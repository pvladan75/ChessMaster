# TODO — šta još nije provereno u aplikaciji

Sve navedeno je napisano, prolazi testove i `flutter analyze`, ali **nije viđeno
kako radi uživo**. Automatski testovi pokrivaju logiku; ne pokrivaju da li je
dugme na pravom mestu i da li tok ima smisla.

Poređano od najbržeg za proveru ka najsporijem.

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

## 0a. Obaveštenja posle popravke — 17.8.2026, nije viđeno uživo

**Kako:** otvori zvonce na **oba** rasporeda — na Androidu je u zaglavlju, na
Windows-u je sada u levoj traci (`NavigationRail`), gde ga ranije nije bilo.

**Na šta obratiti pažnju:**

- Lista se otvara i kad među obaveštenjima ima onih **bez sobe** (zahtev za
  odnos, odbijanje). Do sada je to bio beo ekran.
- Pozivnica u sobu i dalje ima „Pridruži se" i ulazi u sobu; zahtev za odnos
  nema dugme nego uputstvo da se odgovara u tabu Prijatelji.
- **Značka broji nepročitana.** Posle otvaranja i čitanja broj mora da padne.
  Zatečeno stanje: jedno staro obaveštenje (#7) je odgovoreno pre popravke koja
  ih zatvara, pa će ostati nepročitano dok ga ne otvoriš.
- Na telefonu proveri i da se naslov dijaloga ne preliva.

## 0b. Reprodukcija snimaka posle prelaska na relativne putanje — 16.8.2026

**Kako:** otvori **stari** snimak (napravljen pre ove izmene) — zvuk mora da radi
kao i pre, jer se apsolutna adresa propušta nedirnuta. Pa **snimi nov čas** i
pusti ga: taj se u bazi čuva kao `/uploads/ime.aac` i klijent ga sastavlja.

Proveri i **MP4 izvoz** — link za preuzimanje je isto postao relativan, a nosi
potpisan token u upitu. Ako token nestane pri sastavljanju, preuzimanje vraća 401
koji izgleda kao da fajl ne postoji.

## 1. Izveštaj za roditelja

**Kako:** Prijatelji → učenik → ikona 📄 u zaglavlju → izaberi period, napiši
poruku → „Napravi" → otvori link.

**Na šta obratiti pažnju:**
- Da li se link otvara u pregledaču bez prijave.
- `Ctrl+P` treba da da čist PDF bez dugmadi.
- Ako učenik nije ništa radio u tom periodu, izveštaj to mora **reći rečima**, a
  ne prikazati nule.

## 2. Zadaci tipa „lekcija"

**Kako:** napravi lekciju u sesiji („Kreiraj lekciju") → Prijatelji → učenik →
„Zadaj lekciju" → prijavi se kao učenik → „Moji zadaci" → otvori je.

**Na šta obratiti pažnju:**
- Da li se koraci smenjuju i da li navigacija kroz poteze radi za korake
  sačuvane iz Analysis Studija.
- **Lekcija sa zadatom početnom pozicijom** — ako navigacija kroz poteze nedostaje,
  to je namerno: parser bi inače prikazao pogrešnu liniju, pa se korak prikazuje
  kao statična pozicija.
- Da li se napredak („3/5 koraka pregledano") vidi kod trenera.
- Da izlaz i povratak nastavlja gde je stao, a ne iz prvog koraka.

## 3. Ponavljanje u razmacima

**Kako:** prođi kroz zadatu lekciju i oceni korake → „Ponavljanje" na početnoj.

**Na šta obratiti pažnju:**
- Da li se ocenjeni korak vraća na red kad mu dođe vreme.
- Da „Ponovo" vrati korak istog dana, a „Lako" ga odgurne daleko.

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

## 5. Keširanje evaluacija

**Kako:** u Analysis Studiju uradi „Analiziraj celu partiju", pa **odmah zatim**
„Automatska analiza" nad istim pozicijama.

Druga operacija treba da bude osetno brža. U logovima se vidi linija
`[EvalCache] ... iz keša (N%)`.

Ako promenite motor u podešavanjima, keš se prazni — druga analiza posle toga
opet ide punom brzinom, i to je namerno.

## 6. Mobilni raspored

**Kako:** pokrenuti na telefonu (ili suziti prozor na ~360 px).

Testovi renderuju dijaloge na 360×640 i 320×568 i hvataju prelivanje, ali
**„Moji zadaci" i izveštaj o učeniku nisu pokriveni** — oni zovu server pri
otvaranju, pa bi test visio. Njih treba pogledati okom.

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

## 8. Preimenovanje paketa

Aplikacija je sada `rs.pejovic.chesscoach`.

- [ ] Obrisati staru instalaciju sa `com.example.chess_app` — neće se ažurirati,
      to je sada druga aplikacija.
- [ ] **Google prijava neće raditi na Androidu** dok se ne registruje nov OAuth
      klijent za novi paket. Vidi `TODO-objavljivanje.md`, korak 2.
- [ ] Na Windows-u su podaci sada u `AppData\Roaming\rs.pejovic\chess_app` —
      preuzeti Stockfish je ostao na staroj putanji.

## 9. Naplata — nije isprobana u ovoj aplikaciji

Ceo sloj (prava pristupa, Play verifikacija, RTDN, kvote) radi po testovima, ali
**nijedna prava kupovina nije obavljena kroz ovu aplikaciju**. Prvi stvarni
`purchaseToken` je jedini pravi dokaz.

**Nalog nije prepreka — provereno 15.8.2026.** Play Console i merchant deo rade:
korisnikova druga aplikacija (`com.program.braintrainer`) prodaje Premium za
pravi novac, i sam je obavio kupovinu i povraćaj. Ostaje ono što je vezano za
ovu aplikaciju: unos u Play Console za `rs.pejovic.chesscoach`, proizvodi koji
odgovaraju `PLAY_PRODUCT_TIERS`, servisni nalog (`GOOGLE_PLAY_SA_*`) i RTDN
adresa — a ona traži domen.

> Za probu **ne treba ponovo plaćati sopstvenim novcem**. Play Console →
> Setup → License testing prima naloge koji kupuju bez naplate, uz pun
> `purchaseToken` i RTDN obaveštenja. Isto važi i za obnovu pretplate, koja se
> testnim nalozima ubrzava na nekoliko minuta umesto mesec dana.

Vidi `TODO-objavljivanje.md`.

## 10. Merenje troška — nikad pogledano

Agora sekunde i MP4 renderi se beleže od prvog dana, ali izveštaj nije otvaran:

```bash
curl -s "$BACKEND_URL/billing/usage?month=2026-08" -H "Authorization: Bearer $ADMIN_TOKEN"
```

Admin nalog sad postoji (stavka 11) — ovo je jedino što je nedostajalo. Ostaje
samo da se izveštaj stvarno otvori i pogleda da li brojevi imaju smisla.

Posle toga se **morate ponovo prijaviti** da bi token nosio novu ulogu.

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

## 12. Skener pozicija iz knjige — backend proveren uživo 19.8.2026, ekran nije

**Backend je stvarno pozvan**, ne samo testiran jedinično. Token mintovan istim
`JWT_SECRET`-om koji server koristi, pa ceo lanac preko HTTP-a:

- `POST /scans` sa pravim PDF-om od 5,4 MB, strane 32–51 uz rešenja 972–980 →
  **200 za 1,3 s**, 120 pozicija, nijedna sporna, font prepoznat kao
  `SkakNew-Diagram`. Prva: `#97` sa `Qf1#`, strana na potezu pročitana iz
  rešenja.
- `POST /scans/confirm` sa 3 ispravne pozicije i **jednom namerno pokvarenom** →
  201, sačuvano 3, odbijeno 1 uz razlog (`Invalid FEN: castling availability is
  invalid`). Dakle provera na serveru radi i ne propušta smeće.
- `GET /scans/puzzles` vratio tačno ta tri reda, sa temama i `needs_review`.
- Redovi napravljeni probom su posle obrisani; `custom_puzzles` je opet prazna.

**Nađeno pri toj probi i popravljeno istog dana.** Privremeni PDF se briše u
`finally` — ali `finally` se ne izvrši ako proces bude ubijen usred zahteva.
Nodemon koji se restartuje na snimanje fajla je dovoljan, i tako je i otkriveno:
kopija knjige od 5,4 MB ostala je da leži u `%TEMP%\chess-scans`. Sad se pri
pokretanju servera brišu svi zaostali `scan_*` fajlovi, uz upozorenje u dnevniku.
Provereno posle popravke: direktorijum je prazan odmah po skeniranju.

**Ekran je prošao uživo 19.8.2026.** Korisnik je skenirao `23.pdf`, strane
32–51, i potvrdio čuvanje: u bazi stoji **120 pozicija, svih 120 sa proverenim
rešenjem, nijedna obeležena kao sporna**. Time je usput potvrđeno i troje što je
ranije bilo nepoznato: `file_picker` na Windows-u **vraća putanju** za PDF, mreža
sa 120 dijagrama je upotrebljiva, i ulaz iz Biblioteke vodi gde treba.

**Nađeno pri toj probi:** pozicije su sačuvane, a korisnik nije imao gde da ih
vidi — ekran je čuvao u prazno. Dodato istog dana: `GET`/`DELETE
/scans/puzzles`, ekran „Moje pozicije" (mreža, filter po knjizi, brisanje,
dodir otvara poziciju na tabli za analizu), dugme u Biblioteci, i poruka posle
čuvanja koja sad nosi „Pogledaj".

**Drugo nađeno na slici, popravljeno istog dana:** pozicije su se prikazivale
redosledom upisa — `#97 #100 #98 #101 #99 #102`. Skener obilazi stranu po
položaju (prvo naniže, pa nadesno), a knjiga numeriše niz levu kolonu pa niz
desnu; uz to svih 120 redova deli isti `created_at`, pa sortiranje po vremenu
nije sortiranje. Sad se sortira po broju dijagrama, i to **kao broj a ne kao
tekst**, inače 100 dolazi pre 97. Provereno na živim podacima: 97, 98, 99, 100…

**Provereno uživo 19.8.2026, drugi krug.** Skeniranje bez odeljka sa rešenjima
(strane 45–64, sve „nepoznato"), preklapanje raspona, ekran „Moje pozicije",
pitanje „ko je na potezu" i otvaranje table za analizu sa tim FEN-om — sve
prošlo. Duplikati su se pojavili tačno kako je predviđeno, pa je pravilo
dopunjavanja ugrađeno i stari duplikati počišćeni (240 → 198).

**Skup je zatvoren 19.8.2026.** Posle drugog skeniranja sa rešenjima i ispravke
devet pozicija kojima je strana bila pogrešna: **198 pozicija, svih 198 sa
rešenjem koje stvarno igra i daje mat, nijedna obeležena, nijedna bez rešenja.**
Provereno upitom nad bazom, a ne na oko.

## 13. Zadavanje skeniranih pozicija učeniku — ✅ ceo lanac prošao uživo 19.8.2026

Knjiga → skener → potvrda → zadatak → dete → ocena → napredak, sa dva naloga i
prihvaćenim odnosom trener–učenik.

Potvrđeno okom: izbor pozicija dugim pritiskom, zadavanje učeniku, učenikov ekran
sa zadatkom u okviru („Beli matira u jednom potezu."), tabla okrenuta ka strani na
potezu, ocena posle poteza, **„Mat u 333: 2/2 urađeno, tačnost 100%"**, napredak
prešao sa 0/4 na 1/4, i izveštaj za roditelja sa ispravno razdvojenim temama.

**Tri greške nađene baš tom probom, sve popravljene istog dana:**

1. **Potez deteta nije radio ništa, bez ijedne poruke.** `move_to_san` mora da se
   pita pre nego što je potez odigran; pozvan posle, puca. Izuzetak u `async`
   rukovaocu otišao je u prazno.
2. **Tabla nikad nije prijavljivala matirajući potez.** Pitala je koliko poteza
   *preostaje* i nulu čitala kao „ništa nije odigrano" — a mat je tačan odgovor u
   svih 198 pozicija. Pogađa i živu sesiju: mat se nije emitovao drugoj strani.
3. **Izveštaj je istu temu zvao i jakom i slabom**, jer su obe liste bile krajevi
   istog niza.

Ostalo iz ovog lanca — čekirano 20.8.2026. kroz probu u stavkama 14–17:

- [ ] **Da li se drugi mat priznaje.** Najlakše na #122 (knjiga `Qe6#`, ali i
      `Qh7#` matira) — očekuje se „Tačno" i objašnjenje „Drugi mat od onog u
      knjizi". Logika je pokrivena testovima, ali okom nije viđena.
- [x] Šta se prikaže posle **netačnog** odgovora (rešenje se otkriva tek tada).
- [x] **Zadatak u lekciji kod učenika** — uokvireni tekst iznad table u
      `lesson_viewer_screen`. Traži zadatu lekciju sa upisanim zadatkom po koraku.
- [ ] Da li se traka „nema veze sa serverom" sama povuče kad server krene
      (ponavlja proveru na 10 s, a povezivanje socketa je računa kao dokaz).
- [x] **Odigran potez se upisuje** (`assignment_items.played_san`, 20.8.2026).
      Kolona se dodaje pri pokretanju servera — u dnevniku mora da stoji
      `Verified database table & indexes: assignment_items`. Pusti dete da
      odgovori na jednu poziciju, tačno i netačno, pa proveri:

      ```sql
      SELECT puzzle_id, solved, played_san FROM assignment_items
       WHERE assignment_id = <id> ORDER BY position;
      ```

      Očekuje se potez u notaciji za oba reda. `NULL` posle stvarnog odgovora
      znači da tabla nije umela da odigra ono što je klijent poslao — u tom
      slučaju u dnevniku stoji `Custom attempt could not be resolved to a move`
      i to je stvarno neslaganje, ne kozmetika. Redovi odgovoreni pre 20.8.2026.
      ostaju prazni i to je ispravno.

---

Ostalo neprovereno:

- [ ] Knjiga sa **drugim fontom** — mapa za `TacticsCourse.pdf` nije završena,
      pa je sve mereno na jednoj knjizi.
- [ ] Šta se dešava kad se pošalje PDF **bez ijednog dijagrama** ili zaštićen
      lozinkom.
- [ ] Filter „traži pogled" nad **mešanim** skupom — dosad je bio ili 0/120 ili
      120/120, nikad delimičan.

Napomena: `custom_puzzles` je nastala pri restartu 19.8.2026
(`Verified database table & indexes: custom_puzzles`), pa taj korak više ne
stoji na putu.

## 14. Biblioteka pozicija i „Dodaj u lekciju" — ✅ provereno uživo 20.8.2026

Backend je pozvan preko HTTP-a (203 stavke iz tri izvora, dopisivanje koraka
201, tri odbijanja svako sa svojim razlogom, probna lekcija obrisana), a
**korisnik je 20.8.2026. prošao i ekrane**: birač sa sve tri police, skenirana
pozicija ušla u lekciju sa svojim zadatkom, korak bez zadatka narandžast,
„Dodaj u lekciju" nad više izabranih pozicija.

Ostalo je neprovereno samo ponašanje kad je **server ugašen** — jedino
stanje koje ova proba nije dodirnula.

**Kako:** Sesija → „Kreiraj lekciju" → **Dodaj iz biblioteke**. Pa Biblioteka →
„Moje pozicije" → dugi pritisak na jednu ili više → **Dodaj u lekciju**.

**Na šta obratiti pažnju:**

- [x] U biraču se vide **sve tri vrste** — iz knjige, sačuvane pozicije, analize
      — i čipovi ih filtriraju.
- [x] **Skenirana pozicija zaista uđe u lekciju** i u koraku piše njen zadatak
      („Beli matira u jednom potezu."), ne samo naslov.
- [x] Kad se doda **analiza**, korak nosi varijante (PGN), a ne samo početnu
      tablu. Ako učitavanje stabla ne uspe, mora da stigne poruka i pozicija —
      ne tiho preskakanje.
- [x] Traženje po tekstu radi (kuca se, pa se posle kratke pauze osvežava lista).
- [ ] Kad je server ugašen, birač kaže **„Nije moguće doći do servera"**, a ne
      „Nema sačuvanih pozicija".
- [x] „Dodaj u lekciju" nad **više izabranih** pozicija: poruka mora da kaže i
      koliko je dodato i koliko nije.
- [x] Na telefonu traka sa tri dugmeta („Poništi", „Dodaj u lekciju", „Zadaj
      učeniku") mora da se prelomi, ne da iscuri sa ekrana.

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

## 18. Prva pogrešna ideja u zagonetki — 20.8.2026, nije viđeno uživo

**Kako:** kao učenik otvori zadatak sa Lichess zagonetkama („Domaći zadatak"),
pa **namerno odigraj pogrešan potez**, zatim tačan. Onda uradi jednu zagonetku
**iz prve**, bez greške. Pa otvori „Pregled i komentari".

**Na šta obratiti pažnju:**

- [ ] Kod zagonetke gde si pogrešio piše **„Prvo probao: <potez>"** — u
      notaciji, ne kao `e2e4`.
- [ ] Kod zagonetke rešene iz prve **nema nijednog reda o potezu**. Ne sme da
      piše „nije zabeležen".
- [ ] Kod starih zagonetki (pre 20.8.2026) i dalje piše „nije zabeležen".
- [ ] Kod trenera piše isto, samo „Prvo probao" umesto „Prvo si probao".
- [ ] Linija ispod i dalje stoji u čitljivom zapisu.
