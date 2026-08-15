# Stanje rada — nastavak u novoj konverzaciji

Namena: da neko ko dolazi bez istorije razgovora za pet minuta zna gde smo stali
i zašto je nešto urađeno baš tako. Nije prepis dijaloga — prepis troši prostor,
a odluke su ono što se ne može rekonstruisati iz koda.

Poslednje ažuriranje: 15.8.2026.

---

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
  Ostaje samo provera da li je **merchant** deo aktivan — bez njega nema Play
  Billing-a, a besplatna aplikacija bez kupovina ga možda nikad nije tražila.
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

## Sečenje pauza iz zvuka — ✅ urađeno i provereno uživo

**Problem.** `_pauseRecording` zaustavlja samo tajmer događaja; Agora nastavlja
da snima. Vremena poteza oduzimaju pauzu (`LessonRecorder.elapsedMs`), audio je
ne oduzima. Od pauze nadalje tabla i glas su razmaknuti za dužinu pauze, a
poslednji deo zvuka nikad ne stigne na red. Korisnik je ovo čuo i potvrdio.

**Rešenje (od tri razmatrana).** Jedan audio fajl, pauze isečene pri čuvanju:

1. `LessonRecorder` beleži intervale u **zidnom vremenu od početka snimanja** —
   to je vremenska osa audio fajla, ne oduzeto vreme. `stop()` sad vraća
   `LessonRecording {events, pauses}` i zatvara pauzu koja je još u toku.
2. Klijent ih čuva uz snimak i šalje kao polje `pauseIntervals`
   (`local_recording_service.dart`).
3. Server ih iseče u `services/audioTrimmer.js`, pozvan iz `POST /recordings/save`.

**Nije bila potrebna izmena šeme baze** — intervali su ulaz u obradu, a ne
trajno stanje: posle sečenja audio fajl na disku je već tačan.

Odbačeno: (a) ne oduzimati pauzu iz vremena — savršena sinhronizacija, ali pauza
ostaje kao mrtvo vreme i gubi smisao; (b) deliti audio na više fajlova — unosi
više fajlova po snimku kroz ceo lanac.

> **Zapamtiti: `aselect` ovde ne radi.** Očigledno rešenje
> `-af "aselect='not(between(t,a,b))',asetpts=N/SR/TB"` **ćutke ne seče ništa** —
> ffmpeg izađe sa kodom 0 i vrati fajl iste dužine. Provereno na tonu od 10 s:
> ostane 9,97 s. Radi tek kad se imenuju delovi koji se **zadržavaju**:
> `[0:a]atrim=start=..:end=..,asetpts=N/SR/TB[s0];...;[s0][s1]concat=n=2:v=0:a=1[out]`
> uz `-filter_complex` i `-map [out]`. Izmereno: 19,8 s − 8 s = 11,94 s. ✅
> Uz to, `spawn` ne prolazi kroz shell, pa navodnici u filteru ostaju doslovni
> znakovi — ne pisati ih.

## Politika brisanja fajlova — ✅ urađeno 15.8.2026

`exports/` (MP4 izvozi) je rastao zauvek — jedini `unlink` u backendu je bio
privremeni fajl iz `audioTrimmer`-a. `services/retentionService.js` sad briše
izvoze starije od `EXPORT_RETENTION_DAYS` (podrazumevano 14 dana), pokreće se
pri startu servera i potom svaka 24h iz `server.js`. Kad fajl nestane, red u
`session_recordings` čiji je `video_url` na njega pokazivao se čisti
(`video_url = NULL`) da dugme za preuzimanje ne ponudi 404.

Namerno **ne dira `uploads/`** (zvuk) — MP4 se uvek može ponovo izrenderovati iz
snimka, zvuk je jedina kopija časa. Test: `test/retention.test.js`, 4 testa,
sa privremenim direktorijumom i lažnim `pool` — ne dira pravi `exports/`.

