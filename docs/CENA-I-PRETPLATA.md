# Šta košta, šta se meri, šta se naplaćuje

Popis napravljen 26.8.2026, jer je prvobitni plan pretplate stariji od pola
aplikacije. Ovde stoji **šta postoji danas u kodu**, provereno čitanjem, a ne po
sećanju — pa tek onda modeli naplate i ono što treba odlučiti.

Pravilo koje se provlači kroz ceo dokument: *meriti nije isto što i
ograničavati, a ograničiti u katalogu nije isto što i sprovesti.* Ova aplikacija
trenutno ima sva tri stanja istovremeno.

---

## 1. Šta stvarno košta

| stavka | ko naplaćuje | kako se meri danas | ograničeno? |
|---|---|---|---|
| **Glas u sobi** (Agora) | Agora, po minutu | `agora_seconds`, po korisniku | **ne** |
| **AI komentar**, objašnjenje pozicije i **studija pozicije** (DeepSeek od 28.9.2026 — `deepseek-v4-pro`; brojači `ai_comment_tokens`, `ai_studies`, `ai_study_tokens`; ostatak reda opisuje Gemini, koji je tog dana uklonjen) | do 28.9.2026 Google, po pozivu | kvota `ai_comments` | **da** — 10 / 500 / 2000 mesečno, uz 10 zahteva/min. **Relikt** (vlasnik, 26.9.2026): Gemini se više ne koristi, a dvoja vrata još stoje — „Generate AI comment" u Analizi i „Ask" u repertoaru; brišu se u sledećoj turi pojednostavljenja |
| **Reči tutorijala i pregleda** (DeepSeek) | DeepSeek, po tokenu | `ai_tutorial_tokens`, `ai_review_tokens` (ukupni tokeni pokušaja) uz kvote `ai_tutorials`, `ai_review_words` | **da** — 30 / 100 / bez granice |
| **Govor u tekst** — prepis snimka iz Preparation (Groq, `whisper-large-v3`) | Groq, po satu zvuka (stranica kaže $0.111 za sat; nije pročitano sa računa) | od 27.9.2026 `stt_groq_seconds` — dužina snimka za **svaki** pokušaj, i odbijen, jer Groq naplaćuje pokušaj; `provider_requests` (`groq_stt`) po danu | **ne** — vlasnikova odluka (Q3 plana `PLAN-PRIPREMA.md`, 27.9.2026): ko sme da snima sme i da prepiše, broji se bez limita. Na dropletu je isključeno (`STT_PROVIDER` prazan) dok politika privatnosti ne navede Groq (D9) |
| **Prevod tutorijala** (DeepSeek) | DeepSeek, po tokenu | od 27.9.2026 `ai_translations` (jedan po napravljenoj kopiji) i `ai_translation_tokens` (tokeni svakog pokušaja, i odbijenog) | **ne** — vođina odluka po uzoru na govor u tekst (faza 9 plana `PLAN-PRIPREMA.md`); limit je pitanje ovog dokumenta |
| **Naracija filma** (Azure Speech) | Azure, po znaku | od 26.9.2026 `tts_azure_characters`, po korisniku — samo rečenice koje su stvarno poslate (keš pogodak se ne plaća ni ne broji), knjiži se u trenutku izgovora, ne posle crtanja | ne |
| **MP4 izvoz** | naš CPU na dropletu (ffmpeg) | `mp4_renders`, `mp4_render_seconds` | **da** — samo plaćeni nalog; od 25.9.2026 i jedini način da tutorijal stigne do učenika (odeljak 7, tačka 7) |
| **Skener strana iz knjige** | naš CPU | `scanned_pages` | ne |
| **Snimci časova** u `uploads/` | prostor na dropletu, **trajno** | ne meri se | ne |
| **Mejlovi** (potvrda naloga, saglasnost roditelja) | SMTP provajder, po poruci | ne meri se | ne |
| **Droplet i baza** | fiksno mesečno, bez obzira na upotrebu | — | — |
| Lichess sa servera (tablice do 7 figura, cloud-eval suda o potezu, tok partija pri uvozu, pogled na protivnika) i naše lokalne tablice | besplatno, ali uz tuđe uslove i ograničenje brzine; lokalne tablice su naš CPU | od 26.9.2026 `provider_requests` — po provajderu i danu, ne po nalogu, jer domaći suđen na serveru ne zna čiji je zahtev | ne |
| Pozivi **iz aplikacije direktno** — Lichess cloud-eval i `stockfish.online` u onlajn režimu motora, uvoz partija sa chess.com i Lichessa, Lichess tablebase kad server nije dostižan | besplatno, tuđi uslovi | **ne meri se** — server ih ne vidi; merilo bi se tek kad bi išli kroz server | ne |

