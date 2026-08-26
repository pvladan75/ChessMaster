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

- [x] **Advokat potvrdio 25.8.2026** da su `docs/politika-privatnosti.md` i
      `docs/saglasnost-roditelja.md` ispravni i da pokrivaju ono što aplikacija
      radi — uključujući snimanje glasa dece, zbog kog su i pisani.
      **Ograda je njegova: proveravao je za Srbiju, za druge države ne zna.**
- [ ] **Odlučiti gde se aplikacija nudi.** Play podrazumevano deli svuda; dok
      pravna provera pokriva jednu državu, spisak zemalja u Play Console-u
      treba suziti na nju. Proširenje je onda odluka, a ne previd.
- [x] **Uzrast nije zakucan u kodu — ✅ urađeno 25.8.2026.** Prag je
      `AGE_OF_CONSENT` u `.env` (podrazumevano 16, najstroža primenljiva
      granica). Van 13–18 server **ne startuje** umesto da se vrati na
      podrazumevano. Ostaje da se od advokata traži sam broj za Srbiju.
- [ ] Popuniti označena polja (`[IME I PREZIME / NAZIV]`, `[ADRESA]`,
      `[EMAIL ZA PRIVATNOST]`, `[DATUM]`, `[URL]`) — **ali ne u ovom
      repozitorijumu.** On je javan, a to su lično ime, adresa i email.
      Popunjena verzija ide na sajt; u `docs/` ostaje nacrt sa praznim poljima,
      jer je on ono što opisuje šta aplikacija radi.
- [x] **Verzija teksta se upisuje — ✅ urađeno 25.8.2026.**
      `PARENT_CONSENT_VERSION` u `.env`, podrazumevano `rs-2026-08-25`; država
      je deo oznake, jer je advokat potvrdio za Srbiju i to izričito rekao.
      Prepisuje se **na zahtev** kad se zahtev napravi, pa roditelj pristaje na
      tekst koji mu je pokazan, a ne na onaj koji je na serveru danas.
- [x] **Tok roditeljske saglasnosti — ✅ urađeno 25.8.2026**, nije viđeno uživo
      (stavka 36 u `TODO-provera.md`). Roditelj potvrđuje preko **linka u
      mejlu**, na stranici koju servira backend — jedino što pošteno popunjava
      `parent_consent_at/ip/version`. Veza sa maloletnikom stoji na
      `awaiting_parent` i ne otključava ništa dok roditelj ne odgovori.
- [x] **Saglasnost za snimanje se sprovodi — ✅ urađeno 25.8.2026**, nije
      viđeno uživo (stavka 37 u `TODO-provera.md`). Kolonu je do tada punila
      roditeljska stranica i čitao je niko. Sad čas ne može da se snima dok je
      u sobi dete čiji roditelj to nije dozvolio, a odbijen snimak ne ulazi u
      `uploads/`.
- [ ] **Podesiti `PUBLIC_BASE_URL` na serveru** pre nego što ijedno dete
      dobije trenera. Prazan znači da pismo ne odlazi (i to se prijavljuje, ne
      preskače tiho), a pogrešan znači link koji nađe tek roditelj koji je već
      odustao. Na droplet-u je to `https://api.chesstrainers.app`, dok se ne
      odluči domen.
- [ ] **Age gate — ✅ napisan 25.8.2026**, ali proveriti uživo (stavka 35) da
      pita i **postojeće** naloge, ne samo nove. Bez toga `birth_year` ostaje
      prazan i sva pravila o maloletnicima ne odbijaju nikoga.
- [x] **Soba: spisak zvanica — ✅ urađeno 25.8.2026**, nije viđeno uživo
      (stavke 31, 32 i 34 u `TODO-provera.md`). `mayJoinRoom` čuva `joinGame` i
      `audio_join`, kod se pravi iz `crypto.randomInt`, prekidač „soba prima
      goste" je u sobi, a `POST /agora/token` — koji je izdavao token za bilo
      koji kanal i time zaobilazio ceo spisak — pita isto pitanje i nosi ulogu
      `SUBSCRIBER` za onoga ko samo sluša.
