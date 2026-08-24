# Popis prostora aplikacije — 24.8.2026

Šta se sve može otvoriti, kako se do toga stiže, i šta ima rutu a šta nema.
Napravljeno čitanjem koda, ne po sećanju, kao podloga za odluku o
sistematizaciji navigacije. **Ovaj dokument ništa ne predlaže** — opisuje
zatečeno stanje; predlog ide posle odluke.

## Ljuska

Pet mesta u `HomeScreen`, prilagodljivo: na širokom prozoru `NavigationRail` sa
strane, na uskom `NavigationBar` dole.

| kartica | sadržaj |
|---|---|
| Početna | `HomeDashboardTab` — sobe, snimci, brzi ulazi |
| Trening | `AiStudioScreen` (2662 linije) — raskrsnica **i** radni ekran |
| Biblioteka | `HomeBibliotekaTab` |
| Prijatelji | `HomeFriendsTab` |
| Podešavanja | `SettingsScreen` |

## A. Odredišta koja imaju rutu (12)

Sve su na jednom mestu u `lib/routing/app_routes.dart`, sa objašnjenjima. To je
zdrav deo sistema.

| putanja | ekran | parametri | odakle se otvara |
|---|---|---|---|
| `/login` | `LoginRegisterScreen` | `extra: intent` | Početna (3 mesta), preusmerenje iz rutera |
| `/home` | `HomeScreen` | — | posle prijave |
| `/room/:roomCode` | `ChessGameScreen` (3384 linije) | `role` | Početna: pridruži se, napravi sobu, nastavi, „STUDIO" |
| `/analysis` | `AnalysisStudioScreen` | `fen` | Početna, Trening, Moje pozicije (2×), Reprodukcija, Soba |
| `/replay/:recordingId` | `ReplayPlayerScreen` | — | Početna |
| `/tactics` | `TacticsTrainerScreen` | — | raskrsnica Treninga |
| `/endgames` | `EndgameTrainerScreen` | `mode`, filteri | **samo iz `/endgames/izbor`**, preko `pushReplacement` |
| `/endgames/izbor` | `EndgamePickerScreen` | `mode` | raskrsnica Treninga (dva dugmeta: dobitak, remi) |
| `/endgames/greske` | `BlunderWalkScreen` | filteri | raskrsnica Treninga |
| `/scan` | `ScanReviewScreen` | — | Početna, Moje pozicije |
| `/scan/saved` | `SavedPositionsScreen` | — | Početna, Skener |
| `/preferences` | `SettingsScreen` preko trenutnog ekrana | — | Analiza, Soba |

## B. Odredišta bez rute — guraju se `MaterialPageRoute`-om (7)

Ovi ekrani postoje i otvaraju se, ali ih nema u `AppRoutes`. Ne mogu se duboko
povezati, ne obnavljaju se, i „nazad" im zavisi od toga ko ih je gurnuo.

| ekran | odakle se otvara |
|---|---|
| `MyAssignmentsScreen` | Početna |
| `StudentProgressScreen` | Početna |
| `ReviewSessionScreen` | Početna |
| `AssignmentReviewScreen` | **četiri mesta**: Moji zadaci, Pregled zadatka, Rešavač, Napredak učenika |
| `CustomAssignmentOverviewScreen` | Moji zadaci |
| `CustomPuzzleSolverScreen` | Pregled zadatka |
| `LessonViewerScreen` | Moji zadaci |

**Jedan ekran se otvara na oba načina:** `TacticsTrainerScreen` ima rutu
`/tactics` (iz raskrsnice) i istovremeno se gura `MaterialPageRoute`-om iz
`my_assignments_screen.dart:123`. To je najkraći dokaz da pravilo ne postoji.

## C. Odredišta koja su samo stanje unutar ekrana (3)

`AiStudioScreen` ih drži kao vrednost polja `_selectedCategory` i menja sadržaj
oko iste table. Za korisnika su to zasebna mesta; za aplikaciju nisu.

