# Studio za tutorijal — kako se piše

Kratko uputstvo za trenera koji piše tutorijal, i ujedno ugovor za bilo koga —
čoveka ili model — ko priprema materijal za ovu aplikaciju.

**Pisano na srpskom namerno.** Ostali dokumenti u `docs/` su na engleskom; ovaj
je za trenere koji ga koriste, kao i pravni tekstovi. Ne prevoditi.

Studio postoji samo na Windows-u. Na telefonu se tutorijal i dalje uređuje
starim editorom koraka, koji je zamrznut.

**Aplikacija je na engleskom**, pa su nazivi dugmadi i polja u ovom uputstvu
navedeni onako kako stoje na ekranu — „Save tutorial", „Flow" i tako dalje.

---

## 1. Dve reči koje treba razlikovati

**Takt** (na ekranu *beat*) je jedan trenutak: jedna pozicija, rečenica o njoj, i ono što je na njoj
nacrtano. Takt nastaje sam od sebe — čim povučeš potez na tabli, dobio si sledeći
takt.

**Deo** (na ekranu *part*) je jedna celina: **jedan tip zadatka i jedna
polazna pozicija.** Deo ima
onoliko taktova koliko poteza u njemu odigraš.

**Zlatno pravilo:**

> Potezi se vuku na tabli. Nov deo se pravi **samo** kad se menja tip zadatka ili
> kad se skače na drugu poziciju.

Ako za svaki potez praviš nov deo, radiš deset puta više posla i dete dobija
deset tabli umesto jedne priče.

## 2. Tri tipa dela

Bira se u polju **„Task type"**, i važi za **ceo deo**:

| Tip | Šta dete radi |
|---|---|
| **Show only** | Gleda i sluša. Prolazi potez po potez kroz liniju koju si napisao. |
| **Ask for move on board** | Vidi poziciju i mora da odigra potez. Tačan potez zadaješ tako što ga **odigraš na tabli** dok je ovaj tip izabran. |
| **Ask for answer from list** | Vidi poziciju i bira jedan od ponuđenih odgovora. |

**Pitanje se uvek postavlja o polaznoj poziciji dela.** Ako hoćeš da pitaš nešto
posle tri poteza demonstracije, ta tri poteza su jedan deo, a pitanje je sledeći
deo. Ne praviš ga ručno: stani na takt posle trećeg poteza i u panelu
**„Tutorial contents"** pritisni **„Find the move"** ili **„Choose the
answer"**. Studio sam deli deo — demonstracija ostaje u delu ispred, pitanje
postaje nov deo na toj poziciji, a ono što je u liniji išlo dalje nastavlja se
iza pitanja. Deo bez poteza se ne deli, nego sam postaje pitanje. Pregledač te
delove spaja na **jednoj tabli**, bez resetovanja, pa dete ne vidi šav.

## 3. Zašto pitanje ne sme da nosi liniju

Linija dela **nije sakrivena** od deteta — ona *jeste* lekcija, i dete može da je
prolista dugmetom „Next move". Zato deo koji traži potez a nosi liniju
pokazuje detetu sopstveni odgovor.

Aplikacija to odbija sama, na tri mesta:

