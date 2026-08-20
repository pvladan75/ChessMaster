# Pitanja koja čekaju odluku

Ovde stoje pitanja **dizajna**, ne poslovi. Razlika je namerna: `TODO-provera.md`
vodi šta je napisano a nije viđeno kako radi, `STANJE-RADA.md` vodi odluke koje
su već donete i zašto. Ovde su ona koja tek treba doneti, sa procenom šta svaka
mogućnost povlači — da se sledeći put ne počinje od nule.

Zapisano 20.8.2026, iz zapažanja pri prvom pravom korišćenju lanca knjiga →
učenik.

---

## Prvo: ono što se gubilo svakog dana — ✅ zatvoreno 20.8.2026

Pitanja 4 i 5 traže podatak koji se **do 20.8.2026. bacao**. Kad učenik odigra
potez, `judgeAttempt` vrati i `playedSan` — šta je dete stvarno odigralo — a
upisivalo se samo `solved: true/false`.

To se ne može rekonstruisati kasnije, pa je kolona dodata pre ijednog ekrana:
`assignment_items.played_san`. Vidi „Odigran potez se više ne baca" u
[STANJE-RADA.md](STANJE-RADA.md).

**Ekrani i dalje ne postoje** — pitanja 4 i 5 su otvorena kao i pre. Razlika je
što od danas imaju šta da prikažu, umesto da počinju od praznih kolona.

---

## 1. Da li učenik rešava domaći redom koji sam bira?

**Danas:** ne. Ekran napravi red od nerešenih pozicija u redosledu koji je trener
zadao i vodi kroz njih jednu po jednu. Nema pregleda svih, nema preskakanja,
nema vraćanja.

**Šta govori za slobodan redosled.** Dete koje zapne na trećoj poziciji ne može
dalje — a domaći koji se ne može završiti je domaći koji se ne radi. Uz to,
„prvo da vidim sve pa da počnem od lakših" je stvarna tehnika učenja, ne
izbegavanje.

**Šta bi govorilo protiv** obično je bojazan od varanja — ali ovde ne stoji:
**rešenje se ne šalje učeniku unapred**, server ga otkriva tek posle odgovora.
Pregled svih pozicija ne odaje ništa. Time glavni prigovor otpada.

**Šta ipak treba čuvati.** Trenerov redosled ume da bude pedagoški (lakše ka
težem, ili napredovanje kroz motiv). To se ne gubi ako ostane **podrazumevani**
redosled.

**Preporuka:** slobodan redosled uz mrežu za pregled svih pozicija sa stanjem
(urađeno / netačno / nedirnuto), a trenerov redosled kao početni. Ako se ikad
pokaže potreba za prisilnim redosledom, to je zastavica na zadatku, ne pravilo
za sve.

---

## 2. Objediniti skenirane pozicije i pozicije iz Studija — ✅ urađeno 20.8.2026

Urađeno onako kako je ovde predloženo: **jedan pogled nad tri izvora, ne jedna
tabela** (`GET /library/positions` sa poljem `kind`), i jedan birač koji koristi
i editor lekcije i ekran „Moje pozicije". Vidi „Jedna biblioteka pozicija, tri
police" u [STANJE-RADA.md](STANJE-RADA.md). Ostatak odeljka stoji kao zapis
razloga.

**Danas su dve police koje se ne vide jedna drugoj.** Skenirano živi u
`custom_puzzles` i vidi se samo u „Mojim pozicijama". Studio čuva u
`saved_analyses` i `saved_lessons`, a editor lekcije bira **samo odatle**.

Posledica koja se lako previdi: **skenirana pozicija se danas uopšte ne može
staviti u lekciju.** To nije nedostatak udobnosti nego rupa u lancu.

**Ali objediniti ne znači spojiti tabele.** Oblici su stvarno različiti:
skenirana pozicija je jedna tabla, jedan potez i zadatak; sačuvana analiza je
stablo varijanti sa PGN-om. Spajanje bi nateralo svakog potrošača da grana po
vrsti — što je isti razlog zbog kog su `puzzles` i `lichess_puzzles` namerno
ostale odvojene (vidi komentar u `db.js`).

**Preporuka:** jedan **pogled** nad dva izvora, ne jedna tabela. Zajednički
endpoint koji vraća i jedne i druge sa poljem `kind`, i jedan birač koji se
koristi i u editoru lekcije i pri zadavanju domaćeg. Trener dobija „moje
pozicije" kao jedno mesto, a podaci ostaju u obliku koji im odgovara.

