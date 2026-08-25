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
| **AI komentar** i objašnjenje pozicije (Gemini `gemini-flash-latest`) | Google, po pozivu | kvota `ai_comments` | **da** — 10 / 500 / 2000 mesečno, uz 10 zahteva/min |
| **MP4 izvoz** | naš CPU na dropletu (ffmpeg) | `mp4_renders`, `mp4_render_seconds` | **da** — samo plaćeni nalog |
| **Skener strana iz knjige** | naš CPU | `scanned_pages` | ne |
| **Snimci časova** u `uploads/` | prostor na dropletu, **trajno** | ne meri se | ne |
| **Mejlovi** (potvrda naloga, saglasnost roditelja) | SMTP provajder, po poruci | ne meri se | ne |
| **Droplet i baza** | fiksno mesečno, bez obzira na upotrebu | — | — |
| Lichess (baza otvaranja, sud o potezu, tablice), ChessDB, `stockfish.online`, uvoz sa chess.com | besplatno, ali uz tuđe uslove i ograničenje brzine | ne meri se | ne |

Cene po jedinici nisu u kodu nego u `.env` (`USAGE_UNIT_COSTS`), pa promena
cenovnika kod provajdera nije izmena koda. Izveštaj `getUsageReport` množi
izmerene količine tim cenama i odgovara na jedino pitanje od koga cena pretplate
sme da počne: **koliko košta jedan aktivan trener mesečno.**

---

## 2. Četiri stanja u kojima se kod zatekao

**Mereno i ograničeno** — AI komentari, MP4 izvoz. Ovde je lanac ceo:
`requireQuota` / `requireEntitlement` odbije, `recordUsage` zabeleži.

**Mereno, neograničeno** — glas i skener. Zna se koliko je potrošeno i koliko
je koštalo, ali niko ne može da bude zaustavljen. Za glas je to najskuplja
stavka koja se ne kontroliše.

**Ni mereno ni ograničeno** — prostor za snimke i mejlovi.

**Napisano, a nepriključeno** — `limitsService.js` nosi ceo model besplatnog
naloga (**5 soba mesečno**, 20 lekcija, bez MP4), broji sobe po
`rooms.creator_id`, i ima funkciju `checkUserLimits` koja to sprovodi.
**Ta funkcija nema nijednog pozivaoca**, ni u jednom testu. Uz nju,
`unlimited_sessions` i `unlimited_lessons` stoje u katalogu prava i ne čita ih
niko.

Posledica koju treba znati pre objave: `TODO-objavljivanje.md` vodi
`ENABLE_LIMITS=true` kao poslednji prekidač pred izlazak. Danas ne menja ništa —
stoji ispred `return { allowed: true }` koji niko ne zove.

Uzgred, jedan podatak koji već imamo: kod postojećeg modela **plaća onaj ko
otvara sobu**, i plaća se *otvaranje*, a ne *ulazak*. To je suprotno od ideje da
pretplata bude uslov za ulazak, i to dvoje treba pomiriti.

---

## 3. Jedini trošak koji se ne resetuje

Sve gore je mesečno i prestaje kad korisnik prestane da radi. Snimci nisu:
`uploads/` je jedina kopija dečjih glasova, gitignorisan, i **kod ga nikad ne
briše**. MP4 izvozi jesu prolazni jer su obnovljivi, snimci nisu.

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
- domaći zadaci, prilagođene zagonetke, lekcije u više koraka
- pregled urađenog, komentari, izveštaj za roditelja
- ponavljanje u razmacima
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

## 7. Šta treba odlučiti

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
