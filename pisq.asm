; Pisq (c)2000 Stepan Roh

IDEAL
P386
MODEL small, C
STACK 200h

DATASEG

; informacni text
info		db 'Pisq (c)2000 SR',13,10
		db '(_|brain1.exe) (_|brain2.exe)',13,10
		db '$'

; vypisy do stavove (prvni) radky
; format: cislo_tahu body_pro_O O kdo_je_na_tahu_-_sipka X body_pro_X text
str_human	db '000 00 O  X 00 Hit "S" for surrender', 0
str_brain	db '000 00 O  X 00                      ', 0
str_again_q	db '000 00 O  X 00 Again (y/n)?         ', 0
str_brain_err	db '000 00 O  X 00 Error loading brain! ', 0
str_file_err	db '000 00 O  X 00 File I/O error!      ', 0

; nastaveni textoveho rezimu
TEXT_SEG	equ 0b800h	; segment pameti vram v textu
TEXT_MODE	equ 3		; textovy mod
old_mode	db ?		; stary textovy mod
text_width	dw ?		; sirka obrazovky
text_width_df	dw ?		; sirka obrazovky nasobena DESK_FSIZE

; veci tykajici se hry
NAME_LEN	equ 13		; max. delka jmena
brain1		db NAME_LEN dup(?), 0	; jmeno prvniho hrace (max. 13 znaku)
brain2		db NAME_LEN dup(?), 0	; jmeno druheho hrace (max. 13 znaku)
lbrain1		db 0		; delka jmena prvniho hrace
				; - 0 znaci cloveka (i u lbrain2)
lbrain2		db 0		; delka jmena druheho hrace
				; - musi byt ihned za lbrain1
score1		db 0		; skore prvniho hrace
score2		db 0		; skore druheho hrace
				; - musi byt ihned za score1
turn		dw 0		; cislo tahu
on_turn		dw 0		; hrac ktery je na tahu (0,1)
st_turn		dw 0		; hrac, ktery zacinal (0,1)
brain_pos	dw 0		; pozice kamene pridaneho externim prg.

; hraci deska
DESK_SIZE	equ 19		; zakladni rozmer desky (bez okraju)
DESK_LEN	equ (DESK_SIZE*DESK_SIZE)		; pocet poli
DESK_FSIZE	equ (DESK_SIZE+2)			; sirka s okraji
DESK_FLEN	equ ((DESK_SIZE+2)*(DESK_SIZE+2))	; pocet poli s okraji
desk		db DESK_FLEN dup (?)	; aktualni herni deska
desk_d		db DESK_LEN dup (?)	; deska pro externi prg.
desk_ch		db '.', 'O', 'X', '#'	; prevod z policek na znaky
		; - 0 = prazdny
		; - 1 = hrac 0
		; - 2 = hrac 1
		; - 3 = okraj

; externi komunikace
struc epb_t			; exec parameter block pro spusteni procesu
	env	dw 0		; environment (0 -> zdedeny)
	cmd_o	dw ?		; cmdline offset
	cmd_s	dw ?		; cmdline segment
	fcbs	db 0eh dup (0)	; fcbs - zadne
ends
epb		epb_t ?, ?	; epb
epb_cmd		db ?, ?, 0dh	; cmdline (delka, znak 1 nebo 2, konec)
data_file	db 'pole.dat', 0	; jmeno datoveho souboru

CODESEG
ASSUME CS:@code, DS:@data, ES:nothing

; pro exec v proc play
old_ss	dw 0
old_sp	dw 0

; zneguje hodnotu 0<->1
macro	mneg reg
	not reg
	and reg, 1
endm

; preskoci mezery na prik. radce
; es:bx - ukazatel do prikazove radky
; si - pocet zbyvajicich znaku na radce
; nastavuje carry pri narazeni na konec radky
; vraci zmenene bx a si
proc	skip_sp
	uses ax

	clc
@@l1:
	cmp si, 0
	jz @@lc
	mov al, [es:bx]
	cmp al, ' '
	jne @@le
	inc bx
	dec si
	jmp @@l1
@@lc:
	stc
@@le:
	ret
endp