| „mesto" | kako se bira | šta ga pokreće |
|---|---|---|
| Zagonetke: mat u 1 / 2 / 3 | dubina se pamti u `_selectedMateDepth` | `_launchCategory('mate_puzzle')` |
| Osnovno matiranje (tri težine) | `_loadBasicMatePreset(...)` | `_selectedCategory = 'basic_mate'` |
| Dobijena pozicija | — | `_launchCategory('winning_position')` |

Iz iste raskrsnice, tri kartice vode **rutom** (taktika, završnice, greške iz
partija), a tri **stanjem**. Ista lista, dva mehanizma.

## Šta se iz ovoga vidi

**Tri klase odredišta umesto jedne.** Ruta, gurnuti ekran, i stanje u ekranu.
Korisnik ne razlikuje te tri stvari — sve mu je „mesto na koje sam otišao" — ali
se ponašaju različito pri povratku, pri obnavljanju stanja i pri dubokom
povezivanju.

**Raskrsnica i radni ekran su isti fajl.** `AiStudioScreen` je 2662 linije i
radi dva posla: nudi izbor i sam rešava tri od tih izbora. Zato tri kartice
vode rutom a tri ne — i zato je ovo najveća pojedinačna stavka.

**Grana zadataka je cela izvan ruta.** Sedam ekrana, među njima i lanac od tri
u dubinu (Moji zadaci → Pregled → Rešavač → Ocena), a nijedan nema putanju.
`AssignmentReviewScreen` se otvara sa četiri mesta, što je najviše u aplikaciji.

**Jedna ruta se ne može otvoriti direktno.** `/endgames` postoji, ali se do nje
stiže samo `pushReplacement`-om iz izbora. Otvaranje `/endgames?mode=win` spolja
zaobilazi ekran koji sastavlja filtere.

**Nema mreže.** Ekrani iz ovog popisa nemaju skoro nikakve testove — ono što
postoji pokriva table i logiku, ne kretanje. Refaktor navigacije bez toga radi
se naslepo.

## Brojke, da se zna obim

- 12 ruta, 7 ekrana bez rute, 3 mesta koja su stanje.
- 20 fajlova `*_screen.dart`, ukupno 18.758 linija.
- Četiri najveća: soba 3384, Trening 2662, analiza 1855, trener završnica 1529.
- Navigacijskih poziva: 24 preko `AppRoutes`, 11 preko `MaterialPageRoute`.

## Odluke, 24.8.2026

Donete posle ovog popisa, pre nego što je išta pomereno:

1. **Svako odredište dobija rutu — osim jednog.** Šest ekrana iz grane zadataka
   dobija putanju; `CustomPuzzleSolverScreen` je ne dobija, jer nosi povratni
   poziv `onAnswered` i time nije mesto nego **korak u toku** koji drži
   „Pregled zadatka". Ruta koja radi samo kad je neko ručno dohrani objektom je
   ruta samo po imenu.
2. **Ekrani koji traže ceo objekat rade po id-u**, sa dohvatanjem; `extra` je
   prečica kad se objekat već ima, ne uslov.
3. **Tri unutrašnja stanja postaju jedan parametrizovan radni ekran**
   (`/training/drill?category=…`), a raskrsnica ostaje lagana lista kartica.
4. **Putanje su na engleskom**, sve; `/endgames/izbor` i `/endgames/greske` se
   preimenuju dok nema objavljenih dubokih veza.
5. **Četiri taba**, jer prvi ekran ne sme da pretpostavlja odnos sa trenerom:

   | | tab | sadržaj |
   |---|---|---|
   | 1 | Trening | „Nastavi" · taktika, završnice, matovi, greške iz partija |
   | 2 | Časovi | sobe, pridruživanje, snimci, domaći, ponavljanje, napredak |
   | 3 | Biblioteka | analiza, skener, sačuvane pozicije |
   | 4 | Ljudi | prijatelji, učenici, pozivnice |

   Podešavanja izlaze u ikonicu; statistika naloga i PREMIUM idu u njih. Isti
   tabovi za sve, sadržaj se prilagođava — „trener" nije svojstvo naloga nego
   uloga u odnosu i menja se u toku rada.
