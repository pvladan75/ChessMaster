# Stanje rada — nastavak u novoj konverzaciji

Namena: da neko ko dolazi bez istorije razgovora za pet minuta zna gde smo stali
i zašto je nešto urađeno baš tako. Nije prepis dijaloga — prepis troši prostor,
a odluke su ono što se ne može rekonstruisati iz koda.

Poslednje ažuriranje: 25.8.2026. (uveče, usred provera 31–38)

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

### „Nazad na zadatak" sada zaista vraća na zadatak

Prijavljeno 23.8.2026, treći put isti oblik: našao potez, ušao u „Odigraj do
kraja", pogrešio, vratio potez, pritisnuo „Nazad na zadatak" — i **nije mogao da
igra**. Tabla je bila zatvorena s razlogom (pozicija je rešena), a izlaz je bio
dugme „Nađi i ostale (1/3)" koje korisnik nije imao razloga da traži. Njegovim
rečima: „izgleda kao bag, a nije".

Dva odgovora, oba mala:

- **Dugme radi ono što piše.** Ako je rešeno a ima još poteza koji drže, izlazak
  iz vežbe sam nastavlja traženje — isto kao da je „Nađi i ostale" pritisnuto.
  Nerešena pozicija se ne dira: izlazak bez odgovora vraća običan zadatak, ne
  „nađite još jedan".
- **Zatvorena tabla to i kaže.** Naslov više ne glasi „Beli na potezu —
  zadržite dobitak" nad tablom koja ne prima potez, nego „Rešeno — dobitak je
  zadržan", a ispod stoji šta otvara poziciju. Broj preostalih poteza ide kroz
  istu rečenicu koju koristi presuda, pa se padeži slažu bez drugog pravila.

Za sve tri prijave važi isto: tabla je bila u pravu i ćutala je. Kad se negde
uvodi stanje u kojem se ne igra, ono mora da se predstavi.

## Nalaz tablica i zaključivanje remija — 24.8.2026

Traženo pošto se u „Odigraj do kraja" često ne vidi rešenje, a u držanju remija
se ne vidi ni kraj: KRP–KR pređe u KR–KR i onda nema šta da se odigra do kraja.

**Pun nalaz, na zahtev.** Dugme „Nalaz tablica" u vežbi otvara ono što tablice
kažu o poziciji koja stoji pred igračem: ishod, DTZ, i **svaki legalan potez**
sa svojim ishodom, DTZ-om i oznakom da li nulira brojač. Ne jedan preporučen
potez — cela slika, jer je ovde poenta baš u tome da **držanje nije napredak**.
Motor bi dao „najbolji potez"; tablice daju skup onih koji drže i podatak koji
od njih zaista vodi ka matu.

Broji se: čip „Nalaz: n" stoji pored „Greške", jer vežba odigrana sa nalazom
pred sobom nije ista kao ona bez njega. Broji se **otvaranje**, ne osvežavanje —
panel koji se sam drži u toku nije nova upotreba pomoći.

**Gde stoji zavisi od ekrana.** Na Windows-u ide kao poseban panel **ispod info
panela**, u istoj koloni pored table, i **ostaje otvoren dok se igra** — to je i
bio razlog za promenu: prozorčić je morao da se zatvori pre svakog poteza, a
baš tada se gleda. Panel se posle svakog presuđenog poteza sam osvežava, i pri
tome **prvo obriše stari nalaz**: spisak poteza pored table koja je otišla dalje
čitao bi se kao da je o ovoj poziciji. Na telefonu ostaje prozorčić, jer ispod
table nema kolone koju bi zauzeo.

Usput je test uhvatio staru zamku iz `CLAUDE.md`: prozorčić je na 360 dp
prelivao 23 piksela, a red poteza je imao fiksnu širinu za notaciju. Sada se
širina uzima iz ekrana (uz onih 128 piksela koje `AlertDialog` potroši na svoje
margine i razmak), a red se skuplja umesto da seče.

### Potez iz nalaza se može odigrati

Traženo posle prvog korišćenja, i menja čemu nalaz služi: kad potez ispusti
rezultat, umesto „Vrati potez" — što ne nauči ništa — može se **kliknuti potez
iz spiska** i on se odigra na tabli. Tabla ostaje slobodna, pa se odgovori
rukom, pa opet iz spiska, dokle god treba da se vidi **zašto** je potez bio loš.

To je zaseban režim, „Istraživanje", i namerno je odvojen od vežbe:

- potezi se **ne sude** i ne ulaze u brojač grešaka;
- pomera se **bilo koja strana**, jer se kazna igra protivnikovim potezima;
- „Nazad na poziciju" vraća tačno onaj položaj odakle se krenulo.

Panel se pri svakom takvom potezu osvežava, pa se ceo niz prati sa tablicama sa
strane. Na telefonu prozorčić se prvo zatvori pa se potez odigra — inače bi
stajao preko onoga što je tražio da pokaže.

### Šta znače oznake, da se ne meša ponovo

- **WDL** — ishod za stranu na potezu, i nije troje nego petoro: uz `win`,
  `draw`, `loss` idu i `cursed-win` (dobitak koji pravilo 50 poteza pretvara u
  remi) i `blessed-loss` (gubitak koji isto pravilo spasava). Kategorije
  `unknown` i `maybe-win` se **odbijaju**, ne nagađaju.
- **DTZ** — polupotezi do sledećeg uzimanja ili poteza pešaka, **ne do mata**.
  Po njemu se broji pravilo 50 poteza, i zato ga tablice i čuvaju. Skače naviše
  posle nuliranja, pa se napredak ne sme meriti prostim poređenjem preko takvog
  poteza.
- **DTM** — do mata. **Syzygy ga nema uopšte**; dolazi iz drugih tablica i
  Lichess ga vraća samo do pet figura. Namerno se ne traži ni ne prikazuje.
- Uz svaki potez stižu i `zeroing`, `checkmate`, `stalemate`,
  `insufficient_material`.

### Kad je remi gotov

Korisnikovo pravilo, i traži se da **oba** uslova važe istovremeno:

1. **Materijal je jedan od imenovanih mrtvih oblika**: R–R, Q–Q, B–R, N–R,
   minorac protiv minorca, i sve što protiv golog kralja ne može da matira
   (N, B, NN, istobojni lovci). Lista je zatvorena i pisana rukom namerno — to
   su završnice koje igrač prepoznaje po imenu.
2. **Svaki potez koji gubi je grub previd**: nije iznuđen, a gubi figuru odmah
   ili je gubi na fork/nabod u sledećem potezu. Zato provera gleda dva
   protivnikova poteza unapred, a ne samo da li figura visi — `Kc3` u
   Da Silva–Gazel Pereira ništa ne ostavlja da visi i svejedno gubi damu na
   `Qa1+`.

Oba, a ne jedno ili drugo, i to je svesno oprezna strana: zatvoriti remi koji
nije gotov znači oduzeti vežbu, a ostaviti ga otvorenim košta nekoliko poteza.
Iznad svega stoji presuda tablica — oblik sa liste koji tablice zovu dobitkom
jeste dobitak i lista tu nema reč.

Kad su oba ispunjena, dugme „Zaključi remi" zatvara vežbu odmah.

**Kad nisu — ne odbija, nego traži da se odigra.** Korisnikov predlog, i bolji
je od svađe oko pravila: pozicija koja nije dokazano mrtva se ne zatvara na
reč, ali se zato može **pokazati**. Dugme tada imenuje šta još gubi i postavlja
brojač: održi remi još **osam poteza** (četiri sa svake strane) i vežba se
zatvara. Čip „Do remija: n" broji unazad.

Razlika je u tome šta se tvrdi. Zatvaranje po pravilu kaže „ovde nema šta da se
pokvari"; zatvaranje po odigranom kaže „održali ste ga", što je i ono što je
vežba učila. Poruka na kraju zato ne pominje mrtvu poziciju.

Osam je izabrano tako da odbrana koja samo što nije pukla pukne unutar tog
raspona, a da ne bude ono isto vrćenje koje zamenjuje. Broj stoji na jednom
mestu (`holdOutMoves`).

### Ponavljanje nije istek brojača

Usput nađeno: `endOf` je oba remija po pravilu vraćao kao `draw_rule`, pa je
mrtva topovska završnica — koja se ponovi za nekoliko poteza — završavala
porukom „Pedeset poteza bez uzimanja". Sada se razlikuju (`repetition`,
`fifty_moves`) i svaki se imenuje onim što se stvarno desilo.

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

## Sistematizacija prostora — popis napravljen 24.8.2026

Pre nego što se dira navigacija, popisano je zatečeno stanje:
[POPIS-PROSTORA.md](POPIS-PROSTORA.md). Ukratko, odredišta su u tri klase koje
se za korisnika ne razlikuju a ponašaju se različito: **12 sa rutom**, **7 koja
se guraju `MaterialPageRoute`-om**, i **3 koja su samo stanje** unutar
`AiStudioScreen`-a. Jedan ekran (`TacticsTrainerScreen`) otvara se na oba
načina, što je najkraći dokaz da pravilo ne postoji.

Najveća pojedinačna stavka je što je `AiStudioScreen` (2662 linije) istovremeno
raskrsnica i radni ekran — otud i to što tri kartice iz iste liste vode rutom a
tri stanjem.

Odluka o strukturi još nije doneta; pitanja su na kraju popisa.

**O Windows-u je odlučeno da ostane jedna prilagodljiva aplikacija**, a ne
zasebna desktop ljuska: rail i paneli već rade, a prava „Windows aplikacija"
(meni traka, više prozora) udvostručuje površinu koja se ionako menja svake
nedelje. Ono što jeste vredno i jeftino: tastatura (strelice kroz poteze, Esc,
Ctrl+,), pamćenje veličine prozora, desni klik za kopiranje FEN-a, i manje
modalnih prozora u korist panela — poslednje je već urađeno za nalaz tablica.

## Desktop sitnice — 24.8.2026

Tri stvari koje se od prozora očekuju, i sve tri su napravljene tako da važe
svuda umesto ekran po ekran.

**Esc i Ctrl+,** su na nivou cele aplikacije (`DesktopShortcuts`, umotan oko
svega što ruter nacrta), pa ih dobija i ekran napisan sutra. Esc samo
**izlazi** — ponaša se kao dugme „nazad" i na ljusci ne radi ništa, jer tamo
nema šta da se zatvori. Ctrl+, otvara podešavanja i **ne otvara ih dvaput** ako
se prečica drži.

Ruter se prosleđuje izričito, ne traži se po kontekstu: omotač stoji **iznad**
navigatora na koji deluje, pa ga `GoRouter.maybeOf` odatle ne vidi — pritisak bi
prošao bez ikakvog traga. To je tačno onaj oblik tihog neuspeha protiv kojeg je
pola ovog projekta pisano, i test ga hvata.

**Strelice kroz poteze** (`MoveKeyboardShortcuts`) voze **isti kursor** koji
voze i dugmad u traci, pa nema druge istine o tome gde se stoji: levo/desno je
potez, gore/dole su krajevi. Sluša se bez preuzimanja fokusa, pa polje za tekst
zadržava strelice koje su njemu potrebne. Uključeno u šetnji kroz partiju; ostali
ekrani sa istom trakom dobijaju ih jednim omotačem kad se dođe do njih.

**Desni klik na tablu kopira FEN** — jednim potezom oko zajedničkog omotača
table, pa radi na svakom ekranu koji crta tablu, a ne na onom na kojem je dodat.
Na dodirnom ekranu ne smeta, jer sekundarnog dodira nema.

**Ctrl+, nije radio pri prvoj probi** (Esc jeste). Prečice se vezuju za
**logički** taster — ono što raspored kaže da taster daje — a na srpskom
rasporedu taster pored M ne mora da preda Flutteru zarez kad je Ctrl pritisnut.
Prečica je tada vezana za taster koji niko ne može da pritisne, i to na
najtiši mogući način: ništa se ne desi i ništa se ne zapiše.

