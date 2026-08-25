# Pitanja koja čekaju odluku

Ovde stoje pitanja **dizajna**, ne poslovi. Razlika je namerna: `TODO-provera.md`
vodi šta je napisano a nije viđeno kako radi, `STANJE-RADA.md` vodi odluke koje
su već donete i zašto. Ovde su ona koja tek treba doneti, sa procenom šta svaka
mogućnost povlači — da se sledeći put ne počinje od nule.

Zapisano 20.8.2026, iz zapažanja pri prvom pravom korišćenju lanca knjiga →
učenik. **Sva su rešena istog dana**; odeljci su zadržani kao zapis razloga, jer
je obrazloženje ono što se ne može rekonstruisati iz koda.

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

## 1. Da li učenik rešava domaći redom koji sam bira? — ✅ urađeno 20.8.2026

Da, uz mrežu svih pozicija sa tri stanja i trenerov redosled kao podrazumevani —
kako je ovde i predloženo. Prisilan redosled nije napravljen: ako se ikad pokaže
potreba, to je zastavica na zadatku, ne pravilo za sve. Vidi „Domaći se više ne
rešava u koloni" u [STANJE-RADA.md](STANJE-RADA.md).

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

## 4. Pregled urađenog domaćeg i povratna informacija — ✅ urađeno 20.8.2026

Urađeno zajedno sa pitanjem 5: `GET /assignments/:id/review` i isti ekran za obe
strane. Pravilo o rešenju je ispalo oštrije nego što je ovde naslućeno — učenik
ga vidi tek pošto odgovori, trener uvek, a „sakriveno" i „ne postoji" su dva
različita stanja. Vidi „Pregled urađenog domaćeg i komentari" u
[STANJE-RADA.md](STANJE-RADA.md).

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

## 5. Da li učenik može da komentariše zadatak i poziciju — ✅ urađeno 20.8.2026

Može, i tabela je tačno ona predložena niže. Dodato je samo brisanje sopstvene
poruke — dete koje se predomisli treba da može da je povuče, a tuđu ne.

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

## Kako roditelj potvrđuje — ✅ odlučeno i urađeno 25.8.2026

**Odlučeno: mogućnost 1 — link u mejlu, stranica na backendu.** Napisano istog
dana; vidi „Roditeljska saglasnost: tok je napisan" u
[STANJE-RADA.md](STANJE-RADA.md). Odeljak ostaje kao zapis šta je bilo u igri.

Tekst saglasnosti je potvrđen (advokat, 25.8.2026, **za Srbiju**), kolone
postoje i prazne su, age gate ima backend (`GET /me/standing`, `POST /me/age`).
Ostaje jedno pitanje, i ono odlučuje ceo podsistem: **čime roditelj potvrđuje.**

1. **Link u mejlu → stranica koju servira backend.** Jedino što ostavlja pravi
   zapis: vreme, IP, verzija teksta — sve tri kolone koje već postoje. Traži
   malu HTML stranicu i javan URL. `api.chesstrainers.app` postoji, ali je
   servis namerno zaustavljen dok aplikacija gleda u lokalni backend, pa se
   uživo proverava tek posle prebacivanja.
2. **Kod iz mejla se unosi u aplikaciji.** Bez web stranice, radi i lokalno.
   Slabije: nigde se ne vidi da je roditelj pročitao tekst, pa je zapis tanji.
3. **Trener potvrđuje da ima papir.** Najbliže sadašnjoj praksi iz
   `saglasnost-roditelja.md`, ali zapis je trenerova reč.

**Uz to je predložen model nivoa (25.8.2026), i mehanizam za njega je već
napisan** — vidi „Glas ima nivo, i nivo je u tokenu" u `STANJE-RADA.md`. Dete
sluša i odgovara dugmadima, mikrofon dobija kasnije. Ostaje da se odluči **šta
otključava nivo 2**: broj održanih časova, odobrenje trenera (postoji), ili
izričita potvrda roditelja.