6. **Imena u kodu su skela.** `AiStudioScreen` nema veze sa AI. Unutrašnja
   imena se smeju zadržati radi mira, ali **naslovi pred korisnikom moraju da
   odgovaraju funkciji**.

## Mreža je postavljena — 24.8.2026

Pre bilo kakvog pomeranja, tri sloja, sva tri prolaze:

- `test/navigation_map_test.dart` — čita `AppRoutes` i ruter kao tekst i pada
  ako ruta postoji a ruter je ne gradi, ako je putanja u ruteru upisana rukom
  umesto konstantom, ako se dve konstante poklope, ili ako putanja nije
  apsolutna i mala slova (parametri kao `:roomCode` su izuzeti).
- `test/training_hub_test.dart` — svaka kartica raskrsnice vodi tamo gde piše,
  i ništa se ne okida samo od sebe. To je ono što se pri deobi najlakše
  nečujno pomeri, jer tri kartice danas idu rutom a tri stanjem.
- `test/navigation_flow_test.dart` — otvara šest putanja i traži da na stablu
  bude baš onaj ekran, gura i vraća se (`push` pa `pop`), i proverava da
  nepostojeća putanja daje poruku umesto pada.

Uz to je iz `app_router.dart` izdvojen `appRouteTable` (i `appRouteErrorBuilder`),
da test može da otvori aplikaciju **na bilo kojoj putanji**. Bez toga svaki
navigacioni test počinje na Početnoj i time postaje test svega usput — a Početna
otvara sokete.

Namerno **nisu** pokriveni soba i analiza: prva diže sokete, druga motor. Njih
pokrivaju sopstveni testovi.

## Korak 1 urađen — raskrsnica je izašla, 24.8.2026

`AiStudioScreen` više nije i raskrsnica i radni ekran.

- **`TrainingHubScreen`** je nov, lagan ekran: kartice i ništa drugo, bez table
  i bez motora. Svih sedam kartica sada radi istu stvar — imenuje putanju.
- **Tri unutrašnja stanja su postala jedna ruta sa parametrom**:
  `/training/drill?category=mate_puzzle&depth=2`, `…&category=basic_mate&level=…`,
  `…&category=winning_position`. Radni ekran ih prima kroz konstruktor i otvara
  se odmah na vežbi.
- **Putanje su prevedene na engleski**: `/endgames/izbor` → `/endgames/picker`,
  `/endgames/greske` → `/endgames/blunders`.
- Kartica „Trening" u ljusci sada drži raskrsnicu, ne radni ekran.
- „Nazad" iz vežbe otvorene rutom **izlazi** sa nje; stara petlja (povratak na
  listu unutar istog ekrana) ostaje samo dok postoji poslednji pozivalac.

**Nađeno zato što je nešto konačno otvorilo taj ekran u testu:**

1. Red sa tri dugmeta (`Analiza`, `Probaj Ponovo`, `Naredna Pozicija`) prelivao
   se za 80 piksela — u release buildu se to ne vidi, treće dugme prosto nema.
   Sada je `Wrap`.
2. **Dva tajmera su nadživljavala ekran**: protivnikov potez i sekunda pauze pre
   motorovog odgovora. Oba se sada otkazuju u `dispose`; drugi je zbog toga
   pretvoren iz `Future.delayed` u `Timer`, jer se `Future` ne može otkazati.

**Ostalo otvoreno:** učitavanje preseta za `basic_mate` čeka dva
`await Future.delayed` koja se ne mogu otkazati, pa ekran i dalje ostavi tajmer
za sobom. Ta ruta je zato izuzeta iz testa, sa objašnjenjem na licu mesta —
prepisivanje tog toka je zaseban posao.

**O formatiranju:** `dart format` nad tim fajlom pravi 850 izmenjenih linija
umesto 40 i obara `flutter analyze` (formater razbija `if (x) return;` na dva
reda, a linter traži vitičaste zagrade). Zato je izostavljen; taj fajl se
formatira kad se bude delio.

