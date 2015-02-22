// Zaklad pro pisqorky 21.2.1997 SR
// Kitty 0.0 (zaklad pro pisqorky) 31.10.1997
// Loser 0 0.0 (zaklad pro pisqorky) 12.4.1998
// Loser III 1.0 12.4.1998
// Loser III 2.0 13.4.1998
// Loser III 2.5 29.4.1998 - rozdilove ohodnocovani
// Loser III 2.5a 29.4.1998 - zvysena sirka ze 4 na 8
// Loser III 2.5b 1.5.1998 - urychleni
// Loser III 2.5c 3.5.1998 - urychleni 2
// Loser III 2.5d 8.5.1998 - urychleni 3 - zruseni urcite nevyuziteho stromu

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define sbyte signed char

#define MAX_NEJ	8
#define MAX_HLOUBKA 4

// hraci pole
sbyte s_pole[19][19]; // I/O
sbyte h_pole[21][21]; // pracovni
sbyte hrac, nhrac;
// info string
#ifdef PDEBUG
char *info = "Loser III 2.5d (c)1997,1998 Stepan Roh - Debugging on";
#else
char *info = "Loser III 2.5d (c)1997,1998 Stepan Roh";
#endif
// pole.dat
char *fpole = "pole.dat";
// log
#ifdef PDEBUG
FILE *log; const char *flog = "loser325.log";
#endif


// nacte pole.dat do hraci_pole
void nacti_pole (void) {
  int i,j; FILE *fr;

#ifdef PDEBUG
  if ((log = fopen (flog, "w")) == NULL) return;
#endif
  if ((fr = fopen (fpole, "rb")) == NULL) return;
  if (fread (&s_pole, 361, 1, fr) == 0) return;
  if (fclose (fr) == EOF) return;

  for (i = 0; i <= 20; i++)
    for (j = 0; j <= 20; j++)
      h_pole[i][j] = -2;
  for (i = 1; i <= 19; i++)
    for (j = 1; j <= 19; j++)
      h_pole[i][j] = s_pole[i - 1][j - 1];
};

// zapise hraci_pole do pole.dat
void zapis_pole (void) {
  int i,j; FILE *fw;

  for (i = 1; i <= 19; i++)
    for (j = 1; j <= 19; j++)
      s_pole[i - 1][j - 1] = h_pole[i][j];
  if ((fw = fopen (fpole, "wb")) == NULL) return;
  if (fwrite (s_pole, sizeof(s_pole), 1, fw) == 0) return;
  if (fclose (fw) == EOF) return;
#ifdef PDEBUG
  if (fclose (log) == EOF) return;
#endif
};

// prepocitavaci tab.
int oh_tab[2][5] = {
{
// nevlastni
// 1, 2, 3, 4, 5 - bude
  0, 4, 20, 100, 400
},
{
// vlastni
// 1, 2, 3, 4, 5 - bude
  0, 5, 25, 125, 1000
}
};

int idx[] = { 1, 0, 1, -1 };
int idy[] = { 0, 1, 1,  1 };

int oh_pole[MAX_HLOUBKA + 1][21][21][2];

// ohodnoti dane policko pro oba hrace a ulozi primo do oh_pole
void ohodnot_pole (int hloubka, int x, int y) {
  int oh1, oh2, i, sx, sy, i2, p1, p2, x2, y2, h1, h2;

  oh1 = oh2 = 0;
  h1 = hrac == 1;	// predvypocet
  h2 = hrac == 2;

  for (i = 0; i < 4; i++) {
    sx = x - (idx[i] << 2) - idx[i];
    sy = y - (idy[i] << 2) - idy[i];	// zac. prohledavani
    while ((sx != x) || (sy != y)) {
      sx += idx[i]; sy += idy[i];
      x2 = sx; y2 = sy;
      if (!((x2 < 1) || (y2 < 1))) {
	i2 = p1 = p2 = 0;
	while (i2 != 5) {
	  switch (h_pole[x2][y2]) {
	  case 1 : p1++; break;
	  case 2 : p2++; break;
	  case -2 : goto l1;
	  };
	  x2 += idx[i]; y2 += idy[i]; i2++;
	};
	if (!((p1 > 0) && (p2 > 0))) {
	  if (p2 == 0)
	    oh1 += oh_tab[h1][p1];
	  else
	    oh2 += oh_tab[h2][p2];
	};
	l1:
      };
    };
  };

  oh_pole[hloubka][x][y][0] = oh1;
  oh_pole[hloubka][x][y][1] = oh2;
};