Cene po jedinici nisu u kodu nego u `.env` (`USAGE_UNIT_COSTS`), pa promena
cenovnika kod provajdera nije izmena koda. Izveštaj `getUsageReport` množi
izmerene količine tim cenama i odgovara na jedino pitanje od koga cena pretplate
sme da počne: **koliko košta jedan aktivan trener mesečno.**

**Gde se to čita** (od 26.9.2026): `node tools/status/status.js` — ovaj mesec po
metrici sa procenom troška, Azure znakovi naspram F0 dozvole, `provider_requests`
za mesec i dan, i pet prethodnih meseci po metrici, da bi se „mesec dana
merenja" (§5) pročitao kao mesec. Nalog svoju potrošnju vidi u aplikaciji:
Settings → Account → „Usage this month" (plan, limiti, sve izbrojano — bez cene).

---

## 2. Četiri stanja u kojima se kod zatekao

**Mereno i ograničeno** — AI komentari, MP4 izvoz. Ovde je lanac ceo:
`requireQuota` / `requireEntitlement` odbije, `recordUsage` zabeleži.

**Mereno, neograničeno** — glas, skener, i od 26.9.2026 naracija (Azure znakovi)
i zahtevi ka Lichess-u. Zna se koliko je potrošeno i koliko je koštalo, ali niko
ne može da bude zaustavljen. Za glas je to najskuplja stavka koja se ne
kontroliše.

**Ni mereno ni ograničeno** — prostor za snimke, mejlovi, i pozivi koje
aplikacija šalje tuđim servisima direktno (poslednji red tabele u §1).

**Napisano, nepriključeno, pa obrisano** — `limitsService.js` je nosio model
besplatnog naloga (**5 soba mesečno**, 20 lekcija, bez MP4) i funkciju
`checkUserLimits` koju niko nije zvao, uz `unlimited_sessions` i
`unlimited_lessons` u katalogu prava koje niko nije čitao. **Obrisano 16.9.2026**
po odluci vlasnika, zajedno sa `ENABLE_LIMITS` i dve stavke „Unlimited …" u
Premium dijalogu. Besplatan nalog danas ograničavaju samo kvote i prava; broj
soba i tutorijala nije ograničen. Ako cena to bude tražila, to je nov posao.

Uzgred, jedan podatak koji već imamo: kod postojećeg modela **plaća onaj ko
otvara sobu**, i plaća se *otvaranje*, a ne *ulazak*. To je suprotno od ideje da
pretplata bude uslov za ulazak, i to dvoje treba pomiriti.

---

## 3. Jedini trošak koji se ne resetuje

Sve gore je mesečno i prestaje kad korisnik prestane da radi. Snimci nisu:
`uploads/` je jedina kopija dečjih glasova, gitignorisan, i **kod ga nikad ne
briše**. MP4 izvozi jesu prolazni jer su obnovljivi, snimci nisu.

**Izuzetak od 25.9.2026: film tutorijala.** Učenik dobija film, pa se film koji
tutorijal imenuje više ne briše po isteku roka od 14 dana — ide tek kad se
tutorijal obriše ili novi izvoz zameni stari (`docs/PLAN-TUTORIJAL-VIDEO.md`,
D2). Jedan film po tutorijalu, izmereno 1,8–6,4 MB. To je prostor koji raste sa
brojem tutorijala, ne sa brojem časova, i briše se zajedno sa tutorijalom.