Sada je vezana i za **fizički** taster, isti na svakom rasporedu. Uz to se svaki
pritisak sa Ctrl-om koji nije obrađen upiše u dnevnik (`[Prečice] Ctrl +
logički … / fizički …`), pa sledeći ovakav slučaj traje jedan pritisak umesto
jednog nagađanja.

**Pamćenje veličine prozora nije urađeno.** Traži nativni dodatak
(`window_manager`), a posle iskustva sa `flutter_tts`-om i `nuget`-om to je
odluka koja se donosi svesno, ne usput.

## Odakle nastaviti — stanje na kraju 24.8.2026

Prvo pročitaj ovaj odeljak, pa `POPIS-PROSTORA.md` ako je posao oko navigacije.

### Šta je urađeno u poslednjem krugu

**Govor (TTS)** — čita poruke iz info panela, notaciju prevodi u reči, prekida
ga samo korisnik. Radi na Androidu i na Windows-u (hrvatski glas `Matej`).

**Trener završnica** — nalaz tablica na zahtev, zaključivanje remija po dva
uslova ili odigravanjem osam poteza, igranje poteza iz nalaza kao istraživanje.

**Baza otvaranja bez tokena** — upit ide na `GET /opening-explorer` našeg
backenda, koji drži jedan Lichess token i pamti odgovore. Korisniku token
više nije potreban; lični, ako ga neko unese, i dalje pretekne naš i ide
pravo na Lichess. ChessDB ostaje kao izbor i kao mreža kad Lichess ne
odgovori — panel tada pređe na njega, a dnevnik kaže zbog čega.

**Sud o potezu** — `GET /opening-judge` odgovara šta je jedan potez u
otvaranju: *glavna teorija*, *praktična alternativa*, *sumnjiv potez* — ili
*nije presuđeno*. Panel u Analizi to pokazuje na zahtev. Ovo je prvi i
najmanji deo trenažera repertoara, i vredi sam za sebe. Odluke iza njega su
u odeljku „Sudija: šta je odlučeno i zašto".

**Navigacija** — četiri koraka, sva četiri gotova i puširana:
mreža testova → raskrsnica izdvojena iz `AiStudioScreen`-a → šest ruta za granu
zadataka → četiri taba, prvi je Trening.

### Sudija: šta je odlučeno i zašto

Urađeno i **provereno uživo** 24.8.2026 (stavka 27 u
[TODO-provera.md](TODO-provera.md)) — uključujući onu proveru koja jedina ne bi
ličila na grešku: loš potez odigran crnim piše da gubi. Sedam odluka koje treba
znati pre nego što se na ovome dalje zida.

**Sud se računa na serveru, nikad u aplikaciji.** Motor na telefonu odgovara sa
one dubine do koje je stigao pre nego što je dete kliknulo dalje, pa bi isti
potez bio „igriv" danas i „greška" sutra na sporijem uređaju. To je oblik kvara
koji ovaj projekat stalno plaća: rezultat koji izgleda izračunato, a zapravo je
pogodak. Lichess-ova oblačna ocena je jedan fiksan broj po poziciji, isti za
sve, keširan i gore i kod nas.

**Troši se korisnikov token, ne naš.** Suđenje jednog poteza košta do četiri
upita gore, a token servera je jedno grlo za svu decu — prvi ko prošeta dužu
varijantu ostavio bi ostale bez baze otvaranja. Zato ruta traži lični token u
zaglavlju `X-Lichess-Token`, ne pamti ga i ne piše ga u dnevnik, a ko ga nema
dobija rečenicu i put do Podešavanja umesto tihe usluge sa zajedničke kvote.
Ograda stoji na dva mesta, na ruti i u aplikaciji, da se do rute uopšte ne
dođe bez tokena.

**Ocena se meri kao *gubitak*, ne kao apsolutna vrednost.** Ovo je jedina
izmena u odnosu na prvobitnu skicu (`repertoire_trainer_spec.md`, prag
-0.40). Gambit koji je i pre poteza stajao na -0.3 nije greška; pitanje je da
li je potez nešto *dao*, a to je razlika. Praktična alternativa mora da prođe
oba uslova: `MAX_LOSS_CP = 40` i `MIN_EVAL_CP = -100` — potez koji ne gubi
ništa zato što nema šta da izgubi nije igriv ni u kom korisnom smislu.

**Knjige pretiču motor.** Potez koji majstori igraju (`MIN_MASTER_GAMES = 10`)
je teorija i kad ga oblak ima desetinku lošijim od prvog izbora. Uz to štedi
tri upita: kad je odgovor iz knjige, motor se i ne pita.

**„Nije presuđeno" je četvrti ishod, a ne blaža greška.** Kad oblak nikad nije
ocenio poziciju, ruta to kaže i panel to kaže drugom bojom. Nepresuđen potez
prikazan kao greška je tačno onaj oblik tihog kvara zbog kog je pisano sve
gore.

**Crvena presuda nosi i lek i kaznu.** Uz „gubi 4.20 pešaka" idu i „bolje je
bilo Nf3" i „kažnjava se sa Qh4 Nf3 Qxe4+". Obe linije stižu unutar ocena koje
su ionako plaćene, pa ne koštaju nijedan dodatni upit. Ista pouka koju je
trener završnica platio: broj bez poteza ne uči ništa.

**Limiti se poštuju na tri načina, i nijedan nije nagađanje.** Lichess daje
anonimnom pozivaocu oko 1 upit u sekundi, a onome sa tokenom 15–20; Explorer
rute su računske, pa traže 100–200 ms razmaka između uzastopnih upita; a
prekoračenje (429) blokira **adresu** na minut, i duže — do sat vremena — ako
se kucanje nastavi. Zato: token uvek ide u `Authorization`; sve što izlazi iz
sudije prolazi kroz jedan red sa razmakom od `MIN_REQUEST_GAP_MS = 150` ms, pa
četiri upita jednog suđenja nisu nalet; i posle 429 se `RATE_LIMIT_COOLDOWN_MS
= 60 s` ne šalje **ništa**, nego se čeka ovde. To poslednje je važnije nego što
izgleda: ovaj server ima jednu adresu za svu decu, pa je ponovno pitanje u
blokadi ono što jedan izgubljen minut pretvara u izgubljen sat.

Isto važi i za bazu otvaranja, od 24.8.2026: pravilo je izdvojeno u
`lichessPacing.js` i koriste ga oba servisa, jer je drugi primerak jednog
limita druga prilika da bude pogrešan — a pogrešan je nevidljiv, pošto prebrzo
radi sve dok jednog dana ne prestane. Tamo je i važnije nego kod sudije: token
koji se troši u bazi je serverov, pa bi blokada koju zaradi jedno dete zatvorila
bazu otvaranja svima.

**Lichess-ova oblačna ocena je iz ugla belog.** `mate: -8` sa crnim na potezu
znači da se *beli* matira. Provereno pozivom na živi API, a ne pročitano, jer
je znak jedina stvar ovde koju čitanje ne hvata: sve presude bi bile pogrešne,
dosledno, i to samo za jednu boju. Test to drži (`opening_judge_service.test.js`,
„a black move is judged from black's side").

Isti nalaz je otkrio i **grešku u onlajn motoru, popravljenu 24.8.2026**:
`stockfish_service_native.dart` je obrtao znak oblačne ocene za svaku poziciju
sa crnim na potezu, pa su se sve takve ocene prikazivale naopako — i to samo za
jednu boju, što je oblik kvara koji preživi sto pogleda. Za nativni UCI motor
to obrtanje **ostaje**, jer UCI računa iz ugla onoga ko je na potezu; dve
konvencije, dva izvora. Formatiranje oblačne ocene je zato izdvojeno u
`lib/services/cloud_eval_format.dart`, gde konvencija piše jednom, sa vrednostima
iz živog API-ja u testu (`cloud_eval_format_test.dart`).

### Repertoar: režim izgradnje

Urađeno 24.8.2026, **nije viđeno uživo** (stavka 29 u
[TODO-provera.md](TODO-provera.md)). Korisnikova zamisao, sa četiri odluke koje
je potvrdio i koje su ugrađene tako da se ne mogu zaobići.

**Čvor je pozicija, ne potez u nizu.** Ključ je prva četiri polja FEN-a, isti
oblik koji stablo u Analizi koristi za transpozicije. Zato je i čuvanje **jedan
graf po korisniku i po boji**, a `repertoires` je samo *ime za početnu
poziciju*. Time se dobija tačno ono što je traženo: rad iz Smit-More je već deo
kasnijeg, šireg repertoara protiv 1.e4 čim taj repertoar dođe do iste table —
bez spajanja i bez mogućnosti da ista pozicija nosi dva odgovora zavisno od
toga na koja se vrata ušlo.

**Jedan glavni potez po poziciji, ostalo su alternative.** Tri ravnopravna
odgovora se ne mogu uvežbavati: sve je tačno, pa se ništa ne nauči preko toga
da se svaki put mora stati i misliti. Pravilo drži **baza** (parcijalni
jedinstveni indeks), ne ekran; brisanje glavnog unapređuje najstariju
alternativu, jer čvor sa potezima a bez glavnog je čvor koji drill ne ume da
pita.

**Odgovori protivnika staju na udelu, ne na broju koji neko izabere.** Server
pokriva ono što igra 80% partija u izabranoj traci, najviše četiri poteza, i
uvek kaže koliko je ostalo napolju. Rep se ne baca nego se broji — to je tačno
skup poteza koje će drill jednog dana odigrati, a učenik na njih neće imati
odgovor. Bez tog praga pozicija nema kraj, jer je grananje 3–8 po nivou.

**Sudi se automatski, uz brojač.** U ovom režimu je suđenje poenta poteza, pa
se ne čeka dugme; ali u uglu stoji koliko je upita ka Lichessu sesija potrošila,
jer je to korisnikova kvota. Sve ide kroz isti keš i isti red kao sudija:
odgovori protivnika i presuda o potezu čitaju **istu** knjigu za istu poziciju,
pa druga stvar ne košta ništa.

**Peto, što nije bilo u planu, a ispalo je najvrednije:** `repertoire_attempts`
pamti i **odbijene** pokušaje. Repertoar beleži šta je učenik odlučio; samo ta
tabela beleži za čim je prvo posegnuo i šta je sud o tome rekao. To su pozicije
u kojima je instinkt pogrešan, i to je ono što drill treba da pita prvo — inače
je „učenje na svojim greškama" anegdota, a ne raspored.

**Pravljenje repertoara ide preko table, ne preko FEN-a.** Prva verzija je
tražila FEN u polju za tekst, i to je pala na prvom korisniku: nalepio je deo
niza i dobio „Nije sačuvano — ili je ime zauzeto, ili server ne odgovara", što
je jedna rečenica za tri različita uzroka. Sada je to ekran na kom se otvaranje
**odigra na tabli** (sa „Nazad" i „Ispočetka"), a FEN je sporedni izlaz za
poziciju koju je brže nalepiti nego odigrati. Uz to, boja i pozicija su jedna
odluka: dugme „Napravi" je živo samo dok je na potezu strana za koju se gradi,
pa greška „gradite za belog a crni je na potezu" više ne može ni da nastane.

**Knjiga se otvara sama, čim se potez odigra.** Traženo pri prvoj upotrebi, i
tačno: bez spiska kandidata čovek ne bira nego pogađa, a presuda o jednom potezu
kaže da li je taj potez zdrav — ne i da li je pored njega stajao bolji. Pravilo
je zato o *trenutku*, ne o tome da li se knjiga vidi: skrivena dok se učenik
odlučuje, besplatna čim se opredelio. Spisak nosi i procenat partija i procenat
učinka za stranu na potezu (istorija, ne ocena, i tako i piše), zvezdicu na
potezima koji su već uzeti i strelicu na onom koji je upravo predložen. Dugme
„Ne znam" je ostalo za zavirivanje **pre** odluke i jedino ono upisuje da je
pozicija rešena gledanjem.

**Glavni potez se bira, i to sada piše.** Izbor je oduvek postojao — dodir na
čip ga je postavljao — ali nigde nije stajalo da postoji, a kontrola koju niko
ne vidi ne postoji. Sada su to redovi sa zvezdicom, uz rečenicu „Zvezdica je
glavni potez — to će drill tražiti od vas. Dodirnite drugi potez da on postane
glavni."

**Rokada je pisana dvojako, i to je tiho lomilo tri stvari.** Lichess piše
rokadu kao „kralj uzima top" (`e1h1`, `e8h8`, potvrđeno pozivom na živi
cloud-eval 25.8.2026: `d2d3 d7d6 e1h1 a7a5 f1e1 e8h8 …`), a tabla u ovoj
aplikaciji piše `e1g1`. Posledice se nisu prijavljivale kao greška nego kao
ništa: potez iz knjige koji je rokada nije mogao da se odigra, pa ga je svako
ko pokuša tiho ispuštao — protivnik u drillu nikad ne rokira, sledeći talas u
izgradnji ostane bez grane, a u panelu Analize klik na „O-O" ne uradi ništa.
Nađeno je tek kad je korisnik video spisak u kom red piše „O-O", a rečenica
ispod tvrdi da tog poteza nema u spisku.