; preskoci ne-mezery na prik. radce
; es:bx - ukazatel do prikazove radky
; ds:ax - cil pro kopirovani - kopiruje max. NAME_LEN znaku a na konec da nulu
; si - pocet zbyvajicich znaku na radce
; v di vraci delku preskocenych
; nastavuje carry pri narazeni na konec radky
; vraci zmenene bx, si a ax
proc	skip_nosp
	uses ax, bp

	xor di, di
	mov bp, ax
	clc
@@l1:
	cmp si, 0
	jz @@lc
	mov al, [es:bx]
	cmp al, ' '
	je @@le
	cmp di, NAME_LEN-1
	ja @@l2			; preskakuje dal, i kdyz uz se nesmi kopirovat
	mov [bp], al
	inc bp
	inc di
@@l2:
	inc bx
	dec si
	jmp @@l1
@@lc:
	stc
@@le:
	mov [byte ptr bp], 0
	ret
endp

; parsovani cmdline
; es - segment psp
; naplni brain[12]
; nastavi carry kdyz neni dostatek argumentu na radce
proc	parse_cmd
	uses ax, bx, si, di

	mov bl, [es:80h]
	xor bh, bh
	mov si, bx
	mov bx, 81h
	call skip_sp
	jc @@lc
	mov ax, offset brain1
	call skip_nosp		; preskoceni (a prekopirovani) prvniho argumentu
	mov ax, di
	mov [lbrain1], al
	call skip_sp
	jc @@lc
	mov ax, offset brain2
	call skip_nosp		; preskoceni (a prekopirovani) druheho argumentu
	mov ax, di
	mov [lbrain2], al
@@le:
	mov al, [brain1]
	cmp al, '_'
	jne @@l1
	mov [lbrain1], 0	; '_' -> clovek
@@l1:
	mov al, [brain2]
	cmp al, '_'
	jne @@l2
	mov [lbrain2], 0	; '_' -> clovek
@@l2:
	clc
@@lc:
	ret
endp

; vytiskne text ukonceny '$'
; par. je adresa (i registr)
macro	print adr
	push ax
	mov ah, 9
	ifdifi <adr>,<dx>
		push dx
		if (((symtype adr) and 8) eq 8)		; prima adresa
			mov dx, offset adr
		else					; registr
			mov dx, adr
		endif
	endif
	int 21h
	ifdifi <adr>,<dx>
		pop dx
	endif
	pop ax
endm

; inicializuje desk (vynuluje a okraje naplni hodnotou 3)
proc	init_desk
	uses cx, ax, di, es

	cld
	mov ax, ds
	mov es, ax
	xor ax, ax
	mov di, offset desk
	mov cx, DESK_FLEN
	rep stosb		; vynulovani
	mov ax, 0303h
	mov di, offset desk
	mov cx, DESK_FSIZE+1
	rep stosb		; horni okraj + prvni z leve bocnice
	mov cx, DESK_FSIZE-2	; bocnice
@@l1:
	add di, DESK_FSIZE-2
	mov [di], ax		; zapisuji se najednou dve hodnoty
	inc di
	inc di
	loop @@l1
	mov cx, DESK_FSIZE-1
	rep stosb		; spodni okraj (bez prvniho znaku)

	ret
endp

; precte pozici kurzoru
; dl - sloupec, dh - radek
; meni ax, bx, cx
macro	cur_get
	mov ah, 3
	mov bh, 0
	int 10h
endm

; nastavi pozici kurzoru
; dl - sloupec, dh - radek
; meni ax, bx
macro	cur_set
	mov ah, 2
	mov bh, 0
	int 10h
endm

; inicializuje obrazovku
proc	init_scr
	uses ax, bx, cx, dx

	mov ah, 0fh
	int 10h
	mov [old_mode], al
	mov al, TEXT_MODE
	mov ah, 0
	int 10h
	mov ah, 0fh
	int 10h
	shr ax, 8
	mov [text_width], ax
	mov bx, DESK_FSIZE-1
	mul bx
	mov [text_width_df], ax
	mov dh, DESK_FSIZE/2
	mov dl, dh
	shl dl, 1
	inc dh
	cur_set			; centrovani kurzoru

	ret
endp

; vrati puvodni obrazovku
proc	done_scr
	uses ax

	mov al, [old_mode]
	mov ah, 0
	int 10h

	ret
endp