- [x] **Email van spiskova — ✅ urađeno 25.8.2026.** `GET /friends`, spisak
      učenika i spisak trenera vraćaju ime i identifikator. Polje za pozivanje
      po adresi ostaje — pozivaš nekoga čiju adresu već znaš.
- [x] **Maloletnik samo sa prihvaćenim trenerom — ✅ urađeno 25.8.2026**, nije
      viđeno uživo (stavka 33 u `TODO-provera.md`). `ageService.mayRelate`:
      maloletnik je nečiji učenik, nikad nečiji trener. Prijatelji nisu dobili
      pristanak nego su **ukinuti kao mehanizam** — `POST /friends/add` je
      obrisan, jer ga nijedan ekran nikad nije ni zvao, pa red u `friends` sada
      nastaje isključivo iz prihvaćene veze.
      **Zubi tek sa age gate-om:** dok nijedan nalog nema upisanu godinu, ovo
      pravilo ne odbija nikoga.
- [ ] **Probati prijavu Family Link nalogom** (nalog deteta pod roditeljskim
      nadzorom) pre objave. Google ume da traži odobrenje na roditeljskom
      uređaju pre nego što izda token; taj tok niko nije video, a on je prvi
      koji dete sretne.
- [ ] **Pitati advokata izričito o potvrdi mejlom.** Za mlađe od 13 u SAD
      (COPPA) potvrda mejlom se prihvata samo za internu upotrebu, a ovde
      trener dobija snimak dečjeg glasa. Pitanje je odloženo dok je distribucija
      sužena; pri širenju se postavlja prvo.
- [ ] **Pitati advokata o obliku, ne samo o tekstu.** Neke države ograničavaju
      maloletnike na *društvenim mrežama*, a to se meri vezama korisnik–korisnik
      i direktnom komunikacijom, ne temom aplikacije. Od 25.8.2026. je **svaka**
      veza u aplikaciji obostrano pristanak (`POST /friends/add` je obrisan), a
      maloletnik može biti samo nečiji učenik. Pitanje advokatu je time uže:
      da li aplikacija u kojoj dete ima vezu isključivo sa punoletnim trenerom
      i govori tek kad trener odobri i dalje pada pod ta ograničenja.
- [ ] U Play Console-u popuniti **Target audience & content** i deo o
      korisnički generisanom sadržaju iskreno: soba ima glas, a „Ljudi" ima
      veze među korisnicima. Šta se tamo prijavi mora da odgovara onome što
      aplikacija zaista radi tog dana.
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
- [x] **Gde stoji — odlučeno 17.8.2026: isti droplet.** Statičke stranice kroz
      nginx koji već radi i certbot koji već obnavlja sertifikate. Nema novog
      troška ni novog naloga. Alternativa je bila GitHub Pages, ali bi onda sajt
      i API stajali na dva mesta bez potrebe.

      **Odluka je namerno povratna.** Sajt nema bazu ni stanje, pa je selidba
      kopiranje foldera i promena DNS zapisa. Ono što vezuje nisu mašina ni
      provajder nego **adrese**: Play pamti URL politike privatnosti, pa domen i
      putanje moraju ostati isti — ko ih servira je nevidljivo.

      **Uslov pod kojim to ostaje jeftino: `@`/`www` dobijaju svoj sertifikat,
      odvojen od `api`.** `deploy/app-setup.sh` sada traži sertifikat sa
      `-d "$HOST"` i `--cert-name "$HOST"`, dakle samo za API — tako i treba da
      ostane. Ako se `@` i `www` dodaju na taj isti sertifikat (`--expand`), a
      sajt se kasnije preusmeri drugde, certbot će nastaviti da obnavlja imena
      koja ta mašina više ne servira: HTTP-01 za njih pukne, obnova **celog**
      sertifikata pukne, i sa njim padne `api` koji niko nije dirao. Tri meseca
      kasnije i bez ijedne poruke — isti oblik kao zatvaranje porta 80.

