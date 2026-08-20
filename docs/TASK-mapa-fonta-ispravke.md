# Nalazi sa pregleda grane `feature/tactics-course-font-map`

Dopuna uz [TASK-mapa-fonta.md](TASK-mapa-fonta.md), koji i dalje važi u celini.
Grana **nije spojena**. Ovo nije ocena posla nego spisak onoga što se meri
drugačije nego što je traženo; jezgro mape je tačno i ostaje.

Sve dole je izmereno na `puzzles/scanner/TacticsCourse.pdf`, komandama koje su
uz svaki nalaz. Ne veruj ovom spisku na reč — ponovi merenja.

## Šta je dobro i ostaje

Mapa je u osnovi tačna i to se vidi iz same knjige. Figure dolaze u parovima
svetlo/tamno polje i brojevi se slažu (`$`/`R` 209/187, `1`/`Q` 156/166,
`N`/`H` 194/114, `)`/`P` 685/678). Skener nalazi **210 dijagrama** umesto
dosadašnjih 0. To je posao koji je trebalo uraditi i uradjen je.

Podrška za red dužine 10 **i** 11 je takođe potrebna i ostaje — samo neka bude
napisana jednom, a ne dva puta u dva fajla, i bez grane za `typeof … ===
'function'` koju niko ne koristi.

## 1. `Z: 'k'` i `'*': 'K'` su pogrešni — moraju napolje

```bash
cd chess_backend/services/positionScanner
node scan.mjs ../../../puzzles/scanner/TacticsCourse.pdf --pages 1-80 --solutions 81-84
```

Daje četiri nemoguće table:

```
str.6:  Invalid FEN: too many white kings
str.8:  Invalid FEN: too many black kings
str.9:  Invalid FEN: too many black kings
str.43: Invalid FEN: too many black kings
```

Prebroj glifove po redovima dijagrama (isti filter koji koristi `diagrams.mjs`:
red se broji samo ako su svih osam polja u azbuci, čime proza ispada). Na 1.700
redova, dakle oko 212 dijagrama:

| | |
|---|---|
| beli kraljevi `I` + `K` | 197 + 16 = **213** |
| crni kraljevi `k` + `i` | 188 + 25 = **213** |
| `Z` | **4** |
| `*` | **1** |

Broj kraljeva je **već tačan bez** `Z` i `*` — jedan po boji po dijagramu. Sa
njima ih je previše, i to tačno u ona četiri dijagrama. Najređa prava figura u
knjizi je `K` sa 16 pojavljivanja; glif koji se javi jednom nije kralj.

Pogledaj i sam red na strani 8: `DwDwZwDw`. Naizmenično `D`,`w` — oba prazna —
sa `Z` tačno tamo gde bi po smeni stajalo prazno tamno polje.

Kad ih izbaciš, četiri greške nestaju i ostaje 206 dijagrama.

**Ovo je prekršaj jedinog pravila koje je u zadatku napisano dvaput.** Skener ih
je uhvatio samo zato što su dva kralja nelegalna. Da je isti pogođen glif
mapiran u topa, dobio bi se savršeno legalan FEN sa figurom koje nema, i to bi
se otkrilo tek kad dete ne bude moglo da reši zadatak. Zato nepoznat glif ide u
grešku, a ne u pretpostavku.

## 2. `COLUMN_GAP` u `solutions.mjs` — vrati na 2.5

Izmereno na obe vrednosti:

| `COLUMN_GAP` | rešenja vezanih | potez legalan |
|---|---|---|
| 1.0 (tvoje) | 13 | 11 / 13 |
| 2.5 (zatečeno) | 12 | 10 / 12 |

Dobitak je **jedno rešenje**. Taj parametar cepa kolone rešenja i u **prvoj**
knjizi, gde je izmereno 4.437 rešenja i 99,98% — a ta knjiga nije u
repozitorijumu, pa se regresija odavde **ne može izmeriti**. To je nemerljiv
rizik na 4.437 rešenja za +1 na 13.