; vykresli desk na obrazovku
proc	draw_desk
	uses cx, ax, bx, dx, di, si, es

	mov ax, TEXT_SEG
	mov es, ax
	mov bx, offset desk
	xor cx, cx		; x
	xor dx, dx		; y * text_width
	jmp @@l5
@@l4:
	inc cx
@@l5:
	cmp cx, DESK_FSIZE
	jne @@l2
	xor cx, cx
	cmp dx, [text_width_df]
	je @@l3
	add dx, [text_width]
@@l2:
	mov di, cx
	shl di, 2		; k 1 znaku je jeste atribut + mezera
	mov si, dx
	add si, [text_width]
	shl si, 1
	add di, si		; di = x*4 + (y+1)*2
	xor ah, ah
	mov al, [bx]
	mov si, ax
	mov al, [byte ptr si+desk_ch]
	mov [byte ptr es:di], al
	inc bx
	jmp @@l4
@@l3:
	ret
endp

; precte znak z bufferu klavesnice
; al = ascii, ah = scan code
macro	read_key
	mov ah, 0
	int 16h
endm

; kontroluje vyherni podminku
; dx - prirustek k di
; di - aktualni (jednodimenzionalni) pozice v desk (posledni pridany kamen)
; ax - hrac (1,2 - jako v desk)
; nastavuje carry pri vyhre
proc	check_win
	uses dx, ax, cx, bx, di, si

	xor bx, bx	; citac - musi byt alespon 4, aby jich bylo 5 v rade
	mov si, di
	mov cx, 5
	jmp @@l11
@@l1:
	inc bx
@@l11:
	add si, dx
	cmp [offset desk + si], al
	loope @@l1	; pricitaci smycka
	mov cx, 5
	jmp @@l22
@@l2:
	inc bx
@@l22:
	sub di, dx
	cmp [offset desk + di], al
	loope @@l2	; odecitaci smycka
	cmp bx, 4
	jb @@l3
	stc
	jmp @@le
@@l3:
	clc
@@le:
	ret
endp

; hraci fce pro cloveka
; si - hrac (0,1)
; v di vraci jednodimenzionalni pozici polozeneho kamene v desk
; nastavuje carry pri zadosti o ukonceni (a pri te prilezitosti zneguje si)
proc	play_human
	uses ax, bx, dx

@@human:
	mov bx, offset str_human
	call lprint
@@hl1:
	read_key
	cmp ah, 31	; scan S -> surrender
	jne @@hleft
	; surrender
	mneg si
	inc [score1+si]
	stc
	jmp @@le
@@hleft:
	cmp ah, 75	; scan sipka doleva
	jne @@hright
	cur_get
	cmp dl, 2
	je @@hl1
	dec dl
	dec dl
	cur_set
	jmp @@hl1
@@hright:
	cmp ah, 77	; scan sipka doprava
	jne @@hup
	cur_get
	cmp dl, (DESK_SIZE*2)
	je @@hl1
	inc dl
	inc dl
	cur_set
	jmp @@hl1
@@hup:
	cmp ah, 72	; scan sipka nahoru
	jne @@hdown
	cur_get
	cmp dh, 2
	je @@hl1
	dec dh
	cur_set
@@hdown:
	cmp ah, 80	; scan sipka dolu
	jne @@hspace
	cur_get
	cmp dh, DESK_SIZE+1
	je @@hl1
	inc dh
	cur_set
	jmp @@hl1
@@hspace:		; scan mezernik -> polozeni kamene
	cmp ah, 57
	jne @@hl1
	cur_get
	shr dl, 1	; prevod na indexy do pole
	dec dh
	xor ah, ah
	mov al, dh
	mov cl, DESK_FSIZE
	mul cl
	and dx, 0ffh
	add ax, dx
	mov di, ax
	cmp [byte ptr offset desk + di], 0	; je tam volno ?
	jne @@hl1
	mov ax, si
	inc al		; prevod hrac(0,1)->hrac(1,2)
	mov [byte ptr offset desk + di], al	; polozeni kamene
	clc
@@le:
	ret
endp

; hraci fce pro brain
; si - hrac (0,1)
; v di vraci jednodimenzionalni pozici polozeneho kamene v desk
; nastavuje carry pri chybe
proc	play_brain
	uses ax, bx, cx, dx, bp

