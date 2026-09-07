# Studio za tutorijal — kako se piše

Kratko uputstvo za trenera koji piše tutorijal, i ujedno ugovor za bilo koga —
čoveka ili model — ko priprema materijal za ovu aplikaciju.

**Pisano na srpskom namerno.** Ostali dokumenti u `docs/` su na engleskom; ovaj
je za trenere koji ga koriste, kao i pravni tekstovi. Ne prevoditi.

Studio postoji samo na Windows-u. Na telefonu se tutorijal i dalje uređuje
starim editorom koraka, koji je zamrznut.

---

## 1. Dve reči koje treba razlikovati

**Takt** je jedan trenutak: jedna pozicija, rečenica o njoj, i ono što je na njoj
nacrtano. Takt nastaje sam od sebe — čim povučeš potez na tabli, dobio si sledeći
takt.

**Deo** je jedna celina: **jedan tip zadatka i jedna polazna pozicija.** Deo ima
onoliko taktova koliko poteza u njemu odigraš.

**Zlatno pravilo:**

> Potezi se vuku na tabli. Nov deo se pravi **samo** kad se menja tip zadatka ili
> kad se skače na drugu poziciju.

Ako za svaki potez praviš nov deo, radiš deset puta više posla i dete dobija
deset tabli umesto jedne priče.

## 2. Tri tipa dela

Bira se u polju **„Tip zadatka"**, i važi za **ceo deo**:

| Tip | Šta dete radi |
|---|---|
| **Samo prikaži** | Gleda i sluša. Prolazi potez po potez kroz liniju koju si napisao. |
| **Traži potez na tabli** | Vidi poziciju i mora da odigra potez. Tačan potez zadaješ tako što ga **odigraš na tabli** dok je ovaj tip izabran. |
| **Traži odgovor iz liste** | Vidi poziciju i bira jedan od ponuđenih odgovora. |

**Pitanje se uvek postavlja o polaznoj poziciji dela.** Ako hoćeš da pitaš nešto
posle tri poteza demonstracije, ta tri poteza su jedan deo, a pitanje je sledeći
deo — napravljen preko **„+ Dodaj deo" → „Nastavi odavde"**. Pregledač ta dva
spaja na **jednoj tabli**, bez resetovanja, pa dete ne vidi šav.

## 3. Zašto pitanje ne sme da nosi liniju

Linija dela **nije sakrivena** od deteta — ona *jeste* lekcija, i dete može da je
prolista dugmetom „Sledeći potez". Zato deo koji traži potez a nosi liniju
pokazuje detetu sopstveni odgovor.

Aplikacija to odbija sama, na tri mesta:

