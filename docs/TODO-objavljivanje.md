# TODO — objavljivanje na Google Play

Sve u kodu je spremno. Ostalo je ono što traži naloge, novac i advokata.
Redosled je bitan: svaki korak zavisi od prethodnog.

---

## 1. Google Play Console nalog

- [ ] Otvoriti **developer nalog kao fizičko lice** — jednokratno $25.
- [ ] Srbija je podržana i za registraciju i za **merchant** (prodaju), sa USD kao
      podrazumevanom valutom. Provereno na Google-ovoj tabeli podržanih lokacija.
- [ ] Uneti podatke za isplatu (bankovni račun, deviznii priliv).

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
      pre nego što pusti aplikaciju — bez toga se ne može objaviti.
- [ ] Uneti taj URL u Play Console → App content → Privacy policy.
- [ ] Popuniti **Data safety** formu u Play Console-u prema onome što piše u
      politici (email, glas, snimci, rezultati vežbi).

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