- [x] **Jezik sajta — odlučeno 26.8.2026: engleski.** Otuda i adrese
      `privacy@` i `support@`, a ne `privatnost@`/`podrska@`. Ovo je **izuzetak
      od pravila** iz `CLAUDE.md` da su korisnički tekstovi srpski: ono važi za
      aplikaciju, sajt je druga publika.

      **Posledica koju treba rešiti pre objave:** stranice u `site/` su
      napisane na srpskom i treba ih prevesti. A politiku privatnosti je
      advokat proverio **na srpskom i za Srbiju** — prevod nije provereni
      tekst. Treba odlučiti šta je merodavno: ili sajt nosi obe verzije uz
      izričitu napomenu koja je obavezujuća, ili engleska verzija ide na novu
      pravnu proveru. Stranica saglasnosti koju servira backend ostaje srpska,
      jer je vezana za `PARENT_CONSENT_VERSION` i za tekst koji je potvrđen.

**Šta sajt mora da nosi:**

- [x] Politika privatnosti i saglasnost roditelja — na stalnim URL-ovima koji se
      ne menjaju (Play ih pamti). **Napisano 26.8.2026** u `site/`, i objavljuje
      se sa `deploy/site-setup.sh`. Adrese su
      `/politika-privatnosti`, `/saglasnost-roditelja`, `/kontakt`.

      **Dva primerka, po odluci iznad:** `docs/*.md` ostaje nacrt sa praznim
      poljima, jer je to ono što opisuje šta aplikacija radi i što je advokat
      čitao; `site/*.html` je objavljena verzija sa popunjenim vrednostima. Kad
      se jedan menja, mora i drugi — na sajtu je i **snimanje opisano kao
      sprovedeno pravilo** (server odbija i zaustavlja snimanje), što je urađeno
      posle pravne provere.
      Stranica `/saglasnost-roditelja` namerno **nije obrazac**: obavezujući
      tekst generiše `routes/consent.js` i nosi `PARENT_CONSENT_VERSION`, pa
      treći primerak nije smeo da nastane.
- [x] **Kontakt podrške.** Play traži adresu; za početak je dovoljna jedna
      stranica i email. Sistem za tikete je preterivanje dok nema korisnika.
- [ ] **Popuniti vrednosti u `.env` na dropletu i pokrenuti skriptu.** Stranice
      nose `{{PLACEHOLDER}}`-e koje `site-setup.sh` puni iz `.env`
      (`OPERATOR_NAME`, `OPERATOR_ADDRESS`, `PRIVACY_EMAIL`, `SUPPORT_EMAIL`,
      `HOSTING_PROVIDER`, `HOSTING_REGION`, `SMTP_PROVIDER`,
      `SITE_LAST_UPDATED`). Skripta **odbija da objavi** stranicu u kojoj je
      ijedan ostao — politika koja ne imenuje rukovaoca gora je od nikakve.
      Ime i adresa su fizičkog lica i zato ne smeju u repozitorijum.
- [ ] `chesstrainers.net` još pokazuje na parkiranu stranicu, ne na droplet.
      Dok se A zapis ne prebaci, `site-setup.sh` preskače preusmerenje i to
      **kaže naglas** umesto da ćuti.
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

## 7a. Veličina aplikacije — Stockfish nosi 114 MB

Izmereno 17.8.2026. nad `app-arm64-v8a-release.apk`:

| stavka | veličina |
|---|---|
| `lib/arm64-v8a/libstockfish.so` | **114,0 MB**, od čega 112,6 MB `.rodata` |
| ceo Agora SDK (osam biblioteka) | ~59 MB |
| `libflutter.so` + `libapp.so` | ~21 MB |
| assets (zagonetke, ECO) | ~4 MB |
| **APK ukupno** | **221 MB** |

