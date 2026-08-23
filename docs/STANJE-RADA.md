# Stanje rada — nastavak u novoj konverzaciji

Namena: da neko ko dolazi bez istorije razgovora za pet minuta zna gde smo stali
i zašto je nešto urađeno baš tako. Nije prepis dijaloga — prepis troši prostor,
a odluke su ono što se ne može rekonstruisati iz koda.

Poslednje ažuriranje: 23.8.2026.

---

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

## Koraci lekcije su se čitali na četiri načina — popravljeno 20.8.2026

Korisnik je pri proveri stavke 21 video: trener otvori „Pregled i komentari" za
zadatak od lekcije sačuvane kao **jedna pozicija**, i dobije naslov „Pozicija 1"
iznad praznog kvadrata na kom piše „tabla nije dostupna". Ista lekcija se svuda
drugde otvara ispravno.

Lekcija napravljena u alatu ima `position_list`. Lekcija sačuvana kao jedna
pozicija — sa analize, iz skenera, iz biblioteke — nema ga, i **jeste** jedan
korak, sastavljen od svojih `fen`/`pgn` kolona. To se čitalo na četiri mesta:
pri zadavanju lekcije, u učenikovom pregledaču, u redu za ponavljanje, i na
ekranu pregleda. **Tri su imala rezervu, četvrto nije** — čitalo je samo
`position_list`, nalazilo ništa, i crtalo prazan kvadrat.

Ništa nije puklo i ništa nije prijavilo grešku; jedno od četiri čitanja je samo
znalo manje od ostala tri. Isti oblik kao i sve ostalo u odeljku o ponavljajućoj
grešci.

Sada postoji `stepsOfLesson` u `services/lessonSteps.js` i sva četiri mesta idu
kroz njega. Test čita izvor i pada ako neko ponovo napiše rezervu sam za sebe —
kopija bez nje vraća prazan spisak, a prazan spisak izgleda kao ekran koji je
prosto prazan, ne kao pokvaren. Tako je i preživelo.

## Obaveštenja stižu dok je aplikacija otvorena — 20.8.2026

Korisnik je pri proveri stavke 19 primetio: A pošalje zahtev, B ga prihvati, a
A — ako u tom trenutku **stoji u tabu Prijatelji** — i dalje vidi „čeka
potvrdu". Tek izlazak iz taba i povratak u njega pokaže odnos.

Kad se pogledalo zašto, ispalo je da je osvežavanje ekrana manji deo. `accept`
**nije slao nikakvo obaveštenje**, a `decline` jeste. Onaj ko čeka odgovor
saznao bi da je odbijen, a da je prihvaćen ne bi saznao nikako.

**Šta je urađeno.** `notifyAccept` upisuje red koji je nedostajao. Sam po sebi
bi bio nevidljiv do sledećeg pokretanja aplikacije: klijent čita
`/notifications` pri pokretanju i na dva soket događaja, nikad na tajmeru. Zato
je i druga polovina napravljena odmah — ispalo je jeftinije nego što je
izgledalo, jer registar `onlineUsers` (userId → socketId) već postoji i koristi
ga poziv na čas. Nije trebala nikakva nova soba.

- `services/realtime.js` — registar je izašao iz `server.js` da bi i HTTP rute
  mogle da dohvate povezanog korisnika. `emitToUser` vraća `false` kad je
  korisnik odsutan; to nije greška, red u bazi je trajna polovina i pročita se
  pri sledećem pokretanju.
- Slanje, prihvatanje i odbijanje sada guraju `relationship_changed` drugoj
  strani. Klijent na to ponovo čita obe liste, pa i značka i sivi red u
  Prijateljima žive bez izlaska iz taba.
- `emitToUser` **puca** ako `realtime.init(io)` nije pozvan. Tiho vraćanje bi
  značilo da svaki gurac u aplikaciji ne radi ništa dok logovi izgledaju zdravo
  — tačno oblik greške zbog kog modul i postoji.

Poruka je namerno kratka i bez razloga, kao i kod odbijanja: „<ime> je
prihvatio vaš zahtev."

**Zadaci i pregledi, isti dan.** Provera je pokazala nešto grublje od
zakasnelog obaveštenja: zadaci i pregledi **nisu slali nikakvo**. Učenik je za
novi domaći saznavao tako što otvori spisak, a trener da je urađen na isti
način. Sada:

| Kada | Ko sazna | `kind` |
|---|---|---|
| Trener zada domaći (zagonetke, svoje pozicije, lekcija) | učenik | `assignment_new` |
| Poslednja stavka zadatka padne | trener | `assignment_done` |
| Neko napiše poruku o zadatku | druga strana, ko god da je pisao | `assignment_note` |

Usput su **svih pet ručno pisanih `INSERT INTO user_notifications`** svedena na
jedan, u `services/notifications.js`. Već su se bili razišli: dva su ostavljala
`kind` i `ref_id` na podrazumevanoj vrednosti, pa su poziv na čas i zakazan čas
stizali klijentu kao neprepoznata vrsta i dobijali generičku zvezdicu. Test
čita izvor i pada ako se pojavi šesti — obaveštenje upisano mimo `notify()`
preskočilo bi i gurac, pa se ne bi videlo do restarta.

Završetak zadatka se sada peče na jednom mestu umesto na dva, a `completed_at
IS NULL` u tom `UPDATE`-u je ono što drži obaveštenje na tačno jednom: ponovni
prolazak kroz gotovu lekciju ili ponovo rešena zagonetka ne menjaju nijedan red.

Ostaje otvoreno: **ekran koji je već otvoren se ne osvežava sam.** Zvonce i
Prijatelji da, jer sede na početnom ekranu koji sluša soket; ali učenik koji
stoji u „Moji zadaci" videće novi zadatak tek kad se vrati na spisak. Za to
treba isti potez kao za Prijatelje — soket koji sluša i taj ekran.

## Unifikacija table i okolnih elemenata — faza 2 gotova, čeka proveru

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

**Faza 2 (urađeno 20.8.2026, čeka proveru):** `MoveCursor`
(`lib/core/models/move_cursor.dart`) stoji između trake i modela poteza, pa
traka ne zna ni za jedan od njih — samo za `canGoBack/canGoForward/first/
previous/next/last/currentFen` i, opciono, spisak čipova. Kursor se pravi u
`build()` od zatečenog stanja i zove nazad u ekran, koji radi svoj `setState`;
zato ne nosi sopstveno stanje i nema šta da se raziđe.

Tri implementacije: `MoveTreeCursor` i `LinearMoveCursor` uz sam interfejs,
`AnalysisNodeCursor` pored svog modela u `features/analysis_studio/models/`,
da `core/` ne zavisi od jedne funkcionalnosti. Na traku su prešli lekcije
(pregled zadate lekcije), ponavljanje, Analysis Studio **i** dijalog sa
linijom motora — šest kopija istih dugmadi je sada jedna.

Dve stvari koje su namerno ovakve:

- **`<<` u Analysis Studio-u i dalje vodi na mesto gde se linija odvojila**, ne
  na prvi potez partije. To je oduvek radio, samo je stajalo u ekranu; sad je
  u kursoru i ima test. Bez njega bi „jedna traka za sve" tiho pojela razliku,
  a stajanje u varijanti bi se izgubilo.
- **Ponavljanje je dobilo dugme za okretanje table** kao i svi ostali. Tamo je
  `_orientation` do sada značio dve stvari — kako tabla stoji *i* ko je na
  potezu — pa bi okretanje počelo da laže u tekstu iznad table. Zato se „Beli/
  Crni je na potezu" sad čita iz pozicije.

Dogovor ostaje: faza po faza, korisnik proverava svaku, vraćamo se ako ne valja.

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

Provera je usput otkrila da na tadašnjem droplet-u Node **uopšte nije bio
instaliran**, niti je backend bio raspoređen — vidi sledeći odeljak.

## Nov server — ✅ urađeno 15.8.2026, čeka prebacivanje

**Šta je zatečeno.** Stari droplet je bio Ubuntu 25.04 — izdanje **van
podrške**, bez bezbednosnih zakrpa, sa 2,3 GB dnevnika i punim `openjdk-17-jdk`
iz avgusta 2025. Na njemu nije bilo ničega našeg: ni Node-a, ni koda, ni
procesa; slušao je samo `sshd`. Cela istorija komandi te mašine (provereno u
`.bash_history` pre brisanja) svodi se na `apt upgrade`, pravljenje naloga,
`ufw`, i jedan pokušaj sa Javom. Backend je sve vreme radio na radnoj stanici.

**Odluka: nova mašina, ne nadogradnja.** Put 25.04 → 26.04 nije jedan skok nego
dva `do-release-upgrade` ciklusa na 1 GB RAM-a, sa arhivom preseljenom na
`old-releases` — a nije se imalo šta sačuvati.

**Šta sad postoji:** `chess-backend-ams3`, Ubuntu 26.04 LTS, 1 vCPU / 2 GB /
50 GB, AMS3, dnevne rezervne kopije, rezervisani IP. Node 22.23.2, ffmpeg 8.0.1,
swap 2 GB, `journald` ograničen na 200 MB, `ufw` propušta 22/80/443, nalog
`chess` bez `sudo`. Postavljeno skriptama
[`deploy/provision.sh`](../deploy/provision.sh) i
[`deploy/app-setup.sh`](../deploy/app-setup.sh) — obe idempotentne, da se sledeća
mašina podigne istim redosledom.

**Šta je dokazano, ne pretpostavljeno:**

- `https://api.chesstrainers.app` odgovara sa `200`, sertifikat prolazi proveru
  spolja, `http` se preusmerava. (Do 16.8.2026. je ime bilo privremeno,
  `209-38-55-151.sslip.io` — Let's Encrypt za golu IP adresu ne izdaje
  sertifikat. Stari sertifikat je obrisan da mu obnova ne bi padala.)
- Backend se povezuje na bazu **privatnom VPC mrežom** i sa punom proverom
  sertifikata: `rejectUnauthorized: true`, `TLS socket authorized: true`,
  PostgreSQL 17.10. Pre toga je `openssl s_client` potvrdio da SAN sertifikata
  sadrži i privatno ime — što nije bilo sigurno unapred.
- `initDB` je prošao kroz sve migracije nad postojećom bazom bez izmene podataka.

**Servis je namerno ugašen i isključen iz automatskog podizanja.** Dok aplikacija
gađa lokalni backend, dva servera nad istom bazom znače razdvojeno stanje: čas
snimljen preko jednog nije na disku drugog, a baza tvrdi da postoji. Prebacuje se
u jednom smeru, kad `backendUrl` bude promenjen.

### Sertifikat se obnavlja sam — i šta ga jedino može pokvariti

`certbot.timer` je uključen i budi se dvaput dnevno; obnova kreće tek kad
sertifikatu ostane manje od 30 dana. Provereno 16.8.2026. sa
`certbot renew --dry-run`: „all simulated renewals succeeded". Ništa se ručno ne
radi, a Let's Encrypt uz to šalje opomene na mejl 20, 7 i 1 dan pre isteka.

> **Ne zatvarati port 80.** Provera pri obnovi ide **isključivo preko HTTP-a** na
> `api.chesstrainers.app`. Pomisao da 80 više ne treba je razumna — `.app` je na
> HSTS preload listi, pa pregledači ionako nikad ne idu na HTTP — i baš zato je
> opasna. Zatvoren 80 u `ufw`-u, ili izbačen HTTP `server` blok iz nginx
> konfiguracije, obara obnovu **ćutke**: ništa ne prijavi grešku, a sajt nestane
> tri meseca kasnije.

Stanje se proverava sa `certbot certificates`. Kad sajt na korenu domena dobije
svoj sertifikat, pridružuje se istom tajmeru bez dodatnog podešavanja.

**Dve greške u sopstvenim skriptama, obe uhvaćene ponovnim pokretanjem:**

1. Skripta je pri svakom prolazu iznova ispisivala nginx konfiguraciju iz
   šablona, koji nema TLS blok — njega dodaje certbot. Zaštita „ne traži
   sertifikat ako postoji" preskakala je jedini korak koji bi TLS vratio, pa je
   server tiho spao na port 80. **Ništa nije prijavilo grešku u tom trenutku.**
   Popravljeno sa `certbot install --cert-name`.
2. `sed s/^KEY=.*/` ne radi ništa kad ključa nema, i to ćutke — promenljiva
   dodata u `.env.example` sutra ne bi stigla na server. Zamenjeno funkcijom
   `set_env` koja dopisuje red ako ga nema.

> Pouka koja se ponavlja kroz ceo dan: **tiho preskakanje je gore od pada.** Isto
> važi za `zlib.zstd*` u CI-ju i za `DB_CA_PATH`, koji namerno obara proces ako
> fajl ne postoji, umesto da se vrati na neproverenu vezu.

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

## Otvoren problem: ko je trener, a ko učenik — niko to ne odlučuje

Primećeno 15.8.2026: **učenik može treneru da zada zadatak i lekciju.** To nije
propust u proveri nego posledica modela — provere rade tačno ono što piše u
njima.

Dva pojma se ovde mešaju, a samo jedan nešto znači:

- **`users.role`** se pri registraciji **uvek** postavlja na `'korisnik'`
  ([auth.js:35](../chess_backend/routes/auth.js) — vrednost je zakucana). Kolona
  poznaje `'trener'` i `'ucenik'`, ali ih ništa nikad ne upisuje. `requireRole`
  se koristi na tačno dva mesta, oba za `'admin'`. Uloga u sesiji sobe je opet
  treća stvar — ona se dodeljuje po ulasku u sobu i nema veze sa podučavanjem.
- **`trainer_students`** je jedino što stvarno određuje odnos. Red nastaje u
  `POST /trainer/students/add` ([social.js:9](../chess_backend/routes/social.js)),
  koji sme da pozove **bilo koji prijavljen korisnik za bilo koju tuđu adresu**,
  bez provere uloge i **bez pristanka druge strane**. Uz to se upisuju i
  simetrični redovi u `friends`.

Zato je „trener" prosto onaj ko je prvi kliknuo „dodaj učenika". Ako obojica
dodaju jedan drugog, obojica mogu da zadaju zadatke — što je tačno ono što se
videlo.

Vredi znati dokle to seže: `POST /assignments/report/:studentId` proverava isti
taj odnos ([assignments.js:202](../chess_backend/routes/assignments.js)) i onda
pravi **izveštaj o aktivnosti tog korisnika**, sa deljivim linkom. Provera je
ispravna, ali nasleđuje slabost veze koju proverava — a reč je o podacima dece.

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

## Odlučeno: zvonce je vlasnik odgovora na zahtev — ✅ napisano 20.8.2026

Odluka je sprovedena; odeljak ispod je zadržan kao zapis razloga, a šta je
tačno urađeno stoji u „Zvonce je dobilo kvačicu i krstić" niže.

Zahtev za odnos danas postoji na **dva** mesta: kao kartica „Čeka vaš odgovor" u
tabu Prijatelji i kao obaveštenje u zvoncetu. Odgovara se samo na prvom; zvonce
te uputi da odeš tamo. To je dvostruko vođenje iste stvari i već se jednom
osvetilo — obaveštenje je ostajalo nepročitano zauvek, jer ništa nije povezivalo
odgovor sa njim.

**Dogovoreno 17.8.2026:** vlasnik radnje postaje **zvonce**. Kvačica i krstić
sele se u obaveštenje, a kartica iz taba Prijatelji nestaje. Razlog: dete koje
dobije poziv gleda u zvonce, ne pretražuje tabove — a zvonce je jedino mesto koje
već nosi brojač, pa je i jedino koje samo od sebe kaže da nešto čeka.

Posao je **odložen namerno**, jer dira oba ekrana i njihove testove, a večerašnje
popravke su već velike. Kad se bude radilo:

- `pendingRequests` prestaje da bude ulaz u `HomeFriendsTab`; filtriranje po
  `i_asked` u tom tabu onda gubi svrhu i treba ga ukloniti zajedno sa karticom,
  da ne ostane mrtav kod koji izgleda kao pravilo.
- Obaveštenje tipa `student_request` nosi `ref_id`, što je upravo `id` reda u
  `trainer_students` — dakle sve što treba za `accept`/`decline` je već u redu
  obaveštenja, ništa se ne dodaje u bazu.
