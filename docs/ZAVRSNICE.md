# Završnice: rudarenje pozicija iz PGN baza

Stanje na 23.8.2026.

Alat koji iz majstorskih partija izdvaja završničke pozicije upotrebljive kao
vežba. Živi u `puzzles/`, pokreće se ručno na radnoj mašini i **nije deo
aplikacije** — ni backend ni klijent ga ne pozivaju. Izlaz su JSON fajlovi koji
tek treba da uđu u bazu.

## Zašto postoji

Prethodnik je bio `zavrsnice.py` u folderu sa bazama: uzimao je svaku poziciju
koja odgovara materijalnom šablonu i u kojoj strana na potezu ima bar +2.00. To
nije isto što i zadatak. Merenjem na njegovom izlazu:

- medijana razlike između prvog i drugog poteza bila je **11 centipiona** — u
  većini pozicija desetak poteza jednako drži rezultat, dakle nema šta da se
  nađe;
- kod `RookBishopVsRook` je **30% pozicija imalo figuru koja prosto visi**, a
  38% je prestajalo da bude taj tip završnice unutar četiri poluposteza.

Primer koji je pokrenuo prepravku, `1r6/8/2K5/5p2/6k1/8/8/1R6 w - - 0 73`:
rešenje je `Rxb8`, uzimanje nebranjenog topa, posle čega pozicija više nije
T+P protiv T.

## Alati

| fajl | šta radi |
|---|---|
| `endgame_miner.py` | rudar; jedan tip završnice po pokretanju |
| `mine_session.py` | interaktivno: pita kvotu po tipu i pokreće rudar |
| `coverage_report.py` | matrica pokrivenosti baza × tip |
| `dedupe_endgames.py` | čišćenje duplikata iz gotovih fajlova |
| `run_all_endgames.ps1` | neinteraktivno pokretanje svih tipova sa jednom kvotom |
| `get_syzygy6.ps1` | preuzimanje šestofiguraških tablica, sa nastavkom |
| `verify_syzygy6.ps1` | provera SHA-256 suma skinutih tablica, sa nastavkom |
| `rejudge_endgames.py` | ponovno suđenje iz tablica i sa Lichess API-ja |

Na strani backenda: `chess_backend/import_endgames.js` prenosi izlaz u bazu.

Uobičajen ulaz je `mine_session.py` — prikaže stanje po tipu i pita koliko se
pozicija traži:

```
PawnEnding
  nadjeno do sada:   301
  pregledano partija: 14316 od 97330 (14.7%)
  neobidjeno:        83014 partija, po dosadasnjem prinosu jos oko 1745
  koliko ukupno zelite? (Enter = preskoci):
```

Putanje se podešavaju preko `CHESS_BASE_DIR`, `STOCKFISH_PATH` i `SYZYGY_PATH`,
ili preko `--base-dir`, `--stockfish`, `--syzygy`.

## Podaci

**PGN baze.** 43 fajla po igraču, **97.330 partija**, od čega 91.796
jedinstvenih po potezima (5,7% su duplikati). Pored njih stoje dve velike baze
koje još nisu korišćene: `LumbrasGigaBase_OTB_Complete.pgn` sa oko **10,5
miliona** partija i `LumbrasGigaBase_Online_Complete.pgn` sa oko **7,1 miliona**.

**Syzygy tablice.** Set za tri do pet figura, 290 fajlova, 940 MB, i
šestofiguraški set, 730 fajlova, 149,2 GB — kod oba su sve kontrolne sume
proverene (šestofiguraški 23.8.2026, `verify_syzygy6.ps1`).

**Izlaz.** `_mining/<Tip>.json` uz `_mining/<Tip>.json.done`, `.games` i
`.visited` za nastavak.

## Sedam tipova završnica

`PawnEnding`, `RookPawnVsRook`, `BishopVsKnight`, `QueenVsRook`,
`RookBishopVsRook`, `DoubleBishopVsBishopKnight`, `OppositeBishops`.

Koliko ih uopšte ima u zbirci, sve pozicije pre proređivanja:

| tip | pojavljivanja |
|---|---|
| BishopVsKnight | 85.659 |
| RookBishopVsRook | 36.389 |
| OppositeBishops | 34.944 |
| PawnEnding | 29.429 |
| DoubleBishopVsBishopKnight | 26.317 |
| RookPawnVsRook | 14.635 |
| QueenVsRook | 8.181 |

Lovac protiv skakača javlja se deset puta češće od dame protiv topa. To je
argument koji tip učiti prvo, i nije mišljenje nego brojanje.

## Kriterijum

Pozicija je zadatak kad **mala, prepoznatljiva grupa poteza dostiže ishod, a sve
ostalo pada ispod njih.** Koji ishod — dobitak ili održanje remija — je režim
(`--mode win|draw|any`).