## Korak 2 urađen — grana zadataka ima putanje, 24.8.2026

Šest novih ruta, i time cela grana koja je dosad bila izvan sistema:

| putanja | ekran |
|---|---|
| `/assignments` | `MyAssignmentsScreen` |
| `/assignments/:id/review` | `AssignmentReviewScreen` (`?title=` je ukras) |
| `/assignments/:id/positions` | `CustomAssignmentOverviewScreen` |
| `/assignments/:id/lesson` | `LessonViewerScreen` |
| `/review` | `ReviewSessionScreen` |
| `/students/:id` | `StudentProgressScreen` (`?name=` je ukras) |

**Id je ugovor, objekat je prečica.** Dva ekrana se grade od celog
`AssignmentDetail`-a, što je u redu kad ih otvara lista koja ga već ima, a
beskorisno iz veze, iz obnovljene sesije i iz testa. Zato postoji
`AssignmentDetailGate`: prosledi mu se `extra` kad se objekat ima i ništa se ne
dohvata, a bez njega se dohvata po id-u. Ni jedan od ta dva ekrana nije morao da
nauči šta je stanje učitavanja da bi dobio putanju.

Naslov zadatka i ime učenika idu kao upitni parametri i **ukras su** — ekran ih
prikaže dok odgovor ne stigne, i živi bez njih.

### Šta je namerno ostalo bez rute

- **`CustomPuzzleSolverScreen`** — nosi povratni poziv `onAnswered`, dakle nije
  mesto nego korak u toku koji drži „Pregled zadatka".
- **Taktika iz zadatka** (`my_assignments_screen.dart`) — prosleđuje **spisak
  preostalih zagonetki**, a spisak id-eva u putanji nije putanja. Da bi i ovo
  postalo ruta, ekran taktike bi morao sam da dohvati šta je preostalo po
  `assignmentId`; to je zaseban posao i vredi ga uraditi, jer „preostalo iz ovog
  domaćeg" **jeste** mesto.

Posle ovoga u celoj aplikaciji ostaju **tri** `MaterialPageRoute` poziva: ta dva
gore i jedan unutar samog rutera.

## Korak 3 urađen — četiri taba, 24.8.2026

| | tab | šta drži |
|---|---|---|
| 1 | **Trening** | raskrsnica vežbi — i podrazumevani ekran pri otvaranju |
| 2 | **Časovi** | sobe, pridruživanje, snimci, domaći, ponavljanje |
| 3 | **Biblioteka** | analiza, skener, sačuvane pozicije |
| 4 | **Ljudi** | prijatelji, učenici, pozivnice |

**Podešavanja su izašla iz tabova** u ikonicu u traci. Imala su rutu odranije
(`/preferences`), koja se otvara **preko** trenutnog ekrana umesto da ga ruši —
a tab je mesto u kojem se boravi, i u podešavanjima niko ne boravi. Uz to,
četiri odredišta sa rečima ispod njih stanu na 360 dp lakše nego pet.

**Zašto Trening prvi:** stari prvi tab je pretpostavljao odnos — sobe, snimci,
domaći. Ko vežba sam ili pravi studije, video je prvo tuđi posao. Vežbanje je
jedina stvar koja važi za svakoga ko otvori aplikaciju.

**Usput je otvoren put za testiranje ljuske.** `HomeScreen` u testu više ne
otvara soket ni klijent za naplatu — isti onaj čuvar po tipu vezivanja koji AI
ekran već koristi za svoju proveru servera. Bez toga svaki test koji samo
otvori ljusku pada na „a Timer is still pending", pa se tabovi nisu mogli
pokriti uopšte.

## Nađeno pri prvoj probi uživo — 24.8.2026

Prijava: „ušao sam u Mat u N i vratio se, izgubio sam tabove sa strane"
(Windows). U logu ničega — nije pad nego ponašanje, i bilo je dvoje.