- Posle odgovora obaveštenje se već označava pročitanim
  (`closeRequestNotification`), pa taj deo ne treba pisati ponovo.

## Obaveštenja: beo ekran, nedostupno zvonce, značka koja laže — ✅ 17.8.2026

Tri odvojena kvara u istom uglu ekrana, sva tri prijavljena sa uređaja.

**Beo ekran na Androidu.** `home_dialogs.dart` je čitao `n['room_code'] as
String`, a ta kolona je od 16.8. **nullable** — migracija ju je namerno
oslobodila `NOT NULL` da bi obaveštenje moglo da nosi zahtev za odnos, koji nema
sobu. `as String` nad `null`-om baca `TypeError` usred gradnje, što je u release
build-u beo ekran. Pade **ceo** dijalog, pa i pozivnice u sobe koje su ispravne,
jer se lista gradi u jednom prolazu.

Opet isti obrazac: server je izmenjen, klijent je ostao na staroj pretpostavci, i
vidi se tek jedan sloj kasnije. Sad se `kind` poštuje — pozivnica u sobu nudi
„Pridruži se", zahtev za odnos kaže gde se odgovara, a obaveštenje o odbijanju ne
nudi ništa jer nema šta da se odgovori.

**Zvonca nema na Windows-u.** `appBar: isLandscape ? null : AppBar(...)` — u
landscape-u AppBar-a nema uopšte, a zvonce je živelo u njemu. Windows prozor je
uvek landscape, pa obaveštenja nisu bila dostupna **nikako**. Prebačeno u
`leading` od `NavigationRail`-a, jedino što u tom rasporedu preživi.

**Značka je brojala sve.** `GET /notifications` vraća poslednjih 20 bez obzira na
`is_read`, a značka je prikazivala `_notifications.length`. Broj se nije menjao ma
koliko čitao — i ne bi se promenio ni posle sinoćne popravke koja zahteve
označava pročitanim. Sad broji samo nepročitana.

Uz to, naslov dijaloga se prelivao 184 px na 360 px, pa je i on dobio `Expanded`.
Isti oblik kao zaglavlje u tabu Prijatelji: `Row` sa golim `Text`-om.

## Odbijanje više ne ćuti — 17.8.2026

Odbijen zahtev se briše, i to namerno: bez toga ponovno slanje ne bi radilo. Ali
pošiljalac je ostajao bez ijednog traga — nema obaveštenja, stavka nestane iz
liste — pa sa njegove strane „odbijen sam" i „nikad nisam ni poslao" izgleda
isto. Prirodan odgovor na to je da pošalje ponovo, i opet.

Sad `POST /relationships/:id/decline` javlja pošiljaocu: „*X nije prihvatio vaš
zahtev.*" Nova vrsta obaveštenja `request_declined`, `ref_id` prazan, jer nema
šta da se odgovori.

Namerno **bez razloga za odbijanje** — ne traži se i ne prosleđuje. Odbijanje
koje mora da se obrazloži teže se daje, a ovde odbijaju i deca.

Pošiljalac je uzet kao „onaj drugi učesnik", ne kao trener: zahtev pokreće bilo
koja strana, pa pošiljalac sedi čas u jednoj čas u drugoj koloni.

## Uzajaman par se više ne može ni napraviti — ✅ 17.8.2026

Korisnik je pitao pre nego što je instalirao: šta ako je A trener osobi B, pa B
pošalje zahtev da bude trener osobi A? Odgovor je bio da to prolazi.

`requestRelationship` je postojeći odnos tražio **samo u istom smeru**
(`trainer_id = $1 AND student_id = $2`). Obrnuti red je drugi red, pa ga taj
upit ne vidi — i par u kome se dvoje uzajamno uče mogao je da nastane i posle
uvođenja pristanka. Pristanak je samo učinio da ne nastane nečujno: druga strana
klikne na karticu koja piše „želi da vas upiše kao učenika", bez ijedne reči o
tome da odnos u suprotnom smeru već traje.