Prevod stoji na granici, u `openingMoveNotation.js`, i ide **preko SAN-a** a ne
preko pravila o poljima — biblioteka već ume da pročita SAN, a ručno pravilo za
rokadu je još jedna stvar koju treba pogoditi. Koriste ga oba servisa koja
čitaju knjigu (sudija i baza otvaranja), pa je aplikacija nizvodno ne vidi.
Uz to, `opening_replies` se sada **zamenjuje** za poziciju umesto da se dopunjuje:
spajanje bi ostavilo jučerašnje `e1h1` redove pored današnjih ispravnih, zauvek
u izvlačenju.

**Motor pomaže pri izboru, na zahtev.** Traženo pri prvoj upotrebi: „Pitaj
motor" pušta **lokalni** Stockfish na tekuću poziciju, sa dubinom i brojem
linija koji se biraju tu, u panelu — i to su iste postavke koje koristi i tabla
za analizu, ne druga kopija koju niko ne bi našao. Ne troši nijedan Lichess
upit. Pita se jednom (`analyzePositionSync`) umesto da stoji upaljen: ovo je
razgovor o jednoj poziciji, a motor koji radi u pozadini greje telefon zbog
pitanja koje još niko nije postavio. Klik na liniju **odigra njen prvi potez
kao korisnikov predlog** — dakle kroz isti sud i istu odluku uzmi/odbaci, jer
predlog nije odluka.

**Odgovor pripada poziciji za koju je tražen.** Nađeno pri prvoj upotrebi
motora, sa slikom kao dokazom: motor je nudio `Bxb2` u poziciji u kojoj tog
uzimanja nema, jer je taj potez bio moguć jednu poziciju ranije. Pretraga na
dubini 28 traje sekundama, korisnik u međuvremenu ode dalje, i odgovor stigne
za tablu koju niko više ne gleda. Isto važi za knjigu i za presudu, pa sada sve
tri provere da li je pozicija na ekranu i dalje ona o kojoj su pitale — isti
onaj čuvar koji trener završnica ima uz nalaz tablica (`_readoutFen`) i analiza
uz presuđeni čvor. Zapisan je i razlog, jer ovo je treći put da se ista greška
pojavi u trećem obliku.

**Promena dubine je novo pitanje.** Prijavljeno kao „motor staje da radi": nije
stajao, nego se ništa nije ponovo pokrenulo, pa je stari odgovor ostajao na
ekranu ispod novog broja — što je iz korisnikove stolice ista stvar. Sada
promena dubine ili broja linija odmah ponovo pita. Panel ostaje otvoren i kad
motor ne vrati ništa, jer je to trenutak kad čovek najviše želi dugme za drugu
dubinu.

**Otvaranje se bira po imenu.** Pretraga ECO baze je već postojala u Analizi,
kao jedna od pet kartica u dijalogu za postavljanje table; izdvojena je u
`OpeningPicker` i sada je koriste oba mesta — jedna implementacija, dvoja vrata.
Ko hoće repertoar za Smit-Moru sada ga **imenuje** umesto da ga sricanjem
odigra: linija, pozicija i predloženo ime stižu zajedno, a strana za koju se
gradi je ona koja je na potezu na kraju te linije. Potez iz knjige koji tabla
odbije **zaustavlja** prepisivanje umesto da bude preskočen — pola tiho
učitane linije je pozicija koju niko nije tražio, sa imenom one koju jeste.

**Ime se predlaže iz ECO baze.** Aplikacija već nosi 3810 imenovanih linija, pa
polje samo ponudi „Sicilian Defense — crni" i dovoljno je pritisnuti „Napravi".
Pamti se poslednje ime kroz koje je linija prošla, jer repertoar obično zađe
dublje nego što knjiga ima ime; čim korisnik nešto otkuca, predlog prestaje da
ga ispravlja.

Usput je jedan test otkrio zamku koja bi se inače vukla: **učitavanje ECO baze
ne završava unutar `testWidgets`**, jer ide kroz `compute()`, a izolat u tom
okruženju nikad ne odgovori — jedan `await` na to je držao ceo krug dok ga
vreme nije pokosilo na deset minuta. Zato ekran prima izvor imena spolja
(`nameFor`), pa test nikad ne poseže za pravom bazom.

Ista pouka je stigla i drugi put, u suprotnom smeru: pozicija je bila ispravna,
red ispod table zelen, a dugme „Napravi" sivo — jer ime nije bilo upisano, što
nigde nije pisalo. Sada svako ugašeno dugme na tom ekranu ima svoj razlog
odštampan tu gde se gleda (`_whyNot`), a kolona je ograničena na 560 px, pošto
je na desktopu polje za ime bilo razvučeno preko celog prozora, metar od table
kojoj pripada.

I sama poruka o neuspehu je popravljena na istom mestu gde je i nastala:
`_send` sada vraća **razlog**, a ne samo `null`. Zauzeto ime, ugašen backend i
odbijena pozicija su tri različite stvari — jednu čovek popravlja u polju pred
sobom, drugu u terminalu, a treća nije njegova krivica.

Šta **nije** urađeno, namerno: drilla još nema (sledeći korak, kroz postojeći
`spacedRepetitionService.js`), radara pokrivenosti nema (poslednji je, najlepši
i najmanje uči), a red pozicija u kom se radi ne preživljava zatvaranje ekrana —
sačuvano je ono što je izabrano, ne dokle se stiglo.

### Repertoar: drill

Urađeno 24.8.2026, **nije viđeno uživo** (stavka 30 u
[TODO-provera.md](TODO-provera.md)). Zatvara krug koji je korisnik zamislio:
gradi → vežba → drill podmetne nepokriven potez → vraća se u izgradnju.

**Algoritam se ne ponavlja.** Raspored ide kroz `schedule()` iz
`spacedRepetitionService.js`, isti SM-2 koji vozi domaći. Ono što je novo je
samo *skladište*, `repertoire_reviews`, i to je svesna odluka a ne propust:
stavka domaćeg je (lekcija, korak) i čita se spajanjem sa lekcijom, a stavka
repertoara je (boja, pozicija) i ne spaja se ni sa čim. Širenje postojeće
tabele značilo bi `lesson_id` koji sme da bude prazan, granu u svakom upitu nad
njom i migraciju nad funkcijom koja je već proverena uživo — a učenik od toga
ne bi dobio ništa.

**Drill ne košta ništa.** Nijedan upit ka Lichessu se ne šalje: šta protivnik
igra dolazi iz `opening_replies`, knjige koju je izgradnja već platila. Ko je
potrošio kvotu, ili nikad nije ni imao token, i dalje vežba sve što je
izgradio. Redovi su o poziciji i traci rejtinga, nikad o čoveku, pa gradnja
jednog deteta čini drill sledećem besplatnim.

**Ne pita se učenik kako je znao.** U drillu je odgovor objektivan — to je
njegova sopstvena odluka, zapisana — pa se ocena izvodi: setio se je prolaz,
morao je da pogleda je slabiji prolaz, sve ostalo je pad. **I dobar potez koji
nije njegov je pad**, jer drill pita za odluku, ne za šahovsku ispravnost; kad
bi se primalo sve što je zdravo, raspored ne bi značio ništa jer bi sve uvek
bilo tačno.

**Pitanje ne nosi svoj odgovor.** `GET /repertoire/drill/next` vraća poziciju i
ništa više; „Pokaži" je zaseban poziv, pa je gledanje radnja koju raspored vidi.

**Drillu je dozvoljeno da iznenadi.** Protivnikov potez se izvlači težinski po
učestalosti, a nepokriveni potezi su u izvlačenju namerno. Pozicija koju učenik
nije pripremio nije kvar nego jedina stvar koju knjiga ne ume — pokazuje mu ivicu
onoga što je pokrio — i vodi pravo u izgradnju te iste pozicije.

### Roditeljska saglasnost: tekst je potvrđen, tok nije napisan

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

### Rizik koji nije u tekstu saglasnosti nego u obliku aplikacije

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

### Odlučeno 25.8.2026, radi se sutra

1. **Soba dobija spisak zvanica.** Ulaz samo za tvorca sobe i za prihvaćenu
   vezu (ili izričito pozvanog); gost samo ako trener to uključi; glas samo za
   člana sobe. Uz to kod iz kriptografskog izvora i ograničenje pokušaja, jer
   šest cifara iz `Math.random()` nije brava.
2. **Email izlazi iz spiskova.** `GET /friends`, spiskovi učenika i trenera
   vraćaju ime i javni identifikator. Email tamo ništa ne rešava, a jeste
   podatak o detetu.
3. **Maloletnik se povezuje samo sa prihvaćenim trenerom.** Odrasli zadržavaju
   prijatelje, ali uz obavezan pristanak druge strane (`pending → accepted`,
   isti obrazac koji veza trener–učenik već ima). Time aplikacija prestaje da
   bude mesto gde se deca povezuju međusobno, a odrasli ne gube ništa.
4. ~~**Tok roditeljske saglasnosti**~~ — urađeno 25.8.2026, zajedno sa age
   gate-om koji ga uslovljava. Odeljci „Age gate: aplikacija sada pita za
   godinu" i „Roditeljska saglasnost: tok je napisan".
5. **Play Console deklaracije poslednje** — ono što se tamo prijavi mora da
   opisuje aplikaciju kakva jeste tog dana, a ne kakva će biti.

Uz to jedna korekcija tuđe preporuke koju ne treba ponoviti: granica godina ne
ide globalno na 18. GDPR ide najviše do 16, pa 18 dodaje trenje bez pravne
koristi — najstroža *primenljiva* je 16, uz spuštanje po državi.

Ovo nije pravni savet i ne zamenjuje advokata; ovde je zapisano samo šta
aplikacija stvarno jeste, da bi pitanje njemu moglo da bude precizno.

### Soba je dobila spisak zvanica, i grupe

Urađeno 25.8.2026, **nije viđeno uživo** (stavka 31 u
[TODO-provera.md](TODO-provera.md)). Prva dva koraka iz odluke od istog dana.

**Pravilo: soba je mesto sa spiskom zvanica, a ne niz koji otvara vrata.** Kod
i dalje služi da učenik imenuje sobu u koju ulazi, ali više ne ovlašćuje nikoga.
Odluka je izdvojena u `roomAccess.mayJoinRoom` i oba socket ulaza je zovu —
`joinGame` i `audio_join`. Glas se pita zasebno, iako je već prošao proveru za
tablu, jer je glas ono što završi u snimku dece i dva puta do iste sobe ne smeju
da se raziđu.

Redosled: tvorac sobe; pa **spisak zvanica ako postoji**; pa prihvaćena veza sa
tvorcem; pa poziv na zakazani čas sa tim kodom; pa gost, i to samo ako soba
prima goste (`rooms.allow_guests`, podrazumevano `FALSE` — podrazumevana
vrednost je ono što odlučuje šta se dešava u sobi o kojoj niko nije mislio).