**Strelica u ekranu nije izlazila sa rute.** Radila je ono što je radila dok je
taj ekran bio i raskrsnica: `_selectedCategory = null`, što nacrta **unutrašnju**
raskrsnicu koja i dalje živi u tom fajlu — preko ljuske, dakle bez tabova sa
strane. Sada, kad je ekran otvoren kao ruta, strelica **izlazi**.

**A prava strelica je bila druga.** Na Windows-u je prozor uvek landscape, a taj
raspored **namerno nema traku sa naslovom** — tabla se računa od visine prozora.
Dok je ekran bio unutar ljuske to je bilo u redu, jer je rail stajao pored
njega; komentar u `home_screen.dart` to izričito kaže. Otkad je ruta, rail je
pokriven, pa je jedini izlaz strelica u landscape zaglavlju — i baš ona je
vodila u unutrašnju raskrsnicu.

Probano je i drugo rešenje — vratiti traku i u landscape — pa odbačeno: uzima
38 piksela visine tabli u rasporedu koji je namerno kvadratni. Umesto toga obe
strelice sada rade isto: kad je ekran svoja ruta, izlaze sa nje.

Test to vozi kao korisnik: otvori ljusku u širokom prozoru, pritisne „Mat u 2",
pa **strelicu na ekranu**, i traži da rail bude tu. Pada bez popravke.

## Tabovi dovršeni — 24.8.2026

**Statistika naloga je otišla u Podešavanja.** Stajala je na prvom tabu, odmah
ispod dugmadi za pokretanje časa — ime plana i broj sačuvanih pozicija su
činjenice o nalogu, a ne o današnjem radu. Sada je `AccountStatsCard`, u
odeljku „NALOG", i **sama dohvata** brojeve: ekran na kojem živi otvara se preko
onoga što si radio, pa iznad njega nema nikoga da mu ih doda.

Usput je iz ljuske nestao i poziv `/users/me/stats` pri pokretanju — jedan
zahtev manje na startu — i `_showPremiumModal`, koji je **već bio mrtav** pre
ove izmene: definisan, nigde pozvan. Ako ulaz u kupovinu bude trebao, mesto mu
je uz onaj `FREE`/`PREMIUM` čip, dakle u toj kartici.

**Traka „Nastavi" je na vrhu Treninga.** Nudi samo ono što je stvarno ostalo
otvoreno: čas koji još traje i analizu koja je sačuvana. Ništa se ne izmišlja i
ništa se ne predlaže.

Kad nema ničega, **ne prikazuje se ništa** — ni kartica koja objašnjava da nema
ničega. Prazno stanje koje treba pročitati gore je od praznine koje nema. Oba
slučaja drži test.

Time je prvi ekran i univerzalan (svi vežbaju) i ličan (tvoje je gore), a da
pritom ne pretpostavlja da imaš trenera.

**Ispravka istog dana: podešavanja su bila nevidljiva na Windows-u.** Ikonica je
otišla u traku sa naslovom — a ljuska u landscape rasporedu **nema traku**, i
Windows je uvek landscape. Iznad rail-a stoji komentar koji tačno to objašnjava
za zvonce, iz ranijeg kruga: sve što živi samo u traci na toj platformi ne
postoji. Ponovljena greška, uz postojeće upozorenje.

Sada je ulaz u **podnožju rail-a**, gde ga desktop i traži, a ikonica u traci
ostaje za uske prozore koji nemaju rail. Prozor koji ima oboje pokaže oboje i to
ne smeta. Test traži da u rail-u postoji ulaz i pada bez njega.

## Pitanja na koja je odgovoreno gore

1. Da li **svako** odredište dobija rutu, uključujući lanac zadataka i tri
   stanja iz Treninga?
2. Da li se `AiStudioScreen` deli na raskrsnicu i radne ekrane — i da li tri
   njegova režima postaju zasebni ekrani ili jedan ekran sa parametrom?
3. Ostaje li pet kartica u ljusci, ili Trening i Biblioteka menjaju sadržaj kad
   se raskrsnica raščisti?
4. Šta je mreža pre refaktora — test koji prolazi kroz sve rute, ili nešto šire?
