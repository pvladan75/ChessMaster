# Stanje rada — arhiva, 26.8–2.9.2026

Istorija iz `STANJE-RADA.md` preseljena 16.9.2026: panel trenera, prijava, motor,
teme i kože, arhiva sopstvenih partija, i repertoar iz avgusta i s početka
septembra (najveći deo zamenjen planom `PLAN-REPERTOAR-RUCNO.md` 16.9.2026).
**Ne čitati unapred** — pretražuje se (`grep`) kad zatreba *zašto*.
Provere uživo koje su ovde pominjane i dalje stoje u `TODO-provera.md`, pod
istim brojevima; ta lista nije dirana.

---

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

## Kapija repertoara: dva otvaranja iz iste pozicije — 2.9.2026

Vlasnik gradi belim iz italijanke posle 3...Bc5. Tu se igra i 4.b4 (Evans) i
4.0-0, i to su dva različita repertoara — ali potezi pripadaju paru
(korisnik, boja), pa je drugi repertoar u stablu prikazivao ceo prvi.

**Nije se delio store, nego pogled.** Potezi ostaju u jednom grafu i to je
namerno: pozicija do koje se stiže na dva načina je *jedna* pozicija sa jednim
odgovorom, jer šah ne pita kroz koja ste vrata ušli. Ono što je falilo je bilo
ime za to kroz šta jedan repertoar ide.

**`repertoires.via_uci`** — kapija. Jedan potez iz korena. Filtriranje je jedna
funkcija, `gateMoves`, primenjena na mapu `kept` **pre** nego što se napravi
ijedan korak — a tu mapu čitaju i šetnja (`walkLines`, `frontier`) i crtanje
(`tree` crta iz `kept`, ne iz onoga do čega je šetnja stigla, da bi potez koji je
odlučen a nije otvoren i dalje imao karticu). Zato jedan filter pokriva stablo,
red za odlučivanje, radar pokrivenosti, spisak grana, vežbanje i listu
neslaganja.

Kapija koja nije među zadržanim potezima ostavlja poziciju **praznom**, a ne
nefiltriranom: to se na ekranu čita kao „ovde još nije odlučeno", što je tačno za
repertoar čiji prvi potez nije zadržan.