@@comp:
	xor ch, ch
	mov cl, [lbrain1+si]
	xor bp, bp
	mov bx, offset brain1
	cmp si, 0
	je @@cl1
	add bx, brain2-brain1
@@cl1:					; kopie jmena brainu do stavoveho retezce
	mov al, [bx]
	mov [str_brain+bp+15], al
	inc bx
	inc bp
	loop @@cl1
	mov bx, offset str_brain
	call lprint			; tisk stavoveho retezce
	pusha				; ulozeni kontextu procesu
	push ds
	push es
	mov [cs:old_ss], ss
	mov [cs:old_sp], sp
	mov ah, 3ch
	mov dx, offset data_file
	mov cx, 0
	int 21h				; vytvoreni pole.dat
	mov bx, offset str_file_err
	jc @@cerr

	mov bx, ax			; handle
	mov dx, si
	mov cx, DESK_FLEN
	xor di, di
	xor si, si
@@cll:					; prepsani desk do desk_d
	mov al, [desk+di]
	inc di
	cmp al, 3			; preskakuji se okraje
	je @@cll2
	mov [desk_d+si], al
	inc si
@@cll2:
	loop @@cll
	mov si, dx

	mov ah, 40h
	mov dx, offset desk_d
	mov cx, DESK_LEN
	int 21h				; zapis desk_d do pole.dat
	mov ax, bx
	mov bx, offset str_file_err
	jc @@cerr

	mov bx, ax
	mov ah, 3eh
	int 21h				; zavreni pole.dat

	mov [epb.cmd_s], ds		; naplneni epb
	mov [epb.cmd_o], offset epb_cmd
	mov ax, ds
	mov es, ax
	mov bx, offset epb
	mov dx, offset brain1
	cmp si, 0
	je @@cl2
	add dx, brain2-brain1
@@cl2:					; v dx je adresa jmena prg
	mov cx, si
	add cx, '1'
	mov [epb_cmd], 1
	mov [epb_cmd+1], cl		; obsah cmdline ('1' nebo '2')
	mov ah, 4bh
	mov al, 0
	int 21h				; volani externiho prg
	mov ss, [cs:old_ss]		; obnoveni kontextu procesu
	mov sp, [cs:old_sp]
	pop es
	pop ds
	popa
	mov bx, offset str_brain_err
	jc @@cerr

	mov ah, 3dh
	mov al, 0
	mov dx, offset data_file
	int 21h				; otevreni pole.dat
	mov bx, offset str_file_err
	jc @@cerr
	
	mov bx, ax
	mov ah, 3fh
	mov dx, offset desk_d
	mov cx, DESK_LEN
	int 21h				; nacteni pole.dat do data_d
	mov ax, bx
	mov bx, offset str_file_err
	jc @@cerr

	mov bx, ax			; handle
	mov dx, si
	mov cx, DESK_FLEN
	xor di, di
	xor si, si
@@cll3:					; prepis desk_d do desk (zadna kontrola podvadeni!)
	mov al, [desk+di]
	inc di
	cmp al, 3			; okraje (ktere v desk_d nejsou) se v desk preskoci
	je @@cll4
	mov al, [desk_d+si]
	cmp al, 0
	je @@cll5			; prazdna policka se preskoci
	cmp al, [desk+di-1]
	je @@cll5			; stejna policka se preskoci
	mov [brain_pos], di		; lisici se pole je povazovano za umisteny kamen
	dec [brain_pos]
	mov [desk+di-1], al
@@cll5:
	inc si
@@cll4:
	loop @@cll3
	mov si, dx

	mov ah, 3eh
	int 21h				; zavreni pole.dat

	mov di, [brain_pos]
	clc
	jmp @@le
@@cerr:					; vypis chybove hlasky (v bx)
	call lprint
	read_key
	stc

@@le:
	ret
endp

; hraci fce
; ax - cislo hrace
; nastavuje carry pri skonceni hry
proc	play
	uses si, bx, ax, dx, cx, di, es

	mov si, ax		; rozhodovani jakou play fci volat
	cmp [byte ptr offset lbrain1+si], 0
	jne @@comp
	call play_human
	jc @@le
	jmp @@check
@@comp:
	call play_brain
	jc @@le
