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

## Pitanja koja čekaju odluku

1. Da li **svako** odredište dobija rutu, uključujući lanac zadataka i tri
   stanja iz Treninga?
2. Da li se `AiStudioScreen` deli na raskrsnicu i radne ekrane — i da li tri
   njegova režima postaju zasebni ekrani ili jedan ekran sa parametrom?
3. Ostaje li pet kartica u ljusci, ili Trening i Biblioteka menjaju sadržaj kad
   se raskrsnica raščisti?
4. Šta je mreža pre refaktora — test koji prolazi kroz sve rute, ili nešto šire?
