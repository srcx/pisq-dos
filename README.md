# Pisq

Pisq is a text interface for connect5 playing written in assembler. Loser is legendary brain originally included in legendary program Pisqorky for Dummies and Wizards which few times almost ;-) won Turnaj (tournament).

(Rest in Czech.)

Spusteni:

`pisq.exe hrac1 hrac2`

Hrac? muze byt bud '_' pro lidskeho hrace nebo jmeno externiho programu (.exe)

Vzhled:

Prvni radek obrazovky je stavovy - jeho obsah (zleva doprava):

* pocet tahu (jako tri cislice) - jedno kolo jednoho hrace = jeden tah
* pocet bodu (vyher) pro hrace 1 (kolecko) jako dve cislice
* symbol kolecka 'O'
* sipka ukazujici, kdo je na tahu nebo kdo prave vyhral, popr. nic pri remize
* symbol krizku 'X'
* pocet bodu (vyher) pro hrace 2 (krizek) jako dve cislice
* dodatecna informace - chybove hlasky, jmeno externiho programu apod.

Zbytek obrazovky obsahuje hraci pole (19 krat 19 policek + okraje), kde '.' je
prazdne policko, 'O' a 'X' jsou jiz polozene kameny a '#' je okraj.

Ovladani:

* sipka nahoru, dolu, doleva, doprava - ovladani kurzoru
* mezernik - umisteni kamene na misto kurzoru
* klavesa 'S' - vzdani se

Po kazde skoncene hre je mozno po dotazu 'Again (y/n)?' program ukoncit
klavesou 'n'.

Pravidla:

Klasicke piskvorky s omezenym hracim polem, kdy je ukolem umistit pet svych
kamenu na v rade sousedici policka vodorovne, svisle nebo diagonalne. Zaplni-li
se cela plocha, je to remiza. Zacinajici hrac se pravidelne meni s kazdou
novou hrou. 

Externi programy:

Musi to byt .exe program, ktery pri spusteni ocekava jako argument na prikazove
radce cislo hrace, za ktereho hraje (1 nebo 2). Pri svem spusteni nacte z
aktualniho adresare soubor pole.dat, ktery obsahuje (po radcich) cele hraci
pole 19 krat 19 poli. Kazde policko muze nabyvat hodnot 0 - prazdne, 1 - hrac
cislo 1, 2 - hrac cislo 2. Provede jeden tah a pole.dat opet prepise novym
stavem.

Implementace:

V pameti programu je pole 21 krat 21 (19 krat 19 + okraje), ve kterem je ulozen
aktualni stav herni plochy, to se po kazdem tahu znovu vykresli na obrazovku
spolecne se stavovym radkem. Pri volani externiho programu se pouziva jeste
jedno docasne pole 19 krat 19, pomoci ktereho se kopiruji data mezi pameti a
polem.dat.

Veskere systemove veci se provadi pres sluzby DOSu nebo BIOSu, pouze vypis na
obrazovku probiha primym zapisem do video ram.