Onih 112,6 MB `.rodata` je NNUE mreža ušivena u binarni fajl. Biblioteka **jeste**
strip-ovana (nema ni `.symtab` ni `.debug_*`), pa se tu nema šta dobiti.

APK je veći nego što izgleda i iz drugog razloga: native biblioteke se pakuju
**nekompresovano** (`STORED`, 281 unos), što je današnje podrazumevano ponašanje
— veći APK, ali manja instalacija i brže pokretanje, jer se mapiraju u memoriju
umesto da se raspakuju. Zato GitHub-ov artefakt-ZIP ispada 128 MB: to je isti
APK, samo ZIP kompresuje ono što APK namerno ne kompresuje. **Nije druga
verzija** — ta razlika je jednom već delovala kao da CI gradi nešto drugo.

**Zašto je ovo stavka pred objavljivanje:** Play ne prima APK nego AAB, i ima
granicu veličine preuzimanja. Ovo se ne rešava podešavanjem nego odlukom:

- [ ] **Manja NNUE mreža.** Stockfish radi i sa manjom mrežom; gubi se nešto
      snage, koja za rad sa decom ionako nije usko grlo.
- [ ] **Ili preuzimanje mreže pri prvom pokretanju**, umesto pakovanja. Aplikacija
      već ume da preuzme Stockfish na desktop-u, pa mehanizam nije nov — ali
      uvodi prvo pokretanje koje traži mrežu i mesto na uređaju.
- [ ] Proveriti da li se Agora deo može smanjiti: pola njegove veličine su
      proširenja (praćenje lica, uklanjanje pozadine, prostorni zvuk) koja ova
      aplikacija ne koristi.

Ništa od toga nije hitno dok se deli APK za probu. Postaje blokada na koraku 8.

## 7b. Agora App Certificate — bez njega glas nije zaključan

Nađeno 25.8.2026, dok se pravo na mikrofon prebacivalo u token.

`AGORA_APP_ID` i `AGORA_APP_CERTIFICATE` se čitaju u `routes/agora.js`. Bez
sertifikata server izdaje **prazan token** i sam upozori u dnevniku: kanal je
tada otvoren svakome ko ima App ID, a App ID je po prirodi javan i stoji u
aplikaciji.

To znači da sve što je urađeno oko glasa — spisak zvanica, uloga `SUBSCRIBER`
za onoga ko sluša, dete koje ne dobija mikrofon dok trener ne odobri — **važi
tek kad je sertifikat uključen**. Do tada je uloga u tokenu savet, a ne brava.
Server to i kaže u odgovoru (`warning`), da razlika ne bude nevidljiva.

- [ ] U Agora konzoli uključiti **App Certificate** za ovaj projekat.
- [ ] Upisati `AGORA_APP_CERTIFICATE` u `.env` na mašini i restartovati servis.
- [ ] Provera: `POST /agora/token` vraća `tokenRequired: true` i token koji nije
      prazan, a u dnevniku stoji `Issued PUBLISHER token` ili
      `Issued SUBSCRIBER token`.
- [ ] Provera da brava stvarno drži: nalog bez veze sa trenerom traži token za
      tuđ kod sobe → **403** (to važi i bez sertifikata), a učenik koji sluša
      dobija `SUBSCRIBER` — i sa izmenjenim klijentom ne može da objavi zvuk.

## 8. Tek na kraju

- [ ] `ENABLE_LIMITS=true` u backend `.env`.
      **Ne ranije.** Dok kupovina ne radi, ovo zaključava besplatne naloge na 5
      sesija mesečno bez ijednog načina da se otključa.