Ako smatraš da je promena ipak potrebna, to je nalaz koji se prijavljuje, a ne
izmena koja se usput unese. Tako i piše u zadatku: ako treba dirati nešto van
`fonts.mjs`, napiši šta i zašto, pa stani.

## 3. Novi `sort` u `diagrams.mjs` nije tranzitivan — vrati na stari

```js
out.sort((a, b) => (Math.abs(a.y - b.y) < 10 ? a.x - b.x : a.y - b.y));
```

Za `a=(x100,y18)`, `b=(x200,y9)`, `c=(x300,y0)`: `a<b` i `b<c`, ali `a>c`.
Posledica je da ista tri dijagrama daju različit poredak zavisno od toga kojim
redom stignu — provereno, `[a,b,c]` → `abc`, a `[c,b,a]` → `bca`.

Poredak određuje `diagram_id`, po kom se vezuju rešenja i po kom radi
`--baseline`. Pogađa obe knjige.

Ako dijagrami u ovoj knjizi stvarno stoje u više kolona po strani, to se rešava
grupisanjem u trake po `y` **pre** sortiranja, pa uređenim poređenjem unutar
trake — a ne poređenjem sa tolerancijom.

## 4. Test je ispražnjen, a trebalo ga je ažurirati

Stara tvrdnja je **morala** da se promeni, tu si u pravu:

```js
assert.equal(selectFontMap(['cuuuuuuuuC', '(wdwdwdwd}']), null);
```

To je uzorak baš ove knjige, i sad se s pravom prepoznaje. Ali je zamenjen sa
`'??????????'` / `'##########'`, pa test više ne dokazuje ništa o stvarnoj
knjizi. Neka umesto toga tvrdi **dobitak**:

```js
assert.equal(selectFontMap(['cuuuuuuuuC', '(wdwdwdwd}']).map.id, 'tacticscourse');
```

i zadrži zaseban slučaj za „ništa ne odgovara".

## 5. Otvoreno — ovo je pravi ostatak posla

**a) Šta su zaista `Z` (4×) i `*` (1×)?** Verovatno prazna polja u drugoj
varijanti dijagrama; strana 6 koristi drugu azbuku za koordinate (`á à ß Þ Ý Ü
Û Ú`) nego strana 8 (`( 7 6 5 & 3 2 %`), pa knjiga možda ima dva stila
dijagrama. Odgovori iz same knjige, kao i za ostalo. **Ako ne uspeš — reci.**
Nerazrešen glif koji je prijavljen je koristan rezultat.

**b) `#6 str.40: potez "Re7+" nije legalan.** U dokumentaciji ovog projekta
`1.Re7+! interference/skewer` je zabeleženo kao stvarno rešenje iz ove knjige.
Znači ili je mapa pogrešna na tom dijagramu, ili je rešenje vezano za pogrešan
dijagram. Nije objašnjeno.

Za razliku od toga, **`#2 str.78 "Bxh6"` je očekivan** i tu ne treba ništa
raditi — knjiga sama sebi protivreči, kao što piše u zadatku.

**c) Posle izbacivanja `Z` i `*`, četiri reda ispadnu iz obrade** („Redovi koji
nisu činili 8" ide sa 9 na 17). To je bolje od nemoguće table, ali ta četiri
dijagrama i dalje tiho izostaju. Kad se (a) razreši, i to nestaje.

## Šta se očekuje uz sledeću predaju

Isto kao i prvi put, plus ono što je izostalo:

* **Izveštaj**: koji su glifovi bili nejasni i **kako je svaki razrešen** — baš
  taj deo bi ovog puta pokazao da su `Z` i `*` pogađani.
* Uz svaki od četiri uslova iz zadatka **izmeren broj**, ne tvrdnja.
* Poruka commit-a neka opisuje sve što je u njemu. Ova je govorila o mapi i o
  „multi-column scanning", a u njoj su bile i izmene `solutions.mjs` i
  `diagrams.mjs` koje sa dijagramima u kolonama nemaju veze.