Znači: trener koji je otišao pre godinu dana i dalje košta svakog meseca, a taj
trošak raste linearno sa svakim održanim časom u istoriji aplikacije. To je
jedina stavka gde „koliko košta aktivan korisnik" nije cela slika.

Odluke koje ovo traži — sve tri su otvorene:

- gornja granica prostora po nalogu, i šta se dešava kad se popuni;
- rok čuvanja (na primer: snimak se briše posle N meseci, uz upozorenje) — ali
  to je i pravno pitanje, jer je saglasnost roditelja data za snimanje časa, ne
  za trajno čuvanje;
- da li je snimanje uopšte funkcija besplatnog naloga.

---

## 4. Šta aplikacija danas ume

Popis postojećeg, da bi odluka imala šta da rasporedi. Oznaka **€** znači da
stavka troši nešto što se plaća po upotrebi.

**Čas uživo**
- soba sa tablom, potezima i dozvolama za učenika
- glas u sobi, mikrofon po učeniku, dizanje ruke, brzi odgovori **€**
- snimanje časa, reprodukcija, izvoz u MP4 **€**
- spisak zvanica, grupe učenika, prekidač za goste

**Analiza i priprema**
- Analiza Studio: stablo varijanti, ocene, automatsko stablo
- baza otvaranja i sud o potezu (preko našeg servera, tuđi besplatan izvor)
- tablice završnica, trener završnica
- uvoz partija sa chess.com i Lichessa
- AI komentar poteza i objašnjenje pozicije **€**

**Rad sa učenikom**
- domaći zadaci, vežbe (pozicija + zadatak), video tutorijala **€** (izvoz)
- pregled urađenog, komentari, izveštaj za roditelja
- ponavljanje grešaka i repertoara u razmacima
- repertoar i vežbanje repertoara

**Sam vežbač**
- taktika, završnice, zagonetke, AI studio protiv motora
- skener pozicija iz knjiga **€** (naš CPU)

**Nalog i odnosi**
- veza trener–učenik u oba smera, sa pristankom
- saglasnost roditelja za maloletnika, i posebno za snimanje
- prijava preko Google naloga, potvrda mejlom **€** (sitno)

---

## 5. Tri modela

### Pretplata

Mesečna cena, i sve unutar nje. Jednostavno za razumeti i jedino što se u praksi
prodaje trenerima.

*Traži:* uključene količine za ono što curi (minuti glasa, AI pozivi, prostor),
inače jedan intenzivan korisnik pojede maržu desetorice. Model za to već postoji
— `usage_counters` i kvote rade.

*Rizik:* cena se određuje na osnovu proseka, a raspodela je verovatno vrlo
neravnomerna — jedan trener sa šest časova dnevno nije isto što i deset trenera
sa dva časa nedeljno. Zato prvo `getUsageReport`, pa cena.

### Plaćanje po upotrebi

Plaća se ono što je potrošeno: minut glasa, AI poziv, MP4 izvoz.

*Traži:* dopunu ili kredit, prikaz stanja i upozorenje pre nego što se potroši.
Na Google Play-u digitalna dopuna ide kroz Play naplatu (potrošni artikal), sa
njihovim udelom.

*Rizik:* trener ne ume da predvidi mesečni trošak, a to je najgora osobina alata
koji se koristi svakog dana. Retko se prodaje samo ovako.

### Mešoviti

Pretplata daje pristup i uključene količine; preko toga se dokupljuje.

*Traži:* oboje od gornjeg, ali ništa što već nije zapisano u modelu — kvote
postoje, merenje postoji, fali priključivanje i ekran koji to pokazuje.

**Preporuka:** mešoviti, u dva koraka. Prvo pretplata sa uključenim količinama,
jer je to jedino što se prodaje; dokup tek kad postoji makar jedan korisnik koji
je količine probio. Pre svega toga — **mesec dana merenja**, jer sve tri
mogućnosti traže isti podatak koji danas nemamo: koliko stvarno košta jedan
aktivan trener.

---

## 6. Plan od 15.8.2026, i šta je od tada nastalo

