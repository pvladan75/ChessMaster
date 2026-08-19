# Skener pozicija iz knjiga

Izvlači šahovske pozicije iz PDF-a složenog vektorskim šahovskim fontom i
**proverava svaku poziciju potezom iz same knjige**. Node, bez Pythona i bez
ičega novog na serveru.

Zavisnosti (`pdfjs-dist`, `chess.js`) stoje u `chess_backend/package.json`. Odluke i brojevi su u
[docs/STANJE-RADA.md](../../../docs/STANJE-RADA.md), odeljak „Skener pozicija iz
knjiga".

Biblioteka je `index.mjs` (`scanDocument`) i koristi je
[routes/scans.js](../../routes/scans.js). Ostalo su alati za razvoj:

```bash
node scan.mjs knjiga.pdf --pages 16-965 --solutions 972-1184 --out pozicije.json
node --test services/positionScanner        # iz chess_backend/
```

`--baseline stari.json` uporedi izlaz sa ranijim (koristi `diagram_id` i `fen`).

## Kako radi

| | |
|---|---|
| `pdf.mjs` | pdfjs-dist → pozicionirani spanovi, y odozgo nadole |
| `fonts.mjs` | mape glif → figura, biraju se **po azbuci** a ne po imenu fonta |
| `diagrams.mjs` | osam redova u istoj koloni = dijagram |
| `solutions.mjs` | odeljak sa rešenjima → ko je na potezu i koji je potez |
| `verify.mjs` | sastavljanje FEN-a i provera kroz `chess.js` |

## Tri stvari koje su koštale vremena

**Dijagram se ne traži po broju.** Prva testna knjiga numeriše svaki dijagram,
druga nijedan; parser koji se oslanja na broj nađe 0 od 211 dijagrama u drugoj i
prijavi uspeh. Osam redova glifova u koloni je dijagram, broj je neobavezan
dodatak.

**Broj dijagrama nije jedini broj pored table.** Koordinate redova (8..1) stoje u
levoj margini i takođe su cifre. Uzimanje najbližeg daje svakom dijagramu u
knjizi broj „8". Broj je iznad table i nikad levo od njene ivice.

**Notacija je dvosmislena bez razmaka.** `1.Nc6 b5` stigne kao `Nc6b5`, što se
piše isto kao razjašnjeni potez `Nc6b5`. Ništa u tekstu to ne razrešava — zato
se nude oba, kraći prvi, a `chess.js` odbaci pogrešan.

## Šta namerno puca glasno

Nepoznat glif je greška, nikad prazno polje: tabla koja tiho izgubi figuru i
dalje daje ispravan FEN, a greška se vidi tek kad dete ne može da reši zadatak.
Isto važi za font — ako nijedna mapa ne objašnjava dijagrame, program ispiše
nepoznate glifove i izađe sa greškom umesto da izvuče nešto.

Prava na rokadu i polje za en passant se **ne pogađaju**. Dijagram ih ne
prikazuje. Postavljaju se samo kad ih potez iz rešenja dokazuje (`O-O` dokazuje
pravo, `axb6` na prazno polje dokazuje en passant), i to se upiše u `repairs`.

## Izmereno

Prva testna knjiga, 950 strana dijagrama:

| | |
|---|---|
| dijagrama nađeno | 5.320 |
| poklapanje sa ranijim Python izlazom | 5.220 istih, **0 različitih** |
| potez iz knjige legalan (prave zagonetke, id < 4463) | **4.436 / 4.437 = 99,98%** |
| popravki rokade i en passant-a | 16 |

Iznad dijagrama 4463 tačnost pada na 29% — tamo „rešenje" nije rešenje nego
partija od prvog poteza. Pad je **nalaz, ne kvar**: granica odeljka se vidi po
tome što potez iz knjige prestaje da bude legalan u dijagramu.

## Nova knjiga — šta treba

Mapa u `fonts.mjs`. Font ne pomaže: `TTE2BEAF20t00` iz druge testne knjige ima
`post` tabelu verzije 3.0, dakle bez imena glifova. Mapa se izvodi iz same
knjige, u dva koraka:

```bash
node derive.mjs knjiga.pdf                        # statistika glifova
node identify.mjs knjiga.pdf --tests 78-79 --answers 81
```

`derive.mjs` iz statistike sam izvlači prazna polja, **kraljeve** (jedini par
koji stoji tačno jednom na svakom dijagramu) i **pešake** (nikad na 1. i 8.
redu). To je oko pola mape i ne traži nikakvo pogađanje.

`identify.mjs` rešava ostatak iz **geometrije poteza**: `1.Ng5` znači da beli
skakač stoji skakačev skok od g5, a koja su polja zauzeta zna se i bez mape jer
prazno polje ima svoj glif. Vraća se unazad od odredišta i glif se sam
predstavi; kad je polazišta više, odgovor je skup koji se preseca sa drugim
pozicijama.

**Šta ne raditi:** prvo je pisana pretraga koja nabraja sve moguće mape i
proverava ih. 2.654.208 kandidata, sedam minuta, i kao rezultat „nijedna ne
prolazi" — što ne kaže koja pretpostavka je pukla. Direktna metoda daje isto to
za sekundu, i uz to imenuje glif.

### Šta je za `TacticsCourse.pdf` do sada izvedeno

Kraljevi `I`,`K` (beli) i `i`,`k` (crni); pešaci `P` (beli, svetlo) i `p`,`0`
(crni). Iz jednog dijagrama pročitano i `R`,`$` = beli topovi, `4` = crni top,
`G` = beli lovac. **Mapa nije završena** i knjiga još nije prošla kroz `scan.mjs`.

Usput je nađena i protivrečnost: rešenje #2 je odštampano kao `1...Bxh6`, dakle
crni na potezu, ali u toj poziciji crni lovac sa g7 uzimao bi sopstvenog pešaka
na h6 — potez pripada belom lovcu sa c1. Alat to prijavljuje kao `PROTIVREČNO`
umesto da izabere jednu stranu. To je isti raskorak koji ide treneru na potvrdu.