Ključna ispravka u odnosu na prvu verziju: **ne poredi se prvi potez sa drugim,
nego se potezi grupišu po ishodu.** U poziciji
`8/4k3/8/1p2Pp2/p7/P1K1P3/1P6/8 w - - 1 42` i `Kd3` i `e4` dobijaju, a preostalih
sedam poteza remizira ili gubi. Razlika između ta dva je tri centipiona, pa bi
ih poređenje prvog sa drugim odbacilo. Na punom uzorku **68% prihvaćenih pozicija
ima više od jednog dobitnog poteza** — sa starim kriterijumom ostala bi trećina.

Tolerancija u centipionima ni ne bi radila: na dubini 26 je `Kd3` mat a `e4`
„samo" +83; kao brojevi razlikuju se hiljadama, kao ishod su isti potez dvaput.

### Redosled filtera

Od najjeftinijeg ka najskupljem. Prvih pet je čista aritmetika, bez motora:

1. najviše dve pozicije iz jedne partije (`--per-game`);
2. razmak od poslednje poslate motoru (`--min-ply-gap`);
3. razmak od poslednje prihvaćene (`--min-accept-gap`);
4. pozicija nije mat ili pat;
5. materijal odgovara tipu, i pozicija nema više od 16 figura (`--max-pieces`).

Zatim, i dalje bez motora:

6. ne visi figura — uzimanje nebranjene figure ili uzimanje jeftinijom;
7. nema forsiranog mata u dva (`--reject-mate-in`).

Tek onda ide motor ili tablica, pa unutar toga opet od jeftinijeg: najbolji
potez nije uzimanje figure, završnica se ne raspada u prva četiri poluposteza,
nije očigledno na maloj dubini. Duboku proveru plaćaju samo preživeli.

### Motor ili tablica

Ruta se bira jednom, po broju figura, i ne menja se usred procene. **Šest i
manje ide na tablice** — tamo ishod nije procena nego činjenica. Sedam i više
ide na motor: plitka pretraga od 6 poluposteza u zasebnom procesu, duboka na
dubinu 20 sa ograničenjem od 3 sekunde, i provera na dubini 24 sa 10 sekundi
samo za one koje su prošle sve ostalo.

Granica je bila pet do 23.8.2026, dok je na disku stajao samo trofiguraški do
petofiguraški set. `--syzygy-max-pieces` je i dalje podesiv, jer nema svaka
mašina 150 GB, ali je podrazumevana vrednost sada 6.

Motoru se prosleđuje `SyzygyPath`, pa Stockfish sam proba tablice kad varijanta
siđe ispod sedam figura.

**Dva foldera, jedan string.** Setovi stoje odvojeno (`3-4-5` i `6`), a
`chess.syzygy.open_tablebase()` otvara jedan folder, pa se spajaju preko
`os.pathsep` — tačno onog znaka kojim ih i `SyzygyPath` spaja (`;` na Windows-u,
`:` drugde). Isti string tako podešava i tablice i motor.

**Provera pokrivenosti na startu.** `probe_wdl` već pada kad tabele nema, ali
pada na poziciji kojoj ta tabela treba — a to na šestofiguraškom prolazu ume da
bude sat vremena unutra, sa već potrošenim popodnevom. Zato se sada na startu,
pre prve partije, proba po jedna pozicija za svaki broj figura do zadatog
maksimuma (`CANARY_FENS`). Mašina sa samo malim setom i `--syzygy-max-pieces 6`
staje u prvoj sekundi, sa porukom šta joj nedostaje.

### Test očiglednosti

Poredi se **koje poteze plitka pretraga smatra dobitnim**, ne koji joj je prvi.
U pomenutoj pešačkoj završnici dubina 6 takođe igra `Kd3` prvo — ali misli da i
`Kb4` dobija, a `Kb4` remizira. Pitanje „isti prvi potez?" bacilo bi tu poziciju.

Plitka pretraga ima **svoj proces**, sa jednom niti i 16 MB. Sa zajedničkim
motorom je čitala odgovor duboke pretrage iz heša: prijavljivala je provaliju od
3459 centipiona tamo gde na hladnoj tabli ne nalazi ništa. Svako merenje
očiglednosti je do te popravke bilo besmisleno — uključujući brojku „68%
pozicija je očigledno", koja je bila posledica te greške, a ne stvarnosti.
Stvarna vrednost je oko 5%.

## Format zapisa

```json
{
  "fen": "5R2/8/4k3/8/r5P1/7K/8/8 b - - 3 77",
  "source": "syzygy",
  "mode": "draw",
  "wdl": 0,
  "dtz": 0,
  "difficulty": 5,
  "winning_moves": ["e6e7"],
  "winning_moves_san": ["Ke7"],
  "solution": ["e6e7", "f8h8", "..."],
  "solution_san": ["Ke7", "Rh8", "..."],
  "white": "Fischer, Robert James",
  "black": "Sherwin, James T",
  "date": "1958.??.??",
  "database": "Fischer.pgn",
  "type": "RookPawnVsRook",
  "ply": 154
}
```