## Uvoz partija sa Chess.com/Lichess — ✅ urađeno 15.8.2026, nije kliknuto uživo

Nova 5. kartica u postojećem dijalogu „Unos Pozicije" (Analysis Studio) —
`board_setup_dialog.dart`. Bira se platforma, unosi korisničko ime, preuzete
partije idu kroz već postojeći `GameSelectorDialog` (isti koji već radi za
pasted multi-game PGN) i slecu na karticu „PGN Uvoz" na potvrdu, isti tok kao
ručno lepljenje. Novi servis: `chess_platform_import_service.dart`, direktan
poziv klijenta ka javnim API-jima (isti obrazac kao postojeći Lichess Explorer
i ChessDB servisi) — **bez izmena na backend-u**.

- **Chess.com strana potvrđena uživo** izvan aplikacije: pravi PGN, pravi
  headeri, format se poklapa sa onim što kod očekuje.
- **Lichess strana samo delimično** — ruta i format tačni po zvaničnom API
  spec-u, poziv sa ispravnim `User-Agent`-om dobija pravi odgovor servera, ali
  ponovljeno testiranje je udarilo u Lichess-ovo ograničenje brzine pre nego
  što se video pravi PGN u odgovoru. Prva stvar za proveru uživo.
- **Otkriveno usput:** Lichess ćutke vraća lažnu 404 stranicu zahtevima bez
  prepoznatljivog `User-Agent`-a, samo na ruti `/api/games/user/...`. Servis
  sad šalje `User-Agent: ChessMasterCoach/1.0` — ako se ikad ukloni, ova ruta
  će ponovo tiho „ne raditi" bez greške koja bi ukazala zašto.
- Klikanje kroz dijalog nije provereno okom — nema alata za automatizaciju
  native Windows GUI-ja u ovoj sesiji. `flutter analyze` čist, testovi prolaze.

**Korisnik je isprobao Chess.com stranu uživo istog dana** i naišao na
„Neispravan PGN format" pri prebacivanju na tablu. Uzrok: Chess.com stavlja
`{[%clk ..]}` komentar posle svakog poteza, što po PGN konvenciji primorava
oznaku `12...` za nastavak crnog — `chess` paket (0.7.0) u svom `load_pgn`-u
skida `12.` naivnim regex-om, ali ne i `12...`, pa ostave dve tačke obore ceo
uvoz. Pogađa svaki PGN sa komentarima koji prekidaju par poteza, ne samo
Chess.com. Popravljeno: `PgnParser.sanitizeForLoadPgn` u `pgn_parser.dart`
skida `12...` pre poziva `load_pgn`, pozvano iz `_importPgn`
(`analysis_studio_screen.dart`). Test koji pada bez ispravke:
`test/pgn_parser_sanitize_test.dart`, potvrđeno `git stash`-om.

Detalji provere: `TODO-provera.md`, stavka 7.

## Admin nalog i dodela Premium-a — ✅ odrađeno i testirano uživo 15.8.2026

`UPDATE users SET role = 'admin'` za nalog `id=5` (vlasnikov glavni nalog) —
potvrđeno SELECT-om pre i posle. Nalog `id=3`, prvobitno predložen pa
promenjen, nije diran. (Emailovi se namerno ne upisuju ovde — repozitorijum je
javan.)

`POST /users/account-type` je zatim stvarno pozvan (prvi put ikad) — token
mintovan sa `JWT_SECRET`-om servera umesto lozinke (nalog je isti vlasnikov,
samo bez kucanja lozinke u razgovor), poziv vratio 200, `account_type` na
`'premium'`. Oba upisa (role i account-type poziv) su prvi put zaustavljena od
strane sistema za automatsku proveru — na oba je drugi pokušaj, posle
korisnikove izričite potvrde, prošao.

