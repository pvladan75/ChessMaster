# Studio za tutorijal — kako se piše

Kratko uputstvo za trenera koji piše tutorijal, i ujedno ugovor za bilo koga —
čoveka ili model — ko priprema materijal za ovu aplikaciju.

**Pisano na srpskom namerno.** Ostali dokumenti u `docs/` su na engleskom; ovaj
je za trenere koji ga koriste, kao i pravni tekstovi. Ne prevoditi.

**Tutorijal je materijal za video** (od 25.9.2026, `docs/PLAN-TUTORIJAL-VIDEO.md`).
Učeniku se šalje film, nikad sam tutorijal; ako hoćeš da učenik nešto reši,
napravi vežbu (*exercise*), ne deo tutorijala.

Studio postoji na Windows-u i na telefonu; na telefonu su dva ekrana, „Line" i
„Parts".

**Aplikacija je na engleskom**, pa su nazivi dugmadi i polja u ovom uputstvu
navedeni onako kako stoje na ekranu — „Save tutorial", „Flow" i tako dalje.

---

## 1. Dve reči koje treba razlikovati

**Takt** (na ekranu *beat*) je jedan trenutak: jedna pozicija, rečenica o
njoj, i ono što je na njoj nacrtano. Takt nastaje sam od sebe — čim povučeš
potez na tabli, dobio si sledeći takt.

**Deo** (na ekranu *part*) je jedna celina: **jedna polazna pozicija i jedna
linija iz nje.** Deo ima onoliko taktova koliko poteza u njemu odigraš, i
**nikad se ne grana**: film prolazi deo od prvog do poslednjeg takta, pa sledeći
deo, i sve što je u delu vidi se u filmu (od 26.9.2026,
`docs/PLAN-MAPA-DELOVA.md`).

**Zlatno pravilo:**

> Potezi se vuku na tabli. Nov deo počinje **samo** kad priča skoči na drugu
> poziciju ili na drugu liniju.

Ako za svaki potez praviš nov deo, radiš deset puta više posla, a film pokazuje
deset tabli umesto jedne priče.

## 2. Deo samo pokazuje

Svaki deo je demonstracija: pozicija, potezi i rečenice uz njih. Nema tipa
zadatka, pitanja ni ponuđenih odgovora — film ne može da sačeka odgovor. Ako
je pozicija vredna rešavanja, uvodna rečenica kaže šta da se traži, a linija
pokazuje rešenje.

**Deo bez ijednog poteza je potpuno ispravan deo.** „Pogledaj polje d5" plus
strelica je cela lekcija; takav deo se čuva sa svojim komentarom i oznakama.