`winning_moves` nosi **sve** poteze koji drže ishod, ne samo motorov favorit —
aplikacija mora sve da prihvati. `source` kaže odakle ishod dolazi: `syzygy`
iz lokalne tablice, `lichess` iz iste tablice preko mreže, `engine` iz procene
— prve dve su egzaktne. Pozicije iz motora dodatno imaju `eval`, `cliff`,
`depth` i `verified_depth`; ponovno suđenje ta četiri polja briše, jer opisuju
odgovor u kome nisu učestvovala.

## Nastavak i ravnomernost

Tri pomoćna fajla uz svaki izlaz:

- `.done` — baze koje su **cele** obiđene; baza zaustavljena kvotom ostaje
  otvorena, inače bi je kasniji veći cilj preskočio;
- `.games` — otisci obrađenih partija, računati iz **poteza** a ne iz zaglavlja;
- `.visited` — indeksi obiđenih partija po bazi; ovo omogućava da se cilj kasnije
  podigne, jer se onda gledaju partije koje taj tip nikad nije video.

Zašto otisak iz poteza: ključ iz zaglavlja (igrači, datum, rezultat, turnir)
proglasio bi **4.712 različitih partija istima**. Potezi su partija.

Kvota se deli po bazama **srazmerno broju partija u njima**, i preračunava se u
hodu, pa baza koja ne može da popuni svoj deo prosleđuje ostatak sledećima.
Partije unutar baze se biraju stalnim nasumičnim redosledom kroz ceo fajl —
uzimanje prvih N popunilo bi kvotu iz Aljehinove rane karijere.

**Ne dopisivati partije u postojeći PGN.** Redosled se izvodi iz imena baze i
broja partija u njoj; dodavanje partija pomera sve zapamćene indekse i `.visited`
počinje da pokazuje na pogrešne partije. Nove partije uvek kao nov fajl.

## Gustina: zašto ukupan broj figura, a ne broj pešaka

Rudarenje je izbacilo poziciju od **17 figura i 13 pešaka** kao „raznobojne
lovce" — srednjišnjicu u kojoj su slučajno ostali samo lovci. Uzrok: većina
tipova ograničava samo figure i o pešacima ne kaže ništa.

Prva reakcija je bila prag od 6 pešaka. Merenje ga je oborilo: odneo bi **357 od
1.119 pozicija**, kod pešačkih završnica 62%, a pešačka završnica sa pet na pet
pešaka je i dalje završnica.

Ta dva merila su uz to **ista stvar pomerena za fiksni broj figura tipa**:

| tip | figura pre pešaka | 6 pešaka znači |
|---|---|---|
| PawnEnding | 2 | 8 ukupno |
| BishopVsKnight, QueenVsRook, OppositeBishops | 4 | 10 ukupno |
| RookPawnVsRook, RookBishopVsRook | 5 | 11 ukupno |
| DoubleBishopVsBishopKnight | 6 | 12 ukupno |

Jedan prag pešaka daje tipovima sa više figura veću gustinu na tabli; jedan prag
ukupnih figura daje tipovima sa manje figura pravo na više pešaka. Nijedan nije
neutralan.

Rešenje nije bolji prag nego **drugo mesto**: odbacivanje pri rudarenju je
nepovratno i košta sate rada motora, a filtriranje u upitu je besplatno i
promenljivo. Zato:

- **u rudaru** samo `--max-pieces 16`, da motor ne troši vreme na srednjišnjicu.
  Odbacuje 16 pozicija od 1.119, sve stvarne srednjišnjice;
- **u bazi** kolone `piece_count` i `pawn_count`;
- **u upitu** pravi izbor, po nameni:

| namena | kriterijum | zašto |
|---|---|---|
| igranje do kraja | ukupno ≤5 figura | dokle sežu tablice; tvrdo, ne stvar ukusa |
| trener zagonetki | ukupno ≤12 | mora da izgleda kao završnica |
| pešačka tema | broj pešaka | struktura je sam predmet učenja |
| domaći | bez praga | trener bira |

Gde je kriterijum tehnički, mera je ukupan broj figura. Gde je pedagoški, zavisi
od teme.

## Stanje

Posle čišćenja: **1.089 pozicija, sve u bazi.**

| tip | dobitne | remi | ukupno | figura |
|---|---|---|---|---|
| RookPawnVsRook | 173 | 248 | 421 | 5 |
| PawnEnding | 157 | 143 | 300 | 3–16 |
| QueenVsRook | 83 | 85 | 168 | 4–16 |
| BishopVsKnight | 54 | 43 | 97 | 6–16 |
| OppositeBishops | 21 | 16 | 37 | 6–14 |
| RookBishopVsRook | 23 | 12 | 35 | 5–14 |
| DoubleBishopVsBishopKnight | 16 | 15 | 31 | 10–16 |

**Odbrambenih pozicija ima gotovo koliko i dobitnih — 562 naspram 527.** Kod
`RookPawnVsRook` čak 248 naspram 173. Ta polovina baze ne bi postojala bez
remi-režima; stari kriterijum je tražio `eval >= +200` i nije je mogao videti.

Pet tipova je jedva zagrebano: `BishopVsKnight` je obišao 3.046 od 97.330
partija. Materijala ima još mnogo.