struct S_max {
  int oh, x, y;
};	// struktura pro ulozeni nejlepsich

// ohodnoti do daneho oh_pole (dle hloubky)
// hloubka = 0 : ohodnoti vse
// hloubka > 0 : zkopiruje z hloubka-1 a ohodnoti rozdil
void i_ohodnot (int hloubka, int px, int py) {
  int x, y, i;

  if (!hloubka) {	// vse
    memset (oh_pole[0], 0, sizeof (int) * 21 * 21 * 2);	// vymazani
    for (y = 1; y < 20; y++)
      for (x = 1; x < 20; x++)
	if (h_pole[x][y] == 0) {
	  ohodnot_pole (0, x, y);
	};
  } else {		// dle px, py
    // zkopirovani
    memcpy (oh_pole[hloubka], oh_pole[hloubka-1], sizeof (int) * 21 * 21 * 2);
    // vymazani ohodnoceni na px, py
    oh_pole[hloubka][px][py][0] = oh_pole[hloubka][px][py][1] = 0;
    // rozdilove ohodnoceni
    for (i = 0; i < 4; i++) {	// smery
	x = px - (idx[i] << 2); y = py - (idy[i] << 2);	// zac. cesty
      while ((x != px + (idx[i] << 2) + idx[i]) || (y != py + (idy[i] << 2) + idy[i])) {
	// kontrola pozice
	if ((h_pole[x][y] == 0) && (((x > 0) && (x < 20)) && ((y > 0) && (y < 20)))) {
	  ohodnot_pole (hloubka, x, y);
	};
	x += idx[i]; y += idy[i];	// posun v ceste
      };
    };
  };
};

// ohodnocuje do hloubky
// -- 325 -- : +par. px, py - oznacuji x,y posledne pridaneho tahu
// -- 325 -- : hloubka = 0 : ohodnotit vse
// -- 325 -- : ohodnoceni se nachazi v poli oh_pole[hloubka][x][y][h]
// -- 325d -- : lo - nejvyssi ohodnoceni v predchozim
int ohodnot_r (int h, int *nx, int *ny, int px, int py, int lo) {
#ifdef PDEBUG
  int debug_i;
#endif
  int x, y, i, oh, nx2, ny2;
  int oh2;
  static hloubka = 0;
  int no = 0;
  int no2 = 0;
  int noi = 0;
  int nh = (!(h - 1)) + 1;
  struct S_max *max = malloc (sizeof (struct S_max) * MAX_NEJ);

  memset (max, 0, sizeof (struct S_max) * MAX_NEJ);
  i_ohodnot (hloubka, px, py);	// ohodnoti rozdilove do daneho oh_pole
  // faze 1 : vyber MAX_NEJ nejlepsich (h i nh) - ukonceni pri vlastni petce
  // vyber z vlastnich i souperovych
  for (y = 1; y < 20; y++)
    for (x = 1; x < 20; x++)
      {
	if ((oh = oh_pole[hloubka][x][y][h-1]) > no) {	// vlastni
	  no = oh; *nx = x; *ny = y;
	  if (no >= oh_tab[h == hrac][4])	{ // petka
	    hloubka++;
	    goto lend;
	  };
	};
	if ((oh2 = oh_pole[hloubka][x][y][nh-1]) > no2) {	// souper.
	  no2 = oh2; nx2 = x; ny2 = y;
	  if (oh2 >= oh_tab[nh == hrac][4]) noi++;	// ???
	};
	if (oh2 > oh) oh = oh2;
	// zarazeni do max
	if (oh > max[MAX_NEJ - 1].oh)	// kvuli urychleni
	  for (i = 0; i < MAX_NEJ; i++) {
	    if (oh > max[i].oh) {
	      if (i < MAX_NEJ - 1)
		memmove (max + i + 1, max + i, sizeof (struct S_max) * (MAX_NEJ - i - 1));
	      max[i].oh = oh;
	      max[i].x = x;
	      max[i].y = y;
	      break;
	    };
	  };
      };
  // faze 2 : kontrola hloubky - prilisna - vraci nejlepsi (h ci nh)
  if (++hloubka > MAX_HLOUBKA) {
    // nepr. pouze, kdyz je jich tam vic >= potenc. ctyrka
    if ((noi > 1) && (no2 > no)) {
      *nx = nx2; *ny = ny2; no = -no2;
    };
    goto lend;
  };
  // faze 3 : do hloubky (nh) pro nejlepsi
  no = -32000;
  for (i = 0; i < MAX_NEJ; i++) {
    if (max[i].oh > 0) {
      h_pole[max[i].x][max[i].y] = h;
#ifdef PDEBUG
      for (debug_i = 0; debug_i < hloubka; debug_i++)
	fprintf (log, " ");
      fprintf (log, "[%d] x = %2d, y = %2d\n", h, max[i].x, max[i].y);
#endif
// -- 325c -- :      if ((oh = ohodnot_r (nh, &x, &y, max[i].x, max[i].y)) > no) {
// -- 325d -- : 325c
      if ((oh = ohodnot_r (nh, &x, &y, max[i].x, max[i].y, no)) > no) {
// -- 325d --
	no = oh; *nx = max[i].x; *ny = max[i].y;
	if (no >= oh_tab[h == hrac][4]) {
	  h_pole[max[i].x][max[i].y] = 0;
	  goto lend;
	};
// -- 325d -- : orezani
	if (no > -lo) {
	  h_pole[max[i].x][max[i].y] = 0;
	  goto lend;
	};
// -- 325d --
      };
#ifdef PDEBUG
      for (debug_i = 0; debug_i < hloubka; debug_i++)
	fprintf (log, " ");
      fprintf (log, "= %d\n", oh);
#endif
      h_pole[max[i].x][max[i].y] = 0;
    };
  };
  // faze 4 : vyber nejvetsiho a vraceni negace

  lend:
  hloubka--;
  free (max);
  return (-no);
};