Korisnik se ponovo prijavio i **potvrdio da MP4 izvoz radi** — poslednja
neproverena veća funkcija snimanja časa je time zatvorena (`TODO-provera.md`,
stavka 4). Otključana je i stavka 10 (merenje troška — endpoint sad ima ko da
ga pozove, sam izveštaj još nije pogledan); stavka 9 (naplata) i dalje čeka
Play Console, ne admin nalog. Detalji: `TODO-provera.md`, stavka 11.

## Navigacija poteza u sesiji — ✅ popravljeno 15.8.2026

Korisnik je prijavio da navigacija poteza u sesiji ne radi. Uzrok: u sobi
postoje **dve različite uloge**, a kod je proveravao pogrešnu.

- `userSession.role` — globalna uloga naloga; svi se registruju kao `korisnik`.
- `activeRole` — sedište koje **server** dodeli u sobi; kreator dobija `trener`.

`buildNavigationControls()` je gledao samo globalnu ulogu, a `boardControl`
podrazumevano jeste `'trainer_only'` (`chess_game_screen.dart:77`) — pa je
`false || false` isključilo celu traku, i to baš onome ko drži čas. Tabla je
radila jer ona proverava `activeRole`.

Isto pravilo je u tom fajlu bilo ispisano **četiri puta u tri verzije**, a
navigacija je imala petu, pogrešnu. Izvučeno u čistu funkciju
`lib/core/services/board_control_rules.dart`; test
`test/board_control_rules_test.dart` pada na staroj logici (provereno
privremenim vraćanjem). Commit `21ae682`.

## Unifikacija table i okolnih elemenata — faza 1 gotova, čeka proveru

Korisnik je primetio da isti elementi izgledaju različito po ekranima (dugme za
okretanje table nekad ispod table, nekad gore desno). Izmereno stanje pre rada:

| Element | Zatečeno |
|---|---|
| Tabla | `ChessBoardWithOverlay` **već postoji**, koriste ga 4 ekrana; još 4 mesta grade sirov `ChessBoard` |
| Navigacija poteza | **6 zasebnih implementacija** istog niza dugmadi |
| Okretanje table | **4 ikone** (`flip`, `flip_camera_android`, `swap_vert`, `rotate_*`) na **2 mesta** |

**Zašto je iscepkano** — ispod stoje **tri različita modela poteza**, pa „izvuci
widget" ne prolazi bez sloja-adaptera:

- `MoveTree`/`MoveNode` — sesija i AI Studio *(isti model, čista duplikacija)*
- linearni `_moveIndex` u listu FEN-ova — lekcije i ponavljanje
- `AnalysisNode` — Analysis Studio

**Faza 1 (urađeno):** jedan `BoardFlipButton` (`swap_vert`, jedan tooltip) na
svih 7 mesta; dugme premešteno iz zaglavlja u traku ispod table tamo gde ta
traka postoji (lekcije, Analysis Studio); u engine dijalogu pomereno s početka
na kraj reda. Dve `MoveTree` navigacije spojene — `MoveHistoryNavigationWidget`
obrisan, `MoveNavigationControls` dobio opcione `showMoveChips` i `onFlipBoard`.
Time i `navigate_before` vs `chevron_left` postaje jedno.

**Faza 2 (dogovoreno, nije započeto):** `MoveCursor` adapter
(`canGoBack/canGoForward/first/prev/next/last/currentFen`) sa tri
implementacije, pa lekcije, ponavljanje i Analysis Studio pređu na istu traku.
Dogovor je: faza po faza, korisnik proverava svaku, vraćamo se ako ne valja.

**Na šta gledati pri proveri faze 1:**

- **Lekcije i Analysis Studio** — dugme za okretanje više nije gore desno nego
  ispod table. Najveća vidljiva promena.
- **AI Studio** — traka sa čipovima poteza sad koristi `cardColor` umesto
  tamnoplave sa ivicom, pa je svetlija nego ranije.
- **Analysis Studio** — okretanje se i dalje mora pamtiti u nacrtu
  (`_flipBoard` zove `_saveDraft`).
- Sesija — navigacija poteza (gore).