Dokumentacija je pritom tvrdila suprotno („ispravka sprečava nove takve"), što je
ispravljeno u `TODO-provera.md`.

Sad upit gleda oba smera i odbija, uz poruku koja kaže **šta je zatekao**:

- odnos već postoji u suprotnom smeru → „Sa tom osobom već postoji odnos — ona je
  vaš trener. Raskinite ga pre nego što zatražite obrnuto."
- zahtev u suprotnom smeru još čeka → „Rešite njega pre nego što pošaljete ovaj."

Odbija se i kad je obrnuti zahtev tek `pending`, iz istog razloga: dva reda ne
smeju da odlučuju ko kome zadaje domaći.

Zašto odbijanje, a ne upozorenje: premisa modela je da je *trener* pozicija u
odnosu — ali u **jednom** odnosu. Par u kome su oboje i trener i učenik čini sva
prava simetričnim nad dečjim podacima i ne opisuje ništa što se dešava na času.
Ako dvoje zaista menjaju uloge, ispravan potez je raskid pa nov odnos u drugom
smeru; test `the reverse row does not block once it is gone` čuva da taj put
zaista bude otvoren, da odbijanje ne postane ćorsokak.

Klijent ne treba menjati — `_addStudent` već ispisuje `data['error']`.

## Tab Prijatelji je poricao pola odnosa — ✅ popravljeno 17.8.2026

Nađeno uživo, i najlepše se vidi na dva ekrana istovremeno: nalog trenera vidi
učenika u listi, a učenik na svom telefonu čita **„Nemate još uvek dodatih
prijatelja"** — za isti, prihvaćen odnos.

Tab je crtao samo `/trainer/students`, dakle ljude kojima si **ti** trener.
Ruta `/students/trainers` postoji od početka i vraća drugu polovinu, ali je
klijent nikad nije pozvao. Odnos je jedan red čitan sa dva kraja; prikazivan je
samo jedan kraj.

Sad su dve sekcije, **„Moji učenici"** i **„Moji treneri"**, iz obe rute. Red
trenera nema dugme za napredak i zadatke — to pripada onome ko predaje — ali
**ima** raskid: pristanak koji se ne može povući sa jedne strane nije pristanak.

Uz to se `pending` red filtrira po `i_asked`: zahtev koji čeka **mene** stoji
samo u kartici „Čeka vaš odgovor", a ne i dole u listi. Bez toga bi ista osoba
bila na ekranu dvaput — jednom sa kvačicom i krstićem, jednom posivljena.

## Prihvatanje se nije videlo bez restarta — ✅ popravljeno 17.8.2026

Nađeno uživo, u samoj probi pristanka: učenik je prihvatio na telefonu, a kod
trenera je i dalje stajalo „čeka potvrdu" dok aplikaciju nije ugasio i ponovo
pokrenuo. Lista se dohvatala **samo u `initState`** — druga strana odgovara na
svom uređaju, a ovom niko ništa ne javlja.

Sad se osvežava pri ulasku u tab Prijatelji i na povlačenje nadole
(`RefreshIndicator`, uz `AlwaysScrollableScrollPhysics` — bez toga geste nema
kad je lista kratka, a to je baš slučaj kad ekran izgleda zastarelo).

Nije rađeno preko socket-a namerno: sokete ovde drže sobe časa, a ne korisnici,
pa bi to tražilo registar korisnik→socket. Ovo rešava isti problem i kad je
aplikacija bila u pozadini.

Uz istu probu nađeno i drugo: notifikacija koja nosi zahtev ostajala je
**nepročitana zauvek**. Kartica nestane sama (crta se iz `trainer_students`),
ali notifikacija je zaseban red, pa je zvonce trajno pokazivalo broj za nešto
već rešeno — a posle odbijanja `ref_id` pokazuje na red koji više ne postoji.
Sad je `respondToRequest` zatvara, u oba ishoda, i to „best effort": odgovoren
zahtev se ne poništava zato što notifikacija nije pospremljena.

## Smer odnosa se sada bira, ne pogađa — ✅ 17.8.2026

Model je od početka imao oba smera (`initiatorIsTrainer` u
`relationshipService.js`, dve rute), ali je aplikacija umela da pošalje **samo
jedan**: ko prvi unese tuđu adresu, taj postaje trener. Ništa nije pucalo —
odnos je prosto bio naopak, a jedini izlaz je bio da pogrešan trener obriše vezu
i zamoli drugoga da je napravi.

Sada se iznad polja za email bira **„Ja sam trener" / „Ja sam učenik"**, natpis
polja prati izbor (`Email učenika` / `Email trenera`), a ispod stoji rečenica ko
koga uči. Dugme više ne piše „Dodaj prijatelja" nego „Pošalji zahtev", jer to i
radi — veza nastaje tek kad druga strana potvrdi.

Ruta i naziv polja žive na jednom mestu
([relationship_request_target.dart](../chess_app/lib/models/relationship_request_target.dart));
dve rute se razlikuju i po ključu (`studentEmail` vs `trainerEmail`), a
zamena ključa pada uz poruku „email je obavezan", koja o ulogama ne kaže ništa.

Usput nađeno testom: zaglavlje kartice u tabu Prijatelji **prelivalo se preko
desne ivice na 360 px**. Tab dotad nikad nije bio renderovan na širini telefona.

## Pristanak je propuštao lekcije — ✅ popravljeno 17.8.2026

Nađeno tokom same probe pristanka uživo (stavka 0 u `TODO-provera.md`), nad
pravim podacima: dok je veza stajala kao `pending`, pozvani korisnik je već
video **sve lekcije** onoga ko ga je pozvao.

Uzrok: `trainerOwnsStudent` traži `status='accepted'` i čuva zadatke i izveštaje,
ali tri upita nisu išla kroz njega nego su podupit pisala rukom — i sva tri su
izostavila status. Dva u `routes/lessons.js` (lista lekcija i lista oznaka) i
jedan u `routes/reviews.js` (pristup lekciji pri ocenjivanju).

Gori je bio drugi smer: `POST /students/trainers/request` prima bilo koju adresu
i jednostrano pravi red `trainer_id=druga strana, student_id=ja`. Znači svako je
mogao da napravi zahtev koji niko ne odobri i time čita tuđe deljene lekcije.

Popravka nije bila „dodaj uslov na tri mesta" nego **`acceptedTrainersOf` u
`relationshipService.js`**, jedan izvor tog podupita, koji uz to pukne ako mu se
prosledi vrednost umesto oznake parametra. Uz to test koji čita izvorni kod i
pada ako se bilo gde pojavi četvrta ručno pisana kopija — jer je ovo greška koja
se u ponašanju **ne vidi**: svi ekrani rade, samo pristanak ne znači ništa.

Provereno i nad bazom, ne samo testom: isti upit koji je pre popravke vraćao tri
lekcije, posle nje vraća nula, sa vezom koja je i dalje `pending`.

## Prijava je ćutala o nalogu bez lozinke — ✅ popravljeno 17.8.2026

Nalozi napravljeni kroz Google prijavu nemaju lozinku — kolona je `NOT NULL`, pa
`/auth/google` upiše oznaku umesto hesa. `bcrypt.compare` protiv te oznake vraća
`false` bez greške, pa je takav nalog na **svaku** lozinku odgovarao „Invalid
email or password". Tačan odgovor koji šalje čoveka da traži grešku u kucanju
koje nema, i nalog je nedostupan sa Windows-a (gde `google_sign_in` ne postoji) i
sa Androida (dok se ne registruje nov OAuth klijent, korak 2 u
`TODO-objavljivanje.md`).

Sad `/login` prepozna oznaku i kaže da nalog koristi Google prijavu, uz
`usesGoogle: true` u odgovoru. Klijent to prikazuje bez izmene, jer već ispisuje
`data['error']`.

Svesno prihvaćeno: ta poruka **potvrđuje da nalog postoji**, što generički
odgovor iznad namerno ne radi. Ista se stvar ionako saznaje sa
`/students/trainers/request`, ruta ima ograničenje od 20 pokušaja na 15 minuta, a
alternativa je nalog do kog se ne može doći.

## Snimci više ne nose adresu servera u sebi — ✅ 16.8.2026

Nađeno pri pripremi prebacivanja, i zaustavilo bi ga na sam dan.

`recordings.js` je upisivao **apsolutnu adresu** u bazu:
`${req.protocol}://${req.get('host')}/uploads/...`. Posledice su bile dve, i
druga je bila gora od prve:

- svih **16 postojećih snimaka** nosi `http://192.168.0.19:3000/...`, dakle kućnu
  mrežu — prekopiranje fajlova to ne bi rešilo;
- `trust proxy` nije bio podešen, pa bi iza nginx-a `req.protocol` vratio `http`,
  i svaki **nov** snimak dobio bi `http://api.chesstrainers.app/...` — nešifrovanu
  adresu na domenu koji je na HSTS listi.

Sad se čuva **putanja** (`/uploads/ime.aac`), a klijent je spaja sa svojim
`backendUrl`-om (`resolveMediaUrl` u `constants.dart`). Promena servera, domena
ili prelazak na HTTPS od sada ne košta ništa.

Stari redovi se **namerno ne prepisuju**: `resolveMediaUrl` propušta apsolutne
adrese nedirnute, pa oni rade dok je backend ta ista mašina, a nestaće zajedno sa
snimcima koje korisnik ionako planira da obriše pri prebacivanju. Fajlovi se iz
istog razloga ne prenose na server.

Uz to je podešen **`app.set('trust proxy', 1)`** — bez toga bi iza nginx-a svi
zahtevi izgledali kao da dolaze sa `127.0.0.1`, pa bi ograničenje broja pokušaja
prijave brojalo **sve korisnike kao jednog** i zaključavalo svakoga odjednom.
Vrednost je `1`, a ne `true`: poverenje celom lancu dozvolilo bi klijentu da sam
postavi `X-Forwarded-For` i bira u koju korpu pada.

`_startAudioFrom` u `replay_player_screen.dart` sad razlikuje **tri** oblika:
apsolutnu adresu iz starog reda, fajl koji još stoji na uređaju pre
sinhronizacije, i putanju. Srednji slučaj je lako previdеti — zbog njega se
snimak koji nije stigao na server pušta sa diska.

## Skener pozicija iz knjiga — izmereno 19.8.2026, proba na Node-u radi

Ideja: trener unosi **svoj** materijal — knjigu, papir sa časa — a ne bira iz
tuđe baze. Količina nije problem, 50.000 Lichess zagonetki već stoji u bazi.

Postoji radni prototip u Pythonu van repozitorijuma (`pdf_u_fen_skener.py` i
prateće skripte). Ovaj odeljak je merenje na dve stvarno različite knjige, jer od
te razlike zavisi šta uopšte treba graditi.

### Dva puta u prototipu, i samo jedan valja

**Put A — vektorski font.** Šahovski dijagrami u knjigama složenim u LaTeX-u ili
Word-u nisu slike nego **tekst** u posebnom fontu: osam redova po osam znakova.
Čita se iz tekstualnog sloja, bez prepoznavanja slike. Zato je i tačan.

**Put B — OpenCV + `board_to_fen` (TensorFlow).** Ne prenosi se. Na droplet-u sa
1 vCPU / 2 GB TensorFlow ne dolazi u obzir, a i sam kod ima tačno onu grešku koju
ovde lovimo: ako uvoz modela pukne, `get_fen_from_image` se zameni funkcijom koja
vraća praznu tablu. Bez instaliranog TensorFlow-a skener **tiho vraća praznu
tablu kao validan rezultat**, upiše je i javi „skeniranje završeno". Peti primer
u nizu iz `CLAUDE.md`.

### Ko je na potezu — četiri izvora, poređana

Merano na knjizi sa 5.234 izvučene pozicije:

1. **Rešenje.** `1255  1...Rd1+ 2.NXd1` — tri tačke znače da je crni na potezu.
   Pravilo nije „red sadrži tri tačke" nego „**prvi potez** u redu je `1...`";
   red `307  1.Kc3 [threatening Qa7m] 1...Ka2` takođe sadrži `1...`, a beli je na
   potezu. Od te razlike zavisi da li je pravilo tačno ili grubo pogrešno.
2. **Oznaka uz dijagram** — natpis ili glif pored table.
3. **Zaglavlje sekcije**, preneseno unapred na strane koje ga nemaju.
4. **Motor** kao arbitar kad prva tri ćute.

Poklapanje izvora 1 i 2 na toj knjizi: **5.009 slaganja, nula neslaganja među
pravim zagonetkama.** Svih 173 neslaganja leže iznad dijagrama 4463, gde
„rešenje" nije rešenje nego partija od prvog poteza. Pravilo je samo pronašlo
granicu odeljka — to je traženo ponašanje: kad se dva izvora raziđu, to se vidi,
a ne pogađa se.

### Rešenje je test svake izvučene pozicije

Ovo je važnije od strane na potezu. Ako knjiga kaže `1.Qg7m`, a taj potez nije ni
legalan u izvučenom FEN-u, tabla je pogrešno pročitana. Na 4.337 zagonetki:

| | |
|---|---|
| potez iz knjige legalan u izvučenom FEN-u | **99,61%** |
| i identičan onome što nađe motor | **98,20%** |
| nelegalan | 17 |

Od tih 17: **14 rokada, 2 en passant, i samo jedna stvarno pogrešno pročitana
tabla.** Uzrok nije čitanje figura nego to što skener zakucava metapodatke FEN-a
na `- -`: prava na rokadu i polje za en passant se bacaju. Mat u jedan potez
rokadom se uvozi kao **nerešiva zagonetka** — figure tačne, potez zabranjen, dete
odigra tačno rešenje i dobije „pogrešno". Stvarna tačnost čitanja table je dakle
**1 promašaj na 4.337**, a ne 17.

Odluka koja iz toga sledi: **prava na rokadu se iz dijagrama ne mogu pročitati**,
knjiga ih ne štampa. Ako je rešenje rokada, postaviti prava koja je čine
legalnom; inače pretpostaviti da ih nema **i označiti poziciju**. Ne pogađati
ćutke — isti oblik greške kao `sed s/^KEY=.*/` koji ne uradi ništa.

### Druga knjiga: šta se prenosi, a šta ne

Provereno na `TacticsCourse.pdf` (Exeter Chess Club, Dave Regis, besplatno
objavljeno — 84 strane, 211 dijagrama). Word → PostScript → Ghostscript, ne
LaTeX.

**Prenosi se tehnika, ne tabela.** Dijagram je i dalje tekst u posebnom fontu,
ali je azbuka sasvim druga: `w`/`D` prazna polja, `p`/`0`/`P`/`)` pešaci, ivice
`cuuuuuuuuC` i `v,./9EFJMV`. Font je podskup sa zamagljenim imenom
(`TTE2BEAF20t00`), bez `/CharSet` i bez `ToUnicode` — dakle **mapa znak→figura
mora da se napiše po knjizi**. Nije veliki posao (48 znakova, od čega je pola
ivica), ali se ne izvodi automatski.

**Postojeći parser na njoj nalazi 0 od 211 dijagrama**, jer traži trocifren broj
dijagrama kojeg u ovoj knjizi nema. U punom toku to znači propadanje na Put B i
211 izmišljenih praznih tabli prijavljenih kao uspeh.

**„White to move" gotovo i ne postoji:** tri natpisa na celu knjigu. Sufiks-glif
uz ivicu (`}a` / `}e`) stoji na 31 od 211 dijagrama. Oba izvora otpadaju, ostaju
rešenja i motor. I još jedno upozorenje: natpisi se u tekstualnom toku pojavljuju
**na kraju strane**, ne uz svoj dijagram — spajaju se po koordinatama, nikako po
redosledu čitanja.

**Dijagrami nose oznake polja koje nisu figure** (`X` za napadnuto polje). Mapa
ih mora slati u „prazno", inače postaju figure kojih nema.

### Iz ovoga sledi da skener ima dva izlaza, ne jedan

Najvažniji nalaz. Dve knjige su dve različite vrste dokumenta:

- **Katalog** (prva knjiga): numerisani dijagrami, ujednačeni, rešenja
  indeksirana po broju. Izlaz su **zagonetke** — `kind = 'puzzles'`.
- **Kurs** (`TacticsCourse.pdf`): proza sa ilustracijama, 211 dijagrama ali samo
  **12 rešenja** na kraju, za završni test. Ostalih 199 nisu zagonetke nego
  primeri uz tekst. Izlaz je **lekcija** — `saved_lessons` sa koracima,
  `kind = 'lesson'`, i `review_items` preko toga.

Vući 211 „zagonetki" iz kursa bilo bi tačno po formi i besmisleno po sadržaju.
Vrstu dokumenta treba prepoznati (ima li numerisanih dijagrama, ima li rešenja
indeksiranih po broju, koliki je odnos proze i dijagrama) i **pitati trenera**,
jer je pogrešan izbor ovde tih.

Uzgred, rešenja ove knjige nose i temu rečima — `1...a5! undermining`,
`1.Re7+! interference/skewer` — što se preslikava na `assignments.themes`. Prva
knjiga isto to daje kroz zaglavlje (`2.1 White to Move #2` → `mateIn2`). Bez toga
trener ne može da zada „dvadeset matova u dva", jer skenirane pozicije nemaju
nijedan tag.

### Druga knjiga je pročitana — 20.8.2026, mapa gotova

`TacticsCourse.pdf` prolazi kroz skener: **210 dijagrama** umesto dosadašnjih 0.
Mapa je u `fonts.mjs` kao `TACTICS_COURSE`.

Posao je bio predat spoljnom agentu, sa merilom unapred (vidi dva `TASK-` fajla u
istoriji, obrisana po spajanju). Vratio ga je dvaput; oba puta je jezgro mape
bilo tačno, i oba puta je unutra bila tiha greška. Vredi zapisati **kako su
nađene**, jer je to jedini prenosiv deo:

**Prvi krug:** `Z` i `*` mapirani u kraljeve. Nađeno tako što `chess.js` odbija
tablu sa dva kralja — četiri dijagrama su pukla naglas. Uz to su bila i tri
zahvata van dogovorenog: `COLUMN_GAP` u `solutions.mjs` (izmereno: donosi jedno
rešenje više na 13, a upravlja i prvom knjigom sa 4.437 rešenja i 99,98%),
netranzitivan `sort`, i test kome je tvrdnja zamenjena besmislicom.

**Drugi krug:** popravio je sve traženo, i `Z`/`*` kao prazna polja su ispravna —
svaki glif ovog fonta drži se jedne boje polja, a `Z`, `*` i već poznati `X` uz
to nemaju para, što je potpis oznake a ne figure.

Ali `1` i `!` su bili **zamenjeni**: `1` je crna dama na tamnom polju, `!` bela.
Pročitano obrnuto, u **22 od 210 dijagrama** bela dama stoji na d8 — a to su
zamke u otvaranju, gde je figura duboko u crnom taboru crna dama. **Svaki takav
FEN je ostao legalan i svaka postojeća provera je prošla.** Brojevi su presudili:
ovako uparene, obe dame daju po 182; obrnuto su davale 290 prema 74, dok je svaka
druga figura bila uravnotežena.

**Nađeno je prebrojavanjem materijala, a to nije bilo ni u jednom merilu** — ni u
zadatku koji smo mu dali. Zato je sada stalna provera:

- `materialProblem` u `verify.mjs` odbija ono što nikad nije moglo stajati na
  tabli. `chess.js` proverava da li je pozicija *učitljiva* i tu staje — prima
  devet pešaka i prima dve bele dame dok crni nema nijednu. Oba su tačno ono kako
  izgleda pogrešno pročitan glif.
- `flagDuplicateNumbers` u `index.mjs`: knjiga numeriše i završni test i primere u
  tekstu, pa broj 6 stoji nad dva dijagrama i oba su dobijala isto rešenje. Onaj
  kom nije pripadalo prijavljivao je knjigin sopstveni potez kao nelegalan — što
  je ličilo na pokvarenu mapu. Sad se ne pogađa nijedan, oba idu čoveku.
  Izvezeno je zato što `scan.mjs` ima **svoju kopiju** te petlje; zaštita koju
  primenjuje samo jedna od dve staze gora je od nikakve.

**Stanje na kraju:** 210 dijagrama, 0 nemogućih pozicija, od 11 rešenja koja se
mogu vezati **10 legalnih** — a jedini neuspeh je `#2`, protivrečnost koju knjiga
sama štampa. Knjiga je kurs, ne katalog, pa njen izlaz treba da bude lekcija;
vidi odeljak „Iz ovoga sledi da skener ima dva izlaza".

**Ostaje neizmereno:** obe nove provere diraju stazu kojom prolazi i prva knjiga,
a nje nema u repozitorijumu, pa se 99,98% odavde ne može ponovo izmeriti. Kad se
prva knjiga sledeći put pusti, taj broj treba pogledati — naročito
`flagDuplicateNumbers`, jer ako i ona negde ponavlja broj, deo dosadašnjih
„legalnih" rešenja bio je vezan pogrešno.

### Knjiga kao interaktivna lekcija — procenjeno 20.8.2026, nije započeto

Ideja korisnika: skener već daje FEN sa dijagrama; da li može uz to da pokupi i
**prozu oko dijagrama**, prepozna poteze u njoj, i sve zajedno sklopi u lekciju —
tabla levo, tekst iz knjige desno, potezi u tekstu klikabilni i vezani za
navigaciju ispod table. Time se rešava ono zbog čega svako ko uči iz knjige drži
tablu pored sebe: ručno postavljanje figura i vraćanje poteza kroz varijante.

**Procena: izvodljivo, i bliže nego što deluje.** Više od pola stoji napravljeno:

| Korak | Stanje |
|---|---|
| dijagram → FEN | radi, 99,98% na prvoj knjizi |
| izvlačenje teksta | `pageSpans` već vraća sav tekst **sa koordinatama** |
| poteze iz teksta u SAN | `normalizeSan` guta `QXg7m`, `eXd8Q`, `0-0-0`, `!?` |
| stablo sa varijantama | `AnalysisNode` |
| lekcija sa koracima | `saved_lessons.position_list` |
| tabla + navigacija | jedna traka nad tri modela, od 20.8.2026 |

Uz to, u odeljku „Iz ovoga sledi da skener ima dva izlaza" **već je zaključeno**
da knjiga tipa kurs treba da daje lekciju a ne zagonetke. Ovo je nastavak te
odluke, ne nova grana.

**Šta je stvarno teško — a nije ono što se prvo pomisli.** Nije prepoznavanje
poteza ni prikaz; to je najlakši deo. Teško je dvoje:

1. **Koji tekst pripada kom dijagramu.** Već je zabeleženo da se natpisi u
   tekstualnom toku pojavljuju na kraju strane, a ne uz svoj dijagram — spajanje
   ide **po koordinatama, nikako po redosledu čitanja**.
2. **Odakle linija kreće.** Knjiga piše `1.Sf3 d5`, ali od pozicije sa dijagrama
   ili od početka partije? Isti raskorak koji je 20.8.2026 dao „`Re7+` nije
   legalan" — potez je bio tačan, dijagram pogrešan.

**Zašto je ipak izvodljivo:** `verify.mjs` odigra potez iz teksta u FEN-u sa
dijagrama i kaže da li prolazi. To je provera istine, a ne pogađanje — bez nje
bi ovo bio generator uverljivih gluposti. Sa njom se svaka lekcija može izmeriti
pre nego što je dete vidi.

**Najmanji korak koji nešto dokazuje**, na knjizi koja se već skenira: jedno
poglavlje `TacticsCourse.pdf`, proza vezana za dijagrame po koordinatama, potezi
iz nje provereni kroz `verify.mjs`, izlaz jedan red u `saved_lessons`. Mere se
dve stvari — koliko dijagrama je dobilo tačan tekst, i koji procenat poteza je
legalan iz svog dijagrama. Ako je drugi broj visok, ostatak je UI: klikabilan
`TextSpan` iznad table, uz postojeći `MoveCursor` posao od pola dana.

**Prevod — dve različite stvari, ne jedna.**

- **Mapiranje slova figura** (`Кf3` → `Nf3`, ruski/nemački/engleski zapis) je
  trivijalno i sigurno: tabela po jeziku, a `chess.js` odbije svaki pogrešno
  mapiran potez. Uklapa se pravo u `normalizeSan`.
- **Prevod didaktičke proze modelom** je tehnički lak i pravno nije. Skeniranje
  kupljene knjige za sebe je jedno; **pravljenje prevoda i deljenje učenicima
  kroz aplikaciju je distribucija izvedenog dela**. To je veća izloženost od
  imena aplikacije, i to za funkciju koja bi bila reklamna. Pitanje za istog
  pravnika koji piše tekst o pristanku roditelja, pre nego što se u to uloži red
  koda.

**Redosled:** ne dizati dok se ne završi ekran za potvrdu skeniranih pozicija i
objavljivanje. Ovo je nova i velika grana, a sve ostalo na spisku je na dva-tri
koraka od gotovog. Ali je vredi držati — prirodan je nastavak već izgrađenog, i
jedina stvar u projektu koju konkurencija nema.

### Ekran za potvrdu i put do baze — napisano 19.8.2026, nije viđeno uživo

Skener je iz `puzzles/` prešao u aplikaciju:
`chess_backend/services/positionScanner/` (biblioteka + tri CLI alata),
`routes/scans.js`, tabela `custom_puzzles`, i ekran
`features/position_scanner` sa ulazom iz Biblioteke.

Tri odluke koje su ugrađene, a ne dopisane:

- **Dokument se ne čuva.** Upiše se u `os.tmpdir()` samo zato što čitač traži
  putanju, skenira se u toku zahteva i briše u `finally`. Server koji ne čuva
  ništa ne može ništa ni da propusti — a `uploads/` ostaje jedino mesto sa
  dečjim glasovima i tamo ovo nikad ne ulazi.
- **Skenira se opseg strana, ne knjiga.** Najviše 40 po prolazu. Nije zbog
  brzine — 40 strana je 0,3 s — nego zato što jedan zahtev ne sme da drži
  jedini vCPU nad knjigom od 1.184 strane, i zato što 200 dijagrama odjednom
  već jeste gornja granica onoga što čovek može da pregleda.
- **Klijent nije autoritet za poziciju.** `services/scanIntake.js` iznova
  proverava svaki FEN kroz `chess.js`; strana na potezu se čita iz FEN-a, a ne
  iz onoga što je aplikacija poslala. Potez koji se ne odigra ne upisuje se kao
  rešenje, ali se pozicija čuva i obeleži — tabla ume da valja i kad je potez
  pored nje pogrešno pročitan.

Merenje: 40 strana + 9 sa rešenjima za **0,3 s** u biblioteci, **1,3 s** kroz
HTTP sa pravim PDF-om od 5,4 MB. Backend 152 testa, aplikacija 220,
`flutter analyze` čist.

**Backend je pozvan uživo 19.8.2026** — ceo lanac preko HTTP-a, 120 pozicija sa
strana 32–51, čuvanje sa jednom namerno pokvarenom pozicijom koju je server
odbio uz razlog, čitanje nazad, pa brisanje probnih redova. Ekran u aplikaciji
još niko nije otvorio: `TODO-provera.md`, stavka 12.

Ta proba je odmah otkrila i rupu u obećanju „dokument se ne čuva": `finally` se
**ne izvrši ako proces bude ubijen usred zahteva**, a nodemon koji se restartuje
na snimanje fajla je dovoljan da se to desi. Kopija knjige od 5,4 MB ostala je u
privremenom direktorijumu. Sad se pri pokretanju servera brišu svi zaostali
`scan_*` fajlovi, uz upozorenje u dnevniku. Isti oblik greške kao i ostali u
ovom projektu — korak koji tiho ne odradi svoje, i vidi se tek kad neko pogleda.

### Nepoznato ne sme da postane tvrdnja jedan sloj kasnije — 19.8.2026

Najvažniji nalaz iz prve prave upotrebe, i nije ga našao test nego korisnik.

Kad knjiga ne kaže ko je na potezu, pozicija se čuva sa belim i obeleži se
`needs_review`. **Ali FEN nema način da kaže „ne zna se".** Čim pozicija napusti
ekran skenera, pogađanje se više ne razlikuje od činjenice: tabla za analizu je
učita, motor odradi svoje za belog, i strelica samouvereno prikaže mat u jedan —
odgovor na pitanje koje niko nije postavio.

To je peti primer istog oblika greške u ovom projektu, samo obrnut: umesto da
korak tiho ne uradi ništa, sumnja se tiho pretvorila u tvrdnju.

Rešenje nije u FEN-u — tamo mora da stoji nečiji potez. Rešenje je da se **ne
otvori ćutke**: dodir na nepotvrđenu poziciju pita „ko je na potezu", odgovor se
upiše (`PATCH /scans/puzzles/:id`), zastavica se skida, i tek onda se otvara
tabla. Jedna odluka, doneta jednom, u trenutku kad je bitna.

Prepisivanje strane radi server, ne klijent: polje za en passant pripada
**protivnikovom** poslednjem potezu i mora da otpadne kad se promeni ko igra,
a rezultat se proverava kroz `chess.js` pre upisa. Ako izabrana strana čini
poziciju nemogućom, vraća se 422 sa objašnjenjem umesto tihog upisa.

Uz to, žuti okvir u „Mojim pozicijama" sad piše šta znači — „strana na potezu
nije potvrđena" — jer boja bez teksta ne govori ništa.

### Izveštaj je istu temu zvao i jakom i slabom — 19.8.2026

Viđeno na prvom pravom izveštaju za roditelja: **„dvojni napad 70%" i „izložen
kralj 25%" stoje i pod „šta ide dobro" i pod „na čemu radimo dalje"**, samo
obrnutim redom.

Uzrok:

```js
measured.sort((a, b) => a.accuracy - b.accuracy);
weakestThemes:   measured.slice(0, 5),
strongestThemes: [...measured].reverse().slice(0, 5),
```

Prvih pet i poslednjih pet iz iste liste — kad je izmerenih tema **manje od
šest**, obe liste sadrže sve. A trener na početku i ima dve-tri teme, pa je to
bio uobičajen slučaj, ne rub.

Sada tema mora da **zasluži** mesto i može biti samo u jednoj: `>= 70%` je jaka
strana, `< 50%` je ono na čemu se radi, a između nije nijedno. Srednji pojas je
namerno izostavljen iz oba — „tačno otprilike dve trećine" nije vest ni u jednom
smeru, a tema se i dalje vidi u punom spisku po temama.

Prag je izdvojen u `STRONG_THEME_ACCURACY` / `WEAK_THEME_ACCURACY`, sa razmakom
između njih, jer je baš spajanje ta dva praga i napravilo besmislicu.

### Ceo lanac je prošao uživo — 19.8.2026

Knjiga → skener → potvrda → zadatak → dete → ocena → napredak. Potvrđeno na
zadatku „Mat u 333": **2/2 urađeno, tačnost 100%**, napredak prešao sa 0/4 na
1/4 završenih zadataka.

### Skenirane pozicije se zadaju učeniku — backend 19.8.2026

`POST /assignments/custom` uzima **izričitu listu** pozicija koje je trener
izabrao sa svog ekrana, za razliku od `POST /assignments` koje traži „dvadeset
zagonetki o vezivanju". Zato su dve rute a ne jedna sa granama.

Dve vrste pozicije se **odbijaju, ne preskaču ćutke**: ona bez rešenja (odgovor
ne može da se oceni, pa bi dete dobilo „netačno" šta god odigra) i ona označena
za proveru (sumnja koju već držimo — domaći pred detetom je poslednje mesto da
se to otkrije). Razlozi putuju uz grešku, po poziciji.

**Rešenje se ne šalje učeniku unapred.** Detalj zadatka nosi tablu, zadatak i
temu, ali ne i potez; server sudi (`POST /assignments/:id/custom-attempt`) i
rešenje otkriva tek pošto je odgovoreno. Poslati rešenje klijentu da sam sebe
oceni znači dati učeniku baš ono što se od njega traži.

### Drugi mat je i dalje mat — 19.8.2026

Ocena ne poredi tekst nego prati zadatak: **kad sačuvano rešenje matira, prihvata
se svaki potez koji matira.** Inače važi samo autorov, jer ništa ovde ne zna šta
je pozicija još trebalo da nauči.

Nije teorijski slučaj. U trenerovih 198 pozicija **četiri** imaju više od jednog
mata u jedan:

| dijagram | knjiga | takođe matira |
|---|---|---|
| #122 | `Qe6#` | `Qh7#` |
| #154 | `Qg7#` | `Qa7#` |
| #220 | `exd8=Q#` | `exd8=R#` |

Dakle oko **2% domaćeg** reklo bi detetu „netačno" za ispravan mat. Dete koje
nađe drugi mat je rešilo zadatak, a poruka da nije uči ga da ne veruje
aplikaciji — i bilo bi u pravu.

### „Dobrodošli, Vladan" ne znači da postoji server — 19.8.2026

Primećeno na telefonu: aplikacija pozdravlja imenom iako backend uopšte nije bio
pokrenut. Pozdrav dokazuje samo da **uređaj pamti prijavu** — `SessionService`
je vraća iz `SharedPreferences` i nikad je ne proverava, ni da li token važi ni
da li server postoji. Oba slučaja izgledaju identično kao ispravna prijava, pa
se otkriju tek kad nešto ne uspe da se sačuva.

Dodat je `GET /session/check`: bez ijednog upita u bazu, odgovara samo na to da
li server postoji i da li token još nešto znači. Dovoljno jeftino da se zove pri
svakom pokretanju.

`ServerStatusService` razlikuje četiri stanja, i **`unknown` nije uveravanje** —
dok se ne dobije odgovor, ekran ćuti umesto da tvrdi da je sve u redu. Kad
odgovor stigne, ispod pozdrava piše šta je stvarno:

- *nema veze sa serverom* — prijava je zapamćena, ali ništa se ne čuva
- *prijava je istekla* — server odgovara i odbija token (traje 7 dana, pa je ovo
  pitanje vremena, ne izuzetak)

Namerno se **ne odjavljuje**: sesija na uređaju može biti sasvim ispravna, samo
trenutno ne može ništa da uradi. To su dve različite stvari i spajanje im je i
bila greška.

### Tabla bez zadatka nije vežba — 19.8.2026

Korisnikovo zapažanje, i starije od skenera: trener sačuva poziciju, uključi je u
lekciju, zada je za domaći — a **nigde ne piše šta učenik treba da uradi.**
Dete dobije figure i ništa.

Rupa je bila na tri mesta odjednom:

| gde | šta je nosilo | šta je falilo |
|---|---|---|
| `LessonStep` | `title`, `fen`, `pgn` | naslov je ime, ne zadatak |
| `assignments.instructions` | tekst za ceo domaći | ne po poziciji |
| `custom_puzzles` | teme, rešenje | nijedna reč učeniku |

Podela koja je uvedena: `assignments.instructions` ostaje trenerov okvir za ceo
domaći („uradi do petka, bez motora"), a nova kolona `custom_puzzles.instruction`
nosi **šta se traži u ovoj poziciji**. To je svojstvo pozicije, ne zadavanja —
ista pozicija ima isti zadatak kome god da je data.

Uputstvo se **izvodi samo kad pozicija sama može da ga kaže**: rešenje koje je
provereno da matira odmah *jeste* „mat u jedan", i reći to je izveštavanje a ne
nagađanje. Sve ostalo vraća prazno. Jedan sačuvan potez ne otkriva da li se
tražio dobitak materijala, remi ili jedina odbrana, a izmisliti zadatak je gore
nego ostaviti polje čoveku.

Trenerove reči se **nikad ne prepisuju** — ni pri ponovnom skeniranju, ni pri
rešavanju strane na potezu. Izvedeno popunjava samo prazno polje.

Postojećih 198 pozicija je popunjeno odmah: svih 198 nosi „Beli matira u jednom
potezu", što je tačno jer je za svih 198 provereno da rešenje matira.

**Lekcije su dobile isto** — 19.8.2026. `LessonStep` sad nosi `instruction`, uz
`title`. Ide u `position_list` JSON, pa nema migracije: korak zapisan ranije
jednostavno nema polje, a ekran tada **ne piše ništa** umesto da izmisli zadatak.

Naslov se namerno **ne koristi kao zamena**. „Završnica sa skakačem" je ime, ne
pitanje — stavljeno na mesto zadatka izgledalo bi kao uputstvo, a učeniku ne bi
reklo ništa. To čuva test.

Trener zadatak upisuje u editoru lekcije (`create_course_dialog`), po koraku;
korak bez zadatka stoji narandžasto sa „učenik neće znati šta se traži". Učenik
ga vidi u `lesson_viewer_screen`, uokvireno, iznad napomene za ceo domaći.

### Knjiga je jača od motora, i to se izmerilo — 19.8.2026

Prvo skeniranje strana 45–64 išlo je **bez rešenja**, pa je 78 pozicija ostalo
bez poteza i sa nepoznatom stranom. Motor je predložio stranu za 62, trener je
ručno postavio 10, ostalo 6 kod kojih **obe strane matiraju** — tu motor nema
odgovor i pravilno je odustao.

Onda je isti opseg ponovo skeniran, ovaj put sa rešenjima (strane 975–977):
**dopunjeno 69, već postojalo 42, neslaganja 9.**

Tih devet je nalaz. Svih devet su pozicije upisane kao „crni na potezu", a
knjiga za svih devet kaže **beli** — i njen potez igra čim se strana vrati.
Provera „rešenje mora da igra u već sačuvanoj poziciji" uhvatila je tačno ono
zbog čega je i napisana.

Iz toga dve izmene:

- **Neslaganje sad obeležava poziciju** (`needs_review = TRUE`). Ranije je broj
  stajao samo u odgovoru koji nestane sa porukom, a pozicija je izgledala
  „nedovršeno" umesto „sporno" — pa se do nje više nije moglo vratiti.
- **Neslaganje kaže verovatan uzrok.** Ako potez proigra sa suprotnom stranom,
  poruka to i kaže umesto golog „ne igra". Na ovih devet to je bio uzrok u sto
  posto slučajeva.

Redosled koji iz svega ovoga sledi, i vredi ga pamtiti: **ako knjiga ima
rešenja, skenirati sa njima odmah.** Motor je zamena kad ih nema, a ne prečica —
rešenje iz knjige razrešava i stranu na potezu, besplatno i tačno.

### Motor predlaže, trener odlučuje — 19.8.2026

Za pozicije kojima knjiga nije rekla ko je na potezu, motor može da odgovori: u
zbirci zadataka **strana na potezu je ona koja ima šta da odigra**, jer to
zadatak i jeste. Provera je zato dvostruka — ista tabla se analizira jednom sa
belim, jednom sa crnim — pa se poredi koliko potez vredi svakoj strani.

Pouzdanost se ne pretvara u sigurnost:

| | |
|---|---|
| jedna strana matira, druga ne | **visoka** — oblik svakog zadatka u poglavlju „mat u N" |
| razlika ≥ 3.0 bez mata | **srednja** — ali knjiga ume da traži i odbranu |
| obe strane imaju slično, ili nijedna | **nema predloga** |

Ako je pozicija legalna samo za jednu stranu, to je odgovor bez ijedne pretrage.

Šta je namerno ovako:

- **Predlog se ne upisuje sam.** Stoji pored pozicije dok ga trener ne prihvati.
  Iste je vrste greška kao ona od jutros — mašina koja odgovara na pitanje koje
  niko nije postavio, samo sa više samopouzdanja.
- **Dubina se bira** (12/16/20/24) i provera se ponavlja koliko god puta treba,
  jer je to trampa koju trener oseti: plitko je brzo i ponekad pogrešno.
- **Mogu i već odlučene pozicije.** Tada motor može da se **ne složi** sa
  upisanom stranom — i to neslaganje je jedini način da se uhvati strana koja je
  ranije pogrešno postavljena. Prikazuje se crvenim i **nikad ne ulazi u
  „prihvati sve pouzdane"**; grupno prevrtanje tuđe odluke je tačno ono što ovaj
  tok sprečava.
- **Traži lokalni motor.** Mrežni ne poznaje pozicije iz knjiga (vidi odeljak
  niže), pa bi grupna provera mlela dva minuta i vratila ništa. Provera se
  odbija unapred sa objašnjenjem umesto da se to desi.

Analiza ide **redom, jedna po jedna** — motor je deljeni singlton koji koristi i
tabla za analizu, a `analyzePositionSync` je i napisan da odgovor jednog upita ne
završi kod drugog. Paralelno pokretanje bi to vratilo.

Tabla se otvara iz ugla strane na potezu — to je već radilo
(`_initAnalysisTree` uzima orijentaciju iz FEN-a), i `initialFen` namerno gazi
sačuvan nacrt.

### Nedovršeno i sporno nisu isto — 19.8.2026

Primećeno pri korišćenju: kad se odgovori ko je na potezu, žuti okvir nestane —
a pozicija je i dalje bez rešenja. Izgleda gotovo, a nije.

Uzrok je što je `needs_review` nosio dva različita značenja. Sumnja („rešenje iz
knjige ne igra", „strana na potezu se ne zna") jeste razlog za upozorenje.
Odsustvo rešenja **nije sumnja** — pozicija je ispravna, samo nepotpuna, i ništa
se ni sa čim ne sukobljava.

Sada su tri stanja: žuti okvir za sumnju, blaži za nedovršeno, običan za gotovo.
Zaglavlje broji oba („N traži pogled", „M bez rešenja").

Uz to je zatvorena rupa koju je isto zapažanje otkrilo: `PATCH` je skidao
zastavicu **ne proverivši** da li sačuvano rešenje i dalje igra posle promene
strane. Ako ne igra, zastavica ostaje — jer promena strane može da učini
sačuvani potez nemogućim, a tiho čišćenje bi sakrilo poziciju čiji se potez i
tabla više ne slažu.

### Na Windows-u skener traži sopstveni motor — 19.8.2026

Zamka koju je lako ne videti, jer izgleda kao greška u skeneru a nije.

```dart
bool get _useOnline {
  if (Platform.isWindows && _isCustomActive) return false;
  return Platform.isWindows || Platform.isLinux;
}
```

Na Windows-u aplikacija **ne pokreće ugrađeni Stockfish** nego mrežni. A mrežne
baze znaju samo pozicije iz odigranih partija — dok su pozicije iz knjige tačno
one kojih tamo nema. Svako skenirano pitanje promaši, `catch (_) {}` to proguta,
i odgovori brojanje materijala.

Simptom je bio ubedljiv: „Eval +1.00 (depth: 18)", prazna linija, bez najboljeg
poteza. Ni jedno od toga nije bilo tačno — ni ocena, ni dubina. Uz to je taj
račun okretao znak za crnog, iako je `whiteVal - blackVal` već iz ugla belog, pa
je pozicija u kojoj crni ima pešak više pisala kao prednost belog.

Popravljeno: znak se više ne okreće (pokriveno testom), dubina je 0 umesto
tražene, i razlog ide u dnevnik. **Ali to ne čini pozicije analiziranim** —
za to treba pravi motor: Podešavanja → putanja do motora, na `stockfish.exe`.
Potvrđeno uživo: sa sopstvenim motorom rade pune linije i tačan znak
(−5.67 za poziciju u kojoj crni dobija).

Ranije viđeno „M1 (d50)" nije bio motor nego pogodak u mrežnoj bazi — zato je
delovalo da povremeno radi.

### Ponovno skeniranje dopunjava, ne dodaje i ne gazi — 19.8.2026

Preklapanje raspona strana je normalno: trener radi knjigu poglavlje po
poglavlje. Mereno na pravom preklapanju: **42 dijagrama stigla su dva puta sa
bajt-identičnim tablama**, ali je samo jedan primerak para nosio rešenje. Dakle
kopije nisu zamenljive, i pravilo „zadrži prvu" bilo bi pogrešno da su rasponi
skenirani obrnutim redom.

Pravilo je zato: **popuni prazno, ne diraj popunjeno.** Ono što već stoji ostaje
— trener koji je ručno ispravio stranu na potezu nadjačava skener koji je istu
stranu pročitao još jednom. Rešenje se upisuje samo ako **stvarno igra u već
sačuvanoj poziciji**; ako ne igra, to je neslaganje o nečem stvarnom i prijavljuje
se umesto da se zaglača.

Poruka posle čuvanja više ne kaže samo „sačuvano", nego „novih N, dopunjeno M,
već postojalo K, neslaganja L" — jer je samo „sačuvano 120" bilo tačno i
beskorisno istovremeno.

### Nijedan skener ne sme da preskoči potvrdu čoveka

Tok je: skeniraj → mreža kandidata → trener ispravi ili odbaci → sačuvaj. Čim to
prihvatimo, tačnost od 90% je upotrebljiva i faza 2 postaje moguća bez sopstvenog
modela. Automatske provere (legalnost pozicije, potez iz rešenja legalan, opseg
brojeva iz zaglavlja) služe da se treneru pošalje dvadeset sumnjivih umesto pet
hiljada.

### Prenos na Node je urađen i izmeren — 19.8.2026

Proba stoji u [puzzles/scanner](../puzzles/scanner/README.md) (nije deo
aplikacije). Python se **ne prenosi**: `pdfjs-dist` je čist JS i daje isto što i
PyMuPDF, `chess.js` proverava svaki potez.

| | |
|---|---|
| dijagrama nađeno u prvoj knjizi | 5.320 (Python ih je našao 5.234) |
| poklapanje sa Python izlazom | 5.220 istih, **0 različitih** |
| potez iz knjige legalan, id < 4463 | **4.436 / 4.437 = 99,98%** |
| popravki rokade i en passant-a | 16 |

Popravka metapodataka radi: `#305` je sad `O-O#` sa pravom `K` u FEN-u, `#306`
`axb6#` sa poljem `b6`. Ranije su obe bile „nelegalne", a bile su tačno
pročitane. Preostaje **jedan** stvarni promašaj u celoj knjizi (`#3518`).

Tri stvari koje su koštale vremena i koje ne treba ponovo otkrivati:

- **Dijagram se ne traži po broju** nego po obliku — osam redova glifova u istoj
  koloni. Parser vezan za broj nalazi 0 od 211 dijagrama u drugoj knjizi.
- **Koordinate redova (8..1) su takođe cifre** u levoj margini. Uzimanje najbliže
  cifre daje svakom dijagramu u knjizi broj „8". Broj je iznad table i nikad levo
  od njene ivice.
- **Notacija je dvosmislena kad nestanu razmaci.** `1.Nc6 b5` stiže kao `Nc6b5`,
  identično razjašnjenom potezu `Nc6b5`. Tekst to ne razrešava — nude se oba,
  kraći prvi, a `chess.js` odbaci pogrešan. Dok ovo nije bilo popravljeno,
  tačnost je izgledala kao 88,6% umesto 99,98%.

Font ne pomaže oko mape: `TTE2BEAF20t00` iz druge knjige ima `post` tabelu
verzije 3.0, dakle bez imena glifova. Mapa se izvodi iz same knjige, i to je
posao po knjizi — **za drugu knjigu je započet, nije završen.**

### Kako se izvodi mapa za novu knjigu — 19.8.2026

Pola mape daje statistika (`derive.mjs`), bez ijednog pogađanja: prazna polja su
najčešći glifovi, **kraljevi** su jedini par koji stoji tačno jednom na svakom
od 206 dijagrama, **pešaci** nikad ne stoje na 1. i 8. redu.

Ostatak daje **geometrija poteza** (`identify.mjs`): `1.Ng5` znači da beli skakač
stoji skakačev skok od g5, a koja su polja zauzeta zna se i bez mape, jer prazno
polje ima svoj glif. Vrati se unazad od odredišta i glif se sam predstavi.

Pre toga je pisana pretraga koja nabraja sve moguće mape: **2.654.208 kandidata,
sedam minuta, rezultat „nijedna ne prolazi"** — što ne kaže koja pretpostavka je
pukla. Direktna metoda daje isto za sekundu i uz to imenuje glif. Vredi zapamtiti
kao oblik greške: nabrajanje tamo gde podatak već sadrži odgovor.

Izvedeno do sada: kraljevi `I`,`K` / `i`,`k`; pešaci `P` / `p`,`0`; iz jednog
dijagrama i `R`,`$` beli topovi, `4` crni top, `G` beli lovac.

Usput je nađena protivrečnost u samoj knjizi: rešenje #2 je odštampano kao
`1...Bxh6` (crni na potezu), ali bi crni lovac sa g7 uzimao **sopstvenog** pešaka
na h6 — potez pripada belom lovcu sa c1. Alat to prijavljuje kao `PROTIVREČNO` i
ne bira stranu. To je tačno onaj raskorak koji ide treneru na potvrdu, i prvi
stvarni dokaz da ekran za potvrdu nije formalnost.

### Šta ovo košta

| | |
|---|---|
| Faza 1 — PDF sa vektorskim fontom | ~1,5 nedelja. Trošak izvršavanja **nula** |
| Faza 2 — skenirane slike | ~3–5 dana, **ponavljajući trošak** po strani |
| Veličina aplikacije | **+0 MB** ako ne uvodimo TensorFlow |

U fazi 1 nema ničeg novog na serveru: `pdfjs-dist` je čist JS i daje isto što i
PyMuPDF (ime fonta, koordinate glifova), `chess.js` i `multer` su već zavisnosti,
obrazac za otpremanje stoji u
[recordings.js](../chess_backend/routes/recordings.js). Provera motorom ide **na
uređaj** — backend nema Stockfish, aplikacija ga ima.

Za fazu 2 postoji `@google/genai`, već zavisnost. Tačnost na skeniranim stranama
je nepoznata; pre nego što se uloži pet dana, izmeriti na pet strana.

Skenirani fajlovi **ne idu u `uploads/`** — to je jedina kopija dečjih glasova.
Idu u zaseban direktorijum sa rokom trajanja, kao MP4 izvozi.

### Pravno — jedina cena koja nije mala

Pojedinačna pozicija je činjenica, ali **izbor i raspored** zbirke je autorski
rad, a u EU postoji i pravo proizvođača baze. Razlika je oštra: trener skenira
knjigu koju poseduje za svoje učenike = jedan rizik; mi te pozicije slivamo u
zajedničku bazu = sasvim drugi.

Ugrađuje se kao ograničenje dizajna, ne kao napomena: **skenirane pozicije su
privatne za trenera koji ih je uneo, ne ulaze u globalnu bazu zagonetki, i ne
dele se van njegovih učenika.** Ovo ide uz ostale pravne stavke koje ionako čekaju
pravnika ([TODO-objavljivanje.md](TODO-objavljivanje.md), korak 3).

I: **testne knjige i izvučeni JSON ne smeju u repozitorijum** — javan je.

## Odigran potez se više ne baca — 20.8.2026

Prva stavka iz [PITANJA-ZA-ODLUKU.md](PITANJA-ZA-ODLUKU.md), urađena pre ijednog
ekrana koji bi je prikazao — jer ekran može da sačeka, a podatak ne može.

`judgeAttempt` je i ranije vraćao `playedSan`, poslao ga klijentu u odgovoru i
tu ga ostavljao; u bazu je išlo samo `solved`. Posle toga se za odgovor moglo
reći „tačno" ili „netačno", nikad **šta je dete probalo** — a to je jedino što
treneru kaže *zašto* nije uspelo. Promašaj za jedno polje i potez koji nema veze
sa pozicijom bili su isti red.

Šta je urađeno, i ništa više od toga:

- `assignment_items.played_san VARCHAR(20)` — `ADD COLUMN IF NOT EXISTS`, kao
  ostale izmene šeme.
- `recordPuzzleResult` prima `playedSan` i upisuje ga uz `solved` i `ms_taken`.
  Parametar je **neobavezan**: put preko Lichess zagonetki šalje samo da li je
  rešeno, i tamo kolona ostaje `NULL` umesto da se izmišlja potez.
- `getAssignmentDetail` vraća kolonu, pa je podatak dohvatljiv bez novog
  endpointa kad ekran bude pisan. Rešenje i dalje ne izlazi pre odgovora — ovo
  je učenikov sopstveni potez, pa ništa ne odaje.

Dve stvari koje su namerno ovako:

- **`NULL` znači „ne zna se", ne „ništa nije odigrano".** Tako stoji za sve što
  je odgovoreno pre ove kolone i za korake lekcije, koji se čitaju a ne rešavaju.
  Ekran koji to bude prikazivao mora da poštuje razliku.
- **Potez koji tabla ne ume da odigra upisuje se kao `NULL`, ali se glasno
  prijavljuje.** To znači da se klijent i server ne slažu oko pozicije — dete je
  na svojoj tabli odigralo nešto što ova odbija. Bez upozorenja u dnevniku to bi
  bio tih slučaj koji se ne vidi nigde, a upravo takvi su nas već koštali.

Pokriveno sa tri testa u `test/assignment.test.js` (upis poteza, `NULL` umesto
praznog teksta, i pozivalac koji potez ne zna). Backend 190 testova, sve prolazi.

**Nije provereno uživo** — kolona se dodaje pri pokretanju servera i prvi upis
se desi tek kad dete odgovori na skeniranu poziciju. Vidi `TODO-provera.md`,
stavka 13.

## Jedna biblioteka pozicija, tri police — 20.8.2026

Pitanja 2 i 3 iz [PITANJA-ZA-ODLUKU.md](PITANJA-ZA-ODLUKU.md), rešena zajedno
jer su ista stvar sa dve strane.

Rupa koja se zatvara nije udobnost: **skenirana pozicija se do danas nije mogla
staviti u lekciju.** Editor lekcije je čitao `saved_lessons` i `saved_analyses`,
skener je pisao u `custom_puzzles`, i te dve police se nisu videle. Trener je
mogao da skenira dijagram, potvrdi ga i zada ga za domaći — ali ne i da po njemu
drži čas.

**Tabele se ne spajaju.** Oblici su stvarno različiti (jedna tabla i potez
naspram stabla varijanti sa PGN-om), pa bi spajanje nateralo svakog potrošača da
grana po vrsti — isti razlog zbog kog su `puzzles` i `lichess_puzzles` namerno
odvojene. Napravljen je **pogled**: `GET /library/positions` vraća sve tri police
sa poljem `kind`, svaka zadržava svoj upit, svoj redosled i svoju proveru prava.

Šta je ugrađeno, i zašto baš tako:

- **Pravo se ne prepisuje po treći put.** Sačuvane pozicije se čitaju kroz
  `acceptedTrainersOf`, kao i svuda drugde; test koji broji ručne kopije te
  podupite i dalje prolazi.
- **„Može li da se zada" odlučuje server**, kroz postojeći `assignableProblem`.
  Birač ne izvodi pravilo drugi put — dobija i odgovor i razlog.
- **Ono što se ne može zadati se ne krije.** Stoji sivo, sa razlogom pored
  („nema rešenje, pa odgovor ne može da se oceni"). Pozicija koju je trener
  sačuvao a ne može da nađe izgleda kao bag; ona koja kaže zašto — ne.
- **Traži se na serveru, ne u već učitanoj listi.** Stiže najviše 500 redova po
  polici, pa bi filtriranje na klijentu sakrilo baš ono što trener sa velikom
  bibliotekom traži.
- **Prazna polica i nedostupan server nisu isto.** Servis vraća `null` za drugo,
  i ekran to razlikuje.

### Zadatak i rešenje moraju da pređu sa pozicije na korak

Sitnica koja se najlakše izgubi, i zapisana je u pitanju 3: korak lekcije nosi
`title`, `fen`, `pgn` i `instruction`, a skenirana pozicija nosi `fen`,
`solution_san` i `instruction`. Ako `instruction` ne pređe, dete opet dobija
tablu bez pitanja — greška koju smo tek popravili.

`solution_san` takođe putuje, iako ga niko ne koristi: lekcija se čita, ne
rešava, ali isti korak kasnije može da postane domaći, a potez izgubljen na
ulazu se ne vraća. Prikazivač ga nikad ne odigra.

Gradnja koraka je izdvojena u `services/lessonSteps.js` — prolaze **samo polja
od kojih se korak sastoji**, ostalo otpada umesto da se čuva zato što je
stiglo, a FEN se proverava kroz `chess.js` (klijent nije autoritet za poziciju).

### Dodavanje ide na server, ne kroz čitaj-izmeni-upiši

`POST /lessons/:id/steps` dopisuje jedan korak jednim `UPDATE`-om. Da klijent
čita lekciju, dopiše korak i vrati je celu, dvoje koji je istovremeno menjaju
izgubili bi jednu izmenu — i to bez ijedne poruke.

Tri odbijanja imaju različite razloge i **kažu koji je koji**: nepostojeća ili
tuđa lekcija (404), pozicija koju nijedna tabla ne može da učita (422), i
pojedinačna sačuvana pozicija koja nije lekcija sa koracima (409). Poslednje je
namerno odbijanje a ne pretvaranje: dopisivanje koraka bi joj tiho promenilo
vrstu.

### Gde se birač koristi

- **Editor lekcije** — dve odvojene liste („gole pozicije iz baze" i dugme
  „Dodaj sačuvanu analizu") zamenjene su jednim dugmetom „Dodaj iz biblioteke".
- **„Moje pozicije"** — u traci za izbor stoji „Dodaj u lekciju" pored „Zadaj
  učeniku". Radnja je namerno u traci, a ne na kartici: već postoji izbor više
  pozicija odjednom, a kartica je puna (tabla, zadatak, rešenje, predlog motora).

### Izmereno uživo 20.8.2026

Backend pozvan preko HTTP-a sa mintovanim tokenom, kao i pri probi skenera:

| | |
|---|---|
| `GET /library/positions` | 203 stavke — 198 skeniranih, 2 sačuvane pozicije, 3 analize |
| može da se zada | 198; ostalih 5 sa razlogom |
| `?kind=analysis` | 3, samo analize |
| `?kind=scans` (greška u kucanju) | 400 sa spiskom dozvoljenih |
| dopisivanje koraka | 201, `step_count` 1 → 2, zadatak prešao uz poziciju |
| polja `id` i `junk` uz korak | odbačena, u bazi ostaju samo četiri prava |
| loš FEN / pojedinačna pozicija / tuđa lekcija | 422 / 409 / 404, svaki sa svojim razlogom |

Probna lekcija je zatim obrisana. **Ekran u aplikaciji još niko nije otvorio** —
`TODO-provera.md`, stavka 14.

Uzgred provereno istom prilikom: kolona `assignment_items.played_san` stvarno
postoji u bazi posle pokretanja servera (`character varying(20)`).

## Pregled urađenog domaćeg i komentari — 20.8.2026

Pitanja 4 i 5 iz [PITANJA-ZA-ODLUKU.md](PITANJA-ZA-ODLUKU.md), rešena zajedno
jer im je oblik isti.

Do danas se domaći završavao kao dve brojke — „2/2 urađeno, tačnost 100%".
Nijedna strana nije mogla da otvori **jednu poziciju** i vidi koju je tablu dete
imalo pred sobom i šta je odigralo. To je deo koji kaže *zašto*, i jedini iz kog
se može predavati.

### Ekran

`GET /assignments/:id/review` vraća zadatak, stavke i razgovor — jedan zahtev,
jer je jedan ekran. Ekran je isti za obe strane, a `viewer.isTrainer` menja reči:
„tvoj potez" i „učenikov potez" su isto polje i nisu ista rečenica.

Tri vrste stavke se **ne spljoštavaju** u jednu:

| vrsta | šta nosi |
|---|---|
| skenirana pozicija | tabla, zadatak, autorov potez, odigran potez |
| Lichess zagonetka | tabla i cela linija u zapisu u kom je čuvana |
| korak lekcije | tabla i zadatak — **bez ocene**, jer se korak čita, ne rešava |

Četvrti slučaj je stavka čija je zagonetka nestala (obrisana pozicija, id koji
nikad nije uvezen). Pokušaj se i dalje prikazuje: izbaciti taj red značilo bi
tiho promeniti broj urađenog.

### Kada se rešenje sme videti

Jedino pravilo na ovom ekranu koje je moralo da bude precizno:

- **Učenik ga vidi tek pošto je odgovorio.** Ranije bi to bilo davanje odgovora
  na pitanje koje mu se postavlja. Posle odgovora skrivanje bi ga samo sprečilo
  da nauči šta je promašio.
- **Trener ga vidi uvek.** To je njegov materijal i on ga je birao.
- **Sakriveno rešenje i nepostojeće rešenje nisu isto.** Zato uz stavku ide i
  `solutionHidden` — pozicija bez rešenja i pozicija čije rešenje još nije
  zarađeno izgledale bi identično, a to su različite stvari.

Uz to: **odigran potez koji nije zabeležen nije „ništa nije odigrano".** Za sve
odgovoreno pre 20.8. i za ceo Lichess put kolona je prazna, i ekran to piše kao
„nije zabeležen", odvojeno od „nije urađeno".

### Komentari su jedna tabela, ne četiri kolone

`assignment_notes(id, assignment_id, item_id NULL, author_id, body, created_at)`.
`item_id` prazan znači komentar na ceo zadatak. Autor se čita iz naloga, pa ko
je šta rekao nije upisano dvaput i ne može samo sa sobom da se ne složi.

Alternativa je bila trenerov komentar na zadatak, učenikov na zadatak, trenerov
na poziciju i učenikov na poziciju — četiri mesta za istu vrstu stvari i svaki
čitalac spaja sva četiri.

Odluke koje su ugrađene:

- **Komentar na poziciju mora biti na poziciji iz tog zadatka.** Bez te provere
  bi `item_id` iz tuđeg domaćeg upao ovde i poruka bi stajala uz tablu o kojoj
  ne govori.
- **Autor može da povuče svoje reči, i ničije druge.** Dete koje napiše nešto
  pa se predomisli treba da može; trener koji briše detetove reči je sasvim
  druga stvar i ne nudi se.
- **Obe kaskade su namerne.** Povučen zadatak nosi razgovor sa sobom, a obrisan
  nalog nosi detetov tekst — to je tekst koji je dete napisalo i ne treba da ga
  nadživi ovde.
- **Prava se čitaju na jednom mestu.** `assignmentParticipant` je jedini uslov
  iza svega oko jednog zadatka: dve strane i niko treći, isti odgovor za „ne
  postoji" i „nije tvoj". Namerno **ne** proverava ponovo odnos — trener koji je
  zadao domaći pa je veza kasnije raskinuta i dalje treba da vidi šta je urađeno,
  a učenik ne sme da izgubi svoj rad zato što se veza promenila.

### Gde se ulazi

- **Trener:** Prijatelji → učenik → dodir na zadatak u listi.
- **Učenik:** „Moji zadaci" → „Pregled i komentari" (vidi se čim je bar jedna
  pozicija urađena, ne tek na kraju — dete koje je zapelo na trećoj ima šta da
  pita odmah). Završen skup zagonetki se sada otvara u pregled, jer u njemu više
  nema šta da se rešava.

### Izmereno uživo 20.8.2026

Preko HTTP-a, sa tokenima obe strane:

| | |
|---|---|
| pregled zadatka od 2/2, obe strane | tabla, vreme, ocena, rešenje |
| neodgovorena stavka, trener | linija se vidi |
| ista stavka, učenik | `null` i `solutionHidden: true` |
| lekcija | koraci sa naslovima, `solved = null` — bez lažne ocene |
| pregled trećeg naloga | 404, isti odgovor kao za nepostojeći |
| komentar na zadatak i na poziciju | 201, obe strane ih vide, `mine` tačno |
| prazna poruka / tuđa pozicija / tuđi zadatak | 400 / 400 / 404 |
| trener briše učenikovu poruku | 404 — samo autor može |

Probne poruke su zatim obrisane. **Ekran u aplikaciji još niko nije otvorio** —
`TODO-provera.md`, stavka 15.

Uzgred, proba je pokazala i nešto što se u kodu ne vidi: **sve postojeće stavke
imaju prazan `played_san`**, jer su odgovorene pre 20.8. Ekran ih prikazuje kao
„nije zabeležen" — što je tačno, i ujedno mera koliko je vredelo dodati kolonu
pre ekrana.

### Pravno

Komentari su sadržaj koji se čuva i koji piše dete, pa su dopisani u nacrt
politike privatnosti (`politika-privatnosti.md`, tabele u 3.2 i 6) zajedno sa
odigranim potezom. Ne otvaraju novu površinu — sve ostaje unutar odnosa koji je
već zasnovan pristankom.

## Domaći se više ne rešava u koloni — 20.8.2026

Pitanje 1, poslednje od pet.

**Šta je bilo:** ekran je napravio red od nerešenih pozicija u trenerovom
redosledu i vodio kroz njih jednu po jednu. Nije bilo pregleda svih, ni
preskakanja, ni vraćanja. Dete koje zapne na trećoj poziciji nije moglo do
četvrte — a domaći koji se ne može završiti je domaći koji se ne radi.

**Šta je sada:** zadatak se otvara kao **mreža svih pozicija** sa stanjem, i
radi se kojim redom se hoće.

Tri stanja, ne dva: `tačno`, `netačno`, `nije urađeno`. Druga dva su par koji je
učeniku najvažnije da razlikuje, a stara traka napretka ih je spajala u jedan
broj.

Zašto ovo ništa ne odaje: **rešenje se ne šalje aplikaciji unapred** — server
sudi potez i otkriva odgovor tek posle njega — pa mreža tabli otkriva tačno
onoliko koliko je otkrivala jedna tabla. To je bio jedini prigovor slobodnom
redosledu i ovde ne stoji.

### Trenerov redosled nije bačen, prestao je da bude kavez

- Mreža je u trenerovom redosledu, i „Nastavi" vodi na **prvu poziciju koja još
  čeka** — ne na onu posle poslednje dodirnute.
- „Sledeća nerešena" **obilazi u krug**. Pozicija preskočena na početku se tako
  stigne sa kraja; bez toga bi dugme koje piše „sledeća" tiho ostavilo posao iza
  sebe, a dete bi moralo samo da se seti da se vrati.
- Strelice levo/desno prolaze kroz sve pozicije redom, urađene i neurađene, jer
  je gledanje unaokolo pola razloga zašto mreža postoji.

### Već urađena pozicija se otvara, ali se ne rešava ponovo

Tabla je zaključana i piše zašto: **računa se prvi pokušaj**. Tabla koja bi i
dalje primala poteze obećavala bi drugu priliku koje nema. Uz to stoji prečica
na „Rešenje i komentari", jer se tamo rešenje već sme videti.

Traka napretka sada meri **koliko je urađeno**, a ne dokle se stiglo u redu —
sa slobodnim redosledom to više nije isto pitanje.

Ništa na serveru nije menjano: pravilo „samo prvi pokušaj se upisuje" je
postojalo (`recordPuzzleResult` gađa samo redove sa `attempted_at IS NULL`), a
ovaj ekran ga sada i pokazuje umesto da se oslanja na to da se pozicija ne može
otvoriti dvaput.

Redosled je pokriven testovima (`test/solve_order_test.dart`) jer je logika
„sledeće" jedino mesto gde se posao može izgubiti, a mreža sa tri stanja
`test/assignment_overview_test.dart`. Aplikacija 296 testova, `flutter analyze`
čist.

**Nije viđeno uživo** — `TODO-provera.md`, stavka 16.

## Prva prava upotreba svega urađenog — 20.8.2026

Korisnik je prošao ceo lanac na Windows-u i na telefonu, sa oba naloga. Prošlo
je: birač biblioteke sa tri police, skenirana pozicija u lekciji **sa svojim
zadatkom**, mreža sa slobodnim redosledom, „Sledeća nerešena", ocena posle
netačnog odgovora, pregled sa obe strane, i komentari u oba smera. Dnevnik
servera je čist — nijedno upozorenje, nijedan potez koji server nije umeo da
razreši.

Prvi put se uživo video i **odigran potez**: `Odigrao: Qh1# · Rešenje: Qh1#`.
Na starom Lichess zadatku i dalje piše „nije zabeležen", što je tačno — taj put
potez ne šalje.

### Zadatak koji se ne može odigrati — našao ga je učenik

Njegovim rečima: *„ovde ne mogu da pomeram figure, samo mogu da gledam
pozicije"*, napisano kroz komentar koji je tog jutra i dobio.

Uzrok je naš od istog dana. Skenirana pozicija nosi zadatak („Beli matira u
jednom potezu"), zadatak sada putuje u lekciju — a tabla u pregledaču lekcije
je bila zaključana, jer se lekcija čita a ne rešava. Dok koraci nisu imali
zadatke, to se nije videlo. Sa zadacima, **ekran traži potez koji ne prima**.

Isti oblik greške kao ostali u ovom projektu, treći put u novom ruhu: prvo korak
koji tiho ne uradi ništa, pa sumnja koja se prećuti u tvrdnju, sad obećanje koje
ekran ne može da ispuni.

Rešenje: **tabla u lekciji prima poteze**, ali ništa ne ocenjuje niti upisuje.
Kad se figura pomeri, ispod stoji „Probaš poteze — ovde se ništa ne ocenjuje" i
dugme **Vrati poziciju**. Dugme se pojavljuje tek posle prvog poteza; da stoji
od početka, sugerisalo bi da nešto sa pozicijom nije u redu. Prelazak na drugi
korak ili šetnja kroz varijantu vraćaju tablu sami.

Lekcija time nije postala vežba: napredak se i dalje meri pregledanim koracima,
ništa se ne šalje serveru, i nema ocene. Pokriveno testom
(`test/lesson_board_playable_test.dart`), koji pini baš to da korak koji traži
potez mora da ga primi.

### Linija zagonetke se sada može pročitati

U pregledu je stajalo `e7b7 b8b7 g7g8q` — zapis u kom Lichess čuva liniju,
tačan i nečitljiv. Sada stoji `Rb7 Rxb7 g8=Q Rg7+ Qxg7+ Kxg7`; prevod radi
server kroz `chess.js` pri sastavljanju pregleda.

Ako se linija ne odigra u toj poziciji, **vraća se onakva kakva je sačuvana**.
To znači da se pozicija i linija oko nečeg stvarnog ne slažu, a prazno polje bi
to sakrilo. Delimičan prevod se ne nudi — izgledao bi kao ceo odgovor.

Ostaje nezabeleženo: **odigran potez na Lichess putu**. Klijent zna koji je
potez dete odigralo u zagonetki, ali ga ne šalje, pa tamo i dalje piše „nije
zabeležen". Odloženo svesno, nije zaboravljeno.

### Sve provereno uživo — 20.8.2026

Korisnik je istog dana prošao **ceo spisak po stavkama**, na svežem build-u za
Windows i na novoinstaliranom APK-u: biblioteka i „Dodaj u lekciju", slobodan
redosled sa preskakanjem i povratkom na preskočenu poziciju, već urađena
pozicija sa zaključanom tablom, pregled sa obe strane i komentari u oba smera,
igriva tabla u lekciji sa vraćanjem pozicije, i linija zagonetke u čitljivom
zapisu. Sve se ponašalo kako je opisano.

Dnevnik servera je za celu tu sesiju čist: nijedno upozorenje, nijedan
`Custom attempt could not be resolved to a move`, nijedan odbijeni upis.

Neprovereno ostaje samo ono što traži da se **server ugasi** (poruka „Nije
moguće doći do servera" u biraču i traka koja se sama povlači kad server krene),
i priznavanje **drugog mata** na dijagramu #122, gde ta zbirka ima dva mata u
jedan. Oboje stoji u `TODO-provera.md`.

Napomena za sledeći put: `flutter install` instalira **zatečeni** APK, a ne
sveže sagrađen. Jednom je time na telefon vraćena verzija stara nedelju dana.
Prvo `flutter build apk --release --target-platform android-arm64`, pa
instalacija.

## Zagonetka sada kaže šta je dete prvo probalo — 20.8.2026

Poslednje mesto na kom je u pregledu pisalo „nije zabeležen". Klijent je znao
potez i nije ga slao.

**Ali „odigran potez" ovde ne znači isto što i kod trenerove pozicije**, i to je
cela suština ove izmene. Pozicija koju trener zada odgovara se **jednom** —
potez je odgovor. Zagonetka odbija pogrešan potez i pušta da se proba ponovo, pa
niza pokušaja ima koliko hoćeš. Ono što treneru zaista nešto govori je **prva
pogrešna ideja**: šta je dete mislilo pre nego što je našlo, ili umesto da nađe.

Zato se čuva prvi pogrešan potez, i samo on. Kasniji pokušaji su ispravke te
iste ideje, a spisak ispravki kaže manje od onoga što ih je pokrenulo.

Iz toga sledi da `NULL` u toj koloni sada pokriva **tri** slučaja, i ekran ih ne
sme spljoštiti u jedan:

| | |
|---|---|
| red odgovoren pre 20.8.2026. | podatak ne postoji |
| korak lekcije | čita se, ne rešava |
| **zagonetka rešena bez ijedne greške** | nije bilo šta da se zabeleži |

Treći je nov. Zato u pregledu kod takve zagonetke **ne piše ništa** o potezu —
„nije zabeležen" bi zvučalo kao da se nešto izgubilo. Kad prva greška postoji,
red se zove **„Prvo probao"**, a ne „Odigrao": to su dve različite tvrdnje i
jedna oznaka za obe bila bi netačna kod jedne od njih.

**Provereno uživo 20.8.2026** na telefonu: „Prvo si probao" sa potezom u
notaciji kod zagonetke sa greškom, nijedan red o potezu kod one rešene iz prve,
„nije zabeležen" kod starih, i linija u čitljivom zapisu. Dnevnik servera čist.

Napomena o poverenju: ovaj potez dolazi **od klijenta**, za razliku od
trenerovih pozicija gde ga server izvodi sam dok sudi. To nije novo popuštanje —
na ovom putu klijent već odlučuje i `solved`, pa potez nije poverljiviji od
ocene uz koju stiže. Prolazi kroz `cleanSan`, koji zadržava samo ono od čega
potez može da bude sastavljen.

## Dve ikone na telefonu, i skripta koja je pokretala pogrešnu — 20.8.2026

Simptom: prijava kao učenik prolazi, a aplikacija nema ni „Moje zadatke" ni
trenera u „Prijateljima". Izgleda kao da je nalog prazan.

Nije bio. Podaci su provereni sa obe strane: odnos `trener → učenik` je
`accepted`, sedam zadataka postoji, a `GET /assignments/mine` i `GET /friends`
vraćaju i jedno i drugo — isto preko `localhost` i preko LAN adrese koju telefon
gađa.

Uzrok je nađen preko `adb`: u prvom planu je bio paket
**`com.example.chess_app`** — instalacija od pre preimenovanja paketa. Nikad se
ne ažurira, nosi kod od pre celog rada na zadacima, a **prijava u njoj radi**
jer se backend nije menjao. Otud „prazan nalog".

Zapisano je i ranije da tu staru instalaciju treba obrisati
([TODO-provera.md](TODO-provera.md), stavka 8); danas je prvi put ujelo.

**Prava krivica je bila u `chess_app/build_and_deploy.ps1`:** skripta je
instalirala **novu** aplikaciju, a onda pokretala **staru**, jer je ime paketa
bilo prekucano u njoj i ostalo staro posle preimenovanja. Sedmi primer istog
oblika greške u ovom projektu: korak koji uspešno prijavi da je gotov, a odradi
nešto drugo.

Šta je popravljeno u skripti:

- **Ime paketa se čita iz `android/app/build.gradle.kts`**, ne kuca se. Prepis
  se jednom raziđe sa aplikacijom, i to se već desilo.
- **Nema više pada na `app-release.apk`** kad sveže sagrađen APK ne postoji. Baš
  tako je istog dana na telefon otišla verzija stara nedelju dana (kroz
  `flutter install`, koji instalira zatečeni APK). Sad staje uz objašnjenje.
- **Proverava se da je APK mlađi od početka gradnje** — zaostao fajl se ne
  instalira ni slučajno.
- Provere pre gradnje: `adb`, `dart_defines.json`, i koji je uređaj povezan
  (kad ih ima više, traži `-Serial` umesto da pogađa).
- Na kraju **upozorava ako stara instalacija još stoji na telefonu**, sa
  komandom za brisanje.

Provereno tako što je skripta puštena od početka do kraja: sagradila, instalirala
i pokrenula `rs.pejovic.chesscoach`, pa ispisala upozorenje o staroj instalaciji.

Stara instalacija je zatim **obrisana sa korisnikovog telefona** (na njegov
zahtev), pa je ostala samo jedna ikona. Upozorenje u skripti ostaje — isti
uređaj nije jedini na kom se stara verzija može zateći.

## Zvonce je dobilo kvačicu i krstić — 20.8.2026

Sprovedena odluka od 17.8.2026. Zahtev za odnos se do danas vodio na **dva**
mesta: kartica „Čeka vaš odgovor" u tabu Prijatelji, gde se odgovaralo, i
obaveštenje u zvoncetu, koje te je slalo tamo. Dva vlasnika jedne stvari, i to
se već jednom osvetilo — obaveštenje je ostajalo nepročitano zauvek, jer ništa
nije vezivalo odgovor za njega.

Sada se odgovara **u zvoncetu**, i nigde drugde.

### Šta je zvonce dobilo

- Kvačica i krstić stoje uz zahtev, sa istim rečima kao ranije („želi da vas
  upiše kao učenika" / „želi da mu budete trener").
- Posle odgovora **red ostaje**, i piše šta je odlučeno. Da nestane ispod prsta
  koji ga je upravo dodirnuo, ostalo bi pitanje da li se išta desilo.
- Ako server odbije, red ostaje **neodgovoren**. Prikazati suprotno značilo bi
  izgubiti zahtev.
- Dok traje slanje, dugmad zamenjuje vrteška — dvostruki dodir ne šalje dva
  odgovora.

### Nepredviđena rupa koju je ovo otvorilo, i kako je zatvorena

`GET /notifications` vraća **poslednjih dvadeset**. Da se odgovor oslonio samo
na obaveštenje, zahtev bi ispao iz liste čim stigne dvadeset novijih poruka — i
postao **neodgovoriv**, tiho. Zato je izvor istine za „šta još čeka"
`/relationships/pending`, a ne lista obaveštenja: sve što je neodgovoreno vidi
se u zvoncetu bez obzira na to da li je njegovo obaveštenje preživelo.

Iz istog razloga i **značka broji zahteve iz te liste**, pa obaveštenje istog
zahteva preskače — inače bi jedan zahtev brojao dvaput ili nijednom.

Zahtev koji još čeka prikazuje se **jednom**: kao red sa dugmadima. Njegovo
obaveštenje bi ga inače ponovilo odmah ispod. Obaveštenje o zahtevu koji je
**već odgovoren** ostaje u listi kao poruka, sa „Odgovoreno." umesto dugmadi —
ponuditi dugmad drugi put bilo bi laž.

### Šta je otišlo iz taba Prijatelji

Kartica „Čeka vaš odgovor", i sa njom filtriranje po `i_asked` koje je postojalo
**samo** zbog nje (da se isti čovek ne pojavi dvaput — jednom sa dugmadima,
jednom sivo). Sada se u listi vide svi, a sivi red kaže **na koga se čeka**:

| | |
|---|---|
| ja sam poslao | „čeka potvrdu" |
| čeka se moj odgovor | „odgovorite u zvoncetu" |

To je bolje od ranijeg skrivanja: čovek koji nestane iz liste dok ne odgovori
izgleda kao da ga nema.

Ništa na serveru nije menjano — `accept`/`decline` primaju `id` reda u
`trainer_students`, a to je upravo `ref_id` koji obaveštenje već nosi, i server
sam zatvara obaveštenje posle odgovora.

Pokriveno testovima: zvonce (odgovor, odbijen odgovor, zahtev bez obaveštenja,
zahtev prikazan jednom, odgovoren zahtev bez dugmadi) i tab Prijatelji (sivi red
sa uputstvom, i onaj koji čeka drugu stranu). Aplikacija 310 testova,
`flutter analyze` čist.

**Nije viđeno uživo** — `TODO-provera.md`, stavka 19.

## Dve greške nađene 22.8.2026, nisu popravljene

Obe je korisnik primetio u Windows verziji dok je proveravao trener završnica,
i obe su van onoga što je tada rađeno. Zapisane su namerno neurađene.

**Zašto čekaju — odlučeno 23.8.2026.** Projekat je još u izgradnji i korisnik je
zasad **jedini koji ga koristi**: nema deteta kome se mikrofon otvara i nema
tuđeg naloga koji ostaje zaglavljen u poluprijavljenom stanju, pa je stvarna
cena obe greške danas nula. Obe ipak moraju biti zatvorene pre nego što
aplikaciju dotakne iko osim vlasnika — glas zato što otvara mikrofon detetu i
troši novac, istek tokena zato što tuđi korisnik nema odakle da zna da treba
ručno da se odjavi.

### Glas se uključuje sam i naplaćuje se

`_initAudioChat()` se poziva **bezuslovno iz `initState`** u
[chess_game_screen.dart](../chess_app/lib/screens/chess_game_screen.dart) —
čim se uđe u sobu, traži se Agora token, otvara se glasovni kanal i backend
počne da meri. Iz korisnikovog loga:

```
19:58:50  [AUDIO] User pavle joined audio in room STUDIO
19:59:07  [AUDIO] User 5 left audio in room STUDIO
19:59:08  [AUDIO] Booked 18s of voice for user 5
```

Osamnaest sekundi glasa naplaćeno za sesiju u kojoj niko nije nameravao da
priča; minut ranije još četiri. Agora se plaća po minutu i `usage_counters` to
broji kao potrošnju.

Nije samo trošak. **Mikrofon se otvara pre nego što je iko rekao da hoće
razgovor**, a većina korisnika su deca. Ulazak u kanal treba da bude na dugme.

Ograda pre popravke: trener verovatno očekuje da ga se čuje odmah po ulasku, pa
podrazumevano ponašanje možda treba da zavisi od uloge u sobi, a ne da bude
isto za sve.

### Istekao token ne odjavljuje korisnika

```
19:56:25  [SOCKET AUTH] Rejected connection: jwt expired
```

Socket je odbijen, ali klijent to ne tumači kao kraj sesije. `401` se hvata
jedino u
[server_status_service.dart](../chess_app/lib/services/server_status_service.dart);
nema centralnog mesta koje istek pretvara u odjavu.

Posledica koju je korisnik prijavio: aplikacija kaže da se treba prijaviti
ponovo, ali i dalje smatra korisnika prijavljenim, pa **mora prvo ručno da se
odjavi**. Taj međukorak ne bi trebalo da postoji — kad backend kaže da je token
istekao, sesija se čisti sama i vodi na ekran za prijavu.

## Završnice: ceo krug urađen 23.8.2026

Jedan dan, i lanac je zaokružen od tablica do ekrana. Redom, sa onim što se iz
koda ne vidi:

**Šestofiguraške tablice** su skinute (730 fajlova, 149,2 GB) i sve sume su
proverene. Rudar ih koristi do šest figura; `--syzygy` prima više foldera
razdvojenih `os.pathsep`, a na startu proba po jednu poziciju za svaki broj
figura, da mašina bez tablica stane u prvoj sekundi umesto sat vremena unutra.

**Cela zbirka je ponovo presuđena** iz tablica: 596 pozicija, 595 ishoda
potvrđeno, jedan ispravljen. Motor je bio u pravu 595 puta od 596 — dizanje
granice nije bila ispravka zatečene građe nego osiguranje buduće.

**Detektor grešaka** (`puzzles/blunder_detector.py`) prošao je 663.000 OTB
partija i našao 5.256 partija sa 9.811 grešaka. Od toga je 7.173 pozicije ušlo
u trener, pa je zbirka sa 1.089 narasla na **8.262**.

**Dopuna istog dana, uveče.** Rudar je u međuvremenu nastavio da radi. Prvo je
dopunjen OTB deo — 5.489 partija, još 992 pozicije i 250 partija — a onda je,
kad je prolaz kroz „Lumbras Online" završen, uvezena i ta baza: **još 4.518
pozicija i 3.449 partija**. Stanje u bazi: **14.282 pozicije** (12.683 iz
grešaka) i **8.955 partija** za šetnju. Nijedan FEN nije odbačen ni u jednom od
tri uvoza.

**Četiri ekrana rade sa tim**: rešavanje pozicije (dobitak / remi), igranje do
kraja protiv tablično savršenog protivnika, kazna, i šetnja kroz partiju sa
stajanjem na svakoj grešci. Sve provereno uživo na Windows-u istog dana, osim
onoga u `TODO-provera.md` tačke 0e–0j.

**Izbor šta se vežba**: 128 tipova završnica svrstano u sedam porodica pravilom
iz samog ključa, sa srpskim imenima koja se takođe izvode. Ništa se ne održava
rukom — nov tip iz sledećeg rudarenja sam se svrsta i sam dobije ime.

**Objašnjenje „zašto"** ima četiri stepenika: ishod iz tablice, pravilo koje
dele svi potezi koji drže (`holding_pattern.dart`, izmereno — 54% pozicija ga
ima), kazna odigrana na tabli, i „Zapamti za kasnije" sa oznakom `Nejasno` kad
ni to ne pomogne.

### Greške koje su nas koštale u ovom krugu

Sve su istog oblika kao one iz `CLAUDE.md` — tiho pogrešan rezultat, ne pad:

- **Preneseni znak.** `get_wdl` uvek odgovara za stranu na potezu, pa posle
  poteza već govori za sledećeg igrača i ne treba ga obrtati. Obrtanje je
  izvrnulo svaki drugi polupotez, i prvi prolaz je javio da majstori u 77 od 80
  slučajeva iz dobitka odu pravo u gubitak.
- **Brojač pedeset poteza.** `probe_wdl` odgovara kao da je na nuli. Prva
  pronađena greška bila je Lasker–Taraš 1908 na 95 poluposteza, gde je dobitak
  postojao sa tačno pet na raspolaganju.
- **DTZ se poredi preko granice nuliranja.** Isti oblik na dva mesta: u oceni
  napretka i u izboru poteza. Drugo je pravilo „najmanji DTZ" pretvorilo u
  beskonačno ponavljanje — dobitak se držao, partija se nije završavala.
- **Jača strana nije prva u ključu.** `KPPvKR` je top protiv dva pešaka. Čitanje
  belog kao naoružane strane bacilo je petinu zbirke u „Ostalo".
- **Test očiglednosti nije reproducibilan** i **nije popravljen** — plitki motor
  nosi transpozicionu tabelu iz pozicije u poziciju. Zapisano u `ZAVRSNICE.md`.

### Otvoreno

~~**Prijava koju nisam uspeo da reprodukujem.**~~ — **razjašnjeno 23.8.2026,
nije kvar.** Korisnik je javio da u šetnji, pošto prvi potez promaši, figura se
podigne i vrati; posle je sam utvrdio šta se dešavalo — odigravao je poteze koji
ne drže rezultat, pa je tabla odbijala potez tačno kako treba. Pet testova i
podaci su zato i pokazivali da greške nema.

Ostavljeno kako jeste, jer poruka već imenuje potez koji je odbijen („Rd3 takođe
ispušta dobitak. Probajte drugi potez."), a poruka o zaključanoj tabli je usput
dopunjena i vredi za slučaj kad kursor zaista ne stoji na grešci.

**Telefon nije viđen ni za jednu od šest tačaka** (0e–0j), a to je jedina
platforma na kojoj panel ide ispod table.

**Ostatak OTB baze** je mašinsko vreme: prošlo je 663.000 od 9,7 miliona
partija, uz poznat prinos od 9,3 partije sa greškom na 1000.

**Majstorske baze su gotove — 798 partija, 1.031 pozicija.** Svih 43 baze
pojedinačnih igrača su prošle 23.8.2026. Uvezeno je 818 pozicija i 626 partija.
One **ne stoje odvojeno od OTB-a**: partija odigrana za tablom je partija
odigrana za tablom, ko god je igrao.

Stanje posle svega: **15.100 pozicija** (13.501 iz grešaka) i **9.581 partija**.
Od pozicija koje se stvarno serviraju (one sa rešenjem, 14.590): 10.057 za
tablom, 4.533 online, a 1.053 rudarene nemaju izvor jer nisu iz partije.

**„Lumbras Online" je uvezena — 3.463 partije, 4.537 pozicija.** Odluka je
menjana istog dana i vredi zapisati oba koraka: dok je rudar još radio uvezen je
samo OTB deo, a kad je prolaz završen korisnik je rekao da uđe i online.

Ono što ta odluka nosi sa sobom: **težina se izvodi iz rejtinga onoga ko je
pogrešio** (`difficulty_from_elo` u `puzzles/blunders_to_puzzles.py`), a online
rejting nije OTB rejting — ista brojka sada znači dve različite stvari u istoj
lestvici. Zbirka je time skoro udvostručena, pa je to prihvaćena cena, ne
previd.

**Online se od 23.8.2026. i razdvaja u aplikaciji.** Korisnik je tražio da
majstorske partije idu zajedno sa OTB-om, a da online ide zasebno, pa pozicije
sada pamte iz koje baze su došle:

- `endgame_puzzles.source_db`, isto kao `blunder_games` odranije. Uvoz ga
  upisuje, a `--fill-source` ga je dopisao na 13.537 redova koji su uvezeni pre
  nego što je kolona postojala. Namerno zaseban prolaz umesto `--update`:
  `--update` bi preko pozicija vratio i presude iz fajlova, pa bi pobrisao svako
  ponovno suđenje.
- Ruta izostavlja online osim ako se traži (`includeOnline=true`), i pozicije i
  partije za šetnju.
- U aplikaciji: prekidač „Uključi i online partije" u izboru završnica,
  podrazumevano isključen, zapamćen na nivou aplikacije (šetnja se ne otvara
  kroz taj ekran, a pita isto).

**Zamka koja je ovde bila na korak.** Uslov je `IS DISTINCT FROM`, ne `<>`.
Rudarene pozicije nemaju izvor, `source_db <> '...'` je za njih NULL, NULL nije
TRUE — pa bi običan uslov nečujno izbacio 1.053 pozicije koje sa online bazom
nemaju veze. Ime baze zna tačno jedan fajl
(`services/endgameSources.js`), a test pada ako se pojavi drugi — isto kao kod
`acceptedTrainersOf`.

## Govor: aplikacija čita svoje poruke — 23.8.2026

Traženo zato što se u treneru završnica pogled stalno cepa između table i info
panela sa strane. Poruka koja se čuje ne traži da se skrene pogled, pa tabla
ostaje u fokusu.

**Gde se uključuje:** Podešavanja → „GOVOR (ČITANJE PORUKA)". Prekidač,
izbor glasa, brzina i dugme „Probaj". **Podrazumevano je isključeno** — čas sa
detetom u kojem odjednom progovori mašina nije nešto što treba da se desi
slučajno.

**Šta se čita:** ono što piše u info panelu — presuda kad je ima, inače zadatak.
Kuka je u samom panelu (`lib/widgets/endgame_info_panel.dart`), a ne u ekranima
koji ga koriste: ekran koji na šest mesta postavlja `_feedback` morao bi da se
seti da na svih šest i progovori. Drugim mestima u aplikaciji se dodaje jednim
pozivom — `SpeechService.instance.speak(tekst)`.

### Notacija se ne čita slovo po slovo

`Rd3` svaki sintetizator pročita kao tri znaka, što je šum. Zato
`lib/core/services/speech_text.dart` prvo prevede poteze u reči: „top de tri",
„pešak sa e uzima de pet", „dama ef jedan, mat", „mala rokada". Cifra ranga se
namerno ostavlja kao cifra — glas je pročita na svom jeziku, pa brojevi ne
moraju da se pišu.

Rečnik (imena figura, imena linija) stoji odvojeno od pravila, jer se pri
dodavanju drugog jezika menjaju samo reči — notacija je svuda ista.

### Windows nema srpski glas, i to je uredno rešeno

Microsoft-ov spisak glasova **nema srpski**, ali ima **hrvatski**. Hrvatski
glas čita srpski latinični tekst ispravno — ista azbuka, isti glasovi — pa je
redosled izbora `sr`, pa `hr`, `bs`, `sh`, `me`.

Ono što se **nikad** ne radi: pad na engleski ili bilo koji drugi glas. Engleski
glas kojem se da srpski tekst ne otkaže — pročita ga engleskom fonetikom, što
zvuči kao da funkcija radi. To je isti oblik greške kao sve iz `CLAUDE.md`, pa
umesto toga panel u podešavanjima kaže da glasa nema i kako se dodaje.

Spisak glasova se ne čita samo pri pokretanju: glas se instalira iz podešavanja
operativnog sistema, dok aplikacija već radi. Zato se traži ponovo svaki put kad
se otvori ekran sa podešavanjima, a postoji i dugme „Potraži glasove ponovo" —
bez toga bi aplikacija tvrdila da glasa nema onome ko ga je upravo instalirao.

**Na ovoj mašini glasa još nema** (instalirani su samo engleski i nemački).
Windows: Podešavanja → Vreme i jezik → Govor → Dodaj glasove → Hrvatski.
Android: Podešavanja → Pristupačnost → Tekst u govor (Google-ov mehanizam ima
srpski, ali se podaci za jezik skidaju posebno).

### Windows build od sada traži `nuget.exe`

`flutter_tts` na Windows-u u CMake koraku povlači CppWinRT preko NuGet-a i
**prekida build** ako `nuget` nije na PATH-u. Instalirano 23.8.2026 sa
`winget install Microsoft.NuGet`. Poruka je jasna i glasna (`nuget.exe not
found`), pa ovo ne može da prođe nezapaženo — ali novoj mašini treba isti
korak. CI ne dira: gradi APK na Ubuntu-u.

### Nađeno na telefonu 23.8.2026, popravljeno istog dana

Prva proba uživo (Android) dala je dve stvari, obe iz onoga što se čuje a ne
vidi:

**Brojevi nisu bili u padežu.** Pisalo je i izgovaralo se „Postoji još 2 takvih
poteza". Srpski ima tri oblika, ne dva, a aplikacija je svuda pisala treći:

    1, 21, 31 …    Postoji još 1 takav potez.
    2-4, 22-24 …   Postoje još 2 takva poteza.
    5-20, 25-30 …  Postoji još 5 takvih poteza.
    11-14          idu uz poslednji oblik, iako se završavaju na 1-4

Pravilo je sada na jednom mestu (`lib/core/services/serbian_plural.dart`) i
pokriveno testovima; ekran za izbor završnica je imao svoju kopiju istog
pravila, pa je i ona zamenjena. U tekstu se broj piše ciframa, jer je „jedan"
tačno samo za 1 a ne i za 21.

**Tačka posle cifre je redni broj.** `e6.` na kraju rečenice čitalo se „e šesti".
Rang se zato više ne šalje kao cifra nego kao reč („e šest"), pa nema šta da se
pročita kao redni broj. Isti problem imaju i brojevi koji nisu polja — „Nađeno 3
od 12." — pa se tu tačka posle cifre izbacuje; broj ostaje broj, a gubi se samo
pauza na kraju rečenice. Redosled je bitan: potezi se prevode pre tog pravila,
inače bi i rečenica sa potezom ostala bez tačke.

**Potez usred glagolske konstrukcije.** „Ovako se Qxb2 kažnjava" prolazi u
tekstu a ne prolazi na uho: izgovorena notacija padne usred konstrukcije koju
slušalac još čeka da se dovrši. Sada glasi „Ovako se kažnjava potez Qxb2" —
potez na kraju, iza imenice. Pravilo za dalje: kad rečenicu treba i čuti, potez
ide na kraj, a ne između glagola i njegovog nastavka.

**Tabla se pomerala dok se govori.** Odigravanje partije je išlo dalje ispod
rečenice koja se još čita, pa je slušalac dobijao objašnjenje pozicije koje više
nema na ekranu. Sada oba odigravanja u šetnji preskaču otkucaj dok govor traje.

Uz to ide osigurač: `flutter_tts` javlja kraj izgovora na Androidu, a Windows je
druga implementacija i za nju se ne može jemčiti. Zastavica koja se nikad ne
skine zamrzla bi šetnju zauvek, što je gore od preklopljene rečenice — pa
postoji i rok, izračunat iz dužine rečenice, posle kojeg se nastavlja i bez
potvrde. Kad se to desi, piše u dnevniku.

Spisak glasova se **označava, a ne filtrira**: uz one koji čitaju srpski piše
„čita srpski", ali sme da se izabere bilo koji. Čuti kako engleski glas čita naš
tekst je razumna radoznalost i korisna proba — samo nije za rad, jer notacija i
dalje izlazi kao srpske reči („top de tri"), pročitane tuđom fonetikom.

### Pad na Windows-u: `stop()` pre prvog `speak()`

Ovo je pravi uzrok, nađen 23.8.2026. sondom, i **nije bio ono što sam prvo
mislio**. Hrvatski glas *postoji* na mašini — `Microsoft Matej`, `hr-HR`, u
`Speech_OneCore` — i svi pozivi u plugin rade. Pad je bio u redosledu.

`stop()` u Windows delu `flutter_tts`-a radi ovo:

```cpp
void FlutterTtsPlugin::stop() {
    methodChannel->InvokeMethod("speak.onCancel", NULL);
    if (awaitSpeakCompletion) {
        speakResult->Success(1);
    }
```

a `speakResult` se postavlja **isključivo unutar `speak()`**. Prekid pre nego
što je išta izgovoreno razmotava pokazivač koji nikad nije dobio vrednost:
proces nestaje, bez Dart izuzetka i bez steka, i nijedan `try/catch` tu ne može
da pomogne. Svedeno na tri linije — nov sintetizator,
`awaitSpeakCompletion(true)`, jedan `stop()` — i aplikacija umire.

Pogađalo je dva puta: kad se govor **isključi** u podešavanjima pre nego što je
išta rečeno, i pri **prvoj rečenici** u pokretanju, jer je tadašnji „prekini pa
reci" zvao `stop()` pre `speak()`-a kojem pravi mesta.

Rešeno zaobilaženjem, ne krpljenjem plugina: `stop()` se ne šalje dok bar jedna
rečenica nije izgovorena. Test pada ako se to izgubi.

**Kako je nađeno** — vredi zapisati, jer je prva pretpostavka bila pogrešna i
koštala je jedan krug: privremeni `-t lib/tts_probe.dart` koji zove korak po
korak i štampa pre svakog poziva. Poslednja odštampana linija je poziv koji se
nije vratio. Bez toga se iz „Lost connection to device" ne vidi ništa.

### Kazna je preživela prelazak na sledeću partiju

Prijavljeno 23.8.2026: „zaključala mi se tabla". Nije bio govor, iako je log te
večeri bio pun grešaka iz `flutter_tts`-a — one su prave i zapisane su ispod,
ali sa ovim nemaju veze.

`_loadNext()` u šetnji je resetovao sve: šetnju, kursor, oznake, poruku,
orijentaciju — **osim kazne**. A tabla je živa samo dok kazne nema. Nova partija
se zato otvarala bez trake za kretanje, bez mogućnosti da se figura uzme, i sa
dugmetom „Nazad na partiju" koje pripada poziciji dve partije unazad. Na slici
je to bilo vidljivo: nova partija sa „Greške: 0/2", a kazna se nudi isključivo
na **odgovorenoj** grešci.

Sad postoji jedna metoda za izlazak iz kazne, i zovu je sva tri izlaza —
zatvaranje, skok na grešku i učitavanje nove partije. Test pada bez popravke,
provereno `git stash`-om.

**I druga polovina istog nalaza:** korisnik je rekao „bio sam u modu u kom nije
dozvoljeno pomeranje figura, a to nisam znao". Isti oblik kao ranija prijava o
nemoj tabli — panel sada u kazni piše da se tabla tu ne igra i kako se izlazi.
Mod u kojem si a da to ne znaš ne razlikuje se od kvara.

### Šta `flutter_tts` radi pogrešno na Windows-u

Zapisano jer je nađeno u logu i ostaje tačno, bez obzira što nije bilo uzrok
zaključane table:

```
The 'flutter_tts' channel sent a message from native to Flutter on a
non-platform thread.
Error: Only one of Success, Error, or NotImplemented can be called ...
Ignoring duplicate result.
```

Plugin odgovara dvaput na isti poziv i šalje sa pogrešne niti. Motor to sada
odbaci umesto da padne, ali posledica je da `speak()` na Dart strani ume da
nikad ne dobije odgovor. Zato zastavica „govori se" ne sme da zavisi samo od
njega — rok izračunat iz dužine rečenice je jedino što je pouzdano.

### Tačka posle cifre: dva slučaja, ne jedan

Prvo pravilo je bilo pregrubo. Tačka posle cifre jeste oznaka rednog broja, ali
zato je u „greška je napravljena u 8. potezu" **mora ostati** — bez nje glas
kaže „u osam potezu". Brisati je treba samo tamo gde je kraj rečenice koja se
slučajno završava brojem („Nađeno 3 od 12.").

Razlikuju se po onome što sledi, i to je u srpskom pouzdano: iza rednog broja
ide ostatak rečenice malim slovom, a nova rečenica počinje velikim. Zato tačka
pada samo na kraju teksta ili pred velikim slovom. Potezi ovo pravilo ne dotiču,
jer im je rang do tada već reč.

### Imena linija: golo slovo, ništa ispisano

Linija `g` se čula kao englesko „džej", a ne kao g u „gitara". Glas nije bio
kriv i nije bio engleski — u podešavanjima ništa nije bilo upisano pod
`app_speech_language`, pa je važio automatski izbor i aktivan je bio **hr-HR,
Microsoft Matej**.

Krivo je bilo **naše ispisivanje**. Pisali smo „ge", „be", „ef", a dvoslovni
token taj glas čita po **engleskom** imenu slova — otud „dž" za `g`. Rešenje
nije bio bolji zapis nego nijedan: **jedno slovo po liniji**, jer jednoslovni
token ide kroz glasovnu tablicu imena slova, a hrvatska imena slova su tačno
ono što igrač i kaže — a, be, ce, de, e, ef, ge, ha.

Do toga se stiglo uhom, u tri kruga sonde: prvo šest kandidata za `g` (pobedilo
`gje`), pa pet za `b` (gde se videlo da golo slovo zvuči isto kao najbolji
zapis), pa svih osam kao gola slova — i to je prošlo iz prve, za sve.

Mapa `files` je ostala iako je sada preslikavanje jedan u jedan. Ona je mesto
koje drugi jezik ili drugi glas menja; bez nje bi ta odluka završila kao grana
negde u kodu.

**Postupak za sledeći put**, jer se iz koda ne vidi a ja ga ne mogu čuti:
privremeni `-t lib/tts_probe.dart` koji izgovara kandidate sa brojevima, prvo
samostalno pa u potezu, korisnik kaže broj. Prva stvar koju treba probati je
golo slovo.

### Pravilo koje i pogrešan potez poštuje nije objašnjenje

Nađeno na ekranu 23.8.2026, u istoj kartici, jedno ispod drugog:

> U partiji je odigrano **Qb4+** i remi je izgubljen.
> Tačno — remi je održan. Bio je to jedini potez.
> **Dama mora da ostane na B-liniji.**

`Qb4+` **jeste** na b-liniji. Pozicija je `1Q6/8/6K1/3pq3/3k4/8/8/8 w - - 0 84`
(Da Silva — Gazel Pereira 2010): drži samo `Qb2`, a odigrano je `Qb4+` — oba
poteza ostaju na istoj liniji, pa pravilo ne razdvaja ništa.

Uzrok: `holding_pattern.dart` je tražio šta je zajedničko potezima koji drže, a
onda pokazivao najbolje pravilo **i kad nijedno ne isključuje odigrani potez**.
Poređenje je već umelo da prepozna takvo pravilo (`explainsPlayed`) i da ga
rangira niže, ali ga niko nije odbacivao.

Sad se pravilo koje odigrani potez poštuje ni ne razmatra. Tamo gde greške nema
— rudarene pozicije — sve ostaje kao pre, jer tu nema šta da se protivreči.
Cena je da neke pozicije iz partija ostanu bez rečenice; to je bolje od tačne
rečenice koja na tom mestu čita kao netačna.

### „Ispušta dobitak — ostaje remi" nije uvek istina

Prijavljeno sa ekrana 23.8.2026, u kazni nad Da Silva — Gazel Pereira 2010.
Posle `Kc3` je pisalo „ispušta dobitak — ostaje remi", a pozicija
`8/8/6K1/3pq3/8/2k5/8/1Q6 w` je **dobijena za belog**: `Qa1+` je jedini potez
koji dobija (svi ostali gube), jer kralj na c3 i dama na e5 stoje na istoj
dijagonali, pa šah osvaja damu. Provereno tablicama, ne procenom.

Uzrok je bio prazan: server već šalje pravi ishod (`outcome`: `win`/`draw`/
`loss` iz tablica), a klijent ga nije čitao — za svaki ispušten dobitak je
pisao „ostaje remi". Sada piše „pozicija je sada izgubljena" kad je tako.

Ostala mesta su proverena i **ne tvrde ništa slično**: šetnja i trener kažu šta
je izgubljeno („ispustio dobitak", „izgubio remi"), a to je tvrdnja o poziciji
pre poteza. Razlika je bitna — reći šta je bilo je činjenica iz rudarenja, reći
šta je sada je tvrdnja koja mora doći iz tablica.

### Govor prekida samo korisnik

Traženo 23.8.2026: rečenica koja je počela **čuje se do kraja**. Ništa što
aplikacija radi sama je ne preseca — ni sledeća presuda, ni tabla koja odigrava
potez. Ako nova rečenica stigne u međuvremenu, čeka; čeka **samo poslednja**,
jer starija od dve ionako opisuje tablu koje više nema.

Prekidaju je tri korisnikove radnje, i ništa drugo: dodir trake za kretanje,
odigran potez, i izlazak sa ekrana.

### Prvi pokušaj, koji nije bio uzrok

Ostavljeno zapisano da se ne ponavlja: mislio sam da je krivac glas koji je na
spisku a nije instaliran, pošto `getLanguages` na Windows-u nabraja jezike
instaliranih glasova. Zaštite koje su tada dodate ostaju jer su same po sebi
tačne — poziv ka sintezi koji padne postaje stanje umesto izuzetka, a
`DropdownButton` nikad ne dobija vrednost koje nema u spisku (to **ne** pada na
`hint` nego puca) — ali pad nisu rešile.

### Pad na Windows-u: glas koji je na spisku a nije instaliran

Prijavljeno 23.8.2026: aplikacija je pucala pri **ulasku u Podešavanja**, ako je
za govor bio izabran hrvatski kojeg na računaru nema.

Uzrok je ono što `getLanguages` na Windows-u vraća — **jezike koje sistem
poznaje, a ne glasove koji su instalirani**. Hrvatski je zato bio na spisku,
mogao je da se izabere, a `setLanguage` je na njemu bacio izuzetak. Taj poziv
nije bio u `try`, i to iz asinhronog toka koji niko ne čeka, pa je rušio ceo
program.

Popravljeno na tri mesta, sva tri istog oblika — greška sme da postoji, ali mora
da postane stanje:

- `setLanguage`/`setSpeechRate` su u `try`; kad glas ne radi, stanje postaje
  „nema glasa" i panel već zna da kaže kako se dodaje.
- Sam objekat sinteze se pravi unutar `try`, jer je i to poziv ka platformi.
- `awaitSpeakCompletion` više ne visi nepraćen; ako platforma odbije, ostaje rok
  iz dužine rečenice, koji za to i postoji.

Uz to i jedna zamka Fluttera: `DropdownButton` čija `value` nije među `items`
**ne pada na `hint` nego puca**. Sada se prosleđuje samo vrednost koja je na
spisku.

### Jezik aplikacije je zasebno pitanje

U podešavanjima se bira **jezik govora**, iz spiska koji uređaj stvarno ima.
Jezik same aplikacije nije isto i još ne postoji: svi tekstovi su tvrdo upisani
na srpskom, pa je stari izbornik jezika i uklonjen jer nije radio ništa.
Kad se uradi i18n, `SpeechVocabulary` je već pripremljen da dobije drugi jezik.

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
