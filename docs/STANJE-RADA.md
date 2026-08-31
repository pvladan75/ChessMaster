# Stanje rada — nastavak u novoj konverzaciji

Namena: da neko ko dolazi bez istorije razgovora za pet minuta zna gde smo stali
i zašto je nešto urađeno baš tako. Nije prepis dijaloga — prepis troši prostor,
a odluke su ono što se ne može rekonstruisati iz koda.

Ovde stoji samo **ono što je još živo**: gde smo, šta je otvoreno, šta sledi, i
pravila koja i dalje važe. Zatvorena istorija — popravke sa ✅ i datumom,
merenja, i putevi kojima se do sadašnjeg oblika došlo — preseljena je 27.8.2026.
u [arhiva/STANJE-RADA-do-26.8.2026.md](arhiva/STANJE-RADA-do-26.8.2026.md).
**Arhivu ne treba čitati unapred**; ona se pretražuje (`grep`) kad zatreba
*zašto* neke starije odluke. Razlog za podelu: ovaj fajl je bio 242 KB i svaka
je sesija počinjala tako što ga je ceo pročitala.

Zbog podele poneko „odeljak iznad/niže" sada pokazuje preko granice dva fajla —
ako ga nema ovde, u arhivi je.

Poslednje ažuriranje: 30.8.2026.

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
   Skica je u [repertoire_trainer_spec.md](repertoire_trainer_spec.md); gradilo
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

## Panel trenera — kanvas sa tri varijante, 26.8.2026

Stavka „kanvas sa predlozima za panel trenera, koji čeka izbor varijante" stajala
je otvorena od 24.8.2026, ali **varijante nigde nisu bile zapisane** — čekao se
izbor između predloga koji ne postoje. Sada postoje.

Radni fajlovi: `design/panel-trenera/`. Objavljeni kanvas:
https://claude.ai/code/artifact/dca9d784-3e96-4c50-84ed-9b69e117a07c

Tri varijante se ne razlikuju po izgledu nego po **pitanju na koje odgovaraju**,
jer to odlučuje šta stoji na vrhu ekrana:

| | Pitanje | Jaka strana | Cena |
|---|---|---|---|
| **A — Danas** | šta mi je sad posao | otvoriš i znaš šta radiš | učenik koji tone mesecima, a nema ništa danas, nigde se ne pojavi |
| **B — Po učeniku** | kako stoji svako | jedina pokazuje trend | ne kaže šta da uradiš; sa dvadeset učenika je zid brojeva |
| **C — Čeka tebe** | gde sam ja usko grlo | broj na tabu je iskren i prazni se do nule | vidi samo ono što je neko drugi pokrenuo; ćutljiv učenik ne stvara stavku |

**Predlog: A kao ekran, C kao broj.** Trener otvara aplikaciju pred čas, ne radi
pregleda. Ono što iz C-a stvarno vredi je značka sa brojem na tabu Ljudi; red
posla može da bude odeljak unutar A umesto zasebnog ekrana. B ne bi bio panel
nego postojeći ekran napretka, do kog se stiže klikom na učenika — trend je
važan jednom mesečno, ne svakog dana.

Makete su statične i u tamnoj temi aplikacije; boje i razmaci su preuzeti iz
`chess_app/lib/theme/app_colors.dart`, a polja su stvarna (Rejting, Tačnost,
Rešeno, Aktivnih dana, period 7/30/90). Imena i brojevi su izmišljeni, jer je
repozitorijum javan.

Ono što maketa **ne** rešava: prelivanje na uskom telefonu. To i dalje traži
proveru na uređaju, iz razloga opisanog u `CLAUDE.md` — u release build-u nema
žuto-crnih traka.

## Panel trenera — izabrano i napisano, 27.8.2026

Korisnik je izabrao **A kao ekran, C kao broj**, kako je i predloženo. Napisano
istog dana; **nije viđeno uživo** — stavka 39 u
[TODO-provera.md](TODO-provera.md).

**Nije nov tab, nego odeljak na vrhu taba „Ljudi".** Razlog je isti onaj koji
drži i ostatak ovog dokumenta: trener je *položaj u vezi*, ne osobina naloga, pa
bi peto odredište u traci stajalo prazno svakome ko nikoga ne uči — a to je
većina korisnika i gotovo sva deca. „Ljudi" je jedini tab koji ionako postoji
zbog veze. Uz to, peto odredište bi se pisalo na dva mesta (`NavigationBar` i
`NavigationRail`) plus prečice i istorija tabova, a pet natpisa na telefonu od
360 dp je tačno onaj red koji release build ćutke odseca.

Šta je napisano:

| | |
|---|---|
| `GET /trainer/panel` | jedan poziv, četiri odeljka: današnji časovi, domaći kojima ističe rok, predato a nepregledano, i učenici koji ćute duže od 7 dana |
| `POST /assignments/:id/reviewed` | jedini događaj koji prazni značku |
| `assignments.reviewed_at` | nova kolona; bez nje značka može samo da raste |
| `acceptedStudentsOf` | isti fragment kao `acceptedTrainersOf`, samo iz drugog smera — spisak „moji učenici" ide kroz njega, ne kroz ručno prepisan uslov |

**Značka broji samo ono što trener može da isprazni** — predato a nepregledano,
plus zahtevi na koje nije odgovorio. Rokovi i učenici koji ćute jesu na ekranu i
**nisu** u broju: njih ne zatvara nijedan potez trenera, a značka koja ne može
da padne na nulu prestaje da se čita. To je i cela poenta varijante C.

`POST .../reviewed` je zasebna ruta, a ne propratni efekat čitanja pregleda,
jer isti pregled čita i učenik: da GET piše, dete bi gledanjem svoje povratne
informacije brisalo stavku sa trenerovog spiska. Poziv ide **pre** otvaranja
ekrana i ne može da ga obori — isto pravilo kao „uradi pa javi" iz `CLAUDE.md`.

Usput popravljeno: prvi tab se u traci zvao **„Trening"**, a u bočnom rail-u
**„Početna"** — jedan te isti `TrainingHubScreen`. Sada oba kažu „Trening", i
`test/home_tabs_test.dart` pada ako se raziđu.

Ostalo namerno nenapisano: „Podseti" iz makete (traži poruku učeniku, a ta ruta
ne postoji — dugme vodi u zadatak), i sekcija „Izveštaji roditeljima" iz C
(`student_reports` nema stanje „sastavljen, nije poslat", pa bi broj bio
izmišljen).

## Bagovi 1 i 7 sa prolaska kroz aplikaciju — 27.8.2026

**Bag 1: engine se „zamrzne" ako se odigra potez dok razmišlja.** Nije Stockfish
nego jedna sekunda. Kad engine odabere potez, `_isOpponentTurn` se gasio
**odmah**, a potez se igrao tek posle pauze od 1000 ms — a tabla je nema samo
dok je ta zastavica podignuta. U toj sekundi korisnik odigra potez figurom
strane koja je na potezu (engine-ove!), pa zakazani potez padne na poziciju
kojoj više ne pripada. Odatle nadalje pozicija u `_puzzleGame` i pozicija na
tabli nisu ista stvar, i drill prestane da odgovara.

Zastavica se sada gasi tek kad je potez **na tabli** (`resetBoardState` to
ionako radi), potez se pred igranje **proverava ponovo** — protiv table na koju
sleće, a ne one za koju je izabran — i ako više nije legalan, traži se nov
odgovor umesto da se odigra nasilu.

Uz to, dve stvari koje su rupu skrivale:

- Kad engine nema šta da odigra (sve evaluacije stigle za staru poziciju, pa su
  odbačene kao zastarele), ranije se tiho izlazilo iz funkcije. Sad ide **jedan**
  ponovni upit za poziciju koja je stvarno na tabli, pa tek onda odustajanje sa
  porukom — i tabla se vraća korisniku, jer zaključana tabla i tabla koja ne
  odgovara izgledaju isto spolja.
- `stopAnalysis()` briše `_currentFen`, ali engine posle „stop" šalje još
  nekoliko redova i `bestmove`. Ti redovi su se prosleđivali sa **praznim**
  FEN-om: svaki slušalac ih odbaci kao zastarele, ali tek pošto
  `AnalysisLine.fromPv` pokuša da napravi tablu od `''` i baci *„FEN string must
  contain six space-delimited fields"* u log, po redu. To je bio šum u kom se
  pravo zamrzavanje izgubilo. Sada se izlaz zaustavljene pretrage ne prosleđuje.

**Bag 7: posle pogrešnog poteza tabla je primala poteze koje niko nije čuvao.**
Pogrešan potez postavlja status `failed`, a `failed` znači „gotovo", pa je
sledeći `_onMove` izlazio **bez vraćanja table** — dok je widget figuru već
pomerio. Nekoliko povlačenja kasnije, tabla na ekranu i pozicija koja se rešava
bile su dve različite stvari, za obe boje.

Dva pravila, oba tražena:

1. **Svako odbijanje poteza vraća tablu.** Bez izuzetka i bez obzira na razlog.
2. **Nema više dugmeta „Pokušaj ponovo".** Pogrešan potez u vežbi sam vraća
   poziciju i odmah dozvoljava nov pokušaj — to je jedino zbog čega je iko to
   dugme i pritiskao. Greška ostaje zabeležena, pa rešenje posle greške i dalje
   ne važi kao čisto.
3. **Domaći je izuzetak.** Tamo je prvi potez odgovor i već je zabeležen, pa
   drugi pokušaj ne bi menjao ništa osim utiska. Umesto toga piše da je zadatak
   sa jednim pokušajem i da je potez zabeležen, tabla se zaključava, a „Prikaži
   rešenje" ostaje dostupno — tu i vredi najviše.

Isto je primenjeno na trener završnica, gde je korisnik video isto ponašanje.
`test/wrong_move_board_test.dart` drži pravilo (dokazano mutacijom); taktika
nema ubrizgan API pa se ne može testirati bez mreže — ostaje provera uživo.

## Rupa u prijavi, nađena usput 27.8.2026

**`POST /verify-email` je izdavao token bez ijedne provere.** Ruta je nalazila
nalog po adresi i, ako je već verifikovan, **potpisivala JWT i vraćala ga** —
bez poređenja kôda, bez lozinke. Ko zna bilo koju registrovanu adresu, pošalje
je sa šest proizvoljnih znakova i dobije sedmodnevnu sesiju za taj nalog. Za
svaki nalog na serveru, uključujući dečje.

Nije izgledalo kao rupa nego kao ljubaznost: „ako je korisnik već verifikovan,
nemoj da mu javljaš da je kôd pogrešan". I stajalo je tačno iznad poređenja koje
je preskakalo. Nađeno čitanjem rute zbog sasvim drugog pitanja.

Pravilo je sada u `services/emailVerification.js`, kao jedna čista funkcija sa
tri ishoda, i **verifikovan nalog ne dobija sesiju nikada** — dobija poruku da
se prijavi lozinkom ili preko Google-a. Verifikacija dokazuje da je adresa
jednom bila dostupna; to nije dokaz o *sada*, a ova ruta drugog dokaza nema.
Aplikacija na `alreadyVerified` vraća korisnika na formu za prijavu, umesto da
ga ostavi pred poljem za kôd koje više ne može da radi.

**Uz to, druga polovina istog pitanja: Google prijava i postojeći nalog.**
Prijava preko Google-a preuzima nalog koji već drži tu adresu — i to treba tako
da ostane. Adresu je potvrdio Google (`email_verified` se proverava), isti dokaz
koji daje i naš kôd; odbijanje bi ostavilo čoveka bez ulaza, a drugi nalog bi
tiho razdvojio trenera od učenika, jer veza visi o `users.id`.

Jedan izuzetak je dodat. Ako zatečeni nalog **nije verifikovan**, niko nikad
nije dokazao da je adresa njegova — bilo ko može da registruje bilo čiju adresu,
a kôd koji bi to dokazao nije unet. Preuzimanje takvog naloga sa zatečenom
lozinkom ostavilo bi onome ko ga je napravio radnu lozinku za nalog čoveka koji
adresu stvarno poseduje. Zato lozinka u tom slučaju pada na
`GOOGLE_PLACEHOLDER_HASH` i nalog postaje Google nalog.

Oba pravila drži `test/email_verification.test.js`, a čitač izvora u njemu je
dokazan mutacijom — vraćanjem stare grane, koja test obara.

## Ekran za prijavu — pet nalaza sa prve prolaznosti, 27.8.2026

Korisnik prolazi kroz aplikaciju ekran po ekran. Prvi je ekran za prijavu; pet
stvari, sve stvarne.

**Dva puta unutra, sada razdvojena.** Ranije su tri dugmeta stajala jedno ispod
drugog i jedno od njih je radilo nešto drugo. Sada je prvo Google blok, pa linija
„ili", pa email forma. Google dugme je izgubilo ivicu u primarnoj boji — ta ivica
je i bila razlog što je izgledalo kao označen izbor dok korisnik kuca adresu — i
piše **„Prijava / Registracija preko Google-a"**, jer to dugme i registruje.
Prikazuje se i u režimu registracije, gde ga uopšte nije bilo: to je jedini ekran
na kom neko sigurno traži način da napravi nalog.

**„Zapamti me" je radilo, ali ne ono što je pisalo.** Kutijica čuva token i
`SessionService.init()` ga vraća pri pokretanju. Sesiju prekidaju tri stvari, sve
tri ispravne: token traje **7 dana**, odjava, i nestao nalog (baza je pražnjena
25.8.2026, pa je stari token pokazivao na nalog koga više nema). Sada:

- adresa iz poslednje prijave se pamti i upisuje sama (preživljava odjavu, token
  ne),
- polja su u `AutofillGroup` sa `autofillHints`, a uspešna prijava zove
  `finishAutofillContext()` — **to** je ono što natera Android i Windows da
  ponude čuvanje i kasnije popunjavanje lozinke,
- kursor počinje u lozinki kad je adresa već poznata, inače u adresi,
- ispod kutijice piše šta ona radi: „Ostajete prijavljeni na ovom uređaju."

**Lozinka se namerno ne čuva u aplikaciji.** Predlog je bio da se pamti i
prikaže pod zvezdicama. `SharedPreferences` je na Windows-u običan XML fajl u
profilu korisnika — čita ga svaki program koji radi kao taj korisnik — a većina
ovih naloga pripada deci. Isti efekat daje menadžer lozinki operativnog sistema,
kome se pristupa preko `autofillHints`, i tada je aplikacija nikad ne vidi.

**Google prijava na Windows-u — napisana, nije isprobana.** `google_sign_in` ne
podržava Windows (ni Linux): `supportsAuthenticate()` vraća false i dugme je bilo
slepa ulica. Umesto njega ide tok za instalirane aplikacije (RFC 8252):
sistemski pretraživač, `redirect_uri` na `http://localhost:<slobodan port>`, PKCE
(S256), pa razmena kôda za `id_token`, koji ide na postojeću rutu `/auth/google`.

Backend se **ne dira** — `GOOGLE_CLIENT_IDS` je oduvek lista, baš zato što svaka
platforma ima svoj klijent.

| | |
|---|---|
| `services/oauth_pkce.dart` | čist deo: PKCE, sastavljanje URL-a, čitanje odgovora — jedino što se može testirati, i jedino što tiho pukne |
| `services/desktop_google_sign_in_io.dart` | soket, pretraživač, razmena kôda |
| `services/desktop_google_sign_in.dart` | uslovni izvoz, da web build ne vidi `dart:io` (isti oblik kao `stockfish_service.dart`) |

Provera `state` nije ukras: bez nje bilo koja stranica u bilo kom pretraživaču
na toj mašini može da pogodi loopback port svojim kôdom i natera aplikaciju da
ga iskoristi — prijava na tuđi nalog. Test to drži.

**Šta preostaje tebi**, jer bez toga ovo ne može da se isproba (koraci su u
stavci 40 u [TODO-provera.md](TODO-provera.md)): napraviti OAuth klijent tipa
„Desktop app" u Google Cloud konzoli, dodati njegov ID u `GOOGLE_CLIENT_IDS` na
serveru, i graditi Windows sa `--dart-define`. Dok toga nema, dugme se na
Windows-u **ne prikazuje** — bolje nego dugme koje javi grešku posle klika.

## Šta je prva proba panela pokazala — 27.8.2026

Korisnik je panel video na Windows-u i na Androidu; prikazuje se samo onome ko
ima učenike, i „Otvori" radi. Iz same probe su ispala **tri** nalaza, i sva tri
su bila stvarna rupa, ne greška u prikazu.

**1. Domaći bez roka nije se video nigde.** Prva verzija je gledala samo rok, a
zadatak bez roka nema šta da istekne. Isto tako, zadatak koji je stao na pola
nestajao je iz „Nije vežbao" čim učenik reši prvu zagonetku — nije više ćutao,
a nije ni završio.

Dodat je odeljak **„Domaći stoji"**: nezavršen zadatak bez pomaka 3+ dana, sa
rokom koji je još daleko ili bez roka. Poslednji pomak je
`GREATEST(created_at, MAX(attempted_at))`, pa zadatak koji niko nije ni otvorio
računa od dana kad je zadat. Dva prozora su komplementarna — šta je u naredna
48 sata ide u „Domaći ističe", sve ostalo sme u „Domaći stoji" — tako da isti
zadatak ne može da bude u oba.

**2. „Nije vežbao" je prijavljivalo učenika kome ništa nije ni zadato.** Odeljak
sada izostavlja svakog ko ima otvoren zadatak: o njemu govori red o domaćem, a
ne rečenica da ćuti. Jedan čovek, jedan red, jedna stvar koja se s njim radi.
Odeljak **nije** vezan za domaći, jer bi se time izgubio slučaj zbog kog i
postoji — dete koje tone mesecima a niko mu ništa nije zadao. Zato red sada i
piše „nema zadatog domaćeg".

**3. Obaveštenje treneru radi, ali učenik nije znao da nije predao.** Korisnik
je preskočio dve zagonetke i mislio da je predao domaći. `assignment_done`
obaveštenje **postoji odranije** i stiglo je čim je kasnije uradio i te dve —
provereno u bazi. Problem je bio na učenikovoj strani: na kraju prolaza je
pisalo **„Zadatak je završen. Vaš trener vidi rezultat."** bez obzira na to
koliko je preskočeno.

Sada, kad je nešto preskočeno, piše **„Domaći još nije predat"**, koliko je
preskočeno, i da trener ne dobija obaveštenje dok se i te zagonetke ne pokušaju
— uz dugme „Uradi preskočene", koje vraća **samo** njih, ne ceo zadatak.

Sitnica koja se lako previdi: broj u toj rečenici ide kroz `puzzleCountLabel`,
jer srpski ima tri oblika (1 zagonetku / 2 zagonetke / 5 zagonetaka), a 11–14
idu uz peti oblik. Tekst čitaju deca.

Usput: panel i značka se sada osvežavaju i preko soketa
(`notifications_changed`), pa predat domaći stiže na ekran bez izlaska iz taba.
Promena prisutnosti više ne pokreće upite panela — to je najbučniji događaj koji
panel ne prikazuje.

## Šahovski studio nije mogao da se otvori — 27.8.2026

Iz korisnikovog loga:

```
[SOBA]  Odbijen ulazak u STUDIO: no-room (korisnik 1)
[AGORA] Odbijen token za kanal STUDIO: no-room (korisnik 1)
```

Studio je **lokalna tabla, a ne soba**: reda `rooms.room_code = 'STUDIO'` nema
i ne treba da ga bude — `canMoveInRoom` u `server.js` to i kaže naglas. Ali
`chess_game_screen` je isti ekran za oba slučaja, pa je iz `initState` slao
`joinGame` sa `roomId: 'STUDIO'`. Otkad postoji spisak zvanica (`roomAccess.js`),
na to pitanje postoji samo jedan odgovor — `no-room` — a ekran radi ono što
odbijanje nalaže: poruka „Ne postoji soba sa tim kodom" i izlazak nazad. Studio
se time zatvorio sam.

Nije regresija u `roomAccess.js` nego rupa koju je on otkrio: dok je `joinGame`
puštao svakoga, **svi studiji na svetu su bili jedna soba po imenu STUDIO**, pa
su se potezi jednog čoveka emitovali u tuđu analizu.

Popravka je na klijentu, jer je odluka klijentova: kad je `roomCode == 'STUDIO'`,
ne šalje se `joinGame`, a glas se ne dira uopšte — `_joinVoice()` ga odbija
za studio, i sam panel „Audio Učionica" stoji pod `if (!isStudio)`. Soket
ostaje otvoren (ekran ga koristi na 34 mesta i emitovanja padaju u praznu
sobu), a naslov u `AppBar`-u je sada „Šahovski studio" umesto „Soba: STUDIO".

