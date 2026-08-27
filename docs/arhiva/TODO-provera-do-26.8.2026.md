# TODO — provere zaključene do 26.8.2026

Izdvojeno iz [TODO-provera.md](../TODO-provera.md) 27.8.2026. Ovde su stavke
koje su **i označene kao proverene uživo i nemaju nijednu otvorenu kutijicu** —
dakle zatvorene u celini. Ono što je makar delom otvoreno ostalo je u glavnom
fajlu, ceo odeljak zajedno, da se dokaz i preostali korak ne razdvajaju.

**Brojevi stavki su namerno zadržani** onakvi kakvi su bili. Drugi dokumenti
upućuju na njih po broju („stavka 27 u `TODO-provera.md`"), pa bi prenumerisanje
pokvarilo ta upućivanja. Zato u glavnom fajlu brojevi preskaču — to nije greška.

**Ne čita se unapred**; `grep` po broju ili naslovu kad treba dokaz da je nešto
prošlo, i šta je tačno provereno.

> Dve stavke ovde opisuju tok koji **više ne postoji**: snimanje časa sa
> učenikom u sobi (stavka 4, i poslednja kutijica stavke 34). Od 26.8.2026. zvuk
> se snima samo dok je vlasnik sam u sobi — vidi
> `chess_backend/services/recordingConsent.js`. Zadržane su kao zapis šta je
> tada provereno, ne kao opis današnjeg ponašanja.

---

## 0. Pristanak na odnos trener–učenik — ✅ provereno uživo 17.8.2026

Korisnik je prošao ceo tok na telefonu: poziv sa naloga trenera → red „čeka
potvrdu" posivljen kod pozivaoca → kartica „Čeka vaš odgovor (1)" sa tekstom
„želi da vas upiše kao učenika" kod pozvanog → prihvatanje → zadata lekcija.
Potvrđeno i u bazi: veza je prešla u `accepted` sa upisanim `responded_at`,
prijateljstvo je nastalo tek tada, a zadatak je napravljen dva minuta posle
prihvatanja.

**Nađeno pri toj probi, popravljeno istog dana:** kod trenera se prihvatanje
nije videlo dok se aplikacija ne ugasi i ponovo pokrene — lista se dohvatala
samo pri pokretanju. Sad se osvežava pri ulasku u tab i na povlačenje nadole.
Uz to je notifikacija koja nosi zahtev ostajala **nepročitana zauvek**, pa je
zvonce trajno pokazivalo broj za nešto već rešeno.

**Uzajaman par raskinut 17.8.2026.** Korisnik ga je obrisao iz aplikacije, sa
jedne strane; nestala su **oba** reda odjednom (`removeRelationship` briše u oba
smera) i oba reda u `friends`. U bazi više nema nijednog uzajamnog para, a jedina
preostala veza je nastala kroz pristanak i nosi `initiated_by`. Time je zatečenih
podataka iz vremena pre pristanka nestalo.

**Drugi smer i odbijanje — ✅ provereno uživo 17.8.2026.** Korisnik je poslao
zahtev sa naloga trenera birajući **„Ja sam učenik"**; druga strana je dobila
tačan tekst za taj smer („želi da mu budete trener", ne obrnuto), pa ga je
odbila. Red je nestao iz `trainer_students`, a notifikacija koja ga je nosila
prešla je u `is_read = true` — dakle i sinoćna popravka radi na živim podacima.

**Odbijanje zabrane uzajamnog para — ✅ provereno uživo 17.8.2026.** Pokušaj da
se zasnuje odnos u suprotnom smeru od postojećeg vraća poruku i ne pravi red.

Ostaje da se proveri uživo:

- Ponovno slanje posle odbijanja. Tabela je posle probe prazna, pa ništa ne
  stoji na putu, ali sam potez nije ponovljen.

**Obaveštenje o odbijanju — napisano 17.8.2026, nije viđeno uživo.** Nađeno pri
gornjoj probi: pošiljalac odbijenog zahteva nije dobijao **nikakav** trag, pa sa
njegove strane „odbijen sam" i „nikad nisam ni poslao" izgleda isto. Sad mu stiže
obaveštenje „*X nije prihvatio vaš zahtev.*", bez razloga — vrsta
`request_declined`, bez dugmadi.

**Kako proveriti:** pošalji zahtev, odbij ga sa druge strane, pa se vrati na
nalog pošiljaoca i otvori zvonce. Servis je pokriven testovima; **poziv iz rute
`/relationships/:id/decline` nije nijednom izvršen na živim podacima.** Gledaj i
da se obaveštenje prikaže kao običan tekst — klijent ne grana po `kind`-u, pa bi
nova vrsta trebalo da prođe kao svaka druga, ali to niko nije video.

<details>
<summary>Prvobitni opis provere (16.8.2026)</summary>

**Kako:** Prijatelji → unesi email → „Dodaj prijatelja". Sad se šalje **poziv**, a
ne veza. Prijavi se kao druga strana → isti tab → kartica „Čeka vaš odgovor" →
kvačica.

**Na šta obratiti pažnju:**

- Dok je na čekanju, učenik stoji u listi **posivljen, sa „čeka potvrdu"**, a
  dugme za napredak i zadatke je nedostupno. Ako je dostupno, provera na serveru
  je jedino što stoji između — a to je već jednom bilo premalo.
- Posle prihvatanja: zadavanje zagonetki i lekcije mora da proradi **odmah**, bez
  ponovne prijave.
- Odbijanje briše zahtev; ponovno slanje mora da radi.
- Oba smera sada imaju dugme: iznad polja za email biraš **„Ja sam trener"** ili
  **„Ja sam učenik"**, i natpis polja se menja u skladu s tim. Proveriti da
  izbor „Ja sam učenik" stvarno stigne kao *zahtev treneru* — druga strana mora
  da vidi „želi da mu budete trener", ne obrnuto.

> **Zatečeni podaci:** tri postojeće veze su prešle kao `accepted`, i među njima
> je i **uzajaman par** koji je i bio bag (dvoje koji su dodali jedan drugog).
> Taj par je raskinut 17.8.2026.
>
> **Ispravka ih ne sprečava** — suprotno onome što je ovde ranije pisalo.
> `requestRelationship` proverava postojeći red samo u **istom** smeru
> (`trainer_id = $1 AND student_id = $2`), pa je obrnuti red drugi red i prolazi.
> Pristanak čini da par više ne može da nastane nečujno, ali može da nastane.

</details>

## 4. Snimanje časa — ✅ provereno 15.8.2026

Ceo tok je prošao uživo: snimanje → potezi → pauza → nastavak → zaustavljanje →
čuvanje → reprodukcija, uključujući i zvuk (koji do tada nikad nije radio).

Provereno i na podacima, ne samo okom: snimak `id=13` ima svih 10 događaja i na
uređaju i u bazi, sa istim vremenima. Razmak između poteza je ~1–2 s osim jednog
od 4830 ms tačno na mestu pauze — dakle mrtvo vreme pauze **jeste** oduzeto, što
je i bio razlog refaktora u `LessonRecorder`.

**Sinhronizacija zvuka posle pauze — ✅ provereno.** Agora ne ume da pauzira
snimanje, pa mikrofon radi kroz pauzu dok je vremenska osa table zamrznuta. Sad
klijent uz snimak šalje intervale pauza, a server ih iseče iz zvuka
(`services/audioTrimmer.js`) pri čuvanju. Provereno uživo: snimanje sa pauzom pa
reprodukcija — tabla i glas idu zajedno do kraja.

Sečenje je namerno „best effort": ako FFmpeg zakaže, snimak se svejedno sačuva sa
neisečenim zvukom. Bolje neusklađen zvuk nego izgubljen čas. Ako sinhronizacija
ikad opet odluta, prvo potraži `[AUDIO TRIM] Cut N pause(s), Xms total` u logu
servera — bez te linije sečenje nije ni pokušano (`ffmpeg` van PATH-a ili
`pauseIntervals` nije stigao).

**MP4 izvoz — ✅ provereno uživo 15.8.2026.** Poslednja neproverena veća funkcija
snimanja, i najskuplja po CPU na droplet-u od 1 vCPU. Čekala je na admin nalog i
Premium (stavka 11) — posle toga korisnik potvrdio da izvoz radi.

## 7. Uvoz partija sa Chess.com/Lichess — ✅ obe strane potvrđene uživo

**Lichess potvrđen 15.8.2026** (korisnik isprobao). Chess.com je potvrđen ranije
istog dana, uz bag koji je usput nađen i popravljen — vidi niže.


**Kako:** Analysis Studio → dugme za „Unos Pozicije" → kartica „Chess.com/Lichess" →
izaberi platformu, unesi korisničko ime → „Preuzmi Partije". Sleće na karticu
„PGN Uvoz" sa popunjenim tekstom; ako ima više partija, prvo pita koju kroz isti
birač kao kod PGN fajla sa više partija.

**Na šta obratiti pažnju:**
- Chess.com strana je uživo isprobana direktnim pozivom (van aplikacije) i radi —
  pravi PGN, pravi headeri.
- Lichess strana je **samo delimično potvrđena uživo**: ruta i format su tačni po
  zvaničnom API spec-u, i sam poziv sa ispravnim `User-Agent`-om je dobio pravi
  odgovor servera (ne generičku grešku), ali test je posle nekoliko pokušaja
  udario u Lichess-ovo ograničenje brzine i nisam uspeo da vidim pravi PGN u
  odgovoru. Prva stvar za proveru kad se ovo isproba uživo.
- **Napomena za dalji rad:** Lichess ćutke vraća lažnu 404 stranicu zahtevima bez
  prepoznatljivog `User-Agent`-a — samo na ovoj ruti (`/api/games/user/...`), ne
  i na `/api/user/...`. Servis sad šalje `User-Agent: ChessMasterCoach/1.0`; ako
  se ikad ukloni ili promeni, ova ruta će ponovo tiho „ne raditi" umesto da
  vrati grešku.
- Samo klikanje kroz dijalog (tab, dugme, layout) nije provereno okom — nema
  alata za automatizaciju native Windows GUI-ja u ovoj sesiji. `flutter analyze`
  je čist, testovi prolaze.

**✅ Nađeno i popravljeno 15.8.2026, korisnik je isprobao uživo:** uvoz sa
Chess.com je javljao „Neispravan PGN format" pri prebacivanju na tablu. Uzrok:
Chess.com stavlja `{[%clk ..]}` komentar posle svakog poteza, što po PGN
konvenciji primorava oznaku `12...` za nastavak crnog — a `chess` paket (0.7.0)
u svom `load_pgn`-u skida obično `12.` naivnim regex-om, ali ne i `12...`,
pa ostave dve tačke kao otpadak koji se tumači kao nepostojeći potez i obara
ceo uvoz. Ovo pogađa **svaki** PGN sa komentarima koji prekidaju par poteza, ne
samo Chess.com — uključujući ručno nalepljen PGN sa sajtova koji izvoze satove
ili engine-komentare. Popravka: `PgnParser.sanitizeForLoadPgn` (`pgn_parser.dart`)
skida `12...` pre poziva `load_pgn`, pozvano iz `_importPgn` u
`analysis_studio_screen.dart`. Test koji pada bez ispravke:
`test/pgn_parser_sanitize_test.dart` (potvrđeno `git stash`-om).

## 11. Admin dodela naloga — ✅ odrađeno i testirano uživo 15.8.2026

`UPDATE users SET role = 'admin'` za nalog `id=5` (vlasnikov glavni nalog),
potvrđeno pre i posle upisa. Nalog `id=3`, prvobitno predložen pa promenjen,
nije diran. (Emailovi se namerno ne upisuju ovde — repozitorijum je javan.)

`POST /users/account-type` je zatim **stvarno pozvan** (ne direktan upis u
bazu) — admin token mintovan sa istim `JWT_SECRET`-om koji server koristi,
poziv vraćen 200: `account_type` za taj nalog promenjen na
`'premium'`. Ovo je prvi put da je ovaj endpoint uopšte pozvan — bio je
napisan i testiran jedinično, ali nikad pogođen uživo.

Korisnik se ponovo prijavio i potvrdio da **MP4 izvoz radi** (stavka 4) —
ceo lanac je sad zatvoren.

Stavka 10 (merenje troška) je sad otključana admin nalogom — `GET
/billing/usage` sam izveštaj i dalje nije otvoren okom. Stavka 9 (naplata)
ostaje blokirana na nešto drugo: pravu kupovinu, koja čeka Play Console, ne
admin nalog.

## 15. Pregled domaćeg i komentari — ✅ provereno uživo 20.8.2026

Backend je pozvan preko HTTP-a sa tokenima obe strane; pravilo o rešenju,
komentari i sva odbijanja su provereni, probne poruke obrisane.

**Korisnik je 20.8.2026. prošao i ekrane**, na Windows-u i na telefonu: odigran
potez uz rešenje po poziciji, „nije zabeležen" na starom Lichess zadatku,
komentar na poziciju i na ceo zadatak sa oba naloga, iks samo na svojoj poruci.
Ista proba je otkrila i stavku 17.

**Kako:** kao trener — Prijatelji → učenik → dodir na zadatak u listi. Kao
učenik — „Moji zadaci" → „Pregled i komentari" na kartici zadatka.

**Na šta obratiti pažnju:**

- [x] Na svakoj poziciji se vidi **tabla**, zadatak, ocena i vreme.
- [x] **Odigran potez** piše „nije zabeležen" za sve stare zadatke — to je tačno,
      jer se potez čuva tek od 20.8.2026. Za **nov** odgovor mora da stoji potez.
- [x] Kod učenika se **rešenje ne vidi** na poziciji koju nije uradio, i stoji
      „otkriva se kad odgovoriš". Kod trenera se vidi.
- [x] Zadatak tipa **lekcija** nema ocenu „netačno" ni na jednom koraku — samo
      „pregledano" ili „nije otvoreno".
- [x] Komentar na ceo zadatak i komentar na jednu poziciju stoje na različitim
      mestima, i druga strana ih vidi (proveriti na oba naloga).
- [x] Svoju poruku mogu da obrišem, tuđu ne — kod tuđe nema iksa.
- [x] Na telefonu se kartica pozicije ne preliva (tabla 120 px + tekst desno).

## 16. Slobodan redosled domaćeg — ✅ provereno uživo 20.8.2026

Čisto klijentska izmena; server nije menjan.

**Provereno uživo 20.8.2026:** mreža od šest pozicija sa stanjima, „Počni",
„Pozicija 3 od 6", „Sledeća nerešena", i ocena „Nije to · Rešenje: Qf1#" posle
namerno pogrešnog odgovora.

**Kako:** kao učenik, „Moji zadaci" → otvori zadatak sastavljen od trenerovih
pozicija.

**Na šta obratiti pažnju:**

- [x] Zadatak se otvara kao **mreža svih pozicija**, ne odmah kao tabla.
- [x] Tri stanja se razlikuju na prvi pogled: `tačno`, `netačno`, `nije urađeno`.
- [x] Dodir na **bilo koju** neurađenu poziciju je otvara — i onu na kraju.
- [x] „Nastavi" vodi na **prvu** neurađenu, a ne na onu posle poslednje otvorene.
- [x] Preskoči drugu poziciju, uradi ostale, pa na poslednjoj pritisni „Sledeća
      nerešena" — mora da te vrati **na preskočenu**, ne da izađe.
- [x] Već urađena pozicija se otvara sa zaključanom tablom i porukom „računa se
      prvi pokušaj"; figure se ne pomeraju.
- [x] Traka napretka raste kako se rešava, a ne kako se šeta kroz spisak.
- [x] Na telefonu mreža ima dve kolone i kartica se ne preliva.

## 17. Tabla u lekciji i čitljiva linija — ✅ provereno uživo 20.8.2026

Obe izmene su nastale iz probe u stavkama 14–16 i proverene istog dana, na
svežem build-u za Windows i na telefonu.

**Kako:** kao učenik otvori zadatu lekciju u kojoj neki korak ima zadatak.

- [x] **Figure se pomeraju.** Posle prvog poteza se pojavljuje „Vrati poziciju"
      i napomena da se ništa ne ocenjuje.
- [x] „Vrati poziciju" vraća tačno onu poziciju koju korak pokazuje — i kad se
      stoji usred varijante, ne na njen početak.
- [x] Prelazak na sledeći korak sam vraća tablu; ništa se ne prenosi.
- [x] Napredak i dalje broji **pregledane korake**, ne odigrane poteze, i ne
      pojavljuje se nikakva ocena.
- [x] U pregledu Lichess zadatka linija piše kao `Rb7 Rxb7 g8=Q`, a ne kao
      `e7b7 b8b7 g7g8q`.

## 18. Prva pogrešna ideja u zagonetki — ✅ provereno uživo 20.8.2026

**Kako:** kao učenik otvori zadatak sa Lichess zagonetkama („Domaći zadatak"),
pa **namerno odigraj pogrešan potez**, zatim tačan. Onda uradi jednu zagonetku
**iz prve**, bez greške. Pa otvori „Pregled i komentari".

**Na šta obratiti pažnju:**

- [x] Kod zagonetke gde si pogrešio piše **„Prvo probao: <potez>"** — u
      notaciji, ne kao `e2e4`.
- [x] Kod zagonetke rešene iz prve **nema nijednog reda o potezu**. Ne sme da
      piše „nije zabeležen".
- [x] Kod starih zagonetki (pre 20.8.2026) i dalje piše „nije zabeležen".
- [x] Kod trenera piše isto, samo „Prvo probao" umesto „Prvo si probao".
- [x] Linija ispod i dalje stoji u čitljivom zapisu.

## 19. Zvonce odgovara na zahtev — ✅ provereno uživo 20.8.2026

Odgovor na zahtev za odnos preselio se iz taba Prijatelji u zvonce. Server nije
menjan.

**Kako:** treba drugi nalog. Pošalji zahtev sa jednog naloga, pa se prijavi na
drugi i otvori zvonce.

**Na šta obratiti pažnju:**

- [x] U zvoncetu zahtev ima **kvačicu i krstić**, i kaže ko šta traži.
- [x] Posle odgovora red **ostaje** i piše „Zahtev je prihvaćen/odbijen"; dijalog
      se ne zatvara sam.
- [x] **Značka pada** posle odgovora (broji i zahteve, ne samo poruke).
- [x] U tabu Prijatelji **nema više kartice** „Čeka vaš odgovor".
- [x] Sivi red u listi kaže na koga se čeka: „čeka potvrdu" kad sam ja poslao,
      „odgovorite u zvoncetu" kad se čeka moj odgovor.
- [x] Posle prihvatanja odnos se pojavi u listi kao običan, bez restarta.
- [x] Odbijanje i dalje šalje obaveštenje pošiljaocu („nije prihvatio vaš
      zahtev"), i ponovno slanje posle odbijanja radi.
- [x] Na telefonu se dijalog ne preliva sa dugmadima u redu. *(Prelivao se —
      vidi belešku ispod.)*

**Telefon još nema ovaj build** — poslednja stavka ostaje neproverena dok se
uređaj ne priključi i ne odradi `chess_app/build_and_deploy.ps1`.

**Zapaženo pri proveri 20.8.2026 (nije greška u ovome, nego rupa pored):**
onaj ko je **poslao** zahtev ne vidi da je druga strana prihvatila sve dok ne
izađe iz taba Prijatelji i ne vrati se u njega. Lista se osvežava pri ulasku u
tab, a ne dok se u njemu stoji. Uz to, `accept` ne šalje pošiljaocu nikakvo
obaveštenje — `decline` šalje. Vidi „Prihvatanje se ne vidi kod pošiljaoca" u
[STANJE-RADA.md](../STANJE-RADA.md).

## Nađeno na telefonu 20.8.2026, popravljeno istog dana

Uz stavke 20 i 21, proba na telefonu je izbacila četiri greške koje **nijedan
test i nijedan log nisu mogli da pokažu**, jer release build ne crta upozorenje
o prelivu:

1. **Traka za poteze** — devet dugmadi u jednom redu; NAG i brisanje poteza su
   bili van ekrana. Sad `Wrap`.
2. **Gornji red u Analysis Studio-u** — devet radnji, a `AppBar` ih seče;
   „Podešavanja" i „Unos Pozicije / PGN" nisu bili dohvatljivi. Sad meni sa tri
   tačke na uskom ekranu.
3. **Dijalog sa obaveštenjima** — sadržaj je imao fiksnu širinu 360, a telefon
   *jeste* 360 dp, pa je uz margine izlazio 79 px van ekrana. Zato se
   „pavle želi da vas upiše kao učenika" lomilo po jednu reč u red. Širina se
   sad uzima iz ekrana, a dugmad su ispod teksta i nose natpise „Prihvati" i
   „Odbij" umesto gole kvačice.
4. **Prazne ikone na Windows-u** — `Icons.handshake` i `Icons.chat_bubble_outline`
   crtale su se kao ništa, jer `flutter build windows` nije ponovo napravio
   `MaterialIcons-Regular.otf`; font je bio stariji od trenutka kad su ikone
   dodate. Android ga je regenerisao, pa je ista verzija bila ispravna na
   telefonu i pogrešna na Windows-u. Vidi CLAUDE.md.

**Novi izgled reda sa zahtevom je viđen uživo istog dana:** naslov u jednom
redu, a ispod njega „✗ Odbij" i „✓ Prihvati" sa natpisima. Redosled je namerno
takav — odbijanje levo, potvrda desno, da se potvrda ne pritisne u prolazu.

## 22. Baza otvaranja preko servera — ✅ provereno uživo 24.8.2026

Lichess Explorer se više ne zove iz aplikacije nego iz backenda, koji drži jedan
token i keš. Korisniku token više nije potreban.

**Pre probe:** `LICHESS_API_TOKEN=...` u `chess_backend/.env` i restart backenda.
Token se pravi na `lichess.org/account/oauth/token/create` **bez ijedne dozvole**
— dugme „Napravi token" u Podešavanjima otvara baš tu stranicu sa popunjenim
opisom. Dok toga nema, ruta vraća 503 sa `reason: "not-configured"`, što je
ispravno ponašanje, ali nije ono što se ovde proverava.

- [x] Analiza → panel „Lichess Opening Explorer" pokazuje statistiku partija
      **bez ikakvog tokena u Podešavanjima**. To je cela poenta izmene.
      *(Korisnik potvrdio 24.8.2026, uz token u `.env` na lokalnom backendu.)*
- [x] Ista pozicija drugi put: panel se popuni odmah, a u dnevniku backenda nema
      novog upita ka Lichess-u. To je keš.
- [x] Filter „2000+" menja brojeve. Ranije je pokazivao samo partije između 2000
      i 2199 iako je pisalo 2000+; sada su uključene i sve grupe iznad.
- [x] Ugašen backend, pa pomeren potez: panel pređe na ChessDB, a u dnevniku
      aplikacije stoji `⛔ Nedostupno (network)`. **Prazna baza i nedostupna baza
      ne smeju da izgledaju isto** — to je greška koja se u ovom projektu vraća.
- [x] Namerno pokvaren token u `.env`: u dnevniku backenda `[EXPLORER]
      unauthorized`, u aplikaciji ChessDB. Ista provera kao za tablice.
- [x] Podešavanja → „Napravi token" otvara lichess.org sa popunjenim opisom i
      **bez ijedne čekirane dozvole**.
- [x] Unet lični token: upit onda ide pravo na Lichess (u dnevniku aplikacije
      nema poziva ka našem backendu za otvaranja), i panel i dalje radi.
- [x] Gost, bez prijave: panel pokazuje ChessDB, ne praznu Lichess tablu.

**Korisnik je prošao ovo 24.8.2026. na Windows verziji i potvrdio da radi kako je opisano.**

## 23. Spisak prečica — ✅ provereno uživo 24.8.2026

Stranica „Prečice na tastaturi" (`/shortcuts`). Postoji jer je Ctrl+, bila
napravljena, testirana i neupotrebljiva — nije imalo gde da se pročita da
postoji.

- [x] **F1** na Windows-u otvara spisak preko onoga što je bilo, a **Esc** ga
      zatvara i vraća tačno tamo.
- [x] Držanje F1 ne slaže spisak na spisak.
- [x] Podešavanja → „PREČICE NA TASTATURI" → „Spisak prečica" otvara istu
      stranu. To je jedini put na telefonu.
- [x] Sve što na spisku piše zaista radi: Esc, Ctrl+`,`, strelice u šetnji kroz
      partiju, desni klik na tablu. Spisak koji laže gori je od nepostojećeg.
- [x] Na 360 dp se nijedan red ne preliva — tekst se prelama unutar kartice.
- [x] F1 dok je fokus u polju za tekst i dalje otvara spisak, a slova i strelice
      u tom polju ostaju polju.

**Korisnik je prošao spisak 24.8.2026. na Windows-u i potvrdio da radi kako je
opisano.**

## 24. Strelice na pet ekrana — ✅ provereno uživo 24.8.2026

Tastature na Androidu nema, pa je ovo provera za Windows. Svuda gde ispod table
stoji traka sa potezima važi isto: ← → potez, ↑ ↓ krajevi linije, Home/End isto
što i ↑ ↓.

- [x] **Analiza:** strelice šetaju po varijanti, i tabla ih prati.
- [x] **Soba:** strelice rade kod onoga ko vodi tablu, a kod onoga ko je ne vodi
      **ne rade** — isto pravilo koje traka već poštuje.
- [x] **Lekcija (zadatak tipa lekcija):** strelice šetaju kroz liniju koraka.
- [x] **Ponavljanje:** pre „Prikaži nastavak" strelice **ne rade**. Ovo je
      namerno: inače bi tastatura rekla odgovor pre nego što se dete seti.
      Posle otkrivanja rade.
- [x] **AI ekran (vežbe):** strelice rade kad ispod table postoji traka, a kad
      trake nema ne rade ništa (nema linije za šetnju).
- [x] Home i End rade svuda gde i ↑ ↓.
- [x] **Dok je fokus u polju za tekst** (komentar u analizi, kod sobe), strelice
      pripadaju polju i ne pomeraju poteze.
- [x] Šetnja kroz partiju i dalje radi kao pre — nije dirana.

**Korisnik je prošao svih pet ekrana 24.8.2026. na Windows-u i potvrdio da rade
kako je opisano — uključujući obe ograde (ponavljanje pre otkrivanja, mesto koje
ne vodi tablu u sobi) i strelice u polju za tekst.**

## 25. Ctrl+1…4 i Ctrl+C — ✅ provereno uživo 24.8.2026

- [x] **Ctrl+1…4** na početnom ekranu menja tabove: Trening, Časovi,
      Biblioteka, Ljudi. Radi **odmah po otvaranju**, bez ijednog klika pre
      toga.
- [x] Dok je otvorena vežba ili soba preko početnog ekrana, Ctrl+2 ne menja tab
      ispod — tasteri pripadaju onome što je gore.
- [x] Dok je fokus u polju za kod sobe, cifre se kucaju u polje.
- [x] **Ctrl+C** kopira FEN sa table koja je na ekranu, isto što i desni klik, i
      isto tako kaže da je kopirano. Probati na više ekrana (analiza, soba,
      vežbe).
- [x] **Ctrl+C dok je označen tekst u polju** (komentar u analizi) kopira
      **tekst**, ne poziciju. Ovo je bilo pokvareno pri izradi i popravljeno;
      vredi videti uživo.
- [x] Ctrl+C na ekranu bez table ne radi ništa i ne javlja ništa.
- [x] Uz to, ponovo: strelice na ekranu koji je **tek otvoren**, bez klika pre
      toga. Isti uzrok kao gore, popravljen posle provere stavke 24.

**Korisnik je prošao ovo 24.8.2026. na Windows verziji i potvrdio da radi kako je opisano.**

## 27. Sud o potezu u Analizi — ✅ provereno uživo 24.8.2026

Novi panel „Sud o potezu" u Analizi, i `GET /opening-judge` iza njega. Traži
**vaš** Lichess token u Podešavanjima — server svoj namerno ne troši na ovo.
Backend mora da radi (`npm run dev`).

Bez tokena:

- [x] Panel objašnjava zašto ne radi i nudi dugme „Podešavanja". Nema dugmeta
      „Presudi".
- [x] Baza otvaranja u istoj Analizi i dalje radi normalno — nju token ne
      uslovljava.

Sa tokenom, na tabli na kojoj je odigran potez:

- [x] Dugme „Presudi <potez>" stoji tek kad je neki potez odigran; na početnoj
      poziciji piše „Odigrajte potez na tabli pa ga presudite".
- [x] **Teorija:** odigrati 1.e4 e5 2.Nf3 i presuditi — „Glavna teorija", uz
      broj partija majstora.
- [x] **Greška:** odigrati 1.e4 e5 2.Bc4 Qh4?? ili 1.f3 e5 2.g4 — presuda je
      „Sumnjiv potez", uz „Bolje je bilo …" i „Kažnjava se sa …".
- [x] Kazna koja se ispiše zaista mat ili gubitak figure — odigrati je rukom na
      tabli i videti da linija ima smisla.
- [x] **Crni potez se sudi iz ugla crnog.** Ovo je jedino mesto gde greška ne
      bi ličila na grešku: presuda bi bila obrnuta, i to samo za jednu boju.
      Odigrati loš potez **crnim** i proveriti da piše da gubi, a ne da dobija.
- [x] Presuda ostaje uz svoj potez: presuditi potez, pa strelicom otići na
      drugi — panel više ne pokazuje staru presudu.
- [x] Isti potez presuđen dvaput ne pravi novi upit (drugi put stiže odmah).
- [x] Retka pozicija koju oblak nema: presuda je „Nije presuđeno", sivo, sa
      rečenicom da to nije isto što i loš potez.

Ograničenja i greške:

- [x] Pogrešan token u Podešavanjima → „Lichess je odbio vaš token".
- [x] Panel se može isključiti u Podešavanjima („Sud o potezu"), kao i ostali
      paneli Analize.

**Korisnik je prošao ovo 24.8.2026. na Windows verziji i potvrdio da radi kako je opisano.**

## 34. Glas ima nivo — ✅ provereno uživo 25.8.2026

Treba trener, jedan učenik i (za prvu stavku) curl ili Postman.

**Korisnik je 25.8.2026. potvrdio sve stavke.**

- [x] **Rupa koja je zatvorena:** nalog **bez veze** sa trenerom pozove
      `POST /agora/token` sa tuđim kodom sobe kao `channelName` → **403**.
      (Ranije: `PUBLISHER` token i ulazak u glas mimo spiska zvanica, bez
      pojavljivanja na spisku učesnika.)
- [x] Trener uđe u svoju sobu → ima dugme za mikrofon i čuje se.
- [x] Učeniku se u bazi postavi `voice_level = 'listen'`
      (`UPDATE trainer_students SET voice_level = 'listen' WHERE ...`), pa uđe u
      sobu: **ne traži mu se dozvola za mikrofon**, umesto dugmeta stoji
      „Slušate čas", a na spisku učesnika je slušalica.
- [x] Taj učenik čuje trenera i vuče poteze po tabli.
- [x] Klikne **Da**, **Ne**, **Nisam razumeo/la** → treneru se pojavi poruka sa
      njegovim imenom. (Ime dolazi sa servera — provera da nije ono što je
      klijent poslao.)
- [x] Trener na spisku učesnika klikne **Daj mikrofon** → učeniku stigne poruka,
      aplikacija se sama ponovo priključi kanalu, dozvola za mikrofon se traži
      **tek sad**, i od tog trenutka se čuje.
- [x] Trener klikne **Oduzmi mikrofon** → učenik se više ne čuje, a i dalje je u
      času. Provera da nije samo utišan: neka učenik pokuša „Uključi mikrofon" —
      tog dugmeta nema.
- [x] Nova veza sa učenikom kome je upisana godina maloletnika kreće od
      `listen` (`SELECT voice_level FROM trainer_students` posle prihvatanja).
- [x] Snimanje časa na nivou „sluša": u snimku se čuje trener, a ne i dete.
- [x] `node server.js` se uopšte pokreće. (Na `master`-u pre ovoga nije —
      `SyntaxError` u `audio_join`.)