Čišćenje je odnelo 30 pozicija: 16 pretrpanih, 8 viška iz iste partije, 4 koje
se razlikuju samo po brojaču poteza, 2 sa forsiranim matom.

`OppositeBishops` je do sada uvek davao prazan fajl, jer je stara skripta zvala
`chess.square_light_dark`, funkciju koja u `python-chess` ne postoji. Izuzetak
je hvatao goli `except Exception`, ispisivao jedan red i pravio prazan rezultat
koji je izgledao kao „nema takvih pozicija".

`OppositeBishops` je do sada uvek davao prazan fajl, jer je stara skripta zvala
`chess.square_light_dark`, funkciju koja u `python-chess` ne postoji. Izuzetak
je hvatao goli `except Exception`, ispisivao jedan red i pravio prazan rezultat
koji je izgledao kao „nema takvih pozicija".

## Backend: urađeno 22.8.2026

**Tabela `endgame_puzzles` proširena.** Imala je poziciju i jednu reč ocene — ni
rešenje ni tip, jer generator za koji je pisana ništa više nije ni davao. Dodato
je petnaest kolona kroz `ADD COLUMN IF NOT EXISTS`, da se postojeća baza
migrira umesto da ostane po strani: `winning_moves`, `solution`, `solution_san`,
`endgame_type`, `mode`, `side_to_move`, `source`, `wdl`, `dtz`,
`difficulty_score`, `piece_count`, `pawn_count` i podaci o partiji.

Dodat je i **jedinstveni indeks na `puzzle_id`**. Bez njega je
`ON CONFLICT DO NOTHING` u starom uvozniku bio bez ikakvog dejstva — svako
ponovno pokretanje dopisivalo je ceo fajl i javljalo uspeh.

**`chess_backend/import_endgames.js`** zamenjuje `import_endgame_puzzles.js`,
koji je gađao folder koji više ne postoji. Id se izvodi iz pozicije (`eg_` plus
sha1 FEN-a bez brojača), pa je uvoz idempotentan. `--dry-run` ne upisuje ništa.
Izveštaj razdvaja upisano od preskočenog, da „0 upisano" znači „već uvezeno" a
ne tišina.

Upisi idu u grupama od 200: baza je udaljena, pa je red po red jedan mrežni
obilazak po redu — 1.119 pojedinačnih je prešlo dva minuta, u grupama traje
sekunde.

**Ruta `/api/puzzles/endgame/next`** prima `type`, `mode`, `difficulty`,
`maxPieces` i `minPawns`, i vraća sva nova polja. Dve popravke:

- stara ruta je, kad filter ništa ne nađe, **tiho vraćala bilo koju poziciju**;
  ekran koji traži remisnu topovsku završnicu dobio bi dobijenu pešačku bez
  reči. Sada vraća 404.
- u tabeli je i **510 starih redova bez rešenja** — pozicije K+D protiv K iz
  `easy_puzzles.json`, sa ocenom „Mate in 6" i ničim drugim. Ruta ih izostavlja
  uslovom `winning_moves <> '{}'`: pozicija bez zadatka je za dete prazna tabla
  na kojoj ne može da bude u pravu. Nisu obrisane — imaju četiri figure, pa im
  se rešenja mogu dopuniti iz tablica za nekoliko sekundi kad se odluči šta sa
  njima.

## Ponovno suđenje postojeće zbirke — 23.8.2026

Kad su tablice stigle do šest figura, 596 pozicija u zbirci se moglo presuditi
tačno umesto proceniti. `rejudge_endgames.py` to radi: do šest figura lokalne
tablice, na sedam Lichess API, od osam naviše ostaje motorov odgovor i ne dira
se. Sud se ne piše ponovo — zove se `evaluate_with_tablebase` iz rudara
neizmenjen, pa pozicija presuđena danas prolazi kroz isti kriterijum kao ostatak
zbirke; razlikuje se samo objekat koji odgovara na `get_wdl`.

| | |
|---|---|
| presuđeno | 596 |
| ishod potvrđen | 595 |
| ishod ispravljen | 1 |
| ispalo | 0 |
| zahteva ka Lichess-u | 379 |

**Motor je bio u pravu 595 puta od 596.** To je nalaz sam za sebe: dubina 20 sa
proverom na 24 daje isti ishod kao tablica gotovo uvek, pa dizanje granice nije
ispravka postojeće građe nego osiguranje buduće.

Jedina ispravka je `6k1/5p2/7p/8/4r2P/2Q5/6K1/8 w - - 9 55`: motor je našao
`Qf3` i `Qg3+`, tablica dodaje i `Qc8+`. Dete koje odigra `Qc8+` dosad bi dobilo
„netačno" za potez koji dobija — a to je tačno razlog zbog kog `winning_moves`
nosi sve poteze, ne samo najbolji.

### Jedan zahtev po poziciji, ne po potezu