**Okretanje jednog dela.** U redu svakog dela u spisku delova je dugme koje
okreće samo taj deo („Turn this part"); dugme za okretanje table gore okreće
sve delove.

**Druga linija iz iste pozicije — odigraj drugi potez.** Vrati se na takt odakle
hoćeš drugu liniju i **odigraj drugi potez na tabli**. Deo u kome si ostaje
tačno kakav je bio, a odmah posle njega počinje nov deo: na toj poziciji, sa tvojim
potezom kao linijom, i ti stojiš na njemu. U filmu dolazi posle prve linije, kao
„Back to the position after …". Na dnu ekrana piše, na primer, „18... h6 starts
part 4. The film shows it after part 3."

Linija koja stigne **sa varijantama** — nalepljena u tab „PGN", preneta iz
Analize ili uvezena iz fajla (JSON, PGN) — deli se na delove istim redom: do
pozicije gde se linije razilaze, pa svaka sporedna linija redom kako stoji, pa
stara linija dalje. Ništa se ne gubi i ništa se ne krije od filma. Tutorijali
sačuvani pre 26.9.2026 koji u delu imaju varijantu ostaju kakvi su (film i dalje
pokazuje samo glavnu liniju).

**Presek na mestu — „Insert a line here".** Primer: iz pozicije
`8/3k4/1n3b2/8/8/8/2PK4/2R5 w` demonstracija ide `1. Ra1 Kc6 2. Ra6 Bb2 3. c3
Kb5`, a posle `Kc6` hoćeš da pokažeš i `2. Ra8 Bb2`. U panelu **„Flow"** stani
na takt posle `Kc6`; na njegovoj kartici, pored „Delete this move", je ikonica
račvanja puta — **„Insert a line here"**. Deo se deli na tri:

1. **do `Kc6`** — ostaje stari deo, sa svojim imenom i sa istom oznakom na
   serveru;
2. **nova linija** od pozicije posle `Kc6` — studio te ostavlja na njenoj prvoj
   poziciji, pa samo odigraš `2. Ra8 Bb2`;
3. **stari nastavak** `2. Ra6 Bb2 3. c3 Kb5` od iste pozicije.

Svi komentari, strelice i polja ostaju gde su bili. Strelice i polja sa takta
na kome si sekao prelaze i na početak nove linije i na početak nastavka, jer se
ta pozicija u filmu vidi ponovo. Ako si drugu liniju već odigrao kao varijantu
na tom taktu, ona sama postaje nova linija. Ikonica se pojavljuje samo na taktu
na kome stojiš, i samo u delu koji ima poteze. Pogrešan rez vraća jedan Ctrl+Z.

U filmu su prvi deo i nova linija jedna tabla; nastavak ponovo postavlja
poziciju posle `Kc6`, kao kad se okrene strana.

### Delovi kao mapa

**„Tutorial contents"** je spisak delova redom kojim ih film pušta. Svaki red
kaže broj dela i kako počinje — *new board* (nova tabla), *continues* (nastavlja
prethodni) ili *back to after …* (vraća se na poziciju posle nekog poteza) — pa
ime dela i njegove poteze u jednom redu. Levo je linija koja spaja delove:
**puna** gde deo nastavlja prethodni, **isprekidana** gde se vraća na ranije
viđenu poziciju. Svaka linija se završava **strelicom** na delu u koji vodi,
a isprekidana linija polazi baš **od poteza na koji se deo vraća** — tri dela
koja odgovaraju na isti potez izlaze iz tog poteza, svaki u svojoj traci (od
26.9.2026). Nova tabla je **kvadrat**, svaki drugi deo **krug**. Deo koji
pišeš ima okvir, prsten oko oznake i reči *you are here*. Ništa od toga ne zavisi
od boje.

Na širokom prozoru mapa ima svoju kolonu levo od table (kad pored table u punoj
veličini ima mesta za nju); na manjem stoji iznad otvorenog dela. Iznad
„Flow" otvoreni deo kaže gde stoji — „Part 4 of 8 · back to after 18. Rfe1 in
part 3" — i „in part 3" otvara taj deo. U „Flow" takt na koji se neki kasniji
deo vraća ima dugme „Part 4 starts here · 18... h6", koje otvara taj deo. Pored
imena otvorenog dela su „Rename", „Move up", „Move down", „Clone part" i
„Delete part". Premeštanje može da promeni kako deo počinje: deo premešten
iznad dela na koji se vraća postaje nova tabla.

## 3. Komentar, strelice i polja

**Komentar pripada taktu i čita se pre poteza koji odlazi iz njega.** Redosled u
filmu je: vidi se pozicija → čuje se šta se o njoj kaže → odigra se sledeći
potez. Zato panel **„Flow"** i crta rečenicu **između** poteza koji je stigao i
poteza koji odlazi.

Ako hoćeš da nešto kažeš „posle poteza", to je rečenica **sledećeg takta** — ne
druga rečenica na istom.

**Redne brojeve piši rečima:** „sedmi red", „na sedmom redu", „u dvanaestom
potezu" — ne „7. red". Glas broj sa tačkom čita kao broj kojim se rečenica
završava, pa napravi pauzu usred rečenice. Linije slobodno piši kao „h-linija"
ili „c-pešak": glas to čita „ha linija", „ce pešak".

**Crtanje** je traka ispod table: **„Arrow"**, **„Square"**, krugovi sa bojama,
**„Clear marks"**.

* strelica se crta klikom na dva polja; **isti par klikova je briše**;
* polje se označava jednim klikom; ponovni klik ga briše;
* **brisanje ne gleda boju** — ispravlja se „pogrešna strelica", ne „pogrešna
  boja";
* prelazak na drugi takt zaboravlja započetu strelicu i **isključuje crtanje**,
  da prvi klik na novom taktu ne bi nacrtao polje umesto da pomeri figuru.

## 4. Tab „PGN" — tekst dela

Treći tab pored „Flow" i „Tree" pokazuje deo kao tekst i prima tekst spolja.
Ovo su jedina vrata kroz koja anotirana partija (iz knjige, iz motora, iz
programa koji čita PDF) ulazi u tutorijal **sa svojim komentarima i oznakama**.

Format je standardni PGN, isti koji pišu Lichess i šahovski programi:

```
1. e4 { Beli zauzima centar. [%cal Gd2d4][%csl Rd5] } e5 2. Nf3
```

* `{ … }` — komentar tog poteza;
* `[%cal Gd2d4]` — strelica sa d2 na d4;
* `[%csl Rd5]` — obojeno polje d5;
* `( … )` — sporedna varijanta; posle „Apply" svaka postaje **poseban deo**
  (odeljak 2), i piše „Applied as 3 parts: every side line is a part of its
  own.";
* više oznaka se odvaja zarezom: `[%cal Gd2d4,Rf1c4]`.

**Slova boja:** `G` zelena · `R` crvena · `B` plava · `O` narandžasta ·
`P` ljubičasta. (Nema žute.)

**Kucanje ništa ne menja dok ne pritisneš „Apply".** Dok tekst nije primenjen,
pored dugmeta piše „edited" i stoji dugme **„Discard"**, koje tekst baca.
Dok neprimenjen tekst čeka, studio **ne otvara drugi deo preko njega** — ni
potezom koji bi počeo nov deo, ni klikom na drugi red, ni „New demonstration",
„Clone part", „Delete part", „Insert a line here", „Position setup" ni Undo — i
kaže: „Apply or discard the text in the PGN tab first." Ctrl+Z u tom polju
tada vraća tvoje kucanje, a ne izmenu tutorijala.

**Šta „Apply" odbija:**

* tekst u kome neki potez ne može da se odigra — odbija se **ceo**, uz broj
  takvih poteza. Deo ostaje netaknut.

**Kad tekst počinje sa druge pozicije, pita pre nego što odbije.** Dva slučaja,
ista tri odgovora:

* **Tekst nosi svoju polaznu poziciju** (`[FEN]`), različitu od pozicije dela —
  „Text starts from a different position". **„Use that position"** premešta
  deo na tu poziciju.
* **Tekst nema `[FEN]`**, a potezi ne mogu da se odigraju od pozicije dela, ali
  mogu **svi** od osnovne pozicije — „Text does not start from here". To je
  obično partija nalepljena od prvog poteza u deo koji stoji na, recimo,
  dvanaestom. **„Use starting position"** premešta deo na osnovnu poziciju.

U oba slučaja **„Keep existing"** čita tekst od pozicije dela (i odbija ga ako
se potezi odatle ne mogu odigrati), a **„Cancel"** ne menja ništa. Film počinje
deo na poziciji koju si izabrao, zato se to pita, a ne pretpostavlja.