**Predloženo je i plaćanje kao potvrda roditelja** (COPPA to poznaje kao
„credit card / monetary transaction"). Ograde, redom po težini:

- COPPA je SAD i ispod 13; ovde je Srbija i GDPR čl. 8, gde nema liste
  odobrenih metoda nego „razumni napori uz raspoloživu tehnologiju".
- Čl. 7(4): ako je kupovina jedini put do saglasnosti, saglasnost nije slobodno
  data. Izlaz: **plaćanje kao potkrepljenje uz besplatan, izričit čin
  saglasnosti**, a `order_id` se čuva kao dokaz da je odrasla osoba bila
  uključena.
- Play Families: bezbednosna kontrola iza plaćanja loše izgleda na pregledu, bez
  obzira na pravnu odbranu.
- „Maloletnik ne može da ima karticu" nije čvrsto — debitne i prepaid kartice se
  izdaju maloletnicima, a kupovinu može obaviti i dete na tuđem uređaju sa
  sačuvanim načinom plaćanja. Transakcija dokazuje da je korišćen instrument
  odrasle osobe, ne da je roditelj pročitao tekst.
- Sitnica koja kasnije vodi u pogrešan obim: glas **nije** automatski
  „biometrijski podatak" po GDPR-u — postaje to tek kad se obrađuje radi
  jedinstvene identifikacije (čl. 4(14)). Jeste lični podatak deteta, i
  zaključak („ne prikupljaj ga ako ti ne treba") stoji.

Ovo nije pravni savet.

---

## Šta sa vezama koje već postoje kad godina stigne — ✅ odlučeno 25.8.2026

**Odlučeno: prijaviti, ne menjati.** `POST /me/age` javi svakom treneru kad
učenik upiše godinu maloletnika, a status veze i `voice_level` ostaju
nepromenjeni. Napisano istog dana.

Otvorio ga je age gate (25.8.2026): dok nijedan nalog nije imao `birth_year`,
pitanje nije postojalo. Sad postoji, i tiče se **postojećih redova**, ne novih.

Godina se čita na dva mesta, i oba su trenuci: `mayRelate` pri slanju i pri
prihvatanju zahteva, `startingVoiceLevel` pri upisu nove veze. Nijedno ne gleda
unazad. Iz toga slede dva zatečena stanja:

1. **Dete koje već ima prihvaćene veze sa `voice_level = 'talk'`**, pa tek sad
   kaže da ima jedanaest godina. Glas mu ostaje objavljen — i u snimku.
2. **Veza u kojoj je „trener" maloletan**, sklopljena dok se za godine nije ni
   pitalo. Pravilo je odbija, ali samo unapred.

Tri mogućnosti, sa cenom svake:

- **Ne dirati zatečeno.** Nijedan trener se ne iznenadi usred kursa. Rupa koju
  je gate baš otkrio ostaje otvorena tačno kod onih naloga kod kojih je najstarija.
- **Prevesti pri upisu godine.** `POST /me/age` bi, kad je odgovor maloletnik,
  spustio postojeće veze na `listen` i suspendovao one u kojima je maloletnik
  trener. Zatvara rupu odmah; cena je da deca zaćute usred časa bez reči
  treneru, i da mehanizam koji ćutke menja tuđa prava radi na osnovu broja koji
  je dete samo otkucalo.
- **Prijaviti, ne menjati.** Treneru stigne obaveštenje („učenik je upisao
  godinu koja ga čini maloletnim; mikrofon je sada vaša odluka"), a stanje ostaje
  dok neko ne odluči. Skuplje za jedan ekran, ali ne menja tuđi čas bez ijedne
  reči i ne veruje broju više nego što treba.

Isti izbor stoji i za suprotan smer: nalog koji ispravi 2017 u 1997.

---

## Ko sme da bude u sobi — pretplata kao **nužan** uslov — 26.8.2026

Otvoreno pri pitanju šta biva kad u sobu sa detetom uđe gost ili drugi trener.

**Danas sobu ne čuva ništa što se plaća** — ali ne zato što model ne postoji,
nego zato što nije priključen. To je nalaz od 26.8.2026 i vredi ga pročitati pre
odluke:

- `limitsService.js` već nosi ceo model: besplatan nalog ima **5 sesija
  mesečno** i 20 lekcija, a sesije se broje **po `rooms.creator_id`**. Dakle
  postojeći kod već kaže da plaća **onaj ko otvara sobu**, i da se plaća
  *otvaranje*, ne *ulazak*.
- `checkUserLimits`, funkcija koja to sprovodi, **nema nijednog pozivaoca**.
  Izvezena je i nigde se ne koristi, ni u jednom testu.
- `unlimited_sessions` i `unlimited_lessons` stoje u katalogu prava i ne čita ih
  niko; `requireEntitlement` se koristi na jednom mestu u backendu, za MP4 izvoz.
- Posledica za objavljivanje: `TODO-objavljivanje.md` vodi `ENABLE_LIMITS=true`
  kao poslednji prekidač pred izlazak, „jer zaključava besplatne naloge na 5
  sesija". **Danas ne zaključava ništa** — prekidač stoji ispred `return
  { allowed: true }` koji niko ne zove.

Ulazak u sobu vodi `roomAccess.js`, koji pita za vezu, spisak zvanica i
pozivnicu, a nikada za pretplatu.

**Odluka (korisnik, 26.8.2026):** pretplata je **nužan, ali ne i dovoljan
uslov** za ulazak u sobu. Sve postojeće provere ostaju kakve jesu i i dalje
odlučuju *ko* sme; pretplata se dodaje ispred njih i odlučuje *da li uopšte*.
Razlog je trošak: soba troši glas, promet i prostor, a **gost ne plaća ništa**,
pa u sobi nema šta da traži. Gost time prestaje da bude vrsta učesnika.

**Otvoreno je jedno, i ono određuje cenu:** čija se pretplata gleda pri
*ulasku*. Kapije su zapravo dve i mogu da postoje obe:

| kapija | pita za | stanje |
|---|---|---|
| otvaranje sobe | tarifu **tvorca** | napisano u `limitsService`, nepriključeno |
| ulazak u sobu | tarifu **onoga ko ulazi** | ne postoji, ovo je nova odluka |

- *Svaki učesnik svoju.* Doslovno čitanje pravila. Znači da i dete mora imati
  pretplatu — roditelj koji već plaća časove plaća i aplikaciju.
- *Trener plaća, njegovi učenici ulaze na njegov račun.* Pretplata se traži od
  **tvorca sobe**; učeniku i dalje treba prihvaćena veza, ali ne i svoja
  pretplata. Čuva put kojim se ova aplikacija jedino i širi — trener dovodi
  svoje učenike. Ovo je i ono što postojeći kod već pretpostavlja.
- *Sredina:* ulazak traži pretplatu **ili** prihvaćenu vezu sa tvorcem koji je
  ima. Gost i dalje ne ulazi, dete ne plaća, a niko ne ulazi „badava" bez
  nekoga ko za njega odgovara.

**Posledica koju odluka povlači bez obzira na odgovor:** nadzor roditelja nad
časom (dogovoren, nenapisan) je do sada mogao da se zamisli kao gost. Sa gostima
van soba, roditelj mora da dobije nalog i vezu — ili sopstveno sedište koje nije
ni učenik ni gost.

---

## Drugi trener u sobi — 26.8.2026

**Danas:** ulazi kao svako drugi. `mayJoinRoom` daje sedište `trener` **samo**
tvorcu sobe, pa kolega ulazi kao `ucenik`; domaćin ga može unaprediti
(`change_user_role`), i tek tada dobija dugme za snimanje. Presuda o snimanju se
i tada računa prema tvorcu sobe, jer je roditelj odgovarao o njemu.

**Predlog (korisnik):** drugi trener sme u sobu **samo ako sa svakim učenikom u
njoj ima isti odnos kao i prvi** — dakle prihvaćenu vezu sa svima.

**Šta predlogu fali:** pokriva samo ulazak trenera. Neko uđe posle. Trener koji
je legitimno ušao u sobu sa Markom zatiče, deset minuta kasnije, Anu — sa kojom
vezu nema. Pravilo mora da ima i drugu polovinu, pri ulasku **učenika**; a po
pravilu koje je već postavljeno kod snimanja („ne izbacuj dete zbog
papirologije"), izlazi **gost**, ne Ana, i domaćinu se kaže zašto.

**Dve posledice, obe iz istog korena — saglasnost je po treneru, ne po sobi:**

- **Snimanje.** `parent_allows_recording` se računa prema tvorcu sobe. Sa dva
  trenera unutra, pošteno pravilo je da se sme snimati tek kad je roditelj rekao
  „da" za **svakog** trenera koji je prisutan. Inače prisustvo kolege tiho
  proširuje krug ljudi koji drže glas deteta.
- **Reprodukcija.** `participants` daje pravo na snimak
  (`$1 = ANY(sr.participants)`). Gost-trener u tom spisku dobija kopiju časa, a
  roditelj je pristao na svog trenera.

---

## Druga brava na upisu snimka — kako se uopšte proverava — 26.8.2026

Brave su dve: soba odbija da **pokrene** snimanje dok je dete unutra, upis odbija
da **primi** fajl. Druga postoji samo zbog klijenta koji prvu ne posluša — a to
nije haker, nego **stara verzija naše aplikacije**, koja pravilo ne poznaje i
prosto nastavi da snima.

**Rukom se ne može isprobati:** za pravi 403 spisak u memoriji mora da sadrži
dete, a sadrži ga samo ako je snimanje *pokrenuto* dok je dete u sobi — što
aplikacija ne dozvoljava, jer je dugme tada ugašeno. Trebalo bi napisati namerno
neposlušnog klijenta (socket događaj `recording_status_update {status:'started'}`
mimo ekrana), što traži `socket.io-client` kao dev zavisnost.

**Preporuka:** ne sada. Logika ima 13 testova u `recording_stop.test.js` i sve
četiri mutacije padaju. Postaje vredno onog dana kad APK bude javan — fajl koji
svako može da izmeni — pa ide u `TODO-objavljivanje.md` kao stavka pre objave.

---

## Ranije zabeležena, i dalje otvorena

- **Pristanak roditelja** — tok je napisan 25.8.2026 i **nije viđen uživo**
  (stavka 36 u `TODO-provera.md`). Ostaje otvoreno **dvoje**: model nadzora
  roditelja nad časom (dogovoren u `STANJE-RADA.md`, „Dogovoren model uloga i
  nadzora", nije napisan), i pitanje da li nalog maloletnika treba da bude
  zaključan i pre nego što ima ijednog trenera — potvrđen tekst je po obliku
  obrazac po treneru, pa saglasnost danas visi o vezi.
- **Šta otključava mikrofon (nivo 2).** Predloženo uz model postepenog
  poverenja; mehanizam postoji, uslov nije odlučen — broj održanih časova,
  odobrenje trenera (postoji) ili izričita potvrda roditelja.
- **Panel „Pozicioni faktori"** — filtrirati kao automatske komentare ili
  ostaviti nefiltrirano.
- **Mapa fonta za drugu knjigu** (`TacticsCourse.pdf`). Alat za izvođenje
  postoji (`derive.mjs`, `identify.mjs`), mapa nije završena.
- **Lekcija kao izlaz skenera**, umesto zagonetki. Kurs sa prozom i ilustracijama
  nije katalog i ne treba da postane 211 „zagonetki" — vidi „Iz ovoga sledi da
  skener ima dva izlaza" u `STANJE-RADA.md`.
- **Skeniranje slika** (faza 2) — nikad probano; tačnost na skeniranoj strani je
  nepoznata i traži merenje na pet strana pre nego što se u to uloži.