@@check:			; kontrola vyhernich podminek
	mov ax, si
	inc al
	mov dx, 1		; vodorovne
	call check_win
	jc @@win
	mov dx, DESK_FSIZE+1	; z leveho horniho rohu do praveho spodniho
	call check_win
	jc @@win
	mov dx, DESK_FSIZE	; svisle
	call check_win
	jc @@win
	mov dx, DESK_FSIZE-1	; z leveho spodniho rohu do praveho horniho
	call check_win
	jnc @@le
@@win:
	inc [score1+si]		; zvyseni skore
	stc
@@le:
	ret
endp

; vytiskne text na adrese v bx ukonceny NULL do leveho horniho rohu obrazovky a
; vyplni zacatek cislem tahu apod.
proc	lprint
	uses ax, es, si, bx, dx, cx

	xor dx, dx		; pocet tahu (000)
	mov ax, [turn]
	mov cx, 100
	div cx
	add al, '0'
	mov [bx], al
	mov ax, dx
	xor dx, dx
	mov cx, 10
	div cx
	add al, '0'
	mov [bx+1], al
	add dl, '0'
	mov [bx+2], dl

	xor ah, ah		; skore (00)
	mov al, [score1]
	mov dl, 10
	div dl
	add al, '0'
	mov [bx+4], al
	add ah, '0'
	mov [bx+5], ah
	xor ah, ah
	mov al, [score2]
	mov dl, 10
	div dl
	add al, '0'
	mov [bx+12], al
	add ah, '0'
	mov [bx+13], ah

	mov ax, [on_turn]	; kdo je na rade (nebo kdo vyhral)
	cmp ax, 0
	jne @@l2
	mov [byte ptr bx+8], '<'
	mov [byte ptr bx+9], '-'
	jmp @@l4
@@l2:
	cmp ax, 1
	jne @@l3
	mov [byte ptr bx+8], '-'
	mov [byte ptr bx+9], '>'
	jmp @@l4
@@l3:
	mov [byte ptr bx+8], ' '
	mov [byte ptr bx+9], ' '
@@l4:
	xor si, si
	mov ax, TEXT_SEG
	mov es, ax
@@l1:				; tisk na obrazovku (od leveho horniho rohu)
	mov al, [bx]
	cmp al, 0
	jz @@le
	mov [byte ptr es:si], al
	inc si
	inc si
	inc bx
	jmp @@l1

@@le:
	ret
endp

STARTUPCODE			; startovaci kod
	mov ax, @data
	mov ds, ax

	call parse_cmd		; parsovani cmdline
	jc print_info		; nedostatek argumentu

	mov ah, 4ah
	mov bx, 1000
	int 21h			; snizeni okupovane pameti na 16000 bytu

game_init:			; jedna hra
	call init_scr		; nastaveni textoveho modu
	call init_desk		; inicializace desky
	mov [turn], 0
	mov ax, [st_turn]	; stridani prvniho na tahu
	mneg ax
	mov [on_turn], ax
	mov [st_turn], ax
game_loop:			; jeden tah obou hracu
	call draw_desk
	mov ax, [on_turn]
	mneg ax
	mov [on_turn], ax
	inc [turn]
	cmp [turn], (DESK_SIZE*DESK_SIZE)	; kontrola naplneni desky
	ja desk_full
	call play		; tah hrace 1
	jc game_end		; cf=1 -> konec hry
	call draw_desk
	mov ax, [on_turn]
	mneg ax
	mov [on_turn], ax
	inc [turn]
	cmp [turn], (DESK_SIZE*DESK_SIZE)	; kontrola naplneni desky
	ja desk_full
	call play		; tah hrace 2
	jc game_end		; cf=1 -> konec hry
	jmp game_loop		; cf=0 -> dalsi kolo

desk_full:
	mov [on_turn], 2	; remiza
game_end:
	call draw_desk
	mov bx, offset str_again_q
	call lprint
again_q:			; dotaz na pokracovani
	read_key
	cmp ah, 49		; scan N
	je no_more
	cmp ah, 21		; scan Y
	je game_init		; a znovu
	jmp again_q
no_more:			; konec
	call done_scr
	jmp the_end
print_info:
	print info		; tisk info stringu
the_end:
	mov al, 0		; return 0
	mov ah, 4ch
	int 21h
END