Ako tekst bez `[FEN]` ne može da se odigra ni od pozicije dela ni od osnovne
pozicije, ništa se ne pita: odbija se, uz napomenu da tekst nema polaznu
poziciju, pa se ne vidi odakle počinje.

Kursor u tekstu bira potez: tabla i „Flow" idu za njim. **Desni klik** na potez
nudi „Add arrow", „Mark square" i „Add comment" — prve dve postave
kursor na taj potez i uključe crtanje **na tabli**.

## 5. Redosled rada i čuvanje

1. **Naziv** — gore u traci prozora, klikni i kucaj. Ispod naziva su jezik i
   oznake i **„Details…"**, koje otvara „Labels" i „Language" — jezik odlučuje
   na kom glasu se otvara izvoz videa (odeljak 6).
2. **„Position setup"** (ikonica klizača gore desno) ako deo ne počinje iz
   osnovne pozicije.
3. Povuci poteze i piši komentare po taktovima.
4. Nov deo: **„New demonstration"** za sledeći primer — „From here" ga počinje
   na poziciji gde se linija otvorenog dela završava, „New board" iz osnovne
   pozicije; **„Insert a line here"** za drugu liniju iz iste pozicije
   (odeljak 2).
5. **„Save tutorial"** — jedan upis, na kraju. Svaki sledeći pritisak menja
   **isti** tutorijal, ne pravi nov.
6. **„Export video"** (ikonica kamere) — film koji se šalje učeniku. Dugme
   **„Preview"** u tom dijalogu pokazuje nekoliko slika iz filma pre nego što
   se ceo renderuje; to je jedini pregled pre izvoza.