`tablebase_results` je pitao samo poteze, nikad samu poziciju, a API u jednom
odgovoru daje ishod za **sve** poteze. Bez toga svaki potez plaća svoj zahtev —
oko dvadeset pet puta više saobraćaja, i to bi od „mali ciljani broj zahteva"
napravilo upravo skeniranje tuđeg servisa. Sada `tablebase_results` nudi tablici
`prime()` pre probanja poteza; lokalno je bez dejstva, jer python-chess nema taj
metod. Mereno: 32 zahteva za četiri sedmofiguraške pozicije umesto oko 800.

Znati ishod pozicije i imati njene potomke nisu ista stvar — potomak naučen iz
roditeljskog odgovora nosi presudu i nijedan potez — pa se to dvoje prati
odvojeno. Spajanje bi saobraćaj vratilo tamo gde je bio.

### Uvoz mora da zna da ažurira

`import_endgames.js` je imao `ON CONFLICT DO NOTHING`, što je tačno za ponovni
uvoz istog fajla i pogrešno za presuđen: red bi zadržao stari sud, a izveštaj bi
rekao „0 upisano, N preskočeno" — što izgleda tačno kao „već uvezeno". Dodat je
`--update`, a `xmax` u izveštaju razdvaja upisano od ažuriranog. Prepisuju se
samo kolone suda; partija iz koje pozicija potiče nije sud.

Uz to i uslov `IS DISTINCT FROM` nad tim istim kolonama, bez kog `DO UPDATE`
pali za svaki red i prijavljuje **1089 ažuriranih** — broj koji izgleda kao rad
a ne opisuje nijedan. Sa uslovom: 319 ažurirano, 770 netaknuto, a **drugo
pokretanje javlja nulu**. To je provera samo po sebi — uvoz koji ništa ne menja
mora i da kaže da ništa nije promenio.

U bazi posle uvoza: 533 `syzygy`, 63 `lichess`, 493 `engine`.

### Šta ponovno suđenje namerno ne dira

Prvi prolaz je prepisao i **ocenu težine kod 185 pozicija**. Težina se računa iz
`shallow_best`, dakle iz iste plitke pretrage čiji sud nije reproducibilan — pa
je to bila zamena jedne šumovite ocene drugom, jednako šumovitom. Sada se težina
zadržava svuda gde se ishod nije pomerio, a računa iznova samo tamo gde je
pozicija stvarno prešla sa procene na tablicu: 112 pozicija.

Uz to se `winning_moves` sada upisuje **sortirano**. Lista je skup i redosled ne
znači ništa, ali se serijalizovala onako kako je `frozenset` naišao, pa je
ponovni upis izgledao kao izmena kod trinaest zapisa čiji su potezi identični.
Aplikacija uz to koristi `winningMoves.first` kao nagoveštaj — proizvoljan
redosled je značio i proizvoljan nagoveštaj.

### Nađeno usput, nije popravljeno: test očiglednosti nije reproducibilan

Isti fajl, isti kod: **tri pozicije ispadaju kad se pusti sam, jedna kad se
pusti posle 587 drugih.** Plitki motor nosi transpozicionu tabelu iz pozicije u
poziciju, pa sud „ovo je očigledno" zavisi od toga šta je analizirano pre njega.

Ista je porodica greške kao „zagrejana transpoziciona tabela" niže, samo jedan
sloj dalje: tamo je plitka pretraga čitala odgovor duboke, ovde čita sopstvene
ranije odgovore. Pogađa **i samo rudarenje**, jer isti test odlučuje o prijemu —
dakle koje pozicije uđu u zbirku delom zavisi od redosleda kojim su naišle.

Zato ponovno suđenje ne preispituje težinu, samo ishod (`reject_obvious` je
isključen). Izmereno nad celom zbirkom: **svih 252 odbijanja u prvom prolazu
došlo je iz tog testa, nijedno iz neslaganja o ishodu**, pa isključivanje ne
košta ništa, a čuva 252 pozicije od tihog i svaki put drugačijeg brisanja.

Popravka bi bila `ucinewgame` pre svake analize — u python-chess različit `game`
objekat po poziciji. To menja i šta rudar prima, pa je posao za sebe i traži
ponovno merenje praga očiglednosti.

## Zamisao: kako ovo ulazi u aplikaciju

**Ocenjivanje po ishodu, ne po jednom potezu.** Dete koje odigra `Kd3` umesto
`e4` dobija „tačno". Podaci to već nose.

**Igranje do kraja protiv motora, sa tačnim sudijom.** Za pozicije iz tablica
backend može da oceni svaki potez egzaktno: da li je zadržao dobitak ili ga je
prokockao. Ne „motor kaže −0.3", nego „ovaj potez gubi dobitak".

**Odbrana kao zaseban režim.** „Drži remi" je drugi zadatak od „dobij", i za
decu često teži.

**Domaći i ponavljanje.** `assignment_items.puzzle_id` je `VARCHAR(64)`, pa
završnice ulaze u domaći čim dobiju token id, bez izmene te tabele.
`review_items` je zasad vezan samo za `saved_lessons` i morao bi da prihvati i
zagonetku.

