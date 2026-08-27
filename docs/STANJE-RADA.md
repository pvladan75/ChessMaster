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

Poslednje ažuriranje: 27.8.2026.

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
