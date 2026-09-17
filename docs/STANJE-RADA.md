# Stanje rada — nastavak u novoj konverzaciji

Namena: da neko ko dolazi bez istorije razgovora za pet minuta zna gde smo stali
i zašto je nešto urađeno baš tako. Nije prepis dijaloga — prepis troši prostor,
a odluke su ono što se ne može rekonstruisati iz koda.

Ovde stoji samo **ono što je još živo**: gde smo, šta je otvoreno, šta sledi, i
pravila koja i dalje važe. Zatvorena istorija — popravke sa ✅ i datumom,
merenja, i putevi kojima se do sadašnjeg oblika došlo — preseljena je 27.8.2026.
u [arhiva/STANJE-RADA-do-26.8.2026.md](arhiva/STANJE-RADA-do-26.8.2026.md),
a istorija od 26.8. do 2.9.2026 (panel trenera, prijava, teme, arhiva partija,
avgustovski repertoar) 16.9.2026. u
[arhiva/STANJE-RADA-26.8-do-2.9.2026.md](arhiva/STANJE-RADA-26.8-do-2.9.2026.md).
**Arhivu ne treba čitati unapred**; ona se pretražuje (`grep`) kad zatreba
*zašto* neke starije odluke. Razlog za podelu: ovaj fajl je bio 242 KB i svaka
je sesija počinjala tako što ga je ceo pročitala.

Zbog podele poneko „odeljak iznad/niže" sada pokazuje preko granice dva fajla —
ako ga nema ovde, u arhivi je.

Poslednje ažuriranje: **16.9.2026** — najnovije je „Reorganizacija aplikacije — plan sa tri varijante" (predlog, ništa u kodu, čeka odluku vlasnika), pa „Četiri prijave iste večeri: podešavanja, mat, Google, obaveštenje" (u kodu, provera uživo — stavka 174), pa „Telefon položeno: posle prve provere" (u kodu, **viđeno uživo** — stavka 173), pa „Telefon položeno: tabla levo, sve ostalo desno" (u kodu, prva provera uživo — stavka 172), pa „Analiza uvozi PGN sa varijantama" (u kodu, provera uživo — stavka 171), pa „Tri prijave o repertoaru: motor, brojač i PGN" (u kodu, spojeno posle revizije, provera uživo — stavka 170), pa „Ostatak revizije (blok C)" (u kodu, četiri pitanja čekaju odluku, provera uživo — stavka 169), pa „Soba iz revizije (blok B)" (u kodu, provera uživo sa dva uređaja — stavka 168), pa „Sigurnosni blok iz revizije" (u kodu, provera uživo — stavka 167), pa „Repertoar se gradi na
tabli" odmah ispod ove glave (P0–P4 u kodu, provera uživo — stavka 166), pa
„Otvaranja iz naše baze" (faze 0–4 u kodu, faza 5 otvorena, provera uživo —
stavke 164 i 165), pa „Izlazak iz
masters baze, kraj linije bez reči, i tutorijal iz studije", pa
„Tutorijal iz partije kao priča" (oboje u kodu, ostaje provera uživo — stavke
163 i 162), pa „Druga provera uživo: šest
prijava (A–F)", pa „Skelet: devet prijava sa
prve provere uživo" (sve u kodu, ostaje provera uživo),
pa faze 4, 3, 2 i 0 plana skeleta. Pre toga „Ispis prati glas, a ne
fajl" (u kodu, ostaje provera uživo), pa „Oznake van
table, i kartice koje ne beže" (isto), pa
„Vraćanje na već viđenu poziciju" (isto), pa „60 fps za
YouTube — mereno i odbijeno" (ništa u kodu, samo merenje), pa „Oznake na tabli —
plan i sve faze" (ceo plan u kodu, ostaje provera uživo), pa „Priručnik",
pa „Jezik glasa — plan", pa „Prevod tutorijala, van
aplikacije", pa „Video bez komentara pored
table", pa „Ispis prati glas, a ne
sat", pa „Tutorijal iz fajla, i oznake koje su oduvek
postojale", pa „Četiri prijave
uživo: slova, glas i uzorak", pa „Izbor glasa: prvo jezik, pa glas",
„Azure Speech, i srpski koji je vraćen a ne preveden" i „Glas koji ne može da
progovori se sada zna pre crtanja"; pre toga, faze 1 do 6 plana snimanja su u kodu, dakle ceo prvi deo, a od drugog dela
tačke 4 i 5 („Render izlazi iz zahteva" i „Render koji ne može da stane" niže):
trener snima svoj glas preko tutorijala, izvozi video u tom glasu, i snimak zna
kojim taktovima pripada („Snimanje glasa: faza 6", „faza 5" i „faza 4" niže), a „ODAKLE
SUTRA — 10.9.2026, video i snimanje" ispod toga. Tog dana i noći pred njim: prekid napuštenog rendera,
pregled pre renderovanja, jedan film po tutorijalu sa linkom na zahtev,
pravednost reda po nalogu, i zatvorena faza 0 plana snimanja.

Prethodno: 6.9.2026 (redizajn studija: **P0–P4 gotove** — deo
tutorijala čuva svoje stablo, drugi „Sačuvaj“ menja tutorijal umesto da pravi novi,
ekran zna zašto se otvara, i „Biblioteka“ ima ulaz u studio; ostaje P5 nadalje. Tutorijal: cela
faza 4 zatvorena, ostaje faza 5, provera uživo).

---

## Reorganizacija aplikacije — plan sa tri varijante — 16.9.2026, predlog

Vlasnik je istog dana zatražio plan reorganizacije **sa stanovišta korisnika**:
funkcije su razbacane, isti posao (pisanje tutorijala) ima četiri ulaza pod
četiri imena (Studio; četiri dugmeta u Analizi; „Create tutorial (multiple
positions)" u levom meniju Pripreme i sobe; stari panel na Androidu), a budući
korisnik se neće snaći. Tražio je više varijanti, skice ekrana, i da se
ponovo razmotri pisanje tutorijala na Androidu (odluka 5 `PLAN-TUTORIJAL.md`),
ako postoji rešenje.

Plan je [PLAN-REORGANIZACIJA.md](PLAN-REORGANIZACIJA.md), skice u
[skice/reorganizacija.html](skice/reorganizacija.html) (otvoriti u browseru).
Ovim se **ponovo otvara** red „Reorganising the app by function — out" iz
`PLAN-ZAVRSNICA.md`: priručnik je kupio vreme, ne popravku.

Šta je nađeno (inventar svih ekrana, oznaka po oznaka; F1–F12 u planu):
jedan artefakt i četiri editora; 13 akcija u traci Analize, četiri od njih
vrata za tutorijal ka tri različita odredišta; šest polica na pet mesta
(pozicija sačuvana iz sobe ne postoji nigde na početnom ekranu); panel
trenera pod „People"; mrtav UI (zakazivanje sesije, Premium dijalog) i
podnaslov „New Session" koji obećava zakazivanje; na Androidu nema ni jednog
pravog ulaza za pisanje.

Tri varijante: **A** — ista četiri taba, jedna vrata po poslu (temelj S1–S6:
jedan editor, jedan meni „Use in a tutorial" u Analizi, jedna biblioteka svega
što se čuva, mrtav UI napolje, panel na Sessions); **B** — tabovi po glagolu:
Home · Practise · Analyse · Teach, Home adaptivan iz podataka a ne iz uloge
(**preporučeno**, gradi se kao A pa promena ljuske); **C** — dve ljuske po
tome da li korisnik podučava. Android studio: rešenje je *jedan kontroler,
dva rasporeda, jedan deo u jednom trenutku* — kontroler iz §4 plana redizajna
nikad nije izvučen iz ekrana (2693 reda), pa je to najveća stavka, i vođina.
Ništa u studiju nije vezano za Windows osim rasporeda.

**Ništa nije u kodu.** Brojke pri pisanju: 2819 / 1 preskočen / 26 info / 1376.

**Odluke vlasnika, 17.9.2026** (upisane u §9 plana): **varijanta B**, gradi
se kao A pa promena ljuske; **studio na telefonu — da** (kontroler se izvlači,
raspored Line | Task | Parts, stari editori se brišu); tabovi **Home ·
Practise · Analyse · Teach**; „People" se ukida kao tab i ide u Teach i Home;
tabla za analizu je **telo taba Analyse**.

**Faza 0 gotova, 17.9.2026 (vođa, Fable):** rečnik tabova u
`GLOSSARY-EN.md`; kapije u `docs/gates/` — `home_map_test.dart` (grupe po
fazama 5, 2 i 6c) i `analysis_teach_door_test.dart` (faza 1), obe **crvene
na `master`-u na prvom stringu koji imenuju**; šav za fazu 1 napisan i zelen:
`features/analysis_studio/widgets/teach_menu.dart` (list „Use in a tutorial",
šest redova, crta samo ono što mu je dato) sa `test/analysis_teach_menu_test.dart`
(10 testova; test na 360 dp uhvatio je prelivanje od 9 px u prvom pokretanju).
Raspodela po modelima je u §8 plana: Fable — faze 0 i 6a; Opus — vođa faza
1–5; Sonnet `implementer` — faze 1, 2, 3, 4 (kod), 6b, 6c i faze 1–2 plana
napretka; Gemini — tabela stringova i stranice priručnika 2–8 (tražiti očitanje
kvote pre pokretanja); Haiku — pretrage.

**Priručnik je prepisan na novu mapu, 17.9.2026, spojeno `16295b3`** (Gemini
batch `prirucnik-b`, jedna runda, svih dvanaest kapija zeleno na 2844). Dvanaest
strana opisuje aplikaciju **kakva će biti posle faza 2–5** — to je specifikacija
po kojoj se te faze grade. Oznake koje aplikacija još nema su redovi
`docs/gates/map_b_labels.txt` (test priručnika ih prihvata), a oznake koje
nestaju su u `map_b_retired_labels.txt` (novi `manual_places_test` ih odbija i
vezuje svaku stranu za njen tab). **Faza 5 briše oba fajla i dopuštenje u
testu.** Do tada: **sajt se ne isporučuje na droplet** — priručnik na `master`-u
opisuje tabove kojih u aplikaciji još nema.

**Faza 6a gotova, 17.9.2026 (vođa, Fable): `TutorialDraftController` izvučen
iz ekrana studija.** Klasa koju je `PLAN-STUDIO-REDIZAJN.md` §4 nacrtao a
ekran nikad nije dobio: nacrt, otvoreni deo i kursor, istorija, id-jevi koje je
čuvanje dodelilo, sačuvana verzija, poslednji potez — sve iza metoda, bez
table, polja, dijaloga i kadra. Polja pišu direktno u model (nema više
`_syncSelectedSection`); dva signala (`notifyListeners` = precrtaj,
`generation` = ponovo napuni polja iz modela). Ekran za Windows je raspored
nad kontrolerom (2693 → 2219 linija); 543 testa studija prošla **neizmenjena**;
`tutorial_draft_controller_test.dart` — 14 testova bez kadra. Nema stavke za
proveru uživo: ništa vidljivo se nije promenilo. Sledeće: **6b** (raspored za
telefon Line | Task | Parts nad istim kontrolerom, implementer), pa 6c.

**Faza 3b gotova, 17.9.2026 (vođa, Fable): kolona sobe je deljena lista.**
Leva kolona sobe i Pripreme crta `LibraryList` sužen na All · Tutorials ·
Positions, sa čipovima Mine / From trainer i panelom oznaka — oba su sada
deo vidžeta (`originChips`, `labels`), pa i ekran Library filtrira po
oznakama, kako priručnik već obećava. Kolona čita `GET /library/positions`
kao i Library; red iz `saved_lessons` (delovi tutorijala, opis pozicije) vuče
se tek kad ga radnja traži (`fetchRow`); polica tutorijala nosi svoje oznake
(kapija pozadine). Radnje na redu nepromenjene; trenerovi redovi ih nemaju.
Nestali: sopstvena pretraga kolone, matrica oznaka u sobi, tri čipa
kategorije i sopstveni red sa sličicom. Provera uživo: **178**. Sledeće:
6a (kontroler studija, vođa), 6b, 6c.

**Faza 5 gotova, 17.9.2026 (vođa, Fable): ljuska je Home · Practise · Analyse ·
Teach.** „People" je ušao u Teach (učenici, grupe, zahtevi) i Home (panel
trenera, „Set for me", „Join a session"); Home crta blokove samo iz podataka
(`hasTrainer`, dospeli pregledi); Analyse montira ekran Analize kao telo taba,
pri prvom ulasku, sa „My games" i „Scan a book" iznad i bez drugog naslova;
`HomeBibliotekaTab` obrisan; kapija `home_map_test` prešla u `test/` (grupa 6c
ostala kao `docs/gates/one_editor_test.dart`); `map_b_*` fajlovi i dopuštenje
u testu priručnika obrisani — **priručnik sad opisuje aplikaciju kakva jeste i
sajt sme na droplet**. Provera uživo: **177**. Sledeće: 3b (kolona sobe na
`LibraryList`), pa 6a (kontroler studija, vođa), 6b, 6c.

**Napredak u vežbama, faza 2 gotova, 17.9.2026, spojeno `1677f34`** (implementer,
Sonnet): svih pet vežbi piše ishod, preskakanje i pomoć (taktika kroz svoj
servis, ostalo kroz `PuzzleAttemptApi`); kartice huba crtaju „Solved N · M to
retry" i „Retry failed (M)" samo iz pročitanog; taktika, matovi, dobitne
pozicije i završnice serviraju promašene po id-u. Radnik je našao da dobitne
pozicije i osnovni matovi ranije **nisu beležili ništa**, kao ni dva dugmeta
lista „Incorrect Move" — sve spojeno. Bez mašinskog testa ostaje beleženje u
`ai_studio_screen.dart` (pravi motor u `initState`) — provera uživo 176. Id
partije u šetnji je neproziran na žici (`7da960b`). **`master`: 2878, 1
preskočen, analyze 26; backend 1412.** Stavke za proveru uživo: **175**
(reorganizacija 1–3a) i **176** (napredak). Sledeće: faza 5 (ljuska), pa 3b,
pa 6.

**Faza 3a gotova, 17.9.2026, spojeno `2671241`** (implementer, Sonnet): server
u `/library/positions` lista i `tutorial` (sa brojem delova, videom, jezikom)
i `recording`; `LibraryList` (šest čipova: All · Tutorials · Positions ·
Analyses · Recordings · Puzzle sets, pretraga, red po stavci sa akcijama koje
mu se daju); `LibraryScreen` na `/library` spaja serverske police sa
lokalnim skupovima zagonetki; kartica „Everything you keep" → „Open library"
na tabu Library; pet akcija reda tutorijala izvučeno u `TutorialRowActions`
i deljeno sa dijalogom. Vođa je dodao `initialTree` ekranu Analize, pa se
sačuvana analiza otvara cela (`8c3d418`). **3b** (kolona sobe na istu listu)
ostaje posle faze 5. **`master`: 2859, 1 preskočen, analyze 26; backend
1412.** U toku: faza 2 plana napretka (vežbe pišu ishode, kartice čitaju,
„Retry failed"), Sonnet.

**Faza 2 gotova, 17.9.2026, spojeno `6a7ac83`** (implementer, Sonnet): treći
editor (`CreateCourseDialog`) obrisan, „Create tutorial (multiple positions)"
i „Edit positions" nestali iz sobe; leva kolona sobe je „Board" (Set up
position, Import PGN, Save position, FEN) i „Library"; mrtvi dijalozi
(zakazivanje, Premium) obrisani; vidljivo „Join" prolazi kroz proveru šest
cifara; „Student groups" uvek nacrtano; nova imena (New session, Recordings,
Students and trainers, Tutorials, Scan a book, Save position). Sedam testova
otišlo sa editorom. **`master` posle svega: 2839, 1 preskočen, analyze 26;
backend 1406.** Faza 3a (jedna biblioteka: server dobija police `tutorial` i
`recording`, `LibraryList` + `LibraryScreen`) briefovana i pokrenuta; šavovi
vođe u `facac0a` (model, seam, dve kapije), a birač pozicija je pri tom uhvaćen
kako crta čip po svakoj vrednosti enuma — sad imenuje svoje tri police.

**Faza 1 gotova, 17.9.2026, spojeno `bfeaadb`** (implementer, Sonnet): jedno
dugme „Use in a tutorial" i list sa šest redova umesto četiri dugmeta; dijalog
„What are we transferring" nestao; 2819 → 2831, analyze 26. Backend faza 1
plana napretka spojena `da433d3`: 1387 → 1406.

**Faza 1 briefovana Sonnet-u 17.9.2026** (worktree; brief u sesiji): jedan
`_ToolAction` „Use in a tutorial" umesto četiri, dijalog „What are we
transferring" nestaje, dva stara testa koja čitaju izvor prepisuju se na novi
oblik, stranica `analysis.html` priručnika opisuje list. Kapija: kopija
`docs/gates/analysis_teach_door_test.dart` u `test/`.

Istog jutra vlasnik je tražio i **napredak u vežbama** — šta je rešeno, šta
promašeno, i kako vratiti promašene zagonetke. Predlog je
[PLAN-NAPREDAK-VEZBI.md](PLAN-NAPREDAK-VEZBI.md): `user_puzzle_attempts`
već postoji i indeksiran je kako treba, ali ga piše samo taktika — `/submit`
(matovi, dobitne pozicije), završnice i šetnja kroz partiju ne pišu ništa, a
preskakanje se nigde ne beleži. Plan: `source` imenuje vežbu, dve kolone
(`skipped`, `hinted`), stanja se *izvode* iz prvog i poslednjeg reda; red za
ponavljanje je **upit** (poslednji pokušaj nije rešen), a SM-2 tek kao
opciona faza 3 posle drugog promašaja, kroz postojeći `schedule()`. Na
karticama huba jedan red („Solved 48 · 9 to retry") i dugme „Retry failed".
Ništa u kodu; dodir sa fazom 5 reorganizacije je isti hub widget, pa se
redosled bira pre briefa.

---

## Četiri prijave iste večeri: podešavanja, mat, Google, obaveštenje — 16.9.2026, u kodu

Stavka 173 je prošla uživo (vlasnik, 16.9.2026 uveče); iz 172 prošla je i 8.
Iste večeri četiri prijave.

**1. Početni ekran položeno: do podešavanja se nije moglo.** Bočni meni
(zvono, četiri kartice, „Settings" na dnu) ne staje u 360 dp visine, pa je
„Settings" bio odsečen bez reči; a naslov kartice je bio nacrtan preko sata i
baterije. Sada, kad `LandscapeBoardLayout.applies`: zvono i „Settings" su u redu
sa naslovom, desno, a meni drži samo kartice; telo ekrana bez app bara ima
`SafeArea` odozgo. Na desktopu je sve kao pre („Settings" na dnu menija, zvono
na vrhu). Test: `home_landscape_test.dart`, na četiri veličine telefona sa
statusnom trakom od 24 dp. Napomena: stari ekran u testu nije odsekao
„Settings" (testni telefon nema baner aktivne sesije ni pravu visinu
destinacija), pa test drži novi raspored, a ne reprodukuje staru grešku.

**2. Mat bez komentara** — odluka vlasnika: ne bolji komentar, nego nikakav.
Pod Rh5# je stajalo „The black king on f5 is checkmated. The white rook on h5
skewers the black king…". Pravilo je `autoMoveComment`
(`core/services/finding_sentences.dart`): posle poteza koji matira, automatski
komentar je prazan. Zovu ga sva tri mesta koja sama pišu komentar — potez na
tabli Analize, „Auto Analysis" (`auto_tree_generator_service`) i pregled
partije (`game_analysis_walker_service`) — a dijalog za komentar za matni potez
ne nudi nalaze.

**Prva verzija je bila na pogrešnom mestu** i to je vredno zapamtiti: pravilo u
`explainMove` detektora oborilo je `game_tutorial_facts_test` — nalazi posle
mata ulaze u činjenice tutorijala, koje se porede sa harnessom bajt po bajt.
Nalazi ostaju; ćuti samo komentar. Testovi: `core/mating_move_comment_test.dart`
(prijavljena pozicija, ulaz sa „skewers" dokazan pre pravila; mat o kome
pozicioni evaluator ima šta da kaže, nađen šetnjom slučajnih partija; pregled
partije) i `analysis_mating_move_comment_test.dart` (Rh5# odigran na tabli
Analize). Mutacije: pravilo izbačeno iz pomoćne funkcije, iz ekrana, iz pregleda
partije — svaka uhvaćena.

**3. Google prijava na Androidu** — uzrok nije bio u kodu:
`google-services.json` je i dalje bio za stari paket `com.example.chess_app`.
Vlasnik je istog dana napravio Android OAuth klijent za `rs.pejovic.chesscoach`
sa debug SHA-1 i zamenio fajl; prijava radi. Release i Play App Signing SHA-1
ostaju za objavljivanje (`TODO-objavljivanje.md`, korak 2).

**4. „Your latest analysis has been restored" je uklonjeno.** Analiza se i dalje
vraća, bez poruke. „Start over" iz te poruke nije nadoknađivan: nova tabla je u
„Setup Position" → „Starting Position". Test:
`analysis_draft_restore_quiet_test.dart` (vraćeno stablo, nijedan SnackBar;
na starom ekranu pada).

Testovi: 2807 → **2819** (+12: 5 početni ekran, 1 obaveštenje, 4 + 2 mat), 1
preskočen; analyze 26, isti fajlovi.

Provera uživo: stavka 174.

---

## Telefon položeno: posle prve provere — 16.9.2026, u kodu

Vlasnik je istog dana prošao stavku 172 na telefonu: soba (2) u redu; Analiza
(1), gradnja repertoara (4) i Android uređivač delova (7) loše; 3, 5, 6, 8 i 9
još nisu probani. Tri odluke vlasnika, i šta je urađeno:

**1. Sudija poteza je izbačen iz Analize** — panel „Move Verdict", dugme
„Judge move", i prekidač „Move evaluation" u podešavanjima. Motor i knjiga
otvaranja odgovaraju na to pitanje. Dugme je postojalo zato što je svaka presuda
trošila token; to je prestalo 15.9, a upit ka Lichess-ovoj evaluaciji je ostao
samo zbog njega. **Gradnja repertoara zadržava svoju presudu** (radi sama, bez
dugmeta), ali njene poruke više ne pominju Lichess („There is no evaluation for
this position…", „The evaluation service is not answering…").

**2. Traka sa potezima i dugmad repertoara, strogo u jednom redu na ~760 dp.**
Na telefonu je traka Analize bila dva reda i pojela pola desne kolone. Moj
test je tvrdio da staje na 800 dp, a telefon je imao oko 760 posle sistemskih
dugmadi, uz eval traku od 26 dp — test je bio „srećniji od stvarnosti" (pravilo
6). Sada:
- `MoveNavigationControls` ima gusti režim (`dense`, sam se uključuje kad
  `LandscapeBoardLayout.applies`): dugmad 40 dp umesto 48, manji razmak, i to
  važi i za dugmad koja ekran doda na traku.
- `LandscapeBoardLayout.minPanelWidth` je **390** umesto 300: najšira traka
  (Analiza, devet dugmadi) je 384. Plaća tabla, samo tamo gde širina vezuje
  (telefon od 640 dp, ili visok telefon oko 760).
- Tri dugmeta gradnje repertoara su u pejzažu jedan red, sitnijim slovima i
  ikonama, a natpis se skraćuje umesto da se prelama.
- **Testovi mere pravim fontom.** Test crta svako slovo kao kvadrat širine
  jednog em, pa je „Move 12 of 30" u testu dva puta šira nego na telefonu.
  `loadRoboto()` (`test/support/landscape.dart`) učitava Roboto iz Flutter SDK-a
  i **puca** ako ga nema; jedan test proverava da je font zaista primenjen
  („iiii" uže od „MMMM").
- Svi pejzažni testovi ekrana sada idu i na 760×360 i 760×430, i traže da
  traka bude **jedan red**.

**3. Uređivač delova tutorijala u pejzažu ima dve kartice:**
- **Board** — tabla levo; desno spisak delova (strelice gore/dole, dodaj, obriši
  kao ikonice), a pri dnu potez koji deo traži i „Save step" / „Preview".
- **Text** — naslov, zadatak, vrsta zadatka i izbori preko cele širine, bez
  table, pa tastatura ima mesta.
Prevlačenje između kartica je isključeno, jer je na „Board" prevlačenje potez.
Uspravno je uređivač isti kao pre, a privremeno rešenje od jutros (spisak koji
skroluje sa dugmadima kad je tastatura gore) je vraćeno, jer ga pejzaž više ne
koristi.

**SafeArea sa strane je sada u samom `LandscapeBoardLayout`**, ne po ekranima:
uređivač ga nije imao i polja su bila pod sistemskom dugmadi.

Testovi: 2769 → **2807** (+38), 1 preskočen; analyze 26, isti fajlovi.
Mutacije, sve uhvaćene testom pisanim za njih: traka nikad gusta, minimum kolone
vraćen na 300, bez SafeArea, sudija vraćen u Analizu, poruke sa Lichess-om
vraćene, dugmad repertoara u `Wrap`, test bez pravog fonta, uređivač bez
kartica.

Provera uživo: stavka 173.

## Telefon položeno: tabla levo, sve ostalo desno — 16.9.2026, u kodu

Odluka vlasnika istog dana: pre objavljivanja Android mora dobro da radi
položeno. Tabla levo i **ne pomera se**, sve ostalo desno u koloni koja se
skroluje. Uspravno ostaje kako jeste, kao mogućnost — **orijentacija nije
zaključana**. Ovim je ukinuta odluka od 5.9.2026 („pejzaž na telefonu se za
sada ne dira"), koja je bila odlaganje, a ne izbor.

**Jedno pravilo, jedan dom:** `lib/widgets/landscape_board_layout.dart`.

- **Kada:** `LandscapeBoardLayout.applies(context)` — širina veća od visine
  **i** visina ispod 480 dp (Material 3 „compact height",
  `Breakpoints.compactHeight`). Po visini, ne po širini: veliki telefon
  položeno ima 915–932 dp, dakle iznad `Breakpoints.wide` (840), a rasporedi
  za tu širinu računaju na visinu desktopa. Soba je upravo tako na velikom
  telefonu dobijala dve bočne kolone od po 300 dp.
- **Tabla** se meri iz visine koju raspored stvarno dobije (ne „ekran minus
  120"), a širina ostavlja desnoj koloni bar 300 dp. Podešavanje veličine table
  (0.6–1.0) samo smanjuje.
- **Traka sa potezima nije ispod table nego pri dnu desne kolone, zakačena.**
  Ispod table bi joj uzela visinu, a na 360 dp visokom telefonu ni ne staje u
  red: devet dugmadi Analize traže 432 dp, a tabla ograničena visinom je oko
  290 dp široka, pa bi se traka prelomila u dva reda i tabla izgubila još
  jedan. Desno je jedan red, uvek na istom mestu. Isto važi za dugmad ispod
  table (ocene, „Show answer", kontrole plejera…): idu u `footer`, koji se
  skroluje sam u sebi tek kad pređe 60% kolone.
- **Eval traka stoji uspravno pored table**, iste visine (`boardAside`).
- **AppBar je 44 umesto 56** (`LandscapeBoardLayout.toolbarHeight`).
- **Tastatura:** kad visina padne ispod 240 dp, raspored se ne skuplja nego
  skroluje kao celina. Stablo je **istog oblika** i bez tastature — prva verzija
  je uvijala u `SingleChildScrollView` samo kad zatreba, pa bi polje u koje se
  kuca bilo ponovo izgrađeno i tastatura bi se zatvorila. Uhvaćeno testom, pre
  telefona.

**Ekrani** (svi pitaju isto `applies`): Analiza (za svaki položeni prozor,
kao i ranije), moje greške, pozicije iz domaćeg, ponavljanje, taktika, novi
repertoar, gradnja repertoara, dril, obilazak, endšpil, greške iz partija,
lekcija (učenik), plejer snimka, AI vežbe, soba (lekcije ostaju u Draweru) i
Android uređivač delova tutorijala. **Nisu dirani** studio tutorijala i
naracija: otvaraju se samo na Windows-u (`isTutorialStudioAvailable`).

**Nađeno usput, i popravljeno:**
- Dijalog „Board Setup" (FEN, PGN, Chess.com/Lichess kartice) se na 800×360
  prelivao za 140 px: `Spacer`/`Expanded` u koloni koja ne može da skroluje.
  Sada `_fillOrScroll` — popunjava gde staje, skroluje gde ne.
- Levi spisak delova u Android uređivaču se sa tastaturom prelivao (ostane mu
  ~50 dp); tada dugmad skroluju zajedno sa spiskom.
- U plejeru snimka rečenica „Synchronized playback of moves and arrows" nije
  imala `Flexible`. U testu se preliva za 41 px; testni font je širi od pravog,
  pa na telefonu verovatno nije, ali red koji ne može da se skupi ionako ne
  treba da postoji.

**Uspravno nije promenjeno** — nijedan postojeći test nije morao da se menja.
Sa svih 17 izmenjenih fajlova u `lib/` vraćenih na `HEAD`, 34 nova testa padaju;
tri ostaju zelena s razlogom (uspravna Analiza, tastatura na starom novom
repertoaru koji je ceo skrolovao, i dijalog na 932×430 koji je i ranije
stajao).

Testovi: `landscape_board_layout_test.dart` (14; sedam mutacija, sve uhvaćene
posle dodavanja testa za visok footer), `landscape_screens_test.dart` (23), po
dva u sedam postojećih fajlova ekrana (14); zajednička očekivanja u
`test/support/landscape.dart`. Aplikacija 2718 + 51 = **2769**, 1 preskočen;
analyze 26, isti fajlovi.

**Nije viđeno:** nijedan ekran na pravom telefonu. Testovi crtaju tekst
kvadratima, pa ne kažu da li se prava slova lepo prelamaju, kako izgleda
notch, ni da li Android položeno otvara tastaturu preko celog ekrana.
Provera uživo: stavka 172.

## Analiza uvozi PGN sa varijantama — 16.9.2026, u kodu

Prijava istog dana: repertoar izvezen kao PGN, nalepljen u Analizu („PGN
Uvoz"), dobija „Invalid PGN format". Uvoz u Analizi je išao kroz
`chess.load_pgn` + `getHistory()`, a taj paket odbija **ceo** tekst na dve
stvari koje ova aplikacija sama piše: varijantu u zagradi i razmak koji
`PgnExporterService` ostavlja ispred `1.`. Provereno na prijavljenom fajlu:
bez razmaka i dalje pada, na `Ba5 (5... Be7)`. Isto bi se desilo i sa
izvozom same Analize čim ima jednu varijantu — a i kad bi prošao, zadržao bi
samo glavnu liniju.

Izvoz repertoara nije diran: PGN koji piše je ispravan, a „popraviti" ga za
ovaj uvoz značilo bi izbaciti varijante, dakle ono što repertoar jeste.

**Ispravka:** `features/analysis_studio/services/pgn_import.dart`
(`readAnalysisPgn`) čita kroz `readStepTree` → `LessonStepLine` →
`MoveTree.parsePgn`, jedini čitač, isti koji koristi PGN kartica tutorijala.
Dolaze glavna linija, varijante (i ugnježdene), komentari, strelice i ocene.
Ekran je samo žica. Ono što se ne može odigrati se **broji i kaže**
(„N moves could not be played and were left out"), kao i „only the first of N
games" kad je nalepljeno više partija; tekst bez ijednog poteza i bez `[FEN]`
se odbija.

`PgnParser.sanitizeForLoadPgn` je ostao bez ijednog pozivaoca, pa je na
vlasnikovu odluku istog dana obrisan ceo `lib/pgn_parser.dart` (klasa nije imala
ništa drugo) zajedno sa `test/pgn_parser_sanitize_test.dart` (4 testa).
Komentari u `step_tree.dart` i `tutorial_pgn_panel.dart` koji su opisivali stari
uvoz prepravljeni su u prošlo vreme.

Testovi: `test/analysis_pgn_import_test.dart`, 10, na prijavljenom fajlu bajt
po bajt, na izvozu Analize vraćenom nazad, na Chess.com partiji sa satom i na
`[FEN]` poziciji. Šest mutacija, sve uhvaćene, svaka testom pisanim za nju. Aplikacija 2712 + 10 − 4 (obrisani
`pgn_parser_sanitize_test.dart`) = **2718**, 1 preskočen; analyze 26.

Provera uživo: stavka 171.

## Tri prijave o repertoaru: motor, brojač i PGN — 16.9.2026, u kodu

Sedam prijava iz jutra 16.9.2026 (segment „Opening repertoire", 09:27–09:44).
Urađene su tri, po dogovoru sa vlasnikom; četiri stoje: analiza celog
repertoara ostaje obrisana (obrisana je 3.9.2026, `0ec7f05`, iz vlasnikovog
razloga koji i dalje važi — sudija knjige je bolje pitanje za repertoar od
drugog mišljenja motora), „Ask AI about position" ostaje kakvo je, slanje
repertoara učeniku se ne dira, a tutorijal od otvaranja čeka.

**Motor se pita o poziciji na tabli, a ne o čvoru.** Posle sopstvenog poteza
tabla stoji ply dalje, sa protivnikom na potezu — i to je jedino stanje u kome
se motor uopšte nije mogao pitati: `if (!_afterMyMove)` je sklanjalo i dugme i
panel, a `_askEngine` je pitao o `_node`, ne o tabli. To je tačno stanje u koje
se upada kad knjiga nema odgovor („The book has no reply here"), pa je motor
nedostajao baš tamo gde drugog oslonca nema. Obe polovine prijave su bile jedno
isto stanje. Panel komentara je od početka pratio tablu; sada i motor. Uz to:
kad knjiga nema nijednu strelicu na tom mestu, crta se strelica motora — sloj
po sloj, kako je i pisalo u komentaru te funkcije.

**Brojač neodgovorenih pozicija je otišao sa ekrana i iz govora.** Rečenica
ispod pitanja („1 more unanswered position, not counting this one") bila je deo
izgovorenog teksta, pa se menjala na svakoj poziciji i čitala se iznova. Nije
samo buka: od 15.9.2026 se uz korisnikov potez čuva i najigraniji odgovor, pa
je nastavak linije izbor, a ne dug — brojanje neodgovorenog opisuje model po
kome ovaj ekran više ne radi. Sa njom je otišlo i „open N" iz reda ispod
(`decided 3 · open 1` → `decided 3`), jer je to isti broj u kraćim rečima;
polovična popravka je ono zbog čega su brojevi redova ostali nevidljivi dva
dana pošto su slova kolona sređena. **Posledica koja je namerna:** dve
uzastopne pozicije koje pitaju isto imaju isti tekst, a `SpeechService` istu
rečenicu ne ponavlja — pitanje se izgovara kad postane drugo pitanje.

Isti broj je stajao i na kartici u listi repertoara („5 unanswered positions" /
„all answered"), i otišao je na vlasnikovu odluku istog dana. Sa njim je otišao
i `GET /repertoire/progress` iz aplikacije: to je bila **šetnja po repertoaru**
na svako otvaranje liste, oko trećine sekunde po repertoaru, i bila je jedini
čitalac te rute. Klijentska metoda `progress()` i model `RepertoireProgress` su
obrisani, a ruta na serveru je ostavljena netaknuta — brisanje rute je zaseban
posao, a ostavljanje mrtve klijentske metode je tačno ono na šta je
`disagreements` ostavljen 3.9.2026 i što se ovog jutra našlo kao „postoji na
svakom sloju, a nedostupno". Kartica sada kaže koja je strana, kroz šta ide i
koliko poteza ima u grafu — dakle koliko je napravljeno.

Mapa repertoara („Gaps in repertoire") nije dirana: ona se otvara namerno da bi
se videle rupe, i tamo je broj neodgovorenih ono zbog čega se ekran i otvara.

**Repertoar izlazi kao PGN.** „Export as PGN" na meniju repertoara u listi:
celo stablo, glavni potez kao glavna linija, ostali kao varijante, komentari
korisnika unutra — podrazumevano, jer su oni jedino u fajlu što knjiga i motor
ne mogu ponovo da naprave. Tri odluke vrede pamćenja.

*Stablo crteža nije stablo izvoza.* `repertoireTreeToNodes` piše natpis kartice
u `AnalysisNode.nag` (` ★`, ` 45% ?`), a izvoznik `nag` piše odmah iza poteza —
izvoz slike bi dao `1. e4 ★ 62%` u fajlu. Stablo se gradi ponovo, čisto
(`features/repertoire/services/repertoire_pgn.dart`).

*Koji je potez glavni ne treba dogovor.* Server vraća korisnikov primarni potez
prvi, a protivnikove odgovore po opadajućem udelu; glavna linija u PGN-u je
prvi potomak na svakom koraku — dakle glavna linija fajla **jeste** glavna
linija repertoara. Izmišljanje `{main}` oznake bilo bi drugo ime za isto.

*Odakle fajl počinje se proverava, ne pretpostavlja.* Repertoar može da počne
bilo gde, a `rootPath` je put dotle. Put se odigra od početne pozicije i koristi
se **samo ako** se završi na korenu koji je server poslao; tada fajl ide od
prvog poteza, bez `[FEN]`. Ako se ne poklopi, koren je dijagram sa
`[SetUp]`/`[FEN]`, a linija se napiše rečima („Repertoire line: 1.e4 e5"). Isto
pravilo kao za zalepljenu partiju bez zaglavlja, 8.9.2026.

Izvoz traži celo stablo (`maxPly` 40, koliko server daje), a kad server kaže da
je skratio, dijalog to napiše iznad teksta. Dijalog `exportPgnDialog` sada prima
**tekst**, a ne stablo: šta ide u zaglavlje partije iz Analize i šta iz
repertoara su dva različita odgovora, a dijalog koji bi sam izvozio morao bi da
zna oba.

**Merenje (`master`, ništa drugo nije radilo):** 2693 testa u aplikaciji, 1
preskočen — 2670 pre ovoga, +3 za motor i govor, +13 za sam fajl, +7 za vrata
do njega; kartica u listi ništa nije promenila u broju, jer je
`repertoire_progress_card_test.dart` (3 testa o broju koji je otišao) postao
`repertoire_list_card_test.dart` (3 testa o onome što kartica sada kaže, i o
tome da se ruta više ne poziva). `flutter analyze` 26 infa, bez upozorenja i grešaka. Backend nije
diran (1289). Petnaest mutacija, sve uhvaćene, svaku je oborio test pisan za
nju.

Dve sitnice za pamćenje. `repertoire_counts_refresh_test.dart` je pao na
`decided 2 · open 1` — reč `open` je grepovana u `lib/` i u `site/`, ali ne i u
testovima, pa je „posle preimenovanja grepuj staru reč po testovima" opet
naplaćeno. I: analizator je prijavio `unused_element_parameter` za parametar
lažnog servisa koji nijedan test ne prosleđuje — to je bila prava rupa, jer
ništa nije tvrdilo da **ekran** prosleđuje komentare izvozniku; test je dopisan
i mutacija ga obara.

**Spojeno u `master` 16.9.2026 posle revizije** (grana je bila napravljena pre nje): aplikacija 2689 → **2712**, 1 preskočen; backend 1376; analyze 26.

Provera uživo: stavka 170.

---

## Ostatak revizije (blok C) — 16.9.2026, u kodu

Srednji i jeftini nalazi sva četiri traga revizije. Svaka ispravka ima test
viđen crven na starom kodu ili pod mutacijom (ukupno 35 mutacija, sve uhvaćene).

**Server:**
- **Troškovi tuđih servisa i procesora imaju granicu.** Narativ o protivniku
  (Gemini) ide kroz mesečnu AI kvotu i 10/min; izveštaj o rupama sa sudijom pita
  najviše 20 pozicija i ima 10/min; skeniranje PDF-a 20 u 15 min po nalogu;
  pismo roditelju 5 na sat po nalogu; sličice pregleda 30/min po nalogu
  (`middleware/accountLimiter.js` — broji po nalogu, ne po adresi, jer đaci
  jedne škole dele adresu).
- **Adrese e-pošte više nisu u logu**: pozivi pišu id korisnika, pino ima
  `redact` za `email`/`parent_email`, a razvojni ispis kodova maskira adresu.
  Test čita svaki poziv loggera na serveru.
- Trenerov spisak domaćih više ne nosi adresu učenika.
- Verifikacioni kod je iz `crypto.randomInt`.
- Socket token se čita samo iz `auth` rukovanja, ne iz URL-a.
- Linija duža od 100 KB i potez duži od poteza se **odbijaju** sa brojem, umesto
  da se odseku u korak koji se ne može odigrati. Naslov i zadatak se i dalje
  seku, po ranijoj odluci koju testovi čuvaju — vidi pitanje ispod.
- IP adresa droplet-a uklonjena iz `TODO-objavljivanje.md`.

**Aplikacija:**
- PGN pisac sobe sada zapisuje `!`/`?` koje čitač čuva.
- Srpske reči bez dijakritika na ekranima prevedene (trener završnica je pisao
  „Position: remi"), a `vocabulary_en_test.dart` sada zna i za takve reči.
- Traka napretka videa se završava kad server odbije posao (4xx) i posle 20
  neodgovorenih pitanja, umesto da zauvek čeka.

**Testovi koji nisu mogli da padnu:** vlasništvo grupe i trenera sada proverava
ceo uslov upita; čuvar „nema četvrte kopije" traži `status = 'accepted'` u svakom
obliku upita; provera 403 za prekidač gostiju čita telo rute bez komentara;
dijalozi na telefonu proveravaju da je dugme u dijalogu; trener završnica ima
test žice na obe strane (putanje, parametri, telo, prijava).

Brojke: aplikacija **2677 → 2689**, backend **1350 → 1374**, analyze 26.
Provera uživo: `TODO-provera.md`, stavka 169.

**Četiri odluke vlasnika, 16.9.2026 uveče:**
1. **Ograničenja besplatnog naloga — obrisana.** `checkUserLimits`,
   `ENABLE_LIMITS`, `unlimited_lessons`/`unlimited_sessions` i brojevi „n / 20",
   „n / 5" na kartici naloga nisu nikad ništa sprovodili. Obrisani su, zajedno sa
   dve stavke „Unlimited …" u Premium dijalogu koje su prodavale neograničeno
   naspram granice koje nije bilo. `limitsService.js` sada samo broji. Plaćene
   stvari se i dalje zatvaraju kroz `requireEntitlement` / `requireQuota`.
2. **Ključ RTDN-a u URL-u — ostaje za sada.** Sam po sebi ne daje ništa (poruka
   je samo token koji se ponovo proverava kod Google-a); zabeleženo u
   `TODO-objavljivanje.md`, odeljak 6.
3. **Predug naslov, zadatak ili izbor — odbija se sa brojem**, kao i linija i
   potez. Stari test koji je tvrdio suprotno je preokrenut i to kaže.
   Rečenice modela za tutorijal iz partije sada su ograničene na 500 znakova
   (`answerSlotChars`, bilo je 600), da generisani zadatak ne bi bio odbijen tek
   pri čuvanju.
4. **`POST /games/mistakes` — samo zabeleženo.** Ruta za greške motora iz
   klijentove analize postoji i testirana je, ali je **aplikacija ne poziva**:
   dril sopstvenih grešaka dobija samo greške iz tablica završnica (serverska
   provera, `mistakeReviews.js`), a deo `/recurrence` po taktičkom motivu nikad
   nema podataka. Ne čitati brojeve drila kao da pokrivaju greške motora.

## Soba iz revizije (blok B) — 16.9.2026, u kodu

Revizija je našla da se imena socket događaja između aplikacije i servera ne
slažu od commita `6a6b0dd` (10.8.2026): server je preimenovao događaje sobe, a
aplikacija je zadržala stara imena. Petnaest slušalaca u aplikaciji nije imalo
pošiljaoca, pet poruka iz aplikacije nije imalo primaoca. **Učenikova tabla nije
pratila trenerove poteze** — stablo jeste, preko `pgn_loaded`, pa je izgledalo da
radi — i to se nije videlo pet nedelja jer je svaka provera sobe bila na jednom
uređaju. Isto tako mrtvi: „Force student board to…", „Position sent to
trainer!", „Invite to lesson" sa spiska učenika, utišaj/dozvoli govor, „Mute all
students" i podignuta ruka.

Šta je urađeno:

- **`test/socket_contract.test.js`** čita obe strane (Dart i JS, komentari
  uklonjeni skenerom koji zna za stringove) i traži da svako ime ima par u oba
  smera, plus da nijedno ime nije izračunato. Dokazano sa tri mutacije.
- Aplikacija sluša `move`, `board_flipped`, `role_changed` (obaveštenje samo kad
  ga domaćin promeni, `changed: true`), `recording_status_changed`,
  `lesson_invite_received`; utišavanje ide kroz `audio_mute_toggle` sa
  `userId`, ruka kroz `audio_hand_raise_toggle`.
- Server šalje utišanom članu `audio_force_mute_student` / `…unmute…`, svima
  pri „Mute all" isto sa `'all'`, i `audio_hand_raised_alert`; deljenje pozicije
  je vraćeno u `services/roomBoardEvents.js` (samo onaj ko sedi u sobi, samo
  članu te sobe, ime sa soketa).
- **Poziv na čas sa spiska učenika** ide kroz `POST /invitations/send`
  (provera veze + red u obaveštenjima), koji sada i odmah javlja otvorenoj
  aplikaciji. Socket `send_lesson_invite`, bez ikakve provere, je obrisan.
- **Kasni ulazak u sobu** dobija `gameState` sa pozicijom sobe (primenjuje se
  samo na prazno stablo, da ponovno povezivanje ne obriše trenerovu lekciju) i
  dozvolu za motor iz `permissions_updated`.
- **Primljeni PGN** se čita od svog `[FEN]` zaglavlja, ne od korena primaoca
  (`lib/core/services/room_tree_sync.dart`) — posle trenerovog učitavanja
  pozicije primalac je dobijao prazno stablo.
- Glasovne i deljene kontrole pitaju **mesto u sobi**, ne ulogu iz URL-a:
  ulazak kodom stiže kao `korisnik`, pa provera za `ucenik` nije palila ni za
  koga ko je ukucao kod.
- **„Save position" u sobi** je slao `fen` sa table i `pgn` od korena — greška
  od 6.9.2026, još živa u sobi. Sada oba iz korena i čita se nazad pre čuvanja.
- **„Edit positions"** više ne piše `tags: ['lekcija_kurs']` preko oznaka
  tutorijala.
- Obrisano: `toggle_blunder_alert`, `audio_speaker_active`, `leaveGame`,
  `user_presence_changed`, `session_invite_received`.

Brojke: aplikacija **2670 → 2677**, backend **1338 → 1350**, analyze 26.
**Najvažnija provera uživo je sa dva uređaja**: `TODO-provera.md`, stavka 168.

## Sigurnosni blok iz revizije — 16.9.2026, u kodu

Prva revizija cele arhitekture (četiri Fable prolaza, `docs/AUDIT-BRIEF.md`)
našla je 58 problema; `docs/AUDIT-2026-09.md` je ocena i redosled. Fajlovi
revizije **nisu u gitu** dok se ne zatvori sve što opisuje kako se nešto
zloupotrebljava (`.git/info/exclude`). Ovo je blok A, zatvoren istog dana, i
svaka ispravka ima test koji je viđen crven na starom kodu ili pod mutacijom:

- **Preuzimanje naloga pre registracije.** Ponovna registracija nepotvrđene
  adrese zadržavala je lozinku i ime prvog koji ju je upisao. Sada ih menja, a
  `/verify-email` odbija kod ako lozinka koju aplikacija još drži u formi nije
  sačuvana (`passwordChanged`). `test/registration_takeover.test.js`.
- **Snimak u tuđoj listi.** `POST /recordings/save` je uzimao `participants` i
  `audioUrl` iz tela, a `roomId` nije morao biti pozivaočev. Sada: soba mora biti
  njegova (403 i brisanje otpremljenog fajla), učesnici su samo oni koje je
  serverov spisak video, `audioUrl` se ne čita. `test/recording_participants.test.js`.
- **Potez u tuđoj sobi.** `move` i `pgn_loaded` nisu pitali da li je soket seo u
  sobu. Premešteni su u `services/roomBoardEvents.js` i traže `socket.roomId`;
  nesmešten soket se tiho ignoriše, jer lokalna „Priprema" (STUDIO) šalje poteze
  a nikad ne ulazi u sobu — da je dobila `action_denied`, crvena traka bi išla
  preko svakog poteza. `test/room_board_events.test.js`.
- **`POST /rooms/join`** je vraćao ceo red sobe svakome, bez ograničenja. Sada
  pita isti `mayJoinRoom` kao soket, vraća samo mesto (`role`), isti odgovor za
  „nema sobe" i „nisi na spisku", i ima limit 30 u 15 minuta. `test/rooms_join.test.js`.
- **Skripte koje brišu bazu** (`clear_users.js`, `import_new_puzzles.js`) odbijaju
  bazu koja nije lokalna, osim ako se imenuje: `--target=<host>`.
  `test/destructive_script_guard.test.js` ih stvarno pokreće.
- **100 MB JSON pre prijave** na `/recordings/*` — sada 2 MB svuda
  (`middleware/bodyParsers.js`, test preko pravog soketa).
- **Testovi za postojeće zaštite** koje ništa nije dokazivalo: četiri
  `trainerOwnsStudent` provere u `routes/assignments.js`, odbijanje tokena za
  preuzimanje kao prijave, `POST /login`, i donja granica od 13 godina na ruti.

Brojke: backend **1289 → 1338** (+49), aplikacija nepromenjena na 2670, analyze
26. Provera uživo: `TODO-provera.md`, stavka 167.

Nije rađeno iz revizije, a sledeće je: soba (blok B — imena socket događaja se
ne slažu od 10.8.2026, prvo provera sa dva uređaja), pa srednji nalazi. Revizija
sama po sebi nije dokaz: ono što je označeno „Reasoned" još niko nije proverio.

## Repertoar se gradi na tabli — `PLAN-REPERTOAR-RUCNO.md` — 16.9.2026, u kodu

Vlasnik je 15.9.2026 tražio da se gradnja repertoara pojednostavi koliko god može,
i to je pretvorio u pravilo: **potez koji korisnik nije sam uneo je potez kroz
koji nije prošao**. Svaki unos u stablu je potez odigran na tabli; knjiga
otvaranja je pomoć pored table. Jedini izuzetak: kad se prvi put zadrži sopstveni
potez, uz njega se upiše **najigraniji odgovor iz knjige**, kao običan uneti potez
koji se može obrisati — da se ne gradi odgovor na sporednu varijantu dok glavni
nastavak fali.

**Šta je izbačeno:** „Suggest main line" (spine), širina (breadth), nepotvrđeni
potezi i njihov pregled, „Take X"/„Discard", „Next" (talas odgovora), „Do not
prepare this" i vraćanje odsečene grane, „Back to X", „Open book (1 query)" i
brojač upita. Procenat „unanswered %" je zamenjen brojem pozicija.

**Model:** strana protivnika je sada samo `repertoire_extra_replies` (ime je
starije od modela). Šetnje — `frontier`, stablo, linija za dril, orphan detekcija,
progress — idu kroz jedan `enteredReplies` (`repertoireFrontier.js`), koji knjigu
čita samo za broj partija i udeo; potez koji knjiga ne zna ima udeo 0 i prati se
kao svaki drugi. `GET /repertoire/book` sam puni poziciju iz lokalne knjige
(`repertoireBook.bookAt`), a `POST /node/move` upisuje najigraniji odgovor samo
kad je potez **nov** (`xmax = 0`) i ništa još nije uneto posle njega. Brisanje
sopstvenog poteza briše i odgovore koji ostanu bez poteza ispred sebe
(`sweepDanglingReplies`); brisanje poteza protivnika pita pre nego što odnese
korisnikove poteze iza njega. Protivnik u drilu igra unete poteze, ponderisane
brojem partija; potez van knjige teži kao najređi uneti potez koji knjiga zna.

**Ekran:** knjiga je red čipova kao u Analizi (`OpeningExplorerPanelWidget`, uz
`markOf` ★/✓ i broj partija), tap na čip igra potez. Tabla dozvoljava poteze za
obe strane. Pravilo i savet („za svoju stranu po mogućstvu jedan potez, za
protivnika jedan ili više") stoje ispod pitanja; priručnik
(`site/mislisha/manual/repertoire.html`) je prepisan oko istog pravila.

**P0 — vlasnikov korak:** postojeći repertoari su probni i brišu se. Pre
korišćenja novog build-a: obrisati repertoare na listi, pa „Delete moves from
database" za belog i za crnog. Migracija je napisana, puštena na suvo i obrisana
istog dana — prvi broj je bio 619 nedostižnih pozicija za jednu boju, što je
izgled podataka iz tri ranija modela.

**Mutacije (server):** 25, uhvaćeno 24; preživela je provera `if (played)` u
`sweepDanglingReplies`, jer chess.js baca izuzetak umesto da vrati null — linija
je obrisana.

**Otvoreno:** provera uživo (TODO-provera 166). Kolone `repertoires.breadth` i
tabela `repertoire_skips` ostaju nečitane, za posebno brisanje.

---

## Otvaranja iz naše baze — `PLAN-OTVARANJA-LOKALNO.md`, faze 0–4 — 15.9.2026, u kodu

Statistika otvaranja se više ne traži od Lichess-a. Do sada je samo šetnja kroz
otvaranje u tutorijalu iz partije čitala lokalni SQLite (D5 plana skeleta); sve
ostalo — panel u Analizi, sudija poteza, repertoar — išlo je na Lichess
explorer, i to na **tuđi token**: sudija traži *korisnikov sopstveni* token za
sva četiri upita i bez njega odgovara `no-token`, pa je repertoar u praksi bio
isključen za skoro sve. Dve od te četiri stvari su knjiga, a druge dve su
procena koja odgovara i **bez ikakvog tokena** (provereno 15.9.2026:
`lichess.org/api/cloud-eval` vraća 200, dubina 60).

**Odluke vlasnika, 15.9.2026.** Jedna baza, 2200+, bez rejting-opsega — dete
uči ispravan potez bez obzira na svoj rejting, a ne da oponaša ono što se na
njegovom nivou greši; filter po rejtingu se **briše iz aplikacije**, ne
preusmerava. Dubina 50 polupoteza umesto 30. Redovi koje je odigrala jedna
jedina partija se brišu. Nigde više lični token. ChessDB prekidač odlazi.

**Šta je izmereno pre nego što je odlučeno** (sve u planu, sa brojevima):
granica od 30 polupoteza seče **svaku** glavnu liniju — osam otvaranja staje
tačno na 30 sa 117 do 750 partija koje još stoje u poziciji. Brisanje
jednokratnih redova skida 85.1% redova i 87.3% pozicija, ali te redove drži
2.2% partija u preživeloj poziciji u proseku i **80%** u najgoroj, pa se pravi
zbir po poziciji upisuje u `position_totals` **pre** brisanja. I: brisanje
skraćuje knjigu u **8 od 13** partija iz harness-a, a u svih osam je pozicija na
kojoj se staje bila dosegnuta **jednom jedinom** partijom (g09 šest polupoteza,
g03 tri). To je ispravka, ne gubitak, ali menja ono što nov tutorijal kaže.

**Urađeno i mereno.** `tools/opening_book/extract_stats.py` je dobio `--max-elo`
i `--prune`. **Taj fajl je već bio u repozitorijumu**, na engleskom, od faze 2
plana skeleta — vlasnikova kopija u `D:\chess_base` je srpski original od koga
je preveden i od tada su se razišli (prevedena verzija je preimenovala kolone u
`chunks`, pa baza koju je počela jedna ne može da se nastavi drugom). Merodavna
je ona iz repozitorijuma i njome se gradi; `services/mastersBook.js` je
`services/openingBook.js` i čita `position_totals`, razlikuje „niko ovo nije
igrao" od „fajl ne ide tako duboko" (`beyondBook`), kaže zašto je šetnja stala,
i odbija neispravan FEN kao lošu molbu umesto kao praznu knjigu; `GET
/opening-explorer` odgovara iz fajla, a `services/openingExplorerService.js` je
obrisan sa svojim kešom, pejserom i testom. **1329 na backendu** sa `.env`
sklonjenim; deset mutacija, svih deset uhvaćeno.

**Faza 0: fajl je gotov i prošao je kapiju.** 10,355,488 pročitanih partija i
2,567,674 uzetih — isti brojevi kao stari fajl, deo po deo. Posle sažimanja
4,507,012 redova nad 3,552,524 pozicije, i **145 MB** (procena „ispod 500 MB"
bila je pre sažimanja). `--verify-hash` se slaže sa python-chess na 908,577
polupoteza. Kapija je `tools/opening_book/compare_books.py` i ostaje u
repozitorijumu za sledeću promenu ekstrakcije: od 3,589,929 redova koje stari
fajl drži sa bar dve partije **nijedan ne fali i nijedan nije manji**; 12,039
(0.335%) je porastao, jer dublja ekstrakcija broji i partije koje do pozicije
stignu tek posle 30. polupoteza — pa „isti brojevi" iz plana nije moglo da
važi i kapija to kaže. Svih 13 harness partija staje tačno gde je simulacija
rekla. Kapija je prvo puštena na **pogrešan** fajl (stari, nesažeti), i njena
prva verzija je tu prošla šetnju — čitala je novi fajl kroz isti filter „bar dve
partije" kao simulacija. Sad čita svaki red, kao server, i pada na 11 provera.
`MASTERS_BOOK_PATH` u razvojnom `.env` pokazuje na novi fajl, a
`kMastersBookPlies` je 50.

**Faza 3: sudija bez tokena.** Knjiga je lokalna (`sharedOpeningBook()`, jedan
primerak za sudiju i explorer), procena ide na Lichess cloud-eval bez tokena, a
pitanje o rejting-opsegu je obrisano u celini — i `minRating` je nestao iz
**svih** servisa i ruta repertoara, ne samo ignorisan na jednom mestu.
`no-token` više ne postoji ni na serveru ni u aplikaciji: `hasPersonalToken`,
zaglavlja `X-Lichess-Token` (sudija, odgovori, kičma, izveštaj o rupama), stanje
panela bez tokena i baner u izveštaju. Pozicija dublja od knjige ne navodi ništa
i kaže `beyondBook` — u presudi, u listi odgovora, i kao treći razlog zašto je
kičma stala (`beyond-book`), koji ekran sad piše drugačije od „too thin" (a
`illegal` drugačije od oba, što ranije nije). Server bez knjige odgovara 503 sa
razlogom na sve tri rute, nikad presudom samo od motora. `MIN_MASTER_GAMES`
ostaje 10, **izmereno**: na 13 harness partija lokalna knjiga i Lichess masters
se slažu (medijana 0.99 po potezu), a na 10 lokalna čuva 783 od 795 poteza koje
je Lichess zvao teorijom. `MIN_SPINE_GAMES` ostaje 100, izmereno: sa devet
čestih korena najigranija linija prvi put padne ispod 100 partija 14 do 32
polupoteza unutra. Usput nađeno: cloud-eval piše rokadu kao „kralj uzima topa"
(`e1h1`), pa se linija ispod presude tiho prekidala na rokadi („better was O-O"
je ispadalo kao ništa) — sad se čita kao rokada.

**`opening_replies` je prepisan, a ne obrisan** — odstupanje od plana, iz
merenja: razvojna baza je imala 396 sačuvanih skupova (pozicija, opseg) iz
1,251 poteza repertoara jednog korisnika, a drill, stablo i frontier ne čitaju
ništa drugo. Obrisano, svaka nacrtana grana bi nestala dok se pozicija ne otvori
ponovo, bez ijedne reči zašto. Zato kolona `source` (NULL za stare redove),
čitaoci traže `source = 'book'`, a `refreshStoredReplies` jednom pri pokretanju
prepiše stare redove iz knjige i obriše samo pozicije o kojima knjiga ne može da
govori. Strani ključevi: nijedan ne pokazuje na tu tabelu.

**I prepis je pušten pre pregleda.** `npm run dev` (nodemon) se restartuje na
svaku izmenu `.js` fajla, pa je razvojni server u 12:36 pokrenuo migraciju i
prepis nad **necommitovanim** kodom — dok je `.env` još pokazivao na stari fajl
od 30 polupoteza, nesažet. Odgovori u razvojnoj bazi su zato iz tog fajla,
uključujući poteze jedne partije (298 pozicija, 1,442 reda). Pušteno je jednom i
bez mutacije: posle 12:37 ništa nije upisano, a mutacije koje su usledile nisu
imale NULL redove da diraju. **Ponovljeno na vlasnikov zahtev istog dana u
13:09:** `UPDATE opening_replies SET source = NULL` pa restart, sad nad fajlom od
50 polupoteza. Rezultat: 1,125 redova nad 272 pozicije, svi `source = 'book'`,
nijedan NULL, i nijedan odgovor sa manje od dve partije — što samo sažeti fajl
može da da. 26 pozicija je otpalo jer ih sažeta knjiga ne pokriva.

Brojevi: **1343 na backendu** sa `.env` sklonjenim (1329 − 7 − 24 + 29 + 6 + 1 +
1 + 8), **2692 u aplikaciji** sa 1 preskočenim (ova promena dodaje 7; broj
2684 u CLAUDE.md je bio jedan manji od `master`-a), analyze 26 infos i nula
upozorenja. Mutacije: 21 na serveru i 9 u aplikaciji, sve uhvaćene, svaka testom
koji je za nju pisan. Provera uživo: stavka 164.

**Faza 4: aplikacija (batch 71, `46c2cb2`).** Panel u Analizi ide samo na naš
server i kaže u kom je od pet stanja — prijavi se, knjige nema na ovom serveru,
knjiga nedostupna, dublje od knjige, nijedna majstorska partija — pod ECO imenom
koje ekran već računa (`displayOpeningName`). Obrisani su ChessDB, prekidač
izvora, ceo odeljak „OPENING EXPLORER" u Settings sa poljem za token, meni
„Opponent rating" na listi repertoara, „Book: games from …+" ispod stabla i
svaki `minRating` koji je aplikacija slala; token koji uređaj već čuva briše se
pri učitavanju podešavanja. Zagonetke u domaćem zadržavaju svoj `minRating` — to
je težina zagonetke, ne knjiga. **Polje za token nije ostalo „za uvoz partija"**
kako je plan pisao: uvoz ide preko serverovog tokena i to polje nikad nije
čitao. Usput: „Osnovna linija" u biraču otvaranja je sada „The opening itself"
(ne „Main line" — pet otvaranja u ECO podacima ima i varijantu „Main Line", pa
bi dva reda isto glasila za dve različite pozicije), commit `d0c6b6c`.

**Worker je istekao posle 75 minuta sa pola posla** i bez izveštaja — većinu
vremena je čekao sopstveno merenje suite-a. Ono što je napisao bilo je ispravno,
osim dve srpske log poruke i nekoliko polomljenih rečenica u komentarima; ostatak
je dovršio vodeći u istom worktree-u. Pun suite je onda našao **dva propusta u
brief-u**: priručnik na sajtu (`site/mislisha/manual/`) je citirao tri obrisane
kontrole, a `repertoire_build_test.dart` je proveravao rečenicu koju je brief
naložio da se prepiše. Oba ispravljena. Kapija 26/26, pet mutacija nad njom, sve
uhvaćene. **2716 u aplikaciji** sa 1 preskočenim, izmereno na `master`-u (2692 +
26 kapija − 3 penzionisanog testa panela + 1 za „The opening itself"), analyze
26 infos; backend nepromenjen na 1343. Provera uživo: stavka 165.

**Šta sledi.**

**Fajl je na droplet-u (15.9.2026).** Prebačen ručno `scp`-om u
`/home/chess/data/opening-book/` (van git checkout-a, vlasnik `chess`, 0444),
SHA-256 se slaže sa lokalnim, `quick_check` ok, `meta` i broj redova isti kao u
fazi 0; `MASTERS_BOOK_PATH` u serverskom `.env` pokazuje na njega (stari `.env`
sačuvan kao `.env.bak-2026-09-15`). Servis i dalje stoji ugašen. **Kod na
droplet-u je još `89aa8c6`**, pre faze 1, pa knjigu ne čita — oživeće kad
`app-setup.sh` povuče `master`.

Istog dana je serverski `.env` dopunjen prema razvojnom (samo imena, vrednosti
upoređene hešom; prethodno stanje u `.env.bak-2026-09-15-2`): `GOOGLE_CLIENT_IDS`
je dobio Windows desktop klijenta (bez njega svaka Google prijava sa Windows-a
na ovaj server pada), prekopirani su `DEEPSEEK_API_KEY`, `AZURE_SPEECH_KEY`,
`AZURE_SPEECH_REGION` i `TTS_PROVIDER=azure`, a `PUBLIC_BASE_URL` je
`https://api.chesstrainers.app`. Namerno nisu preneti `AZURE_OPENAI_*` i
`DASHSCOPE_API_KEY` (server ih ne čita), Piper putanje (na droplet-u nema
`/opt/piper`, pa nema rezervnog glasa ako Azure padne) i `SYZYGY_SIDECAR_URL`.

**Odluka vlasnika, 15.9.2026:** razvoj i provere uživo ostaju na lokalnom
serveru (isti fajl od 145 MB). Servis na droplet-u ostaje ugašen i isključen do
prelaska, da se Socket.IO sesije i `uploads/` ne podele između dva servera nad
istom bazom. Glas je Azure; Piper se instalira kasnije, samo ako zatreba.

1. **Faza 5**: `deploy/app-setup.sh`, kako fajl stiže na server koji još stoji
   ugašen, i šta biva kad ga nema. `.env.example` je već ispravljen u fazi 3
   (`LICHESS_EXPLORER_URL` i `LICHESS_MASTERS_URL` se više ne čitaju).

**Šta i dalje ide na Lichess kad se ovo završi:** jedan upit, dvaput po
suđenom potezu, keširan — `api/cloud-eval`. Bez tokena, isti broj za sve.
Uvoz sopstvenih partija sa lichess.org, Syzygy i uvoz zagonetki nisu baza
otvaranja i ostaju kakvi jesu.

## Izlazak iz masters baze, kraj linije bez reči, i tutorijal iz studije — 15.9.2026, u kodu

Tri prijave vlasnika istog dana, prve dve popravke, treća pitanje na koje je
odgovor „već radi, i evo šta ne radi". Provera uživo: `TODO-provera.md`, stavka
163.

**1. „And the line goes on" se više ne nudi modelu.** U delu sa najboljom
linijom svaki potez posle prvog nosio je činjenicu `; the best line goes on -
not played`, a u delu sa drugim najboljim `; the line goes on` — i model ih je
vraćao doslovno, na svakom potezu svake linije: „Black would answer Ra7. Not
played either; best line goes on." To je isti nalaz koji ovaj projekat već ima
zapisan za detektor motiva (**kad model ponavlja ulaz reč po reč, ulaz je
proizvod**): čišćenje se radi u onome što se šalje, ne u onome što se traži.
Oznaka je sada samo `; not played` — dve reči na koje se pravilo iz prompta
oslanja — a prompt je dobio i pravilo koje nedostaje: *rečenica čiji je jedini
sadržaj da se linija nastavlja ne piše se; potez koji nema šta da kaže dobija
prazan slot*. Prazan slot je već bio dozvoljen i tabla nad njim ćuti.

**2. Statistika masters baze stoji na poziciji koja to zaista jeste.**
Rečenica „This move left the masters database: 698 master games reached this
position and none played it." pisala se na **potez** kojim se izašlo iz baze — a
komentar na potezu je u PGN-u komentar pozicije **posle** njega. Đak je dakle
stajao na tabli do koje nijedna master partija nije stigla i čitao da je do nje
stiglo 698 partija. Sada je to `mastersDeparture` (`skeleton_assembly.dart`,
`_masters_departure` u `skeleton.py`): rečenica ide na **prethodni** potez, tamo
gde je na tabli poslednja pozicija koja je bila u bazi, nabraja poteze koje baza
tu igra sa procentima i crta ih kao **zelene strelice**, pa imenuje potez koji
je igrač odigrao — i tek onda se taj potez odigra.

> Up to here the game followed the masters database: 1367 master games reached
> this position and played Nf6 77%, Bb4+ 15%, c6 3.0%. Black played g6, which
> none of them did.

Tri imena i tri strelice su isti potezi (`book['alternatives']`, već odsečen na
tri): spisak imena bez strelica je spisak koji slušalac ne može da prati, a
strelica bez imena je potez koji niko ne može da potraži. Plava strelica i dalje
znači „ovo je odigrano", zelena „ovo baza igra" — dve boje jer odgovaraju na dva
pitanja, a na ovoj tabli đak sreće oba.

Dva nalaza o proveri koja su došla uz ovo.

**Kapija nije poredila nijednu strelicu.** `game_tutorial_skeleton_test.dart`
poredi `pgn` tako što ga pročita nazad kroz dečji čitač i uporedi poteze i
komentare — a `[%cal]` čitač skida iz komentara, pa je plava strelica račve,
nacrtana od 14.9.2026, mogla da nestane a da kapija ostane zelena. Sada se
porede i strelice, korena i svakog poteza; dokazano mutacijama u oba smera.

**Sve partije izlaze iz baze između 3. i 13. poluopoteza**, pa grana koja
rečenicu piše na **tablu samog dela** (partija čiji prvi potez nijedna master
partija nije igrala) nije bila dostižna nijednim podatkom. To je isti oblik koji
ovaj fajl već zna — *kapija napravljena od stvarnih podataka ne vidi ono što ti
podaci nikad ne rade* — pa `edge_cases.json` sada nosi i varijantu g01 sa
`left_book` na poluopotezu 0.

**3. Tutorijal od niza poteza, ne od cele partije — već radi.** Pitanje je bilo
može li se na automatsko generisanje poslati studija sa jednom ili više početnih
pozicija, sa sporednim linijama koje već imaju komentare, iz PGN-a ili sa table
u Analizi. Odgovor, izmeren a ne pročitan
(`game_tutorial_flow_test.dart`, „a study position and its main line are what
the run is given", obe polovine dokazane mutacijom):

- **Radi, i radi već sada.** „Make a tutorial from this game" u Analizi šalje
  `root.fen` kao početnu poziciju i glavnu liniju stabla kao poteze. Pozicija ne
  mora da bude početna: FEN iz studije putuje kakav jeste. Masters šetnja tu ne
  nađe ništa, pa tutorijal ćuti o otvaranju (`mastersNote` se javlja samo kad
  baza nije dostupna, ne kad pozicija nije u njoj).
- **Sporedne linije se ne šalju.** Vrata idu `children.first` do kraja, tako da
  je poslato tačno glavna linija. Studija sa granama daje tutorijal od svoje
  glavne linije, a grane se tiho izostave.
- **Postojeći komentari se ne koriste.** Na put ide samo lista UCI poteza;
  `motifs_after_played` u činjenicama je ono što detektor motiva sam napiše za tu
  poziciju, ne ono što je trener napisao. Trenerove reči nigde ne ulaze.
- **Više početnih pozicija nije podržano.** Jedno pokretanje = jedan koren i
  jedna linija. Studija sa nekoliko poglavlja tražila bi nekoliko pokretanja.
- **Prag i dalje važi**: ako u nizu nema bar dva poteza koja koštaju onoliko
  koliko je traženo, pokretanje staje pre reči i ništa se ne troši. Kratka
  studija od pet poteza po pravilu neće imati dva.

Šta bi tek trebalo napisati, ako se to bude tražilo: čitanje sporednih linija
kao već napisanog dela tutorijala (`LessonStepLine` ih već ume, prikazivač ih
već nudi kao račvu) i preuzimanje trenerovih komentara umesto da ih model piše.
Ni jedno ni drugo nije u planu i ništa danas ne zavisi od njih.

## Tutorijal iz partije kao priča — 15.9.2026, u kodu

Odgovor na B, C i naraciju iz druge provere (niže), i na dve dopune vlasnika
(„partija je borba", „početak nagoveštava, kraj kaže ko je pobedio"). Plan i
merenje: `docs/PLAN-NARACIJA.md`. Vlasnik je pročitao deset partija napisanih
tri puta (stari prompt, priča, priča sa početkom i krajem) i odlučio: **priča
potpuno zamenjuje stari prompt**.

Šta sada važi. Potez se ne najavljuje („Black plays Qc7, the queen from d8 to
c7" — 306 od 491 izgovorene rečenice sa starim promptom, 2 sa novim). Na grešci
program sam kaže „In this position White played Bd3." sa plavom strelicom
odigranog poteza (bez igranja), pa „The best move was…", i tek sledeći deo
igra najbolju liniju. Prekretnice partije (prva velika greška, šansa data i
iskorišćena ili propuštena, poslednja propuštena, materijal za aktivnost) računa
program iz ocena motora i daje ih modelu kao činjenice. Tutorijal počinje
rečenicom o tome kakva partija sledi, a završava se time ko je izašao kao
pobednik — iz mata na tabli ili poslednje ocene, jer PGN iz Analize nema
rezultat. Provera tvrdnji čita ceo momenat, ne jedan slot, i „no mate" nije
tvrdnja o matu.

Na kraju merenja rečenice na koje provera ne može da vidi i dalje postoje
(g10: „two chances each side" gde su dve ukupno) — zato arc sada broji po strani.

Aplikacija i server su usklađeni sa harnessom kroz fixture-e (`--check` zelen,
gate zelen, prompt servera bajt po bajt). Server prima i zahtev bez priče, pa
već instalirana starija aplikacija i dalje dobija odgovor. Provera uživo:
`TODO-provera.md`, stavka 162.

## Druga provera uživo: šest prijava (A–F) — 14.9.2026 uveče

Vlasnik je pregledao „The bishop pair and the open e-file (whole game)"
(sačuvana lekcija 57) u prikazivaču i u videu. A, D i E su u kodu; B, C i
naracija idu kroz `docs/PLAN-NARACIJA.md` (prvo merenje, pa ugradnja); F je
odgovor. Provera uživo: `TODO-provera.md`, stavka 161, tačke 17–20.

**A — tabla se okretala, ali ne zbog koda koji je ovde tražen.** Baza je rekla
tačno: lekcija 57 ima deo 1 crni dole i jedanaest delova beli dole, dok 55 i 56
imaju sve belo. Jedini put koji menja jedan deo je dugme „Flip board" u studiju,
koje je okretalo **samo otvoreni deo** i nije to nigde reklo. Pravilo vlasnika:
novi tutorijal iz partije je beli dole na svakom delu (`facingWhite`, orijentacija
Analize više ne putuje); „Flip board" u studiju okreće **svaki** deo, svaki
suprotno od onog kako stoji (mešavina ostaje mešavina); jedan deo se okreće u
„Preview tutorial" dugmetom „Flip this part", i to se upisuje u nacrt. Prikazivač
sada poštuje izričitu orijentaciju i na spoju delova — do sada je deo koji
nastavlja poziciju zadržavao tablu kakva jeste, što bi pregled učinilo
beskorisnim. Deo bez polja i dalje zadržava tablu.

**D — „the bishop on f6 is attacked by the g7 pawn with no defender" posle
`Bxf6`.** Detektor motiva je figuru koja je upravo uzela zvao visećom iako je
uzimanje nazad samo završava razmenu. Sada ta figura nije viseća kad uzimanje
nazad dobija **ne više** od onoga što je potez uzeo (dama koja uzme skakača pod
pešakom i dalje jeste). Isti zahvat je otkrio drugu grešku u sopstvenom prvom
nacrtu: kad se uzimanje sakrije iz „stvorenog", poređenje pre/posle je javljalo
„the white pawn on e4 is no longer hanging" usred `exd5` — pa se „rešeno" računa
prema punom čitanju, a „stvoreno" prema filtriranom. Deset `_reviewed.pgn` i
njihovi `_facts.json` prepisani su (`REVIEW_COMMENTS_ONLY=1`), provereni
rečenicu po rečenicu: samo uklonjene rečenice uzimanja nazad, plus nalazi koje
je ograničenje od tri po potezu ranije sakrivalo. Fixture-i regenerisani,
`--check` zelen.

**E — za učenike ili za video.** U poslednjem dijalogu, besplatno, jer su oba
tutorijala već sklopljena od istih reči: verzija za video izbacuje delove sa
pitanjem (`showOnly`), i broj delova se menja odmah.

**F — drugi jezik.** Sam poziv je jeftin: pet tutorijala vlasnika potrošilo je
57.022 tokena (oko 11 hiljada po tutorijalu, oko jednog centa), drugi jezik
dodaje možda pola centa, a prevod gotovog tutorijala manje od toga. Pravi trošak
je drugde: rečenice koje piše sam program („Back to the game", „The opening is…",
rekapitulacija, a posle plana naracije i rečenica na račvanju) trebaju prevod za
svaki od sedam jezika, a provera tvrdnji („sentences to check") radi samo na
engleskom. Planira se posle naracije, da se programske rečenice ne prevode dvaput.

Aplikacija **2659** (1 preskočen), analyze 26 infoa, nula upozorenja; backend
nepromenjen. Dvadeset mutacija, sve uhvaćene — jedna tek posle ispravke testa
(spoj delova nije bio spoj: pešak sa dva polja ostavlja en passant polje u FEN-u,
pa pozicije nisu bile iste). Usput: `game_tutorial_run_test.dart` je pod celim
paketom padao na 30 s i na nepromenjenom `master`-u (193 s sam, prema 89 s sa
izmenama), pa fajl ima svoj limit od 3 minuta.

## Skelet: devet prijava sa prve provere uživo — 14.9.2026, u kodu

Vlasnik je prvi put prošao ceo put — analiza partije, tutorijal, izvoz videa —
i javio da radi. Iz toga je izašlo devet stavki; sve su u kodu, ništa od toga
nije ponovo viđeno uživo.

**Majstorska baza nije bila greška u kodu.** „Tutorijal ne kaže ništa o
otvaranju" i `not-configured` u dijalogu: `routes/openingExplorer.js` pravi
knjigu **pri importu** (`createMastersBook()`), a podrazumevani parametar čita
`process.env.MASTERS_BOOK_PATH` u tom trenutku. Server je bio pokrenut u
12:00:30, a `.env` upisan u 12:26:17 — taj proces tu promenljivu nije mogao da
vidi, i `nodemon` ne prati `.env` (gleda `js,mjs,cjs,json`). Posle restarta
`POST /opening-explorer/masters-walk` vraća 200 sa pravim brojevima. **Pouka je
o merenju, ne o kodu**: pre nego što se traži greška u logici, uporediti kad je
proces startovan sa tim kad je konfiguracija upisana.

**Tabla stoji na jednu stranu.** `stepsFor` nije pisao `blackOrientation`, pa je
svaki deo padao na `blackToMoveIn(fen)` — pretpostavku koju dobija sačuvan korak
koji ne kaže ništa — i tabla se okretala sa time ko je na potezu. Sačuvana
lekcija 54 ima redom belo, belo, belo, belo, **crno, crno, crno**, belo, belo,
belo. Pečat se stavlja u aplikaciji (`facingOneWay`), namerno **ne** u skeletu:
`skeleton.py` nema tablu da je okrene, a orijentacija je svojstvo ekrana sa kog
je trener pritisnuo dugme. Video čita isto polje, pa prati bez ičega novog.

**Ista rečenica se ne kaže dvaput.** Svaki „odgovor" je govorio isti potez u dve
uzastopne rečenice, jer su `m*.answer.intro` i `m*.answer.1` dobijali istu
činjenicu. Model je bio veran — ponavljanje je bilo u ulazu. Uvod sada kaže šta
je partija odigrala i koliko je to koštalo, a **prvi potez linije imenuje potez**,
što je i bolja pouka: potez pročitan pre nego što se odigra je poklonjen potez.

**„Back to the game" posle sporedne linije.** Polovina je već postojala
(`kLexicon['resumed']`, tri varijante, piše ih aplikacija a ne model), ali samo
tamo gde postoji ispuna: kad su dve greške blizu, druga vodi svoj uvod unazad
preko prve, ispune nema i partija se nastavljala bez ijedne reči. U režimu
ključnih momenata mosta nije bilo **nigde**. Mereno pre popravke: cela partija
je imala most manje u 4 od 10 partija, ključni momenti ni u jednoj. Sada je u
obe: jedan po izabranom momentu, u ključnim momentima jedan manje (pre prvog
nema šta da se vrati). Vlasnik je 14.9.2026. potvrdio da ostaje i u režimu
ključnih momenata.

**Prag greške bira trener, i vidi šta je našao.** `minCost` je bio konstanta do
koje se nije moglo doći. Prvi dijalog sada pita i dubinu i prag (opseg i korak
kao u „Review game", ali podrazumevano 1.0 a ne 2.0 — 2.0 označava blunder i
seče zagonetku, 1.0 je ono što je faza 0 potvrdila kao „vredi učiti"). Posle
motora dolazi drugo pitanje: „6 moves cost 1.0 pawns or more", klizač koji
prebrojava dok se pomera, i ništa se ne troši do dugmeta. **Ovo je ispalo
jeftinije nego što je traženo** — činjenice se keširaju po partiji, dubini i
motoru, a prag **nije deo tog ključa**, pa drugo presecanje iste partije ne
košta nijednu sekundu motora; „pokreni analizu ponovo" nikad nije ni trebalo.
Kapa se kaže zasebno („The 8 worst become parts"), jer „23 nađeno" iznad
tutorijala od osam delova čita se kao greška u tutorijalu.

**Kritičan momenat, i povratak na njega.** Svaki ponuđeni momenat je već greška;
ono što je nedostajalo je **koji je odlučio partiju**. `decisiveMoment` označava
jedan, `turning_point` putuje u zahtevu, i prompt to kaže. Pravilo namerno
**nije** „najskuplji potez": izgubljena partija skuplja skupe promašaje koji ne
odlučuju ništa — na g01 se potez koji košta forsiran mat preskače zbog poteza od
2.11 pešaka, jer je prvi odigran iz već izgubljene pozicije a drugi je mesto gde
je izgubljena. Pitanje je `mistakeKind`, isti klasifikator koji leksikon ispune
već koristi, pa rečenica koju dete čita na tom potezu i momenat nazvan
odlučujućim ne mogu da se raziđu. Ista funkcija se pita dvaput: jednom nad svim
momentima (pre nego što model bira, da prompt zna), jednom nad izabranima (da
rekapitulacija na kraju postoji i kad je model preskočio označeni). Rekapitulacija
je samo u režimu cele partije, kako je i traženo.

**Linija se ne seče dok je žrtva neplaćena.** Prijava: sporedna linija se
završava na poziciji gde je beli bolji a ne vidi se zašto. Mereno pre popravke:
**16 od 69 delova** se završavalo sa igračem u minusu, dakle svaki četvrti. Sada
linija ide dalje dok materijal ne izađe na svoje, ograničena `max_answer_plies`
— 16 → 7, a 53 dela su netaknuta. Na g01 `g7 Qe8 h7+ Kxg7 h8=R Qxh8` ide 0, 0,
0, −1, +3, −2: presečena na četiri staje na „pešak manje", a jedan potez dalje
staje na promociju, što je cela ideja linije. Preostalih 7 su linije čija
nadoknada uopšte nije materijalna.

**I šta radi drugi najbolji potez.** Traženo je usko: „kad je žrtva opravdana i
najbolji potez". Napisano prvo za svaki momenat sa slabijom alternativom, palilo
se na **67 od 69** — drugi deo skoro na svakom odgovoru. Uslovljeno time da
najbolja linija stvarno nešto daje, to je **29 od 69**. `givesMaterial` pita celu
prikazanu liniju a ne prvi potez, i to nije sitnica: **nijedan najbolji potez u
deset partija iz fixture-a ne daje materijal na prvom potezu**, pa bi pravilo
koje gleda tamo bilo pravilo koje se nikad ne pali; postoji test koji tu nulu
drži. Alternativa je uvek najbolji **jasno slabiji** kandidat — sve unutar
`near` je jednako dobro, i nazvati to slabijim potezom bila bi rečenica koju
činjenice ne pokrivaju.

**Zašto je alternativa zaseban deo a ne varijanta.** Odlučeno čitanjem
prikazivača, ne ukusom: `lesson_viewer_screen.dart:490` prekida vođenu šetnju na
račvanju i traži od deteta da bira. Varijanta bi zaustavila „Pusti tutorijal"
baš u trenutku kad se odgovor prikazuje, i ponudila izbor između tačnog i
slabijeg poteza pre nego što je o ijednom išta rečeno. Film takođe ignoriše
varijante — taktovi prate kičmu — pa bi kao varijanta ovo bilo nevidljivo u
svakom izvezenom videu. Kao deo se čita, govori i snima kao i svaki drugi.

Aplikacija **2649** (1 preskočen), backend **1324** (`.env` sklonjen), analyze
26 infoa, nula upozorenja. Sedam commit-ova, oba čuvara razlaza zelena
(`export_fixtures.py --check` i gate porta). Promptovi su narasli za oko šestinu
— najveći 30.5 KB prema serverskoj granici od 120 KB.

**Ostaje otvoreno.** (1) Provera uživo: sve iznad je viđeno samo prema snimljenom
odgovoru modela, a snimljeni odgovori su stariji od svih ovih izmena, pa fixture
tutorijali i dalje pokazuju stari tekst. (2) Druga polovina prijave o žrtvama —
„kad jedna strana žrtvuje a druga može da prihvati ili ne, pokazati oba" —
traži **nova pretraživanja motora** unutar linije (motor je pitan samo o
pozicijama iz partije), oko 8 dodatnih pretraga po partiji i podizanje verzije
keša, što znači ponovnu analizu već keširanih partija. Mereno: takva žrtva
postoji u 27 od 69 linija. (3) `kFactsLineLength` je 6 iako motor vraća ceo PV —
`candidateOf` ostatak baca; podizanje je zasebna odluka sa istom cenom keša.

## Skelet: faza 4, vrata — 14.9.2026, u kodu

U Analizi „Make a tutorial from this game" (samo gde postoji studio): izbor
dubine sa vremenom (pamti se), pa jedno pokretanje — motor na uređaju,
majstorska baza, činjenice, reči sa servera — i na kraju **Key moments** /
**Whole game**, oba napravljena, jedan otvoren u studiju. Napredak kaže fazu i
„N of M positions · about X minutes left"; Cancel odmah gasi motore i ne nudi
se dok se reči pišu (taj poziv se naplaćuje). Svaki prekid je rečenica: nema
motora (sa dugmetom za podešavanja), partija se ne odigrava, motor pao dva puta,
manje od dva momenta, svako odbijanje rute za reči, odgovor koji se ne sklapa.
Majstorska baza nedostupna **nije** prekid — tutorijal se pravi bez nje i to se
kaže.

Arhiva: greška u „Mistake drill" ima „Open this game in Analysis"; server
vraća poteze partije (`GET /games/:id/moves`, samo sopstvene partije naloga), a
Analiza stoji na potezu greške, okrenuta strani igrača. Lichess rokada
(`e1h1`) čita se kao rokada samo kad je igra kralj.

Aplikacija **2540** (1 preskočen), backend **1321** (`.env` sklonjen), analyze
26. 39 mutacija, sve uhvaćene — tri tek posle novih testova za slučajeve koje
nijedna partija iz fixture-a ne dostiže (partija bez otvaranja, tačno jedan
momenat, nelegalan potez iza kog sledi legalan).
Ništa od ovoga nije viđeno uživo: `TODO-provera.md`, stavka 161 — pre nje
vlasnik traži pro nivo za svoj nalog. **Sledeće: faza 5**, provera uživo.

## Skelet: faza 3, ruta za reči — 14.9.2026, u kodu

`POST /lessons/from-game/words`: aplikacija šalje skelet kao podatke, server od
njega piše prompt (šablon je jedan fajl, `services/prompts/tutorial_words.txt`,
koji čita i harness), pita DeepSeek (`deepseek-flash`, effort low) i vraća reči
kad su u traženom obliku. **Prompt je bajt po bajt isti kao harnessov na svih
deset partija.** Partija se šalje **bez PGN zaglavlja** — imena igrača su
trenerovi učenici, a model je tuđ; server odbija zahtev sa zaglavljem.

Kredit se rezerviše pre poziva i vraća ako reči nisu napisane; tokeni svakog
pokušaja se beleže (`ai_tutorial_tokens`). Backend **1316**, aplikacija
nepromenjena (2489). 36 mutacija, sve uhvaćene posle tri izolovana testa.

D6, broj tutorijala mesečno po nivou: **privremene vrednosti ostaju za sada**
(vlasnik, 14.9.2026) — premium 30, pro 100, club neograničeno, free nema. Pravi
poziv DeepSeek-u sa servera još nije napravljen (faza 5). Za proveru uživo
vlasnik će tražiti da mu se nalogu dodeli pro nivo — tek kad to zatraži.
**Sledeće: faza 4**, vrata u aplikaciji.

## Skelet: faza 2, činjenice na uređaju — 14.9.2026, gotovo

Činjenice partije se prave u aplikaciji: `game_tutorial/game_facts.dart`
(redovi, cena, „stands out", majstorska statistika, pravilo 1 i spavanje) i
`game_tutorial_io/` (Stockfish procesi, pamćenje odgovora, sat za spavanje,
klijent za majstorsku bazu). **Svih deset partija kroz `lib/` na pravom motoru
identično je harnessu**, a drugo pokretanje iz sačuvanih odgovora ne traži
ništa (4–8 s umesto 32–97 s). Aplikacija **2489** (1 preskočen), backend
**1278**, analyze 26.

**Majstorska statistika dolazi iz lokalne baze na serveru** (odluka D5,
vlasnik): Lumbras GigaBase OTB, oba igrača 2200+, bez dopisnih partija, prvih
30 polupoteza — 2,57 miliona partija, 512 MB. Poređenje sa Lichess masters na
163 pozicije: isti najigraniji potez u 99%, remi 2,9 poena manje (sa prosekom
2200 bilo je 6,5). Imena otvaranja daje ECO skup aplikacije (52 od 52 ista kao
Lichess). Ruta je `POST /opening-explorer/masters-walk`, baza se kopira na
server ručno (`MASTERS_BOOK_PATH`); skripta i uputstvo su u `tools/opening_book/`.

Otvoreno: licenca Lumbras GigaBase za plaćenu aplikaciju i kopiranje baze na
server (`TODO-objavljivanje.md`). **Sledeće: faza 3**, ruta za reči na serveru.

## Skelet: faza 0, merenje na Windows-u — 14.9.2026, gotovo

`chess_app/tool/game_facts.dart` pravi činjenice deset partija kroz servise
aplikacije i preuzeti Stockfish (više procesa, jedna nit, prazan heš po
poziciji) i poredi ih sa harnessom. **Na dubini 18 svih deset je identično** —
kandidati, ocene, linije, „stands out", cena, rečenice detektora, pa i momenti i
odgovori na pitanja. Razlika je samo u en passant polju FEN-a (python-chess ga
piše samo kad je uzimanje legalno). Razlog: preuzeti Stockfish je isti binarni
fajl koji je harness koristio (isti MD5), a jedna nit na fiksnoj dubini je
deterministička. Poređenje je dokazano da ume da padne: g01 na dubini 16 daje 8
momenata umesto 6.

Vreme sa 8 radnika (laptop vlasnika, 16 logičkih procesora): dubina 18 je 39–109
s po partiji, 20 je 1,9–3,8× toga, 22 je 3,6–7,1×. **16 radnika ne pomaže**
(g03 čak 64 → 112 s), pa faza 2 broji fizička jezgra, ne logička. Tabela je u
`PLAN-SKELET.md`, faza 0.

Usput: baterija se ispraznila usred g03, osam pretraga je prešlo 15-minutni
timeout, odbačene su i ponovljene, i ishod je isti. Pravilo 1 je radilo, ali
spavanje preko oba pokušaja bi oborilo pokretanje uz rečenicu koja krivi motor —
zato plan sada kaže da graditelj prepoznaje skok sata i ponavlja poziciju bez
trošenja jedinog ponovnog pokušaja. Testovi se nisu menjali (alat je u `tool/`).
**Sledeće: faza 2**, činjenice na uređaju.

## Skelet u aplikaciji — plan i korak 1 — 13.9.2026

Plan je `docs/PLAN-SKELET.md` (opcija A): činjenice, skelet, provera odgovora i
oba moda (ključni momenti i cela partija) prave se **na Windows-u, gde živi
studio**; model piše samo reči, preko jedne rute na serveru koja prompt pravi iz
svog šablona — klijent nikad ne šalje prompt. Odluke vlasnika su upisane u plan:
dubinu bira trener od 18 naviše, funkcija je za premium i za kupljene kredite
(krediti kasnije, potrošnja se meri odmah), `deepseek-flash` sa
`reasoning_effort: low`, vrata i u Analizi i u arhivi partija, i jedno
automatsko pokretanje koje staje samo pre trošenja.

**Korak 1 je urađen:** `tools/game_annotate/export_fixtures.py` piše deset
fajlova u `chess_app/test/fixtures/game_tutorial/` — ulaze (činjenice, PGN,
parametre, odgovor modela) i ono što harness od njih pravi (momente sa tekstom i
činjenicama svakog slota, prompt, izveštaj, oba tutorijala). `--check` kaže da li
fajlovi i dalje odgovaraju `skeleton.py`; dokazan dvema mutacijama.

**Korak 3 je urađen:** `evaluation_words.dart` (`wordsFor`, `standing`) prenet i
držan uz harness na svakoj oceni deset partija i na graničnim slučajevima koje je
harness sam odgovorio; deset mutacija od deset uhvaćeno. Kapija za ostatak faze 1
je `docs/gates/game_tutorial_skeleton_test.dart` — zamrznut API, jedanaest mesta
gde se Python i Dart razilaze, pet loših odgovora modela. Jedino poređenje koje
nije bajt po bajt (`pgn` dela, čita se nazad kroz `LessonStepLine`) dokazano je
prolaznim unapred: svaki deo svakog fixture-a, prepisan kroz
`StudioLessonStep.from`, čita se nazad isto. Aplikacija **2368 testova** (1
preskočen), analyze 26 info. Sledeće: batch 1 za worker-a (ostatak skeleta prema
kapiji), pa faza 0 (`tool/game_facts.dart`).

**Batch 70 (Gemini) je prošao i spojen je, 14.9.2026 — faza 1 je gotova.** Ceo
skelet je u aplikaciji (`game_tutorial/skeleton_*.dart`, `board_queries.dart`):
od istih činjenica i istog odgovora modela pravi isto što harness. Sve kapije
zelene u prvom krugu; ocenjivanje je dodalo tri ispravke. Dve su pravila
zaokruživanja do kojih deset partija nikad ne stiže — Pythonov `round` samo na
tačnoj polovini i `'%.1f'` na tačnom izjednačenju (u zaglavlju kapije je pisalo
da se Dart i Python tu slažu, što je bila pretpostavka) — a treća je potez koji
ne može da se odigra, a nije bio prijavljen. `edge_cases.json` ih sada pokriva,
iz samog harnessa. Aplikacija **2412** (1 preskočen), analyze 26. Sledeće: faza 0
(`tool/game_facts.dart`) i faza 2, činjenice na uređaju.

## Isti nalaz posle poteza, i težina onoga što se može osvojiti — 13.9.2026, u kodu

Nastavak „Rečnika detektora motiva" odmah ispod, iz zadatka koji je taj unos
izdvojio. Provera uživo ide uz stavku 160 u `TODO-provera.md`.

**Identitet.** Nalaz iz pozicije pre poteza se poredi sa nalazima posle poteza
kao da je odigrana figura već stajala na odredišnom polju
(`finding_identity.dart`). Do sada je identitet bio skup polja, pa je dama koja
pređe sa jednog napadnutog polja na drugo bila „no longer hanging" na d1 i
ponovo viseća na d5, a kralj bez zaštite pešaka isto na svakom koraku. Prati se
samo figura iz poteza; top pri rokadi i pešak uzet en passant ne, pa za njih
nalaz i dalje izgleda završen pa započet — kao i pre, ne kao nova greška.
`PositionalEvaluatorService.explainMove` sada **traži** `lastMoveUci`
(`null` samo za dve pozicije koje nisu jedan potez), da pozivalac ne može da ga
zaboravi; šetač, generator stabla i četiri mesta u Analizi ga predaju.

**Težina.** `significance` je vrednost onoga što nalaz može da osvoji ili
košta, nikad figure koja napada: veza — vezana figura i ono iza nje osim kralja;
iskošenje — figura iza; viljuška i preopterećenost — ono što drže; otkriveni
napad — figura na koju je otkriven; odvlačenje — figura koja ostaje bez branioca.
Dama koja vezuje pešaka za kralja vredela je 1000, sada 1. `_Found.stake` je
obavezan parametar, da novi motiv mora da kaže šta mu je ulog.

**Dva testa su tvrdila šum.** Test 9 detektora i test 3 šetača su za Qd1-d5
tvrdili da je dama „tek" ostavljena da visi — a na otvorenoj d-liniji visila je
već na d1, i komentar testa je opisivao poziciju koju njegov FEN nema. Fiksture
su prebačene na Qh1-d5, gde je to istina; stari potez je sada test identiteta.

**Mereno:** aplikacija 2335 prolaza, 1 preskočen; analyze 26, sva
`curly_braces`; server nedirnut na 1260. 15 mutacija, sve uhvaćene testom kome
su namenjene. Jedna je prošla tek iz drugog pokušaja: njen isečak je u šetaču
postojao dvaput (taktički poziv je potez predavao i ranije), pa ga harness nije
primenio i tako je i rekao, umesto da izabere pogrešnu liniju.

**Pozivalac je dobio test pre mutacije koja bi ga otkrila.** Da šetač preda
`null` umesto poteza, sve bi ostalo zeleno — testovi identiteta zovu servis
direktno. Test 6 šetača (kralj hoda, komentar mora biti prazan) napisan je pre
pokretanja i uhvatio je baš tu mutaciju. Generator stabla i ekran Analize takav
test nemaju; obavezan parametar je njihova zaštita.

**Ulazi eksperimenta su ponovo regenerisani** (`REVIEW_COMMENTS_ONLY=1`, pa
`make_facts.py` na dubini 20): stablo, oznake i komentari u varijantama
identični; promenjeno je 8/53, 33/78 i 38/86 komentara glavne linije, tekst je
kraći za 21% (28.039 → 22.224 znaka). `_facts.json` su ponovo izgrađeni i
upoređeni sa prethodnim: svaki red je identičan van `motifs_after_played`
(kandidati, ocene, linije, „stands out"), a promenjeno je upravo 8, 33 i 38
redova motiva — isti broj kao komentara. Primeri: posle `10... Bxe2` nema više
„lovac na e2 nema branioca" pored „lovac na g4 više ne visi" — isti lovac je
visio i pre; posle `8... Kxf7` nema para „izgubio zaštitu / više nije bez nje",
jer je kralj bez nje bio i na e8.

---

## Rečnik detektora motiva — 13.9.2026, u kodu, ostaje provera uživo

Odeljak „ODAKLE SUTRA — čišćenje rečnika detektora motiva" niže je urađen, u
dva commita, sa odlukama vlasnika na četiri pitanja: „Watch out" se briše bez
zamene, „ | " postaje rečenica sa tačkom, B ide odmah posle A bez pauze za
pregled, i pravilo slabih polja je bilo naopako. Provera uživo:
`TODO-provera.md`, stavka 160.

**A — kako se kaže** (`finding_sentences.dart`). Svaki nalaz je jedna rečenica
i nosi drugu za trenutak kad prestane da važi (`goneDescription`) — „Resolved —
X" je ponavljao nešto što više nije tačno. Jedan nalaz po pojavi: dve vezane
figure su dva nalaza, a ne „Pin: a | b", koji dijalog za komentar nije mogao
ponovo da prepozna. Komentar su rečenice spojene razmakom, svuda gde se
spajalo (šetač, generator stabla, Analiza, dijalog, rezervni komentar na
serveru), a dijalog nalaz traži po rečenici. „Undefended" se kaže samo za
figuru bez branioca; branjena figura napadnuta jeftinijom kaže to.

**B — šta se broji.** Viljuška broji samo ono što može da osvoji; iskošenje
traži prednju figuru koja mora da se skloni i zadnju vrednu osvajanja; veza
traži da je iza nešto vrednije od figure koja vezuje ili nebranjeno; kralj nije
„branjena figura", pešak koji brani pešaka je lanac; slaba polja su ona boje
koju pešaci **ne** pokrivaju. Svaki „ne sme" test je pozicija iz jedne od tri
partije, i svaki je prvo pao na starom detektoru.

**Mereno:** aplikacija 2323 prolaza, 1 preskočen; server 1260 sa `.env`-om po
strani; analyze 26 infos, sva `curly_braces` (tri manje — prepis je dodao
zagrade). 32 mutacije, sve uhvaćene testom kome su namenjene.

Četiri stvari vredne pamćenja.

**Mutacija koja se ne kompajlira nije uhvaćena.** M14 je zamenila
`mate != null && …` sa `false`, čime je nestalo unapređenje tipa od kog
`mate.squares` zavisi; harness je video crveno i javio „caught". Izveštaj je
imao samo imena fajlova, bez imena testova — to je bio znak. Prepisana tako da
se kompajlira, pala je na testu 19b.

**Klauzula koja ne može ništa da odluči je obrisana pre mutacija, ne posle.**
„Kralj se uvek broji" stajalo je tri puta pored poređenja vrednosti, a kralj
vredi 1000 — više od svakog napadača. Nađeno čitanjem testova za mutaciju koja
bi preživela, što je jeftinije od preživele mutacije.

**Broj u CLAUDE.md je bio šest iza.** Pisalo je 2272, a HEAD pre ovog posla je
imao 2278: 2298 posle A minus 20 dodatih deklaracija, prebrojano na oba stabla.

**Ulazi eksperimenta su regenerisani, i to je provereno, ne pretpostavljeno.**
Tri `_reviewed.pgn` su prepisana kroz `REVIEW_COMMENTS_ONLY=1`
(`tool/review_game.dart`): samo komentari glavne linije, dok su potezi, `??`,
`!` linije i komentari u varijantama identični — jer oznake prve partije
potiču iz trenerovog pregleda u aplikaciji i novi pregled ih ne bi vratio.
`_facts.json` su ponovo izgrađeni sa podešavanjima koja su nosili: kandidati,
ocene, linije i sve „stands out" oznake identični; jedino drugo polje koje se
promenilo je `cost_pawns`, koje su stari fajlovi imali ispod nule jer su
stariji od `max(0, …)` u `make_facts.py`. Tekst motiva je kraći za 35%
(43.271 → 28.039 znakova), 634 prefiksa i crte → 0. **Pokretanja pre ovog
datuma čitaju stari rečnik** — poređenje preko te granice poredi dva rečnika.

**Viđeno, nije dirano:** nalaz je vezan za polje, pa dama koja pređe sa jednog
napadnutog polja na drugo dobija „d1 no longer hanging" pored „d5 … has no
defender"; isto važi za zaštitu kralja dok kralj hoda. `significance` računa i
figuru koja napada, pa veza damom vredi 9 i kad je vezan pešak. Urađeno isti
dan — vidi „Isti nalaz posle poteza" iznad.

---

## Gemini kao plaćeni API — odustalo, 13.9.2026

**Odluka vlasnika: „ne mogu da platim API."** Google Cloud odbija njihov
platni profil — *„You can't select this profile because the legal entity type
isn't supported for this product"* — što je **drugi put** da isti zid odlučuje
o dobavljaču: 9.9.2026. je zbog njega `google.js` (Google TTS) ostao napisan i
nedostupan, pa je uzet Azure Speech. Bez naplate nema ni Batch reda, dakle ni
one druge kolone iz cenovnika; ostaje besplatni nivo sa ~20 poziva dnevno,
što nije osnova za bilo šta u proizvodu.

**Šta odluka NE obuhvata.** `agy` (Antigravity CLI) i dalje radi i nije
naplata po tokenu — `tools/tutorial_translate/` prevodi kroz njega
(`gemini-3.8-flash-high`), i tu se ništa ne dira. Odustaje se od **Gemini API-ja
koji se plaća po tokenu**, ne od alata koji već radi.

**Šta odluka ne košta.** Isporučena funkcija (faze 1–4 ispod) ne zove nikakav
model: pitanje se pravi tamo gde je „Review entire game" već napisao `??` i
pored njega `!` liniju. Model je bio kandidat samo za *masovno* pisanje
tutorijala iz partija; to ostaje neurađeno, a ne pokvareno.

**Izmereno pre odustajanja** (`tools/game_annotate/`, grana B, partija 1, ista
API cev za sve): `gemini-3.5-flash` → CLEAN. Oba Lite modela koja nalog uopšte
može da dohvati padaju — `3.5-flash-lite` DAMAGED (16 poteza koji se ne mogu
odigrati; sa uključenim razmišljanjem 2), `3.1-flash-lite` REFUSED (nelegalno
rešenje i 22 poteza) i sa razmišljanjem i bez njega. `gemini-2.5-flash-lite`,
najjeftiniji red u cenovniku, nalog **uopšte ne može da dobije** („no longer
available to new users"). Cev je time opravdana: isti prompt kroz isti API sa
ne-Lite modelom daje CLEAN, dakle greši model.

**I cenovnik je merio pogrešnu stvar.** Te cene pretpostavljaju kratak odgovor:
jeftini pokušaji potrošili su **nula** tokena na razmišljanje, odgovorili za
četiri sekunde i pali. Oni koji su blizu prolaza potroše ~12.000 tokena
razmišljanja, što se naplaćuje kao izlaz — više nego model koji zadatak
rešava (9.640). Ušteda nestaje tačno tamo gde bi trebalo da postoji.

**Ako se masovno pisanje ikad vrati:** dobavljač čiju naplatu ovaj nalog može
da koristi je Azure (već se plaća za Speech), a to znači modele iz OpenAI
porodice. Alat je spreman za to — `run_api.py` prima `--model`, a ocenjivač,
motor i partije ne znaju ni za jednog dobavljača.

---

## ODAKLE SUTRA — 13.9.2026, izbor LLM dobavljača

**Cilj oko kog smo se složili**, da se ne bi ponovo otvarao: funkcija se na
kraju nudi korisniku **u aplikaciji**, preko backenda, sa ključem na serveru i
kontrolom (entitlement, merenje, red) — ali **pre** nego što se pipne backend
ili UI, dobavljač se proverava kroz `tools/game_annotate/`, isto onako kako je
provereno tri partije: ponašanje, format, kvalitet rezonovanja i potrošnja.
Vlasnikove lične partije su odvojen posao i mogu oflajn kroz `agy`.

**Šta model tu radi, a šta ne.** Komentare aplikacija već piše sama, lokalno i
besplatno („Review entire game" = detektor motiva + pozicioni procenjivač +
Stockfish). Model se kupuje za *pedagoški* deo: koja 4–10 trenutaka partije
vrede detetu i koje rečenice ono čuje. Zato je tok **grana B**, ne A:

> čist PGN → „Review entire game" (lokalno) → prokomentarisan PGN → model →
> tutorijal JSON → `readTutorialJson` → otvara se u studiju

Grana A (čist PGN pravo modelu) je merena i lošija u sve tri partije: pitanja
koja izgledaju ispravno a netačna su.

**Gde je stalo — DeepSeek je proveren i ne prolazi (13.9.2026).** Vlasnik je
dopunio nalog sa 5 USD; potrošeno oko 0,35 USD. Nalog nudi `deepseek-flash` i
`deepseek-v4-pro` (nema `deepseek-reasoner`). Od sedam pokretanja na tri
partije, merilo je prošlo **jedno**: pro na francuskoj partiji, sve pozicije
tačne, `d4` prvi izbor motora sa razlikom 0,49. Tabela i obrazloženje su u
`tools/game_annotate/README.md`, odeljak „DeepSeek, 13.9.2026".

Tri stvari iz toga vrede i bez tabele:

- **Razmišljanje se troši iz `max_tokens`.** Na 16k oba modela nisu napisala
  ništa; flash ni na 64k. Završava tek sa `--reasoning-effort low`, a bez
  razmišljanja (`--thinking-mode disabled`) je REFUSED, kao Gemini Lite.
- **Ne pada šah nego tabla.** Svaka pogrešna pozicija je prava pozicija partije
  sa jednim do tri pogrešna polja — izostao top na a1, pešak, dama, crni lovac
  upisan kao beli. Gde tabla preživi, pitanja su dobra. Otvoren predlog, ništa
  nije urađeno: da model **imenuje** potez („posle 15. Nd5"), a čitač sam
  sagradi FEN — onda model ne mora da odigra celu partiju u glavi.
- **Ocenjivač to nije mogao da vidi.** FEN bez topa se učitava i linija se
  odigrava, pa dobija CLEAN. Zato postoji `check_positions.py`: da li je svaka
  pozicija zaista iz partije (ili varijante pregleda), koja polja se razlikuju,
  i sa `--engine` gde je odgovor na `ask_move` kod motora i sa kolikom razlikom.

**Azure OpenAI i Qwen, isti dan — i kraj probe dobavljača.** Vlasnikovo
pravilo za ovaj krug: probaj Qwen, pa ako ne uspe, odustajemo. Nije uspeo
nijedan. `gpt-5.4-mini` (Azure, Data Zone EU — jedini model sa kvotom posle
nadogradnje probne pretplate) DAMAGED; `qwen3.8-flash` DAMAGED, svih deset
pozicija van partije; `qwen3.8-2.4t-a95b` REFUSED; `qwen3.8-max` bez odgovora,
stream zatvoren posle 899 s. Tabela i detalji kanala (Azure kvote, Qwen koji bez
streama ne odgovara) su u `tools/game_annotate/README.md`.

**Svaki neuspeh u celoj probi je isti neuspeh: izgubljena tabla**, ne loš izbor
ni loše rezonovanje. Zato **sledeći korak nije dobavljač nego ugovor — grana D**:
modelu se daju samo momenti partije (gde je pregled napisao `??`), sa FEN-om koji
izračunamo mi, potezom koji je odigran, boljim potezom i — posle vlasnikove
odluke gore — kandidatima sa ocenom motora; model bira koje momente i piše
rečenice, a poziciju samo imenuje. Nije izgrađeno.

**Uz to, jedna greška u samom eksperimentu:** ulaz za prvu partiju je nosio
vlasnikova pitanja posle partije (`make_inputs.py` je tražio rezultat u zasebnom
redu), u svim promptovima grane B za tu partiju, Gemini uključen. Ulaz je
ponovo napravljen, a skripta sada odbija partiju koja se ne završava rezultatom.

**I jedna greška u aplikaciji nađena usput, popravljena:** `MoveTree.cleanPgnComment`
je iz komentara skidao samo `[%cal]` i `[%csl]`, pa je partija sa Chess.com-a
uvezena kao tutorijal detetu naglas čitala `[%clk 0:02:59.9]` posle svakog
poteza. Sada skida svaku PGN komandu; šest testova u `pgn_dialect_test.dart`,
pet mutacija uhvaćeno; 2278 testova, 1 preskočen, analyze 29 infos.

**Isti dan, posle probe dobavljača: pronađen put koji radi — skelet (grana H).**
Vlasnikova postavka: model ne sme da procenjuje poteze. Python i Stockfish
(`make_facts.py`, dubina 20, jednom po partiji) prave ceo tutorijal: kandidat
momente gde je odigrani potez koštao ≥ 1,0 pešak, delove, FEN-ove, linije i
pitanja (tačni su svi potezi u krugu od 0,3; bez pitanja ako ih je više od 3).
Model samo bira 2–3 ponuđena momenta i popunjava prazna tekstualna polja, svako
sa činjenicama pored sebe (`skeleton.py`). Pragovi se primenjuju pri pravljenju
skeleta, ne pri analizi — već analizirane partije se ne šalju ponovo.

Rezultat, 15 pokretanja na tri partije i pet modela: **14 CLEAN, sve pozicije
tačne, svako pitanje prvi izbor Stockfish-a**; `deepseek-flash` 24–38 s po
partiji, oko 10 hiljada tokena, rečenice pročitane i uglavnom tačne;
`gpt-5.4-mini`, `qwen3.7-max`, `gemini-3.8-flash-high` i `gemini-3.1-pro-high`
takođe prolaze; `qwen3.8-flash` je pokvario sopstveni JSON. Preostaje istina
rečenica — provera tvrdnji hvata rečenicu na pogrešnom potezu i „pin"/„fork"/
„mate" koje činjenice ne pokazuju — i **rečnik detektora motiva** u aplikaciji,
koji model verno ponavlja („Skewer: … knight … exposing the pawn", „Fork" koji
broji pešake, „Resolved —"). Tabele i sve pouke: `tools/game_annotate/README.md`,
odeljak „Arms F, G and H".

**Sledeći korak je odluka vlasnika, ne dobavljač:** da li se skelet prenosi u
aplikaciju/backend (analiza lokalno ili na serveru, model samo za reči), i da li
se prvo čisti rečnik detektora motiva. Jedna pouka ide uz to: jedna pretraga
Stockfish-a blizu praga nije presuda (`Ke3` je na dubini 22 sa četiri linije
izgledao drugi, a na dubini 26 vodi 0,44), pa granično pitanje mora da potvrdi
dublja ili ponovljena pretraga.

**Odluke vlasnika, 13.9.2026, uveče:** (1) LLM se koristi **samo za reči**;
**analiza je lokalna, na korisnikovom uređaju** — skelet (momenti, pozicije,
linije, pitanja) pravi aplikacija, ne server. (2) **Prvo se čisti rečnik
detektora motiva**, pa tek onda prenos skeleta u aplikaciju. (3) Publika je
**13+** (u nekim državama više), ne deca — promptovi u `tools/game_annotate/` i
`CLAUDE.md` su ispravljeni.

**Odluka (2) je izvršena iste noći** — „Rečnik detektora motiva" i „Isti nalaz
posle poteza" na vrhu. Ulazi sve tri partije su regenerisani, pa **svaki raniji
rezultat grana B–H čita stari rečnik**. Odavde se nastavlja testiranje modela:
ponovo pokrenuti granu H (prvo `deepseek-flash`, pa jedan Gemini) na novim
ulazima, istim merilom (ocenjivač, `check_positions.py --engine`,
`review_run.py`), i pročitati da li su rečenice postale tačnije — to je pitanje
zbog kog je rečnik čišćen. Tek posle toga prenos skeleta u aplikaciju.

## ODAKLE SUTRA — čišćenje rečnika detektora motiva

**Urađeno 13.9.2026** — vidi „Rečnik detektora motiva" na vrhu. Ono ispod o
oceni u PGN-u i o merilu i dalje važi.

Zašto: skelet je pokazao da model **doslovno ponavlja** ono što detektor napiše,
pa kvalitet rečenica ne može biti bolji od rečnika detektora. Primeri iz
činjenica partije `pvladan_2026-09-12` (`tools/game_annotate/input/
pvladan_2026-09-12_facts.json`, polje `motifs_after_played`), koje su četiri
različita modela prenela u tutorijal:

- **„Skewer" na slabim figurama:** „Skewer: the white knight on d5 has to move,
  exposing the white pawn on e4", „Skewer: the black rook on e7 has to move,
  exposing the black pawn on f7". Geometrijski tačno, ali skewer iza kojeg stoji
  pešak nije pouka.
- **„Fork" koji broji pešake:** „Fork: the white queen on d5 attacks five black
  pieces: the black rook on a8, the black pawn on c5, the black rook on d7, the
  black pawn on e5 and the black pawn on f7".
- **Mašinski prefiksi kao reči:** „Resolved — …" i „Watch out — …" su promene
  stanja, ne rečenice; jedan model je napisao „The skewer on c6 is resolved".

Gde: `chess_app/lib/core/services/tactical_motif_detector.dart`,
`positional_evaluator_service.dart`, i spajanje u
`game_analysis_walker_service.dart` (`combinedComment`). Pre izmene pogledati ko
sve čita te tekstove (komentari „Review entire game" u PGN-u, paneli nalaza,
`reportService.js` na backendu drži kopiju tabele motiva — vidi CLAUDE.md o
engleskom rečniku), jer promena naziva menja i što vide treneri i testovi.
Pravila rada iz CLAUDE.md važe: testovi prvo, mutacije, `flutter analyze` na 29
infos.

**Odluka vlasnika, 13.9.2026 — evaluacija u PGN, ne u stablo.** Sužava odluku
od 4.9.2026: ocena motora i dalje **ne ulazi u grafičko stablo poteza** (nema
broja na kartici, nema polja na `AnalysisNode`), ali **sme da ide u PGN**. Povod:
„Review entire game" bi davao više boljih poteza sa ocenom, pa se pitanje pravi
samo gde je najbolji potez jasno najbolji, a jednako dobri idu u `acceptedSans`.
Implementacija od 4.9. je uklonila i `[%eval]` iz izvoza, pa je PGN deo sada
dozvoljen, ne vraćen. Uslov koji ide uz to: tutorijal uvezen iz PGN-a čita
komentare detetu naglas, pa ocena upisana u komentar ne sme da stigne do glasa.
Prvo se dokazuje u `tools/game_annotate/` (grana D, momenti umesto cele
partije), pa tek onda plan za aplikaciju.

**Merilo je već postavljeno i ne izmišlja se ponovo**: ocenjivač mora reći
CLEAN (`cd chess_app && dart run tool/grade_tutorial.dart <folder>`),
`python check_positions.py <folder> --engine` ne sme naći poziciju koje nema u
partiji, a svako `ask_move` mora biti prvi izbor motora (dubina 22, multipv 4)
sa jasnom razlikom. Tako su prošli i Gemini modeli, pa su brojevi uporedivi.

**Jedna šteta iz te sesije, da se ne traži uzalud:** tri `out/B-…` foldera
(grana B, sve tri partije, `gemini-3.8-flash-high`) obrisana su nepažljivim
`rm -rf` sa džokerom. Nalazi su zapisani u `tools/game_annotate/README.md`;
sami tutorijali nisu, i vraćaju se ponovnim pokretanjem
(`python run_arm.py B --name <partija>`), oko dvanaest minuta za sve tri.

---

## PGN u tutorijal i natrag — `PLAN-PGN-TUTORIJAL.md`, sve četiri faze, 12–13.9.2026

Tačke 1, 2 i 4 iz fajla sa pitanjima vlasnika od 12.9.2026. Nije viđeno
uživo: `TODO-provera.md`, stavke 157 (fajl iz Analize), 158 (uvoz) i 159
(izvoz).

**Pre koda je išao eksperiment**, `tools/game_annotate/`: tri partije, devet
prolaza, svaki `ask_move` proveren Stockfish-om na dubini 22. Grana koja je
dobila izlaz „Review entire game" svaki put je pitala pitanje čiji je odgovor
engine-ov prvi izbor sa jasnom razlikom; grana koja je dobila samo poteze nije
nijednom — pisala je pitanja koja izgledaju ispravno i suptilno su netačna
(„jedini odbrambeni potez", odgovor treći po redu). Zato se pitanja prave samo
tamo gde je pregled već ostavio `??` **i** `!` liniju pored njega.

Šta je napravljeno:

 * **Faza 0** — `??` i `!` se konačno i čitaju natrag. Do 12.9.2026. su se
   gubile pri prvom ponovnom snimanju tutorijala, tiho.
 * **Faza 1** — `.pgn` postaje tutorijal: jedna partija, jedan deo; naslov iz
   zaglavlja; ništa se ne parsira po drugi put.
 * **Faza 2** — pitanja na oznakama, sečena istim `splitForQuestion` koji
   trener koristi ručno. Odgovor je engine-ov potez, nastavak prati partiju.
   Rečenica pitanja **ne tvrdi da je odgovor jedini** — pregledani PGN ne nosi
   nijednu ocenu, pa se to iz fajla ne može znati.
 * **Faza 3** — vrata: `.pgn` pored `.json` u „Uvezi iz fajla", najviše 50
   partija po fajlu i to piše na prvom redu.
 * **Faza 4** — natrag: susedni delovi se spajaju u jednu partiju kad drugi
   stoji na poziciji na kojoj se prvi završio, a prekid počinje novu partiju u
   istom fajlu. Izlazi kroz „Save as .pgn", sada dugme i u studiju.

**Šta PGN ne nosi, i to dijalog kaže pre nego što se fajl imenuje**: šta deo
pita, odgovor, primljeni potezi, orijentacija table, naslov tutorijala, oznake i
jezik. Rečenica ne šalje trenera na druga vrata — izvoza u JSON u aplikaciji
nema — nego kaže da sve to ostaje u sačuvanom tutorijalu.

---

## Ispis prati glas, a ne fajl — 12.9.2026

Dve prijave posle gledanja prvog objavljenog tutorijala: prva reč se ne čuje
cela („Checkmating" počinje od „mating"), i „govor ide brže od ispisa teksta, pa
posle govora čekamo da se tekst ispiše, nekad i po 2 sekunde, pa tek onda ide
dalje". **1258 na serveru** sa `.env`-om po strani; aplikacija je netaknuta.
Trinaest mutacija, sve uhvaćene. Provera uživo: `TODO-provera.md`, stavka 156.

**Prvo mereno, pa menjano.** Svaka Azure snimka nosi tišinu oko rečenice, i to
je izmereno na svih 22 klipa tog filma: **0,12–0,14 s ispred i 0,80–0,93 s
iza** — 18,6 sekundi od 175 koliko film traje. A sve se ravnalo po **dužini
fajla**, ne po glasu u njemu:

* natpis se ispisivao preko celog klipa, pa je počinjao pre prve reči i još se
  pisao posle poslednje — to je „govor ide brže od ispisa";
* pauza (`BREATH_SECONDS`, 0,6 s) se dodavala na **kraj fajla**, pa je čekanje
  posle glasa bilo rep klipa *plus* pauza *plus* zaokruživanje na celu sekundu —
  tačno one dve sekunde koje je vlasnik izmerio.

**Prva reč nije bila odsečena.** Mereno pre nego što je bilo šta dirano: prvih
0,129 s filma i istih 0,129 s klipa daju identično očitavanje, do decibela
(−66,2 prema −66,6 dB srednje). Zvuk je bio ceo — reč počinje na 0,129 s, bez
ikakvog mesta pre sebe, a to je mesto koje plejer ume da pojede. Zato je dodat
**uvod od 0,4 s pred prvi klip** (`LEAD_SECONDS`), i to je prostor a ne
popravka; tako i stoji zapisano u kodu, jer bi drugačije neko sutra tražio
odsečene semplove kojih nema.

Četiri izmene, sve na serveru:

1. **`speechWindow`** (`services/tts/wav.js`) čita gde je glas unutar wav-a —
   vrh po bloku od 20 ms, prag −40 dBFS. Ne traži prvi sempl različit od nule:
   tiši deo klipa nije digitalna tišina (−50 dB u vrhu), pa bi takav skan za
   svaki klip odgovorio „od nule".
2. **Pauza se meri od glasa**, ne od kraja fajla. Rep klipa je obično duži od
   pauze, pa je sam sebi pauza; takt je `max(klip, kraj glasa + pauza)`.
3. **Takt se zaokružuje na kadar, ne na celu sekundu.** Ruta prosleđuje `fps`
   (`framesPerSecondOf`) do plana: sa natpisima film se crta četiri puta u
   sekundi, pa zaokruživanje košta najviše četvrt sekunde umesto cele. Bez
   natpisa je i dalje cela sekunda, jer se tada crta jednom u sekundi.
4. **`captionRevealAt`** je pravilo ispisa, izvučeno kao vrednost koju test
   može da pročita (kao `underBoardText` i `ffmpegArgsFor`): ispis počinje kad
   glas počne i završava se kad glas stane. Nemi film je nedirnut — nema šta da
   prati, pa piše preko tri četvrtine takta.

**Koliko to vredi, mereno na vlasnikovim klipovima:** sam govor je 115,8 s;
film je po starom pravilu 168 s, po novom **146,75 s** — kraći za 21 sekundu,
oko 13%. Mrtvo vreme posle glasa padne sa ~1,45 s na ~0,9 s po taktu, i to je
rep klipa, dakle prava pauza.

Dve mutacije koje su vredele koliko i kod. „`speakBeats` zaboravi da izmeri
prozor" i „ruta ne prosledi `fps`" — obe bi ostavile sve gore dokazano i
ništa uključeno; to je isto ono „proved function is not a proved caller" koje
ovaj fajl već pamti iz plana snimanja. Obe su sada pokrivene, jedna testom sa
klipom podmetnutim u keš (bez ijednog poziva sintetizatoru), druga tvrdnjom u
testu rute.

---

## Oznake van table, i kartice koje ne beže — 12.9.2026

Dve stvari iz vlasnikovog gledanja uživo istog dana. **2173 u aplikaciji, 1
preskočen, i 1245 na serveru** sa `.env`-om po strani, mereno jedno posle
drugog bez ičega drugog u pogonu; analyze na 29 infova, nula upozorenja. Tri
mutacije, sve uhvaćene. Provera uživo: `TODO-provera.md`, stavka 155.

**Oznake kolona i redova su izašle iz table.** „U videu su unutar table, a u
studiju su spolja" — sa tri slike, film i studio jedan pored drugog. Sada su u
pojasu oko table, kao u aplikaciji (`BoardWithCoordinates`), i **pojas se
odbija od okvira table a ne dodaje na njega**: naslov, sat i kolona sa
rečenicom stoje tačno gde su stajali, a kad su oznake ugašene tabla uzme ceo
okvir natrag — ista računica koju taj vidžet pravi iz istog razloga. Pojas se
skalira sa slovima (`fontSizeCoord * 1.7`), pa na 720p izađe 20 piksela, što je
tačno širina na koju je aplikacijin pojas ograničen.

**Crtanje po poljima je ovom projektu koštalo dva odvojena buga**: godinu dana
nijedno slovo kolone nije bilo nacrtano (svako u boji polja na kom stoji), a
popravka tog dana je preselila grešku na brojeve redova, pa su oni bili
nevidljivi dva dana. Donji red i leva kolona počinju na suprotnim bojama, i
jedna ručno napisana parnost ne može da služi oboma. **Van table postoji jedna
pozadina i nema parnosti koja može da se pogreši.**

Testovi su prepisani, i treći je dodat: dva pitaju da li u pojasu ima mastila
na mestu svake oznake, a treći da **na poljima nema ničega osim njihove
boje** — što prva dva ne umeju da kažu sama (našla bi svoje mastilo u pojasu i
kad bi se crtalo na oba mesta). Tabla je od ovoga manja za pojas (31 piksel na
1080p, 20 na 720p), a izvoz snimljenog časa se menja isto — namerno, jer je
zahtev o slikama a ne o jednom izvozu.

**„Flow", „Tree" i „PGN" više ne beže sa ekrana.** Iz prijave: „Flow, tree i
pgn kartice ne treba da se skrivaju prilikom skrolovanja, tj. skrolovanje ne
sme na njih da utiče. Skroluje se samo ono ispod njih." Na širokom prozoru
traka sada stoji **izvan** svog skrol-prozora, a `_editorFields` je razdvojen u
`_editorTabs` i `_editorPanels`. Na uskom su tabla i spisak delova iznad nje u
istom skrolu, pa je traka **prikačen sliver** (`_PinnedEditorTabs`): dohvati
gornju ivicu i tu stane, a kartice prolaze ispod nje.

Tri stvari koje su se pokazale u radu. **Prikačen sliver se ne pravi dok ne
dođe do ekrana**, pa na uskom prozoru traka nije prikačena iznad sadržaja koji
je pre nje — ne može da bude, i to je tačno ono što je traženo („skroluje se
samo ono ispod njih"). **Tabla uzima potez prsta za sebe** — ona je tabla, i
vučenje po njoj je figura koja se pomera — pa na uskom prozoru, gde tabla
pokriva ceo vidokrug, test vozi `ScrollPosition.jumpTo` umesto pokreta; to je i
odgovor zašto se ovde ne skroluje prevlačenjem preko table. I **`Color` je u
ovom fajlu dvosmislen**: `flutter_chess_board` re-eksportuje šahovski paket,
koji ima svoj `Color`, pa polje tog tipa ne prolazi analizu — pozadinu boji
pozivalac, a delegat nosi samo vidžet.

Jedna stvar nađena u prolazu i **nije** dirana: u širokoj grani, na prozoru
visokom 640, `TutorialSectionsPanel` prelije 58 piksela. Gornja polovina panela
ničim nije menjana ovim radom (flex 2 od iste visine), pa je to starije od
ovoga; na 800 nema prelivanja. Ako se pojavi uživo, to je svoj zadatak.

---

## Vraćanje na već viđenu poziciju — 12.9.2026

`docs/PLAN-VRACANJE-NA-POZICIJU.md`, iz vlasnikovog zahteva posle prvog
objavljenog tutorijala: „Vraćanje na zajedničku poziciju treba da bude takvo da
gledalac zna da sam se vratio na već viđenu poziciju." **2171 u aplikaciji, 1
preskočen, i 1244 na serveru** sa `.env`-om po strani, mereno jedno posle
drugog bez ičega drugog u pogonu; analyze na 29 infova, nula upozorenja.
Osam mutacija, sve uhvaćene. Provera uživo: `TODO-provera.md`, stavka 154.

**Tri odgovora, ne dva, i to je cela stvar.** Izmereno na objavljenom
tutorijalu, ne pretpostavljeno: deo 2 se otvara na poziciji posle `2. Kf3`, gde
je deo 1 stao, i deo 3 na poziciji posle `12. Rh7`, gde je stao deo 2 — oba
**nastavljaju**, tabla se ne pomera, i rečenica „vraćamo se na…" bila bi tekst
preko slike koja se nije promenila. Samo deo 4 se vraća. Pravilo koje ih
razlikuje je mehaničko — je li to pozicija prethodnog takta, neka ranija, ili
nijedna — i poredi se kroz `MoveTree.samePosition`, koje **već postoji** i koje
dečji ekran već koristi za nastavak; drugo čitanje „iste pozicije" je način da
se dva ekrana raziđu oko jednog tutorijala.

**Red koji to nosi je postojao i bio je potrošen uludo.** Ispod table film piše
„Last move: 12. Rh7", a „Starting position" kad poteza nema — i na **svakoj**
granici dela je pisalo „Starting position", što je u tom tutorijalu bilo
netačno tri puta: dva puta deo nastavlja, jednom se vraća. Sada piše i „Back to
the position after 12. Rh7", a kad pozicija nikad nije bila ničija posledica
nego samo početak nekog dela — „Back to a position already shown".

**Tekst, nikad boja ni blesak.** Vlasnik ne razlikuje boje, a znak koji se mora
videti kao nijansa nije znak; ovo je i jedini signal koji preživi gledanje
filma na telefonu.

Dve posledice koje nisu bile traženo, a jesu popravka. **Nastavak više ne gasi
poslednji potez**: `applyEvent` ga je brisao na svakom `init`-u, što je tačno za
skok a netačno za spoj, gde je taj potez upravo ono čime se do te table došlo —
komentar iznad tog reda je tvrdio opšti slučaj i bio je stariji od delova koji
se spajaju. I **takt koji se vraća stoji najmanje četiri sekunde**: nota ima oko
35 slova, film se čita na 12 slova u sekundi, a dve sekunde koliko dobije takt
bez teksta nisu dovoljne da se primeti da je tabla otišla nazad. Tiče se samo
nemih filmova — `narrationPlan` svakom taktu meri dužinu po glasu.

**`filmSignatureOf` o ovome ne zna ništa, namerno.** Snimljena naracija nosi
potpis liste taktova nad kojom je snimljena, a potpis je pozicija plus rečenica.
Spoj nije ni jedno ni drugo: menja ono što je *ispisano pod* taktom, a ne koji
je takt ni koliko se nad njim govori. Da je ušao u potpis, svaka do sada
snimljena naracija bila bi nevažeća — zbog natpisa koji trenerov glas nikad ne
čita.

**Odsutan `join` znači `fresh`.** Izvoz snimljenog časa šalje jedan `init` bez
ikakvog spoja, kao i svaki nacrt napisan pre ovog dana, i mora da nastavi da
crta tačno ono što je crtao. Test ide kroz oba oblika.

**Zašto je `underBoardText` funkcija a ne red unutar crtanja.** Tekst na
kanvasu se ne može pročitati iz piksela: i kadar takta koji se vraća i kadar
svežeg dela imaju mastilo ispod table, pa bi test koji gleda sliku umeo da kaže
samo da tamo nešto piše. Isti razlog zbog kog je `ffmpegArgsFor` izvučen.

**Dečji ekran (P2) nije rađen**, i to je pitanje obima a ne teškoće: zahtev je o
filmu. Ekran već ima polovinu pravila (`_nextStepContinuesHere`, koje čeka takt
pre table koju će prerasporediti); nema treći odgovor ni red na kom bi ga
nacrtao, i kad dođe mora da pozove `partOpeningsOf` a ne da prepiše pravilo —
pri čemu ume da imenuje samo deo, ne potez, jer parsira jednu liniju u
trenutku.

---

## 60 fps za YouTube — mereno i odbijeno, 12.9.2026

Pitanje vlasnika: da li se render može podići na 60 fps, jer YouTube „forsira"
60. **Ništa nije promenjeno u kodu** — `OUTPUT_FPS` ostaje 30. Ovde stoji
merenje, da se pitanje ne otvara ponovo.

**Dva različita broja, a samo jedan je bio u igri.** `OUTPUT_FPS = 30`
(`videoRenderer.js`) je ono što fajl *tvrdi*; `CAPTION_FPS = 4` (jedan kad se
ništa ne govori) je ono što se zaista crta. Između dva takta se na tabli ne
menja ništa, pa bi 60 *crtanja* u sekundi bilo oko 56 identičnih slika po
sekundi, a budžet (`renderBudget.js`) bi sa dozvoljenih 30 minuta filma na 720p
pao na 2 (na 1080p na 1), i najduža snimljena naracija sa njim — ona se iz istog
računa izvodi (`narrationUpload.js`). To nije ni razmatrano dalje. Mereno je
samo prvo: isti film, isti nacrtani kadrovi, promenjen jedino `-r` na izlazu.

**Cena, mereno pravim renderom na razvojnoj mašini** (30 i 60 naizmenično, da
drift mašine padne na oba jednako):

| film | 30 fps | 60 fps |
|---|---|---|
| 1080p, 180 s | 2,44 MB; 67,7 / 67,6 s | 3,65 MB; 87,5 / 88,6 s |
| 1080p, 64 s | 859 KB; 24,6 / 24,4 / 24,5 s | 1288 KB; 32,1 / 31,1 / 33,1 s |
| 720p, 64 s | 596 KB | 896 KB |

Veličina: **+50% u svakom merenju** (50,3 / 49,9 / 49,7%) — duplirani kadar nije
besplatan, nosi zaglavlje P-kadra i bez ikakve razlike u slici. Vreme: **oko
+30% na 1080p**; par od 180 s je merodavan (oba merenja na 30 se slažu na 0,1%,
oba na 60 na 1%), dok su merenja od 64 s bučnija — jedan kasniji prolaz na 60 je
ispao izjednačen sa 30. Sam film je ispravan: 180,27 s prema 180,25 s, tačno
dvostruko kadrova, `r_frame_rate=60/1`.

**A YouTube za to ne daje ništa.** Oba filma su postavljena privatno i `yt-dlp
-F` je pročitao obe lestvice:

| tok | 30 fps | 60 fps |
|---|---|---|
| 1080p DASH | 154k | 162k |
| 720p DASH | 102k | 95k |
| 1080p HLS | 350k | 330k |
| 720p HLS | 277k | 258k |
| 360p H.264 | 48k | 42k |

Dva od pet su *niža*. Jedino što 60 fps kupuje je natpis „1080p60" u meniju
kvaliteta. Uz to dva nalaza koja ruše pretpostavku ispod pitanja: YouTube-ov
1080p izlaz nosi **više** bitova (154k) nego naš izvor (97k), dakle ne
izgladnjuje ni tekst ni tanke konture — a 50% više bajtova koje smo poslali je
odbacio i dao isti izlaz. I to plaća gledalac: 11 ispuštenih kadrova od 2741 na
60 fps, prema 0 od 1274 na 30, za slike koje se menjaju četiri puta u sekundi.

Provereno i da enkoder nije usko grlo, pošto film izlazi na svega ~100–160 kbps:
`-crf 18` umesto podrazumevanog 23 daje samo 23% veći fajl, a PSNR između dva
enkodiranja je 50 dB. Ravna boja i tanke linije prosto ne traže bitove — CRF
nije ručica.

**Kada ovo prestaje da važi:** onog dana kada nešto u filmu *krene* — figura
koja se pomera preko polja, strelica koja se iscrtava. Tada kadrovi između dva
takta nisu kopije, imaju šta da nose, i tek tada visok broj nešto znači; to je i
komentar koji već stoji nad `OUTPUT_FPS`. Do tada se plaća tri puta — fajl, slot
za render, i dekodiranje kod gledaoca — za jedan natpis.

---

## Oznake na tabli — plan i sve faze, 12.9.2026

`docs/PLAN-OZNAKE-NA-TABLI.md`. Iz četiri vlasnikove prijave od 12.9.2026;
dve su o istoj stvari.

**Faza 0 je gotova, 12.9.2026 — 2102 u aplikaciji, 1 preskočen, analyze 29
infova i nula upozorenja**, mereno na `master` bez ičega drugog u pogonu.
Osnova pre rada je bila **2095**, dakle svih sedam novih su kapija ove faze
(`test/last_move_layer_test.dart`); sedam mutacija, sve uhvaćene. Broj u
CLAUDE.md je govorio 2079 dok je svita bila 2095 — zastareo, pa je izveden
ponovo umesto da se ponovi. **Ostalo (faze 1–4) još nije u kodu.**

**Faza 1 je gotova istog dana — 2098, 1 preskočen, analyze 29 infova.** Marker
iznad figura (žuti pojas, okvir i uglovne zagrade) je obrisan; `ChessBoardPainter`
više ne zna za poslednji potez. Četiri pozivaoca sada prosleđuju dva polja
`SkinnedChessBoard`-u. Prsten `[%csl]` je netaknut — on se menja u fazi 3.

Računica od 2102: −6 (`last_move_marker_test.dart` ceo), −3 (grupa u
`board_skin_contrast_test.dart`), +2 (nova grupa o sloju), +1 (test da boja ne
curi na susedno polje), +2 (nova kapija) = **2098**.

**Dve mutacije su preživele u prvom krugu**, i one su nalaz: brisanje
prosleđivanja u analizi i u ekranu za vežbe nije oborilo ništa. Nijedan od ta
dva ekrana se ne gradi ni u jednom widget testu, a oba zaobilaze
`ChessBoardWithOverlay`, pa ih ni faza 2 neće pokriti. `test/
last_move_reaches_board_test.dart` sada traži: **ekran koji vodi računa o
`_lastMoveFrom` mora da ga da tabli.** Čita se brojanjem zagrada, ne sečenjem.

Usput: `replay_player_screen.dart` je prosleđivao `lastMoveColor` a nijedno
polje, dakle nikada nije ni crtao poslednji potez. I dalje ne crta; faza 2
odlučuje da li treba.

Najgori kontrast opranog polja prema istom neopranom je **1.46:1** (High
Contrast, tamno polje) — prema 1.03:1 koliko je bio žuti.

**Faza 2 je gotova istog dana — 2127, 1 preskočen, analyze 29 infova.** Tabla
sama zaključuje koji je poslednji potez, pa ekran ne mora da je obavesti. Od
2098: +6 kapija izvođenja, +19 čisto jezgro faze 2b, +4 testa koje je 2b
dodala. Dvadeset mutacija u tri kruga, sve uhvaćene. **Ostaju faze 3 i 4.**

**Faza je morala da se radi dvaput, i drugi put je ono što se pamti.** Prvo
izvođenje je čitalo potez iz `game.history` — tačno, i **bez efekta na devet od
deset ekrana** zbog kojih je i pisano: svi oni voze tablu preko `loadFen`, a
`loadFen` briše istoriju. Taktika, odakle je prijava i došla, odigra potez na
svom `chess.Chess` pa pozove `loadFen(game.fen)`. Izmereno, ne pretpostavljeno:
posle prevlačenja istorija ima `e2e4`, posle te jedne linije nema ništa.

Kapija to nije uhvatila jer je njen fixture koristio `makeMove`, a ekrani
koriste `loadFen` — **fixture koji ne liči na ono što se testira**, što je u
CLAUDE.md već dvaput zapisano.

Rešenje je `lib/core/services/move_between_positions.dart`: za dve pozicije
pita **koji jedan legalan potez vodi od jedne do druge**, tako što generiše
poteze i proba ih. Ne poredi polja: rokada pomera dve figure, en passant prazni
polje na koje niko nije došao, promocija menja šta figura jeste — to su četiri
posebna slučaja koje `chess.dart` već zna.

**`chess.Chess.fromFEN` ne baca izuzetak — vraća praznu tablu.** Za `''`, `'not
a fen'`, `'////////'`, četiri reda ili red od devet pešaka vraća tablu bez
figura i ne kaže ništa. Zato je `try`/`catch` bio mrtav kod, a ni stražar koji
je izgledao bitno nije mogao da padne: prazna tabla nema kralja, ne generiše
poteze, pa već odgovara null. Dva stražara obrisana, osobina na koju se
oslanjaju je zakucana testom.

Usput: `SkinnedChessBoard` je sada `StatefulWidget` (pamti poziciju koju je
poslednju nacrtao), a reprodukcija snimka i dijalog sa linijama motora sada
crtaju potez — što je promena koju niko nije tražio i koja je ispravna.

**Faza 3 je gotova istog dana — 2129 u aplikaciji i 1238 na serveru** (sa
sklonjenim `.env`), analyze 29 infova. Prsten `[%csl]` je sada tanak okvir po
obodu polja — u aplikaciji i u filmu, istog dana, jer pravilo na dva mesta su
dva pravila. Širine 0.055 / 0.075 / 0.105 strane polja, autorova boja spolja,
bela pa crna unutra; to su brojevi sa `probe_trainer_frames.png`. Renderer je
dobio i boju poslednjeg poteza iz aplikacije — do sada je imao svoju žutu.
Osam mutacija na oba kraja, sve uhvaćene. **Ostaje faza 4.**

`chess_backend/test/square_mark_frame.test.js` čita tri razlomka i boju **iz
Dart izvora** i traži da su serverove konstante iste. Traži jednu po jednu
imenovanu konstantu i pada glasno ako je ne nađe — ne skenira oblast i ne veruje
njenom obliku.

**Tri testa su prestala da budu o bilo čemu.** „Prsten ostaje unutar svog
polja" je prepisivao formulu poluprečnika, pa je kad je koda nestalo nastavio
da se slaže sam sa sobom; tri testa u `video_renderer.test.js` su nosila po
kopiju iste formule, zato su sva tri pala zajedno pokazujući na broj koji je
obrisan. A **sam oblik nije imao test**: oznake su proveravane po boji i po tome
da stižu do slikara, što prsten i okvir prolaze isto. Sada se pita platno — ni
jedan `drawCircle`, tačno tri `drawRect`, svaki potez a nikad ispuna — a na
strani filma se pita da li **ugao** polja nosi mastilo, što prsten ne može da
prođe.

Ništa sačuvano se nije promenilo: `SquareMark` je polje i slovo boje, ni PGN ni
baza nikada nisu znali kojim se oblikom crta. Zato **svi već napisani tutorijali
od sada prikazuju okvire** — u studiju, u đakovom pregledu i u filmu; vredi da
vlasnik pogleda jedan koji je pisao ranije (deo C provere).

**Faza 4 je gotova istog dana — 2164 u aplikaciji, 1 preskočen, analyze 29
infova; server netaknut na 1238. Ceo plan je time u kodu; ostaje provera
uživo (`TODO-provera.md`, stavka 153, delovi A–D).** Obeležavanje niza polja:
`squaresBetween` je pravilo, `tap` je dobio `asRange`, a dugme „Line" stoji u
traci pored „Arrow" i „Square". Sedamnaest mutacija, sve uhvaćene.

a2→c7 nije linija i obeležava samo polje na koje je upravo kliknuto. Niz
**postavlja** umesto da prebacuje svako polje (inače bi preko poluobeležene
linije ispao šah-tabla), a ponovljen isti niz ga briše — u oba smera i bez
obzira na boju kojom je crtan. **Dugme, a ne samo SHIFT**, jer telefon nema
modifikator: ekran šalje `asRange: rangeMode || shiftHeld`, dakle jedan put kroz
kod, a SHIFT je prečica za isti taj put.

**Četiri mutacije su preživele, i to je bila ista rupa kao u fazi 1.** Pravilo
je imalo 24 testa, a povezivanje sa ekranom nijedan — isto kao kad su analiza i
ekran za vežbe tiho prestali da prosleđuju potez. `tutorial_oznake_test.dart`
sada vozi ekran i čita zahtev, uključujući i **kontrolni** slučaj: dva klika bez
dugmeta i bez tastera moraju i dalje biti dva polja, inače bi mutacija koja
uvek traži niz prošla oba testa oko njega.

Sedamnaesta je suptilnija: „gašenje dugmeta ostavlja započeto polje" je
preživela i posle toga, jer kontroler **ionako** odbacuje započeti niz na
sledeći običan klik — pa je čišćenje u ekranu izgledalo suvišno. Nije: ugasi pa
upali bez klika između je put koji samo ekran vidi.

Neodlučeno i namerno: desni klik je i dalje kopiranje FEN-a na svakoj tabli, pa
se ličesova konvencija ne može uzeti dok se ne odluči gde ide kopiranje.

**Vlasnikova odluka, „uzmi inverziju":**

1. **Nema krugova, nigde.** `[%csl]` prsten se briše; trenerovo obeleženo polje
   postaje tanak okvir po obodu polja, u boji koju je izabrao.
2. **Poslednji potez ide ispod figura** — sloj između polja i figure, crno na
   22%. Uglovne zagrade i žuti pojas idu s njim.
3. Time se dve oznake više ne takmiče: jedna je boja polja koja se menja ispod,
   druga je obod iznad. Nijednoj ne treba tuđa nijansa da bi se videla.

**Tri nalaza koja su odluku i napravila.**

Prvo: **`videoRenderer.js` to već radi tako** (linija 642) — polja, pa
`fillRect` preko oba polja poteza, pa figure. Film i aplikacija se danas ne
slažu oko toga kako poslednji potez izgleda, i nijedan kraj nije znao za drugi.
Renderer time dobija samo promenu boje.

Drugo: **poslednji potez se crta na 5 od 15 ekrana** koji imaju
`ChessBoardWithOverlay`. Među deset koji ga nemaju su Tactics (odakle je prijava
došla) i **soba**. `ChessBoardWithOverlay.lastMoveSquares` već postoji i već se
zove pri svakom potezu, pa se izvodi u samom widgetu — deset poziva koji treba
da se sete parametra je upravo to kako je i nastalo 5-od-15.

Treće: **okvir u trenerovoj boji ne radi bez tankih linija sa strane.** Mereno
na svih pet tabli i za obe modelirane deficijencije: zelena 1.01:1, crvena
1.02:1, narandžasta 1.24:1, ljubičasta 1.37:1, plava 2.86:1. Tri od pet nestanu
u polju na kom stoje. Sa crnom linijom spolja i belom iznutra svaka se vidi na
svakoj tabli. Ono što ni to ne popravlja, i piše u planu: boje se i dalje ne
razlikuju **međusobno** za crveno-zeleni deficit — to je plafon same palete
(`arrow_colors.dart`), isti kao i danas sa prstenom.

**Faze:** 0 sloj u `SkinnedChessBoard` (vođin commit, ništa se još ne crta),
1 poslednji potez postaje sloj, 2 svaka tabla ga crta, 3 okvir umesto prstena u
aplikaciji **i u filmu**, 4 označavanje opsega polja (a2→a7 po liniji, a2→e2 po
redu, a2→d5 po dijagonali). SHIFT je samo za desktop — Android nema modifikator
— pa je interakcija dugme u traci za crtanje, a SHIFT prečica za isto.

Otvoreno pitanje koje plan ne rešava: **desni klik je već zauzet** — kopira FEN
na svakoj tabli (`chess_board_with_overlay.dart:250`), pa se ličesova konvencija
(desni-prevlačenje strelica, desni klik polje) ne može uzeti dok se ne odluči
gde ide kopiranje FEN-a.

Provera uživo: `TODO-provera.md` stavka **153**, u četiri dela.

---

## Priručnik — faza 4 plana završnice, počela 11.9.2026

`docs/PLAN-PRIRUCNIK.md`. Vlasnikova odluka: priručnik su stranice na sajtu
(`chesstrainers.app/mislisha/manual/`), sa linkom iz aplikacije (red
„User manual" u Settings i na F1 strani), **bez slika** dok se aplikacija ne
zamrzne, na engleskom po glosaru. Piše se **po zadacima**, ne po ekranima.

**Vođin deo je gotov:** plan, kapija, sadržaj (`index.html`), uzorak poglavlja
„Write a tutorial", link iz aplikacije (`lib/core/user_manual.dart`), i
ispravka — naslov ekrana „Trening" je bio ostatak srpskog koji jezička kapija
ne vidi (nema našeg slova), sad je „Training" i test traži ime taba.

**Kapija je `chess_app/test/manual_labels_test.dart`:** svaka oznaka koju
priručnik citira mora da postoji kao literal u `lib/` — čita se lekserom, ne
regexom, jer komentari u ovom repou citiraju penzionisane nazive („Snimljeni
časovi"), pa bi ih regex primio kao dokaz. Proverava i da sadržaj vodi do svake
stranice i svaka nazad, da nema `{{`, slike ni našeg slova. Dokazana
mutacijama (izmišljena oznaka, preimenovana oznaka u aplikaciji, komentari kao
kod, stranica bez puta nazad).

**Priručnik je napisan — trinaest stranica, sve vođine.** Worker batch
(`docs/TASK-prirucnik.md`, `gemini-3.8-flash-high`) prošao je svih dvanaest
kapija iz prve runde, i njegove stranice su **odbačene**. Kapija za oznake je
odradila svoje — nijedna stranica nije citirala dugme koje ne postoji — ali ona
ne može da pita da li je **rečenica** tačna, a rečenice su bile izmišljene sa
istom sigurnošću: „radi u mobilnim veb pregledačima" (nema veb verzije), teme
table „tournament wood, modern slate, green vinyl" (izmišljena imena), prečice
`?` i `F` (ne postoje), „ispod 16 ulazi u zaštićeni režim" (ispod 13 se odbija),
i skener koji „slika stranicu veb kamerom" (skener čita PDF sa dijagramima u
šahovskom fontu, nikad sliku). Citati `file:line` koje je brief tražio ne drže:
`age_gate_screen.dart:176` je poruka o grešci, ne oznaka „Birth year".
Zadržana je njegova **struktura** (spisak stranica, redosled odeljaka, dužina);
sadržaj je pisan iznova uz kod.

**Pravilo koje iz toga sledi:** workeru se traži ono što kapija ume da proveri
(oznake, fajlovi, postojanje vrata), a ne proza o ponašanju — osim ako neko
ionako čita svaku rečenicu uz kod, a tada je pisanje jeftinija polovina.

Harness je pripremljen i ostaje koristan: `diff` kapija sad broji i izmene u
`site/`, `gate_tree` prima izmenu tračenih ne-Dart fajlova po imenu, a
`SERBIAN_WORDS` je dobio „trening" i „delovi" (ne i „deo" — javio bi se na
regexu koji prepoznaje stare nazive delova).

**Ostaje:** sajt nije objavljen (`TODO-objavljivanje`, 3a), pa link iz
aplikacije još ne otvara ništa; engleska politika privatnosti je starija od
odluke 13+ i ide zasebno, uz advokata. Provera uživo: `TODO-provera.md`, stavka
152. Aplikacija 2095 (1 preskočen), analyze 29.

Van plana priručnika, a nađeno usput: engleska politika privatnosti na sajtu je
od 26.8.2026, pre odluke 13+, i nije usklađena sa onim što aplikacija danas
radi. To je pravni tekst — ide odvojeno, uz advokatsku proveru kao kapiju pred
objavu.

## Istorija u studiju — plan 11.9.2026; sve četiri faze gotove, čeka proveru uživo (TODO-provera 151)

`docs/PLAN-STUDIO-ISTORIJA.md`. Vlasnik je obrisao deo, nije sačuvao, i kad je
ponovo otvorio tutorijal deo je i dalje bio obrisan: studio tiho uzima lokalni
nacrt istog tutorijala, i nema puta nazad do verzije sa servera. Tri stvari,
četiri faze: **undo/redo** (100 koraka, dok je studio otvoren, kucanje je jedan
korak po pauzi), **sačuvana verzija** (pitanje pri otvaranju kad postoje
nesačuvane izmene, „Discard changes", nova ruta `GET /lessons/:id`), i
**„Insert a line here"** — deo se seče na taktu u tri dela (do takta, nova
linija, stari nastavak), sa svim komentarima, strelicama i poljima. Vlasnikov
primer iz `8/3k4/1n3b2/8/8/8/2PK4/2R5 w` je test.

**Faza 1, 11.9.2026:** „Undo" i „Redo" u traci studija, Ctrl+Z / Ctrl+Y (i
Ctrl+Shift+Z), 100 koraka. Istorija je spisak celih nacrta
(`services/draft_history.dart`), beleži se u `_persist()`; kucanje u jednom
polju bez pauze od 1,2 s je jedan korak. Ctrl+Z pripada studiju i u tekstualnom
polju, jer na Windowsu polje zadržava fokus dok se figura vuče po tabli. Deo
vraćen undo-om nosi svoj stari step id i posle čuvanja (`localKey` po delu).
„Preview as student" je sada ikonica — na osnovu merenja koje je bilo pogrešno
(vidi fazu 3): kako Windows crta traku, reči staju i na 700 dp, pa je vlasnikova
odluka da li se vraćaju. Zadatak i
odgovori ranije nisu zvali `_persist()` — sada zovu. Prečice su na strani
„Keyboard Shortcuts". 27 testova; 26 mutacija uhvaćeno, a 27. je pokazala
suvišan red, koji je obrisan. Stavka za proveru
uživo dolazi u fazi 4, po planu. `Icons.redo` je nova ikonica u aplikaciji — ako
na Windows buildu ispadne prazna, to je zastareli `MaterialIcons-Regular.otf`
(vidi CLAUDE.md).

**Faza 2, 11.9.2026:** nova ruta `GET /lessons/:id` — isti uslov pristupa i
iste kolone kao lista, iz jedne konstante, pa ne može da da po id-u ono što
lista ne pokazuje. Kad se otvori sačuvan tutorijal čiji nacrt je na ovom
uređaju, studio uzme nacrt odmah (kao do sada), pa ga uporedi sa verzijom sa
servera; ako se razlikuju **po sadržaju** (ne po kursoru), pita „This tutorial
has changes you have not saved" — **Continue with my changes** ili **Open the
saved version**. Pita samo dok trener još ništa nije promenio; posle toga samo
upali „Discard changes" (ikonica pored undo/redo), koje vraća sačuvanu verziju
i samo je jedan Ctrl+Z. I „Open the saved version" je undo-korak. Ako server ne
odgovori, studio otvori nacrt i kaže da nije mogao da proveri. Red iz liste
stariji od poslednjeg čuvanja (sačuvano sa drugog uređaja) zameni se verzijom
sa servera kad trener nema ništa svoje na ekranu. `Icons.restore` je nova
ikonica — ista napomena o fontu kao za `Icons.redo`. Aplikacija 2066 (1
preskočen), backend 1234 sa sklonjenim `.env`, 24 mutacije uhvaćene.

**Faza 3, 11.9.2026:** „Insert a line here" — ikonica na kartici trenutnog
takta u „Flow" (samo na trenutnom taktu, i samo kad deo ima liniju). Deo se
seče na tri: do takta (zadržava step id i ime), nova linija od te pozicije
(trener ostaje na njenoj prvoj poziciji da je odigra; varijanta već odigrana na
tom taktu ide u nju), i stari nastavak sa svim komentarima, strelicama i
poljima. Jedan Ctrl+Z vraća sve. Vlasnikov primer je test, pročitan kroz
`LessonStepLine`. Mesto dugmeta je izmereno: u panelu delova četvrto dugme
spušta ikonice u treći red, pa lista delova pada sa 114 na 70 px na 1366 × 768;
na kartici takta ne košta ništa. Usput popravljen nestabilan test iz faze 1
(istorija sad čita `package:clock`). 19 mutacija: 18 uhvaćeno, jedna je pokazala
suvišan red.

**Merenja „sa pravim Windows fontom" iz faza 1–3 su bila pogrešna.** Sonda je
učitala Segoe UI, ali dugmad, naslov trake, dijalozi i oznake polja dobijaju iz
teme `AppText` stil bez porodice fonta; Windows to crta u Segoe UI, a
`flutter_test` u kvadratima. Izmereno ponovo kako Windows crta: naslov je 111 px
(ne 240) i ceo je do ~610 dp; „Preview as student" rečima je 147 px i staje na
700 dp; lista delova je 114 px na 1366 × 768 (1,8 reda), a 840 × 700 se ne
preliva. Zadatak „daj listi delova mesta" je tako izgubio premisu: ništa nije
menjano, a da li lista treba da bude gušća je pitanje za vlasnika. Tabela je u
`docs/PLAN-STUDIO-ISTORIJA.md`, „The measurements were wrong".

**Isto veče:** `splitForQuestion` više ne gubi step id kad se pitanje postavi
na početnu poziciju dela — nastavak (koji nosi celu originalnu liniju) zadržava
id i ime, a bez nastavka ga zadržava samo pitanje. Test čita zahtev za čuvanje;
6 mutacija uhvaćeno.

**Faza 4, 11.9.2026:** uputstvo (`UPUTSTVO-STUDIO.md`, odeljci 2 i 7) i stavka
151 u `TODO-provera.md`. Uz to, po vlasnikovoj odluci: dugme za pregled je
ponovo rečima, sad **„Preview tutorial"** (ne „as student" — tutorijal može da
piše i neko ko nema učenika); od 840 dp rečima, ispod toga ikonica kape sa
istim imenom, jer u testovima, gde je tekst dugmeta kvadratić, reči na 700 dp
prelivaju traku. Uputstvo kaže da „Preview tutorial" **nije izgled videa** —
film ima svoj „Preview" u dijalogu „Export video". Usput ispravljena netačna
rečenica u odeljku 5 uputstva: prelazak na drugi takt **gasi** crtanje (od
7.9.2026). Lista delova ostaje kakva je — vlasnikova odluka. Aplikacija 2083
(1 preskočen), backend nepromenjen 1234.

## Jezik glasa — 11.9.2026; svih šest faza gotovo, čeka proveru uživo

**Faza 6 je gotova** (samo dokumenti): `UPUTSTVO-STUDIO.md`, odeljak 8,
prepisan — tutorijal kaže jezik, uređaj bira glas tog jezika ili niko; bez
jezika je kao ranije. **Provera uživo je `TODO-provera.md`, stavka 150.**
Usput nađeno i ostavljeno: ostatak uputstva i dalje imenuje dugmad studija na
srpskom („Sačuvaj tutorijal", „+ Dodaj deo"), a aplikacija je od prelaska na
engleski sve to preimenovala.

**Faza 5 je u kodu** (aplikacija 2018, 1 preskočen; backend 1226): trener bira
jezik u studiju — padajući meni „Language" („Not set" i sedam jezika) u istom
redu sa nazivom i oznakama. Mesto je izmereno pravim Windows fontom, ne test
fontom: poseban red ispod košta 56 px i preliva prozor 840 × 800, a treći jednak
deo reda bi oba srpska unosa skratio na „Serbia…". Meni zato uzima svoju
širinu, a naziv i oznake dele ostatak (159 i 106 px na 840, umesto 271 i 181).
„Not set" šalje `null` samo kad je trener zaista promenio izbor; tutorijal koji
nikad nije znao jezik ostaje nem.

**Faza 4 je u kodu** (aplikacija 2009, 1 preskočen; backend 1226) — ovo je deo
koji se čuje. Ekran tutorijala čita trenerove rečenice glasom jezika tutorijala:
srpska latinica srpskim glasom, na Windows-u hrvatskim `Matej`, i potezima na
srpskom („lovac ce četiri"); nikad engleskim glasom. Gde uređaj nema glas za taj
jezik, umesto ▶ stoji ikonica „nema glasa", i dodir kaže zašto i šta da se
instalira. Glas koji Windows navede a nema ga, zaustavlja čitanje sa istom
porukom umesto da tutorijal protrči bez glasa. Brzina ispisa prati **glas koji
čita**. „Pregledaj kao učenik" u studiju čita istim glasom, a dijalog za izvoz
se otvara na glasovima jezika tutorijala.


**Faza 3 je u kodu** (aplikacija 1983, 1 preskočen; backend 1226): nacrt
tutorijala nosi jezik i šalje ga pri čuvanju — ali nacrt sačuvan na uređaju pre
ove izmene **ne šalje ništa**, da ne bi obrisao jezik postavljen negde drugde;
JSON uvoz čita `"language"` (nepoznat kod se prijavi i izbaci, tutorijal se
ipak uveze); `translate.py --code sr-Latn` upisuje jezik, a bez `--code` ga
**briše** umesto da ostavi jezik izvora. Provereno do kraja sa pravim srpskim
prevodom: skripta → fajl → uvoz u aplikaciji → nacrt na `sr-Latn`, čist.


**Faza 2 je u kodu** (aplikacija 1971, 1 preskočen; backend 1226): sedam
jezika sa glasovima uređaja u redosledu (`core/services/tutorial_language.dart`,
`voiceFor` — srpska latinica: srpski, pa hrvatski, pa bosanski; ćirilica samo
srpski; nikad engleski), i šest rečnika u `speech_text.dart` prenetih iz
`spokenMoves.js`. Oba suite-a sada čitaju **isti fajl od 76 očekivanih
izgovora** (`chess_backend/test/fixtures/spoken_moves_cases.json`). Usput:
server i aplikacija se već nisu slagali oko velikih slova posle kraja rečenice
(Š, Č, ćirilica) — sad je jedno pravilo. Kapija za srpski tekst u aplikaciji je
naučila ćirilicu, a rečnik glasa izuzima po strukturi, ne po fajlu. Ekrani još
ništa ne koriste — to su faze 3 do 5.


**Faza 1 je u kodu** (backend 1226, sa `.env` sklonjenim): kolona `language`,
jedan spisak od sedam kodova (`services/tutorialLanguage.js`), čuvanje, izmena
(ćutanje ne dira kolonu, `null` briše, nepoznat kod je 400), klon koji nosi
jezik, lista, i — ono najvažnije — **đakov put** `GET /assignments/:id`
(`getAssignmentDetail`) vraća `lessonLanguage`. Plan je u prvoj verziji
imenovao pogrešan fajl za taj put (`assignmentReview.js`, trenerov pregled);
ispravljeno pre kodiranja. Četrnaest mutacija, sve uhvaćene; jedna je prvo
preživela jer je lažna baza vraćala kolonu i kad je upit nije tražio.
Aplikacija još ništa ne zna o tome — to su faze 2 do 5.


`docs/PLAN-JEZIK-GLASA.md`. Vlasnik se složio sa sve tri preporuke: tutorijal
**kaže na kom je jeziku** (polje, ne pogađanje), bira se samo od **sedam
jezika** čije poteze aplikacija ume da izgovori, i gde uređaj nema glas za taj
jezik **ne čita se ništa** — ▶ se ne crta, ekran kaže šta da se instalira, a
tutorijal radi dugmadima. To sužava odluku od 9.9.2026 da se ništa ne izgovara
na srpskom: ona i dalje važi za tekst same aplikacije i za tutorijal koji nije
rekao jezik. Šest faza: kolona na serveru (uključujući put do deteta, preko
`assignmentReview.js`), čisto jezgro u aplikaciji sa rečnicima prenetim iz
`spokenMoves.js` i jednim fajlom očekivanih izgovora koji čitaju oba suite-a,
model i uvoz, glas po rečenici sa brzinom po glasu, kontrola u studiju, pa
dokumenti i provera uživo.

## Prevod tutorijala, van aplikacije — 11.9.2026

Pitanje vlasnika: može li aplikacija da prevede tutorijal na drugi jezik preko
LLM-a. **Odgovor je: ne u aplikaciji, za sada** — i to iz dva razloga koja
nisu tehnička. Backend-ov `GEMINI_API_KEY` je na **besplatnom nivou**:
`gemini-flash-latest` je tog dana pokazivao na `gemini-3.8-flash`, sa **20
zahteva dnevno**, i uz to je stalno vraćao 503. Proba je potrošila dnevnu kvotu
za taj model, pa su AI komentari u aplikaciji tog dana išli na mehanički
rezervni tekst. Isti ključ nosi AI komentare, pa kvote u `entitlementService.js`
(500 i 2000 mesečno) na njemu **ne mogu da se ispune** — to važi nezavisno od
prevoda i treba ga rešiti pre objave. Drugi razlog je pravni:
`politika-privatnosti.md` 5.2 obećava da Gemini dobija **samo šahovske
podatke**, a tekst tutorijala je slobodan tekst trenera koji može da imenuje
dete.

Vlasnik je odlučio: prevod ide **kao batch van aplikacije**. Stari `gemini` CLI
se više ne prijavljuje (Google je lične naloge prebacio na Antigravity), pa
batch ide preko `agy`, isto kao radnički batch-evi.

`tools/tutorial_translate/translate.py` i `prompt.md`; uputstvo je odeljak 9 u
`docs/PGN-TUTORIAL-FORMAT.md`. **Model nikad ne vidi potez**: skripta izvuče
sav tekst u ravnu listu `{id, text}`, pošalje samo nju, i vrati prevode na ista
mesta — pa posle upisa **dokazuje** da je svaki `pgn` bez komentara identičan
izvornom, bajt za bajt, i da se nijedno polje koje nije tekst nije promenilo.
Svaki prevedeni string se proverava pre upisa: notacija token po token (`Lc4`
umesto `Bc4` pada), bez `{`, `}` i `[%` u komentaru, bez ćirilice u latinici.
Odbijen string ide nazad jednom sa razlogom; ako padne opet, tutorijal se ne
piše i izveštaj imenuje string.

Izmereno: povratni prolaz preko svih 27 fajlova iz `fixed/` (703 stringa, 1134
tokena notacije) bez ijednog lažnog alarma; deset ubačenih vrsta greške, svih
deset uhvaćeno. Jedan pravi prevod (`adv_endgame_tarrasch_rule_active_rook`,
na srpski) prošao je sve provere iz prve i aplikacijin `readTutorialJson` ga
čita kao **čist**, četiri dela od četiri. Srpski je bio dobar; dve omaške
(„lekcija" umesto tutorijal, i „Crni" velikim slovom usred rečenice) su ušle u
rečnik u `prompt.md`.

**Otvoreno, i nije posao ove skripte:** aplikacija čita tutorijal naglas
**samo engleskim glasom** (`SpeechService.preferredLanguages = ['en']` od
prelaska na engleski), a ne zna na kom je jeziku rečenica — pa srpski
tutorijal na ▶ u aplikaciji čita engleski glas. To važi i za tutorijal koji
trener napiše na srpskom, ne samo za preveden. Izvezeni video je u redu, jer
dijalog za izvoz bira svoj glas. I: tutorijal napisan u studiju nema izvoz u
fajl, pa batch radi samo nad fajlovima napisanim van aplikacije.

## Video bez komentara pored table — 11.9.2026, ✅ provereno uživo istog dana

Na zahtev vlasnika: izvezeni video može da bude **samo tabla**, bez rečenica u
koloni pored nje. U dijalogu za izvoz je prekidač „Comments beside the board",
podrazumevano uključen i zapamćen za sledeći film, kao i 1080p. **Glas i dalje
čita** — to je bila odluka vlasnika: ko hoće nemi film, bira „No voice" u
pitanju o naraciji iznad.

**To je zastavica za crtanje, a ne izmena teksta.** `data.text` putuje u svakom
slučaju: to je i scenario koji glas čita, i — u filmu bez glasa — ono što
određuje koliko dugo takt stoji na ekranu. Sakriti komentare tako što se tekst
ne pošalje bi istovremeno utišalo film i ubrzalo ga.

Ulazi na jednom mestu, u `captionBandLines`: bez komentara je traka nula
redova, a nula redova je već ceo odgovor — `renderFrameBuffer` centrira tablu,
film se crta jednom u sekundi umesto četiri puta, i `renderBudget` broji
frejmove istim čitanjem. Da je zabrana išla niže, u samo crtanje, druga dva bi
i dalje verovala u kolonu koje nema. U `renderRecordingToMP4` se traka sada čita
**jednom**, pre ffmpeg-a, i ista vrednost ide i u crtanje i u brzinu koju ffmpeg
dobija; ranije se čitala dvaput. Pregled pre renderovanja dobija istu
zastavicu, jer pregled postoji da pokaže film koji će biti nacrtan.

Posledica koja se isplati: film bez komentara je **četvrtina crtanja**, pa
kad je film predugačak za jedan render, odbijanje sada nudi i „export it
without the comments beside the board" — ali samo kad bi to zaista stalo, kao
i ostala dva izlaza. Odsutno polje na serveru znači „da", što je tačno ono što
je svaki klijent pre ovoga mislio kad nije ništa rekao; aplikacija zato šalje
polje samo kad je `false`.

**Sedamnaest mutacija, sve uhvaćene — ali dve tek posle dva dopisana testa.**
Da ruta budžet računa sa zastavicom nije proveravao nijedan test (film koji ne
staje sa komentarima a staje bez njih), i da se izbor **zapisuje** u
podešavanja takođe ne — test „otvara se sa prošlim odgovorom" je taj odgovor
sam upisivao. Oba su dopisana i gledana kako padaju na svojoj mutaciji. Jedna
pogrešna pretpostavka u samom testu je popravljena usput: `find.byType(Switch)`
**findsOneWidget** je značilo „nema prekidača za naraciju", i palo je čim je
dodat drugi prekidač — šesti put u ovom repozitorijumu da tražilica prestane da
bude jedinstvena jer je ekran porastao. Pita za prekidač po imenu sada.

Pogledana su i dva prava frejma, 720p, ista pozicija: sa komentarima rečenica
stoji u svojoj koloni, bez njih je tabla centrirana, iste veličine, i pored nje
nema ničega.

Suite **1956** (+5), 1 preskočen, analyze 29 infoa i nula upozorenja; backend
**1213** (+7) sa `.env` sklonjenim. Proverio vlasnik uživo 11.9.2026, tačka 149
u `docs/TODO-provera.md`.

**Nije urađeno, i namerno odvojeno:** kvadratni izlaz (tabla preko celog
kadra, npr. za kratke klipove). To je novi format a ne podešavanje, i treba ga
prvo oceniti na jednom nacrtanom frejmu pre nego što se gradi.

## Ispis prati glas, a ne sat — 11.9.2026, nije viđeno uživo

Prijava vlasnika (11.9.2026. 11:11): u „Pregledaj kao učenik" pritisak na ▶
istovremeno čita i ispisuje komentar, ali se govor završi pre nego što se ceo
tekst ispiše.

Uzrok je bila jedna konstanta u `lesson_viewer_screen.dart`:
`_typedCharsPerSecond = 14`. Slova su išla fiksnom brzinom, a `_finishTyping()`
je na kraju govora dopisao ostatak odjednom — što je tačno ono što se videlo.
Iza nje su stajale dve greške koje se isplati zapamtiti odvojeno od ove
popravke. **Ta brzina nije znala za klizač za brzinu govora u Podešavanjima**,
pa je svako ko ga je pomerio dobio veći raskorak, i to takav koji se sam ne
ispravlja. I **komentar iznad konstante je tvrdio da je to „ista brzina kojom
piše izvezeni video", a video piše 12** (`tutorial_video.dart`) — broj koji se
drži na dva mesta preko komentara su dva broja, greška koju ovaj projekat već
ima zapisanu.

Sada `SpeechService` **meri** koliko taj glas stvarno čita: dužina rečenice
podeljena njenim trajanjem, i to samo iz rečenica koje su došle do kraja. Ekran
pita servis, pa ispis prati i izabrani glas i klizač. Brzina pripada **jednom
glasu na jednom podešenju**, pa se zaboravlja čim se promeni bilo koje od to
dvoje — inače bi se pisalo u ritmu glasa koji više ne govori.

Uzorak se odbija u tri slučaja: prekratka rečenica („Correct." je pola sekunde
zaleta motora, ne brzina čitanja), neverovatna brzina, i rečenica koja **nije
došla do kraja** — ona koju je čitalac prekinuo, ili za koju platforma nikad
nije javila kraj. Za to poslednje je dovoljan `_speaking`: i watchdog i `stop()`
ga gase, pa jedna provera pokriva oba.

**Osam mutacija, dve su preživele, i obe su bile nalaz.** „Obriši proveru za
nulto trajanje" je preživela zato što je ta provera **suvišna**: deljenje nulom
daje beskonačno, a opseg verovatnoće to ionako odbija. Provera je obrisana, po
pravilu koje već stoji u ovom projektu — dve provere u jednoj petlji se ne mogu
dokazati, pa ostaje ona koja pada na mutaciju. Druga je važnija: „uči i iz
prekinute rečenice" je preživela zato što je **test prekidao posle 400 ms**, pa
je uzorak ispao 165 znakova u sekundi i odbio ga je *opseg*, a ne provera koja
se testira. Prekid je sada posle tri sekunde, što je sasvim verovatna brzina.
Ista porodica kao slova fajlova na koja su odgovorile figure na prvom redu:
**fixture je dokazivao pogrešnu komponentu.**

Da se ekran zaista pita glas, a ne opet neki broj, pazi `CountingSpeech` u
`lesson_narration_test.dart` — mutacija koja vrati fiksnih 14 pada na njemu.
Zbog njega je `SpeechService.forSubclass` dodat pored `forTesting`: klasa sa
samo privatnim konstruktorom se ne može naslediti, pa se nijedan njen odgovor
ne može osmotriti.

Drugo pitanje iz iste prijave — „kojim glasom se čita, i šta ako nemamo piper
za taj jezik" — nije greška nego nesporazum o tome šta gde radi, pa je odgovor
otišao u uputstvo a ne u kod. **Tutorijal čita sistemski glas uređaja
(`flutter_tts`); piper i Azure postoje samo u izvezenom videu.** Novi odeljak 8
u `docs/UPUTSTVO-STUDIO.md` to kaže i imenuje ono što je na treneru i đaku:
glas i brzinu bira vlasnik uređaja, jezik komentara i jezik glasa moraju da se
poklope, a bez ijednog upotrebljivog glasa se ▶ uopšte ne crta. Zapisano baš
zato da se ne čita kao greška u aplikaciji.

Suite **1951** (+9: osam za merenje brzine, jedan za to da ekran pita servis),
1 preskočen, analyze 29 infoa i nula upozorenja. Backend nije diran.
Ostaje da se vidi uživo, tačka 148 u `docs/TODO-provera.md`.

## Tutorijal iz fajla, i oznake koje su oduvek postojale — 11.9.2026, nije viđeno uživo

Gemini je napisao dvadeset sedam tutorijala kao JSON fajlove po
`PGN-TUTORIAL-FORMAT.md`, u folderu van repozitorijuma, i nije
postojao način da se učitaju osim `curl`-om. Sada postoje dva: **Biblioteka →
Interaktivni tutorijali → „Import from a file"**. Aplikacija: **1942 testa**
(1 preskočen), backend: **1206**, analyze na 29 info i nula upozorenja. Deset
mutacija, sve uhvaćene.

**Jedan fajl se otvara u studiju i ne čuva se usput.** To je ono što je traženo:
prvo se pogleda na tabli, popravi ono što ne valja, pa se pritisne „Sačuvaj
tutorijal" — sa svim odbijanjima koja taj ekran već pravi, uključujući ono o
pitanju koje nosi svoj odgovor. **Više fajlova** ide pravo u biblioteku, jer
otvaranje dvanaest fajlova jedan po jedan u ekranu za pisanje nije provera nego
posao koji se preskoči.

**Čitač je `TutorialSection.fromStep`, ništa novo.** `positionList` iz fajla je
isti oblik kao `position_list` iz baze, pa se fajl čita kroz `readStepTree` →
`LessonStepLine`, dakle kroz parser koji dete koristi. Novo je samo pitanje koje
taj čitač ne može sam da postavi: **vredi li ovaj fajl otvoriti**, i ako ne — u
kom delu i zašto. `readTutorialJson` razlikuje dve vrste greške: ono što bi
server odbio (nečitljiv FEN, rešenje koje se ne može odigrati, loš broj
ponuđenih odgovora) i ono što bi bilo **sačuvano i pogrešno** (linija koja se ne
odigrava iz svoje pozicije, pitanje koje nosi odgovor). Prvo se ne šalje uopšte;
drugo se prijavi i trener odlučuje.

**`id` koraka se uvek odbacuje.** Korak po tom id-u nalazi red rasporeda i
zapamćen odgovor, pa bi isti fajl uvezen dvaput imao iste id-eve u dva
tutorijala — dečji napredak u pogrešnoj kopiji, bez ijedne poruke, jer se ni na
šta ne spaja.

**Oznake (labels) su već postojale na svakom sloju osim na ovom.**
`saved_lessons.tags` je u šemi, `GET /lessons/labels` ih vraća,
`GET /lessons?includeTags=&excludeTags=&matchMode=` filtrira, `SavePositionDialog`
ih piše a `MatrixFilterPanel` ih crta — samo tutorijal nikad nije stigao do
njih. Sada: polje „Labels" u studiju pored naziva, polje u dijalogu za uvoz koje
označi ceo skup fajlova odjednom, i u „Sačuvani tutorijali" traka čipova plus
pretraga po imenu. Čipovi se čitaju **iz samih redova**, ne iz
`GET /lessons/labels`: taj kraj vraća i oznake sačuvanih pozicija, a čip koji
prazni listu kad se pritisne je čip koji se ne pritisne drugi put.

**Uz to je izašla greška koja je tiho brisala opis.** `PUT /lessons/:id` je
pisao `description = $2, tags = $3` na **svakom** zahtevu, iz `body.x || null`,
a `commitDraft` ne pominje nijedno — pa je otvaranje sačuvanog tutorijala i
pritisak na „Sačuvaj tutorijal" brisao opis, ćutke. Niko to nije video jer u
aplikaciji ništa nikada nije pisalo opis tutorijala — do uvoza, koji je stigao
istog dana. Server sada ostavlja kolonu na miru kad je zahtev ne pomene (isto
pravilo koje `positionList` već ima), a `commitDraft` šalje ono što nacrt drži.
Prazna lista i dalje briše — „ovaj tutorijal više nema oznake" mora da ostane
izgovorljivo.

**Dvadeset tri od dvadeset sedam fajlova sada prolaze čisto** (bilo je
četrnaest). Popravka je jednokratna skripta koja: skida ocene zalepljene za
potez (`Kb6+-`, `Be8!+-`), **prepisuje potez kanonskim SAN-om** — `Bd6+` gde
nema šaha aplikacijin parser odbija, a python-chess ga prima, pa se neslaganje
vidi tek kad trener otvori tutorijal i nađe četiri poteza manje — vraća
`[%cal]` unutar vitičastih zagrada, i pitanju koje nosi odgovor izdvaja liniju u
zaseban `show` deo posle njega. Popravljeni fajlovi su u `fixed/`, originali
nisu dirani. **Četiri su ostala za čoveka**: `solutionSan` koji nije legalan u
svom FEN-u (`adv_endgame_queen_vs_rook_and_pawn` 3, `attack_focal_points_f7_g7_h7`
4, `positional_space_advantage_restriction` 4, `pvladan_vs_kvobetis_london` 4) —
u tri slučaja izgleda kao greška u strani koja je na potezu, a to je pogađanje o
šahu, ne o notaciji, pa nije rađeno automatski.

`PGN-TUTORIAL-FORMAT.md` je dopunjen pravilima koja su nedostajala (ništa
zalepljeno za potez, `+` samo kad stvarno ima šaha, `[%cal]` unutar zagrada,
pitanje bez linije, `solutionSan` legalan u svom FEN-u, opcioni `tags`) i ima
odeljak C o uvozu u aplikaciji.

Provera uživo: `docs/TODO-provera.md`, stavka 147.

---

## Četiri prijave uživo: slova, glas i uzorak — 11.9.2026, delimično provereno

Jedno veče sa pravim Azure nalogom, četiri prijave, sve četiri zatvorene u kodu.
Aplikacija: **1893 testa** (1 preskočen), backend: **1202**, analyze na 29 info i
nula upozorenja. Dvadeset četiri mutacije, sve uhvaćene.

**1. „Kad izgovara poteze Bc4, ovo c se skoro i ne čuje."** Polja su svuda bila
gola slova, i to je bilo pravilo sa razlogom: u srpskoj verziji aplikacije
„ge" je pročitala engleska tabela kao „dzh". Ali sa srpskim glasom koji čita
srpski, usamljen suglasnik je glas a ne reč. Ono o čemu je stara greška zapravo
bila jeste glas koji čita jezik koji nije njegov — pa tabela pripada **jeziku**:
`files` nema u pet rečnika čiji glasovi slovo ionako izgovaraju kako treba, a
ima ga u dva srpska (be, ce, de, ef, ge, ha). Provereno na pravom glasu, ne samo
u testu: `exports/tts-probe.wav`, „Odigraj lovac ce četiri, pa mala rokada".

**Srpski ima dva pisma i Azure ima oba.** `sr-Latn-RS` je latinički lokalitet, a
goli `sr-RS` ćirilički, i jedino id kaže koji je — pa postoje dva srpska rečnika.
Ono što je trener napisao se ne dira ni u jednom slučaju; u pismu glasa se piše
samo ono što se **dodaje** na putu do sintetizatora.

**2. „u renderovanom videu slova č, ć se ne vide."** `sans-serif` nije font nego
šta god mašina vrati, a na vlasnikovom Windowsu je to bila porodica bez Latin
Extended-A — dakle svako š, đ, č, ć i ž u svakom natpisu svakog filma je bilo
kvadratić, otkad je render napisan. Ni ispravka ne imenuje porodicu: ona se
**bira crtanjem**, jer su „č" i „ć" dva različita znaka, a font koji nema nijedan
nacrta isti kvadratić dvaput (`services/renderFont.js`). Stari test nad
pikselima ovo nije mogao da uhvati — pitao je ima li mastila, a kvadratić jeste
mastilo.

**3. Brojevi redova su bili nevidljivi od popravke slova kolona.** Popravka od
9.9.2026. je postavila `fillStyle` za kolone i ostavila redove da ga naslede, pa
je parnost koja je bila pogrešna za jedno postala pogrešna za drugo: osam
brojeva, nijedan nacrtan, dva dana. Sada oba natpisa pitaju tablin sopstveni
izraz `(row + col) % 2`, a test za redove je napisan kao blizanac testa za
kolone da par ne bi mogao ponovo da se popravi na pola.

**4. „Kako da se u Preview for students takođe bira glas… ili da se pusti sample
da čuje."** Uzorak, ne pregled: pregled je nem po prirodi (tri slike, bez
ffmpeg-a i bez reda čekanja), pa dodavanje izbora glasa tamo ne bi dalo da se
išta **čuje**. `GET /lessons/tts/sample?voice=…` izgovori jednu rečenicu, kroz
`spokenMoves` — dakle onako kako će zvučati i takt — i odbija glas koji ovaj
server nije sam ponudio: neprovereno ime stiže do Azurea kao 400, a do pipera
kao **drugi model**, pa bi trener birao po glasu koji nikad nije čuo. Dugme je
pored padajuće liste glasova u izvoznom listu.

Sitnica koju treba znati: u `.env` sada stoje **dva** reda `TTS_PROVIDER` (stari
`piper` i novi `azure`). Poslednji pobeđuje, ali to je detalj implementacije
dotenv-a, a ne pravilo — obrisati stari red.

## Izbor glasa: prvo jezik, pa glas — 11.9.2026, nije viđeno uživo

Vlasnikov Azure nalog je 11.9.2026. odgovorio sa **655 glasova u 154 jezika**
(`node scripts/tts-probe.js`). Jedna padajuća lista od 655 stavki je lista do
čijeg kraja niko ne skroluje, pa izvozni list sada pita **prvo jezik** — imenom
koji server pošalje („Serbian (Latin, Serbia)"), a ne šifrom — a lista glasova
je lista tog jezika. Kontrola za jezik se crta samo kad ih ima više od jednog,
po istom pravilu po kom se crta i pitanje o naraciji: pitanje sa jednim
odgovorom nije pitanje.

**I odgovor na staro pitanje: Azure ima srpski glas.** Četiri, u oba pisma —
`sr-RS-NicholasNeural` i `sr-RS-SophieNeural`, sa `sr-Latn-RS-` blizancima. U tri
fajla je stajalo da ga nema, a provereno je bilo protiv Googleove liste. Za
tekst pisan latinicom treba `sr-Latn-RS` glas; `sr-RS` je ćirilički lokalitet.
Komentari sada kažu šta je provereno i protiv čega.

**„Prvi glas sa liste" prestaje da bude razuman podrazumevani izbor.** Lista je
sortirana po jeziku, pa je prvi glas od 655 bio afrikans — a pozivalac je baš to
slao kad ništa nije zapamćeno. Sada šalje null, a list bira: jezik zapamćenog
glasa, pa jezik same aplikacije, pa vrh liste. Null pokriva i zapamćen glas koji
server više ne nudi, što je tačno ono što promena `TTS_PROVIDER`-a uradi svim
id-jevima odjednom.

Aplikacija: **1891 test** (bilo 1884), 1 preskočen, `flutter analyze` na 29 info
i nula upozorenja. Sedam mutacija, sve uhvaćene — jedna je isprva preživela i
otkrila stražu koju ništa nije moglo da dosegne; zamenjena je pravilom na ulazu
u list, koje test sa glasom bez jezika stvarno dohvati.

## Azure Speech, i srpski koji je vraćen a ne preveden — 11.9.2026, nije viđeno uživo

Vlasnik je 11.9.2026. uzeo ključ i region za Azure Speech, pa `services/tts/
azure.js` postoji: četvrti provajder i **prvi oblak koji ovaj projekat može da
plati**. Google Cloud stoji napisan i nedostupan od 9.9.2026. jer ne prima
individualni platni profil iz Srbije; Azure traži pretplatni ključ i region i
ništa drugo. Piper ostaje instaliran kao rezerva — bira se `TTS_PROVIDER`-om, i
dalje radi bez naloga, bez kartice i bez mreže.

**Ključ ne ulazi u repozitorijum.** `.env.example` nosi samo imena
(`AZURE_SPEECH_KEY`, `AZURE_SPEECH_REGION`); vrednosti idu u `.env` na mašini
kojoj trebaju. Resurs ima dva ključa upravo zato da se jedan može poništiti bez
prekida.

**Region, a ne URL.** Oba endpointa se grade od regiona
(`https://<region>.tts.speech.microsoft.com`), pa provajder odbija sve što nije
slovo ili cifra — inače se od nalepljenog URL-a gradi `https://https://…` i kvar
stiže kao poruka o hostu umesto kao poruka o konfiguraciji.

**SSML je jedina prava razlika u odnosu na Google.** Googleov endpoint prima
običan tekst i `google.js` piše zašto ga baš tako šalje: rečenica sa `<` u sebi
nije pokvaren markup nego rečenica koju bi SSML odbio. Azurov `cognitiveservices/
v1` prima isključivo SSML, pa taj izbor ne postoji — `ssmlFor` escapuje i ima
test, sa ampersandom **prvim**, jer escapovanje `&` na kraju pretvori četiri
ranija escapea u „and a m p semicolon".

**Lokalitet nije uvek dvodelan, i srpski je razlog.** Azure piše srpski kao
`sr-Latn-RS`, sa pismom u sredini. `languageOf` uzima sve do **poslednje** crte;
dvodelno čitanje kakvo koristi `google.js` poslalo bi `xml:lang="sr-Latn"` i
svrstalo sve srpske glasove pod jezik koji ne postoji.

**Srpske reči su vraćene, ne prevedene.** `spokenMoves.js` je dobio `sr` rečnik,
pa se „Bd5" izgovara „lovac d pet" umesto da se slovka — a reči su `serbianSpeech`
tačno onakav kakav je stajao u `speech_text.dart` pre engleskog zaokreta
(`ce012c0^`), dakle ono što su treneri slušali nedeljama. Pravilo je staro i u
`CLAUDE.md`: potraži postojeću implementaciju pre nego što napišeš drugu.

**„Ni Google ni Azure nemaju srpski glas" je stajalo u tri fajla, a provereno je
protiv jedne liste.** Sada na to pitanje odgovara `node scripts/tts-probe.js`,
koji ispiše listu glasova koju nalog stvarno ima, grupisanu po jeziku, i traži i
`sr-RS` i `sr-Latn-RS`.

**Šta ostaje, i nije u ovom poslu.** Padajuća lista glasova u izvoznom listu
crta jednu stavku po glasu. To je tačno za piperovih šest i neupotrebljivo za
oblak sa nekoliko stotina; probe skript ispiše koliko ih zaista ima, a popravka
je filter po jeziku u samom listu. Aplikacija u ovom poslu nije dirana.

Backend: **1186 testova** (bilo 1176), sa `.env` sklonjenim u stranu. Devet
mutacija, sve uhvaćene.

## Glas koji ne može da progovori se sada zna pre crtanja — 10.9.2026, nije viđeno uživo

Prijava vlasnika te večeri: izvoz tutorijala se renderuje bez glasa iako je
jezik izabran. U logu: `piper exited 1: ...python.exe: No module named piper`,
zatim `[TTS] narration was asked for and every beat came back silent`, pa
uredan `Success!` i film — nem.

**Dve izmene, obe tražene tog dana.**

*Prva je konfiguracija.* Piper je na razvojnoj mašini bio instaliran sa
`pip install --user`, dakle u `%APPDATA%\Python\Python313\site-packages`, a
`PIPER_PYTHON` je bio prazan — što znači `python`, razrešen kroz PATH. Oba
oslonca zavise od okruženja procesa koji ga pokreće: korisnički `site-packages`
je na `sys.path` samo dok proces nosi ispravan `APPDATA`. Sada postoji
virtualenv (`C:/Users/Admin/.piper/env`) i `PIPER_PYTHON` pokazuje na njegov
interpreter punom putanjom; venv razrešava svoje pakete iz `pyvenv.cfg` pored
sopstvenog `python.exe`, pa mu ni PATH ni APPDATA ne mogu ništa. Provereno:
isti `import piper` prolazi i kad se `APPDATA` obriše iz okruženja, dok je pod
`--user` instalacijom padao. Droplet je to ionako već imao — `deploy/
provision.sh` pravi venv u `/opt/piper`; pogrešna je bila samo razvojna mašina i
uputstvo u `.env.example`, koje je to preporučivalo.

*Druga je kod, i ona je važnija.* `piper.available()` je odgovarao na pitanje o
**modelima** — „ima li `.onnx` fajlova u direktorijumu" — a ne o **motoru**.
Zato je aplikacija ponudila prekidač za naraciju, server prihvatio `narrate:
true`, i tek posle celog crtanja film ispao nem. „Instalirano" i „dohvatljivo iz
ovog procesa" su dva pitanja: `piper.engineReady()` je sada drugo od njih —
jedan `find_spec("piper.__main__")` po interpreteru, asinhrono (250-430 ms na
niti koja crta nečiji film), zapamćen za život procesa. Posledica: motor koji ne
može da se pokrene znači **praznu listu glasova**, pa se prekidač uopšte ne
crta, a ako neko ipak pošalje `narrate: true`, trener dobija svoju rečenicu —
„the speech engine could not start", odvojenu od „no speech voices installed",
jer te dve šalju čoveka na dva različita mesta.

**Šta nije utvrđeno, i to treba da stoji.** Log je u UTC (`translateTime` bez
`SYS:`), pa je `21:15:18` zapravo `23:15:18` po lokalnom vremenu — minut posle
pokretanja servera u `23:14:11`. Okruženje **tog istog procesa** je pročitano iz
PEB-a dvanaest minuta kasnije i bilo je ispravno: `APPDATA` na mestu, bez
`PYTHONNOUSERSITE`, `PYTHONPATH` i `PYTHONHOME`, Python313 prvi na PATH-u, a
paket u korisničkom `site-packages` neizmenjen od 9.9. u 11:28. Tri načina da se
ista poruka izazove su reprodukovana (bez `APPDATA`, sa `PYTHONNOUSERSITE=1`, sa
tuđim `APPDATA`), ali nijedan od njih se u tom procesu nije desio. Dakle: klasa
greške je uklonjena, konkretan okidač tog jednog pokretanja nije objašnjen — i
zato je druga izmena ona koja nosi težinu, jer se **svaka** takva greška sada
vidi pre crtanja, a ne minut posle njega.

Backend: **1176 testova** (bilo 1172), sa `.env` sklonjenim u stranu. Šest
mutacija, sve uhvaćene — a jedna je isprva preživela: `narrateFilm` koji
uvek kaže „unavailable" umesto stvarnog razloga ostavljao je sve zeleno, iako je
to rečenica koju trener čita. Test za nju je napisan pošto ju je mutacija
otkrila.

## Render izlazi iz zahteva — tačka 5 drugog dela plana snimanja, 10.9.2026, nije viđeno uživo

Izvoz tutorijala sada odgovara **čim server prihvati film** (`202` i id posla), a
film se crta posle odgovora. Ekran se više ne zamrzava: traka ima „Hide" (film se
crta dalje, a kad bude gotov stiže obaveštenje na zvonce) i „Cancel render".
Sakriven render se nalazi ponovo na redu tutorijala u „Saved tutorials" (ikona
filma), a drugi izvoz istog tutorijala prikazuje onaj koji već radi umesto da
pokrene novi.

Posao je **red u bazi** (`tutorial_render_jobs`, `services/renderJobs.js`), ne
zapis u memoriji. Server bira id; jedan render po tutorijalu i treneru čuva
jedinstveni indeks; a red koji kaže `running`, a iza njega nema ničega (restart
servera), proglašava se neuspelim — pri pokretanju, uz obaveštenje, i kad god ga
neko pogleda. Sve što odbija film i dalje odgovara u samom zahtevu (404, 400,
409, 422, 429).

**Četiri dopune vlasnika iste večeri**, pre commit-a:

1. Plafon za jedan film je **600 s crtanja** (`RENDER_MAX_DRAW_SECONDS`), oko 30
   minuta tutorijala na 720p. `RENDER_REQUEST_SECONDS` (300, nginx) se vratio i
   znači samo vezu.
2. Snimak glasa sme do **30 minuta**, i to više nije poseban broj: izvodi se iz
   plafona (najduži film sa natpisima koji jedan render sme da nacrta na 720p).
   `GET /lessons/:id/narration` ga vraća kao `maxMs`, a studio pita pre nego što
   otvori ekran za snimanje. Kad server ne može da se pita, ekran staje na starih
   15 minuta — namerno kraće, jer se kraći snimak uvek prima.
3. **Izvoz snimljenog časa ide ispred tutorijala koji čekaju**, jer se on i dalje
   crta u zahtevu (300 s). Film koji se već crta ne može da prekine — jedan slot
   crta jedan film — pa ako mu ostatak tog filma pojede vreme, odmah dobija 429
   sa „Try again in about N minutes", umesto da ga nginx preseče. Proverava se i
   na ulazu i kad dođe na red.
4. `abortOnDisconnect` je obrisan sa svoja tri testa; signal pali trenerovo
   „Cancel".

Namerno nije urađeno: deljenje filma na komade (dugačak film i dalje drži slot
do deset minuta), noćni red, čišćenje starih redova poslova, i prekid izvoza
snimljenog časa (nije ga imao ni ranije). Detalji i razlozi su u planu, pod
„5 — the render leaves the request".

Trideset četiri mutacije, sve uhvaćene testom na koji su ciljale. Usput je jedan
test koji je zaboravio da otvori svoju kapiju oborio još deset — a pravilo
„jedan render po tutorijalu" je svaki put radilo kako treba. Test
„3. empty events", poznat kao nestabilan, sada broji samo fajlove svog tutorijala.

Brojke, merene sa ovim izmenama bez ičega drugog uz to: **1884 u aplikaciji** (1
preskočen), **1172 na backendu** sa `.env` sklonjenim u stranu, analyze 29
infos, bez upozorenja. Provera uživo: `TODO-provera.md`, stavka **143**; stavka
142 je dopunjena, jer se njeni koraci 2–5 menjaju sa novim plafonom.

Van koda: `chess_backend/.env` je od 9.9. stajao kao `.env.aside` — ranija
sesija ga je sklonila za merenje kao na CI-ju i nije ga vratila, a to ime nije
u `.gitignore`, pa je jedan `git add` delio tajne od javnog repozitorijuma.
Vraćen je 10.9.2026, a merenja sa `.env` u stranu sada rade sa `trap`-om koji ga
vraća i kad test padne.

---

## Render koji ne može da stane se odbija pre crtanja — tačka 4 drugog dela plana snimanja, 10.9.2026, nije viđeno uživo

Server sada pre prvog frejma računa koliko bi film trajao
(`services/renderBudget.js`): frejmove po istom pravilu po kom ih renderer crta
(`framesPerSecondOf`), podeljene brzinom crtanja iz `.env`. Film koji ne može da
stane ni u jedan zahtev (300 s, koliko nginx daje) odbija se **odmah**, sa 422 i
rečenicom koja kaže koliko bi trajalo, koliko server može u jednom komadu, i
samo one izlaze za koje je provereno da staju: podeli na N tutorijala, 720p
umesto 1080p, film bez snimka.

**Red je postao obećanje o vremenu.** Svaki posao nosi procenu i rok; novi se
odbija kad bi on zakasnio iza drugih (a sam bi stao), ili kad bi zbog njega
zakasnio film koji već čeka — round-robin to može, jer nalog koji još nije
služen ide napred. Taj odgovor je 429 sa „Try again in about N minutes", a ne
rečenica o punom redu: server ima mesta, nema vremena. Film sa sintetizovanim
glasom meri se **ponovo kad dođe na red**, jer mu se prava dužina zna tek kad
glas progovori.

Podrazumevane brzine su 12 i 6 frejmova u sekundi (720p / 1080p) — sporiji kraj
razvojne mašine sa marginom. **Brzina dropleta nije izmerena**; to je korak 6
stavke 142. Petnaestominutni snimak na 720p je po podrazumevanoj brzini tačno
jedan zahtev, i test to drži: granica snimka i ovaj budžet su sada jedna odluka.

Osamnaest mutacija, sedamnaest pada. Dve su najpre preživele i obe su nalaz:
ruta nije imala test da posle glasa **javlja redu** novu procenu (`revise` je bio
dokazan samo u samom redu), a **pravilo „natpis → 4 frejma u sekundi"** nije
imalo nijedan test u celom paketu — mutacija koja svaki film crta jednom u
sekundi prolazila je sve, a budžet se sada na to pravilo oslanja. Oba sada imaju
test. Preživljava namerno samo izvoz snimljenog časa (`routes/recordings.js`)
koji redu javlja svoju procenu: ta ruta nema test izvoza ni pre ni posle.

Usput: test „3. empty events" u `tutorial_video_export.test.js` je nestabilan —
broji fajlove u pravom `exports/` dok drugi test fajlovi rade paralelno. Pao je
jednom u punom prolazu, nevezano za ovu promenu, i ponuđen je kao zaseban
zadatak.

Iz provere uživo 10.9. (beleške i prijave): ekran se zamrzava za ceo render, što
je najjači argument za tačku 5; tutorijali postoje samo na Windowsu, pa koraci
za telefon u stavkama 136 i 141 ne mogu kako su napisani (141.6 je
preformulisan); i „Moji materijali" sa kvotom po nalogu. Sve troje je upisano u
plan, odeljak „What the live check changed".

Brojke: **1146 na backendu** sa `.env` sklonjenim u stranu, aplikacija nedirnuta
na 1876. Provera uživo: `TODO-provera.md`, stavka **142**.

---

## Snimanje glasa: faza 6, jedno pitanje za zvuk filma — 10.9.2026, nije viđeno uživo

U „Export video" su dva prekidača — „Use my recording" i „Narrate this video" —
postala jedno pitanje **„Narration" sa tri odgovora**: „My recording (m:ss)",
„Synthesised voice" i „No voice". Odgovor se crta samo tamo gde može da se
ispuni (snimak samo ako postoji na uređaju i slaže se sa taktovima, sintetizovan
glas samo ako ga server ima), a pitanje samo kad postoje bar dva odgovora. Server
se nije menjao: ruta je već gledala `useRecording` pre `narrate`.

**Snimak je podrazumevan i ne pamti se.** Kad ga trener izabere, ne briše se ono
što je prošli put izabrao između sintetizovanog glasa i tišine — taj odgovor
važi baš za filmove koje snimak ne može da napravi: tutorijal izmenjen posle
snimanja, sledeći koji još nije snimljen. Test to proverava na sačuvanoj
postavci, ne na ekranu.

**Dijalog nije stao na telefon.** Sa sva tri odgovora i listom glasova viši je
za 49 px od 360 × 640, a release build to odseče bez reči: test koji je tapnuo
„Higher quality (1080p)" pogodio je red sa dugmadima, dakle na telefonu je
prekidač stajao ispod „Export". Sada dijalog skroluje, a test traži da prekidač
**radi** — zahtev kaže 1080p — umesto da pita da li je nešto bacilo izuzetak.

Osam mutacija, svih osam pada. Provera uživo: `TODO-provera.md`, stavka **141**;
koraci u stavkama 139 i 140 koji su opisivali prekidač su preformulisani.

Time je **ceo prvi deo `PLAN-SNIMANJE.md` u kodu**. Ostaje drugi deo (tačke 4 i
5 — odbijanje prevelikog rendera i izlazak rendera iz zahteva), i dalje
otvoreno brisanje **lokalnog** snimka kad se tutorijal obriše.

Brojke: **1876 u aplikaciji (1 preskočen)**, backend nedirnut na 1126;
`flutter analyze` 29 info poruka, bez upozorenja i grešaka — mereno na `master`,
bez ičeg drugog pokrenutog.

---

## Snimanje glasa: faza 5, snimak zna kojim taktovima pripada — 10.9.2026, nije viđeno uživo

Prepravi rečenicu, dodaj deo, zameni dva mesta — i markeri imenuju taktove nad
kojima nisu snimljeni. Ćutke, i film je pogrešan negde od sredine, što je
polovina koju niko ne proverava. Broj taktova, koji je to čuvao do sada, vidi
dodat i obrisan takt i **ne vidi prepravljenu rečenicu**.

Snimak sada nosi **potpis liste taktova** nad kojom je napravljen —
`filmSignatureOf`, sha256 nad `filmBeatsOf`, dakle nad istom šetnjom po
tutorijalu koju film crta. Kad se potpis tutorijala razlikuje, studio to kaže
**tamo gde je izmena i napravljena**, sa dva izlaza: „Record again" i „Export
without your voice". Isti odgovor daje ekran za snimanje, dijalog za izvoz i
server — jedna odluka (`takeMismatchOf`), tri rečenice.

Šta **nije** u potpisu, i to je pola faze: ime tutorijala, ime dela, strelice,
obojena polja i okrenuta tabla. Sve to menja šta je nacrtano na taktu, a ne koji
je takt niti koliko dugo se o njemu priča — sat vremena snimanja ne sme da
propadne zbog naslova.

**Snimak bez potpisa nije snimak koji se slaže.** Napravljen je starijom
verzijom aplikacije, stoji na trenerovim uređajima i na serveru, i sudi se po
broju taktova kao i pre; server odbija tek kad **obe** strane imaju potpis.
Odsustvo je treći odgovor, po treći put u ovom projektu.

Dva nalaza, oba iz mutacija koje su preživele. **Potez nije u potpisu** — bio je
u prvoj verziji, i brisanje mu ništa nije oborilo: fen takta već odgovara za
potez koji ga je napravio, jer se dve linije koje se razlikuju u jednom potezu
razlikuju u svakoj poziciji posle njega. Polje koje nijedan test ne može da
obori je polje u koje će se verovati a da ga niko nije pročitao. I **fikstura
može da dokazuje pogrešnu stvar**: „deo koji počinje na drugoj poziciji" je
najpre menjao i broj taktova, pa nije govorio o fenu ništa; sada je isti
tutorijal na tabli bez dama.

Provera uživo: `TODO-provera.md`, stavka **140**.

---

## Snimanje glasa: faza 4, video u trenerovom glasu — 10.9.2026, nije viđeno uživo

U „Export video" prvi red je sada **„Use my recording (m:ss)"**, uključen kad
uređaj ima upotrebljiv snimak tog tutorijala. Aplikacija pita server koji snimak
ima (`GET /lessons/:id/narration`), šalje ga **samo ako server nema baš taj**, i
server crta film po markerima snimka: takt počinje tamo gde je trener pritisnuo
razmak, natpis se otkriva kroz vreme koje je stvarno proveo na tom taktu, a zvuk
se ubacuje kakav jeste. Provera uživo: `TODO-provera.md`, stavka **139** — ovo
je prva faza koju vlasnik može da pritisne, pa je i faza 3 tek sad vidljiva.

Snimak koji ne može da napravi ovaj film se **objasni umesto prekidača**
(nem, nedovršen, ili snimljen kad je tutorijal imao drugi broj taktova). Kad je
prekidač uključen, redovi za sintetizovani glas se ne crtaju — film nikad ne ide
sa oba glasa. Server na isto pitanje odgovara pre reda za renderovanje: nema
snimka, drugi snimak, drugi broj taktova, ili fajl nestao — četiri 409 sa četiri
rečenice, bez potrošenog slota.

Tri stvari vredi zapamtiti.

**Snimak je stajao pored koda koji briše zvuk.** Ruta za izvoz u `finally`
briše `narrationAudioPath` — sintetizovanu traku — kad se film nacrta. Da je
snimak prošao kroz tu promenljivu, jedan izvoz bi zauvek obrisao trenerov glas.
Ide samo kao `audioFilePath`, a test proverava da je fajl i dalje tu posle
izvoza; mutacija koja ga provlači kroz pogrešnu promenljivu pada.

**Dijalog koji čeka platformu je dijalog koji se ne otvara.** Prva verzija je
čekala da nađe snimak pre nego što otvori dijalog, a `path_provider` na Windowsu
pravi folder pravim asinhronim I/O-om, koji lažni sat widget testa nikad ne
pusti da se završi — dvanaest postojećih testova izvoza prestalo je da vidi
dijalog. Sada se dijalog otvara odmah, a red se pojavi kad stigne odgovor;
kasni odgovor posle zatvorenog dijaloga ne dira ništa (i to ima test). Slanje
čita fajl ceo, iz istog razloga.

**Dve mutacije bi preživele iz pogrešnog razloga, i nađene su pre pokretanja.**
„Nikad oba glasa" nije moglo da se vidi dok lažni server nije umeo da govori,
jer tada `narrate` ionako nikad nije u zahtevu; a „film u trenerovom glasu je
označen kao ozvučen" proveravao je jedini test koji šalje i `narrate: true`, što
zastavicu postavlja samo po sebi. Oba testa su popravljena pre nego što je
skripta pokrenuta, i svih 22 mutacija pada.

Otvoreno: faza 5 (potpis umesto broja taktova), i brisanje **lokalnog** snimka
kad se tutorijal obriše.

Brojke: **1846 u aplikaciji (1 preskočen), 1121 na backendu** sa `.env`
sklonjenim u stranu, `flutter analyze` na 29 info poruka; sve mereno jedno za
drugim, bez ičeg drugog pokrenutog.

---

## Snimanje glasa: faza 3, slanje na server — 10.9.2026, testirano, bez dugmeta

`POST /lessons/:id/narration` prima trenerov snimak, a
`LessonApiService.uploadNarration` ga šalje. **Ništa u aplikaciji još ne zove
slanje** — to radi opcija „tvoj snimak" u izvozu, koja je faza 4. Zato ovde nema
stavke za proveru uživo: nema dugmeta koje bi se pritisnulo.

Tri odluke vlasnika od 10.9.2026: server čuva **wav kako je snimljen**; klon
tutorijala **počinje bez glasa**; jedan snimak je najviše **15 minuta**. Vlasnik
se sećao dogovora da se ograničenje od 300 s promeni — u dokumentima je
zapisano nešto drugo: korak 5 drugog dela plana (render izlazi iz zahteva), koji
plafon ukida umesto da ga pomera, i koji nije urađen. Kad bude, ograničenje od
15 minuta nema više razloga. Aplikacija sama zaustavlja snimanje sekund pre
toga, jer zvuk stiže u celim paketima.

**Server čita fajl, a ne opis fajla.** Format i dužina iz zaglavlja wav-a
(`wav.js` je dobio `wavInfo`; `ffprobe` bi pročitao isto zaglavlje, drugim
procesom), nivo iz samih uzoraka. Markeri moraju da počnu od 0, samo da rastu,
da se završe pre kraja zvuka i da ih bude koliko i taktova. Odbijen fajl se
briše. **Ko sme da snima pita se pre nego što multer primi ijedan bajt** —
`mayRecordNarration`, isto pravilo kao u sobi: 18 godina, a nepoznata godina je
odbijanje. Red u bazi se piše pre nego što se stari snimak obriše, a brisanje
tutorijala briše i snimak.

Tri stvari vredi zapamtiti.

**`uploads/` je javan, i to od ranije.** `server.js` ga služi preko
`express.static`, bez prijave — ko zna ime fajla, skida snimak iz sobe.
Snimci glasa za tutorijale su zato u `uploads/narration/`, koji se nikad ne
služi (`middleware/uploadsStatic.js`); ostatak je zaseban zadatak, predložen
kao posebna sesija.

**Test koji šalje URL preko `fetch` ne vidi `..`.** WHATWG URL razreši `.` i
`..` (i `%2E%2E`) pre nego što zahtev ode, pa je mutacija koja briše
normalizaciju putanje preživela. Test sada šalje putanje doslovno kroz
`http.get`, i tek tada mutacija pada.

**Tri mutacije se nisu ni primenile**, jer `routes/lessons.js` ima Windows
kraj reda, a regex je tražio `\n`. „NOT APPLIED" nije „caught" — skripta to
razlikuje, i zato je to uopšte primećeno.

Otvoreno: **brisanje naloga mora da obriše snimke.** Ruta za brisanje naloga
danas ne postoji (`DELETE FROM users` je samo povratak neuspele registracije),
ali `saved_lessons` se briše kaskadno sa nalogom, a kaskada ne briše fajlove.

Brojke: **1836 u aplikaciji (1 preskočen), 1114 na backendu** sa `.env`
sklonjenim u stranu; obe mereno jedna za drugom, bez ičeg drugog pokrenutog.

---

## Snimanje glasa: faze 1 i 2 — 10.9.2026, nije viđeno uživo

Trener u studiju pritisne ikonicu mikrofona (samo na **sačuvanom** tutorijalu,
kao i „Export video"), pritisne „Record" i priča; razmak postavlja sledeći
takt. Tabla i rečenica tog takta stoje pred njim kao sufler, a red „Next: …"
kaže šta će razmak postaviti. Posle „Stop" snimak ostaje **na uređaju**, i
„Listen" ga pušta dok tabla prati glas. Slanje na server je faza 3 i nije
početo. Provera uživo: `TODO-provera.md`, stavka 138.

**Marker je broj bajtova ÷ byte rate, nikad sat na zidu** — to je odgovor faze
0 i sad je kod. Zagrevanje mikrofona i pauze zato ne pomeraju ništa: pauza
zaustavlja i zvuk i sat, a takt pomeren tokom pauze pada tačno na šav. Utišan
mikrofon se čita iz samih uzoraka (prag −70 dBFS naspram izmerenih −91) i ekran
to kaže posle tri sekunde **zvuka** bez ičega, dok se snima — ne posle sat
vremena pričanja.

Gde je šta: jezgro je `services/narration_take.dart` (bez plugina i widgeta),
plugin je `record_pcm_source.dart`, ekran `tutorial_narration_screen.dart`.
`filmBeatsOf` je izvučen iz `tutorialVideoOf`, pa film i snimanje čitaju **jednu**
šetnju tutorijala — marker `i` je događaj `i` po konstrukciji, a ne zato što se
dve petlje danas slažu.

Tri stvari vredi zapamtiti.

**`await` na `StreamSubscription.cancel()` visi pod lažnim satom widget testa.**
Budućnost koju vraća već je završena u root zoni, i pod `fake_async` nastavak
nikad ne dođe — „Stop" i „Discard" su visili u četiri testa ekrana, dok su
jedinični testovi jezgra prolazili jer nemaju lažni sat. Otkazivanje deluje u
trenutku poziva, pa se ne čeka.

**Četiri straže su obrisane jer nijedna nije mogla da padne**, i sve je našla
mutacija: provera stanja u `_onChunk` (pretplata je već otkazana pre nje),
`existsSync` u `load` (otvaranje fajla koji ne postoji baca, i `catch` već
odgovara), te `ExcludeFocus` i `requestFocus` oko dugmadi. Za poslednje dve
odgovor je dala **proba**, a ne zaključivanje: prečica za razmak stoji iznad
svih kontrola pa je čuje pre fokusiranog dugmeta, a kad dugme „Record" nestane
sa fokusom na sebi, opseg sam vraća fokus čvoru koji ga je imao pre. Test „take
started from the keyboard" ostaje — on ne dokazuje `requestFocus`, nego
`autofocus`, bez koga ne bi bilo prethodnog čvora, i pada kad se `autofocus`
obriše.

**Snimak na disku ima svoje ime, a indeks ga imenuje.** Novi pokušaj se snima
pored starog, `take.json` se zameni, i tek onda se stari zvuk briše; pri
čitanju se indeks proverava prema dužini samog wav-a. Neslaganje se prijavljuje
kao **izgubljen** snimak, ne kao da ga nema — izgubljen snimak prijavljen kao
uspeh je najstariji oblik greške u ovom repozitorijumu.

Otvoreno: faza 3 (slanje, `ffprobe` na serveru, odbijanje nemog snimka), faza 5
(potpis umesto broja taktova — sad se hvata samo dodat ili obrisan takt), i
**brisanje lokalnog snimka kad se tutorijal obriše iz biblioteke**, što još ne
postoji. Alat `tool/spike_recorder` se čuva do provere uživo.

Brojke: **1832 u aplikaciji (1 preskočen)**, mereno na `master` bez ičeg drugog
pokrenutog — 1790 + 28 testova jezgra + 14 testova ekrana. Backend nije diran
(1098). `flutter analyze` na 29 info poruka, bez upozorenja.

---

## ODAKLE SUTRA — 10.9.2026, video i snimanje

**Sutra počinje faza 1 iz `docs/PLAN-SNIMANJE.md`** — ekran za snimanje u
studiju, markeri sa audio clock-a i lokalno preslušavanje. Faza 0 je zatvorena
noćas i njen odgovor je jednoznačan; ne treba je ponavljati.

### Šta je odlučeno u fazi 0, da se ne otvara ponovo

`record` 7.1.1, `startStream` sa `AudioEncoder.pcm16bits`, 16 kHz mono, i
**marker = bajtovi ÷ byte rate**. Paket **nema nijedan API za poziciju**, pa ono
što je plan zvao rezervnim rešenjem jeste rešenje.

Izmereno na Androidu 15 i na Windowsu 11, sa glasom vlasnika:

* zagrevanje mikrofona: 750 ms na Androidu; na Windowsu **668 ms pa 100 ms** —
  ista mašina, isti kod, par minuta razmaka. **Nije konstanta**, pa se ne može
  ispraviti fiksnim pomerajem; zato je jedino ispravno čitanje ono iz samog
  zvuka.
* `pause()` zaustavlja i zvučni sat: 0 bajtova posle pauze na Windowsu, jedan
  paket (80 ms) na Androidu.
* posle jedne pauze od tri sekunde zidni sat je **2,6 s (Android) odnosno
  3,0 s (Windows) ispred** i tu ostaje — to je tačno greška koju bi svaki
  marker uzet iz `DateTime.now()` nosio do kraja snimka.
* `ffprobe` se tri puta složio sa bajt-satom **u milisekundu** (12480/12.480000,
  11928/11.928063, 12008/12.008063).

Dve stvari koje su koštale vremena i neće ponovo:

**Windows traži Visual Studio Build Tools 2022.** `record_windows` hoće CMake
3.23, a Build Tools 2019 nose 3.20 — i dok je zavisnost u `pubspec.yaml`, **pada
ceo Windows build**, ne samo plugin. Posle instalacije 2022 prvi build i dalje
pada na starom CMake kešu („generator Visual Studio 17 2022 does not match …
16 2019"); briše se `build/windows` i to je cela popravka.

**Sat radi i kad zvuka nema.** Windows snimak je bio savršena tišina (−91 dB) uz
besprekoran bajt-sat, tačan wav zaglavlje i tačan `ffprobe` — mikrofon je bio
mutiran na nivou sistema, a ništa to nije reklo: `hasPermission` je vraćao
`true`, uređaj je bio na spisku, paketi su stizali. Snimanje kroz `ffmpeg`
(DirectShow, bez Fluttera) dalo je istu tišinu. Zato faza 2 dobija pravilo:
gledati `onAmplitudeChanged` tokom snimanja, reći kad se ništa ne čuje, i
odbiti slanje snimka koji nikad nije prešao prag tišine.

`chess_app/tool/spike_recorder/main.dart` se sam pokreće i sam izlazi; čuva se
dok faza 1 ne bude gotova, jer je to način da se Windows strana ponovo proveri
posle svake promene alata.

### Šta je od danas u kodu, a nije viđeno uživo

Sve četiri stvari su merene i testirane, nijedna nije gledana kako radi:

1. **Prekid napuštenog rendera** (stavka 134). Klijent ode, crtanje staje,
   ffmpeg i piper se ubijaju, polufajl se briše, slot se vraća **odmah**.
   Lokalno provereno pravim socketom; na dropletu vezu zatvara nginx i to je
   jedini deo koji lokalno ne može da se proveri.
2. **Pregled pre renderovanja** (stavka 135) — tri slike, bez ffmpeg-a, bez
   mesta u redu, bez kvote.
3. **Tutorijal pamti svoj film** (stavka 136) — jedan video po tutorijalu,
   dugme za preuzimanje na redu u „Sačuvani tutorijali", svež link na zahtev.
4. **Pravednost reda** (stavka 137) — round-robin po nalogu i najviše dva filma
   po nalogu. **Ovo je bio živ kvar**: jedan trener sa tri izvoza je punio red i
   svi ostali su dobijali 429.

Za proveru postoje gotovi fixture-i u `mislisha-test/render-fixtures` (README
tamo ima izmerene brojke i dva PowerShell skripta).

### Brojke na `master` na kraju dana

**1790 u aplikaciji (1 preskočen), 1098 na backendu** sa `.env` sklonjenim u
stranu, `flutter analyze` na 29 info poruka bez ijednog upozorenja. Zavisnost
`record` je unutra i Windows build prolazi sa njom.

### Šta nije rađeno i zašto

Tačke 4 i 5 iz `PLAN-SNIMANJE.md` (odbijanje prevelikog rendera i izlazak
rendera iz zahteva) **nisu počete namerno** — 5 traži posao kao red u bazi, a 4
bez 5 je privremena mera. Deljenje velikog filma na delove i odloženo („noćno")
renderovanje idu uz njih. Redosled i zavisnosti su u tom planu, deo drugi.

---

## ODAKLE SUTRA — 8.9.2026, kraj dana

**Prvo pročitati `docs/PLAN-ZAVRSNICA.md`.** To je zamrznut obim za završetak
projekta, sa šest faza i četiri izričita izuzeća, i sve ispod je stanje unutar
njega.

### Gde smo

| | |
|---|---|
| aplikacija | **1762 testa, 1 preskočen** |
| backend | **964 testa**, sa `.env` sklonjenim u stranu |
| `flutter analyze` | 29 `info`, nijedno upozorenje, nijedna greška |
| grana | `master`, pushovana 8.9.2026 |
| srpski u `lib/` | **nema ga** — `gate_english_ui` čist nad svih 258 fajlova |
| srpski na serveru | **nema ga u rečenicama koje idu na ekran** — 66a i 66b, 71 fajl; ostaju logovi, komentari, `routes/consent.js`, roditeljski mejl i vrednosti uloga |

Faza 1 (zamrzavanje + dva reza) i faza 2 (jezgro videa) su gotove, i
**engleski zaokret je zatvoren 8.9.2026**: batch-evi 62–65b spojeni, `docs/gates/`
prazan, srpska sidra obrisana. Sledeće je **faza 4 — priručnik i sajt**, na
engleskom, pisan po glosaru.

Nedovršeno iz faze 2 i dalje stoji: renderer ne crta natpis, strelice ni polja.
To je batch koji dolazi posle priručnika ili pre njega, po izboru.

### Šta je odlučeno danas i ne otvara se ponovo

1. **Aplikacija ide isključivo na engleski**, bez i18n sloja — zamena u mestu.
   Ugovor je `docs/GLOSSARY-EN.md`.
2. **Tutorial** je ono što trener piše; **Session** je živi susret u sobi.
   Nikad „Lesson" na ekranu — u kodu ta reč znači artefakt (`saved_lessons`,
   `LessonStep`).
3. **Trainer**, ne Coach. Šema kaže trainer u svakom identifikatoru.
4. **Tekst se obraća igraču, učeniku i treneru — nikad detetu**, osim gde je
   funkcija izričito o roditeljskom nadzoru.
5. **General Audience, 13+**, ne „namenjeno deci". Ispod 13 nema naloga —
   `MINIMUM_AGE` odbija na ruti i na ekranu i **ne upisuje godinu**.
   Roditeljski tok time pokriva 13–15 u zemljama sa pragom iznad 13.
6. **Ekrani**: Room, Preparation, Analysis, Tutorial Studio. Reč „studio"
   imenuje jedan ekran.
7. `docs/politika-privatnosti.md` ostaje srpska i netaknuta; engleska je nov
   fajl (`docs/privacy-policy-en.md`) u fazi 4; advokatska provera je
   **eksterna kapija na izlasku**.

### Šta je sledeće, po redu

**Batch 65 je podeljen na tri dela, i prvi je već gotov.** Merenje 8.9.2026:
516 linija u 87 fajlova — trostruko više nego batch 64, koji je sa 26 fajlova
istrošio ceo budžet. Podela ide po rečniku, ne po veličini.

**Gotovo — vođin deo, commit `b694d3b`.** `core/services/tactical_motif_detector.dart`
i `core/services/positional_evaluator_service.dart` (28 literala) nisu tekst nego
**generator rečenica**: rod po figuri, nominativ i akuzativ za svaku, genitiv za
pridev boje, tri oblika množine za broj, i srpsko nabrajanje sa „i". Engleski ne
traži ništa od toga, pa je mašinerija obrisana a ne prevedena. Isto pravilo kao
batch 59 i 61: batch kome se da fajl koji traži refaktor je batch koji ima na
čemu da pogreši. Suite ostao 1772, analyze 29.

Iz njega jedna lekcija koja važi za oba preostala batch-a: **pet asercija u
testovima nije imalo nijedno naše slovo** — `contains('Beli')`,
`contains('otvorenu')`, `contains('je otvorena')` — pa ih `gate_english_ui`
nikad ne bi imenovao; našao ih je samo suite. Kad se menja string, grepuje se
**stara srpska reč**, ne dijakritik.

**Gotovo — batch 65a, spojen kao `c93deb8`.** 29 fajlova, 268 linija
(`features/analysis_studio`, `widgets/ai_studio`, `features/position_scanner`),
plus 17 test fajlova. **Svih jedanaest kapija zeleno iz prve runde**, prvi put u
ovoj seriji; 48 minuta od 75. Premereno na `master` bez ičega drugog u pozadini:
1772 testa i 1 preskočen, 29 `info`, nula upozorenja i grešaka, i tačno **220
srpskih literala** ostalo u `lib/` — što je do slova obim 65b, pa batch nije
izašao iz svog spiska.

Tri stvari iz njega. **Kad batch dodiruje jedan kraj rečnika čiji je drugi kraj
već napisan, taj napisani kraj se prepisuje u brief** — brief je nosio drugu
tabelu od 21 termina koji su **već otišli u kod** (fork, pin, skewer, outpost,
bishop pair…), jer dva panela imenuju iste motive koje generator rečenica
ispisuje; sva 21 su se vratila tačna. **Prevod ume da proširi matcher a da to
niko nije odlučio** — `contains('slika')` nije podniz od `slike`, ali
`contains('image')` jeste podniz od `images`; mutacija (zamena dve klasifikacije
skenera) i dalje pada, na susednom testu, pa nije menjano — ali to je rekla samo
mutacija. I **test za množinu se preimenuje, ne skraćuje**: `gamesLabel` je
zadržao svih osam ulaza, pa brojka nije pala kao kod batch-a 64.

**Treći izveštaj zaredom sa tačnim brojevima i izmišljenom sekcijom.** Sekcije
5.3 i 5.5 citiraju rečenice kojih nema ni u diffu ni u stablu — poruka skenera o
„slabom osvetljenju ili mutnoj slici" za funkciju koja čita **dijagrame složene
fontom, nikad sliku**, i četiri izmišljena imena otvaranja pored četiri prava.
Sekcija 3 je podmuklija i poučnija: njena tabela po fajlu je poštena računica
(zbir 558 je tačno `git diff --numstat` dodatih linija) pod pogrešnim imenom
(„prevedeni literali"), gde je pravi broj 268. **Tačan broj pod lažnim imenom
teže se hvata od izmišljenog.**

**Sledeće — batch 65b**, ostatak, 54 fajla i 220 linija: `features/archive` (59),
`lib/widgets` van `ai_studio` (52), `features/groups` (24), `lib/services` (29),
`features/trainer_panel`, `library`, `reviews`, `theme`, `routing`, `core`.
Brief se piše po uzoru na 65a.

Uz 65b ide i jedno čišćenje: **`lib/core/services/serbian_plural.dart` više
nema nijednog pozivaoca u `lib/`** — briše se sa svoja dva test fajla kad ode i
poslednji srpski.

**Kad 65b prođe:** oba sidra iz `docs/gates/` (`vocabulary_en_test.dart`,
`screen_names_en_test.dart`) prelaze u `test/`, a srpski `tutorial_vocabulary_test.dart`
i `screen_names_test.dart` se brišu. Tek tada počinje **faza 4 — priručnik i
sajt**, na engleskom, pisan po glosaru.

Posle toga: **faza 5** (trijaža 1037 stavki provere u tri gomile — zastarelo,
viđeno, stvarno neprovereno) i **faza 6** (objavljivanje).

Nedovršeno iz faze 2: renderer još ne crta natpis, strelice ni polja — to je
batch koji dolazi posle prevoda. Jezgro (`tutorialVideoOf`) je gotovo i
gejtovano.

### Šta o workeru mora da se zna

**Dva runda su izgubljena na workera koji je ponavljao „čekam da se testovi
završe", i uzrok je sada utvrđen — bila je mreža.** Prvo je zapisano kao
„`gemini-3.8-flash-high` ne ume da čeka potproces"; vlasnik je to ispravio
8.9.2026 — pala mu je internet konekcija. **Batch 65a je presudio istog dana**:
ispisuje istih devet „pustio sam ceo suite i čekam" rečenica — i onda se vrati
sa brojem, za 48 minuta od 75, sa svih jedanaest kapija zelenih. Na ispravnoj
vezi model sasvim uredno čeka potproces. Pouka je o vođi, ne o workeru: **zastoj
ima i okruženje a ne samo model, a imenovati model je jeftinija priča, ne i
verovatnija.**

Ono što ne zavisi od toga koje je tačno: **batch se brifuje tako da mu treba
najviše jedno puštanje celog suite-a, na kraju.** Batch 64 je dobio nalog da
pusti testove posle svakog od dvadeset šest fajlova, a dvadeset šest puštanja
po tri minuta je sedamdeset osam — više od celog budžeta, pre nego što model
išta pomisli. Taj nalog je bio moj i povučen je zbog računice, ne zbog
dijagnoze.

Persona za prevod je `flutter_translator` (`.agents/agents/`), napisana jer
`flutter_copy_sweeper` traži tabelu odlučenih zamena a `flutter_feature_builder`
sme da dira srpski tekst.

**Dozvole se pišu pre puštanja**, u `orchestrate.py`: `untracked` za izveštaj po
imenu i `translated` za svaki fajl pojedinačno. Peti put da `worktree` obori
posao koji je task sam tražio.

**Izveštaji su dva puta imali tačne brojeve i po jednu izmišljenu sekciju.**
Ocenjuje mašina; izveštaj je dokaz koji se čita, ne presuda.

### Nove kapije u harnessu (van repoa, `mislisha-test/orchestrator`)

* `english ui` — nijedno naše slovo u literalu pod `chess_app/lib`.
* `npm test` — backend suite sa `.env` sklonjenim, preskače se kad batch nije
  dirao `chess_backend/`.
* `gate_strings` ima `allow_translated` — jedina dozvola koja se sklanja umesto
  da preusmeri.
* `gate_contrast` sada uzima `baseline` i ne naplaćuje linije koje batch nije
  napisao.

### Glas je posle zaokreta bio nem — popravljeno 8.9.2026

`SpeechService.preferredLanguages` je i posle prelaska na engleski tražio
`['sr', 'hr', 'bs', 'sh', 'me']`, a nikad ne pada na nesrodan jezik — namerno,
jer engleski glas koji čita srpski ne pukne nego zvuči kao da funkcioniše.
Posledica: na običnoj engleskoj mašini stanje je `noVoice`, pa **nijedno dugme
za čitanje naglas u aplikaciji ništa ne kaže**, uključujući pripovedanje
tutorijala. Sada traži `en`, a `fitsSerbian` je `fitsAppLanguage`.

**Nijedan test to nije mogao da vidi, i to je pouka.** Svaki test u
`speech_service_test.dart`, `lesson_narration_test.dart`,
`govor_na_panelima_test.dart`, `tutorial_branching_test.dart` i
`phase0_widgets_test.dart` dodavao je servisu lažni motor koji prijavljuje
`['sr-RS']` — pretpostavka je bila ušivena u fixture. Najjači primer je
`VoicelessTts`, koji je vraćao `['en-US']` **da bi značio „nema glasa"**; sada
vraća `['de-DE']`. Nađeno je po log liniji u ispisu jednog test rana
(„Nema srpskog glasa. Instalirano: en-US"), a ne po testu.

Vlasnikovo pravilo, zapisano doslovno jer određuje oblik: *drugi jezik može da
bude samo mesto koje je korisnik napravio — repertoar, tutorijal, komentar. Ako
se to čita kroz TTS, ne sme kroz `en-*`, nego kroz servis za taj jezik. Srpski
nam nigde ne treba po defaultu.* Polovina po defaultu je gore popravljena;
polovina po artefaktu je **svesno odložena** i upisana u
`docs/PLAN-ZAVRSNICA.md` — današnji odgovor je izbor glasa u Podešavanjima,
koji važi za sve odjednom.

Suite 1773 (jedan test više nego 1772: dva stara slučaja o srpskom glasu
zamenjena sa tri o engleskom), analyze 29.

### Server je progovorio engleski — batch 66a, 8.9.2026

Vlasnik je na čistom buildu pročitao „učenik 2 želi da vas upiše kao
učenika". **Server šalje rečenice na ekran**, a svaki brief u ovom zaokretu je
govorio „ne diraj chess_backend" — što je bilo tačno za te batch-eve i to je
ovo sakrilo. Merenje: 847 srpskih linija u 79 produkcionih fajlova.

**66a je spojen** (`a5fc057`): 30 fajlova, 278 literala, 9 backend testova.
`npm test` 964, `flutter test` 1762 — oba nepromenjena.

### I šahovska polovina — batch 66b, 9.9.2026

**66b je spojen** (`8218c59`): 41 fajl, 466 linija, 12 test fajlova, svih
dvanaest gate-ova zeleno iz prve. `npm test` 964, `flutter test` 1762 sa jednim
preskočenim, analyze 29 — sve nepromenjeno, jer batch nije dirao Dart.
**Time nijedna srpska rečenica više ne postoji nigde odakle server može da je
pošalje na ekran.**

Brojka „281 linija u 41 fajlu" iz prethodnog pasusa **bila je pogrešna** i
ispravljena je pre briefa: nije brojala ni `.mjs` fajlove (skener je ESM, jer
pdfjs nema CommonJS build) ni bilo šta unutar template literala koji se prelama
u više redova. Tačna mera je 466 linija — 331 u jednorednim literalima i 135
unutar sedam prelomljenih šablona.

**Tri fajla nisu bila prevod.** `geminiService.js` je izgubio parametar
`userLanguage = 'sr'` i svaku `isSr` granu — engleska aplikacija je tražila od
modela srpski, i sama slala `'sr'` kao podrazumevano; oba prompta su sada
engleska i traže engleski. `services/prepNarrative.js` je prompt iza kojeg stoji
`narrativeGuard`, pa je svaki broj i svako pravilo o procentima prenet doslovno.
`services/endgameCatalog.js` je bio gramatička mašina — nominativ, genitiv i
množinska osnova, jer srpski traži padež posle „protiv"; engleski traži množinu,
pa se dve tablice spajaju u jednu i `labelOf('KRPPvKR')` sada čita
`rook and two pawns versus rook`. Nijedan ulaz iz testa nije izgubljen, samo su
očekivanja preimenovana.

**Tri niske su bile ugovor sa aplikacijom, ne tekst, i vođa ih je pomerio
unapred** (`9b786a2`), u istom commitu sa oba kraja: `reason` iz
`customPuzzleJudge.js` (aplikacija poredi „drugi mat, ali mat", a *netačne*
verdikte crta detetu doslovno) i tri vrednosti `sideSource` iz
`positionScanner/verify.mjs` (`needsReview` gori na `'nepoznato'` — prevod te
jedne reči prestao bi da označava svaku poziciju kojoj se ne zna strana na
potezu, tiho, uz zeleno oba paketa testova).

**Dve pouke o harnessu iz ovog batch-a:**

* `gate_english_backend` je gledao `` `[^`
]*` `` — bez novog reda — pa
  **prelomljen template literal nije video uopšte**. Tri najveća srpska bloka u
  66b su baš takvog oblika: HTML roditeljskog izveštaja (55 redova) i dva
  prompta (36 i 23). Popravljeno i dokazano mutacijom u oba smera.
* `test/repertoire_route_wiring.test.js` čita rute kao tekst i nije umeo da
  razlikuje parametar od reči u poruci. Batch je oboren zbog ispravne engleske
  rečenice „Could not read color status." u `/color` ruti i **preformulisao je
  poruke da prođe** — a gori je lažni prolaz koji je tu stajao od početka:
  parametar koji se pročita iz zahteva i nigde ne prosledi računa se kao
  upotrebljen čim ga bilo koja poruka pomene, što je tačno bug zbog kojeg taj
  fajl postoji. Popravljeno (`bccc04e`), dokazano mutacijom, poruke vraćene.

**Tri stvari su trajno van obima, sa razlogom:** `routes/consent.js` i
roditeljski mejl u `services/mailService.js` nose formulaciju koju je advokat
odobrio za Srbiju 25.8.2026 — engleska verzija je dokument iz faze 4 sa
spoljnom proverom; `db.js` je šema; a **vrednosti uloga** (`'trener'`,
`'ucenik'`, `'korisnik'`, `'host'`, `'admin'`, `'user'`) žive u CHECK
ograničenju baze i aplikacija grana po njima na 25 mesta. Preimenovanje toga je
migracija kroz šemu, server, socket i aplikaciju — nije prevod.

**Što batch ne može da popravi, i rečeno je unapred:** `user_notifications` je
tabela, pa su poruke sa vlasnikovog snimka **već upisani redovi**. Prevod
generatora menja šta se piše od sada i ništa što postoji. Briše li se to —
vlasnikova odluka, ne posao batch-a.

### Tutorijal je postao video — faza 2 zatvorena, 9.9.2026

**Sva četiri dela faze 2 su gotova.** Jezgro (`tutorialVideoOf`, `dwellSecondsFor`)
je bilo gotovo ranije; 9.9.2026 su došla preostala dva.

**Renderer crta ono što se uči** (`401ad0f`, vođa). `videoRenderer.js` sada prima
`caption`, `arrows`, `squares` i `orientation` po događaju. `[%csl]` se crta kao
ista tri prstena kao u aplikaciji — crni oreol, beli oreol, boja — jer to je ono
što se čita i na svetlom i na tamnom polju, a puno polje bi sakrilo figuru o
kojoj se priča. Pet boja je prepisano po vrednosti iz `arrow_colors.dart`, a
nepoznat kod ostaje siv: zeleno ovde **znači** nešto.

**Traka za rečenicu meri se jednom za ceo film** i tabla se smanjuje oko nje —
visina po kadru bi tablu terala da raste i da se smanjuje između dve rečenice.
Film bez ijedne rečenice ne rezerviše ništa i dobija geometriju koju je renderer
oduvek crtao; izvoz snimka je proveren uživo i ne sme da se pomeri ni za piksel.

**Dva kvara su bila u svakom ikada renderovanom izvozu**, i našao ih je jedan
probni kadar: naslov je nosio `♟`, koji nijedan font na tom serveru nema, pa je
svaki kadar prikazivao praznu kutijicu; i **nijedno slovo kolone nikada nije
nacrtano** — bila su obojena bojom polja na kome stoje, osam puta zaredom, jer
je parnost koja važi za redove obrnuta za kolone a izraz je bio jedan.

**Izvoz i vrata** (`0c9cb0f`, batch 67): `POST /lessons/:id/export-video` pored
izvoza snimka, i treća ikonica u spisku sačuvanih tutorijala. Ruta proverava
pravo pre bilo kakvog posla, razrešava red uslovom `(user_id = $2 OR trainer_id
= $2)`, seče trajanje na 3600 umesto da odbije, i knjiži potrošnju tek pošto je
render uspeo. Preuzimanje ide kroz **postojeću** rutu snimaka — jedno mesto koje
mora da brani `exports/` lakše je držati ispravnim nego dva.

Tri stvari iz ocenjivanja, dve od njih ispravke moje prve dijagnoze:

* Probni test na 360 dp našao je prelivanje od 88 px. **Pročitao sam ga
  pogrešno** kao tri ikonice u redu i zbio ih; merenje je pokazalo da je red bio
  u redu, a da se prelivao dijalog „Video ready!", čiji je naslov u headline
  veličini tražio 320 dp od telefonskih 232. Vidi se tek posle klika, pa ga
  nijedan test koji staje na redu ne može videti.
* **Naslov bez elipse zaista gura akcije preko ivice** — tutorijal se imenuje
  svojom prvom rečenicom, pa `'Opozicija'` nije bio pošten uzorak.
* **Test napisan za sve to nije dokazivao ništa, dvaput.** `takeException`
  prolazi i sa vraćenim prelivanjem; pitanje o redu u mirovanju promašuje
  dijalog do kog se stiže klikom. Sada meri da li je svako dugme unutar
  dijaloga, na redu sa dugim naslovom, i obe popravke su mutirane da se vidi
  kako pada.

Ostaje **provera uživo** — stavka 133 u `docs/TODO-provera.md`.

### Otvoreno, nije rađeno

* Tri pitanja o dizajnu iz prijava od 7.9.2026: orijentacija kao svojstvo niza
  taktova, jedan tip zadatka po taktu, i komentar pre *i* posle poteza.
* Prijava `n1788823148283`: organizacija ekrana. Uski zahvat je urađen (jedan
  dijalog, imena); širi — jedno mesto za sve što aplikacija proizvodi — je
  izričito van obima i odgovara mu priručnik iz faze 4.
* Nove stavke provere uživo: **123–133** u `docs/TODO-provera.md`. Stavka 132
  je najveća: 71 fajl prevedenog servera nije viđen na ekranu ni jednom.
  Stavka 133 je video tutorijala — renderovanje je dokazano, dugme nije.

---

## Jedan trener više ne zauzima celu mašinu — 9.9.2026

Bio je **živ kvar, ne budući**: sa `RENDER_CONCURRENCY` 1 i `RENDER_QUEUE_MAX`
2 staju tri renderovanja, pa je jedan trener sa tri pritiska na „Export" punio
red, a svi ostali su dobijali 429 dok se ne isprazni. FIFO ne zna ko pita.

Dva pravila, i odgovaraju na različita pitanja. **Round-robin** odlučuje o
redosledu: sledeći film je onog naloga koji najduže nije bio na redu — pa
dvanaest delova jednog velikog tutorijala ne mogu da preteknu kratak film koji
je stigao kasnije. **`RENDER_ACCOUNT_MAX`** (podrazumevano 2) odlučuje o
prijemu: dva filma po nalogu, jedan koji se crta i jedan koji čeka. Posao bez
naloga je sam sebi grupa, da ne bi slučajno blokirao nešto sa čim nema veze.

Tri stvari vredi zapamtiti.

**Broj koji trener vidi mora da bude broj koji se obistini.** Objavljivati
indeks u nizu bilo je tačno dok je red bio „ko pre devojci", i postalo je laž
čim više nije — mesto se sada računa igranjem pravila unapred nad kopijom reda.
Uz to, posao se obaveštava **samo kad mu se mesto stvarno promeni**.

**Dva odbijanja traže dve rečenice.** „Server trenutno renderuje druge videe" je
neistina kad su ti drugi videi tvoji; trener tako čeka pogrešnu stvar.
`RenderAccountBusy` je zato zaseban tip, i ruta na njega odgovara drugom
rečenicom.

**Mutacija je prijavila „preživela" a zapravo je visila.** Brisanje ograničenja
po nalogu ne obara treći render — ono ga *stavlja u red*, pa se `assert.rejects`
nikad ne razreši i fajl istekne. Svaki test odbijanja sada trka sa rokom. Drugi
put u jednom danu: test koji visi je gori od testa koji padne.

Brojke: **1098 na backendu**; aplikacija nije dirana.

---

## Snimanje glasa i red za renderovanje — plan, 9.9.2026

`docs/PLAN-SNIMANJE.md`, u dva dela. **Prvi**: trener sam snima svoj glas u
aplikaciji, klijent hvata markere **sa audio clock-a rekordera** (ne sa
`DateTime.now()`, jer to klizi progresivno), lokalno preslušava, i tek na izvoz
šalje gotov fajl — pa server samo muxuje kroz `ffmpegArgsFor`, bez pipera.
Snimak je vezan za potpis liste taktova (`treeSignature` obrazac), jer izmena
lekcije razvezuje markere u tišini. Piper ostaje kao fallback.

**Drugi deo** su tačke 4 i 5 sa iste liste — odbijanje renderovanja koje ne
može da stane u vezu, i izlazak rendera iz zahteva (202 + posao u bazi) — i
vlasnikov hibrid: odloženo renderovanje „preko noći", **deljenje velikog filma
na delove** (što daje tačke prekida, pa mali film čeka jedan deo umesto celog
filma) i **round-robin po nalogu**, jer danas jedan korisnik sa tri izvoza puni
red i svi ostali dobijaju 429.

---

## Tutorijal pamti svoj film — 9.9.2026

Pitanje vlasnika: „ako ne downloaduje odmah video, kako može to da uradi
kasnije?" Do ovoga — **nikako.** Token za preuzimanje traje trideset minuta,
link je postojao samo u odgovoru na izvoz i nigde se nije čuvao; ko zatvori
dijalog „Video ready!" morao je da renderuje ceo film ponovo, dok je fajl stajao
u `exports/` četrnaest dana, nedohvatljiv, dok ga retencija ne obriše. Deset
izvoza jednog tutorijala bilo je deset siročića.

`saved_lessons` sada nosi `video_filename`, `video_rendered_at`,
`video_resolution`, `video_seconds` i `video_narrated`, a `GET
/lessons/:id/video` **kuje svež link** kad neko pita. U aplikaciji je to ikonica
za preuzimanje na redu u „Sačuvani tutorijali", i crta se **samo tamo gde film
postoji** — akcija ponuđena na redu koji je ne može izvršiti je najčešća greška
u ovom repozitorijumu.

Četiri pravila iz toga:

**Ime fajla, ne URL.** URL nosi token, a sačuvan token je token koji nadživi
svoje isticanje: pola sata posle izvoza to je link koji vraća 401, čuvan
četrnaest dana.

**Red se upisuje pre nego što se stari fajl obriše.** Pad između to dvoje
ostavlja fajl na koji niko ne pokazuje — njega retencija pokupi; obrnut redosled
ostavlja red koji imenuje fajl kojeg nema, a to je trener koji pritisne
„Download" i ne dobije ništa.

**Retencija briše i novu kolonu.** Inače lista crta dugme na redu čiji je fajl
taj isti prolaz upravo obrisao, pa bi odgovor „film je obrisan" — koji postoji
za prozor između to dvoje — postao redovno stanje.

**Tri odgovora se razlikuju:** nema filma (404), film je bio pa ga je retencija
uzela (410, „izvezi ponovo"), ili evo ga (200). Vode trenera na različita
dugmad, pa ne smeju da glase isto.

Jedna pouka o starom testu: `retention.test.js` je tvrdio `queries.length === 1`
— tvrdnja o **obliku** prolaza, a ne o tome šta briše, i netačna čim druga
tabela zapamti ime fajla. Sada svoj upit traži po imenu.

Brojke: **1790 u aplikaciji (1 preskočen), 1090 na backendu.** Ostaje stavka
**136** u `docs/TODO-provera.md`.

---

## Pregled pre renderovanja — 9.9.2026

Pitanje vlasnika: „da li ima smisla uvesti preview da ne bi korisnik renderovao
samo da bi video kako izgleda video". Da, i to je najjeftinija stvar na spisku:
`renderFrameBuffer` crta jedan kadar **bez ffmpeg-a**, pa pregled ne troši ni
mesto u redu, ni fajl, ni kvotu.

`POST /lessons/:id/preview-frames` vraća do četiri PNG-a u base64. Podrazumevano
tri — početak, sredina i kraj — jer su to tri pitanja koja trener ima: kako film
počinje, kako izgleda običan takt sa rečenicom i strelicama, i gde ostavlja
dete. U aplikaciji je dugme **„Preview"** u dijalogu za izvoz, pored „Export":
tu je trener već izabrao rezoluciju i naraciju, pa je to jedino mesto gde
pregled odgovara na pravo pitanje.

**To nije drugo crtanje.** Isti `applyEvent` koji koristi petlja renderera, isti
`renderFrameBuffer`, isti raspored natpisa — inače bi pregled bio slika filma
koji niko neće dobiti.

Dve stvari koje su testovi našli, i obe su o tome šta test ume da vidi.

**Tri kadra su se razlikovala po satu, ne po tabli.** Mutacija „uvek crtaj takt
0" je prošla pored tvrdnje „kadrovi su različiti", jer sat u uglu piše 00:00,
00:04, 00:09. Dodat je test u kome svi taktovi imaju **isti** `timestampMs`, pa
je svaka razlika nužno pozicija. Ista porodica kao slova ispod table na koja su
odgovorile figure sa prvog reda.

**Komentar je tvrdio više nego što kod radi.** Napisao sam da je traka natpisa
„visoka koliko najduža rečenica u filmu"; `renderFrameBuffer` je čita samo kao
`captionBand > 0`. Pravilo koje stvarno postoji — i koje se testira — jeste da
se **takt bez teksta unutar filma koji govori** ipak crta sa kolonom za natpis.
Test koji je pao je ono što je našlo preterivanje.

Ostaje: stavka **135** u `docs/TODO-provera.md`.

---

## Render koji je klijent napustio se prekida — 9.9.2026

**Nalaz je izmeren, ne pretpostavljen.** Za brzo pravljenje velikih tutorijala
napravljen je set fixtura (`mislisha-test/render-fixtures`, u QA folderu van
gita) i format za LLM (`docs/PGN-TUTORIAL-FORMAT.md`). Sa njima su ispaljena
četiri istovremena renderovanja na lokalni backend, pa jedno preveliko sa
klijentskim tajmautom od 300 s — koliko nginx daje proksiranom zahtevu na
dropletu (`deploy/app-setup.sh`).

Red je odradio svoje: četvrti zahtev je odbijen za **0,9 s**, pre ijednog
nacrtanog frejma, a tri koja su stala u red su završila na 16,0 / 31,4 / 52,1 s.
Ali film od 36 minuta je pokazao rupu: klijent je odustao na 300,1 s, a **server
je nastavio da crta**, napisao MP4 od 14,4 MB čiji je link za preuzimanje bio u
odgovoru koji niko nije primio — i, što je gore, **držao jedini slot za
renderovanje do kraja tog filma**. Svaki drugi trener u tom prozoru čekao je iza
filma koji niko neće pokupiti, ili je dobijao 429.

To je tačno ona rečenica zbog koje `services/renderQueue.js` i postoji.
`RENDER_QUEUE_MAX` ograničava **red**; ne kaže ništa o jednom renderu koji
nadživi svoju vezu. Nigde u lancu nije bilo obrade prekinute veze — ni
`routes/lessons.js`, ni `renderQueue.js`, ni `videoRenderer.js`.

### Rešenje

`services/renderAbort.js`, jedan `AbortSignal` provučen kroz ceo lanac:

* `abortOnDisconnect(res)` sluša `res.on('close')` i pali signal **samo ako
  `writableFinished` nije tačno**. To je cela ispravnost tog mesta: i uspešan
  odgovor emituje `close`, pa bi slušalac bez tog pitanja gasio svaki render u
  trenutku kad uspe — bezopasno danas samo zato što tada ništa više ne radi.
* `videoRenderer` proverava signal na vrhu frejm-petlje (koja ionako popušta
  event loop jednom po frejmu), ubija ffmpeg sa **SIGKILL** i briše polufajl.
  SIGTERM ne valja: ffmpeg zamoljen lepo dovrši fajl koji ovo baš i sprečava.
* Narracija je unutar reda zajedno sa crtanjem, pa i ona mora da stane:
  `narrateFilm` → `tts.speakBeats` → `piper.run` ubija piper proces, a
  `narrationTrack` svoj ffmpeg; polu-napisan `.wav` u `exports/` se briše.
  `speakBeats` je do sada gutao svaku grešku sinteze (film bez glasa je i dalje
  film) — **prekid je jedini izuzetak**, jer bi inače nastavio da crta ceo nemi
  film za klijenta koga nema.
* Ruta ne šalje odgovor (socket je zatvoren), **ne knjiži potrošnju** i vraća
  slot. Trener nije dobio film, pa ništa nije ni naplaćeno.

Živa provera, pravi socket i pravi ffmpeg (`render-fixtures/abort-live-check.js`):
klijent prekida na 3,0 s, server javlja prekid na 3,5 s, fajl obrisan, red na
`{running: 0, waiting: 0}`, **sledeći posao krenuo za 0,00 s**.

### Šta su testovi pokazali, a šta nisu

`test/render_abort.test.js`, 11 testova, ffmpeg lažiran kao u
`render_yields.test.js`. **Backend suite: 1069, sve zelene**, sa `.env` sklonjen
u stranu (1058 pre ovoga). Aplikacija nije dirana.

Devet mutacija je uhvaćeno; dve su preživele i obe su nešto naučile.

**Dve provere u istoj petlji ne mogu da se dokažu.** Brisanje provere na vrhu
petlje ostavljalo je suite zelenim — jer je druga, pred samim upisom frejma,
zaustavljala render, i obrnuto. Ostala je **jedna** provera, koja sada pada na
mutaciju („5 frejmova u trenutku odbijanja, 12 sada"); cena je jedan frejm
viška kad prekid stigne usred crtanja. Provera koju nijedna mutacija ne može da
dosegne je provera za koju niko ne zna da radi.

**Prva verzija testa nije umela da vidi da petlja i dalje crta.** Brojala je
frejmove u trenutku odbijanja obećanja — a između `kill` i odbijanja prođu dva
turnusa, pa je i petlja koja prekid potpuno ignoriše tada tek nekoliko frejmova
dalje. Sada se broji dvaput, sa pauzom između.

**Test koji visi umesto da padne.** Mutacija „`killOnAbort` ne ubija" je
zaglavila ceo suite na 300 s bez ijedne poruke. Svako pitanje u ovom fajlu je o
tome da nešto **stane**, a to se kvari tako što se obećanje nikad ne razreši —
zato sada sve ide kroz `withDeadline`.

**Jedna zaštita nije dokazana i to je zapisano u kodu.** `ffmpeg.stdin.on
('error', …)` hvata EPIPE koji pravi ffmpeg digne kad se u njegov stdin upiše
posle `kill` — a `error` na streamu bez slušaoca ruši ceo proces. Lažni ffmpeg
ne ume da pukne kao pravi, pa mutacija koja tu liniju obriše prolazi. Ostaje,
jer je rizik nesimetričan: nedosežna zaštita košta jedan red, njeno odsustvo
košta proces. Živa provera je prošla bez pada.

**Dve postojeće fixture su proširene, tvrdnje nisu dirane.**
`render_yields.test.js` je imao lažni `stdin` bez `on`, a
`tutorial_video_export.test.js` lažni `res` bez `on`/`off` — prvi je visio 60 s,
drugi je vraćao 500 na svaku tvrdnju. Obe su dobile ono što pravi objekat
oduvek ima. („Prolazi bez izmene" je i dalje pogrešna formulacija: tvrdnje su
nepromenjene, fixture su se pomerile.)

### Ostaje

* **Prekid nad TTS lancem nije proveren od kraja do kraja** — traži instaliran
  piper; pokriven je konstrukcijom (`killOnAbort` + `throwIfAborted`), ne
  testom.
* Stavka **134** u `docs/TODO-provera.md` — živa provera na dropletu, gde je
  nginx taj koji zatvara vezu.

---

## Redizajn Studija za tutorijal — P0–P2 gotove, 6.9.2026

Dogovor je [PLAN-STUDIO-REDIZAJN.md](PLAN-STUDIO-REDIZAJN.md), napisan pošto je
vlasnik probao studio iz faza 4a–4c i prijavio četiri problema: ulazak iz
Analize nasleđuje tuđe stanje, postoje dva ekrana za isti posao, nema osećaja
hronologije, i stablo dole desno je skučeno i tehničko.

**Koren je jedan i nije u rasporedu.** Gotov primer se pri „Dodaj sledeću
poziciju" spljošti na `fen` + `pgn` i stablo se baci, a ništa u aplikaciji nije
umelo da pročita `pgn` nazad u `AnalysisNode`. Zato gotov deo nije mogao da se
ponovo otvori — i zato je drugi, slabiji ekran za izmene morao da postoji.
Uklanjanje drugog ekrana nije posao oko rasporeda nego jedan konvertor.

Vlasnik je 6.9.2026 usvojio plan u celosti i razrešio tri otvorene odluke:
**D6** — ostaju oba taba, „Tok" podrazumevan i „Stablo" kao alternativa;
**D7** — „Deo" je jedina reč u autorskim ekranima (stiže sa ekranom u P5, ne
pre, jer bi pomeranje stringova u P1/P2 pokvarilo jedini dokaz da tok nije
promenjen); **D9** — dugme nudi „Nastavi odavde (dete ne vidi novu tablu)" prvo
i podrazumevano, pa „Nova pozicija", uz spojnicu u listi delova.

### Šta je urađeno (P0–P2, sve lead)

* `lib/features/tutorial_studio/services/step_tree.dart` — prelaz sa `MoveNode`
  na `AnalysisNode`, plus `treeSignature`, `copyTree` i `endOfMainLine`.
* `tutorial_draft.dart` napisan iznova: `TutorialChoice`, `TutorialSection` (sa
  stablom, `stepId` i `acceptedSans`) i `TutorialDraft` (sa `lessonId`,
  `selected`, dodavanjem, brisanjem, premeštanjem i kloniranjem delova).
* `TutorialDraftService` čuva jedan objekat umesto nacrta pored radnog stabla, i
  i dalje ume da pročita **stari** oblik slota — trener koji nadogradi usred
  pisanja ne gubi ono što je napisao.
* Ekran je preveden na novi model, **bez ijednog pomerenog stringa za
  korisnika**. To je i dokaz: `test/tutorial_authoring_test.dart` prolazi.

### Merenja i kapije

Kapija je napisana **pre** rada i dokazana sa **sedam mutacija, sve uhvaćene**:
izbačene sporedne varijante (oblik
`_importPgn`), `stepId` prestao da putuje, `acceptedSans` izbačen, netaknuta
linija ipak ponovo izvezena, klon deli stablo umesto da ga kopira, poslednji deo
postao obrisiv, i rečenice trenera izbačene pri čitanju.

**1458 testova u aplikaciji, 1 preskočen, sve zeleno** (bilo 1436), izmereno na
`master`-u sa ničim drugim što radi paralelno. `flutter analyze` i dalje 29
info-a, bez grešaka i upozorenja, i **ništa novo nije prigušeno**. Backend nije
dodirnut i ostaje 956.

### Šta je rad otkrio, a plan nije predvideo

1. **Bajt-identičan povratni put je nemoguć ako se `pgn` uvek ponovo izvozi** —
   `PgnExporterService` upisuje svež `[Date]` u svakom pozivu. Zato se netaknut
   deo vraća kao *tačno onaj tekst koji je pročitan*, a keš se poništava
   poređenjem `treeSignature` sa samim stablom. Namerno nije `bool` zastavica:
   zastavica je verzija ovoga koja otkazuje nečujno.
2. **`acceptedSans` nije postojao u modelu** i to niko nije primetio, jer ništa
   nikada nije čitalo sačuvan korak nazad. Server ga čuva; povratni put bez
   njega bi obrisao trenerove dodatne tačne poteze prvi put kad preimenuje
   tutorijal. Našao ga je bajt-identičan test — zbog toga takav test i postoji.
3. **`pgn` se izostavlja, ne šalje kao `''`.** Serveru je isto (`if (pgn)`), ali
   samo izostavljanje vraća korak koji je sačuvan bez linije — bez linije. To
   izoštrava ispravku iz batch-a 54, ne poništava je.
4. **Kapija iz batch-a E je morala da se dopuni, i to je prošireno a ne
   ublaženo** — piše ovde jer je „prolazi neizmenjena" bila lead-ova sopstvena
   mera. Njen izvorni test je tražio `StudioLessonStep` u fajlu ekrana; P1 je taj
   poziv spustio u `TutorialSection`. Sada čita ceo direktorijum feature-a i pita
   za **import**, ne za identifikator — `contains` nad direktorijumom pogađa i
   komentar, pa bi ga oborio komentar koji objašnjava zašto se izvoznik tu *ne*
   zove.

### P3a — čuvanje, 6.9.2026

`commitDraft` i `LessonWriteResult`: prvi „Sačuvaj" je `POST`, svaki sledeći
`PUT` na isti tutorijal, sa `id`-jem svakog koraka u telu. Stare potpise
`save`/`update` namerno nismo dirali — tri zaštićene kapije lažiraju server tako
što **preklapaju `update`**, pa postoji jedna implementacija i dva oblika.

**Osam mutacija, i dve su razlog što ovo piše ovde.** Jedna je preživela —
„`markSaved` zaboravi sačuvan tekst" — i lako je bilo okriviti mutaciju. Test je
svoj deo napravio kroz `fromStep`, a takav deo je *već* netaknut, pa test nije
mogao da vidi razliku. Prepisan tako da deo pravi rukom, pao je na mutaciju **i
ostao crven** posle te popravke — i tu je izašla prava greška:

**Deo bez poteza nije slao liniju uopšte, pa se gubila beleška o početnoj
poziciji.** `pgnForSave` je sudio delu po broju poteza, a komentar, strelica i
obojeno polje o *mirnoj* poziciji žive na korenu — jedinom mestu gde mogu.
„Pogledaj polje d5" je ceo korak, i `PgnExporterService` je baš zato naučen da
taj komentar upiše ispred prvog poteza. Pisac ga je na izlazu ponovo bacao; dete
je dobijalo golu dijagramu i niko ništa nije rekao. Greška je starija od ovog
plana — nasleđena iz batch-a 54.

Pouka koja se prenosi: **preživela mutacija je pitanje, a ne presuda.** Kaže da
test ne vidi, a ono što ne vidi ponekad nije ono što si mutirao.

Sitnija, ali skupa: `http.Response(String, …)` kodira **latin1** ako tip sadržaja
ne kaže drugačije, pa lažni server nije mogao da ponese „Nađi potez." i pukao je
— a greška je stigla obučena kao „Nije moguće doći do servera.", mrežna greška za
bug u testu. Rečenice ovog servera su srpske; lažni server mora da ume da ih
nosi.

**1473 testa u aplikaciji, 1 preskočen, sve zeleno** (bilo 1458).

### P3b — zašto se ekran otvara, 6.9.2026

`TutorialEntry`, i ekran kome se **mora** reći zašto se otvara. Ovo je prijava 1.1
zatvorena u korenu: ekran je ranije uzimao neobavezan handover i bezuslovno
učitavao jedini slot za nacrt, pa su naziv i svi završeni delovi dolazili natrag
šta god trener tražio.

* **`blank(naziv)`** — ništa se ne preuzima. Ako u slotu nešto stoji, trener se
  pita **imenom**: „Prošli put ste pisali tutorijal „Opozicija“ (3 dela).“
  „Odbaci“ briše slot — nacrt koji je upravo odbijen ne sme da čeka sutra.
* **`saved(lekcija)`** — sačuvan nacrt se preuzima **samo ako mu se `lessonId`
  poklapa**. Nacrt drugog tutorijala je tuđ nedovršen posao: ostaje gde jeste i o
  njemu se ne pita.
* **`fromAnalysis(handover, intoOpenDraft:)`** — dosadašnje ponašanje, sada
  izričito.

**Pitanje sa vrata postavljaju — vrata.** Gde linija treba da ode pita Studio za
analizu, dok trener još gleda tu liniju, pa se odgovor prenosi u `intoOpenDraft`.
Same veze idu u P4; oba ponašanja već postoje i testirana su.

**Jedna postojeća kapija je promenila ono što tvrdi, i to je suština faze.** U
`tutorial_studio_test.dart` dva testa su ponovo otvarala ekran bez argumenta i
očekivala nacrt natrag — u tišini. Sada odgovaraju na pitanje koje ekran
postavlja; sve njihove tvrdnje su nepromenjene i nacrt se i dalje vraća.

**A `tutorial_authoring_test.dart` je tražio još jednu mehaničku izmenu** — jedno
mesto gde pravi ekran, jer se konstruktor promenio. Zajedno sa proširenjem iz P1,
pošteno pravilo glasi uže nego što je zapisano: **sve njegove tvrdnje su
nepromenjene i zelene; pomerila su se dva pomoćna mesta.** Alternativa bi bila
zadržati suvišan drugi način da se ekran otvori samo da se test ne pomeri.

**Pet mutacija, sve uhvaćene.** **1482 testa u aplikaciji, 1 preskočen, sve
zeleno** (bilo 1473).

### P4 — ulaz u studio, 6.9.2026, batch 56

Prvi posao u ovom planu koji je radio radnik (`gemini-3.8-flash-high` kroz
`agy`), jedna runda. Kapija je napisana pre posla — petnaest testova; četrnaest
zelenih iz prve, a petnaesti crven **zato što je bio lead-ov i tvrdio je
neistinu**. Sedam mutacija posle toga, sve uhvaćene.

„Biblioteka“ sada nosi karticu sa „Novi tutorijal“ i „Otvori sačuvani
tutorijal“, tamo gde studio postoji. `TutorialLibraryCard` drži ceo ulaz —
karticu, oba dijaloga i sve stringove — pa se pitanje o platformi rešava na
jednom mestu. Vrata iz Analize pitaju gde linija ide i prosleđuju odgovor kao
`intoOpenDraft`.

**Dva najbolja doprinosa te runde nisu kod.**

Radnik je **prijavio pokvarenu lead-ovu kapiju umesto da je zaobiđe** — što je
tačno ono što je zadatak tražio, i ono što batch 55 nije umeo. Test „pitanje o
platformi ima jedan dom“ izuzimao je `engine_settings_dialog.dart` na putanji
koja ne postoji, i pretpostavljao da je predikat jedino mesto u `lib/` koje pita
za Windows. Pitaju još četiri fajla, s pravom. **Kapija koja imenuje fajl koji
ne postoji ne može da se primeti tako što padne** — ova je primećena samo zato
što je tvrdila i nešto drugo što nije tačno. Sada nabraja šest poznatih domova i
pada na sedmi.

I **brojevi u njegovom izveštaju poklapaju se sa lead-ovim merenjima do
poslednjeg** — uključujući upozorenje analizatora koje je lead promašivao tri
faze.

Jednu odluku koju je brief ostavio otvorenu doneo je ispravno: `fetchAll`
odgovara `[]` i kad je prazno i kad je puklo, a brief je rekao „ako ne možeš da
ih razlikuješ, prijavi“ — što je lead-ov problem ostavljen u briefu. Dodao je
`lastFetchFailed` po uzoru na `cloneError`, koji je imenovan u doc-u te iste
klase: aditivno, bez promene potpisa, nijedan pozivalac nije dirnut.

Lead je posle popravio tri greške koje nijedna kapija ne hvata: nedisponovan
`TextEditingController` u dijalogu za naziv (i **prva lead-ova popravka bila je
gora od greške** — `showDialog` završava na `pop` dok se ruta još animira, pa
`TextField` puca na disponovan kontroler; sada je mali `StatefulWidget`),
razmak koji je pripadao kartici a ne tabu (na telefonu je ostavljao 24 px praznog
prostora na vrhu „Biblioteke“, gde kartice nema), i suvišan
`identical(rawRows, const [])` pored `lastFetchFailed`.

### Tvrdnja o analizatoru koju su P0–P3 promašile

**„29 info-a, bez grešaka i upozorenja“ napisano je tri puta i nije bilo
tačno.** P1 je ostavio neiskorišćen import u `tutorial_studio_test.dart`, i
analizator je od tada prijavljivao upozorenje.

Provera nije mogla da ga vidi: `flutter analyze | grep -cE "^\s+(info|warning|error)"`
— a `flutter analyze` uvlači `info` linije za tri razmaka, dok `warning` piše od
**nulte kolone**. `\s+` traži bar jedan razmak, pa je obrazac brojao 29 info-a i
to proglašavao celom listom: **provera koja ne može da padne nije provera.**
Harness koristi `\s*` i uhvatio ju je na prvoj sledećoj rundi; radnikov izveštaj
je to upozorenje prepisao, stavku po stavku, na vidnom mestu.

Ista porodica kao odsecanje tela funkcije na 1600 znakova i kapija koja je
poklapala komentare. Popravljeno u `30b5fcc`. Sažetak koji `flutter analyze` sam
ispiše — „30 issues found“ — rekao bi to bez ikakvog obrasca.

**1497 testova u aplikaciji, 1 preskočen, sve zeleno** (bilo 1482). 29 info-a,
nula upozorenja i grešaka, mereno obrascem koji ume da ih vidi.

### P5a — panel „Delovi tutorijala", 6.9.2026, batch 57

`gemini-3.8-flash-high`, `flutter_feature_builder`, jedna runda, 24 minuta.
Devet kapija zeleno. **1515 testova u aplikaciji, 1 preskočen** (bilo 1497);
backend nije diran i ostaje na 956.

Ekran koji piše tutorijal do juče je umeo samo da **dodaje**: tekuća lista je
bila četiri reda običnog teksta, a jedino dugme je zatvaralo deo koji se piše i
otvaralo sledeći. `TutorialSectionsPanel` je površina za sve što model već ume —
izbor (tabla, stablo i polja idu za izabranim delom), ▲/▼, kloniranje, brisanje
sa pitanjem, „+ Dodaj deo" sa dva odgovora — i za **spojnicu**, koju autor do
sada nije mogao da vidi: dva dela gde drugi počinje tamo gde se prvom linija
završila su detetu jedna tabla bez učitavanja.

**D7 je delimično ušao ovde, suprotno onome što je ovaj dokument ranije rekao.**
Kada je pisana kapija, „Deo" umesto „Primer" ušlo je **u ovaj ekran i nigde
drugde**, jer panel je površina koja imenuje deo i besmisleno je da se zove
jedno a piše drugo. Ostatak D7 — svaka druga pojava te reči — i dalje je poseban
batch sa tabelom, po uzoru na batch 51.

**Izveštaj radnika je treći uzastopni čist.** Brojevi se poklapaju sa lead-ovim
merenjima do stavke, a i ono što nijedna tvrdnja u kapiji ne pokriva — FEN table
pre promene dela — izmereno je nezavisno i ispalo je znak po znak tačno,
uključujući polje za en-passant. Njegova jedina primedba je bila korisna: stari
`find.byIcon(Icons.delete).first` u `tutorial_studio_fields_test.dart` hvatao bi
dugme panela, pa je za svoje uzeo `Icons.delete_outline` **umesto da menja test
koji mu nije dat** — tačna odluka.

**Lead-ova mutacija je preživela, i to je najvredniji deo runde.** Ispražnjeno
`_renumberGeneratedTitles()` ostavilo je svih četrnaest testova kapije zelenim,
zato što panel ime dela crta iz **rednog broja reda** — dakle ispisivao je
tačne reči preko netačnih podataka. A `TutorialSection.toJson` šalje baš to ime
serveru: deo pomeren na početak, sa zapamćenim imenom „Deo 2", daje tutorijal
čiji su koraci numerisani obrnuto od ekrana na kome su pisani.
`test/tutorial_section_titles_test.dart` tvrdi nad **zahtevom**, i viđen je kako
pada na toj mutaciji pre nego što mu se poverovalo. **Preživela mutacija je
pitanje, a ne presuda** — kaže da test ne vidi, a ono što ne vidi nije uvek ono
što si mutirao.

Ostale lead-ove popravke: pravilo o numeraciji stajalo je na **pet mesta**
(četiri prekopirane petlje u ekranu, svaka sa `RegExp` koji se prevodi unutar
petlje, i još jednom u panelu) — sada je `generatedSectionTitle` /
`isGeneratedSectionTitle` u modelu, ista porodica kao tri prepisana podupita
koja su sva zaboravila `status = 'accepted'`; dve rečenice koje su ostale na
„Primer" u tom ekranu; i pomenuti pretraživač po ključu umesto po ikoni.

**Kapija za prazan string.** `strings` je pao na `-['', '']` — radnik je izbacio
`_sentenceController.text = ''` jer čišćenje polja sada ide kroz
`_loadSelectedSection()`, jedinog čitača. To je popravljeno **u kapiji, a ne
dozvolom**: `_norm` više ne broji prazan literal ni sa jedne strane, jer u
stringu bez znakova nema teksta koji bi trebalo štititi. Dozvola bi rešila jedan
batch i ostavila sledeće preuređenje kontrolera da udari u isti zid.

### P5b — podeljeni raspored, 6.9.2026, batch 58

`gemini-3.8-flash-high`, `flutter_feature_builder`, jedna runda, devet kapija
zeleno iz prve. **1524 testa u aplikaciji, 1 preskočen** (bilo 1515); backend
nije diran i ostaje na 956.

Tabla sada uzima prozor, a desna kolona je fiksnih 460: naziv iznad, „Delovi
tutorijala" u gornjoj polovini, polja i stablo u donjoj, **svaka polovina sa
svojim skrolom**. Čitanje linije više ne odnosi spisak delova sa ekrana, što je
ceo razlog zbog kog je ovaj raspored napravljen. „Sačuvaj tutorijal" je otišao
**u AppBar**, iz oba rasporeda — tamo gde ga je §5 plana i crtao.

**Najvrednije u ovoj rundi desilo se pre nego što je radnik pokrenut.** Ceo
raspored je jednom napravljen kao proba pa bačen, samo da se vidi da li je
kapija zadovoljiva. Nije bila: prvi oblik je Sačuvaj prikucao ispod donje
polovine, tačno tamo gde `AppFeedback` crta poruku — pa je SnackBar prekrivao
dugme na koje se žali, i jedan od šest dodira na njega u zamrznutoj kapiji
`tutorial_authoring_test.dart` je pao na prekriveno dugme. Sa dugmetom u
AppBar-u proba je dala 1524 zelena bez ijedne izmene u postojećim testovima —
i tačno to je batch i postigao. **Kapija koju niko ne može da zadovolji košta
rundu; pola sata probe je platilo tri takve stvari odjednom** (uz to: panel
traži `Flexible`, ne `Expanded`, jer u uskom rasporedu ima neograničenu visinu;
a centriranje se meri na `BoardWithCoordinates`, jer oznake redova i kolona
stoje sa dve strane pa je sama tabla namerno van centra u svom vidžetu — prva
verzija kapije je tražila asimetriju koja bi bila greška da ju je neko napravio).

**Izveštaj radnika je četvrti uzastopni čist**, i sve u njemu je mereno:
460 + 12 + 1104 = 1576 (širina reda na prozoru od 1600), polovine 336 i 504 —
tačno 2:3 — i 148 px zazora sa svake strane table. Na pitanje „koji je test van
kapije ijednom pocrveneo" odgovor je „nijedan", što se poklapa sa probom.

Vođa je pokrenuo još dve mutacije preko tri koje je batch prijavio: kad se
donjoj polovini oduzme sopstveni skrol, pada sedam od devet testova; kad se
Sačuvaj vrati ispod nje, pada tačno jedan — onaj koji i postoji zbog SnackBar-a.

Jedna popravka vođe: naziv tutorijala i poziv panela stigli su **napisani dva
puta**, po jednom u svakoj grani rasporeda, s tim što je naziv sa sobom poneo i
doslovnu kopiju četvororednog komentara koji objašnjava zašto se upisuje u
nacrt. Sada su `_titleField()` i `_sectionsPanel()`. **Kapija za stringove je to
i primetila** — prijavila je ta dva literala kao *dodata*, što je ono što druga
kopija izgleda spolja.

### P6a — hronologija „Tok", 7.9.2026, batch 59

`gemini-3.8-flash-high`, `flutter_feature_builder`, jedna runda, devet kapija
zeleno iz prve. **1551 test u aplikaciji, 1 preskočen** (bilo 1539); backend
nije diran i ostaje na 956.

Autor je svoj tutorijal do sada mogao da pročita samo kao stablo poteza — pravi
oblik za uređivanje linije, pogrešan za pitanje „kako će ovo izgledati". „Tok"
je isti tutorijal u redosledu kojim ga dete sreće: kartica po taktu, rečenica
**između** poteza koji je stigao i poteza koji odlazi, i čip po odgovoru na
grananju. „Stablo" ostaje pored, jer je grananje stvar oblika stabla.

**Lead-ova polovina je bila `beatsOf`** (`3a4fe2e`): čista funkcija, petnaest
testova bez ijednog widgeta, devet mutacija — sve uhvaćene. Uz nju su izašle
dve stvari kojih u planu nije bilo. Broj poteza se **ne može brojati od korena**
(deo tutorijala može da počne iz bilo koje pozicije, pa samo FEN zna odakle
brojanje kreće) — to pravilo je bilo privatno u `VisualMoveTreeWidget`-u i sada
je `AnalysisNode.moveNumberLabel`, sa starim pozivaocem preusmerenim na njega. I
„koren" koji i sam ima roditelja je ovde dostižan — ekran drži `_rootNode` i
`_currentNode` preko izmena — pa je prva verzija beskonačno rekurzirala; sada se
zaustavlja, sa testom.

**Proba je i ovde platila.** Ceo panel je jednom napravljen pa bačen, i našla je
pravilo koje ne bi našao niko: `IndexedStack` drži skrivenu karticu **van
scene**, a `find.byType` podrazumevano preskače takve widgete. To je obaralo
`tree()` pomoćnu funkciju u **tri postojeća fajla** i sa njom dvadeset tvrdnji,
nijednu o karticama. Pripremljeno je na `master`-u pre batch-a, pa batch nije
morao da dira nijedan test.

**Jedna od tih dvadeset nije bila stvar pomoćne funkcije nego pretvrde tvrdnje.**
`tutorial_authoring_test.dart` je tražio da rečenice **nema nigde na ekranu**,
misleći „polje je više ne drži" — a hronologija je crta na svojoj kartici, s
pravom. Ispravna funkcija bi oborila taj test. Sada pita za `TextField`. Ista
porodica kao pretraživač iz batch-a 55: **tvrdnja o odsustvu je tvrdnja o celom
ekranu, a ekran stalno raste.**

Radnik je uradio dve stvari preko onoga što je traženo, i obe se zadržavaju:
tekući takt je označen na četiri načina (podloga, jači okvir, deblja slova i
ikonica), kao i uzeti čip — dakle ništa ne zavisi od same boje; i svaka kartica
ima najmanje 48 dp visine sa čipovima u `Wrap`-u. Vođa je pokrenuo još jednu
mutaciju preko četiri koje je batch prijavio, onu koju testovi crtanja ne mogu
da vide: zamena `IndexedStack`-a običnim uslovom crta isto, a obara „stablo se
ne pregrađuje pri promeni kartice".

### P6b — tutorijal se piše u hronologiji, 7.9.2026, batch 60

`gemini-3.8-flash-high`, `flutter_feature_builder`, jedna runda, devet kapija
zeleno iz prve. **1563 testa u aplikaciji, 1 preskočen** (bilo 1554); backend
nije diran i ostaje na 956. Diff su dva fajla i nijedan postojeći test nije
dirnut.

Do sada je „Tok" bio pogled, a pisalo se u jednom polju pored njega — pa je isti
tekst imao dva mesta: karticu na kojoj se čita i polje u koje se kuca, bez ičega
na ekranu što kaže o kom je potezu to polje. Sada svaka kartica nosi rečenicu
svog poteza, kartica sa pitanjem stoji ispod poslednjeg takta, a iznad kartica
ostaju samo naziv tutorijala i spisak delova.

**Preživela mutacija je bila rupa u kapiji, ne u diff-u.** Vođa je promenio
`onCommentChanged` da piše na čvor **na kome autor stoji** umesto na čvor
kartice — tačno kvar zbog kog je test i pisan — i svih devet je ostalo zeleno.
Razlog: kad se sačuvan tutorijal otvori, kursor stoji **na korenu**, a komentar
korena `PgnExporterService` ispisuje *ispred* prvog poteza, pa je tvrdnja
„rečenica stoji pre `e5`" bila tačna i za njega. Test sada prvo stane na
poslednji takt i čita sačuvanu liniju nazad **kroz `LessonStepLine`**, pitajući
koji potez nosi komentar. Gledan je kako pada pod mutacijom i kako je zelen bez
nje. **Izveštaj radnika je istu rupu našao sam i predložio istu popravku** — to
je najvrednije u njemu, i šesti uzastopni izveštaj bez ijednog izmišljenog broja.

**Dve popravke vođe koje nijedna kapija ne dohvata.** Kursor se gubio na kliku
kojim pisanje počinje: ključ polja se menja u trenutku kad kartica postane
tekuća (`beat-comment-N` → `example-sentence`), promenjen ključ demontira
element, i `TextField` koji sam pravi svoj `FocusNode` ostaje bez fokusa baš kad
trener klikne u tuđu karticu da piše. Izmereno sondom (posle klika nijedan
`EditableText` nema fokus; kontrola sa klikom u polje tekuće kartice daje
`focus=true`), popravljeno tako što `FocusNode` drži kartica. Nijedan test to ne
može da vidi, jer `enterText` sam fokusira polje. I nalepnica „Komentar za
trenutni potez" stajala je na svim karticama, pa su tri od četiri tvrdile da su
potez na kome trener stoji; sada je samo na tekućoj, a zaglavlje svake kartice
(„posle 1. e4") ionako kaže o kom je potezu reč.

Ostaje da se vidi uživo, tačka 116 u `docs/TODO-provera.md`, koja ide zajedno sa
113–115 — isti ekran, isti prolaz.

### P7a — trener crta po tabli, 7.9.2026, batch 61

`gemini-3.8-flash-high`, jedna runda. **1593 testa u aplikaciji, 1 preskočen**
(bilo 1582); backend nije diran i ostaje na 956. Sedam mutacija ukupno, tri
batch-ove i četiri vođine — sve uhvaćene.

Model ovo nosi od faze 2 `PLAN-INTERAKTIVNA-LEKCIJA`: čvor drži `arrows` i
`squares`, izvoznik piše `[%cal]` i `[%csl]`, dečji pregledač ih crta. **Niko ih
nigde nije upisivao** — svaka strelica u svakoj lekciji do danas ukucana je
rukom u PGN. Sada postoji traka ispod table i oznake putuju do deteta.

Ožičenje je ceo diff: `cancelPending()` na sva četiri mesta gde se tabla pomera,
oznake predate kontroleru kao `_current.arrows` i `_current.squares`, i
`_persist()` samo kad se nešto promenilo.

**Dve kapije su pale iz prve i nijedna nije bila greška u poslu.** `worktree` je
oborio traku, koju vođina dozvola nije imenovala — batch 47 je naučio
`changed_dart_files` da **vidi** nepraćene lib fajlove, a `gate_tree`, čiji je
posao da obori nepraćen fajl koji niko nije imenovao, o tome nije obavešten.
Videti fajl i dozvoliti ga su dve kapije; ovo je četvrti put da mehanizam obori
posao koji je sam tražio. A `contrast` je pročitao
`backgroundColor: isArrow ? accent : null` i `foregroundColor: isArrow ? canvas
: textPrimary` kao **unakrsni proizvod** i prijavio par koji se na ekranu nikad
ne crta. Popravljeno u widget-u a ne dozvolom: `_modeStyle` vraća dva cela stila
umesto jednog sastavljenog od četiri uslova, pa svaka grana nosi svoj par.
Skener ostaje konzervativan, i to je ispravno — skener koji bi grane uparivao
pogađanjem jednog dana bi sakrio pravi pad.

Ostaje da se vidi uživo, tačka 117 u `docs/TODO-provera.md`, uz 113–116.

### Šta je otvoreno — ODAKLE SUTRA

**P5a je gotov** (batch 57, gore) — ostaje da se vidi uživo, tačka 113 u
`docs/TODO-provera.md`. Odluka da se P5 deli na dva batch-a (6.9.2026, vlasnik
izabrao između tri ponuđene) pokazala se tačnom: ekran koji istovremeno dobija
nov raspored i novo ponašanje daje diff koji niko ne može da oceni popodne.

**D7 („Deo" umesto „Primer"): pola je ušlo u P5a, pola nije.** Ovaj dokument je
prvobitno rekao da ništa od toga ne ide u P5a; kada je pisana kapija, odlučeno
je drugačije za **ovaj jedan ekran** — panel je površina koja imenuje deo, pa je
besmisleno da se zove jedno a piše drugo. Svaka druga pojava te reči i dalje je
poseban batch sa tabelom u `docs/TABELA-TUTORIJAL.md` i
`tutorial_vocabulary_test.dart` kao zaštitom, po uzoru na batch 51.

**`master` nije gurnut.** CI se okida na push, pa je to svesna odluka vlasnika, ne
propust.

**P5b je gotov** (batch 58, gore) — ostaje da se vidi uživo, tačka 114 u
`docs/TODO-provera.md`, koja ide zajedno sa 113.

**P6a je gotov** (batch 59, gore) — ostaje da se vidi uživo, tačka 115 u
`docs/TODO-provera.md`, koja ide zajedno sa 113 i 114.

**P6b je gotov** (batch 60, gore) — ostaje da se vidi uživo, tačka 116. **Time
je ceo P6 zatvoren**, i sa njim glavni deo redizajna: studio je jedan ekran na
kome se tutorijal i piše i čita.

Probni build je i za P6b platio pre nego što je brief napisan: našao je da
sačuvan tutorijal nikada nije učitavao *tip* dela u editor (`ad8c11a`, sa
`test/tutorial_reopen_test.dart`), i suzio tvrdnju u
`tutorial_authoring_test.dart` koju bi ispravan P6b oborio (`3c9d481`). To je
treći probni build zaredom koji se isplatio.

**Stanje `master`-a mereno 7.9.2026, ničim drugim uz to: 1563 testa u
aplikaciji, 1 preskočen; `flutter analyze` — 29 stavki, sve `info`.** Backend
nije diran i ostaje na 956.

**P7 je ceo gotov.** P7a je batch 61 (gore) — ostaje da se vidi uživo, tačka
117. **P7b je urađen isti dan, vođa** (`1ae5fd2` + `869dd60`): soba je prešla na
`BoardAnnotationController`, iz nje su izašla tri polja i dve metode, i jedno
pravilo više ne živi na dva mesta. **1605 testova u aplikaciji, 1 preskočen**;
analizator 29; backend 956.

Redosled je bio ceo posao: **prvo dvanaest testova crtanja u sobi, zelenih na
nepromenjenoj sobi**, pa tek onda selidba. Soba se, ispostavilo se, može
pumpati u testu — `STUDIO` je jedini kod sobe čiji `initState` ne traži server,
ni registraciju sesije, ni partnera, socket se pravi sa `disableAutoConnect`, a
`lessonApi` je već injektabilan.

**Dve mutacije su preživele prvi put**, i to je bio nalaz: brisanje
`cancelPending()` iz `_selectNode` i iz rukovaoca potezom ostavljalo je sve
zeleno, jer nijedan test nije šetao stablom sa polunacrtanom strelicom. Rupa je
zatvorena sa dva testa, oba gledana kako padaju na mutaciji koja ih je našla.

Dve namerne promene ponašanja, obe zapisane u kodu: **prazno „Izbriši sve
strelice" više ne emituje** (upisivalo je `arrow_drawn` u `timeline_json` za
pritisak koji ništa nije promenio, pa je reprodukcija imala prazan takt), i
dugme za crtanje je `_toggleDrawingMode()`, napisano jednom umesto po jednom u
svakom rasporedu. Živa provera je tačka 118, i ona gađa **baš ono što testovi ne
vide** — emitovanje detetu i snimak.
Lead-ova polovina je bila `BoardAnnotationController` (`e95b27e`): celo
odlučivanje o tome šta klik znači, devetnaest testova bez ijednog widgeta i
sedam mutacija — šest uhvaćeno, a sedma se nije mogla ni napisati, jer
`clearArrows` fizički ne dobija polja. Kontroler drži *interakciju* i nikad
oznake: oznake pripadaju čvoru, pa svaka metoda dobija dve liste i vraća da li
se išta promenilo.

**P8 je gotov, i sa njim je `PLAN-STUDIO-REDIZAJN` ceo zatvoren** (`52499cc` +
`812bd1a`, vođa). **1620 testova u aplikaciji, 1 preskočen**; analizator 29;
backend 956. Ostaje da se vidi uživo, tačka 119.

P8a je doneo odbrane iz §7 u studio — pitanje kad se bira tip, traka na
tutorijalu koji već curi, i odbijanje pri čuvanju sa **imenovanim** delovima —
i usput našao da je odbrana koja je već postojala **bila pogrešna**: deo se
procenjivao po `pgnForSave.trim().isNotEmpty`, a deo bez poteza ipak izveze
`pgn` kad mu koren nosi belešku, strelicu ili obojeno polje. Tako je „Nađi
najbolji potez" sa strelicom bio odbijen zbog linije koju nema. **P7a je to
učinio uobičajenim načinom pisanja pitanja**, pa bi greška stigla sa prvim
pravim tutorijalom. Sada `TutorialSection.hasLine` pita stablo, a `leaksAnswer`
je jedan geter koji čitaju sva tri mesta. Uz to `ask_choice` traži dva do četiri
odgovora sa tačno jednim tačnim, što je §7.6 tražio a batch 54 ostavio otvoreno.

P8b je preneo „Pregledaj kao učenik" u studio (ništa ne šalje — pregledač dobija
`PreviewAssignmentApiService`) i ugasio stari editor **samo na Windows-u**:
`openTutorialEditor` je jedina vrata i jedino mesto koje pita platformu. Na
Androidu `LessonStepEditorPanel` ostaje netaknut, jer je dohvatljiv sa svake
platforme i brisanje bi odnelo uređivanje tutorijala sa telefona. Brisanje
panela kasnije je sada jedna izmena u jednom fajlu.

**Napisan je nov plan: [PLAN-PGN-TEKST.md](PLAN-PGN-TEKST.md)** (7.9.2026), iz
dve vlasnikove primedbe sa žive provere — tekstualni pogled na deo, i desni klik
na potez u tom tekstu. Ne menja model: oba smera već postoje
(`PgnExporterService` piše `[%cal]`, `[%csl]`, varijante i `[FEN]`;
`LessonStepLine` ih čita nazad i broji `rejectedMoves`). Usput zatvara rupu koja
je ostala posle razgovora o PDF-ovima: **aplikacija nema vrata za anotiranu
liniju napravljenu bilo gde drugde**, jer jedini uvoz PGN-a ide kroz
`_importPgn`, koji baca komentare, oznake i varijante. **T1 i T2 su gotovi istog dana** (`e45f004`, `e75e97d`), oba vođa.
`exportWithSpans` vraća isti tekst plus `(start, end, nodeId, kind)` za svaki
potez i svaki komentar (petnaest testova bez ijednog widgeta, pet mutacija, sve
uhvaćene), a studio ima treći tab **„PGN"**: tekst dela sa komentarima,
`[%cal]`, `[%csl]` i varijantama, i „Primeni" koje čita nazad kroz
`LessonStepLine`. **Time su otvorena vrata kojih nije bilo** — anotirana linija
iz knjige, iz motora ili iz onoga što model napiše iz PDF-a više ne mora da se
prekucava potez po potez.

U T2 su **tri od pet mutacija preživele prvi prolaz** i svaka je platila
popravku: test odbijanja nije umeo da razlikuje „odbijeno" od „primenjeno bez
poteza koji nije pročitan"; brisanje sačuvanog teksta pri primeni nije radilo
ništa (`treeSignature` ionako vidi novo stablo, pa je taj red obrisan); a
zaštita koja čuva neprimenjen tekst nije imala nijedan test — sada ima, iz
drugog pokušaja, jer je prvi igrao crni potez iz pozicije u kojoj je beli na
potezu.

**T3 i T4 su gotovi istog dana** (`b36ffe0`). Kursor u tekstu bira potez i
obrnuto — tabla i „Tok" idu za karetom, a karet ide za kursorom, ali nikad preko
teksta koji trener piše a nije primenio. Desni klik nudi tri stvari za potez pod
karetom; **strelica i polje ne crtaju sami**, nego postave kursor na taj potez i
uključe režim na tabli, jer crtanje ima jedan dom od P7.

Usput je jedno postojeće pravilo uhvatilo grešku i **bilo je u pravu**:
`tutorial_authoring_test` obara sve pod `lib/features/tutorial_studio/` što
uvozi `PgnExporterService`, jer par `fen`/`pgn` ima jedan dom. Tipovi raspona su
sada zaseban model, a tekst za tab dolazi iz `StudioLessonStep.textWithSpans` —
kapija stoji neoslabljena.

**T5 je gotov** (`daee549`) i sa njim je `PLAN-PGN-TEKST` ceo zatvoren. Kad
nalepljeni tekst nosi svoj `[FEN]` različit od pozicije dela, pita se jednom —
„Odustani", „Zadrži postojeću", „Uzmi tu poziciju" — jer uzimanje te pozicije
menja tablu na kojoj **dete** otvara deo. Usput su dve stvari koje su htele da
budu napisane dvaput sada napisane jednom, u `move_tree.dart` pored parsera koji
ih je već znao: `fenHeaderOf` (jedini čitač `[FEN]` zaglavlja) i `samePosition`
(poređenje bez satova, koje je do sada privatno živelo u pregledaču).

**Stanje: 1667 testova, 1 preskočen; analizator 29; backend 956.**

Napisano je i **[UPUTSTVO-STUDIO.md](UPUTSTVO-STUDIO.md)** (7.9.2026, srpski —
namerno, publika su treneri): razlika između **takta** i **dela**, tri tipa
zadatka, zašto pitanje ne sme da nosi liniju, format `[%cal]`/`[%csl]` sa
slovima boja, i redosled rada. Poslednji odeljak je **prompt za model** koji iz
knjige pravi gradivo, sa šest pravila koja je izlaz stvarno prekršio na
fajlovima u `D:\chess books`.

Ostaje **živa provera** — tačke 113–120, jedna sesija na jednom ekranu.

**Sledeće nije više ovaj plan nego živa provera**: tačke 113–119 su jedna
sesija na jednom ekranu, i sada ima na čemu — fajlovi iz `D:\chess books` daju
pravi tutorijal umesto izmišljenog.

**Zašto je P7 bio podeljen na dva** — vredi zapamtiti, jer je odluka bila
ispravna iz razloga koji se video tek na kraju. Drugo mesto poziva je soba, a
soba **nije imala nijedan test svog crtanja**, dok je to ekran na kome ide živi
čas i gde nacrtana strelica ide i u `timeline_json` i na dečju tablu.
Prepravljati ga na osnovu izveštaja radnika je tačno ono što je u ovom
repozitorijumu zapisano da se ne radi — pa je otišao vođi, sa testovima kao
prvim korakom. Te testove su odmah zaradile **dve preživele mutacije**, obe o
polunacrtanoj strelici preko promene poteza: da je posao bio jedan batch, taj
propust bi ušao u sobu i niko ga ne bi video.

Dve stvari koje je P6b ostavio kao pitanje, a ne kao dug: da li kartice koje
nisu tekuće treba da imaju nalepnicu nad poljem (sada je nemaju, i to je odluka
o tekstu koju donosi vlasnik), i da li klik u polje tuđe kartice treba i da
pomeri tablu (sada pomera — radnik je to dodao preko onoga što je traženo, i
zadržano je).

**Dozvole za batch-eve 57, 58 i 59 su izbrisane iz `orchestrate.py` pri
spajanju**, a staging kopije kapija su otišle iz `docs/gates/` u
`chess_app/test/` u samim merge commit-ima — `docs/gates/` je sada prazan, kako
i treba između batch-eva.

Redosled, podela posla i kapije su u §8 [PLAN-STUDIO-REDIZAJN.md](PLAN-STUDIO-REDIZAJN.md).
Za rad sa radnikom: `D:\Projekti\mislisha-test\orchestrator\HANDOFF.md`, prvi
odeljak je batch 57.

---

## Jednostavnost — plan i faze 0–3, 3.9.2026

Dogovor je [PLAN-JEDNOSTAVNOST.md](PLAN-JEDNOSTAVNOST.md), napisan posle
provere uživo koja je bila i najkorisniji dan do sada: vlasnik je za jedno
popodne morao da pita šta znače četiri stvari na ekranu („Pregledaj nacrt",
„talas", „Napravi kičmu", „Pokrivenost"), a ista ta provera je našla četiri
kvara — svi istog oblika, **ekran zna nešto što čitalac ne vidi**. Rečnik i
kvarovi su isti problem: ekran koji se ne može pročitati je ekran koji se ne
može ni proveriti.

| faza | šta | ko | stanje |
|---|---|---|---|
| 0 | ugovori: tri prekidača u podešavanjima, `ActionBanner`, `SpeakableInfo`, `SpeechToggleButton` | lead | **Urađeno**, `661ff47` |
| 1 | jedan meni na tabli i tri prekidača za strelice | radni agent | **Urađeno**, `c26b83c` |
| 2 | govor na info panelima, prekidač u zaglavlju | radni agent | **Urađeno**, `1e8822d` |
| 3 | dril kaže šta pokriva; dnevni cilj i vežba van rasporeda | lead | **Urađeno**, `28b196c` + `a217cdf` |
| 4 | zamena reči po rečniku | radni agent | **Urađeno**, `8ce6a6e` |
| 5 | provera uživo i unos u `TODO-provera.md` | lead | Nije rađeno |

**Rečnik je zamrznut u planu** i faza 4 se radi po njemu: kičma → glavna
linija, nacrt → nepotvrđeni potezi (gomila) / predlog poteza (jedan), kapija →
„ide kroz <potez>", širina → „koliko odgovora spremamo", pokrivenost → rupe u
repertoaru, odsečeno → „ne spremam". „Talas" i „red" su već izbačeni.

Otvoreno pitanje koje je vlasnik ostavio za kasnije: pojmovi „odlučeno",
„otvoreno", „bez odgovora" traže objašnjenje na dodir, tamo gde broj stoji.
Radi se **posle** faze 4, da se ne piše dvaput.

### Šta je faza 2 pokazala o ocenjivanju batch-a — 3.9.2026

Batch je urađen i spojen (`1e8822d`). Kod je bio uglavnom tačan; **dokaz nije
bio**, i to je nalaz koji vredi pamtiti.

Testovi koje je radni agent napisao nisu dodirnuli nijedan panel: dizali su
goli `SpeakableInfo` sa rečenicom otkucanom u samom testu, što je test iz faze
0 napisan po drugi put. Prošli bi i da je omotač uklonjen sa svakog ekrana u
aplikaciji. `flutter analyze` je to rekao naglas — dva `unused_import`, i to
baš onih ekrana koje je fajl tvrdio da testira. To je i razlog zašto se
izveštaj ne uzima kao ocena: brojevi u njemu (29 upozorenja) nisu bili tačni,
pravo stanje je bilo 31, od toga dva `warning`. Fajl uz to nije bio formatiran.

Testovi sada dižu **prave ekrane** (`RepertoireDrillScreen`, `UnconfirmedBanner`)
i porede ono što je stiglo do lažnog engine-a sa tekstom pročitanim iz stabla
widget-a, pa rečenica koja odluta od svog panela obara test. Šav koji to
omogućava: `SpeakableInfo` u ekranu nema injekciju, čita `SpeechService.
instance` — ali `init` prima engine, pa se singleton uperi u lažni.

Svaki čuvar dokazan mutacijom: razdvoji izgovoreno od prikazanog, skini
zvučnik sa banera, ugasi `autoSpeak` na presudi — svaka mutacija obori svoj
test i nijedan drugi.

Dve odluke izmerene umesto isprazno raspravljene: `Container`/`FittedBox` u
zaglavlju **ostaje** na ekranu drila, gde vraćanje starog `Padding`/`Center`
prelije 360 dp telefon za jedan piksel, a **vraćen je** na ekranu gradnje, gde
nije trebao i uzalud je smanjivao brojač. Release build ne crta trake ni za
jedno.

**Prag je sada 1128**, 1 preskočen.

### Šta je harness naučio 3.9.2026

Prvi batch koji je smeo da **obriše** fajl srušio je tri kapije: čitale su
spisak izmenjenih fajlova i otvarale svaki, a obrisan fajl je u spisku i nije na
disku. Pad je najgori od tri moguća odgovora — nije prolaz, nije nalaz, i
zaustavi sve kapije iza sebe. Sada postoji `changed_dart_files_on_disk`,
`gate_strings` sam rešava obrisan fajl, a `BATCH_ALLOWANCES` ima treću vrstu
dozvole: `"deleted"`.

---

## Repertoar, druga iteracija — faze 0–4 gotove, ostaje provera uživo

Dogovor je [PLAN-REPERTOAR-2.md](arhiva/planovi/PLAN-REPERTOAR-2.md): devet zahteva, pet faza.
Stanje na 3.9.2026, sve na `master`:

| faza | šta | stanje |
|---|---|---|
| 0 | dril govori istinu (`pickReply` čita `repertoire_skips` i nudi samo odgovore koji vode u poziciju sa `source='chosen'`) | **Urađeno**, oba čuvara dokazana mutacijom |
| 1 | ugovor: `repertoires.breadth`, `/unconfirmed`, `/unconfirmed/count`, `/alternative`, `ids` na `/drill/line` i `/drill/branches` | **Urađeno**, zamrznuto u `3691e8f` |
| 2 | poslednji potez na tabli i ECO traka | **Urađeno**, `098e786` |
| 3 | pregled nacrta, značka na kartici, širina kičme | **Urađeno**, `936d202` |
| 4 | „Izdvoji u novo otvaranje" i kombinovani dril | **Urađeno**, batch ocenjen i dovršen rukom |
| 5 | provera uživo i unos u `TODO-provera.md` | Stavke napisane (sekcije 86–91); **provera je počela 3.9.2026** i našla četiri kvara — vidi ispod |

**Provera uživo je počela 3.9.2026 i stala na sekciji 89.** Alat je
`D:\Projekti\mislisha-test\qa` (699 stavki, 137 odgovoreno; `python
server.py`, pa `http://localhost:8099/provera.html`). Sekcije 86–91 kažu šta
treba videti; 91 je spisak onoga što je ta provera našla i popravila.

Četiri kvara nađena za jedno popodne, **nijedan vidljiv za 1088 testova**, svi u
procepu između onoga što klijent pošalje i onoga što test gleda:

* `'minRating': ''` — vrednost nikad interpolirana, pa je server čitao
  `Number('') || 0` i svaki pregled nacrta pitao u traci 0, gde pozicije nisu ni
  dohvatane. „Nema više nepotvrđenih poteza" na repertoaru pun nacrta.
* **širina se čuvala i nije se slala** — `tree`, `frontier` i oba `drill` poziva
  su je izostavljala, pa je server uvek računao 80%. Mereno: `main` crta 3
  protivnikova poteza, `standard` 23.
* **traka sa brojem nacrta se nije osvežavala** posle pregleda.
* **prazan red je bio ćorsokak** — ekran je govorio da se vratite na neku
  poziciju i nudio samo „Nazad".

Popravke: `cb21012`, `9809a25`, `50fe6d2`, `5f9fc6c`, `34cd5de`, `07c3e1f`,
`8e268bc`, `f2b2dc8`, `0ec7f05`. Sve traže build napravljen posle `50fe6d2` da
bi se videle.

Faze 2, 3 i 4 radio je radni agent (Gemini) po brief-u; ocenjivanje je mašinsko,
harness je `D:\Projekti\mislisha-test\orchestrator` (nije u gitu — pročitati
njegov `HANDOFF.md` prvo).

Tri stvari koje su prošle sve kapije i našle se tek čitanjem diffa, vredne
pamćenja jer se ponavljaju:

* **Faza 2:** traka sa imenom otvaranja bila je montirana sa `key` koji se menja
  pri svakom koraku šetnje, pa se ime brisalo baš tamo gde pravilo postoji.
  Widget test je prolazio — pumpa traku direktno i nikad ne vidi `key` koji joj
  ekran daje.
* **Faza 3:** sva četiri nova endpointa napisana su bez `$backendUrl`. Pali bi
  na prvi dodir na telefonu, a svi testovi su bili zeleni, jer `MockClient`
  odgovara na šta god dobije i nikad ne gleda URL.
  `test/repertoire_api_urls_test.dart` sada to čita iz izvora.
* **Faza 4:** `ids` je bio uredno provučen kroz servis i nikad poslat. Spisak je
  gurao ekran drila sa `rootFen: null`, a `_loadNext` i `_pickBranch` su čitali
  samo koren — pa je kombinovana sesija propadala na dril cele boje, a list
  grana nije mogao ni da se otvori. Dva otvaranja su drilovala sve crne
  pozicije koje čovek ima. Osam od devet kapija je bilo zeleno; oba nova testa
  su lagala jer su lažirala API **iznad** žice. Uz to: `widget.api!` tamo gde
  konvencija fajla dvesta linija iznad glasi `widget.api ?? ...`, a ruter pravi
  `const RepertoireListScreen()` — dugme je pucalo na prvi dodir van testa.
  **Pouka koja se ponavlja treći put: lažirati klijent, ne metodu.** Testovi
  koji su ovo uhvatili gledaju URL koji je `MockClient` stvarno dobio.

---

## Tabla, stablo i pitanje moraju da govore o istoj poziciji — 4.9.2026

Prijavljeno uživo: „pita me za potez, a u stablu mi je fokus na drugoj
poziciji." Jedan slučaj je nađen i popravljen istog dana (`_openReplies` je
pomerao tablu preko `_boardController.loadFen`, što ne kaže ničemu drugom da se
pozicija promenila — `_standingAfter` je ostajao prazan, a to je ono što stablo
osvetljava i po čemu se čita knjiga ispod table). Sada ide kroz
`_standAfterMove`, sa testom dokazanim mutacijom.

**Pravilo koje iz toga sledi, i važi šire od ovog ekrana:** postoji **jedan**
način da se ova tabla pomeri, i to je metoda koja uz tablu pomeri i sve ostalo.
`_boardController.loadFen` sam za sebe je uvek pola posla — pomeri figure i
ostavi stablo, poslednji potez i knjigu na staroj poziciji. Ako zatreba nova
vrsta pomeranja, dobija svoju metodu pored `_standAfterMove` i `_show`, a ne
goli `loadFen` na mestu upotrebe.

Ono što **nije** kvar i ne treba „popravljati": pitanje i tabla smeju da se
razilaze. Red je odakle dolazi sledeće pitanje, tabla je ono što gledate, i
stajanje posle svog poteza da bi se videli protivnikovi odgovori je namerno.
Sinhronizovani moraju da budu **tabla i sve što tvrdi gde smo** — stablo,
poslednji potez, knjiga, komentar.

`findNodeByFen` je popravljen istog dana (`7bbd16f`): poredio je ceo FEN dok
ostatak koda poredi `fenKeyOf`, pa su se pozicija koju je server poslao i ona
koju je tabla izračunala razlikovale u brojačima poteza — tiho, uz stablo koje
osvetli koren. Uz njega je otišla i druga kopija iste pretrage (`_findNode`).

Otvoreno: proveriti ostale `loadFen` pozive na ovom ekranu istom merom.

## „Upoznaj repertoar" — faze 1–3 gotove, 4.9.2026

Dogovor je [PLAN-UPOZNAJ-REPERTOAR.md](arhiva/planovi/PLAN-UPOZNAJ-REPERTOAR.md), napisan po
vlasnikovom zapažanju da izgrađen repertoar postane slika koju niko ne može da
drži u glavi.

| faza | šta | ko | stanje |
|---|---|---|---|
| 1 | šetnja pokazuje igraču njegov sopstveni rad (širina ga ne skriva) | lead | **Urađeno**, `e5bdb4c` + `8625273` — uživo neprovereno |
| 2 | stablo crta svoja četiri stanja | lead | **Urađeno**, `37a67d3` — vlasnik video na obe teme |
| 3 | redosled obilaska (`walkthroughOrder`) | lead | **Urađeno** — brief `docs/TASK-upoznaj-f3.md` stoji kao ugovor za fazu 4 |
| 4 | ekran „Upoznaj" | radni agent | **Urađeno**, `a3b32d5` — radni agent 43.7 min, pet popravki vodećeg, uživo neprovereno |
| 5 | govor, sa budžetom rečenica | lead | **Urađeno** — uživo neprovereno |

**Dve odluke koje je vlasnik doneo 4.9.2026 i koje faza 4 nasleđuje:**

* Redosled je po `share`, ali **grana u kojoj ima igračevih odluka nikad ne ide
  iza prazne**. „It is a walkthrough of my repertoire, so the user's actual
  work must never be buried beneath untouched book lines."
* Tura govori samo o onome što je nacrtano. Rep („van toga još N poteza") ne
  ulazi u odgovor `/repertoire/tree` i endpoint se ne dira.

**Vlasnik je oba pitanja zatvorio 4.9.2026.**

Stablo iz faze 2 **jeste** rešilo prostorni deo — „graf je neuporedivo
čitljiviji" — ali faza 4 ostaje, i to je merenje koje je faza 2 trebalo da
donese: *„korisnik ne želi samo statičan pogled na razgranato stablo, već
sekvencijalno vođenje kroz poteze na tabli korak-po-korak, gde na protivnikovom
potezu jasno vidi listu odgovora i rupe."* Ekran je zato kompaktan: tabla,
traka poteza, sheet za granu i kartica sa objašnjenjem — bez drugog graditelja
i bez druge slike.

Tri odluke koje faza 4 nasleđuje, sve tri vlasnikove:

* **Ulaz je stavka u meniju „Još"** na kartici repertoara, ne četvrta ikonica:
  red već nosi bedž, „Vežbaj" i meni, a četvrta kontrola na 360 dp se u release
  buildu tiho seče. Naziv je **„Upoznaj repertoar"**.
* **Na širokom ekranu stablo stoji pored table**, sinhronizovano sa turom; na
  telefonu ostaje kompaktni raspored bez stabla.
* Kontrast rupe u tamnoj temi — rešeno pre faze 4, odeljak ispod.

### Strelice na račvanju i povratak na račvanje — 4.9.2026

Vlasnik je gledao turu i tražio dvoje: strelice za protivnikove odgovore tamo
gde se linije račvaju, i **povratak na poziciju iz koje se račva** pre nego što
krene sledeća linija, da bi je prepoznao.

**Strelice** idu kroz `EngineArrow`, isto kao na ekranu za izgradnju, pa
debljina poteza nosi rang kao i boja. Tri pravila koja se razlikuju od
`_shareArrows`: rang je **redosled ture**, ne `share` (inače najdeblja strelica
nije prvi čip); nema praga od 2%, jer tura hoda samo kroz ono što repertoar
zaista sadrži; rupa nosi `?` u znački, nikad boju. Tavanica od četiri ostaje.

**Povratak** je nov pojam: `walkthroughBeats` pravi listu *taktova* od liste
stajanja — svako stajanje jednom, plus povratak na račvanje pred svaki uspon.
`walkthroughOrder` nije diran, i test tvrdi da taktovi ne preuređuju stajanja.
Kartica tada kaže „Videli smo liniju posle e5. Sada ide e6." i to se izgovara
uvek, jer je to jedini takt koji postoji da čitalac ne bi bio izgubljen.

Tri greške nađene dok se ovo pisalo, i sve tri su isti oblik — **indeks kome se
promenilo značenje**:

* `_onSelect` i `_syncBoard` su ograničavali i indeksirali `_index` po
  `_stops`, a on sada broji taktove. Ima ih više nego stajanja, pa je tura
  **stala na poslednjem usponu** — dugme napred nije radilo ništa, tiho — a pre
  toga je tabla učitavala stajanje koje slučajno deli broj sa taktom, dakle
  **pogrešnu poziciju**, dok su kartica, strelice i rečenica bili tačni.
  Sve što je ekran činilo tačnim je bilo pokriveno; jedino što je bilo
  pogrešno nije.
* Na taktu povratka je traka pitala „odavde ide više linija — kojom?" odmah
  pošto je tura rekla kojom ide. `forwardBranches` (pitanje trake) je zato
  razdvojen od `replyBranches` (spisak na kartici).
* Test iz faze 4 je posle uvođenja taktova **prolazio iz pogrešnog razloga**:
  čitao je `stops[currentIndex]` sa brojem takta. Prepisan je da tvrdi kroz
  kursor.

I jedan test moj: „jedan odgovor nije račvanje" je stajao na poziciji ispod
koje je *moj* potez, pa je dokazivao da pozicija bez protivnikovih odgovora ne
crta ništa — što niko nije ni sumnjao. Uklanjanje pravila ga je ostavljalo
zelenim. Sada se dohoda do `d4`, gde postoji tačno jedan odgovor.

**Otvoreno, nađeno usput i namerno nepopravljeno:** `board_arrows_reach_test`
je pojačan da hvata i drugu polovinu istog kvara — prekidač za sloj koji ekran
nikad ne crta. Tri ekrana ga imaju: Analysis Studio, AI Studio i
`chess_game_screen`, svi kroz staro `arrows: true`. Nije dirano jer bi skinulo
po dva prekidača sa tri ekrana koje niko nije tražio, a podešavanja iza njih
važe za celu aplikaciju. Nov ekran koji imenuje prekidače pojedinačno je
pokriven.

### Faza 5: tura govori, i uglavnom ćuti — 4.9.2026

`walkthroughLine` (`services/walkthrough_speech.dart`) vraća **dve** stvari:
rečenice i to da li se ovo stajanje uopšte izgovara. Govori se na račvanju, na
rupi i tamo gde ste nešto zapisali; običan potez na glavnoj liniji ćuti — tabla
se pomeri, kartica kaže šta je, i ništa se ne čita. To je ceo dizajn protiv
zamora i zbog njega budžet iz plana („najviše četiri izgovorene rečenice na
dvanaest poteza") drži po konstrukciji, a ne slučajno. Test ga meri na trunku
od 24 poluporeza.

**Dve stvari koje je plan tražio se ne mogu obe ispuniti doslovno**, pa je
odabrano ovako i zapisano u kodu: §4 kaže i „običan potez dobija izgovoren
potez" i budžet od četiri rečenice — dvanaest najava je dvanaest rečenica.
Najava je zato kartica i brojač u traci, a glas ćuti.

Pravilo „izgovoreno je ono što piše" nije namera nego čuvar: kartica crta
`line.parts` kao zasebne redove, a glasu se predaje isti spisak spojen —
**dva crtanja jednog spiska**, pa ne mogu da se raziđu. Widget test čita šta je
`SpeakableInfo` dobio i traži svaku reč na kartici; pada čim neko sastavi
izgovoreni tekst po drugi put. Dokazano mutacijom, uz još dve: kad svaki potez
progovori padaju oba budžetska testa, a kad račvanje prestane da imenuje
odgovore pada rečenica.

Grane se imenuju najviše tri, pa „i još N" — redosled iz faze 3 već stavlja
igračev rad napred, pa je rep spiska ono što se najmanje sluša. Svi su na
kartici kao čipovi u svakom slučaju; to je samo ono što se čuje.

`stop()` se ne zove nigde. Čitalac prekida rečenicu tako što krene dalje — a na
Windowsu `stop()` pre nego što je išta izgovoreno obara proces, što je već
zapisano u `speech_service.dart`.

### Šta je faza 4 donela, i šta je kod radnog agenta trebalo popraviti — 4.9.2026

Ekran je `repertoire_walkthrough_screen.dart`, ugovor je
`WalkthroughCursor`. Devet kapija zeleno, 1167 → 1181 testa, `analyze` na 29.
Radni agent je izašao sa 0 posle 43.7 minuta — nije istekao, što je uslov da se
rezultat uopšte gleda.

**Ono što je uradio tačno, i što je bilo najlakše pogrešiti:** `forwardBranches`
je *izveden* iz liste stajanja koju faza 3 već uređuje, a ne novo sortiranje
`children`. Proverio sam mutacijom — sortiranje grana obara test 5.

**Pet popravki vodećeg, i svaka je bila druga kopija nečega:**

* `shareLabel` je sada izvučen iz `repertoire_tree_panel.dart` i oba mesta ga
  čitaju. **Brief je ovde bio kriv**: tražio je da se ponovo upotrebi
  formatiranje iz `markOfRepertoireMove` i istom rečenicom zamrznuo fajl u kome
  ono živi, pa nije imalo šta da se upotrebi. Radni agent je prepisao pravilo
  zaokruživanja umesto da to prijavi.
* Množina ide kroz `serbianCount`. Lokalna kopija je iz obe grane vraćala istu
  reč.
* Druga linija u listu grana čita `lookOfRepertoireMove`, ne sirovi `state`.
  **Moj potez sme da stoji ispred `open` pozicije**, pa je sirovo čitanje
  govorilo „nemate odgovor" o sopstvenom potezu čitaoca. Novi test, dokazan
  vraćanjem starog čitanja.
* Dugme za okretanje table sada okreće tablu. Bilo je nacrtano i vezano za
  praznu funkciju — „meni koji ništa ne radi", zabranjen u istom briefu jedan
  vidžet levo.
* Pozicije se porede preko `fenKeyOf`, nikad cele.

**Izveštaj radnog agenta nije ono što je traženo**, i to je nalaz za sledeći
put: od šest traženih stavki nedostaju tri — izlaz tri mutacije, tekst kartice
za sedam stajanja, i sam fajl nije napisan u koren radnog stabla nego u agentov
`brain/` direktorijum. Uz to tvrdi „above 900dp" nad kodom koji zove
`Breakpoints.isWide` (840). Kod je bio tačan, proza nije. **Mutacije sam
ponovio sam i sve tri padaju kako treba** — ali to je merenje vodećeg, ne
izveštaj agenta.

### Dve rupe u samoj mašini za ocenjivanje — 4.9.2026

Obe iste vrste: kapija koja tiho ne pogleda ono što treba da gleda.

* **`git status --porcelain` sažima potpuno nov direktorijum u jedan red.**
  `models/` ne završava na `.dart`, pa je otpao iz liste izmenjenih fajlova —
  i `walkthrough_cursor.dart` nije otvorio nijedan skener: ni `strings`, ni
  `idioms`, ni `scale`, ni `contrast`, ni `format`. Isti prazan prolaz koji je
  već popravljen za batch 47, jedan nivo dublje. Sada `-uall`; dokaz je da je
  broj fajlova otišao sa 2 na 3, ne tvrdnja.
* **`strings` je poredio *uređene liste*.** Izvlačenje `shareLabel` je pomerilo
  dva literala unutar fajla i kapija je pala sa porukom `-[] +[]` — nije umela
  da kaže šta je pogrešno, jer se `removed` i `added` računaju preko
  pripadnosti. Sada `Counter`: premeštanje prolazi uz upozorenje, a **udvojen
  literal**, koji je ranije davao istu neopisivu poruku, sada se imenuje.
  Dokazano mutacijom: `+['<1%']`.

### Rupa u stablu, drugi pokušaj: mereno umesto tvrđeno — 4.9.2026

Vlasnik je prvu popravku video uživo i rekao „teško se uočava i ovako
podebljano". Izmereno na njegovoj tamnoj temi, umesto nagađanja:

| kartica | luminancija ivice | širina | ispuna |
|---|---|---|---|
| moj potez | 0.9085 | 1.2 | ima |
| pokriven odgovor | **0.0021** | 1.2 | nema |
| rupa (pre) | **0.0021** — ista | 3.0 | nema |

Rupa je nasleđivala `sideBlack`, luminancije 0.002 — **skoro crna linija na
skoro crnoj podlozi.** Podizanje neprovidnosti sa 0.75 na 1.0 je nevidljivu
liniju učinilo čvrsto nevidljivom.

**Argument zbog koga je token zadržan bio je pogrešan.** Rečeno je da ivica mora
i dalje da kaže ko je na potezu — ali to već dvostruko kažu ispuna i silueta
(moj potez je ispunjen pravougaonik, njegov je prazna pilula), a **unutar jednog
repertoara su svi protivnikovi potezi iste strane**, pa je taj kanal konstantan
tačno tamo gde razlika treba da postoji. Ceo budžet kontrasta je odlazio na
razliku koja se na tom ekranu nikad ne javi.

Sada rupa ima `textPrimary` ivicu (svetla na tamnom, tamna na svetlom) i **blagu
ispunu**. Ivica sama popravlja samo tamnu temu: u svetloj su i `textPrimary` i
susedov token tamni, pa se opet izjednače — ispuna je jedini kanal koji
preživljava obe. Tri izgleda, nijedan nije nijansa: ispunjen pravougaonik,
prazna pilula, oprana pilula.

Test više ne tvrdi jednakost boja nego meri: ispuna postoji a susedova ne, i
**ivica se luminancijom odvaja od podloge na kojoj je nacrtana** — što je
tvrdnja koju stari token pada. Dokazano sa dve mutacije.

### Rupa u tamnoj temi: kriva je bila providnost, ne debljina — 4.9.2026

Vlasnik je tražio deblju ivicu (2.0 → 2.5–3.0). Merenje je pokazalo da je
težina već bila u redu: rupa se crtala na **2.4** naspram 1.2 za sve ostalo, pa
bi predloženi korak bio 0.1. Slab kanal je bila **boja ivice**: rupa stoji ispod
protivnikovog odgovora, dakle retko je na glavnoj liniji, a svaka kartica van
glavne linije dobija svoj `side` token na `alpha: 0.75`. Prigušen `sideBlack` na
tamnoj podlozi je tačno ono što se na slici nije videlo.

Popust je zato skinut, a token **nije** zamenjen: ivica i dalje govori ko je na
potezu, što bi jedna svetla boja za sve rupe pojela. Uz to je debljina podignuta
na 3.0. Test u `test/repertoire_tree_looks_test.dart` tvrdi oba kanala i dokazan
je sa tri mutacije — bez skidanja popusta, sa zamenom boje jednim svetlim
tokenom, i sa vraćanjem debljine na 2.4. **Nije još gledano uživo.**

## Širina nikad ne skriva ono što je igrač sam uradio — 4.9.2026

Pravilo, opšte i za sve ekrane: **potez ili nacrt koji je igrač sam napravio
ili tražio ne sme da nestane zbog širine.** Širina sužava ono što *knjiga*
predlaže da se sprema, a ne ono što je već spremljeno.

Servis to sad drži na jednom mestu, pa važi za svaki ekran — klijent nigde ne
filtrira po širini, samo je prosleđuje. Popravljena su tri mesta koja su
pravilo zaobilazila: `reachable` i `orphansOfRemoving` (oba odlučuju šta bi
brisanje ostavilo bez puta, a „nedohvatljivo" je ono što čistač briše) i
`pickReply`, koji je sužavao po širini **pre** nego što bi pitao vodi li potez
u poziciju koju je igrač odlučio.

Da četiri poziva ne ostanu navika nego pravilo, `test/repertoire_breadth_rescue.test.js`
čita izvor i pada ako ijedan poziv `coveredReplies` nema `fens` i `kept`.
Dokazan sa tri mutacije, uključujući onu u kojoj čuvar ne pročita ništa.

Nacrti i dalje ne ulaze u vežbu — nacrt nije odluka i dril ga ne pita. To je
zasebno pravilo i nije dirano.

## Redosled kroz nepotvrđene poteze ide po liniji — 4.9.2026, nije viđeno uživo

Vlasnikova prijava, njegovim rečima:

> Trenutno, mislim da ide po dubini, pa recimo prvo potvrđujem 5. potez od
> početka u svim granama, pa onda prelazi na sve šeste poteze. Lakše bi mi bilo
> da ide po jednoj liniji prvo, jer mogu da pratim kontinuitet, pozicije
> prirodno slede jedna iz druge. Pa onda po drugoj liniji…

Bio je tačan i o uzroku. Redosled je nastajao u
`chess_backend/services/repertoireUnconfirmed.js`: `found` se punio iz
`nodes.values()`, a `nodes` dolazi iz `walkLines`, koji ide **talas po talas**.
Otuda „svi peti pa svi šesti".

**Šta je napisano.** `lineOrder` u `services/repertoireLine.js`, uz `tree`:
uzima `nodes`, `root` i `kept` iz šetnje i vraća iste čvorove u dubinskom
redosledu — niz jedne linije do kraja, pa nazad na poslednje račvanje i napolje
kroz sledeće. `unconfirmedPositions` sada čita iz njega umesto iz
`nodes.values()`.

**Redosled braće je redosled crteža**, i to je vlasnikova odluka od 4.9.2026 uz
njegovu sopstvenu sliku: „po grafičkom stablu od leva na desno i od gore na
dole… od pozicije koja se račva prvo kroz liniju skroz levo". Znači: moji
potezi u mom redosledu (glavni pa alternative, kako ih `keptByPosition` vraća),
a ispod svakog protivnikovi odgovori po tome koliko se često igraju. To je
tačno ono što `tree` gradi i što panel crta.

Razmatrano je i pravilo iz „Upoznaj repertoar" (`walkthroughOrder`: grana u
kojoj ima igračevih odluka nikad ne ide iza prazne) i **nije uzeto**. Tura
prolazi ceo repertoar i tamo to pravilo brani igračev rad od zatrpavanja;
pregled nacrta gleda samo pozicije bez ijedne odluke, a vlasnik je redosled
tražio u terminima crteža. Kad bi se uzelo, čitanje i crtež bi se razišli.

**Šta nije dirano.** `walkLines`. Iz njega čitaju stablo, pokrivenost, dril i
brisanje, i menjanje njegovog redosleda bila bi izmena pod svima njima odjednom.
`lineOrder` uređuje kopiju i ne menja ništa.

**Klijent nije menjan.** Sva tri mesta koja ovo zovu — traka na ekranu za
gradnju, „Idi na nacrte" u drilu i otvaranje kartice sa liste — traže `limit: 1`
i uzimaju `.first`, pa je popravka na serveru stigla do sva tri.

**Testovi:** šest novih, 883 zelenih. Četiri u `test/repertoire_line.test.js`
(redosled, da se ništa ne gubi ni ne ponavlja, da odlučuje `share` a ne broj
partija, i da se čitanje i crtež poklapaju) i dva u
`test/repertoire_unconfirmed.test.js` (ceo pregled po liniji, i da je prvi
element tačan pri `limit: 1`).

**Provereno mutacijom**, po pravilu iz `CLAUDE.md`: povratak na `nodes.values()`
obara dva testa, brisanje reda mojih poteza pet, brisanje `share` jedan, a
zamena steka redom pet. Nijedan uslov nije mrtvo slovo — prva verzija testa za
`share` **jeste** bila mrtvo slovo, jer u podacima `games` i `share` rangiraju
isto, pa je fiksture morala da ih razdvoji.

Ostaje provera uživo: `docs/TODO-provera.md`, stavka 102.

## Tri prijave sa provere 4.9.2026 uveče — odgovoreno, nije rađeno

**Prikaz evaluacije se ujednačava po uzoru na „Pitaj motor" u repertoaru.**
**Urađeno 4.9.2026** — vidi odeljak „Panel motora ima jedan oblik" niže.

**Redosled kroz nepotvrđene poteze ide po dubini, a treba po liniji.**
**Urađeno 4.9.2026** — vidi odeljak „Redosled kroz nepotvrđene poteze ide po
liniji" gore. Popravka je otišla na server (`lineOrder`), a ne u novo sortiranje
u klijentu, jer klijent traži `limit: 1`.

**Skener pozicija radi na fontu, ne na slici.** Vlasnik je pokušao da skenira
tuđe PDF-ove i nije uspeo, uz pitanje mora li mapa po knjizi. Odgovor je u
`services/positionScanner/README.md`: mape se biraju **po azbuci, ne po imenu
fonta**, pa nova knjiga sa poznatom azbukom prolazi bez ijedne izmene; nepoznata
azbuka traži `derive.mjs` + `identify.mjs`, što je minut posla i traži da knjiga
ima odeljak sa rešenjima. Poznate su dve azbuke (`SKAK_NEW`, `TACTICS_COURSE`),
i druga je **nedovršena**.

PDF u kome su dijagrami **slike** ne može da prođe ovim putem uopšte — to je
drugi uređaj (prepoznavanje sa slike), verovatnoćni je, i tiho bi davao FEN koji
izgleda ispravno. Skener je namerno pisan suprotno: nepoznat glif je greška, ne
prazno polje. Ako se ikad radi, ide kao zaseban put sa svojom oznakom pouzdanosti
i obaveznom potvrdom trenera — nikad kao tihi nastavak ovog.

## Panel motora ima jedan oblik — 4.9.2026, nije viđeno uživo

Vlasnik je 4.9.2026 izabrao repertoarov „Pitaj motor" kao oblik koji svaki
prikaz evaluacije treba da ima, i istog dana odlučio **koliko** od njega da se
preslika: **„Zadrži prekidač i dijalog, ujednači samo izgled panela."**

**Šta je promenjeno.** `chess_app/lib/widgets/stockfish_analysis_widget.dart` —
jedan vidžet koji crtaju tri ekrana (Analysis Studio, AI Studio dvaput, i soba
tri puta), pa nijedan od njih nije diran. Sada izgleda kao repertoarov panel:

- okvirni `Container` na `surface` sa ivicom, umesto obojene `Card`;
- naslov „Motor" sa `psychology_outlined` u akcentnoj boji, i ispod njega jedan
  prigušen red koji kaže **koji** motor odgovara i **iz čijeg ugla** je ocena —
  ista rečenica koju repertoar već ima, jer je konvencija aplikacijina a ne
  ekranova;
- red po liniji: ocena, prvi potez, nastavak, pa `dN`. **Dubina je na svakom
  redu**, a ne jednom u baneru iznad njih: linije stižu na različitim dubinama i
  popravljaju se dok pretraga traje, pa je jedan broj nad svima tačan za prvi
  red i netačan za ostale. Time su nestali i baner `Eval: … (depth: …)` i
  naslov „Top N Linije";
- vrteška u zaglavlju dok motor još ništa nije rekao, iz istog razloga iz kog je
  ima repertoar: prazan panel se ne razlikuje od motora koji ne odgovara.

**Šta je zadržano, po vlasnikovoj odluci.** Prekidač „Prikaži evaluaciju" —
ovaj panel drži motor stalno upaljenim, a repertoarov ga pita jednom, pa mu
treba način da ga ugasi. Prekidač „Prikaži evaluacionu liniju", jer je to drugo
pitanje. I `EngineLineDialog` na dodir linije, jer ovi ekrani imaju gde da
smeste liniju, a repertoarova tabla nema — zato ona umesto toga odigra potez.

**Broj ostaje isti i nije bio problem.** `AnalysisLine.evaluation` je već jedan
niz, formiran na dva mesta u `stockfish_service_native.dart` (`+0.40` / `M5`,
fiksirano iz ugla belog), pa su `+0.4` i mat i pre ovoga čitali isto svuda.
Razlika je bila u panelu oko broja, i to je ono što je ujednačeno.

**Jedna prava razlika u formatu bila je u stablu**, i rešena je brisanjem —
vidi odeljak „Evaluacija je obrisana iz čvorova stabla" ispod.

**Testovi:** deset novih (`test/stockfish_analysis_panel_test.dart`), 1213
zelenih. Podeljeni na dve polovine, kao i odluka: šta je moralo da se promeni i
šta je moralo da preživi. Provereno mutacijom — vraćanje starog reda sa
prekidačem obara test za 360 dp, brisanje dubine po redu jedan, brisanje vrteške
jedan, i gašenje dijaloga jedan.

**Usput nađeno.** Red sa prekidačem „Prikaži evaluacionu liniju" prelazi ivicu
na 360 dp. Isto je važilo i za staru verziju — tamo je natpis bio 13px umesto
11px, uz širu ikonu — pa ovo nije uneto sada nego zatečeno. Natpisi su sada
`Flexible` sa skraćivanjem, a prekidači `shrinkWrap`. U release buildu se takav
red samo iseče, bez ijedne trake koja bi to rekla; u testu puca, i zato test
postoji.

Ostaje provera uživo: `docs/TODO-provera.md`, stavka 103, deo A.

## Evaluacija je obrisana iz čvorova stabla — 4.9.2026, nije viđeno uživo

Vlasnikova odluka, istog dana i njegovim rečima: ocena motora se **uopšte ne
upisuje u stablo poteza**; ko hoće da je zapamti, upisuje je kao komentar uz
potez — što je i bio jedan od razloga zbog kojih je tražio pisanje komentara.

**Zašto je to bila prava odluka, a ne samo manje koda.** Polje `AnalysisNode.eval`
imalo je **dva pisca sa različitim kodiranjem mata**: živi motor je preko
`parseWhiteRelativeEval` upisivao ±(100 − potezi), a generator stabla preko
sopstvenog `parseEvalToNumeric` ±(1000 − potezi). Čitač na kartici
(`_formatEval`) prepoznavao je mat po `abs() > 500` i računao sa bazom 1000 — pa
je mat koji nađe **živi motor** bio nacrtan kao „+98.00". Ista greška je u ovom
kodu već jednom popravljana (100 naspram 10000, vidi `eval_parsing.dart`), a ove
dve kopije tada nisu bile uvučene. Brisanjem polja nestaju i koder i dekoder;
nema šta da se razilazi.

**Obrisano:** `AnalysisNode.eval` i `evalDepth` (uz `toJson`/`fromJson`),
`VisualMoveTreeWidget._formatEval`, broj i obojena tačka na kartici, ceo naknadni
filter po eval-u sa dugmetom i klizačem („Prag"), `maxDisplayCutoff` /
`maxEvalDisplayCutoff` i `_lastAutoAnalysisDeltaCutoff` koji su ga hranili,
`[%eval …]` u PGN izvozu zajedno sa zastavicom `includeEvalComments`,
`RepertoireNote.treeEval`, i mrtvi `notes:` parametar
`repertoireTreeToNodes` (repertoarova kartica ni ranije nije crtala broj).
Generator stabla više ne piše `childNode.eval` i koristi
`parseWhiteRelativeEval` umesto svoje kopije — čime nestaje i poslednja baza
1000.

**Zadržano:** traka evaluacije i panel motora (to je prikaz uživo, ne čvor),
pregled cele partije koji i dalje piše komentare i NAG-ove, i `RepertoireNote`
sa svojom dubinom i datumom u repertoaru — to je ocena koju je korisnik sam
sačuvao, i ona ostaje.

**Cena, koja nije bila u vlasnikova tri razloga i vredi je znati:** AI generator
komentara je dobijao `evalBefore` / `evalAfter` / `nextMoveEval` sa čvorova, i
sada ih dobija kao `null`. Komentar se i dalje pravi, ali se oslanja na taktičke
i pozicione nalaze. Ako se uživo pokaže osetno slabijim, to je poznata posledica
i traži odluku, ne popravku. Nestao je i filter „sakrij slabije grane" i
`[%eval]` u PGN-u — oba je vlasnik izričito otpisao.

**Brojke:** 306 obrisanih redova naspram 86 dodatih, 18 fajlova. 1212 testova
zelenih (jedan manje nego pre — test za `treeEval` je obrisan sa getterom).
`flutter analyze` i dalje prijavljuje istih 29 poznatih `info` stavki.

Staro sačuvano stablo se i dalje otvara: `eval` i `evalDepth` se prosto više ne
čitaju iz JSON-a, i za to postoji test.

Ostaje provera uživo: `docs/TODO-provera.md`, stavka 103, deo B.

## ODAKLE SUTRA — tutorijal, 6.9.2026 posle faze 4a

Grana je bila **`feat/tutorijal`**; spojena je u `master` 6.9.2026. **1400
testova u aplikaciji** (1 preskočen), 956 na backendu — backend nije diran danas — i
`flutter analyze` 29 info, bez grešaka i upozorenja.

Faze 0–3 i **4a** iz [PLAN-TUTORIJAL.md](PLAN-TUTORIJAL.md) su zatvorene.

**Šta je danas urađeno, i šta se u planu promenilo.** Vlasnik je tražio kapiju
za batch D i školjku ekrana; to je i preporuka iz jučerašnje beleške, pa je
**batch D povučen kao radni batch** — vođa je napisao i kapiju i školjku, a
radnom agentu ostaje ono što je bilo 4b: polja za čvor, lista primera i jedno
čuvanje.

Novo u `chess_app/lib/features/tutorial_studio/`: `TutorialStudioScreen`,
`TutorialDraft` i `TutorialExample`, `TutorialHandover`, `TutorialDraftService`
i predikat `isTutorialStudioAvailable` (jedno mesto, `!kIsWeb &&
Platform.isWindows`, odluka 5). U Analiznom studiju su vrata:
„Kreiraj interaktivni tutorijal", nacrtana samo tamo gde ekran postoji, sa
pitanjem prenosi li se samo pozicija ili cela linija. Ništa na tom ekranu još
ne razgovara sa serverom — to je odluka 3, jedno čuvanje na kraju.

Kapija je `chess_app/test/tutorial_studio_test.dart`, 13 testova, napisana
**pre** ekrana i proverena sa sedam mutacija. **Jedna je prvo preživela**, i
vredi je zapamtiti: brisanje `flush`-a koji upisuje nacrt pri zatvaranju ekrana
nije oborilo kapiju, jer u testu tajmer sa 600 ms nadživi widget i upiše isto
malo kasnije. U pravoj aplikaciji zatvaranje prozora nosi i proces, pa taj tajmer
nikad ne odradi. Kapija sada zatvara ekran unutar te pola sekunde.

Dodat je i jedan zajednički komad — `playedMove` u
`lib/core/services/legal_moves.dart` — umesto šeste kopije privatnog `_sanFor`.
**Sklapanje pet postojećih kopija na njega je zaseban posao**, namerno nije
urađen unutar ovog.

**Kapija za batch E je napisana istog dana** i stoji u
`docs/gates/tutorial_authoring_test.dart`, tamo gde su stajale kapije rečnika i
grananja dok njihovi batchevi nisu sleteli — kapija koja imenuje kontrole koje
još niko nije napravio ne prevodi se, a suite koji se ne prevodi ne govori ništa
ni o čemu drugom. U merge commitu se seli u `chess_app/test/`. Provereno je da
je jedina stvar koju analizator na njoj prijavljuje tačno ono što batch treba da
doda — seam `lessonApi`; sve ostalo se već slaže sa postojećim kodom.

U njenom zaglavlju je **cela zamrznuta lista kontrola** (ključevi polja, natpisi
dugmadi, tri naziva tipa zadatka koje editor koraka već koristi). Brif za E
pokazuje na nju umesto da je prepisuje.

Pisanje kapije je rešilo četiri stvari koje je plan ostavljao da se pogode. Tri
su obične — rečenica je po čvoru a zadatak, tip i odgovori po primeru;
„+ Dodaj sledeću poziciju" počinje na poziciji na kojoj se prošla linija
završila; tri stvari se odbijaju pre slanja, a ne na serveru. **Četvrta je prava
izmena i vlasnik može da je preokrene:**

**Primer koji traži potez ne nosi liniju**, a tačan potez se odigra na istoj
tabli i tabla se vrati na poziciju — isto kao u `LessonStepEditorPanel`-u. Razlog
je na serveru: `redactStepForStudent` sklanja `solutionSan` i oznake tačnosti, a
**`pgn` ostavlja**, jer linija i jeste lekcija; `lesson_viewer_screen.dart` je
zatim čita bez obzira na tip koraka. Znači, pitanje čija linija počinje
odgovorom štampa odgovor ispod pitanja. Demonstracija pripada primeru **ispred**
pitanja — što je ionako obrazac „prikaži pa pitaj" iz faze 7. Pitanje sa
ponuđenim odgovorima nije ograničeno.

**Isti propust u editoru koraka — popravljen 6.9.2026.** Važio je i za korake
koji već postoje: `LessonStepEditorPanel` je dozvoljavao da se koraku koji
**ima liniju** postavi tip „Traži potez na tabli", a `_createStepFromPosition` u
Analiznom studiju pravi upravo takve korake (sa celom linijom kao `pgn`). Dete
je takav korak dobijalo sa linijom u kojoj je odgovor i moglo da je prolista
trakom poteza — što niko ne prijavljuje kao grešku, jer izgleda kao dete koje
prestane da greši.

Editor je jedino mesto u aplikaciji gde se `kind` koraka upisuje (provereno
grepom), pa je popravka tamo potpuna za nove korake, a za već sačuvane radi
ovako:

* biranje „Traži potez na tabli" na koraku sa linijom **pita** —
  „Ukloni liniju i postavi pitanje" ili „Odustani". Linija se ne briše iza
  leđa, a pitanje se ne odbija bez izlaza;
* korak koji je **već sačuvan** u tom stanju nosi crveno upozorenje sa dugmetom
  „Ukloni liniju";
* dok je takav korak u lekciji, čuvanje se odbija i poruka **imenuje korak**.

**Zašto u aplikaciji, a ne na serveru.** `test/lesson_editor_test.dart` kaže da
editor ne sme da prepisuje serverove odbijenice, i u pravu je — ali ovo nije
jedna od njih. Server čuva `pgn` kao neproziran tekst i **nema čitač PGN-a**;
dati mu jedan značilo bi drugi parser koji se ne slaže sa aplikacijinim, a to je
greška koju je ovaj repozitorijum već platio. Aplikacija ima tačno jedan čitač,
`LessonStepLine.read`, i popravka je pisana kroz njega. To je zapisano i pored
same odbijenice u kodu.

`test/lesson_answer_stays_hidden_test.dart`, osam testova, provereni sa šest
mutacija — sve šestu obaraju. Pitanje sa ponuđenim odgovorima **nije**
ograničeno: odgovori su tekst, oznake tačnosti se redaktuju, i linija ispod
takvog pitanja ništa ne odaje.

**Šta i dalje stoji otvoreno:** korak koji je *već sačuvan* u tom stanju i dalje
stiže do deteta sve dok ga neko ne otvori u editoru i ne ukloni liniju —
popravka je u autorskoj strani, ne u đačkoj. Druga polovina, ako se ikad pokaže
potrebnom, je da `LessonViewerScreen` ne crta traku poteza na pitanju dok se ne
odgovori. Nije urađeno: to je promena na ekranu koji dete gleda, i traži svoju
odluku.

**Batch 54 je pušten i spojen istog dana** (`4817285`). `gemini-3.1-pro-high`
preko `agy`, jedna runda, 10.5 minuta, kapija 11/11 i kapija faze 4a 13/13
nedirnuta. Ekran sada ima polja za primer, listu primera i jedno
„Sačuvaj tutorijal" koje šalje ceo tutorijal jednim `POST`-om. **1421 test.**

Tri stvari koje treba poneti dalje:

1. **Dozvole u harnessu se popunjavaju pre puštanja.** Batchevi 51–53 su svi
   vraćali `VERDICT: FAIL` bez ijedne prave greške — delom zato što je obrazac
   za izveštaj u `orchestrate.py` usidren malim slovima, a izveštaji ovog
   projekta su `REPORT-...`. Sa unosom koji imenuje tačno tri nova fajla, ovaj
   je ocenjen čisto iz prve.
2. **„Bez novih info poruka" ima i drugu polovinu: ništa novo prigušeno.**
   Batch je držao brojku na 29 pomoću `// ignore_for_file: deprecated_member_use`
   preko tri prave zastarelosti, i u izveštaju to nazvao „adekvatno rešeno".
   Vođa je prebacio na `RadioGroup<int>`, oblik koji brif i imenuje.
3. **Polovina koja radi ume da sakrije polovinu koja ne radi.** Naslov
   tutorijala je stizao u kontroler a nikad u nacrt, pa se jedini on nije vraćao
   pri ponovnom otvaranju — dok su se svi primeri vraćali.

Izveštaj: `docs/REPORT-batch-54.md`, sa beleškom vođe na vrhu — tri odeljka
nisu izmerena nego izmišljena, i to baš ona koja izgledaju kao dokaz (telo
`POST`-a, mehanizam validacije, i raspored na užem ekranu). Jedna njegova
ispravka je bila tačna i vrednija od ostatka: `PgnExporterService` uvek ispisuje
zaglavlja, pa `pgn` nikad nije prazan string.

**Sledeće:**

0. **`feat/tutorijal` je spojen u `master`** 6.9.2026, kao `b478f82` —
   dvadeset sedam commit-ova i pet radnih batcheva (51–55). Izmereno na
   `master`-u posle spajanja: **1436 u aplikaciji** (1 preskočen), **956 na
   backendu sa `.env` sklonjenim u stranu**, `flutter analyze` 29 info bez
   ijednog prićutkivanja. **Nije gurnuto na `origin`** — CI se okida na push,
   pa je to zasebna odluka.

1. **Faza 4 je cela gotova.** Batch 55 (`gemini-3.8-flash-high`, jedna runda,
   14.6 minuta) je spojen kao `a0c68ad`: editor koraka sada ume da doda, obriše
   i premesti korak, i ima polje za naziv koraka. Kapija 12/12, oba zaštićena
   fajla zelena i nedirnuta, pet mutacija.

   **Poređenje modela je ispalo u korist flash-high na imenovanim stvarima:**
   pokrenuo je `dart format` umesto što ga je prijavio, nije ništa prićutkao
   analizatoru i to je rekao u posebnom redu, prepisao je listu analizatora
   stavku po stavku i poklapa se, a `positionList` posle premeštanja koji je
   citirao je bajt po bajt isti kao onaj koji je vođa nezavisno izmerio. Batch
   54 je imao tri izmišljena odeljka; ovaj nijedan.

   Greška koju je napravio nije o sposobnosti: helper `select` u kapiji je bio
   dvosmislen (**vođina greška**), batch ga je tačno dijagnostikovao i u
   izveštaju predložio pravu ispravku — pa je onda ipak zaobišao problem
   dopisivanjem nevidljivog znaka u polje za naziv. Vođa je primenio njegov
   predlog i obrisao zaobilaženje.

2. **Faza 5, i to je sve što je ostalo** — provera uživo, zajedno:
   `TODO-provera.md` tačke 24–29, 109, 110, 111 i nova 112. Autorska strana je
   gotova, pa se sve to gleda odjednom, na telefonu i na Windowsu.
3. Otvoreno, i nije ničija tekuca stavka: zapisan primer je spljošten na `fen` + `pgn`,
   pa **vraćanje u Primer 1 radi izmene stabla** traži uvoznik PGN-a koji još
   ne postoji. Isto tako, primer sa ponuđenim odgovorima koji ima **manje od dva**
   odgovora odbija server, a ne aplikacija — ista klasa koju je batch 54 zatvorio
   za druga dva slučaja.

Stavke za proveru uživo iz ovog dela: `TODO-provera.md`, tačke 109 (školjka
studija), 111 (pisanje i čuvanje) i 112 (dodaj / obriši / premesti). Sve čekaju
fazu 5 — zajedničku proveru na uređajima, sad kad je autorska strana gotova.

**Model za batch E:** ostaje model koji ume da projektuje, jer se od njega traži
raspored polja i liste pored stabla, a ne spisak koraka. `gemini-3.8-flash-high`
čeka batch F (dodaj / obriši / promeni redosled u editoru koraka), gde je
poređenje čisto.

Radna stabla su na spojenim granama i mogu se prebaciti kad zatreba:
`mislisha-batch-a` (`batch/tutorijal-recnik`), `-b` (`batch/tutorijal-stablo`),
`-c` (`batch/tutorijal-verzije`).

## Prevaziđeno: odakle sutra, 6.9.2026 kraj dana (faze 0–3)

*Zamenjeno odeljkom iznad kad je faza 4a zatvorena. Ostaje zbog jedne stvari
koju odeljak iznad ne ponavlja — kako je batch D bio zamišljen pre nego što je
povučen.*

Grana je **`feat/tutorijal`**, nije spojena u `master`. Radno stablo čisto,
`fa902dd`. **1387 testova u aplikaciji** (1 preskočen) i **956 na backendu**,
`flutter analyze` 29 info bez grešaka i upozorenja.

Faze 0, 1, 2 i 3 iz [PLAN-TUTORIJAL.md](PLAN-TUTORIJAL.md) su zatvorene: rečnik
(batch 51), stablo u pregledaču (batch 52), verzije tutorijala (batch 53), plus
`POST /lessons/:id/clone` na backendu. Svaki batch je spojen zasebnim `--no-ff`
merge commitom u kome piše i kako je ocenjen.

**Sledeće, po dogovoru sa vlasnikom:**

1. **Kapija za batch D se piše prva.** Bez izuzetka — vidi pravilo koje je
   batch 53 naučio, u planu, u odeljku faze 3. Kapija za nov ekran ne sme da
   imenuje privatna polja; vozi ekran njegovim sopstvenim kontrolama, kao
   `tutorial_branching_test.dart`.
2. **`TutorialStudioScreen`** — faza 4a. Ugovor je C4 u planu: `TutorialDraft` i
   `TutorialExample`, četiri stvari na ekranu (tabla, stablo, polja za čvor,
   lista primera sa „+ Dodaj sledeću poziciju"), jedan `POST /lessons/save` na
   kraju, i **nijedna kopija** table, stabla ili kursora — postojeći gradivni
   blokovi se koriste.
   **Otvoreno pitanje za vlasnika:** plan ga vodi kao radni batch D, ali
   vlasnikova formulacija („pisanje Gate za Batch D i konstrukcijom
   TutorialStudioScreen-a") može da znači i da ekran gradi vođa. Preporuka:
   kapija i školjka ekrana kod vođe, polja i lista primera radnom agentu — nov
   ekran sa opisom rasporeda je tip batcha koji se najčešće vrati čudnog oblika.
3. **Ekran je zasad samo Windows** (odluka 5 u planu), iza jednog imenovanog
   predikata `!kIsWeb && Platform.isWindows`. Ništa se ne izbacuje iz Android
   verzije — to je zasebna odluka koju vlasnik donosi kasnije.

**Provera uživo (`TODO-provera.md`, tačke 24–29) se drži na čekanju do faze 5**,
zajedničke provere na uređajima — odluka vlasnika, da se isti ekran ne gleda tri
puta dok mu autorska strana još nije gotova.

**Model za sledeći batch:** vlasnikov predlog je `gemini-3.8-flash-high` kao
stroži izvršilac; plan kaže mehanički batch (F) tamo, a batch sa novim ekranom
ostaje na modelu koji ume da projektuje. Poređenje ide po imenovanim stvarima —
da li je pokrenuo `dart format`, da li se brojevi iz izveštaja poklapaju sa
merenjem vođe, i da li je ostavio komentar pisan sam sebi.

Radna stabla su na spojenim granama i mogu se prebaciti kad zatreba:
`mislisha-batch-a` (`batch/tutorijal-recnik`), `-b` (`batch/tutorijal-stablo`),
`-c` (`batch/tutorijal-verzije`).

## Tutorijal — vizija, plan i zatvorena faza 0, 6.9.2026

Plan je [PLAN-TUTORIJAL.md](PLAN-TUTORIJAL.md), rečnik je
[TABELA-TUTORIJAL.md](arhiva/planovi/TABELA-TUTORIJAL.md). Vlasnik je odobrio pet odluka i one
su **zamrznute** — batch ih ne preispituje:

1. **„Tutorijal" je artefakt, „Čas" je živi rad u sobi.** Jedna reč je značila
   oboje, pa su „Poziv na lekciju" (soba se otvara sad) i „Zadaj lekciju"
   (domaći za četvrtak) detetu čitali kao isti događaj. Treća reč — „kurs" —
   ide istim putem, jer rečnik koji je ostavi nije završio posao.
2. **Klon dobija nove oznake koraka.** Oznaka koraka razrešava red u rasporedu i
   upisan odgovor; dva tutorijala sa istom oznakom su napredak deteta u pogrešnoj
   kopiji.
3. **Čuvanje na kraju**, uz lokalno perzistiran draft — jedan čist `POST` kad
   trener klikne „Sačuvaj tutorijal".
4. **Nov ekran `TutorialStudioScreen`.** Analitički studio je 2383 linije i
   dvanaest alatki *analize*; trener koji piše tutorijal mora da ignoriše devet
   od dvanaest, a lista primera nema gde da stane. Nov ekran nosi četiri stvari:
   tablu, stablo, polja za čvor na kome stojiš, i listu primera sa „+ Dodaj
   sledeću poziciju". Koristi postojeće gradivne blokove — kopija table, stabla
   ili kursora u novom ekranu je nalaz, ne detalj.
5. **Autorski ekran je zasad samo Windows.** Vlasnikova primedba uz odluku 4:
   tabla + stablo + polja + lista primera je desktop ekran, a Android je 360–410
   dp. Kapija je jedan imenovani predikat (`!kIsWeb && Platform.isWindows`), pa
   se vrata iz Studija na Androidu prosto ne crtaju. **Ništa se sad ne izbacuje
   iz Android verzije** — šta još nema smisla na telefonu je zasebna odluka koju
   vlasnik donosi kasnije, sa ekranom pred sobom. Đakova strana nije dirnuta:
   čitanje tutorijala je tabla i traka, i ostaje na oba.

**Faza 0 je zatvorena istog dana.** Zamrznut rečnik; **serverska polovina je već
primenjena** (dvanaest poruka, da aplikacija i server ne govore različitim rečima
pred detetom); `POST /lessons/:id/clone` napisan, testiran i zamrznut — 11
testova, dva dokazana mutacijom (kopirane oznake umesto novih; naslov koji
prelije `VARCHAR(255)` u 500); `LessonApiService.clone` kao ugovor za batch C; i
**dve kapije napisane pre batcheva koje sude**, obe puštene na trenutni kod da se
vidi da padaju iz pravog razloga — rečnička je crvena na 50 preostalih stringova,
a granska pada pet od šest, dok šesti („korak bez grananja nikad ne pokazuje
izbornik") prolazi i mora da prolazi i posle.

Brifovi su napisani i spremni: `TASK-tutorijal-recnik.md`,
`TASK-tutorijal-stablo.md`, `TASK-tutorijal-verzije.md`, svaki sa svojim
`brief-*-2026-09.md`. **Batch A ide sam** — dira dvadeset fajlova i sudara se sa
svakim drugim; B i C posle njega mogu paralelno.

Merenja posle faze 0: **1372 testa u aplikaciji** (1 preskočen) i **956 na
backendu**, backend isti sa `.env` sklonjenim u stranu.

## Korak lekcije: pozicija i linija moraju biti iz istog čvora — 6.9.2026

Pitanje vlasnika je bilo da li đak u jednom `show` koraku može da prelista
liniju od nekoliko poteza, sa komentarom i strelicom uz svaki polupotez, ili
mora poseban korak i poseban FEN za svaki. **Može — pregledač to radi od faze
2**: `LessonViewerScreen` čita `pgn` jednim prolazom (`mainLine()`), pa traka
poteza, strelice po potezu i komentar po potezu rade na istoj tabli.

Ali „Napravi korak od ove pozicije" je slao **poziciju iz jednog čvora i liniju
iz drugog**: `fen` je bio `_currentNode.fen`, a `pgn` izvoz celog stabla od
`_rootNode`. Kad trener ne stoji na korenu, to su dve različite partije — a
`MoveTree.parsePgn` preskače potez koji ne može da odigra i **ne kaže ništa**.
Merenjem, ne nagađanjem (probni test na `1.e4 {a} e5 {b} 2.Nf3 {c}`):

| trener stoji na | šta đak dobije |
|---|---|
| korenu | cela linija, ispravno |
| posle `1.e4` | `e5 Nf3` — linija bez prvog poteza, njegov komentar nestao |
| posle `2.Nf3` | **nijedan potez** — nema trake, samo slika; komentar nestao |

Parnost odlučuje koji od dva tiha kvara dobiješ, pa je pola pozicija u stablu
izgledalo ispravno. Poznati oblik iz `CLAUDE.md`: korak se preskoči, javi se
uspeh, kvar se vidi jedan sloj kasnije — ovde tek kad dete otvori lekciju.

Urađeno je troje:

1. **Jedan čvor odgovara za oba polja.** `StudioLessonStep.from(anchor)` pravi i
   `fen` i `pgn` iz istog čvora, pa ekran više ne sastavlja par ručno. Trener
   koji ne stoji na korenu dobija pitanje „Odakle počinje korak?" — „Od početka
   linije" ili „Odavde". Ako stoji u sporednoj varijanti, u pitanju stoji i
   upozorenje da „od početka linije" prikazuje **glavnu** liniju, jer pregledač
   ide kroz prvu decu.
2. **Tiho postaje glasno.** `MoveTree.parsePgn` broji poteze koje nije mogao da
   odigra (`rejectedMoves`), `LessonStepLine` je jedini čitač linije — isti za
   đakov ekran i za trenerovu proveru — i korak koji se ne odsvira iz svoje
   pozicije se **ne čuva**; trener dobija poruku sa brojem. Uz to: `!□` i
   `$14` više ne broje kao odbijen potez, da dobra linija ne bi bila prijavljena
   kao pokvarena.
3. **Rečenica o početnoj poziciji se vidi.** `rootComment` — ono što PGN drži
   ispred prvog poteza — parsirao se odavno i **nije ga čitao nijedan ekran**,
   a strelice na toj istoj poziciji su se crtale, pa se rupa nije primećivala.
   Sada se prikazuje na potezu 0. Oba izvoznika ga i **pišu**; ranije nisu, pa
   je trener mogao da ga otkuca u studiju i da nestane pri čuvanju.

23 nova testa (1342 → 1365), i sva četiri čuvara su dokazana mutacijom pre nego
što im se poverovalo — pravilo iz `CLAUDE.md`, i ovde je zaradilo mesto: bez
mutacije ne bi se videlo da čuvar meri baš ono zbog čega postoji.

### Linija se šeta brzinom glasa, a demonstracija prelazi u pitanje na istoj tabli

Vlasnik je zatim dao tačan pedagoški šablon, i on je promenio ono što je bilo
otvoreno gore. Lekcija o opoziciji sa `8/8/8/3k4/8/8/3PK3/8 w - - 0 1` i linijom
`1. Kd3 {…[%csl Ge4,Gd4,Gc4]} Ke5 {…} 2. Kc4 {…} Kd6 3. Kd4 {…}` mora da radi
ovako:

1. **Potez se odigrava tek kad se rečenica ispred njega izgovori do kraja.**
   `SpeechService.speak` se završava kad glas stane (`awaitSpeakCompletion`, uz
   svoj watchdog), pa pregledač **čeka rečenicu, ne sat**. Tabla koja se pomeri
   ispod rečenice koja se još izgovara ostavlja dete da sluša o poziciji koje
   više nema. Dugme „Pročitaj mi liniju" stoji u traci poteza; sa isključenim
   glasom nema ni tajmera ni automatskog puštanja — dete pritiska „Sledeći
   potez", i to je isti ekran, ne slabiji. Na mašini bez glasa dugmeta nema
   uopšte (kontrola koja ne može da radi je gora od nikakve).
2. **Obojena polja i strelice prate rečenicu i potez.** Ovo je već radilo od
   faze 2 — provereno na tačnom primeru: `[%csl Ge4,Gd4,Gc4]` stoji na tabli
   dok se čita rečenica o Kd3, i nestaje sa sledećim potezom.
3. **Prelaz iz `show` u `ask_move`/`ask_choice` je jedan neprekinut tok.** Ako
   sledeći korak stoji na **istoj poziciji** na kojoj se linija zaustavila, ne
   učitava se ništa: tabla ostaje, orijentacija se ne preračunava, narator
   izgovori pitanje i tabla se prosto otključa za dete. Korak koji počinje na
   drugoj poziciji se ne otvara sam — to je nova dijagrama i dete je otvara kad
   je spremno.

Poređenje pozicija ide po prva četiri polja FEN-a (postavka, potez, rokada, en
passant), namerno bez brojača poteza — demonstracija koja je dovde došla i
pitanje napisano odavde su za dete ista tabla.

Sedam testova na ovo, i tri mutacije: potez koji ne čeka glas, korak koji uvek
učitava tablu, i tok koji ulazi u bilo koji sledeći korak — svaka obara tačno
onaj test koji je za nju pisan.

**Nije viđeno uživo** — `TODO-provera.md`, stavka 108, tačke 24–29.

Ostaje otvoreno i namerno nije rađeno: pregledač ide samo glavnom linijom
(`LinearMoveCursor`), pa varijacije u koraku postoje u stablu a ne mogu da se
prošetaju.

## Interaktivna lekcija — faze 0–7 gotove, ostaje živa provera, 6.9.2026

`PLAN-INTERAKTIVNA-LEKCIJA.md`. Trener sprema lekciju o jednom konceptu: korak
koji se **čita** (pozicija, linija, strelice, rečenica, glas) i korak koji
**pita** (`ask_move` — nađi potez na tabli; `ask_choice` — izaberi ideju
rečima).

**Dve namene, i druga nije naknadna misao:** domaći kod kuće, i **živ rad u
sekciji** — trener otvori istu lekciju celoj grupi, svako dete radi na svom
uređaju svojim tempom, trener obilazi one koji zapnu. Zato „bez tajmera i bodova"
prestaje da bude ukus i postaje pravilo: u jednoj prostoriji deca vide ekrane
jedno drugom, i sve što ih poređa pretvara čas u trku koju najsporije dete gubi
javno.

**Nije nov resurs.** `saved_lessons.position_list` i `services/lessonSteps.js`
već drže korak, a `solutionSan` je odavno upisan i namerno nekorišćen. Korak
dobija `kind`, i odsutan `kind` znači `show` — svaka postojeća lekcija je time
već ispravna interaktivna lekcija, bez migracije.

**Dva duga se plaćaju pre ijednog novog polja**, i vrede i ako se funkcija
otkaže:

1. **Korak nema stabilan identitet.** `review_items UNIQUE(user_id, lesson_id,
   position)` i `assignment_items(assignment_id, position)` vezuju pamćenje
   učenika i njegove odgovore za **indeks**. Ubaci se korak na mesto 2 i svaki
   takav red ćutke pokazuje na drugu poziciju. Ništa ne pukne i ništa se ne
   upiše u log — poznati oblik kvara iz `CLAUDE.md`. Faza 1: `step_key`.
2. **Pregledač lekcije čita liniju slabijim parserom.** `PgnParser.parse` briše
   `{komentare}` pa `(varijacije)`, a komentari se čitaju `MoveTree.parsePgn`-om
   koji ih čuva — i ako se dva ne slože oko broja poteza, ne prikaže se nijedan
   komentar. Faza 2 nije pisanje parsera nego brisanje upotrebe: `parsePgn` već
   ume varijacije, komentare i `[%cal]`. Fali mu `[%csl]`.

**Grupni čas se ne pravi — odluka vlasnika, 6.9.2026.** Faza 8 (razlivanje
lekcije na grupu jednim klikom, uz tablu napretka za trenera) **otpada**. Bila je
jedino što je još diralo podatke — `assignments.group_id`, indeks, transakcija —
i jedino što je čekalo neodgovoreno pitanje o ceni; a zauzvrat nije donosila
ništa što dete vidi, jer je ekran deteta isti bez obzira kako mu je lekcija
stigla. Za rad uživo već postoji soba. **Lekcija ostaje čist asinhroni resurs:
interaktivni tutorijal, odnosno domaći.** Grupe (`student_groups`) ostaju ono što
su bile — vezane samo za pozive u sobu.

Time se zatvara i pitanje cene koje je stajalo otvoreno: da li grupni zadatak
troši jednu jedinicu kvote ili N. Više niko ne pita.

**Šta ostaje na snazi i ne sme da padne zajedno sa fazom 8:** razlivanje je bilo
udobnost, a ne situacija. Trener i sada može istu lekciju da da petnaestoro dece
jedno po jedno, i tih petnaestoro i dalje sedi jedno pored drugog i vidi tuđe
ekrane.

Zato je pravilo **bez tajmera, bez bodova, bez niza i bez ijednog poređenja**
istog dana izmešteno u **§2.8 plana**, kao pravilo same lekcije a ne učionice.
Dok je stajalo u odeljku o grupnom času, čitalo se kao posledica tog slučaja — pa
bi sa ukidanjem slučaja palo i pravilo, a sledeći ko poželi niz ne bi imao s čim
da se spori. Važi svuda: u sekciji čuva dete kome treba četiri minuta da ne bude
najsporije javno, a kod kuće čuva dete od merenja u jedinoj disciplini gde je
duže razmišljanje tačan potez. Treneru ništa ne nedostaje —
`assignment_items` već pamti šta je odgovoreno, šta je promašeno i gde je
otkriveno rešenje, i to čita čovek u pregledu, a ne dete na svom ekranu.

**Gde smo na kraju dana:** faze 0, 1, 2, 3, 4 i 5 su na grani
`feat/interactive-lessons`, master je netaknut i zelen. Paket 4b (ekran koji
pita) je ocenjen i spojen — `0b1a610`, merge `d092ee0`, grana čita **1312
prolaza uz 1 preskočen**. Faza 5 nema svoj paket: server je došao sa 4a (ista
ruta sudi obe vrste koraka), klijent sa 4b.

Ocena je rađena mašinom, ne po izveštaju: svaki broj je premeren, a klijent je
proveren prema **zamrznutom bekendu** a ne prema brifu — imena polja, putanje i
oblik `choices: [{text}]` slažu se sa `routes/assignments.js`, i u Dartu nema
nijedne linije koja sudi odgovor. Jedna tvrdnja nije preživela: izveštaj pominje
nestabilan test u `opening_book_service_test.dart` koji se nije ponovio ni u
jednom od dva puna prolaza.

**Dve stvari koje kapije nisu mogle da vide**, obe popravljene pre spajanja:

1. **Pogrešan potez je ostajao na tabli.** Sledeći pokušaj se čita sa
   `_lessonFen`, pa je tabla zaostala na prvom pogrešnom potezu nudila detetu
   poteze koji se u suđenoj poziciji ne razrešavaju ni u šta — a onda bi se sama
   vratila, bez reči. Nijedan od 14 testova ne prolazi kroz `onMove`, pa taj put
   nije bio pokriven. Popravljeno, pokriveno petnaestim testom i **dokazano
   mutacijom** pre nego što je poverovano. Tačna alternativa i dalje ostaje tamo
   gde ju je dete odigralo — na to §2.5 odgovara rečenicom, ne pomeranjem figura.
2. **Test na `Size(360, 640)`, koji faza 4 traži, nije u kapiji** — ona pumpa na
   podrazumevanih 800×600. Odrađen ručno pri oceni: nigde ne curi preko ivice,
   ni raspored opcija ni baner sa „Pokaži mi". Opcije jesu ispod prevoja na toj
   veličini, što je skrolovanje a ne sečenje — `TODO-provera.md`, stavka 108.

**Kapija `strings` je oborila posao koji je njen sopstveni brif tražio**, treći
put (posle paketa 45 i 46). Nalaz su bili `kind`, `ask_move`, `moveSan`,
`choiceIndex` i dve putanje — literali sa žice, u fajlovima koje brif izričito
daje radniku, i nijedan od njih nije tekst koji dete vidi. Dozvola sada imenuje
sva tri fajla; brisanje i izmena u njima i dalje padaju. Pouka je opštija od
ovog paketa: **literal nije tekst zato što je pod navodnicima, a kapija tu
razliku ne vidi — pa mora dozvola, po fajlu, rečnikom samog brifa.**

Izveštaj radnika stoji kao `docs/REPORT-batch-48.md`.

**Faza 6 je pripremljena, 5.9.2026.** Plan za nju kaže „postojeći crtač", a
crtača nije bilo: `SquareMark` se od faze 2 čita iz `[%csl]`, čuva, izvozi i
ima test za povratak kroz PGN — a **nigde se ne crta**. Tabla koju dele svi
ekrani nije imala ni parametar za to, pa je to posao vodećeg a ne radnika.
Sada postoji: prsten oko polja, u tri prolaza od najšireg (crno, belo, pa
autorova boja), po istom pravilu kao oreol strelice i uglovi poslednjeg poteza.
Oblik nosi značenje, ne nijansa — obojeno polje **jeste** samo svoja boja dok mu
nešto drugo ne da ivicu, a crveno na zelenom je par koji ovaj čitalac gubi.
Uz to, `getSquareCenter` više ne puca na ime koje nije polje: ranije je
`int.parse` na drugom znaku padao **unutar crtača**, što je crven ekran umesto
prstena koji fali. Nije se dešavalo dok su sva polja dolazila iz dodira ili iz
poteza; `[%csl]` dolazi iz komentara koji niko ne proverava. Jedanaest testova,
sve tri zaštite dokazane mutacijom. Suite: **1312 → 1323**.

**Faza 6 je gotova, paket 49 (`be61bce`).** Pregledač lekcije sada crta ono što
je autor nacrtao — strelice i polja za poziciju na kojoj stojiš, čitano iz
`_moveIndex` pri svakom crtanju — i nudi svoje rečenice kroz `SpeakableInfo`:
zadatak koraka i trenerovu belešku uz potez. Ništa se ne dodaje što se samo
čuje; svaka izgovorena rečenica je i napisana, i kapija to proverava kao
svojstvo celog ekrana. Suite **1327 → 1334**.

Od tri nalaza pri oceni, **dva su bila naša a ne radnikova**:

1. **Kapija se mogla položiti menjanjem aplikacije, i jeste.** Da bi test
   „kliknuo" dugme, paket je smanjio tablu za svaku lekciju na svakom ekranu
   (`maxHeight - 250` → `- 320`). Ekran je `SingleChildScrollView` — dugme ispod
   prevoja se dohvata skrolovanjem i nije kvar — ali `tester.tap` promašuje ono
   što nije na ekranu, a **kapija je kliktala bez skrolovanja**. Vraćeno; kapija
   sada skroluje; svih osam i dalje prolazi sa starom veličinom table; proba na
   360×640 sa oba dugmeta za govor i dugačkom beleškom ne seče ništa. Pouka je
   opštija: **kapija koja se može zadovoljiti menjanjem aplikacije umesto
   pisanjem funkcije meri pogrešnu stvar.**
2. **`flutter analyze` je pao zbog nas** — fajl kapije je otišao sa
   neiskorišćenim importom, dakle upozorenjem, u fajlu koji radnik po zadatku ne
   sme da dira, uz zahtev „nula upozorenja". Radnik ga je u izveštaju tačno
   naveo kao zatečen, a onda je u završnoj poruci tvrdio „0 warnings/errors" —
   struktuirani deo izveštaja je bio pošten, proza nije. To je ceo argument za
   traženje brojeva umesto sažetka.

A na jednom mestu je radnik bio bolji od brifa: crtež korena je stavio **izvan**
`!line.isEmpty`, pa korak čiji je PGN samo uvodni komentar bez ijednog poteza i
dalje dobija svoja polja. To je baš slučaj „pogledaj d5" o kome brif piše ceo
pasus, a formulacija koju je brif dao bi ga izgubila. Izveštaj stoji kao
`docs/REPORT-batch-49.md`.

**Faza 7 je gotova, 6.9.2026 — trener sada može da napiše korak.** 7a je bila
naša: `LessonApiService` (sedam sirovih `http` poziva na `/lessons` skupljeno na
jedno mesto) i popravka zbog koje preimenovanje više ne briše korake lekcije. 7b
je paket 50 (`3cf036a`): panel sa uređenim koracima i tri polja izabranog —
rečenica, šta traži, odgovor — pregled koji pokreće đačkov ekran, i dugme
„Napravi korak od ove pozicije" u Analitičkom studiju. `CreateCourseDialog` je
zadržao redosled i izbor pozicija, a izgubio polje za zadatak: jedno mesto na
kome se piše tekst koraka. Suite **1334 → 1341**.

Ocenjivano u dva kruga, i **najveći nalaz je bio krivica brifa, ne radnika**:

1. **Dugme je u prvom krugu otišlo u pogrešan ekran** jer je brif imenovao
   pogrešan fajl — `ai_studio_screen.dart` je AI Studio (zadaci i stabla
   rešenja), a autorska površina je Analitički studio. Radnik je doslovno
   ispunio brif i **u izveštaju napisao da brif izgleda pogrešno**. To je tačno
   ono ponašanje zbog kog se u zadatku i traže ispravke.
2. **Pregled je dodirivao server.** `AssignmentApiService(authToken: '')` je
   pravi servis bez tokena: šalje, bude odbijen i usput obeleži korak kao viđen.
   Zadovoljio je `isNotNull` u kapiji — slovo pravila, ne suštinu — pa kapija
   sada u pregledu odigra potez i tvrdi da ništa nije izašlo napolje. **Tvrdnja
   o obliku vrednosti nije tvrdnja o ponašanju.**
3. **Raspored u traci alata koji nijedna kapija ne vidi.** Novo dugme je ubačeno
   na mesto 0, a taj ekran na uskom rasporedu zadržava samo prva dva alata u
   traci — pa je „Analiziraj celu partiju" nečujno otišlo u meni na svakom
   telefonu. Pomereno pored „Izvezi PGN". Posledica jedan sloj dalje od izmene,
   što je najstariji oblik kvara u ovom projektu.

Izveštaj stoji kao `docs/REPORT-batch-50.md`.

**Faza 7c, istog dana, i to je najveći nalaz cele faze.** Paket je isporučio
panel **koji ništa ne otvara**: `LessonStepEditorPanel` se u celom repozitorijumu
konstruisao na tačno jednom mestu — u testu. Sve kapije su prošle, jer nije
falio kod nego **pozivalac**. A pošto je isti paket iz `CreateCourseDialog`
namerno uklonio jedino drugo polje za zadatak, ono što je spojeno na `master` je
bila regresija: ranije je trener mogao da napiše zadatak uz poziciju, posle toga
nigde.

Krivica je brifova: §4.1 je fiksirao konstruktor rečima „the gate constructs it
directly" i nijednom nije rekao *i otvara se odnekud*. Kapija je pumpala vidžet
direktno — test koji dokazuje da stvar radi, a ne i da neko može do nje. Isti
oblik kao `getDue`, koji nedeljama nije imao pozivaoca uz zelene testove.

Popravljeno drugim dugmetom u studiju („Uredi korake lekcije") i čuvarom koji
pada ako `lib/` prestane da konstruiše panel — dokazan mutacijom. Suite
**1341 → 1342**. **Pravilo koje ostaje:** kapija koja sama konstruiše vidžet mora
da ide u paru sa onom koja tvrdi da ga i aplikacija konstruiše. Dohvatljivost ne
vidi nijedan alat, jer sa kodom nije ništa loše — samo nema ulaza.

Dva nalaza iz ovih faza koja nadživljavaju ovu funkciju:

1. **`getDue` nikad nije radio.** `stepsOfLesson` se poziva unutra a nikad nije
   uvezen, pa je svaki poziv bacao `ReferenceError` — od `60648ba`, komita čija
   poruka glasi „the review screen knew less about a lesson than three other
   readers". `npm test` je ostajao zelen jer `sources_compile` **kompajlira**
   izvore, a nedostajuće ime nije sintaksna greška. Red za ponavljanje u
   razmacima stoji u `TODO-provera.md` kao „tested in code, never run live"; ovo
   je ono što je ta rupa krila. Popravljeno, i `test/review_due_runs.test.js`
   sada stvarno poziva funkciju.
2. **Tvrdnja koju sam sâm napisao u fazi 0 bila je pogrešna, a stari test ju je
   uhvatio.** Detalji su u planu. Pouka: testovi koji već prolaze su dokaz o
   ugovoru, ne samo o kodu.

**Faza 0 je urađena 5.9.2026** i nije na `master`-u: njen proizvod je **crven
paket**. `chess_backend/test/lesson_step_kinds.test.js`, 19 testova, svi padaju
— `npm test` čita 914 / 895 prolaza / 19 padova, a tih 895 je ceo postojeći
paket, nedirnut. Isto i sa sklonjenim `.env`-om, pa fajl ne uvlači lanac servera.
Pravilo je isto kao za fazu 4 `PLAN-JEDNOSTAVNOST`-a: tvrdnje idu na granu,
grana je crvena, `master` ostaje zelen, a faza koja ih pozeleni ocenjuje se po
tome što ih **nije menjala**.

**Provera skenera je pozitivna:** `scanIntake.prepareRow` vraća
`{ fen, solutionSan, instruction, needsReview }` — tačno `ask_move` korak.
`deriveInstruction` već piše „Beli matira u jednom potezu" za proveren mat u
jednom, pa skenirana strana može stići sa već napisanim pitanjem.

Odlučeno sa vlasnikom 5.9.2026: oba tipa pitanja idu u v1, `acceptedSans` za
više jednako tačnih poteza, trener sastavlja u Analysis Studiju, „Pokaži mi"
posle dva promašaja. Devet faza, faze 1–3 su vodeće (diraju podatke i ugovore),
4–6 mogu biti paketi za radnika, 8 je razlivanje na grupu.

## ODAKLE SUTRA — 5.9.2026, kraj dana

`PLAN-TABLA-I-STABLO.md` je **završen u celini**: svih pet faza je na masteru, plus
dve izmene koje su došle iz vlasnikovih snimaka ekrana istog dana (visina table na
desktopu, i oba banera u zaglavlju).

**Ništa od toga nije gledano uživo osim jedne stavke.** Sve čeka u
`docs/TODO-provera.md`, **stavka 104**, koja je narasla na šest delova:

| deo | šta | stanje |
|---|---|---|
| A | fokus u stablu, širina ne skriva gde stojiš | čeka |
| B | lepeza neodgovorenih odgovora u turi | čeka |
| C | fiksna tabla i sažet baner | čeka |
| D | šansa linije i pogled na jednu granu | čeka |
| E | prostor ispod table | **potvrđeno na desktopu**, telefon čeka |
| F | oba banera u zaglavlju iznad 1200 dp | čeka |
| G | stablo ne pomera pogled samo od sebe | čeka |
| H | zum preživi promenu veličine prozora | čeka |

**Urađeno posle ovog reda, istog dana:** zum i pogled u stablu sada preživljavaju
promenu širine prozora preko 840 dp (`_treeKey`) — poslednje što je od
vlasnikovih prijava od 4.9–5.9.2026 ostajalo neurađeno u kodu. Detalji i cena su
u sekciji ispod, stavka 3; provera je 104-H.

**Prvo pitanje za sledeći put:** proći 104 od početka. Dve stvari u njoj su
odluke a ne provere, i vlasnik ih jedini može doneti — dugme banera je sada 32 px
visoko umesto 48 (deo C, stavka 13), a u zaglavlju uz „N nepotvrđenih" nema
zvučnika (deo F, stavka 29).

**Brojke na kraju dana:** Flutter **1241** (1 preskočen), backend 886, `flutter
analyze` istih 29 poznatih `info` stavki. Broj 1234 koji je ovde stajao ranije
tog dana bio je zastareo za pet — izmeren je pre nego što su poslednje faze
spojene, pa je prag bio niži od suite-a i pad od pet testova bi prošao
neprimećen. Izmereno na `master`-u pre današnje izmene: 1239, i 1241 sa dva
testa koje ona donosi.

**Radna stabla:** `mislisha-batch-b` je odrađen i spojen. **`mislisha-batch-a`
drži odbačeni posao** — worker je uradio baner (uzet) i fiksnu tablu (odbijena:
sopstvena tri testa su mu padala jer traže `BoardWithCoordinates`, a izveštaj je
navodio brojeve koje njegov paket testova demantuje). Sve što je vredelo je
preuzeto; to stablo se može resetovati bez gubitka.

**Sitnica koja će se ponoviti:** `orchestrate.py` je pucao na `UnicodeEncodeError`
pri ispisu radnikovog izveštaja u cp1250 konzolu — posle rada, pre ijedne kapije
— pa su oba paketa izgledala kao prolaz a nijedna kapija nije bila pokrenuta.
Popravljeno 5.9.2026, ali tek posle oba pokretanja.

## Prijave sa provere 4.9–5.9.2026 — zabeleženo, nije rađeno

Vlasnik ih je izričito prijavio kao **sugestije, ne kvarove**, i tražio da se
samo zabeleže: „kad ih skupimo dovoljno, možemo jednim planom popravke sve da
rešimo." Kod je pogledan samo toliko da se svaka usidri i da se zna šta bi
koštala — ništa nije menjano.

### 1. Lepeza neodgovorenih protivnikovih poteza kaže istu stvar pet puta (21:21, pojašnjeno 22:20)

Prva formulacija je zvučala kao „ne pokazuj rupe", pa je ovde bila zabeležena
kao sudar sa svrhom ture. **Vlasnikovo pojašnjenje pomera je sasvim:**

> „Nema potrebe doći u situaciju da na kraju linije imamo poziciju posle
> korisnikovog poteza, a onda 4 poteza protivnika koji započinju nove linije, a
> nemaju odgovor korisnika, i da se sad sve 4 pokazuju. Tu korisnik nema šta da
> zapamti."

**Nije sudar — prijava je tačna, i to protiv budžeta koji je tura sama sebi
postavila.** Provereno u kodu:

- `lookOfRepertoireMove` (`repertoire_tree_panel.dart:32`) proglašava rupom svaki
  protivnikov potez čija je pozicija `open`. Ako korisnikov potez vodi u
  poziciju sa četiri neodgovorena odgovora, sva četiri su rupe.
- `walkthroughOrder` obilazi **svaki** potez u crtežu, pa su to četiri zasebna
  stajanja.
- `walkthrough_speech.dart` daje glas svakoj rupi, pa se četiri puta izgovori
  „Na …, N% partija, nemate odgovor."
- A **peta rečenica je već rečena pre njih**: stajanje na korisnikovom potezu
  dobija račvu — „Odavde protivnik ima 4 odgovora: …" — i ona ih sve imenuje.

Dakle pet izgovorenih rečenica na jednoj poziciji, sve o istoj činjenici. Tura
je pisana sa budžetom „najviše četiri izgovorene rečenice na dvanaest poteza
trunka" (`walkthrough_speech.dart`), i jedna ovakva lepeza ga potroši na jednom
mestu. Rupa **ostaje prijavljena** — u račvi, gde je već imenovana.

**Odluka vlasnika, 5.9.2026: prihvaćeno po ovom pravilu.** Nije pisan nijedan
red u trenutku pisanja ovog reda.

**Pravilo:**

- Ne silaziti u protivnikov potez koji je rupa **kada ih na toj poziciji ima
  dvoje ili više**; račva ih je već imenovala.
- **Usamljenu rupu zadržati.** Račva se izgovara tek na `theirs.length > 1`, pa
  je kod jednog jedinog neodgovorenog odgovora to stajanje jedino mesto gde se
  rupa uopšte kaže.
- Pravilo važi samo za odgovore koji su rupe; ako su neki odgovoreni, u njih se
  silazi kao i do sada.

Time linija prirodno završava korisnikovim potezom — što je i bilo traženo — a
da se ništa ne prećuti.

### 2. Verovatnoća da se stigne do pozicije (21:30)

> „Pošto repertoar prati statistiku sa Lichess-a, možda ne bi bilo loše znati
> relativnu verovatnoću da pozicije... stignu do trenutne pozicije ili početka
> neke linije."

**Podaci već postoje.** Svaki protivnikov odgovor nosi `share` iz `walkLines`
(`repertoireLine.js`), a klijent ga već ispisuje (`shareLabel` u
`repertoire_tree_panel.dart`). Verovatnoća dolaska = proizvod `share`-ova
protivnikovih odgovora duž linije; sopstveni potezi su odluke, ne verovatnoće,
i ulaze kao 1.

**Šta treba odlučiti:** to je **uslovna** verovatnoća — „ako igramo ovaj
repertoar i protivnik ostane unutar onoga što je pokriveno". Širina repertoara
je menja: na „samo glavna linija" proizvod je nad jednim odgovorom po poziciji i
čita se previsoko. Broj bez te rečenice pored sebe je broj koji laže.

### 3. Zum ne sme da se menja pri kretanju kroz stablo (21:55)

> „Korisnik je već izabrao veličinu, tj. zum koji mu odgovara... Ako aplikacija
> menja zum, onda korisnik izgubi fokus. Takođe, ne mora trenutni potez da bude
> centriran na sred ekrana, već samo ako priđe ivicama."

Odnosi se na **svaki** ekran sa grafičkim stablom, ne samo na repertoar.

**Polovina je potvrđena i tačno locirana:** `visual_move_tree_widget.dart:407`
centrira na aktivni čvor **posle svake promene poteza**
(`_lastCenteredNodeId != widget.activeNode.id`). To je upravo skakanje koje
vlasnik opisuje, i „samo kad priđe ivici" je izmena unutar `_centerOnActive`.

**Odluka vlasnika, 5.9.2026:** pravilo je **bezuslovno** — „aplikacija nikad ne
menja sama zum, to treba da bude korisnikov izbor". Merenje ispod ostaje, ali
kao dijagnostika (gde se menja), ne kao odluka (sme li).

**Prva polovina je urađena 5.9.2026** (`883c598`, faza 2 iz
`docs/PLAN-TABLA-I-STABLO.md`): pogled se pomera samo kad aktivna kartica priđe
ivici, i to tačno toliko da uđe unutra. Prag je `_edgeMargin` = 48 px vidljivog
dela. Dugme „Centriraj na aktivni potez" i dalje centrira — to je korisnikov
zahtev, a pravilo zabranjuje samo ono što aplikacija radi sama. Živo nije
gledano: `docs/TODO-provera.md`, stavka 104-G.

**Druga polovina je izmerena i nije popravljena, i sada zna svoje ime.**
`_centerOnActive` **čuva** razmeru — čita `getMaxScaleOnAxis()` i vraća je istu
— a u celom fajlu matricu upisuju samo tri mesta i dva su korisnikova (zum i
reset). Dakle promena zuma ne dolazi iz računa u tom vidžetu.

**Dolazi od gubitka stanja, izmereno dva puta 5.9.2026: 1,5625 → 1,0.**
`repertoire_build_screen.dart` crta stablo na **dva različita mesta** u
rasporedu — unutar kolone sa tablom kad je usko (linija 3064) i u svojoj koloni
pored table kad je široko (linija 2768) — a prelaz je `Breakpoints.wide` = 840.
Vidžet koji se premesti u drugi slot dobija **novo** `State`, pa nov
`TransformationController`, pa razmeru 1,0. Isti oblik zamke koji je u tom
fajlu već zapisan za `OpeningBanner._lastNamed`.

**Urađeno 5.9.2026, posle faze 5.** Izabran je `GlobalKey` — `_treeKey` u
`repertoire_build_screen.dart` — a ne selidba kontrolera na ekran, iz dva
razloga. Prvi: kontroler nije jedino što se gubilo. U istom `State`-u su i
pomeraj, prekidač „graf / notacija" i smer rasporeda, pa bi selidba jednog
polja ostavila ostala tri da se i dalje resetuju. Drugi: isti fajl je istog
dana dobio `_openingKey` iz istog razloga, sa objašnjenjem uz njega — dve
različite popravke istog oblika u jednom fajlu su skuplje od jedne ponovljene.
Zamerka „jedan red koji se lako zaboravi zašto stoji" rešena je time što taj
red nosi mereni broj (1,5625 → 1,0) i pravilo koje brani.

**Cena koja je došla uz ključ, i nije bila u proceni:** `GlobalKey` u dva mesta
odjednom baca. Dva crteža su se do sada isključivala tako što su **dva puta
čitala širinu** — `LayoutBuilder` u telu i `Breakpoints.isWide` u koloni sa
tablom — a to su dva izvora koji mogu da se ne slože. Sada telo odlučuje jednom
i odgovor prosleđuje kao `treeBelow`. Čuvar je dokazan mutacijom u oba pravca:
bez ključa test pada sa `1.0` umesto `1.5625`, a sa uvek uključenim drugim
mestom pada na „Multiple widgets used the same GlobalKey".

Živo nije gledano: `docs/TODO-provera.md`, stavka **104-H**.

### 4. Fokus na liniju, i dugme za način prikaza (22:00)

> „Fokus treba da bude na trenutnoj liniji, ne striktno na potez. Ili da postoji
> dugme kojim korisnik podešava kako se ažurira prikaz stabla... Možda i dugme
> „prikaži samo ovu liniju" ili prikaži samo od ove pozicije."

Isti vidžet kao 3, i to dvoje ide zajedno u plan.

**Dve stvari vredi znati:**

- Filtar koji je 4.9.2026 obrisan bio je **po evaluaciji motora** i to je ono što
  ga je činilo lošim — sakrivao je grane po tuđem mišljenju. Ovo je filtar **po
  liniji koju je korisnik izabrao**, što je sasvim druga stvar i mnogo
  odbranjivije. Brisanje onog ne govori protiv ovog.
- „Prikaži samo od ove pozicije" **već postoji na serveru**, kao kapija
  repertoara (`rootFen` + `gateUci`, `gateMoves` u `repertoireFrontier.js`) i
  ekran „Vežbaj X" ga koristi. Pre pisanja novog filtra treba proveriti da li je
  ovo isti pojam pod drugim imenom — dva različita „samo ova grana" u istoj
  aplikaciji je tačno onaj oblik koji se kasnije razilazi.

### 5. Tabla mora da stoji, a stablo da ne gubi fokus (5.9.2026, 08:35)

Jedna prijava, četiri zahteva u njoj. Vlasnikov tekst je u alatu za proveru
(`stanje.json`, `n1788590120398`), uz sliku.

**a) Tabla i navigaciona paleta ne smeju da odskroluju.**

> „Tabla sa navigacionom paletom ispod se skrolovanjem ne vidi, treba da bude
> statična, a da se pomera samo ono što je ispod."

`_buildBoardColumn` (`repertoire_build_screen.dart`) je jedan
`SingleChildScrollView` oko jednog `Column`-a, pa se **sve** pomera zajedno:
traka nepotvrđenih, tabla, `_buildNavigation`, pa komentar, pitanje, odgovori,
presuda, uzeti potezi i knjiga. Traženi oblik je `Column[ nepomični deo,
Expanded(SingleChildScrollView(ostatak)) ]`.

**Odluka vlasnika, 5.9.2026:** prihvaćeno — tabla i navigaciona traka ostaju
fiksirane na vrhu, ostatak se skroluje, a **proračun veličine table mora da uzme
i visinu ekrana**, izričito za male telefone (360 dp).

**Ograničenje koje treba rešiti pre pisanja:** na 360×640 tabla plus paleta već
troše skoro ceo ekran. Ako se zakuju, deo koji se skroluje spada na nekoliko
piksela, a tabla se iseca — dakle veličina table mora da se računa **od visine
prozora**, ne samo od širine, i to je pravi posao ove stavke.

**b) Traka „N nepotvrđenih u grafu" jede prostor iznad table.** Na slici uz
prijavu je baš ona. Vlasnikov predlog: izbaciti je ili pomeriti. Vredi
razmisliti da postane deo nepomičnog zaglavlja ili da se skupi u jedan red sa
dugmetom, umesto zasebne kartice.

**Odluka vlasnika, 5.9.2026:** baner se **sažima u jedan kompaktan red u ravni
sa dugmetom**, da ne gura tablu nadole. Ne briše se.

**c) Fokus u stablu se ne sme gubiti pri gradnji.**

> „Ako korisnik izabere potez za svoju boju, taj potez treba odmah da se vidi u
> stablu poteza i da se pozicija na tabli i fokus u stablu poteza postavi na tu
> poziciju. Izborom poteza za protivnika pozicija ostaje na tom mestu, ali se u
> stablo dodaje odmah potez protivnika, a fokus je usklađen sa tablom, jer
> korisnik može da doda i druge, alternativne poteze protivnika."

Ovo je **ista prijava** kao ranija, nezabeležena, od 4.9.2026 13:29
(`n1788510593557`): „aplikacija ne upisuje taj potez u stablo odmah… i posle
mog izbora šta igra protivnik, baca me negde".

**Arhitektura je već prava, i to je dobra vest:** `_activeNode` se izvodi iz
FEN-a table (`_standingAfter?.fen ?? _current`), pa fokus **prati tablu** po
konstrukciji — tačno kako vlasnik traži. Sumnjiv je jedan red:

    return findNodeByFen(root, fen) ?? root;

`?? root` znači da pozicija koju novi crtež ne sadrži tiho vraća fokus na koren
repertoara — što je verovatno ono „baca me negde". A crtež je ne sadrži kada
potez ispadne izvan trenutne širine, što je **isti uzrok** koji je već imenovan
na drugom mestu istog fajla (poruka „Ova pozicija je izvan onoga što spremate").
**Odluka vlasnika, 5.9.2026, i ona rešava baš taj sudar:**

- **Tihi `?? root` se ukida.** Korisnik nikada ne sme da bude vraćen na početak
  dok istražuje poteze.
- Ako korisnik odigra potez, **stablo mora odmah da prikaže taj potez**.
  „Odigra" znači **oba ulaza**, pojašnjeno 5.9.2026: i potez povučen na tabli, i
  potez prihvaćen iz spiska ispod table („Potvrdi", „Uzmi …", odgovori). Pravilo
  visi o tome da je čovek potez odobrio, ne o tome kojim ga je putem odobrio.
- Ako je potez bio van filtera širine, **privremeno se otkriva** — jer korisnik
  je eksplicitno na njemu. Širina ostaje ono što je bila za sve ostalo; ovo je
  izuzetak za poziciju na kojoj čovek stoji, ne promena širine.

To je isti oblik pravila koje već postoji na serveru (`coveredReplies` prati
odgovor koji vodi u poziciju gde korisnik ima odluku, na svakoj širini) — dakle
„ono što je čovek sam uradio se ne skriva" važi i ovde.

**d) Zum se nikad ne menja sam.**

> „Zum (veličina prikaza) u grafičkom stablu poteza ne treba da se menja
> automatski, već to korisnik radi. Dakle, aplikacija nikad ne menja sama zum."

Ovo **zatvara pitanje ostavljeno otvoreno u stavci 3** gore: zahtev je sada
bezuslovan, pa nije bitno odakle promena dolazi — ne sme da postoji.

**Izmereno 5.9.2026, i stavka 3 gore nosi ceo nalaz:** stablo samo od sebe ne
menja zum ni na jednom mestu u svom vidžetu; zum se gubi zato što vidžet pri
prelazu preko 840 px dobija novo stanje. **Urađeno 5.9.2026** — vidi stavku 3
gore za izbor rešenja i za cenu koja je uz njega došla. Ovime je cela prijava
d) zatvorena u kodu; ostaje da se vidi uživo (provera 104-G i 104-H).

### 6. Banere iznad srednje kolone na desktopu (5.9.2026, ideja vlasnika)

> „Šta misliš da u desktop režimu naziv otvaranja („C50 · Italian Game…") i
> baner sa nepotvrđenim potezima prebacimo iznad srednje kolone (iznad stabla
> varijanti)?"

Njegova dva razloga, oba stoje: leva kolona bi ostala bez ijedne fiksne kartice
iznad table — tabla ide na sam vrh, a sav prostor ostaje tabli, navigaciji i
potezima; a i sadržajno, i ime otvaranja i broj nepotvrđenih govore o
repertoaru i stablu, a srednja kolona na desktopu ima vertikalnog prostora
napretek.

**Šta bi se menjalo.** `_buildBoardColumn` već prima `commentBeside` za istu
vrstu odluke, pa bi dobio i drugi takav prekidač; široki raspored bi banere
crtao iznad `Expanded`-a sa stablom. Fiksno iznad, ne unutar `SingleChildScrollView`-a
— „Pregledaj nepotvrđene" je radnja i ne sme da odskroluje.

**Koliko se dobija.** Baneri u levoj koloni troše oko 106 px (ime otvaranja ~40
+ nepotvrđeni 66). Na prozoru visine 1000 to je, pri istom `_boardShare`, oko
106 px više ispod table — ili veća tabla za toliko, ako se deo uzme nazad.
Vlasnikovih 500 px traži `_boardShare` oko 0,53.

**Dve cene, i obe treba znati pre nego što se počne:**

1. **`_boardShare` bi opet postao dva broja.** Tek je 5.9.2026 postao jedan za
   oba rasporeda, i to je bilo pojednostavljenje. Ako desktop izgubi banere iz
   leve kolone, njegov nepomični deo više nije istog sastava kao telefonov, pa
   jedan udeo prestaje da znači isto na oba. Nije prepreka — samo treba reći
   naglas da se time vraća razlika koja je upravo uklonjena.
2. **`OpeningBanner` nosi stanje, i selidba ga briše.** `_lastNamed` u
   `_OpeningBannerState` pamti poslednje *imenovano* otvaranje, i zato je taj
   vidžet namerno bez ključa — komentar u `repertoire_build_screen.dart` to
   izričito kaže. Vidžet na drugom mestu u stablu vidžeta dobija **novo**
   `State`, pa se ime gubi. Jednokratno je bezazleno, ali ako baner postoji na
   dva mesta (usko naspram široko), **svaki prelaz preko praga od 840 px briše
   nošeno ime** — a to je obično menjanje veličine prozora na Windowsu. Rešivo
   (jedan `GlobalKey`, ili da se nošeno ime drži na ekranu umesto u baneru),
   ali se mora rešiti, inače je to tiha regresija tačno one vrste koju ovaj
   projekat stalno plaća.

**Bolja varijanta iste ideje, vlasnikova, isti dan:** „Možemo li iskoristiti
prostor pored *Italian Game: Giuoco Piano — beli*?" — dakle u **zaglavlje**, ne
iznad srednje kolone.

Bolja je zato što srednja kolona ne plaća ništa: zaglavlje već postoji, već je
visoko 56 px, i na širokom prozoru mu desno stoji prazno. Selidba iznad stabla
oslobađa levu kolonu ali trošak seli u srednju; u zaglavlju trošak nestaje.

**Mere na prozoru od 1920** (naslov ~340, radnje sa zvučnikom, mrežom i
„upita: 0" ~172, vodeća strelica ~56): slobodno ostaje **oko 1350 px**. Čip sa
imenom otvaranja je oko 400, sažeti red nepotvrđenih oko 390 — zajedno oko 790,
staje sa viškom.

**Prag, i on je odluka a ne detalj:** na 1200 slobodnog prostora ima oko 630, što
prima jedno od to dvoje. Ispod `Breakpoints.wide` (840) ne prima nijedno i oba
ostaju gde su danas. Dakle tri stanja, ne dva.

**Zaglavlje je izvan `LayoutBuilder`-a**, pa širinu čita iz
`Breakpoints.isWide(context)` / `MediaQuery`, kako to isti ekran već radi na
jednom mestu.

**Vizuelno:** baner u zaglavlju verovatno ne treba svoju obojenu karticu sa
ivicom — zaglavlje ga već odvaja. Tekst i dugme, bez okvira.

**Cena oko `OpeningBanner`-a ostaje ista i tu** — i dalje se seli između dva
mesta, pa i dalje gubi nošeno ime na svakom prelasku praga. Dva rešenja:
`GlobalKey` na baneru, ili — čistije — da `_lastNamed` živi na ekranu, a baner
postane bezstanjen i prima ime kao parametar. Drugo rešenje uklanja krhkost
umesto da je zaobiđe.

**Urađeno 5.9.2026 za oba**, uz `bare: true`. Levoj koloni je time skinuto oko
106 px fiksnih kartica iznad table.

**Prag je `ultraWide` (1200), ne `wide` (840), i to je izmereno.** Dugme
„Pregledaj nepotvrđene" ne može da se skupi, pa se na 900 dp zaglavlje prelilo
25 px već sa imenom repertoara i banerom, a 139 px kad se doda i ime otvaranja.
1200 je postojeći odgovor ove aplikacije na pitanje „ima li ovde mesta za treću
stvar" i njegov sopstveni komentar to kaže, pa je iskorišćen umesto da se
izmišlja nov broj. Ispod praga oba ostaju iznad table — što uključuje i telefon
u pejzažu, koji je oko 770 dp.

**Nađeno pri radu, i vredi zapamtiti:** `SpeakableInfo` je `Row` od `Expanded`-a
i `IconButton`-a, a ta ikonica ne može da se skupi. U zaglavlju, gde dugme
„Pregledaj nepotvrđene" traži 326 od 381 px koliko baner dobija, rečenici ostane
devetnaest — i ikonica ispadne jedanaest piksela van. U zaglavlju zato ide obična
`Text` sa skraćivanjem, bez sopstvenog zvučnika; zaglavlje ima svoj prekidač za
govor. **Uhvaćeno testom koji je već postojao** (`repertoire_counts_refresh_test`),
a u release bildu bi to bilo jedanaest piksela ćutanja.

**Pejzaž na telefonu nije diran** i vlasnik je izričito rekao da se za sada ne
dira (5.9.2026). Telefon u pejzažu je oko 770 dp — **ispod praga od 840** — pa
ostaje uski raspored: baner iznad table preko cele širine, tabla po sredini, a
visina je tada oko 340 dp, gde pravilo `_boardShare` daje malu tablu. To je
zasebna stavka kad na nju dođe red.

## Širina se menja bez pisanja ijednog poteza — 5.9.2026

Prijava vlasnika, ista večer: „ručno dodajem poteze i kad izaberem potez za
protivnika, dodaju mi se još nekoliko alternativa (a hoću samo da se dodaje taj
jedan koji sam izabrao)... nema smisla da biram šta igra protivnik, kad mi se
potezi sami dodaju."

**Prvo šta se zapravo dešava, jer prijava opisuje pogrešan mehanizam.** Ti
potezi **nisu upisani** kao njegove odluke. Čuva se samo ono što potvrdi i ono
na šta sam pritisne „Spremi i ovo". Kartice o kojima govori računaju se pri
svakom čitanju, iz `opening_replies`, a koliko ih se uzme odlučuje **širina
repertoara** (`coveredReplies` / `withinBreadth`). Na podrazumevanom
`Uobičajeno (80%)` to je svaki protivnikov odgovor unutar 80% odigranih
partija, pa biranje jednog ne uklanja ostale — oni nikad nisu ni bili njegov
izbor.

Nisu bezazleni: isti hod puni i red pitanja, pa svaka takva pozicija stoji u
stablu kao rupa i vraća se kao pitanje.

**Kvar koji je prijava otkrila usput, i on je pravi.** Širina se do sada mogla
promeniti **samo** kroz dijalog dugmeta „Predloži glavnu liniju", i čuvala se
**tek ako se izabere i dubina** — „Odustani" baca izbor. Dakle: čovek koji
sužava repertoar zato što mu aplikacija upisuje previše, morao je da joj dopusti
da upiše još jednu liniju da bi to uradio. To je oblik koji ovaj projekat već
zna: radnja i podešavanje spojeni u jedno dugme.

**Urađeno 5.9.2026:**

* `BreadthSettingDialog` — širina sama, bez dubine i bez kičme. Čuva na
  „Sačuvaj", vraća izabranu širinu pozivaocu (da je ekran usvoji odmah, što je
  bug zbog kog `current` uopšte postoji), i ostaje otvoren ako server odbije.
* Ulaz je **legenda ispod crteža**, red koji ionako kaže „Koliko odgovora:
  uobičajeno 80%". Mesto koje činjenicu izgovara je mesto na kome se menja —
  isto pravilo po kome odsečene grane stoje uz prekidač koji ih vraća. Ikonica,
  ne boja, jer boja nije nešto što svaki čitalac vidi.
* `onChangeBreadth` je opcion: tura (`repertoire_walkthrough_screen`) ga ne
  prosleđuje i tamo red ostaje običan tekst, a i ekran bez `id` repertoara ga
  ne nudi — `setBreadth` piše u red repertoara, pa bi dugme tamo bilo
  podešavanje koje tiho ne radi ništa.
* Red se **ponovo gradi**, ne dopunjava: širina odlučuje šta hod sadrži, pa
  pozicije upisane na staroj nisu manji deo novog odgovora nego odgovor na
  drugo pitanje. Tabla ostaje gde je.
* Tekst dijaloga kaže i šta sužavanje **ne** košta: potezi uzeti rukom i
  pozicije u kojima je već odlučeno prate se na svakoj širini (to je pravilo iz
  `coveredReplies` od 4.9.2026). Zato je rečenica u starom dijalogu — „Manje
  odgovora skriva grane koje ste već pripremili" — sada netačna i ispravljena;
  dva dijaloga koja o istom brojčaniku govore suprotno je tačno onaj oblik koji
  se kasnije razilazi.

Provera uživo: `docs/TODO-provera.md`, stavka **105**.

**Ostaje otvoreno, i vlasnik ga je izričito ostavio za posle:** „samo moji
odgovori" — širina sa **nula** automatskih odgovora. Uklapa se u postojeće
pravilo (`manual ⊆ main ⊆ standard ⊆ broad`), ali dira serverski hod, dril i
mapu pokrivenosti, i menja šta „pokrivenost" znači: bez knjige nema sa čim da
poredi, pa bi radar morao da kaže da meri nešto drugo.

## Crtež uvek sadrži poziciju na kojoj tabla stoji — 5.9.2026

Druga prijava iste večeri: „posle izbora poteza protivnika, taj potez se ne
prikazuje u stablu, a trebalo bi — da vidim i u stablu na šta treba da
odgovaram." Put je, na pitanje, bio **dugme „Idi"** na protivnikovom odgovoru
koji je već u pripremi.

**Prvo je izmeren server, i on nije kriv.** `tree()` sa lažnim poolom, tri
širine: odgovor uzet rukom (`repertoire_extra_replies`) crta se na **svakoj**
širini, uključujući `main`, a crta se i onaj na kome čitalac samo stoji
(`alongPath`). Dakle pravilo „ono što je čovek sam uradio se ne skriva" radi
tamo gde je napisano.

**Kvar je u klijentu, i to je zastarela pretpostavka a ne previd.**
`_loadTree` je nosio komentar: „nikad na običnom pomeranju — stablo se pomera
kad se pomere potezi." To je bilo tačno dok se crtež nije počeo čitati **od
mesta gde je tabla**: `maxPly` se od 4.9.2026 računa iz dubine na kojoj se
stoji, a `alongPath` je od 5.9.2026 linija na kojoj se stoji. Oba su funkcije
table, pa crtež pročitan na ranijoj poziciji zaista može da nema karticu za
ovu — a `_activeNode` tada (ispravno, po pravilu iz faze 1) ostavlja
osvetljenje na prethodnom potezu. Čitaocu to izgleda tačno onako kako je
prijavio: potez koji je upravo izabrao nije nigde.

**Pravilo koje je sada zapisano:** posle svakog pomeranja table, ako crtež ne
sadrži poziciju na kojoj se stalo — pročitaj ga ponovo. Jednom, ne u petlji:
ako ni novi crtež ne stigne dotle, osvetljenje ostaje gde je bilo. I samo ako
crtež uopšte postoji — bez njega je to otvaranje ekrana, gde `_resume` ionako
čita, pa bi provera značila dva čitanja pri svakom pokretanju. To je i uhvatio
postojeći test (`treeCalls`), pre nego što je stigao do telefona.

Cena je nula za kretanje unutar crteža koji već sadrži liniju — što je i drugi
test u paru.

Provera uživo: `docs/TODO-provera.md`, stavka **106**.

## Provera uživo 5.9.2026 popodne — 35 stavki zeleno, tri nalaza

Vlasnik je prošao stavke 104 (A, C, D, F, G), 105 i 106 u release bildu na
Windowsu. **Trideset pet stavki je potvrđeno**, uključujući ceo deo G (crtež
stoji dok se ide kroz liniju, pomeri se tek uz ivicu, zum se pri tome ne menja,
dugme za centriranje i dalje centrira), celu stavku 106 i devet od deset u 105.

Zabeleženo iz alata (`D:\Projekti\mislisha-test\qa`, `stanje.json`), i ovde
stoji ono što se ne vidi iz kvačica.

**Nijedan od tri nalaza nije kvar u aplikaciji.**

### 1. „Ne vidim baner" — stavke 104-F/25 i 105/5

Obe su pisane preko banera „N nepotvrđenih". Sa vlasnikovih slika se vidi zašto
ga nema: red ispod table kaže „odlučeno 12 · otvoreno 6 · bez odgovora 5%" i
**ne kaže „nepotvrđeno N"**, a taj deo rečenice postoji samo kad je
`walk.draft > 0`. Dakle repertoar je imao nula nepotvrđenih poteza i baner se
ispravno nije crtao — nema šta da prijavi.

Ime otvaranja **jeste** bilo u zaglavlju na obe slike („C54 · Italian Game:
Classical Variation, Giuoco Pianissimo"), pa polovina stavke 25 koja se mogla
proveriti prošla je; stavka 26 (dugme iz zaglavlja radi) je zelena.

**Popravljene su stavke, ne kod.** 105/5 sada traži broj iz reda ispod table,
koji postoji uvek; 104-F/25 kaže da prvo treba napraviti nepotvrđene poteze.
Pouka je opštija i vredi je pamtiti: **stavka provere koja se oslanja na
indikator koji postoji samo u jednom stanju je stavka koja se u drugom stanju
čita kao kvar.**

### 2. Suženje se ne pušta samo — stavka 104-D/20

Vlasnik: „ne pušta se, može samo u okviru stabla trenutno prikazanog, ali nije
problem, meni odgovara." Pravilo `_leftTheNarrowing` radi, ali nema šta da ga
okine: dok je crtež sužen, kretanje ide kroz ono što je nacrtano, pa se iz grane
i ne može izaći. Izlaz je dugme „Prikaži ceo repertoar". **Prihvaćeno kako
jeste**, stavka prepisana i zatvorena.

### 3. Poteze ne mogu da povlačim po tabli — uz stavku 104-A/2, zatvoreno

Vlasnik je stavku označio kao prolaz i uz nju napisao tu rečenicu, pa je pitanje
vraćeno njemu. Odgovor istog dana: **nije kvar** — probao je dok nije bio na
potezu. „Mogu da povlačim kad sam ja i tada je ista procedura kao da sam ga
izabrao sa liste — bila je opaska, nisam smatrao da mi smeta kao korisniku,
ovako je još bolje."

To je tačno ono što `isAllowedToMove` propisuje (`!_busy && _proposalUci == null
&& !_afterMyMove`), i potvrđuje pravilo iz faze 1: oba ulaza — potez povučen po
tabli i potez uzet sa spiska — vode kroz isti put.

### Zamka u alatu za proveru, nađena pri ovom upisu

`izvuci.py` deli id-jeve **po redosledu u fajlu** (`i%04d`, prosto brojanje), a
`stanje.json` je kljucan po tom id-u. Dakle **nova stavka umetnuta iznad
postojećih pomera id-jeve svemu ispod nje**, i odgovori se tiho zalepe za
druge stavke. Zaglavlje samog alata na to upozorava.

Danas je prošlo bez štete — deo H je umetnut iznad dela B, a B nije imao
nijedan odgovor, i tada iza 104 nije bilo ničega. Pravilo za ubuduće: **nove
stavke idu na kraj fajla**, ili bar iza svake koja već ima odgovor; a ako baš
moraju u sredinu, treba prvo prebrojati odgovore ispod tog mesta.

### Šta u 104 još nije gledano

B (lepeza u turi, 6–9), C/13 (visina dugmeta banera, odluka), D/22, E/23–24
(telefon), F/28–30, G/33–34 i cela **H** (zum preživi promenu veličine prozora,
35–39) — H je pisana danas i još nije prošla.

## Skener kaže koji je od tri problema — 5.9.2026, nije viđeno uživo

Vlasnik je 5.9.2026 pokušao četiri knjige. Sve četiri su pale, **svaka iz drugog
razloga**, a aplikacija je za sve četiri prijavila isti — i pogrešan — uzrok.

**Šta je izmereno** (pdfjs, sve strane svake knjige):

| knjiga | šta je zapravo | šta je aplikacija rekla |
|---|---|---|
| Reinfeld, 1001 žrtvovanje | 252 strane, **0 znakova teksta**, jedna slika po strani (92 dpi) | nepoznat font |
| Complete Book of Chess Strategy | 388 strana, **0 znakova teksta**, jedna slika po strani (400 dpi) | nepoznat font |
| Back to Basics: Openings | tekst postoji (OCR), ali su dijagrami slike — 433 slike na 224 strane | nepoznat font, uz glifove `e` (26×), `.` (18×), `t` (5×) — slova engleske proze |
| Grandmaster Codex | 4513 strana, LaTeX tekst, table crtane vektorski (177 putanja i 71 popuna u kvadratu 288×288) | „Skeniranje nije uspelo (500)" |

Nijedna od četiri nema font za koji bi se pisala mapa. Peta, `chessboard.pdf`,
prošla je bez ijedne izmene (`SkakNew`, 31 dijagram, 0 grešaka u glifovima) —
ali je to **uputstvo za LaTeX paket `chessboard`**, pa su joj „pozicije" primeri
sloga: 13 različitih na 31 nađenu, 9× početna pozicija, 9× ista tabla sa dva
kralja, i četiri nemoguće table koje su sve uredno označene.

**Prva popravka — tri odgovora umesto jednog.** `classifyUnreadable`
(`services/positionScanner/diagrams.mjs`) razlikuje `no_text` (na stranama nema
nikakvog teksta), `no_diagram_text` (teksta ima, ali nijedan red nema oblik
dijagrama) i `unknown_font` (redovi postoje, azbuka je nepoznata). Pravilo za
srednji slučaj je **definicija samog cevovoda bez azbuke**: osam redova oblika
reda složenih u jednu kolonu, preko `runsByColumn` koji izvlačenje ionako
koristi. Spisak nepoznatih glifova se sada računa **samo iz tih redova**, pa
proza ne može da se prijavi kao šahovski glif.

Zašto je to bitno: stara poruka je slala čitaoca da izvede mapu za font kog u
fajlu nema. Pogrešno imenovan uzrok je gori od neimenovanog.

**Druga popravka — 43 MB više ne izgleda kao pad servera.** `uploadRejection`
(`services/scanIntake.js`) i rukovalac greškom na kraju `routes/scans.js`:
`LIMIT_FILE_SIZE` daje **413** i rečenicu koja imenuje granicu (25 MB) i kaže
šta da se radi, sve ostalo 400 sa multerovom porukom. Ranije je multer prekidao
otpremanje pre nego što ruta uopšte krene, greška je odlazila Expressu, a klijent
je štampao samo broj statusa. Isti oblik je od 20.8.2026 na ruti za arhivu.

Klijent bira rečenicu po kodu (`scanFailureMessage` u
`scanner_api_service.dart`), a sve što ne prepoznaje pušta serverovu poruku —
zato što server zna brojeve koje ekran ne zna, kao što je granica u megabajtima.

**Testovi:** 9 novih na serveru (`positionScanner.test.mjs` +4, uključujući
prolaz kroz `scanDocument` sa sintetičkim PDF-om bez teksta;
`test/scan_upload_limits.test.js` +5, uključujući čitanje samog rutera — sloj
greške se prepoznaje po arnosti 4, ne po tekstu fajla) i 6 u aplikaciji
(`test/scan_failure_message_test.dart`). Sva četiri su dokazana mutacijom:
spuštanje praga sa 8 na 1 obara dva testa, vraćanje `unknown_font` u
`scanDocument` obara treći, uklanjanje rukovaoca greškom iz rute obara četvrti,
a spajanje dve poruke u jednu obara dartov.

**Ostaje:** provera uživo, stavka 107 u [TODO-provera.md](TODO-provera.md).

## Otvorena pitanja dizajna

Ona koja tek treba odlučiti stoje u [PITANJA-ZA-ODLUKU.md](PITANJA-ZA-ODLUKU.md),
sa procenom šta svaka mogućnost povlači. Ovde su odluke koje su **već** donete;
tamo one koje čekaju. Prvo na toj listi nije bio ekran nego jedna kolona —
`assignment_items.played_san`, urađena 20.8.2026, odeljak niže.

## Prvo pročitati: procena i plan

**https://claude.ai/code/artifact/a3456b17-94b0-4b56-a59f-44bebb02a77b**
(„Chess Master — Procena i Plan Rasta", 15.8.2026. — čita se preko `WebFetch`.)

Tamo stoji ono što se iz koda ne može rekonstruisati: **zatečeno stanje** pre
ovog posla, ocene po dimenzijama, pogled iz ugla trenera i učenika, poređenje sa
Chess.com / Lichess / Chessable / DecodeChess, predloženi model naplate sa
cenama, i plan u pet faza — a uz svaku stavku i **zašto** baš ona i baš tim
redom. To je izvor za svako „zašto smo se ovako dogovorili".

> **Pažnja: dokument opisuje stanje *pre* rada.** Faze 0–2 su u međuvremenu
> najvećim delom izvedene. Ko ga pročita bez ove tabele predložiće posao koji je
> odavno gotov.

| Iz plana | Stanje |
|---|---|
| Faza 0 — lažni Premium, prava pristupa, merenje troška | **Urađeno.** Naplata (Play Billing, RTDN, kvote) napisana i testirana, ali **nijedna prava kupovina** — čeka Play Console |
| Faza 0 — pravni okvir | Nacrti postoje (`politika-privatnosti.md`, `saglasnost-roditelja.md`); treba pravnik i hosting |
| Faza 0 — analitika i levak | **Nije rađeno** |
| Faza 1 — uvoz Lichess zagonetki, adaptivan izbor | **Urađeno.** 50.000 uvezeno (dostupno 6,1M) |
| Faza 1 — keširanje evaluacije | **Urađeno** (`EvalCache`) |
| Faza 1 — uvoz partija sa Chess.com/Lichess | **Urađeno** u Analysis Studio-u. Chess.com **potvrđeno uživo** (i jedan bag nađen i popravljen usput); Lichess strana čeka proveru — `TODO-provera.md`, stavka 7 |
| Faza 1 — dnevna zagonetka, niz dana | **Nije rađeno** |
| Faza 2 — domaći zadaci, napredak učenika, izveštaj za roditelja | **Urađeno**, ali izveštaj i zadaci **nisu provereni uživo** |
| Faza 2 — ponavljanje u razmacima (SM-2) | **Urađeno** |
| Faza 2 — grupe i prisustvo, chat i video | **Nije rađeno** |
| Faza 3 — višejezičnost, distribucija | **Nije rađeno.** Vidi `TODO-objavljivanje.md` |

## Gde smo

Aplikacija radi na Windows-u u debug režimu. Sesija, snimanje časa, čuvanje i
reprodukcija sa zvukom — sve prošlo uživo. Backend na `chess_backend` (Node +
PostgreSQL na DigitalOcean), pokreće se sa `npm run dev`.

Od 15.8.2026. postoji i **pravi server, potpuno postavljen i proveren, ali
namerno ugašen** — vidi „Nov server" niže. Aplikacija i dalje gađa lokalni
backend; prebacivanje čeka odluku o domenu.

Stanje provere funkcionalnosti se vodi u [TODO-provera.md](TODO-provera.md),
koraci za objavljivanje u [TODO-objavljivanje.md](TODO-objavljivanje.md).

## Šta je urađeno u ovom ciklusu

Redom, sa uzrokom — jer su tri greške bile u lancu i lako se pomešaju.

**1. Zamrzavanje ekrana pri snimanju** — `Stack` u `AnimatedMovePiece`
([board_overlay_painter.dart](../chess_app/lib/widgets/board_overlay_painter.dart))
ima isključivo `Positioned` decu, pa je uzimao veličinu roditelja. Tabla u sobi
stoji u `Column` unutar `SingleChildScrollView`, gde je visina beskonačna →
`size.isFinite` pukne u `performLayout()`. Flutter oko `_deviceUpdatePhase`
**nema `try/finally`**, pa izuzetak iz layout-a trajno zaglavi
`_debugDuringDeviceUpdate` i onda svaki frame i svaki pomeraj miša bacaju novu
grešku — otud hiljade `MouseTracker` poruka koje su izgledale kao uzrok, a bile
su posledica. Popravka: `SizedBox` oko `Stack`-a, jer je overlay po definiciji
veličine table.

**2. `ListTile` u `ColoredBox`** — `buildRightSidebar()` u
[chess_game_screen.dart](../chess_app/lib/screens/chess_game_screen.dart) je
vraćao `Container(color:)`, a `SwitchListTile` interno gradi `ListTile` kome
neproziran sloj krije pozadinu i ink. Flutter to prijavljuje **u svakom frame-u**.
Popravka: `Material` umesto `Container`. (`Card` je već `Material`, zato druga
slična mesta nisu bila problem.)

**3. Play u reprodukciji nije radio, zvuk se nikad nije čuo** —
[replay_player_screen.dart](../chess_app/lib/screens/replay_player_screen.dart).
Pozivi ka audio plejeru stajali su **ispred** kreiranja tajmera reprodukcije, pa
bi greška zvuka oborila ceo `_play()`. Uz to su bili ispaljeni bez `await`, pa se
`seek` trkao sa `play` i `setSourceUrl`. Popravka: tajmer se kreira **prvi**,
zvuk ide posle kroz `_startAudioFrom` sa `await`-ovima i `try/catch`. Time je
rešeno oboje — i Play i zvuk.

**4. Zamrzavanje pri otvaranju „Kreiraj lekciju"** —
[create_course_dialog.dart](../chess_app/lib/widgets/create_course_dialog.dart).
`AlertDialog` svoju decu uvek umotava u `IntrinsicWidth`
([dialog.dart:925](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/dialog.dart)).
Kad `content` **nije čvrste širine**, taj intrinsic prolaz siđe kroz
`SingleChildScrollView` do `Column`-a, a `RenderFlex` pri računanju poprečne
veličine traži *glavnu* (visinu) od svoje dece — i tako stigne do `ListView`-a i
`ReorderableListView`-a sa `shrinkWrap: true`. Lenji viewport ne ume da vrati
intrinsic dimenzije i baci `RenderShrinkWrappingViewport does not support
returning intrinsic dimensions`, pa dijalog ostane neraspoređen. Popravka:
`SizedBox(width: 380)` oko sadržaja — `RenderConstrainedBox` kod čvrste širine
vraća broj **bez** silaska u dete ([proxy_box.dart:250](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/rendering/proxy_box.dart)),
pa lanac nikad ne krene. Visina ostaje `maxHeight`, izgled nepromenjen.
Isti obrazac je preventivno popravljen i u
[save_position_dialog.dart](../chess_app/lib/widgets/save_position_dialog.dart)
(lista predloga labela puca isto, čim se ukuca slovo). Ostali dijalozi sa lenjim
listama već koriste čvrst `SizedBox`. Pokriveno testom
[dialog_layout_test.dart](../chess_app/test/dialog_layout_test.dart).

**Ostalo:** tap-to-move je postao dodatak prevlačenju (overlay je
`HitTestBehavior.translucent`, pa ne guta gest), podešavanje „Način izvođenja
poteza" je zato uklonjeno u celosti, i animacija klizanja figure je izbačena sa
*drag* puteva u sve tri table (figura je već putovala pod prstom — ponavljanje
izgleda kao dvostruki potez).

## Korisnik već ima objavljenu aplikaciju na Play-u

[Chess Brain Trainer: Puzzles](https://play.google.com/store/apps/details?id=com.program.braintrainer)
— `com.program.braintrainer`. Tri režima vežbanja kretanja figura (Sleepers,
Avoidance, King Hunt).

Zašto je to bitno, a ne anegdota:

- **Play Console nalog postoji**, $25 je plaćeno, identitet potvrđen, review već
  jednom prošao. To je bila prva stavka u `TODO-objavljivanje.md` i otpada.
- **Merchant nalog radi — potvrđeno 15.8.2026.** Brain Trainer prodaje Premium za
  pravi novac, a korisnik je sam kupio i potom **povratio novac**. Time su i
  naplata, i isplata, i refund tok već prošli kroz Google na ovom nalogu. Ovo je
  bila zabeležena nepoznanica; više nije. Za ovu aplikaciju ostaje samo da se
  naprave proizvodi i servisni nalog.
- **Postojeća publika** rešava šahovske zagonetke — to je tačno publika ove
  aplikacije. Unakrsna promocija između dva unosa pod istim nalogom je
  najjeftiniji kanal koji postoji.
- Korisnik je pomenuo da bi **neki deo Brain Trainer-a mogao da se uklopi** u
  ovu aplikaciju, ali izričito: „o tom potom". Ne otvarati bez njegovog povoda.

## Odluke i zašto

- **`applicationId` je `rs.pejovic.chesscoach`**, namerno odvojen od brenda. Ime
  „Chessmaster" je Ubisoft-ovo i ne dolazi u obzir. Posledica: na Windows-u su
  podaci sad u `AppData\Roaming\rs.pejovic\chess_app`, pa preuzeti Stockfish sa
  stare putanje izgleda kao da nedostaje.
- **Naplata ide preko Google Play-a**, jer je korisnik fizičko lice u Srbiji bez
  firme; Stripe tamo ne radi, a PayPal Srbija ne može rezident–rezident. Play je
  merchant of record i plaća prekogranično.
- **Animacija se zadržava** tamo gde figura *nije* putovala pod prstom: tap
  potezi, protivnikov odgovor, replay, autoplay rešenja, koračanje kroz stablo.
- **`chess_backend/uploads/` je u `.gitignore`** — sadrži prave snimke časova.
  Dečji glasovi ne smeju u repozitorijum. Ovo ne dirati.

## Zašto ostajemo na Agori (i pod kojim uslovom se to menja)

Razmatran je LiveKit, povodom Linux podrške. Odluka 15.8.2026: **ostaje Agora.**

Provereno u samim paketima, ne po sećanju:

- `agora_rtc_engine-6.6.3` deklariše `android`, `ios`, `macos`, `windows` i
  **`web`**. Nedostaje samo **Linux**.
- `livekit_client` podržava svih šest platformi, uključujući Linux.

Time se prednost LiveKit-a svodi na Linux jedini — a to je platforma sa najmanjom
publikom ovde. Cena te zamene je nesrazmerna: **Agora kod nas radi dva posla.**
Pored prenosa glasa, ona i **snima čas** — `startAudioRecording` piše *izmešan*
kanal u fajl, zato se u snimku čuju i trener i učenik. LiveKit nema pandan na
klijentu; njegovo snimanje je serverski **Egress** (zaseban servis, Redis, CPU za
mešanje), što na droplet-u sa 1 vCPU nije sitnica, uz TURN i opseg UDP portova.

Prelazak bi, dakle, značio **ponovno pisanje celog lanca snimanja** — sečenja
pauza, sinhronizacije, reprodukcije i MP4 izvoza — dakle baš onog dela koji je
tek proradio.

**Uslov pod kojim se odluka menja:** ako trošak Agore počne da se oseća. Meri se
kroz `agora_seconds` u `USAGE_UNIT_COSTS`, pa će se videti unapred.

### Web je izvodljiviji nego što izgleda — osim snimanja

Web bi ukinuo ceo problem instalacije: nema SmartScreen-a, sertifikata za
potpisivanje, `.exe` fajla ni Store pravila (vidi korak 3a u
[TODO-objavljivanje.md](TODO-objavljivanje.md)).

- **Motor je već rešen.** `stockfish_service_stub.dart` je verzija koja računa
  preko interneta (`lichess cloud-eval`, `stockfish.online`) — put za Web je
  predviđen u kodu. Analiza je slabija nego lokalni Stockfish, ali radi.
- **Glas radi**, jer Agora deklariše web.
- **Snimanje najverovatnije ne radi.** `AgoraRtcEngineWeb.registerWith()` je
  prazan, a u web sloju paketa nema nijednog pomena snimanja — ima kontrolera za
  video prikaz. To treba potvrditi malim ogledom pre nego što se bilo šta planira
  oko Web verzije.

Web bi tako bio: čas uživo, analiza, zagonetke i domaći — **bez snimljenih
časova**. To je i dalje mnogo, ali je odluka o tome šta proizvod jeste.

## Dogovoren model uloga i nadzora — 16.8.2026, još nije napisan

Zamenjuje predlog iznad. Dogovoreno u razgovoru; ovde stoji jer se iz koda neće
moći rekonstruisati zašto je baš tako.

### 1. „Trener" nije osobina osobe nego položaj u odnosu

Odatle sledi sve ostalo. **`users.role` se za podučavanje ne koristi uopšte** —
ostaje samo za `'admin'`. Ista osoba je trener u jednoj vezi i učenik u drugoj:
kao trener ima svoju listu učenika, kao učenik ima svoje trenere.

Time otpada pitanje koje nije imalo dobar odgovor — **ko dodeljuje ulogu trenera.**
Niko. Ne postoji gazda koji potvrđuje da je neko trener; postoji samo veza koju
su obe strane prihvatile.

### 2. Vezu pokreće bilo ko, ali je zasniva pristanak

```
zahtev  →  druga strana prihvati  →  [ako je učenik maloletan] roditelj potvrdi  →  veza važi
```

Smer je slobodan: trener sme da upiše učenika, učenik sme da pošalje zahtev
treneru. Ono što veza **ne** daje dok nije prihvaćena je bilo kakvo pravo.

Šema to podnosi sa jednom kolonom na `trainer_students`:

```sql
status VARCHAR(20) NOT NULL DEFAULT 'accepted'
  CHECK (status IN ('pending', 'awaiting_parent', 'accepted'))
```

Podrazumevano `accepted` usput reši i zatečene redove — u trenutku pisanja ih ima
**tri, na četiri korisnika, od kojih dva čine jedan uzajaman par** (to je i bio
viđeni bag). Sve novo se upisuje izričito kao `pending`, pa migraciona skripta ne
treba.

Bezbednosna ispravka je onda jedan uslov u `trainerOwnsStudent`
(`assignmentService.js`): `AND status = 'accepted'`. Kroz njega prolaze zadaci,
lekcije i izveštaj o učeniku.

Prijateljstvo (`friends`) se **više ne upisuje pri dodavanju nego tek pri
prihvatanju** — inače te neko ubaci među prijatelje bez tvog znanja.

### 3. Saglasnost roditelja se ne proverava — ona se zapisuje

Provera roditeljstva ne postoji ni kod jedne aplikacije; zakon i traži **razuman
napor srazmeran riziku**, ne dokaz. Zato: mejl roditelja, dvostruka potvrda, i
zapis o tome ko je pristao, kad, sa koje adrese i **na koju verziju teksta** —
poslednje zato što se dokument menja, a saglasnost mora ostati vezana za tekst na
koji je data.

Tri stvari koje su namerno tako:

- **Mejl roditelja stoji na vezi, ne na profilu učenika.** Dete može imati dva
  trenera, a saglasnost se tiče *tog* odnosa. Nov trener — nova saglasnost.
- **Traži se samo za maloletne**, pa nalog mora nositi godinu rođenja
  (samoprijavljenu). Odrastao učenik je ovde sasvim običan slučaj.
- **Povlačenje mora biti lako koliko i davanje** — to zakon izričito traži, pa
  link koji roditelj dobije ostaje važeći i nosi dugme koje raskida vezu.

> Zašto se time uopšte bavimo, kad TikTok ne pita nikoga: zato što se bave, i to
> skupo — TikTok €345M (irski DPC, 2023), Instagram €405M (2022), oba baš zbog
> naloga maloletnika. Ali brojke nisu razlog. Razlog je što je **suština ovog
> proizvoda** da se određena odrasla osoba spoji sa određenim detetom u privatnoj
> sobi, sa glasom koji se snima. TikTok se brani time da je javna platforma; ovde
> te odbrane nema. Uz to, Play Console pri objavljivanju **traži** da se prijavi
> ciljni uzrast — to je formular, ne stav.

### 4. Roditelj sme da posmatra svaki čas, i trener ne zna kad

Najjača zaštita u celom modelu, i istovremeno prodajni argument: roditelju koji
bira trenera preko interneta „možete ući na bilo koji čas i dobijate snimak
svakog" znači više od bilo kakvog opisa.

Radi zato što **mogućnost nadzora deluje trajno, a prisustvo samo povremeno.**

Jedna ograda je pravno bitna: **anonimno ne sme da znači tajno.** Trener je i sam
osoba čiji se glas snima, a prikriveno posmatranje je u većini propisa osetljivo.
Zato trener **pri registraciji prihvata pravilo** da svaki čas može biti posmatran
bez najave. Obavešten je o pravilu, ne o pojedinom času — odvraćajuće dejstvo
ostaje, a nadzor prestaje da bude prikriven. Isto važi i za dete.

Tehnički, oslanja se na ono što već postoji:

- **Roditelju ne treba nalog.** `signReportToken` (`middleware/auth.js`) već pravi
  potpisan token sa rokom kojim se izveštaj otvara bez prijave. Isti obrazac nosi
  i ulazak na čas i link ka snimku.
- **Posmatrač mora biti izostavljen iz spiska učesnika**, i to je pravi posao a ne
  prekidač: soba preko Socket.IO razašilje ko je ušao, a snimak upisuje
  `participantIds`. Ako se to ne uredi namerno, trener vidi ulazak i cela zamisao
  pada. Agora ima ulogu *audience* koja sluša bez objavljivanja, pa glasovna
  strana to podnosi.
- **Snimci se šalju kao link mejlom**, istim mehanizmom i sa rokom, kao izveštaji.

### Šta je odlučeno, a šta čeka

Odlučeno i spremno za pisanje: tačke 1, 2 i 4 — pristanak, smer, i posmatranje.

Čeka pravnika: tekst saglasnosti (`saglasnost-roditelja.md`) i da li je opisani
postupak dovoljan po ZZPL-u. **Kolone se ipak dodaju odmah**, jer prazna kolona
danas ne košta ništa, a ista kolona nad živim podacima kasnije košta migraciju.

## Ako droplet postane tesan, kojim redom — 17.8.2026

Zapisano jer je lako pretpostaviti da se MP4 izvoz „samo prebaci na drugu
mašinu". Ne prebacuje se: `routes/recordings.js` uzima zvuk iz `uploads/` sa
**lokalnog diska**, a `videoRenderer.js` piše gotov fajl u `exports/`, isto
lokalno. Druga mašina bi morala da dođe do tog zvuka — a `uploads/` je jedina
kopija dečjih glasova.

Redosled kad zatreba:

1. **Veći droplet.** Jedan restart, nijedna izmena u kodu. Za 1 vCPU / 2 GB je to
   najjeftiniji potez i verovatno dovoljan zadugo.
2. **Odvajanje izvoza tek uz konkretan simptom** — da renderovanje usporava API,
   ili da veći droplet više ne pomaže. Povlači prelazak `uploads/` na objektno
   skladište, što uzgred rešava i to da su snimci danas na jednom disku.

Sajt ne učestvuje ni u jednom koraku: statičke stranice nginx servira bez CPU
troška, pa ostaje gde jeste i u slučaju da se izvoz odseli.

## Dve greške nađene 22.8.2026 — obe zatvorene 27.8.2026

Obe je korisnik primetio u Windows verziji dok je proveravao trener završnica,
i obe su bile van onoga što je tada rađeno. Zapisane su namerno neurađene.

**Zašto su čekale — odlučeno 23.8.2026.** Projekat je još u izgradnji i korisnik
je zasad **jedini koji ga koristi**: nema deteta kome se mikrofon otvara i nema
tuđeg naloga koji ostaje zaglavljen u poluprijavljenom stanju, pa je stvarna
cena obe greške tada bila nula. Obe ipak moraju biti zatvorene pre nego što
aplikaciju dotakne iko osim vlasnika — glas zato što otvara mikrofon detetu i
troši novac, istek tokena zato što tuđi korisnik nema odakle da zna da treba
ručno da se odjavi. Obe su zatvorene 27.8.2026, u istom prolazu.

### Glas se uključivao sam i naplaćivao se — zatvoreno 27.8.2026

`_initAudioChat()` se pozivao **bezuslovno iz `initState`** u
[chess_game_screen.dart](../chess_app/lib/screens/chess_game_screen.dart) — čim
se uđe u sobu, tražio se Agora token, otvarao se glasovni kanal i backend je
počinjao da meri. Iz korisnikovog loga:

```
19:58:50  [AUDIO] User pavle joined audio in room STUDIO
19:59:07  [AUDIO] User 5 left audio in room STUDIO
19:59:08  [AUDIO] Booked 18s of voice for user 5
```

Osamnaest sekundi glasa naplaćeno za sesiju u kojoj niko nije nameravao da
priča; minut ranije još četiri. Agora se plaća po minutu **prisustva u kanalu**,
ne po minutu govora, i `usage_counters` to broji kao potrošnju.

Nije bio samo trošak. **Mikrofon se otvarao pre nego što je iko rekao da hoće
razgovor**, a većina korisnika su deca.

**Kako je rešeno.** Ulazak u kanal je sada na dugme, za sve — korisnikova odluka
od 27.8.2026, čime pada i ograda koja je ovde stajala („trener možda očekuje da
ga se čuje odmah"): trener pritisne isto dugme kad počne čas. Kanal se otvara
samo kroz `_joinVoice()`, i zatvara kroz `_leaveVoice()` bez izlaska iz sobe.

Ono što ovo drži da ne postane tišina: `audio_users_list` se emituje **celoj
sobi**, ne samo onima u kanalu, pa onaj ko nije uključio glas vidi da se
razgovara i dobija dugme **„Priključi se razgovoru"** umesto „Uključi glas". Bez
tog reda učenik bi sedeo u tišini ne znajući da ima šta da se čuje.

Tri sitnice koje su izašle usput, sve tri iste vrste:

- `voice_level_changed` (trener daje ili oduzima reč) je zvao `_rejoinVoice()`
  bezuslovno — kod nekoga ko nikad nije ušao u glas to bi **otvorilo kanal na
  trenerov pritisak, na učenikovom uređaju**. Sada se odbija ako je glas
  isključen, a poruka to i kaže: „Važi čim uključite glas."
- Neuspeo ulazak vraća panel na dugme, sa razlogom iznad njega; inače bi nudio
  „Isključi glas" za kanal u kome niko nije.
- Studio nema glas uopšte (vidi popravku studija niže).

`test/voice_on_request_test.dart` čuva pravilo: `initState` ne sme da pomene
nijedan ulazak u glas, `_initAudioChat` sme da ima **tačno dva** pozivna mesta
(dugme i ponovni ulazak), a `_rejoinVoice` mora da ima ogradu. Dokazano
mutacijom — vraćen poziv u `initState` i uklonjena ograda obore tri testa.
Funkcije se čitaju **poklapanjem zagrada**, i komentari se skidaju pre provere,
jer komentar koji pominje poziv nije poziv.

Ostaje provera uživo: dva naloga u istoj sobi, jedan uključi glas i drugi vidi
„Priključi se razgovoru"; i pogled u log da posle ulaska u sobu nema
`[AUDIO] joined` dok se dugme ne pritisne.

### Istekao Agora token je gasio glas usred časa — popravljeno 27.8.2026

Nađeno čitajući isti kod. Token se izdavao **jednom, pri ulasku**, i trajao
`AGORA_TOKEN_TTL_SECONDS` (podrazumevano 3600). U celom `lib/` nije bilo ni
`renewToken` ni `onTokenPrivilegeWillExpire`, pa je čas duži od sat vremena
ostajao bez zvuka — bez poruke, bez reda u logu, sat vremena posle greške. Isti
oblik kao sve ostalo u toj sekciji CLAUDE.md-a.

Agora javlja **30 sekundi ranije** (`onTokenPrivilegeWillExpire`), i još jednom
kad je već kasno (`onRequestToken`). Oba sada vode u jedno mesto koje ponovo
pita server — a `/agora/token` svaki put iznova pita `maySpeakInRoom`, pa
osvežavanje nije samo produžetak nego i ponovna provera prava.

Odluka je izdvojena iz radnje (`AgoraService.refreshAction`) da bi mogla da se
testira bez engine-a, časa i sat vremena čekanja. Četiri odgovora, jer „uzmi nov
token" je tačno samo ako se ništa drugo nije promenilo:

- **soba odbija** (izbačen sa spiska usred časa) → izlazak iz kanala i poruka, a
  ne tiho ostajanje dok Agora ne preseče;
- **nema odgovora, ili server nema sertifikat** (prazan token) → pita se ponovo,
  jer bi `renewToken('')` prekinuo baš vezu koju poziv čuva. Tri pokušaja na osam
  sekundi, sve unutar prozora od 30 s; kad se potroše, kanal se **ostavlja na
  miru** — server koji se ne javlja nije soba koja je odbila;
- **pravo se promenilo** (dobio ili izgubio mikrofon) → pun ponovni ulazak, jer
  `renewToken` menja token a ne ulogu: učenik kome je mikrofon upravo dat držao
  bi publisher token kao `audience`;
- **ista stolica, nov token** → zamena u mestu, niko ne čuje prekid.

`test/voice_seat_test.dart` drži sva četiri, dokazano mutacijom (uklonjene grane
`refused` i `token.isEmpty` — oba testa padaju). Ostaje provera uživo: čas duži
od TTL-a, ili privremeno smanjen `AGORA_TOKEN_TTL_SECONDS` da se ne čeka sat.

### Istekao token nije odjavljivao korisnika — zatvoreno 27.8.2026

```
19:56:25  [SOCKET AUTH] Rejected connection: jwt expired
```

Socket je bio odbijen, a klijent to nije tumačio kao kraj sesije. `401` se hvatao
jedino u
[server_status_service.dart](../chess_app/lib/services/server_status_service.dart),
i to samo da bi se ispisala traka na kontrolnoj tabli. Posledica koju je korisnik
prijavio: aplikacija kaže da treba da se prijavi ponovo, i dalje ga smatra
prijavljenim, pa **mora prvo ručno da se odjavi** iz sesije koju je server već
odbacio.

Sada postoji jedno mesto koje „server ne prima ovaj uređaj" pretvara u odlazak
sa ekrana: `SessionService.expire(reason)` postavlja razlog, ruter ga sluša
(`refreshListenable` + `expiredSessionRedirect`) i vodi na prijavu **odakle god
korisnik bio**, a ekran za prijavu pročita razlog i kaže ga. Dva razloga, ne
jedan, jer traže suprotne stvari od čoveka: `expired` čeka istu osobu da se
prijavi ponovo, `account-gone` nema koga da prijavi.

Četiri ulaza vode u to jedno mesto, po redu koliko rano hvataju:

1. **Sam token, pri pokretanju.** `SessionService.init()` ne obnavlja zapamćenu
   sesiju čiji je `exp` prošao — inače aplikacija pozdravi po imenu, a svaki
   zahtev iza tog pozdrava bude odbijen. Čita se iz tokena, bez mreže, jer
   odluka pada pre prvog ekrana, a to što nema veze nije razlog da se veruje
   mrtvom papiru.
2. **Povratak u prvi plan** (`SessionWatch` u `main.dart`) — telefon ostavljen
   preko noći sa otvorenom aplikacijom. Poređenje, ne upit.
3. **Soket**, koji je i najbrži signal: server odbija rukovanje pre nego što
   ijedan ekran bilo šta zatraži. `looksLikeRefusedToken` razlikuje tu rečenicu
   (`Invalid or expired authentication token`) od običnog `websocket error` —
   odjaviti nekoga zato što je pao vaj-faj bilo bi gore od greške koja se ovde
   popravlja.
4. **`_checkServerAndSession`** na kontrolnoj tabli sada dela i na `expired`, ne
   samo na `gone`. `offline` i dalje ne radi ništa, iz istog razloga.

Isto pravilo kao na serveru (`services/accountGuard.js`): **„ne znam" ne sme da
stigne kao „napolje si"**. Token koji ovaj parser ne ume da pročita, `exp` koji
ne postoji, server koji ćuti — ništa od toga nije odbijanje.

`test/session_expiry_test.dart` (16 provera) drži i jedno i drugo lice pravila,
dokazano mutacijom: uklonjena provera `exp`-a u `init()` i `looksLikeRefusedToken`
koji uvek kaže „da" — oba obore po jedan test.

**Šta nije urađeno:** 53 mesta u `lib/` (25 fajlova) i dalje šalju
`Authorization: Bearer` ručno i ne rade ništa posebno sa `401`. Prolaz kroz sva
nije napravljen; praktično se ne oseti, jer soket na istom ekranu dobije isto
odbijanje u istoj sekundi i sesija se završi pre nego što taj `401` išta znači.
Kad se bude radilo, ide kroz jedan `http.Client` omotač, ne kroz 53 izmene.

Ostaje provera uživo: prijaviti se, ručno skratiti `JWT_EXPIRES_IN` na serveru
(ili izmeniti sat), sačekati istek i videti da aplikacija sama završi na ekranu
za prijavu sa porukom „Prijava je istekla".

## Roditeljska saglasnost: tekst je potvrđen, tok nije napisan

**Advokat je 25.8.2026 potvrdio** da su politika privatnosti i obrazac
saglasnosti ispravni i da pokrivaju ono što aplikacija stvarno radi —
uključujući snimanje glasa dece, koje je i bio razlog da se pišu. Time je pao
jedini razlog zbog kog tok nije napisan: čekao se tekst, ne kod.

**Ograda je njegova, ne naša:** proverio je za Srbiju i rekao da za druge države
ne zna. Iz toga slede dve stvari, i obe su inženjerske:

1. **Gde se aplikacija nudi je odluka, a ne podrazumevana vrednost.** Play deli
   svuda ako mu se ne kaže drugačije. Dok pravna provera pokriva jednu državu,
   spisak zemalja treba suziti na nju.
2. **Uzrast ide u podešavanje, ne u `if`.** Granica ispod koje je saglasnost
   obavezna razlikuje se po državama, pa je nijedan broj u kodu ne sme
   predstavljati kao univerzalnu. Isto važi za sam tekst: verzija na koju je
   neko pristao upisuje se u `parent_consent_version` — kolona postoji od ranije
   i do sada je bila prazna.

Šta je u bazi već pripremljeno, a nema ko da napuni: `trainer_students` ima
`parent_email`, `parent_consent_at`, `parent_consent_ip` i
`parent_consent_version`, i status `awaiting_parent` između `pending` i
`accepted`. Oblik toka je dakle već zamišljen — veza sa trenerom ne postaje
`accepted` dok roditelj ne potvrdi.

Popunjena verzija dokumenata (ime, adresa, email, URL) **ne ide u ovaj
repozitorijum**, jer je javan; u `docs/` ostaju nacrti sa praznim poljima, koji
su ionako ono što opisuje šta aplikacija radi.

## Rizik koji nije u tekstu saglasnosti nego u obliku aplikacije

Primedba je korisnikova i tačna: problem u drugim državama verovatno neće biti
*šta* aplikacija radi sa podacima — to pokriva saglasnost — nego **da li
izgleda kao mesto na kom se maloletnici povezuju međusobno**. Propisi koji
ograničavaju decu na društvenim mrežama (Australija ima zakon za mlađe od 16;
sličnih predloga ima i drugde) kače se za oblik: veze korisnik–korisnik,
pronalaženje drugih korisnika i direktna komunikacija. Ne za temu.

**Kod nas je ta površina mala i uglavnom već zatvorena pristankom** — veza
trener–učenik ne postoji dok druga strana ne prihvati, i test pada ako neko
napiše četvrtu kopiju tog uslova bez `status = 'accepted'`.

**Jedan izuzetak, i on je oštar:** `POST /friends/add` prima **email**, nađe
korisnika i odmah upiše vezu **u oba smera, bez ijednog pristanka druge
strane**; `GET /friends` zatim vraća ime i email. Dakle svako ko zna email
deteta može sebe da ubaci u njegov spisak — i to je istovremeno ono što najviše
liči na društvenu mrežu i jedina rupa u modelu pristanka koji je svuda drugde
poštovan. U aplikaciji to je tab „Ljudi".

Tri izlaza, od najjeftinijeg:

1. **Prijateljstvo dobija pristanak**, isto kao veza trener–učenik: `pending` →
   `accepted`, isti obrazac koji već postoji i već je testiran.
2. **Maloletnik nema prijatelje, nego samo trenera.** Najjači odgovor na pitanje
   o državama, jer aplikacija tada nije mesto gde se deca povezuju međusobno —
   a jeftin je, pošto model veze već postoji.
3. **Izbaciti prijatelje.** Tab „Ljudi" bi pokazivao trenere i učenike. Time se
   pravna površina svodi na „alat za podučavanje" umesto na „mrežu".

Uz bilo koji od njih: spiskovi ne treba da vraćaju **email** drugog korisnika.
To je podatak koji tamo ništa ne rešava, a jeste podatak o detetu.

**Teže od prijatelja: soba nema spisak zvanica.** Nađeno 25.8.2026, dok se
proveravala tuđa preporuka da se „glas isključi maloletnicima". Ta preporuka
promašuje metu — glas *jeste* čas, trener drži lekciju glasom i snima je — ali
je pokazala pravo pitanje: ne da li dete sme da priča, nego **ko sme da bude u
sobi dok priča**. Odgovor je danas: bilo ko.

    socket.on('joinGame', async ({ roomId, playerColor }) => {
      socket.join(roomId);

`joinGame` u `server.js` ne proverava ni vezu trener–učenik, ni poziv, ni to da
li je pozivalac uopšte prijavljen — gost ulazi kao „Gost". `audio_join` je isti,
pa ko uđe u sobu, uđe i u glas; ako trener snima, taj glas ide u `uploads/`,
među snimke dečjih glasova. Kod sobe je šest cifara iz `Math.random()`
(`routes/rooms.js`), bez ograničenja broja pokušaja.

To je gore od `/friends/add`: prijatelj vidi email, a ovo je neko u živom
razgovoru sa detetom. Zato ide **prvo**, pre svega ostalog oko saglasnosti.

## Odakle sutra — 26.8.2026, 00:20

Sve je commitovano i **pushovano** (`493f8db`), droplet je povučen na isti
commit, CI se pokrenuo i nije proveren.

**Sajt stoji na jednom koraku:** u `.env` na dropletu fale `PRIVACY_EMAIL` i
`SUPPORT_EMAIL`, jer adrese na domenu još ne postoje. MX zapisi
`chesstrainers.app` već pokazuju na Namecheap-ovo preusmeravanje
(`eforward1–5.registrar-servers.com`), pa je posao samo dodati aliase u panelu
i proslediti ih na Gmail. Ostale vrednosti su upisane i proverene
(`OPERATOR_NAME`, `OPERATOR_ADDRESS`, hosting, `SMTP_PROVIDER=Google (Gmail)`,
datum, `EXPORT_RETENTION_DAYS=14`). Posle toga je objava jedna komanda:
`LE_EMAIL=… bash deploy/site-setup.sh` — i **pre nje prevod stranica na
engleski**, po odluci iznad.

**Nađeno usput, popravljeno na dropletu:** `MAIL_FROM` je glasio
`Chess Master <…@gmail.com>` — Ubisoft-ov brend u pošiljaocu svake poruke,
uključujući poruku roditelju. Ime je promenjeno u `Šahovska obuka`; adresa nije
dirana, jer Gmail ne šalje sa neverifikovane. **Isti red skoro sigurno stoji i u
lokalnom `.env`.**

**Zamka na koju sam nasankao, da se ne ponovi:** `git fetch --depth 1 origin
master` na plitkom klonu ostavi `origin/master` na starom commitu, pa
`checkout -B master origin/master` „uspe" i vrati stari kod. Traži izričit
refspec `+refs/heads/master:refs/remotes/origin/master` — kako i piše u
`deploy/app-setup.sh`, dva reda iznad te komande. I dalje: **ne pokretati
`app-setup.sh`** samo radi povlačenja koda, jer on radi `systemctl enable` i
`restart` servisa koji je namerno ugašen.

**Ostalo otvoreno, po veličini:** prevod sajta i pravni status prevoda; nivoi
pretplate (`CENA-I-PRETPLATA.md`, odeljak 7); `checkUserLimits` bez pozivaoca;
slanje pošte sa domena (SPF/DKIM) umesto sa lične Gmail adrese;
`PUBLIC_BASE_URL` prazan na dropletu. ~~Kanvas sa predlozima za panel
trenera, koji čeka izbor varijante~~ — kanvas je napravljen 26.8.2026, korisnik
je 27.8.2026. izabrao **A + značka iz C**, i to je napisano; ostaje samo provera
uživo (stavka 39 u [TODO-provera.md](TODO-provera.md)).

## Sledeće, po redu

Stanje na kraju 24.8.2026. Sve iz prošlog spiska pod 2–6 je urađeno; ostaje
ovo.

1. **Provera uživo onoga što još nije viđeno.** Tačke `0l`–`0p` u
   [TODO-provera.md](TODO-provera.md). Korisnik je prošao navigaciju, tabove i
   desktop prečice i našao tri stvari koje su odmah popravljene (nestali tabovi
   pri izlasku iz vežbe, nevidljiva podešavanja na Windows-u, Ctrl+, vezan za
   pogrešan taster). **Nije još viđeno:** sve oko govora na telefonu, nalaz
   tablica, „Zaključi remi", i rute zadataka.

2. ~~**Spisak prečica**~~ — urađeno 24.8.2026, **nije viđeno uživo** (stavka
   23 u [TODO-provera.md](TODO-provera.md)). Ruta `/shortcuts`, a otvaraju je
   **F1** i red „Spisak prečica" u Podešavanjima — na telefonu, gde tastature
   nema, taj red je jedini put.

   `?` namerno **nije** vezan, iako je bio predviđen: to je znak koji neko može
   da kuca u komentar ili u kod sobe, a prečica iznad cele aplikacije bi mu ga
   uzela iz polja. F1 nijedan raspored ne kuca — ista pouka kao Ctrl+, vezan po
   mestu tastera, a ne po znaku.

   Spisak ne može da zastari ćutke: test čita `desktop_shortcuts.dart` i
   `move_keyboard_shortcuts.dart`, vadi svaki `LogicalKeyboardKey` iz njih i
   pada ako se veže taster koji na spisku ne piše. Zato i piše, uz svaku grupu,
   *gde* radi — strelice su za sada samo u šetnji kroz partiju, i tako i stoji.

3. ~~**Ostale prečice**~~ — sve tri stavke urađene 24.8.2026. Strelice i
   Ctrl-prečice su i **proverene uživo** istog dana (stavke 24 i 25 u
   [TODO-provera.md](TODO-provera.md)); slova u treneru završnica i razmak u
   reprodukciji još nisu (stavka 26). Dogovoreno je bilo, ovim redom:
   - ~~Ctrl+1…4 za četiri taba, Ctrl+C za kopiranje FEN-a~~ — urađeno i
     **provereno uživo** 24.8.2026 (stavka 25 u
     [TODO-provera.md](TODO-provera.md));
   - ~~strelice na preostalih pet ekrana~~ — urađeno 24.8.2026, **nije viđeno
     uživo** (stavka 24 u [TODO-provera.md](TODO-provera.md)). Analiza, soba,
     lekcija, ponavljanje i AI ekran; `MoveKeyboardShortcuts` je isti omotač
     koji je šetnja kroz partiju već imala, plus Home/End kao drugo ime za
     ↑/↓. Dva mesta su dobila i ogradu koja nije bila u planu: u **ponavljanju**
     tasteri rade tek kad je nastavak otkriven, jer bi inače tastatura govorila
     odgovor pre nego što se dete seti; u **sobi** važi isti uslov koji traka
     već ima (`canDriveSharedBoard`), da mesto koje ne vodi zajedničku tablu ne
     povede je tastaturom. Uz to, na svakom od pet ekrana kursor se sada pravi
     na **jednom** mestu (`_moveCursor()`) umesto po jednom za traku i jednom za
     tastere. Test čita `lib/` i pada ako ekran sa trakom nema i strelice;
     jedini izuzetak je `engine_line_dialog`, jer dijalog drži fokus i uzeo bi
     tastere ekranu ispod sebe;
   - ~~u treneru završnica slova: N sledeća, R ispočetka, H pomoć, T nalaz,
     U vrati potez; razmak za pusti/pauziraj u reprodukciji~~ — urađeno
     24.8.2026, **nije viđeno uživo** (stavka 26 u
     [TODO-provera.md](TODO-provera.md)). Time je spisak pod 3 završen.

     Slova i razmak dele jedan omotač, `ActionKeyShortcuts`: dobija mapu
     taster → dugme, gde **null znači da tog dugmeta sada nema na ekranu**.
     To je pravilo koje drži spisak prečica istinitim — taster radi tačno
     onoliko koliko i dugme koje predstavlja, pa nema stanja u kom tastatura
     ume nešto što se na ekranu ne vidi. U treneru je mapa pisana kao ogledalo
     `_buildControls`, uslov po uslov, uključujući i zaključanu tablu dok
     tablica odgovara.

     **Razmak je jedini taster koji namerno ustupa mesto.** Fokusirano dugme
     na razmak odgovara samo, i to je pravilo koje aplikacija ne sme da
     razbije: ko šeta ekran Tab-om mora da može da pritisne ono na čemu je
     stao. Zato je razmak vezan samo dok fokus drži sam omotač. Slova takvog
     suparnika nemaju.

   Dve ograde: prečica **nikad nije jedini put** do radnje, jer na Androidu
   tastature nema; i **jedno slovo samo na ekranima bez unosa teksta**, pošto
   dok je fokus u polju to slovo pripada polju.

   **Tri stvari koje je ovaj krug naučio, i koje važe za svaku sledeću
   prečicu.**

   *Prvo: prečica vezana unutar ekrana ne radi dok ekran ne drži fokus.* Pritisak
   se nudi onome ko ima fokus pa redom njegovim precima — vezivanje koje sedi
   *ispod* fokusiranog čvora niko nikad ne pita. Tek otvoren ekran ostavlja
   fokus na samoj ruti, pa su strelice ćutale sve dok se na ekranu nešto ne
   klikne. Izgleda kao „ponekad radi", što je najgori oblik kvara. Lek je jedna
   linija: omotač drži `Focus(autofocus: true, skipTraversal: true)` — uzima
   fokus samo ako ga niko drugi ne traži, pa polje za tekst i dalje dobija svoje
   tastere kad se u njega klikne. Test `move_keyboard_shortcuts_test.dart` pritiska
   strelicu **bez ijednog klika pre toga** i pada ako se to vrati.

   *Drugo: `CallbackShortcuts` proguta taster i kad ništa nije uradio.* Ctrl+C
   vezan tako je uzimao kopiranje svakom polju za tekst u aplikaciji — a to
   vezivanje stoji bliže fokusu nego Flutter-ovi ugrađeni tasteri za tekst, pa
   je pobeđivalo. Zato je Ctrl+C napisan kao `Action` koji ume da **odbije**
   taster (`isEnabled` je netačno dok se kuca ili kad table nema): odbijen
   taster putuje dalje i polje odradi svoje kopiranje. Isto važi za svaku
   buduću prečicu koja se preklapa sa nečim ugrađenim.

   *Treće, nađeno pri poslednjoj stavci: spisak prečica je bio nepotpun, a test
   to nije video.* Test je čitao tri fajla po imenu, a stablo poteza u Analizi
   veže **+** i **−** iz četvrtog — ni jedno ni drugo nije bilo na spisku, jer
   fajl koji je dobio prečicu niko nije dopisao u test. Sada se čita ceo `lib/`,
   pa nema liste koja mora da se održava da bi test radio; izuzet je samo sam
   omotač, koji imenuje tastere kojima **ustupa** mesto, a ne veže nijedan svoj.
   Tri prečice stabla poteza su usput dopisane na spisak, uz „gde radi" — one
   traže da se prvo klikne u stablo.

4. **Pamćenje veličine i položaja prozora.** Traži nativni dodatak
   (`window_manager`) — odluka o zavisnosti, ne usputan posao. Posle
   `flutter_tts`-a i `nuget`-a vredi je doneti svesno.

5. ~~**Lichess, dve stavke.**~~ — urađeno i **provereno uživo** 24.8.2026
   (stavka 22 u [TODO-provera.md](TODO-provera.md)). Baza otvaranja ide kroz
   `GET /opening-explorer`: jedan token stoji u `.env` na serveru, keš je isti
   oblik koji `tablebaseService` ima za tablice, i token je prestao da bude
   uslov za korisnika. Dugme sa pre-popunjenim linkom je ostalo u Podešavanjima,
   ali sada za onoga ko *hoće* svoj — polje uz njega je izlaz u nuždi ako naš
   token ikad bude odbijen.

   Dve stvari koje treba znati pre nego što se pusti u rad: **`LICHESS_API_TOKEN`
   mora u `.env`**, inače ruta vraća 503 sa `reason: "not-configured"` i svi
   dobijaju ChessDB; i **jedan token je jedno grlo za sve**, pošto Lichess broji
   upite po tokenu. Keš zato nije ušteda nego uslov — pozicije iz otvaranja se
   kod sve dece ponavljaju, pa je pogodak čest. Ruta traži prijavu (`authenticateToken`)
   da ne bi bila otvoren proksi čim server izađe na internet; gost dobija ChessDB,
   što je tačno ono što je i pre imao.

6. **Unija „Dobij" i „Greške iz partija"** — procenjeno i odloženo. Šetnja
   nema „Odigraj do kraja" ni igranu kaznu. Kad se bude radilo, izdvojiti alate
   nad pozicijom u zajedničku komponentu umesto spajanja ekrana.

7. ~~**Trenažer repertoara**~~ — **svi delovi su urađeni 31.8.2026**, nijedan
   nije viđen uživo (stavke 29, 30, 62–66 u [TODO-provera.md](TODO-provera.md)).
   Skica je u [repertoire_trainer_spec.md](arhiva/planovi/repertoire_trainer_spec.md); gradilo
   se odozdo, jer je celina bila najveća stavka koja je do tada predložena i
   takmičila se sa objavljivanjem.

   - ~~**Sudija** — jedan endpoint i panel u Analizi~~ — urađeno i provereno
     uživo 24.8.2026. Vredi sam za sebe i bez ijednog repertoara, i dokazuje
     priču o kešu i opterećenju pre nego što se na njoj zida.
   - ~~**Režim izgradnje**~~ — urađeno 24.8.2026, nije viđeno uživo (stavka
     29). Prag je 80% u izabranoj traci, najviše četiri odgovora, a ostatak se
     broji i prijavljuje. Odluke su u odeljku „Repertoar: režim izgradnje".
   - ~~**Uvežbavanje**~~ — urađeno 24.8.2026, nije viđeno uživo (stavka 30).
     Kroz postojeći SM-2, ali sa svojom tabelom `repertoire_reviews`; zašto ne
     kroz proširen `review_items`, piše u odeljku „Repertoar: drill".
   - ~~**Putanja i izvedena granica**~~ — urađeno 31.8.2026, nije viđeno uživo.
     Ekran za izgradnju sada kaže u kojoj je liniji i nastavlja tamo gde je
     stao. Odeljak „Repertoar: gde sam u stablu".
   - ~~**Radar pokrivenosti**~~ — urađeno 31.8.2026, nije viđeno uživo.
     Ispalo je tačno onako kako je i procenjeno: nijedan nov račun i nijedna
     nova ruta, samo `branches` iz iste šetnje. Odeljak „Radar pokrivenosti".

   Tri odluke koje važe za sve delove: repertoar živi **na serveru**, ne u
   lokalnoj bazi, jer ga trener zadaje i gleda, a reinstalacija ne sme da
   obriše godinu dana rada; rang se bira **prema učeniku**, ne fiksnih „1800+",
   pošto dete sreće poteze od 1200; i kazna se **odigra**, ne objasni — za to
   već postoje „Kazni" i „Odigraj do kraja" iz trenera završnica.

8. **i18n na kraju**, kad prestanu da se menjaju ekrani. Odluka i razlozi su u
   odeljku „Sistematizacija prostora".

## Šta namerno nije urađeno

- **`CustomPuzzleSolverScreen` nema rutu** — nosi povratni poziv `onAnswered`,
  dakle je korak u toku, ne mesto.
- **`AiStudioScreen` nije formatiran** `dart format`-om — nad tim fajlom pravi
  850 izmenjenih linija umesto 40 i obara `analyze`. Formatira se kad se bude
  delio, i tada mu ide i pravo ime: nema veze sa AI.
- **Unija „Dobij" i „Greške iz partija"** — procenjeno, korisnik odložio.
  Šetnja i dalje nema „Odigraj do kraja" ni igranu kaznu.

## Brojke, da se vidi da li je nešto puklo

`cd chess_app && flutter test` → **653**, `flutter analyze` čist.
`cd chess_backend && npm test` → **517**.

## Sledeće na redu

Poređano po odnosu dobitka i uloženog. Sve sa ranije liste (admin nalog, swap,
politika brisanja fajlova, uvoz partija, MP4 izvoz) je urađeno i provereno
uživo. Ostaju:

- **Prvo: rad na aplikaciji.** Korisnik je 16.8.2026. rekao da ima još izmena u
  samoj aplikaciji, pa je **prebacivanje namerno odloženo** — ono je jedina
  stavka koja usporava razvoj, jer posle njega svaka izmena backenda traži
  push, pull i restart umesto da je `nodemon` sam pokupi. Rad na Flutter strani
  se ne usporava, ali koristi od prebacivanja nema dok aplikaciju koristi samo
  vlasnik kod kuće.
- **Prebacivanje na server** kad to bude gotovo — sve je spremno i provereno.
  Dve stvari idu zajedno: `systemctl enable --now chess-backend` i `backendUrl` u
  [constants.dart](../chess_app/lib/constants.dart) sa LAN adrese na
  `https://api.chesstrainers.app`. Jedno bez drugog razdvaja snimke časova.
  Kad dođe vreme, ne mora biti sve-ili-ništa: debug build sme da ostane na
  lokalnom backendu, a probni da se pravi sa
  `--dart-define=BACKEND_URL=https://api.chesstrainers.app`.
- ~~Zvonce kao vlasnik odgovora na zahtev~~ — urađeno 20.8.2026.
- ~~Prihvatanje se ne vidi kod pošiljaoca~~ — rešeno i **provereno uživo na dva
  uređaja 20.8.2026** (stavka 21 u [TODO-provera.md](TODO-provera.md)).
- Ostatak probe pristanka: ponovno slanje posle odbijanja, samo obaveštenje o
  odbijanju, i obaveštenja posle popravke — stavke 0 i 0a u
  [TODO-provera.md](TODO-provera.md). Proba pristanka je inače prošla uživo
  17.8.2026, i uzajaman par je raskinut.
- **Sajt** na korenu domena — sadržaja još nema, pa ni sertifikata za `@` i
  `www`. Vidi korak 3a u [TODO-objavljivanje.md](TODO-objavljivanje.md).
- ~~Faza 2 unifikacije — `MoveCursor`~~ — urađeno 20.8.2026, čeka proveru
  uživo (stavka 20 u [TODO-provera.md](TODO-provera.md)).
- **Prisilan redosled kao zastavica na zadatku**, ako se ikad pokaže potreba —
  vidi pitanje 1. Namerno nije napravljeno unapred.
- Provere uživo iz `TODO-provera.md`: izveštaj za roditelja, zadaci tipa
  lekcija, ponavljanje u razmacima, merenje troška (stavka 10 — endpoint sad
  radi, izveštaj nikad otvoren).
- **Skener pozicija iz knjiga** — odeljak iznad. Parser na Node-u radi i izmeren
  je (99,98% na prvoj knjizi). Mapa fonta za drugu knjigu je gotova 20.8.2026 —
  210 dijagrama, 0 nemogućih pozicija. Sledeće je ekran za potvrdu u aplikaciji;
  faza 2 (skenirane slike) čeka merenje tačnosti na pet strana pre nego što se u
  nju uloži.
- **Knjiga kao interaktivna lekcija** — procenjeno 20.8.2026, odeljak u skeneru.
  Izvodljivo, pola je već napravljeno, ali tek posle ekrana za potvrdu i
  objavljivanja. Prevod proze čeka pravnika, mapiranje slova figura ne čeka
  nikoga.
- Veći, netaknuti poduhvati iz procene: dnevna zagonetka i niz dana, grupe i
  prisustvo, chat i video, višejezičnost.

## Kako se proverava

```bash
cd chess_app && flutter analyze && flutter test
```

Trenutno: čisto, 162 testa prolaze.

```bash
cd chess_backend && npm test
```

Pokretanje (server pa aplikacija):

```bash
cd chess_backend; npm run dev
```

```bash
cd chess_app; flutter run -d windows 2>&1 | Tee-Object -FilePath run.log
```

## Zamke koje su nas već koštale vremena

- **PowerShell je 5.1**, ne 7. Nema `&&` kao separator, `Tee-Object` nema
  `-Encoding`.
- **`run.log` je UTF-16LE** (tako piše `Tee-Object`), pa ga `grep` ne vidi.
  Prvo: `iconv -f UTF-16LE -t UTF-8 run.log > /tmp/r.log`.
- **Tražiti *prvu* grešku u logu**, ne poslednju. Kod Flutter-a lavina
  `MouseTracker` poruka je posledica jednog ranijeg izuzetka iz layout-a.
- **Baza se čita ovako** (obavezno `ssl` iz `DB_SSL`, inače „no pg_hba.conf
  entry"):
  ```js
  new Pool({host:process.env.DB_HOST, port:process.env.DB_PORT,
    user:process.env.DB_USER, password:process.env.DB_PASSWORD,
    database:process.env.DB_DATABASE,
    ssl:String(process.env.DB_SSL)==='true'?{rejectUnauthorized:false}:false})
  ```
- **Lokalni snimci** su u SharedPreferences:
  `AppData/Roaming/rs.pejovic/chess_app/shared_preferences.json`, ključ
  `flutter.local_session_recordings_list`. Korisno za proveru da li je greška u
  podacima ili u prikazu — kod nas je dvaput bila u prikazu.
- **Ključevi klijent/server su se već tri puta razišli** (`account_type` vs
  `accountType`, `studentEmail`, status 200 vs 201). Pri svakoj novoj ruti
  uporediti `jsonEncode` na klijentu sa `req.body` destrukturiranjem na serveru.

## Način rada koji korisnik očekuje

- Odgovori na srpskom.
- Ne nagađati uzrok — doći do dokaza (log, baza, endpoint, test koji pada bez
  popravke). Ovaj ciklus je tri puta demantovao uverljivu hipotezu podacima.
- Uz popravku ide test koji pada bez nje; to je provereno `git stash`-om.
- Kad se nešto ne može proveriti uživo, upisati u `TODO-provera.md`, ne
  prećutati.

## Snimanje časa je uklonjeno — odluka od 26.8.2026

**Čas se više ne snima.** Zvuk se prima samo iz sobe u kojoj je **jedan jedini
učesnik — punoletan vlasnik sobe**, koji tako pravi sopstveni materijal, skida ga
i objavljuje gde hoće. Interakcija trenera i učenika nema zvučni zapis ni uz čiju
saglasnost.

### Zašto, kad je bilo napravljeno i provereno uživo

Pitanje je postavljeno kao „koliko bi se smanjio pravni posao bez snimanja", i
merenje je dalo suprotan odgovor od očekivanog:

- **vezano samo za snimanje:** `recordingConsent.js`, kolona
  `parent_allows_recording`, treće polje na roditeljskoj stranici, jedan test;
- **ostaje bez obzira na snimanje:** `parentConsentService`, `ageService`,
  `relationshipService`, `accountGuard`, `routes/consent.js`, `awaiting_parent`,
  `parent_consent_at/ip/version`, `AGE_OF_CONSENT` — 52 mesta u 10 fajlova.

Ta mašinerija ne postoji zbog snimanja nego zato što **dete ima nalog, a trener
vidi njegove podatke**. Papirologija se, dakle, jedva smanjuje.

Ono što se smanjuje je izloženost. `uploads/` je bio jedina kopija dečjih
glasova — jedini podatak ovde koji se ne može reprodukovati, anonimizovati ni
povući. Uz to nestaje „audio" iz Play prijave podataka i ceo odeljak koji bi
advokat morao da odobrava **po svakom tržištu posebno**, dok je advokat 25.8.2026.
pokrio samo Srbiju.

Oštriji deo, koji je i presudio: izbacivanje gađa deo koji je **već plaćen i
završen** (Srbija, uključujući snimanje), a deo koji se razlikuje od zemlje do
zemlje — uzrast za saglasnost, 13 do 16 — ostaje i posle njega. Jedino što bi
zaista srušilo pravni posao je da deca nemaju naloge, a to je proizvod.

### Šta je dobijeno, a ne samo uklonjeno

Trener sam u sobi pravi video lekcije i objavljuje ih. To je funkcija sa uzlaznom
stranom — kanal kojim ljudi dolaze do aplikacije — dok snimanje časa sa detetom
nema nijedna šahovska aplikacija, i verovatno ne slučajno.

### Kako je izvedeno

Pravilo je zamenjeno **unutar `mayRecordRoom`**, a mehanika oko njega je ostala:
sva četiri pozivna mesta, zaustavljanje snimanja, spisak učesnika i drugi katanac
pri upisu rade kao pre, samo odgovaraju na drugo pitanje.

Tri odluke u tom pravilu, svaka je mesto gde bi tiho prestalo da znači nešto:

- **Gost obara snimanje.** Nema nalog, pa nema ni godine ni vezu — pod starim
  pravilom bio je nevidljiv. Pod ovim mu nalog ne treba: on je neko drugi u sobi,
  a to je celo pitanje. Zato spisak učesnika sada čuva i njegov socket id.
- **Nepoznata godina je odbijanje, ne prolaz.** Svuda drugde u ovoj bazi
  neizjašnjen uzrast je namerno propušten; ovde je obrnuto, jer je reč o dozvoli
  da nastane jedini artefakt koji se ne može povući.
- **Osamnaest, ne `AGE_OF_CONSENT`.** Taj prag je 13–18 po zemlji i odgovara na
  drugo pitanje. Ovo je objavljivanje sopstvenog glasa, dakle punoletstvo.

**Odbija se zvuk, a ne čas.** Ranije je upis vraćao 403 i bacao ceo snimak, čime
se zbog pravila o zvuku gubio i tok table stvarnog časa. Sada se čas uvek čuva i
pregleda nemo, a izostane samo zvuk — ista pouka kao ranija odluka da se detetu
ne oduzima čas nego snimanje.

### Usput nađeno i popravljeno

Spisak učesnika je prešao na niske da bi primio goste, a `stopRecordingForConsent`
je i dalje brisao **brojeve** iz skupa niski — dakle ništa, i ćutke. Uhvatio ga je
postojeći test. Isti oblik greške koji ovaj dokument nabraja od početka.

### Stanje

`npm test` 517 prolazi, `flutter test` 653 prolaze, `flutter analyze` bez ijedne
primedbe u dirnutim fajlovima. Čuvar upisa je dokazan mutacijom: bez brisanja
odbijenog fajla test pada.

`PARENT_CONSENT_VERSION` je podignut na `rs-2026-08-26`, jer se tekst promenio —
bez toga bi već date saglasnosti pokazivale na formulaciju koja više ne postoji.
**Mora se podići i u `.env` na dropletu.**

### Otvoreno

- `docs/politika-privatnosti.md` i `docs/saglasnost-roditelja.md` su druga kopija
  pravnog teksta koji stvarno izlazi iz `site/` i `routes/consent.js`. Usklađeni
  su sa ovom izmenom, ali dve kopije istog pravnog teksta se pre ili kasnije
  raziđu. Odlučiti da li se brišu ili ostaju samo kao obrazloženje.
- Isti fajlovi još nose ime „Chess Master" u naslovu, koje je odbačeno.
- Kolona `parent_allows_recording` je ostavljena u bazi i više se ne piše ni ne
  čita. Nije obrisana namerno — rušenje kolone je nepovratno, a šteta od nje je
  nula.

## Snimak table sa glasom u studiju — odbijeno 27.8.2026

**Predlog:** trener u Šahovskom studiju priča dok izvodi poteze, iz toga nastaje
snimak (tabla se pomera uz glas, plejer a ne renderovan video), i taj snimak se
ubaci u lekciju da ga učenici odslušaju.

**Odluka: ne gradi se.** Ni sada, ni u ovom obliku. Razlozi, po težini.

**Plejer je danas lošiji od videa, ne bolji.** Ceo argument za „plejer umesto
videa" je da format ume nešto što video ne ume. `replay_player_screen.dart` drži
`enableUserMoves: false` — učenik gleda. Ostaje slajder i izbor brzine, dakle
video plejer sa manje funkcija nego YouTube: bez CDN-a, bez titlova, bez
puštanja u pozadini na telefonu, i bez weba, jer Agora tamo nema snimanje. Ono
što bi format opravdalo — da učenik zaustavi, odigra potez sam, pita motor,
skrene u varijantu — ne postoji. Dok toga nema, premisa predloga ne stoji.

**Ono što je opisano već postoji i već je provereno uživo.** Trener sam u sobi →
snimi → izvezi MP4 → objavi gde hoće; tako i piše u odeljku „Snimanje časa je
uklonjeno". Razlika je samo u tome što bi snimak stajao *unutar* aplikacije i
bio zakačen za lekciju. To je udobnost, a ne nova mogućnost. I gore: dobitak od
snimljenog materijala je u tom odeljku opisan kao **kanal kojim ljudi dolaze do
aplikacije**, što važi za javni materijal. Materijal zaključan iza naloga tu
stranu nema uopšte — predlog uzima jedinu jasnu korist od snimanja i sklanja je.

**`uploads/` nije tog oblika.** `retentionService.js` izričito ostavlja taj
direktorijum na miru: jedina kopija, nikad se ne briše. Pravilo je pisano za
šačicu nezamenljivih snimaka časa. Materijal za učenje je proizvodna traka —
trener koji pravi kurs napravi desetine fajlova, namerno i zauvek, na jednom
dropletu koji drži i API. Vidi „Ako droplet postane tesan, kojim redom"; ovo je
najbrži put dotle. Apsurd je što je to materijal koji trener *hoće* da objavi,
pa baš on ne mora da bude nešto čemu je ova aplikacija jedina kopija.

**Studio deo ima nedokazanu tehničku premisu.** Zvuk ide kroz
`agora_rtc_engine.startAudioRecording`, motor napravljen za kanal, a u studiju
nema ni sobe ni kanala ni tokena. Možda radi bez `joinChannel`, možda traži drugi
audio put — ne zna se dok se ne proba. A vrednost studija (stablo varijanti,
evaluacija, eksplorer) je tačno ono što `TimelineEvent` ne beleži, pa bi format
morao da se proširi na kretanje kroz stablo. To je skupi deo funkcije čiji jeftini
delovi već premašuju dobitak.

**I peti razlog, koji je presudio.** 280 neoznačenih provera u 44 stavke,
53 koraka do objave, a poslednja nedelja su ispravke iz prvog prolaska kroz
aplikaciju: studio nije mogao da se otvori, pešak nije mogao da promoviše, pet
nalaza na ekranu za prijavu. Aplikaciju još nije koristio niko osim vlasnika.
Funkcija za deljenje materijala učenicima pretpostavlja učenike, a trenera koji
je ovo tražio još nema.

### Šta mora da putuje uz ovo ako se ikad bude gradilo

- **`ADULT_AGE = 18`, i nepoznata godina znači odbijanje.** Pravilo iz
  `recordingConsent.js` ne sme da ostane iza u sobi: bez njega glas
  petnaestogodišnjaka završi u `uploads/`.
- **`/uploads` se servira statički i bez provere** (`server.js`). Danas je to
  bezopasno, jer URL ima samo vlasnik snimka — ali se naoruža istog trenutka kad
  se bilo šta podeli, jer je onda reč o trajnim linkovima bez provere. Obrazac za
  popravku već postoji: `signDownloadToken` / `authenticateDownloadToken`, kako
  MP4 izvoz već radi.

### Jeftina varijanta, kad se pojavi prvi trener koji pravi materijal

**Polje za link na lekciji.** Trener snimi postojećim putem (sam u sobi, MP4
izvoz), objavi na YouTube ili gde hoće, i nalepi link u lekciju. Jedna kolona i
jedno tekstualno polje: bez skladišta, bez Agore, bez novog puta za saglasnost,
radi i na webu, i zadržava akvizicionu stranu. To je ujedno i način da se sazna
da li treneri uopšte prave materijal, pre nego što se za to gradi cev.

### Naziv je ispravljen 27.8.2026, funkcija nije dirana

Kartica na početnom ekranu zvala se **„Snimljeni časovi (Replay)"**, a dijalog za
čuvanje nudio naziv **„Čas 27.8.2026"** — imena za nešto što aplikacija od
26.8.2026. više ne pravi. Sada je „Snimljeni materijal", odnosno „Materijal
27.8.2026"; isto i u dijalogu za čuvanje i u MP4 izvozu. Plejer, izvoz i
rekorder ostaju kakvi jesu, jer je zastareo bio **naziv, a ne funkcija** —
trener sam u sobi i dalje pravi materijal, i to je jedini snimak koji je
preživeo odluku iznad.

Test u `home_tabs_test.dart` pada ako se stara reč vrati, i proveren je
mutacijom.

### Polje „Unesite kod sobe" — razmotreno i namerno ostavljeno

Predloženo je 27.8.2026. da se izbaci sa početnog ekrana. **Ostaje za sada**, jer
na njemu vise dve stvari koje sa ekrana ne mogu da se vide:

- **Neprijavljen gost nema drugi ulaz.** `room_guests_dialog.dart` obećava
  „ulazi svako ko zna kod sobe, i neprijavljen", a to polje su ta vrata. Brisanje
  polja pretvara guest-access prekidač u obećanje koje se ne može ispuniti.
- **Poruka o zakazanom času sama deli kod.** `routes/social.js` upisuje
  obaveštenje čiji tekst glasi „Kod sobe: …", pa bi posle brisanja učenik dobijao
  broj koji nema gde da otkuca.

Prijavljeni učenik ionako ne zavisi od polja: postoje trenerov poziv uživo
(`lesson_invite_received`), obaveštenje o zakazanom času sa sopstvenim dugmetom
„Pridruži se", i traka za nastavak započetog časa. **Odluka o polju je, dakle,
odluka o gostima** — i tek kad se ona donese, briše se i ostalo što uz nju ide.

---