- [ ] **Pre toga: priključiti ograničenja uopšte.** Nalaz 26.8.2026 —
      `checkUserLimits` u `limitsService.js` **nema nijednog pozivaoca**, ni u
      jednom testu. Model postoji (besplatno = 5 soba mesečno, brojano po
      `rooms.creator_id`, 20 lekcija), ali ga ne sprovodi niko, pa prekidač
      iznad danas ne menja ništa. Dok se ne priključi, besplatan nalog je
      neograničen bez obzira na `.env`.
- [ ] **Neposlušan klijent** — proba druge brave na upisu snimka
      (`POST /recordings/save` → 403 i obrisan fajl) traži skript koji emituje
      `recording_status_update {status:'started'}` mimo ekrana, jer aplikacija
      to dugme tada gasi. Nije hitno dok je jedini klijent naš i poslušan; **na
      dan kad APK bude javan prestaje da važi** — fajl koji svako može da
      izmeni je tačno klijent zbog koga ta brava postoji. Vidi
      `PITANJA-ZA-ODLUKU.md`, „Druga brava na upisu snimka".

---

## Odvojeno: ime aplikacije

`applicationId` je namerno **odvojen od brenda** — `rs.pejovic.chesscoach` je
vezan za vas, ne za ime, pa se ime može menjati koliko god puta zatreba. Menja
se **samo** prikazno ime; `applicationId` posle prvog objavljivanja ne može
nikada.

### Odluka, 26.8.2026: kućni brend odvojen od proizvoda

Tri aplikacije dele izlog na `chesstrainers.app`:

| Aplikacija | applicationId | Prikazno ime | Stanje |
|---|---|---|---|
| BrainTrainer | `com.program.braintrainer` | Chess Brain Trainer | objavljena, v7.0 |
| BlindfoldTrainer | `com.program.blindfoldtrainer` | Blindfold Trainer | neobjavljena, v0.1 |
| ova | `rs.pejovic.chesscoach` | **Potez** | neobjavljena |

**Dve vežbalice zadržavaju opisna imena, platforma dobija brend.** To nije
nedoslednost nego podela posla. Vežbalicu čovek nađe tako što u Play-u ukuca
šta mu treba, pa opisno ime radi posao pretrage. Do platforme se ne dolazi
pretragom — niko ne kuca „snimanje časa sa saglasnošću roditelja" — nego
preporukom trenera roditelju, a preporuka traži ime koje se izgovori i zapamti.
Dva imena služe pretrazi, treće služi pamćenju. `chesstrainers.app` je kućni
brend nad sva tri i za tu ulogu je opisnost prednost.

Posledica: Potez **nema svoj domen** i ne treba mu. Živi pod izlogom.

Prefiks `rs.pejovic.*` razbija `com.program.*` druga dva. Ostaje kako jeste:
Play ne grupiše po prefiksu, korist bi bila nula. Zabeleženo da odluka bude
svesna, a ne propuštena — ovo je bio poslednji trenutak kad se mogla promeniti.

### Zašto Potez

- Znači tačno ono što aplikacija radi, a napolju ne znači ništa. To je
  *arbitraran* žig, najjača kategorija koja postoji (Kodak, Xerox). Opisno ime
  je najslabija. Presedan istog oblika: **Anki** — japanski za „učenje
  napamet", globalni proizvod za učenje.
- Pet slova, dva sloga, bez suglasničkih grupa. Ukuca se čim se čuje.
- **Ne prevoditi ga.** „The Move" je generično u kategoriji, neregistrljivo i
  nepretraživo; prevod ubija jedini razlog zbog kog ime radi.
- Jedini nosilac imena je Potez Aéronautique (francuska avio-industrija,
  `potez.com`) — druga klasa robe, bez dodira sa softverom za obuku.

