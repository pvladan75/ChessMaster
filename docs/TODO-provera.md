# TODO — šta još nije provereno u aplikaciji

Sve navedeno je napisano, prolazi testove i `flutter analyze`, ali **nije viđeno
kako radi uživo**. Automatski testovi pokrivaju logiku; ne pokrivaju da li je
dugme na pravom mestu i da li tok ima smisla.

Poređano od najbržeg za proveru ka najsporijem.

---

## 0. Pristanak na odnos trener–učenik — novo 16.8.2026, nikad viđeno uživo

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
- Zahtev radi i u drugom smeru (`POST /students/trainers/request`), ali za to
  **još nema dugmeta u aplikaciji** — proverljivo samo pozivom rute.

> **Zatečeni podaci:** tri postojeće veze su prešle kao `accepted`, i među njima
> je i **uzajaman par** koji je i bio bag (dvoje koji su dodali jedan drugog).
> Ispravka sprečava nove takve, ali taj par treba ručno raskinuti iz aplikacije.

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