* kad izabereš „Traži potez na tabli" nad delom koji ima poteze, pita te
  („Dete bi videlo odgovor") i nudi da liniju ukloni;
* ako otvoriš stariji tutorijal koji je već takav, gore stoji crvena traka koja
  **imenuje** te delove;
* čuvanje se odbija dok takav deo postoji.

Server to ne može da proveri — on `pgn` čuva kao običan tekst i nema čitač
poteza. Zato je ovo jedina odbrana koju aplikacija donosi sama.

**Deo bez ijednog poteza je potpuno ispravan deo.** „Pogledaj polje d5" plus
strelica je cela lekcija; takav deo se čuva sa svojim komentarom i oznakama.

## 4. Ponuđeni odgovori

* **dva do četiri** odgovora;
* **tačno jedan** označen kao tačan (kružić levo od teksta);
* prazni odgovori se ne broje.

Ne piši `!` i `??` u tekst odgovora — dete ih vidi, pa je pitanje rešeno bez
šaha.

## 5. Komentar, strelice i polja

**Komentar pripada taktu i čita se pre poteza koji odlazi iz njega.** Redosled
koji dete dobija je: vidi poziciju → čuje šta se o njoj kaže → odigra se sledeći
potez. Zato panel **„Tok"** i crta rečenicu **između** poteza koji je stigao i
poteza koji odlazi.

Ako hoćeš da nešto kažeš „posle poteza", to je rečenica **sledećeg takta** — ne
druga rečenica na istom.

**Crtanje** je traka ispod table: **„Strelica"**, **„Polje"**, krugovi sa bojama,
**„Obriši oznake"**.

* strelica se crta klikom na dva polja; **isti par klikova je briše**;
* polje se označava jednim klikom; ponovni klik ga briše;
* **brisanje ne gleda boju** — ispravlja se „pogrešna strelica", ne „pogrešna
  boja";
* prelazak na drugi takt zaboravlja započetu strelicu, a režim crtanja ostaje
  uključen.

## 6. Tab „PGN" — tekst dela

Treći tab pored „Tok" i „Stablo" pokazuje deo kao tekst i prima tekst spolja.
Ovo su jedina vrata kroz koja anotirana partija (iz knjige, iz motora, iz
programa koji čita PDF) ulazi u tutorijal **sa svojim komentarima i oznakama**.

Format je standardni PGN, isti koji pišu Lichess i šahovski programi:

```
1. e4 { Beli zauzima centar. [%cal Gd2d4][%csl Rd5] } e5 2. Nf3
```

* `{ … }` — komentar tog poteza;
* `[%cal Gd2d4]` — strelica sa d2 na d4;
* `[%csl Rd5]` — obojeno polje d5;
* `( … )` — sporedna varijanta;
* više oznaka se odvaja zarezom: `[%cal Gd2d4,Rf1c4]`.

**Slova boja:** `G` zelena · `R` crvena · `B` plava · `O` narandžasta ·
`P` ljubičasta. (Nema žute.)

**Kucanje ništa ne menja dok ne pritisneš „Primeni".** Dok tekst nije primenjen,
pored dugmeta piše „izmenjeno".

**Šta „Primeni" odbija:**

* tekst u kome neki potez ne može da se odigra — odbija se **ceo**, uz broj
  takvih poteza. Deo ostaje netaknut;
* ako nalepljeni tekst nosi svoju polaznu poziciju (`[FEN]`) različitu od
  pozicije dela, pita se: **„Uzmi tu poziciju"** (deo se premešta na nju),
  **„Zadrži postojeću"** (tekst se odbija) ili **„Odustani"**.

Kursor u tekstu bira potez: tabla i „Tok" idu za njim. **Desni klik** na potez
nudi „Dodaj strelicu", „Označi polje" i „Dodaj komentar" — prve dve postave
kursor na taj potez i uključe crtanje **na tabli**.

## 7. Redosled rada i čuvanje

1. **„Unos pozicije"** ako deo ne počinje iz osnovne pozicije.
2. Povuci poteze i piši komentare po taktovima.
3. **„+ Dodaj deo"** kad menjaš tip ili poziciju („Nastavi odavde" zadržava
   poziciju na kojoj si stao).
4. **„Pregledaj kao učenik"** — otvara tutorijal onako kako ga dete vidi.
   **Ništa ne šalje na server**; odgovori u pregledu se ne beleže.
5. **„Sačuvaj tutorijal"** — jedan upis, na kraju. Svaki sledeći pritisak menja
   **isti** tutorijal, ne pravi nov.

Tutorijal mora da ima naziv. Poslednji deo se ne može obrisati. Nedovršen rad se
sam čuva na računaru; kad sledeći put otvoriš nov tutorijal, pitaće te
(„Odustajem" / „Nov" / „Nastavi") — **„Nov" briše nezavršeni**.

---

## 8. Ako materijal priprema program (prompt za model)

Ovaj odeljak je namenjen da se prosledi modelu koji iz knjige ili PDF-a pravi
gradivo. Sve ostalo iznad važi i za njega.

Traži izlaz u kome je **jedan deo = jedan blok**, ovako:

```
### Deo: <kratak naziv>
Tip: prikaz | traži potez | traži odgovor
FEN: <polazna pozicija dela>
Zadatak: <samo ako tip nije „prikaz">
Odgovori: <samo za „traži odgovor": dva do četiri, tačan označen sa (tačno)>
PGN:
1. e4 { rečenica [%cal Gd2d4][%csl Rd5] } e5 { rečenica } 2. Nf3
```

Pravila koja model najčešće prekrši:

1. **Standardne oznake, ne izmišljene.** `[%cal]` i `[%csl]`, nikako
   „(strelica d2d5)".
2. **Jedan tip po delu.** Demonstracija i pitanje su **dva** dela; pitanje se
   postavlja o polaznoj poziciji svog dela.
3. **Deo koji traži potez ne sme da ima poteze u `PGN`** — samo komentar i
   oznake. Tačan potez ide u `Zadatak`/`Odgovori`, ne u liniju.
4. **Bez `!` i `??` u ponuđenim odgovorima.**
5. **FEN mora biti legalan i potpun**, i svaki potez mora da se može odigrati iz
   njega — aplikacija odbija ceo tekst čim jedan ne može.
6. **Komentar ide na potez posle kog se čita**, ne na potez o kome govori
   unazad.

Provera pre isporuke: svaki `PGN` provuci kroz program koji ume da odigra poteze
iz datog `FEN`-a. Tekst koji se ne odigra ne treba ni slati — aplikacija ga
odbija, a ručno traženje greške u dugačkoj partiji je najskuplji deo posla.