**Otvoreno, za advokata:** EUIPO odbija žig koji je opisan na **bilo kom**
zvaničnom jeziku EU, a hrvatski je zvaničan i *potez* na njemu znači isto.
Rizik postoji, nije presudan — reč je sugestivna pre nego opisna za softver, a
figurativni žig (reč + logotip kao celina) redovno prolazi tamo gde gola reč ne
prođe. Van EU (SAD, UK) pitanje ne postoji. Isti advokat koji je 25.8.2026.
potvrdio tekst saglasnosti.

### Odbačena imena i razlog

Da se ne predlažu ponovo. Sva su pala na proveri, ne na ukusu.

| Ime | Zašto je palo |
|---|---|
| Chess Master / Chessmaster | Ubisoft, 20+ izdanja od 1986, **ista kategorija**. Najgori mogući slučaj kod žigova. |
| Pawn to King | Pešak po pravilima ne može da postane kralj. Publika su treneri. |
| Knight School | The Knight School — postojeća firma za časove šaha deci po školama, sa trenerima i robom. Ista roba, isti uzrast. |
| Caissa | Zauzeto višestruko u istoj kategoriji: Caissa School of Chess sa svojom aplikacijom, caissa-chess.org sa treningom i analizom, Caissa Chess Academy. |
| Knightly | `knightlychess.com` je „AI-powered nightly chess trainer" — doslovan opis ovog proizvoda. Uz to još tri odvojene aplikacije istog imena. |
| Outpost | Outpost Chess, „AI chess coach", 100.000+ igrača, Play + App Store. |
| Chesscraft | ChessCraft, Play i iOS, izdavač MWM. |
| Chess Forge | Dvaput: FOSS Windows alat za studije, repertoar i PGN — skoro isti spisak funkcija — i aplikacija na Play-u. |
| Tesuji | Tesuji Games Inc sa žigom, i žig Tesuji Corp iz 1995. za **softver za obrazovne namene**. Naša klasa. |
| Move by Move | Vodeća edukativna serija izdavača Everyman Chess, čiji je koncept izričito da oponaša čas sa trenerom. Isti proizvod u drugom mediju. |
| The Move | Generično u kategoriji — šah se sastoji od poteza. Neregistrljivo, nepretraživo, domeni zauzeti, plus poznat bend iz šezdesetih. |
| Chess Studio / Chess Study / Chess Trainer Studio | Opisna imena. „Studio" je uz to već zauzet **unutar same aplikacije** (`features/analysis_studio/`), a „study" je naziv centralne funkcije na Lichess-u. |
| Zwischenzug / Međupotez | Bez sukoba, ali 11 slova i grupa suglasnika koju stranac ne ume da napiše po sluhu — najgora osobina za ime koje se prenosi usmeno. Semantika je uz to pogrešna: zwischenzug je smicalica, ne učenje. „Međupotez" pada i na slovu đ. |
| Mislilac | Nije palo — čisto je i `mislilac.app`/`.com` su slobodni. Izgubilo od Poteza na dužini i izgovoru: osam slova, tri sloga, grupa „sl", a značenje je napolju svejedno izgubljeno. Prva rezerva. |

### Metod, jer je ovde koštao najviše vremena

**Ime se prvo proveri, pa onda predloži.** Tri jezička modela su nezavisno
predložila Knight School, Caissa, Knightly i Outpost kao favorite — sva četiri
su zauzeta postojećim šahovskim proizvodima. Registar „šahovski pojam +
engleska reč" je iscrpen, najvećim delom talasom „AI chess coach" proizvoda iz
poslednje dve godine. Ime koje ti model predloži je po pravilu već uzeto, jer
isti model isto ime predlaže svima, a oni su krenuli ranije.