**Grupe učenika**, tražene sa jasnim razlogom: sa četrdeset učenika, pozivanje
istih osam svakog utorka znači svaki put ići niz spisak i tražiti ih. Grupa je
taj spisak, imenovan jednom (`student_groups`, `student_group_members`). Na
spisku zvanica sobe (`room_guests`) stoje **i grupe i pojedinci**, jer je
traženo oboje, a nema razloga za dva mehanizma.

Dve stvari koje spisak drži poštenim:

* **Prazan spisak znači ono što je soba oduvek značila** — svi prihvaćeni
  učenici tvorca. Prvi red ga sužava, jer „pozovi grupu" mora da znači *samo*
  ta grupa.
* **Članstvo u grupi nije pravo.** Uz spisak se svaki put proverava i prihvaćena
  veza, pa red u grupi koji je ostao za nekim ko više nije učenik nije ključ.

Uz to: kod sobe se sada pravi iz `crypto.randomInt` umesto iz `Math.random()`.
Nije više brava — spisak jeste — ali brava koja to nije ne treba ni da izgleda
tako.

**Email je izašao iz spiskova.** `GET /friends`, spisak učenika i spisak trenera
vraćaju ime i identifikator, ne adresu; u aplikaciji je ono što je stajalo pod
imenom zamenjeno onim što red zaista jeste („Čeka potvrdu", „Vaš učenik").
Polje za *pozivanje* po adresi ostaje — pozivaš nekoga čiju adresu već znaš —
ali tuđa adresa više ne putuje kroz liste, a većina ljudi u tim listama su deca.

**Ekrani su napisani 25.8.2026.** „Ljudi" ima dugme *Grupe učenika* (samo za
onoga ko nekoga uči — grupa je spisak *tvojih* učenika), gde se grupe prave,
preimenuju, brišu i pune; u sobi trener ima *Ko sme u sobu*, gde se pozivaju
cele grupe i pojedinci. Dijalog kaže naglas šta spisak radi: prazan znači „svi
moji učenici", a prvi red sužava sobu na spisak. Tiho sužavanje toga ko sme
unutra bilo bi ista vrsta iznenađenja kao kontrola koja radi dok joj je dugme
sakriveno.

Ekran nudi samo **prihvaćene** učenike. Server to ionako odbija, ali ekran koji
ponudi ono što će server odbiti pravi grešku koja izgleda kao njegova.