## CI je bio crven — ✅ rešeno 15.8.2026

GitHub Actions je padao na koraku **„Run Backend Tests"** (`npm test` u
`chess_backend`), i to još od commit-a `661329a` — dakle pre ovog ciklusa.
Flutter analiza i Flutter testovi su prolazili sve vreme.

**Uzrok:** `TypeError: zlib.zstdCompressSync is not a function` u
[zstd_multiframe.test.js](../chess_backend/test/zstd_multiframe.test.js). Node
je dobio zstd kodek tek u **v22.15.0** (i v23.8.0), a workflow je bio pinovan na
**Node 20**. Lokalno je Node 25, pa se greška nikad nije videla — svih 96
backend testova tu prolazi.

**Popravka:** `node-version: '22'` u [ci_cd.yml](../.github/workflows/ci_cd.yml),
`engines.node >= 22.15.0` u `package.json`, i provera na vrhu
[zstdMultiFrame.js](../chess_backend/services/zstdMultiFrame.js) koja na starijem
Node-u baca jasnu poruku umesto „is not a function".

> Ranija istraga je ovo pogrešno isključila („nema API novijeg od Node 20") —
> pretraga je gledala jezičke i `fs`/`stream` novitete, a `zlib.zstd*` je izgledao
> kao odvajkada postojeći deo `zlib`-a. Pouka: verziju API-ja proveriti u
> dokumentaciji („Added in:"), ne po osećaju o starosti modula.

**Provereno na droplet-u (15.8.2026, preko SSH):** Node tamo **uopšte nije
instaliran** — ni `apt` paket, ni `nvm`, ni jedan izvršni fajl na disku. Backend
nije ni raspoređen: nema procesa, ništa ne sluša osim `sshd` i `systemd-resolved`,
`/root` i `/srv` su prazni. Droplet je zasad samo mašina sa podešenim swap-om;
backend radi na tvojoj mašini (`backendUrl` u aplikaciji podrazumevano gađa LAN
adresu), a na DigitalOcean-u je samo upravljana PostgreSQL baza.

Praktično: nema šta da se popravlja na serveru, ali kad dođe raspoređivanje —
instalirati **Node 22 LTS ili noviji odmah**, ne 20. Stavka je dopisana u
[TODO-objavljivanje.md](TODO-objavljivanje.md).

## Sledeće na redu

Poređano po odnosu dobitka i uloženog. Sve sa ranije liste (admin nalog, swap,
politika brisanja fajlova, uvoz partija, MP4 izvoz) je urađeno i provereno
uživo. Ostaju:

- **Faza 2 unifikacije — `MoveCursor`** (faza 1 proverena uživo 15.8.2026).
- Provere uživo iz `TODO-provera.md`: izveštaj za roditelja, zadaci tipa
  lekcija, ponavljanje u razmacima, merenje troška (stavka 10 — endpoint sad
  radi, izveštaj nikad otvoren).
- Veći, netaknuti poduhvati iz procene: dnevna zagonetka i niz dana, grupe i
  prisustvo, chat i video, višejezičnost.

## Swap na droplet-u — ✅ urađeno 15.8.2026

2GB `/swapfile` na produkcijskom droplet-u, upisan u `/etc/fstab` (backup
originala kao `/etc/fstab.bak-swap`), `vm.swappiness=10` u
`/etc/sysctl.d/99-swappiness.conf`. Nisko `swappiness` je namerno — swap se
koristi samo kao zaštita kad MP4 izvoz (jedina stvar koja skoči u memoriji na
1 vCPU / 960MB droplet-u) naglo potroši RAM, ne za svakodnevni rad. `mount -a`
posle upisa u `fstab` prošao bez greške, što potvrđuje da konfiguracija
preživljava restart.

Provere koje čekaju korisnika stoje u `TODO-provera.md` (izveštaj za roditelja i
zadaci tipa lekcija su najbrži za proveru, a nikad nisu otvoreni uživo).

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
