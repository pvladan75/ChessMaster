# Zadatak: mapa glifova za `TacticsCourse.pdf`

Zaokružen posao za spoljnog agenta. Ovaj fajl je jedini kontekst koji dobijaš —
nemoj se oslanjati ni na kakav razgovor pre njega. Kad posao bude spojen, fajl se
briše.

## Šta se traži

Dopuniti mapu glif → figura za drugu testnu knjigu i propustiti knjigu kroz
skener. Konkretno:

1. Novi unos u `FONT_MAPS` u
   `chess_backend/services/positionScanner/fonts.mjs`, po uzoru na postojeći
   `SKAK_NEW`.
2. Da `node scan.mjs TacticsCourse.pdf --pages <opseg>` nađe dijagrame te knjige
   i sastavi FEN-ove, umesto sadašnjih **0 od 211**.

Ništa drugo. Ako se ispostavi da je potrebna izmena van `fonts.mjs`, **napiši u
izveštaju koja i zašto, pa stani** — ne širi zahvat sam.

## Šta ti treba pre početka

* **Node >= 22.15.** Ispod toga backend ne radi (`zlib.zstd*`).
* **`TacticsCourse.pdf`** — Exeter Chess Club, Dave Regis, 84 strane, 211
  dijagrama, besplatno objavljen. **Nije u repozitorijumu.** Ako ga nemaš, traži
  ga umesto da radiš na drugoj knjizi.
* Zavisnosti su već tu: `cd chess_backend && npm install`.

## Gde je šta

Sve je u `chess_backend/services/positionScanner/`. Pročitaj `README.md` u tom
folderu pre nego što bilo šta pipneš — u njemu je i spisak stvari koje su već
koštale vremena.

| | |
|---|---|
| `fonts.mjs` | **jedini fajl koji treba da menjaš** |
| `derive.mjs` | statistika glifova → prazna polja, kraljevi, pešaci |
| `identify.mjs` | ostatak mape iz geometrije poteza u rešenjima |
| `scan.mjs` | pun prolaz kroz knjigu |
| `positionScanner.test.mjs` | testovi, moraju da ostanu zeleni |

## Metod — ovim redom

```bash
cd chess_backend/services/positionScanner
node derive.mjs TacticsCourse.pdf
node identify.mjs TacticsCourse.pdf --tests 78-79 --answers 81
```

`derive.mjs` sam izvlači prazna polja, kraljeve (jedini par koji stoji tačno
jednom na svakom dijagramu) i pešake (nikad na 1. i 8. redu) — otprilike pola
mape, bez ijedne pretpostavke. `identify.mjs` ostatak rešava iz geometrije:
`1.Ng5` znači da beli skakač stoji skakačev skok od g5, a koja su polja zauzeta
zna se i bez mape, jer prazno polje ima svoj glif.

**Ono što je već izvedeno**, da ne ponavljaš posao: kraljevi `I`,`K` (beli) i
`i`,`k` (crni); pešaci `P` (beli na svetlom) i `p`,`0` (crni); `R`,`$` beli
topovi; `4` crni top; `G` beli lovac.

**Šta ne raditi:** ne piši pretragu koja nabraja moguće mape i proverava ih. Već
je pisana — 2.654.208 kandidata, sedam minuta, i rezultat „nijedna ne prolazi",
koji ne kaže koja pretpostavka je pukla.

## Čime se meri da je gotovo

Ovo su uslovi, ne želje. Nabroj ih u izveštaju sa izmerenim brojem uz svaki.

1. `cd chess_backend && node --test services/positionScanner` — **zeleno**.
2. `scan.mjs` na knjizi nalazi **oko 211 dijagrama**. Ako nađe 0 ili 5, mapa nije
   gotova bez obzira na to što program ne puca.
3. **Nijedan nepoznat glif** na celoj knjizi.
4. Od **12 rešenja** sa kraja knjige (završni test), potez iz rešenja mora biti
   **legalan u svom dijagramu**. Izuzetak je poznat i očekivan: rešenje **#2** je
   protivrečno u samoj knjizi (odštampano `1...Bxh6`, ali potez pripada belom
   lovcu sa c1). Alat to prijavljuje kao `PROTIVREČNO` — **tako i treba da
   ostane**. Ako to „nestane", nešto si pokvario.

Za poređenje, prva knjiga daje 99,98% (4.436 od 4.437). Ova ima premalo rešenja
za takav procenat, zato su gornja četiri uslova merilo.

## Tvrde granice

* **Nepoznat glif je greška, nikad prazno polje.** Ovo je najvažnije pravilo u
  celom zadatku. Tabla koja tiho izgubi figuru i dalje daje ispravan FEN, pa se
  greška vidi tek kad dete ne može da reši zadatak. Ako te nešto tera da mapiraš
  neprepoznat glif u prazno da bi „prošlo", stani i prijavi.
* `X` u dijagramima ove knjige **nije figura** nego oznaka napadnutog polja —
  mapira se u prazno, i to namerno i izričito.
* Rokada i en passant se **ne pogađaju**. Dijagram ih ne prikazuje.
* **Ne diraj**: `chess_app/`, `deploy/`, `chess_backend/uploads/`, `docs/`.
  Dokumentaciju pišemo mi, posle pregleda.
* Ne menjaj postojeći `SKAK_NEW` unos. Prva knjiga na njemu daje 99,98% i taj
  broj mora da ostane.
* Komentari u kodu i poruke commit-a su na **engleskom**; ovaj fajl je na
  srpskom jer ga čita naručilac.

## Kako se predaje

* Radi **na svojoj grani**, ne na `master`-u.
* Ostavi **diff**, ne izveštaj o uspehu. „Gotovo, testovi prolaze" nije predaja —
  ova baza koda ima dugu istoriju koraka koji tiho preskoče i prijave uspeh, i
  svaka takva greška je nađena tek gledanjem šta se stvarno desilo.
* U izveštaj napiši: koliko dijagrama je nađeno, koliko glifova je mapa dobila,
  koji su bili nejasni i kako si ih razrešio, i rezultat za svaka od 12 rešenja.
* Ako neki glif ostane nerazrešen — **reci to**. Nerazrešen glif koji je prijavljen
  je koristan rezultat; nerazrešen glif koji je tiho mapiran u prazno je šteta
  koja se otkriva mesecima kasnije.