Usput nađena i popravljena greška koju je test izvukao: `TextEditingController`
napravljen oko `showDialog` i obrisan čim se dijalog zatvori umire dok se
dijalog još animira, pa se polje jedan kadar kasnije crta nad mrtvim
kontrolerom. Isti obrazac je bio napisan istog dana i u repertoaru („Nalepi
FEN"); oba dijaloga sada drže svoj kontroler koliko i sami traju.

Šta **nije** urađeno: age gate i tok roditeljske saglasnosti.

### Prekidač „soba prima goste"

Urađeno 25.8.2026, **nije viđeno uživo** (stavka 32 u
[TODO-provera.md](TODO-provera.md)).

`rooms.allow_guests` je postojala od prvog dana spiska zvanica i odlučivala je
ko ulazi, ali je u aplikaciji nije bilo nigde. Pravilo koje niko ne vidi je
pravilo na koje niko ne može da se osloni — pa je prekidač sad u dijalogu „Ko
sme u sobu", ispod spiska, sa rutama `GET`/`PATCH /rooms/:kod/guest-access`
koje pripadaju samo tvorcu sobe.

Uz to je ispravljena jedna nesimetrija koja se videla tek kad se prekidač
izvuče na ekran: `allow_guests` se pitalo **samo za neprijavljenog** posetioca.
Naopako — stranac koji se odjavi je mogao da gleda sobu koja prima goste, a
roditelj sa nalogom nije. Sad su vrata za goste **poslednja** i za sve isto:
ko ne prođe ni kao tvorac, ni sa spiska, ni preko prihvaćene veze, ni preko
poziva na čas — ulazi kao gost ako soba prima goste, i nikako drugačije.

Zbog toga su spisak i prekidač **namerno nezavisni**: spisak bira ko je u sobi
*učenik*, prekidač da li iko sme da *gleda*. Dijalog to kaže naglas dok je
prekidač uključen („ulazi i svako ko zna kod, bez obzira na spisak"), jer bi
prekidač koji ćutke prestane da važi čim se pozove jedna grupa bio ista vrsta
iznenađenja kao kontrola koja radi dok joj je dugme sakriveno.

Tri stanja, ne dva: uključeno, isključeno i **ne zna se**. Odgovor koji nije
stigao se ne crta kao „isključeno" — to je tačno onaj oblik greške koji ovaj
projekat stalno plaća, korak koji tiho preskoči i jedan sloj iznad prijavi
uspeh, a ovde bi lagao o tome ko sme u sobu sa decom. Isto i pri upisu: posle
neuspelog `PATCH`-a se stanje **ponovo pita**, a odgovor se čita iz
`RETURNING`, ne iz onoga što je poslato.

Usput: `ownsRoom` je bio napisan u `studentGroups.js`, a trebao je i ovde —
sad stoji na jednom mestu (`roomAccess.js`), po istom pravilu zbog kojeg
`acceptedTrainersOf` postoji: tri prepisana primerka istog uslova su sva tri
zaboravila `status`.

### Maloletnik ima samo trenera

Urađeno 25.8.2026, **nije viđeno uživo** (stavka 33 u
[TODO-provera.md](TODO-provera.md)). Treća stavka iz odluke od istog dana.

**Pravilo je jedno i staje u rečenicu: maloletnik je nečiji učenik, nikad
nečiji trener.** Odatle sledi i ono što je traženo — dvoje dece ne mogu da se
povežu, jer bi jedno od njih moralo da bude trener. Živi u
`ageService.mayRelate`, a pitaju ga oba mesta koja prave vezu:
`requestRelationship` (pred sam upis reda) i `respondToRequest` (pred
prihvatanje). Drugo mesto nije višak: **svaki zahtev koji danas postoji je
poslat dok niko nije rekao koliko ima godina.**

**Godine su izjava, ne dokaz**, i zato ništa što stvarno štiti dete ne sme da
zavisi od tog broja — kod nas i ne zavisi: spisak zvanica i saglasnost po
treneru drže bez obzira na to šta je upisano. Uzrast bira kojim tokom neko ide,
ne koliko je bezbedan.

Nova kolona je `users.birth_year` (uz `birth_year_stated_at`) — **godina, ne
datum**: odgovara na jedino pitanje koje joj se postavlja, a jedno je polje
manje o detetu. Unutar godine rođendana je dvosmislena za jednu, pa
`statedAge` uzima **mlađe** čitanje: ko je rođen 2010. računa se kao 15 kroz
celu 2026, i posle rođendana. Greši u pravcu pitanja roditelja, a to je pravac
u kom treba grešiti.

Prag je konfiguracija (`AGE_OF_CONSENT`, podrazumevano 16), jer je broj odluka
po državi. Van 13–18 server **ne startuje** umesto da se vrati na podrazumevano:
prag koji tiho preskoči je pravilo o deci koje tiho prestane da važi.

**Pošteno ograničenje, zapisano unapred:** dok niko nije rekao godine, ovo
pravilo ne odbija nikoga. Zubi stižu sa age gate-om koji puni `birth_year` — a
taj gate mora da pita i **postojeće** naloge, ne samo nove, inače pravilo ostaje
komentar. To je tačno oblik greške koji ovaj projekat stalno plaća.

**Prijatelji su ukinuti kao mehanizam.** `POST /friends/add` je primao email,
nalazio korisnika i upisivao vezu **u oba smera, bez ijednog pristanka**; `GET
/friends` je onda vraćao spisak. Bila je to jedina rupa u modelu pristanka koji
je svuda drugde poštovan. Nije mu dodat tok saglasnosti nego je izbačen, jer se
pokazalo da **nijedan ekran u aplikaciji nikad nije ni zvao tu rutu** — tab
„Ljudi" crta trenere i učenike, a `_addFriend`/`_removeFriend` u
`home_screen.dart` su bili mrtav kod. Otišli su zajedno sa rutama (i sa `DELETE
/friends/:id`).

Red u `friends` sada ima tačno jedno poreklo: prihvaćenu vezu trener–učenik,
koja ga i briše kad se raskine. Time je svaka veza u aplikaciji nešto na šta su
obe strane pristale. Test čita izvor i pada ako se `INSERT INTO friends` pojavi
igde osim u `relationshipService.js` — isti obrazac kao za `acceptedTrainersOf`,
jer je i ovde otkaz nevidljiv u ponašanju.

**Usput nađena i zatvorena rupa u sobi, veća od prijatelja.** Spisak zvanica
propušta i onoga ko je pozvan na *zakazan čas* sa tim kodom sobe — poziv jeste
pristanak. Ali `POST /sessions/schedule` je primao **bilo koji kod sobe** i
**bilo koje id-jeve**, pa je stranac mogao da zakaže čas na tuđem kodu, pozove
sam sebe i uđe u sobu držeći pozivnicu koju je sam sebi izdao. Sad se pita i
`s.host_id`: pozivnica je pristanak samo ako dolazi od onoga čija je soba. Uz
to, ruta odbija zakazivanje u tuđoj sobi i preskače pozivanje onoga ko nije
prihvatio vezu — dve brave na istim vratima, namerno.

Isto i `POST /invitations/send`: primao je spisak id-jeva i slao obaveštenje
kome god, a većina id-jeva u ovoj aplikaciji su deca. Sad ide samo prihvaćenoj
vezi, i kaže naglas kad deo spiska nije prošao.

### Glas ima nivo, i nivo je u tokenu

Urađeno 25.8.2026, **nije viđeno uživo** (stavka 34 u
[TODO-provera.md](TODO-provera.md)). Nije bilo u planu tog dana; ušlo je zato
što je predloženo *postepeno poverenje* — dete sluša trenera i odgovara
dugmadima, a mikrofon dobija kasnije — a provera je pokazala da mesto na kom bi
se to sprovodilo stoji otvoreno.

**Šta je zatečeno.** `POST /agora/token` je izdavao `PUBLISHER` token **svakom
prijavljenom korisniku za bilo koje ime kanala**, bez ijedne provere — a ime
kanala je kod sobe. Spisak zvanica je čuvao `joinGame` i `audio_join`; glas je
išao pored njih. Ko ima nalog i kod sobe: uzme token, uđe u Agora kanal, čuje se
na času i **ne pojavi se na spisku učesnika**. Ako trener snima, taj glas je u
snimku. To je bila rupa veća od one zbog koje je spisak zvanica i pravljen.

Uz to, „trener je utišao učenike" nije bila kontrola nego molba: `isMuted` je
polje u mapi na serveru, a stvarno utišavanje je `muteLocalAudioStream` —
odluka klijenta. Klijent koji ne posluša, ne posluša.

**Šta je sada.** Pravo se odlučuje na serveru i **postaje uloga u tokenu**:

* `maySpeakInRoom` odgovara na dva pitanja odjednom — sme li unutra (isti
  `mayJoinRoom` kao i do sad) i sme li da se čuje. Tvorac sobe: da. Gost: ne —
  gost je došao da gleda, a njegov glas bi završio u `uploads/` pored dečjih.
  Učenik: prema `trainer_students.voice_level`.
* Token je `SUBSCRIBER` za onoga ko sluša. Mikrofon isključen zato što se
  aplikacija sama utišala je isključen dok neko ne zameni aplikaciju;
  pretplatnički token ne može da objavi zvuk bez obzira na to ko ga drži.
* Aplikacija **ne traži dozvolu za mikrofon** onome ko sluša. Dete koje samo
  sluša nikad ne vidi taj dijalog.
* Dugme „Uključi mikrofon" se slušaocu **ne crta**. Zasvetlelo bi, spisak bi
  rekao da govori, i niko ga ne bi čuo.

**Nivo stoji na vezi, ne na nalogu**, jer je tamo istinit: isto dete može da
sluša kod novog trenera i govori kod onog kod koga je dve godine. Podrazumevano
je `'talk'` — da nijedna postojeća veza ne bi ućutala od migracije — ali novi
red se **upisuje izričito**: za učenika za koga se zna da je maloletan to je
`'listen'`. Isti obrazac kao `status`, iz istog razloga.

Trener daje i oduzima mikrofon (`PATCH /trainer/students/:id/voice`), a učeniku
koji je u sobi se javi da se ponovo priključi kanalu — jer uloga živi u tokenu,
a token se izdaje pri ulasku. Da toga nema, „oduzmi mikrofon" bi značilo „od
sledećeg časa".

**Brzi odgovori.** Da / Ne / Nisam razumeo, i potezi na tabli. To je ono što
čini da slušanje bude čas a ne prenos: trener pita da li je jasno i dobija
odgovor, a da nijedan dečji glas nije objavljen ni snimljen. Tri vrednosti i
ništa više — slobodan tekst bi bio polje za poruke između deteta i svih u sobi,
tačno ono što ova aplikacija dva dana odlučuje da ne bude. **Ime pošiljaoca
uzima se sa socket-a, ne iz poruke**: ko sebe imenuje, može da imenuje i
drugoga.

**Šta ovo ne rešava.** Bez uključenog Agora App Certificate-a uloga u tokenu je
savet, jer svako sa App ID-jem ulazi u kanal kako hoće. Server to i kaže u
odgovoru. Uključivanje sertifikata nije bilo nigde u
[TODO-objavljivanje.md](TODO-objavljivanje.md) — sad jeste.

### Backend na `master` nije mogao da se pokrene

Nađeno 25.8.2026, popravljeno istog dana.

U `audio_join` su stajala **dva `const seat` u istom bloku** — jedno iz provere
spiska zvanica, drugo za red u spisku učesnika. To je `SyntaxError` pre nego što
ijedna linija krene: `node server.js` je odmah padao. Stanje je bilo
komitovano.

Zašto niko nije primetio: `npm test` nikad ne učitava `server.js`, a dva testa
koja ga *gledaju* čitaju ga **kao tekst** i traže ime funkcije u njemu. Oba su
prolazila nad fajlom koji se ne može ni raščlaniti. To je isti oblik greške koji
CLAUDE.md već nabraja četiri puta, samo pomeren jedan sloj naviše: provera koja
preskoči baš ono što izgleda da proverava.

Sad postoji `test/sources_compile.test.js`: svaki `.js` fajl servera se
kompajlira (`vm.Script`, bez izvršavanja — jer bi `require` otvorio bazu i
zauzeo port). Uz njega ide i test koji proverava da je `server.js` uopšte u
obilasku, pošto bi obilazak koji ga tiho ne nađe padao na potpuno isti način.

Vredi zapisati i kako je zamalo otišlo naopako: prva provera da nova zaštita
radi vratila je staru grešku u **pogrešnu funkciju**, test je prošao, i zaključak
je bio „`vm.Script` ne hvata grešku u telu funkcije, treba `node --check` po
fajlu". Netačno — `vm.Script` je hvata; proba je bila loša. Da se zaključak
zadržao, u kodu bi stajao komentar koji objašnjava pogrešnu stvar i test tri
sekunde sporiji od potrebnog.

### Uzrast i saglasnost: šta znamo o korisniku (ništa) i kako to popraviti

Zapisano 25.8.2026, pre nego što se počne. Polazna činjenica: **aplikacija danas
ne zna koliko korisnik ima godina.** `users` ima email, ime, lozinku,
`is_verified` i `account_type` — ni datum rođenja, ni roditelja. Google prijava
tu ne pomaže: vraća email, ime i `sub`, a **ne vraća godine niti email
roditelja**, ni za naloge pod Family Link nadzorom. Prijava dokazuje da je
sanduče njegovo; sve ostalo je na nama.

**Dve saglasnosti, ne jedna.** Ovo je jedino mesto gde se opšti savet („nalog
stoji zaključan dok roditelj ne potvrdi") sudara sa onim što ovde već postoji, i
odgovor je da su potrebne obe:

* **Na nalogu** — sme li ovo dete uopšte da koristi interaktivni deo aplikacije.
  Za to trebaju nove kolone na `users`: datum rođenja (ili godina), `parent_email`,
  `parent_consent_at/ip/version`, i status naloga.
* **Na vezi** — sme li *ovaj* trener da uči moje dete, da mu vidi domaći i da ga
  snima. Za to kolone već postoje, na `trainer_students`, zajedno sa statusom
  `awaiting_parent`. To nije duplikat: prva odgovara na „sme li dete ovde", druga
  na „sme li baš on".

**Gde se to sprovodi — tri mesta, sva tri već postoje.** `mayJoinRoom` je jedina
vrata u sobu i u glas, pa maloletnik bez saglasnosti tamo dobija isto odbijanje
kao i stranac. Prihvatanje veze ide kroz `respondToRequest`. Povezivanje sa
drugim korisnicima je ionako odlučeno: maloletnik ima samo trenera.

**Tri stvari koje savet ne kaže, a važne su:**

1. **Uzrast je izjava, ne dokaz.** Dete može da upiše bilo šta. Zato ništa što
   štiti dete ne sme da *zavisi* od tačnosti tog broja — a kod nas i ne zavisi:
   spisak zvanica i saglasnost po treneru drže bez obzira na to šta je upisano.
   Age gate određuje koji tok ide, ne koliko je neko bezbedan.
2. **Potvrda mejlom je slaba potvrda.** Za mlađe od 13 u SAD (COPPA) „email
   plus" se prihvata samo za internu upotrebu, a ovde postoji snimanje glasa
   koje trener dobija — to je otkrivanje. Dok je distribucija sužena na jednu
   državu, pitanje je odloženo; pri širenju se postavlja advokatu izričito.
3. **Family Link nalog treba probati uživo pre objave.** Google ume da traži
   odobrenje roditelja na roditeljskom uređaju pre nego što uopšte izda token,
   i to je tok koji niko od nas nije video.

Redosled ostaje: ekrani za grupe i zvanice → maloletnik samo sa trenerom → age
gate i tok saglasnosti → Play deklaracije.

### Age gate: aplikacija sada pita za godinu

Urađeno 25.8.2026, **nije viđeno uživo** (stavka 35 u
[TODO-provera.md](TODO-provera.md)). Ovim dva pravila napisana istog dana
prestaju da budu komentar: „maloletnik nije trener" i „dete kreće od slušanja"
oba čitaju `users.birth_year`, koji je do sada bio prazan u **svakom** redu.

**Pitanje stoji iznad cele aplikacije, ne na kraju registracije.** To je jedina
odluka u ovom delu koja je mogla da se pogreši tiho, i pogrešila bi se upravo
onako kako ovaj projekat stalno greši: kroz formu za registraciju ne prolazi
skoro niko od postojećih naloga, a Google prijava pravi nalog ne prolazeći kroz
nju uopšte. Pravilo bi izgledalo napisano i važilo bi ni za koga. Zato `AgeGate`
umotava `MaterialApp.builder`, a pita ga jedno mesto — promena u
`SessionService`, kroz koju prolaze i forma, i Google, i zapamćen token pri
pokretanju.

**Tri stanja, opet, i to je isti oblik kao kod prekidača za goste:** upisana
godina, nalog koji **niko nikad nije pitao**, i **odgovor koji nije stigao**.
Poslednje nije nijedno od prva dva. Da su spojeni, ugašen backend bi zaključao
sve naloge (ako se ćutanje čita kao „nije pitan"), ili bi propustio tačno one
zbog kojih gate postoji (ako se čita kao „punoletan"). Klijent zato ne postavlja
pitanje dok server ne kaže `ageKnown: false`, a sve što stvarno štiti dete
sprovodi se ionako na serveru.

**Godina, ne datum**, iz istog razloga kao u koloni: jedno polje manje o detetu,
a odgovara na jedino pitanje koje joj se postavlja. Prag koji ekran ispisuje
dolazi **sa servera** (`ageOfConsent`), jer bi broj prepisan u Dart bio drugi
broj koji sme da se ne slaže sa prvim.

**Neuspeo upis ne zatvara pitanje.** Zatvaranje bi izgledalo identično uspehu i
ostavilo nalog tačno u stanju zbog kog gate postoji. Provera godine je izvučena
u `ageService.parseStatedYear` i testirana bez baze — ruta je samo poziva —
pošto je to jedino mesto koje je moglo da propusti vrednost koju `statedAge`
kasnije čita kao **nikakvu godinu**: nalog se tiho vraća u stanje „niko ga nije
pitao", a ekran je rekao da je sačuvano. Test prolazi kroz sve godine 1900–2026
i traži da se dve polovine slažu.

**Dva izlaza, oba obavezna.** Na samom pitanju stoji *Odjavi se*, jer nalog na
koji se greškom ušlo ne sme da bude ćorsokak; a u Podešavanjima je red **NALOG →
Godina rođenja**, jer ko otkuca 2017 umesto 1997 ne sme da ostane zaključan u
polju do kog više ne može. Ispravka ide kroz isti ekran, sa *Odustani* umesto
*Odjavi se*.

**Šta ovo namerno ne radi, i zašto je pitanje za korisnika.** Godina se čita
**pri sklapanju veze** i **pri prihvatanju**, a ne unazad. Nalog koji danas ima
tri prihvaćene veze i `voice_level = 'talk'`, pa tek sad kaže da ima jedanaest
godina, ostaje tamo gde jeste. Isto i veza u kojoj je „trener" maloletan.
Retroaktivno prevođenje bi utišalo decu usred kursa bez reči treneru, a
neprevođenje ostavlja rupu koju je gate baš otkrio. Odluka je zapisana u
[PITANJA-ZA-ODLUKU.md](PITANJA-ZA-ODLUKU.md) umesto da bude odabrana usput.

Šta i dalje **nije** urađeno: sam tok roditeljske saglasnosti. `GET /me/standing`
već prijavljuje `parentConsent.given: false`, jer je to iskren odgovor i
aplikacija mora da ume da ga izgovori — ali kolone `parent_consent_*` i dalje
puni niko.

### Roditeljska saglasnost: tok je napisan

Urađeno 25.8.2026, **nije viđeno uživo** (stavka 36 u
[TODO-provera.md](TODO-provera.md)). Četvrta stavka iz odluke od istog dana, i
prva koja je čekala **odluku korisnika**, a ne kod.

**Odlučeno 25.8.2026: roditelj potvrđuje preko linka u mejlu, na stranici koju
servira backend.** Razlog je zapis: `parent_consent_at`, `parent_consent_ip` i
`parent_consent_version` su tri kolone koje pošteno može da popuni samo stranica
koju je roditelj stvarno otvorio. Kod pročitan detetu dokazuje da je mejl
stigao, ne da je iko pročitao tekst — a saglasnost koja ne ume da kaže **na šta**
je data nije zapis.

**Pravilo je jedna rečenica: veza maloletnika sa trenerom ne počinje kad se njih
dvoje dogovore, nego kad roditelj kaže.** Kad obe strane prihvate, red ide u
`awaiting_parent` — stanje koje kolona `status` dopušta otkad je napisana i koje
do danas nije popunio niko. Ništa što prihvaćena veza otključava (domaći,
izveštaji, soba, mikrofon) nije dostupno iz tog stanja, i **red u `friends` se
ne pravi**. Zato `respondToRequest` godinu čita **pre** upisa: red koji je jednu
naredbu bio `accepted` pa ispravljen jeste `accepted` za svako čitanje koje se
desi u međuvremenu.

**Tekst na stranici je onaj potvrđen 25.8.2026**, sa tri stavke iz
[saglasnost-roditelja.md](saglasnost-roditelja.md); treća, snimanje, je opciona i
živi u novoj koloni `trainer_students.parent_allows_recording`. I tamo su **tri
stanja, ne dva**: `NULL` znači da niko nije pitan, i ne sme da se čita kao „ne"
ništa više nego kao „da" — svaka veza koja danas postoji je `NULL`, a čitanje
kao odbijanje bi ugasilo snimanje na četrdeset kurseva u toku.

**Verzija teksta je konfiguracija** (`PARENT_CONSENT_VERSION`, podrazumevano
`rs-2026-08-25`) i **prepisuje se na zahtev** kad se zahtev napravi, a ne čita
ponovo kad roditelj odgovori: roditelj pristaje na tekst koji mu je pokazan.
Država je deo oznake namerno — advokat je potvrdio za Srbiju i to izričito
rekao, pa bi `2026-08-25` samo po sebi ne bi umelo da kaže **koji** je tekst
pročitan.

**Token je token, a ne ime.** 32 bajta iz `crypto.randomBytes`, čuva se
**heširan**, jednokratan je i ističe za 14 dana. Original nikom ne treba nazad —
roditelj ga ima u mejlu — pa bi čuvanje značilo samo da je procureo backup gomila
radnih linkova u dosijee dece. Jednokratnost sprovodi **upis**, ne provera: dva
klika na isti link pola sekunde razmaka oba prođu proveru, a računa se jedan.

**Adresa roditelja se traži od deteta, ne od trenera**, jer je to detetov nalog:
pismo poslato na adresu koju je trener zapamtio sa telefona je jedini otkaz u
ovom toku koji izgleda identično uspehu. Kad se adresa unese, server **odmah
šalje sve što je na nju čekalo** — inače bi veza zaglavljena na
`awaiting_parent` ostala tamo zauvek sa popunjenom adresom i nikim upitanim.

**Stranica je jedina u projektu koja nije za aplikaciju.** Otvara je roditelj
bez naloga, na bilo kom uređaju. Zato: nema prijave i token je cela brava; sve
je ugrađeno u jednu stranicu (bez stilova, skripti i fontova sa mreže, jer
nepoznat mail klijent na nepoznatoj mreži ume da prikaže praznu stranu); i svako
ime se ekranizuje, pošto su i ime deteta i ime trenera ono što je neko ukucao u
formu za registraciju. Tri odbijanja se ne stapaju u „link nije ispravan": ne
postoji, istekao je i već je odgovoreno traže tri različita poteza od onoga ko
čita.

**Odbijanje se upisuje** (`granted = false`, sa vremenom) i ne briše ništa.
Zahtev koji bi se obrisao sam izgledao bi identično onom koji nikad nije ni
poslat.

**Šta ovo namerno nije.** Nalog maloletnika **nije zaključan** dok roditelj ne
potvrdi. Potvrđen tekst je po obliku obrazac **po treneru** — u njemu stoji
„Podaci o treneru" — pa saglasnost visi o vezi, a prva data saglasnost usput
popunjava i kolone na nalogu (`users.parent_consent_*`, kroz `COALESCE`, dakle
jednom). Dete bez ijednog trenera koristi aplikaciju kao i do sada. Ako se
odluči da i to treba zaključati, to je zaseban posao i zaseban tekst.

**Zatečene veze se ne diraju — odlučeno 25.8.2026.** Kad dete upiše godinu po
kojoj je maloletno, `POST /me/age` **javi svakom njegovom treneru** i ne menja
ništa: ni status veze, ni `voice_level`. Mehanizam koji bi ćutke prepisao tuđa
prava na osnovu broja koji je dete upravo otkucalo bio bi gori od rupe koju
zatvara, a ćutanje bi značilo da trener i dalje snima dete čija je godina tek
izgovorena. Zato treći put isto pravilo: **javi, ne menjaj.**

**Novo u `.env`:** `PUBLIC_BASE_URL` (odakle je server dostupan spolja, bez
kose crte na kraju) i `PARENT_CONSENT_VERSION`. Prvi sme da bude prazan i tad
veza i dalje stane na `awaiting_parent`, a API kaže da pismo nije poslato;
**polovična vrednost obara server**, jer bi pokvaren link našao tek roditelj
koji je već zaključio da aplikacija ne radi.

### Saglasnost za snimanje se sada i sprovodi

Urađeno 25.8.2026, **nije viđeno uživo** (stavka 37 u
[TODO-provera.md](TODO-provera.md)). Ovo je popravka rupe iz istog dana, ne nova
mogućnost.

**Šta je bilo.** `parent_allows_recording` je od prvog sata pošteno punila
roditeljska stranica — i **niko je nije čitao**. `grep` je nalazio tačno dva
mesta: migraciju koja kolonu pravi i upis koji je postavlja. Roditelj je mogao
da odbije snimanje, a snimanje bi radilo. To je peti put isti oblik: pravilo
zapisano, pravilo koje se ne sprovodi — i sam
[saglasnost-roditelja.md](saglasnost-roditelja.md) to kaže naglas („Druga
stavka je važnija od prve — ona pretvara pravilo iz obećanja u nešto što sistem
stvarno sprovodi").

**Pravilo: čas se ne snima dok je u sobi dete čiji roditelj to nije dozvolio.**
Ne „ne bi trebalo" — `uploads/` je jedina stvar u projektu koja se ne može
reprodukovati ni anonimizovati.

Tri odluke koje ga oblikuju:

* **Blokira samo *izjavljen* maloletnik.** Nalog za čiju godinu niko nije pitao
  ne blokira ništa — isto grandfathering-ovanje koje su dobili `status` i
  `voice_level`. Odbijanje na praznoj koloni bi ugasilo snimanje u celoj
  aplikaciji na osnovu polja koje je sat vremena ranije bilo prazno.
* **`NULL` i `false` oba blokiraju, i razlikuju se.** Kad se zna da je dete
  dete, „roditelj je rekao ne" i „roditelja niko nije pitao" su isti odgovor na
  „smem li da snimam" i različiti odgovori na „šta sad" — prvo je odluka koju
  poštuješ, drugo pismo koje nije poslato. Poruka treneru ih zato razdvaja i
  **imenuje decu**: „ne" bez imena je nešto sa čim trener ne može ništa.
* **Zabraniti novo snimanje nije isto što i prepisati zatečeno.** Odluka od
  25.8.2026 je bila *javi, ne menjaj* — godina koja stigne kasnije ne ućutkuje
  dete i ne raskida vezu. To je pravilo o stanju na koje se neko već oslanja.
  Ovo je radnja koja se **još nije desila**, i odbiti je ne oduzima nikome
  ništa.

**Dve brave na istim vratima, namerno.** `recording_status_update` odbija
**pokretanje** (server pita svoj spisak članova sobe, ne klijentov), a
`POST /recordings/save` odbija **upis** — jer klijent koji nikad ništa ne javi
i dalje može da stigne sa gotovim fajlom, a to je trenutak kad glas deteta ulazi
u `uploads/`. Odbijen fajl se briše sa diska: multer ga je već zapisao, pa bi
ostavljanje značilo tačno ono što se sprečava.

**Ko je bio na času pamti server**, ne klijent (`realtime.recordedRoster`) —
upis stiže davno pošto su svi otišli, kad je spisak članova prazan, pa bi
provera bila provera nad nikim. Pauza dodaje u spisak umesto da ga počne iznova.
**Iskrena granica, zapisana a ne prećutana:** spisak živi u memoriji, pa backend
restartovan usred časa zaboravi — tada upis **prolazi** (odbijanje bi uništilo
pravi čas zbog tuđeg restarta) i **kaže da provera nije mogla da se izvrši**.
„Nije provereno" i „prošlo je" su dva stanja koja ovaj projekat stalno spaja u
jedno.

**Dete se ne izbacuje sa časa.** Kad uđe u sobu u kojoj snimanje traje, snimanje
se **zaustavlja**, a dete ostaje — potvrđen tekst kaže da se čas ne sme snimati,
ne da dete ne sme da prisustvuje. Ono što je snimljeno pre njegovog dolaska
ostaje, jer njega u tome nema.

**Dugme kaže zašto je ugašeno.** Server šalje `recording_consent` svaki put kad
se promeni spisak članova — jedini trenutak kad odgovor može da se promeni — pa
aplikacija crta ugašeno dugme sa razlogom ispod njega, umesto dugmeta koje
pukne kad se pritisne. To je savet; brava je i dalje na serveru.

**Odbijen snimak prestaje da se nudi.** Snimci se prvo čuvaju lokalno pa
sinhronizuju u pozadini; posle 403 se red označava (`syncRefused`) i više se ne
šalje. Ostaje na trenerovom uređaju — njegov je — ali na server ne ide, i razlog
je zapisan uz njega.

**Test čita izvor i pada ako kolona ponovo postane samo zapis.** Isti obrazac
kao za `INSERT INTO friends` i `acceptedTrainersOf`, iz istog razloga: otkaz je
nevidljiv u ponašanju — sve i dalje radi, samo odgovor roditelja prestane da
znači išta. Provereno mutacijom: kad se čitanje ukloni, tri testa padaju.

**Šta ovde nema testa:** ekran sobe. `chess_game_screen.dart` je tri hiljade
linija vođenih socket-om i dugme se ne da izolovati bez posla većeg od same
popravke — pa je to jedino što pokriva samo živa proba.

### Pitanje je pokrivalo ekran, ali ne i tastaturu

Nađeno uživo 25.8.2026, popravljeno istog dana. Prva otkucana godina je ostajala
u polju zauvek — koliko god se kucalo, vrednost se nije menjala.

**Pokriti ekran i izvaditi ga iz fokusnog stabla su dve različite stvari, a
samo prva je besplatna.** Neprozirni sloj na vrhu `Stack`-a zaustavlja dodire;
prelazak fokusa mirno stiže do brata u istom `Stack`-u koga niko ne vidi. Ispod
gate-a stoji **cela živa aplikacija**, sa svojim poljima i svojim `autofocus`-om
— pa je kadar posle pojave pitanja uzela fokus nazad, i svaki sledeći taster je
odlazio ekranu koji se ne vidi. Polje je izgledalo zamrznuto na onome što je
ukucano do tog trenutka.

Popravka: `ExcludeFocus` oko onoga što je ispod (i `FocusScope` oko samog
pitanja), pa dok gate stoji ništa ispod ne može da drži tastaturu ni kad
izričito traži. Test pita baš tako — `requestFocus()` na čvoru ispod pa provera
da ga nije dobio — i provereno mutacijom: bez `ExcludeFocus`-a pada.

Uz to: polje se pri dobijanju fokusa **selektuje celo**. Četiri cifre iza
ograničenja dužine su polje koje, kad se napuni, tiho ignoriše kucanje — a to se
čita kao polje koje ne može da se promeni, što je tačno ono što je i prijavljeno.

Pouka koja važi šire, jer će se ovaj oblik ponoviti: **sve što se crta preko
aplikacije umesto kroz `Navigator` mora samo da preuzme i dodire i fokus.**
Dijalozi to dobiju besplatno, jer idu kroz `Overlay`; ručno naslagan sloj ne.

### Baza je ispražnjena pred proveru — 25.8.2026

Odluka korisnika, i dobra: provere 31–37 su o pravilima koja važe **od trenutka
kad se veza napravi**, a sve što je u bazi stajalo napravljeno je pre nego što su
ta pravila postojala. Provera nad zatečenim redovima bi merila grandfathering, ne
pravilo. Zato se nalozi prave iznova i proverava se ono što će stvarno postojati
kad aplikacija izađe.

**Obrisano je tačno ono što su nalozi napravili** — `TRUNCATE users RESTART
IDENTITY CASCADE` dohvata 28 tabela, i pre brisanja je izračunato zatvaranje
stranih ključeva da se vidi šta tačno pada. Zatečeno: 5 naloga, 2 prihvaćene
veze, 16 snimaka, 93 sobe, 198 sopstvenih zagonetki, 10 lekcija, 8 zadataka.

**Uvezeni skupovi su ostali netaknuti**, jer nijedan nema strani ključ ka
`users`: `lichess_puzzles` (50.000), `endgame_puzzles` (15.100), `blunder_games`
(9.581), `opening_replies` (271), `puzzles`. To je i bio uslov — uvoz se meri
satima, nalozi minutima.

**Snimci su obrisani i sa diska**, uz izričitu potvrdu. `uploads/` je jedino
mesto u projektu koje se ne može reprodukovati, pa je postupak bio: prvo
premestiti van repozitorijuma, pa obrisati tek kad je potvrđeno — a nikako
brisati iz koda. Pravilo iz `CLAUDE.md` ostaje netaknuto: **nijedan kod ovog
projekta ne briše `uploads/`**; ovo je bila ručna radnja nad sopstvenim probnim
časovima.

Pre brisanja je uzet `pg_dump` cele baze. Stoji van repozitorijuma i **ne ide u
njega** — sadrži naloge i heševe lozinki.

**Dve stvari koje posle ovoga treba znati:**

* **Admin se dodeljuje ručno.** Nema `ADMIN_EMAIL` niti bilo kakvog bootstrap-a:
  jedini put je `UPDATE users SET role = 'admin' WHERE email = ...` nad novim
  nalogom. Bez toga rute koje traže admina (dodela paketa, merenje troška) nemaju
  ko da pozove.
* **Identifikatori kreću od 1**, jer je `RESTART IDENTITY`. Sve što je negde
  zapisano sa starim `id`-jem — a to su samo beleške u ovim dokumentima — više ne
  pokazuje ni na šta.

### Token je nadživeo nalog — nađeno i popravljeno 25.8.2026

Nađeno slučajno, čim je baza ispražnjena: aplikacija se povezala i prijavila
prisustvo kao `pavle (ID: 5)` — nalog koji je minut ranije obrisan.

**Token je potpisana ceduljica, ne red u bazi.** `jwt.verify` dokazuje da je
ovaj server izdao token i da nije istekao; o nalogu koji token *imenuje* ne
kaže ništa, a niko drugi nije pitao. Rok tokena je **7 dana**, pa je obrisan
nalog zadržavao radnu prijavu nedelju dana.

Dva razloga zbog kojih to nije bila samo neobičnost tog popodneva:

* **Politika privatnosti obećava brisanje.** Roditelj sme da traži da nalog
  nestane, i tekst kaže da nestaje. Prijava koja posle toga radi još nedelju
  dana je to obećanje neispunjeno — isti oblik kao kolona saglasnosti koja se
  upisuje a ne čita.
* **Identifikatori se ponovo dodeljuju.** `RESTART IDENTITY` vraća brojač na 1,
  pa je peti nalog napravljen posle pražnjenja **stvarno** ID 5 — i stara
  ceduljica postaje ispravna prijava za drugu osobu. To nije zastarela sesija
  nego tuđ nalog.

**Popravka:** `services/accountGuard.js` odgovara na jedno pitanje —
postoji li još red iza ovog tokena — i **tri odgovora, ne dva**: postoji,
obrisan je (`401 account-gone`), i **nije moglo da se pita** (`503
unverifiable`). Treće nije drugo: baza koja načas ne odgovara ne sme da se čita
kao „vaš nalog je obrisan", jer je odgovor klijenta na to da baci sesiju. Sva
tri ulaza to zovu: `authenticateToken`, `optionalAuth` i nov
`authenticateSocket`.

**Usput, besplatno:** uloga se od sada čita **iz reda**, ne iz tokena. Uloga je
tvrdnja zamrznuta pri prijavi, pa je oduzet admin važio do isteka tokena — ista
greška, jedno polje dalje. Red se ionako čita.

**Cena:** jedan pogodak po primarnom ključu na svaki prijavljen zahtev. Keš bi
je vratio tako što bi ponovo otvorio baš ovaj prozor, samo kraći.

**Klijent, usko:** `account-gone` je dobio svoje stanje (`ServerStatus.gone`) i
briše zapamćenu sesiju. Istek tokena **namerno ne radi to isto** — to je širi
posao (svaki zahtev u aplikaciji bi morao negde da usmeri svoj 401) i vodi se
kao zasebna otvorena stavka („Istekao token ne odjavljuje korisnika"). Uraditi
pola toga ovde, pod tuđim imenom, tačno je način da popravka izgleda gotova.

**Provereno protiv živog servera, ne samo testom:** potpisan token za nepostojeći
nalog → `401 account-gone`; bez tokena → 401; izmišljen potpis → 403; a na
socket-u redom `connect_error`, gost prolazi, izmišljen potpis pada.

### Test koji nije proveravao ono što piše — isti dan, isti oblik

Vredi zapisati odvojeno, jer je greška bila **u testu**, ne u kodu, i prošla bi
neprimećeno.

Prva verzija zaštite je čitala izvor `middleware/auth.js` i tražila poziv
`tokenHolderStanding` u **fiksnih 1600 znakova** od početka svake funkcije. Kod
kratkih funkcija taj odsečak iscuri u susednu — pa kad se provera ukloni iz
`authenticateToken`, poklopi se ona u `optionalAuth` i test i dalje prolazi.
Zaštita je zelena nad kodom u kom je rupa ponovo otvorena.

Otkriveno **mutacijom**: provera je uklonjena namerno, test je i dalje prolazio.
Sada se telo funkcije vadi brojanjem vitičastih zagrada, obe mutacije obaraju
test, a uz njega stoji i test **te funkcije** — dve funkcije, marker u drugoj,
i čitanje prve ne sme da ga nađe.

Pouka za svaki sledeći test koji čita izvor: **odsečak po broju znakova nije
granica funkcije**, i svaka takva zaštita mora da se proba mutacijom pre nego
što se poveruje da radi. `CLAUDE.md` već nabraja dva testa koji su čitali
`server.js` kao tekst i prolazili nad fajlom koji se ne može ni raščlaniti; ovo
je treći iz iste porodice.

### Stranica se otvarala, a dugme nije radilo — nađeno uživo 25.8.2026

Prva prava proba roditeljske saglasnosti: pismo je stiglo, stranica se otvorila
besprekorno, a „Dajem saglasnost" je vratilo `{"error":"Origin not allowed"}`.

**Uzrok.** CORS ograda u `server.js` je pisana kad je backend služio **samo JSON
API nativnim klijentima**. Android i Windows ne šalju `Origin`, pa je svaki
zahtev koji ga nosi po definiciji bio tuđa stranica — i odbijanje svega van
`ALLOWED_ORIGINS` bilo je tačno. Onda je stigla roditeljska stranica: jedna HTML
strana koju servira **ovaj isti server** i čija forma šalje **samoj sebi**. Njen
`Origin` nije bio na spisku.

**Zašto se nije videlo ranije.** Pregledač na običnu navigaciju **ne šalje**
`Origin`, a na slanje forme ga **šalje**. Zato je otvaranje stranice prolazilo, a
padalo je samo dugme — i to jedino dugme zbog kog stranica postoji. Roditelj bi
video obrazac za saglasnost koji odbija da zabeleži saglasnost.

**Pravilo koje je nedostajalo:** *zahtev sa sopstvenog porekla nije unakrsni
zahtev.* Spisak dozvoljenih porekala postoji da drži **druge** napolju;
same-origin je slučaj o kom nikad nije ni trebalo da presuđuje. Odluka je
izdvojena u `services/corsPolicy.js` i ima **četiri** odgovora umesto tačno/
netačno — `no-origin`, `allowed`, `same-origin`, `blocked` — jer je spajanje ta
četiri u dva i bilo ono što je pojelo srednji slučaj.

Poređenje ide po `Host` zaglavlju samog zahteva, ne po nečemu iz konfiguracije:
to je ono što je pregledač stvarno tražio, pa ostaje tačno iza proksija, na LAN
adresi i posle promene domena. Test pokriva i klasičan promašaj u ovakvoj
proveri — `api.example.com.evil.rs` ne sme da prođe kao „isti host".

**Provereno protiv živog servera**, sa izmišljenim tokenom da se pravi zahtev ne
potroši: slanje sa same stranice → 200, slanje sa tuđeg porekla → i dalje 403.

Zapaziti i **kako je ovo nađeno**: nijedan test nije mogao. Ovo je greška na
spoju servera i pregledača, u kodu koji je do juče bio tačan, i vidi se tek kad
neko pritisne dugme na pravom uređaju. Isto važi za sve iz `TODO-provera.md`.

### Poruka koja obori radnju — nađeno uživo 25.8.2026

Prijava je bila: *„kad učenik 1 uđe, snimanje se ne prekida"*. Uzrok je bio moj,
i to najstariji obrazac u ovom projektu.

```dart
if (isRecording) {
  ScaffoldMessenger.of(context).showSnackBar(...);   // pukne ovde
  unawaited(_stopRecording());                        // nikad se ne izvrši
}
```

`showSnackBar` baci *„Looking up a deactivated widget's ancestor is unsafe"* kad
je `ScaffoldMessenger` koji nađe i sam deaktiviran — a to se u sobi dešava stalno,
jer socket poruka stigne dok se ekran zatvara. Izuzetak obori ceo rukovalac, i
snimanje deteta čiji je roditelj snimanje **odbio** nastavi da radi.

**Isti oblik kao prva greška u ovom dokumentu:** „Pozivi ka audio plejeru stajali
su ispred kreiranja tajmera reprodukcije, pa bi greška zvuka oborila ceo
`_play()`." Pravilo je bilo zapisano i svejedno prekršeno.

**Pravilo, sada i u kodu:** *radnja pre poruke, i poruka ne sme da može da obori
radnju.* `AppFeedback` je dobio `_show` koji hvata izuzetak i loguje ga —
`context.mounted` nije dovoljno, jer nije kontekst taj koji je mrtav nego
messenger. Sva četiri mesta u lancu snimanja idu kroz njega, a `_stopRecording`
je pomeren **ispred** poruke.

**Šire — urađeno 25.8.2026:** svih **82** poziva `ScaffoldMessenger.of(...)` u
`lib/`, u 23 fajla, prebačeno je na `AppFeedback`. Prevod je namerno doslovan
(`AppFeedback.show`, ista boja, isto trajanje, isto dugme): poenta je da poziv
ne može da obori ono što javlja, a ne da sve poruke odjednom izgledaju drugačije
— najmanje usred provere uživo. U `lib/` više nema nijednog `ScaffoldMessenger`
ni `showSnackBar` van `AppFeedback`.

**I sama ograda je imala istu rupu.** `AppFeedback.error(context, ...)` je
pravio `SnackBar` **pre** nego što uđe u `_show`, a u tom `SnackBar`-u stoji
`context.colors` — što je `Theme.of(context)`, dakle **isto ono traženje pretka**
koje puca na zatvorenom ekranu. Ograda je proveravala `mounted` i hvatala
izuzetak tek posle mesta na kome se puca. Ista rečenica koju ovaj dokument već
nosi na drugom mestu: *ograda napisana za grešku nije čuvala*. Sad `_show` prima
**graditelja** (`SnackBar Function()`) i gradi ga unutra, iza provere i iza
`try`-a.

**Dokazano mutacijom**, jer se izvorno-čitajućem testu ovde ne veruje na reč.
Tri mutacije, sve tri uhvaćene:

| mutacija | test koji padne |
|---|---|
| ručni `ScaffoldMessenger.of(context)` vraćen u jedan ekran | *no file reaches for ScaffoldMessenger itself* |
| messenger uhvaćen u lokalnu promenljivu, pa `messenger.showSnackBar(...)` | *no file calls showSnackBar directly* |
| `_show` ponovo gradi `SnackBar` pre provere (stari kod) | *a popped screen does not throw* — baci baš „Looking up a deactivated widget's ancestor is unsafe" |

Test je `test/app_feedback_guard_test.dart` (7 testova): tri čitaju izvor `lib/`,
četiri puštaju `AppFeedback` kroz kontekste koje soba stvarno pravi — ekran koji
je zatvoren, drvo bez messenger-a, i jedan sa messenger-om, da provera ne bi
prošla zato što se poruka nikad ne prikazuje.

**Ostaje kao sitnica, ne kao rupa:** tih 82 mesta i dalje sama sastavljaju
`SnackBar` sa svojom bojom. Prelazak na `error` / `success` / `info` / `warning`
je posao za dan kad se boje budu ujednačavale, i menja izgled — zato nije urađen
sada.

**Usput popravljeno na serveru:** odbijen početak snimanja nije ostavljao nikakav
trag, pa je upis snimka kasnije nalazio prazan spisak učesnika i prolazio kao
„nije moglo da se proveri". Sad se spisak upisuje **pre** presude — ko je bio u
sobi kad je snimanje *pokušano* — pa klijent koji ignoriše `recording_denied` i
svejedno pošalje snimak biva odbijen i na upisu.

### Prekid zbog saglasnosti više nije „restart usred časa" — ✅ 25.8.2026

**Provereno uživo istog dana**, soba 104362: log kaže pravi razlog, klijent javi
prekid u istoj sekundi u kojoj dete uđe, a rečenica stigne do trenera. Ostaje
samo provera `participants` u bazi (stavka 37 u `TODO-provera.md`).

Nađeno u logu prave provere, dvanaest minuta posle prethodnog odeljka:

```
21:30:05 WARN  [SNIMANJE] Zaustavljeno u sobi 104362: … roditelj nije dozvolio snimanje za: učenik 1.
21:30:05 INFO  [RECORDING STATUS] Room 104362 -> status: stopped
21:30:18 WARN  [SNIMANJE] Saglasnost nije mogla da se proveri … (restart usred časa?)
21:30:18 INFO  [RECORDING] Multipart audio saved: …recording_1787693418307_397535871.aac
```

Nije bilo nikakvog restarta. Rukovalac ulaska je **brisao spisak učesnika**
(`clearRecordedRoster`) pre nego što pošalje `recording_must_stop`, pa je upis
trinaest sekundi kasnije pao u granu pisanu za tuđi kvar. Tri posledice, sve tri
merene a ne pretpostavljene:

1. **Prekid zbog saglasnosti i restart servera bili su isto stanje.** Server je
   znao tačan razlog, sam ga obrisao, pa o istoj sobi rekao da ne pamti ništa.
2. **Druga brava od tog trenutka nije držala ništa.** Komentar dvadesetak redova
   iznad opisuje baš tu rupu i zatvara je za odbijen *početak* — a ulazak ju je
   otvarao ponovo: klijent koji ignoriše `recording_must_stop` i nastavi da
   snima dete mogao je posle da upiše šta hoće.
3. **Dete je ostajalo u `participants` snimka u kome ga nema.** Klijent šalje ko
   je u sobi u trenutku čuvanja, a to je i spisak onih kojima se snimak
   prikazuje (`$1 = ANY(sr.participants)`) — pa bi odbijenom detetu tuđi snimak
   stajao kao njegov.

**Sada su tri odgovora**, isti oblik koji je `accountGuard` već tražio:
*zaustavljeno zbog saglasnosti*, *ništa nije zaustavljeno*, *server ne pamti*.
Samo srednji prolazi bez napomene.

- `stopRecordingForConsent` **pamti** prekid umesto da ga zaboravi, i iz spiska
  vadi samo onoga zbog koga je stao — ono što je snimljeno pre njegovog ulaska
  ostaje trenerovo, jer njega u tome nema.
- Prolaz zavisi od toga da li je soba **javila da je stala**. To nije novo
  polje: `recording_status_update {status:'stopped'}` je već postojao i pošten
  klijent ga šalje u istoj sekundi (0s u logu gore). Rok je 30 s — širok za lošu
  vezu, preuzak za klijenta koji je nastavio da snima. Ako nije javio: **403** i
  fajl se briše.
- Poruka govori šta se stvarno desilo, i **stiže do trenera**:
  `syncPendingRecordings` sada vraća napomene servera, a soba ih prikazuje kroz
  `AppFeedback` — posle sinhronizacije, ne pre nje. Do danas je server tu
  rečenicu sastavljao na svaki upis, a `lib/` je nije čitao nigde: `consentUnverified`
  i `message` su se odbacivali. Ista greška kao `parent_allows_recording` —
  upisano, i ne čita ga niko — uperena u ono što je roditelj odgovorio.

**Dokazano mutacijom**, `test/recording_stop.test.js` (13 testova):

| mutacija | test koji padne |
|---|---|
| upis prestane da pita `realtime.consentStop(...)` | *the save asks whether this room was stopped for consent* + *… refuses the room that never said it stopped* |
| ulazak vrati `clearRecordedRoster` | *the join handler records the stop instead of forgetting the room* |
| niko ne beleži javljeni prekid | *the stop reported by the room reaches the record* |
| aplikacija prestane da čita odgovor | *the answer the server composes is read by the app, not only written* |

Poslednja je zaslužila i belešku u samom testu: **prva verzija tog testa nije
pala.** Tražila je reč `consentStopped` bilo gde, a ta reč je i posle mutacije
stajala u komentaru i u ključu pod kojim se čuva. Sad se komentari prvo brišu i
traži se `data['consentStopped']`, dakle čitanje. Ograda vredi tačno onoliko
koliko kaže njena mutacija.

### „Nemate sačuvanih prijatelja" je bila greška u čitanju — ✅ 25.8.2026

Prijava uživo: *„zašto dok sam u sesiji ne mogu nikog da pozovem?"* — dijalog
*Pozovi prijatelje u sesiju* je pisao **Nemate sačuvanih prijatelja** treneru
koji u toj sobi ima dva prihvaćena učenika.

```dart
friendsList = jsonDecode(res.body);   // ruta vraća { "friends": [...] }
} catch (e) {
  // quiet fail
}
```

`GET /friends` vraća objekat. Dekodiranje pravo u `List<dynamic>` bacalo je
`TypeError` **na svakom pozivu koji je ikada bio**, a `catch` ispod ga je gutao
pod komentarom „quiet fail" — pa je nemogućnost da se spisak *pročita* izlazila
kao spisak koji je *prazan*. Isti oblik kao sve ostalo u ovom dokumentu: „nisam
mogao da pitam" pročitano kao „nema nikoga". `home_screen.dart` čita istu rutu
ispravno (`jsonDecode(res.body)['friends']`), četiri stotine redova dalje.

Popravljeno oboje: odgovor se raspakuje, a neuspeh se sada **vidi** — dijalog
kaže da spisak nije mogao da se učita, umesto da tvrdi da je prazan. Prazan
spisak je usput dobio i tačniju rečenicu, jer `friends` red od 25.8.2026 nastaje
samo iz prihvaćene veze trener–učenik.

Provereno ostatkom koda: `/lessons/labels` i `GET /recordings` vraćaju čiste
nizove, pa su ta dva čitanja ispravna — ovo je bilo jedino mesto tog oblika.

`test/invite_friends_dialog_test.dart` čita telo dijaloga po zagradama i pada na
obe mutacije: povratak na dekodiranje pravo u listu, i povratak na tiho gutanje.

**Potvrđeno uživo istog dana:** poziv iz sobe radi.

### Sajt: pravni deo je napisan i čeka jedno pokretanje — 26.8.2026

Odluke su bile donete ranije (domen 16.8, isti droplet 17.8); nedostajale su
stranice. Sada postoje, u `site/`, sa `deploy/site-setup.sh` koji ih objavljuje.

**Zašto baš ovaj deo prvi:** politika privatnosti i kontakt su ono što **blokira
Play**, ne traže odluku o imenu, i ne dodiruju backend — koji je namerno ugašen,
pa objavljivanje statičnih stranica ne otvara priču o dva servera nad jednom
bazom. Naslovna sa opisom mogućnosti i preuzimanjem čeka ime i odluku o nivoima
pretplate, jer se taj tekst piše jednom i koristi i u Play listingu.

**Zatečeno stanje koje niko nije primetio:** `chesstrainers.app`, `www` i `api`
**već pokazuju na isti droplet**. Pošto je ceo `.app` na HSTS preload listi, ko
danas ukuca adresu ne dobije upozorenje nego stranicu koja izgleda pokvareno —
nginx nema server blok za to ime. `chesstrainers.net` još pokazuje na parkiranu
stranicu registrara.

Tri stvari koje skripta radi drugačije nego što bi bilo očigledno, i sve tri su
iz grešaka koje ovaj projekat već ima zapisane:

- **Zaseban sertifikat za `@` i `www`**, nikad `--expand` na onaj za `api`. Ako
  se sajt ikad preseli, certbot bi nastavio da obnavlja imena koja ta mašina ne
  servira, obnova **celog** sertifikata bi pukla i sa njom `api` — tri meseca
  kasnije i bez poruke.
- **Stranica sa neispunjenim `{{PLACEHOLDER}}`-om se ne objavljuje.** Zamena se
  radi u privremenom folderu, proverava se tamo, i tek onda menja ono što je
  živo. Politika privatnosti koja ne imenuje rukovaoca gora je od nikakve, a
  ime i adresa su fizičkog lica i ne smeju u javan repozitorijum — pune se iz
  `.env`.
- **Preusmerenje sa `.net` se preskače naglas** dok njegov A zapis ne pokazuje
  ovde, umesto da se od certbot-a traži ime koje se ne razrešava na ovaj host.

**Šta je namerno ostalo van sajta:** obrazac saglasnosti. Obavezujući tekst
generiše `routes/consent.js` i nosi `PARENT_CONSENT_VERSION`; stranica na sajtu
opisuje postupak i to izričito kaže. Treći primerak pravnog teksta nije smeo da
nastane — dva već postoje (nacrt u `docs/` koji je advokat čitao, i objavljena
verzija).

Provereno lokalno pre predaje: sve četiri stranice se iscrtavaju, nemaju
nijedan neispunjen `{{...}}`, nemaju vodoravno prelivanje na širini telefona, i
konzola je prazna. Ostaje da se u `.env` na dropletu upišu vrednosti i pokrene
skripta — to je jedina radnja koja traži server.

### Odakle sutra — 26.8.2026, 00:20

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
`PUBLIC_BASE_URL` prazan na dropletu; i kanvas sa predlozima za panel trenera,
koji čeka izbor varijante.

### Sledeće, po redu

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

7. **Trenažer repertoara**, po delovima. Skica je u
   [repertoire_trainer_spec.md](repertoire_trainer_spec.md); dogovoreno je da
   se gradi odozdo, jer je celina najveća stavka koja je do sada predložena i
   takmiči se sa objavljivanjem.

   - ~~**Sudija** — jedan endpoint i panel u Analizi~~ — urađeno i provereno
     uživo 24.8.2026. Vredi sam za sebe i bez ijednog repertoara, i dokazuje
     priču o kešu i opterećenju pre nego što se na njoj zida.
   - ~~**Režim izgradnje**~~ — urađeno 24.8.2026, nije viđeno uživo (stavka
     29). Prag je 80% u izabranoj traci, najviše četiri odgovora, a ostatak se
     broji i prijavljuje. Odluke su u odeljku „Repertoar: režim izgradnje".
   - ~~**Uvežbavanje**~~ — urađeno 24.8.2026, nije viđeno uživo (stavka 30).
     Kroz postojeći SM-2, ali sa svojom tabelom `repertoire_reviews`; zašto ne
     kroz proširen `review_items`, piše u odeljku „Repertoar: drill".
   - **Radar pokrivenosti** — poslednji. Najlepši je i najmanje uči.

   Tri odluke koje važe za sve delove: repertoar živi **na serveru**, ne u
   lokalnoj bazi, jer ga trener zadaje i gleda, a reinstalacija ne sme da
   obriše godinu dana rada; rang se bira **prema učeniku**, ne fiksnih „1800+",
   pošto dete sreće poteze od 1200; i kazna se **odigra**, ne objasni — za to
   već postoje „Kazni" i „Odigraj do kraja" iz trenera završnica.

8. **i18n na kraju**, kad prestanu da se menjaju ekrani. Odluka i razlozi su u
   odeljku „Sistematizacija prostora".

### Šta namerno nije urađeno

- **`CustomPuzzleSolverScreen` nema rutu** — nosi povratni poziv `onAnswered`,
  dakle je korak u toku, ne mesto.
- **`AiStudioScreen` nije formatiran** `dart format`-om — nad tim fajlom pravi
  850 izmenjenih linija umesto 40 i obara `analyze`. Formatira se kad se bude
  delio, i tada mu ide i pravo ime: nema veze sa AI.
- **Unija „Dobij" i „Greške iz partija"** — procenjeno, korisnik odložio.
  Šetnja i dalje nema „Odigraj do kraja" ni igranu kaznu.

### Brojke, da se vidi da li je nešto puklo

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