**Gde se bira.** Na ekranu za novi repertoar, ali samo ako u toj poziciji već
ima poteza — pozicija koju niko nije dodirnuo ne treba kapiju i ne pita se za
nju. Ponuđeni su prvo potezi koji se već igraju (označeni), pa **svi ostali
legalni**, jer novi repertoar često ide kroz potez koji još nije odigran — to je
tačno slučaj koji je i naterao ovu izmenu. Postojećim repertoarima kapija se
postavlja iz menija na kartici („Kroz koji potez ide"), i to je važnije od
prvog: repertoari kojima kapija najviše treba su oni koji su već napravljeni.

**Ekran za izgradnju to kaže**: „Ovaj repertoar ide kroz 0-0 — ostalo iz ove
pozicije se ne prikazuje." Filtriran pogled koji ne kaže da je filtriran je način
da neko zaključi kako mu je rad obrisan.

**Brisanje sada ume da razlikuje ta dva.** `reachable` prima i `{fen, viaUci}`,
pa se oduzimanje kod „obriši i poteze" računa kroz kapije: brisanje jednog od dva
repertoara iz istog korena odnosi samo njegovu granu. Kapije se **spajaju** kad
više polazišta deli poziciju, a jedno polazište bez kapije otvara je celu —
inače bi se linija proglasila nedohvatljivom zato što je neki drugi repertoar ne
igra.

Jedan ostatak: kad šetnja uopšte ne uspe (server je pao), dril pada na
`/drill/next`, koji je i dalje po boji. To je putanja koja se javlja rečenicom
„Linija nije mogla da se sastavi", pa se ne ćuti — ali nije filtrirana.

### Usput nađeno: „Vežbaj 0-0" nije radilo

Dok se gledalo kako se dril sužava, ispalo je da su `viaFen`, `viaUci` i
`exclude` u `routes/repertoire.js` upisani u **pogrešan handler**: stajali su u
`/disagreements`, koji ih nikad nije ni pročitao iz zahteva, a `/drill/line`, koji
ih čita, nije ih prosleđivao dalje. Posledice, obe bez ijedne poruke:

- „Vežbaj 0-0" je menjalo rečenicu iznad table i ništa više — pitanje je i dalje
  dolazilo kroz onaj potez koji raspored preferira;
- „Druga linija" je vraćala istu liniju, jer je red determinističan
  (`ORDER BY due_at LIMIT 1`), a preskakanje ne upisuje ništa;
- `/disagreements` je padao na **svaki** poziv, jer je golo `exclude` referenca
  na nepostojeće ime. `typeof viaFen` na nedeklarisanom imenu je legalan i vraća
  „undefined", pa su dva od tri otkaza bila potpuno tiha.

Ovo je tačno ona greška koja se u ovom projektu ponavlja — korak koji se preskoči,
javi uspeh i pukne jedan sloj dalje — pa je dobila test koji čita **ožičenje**:
`test/repertoire_route_wiring.test.js` traži (1) parametar koji je pročitan iz
zahteva a nigde ne prosleđen i (2) ime koje handler koristi a nije uzeo iz
zahteva. Telo handlera se čita **poklapanjem zagrada**, komentari se skidaju pre
provere, a oba testa su dokazana mutacijom.

Backend treba pokrenuti jednom, zbog `ALTER TABLE repertoires ADD COLUMN
via_uci`.

Uživo nije viđeno: [TODO-provera.md](TODO-provera.md), stavka 85.

## Brisanje poteza iz baze i sopstveni komentari — 2.9.2026

Vlasnik je obrisao sve repertoare, otišao na „Novi" da ponovo izgradi ono što je
imao — i u stablu zatekao poteze koje je ranije prihvatio. To nije bila greška
nego posledica oblika: `repertoire_moves` je ključevan `(user, boja, fen_key)`,
a `repertoires` je **ime za početnu poziciju**, ne kutija koja drži poteze.
Zbog toga transpozicije ne koštaju ništa i zbog toga drugi repertoar iste boje
odmah zna šta se tu igra.

Rupa nije bila to što potezi preživljavaju brisanje. Rupa je bila što posle
brisanja **poslednjeg** repertoara boje do njih nema nikakvih vrata:
`repertoirePrune.rootsOf` odbija da radi bez korena — i to je ispravno, jer
„nema korena" nikada ne sme da se pročita kao „ništa nije dohvatljivo" i pomete
sve — pa ni `/node/orphans` ni `/prune` tada ne odgovaraju. Novi
`services/repertoireErase.js` su ta vrata, i ima ih dvoje:

- **Brisanje jednog repertoara, sa potezima.** Ide ono što *samo on* dohvata:
  dohvatljivo iz njegovog korena minus dohvatljivo iz svih ostalih korena te
  boje. Pozicija koju drži još neki repertoar ostaje, jer se i dalje igra.
  Broj se pokazuje **pre** pitanja (`GET /repertoire/removal`), i posebno se
  imenuje koliko je od toga „sami ste izabrali".
- **Pražnjenje boje.** Sve što je sačuvano za tu stranu, prebrojano prvo
  (`GET /repertoire/color`, `DELETE /repertoire/color`). Ovo je jedina vrata
  koja se otvaraju i kad nijednog repertoara nema — zato stoje u gornjoj traci
  spiska, a ne na kartici: stanje zbog kog postoje je ono u kom kartica nema.
  Sami repertoari ostaju; pražnjenje poteza je počinjanje otvaranja iznova, a ne
  odricanje od njega.

Uz poteze idu i odsečene grane, dodati odgovori, pokušaji, raspored za vežbanje
i ocene motora za te pozicije. Razlog je jedan: rez ili raspored koji ostane iza
obrisanih poteza **ponovo se primeni** na liniju izgrađenu kasnije — odluka iz
repertoara koji više ne postoji, koja stigne nedeljama posle.

Prazan spisak sada i sam kaže gde su potezi otišli, jer je to mesto na kom
čovek bude iznenađen.

### Komentar uz poziciju — svoja tabela, ne polje u oceni

Nova tabela `repertoire_comments (user, boja, fen_key, body)`. Nije kolona u
`repertoire_notes`, i to je odluka, ne ukus:

- ocena je ono što je motor rekao — prepisuje je svaka dublja pretraga i ide sa
  potezima koje opisuje; rečenica koju je čovek otkucao ne može da se izračuna
  ponovo ni na jednoj dubini, ni na jednoj mašini;
- `putNote` **odbija** red bez ocene — a to je tačno onaj red koji treba
  komentaru na poziciji koja nije analizirana.

Zato komentari **ostaju** kad potezi odu, osim ako se ne zažele izričito
(kvadratić u oba dijaloga, podrazumevano ugašen). Komentar bez poteza košta
jedan red i vrati se čim se do te pozicije opet dođe — ključ je pozicija, kao i
svuda ovde, pa se ono što je zapisano duboko u jednoj liniji vidi čim druga
linija transponira u tu tablu.

Prazan tekst je brisanje. Sačuvan prazan komentar bi crtao karticu o poziciji o
kojoj niko ništa nije rekao.

### Gde se komentar vidi

Jedan widget (`RepertoireCommentPanel`), dva mesta, i to je razlog što je widget:

- **Pored table**, u trećoj koloni, od `Breakpoints.ultraWide` (1200 dp) na
  više. Širina se uzima od stabla, nikada od table — `_boardSize` se i dalje
  računa iz istih 42% — jer je manja tabla jedina stvar gora od komentara koji
  je jedan skrol daleko. Panel ima svoj skrol, da dugačak komentar ne može da
  produži red preko prozora (u release buildu to nisu pruge nego odsečen dno).
- **Ispod table**, na telefonu i u užem prozoru, gde prazan komentar crta
  **ništa**. Kolona ispod table na 360 dp je najskuplji prostor u aplikaciji.

Na 840 dp (dve kolone) komentar i dalje ide ispod table: treća kolona izvučena na
toj širini ostavlja sliku preusku da se čita.

### Dva dugmeta u traci ispod table

Tamo gde ih Tabla za analizu već ima, jer onaj ko je naučio jedan ekran ne treba
da ih traži na sledećem. `MoveNavigationControls` je `Wrap`, pa se na telefonu
prelome u drugi red umesto da budu isečena bez upozorenja u release buildu.
Traka se sada crta i kad je linija prekratka za šetnju — ranije bi nestala cela,
a sa njom i jedini način da se napiše komentar na prvoj poziciji.

**„Pitaj AI o poziciji"** zove `POST /api/ai/explain-position` — rutu koja
postoji od AI trenera, sa svojom kvotom (`ai_comments`) i limiterom, i
`PuzzleApiService.explainPosition`, koji je bio **napisan i nigde pozvan**. Nije
drugi sudija: sud o potezu ostaje otvaranjska baza (šta su ljudi stvarno igrali),
a ovo je proza o poziciji, ponuđena da se pročita i — ako vredi — prepiše u
sopstveni komentar, kroz editor, pa tek onda sačuva. Ono što je model napisao
nije ničiji komentar dok čovek ne kaže da jeste.

Backend treba pokrenuti jednom, zbog nove tabele `repertoire_comments`.

Uživo nije viđeno: [TODO-provera.md](TODO-provera.md), stavka 84.

## Dril šeta sam, i kaže kroz koju odluku — 1.9.2026

Vlasnik je uživo naleteo na dve stvari koje su, kad se pogledalo u kod, ispale
tri odvojene greške i jedno neslaganje sa dogovorom.

**Šetnja linijom nije govorila kroz koju odluku ide.** `walkLines` širi *svaki*
zadržani potez u poziciji — i glavni i alternativu — pa linija do dospele
pozicije sme da ide kroz alternativu. Prefiks o tome nije nosio ništa. Ekran je
onda pitao „odigrajte potez koji ste izabrali" u poziciji u kojoj su **dva**
poteza vlasnikova, a samo jedan nastavlja tu liniju; drugi je vraćen narandžastom
rečenicom „U ovoj liniji ide Nc3", istom kojom se javlja i promašaj. To uči
učenika da ne veruje potezu koji je sam izabrao, a ništa u repertoaru ne vredi
toliko.

Sad `walkLines` nosi `role` i `alts` uz svaki moj potez u liniji, a šetnja ima
**tri ishoda umesto dva**: potez linije, *drugi moj potez* („I d4 je vaš potez —
ali ova linija vežba Nc3", plavo, ne narandžasto), i promašaj. Pre poteza, kad
linija ide kroz alternativu, stoji rečenica da ide kroz alternativu — **bez
imena poteza**, jer imenovanje bi šetnju pretvorilo u film baš na pozicijama
zbog kojih se šeta. Ćutanje na račvanju znači „glavni", i to je pošteno: koji je
potez, ostaje na učeniku.

**Ispravka se nije videla.** Potez linije i protivnikov odgovor sletali su u
jednom `loadFen`-u, pa se figura pojavljivala na polju na koje ništa nije viđeno
da ide — vlasnik je posle svog d4 dobio crnog skakača na c3 i nigde potez Nc3.
Sada idu u dva takta: potez linije prvo, sam, sa strelicom na sebi, pa posle
550 ms protivnikov odgovor.

**„Nastavi liniju" je bilo ručno ono što sparing radi sam.** Dogovor je bio
šetnja linijom do kraja, a red je posle svakog odgovora stajao i tražio klik.
Sada tačan odgovor vodi dalje sam, posle 1400 ms — duže od sparingovih 700, jer
ovde panel kaže i **kada se pozicija vraća**, a rečenica koju niko ne stigne da
pročita je rečenica koju dril više ne govori. Zato presuda ide **sa** šetnjom:
iznad sledećeg pitanja stoji „Tačno — Nc6 · protivnik Nf3 · vraća se za 6 dana".

Dugme je ostalo za ono što šetnju **zaustavlja**: grešku i nepokriveni
protivnikov odgovor. Iznenađenje je jedina stvar koju knjiga ne ume i vrata
nazad ka izgradnji — proletanje kroz tu rečenicu u poziciju bez odgovora bilo bi
najgore mesto za žurbu.

**Dve greške uz put.** Dugme se nudilo i kad protivnik nije odgovorio: pozicija
posle sopstvenog poteza je protivnikova da je odigra, pa je „Nastavi liniju"
tamo vodilo u pitanje „šta igrate" u poziciji u kojoj nisi na potezu. I šetnja
je upisivala raspored pozicija koje niko nije tražio — pravilo „ocenjuje se samo
ono što je bilo dospelo" držao je sparing preko `dueKeys`, a red nije držao
niko. Sada odgovor ide sa `onlyIfDue`, a odluku donosi server, jer je `due_at`
njegov. Pozicija koja nikad nije ponavljana i dalje **jeste** dospela.

Testovi: backend 779 → **784**, aplikacija 1032 → **1040**. Uživo nije viđeno:
stavka 81 u [TODO-provera.md](TODO-provera.md).

## Protivnik ostaje unutar pripremljenog — 1.9.2026

Vlasnik je tražio da dril ide **samo kroz pozicije pokrivene protivnikovim
odgovorima**, da ne dobija „Protivnik je odgovorio Nf6 — to niste pokrili".
`pickReply` je do sada vukao iz **celog repa** `opening_replies` — svega što je
explorer vratio i posle 80% reza — i to namerno: sretanje nepokrivenog poteza
pokazivalo je učeniku ivicu onoga što je spremio i vodilo nazad u izgradnju.

To je uklonjeno, i dva razloga govore isto:

**Šetnja linijom to nikad nije radila.** `coveredReplies` prati samo pokrivene
odgovore plus one koje je učenik imenovao, pa je *živi* protivnik igrao poteze
koje ponavljanje iste te linije ne bi odigralo. Dva različita protivnika u
jednom drilu, i ponavljanje je bilo ono koje je u pravu.

**Vrata ka izgradnji nisu bila u tome.** Ostaje `unprepared` — pozicija koju
jesi pokrio a nisi odlučio šta u njoj igraš — sa ponudom „Izgradi ovu poziciju".
To je rupa u repertoaru, a ne rupa u knjizi, i to je poštenija polovina onoga
čemu je iznenađenje služilo.

Pozicija u kojoj ništa nije pripremljeno sada odgovara **ničim**: linija se
završava tamo gde se završava priprema, što je ono kako izgleda knjiga koja je
istekla. „Nastavi liniju" se tu ne nudi, a sparing to već zove „Grana odigrana
do kraja".

„Pripremljeno" i ovde znači isto što i svuda: pokriveno **ili** potez na koji je
učenik pritisnuo „spremi i ovo" — pa `pickReply` sada mora da zna **ko** pita
(`repertoire_extra_replies` je po učeniku). Uslov se računa u SQL-u a filtrira u
JS-u namerno: tako je izvlačenje provereno nad redovima, a ne nad tekstom upita.

`replyCovered` i rečenica koju ekran gradi iz njega **ostaju**. Server to više ne
šalje, ali su ispravno čitanje zastavice koju i dalje šalje — ako se izvlačenje
ikad ponovo proširi, ekran to kaže bez ijedne izmene unazad.

Testovi: backend 788 → **791**. Uživo nije viđeno: stavka 83 u
[TODO-provera.md](TODO-provera.md).

## Izbor račve je radio i nije se video — 1.9.2026

Vlasnik je javio da izbor ne radi: klikne „Vežbaj d4" i i dalje dobija
alternativnu liniju. **Nije bilo tako.** Server je narušavao ispravno — dokazano
probom nad račvom četiri poteza duboko, jer je jedini postojeći test imao račvu
u **korenu**, gde je `moves[at * 2]` trivijalno `moves[0]` i aritmetika indeksa
se ne proverava. Kad se napravi ista provera dublje, `nodesVia` vraća tačno
poziciju iza `d4`.

Greška je bila u tome što se to **ne vidi**. Iznad račve obe linije čitaju
identično — ista tabla, isti trag poteza, isti brojač „potez 1 od 1" — jer se
linija razilazi tek **sledećim** potezom. Učenik je tražio d4, dobio d4, video
poziciju koju je i pre gledao i rečenicu „Odigrajte potez koji ste izabrali", pa
je zaključio da se ništa nije desilo. Funkcija koja radi a ne može da se vidi
kako radi nije isporučena.

Sada, kad je put izabran, ponavljanje na toj račvi **imenuje potez**: „Ova linija
ide kroz d4 — odigrajte ga." Ništa se ne odaje — učenik ga je maločas izabrao po
imenu — a rečenica o alternativi se tu gasi, jer „jedan od vaših poteza" ispod
„odigrajte d4" kaže manje od ničega.

**Druga polovina: put koji nema šta da ponudi.** Prazan ekran se crta *umesto*
panela koji nosi red „Vežbate liniju kroz d4." i izlaz sa njega, pa je učenik
ostajao na putu koji ne vidi i sa kog ne može da siđe, ispod rečenice „Ništa nije
na redu" — koja je tvrdnja o repertoaru, a bila je činjenica o jednom potezu. Sad
piše „Iza poteza d4 ništa nije na redu." i tu stoji „Nazad na red".

Pouka za dalje, jer se ponavlja: **test koji potvrđuje ponašanje na indeksu 0 ne
potvrđuje aritmetiku indeksa.** Račva u korenu je prošla i kad je duboka bila u
pitanju.

Testovi: aplikacija 1044 → **1046**. Uživo nije viđeno: stavka 82 u
[TODO-provera.md](TODO-provera.md), tačke 12–14.

## Račva se bira, i preskakanje zaista preskače — 1.9.2026

Nastavak istog razgovora. Vlasnik je pitao šta znače „Preskoči ponavljanje" i
„Druga linija", i kako da pređe na glavni potez i liniju iza njega. Prvo je
objašnjenje, drugo je bila rupa, a usput je ispalo da jedno od ta dva dugmeta ne
radi ono što piše na njemu.

**„Druga linija" nije davala drugu liniju.** `nextItem` je deterministički
`ORDER BY due_at ASC LIMIT 1`, a ponavljanje ne upisuje ništa — pa je isti
zahtev vraćao isto pitanje. Isto važi i za „Preskoči" nad pitanjem: preskakanje
ne ocenjuje i ne piše `repertoire_attempts`, pa se pozicija vraćala u nedogled.
Oba dugmeta su bila izlaz koji ne izlazi nigde. Sada `drillLine` prima
`exclude` — pozicije odbijene u ovoj sesiji — a kad se sve odbije, gomila se
**okrene** umesto da ekran kaže „Ništa nije na redu", što bi bila laž koju je
izgovorilo samo dugme.

**Linija kroz jednu odluku sada može da se zatraži.** `drillLine` prima
`viaFen` + `viaUci` i šeta samo kroz pozicije do kojih se stiže **tim** potezom
iz **te** pozicije. Potez se traži po tome *odakle je odigran*, ne po samom
polju: potez na indeksu `2i` u lancu je moj potez iz čvora `i`, jer šetnja
dodaje po jedan par po nivou — poklapanje samo po uci uhvatilo bi isti potez
odigran negde drugde. Sama račva **nije** u odgovoru: to je pozicija u kojoj se
bira, ne pozicija do koje izbor vodi.

Na ekranu je to dugme **„Druga odluka"**, i to samo na račvi. Otvara list sa
„Vežbaj d4" po jednom drugom potezu. **Iza pritiska, a ne na tabli** — isto
pravilo koje već važi za „Pokaži": ponavljanje se ne ocenjuje, ali imenovanje
drugog poteza tamo gde su zadržana tačno dva odaje onaj koji se traži, pa
gledanje treba da bude nešto što je učenik uradio, a ne što se desilo samo.

Izabrani put se vidi („Vežbate liniju kroz d4.") i ima izlaz („Nazad na red"),
jer režim koji se ne vidi izgleda kao greška. Ide sa `ahead: true`: traženje
puta je dovoljan razlog da se njime prošeta, a rani odgovor se ne upisuje. Grana
i sparing brišu izbor — veći izbor pobeđuje manji.

Namerno nije rađeno: **biranje grane dublje od prva dva poteza.**
`drillBranches` i dalje grupiše po paru poteza koji otvara granu, pa je
„Druga odluka" jedini način da se bira račva u dubini. To je dovoljno za ono
zbog čega je traženo, a spisak grana kao malo stablo je zaseban posao.

Testovi: backend 784 → **788**, aplikacija 1040 → **1044**. Uživo nije viđeno:
stavka 82 u [TODO-provera.md](TODO-provera.md).

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