Provera ide redom: Play i App Store pretraga → postojeći proizvodi na webu →
[ZIS](https://www.zis.gov.rs) → EUIPO eSearch → domen.

I jedna zamka iz iste porodice kao sve u „Ono što grize": prva provera domena
preko `nslookup` je **za svaki domen javljala da je slobodan**, jer je obrazac
za pretragu promašivao format ispisa. Uhvaćeno samo zato što su u spisak
namerno ubačena dva domena za koja se pouzdano zna da postoje. **Svaka provera
mora da sadrži kontrolni slučaj za koji se unapred zna da mora da padne** —
inače merite ćutanje.

Odsustvo NS zapisa je jak nagoveštaj da je domen slobodan, ali nije dokaz;
potvrda je jedino kod registrara.

### Ostalo da se uradi

- [ ] EUIPO klase 9 i 41 za „Potez", i pitanje o figurativnom žigu — advokatu.
- [ ] ZIS provera.
- [ ] Prikazno ime u `chess_app` postaviti na „Potez" (samo labela).
- [ ] Play naslov `Potez`, ključne reči u kratkom opisu, ne u imenu.

## Posle preimenovanja paketa — sitnica

Windows verzija sada koristi `AppData\Roaming\rs.pejovic\chess_app` umesto
`AppData\Roaming\com.example\chess_app`. Preuzeti Stockfish i podešavanja su
ostali na staroj putanji. Prekopirati folder ili pustiti aplikaciju da ponovo
preuzme motor.

## Pošta na domenu — ✅ postavljeno 26.8.2026

Sanduče kod Namecheap Private Email (Launch, jedno sanduče, plaćeno godišnje,
automatska obnova uključena). Sanduče je `support`, a `privacy`, `no-reply`,
`info`, `podrska` i `privatnost` su **aliasi** na njemu — pet od deset. Aliasi,
ne zasebna sanduka: dodatna sanduka trebaju tek kad poštu čita drugi čovek.

Zašto sanduče a ne besplatno preusmeravanje, koje je do tada stajalo: preusmeravanje
rešava samo **primanje**. Slanje je ostajalo sa lične Gmail adrese, a poruka koja
traži saglasnost za snimanje glasa deteta, a stiže sa privatne adrese, je tačno
ono što bi oprezan roditelj trebalo da prijavi kao phishing.

Sva četiri zapisa su **provereni spolja**, ne po statusu u panelu:

| Zapis | Vrednost |
|---|---|
| MX | `mx1/mx2.privateemail.com` |
| SPF | `v=spf1 include:spf.privateemail.com ~all` |
| DKIM | selektor `privateemail._domainkey` (ne `default`) |
| DMARC | `p=none` sa `rua`, dodat ručno — Namecheap ga ne pravi sam |

DMARC je namerno `p=none`: prvo posmatranje, pa `quarantine`, pa `reject`.
Obrnut redosled je uobičajen način da se pošta tiho poobara. Razlog zbog kog
DMARC ovde nije kozmetika: bez njega neko može da pošalje lažni zahtev za
saglasnost roditelja sa ovog domena, što je phishing uperen u najosetljiviju
radnju u aplikaciji.

`MAIL_FROM` nosi ime proizvoda (roditelj mora da prepozna aplikaciju koju dete
koristi), a ljudski odgovori iz Thunderbird-a idu pod kućnim imenom, jer isto
sanduče opslužuje sva tri proizvoda.

**Zamka pri promeni:** SPF sada ovlašćuje samo Private Email da šalje sa ovog
domena. Dok `MAIL_FROM` pokazuje na Gmail, važi Gmail-ov SPF i sve radi; čim
`MAIL_FROM` pređe na naš domen a `SMTP_*` ostanu na Gmail-u, poruke kreću sa
servera koji SPF ne priznaje i tiho odlaze u spam. **`MAIL_FROM` i `SMTP_*` se
menjaju istim potezom.**

**Slanje provereno uživo 26.8.2026** (korisnik): obe poruke koje aplikacija
šalje — verifikacioni kod i zahtev roditelju — poslate sa radne stanice kroz
`services/mailService.js`, dakle kroz isti kod koji se izvršava u radu, a ne
kroz zasebnu probu sa strane.

Do te potvrde otišlo je nekoliko krugova, i uzrok je vredan pamćenja: SMTP je
odbijao tačnu lozinku sa `535`, dok su webmail i IMAP prolazili. Fajl je bio
besprekoran po svakoj proveri oblika — bez navodnika, belina, `CR`-a i BOM-a —
a vrednost je ipak bila pogrešna. Stara i nova lozinka su bile **iste dužine**
(15 znakova) i razlikovale se samo sadržajem, pa ih ni provera dužine ne bi
razdvojila — razlikovao ih je tek skraćeni `sha256` otisak vrednosti koju
`dotenv` stvarno učita. **Provera oblika ne dokazuje sadržaj, a provera dužine
ne dokazuje jednakost.** Ono što je razrešilo slučaj bilo je
poređenje dva puta koja koriste isti nalog: Thunderbird je slao preko istog
porta sa istim korisničkim imenom, čime je provajder bio oslobođen sumnje i
ostala je samo naša vrednost. Ispravna lozinka je zatim pročitana iz
Thunderbird-ovog spiska sačuvanih lozinki.

## Odlazni SMTP je blokiran na dropletu — prepreka pred prelazak

Nađeno 26.8.2026, pri prvoj pravoj probi slanja sa servera.

Skripta je stala bez greške i bez poruke — samo tišina do isteka veze. Mereno:

```
25   blokiran      ufw Default: allow (outgoing)
465  blokiran
587  blokiran
443  otvoren   ← kontrolni slučaj
```

`ufw` propušta odlazni saobraćaj, a kontrolni port prolazi, pa blokada nije
naša i nije opšta — **ciljana je na SMTP i dolazi od DigitalOcean-a**, koji ga
na novijim nalozima drži zatvorenim dok se ne zatraži otvaranje.

- [ ] **Otvoriti tiket kod DigitalOcean-a** za skidanje blokade odlaznog SMTP-a.

Ovo **mora biti rešeno pre nego što aplikacija pređe na droplet**. Bez odlazne
pošte nema ni verifikacionih kodova ni saglasnosti roditelja — a oboje su
preduslov za rad, ne pogodnost. Sajt time nije pogođen: `site-setup.sh` ne šalje
poštu, a lokalni backend šalje normalno, jer je sa radne stanice 465 otvoren.

Ako DigitalOcean odbije — što se novijim nalozima dešava — rezervni put je
provajder sa HTTP API-jem preko porta 443 umesto SMTP-a. Tada se menja i
`SMTP_PROVIDER`, a ta vrednost se upisuje u politiku privatnosti, pa promena
povlači i izmenu objavljenog pravnog teksta.

**Pouka za sledeći put, ista kao ceo ovaj dokument:** prvo merenje je pokazalo
samo „465 blokiran". Tek kontrolni port i provera `ufw`-a razdvojili su tuđu
blokadu od naše sopstvene greške. Bez njih bi tiket otišao na osnovu jednog
merenja koje meri tišinu.

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
- [ ] **`LICHESS_API_TOKEN` u `.env` na serveru** pre prebacivanja. Baza
      otvaranja od 24.8.2026. ide kroz backend; bez tokena ruta vraća 503 i svi
      dobijaju ChessDB umesto statistike iz partija — tiho, jer aplikacija na to
      i treba da pređe kad Lichess nije dostupan.
- [ ] **Veća baza pre punog Lichess seta.** 50k zagonetki je zanemarljivo, ali
      punih 6,1M sa GIN indeksom po temama neće udobno stati u 1 GB RAM-a.

Nije uzrok brige: Stockfish radi na klijentu, a glas nosi Agora — server ne
analizira pozicije niti prenosi zvuk uživo, pa je 1 vCPU sasvim dovoljan za
sesije. MP4 izvoz renderuje jedan frejm po sekundi časa i `await`-uje između
njih, pa ne blokira Socket.IO.