Prvobitni predlog (artefakt „Procena i Plan Rasta") imao je četiri nivoa:

| nivo | cena | šta je nosio |
|---|---|---|
| Besplatno | 0 | 5 sesija mesečno, 20 lekcija, osnovne zagonetke, 10 AI komentara, bez MP4 |
| **Trener Pro** | 1.490 din/mes | neograničene sesije i lekcije, snimanje i MP4, do 15 učenika, domaći i izveštaji, 500 AI komentara |
| Klub | 5.900 din/mes | 5 trenera, 75 učenika, grupe i prisustvo, administratorski pregled, logo, izveštaji za roditelje |
| Učenik Plus | 590 din/mes | zagonetke po temama, analiza svojih partija, repertoar, AI bez ograničenja |

Pozicioniranje uz njega — *trener plaća, učenici ulaze na njegov račun* — vredi
pročitati ponovo pre nego što se odluči čija se pretplata gleda pri ulasku u
sobu. To je bio zaključak i onda.

**Šta je od tada urađeno od onoga što je plan tražio:** merenje troška po nalogu
(`usage_counters`, `getUsageReport`, cene u `.env`) — plan je izričito pisao da
toga nema; lažni premium (dugme koje besplatno menja tip naloga) je zatvoren i
danas je to admin ruta; `/puzzles/verify` bez prijave više ne postoji.

**Šta je nastalo posle plana i ne pripada nijednom nivou.** Ovo je posao koji
treba obaviti — svakoj stavci odrediti nivo:

| funkcija | nastala | trošak | predlog |
|---|---|---|---|
| Grupe učenika i spiskovi | 25.8. | — | Klub, delom Trener Pro |
| Spisak zvanica za sobu, prekidač za goste | 25.8. | — | uz sobu, dakle Trener Pro |
| Saglasnost roditelja, saglasnost za snimanje | 25.8. | mejlovi | **svuda**, nije funkcija nego obaveza |
| Ponavljanje u razmacima, pregledi | 20–24.8. | — | Učenik Plus |
| Trener repertoara | ranije, prošireno | — | Učenik Plus (plan ga već ima) |
| Završnice i tablice | 23–24.8. | tuđi besplatan servis | Učenik Plus |
| Baza otvaranja i sud o potezu preko našeg servera | 24.8. | naš token, tuđe ograničenje brzine | Trener Pro / Učenik Plus |
| Skener pozicija iz knjiga | 19–20.8. | **naš CPU** | Trener Pro, sa granicom strana |
| Uvoz partija sa chess.com i Lichessa | 20.8. | — | Učenik Plus |
| Govor (TTS) | 23.8. | — (uređaj) | svuda |
| Izveštaj za roditelja | 20.8. | — | Trener Pro (plan ga ima) |

Dve stavke iz te tabele traže odluku, ne raspoređivanje: **skener** je jedina
nova funkcija koja troši naš procesor po upotrebi, a **baza otvaranja** ide
preko našeg Lichess tokena — što znači da tuđe ograničenje brzine delimo svi
zajedno, i da rastom broja korisnika to postaje naš problem, a ne njihov.

---

## 7. Šta je odlučeno (vlasnik, 3.10.2026)

Pitanja su ispod, kako su bila postavljena. Ovo su odgovori; brojevi prate
pitanja. **Ništa od ovoga još nije u kodu** — posao koji svaka odluka traži
stoji uz nju.

1. **Besplatno je sve što nas ništa ne košta, uz malu mesečnu količinu onoga
   što se meri.** Besplatan nalog ima celu stranu table: analizu sa motorom na
   uređaju, zagonetke, završnice, repertoar, svoje partije, vežbe, domaći,
   sesiju sa tablom. Mereno (glas, AI reči, film, snimci, skener) dobija malu
   mesečnu količinu, a plaćeni nalog veću ili neograničenu. Jedna plaćena
   klasa za početak. Odbačeno: besplatan nalog bez ičeg merenog (niko ne vidi
   šta kupuje) i probni period pa zid (trener proba jedne nedelje, a prvi čas
   drži mesec dana kasnije).
2. **Trener plaća, učenici ulaze na njegov račun, a kapija je na glasu, ne na
   sesiji.** Sesiju sa tablom sme da pokrene svako. Glas je plaćeni deo:
   gleda se plan onoga ko je sesiju pokrenuo i njemu se broje minuti; učeniku
   plan ne treba. **Ovo zamenjuje odluku od 26.8.2026** („pretplata je nužan
   uslov za ulazak u sobu", `PITANJA-ZA-ODLUKU.md`): njen razlog je bio
   trošak sobe, a od tada gostiju više nema, sesija se ne snima, i jedino što
   sesija košta jeste glas. *Posao:* sekunde glasa se danas knjiže svakome na
   njegov nalog (`agora_seconds`); treba da se knjiže pokretaču sesije.
3. **Snimci: granica na ukupnu dužinu sačuvanih snimaka po planu; kad se
   popuni, nov snimak se odbija; ništa se nikad ne briše samo.** Granica je u
   minutima zvuka, ne u megabajtima. Besplatan nalog ima malu, plaćeni
   veliku. Na granici „Record" kaže da je prostor pun i upućuje na spisak;
   vlasnik bira šta briše. Istekla pretplata zadržava sve snimljeno, ali ne
   snima dalje dok je iznad besplatne granice. Odbačen je rok čuvanja — to bi
   bio prvi kod koji čisti `uploads/`. *Posao:* nov brojač (sačuvane sekunde
   po nalogu) i provera pre početka snimanja. *Otvoreno:* koliko megabajta
   zauzima minut snimka (nije izmereno), i da li brisanje naloga briše
   njegove zvučne fajlove (nije provereno).
4. **Glas: mesečna količina po planu; kad se potroši, glas ne može da se
   pokrene, ali sesija koja je već u glasu se nikad ne prekida.** Upozorenje
   pre kraja (na primer na četiri petine), na traci sesije i u „Usage this
   month". Sesija sa tablom uvek ide dalje. **Minut je minut po osobi**
   (person-minute), kako Agora naplaćuje i kako server već meri: sat sa
   trenerom i pet učenika je šest sati. Ekran to mora da kaže, jer grupni čas
   troši brže od časa jedan na jedan. Dokup minuta — tek kad neko stvarno
   probije količinu.
5. **Početna cena se određuje sada, iz najgoreg slučaja, ne posle meseca
   merenja.** Vlasnik je jedini korisnik, pa bi mesec merenja izmerio njega.
   Pošto odluke 3, 4 i 7 daju svakom trošku koji raste tvrdu granicu, cena se
   računa iz pretplatnika koji potroši sve do kraja: količine se odmere tako
   da takav pretplatnik košta najviše polovinu onoga što stvarno stigne posle
   udela prodavnice. Jedna plaćena klasa, mesečno i godišnje; cena i količine
   se ponovo gledaju posle prvog meseca sa pravim pretplatnicima. „Učenik
   Plus" i „Klub" iz §6 su odloženi, ne odbačeni. Tabela najgoreg slučaja — svaka
   količina, njena jedinična cena, zbir, i cena koja ga pokriva dvaput posle
   udela — je u `STUDIJA-CENA-I-AKVIZICIJA.md`, §1–§5.
6. **Otpalo.** `checkUserLimits` je obrisan 16.9.2026 (§2); nema šta da se
   priključi.
7. **Besplatan nalog dobija mali mesečni broj izvoza filma**, sa naracijom.
   Kapija je broj izvoza (`mp4_renders` se već beleži); znakovi naracije se i
   dalje mere i ulaze u tabelu najgoreg slučaja. Na granici „Export" kaže
   koliko je ostalo i kada se broj vraća. *Posao:* `mp4_export` od prava
   da/ne postaje mesečna kvota, istim mehanizmom kao AI reči.

Uz ovo, istog dana: **Paddle za Windows** (`STANJE-RADA.md`, stavka 1
vlasnikovog spiska) — Android ostaje na Play-u.

**Dopuna iste večeri — model kredita (vlasnik, 3.10.2026).** Umesto posebne
količine za svaku stvar, nalog ima **jedno stanje kredita** i troši ga na
plaćene servise po svom izboru; svaki tip naloga može da dokupi kredit, po
ceni koja zavisi od tipa naloga i od veličine paketa; cene se određuju po
tome šta servis vredi korisniku, a trošak ostaje donja granica. Time se
menjaju tri odluke odozgo:

- **4** — posebna količina glasa postaje deo stanja. Minut po osobi ostaje
  jedinica cene, a „sesija u glasu se ne prekida" ostaje uz pravilo: glas se
  ne pokreće na nuli, započeta sesija se završava, manjak se skida sa kredita
  sledećeg meseca. Dokup više nije „kasnije" nego deo modela, drugi po redu
  gradnje.
- **5** — cena se ne izvodi iz najgoreg slučaja nego iz vrednosti; najgori
  slučaj ostaje provera (krediti naloga × najveći trošak po kreditu).
- **7** — broj izvoza filma za besplatan nalog postaje mesečni kredit
  besplatnog naloga.

Odluke 1, 2 i 3 ostaju. Granica sačuvanih snimaka (3) ostaje posebna, jer se
snimci gomilaju, a ne troše. Pet izbora koje je vlasnik potvrdio („sve po
preporuci"): jedno stanje umesto pojedinačnih količina; jedan proizvod po
veličini paketa, a broj kredita zavisi od plana kupca; pravilo za glas na
nuli kao gore; prvo planovi sa mesečnim kreditom, pa paketi; jedan plaćeni
plan na početku. Brojevi — cenovnik u kreditima, veličina planova i paketa —
su predlog u `STUDIJA-CENA-I-AKVIZICIJA.md` §3–§4 i **nisu odlučeni**.

**Gde se kupuje na Windows-u je ponovo otvoreno.** Vlasnik je tražio
alternative za Paddle, čija pravila zabranjuju virtuelnu valutu i uskladištenu
vrednost, bez reči o kreditima za sopstveni softver. Studija §6 ih poredi;
preporuka sesije je kupovina kroz sam Microsoft Store (pretplata i potrošni
dodaci), a veb-prodavac samo za platformu koja nema prodavnicu. Čeka dva
odgovora: Microsoft (tip naloga, uz dopunu pitanja o prodaji kroz Store) i
Paddle (krediti, korisnici od 13 do 17 godina). **Oba pitanja su poslata
3.10.2026**: Microsoftu kroz zahtev za podršku u Partner Center-u, sa
dopunom; Paddle-u kroz podršku za prodavce, za šta je vlasnik otvorio
besplatan nalog prodavca — provera domena nije pokrenuta i ništa drugo na
tom nalogu nije popunjeno.

### Pitanja kako su bila postavljena

1. **Šta ulazi u besplatan nalog.** Danas je odgovor „skoro sve, jer ograničenja
   nisu priključena".
2. **Čija se pretplata gleda pri ulasku u sobu** — vidi
   `PITANJA-ZA-ODLUKU.md`, „Ko sme da bude u sobi". Postojeći kod naplaćuje
   *otvaranje* sobe tvorcu.
3. **Snimci: granica, rok, i da li su za besplatan nalog.** Jedini trošak koji
   ne prestaje.
4. **Glas: uključeni minuti i šta biva kad se potroše.** Danas nema granice.
5. **Cene pretplate** — tek posle meseca merenja.
6. **Priključiti `checkUserLimits`** pre nego što `ENABLE_LIMITS` ima ikakvog
   smisla.
7. **Tutorijal za besplatan nalog.** Od 25.9.2026 učenik dobija samo film
   tutorijala, a izvoz filma traži `mp4_export`, koji besplatan nalog nema —
   pa trener na besplatnom nalogu **ne može da pošalje nijedan tutorijal**.
   Prihvaćeno za sada, jer još niko ništa nije kupio
   (`docs/PLAN-TUTORIJAL-VIDEO.md`, D5). Druga mogućnost je mala mesečna kvota
   izvoza za besplatan nalog; odluka pada najkasnije uz prvu pravu kupovinu.