**Ovo bih uradio prvo od svih pet** — otključava i pitanje 3, i zatvara rupu
koja već postoji.

---

## 3. „Dodaj u lekciju" sa same pozicije — ✅ urađeno 20.8.2026

Palo je zajedno sa pitanjem 2, kako je i predviđeno. Radnja stoji u traci za
izbor na ekranu „Moje pozicije" a ne na samoj kartici — kartica je već puna, a
izbor više pozicija odjednom je već postojao. Zadatak i rešenje prelaze sa
pozicije na korak; `solution_san` se čuva iako se ne koristi, tačno iz razloga
koji je ovde naslućen.

Ovo je pitanje 2 sa druge strane i pada zajedno s njim. Kad postoji jedna
biblioteka, radnja pripada kartici pozicije, a editor lekcije treba da ume da
povuče iz iste biblioteke.

**Jedna sitnica koja se lako izgubi:** korak lekcije nosi `title`, `fen`, `pgn` i
sada `instruction`; skenirana pozicija nosi `fen`, `solution_san` i
`instruction`. Pri prenošenju **zadatak mora da pređe sa pozicije na korak** —
inače dete opet dobija tablu bez pitanja, što smo tek popravili.

Otvoreno i: šta sa `solution_san` kad pozicija uđe u lekciju? Lekcija se čita,
ne rešava. Verovatno se čuva, pa da isti korak može kasnije da postane zadatak.

---

## 4. Pregled urađenog domaćeg i povratna informacija

**Danas:** `assignment_items` pamti `solved`, `ms_taken`, `attempted_at`. Trener
vidi brojeve („2/2 urađeno, tačnost 100%"), ali **nijedna strana ne može da
pogleda šta se desilo po poziciji** — koju je tablu dete videlo i šta je
odigralo.

Odigran potez se od 20.8.2026. čuva (odeljak na vrhu), pa ekran ima šta da
prikaže i jednostavan je: pozicija, tvoj potez, rešenje, i da li je priznato —
uključujući onaj slučaj „drugi mat, ali mat". Za zadatke odgovorene ranije polje
je prazno i to se mora videti kao „ne zna se", ne kao „ništa nije odigrano".

**Povratna informacija** je zaseban sloj: trenerov komentar po zadatku i po
poziciji. Vidi pitanje 5 — bolje ih rešiti zajedno, jer je oblik isti.

---

## 5. Da li učenik može da komentariše zadatak i pojedinačnu poziciju

Prirodan par sa 4. Dete koje napiše „ovu nisam razumeo" daje treneru tačno ono
što mu treba, a što se iz brojeva ne vidi.

**Predlog oblika:** ne četiri kolone (trenerov komentar na zadatak, učenikov na
zadatak, trenerov na poziciju, učenikov na poziciju) nego **jedna tabela**:

```
assignment_notes(id, assignment_id, item_id NULL, author_id, body, created_at)
```

`item_id` prazan znači komentar na ceo zadatak. Autor se čita iz naloga, pa se
uloga ne upisuje dvaput. Time se 4 i 5 rešavaju istim potezom.

**Pravna napomena:** ovo je tekst koji piše dete i čita ga njegov trener — dakle
unutar odnosa koji već postoji i koji je pristankom zasnovan. Ne otvara novu
površinu, ali kad se bude pisala politika privatnosti, komentari su sadržaj koji
se čuva i treba ga pomenuti.

---

## Ranije zabeležena, i dalje otvorena

- **Pristanak roditelja.** `parent_consent_*` kolone postoje i prazne su; nijedan
  tok ih ne upisuje, a tekst čeka pravnika. Model nadzora je dogovoren u
  `STANJE-RADA.md` („Dogovoren model uloga i nadzora"), nije napisan. Ovo je
  jedino otvoreno pitanje koje blokira objavljivanje.
- **Panel „Pozicioni faktori"** — filtrirati kao automatske komentare ili
  ostaviti nefiltrirano.
- **Mapa fonta za drugu knjigu** (`TacticsCourse.pdf`). Alat za izvođenje
  postoji (`derive.mjs`, `identify.mjs`), mapa nije završena.
- **Lekcija kao izlaz skenera**, umesto zagonetki. Kurs sa prozom i ilustracijama
  nije katalog i ne treba da postane 211 „zagonetki" — vidi „Iz ovoga sledi da
  skener ima dva izlaza" u `STANJE-RADA.md`.
- **Skeniranje slika** (faza 2) — nikad probano; tačnost na skeniranoj strani je
  nepoznata i traži merenje na pet strana pre nego što se u to uloži.