Tutorijal mora da ima naziv. Poslednji deo se ne može obrisati. Nedovršen rad se
sam čuva na računaru; kad sledeći put otvoriš nov tutorijal, pitaće te
(„Cancel" / „New" / „Continue") — **„New" briše nezavršeni**.

### Vraćanje unazad i sačuvana verzija

**Undo i Redo** su dve strelice gore desno, ili **Ctrl+Z** i **Ctrl+Y** (i
Ctrl+Shift+Z). Pamti se **100 poslednjih izmena**, dok je studio otvoren;
zatvaranjem studija istorija se briše. Rečenica otkucana bez pauze je jedna
izmena, ne slovo po slovo. Ctrl+Z radi i dok je kursor u polju za tekst — vraća
poslednju izmenu tutorijala, bila to rečenica ili potez — osim u tabu „PGN"
dok u njemu čeka neprimenjen tekst (odeljak 4). Prelazak na drugi takt ili deo
nije izmena.

**„Discard changes"** (ikonica sata sa strelicom, pored Undo i Redo) vraća
tutorijal na poslednju sačuvanu verziju. I to je jedna izmena, pa ako si
pogrešio, Ctrl+Z vraća tvoje izmene. Ikonica je siva kad nema šta da se odbaci.

**Kad otvoriš sačuvan tutorijal koji na ovom računaru ima nesačuvane izmene**,
studio ih uporedi sa verzijom na serveru. Ako se razlikuju po sadržaju (a ne
samo po tome gde si stajao), pita: **„This tutorial has changes you have not
saved"** — **„Continue with my changes"** ili **„Open the saved version"**. Ni
jedan odgovor ništa ne gubi dok je studio otvoren: posle „Open the saved
version" Ctrl+Z vraća izmene. Pita samo dok još ništa nisi promenio; ako si
počeo da radiš pre nego što je server odgovorio, ne prekida te, nego samo
upali „Discard changes". Ako server ne odgovori, tutorijal se otvara sa tvojim
izmenama i to piše na dnu ekrana.

---

## 6. Jezik i glas videa

**Tutorijal kaže na kom je jeziku, i to biraš ti.** Polje **„Language"** je u
prozoru **„Details…"** ispod naziva, gore u traci (na telefonu: „More" →
„Details…"): **„Not set"** ili jedan od sedam jezika — English,
Serbian (Latin), Serbian (Cyrillic), German, Spanish, Italian, French. Samo tih
sedam, jer su to jezici čije poteze aplikacija ume da izgovori; jezik čiji bi
potezi bili pročitani engleskim rečima se ne nudi.

**Tutorijal čita samo film.** Aplikacija tutorijal više ne čita naglas ni na
jednom uređaju. Glas za **izvoz videa** biraš ti, i on važi za sve koji snimak
gledaju. Dijalog za izvoz se otvara na glasovima jezika tutorijala; kad je jezik
„Not set", na glasu izabranom prošli put. Potezi u komentaru se u filmu
izgovaraju na jeziku glasa: „Bc4" postaje „lovac ce četiri", a ne „bishop c
four". Ono što si napisao se ne menja — menja se samo ono što glas dobija.

Za video hrvatski glas **ne važi** kao srpski: server nema hrvatski rečnik
poteza, pa bi potezi bili izgovoreni engleskim rečima. Ako server nema srpski
glas, dijalog se otvara kao ranije.

**Tutorijal koji ne pišeš u studiju** — JSON fajl ili prevod — nosi jezik u
polju `"language"` (`docs/PGN-TUTORIAL-FORMAT.md`, odeljak 5), a
`tools/tutorial_translate/translate.py --code sr-Latn` ga upisuje sam.

---

## 7. Ako materijal priprema program (prompt za model)

Ovaj odeljak je namenjen da se prosledi modelu koji iz knjige ili PDF-a pravi
gradivo. Sve ostalo iznad važi i za njega.

Traži izlaz u kome je **jedan deo = jedan blok**, ovako:

```
### Deo: <kratak naziv>
FEN: <polazna pozicija dela>
PGN:
{ uvodna rečenica } 1. e4 { rečenica [%cal Gd2d4][%csl Rd5] } e5 { rečenica } 2. Nf3
```

Pravila koja model najčešće prekrši:

1. **Standardne oznake, ne izmišljene.** `[%cal]` i `[%csl]`, nikako
   „(strelica d2d5)".
2. **Deo samo pokazuje.** Nema pitanja, zadataka ni ponuđenih odgovora. Ako
   knjiga traži rešenje, uvodna rečenica kaže šta se traži, a linija ga
   pokazuje.
3. **FEN mora biti legalan i potpun**, i svaki potez mora da se može odigrati iz
   njega — aplikacija odbija ceo tekst čim jedan ne može.
4. **Komentar ide na potez posle kog se čita**, ne na potez o kome govori
   unazad.
5. **Redni brojevi rečima** — „sedmi red", „u dvanaestom potezu", nikako
   „7. red". Broj sa tačkom glas čita kao kraj rečenice. Brojevi poteza
   ispred samog poteza u `PGN` ostaju kakvi jesu.

Provera pre isporuke: svaki `PGN` provuci kroz program koji ume da odigra poteze
iz datog `FEN`-a. Tekst koji se ne odigra ne treba ni slati — aplikacija ga
odbija, a ručno traženje greške u dugačkoj partiji je najskuplji deo posla.