Ostaje sitnica, namerno neurađena: studio i dalje emituje `move` i `pgn_loaded`,
pa server po potezu radi `UPDATE rooms ... WHERE room_code = 'STUDIO'` koji ne
pogađa nijedan red. Bezopasno, ali je jedan upit u bazu po potezu za tablu koja
je sama svoja.

Provera uživo: ući u Šahovski studio i videti da se otvara, da u logu nema
`[SOBA]`/`[AGORA]` odbijanja i da tabla radi bez servera.

## Pešak nije mogao da postane figura — 27.8.2026

Prijavljeno uživo iz „Pronađite dobitni put", sa logom koji je odmah pokazao
gde da se gleda:

```
[MOVE_MADE_DEBUG] Could not match move in chess.js legal moves!
```

Uzrok je jedan nedostajući ključ u paketu. `chess.dart` u `make_pretty` pravi
mapu poteza od `san`, `to`, `from`, `captured` i `flags` — **i ničeg više** — a
dokumentacija dva reda iznad te funkcije kaže da u mapi stoje i `piece` i
`promotion`. Ceo ovaj kod je verovao dokumentaciji. Znači: `m['promotion']` je
**uvek `null`**, za svaki potez, u svakoj poziciji.

Dva različita kvara iz istog uzroka:

- mapa vraćena u `game.move(m)` **biva odbijena** kad je potez promocija, jer
  `move()` poredi `move['promotion'] == moves[i].promotion!.name`, a ključa
  nema. Potez se ne odigra, `move()` to i kaže — i svaki pozivalac je nastavio
  kao da jeste;
- `where((m) => m['promotion'] != null)` ne izabere ništa, pa kod koji traži
  promociju među legalnim potezima zaključi da je nema.

**Popravka je na jednom mestu**: `core/services/legal_moves.dart` čita figuru iz
SAN-a (`d8=Q+`) i vraća iste mape sa popunjenim `promotion` (`''` kad nije
promocija), plus `playMove` koji potez odigra sa imenom figure i `isPromotionMove`
koji pita **poziciju**, a ne odredišno polje — pešak koji uzima na osmom redu
jeste promocija, a top koji dođe na osmi red nije. Namerno se ne generiše lista
poteza drugi put „kao objekti" pa uparuje po indeksu: to bi bile dve liste za
koje se veruje da su istog redosleda, a takve tihe pretpostavke su ono što ovaj
projekat stalno plaća.

Zamenjeno je svih 14 mesta koja su zvala `moves({'verbose': true})`. Šta je sve
usput bilo pokvareno, a niko nije znao:

- **AI studio** (prijavljeni slučaj) — potez se nije odigrao ni preko tapa ni
  prevlačenjem;
- **`game_analysis_walker_service`** — šetnja kroz partiju **prekidala se na
  prvoj promociji**, tiho, na sredini tuđe analize;
- **`tactical_motif_detector`** — mat u jedan **promocijom** (najčešći od svih:
  `d8=Q#`) nikad nije bio pronađen;
- **`auto_tree_generator_service`** — rezervno uparivanje poteza padalo je baš
  na linijama u kojima pešak prolazi;
- **analiza, otvaranja, stablo rešenja, graf rešenja** — SAN promocije ispisivan
  kao `d7d8` umesto `d8=Q`.

**Drugi deo: izabrana figura mora da putuje sa potezom.** `ChessBoardWithOverlay.onMove`
sada nosi i `promotion`, a deset ekrana koji ga koriste igraju tu figuru umesto
svog `'promotion': 'q'`. Ranije je prevlačenje otvaralo dijalog paketa, čovek bi
izabrao skakača — a ekran bi u svoju poziciju upisao damu i tablu prepisao
preko izbora.

**Treći deo: pita se.** Tap-potez je ćutke pravio damu, pa se vežba čije je
rešenje skakač nije mogla ni odigrati tapkanjem. Sada postoji jedan dijalog za
sve table (`widgets/promotion_picker.dart`), na srpskom, u boji strane koja
igra, sa imenima figura ispod slika — „lovac" i „top" su tačno one dve koje deca
mešaju. Odustajanje znači da se potez **ne igra**, umesto da se odigra ono što
niko nije izabrao. Taktika je imala svoj dijalog i sada koristi ovaj; AI studio
je imao gore od toga — čitao je stablo rešenja i tiho promovisao u figuru koju
rešenje traži, pa je zadatak koji uči da samo skakač radi bio „rešen" damom.

`test/legal_moves_test.dart` (9 provera, uključujući onu koja reprodukuje sam
bag) i tri nove u `test/tap_to_move_test.dart`. Dokazano mutacijom: kad
`promotionOf` uvek vrati prazno, pada sedam testova; kad se ukloni pitanje u
tabli, pada test koji traži dijalog.