* kad u „Task type" izabereš „Ask for move on board" nad delom koji ima
  poteze, pita te („The student would see the answer") i nudi da liniju ukloni
  („Remove line and ask question");
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
potez. Zato panel **„Flow"** i crta rečenicu **između** poteza koji je stigao i
poteza koji odlazi.

Ako hoćeš da nešto kažeš „posle poteza", to je rečenica **sledećeg takta** — ne
druga rečenica na istom.

**Crtanje** je traka ispod table: **„Arrow"**, **„Square"**, krugovi sa bojama,
**„Clear marks"**.

* strelica se crta klikom na dva polja; **isti par klikova je briše**;
* polje se označava jednim klikom; ponovni klik ga briše;
* **brisanje ne gleda boju** — ispravlja se „pogrešna strelica", ne „pogrešna
  boja";
* prelazak na drugi takt zaboravlja započetu strelicu, a režim crtanja ostaje
  uključen.

## 6. Tab „PGN" — tekst dela

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
* `( … )` — sporedna varijanta;
* više oznaka se odvaja zarezom: `[%cal Gd2d4,Rf1c4]`.

**Slova boja:** `G` zelena · `R` crvena · `B` plava · `O` narandžasta ·
`P` ljubičasta. (Nema žute.)

**Kucanje ništa ne menja dok ne pritisneš „Apply".** Dok tekst nije primenjen,
pored dugmeta piše „edited".

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
se potezi odatle ne mogu odigrati), a **„Cancel"** ne menja ništa. Dete otvara
deo na poziciji koju si izabrao, zato se to pita, a ne pretpostavlja.

Ako tekst bez `[FEN]` ne može da se odigra ni od pozicije dela ni od osnovne
pozicije, ništa se ne pita: odbija se, uz napomenu da tekst nema polaznu
poziciju, pa se ne vidi odakle počinje.

Kursor u tekstu bira potez: tabla i „Flow" idu za njim. **Desni klik** na potez
nudi „Add arrow", „Mark square" i „Add comment" — prve dve postave
kursor na taj potez i uključe crtanje **na tabli**.

## 7. Redosled rada i čuvanje

1. **Naziv i jezik** („Language") — jezik odlučuje kojim glasom se tutorijal
   čita (odeljak 8).
2. **„Position setup"** (ikonica klizača gore desno) ako deo ne počinje iz
   osnovne pozicije.
3. Povuci poteze i piši komentare po taktovima.
4. Nov deo: **„New demonstration"** za sledeći primer — „From here" ga počinje
   na poziciji gde se linija otvorenog dela završava, „New board" iz osnovne
   pozicije; **„Find the move"** ili **„Choose the answer"** za pitanje na
   taktu na kome stojiš (odeljak 2).
5. **„Preview as student"** — otvara tutorijal onako kako ga dete vidi.
   **Ništa ne šalje na server**; odgovori u pregledu se ne beleže.
6. **„Save tutorial"** — jedan upis, na kraju. Svaki sledeći pritisak menja
   **isti** tutorijal, ne pravi nov.

Tutorijal mora da ima naziv. Poslednji deo se ne može obrisati. Nedovršen rad se
sam čuva na računaru; kad sledeći put otvoriš nov tutorijal, pitaće te
(„Cancel" / „New" / „Continue") — **„New" briše nezavršeni**.

---

## 8. Glas koji čita tutorijal

**Tutorijal kaže na kom je jeziku, i to biraš ti.** Polje **„Language"** stoji u
redu sa nazivom i oznakama: **„Not set"** ili jedan od sedam jezika — English,
Serbian (Latin), Serbian (Cyrillic), German, Spanish, Italian, French. Samo tih
sedam, jer su to jezici čije poteze aplikacija ume da izgovori; jezik čiji bi
potezi bili pročitani engleskim rečima se ne nudi.

Čita ga **glas sa uređaja na kome se sluša**, ne sa servera — sistemski glas
Androida ili Windowsa. Video je posebna priča, niže.

**Kad je jezik izabran:**

1. **Uređaj sam bira glas tog jezika.** Za srpsku latinicu: srpski glas, a ako
   ga nema hrvatski, pa bosanski. Windows nema srpski glas, a hrvatski
   („Microsoft Matej") čita srpsku latinicu ispravno — zato je on dovoljan. Za
   **ćirilicu** važi samo srpski glas, jer hrvatski ćirilicu ne ume da pročita.
2. **Potezi u komentaru se izgovaraju na tom jeziku.** „Bc4" postaje „lovac ce
   četiri", a ne „bishop c four". Ono što si napisao se ne menja — menja se samo
   ono što glas dobija.
3. **Nikad glasom drugog jezika.** Ako uređaj nema glas za taj jezik, umesto ▶
   stoji ikonica prekriženog zvučnika; dodir na nju kaže zašto i šta treba
   instalirati. Za srpsku latinicu na Windows-u: *Settings → Time & language →
   Speech → Add voices*, pa hrvatski. Tutorijal se i dalje prolazi dugmadima —
   to je isti tutorijal, ne slabiji.
4. **Windows ponekad navede jezik za koji nema glas.** Tada se čitanje zaustavi
   na prvoj rečenici, sa istom porukom, umesto da tutorijal protrči bez zvuka.

**Kad je jezik „Not set"** — a takvi su svi tutorijali sačuvani pre 11.9.2026,
dok im ne izabereš jezik — sve je kao ranije: čita glas izabran u Podešavanjima
aplikacije, i jezik komentara i jezik glasa moraju da se poklope ručno. Srpski
tekst pročitan engleskim glasom ne prijavi grešku nego zvuči kao da radi; zato
je bolje izabrati jezik. Ako uređaj nema nijedan upotrebljiv glas, dugme ▶ se
uopšte ne crta, a tutorijal se prolazi dugmadima.

**Na tvom računaru i na detetovom telefonu čuju se različiti glasovi.**
„Preview as student" čita glasom *tvog* uređaja — na Windows-u hrvatskim
Matejem — a dete na Androidu čuje Googleov srpski glas. Oba čitaju isti tekst
istim pravilima.

**Brzinu govora bira vlasnik uređaja**, klizačem u Podešavanjima. **Tekst se
ispisuje u ritmu glasa koji čita:** brzina se ne pretpostavlja nego meri iz
rečenica koje je *taj* glas već pročitao, za svaki glas posebno. Prva rečenica
svakog glasa u sesiji ide na procenu; od druge se ispis i govor poklapaju.

**Video je drugačiji.** Glas za **izvoz videa** biraš ti, i on važi za sve koji
snimak gledaju. Dijalog za izvoz se otvara na glasovima jezika tutorijala. Za
video hrvatski glas **ne važi** kao srpski: server nema hrvatski rečnik poteza,
pa bi potezi bili izgovoreni engleskim rečima. Ako server nema srpski glas,
dijalog se otvara kao ranije.

**Tutorijal koji ne pišeš u studiju** — JSON fajl ili prevod — nosi jezik u
polju `"language"` (`docs/PGN-TUTORIAL-FORMAT.md`, odeljak 9), a
`tools/tutorial_translate/translate.py --code sr-Latn` ga upisuje sam.

---

## 9. Ako materijal priprema program (prompt za model)

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
