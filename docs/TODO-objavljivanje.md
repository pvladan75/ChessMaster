# TODO — objavljivanje na Google Play

Sve u kodu je spremno. Ostalo je ono što traži naloge, novac i advokata.
Redosled je bitan: svaki korak zavisi od prethodnog.

---

## 1. Google Play Console nalog — ✅ već postoji

Nalog je otvoren i **kroz njega je već objavljena aplikacija**:
[Chess Brain Trainer: Puzzles](https://play.google.com/store/apps/details?id=com.program.braintrainer)
(`com.program.braintrainer`).

Time otpada ceo ovaj korak: $25 je plaćeno, identitet potvrđen, Play review je
već jednom prošao. Ostaje samo:

- [ ] Proveriti da je **merchant nalog** (prodaja, ne samo objavljivanje) aktivan
      i da su uneti podaci za isplatu — Brain Trainer je verovatno besplatan bez
      kupovina, pa merchant možda nikad nije ni podešen. To je preduslov za
      Play Billing, i jedina stvar iz ovog koraka koja može još da nedostaje.
- [ ] Novu aplikaciju napraviti kao **zaseban unos** pod istim nalogom, paket
      `rs.pejovic.chesscoach`.

Uz to, postojeća aplikacija je i **kanal**: publika koja već rešava šahovske
zagonetke je tačno publika ove aplikacije. Unakrsna promocija između dva unosa
pod istim nalogom je najjeftinije sticanje korisnika koje imate — vredi razmotriti
pre plaćenog oglašavanja.

## 2. Google prijava mora ponovo da se registruje

**Ovo neće pući pri build-u — pući će tek kad se neko pokuša prijaviti.**
`google-services.json` sadrži OAuth klijent vezan za stari paket
`com.example.chess_app`, a aplikacija se sada zove `rs.pejovic.chesscoach`.

U **Google Cloud Console → Credentials**:

- [ ] Novi **OAuth client ID → Android**, paket `rs.pejovic.chesscoach`.
- [ ] Dodati SHA-1 **debug** ključa (za razvoj na svojoj mašini).
- [ ] Dodati SHA-1 **release / upload** ključa.
- [ ] Dodati i SHA-1 iz **Play Console → Setup → App signing**, ako koristite Play
      App Signing. Bez ovoga prijava radi lokalno a puca u objavljenoj verziji —
      klasična zamka.
- [ ] Preuzeti nov `google-services.json` i zameniti
      `chess_app/android/app/google-services.json`.

**Backend ne dirati.** `GOOGLE_CLIENT_IDS` sadrži *web* klijent
(`425483567970-jgkipp2df...`), koji je ujedno `serverClientId` u aplikaciji.
Publika ID tokena se ne menja preimenovanjem paketa.

## 3. Pravni dokumenti

- [ ] Dati advokatu na proveru: `docs/politika-privatnosti.md` i
      `docs/saglasnost-roditelja.md`. Posebno delove o maloletnicima i o
      prenosu podataka van Srbije.
- [ ] Popuniti označena polja: ime/naziv, adresa, email za privatnost, rokovi
      čuvanja snimaka, hosting provajder i region.
- [ ] **Objaviti politiku privatnosti na javnom URL-u.** Play Console traži link
      pre nego što pusti aplikaciju — bez toga se ne može objaviti. Gde tačno:
      vidi korak 3a niže.
- [ ] Uneti taj URL u Play Console → App content → Privacy policy.
- [ ] Popuniti **Data safety** formu u Play Console-u prema onome što piše u
      politici (email, glas, snimci, rezultati vežbi).

## 3a. Sajt — nije marketing, nego preduslov

Lako ga je odložiti kao „kad stignemo", ali **korak 3 zavisi od njega**: Play
neće pustiti aplikaciju bez javnog URL-a politike privatnosti, a Play traži i
kontakt podrške. Sajt je mesto gde oba žive. Uz to je i jedini način da se
desktop verzija uopšte podeli — nju Play ne raznosi.

**Odluke koje treba doneti pre pisanja ijedne stranice:**

- [x] **Domen — odlučeno 16.8.2026: `chesstrainers.app`, uz `chesstrainers.net`
      kao trajno preusmerenje (301).** Ime je krovno namerno: sve tri aplikacije
      *jesu* trenažeri (Brain Trainer, Blindfold Trainer, i ova platforma), pa
      četvrta ništa ne ruši. `.com` je registrovan i parkiran kod GoDaddy-ja, na
      prodaju — **svesno se ne kupuje**; novac je prečiji za sertifikat za
      potpisivanje Windows verzije. Posledica koju treba prihvatiti: ko ukuca
      `.com` završi na parkiranoj stranici sa reklamama, pa se adresa uvek deli
      kao link.

      Dve stvari koje `.app` nosi sa sobom:

      - Ceo `.app` je na **HSTS preload** listi, pa pregledač odbija običan HTTP —
        ne upozorava nego neće da otvori. Dok certbot ne izda sertifikat, sajt ne
        izgleda „nezaštićeno" nego potpuno pokvareno. Bitno za redosled pri
        postavljanju.
      - Registrovati uz **zaštitu podataka u WHOIS-u**. Vlasnik je fizičko lice;
        bez toga kućna adresa i telefon idu u javnu bazu.
- [ ] **Gde stoji.** Najjeftinije i najprostije: statičke stranice sa istog
      droplet-a, kroz nginx koji već radi i certbot koji već obnavlja
      sertifikate. Nema novog troška ni novog naloga. Alternativa je GitHub
      Pages, ali onda su sajt i API na dva mesta bez potrebe.

**Šta sajt mora da nosi:**

- [ ] Politika privatnosti i saglasnost roditelja — iz `docs/`, na stalnim
      URL-ovima koji se ne menjaju (Play ih pamti).
- [ ] **Kontakt podrške.** Play traži adresu; za početak je dovoljna jedna
      stranica i email. Sistem za tikete je preterivanje dok nema korisnika.
- [ ] Opis i spisak mogućnosti. Piše se **jednom** i koristi i kao tekst u Play
      listingu. Pri tom: ime „Chess Master" / „Chessmaster" se **ne koristi** —
      to je Ubisoft-ov brend (vidi „Odvojeno: ime aplikacije" niže).

**Preuzimanje se razlikuje po platformi, i to je prava tema:**

- [ ] **Android — link ka Play-u, ne APK.** Direktan APK uči korisnika da
      isključi zaštitu i gubi automatska ažuriranja. APK samo za probu, na
      skrivenoj stranici.
- [ ] **Windows — instalacija, i tu je trošak.** Nepotpisan `.exe` dočekuje
      SmartScreen upozorenjem koje većinu ljudi vrati nazad. Sertifikat za
      potpisivanje koda je godišnji trošak reda nekoliko stotina evra. Odluka:
      platiti, ili prihvatiti upozorenje i objasniti ga na stranici za
      preuzimanje.
- [ ] **iOS / macOS — nije ni građeno.** Flutter to može, ali traži Apple
      Developer nalog ($99 godišnje) i Mac za potpisivanje. Dok se ne odluči,
      sajt ne sme da ih pominje.

## 4. Proizvodi za pretplatu

- [ ] Napraviti pretplatničke proizvode u Play Console-u
      (npr. `coach_pro_monthly`, `coach_pro_yearly`, `club_monthly`).
- [ ] Upisati ih u backend `.env`, u `PLAY_PRODUCT_TIERS`:
      `{"coach_pro_monthly":"premium","club_monthly":"club"}`
      Proizvod koji nije u mapi **ne dodeljuje ništa** — namerno, da nova cena ne
      bi slučajno poklonila premium.

## 5. Servisni nalog za verifikaciju kupovina

- [ ] Napraviti service account sa pravima **View financial data** i
      **Manage orders and subscriptions**, i dati mu pristup aplikaciji.
- [ ] Popuniti u `.env`: `GOOGLE_PLAY_PACKAGE_NAME=rs.pejovic.chesscoach`,
      `GOOGLE_PLAY_SA_EMAIL`, `GOOGLE_PLAY_SA_PRIVATE_KEY`
      (sa `\n` escape-ovima, kako stoji u `.env.example`).

## 6. Obaveštenja o obnovi pretplate (RTDN)

- [ ] Generisati tajnu: `node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"`
- [ ] Upisati je kao `PLAY_RTDN_SECRET`.
- [ ] U Play Console uključiti Real-Time Developer Notifications sa Pub/Sub push
      URL-om: `https://VAŠ-HOST/billing/play/rtdn?key=TAJNA`
- [ ] Poslati test notifikaciju iz Play Console-a. Endpoint je prepoznaje i loguje
      — to je potvrda da je žica spojena.

## 7. Prva prava kupovina

- [ ] Objaviti build na **internom testu**.
- [ ] Obrisati staru instalaciju sa `com.example.chess_app` sa test uređaja —
      neće se ažurirati, to je sada druga aplikacija.
- [ ] Kupiti pretplatu test nalogom i proveriti da se tier promeni.
- [ ] Proveriti da je kupovina **acknowledged** — nepotvrđene Play refundira
      posle 3 dana.

## 8. Tek na kraju

- [ ] `ENABLE_LIMITS=true` u backend `.env`.
      **Ne ranije.** Dok kupovina ne radi, ovo zaključava besplatne naloge na 5
      sesija mesečno bez ijednog načina da se otključa.

---

## Odvojeno: ime aplikacije

`applicationId` je namerno **odvojen od brenda** — `rs.pejovic.chesscoach` je
vezan za vas, ne za ime, pa se ime može menjati koliko god puta zatreba.

- [ ] Odlučiti prikazno ime aplikacije.
- **Ne koristiti „Chess Master" / „Chessmaster"** — to je Ubisoft-ov brend, serija
  od 20+ izdanja od 1986., i to u **istoj kategoriji** (softver za učenje šaha).
  Isto ime + ista vrsta robe je najgori mogući slučaj kod žigova.
- „Pawn to King" je pravno znatno bezbednije, ali pešak po pravilima **ne može da
  postane kralj** — publika su treneri i primetiće.
- Pre nego što se odlučite, proverite redom: pretraga u Play Store-u,
  [ZIS baza žigova](https://www.zis.gov.rs), EUIPO eSearch, slobodan domen.

## Posle preimenovanja paketa — sitnica

Windows verzija sada koristi `AppData\Roaming\rs.pejovic\chess_app` umesto
`AppData\Roaming\com.example\chess_app`. Preuzeti Stockfish i podešavanja su
ostali na staroj putanji. Prekopirati folder ili pustiti aplikaciju da ponovo
preuzme motor.

## Infrastruktura — pre nego što aplikacija izađe iz testiranja

Trenutno: baza 1 GB RAM / 10 GiB, droplet 1 vCPU / 1 GB RAM / 25 GB (AMS3).
Za testiranje je dovoljno; mereno je ~11 MB zvuka po satu časa, što je ~1600
sati na 25 GB. Sledeće troje nije hitno, ali svako od njih zagrize tiho.

- [x] **Politika zadržavanja fajlova — ✅ urađeno 15.8.2026.**
      `services/retentionService.js` briše MP4 izvoze starije od
      `EXPORT_RETENTION_DAYS` (podrazumevano 14 dana) — pokreće se pri startu
      servera i zatim svaka 24h (`server.js`). Redovi u `session_recordings`
      čiji je `video_url` pokazivao na obrisan fajl se čiste (`video_url = NULL`),
      da dugme za preuzimanje ne ponudi 404 — sam snimak i zvuk ostaju netaknuti.
      `uploads/` (zvuk) namerno nije uključen: to je jedina kopija časa i ne
      sme da se briše automatski.
- [x] **Swap na droplet-u — ✅ urađeno 15.8.2026.** 2GB `/swapfile`, upisan u
      `/etc/fstab` (preživljava restart), `vm.swappiness=10` u
      `/etc/sysctl.d/99-swappiness.conf` da se ne koristi agresivno u normalnom
      radu — samo kao zaštita kad MP4 izvoz naglo potroši RAM. Backup originalnog
      `fstab`-a je na droplet-u kao `/etc/fstab.bak-swap`.
### Nov droplet — ✅ napravljen i postavljen 15.8.2026

Stari droplet (Ubuntu 25.04, van podrške) je **obrisan**; na njemu nije bilo
ničega našeg. Nova mašina je `chess-backend-ams3`: Ubuntu 26.04 LTS, 1 vCPU /
2 GB / 50 GB, AMS3, dnevne rezervne kopije, rezervisani IP, tag `chess-backend`.

Sve je postavljeno i provereno, ali servis je **namerno ugašen i isključen iz
automatskog podizanja** dok aplikacija ne pređe na njega — dva backend-a nad
istom bazom razdvajaju `uploads/` i stanje sesija.

Redosled (odrađeno):

- [x] **„Trusted Sources" na bazi** — dodat **tag** `chess-backend`, ne pojedina
      mašina, pa buduće presipanje servera ne traži izmenu na bazi. Stari droplet
      skinut. (Da je promašeno, backend ne bi mogao do baze, a greška izgleda kao
      pogrešna lozinka.)
- [x] **Rezervisani IP** `209.38.55.151` zakačen. Napomena: mašina tu adresu
      **ne vidi** na svojim interfejsima — DO je rutira spolja, pa sve mora da
      sluša na `0.0.0.0`, nikad na konkretnoj adresi.
- [x] Kreiran droplet: Ubuntu 26.04 LTS, AMS3, postojeći SSH ključ.
- [x] **Pokrenut [`deploy/provision.sh`](../deploy/provision.sh)** — jedna
      komanda umesto šest koraka:

      scp deploy/provision.sh root@HOST:/tmp/ && ssh root@HOST 'bash /tmp/provision.sh'

      Radi zakrpe, Node 22+ (iz distribucije ako je dovoljno nov, inače
      NodeSource), `ffmpeg` — koji **nije opcion**, jer ga `audioTrimmer.js` i
      `videoRenderer.js` pozivaju po imenu — swap i `swappiness`, `journald`
      ograničen na 200 MB, `ufw`, nalog `chess` koji nije `root`, i automatske
      bezbednosne zakrpe. Na kraju sam proveri da `zlib.zstd*` postoji. Skripta
      je idempotentna, može da se pokrene ponovo bez štete. **Java se ne
      instalira** — backend je Node, Android se gradi u CI-ju.
- [x] Restart posle nadogradnje jezgra.
- [x] Obrisan stari zapis iz `known_hosts` na radnoj stanici.
- [x] **Pokrenut [`deploy/app-setup.sh`](../deploy/app-setup.sh)** — nginx,
      Let's Encrypt sertifikat, `systemd` servis. Tri stvari u njemu nose težinu:
      `client_max_body_size 120m` (backend prima snimke do 100 MB, a nginx
      podrazumevano odbija preko 1 MB — greška bi izgledala kao kvar snimanja),
      `Upgrade`/`Connection` zaglavlja bez kojih Socket.IO tiho pada na
      polling, i izričito imenovana grana pri kloniranju.
- [x] **Baza: privatni host i provera sertifikata.** `DB_HOST` je `private-...`
      ime, `DB_CA_PATH` pokazuje na CA klastera. Provereno na živoj vezi:
      `rejectUnauthorized: true`, `TLS socket authorized: true`, PostgreSQL 17.10.
      Pre toga `openssl s_client -starttls postgres` potvrdio da SAN sertifikata
      sadrži i privatno ime — nije bilo sigurno unapred, jer se sertifikati često
      izdaju samo za javno ime. Vidi `buildSslConfig` u `db.js` i
      `test/db_ssl_config.test.js`.
- [x] **DNS — ✅ postavljen 16.8.2026.** Sva tri zapisa na rezervisani IP
      (`@`, `www`, `api`). Zatečeni Namecheap parking zapisi obrisani, jer bi se
      sudarali. `chesstrainers.net` je URL Redirect (301) na `.app`.
- [x] **Privremeno `sslip.io` ime zamenjeno — ✅ 16.8.2026.** Backend je sada na
      **`https://api.chesstrainers.app`**, sertifikat važi do 14.11.2026. i
      obnavlja se sam. Provereno spolja: `HTTP 200`, sertifikat prolazi proveru,
      `http` se preusmerava.

      Stari sslip.io sertifikat je **obrisan** (`certbot delete`) — nginx ga više
      ne opslužuje, pa bi mu obnova pucala i slala izveštaje o grešci na mejl.
- [ ] **Prebacivanje:** `systemctl enable --now chess-backend`, pa `backendUrl` u
      aplikaciji sa LAN adrese na `https://api.chesstrainers.app`. Jedan smer u
      jednom trenutku.
- [ ] **Veća baza pre punog Lichess seta.** 50k zagonetki je zanemarljivo, ali
      punih 6,1M sa GIN indeksom po temama neće udobno stati u 1 GB RAM-a.

Nije uzrok brige: Stockfish radi na klijentu, a glas nosi Agora — server ne
analizira pozicije niti prenosi zvuk uživo, pa je 1 vCPU sasvim dovoljan za
sesije. MP4 izvoz renderuje jedan frejm po sekundi časa i `await`-uje između
njih, pa ne blokira Socket.IO.