Svaka pozicija nosi igrače i godinu — „ovo je iz partije Fischer–Sherwin 1958"
deci nije svejedno.

## Sledeći koraci

**1. Ekran u aplikaciji.** ✅ Urađeno. Rešavanje je provereno uživo 22.8.2026,
igranje do kraja 23.8.2026 — oba u `endgame_trainer_screen.dart`, jedan ekran sa
dva režima. Prima svaki potez iz `winning_moves`, razdvaja dobitak od odbrane, i
igra do kraja protiv tablično savršenog protivnika do sedam figura. Otvorene
ostaju dve provere u [TODO-provera.md](TODO-provera.md), tačka 0c.

**2. Šestofiguraške tablice.** ✅ Skinute i proverene 23.8.2026 — 730 fajlova,
149,2 GB, sve `sha256` sume se slažu (`verify_syzygy6.ps1`). Domet tablica u
partijama raste sa 2,6% na 5,4%, i tek na šest figura počinju teme koje se
stvarno predaju. Rudar ih koristi od istog dana — vidi „Motor ili tablica".
Ostaje **ponovno rudarenje**: 55 postojećih pozicija sa tačno šest figura
ocenio je motor, a sada se mogu presuditi tačno.

**3. Detektor grešaka iz tablica.** Zaseban alat: proći kroz pozicije sa pet i
manje figura i naći poteze koji su **promenili ishod**. To je egzaktna greška,
bez praga i bez dubine, i dokaz da pozicija nije trivijalna je to što je čovek
pred njom pogrešio. Izmereno na 1.424 partije: 2,5% stigne do pet figura, i tu je
9 grešaka — oko 600 na celoj zbirci, za pola sata bez ijednog poziva motora.
Svaka daje dva zadatka: „nađi potez koji drži" i „kazni".

**4. Velike baze.** Gigabaza od 10,5 miliona partija je 108 puta veća od
sadašnje zbirke i traži tri izmene: filter rejtinga, gornju granicu kvote po
bazi (inače bi dobila 99% svake kvote i ostale baze bi ostale prazne), i jeftiniji
način biranja partija od mešanja liste od deset miliona indeksa. Sortirana je
**po otvaranju**, pa isečak uzet u komadu meri jedno otvaranje — uzorak mora biti
razvučen kroz ceo fajl.

Online baza je pretežno brzopotezna: `TimeControl` je prisutan u 63% partija i
ubedljivo najčešća vrednost je `180+0`. Za gradivo nije upotrebljiva, za detektor
grešaka jeste — medijana rejtinga je 2592, dakle jaki igrači koji greše zbog
sata.

## Igranje do kraja protiv motora — napravljeno i provereno 23.8.2026

Zamišljeno je da dete odigra celu završnicu protiv motora, a da svaki njegov
potez bude ocenjen **tačno**, iz tablica.

**Građa već postoji** — 478 pozicija sa pet i manje figura, sve iz tablica.
Ne treba novo rudarenje; nedostaje petlja suđenja.

| tip | dobitne | remi | raspon DTZ (dobitne) |
|---|---|---|---|
| RookPawnVsRook | 173 | 248 | 1–41 |
| PawnEnding | 6 | 23 | 1–17 |
| QueenVsRook | 7 | 16 | 1–77 |
| RookBishopVsRook | — | 5 | — |

Remi-pozicija ima više nego dobitnih, 292 naspram 186. Tamo dete brani a motor
napada, što je verovatno vrednija vežba.

### Kako radi

Posle svakog poteza pitanje nije „je li dobar" nego **„da li je zadržao
ishod"**, a to je probanje tablice — činjenica, ne procena. Motor igra drugu
stranu i mora da brani **tablično najbolje**: ako pogreši, zadatak se završi sam
i ništa nije naučeno.

**DTZ meri napredak**, i to je ono što nijedna ocena u centipionima ne može:
posle poteza se zna ne samo da je dobitak zadržan nego i da li je dete prišlo
bliže. „Tačno, ali nisi ništa dobio — i dalje 18 poteza do kraja."

Čim potez promeni ishod, staje se i kaže tačno to: „ovaj potez ispušta
dobitak". Bez pogađanja.

### Odluka 1: gde stoje tablice — ✅ odlučeno 23.8.2026

**Do pet figura sudi server, šest i sedam idu na Lichess API.**

- **Na serveru** — backend dobije 940 MB i endpoint koji prima poziciju i
  potez, vraća da li je ishod zadržan, koliko je ostalo po DTZ i šta protivnik
  odgovara. Jedan poziv po potezu, tablice na jednom mestu.
- **Lichess API** — jedan zahtev po potezu, vraća kategoriju za **svaki**
  legalan potez odjednom, i ide do sedam figura. Ovo je ispravna upotreba tog
  servisa: mali ciljani broj zahteva, ne masovno skeniranje.
- **Na telefonu** — 940 MB uz aplikaciju, otpada.

Šestofiguraški set ne ide na server: 149,2 GB ne staje ni na disk droplet-a, a
Syzygy se uz to čita mapiranjem u memoriju, pa bi i da stane radio loše. Set
ostaje na radnoj mašini, gde mu je posao rudarenje, ne suđenje.