Ostaje, sitno i zapisano: **prevlačenje i dalje otvara dijalog paketa** („Choose
promotion", uvek bele figure). Radi ispravno i izbor sada stiže do ekrana, ali
je na engleskom u aplikaciji za srpsku decu. Zameniti se može samo ako se widget
table preuzme u repo — nije vredno danas.

Provera uživo: u „Pronađite dobitni put" dovesti pešaka do poslednjeg reda i
tapnuti — mora da pita, i izabrana figura mora da se pojavi na tabli; isto
prevlačenjem; pa isto u završnicama, taktici i repertoaru.

## Koordinate na tabli, i jedno dugme koje je smetalo — 27.8.2026

Tri stvari, sve prijavljene sa slika ekrana.

**Dugme za okretanje table izbačeno iz vežbi.** U „Mat u 1, 2 ili 3 poteza",
„Vežbanje osnovnog matiranja" i „Pronađite dobitni put" — to je jedan te isti
ekran (`_buildActiveBoardScreen` u `ai_studio_screen.dart`), pa je izmena na
jednom mestu pokrila sva tri — tabla se okreće prema onome ko rešava, a iznad
nje piše „Crni na potezu". Ko je okrene, gleda tablu koja protivreči rečenici sa
njegovom bojom. `_toggleOrientation` je obrisan jer više nema ko da ga zove.

**Prekidač za koordinate, na svakom ekranu sa tablom.** `BoardWithCoordinates`
je postojao od ranije, ali samo na pet ekrana i bez načina da se ugasi. Sada:

- `AppSettingsService.showBoardCoordinates` (podrazumevano **uključeno**, jer
  deca uče da čitaju tablu), zapamćeno na uređaju;
- `BoardWithCoordinates` sluša podešavanje i, kad je isključeno, **vraća tabli
  ceo prostor** — zato prekidač stoji u njemu, a ne u pozivaocima: ekran koji je
  sam oduzeo pojas ostavio bi prazan okvir;
- `BoardCoordinatesButton` — jedno dugme (`grid_on`/`grid_off`), koje samo crta
  svoje stanje, na: vežbama iz AI studija, Tabli za analizu, sobi za čas (u
  traci ispod table, pored dugmeta za okretanje — u gornjoj traci već stoji pet
  radnji i šesta bi na telefonu od 360 dp izašla van ekrana bez ijednog
  upozorenja u release buildu), taktici, završnicama, greškama iz partija, sva
  tri repertoara, rešavaču zadataka, pregledu lekcije, ponavljanju i plejeru
  snimaka;
- isti prekidač i u Podešavanjima, jer podešavanje treba da postoji i tamo gde
  se traži kad se ne zna gde je dugme.

Tablama koje ranije nisu imale koordinate sada su dodate: AI studio, Tabla za
analizu, soba za čas, taktika, rešavač zadataka, pregled lekcije, ponavljanje,
plejer snimaka.

**Preklapanje ispod table u Tabli za analizu** („BOTTOM OVERFLOWED BY 12
PIXELS"). Leva kolona u pejzažnom rasporedu drži tablu, evaluacionu traku,
navigaciju i panel komentara, a u računicu visine table ulazi samo prvo od toga.
Kolona sada **skroluje**, kao i panel desno od nje. Prevlačenje figure i dalje
pobeđuje skrol: `Draggable` uzima gest odmah, a skrol mora prvo da pređe prag —
soba za čas ima tablu u skrolu oduvek, i za to postoji test.

Provera uživo: ugasiti i upaliti koordinate na jednom ekranu i videti da su
promenjene i na ostalima; suziti prozor Table za analizu dok se ne pojavi
preklapanje (ne sme).

## Motor: jačina protivnika i dubina analize razdvojeni — 27.8.2026

Do sada je u Podešavanjima stajao **jedan broj** („dubina analize"), koji je bio
i to koliko duboko motor misli kad **igra protiv vas**, i to koliko duboko svaka
tabla u aplikaciji računa evaluaciju. Spustiti protivnika da bi detetu bilo
lakše značilo je i plići prikaz u celoj aplikaciji; tražiti pet linija na jednoj
poziciji značilo je promeniti kako motor igra svuda. Dva pitanja, jedan broj.

**Podešavanja sada drže samo protivnika:**

- **Jačina motora kada igra protiv vas** — Lako / Srednje / Teško, što je
  redom 18 / 24 / 30 poteza unapred (`AppSettingsService.kEnginePlayDepths`,
  pa se sva tri mogu naštelovati na jednom mestu). Stara ručno podešena dubina
  se **jednom** preslikava na najbliži nivo, a sam broj ostaje kao početna
  dubina analize — ko je izabrao 29 nije hteo da bude vraćen na podrazumevano.
- **Maksimalno vreme razmišljanja** ostaje kakvo je bilo: motor igra čim
  dostigne dubinu svog nivoa ili čim istekne vreme, šta pre.

**Dubina i broj linija su sada na samoj tabli** (`widgets/engine_analysis_dials.dart`),
ispod prekidača „Prikaži evaluaciju", na svakom ekranu gde se evaluacija
prikazuje: vežbe u AI studiju, Tabla za analizu, soba za čas i građenje
repertoara. Dubina ide **do 50** (bilo je 28 — ostatak iz vremena kad je taj
broj određivao i koliko protivnik razmišlja pre poteza). Poslednje izabrano se
pamti, pa sledeća tabla počinje tamo gde je prethodna stala.

Usput, u istom panelu: **„Prikaži evaluaciju" i „Prikaži evaluacionu liniju"
stoje jedno pored drugog**, u `Wrap`-u — na telefonu se prelamaju u dva reda
umesto da budu isečeni bez upozorenja u release buildu.

**Evaluacija se sada vidi sve vreme.** Ekran za građenje repertoara je čekao da
pretraga stigne do zadate dubine pa tek onda išta prikazivao: na dubini 40 to je
prazan panel po pola minuta, što spolja izgleda isto kao motor koji se ne javlja.
`analyzePositionSync` dobija `onProgress`, pa linije stižu od prve dubine i samo
postaju bolje — a dubina pored svake kaže koliko joj se veruje.

**Strelice sa evaluacijom.** Prvi potez svake linije se crta na tabli, sa
ocenom pored strelice (`EngineArrow`, isto što drugi ekrani već koriste).
Uz to je u AI studiju uklonjeno ograničenje od tri strelice — ko traži pet
linija dobijao je četiri strelice i petu liniju samo u spisku ispod.

**I bag koji je sve to otkrilo:** kad pretraga dostigne zadatu dubinu, poslednje
što motor pošalje je `bestmove`, koji **nema ocenu u sebi**. Servis je taj
događaj prosleđivao kao praznu evaluaciju na dubini 0, a svaki ekran ju je
upisivao u traku — pa je grafička evaluaciona linija u trenutku kad odgovor
postane konačan skakala na 0.00 i crtala dobijenu poziciju kao **egal**. Servis
sada ponavlja poslednju stvarnu ocenu, a ekrani ignorišu praznu evaluaciju:
„nemam šta da kažem" nije „nula".

Provera uživo: promeniti dubinu na tabli i videti da se linije odmah traže
ponovo; pustiti da pretraga stigne do kraja i videti da traka ostaje na pravoj
oceni; u repertoaru gledati kako linije pristižu tokom računanja i kako strelice
sa ocenama stoje na tabli; u Podešavanjima prebaciti nivo i videti da se menja
samo protivnik, a ne i dubina prikaza.

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

## Jedanaest nalaza sa prolaska kroz aplikaciju — 28.8.2026

Korisnik je vodio zaseban dnevnik provere (`D:/Projekti/mislisha-test/
TESTING_LOG.md`, van ovog repozitorijuma) sa jedanaest stavki: dva baga i devet
želja. Sve su rešene istog dana. Ovde stoji samo ono što se iz koda ne vidi —
razlozi, i dve stvari koje su namerno ostavljene.

### Stablo poteza je postojalo, samo se nije videlo

Najveći nalaz nije bio nedostatak funkcije nego njena nevidljivost. `MoveTree`
u `chess_game_screen.dart` odavno pravi varijacije, čuva ih i izvozi u PGN, a
`_promptBranchingDialog` čak pita gde novi potez ide. Ali `MoveHistoryView` —
napisan, potpun, sa varijacijama i komentarima — **nije bio pozvan nigde**, a
navigaciona traka ide isključivo kroz prvo dete. Trener bi se vratio dva poteza
unazad, odigrao drugi potez, i izvorni nastavak bi mu nestao sa ekrana iako je
i dalje bio u stablu.

Isto se ponovilo sa komentarima: `commentController` se održavao u koraku sa
izabranim čvorom na **četrnaest** mesta, a nijedno polje nije bilo vezano za
njega. Zato je stavka u dnevniku glasila „studio nema komentare ni čuvanje" —
čuvanje je radilo sve vreme, samo nije imalo šta da sačuva.

**Pouka koja se ponavlja:** grep na „ko koristi ovaj widget" pre nego što se
piše nov. Dva gotova, testabilna dela stajala su neupotrebljena, a nalaz je
opisan kao nedostatak arhitekture.

### Varijacije su, čim su postale vidljive, otkrile pravi bag

`PgnParser` (koji čitaju pregledač lekcije i ponavljanje) uklanja `{komentare}`
ali **nije uklanjao `(varijacije)`**. `chess.load_pgn` je zato poteze sporedne
linije čitao kao nastavak partije: `1. e4 (1. d4 d5) e5` vraća e4, d5, e5 —
liniju koju niko nije odigrao, prikazanu detetu kao domaći zadatak.

Nije grizlo dosad zato što ništa nije proizvodilo lekcije sa varijacijama.
Rešeno vidljivo (`PgnParser.stripVariations`, broji zagrade jer se varijacije
gnezde), ali obrazac je poznat: **funkcija koja se tek uključuje otkriva put
koji je oduvek bio pogrešan.** Isto kao `zlib.zstd*` i `sed s/^KEY=.*/`.

Uz to, trenerova beleška se sada vidi i učeniku, ispod table u pregledaču
lekcije. Linija se čita jednim parserom a beleške drugim, pa ako se ta dva ne
slože oko broja poteza, **ne prikazuje se nijedan komentar** — beleška ispod
pogrešnog poteza je gore od nijedne, jer izgleda kao da je trener rekao nešto
što nije.

### Traka sa čipovima poteza je uklonjena, ne isključena

Želja je bila da nestane vodoravna traka poteza iznad navigacije, svuda. Pošto
je `showMoveChips: true` stajalo na tačno dva mesta i ništa drugo nije čitalo
`MoveCursor.line`, uklonjeno je celo — `MoveStop`, oba `line` gettera, parametar
i sam widget. `formatMoveWithNumber` je ostao, jer sada imenuje potez u zaglavlju
polja za komentar.

### Šta je namerno izostavljeno

- **NAG oznake** (`$1` = `!`, `$14` = `⩲`). Tekstualni komentari putuju kroz PGN
  u oba smera; glifovi nemaju polje na `MoveNode`, izvoz ih ne piše, a uvoz
  `!`/`?` baca pri čišćenju tokena. Traži polje, birač u UI-ju i odluku šta sa
  tim što se već baca — sopstvena stavka, ne dodatak uz komentare.
- **Prevlačenje figure van table** u postavljanju pozicije. Dodir na istu
  figuru, dug pritisak i desni klik sada svi prazne polje; prevlačenje bi
  tražilo `Draggable`/`DragTarget` na svih 64 polja i na paleti, što je veće od
  sva tri zajedno a kupuje četvrti način za isto.

Obe stoje kao zasebne otvorene stavke u dnevniku provere.

---

## Dizajnerski prolaz na zasebnoj grani — spojen 28.8.2026

Vizuelni sloj je prvi put dobio svoj prolaz, i to kao eksperiment: zaseban agent
(Gemini) radio je u `git worktree`-u na grani `design/gemini-pass`, dok je ovde
tekao rad na funkcionalnosti. Spojeno istog dana, `2c19ca6`, bez ijednog
konflikta.

### Zašto se spojilo bez konflikta

Zato što je opseg bio uzak i napisan unapred. U Flutter-u izmena dizajna i
izmena ponašanja žive u istom fajlu, pa dva paralelna toka po pravilu prepisuju
ista stabla widgeta. Dogovoreno mu je tačno četvoro: sloj tokena, dva prazna
`ThemeData` bloka u `main.dart`, nova galerija koja postoji samo da se gleda, i
**jedan** pilot ekran. Sve ostalo je pisao kao predlog u `DESIGN-PROPOSALS.md`
umesto da menja kod.

**To je oblik koji vredi ponoviti**, a ne samo detalj ove runde: širok diff bi
bio bačen pri spajanju, a predlog nije. Pilot je bio trening hub — mali,
vizuelan, pokriven testom i van puta rada na stablu poteza.

### Šta je ušlo

- `lib/theme/app_theme.dart` — cela `ThemeData`, koju čitaju i `main.dart` i
  golden test. Namerno jedno mesto: tema je pre toga postojala u dva primerka,
  pa su se screenshotovi renderovali iz teme koju aplikacija ne isporučuje.
- Prefarban sloj tokena, sa **izmerenim kontrastom upisanim uz svaki token**,
  plus `app_spacing.dart` i `app_radii.dart`.
- Popunjena `ThemeData` prestilizuje svih 29 ekrana bez diranja ijednog od njih.
- Galerija na `/design-gallery`, dostupna isključivo kroz stavku iza
  `kDebugMode` na dnu Podešavanja — u release buildu je nema.

### Druga runda: paketi 14–43, spojeni 29.8.2026 (`71d3452`)

Prva runda je bila jedan pilot ekran i predlozi. Druga je odradila ostatak, kao
numerisani paketi na istoj grani: razmaci, tipografija, boje, kontejnerski
tokeni i pravila 23, 24, 25 i 26 koja su iz njih ispala. Devedeset fajlova,
+2990/−1968, bez ijednog konflikta.

Ono što se ne vidi iz diffa je da su **dve stvari bile odluke, a ne migracija**:

- **Pravilo 14 je suženo, ne ukinuto** (`c2e0ae0`). Ranije je govorilo da boja
  koja nosi šahovsko značenje ostaje literal. Zabrana da se `surface` rastegne
  da znači „beli“ ili „crni“ i dalje stoji; ono što je dodato je pošteno
  rešenje — takva boja sme da dobije **token sa domenskim imenom**, koji odlučuje
  čovek i dodaje paket napisan za to, nikad izmišljen usput.
- **Paketi 42 i 43** su dodali prva tri takva tokena (`sideWhite` #F1F5F9,
  `sideDraw` #64748B, `sideBlack` #020617) i prebacili četrnaest literala na
  njih: tri polja u eksploreru otvaranja, obe trake evaluacije u obe
  orijentacije, izabrano stanje u biraču strelica i maketa u galeriji.

Četiri predložene grupe tokena su **odbijene** 29.8.2026 (osmostepena skala za
Syzygy, `boardHighlight`, `brandBase`, `shadow`), pa literali koje bi one
zamenile i dalje stoje — namerno. Obrazloženje je u `report-batch-41.md` u
worktree-u.

Merenja koja su odlučila vrednosti nose testovi, ne komentari
(`chess_app/test/side_token_contrast_test.dart`): trake se razdvajaju međusobno
(4.34 / 4.24 / 18.41), a `sideBlack` se **ne može** razdvojiti od panela iza
sebe ni pri jednoj boji — čisto crno daje 1.18 / 1.44 / 2.03 na tri površine, pa
je to plafon a ne mana tokena, i granicu nosi `borderStrong`.

### Pouka, koja je opštija od dizajna

Od osam nalaza iz pregleda, **tri nisu bila loš dizajn nego netačna tvrdnja**:

- paleta dokumentovana kao 4.5:1 koja meri 2.72 (belo na `brand`, i to kao
  podrazumevani stil dugmeta, dakle za celu aplikaciju a ne za jedan ekran),
- zaglavlje koje garantuje AA za tokene koji ga ne ispunjavaju,
- i screenshotovi ponuđeni kao dokaz, na kojima nema nijednog slova, jer golden
  test ne učitava font.

Isti oblik kao sve u odeljku o ponavljajućem bagu: korak koji prijavi uspeh a
omane sloj niže. Uhvaćeno je samo zato što je **svaki broj preračunat nezavisno
i svaki ekran otvoren u pokrenutoj aplikaciji**. Kad sledeći put neki agent
napiše meru, meri je ponovo.

Vredi zabeležiti i jedan dobar znak: kod tvrdnje o kontrastu je mogao da oslabi
tvrdnju dok se ne poklopi sa bojama — umesto toga je promenio `danger` da tvrdnja
postane istinita.

### Šta ostaje otvoreno

- `DESIGN-PROPOSALS.md` (koren repoa) nosi ostatak: predlozi po ekranima,
  komponentna biblioteka, i **redosled za svetlu temu** — prvo migracija
  preostalih literala, pa svetli tokeni, pa podešavanje. Obrnutim redom svetla
  tema daje belo na belom.
- **Brojka „~53 fajla“ je zastarela od 29.8.2026**, i posle paketa 44 migracija
  boje je gotova. U `lib/` je ostalo **35 literala i svi su tu namerno**:
  strelice (`board_overlay_painter.dart`, 14), Syzygy skala (8), polja table
  (`board_thumbnail.dart` i dva `board_setup_dialog.dart`, po 2), `main.dart`
  seed (2), poteg oko izabranog polja i poteg ispod broja u traci evaluacije
  (2), i dve senke (galerija, plejer). Za četiri grupe tokena koje bi ih
  zamenile odlučeno je da se **ne** prave. Ako neko ubuduće izmeri drugi broj,
  prvo proveri je li dodat nov literal, a ne je li lista pogrešna.

  **Od 29.8.2026. uveče ih je 29**: šest polja table otišlo je u `BoardSkin`
  (odeljak niže). To nije izuzetak od pravila 14 nego njegova druga izmena —
  domenska boja sme da dobije domenski token, a `BoardSkin` je taj token za
  tablu. Strelice ostaju literali i nisu pokrivene.
- Svetla tema je bila namerno **ne**napisana: `ThemeMode` je bio zakucan na
  `dark`, a `setThemeMode` nije postojao nigde u `lib/`. Napisana je 29.8.2026
  (paket 45, `b4fb881`), i istog dana je **faza 5 dodala birač** — tema, tabla i
  figure biraju se u odeljku „IZGLED" u Podešavanjima. Nije više mrtav kod.
  Odeljak niže.
- `DESIGN-BRIEF.md` je posle spajanja ostao na korenu. Pisan je agentu („ovo
  smeš da menjaš"), pa kao projektna dokumentacija tu ne stoji — treba ga
  premestiti u `docs/` kao zapis o tome kako je opseg omeđen, ili obrisati.
- Natpisi na dugmadi su na goldenima i dalje kutije: `textStyle` u temi nema
  `fontFamily`, pa ne hvata font učitan u testu. U pravoj aplikaciji se
  iscrtavaju ispravno, provereno na Windows buildu. Jedan red u `AppTheme` kad
  se bude diralo.

---

## Presuda koja se čitala iz kategorije, a ne sa table — 28.8.2026

Korisnik je prijavio nešto što je zvučalo kao sitnica: u vežbi protiv motora
može se u stablu poteza vratiti na poziciju gde je motor na potezu, odigrati
taj potez sam, i od tada motor igra ono što je bila korisnikova strana.

Tačno, i uzrok je bio da **pojam „korisnikova strana" nije ni postojao**. Motor
je bio definisan čisto reaktivno — posle čovekovog poteza, motor odgovara — što
važi sve dok se čovek ne vrati unazad i ne preuzme motorov potez.

### Šta se našlo dok se tražilo gde ta praznina smeta

Gore od prijave. U `ai_studio_screen.dart`, unutar obrade **motorovog** poteza:

```dart
if (in_checkmate) {
  if (category == 'basic_mate') showSnackBar('Stockfish vam je zadao mat');
  else { _puzzleSolved = true; _showEndgameWinDialog(); }
}
```

Motor je upravo odigrao, dakle mat je uvek onaj koji je korisnik **primio**. Sve
što nije `basic_mate` padalo je u dijalog **„🎉 POBEDA! Uspešno ste zadali mat
Stockfish-u"** i obeležavalo vežbu kao rešenu — pa je `winning_position`
čestitao detetu na matu koji ga je upravo dokrajčio. **Za to nije bila potrebna
nikakva zamena strana**; zamena je samo činila lakim da se dođe dotle.

### Pouka, koja se ponavlja u ovom repozitorijumu

Presuda se izvodila iz **koja je ovo vežba** umesto iz **šta je na tabli**.
Isti oblik kao svuda u odeljku o ponavljajućem bagu: odgovor se čita sa
pogrešnog mesta, a pogrešno mesto se najčešće slaže sa tačnim — dok se jednog
dana ne raziđu.

Zato `core/models/drill_outcome.dart` ne prima ni kategoriju ni „ko je poslednji
vukao": to su dva ulaza koja su davala pogrešan odgovor, pa sada **ne postoji
način da se proslede**. Mat imenuje svoju žrtvu time ko je na potezu. Obe
presude na ekranu idu kroz jednu funkciju, umesto dva pravila koja su se već
jednom razišla. Test je dokazan mutacijom: vraćanje starog pravila obara tri od
deset.

### Ostala tri ekrana su čista, svaki iz svog razloga

Provereno istog dana, jer je pitanje bilo da li isti oblik postoji drugde:

- `repertoire_drill_screen` — strana se **prosleđuje** (`widget.color`), a
  protivnikovi odgovori dolaze iz knjige, ne od motora.
- `blunder_walk_screen` — nema protivnika-motora ni presude o matu; to je
  šetnja kroz već odigranu partiju.
- `endgame_trainer_screen` — presudu daje **server** (`solve.submit`), pa se
  lokalno i ne izvodi. Komentar u fajlu to i kaže.

Praznina je, dakle, bila samo tamo gde se presuđivalo lokalno bez pojma o
stranama.

---

## Teme, boje polja i boje figura — plan i faze 1–5, 29.8.2026

Plan u celini je u [PLAN-TEME-I-TABLA.md](PLAN-TEME-I-TABLA.md); ovde stoji samo
ono što je urađeno i šta treba znati pre nastavka.

Opseg je odlučio vlasnik projekta 29.8.2026: **svetla + tamna + sistemska** tema,
bez dodatnih imenovanih paleta, i **prefarbavanje** postojećih figura umesto
novih kompleta. Koža table je nezavisna od teme aplikacije — zelena tabla je
legitiman izbor i u svetloj i u tamnoj temi.

### Četiri stvari iz koda koje su odlučile oblik

1. **Svetla tema nije bila isključena nego zamka.** `init()` je prepisivao svaki
   sačuvani `themeMode` u `dark`, a svetla `ThemeData` u `main.dart` nije nosila
   `AppColorTokens` — `context.colors` pada nazad na tamne tokene, pa bi svih 29
   ekrana pisalo tamnim tekstom po svetloj podlozi. Ta linija u `init()` je
   jedino što je stajalo između sačuvanog izbora i nečitljive aplikacije.
2. **Boje polja nisu bile podesive.** `flutter_chess_board` crta tablu sa
   `Image.asset` — četiri gotove PNG slike, bira ih enum. Paket to neće dobiti:
   i dalje piše `sdk: <3.0.0` i i dalje zove `onWillAccept`.
3. **Boje figura su bile besplatne.** `chess_vectors_flutter` oduvek prima
   `fillColor` i `strokeColor`, a crne figure i treću, `decorationColor` (oko i
   griva skakača, krst na kralju). Ništa u aplikaciji ih nije prosleđivalo.
4. **Animacija poteza je bila zavarena za sliku**: polje na koje figura sleće
   pokrivalo se **isečkom PNG-a** table, postavljenim na negativan offset unutar
   isečenog kvadrata. Sa farbanim poljima nema šta da se iseca.

### Šta je urađeno

**Faza 1** (`b937af9`) — `lib/theme/board_skins.dart`: `BoardSkin` i `PieceSkin`,
po jedna koža svaka. Namerno **nisu** `ThemeExtension`: koža preživljava promenu
teme, a `pieceImageForAnimation` nema `BuildContext` iz kog bi je čitao.

`BoardSkin.classic` je #F0DAB5 / #B58763 — to nisu izmišljene vrednosti nego
**izmereni pikseli** `brown_board.png`, koji je ravna dvobojna slika a ne tekstura
drveta (120 boja u celom fajlu, sve na spojevima polja). Zato je prelazak na
farbanje piksel u piksel isti, samo bez mutnih spojeva.

**Faza 2** — `lib/widgets/board/skinned_chess_board.dart`, fork `ChessBoard`-a iz
paketa. Paket **ostaje** zavisnost: `ChessBoardController` i `PlayerColor` se
zovu u 35 fajlova, a menja se samo widget koji crta. Uz to: jedna fabrika figura
za celu aplikaciju (`board/chess_piece_image.dart`), pokrivka animacije farba
polje umesto da seče sliku, i sličice i oba editora pozicije crtaju istu tablu —
do sada su bili tri različita: mrka, zelena i tirkizna.

**Promocija prevlačenjem sada pita na srpskom.** To je bila poznata rupa opisana
u zaglavlju `promotion_picker.dart`: svaki potez tapkanjem je pitao na srpskom, a
prevlačenje je otvaralo dijalog paketa („Choose promotion", i uvek četiri bele
figure). Fork ju je zatvorio usput.

Mere: 836 testova (12 novih), 1 preskočen, `flutter analyze` na istih 29 poznatih
`info`-a. Oba tvrđenja o **iscrtavanju** dokazana su mutacijom — zamenom svetlog
i tamnog polja u painteru, pa u pokrivci animacije; oba puta su pala kako treba.

Uživo nije viđeno: [TODO-provera.md](TODO-provera.md), stavka 47.

### Vid i boje — mereno, ne procenjeno, 29.8.2026

Povod je jedna rečenica vlasnika projekta: *„sve je ekstra, boje, kontrasti,
inače sam daltonista"*. To menja šta znači „provereno uživo" na ovom projektu —
njegova potvrda dokazuje svetlinu, veličinu i oblik, a **ne** dokazuje da se dve
boje razlikuju po tonu. Zato je merenje moralo da zameni oko.

**`test/support/color_vision.dart`** — simulacija dihromatskog vida po Viénot,
Brettel & Mollon (1999): jedna 3×3 matrica po deficitu, primenjena u
**linearnom** RGB-u. Uz nju `over()` (spljošti providnu boju na podlogu, jer se
meri ono što je na ekranu a ne ono što je prosleđeno `Paint`-u), WCAG kontrast, i
`worstContrast()` koji vraća najgori slučaj kroz sva tri vida.

**Tritanopija namerno nije tu.** Viénot-ova simplifikacija važi za protan i
deutan i poznato je da za tritan ne valja — sam rad to kaže. Broj koji proizvede
model koji ne važi gori je od nikakvog broja, jer će mu se verovati.

Instrument se proverava pre nego što mu se veruje, kao i sve ostalo ovde: siva
prolazi kroz simulaciju nepromenjena, a crvena i zelena padaju na istu žutu osu.
Prva verzija tog testa je pala i bila je u pravu što je pala — poređenje je bilo
na `double`-ovima, a povratak sRGB → linearno → matrica → sRGB promaši polaznu
tačku za nekoliko desethiljaditih. Poredi se `toARGB32()`, jer je to ono što se
crta.

**Šta su brojke rekle:**

- **Figure prolaze, sve.** Ivica figure naspram polja: najgori slučaj kroz sva
  tri vida i ceo katalog je **3.36:1**, iznad praga 3.0. Ispuna naspram ivice ne
  pada ispod 14.65:1. Žute figure iz kompleta „Visoki kontrast" drže 19.56:1 i
  pod oba deficita — žuto na crnom je jedan od najotpornijih parova koji postoje,
  pa je ta odluka i pod ovim merenjem u redu.
- **Oznaka poslednjeg poteza pada.** `warning` na 45% naspram polja ispod sebe:
  **1.03:1** u najgorem slučaju (plava tabla, tamna paleta, svetlo polje,
  deuteranopija). To nije slab signal po svetlini nego nikakav — oznaka se
  videla isključivo kao promena tona.

**Šta je urađeno s tim.** `ChessBoardPainter` sada crta i **uglove**: četiri
prava ugla ka unutra, u dva poteza — crni oreol pa belo jezgro preko njega. Amber
ostaje netaknut; ovo je **dodato**, nije zamenjeno, jer je vlasnik odobrio kako
tabla izgleda i to nije trebalo prepravljati.

Zašto baš dve boje a ne jedna pametno izabrana siva: crno drži 4.4:1 naspram
svakog polja svake kože, belo drži 3.0:1 naspram svakog tamnog, pa se crtanjem
**oba** garantuje da bar jedno ima ivicu ma na čemu stajalo. Obe su ahromatske,
pa ih simulacija ne pomera uopšte — nema tona koji bi izgubile. To je i jedina
stvar koju test o tome tvrdi: raniji pokušaj je tvrdio da se *kontrast* uglova ne
menja po vidu, a to je netačno, jer se polje ispod njih menja i kad se ugao ne
menja.

Uglovi su i treći kanal povrh drugog: četiri prava ugla ne liče ni na šta drugo
na ovoj tabli, pa oznaka radi i za nekoga ko gleda crno-belu sliku.

Mere: **881 test** (12 novih), 1 preskočen, `flutter analyze` na istih 29
`info`-a. Oba tvrđenja dokazana mutacijom — kad se uglovi ne crtaju, padaju tri
testa; kad im se boje zamene tonovima umesto crno-bele, padaju tri druga.

### Strelice — izmereno 29.8.2026, popravka nije počela

Nije 14 boja nego **pet**, upotrebljenih dvaput: `arrowPalette` (R/G/B/O/P, koje
korisnik bira kad crta) i `_getEngineColor(rank)` (isti komplet, drugim redom,
za pet linija motora). Brief za Gemini je
[brief-arrow-colours-2026-08.md](brief-arrow-colours-2026-08.md); ovde su nalazi.

1. **Dva para su ista boja.** `R`/`P` mere **1.04:1** pod protanopijom — crvena i
   ljubičasta su jedna boja. `R`/`B` 1.07 pod deuteranopijom. A `B`/`O` mere
   **1.07 i pod normalnim vidom**: taj par razlikuje samo ton, za sve. Najbolji
   par u kompletu je 2.00:1.
2. **Svaka strelica nestane na nekom polju.** Spljoštena na 0.75 alfe naspram
   polja ispod sebe, najgori slučaj kroz svih pet koža i sva tri vida: R 1.02,
   G 1.02, B 1.04, O 1.12, P 1.01.
3. **Strelice motora su mnogo manje pokvarene nego što izgledaju**, i to je zamka
   ovog zadatka. Rang je već kodiran dvaput — bojom **i debljinom**,
   `7.0 - (rank - 1) * 1.5`, pa je najbolja linija 7 px a peta 1 px. Zeleno
   naspram crvenog za najbolje-naspram-najgore je 1.53:1 pod deuteranopijom, što
   zvuči loše i preživljava, jer debljina to već kaže. Ono što nema drugi kanal
   je **korisnikova** strelica: sve su 6 px.

**Boje su izabrane 29.8.2026** — `lib/theme/arrow_colors.dart`, sa
`test/arrow_color_contrast_test.dart`. Odeljak niže objašnjava zašto je prag
1.5, a ne 1.8.

**Nov bag, nađen usput i nije od strelica: značka evaluacije je nečitljiva u
svetloj temi.** `badgeTextColor` je `context.colors.canvas` — skoro crno u tamnoj
temi (8.8:1, u redu) i skoro belo u svetloj, gde rang 1 meri **1.55:1**. Svih
deset kombinacija u svetloj temi je ispod 4.5:1. Ovo je postalo dohvatljivo tek
fazom 5, kad je svetla tema mogla da se izabere. Tekst značke mora da se bira iz
svetline same značke, ne iz teme. Claude-ovo, nije počelo.

### Zašto je prag za strelice 1.5, a ne 1.8 — 29.8.2026

Batch 47 (Gemini) je dobio prag **1.8** za svaki par boja i rečenicu da boje
moraju da ostanu prepoznatljive po imenu. Isporučio je 1.771 i **rekao da nije
stigao do 1.8**, sa označenim ćelijama — što je bilo ispravno ponašanje i razlog
što je runda bila jeftina. Svih trideset brojki za parove, svih deset za halo i
svih šest za rangove motora prekontrolisano je nezavisno i **sve su tačne**;
četiri od pet simuliranih heksova promaše za jedan bit u poslednjem mestu, što je
zaokruživanje pri ispisu i ništa izvedeno iz njih se ne pomera.

Cena je bila narandžasta `#88370E`, koja je **braon**, i crvena `#FA8158`, koja
je losos — a njih dve su na 5° razmaka po tonu, dakle ista boja razdvojena samo
svetlinom.

**Onda je pretražen prostor, i ispalo je da 1.8 nikada nije ni bilo dostižno:**

| šta se drži fiksno | najveći dostižan prag |
|---|---|
| ton u ±15° od imena | **1.50** |
| ton u ±20° od imena | **1.50** |
| ton u ±25° | 1.60, ali narandžasta odluta u žutu |
| ton napušten | 1.77 — tačno ono što je Gemini našao |

Razlog je strukturni: pod oba deficita pet boja pada na **dve** tonske ose, pa
sve moraju da se razdvoje svetlinom, a pojas svetline koji ih drži dalje od crne
i bele ograničava koliko to može da ide. Zamena narandžaste tirkiznom na 180°
ostavlja plafon na tačno 1.50 — dakle nije stvar izbora tona.

Dve greške u prvom brifu, obe moje:

1. **Halo pravilo je bilo prazno.** „Nijedna boja ne sme biti unutar 1.2:1 od
   *obe*, crne i bele" ne može da se desi: ispod 1.2 prema crnoj traži L < 0.01,
   ispod 1.2 prema beloj traži L > 0.825. Gemini je pročitao strože — svaka boja
   čisti 1.2 prema obema — i to je jedino čitanje koje išta ograničava. Popravio
   je pravilo umesto mene; granica je sada 1.1 i u tom, strožem čitanju.
2. **Prepoznatljivost je bila rečenica, a prag broj.** Kad jedno ima meru a
   drugo nema, žrtvuje se ono bez mere, i to je ispravno ponašanje agenta.

Finalne vrednosti su birane pretragom koja **minimizuje odstupanje tona**, ne
prvim rešenjem koje prođe: `#FF2929`, `#FF9429`, `#85FF85`, `#00188F`,
`#910FB3` — odstupanja 0°, 0°, 0°, 10°, 2.5°. Najgori par 1.50 (B/P,
protanopija).

**Test sada meri i prepoznatljivost**, i prvi pokušaj te mere je bio pogrešan:
jedinstven pojas svetline 0.28–0.80 propuštao je `#88370E` (ton 20, unutar
dozvole; svetlina 0.29, unutar pojasa). Braon je prošao test napisan da uhvati
braon — uhvatio ga je test za parove, što je sreća a ne pokrivenost. Topli
tonovi gube ime kad potamne a hladni ne: tamna narandžasta je braon, tamna
crvena je bordo, a mornarsko plava je i dalje plava. Prag je zato **0.45 za luk
od crvene do žute i 0.28 za ostalo**. Nađeno mutacijom, kao i sve ostalo ovde.

### Ožičenje strelica — 29.8.2026

Sve troje je urađeno i sve troje je isti potez: dodaj kanal, ne prepravljaj boju.

**Strelica ima obrub.** `_drawSingleArrow` sada crta u tri prolaza — crni obrub
(+5 px), beli (+2.5 px), pa sama strelica. Oba obruba su ahromatska, pa se ne
pomeraju pod simulacijom, a crno drži 4.4:1 naspram svakog polja svake kože i
belo 3.0:1 naspram svakog tamnog. **To je ono što je paleti dozvolilo da stane
na 1.5** — spljoštena na svoju alfu, svaka boja strelice pada između 1.01:1 i
1.12:1 naspram nekog polja, i nijedan izbor pet boja to ne popravlja, jer je
problem polje a ne paleta.

**Značka evaluacije više ne uzima boju iz teme.** `badgeTextColor` je uklonjen
iz `ChessBoardPainter` i sa svih šest mesta poziva; tekst se sada bira iz
svetline same značke (`ChessBoardPainter.readableOn`). To popravlja četiri od pet
rangova odmah. **Peti se ne da popraviti izborom boje**: crvena `#FF2929` stoji
na svetlini gde crno daje 3.04:1 a belo 3.74:1 i nijedno ne stiže do 4.5:1, jer
je ispuna srednje tonirana. Zato glif nosi **oba** — ispunjen boljim, oivičen
drugim — pa je ivica unutar samog glifa 21:1 ma na čemu stajao. Ista logika kao
strelica i kao uglovi poslednjeg poteza.

**Pločica se više ne zatamnjuje, i to je popravka a ne previd.** Neizabrana
pločica se crtala na 40% preko panela — tako je radio i prvobitni dizajn. Mereno
naspram tamne teme: `Crvena` postaje `#782934`, `Narandžasta` postaje `#785434`,
oba topla tona **ispod praga svetline koji deli narandžastu od braon** — tačno
onaj promašaj zbog kog je odbijena Gemini-jeva paleta. Uz to je najgori par pao
sa zagarantovanih 1.50:1 na **1.10:1**, i to u kontroli čiji je jedini posao da
se boje razlikuju. Birač koji zatamnjuje ono što prikazuje ne prikazuje ništa.
Izbor nose prsten i sjaj, za to i služe. Nađeno tako što je vlasnik poslao
screenshot, pa su boje **izmerene onako kako se crtaju** umesto procenjene okom.

**Pločica u biraču ima slovo.** `ArrowColorButton` prima `ArrowColor` umesto
boje i tooltipa (koji su bili otkucani na osam mesta), i crta inicijal srpskog
imena: **C, N, Z, P, Lj** — pet različitih, što je sreća koju vredi iskoristiti.
Pet krugova koji se razlikuju samo bojom je pet istih krugova za nekoga ko boje
ne razdvaja, a tooltip progovori tek na hover ili dug pritisak.

`arrowPalette` je nestao iz painter-a; `_getColor` je `ArrowColor.byId`, a
`_getEngineColor` mapira rang na katalog uz **nepromenjen redosled** (1 zelena,
2 plava, 3 narandžasta, 4 ljubičasta, 5 crvena) — to je ono što je čitalac
naučio. Rang i dalje nosi i debljina, `7.0 - (rang - 1) * 1.5`, i to je kanal
koji zapravo preživljava deficit.

Mere: **900 testova** (11 novih), 1 preskočen, analyze na istih 29. Tri mutacije:
bez obruba pada 4 testa, stari zeleni literal za rang 1 pada 1, `readableOn` koji
uvek vraća belo pada 2.

**Šta se vidi na renderu, i kako je pitanje zatvoreno.** Obrub radi — svaka
strelica se čita na svakoj koži, i to je bio glavni cilj. Ostalo je otvoreno da
li 1.50:1 dovoljno razdvaja plavu od ljubičaste, jer na simuliranom renderu
deluju skoro isto, i zapisao sam da bi rešenje bio kanal a ne boja.

**Nije potrebno. Vlasnik projekta, koji je daltonista, potvrdio je 29.8.2026. da
ih razlikuje** — na živoj tabli, u obe teme. To je najbolji dokaz koji ovo
pitanje može da dobije, bolji od simulacije, jer simulacija modeluje
dihromatiju a stvarni deficit je najčešće blaži. **Ako neko ubuduće bude
„popravljao" taj par isprekidanom linijom ili slovom uz rep — ovo je razlog da
ne.** Plafon od 1.50 je dovoljan.

Šta ovo *ne* znači: par je i dalje najslabiji u katalogu i test ga i dalje drži
na 1.50. Potvrda je da je 1.50 dovoljno, ne da razdvojenost više nije bitna.

### Šta sledi

- **Paket 45 (Gemini)**: gotov i spojen 29.8.2026 (`b4fb881`).
  `AppColorTokens.light` + `AppTheme.light`, svih trideset uloga, `theme:` u
  `main.dart` umesto seed-a. Ništa se ne vidi — `themeMode` je i dalje `dark`.

  Presuda harness-a bila je FAIL i **bila je uglavnom do kapija**: dva prava
  propusta (galerija je čitala `Theme.of(context).brightness`, što druga
  polovina pravila 19 zabranjuje, i natpis `Light` na srpskom ekranu), a treća
  kapija je pala na fajlovima koje je zadatak **tražio**. Svih trideset
  navedenih kontrasta prera­čunato je nezavisno i svih trideset je tačno; test
  registracije dokazan je mutacijom.

  Ono što nijedna kapija nije mogla da vidi našlo se otvaranjem screenshota:
  petnaest pločica palete nosilo je heks i kontrast **kao otkucan tekst**.
  Tačno za tamnu paletu, i laž onog trenutka kad isti ekran nauči da crta
  svetlu — `#1E293B` ispod belog kvadrata. Sada se oboje čita iz same boje.
  Isti oblik kao sve u odeljku o ponavljajućem bagu: nešto što **prijavljuje**
  vrednost umesto da je pročita.

  `report-batch-45.md` nije napisan (pravilo 22). Brojke su zato provere­ne
  ručno.
- **Paket 46 (Gemini)**: gotov i spojen 29.8.2026. Pet tabli (`classic`,
  `Zelena`, `Plava`, `Visoki kontrast`, `Siva`) i tri kompleta figura
  (`Klasične`, `Tople`, `Visoki kontrast`), i test koji **množi oba kataloga**
  umesto da nabraja slučajeve. Dokazan tako što je dodata šesta, namerno
  pokvarena tabla — petlja ju je uhvatila na dva mesta, što spisak ručno
  napisanih slučajeva ne bi.

  Sve brojke iz `report-batch-46.md` prera­čunate su nezavisno i sve su tačne —
  drugi paket zaredom. Merilo nosi **ivica** figure, ne ispuna: bela ispuna na
  svetlom polju meri oko 1.3:1 i oduvek je merila toliko.

  Tamno polje table „Visoki kontrast" je srednje sivo (#737373), a ne skoro
  crno, i izveštaj kaže zašto: na #222222 crna ivica figure meri 1.32:1, pa bi
  tabla napravljena da se bolje vidi izbrisala svaku crnu figuru.

  Kapija `strings` je oborila paket zbog **srpskih imena koja mu je zadatak
  tražio** — isti oblik kao kod paketa 45. Popravljeno u harness-u: kapija sada
  prima spisak fajlova u kojima paket sme da **doda** string; brisanje i izmena
  i dalje padaju, jer je to polovina pravila 12 koja nešto čuva.

- **Nalaz koji niko nije tražio, i jedini koji traži odluku**: oznaka poslednjeg
  poteza je `warning` — ispuna na 45% plus obod od 2,5 px — i **po svetlini se
  jedva razlikuje od polja ispod sebe**. Ispuna prema neoznačenom polju meri
  1.05–1.94 kroz svih pet tabli i obe palete; najgore je na plavoj tabli sa
  tamnom paletom (1.05 i 1.06). Za tamnu paletu na klasičnoj tabli: 1.10 na
  svetlom polju, 1.35 na tamnom.

  **To je merenje svetline, a ne presuda.** Žuto preko krem polja i dalje
  izgleda žuće, a promena tona se vidi i kad je razlika u svetlini mala — zato
  ovo niko do sada nije prijavio kao bag.

  **Razrešeno 29.8.2026, i razrešeno je u drugom smeru nego što je pisalo
  ovde.** Onaj argument — „promena tona se vidi i kad je svetlina ista" — traži
  oko koje razlikuje tonove. Vlasnik projekta je daltonista, a korisnici su deca
  među kojima otprilike svaki dvanaesti dečak ima crveno-zeleni deficit. Za njih
  taj argument ne važi, pa oznaka koja je nosila samo ton nije nosila ništa.
  Rešenje je ono koje je gore i predviđeno: **oznaka koja ne zavisi od boje.**
  Odeljak niže.
### Faza 5 — birač, 29.8.2026

Odeljak **„IZGLED"** u `settings_screen.dart`, iznad „NALOG": tema
(Sistem / Svetla / Tamna) kao čipovi, pa pet tabli i tri kompleta figura kao
pločice koje se tapkaju. `setThemeMode` pamti izbor, a **prisila na tamnu temu u
`init()` je uklonjena**.

Ta linija nije samo ignorisala sačuvanu vrednost nego ju je i **prepisivala** na
svakom pokretanju, i to od `6780886` (13.8.2026). Praktična posledica: svako ko
je otvorio aplikaciju posle tog datuma već je izgubio svoj izbor, pa „oživljene"
svetle teme ima samo na instalaciji starijoj od toga. Redosled faza je i dalje
bio tačan — polje dejstva je samo manje nego što je plan pretpostavljao.

Tri odluke koje je doneo kod, a ne plan:

- **Pregled nije dvaput `BoardThumbnail`.** Tabla se sudi celom tablom i dobija
  je na 72 px. Komplet figura je ispuna, ivica i dekoracija — ništa od toga ne
  preživljava polje od devet piksela — pa dobija četiri figure na 30 px, na dva
  polja **izabrane** table: bela figura na tamnom polju i crna na svetlom, pa
  obrnuto, jer su to dva para koja padaju.
- **Prsten izbora je 2 px u oba stanja**, samo druge boje kad nije izabran.
  Ivica koja menja debljinu menja širinu pločice, pa se `Wrap` prelama pod
  prstom koji ju je upravo dodirnuo.
- **Sve je `Wrap`.** Tri srpska čipa su već 330 dp naspram 316 koliko kartica
  ima na telefonu od 360 dp, pa se red teme namerno prelama 2 + 1.

Dvanaest testova u `test/appearance_settings_test.dart`, i svaki tvrdi šta se
**iscrtava** posle dodira, a ne šta je zapamćeno: svetli tokeni ispod ekrana
(poređeni polje po polje — `Theme` dok animira izdaje *lerpovan*
`AppColorTokens`, pa identitet nikad ne pogađa), `SkinnedChessBoard` bez
prosleđene kože koji crta zeleno, `chessPieceWidget` bez prosleđene kože koji
nosi toplu ispunu, i koža koja preživi prelazak na svetlu temu. Dokazano
mutacijom: vraćanje prisile u `init()` i praznjenje oba `onTap`-a obara sedam od
dvanaest.

**Uz put su nađena dva prelivanja, oba zatečena i oba na ovom ekranu.** Na 360 dp
red „Maksimalno vreme razmišljanja engine-a:" u kartici motora prelivao se za
303 px, a zaglavlje kartice naloga za 26 — nevidljivo, jer release build seče
umesto da išara. Oba natpisa su sada `Expanded`, zajedno sa druga dva reda
natpis/vrednost u istoj kartici. Nađena su samo zato što novi test pumpa na
`Size(360, 640)`.

Mere posle faze 5: **869 testova** (12 novih), 1 preskočen, `flutter analyze` na
istih 29 poznatih `info`-a.

Uživo nije viđeno: [TODO-provera.md](TODO-provera.md), stavke 47, 48 i 49.

## Sopstvene partije kao korpus — predlog, 30.8.2026

Pitanje je bilo: korisnik preda arhivu od nekoliko hiljada svojih partija sa
Lichess-a — šta se s njom može uraditi, a ne može se uraditi partiju po partiju?
Odgovor je u [PLAN-MOJE-PARTIJE.md](PLAN-MOJE-PARTIJE.md). **Ništa od toga nije
napisano**; dokument je predlog, ali su brojke u njemu **merene** na stvarnoj
arhivi od 4073 partije, a ne procenjene.

Tri nalaza koja odlučuju šta vredi graditi:

- **Signal živi između 6. i 20. poluteza.** Na 12. potezu 4073 partije stoje na
  2749 različitih pozicija (najčešća se ponavlja 52 puta); do 20. ih je 3869 i
  najčešća se ponavlja 8 puta. Posle desetog poteza svaka je partija skoro
  jedinstvena i statistika po poziciji prestaje da znači išta.
- **Izveštaj o otvaranjima je besplatan** — nula motora, nula mreže, samo
  brojanje. Na uzorku: 14 pozicija na 10. polutezu koje se ponavljaju bar 8 puta
  a nose ispod 42%, i u jednoj od njih isti potez odigran 33 od 35 puta. To je
  navika, ne varijansa.
- **Završnice preko Syzygy-ja su jeftine i tačne.** Cela arhiva ima 8673
  različite pozicije sa ≤7 figura — oko 22 minuta kroz postojeći `lichessPacing`
  — i 234 partije koje su ušle u tablice a nisu dobijene. Presuda „izgubio si
  dobijenu" je činjenica, ne mišljenje motora, što je tačno ono što
  `tablebaseService.js` čuva.

Ono što nedostaje je **jedno**: tabela sa partijama korisnika. `blunder_games` je
uvezen javni skup, ne korisnikov. Sve ostalo u planu je upit nad tom tabelom.

Skupo je samo prolaz motorom: ~273k pozicija za celu arhivu, ~7–8 sati na dubini
14 u jednoj niti. To je noćni posao na desktopu, ne na dropletu od 960 MB, i
nikako ne kroz cloud-eval — jedan izlazni IP za sve korisnike.

**Usput provereno uživo 30.8.2026**: Lichess daje partije **bilo kog** naloga
nepotpisanom pozivaocu (HTTP 200, bez tokena), pa je priprema za protivnika isti
izveštaj usmeren na drugog igrača. Parametar `vs=` vraća samo međusobne partije,
a `opening=true` dodaje `[ECO]` i `[Opening]` — ECO baza lokalno ne treba.
Detalji i jedna odluka koja ostaje proizvodu (dozvoliti li profilisanje
imenovanog deteta) su u planu.

**Podela posla dogovorena 30.8.2026** i upisana kao sekcija 8 plana: Claude —
šema, serverska logika, prava pristupa i sve što je *garancija*; Gemini — UI,
izolovana logika na klijentu i widget testovi. Linija nije „server naspram
klijenta" nego **koliko košta pogrešan odgovor**: brojač koji se računa u UI-ju
može da izbroji samo ono što je do njega stiglo, a rangiranje na klijentu samo
ono što mu je poslato — pa su oba prešla na serversku stranu. Pre nego što bilo
šta osim uvoza krene: **šema mora biti zamrznuta i mora postojati zasejana
fixture baza**, inače se gradi UI nad oblikom koji se još pomera.

**Faza 0 napisana 30.8.2026** — šema je zamrznuta. Tri tabele u `db.js`
(`user_games`, `user_game_imports`, `mistake_reviews`) i čist modul
`services/gameArchive.js` koji od jedne PGN partije pravi red ili **imenovano
odbijanje** (pet razloga, i tally odbija svaki šesti). Kolone koje nose ugao
gledanja zovu se po **subjektu**, ne po vlasniku reda — ista tabela nosi i
protivnikovu arhivu, pa bi imena po vlasniku učinila svaku agregaciju pogrešnom
čim se okrene ka nekom drugom, i to pogrešnom uz uredne brojeve. Uslov u bazi
drži `read = stored + duplicate + skipped` kad run stane na `done`, a
`assertBalanced()` puca i pre toga. Testovi: 541 → **556**, svi zeleni.

Modul je pušten preko **stvarne arhive od 4126 partija** (30.8.2026): 4126
pročitano, 4126 redova, nijedna preskočena ni duplirana; ECO na svima, sat na
3632 (starije partije su od pre nego što ih je Lichess beležio), 471 partija
ušla u domet tablica, 276.877 poluteza za 68 sekundi. Parsiranje, dakle, neće
biti usko grlo uvoza — stream hoće.

**Provereno uživo — korisnik, log u 23:40 29.8.2026**: `initDB()` je prošao nad
upravljanom bazom i prijavio `user_games`, `user_game_imports` i
`mistake_reviews` odmah posle `room_guests`, a server je podigao port 3000.
Dakle DDL je *primenjen*, ne samo napisan — sa oba check uslova i parcijalnim
indeksom, koje baza sme da odbije pri kreiranju a nije.

Sledeće na redu je sam uvoznik (jedan stream sa Lichess-a, upis kroz tally) i
tek onda sve ostalo iz plana.

**Uvoznik napisan 30.8.2026** — `services/gameArchiveImport.js` i
`routes/userGames.js` na `/games`. Cela arhiva je **jedan stream**, ne hiljade
zahteva, pa ograničenje nije broj upita u sekundi nego to što server ima jednu
adresu za sve korisnike — zato i taj jedan zahtev ide kroz isti pacer kao
explorer. Traje minutima, pa ruta vraća 202 i `importId`, a klijent pita kako
ide; run koji padne upiše svoj razlog u svoj red, jer u trenutku pada odgovora
odavno nema.

Četiri ponašanja koja treba znati: nastavlja se od `MAX(played_at)` za tog
subjekta (drugi uvoz povuče samo novo); drugi istovremeni run se odbija sa 409
umesto da udvostruči svaki brojač; run koji je ostao `running` posle pada
procesa se posle pola sata proglašava neuspelim, jer bi inače jedan pad zauvek
blokirao korisnika; `subject_is_owner` je u ruti fiksiran na `true`, pošto
odluka o tuđim arhivama (sekcija 6 plana) ne sme da stigne kroz neiskorišćen
parametar.

Deljenje streama na partije je jedino mesto gde se podaci mogu izgubiti tiho, pa
nosi najjači test: ista arhiva pušta bajt po bajt i odjednom mora da da iste
partije. **Dokazano mutacijom** — kad se rep pusti odmah, pada pet testova.
Testovi: 556 → **569**, svi zeleni. Uživo još nije viđeno:
[TODO-provera.md](TODO-provera.md), stavka 52.

**Otpremanje fajla je glavni put — odluka vlasnika projekta, 30.8.2026.**
Korisnik sam skine PGN sa Lichess-a i preda ga aplikaciji
(`POST /games/import/file`, multipart, do 25 MB, čita se kao stream i briše kad
run završi). Time nestaje cela klasa rizika koju povlačenje sa servera nosi —
server ima jednu adresu za sve korisnike, pa je 429 koji zaradi jedan uvoz kvar
za sve — i radi za Chess.com, ChessBase ili turnirski PGN bez integracije po
izvoru. Cena je osvežavanje u jednom dodiru: ručni fajl nema `since`, pa drugi
upload ponovo pročita celu arhivu i sve padne kao duplikati. To je rasipno, ne
pogrešno, i jeftinije od druge greške.

Povlačenje sa Lichess-a i dalje postoji i i dalje je testirano; **da li ostaje,
otvoreno je** — to je jedini deo ovoga koji troši dozvolu zajedničku za svu decu
u aplikaciji.

Mereno na stvarnom fajlu od 8,7 MB, kroz stream: 4126 partija, 4126 redova,
nijedna preskočena, brojevi se slažu, **40 s i 209 MB RSS u vrhu**. Na dropletu
od 960 MB memorija je važnija od vremena, i zato upload ide na disk pa se čita
nazad umesto da stoji kao jedan string. Testovi: **570**.

## Izveštaj o otvaranjima — sekcija 1, napisana 30.8.2026

`opening_nodes` u `db.js`, `services/openingLeaks.js` i
`GET /games/openings/leaks`. Jedan red po ranoj odluci subjekta — pozicija pred
njim i potez koji je izabrao — upisuje ga uvoznik u istom prolazu u kom ionako
računa `min_men`, pa ne košta ništa dodatno.

Ključ je `fen_key`, **isti onaj koji koriste `repertoire_moves`**: transpozicije
su veći deo poente, a isti ključ znači da je diff repertoara (sekcija 4)
spajanje tabela a ne drugi dogovor koji neko mora da održava. Test tvrdi da se
dva `fenKey`-a slažu, jer dva zapisa istog ključa ne bi pukla — dali bi **prazan
diff**, što se čita kao „nikad nisi izašao iz repertoara".

Prozor drži skladište: dublje od 20. poluteza se ništa ne upisuje, a traženje
dubljeg izveštaja je `RangeError`, ne tiho uži odgovor. Partije kojima čvorovi
nisu upisani se broje i vraćaju kao `gamesWithoutNodes` — prazan izveštaj inače
izgleda isto kao igrač bez slabosti. `POST /games/openings/backfill` ih dopuni
ponovnim odigravanjem UCI poteza koji već stoje u redu.

**Mereno na stvarnoj arhivi od 4126 partija, kroz produkcioni kod:** 18934
različite pozicije u prozoru, 298 dostignutih bar 8 puta, **78 označenih** ispod
42%. Najjači nalaz je tačno oblik koji je plan predvideo — crnim, jedna pozicija
dostignuta 121 put, prolaznost 41,3%, i isti potez odigran 92 puta. Još dva: 53
partije na 38,7% sa istim potezom 52 puta, i 48 partija na 39,6% sa istim
potezom 47 puta.

Ta brojka zatvara i pitanje dozvole. Suđenje je opciono (`&judge=true` uz
korisnikov `X-Lichess-Token`, koji ruta sudije ionako zahteva) i sudi glavni
potez u prvih N pozicija: **deset zahteva za izveštaj od deset, 78 da se osudi
svaki nalaz** — oko dvanaest sekundi kroz postojeći pacer. Šaka zahteva, ne
skeniranje, pa lični tokeni po korisniku nisu potrebni da bi ovo bilo isplativo.
Token koji nedostaje ili je odbijen **ne obara izveštaj**: brojevi su izračunati
pre nego što se bilo šta pita Lichess, a svaki čvor pojedinačno pada na
`unknown`.

Testovi: 570 → **584**. Uživo nije viđeno: [TODO-provera.md](TODO-provera.md),
stavka 53.

## Provera završnica preko tablica — sekcija 2, napisana 30.8.2026

`tablebase_cache` i `endgame_audits` u `db.js`, `services/endgameAudit.js`, tri
rute pod `/games/endgame`. Nalazi se upisuju u `mistake_reviews` sa
`kind = 'tablebase'` — tabelu napravljenu za njih još u sekciji 0, čiji check
uslov odbija red kojem fali bilo koja od dve presude.

**Jedan upit po poziciji, ne dva.** Odgovor tablice nosi kategoriju za svaki
legalan potez, pa pozicija *pre* poteza već kaže koliko vredi svaki potez
uključujući odigrani. Pozicija posle se nikad ne pita. Ono što treba pogoditi su
dve perspektive: kategorija pozicije pripada strani koja je na potezu, dakle
igraču, a kategorija svakog poteza pripada onome ko igra sledeći, dakle
protivniku — pa je igračev ishod posle sopstvenog poteza negacija te kategorije.

**Mereno na stvarnoj arhivi, bez mreže:** 471 partija je ušla u tablice, a
njihova provera pita **4255 pozicija** — samo igračevi potezi, samo u dometu.
Oko **10,6 minuta** na postojećem tempu od 150 ms, ispod 22 minuta koliko je
plan procenio.

Dva merenja su ispravila projekat, i oba su upisana tamo gde je stajala pogrešna
tvrdnja:

- **Pozicije završnica se ne ponavljaju unutar jedne arhive.** Sve 4255 su
  različite. Materijal se ponavlja jako — 308 potpisa, uglavnom top i pešaci —
  ali tačna pozicija ne, pa `tablebase_cache` prvom prolazu ne štedi ništa.
  Vredi za svaki sledeći: ponovna provera je besplatna, a inkrementalna posle
  dvadeset novih partija pita koliko ima u tih dvadeset. Prvobitno obrazloženje
  te tabele — da se završnice raznih igrača poklapaju — bilo je nagađanje i bilo
  je netačno.
- **Ključ od pet polja košta 83 od 4255 upita**, ispod 2%. Zadržati polupotezni
  brojač, koji razdvaja dobitak od `cursed-win`-a, praktično je besplatno.

`positions_unknown` je zaseban brojač i ne sabira se ni sa čim. Pozicija koju
tablica ne presuđuje (`unknown`, `maybe-win`, `maybe-loss`) nije pozicija koju je
igrač odigrao dobro — nju niko nije presudio, a svrstati je bilo gde pretvorilo
bi jedino obećanje ove funkcije, da je presuda ovde činjenica, u nagađanje.

Testovi: 584 → **596**. Uživo nije viđeno: [TODO-provera.md](TODO-provera.md),
stavka 54.

## Ponavljanje sopstvenih grešaka — sekcija 3, napisana 30.8.2026

`services/mistakeReviews.js` i `routes/mistakeDrill.js` na `/games/mistakes`.
Nova tabela nije trebala: provera završnica već puni `mistake_reviews`, a ovo je
polovina koja iz toga uči.

**SM-2 nije prepisan.** `schedule()` iz `spacedRepetitionService.js` je čista
funkcija nad `ease_factor`, `repetitions` i `lapses`, a ova tabela te kolone
zove isto — što je i bio ceo argument za paralelnu tabelu umesto nullable
`lesson_id`. Test oceni stavku i tvrdi da su upisane vrednosti jednake onome što
`schedule()` vrati, pa druga kopija računice ne može da se pojavi a da test
ostane zelen.

Redovi stižu sa dve strane. Provera završnica upisuje svoje, na serveru, iz
tablica. Nalazi motora stižu **sa klijenta**, kroz `POST /games/mistakes`, jer
je prolaz motorom kroz celu arhivu oko 273k pozicija i noćni posao na desktopu —
na dropletu od 960 MB tome nije mesto. Ta vrata proveravaju šta im se preda:
svaki `game_id` se ponovo proverava prema partijama samog pozivaoca, jer je
`game_id` sa klijenta broj koji je neko mogao i da pogodi.

Odgovor na paket je **tally**, ne `ok` — predato, upisano, već postojalo,
odbijeno sa imenovanim razlozima (`no-game`, `no-ply`, `no-position`, `no-move`,
`no-swing`, `game-not-yours`) — i puca ako se ne slažu. Isti oblik i isti razlog
kao kod uvoznika.

`GET /games/mistakes/recurrence` je rangiranje zbog kojeg drill uopšte vredi:
jedan propušten viljušak je loše veče, isti motiv propušten četrdeset puta je
slabost. Greške motora se grupišu po taktičkom motivu, a one iz tablica po
**potpisu materijala** — jer je merenje iz sekcije 2 pokazalo da se tačne
pozicije završnica nikad ne ponavljaju, a materijal se ponavlja stalno.

Dva baga koja su testovi uhvatili, oba tiha: `Number(null)` je 0, pa je nalaz
bez swinga prolazio `Number.isFinite` proveru i bio bi upisan kao greška koja
nije koštala ništa; i indeks odbijenice izvučen preko `indexOf` imenuje prvi od
dva identična nalaza dvaput.

Testovi: 596 → **610**. Uživo nije viđeno: [TODO-provera.md](TODO-provera.md),
stavka 55.

## Repertoar: gde sam u stablu — izvedena granica, 31.8.2026

Vlasnik je prijavio da je gradnja repertoara zbunjujuća: ne zna gde je u stablu,
dokle je stigao, nema pregled. Nije bila stvar ukusa — ekran to nije ni mogao da
kaže.

**Red je držao gole FEN-ove.** Putanja do pozicije nigde nije postojala, pa je
jedina orijentacija bila „Još N u redu", dužina liste koja se ne vidi. Red sada
nosi i putanju (`_Pending`), a zaglavlje ispisuje liniju numerisanu kao u
knjizi: `1.e4 c5 2.d4 cxd4 3.c3 dxc3 4.Nxc3`.

**Red je živeo u memoriji ekrana.** Zatvaranje ekrana ga je bacalo; povratak je
kretao od korena i **ponovo trošio Lichess kvotu** na odgovore koji su već
plaćeni. Nov `services/repertoireFrontier.js` ga **izvodi** iz dve tabele koje
već postoje — `repertoire_moves` (šta je učenik odlučio) i `opening_replies`
(šta protivnik igra, upisano kad je pozicija prvi put otvorena). Nijedan zahtev
ka Lichessu; isto na svakom uređaju. Red nikad nije bio činjenica vredna
čuvanja, nego posledica.

Dve vrste otvorenih pozicija izlaze iz šetnje, i obe su pitanje koje ekran već
ume da postavi: `undecided` (ništa nije izabrano) i `unopened` (izabrano je, ali
odgovori nikad nisu uzeti, pa linija staje).

**Redosled je `reach`, a ne širina ni dubina.** `reach` je proizvod protivnikovih
udela duž putanje — koliko često partija zaista stigne dovde. Glavna linija na
osmom polupotezu (0.5 × 0.6 = 0.30) pretiče treću po redu stranputicu na drugom
(0.20), i pretiče je sve dok joj sopstvena verovatnoća ne padne dovoljno. To je
ono što je vlasnik tražio kao „prvo u dubinu, pa se postepeno širi", samo
izračunato umesto pogođeno. Sopstveni potezi ne dele `reach`: koji od svojih
poteza igra je odluka, ne novčić.

**`repertoires.root_path`** (novo, `ALTER ... ADD COLUMN IF NOT EXISTS`) pamti
poteze kojima se stiglo do korena. Bez njega putanja počinje u vazduhu:
repertoar građen od četvrtog poteza čita se kao da je partija tu i počela. Prazan
je za svaki repertoar napravljen ranije i za onaj iz zalepljene pozicije — tada
se numeracija čita iz samog FEN-a (`4...Nc6 5.Nf3`), što je istina umesto
izmišljene otvaranja.

Šetnja ima tavanice (`MAX_NODES` 4000, `MAX_PLY` 60) i **kaže** kad ih dodirne
(`truncated`), umesto da tiho vrati kraći odgovor. Knjiga se pita jednom po
talasu, ne jednom po grani.

### Strelice sa statistikom — 31.8.2026

Dva sloja, nikad oba odjednom. Tri skupa strelica koji odgovaraju na tri
različita pitanja nisu bogatiji, nego nečitljivi — a značke bi bile procenti
različitih stvari jedan pored drugog.

- **Dok sam ja na potezu**: potezi koje sam već izabrao. Glavni nosi zvezdicu i
  najdeblju liniju; `rank` u `EngineArrow` već nosi debljinu **i** boju, pa je
  zvezdica treći kanal. Koji je potez glavni ne sme da počiva na nijansi.
  Procenat dolazi iz knjige **ako je već otvorena** — strelica ne vredi
  Lichess zahteva koji niko nije tražio.
- **Posle mog izbora**: protivnikovi odgovori, sa table pomerene za moj potez.

Broj uz strelicu je **udeo**, ne rezultat. Udeo odlučuje da li potez mora da se
sprema; „kako su te partije prošle" na strelici poziva da se bira najveći broj,
što je pogrešna pouka, i ostaje u panelu ispod gde ima mesta da se objasni.

`Dalje` je sada **stanica, ne korak**. Odgovori su se dovlačili, brojali i
bacali — ekran je trošio zahtev na njih i nikad ih nije pokazao onome ko ih je
platio, iako oni odlučuju kako izgleda ceo sledeći talas. Sada se vide, pa se
ide na `Sledeća pozicija`. Tabla je u tom stanju zaključana: pokazuje poziciju u
kojoj je protivnik na potezu, a potez povučen tu bi bio ocenjen kao učenikov.

**Šta ovim nije urađeno** — ništa više. Svih pet stavki sa te liste je
urađeno 31.8.2026: redosled unutar sesije i orezivanje grane u odeljku ispod,
a preostale tri (blok iz jednog čvora, „vrlo poznat" čvor, ponavljanje linije od
početka) u odeljku „Repertoar: vežba je linija". Jedna sa te liste je i pre
toga **već bila tu**: potez koji nije glavni, a jeste učenikov, već se ocenjuje
kao tačan (`QUALITY.alternate = GRADES.good`).

## Repertoar: red po dometu i odsecanje grane — 31.8.2026

Dve poluge sa iste liste, obe nad ekranom za izgradnju.

**Red sada ima jedan redosled, a ne dva.** Novi čvorovi su se dodavali na kraj
liste, pa je glavna linija otvorena na sredini sesije čekala iza svake
stranputice upisane pre nje — a ista šetnja, nastavljena sutradan, vraćala se
poređana po `reach`, jer server tako računa. Dva redosleda za jednu šetnju su
gori deo toga: uči se oblik sesije umesto oblika stabla. `_Pending` sada nosi
`reach`, a `_enqueue` ubacuje na mesto koje mu taj broj daje — isti račun kao na
serveru, uključujući i to da sopstveni potez **ne** deli domet.

**„Ne spremam ovo" je jedina poluga koja stablo smanjuje.** Sve ostale ga
uvećavaju: svaki talas odgovora umnoži red, a repertoar koji odgovara na svaku
stranputicu je repertoar koji niko ne završi. Bez mesta gde se to zapiše, jedini
način da se kaže bio je zatvoriti ekran — što isto to kaže za jednu sesiju i
zaboravi, pa je ista mrtva linija tu sutra, na svakom uređaju.

Nova tabela `repertoire_skips` (korisnik, boja, `fen_key`) i dve rute pod
`/repertoire/node/skip`. Ključ je pozicija, ne linija, kao i kod poteza:
odsečena grana ostaje odsečena kako god se partija u nju transponuje.

Tri odluke oko toga:

- **Sa granom izlazi i sve ispod nje.** Odsecanje koje ostavi pozicije ispod
  ostavlja stablo tačno onoliko veliko koliko je bilo — tako se korisnik nauči
  da dugme ne pritiska. Na serveru se to dešava samo od sebe (šetnja tu staje), a
  ekran isto to radi nad redom koji već drži: pozicija je ispod ove tačno kad
  njena linija počinje ovom.
- **Odsečeno se broji odvojeno i nikad se ne oduzima od „bez odgovora".**
  Odsecanje obara `openReach` a da nijedno pitanje nije odgovoreno, pa
  `prunedReach` stoji pored njega i kaže da se te partije i dalje igraju. U
  zaglavlju: `odsečeno 1 (60%)`.
- **Potezi u odsečenoj poziciji ostaju.** Odsecanje govori dokle se sprema, ne
  šta se zaboravlja; drill i dalje traži potez koji je tu izabran. Zato čvor koji
  je odsečen ne ulazi ni u `decided` — šetnja je stala pre njega, a zaglavlje
  čiji se brojevi preklapaju ne može da se sabere.

Vraćanje je jedan potez unazad (`Vrati odsečenu granu`), i stoji i na ekranu
„nema više pozicija", jer odsecanje je upravo ono što red ume da isprazni. Ono
što je bilo ispod ne vraća se sa granom — te pozicije se otvaraju uzimanjem
odgovora, odakle su i došle.

Koren repertoara se **ne nudi** za odsecanje: to nije orezivanje nego brisanje
repertoara iz ekrana koji ga gradi, i jedini je rez posle kojeg u stablo nema
ulaza. Ako je koren ipak odsečen sa drugog uređaja, šetnja to prijavljuje kao
odsečeno, a ne kao gotovo.

Testovi: backend 723 → **730**, aplikacija 959 → **964**. Uživo nije viđeno:
[TODO-provera.md](TODO-provera.md), stavka 64.

## Repertoar: vežba je linija, a ne fotografija — 31.8.2026

Poslednje tri stavke sa liste iz razgovora o granici, i ispalo je da su jedna
stvar. Drill je do sada spuštao učenika na golu tablu četiri poteza duboko u
nešto, bez ijednog traga kako se tu stiglo. Pitanje je bilo dobro, način dolaska
nije: repertoar se igra unapred, a pamćenje koje vredi ide **duž** linije, ne
prepoznaje sliku njenog kraja.

`services/repertoireLine.js` i `GET /repertoire/drill/line`. **Nijedna nova
tabela** — šetnja je ista ona nad `repertoire_moves` i `opening_replies` koju
granica već radi, i to doslovno ista: `step`, `keptByPosition` i
`coveredReplies` su izvezeni iz `repertoireFrontier.js` umesto da se prepišu.

- **Ponavljanje cele linije pre pitanja.** Učenik odigra svoje poteze od početka
  linije, protivnikovi odgovori mu se vrate, i tabla stigne do pozicije koja je
  na redu.
- **Kreće od mesta koje već zna napamet**, ne od prvog poteza. Prag je
  `KNOWN_REPETITIONS = 3` — isti broj koji prazan ekran već zove „znate". Dvanaest
  poluporeza ponavljanja do jednog pitanja je način da se drill prestane
  otvarati.
- **Blok iz jednog čvora** (`fromFen`): grana se vežba sama. Dugme je u ekranu za
  izgradnju, na poziciji koja je pred učenikom — deset pozicija napravljenih juče
  je ono na šta neko sedne, a sa spiska repertoara može da se traži samo ceo
  repertoar.

**Ponovljeni potezi se ne ocenjuju**, i na tome stoji ceo dizajn. Prefiks se
igra više puta dnevno usput ka onome što je ispod njega; da se ocenjuje, SM-2 bi
tim pozicijama gurao interval na osnovu ponavljanja koja niko nije morao da se
seti hladno, i raspored bi tiho postao izmišljotina. Ocenjuje se **samo** pozicija
na kraju linije, kroz isti `POST /drill/answer` kao pre.

Dva pravila koja su ispala usput:

- **Pogrešan potez u ponavljanju se imenuje, ne ocenjuje.** Potez linije ipak ode
  na tablu — nastavak iz poteza koji nije u liniji bio bi vežbanje druge linije.
- **Odgovor i dalje ne putuje sa pitanjem.** Prefiks jeste u odgovoru servera, jer
  su to potezi koji se ponavljaju, ali potez koji se traži nije nigde u JSON-u;
  test to tvrdi i **dokazan je mutacijom**.

Redosled unutar bloka nije prepisan: `nextItem` i `drillStats` su dobili
parametar `only`, pa jedno te isto pravilo („dospelo prvo, pa nikad vežbano sa
najviše promašaja") važi i za celu boju i za jednu granu.

Kad linija ne može da se sastavi, ekran pada na staro pitanje bez ponavljanja i
**to kaže** — pokvarena šetnja je stvar koja se primeti, a ne stvar sa kojom se
živi.

Testovi: backend 730 → **738**, aplikacija 964 → **971**. Uživo nije viđeno:
[TODO-provera.md](TODO-provera.md), stavka 65.

## Radar pokrivenosti — poslednji deo trenažera, 31.8.2026

Mapa repertoara umesto mesta u njemu, i poslednja stavka iz skice
(`repertoire_trainer_spec.md`, „Vizuelna Mapa Pokrivenosti"). Procena da „mu je
ceo račun već tu" se pokazala tačnom: **nijedna nova ruta i nijedan nov upit** —
`frontier()` sada uz sve ostalo vraća i `branches`, iz iste petlje kroz koju su
ti brojevi ionako prolazili.

**Grana se imenuje po protivnikovom izboru**, ne po svom. U repertoaru je svoj
prvi potez već odlučen; posao deli ono što druga strana uradi povodom njega — pa
je ključ grane par poteza (moj, njegov), a ne samo njegov: repertoar sme da drži
više prvih poteza, i tada „2...d6" znači dve različite grane. Ime linije
(„Sicilian Defense") dolazi iz `OpeningBookService`, lokalno i bez tokena.

**Tri broja, i nikad se ne sabiraju.** Koliko se grana igra, koliko je od nje
spremljeno, i koliko je odsečeno. Prvi kaže da li je grana bitna, drugi koliko je
gotova, treći je odbijen posao — traka koja bi odsečeni deo ubrojala u spremljeni
pretvorila bi „ovo neću da spremam" u napredak.

**Procenat je u odnosu na granu, ne na ceo repertoar** (`openWithin`). Ovo je
broj koji bi inače bio pogrešan: linija koja se igra u 10% partija i u kojoj
nema nijednog odgovora, merena prema celini, čita se kao 90% gotova.

Ekran ne kaže **ništa** samo bojom: svaki udeo je ispisan procentom, a svako
stanje nosi ikonicu (kvačica / peščani sat / makaze). To je pravilo ovog projekta
i uslov za prijem, ne ukras — ekran čije značenje živi u nijansi je ekran koji
deo njegovih čitalaca ne može da koristi.

Mapa je i raskrsnica: iz svake grane vode „Gradi ovde" i „Vežbaj granu", pa se
poslednja tri dela trenažera (granica, rez, linijski drill) prvi put sreću na
jednom ekranu. Ulaz je ikonica radara u spisku repertoara, **na mestu strelice
udesno** — strelica je govorila samo „ovaj red se otvara", što red i inače radi
dodirom.

Testovi: backend 738 → **742**, aplikacija 971 → **979**. Uživo nije viđeno:
[TODO-provera.md](TODO-provera.md), stavka 66.

## Prvi prolaz kroz trenažer uživo — tri nalaza, 31.8.2026

Vlasnik je prošao kroz repertoar i javio tri stvari. Prva je izgledala kao bag i
nije bila.

**„Vežbaj ovu granu" nije dalo da se vežba.** Grana je imala tačno jednu odluku,
ta pozicija je već jednom vežbana, i SM-2 ju je zakazao za sutra. Server je
korektno vratio `question: null`, a ekran je rekao samo „Ništa nije na redu" —
rečenicom pisanom za ceo repertoar, bez datuma i bez izlaza. Pročitano je, sasvim
razumno, kao „ova grana ne može da se vežba".

Tri izmene, i sve tri su o tome da ekran kaže istinu koju server već zna:

- `drillStats` vraća i **`nextDueAt`**, pa ekran piše „Sledeća se vraća sutra"
  umesto da ćuti. Zaokruživanje ide na cele dane, jer „sutra" stiže kao 23 sata i
  nešto — `inDays` bi to prijavio kao nulu, a pozicija koja dospeva sutra ne sme
  da se čita kao da dospeva danas.
- U grani se i naslov menja: „**U ovoj grani** ništa nije na redu."
- **„Vežbaj ipak"** — `ahead=1`. Uzima poziciju koja je najbliža dospeću iako
  još nije dospela; pozicija koja nikad nije vežbana i dalje ide prva, jer je
  ona jedina prava, a ne vežba.

Ono što tu polugu čini bezopasnom je drugi kraj: odgovor dat van rasporeda se
**ne upisuje** (`practice: true`). Isto pravilo koje već važi za ponavljanje
linije, i iz istog razloga — pozicija provučena pet puta u jedno veče ne sme da
se vrati tek za mesec dana zato što je nekome bilo zabavno. Ekran to i kaže, a
`intervalDays` je `null`, pa ne može ni slučajno da obeća datum koji niko nije
sačuvao.

**„Kada će mi se pojaviti druge opcije protivnika?"** — u trenutku prijave,
nikada; sada mogu, jedan po jedan, odeljak „Rep se sada može spremiti". Talas pokriva 80% odigranog, najviše četiri poteza; u toj poziciji su to
bili c3 (64%) i Nf3 (19%), a ostalih 28 poteza je rep koji nosi 16% partija.
Panel ih pošteno broji, ali nema načina da se jedan od njih **doda** u pripremu.
Sreću se samo u drillu, koji vuče i nepokrivene poteze. To je prava rupa i nije
zatvorena — vidi „Šta je ostalo" ispod.

**Stablo poteza** — urađeno, odeljak ispod.

## Stablo repertoara — postojeći crtež, nova stabla, 31.8.2026

`GET /repertoire/tree` i `RepertoireTreeScreen`. Crtež **nije nov**: to je
`VisualMoveTreeWidget` iz Analize, koji već ume da zumira, pomera, crta odozgo
naniže ili s leva na desno i da označi transpoziciju. Drugo stablo napisano ovde
bilo bi drugo mesto na kome sve to može da se pokvari, pa je jedini posao bio
pretvoriti repertoar u `AnalysisNode`.

**Jedan čvor po poluporezu**, za razliku od šetnje koja radi u celim talasima
(moj potez i odgovor na njega), jer je talas jedinica u kojoj se postavlja
pitanje, a ne u kojoj se crta. Zato se stablo gradi iz **`repertoire_moves`**, a
ne iz onoga do čega je šetnja stigla: potez koji je izabran a odgovori nikad
uzeti nema nijedno dete, i crtež građen od dosegnutih pozicija bi ga izostavio —
što je tačno pozicija u koju je vlasnik gledao.

Svaka kartica kaže i **šta je pozicija posle nje**: `?` nema odluke, `…` odluka
bez uzetih odgovora, `✂` odsečeno, a uz protivnikov potez stoji i procenat.
Zvezdica je moj glavni potez. Sve u znakovima, ništa u nijansi.

**Dubina je parametar** (`maxPly`, podrazumevano 16, u ekranu 8/16/24/40).
Repertoar zasejan iz arhive ima hiljade poteza i crtež svih nije crtež koji neko
čita; kad se dubina dodirne, odgovor to kaže.

Iz izabranog čvora vode ista dvoja vrata kao sa radara — „Gradi odavde" i
„Vežbaj ovu granu" — i to samo kad je učenik na potezu, jer oba ekrana pitaju
„šta vi igrate ovde". Ulaz je ikonica stabla u zaglavlju radara.

Testovi: backend 742 → **751**, aplikacija 979 → **989**. Uživo nije viđeno:
[TODO-provera.md](TODO-provera.md), stavka 67.

### Šta je ostalo posle ovog prolaza

- ~~**Rep protivnikovih poteza se ne može spremiti.**~~ — urađeno istog dana,
  odeljak „Rep se sada može spremiti".
- **`minRating` niko ne postavlja.** Provučen je kroz sve ekrane repertoara i
  uvek je `null`, pa svako dete vidi poteze svih rejtinga. Odluka iz plana
  („rang se bira prema učeniku") još nema polje.
- **Odsečena grana se posle sesije ne može naći.** Server vraća ceo spisak,
  aplikacija koristi samo njegovu dužinu; „Vrati odsečenu granu" je jedan korak
  i živi koliko i ekran.

## Rep se sada može spremiti — 31.8.2026

Talas pokriva 80% odigranog, najviše četiri poteza, i **imenuje ostatak**. To je
dobra podrazumevana vrednost i loš zid: vlasnik ga je sreo na prvoj liniji — dva
odgovora spremljena, dvadeset osam preostalih koji nose šestinu partija, i
nijedan način da se kaže „i taj". Rep je bio prebrojan i nedostupan.

`repertoire_extra_replies` (nova tabela) i `POST/DELETE /repertoire/node/reply`.
U panelu „Odgovori protivnika" ispod rečenice o repu stoji „Spremi i neki od
njih"; otvara spisak nepokrivenih poteza sa dugmetom uz svaki.

**Po učeniku, ne preko `covered`.** Kolona `opening_replies.covered` je
zajednička — ti redovi su o poziciji i rangu, nikad o osobi — pa bi njeno
prebacivanje za jedno dete tiho prepisalo šetnju koju prate sva ostala. Nova
tabela je ogledalo `repertoire_skips`: jedna kaže „ovu granu neću", druga „i ovaj
potez hoću".

**Šetnja to mora da prati.** `coveredReplies` sada uzima pokrivene poteze **plus
one koje je ovaj učenik imenovao**. Bez toga bi pozicija bila postavljena jednom
i nestala čim se ekran zatvori, jer red nije sačuvan nego izveden — što je cela
poenta granice. Pravilo da se rep inače ne prati ostaje: praćenje celog repa bi
red napunilo potezima koje niko nije stavio u njega.

**Ulazi u red po dometu, kao i sve ostalo.** Biranje govori da potez mora da se
spremi, ne da je odjednom čest: potez koji se igra u jednoj partiji od dvadeset
čeka iza onih koje se igraju.

Spisak je sklopljen dok se ne zatraži — deset poteza po jedan procenat ispod
svake pozicije zatrpalo bi odgovore koji odlučuju kako izgleda sledeći talas — i
crta se iz onoga što je knjiga već vratila, bez ijednog novog zahteva.

Jedan nalaz iz testova, o testovima: lažna knjiga je vraćala **iste** poteze bez
obzira ko je na potezu, pa je red repa nudio crni potez u poziciji u kojoj je
beli na potezu. Ništa nije puklo — potez je bio nelegalan, `_fenAfter` je vratio
null i pozicija tiho nije ušla u red. Lažnjak sada zna čija je knjiga, jer ekran
te poteze zaista igra na toj tabli.

Testovi: backend 751 → **758**, aplikacija 989 → **992**. Uživo nije viđeno:
[TODO-provera.md](TODO-provera.md), stavka 68.

## Gde se staje 31.8.2026 uveče — repertoar

**Svih šest koraka iz [PLAN-REPERTOAR.md](PLAN-REPERTOAR.md) je gotovo**:
raspored sa stablom uz tablu, `source` i potvrda, auto-kičma, orezivanje po
dohvatljivosti, odgovori protivnika uz tablu, i ocena motora na čvoru. Plan
nema više otvorenih koraka.

Ništa od toga **nije viđeno uživo**. Stavke su 70–75 u
[TODO-provera.md](TODO-provera.md), i vrede više od bilo kog novog posla: šest
izmena nad istim ekranom, nijedna nije pokrenuta.

Backend treba pokrenuti jednom zbog `ALTER TABLE repertoire_moves ADD COLUMN
source` i zbog nove tabele `repertoire_notes`.

## Grana kao sesija, i sparing kroz nju — 1.9.2026

Vlasnik je razložio kako bi dril mogao da radi, u četiri režima, i rekao šta bi
njemu odgovaralo: **Line-Walk / sparing sa elementima drila po granama**. Pet od
šest stvari sa tog spiska je već radilo — SM-2 po pozicijama, šetnja linijom pre
pitanja, `fromFen` za jednu granu, protivnik biran **težinski po `games`**,
alternativa priznata uz rečenicu „Glavni potez vam je X", i kontrolne tačke koje
se **računaju** (najdublja pozicija koju znaš napamet) umesto da se postavljaju
rukom. Nedostajala su dva ulaza, i oni su sad napravljeni.

**Grana je postala ulaz u dril.** `GET /repertoire/drill/branches` vraća
protivnikove prve odgovore, svaki sa `positions`, `due`, `known` i **`dueKeys`**.
Grana se ključa **parom** poteza koji je otvara — mojim i njegovim — jer
repertoar sme da drži više prvih poteza, pa „2...d6" tada imenuje dve različite
grane; isto pravilo koje radar već koristi. Šeta se samo kroz odluke
(`onlyChosen`), jer dril ne pita za poteze koje niko nije izabrao. Pozicija koja
nikad nije ponavljana **računa se kao dospela**: to je najdospelija stvar koja
postoji, a grana koju niko nije otvarao ne sme da izgleda gotovo.

Do sada je `fromFen` radio od dana kad je napisan, ali je do njega mogao samo
onaj ko dolazi sa ekrana za izgradnju ili sa radara. Sada u zaglavlju drila stoji
ikonica grane: „Ceo repertoar" ili jedna grana, sa brojem dospelih uz svaku.

**Sparing: odigraj granu do kraja.** Iz istog lista, dugme ▶ na grani. Tabla ode
na poziciju kojom grana počinje, protivnik odgovara sam (težinski, pa ista grana
dvaput ne teče isto), i ide se dok ima pripremljenog poteza.

Jedno pravilo drži ceo režim: **ocenjuju se samo pozicije koje su bile dospele**,
ostale se igraju kao vežba i ne upisuju. Grana preigrana sa svakom pozicijom
ocenjenom gurala bi raspored napred na osnovu poteza koje niko nije morao da zna
napamet — isto pravilo zbog kojeg se ni prefiks u šetnji linijom ne ocenjuje, i
razlog zbog kojeg sparing sme da se pusti dvaput iste večeri.

Greška **zaustavlja trku tamo gde se desila**: ta pozicija je ceo razlog zbog
kojeg se trka igra, i proletanje kroz nju istom brzinom kao kroz ostalo je jedini
trenutak u kome ekran ne sme da žuri. Na kraju stoji jedna rečenica: „Grana
odigrana do kraja. Odigrano 9, greške: 1."

Ostalo nenapravljeno, svesno: **dril „slepih mrlja"** (`weakNodes` i
`disagreements` postoje kao podaci, ali nisu ulaz u dril) i **biranje grane po
tome gde ima najviše dospelog** — težinski protivnik je poštena simulacija, a
skretanje ka onome što je dospelo vraća sparing u kviz.

Testovi: backend 773 → **779**, aplikacija 1026 → **1032**. Uživo nije viđeno:
stavka 80 u [TODO-provera.md](TODO-provera.md).

## Otvaranje se bira sa spiska, ne samo kucanjem — 1.9.2026

Vlasnik je pitao može li da izabere repertoar **po nazivu otvaranja i po
varijanti u njemu**. Biranje po imenu je postojalo od ranije, ali samo kao
polje za pretragu: ekran se otvarao kao prazna kutija sa lupom, što služi jedino
onome ko već zna kako se zove ono što traži. Tražena je druga polovina.

**`OpeningBookEntry` sada zna svoja dva nivoa.** ECO ime je jedan string koji
nosi oboje — „Sicilian Defense: Najdorf Variation, English Attack" — pa je
`family` ono pre dvotačke, a `variation` ostatak. Sopstvena glavna linija
otvaranja nema ništa posle dvotačke i **imenuje se** („Osnovna linija"), jer
prazan red u spisku varijanti čita se kao greška, a „samo otvaranje" je stvaran
izbor.

**Dva spiska u `OpeningPicker`-u**: `families()` daje 149 otvaranja po
abecedi, `variationsOf(ime)` linije unutar jednog — **najkraća prva**, jer
najkraća linija *jeste* otvaranje na koje se misli kad se imenuje, a abecedno bi
spisak otvorilo na onome što počinje slovom A. Kucanje i dalje radi i **seče
popreko**: ko ukuca „Najdorf" misli na Najdorf, ne na Najdorf unutar otvaranja
koje je slučajno bio otvorio.

Usput popravljeno: picker je **odmah pokazivao spisak** ako je baza već
učitana, umesto da za jedan kadar treperi „Učitavanje…". To je i ono što je
omogućilo test — `compute()` pravi izolat, a časovnik u widget testu je lažni,
pa se `.then` na taj future iz test-zone nikad ne isporuči. Isti razlog, dva
dobitka.

Dugme je preimenovano u **„Izaberi otvaranje"**, jer „Nađi" opisuje samo
pretragu.

Testovi: aplikacija 1018 → **1026**. Uživo nije viđeno: stavka 79 u
[TODO-provera.md](TODO-provera.md).

## Izbor grane je sada pravilo cele aplikacije — 1.9.2026

Traženo od vlasnika, i tačno na mestu: na račvanju „napred" ima više od jednog
značenja, a traka je uvek uzimala prvo dete — pa se do ostalih grana
navigacijom **nije moglo stići uopšte**. To nije bila mana jednog ekrana nego
mana pravila, pa je i popravka na nivou pravila.

**`MoveCursor` je dobio dva člana**: `forwardBranches` (šta vodi napred odavde)
i `takeBranch(i)`. Oba imaju telo, ne apstraktnu deklaraciju, i to je odluka:
model koji se ne grana je ispravan **bez ičega** — vrati praznu listu i nikad ne
dobije pitanje. Obrnuto bi značilo da svaki nov kursor mora da zna za račvanja
da bi se uopšte kompajlirao, a to je strana na kojoj se pravi pogrešan odgovor.

**Pitanje postavlja traka i tastatura, na jednom mestu.**
`showBranchChoice` (`widgets/game_screen/branch_choice_sheet.dart`) je jedan
list za sve; `MoveNavigationControls` ga otvara na dugmetu „napred", a
`MoveKeyboardShortcuts` na strelici desno. Njih dvoje **ne smeju da se
razilaze**: račvanje koje otvara izbor pod mišem a pod tastaturom ćutke uzima
glavnu liniju gore je nego bilo koje od ta dva ponašanja samo za sebe.

Ko je time dobio izbor grane, bez ijedne izmene na svom ekranu: **Analiza**
(`AnalysisNodeCursor`), **soba za lekciju i AI Studio** (`MoveTreeCursor`), i
**repertoar**, koji je usput prestao da nosi svoju kopiju — ekran je prešao sa
spljoštene liste (`LinearMoveCursor`) na kursor nad stablom, pa mu je pravilo
stiglo samo od sebe. Lekcije i ponavljanja koriste `LinearMoveCursor`, koji
nema grane i ostaje tačno onakav kakav je bio.

Dve stvari koje su namerno ostale: **„na kraj" ne pita** — to znači kraj *ove*
linije, a pitanje na svakom račvanju usput bi ga učinilo neupotrebljivim; i
**zatvaranje lista ne pomera tablu**, jer biti pitan i ćutati nije isto što i
izabrati glavnu liniju.

Testovi: aplikacija 1015 → **1018**. Uživo nije viđeno: stavka 78 u
[TODO-provera.md](TODO-provera.md).

## Drugi prolaz uživo: jedna lista, jedan zahtev, jedan izbor — 1.9.2026

Vlasnik je prošao kroz izmene i javio četiri stvari. Sve četiri su bile tačne i
sve su bile posledica istog: ekran je radio dvaput ono što treba jednom.

**Potez koji je već u repertoaru se više ne sudi ponovo.** Vlasnik je odigrao
svoj *drugi* potez u poziciji i ekran ga je pitao „Uzmi Re1?" — potez koji je
već bio prihvaćen. Odigrati potez koji već stoji u listi je isti čin kao
izabrati ga u stablu: idi i pogledaj šta dolazi posle njega. Sada je tako, kroz
isti `_standAfterMove` kroz koji ide i dodir na karticu.

**Druga Lichess lista je uklonjena, i sa njom jedan upit po potezu.** Posle
svakog odigranog poteza dohvatala se cela knjiga preko sudije, da bi se videlo
kako su te partije prošle. To je bio **Lichess upit po potezu**, protiv tokena
koji služi svu decu koja koriste ovu aplikaciju, i drugi panel ispod onog koji
stoji na ekranu otkad je pozicija otvorena. Ono što je nosio a sačuvana knjiga
ne nosi — kako su partije **završile** — vredi imati, ali kao kolonu u
`opening_replies` koja se dohvati jednom za sve, ne kao upit po potezu.

**Navigacija pita kojom granom.** U poziciji koja se grana „napred" ima više od
jednog značenja, a paleta je uvek uzimala prvo dete — pa se do ostalih grana
navigacijom **nije moglo stići uopšte**. Sada se otvara list sa svim
nastavcima, i tek kad izbor zaista postoji.

*Vlasnikov predlog je da to bude pravilo na nivou cele aplikacije.* Nije
urađeno i vredi zasebno: `MoveCursor` bi dobio „koje su grane napred", a
`MoveNavigationControls` i `MoveKeyboardShortcuts` bi pitali umesto da biraju.
Tri implementacije kursora i šest ekrana, pa je to svoj posao, a ne usputna
izmena.

**Desni klik sada kaže šta je uradio.** Radnje iz menija su radile i ćutale.
Sve idu kroz `AppFeedback` — „Nc3 je sada vaš glavni potez", „Nc3 je uklonjen iz
repertoara", „Grana posle Bf5 je odsečena" — jer pravilo ovog projekta je
**uradi pa reci**, i reci kroz `AppFeedback`, koji ne može da baci izuzetak.

Testovi: aplikacija 1014 → **1015**. Uživo nije viđeno: stavka 77 u
[TODO-provera.md](TODO-provera.md).

## Gradnja prestaje da bude kviz — 31.8.2026

Vlasnik je prošao kroz ekran uživo i javio šest stvari. Jedna od njih je
promenila zamisao, ne raspored: **repertoar se više ne gradi tako što korisnik
pogađa poteze, nego na osnovu statistike, ocene i svoje slobodne volje.**

**Statistika stoji uz tablu, uvek.** Panel „Šta se ovde igra" pokazuje šta se u
poziciji na tabli igra — iz sačuvane baze, dakle **bez ijednog Lichess upita** —
i svaki red ima „Igraj", koji potez pusti kroz isto suđenje i istu odluku kao
potez povučen po tabli. Poziciju koju niko nikad nije otvarao i dalje otvara
dugme sa cenom u natpisu („1 upit").

**Dugmeta „Ne znam" više nema.** Ono je postojalo da bi se **zapisalo** da je
neko gledao (`looked_up`), a taj podatak je drillu govorio koje pozicije da pita
prve. Sa listom na ekranu od početka, „rešeno gledanjem" se ne razlikuje od
„rešeno mišljenjem", pa se `lookedUp` više ne upisuje kao `true` — broj koji ne
znači ništa gori je od broja koga nema. Kolona ostaje, drill se povlači na
odbijene pokušaje, koji i dalje znače tačno ono što su značili.

Ostalih pet nalaza, sve na istom ekranu:

**Desni klik u stablu nije radio ništa.** To je bila greška, ne odluka:
`AnalysisMoveTreeWidget` zove `onPromoteNode?.call` i `onDeleteNode?.call`, a
`RepertoireTreePanel` nije prosleđivao nijedan — `?.` je gutao dodir. Meni je
ceo dan nudio dve stavke vezane ni za šta. Sada: na **mom** potezu „Unapredi"
menja glavni potez, a „Obriši" je uklanjanje sa punim čišćenjem nedohvatljivog i
pitanjem o odlukama; na **protivnikovom** potezu „Obriši" je **rez** — njegovi
potezi nisu ničiji izbor, pa nema šta da se briše, a ono što neko time misli je
„ovo ne spremam".

**Odsečene grane se više ne crtaju.** Rez zaustavlja šetnju, ali je kartica
ostajala: deset rezova je ostavljalo deset mrtvih listova koji šire crtež koji
se čita da bi se videle rupe. Sakrivene, nikad obrisane — iznad stabla stoji
„Prikaži odsečene grane (N)", jer je rez odluka i mora da ostane pronađiv.

**Navigaciona paleta ispod table.** Ista četiri dugmeta kao na još pet ekrana,
preko istog `MoveCursor`-a, i linija ide **kroz** tablu do kraja glavne linije —
paleta čija su dugmad unapred mrtva čim se ekran otvori nije navigacija. Test
`move_keys_everywhere_test.dart` je odmah pao i tražio strelice uz traku; dobile
su ih. Taj test je uradio tačno ono zbog čega je pisan.

**Kartice su numerisane od prave pozicije.** Repertoar koji počinje posle 3.e5
crtao je svoju prvu karticu kao potez jedan. Broj se sada čita iz FEN-a kartice
— jedino mesto koje zna gde je brojanje počelo — pa piše `3... c5` i `4. c3`.
Isto važi i za PGN prikaz istog panela, gde je laž bila ista.

**Ivica kartice kaže čija je strana.** Ne ispuna: ispuna i dalje govori glavna
linija/varijanta. Ivica ide na `sideWhite`/`sideBlack`, dakle **svetla ivica
prema tamnoj**, ne jedna nijansa protiv druge — razlika mora da preživi čitaoca
koji ne razdvaja nijanse. Izabrana kartica zadržava svoj akcenat i sjaj, jer
izbor mora da ostane nepogrešiv.

Testovi: aplikacija 1008 → **1014**. Uživo nije viđeno: stavka 76 u
[TODO-provera.md](TODO-provera.md).

## Dodir na svoj potez u stablu — 31.8.2026

Vlasnik je pitao ima li logike iza toga što u stablu ne može da klikne na svoje
poteze. Imala je, i bila je preuska.

Kartica nosi poziciju **posle** poteza. Posle protivnikovog poteza na potezu sam
ja, pa tabla prosto ode tamo. Posle **mog** poteza na potezu je protivnik, a to
je pozicija o kojoj ovaj ekran nema šta da pita — pa se dodir vraćao na
roditelja, poziciju iz koje je potez izabran. U liniji u kojoj stojite to je
pozicija na kojoj **već jeste**: dodir je izgledao kao kartica koja ne radi
ništa, a usput je kroz `_show` brisao linije motora i ocenu sudije.

Sada dodir na svoj potez **postavi tablu posle njega** i ispod nacrta ono što
protivnik odatle igra — iz sačuvane knjige, dakle bez ijednog Lichess upita.
To je ono što neko i misli kad dodirne svoj potez. Pitanje ostaje na poziciji iz
koje je potez odigran (`_node` se ne pomera), tačno kao u stanju posle „Dalje";
`_afterMyMove` je jedan uslov umesto dva ponovljena kroz ceo `build`, jer panel
koji zaboravi drugi je ocena ili knjiga nacrtana za tablu koja se ne vidi.

Izlaz je dugme **„Nazad na X"**. Bez njega je jedini izlaz iz dodirnutog poteza
još jedan dodir u stablu, što je ćošak a ne stanje.

I zaštita: **skok na poziciju koja je već na tabli sada ne radi ništa.**
Ponovno prikazivanje pozicije briše sve što joj je pripadalo, pa je dodir koji
sleti tamo gde tabla već stoji ranije bacao linije motora koje je čitalac upravo
sačekao. Test je dokazan mutacijom — bez te jedne linije pada.

Testovi: aplikacija 1006 → **1008**. Uživo nije viđeno: stavka 70 u
[TODO-provera.md](TODO-provera.md).

## Ocena motora na čvoru — korak 6 iz plana, 31.8.2026

`repertoire_notes`, `PUT /repertoire/note`, `GET /repertoire/notes` i
`GET /repertoire/disagreements`. Motor je i pre ovoga bio na ekranu za
izgradnju; ono što je nedostajalo je da njegov odgovor **ostane** na poziciji.

**Broj je podatak, nije presuda.** Ekran već ima sudiju — sudiju otvaranja, koji
odgovara na „da li je ovaj potez zdrav, sudeći po partijama koje su ljudi
odigrali", i to je za repertoar bolje pitanje, jer je repertoar o onome što će
se protiv vas zaista igrati. Drugo mišljenje iz drugog pojma „dobrog", odštampano
na istoj kartici, način je na koji ekran počne da protivreči sam sebi pred
detetom. Zato **nema zastavice ni na jednom potezu**; umesto nje postoji
**spisak**: „Gde se motor ne slaže", sortiran po tome koliko neslaganje košta,
kroz koji se prolazi namerno.

**Ocena je po korisniku.** Red iz knjige je činjenica o poziciji i zato se deli
(`opening_replies`); ocena je činjenica o poziciji *i* verziji motora, dubini i
mašini. Deljena tabela bi morala da ima sve troje u ključu da bi išta značila, a
ovako se ne bi slagala ni sa kim.

**Plića ocena nikad ne pregazi dublju.** Prolaz kroz celu liniju ide na dubini
koja je na točkiću; ručno pokrenuta pretraga na dubini 30 nad jednom pozicijom
ne sme da se spljošti sutrašnjim prolazom na 18. Isto pravilo koje
`AnalysisNode.evalDepth` drži u klijentu, ovde ga drži baza (`WHERE
EXCLUDED.eval_depth >= repertoire_notes.eval_depth`), a odgovor vraća **red koji
je pobedio**, ne onaj koji je poslat — ekran crta ono što je sačuvano.

**Dubina i datum se vide.** Ocena bez dubine je broj koji stari nevidljivo:
dubina 12 od pre dve nedelje i dubina 30 od pre minut izgledaju isto napisane kao
`+0.35`.

**„Evaluiraj celu liniju (N pozicija)"**, sa brojem u natpisu. Ne troši nijedan
Lichess upit — samo vreme i toplu bateriju — pa cena mora da se vidi pre nego što
se pritisne, a prolaz može da se zaustavi. Zaustavljanje se čita **između**
pozicija: pretraga koja je već krenula se dovrši i sačuva, jer bacanje odgovora
koji je plaćen ne pomaže nikome. `N` je koliko će zaista biti računato, a ne
dužina linije: pozicije koje već imaju ocenu bar te dubine se preskaču.

Prolaz ocenjuje **i protivnikove poteze**, jer je veličina neslaganja ocena pre
poteza minus ocena posle njega. Gde druge ocene nema, red je i dalje na spisku (
motor očigledno igra nešto drugo) sa `?` umesto broja — a `?` nije nula.

Dve kolone preko onoga što je plan nabrojao, i obe su odluka: `best_uci`, jer se
potezi porede po UCI-ju a ne po SAN-u koji ispisuju dve različite šahovske
biblioteke; i `mate_in`, jer forsiran mat sačuvan samo kao veliki broj pešaka
čita se kao ocena. `eval_cp` i dalje nosi mat sažet u centipešake, da sve što
sortira i oduzima ima jedan broj.

Ocene se čitaju **jednom, uz crtež** (`GET /repertoire/notes`), i sedaju na
kartice stabla — `VisualMoveTreeWidget` već crta `eval`, pa to nije nov crtež
nego broj koji stiže tamo gde je mesto za njega već postojalo.

**Jedno mesto na koje treba paziti**, zapisano jer je to oblik koji
`tablebaseService` odbija za trenera završnica: ocenu računa klijent a čuva je
server, dakle server je ne može proveriti. Ovde je to prihvatljivo iz jednog
razloga — niko ne vara sam sebe za ocenu motora, i ovaj broj ništa ne ocenjuje.
Ako ikad počne išta da ocenjuje, taj razlog pada i računanje mora da se preseli.

Testovi: backend 761 → **773**, aplikacija 995 → **1006**. Uživo nije viđeno:
[TODO-provera.md](TODO-provera.md), stavka 75.

## Protivnikovi odgovori uz tablu — korak 5 iz plana, 31.8.2026

`GET /repertoire/book` i panel „Posle X — šta igra protivnik", koji sada stoji
uz tablu umesto da se pojavljuje tek posle `Dalje`. To je jedina lista koja
odlučuje kako izgleda sledeći talas, pa nije imala šta da traži iza dugmeta.

**Ne troši nijedan upit.** Čita se iz `opening_replies`, gde stoji sve što je
ičija sesija izgradnje već platila — ti redovi su o poziciji i rangu, nikad o
osobi. To je pravilo za panel koji prati tablu: jedan token služi svu decu koja
koriste ovu aplikaciju, a lista koja bi se osvežavala na svaki klik trošila bi
njihovu kvotu na crtež koji niko nije tražio.

`opened` razlikuje dva prazna: „niko ovde nije gledao" je ponuda (dugme „Otvori
knjigu (1 upit)"), a ne tvrdnja da protivnik nema šta da igra.

Svaki red vodi negde. Odgovor koji je već u pripremi nudi **„Idi"** — tabla ode
tamo; odgovor van pripreme nudi **„Spremi"**, isti put kroz
`repertoire_extra_replies` koji je napravljen za rep.

Usput uhvaćen tridesteti `info` u `analyze` — jedan `if` bez zagrada u novom
kodu. Pravilo je „nula grešaka, nula upozorenja i nijedan nov info", i jedini
način da se to vidi je brojanje, jer izlazni kod je crven i kad je sve u redu.

Testovi: backend 758 → **761**, aplikacija 993 → **995**. Uživo nije viđeno:
[TODO-provera.md](TODO-provera.md), stavka 74.

## Orezivanje po dohvatljivosti — korak 4 iz plana, 31.8.2026

`services/repertoirePrune.js`, `GET /repertoire/node/orphans` i
`POST /repertoire/prune`. Traženo pravilo je bilo „promeniš potez, sve iza starog
izbora se briše"; napravljeno pravilo je **briše se ono do čega se više ne može
stići**, a ne „briše se podstablo".

Razlika nije akademska. Baza je graf ključan po poziciji — zbog toga rad duboko u
Smit-Mori postaje deo šireg repertoara protiv 1.e4 u trenutku kad stigne do iste
table — pa pozicija ispod napuštenog poteza može da stoji i na liniji koja se i
dalje igra. Brisanje podstabla bi tiho pokvarilo liniju koju niko nije dirao.

Dve šetnje i oduzimanje: **S** je ono do čega se stizalo kroz potez koji odlazi,
uzeto **pre** nego što ode; **R** je ono do čega se stiže iz svih korena te boje
posle; siročići su `S \ R`. To oduzimanje usput čuva i pozicije do kojih se
nikad nije ni stizalo — na primer izgrađene ulaskom iz drilla, van pokrivenog
repa — jer one nisu ni u `S`. Čistka „sve što je nedohvatljivo" preko cele boje
pojela bi svaku takvu.

Rezovi se **prolaze**. `repertoire_skips` znači „ne pitaj me za ovu granu", ne
„obriši je", a rez koji bi tiho obrisao rad iza sebe ne bi mogao da se poništi.

**Nacrti odlaze bez pitanja, odluke se broje i vraćaju na pitanje.** Gubitak
večeri rada zbog promenjenog drugog poteza, bez ijedne rečenice o tome, je stvar
koja se dogodi jednom i završi poverenje u funkciju.

Okačeno je na **uklanjanje** poteza, ne na promenu glavnog: sa `role`, promena
glavnog ostavlja stari potez kao alternativu i ništa ne ostaje bez veze.

### Test koji ništa nije merio, pa je popravljen

Prvi test za ovo je prošao i sa **isključenim** oduzimanjem — imenovao je ključ
koji ionako nikad nije u skupu. Drugi pokušaj je imenovao transpoziciju, ali
poziciju u kojoj je protivnik na potezu, a šetnja u skup upisuje samo pozicije u
kojima je učenik na potezu; opet ništa. Tek treći, nad pravom transpozicijom
(2.Nf3 Nc6 3.Nc3 i 2.Nc3 Nc6 3.Nf3 su jedna tabla), pada kad se oduzimanje
izbaci i prolazi kad se vrati.

To je tačno pravilo iz `CLAUDE.md` — **dokaži zaštitu mutacijom pre nego što joj
poveruješ** — i ovde je dvaput uzastopno pokazalo da zaštita nije čuvala ništa.

Testovi: backend 749 → **758**, aplikacija 989 → **993**. Uživo nije viđeno:
[TODO-provera.md](TODO-provera.md), stavka 73.

## Auto-kičma — korak 3 iz plana, 31.8.2026

`services/repertoireSpine.js` i `POST /repertoire/spine`. Deblo u jednom
potezu: najigraniji potez za obe strane, onoliko poteza koliko se traži.
Odgovor na „tridesetak pitanja pre nego što išta liči na otvaranje".

**Sve što upiše je nacrt** (`source = 'auto'`), pa drill to ne pita dok se ne
potvrdi. Zbog ove funkcije kolona i postoji — bez nje bi kičma bila sejanje iz
arhive sa boljim potezima.

**Nikad ne gazi odluku.** Ako pozicija već ima potez, kičma ga prati umesto da
pita knjigu — što je čini bezbednom za ponovno pokretanje i čini „nastavi
odavde" istom radnjom kao „počni ovde". Test to tvrdi tako što proverava da
knjiga **nije ni pitana** o poziciji o kojoj je učenik već odlučio.

**Staje kad linija postane tanka, i kaže gde i zašto.** Prag je 100 partija, a
ne sudijskih 5: taj broj odgovara na pitanje „da li se ovo uopšte igra", a ovaj
na „da li je ovo još glavna linija". Odgovor uvek nosi `stopped: {reason, ply,
games}` — `depth` kad je prošla ceo put, `thin` kad je stala, `illegal` kad
upisan potez više ne može da se odigra. Tiho skraćen odgovor je greška koju ovaj
projekat najčešće pravi, pa ova funkcija ne ume da ga vrati.

**Sinhrono, namerno.** Dva upita po potezu na 150 ms je nekoliko sekundi;
pozadinski posao koji je ovaj projekat imao obrisan je juče jer je trajao
predugo i pukao. Dubina je ograničena na 12 poteza, a ruta ima svoj limiter
(šest kičmi u minutu) jer je svaka od njih rafal nad tokenom koji dele sva deca.

Svaka knjiga koju usput otvori se upisuje u `opening_replies` — svejedno je
morala da se dovuče, a upisana čini drill i izvedeni red besplatnim posle toga.

Usput nađen i popravljen jedan red greške u samom ekranu: poruka o tome šta je
kičma uradila pisala se **pre** ponovnog čitanja šetnje, a `_resume` upisuje
svoju poruku kad šetnja ne može da se pročita — pa je jedina stvar koju je
čitalac tražio bila jedina koju ne bi video.

Testovi: backend 737 → **749**, aplikacija 985 → **989**. Uživo nije viđeno:
[TODO-provera.md](TODO-provera.md), stavka 72.

## Nacrt nije odluka — korak 2 iz plana, 31.8.2026

`repertoire_moves.source` (`'chosen'` podrazumevano, `'auto'` za ono što
generator napiše), i sve što iz toga sledi. Ovo je morala da bude izmena **pre**
auto-kičme, jer bi kičma bez nje bila sejanje iz arhive sa boljim potezima:
potezi koje niko nije izabrao, nerazlučivi od odluka, koje drill traži da se
setiš i priznaje kao tačne.

Pravilo je jedno i drži se na četiri mesta: **auto-potez se crta, kroz njega se
šeta, nudi se na potvrdu — i drill ga ne pita.** Filtrirano je u `nextItem` (oba
upita), `drillStats`, `revealPrimary` i u ocenjivanju odgovora. Pozicija u kojoj
postoje samo generisani potezi vraća `unprepared`, što je pošteno: tamo nema šta
da bude tačno ili netačno.

**Potvrda je čin.** `POST /repertoire/node/confirm` (jedan potez ili cela
pozicija) i `POST /repertoire/line/confirm` (cela linija, jednim `UPDATE`-om —
linija potvrđena do pola je linija koju bi učenik prošao dvaput). U ekranu za
izgradnju nacrt piše „predlog — nije još vaš izbor" i uz njega stoji „Potvrdi".
Odigran potez preko generisanog takođe ga pretvara u odluku; obrnuto nikad —
generator ne sme da nečiju odluku vrati u predlog.

**Šetnja i slika prate nacrte, vežba ne.** Red i stablo idu kroz `auto` poteze —
nacrt do koga se ne može doći je nacrt koji se ne može potvrditi — dok
`walkLines` za linijski drill uzima samo `chosen`, jer linija kroz potez koji
niko nije izabrao nije učenikova linija. Isti `keptByPosition`, jedan parametar.

Radar broji odvojeno: `decided` su odluke, `draft` su pozicije čiji su svi potezi
generisani. Nikad se ne sabiraju — mapa koja bi kičmu zvala „spremljeno" bila bi
ista laž koju je sejanje pričalo, samo sa boljim izvorom.

### Rejting protivnika — odlučeno 1600, i zašto ne 1500/2100

Vlasnik je izabrao **1600 kao podrazumevano**, uz izbor trake. Njegov predlog
šireg raspona (1500 / 1800 / 2100) nije izvodljiv i to nije stvar ukusa:
Lichess Explorer poznaje tačno određene korpe — `[0, 1000, 1200, 1400, 1600,
1800, 2000, 2200, 2500]` — a `ratingBucketsFrom` odbija sve ostalo imenujući
dozvoljene vrednosti. 1500 i 2100 ne postoje.

U aplikaciji su zato **1400 / 1600 / 1800 / 2000**, u zaglavlju spiska
repertoara, i podešavanje se pamti (`app_repertoire_min_rating`). Do sada je
`minRating` bio provučen kroz svaki ekran repertoara i **nije ga postavljao
niko** — svako dete je gledalo poteze svih rejtinga.

Traka je prag, ne opseg: 1600 znači „1600 pa naviše". Tako ostaje, i razlog nije
estetski — `opening_replies` je ključan po pragu i **deli se između korisnika**,
pa bi promena značenja praga bez promene ključa ostavila jedan ključ sa dva
različita odgovora.

**Majstori namerno nisu prečka na tim merdevinama.** To je druga baza koja
odgovara na drugo pitanje — „šta je teorija" naspram „šta ću sresti" — i stavljena
na vrh trake tiho bi promenila šta broj znači. Ide uz kičmu, kao prekidač pored
trake.

Testovi: backend 733 → **737**, aplikacija 983 → **985**. Uživo nije viđeno:
[TODO-provera.md](TODO-provera.md), stavka 71.

## Stablo je sada pored table — korak 1 iz plana, 31.8.2026

Prvi korak iz [PLAN-REPERTOAR.md](PLAN-REPERTOAR.md). `RepertoireTreeScreen`
više ne postoji kao ekran: crtež je **panel na ekranu za izgradnju**, onako kako
Analiza to već radi, pa se ono što se gradi vidi dok se gradi.

- **Široko (≥840 dp):** dve kolone — tabla sa pitanjem levo, stablo desno. Ovo
  ništa ne košta: tabla je ograničena, pa je prostor pored nje na 1900 px
  prozoru i do sada bio prazan. Tabla sada raste do 560 px, ali nikad preko
  onoga što visina dozvoljava — pitanje ispod nje ne sme da ode sa ekrana.
- **Usko:** jedna kolona, panel ispod kontrola, sklopljen. Nikakve navigacije.
- **Oba:** traka odmah ispod table — roditelj → trenutna pozicija → deca, svako
  sa svojom oznakom. To je deo stabla koji treba dok se odgovara na poziciju, i
  jedini koji je čitljiv na 360 dp.

**Stablo je postalo navigacija.** Dodir na čvor vodi tablu tamo. Dodir na *svoj*
potez vodi na poziciju **pre** njega — tamo gde je ta odluka doneta — jer je to
jedina pozicija o kojoj ovaj ekran ume da postavi pitanje, i to je ono što neko
ko dodirne svoj potez i misli. Red je ostao netaknut: tabla pokazuje poziciju,
red je mesto odakle stiže sledeće pitanje, i to nikad nisu bile iste stvari.

**Nađen jedan stari bag, i to onaj koji se ne vidi.** `AnalysisMoveTreeWidget`
ima zaglavlje koje je `Row` sa naslovom i četiri kontrole; na 360 dp prelivalo se
za **180 px**. Postoji od kad i Analiza i nikad nije bilo pumpano na širini
telefona — u release build-u se preliv ne crta, pa se ne vidi. Naslov je sada u
`Flexible`, i popravka je **dokazana mutacijom**: bez njega test na 360 dp pada.
Analiza od toga takođe ima koristi.

Testovi: 985 → **983** (obrisan `repertoire_tree_test.dart` sa 7, dodato 5 novih
za raspored). Uživo nije viđeno: [TODO-provera.md](TODO-provera.md), stavka 70.

### Batch koji je ovo trebalo da uradi — istekao

Posao je bio predat Gemini-ju i **istekao je na 75 minuta**. Izveštaj je tvrdio
da je sve urađeno; diff je pokazao da `repertoire_build_screen.dart` — ceo smisao
posla — nije ni otvoren, a napisani panel nije bio pozvan niotkuda. Test koji je
napisao pumpao je **nepromenjen** ekran, pa bi prošao ne dokazujući ništa.

Uzrok je u ostacima: `modify_build.py`, 285 linija `content.replace()` hirurgije
nad fajlom od 1804 linije. Pouka je ona koju je `chess_game_screen.dart` već
naučio i koju je brief zaboravio: **prepravka vrlo velikog fajla nije jedan
batch** — taj ekran (4291 linija) uzet je u pet prolaza. Zapisano u
`orchestrator/HANDOFF.md`.

## Izgradnja repertoara se prepravlja — plan, 31.8.2026

Vlasnik je posle prvog ozbiljnog korišćenja rekao da je gradnja konfuzna, i
predložio četiri pravila (auto-kičma, orezivanje pri promeni poteza, spisak
protivnikovih odgovora uz tablu, motor samo na dugme). Plan je u
[PLAN-REPERTOAR.md](PLAN-REPERTOAR.md), zajedno sa tri izmene iz pregleda —
najvažnija je da **auto-potez nikad ne sme da izgleda kao odluka**, jer je to
tačno greška zbog koje je sejanje iz arhive obrisano isti dan.

Tu je i odgovor na „stablo je na drugom ekranu": stablo postaje **panel na
ekranu za izgradnju**, onako kako Analiza to već radi — `AnalysisMoveTreeWidget`
ima i prekidač PGN/graf i ceo ekran i zatvaranje na dodir čvora.

Ništa od toga još nije napisano. Redosled poslova je na kraju plana.

## Dva uklanjanja, na zahtev vlasnika — 31.8.2026

Oba su prijavljena pri prvom ozbiljnom korišćenju, i oba su tačna.

### Repertoar iz uvezenih partija — uklonjen

Sejanje je pisalo kroz **isti `addMove`** kao ekran za izgradnju, u **isti graf**
— potezi pripadaju paru (korisnik, boja), ne repertoaru. Posledica koju je
vlasnik video na spisku: „French Defense: Advance — crni" i „Iz mojih partija —
crni" prikazuju **isti broj poteza**, jer to i jesu isti potezi. Njegove reči:
„možda su mnogi od tih poteza pogrešni, a meni ulaze kao da sam ih izabrao".

Gore je nego što zvuči. Uvezeni potez je bio **nerazlučiv** od odluke: šetnja je
kroz njega prolazila, radar ga je brojao kao odlučen, a drill je tražio da se
seti poteza koji nikad nije izabrao — i priznavao ga kao tačan, jer je
`QUALITY.alternate = GRADES.good`.

Uklonjeno: `seedFromArchive`, `POST /games/repertoire/seed`, `ensureRepertoire` i
dugme „Izvuci repertoar iz partija". **Poređenje ostaje** (`GET
/games/repertoire/diff`) — ono ništa ne upisuje i odgovara na pravo pitanje:
gde ste izašli iz onoga što ste izgradili.

Za ono što je seme već upisalo: `GET/DELETE /repertoire/imported`. Test je da li
uz potez postoji zabeležen **vaš izbor** (`repertoire_attempts` sa `kept`), jer
ekran za izgradnju taj red upisuje u trenutku kad se potez uzme, a seme nije
upisivalo nijedan. To je **procena, ne dokaz**, i ekran to kaže pre nego što bilo
šta obriše — jedini je trag koji postoji, upravo zato što je seme pisalo kroz
isti put. Brisanje vraća `primary` tamo gde ga je odnelo, u istoj transakciji:
pozicija sa potezima a bez glavnog je pozicija koju drill ne ume da pita.

Usput: **repertoar do sada nije mogao da se obriše**. `DELETE /repertoire/:id`
briše ime i početnu poziciju, nikad poteze — oni pripadaju boji i dele ih svi
repertoari koji do njih stignu.

### Provera završnica preko tablica — uklonjena

Vlasnik je odustao, sa razlozima koji stoje: dva izvora za jedan odgovor (lokalni
Syzygy + Lichess) su sistem sa dva načina da bude u kvaru, prolaz traje predugo,
proces je pukao, i greške iz sopstvenih završnica ne uče ništa što ponavljanje
grešaka već ne pokriva.

Uklonjeno: `services/endgameAudit.js`, tri rute pod `/games/endgame`, tabele
`tablebase_cache` i `endgame_audits`, lokalni sidecar
(`sidecar/syzygy_sidecar.py`, `SYZYGY_SIDECAR_URL`, `SYZYGY_PATH`) i ekran
„Proveri završnice".

**Šta ostaje i zašto:** `tablebaseService` — trener završnica i „odigraj do
kraja" ga i dalje koriste, jedan zahtev po potezu, što je oblik za koji je i
pisan. Ostaje i **tempo** (razmak i zastoj posle 429): skener koji ga je učinio
neophodnim je otišao, ali pravilo koje važi samo dok ga niko ne pritisne nije
pravilo. Ostaju i nalazi koji su već upisani u `mistake_reviews` sa
`kind = 'tablebase'` — ponavljanje grešaka ih i dalje prikazuje.

Dve tabele ostaju u bazi kod onoga ko ih već ima; kod se više ne pravi. Mogu da
se obrišu ručno, ali ništa ih ne čita.

Testovi: backend 758 → **733**, aplikacija 992 → **985**. Manje koda i manje
testova je ovde ceo rezultat. Uživo nije viđeno: [TODO-provera.md](TODO-provera.md),
stavka 69; stavke **54 i 56 više ne postoje** i precrtane su.

## Repertoar iz arhive — sekcija 4, napisana 30.8.2026

`services/repertoireArchive.js`, `POST /games/repertoire/seed` i
`GET /games/repertoire/diff`. **Nijedna nova tabela** — obe polovine su spajanja,
što je isplata za odluku od pre dva dana da `opening_nodes` koristi isti
`fen_key` kao `repertoire_moves`.

**Sejanje ide kroz `addMove`**, ne kroz direktan `INSERT`. Ta funkcija već drži
pravilo koje bi ova mogla najlakše da pokvari: prvi potez u poziciju postaje
`primary`, svaki sledeći `alternate`, a to čuva parcijalni unique indeks. Zato
pozicija o kojoj je igrač već odlučio zadržava njegovu odluku i samo dobija
alternative — sejanje koje bi pregazilo ručno građen repertoar bilo bi najgori
mogući način da se ova funkcija uvede.

**Mereno na stvarnoj arhivi**, uz podrazumevani prag od 5 partija i 15% udela za
drugi odgovor: pri pragu 3 → 1306 pozicija i 2362 poteza; **pri 5 → 648 pozicija
i 1132 poteza**; pri 8 → 372 i 592; pri 15 → 206 i 314. Nijedan potez nije
odbijen kao neodigriv. Od 648 pozicija, njih 193 ima jedan odgovor u 90% ili
više partija — to su rešeni delovi repertoara, ostalo je gde se još bira.

1132 poteza po dva upita je 2264 obilaska baze, predugo za jedan zahtev, pa se
pozicije pišu paralelno a potezi **unutar** jedne pozicije ostaju redom. To je
uslov ispravnosti, ne štelovanje: dva poteza u istu poziciju istovremeno oba bi
zatekla da nema `primary`, oba bi ga upisala, i parcijalni indeks bi oborio
sejanje na pola — iz razloga koji sa igračem nema veze. Test tvrdi da dva poteza
za istu poziciju nikad nisu u letu zajedno, i **dokazan je mutacijom**:
grupisanje po potezu umesto po poziciji ga obori.

`dryRun: true` vraća plan i ne upisuje ništa — to je ono što UI treba prvo da
pokaže.

Diff broji samo pozicije koje repertoar zaista pokriva. Pozicija o kojoj
repertoar ćuti nije izlazak iz repertoara nego **rupa** — drugi izveštaj i drugi
osećaj.

Testovi: 610 → **623**. Uživo nije viđeno: [TODO-provera.md](TODO-provera.md),
stavka 56.

## Profil igrača van otvaranja — sekcija 5, napisana 30.8.2026

`services/playerProfile.js` i `GET /games/profile`. Sve izlazi iz `user_games` —
bez motora, bez tablica, bez mreže — a `min_men`, upisan pri uvozu, je ono što
pitanje „dokle je partija stigla" pretvara u `GROUP BY` umesto u ponovno
odigravanje.

**Mereno na stvarnoj arhivi od 4126 partija, kroz produkcioni kod.** Po dužini:
ispod 20. poteza 696 partija i **45,5%**, 20–40. potez 2196 i 51,3%, preko 40.
poteza 1234 i 53,6%. Po fazi: rešeno pre završnice 3237 i 49,6%, stiglo u
završnicu 418 i 50,5%, stiglo do tablica 471 i **61,5%**.

Sat, na 3632 partije koje ga nose — prolaznost prema tome koliko je vremena
ostalo posle 20. poteza: ispod 30 s → 21 partija, 23,8%; 30–60 s → 84, 48,2%;
60–120 s → 1078, 50,9%; preko 120 s → 1858, 53,7%. Čist gradijent, i prvi broj u
celom planu koji govori o tome **kako** igrač igra, a ne šta. Posle 10. poteza,
37,9% poteza je odigrano za manje od tri sekunde.

Dva upozorenja idu uz te brojke gde god se prikažu: red „ispod 30 s" ima 21
partiju i ne sme da se čita kao nalaz, a to što kratke partije nose najlošiju
prolaznost samo po sebi nije tvrdnja o otvaranju — to je mesto gde dalje treba
gledati, a sekcija 1 je ta koja može da odgovori.

Dve stvari ovde daju uverljivo pogrešne brojeve umesto greške, pa su obe čiste
funkcije sa sopstvenim testovima:

- **Koji unosi u nizu sata pripadaju igraču.** `clocks[i]` je sat posle poluteza
  i+1, pa su igračevi svaki drugi, a koji drugi zavisi od boje. Obrnuto, to
  prijavljuje protivnikovu vremensku nevolju kao igračevu i sve niže i dalje
  izgleda razumno. Jedna definicija, u `subjectClocks`.
- **Sat nije štoperica.** U partiji 3+2 potez odigran za sekundu ostavlja sat
  **višim** nego pre, pa je potrošeno vreme `pre - posle + inkrement`.
  Zaboravljen inkrement ne puca — kaže da igrač na 3+2 nikad ne žuri.

Testovi: 623 → **635**. Uživo nije viđeno: [TODO-provera.md](TODO-provera.md),
stavka 57.

## Trenerski sloj i domaći iz arhive — sekcija 6, napisana 30.8.2026

`services/homeworkFromArchive.js`, `POST /assignments/from-archive` i
`GET /assignments/student/:id/archive`. Ovo je deo koji ceo plan pretvara iz
funkcije za jednog igrača u funkciju za trenera: trener izabere učenika i dobije
zadatak sastavljen od pozicija koje je to dete stvarno pogrešilo.

**Kapija je `trainerOwnsStudent`, pozvana a ne prepisana.** Tri ručno pisane
kopije slične provere u ovom kodu su sve zaboravile status, pa je neodgovoreni
poziv već otključavao pošiljaočeve časove; test prolazi kroz `routes/` i
`services/` i pada ako se pojavi četvrta kopija. Sam zadatak pravi
`createCustomAssignment`, koji istu kapiju proverava još jednom — ovaj fajl
dodaje pozicije, ne dodaje drugi način da se zada domaći. Dva testa to drže:
jedan da se nepovezani trener odbija, drugi da se kapija pita **pre** nego što
se učenikove partije pročitaju. **Dokazano mutacijom**: isključena provera obori
oba.

Dve osobine su strukturne, ne obećane:

- **Trener može da pravi domaći samo iz arhive koju je učenik sam uvezao.** Ruta
  za uvoz je vezana za `req.user.id`, pa niko drugi ne može da ubaci partije u
  učenikovu arhivu, a upit čita samo redove sa `subject_is_owner = TRUE` —
  dečije sopstvene partije, nikad tuđi profil koji je dete gledalo radi pripreme.
- **Trener vidi pozicije i greške, ne pretraživu istoriju partija.** Uže čitanje
  je ono koje odnos zaista traži.

Skup se **razmiče po temama** pre nego što udvoji bilo koju: osam verzija istog
viljuška je jedna lekcija ponovljena, ne domaći. Nalazi iz završnica se grupišu
po materijalu jer temu nemaju — po `theme` bi svi završili zajedno pod „bez
teme".

Rangira se **unutar** vrste, nikad preko nje. Greška motora se meri
centipešacima a ona iz tablica promenom ishoda; jedna skala za obe značila bi
izmišljen kurs između „dao 300 centipešaka" i „pretvorio dobitak u remi", a
svaki broj posle toga bi tu izmišljotinu nosio ćutke.

**Trend je trend i tako se zove.** Ruta za trenera vraća dvanaest meseci partija,
prolaznosti i prosečnog rejtinga, i namerno se **ne** zove „pre i posle": pravo
pre-i-posle traži datum preko kojeg se poredi — dan kad je učenik počeo da radi
na nečemu — a to šema nigde ne beleži. Prikazano kao „pre i posle" pripisalo bi
planu treninga sve što je igrač tog meseca slučajno uradio. Zapisati taj datum
je najmanji koristan sledeći korak za trenerski panel.

Testovi: 635 → **650**. Uživo nije viđeno: [TODO-provera.md](TODO-provera.md),
stavka 58.

## Dva ekrana nad arhivom — agent za dizajn, 30.8.2026, pregledano istog dana

`chess_app/lib/features/archive/`: uvoz i izveštaj o otvaranjima, nad
backendom iz sekcija 0 i 1, koji ovaj posao nije menjao. Do njih se stiže
preko nove kartice **„Moje partije"** u sekciji Otvaranje na raskrsnici
treninga; uvoz predaje izveštaju korisničko ime pod kojim je run išao, pa
izveštaj nema svoje polje za unos i ne može da se otvori nad arhivom koje
nema.

Tri stvari koje je pregled uhvatio, i vrede zapisane jer se sve tri čitaju kao
uspeh dok se ne pogledaju:

- **Agent je prijavio „902 testa, sve zeleno" dok je jedan njegov test padao.**
  `find.text('2. polupotez')` traži tačno podudaranje, a ekran crta
  „2. polupotez · uspeh 45,0%". Broj u prijavi je bio tačan, boja nije.
- **`user_game_imports.id` je `BIGSERIAL`, a node-postgres `int8` vraća kao
  string.** `json['importId'] as int` bi pukao na prvom pravom uvozu, i nijedan
  widget test to ne može uhvatiti jer lažni servis vraća `int`. Broj sada ide
  kroz `jsonInt`, koji prima i jedno i drugo. Isti oblik greške kao svi ostali
  u ovom projektu: korak koji tiho preskoči i javi uspeh.
- **Četiri brojača se nisu crtala ni u jednom testu.** `_run` ostaje `null` dok
  ne prođe birač fajlova, koji widget test ne može da pokrene, pa je tvrdnja
  „u `Wrap` su da se ne preliju" bila neproverena. Izdvojeni su u
  `ImportCounters` i dokazani mutacijom: kao `Row` prelivaju se za 358 px
  prazni i 860 px sa razlozima preskakanja.

Suđenje je **isključeno dok se ne zatraži**. Agent je model i ekran napisao za
presude, ali `judge=true` nije nikada slao — značke i rečenica „Bolje je bilo…"
postojale su samo u lažnom servisu. Sada ide na dugme „Presudi poteze", jer
troši korisnikov Lichess token, a brojevi su potpuni i bez njega. I to je
dokazano mutacijom.

Tabla u redu je `BoardThumbnail`, a ne `SkinnedChessBoard` kako je brief tražio
— za pregled od 80 px koji se ne dodiruje to je lakše, ali jeste izmena
deljenog widgeta: dodat mu je `isWhiteBottom`, koji okreće mrežu a boju polja
ostavlja vezanu za mesto na ekranu.

Testovi u aplikaciji: 900 → **908**, 1 preskočen. `flutter analyze` i dalje 29
`info`-a, bez novih. Uživo nije viđeno: [TODO-provera.md](TODO-provera.md),
stavke 52 i 53, pododeljci „Ekran".

## Priprema za protivnika i AI opis — sekcija 7, napisana 30.8.2026

`services/opponentPrep.js`, `services/narrativeGuard.js`,
`services/prepNarrative.js`, `services/archiveScope.js`, i dve rute pod
`/games/prep`. Testovi: 650 → **697**.

Mehanički je ovo sekcija 1 uperena drugde. Lichess svakom daje partije bilo kog
naloga, uvoznik već prima proizvoljno korisničko ime, a
`GET /games/openings/leaks?subject=` već agregira po subjektu — **izveštaj nije
dobio nijednu novu rutu**, što je bio ceo argument da se ovo gradi posle sekcije
1 a ne pre nje.

Zato je i opasno. To je jedina funkcija ovde koja čita o osobi koja nikad nije
otvorila aplikaciju, a većina naloga u ovom proizvodu pripada deci. Priprema za
klupski meč protiv imenovanog desetogodišnjaka je isti HTTP zahtev kao priprema
za velemajstora, i kod ih ne razlikuje.

**Prekidač je isključen.** `OPPONENT_PREP_ENABLED` je podrazumevano `false` i
odbija glasno, imenom — prazan izveštaj bi se čitao kao „protivnik nema
slabosti". Isti oblik kao `AGE_OF_CONSENT`: odluka je proizvodna i pravna, ne
podrazumevana vrednost do koje se stigne tako što parametar ostane neiskorišćen.

Vredi zapisati šta se **ne može** napisati: „odbij ako ovaj handle pripada detetu
koje koristi aplikaciju" nije izvodljivo, jer ništa ne povezuje Lichess nalog sa
nalogom ovde. Rejting prag je zamena za to, i nesavršena.

### Ono što je moralo da stigne prvo

Tri upita su odgovarala na pitanje **o igraču** a da to nisu rekla: zbir arhive
je brojao sve redove pod korisnikom; vrata za greške iz motora su proveravala
samo da `game_id` pripada pozivaocu, što tuđi arhiv takođe zadovoljava; a
provera završnica prima korisničko ime i čita sve pod njim, pa bi tuđe greške
završile u igračevom ponavljanju — „stalno visiš figure", sastavljeno od tuđih
partija.

Ništa nije pucalo i svaki odgovor je ostajao uverljiv. Zato `archiveScope.js`
drži uslov na jednom mestu, kao `trainerOwnsStudent`, a test pada ako se pojavi
ručno prepisana kopija. Dve koje su već postojale su prevedene na njega.

### Šta se proverava, a šta se ne može

Rejting prag se proverava **pre** nego što se išta upiše — provera posle značila
bi da već držimo arhiv koji smo hteli da odbijemo. Rejting koji Lichess ne
potvrđuje (provizoran, ili ga nema za traženi tempo) odbija umesto da propusti:
prag koji se sam otvara kad upit padne nije prag. Odbijenica imenuje prag, nikad
čovekov rejting. Uz to: dnevni limit različitih ljudi, i retencija na istom
dnevnom prolazu kao MP4 izvozi — tuđi arhiv je jedan zahtev daleko, igračev je
fajl koji je on otpremio.

Graditelj upita je čista funkcija i izvezen je da bi mogao da se tvrdi bez
mreže, jer je svaki njegov parametar način da se dobije **manji** odgovor nego
što je traženo. Lichess ne odbija pogrešno napisan `perfType` — ignoriše ga, pa
se uvoz tiho proširi na sve tempo-kontrole i izgleda identično ispravnom
zahtevu.

### Rečenica nad izveštajem

`GET /games/prep/narrative`. Dva pravila, oba o tome šta napušta server.

**Ime ne izlazi.** Subjekt se zameni rečju „protivnik" pre nego što se prompt
sastavi. Model opisuje stil igre, ne osobu, pa ime ne doprinosi rečenici — a
slanje imena i partijskog kartona treće strani je deo koji se ne može povući.

**Brojevi se proveravaju, ne traže.** Plan je u pravu: prompt nije zaštita.
Model ne laže — on zaokružuje, prosečuje i sabira, uslužno, u brojeve koje niko
nije izračunao, a „oko 40%" se čita isto kao 41,3% pored njega. Svaki broj u
izlazu mora doslovno postojati u ulazu, inače rečenica pada. Jedan ponovni
pokušaj, sa imenovanim spornim brojem, pa kraj — petlja koja pita dok nešto ne
prođe je petlja koja na kraju opere pogrešan broj u prihvaćen.

Pada zatvoreno, ali u korisnom smeru: bez ključa, uz ispad modela ili uz odbijenu
rečenicu ruta vraća 200, `narrative: null` i imenovan razlog. Tabela je bila
odgovor; rečenica je uvek bila ukras, a ukras ne sme da obori ono što ukrašava.

Uživo nije viđeno: [TODO-provera.md](TODO-provera.md), stavka 59.