int spirala_dx[] = {0,1,0,-1};
int spirala_dy[] = {-1,0,1,0};
// rozmysli tah - hrac = 1 pro kolecka, 2 pro krizky
void mysli (void) {
#ifdef PDEBUG
  int debug_x, debug_y;
#endif

  int nx, ny, oh, nh, x, y, c, mc, i, dx, dy;

#ifdef PDEBUG
  fprintf (log, info);
  fprintf (log, "hrac = %d (", hrac);
  if (hrac == 1) {
    fprintf (log, "o)\n");
  } else {
    fprintf (log, "x)\n");
  };
  fprintf (log, "   01020304050607080910111213141516171819\n");
  for (debug_y = 1; debug_y < 20; debug_y++) {
    fprintf (log, "%02d ", debug_y);
    for (debug_x = 1; debug_x < 20; debug_x++) {
      fputc (' ', log);
      switch (h_pole[debug_x][debug_y]) {
      case 0 : fputc ('.', log); break;
      case 1 : fputc ('o', log); break;
      case 2 : fputc ('x', log); break;
      };
    };
    fputc ('\n', log);
  };
#endif

  nx = ny = 10;

#ifdef PDEBUG
  fprintf (log, "MAX_NEJ = %d, MAX_HLOUBKA = %d\n", MAX_NEJ, MAX_HLOUBKA);
#endif

  nh = ohodnot_r (hrac, &nx, &ny, 0, 0, -32000); nh = -nh;

#ifdef PDEBUG
  fprintf (log, "nx = %2d, ny = %2d, nh = %d\n", nx, ny, nh);
#endif

  if (h_pole[nx][ny] != 0) {
    // hledani mista do spiraly
    nx = 10; ny = 10;	// stred
    c = 1;	// akt. delka kousku spiraly
    mc = 1;	// max. delka
    i = -1;	// index do tab.
    while (h_pole[nx][ny] != 0) {
      c--;
      if (!c) {	// je cas obratit jinam
	i++; if (i > 3) i = 0;
	dx = spirala_dx[i];
	dy = spirala_dy[i];
	mc++;
	c = mc >> 1;	// vzdy kazdy druhy
      };
      nx += dx; ny += dy;
    };
  };

  h_pole[nx][ny] = hrac;
};

void tisk_info (void) {
  putchar ('\n');
  printf ("%s [%dx%d]\n", info, MAX_NEJ, MAX_HLOUBKA);
};

main (int argc, char *argv[]) {
  if (argc == 2) {
    hrac = atoi (argv[1]);
    nhrac = (!(hrac - 1)) + 1;
    nacti_pole ();
    mysli ();
    zapis_pole ();
  } else tisk_info ();
  return 0;
};