**Dopuna istog dana, pri izradi.** Serverska polovina nije preživela dodir sa
kodom. **Za Node ne postoji čitač Syzygy tablica** — npm nema nijedan — pa bi
i onih 940 MB tražilo ili Python sa `python-chess` na droplet-u, ili zaseban
servis, ili pisanje čitača. A tablice se čitaju mapiranjem u memoriju, tako da
940 MB na mašini sa 960 MB RAM-a ionako ne bi stajalo pored svega ostalog.

Umesto toga backend **posreduje ka istom javnom API-ju i kešira po FEN-u**.
„Server sudi" ostaje tačno — aplikacija pita naš backend, ne Lichess — menja se
samo odakle backend zna odgovor, a `LICHESS_TABLEBASE_URL` pokazuje na drugo
mesto onog dana kad lokalne tablice postanu izvodljive, bez ijedne izmene u
aplikaciji.

Time granica prestaje da bude pet: sudi se **do sedam figura**, dokle sežu
tablice koje server pita. Građa za vežbu je 596 pozicija umesto 478.

Šta ovo povlači:

- **Granica se prelazi usred vežbe.** Uzimanje u šestofiguraškoj poziciji je
  spušta na pet, pa isti zadatak počne na API-ju a završi se na serveru. Ruta se
  bira po broju figura u tekućoj poziciji, ne jednom po zadatku.
- **Nedostupan API nije razlog za procenu motora.** Kad se do tablice ne može
  doći, vežba to kaže i ne nudi se — isto pravilo kao `probe_wdl` u rudaru.
  Tiho prelaženje na centipione dalo bi „tačno" tamo gde je ishod izgubljen, a
  ceo smisao ovog režima je da sudija ne pogađa.
- **Ono što se danas koristi ne zavisi ni od koga.** Svih 478 postojećih
  pozicija sa pet i manje figura sudi server; API je za građu koja tek dolazi
  iz šestofiguraškog rudarenja.

### Odluka 2: pravilo od 50 poteza — ✅ odlučeno 23.8.2026

**Pozicije čiji dobitak traje preko pedeset poteza se ne zadaju.** Grindovanje
takvog dobitka ne uči ništa što se ne nauči na kraćem primeru, a vežba koja se
ne može završiti je vežba koja se ne radi.

Pri upisu ove odluke izmereno je da je pitanje bilo postavljeno u **pogrešnoj
jedinici** — istoj grešci koja je već jednom pojela regulator broja radnika.
`dtz` je u **polupotezima**, i meri razdaljinu do sledećeg poteza koji nulira
brojač (uzimanje ili potez pešaka), a ne dužinu dobitka. „DTZ ide do 77" je
dakle oko 38 poteza do nuliranja, ne 77 poteza igre.

Izmereno nad svih 478 postojećih pozicija iz tablica:

| | |
|---|---|
| dobitne | 186, `dtz` 1–77 polupoteza |
| remisne | 292, `dtz` 0 |
| prokleti dobici (`wdl` ±1) | **0** |
| `dtz` preko 100 polupoteza | **0** |

**Danas filter ne izbacuje nijednu poziciju** — sve narudarano konvertuje se
unutar pedesetopoteznog prozora. Odluka je doneta unapred, za šestofiguraško
rudarenje, gde se i prokleti dobici i `dtz` preko 100 stvarno javljaju.

Oblik filtera, kad se bude pisao:

- odbaci `wdl` ±1 — prokleti dobitak je dobitak **samo ako se pravilo od 50
  poteza zanemari**, dakle tačno klasa koju ova odluka isključuje, i ne traži
  nikakav prag;
- odbaci `|dtz| > 100` — nuliranje se ne stiže unutar prozora.

Ono što nijedno od toga ne meri je **ukupna dužina dobitka do mata**: posle
nuliranja brojač kreće iz početka, pa i pozicija sa malim `dtz` može da potraje.
Syzygy nema DTM. Ako se u praksi pokaže da dete grinduje predugo, ograničenje
ide na samu vežbu — stani posle N poteza i pokaži ostatak — a ne na izbor
pozicija.

### Šta je napravljeno

Tri celine, svaka upotrebljiva sama za sebe:

- `chess_backend/services/tablebaseService.js` — jedino mesto koje pita tablicu.
  Keš po FEN-u, zahtevi za istu poziciju se stapaju u jedan, ograničen keš.
  Ništa ne prelazi na motor: nedostupna tablica se prijavljuje kao nedostupna, a
  kategorija koju servis ne potvrđuje (`unknown`, `maybe-win`) puca umesto da
  postane ishod.
- `chess_backend/services/endgameDrill.js` + `POST /api/puzzles/endgame/play` —
  dva pitanja tablici po potezu: pozicija iz koje se igralo, koja kaže i šta je
  trebalo držati i šta je potez ostavio, i pozicija posle nje, gde se bira
  odgovor. Ponovljene pozicije ne koštaju ništa. 503 kad tablice nema.
