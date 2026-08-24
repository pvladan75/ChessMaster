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

## Pitanja na koja je odgovoreno gore

1. Da li **svako** odredište dobija rutu, uključujući lanac zadataka i tri
   stanja iz Treninga?
2. Da li se `AiStudioScreen` deli na raskrsnicu i radne ekrane — i da li tri
   njegova režima postaju zasebni ekrani ili jedan ekran sa parametrom?
3. Ostaje li pet kartica u ljusci, ili Trening i Biblioteka menjaju sadržaj kad
   se raskrsnica raščisti?
4. Šta je mreža pre refaktora — test koji prolazi kroz sve rute, ili nešto šire?