- Režim u `endgame_trainer_screen.dart`, ne nov ekran. Dugme „Odigraj do kraja"
  stoji i pre i posle rešavanja: znati koji potez drži i umeti to odigrati su
  dve različite stvari.

**Zašto sudi server, a ne aplikacija.** Presuda koja stigne sa klijenta je
presuda koju server ne može da razlikuje od bilo kog drugog POST-a — a češći
slučaj nije varanje nego stara verzija APK-a ili ponovljen zahtev posle prekida
mreže. Ovde to uz to ništa ne košta, jer server ionako mora da pita tablicu da
bi detetu odgovorio. Napomena radi poštenja: `POST /api/puzzles/attempt` i dalje
uzima `solved` od klijenta, pa ovo nije pravilo koje projekat primenjuje svuda.

### Šta se ne govori detetu

**Nikad koliko je poteza ostalo.** `dtz` je u polupotezima do sledećeg uzimanja
ili poteza pešaka, ne do mata, i posle konverzije kreće iz početka — „još
osamnaest poteza" bilo bi pogrešno dvaput. Ono što jeste tačno i na šta dete
može da reaguje je poređenje: ishod je zadržan, i jesi li prišao bliže ili nisi.
Test čuva baš to, jer je iskušenje trajno.

**„Tačno, ali nisi prišao bliže"** je zasebna rečenica namerno. Dete koje šeta
kraljem tamo-amo bi golo „tačno" pročitalo kao „to je bio potez" i nastavilo.

**Pedeset poteza** je jedini kraj koji liči na uspeh a nije: dobitak koji
tablica zove dobitkom konvertuje se unutar pravila, pa istrošen brojač znači da
su potrošeni potezi, ne da pozicija nije dobijala.

### Greška koju je našla tek odigrana partija

Prvi pokušaj je konvertovao šest poteza čisto pa ušao u **beskonačno
ponavljanje** — `Rf7`/`Rc7` zauvek, uvek „drži", nikad kraj.

Uzrok je isti oblik greške kao kod `closer`: `bestReply` je za dobitnu stranu
birao najmanji `dtz`, a to poredi razdaljine merene od različitih polazišta, jer
uzimanje ili potez pešaka nuliraju brojač. Kad pozicija ima `dtz = 1`, dobitni
potez je baš onaj koji nulira, a njegova razdaljina posle toga izgleda velika.

Sada dobitni potez koji nulira ide prvi: to je napredak po definiciji i to je
ono što garantuje da se vežba završi. Ista greška stoji i u `tablebase_line` u
rudaru, gde se ne vidi jer linija ima osam poluposteza — **zabeležena, nije
popravljena**. Posle popravke ista pozicija konvertuje do mata u 32 poteza, sa
napretkom u svakom koraku, uz 63 zahteva.

### Ako API zakaže

Vežba kaže da trenutno ne radi i skloni se. Motor je **ne menja**, iako bi u
ogromnoj većini slučajeva rekao istu stvar — izmereno istog dana, motor se
složio sa tablicom na 595 od 596 pozicija. Dva razloga: motor ne zna `dtz`, pa
„tačno, ali nisi prišao bliže" nema ekvivalent u centipionima; i kad greši, ne
kaže da greši. Ostatak trenera završnica radi normalno.

Trajniji odgovor, ako smetnja postane stvarna, nije zamena nego **keš koji
preživljava restart**: prebačen u tabelu, svaka pozicija koju je neko dete ikad
dohvatilo postaje lokalno odgovoriva. To nije zamena koja laže nego lokalna
kopija tačno onog dela tablica koji se stvarno koristi.

## Greške koje su nas koštale

Sve su istog oblika kao ona iz `CLAUDE.md`: ne padaju, nego tiho prestanu da rade.

- **Zagrejana transpoziciona tabela.** Plitka pretraga je čitala odgovor duboke
  iz heša. Popravljeno zasebnim procesom.
- **Curenje motora.** Bazen niti se pravio po svakoj bazi, a motori žive u
  lokalnoj memoriji niti — posle osam baza mašina je nosila **128 Stockfish
  procesa i 3,7 GB** umesto 16. Bazen se sada pravi jednom za ceo prolaz.
- **Prag u nepravoj jedinici.** Prvi regulator broja radnika merio je partije u
  sekundi; većina partija nema nijednu poziciju traženog tipa, pa je signal bio
  šum — šezdeset promena u šesnaest sekundi. Sada meri kandidate.
- **`@()` u Windows PowerShell 5.1.** `ConvertFrom-Json` tamo prosleđuje ceo niz
  kao jedan objekat, pa je izveštaj javio „ukupno 1 pozicija" za fajl sa 429.
- **Em-dash u `.ps1`.** Windows PowerShell čita skriptu u ANSI kodnoj strani i
  string se prekine. Skripte su namerno čist ASCII.
- **Iteracija `board.legal_moves` uz `push`/`pop`.** Generator čita stanje table
  lenjo; lista se sada materijalizuje pre petlje.
