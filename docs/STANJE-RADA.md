# Stanje rada — nastavak u novoj konverzaciji

Namena: da neko ko dolazi bez istorije razgovora za pet minuta zna gde smo stali
i zašto je nešto urađeno baš tako. Nije prepis dijaloga — prepis troši prostor,
a odluke su ono što se ne može rekonstruisati iz koda.

Ovde stoji samo **ono što je još živo**: gde smo, šta je otvoreno, šta sledi, i
pravila koja i dalje važe. Zatvorena istorija — popravke sa ✅ i datumom,
merenja, i putevi kojima se do sadašnjeg oblika došlo — preseljena je 27.8.2026.
u [arhiva/STANJE-RADA-do-26.8.2026.md](arhiva/STANJE-RADA-do-26.8.2026.md).
**Arhivu ne treba čitati unapred**; ona se pretražuje (`grep`) kad zatreba
*zašto* neke starije odluke. Razlog za podelu: ovaj fajl je bio 242 KB i svaka
je sesija počinjala tako što ga je ceo pročitala.

Zbog podele poneko „odeljak iznad/niže" sada pokazuje preko granice dva fajla —
ako ga nema ovde, u arhivi je.

Poslednje ažuriranje: **11.9.2026** — najnovije je „Tutorijal iz fajla, i
oznake koje su oduvek postojale" odmah ispod ove glave, pa „Četiri prijave
uživo: slova, glas i uzorak", pa „Izbor glasa: prvo jezik, pa glas",
„Azure Speech, i srpski koji je vraćen a ne preveden" i „Glas koji ne može da
progovori se sada zna pre crtanja"; pre toga, faze 1 do 6 plana snimanja su u kodu, dakle ceo prvi deo, a od drugog dela
tačke 4 i 5 („Render izlazi iz zahteva" i „Render koji ne može da stane" niže):
trener snima svoj glas preko tutorijala, izvozi video u tom glasu, i snimak zna
kojim taktovima pripada („Snimanje glasa: faza 6", „faza 5" i „faza 4" niže), a „ODAKLE
SUTRA — 10.9.2026, video i snimanje" ispod toga. Tog dana i noći pred njim: prekid napuštenog rendera,
pregled pre renderovanja, jedan film po tutorijalu sa linkom na zahtev,
pravednost reda po nalogu, i zatvorena faza 0 plana snimanja.

Prethodno: 6.9.2026 (redizajn studija: **P0–P4 gotove** — deo
tutorijala čuva svoje stablo, drugi „Sačuvaj“ menja tutorijal umesto da pravi novi,
ekran zna zašto se otvara, i „Biblioteka“ ima ulaz u studio; ostaje P5 nadalje. Tutorijal: cela
faza 4 zatvorena, ostaje faza 5, provera uživo).

---

## Tutorijal iz fajla, i oznake koje su oduvek postojale — 11.9.2026, nije viđeno uživo

Gemini je napisao dvadeset sedam tutorijala kao JSON fajlove po
`PGN-TUTORIAL-FORMAT.md`, u folderu van repozitorijuma, i nije
postojao način da se učitaju osim `curl`-om. Sada postoje dva: **Biblioteka →
Interaktivni tutorijali → „Import from a file"**. Aplikacija: **1942 testa**
(1 preskočen), backend: **1206**, analyze na 29 info i nula upozorenja. Deset
mutacija, sve uhvaćene.

**Jedan fajl se otvara u studiju i ne čuva se usput.** To je ono što je traženo:
prvo se pogleda na tabli, popravi ono što ne valja, pa se pritisne „Sačuvaj
tutorijal" — sa svim odbijanjima koja taj ekran već pravi, uključujući ono o
pitanju koje nosi svoj odgovor. **Više fajlova** ide pravo u biblioteku, jer
otvaranje dvanaest fajlova jedan po jedan u ekranu za pisanje nije provera nego
posao koji se preskoči.

**Čitač je `TutorialSection.fromStep`, ništa novo.** `positionList` iz fajla je
isti oblik kao `position_list` iz baze, pa se fajl čita kroz `readStepTree` →
`LessonStepLine`, dakle kroz parser koji dete koristi. Novo je samo pitanje koje
taj čitač ne može sam da postavi: **vredi li ovaj fajl otvoriti**, i ako ne — u
kom delu i zašto. `readTutorialJson` razlikuje dve vrste greške: ono što bi
server odbio (nečitljiv FEN, rešenje koje se ne može odigrati, loš broj
ponuđenih odgovora) i ono što bi bilo **sačuvano i pogrešno** (linija koja se ne
odigrava iz svoje pozicije, pitanje koje nosi odgovor). Prvo se ne šalje uopšte;
drugo se prijavi i trener odlučuje.

**`id` koraka se uvek odbacuje.** Korak po tom id-u nalazi red rasporeda i
zapamćen odgovor, pa bi isti fajl uvezen dvaput imao iste id-eve u dva
tutorijala — dečji napredak u pogrešnoj kopiji, bez ijedne poruke, jer se ni na
šta ne spaja.

**Oznake (labels) su već postojale na svakom sloju osim na ovom.**
`saved_lessons.tags` je u šemi, `GET /lessons/labels` ih vraća,
`GET /lessons?includeTags=&excludeTags=&matchMode=` filtrira, `SavePositionDialog`
ih piše a `MatrixFilterPanel` ih crta — samo tutorijal nikad nije stigao do
njih. Sada: polje „Labels" u studiju pored naziva, polje u dijalogu za uvoz koje
označi ceo skup fajlova odjednom, i u „Sačuvani tutorijali" traka čipova plus
pretraga po imenu. Čipovi se čitaju **iz samih redova**, ne iz
`GET /lessons/labels`: taj kraj vraća i oznake sačuvanih pozicija, a čip koji
prazni listu kad se pritisne je čip koji se ne pritisne drugi put.

**Uz to je izašla greška koja je tiho brisala opis.** `PUT /lessons/:id` je
pisao `description = $2, tags = $3` na **svakom** zahtevu, iz `body.x || null`,
a `commitDraft` ne pominje nijedno — pa je otvaranje sačuvanog tutorijala i
pritisak na „Sačuvaj tutorijal" brisao opis, ćutke. Niko to nije video jer u
aplikaciji ništa nikada nije pisalo opis tutorijala — do uvoza, koji je stigao
istog dana. Server sada ostavlja kolonu na miru kad je zahtev ne pomene (isto
pravilo koje `positionList` već ima), a `commitDraft` šalje ono što nacrt drži.
Prazna lista i dalje briše — „ovaj tutorijal više nema oznake" mora da ostane
izgovorljivo.

**Dvadeset tri od dvadeset sedam fajlova sada prolaze čisto** (bilo je
četrnaest). Popravka je jednokratna skripta koja: skida ocene zalepljene za
potez (`Kb6+-`, `Be8!+-`), **prepisuje potez kanonskim SAN-om** — `Bd6+` gde
nema šaha aplikacijin parser odbija, a python-chess ga prima, pa se neslaganje
vidi tek kad trener otvori tutorijal i nađe četiri poteza manje — vraća
`[%cal]` unutar vitičastih zagrada, i pitanju koje nosi odgovor izdvaja liniju u
zaseban `show` deo posle njega. Popravljeni fajlovi su u `fixed/`, originali
nisu dirani. **Četiri su ostala za čoveka**: `solutionSan` koji nije legalan u
svom FEN-u (`adv_endgame_queen_vs_rook_and_pawn` 3, `attack_focal_points_f7_g7_h7`
4, `positional_space_advantage_restriction` 4, `pvladan_vs_kvobetis_london` 4) —
u tri slučaja izgleda kao greška u strani koja je na potezu, a to je pogađanje o
šahu, ne o notaciji, pa nije rađeno automatski.

`PGN-TUTORIAL-FORMAT.md` je dopunjen pravilima koja su nedostajala (ništa
zalepljeno za potez, `+` samo kad stvarno ima šaha, `[%cal]` unutar zagrada,
pitanje bez linije, `solutionSan` legalan u svom FEN-u, opcioni `tags`) i ima
odeljak C o uvozu u aplikaciji.

Provera uživo: `docs/TODO-provera.md`, stavka 147.

---

## Četiri prijave uživo: slova, glas i uzorak — 11.9.2026, delimično provereno

Jedno veče sa pravim Azure nalogom, četiri prijave, sve četiri zatvorene u kodu.
Aplikacija: **1893 testa** (1 preskočen), backend: **1202**, analyze na 29 info i
nula upozorenja. Dvadeset četiri mutacije, sve uhvaćene.

**1. „Kad izgovara poteze Bc4, ovo c se skoro i ne čuje."** Polja su svuda bila
gola slova, i to je bilo pravilo sa razlogom: u srpskoj verziji aplikacije
„ge" je pročitala engleska tabela kao „dzh". Ali sa srpskim glasom koji čita
srpski, usamljen suglasnik je glas a ne reč. Ono o čemu je stara greška zapravo
bila jeste glas koji čita jezik koji nije njegov — pa tabela pripada **jeziku**:
`files` nema u pet rečnika čiji glasovi slovo ionako izgovaraju kako treba, a
ima ga u dva srpska (be, ce, de, ef, ge, ha). Provereno na pravom glasu, ne samo
u testu: `exports/tts-probe.wav`, „Odigraj lovac ce četiri, pa mala rokada".

**Srpski ima dva pisma i Azure ima oba.** `sr-Latn-RS` je latinički lokalitet, a
goli `sr-RS` ćirilički, i jedino id kaže koji je — pa postoje dva srpska rečnika.
Ono što je trener napisao se ne dira ni u jednom slučaju; u pismu glasa se piše
samo ono što se **dodaje** na putu do sintetizatora.

**2. „u renderovanom videu slova č, ć se ne vide."** `sans-serif` nije font nego
šta god mašina vrati, a na vlasnikovom Windowsu je to bila porodica bez Latin
Extended-A — dakle svako š, đ, č, ć i ž u svakom natpisu svakog filma je bilo
kvadratić, otkad je render napisan. Ni ispravka ne imenuje porodicu: ona se
**bira crtanjem**, jer su „č" i „ć" dva različita znaka, a font koji nema nijedan
nacrta isti kvadratić dvaput (`services/renderFont.js`). Stari test nad
pikselima ovo nije mogao da uhvati — pitao je ima li mastila, a kvadratić jeste
mastilo.

**3. Brojevi redova su bili nevidljivi od popravke slova kolona.** Popravka od
9.9.2026. je postavila `fillStyle` za kolone i ostavila redove da ga naslede, pa
je parnost koja je bila pogrešna za jedno postala pogrešna za drugo: osam
brojeva, nijedan nacrtan, dva dana. Sada oba natpisa pitaju tablin sopstveni
izraz `(row + col) % 2`, a test za redove je napisan kao blizanac testa za
kolone da par ne bi mogao ponovo da se popravi na pola.

**4. „Kako da se u Preview for students takođe bira glas… ili da se pusti sample
da čuje."** Uzorak, ne pregled: pregled je nem po prirodi (tri slike, bez
ffmpeg-a i bez reda čekanja), pa dodavanje izbora glasa tamo ne bi dalo da se
išta **čuje**. `GET /lessons/tts/sample?voice=…` izgovori jednu rečenicu, kroz
`spokenMoves` — dakle onako kako će zvučati i takt — i odbija glas koji ovaj
server nije sam ponudio: neprovereno ime stiže do Azurea kao 400, a do pipera
kao **drugi model**, pa bi trener birao po glasu koji nikad nije čuo. Dugme je
pored padajuće liste glasova u izvoznom listu.

Sitnica koju treba znati: u `.env` sada stoje **dva** reda `TTS_PROVIDER` (stari
`piper` i novi `azure`). Poslednji pobeđuje, ali to je detalj implementacije
dotenv-a, a ne pravilo — obrisati stari red.

## Izbor glasa: prvo jezik, pa glas — 11.9.2026, nije viđeno uživo

Vlasnikov Azure nalog je 11.9.2026. odgovorio sa **655 glasova u 154 jezika**
(`node scripts/tts-probe.js`). Jedna padajuća lista od 655 stavki je lista do
čijeg kraja niko ne skroluje, pa izvozni list sada pita **prvo jezik** — imenom
koji server pošalje („Serbian (Latin, Serbia)"), a ne šifrom — a lista glasova
je lista tog jezika. Kontrola za jezik se crta samo kad ih ima više od jednog,
po istom pravilu po kom se crta i pitanje o naraciji: pitanje sa jednim
odgovorom nije pitanje.

**I odgovor na staro pitanje: Azure ima srpski glas.** Četiri, u oba pisma —
`sr-RS-NicholasNeural` i `sr-RS-SophieNeural`, sa `sr-Latn-RS-` blizancima. U tri
fajla je stajalo da ga nema, a provereno je bilo protiv Googleove liste. Za
tekst pisan latinicom treba `sr-Latn-RS` glas; `sr-RS` je ćirilički lokalitet.
Komentari sada kažu šta je provereno i protiv čega.

**„Prvi glas sa liste" prestaje da bude razuman podrazumevani izbor.** Lista je
sortirana po jeziku, pa je prvi glas od 655 bio afrikans — a pozivalac je baš to
slao kad ništa nije zapamćeno. Sada šalje null, a list bira: jezik zapamćenog
glasa, pa jezik same aplikacije, pa vrh liste. Null pokriva i zapamćen glas koji
server više ne nudi, što je tačno ono što promena `TTS_PROVIDER`-a uradi svim
id-jevima odjednom.

Aplikacija: **1891 test** (bilo 1884), 1 preskočen, `flutter analyze` na 29 info
i nula upozorenja. Sedam mutacija, sve uhvaćene — jedna je isprva preživela i
otkrila stražu koju ništa nije moglo da dosegne; zamenjena je pravilom na ulazu
u list, koje test sa glasom bez jezika stvarno dohvati.

## Azure Speech, i srpski koji je vraćen a ne preveden — 11.9.2026, nije viđeno uživo

Vlasnik je 11.9.2026. uzeo ključ i region za Azure Speech, pa `services/tts/
azure.js` postoji: četvrti provajder i **prvi oblak koji ovaj projekat može da
plati**. Google Cloud stoji napisan i nedostupan od 9.9.2026. jer ne prima
individualni platni profil iz Srbije; Azure traži pretplatni ključ i region i
ništa drugo. Piper ostaje instaliran kao rezerva — bira se `TTS_PROVIDER`-om, i
dalje radi bez naloga, bez kartice i bez mreže.

**Ključ ne ulazi u repozitorijum.** `.env.example` nosi samo imena
(`AZURE_SPEECH_KEY`, `AZURE_SPEECH_REGION`); vrednosti idu u `.env` na mašini
kojoj trebaju. Resurs ima dva ključa upravo zato da se jedan može poništiti bez
prekida.

**Region, a ne URL.** Oba endpointa se grade od regiona
(`https://<region>.tts.speech.microsoft.com`), pa provajder odbija sve što nije
slovo ili cifra — inače se od nalepljenog URL-a gradi `https://https://…` i kvar
stiže kao poruka o hostu umesto kao poruka o konfiguraciji.

**SSML je jedina prava razlika u odnosu na Google.** Googleov endpoint prima
običan tekst i `google.js` piše zašto ga baš tako šalje: rečenica sa `<` u sebi
nije pokvaren markup nego rečenica koju bi SSML odbio. Azurov `cognitiveservices/
v1` prima isključivo SSML, pa taj izbor ne postoji — `ssmlFor` escapuje i ima
test, sa ampersandom **prvim**, jer escapovanje `&` na kraju pretvori četiri
ranija escapea u „and a m p semicolon".

**Lokalitet nije uvek dvodelan, i srpski je razlog.** Azure piše srpski kao
`sr-Latn-RS`, sa pismom u sredini. `languageOf` uzima sve do **poslednje** crte;
dvodelno čitanje kakvo koristi `google.js` poslalo bi `xml:lang="sr-Latn"` i
svrstalo sve srpske glasove pod jezik koji ne postoji.

**Srpske reči su vraćene, ne prevedene.** `spokenMoves.js` je dobio `sr` rečnik,
pa se „Bd5" izgovara „lovac d pet" umesto da se slovka — a reči su `serbianSpeech`
tačno onakav kakav je stajao u `speech_text.dart` pre engleskog zaokreta
(`ce012c0^`), dakle ono što su treneri slušali nedeljama. Pravilo je staro i u
`CLAUDE.md`: potraži postojeću implementaciju pre nego što napišeš drugu.

**„Ni Google ni Azure nemaju srpski glas" je stajalo u tri fajla, a provereno je
protiv jedne liste.** Sada na to pitanje odgovara `node scripts/tts-probe.js`,
koji ispiše listu glasova koju nalog stvarno ima, grupisanu po jeziku, i traži i
`sr-RS` i `sr-Latn-RS`.

**Šta ostaje, i nije u ovom poslu.** Padajuća lista glasova u izvoznom listu
crta jednu stavku po glasu. To je tačno za piperovih šest i neupotrebljivo za
oblak sa nekoliko stotina; probe skript ispiše koliko ih zaista ima, a popravka
je filter po jeziku u samom listu. Aplikacija u ovom poslu nije dirana.

Backend: **1186 testova** (bilo 1176), sa `.env` sklonjenim u stranu. Devet
mutacija, sve uhvaćene.

## Glas koji ne može da progovori se sada zna pre crtanja — 10.9.2026, nije viđeno uživo

Prijava vlasnika te večeri: izvoz tutorijala se renderuje bez glasa iako je
jezik izabran. U logu: `piper exited 1: ...python.exe: No module named piper`,
zatim `[TTS] narration was asked for and every beat came back silent`, pa
uredan `Success!` i film — nem.

**Dve izmene, obe tražene tog dana.**

*Prva je konfiguracija.* Piper je na razvojnoj mašini bio instaliran sa
`pip install --user`, dakle u `%APPDATA%\Python\Python313\site-packages`, a
`PIPER_PYTHON` je bio prazan — što znači `python`, razrešen kroz PATH. Oba
oslonca zavise od okruženja procesa koji ga pokreće: korisnički `site-packages`
je na `sys.path` samo dok proces nosi ispravan `APPDATA`. Sada postoji
virtualenv (`C:/Users/Admin/.piper/env`) i `PIPER_PYTHON` pokazuje na njegov
interpreter punom putanjom; venv razrešava svoje pakete iz `pyvenv.cfg` pored
sopstvenog `python.exe`, pa mu ni PATH ni APPDATA ne mogu ništa. Provereno:
isti `import piper` prolazi i kad se `APPDATA` obriše iz okruženja, dok je pod
`--user` instalacijom padao. Droplet je to ionako već imao — `deploy/
provision.sh` pravi venv u `/opt/piper`; pogrešna je bila samo razvojna mašina i
uputstvo u `.env.example`, koje je to preporučivalo.

*Druga je kod, i ona je važnija.* `piper.available()` je odgovarao na pitanje o
**modelima** — „ima li `.onnx` fajlova u direktorijumu" — a ne o **motoru**.
Zato je aplikacija ponudila prekidač za naraciju, server prihvatio `narrate:
true`, i tek posle celog crtanja film ispao nem. „Instalirano" i „dohvatljivo iz
ovog procesa" su dva pitanja: `piper.engineReady()` je sada drugo od njih —
jedan `find_spec("piper.__main__")` po interpreteru, asinhrono (250-430 ms na
niti koja crta nečiji film), zapamćen za život procesa. Posledica: motor koji ne
može da se pokrene znači **praznu listu glasova**, pa se prekidač uopšte ne
crta, a ako neko ipak pošalje `narrate: true`, trener dobija svoju rečenicu —
„the speech engine could not start", odvojenu od „no speech voices installed",
jer te dve šalju čoveka na dva različita mesta.

**Šta nije utvrđeno, i to treba da stoji.** Log je u UTC (`translateTime` bez
`SYS:`), pa je `21:15:18` zapravo `23:15:18` po lokalnom vremenu — minut posle
pokretanja servera u `23:14:11`. Okruženje **tog istog procesa** je pročitano iz
PEB-a dvanaest minuta kasnije i bilo je ispravno: `APPDATA` na mestu, bez
`PYTHONNOUSERSITE`, `PYTHONPATH` i `PYTHONHOME`, Python313 prvi na PATH-u, a
paket u korisničkom `site-packages` neizmenjen od 9.9. u 11:28. Tri načina da se
ista poruka izazove su reprodukovana (bez `APPDATA`, sa `PYTHONNOUSERSITE=1`, sa
tuđim `APPDATA`), ali nijedan od njih se u tom procesu nije desio. Dakle: klasa
greške je uklonjena, konkretan okidač tog jednog pokretanja nije objašnjen — i
zato je druga izmena ona koja nosi težinu, jer se **svaka** takva greška sada
vidi pre crtanja, a ne minut posle njega.

Backend: **1176 testova** (bilo 1172), sa `.env` sklonjenim u stranu. Šest
mutacija, sve uhvaćene — a jedna je isprva preživela: `narrateFilm` koji
uvek kaže „unavailable" umesto stvarnog razloga ostavljao je sve zeleno, iako je
to rečenica koju trener čita. Test za nju je napisan pošto ju je mutacija
otkrila.

## Render izlazi iz zahteva — tačka 5 drugog dela plana snimanja, 10.9.2026, nije viđeno uživo

Izvoz tutorijala sada odgovara **čim server prihvati film** (`202` i id posla), a
film se crta posle odgovora. Ekran se više ne zamrzava: traka ima „Hide" (film se
crta dalje, a kad bude gotov stiže obaveštenje na zvonce) i „Cancel render".
Sakriven render se nalazi ponovo na redu tutorijala u „Saved tutorials" (ikona
filma), a drugi izvoz istog tutorijala prikazuje onaj koji već radi umesto da
pokrene novi.

Posao je **red u bazi** (`tutorial_render_jobs`, `services/renderJobs.js`), ne
zapis u memoriji. Server bira id; jedan render po tutorijalu i treneru čuva
jedinstveni indeks; a red koji kaže `running`, a iza njega nema ničega (restart
servera), proglašava se neuspelim — pri pokretanju, uz obaveštenje, i kad god ga
neko pogleda. Sve što odbija film i dalje odgovara u samom zahtevu (404, 400,
409, 422, 429).

**Četiri dopune vlasnika iste večeri**, pre commit-a:

1. Plafon za jedan film je **600 s crtanja** (`RENDER_MAX_DRAW_SECONDS`), oko 30
   minuta tutorijala na 720p. `RENDER_REQUEST_SECONDS` (300, nginx) se vratio i
   znači samo vezu.
2. Snimak glasa sme do **30 minuta**, i to više nije poseban broj: izvodi se iz
   plafona (najduži film sa natpisima koji jedan render sme da nacrta na 720p).
   `GET /lessons/:id/narration` ga vraća kao `maxMs`, a studio pita pre nego što
   otvori ekran za snimanje. Kad server ne može da se pita, ekran staje na starih
   15 minuta — namerno kraće, jer se kraći snimak uvek prima.
3. **Izvoz snimljenog časa ide ispred tutorijala koji čekaju**, jer se on i dalje
   crta u zahtevu (300 s). Film koji se već crta ne može da prekine — jedan slot
   crta jedan film — pa ako mu ostatak tog filma pojede vreme, odmah dobija 429
   sa „Try again in about N minutes", umesto da ga nginx preseče. Proverava se i
   na ulazu i kad dođe na red.
4. `abortOnDisconnect` je obrisan sa svoja tri testa; signal pali trenerovo
   „Cancel".

Namerno nije urađeno: deljenje filma na komade (dugačak film i dalje drži slot
do deset minuta), noćni red, čišćenje starih redova poslova, i prekid izvoza
snimljenog časa (nije ga imao ni ranije). Detalji i razlozi su u planu, pod
„5 — the render leaves the request".

Trideset četiri mutacije, sve uhvaćene testom na koji su ciljale. Usput je jedan
test koji je zaboravio da otvori svoju kapiju oborio još deset — a pravilo
„jedan render po tutorijalu" je svaki put radilo kako treba. Test
„3. empty events", poznat kao nestabilan, sada broji samo fajlove svog tutorijala.

Brojke, merene sa ovim izmenama bez ičega drugog uz to: **1884 u aplikaciji** (1
preskočen), **1172 na backendu** sa `.env` sklonjenim u stranu, analyze 29
infos, bez upozorenja. Provera uživo: `TODO-provera.md`, stavka **143**; stavka
142 je dopunjena, jer se njeni koraci 2–5 menjaju sa novim plafonom.

Van koda: `chess_backend/.env` je od 9.9. stajao kao `.env.aside` — ranija
sesija ga je sklonila za merenje kao na CI-ju i nije ga vratila, a to ime nije
u `.gitignore`, pa je jedan `git add` delio tajne od javnog repozitorijuma.
Vraćen je 10.9.2026, a merenja sa `.env` u stranu sada rade sa `trap`-om koji ga
vraća i kad test padne.

---

## Render koji ne može da stane se odbija pre crtanja — tačka 4 drugog dela plana snimanja, 10.9.2026, nije viđeno uživo

Server sada pre prvog frejma računa koliko bi film trajao
(`services/renderBudget.js`): frejmove po istom pravilu po kom ih renderer crta
(`framesPerSecondOf`), podeljene brzinom crtanja iz `.env`. Film koji ne može da
stane ni u jedan zahtev (300 s, koliko nginx daje) odbija se **odmah**, sa 422 i
rečenicom koja kaže koliko bi trajalo, koliko server može u jednom komadu, i
samo one izlaze za koje je provereno da staju: podeli na N tutorijala, 720p
umesto 1080p, film bez snimka.

**Red je postao obećanje o vremenu.** Svaki posao nosi procenu i rok; novi se
odbija kad bi on zakasnio iza drugih (a sam bi stao), ili kad bi zbog njega
zakasnio film koji već čeka — round-robin to može, jer nalog koji još nije
služen ide napred. Taj odgovor je 429 sa „Try again in about N minutes", a ne
rečenica o punom redu: server ima mesta, nema vremena. Film sa sintetizovanim
glasom meri se **ponovo kad dođe na red**, jer mu se prava dužina zna tek kad
glas progovori.

Podrazumevane brzine su 12 i 6 frejmova u sekundi (720p / 1080p) — sporiji kraj
razvojne mašine sa marginom. **Brzina dropleta nije izmerena**; to je korak 6
stavke 142. Petnaestominutni snimak na 720p je po podrazumevanoj brzini tačno
jedan zahtev, i test to drži: granica snimka i ovaj budžet su sada jedna odluka.

Osamnaest mutacija, sedamnaest pada. Dve su najpre preživele i obe su nalaz:
ruta nije imala test da posle glasa **javlja redu** novu procenu (`revise` je bio
dokazan samo u samom redu), a **pravilo „natpis → 4 frejma u sekundi"** nije
imalo nijedan test u celom paketu — mutacija koja svaki film crta jednom u
sekundi prolazila je sve, a budžet se sada na to pravilo oslanja. Oba sada imaju
test. Preživljava namerno samo izvoz snimljenog časa (`routes/recordings.js`)
koji redu javlja svoju procenu: ta ruta nema test izvoza ni pre ni posle.

Usput: test „3. empty events" u `tutorial_video_export.test.js` je nestabilan —
broji fajlove u pravom `exports/` dok drugi test fajlovi rade paralelno. Pao je
jednom u punom prolazu, nevezano za ovu promenu, i ponuđen je kao zaseban
zadatak.

Iz provere uživo 10.9. (beleške i prijave): ekran se zamrzava za ceo render, što
je najjači argument za tačku 5; tutorijali postoje samo na Windowsu, pa koraci
za telefon u stavkama 136 i 141 ne mogu kako su napisani (141.6 je
preformulisan); i „Moji materijali" sa kvotom po nalogu. Sve troje je upisano u
plan, odeljak „What the live check changed".

Brojke: **1146 na backendu** sa `.env` sklonjenim u stranu, aplikacija nedirnuta
na 1876. Provera uživo: `TODO-provera.md`, stavka **142**.

---

## Snimanje glasa: faza 6, jedno pitanje za zvuk filma — 10.9.2026, nije viđeno uživo

U „Export video" su dva prekidača — „Use my recording" i „Narrate this video" —
postala jedno pitanje **„Narration" sa tri odgovora**: „My recording (m:ss)",
„Synthesised voice" i „No voice". Odgovor se crta samo tamo gde može da se
ispuni (snimak samo ako postoji na uređaju i slaže se sa taktovima, sintetizovan
glas samo ako ga server ima), a pitanje samo kad postoje bar dva odgovora. Server
se nije menjao: ruta je već gledala `useRecording` pre `narrate`.

**Snimak je podrazumevan i ne pamti se.** Kad ga trener izabere, ne briše se ono
što je prošli put izabrao između sintetizovanog glasa i tišine — taj odgovor
važi baš za filmove koje snimak ne može da napravi: tutorijal izmenjen posle
snimanja, sledeći koji još nije snimljen. Test to proverava na sačuvanoj
postavci, ne na ekranu.

**Dijalog nije stao na telefon.** Sa sva tri odgovora i listom glasova viši je
za 49 px od 360 × 640, a release build to odseče bez reči: test koji je tapnuo
„Higher quality (1080p)" pogodio je red sa dugmadima, dakle na telefonu je
prekidač stajao ispod „Export". Sada dijalog skroluje, a test traži da prekidač
**radi** — zahtev kaže 1080p — umesto da pita da li je nešto bacilo izuzetak.

Osam mutacija, svih osam pada. Provera uživo: `TODO-provera.md`, stavka **141**;
koraci u stavkama 139 i 140 koji su opisivali prekidač su preformulisani.

Time je **ceo prvi deo `PLAN-SNIMANJE.md` u kodu**. Ostaje drugi deo (tačke 4 i
5 — odbijanje prevelikog rendera i izlazak rendera iz zahteva), i dalje
otvoreno brisanje **lokalnog** snimka kad se tutorijal obriše.

Brojke: **1876 u aplikaciji (1 preskočen)**, backend nedirnut na 1126;
`flutter analyze` 29 info poruka, bez upozorenja i grešaka — mereno na `master`,
bez ičeg drugog pokrenutog.

---

## Snimanje glasa: faza 5, snimak zna kojim taktovima pripada — 10.9.2026, nije viđeno uživo

Prepravi rečenicu, dodaj deo, zameni dva mesta — i markeri imenuju taktove nad
kojima nisu snimljeni. Ćutke, i film je pogrešan negde od sredine, što je
polovina koju niko ne proverava. Broj taktova, koji je to čuvao do sada, vidi
dodat i obrisan takt i **ne vidi prepravljenu rečenicu**.

Snimak sada nosi **potpis liste taktova** nad kojom je napravljen —
`filmSignatureOf`, sha256 nad `filmBeatsOf`, dakle nad istom šetnjom po
tutorijalu koju film crta. Kad se potpis tutorijala razlikuje, studio to kaže
**tamo gde je izmena i napravljena**, sa dva izlaza: „Record again" i „Export
without your voice". Isti odgovor daje ekran za snimanje, dijalog za izvoz i
server — jedna odluka (`takeMismatchOf`), tri rečenice.

Šta **nije** u potpisu, i to je pola faze: ime tutorijala, ime dela, strelice,
obojena polja i okrenuta tabla. Sve to menja šta je nacrtano na taktu, a ne koji
je takt niti koliko dugo se o njemu priča — sat vremena snimanja ne sme da
propadne zbog naslova.

**Snimak bez potpisa nije snimak koji se slaže.** Napravljen je starijom
verzijom aplikacije, stoji na trenerovim uređajima i na serveru, i sudi se po
broju taktova kao i pre; server odbija tek kad **obe** strane imaju potpis.
Odsustvo je treći odgovor, po treći put u ovom projektu.

Dva nalaza, oba iz mutacija koje su preživele. **Potez nije u potpisu** — bio je
u prvoj verziji, i brisanje mu ništa nije oborilo: fen takta već odgovara za
potez koji ga je napravio, jer se dve linije koje se razlikuju u jednom potezu
razlikuju u svakoj poziciji posle njega. Polje koje nijedan test ne može da
obori je polje u koje će se verovati a da ga niko nije pročitao. I **fikstura
može da dokazuje pogrešnu stvar**: „deo koji počinje na drugoj poziciji" je
najpre menjao i broj taktova, pa nije govorio o fenu ništa; sada je isti
tutorijal na tabli bez dama.

Provera uživo: `TODO-provera.md`, stavka **140**.

---

## Snimanje glasa: faza 4, video u trenerovom glasu — 10.9.2026, nije viđeno uživo

U „Export video" prvi red je sada **„Use my recording (m:ss)"**, uključen kad
uređaj ima upotrebljiv snimak tog tutorijala. Aplikacija pita server koji snimak
ima (`GET /lessons/:id/narration`), šalje ga **samo ako server nema baš taj**, i
server crta film po markerima snimka: takt počinje tamo gde je trener pritisnuo
razmak, natpis se otkriva kroz vreme koje je stvarno proveo na tom taktu, a zvuk
se ubacuje kakav jeste. Provera uživo: `TODO-provera.md`, stavka **139** — ovo
je prva faza koju vlasnik može da pritisne, pa je i faza 3 tek sad vidljiva.

Snimak koji ne može da napravi ovaj film se **objasni umesto prekidača**
(nem, nedovršen, ili snimljen kad je tutorijal imao drugi broj taktova). Kad je
prekidač uključen, redovi za sintetizovani glas se ne crtaju — film nikad ne ide
sa oba glasa. Server na isto pitanje odgovara pre reda za renderovanje: nema
snimka, drugi snimak, drugi broj taktova, ili fajl nestao — četiri 409 sa četiri
rečenice, bez potrošenog slota.

Tri stvari vredi zapamtiti.

**Snimak je stajao pored koda koji briše zvuk.** Ruta za izvoz u `finally`
briše `narrationAudioPath` — sintetizovanu traku — kad se film nacrta. Da je
snimak prošao kroz tu promenljivu, jedan izvoz bi zauvek obrisao trenerov glas.
Ide samo kao `audioFilePath`, a test proverava da je fajl i dalje tu posle
izvoza; mutacija koja ga provlači kroz pogrešnu promenljivu pada.

**Dijalog koji čeka platformu je dijalog koji se ne otvara.** Prva verzija je
čekala da nađe snimak pre nego što otvori dijalog, a `path_provider` na Windowsu
pravi folder pravim asinhronim I/O-om, koji lažni sat widget testa nikad ne
pusti da se završi — dvanaest postojećih testova izvoza prestalo je da vidi
dijalog. Sada se dijalog otvara odmah, a red se pojavi kad stigne odgovor;
kasni odgovor posle zatvorenog dijaloga ne dira ništa (i to ima test). Slanje
čita fajl ceo, iz istog razloga.

**Dve mutacije bi preživele iz pogrešnog razloga, i nađene su pre pokretanja.**
„Nikad oba glasa" nije moglo da se vidi dok lažni server nije umeo da govori,
jer tada `narrate` ionako nikad nije u zahtevu; a „film u trenerovom glasu je
označen kao ozvučen" proveravao je jedini test koji šalje i `narrate: true`, što
zastavicu postavlja samo po sebi. Oba testa su popravljena pre nego što je
skripta pokrenuta, i svih 22 mutacija pada.

Otvoreno: faza 5 (potpis umesto broja taktova), i brisanje **lokalnog** snimka
kad se tutorijal obriše.

Brojke: **1846 u aplikaciji (1 preskočen), 1121 na backendu** sa `.env`
sklonjenim u stranu, `flutter analyze` na 29 info poruka; sve mereno jedno za
drugim, bez ičeg drugog pokrenutog.

---

## Snimanje glasa: faza 3, slanje na server — 10.9.2026, testirano, bez dugmeta

`POST /lessons/:id/narration` prima trenerov snimak, a
`LessonApiService.uploadNarration` ga šalje. **Ništa u aplikaciji još ne zove
slanje** — to radi opcija „tvoj snimak" u izvozu, koja je faza 4. Zato ovde nema
stavke za proveru uživo: nema dugmeta koje bi se pritisnulo.

Tri odluke vlasnika od 10.9.2026: server čuva **wav kako je snimljen**; klon
tutorijala **počinje bez glasa**; jedan snimak je najviše **15 minuta**. Vlasnik
se sećao dogovora da se ograničenje od 300 s promeni — u dokumentima je
zapisano nešto drugo: korak 5 drugog dela plana (render izlazi iz zahteva), koji
plafon ukida umesto da ga pomera, i koji nije urađen. Kad bude, ograničenje od
15 minuta nema više razloga. Aplikacija sama zaustavlja snimanje sekund pre
toga, jer zvuk stiže u celim paketima.

**Server čita fajl, a ne opis fajla.** Format i dužina iz zaglavlja wav-a
(`wav.js` je dobio `wavInfo`; `ffprobe` bi pročitao isto zaglavlje, drugim
procesom), nivo iz samih uzoraka. Markeri moraju da počnu od 0, samo da rastu,
da se završe pre kraja zvuka i da ih bude koliko i taktova. Odbijen fajl se
briše. **Ko sme da snima pita se pre nego što multer primi ijedan bajt** —
`mayRecordNarration`, isto pravilo kao u sobi: 18 godina, a nepoznata godina je
odbijanje. Red u bazi se piše pre nego što se stari snimak obriše, a brisanje
tutorijala briše i snimak.

Tri stvari vredi zapamtiti.

**`uploads/` je javan, i to od ranije.** `server.js` ga služi preko
`express.static`, bez prijave — ko zna ime fajla, skida snimak iz sobe.
Snimci glasa za tutorijale su zato u `uploads/narration/`, koji se nikad ne
služi (`middleware/uploadsStatic.js`); ostatak je zaseban zadatak, predložen
kao posebna sesija.

**Test koji šalje URL preko `fetch` ne vidi `..`.** WHATWG URL razreši `.` i
`..` (i `%2E%2E`) pre nego što zahtev ode, pa je mutacija koja briše
normalizaciju putanje preživela. Test sada šalje putanje doslovno kroz
`http.get`, i tek tada mutacija pada.

**Tri mutacije se nisu ni primenile**, jer `routes/lessons.js` ima Windows
kraj reda, a regex je tražio `\n`. „NOT APPLIED" nije „caught" — skripta to
razlikuje, i zato je to uopšte primećeno.

Otvoreno: **brisanje naloga mora da obriše snimke.** Ruta za brisanje naloga
danas ne postoji (`DELETE FROM users` je samo povratak neuspele registracije),
ali `saved_lessons` se briše kaskadno sa nalogom, a kaskada ne briše fajlove.

Brojke: **1836 u aplikaciji (1 preskočen), 1114 na backendu** sa `.env`
sklonjenim u stranu; obe mereno jedna za drugom, bez ičeg drugog pokrenutog.

---

## Snimanje glasa: faze 1 i 2 — 10.9.2026, nije viđeno uživo

Trener u studiju pritisne ikonicu mikrofona (samo na **sačuvanom** tutorijalu,
kao i „Export video"), pritisne „Record" i priča; razmak postavlja sledeći
takt. Tabla i rečenica tog takta stoje pred njim kao sufler, a red „Next: …"
kaže šta će razmak postaviti. Posle „Stop" snimak ostaje **na uređaju**, i
„Listen" ga pušta dok tabla prati glas. Slanje na server je faza 3 i nije
početo. Provera uživo: `TODO-provera.md`, stavka 138.

**Marker je broj bajtova ÷ byte rate, nikad sat na zidu** — to je odgovor faze
0 i sad je kod. Zagrevanje mikrofona i pauze zato ne pomeraju ništa: pauza
zaustavlja i zvuk i sat, a takt pomeren tokom pauze pada tačno na šav. Utišan
mikrofon se čita iz samih uzoraka (prag −70 dBFS naspram izmerenih −91) i ekran
to kaže posle tri sekunde **zvuka** bez ičega, dok se snima — ne posle sat
vremena pričanja.

Gde je šta: jezgro je `services/narration_take.dart` (bez plugina i widgeta),
plugin je `record_pcm_source.dart`, ekran `tutorial_narration_screen.dart`.
`filmBeatsOf` je izvučen iz `tutorialVideoOf`, pa film i snimanje čitaju **jednu**
šetnju tutorijala — marker `i` je događaj `i` po konstrukciji, a ne zato što se
dve petlje danas slažu.

Tri stvari vredi zapamtiti.

**`await` na `StreamSubscription.cancel()` visi pod lažnim satom widget testa.**
Budućnost koju vraća već je završena u root zoni, i pod `fake_async` nastavak
nikad ne dođe — „Stop" i „Discard" su visili u četiri testa ekrana, dok su
jedinični testovi jezgra prolazili jer nemaju lažni sat. Otkazivanje deluje u
trenutku poziva, pa se ne čeka.

**Četiri straže su obrisane jer nijedna nije mogla da padne**, i sve je našla
mutacija: provera stanja u `_onChunk` (pretplata je već otkazana pre nje),
`existsSync` u `load` (otvaranje fajla koji ne postoji baca, i `catch` već
odgovara), te `ExcludeFocus` i `requestFocus` oko dugmadi. Za poslednje dve
odgovor je dala **proba**, a ne zaključivanje: prečica za razmak stoji iznad
svih kontrola pa je čuje pre fokusiranog dugmeta, a kad dugme „Record" nestane
sa fokusom na sebi, opseg sam vraća fokus čvoru koji ga je imao pre. Test „take
started from the keyboard" ostaje — on ne dokazuje `requestFocus`, nego
`autofocus`, bez koga ne bi bilo prethodnog čvora, i pada kad se `autofocus`
obriše.

**Snimak na disku ima svoje ime, a indeks ga imenuje.** Novi pokušaj se snima
pored starog, `take.json` se zameni, i tek onda se stari zvuk briše; pri
čitanju se indeks proverava prema dužini samog wav-a. Neslaganje se prijavljuje
kao **izgubljen** snimak, ne kao da ga nema — izgubljen snimak prijavljen kao
uspeh je najstariji oblik greške u ovom repozitorijumu.

Otvoreno: faza 3 (slanje, `ffprobe` na serveru, odbijanje nemog snimka), faza 5
(potpis umesto broja taktova — sad se hvata samo dodat ili obrisan takt), i
**brisanje lokalnog snimka kad se tutorijal obriše iz biblioteke**, što još ne
postoji. Alat `tool/spike_recorder` se čuva do provere uživo.

Brojke: **1832 u aplikaciji (1 preskočen)**, mereno na `master` bez ičeg drugog
pokrenutog — 1790 + 28 testova jezgra + 14 testova ekrana. Backend nije diran
(1098). `flutter analyze` na 29 info poruka, bez upozorenja.

---

## ODAKLE SUTRA — 10.9.2026, video i snimanje

**Sutra počinje faza 1 iz `docs/PLAN-SNIMANJE.md`** — ekran za snimanje u
studiju, markeri sa audio clock-a i lokalno preslušavanje. Faza 0 je zatvorena
noćas i njen odgovor je jednoznačan; ne treba je ponavljati.

### Šta je odlučeno u fazi 0, da se ne otvara ponovo

`record` 7.1.1, `startStream` sa `AudioEncoder.pcm16bits`, 16 kHz mono, i
**marker = bajtovi ÷ byte rate**. Paket **nema nijedan API za poziciju**, pa ono
što je plan zvao rezervnim rešenjem jeste rešenje.

Izmereno na Androidu 15 i na Windowsu 11, sa glasom vlasnika:

* zagrevanje mikrofona: 750 ms na Androidu; na Windowsu **668 ms pa 100 ms** —
  ista mašina, isti kod, par minuta razmaka. **Nije konstanta**, pa se ne može
  ispraviti fiksnim pomerajem; zato je jedino ispravno čitanje ono iz samog
  zvuka.
* `pause()` zaustavlja i zvučni sat: 0 bajtova posle pauze na Windowsu, jedan
  paket (80 ms) na Androidu.
* posle jedne pauze od tri sekunde zidni sat je **2,6 s (Android) odnosno
  3,0 s (Windows) ispred** i tu ostaje — to je tačno greška koju bi svaki
  marker uzet iz `DateTime.now()` nosio do kraja snimka.
* `ffprobe` se tri puta složio sa bajt-satom **u milisekundu** (12480/12.480000,
  11928/11.928063, 12008/12.008063).

Dve stvari koje su koštale vremena i neće ponovo:

**Windows traži Visual Studio Build Tools 2022.** `record_windows` hoće CMake
3.23, a Build Tools 2019 nose 3.20 — i dok je zavisnost u `pubspec.yaml`, **pada
ceo Windows build**, ne samo plugin. Posle instalacije 2022 prvi build i dalje
pada na starom CMake kešu („generator Visual Studio 17 2022 does not match …
16 2019"); briše se `build/windows` i to je cela popravka.

**Sat radi i kad zvuka nema.** Windows snimak je bio savršena tišina (−91 dB) uz
besprekoran bajt-sat, tačan wav zaglavlje i tačan `ffprobe` — mikrofon je bio
mutiran na nivou sistema, a ništa to nije reklo: `hasPermission` je vraćao
`true`, uređaj je bio na spisku, paketi su stizali. Snimanje kroz `ffmpeg`
(DirectShow, bez Fluttera) dalo je istu tišinu. Zato faza 2 dobija pravilo:
gledati `onAmplitudeChanged` tokom snimanja, reći kad se ništa ne čuje, i
odbiti slanje snimka koji nikad nije prešao prag tišine.

`chess_app/tool/spike_recorder/main.dart` se sam pokreće i sam izlazi; čuva se
dok faza 1 ne bude gotova, jer je to način da se Windows strana ponovo proveri
posle svake promene alata.

### Šta je od danas u kodu, a nije viđeno uživo

Sve četiri stvari su merene i testirane, nijedna nije gledana kako radi:

1. **Prekid napuštenog rendera** (stavka 134). Klijent ode, crtanje staje,
   ffmpeg i piper se ubijaju, polufajl se briše, slot se vraća **odmah**.
   Lokalno provereno pravim socketom; na dropletu vezu zatvara nginx i to je
   jedini deo koji lokalno ne može da se proveri.
2. **Pregled pre renderovanja** (stavka 135) — tri slike, bez ffmpeg-a, bez
   mesta u redu, bez kvote.
3. **Tutorijal pamti svoj film** (stavka 136) — jedan video po tutorijalu,
   dugme za preuzimanje na redu u „Sačuvani tutorijali", svež link na zahtev.
4. **Pravednost reda** (stavka 137) — round-robin po nalogu i najviše dva filma
   po nalogu. **Ovo je bio živ kvar**: jedan trener sa tri izvoza je punio red i
   svi ostali su dobijali 429.

Za proveru postoje gotovi fixture-i u `mislisha-test/render-fixtures` (README
tamo ima izmerene brojke i dva PowerShell skripta).

### Brojke na `master` na kraju dana

**1790 u aplikaciji (1 preskočen), 1098 na backendu** sa `.env` sklonjenim u
stranu, `flutter analyze` na 29 info poruka bez ijednog upozorenja. Zavisnost
`record` je unutra i Windows build prolazi sa njom.

### Šta nije rađeno i zašto

Tačke 4 i 5 iz `PLAN-SNIMANJE.md` (odbijanje prevelikog rendera i izlazak
rendera iz zahteva) **nisu počete namerno** — 5 traži posao kao red u bazi, a 4
bez 5 je privremena mera. Deljenje velikog filma na delove i odloženo („noćno")
renderovanje idu uz njih. Redosled i zavisnosti su u tom planu, deo drugi.

---

## ODAKLE SUTRA — 8.9.2026, kraj dana

**Prvo pročitati `docs/PLAN-ZAVRSNICA.md`.** To je zamrznut obim za završetak
projekta, sa šest faza i četiri izričita izuzeća, i sve ispod je stanje unutar
njega.

### Gde smo

| | |
|---|---|
| aplikacija | **1762 testa, 1 preskočen** |
| backend | **964 testa**, sa `.env` sklonjenim u stranu |
| `flutter analyze` | 29 `info`, nijedno upozorenje, nijedna greška |
| grana | `master`, pushovana 8.9.2026 |
| srpski u `lib/` | **nema ga** — `gate_english_ui` čist nad svih 258 fajlova |
| srpski na serveru | **nema ga u rečenicama koje idu na ekran** — 66a i 66b, 71 fajl; ostaju logovi, komentari, `routes/consent.js`, roditeljski mejl i vrednosti uloga |

Faza 1 (zamrzavanje + dva reza) i faza 2 (jezgro videa) su gotove, i
**engleski zaokret je zatvoren 8.9.2026**: batch-evi 62–65b spojeni, `docs/gates/`
prazan, srpska sidra obrisana. Sledeće je **faza 4 — priručnik i sajt**, na
engleskom, pisan po glosaru.

Nedovršeno iz faze 2 i dalje stoji: renderer ne crta natpis, strelice ni polja.
To je batch koji dolazi posle priručnika ili pre njega, po izboru.

### Šta je odlučeno danas i ne otvara se ponovo

1. **Aplikacija ide isključivo na engleski**, bez i18n sloja — zamena u mestu.
   Ugovor je `docs/GLOSSARY-EN.md`.
2. **Tutorial** je ono što trener piše; **Session** je živi susret u sobi.
   Nikad „Lesson" na ekranu — u kodu ta reč znači artefakt (`saved_lessons`,
   `LessonStep`).
3. **Trainer**, ne Coach. Šema kaže trainer u svakom identifikatoru.
4. **Tekst se obraća igraču, učeniku i treneru — nikad detetu**, osim gde je
   funkcija izričito o roditeljskom nadzoru.
5. **General Audience, 13+**, ne „namenjeno deci". Ispod 13 nema naloga —
   `MINIMUM_AGE` odbija na ruti i na ekranu i **ne upisuje godinu**.
   Roditeljski tok time pokriva 13–15 u zemljama sa pragom iznad 13.
6. **Ekrani**: Room, Preparation, Analysis, Tutorial Studio. Reč „studio"
   imenuje jedan ekran.
7. `docs/politika-privatnosti.md` ostaje srpska i netaknuta; engleska je nov
   fajl (`docs/privacy-policy-en.md`) u fazi 4; advokatska provera je
   **eksterna kapija na izlasku**.

### Šta je sledeće, po redu

**Batch 65 je podeljen na tri dela, i prvi je već gotov.** Merenje 8.9.2026:
516 linija u 87 fajlova — trostruko više nego batch 64, koji je sa 26 fajlova
istrošio ceo budžet. Podela ide po rečniku, ne po veličini.

**Gotovo — vođin deo, commit `b694d3b`.** `core/services/tactical_motif_detector.dart`
i `core/services/positional_evaluator_service.dart` (28 literala) nisu tekst nego
**generator rečenica**: rod po figuri, nominativ i akuzativ za svaku, genitiv za
pridev boje, tri oblika množine za broj, i srpsko nabrajanje sa „i". Engleski ne
traži ništa od toga, pa je mašinerija obrisana a ne prevedena. Isto pravilo kao
batch 59 i 61: batch kome se da fajl koji traži refaktor je batch koji ima na
čemu da pogreši. Suite ostao 1772, analyze 29.

Iz njega jedna lekcija koja važi za oba preostala batch-a: **pet asercija u
testovima nije imalo nijedno naše slovo** — `contains('Beli')`,
`contains('otvorenu')`, `contains('je otvorena')` — pa ih `gate_english_ui`
nikad ne bi imenovao; našao ih je samo suite. Kad se menja string, grepuje se
**stara srpska reč**, ne dijakritik.

**Gotovo — batch 65a, spojen kao `c93deb8`.** 29 fajlova, 268 linija
(`features/analysis_studio`, `widgets/ai_studio`, `features/position_scanner`),
plus 17 test fajlova. **Svih jedanaest kapija zeleno iz prve runde**, prvi put u
ovoj seriji; 48 minuta od 75. Premereno na `master` bez ičega drugog u pozadini:
1772 testa i 1 preskočen, 29 `info`, nula upozorenja i grešaka, i tačno **220
srpskih literala** ostalo u `lib/` — što je do slova obim 65b, pa batch nije
izašao iz svog spiska.

Tri stvari iz njega. **Kad batch dodiruje jedan kraj rečnika čiji je drugi kraj
već napisan, taj napisani kraj se prepisuje u brief** — brief je nosio drugu
tabelu od 21 termina koji su **već otišli u kod** (fork, pin, skewer, outpost,
bishop pair…), jer dva panela imenuju iste motive koje generator rečenica
ispisuje; sva 21 su se vratila tačna. **Prevod ume da proširi matcher a da to
niko nije odlučio** — `contains('slika')` nije podniz od `slike`, ali
`contains('image')` jeste podniz od `images`; mutacija (zamena dve klasifikacije
skenera) i dalje pada, na susednom testu, pa nije menjano — ali to je rekla samo
mutacija. I **test za množinu se preimenuje, ne skraćuje**: `gamesLabel` je
zadržao svih osam ulaza, pa brojka nije pala kao kod batch-a 64.

**Treći izveštaj zaredom sa tačnim brojevima i izmišljenom sekcijom.** Sekcije
5.3 i 5.5 citiraju rečenice kojih nema ni u diffu ni u stablu — poruka skenera o
„slabom osvetljenju ili mutnoj slici" za funkciju koja čita **dijagrame složene
fontom, nikad sliku**, i četiri izmišljena imena otvaranja pored četiri prava.
Sekcija 3 je podmuklija i poučnija: njena tabela po fajlu je poštena računica
(zbir 558 je tačno `git diff --numstat` dodatih linija) pod pogrešnim imenom
(„prevedeni literali"), gde je pravi broj 268. **Tačan broj pod lažnim imenom
teže se hvata od izmišljenog.**

**Sledeće — batch 65b**, ostatak, 54 fajla i 220 linija: `features/archive` (59),
`lib/widgets` van `ai_studio` (52), `features/groups` (24), `lib/services` (29),
`features/trainer_panel`, `library`, `reviews`, `theme`, `routing`, `core`.
Brief se piše po uzoru na 65a.

Uz 65b ide i jedno čišćenje: **`lib/core/services/serbian_plural.dart` više
nema nijednog pozivaoca u `lib/`** — briše se sa svoja dva test fajla kad ode i
poslednji srpski.

**Kad 65b prođe:** oba sidra iz `docs/gates/` (`vocabulary_en_test.dart`,
`screen_names_en_test.dart`) prelaze u `test/`, a srpski `tutorial_vocabulary_test.dart`
i `screen_names_test.dart` se brišu. Tek tada počinje **faza 4 — priručnik i
sajt**, na engleskom, pisan po glosaru.

Posle toga: **faza 5** (trijaža 1037 stavki provere u tri gomile — zastarelo,
viđeno, stvarno neprovereno) i **faza 6** (objavljivanje).

Nedovršeno iz faze 2: renderer još ne crta natpis, strelice ni polja — to je
batch koji dolazi posle prevoda. Jezgro (`tutorialVideoOf`) je gotovo i
gejtovano.

### Šta o workeru mora da se zna

**Dva runda su izgubljena na workera koji je ponavljao „čekam da se testovi
završe", i uzrok je sada utvrđen — bila je mreža.** Prvo je zapisano kao
„`gemini-3.8-flash-high` ne ume da čeka potproces"; vlasnik je to ispravio
8.9.2026 — pala mu je internet konekcija. **Batch 65a je presudio istog dana**:
ispisuje istih devet „pustio sam ceo suite i čekam" rečenica — i onda se vrati
sa brojem, za 48 minuta od 75, sa svih jedanaest kapija zelenih. Na ispravnoj
vezi model sasvim uredno čeka potproces. Pouka je o vođi, ne o workeru: **zastoj
ima i okruženje a ne samo model, a imenovati model je jeftinija priča, ne i
verovatnija.**

Ono što ne zavisi od toga koje je tačno: **batch se brifuje tako da mu treba
najviše jedno puštanje celog suite-a, na kraju.** Batch 64 je dobio nalog da
pusti testove posle svakog od dvadeset šest fajlova, a dvadeset šest puštanja
po tri minuta je sedamdeset osam — više od celog budžeta, pre nego što model
išta pomisli. Taj nalog je bio moj i povučen je zbog računice, ne zbog
dijagnoze.

Persona za prevod je `flutter_translator` (`.agents/agents/`), napisana jer
`flutter_copy_sweeper` traži tabelu odlučenih zamena a `flutter_feature_builder`
sme da dira srpski tekst.

**Dozvole se pišu pre puštanja**, u `orchestrate.py`: `untracked` za izveštaj po
imenu i `translated` za svaki fajl pojedinačno. Peti put da `worktree` obori
posao koji je task sam tražio.

**Izveštaji su dva puta imali tačne brojeve i po jednu izmišljenu sekciju.**
Ocenjuje mašina; izveštaj je dokaz koji se čita, ne presuda.

### Nove kapije u harnessu (van repoa, `mislisha-test/orchestrator`)

* `english ui` — nijedno naše slovo u literalu pod `chess_app/lib`.
* `npm test` — backend suite sa `.env` sklonjenim, preskače se kad batch nije
  dirao `chess_backend/`.
* `gate_strings` ima `allow_translated` — jedina dozvola koja se sklanja umesto
  da preusmeri.
* `gate_contrast` sada uzima `baseline` i ne naplaćuje linije koje batch nije
  napisao.

### Glas je posle zaokreta bio nem — popravljeno 8.9.2026

`SpeechService.preferredLanguages` je i posle prelaska na engleski tražio
`['sr', 'hr', 'bs', 'sh', 'me']`, a nikad ne pada na nesrodan jezik — namerno,
jer engleski glas koji čita srpski ne pukne nego zvuči kao da funkcioniše.
Posledica: na običnoj engleskoj mašini stanje je `noVoice`, pa **nijedno dugme
za čitanje naglas u aplikaciji ništa ne kaže**, uključujući pripovedanje
tutorijala. Sada traži `en`, a `fitsSerbian` je `fitsAppLanguage`.

**Nijedan test to nije mogao da vidi, i to je pouka.** Svaki test u
`speech_service_test.dart`, `lesson_narration_test.dart`,
`govor_na_panelima_test.dart`, `tutorial_branching_test.dart` i
`phase0_widgets_test.dart` dodavao je servisu lažni motor koji prijavljuje
`['sr-RS']` — pretpostavka je bila ušivena u fixture. Najjači primer je
`VoicelessTts`, koji je vraćao `['en-US']` **da bi značio „nema glasa"**; sada
vraća `['de-DE']`. Nađeno je po log liniji u ispisu jednog test rana
(„Nema srpskog glasa. Instalirano: en-US"), a ne po testu.

Vlasnikovo pravilo, zapisano doslovno jer određuje oblik: *drugi jezik može da
bude samo mesto koje je korisnik napravio — repertoar, tutorijal, komentar. Ako
se to čita kroz TTS, ne sme kroz `en-*`, nego kroz servis za taj jezik. Srpski
nam nigde ne treba po defaultu.* Polovina po defaultu je gore popravljena;
polovina po artefaktu je **svesno odložena** i upisana u
`docs/PLAN-ZAVRSNICA.md` — današnji odgovor je izbor glasa u Podešavanjima,
koji važi za sve odjednom.

Suite 1773 (jedan test više nego 1772: dva stara slučaja o srpskom glasu
zamenjena sa tri o engleskom), analyze 29.

### Server je progovorio engleski — batch 66a, 8.9.2026

Vlasnik je na čistom buildu pročitao „učenik 2 želi da vas upiše kao
učenika". **Server šalje rečenice na ekran**, a svaki brief u ovom zaokretu je
govorio „ne diraj chess_backend" — što je bilo tačno za te batch-eve i to je
ovo sakrilo. Merenje: 847 srpskih linija u 79 produkcionih fajlova.

**66a je spojen** (`a5fc057`): 30 fajlova, 278 literala, 9 backend testova.
`npm test` 964, `flutter test` 1762 — oba nepromenjena.

### I šahovska polovina — batch 66b, 9.9.2026

**66b je spojen** (`8218c59`): 41 fajl, 466 linija, 12 test fajlova, svih
dvanaest gate-ova zeleno iz prve. `npm test` 964, `flutter test` 1762 sa jednim
preskočenim, analyze 29 — sve nepromenjeno, jer batch nije dirao Dart.
**Time nijedna srpska rečenica više ne postoji nigde odakle server može da je
pošalje na ekran.**

Brojka „281 linija u 41 fajlu" iz prethodnog pasusa **bila je pogrešna** i
ispravljena je pre briefa: nije brojala ni `.mjs` fajlove (skener je ESM, jer
pdfjs nema CommonJS build) ni bilo šta unutar template literala koji se prelama
u više redova. Tačna mera je 466 linija — 331 u jednorednim literalima i 135
unutar sedam prelomljenih šablona.

**Tri fajla nisu bila prevod.** `geminiService.js` je izgubio parametar
`userLanguage = 'sr'` i svaku `isSr` granu — engleska aplikacija je tražila od
modela srpski, i sama slala `'sr'` kao podrazumevano; oba prompta su sada
engleska i traže engleski. `services/prepNarrative.js` je prompt iza kojeg stoji
`narrativeGuard`, pa je svaki broj i svako pravilo o procentima prenet doslovno.
`services/endgameCatalog.js` je bio gramatička mašina — nominativ, genitiv i
množinska osnova, jer srpski traži padež posle „protiv"; engleski traži množinu,
pa se dve tablice spajaju u jednu i `labelOf('KRPPvKR')` sada čita
`rook and two pawns versus rook`. Nijedan ulaz iz testa nije izgubljen, samo su
očekivanja preimenovana.

**Tri niske su bile ugovor sa aplikacijom, ne tekst, i vođa ih je pomerio
unapred** (`9b786a2`), u istom commitu sa oba kraja: `reason` iz
`customPuzzleJudge.js` (aplikacija poredi „drugi mat, ali mat", a *netačne*
verdikte crta detetu doslovno) i tri vrednosti `sideSource` iz
`positionScanner/verify.mjs` (`needsReview` gori na `'nepoznato'` — prevod te
jedne reči prestao bi da označava svaku poziciju kojoj se ne zna strana na
potezu, tiho, uz zeleno oba paketa testova).

**Dve pouke o harnessu iz ovog batch-a:**

* `gate_english_backend` je gledao `` `[^`
]*` `` — bez novog reda — pa
  **prelomljen template literal nije video uopšte**. Tri najveća srpska bloka u
  66b su baš takvog oblika: HTML roditeljskog izveštaja (55 redova) i dva
  prompta (36 i 23). Popravljeno i dokazano mutacijom u oba smera.
* `test/repertoire_route_wiring.test.js` čita rute kao tekst i nije umeo da
  razlikuje parametar od reči u poruci. Batch je oboren zbog ispravne engleske
  rečenice „Could not read color status." u `/color` ruti i **preformulisao je
  poruke da prođe** — a gori je lažni prolaz koji je tu stajao od početka:
  parametar koji se pročita iz zahteva i nigde ne prosledi računa se kao
  upotrebljen čim ga bilo koja poruka pomene, što je tačno bug zbog kojeg taj
  fajl postoji. Popravljeno (`bccc04e`), dokazano mutacijom, poruke vraćene.

**Tri stvari su trajno van obima, sa razlogom:** `routes/consent.js` i
roditeljski mejl u `services/mailService.js` nose formulaciju koju je advokat
odobrio za Srbiju 25.8.2026 — engleska verzija je dokument iz faze 4 sa
spoljnom proverom; `db.js` je šema; a **vrednosti uloga** (`'trener'`,
`'ucenik'`, `'korisnik'`, `'host'`, `'admin'`, `'user'`) žive u CHECK
ograničenju baze i aplikacija grana po njima na 25 mesta. Preimenovanje toga je
migracija kroz šemu, server, socket i aplikaciju — nije prevod.

**Što batch ne može da popravi, i rečeno je unapred:** `user_notifications` je
tabela, pa su poruke sa vlasnikovog snimka **već upisani redovi**. Prevod
generatora menja šta se piše od sada i ništa što postoji. Briše li se to —
vlasnikova odluka, ne posao batch-a.

### Tutorijal je postao video — faza 2 zatvorena, 9.9.2026

**Sva četiri dela faze 2 su gotova.** Jezgro (`tutorialVideoOf`, `dwellSecondsFor`)
je bilo gotovo ranije; 9.9.2026 su došla preostala dva.

**Renderer crta ono što se uči** (`401ad0f`, vođa). `videoRenderer.js` sada prima
`caption`, `arrows`, `squares` i `orientation` po događaju. `[%csl]` se crta kao
ista tri prstena kao u aplikaciji — crni oreol, beli oreol, boja — jer to je ono
što se čita i na svetlom i na tamnom polju, a puno polje bi sakrilo figuru o
kojoj se priča. Pet boja je prepisano po vrednosti iz `arrow_colors.dart`, a
nepoznat kod ostaje siv: zeleno ovde **znači** nešto.

**Traka za rečenicu meri se jednom za ceo film** i tabla se smanjuje oko nje —
visina po kadru bi tablu terala da raste i da se smanjuje između dve rečenice.
Film bez ijedne rečenice ne rezerviše ništa i dobija geometriju koju je renderer
oduvek crtao; izvoz snimka je proveren uživo i ne sme da se pomeri ni za piksel.

**Dva kvara su bila u svakom ikada renderovanom izvozu**, i našao ih je jedan
probni kadar: naslov je nosio `♟`, koji nijedan font na tom serveru nema, pa je
svaki kadar prikazivao praznu kutijicu; i **nijedno slovo kolone nikada nije
nacrtano** — bila su obojena bojom polja na kome stoje, osam puta zaredom, jer
je parnost koja važi za redove obrnuta za kolone a izraz je bio jedan.

**Izvoz i vrata** (`0c9cb0f`, batch 67): `POST /lessons/:id/export-video` pored
izvoza snimka, i treća ikonica u spisku sačuvanih tutorijala. Ruta proverava
pravo pre bilo kakvog posla, razrešava red uslovom `(user_id = $2 OR trainer_id
= $2)`, seče trajanje na 3600 umesto da odbije, i knjiži potrošnju tek pošto je
render uspeo. Preuzimanje ide kroz **postojeću** rutu snimaka — jedno mesto koje
mora da brani `exports/` lakše je držati ispravnim nego dva.

Tri stvari iz ocenjivanja, dve od njih ispravke moje prve dijagnoze:

* Probni test na 360 dp našao je prelivanje od 88 px. **Pročitao sam ga
  pogrešno** kao tri ikonice u redu i zbio ih; merenje je pokazalo da je red bio
  u redu, a da se prelivao dijalog „Video ready!", čiji je naslov u headline
  veličini tražio 320 dp od telefonskih 232. Vidi se tek posle klika, pa ga
  nijedan test koji staje na redu ne može videti.
* **Naslov bez elipse zaista gura akcije preko ivice** — tutorijal se imenuje
  svojom prvom rečenicom, pa `'Opozicija'` nije bio pošten uzorak.
* **Test napisan za sve to nije dokazivao ništa, dvaput.** `takeException`
  prolazi i sa vraćenim prelivanjem; pitanje o redu u mirovanju promašuje
  dijalog do kog se stiže klikom. Sada meri da li je svako dugme unutar
  dijaloga, na redu sa dugim naslovom, i obe popravke su mutirane da se vidi
  kako pada.

Ostaje **provera uživo** — stavka 133 u `docs/TODO-provera.md`.

### Otvoreno, nije rađeno

* Tri pitanja o dizajnu iz prijava od 7.9.2026: orijentacija kao svojstvo niza
  taktova, jedan tip zadatka po taktu, i komentar pre *i* posle poteza.
* Prijava `n1788823148283`: organizacija ekrana. Uski zahvat je urađen (jedan
  dijalog, imena); širi — jedno mesto za sve što aplikacija proizvodi — je
  izričito van obima i odgovara mu priručnik iz faze 4.
* Nove stavke provere uživo: **123–133** u `docs/TODO-provera.md`. Stavka 132
  je najveća: 71 fajl prevedenog servera nije viđen na ekranu ni jednom.
  Stavka 133 je video tutorijala — renderovanje je dokazano, dugme nije.

---

## Jedan trener više ne zauzima celu mašinu — 9.9.2026

Bio je **živ kvar, ne budući**: sa `RENDER_CONCURRENCY` 1 i `RENDER_QUEUE_MAX`
2 staju tri renderovanja, pa je jedan trener sa tri pritiska na „Export" punio
red, a svi ostali su dobijali 429 dok se ne isprazni. FIFO ne zna ko pita.

Dva pravila, i odgovaraju na različita pitanja. **Round-robin** odlučuje o
redosledu: sledeći film je onog naloga koji najduže nije bio na redu — pa
dvanaest delova jednog velikog tutorijala ne mogu da preteknu kratak film koji
je stigao kasnije. **`RENDER_ACCOUNT_MAX`** (podrazumevano 2) odlučuje o
prijemu: dva filma po nalogu, jedan koji se crta i jedan koji čeka. Posao bez
naloga je sam sebi grupa, da ne bi slučajno blokirao nešto sa čim nema veze.

Tri stvari vredi zapamtiti.

**Broj koji trener vidi mora da bude broj koji se obistini.** Objavljivati
indeks u nizu bilo je tačno dok je red bio „ko pre devojci", i postalo je laž
čim više nije — mesto se sada računa igranjem pravila unapred nad kopijom reda.
Uz to, posao se obaveštava **samo kad mu se mesto stvarno promeni**.

**Dva odbijanja traže dve rečenice.** „Server trenutno renderuje druge videe" je
neistina kad su ti drugi videi tvoji; trener tako čeka pogrešnu stvar.
`RenderAccountBusy` je zato zaseban tip, i ruta na njega odgovara drugom
rečenicom.

**Mutacija je prijavila „preživela" a zapravo je visila.** Brisanje ograničenja
po nalogu ne obara treći render — ono ga *stavlja u red*, pa se `assert.rejects`
nikad ne razreši i fajl istekne. Svaki test odbijanja sada trka sa rokom. Drugi
put u jednom danu: test koji visi je gori od testa koji padne.

Brojke: **1098 na backendu**; aplikacija nije dirana.

---

## Snimanje glasa i red za renderovanje — plan, 9.9.2026

`docs/PLAN-SNIMANJE.md`, u dva dela. **Prvi**: trener sam snima svoj glas u
aplikaciji, klijent hvata markere **sa audio clock-a rekordera** (ne sa
`DateTime.now()`, jer to klizi progresivno), lokalno preslušava, i tek na izvoz
šalje gotov fajl — pa server samo muxuje kroz `ffmpegArgsFor`, bez pipera.
Snimak je vezan za potpis liste taktova (`treeSignature` obrazac), jer izmena
lekcije razvezuje markere u tišini. Piper ostaje kao fallback.

**Drugi deo** su tačke 4 i 5 sa iste liste — odbijanje renderovanja koje ne
može da stane u vezu, i izlazak rendera iz zahteva (202 + posao u bazi) — i
vlasnikov hibrid: odloženo renderovanje „preko noći", **deljenje velikog filma
na delove** (što daje tačke prekida, pa mali film čeka jedan deo umesto celog
filma) i **round-robin po nalogu**, jer danas jedan korisnik sa tri izvoza puni
red i svi ostali dobijaju 429.

---

## Tutorijal pamti svoj film — 9.9.2026

Pitanje vlasnika: „ako ne downloaduje odmah video, kako može to da uradi
kasnije?" Do ovoga — **nikako.** Token za preuzimanje traje trideset minuta,
link je postojao samo u odgovoru na izvoz i nigde se nije čuvao; ko zatvori
dijalog „Video ready!" morao je da renderuje ceo film ponovo, dok je fajl stajao
u `exports/` četrnaest dana, nedohvatljiv, dok ga retencija ne obriše. Deset
izvoza jednog tutorijala bilo je deset siročića.

`saved_lessons` sada nosi `video_filename`, `video_rendered_at`,
`video_resolution`, `video_seconds` i `video_narrated`, a `GET
/lessons/:id/video` **kuje svež link** kad neko pita. U aplikaciji je to ikonica
za preuzimanje na redu u „Sačuvani tutorijali", i crta se **samo tamo gde film
postoji** — akcija ponuđena na redu koji je ne može izvršiti je najčešća greška
u ovom repozitorijumu.

Četiri pravila iz toga:

**Ime fajla, ne URL.** URL nosi token, a sačuvan token je token koji nadživi
svoje isticanje: pola sata posle izvoza to je link koji vraća 401, čuvan
četrnaest dana.

**Red se upisuje pre nego što se stari fajl obriše.** Pad između to dvoje
ostavlja fajl na koji niko ne pokazuje — njega retencija pokupi; obrnut redosled
ostavlja red koji imenuje fajl kojeg nema, a to je trener koji pritisne
„Download" i ne dobije ništa.

**Retencija briše i novu kolonu.** Inače lista crta dugme na redu čiji je fajl
taj isti prolaz upravo obrisao, pa bi odgovor „film je obrisan" — koji postoji
za prozor između to dvoje — postao redovno stanje.

**Tri odgovora se razlikuju:** nema filma (404), film je bio pa ga je retencija
uzela (410, „izvezi ponovo"), ili evo ga (200). Vode trenera na različita
dugmad, pa ne smeju da glase isto.

Jedna pouka o starom testu: `retention.test.js` je tvrdio `queries.length === 1`
— tvrdnja o **obliku** prolaza, a ne o tome šta briše, i netačna čim druga
tabela zapamti ime fajla. Sada svoj upit traži po imenu.

Brojke: **1790 u aplikaciji (1 preskočen), 1090 na backendu.** Ostaje stavka
**136** u `docs/TODO-provera.md`.

---

## Pregled pre renderovanja — 9.9.2026

Pitanje vlasnika: „da li ima smisla uvesti preview da ne bi korisnik renderovao
samo da bi video kako izgleda video". Da, i to je najjeftinija stvar na spisku:
`renderFrameBuffer` crta jedan kadar **bez ffmpeg-a**, pa pregled ne troši ni
mesto u redu, ni fajl, ni kvotu.

`POST /lessons/:id/preview-frames` vraća do četiri PNG-a u base64. Podrazumevano
tri — početak, sredina i kraj — jer su to tri pitanja koja trener ima: kako film
počinje, kako izgleda običan takt sa rečenicom i strelicama, i gde ostavlja
dete. U aplikaciji je dugme **„Preview"** u dijalogu za izvoz, pored „Export":
tu je trener već izabrao rezoluciju i naraciju, pa je to jedino mesto gde
pregled odgovara na pravo pitanje.

**To nije drugo crtanje.** Isti `applyEvent` koji koristi petlja renderera, isti
`renderFrameBuffer`, isti raspored natpisa — inače bi pregled bio slika filma
koji niko neće dobiti.

Dve stvari koje su testovi našli, i obe su o tome šta test ume da vidi.

**Tri kadra su se razlikovala po satu, ne po tabli.** Mutacija „uvek crtaj takt
0" je prošla pored tvrdnje „kadrovi su različiti", jer sat u uglu piše 00:00,
00:04, 00:09. Dodat je test u kome svi taktovi imaju **isti** `timestampMs`, pa
je svaka razlika nužno pozicija. Ista porodica kao slova ispod table na koja su
odgovorile figure sa prvog reda.

**Komentar je tvrdio više nego što kod radi.** Napisao sam da je traka natpisa
„visoka koliko najduža rečenica u filmu"; `renderFrameBuffer` je čita samo kao
`captionBand > 0`. Pravilo koje stvarno postoji — i koje se testira — jeste da
se **takt bez teksta unutar filma koji govori** ipak crta sa kolonom za natpis.
Test koji je pao je ono što je našlo preterivanje.

Ostaje: stavka **135** u `docs/TODO-provera.md`.

---

## Render koji je klijent napustio se prekida — 9.9.2026

**Nalaz je izmeren, ne pretpostavljen.** Za brzo pravljenje velikih tutorijala
napravljen je set fixtura (`mislisha-test/render-fixtures`, u QA folderu van
gita) i format za LLM (`docs/PGN-TUTORIAL-FORMAT.md`). Sa njima su ispaljena
četiri istovremena renderovanja na lokalni backend, pa jedno preveliko sa
klijentskim tajmautom od 300 s — koliko nginx daje proksiranom zahtevu na
dropletu (`deploy/app-setup.sh`).

Red je odradio svoje: četvrti zahtev je odbijen za **0,9 s**, pre ijednog
nacrtanog frejma, a tri koja su stala u red su završila na 16,0 / 31,4 / 52,1 s.
Ali film od 36 minuta je pokazao rupu: klijent je odustao na 300,1 s, a **server
je nastavio da crta**, napisao MP4 od 14,4 MB čiji je link za preuzimanje bio u
odgovoru koji niko nije primio — i, što je gore, **držao jedini slot za
renderovanje do kraja tog filma**. Svaki drugi trener u tom prozoru čekao je iza
filma koji niko neće pokupiti, ili je dobijao 429.

To je tačno ona rečenica zbog koje `services/renderQueue.js` i postoji.
`RENDER_QUEUE_MAX` ograničava **red**; ne kaže ništa o jednom renderu koji
nadživi svoju vezu. Nigde u lancu nije bilo obrade prekinute veze — ni
`routes/lessons.js`, ni `renderQueue.js`, ni `videoRenderer.js`.

### Rešenje

`services/renderAbort.js`, jedan `AbortSignal` provučen kroz ceo lanac:

* `abortOnDisconnect(res)` sluša `res.on('close')` i pali signal **samo ako
  `writableFinished` nije tačno**. To je cela ispravnost tog mesta: i uspešan
  odgovor emituje `close`, pa bi slušalac bez tog pitanja gasio svaki render u
  trenutku kad uspe — bezopasno danas samo zato što tada ništa više ne radi.
* `videoRenderer` proverava signal na vrhu frejm-petlje (koja ionako popušta
  event loop jednom po frejmu), ubija ffmpeg sa **SIGKILL** i briše polufajl.
  SIGTERM ne valja: ffmpeg zamoljen lepo dovrši fajl koji ovo baš i sprečava.
* Narracija je unutar reda zajedno sa crtanjem, pa i ona mora da stane:
  `narrateFilm` → `tts.speakBeats` → `piper.run` ubija piper proces, a
  `narrationTrack` svoj ffmpeg; polu-napisan `.wav` u `exports/` se briše.
  `speakBeats` je do sada gutao svaku grešku sinteze (film bez glasa je i dalje
  film) — **prekid je jedini izuzetak**, jer bi inače nastavio da crta ceo nemi
  film za klijenta koga nema.
* Ruta ne šalje odgovor (socket je zatvoren), **ne knjiži potrošnju** i vraća
  slot. Trener nije dobio film, pa ništa nije ni naplaćeno.

Živa provera, pravi socket i pravi ffmpeg (`render-fixtures/abort-live-check.js`):
klijent prekida na 3,0 s, server javlja prekid na 3,5 s, fajl obrisan, red na
`{running: 0, waiting: 0}`, **sledeći posao krenuo za 0,00 s**.

### Šta su testovi pokazali, a šta nisu

`test/render_abort.test.js`, 11 testova, ffmpeg lažiran kao u
`render_yields.test.js`. **Backend suite: 1069, sve zelene**, sa `.env` sklonjen
u stranu (1058 pre ovoga). Aplikacija nije dirana.

Devet mutacija je uhvaćeno; dve su preživele i obe su nešto naučile.

**Dve provere u istoj petlji ne mogu da se dokažu.** Brisanje provere na vrhu
petlje ostavljalo je suite zelenim — jer je druga, pred samim upisom frejma,
zaustavljala render, i obrnuto. Ostala je **jedna** provera, koja sada pada na
mutaciju („5 frejmova u trenutku odbijanja, 12 sada"); cena je jedan frejm
viška kad prekid stigne usred crtanja. Provera koju nijedna mutacija ne može da
dosegne je provera za koju niko ne zna da radi.

**Prva verzija testa nije umela da vidi da petlja i dalje crta.** Brojala je
frejmove u trenutku odbijanja obećanja — a između `kill` i odbijanja prođu dva
turnusa, pa je i petlja koja prekid potpuno ignoriše tada tek nekoliko frejmova
dalje. Sada se broji dvaput, sa pauzom između.

**Test koji visi umesto da padne.** Mutacija „`killOnAbort` ne ubija" je
zaglavila ceo suite na 300 s bez ijedne poruke. Svako pitanje u ovom fajlu je o
tome da nešto **stane**, a to se kvari tako što se obećanje nikad ne razreši —
zato sada sve ide kroz `withDeadline`.

**Jedna zaštita nije dokazana i to je zapisano u kodu.** `ffmpeg.stdin.on
('error', …)` hvata EPIPE koji pravi ffmpeg digne kad se u njegov stdin upiše
posle `kill` — a `error` na streamu bez slušaoca ruši ceo proces. Lažni ffmpeg
ne ume da pukne kao pravi, pa mutacija koja tu liniju obriše prolazi. Ostaje,
jer je rizik nesimetričan: nedosežna zaštita košta jedan red, njeno odsustvo
košta proces. Živa provera je prošla bez pada.

**Dve postojeće fixture su proširene, tvrdnje nisu dirane.**
`render_yields.test.js` je imao lažni `stdin` bez `on`, a
`tutorial_video_export.test.js` lažni `res` bez `on`/`off` — prvi je visio 60 s,
drugi je vraćao 500 na svaku tvrdnju. Obe su dobile ono što pravi objekat
oduvek ima. („Prolazi bez izmene" je i dalje pogrešna formulacija: tvrdnje su
nepromenjene, fixture su se pomerile.)

### Ostaje

* **Prekid nad TTS lancem nije proveren od kraja do kraja** — traži instaliran
  piper; pokriven je konstrukcijom (`killOnAbort` + `throwIfAborted`), ne
  testom.
* Stavka **134** u `docs/TODO-provera.md` — živa provera na dropletu, gde je
  nginx taj koji zatvara vezu.

---

## Redizajn Studija za tutorijal — P0–P2 gotove, 6.9.2026

Dogovor je [PLAN-STUDIO-REDIZAJN.md](PLAN-STUDIO-REDIZAJN.md), napisan pošto je
vlasnik probao studio iz faza 4a–4c i prijavio četiri problema: ulazak iz
Analize nasleđuje tuđe stanje, postoje dva ekrana za isti posao, nema osećaja
hronologije, i stablo dole desno je skučeno i tehničko.

**Koren je jedan i nije u rasporedu.** Gotov primer se pri „Dodaj sledeću
poziciju" spljošti na `fen` + `pgn` i stablo se baci, a ništa u aplikaciji nije
umelo da pročita `pgn` nazad u `AnalysisNode`. Zato gotov deo nije mogao da se
ponovo otvori — i zato je drugi, slabiji ekran za izmene morao da postoji.
Uklanjanje drugog ekrana nije posao oko rasporeda nego jedan konvertor.

Vlasnik je 6.9.2026 usvojio plan u celosti i razrešio tri otvorene odluke:
**D6** — ostaju oba taba, „Tok" podrazumevan i „Stablo" kao alternativa;
**D7** — „Deo" je jedina reč u autorskim ekranima (stiže sa ekranom u P5, ne
pre, jer bi pomeranje stringova u P1/P2 pokvarilo jedini dokaz da tok nije
promenjen); **D9** — dugme nudi „Nastavi odavde (dete ne vidi novu tablu)" prvo
i podrazumevano, pa „Nova pozicija", uz spojnicu u listi delova.

### Šta je urađeno (P0–P2, sve lead)

* `lib/features/tutorial_studio/services/step_tree.dart` — prelaz sa `MoveNode`
  na `AnalysisNode`, plus `treeSignature`, `copyTree` i `endOfMainLine`.
* `tutorial_draft.dart` napisan iznova: `TutorialChoice`, `TutorialSection` (sa
  stablom, `stepId` i `acceptedSans`) i `TutorialDraft` (sa `lessonId`,
  `selected`, dodavanjem, brisanjem, premeštanjem i kloniranjem delova).
* `TutorialDraftService` čuva jedan objekat umesto nacrta pored radnog stabla, i
  i dalje ume da pročita **stari** oblik slota — trener koji nadogradi usred
  pisanja ne gubi ono što je napisao.
* Ekran je preveden na novi model, **bez ijednog pomerenog stringa za
  korisnika**. To je i dokaz: `test/tutorial_authoring_test.dart` prolazi.

### Merenja i kapije

Kapija je napisana **pre** rada i dokazana sa **sedam mutacija, sve uhvaćene**:
izbačene sporedne varijante (oblik
`_importPgn`), `stepId` prestao da putuje, `acceptedSans` izbačen, netaknuta
linija ipak ponovo izvezena, klon deli stablo umesto da ga kopira, poslednji deo
postao obrisiv, i rečenice trenera izbačene pri čitanju.

**1458 testova u aplikaciji, 1 preskočen, sve zeleno** (bilo 1436), izmereno na
`master`-u sa ničim drugim što radi paralelno. `flutter analyze` i dalje 29
info-a, bez grešaka i upozorenja, i **ništa novo nije prigušeno**. Backend nije
dodirnut i ostaje 956.

### Šta je rad otkrio, a plan nije predvideo

1. **Bajt-identičan povratni put je nemoguć ako se `pgn` uvek ponovo izvozi** —
   `PgnExporterService` upisuje svež `[Date]` u svakom pozivu. Zato se netaknut
   deo vraća kao *tačno onaj tekst koji je pročitan*, a keš se poništava
   poređenjem `treeSignature` sa samim stablom. Namerno nije `bool` zastavica:
   zastavica je verzija ovoga koja otkazuje nečujno.
2. **`acceptedSans` nije postojao u modelu** i to niko nije primetio, jer ništa
   nikada nije čitalo sačuvan korak nazad. Server ga čuva; povratni put bez
   njega bi obrisao trenerove dodatne tačne poteze prvi put kad preimenuje
   tutorijal. Našao ga je bajt-identičan test — zbog toga takav test i postoji.
3. **`pgn` se izostavlja, ne šalje kao `''`.** Serveru je isto (`if (pgn)`), ali
   samo izostavljanje vraća korak koji je sačuvan bez linije — bez linije. To
   izoštrava ispravku iz batch-a 54, ne poništava je.
4. **Kapija iz batch-a E je morala da se dopuni, i to je prošireno a ne
   ublaženo** — piše ovde jer je „prolazi neizmenjena" bila lead-ova sopstvena
   mera. Njen izvorni test je tražio `StudioLessonStep` u fajlu ekrana; P1 je taj
   poziv spustio u `TutorialSection`. Sada čita ceo direktorijum feature-a i pita
   za **import**, ne za identifikator — `contains` nad direktorijumom pogađa i
   komentar, pa bi ga oborio komentar koji objašnjava zašto se izvoznik tu *ne*
   zove.

### P3a — čuvanje, 6.9.2026

`commitDraft` i `LessonWriteResult`: prvi „Sačuvaj" je `POST`, svaki sledeći
`PUT` na isti tutorijal, sa `id`-jem svakog koraka u telu. Stare potpise
`save`/`update` namerno nismo dirali — tri zaštićene kapije lažiraju server tako
što **preklapaju `update`**, pa postoji jedna implementacija i dva oblika.

**Osam mutacija, i dve su razlog što ovo piše ovde.** Jedna je preživela —
„`markSaved` zaboravi sačuvan tekst" — i lako je bilo okriviti mutaciju. Test je
svoj deo napravio kroz `fromStep`, a takav deo je *već* netaknut, pa test nije
mogao da vidi razliku. Prepisan tako da deo pravi rukom, pao je na mutaciju **i
ostao crven** posle te popravke — i tu je izašla prava greška:

**Deo bez poteza nije slao liniju uopšte, pa se gubila beleška o početnoj
poziciji.** `pgnForSave` je sudio delu po broju poteza, a komentar, strelica i
obojeno polje o *mirnoj* poziciji žive na korenu — jedinom mestu gde mogu.
„Pogledaj polje d5" je ceo korak, i `PgnExporterService` je baš zato naučen da
taj komentar upiše ispred prvog poteza. Pisac ga je na izlazu ponovo bacao; dete
je dobijalo golu dijagramu i niko ništa nije rekao. Greška je starija od ovog
plana — nasleđena iz batch-a 54.

Pouka koja se prenosi: **preživela mutacija je pitanje, a ne presuda.** Kaže da
test ne vidi, a ono što ne vidi ponekad nije ono što si mutirao.

Sitnija, ali skupa: `http.Response(String, …)` kodira **latin1** ako tip sadržaja
ne kaže drugačije, pa lažni server nije mogao da ponese „Nađi potez." i pukao je
— a greška je stigla obučena kao „Nije moguće doći do servera.", mrežna greška za
bug u testu. Rečenice ovog servera su srpske; lažni server mora da ume da ih
nosi.

**1473 testa u aplikaciji, 1 preskočen, sve zeleno** (bilo 1458).

### P3b — zašto se ekran otvara, 6.9.2026

`TutorialEntry`, i ekran kome se **mora** reći zašto se otvara. Ovo je prijava 1.1
zatvorena u korenu: ekran je ranije uzimao neobavezan handover i bezuslovno
učitavao jedini slot za nacrt, pa su naziv i svi završeni delovi dolazili natrag
šta god trener tražio.

* **`blank(naziv)`** — ništa se ne preuzima. Ako u slotu nešto stoji, trener se
  pita **imenom**: „Prošli put ste pisali tutorijal „Opozicija“ (3 dela).“
  „Odbaci“ briše slot — nacrt koji je upravo odbijen ne sme da čeka sutra.
* **`saved(lekcija)`** — sačuvan nacrt se preuzima **samo ako mu se `lessonId`
  poklapa**. Nacrt drugog tutorijala je tuđ nedovršen posao: ostaje gde jeste i o
  njemu se ne pita.
* **`fromAnalysis(handover, intoOpenDraft:)`** — dosadašnje ponašanje, sada
  izričito.

**Pitanje sa vrata postavljaju — vrata.** Gde linija treba da ode pita Studio za
analizu, dok trener još gleda tu liniju, pa se odgovor prenosi u `intoOpenDraft`.
Same veze idu u P4; oba ponašanja već postoje i testirana su.

**Jedna postojeća kapija je promenila ono što tvrdi, i to je suština faze.** U
`tutorial_studio_test.dart` dva testa su ponovo otvarala ekran bez argumenta i
očekivala nacrt natrag — u tišini. Sada odgovaraju na pitanje koje ekran
postavlja; sve njihove tvrdnje su nepromenjene i nacrt se i dalje vraća.

**A `tutorial_authoring_test.dart` je tražio još jednu mehaničku izmenu** — jedno
mesto gde pravi ekran, jer se konstruktor promenio. Zajedno sa proširenjem iz P1,
pošteno pravilo glasi uže nego što je zapisano: **sve njegove tvrdnje su
nepromenjene i zelene; pomerila su se dva pomoćna mesta.** Alternativa bi bila
zadržati suvišan drugi način da se ekran otvori samo da se test ne pomeri.

**Pet mutacija, sve uhvaćene.** **1482 testa u aplikaciji, 1 preskočen, sve
zeleno** (bilo 1473).

### P4 — ulaz u studio, 6.9.2026, batch 56

Prvi posao u ovom planu koji je radio radnik (`gemini-3.8-flash-high` kroz
`agy`), jedna runda. Kapija je napisana pre posla — petnaest testova; četrnaest
zelenih iz prve, a petnaesti crven **zato što je bio lead-ov i tvrdio je
neistinu**. Sedam mutacija posle toga, sve uhvaćene.

„Biblioteka“ sada nosi karticu sa „Novi tutorijal“ i „Otvori sačuvani
tutorijal“, tamo gde studio postoji. `TutorialLibraryCard` drži ceo ulaz —
karticu, oba dijaloga i sve stringove — pa se pitanje o platformi rešava na
jednom mestu. Vrata iz Analize pitaju gde linija ide i prosleđuju odgovor kao
`intoOpenDraft`.

**Dva najbolja doprinosa te runde nisu kod.**

Radnik je **prijavio pokvarenu lead-ovu kapiju umesto da je zaobiđe** — što je
tačno ono što je zadatak tražio, i ono što batch 55 nije umeo. Test „pitanje o
platformi ima jedan dom“ izuzimao je `engine_settings_dialog.dart` na putanji
koja ne postoji, i pretpostavljao da je predikat jedino mesto u `lib/` koje pita
za Windows. Pitaju još četiri fajla, s pravom. **Kapija koja imenuje fajl koji
ne postoji ne može da se primeti tako što padne** — ova je primećena samo zato
što je tvrdila i nešto drugo što nije tačno. Sada nabraja šest poznatih domova i
pada na sedmi.

I **brojevi u njegovom izveštaju poklapaju se sa lead-ovim merenjima do
poslednjeg** — uključujući upozorenje analizatora koje je lead promašivao tri
faze.

Jednu odluku koju je brief ostavio otvorenu doneo je ispravno: `fetchAll`
odgovara `[]` i kad je prazno i kad je puklo, a brief je rekao „ako ne možeš da
ih razlikuješ, prijavi“ — što je lead-ov problem ostavljen u briefu. Dodao je
`lastFetchFailed` po uzoru na `cloneError`, koji je imenovan u doc-u te iste
klase: aditivno, bez promene potpisa, nijedan pozivalac nije dirnut.

Lead je posle popravio tri greške koje nijedna kapija ne hvata: nedisponovan
`TextEditingController` u dijalogu za naziv (i **prva lead-ova popravka bila je
gora od greške** — `showDialog` završava na `pop` dok se ruta još animira, pa
`TextField` puca na disponovan kontroler; sada je mali `StatefulWidget`),
razmak koji je pripadao kartici a ne tabu (na telefonu je ostavljao 24 px praznog
prostora na vrhu „Biblioteke“, gde kartice nema), i suvišan
`identical(rawRows, const [])` pored `lastFetchFailed`.

### Tvrdnja o analizatoru koju su P0–P3 promašile

**„29 info-a, bez grešaka i upozorenja“ napisano je tri puta i nije bilo
tačno.** P1 je ostavio neiskorišćen import u `tutorial_studio_test.dart`, i
analizator je od tada prijavljivao upozorenje.

Provera nije mogla da ga vidi: `flutter analyze | grep -cE "^\s+(info|warning|error)"`
— a `flutter analyze` uvlači `info` linije za tri razmaka, dok `warning` piše od
**nulte kolone**. `\s+` traži bar jedan razmak, pa je obrazac brojao 29 info-a i
to proglašavao celom listom: **provera koja ne može da padne nije provera.**
Harness koristi `\s*` i uhvatio ju je na prvoj sledećoj rundi; radnikov izveštaj
je to upozorenje prepisao, stavku po stavku, na vidnom mestu.

Ista porodica kao odsecanje tela funkcije na 1600 znakova i kapija koja je
poklapala komentare. Popravljeno u `30b5fcc`. Sažetak koji `flutter analyze` sam
ispiše — „30 issues found“ — rekao bi to bez ikakvog obrasca.

**1497 testova u aplikaciji, 1 preskočen, sve zeleno** (bilo 1482). 29 info-a,
nula upozorenja i grešaka, mereno obrascem koji ume da ih vidi.

### P5a — panel „Delovi tutorijala", 6.9.2026, batch 57

`gemini-3.8-flash-high`, `flutter_feature_builder`, jedna runda, 24 minuta.
Devet kapija zeleno. **1515 testova u aplikaciji, 1 preskočen** (bilo 1497);
backend nije diran i ostaje na 956.

Ekran koji piše tutorijal do juče je umeo samo da **dodaje**: tekuća lista je
bila četiri reda običnog teksta, a jedino dugme je zatvaralo deo koji se piše i
otvaralo sledeći. `TutorialSectionsPanel` je površina za sve što model već ume —
izbor (tabla, stablo i polja idu za izabranim delom), ▲/▼, kloniranje, brisanje
sa pitanjem, „+ Dodaj deo" sa dva odgovora — i za **spojnicu**, koju autor do
sada nije mogao da vidi: dva dela gde drugi počinje tamo gde se prvom linija
završila su detetu jedna tabla bez učitavanja.

**D7 je delimično ušao ovde, suprotno onome što je ovaj dokument ranije rekao.**
Kada je pisana kapija, „Deo" umesto „Primer" ušlo je **u ovaj ekran i nigde
drugde**, jer panel je površina koja imenuje deo i besmisleno je da se zove
jedno a piše drugo. Ostatak D7 — svaka druga pojava te reči — i dalje je poseban
batch sa tabelom, po uzoru na batch 51.

**Izveštaj radnika je treći uzastopni čist.** Brojevi se poklapaju sa lead-ovim
merenjima do stavke, a i ono što nijedna tvrdnja u kapiji ne pokriva — FEN table
pre promene dela — izmereno je nezavisno i ispalo je znak po znak tačno,
uključujući polje za en-passant. Njegova jedina primedba je bila korisna: stari
`find.byIcon(Icons.delete).first` u `tutorial_studio_fields_test.dart` hvatao bi
dugme panela, pa je za svoje uzeo `Icons.delete_outline` **umesto da menja test
koji mu nije dat** — tačna odluka.

**Lead-ova mutacija je preživela, i to je najvredniji deo runde.** Ispražnjeno
`_renumberGeneratedTitles()` ostavilo je svih četrnaest testova kapije zelenim,
zato što panel ime dela crta iz **rednog broja reda** — dakle ispisivao je
tačne reči preko netačnih podataka. A `TutorialSection.toJson` šalje baš to ime
serveru: deo pomeren na početak, sa zapamćenim imenom „Deo 2", daje tutorijal
čiji su koraci numerisani obrnuto od ekrana na kome su pisani.
`test/tutorial_section_titles_test.dart` tvrdi nad **zahtevom**, i viđen je kako
pada na toj mutaciji pre nego što mu se poverovalo. **Preživela mutacija je
pitanje, a ne presuda** — kaže da test ne vidi, a ono što ne vidi nije uvek ono
što si mutirao.

Ostale lead-ove popravke: pravilo o numeraciji stajalo je na **pet mesta**
(četiri prekopirane petlje u ekranu, svaka sa `RegExp` koji se prevodi unutar
petlje, i još jednom u panelu) — sada je `generatedSectionTitle` /
`isGeneratedSectionTitle` u modelu, ista porodica kao tri prepisana podupita
koja su sva zaboravila `status = 'accepted'`; dve rečenice koje su ostale na
„Primer" u tom ekranu; i pomenuti pretraživač po ključu umesto po ikoni.

**Kapija za prazan string.** `strings` je pao na `-['', '']` — radnik je izbacio
`_sentenceController.text = ''` jer čišćenje polja sada ide kroz
`_loadSelectedSection()`, jedinog čitača. To je popravljeno **u kapiji, a ne
dozvolom**: `_norm` više ne broji prazan literal ni sa jedne strane, jer u
stringu bez znakova nema teksta koji bi trebalo štititi. Dozvola bi rešila jedan
batch i ostavila sledeće preuređenje kontrolera da udari u isti zid.

### P5b — podeljeni raspored, 6.9.2026, batch 58

`gemini-3.8-flash-high`, `flutter_feature_builder`, jedna runda, devet kapija
zeleno iz prve. **1524 testa u aplikaciji, 1 preskočen** (bilo 1515); backend
nije diran i ostaje na 956.

Tabla sada uzima prozor, a desna kolona je fiksnih 460: naziv iznad, „Delovi
tutorijala" u gornjoj polovini, polja i stablo u donjoj, **svaka polovina sa
svojim skrolom**. Čitanje linije više ne odnosi spisak delova sa ekrana, što je
ceo razlog zbog kog je ovaj raspored napravljen. „Sačuvaj tutorijal" je otišao
**u AppBar**, iz oba rasporeda — tamo gde ga je §5 plana i crtao.

**Najvrednije u ovoj rundi desilo se pre nego što je radnik pokrenut.** Ceo
raspored je jednom napravljen kao proba pa bačen, samo da se vidi da li je
kapija zadovoljiva. Nije bila: prvi oblik je Sačuvaj prikucao ispod donje
polovine, tačno tamo gde `AppFeedback` crta poruku — pa je SnackBar prekrivao
dugme na koje se žali, i jedan od šest dodira na njega u zamrznutoj kapiji
`tutorial_authoring_test.dart` je pao na prekriveno dugme. Sa dugmetom u
AppBar-u proba je dala 1524 zelena bez ijedne izmene u postojećim testovima —
i tačno to je batch i postigao. **Kapija koju niko ne može da zadovolji košta
rundu; pola sata probe je platilo tri takve stvari odjednom** (uz to: panel
traži `Flexible`, ne `Expanded`, jer u uskom rasporedu ima neograničenu visinu;
a centriranje se meri na `BoardWithCoordinates`, jer oznake redova i kolona
stoje sa dve strane pa je sama tabla namerno van centra u svom vidžetu — prva
verzija kapije je tražila asimetriju koja bi bila greška da ju je neko napravio).

**Izveštaj radnika je četvrti uzastopni čist**, i sve u njemu je mereno:
460 + 12 + 1104 = 1576 (širina reda na prozoru od 1600), polovine 336 i 504 —
tačno 2:3 — i 148 px zazora sa svake strane table. Na pitanje „koji je test van
kapije ijednom pocrveneo" odgovor je „nijedan", što se poklapa sa probom.

Vođa je pokrenuo još dve mutacije preko tri koje je batch prijavio: kad se
donjoj polovini oduzme sopstveni skrol, pada sedam od devet testova; kad se
Sačuvaj vrati ispod nje, pada tačno jedan — onaj koji i postoji zbog SnackBar-a.

Jedna popravka vođe: naziv tutorijala i poziv panela stigli su **napisani dva
puta**, po jednom u svakoj grani rasporeda, s tim što je naziv sa sobom poneo i
doslovnu kopiju četvororednog komentara koji objašnjava zašto se upisuje u
nacrt. Sada su `_titleField()` i `_sectionsPanel()`. **Kapija za stringove je to
i primetila** — prijavila je ta dva literala kao *dodata*, što je ono što druga
kopija izgleda spolja.

### P6a — hronologija „Tok", 7.9.2026, batch 59

`gemini-3.8-flash-high`, `flutter_feature_builder`, jedna runda, devet kapija
zeleno iz prve. **1551 test u aplikaciji, 1 preskočen** (bilo 1539); backend
nije diran i ostaje na 956.

Autor je svoj tutorijal do sada mogao da pročita samo kao stablo poteza — pravi
oblik za uređivanje linije, pogrešan za pitanje „kako će ovo izgledati". „Tok"
je isti tutorijal u redosledu kojim ga dete sreće: kartica po taktu, rečenica
**između** poteza koji je stigao i poteza koji odlazi, i čip po odgovoru na
grananju. „Stablo" ostaje pored, jer je grananje stvar oblika stabla.

**Lead-ova polovina je bila `beatsOf`** (`3a4fe2e`): čista funkcija, petnaest
testova bez ijednog widgeta, devet mutacija — sve uhvaćene. Uz nju su izašle
dve stvari kojih u planu nije bilo. Broj poteza se **ne može brojati od korena**
(deo tutorijala može da počne iz bilo koje pozicije, pa samo FEN zna odakle
brojanje kreće) — to pravilo je bilo privatno u `VisualMoveTreeWidget`-u i sada
je `AnalysisNode.moveNumberLabel`, sa starim pozivaocem preusmerenim na njega. I
„koren" koji i sam ima roditelja je ovde dostižan — ekran drži `_rootNode` i
`_currentNode` preko izmena — pa je prva verzija beskonačno rekurzirala; sada se
zaustavlja, sa testom.

**Proba je i ovde platila.** Ceo panel je jednom napravljen pa bačen, i našla je
pravilo koje ne bi našao niko: `IndexedStack` drži skrivenu karticu **van
scene**, a `find.byType` podrazumevano preskače takve widgete. To je obaralo
`tree()` pomoćnu funkciju u **tri postojeća fajla** i sa njom dvadeset tvrdnji,
nijednu o karticama. Pripremljeno je na `master`-u pre batch-a, pa batch nije
morao da dira nijedan test.

**Jedna od tih dvadeset nije bila stvar pomoćne funkcije nego pretvrde tvrdnje.**
`tutorial_authoring_test.dart` je tražio da rečenice **nema nigde na ekranu**,
misleći „polje je više ne drži" — a hronologija je crta na svojoj kartici, s
pravom. Ispravna funkcija bi oborila taj test. Sada pita za `TextField`. Ista
porodica kao pretraživač iz batch-a 55: **tvrdnja o odsustvu je tvrdnja o celom
ekranu, a ekran stalno raste.**

Radnik je uradio dve stvari preko onoga što je traženo, i obe se zadržavaju:
tekući takt je označen na četiri načina (podloga, jači okvir, deblja slova i
ikonica), kao i uzeti čip — dakle ništa ne zavisi od same boje; i svaka kartica
ima najmanje 48 dp visine sa čipovima u `Wrap`-u. Vođa je pokrenuo još jednu
mutaciju preko četiri koje je batch prijavio, onu koju testovi crtanja ne mogu
da vide: zamena `IndexedStack`-a običnim uslovom crta isto, a obara „stablo se
ne pregrađuje pri promeni kartice".

### P6b — tutorijal se piše u hronologiji, 7.9.2026, batch 60

`gemini-3.8-flash-high`, `flutter_feature_builder`, jedna runda, devet kapija
zeleno iz prve. **1563 testa u aplikaciji, 1 preskočen** (bilo 1554); backend
nije diran i ostaje na 956. Diff su dva fajla i nijedan postojeći test nije
dirnut.

Do sada je „Tok" bio pogled, a pisalo se u jednom polju pored njega — pa je isti
tekst imao dva mesta: karticu na kojoj se čita i polje u koje se kuca, bez ičega
na ekranu što kaže o kom je potezu to polje. Sada svaka kartica nosi rečenicu
svog poteza, kartica sa pitanjem stoji ispod poslednjeg takta, a iznad kartica
ostaju samo naziv tutorijala i spisak delova.

**Preživela mutacija je bila rupa u kapiji, ne u diff-u.** Vođa je promenio
`onCommentChanged` da piše na čvor **na kome autor stoji** umesto na čvor
kartice — tačno kvar zbog kog je test i pisan — i svih devet je ostalo zeleno.
Razlog: kad se sačuvan tutorijal otvori, kursor stoji **na korenu**, a komentar
korena `PgnExporterService` ispisuje *ispred* prvog poteza, pa je tvrdnja
„rečenica stoji pre `e5`" bila tačna i za njega. Test sada prvo stane na
poslednji takt i čita sačuvanu liniju nazad **kroz `LessonStepLine`**, pitajući
koji potez nosi komentar. Gledan je kako pada pod mutacijom i kako je zelen bez
nje. **Izveštaj radnika je istu rupu našao sam i predložio istu popravku** — to
je najvrednije u njemu, i šesti uzastopni izveštaj bez ijednog izmišljenog broja.

**Dve popravke vođe koje nijedna kapija ne dohvata.** Kursor se gubio na kliku
kojim pisanje počinje: ključ polja se menja u trenutku kad kartica postane
tekuća (`beat-comment-N` → `example-sentence`), promenjen ključ demontira
element, i `TextField` koji sam pravi svoj `FocusNode` ostaje bez fokusa baš kad
trener klikne u tuđu karticu da piše. Izmereno sondom (posle klika nijedan
`EditableText` nema fokus; kontrola sa klikom u polje tekuće kartice daje
`focus=true`), popravljeno tako što `FocusNode` drži kartica. Nijedan test to ne
može da vidi, jer `enterText` sam fokusira polje. I nalepnica „Komentar za
trenutni potez" stajala je na svim karticama, pa su tri od četiri tvrdile da su
potez na kome trener stoji; sada je samo na tekućoj, a zaglavlje svake kartice
(„posle 1. e4") ionako kaže o kom je potezu reč.

Ostaje da se vidi uživo, tačka 116 u `docs/TODO-provera.md`, koja ide zajedno sa
113–115 — isti ekran, isti prolaz.

### P7a — trener crta po tabli, 7.9.2026, batch 61

`gemini-3.8-flash-high`, jedna runda. **1593 testa u aplikaciji, 1 preskočen**
(bilo 1582); backend nije diran i ostaje na 956. Sedam mutacija ukupno, tri
batch-ove i četiri vođine — sve uhvaćene.

Model ovo nosi od faze 2 `PLAN-INTERAKTIVNA-LEKCIJA`: čvor drži `arrows` i
`squares`, izvoznik piše `[%cal]` i `[%csl]`, dečji pregledač ih crta. **Niko ih
nigde nije upisivao** — svaka strelica u svakoj lekciji do danas ukucana je
rukom u PGN. Sada postoji traka ispod table i oznake putuju do deteta.

Ožičenje je ceo diff: `cancelPending()` na sva četiri mesta gde se tabla pomera,
oznake predate kontroleru kao `_current.arrows` i `_current.squares`, i
`_persist()` samo kad se nešto promenilo.

**Dve kapije su pale iz prve i nijedna nije bila greška u poslu.** `worktree` je
oborio traku, koju vođina dozvola nije imenovala — batch 47 je naučio
`changed_dart_files` da **vidi** nepraćene lib fajlove, a `gate_tree`, čiji je
posao da obori nepraćen fajl koji niko nije imenovao, o tome nije obavešten.
Videti fajl i dozvoliti ga su dve kapije; ovo je četvrti put da mehanizam obori
posao koji je sam tražio. A `contrast` je pročitao
`backgroundColor: isArrow ? accent : null` i `foregroundColor: isArrow ? canvas
: textPrimary` kao **unakrsni proizvod** i prijavio par koji se na ekranu nikad
ne crta. Popravljeno u widget-u a ne dozvolom: `_modeStyle` vraća dva cela stila
umesto jednog sastavljenog od četiri uslova, pa svaka grana nosi svoj par.
Skener ostaje konzervativan, i to je ispravno — skener koji bi grane uparivao
pogađanjem jednog dana bi sakrio pravi pad.

Ostaje da se vidi uživo, tačka 117 u `docs/TODO-provera.md`, uz 113–116.

### Šta je otvoreno — ODAKLE SUTRA

**P5a je gotov** (batch 57, gore) — ostaje da se vidi uživo, tačka 113 u
`docs/TODO-provera.md`. Odluka da se P5 deli na dva batch-a (6.9.2026, vlasnik
izabrao između tri ponuđene) pokazala se tačnom: ekran koji istovremeno dobija
nov raspored i novo ponašanje daje diff koji niko ne može da oceni popodne.

**D7 („Deo" umesto „Primer"): pola je ušlo u P5a, pola nije.** Ovaj dokument je
prvobitno rekao da ništa od toga ne ide u P5a; kada je pisana kapija, odlučeno
je drugačije za **ovaj jedan ekran** — panel je površina koja imenuje deo, pa je
besmisleno da se zove jedno a piše drugo. Svaka druga pojava te reči i dalje je
poseban batch sa tabelom u `docs/TABELA-TUTORIJAL.md` i
`tutorial_vocabulary_test.dart` kao zaštitom, po uzoru na batch 51.

**`master` nije gurnut.** CI se okida na push, pa je to svesna odluka vlasnika, ne
propust.

**P5b je gotov** (batch 58, gore) — ostaje da se vidi uživo, tačka 114 u
`docs/TODO-provera.md`, koja ide zajedno sa 113.

**P6a je gotov** (batch 59, gore) — ostaje da se vidi uživo, tačka 115 u
`docs/TODO-provera.md`, koja ide zajedno sa 113 i 114.

**P6b je gotov** (batch 60, gore) — ostaje da se vidi uživo, tačka 116. **Time
je ceo P6 zatvoren**, i sa njim glavni deo redizajna: studio je jedan ekran na
kome se tutorijal i piše i čita.

Probni build je i za P6b platio pre nego što je brief napisan: našao je da
sačuvan tutorijal nikada nije učitavao *tip* dela u editor (`ad8c11a`, sa
`test/tutorial_reopen_test.dart`), i suzio tvrdnju u
`tutorial_authoring_test.dart` koju bi ispravan P6b oborio (`3c9d481`). To je
treći probni build zaredom koji se isplatio.

**Stanje `master`-a mereno 7.9.2026, ničim drugim uz to: 1563 testa u
aplikaciji, 1 preskočen; `flutter analyze` — 29 stavki, sve `info`.** Backend
nije diran i ostaje na 956.

**P7 je ceo gotov.** P7a je batch 61 (gore) — ostaje da se vidi uživo, tačka
117. **P7b je urađen isti dan, vođa** (`1ae5fd2` + `869dd60`): soba je prešla na
`BoardAnnotationController`, iz nje su izašla tri polja i dve metode, i jedno
pravilo više ne živi na dva mesta. **1605 testova u aplikaciji, 1 preskočen**;
analizator 29; backend 956.

Redosled je bio ceo posao: **prvo dvanaest testova crtanja u sobi, zelenih na
nepromenjenoj sobi**, pa tek onda selidba. Soba se, ispostavilo se, može
pumpati u testu — `STUDIO` je jedini kod sobe čiji `initState` ne traži server,
ni registraciju sesije, ni partnera, socket se pravi sa `disableAutoConnect`, a
`lessonApi` je već injektabilan.

**Dve mutacije su preživele prvi put**, i to je bio nalaz: brisanje
`cancelPending()` iz `_selectNode` i iz rukovaoca potezom ostavljalo je sve
zeleno, jer nijedan test nije šetao stablom sa polunacrtanom strelicom. Rupa je
zatvorena sa dva testa, oba gledana kako padaju na mutaciji koja ih je našla.

Dve namerne promene ponašanja, obe zapisane u kodu: **prazno „Izbriši sve
strelice" više ne emituje** (upisivalo je `arrow_drawn` u `timeline_json` za
pritisak koji ništa nije promenio, pa je reprodukcija imala prazan takt), i
dugme za crtanje je `_toggleDrawingMode()`, napisano jednom umesto po jednom u
svakom rasporedu. Živa provera je tačka 118, i ona gađa **baš ono što testovi ne
vide** — emitovanje detetu i snimak.
Lead-ova polovina je bila `BoardAnnotationController` (`e95b27e`): celo
odlučivanje o tome šta klik znači, devetnaest testova bez ijednog widgeta i
sedam mutacija — šest uhvaćeno, a sedma se nije mogla ni napisati, jer
`clearArrows` fizički ne dobija polja. Kontroler drži *interakciju* i nikad
oznake: oznake pripadaju čvoru, pa svaka metoda dobija dve liste i vraća da li
se išta promenilo.

**P8 je gotov, i sa njim je `PLAN-STUDIO-REDIZAJN` ceo zatvoren** (`52499cc` +
`812bd1a`, vođa). **1620 testova u aplikaciji, 1 preskočen**; analizator 29;
backend 956. Ostaje da se vidi uživo, tačka 119.

P8a je doneo odbrane iz §7 u studio — pitanje kad se bira tip, traka na
tutorijalu koji već curi, i odbijanje pri čuvanju sa **imenovanim** delovima —
i usput našao da je odbrana koja je već postojala **bila pogrešna**: deo se
procenjivao po `pgnForSave.trim().isNotEmpty`, a deo bez poteza ipak izveze
`pgn` kad mu koren nosi belešku, strelicu ili obojeno polje. Tako je „Nađi
najbolji potez" sa strelicom bio odbijen zbog linije koju nema. **P7a je to
učinio uobičajenim načinom pisanja pitanja**, pa bi greška stigla sa prvim
pravim tutorijalom. Sada `TutorialSection.hasLine` pita stablo, a `leaksAnswer`
je jedan geter koji čitaju sva tri mesta. Uz to `ask_choice` traži dva do četiri
odgovora sa tačno jednim tačnim, što je §7.6 tražio a batch 54 ostavio otvoreno.

P8b je preneo „Pregledaj kao učenik" u studio (ništa ne šalje — pregledač dobija
`PreviewAssignmentApiService`) i ugasio stari editor **samo na Windows-u**:
`openTutorialEditor` je jedina vrata i jedino mesto koje pita platformu. Na
Androidu `LessonStepEditorPanel` ostaje netaknut, jer je dohvatljiv sa svake
platforme i brisanje bi odnelo uređivanje tutorijala sa telefona. Brisanje
panela kasnije je sada jedna izmena u jednom fajlu.

**Napisan je nov plan: [PLAN-PGN-TEKST.md](PLAN-PGN-TEKST.md)** (7.9.2026), iz
dve vlasnikove primedbe sa žive provere — tekstualni pogled na deo, i desni klik
na potez u tom tekstu. Ne menja model: oba smera već postoje
(`PgnExporterService` piše `[%cal]`, `[%csl]`, varijante i `[FEN]`;
`LessonStepLine` ih čita nazad i broji `rejectedMoves`). Usput zatvara rupu koja
je ostala posle razgovora o PDF-ovima: **aplikacija nema vrata za anotiranu
liniju napravljenu bilo gde drugde**, jer jedini uvoz PGN-a ide kroz
`_importPgn`, koji baca komentare, oznake i varijante. **T1 i T2 su gotovi istog dana** (`e45f004`, `e75e97d`), oba vođa.
`exportWithSpans` vraća isti tekst plus `(start, end, nodeId, kind)` za svaki
potez i svaki komentar (petnaest testova bez ijednog widgeta, pet mutacija, sve
uhvaćene), a studio ima treći tab **„PGN"**: tekst dela sa komentarima,
`[%cal]`, `[%csl]` i varijantama, i „Primeni" koje čita nazad kroz
`LessonStepLine`. **Time su otvorena vrata kojih nije bilo** — anotirana linija
iz knjige, iz motora ili iz onoga što model napiše iz PDF-a više ne mora da se
prekucava potez po potez.

U T2 su **tri od pet mutacija preživele prvi prolaz** i svaka je platila
popravku: test odbijanja nije umeo da razlikuje „odbijeno" od „primenjeno bez
poteza koji nije pročitan"; brisanje sačuvanog teksta pri primeni nije radilo
ništa (`treeSignature` ionako vidi novo stablo, pa je taj red obrisan); a
zaštita koja čuva neprimenjen tekst nije imala nijedan test — sada ima, iz
drugog pokušaja, jer je prvi igrao crni potez iz pozicije u kojoj je beli na
potezu.

**T3 i T4 su gotovi istog dana** (`b36ffe0`). Kursor u tekstu bira potez i
obrnuto — tabla i „Tok" idu za karetom, a karet ide za kursorom, ali nikad preko
teksta koji trener piše a nije primenio. Desni klik nudi tri stvari za potez pod
karetom; **strelica i polje ne crtaju sami**, nego postave kursor na taj potez i
uključe režim na tabli, jer crtanje ima jedan dom od P7.

Usput je jedno postojeće pravilo uhvatilo grešku i **bilo je u pravu**:
`tutorial_authoring_test` obara sve pod `lib/features/tutorial_studio/` što
uvozi `PgnExporterService`, jer par `fen`/`pgn` ima jedan dom. Tipovi raspona su
sada zaseban model, a tekst za tab dolazi iz `StudioLessonStep.textWithSpans` —
kapija stoji neoslabljena.

**T5 je gotov** (`daee549`) i sa njim je `PLAN-PGN-TEKST` ceo zatvoren. Kad
nalepljeni tekst nosi svoj `[FEN]` različit od pozicije dela, pita se jednom —
„Odustani", „Zadrži postojeću", „Uzmi tu poziciju" — jer uzimanje te pozicije
menja tablu na kojoj **dete** otvara deo. Usput su dve stvari koje su htele da
budu napisane dvaput sada napisane jednom, u `move_tree.dart` pored parsera koji
ih je već znao: `fenHeaderOf` (jedini čitač `[FEN]` zaglavlja) i `samePosition`
(poređenje bez satova, koje je do sada privatno živelo u pregledaču).

**Stanje: 1667 testova, 1 preskočen; analizator 29; backend 956.**

Napisano je i **[UPUTSTVO-STUDIO.md](UPUTSTVO-STUDIO.md)** (7.9.2026, srpski —
namerno, publika su treneri): razlika između **takta** i **dela**, tri tipa
zadatka, zašto pitanje ne sme da nosi liniju, format `[%cal]`/`[%csl]` sa
slovima boja, i redosled rada. Poslednji odeljak je **prompt za model** koji iz
knjige pravi gradivo, sa šest pravila koja je izlaz stvarno prekršio na
fajlovima u `D:\chess books`.

Ostaje **živa provera** — tačke 113–120, jedna sesija na jednom ekranu.

**Sledeće nije više ovaj plan nego živa provera**: tačke 113–119 su jedna
sesija na jednom ekranu, i sada ima na čemu — fajlovi iz `D:\chess books` daju
pravi tutorijal umesto izmišljenog.

**Zašto je P7 bio podeljen na dva** — vredi zapamtiti, jer je odluka bila
ispravna iz razloga koji se video tek na kraju. Drugo mesto poziva je soba, a
soba **nije imala nijedan test svog crtanja**, dok je to ekran na kome ide živi
čas i gde nacrtana strelica ide i u `timeline_json` i na dečju tablu.
Prepravljati ga na osnovu izveštaja radnika je tačno ono što je u ovom
repozitorijumu zapisano da se ne radi — pa je otišao vođi, sa testovima kao
prvim korakom. Te testove su odmah zaradile **dve preživele mutacije**, obe o
polunacrtanoj strelici preko promene poteza: da je posao bio jedan batch, taj
propust bi ušao u sobu i niko ga ne bi video.

Dve stvari koje je P6b ostavio kao pitanje, a ne kao dug: da li kartice koje
nisu tekuće treba da imaju nalepnicu nad poljem (sada je nemaju, i to je odluka
o tekstu koju donosi vlasnik), i da li klik u polje tuđe kartice treba i da
pomeri tablu (sada pomera — radnik je to dodao preko onoga što je traženo, i
zadržano je).

**Dozvole za batch-eve 57, 58 i 59 su izbrisane iz `orchestrate.py` pri
spajanju**, a staging kopije kapija su otišle iz `docs/gates/` u
`chess_app/test/` u samim merge commit-ima — `docs/gates/` je sada prazan, kako
i treba između batch-eva.

Redosled, podela posla i kapije su u §8 [PLAN-STUDIO-REDIZAJN.md](PLAN-STUDIO-REDIZAJN.md).
Za rad sa radnikom: `D:\Projekti\mislisha-test\orchestrator\HANDOFF.md`, prvi
odeljak je batch 57.

---

## Jednostavnost — plan i faze 0–3, 3.9.2026

Dogovor je [PLAN-JEDNOSTAVNOST.md](PLAN-JEDNOSTAVNOST.md), napisan posle
provere uživo koja je bila i najkorisniji dan do sada: vlasnik je za jedno
popodne morao da pita šta znače četiri stvari na ekranu („Pregledaj nacrt",
„talas", „Napravi kičmu", „Pokrivenost"), a ista ta provera je našla četiri
kvara — svi istog oblika, **ekran zna nešto što čitalac ne vidi**. Rečnik i
kvarovi su isti problem: ekran koji se ne može pročitati je ekran koji se ne
može ni proveriti.

| faza | šta | ko | stanje |
|---|---|---|---|
| 0 | ugovori: tri prekidača u podešavanjima, `ActionBanner`, `SpeakableInfo`, `SpeechToggleButton` | lead | **Urađeno**, `661ff47` |
| 1 | jedan meni na tabli i tri prekidača za strelice | radni agent | **Urađeno**, `c26b83c` |
| 2 | govor na info panelima, prekidač u zaglavlju | radni agent | **Urađeno**, `1e8822d` |
| 3 | dril kaže šta pokriva; dnevni cilj i vežba van rasporeda | lead | **Urađeno**, `28b196c` + `a217cdf` |
| 4 | zamena reči po rečniku | radni agent | **Urađeno**, `8ce6a6e` |
| 5 | provera uživo i unos u `TODO-provera.md` | lead | Nije rađeno |

**Rečnik je zamrznut u planu** i faza 4 se radi po njemu: kičma → glavna
linija, nacrt → nepotvrđeni potezi (gomila) / predlog poteza (jedan), kapija →
„ide kroz <potez>", širina → „koliko odgovora spremamo", pokrivenost → rupe u
repertoaru, odsečeno → „ne spremam". „Talas" i „red" su već izbačeni.

Otvoreno pitanje koje je vlasnik ostavio za kasnije: pojmovi „odlučeno",
„otvoreno", „bez odgovora" traže objašnjenje na dodir, tamo gde broj stoji.
Radi se **posle** faze 4, da se ne piše dvaput.

### Šta je faza 2 pokazala o ocenjivanju batch-a — 3.9.2026

Batch je urađen i spojen (`1e8822d`). Kod je bio uglavnom tačan; **dokaz nije
bio**, i to je nalaz koji vredi pamtiti.

Testovi koje je radni agent napisao nisu dodirnuli nijedan panel: dizali su
goli `SpeakableInfo` sa rečenicom otkucanom u samom testu, što je test iz faze
0 napisan po drugi put. Prošli bi i da je omotač uklonjen sa svakog ekrana u
aplikaciji. `flutter analyze` je to rekao naglas — dva `unused_import`, i to
baš onih ekrana koje je fajl tvrdio da testira. To je i razlog zašto se
izveštaj ne uzima kao ocena: brojevi u njemu (29 upozorenja) nisu bili tačni,
pravo stanje je bilo 31, od toga dva `warning`. Fajl uz to nije bio formatiran.

Testovi sada dižu **prave ekrane** (`RepertoireDrillScreen`, `UnconfirmedBanner`)
i porede ono što je stiglo do lažnog engine-a sa tekstom pročitanim iz stabla
widget-a, pa rečenica koja odluta od svog panela obara test. Šav koji to
omogućava: `SpeakableInfo` u ekranu nema injekciju, čita `SpeechService.
instance` — ali `init` prima engine, pa se singleton uperi u lažni.

Svaki čuvar dokazan mutacijom: razdvoji izgovoreno od prikazanog, skini
zvučnik sa banera, ugasi `autoSpeak` na presudi — svaka mutacija obori svoj
test i nijedan drugi.

Dve odluke izmerene umesto isprazno raspravljene: `Container`/`FittedBox` u
zaglavlju **ostaje** na ekranu drila, gde vraćanje starog `Padding`/`Center`
prelije 360 dp telefon za jedan piksel, a **vraćen je** na ekranu gradnje, gde
nije trebao i uzalud je smanjivao brojač. Release build ne crta trake ni za
jedno.

**Prag je sada 1128**, 1 preskočen.

### Šta je harness naučio 3.9.2026

Prvi batch koji je smeo da **obriše** fajl srušio je tri kapije: čitale su
spisak izmenjenih fajlova i otvarale svaki, a obrisan fajl je u spisku i nije na
disku. Pad je najgori od tri moguća odgovora — nije prolaz, nije nalaz, i
zaustavi sve kapije iza sebe. Sada postoji `changed_dart_files_on_disk`,
`gate_strings` sam rešava obrisan fajl, a `BATCH_ALLOWANCES` ima treću vrstu
dozvole: `"deleted"`.

---

## Repertoar, druga iteracija — faze 0–4 gotove, ostaje provera uživo

Dogovor je [PLAN-REPERTOAR-2.md](PLAN-REPERTOAR-2.md): devet zahteva, pet faza.
Stanje na 3.9.2026, sve na `master`:

| faza | šta | stanje |
|---|---|---|
| 0 | dril govori istinu (`pickReply` čita `repertoire_skips` i nudi samo odgovore koji vode u poziciju sa `source='chosen'`) | **Urađeno**, oba čuvara dokazana mutacijom |
| 1 | ugovor: `repertoires.breadth`, `/unconfirmed`, `/unconfirmed/count`, `/alternative`, `ids` na `/drill/line` i `/drill/branches` | **Urađeno**, zamrznuto u `3691e8f` |
| 2 | poslednji potez na tabli i ECO traka | **Urađeno**, `098e786` |
| 3 | pregled nacrta, značka na kartici, širina kičme | **Urađeno**, `936d202` |
| 4 | „Izdvoji u novo otvaranje" i kombinovani dril | **Urađeno**, batch ocenjen i dovršen rukom |
| 5 | provera uživo i unos u `TODO-provera.md` | Stavke napisane (sekcije 86–91); **provera je počela 3.9.2026** i našla četiri kvara — vidi ispod |

**Provera uživo je počela 3.9.2026 i stala na sekciji 89.** Alat je
`D:\Projekti\mislisha-test\qa` (699 stavki, 137 odgovoreno; `python
server.py`, pa `http://localhost:8099/provera.html`). Sekcije 86–91 kažu šta
treba videti; 91 je spisak onoga što je ta provera našla i popravila.

Četiri kvara nađena za jedno popodne, **nijedan vidljiv za 1088 testova**, svi u
procepu između onoga što klijent pošalje i onoga što test gleda:

* `'minRating': ''` — vrednost nikad interpolirana, pa je server čitao
  `Number('') || 0` i svaki pregled nacrta pitao u traci 0, gde pozicije nisu ni
  dohvatane. „Nema više nepotvrđenih poteza" na repertoaru pun nacrta.
* **širina se čuvala i nije se slala** — `tree`, `frontier` i oba `drill` poziva
  su je izostavljala, pa je server uvek računao 80%. Mereno: `main` crta 3
  protivnikova poteza, `standard` 23.
* **traka sa brojem nacrta se nije osvežavala** posle pregleda.
* **prazan red je bio ćorsokak** — ekran je govorio da se vratite na neku
  poziciju i nudio samo „Nazad".

Popravke: `cb21012`, `9809a25`, `50fe6d2`, `5f9fc6c`, `34cd5de`, `07c3e1f`,
`8e268bc`, `f2b2dc8`, `0ec7f05`. Sve traže build napravljen posle `50fe6d2` da
bi se videle.

Faze 2, 3 i 4 radio je radni agent (Gemini) po brief-u; ocenjivanje je mašinsko,
harness je `D:\Projekti\mislisha-test\orchestrator` (nije u gitu — pročitati
njegov `HANDOFF.md` prvo).

Tri stvari koje su prošle sve kapije i našle se tek čitanjem diffa, vredne
pamćenja jer se ponavljaju:

* **Faza 2:** traka sa imenom otvaranja bila je montirana sa `key` koji se menja
  pri svakom koraku šetnje, pa se ime brisalo baš tamo gde pravilo postoji.
  Widget test je prolazio — pumpa traku direktno i nikad ne vidi `key` koji joj
  ekran daje.
* **Faza 3:** sva četiri nova endpointa napisana su bez `$backendUrl`. Pali bi
  na prvi dodir na telefonu, a svi testovi su bili zeleni, jer `MockClient`
  odgovara na šta god dobije i nikad ne gleda URL.
  `test/repertoire_api_urls_test.dart` sada to čita iz izvora.
* **Faza 4:** `ids` je bio uredno provučen kroz servis i nikad poslat. Spisak je
  gurao ekran drila sa `rootFen: null`, a `_loadNext` i `_pickBranch` su čitali
  samo koren — pa je kombinovana sesija propadala na dril cele boje, a list
  grana nije mogao ni da se otvori. Dva otvaranja su drilovala sve crne
  pozicije koje čovek ima. Osam od devet kapija je bilo zeleno; oba nova testa
  su lagala jer su lažirala API **iznad** žice. Uz to: `widget.api!` tamo gde
  konvencija fajla dvesta linija iznad glasi `widget.api ?? ...`, a ruter pravi
  `const RepertoireListScreen()` — dugme je pucalo na prvi dodir van testa.
  **Pouka koja se ponavlja treći put: lažirati klijent, ne metodu.** Testovi
  koji su ovo uhvatili gledaju URL koji je `MockClient` stvarno dobio.

---

## Tabla, stablo i pitanje moraju da govore o istoj poziciji — 4.9.2026

Prijavljeno uživo: „pita me za potez, a u stablu mi je fokus na drugoj
poziciji." Jedan slučaj je nađen i popravljen istog dana (`_openReplies` je
pomerao tablu preko `_boardController.loadFen`, što ne kaže ničemu drugom da se
pozicija promenila — `_standingAfter` je ostajao prazan, a to je ono što stablo
osvetljava i po čemu se čita knjiga ispod table). Sada ide kroz
`_standAfterMove`, sa testom dokazanim mutacijom.

**Pravilo koje iz toga sledi, i važi šire od ovog ekrana:** postoji **jedan**
način da se ova tabla pomeri, i to je metoda koja uz tablu pomeri i sve ostalo.
`_boardController.loadFen` sam za sebe je uvek pola posla — pomeri figure i
ostavi stablo, poslednji potez i knjigu na staroj poziciji. Ako zatreba nova
vrsta pomeranja, dobija svoju metodu pored `_standAfterMove` i `_show`, a ne
goli `loadFen` na mestu upotrebe.

Ono što **nije** kvar i ne treba „popravljati": pitanje i tabla smeju da se
razilaze. Red je odakle dolazi sledeće pitanje, tabla je ono što gledate, i
stajanje posle svog poteza da bi se videli protivnikovi odgovori je namerno.
Sinhronizovani moraju da budu **tabla i sve što tvrdi gde smo** — stablo,
poslednji potez, knjiga, komentar.

`findNodeByFen` je popravljen istog dana (`7bbd16f`): poredio je ceo FEN dok
ostatak koda poredi `fenKeyOf`, pa su se pozicija koju je server poslao i ona
koju je tabla izračunala razlikovale u brojačima poteza — tiho, uz stablo koje
osvetli koren. Uz njega je otišla i druga kopija iste pretrage (`_findNode`).

Otvoreno: proveriti ostale `loadFen` pozive na ovom ekranu istom merom.

## „Upoznaj repertoar" — faze 1–3 gotove, 4.9.2026

Dogovor je [PLAN-UPOZNAJ-REPERTOAR.md](PLAN-UPOZNAJ-REPERTOAR.md), napisan po
vlasnikovom zapažanju da izgrađen repertoar postane slika koju niko ne može da
drži u glavi.

| faza | šta | ko | stanje |
|---|---|---|---|
| 1 | šetnja pokazuje igraču njegov sopstveni rad (širina ga ne skriva) | lead | **Urađeno**, `e5bdb4c` + `8625273` — uživo neprovereno |
| 2 | stablo crta svoja četiri stanja | lead | **Urađeno**, `37a67d3` — vlasnik video na obe teme |
| 3 | redosled obilaska (`walkthroughOrder`) | lead | **Urađeno** — brief `docs/TASK-upoznaj-f3.md` stoji kao ugovor za fazu 4 |
| 4 | ekran „Upoznaj" | radni agent | **Urađeno**, `a3b32d5` — radni agent 43.7 min, pet popravki vodećeg, uživo neprovereno |
| 5 | govor, sa budžetom rečenica | lead | **Urađeno** — uživo neprovereno |

**Dve odluke koje je vlasnik doneo 4.9.2026 i koje faza 4 nasleđuje:**

* Redosled je po `share`, ali **grana u kojoj ima igračevih odluka nikad ne ide
  iza prazne**. „It is a walkthrough of my repertoire, so the user's actual
  work must never be buried beneath untouched book lines."
* Tura govori samo o onome što je nacrtano. Rep („van toga još N poteza") ne
  ulazi u odgovor `/repertoire/tree` i endpoint se ne dira.

**Vlasnik je oba pitanja zatvorio 4.9.2026.**

Stablo iz faze 2 **jeste** rešilo prostorni deo — „graf je neuporedivo
čitljiviji" — ali faza 4 ostaje, i to je merenje koje je faza 2 trebalo da
donese: *„korisnik ne želi samo statičan pogled na razgranato stablo, već
sekvencijalno vođenje kroz poteze na tabli korak-po-korak, gde na protivnikovom
potezu jasno vidi listu odgovora i rupe."* Ekran je zato kompaktan: tabla,
traka poteza, sheet za granu i kartica sa objašnjenjem — bez drugog graditelja
i bez druge slike.

Tri odluke koje faza 4 nasleđuje, sve tri vlasnikove:

* **Ulaz je stavka u meniju „Još"** na kartici repertoara, ne četvrta ikonica:
  red već nosi bedž, „Vežbaj" i meni, a četvrta kontrola na 360 dp se u release
  buildu tiho seče. Naziv je **„Upoznaj repertoar"**.
* **Na širokom ekranu stablo stoji pored table**, sinhronizovano sa turom; na
  telefonu ostaje kompaktni raspored bez stabla.
* Kontrast rupe u tamnoj temi — rešeno pre faze 4, odeljak ispod.

### Strelice na račvanju i povratak na račvanje — 4.9.2026

Vlasnik je gledao turu i tražio dvoje: strelice za protivnikove odgovore tamo
gde se linije račvaju, i **povratak na poziciju iz koje se račva** pre nego što
krene sledeća linija, da bi je prepoznao.

**Strelice** idu kroz `EngineArrow`, isto kao na ekranu za izgradnju, pa
debljina poteza nosi rang kao i boja. Tri pravila koja se razlikuju od
`_shareArrows`: rang je **redosled ture**, ne `share` (inače najdeblja strelica
nije prvi čip); nema praga od 2%, jer tura hoda samo kroz ono što repertoar
zaista sadrži; rupa nosi `?` u znački, nikad boju. Tavanica od četiri ostaje.

**Povratak** je nov pojam: `walkthroughBeats` pravi listu *taktova* od liste
stajanja — svako stajanje jednom, plus povratak na račvanje pred svaki uspon.
`walkthroughOrder` nije diran, i test tvrdi da taktovi ne preuređuju stajanja.
Kartica tada kaže „Videli smo liniju posle e5. Sada ide e6." i to se izgovara
uvek, jer je to jedini takt koji postoji da čitalac ne bi bio izgubljen.

Tri greške nađene dok se ovo pisalo, i sve tri su isti oblik — **indeks kome se
promenilo značenje**:

* `_onSelect` i `_syncBoard` su ograničavali i indeksirali `_index` po
  `_stops`, a on sada broji taktove. Ima ih više nego stajanja, pa je tura
  **stala na poslednjem usponu** — dugme napred nije radilo ništa, tiho — a pre
  toga je tabla učitavala stajanje koje slučajno deli broj sa taktom, dakle
  **pogrešnu poziciju**, dok su kartica, strelice i rečenica bili tačni.
  Sve što je ekran činilo tačnim je bilo pokriveno; jedino što je bilo
  pogrešno nije.
* Na taktu povratka je traka pitala „odavde ide više linija — kojom?" odmah
  pošto je tura rekla kojom ide. `forwardBranches` (pitanje trake) je zato
  razdvojen od `replyBranches` (spisak na kartici).
* Test iz faze 4 je posle uvođenja taktova **prolazio iz pogrešnog razloga**:
  čitao je `stops[currentIndex]` sa brojem takta. Prepisan je da tvrdi kroz
  kursor.

I jedan test moj: „jedan odgovor nije račvanje" je stajao na poziciji ispod
koje je *moj* potez, pa je dokazivao da pozicija bez protivnikovih odgovora ne
crta ništa — što niko nije ni sumnjao. Uklanjanje pravila ga je ostavljalo
zelenim. Sada se dohoda do `d4`, gde postoji tačno jedan odgovor.

**Otvoreno, nađeno usput i namerno nepopravljeno:** `board_arrows_reach_test`
je pojačan da hvata i drugu polovinu istog kvara — prekidač za sloj koji ekran
nikad ne crta. Tri ekrana ga imaju: Analysis Studio, AI Studio i
`chess_game_screen`, svi kroz staro `arrows: true`. Nije dirano jer bi skinulo
po dva prekidača sa tri ekrana koje niko nije tražio, a podešavanja iza njih
važe za celu aplikaciju. Nov ekran koji imenuje prekidače pojedinačno je
pokriven.

### Faza 5: tura govori, i uglavnom ćuti — 4.9.2026

`walkthroughLine` (`services/walkthrough_speech.dart`) vraća **dve** stvari:
rečenice i to da li se ovo stajanje uopšte izgovara. Govori se na račvanju, na
rupi i tamo gde ste nešto zapisali; običan potez na glavnoj liniji ćuti — tabla
se pomeri, kartica kaže šta je, i ništa se ne čita. To je ceo dizajn protiv
zamora i zbog njega budžet iz plana („najviše četiri izgovorene rečenice na
dvanaest poteza") drži po konstrukciji, a ne slučajno. Test ga meri na trunku
od 24 poluporeza.

**Dve stvari koje je plan tražio se ne mogu obe ispuniti doslovno**, pa je
odabrano ovako i zapisano u kodu: §4 kaže i „običan potez dobija izgovoren
potez" i budžet od četiri rečenice — dvanaest najava je dvanaest rečenica.
Najava je zato kartica i brojač u traci, a glas ćuti.

Pravilo „izgovoreno je ono što piše" nije namera nego čuvar: kartica crta
`line.parts` kao zasebne redove, a glasu se predaje isti spisak spojen —
**dva crtanja jednog spiska**, pa ne mogu da se raziđu. Widget test čita šta je
`SpeakableInfo` dobio i traži svaku reč na kartici; pada čim neko sastavi
izgovoreni tekst po drugi put. Dokazano mutacijom, uz još dve: kad svaki potez
progovori padaju oba budžetska testa, a kad račvanje prestane da imenuje
odgovore pada rečenica.

Grane se imenuju najviše tri, pa „i još N" — redosled iz faze 3 već stavlja
igračev rad napred, pa je rep spiska ono što se najmanje sluša. Svi su na
kartici kao čipovi u svakom slučaju; to je samo ono što se čuje.

`stop()` se ne zove nigde. Čitalac prekida rečenicu tako što krene dalje — a na
Windowsu `stop()` pre nego što je išta izgovoreno obara proces, što je već
zapisano u `speech_service.dart`.

### Šta je faza 4 donela, i šta je kod radnog agenta trebalo popraviti — 4.9.2026

Ekran je `repertoire_walkthrough_screen.dart`, ugovor je
`WalkthroughCursor`. Devet kapija zeleno, 1167 → 1181 testa, `analyze` na 29.
Radni agent je izašao sa 0 posle 43.7 minuta — nije istekao, što je uslov da se
rezultat uopšte gleda.

**Ono što je uradio tačno, i što je bilo najlakše pogrešiti:** `forwardBranches`
je *izveden* iz liste stajanja koju faza 3 već uređuje, a ne novo sortiranje
`children`. Proverio sam mutacijom — sortiranje grana obara test 5.

**Pet popravki vodećeg, i svaka je bila druga kopija nečega:**

* `shareLabel` je sada izvučen iz `repertoire_tree_panel.dart` i oba mesta ga
  čitaju. **Brief je ovde bio kriv**: tražio je da se ponovo upotrebi
  formatiranje iz `markOfRepertoireMove` i istom rečenicom zamrznuo fajl u kome
  ono živi, pa nije imalo šta da se upotrebi. Radni agent je prepisao pravilo
  zaokruživanja umesto da to prijavi.
* Množina ide kroz `serbianCount`. Lokalna kopija je iz obe grane vraćala istu
  reč.
* Druga linija u listu grana čita `lookOfRepertoireMove`, ne sirovi `state`.
  **Moj potez sme da stoji ispred `open` pozicije**, pa je sirovo čitanje
  govorilo „nemate odgovor" o sopstvenom potezu čitaoca. Novi test, dokazan
  vraćanjem starog čitanja.
* Dugme za okretanje table sada okreće tablu. Bilo je nacrtano i vezano za
  praznu funkciju — „meni koji ništa ne radi", zabranjen u istom briefu jedan
  vidžet levo.
* Pozicije se porede preko `fenKeyOf`, nikad cele.

**Izveštaj radnog agenta nije ono što je traženo**, i to je nalaz za sledeći
put: od šest traženih stavki nedostaju tri — izlaz tri mutacije, tekst kartice
za sedam stajanja, i sam fajl nije napisan u koren radnog stabla nego u agentov
`brain/` direktorijum. Uz to tvrdi „above 900dp" nad kodom koji zove
`Breakpoints.isWide` (840). Kod je bio tačan, proza nije. **Mutacije sam
ponovio sam i sve tri padaju kako treba** — ali to je merenje vodećeg, ne
izveštaj agenta.

### Dve rupe u samoj mašini za ocenjivanje — 4.9.2026

Obe iste vrste: kapija koja tiho ne pogleda ono što treba da gleda.

* **`git status --porcelain` sažima potpuno nov direktorijum u jedan red.**
  `models/` ne završava na `.dart`, pa je otpao iz liste izmenjenih fajlova —
  i `walkthrough_cursor.dart` nije otvorio nijedan skener: ni `strings`, ni
  `idioms`, ni `scale`, ni `contrast`, ni `format`. Isti prazan prolaz koji je
  već popravljen za batch 47, jedan nivo dublje. Sada `-uall`; dokaz je da je
  broj fajlova otišao sa 2 na 3, ne tvrdnja.
* **`strings` je poredio *uređene liste*.** Izvlačenje `shareLabel` je pomerilo
  dva literala unutar fajla i kapija je pala sa porukom `-[] +[]` — nije umela
  da kaže šta je pogrešno, jer se `removed` i `added` računaju preko
  pripadnosti. Sada `Counter`: premeštanje prolazi uz upozorenje, a **udvojen
  literal**, koji je ranije davao istu neopisivu poruku, sada se imenuje.
  Dokazano mutacijom: `+['<1%']`.

### Rupa u stablu, drugi pokušaj: mereno umesto tvrđeno — 4.9.2026

Vlasnik je prvu popravku video uživo i rekao „teško se uočava i ovako
podebljano". Izmereno na njegovoj tamnoj temi, umesto nagađanja:

| kartica | luminancija ivice | širina | ispuna |
|---|---|---|---|
| moj potez | 0.9085 | 1.2 | ima |
| pokriven odgovor | **0.0021** | 1.2 | nema |
| rupa (pre) | **0.0021** — ista | 3.0 | nema |

Rupa je nasleđivala `sideBlack`, luminancije 0.002 — **skoro crna linija na
skoro crnoj podlozi.** Podizanje neprovidnosti sa 0.75 na 1.0 je nevidljivu
liniju učinilo čvrsto nevidljivom.

**Argument zbog koga je token zadržan bio je pogrešan.** Rečeno je da ivica mora
i dalje da kaže ko je na potezu — ali to već dvostruko kažu ispuna i silueta
(moj potez je ispunjen pravougaonik, njegov je prazna pilula), a **unutar jednog
repertoara su svi protivnikovi potezi iste strane**, pa je taj kanal konstantan
tačno tamo gde razlika treba da postoji. Ceo budžet kontrasta je odlazio na
razliku koja se na tom ekranu nikad ne javi.

Sada rupa ima `textPrimary` ivicu (svetla na tamnom, tamna na svetlom) i **blagu
ispunu**. Ivica sama popravlja samo tamnu temu: u svetloj su i `textPrimary` i
susedov token tamni, pa se opet izjednače — ispuna je jedini kanal koji
preživljava obe. Tri izgleda, nijedan nije nijansa: ispunjen pravougaonik,
prazna pilula, oprana pilula.

Test više ne tvrdi jednakost boja nego meri: ispuna postoji a susedova ne, i
**ivica se luminancijom odvaja od podloge na kojoj je nacrtana** — što je
tvrdnja koju stari token pada. Dokazano sa dve mutacije.

### Rupa u tamnoj temi: kriva je bila providnost, ne debljina — 4.9.2026

Vlasnik je tražio deblju ivicu (2.0 → 2.5–3.0). Merenje je pokazalo da je
težina već bila u redu: rupa se crtala na **2.4** naspram 1.2 za sve ostalo, pa
bi predloženi korak bio 0.1. Slab kanal je bila **boja ivice**: rupa stoji ispod
protivnikovog odgovora, dakle retko je na glavnoj liniji, a svaka kartica van
glavne linije dobija svoj `side` token na `alpha: 0.75`. Prigušen `sideBlack` na
tamnoj podlozi je tačno ono što se na slici nije videlo.

Popust je zato skinut, a token **nije** zamenjen: ivica i dalje govori ko je na
potezu, što bi jedna svetla boja za sve rupe pojela. Uz to je debljina podignuta
na 3.0. Test u `test/repertoire_tree_looks_test.dart` tvrdi oba kanala i dokazan
je sa tri mutacije — bez skidanja popusta, sa zamenom boje jednim svetlim
tokenom, i sa vraćanjem debljine na 2.4. **Nije još gledano uživo.**

## Širina nikad ne skriva ono što je igrač sam uradio — 4.9.2026

Pravilo, opšte i za sve ekrane: **potez ili nacrt koji je igrač sam napravio
ili tražio ne sme da nestane zbog širine.** Širina sužava ono što *knjiga*
predlaže da se sprema, a ne ono što je već spremljeno.

Servis to sad drži na jednom mestu, pa važi za svaki ekran — klijent nigde ne
filtrira po širini, samo je prosleđuje. Popravljena su tri mesta koja su
pravilo zaobilazila: `reachable` i `orphansOfRemoving` (oba odlučuju šta bi
brisanje ostavilo bez puta, a „nedohvatljivo" je ono što čistač briše) i
`pickReply`, koji je sužavao po širini **pre** nego što bi pitao vodi li potez
u poziciju koju je igrač odlučio.

Da četiri poziva ne ostanu navika nego pravilo, `test/repertoire_breadth_rescue.test.js`
čita izvor i pada ako ijedan poziv `coveredReplies` nema `fens` i `kept`.
Dokazan sa tri mutacije, uključujući onu u kojoj čuvar ne pročita ništa.

Nacrti i dalje ne ulaze u vežbu — nacrt nije odluka i dril ga ne pita. To je
zasebno pravilo i nije dirano.

## Redosled kroz nepotvrđene poteze ide po liniji — 4.9.2026, nije viđeno uživo

Vlasnikova prijava, njegovim rečima:

> Trenutno, mislim da ide po dubini, pa recimo prvo potvrđujem 5. potez od
> početka u svim granama, pa onda prelazi na sve šeste poteze. Lakše bi mi bilo
> da ide po jednoj liniji prvo, jer mogu da pratim kontinuitet, pozicije
> prirodno slede jedna iz druge. Pa onda po drugoj liniji…

Bio je tačan i o uzroku. Redosled je nastajao u
`chess_backend/services/repertoireUnconfirmed.js`: `found` se punio iz
`nodes.values()`, a `nodes` dolazi iz `walkLines`, koji ide **talas po talas**.
Otuda „svi peti pa svi šesti".

**Šta je napisano.** `lineOrder` u `services/repertoireLine.js`, uz `tree`:
uzima `nodes`, `root` i `kept` iz šetnje i vraća iste čvorove u dubinskom
redosledu — niz jedne linije do kraja, pa nazad na poslednje račvanje i napolje
kroz sledeće. `unconfirmedPositions` sada čita iz njega umesto iz
`nodes.values()`.

**Redosled braće je redosled crteža**, i to je vlasnikova odluka od 4.9.2026 uz
njegovu sopstvenu sliku: „po grafičkom stablu od leva na desno i od gore na
dole… od pozicije koja se račva prvo kroz liniju skroz levo". Znači: moji
potezi u mom redosledu (glavni pa alternative, kako ih `keptByPosition` vraća),
a ispod svakog protivnikovi odgovori po tome koliko se često igraju. To je
tačno ono što `tree` gradi i što panel crta.

Razmatrano je i pravilo iz „Upoznaj repertoar" (`walkthroughOrder`: grana u
kojoj ima igračevih odluka nikad ne ide iza prazne) i **nije uzeto**. Tura
prolazi ceo repertoar i tamo to pravilo brani igračev rad od zatrpavanja;
pregled nacrta gleda samo pozicije bez ijedne odluke, a vlasnik je redosled
tražio u terminima crteža. Kad bi se uzelo, čitanje i crtež bi se razišli.

**Šta nije dirano.** `walkLines`. Iz njega čitaju stablo, pokrivenost, dril i
brisanje, i menjanje njegovog redosleda bila bi izmena pod svima njima odjednom.
`lineOrder` uređuje kopiju i ne menja ništa.

**Klijent nije menjan.** Sva tri mesta koja ovo zovu — traka na ekranu za
gradnju, „Idi na nacrte" u drilu i otvaranje kartice sa liste — traže `limit: 1`
i uzimaju `.first`, pa je popravka na serveru stigla do sva tri.

**Testovi:** šest novih, 883 zelenih. Četiri u `test/repertoire_line.test.js`
(redosled, da se ništa ne gubi ni ne ponavlja, da odlučuje `share` a ne broj
partija, i da se čitanje i crtež poklapaju) i dva u
`test/repertoire_unconfirmed.test.js` (ceo pregled po liniji, i da je prvi
element tačan pri `limit: 1`).

**Provereno mutacijom**, po pravilu iz `CLAUDE.md`: povratak na `nodes.values()`
obara dva testa, brisanje reda mojih poteza pet, brisanje `share` jedan, a
zamena steka redom pet. Nijedan uslov nije mrtvo slovo — prva verzija testa za
`share` **jeste** bila mrtvo slovo, jer u podacima `games` i `share` rangiraju
isto, pa je fiksture morala da ih razdvoji.

Ostaje provera uživo: `docs/TODO-provera.md`, stavka 102.

## Tri prijave sa provere 4.9.2026 uveče — odgovoreno, nije rađeno

**Prikaz evaluacije se ujednačava po uzoru na „Pitaj motor" u repertoaru.**
**Urađeno 4.9.2026** — vidi odeljak „Panel motora ima jedan oblik" niže.

**Redosled kroz nepotvrđene poteze ide po dubini, a treba po liniji.**
**Urađeno 4.9.2026** — vidi odeljak „Redosled kroz nepotvrđene poteze ide po
liniji" gore. Popravka je otišla na server (`lineOrder`), a ne u novo sortiranje
u klijentu, jer klijent traži `limit: 1`.

**Skener pozicija radi na fontu, ne na slici.** Vlasnik je pokušao da skenira
tuđe PDF-ove i nije uspeo, uz pitanje mora li mapa po knjizi. Odgovor je u
`services/positionScanner/README.md`: mape se biraju **po azbuci, ne po imenu
fonta**, pa nova knjiga sa poznatom azbukom prolazi bez ijedne izmene; nepoznata
azbuka traži `derive.mjs` + `identify.mjs`, što je minut posla i traži da knjiga
ima odeljak sa rešenjima. Poznate su dve azbuke (`SKAK_NEW`, `TACTICS_COURSE`),
i druga je **nedovršena**.

PDF u kome su dijagrami **slike** ne može da prođe ovim putem uopšte — to je
drugi uređaj (prepoznavanje sa slike), verovatnoćni je, i tiho bi davao FEN koji
izgleda ispravno. Skener je namerno pisan suprotno: nepoznat glif je greška, ne
prazno polje. Ako se ikad radi, ide kao zaseban put sa svojom oznakom pouzdanosti
i obaveznom potvrdom trenera — nikad kao tihi nastavak ovog.

## Panel motora ima jedan oblik — 4.9.2026, nije viđeno uživo

Vlasnik je 4.9.2026 izabrao repertoarov „Pitaj motor" kao oblik koji svaki
prikaz evaluacije treba da ima, i istog dana odlučio **koliko** od njega da se
preslika: **„Zadrži prekidač i dijalog, ujednači samo izgled panela."**

**Šta je promenjeno.** `chess_app/lib/widgets/stockfish_analysis_widget.dart` —
jedan vidžet koji crtaju tri ekrana (Analysis Studio, AI Studio dvaput, i soba
tri puta), pa nijedan od njih nije diran. Sada izgleda kao repertoarov panel:

- okvirni `Container` na `surface` sa ivicom, umesto obojene `Card`;
- naslov „Motor" sa `psychology_outlined` u akcentnoj boji, i ispod njega jedan
  prigušen red koji kaže **koji** motor odgovara i **iz čijeg ugla** je ocena —
  ista rečenica koju repertoar već ima, jer je konvencija aplikacijina a ne
  ekranova;
- red po liniji: ocena, prvi potez, nastavak, pa `dN`. **Dubina je na svakom
  redu**, a ne jednom u baneru iznad njih: linije stižu na različitim dubinama i
  popravljaju se dok pretraga traje, pa je jedan broj nad svima tačan za prvi
  red i netačan za ostale. Time su nestali i baner `Eval: … (depth: …)` i
  naslov „Top N Linije";
- vrteška u zaglavlju dok motor još ništa nije rekao, iz istog razloga iz kog je
  ima repertoar: prazan panel se ne razlikuje od motora koji ne odgovara.

**Šta je zadržano, po vlasnikovoj odluci.** Prekidač „Prikaži evaluaciju" —
ovaj panel drži motor stalno upaljenim, a repertoarov ga pita jednom, pa mu
treba način da ga ugasi. Prekidač „Prikaži evaluacionu liniju", jer je to drugo
pitanje. I `EngineLineDialog` na dodir linije, jer ovi ekrani imaju gde da
smeste liniju, a repertoarova tabla nema — zato ona umesto toga odigra potez.

**Broj ostaje isti i nije bio problem.** `AnalysisLine.evaluation` je već jedan
niz, formiran na dva mesta u `stockfish_service_native.dart` (`+0.40` / `M5`,
fiksirano iz ugla belog), pa su `+0.4` i mat i pre ovoga čitali isto svuda.
Razlika je bila u panelu oko broja, i to je ono što je ujednačeno.

**Jedna prava razlika u formatu bila je u stablu**, i rešena je brisanjem —
vidi odeljak „Evaluacija je obrisana iz čvorova stabla" ispod.

**Testovi:** deset novih (`test/stockfish_analysis_panel_test.dart`), 1213
zelenih. Podeljeni na dve polovine, kao i odluka: šta je moralo da se promeni i
šta je moralo da preživi. Provereno mutacijom — vraćanje starog reda sa
prekidačem obara test za 360 dp, brisanje dubine po redu jedan, brisanje vrteške
jedan, i gašenje dijaloga jedan.

**Usput nađeno.** Red sa prekidačem „Prikaži evaluacionu liniju" prelazi ivicu
na 360 dp. Isto je važilo i za staru verziju — tamo je natpis bio 13px umesto
11px, uz širu ikonu — pa ovo nije uneto sada nego zatečeno. Natpisi su sada
`Flexible` sa skraćivanjem, a prekidači `shrinkWrap`. U release buildu se takav
red samo iseče, bez ijedne trake koja bi to rekla; u testu puca, i zato test
postoji.

Ostaje provera uživo: `docs/TODO-provera.md`, stavka 103, deo A.

## Evaluacija je obrisana iz čvorova stabla — 4.9.2026, nije viđeno uživo

Vlasnikova odluka, istog dana i njegovim rečima: ocena motora se **uopšte ne
upisuje u stablo poteza**; ko hoće da je zapamti, upisuje je kao komentar uz
potez — što je i bio jedan od razloga zbog kojih je tražio pisanje komentara.

**Zašto je to bila prava odluka, a ne samo manje koda.** Polje `AnalysisNode.eval`
imalo je **dva pisca sa različitim kodiranjem mata**: živi motor je preko
`parseWhiteRelativeEval` upisivao ±(100 − potezi), a generator stabla preko
sopstvenog `parseEvalToNumeric` ±(1000 − potezi). Čitač na kartici
(`_formatEval`) prepoznavao je mat po `abs() > 500` i računao sa bazom 1000 — pa
je mat koji nađe **živi motor** bio nacrtan kao „+98.00". Ista greška je u ovom
kodu već jednom popravljana (100 naspram 10000, vidi `eval_parsing.dart`), a ove
dve kopije tada nisu bile uvučene. Brisanjem polja nestaju i koder i dekoder;
nema šta da se razilazi.

**Obrisano:** `AnalysisNode.eval` i `evalDepth` (uz `toJson`/`fromJson`),
`VisualMoveTreeWidget._formatEval`, broj i obojena tačka na kartici, ceo naknadni
filter po eval-u sa dugmetom i klizačem („Prag"), `maxDisplayCutoff` /
`maxEvalDisplayCutoff` i `_lastAutoAnalysisDeltaCutoff` koji su ga hranili,
`[%eval …]` u PGN izvozu zajedno sa zastavicom `includeEvalComments`,
`RepertoireNote.treeEval`, i mrtvi `notes:` parametar
`repertoireTreeToNodes` (repertoarova kartica ni ranije nije crtala broj).
Generator stabla više ne piše `childNode.eval` i koristi
`parseWhiteRelativeEval` umesto svoje kopije — čime nestaje i poslednja baza
1000.

**Zadržano:** traka evaluacije i panel motora (to je prikaz uživo, ne čvor),
pregled cele partije koji i dalje piše komentare i NAG-ove, i `RepertoireNote`
sa svojom dubinom i datumom u repertoaru — to je ocena koju je korisnik sam
sačuvao, i ona ostaje.

**Cena, koja nije bila u vlasnikova tri razloga i vredi je znati:** AI generator
komentara je dobijao `evalBefore` / `evalAfter` / `nextMoveEval` sa čvorova, i
sada ih dobija kao `null`. Komentar se i dalje pravi, ali se oslanja na taktičke
i pozicione nalaze. Ako se uživo pokaže osetno slabijim, to je poznata posledica
i traži odluku, ne popravku. Nestao je i filter „sakrij slabije grane" i
`[%eval]` u PGN-u — oba je vlasnik izričito otpisao.

**Brojke:** 306 obrisanih redova naspram 86 dodatih, 18 fajlova. 1212 testova
zelenih (jedan manje nego pre — test za `treeEval` je obrisan sa getterom).
`flutter analyze` i dalje prijavljuje istih 29 poznatih `info` stavki.

Staro sačuvano stablo se i dalje otvara: `eval` i `evalDepth` se prosto više ne
čitaju iz JSON-a, i za to postoji test.

Ostaje provera uživo: `docs/TODO-provera.md`, stavka 103, deo B.

## ODAKLE SUTRA — tutorijal, 6.9.2026 posle faze 4a

Grana je bila **`feat/tutorijal`**; spojena je u `master` 6.9.2026. **1400
testova u aplikaciji** (1 preskočen), 956 na backendu — backend nije diran danas — i
`flutter analyze` 29 info, bez grešaka i upozorenja.

Faze 0–3 i **4a** iz [PLAN-TUTORIJAL.md](PLAN-TUTORIJAL.md) su zatvorene.

**Šta je danas urađeno, i šta se u planu promenilo.** Vlasnik je tražio kapiju
za batch D i školjku ekrana; to je i preporuka iz jučerašnje beleške, pa je
**batch D povučen kao radni batch** — vođa je napisao i kapiju i školjku, a
radnom agentu ostaje ono što je bilo 4b: polja za čvor, lista primera i jedno
čuvanje.

Novo u `chess_app/lib/features/tutorial_studio/`: `TutorialStudioScreen`,
`TutorialDraft` i `TutorialExample`, `TutorialHandover`, `TutorialDraftService`
i predikat `isTutorialStudioAvailable` (jedno mesto, `!kIsWeb &&
Platform.isWindows`, odluka 5). U Analiznom studiju su vrata:
„Kreiraj interaktivni tutorijal", nacrtana samo tamo gde ekran postoji, sa
pitanjem prenosi li se samo pozicija ili cela linija. Ništa na tom ekranu još
ne razgovara sa serverom — to je odluka 3, jedno čuvanje na kraju.

Kapija je `chess_app/test/tutorial_studio_test.dart`, 13 testova, napisana
**pre** ekrana i proverena sa sedam mutacija. **Jedna je prvo preživela**, i
vredi je zapamtiti: brisanje `flush`-a koji upisuje nacrt pri zatvaranju ekrana
nije oborilo kapiju, jer u testu tajmer sa 600 ms nadživi widget i upiše isto
malo kasnije. U pravoj aplikaciji zatvaranje prozora nosi i proces, pa taj tajmer
nikad ne odradi. Kapija sada zatvara ekran unutar te pola sekunde.

Dodat je i jedan zajednički komad — `playedMove` u
`lib/core/services/legal_moves.dart` — umesto šeste kopije privatnog `_sanFor`.
**Sklapanje pet postojećih kopija na njega je zaseban posao**, namerno nije
urađen unutar ovog.

**Kapija za batch E je napisana istog dana** i stoji u
`docs/gates/tutorial_authoring_test.dart`, tamo gde su stajale kapije rečnika i
grananja dok njihovi batchevi nisu sleteli — kapija koja imenuje kontrole koje
još niko nije napravio ne prevodi se, a suite koji se ne prevodi ne govori ništa
ni o čemu drugom. U merge commitu se seli u `chess_app/test/`. Provereno je da
je jedina stvar koju analizator na njoj prijavljuje tačno ono što batch treba da
doda — seam `lessonApi`; sve ostalo se već slaže sa postojećim kodom.

U njenom zaglavlju je **cela zamrznuta lista kontrola** (ključevi polja, natpisi
dugmadi, tri naziva tipa zadatka koje editor koraka već koristi). Brif za E
pokazuje na nju umesto da je prepisuje.

Pisanje kapije je rešilo četiri stvari koje je plan ostavljao da se pogode. Tri
su obične — rečenica je po čvoru a zadatak, tip i odgovori po primeru;
„+ Dodaj sledeću poziciju" počinje na poziciji na kojoj se prošla linija
završila; tri stvari se odbijaju pre slanja, a ne na serveru. **Četvrta je prava
izmena i vlasnik može da je preokrene:**

**Primer koji traži potez ne nosi liniju**, a tačan potez se odigra na istoj
tabli i tabla se vrati na poziciju — isto kao u `LessonStepEditorPanel`-u. Razlog
je na serveru: `redactStepForStudent` sklanja `solutionSan` i oznake tačnosti, a
**`pgn` ostavlja**, jer linija i jeste lekcija; `lesson_viewer_screen.dart` je
zatim čita bez obzira na tip koraka. Znači, pitanje čija linija počinje
odgovorom štampa odgovor ispod pitanja. Demonstracija pripada primeru **ispred**
pitanja — što je ionako obrazac „prikaži pa pitaj" iz faze 7. Pitanje sa
ponuđenim odgovorima nije ograničeno.

**Isti propust u editoru koraka — popravljen 6.9.2026.** Važio je i za korake
koji već postoje: `LessonStepEditorPanel` je dozvoljavao da se koraku koji
**ima liniju** postavi tip „Traži potez na tabli", a `_createStepFromPosition` u
Analiznom studiju pravi upravo takve korake (sa celom linijom kao `pgn`). Dete
je takav korak dobijalo sa linijom u kojoj je odgovor i moglo da je prolista
trakom poteza — što niko ne prijavljuje kao grešku, jer izgleda kao dete koje
prestane da greši.

Editor je jedino mesto u aplikaciji gde se `kind` koraka upisuje (provereno
grepom), pa je popravka tamo potpuna za nove korake, a za već sačuvane radi
ovako:

* biranje „Traži potez na tabli" na koraku sa linijom **pita** —
  „Ukloni liniju i postavi pitanje" ili „Odustani". Linija se ne briše iza
  leđa, a pitanje se ne odbija bez izlaza;
* korak koji je **već sačuvan** u tom stanju nosi crveno upozorenje sa dugmetom
  „Ukloni liniju";
* dok je takav korak u lekciji, čuvanje se odbija i poruka **imenuje korak**.

**Zašto u aplikaciji, a ne na serveru.** `test/lesson_editor_test.dart` kaže da
editor ne sme da prepisuje serverove odbijenice, i u pravu je — ali ovo nije
jedna od njih. Server čuva `pgn` kao neproziran tekst i **nema čitač PGN-a**;
dati mu jedan značilo bi drugi parser koji se ne slaže sa aplikacijinim, a to je
greška koju je ovaj repozitorijum već platio. Aplikacija ima tačno jedan čitač,
`LessonStepLine.read`, i popravka je pisana kroz njega. To je zapisano i pored
same odbijenice u kodu.

`test/lesson_answer_stays_hidden_test.dart`, osam testova, provereni sa šest
mutacija — sve šestu obaraju. Pitanje sa ponuđenim odgovorima **nije**
ograničeno: odgovori su tekst, oznake tačnosti se redaktuju, i linija ispod
takvog pitanja ništa ne odaje.

**Šta i dalje stoji otvoreno:** korak koji je *već sačuvan* u tom stanju i dalje
stiže do deteta sve dok ga neko ne otvori u editoru i ne ukloni liniju —
popravka je u autorskoj strani, ne u đačkoj. Druga polovina, ako se ikad pokaže
potrebnom, je da `LessonViewerScreen` ne crta traku poteza na pitanju dok se ne
odgovori. Nije urađeno: to je promena na ekranu koji dete gleda, i traži svoju
odluku.

**Batch 54 je pušten i spojen istog dana** (`4817285`). `gemini-3.1-pro-high`
preko `agy`, jedna runda, 10.5 minuta, kapija 11/11 i kapija faze 4a 13/13
nedirnuta. Ekran sada ima polja za primer, listu primera i jedno
„Sačuvaj tutorijal" koje šalje ceo tutorijal jednim `POST`-om. **1421 test.**

Tri stvari koje treba poneti dalje:

1. **Dozvole u harnessu se popunjavaju pre puštanja.** Batchevi 51–53 su svi
   vraćali `VERDICT: FAIL` bez ijedne prave greške — delom zato što je obrazac
   za izveštaj u `orchestrate.py` usidren malim slovima, a izveštaji ovog
   projekta su `REPORT-...`. Sa unosom koji imenuje tačno tri nova fajla, ovaj
   je ocenjen čisto iz prve.
2. **„Bez novih info poruka" ima i drugu polovinu: ništa novo prigušeno.**
   Batch je držao brojku na 29 pomoću `// ignore_for_file: deprecated_member_use`
   preko tri prave zastarelosti, i u izveštaju to nazvao „adekvatno rešeno".
   Vođa je prebacio na `RadioGroup<int>`, oblik koji brif i imenuje.
3. **Polovina koja radi ume da sakrije polovinu koja ne radi.** Naslov
   tutorijala je stizao u kontroler a nikad u nacrt, pa se jedini on nije vraćao
   pri ponovnom otvaranju — dok su se svi primeri vraćali.

Izveštaj: `docs/REPORT-batch-54.md`, sa beleškom vođe na vrhu — tri odeljka
nisu izmerena nego izmišljena, i to baš ona koja izgledaju kao dokaz (telo
`POST`-a, mehanizam validacije, i raspored na užem ekranu). Jedna njegova
ispravka je bila tačna i vrednija od ostatka: `PgnExporterService` uvek ispisuje
zaglavlja, pa `pgn` nikad nije prazan string.

**Sledeće:**

0. **`feat/tutorijal` je spojen u `master`** 6.9.2026, kao `b478f82` —
   dvadeset sedam commit-ova i pet radnih batcheva (51–55). Izmereno na
   `master`-u posle spajanja: **1436 u aplikaciji** (1 preskočen), **956 na
   backendu sa `.env` sklonjenim u stranu**, `flutter analyze` 29 info bez
   ijednog prićutkivanja. **Nije gurnuto na `origin`** — CI se okida na push,
   pa je to zasebna odluka.

1. **Faza 4 je cela gotova.** Batch 55 (`gemini-3.8-flash-high`, jedna runda,
   14.6 minuta) je spojen kao `a0c68ad`: editor koraka sada ume da doda, obriše
   i premesti korak, i ima polje za naziv koraka. Kapija 12/12, oba zaštićena
   fajla zelena i nedirnuta, pet mutacija.

   **Poređenje modela je ispalo u korist flash-high na imenovanim stvarima:**
   pokrenuo je `dart format` umesto što ga je prijavio, nije ništa prićutkao
   analizatoru i to je rekao u posebnom redu, prepisao je listu analizatora
   stavku po stavku i poklapa se, a `positionList` posle premeštanja koji je
   citirao je bajt po bajt isti kao onaj koji je vođa nezavisno izmerio. Batch
   54 je imao tri izmišljena odeljka; ovaj nijedan.

   Greška koju je napravio nije o sposobnosti: helper `select` u kapiji je bio
   dvosmislen (**vođina greška**), batch ga je tačno dijagnostikovao i u
   izveštaju predložio pravu ispravku — pa je onda ipak zaobišao problem
   dopisivanjem nevidljivog znaka u polje za naziv. Vođa je primenio njegov
   predlog i obrisao zaobilaženje.

2. **Faza 5, i to je sve što je ostalo** — provera uživo, zajedno:
   `TODO-provera.md` tačke 24–29, 109, 110, 111 i nova 112. Autorska strana je
   gotova, pa se sve to gleda odjednom, na telefonu i na Windowsu.
3. Otvoreno, i nije ničija tekuca stavka: zapisan primer je spljošten na `fen` + `pgn`,
   pa **vraćanje u Primer 1 radi izmene stabla** traži uvoznik PGN-a koji još
   ne postoji. Isto tako, primer sa ponuđenim odgovorima koji ima **manje od dva**
   odgovora odbija server, a ne aplikacija — ista klasa koju je batch 54 zatvorio
   za druga dva slučaja.

Stavke za proveru uživo iz ovog dela: `TODO-provera.md`, tačke 109 (školjka
studija), 111 (pisanje i čuvanje) i 112 (dodaj / obriši / premesti). Sve čekaju
fazu 5 — zajedničku proveru na uređajima, sad kad je autorska strana gotova.

**Model za batch E:** ostaje model koji ume da projektuje, jer se od njega traži
raspored polja i liste pored stabla, a ne spisak koraka. `gemini-3.8-flash-high`
čeka batch F (dodaj / obriši / promeni redosled u editoru koraka), gde je
poređenje čisto.

Radna stabla su na spojenim granama i mogu se prebaciti kad zatreba:
`mislisha-batch-a` (`batch/tutorijal-recnik`), `-b` (`batch/tutorijal-stablo`),
`-c` (`batch/tutorijal-verzije`).

## Prevaziđeno: odakle sutra, 6.9.2026 kraj dana (faze 0–3)

*Zamenjeno odeljkom iznad kad je faza 4a zatvorena. Ostaje zbog jedne stvari
koju odeljak iznad ne ponavlja — kako je batch D bio zamišljen pre nego što je
povučen.*

Grana je **`feat/tutorijal`**, nije spojena u `master`. Radno stablo čisto,
`fa902dd`. **1387 testova u aplikaciji** (1 preskočen) i **956 na backendu**,
`flutter analyze` 29 info bez grešaka i upozorenja.

Faze 0, 1, 2 i 3 iz [PLAN-TUTORIJAL.md](PLAN-TUTORIJAL.md) su zatvorene: rečnik
(batch 51), stablo u pregledaču (batch 52), verzije tutorijala (batch 53), plus
`POST /lessons/:id/clone` na backendu. Svaki batch je spojen zasebnim `--no-ff`
merge commitom u kome piše i kako je ocenjen.

**Sledeće, po dogovoru sa vlasnikom:**

1. **Kapija za batch D se piše prva.** Bez izuzetka — vidi pravilo koje je
   batch 53 naučio, u planu, u odeljku faze 3. Kapija za nov ekran ne sme da
   imenuje privatna polja; vozi ekran njegovim sopstvenim kontrolama, kao
   `tutorial_branching_test.dart`.
2. **`TutorialStudioScreen`** — faza 4a. Ugovor je C4 u planu: `TutorialDraft` i
   `TutorialExample`, četiri stvari na ekranu (tabla, stablo, polja za čvor,
   lista primera sa „+ Dodaj sledeću poziciju"), jedan `POST /lessons/save` na
   kraju, i **nijedna kopija** table, stabla ili kursora — postojeći gradivni
   blokovi se koriste.
   **Otvoreno pitanje za vlasnika:** plan ga vodi kao radni batch D, ali
   vlasnikova formulacija („pisanje Gate za Batch D i konstrukcijom
   TutorialStudioScreen-a") može da znači i da ekran gradi vođa. Preporuka:
   kapija i školjka ekrana kod vođe, polja i lista primera radnom agentu — nov
   ekran sa opisom rasporeda je tip batcha koji se najčešće vrati čudnog oblika.
3. **Ekran je zasad samo Windows** (odluka 5 u planu), iza jednog imenovanog
   predikata `!kIsWeb && Platform.isWindows`. Ništa se ne izbacuje iz Android
   verzije — to je zasebna odluka koju vlasnik donosi kasnije.

**Provera uživo (`TODO-provera.md`, tačke 24–29) se drži na čekanju do faze 5**,
zajedničke provere na uređajima — odluka vlasnika, da se isti ekran ne gleda tri
puta dok mu autorska strana još nije gotova.

**Model za sledeći batch:** vlasnikov predlog je `gemini-3.8-flash-high` kao
stroži izvršilac; plan kaže mehanički batch (F) tamo, a batch sa novim ekranom
ostaje na modelu koji ume da projektuje. Poređenje ide po imenovanim stvarima —
da li je pokrenuo `dart format`, da li se brojevi iz izveštaja poklapaju sa
merenjem vođe, i da li je ostavio komentar pisan sam sebi.

Radna stabla su na spojenim granama i mogu se prebaciti kad zatreba:
`mislisha-batch-a` (`batch/tutorijal-recnik`), `-b` (`batch/tutorijal-stablo`),
`-c` (`batch/tutorijal-verzije`).

## Tutorijal — vizija, plan i zatvorena faza 0, 6.9.2026

Plan je [PLAN-TUTORIJAL.md](PLAN-TUTORIJAL.md), rečnik je
[TABELA-TUTORIJAL.md](TABELA-TUTORIJAL.md). Vlasnik je odobrio pet odluka i one
su **zamrznute** — batch ih ne preispituje:

1. **„Tutorijal" je artefakt, „Čas" je živi rad u sobi.** Jedna reč je značila
   oboje, pa su „Poziv na lekciju" (soba se otvara sad) i „Zadaj lekciju"
   (domaći za četvrtak) detetu čitali kao isti događaj. Treća reč — „kurs" —
   ide istim putem, jer rečnik koji je ostavi nije završio posao.
2. **Klon dobija nove oznake koraka.** Oznaka koraka razrešava red u rasporedu i
   upisan odgovor; dva tutorijala sa istom oznakom su napredak deteta u pogrešnoj
   kopiji.
3. **Čuvanje na kraju**, uz lokalno perzistiran draft — jedan čist `POST` kad
   trener klikne „Sačuvaj tutorijal".
4. **Nov ekran `TutorialStudioScreen`.** Analitički studio je 2383 linije i
   dvanaest alatki *analize*; trener koji piše tutorijal mora da ignoriše devet
   od dvanaest, a lista primera nema gde da stane. Nov ekran nosi četiri stvari:
   tablu, stablo, polja za čvor na kome stojiš, i listu primera sa „+ Dodaj
   sledeću poziciju". Koristi postojeće gradivne blokove — kopija table, stabla
   ili kursora u novom ekranu je nalaz, ne detalj.
5. **Autorski ekran je zasad samo Windows.** Vlasnikova primedba uz odluku 4:
   tabla + stablo + polja + lista primera je desktop ekran, a Android je 360–410
   dp. Kapija je jedan imenovani predikat (`!kIsWeb && Platform.isWindows`), pa
   se vrata iz Studija na Androidu prosto ne crtaju. **Ništa se sad ne izbacuje
   iz Android verzije** — šta još nema smisla na telefonu je zasebna odluka koju
   vlasnik donosi kasnije, sa ekranom pred sobom. Đakova strana nije dirnuta:
   čitanje tutorijala je tabla i traka, i ostaje na oba.

**Faza 0 je zatvorena istog dana.** Zamrznut rečnik; **serverska polovina je već
primenjena** (dvanaest poruka, da aplikacija i server ne govore različitim rečima
pred detetom); `POST /lessons/:id/clone` napisan, testiran i zamrznut — 11
testova, dva dokazana mutacijom (kopirane oznake umesto novih; naslov koji
prelije `VARCHAR(255)` u 500); `LessonApiService.clone` kao ugovor za batch C; i
**dve kapije napisane pre batcheva koje sude**, obe puštene na trenutni kod da se
vidi da padaju iz pravog razloga — rečnička je crvena na 50 preostalih stringova,
a granska pada pet od šest, dok šesti („korak bez grananja nikad ne pokazuje
izbornik") prolazi i mora da prolazi i posle.

Brifovi su napisani i spremni: `TASK-tutorijal-recnik.md`,
`TASK-tutorijal-stablo.md`, `TASK-tutorijal-verzije.md`, svaki sa svojim
`brief-*-2026-09.md`. **Batch A ide sam** — dira dvadeset fajlova i sudara se sa
svakim drugim; B i C posle njega mogu paralelno.

Merenja posle faze 0: **1372 testa u aplikaciji** (1 preskočen) i **956 na
backendu**, backend isti sa `.env` sklonjenim u stranu.

## Korak lekcije: pozicija i linija moraju biti iz istog čvora — 6.9.2026

Pitanje vlasnika je bilo da li đak u jednom `show` koraku može da prelista
liniju od nekoliko poteza, sa komentarom i strelicom uz svaki polupotez, ili
mora poseban korak i poseban FEN za svaki. **Može — pregledač to radi od faze
2**: `LessonViewerScreen` čita `pgn` jednim prolazom (`mainLine()`), pa traka
poteza, strelice po potezu i komentar po potezu rade na istoj tabli.

Ali „Napravi korak od ove pozicije" je slao **poziciju iz jednog čvora i liniju
iz drugog**: `fen` je bio `_currentNode.fen`, a `pgn` izvoz celog stabla od
`_rootNode`. Kad trener ne stoji na korenu, to su dve različite partije — a
`MoveTree.parsePgn` preskače potez koji ne može da odigra i **ne kaže ništa**.
Merenjem, ne nagađanjem (probni test na `1.e4 {a} e5 {b} 2.Nf3 {c}`):

| trener stoji na | šta đak dobije |
|---|---|
| korenu | cela linija, ispravno |
| posle `1.e4` | `e5 Nf3` — linija bez prvog poteza, njegov komentar nestao |
| posle `2.Nf3` | **nijedan potez** — nema trake, samo slika; komentar nestao |

Parnost odlučuje koji od dva tiha kvara dobiješ, pa je pola pozicija u stablu
izgledalo ispravno. Poznati oblik iz `CLAUDE.md`: korak se preskoči, javi se
uspeh, kvar se vidi jedan sloj kasnije — ovde tek kad dete otvori lekciju.

Urađeno je troje:

1. **Jedan čvor odgovara za oba polja.** `StudioLessonStep.from(anchor)` pravi i
   `fen` i `pgn` iz istog čvora, pa ekran više ne sastavlja par ručno. Trener
   koji ne stoji na korenu dobija pitanje „Odakle počinje korak?" — „Od početka
   linije" ili „Odavde". Ako stoji u sporednoj varijanti, u pitanju stoji i
   upozorenje da „od početka linije" prikazuje **glavnu** liniju, jer pregledač
   ide kroz prvu decu.
2. **Tiho postaje glasno.** `MoveTree.parsePgn` broji poteze koje nije mogao da
   odigra (`rejectedMoves`), `LessonStepLine` je jedini čitač linije — isti za
   đakov ekran i za trenerovu proveru — i korak koji se ne odsvira iz svoje
   pozicije se **ne čuva**; trener dobija poruku sa brojem. Uz to: `!□` i
   `$14` više ne broje kao odbijen potez, da dobra linija ne bi bila prijavljena
   kao pokvarena.
3. **Rečenica o početnoj poziciji se vidi.** `rootComment` — ono što PGN drži
   ispred prvog poteza — parsirao se odavno i **nije ga čitao nijedan ekran**,
   a strelice na toj istoj poziciji su se crtale, pa se rupa nije primećivala.
   Sada se prikazuje na potezu 0. Oba izvoznika ga i **pišu**; ranije nisu, pa
   je trener mogao da ga otkuca u studiju i da nestane pri čuvanju.

23 nova testa (1342 → 1365), i sva četiri čuvara su dokazana mutacijom pre nego
što im se poverovalo — pravilo iz `CLAUDE.md`, i ovde je zaradilo mesto: bez
mutacije ne bi se videlo da čuvar meri baš ono zbog čega postoji.

### Linija se šeta brzinom glasa, a demonstracija prelazi u pitanje na istoj tabli

Vlasnik je zatim dao tačan pedagoški šablon, i on je promenio ono što je bilo
otvoreno gore. Lekcija o opoziciji sa `8/8/8/3k4/8/8/3PK3/8 w - - 0 1` i linijom
`1. Kd3 {…[%csl Ge4,Gd4,Gc4]} Ke5 {…} 2. Kc4 {…} Kd6 3. Kd4 {…}` mora da radi
ovako:

1. **Potez se odigrava tek kad se rečenica ispred njega izgovori do kraja.**
   `SpeechService.speak` se završava kad glas stane (`awaitSpeakCompletion`, uz
   svoj watchdog), pa pregledač **čeka rečenicu, ne sat**. Tabla koja se pomeri
   ispod rečenice koja se još izgovara ostavlja dete da sluša o poziciji koje
   više nema. Dugme „Pročitaj mi liniju" stoji u traci poteza; sa isključenim
   glasom nema ni tajmera ni automatskog puštanja — dete pritiska „Sledeći
   potez", i to je isti ekran, ne slabiji. Na mašini bez glasa dugmeta nema
   uopšte (kontrola koja ne može da radi je gora od nikakve).
2. **Obojena polja i strelice prate rečenicu i potez.** Ovo je već radilo od
   faze 2 — provereno na tačnom primeru: `[%csl Ge4,Gd4,Gc4]` stoji na tabli
   dok se čita rečenica o Kd3, i nestaje sa sledećim potezom.
3. **Prelaz iz `show` u `ask_move`/`ask_choice` je jedan neprekinut tok.** Ako
   sledeći korak stoji na **istoj poziciji** na kojoj se linija zaustavila, ne
   učitava se ništa: tabla ostaje, orijentacija se ne preračunava, narator
   izgovori pitanje i tabla se prosto otključa za dete. Korak koji počinje na
   drugoj poziciji se ne otvara sam — to je nova dijagrama i dete je otvara kad
   je spremno.

Poređenje pozicija ide po prva četiri polja FEN-a (postavka, potez, rokada, en
passant), namerno bez brojača poteza — demonstracija koja je dovde došla i
pitanje napisano odavde su za dete ista tabla.

Sedam testova na ovo, i tri mutacije: potez koji ne čeka glas, korak koji uvek
učitava tablu, i tok koji ulazi u bilo koji sledeći korak — svaka obara tačno
onaj test koji je za nju pisan.

**Nije viđeno uživo** — `TODO-provera.md`, stavka 108, tačke 24–29.

Ostaje otvoreno i namerno nije rađeno: pregledač ide samo glavnom linijom
(`LinearMoveCursor`), pa varijacije u koraku postoje u stablu a ne mogu da se
prošetaju.

## Interaktivna lekcija — faze 0–7 gotove, ostaje živa provera, 6.9.2026

`PLAN-INTERAKTIVNA-LEKCIJA.md`. Trener sprema lekciju o jednom konceptu: korak
koji se **čita** (pozicija, linija, strelice, rečenica, glas) i korak koji
**pita** (`ask_move` — nađi potez na tabli; `ask_choice` — izaberi ideju
rečima).

**Dve namene, i druga nije naknadna misao:** domaći kod kuće, i **živ rad u
sekciji** — trener otvori istu lekciju celoj grupi, svako dete radi na svom
uređaju svojim tempom, trener obilazi one koji zapnu. Zato „bez tajmera i bodova"
prestaje da bude ukus i postaje pravilo: u jednoj prostoriji deca vide ekrane
jedno drugom, i sve što ih poređa pretvara čas u trku koju najsporije dete gubi
javno.

**Nije nov resurs.** `saved_lessons.position_list` i `services/lessonSteps.js`
već drže korak, a `solutionSan` je odavno upisan i namerno nekorišćen. Korak
dobija `kind`, i odsutan `kind` znači `show` — svaka postojeća lekcija je time
već ispravna interaktivna lekcija, bez migracije.

**Dva duga se plaćaju pre ijednog novog polja**, i vrede i ako se funkcija
otkaže:

1. **Korak nema stabilan identitet.** `review_items UNIQUE(user_id, lesson_id,
   position)` i `assignment_items(assignment_id, position)` vezuju pamćenje
   učenika i njegove odgovore za **indeks**. Ubaci se korak na mesto 2 i svaki
   takav red ćutke pokazuje na drugu poziciju. Ništa ne pukne i ništa se ne
   upiše u log — poznati oblik kvara iz `CLAUDE.md`. Faza 1: `step_key`.
2. **Pregledač lekcije čita liniju slabijim parserom.** `PgnParser.parse` briše
   `{komentare}` pa `(varijacije)`, a komentari se čitaju `MoveTree.parsePgn`-om
   koji ih čuva — i ako se dva ne slože oko broja poteza, ne prikaže se nijedan
   komentar. Faza 2 nije pisanje parsera nego brisanje upotrebe: `parsePgn` već
   ume varijacije, komentare i `[%cal]`. Fali mu `[%csl]`.

**Grupni čas se ne pravi — odluka vlasnika, 6.9.2026.** Faza 8 (razlivanje
lekcije na grupu jednim klikom, uz tablu napretka za trenera) **otpada**. Bila je
jedino što je još diralo podatke — `assignments.group_id`, indeks, transakcija —
i jedino što je čekalo neodgovoreno pitanje o ceni; a zauzvrat nije donosila
ništa što dete vidi, jer je ekran deteta isti bez obzira kako mu je lekcija
stigla. Za rad uživo već postoji soba. **Lekcija ostaje čist asinhroni resurs:
interaktivni tutorijal, odnosno domaći.** Grupe (`student_groups`) ostaju ono što
su bile — vezane samo za pozive u sobu.

Time se zatvara i pitanje cene koje je stajalo otvoreno: da li grupni zadatak
troši jednu jedinicu kvote ili N. Više niko ne pita.

**Šta ostaje na snazi i ne sme da padne zajedno sa fazom 8:** razlivanje je bilo
udobnost, a ne situacija. Trener i sada može istu lekciju da da petnaestoro dece
jedno po jedno, i tih petnaestoro i dalje sedi jedno pored drugog i vidi tuđe
ekrane.

Zato je pravilo **bez tajmera, bez bodova, bez niza i bez ijednog poređenja**
istog dana izmešteno u **§2.8 plana**, kao pravilo same lekcije a ne učionice.
Dok je stajalo u odeljku o grupnom času, čitalo se kao posledica tog slučaja — pa
bi sa ukidanjem slučaja palo i pravilo, a sledeći ko poželi niz ne bi imao s čim
da se spori. Važi svuda: u sekciji čuva dete kome treba četiri minuta da ne bude
najsporije javno, a kod kuće čuva dete od merenja u jedinoj disciplini gde je
duže razmišljanje tačan potez. Treneru ništa ne nedostaje —
`assignment_items` već pamti šta je odgovoreno, šta je promašeno i gde je
otkriveno rešenje, i to čita čovek u pregledu, a ne dete na svom ekranu.

**Gde smo na kraju dana:** faze 0, 1, 2, 3, 4 i 5 su na grani
`feat/interactive-lessons`, master je netaknut i zelen. Paket 4b (ekran koji
pita) je ocenjen i spojen — `0b1a610`, merge `d092ee0`, grana čita **1312
prolaza uz 1 preskočen**. Faza 5 nema svoj paket: server je došao sa 4a (ista
ruta sudi obe vrste koraka), klijent sa 4b.

Ocena je rađena mašinom, ne po izveštaju: svaki broj je premeren, a klijent je
proveren prema **zamrznutom bekendu** a ne prema brifu — imena polja, putanje i
oblik `choices: [{text}]` slažu se sa `routes/assignments.js`, i u Dartu nema
nijedne linije koja sudi odgovor. Jedna tvrdnja nije preživela: izveštaj pominje
nestabilan test u `opening_book_service_test.dart` koji se nije ponovio ni u
jednom od dva puna prolaza.

**Dve stvari koje kapije nisu mogle da vide**, obe popravljene pre spajanja:

1. **Pogrešan potez je ostajao na tabli.** Sledeći pokušaj se čita sa
   `_lessonFen`, pa je tabla zaostala na prvom pogrešnom potezu nudila detetu
   poteze koji se u suđenoj poziciji ne razrešavaju ni u šta — a onda bi se sama
   vratila, bez reči. Nijedan od 14 testova ne prolazi kroz `onMove`, pa taj put
   nije bio pokriven. Popravljeno, pokriveno petnaestim testom i **dokazano
   mutacijom** pre nego što je poverovano. Tačna alternativa i dalje ostaje tamo
   gde ju je dete odigralo — na to §2.5 odgovara rečenicom, ne pomeranjem figura.
2. **Test na `Size(360, 640)`, koji faza 4 traži, nije u kapiji** — ona pumpa na
   podrazumevanih 800×600. Odrađen ručno pri oceni: nigde ne curi preko ivice,
   ni raspored opcija ni baner sa „Pokaži mi". Opcije jesu ispod prevoja na toj
   veličini, što je skrolovanje a ne sečenje — `TODO-provera.md`, stavka 108.

**Kapija `strings` je oborila posao koji je njen sopstveni brif tražio**, treći
put (posle paketa 45 i 46). Nalaz su bili `kind`, `ask_move`, `moveSan`,
`choiceIndex` i dve putanje — literali sa žice, u fajlovima koje brif izričito
daje radniku, i nijedan od njih nije tekst koji dete vidi. Dozvola sada imenuje
sva tri fajla; brisanje i izmena u njima i dalje padaju. Pouka je opštija od
ovog paketa: **literal nije tekst zato što je pod navodnicima, a kapija tu
razliku ne vidi — pa mora dozvola, po fajlu, rečnikom samog brifa.**

Izveštaj radnika stoji kao `docs/REPORT-batch-48.md`.

**Faza 6 je pripremljena, 5.9.2026.** Plan za nju kaže „postojeći crtač", a
crtača nije bilo: `SquareMark` se od faze 2 čita iz `[%csl]`, čuva, izvozi i
ima test za povratak kroz PGN — a **nigde se ne crta**. Tabla koju dele svi
ekrani nije imala ni parametar za to, pa je to posao vodećeg a ne radnika.
Sada postoji: prsten oko polja, u tri prolaza od najšireg (crno, belo, pa
autorova boja), po istom pravilu kao oreol strelice i uglovi poslednjeg poteza.
Oblik nosi značenje, ne nijansa — obojeno polje **jeste** samo svoja boja dok mu
nešto drugo ne da ivicu, a crveno na zelenom je par koji ovaj čitalac gubi.
Uz to, `getSquareCenter` više ne puca na ime koje nije polje: ranije je
`int.parse` na drugom znaku padao **unutar crtača**, što je crven ekran umesto
prstena koji fali. Nije se dešavalo dok su sva polja dolazila iz dodira ili iz
poteza; `[%csl]` dolazi iz komentara koji niko ne proverava. Jedanaest testova,
sve tri zaštite dokazane mutacijom. Suite: **1312 → 1323**.

**Faza 6 je gotova, paket 49 (`be61bce`).** Pregledač lekcije sada crta ono što
je autor nacrtao — strelice i polja za poziciju na kojoj stojiš, čitano iz
`_moveIndex` pri svakom crtanju — i nudi svoje rečenice kroz `SpeakableInfo`:
zadatak koraka i trenerovu belešku uz potez. Ništa se ne dodaje što se samo
čuje; svaka izgovorena rečenica je i napisana, i kapija to proverava kao
svojstvo celog ekrana. Suite **1327 → 1334**.

Od tri nalaza pri oceni, **dva su bila naša a ne radnikova**:

1. **Kapija se mogla položiti menjanjem aplikacije, i jeste.** Da bi test
   „kliknuo" dugme, paket je smanjio tablu za svaku lekciju na svakom ekranu
   (`maxHeight - 250` → `- 320`). Ekran je `SingleChildScrollView` — dugme ispod
   prevoja se dohvata skrolovanjem i nije kvar — ali `tester.tap` promašuje ono
   što nije na ekranu, a **kapija je kliktala bez skrolovanja**. Vraćeno; kapija
   sada skroluje; svih osam i dalje prolazi sa starom veličinom table; proba na
   360×640 sa oba dugmeta za govor i dugačkom beleškom ne seče ništa. Pouka je
   opštija: **kapija koja se može zadovoljiti menjanjem aplikacije umesto
   pisanjem funkcije meri pogrešnu stvar.**
2. **`flutter analyze` je pao zbog nas** — fajl kapije je otišao sa
   neiskorišćenim importom, dakle upozorenjem, u fajlu koji radnik po zadatku ne
   sme da dira, uz zahtev „nula upozorenja". Radnik ga je u izveštaju tačno
   naveo kao zatečen, a onda je u završnoj poruci tvrdio „0 warnings/errors" —
   struktuirani deo izveštaja je bio pošten, proza nije. To je ceo argument za
   traženje brojeva umesto sažetka.

A na jednom mestu je radnik bio bolji od brifa: crtež korena je stavio **izvan**
`!line.isEmpty`, pa korak čiji je PGN samo uvodni komentar bez ijednog poteza i
dalje dobija svoja polja. To je baš slučaj „pogledaj d5" o kome brif piše ceo
pasus, a formulacija koju je brif dao bi ga izgubila. Izveštaj stoji kao
`docs/REPORT-batch-49.md`.

**Faza 7 je gotova, 6.9.2026 — trener sada može da napiše korak.** 7a je bila
naša: `LessonApiService` (sedam sirovih `http` poziva na `/lessons` skupljeno na
jedno mesto) i popravka zbog koje preimenovanje više ne briše korake lekcije. 7b
je paket 50 (`3cf036a`): panel sa uređenim koracima i tri polja izabranog —
rečenica, šta traži, odgovor — pregled koji pokreće đačkov ekran, i dugme
„Napravi korak od ove pozicije" u Analitičkom studiju. `CreateCourseDialog` je
zadržao redosled i izbor pozicija, a izgubio polje za zadatak: jedno mesto na
kome se piše tekst koraka. Suite **1334 → 1341**.

Ocenjivano u dva kruga, i **najveći nalaz je bio krivica brifa, ne radnika**:

1. **Dugme je u prvom krugu otišlo u pogrešan ekran** jer je brif imenovao
   pogrešan fajl — `ai_studio_screen.dart` je AI Studio (zadaci i stabla
   rešenja), a autorska površina je Analitički studio. Radnik je doslovno
   ispunio brif i **u izveštaju napisao da brif izgleda pogrešno**. To je tačno
   ono ponašanje zbog kog se u zadatku i traže ispravke.
2. **Pregled je dodirivao server.** `AssignmentApiService(authToken: '')` je
   pravi servis bez tokena: šalje, bude odbijen i usput obeleži korak kao viđen.
   Zadovoljio je `isNotNull` u kapiji — slovo pravila, ne suštinu — pa kapija
   sada u pregledu odigra potez i tvrdi da ništa nije izašlo napolje. **Tvrdnja
   o obliku vrednosti nije tvrdnja o ponašanju.**
3. **Raspored u traci alata koji nijedna kapija ne vidi.** Novo dugme je ubačeno
   na mesto 0, a taj ekran na uskom rasporedu zadržava samo prva dva alata u
   traci — pa je „Analiziraj celu partiju" nečujno otišlo u meni na svakom
   telefonu. Pomereno pored „Izvezi PGN". Posledica jedan sloj dalje od izmene,
   što je najstariji oblik kvara u ovom projektu.

Izveštaj stoji kao `docs/REPORT-batch-50.md`.

**Faza 7c, istog dana, i to je najveći nalaz cele faze.** Paket je isporučio
panel **koji ništa ne otvara**: `LessonStepEditorPanel` se u celom repozitorijumu
konstruisao na tačno jednom mestu — u testu. Sve kapije su prošle, jer nije
falio kod nego **pozivalac**. A pošto je isti paket iz `CreateCourseDialog`
namerno uklonio jedino drugo polje za zadatak, ono što je spojeno na `master` je
bila regresija: ranije je trener mogao da napiše zadatak uz poziciju, posle toga
nigde.

Krivica je brifova: §4.1 je fiksirao konstruktor rečima „the gate constructs it
directly" i nijednom nije rekao *i otvara se odnekud*. Kapija je pumpala vidžet
direktno — test koji dokazuje da stvar radi, a ne i da neko može do nje. Isti
oblik kao `getDue`, koji nedeljama nije imao pozivaoca uz zelene testove.

Popravljeno drugim dugmetom u studiju („Uredi korake lekcije") i čuvarom koji
pada ako `lib/` prestane da konstruiše panel — dokazan mutacijom. Suite
**1341 → 1342**. **Pravilo koje ostaje:** kapija koja sama konstruiše vidžet mora
da ide u paru sa onom koja tvrdi da ga i aplikacija konstruiše. Dohvatljivost ne
vidi nijedan alat, jer sa kodom nije ništa loše — samo nema ulaza.

Dva nalaza iz ovih faza koja nadživljavaju ovu funkciju:

1. **`getDue` nikad nije radio.** `stepsOfLesson` se poziva unutra a nikad nije
   uvezen, pa je svaki poziv bacao `ReferenceError` — od `60648ba`, komita čija
   poruka glasi „the review screen knew less about a lesson than three other
   readers". `npm test` je ostajao zelen jer `sources_compile` **kompajlira**
   izvore, a nedostajuće ime nije sintaksna greška. Red za ponavljanje u
   razmacima stoji u `TODO-provera.md` kao „tested in code, never run live"; ovo
   je ono što je ta rupa krila. Popravljeno, i `test/review_due_runs.test.js`
   sada stvarno poziva funkciju.
2. **Tvrdnja koju sam sâm napisao u fazi 0 bila je pogrešna, a stari test ju je
   uhvatio.** Detalji su u planu. Pouka: testovi koji već prolaze su dokaz o
   ugovoru, ne samo o kodu.

**Faza 0 je urađena 5.9.2026** i nije na `master`-u: njen proizvod je **crven
paket**. `chess_backend/test/lesson_step_kinds.test.js`, 19 testova, svi padaju
— `npm test` čita 914 / 895 prolaza / 19 padova, a tih 895 je ceo postojeći
paket, nedirnut. Isto i sa sklonjenim `.env`-om, pa fajl ne uvlači lanac servera.
Pravilo je isto kao za fazu 4 `PLAN-JEDNOSTAVNOST`-a: tvrdnje idu na granu,
grana je crvena, `master` ostaje zelen, a faza koja ih pozeleni ocenjuje se po
tome što ih **nije menjala**.

**Provera skenera je pozitivna:** `scanIntake.prepareRow` vraća
`{ fen, solutionSan, instruction, needsReview }` — tačno `ask_move` korak.
`deriveInstruction` već piše „Beli matira u jednom potezu" za proveren mat u
jednom, pa skenirana strana može stići sa već napisanim pitanjem.

Odlučeno sa vlasnikom 5.9.2026: oba tipa pitanja idu u v1, `acceptedSans` za
više jednako tačnih poteza, trener sastavlja u Analysis Studiju, „Pokaži mi"
posle dva promašaja. Devet faza, faze 1–3 su vodeće (diraju podatke i ugovore),
4–6 mogu biti paketi za radnika, 8 je razlivanje na grupu.

## ODAKLE SUTRA — 5.9.2026, kraj dana

`PLAN-TABLA-I-STABLO.md` je **završen u celini**: svih pet faza je na masteru, plus
dve izmene koje su došle iz vlasnikovih snimaka ekrana istog dana (visina table na
desktopu, i oba banera u zaglavlju).

**Ništa od toga nije gledano uživo osim jedne stavke.** Sve čeka u
`docs/TODO-provera.md`, **stavka 104**, koja je narasla na šest delova:

| deo | šta | stanje |
|---|---|---|
| A | fokus u stablu, širina ne skriva gde stojiš | čeka |
| B | lepeza neodgovorenih odgovora u turi | čeka |
| C | fiksna tabla i sažet baner | čeka |
| D | šansa linije i pogled na jednu granu | čeka |
| E | prostor ispod table | **potvrđeno na desktopu**, telefon čeka |
| F | oba banera u zaglavlju iznad 1200 dp | čeka |
| G | stablo ne pomera pogled samo od sebe | čeka |
| H | zum preživi promenu veličine prozora | čeka |

**Urađeno posle ovog reda, istog dana:** zum i pogled u stablu sada preživljavaju
promenu širine prozora preko 840 dp (`_treeKey`) — poslednje što je od
vlasnikovih prijava od 4.9–5.9.2026 ostajalo neurađeno u kodu. Detalji i cena su
u sekciji ispod, stavka 3; provera je 104-H.

**Prvo pitanje za sledeći put:** proći 104 od početka. Dve stvari u njoj su
odluke a ne provere, i vlasnik ih jedini može doneti — dugme banera je sada 32 px
visoko umesto 48 (deo C, stavka 13), a u zaglavlju uz „N nepotvrđenih" nema
zvučnika (deo F, stavka 29).

**Brojke na kraju dana:** Flutter **1241** (1 preskočen), backend 886, `flutter
analyze` istih 29 poznatih `info` stavki. Broj 1234 koji je ovde stajao ranije
tog dana bio je zastareo za pet — izmeren je pre nego što su poslednje faze
spojene, pa je prag bio niži od suite-a i pad od pet testova bi prošao
neprimećen. Izmereno na `master`-u pre današnje izmene: 1239, i 1241 sa dva
testa koje ona donosi.

**Radna stabla:** `mislisha-batch-b` je odrađen i spojen. **`mislisha-batch-a`
drži odbačeni posao** — worker je uradio baner (uzet) i fiksnu tablu (odbijena:
sopstvena tri testa su mu padala jer traže `BoardWithCoordinates`, a izveštaj je
navodio brojeve koje njegov paket testova demantuje). Sve što je vredelo je
preuzeto; to stablo se može resetovati bez gubitka.

**Sitnica koja će se ponoviti:** `orchestrate.py` je pucao na `UnicodeEncodeError`
pri ispisu radnikovog izveštaja u cp1250 konzolu — posle rada, pre ijedne kapije
— pa su oba paketa izgledala kao prolaz a nijedna kapija nije bila pokrenuta.
Popravljeno 5.9.2026, ali tek posle oba pokretanja.

## Prijave sa provere 4.9–5.9.2026 — zabeleženo, nije rađeno

Vlasnik ih je izričito prijavio kao **sugestije, ne kvarove**, i tražio da se
samo zabeleže: „kad ih skupimo dovoljno, možemo jednim planom popravke sve da
rešimo." Kod je pogledan samo toliko da se svaka usidri i da se zna šta bi
koštala — ništa nije menjano.

### 1. Lepeza neodgovorenih protivnikovih poteza kaže istu stvar pet puta (21:21, pojašnjeno 22:20)

Prva formulacija je zvučala kao „ne pokazuj rupe", pa je ovde bila zabeležena
kao sudar sa svrhom ture. **Vlasnikovo pojašnjenje pomera je sasvim:**

> „Nema potrebe doći u situaciju da na kraju linije imamo poziciju posle
> korisnikovog poteza, a onda 4 poteza protivnika koji započinju nove linije, a
> nemaju odgovor korisnika, i da se sad sve 4 pokazuju. Tu korisnik nema šta da
> zapamti."

**Nije sudar — prijava je tačna, i to protiv budžeta koji je tura sama sebi
postavila.** Provereno u kodu:

- `lookOfRepertoireMove` (`repertoire_tree_panel.dart:32`) proglašava rupom svaki
  protivnikov potez čija je pozicija `open`. Ako korisnikov potez vodi u
  poziciju sa četiri neodgovorena odgovora, sva četiri su rupe.
- `walkthroughOrder` obilazi **svaki** potez u crtežu, pa su to četiri zasebna
  stajanja.
- `walkthrough_speech.dart` daje glas svakoj rupi, pa se četiri puta izgovori
  „Na …, N% partija, nemate odgovor."
- A **peta rečenica je već rečena pre njih**: stajanje na korisnikovom potezu
  dobija račvu — „Odavde protivnik ima 4 odgovora: …" — i ona ih sve imenuje.

Dakle pet izgovorenih rečenica na jednoj poziciji, sve o istoj činjenici. Tura
je pisana sa budžetom „najviše četiri izgovorene rečenice na dvanaest poteza
trunka" (`walkthrough_speech.dart`), i jedna ovakva lepeza ga potroši na jednom
mestu. Rupa **ostaje prijavljena** — u račvi, gde je već imenovana.

**Odluka vlasnika, 5.9.2026: prihvaćeno po ovom pravilu.** Nije pisan nijedan
red u trenutku pisanja ovog reda.

**Pravilo:**

- Ne silaziti u protivnikov potez koji je rupa **kada ih na toj poziciji ima
  dvoje ili više**; račva ih je već imenovala.
- **Usamljenu rupu zadržati.** Račva se izgovara tek na `theirs.length > 1`, pa
  je kod jednog jedinog neodgovorenog odgovora to stajanje jedino mesto gde se
  rupa uopšte kaže.
- Pravilo važi samo za odgovore koji su rupe; ako su neki odgovoreni, u njih se
  silazi kao i do sada.

Time linija prirodno završava korisnikovim potezom — što je i bilo traženo — a
da se ništa ne prećuti.

### 2. Verovatnoća da se stigne do pozicije (21:30)

> „Pošto repertoar prati statistiku sa Lichess-a, možda ne bi bilo loše znati
> relativnu verovatnoću da pozicije... stignu do trenutne pozicije ili početka
> neke linije."

**Podaci već postoje.** Svaki protivnikov odgovor nosi `share` iz `walkLines`
(`repertoireLine.js`), a klijent ga već ispisuje (`shareLabel` u
`repertoire_tree_panel.dart`). Verovatnoća dolaska = proizvod `share`-ova
protivnikovih odgovora duž linije; sopstveni potezi su odluke, ne verovatnoće,
i ulaze kao 1.

**Šta treba odlučiti:** to je **uslovna** verovatnoća — „ako igramo ovaj
repertoar i protivnik ostane unutar onoga što je pokriveno". Širina repertoara
je menja: na „samo glavna linija" proizvod je nad jednim odgovorom po poziciji i
čita se previsoko. Broj bez te rečenice pored sebe je broj koji laže.

### 3. Zum ne sme da se menja pri kretanju kroz stablo (21:55)

> „Korisnik je već izabrao veličinu, tj. zum koji mu odgovara... Ako aplikacija
> menja zum, onda korisnik izgubi fokus. Takođe, ne mora trenutni potez da bude
> centriran na sred ekrana, već samo ako priđe ivicama."

Odnosi se na **svaki** ekran sa grafičkim stablom, ne samo na repertoar.

**Polovina je potvrđena i tačno locirana:** `visual_move_tree_widget.dart:407`
centrira na aktivni čvor **posle svake promene poteza**
(`_lastCenteredNodeId != widget.activeNode.id`). To je upravo skakanje koje
vlasnik opisuje, i „samo kad priđe ivici" je izmena unutar `_centerOnActive`.

**Odluka vlasnika, 5.9.2026:** pravilo je **bezuslovno** — „aplikacija nikad ne
menja sama zum, to treba da bude korisnikov izbor". Merenje ispod ostaje, ali
kao dijagnostika (gde se menja), ne kao odluka (sme li).

**Prva polovina je urađena 5.9.2026** (`883c598`, faza 2 iz
`docs/PLAN-TABLA-I-STABLO.md`): pogled se pomera samo kad aktivna kartica priđe
ivici, i to tačno toliko da uđe unutra. Prag je `_edgeMargin` = 48 px vidljivog
dela. Dugme „Centriraj na aktivni potez" i dalje centrira — to je korisnikov
zahtev, a pravilo zabranjuje samo ono što aplikacija radi sama. Živo nije
gledano: `docs/TODO-provera.md`, stavka 104-G.

**Druga polovina je izmerena i nije popravljena, i sada zna svoje ime.**
`_centerOnActive` **čuva** razmeru — čita `getMaxScaleOnAxis()` i vraća je istu
— a u celom fajlu matricu upisuju samo tri mesta i dva su korisnikova (zum i
reset). Dakle promena zuma ne dolazi iz računa u tom vidžetu.

**Dolazi od gubitka stanja, izmereno dva puta 5.9.2026: 1,5625 → 1,0.**
`repertoire_build_screen.dart` crta stablo na **dva različita mesta** u
rasporedu — unutar kolone sa tablom kad je usko (linija 3064) i u svojoj koloni
pored table kad je široko (linija 2768) — a prelaz je `Breakpoints.wide` = 840.
Vidžet koji se premesti u drugi slot dobija **novo** `State`, pa nov
`TransformationController`, pa razmeru 1,0. Isti oblik zamke koji je u tom
fajlu već zapisan za `OpeningBanner._lastNamed`.

**Urađeno 5.9.2026, posle faze 5.** Izabran je `GlobalKey` — `_treeKey` u
`repertoire_build_screen.dart` — a ne selidba kontrolera na ekran, iz dva
razloga. Prvi: kontroler nije jedino što se gubilo. U istom `State`-u su i
pomeraj, prekidač „graf / notacija" i smer rasporeda, pa bi selidba jednog
polja ostavila ostala tri da se i dalje resetuju. Drugi: isti fajl je istog
dana dobio `_openingKey` iz istog razloga, sa objašnjenjem uz njega — dve
različite popravke istog oblika u jednom fajlu su skuplje od jedne ponovljene.
Zamerka „jedan red koji se lako zaboravi zašto stoji" rešena je time što taj
red nosi mereni broj (1,5625 → 1,0) i pravilo koje brani.

**Cena koja je došla uz ključ, i nije bila u proceni:** `GlobalKey` u dva mesta
odjednom baca. Dva crteža su se do sada isključivala tako što su **dva puta
čitala širinu** — `LayoutBuilder` u telu i `Breakpoints.isWide` u koloni sa
tablom — a to su dva izvora koji mogu da se ne slože. Sada telo odlučuje jednom
i odgovor prosleđuje kao `treeBelow`. Čuvar je dokazan mutacijom u oba pravca:
bez ključa test pada sa `1.0` umesto `1.5625`, a sa uvek uključenim drugim
mestom pada na „Multiple widgets used the same GlobalKey".

Živo nije gledano: `docs/TODO-provera.md`, stavka **104-H**.

### 4. Fokus na liniju, i dugme za način prikaza (22:00)

> „Fokus treba da bude na trenutnoj liniji, ne striktno na potez. Ili da postoji
> dugme kojim korisnik podešava kako se ažurira prikaz stabla... Možda i dugme
> „prikaži samo ovu liniju" ili prikaži samo od ove pozicije."

Isti vidžet kao 3, i to dvoje ide zajedno u plan.

**Dve stvari vredi znati:**

- Filtar koji je 4.9.2026 obrisan bio je **po evaluaciji motora** i to je ono što
  ga je činilo lošim — sakrivao je grane po tuđem mišljenju. Ovo je filtar **po
  liniji koju je korisnik izabrao**, što je sasvim druga stvar i mnogo
  odbranjivije. Brisanje onog ne govori protiv ovog.
- „Prikaži samo od ove pozicije" **već postoji na serveru**, kao kapija
  repertoara (`rootFen` + `gateUci`, `gateMoves` u `repertoireFrontier.js`) i
  ekran „Vežbaj X" ga koristi. Pre pisanja novog filtra treba proveriti da li je
  ovo isti pojam pod drugim imenom — dva različita „samo ova grana" u istoj
  aplikaciji je tačno onaj oblik koji se kasnije razilazi.

### 5. Tabla mora da stoji, a stablo da ne gubi fokus (5.9.2026, 08:35)

Jedna prijava, četiri zahteva u njoj. Vlasnikov tekst je u alatu za proveru
(`stanje.json`, `n1788590120398`), uz sliku.

**a) Tabla i navigaciona paleta ne smeju da odskroluju.**

> „Tabla sa navigacionom paletom ispod se skrolovanjem ne vidi, treba da bude
> statična, a da se pomera samo ono što je ispod."

`_buildBoardColumn` (`repertoire_build_screen.dart`) je jedan
`SingleChildScrollView` oko jednog `Column`-a, pa se **sve** pomera zajedno:
traka nepotvrđenih, tabla, `_buildNavigation`, pa komentar, pitanje, odgovori,
presuda, uzeti potezi i knjiga. Traženi oblik je `Column[ nepomični deo,
Expanded(SingleChildScrollView(ostatak)) ]`.

**Odluka vlasnika, 5.9.2026:** prihvaćeno — tabla i navigaciona traka ostaju
fiksirane na vrhu, ostatak se skroluje, a **proračun veličine table mora da uzme
i visinu ekrana**, izričito za male telefone (360 dp).

**Ograničenje koje treba rešiti pre pisanja:** na 360×640 tabla plus paleta već
troše skoro ceo ekran. Ako se zakuju, deo koji se skroluje spada na nekoliko
piksela, a tabla se iseca — dakle veličina table mora da se računa **od visine
prozora**, ne samo od širine, i to je pravi posao ove stavke.

**b) Traka „N nepotvrđenih u grafu" jede prostor iznad table.** Na slici uz
prijavu je baš ona. Vlasnikov predlog: izbaciti je ili pomeriti. Vredi
razmisliti da postane deo nepomičnog zaglavlja ili da se skupi u jedan red sa
dugmetom, umesto zasebne kartice.

**Odluka vlasnika, 5.9.2026:** baner se **sažima u jedan kompaktan red u ravni
sa dugmetom**, da ne gura tablu nadole. Ne briše se.

**c) Fokus u stablu se ne sme gubiti pri gradnji.**

> „Ako korisnik izabere potez za svoju boju, taj potez treba odmah da se vidi u
> stablu poteza i da se pozicija na tabli i fokus u stablu poteza postavi na tu
> poziciju. Izborom poteza za protivnika pozicija ostaje na tom mestu, ali se u
> stablo dodaje odmah potez protivnika, a fokus je usklađen sa tablom, jer
> korisnik može da doda i druge, alternativne poteze protivnika."

Ovo je **ista prijava** kao ranija, nezabeležena, od 4.9.2026 13:29
(`n1788510593557`): „aplikacija ne upisuje taj potez u stablo odmah… i posle
mog izbora šta igra protivnik, baca me negde".

**Arhitektura je već prava, i to je dobra vest:** `_activeNode` se izvodi iz
FEN-a table (`_standingAfter?.fen ?? _current`), pa fokus **prati tablu** po
konstrukciji — tačno kako vlasnik traži. Sumnjiv je jedan red:

    return findNodeByFen(root, fen) ?? root;

`?? root` znači da pozicija koju novi crtež ne sadrži tiho vraća fokus na koren
repertoara — što je verovatno ono „baca me negde". A crtež je ne sadrži kada
potez ispadne izvan trenutne širine, što je **isti uzrok** koji je već imenovan
na drugom mestu istog fajla (poruka „Ova pozicija je izvan onoga što spremate").
**Odluka vlasnika, 5.9.2026, i ona rešava baš taj sudar:**

- **Tihi `?? root` se ukida.** Korisnik nikada ne sme da bude vraćen na početak
  dok istražuje poteze.
- Ako korisnik odigra potez, **stablo mora odmah da prikaže taj potez**.
  „Odigra" znači **oba ulaza**, pojašnjeno 5.9.2026: i potez povučen na tabli, i
  potez prihvaćen iz spiska ispod table („Potvrdi", „Uzmi …", odgovori). Pravilo
  visi o tome da je čovek potez odobrio, ne o tome kojim ga je putem odobrio.
- Ako je potez bio van filtera širine, **privremeno se otkriva** — jer korisnik
  je eksplicitno na njemu. Širina ostaje ono što je bila za sve ostalo; ovo je
  izuzetak za poziciju na kojoj čovek stoji, ne promena širine.

To je isti oblik pravila koje već postoji na serveru (`coveredReplies` prati
odgovor koji vodi u poziciju gde korisnik ima odluku, na svakoj širini) — dakle
„ono što je čovek sam uradio se ne skriva" važi i ovde.

**d) Zum se nikad ne menja sam.**

> „Zum (veličina prikaza) u grafičkom stablu poteza ne treba da se menja
> automatski, već to korisnik radi. Dakle, aplikacija nikad ne menja sama zum."

Ovo **zatvara pitanje ostavljeno otvoreno u stavci 3** gore: zahtev je sada
bezuslovan, pa nije bitno odakle promena dolazi — ne sme da postoji.

**Izmereno 5.9.2026, i stavka 3 gore nosi ceo nalaz:** stablo samo od sebe ne
menja zum ni na jednom mestu u svom vidžetu; zum se gubi zato što vidžet pri
prelazu preko 840 px dobija novo stanje. **Urađeno 5.9.2026** — vidi stavku 3
gore za izbor rešenja i za cenu koja je uz njega došla. Ovime je cela prijava
d) zatvorena u kodu; ostaje da se vidi uživo (provera 104-G i 104-H).

### 6. Banere iznad srednje kolone na desktopu (5.9.2026, ideja vlasnika)

> „Šta misliš da u desktop režimu naziv otvaranja („C50 · Italian Game…") i
> baner sa nepotvrđenim potezima prebacimo iznad srednje kolone (iznad stabla
> varijanti)?"

Njegova dva razloga, oba stoje: leva kolona bi ostala bez ijedne fiksne kartice
iznad table — tabla ide na sam vrh, a sav prostor ostaje tabli, navigaciji i
potezima; a i sadržajno, i ime otvaranja i broj nepotvrđenih govore o
repertoaru i stablu, a srednja kolona na desktopu ima vertikalnog prostora
napretek.

**Šta bi se menjalo.** `_buildBoardColumn` već prima `commentBeside` za istu
vrstu odluke, pa bi dobio i drugi takav prekidač; široki raspored bi banere
crtao iznad `Expanded`-a sa stablom. Fiksno iznad, ne unutar `SingleChildScrollView`-a
— „Pregledaj nepotvrđene" je radnja i ne sme da odskroluje.

**Koliko se dobija.** Baneri u levoj koloni troše oko 106 px (ime otvaranja ~40
+ nepotvrđeni 66). Na prozoru visine 1000 to je, pri istom `_boardShare`, oko
106 px više ispod table — ili veća tabla za toliko, ako se deo uzme nazad.
Vlasnikovih 500 px traži `_boardShare` oko 0,53.

**Dve cene, i obe treba znati pre nego što se počne:**

1. **`_boardShare` bi opet postao dva broja.** Tek je 5.9.2026 postao jedan za
   oba rasporeda, i to je bilo pojednostavljenje. Ako desktop izgubi banere iz
   leve kolone, njegov nepomični deo više nije istog sastava kao telefonov, pa
   jedan udeo prestaje da znači isto na oba. Nije prepreka — samo treba reći
   naglas da se time vraća razlika koja je upravo uklonjena.
2. **`OpeningBanner` nosi stanje, i selidba ga briše.** `_lastNamed` u
   `_OpeningBannerState` pamti poslednje *imenovano* otvaranje, i zato je taj
   vidžet namerno bez ključa — komentar u `repertoire_build_screen.dart` to
   izričito kaže. Vidžet na drugom mestu u stablu vidžeta dobija **novo**
   `State`, pa se ime gubi. Jednokratno je bezazleno, ali ako baner postoji na
   dva mesta (usko naspram široko), **svaki prelaz preko praga od 840 px briše
   nošeno ime** — a to je obično menjanje veličine prozora na Windowsu. Rešivo
   (jedan `GlobalKey`, ili da se nošeno ime drži na ekranu umesto u baneru),
   ali se mora rešiti, inače je to tiha regresija tačno one vrste koju ovaj
   projekat stalno plaća.

**Bolja varijanta iste ideje, vlasnikova, isti dan:** „Možemo li iskoristiti
prostor pored *Italian Game: Giuoco Piano — beli*?" — dakle u **zaglavlje**, ne
iznad srednje kolone.

Bolja je zato što srednja kolona ne plaća ništa: zaglavlje već postoji, već je
visoko 56 px, i na širokom prozoru mu desno stoji prazno. Selidba iznad stabla
oslobađa levu kolonu ali trošak seli u srednju; u zaglavlju trošak nestaje.

**Mere na prozoru od 1920** (naslov ~340, radnje sa zvučnikom, mrežom i
„upita: 0" ~172, vodeća strelica ~56): slobodno ostaje **oko 1350 px**. Čip sa
imenom otvaranja je oko 400, sažeti red nepotvrđenih oko 390 — zajedno oko 790,
staje sa viškom.

**Prag, i on je odluka a ne detalj:** na 1200 slobodnog prostora ima oko 630, što
prima jedno od to dvoje. Ispod `Breakpoints.wide` (840) ne prima nijedno i oba
ostaju gde su danas. Dakle tri stanja, ne dva.

**Zaglavlje je izvan `LayoutBuilder`-a**, pa širinu čita iz
`Breakpoints.isWide(context)` / `MediaQuery`, kako to isti ekran već radi na
jednom mestu.

**Vizuelno:** baner u zaglavlju verovatno ne treba svoju obojenu karticu sa
ivicom — zaglavlje ga već odvaja. Tekst i dugme, bez okvira.

**Cena oko `OpeningBanner`-a ostaje ista i tu** — i dalje se seli između dva
mesta, pa i dalje gubi nošeno ime na svakom prelasku praga. Dva rešenja:
`GlobalKey` na baneru, ili — čistije — da `_lastNamed` živi na ekranu, a baner
postane bezstanjen i prima ime kao parametar. Drugo rešenje uklanja krhkost
umesto da je zaobiđe.

**Urađeno 5.9.2026 za oba**, uz `bare: true`. Levoj koloni je time skinuto oko
106 px fiksnih kartica iznad table.

**Prag je `ultraWide` (1200), ne `wide` (840), i to je izmereno.** Dugme
„Pregledaj nepotvrđene" ne može da se skupi, pa se na 900 dp zaglavlje prelilo
25 px već sa imenom repertoara i banerom, a 139 px kad se doda i ime otvaranja.
1200 je postojeći odgovor ove aplikacije na pitanje „ima li ovde mesta za treću
stvar" i njegov sopstveni komentar to kaže, pa je iskorišćen umesto da se
izmišlja nov broj. Ispod praga oba ostaju iznad table — što uključuje i telefon
u pejzažu, koji je oko 770 dp.

**Nađeno pri radu, i vredi zapamtiti:** `SpeakableInfo` je `Row` od `Expanded`-a
i `IconButton`-a, a ta ikonica ne može da se skupi. U zaglavlju, gde dugme
„Pregledaj nepotvrđene" traži 326 od 381 px koliko baner dobija, rečenici ostane
devetnaest — i ikonica ispadne jedanaest piksela van. U zaglavlju zato ide obična
`Text` sa skraćivanjem, bez sopstvenog zvučnika; zaglavlje ima svoj prekidač za
govor. **Uhvaćeno testom koji je već postojao** (`repertoire_counts_refresh_test`),
a u release bildu bi to bilo jedanaest piksela ćutanja.

**Pejzaž na telefonu nije diran** i vlasnik je izričito rekao da se za sada ne
dira (5.9.2026). Telefon u pejzažu je oko 770 dp — **ispod praga od 840** — pa
ostaje uski raspored: baner iznad table preko cele širine, tabla po sredini, a
visina je tada oko 340 dp, gde pravilo `_boardShare` daje malu tablu. To je
zasebna stavka kad na nju dođe red.

## Širina se menja bez pisanja ijednog poteza — 5.9.2026

Prijava vlasnika, ista večer: „ručno dodajem poteze i kad izaberem potez za
protivnika, dodaju mi se još nekoliko alternativa (a hoću samo da se dodaje taj
jedan koji sam izabrao)... nema smisla da biram šta igra protivnik, kad mi se
potezi sami dodaju."

**Prvo šta se zapravo dešava, jer prijava opisuje pogrešan mehanizam.** Ti
potezi **nisu upisani** kao njegove odluke. Čuva se samo ono što potvrdi i ono
na šta sam pritisne „Spremi i ovo". Kartice o kojima govori računaju se pri
svakom čitanju, iz `opening_replies`, a koliko ih se uzme odlučuje **širina
repertoara** (`coveredReplies` / `withinBreadth`). Na podrazumevanom
`Uobičajeno (80%)` to je svaki protivnikov odgovor unutar 80% odigranih
partija, pa biranje jednog ne uklanja ostale — oni nikad nisu ni bili njegov
izbor.

Nisu bezazleni: isti hod puni i red pitanja, pa svaka takva pozicija stoji u
stablu kao rupa i vraća se kao pitanje.

**Kvar koji je prijava otkrila usput, i on je pravi.** Širina se do sada mogla
promeniti **samo** kroz dijalog dugmeta „Predloži glavnu liniju", i čuvala se
**tek ako se izabere i dubina** — „Odustani" baca izbor. Dakle: čovek koji
sužava repertoar zato što mu aplikacija upisuje previše, morao je da joj dopusti
da upiše još jednu liniju da bi to uradio. To je oblik koji ovaj projekat već
zna: radnja i podešavanje spojeni u jedno dugme.

**Urađeno 5.9.2026:**

* `BreadthSettingDialog` — širina sama, bez dubine i bez kičme. Čuva na
  „Sačuvaj", vraća izabranu širinu pozivaocu (da je ekran usvoji odmah, što je
  bug zbog kog `current` uopšte postoji), i ostaje otvoren ako server odbije.
* Ulaz je **legenda ispod crteža**, red koji ionako kaže „Koliko odgovora:
  uobičajeno 80%". Mesto koje činjenicu izgovara je mesto na kome se menja —
  isto pravilo po kome odsečene grane stoje uz prekidač koji ih vraća. Ikonica,
  ne boja, jer boja nije nešto što svaki čitalac vidi.
* `onChangeBreadth` je opcion: tura (`repertoire_walkthrough_screen`) ga ne
  prosleđuje i tamo red ostaje običan tekst, a i ekran bez `id` repertoara ga
  ne nudi — `setBreadth` piše u red repertoara, pa bi dugme tamo bilo
  podešavanje koje tiho ne radi ništa.
* Red se **ponovo gradi**, ne dopunjava: širina odlučuje šta hod sadrži, pa
  pozicije upisane na staroj nisu manji deo novog odgovora nego odgovor na
  drugo pitanje. Tabla ostaje gde je.
* Tekst dijaloga kaže i šta sužavanje **ne** košta: potezi uzeti rukom i
  pozicije u kojima je već odlučeno prate se na svakoj širini (to je pravilo iz
  `coveredReplies` od 4.9.2026). Zato je rečenica u starom dijalogu — „Manje
  odgovora skriva grane koje ste već pripremili" — sada netačna i ispravljena;
  dva dijaloga koja o istom brojčaniku govore suprotno je tačno onaj oblik koji
  se kasnije razilazi.

Provera uživo: `docs/TODO-provera.md`, stavka **105**.

**Ostaje otvoreno, i vlasnik ga je izričito ostavio za posle:** „samo moji
odgovori" — širina sa **nula** automatskih odgovora. Uklapa se u postojeće
pravilo (`manual ⊆ main ⊆ standard ⊆ broad`), ali dira serverski hod, dril i
mapu pokrivenosti, i menja šta „pokrivenost" znači: bez knjige nema sa čim da
poredi, pa bi radar morao da kaže da meri nešto drugo.

## Crtež uvek sadrži poziciju na kojoj tabla stoji — 5.9.2026

Druga prijava iste večeri: „posle izbora poteza protivnika, taj potez se ne
prikazuje u stablu, a trebalo bi — da vidim i u stablu na šta treba da
odgovaram." Put je, na pitanje, bio **dugme „Idi"** na protivnikovom odgovoru
koji je već u pripremi.

**Prvo je izmeren server, i on nije kriv.** `tree()` sa lažnim poolom, tri
širine: odgovor uzet rukom (`repertoire_extra_replies`) crta se na **svakoj**
širini, uključujući `main`, a crta se i onaj na kome čitalac samo stoji
(`alongPath`). Dakle pravilo „ono što je čovek sam uradio se ne skriva" radi
tamo gde je napisano.

**Kvar je u klijentu, i to je zastarela pretpostavka a ne previd.**
`_loadTree` je nosio komentar: „nikad na običnom pomeranju — stablo se pomera
kad se pomere potezi." To je bilo tačno dok se crtež nije počeo čitati **od
mesta gde je tabla**: `maxPly` se od 4.9.2026 računa iz dubine na kojoj se
stoji, a `alongPath` je od 5.9.2026 linija na kojoj se stoji. Oba su funkcije
table, pa crtež pročitan na ranijoj poziciji zaista može da nema karticu za
ovu — a `_activeNode` tada (ispravno, po pravilu iz faze 1) ostavlja
osvetljenje na prethodnom potezu. Čitaocu to izgleda tačno onako kako je
prijavio: potez koji je upravo izabrao nije nigde.

**Pravilo koje je sada zapisano:** posle svakog pomeranja table, ako crtež ne
sadrži poziciju na kojoj se stalo — pročitaj ga ponovo. Jednom, ne u petlji:
ako ni novi crtež ne stigne dotle, osvetljenje ostaje gde je bilo. I samo ako
crtež uopšte postoji — bez njega je to otvaranje ekrana, gde `_resume` ionako
čita, pa bi provera značila dva čitanja pri svakom pokretanju. To je i uhvatio
postojeći test (`treeCalls`), pre nego što je stigao do telefona.

Cena je nula za kretanje unutar crteža koji već sadrži liniju — što je i drugi
test u paru.

Provera uživo: `docs/TODO-provera.md`, stavka **106**.

## Provera uživo 5.9.2026 popodne — 35 stavki zeleno, tri nalaza

Vlasnik je prošao stavke 104 (A, C, D, F, G), 105 i 106 u release bildu na
Windowsu. **Trideset pet stavki je potvrđeno**, uključujući ceo deo G (crtež
stoji dok se ide kroz liniju, pomeri se tek uz ivicu, zum se pri tome ne menja,
dugme za centriranje i dalje centrira), celu stavku 106 i devet od deset u 105.

Zabeleženo iz alata (`D:\Projekti\mislisha-test\qa`, `stanje.json`), i ovde
stoji ono što se ne vidi iz kvačica.

**Nijedan od tri nalaza nije kvar u aplikaciji.**

### 1. „Ne vidim baner" — stavke 104-F/25 i 105/5

Obe su pisane preko banera „N nepotvrđenih". Sa vlasnikovih slika se vidi zašto
ga nema: red ispod table kaže „odlučeno 12 · otvoreno 6 · bez odgovora 5%" i
**ne kaže „nepotvrđeno N"**, a taj deo rečenice postoji samo kad je
`walk.draft > 0`. Dakle repertoar je imao nula nepotvrđenih poteza i baner se
ispravno nije crtao — nema šta da prijavi.

Ime otvaranja **jeste** bilo u zaglavlju na obe slike („C54 · Italian Game:
Classical Variation, Giuoco Pianissimo"), pa polovina stavke 25 koja se mogla
proveriti prošla je; stavka 26 (dugme iz zaglavlja radi) je zelena.

**Popravljene su stavke, ne kod.** 105/5 sada traži broj iz reda ispod table,
koji postoji uvek; 104-F/25 kaže da prvo treba napraviti nepotvrđene poteze.
Pouka je opštija i vredi je pamtiti: **stavka provere koja se oslanja na
indikator koji postoji samo u jednom stanju je stavka koja se u drugom stanju
čita kao kvar.**

### 2. Suženje se ne pušta samo — stavka 104-D/20

Vlasnik: „ne pušta se, može samo u okviru stabla trenutno prikazanog, ali nije
problem, meni odgovara." Pravilo `_leftTheNarrowing` radi, ali nema šta da ga
okine: dok je crtež sužen, kretanje ide kroz ono što je nacrtano, pa se iz grane
i ne može izaći. Izlaz je dugme „Prikaži ceo repertoar". **Prihvaćeno kako
jeste**, stavka prepisana i zatvorena.

### 3. Poteze ne mogu da povlačim po tabli — uz stavku 104-A/2, zatvoreno

Vlasnik je stavku označio kao prolaz i uz nju napisao tu rečenicu, pa je pitanje
vraćeno njemu. Odgovor istog dana: **nije kvar** — probao je dok nije bio na
potezu. „Mogu da povlačim kad sam ja i tada je ista procedura kao da sam ga
izabrao sa liste — bila je opaska, nisam smatrao da mi smeta kao korisniku,
ovako je još bolje."

To je tačno ono što `isAllowedToMove` propisuje (`!_busy && _proposalUci == null
&& !_afterMyMove`), i potvrđuje pravilo iz faze 1: oba ulaza — potez povučen po
tabli i potez uzet sa spiska — vode kroz isti put.

### Zamka u alatu za proveru, nađena pri ovom upisu

`izvuci.py` deli id-jeve **po redosledu u fajlu** (`i%04d`, prosto brojanje), a
`stanje.json` je kljucan po tom id-u. Dakle **nova stavka umetnuta iznad
postojećih pomera id-jeve svemu ispod nje**, i odgovori se tiho zalepe za
druge stavke. Zaglavlje samog alata na to upozorava.

Danas je prošlo bez štete — deo H je umetnut iznad dela B, a B nije imao
nijedan odgovor, i tada iza 104 nije bilo ničega. Pravilo za ubuduće: **nove
stavke idu na kraj fajla**, ili bar iza svake koja već ima odgovor; a ako baš
moraju u sredinu, treba prvo prebrojati odgovore ispod tog mesta.

### Šta u 104 još nije gledano

B (lepeza u turi, 6–9), C/13 (visina dugmeta banera, odluka), D/22, E/23–24
(telefon), F/28–30, G/33–34 i cela **H** (zum preživi promenu veličine prozora,
35–39) — H je pisana danas i još nije prošla.

## Skener kaže koji je od tri problema — 5.9.2026, nije viđeno uživo

Vlasnik je 5.9.2026 pokušao četiri knjige. Sve četiri su pale, **svaka iz drugog
razloga**, a aplikacija je za sve četiri prijavila isti — i pogrešan — uzrok.

**Šta je izmereno** (pdfjs, sve strane svake knjige):

| knjiga | šta je zapravo | šta je aplikacija rekla |
|---|---|---|
| Reinfeld, 1001 žrtvovanje | 252 strane, **0 znakova teksta**, jedna slika po strani (92 dpi) | nepoznat font |
| Complete Book of Chess Strategy | 388 strana, **0 znakova teksta**, jedna slika po strani (400 dpi) | nepoznat font |
| Back to Basics: Openings | tekst postoji (OCR), ali su dijagrami slike — 433 slike na 224 strane | nepoznat font, uz glifove `e` (26×), `.` (18×), `t` (5×) — slova engleske proze |
| Grandmaster Codex | 4513 strana, LaTeX tekst, table crtane vektorski (177 putanja i 71 popuna u kvadratu 288×288) | „Skeniranje nije uspelo (500)" |

Nijedna od četiri nema font za koji bi se pisala mapa. Peta, `chessboard.pdf`,
prošla je bez ijedne izmene (`SkakNew`, 31 dijagram, 0 grešaka u glifovima) —
ali je to **uputstvo za LaTeX paket `chessboard`**, pa su joj „pozicije" primeri
sloga: 13 različitih na 31 nađenu, 9× početna pozicija, 9× ista tabla sa dva
kralja, i četiri nemoguće table koje su sve uredno označene.

**Prva popravka — tri odgovora umesto jednog.** `classifyUnreadable`
(`services/positionScanner/diagrams.mjs`) razlikuje `no_text` (na stranama nema
nikakvog teksta), `no_diagram_text` (teksta ima, ali nijedan red nema oblik
dijagrama) i `unknown_font` (redovi postoje, azbuka je nepoznata). Pravilo za
srednji slučaj je **definicija samog cevovoda bez azbuke**: osam redova oblika
reda složenih u jednu kolonu, preko `runsByColumn` koji izvlačenje ionako
koristi. Spisak nepoznatih glifova se sada računa **samo iz tih redova**, pa
proza ne može da se prijavi kao šahovski glif.

Zašto je to bitno: stara poruka je slala čitaoca da izvede mapu za font kog u
fajlu nema. Pogrešno imenovan uzrok je gori od neimenovanog.

**Druga popravka — 43 MB više ne izgleda kao pad servera.** `uploadRejection`
(`services/scanIntake.js`) i rukovalac greškom na kraju `routes/scans.js`:
`LIMIT_FILE_SIZE` daje **413** i rečenicu koja imenuje granicu (25 MB) i kaže
šta da se radi, sve ostalo 400 sa multerovom porukom. Ranije je multer prekidao
otpremanje pre nego što ruta uopšte krene, greška je odlazila Expressu, a klijent
je štampao samo broj statusa. Isti oblik je od 20.8.2026 na ruti za arhivu.

Klijent bira rečenicu po kodu (`scanFailureMessage` u
`scanner_api_service.dart`), a sve što ne prepoznaje pušta serverovu poruku —
zato što server zna brojeve koje ekran ne zna, kao što je granica u megabajtima.

**Testovi:** 9 novih na serveru (`positionScanner.test.mjs` +4, uključujući
prolaz kroz `scanDocument` sa sintetičkim PDF-om bez teksta;
`test/scan_upload_limits.test.js` +5, uključujući čitanje samog rutera — sloj
greške se prepoznaje po arnosti 4, ne po tekstu fajla) i 6 u aplikaciji
(`test/scan_failure_message_test.dart`). Sva četiri su dokazana mutacijom:
spuštanje praga sa 8 na 1 obara dva testa, vraćanje `unknown_font` u
`scanDocument` obara treći, uklanjanje rukovaoca greškom iz rute obara četvrti,
a spajanje dve poruke u jednu obara dartov.

**Ostaje:** provera uživo, stavka 107 u [TODO-provera.md](TODO-provera.md).

## Otvorena pitanja dizajna

Ona koja tek treba odlučiti stoje u [PITANJA-ZA-ODLUKU.md](PITANJA-ZA-ODLUKU.md),
sa procenom šta svaka mogućnost povlači. Ovde su odluke koje su **već** donete;
tamo one koje čekaju. Prvo na toj listi nije bio ekran nego jedna kolona —
`assignment_items.played_san`, urađena 20.8.2026, odeljak niže.

## Prvo pročitati: procena i plan

**https://claude.ai/code/artifact/a3456b17-94b0-4b56-a59f-44bebb02a77b**
(„Chess Master — Procena i Plan Rasta", 15.8.2026. — čita se preko `WebFetch`.)

Tamo stoji ono što se iz koda ne može rekonstruisati: **zatečeno stanje** pre
ovog posla, ocene po dimenzijama, pogled iz ugla trenera i učenika, poređenje sa
Chess.com / Lichess / Chessable / DecodeChess, predloženi model naplate sa
cenama, i plan u pet faza — a uz svaku stavku i **zašto** baš ona i baš tim
redom. To je izvor za svako „zašto smo se ovako dogovorili".

> **Pažnja: dokument opisuje stanje *pre* rada.** Faze 0–2 su u međuvremenu
> najvećim delom izvedene. Ko ga pročita bez ove tabele predložiće posao koji je
> odavno gotov.

| Iz plana | Stanje |
|---|---|
| Faza 0 — lažni Premium, prava pristupa, merenje troška | **Urađeno.** Naplata (Play Billing, RTDN, kvote) napisana i testirana, ali **nijedna prava kupovina** — čeka Play Console |
| Faza 0 — pravni okvir | Nacrti postoje (`politika-privatnosti.md`, `saglasnost-roditelja.md`); treba pravnik i hosting |
| Faza 0 — analitika i levak | **Nije rađeno** |
| Faza 1 — uvoz Lichess zagonetki, adaptivan izbor | **Urađeno.** 50.000 uvezeno (dostupno 6,1M) |
| Faza 1 — keširanje evaluacije | **Urađeno** (`EvalCache`) |
| Faza 1 — uvoz partija sa Chess.com/Lichess | **Urađeno** u Analysis Studio-u. Chess.com **potvrđeno uživo** (i jedan bag nađen i popravljen usput); Lichess strana čeka proveru — `TODO-provera.md`, stavka 7 |
| Faza 1 — dnevna zagonetka, niz dana | **Nije rađeno** |
| Faza 2 — domaći zadaci, napredak učenika, izveštaj za roditelja | **Urađeno**, ali izveštaj i zadaci **nisu provereni uživo** |
| Faza 2 — ponavljanje u razmacima (SM-2) | **Urađeno** |
| Faza 2 — grupe i prisustvo, chat i video | **Nije rađeno** |
| Faza 3 — višejezičnost, distribucija | **Nije rađeno.** Vidi `TODO-objavljivanje.md` |

## Gde smo

Aplikacija radi na Windows-u u debug režimu. Sesija, snimanje časa, čuvanje i
reprodukcija sa zvukom — sve prošlo uživo. Backend na `chess_backend` (Node +
PostgreSQL na DigitalOcean), pokreće se sa `npm run dev`.

Od 15.8.2026. postoji i **pravi server, potpuno postavljen i proveren, ali
namerno ugašen** — vidi „Nov server" niže. Aplikacija i dalje gađa lokalni
backend; prebacivanje čeka odluku o domenu.

Stanje provere funkcionalnosti se vodi u [TODO-provera.md](TODO-provera.md),
koraci za objavljivanje u [TODO-objavljivanje.md](TODO-objavljivanje.md).

## Šta je urađeno u ovom ciklusu

Redom, sa uzrokom — jer su tri greške bile u lancu i lako se pomešaju.

**1. Zamrzavanje ekrana pri snimanju** — `Stack` u `AnimatedMovePiece`
([board_overlay_painter.dart](../chess_app/lib/widgets/board_overlay_painter.dart))
ima isključivo `Positioned` decu, pa je uzimao veličinu roditelja. Tabla u sobi
stoji u `Column` unutar `SingleChildScrollView`, gde je visina beskonačna →
`size.isFinite` pukne u `performLayout()`. Flutter oko `_deviceUpdatePhase`
**nema `try/finally`**, pa izuzetak iz layout-a trajno zaglavi
`_debugDuringDeviceUpdate` i onda svaki frame i svaki pomeraj miša bacaju novu
grešku — otud hiljade `MouseTracker` poruka koje su izgledale kao uzrok, a bile
su posledica. Popravka: `SizedBox` oko `Stack`-a, jer je overlay po definiciji
veličine table.

**2. `ListTile` u `ColoredBox`** — `buildRightSidebar()` u
[chess_game_screen.dart](../chess_app/lib/screens/chess_game_screen.dart) je
vraćao `Container(color:)`, a `SwitchListTile` interno gradi `ListTile` kome
neproziran sloj krije pozadinu i ink. Flutter to prijavljuje **u svakom frame-u**.
Popravka: `Material` umesto `Container`. (`Card` je već `Material`, zato druga
slična mesta nisu bila problem.)

**3. Play u reprodukciji nije radio, zvuk se nikad nije čuo** —
[replay_player_screen.dart](../chess_app/lib/screens/replay_player_screen.dart).
Pozivi ka audio plejeru stajali su **ispred** kreiranja tajmera reprodukcije, pa
bi greška zvuka oborila ceo `_play()`. Uz to su bili ispaljeni bez `await`, pa se
`seek` trkao sa `play` i `setSourceUrl`. Popravka: tajmer se kreira **prvi**,
zvuk ide posle kroz `_startAudioFrom` sa `await`-ovima i `try/catch`. Time je
rešeno oboje — i Play i zvuk.

**4. Zamrzavanje pri otvaranju „Kreiraj lekciju"** —
[create_course_dialog.dart](../chess_app/lib/widgets/create_course_dialog.dart).
`AlertDialog` svoju decu uvek umotava u `IntrinsicWidth`
([dialog.dart:925](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/dialog.dart)).
Kad `content` **nije čvrste širine**, taj intrinsic prolaz siđe kroz
`SingleChildScrollView` do `Column`-a, a `RenderFlex` pri računanju poprečne
veličine traži *glavnu* (visinu) od svoje dece — i tako stigne do `ListView`-a i
`ReorderableListView`-a sa `shrinkWrap: true`. Lenji viewport ne ume da vrati
intrinsic dimenzije i baci `RenderShrinkWrappingViewport does not support
returning intrinsic dimensions`, pa dijalog ostane neraspoređen. Popravka:
`SizedBox(width: 380)` oko sadržaja — `RenderConstrainedBox` kod čvrste širine
vraća broj **bez** silaska u dete ([proxy_box.dart:250](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/rendering/proxy_box.dart)),
pa lanac nikad ne krene. Visina ostaje `maxHeight`, izgled nepromenjen.
Isti obrazac je preventivno popravljen i u
[save_position_dialog.dart](../chess_app/lib/widgets/save_position_dialog.dart)
(lista predloga labela puca isto, čim se ukuca slovo). Ostali dijalozi sa lenjim
listama već koriste čvrst `SizedBox`. Pokriveno testom
[dialog_layout_test.dart](../chess_app/test/dialog_layout_test.dart).

**Ostalo:** tap-to-move je postao dodatak prevlačenju (overlay je
`HitTestBehavior.translucent`, pa ne guta gest), podešavanje „Način izvođenja
poteza" je zato uklonjeno u celosti, i animacija klizanja figure je izbačena sa
*drag* puteva u sve tri table (figura je već putovala pod prstom — ponavljanje
izgleda kao dvostruki potez).

## Korisnik već ima objavljenu aplikaciju na Play-u

[Chess Brain Trainer: Puzzles](https://play.google.com/store/apps/details?id=com.program.braintrainer)
— `com.program.braintrainer`. Tri režima vežbanja kretanja figura (Sleepers,
Avoidance, King Hunt).

Zašto je to bitno, a ne anegdota:

- **Play Console nalog postoji**, $25 je plaćeno, identitet potvrđen, review već
  jednom prošao. To je bila prva stavka u `TODO-objavljivanje.md` i otpada.
- **Merchant nalog radi — potvrđeno 15.8.2026.** Brain Trainer prodaje Premium za
  pravi novac, a korisnik je sam kupio i potom **povratio novac**. Time su i
  naplata, i isplata, i refund tok već prošli kroz Google na ovom nalogu. Ovo je
  bila zabeležena nepoznanica; više nije. Za ovu aplikaciju ostaje samo da se
  naprave proizvodi i servisni nalog.
- **Postojeća publika** rešava šahovske zagonetke — to je tačno publika ove
  aplikacije. Unakrsna promocija između dva unosa pod istim nalogom je
  najjeftiniji kanal koji postoji.
- Korisnik je pomenuo da bi **neki deo Brain Trainer-a mogao da se uklopi** u
  ovu aplikaciju, ali izričito: „o tom potom". Ne otvarati bez njegovog povoda.

## Odluke i zašto

- **`applicationId` je `rs.pejovic.chesscoach`**, namerno odvojen od brenda. Ime
  „Chessmaster" je Ubisoft-ovo i ne dolazi u obzir. Posledica: na Windows-u su
  podaci sad u `AppData\Roaming\rs.pejovic\chess_app`, pa preuzeti Stockfish sa
  stare putanje izgleda kao da nedostaje.
- **Naplata ide preko Google Play-a**, jer je korisnik fizičko lice u Srbiji bez
  firme; Stripe tamo ne radi, a PayPal Srbija ne može rezident–rezident. Play je
  merchant of record i plaća prekogranično.
- **Animacija se zadržava** tamo gde figura *nije* putovala pod prstom: tap
  potezi, protivnikov odgovor, replay, autoplay rešenja, koračanje kroz stablo.
- **`chess_backend/uploads/` je u `.gitignore`** — sadrži prave snimke časova.
  Dečji glasovi ne smeju u repozitorijum. Ovo ne dirati.

## Zašto ostajemo na Agori (i pod kojim uslovom se to menja)

Razmatran je LiveKit, povodom Linux podrške. Odluka 15.8.2026: **ostaje Agora.**

Provereno u samim paketima, ne po sećanju:

- `agora_rtc_engine-6.6.3` deklariše `android`, `ios`, `macos`, `windows` i
  **`web`**. Nedostaje samo **Linux**.
- `livekit_client` podržava svih šest platformi, uključujući Linux.

Time se prednost LiveKit-a svodi na Linux jedini — a to je platforma sa najmanjom
publikom ovde. Cena te zamene je nesrazmerna: **Agora kod nas radi dva posla.**
Pored prenosa glasa, ona i **snima čas** — `startAudioRecording` piše *izmešan*
kanal u fajl, zato se u snimku čuju i trener i učenik. LiveKit nema pandan na
klijentu; njegovo snimanje je serverski **Egress** (zaseban servis, Redis, CPU za
mešanje), što na droplet-u sa 1 vCPU nije sitnica, uz TURN i opseg UDP portova.

Prelazak bi, dakle, značio **ponovno pisanje celog lanca snimanja** — sečenja
pauza, sinhronizacije, reprodukcije i MP4 izvoza — dakle baš onog dela koji je
tek proradio.

**Uslov pod kojim se odluka menja:** ako trošak Agore počne da se oseća. Meri se
kroz `agora_seconds` u `USAGE_UNIT_COSTS`, pa će se videti unapred.

### Web je izvodljiviji nego što izgleda — osim snimanja

Web bi ukinuo ceo problem instalacije: nema SmartScreen-a, sertifikata za
potpisivanje, `.exe` fajla ni Store pravila (vidi korak 3a u
[TODO-objavljivanje.md](TODO-objavljivanje.md)).

- **Motor je već rešen.** `stockfish_service_stub.dart` je verzija koja računa
  preko interneta (`lichess cloud-eval`, `stockfish.online`) — put za Web je
  predviđen u kodu. Analiza je slabija nego lokalni Stockfish, ali radi.
- **Glas radi**, jer Agora deklariše web.
- **Snimanje najverovatnije ne radi.** `AgoraRtcEngineWeb.registerWith()` je
  prazan, a u web sloju paketa nema nijednog pomena snimanja — ima kontrolera za
  video prikaz. To treba potvrditi malim ogledom pre nego što se bilo šta planira
  oko Web verzije.

Web bi tako bio: čas uživo, analiza, zagonetke i domaći — **bez snimljenih
časova**. To je i dalje mnogo, ali je odluka o tome šta proizvod jeste.

## Dogovoren model uloga i nadzora — 16.8.2026, još nije napisan

Zamenjuje predlog iznad. Dogovoreno u razgovoru; ovde stoji jer se iz koda neće
moći rekonstruisati zašto je baš tako.

### 1. „Trener" nije osobina osobe nego položaj u odnosu

Odatle sledi sve ostalo. **`users.role` se za podučavanje ne koristi uopšte** —
ostaje samo za `'admin'`. Ista osoba je trener u jednoj vezi i učenik u drugoj:
kao trener ima svoju listu učenika, kao učenik ima svoje trenere.

Time otpada pitanje koje nije imalo dobar odgovor — **ko dodeljuje ulogu trenera.**
Niko. Ne postoji gazda koji potvrđuje da je neko trener; postoji samo veza koju
su obe strane prihvatile.

### 2. Vezu pokreće bilo ko, ali je zasniva pristanak

```
zahtev  →  druga strana prihvati  →  [ako je učenik maloletan] roditelj potvrdi  →  veza važi
```

Smer je slobodan: trener sme da upiše učenika, učenik sme da pošalje zahtev
treneru. Ono što veza **ne** daje dok nije prihvaćena je bilo kakvo pravo.

Šema to podnosi sa jednom kolonom na `trainer_students`:

```sql
status VARCHAR(20) NOT NULL DEFAULT 'accepted'
  CHECK (status IN ('pending', 'awaiting_parent', 'accepted'))
```

Podrazumevano `accepted` usput reši i zatečene redove — u trenutku pisanja ih ima
**tri, na četiri korisnika, od kojih dva čine jedan uzajaman par** (to je i bio
viđeni bag). Sve novo se upisuje izričito kao `pending`, pa migraciona skripta ne
treba.

Bezbednosna ispravka je onda jedan uslov u `trainerOwnsStudent`
(`assignmentService.js`): `AND status = 'accepted'`. Kroz njega prolaze zadaci,
lekcije i izveštaj o učeniku.

Prijateljstvo (`friends`) se **više ne upisuje pri dodavanju nego tek pri
prihvatanju** — inače te neko ubaci među prijatelje bez tvog znanja.

### 3. Saglasnost roditelja se ne proverava — ona se zapisuje

Provera roditeljstva ne postoji ni kod jedne aplikacije; zakon i traži **razuman
napor srazmeran riziku**, ne dokaz. Zato: mejl roditelja, dvostruka potvrda, i
zapis o tome ko je pristao, kad, sa koje adrese i **na koju verziju teksta** —
poslednje zato što se dokument menja, a saglasnost mora ostati vezana za tekst na
koji je data.

Tri stvari koje su namerno tako:

- **Mejl roditelja stoji na vezi, ne na profilu učenika.** Dete može imati dva
  trenera, a saglasnost se tiče *tog* odnosa. Nov trener — nova saglasnost.
- **Traži se samo za maloletne**, pa nalog mora nositi godinu rođenja
  (samoprijavljenu). Odrastao učenik je ovde sasvim običan slučaj.
- **Povlačenje mora biti lako koliko i davanje** — to zakon izričito traži, pa
  link koji roditelj dobije ostaje važeći i nosi dugme koje raskida vezu.

> Zašto se time uopšte bavimo, kad TikTok ne pita nikoga: zato što se bave, i to
> skupo — TikTok €345M (irski DPC, 2023), Instagram €405M (2022), oba baš zbog
> naloga maloletnika. Ali brojke nisu razlog. Razlog je što je **suština ovog
> proizvoda** da se određena odrasla osoba spoji sa određenim detetom u privatnoj
> sobi, sa glasom koji se snima. TikTok se brani time da je javna platforma; ovde
> te odbrane nema. Uz to, Play Console pri objavljivanju **traži** da se prijavi
> ciljni uzrast — to je formular, ne stav.

### 4. Roditelj sme da posmatra svaki čas, i trener ne zna kad

Najjača zaštita u celom modelu, i istovremeno prodajni argument: roditelju koji
bira trenera preko interneta „možete ući na bilo koji čas i dobijate snimak
svakog" znači više od bilo kakvog opisa.

Radi zato što **mogućnost nadzora deluje trajno, a prisustvo samo povremeno.**

Jedna ograda je pravno bitna: **anonimno ne sme da znači tajno.** Trener je i sam
osoba čiji se glas snima, a prikriveno posmatranje je u većini propisa osetljivo.
Zato trener **pri registraciji prihvata pravilo** da svaki čas može biti posmatran
bez najave. Obavešten je o pravilu, ne o pojedinom času — odvraćajuće dejstvo
ostaje, a nadzor prestaje da bude prikriven. Isto važi i za dete.

Tehnički, oslanja se na ono što već postoji:

- **Roditelju ne treba nalog.** `signReportToken` (`middleware/auth.js`) već pravi
  potpisan token sa rokom kojim se izveštaj otvara bez prijave. Isti obrazac nosi
  i ulazak na čas i link ka snimku.
- **Posmatrač mora biti izostavljen iz spiska učesnika**, i to je pravi posao a ne
  prekidač: soba preko Socket.IO razašilje ko je ušao, a snimak upisuje
  `participantIds`. Ako se to ne uredi namerno, trener vidi ulazak i cela zamisao
  pada. Agora ima ulogu *audience* koja sluša bez objavljivanja, pa glasovna
  strana to podnosi.
- **Snimci se šalju kao link mejlom**, istim mehanizmom i sa rokom, kao izveštaji.

### Šta je odlučeno, a šta čeka

Odlučeno i spremno za pisanje: tačke 1, 2 i 4 — pristanak, smer, i posmatranje.

Čeka pravnika: tekst saglasnosti (`saglasnost-roditelja.md`) i da li je opisani
postupak dovoljan po ZZPL-u. **Kolone se ipak dodaju odmah**, jer prazna kolona
danas ne košta ništa, a ista kolona nad živim podacima kasnije košta migraciju.

## Ako droplet postane tesan, kojim redom — 17.8.2026

Zapisano jer je lako pretpostaviti da se MP4 izvoz „samo prebaci na drugu
mašinu". Ne prebacuje se: `routes/recordings.js` uzima zvuk iz `uploads/` sa
**lokalnog diska**, a `videoRenderer.js` piše gotov fajl u `exports/`, isto
lokalno. Druga mašina bi morala da dođe do tog zvuka — a `uploads/` je jedina
kopija dečjih glasova.

Redosled kad zatreba:

1. **Veći droplet.** Jedan restart, nijedna izmena u kodu. Za 1 vCPU / 2 GB je to
   najjeftiniji potez i verovatno dovoljan zadugo.
2. **Odvajanje izvoza tek uz konkretan simptom** — da renderovanje usporava API,
   ili da veći droplet više ne pomaže. Povlači prelazak `uploads/` na objektno
   skladište, što uzgred rešava i to da su snimci danas na jednom disku.

Sajt ne učestvuje ni u jednom koraku: statičke stranice nginx servira bez CPU
troška, pa ostaje gde jeste i u slučaju da se izvoz odseli.

## Dve greške nađene 22.8.2026 — obe zatvorene 27.8.2026

Obe je korisnik primetio u Windows verziji dok je proveravao trener završnica,
i obe su bile van onoga što je tada rađeno. Zapisane su namerno neurađene.

**Zašto su čekale — odlučeno 23.8.2026.** Projekat je još u izgradnji i korisnik
je zasad **jedini koji ga koristi**: nema deteta kome se mikrofon otvara i nema
tuđeg naloga koji ostaje zaglavljen u poluprijavljenom stanju, pa je stvarna
cena obe greške tada bila nula. Obe ipak moraju biti zatvorene pre nego što
aplikaciju dotakne iko osim vlasnika — glas zato što otvara mikrofon detetu i
troši novac, istek tokena zato što tuđi korisnik nema odakle da zna da treba
ručno da se odjavi. Obe su zatvorene 27.8.2026, u istom prolazu.

### Glas se uključivao sam i naplaćivao se — zatvoreno 27.8.2026

`_initAudioChat()` se pozivao **bezuslovno iz `initState`** u
[chess_game_screen.dart](../chess_app/lib/screens/chess_game_screen.dart) — čim
se uđe u sobu, tražio se Agora token, otvarao se glasovni kanal i backend je
počinjao da meri. Iz korisnikovog loga:

```
19:58:50  [AUDIO] User pavle joined audio in room STUDIO
19:59:07  [AUDIO] User 5 left audio in room STUDIO
19:59:08  [AUDIO] Booked 18s of voice for user 5
```

Osamnaest sekundi glasa naplaćeno za sesiju u kojoj niko nije nameravao da
priča; minut ranije još četiri. Agora se plaća po minutu **prisustva u kanalu**,
ne po minutu govora, i `usage_counters` to broji kao potrošnju.

Nije bio samo trošak. **Mikrofon se otvarao pre nego što je iko rekao da hoće
razgovor**, a većina korisnika su deca.

**Kako je rešeno.** Ulazak u kanal je sada na dugme, za sve — korisnikova odluka
od 27.8.2026, čime pada i ograda koja je ovde stajala („trener možda očekuje da
ga se čuje odmah"): trener pritisne isto dugme kad počne čas. Kanal se otvara
samo kroz `_joinVoice()`, i zatvara kroz `_leaveVoice()` bez izlaska iz sobe.

Ono što ovo drži da ne postane tišina: `audio_users_list` se emituje **celoj
sobi**, ne samo onima u kanalu, pa onaj ko nije uključio glas vidi da se
razgovara i dobija dugme **„Priključi se razgovoru"** umesto „Uključi glas". Bez
tog reda učenik bi sedeo u tišini ne znajući da ima šta da se čuje.

Tri sitnice koje su izašle usput, sve tri iste vrste:

- `voice_level_changed` (trener daje ili oduzima reč) je zvao `_rejoinVoice()`
  bezuslovno — kod nekoga ko nikad nije ušao u glas to bi **otvorilo kanal na
  trenerov pritisak, na učenikovom uređaju**. Sada se odbija ako je glas
  isključen, a poruka to i kaže: „Važi čim uključite glas."
- Neuspeo ulazak vraća panel na dugme, sa razlogom iznad njega; inače bi nudio
  „Isključi glas" za kanal u kome niko nije.
- Studio nema glas uopšte (vidi popravku studija niže).

`test/voice_on_request_test.dart` čuva pravilo: `initState` ne sme da pomene
nijedan ulazak u glas, `_initAudioChat` sme da ima **tačno dva** pozivna mesta
(dugme i ponovni ulazak), a `_rejoinVoice` mora da ima ogradu. Dokazano
mutacijom — vraćen poziv u `initState` i uklonjena ograda obore tri testa.
Funkcije se čitaju **poklapanjem zagrada**, i komentari se skidaju pre provere,
jer komentar koji pominje poziv nije poziv.

Ostaje provera uživo: dva naloga u istoj sobi, jedan uključi glas i drugi vidi
„Priključi se razgovoru"; i pogled u log da posle ulaska u sobu nema
`[AUDIO] joined` dok se dugme ne pritisne.

### Istekao Agora token je gasio glas usred časa — popravljeno 27.8.2026

Nađeno čitajući isti kod. Token se izdavao **jednom, pri ulasku**, i trajao
`AGORA_TOKEN_TTL_SECONDS` (podrazumevano 3600). U celom `lib/` nije bilo ni
`renewToken` ni `onTokenPrivilegeWillExpire`, pa je čas duži od sat vremena
ostajao bez zvuka — bez poruke, bez reda u logu, sat vremena posle greške. Isti
oblik kao sve ostalo u toj sekciji CLAUDE.md-a.

Agora javlja **30 sekundi ranije** (`onTokenPrivilegeWillExpire`), i još jednom
kad je već kasno (`onRequestToken`). Oba sada vode u jedno mesto koje ponovo
pita server — a `/agora/token` svaki put iznova pita `maySpeakInRoom`, pa
osvežavanje nije samo produžetak nego i ponovna provera prava.

Odluka je izdvojena iz radnje (`AgoraService.refreshAction`) da bi mogla da se
testira bez engine-a, časa i sat vremena čekanja. Četiri odgovora, jer „uzmi nov
token" je tačno samo ako se ništa drugo nije promenilo:

- **soba odbija** (izbačen sa spiska usred časa) → izlazak iz kanala i poruka, a
  ne tiho ostajanje dok Agora ne preseče;
- **nema odgovora, ili server nema sertifikat** (prazan token) → pita se ponovo,
  jer bi `renewToken('')` prekinuo baš vezu koju poziv čuva. Tri pokušaja na osam
  sekundi, sve unutar prozora od 30 s; kad se potroše, kanal se **ostavlja na
  miru** — server koji se ne javlja nije soba koja je odbila;
- **pravo se promenilo** (dobio ili izgubio mikrofon) → pun ponovni ulazak, jer
  `renewToken` menja token a ne ulogu: učenik kome je mikrofon upravo dat držao
  bi publisher token kao `audience`;
- **ista stolica, nov token** → zamena u mestu, niko ne čuje prekid.

`test/voice_seat_test.dart` drži sva četiri, dokazano mutacijom (uklonjene grane
`refused` i `token.isEmpty` — oba testa padaju). Ostaje provera uživo: čas duži
od TTL-a, ili privremeno smanjen `AGORA_TOKEN_TTL_SECONDS` da se ne čeka sat.

### Istekao token nije odjavljivao korisnika — zatvoreno 27.8.2026

```
19:56:25  [SOCKET AUTH] Rejected connection: jwt expired
```

Socket je bio odbijen, a klijent to nije tumačio kao kraj sesije. `401` se hvatao
jedino u
[server_status_service.dart](../chess_app/lib/services/server_status_service.dart),
i to samo da bi se ispisala traka na kontrolnoj tabli. Posledica koju je korisnik
prijavio: aplikacija kaže da treba da se prijavi ponovo, i dalje ga smatra
prijavljenim, pa **mora prvo ručno da se odjavi** iz sesije koju je server već
odbacio.

Sada postoji jedno mesto koje „server ne prima ovaj uređaj" pretvara u odlazak
sa ekrana: `SessionService.expire(reason)` postavlja razlog, ruter ga sluša
(`refreshListenable` + `expiredSessionRedirect`) i vodi na prijavu **odakle god
korisnik bio**, a ekran za prijavu pročita razlog i kaže ga. Dva razloga, ne
jedan, jer traže suprotne stvari od čoveka: `expired` čeka istu osobu da se
prijavi ponovo, `account-gone` nema koga da prijavi.

Četiri ulaza vode u to jedno mesto, po redu koliko rano hvataju:

1. **Sam token, pri pokretanju.** `SessionService.init()` ne obnavlja zapamćenu
   sesiju čiji je `exp` prošao — inače aplikacija pozdravi po imenu, a svaki
   zahtev iza tog pozdrava bude odbijen. Čita se iz tokena, bez mreže, jer
   odluka pada pre prvog ekrana, a to što nema veze nije razlog da se veruje
   mrtvom papiru.
2. **Povratak u prvi plan** (`SessionWatch` u `main.dart`) — telefon ostavljen
   preko noći sa otvorenom aplikacijom. Poređenje, ne upit.
3. **Soket**, koji je i najbrži signal: server odbija rukovanje pre nego što
   ijedan ekran bilo šta zatraži. `looksLikeRefusedToken` razlikuje tu rečenicu
   (`Invalid or expired authentication token`) od običnog `websocket error` —
   odjaviti nekoga zato što je pao vaj-faj bilo bi gore od greške koja se ovde
   popravlja.
4. **`_checkServerAndSession`** na kontrolnoj tabli sada dela i na `expired`, ne
   samo na `gone`. `offline` i dalje ne radi ništa, iz istog razloga.

Isto pravilo kao na serveru (`services/accountGuard.js`): **„ne znam" ne sme da
stigne kao „napolje si"**. Token koji ovaj parser ne ume da pročita, `exp` koji
ne postoji, server koji ćuti — ništa od toga nije odbijanje.

`test/session_expiry_test.dart` (16 provera) drži i jedno i drugo lice pravila,
dokazano mutacijom: uklonjena provera `exp`-a u `init()` i `looksLikeRefusedToken`
koji uvek kaže „da" — oba obore po jedan test.

**Šta nije urađeno:** 53 mesta u `lib/` (25 fajlova) i dalje šalju
`Authorization: Bearer` ručno i ne rade ništa posebno sa `401`. Prolaz kroz sva
nije napravljen; praktično se ne oseti, jer soket na istom ekranu dobije isto
odbijanje u istoj sekundi i sesija se završi pre nego što taj `401` išta znači.
Kad se bude radilo, ide kroz jedan `http.Client` omotač, ne kroz 53 izmene.

Ostaje provera uživo: prijaviti se, ručno skratiti `JWT_EXPIRES_IN` na serveru
(ili izmeniti sat), sačekati istek i videti da aplikacija sama završi na ekranu
za prijavu sa porukom „Prijava je istekla".

## Roditeljska saglasnost: tekst je potvrđen, tok nije napisan

**Advokat je 25.8.2026 potvrdio** da su politika privatnosti i obrazac
saglasnosti ispravni i da pokrivaju ono što aplikacija stvarno radi —
uključujući snimanje glasa dece, koje je i bio razlog da se pišu. Time je pao
jedini razlog zbog kog tok nije napisan: čekao se tekst, ne kod.

**Ograda je njegova, ne naša:** proverio je za Srbiju i rekao da za druge države
ne zna. Iz toga slede dve stvari, i obe su inženjerske:

1. **Gde se aplikacija nudi je odluka, a ne podrazumevana vrednost.** Play deli
   svuda ako mu se ne kaže drugačije. Dok pravna provera pokriva jednu državu,
   spisak zemalja treba suziti na nju.
2. **Uzrast ide u podešavanje, ne u `if`.** Granica ispod koje je saglasnost
   obavezna razlikuje se po državama, pa je nijedan broj u kodu ne sme
   predstavljati kao univerzalnu. Isto važi za sam tekst: verzija na koju je
   neko pristao upisuje se u `parent_consent_version` — kolona postoji od ranije
   i do sada je bila prazna.

Šta je u bazi već pripremljeno, a nema ko da napuni: `trainer_students` ima
`parent_email`, `parent_consent_at`, `parent_consent_ip` i
`parent_consent_version`, i status `awaiting_parent` između `pending` i
`accepted`. Oblik toka je dakle već zamišljen — veza sa trenerom ne postaje
`accepted` dok roditelj ne potvrdi.

Popunjena verzija dokumenata (ime, adresa, email, URL) **ne ide u ovaj
repozitorijum**, jer je javan; u `docs/` ostaju nacrti sa praznim poljima, koji
su ionako ono što opisuje šta aplikacija radi.

## Rizik koji nije u tekstu saglasnosti nego u obliku aplikacije

Primedba je korisnikova i tačna: problem u drugim državama verovatno neće biti
*šta* aplikacija radi sa podacima — to pokriva saglasnost — nego **da li
izgleda kao mesto na kom se maloletnici povezuju međusobno**. Propisi koji
ograničavaju decu na društvenim mrežama (Australija ima zakon za mlađe od 16;
sličnih predloga ima i drugde) kače se za oblik: veze korisnik–korisnik,
pronalaženje drugih korisnika i direktna komunikacija. Ne za temu.

**Kod nas je ta površina mala i uglavnom već zatvorena pristankom** — veza
trener–učenik ne postoji dok druga strana ne prihvati, i test pada ako neko
napiše četvrtu kopiju tog uslova bez `status = 'accepted'`.

**Jedan izuzetak, i on je oštar:** `POST /friends/add` prima **email**, nađe
korisnika i odmah upiše vezu **u oba smera, bez ijednog pristanka druge
strane**; `GET /friends` zatim vraća ime i email. Dakle svako ko zna email
deteta može sebe da ubaci u njegov spisak — i to je istovremeno ono što najviše
liči na društvenu mrežu i jedina rupa u modelu pristanka koji je svuda drugde
poštovan. U aplikaciji to je tab „Ljudi".

Tri izlaza, od najjeftinijeg:

1. **Prijateljstvo dobija pristanak**, isto kao veza trener–učenik: `pending` →
   `accepted`, isti obrazac koji već postoji i već je testiran.
2. **Maloletnik nema prijatelje, nego samo trenera.** Najjači odgovor na pitanje
   o državama, jer aplikacija tada nije mesto gde se deca povezuju međusobno —
   a jeftin je, pošto model veze već postoji.
3. **Izbaciti prijatelje.** Tab „Ljudi" bi pokazivao trenere i učenike. Time se
   pravna površina svodi na „alat za podučavanje" umesto na „mrežu".

Uz bilo koji od njih: spiskovi ne treba da vraćaju **email** drugog korisnika.
To je podatak koji tamo ništa ne rešava, a jeste podatak o detetu.

**Teže od prijatelja: soba nema spisak zvanica.** Nađeno 25.8.2026, dok se
proveravala tuđa preporuka da se „glas isključi maloletnicima". Ta preporuka
promašuje metu — glas *jeste* čas, trener drži lekciju glasom i snima je — ali
je pokazala pravo pitanje: ne da li dete sme da priča, nego **ko sme da bude u
sobi dok priča**. Odgovor je danas: bilo ko.

    socket.on('joinGame', async ({ roomId, playerColor }) => {
      socket.join(roomId);

`joinGame` u `server.js` ne proverava ni vezu trener–učenik, ni poziv, ni to da
li je pozivalac uopšte prijavljen — gost ulazi kao „Gost". `audio_join` je isti,
pa ko uđe u sobu, uđe i u glas; ako trener snima, taj glas ide u `uploads/`,
među snimke dečjih glasova. Kod sobe je šest cifara iz `Math.random()`
(`routes/rooms.js`), bez ograničenja broja pokušaja.

To je gore od `/friends/add`: prijatelj vidi email, a ovo je neko u živom
razgovoru sa detetom. Zato ide **prvo**, pre svega ostalog oko saglasnosti.

## Odakle sutra — 26.8.2026, 00:20

Sve je commitovano i **pushovano** (`493f8db`), droplet je povučen na isti
commit, CI se pokrenuo i nije proveren.

**Sajt stoji na jednom koraku:** u `.env` na dropletu fale `PRIVACY_EMAIL` i
`SUPPORT_EMAIL`, jer adrese na domenu još ne postoje. MX zapisi
`chesstrainers.app` već pokazuju na Namecheap-ovo preusmeravanje
(`eforward1–5.registrar-servers.com`), pa je posao samo dodati aliase u panelu
i proslediti ih na Gmail. Ostale vrednosti su upisane i proverene
(`OPERATOR_NAME`, `OPERATOR_ADDRESS`, hosting, `SMTP_PROVIDER=Google (Gmail)`,
datum, `EXPORT_RETENTION_DAYS=14`). Posle toga je objava jedna komanda:
`LE_EMAIL=… bash deploy/site-setup.sh` — i **pre nje prevod stranica na
engleski**, po odluci iznad.

**Nađeno usput, popravljeno na dropletu:** `MAIL_FROM` je glasio
`Chess Master <…@gmail.com>` — Ubisoft-ov brend u pošiljaocu svake poruke,
uključujući poruku roditelju. Ime je promenjeno u `Šahovska obuka`; adresa nije
dirana, jer Gmail ne šalje sa neverifikovane. **Isti red skoro sigurno stoji i u
lokalnom `.env`.**

**Zamka na koju sam nasankao, da se ne ponovi:** `git fetch --depth 1 origin
master` na plitkom klonu ostavi `origin/master` na starom commitu, pa
`checkout -B master origin/master` „uspe" i vrati stari kod. Traži izričit
refspec `+refs/heads/master:refs/remotes/origin/master` — kako i piše u
`deploy/app-setup.sh`, dva reda iznad te komande. I dalje: **ne pokretati
`app-setup.sh`** samo radi povlačenja koda, jer on radi `systemctl enable` i
`restart` servisa koji je namerno ugašen.

**Ostalo otvoreno, po veličini:** prevod sajta i pravni status prevoda; nivoi
pretplate (`CENA-I-PRETPLATA.md`, odeljak 7); `checkUserLimits` bez pozivaoca;
slanje pošte sa domena (SPF/DKIM) umesto sa lične Gmail adrese;
`PUBLIC_BASE_URL` prazan na dropletu. ~~Kanvas sa predlozima za panel
trenera, koji čeka izbor varijante~~ — kanvas je napravljen 26.8.2026, korisnik
je 27.8.2026. izabrao **A + značka iz C**, i to je napisano; ostaje samo provera
uživo (stavka 39 u [TODO-provera.md](TODO-provera.md)).

## Sledeće, po redu

Stanje na kraju 24.8.2026. Sve iz prošlog spiska pod 2–6 je urađeno; ostaje
ovo.

1. **Provera uživo onoga što još nije viđeno.** Tačke `0l`–`0p` u
   [TODO-provera.md](TODO-provera.md). Korisnik je prošao navigaciju, tabove i
   desktop prečice i našao tri stvari koje su odmah popravljene (nestali tabovi
   pri izlasku iz vežbe, nevidljiva podešavanja na Windows-u, Ctrl+, vezan za
   pogrešan taster). **Nije još viđeno:** sve oko govora na telefonu, nalaz
   tablica, „Zaključi remi", i rute zadataka.

2. ~~**Spisak prečica**~~ — urađeno 24.8.2026, **nije viđeno uživo** (stavka
   23 u [TODO-provera.md](TODO-provera.md)). Ruta `/shortcuts`, a otvaraju je
   **F1** i red „Spisak prečica" u Podešavanjima — na telefonu, gde tastature
   nema, taj red je jedini put.

   `?` namerno **nije** vezan, iako je bio predviđen: to je znak koji neko može
   da kuca u komentar ili u kod sobe, a prečica iznad cele aplikacije bi mu ga
   uzela iz polja. F1 nijedan raspored ne kuca — ista pouka kao Ctrl+, vezan po
   mestu tastera, a ne po znaku.

   Spisak ne može da zastari ćutke: test čita `desktop_shortcuts.dart` i
   `move_keyboard_shortcuts.dart`, vadi svaki `LogicalKeyboardKey` iz njih i
   pada ako se veže taster koji na spisku ne piše. Zato i piše, uz svaku grupu,
   *gde* radi — strelice su za sada samo u šetnji kroz partiju, i tako i stoji.

3. ~~**Ostale prečice**~~ — sve tri stavke urađene 24.8.2026. Strelice i
   Ctrl-prečice su i **proverene uživo** istog dana (stavke 24 i 25 u
   [TODO-provera.md](TODO-provera.md)); slova u treneru završnica i razmak u
   reprodukciji još nisu (stavka 26). Dogovoreno je bilo, ovim redom:
   - ~~Ctrl+1…4 za četiri taba, Ctrl+C za kopiranje FEN-a~~ — urađeno i
     **provereno uživo** 24.8.2026 (stavka 25 u
     [TODO-provera.md](TODO-provera.md));
   - ~~strelice na preostalih pet ekrana~~ — urađeno 24.8.2026, **nije viđeno
     uživo** (stavka 24 u [TODO-provera.md](TODO-provera.md)). Analiza, soba,
     lekcija, ponavljanje i AI ekran; `MoveKeyboardShortcuts` je isti omotač
     koji je šetnja kroz partiju već imala, plus Home/End kao drugo ime za
     ↑/↓. Dva mesta su dobila i ogradu koja nije bila u planu: u **ponavljanju**
     tasteri rade tek kad je nastavak otkriven, jer bi inače tastatura govorila
     odgovor pre nego što se dete seti; u **sobi** važi isti uslov koji traka
     već ima (`canDriveSharedBoard`), da mesto koje ne vodi zajedničku tablu ne
     povede je tastaturom. Uz to, na svakom od pet ekrana kursor se sada pravi
     na **jednom** mestu (`_moveCursor()`) umesto po jednom za traku i jednom za
     tastere. Test čita `lib/` i pada ako ekran sa trakom nema i strelice;
     jedini izuzetak je `engine_line_dialog`, jer dijalog drži fokus i uzeo bi
     tastere ekranu ispod sebe;
   - ~~u treneru završnica slova: N sledeća, R ispočetka, H pomoć, T nalaz,
     U vrati potez; razmak za pusti/pauziraj u reprodukciji~~ — urađeno
     24.8.2026, **nije viđeno uživo** (stavka 26 u
     [TODO-provera.md](TODO-provera.md)). Time je spisak pod 3 završen.

     Slova i razmak dele jedan omotač, `ActionKeyShortcuts`: dobija mapu
     taster → dugme, gde **null znači da tog dugmeta sada nema na ekranu**.
     To je pravilo koje drži spisak prečica istinitim — taster radi tačno
     onoliko koliko i dugme koje predstavlja, pa nema stanja u kom tastatura
     ume nešto što se na ekranu ne vidi. U treneru je mapa pisana kao ogledalo
     `_buildControls`, uslov po uslov, uključujući i zaključanu tablu dok
     tablica odgovara.

     **Razmak je jedini taster koji namerno ustupa mesto.** Fokusirano dugme
     na razmak odgovara samo, i to je pravilo koje aplikacija ne sme da
     razbije: ko šeta ekran Tab-om mora da može da pritisne ono na čemu je
     stao. Zato je razmak vezan samo dok fokus drži sam omotač. Slova takvog
     suparnika nemaju.

   Dve ograde: prečica **nikad nije jedini put** do radnje, jer na Androidu
   tastature nema; i **jedno slovo samo na ekranima bez unosa teksta**, pošto
   dok je fokus u polju to slovo pripada polju.

   **Tri stvari koje je ovaj krug naučio, i koje važe za svaku sledeću
   prečicu.**

   *Prvo: prečica vezana unutar ekrana ne radi dok ekran ne drži fokus.* Pritisak
   se nudi onome ko ima fokus pa redom njegovim precima — vezivanje koje sedi
   *ispod* fokusiranog čvora niko nikad ne pita. Tek otvoren ekran ostavlja
   fokus na samoj ruti, pa su strelice ćutale sve dok se na ekranu nešto ne
   klikne. Izgleda kao „ponekad radi", što je najgori oblik kvara. Lek je jedna
   linija: omotač drži `Focus(autofocus: true, skipTraversal: true)` — uzima
   fokus samo ako ga niko drugi ne traži, pa polje za tekst i dalje dobija svoje
   tastere kad se u njega klikne. Test `move_keyboard_shortcuts_test.dart` pritiska
   strelicu **bez ijednog klika pre toga** i pada ako se to vrati.

   *Drugo: `CallbackShortcuts` proguta taster i kad ništa nije uradio.* Ctrl+C
   vezan tako je uzimao kopiranje svakom polju za tekst u aplikaciji — a to
   vezivanje stoji bliže fokusu nego Flutter-ovi ugrađeni tasteri za tekst, pa
   je pobeđivalo. Zato je Ctrl+C napisan kao `Action` koji ume da **odbije**
   taster (`isEnabled` je netačno dok se kuca ili kad table nema): odbijen
   taster putuje dalje i polje odradi svoje kopiranje. Isto važi za svaku
   buduću prečicu koja se preklapa sa nečim ugrađenim.

   *Treće, nađeno pri poslednjoj stavci: spisak prečica je bio nepotpun, a test
   to nije video.* Test je čitao tri fajla po imenu, a stablo poteza u Analizi
   veže **+** i **−** iz četvrtog — ni jedno ni drugo nije bilo na spisku, jer
   fajl koji je dobio prečicu niko nije dopisao u test. Sada se čita ceo `lib/`,
   pa nema liste koja mora da se održava da bi test radio; izuzet je samo sam
   omotač, koji imenuje tastere kojima **ustupa** mesto, a ne veže nijedan svoj.
   Tri prečice stabla poteza su usput dopisane na spisak, uz „gde radi" — one
   traže da se prvo klikne u stablo.

4. **Pamćenje veličine i položaja prozora.** Traži nativni dodatak
   (`window_manager`) — odluka o zavisnosti, ne usputan posao. Posle
   `flutter_tts`-a i `nuget`-a vredi je doneti svesno.

5. ~~**Lichess, dve stavke.**~~ — urađeno i **provereno uživo** 24.8.2026
   (stavka 22 u [TODO-provera.md](TODO-provera.md)). Baza otvaranja ide kroz
   `GET /opening-explorer`: jedan token stoji u `.env` na serveru, keš je isti
   oblik koji `tablebaseService` ima za tablice, i token je prestao da bude
   uslov za korisnika. Dugme sa pre-popunjenim linkom je ostalo u Podešavanjima,
   ali sada za onoga ko *hoće* svoj — polje uz njega je izlaz u nuždi ako naš
   token ikad bude odbijen.

   Dve stvari koje treba znati pre nego što se pusti u rad: **`LICHESS_API_TOKEN`
   mora u `.env`**, inače ruta vraća 503 sa `reason: "not-configured"` i svi
   dobijaju ChessDB; i **jedan token je jedno grlo za sve**, pošto Lichess broji
   upite po tokenu. Keš zato nije ušteda nego uslov — pozicije iz otvaranja se
   kod sve dece ponavljaju, pa je pogodak čest. Ruta traži prijavu (`authenticateToken`)
   da ne bi bila otvoren proksi čim server izađe na internet; gost dobija ChessDB,
   što je tačno ono što je i pre imao.

6. **Unija „Dobij" i „Greške iz partija"** — procenjeno i odloženo. Šetnja
   nema „Odigraj do kraja" ni igranu kaznu. Kad se bude radilo, izdvojiti alate
   nad pozicijom u zajedničku komponentu umesto spajanja ekrana.

7. ~~**Trenažer repertoara**~~ — **svi delovi su urađeni 31.8.2026**, nijedan
   nije viđen uživo (stavke 29, 30, 62–66 u [TODO-provera.md](TODO-provera.md)).
   Skica je u [repertoire_trainer_spec.md](repertoire_trainer_spec.md); gradilo
   se odozdo, jer je celina bila najveća stavka koja je do tada predložena i
   takmičila se sa objavljivanjem.

   - ~~**Sudija** — jedan endpoint i panel u Analizi~~ — urađeno i provereno
     uživo 24.8.2026. Vredi sam za sebe i bez ijednog repertoara, i dokazuje
     priču o kešu i opterećenju pre nego što se na njoj zida.
   - ~~**Režim izgradnje**~~ — urađeno 24.8.2026, nije viđeno uživo (stavka
     29). Prag je 80% u izabranoj traci, najviše četiri odgovora, a ostatak se
     broji i prijavljuje. Odluke su u odeljku „Repertoar: režim izgradnje".
   - ~~**Uvežbavanje**~~ — urađeno 24.8.2026, nije viđeno uživo (stavka 30).
     Kroz postojeći SM-2, ali sa svojom tabelom `repertoire_reviews`; zašto ne
     kroz proširen `review_items`, piše u odeljku „Repertoar: drill".
   - ~~**Putanja i izvedena granica**~~ — urađeno 31.8.2026, nije viđeno uživo.
     Ekran za izgradnju sada kaže u kojoj je liniji i nastavlja tamo gde je
     stao. Odeljak „Repertoar: gde sam u stablu".
   - ~~**Radar pokrivenosti**~~ — urađeno 31.8.2026, nije viđeno uživo.
     Ispalo je tačno onako kako je i procenjeno: nijedan nov račun i nijedna
     nova ruta, samo `branches` iz iste šetnje. Odeljak „Radar pokrivenosti".

   Tri odluke koje važe za sve delove: repertoar živi **na serveru**, ne u
   lokalnoj bazi, jer ga trener zadaje i gleda, a reinstalacija ne sme da
   obriše godinu dana rada; rang se bira **prema učeniku**, ne fiksnih „1800+",
   pošto dete sreće poteze od 1200; i kazna se **odigra**, ne objasni — za to
   već postoje „Kazni" i „Odigraj do kraja" iz trenera završnica.

8. **i18n na kraju**, kad prestanu da se menjaju ekrani. Odluka i razlozi su u
   odeljku „Sistematizacija prostora".

## Šta namerno nije urađeno

- **`CustomPuzzleSolverScreen` nema rutu** — nosi povratni poziv `onAnswered`,
  dakle je korak u toku, ne mesto.
- **`AiStudioScreen` nije formatiran** `dart format`-om — nad tim fajlom pravi
  850 izmenjenih linija umesto 40 i obara `analyze`. Formatira se kad se bude
  delio, i tada mu ide i pravo ime: nema veze sa AI.
- **Unija „Dobij" i „Greške iz partija"** — procenjeno, korisnik odložio.
  Šetnja i dalje nema „Odigraj do kraja" ni igranu kaznu.

## Brojke, da se vidi da li je nešto puklo

`cd chess_app && flutter test` → **653**, `flutter analyze` čist.
`cd chess_backend && npm test` → **517**.

## Sledeće na redu

Poređano po odnosu dobitka i uloženog. Sve sa ranije liste (admin nalog, swap,
politika brisanja fajlova, uvoz partija, MP4 izvoz) je urađeno i provereno
uživo. Ostaju:

- **Prvo: rad na aplikaciji.** Korisnik je 16.8.2026. rekao da ima još izmena u
  samoj aplikaciji, pa je **prebacivanje namerno odloženo** — ono je jedina
  stavka koja usporava razvoj, jer posle njega svaka izmena backenda traži
  push, pull i restart umesto da je `nodemon` sam pokupi. Rad na Flutter strani
  se ne usporava, ali koristi od prebacivanja nema dok aplikaciju koristi samo
  vlasnik kod kuće.
- **Prebacivanje na server** kad to bude gotovo — sve je spremno i provereno.
  Dve stvari idu zajedno: `systemctl enable --now chess-backend` i `backendUrl` u
  [constants.dart](../chess_app/lib/constants.dart) sa LAN adrese na
  `https://api.chesstrainers.app`. Jedno bez drugog razdvaja snimke časova.
  Kad dođe vreme, ne mora biti sve-ili-ništa: debug build sme da ostane na
  lokalnom backendu, a probni da se pravi sa
  `--dart-define=BACKEND_URL=https://api.chesstrainers.app`.
- ~~Zvonce kao vlasnik odgovora na zahtev~~ — urađeno 20.8.2026.
- ~~Prihvatanje se ne vidi kod pošiljaoca~~ — rešeno i **provereno uživo na dva
  uređaja 20.8.2026** (stavka 21 u [TODO-provera.md](TODO-provera.md)).
- Ostatak probe pristanka: ponovno slanje posle odbijanja, samo obaveštenje o
  odbijanju, i obaveštenja posle popravke — stavke 0 i 0a u
  [TODO-provera.md](TODO-provera.md). Proba pristanka je inače prošla uživo
  17.8.2026, i uzajaman par je raskinut.
- **Sajt** na korenu domena — sadržaja još nema, pa ni sertifikata za `@` i
  `www`. Vidi korak 3a u [TODO-objavljivanje.md](TODO-objavljivanje.md).
- ~~Faza 2 unifikacije — `MoveCursor`~~ — urađeno 20.8.2026, čeka proveru
  uživo (stavka 20 u [TODO-provera.md](TODO-provera.md)).
- **Prisilan redosled kao zastavica na zadatku**, ako se ikad pokaže potreba —
  vidi pitanje 1. Namerno nije napravljeno unapred.
- Provere uživo iz `TODO-provera.md`: izveštaj za roditelja, zadaci tipa
  lekcija, ponavljanje u razmacima, merenje troška (stavka 10 — endpoint sad
  radi, izveštaj nikad otvoren).
- **Skener pozicija iz knjiga** — odeljak iznad. Parser na Node-u radi i izmeren
  je (99,98% na prvoj knjizi). Mapa fonta za drugu knjigu je gotova 20.8.2026 —
  210 dijagrama, 0 nemogućih pozicija. Sledeće je ekran za potvrdu u aplikaciji;
  faza 2 (skenirane slike) čeka merenje tačnosti na pet strana pre nego što se u
  nju uloži.
- **Knjiga kao interaktivna lekcija** — procenjeno 20.8.2026, odeljak u skeneru.
  Izvodljivo, pola je već napravljeno, ali tek posle ekrana za potvrdu i
  objavljivanja. Prevod proze čeka pravnika, mapiranje slova figura ne čeka
  nikoga.
- Veći, netaknuti poduhvati iz procene: dnevna zagonetka i niz dana, grupe i
  prisustvo, chat i video, višejezičnost.

## Kako se proverava

```bash
cd chess_app && flutter analyze && flutter test
```

Trenutno: čisto, 162 testa prolaze.

```bash
cd chess_backend && npm test
```

Pokretanje (server pa aplikacija):

```bash
cd chess_backend; npm run dev
```

```bash
cd chess_app; flutter run -d windows 2>&1 | Tee-Object -FilePath run.log
```

## Zamke koje su nas već koštale vremena

- **PowerShell je 5.1**, ne 7. Nema `&&` kao separator, `Tee-Object` nema
  `-Encoding`.
- **`run.log` je UTF-16LE** (tako piše `Tee-Object`), pa ga `grep` ne vidi.
  Prvo: `iconv -f UTF-16LE -t UTF-8 run.log > /tmp/r.log`.
- **Tražiti *prvu* grešku u logu**, ne poslednju. Kod Flutter-a lavina
  `MouseTracker` poruka je posledica jednog ranijeg izuzetka iz layout-a.
- **Baza se čita ovako** (obavezno `ssl` iz `DB_SSL`, inače „no pg_hba.conf
  entry"):
  ```js
  new Pool({host:process.env.DB_HOST, port:process.env.DB_PORT,
    user:process.env.DB_USER, password:process.env.DB_PASSWORD,
    database:process.env.DB_DATABASE,
    ssl:String(process.env.DB_SSL)==='true'?{rejectUnauthorized:false}:false})
  ```
- **Lokalni snimci** su u SharedPreferences:
  `AppData/Roaming/rs.pejovic/chess_app/shared_preferences.json`, ključ
  `flutter.local_session_recordings_list`. Korisno za proveru da li je greška u
  podacima ili u prikazu — kod nas je dvaput bila u prikazu.
- **Ključevi klijent/server su se već tri puta razišli** (`account_type` vs
  `accountType`, `studentEmail`, status 200 vs 201). Pri svakoj novoj ruti
  uporediti `jsonEncode` na klijentu sa `req.body` destrukturiranjem na serveru.

## Način rada koji korisnik očekuje

- Odgovori na srpskom.
- Ne nagađati uzrok — doći do dokaza (log, baza, endpoint, test koji pada bez
  popravke). Ovaj ciklus je tri puta demantovao uverljivu hipotezu podacima.
- Uz popravku ide test koji pada bez nje; to je provereno `git stash`-om.
- Kad se nešto ne može proveriti uživo, upisati u `TODO-provera.md`, ne
  prećutati.

## Snimanje časa je uklonjeno — odluka od 26.8.2026

**Čas se više ne snima.** Zvuk se prima samo iz sobe u kojoj je **jedan jedini
učesnik — punoletan vlasnik sobe**, koji tako pravi sopstveni materijal, skida ga
i objavljuje gde hoće. Interakcija trenera i učenika nema zvučni zapis ni uz čiju
saglasnost.

### Zašto, kad je bilo napravljeno i provereno uživo

Pitanje je postavljeno kao „koliko bi se smanjio pravni posao bez snimanja", i
merenje je dalo suprotan odgovor od očekivanog:

- **vezano samo za snimanje:** `recordingConsent.js`, kolona
  `parent_allows_recording`, treće polje na roditeljskoj stranici, jedan test;
- **ostaje bez obzira na snimanje:** `parentConsentService`, `ageService`,
  `relationshipService`, `accountGuard`, `routes/consent.js`, `awaiting_parent`,
  `parent_consent_at/ip/version`, `AGE_OF_CONSENT` — 52 mesta u 10 fajlova.

Ta mašinerija ne postoji zbog snimanja nego zato što **dete ima nalog, a trener
vidi njegove podatke**. Papirologija se, dakle, jedva smanjuje.

Ono što se smanjuje je izloženost. `uploads/` je bio jedina kopija dečjih
glasova — jedini podatak ovde koji se ne može reprodukovati, anonimizovati ni
povući. Uz to nestaje „audio" iz Play prijave podataka i ceo odeljak koji bi
advokat morao da odobrava **po svakom tržištu posebno**, dok je advokat 25.8.2026.
pokrio samo Srbiju.

Oštriji deo, koji je i presudio: izbacivanje gađa deo koji je **već plaćen i
završen** (Srbija, uključujući snimanje), a deo koji se razlikuje od zemlje do
zemlje — uzrast za saglasnost, 13 do 16 — ostaje i posle njega. Jedino što bi
zaista srušilo pravni posao je da deca nemaju naloge, a to je proizvod.

### Šta je dobijeno, a ne samo uklonjeno

Trener sam u sobi pravi video lekcije i objavljuje ih. To je funkcija sa uzlaznom
stranom — kanal kojim ljudi dolaze do aplikacije — dok snimanje časa sa detetom
nema nijedna šahovska aplikacija, i verovatno ne slučajno.

### Kako je izvedeno

Pravilo je zamenjeno **unutar `mayRecordRoom`**, a mehanika oko njega je ostala:
sva četiri pozivna mesta, zaustavljanje snimanja, spisak učesnika i drugi katanac
pri upisu rade kao pre, samo odgovaraju na drugo pitanje.

Tri odluke u tom pravilu, svaka je mesto gde bi tiho prestalo da znači nešto:

- **Gost obara snimanje.** Nema nalog, pa nema ni godine ni vezu — pod starim
  pravilom bio je nevidljiv. Pod ovim mu nalog ne treba: on je neko drugi u sobi,
  a to je celo pitanje. Zato spisak učesnika sada čuva i njegov socket id.
- **Nepoznata godina je odbijanje, ne prolaz.** Svuda drugde u ovoj bazi
  neizjašnjen uzrast je namerno propušten; ovde je obrnuto, jer je reč o dozvoli
  da nastane jedini artefakt koji se ne može povući.
- **Osamnaest, ne `AGE_OF_CONSENT`.** Taj prag je 13–18 po zemlji i odgovara na
  drugo pitanje. Ovo je objavljivanje sopstvenog glasa, dakle punoletstvo.

**Odbija se zvuk, a ne čas.** Ranije je upis vraćao 403 i bacao ceo snimak, čime
se zbog pravila o zvuku gubio i tok table stvarnog časa. Sada se čas uvek čuva i
pregleda nemo, a izostane samo zvuk — ista pouka kao ranija odluka da se detetu
ne oduzima čas nego snimanje.

### Usput nađeno i popravljeno

Spisak učesnika je prešao na niske da bi primio goste, a `stopRecordingForConsent`
je i dalje brisao **brojeve** iz skupa niski — dakle ništa, i ćutke. Uhvatio ga je
postojeći test. Isti oblik greške koji ovaj dokument nabraja od početka.

### Stanje

`npm test` 517 prolazi, `flutter test` 653 prolaze, `flutter analyze` bez ijedne
primedbe u dirnutim fajlovima. Čuvar upisa je dokazan mutacijom: bez brisanja
odbijenog fajla test pada.

`PARENT_CONSENT_VERSION` je podignut na `rs-2026-08-26`, jer se tekst promenio —
bez toga bi već date saglasnosti pokazivale na formulaciju koja više ne postoji.
**Mora se podići i u `.env` na dropletu.**

### Otvoreno

- `docs/politika-privatnosti.md` i `docs/saglasnost-roditelja.md` su druga kopija
  pravnog teksta koji stvarno izlazi iz `site/` i `routes/consent.js`. Usklađeni
  su sa ovom izmenom, ali dve kopije istog pravnog teksta se pre ili kasnije
  raziđu. Odlučiti da li se brišu ili ostaju samo kao obrazloženje.
- Isti fajlovi još nose ime „Chess Master" u naslovu, koje je odbačeno.
- Kolona `parent_allows_recording` je ostavljena u bazi i više se ne piše ni ne
  čita. Nije obrisana namerno — rušenje kolone je nepovratno, a šteta od nje je
  nula.

## Panel trenera — kanvas sa tri varijante, 26.8.2026

Stavka „kanvas sa predlozima za panel trenera, koji čeka izbor varijante" stajala
je otvorena od 24.8.2026, ali **varijante nigde nisu bile zapisane** — čekao se
izbor između predloga koji ne postoje. Sada postoje.

Radni fajlovi: `design/panel-trenera/`. Objavljeni kanvas:
https://claude.ai/code/artifact/dca9d784-3e96-4c50-84ed-9b69e117a07c

Tri varijante se ne razlikuju po izgledu nego po **pitanju na koje odgovaraju**,
jer to odlučuje šta stoji na vrhu ekrana:

| | Pitanje | Jaka strana | Cena |
|---|---|---|---|
| **A — Danas** | šta mi je sad posao | otvoriš i znaš šta radiš | učenik koji tone mesecima, a nema ništa danas, nigde se ne pojavi |
| **B — Po učeniku** | kako stoji svako | jedina pokazuje trend | ne kaže šta da uradiš; sa dvadeset učenika je zid brojeva |
| **C — Čeka tebe** | gde sam ja usko grlo | broj na tabu je iskren i prazni se do nule | vidi samo ono što je neko drugi pokrenuo; ćutljiv učenik ne stvara stavku |

**Predlog: A kao ekran, C kao broj.** Trener otvara aplikaciju pred čas, ne radi
pregleda. Ono što iz C-a stvarno vredi je značka sa brojem na tabu Ljudi; red
posla može da bude odeljak unutar A umesto zasebnog ekrana. B ne bi bio panel
nego postojeći ekran napretka, do kog se stiže klikom na učenika — trend je
važan jednom mesečno, ne svakog dana.

Makete su statične i u tamnoj temi aplikacije; boje i razmaci su preuzeti iz
`chess_app/lib/theme/app_colors.dart`, a polja su stvarna (Rejting, Tačnost,
Rešeno, Aktivnih dana, period 7/30/90). Imena i brojevi su izmišljeni, jer je
repozitorijum javan.

Ono što maketa **ne** rešava: prelivanje na uskom telefonu. To i dalje traži
proveru na uređaju, iz razloga opisanog u `CLAUDE.md` — u release build-u nema
žuto-crnih traka.

## Panel trenera — izabrano i napisano, 27.8.2026

Korisnik je izabrao **A kao ekran, C kao broj**, kako je i predloženo. Napisano
istog dana; **nije viđeno uživo** — stavka 39 u
[TODO-provera.md](TODO-provera.md).

**Nije nov tab, nego odeljak na vrhu taba „Ljudi".** Razlog je isti onaj koji
drži i ostatak ovog dokumenta: trener je *položaj u vezi*, ne osobina naloga, pa
bi peto odredište u traci stajalo prazno svakome ko nikoga ne uči — a to je
većina korisnika i gotovo sva deca. „Ljudi" je jedini tab koji ionako postoji
zbog veze. Uz to, peto odredište bi se pisalo na dva mesta (`NavigationBar` i
`NavigationRail`) plus prečice i istorija tabova, a pet natpisa na telefonu od
360 dp je tačno onaj red koji release build ćutke odseca.

Šta je napisano:

| | |
|---|---|
| `GET /trainer/panel` | jedan poziv, četiri odeljka: današnji časovi, domaći kojima ističe rok, predato a nepregledano, i učenici koji ćute duže od 7 dana |
| `POST /assignments/:id/reviewed` | jedini događaj koji prazni značku |
| `assignments.reviewed_at` | nova kolona; bez nje značka može samo da raste |
| `acceptedStudentsOf` | isti fragment kao `acceptedTrainersOf`, samo iz drugog smera — spisak „moji učenici" ide kroz njega, ne kroz ručno prepisan uslov |

**Značka broji samo ono što trener može da isprazni** — predato a nepregledano,
plus zahtevi na koje nije odgovorio. Rokovi i učenici koji ćute jesu na ekranu i
**nisu** u broju: njih ne zatvara nijedan potez trenera, a značka koja ne može
da padne na nulu prestaje da se čita. To je i cela poenta varijante C.

`POST .../reviewed` je zasebna ruta, a ne propratni efekat čitanja pregleda,
jer isti pregled čita i učenik: da GET piše, dete bi gledanjem svoje povratne
informacije brisalo stavku sa trenerovog spiska. Poziv ide **pre** otvaranja
ekrana i ne može da ga obori — isto pravilo kao „uradi pa javi" iz `CLAUDE.md`.

Usput popravljeno: prvi tab se u traci zvao **„Trening"**, a u bočnom rail-u
**„Početna"** — jedan te isti `TrainingHubScreen`. Sada oba kažu „Trening", i
`test/home_tabs_test.dart` pada ako se raziđu.

Ostalo namerno nenapisano: „Podseti" iz makete (traži poruku učeniku, a ta ruta
ne postoji — dugme vodi u zadatak), i sekcija „Izveštaji roditeljima" iz C
(`student_reports` nema stanje „sastavljen, nije poslat", pa bi broj bio
izmišljen).

## Bagovi 1 i 7 sa prolaska kroz aplikaciju — 27.8.2026

**Bag 1: engine se „zamrzne" ako se odigra potez dok razmišlja.** Nije Stockfish
nego jedna sekunda. Kad engine odabere potez, `_isOpponentTurn` se gasio
**odmah**, a potez se igrao tek posle pauze od 1000 ms — a tabla je nema samo
dok je ta zastavica podignuta. U toj sekundi korisnik odigra potez figurom
strane koja je na potezu (engine-ove!), pa zakazani potez padne na poziciju
kojoj više ne pripada. Odatle nadalje pozicija u `_puzzleGame` i pozicija na
tabli nisu ista stvar, i drill prestane da odgovara.

Zastavica se sada gasi tek kad je potez **na tabli** (`resetBoardState` to
ionako radi), potez se pred igranje **proverava ponovo** — protiv table na koju
sleće, a ne one za koju je izabran — i ako više nije legalan, traži se nov
odgovor umesto da se odigra nasilu.

Uz to, dve stvari koje su rupu skrivale:

- Kad engine nema šta da odigra (sve evaluacije stigle za staru poziciju, pa su
  odbačene kao zastarele), ranije se tiho izlazilo iz funkcije. Sad ide **jedan**
  ponovni upit za poziciju koja je stvarno na tabli, pa tek onda odustajanje sa
  porukom — i tabla se vraća korisniku, jer zaključana tabla i tabla koja ne
  odgovara izgledaju isto spolja.
- `stopAnalysis()` briše `_currentFen`, ali engine posle „stop" šalje još
  nekoliko redova i `bestmove`. Ti redovi su se prosleđivali sa **praznim**
  FEN-om: svaki slušalac ih odbaci kao zastarele, ali tek pošto
  `AnalysisLine.fromPv` pokuša da napravi tablu od `''` i baci *„FEN string must
  contain six space-delimited fields"* u log, po redu. To je bio šum u kom se
  pravo zamrzavanje izgubilo. Sada se izlaz zaustavljene pretrage ne prosleđuje.

**Bag 7: posle pogrešnog poteza tabla je primala poteze koje niko nije čuvao.**
Pogrešan potez postavlja status `failed`, a `failed` znači „gotovo", pa je
sledeći `_onMove` izlazio **bez vraćanja table** — dok je widget figuru već
pomerio. Nekoliko povlačenja kasnije, tabla na ekranu i pozicija koja se rešava
bile su dve različite stvari, za obe boje.

Dva pravila, oba tražena:

1. **Svako odbijanje poteza vraća tablu.** Bez izuzetka i bez obzira na razlog.
2. **Nema više dugmeta „Pokušaj ponovo".** Pogrešan potez u vežbi sam vraća
   poziciju i odmah dozvoljava nov pokušaj — to je jedino zbog čega je iko to
   dugme i pritiskao. Greška ostaje zabeležena, pa rešenje posle greške i dalje
   ne važi kao čisto.
3. **Domaći je izuzetak.** Tamo je prvi potez odgovor i već je zabeležen, pa
   drugi pokušaj ne bi menjao ništa osim utiska. Umesto toga piše da je zadatak
   sa jednim pokušajem i da je potez zabeležen, tabla se zaključava, a „Prikaži
   rešenje" ostaje dostupno — tu i vredi najviše.

Isto je primenjeno na trener završnica, gde je korisnik video isto ponašanje.
`test/wrong_move_board_test.dart` drži pravilo (dokazano mutacijom); taktika
nema ubrizgan API pa se ne može testirati bez mreže — ostaje provera uživo.

## Rupa u prijavi, nađena usput 27.8.2026

**`POST /verify-email` je izdavao token bez ijedne provere.** Ruta je nalazila
nalog po adresi i, ako je već verifikovan, **potpisivala JWT i vraćala ga** —
bez poređenja kôda, bez lozinke. Ko zna bilo koju registrovanu adresu, pošalje
je sa šest proizvoljnih znakova i dobije sedmodnevnu sesiju za taj nalog. Za
svaki nalog na serveru, uključujući dečje.

Nije izgledalo kao rupa nego kao ljubaznost: „ako je korisnik već verifikovan,
nemoj da mu javljaš da je kôd pogrešan". I stajalo je tačno iznad poređenja koje
je preskakalo. Nađeno čitanjem rute zbog sasvim drugog pitanja.

Pravilo je sada u `services/emailVerification.js`, kao jedna čista funkcija sa
tri ishoda, i **verifikovan nalog ne dobija sesiju nikada** — dobija poruku da
se prijavi lozinkom ili preko Google-a. Verifikacija dokazuje da je adresa
jednom bila dostupna; to nije dokaz o *sada*, a ova ruta drugog dokaza nema.
Aplikacija na `alreadyVerified` vraća korisnika na formu za prijavu, umesto da
ga ostavi pred poljem za kôd koje više ne može da radi.

**Uz to, druga polovina istog pitanja: Google prijava i postojeći nalog.**
Prijava preko Google-a preuzima nalog koji već drži tu adresu — i to treba tako
da ostane. Adresu je potvrdio Google (`email_verified` se proverava), isti dokaz
koji daje i naš kôd; odbijanje bi ostavilo čoveka bez ulaza, a drugi nalog bi
tiho razdvojio trenera od učenika, jer veza visi o `users.id`.

Jedan izuzetak je dodat. Ako zatečeni nalog **nije verifikovan**, niko nikad
nije dokazao da je adresa njegova — bilo ko može da registruje bilo čiju adresu,
a kôd koji bi to dokazao nije unet. Preuzimanje takvog naloga sa zatečenom
lozinkom ostavilo bi onome ko ga je napravio radnu lozinku za nalog čoveka koji
adresu stvarno poseduje. Zato lozinka u tom slučaju pada na
`GOOGLE_PLACEHOLDER_HASH` i nalog postaje Google nalog.

Oba pravila drži `test/email_verification.test.js`, a čitač izvora u njemu je
dokazan mutacijom — vraćanjem stare grane, koja test obara.

## Ekran za prijavu — pet nalaza sa prve prolaznosti, 27.8.2026

Korisnik prolazi kroz aplikaciju ekran po ekran. Prvi je ekran za prijavu; pet
stvari, sve stvarne.

**Dva puta unutra, sada razdvojena.** Ranije su tri dugmeta stajala jedno ispod
drugog i jedno od njih je radilo nešto drugo. Sada je prvo Google blok, pa linija
„ili", pa email forma. Google dugme je izgubilo ivicu u primarnoj boji — ta ivica
je i bila razlog što je izgledalo kao označen izbor dok korisnik kuca adresu — i
piše **„Prijava / Registracija preko Google-a"**, jer to dugme i registruje.
Prikazuje se i u režimu registracije, gde ga uopšte nije bilo: to je jedini ekran
na kom neko sigurno traži način da napravi nalog.

**„Zapamti me" je radilo, ali ne ono što je pisalo.** Kutijica čuva token i
`SessionService.init()` ga vraća pri pokretanju. Sesiju prekidaju tri stvari, sve
tri ispravne: token traje **7 dana**, odjava, i nestao nalog (baza je pražnjena
25.8.2026, pa je stari token pokazivao na nalog koga više nema). Sada:

- adresa iz poslednje prijave se pamti i upisuje sama (preživljava odjavu, token
  ne),
- polja su u `AutofillGroup` sa `autofillHints`, a uspešna prijava zove
  `finishAutofillContext()` — **to** je ono što natera Android i Windows da
  ponude čuvanje i kasnije popunjavanje lozinke,
- kursor počinje u lozinki kad je adresa već poznata, inače u adresi,
- ispod kutijice piše šta ona radi: „Ostajete prijavljeni na ovom uređaju."

**Lozinka se namerno ne čuva u aplikaciji.** Predlog je bio da se pamti i
prikaže pod zvezdicama. `SharedPreferences` je na Windows-u običan XML fajl u
profilu korisnika — čita ga svaki program koji radi kao taj korisnik — a većina
ovih naloga pripada deci. Isti efekat daje menadžer lozinki operativnog sistema,
kome se pristupa preko `autofillHints`, i tada je aplikacija nikad ne vidi.

**Google prijava na Windows-u — napisana, nije isprobana.** `google_sign_in` ne
podržava Windows (ni Linux): `supportsAuthenticate()` vraća false i dugme je bilo
slepa ulica. Umesto njega ide tok za instalirane aplikacije (RFC 8252):
sistemski pretraživač, `redirect_uri` na `http://localhost:<slobodan port>`, PKCE
(S256), pa razmena kôda za `id_token`, koji ide na postojeću rutu `/auth/google`.

Backend se **ne dira** — `GOOGLE_CLIENT_IDS` je oduvek lista, baš zato što svaka
platforma ima svoj klijent.

| | |
|---|---|
| `services/oauth_pkce.dart` | čist deo: PKCE, sastavljanje URL-a, čitanje odgovora — jedino što se može testirati, i jedino što tiho pukne |
| `services/desktop_google_sign_in_io.dart` | soket, pretraživač, razmena kôda |
| `services/desktop_google_sign_in.dart` | uslovni izvoz, da web build ne vidi `dart:io` (isti oblik kao `stockfish_service.dart`) |

Provera `state` nije ukras: bez nje bilo koja stranica u bilo kom pretraživaču
na toj mašini može da pogodi loopback port svojim kôdom i natera aplikaciju da
ga iskoristi — prijava na tuđi nalog. Test to drži.

**Šta preostaje tebi**, jer bez toga ovo ne može da se isproba (koraci su u
stavci 40 u [TODO-provera.md](TODO-provera.md)): napraviti OAuth klijent tipa
„Desktop app" u Google Cloud konzoli, dodati njegov ID u `GOOGLE_CLIENT_IDS` na
serveru, i graditi Windows sa `--dart-define`. Dok toga nema, dugme se na
Windows-u **ne prikazuje** — bolje nego dugme koje javi grešku posle klika.

## Šta je prva proba panela pokazala — 27.8.2026

Korisnik je panel video na Windows-u i na Androidu; prikazuje se samo onome ko
ima učenike, i „Otvori" radi. Iz same probe su ispala **tri** nalaza, i sva tri
su bila stvarna rupa, ne greška u prikazu.

**1. Domaći bez roka nije se video nigde.** Prva verzija je gledala samo rok, a
zadatak bez roka nema šta da istekne. Isto tako, zadatak koji je stao na pola
nestajao je iz „Nije vežbao" čim učenik reši prvu zagonetku — nije više ćutao,
a nije ni završio.

Dodat je odeljak **„Domaći stoji"**: nezavršen zadatak bez pomaka 3+ dana, sa
rokom koji je još daleko ili bez roka. Poslednji pomak je
`GREATEST(created_at, MAX(attempted_at))`, pa zadatak koji niko nije ni otvorio
računa od dana kad je zadat. Dva prozora su komplementarna — šta je u naredna
48 sata ide u „Domaći ističe", sve ostalo sme u „Domaći stoji" — tako da isti
zadatak ne može da bude u oba.

**2. „Nije vežbao" je prijavljivalo učenika kome ništa nije ni zadato.** Odeljak
sada izostavlja svakog ko ima otvoren zadatak: o njemu govori red o domaćem, a
ne rečenica da ćuti. Jedan čovek, jedan red, jedna stvar koja se s njim radi.
Odeljak **nije** vezan za domaći, jer bi se time izgubio slučaj zbog kog i
postoji — dete koje tone mesecima a niko mu ništa nije zadao. Zato red sada i
piše „nema zadatog domaćeg".

**3. Obaveštenje treneru radi, ali učenik nije znao da nije predao.** Korisnik
je preskočio dve zagonetke i mislio da je predao domaći. `assignment_done`
obaveštenje **postoji odranije** i stiglo je čim je kasnije uradio i te dve —
provereno u bazi. Problem je bio na učenikovoj strani: na kraju prolaza je
pisalo **„Zadatak je završen. Vaš trener vidi rezultat."** bez obzira na to
koliko je preskočeno.

Sada, kad je nešto preskočeno, piše **„Domaći još nije predat"**, koliko je
preskočeno, i da trener ne dobija obaveštenje dok se i te zagonetke ne pokušaju
— uz dugme „Uradi preskočene", koje vraća **samo** njih, ne ceo zadatak.

Sitnica koja se lako previdi: broj u toj rečenici ide kroz `puzzleCountLabel`,
jer srpski ima tri oblika (1 zagonetku / 2 zagonetke / 5 zagonetaka), a 11–14
idu uz peti oblik. Tekst čitaju deca.

Usput: panel i značka se sada osvežavaju i preko soketa
(`notifications_changed`), pa predat domaći stiže na ekran bez izlaska iz taba.
Promena prisutnosti više ne pokreće upite panela — to je najbučniji događaj koji
panel ne prikazuje.

## Šahovski studio nije mogao da se otvori — 27.8.2026

Iz korisnikovog loga:

```
[SOBA]  Odbijen ulazak u STUDIO: no-room (korisnik 1)
[AGORA] Odbijen token za kanal STUDIO: no-room (korisnik 1)
```

Studio je **lokalna tabla, a ne soba**: reda `rooms.room_code = 'STUDIO'` nema
i ne treba da ga bude — `canMoveInRoom` u `server.js` to i kaže naglas. Ali
`chess_game_screen` je isti ekran za oba slučaja, pa je iz `initState` slao
`joinGame` sa `roomId: 'STUDIO'`. Otkad postoji spisak zvanica (`roomAccess.js`),
na to pitanje postoji samo jedan odgovor — `no-room` — a ekran radi ono što
odbijanje nalaže: poruka „Ne postoji soba sa tim kodom" i izlazak nazad. Studio
se time zatvorio sam.

Nije regresija u `roomAccess.js` nego rupa koju je on otkrio: dok je `joinGame`
puštao svakoga, **svi studiji na svetu su bili jedna soba po imenu STUDIO**, pa
su se potezi jednog čoveka emitovali u tuđu analizu.

Popravka je na klijentu, jer je odluka klijentova: kad je `roomCode == 'STUDIO'`,
ne šalje se `joinGame`, a glas se ne dira uopšte — `_joinVoice()` ga odbija
za studio, i sam panel „Audio Učionica" stoji pod `if (!isStudio)`. Soket
ostaje otvoren (ekran ga koristi na 34 mesta i emitovanja padaju u praznu
sobu), a naslov u `AppBar`-u je sada „Šahovski studio" umesto „Soba: STUDIO".

Ostaje sitnica, namerno neurađena: studio i dalje emituje `move` i `pgn_loaded`,
pa server po potezu radi `UPDATE rooms ... WHERE room_code = 'STUDIO'` koji ne
pogađa nijedan red. Bezopasno, ali je jedan upit u bazu po potezu za tablu koja
je sama svoja.

Provera uživo: ući u Šahovski studio i videti da se otvara, da u logu nema
`[SOBA]`/`[AGORA]` odbijanja i da tabla radi bez servera.

## Pešak nije mogao da postane figura — 27.8.2026

Prijavljeno uživo iz „Pronađite dobitni put", sa logom koji je odmah pokazao
gde da se gleda:

```
[MOVE_MADE_DEBUG] Could not match move in chess.js legal moves!
```

Uzrok je jedan nedostajući ključ u paketu. `chess.dart` u `make_pretty` pravi
mapu poteza od `san`, `to`, `from`, `captured` i `flags` — **i ničeg više** — a
dokumentacija dva reda iznad te funkcije kaže da u mapi stoje i `piece` i
`promotion`. Ceo ovaj kod je verovao dokumentaciji. Znači: `m['promotion']` je
**uvek `null`**, za svaki potez, u svakoj poziciji.

Dva različita kvara iz istog uzroka:

- mapa vraćena u `game.move(m)` **biva odbijena** kad je potez promocija, jer
  `move()` poredi `move['promotion'] == moves[i].promotion!.name`, a ključa
  nema. Potez se ne odigra, `move()` to i kaže — i svaki pozivalac je nastavio
  kao da jeste;
- `where((m) => m['promotion'] != null)` ne izabere ništa, pa kod koji traži
  promociju među legalnim potezima zaključi da je nema.

**Popravka je na jednom mestu**: `core/services/legal_moves.dart` čita figuru iz
SAN-a (`d8=Q+`) i vraća iste mape sa popunjenim `promotion` (`''` kad nije
promocija), plus `playMove` koji potez odigra sa imenom figure i `isPromotionMove`
koji pita **poziciju**, a ne odredišno polje — pešak koji uzima na osmom redu
jeste promocija, a top koji dođe na osmi red nije. Namerno se ne generiše lista
poteza drugi put „kao objekti" pa uparuje po indeksu: to bi bile dve liste za
koje se veruje da su istog redosleda, a takve tihe pretpostavke su ono što ovaj
projekat stalno plaća.

Zamenjeno je svih 14 mesta koja su zvala `moves({'verbose': true})`. Šta je sve
usput bilo pokvareno, a niko nije znao:

- **AI studio** (prijavljeni slučaj) — potez se nije odigrao ni preko tapa ni
  prevlačenjem;
- **`game_analysis_walker_service`** — šetnja kroz partiju **prekidala se na
  prvoj promociji**, tiho, na sredini tuđe analize;
- **`tactical_motif_detector`** — mat u jedan **promocijom** (najčešći od svih:
  `d8=Q#`) nikad nije bio pronađen;
- **`auto_tree_generator_service`** — rezervno uparivanje poteza padalo je baš
  na linijama u kojima pešak prolazi;
- **analiza, otvaranja, stablo rešenja, graf rešenja** — SAN promocije ispisivan
  kao `d7d8` umesto `d8=Q`.

**Drugi deo: izabrana figura mora da putuje sa potezom.** `ChessBoardWithOverlay.onMove`
sada nosi i `promotion`, a deset ekrana koji ga koriste igraju tu figuru umesto
svog `'promotion': 'q'`. Ranije je prevlačenje otvaralo dijalog paketa, čovek bi
izabrao skakača — a ekran bi u svoju poziciju upisao damu i tablu prepisao
preko izbora.

**Treći deo: pita se.** Tap-potez je ćutke pravio damu, pa se vežba čije je
rešenje skakač nije mogla ni odigrati tapkanjem. Sada postoji jedan dijalog za
sve table (`widgets/promotion_picker.dart`), na srpskom, u boji strane koja
igra, sa imenima figura ispod slika — „lovac" i „top" su tačno one dve koje deca
mešaju. Odustajanje znači da se potez **ne igra**, umesto da se odigra ono što
niko nije izabrao. Taktika je imala svoj dijalog i sada koristi ovaj; AI studio
je imao gore od toga — čitao je stablo rešenja i tiho promovisao u figuru koju
rešenje traži, pa je zadatak koji uči da samo skakač radi bio „rešen" damom.

`test/legal_moves_test.dart` (9 provera, uključujući onu koja reprodukuje sam
bag) i tri nove u `test/tap_to_move_test.dart`. Dokazano mutacijom: kad
`promotionOf` uvek vrati prazno, pada sedam testova; kad se ukloni pitanje u
tabli, pada test koji traži dijalog.

Ostaje, sitno i zapisano: **prevlačenje i dalje otvara dijalog paketa** („Choose
promotion", uvek bele figure). Radi ispravno i izbor sada stiže do ekrana, ali
je na engleskom u aplikaciji za srpsku decu. Zameniti se može samo ako se widget
table preuzme u repo — nije vredno danas.

Provera uživo: u „Pronađite dobitni put" dovesti pešaka do poslednjeg reda i
tapnuti — mora da pita, i izabrana figura mora da se pojavi na tabli; isto
prevlačenjem; pa isto u završnicama, taktici i repertoaru.

## Koordinate na tabli, i jedno dugme koje je smetalo — 27.8.2026

Tri stvari, sve prijavljene sa slika ekrana.

**Dugme za okretanje table izbačeno iz vežbi.** U „Mat u 1, 2 ili 3 poteza",
„Vežbanje osnovnog matiranja" i „Pronađite dobitni put" — to je jedan te isti
ekran (`_buildActiveBoardScreen` u `ai_studio_screen.dart`), pa je izmena na
jednom mestu pokrila sva tri — tabla se okreće prema onome ko rešava, a iznad
nje piše „Crni na potezu". Ko je okrene, gleda tablu koja protivreči rečenici sa
njegovom bojom. `_toggleOrientation` je obrisan jer više nema ko da ga zove.

**Prekidač za koordinate, na svakom ekranu sa tablom.** `BoardWithCoordinates`
je postojao od ranije, ali samo na pet ekrana i bez načina da se ugasi. Sada:

- `AppSettingsService.showBoardCoordinates` (podrazumevano **uključeno**, jer
  deca uče da čitaju tablu), zapamćeno na uređaju;
- `BoardWithCoordinates` sluša podešavanje i, kad je isključeno, **vraća tabli
  ceo prostor** — zato prekidač stoji u njemu, a ne u pozivaocima: ekran koji je
  sam oduzeo pojas ostavio bi prazan okvir;
- `BoardCoordinatesButton` — jedno dugme (`grid_on`/`grid_off`), koje samo crta
  svoje stanje, na: vežbama iz AI studija, Tabli za analizu, sobi za čas (u
  traci ispod table, pored dugmeta za okretanje — u gornjoj traci već stoji pet
  radnji i šesta bi na telefonu od 360 dp izašla van ekrana bez ijednog
  upozorenja u release buildu), taktici, završnicama, greškama iz partija, sva
  tri repertoara, rešavaču zadataka, pregledu lekcije, ponavljanju i plejeru
  snimaka;
- isti prekidač i u Podešavanjima, jer podešavanje treba da postoji i tamo gde
  se traži kad se ne zna gde je dugme.

Tablama koje ranije nisu imale koordinate sada su dodate: AI studio, Tabla za
analizu, soba za čas, taktika, rešavač zadataka, pregled lekcije, ponavljanje,
plejer snimaka.

**Preklapanje ispod table u Tabli za analizu** („BOTTOM OVERFLOWED BY 12
PIXELS"). Leva kolona u pejzažnom rasporedu drži tablu, evaluacionu traku,
navigaciju i panel komentara, a u računicu visine table ulazi samo prvo od toga.
Kolona sada **skroluje**, kao i panel desno od nje. Prevlačenje figure i dalje
pobeđuje skrol: `Draggable` uzima gest odmah, a skrol mora prvo da pređe prag —
soba za čas ima tablu u skrolu oduvek, i za to postoji test.

Provera uživo: ugasiti i upaliti koordinate na jednom ekranu i videti da su
promenjene i na ostalima; suziti prozor Table za analizu dok se ne pojavi
preklapanje (ne sme).

## Motor: jačina protivnika i dubina analize razdvojeni — 27.8.2026

Do sada je u Podešavanjima stajao **jedan broj** („dubina analize"), koji je bio
i to koliko duboko motor misli kad **igra protiv vas**, i to koliko duboko svaka
tabla u aplikaciji računa evaluaciju. Spustiti protivnika da bi detetu bilo
lakše značilo je i plići prikaz u celoj aplikaciji; tražiti pet linija na jednoj
poziciji značilo je promeniti kako motor igra svuda. Dva pitanja, jedan broj.

**Podešavanja sada drže samo protivnika:**

- **Jačina motora kada igra protiv vas** — Lako / Srednje / Teško, što je
  redom 18 / 24 / 30 poteza unapred (`AppSettingsService.kEnginePlayDepths`,
  pa se sva tri mogu naštelovati na jednom mestu). Stara ručno podešena dubina
  se **jednom** preslikava na najbliži nivo, a sam broj ostaje kao početna
  dubina analize — ko je izabrao 29 nije hteo da bude vraćen na podrazumevano.
- **Maksimalno vreme razmišljanja** ostaje kakvo je bilo: motor igra čim
  dostigne dubinu svog nivoa ili čim istekne vreme, šta pre.

**Dubina i broj linija su sada na samoj tabli** (`widgets/engine_analysis_dials.dart`),
ispod prekidača „Prikaži evaluaciju", na svakom ekranu gde se evaluacija
prikazuje: vežbe u AI studiju, Tabla za analizu, soba za čas i građenje
repertoara. Dubina ide **do 50** (bilo je 28 — ostatak iz vremena kad je taj
broj određivao i koliko protivnik razmišlja pre poteza). Poslednje izabrano se
pamti, pa sledeća tabla počinje tamo gde je prethodna stala.

Usput, u istom panelu: **„Prikaži evaluaciju" i „Prikaži evaluacionu liniju"
stoje jedno pored drugog**, u `Wrap`-u — na telefonu se prelamaju u dva reda
umesto da budu isečeni bez upozorenja u release buildu.

**Evaluacija se sada vidi sve vreme.** Ekran za građenje repertoara je čekao da
pretraga stigne do zadate dubine pa tek onda išta prikazivao: na dubini 40 to je
prazan panel po pola minuta, što spolja izgleda isto kao motor koji se ne javlja.
`analyzePositionSync` dobija `onProgress`, pa linije stižu od prve dubine i samo
postaju bolje — a dubina pored svake kaže koliko joj se veruje.

**Strelice sa evaluacijom.** Prvi potez svake linije se crta na tabli, sa
ocenom pored strelice (`EngineArrow`, isto što drugi ekrani već koriste).
Uz to je u AI studiju uklonjeno ograničenje od tri strelice — ko traži pet
linija dobijao je četiri strelice i petu liniju samo u spisku ispod.

**I bag koji je sve to otkrilo:** kad pretraga dostigne zadatu dubinu, poslednje
što motor pošalje je `bestmove`, koji **nema ocenu u sebi**. Servis je taj
događaj prosleđivao kao praznu evaluaciju na dubini 0, a svaki ekran ju je
upisivao u traku — pa je grafička evaluaciona linija u trenutku kad odgovor
postane konačan skakala na 0.00 i crtala dobijenu poziciju kao **egal**. Servis
sada ponavlja poslednju stvarnu ocenu, a ekrani ignorišu praznu evaluaciju:
„nemam šta da kažem" nije „nula".

Provera uživo: promeniti dubinu na tabli i videti da se linije odmah traže
ponovo; pustiti da pretraga stigne do kraja i videti da traka ostaje na pravoj
oceni; u repertoaru gledati kako linije pristižu tokom računanja i kako strelice
sa ocenama stoje na tabli; u Podešavanjima prebaciti nivo i videti da se menja
samo protivnik, a ne i dubina prikaza.

## Snimak table sa glasom u studiju — odbijeno 27.8.2026

**Predlog:** trener u Šahovskom studiju priča dok izvodi poteze, iz toga nastaje
snimak (tabla se pomera uz glas, plejer a ne renderovan video), i taj snimak se
ubaci u lekciju da ga učenici odslušaju.

**Odluka: ne gradi se.** Ni sada, ni u ovom obliku. Razlozi, po težini.

**Plejer je danas lošiji od videa, ne bolji.** Ceo argument za „plejer umesto
videa" je da format ume nešto što video ne ume. `replay_player_screen.dart` drži
`enableUserMoves: false` — učenik gleda. Ostaje slajder i izbor brzine, dakle
video plejer sa manje funkcija nego YouTube: bez CDN-a, bez titlova, bez
puštanja u pozadini na telefonu, i bez weba, jer Agora tamo nema snimanje. Ono
što bi format opravdalo — da učenik zaustavi, odigra potez sam, pita motor,
skrene u varijantu — ne postoji. Dok toga nema, premisa predloga ne stoji.

**Ono što je opisano već postoji i već je provereno uživo.** Trener sam u sobi →
snimi → izvezi MP4 → objavi gde hoće; tako i piše u odeljku „Snimanje časa je
uklonjeno". Razlika je samo u tome što bi snimak stajao *unutar* aplikacije i
bio zakačen za lekciju. To je udobnost, a ne nova mogućnost. I gore: dobitak od
snimljenog materijala je u tom odeljku opisan kao **kanal kojim ljudi dolaze do
aplikacije**, što važi za javni materijal. Materijal zaključan iza naloga tu
stranu nema uopšte — predlog uzima jedinu jasnu korist od snimanja i sklanja je.

**`uploads/` nije tog oblika.** `retentionService.js` izričito ostavlja taj
direktorijum na miru: jedina kopija, nikad se ne briše. Pravilo je pisano za
šačicu nezamenljivih snimaka časa. Materijal za učenje je proizvodna traka —
trener koji pravi kurs napravi desetine fajlova, namerno i zauvek, na jednom
dropletu koji drži i API. Vidi „Ako droplet postane tesan, kojim redom"; ovo je
najbrži put dotle. Apsurd je što je to materijal koji trener *hoće* da objavi,
pa baš on ne mora da bude nešto čemu je ova aplikacija jedina kopija.

**Studio deo ima nedokazanu tehničku premisu.** Zvuk ide kroz
`agora_rtc_engine.startAudioRecording`, motor napravljen za kanal, a u studiju
nema ni sobe ni kanala ni tokena. Možda radi bez `joinChannel`, možda traži drugi
audio put — ne zna se dok se ne proba. A vrednost studija (stablo varijanti,
evaluacija, eksplorer) je tačno ono što `TimelineEvent` ne beleži, pa bi format
morao da se proširi na kretanje kroz stablo. To je skupi deo funkcije čiji jeftini
delovi već premašuju dobitak.

**I peti razlog, koji je presudio.** 280 neoznačenih provera u 44 stavke,
53 koraka do objave, a poslednja nedelja su ispravke iz prvog prolaska kroz
aplikaciju: studio nije mogao da se otvori, pešak nije mogao da promoviše, pet
nalaza na ekranu za prijavu. Aplikaciju još nije koristio niko osim vlasnika.
Funkcija za deljenje materijala učenicima pretpostavlja učenike, a trenera koji
je ovo tražio još nema.

### Šta mora da putuje uz ovo ako se ikad bude gradilo

- **`ADULT_AGE = 18`, i nepoznata godina znači odbijanje.** Pravilo iz
  `recordingConsent.js` ne sme da ostane iza u sobi: bez njega glas
  petnaestogodišnjaka završi u `uploads/`.
- **`/uploads` se servira statički i bez provere** (`server.js`). Danas je to
  bezopasno, jer URL ima samo vlasnik snimka — ali se naoruža istog trenutka kad
  se bilo šta podeli, jer je onda reč o trajnim linkovima bez provere. Obrazac za
  popravku već postoji: `signDownloadToken` / `authenticateDownloadToken`, kako
  MP4 izvoz već radi.

### Jeftina varijanta, kad se pojavi prvi trener koji pravi materijal

**Polje za link na lekciji.** Trener snimi postojećim putem (sam u sobi, MP4
izvoz), objavi na YouTube ili gde hoće, i nalepi link u lekciju. Jedna kolona i
jedno tekstualno polje: bez skladišta, bez Agore, bez novog puta za saglasnost,
radi i na webu, i zadržava akvizicionu stranu. To je ujedno i način da se sazna
da li treneri uopšte prave materijal, pre nego što se za to gradi cev.

### Naziv je ispravljen 27.8.2026, funkcija nije dirana

Kartica na početnom ekranu zvala se **„Snimljeni časovi (Replay)"**, a dijalog za
čuvanje nudio naziv **„Čas 27.8.2026"** — imena za nešto što aplikacija od
26.8.2026. više ne pravi. Sada je „Snimljeni materijal", odnosno „Materijal
27.8.2026"; isto i u dijalogu za čuvanje i u MP4 izvozu. Plejer, izvoz i
rekorder ostaju kakvi jesu, jer je zastareo bio **naziv, a ne funkcija** —
trener sam u sobi i dalje pravi materijal, i to je jedini snimak koji je
preživeo odluku iznad.

Test u `home_tabs_test.dart` pada ako se stara reč vrati, i proveren je
mutacijom.

### Polje „Unesite kod sobe" — razmotreno i namerno ostavljeno

Predloženo je 27.8.2026. da se izbaci sa početnog ekrana. **Ostaje za sada**, jer
na njemu vise dve stvari koje sa ekrana ne mogu da se vide:

- **Neprijavljen gost nema drugi ulaz.** `room_guests_dialog.dart` obećava
  „ulazi svako ko zna kod sobe, i neprijavljen", a to polje su ta vrata. Brisanje
  polja pretvara guest-access prekidač u obećanje koje se ne može ispuniti.
- **Poruka o zakazanom času sama deli kod.** `routes/social.js` upisuje
  obaveštenje čiji tekst glasi „Kod sobe: …", pa bi posle brisanja učenik dobijao
  broj koji nema gde da otkuca.

Prijavljeni učenik ionako ne zavisi od polja: postoje trenerov poziv uživo
(`lesson_invite_received`), obaveštenje o zakazanom času sa sopstvenim dugmetom
„Pridruži se", i traka za nastavak započetog časa. **Odluka o polju je, dakle,
odluka o gostima** — i tek kad se ona donese, briše se i ostalo što uz nju ide.

---

## Jedanaest nalaza sa prolaska kroz aplikaciju — 28.8.2026

Korisnik je vodio zaseban dnevnik provere (`D:/Projekti/mislisha-test/
TESTING_LOG.md`, van ovog repozitorijuma) sa jedanaest stavki: dva baga i devet
želja. Sve su rešene istog dana. Ovde stoji samo ono što se iz koda ne vidi —
razlozi, i dve stvari koje su namerno ostavljene.

### Stablo poteza je postojalo, samo se nije videlo

Najveći nalaz nije bio nedostatak funkcije nego njena nevidljivost. `MoveTree`
u `chess_game_screen.dart` odavno pravi varijacije, čuva ih i izvozi u PGN, a
`_promptBranchingDialog` čak pita gde novi potez ide. Ali `MoveHistoryView` —
napisan, potpun, sa varijacijama i komentarima — **nije bio pozvan nigde**, a
navigaciona traka ide isključivo kroz prvo dete. Trener bi se vratio dva poteza
unazad, odigrao drugi potez, i izvorni nastavak bi mu nestao sa ekrana iako je
i dalje bio u stablu.

Isto se ponovilo sa komentarima: `commentController` se održavao u koraku sa
izabranim čvorom na **četrnaest** mesta, a nijedno polje nije bilo vezano za
njega. Zato je stavka u dnevniku glasila „studio nema komentare ni čuvanje" —
čuvanje je radilo sve vreme, samo nije imalo šta da sačuva.

**Pouka koja se ponavlja:** grep na „ko koristi ovaj widget" pre nego što se
piše nov. Dva gotova, testabilna dela stajala su neupotrebljena, a nalaz je
opisan kao nedostatak arhitekture.

### Varijacije su, čim su postale vidljive, otkrile pravi bag

`PgnParser` (koji čitaju pregledač lekcije i ponavljanje) uklanja `{komentare}`
ali **nije uklanjao `(varijacije)`**. `chess.load_pgn` je zato poteze sporedne
linije čitao kao nastavak partije: `1. e4 (1. d4 d5) e5` vraća e4, d5, e5 —
liniju koju niko nije odigrao, prikazanu detetu kao domaći zadatak.

Nije grizlo dosad zato što ništa nije proizvodilo lekcije sa varijacijama.
Rešeno vidljivo (`PgnParser.stripVariations`, broji zagrade jer se varijacije
gnezde), ali obrazac je poznat: **funkcija koja se tek uključuje otkriva put
koji je oduvek bio pogrešan.** Isto kao `zlib.zstd*` i `sed s/^KEY=.*/`.

Uz to, trenerova beleška se sada vidi i učeniku, ispod table u pregledaču
lekcije. Linija se čita jednim parserom a beleške drugim, pa ako se ta dva ne
slože oko broja poteza, **ne prikazuje se nijedan komentar** — beleška ispod
pogrešnog poteza je gore od nijedne, jer izgleda kao da je trener rekao nešto
što nije.

### Traka sa čipovima poteza je uklonjena, ne isključena

Želja je bila da nestane vodoravna traka poteza iznad navigacije, svuda. Pošto
je `showMoveChips: true` stajalo na tačno dva mesta i ništa drugo nije čitalo
`MoveCursor.line`, uklonjeno je celo — `MoveStop`, oba `line` gettera, parametar
i sam widget. `formatMoveWithNumber` je ostao, jer sada imenuje potez u zaglavlju
polja za komentar.

### Šta je namerno izostavljeno

- **NAG oznake** (`$1` = `!`, `$14` = `⩲`). Tekstualni komentari putuju kroz PGN
  u oba smera; glifovi nemaju polje na `MoveNode`, izvoz ih ne piše, a uvoz
  `!`/`?` baca pri čišćenju tokena. Traži polje, birač u UI-ju i odluku šta sa
  tim što se već baca — sopstvena stavka, ne dodatak uz komentare.
- **Prevlačenje figure van table** u postavljanju pozicije. Dodir na istu
  figuru, dug pritisak i desni klik sada svi prazne polje; prevlačenje bi
  tražilo `Draggable`/`DragTarget` na svih 64 polja i na paleti, što je veće od
  sva tri zajedno a kupuje četvrti način za isto.

Obe stoje kao zasebne otvorene stavke u dnevniku provere.

---

## Dizajnerski prolaz na zasebnoj grani — spojen 28.8.2026

Vizuelni sloj je prvi put dobio svoj prolaz, i to kao eksperiment: zaseban agent
(Gemini) radio je u `git worktree`-u na grani `design/gemini-pass`, dok je ovde
tekao rad na funkcionalnosti. Spojeno istog dana, `2c19ca6`, bez ijednog
konflikta.

### Zašto se spojilo bez konflikta

Zato što je opseg bio uzak i napisan unapred. U Flutter-u izmena dizajna i
izmena ponašanja žive u istom fajlu, pa dva paralelna toka po pravilu prepisuju
ista stabla widgeta. Dogovoreno mu je tačno četvoro: sloj tokena, dva prazna
`ThemeData` bloka u `main.dart`, nova galerija koja postoji samo da se gleda, i
**jedan** pilot ekran. Sve ostalo je pisao kao predlog u `DESIGN-PROPOSALS.md`
umesto da menja kod.

**To je oblik koji vredi ponoviti**, a ne samo detalj ove runde: širok diff bi
bio bačen pri spajanju, a predlog nije. Pilot je bio trening hub — mali,
vizuelan, pokriven testom i van puta rada na stablu poteza.

### Šta je ušlo

- `lib/theme/app_theme.dart` — cela `ThemeData`, koju čitaju i `main.dart` i
  golden test. Namerno jedno mesto: tema je pre toga postojala u dva primerka,
  pa su se screenshotovi renderovali iz teme koju aplikacija ne isporučuje.
- Prefarban sloj tokena, sa **izmerenim kontrastom upisanim uz svaki token**,
  plus `app_spacing.dart` i `app_radii.dart`.
- Popunjena `ThemeData` prestilizuje svih 29 ekrana bez diranja ijednog od njih.
- Galerija na `/design-gallery`, dostupna isključivo kroz stavku iza
  `kDebugMode` na dnu Podešavanja — u release buildu je nema.

### Druga runda: paketi 14–43, spojeni 29.8.2026 (`71d3452`)

Prva runda je bila jedan pilot ekran i predlozi. Druga je odradila ostatak, kao
numerisani paketi na istoj grani: razmaci, tipografija, boje, kontejnerski
tokeni i pravila 23, 24, 25 i 26 koja su iz njih ispala. Devedeset fajlova,
+2990/−1968, bez ijednog konflikta.

Ono što se ne vidi iz diffa je da su **dve stvari bile odluke, a ne migracija**:

- **Pravilo 14 je suženo, ne ukinuto** (`c2e0ae0`). Ranije je govorilo da boja
  koja nosi šahovsko značenje ostaje literal. Zabrana da se `surface` rastegne
  da znači „beli“ ili „crni“ i dalje stoji; ono što je dodato je pošteno
  rešenje — takva boja sme da dobije **token sa domenskim imenom**, koji odlučuje
  čovek i dodaje paket napisan za to, nikad izmišljen usput.
- **Paketi 42 i 43** su dodali prva tri takva tokena (`sideWhite` #F1F5F9,
  `sideDraw` #64748B, `sideBlack` #020617) i prebacili četrnaest literala na
  njih: tri polja u eksploreru otvaranja, obe trake evaluacije u obe
  orijentacije, izabrano stanje u biraču strelica i maketa u galeriji.

Četiri predložene grupe tokena su **odbijene** 29.8.2026 (osmostepena skala za
Syzygy, `boardHighlight`, `brandBase`, `shadow`), pa literali koje bi one
zamenile i dalje stoje — namerno. Obrazloženje je u `report-batch-41.md` u
worktree-u.

Merenja koja su odlučila vrednosti nose testovi, ne komentari
(`chess_app/test/side_token_contrast_test.dart`): trake se razdvajaju međusobno
(4.34 / 4.24 / 18.41), a `sideBlack` se **ne može** razdvojiti od panela iza
sebe ni pri jednoj boji — čisto crno daje 1.18 / 1.44 / 2.03 na tri površine, pa
je to plafon a ne mana tokena, i granicu nosi `borderStrong`.

### Pouka, koja je opštija od dizajna

Od osam nalaza iz pregleda, **tri nisu bila loš dizajn nego netačna tvrdnja**:

- paleta dokumentovana kao 4.5:1 koja meri 2.72 (belo na `brand`, i to kao
  podrazumevani stil dugmeta, dakle za celu aplikaciju a ne za jedan ekran),
- zaglavlje koje garantuje AA za tokene koji ga ne ispunjavaju,
- i screenshotovi ponuđeni kao dokaz, na kojima nema nijednog slova, jer golden
  test ne učitava font.

Isti oblik kao sve u odeljku o ponavljajućem bagu: korak koji prijavi uspeh a
omane sloj niže. Uhvaćeno je samo zato što je **svaki broj preračunat nezavisno
i svaki ekran otvoren u pokrenutoj aplikaciji**. Kad sledeći put neki agent
napiše meru, meri je ponovo.

Vredi zabeležiti i jedan dobar znak: kod tvrdnje o kontrastu je mogao da oslabi
tvrdnju dok se ne poklopi sa bojama — umesto toga je promenio `danger` da tvrdnja
postane istinita.

### Šta ostaje otvoreno

- `DESIGN-PROPOSALS.md` (koren repoa) nosi ostatak: predlozi po ekranima,
  komponentna biblioteka, i **redosled za svetlu temu** — prvo migracija
  preostalih literala, pa svetli tokeni, pa podešavanje. Obrnutim redom svetla
  tema daje belo na belom.
- **Brojka „~53 fajla“ je zastarela od 29.8.2026**, i posle paketa 44 migracija
  boje je gotova. U `lib/` je ostalo **35 literala i svi su tu namerno**:
  strelice (`board_overlay_painter.dart`, 14), Syzygy skala (8), polja table
  (`board_thumbnail.dart` i dva `board_setup_dialog.dart`, po 2), `main.dart`
  seed (2), poteg oko izabranog polja i poteg ispod broja u traci evaluacije
  (2), i dve senke (galerija, plejer). Za četiri grupe tokena koje bi ih
  zamenile odlučeno je da se **ne** prave. Ako neko ubuduće izmeri drugi broj,
  prvo proveri je li dodat nov literal, a ne je li lista pogrešna.

  **Od 29.8.2026. uveče ih je 29**: šest polja table otišlo je u `BoardSkin`
  (odeljak niže). To nije izuzetak od pravila 14 nego njegova druga izmena —
  domenska boja sme da dobije domenski token, a `BoardSkin` je taj token za
  tablu. Strelice ostaju literali i nisu pokrivene.
- Svetla tema je bila namerno **ne**napisana: `ThemeMode` je bio zakucan na
  `dark`, a `setThemeMode` nije postojao nigde u `lib/`. Napisana je 29.8.2026
  (paket 45, `b4fb881`), i istog dana je **faza 5 dodala birač** — tema, tabla i
  figure biraju se u odeljku „IZGLED" u Podešavanjima. Nije više mrtav kod.
  Odeljak niže.
- `DESIGN-BRIEF.md` je posle spajanja ostao na korenu. Pisan je agentu („ovo
  smeš da menjaš"), pa kao projektna dokumentacija tu ne stoji — treba ga
  premestiti u `docs/` kao zapis o tome kako je opseg omeđen, ili obrisati.
- Natpisi na dugmadi su na goldenima i dalje kutije: `textStyle` u temi nema
  `fontFamily`, pa ne hvata font učitan u testu. U pravoj aplikaciji se
  iscrtavaju ispravno, provereno na Windows buildu. Jedan red u `AppTheme` kad
  se bude diralo.

---

## Presuda koja se čitala iz kategorije, a ne sa table — 28.8.2026

Korisnik je prijavio nešto što je zvučalo kao sitnica: u vežbi protiv motora
može se u stablu poteza vratiti na poziciju gde je motor na potezu, odigrati
taj potez sam, i od tada motor igra ono što je bila korisnikova strana.

Tačno, i uzrok je bio da **pojam „korisnikova strana" nije ni postojao**. Motor
je bio definisan čisto reaktivno — posle čovekovog poteza, motor odgovara — što
važi sve dok se čovek ne vrati unazad i ne preuzme motorov potez.

### Šta se našlo dok se tražilo gde ta praznina smeta

Gore od prijave. U `ai_studio_screen.dart`, unutar obrade **motorovog** poteza:

```dart
if (in_checkmate) {
  if (category == 'basic_mate') showSnackBar('Stockfish vam je zadao mat');
  else { _puzzleSolved = true; _showEndgameWinDialog(); }
}
```

Motor je upravo odigrao, dakle mat je uvek onaj koji je korisnik **primio**. Sve
što nije `basic_mate` padalo je u dijalog **„🎉 POBEDA! Uspešno ste zadali mat
Stockfish-u"** i obeležavalo vežbu kao rešenu — pa je `winning_position`
čestitao detetu na matu koji ga je upravo dokrajčio. **Za to nije bila potrebna
nikakva zamena strana**; zamena je samo činila lakim da se dođe dotle.

### Pouka, koja se ponavlja u ovom repozitorijumu

Presuda se izvodila iz **koja je ovo vežba** umesto iz **šta je na tabli**.
Isti oblik kao svuda u odeljku o ponavljajućem bagu: odgovor se čita sa
pogrešnog mesta, a pogrešno mesto se najčešće slaže sa tačnim — dok se jednog
dana ne raziđu.

Zato `core/models/drill_outcome.dart` ne prima ni kategoriju ni „ko je poslednji
vukao": to su dva ulaza koja su davala pogrešan odgovor, pa sada **ne postoji
način da se proslede**. Mat imenuje svoju žrtvu time ko je na potezu. Obe
presude na ekranu idu kroz jednu funkciju, umesto dva pravila koja su se već
jednom razišla. Test je dokazan mutacijom: vraćanje starog pravila obara tri od
deset.

### Ostala tri ekrana su čista, svaki iz svog razloga

Provereno istog dana, jer je pitanje bilo da li isti oblik postoji drugde:

- `repertoire_drill_screen` — strana se **prosleđuje** (`widget.color`), a
  protivnikovi odgovori dolaze iz knjige, ne od motora.
- `blunder_walk_screen` — nema protivnika-motora ni presude o matu; to je
  šetnja kroz već odigranu partiju.
- `endgame_trainer_screen` — presudu daje **server** (`solve.submit`), pa se
  lokalno i ne izvodi. Komentar u fajlu to i kaže.

Praznina je, dakle, bila samo tamo gde se presuđivalo lokalno bez pojma o
stranama.

---

## Teme, boje polja i boje figura — plan i faze 1–5, 29.8.2026

Plan u celini je u [PLAN-TEME-I-TABLA.md](PLAN-TEME-I-TABLA.md); ovde stoji samo
ono što je urađeno i šta treba znati pre nastavka.

Opseg je odlučio vlasnik projekta 29.8.2026: **svetla + tamna + sistemska** tema,
bez dodatnih imenovanih paleta, i **prefarbavanje** postojećih figura umesto
novih kompleta. Koža table je nezavisna od teme aplikacije — zelena tabla je
legitiman izbor i u svetloj i u tamnoj temi.

### Četiri stvari iz koda koje su odlučile oblik

1. **Svetla tema nije bila isključena nego zamka.** `init()` je prepisivao svaki
   sačuvani `themeMode` u `dark`, a svetla `ThemeData` u `main.dart` nije nosila
   `AppColorTokens` — `context.colors` pada nazad na tamne tokene, pa bi svih 29
   ekrana pisalo tamnim tekstom po svetloj podlozi. Ta linija u `init()` je
   jedino što je stajalo između sačuvanog izbora i nečitljive aplikacije.
2. **Boje polja nisu bile podesive.** `flutter_chess_board` crta tablu sa
   `Image.asset` — četiri gotove PNG slike, bira ih enum. Paket to neće dobiti:
   i dalje piše `sdk: <3.0.0` i i dalje zove `onWillAccept`.
3. **Boje figura su bile besplatne.** `chess_vectors_flutter` oduvek prima
   `fillColor` i `strokeColor`, a crne figure i treću, `decorationColor` (oko i
   griva skakača, krst na kralju). Ništa u aplikaciji ih nije prosleđivalo.
4. **Animacija poteza je bila zavarena za sliku**: polje na koje figura sleće
   pokrivalo se **isečkom PNG-a** table, postavljenim na negativan offset unutar
   isečenog kvadrata. Sa farbanim poljima nema šta da se iseca.

### Šta je urađeno

**Faza 1** (`b937af9`) — `lib/theme/board_skins.dart`: `BoardSkin` i `PieceSkin`,
po jedna koža svaka. Namerno **nisu** `ThemeExtension`: koža preživljava promenu
teme, a `pieceImageForAnimation` nema `BuildContext` iz kog bi je čitao.

`BoardSkin.classic` je #F0DAB5 / #B58763 — to nisu izmišljene vrednosti nego
**izmereni pikseli** `brown_board.png`, koji je ravna dvobojna slika a ne tekstura
drveta (120 boja u celom fajlu, sve na spojevima polja). Zato je prelazak na
farbanje piksel u piksel isti, samo bez mutnih spojeva.

**Faza 2** — `lib/widgets/board/skinned_chess_board.dart`, fork `ChessBoard`-a iz
paketa. Paket **ostaje** zavisnost: `ChessBoardController` i `PlayerColor` se
zovu u 35 fajlova, a menja se samo widget koji crta. Uz to: jedna fabrika figura
za celu aplikaciju (`board/chess_piece_image.dart`), pokrivka animacije farba
polje umesto da seče sliku, i sličice i oba editora pozicije crtaju istu tablu —
do sada su bili tri različita: mrka, zelena i tirkizna.

**Promocija prevlačenjem sada pita na srpskom.** To je bila poznata rupa opisana
u zaglavlju `promotion_picker.dart`: svaki potez tapkanjem je pitao na srpskom, a
prevlačenje je otvaralo dijalog paketa („Choose promotion", i uvek četiri bele
figure). Fork ju je zatvorio usput.

Mere: 836 testova (12 novih), 1 preskočen, `flutter analyze` na istih 29 poznatih
`info`-a. Oba tvrđenja o **iscrtavanju** dokazana su mutacijom — zamenom svetlog
i tamnog polja u painteru, pa u pokrivci animacije; oba puta su pala kako treba.

Uživo nije viđeno: [TODO-provera.md](TODO-provera.md), stavka 47.

### Vid i boje — mereno, ne procenjeno, 29.8.2026

Povod je jedna rečenica vlasnika projekta: *„sve je ekstra, boje, kontrasti,
inače sam daltonista"*. To menja šta znači „provereno uživo" na ovom projektu —
njegova potvrda dokazuje svetlinu, veličinu i oblik, a **ne** dokazuje da se dve
boje razlikuju po tonu. Zato je merenje moralo da zameni oko.

**`test/support/color_vision.dart`** — simulacija dihromatskog vida po Viénot,
Brettel & Mollon (1999): jedna 3×3 matrica po deficitu, primenjena u
**linearnom** RGB-u. Uz nju `over()` (spljošti providnu boju na podlogu, jer se
meri ono što je na ekranu a ne ono što je prosleđeno `Paint`-u), WCAG kontrast, i
`worstContrast()` koji vraća najgori slučaj kroz sva tri vida.

**Tritanopija namerno nije tu.** Viénot-ova simplifikacija važi za protan i
deutan i poznato je da za tritan ne valja — sam rad to kaže. Broj koji proizvede
model koji ne važi gori je od nikakvog broja, jer će mu se verovati.

Instrument se proverava pre nego što mu se veruje, kao i sve ostalo ovde: siva
prolazi kroz simulaciju nepromenjena, a crvena i zelena padaju na istu žutu osu.
Prva verzija tog testa je pala i bila je u pravu što je pala — poređenje je bilo
na `double`-ovima, a povratak sRGB → linearno → matrica → sRGB promaši polaznu
tačku za nekoliko desethiljaditih. Poredi se `toARGB32()`, jer je to ono što se
crta.

**Šta su brojke rekle:**

- **Figure prolaze, sve.** Ivica figure naspram polja: najgori slučaj kroz sva
  tri vida i ceo katalog je **3.36:1**, iznad praga 3.0. Ispuna naspram ivice ne
  pada ispod 14.65:1. Žute figure iz kompleta „Visoki kontrast" drže 19.56:1 i
  pod oba deficita — žuto na crnom je jedan od najotpornijih parova koji postoje,
  pa je ta odluka i pod ovim merenjem u redu.
- **Oznaka poslednjeg poteza pada.** `warning` na 45% naspram polja ispod sebe:
  **1.03:1** u najgorem slučaju (plava tabla, tamna paleta, svetlo polje,
  deuteranopija). To nije slab signal po svetlini nego nikakav — oznaka se
  videla isključivo kao promena tona.

**Šta je urađeno s tim.** `ChessBoardPainter` sada crta i **uglove**: četiri
prava ugla ka unutra, u dva poteza — crni oreol pa belo jezgro preko njega. Amber
ostaje netaknut; ovo je **dodato**, nije zamenjeno, jer je vlasnik odobrio kako
tabla izgleda i to nije trebalo prepravljati.

Zašto baš dve boje a ne jedna pametno izabrana siva: crno drži 4.4:1 naspram
svakog polja svake kože, belo drži 3.0:1 naspram svakog tamnog, pa se crtanjem
**oba** garantuje da bar jedno ima ivicu ma na čemu stajalo. Obe su ahromatske,
pa ih simulacija ne pomera uopšte — nema tona koji bi izgubile. To je i jedina
stvar koju test o tome tvrdi: raniji pokušaj je tvrdio da se *kontrast* uglova ne
menja po vidu, a to je netačno, jer se polje ispod njih menja i kad se ugao ne
menja.

Uglovi su i treći kanal povrh drugog: četiri prava ugla ne liče ni na šta drugo
na ovoj tabli, pa oznaka radi i za nekoga ko gleda crno-belu sliku.

Mere: **881 test** (12 novih), 1 preskočen, `flutter analyze` na istih 29
`info`-a. Oba tvrđenja dokazana mutacijom — kad se uglovi ne crtaju, padaju tri
testa; kad im se boje zamene tonovima umesto crno-bele, padaju tri druga.

### Strelice — izmereno 29.8.2026, popravka nije počela

Nije 14 boja nego **pet**, upotrebljenih dvaput: `arrowPalette` (R/G/B/O/P, koje
korisnik bira kad crta) i `_getEngineColor(rank)` (isti komplet, drugim redom,
za pet linija motora). Brief za Gemini je
[brief-arrow-colours-2026-08.md](brief-arrow-colours-2026-08.md); ovde su nalazi.

1. **Dva para su ista boja.** `R`/`P` mere **1.04:1** pod protanopijom — crvena i
   ljubičasta su jedna boja. `R`/`B` 1.07 pod deuteranopijom. A `B`/`O` mere
   **1.07 i pod normalnim vidom**: taj par razlikuje samo ton, za sve. Najbolji
   par u kompletu je 2.00:1.
2. **Svaka strelica nestane na nekom polju.** Spljoštena na 0.75 alfe naspram
   polja ispod sebe, najgori slučaj kroz svih pet koža i sva tri vida: R 1.02,
   G 1.02, B 1.04, O 1.12, P 1.01.
3. **Strelice motora su mnogo manje pokvarene nego što izgledaju**, i to je zamka
   ovog zadatka. Rang je već kodiran dvaput — bojom **i debljinom**,
   `7.0 - (rank - 1) * 1.5`, pa je najbolja linija 7 px a peta 1 px. Zeleno
   naspram crvenog za najbolje-naspram-najgore je 1.53:1 pod deuteranopijom, što
   zvuči loše i preživljava, jer debljina to već kaže. Ono što nema drugi kanal
   je **korisnikova** strelica: sve su 6 px.

**Boje su izabrane 29.8.2026** — `lib/theme/arrow_colors.dart`, sa
`test/arrow_color_contrast_test.dart`. Odeljak niže objašnjava zašto je prag
1.5, a ne 1.8.

**Nov bag, nađen usput i nije od strelica: značka evaluacije je nečitljiva u
svetloj temi.** `badgeTextColor` je `context.colors.canvas` — skoro crno u tamnoj
temi (8.8:1, u redu) i skoro belo u svetloj, gde rang 1 meri **1.55:1**. Svih
deset kombinacija u svetloj temi je ispod 4.5:1. Ovo je postalo dohvatljivo tek
fazom 5, kad je svetla tema mogla da se izabere. Tekst značke mora da se bira iz
svetline same značke, ne iz teme. Claude-ovo, nije počelo.

### Zašto je prag za strelice 1.5, a ne 1.8 — 29.8.2026

Batch 47 (Gemini) je dobio prag **1.8** za svaki par boja i rečenicu da boje
moraju da ostanu prepoznatljive po imenu. Isporučio je 1.771 i **rekao da nije
stigao do 1.8**, sa označenim ćelijama — što je bilo ispravno ponašanje i razlog
što je runda bila jeftina. Svih trideset brojki za parove, svih deset za halo i
svih šest za rangove motora prekontrolisano je nezavisno i **sve su tačne**;
četiri od pet simuliranih heksova promaše za jedan bit u poslednjem mestu, što je
zaokruživanje pri ispisu i ništa izvedeno iz njih se ne pomera.

Cena je bila narandžasta `#88370E`, koja je **braon**, i crvena `#FA8158`, koja
je losos — a njih dve su na 5° razmaka po tonu, dakle ista boja razdvojena samo
svetlinom.

**Onda je pretražen prostor, i ispalo je da 1.8 nikada nije ni bilo dostižno:**

| šta se drži fiksno | najveći dostižan prag |
|---|---|
| ton u ±15° od imena | **1.50** |
| ton u ±20° od imena | **1.50** |
| ton u ±25° | 1.60, ali narandžasta odluta u žutu |
| ton napušten | 1.77 — tačno ono što je Gemini našao |

Razlog je strukturni: pod oba deficita pet boja pada na **dve** tonske ose, pa
sve moraju da se razdvoje svetlinom, a pojas svetline koji ih drži dalje od crne
i bele ograničava koliko to može da ide. Zamena narandžaste tirkiznom na 180°
ostavlja plafon na tačno 1.50 — dakle nije stvar izbora tona.

Dve greške u prvom brifu, obe moje:

1. **Halo pravilo je bilo prazno.** „Nijedna boja ne sme biti unutar 1.2:1 od
   *obe*, crne i bele" ne može da se desi: ispod 1.2 prema crnoj traži L < 0.01,
   ispod 1.2 prema beloj traži L > 0.825. Gemini je pročitao strože — svaka boja
   čisti 1.2 prema obema — i to je jedino čitanje koje išta ograničava. Popravio
   je pravilo umesto mene; granica je sada 1.1 i u tom, strožem čitanju.
2. **Prepoznatljivost je bila rečenica, a prag broj.** Kad jedno ima meru a
   drugo nema, žrtvuje se ono bez mere, i to je ispravno ponašanje agenta.

Finalne vrednosti su birane pretragom koja **minimizuje odstupanje tona**, ne
prvim rešenjem koje prođe: `#FF2929`, `#FF9429`, `#85FF85`, `#00188F`,
`#910FB3` — odstupanja 0°, 0°, 0°, 10°, 2.5°. Najgori par 1.50 (B/P,
protanopija).

**Test sada meri i prepoznatljivost**, i prvi pokušaj te mere je bio pogrešan:
jedinstven pojas svetline 0.28–0.80 propuštao je `#88370E` (ton 20, unutar
dozvole; svetlina 0.29, unutar pojasa). Braon je prošao test napisan da uhvati
braon — uhvatio ga je test za parove, što je sreća a ne pokrivenost. Topli
tonovi gube ime kad potamne a hladni ne: tamna narandžasta je braon, tamna
crvena je bordo, a mornarsko plava je i dalje plava. Prag je zato **0.45 za luk
od crvene do žute i 0.28 za ostalo**. Nađeno mutacijom, kao i sve ostalo ovde.

### Ožičenje strelica — 29.8.2026

Sve troje je urađeno i sve troje je isti potez: dodaj kanal, ne prepravljaj boju.

**Strelica ima obrub.** `_drawSingleArrow` sada crta u tri prolaza — crni obrub
(+5 px), beli (+2.5 px), pa sama strelica. Oba obruba su ahromatska, pa se ne
pomeraju pod simulacijom, a crno drži 4.4:1 naspram svakog polja svake kože i
belo 3.0:1 naspram svakog tamnog. **To je ono što je paleti dozvolilo da stane
na 1.5** — spljoštena na svoju alfu, svaka boja strelice pada između 1.01:1 i
1.12:1 naspram nekog polja, i nijedan izbor pet boja to ne popravlja, jer je
problem polje a ne paleta.

**Značka evaluacije više ne uzima boju iz teme.** `badgeTextColor` je uklonjen
iz `ChessBoardPainter` i sa svih šest mesta poziva; tekst se sada bira iz
svetline same značke (`ChessBoardPainter.readableOn`). To popravlja četiri od pet
rangova odmah. **Peti se ne da popraviti izborom boje**: crvena `#FF2929` stoji
na svetlini gde crno daje 3.04:1 a belo 3.74:1 i nijedno ne stiže do 4.5:1, jer
je ispuna srednje tonirana. Zato glif nosi **oba** — ispunjen boljim, oivičen
drugim — pa je ivica unutar samog glifa 21:1 ma na čemu stajao. Ista logika kao
strelica i kao uglovi poslednjeg poteza.

**Pločica se više ne zatamnjuje, i to je popravka a ne previd.** Neizabrana
pločica se crtala na 40% preko panela — tako je radio i prvobitni dizajn. Mereno
naspram tamne teme: `Crvena` postaje `#782934`, `Narandžasta` postaje `#785434`,
oba topla tona **ispod praga svetline koji deli narandžastu od braon** — tačno
onaj promašaj zbog kog je odbijena Gemini-jeva paleta. Uz to je najgori par pao
sa zagarantovanih 1.50:1 na **1.10:1**, i to u kontroli čiji je jedini posao da
se boje razlikuju. Birač koji zatamnjuje ono što prikazuje ne prikazuje ništa.
Izbor nose prsten i sjaj, za to i služe. Nađeno tako što je vlasnik poslao
screenshot, pa su boje **izmerene onako kako se crtaju** umesto procenjene okom.

**Pločica u biraču ima slovo.** `ArrowColorButton` prima `ArrowColor` umesto
boje i tooltipa (koji su bili otkucani na osam mesta), i crta inicijal srpskog
imena: **C, N, Z, P, Lj** — pet različitih, što je sreća koju vredi iskoristiti.
Pet krugova koji se razlikuju samo bojom je pet istih krugova za nekoga ko boje
ne razdvaja, a tooltip progovori tek na hover ili dug pritisak.

`arrowPalette` je nestao iz painter-a; `_getColor` je `ArrowColor.byId`, a
`_getEngineColor` mapira rang na katalog uz **nepromenjen redosled** (1 zelena,
2 plava, 3 narandžasta, 4 ljubičasta, 5 crvena) — to je ono što je čitalac
naučio. Rang i dalje nosi i debljina, `7.0 - (rang - 1) * 1.5`, i to je kanal
koji zapravo preživljava deficit.

Mere: **900 testova** (11 novih), 1 preskočen, analyze na istih 29. Tri mutacije:
bez obruba pada 4 testa, stari zeleni literal za rang 1 pada 1, `readableOn` koji
uvek vraća belo pada 2.

**Šta se vidi na renderu, i kako je pitanje zatvoreno.** Obrub radi — svaka
strelica se čita na svakoj koži, i to je bio glavni cilj. Ostalo je otvoreno da
li 1.50:1 dovoljno razdvaja plavu od ljubičaste, jer na simuliranom renderu
deluju skoro isto, i zapisao sam da bi rešenje bio kanal a ne boja.

**Nije potrebno. Vlasnik projekta, koji je daltonista, potvrdio je 29.8.2026. da
ih razlikuje** — na živoj tabli, u obe teme. To je najbolji dokaz koji ovo
pitanje može da dobije, bolji od simulacije, jer simulacija modeluje
dihromatiju a stvarni deficit je najčešće blaži. **Ako neko ubuduće bude
„popravljao" taj par isprekidanom linijom ili slovom uz rep — ovo je razlog da
ne.** Plafon od 1.50 je dovoljan.

Šta ovo *ne* znači: par je i dalje najslabiji u katalogu i test ga i dalje drži
na 1.50. Potvrda je da je 1.50 dovoljno, ne da razdvojenost više nije bitna.

### Šta sledi

- **Paket 45 (Gemini)**: gotov i spojen 29.8.2026 (`b4fb881`).
  `AppColorTokens.light` + `AppTheme.light`, svih trideset uloga, `theme:` u
  `main.dart` umesto seed-a. Ništa se ne vidi — `themeMode` je i dalje `dark`.

  Presuda harness-a bila je FAIL i **bila je uglavnom do kapija**: dva prava
  propusta (galerija je čitala `Theme.of(context).brightness`, što druga
  polovina pravila 19 zabranjuje, i natpis `Light` na srpskom ekranu), a treća
  kapija je pala na fajlovima koje je zadatak **tražio**. Svih trideset
  navedenih kontrasta prera­čunato je nezavisno i svih trideset je tačno; test
  registracije dokazan je mutacijom.

  Ono što nijedna kapija nije mogla da vidi našlo se otvaranjem screenshota:
  petnaest pločica palete nosilo je heks i kontrast **kao otkucan tekst**.
  Tačno za tamnu paletu, i laž onog trenutka kad isti ekran nauči da crta
  svetlu — `#1E293B` ispod belog kvadrata. Sada se oboje čita iz same boje.
  Isti oblik kao sve u odeljku o ponavljajućem bagu: nešto što **prijavljuje**
  vrednost umesto da je pročita.

  `report-batch-45.md` nije napisan (pravilo 22). Brojke su zato provere­ne
  ručno.
- **Paket 46 (Gemini)**: gotov i spojen 29.8.2026. Pet tabli (`classic`,
  `Zelena`, `Plava`, `Visoki kontrast`, `Siva`) i tri kompleta figura
  (`Klasične`, `Tople`, `Visoki kontrast`), i test koji **množi oba kataloga**
  umesto da nabraja slučajeve. Dokazan tako što je dodata šesta, namerno
  pokvarena tabla — petlja ju je uhvatila na dva mesta, što spisak ručno
  napisanih slučajeva ne bi.

  Sve brojke iz `report-batch-46.md` prera­čunate su nezavisno i sve su tačne —
  drugi paket zaredom. Merilo nosi **ivica** figure, ne ispuna: bela ispuna na
  svetlom polju meri oko 1.3:1 i oduvek je merila toliko.

  Tamno polje table „Visoki kontrast" je srednje sivo (#737373), a ne skoro
  crno, i izveštaj kaže zašto: na #222222 crna ivica figure meri 1.32:1, pa bi
  tabla napravljena da se bolje vidi izbrisala svaku crnu figuru.

  Kapija `strings` je oborila paket zbog **srpskih imena koja mu je zadatak
  tražio** — isti oblik kao kod paketa 45. Popravljeno u harness-u: kapija sada
  prima spisak fajlova u kojima paket sme da **doda** string; brisanje i izmena
  i dalje padaju, jer je to polovina pravila 12 koja nešto čuva.

- **Nalaz koji niko nije tražio, i jedini koji traži odluku**: oznaka poslednjeg
  poteza je `warning` — ispuna na 45% plus obod od 2,5 px — i **po svetlini se
  jedva razlikuje od polja ispod sebe**. Ispuna prema neoznačenom polju meri
  1.05–1.94 kroz svih pet tabli i obe palete; najgore je na plavoj tabli sa
  tamnom paletom (1.05 i 1.06). Za tamnu paletu na klasičnoj tabli: 1.10 na
  svetlom polju, 1.35 na tamnom.

  **To je merenje svetline, a ne presuda.** Žuto preko krem polja i dalje
  izgleda žuće, a promena tona se vidi i kad je razlika u svetlini mala — zato
  ovo niko do sada nije prijavio kao bag.

  **Razrešeno 29.8.2026, i razrešeno je u drugom smeru nego što je pisalo
  ovde.** Onaj argument — „promena tona se vidi i kad je svetlina ista" — traži
  oko koje razlikuje tonove. Vlasnik projekta je daltonista, a korisnici su deca
  među kojima otprilike svaki dvanaesti dečak ima crveno-zeleni deficit. Za njih
  taj argument ne važi, pa oznaka koja je nosila samo ton nije nosila ništa.
  Rešenje je ono koje je gore i predviđeno: **oznaka koja ne zavisi od boje.**
  Odeljak niže.
### Faza 5 — birač, 29.8.2026

Odeljak **„IZGLED"** u `settings_screen.dart`, iznad „NALOG": tema
(Sistem / Svetla / Tamna) kao čipovi, pa pet tabli i tri kompleta figura kao
pločice koje se tapkaju. `setThemeMode` pamti izbor, a **prisila na tamnu temu u
`init()` je uklonjena**.

Ta linija nije samo ignorisala sačuvanu vrednost nego ju je i **prepisivala** na
svakom pokretanju, i to od `6780886` (13.8.2026). Praktična posledica: svako ko
je otvorio aplikaciju posle tog datuma već je izgubio svoj izbor, pa „oživljene"
svetle teme ima samo na instalaciji starijoj od toga. Redosled faza je i dalje
bio tačan — polje dejstva je samo manje nego što je plan pretpostavljao.

Tri odluke koje je doneo kod, a ne plan:

- **Pregled nije dvaput `BoardThumbnail`.** Tabla se sudi celom tablom i dobija
  je na 72 px. Komplet figura je ispuna, ivica i dekoracija — ništa od toga ne
  preživljava polje od devet piksela — pa dobija četiri figure na 30 px, na dva
  polja **izabrane** table: bela figura na tamnom polju i crna na svetlom, pa
  obrnuto, jer su to dva para koja padaju.
- **Prsten izbora je 2 px u oba stanja**, samo druge boje kad nije izabran.
  Ivica koja menja debljinu menja širinu pločice, pa se `Wrap` prelama pod
  prstom koji ju je upravo dodirnuo.
- **Sve je `Wrap`.** Tri srpska čipa su već 330 dp naspram 316 koliko kartica
  ima na telefonu od 360 dp, pa se red teme namerno prelama 2 + 1.

Dvanaest testova u `test/appearance_settings_test.dart`, i svaki tvrdi šta se
**iscrtava** posle dodira, a ne šta je zapamćeno: svetli tokeni ispod ekrana
(poređeni polje po polje — `Theme` dok animira izdaje *lerpovan*
`AppColorTokens`, pa identitet nikad ne pogađa), `SkinnedChessBoard` bez
prosleđene kože koji crta zeleno, `chessPieceWidget` bez prosleđene kože koji
nosi toplu ispunu, i koža koja preživi prelazak na svetlu temu. Dokazano
mutacijom: vraćanje prisile u `init()` i praznjenje oba `onTap`-a obara sedam od
dvanaest.

**Uz put su nađena dva prelivanja, oba zatečena i oba na ovom ekranu.** Na 360 dp
red „Maksimalno vreme razmišljanja engine-a:" u kartici motora prelivao se za
303 px, a zaglavlje kartice naloga za 26 — nevidljivo, jer release build seče
umesto da išara. Oba natpisa su sada `Expanded`, zajedno sa druga dva reda
natpis/vrednost u istoj kartici. Nađena su samo zato što novi test pumpa na
`Size(360, 640)`.

Mere posle faze 5: **869 testova** (12 novih), 1 preskočen, `flutter analyze` na
istih 29 poznatih `info`-a.

Uživo nije viđeno: [TODO-provera.md](TODO-provera.md), stavke 47, 48 i 49.

## Sopstvene partije kao korpus — predlog, 30.8.2026

Pitanje je bilo: korisnik preda arhivu od nekoliko hiljada svojih partija sa
Lichess-a — šta se s njom može uraditi, a ne može se uraditi partiju po partiju?
Odgovor je u [PLAN-MOJE-PARTIJE.md](PLAN-MOJE-PARTIJE.md). **Ništa od toga nije
napisano**; dokument je predlog, ali su brojke u njemu **merene** na stvarnoj
arhivi od 4073 partije, a ne procenjene.

Tri nalaza koja odlučuju šta vredi graditi:

- **Signal živi između 6. i 20. poluteza.** Na 12. potezu 4073 partije stoje na
  2749 različitih pozicija (najčešća se ponavlja 52 puta); do 20. ih je 3869 i
  najčešća se ponavlja 8 puta. Posle desetog poteza svaka je partija skoro
  jedinstvena i statistika po poziciji prestaje da znači išta.
- **Izveštaj o otvaranjima je besplatan** — nula motora, nula mreže, samo
  brojanje. Na uzorku: 14 pozicija na 10. polutezu koje se ponavljaju bar 8 puta
  a nose ispod 42%, i u jednoj od njih isti potez odigran 33 od 35 puta. To je
  navika, ne varijansa.
- **Završnice preko Syzygy-ja su jeftine i tačne.** Cela arhiva ima 8673
  različite pozicije sa ≤7 figura — oko 22 minuta kroz postojeći `lichessPacing`
  — i 234 partije koje su ušle u tablice a nisu dobijene. Presuda „izgubio si
  dobijenu" je činjenica, ne mišljenje motora, što je tačno ono što
  `tablebaseService.js` čuva.

Ono što nedostaje je **jedno**: tabela sa partijama korisnika. `blunder_games` je
uvezen javni skup, ne korisnikov. Sve ostalo u planu je upit nad tom tabelom.

Skupo je samo prolaz motorom: ~273k pozicija za celu arhivu, ~7–8 sati na dubini
14 u jednoj niti. To je noćni posao na desktopu, ne na dropletu od 960 MB, i
nikako ne kroz cloud-eval — jedan izlazni IP za sve korisnike.

**Usput provereno uživo 30.8.2026**: Lichess daje partije **bilo kog** naloga
nepotpisanom pozivaocu (HTTP 200, bez tokena), pa je priprema za protivnika isti
izveštaj usmeren na drugog igrača. Parametar `vs=` vraća samo međusobne partije,
a `opening=true` dodaje `[ECO]` i `[Opening]` — ECO baza lokalno ne treba.
Detalji i jedna odluka koja ostaje proizvodu (dozvoliti li profilisanje
imenovanog deteta) su u planu.

**Podela posla dogovorena 30.8.2026** i upisana kao sekcija 8 plana: Claude —
šema, serverska logika, prava pristupa i sve što je *garancija*; Gemini — UI,
izolovana logika na klijentu i widget testovi. Linija nije „server naspram
klijenta" nego **koliko košta pogrešan odgovor**: brojač koji se računa u UI-ju
može da izbroji samo ono što je do njega stiglo, a rangiranje na klijentu samo
ono što mu je poslato — pa su oba prešla na serversku stranu. Pre nego što bilo
šta osim uvoza krene: **šema mora biti zamrznuta i mora postojati zasejana
fixture baza**, inače se gradi UI nad oblikom koji se još pomera.

**Faza 0 napisana 30.8.2026** — šema je zamrznuta. Tri tabele u `db.js`
(`user_games`, `user_game_imports`, `mistake_reviews`) i čist modul
`services/gameArchive.js` koji od jedne PGN partije pravi red ili **imenovano
odbijanje** (pet razloga, i tally odbija svaki šesti). Kolone koje nose ugao
gledanja zovu se po **subjektu**, ne po vlasniku reda — ista tabela nosi i
protivnikovu arhivu, pa bi imena po vlasniku učinila svaku agregaciju pogrešnom
čim se okrene ka nekom drugom, i to pogrešnom uz uredne brojeve. Uslov u bazi
drži `read = stored + duplicate + skipped` kad run stane na `done`, a
`assertBalanced()` puca i pre toga. Testovi: 541 → **556**, svi zeleni.

Modul je pušten preko **stvarne arhive od 4126 partija** (30.8.2026): 4126
pročitano, 4126 redova, nijedna preskočena ni duplirana; ECO na svima, sat na
3632 (starije partije su od pre nego što ih je Lichess beležio), 471 partija
ušla u domet tablica, 276.877 poluteza za 68 sekundi. Parsiranje, dakle, neće
biti usko grlo uvoza — stream hoće.

**Provereno uživo — korisnik, log u 23:40 29.8.2026**: `initDB()` je prošao nad
upravljanom bazom i prijavio `user_games`, `user_game_imports` i
`mistake_reviews` odmah posle `room_guests`, a server je podigao port 3000.
Dakle DDL je *primenjen*, ne samo napisan — sa oba check uslova i parcijalnim
indeksom, koje baza sme da odbije pri kreiranju a nije.

Sledeće na redu je sam uvoznik (jedan stream sa Lichess-a, upis kroz tally) i
tek onda sve ostalo iz plana.

**Uvoznik napisan 30.8.2026** — `services/gameArchiveImport.js` i
`routes/userGames.js` na `/games`. Cela arhiva je **jedan stream**, ne hiljade
zahteva, pa ograničenje nije broj upita u sekundi nego to što server ima jednu
adresu za sve korisnike — zato i taj jedan zahtev ide kroz isti pacer kao
explorer. Traje minutima, pa ruta vraća 202 i `importId`, a klijent pita kako
ide; run koji padne upiše svoj razlog u svoj red, jer u trenutku pada odgovora
odavno nema.

Četiri ponašanja koja treba znati: nastavlja se od `MAX(played_at)` za tog
subjekta (drugi uvoz povuče samo novo); drugi istovremeni run se odbija sa 409
umesto da udvostruči svaki brojač; run koji je ostao `running` posle pada
procesa se posle pola sata proglašava neuspelim, jer bi inače jedan pad zauvek
blokirao korisnika; `subject_is_owner` je u ruti fiksiran na `true`, pošto
odluka o tuđim arhivama (sekcija 6 plana) ne sme da stigne kroz neiskorišćen
parametar.

Deljenje streama na partije je jedino mesto gde se podaci mogu izgubiti tiho, pa
nosi najjači test: ista arhiva pušta bajt po bajt i odjednom mora da da iste
partije. **Dokazano mutacijom** — kad se rep pusti odmah, pada pet testova.
Testovi: 556 → **569**, svi zeleni. Uživo još nije viđeno:
[TODO-provera.md](TODO-provera.md), stavka 52.

**Otpremanje fajla je glavni put — odluka vlasnika projekta, 30.8.2026.**
Korisnik sam skine PGN sa Lichess-a i preda ga aplikaciji
(`POST /games/import/file`, multipart, do 25 MB, čita se kao stream i briše kad
run završi). Time nestaje cela klasa rizika koju povlačenje sa servera nosi —
server ima jednu adresu za sve korisnike, pa je 429 koji zaradi jedan uvoz kvar
za sve — i radi za Chess.com, ChessBase ili turnirski PGN bez integracije po
izvoru. Cena je osvežavanje u jednom dodiru: ručni fajl nema `since`, pa drugi
upload ponovo pročita celu arhivu i sve padne kao duplikati. To je rasipno, ne
pogrešno, i jeftinije od druge greške.

Povlačenje sa Lichess-a i dalje postoji i i dalje je testirano; **da li ostaje,
otvoreno je** — to je jedini deo ovoga koji troši dozvolu zajedničku za svu decu
u aplikaciji.

Mereno na stvarnom fajlu od 8,7 MB, kroz stream: 4126 partija, 4126 redova,
nijedna preskočena, brojevi se slažu, **40 s i 209 MB RSS u vrhu**. Na dropletu
od 960 MB memorija je važnija od vremena, i zato upload ide na disk pa se čita
nazad umesto da stoji kao jedan string. Testovi: **570**.

## Izveštaj o otvaranjima — sekcija 1, napisana 30.8.2026

`opening_nodes` u `db.js`, `services/openingLeaks.js` i
`GET /games/openings/leaks`. Jedan red po ranoj odluci subjekta — pozicija pred
njim i potez koji je izabrao — upisuje ga uvoznik u istom prolazu u kom ionako
računa `min_men`, pa ne košta ništa dodatno.

Ključ je `fen_key`, **isti onaj koji koriste `repertoire_moves`**: transpozicije
su veći deo poente, a isti ključ znači da je diff repertoara (sekcija 4)
spajanje tabela a ne drugi dogovor koji neko mora da održava. Test tvrdi da se
dva `fenKey`-a slažu, jer dva zapisa istog ključa ne bi pukla — dali bi **prazan
diff**, što se čita kao „nikad nisi izašao iz repertoara".

Prozor drži skladište: dublje od 20. poluteza se ništa ne upisuje, a traženje
dubljeg izveštaja je `RangeError`, ne tiho uži odgovor. Partije kojima čvorovi
nisu upisani se broje i vraćaju kao `gamesWithoutNodes` — prazan izveštaj inače
izgleda isto kao igrač bez slabosti. `POST /games/openings/backfill` ih dopuni
ponovnim odigravanjem UCI poteza koji već stoje u redu.

**Mereno na stvarnoj arhivi od 4126 partija, kroz produkcioni kod:** 18934
različite pozicije u prozoru, 298 dostignutih bar 8 puta, **78 označenih** ispod
42%. Najjači nalaz je tačno oblik koji je plan predvideo — crnim, jedna pozicija
dostignuta 121 put, prolaznost 41,3%, i isti potez odigran 92 puta. Još dva: 53
partije na 38,7% sa istim potezom 52 puta, i 48 partija na 39,6% sa istim
potezom 47 puta.

Ta brojka zatvara i pitanje dozvole. Suđenje je opciono (`&judge=true` uz
korisnikov `X-Lichess-Token`, koji ruta sudije ionako zahteva) i sudi glavni
potez u prvih N pozicija: **deset zahteva za izveštaj od deset, 78 da se osudi
svaki nalaz** — oko dvanaest sekundi kroz postojeći pacer. Šaka zahteva, ne
skeniranje, pa lični tokeni po korisniku nisu potrebni da bi ovo bilo isplativo.
Token koji nedostaje ili je odbijen **ne obara izveštaj**: brojevi su izračunati
pre nego što se bilo šta pita Lichess, a svaki čvor pojedinačno pada na
`unknown`.

Testovi: 570 → **584**. Uživo nije viđeno: [TODO-provera.md](TODO-provera.md),
stavka 53.

## Provera završnica preko tablica — sekcija 2, napisana 30.8.2026

`tablebase_cache` i `endgame_audits` u `db.js`, `services/endgameAudit.js`, tri
rute pod `/games/endgame`. Nalazi se upisuju u `mistake_reviews` sa
`kind = 'tablebase'` — tabelu napravljenu za njih još u sekciji 0, čiji check
uslov odbija red kojem fali bilo koja od dve presude.

**Jedan upit po poziciji, ne dva.** Odgovor tablice nosi kategoriju za svaki
legalan potez, pa pozicija *pre* poteza već kaže koliko vredi svaki potez
uključujući odigrani. Pozicija posle se nikad ne pita. Ono što treba pogoditi su
dve perspektive: kategorija pozicije pripada strani koja je na potezu, dakle
igraču, a kategorija svakog poteza pripada onome ko igra sledeći, dakle
protivniku — pa je igračev ishod posle sopstvenog poteza negacija te kategorije.

**Mereno na stvarnoj arhivi, bez mreže:** 471 partija je ušla u tablice, a
njihova provera pita **4255 pozicija** — samo igračevi potezi, samo u dometu.
Oko **10,6 minuta** na postojećem tempu od 150 ms, ispod 22 minuta koliko je
plan procenio.

Dva merenja su ispravila projekat, i oba su upisana tamo gde je stajala pogrešna
tvrdnja:

- **Pozicije završnica se ne ponavljaju unutar jedne arhive.** Sve 4255 su
  različite. Materijal se ponavlja jako — 308 potpisa, uglavnom top i pešaci —
  ali tačna pozicija ne, pa `tablebase_cache` prvom prolazu ne štedi ništa.
  Vredi za svaki sledeći: ponovna provera je besplatna, a inkrementalna posle
  dvadeset novih partija pita koliko ima u tih dvadeset. Prvobitno obrazloženje
  te tabele — da se završnice raznih igrača poklapaju — bilo je nagađanje i bilo
  je netačno.
- **Ključ od pet polja košta 83 od 4255 upita**, ispod 2%. Zadržati polupotezni
  brojač, koji razdvaja dobitak od `cursed-win`-a, praktično je besplatno.

`positions_unknown` je zaseban brojač i ne sabira se ni sa čim. Pozicija koju
tablica ne presuđuje (`unknown`, `maybe-win`, `maybe-loss`) nije pozicija koju je
igrač odigrao dobro — nju niko nije presudio, a svrstati je bilo gde pretvorilo
bi jedino obećanje ove funkcije, da je presuda ovde činjenica, u nagađanje.

Testovi: 584 → **596**. Uživo nije viđeno: [TODO-provera.md](TODO-provera.md),
stavka 54.

## Ponavljanje sopstvenih grešaka — sekcija 3, napisana 30.8.2026

`services/mistakeReviews.js` i `routes/mistakeDrill.js` na `/games/mistakes`.
Nova tabela nije trebala: provera završnica već puni `mistake_reviews`, a ovo je
polovina koja iz toga uči.

**SM-2 nije prepisan.** `schedule()` iz `spacedRepetitionService.js` je čista
funkcija nad `ease_factor`, `repetitions` i `lapses`, a ova tabela te kolone
zove isto — što je i bio ceo argument za paralelnu tabelu umesto nullable
`lesson_id`. Test oceni stavku i tvrdi da su upisane vrednosti jednake onome što
`schedule()` vrati, pa druga kopija računice ne može da se pojavi a da test
ostane zelen.

Redovi stižu sa dve strane. Provera završnica upisuje svoje, na serveru, iz
tablica. Nalazi motora stižu **sa klijenta**, kroz `POST /games/mistakes`, jer
je prolaz motorom kroz celu arhivu oko 273k pozicija i noćni posao na desktopu —
na dropletu od 960 MB tome nije mesto. Ta vrata proveravaju šta im se preda:
svaki `game_id` se ponovo proverava prema partijama samog pozivaoca, jer je
`game_id` sa klijenta broj koji je neko mogao i da pogodi.

Odgovor na paket je **tally**, ne `ok` — predato, upisano, već postojalo,
odbijeno sa imenovanim razlozima (`no-game`, `no-ply`, `no-position`, `no-move`,
`no-swing`, `game-not-yours`) — i puca ako se ne slažu. Isti oblik i isti razlog
kao kod uvoznika.

`GET /games/mistakes/recurrence` je rangiranje zbog kojeg drill uopšte vredi:
jedan propušten viljušak je loše veče, isti motiv propušten četrdeset puta je
slabost. Greške motora se grupišu po taktičkom motivu, a one iz tablica po
**potpisu materijala** — jer je merenje iz sekcije 2 pokazalo da se tačne
pozicije završnica nikad ne ponavljaju, a materijal se ponavlja stalno.

Dva baga koja su testovi uhvatili, oba tiha: `Number(null)` je 0, pa je nalaz
bez swinga prolazio `Number.isFinite` proveru i bio bi upisan kao greška koja
nije koštala ništa; i indeks odbijenice izvučen preko `indexOf` imenuje prvi od
dva identična nalaza dvaput.

Testovi: 596 → **610**. Uživo nije viđeno: [TODO-provera.md](TODO-provera.md),
stavka 55.

## Repertoar: gde sam u stablu — izvedena granica, 31.8.2026

Vlasnik je prijavio da je gradnja repertoara zbunjujuća: ne zna gde je u stablu,
dokle je stigao, nema pregled. Nije bila stvar ukusa — ekran to nije ni mogao da
kaže.

**Red je držao gole FEN-ove.** Putanja do pozicije nigde nije postojala, pa je
jedina orijentacija bila „Još N u redu", dužina liste koja se ne vidi. Red sada
nosi i putanju (`_Pending`), a zaglavlje ispisuje liniju numerisanu kao u
knjizi: `1.e4 c5 2.d4 cxd4 3.c3 dxc3 4.Nxc3`.

**Red je živeo u memoriji ekrana.** Zatvaranje ekrana ga je bacalo; povratak je
kretao od korena i **ponovo trošio Lichess kvotu** na odgovore koji su već
plaćeni. Nov `services/repertoireFrontier.js` ga **izvodi** iz dve tabele koje
već postoje — `repertoire_moves` (šta je učenik odlučio) i `opening_replies`
(šta protivnik igra, upisano kad je pozicija prvi put otvorena). Nijedan zahtev
ka Lichessu; isto na svakom uređaju. Red nikad nije bio činjenica vredna
čuvanja, nego posledica.

Dve vrste otvorenih pozicija izlaze iz šetnje, i obe su pitanje koje ekran već
ume da postavi: `undecided` (ništa nije izabrano) i `unopened` (izabrano je, ali
odgovori nikad nisu uzeti, pa linija staje).

**Redosled je `reach`, a ne širina ni dubina.** `reach` je proizvod protivnikovih
udela duž putanje — koliko često partija zaista stigne dovde. Glavna linija na
osmom polupotezu (0.5 × 0.6 = 0.30) pretiče treću po redu stranputicu na drugom
(0.20), i pretiče je sve dok joj sopstvena verovatnoća ne padne dovoljno. To je
ono što je vlasnik tražio kao „prvo u dubinu, pa se postepeno širi", samo
izračunato umesto pogođeno. Sopstveni potezi ne dele `reach`: koji od svojih
poteza igra je odluka, ne novčić.

**`repertoires.root_path`** (novo, `ALTER ... ADD COLUMN IF NOT EXISTS`) pamti
poteze kojima se stiglo do korena. Bez njega putanja počinje u vazduhu:
repertoar građen od četvrtog poteza čita se kao da je partija tu i počela. Prazan
je za svaki repertoar napravljen ranije i za onaj iz zalepljene pozicije — tada
se numeracija čita iz samog FEN-a (`4...Nc6 5.Nf3`), što je istina umesto
izmišljene otvaranja.

Šetnja ima tavanice (`MAX_NODES` 4000, `MAX_PLY` 60) i **kaže** kad ih dodirne
(`truncated`), umesto da tiho vrati kraći odgovor. Knjiga se pita jednom po
talasu, ne jednom po grani.

### Strelice sa statistikom — 31.8.2026

Dva sloja, nikad oba odjednom. Tri skupa strelica koji odgovaraju na tri
različita pitanja nisu bogatiji, nego nečitljivi — a značke bi bile procenti
različitih stvari jedan pored drugog.

- **Dok sam ja na potezu**: potezi koje sam već izabrao. Glavni nosi zvezdicu i
  najdeblju liniju; `rank` u `EngineArrow` već nosi debljinu **i** boju, pa je
  zvezdica treći kanal. Koji je potez glavni ne sme da počiva na nijansi.
  Procenat dolazi iz knjige **ako je već otvorena** — strelica ne vredi
  Lichess zahteva koji niko nije tražio.
- **Posle mog izbora**: protivnikovi odgovori, sa table pomerene za moj potez.

Broj uz strelicu je **udeo**, ne rezultat. Udeo odlučuje da li potez mora da se
sprema; „kako su te partije prošle" na strelici poziva da se bira najveći broj,
što je pogrešna pouka, i ostaje u panelu ispod gde ima mesta da se objasni.

`Dalje` je sada **stanica, ne korak**. Odgovori su se dovlačili, brojali i
bacali — ekran je trošio zahtev na njih i nikad ih nije pokazao onome ko ih je
platio, iako oni odlučuju kako izgleda ceo sledeći talas. Sada se vide, pa se
ide na `Sledeća pozicija`. Tabla je u tom stanju zaključana: pokazuje poziciju u
kojoj je protivnik na potezu, a potez povučen tu bi bio ocenjen kao učenikov.

**Šta ovim nije urađeno** — ništa više. Svih pet stavki sa te liste je
urađeno 31.8.2026: redosled unutar sesije i orezivanje grane u odeljku ispod,
a preostale tri (blok iz jednog čvora, „vrlo poznat" čvor, ponavljanje linije od
početka) u odeljku „Repertoar: vežba je linija". Jedna sa te liste je i pre
toga **već bila tu**: potez koji nije glavni, a jeste učenikov, već se ocenjuje
kao tačan (`QUALITY.alternate = GRADES.good`).

## Repertoar: red po dometu i odsecanje grane — 31.8.2026

Dve poluge sa iste liste, obe nad ekranom za izgradnju.

**Red sada ima jedan redosled, a ne dva.** Novi čvorovi su se dodavali na kraj
liste, pa je glavna linija otvorena na sredini sesije čekala iza svake
stranputice upisane pre nje — a ista šetnja, nastavljena sutradan, vraćala se
poređana po `reach`, jer server tako računa. Dva redosleda za jednu šetnju su
gori deo toga: uči se oblik sesije umesto oblika stabla. `_Pending` sada nosi
`reach`, a `_enqueue` ubacuje na mesto koje mu taj broj daje — isti račun kao na
serveru, uključujući i to da sopstveni potez **ne** deli domet.

**„Ne spremam ovo" je jedina poluga koja stablo smanjuje.** Sve ostale ga
uvećavaju: svaki talas odgovora umnoži red, a repertoar koji odgovara na svaku
stranputicu je repertoar koji niko ne završi. Bez mesta gde se to zapiše, jedini
način da se kaže bio je zatvoriti ekran — što isto to kaže za jednu sesiju i
zaboravi, pa je ista mrtva linija tu sutra, na svakom uređaju.

Nova tabela `repertoire_skips` (korisnik, boja, `fen_key`) i dve rute pod
`/repertoire/node/skip`. Ključ je pozicija, ne linija, kao i kod poteza:
odsečena grana ostaje odsečena kako god se partija u nju transponuje.

Tri odluke oko toga:

- **Sa granom izlazi i sve ispod nje.** Odsecanje koje ostavi pozicije ispod
  ostavlja stablo tačno onoliko veliko koliko je bilo — tako se korisnik nauči
  da dugme ne pritiska. Na serveru se to dešava samo od sebe (šetnja tu staje), a
  ekran isto to radi nad redom koji već drži: pozicija je ispod ove tačno kad
  njena linija počinje ovom.
- **Odsečeno se broji odvojeno i nikad se ne oduzima od „bez odgovora".**
  Odsecanje obara `openReach` a da nijedno pitanje nije odgovoreno, pa
  `prunedReach` stoji pored njega i kaže da se te partije i dalje igraju. U
  zaglavlju: `odsečeno 1 (60%)`.
- **Potezi u odsečenoj poziciji ostaju.** Odsecanje govori dokle se sprema, ne
  šta se zaboravlja; drill i dalje traži potez koji je tu izabran. Zato čvor koji
  je odsečen ne ulazi ni u `decided` — šetnja je stala pre njega, a zaglavlje
  čiji se brojevi preklapaju ne može da se sabere.

Vraćanje je jedan potez unazad (`Vrati odsečenu granu`), i stoji i na ekranu
„nema više pozicija", jer odsecanje je upravo ono što red ume da isprazni. Ono
što je bilo ispod ne vraća se sa granom — te pozicije se otvaraju uzimanjem
odgovora, odakle su i došle.

Koren repertoara se **ne nudi** za odsecanje: to nije orezivanje nego brisanje
repertoara iz ekrana koji ga gradi, i jedini je rez posle kojeg u stablo nema
ulaza. Ako je koren ipak odsečen sa drugog uređaja, šetnja to prijavljuje kao
odsečeno, a ne kao gotovo.

Testovi: backend 723 → **730**, aplikacija 959 → **964**. Uživo nije viđeno:
[TODO-provera.md](TODO-provera.md), stavka 64.

## Repertoar: vežba je linija, a ne fotografija — 31.8.2026

Poslednje tri stavke sa liste iz razgovora o granici, i ispalo je da su jedna
stvar. Drill je do sada spuštao učenika na golu tablu četiri poteza duboko u
nešto, bez ijednog traga kako se tu stiglo. Pitanje je bilo dobro, način dolaska
nije: repertoar se igra unapred, a pamćenje koje vredi ide **duž** linije, ne
prepoznaje sliku njenog kraja.

`services/repertoireLine.js` i `GET /repertoire/drill/line`. **Nijedna nova
tabela** — šetnja je ista ona nad `repertoire_moves` i `opening_replies` koju
granica već radi, i to doslovno ista: `step`, `keptByPosition` i
`coveredReplies` su izvezeni iz `repertoireFrontier.js` umesto da se prepišu.

- **Ponavljanje cele linije pre pitanja.** Učenik odigra svoje poteze od početka
  linije, protivnikovi odgovori mu se vrate, i tabla stigne do pozicije koja je
  na redu.
- **Kreće od mesta koje već zna napamet**, ne od prvog poteza. Prag je
  `KNOWN_REPETITIONS = 3` — isti broj koji prazan ekran već zove „znate". Dvanaest
  poluporeza ponavljanja do jednog pitanja je način da se drill prestane
  otvarati.
- **Blok iz jednog čvora** (`fromFen`): grana se vežba sama. Dugme je u ekranu za
  izgradnju, na poziciji koja je pred učenikom — deset pozicija napravljenih juče
  je ono na šta neko sedne, a sa spiska repertoara može da se traži samo ceo
  repertoar.

**Ponovljeni potezi se ne ocenjuju**, i na tome stoji ceo dizajn. Prefiks se
igra više puta dnevno usput ka onome što je ispod njega; da se ocenjuje, SM-2 bi
tim pozicijama gurao interval na osnovu ponavljanja koja niko nije morao da se
seti hladno, i raspored bi tiho postao izmišljotina. Ocenjuje se **samo** pozicija
na kraju linije, kroz isti `POST /drill/answer` kao pre.

Dva pravila koja su ispala usput:

- **Pogrešan potez u ponavljanju se imenuje, ne ocenjuje.** Potez linije ipak ode
  na tablu — nastavak iz poteza koji nije u liniji bio bi vežbanje druge linije.
- **Odgovor i dalje ne putuje sa pitanjem.** Prefiks jeste u odgovoru servera, jer
  su to potezi koji se ponavljaju, ali potez koji se traži nije nigde u JSON-u;
  test to tvrdi i **dokazan je mutacijom**.

Redosled unutar bloka nije prepisan: `nextItem` i `drillStats` su dobili
parametar `only`, pa jedno te isto pravilo („dospelo prvo, pa nikad vežbano sa
najviše promašaja") važi i za celu boju i za jednu granu.

Kad linija ne može da se sastavi, ekran pada na staro pitanje bez ponavljanja i
**to kaže** — pokvarena šetnja je stvar koja se primeti, a ne stvar sa kojom se
živi.

Testovi: backend 730 → **738**, aplikacija 964 → **971**. Uživo nije viđeno:
[TODO-provera.md](TODO-provera.md), stavka 65.

## Radar pokrivenosti — poslednji deo trenažera, 31.8.2026

Mapa repertoara umesto mesta u njemu, i poslednja stavka iz skice
(`repertoire_trainer_spec.md`, „Vizuelna Mapa Pokrivenosti"). Procena da „mu je
ceo račun već tu" se pokazala tačnom: **nijedna nova ruta i nijedan nov upit** —
`frontier()` sada uz sve ostalo vraća i `branches`, iz iste petlje kroz koju su
ti brojevi ionako prolazili.

**Grana se imenuje po protivnikovom izboru**, ne po svom. U repertoaru je svoj
prvi potez već odlučen; posao deli ono što druga strana uradi povodom njega — pa
je ključ grane par poteza (moj, njegov), a ne samo njegov: repertoar sme da drži
više prvih poteza, i tada „2...d6" znači dve različite grane. Ime linije
(„Sicilian Defense") dolazi iz `OpeningBookService`, lokalno i bez tokena.

**Tri broja, i nikad se ne sabiraju.** Koliko se grana igra, koliko je od nje
spremljeno, i koliko je odsečeno. Prvi kaže da li je grana bitna, drugi koliko je
gotova, treći je odbijen posao — traka koja bi odsečeni deo ubrojala u spremljeni
pretvorila bi „ovo neću da spremam" u napredak.

**Procenat je u odnosu na granu, ne na ceo repertoar** (`openWithin`). Ovo je
broj koji bi inače bio pogrešan: linija koja se igra u 10% partija i u kojoj
nema nijednog odgovora, merena prema celini, čita se kao 90% gotova.

Ekran ne kaže **ništa** samo bojom: svaki udeo je ispisan procentom, a svako
stanje nosi ikonicu (kvačica / peščani sat / makaze). To je pravilo ovog projekta
i uslov za prijem, ne ukras — ekran čije značenje živi u nijansi je ekran koji
deo njegovih čitalaca ne može da koristi.

Mapa je i raskrsnica: iz svake grane vode „Gradi ovde" i „Vežbaj granu", pa se
poslednja tri dela trenažera (granica, rez, linijski drill) prvi put sreću na
jednom ekranu. Ulaz je ikonica radara u spisku repertoara, **na mestu strelice
udesno** — strelica je govorila samo „ovaj red se otvara", što red i inače radi
dodirom.

Testovi: backend 738 → **742**, aplikacija 971 → **979**. Uživo nije viđeno:
[TODO-provera.md](TODO-provera.md), stavka 66.

## Prvi prolaz kroz trenažer uživo — tri nalaza, 31.8.2026

Vlasnik je prošao kroz repertoar i javio tri stvari. Prva je izgledala kao bag i
nije bila.

**„Vežbaj ovu granu" nije dalo da se vežba.** Grana je imala tačno jednu odluku,
ta pozicija je već jednom vežbana, i SM-2 ju je zakazao za sutra. Server je
korektno vratio `question: null`, a ekran je rekao samo „Ništa nije na redu" —
rečenicom pisanom za ceo repertoar, bez datuma i bez izlaza. Pročitano je, sasvim
razumno, kao „ova grana ne može da se vežba".

Tri izmene, i sve tri su o tome da ekran kaže istinu koju server već zna:

- `drillStats` vraća i **`nextDueAt`**, pa ekran piše „Sledeća se vraća sutra"
  umesto da ćuti. Zaokruživanje ide na cele dane, jer „sutra" stiže kao 23 sata i
  nešto — `inDays` bi to prijavio kao nulu, a pozicija koja dospeva sutra ne sme
  da se čita kao da dospeva danas.
- U grani se i naslov menja: „**U ovoj grani** ništa nije na redu."
- **„Vežbaj ipak"** — `ahead=1`. Uzima poziciju koja je najbliža dospeću iako
  još nije dospela; pozicija koja nikad nije vežbana i dalje ide prva, jer je
  ona jedina prava, a ne vežba.

Ono što tu polugu čini bezopasnom je drugi kraj: odgovor dat van rasporeda se
**ne upisuje** (`practice: true`). Isto pravilo koje već važi za ponavljanje
linije, i iz istog razloga — pozicija provučena pet puta u jedno veče ne sme da
se vrati tek za mesec dana zato što je nekome bilo zabavno. Ekran to i kaže, a
`intervalDays` je `null`, pa ne može ni slučajno da obeća datum koji niko nije
sačuvao.

**„Kada će mi se pojaviti druge opcije protivnika?"** — u trenutku prijave,
nikada; sada mogu, jedan po jedan, odeljak „Rep se sada može spremiti". Talas pokriva 80% odigranog, najviše četiri poteza; u toj poziciji su to
bili c3 (64%) i Nf3 (19%), a ostalih 28 poteza je rep koji nosi 16% partija.
Panel ih pošteno broji, ali nema načina da se jedan od njih **doda** u pripremu.
Sreću se samo u drillu, koji vuče i nepokrivene poteze. To je prava rupa i nije
zatvorena — vidi „Šta je ostalo" ispod.

**Stablo poteza** — urađeno, odeljak ispod.

## Stablo repertoara — postojeći crtež, nova stabla, 31.8.2026

`GET /repertoire/tree` i `RepertoireTreeScreen`. Crtež **nije nov**: to je
`VisualMoveTreeWidget` iz Analize, koji već ume da zumira, pomera, crta odozgo
naniže ili s leva na desno i da označi transpoziciju. Drugo stablo napisano ovde
bilo bi drugo mesto na kome sve to može da se pokvari, pa je jedini posao bio
pretvoriti repertoar u `AnalysisNode`.

**Jedan čvor po poluporezu**, za razliku od šetnje koja radi u celim talasima
(moj potez i odgovor na njega), jer je talas jedinica u kojoj se postavlja
pitanje, a ne u kojoj se crta. Zato se stablo gradi iz **`repertoire_moves`**, a
ne iz onoga do čega je šetnja stigla: potez koji je izabran a odgovori nikad
uzeti nema nijedno dete, i crtež građen od dosegnutih pozicija bi ga izostavio —
što je tačno pozicija u koju je vlasnik gledao.

Svaka kartica kaže i **šta je pozicija posle nje**: `?` nema odluke, `…` odluka
bez uzetih odgovora, `✂` odsečeno, a uz protivnikov potez stoji i procenat.
Zvezdica je moj glavni potez. Sve u znakovima, ništa u nijansi.

**Dubina je parametar** (`maxPly`, podrazumevano 16, u ekranu 8/16/24/40).
Repertoar zasejan iz arhive ima hiljade poteza i crtež svih nije crtež koji neko
čita; kad se dubina dodirne, odgovor to kaže.

Iz izabranog čvora vode ista dvoja vrata kao sa radara — „Gradi odavde" i
„Vežbaj ovu granu" — i to samo kad je učenik na potezu, jer oba ekrana pitaju
„šta vi igrate ovde". Ulaz je ikonica stabla u zaglavlju radara.

Testovi: backend 742 → **751**, aplikacija 979 → **989**. Uživo nije viđeno:
[TODO-provera.md](TODO-provera.md), stavka 67.

### Šta je ostalo posle ovog prolaza

- ~~**Rep protivnikovih poteza se ne može spremiti.**~~ — urađeno istog dana,
  odeljak „Rep se sada može spremiti".
- **`minRating` niko ne postavlja.** Provučen je kroz sve ekrane repertoara i
  uvek je `null`, pa svako dete vidi poteze svih rejtinga. Odluka iz plana
  („rang se bira prema učeniku") još nema polje.
- **Odsečena grana se posle sesije ne može naći.** Server vraća ceo spisak,
  aplikacija koristi samo njegovu dužinu; „Vrati odsečenu granu" je jedan korak
  i živi koliko i ekran.

## Rep se sada može spremiti — 31.8.2026

Talas pokriva 80% odigranog, najviše četiri poteza, i **imenuje ostatak**. To je
dobra podrazumevana vrednost i loš zid: vlasnik ga je sreo na prvoj liniji — dva
odgovora spremljena, dvadeset osam preostalih koji nose šestinu partija, i
nijedan način da se kaže „i taj". Rep je bio prebrojan i nedostupan.

`repertoire_extra_replies` (nova tabela) i `POST/DELETE /repertoire/node/reply`.
U panelu „Odgovori protivnika" ispod rečenice o repu stoji „Spremi i neki od
njih"; otvara spisak nepokrivenih poteza sa dugmetom uz svaki.

**Po učeniku, ne preko `covered`.** Kolona `opening_replies.covered` je
zajednička — ti redovi su o poziciji i rangu, nikad o osobi — pa bi njeno
prebacivanje za jedno dete tiho prepisalo šetnju koju prate sva ostala. Nova
tabela je ogledalo `repertoire_skips`: jedna kaže „ovu granu neću", druga „i ovaj
potez hoću".

**Šetnja to mora da prati.** `coveredReplies` sada uzima pokrivene poteze **plus
one koje je ovaj učenik imenovao**. Bez toga bi pozicija bila postavljena jednom
i nestala čim se ekran zatvori, jer red nije sačuvan nego izveden — što je cela
poenta granice. Pravilo da se rep inače ne prati ostaje: praćenje celog repa bi
red napunilo potezima koje niko nije stavio u njega.

**Ulazi u red po dometu, kao i sve ostalo.** Biranje govori da potez mora da se
spremi, ne da je odjednom čest: potez koji se igra u jednoj partiji od dvadeset
čeka iza onih koje se igraju.

Spisak je sklopljen dok se ne zatraži — deset poteza po jedan procenat ispod
svake pozicije zatrpalo bi odgovore koji odlučuju kako izgleda sledeći talas — i
crta se iz onoga što je knjiga već vratila, bez ijednog novog zahteva.

Jedan nalaz iz testova, o testovima: lažna knjiga je vraćala **iste** poteze bez
obzira ko je na potezu, pa je red repa nudio crni potez u poziciji u kojoj je
beli na potezu. Ništa nije puklo — potez je bio nelegalan, `_fenAfter` je vratio
null i pozicija tiho nije ušla u red. Lažnjak sada zna čija je knjiga, jer ekran
te poteze zaista igra na toj tabli.

Testovi: backend 751 → **758**, aplikacija 989 → **992**. Uživo nije viđeno:
[TODO-provera.md](TODO-provera.md), stavka 68.

## Gde se staje 31.8.2026 uveče — repertoar

**Svih šest koraka iz [PLAN-REPERTOAR.md](PLAN-REPERTOAR.md) je gotovo**:
raspored sa stablom uz tablu, `source` i potvrda, auto-kičma, orezivanje po
dohvatljivosti, odgovori protivnika uz tablu, i ocena motora na čvoru. Plan
nema više otvorenih koraka.

Ništa od toga **nije viđeno uživo**. Stavke su 70–75 u
[TODO-provera.md](TODO-provera.md), i vrede više od bilo kog novog posla: šest
izmena nad istim ekranom, nijedna nije pokrenuta.

Backend treba pokrenuti jednom zbog `ALTER TABLE repertoire_moves ADD COLUMN
source` i zbog nove tabele `repertoire_notes`.

## Kapija repertoara: dva otvaranja iz iste pozicije — 2.9.2026

Vlasnik gradi belim iz italijanke posle 3...Bc5. Tu se igra i 4.b4 (Evans) i
4.0-0, i to su dva različita repertoara — ali potezi pripadaju paru
(korisnik, boja), pa je drugi repertoar u stablu prikazivao ceo prvi.

**Nije se delio store, nego pogled.** Potezi ostaju u jednom grafu i to je
namerno: pozicija do koje se stiže na dva načina je *jedna* pozicija sa jednim
odgovorom, jer šah ne pita kroz koja ste vrata ušli. Ono što je falilo je bilo
ime za to kroz šta jedan repertoar ide.

**`repertoires.via_uci`** — kapija. Jedan potez iz korena. Filtriranje je jedna
funkcija, `gateMoves`, primenjena na mapu `kept` **pre** nego što se napravi
ijedan korak — a tu mapu čitaju i šetnja (`walkLines`, `frontier`) i crtanje
(`tree` crta iz `kept`, ne iz onoga do čega je šetnja stigla, da bi potez koji je
odlučen a nije otvoren i dalje imao karticu). Zato jedan filter pokriva stablo,
red za odlučivanje, radar pokrivenosti, spisak grana, vežbanje i listu
neslaganja.

Kapija koja nije među zadržanim potezima ostavlja poziciju **praznom**, a ne
nefiltriranom: to se na ekranu čita kao „ovde još nije odlučeno", što je tačno za
repertoar čiji prvi potez nije zadržan.

**Gde se bira.** Na ekranu za novi repertoar, ali samo ako u toj poziciji već
ima poteza — pozicija koju niko nije dodirnuo ne treba kapiju i ne pita se za
nju. Ponuđeni su prvo potezi koji se već igraju (označeni), pa **svi ostali
legalni**, jer novi repertoar često ide kroz potez koji još nije odigran — to je
tačno slučaj koji je i naterao ovu izmenu. Postojećim repertoarima kapija se
postavlja iz menija na kartici („Kroz koji potez ide"), i to je važnije od
prvog: repertoari kojima kapija najviše treba su oni koji su već napravljeni.

**Ekran za izgradnju to kaže**: „Ovaj repertoar ide kroz 0-0 — ostalo iz ove
pozicije se ne prikazuje." Filtriran pogled koji ne kaže da je filtriran je način
da neko zaključi kako mu je rad obrisan.

**Brisanje sada ume da razlikuje ta dva.** `reachable` prima i `{fen, viaUci}`,
pa se oduzimanje kod „obriši i poteze" računa kroz kapije: brisanje jednog od dva
repertoara iz istog korena odnosi samo njegovu granu. Kapije se **spajaju** kad
više polazišta deli poziciju, a jedno polazište bez kapije otvara je celu —
inače bi se linija proglasila nedohvatljivom zato što je neki drugi repertoar ne
igra.

Jedan ostatak: kad šetnja uopšte ne uspe (server je pao), dril pada na
`/drill/next`, koji je i dalje po boji. To je putanja koja se javlja rečenicom
„Linija nije mogla da se sastavi", pa se ne ćuti — ali nije filtrirana.

### Usput nađeno: „Vežbaj 0-0" nije radilo

Dok se gledalo kako se dril sužava, ispalo je da su `viaFen`, `viaUci` i
`exclude` u `routes/repertoire.js` upisani u **pogrešan handler**: stajali su u
`/disagreements`, koji ih nikad nije ni pročitao iz zahteva, a `/drill/line`, koji
ih čita, nije ih prosleđivao dalje. Posledice, obe bez ijedne poruke:

- „Vežbaj 0-0" je menjalo rečenicu iznad table i ništa više — pitanje je i dalje
  dolazilo kroz onaj potez koji raspored preferira;
- „Druga linija" je vraćala istu liniju, jer je red determinističan
  (`ORDER BY due_at LIMIT 1`), a preskakanje ne upisuje ništa;
- `/disagreements` je padao na **svaki** poziv, jer je golo `exclude` referenca
  na nepostojeće ime. `typeof viaFen` na nedeklarisanom imenu je legalan i vraća
  „undefined", pa su dva od tri otkaza bila potpuno tiha.

Ovo je tačno ona greška koja se u ovom projektu ponavlja — korak koji se preskoči,
javi uspeh i pukne jedan sloj dalje — pa je dobila test koji čita **ožičenje**:
`test/repertoire_route_wiring.test.js` traži (1) parametar koji je pročitan iz
zahteva a nigde ne prosleđen i (2) ime koje handler koristi a nije uzeo iz
zahteva. Telo handlera se čita **poklapanjem zagrada**, komentari se skidaju pre
provere, a oba testa su dokazana mutacijom.

Backend treba pokrenuti jednom, zbog `ALTER TABLE repertoires ADD COLUMN
via_uci`.

Uživo nije viđeno: [TODO-provera.md](TODO-provera.md), stavka 85.

## Brisanje poteza iz baze i sopstveni komentari — 2.9.2026

Vlasnik je obrisao sve repertoare, otišao na „Novi" da ponovo izgradi ono što je
imao — i u stablu zatekao poteze koje je ranije prihvatio. To nije bila greška
nego posledica oblika: `repertoire_moves` je ključevan `(user, boja, fen_key)`,
a `repertoires` je **ime za početnu poziciju**, ne kutija koja drži poteze.
Zbog toga transpozicije ne koštaju ništa i zbog toga drugi repertoar iste boje
odmah zna šta se tu igra.

Rupa nije bila to što potezi preživljavaju brisanje. Rupa je bila što posle
brisanja **poslednjeg** repertoara boje do njih nema nikakvih vrata:
`repertoirePrune.rootsOf` odbija da radi bez korena — i to je ispravno, jer
„nema korena" nikada ne sme da se pročita kao „ništa nije dohvatljivo" i pomete
sve — pa ni `/node/orphans` ni `/prune` tada ne odgovaraju. Novi
`services/repertoireErase.js` su ta vrata, i ima ih dvoje:

- **Brisanje jednog repertoara, sa potezima.** Ide ono što *samo on* dohvata:
  dohvatljivo iz njegovog korena minus dohvatljivo iz svih ostalih korena te
  boje. Pozicija koju drži još neki repertoar ostaje, jer se i dalje igra.
  Broj se pokazuje **pre** pitanja (`GET /repertoire/removal`), i posebno se
  imenuje koliko je od toga „sami ste izabrali".
- **Pražnjenje boje.** Sve što je sačuvano za tu stranu, prebrojano prvo
  (`GET /repertoire/color`, `DELETE /repertoire/color`). Ovo je jedina vrata
  koja se otvaraju i kad nijednog repertoara nema — zato stoje u gornjoj traci
  spiska, a ne na kartici: stanje zbog kog postoje je ono u kom kartica nema.
  Sami repertoari ostaju; pražnjenje poteza je počinjanje otvaranja iznova, a ne
  odricanje od njega.

Uz poteze idu i odsečene grane, dodati odgovori, pokušaji, raspored za vežbanje
i ocene motora za te pozicije. Razlog je jedan: rez ili raspored koji ostane iza
obrisanih poteza **ponovo se primeni** na liniju izgrađenu kasnije — odluka iz
repertoara koji više ne postoji, koja stigne nedeljama posle.

Prazan spisak sada i sam kaže gde su potezi otišli, jer je to mesto na kom
čovek bude iznenađen.

### Komentar uz poziciju — svoja tabela, ne polje u oceni

Nova tabela `repertoire_comments (user, boja, fen_key, body)`. Nije kolona u
`repertoire_notes`, i to je odluka, ne ukus:

- ocena je ono što je motor rekao — prepisuje je svaka dublja pretraga i ide sa
  potezima koje opisuje; rečenica koju je čovek otkucao ne može da se izračuna
  ponovo ni na jednoj dubini, ni na jednoj mašini;
- `putNote` **odbija** red bez ocene — a to je tačno onaj red koji treba
  komentaru na poziciji koja nije analizirana.

Zato komentari **ostaju** kad potezi odu, osim ako se ne zažele izričito
(kvadratić u oba dijaloga, podrazumevano ugašen). Komentar bez poteza košta
jedan red i vrati se čim se do te pozicije opet dođe — ključ je pozicija, kao i
svuda ovde, pa se ono što je zapisano duboko u jednoj liniji vidi čim druga
linija transponira u tu tablu.

Prazan tekst je brisanje. Sačuvan prazan komentar bi crtao karticu o poziciji o
kojoj niko ništa nije rekao.

### Gde se komentar vidi

Jedan widget (`RepertoireCommentPanel`), dva mesta, i to je razlog što je widget:

- **Pored table**, u trećoj koloni, od `Breakpoints.ultraWide` (1200 dp) na
  više. Širina se uzima od stabla, nikada od table — `_boardSize` se i dalje
  računa iz istih 42% — jer je manja tabla jedina stvar gora od komentara koji
  je jedan skrol daleko. Panel ima svoj skrol, da dugačak komentar ne može da
  produži red preko prozora (u release buildu to nisu pruge nego odsečen dno).
- **Ispod table**, na telefonu i u užem prozoru, gde prazan komentar crta
  **ništa**. Kolona ispod table na 360 dp je najskuplji prostor u aplikaciji.

Na 840 dp (dve kolone) komentar i dalje ide ispod table: treća kolona izvučena na
toj širini ostavlja sliku preusku da se čita.

### Dva dugmeta u traci ispod table

Tamo gde ih Tabla za analizu već ima, jer onaj ko je naučio jedan ekran ne treba
da ih traži na sledećem. `MoveNavigationControls` je `Wrap`, pa se na telefonu
prelome u drugi red umesto da budu isečena bez upozorenja u release buildu.
Traka se sada crta i kad je linija prekratka za šetnju — ranije bi nestala cela,
a sa njom i jedini način da se napiše komentar na prvoj poziciji.

**„Pitaj AI o poziciji"** zove `POST /api/ai/explain-position` — rutu koja
postoji od AI trenera, sa svojom kvotom (`ai_comments`) i limiterom, i
`PuzzleApiService.explainPosition`, koji je bio **napisan i nigde pozvan**. Nije
drugi sudija: sud o potezu ostaje otvaranjska baza (šta su ljudi stvarno igrali),
a ovo je proza o poziciji, ponuđena da se pročita i — ako vredi — prepiše u
sopstveni komentar, kroz editor, pa tek onda sačuva. Ono što je model napisao
nije ničiji komentar dok čovek ne kaže da jeste.

Backend treba pokrenuti jednom, zbog nove tabele `repertoire_comments`.

Uživo nije viđeno: [TODO-provera.md](TODO-provera.md), stavka 84.

## Dril šeta sam, i kaže kroz koju odluku — 1.9.2026

Vlasnik je uživo naleteo na dve stvari koje su, kad se pogledalo u kod, ispale
tri odvojene greške i jedno neslaganje sa dogovorom.

**Šetnja linijom nije govorila kroz koju odluku ide.** `walkLines` širi *svaki*
zadržani potez u poziciji — i glavni i alternativu — pa linija do dospele
pozicije sme da ide kroz alternativu. Prefiks o tome nije nosio ništa. Ekran je
onda pitao „odigrajte potez koji ste izabrali" u poziciji u kojoj su **dva**
poteza vlasnikova, a samo jedan nastavlja tu liniju; drugi je vraćen narandžastom
rečenicom „U ovoj liniji ide Nc3", istom kojom se javlja i promašaj. To uči
učenika da ne veruje potezu koji je sam izabrao, a ništa u repertoaru ne vredi
toliko.

Sad `walkLines` nosi `role` i `alts` uz svaki moj potez u liniji, a šetnja ima
**tri ishoda umesto dva**: potez linije, *drugi moj potez* („I d4 je vaš potez —
ali ova linija vežba Nc3", plavo, ne narandžasto), i promašaj. Pre poteza, kad
linija ide kroz alternativu, stoji rečenica da ide kroz alternativu — **bez
imena poteza**, jer imenovanje bi šetnju pretvorilo u film baš na pozicijama
zbog kojih se šeta. Ćutanje na račvanju znači „glavni", i to je pošteno: koji je
potez, ostaje na učeniku.

**Ispravka se nije videla.** Potez linije i protivnikov odgovor sletali su u
jednom `loadFen`-u, pa se figura pojavljivala na polju na koje ništa nije viđeno
da ide — vlasnik je posle svog d4 dobio crnog skakača na c3 i nigde potez Nc3.
Sada idu u dva takta: potez linije prvo, sam, sa strelicom na sebi, pa posle
550 ms protivnikov odgovor.

**„Nastavi liniju" je bilo ručno ono što sparing radi sam.** Dogovor je bio
šetnja linijom do kraja, a red je posle svakog odgovora stajao i tražio klik.
Sada tačan odgovor vodi dalje sam, posle 1400 ms — duže od sparingovih 700, jer
ovde panel kaže i **kada se pozicija vraća**, a rečenica koju niko ne stigne da
pročita je rečenica koju dril više ne govori. Zato presuda ide **sa** šetnjom:
iznad sledećeg pitanja stoji „Tačno — Nc6 · protivnik Nf3 · vraća se za 6 dana".

Dugme je ostalo za ono što šetnju **zaustavlja**: grešku i nepokriveni
protivnikov odgovor. Iznenađenje je jedina stvar koju knjiga ne ume i vrata
nazad ka izgradnji — proletanje kroz tu rečenicu u poziciju bez odgovora bilo bi
najgore mesto za žurbu.

**Dve greške uz put.** Dugme se nudilo i kad protivnik nije odgovorio: pozicija
posle sopstvenog poteza je protivnikova da je odigra, pa je „Nastavi liniju"
tamo vodilo u pitanje „šta igrate" u poziciji u kojoj nisi na potezu. I šetnja
je upisivala raspored pozicija koje niko nije tražio — pravilo „ocenjuje se samo
ono što je bilo dospelo" držao je sparing preko `dueKeys`, a red nije držao
niko. Sada odgovor ide sa `onlyIfDue`, a odluku donosi server, jer je `due_at`
njegov. Pozicija koja nikad nije ponavljana i dalje **jeste** dospela.

Testovi: backend 779 → **784**, aplikacija 1032 → **1040**. Uživo nije viđeno:
stavka 81 u [TODO-provera.md](TODO-provera.md).

## Protivnik ostaje unutar pripremljenog — 1.9.2026

Vlasnik je tražio da dril ide **samo kroz pozicije pokrivene protivnikovim
odgovorima**, da ne dobija „Protivnik je odgovorio Nf6 — to niste pokrili".
`pickReply` je do sada vukao iz **celog repa** `opening_replies` — svega što je
explorer vratio i posle 80% reza — i to namerno: sretanje nepokrivenog poteza
pokazivalo je učeniku ivicu onoga što je spremio i vodilo nazad u izgradnju.

To je uklonjeno, i dva razloga govore isto:

**Šetnja linijom to nikad nije radila.** `coveredReplies` prati samo pokrivene
odgovore plus one koje je učenik imenovao, pa je *živi* protivnik igrao poteze
koje ponavljanje iste te linije ne bi odigralo. Dva različita protivnika u
jednom drilu, i ponavljanje je bilo ono koje je u pravu.

**Vrata ka izgradnji nisu bila u tome.** Ostaje `unprepared` — pozicija koju
jesi pokrio a nisi odlučio šta u njoj igraš — sa ponudom „Izgradi ovu poziciju".
To je rupa u repertoaru, a ne rupa u knjizi, i to je poštenija polovina onoga
čemu je iznenađenje služilo.

Pozicija u kojoj ništa nije pripremljeno sada odgovara **ničim**: linija se
završava tamo gde se završava priprema, što je ono kako izgleda knjiga koja je
istekla. „Nastavi liniju" se tu ne nudi, a sparing to već zove „Grana odigrana
do kraja".

„Pripremljeno" i ovde znači isto što i svuda: pokriveno **ili** potez na koji je
učenik pritisnuo „spremi i ovo" — pa `pickReply` sada mora da zna **ko** pita
(`repertoire_extra_replies` je po učeniku). Uslov se računa u SQL-u a filtrira u
JS-u namerno: tako je izvlačenje provereno nad redovima, a ne nad tekstom upita.

`replyCovered` i rečenica koju ekran gradi iz njega **ostaju**. Server to više ne
šalje, ali su ispravno čitanje zastavice koju i dalje šalje — ako se izvlačenje
ikad ponovo proširi, ekran to kaže bez ijedne izmene unazad.

Testovi: backend 788 → **791**. Uživo nije viđeno: stavka 83 u
[TODO-provera.md](TODO-provera.md).

## Izbor račve je radio i nije se video — 1.9.2026

Vlasnik je javio da izbor ne radi: klikne „Vežbaj d4" i i dalje dobija
alternativnu liniju. **Nije bilo tako.** Server je narušavao ispravno — dokazano
probom nad račvom četiri poteza duboko, jer je jedini postojeći test imao račvu
u **korenu**, gde je `moves[at * 2]` trivijalno `moves[0]` i aritmetika indeksa
se ne proverava. Kad se napravi ista provera dublje, `nodesVia` vraća tačno
poziciju iza `d4`.

Greška je bila u tome što se to **ne vidi**. Iznad račve obe linije čitaju
identično — ista tabla, isti trag poteza, isti brojač „potez 1 od 1" — jer se
linija razilazi tek **sledećim** potezom. Učenik je tražio d4, dobio d4, video
poziciju koju je i pre gledao i rečenicu „Odigrajte potez koji ste izabrali", pa
je zaključio da se ništa nije desilo. Funkcija koja radi a ne može da se vidi
kako radi nije isporučena.

Sada, kad je put izabran, ponavljanje na toj račvi **imenuje potez**: „Ova linija
ide kroz d4 — odigrajte ga." Ništa se ne odaje — učenik ga je maločas izabrao po
imenu — a rečenica o alternativi se tu gasi, jer „jedan od vaših poteza" ispod
„odigrajte d4" kaže manje od ničega.

**Druga polovina: put koji nema šta da ponudi.** Prazan ekran se crta *umesto*
panela koji nosi red „Vežbate liniju kroz d4." i izlaz sa njega, pa je učenik
ostajao na putu koji ne vidi i sa kog ne može da siđe, ispod rečenice „Ništa nije
na redu" — koja je tvrdnja o repertoaru, a bila je činjenica o jednom potezu. Sad
piše „Iza poteza d4 ništa nije na redu." i tu stoji „Nazad na red".

Pouka za dalje, jer se ponavlja: **test koji potvrđuje ponašanje na indeksu 0 ne
potvrđuje aritmetiku indeksa.** Račva u korenu je prošla i kad je duboka bila u
pitanju.

Testovi: aplikacija 1044 → **1046**. Uživo nije viđeno: stavka 82 u
[TODO-provera.md](TODO-provera.md), tačke 12–14.

## Račva se bira, i preskakanje zaista preskače — 1.9.2026

Nastavak istog razgovora. Vlasnik je pitao šta znače „Preskoči ponavljanje" i
„Druga linija", i kako da pređe na glavni potez i liniju iza njega. Prvo je
objašnjenje, drugo je bila rupa, a usput je ispalo da jedno od ta dva dugmeta ne
radi ono što piše na njemu.

**„Druga linija" nije davala drugu liniju.** `nextItem` je deterministički
`ORDER BY due_at ASC LIMIT 1`, a ponavljanje ne upisuje ništa — pa je isti
zahtev vraćao isto pitanje. Isto važi i za „Preskoči" nad pitanjem: preskakanje
ne ocenjuje i ne piše `repertoire_attempts`, pa se pozicija vraćala u nedogled.
Oba dugmeta su bila izlaz koji ne izlazi nigde. Sada `drillLine` prima
`exclude` — pozicije odbijene u ovoj sesiji — a kad se sve odbije, gomila se
**okrene** umesto da ekran kaže „Ništa nije na redu", što bi bila laž koju je
izgovorilo samo dugme.

**Linija kroz jednu odluku sada može da se zatraži.** `drillLine` prima
`viaFen` + `viaUci` i šeta samo kroz pozicije do kojih se stiže **tim** potezom
iz **te** pozicije. Potez se traži po tome *odakle je odigran*, ne po samom
polju: potez na indeksu `2i` u lancu je moj potez iz čvora `i`, jer šetnja
dodaje po jedan par po nivou — poklapanje samo po uci uhvatilo bi isti potez
odigran negde drugde. Sama račva **nije** u odgovoru: to je pozicija u kojoj se
bira, ne pozicija do koje izbor vodi.

Na ekranu je to dugme **„Druga odluka"**, i to samo na račvi. Otvara list sa
„Vežbaj d4" po jednom drugom potezu. **Iza pritiska, a ne na tabli** — isto
pravilo koje već važi za „Pokaži": ponavljanje se ne ocenjuje, ali imenovanje
drugog poteza tamo gde su zadržana tačno dva odaje onaj koji se traži, pa
gledanje treba da bude nešto što je učenik uradio, a ne što se desilo samo.

Izabrani put se vidi („Vežbate liniju kroz d4.") i ima izlaz („Nazad na red"),
jer režim koji se ne vidi izgleda kao greška. Ide sa `ahead: true`: traženje
puta je dovoljan razlog da se njime prošeta, a rani odgovor se ne upisuje. Grana
i sparing brišu izbor — veći izbor pobeđuje manji.

Namerno nije rađeno: **biranje grane dublje od prva dva poteza.**
`drillBranches` i dalje grupiše po paru poteza koji otvara granu, pa je
„Druga odluka" jedini način da se bira račva u dubini. To je dovoljno za ono
zbog čega je traženo, a spisak grana kao malo stablo je zaseban posao.

Testovi: backend 784 → **788**, aplikacija 1040 → **1044**. Uživo nije viđeno:
stavka 82 u [TODO-provera.md](TODO-provera.md).

## Grana kao sesija, i sparing kroz nju — 1.9.2026

Vlasnik je razložio kako bi dril mogao da radi, u četiri režima, i rekao šta bi
njemu odgovaralo: **Line-Walk / sparing sa elementima drila po granama**. Pet od
šest stvari sa tog spiska je već radilo — SM-2 po pozicijama, šetnja linijom pre
pitanja, `fromFen` za jednu granu, protivnik biran **težinski po `games`**,
alternativa priznata uz rečenicu „Glavni potez vam je X", i kontrolne tačke koje
se **računaju** (najdublja pozicija koju znaš napamet) umesto da se postavljaju
rukom. Nedostajala su dva ulaza, i oni su sad napravljeni.

**Grana je postala ulaz u dril.** `GET /repertoire/drill/branches` vraća
protivnikove prve odgovore, svaki sa `positions`, `due`, `known` i **`dueKeys`**.
Grana se ključa **parom** poteza koji je otvara — mojim i njegovim — jer
repertoar sme da drži više prvih poteza, pa „2...d6" tada imenuje dve različite
grane; isto pravilo koje radar već koristi. Šeta se samo kroz odluke
(`onlyChosen`), jer dril ne pita za poteze koje niko nije izabrao. Pozicija koja
nikad nije ponavljana **računa se kao dospela**: to je najdospelija stvar koja
postoji, a grana koju niko nije otvarao ne sme da izgleda gotovo.

Do sada je `fromFen` radio od dana kad je napisan, ali je do njega mogao samo
onaj ko dolazi sa ekrana za izgradnju ili sa radara. Sada u zaglavlju drila stoji
ikonica grane: „Ceo repertoar" ili jedna grana, sa brojem dospelih uz svaku.

**Sparing: odigraj granu do kraja.** Iz istog lista, dugme ▶ na grani. Tabla ode
na poziciju kojom grana počinje, protivnik odgovara sam (težinski, pa ista grana
dvaput ne teče isto), i ide se dok ima pripremljenog poteza.

Jedno pravilo drži ceo režim: **ocenjuju se samo pozicije koje su bile dospele**,
ostale se igraju kao vežba i ne upisuju. Grana preigrana sa svakom pozicijom
ocenjenom gurala bi raspored napred na osnovu poteza koje niko nije morao da zna
napamet — isto pravilo zbog kojeg se ni prefiks u šetnji linijom ne ocenjuje, i
razlog zbog kojeg sparing sme da se pusti dvaput iste večeri.

Greška **zaustavlja trku tamo gde se desila**: ta pozicija je ceo razlog zbog
kojeg se trka igra, i proletanje kroz nju istom brzinom kao kroz ostalo je jedini
trenutak u kome ekran ne sme da žuri. Na kraju stoji jedna rečenica: „Grana
odigrana do kraja. Odigrano 9, greške: 1."

Ostalo nenapravljeno, svesno: **dril „slepih mrlja"** (`weakNodes` i
`disagreements` postoje kao podaci, ali nisu ulaz u dril) i **biranje grane po
tome gde ima najviše dospelog** — težinski protivnik je poštena simulacija, a
skretanje ka onome što je dospelo vraća sparing u kviz.

Testovi: backend 773 → **779**, aplikacija 1026 → **1032**. Uživo nije viđeno:
stavka 80 u [TODO-provera.md](TODO-provera.md).

## Otvaranje se bira sa spiska, ne samo kucanjem — 1.9.2026

Vlasnik je pitao može li da izabere repertoar **po nazivu otvaranja i po
varijanti u njemu**. Biranje po imenu je postojalo od ranije, ali samo kao
polje za pretragu: ekran se otvarao kao prazna kutija sa lupom, što služi jedino
onome ko već zna kako se zove ono što traži. Tražena je druga polovina.

**`OpeningBookEntry` sada zna svoja dva nivoa.** ECO ime je jedan string koji
nosi oboje — „Sicilian Defense: Najdorf Variation, English Attack" — pa je
`family` ono pre dvotačke, a `variation` ostatak. Sopstvena glavna linija
otvaranja nema ništa posle dvotačke i **imenuje se** („Osnovna linija"), jer
prazan red u spisku varijanti čita se kao greška, a „samo otvaranje" je stvaran
izbor.

**Dva spiska u `OpeningPicker`-u**: `families()` daje 149 otvaranja po
abecedi, `variationsOf(ime)` linije unutar jednog — **najkraća prva**, jer
najkraća linija *jeste* otvaranje na koje se misli kad se imenuje, a abecedno bi
spisak otvorilo na onome što počinje slovom A. Kucanje i dalje radi i **seče
popreko**: ko ukuca „Najdorf" misli na Najdorf, ne na Najdorf unutar otvaranja
koje je slučajno bio otvorio.

Usput popravljeno: picker je **odmah pokazivao spisak** ako je baza već
učitana, umesto da za jedan kadar treperi „Učitavanje…". To je i ono što je
omogućilo test — `compute()` pravi izolat, a časovnik u widget testu je lažni,
pa se `.then` na taj future iz test-zone nikad ne isporuči. Isti razlog, dva
dobitka.

Dugme je preimenovano u **„Izaberi otvaranje"**, jer „Nađi" opisuje samo
pretragu.

Testovi: aplikacija 1018 → **1026**. Uživo nije viđeno: stavka 79 u
[TODO-provera.md](TODO-provera.md).

## Izbor grane je sada pravilo cele aplikacije — 1.9.2026

Traženo od vlasnika, i tačno na mestu: na račvanju „napred" ima više od jednog
značenja, a traka je uvek uzimala prvo dete — pa se do ostalih grana
navigacijom **nije moglo stići uopšte**. To nije bila mana jednog ekrana nego
mana pravila, pa je i popravka na nivou pravila.

**`MoveCursor` je dobio dva člana**: `forwardBranches` (šta vodi napred odavde)
i `takeBranch(i)`. Oba imaju telo, ne apstraktnu deklaraciju, i to je odluka:
model koji se ne grana je ispravan **bez ičega** — vrati praznu listu i nikad ne
dobije pitanje. Obrnuto bi značilo da svaki nov kursor mora da zna za račvanja
da bi se uopšte kompajlirao, a to je strana na kojoj se pravi pogrešan odgovor.

**Pitanje postavlja traka i tastatura, na jednom mestu.**
`showBranchChoice` (`widgets/game_screen/branch_choice_sheet.dart`) je jedan
list za sve; `MoveNavigationControls` ga otvara na dugmetu „napred", a
`MoveKeyboardShortcuts` na strelici desno. Njih dvoje **ne smeju da se
razilaze**: račvanje koje otvara izbor pod mišem a pod tastaturom ćutke uzima
glavnu liniju gore je nego bilo koje od ta dva ponašanja samo za sebe.

Ko je time dobio izbor grane, bez ijedne izmene na svom ekranu: **Analiza**
(`AnalysisNodeCursor`), **soba za lekciju i AI Studio** (`MoveTreeCursor`), i
**repertoar**, koji je usput prestao da nosi svoju kopiju — ekran je prešao sa
spljoštene liste (`LinearMoveCursor`) na kursor nad stablom, pa mu je pravilo
stiglo samo od sebe. Lekcije i ponavljanja koriste `LinearMoveCursor`, koji
nema grane i ostaje tačno onakav kakav je bio.

Dve stvari koje su namerno ostale: **„na kraj" ne pita** — to znači kraj *ove*
linije, a pitanje na svakom račvanju usput bi ga učinilo neupotrebljivim; i
**zatvaranje lista ne pomera tablu**, jer biti pitan i ćutati nije isto što i
izabrati glavnu liniju.

Testovi: aplikacija 1015 → **1018**. Uživo nije viđeno: stavka 78 u
[TODO-provera.md](TODO-provera.md).

## Drugi prolaz uživo: jedna lista, jedan zahtev, jedan izbor — 1.9.2026

Vlasnik je prošao kroz izmene i javio četiri stvari. Sve četiri su bile tačne i
sve su bile posledica istog: ekran je radio dvaput ono što treba jednom.

**Potez koji je već u repertoaru se više ne sudi ponovo.** Vlasnik je odigrao
svoj *drugi* potez u poziciji i ekran ga je pitao „Uzmi Re1?" — potez koji je
već bio prihvaćen. Odigrati potez koji već stoji u listi je isti čin kao
izabrati ga u stablu: idi i pogledaj šta dolazi posle njega. Sada je tako, kroz
isti `_standAfterMove` kroz koji ide i dodir na karticu.

**Druga Lichess lista je uklonjena, i sa njom jedan upit po potezu.** Posle
svakog odigranog poteza dohvatala se cela knjiga preko sudije, da bi se videlo
kako su te partije prošle. To je bio **Lichess upit po potezu**, protiv tokena
koji služi svu decu koja koriste ovu aplikaciju, i drugi panel ispod onog koji
stoji na ekranu otkad je pozicija otvorena. Ono što je nosio a sačuvana knjiga
ne nosi — kako su partije **završile** — vredi imati, ali kao kolonu u
`opening_replies` koja se dohvati jednom za sve, ne kao upit po potezu.

**Navigacija pita kojom granom.** U poziciji koja se grana „napred" ima više od
jednog značenja, a paleta je uvek uzimala prvo dete — pa se do ostalih grana
navigacijom **nije moglo stići uopšte**. Sada se otvara list sa svim
nastavcima, i tek kad izbor zaista postoji.

*Vlasnikov predlog je da to bude pravilo na nivou cele aplikacije.* Nije
urađeno i vredi zasebno: `MoveCursor` bi dobio „koje su grane napred", a
`MoveNavigationControls` i `MoveKeyboardShortcuts` bi pitali umesto da biraju.
Tri implementacije kursora i šest ekrana, pa je to svoj posao, a ne usputna
izmena.

**Desni klik sada kaže šta je uradio.** Radnje iz menija su radile i ćutale.
Sve idu kroz `AppFeedback` — „Nc3 je sada vaš glavni potez", „Nc3 je uklonjen iz
repertoara", „Grana posle Bf5 je odsečena" — jer pravilo ovog projekta je
**uradi pa reci**, i reci kroz `AppFeedback`, koji ne može da baci izuzetak.

Testovi: aplikacija 1014 → **1015**. Uživo nije viđeno: stavka 77 u
[TODO-provera.md](TODO-provera.md).

## Gradnja prestaje da bude kviz — 31.8.2026

Vlasnik je prošao kroz ekran uživo i javio šest stvari. Jedna od njih je
promenila zamisao, ne raspored: **repertoar se više ne gradi tako što korisnik
pogađa poteze, nego na osnovu statistike, ocene i svoje slobodne volje.**

**Statistika stoji uz tablu, uvek.** Panel „Šta se ovde igra" pokazuje šta se u
poziciji na tabli igra — iz sačuvane baze, dakle **bez ijednog Lichess upita** —
i svaki red ima „Igraj", koji potez pusti kroz isto suđenje i istu odluku kao
potez povučen po tabli. Poziciju koju niko nikad nije otvarao i dalje otvara
dugme sa cenom u natpisu („1 upit").

**Dugmeta „Ne znam" više nema.** Ono je postojalo da bi se **zapisalo** da je
neko gledao (`looked_up`), a taj podatak je drillu govorio koje pozicije da pita
prve. Sa listom na ekranu od početka, „rešeno gledanjem" se ne razlikuje od
„rešeno mišljenjem", pa se `lookedUp` više ne upisuje kao `true` — broj koji ne
znači ništa gori je od broja koga nema. Kolona ostaje, drill se povlači na
odbijene pokušaje, koji i dalje znače tačno ono što su značili.

Ostalih pet nalaza, sve na istom ekranu:

**Desni klik u stablu nije radio ništa.** To je bila greška, ne odluka:
`AnalysisMoveTreeWidget` zove `onPromoteNode?.call` i `onDeleteNode?.call`, a
`RepertoireTreePanel` nije prosleđivao nijedan — `?.` je gutao dodir. Meni je
ceo dan nudio dve stavke vezane ni za šta. Sada: na **mom** potezu „Unapredi"
menja glavni potez, a „Obriši" je uklanjanje sa punim čišćenjem nedohvatljivog i
pitanjem o odlukama; na **protivnikovom** potezu „Obriši" je **rez** — njegovi
potezi nisu ničiji izbor, pa nema šta da se briše, a ono što neko time misli je
„ovo ne spremam".

**Odsečene grane se više ne crtaju.** Rez zaustavlja šetnju, ali je kartica
ostajala: deset rezova je ostavljalo deset mrtvih listova koji šire crtež koji
se čita da bi se videle rupe. Sakrivene, nikad obrisane — iznad stabla stoji
„Prikaži odsečene grane (N)", jer je rez odluka i mora da ostane pronađiv.

**Navigaciona paleta ispod table.** Ista četiri dugmeta kao na još pet ekrana,
preko istog `MoveCursor`-a, i linija ide **kroz** tablu do kraja glavne linije —
paleta čija su dugmad unapred mrtva čim se ekran otvori nije navigacija. Test
`move_keys_everywhere_test.dart` je odmah pao i tražio strelice uz traku; dobile
su ih. Taj test je uradio tačno ono zbog čega je pisan.

**Kartice su numerisane od prave pozicije.** Repertoar koji počinje posle 3.e5
crtao je svoju prvu karticu kao potez jedan. Broj se sada čita iz FEN-a kartice
— jedino mesto koje zna gde je brojanje počelo — pa piše `3... c5` i `4. c3`.
Isto važi i za PGN prikaz istog panela, gde je laž bila ista.

**Ivica kartice kaže čija je strana.** Ne ispuna: ispuna i dalje govori glavna
linija/varijanta. Ivica ide na `sideWhite`/`sideBlack`, dakle **svetla ivica
prema tamnoj**, ne jedna nijansa protiv druge — razlika mora da preživi čitaoca
koji ne razdvaja nijanse. Izabrana kartica zadržava svoj akcenat i sjaj, jer
izbor mora da ostane nepogrešiv.

Testovi: aplikacija 1008 → **1014**. Uživo nije viđeno: stavka 76 u
[TODO-provera.md](TODO-provera.md).

## Dodir na svoj potez u stablu — 31.8.2026

Vlasnik je pitao ima li logike iza toga što u stablu ne može da klikne na svoje
poteze. Imala je, i bila je preuska.

Kartica nosi poziciju **posle** poteza. Posle protivnikovog poteza na potezu sam
ja, pa tabla prosto ode tamo. Posle **mog** poteza na potezu je protivnik, a to
je pozicija o kojoj ovaj ekran nema šta da pita — pa se dodir vraćao na
roditelja, poziciju iz koje je potez izabran. U liniji u kojoj stojite to je
pozicija na kojoj **već jeste**: dodir je izgledao kao kartica koja ne radi
ništa, a usput je kroz `_show` brisao linije motora i ocenu sudije.

Sada dodir na svoj potez **postavi tablu posle njega** i ispod nacrta ono što
protivnik odatle igra — iz sačuvane knjige, dakle bez ijednog Lichess upita.
To je ono što neko i misli kad dodirne svoj potez. Pitanje ostaje na poziciji iz
koje je potez odigran (`_node` se ne pomera), tačno kao u stanju posle „Dalje";
`_afterMyMove` je jedan uslov umesto dva ponovljena kroz ceo `build`, jer panel
koji zaboravi drugi je ocena ili knjiga nacrtana za tablu koja se ne vidi.

Izlaz je dugme **„Nazad na X"**. Bez njega je jedini izlaz iz dodirnutog poteza
još jedan dodir u stablu, što je ćošak a ne stanje.

I zaštita: **skok na poziciju koja je već na tabli sada ne radi ništa.**
Ponovno prikazivanje pozicije briše sve što joj je pripadalo, pa je dodir koji
sleti tamo gde tabla već stoji ranije bacao linije motora koje je čitalac upravo
sačekao. Test je dokazan mutacijom — bez te jedne linije pada.

Testovi: aplikacija 1006 → **1008**. Uživo nije viđeno: stavka 70 u
[TODO-provera.md](TODO-provera.md).

## Ocena motora na čvoru — korak 6 iz plana, 31.8.2026

`repertoire_notes`, `PUT /repertoire/note`, `GET /repertoire/notes` i
`GET /repertoire/disagreements`. Motor je i pre ovoga bio na ekranu za
izgradnju; ono što je nedostajalo je da njegov odgovor **ostane** na poziciji.

**Broj je podatak, nije presuda.** Ekran već ima sudiju — sudiju otvaranja, koji
odgovara na „da li je ovaj potez zdrav, sudeći po partijama koje su ljudi
odigrali", i to je za repertoar bolje pitanje, jer je repertoar o onome što će
se protiv vas zaista igrati. Drugo mišljenje iz drugog pojma „dobrog", odštampano
na istoj kartici, način je na koji ekran počne da protivreči sam sebi pred
detetom. Zato **nema zastavice ni na jednom potezu**; umesto nje postoji
**spisak**: „Gde se motor ne slaže", sortiran po tome koliko neslaganje košta,
kroz koji se prolazi namerno.

**Ocena je po korisniku.** Red iz knjige je činjenica o poziciji i zato se deli
(`opening_replies`); ocena je činjenica o poziciji *i* verziji motora, dubini i
mašini. Deljena tabela bi morala da ima sve troje u ključu da bi išta značila, a
ovako se ne bi slagala ni sa kim.

**Plića ocena nikad ne pregazi dublju.** Prolaz kroz celu liniju ide na dubini
koja je na točkiću; ručno pokrenuta pretraga na dubini 30 nad jednom pozicijom
ne sme da se spljošti sutrašnjim prolazom na 18. Isto pravilo koje
`AnalysisNode.evalDepth` drži u klijentu, ovde ga drži baza (`WHERE
EXCLUDED.eval_depth >= repertoire_notes.eval_depth`), a odgovor vraća **red koji
je pobedio**, ne onaj koji je poslat — ekran crta ono što je sačuvano.

**Dubina i datum se vide.** Ocena bez dubine je broj koji stari nevidljivo:
dubina 12 od pre dve nedelje i dubina 30 od pre minut izgledaju isto napisane kao
`+0.35`.

**„Evaluiraj celu liniju (N pozicija)"**, sa brojem u natpisu. Ne troši nijedan
Lichess upit — samo vreme i toplu bateriju — pa cena mora da se vidi pre nego što
se pritisne, a prolaz može da se zaustavi. Zaustavljanje se čita **između**
pozicija: pretraga koja je već krenula se dovrši i sačuva, jer bacanje odgovora
koji je plaćen ne pomaže nikome. `N` je koliko će zaista biti računato, a ne
dužina linije: pozicije koje već imaju ocenu bar te dubine se preskaču.

Prolaz ocenjuje **i protivnikove poteze**, jer je veličina neslaganja ocena pre
poteza minus ocena posle njega. Gde druge ocene nema, red je i dalje na spisku (
motor očigledno igra nešto drugo) sa `?` umesto broja — a `?` nije nula.

Dve kolone preko onoga što je plan nabrojao, i obe su odluka: `best_uci`, jer se
potezi porede po UCI-ju a ne po SAN-u koji ispisuju dve različite šahovske
biblioteke; i `mate_in`, jer forsiran mat sačuvan samo kao veliki broj pešaka
čita se kao ocena. `eval_cp` i dalje nosi mat sažet u centipešake, da sve što
sortira i oduzima ima jedan broj.

Ocene se čitaju **jednom, uz crtež** (`GET /repertoire/notes`), i sedaju na
kartice stabla — `VisualMoveTreeWidget` već crta `eval`, pa to nije nov crtež
nego broj koji stiže tamo gde je mesto za njega već postojalo.

**Jedno mesto na koje treba paziti**, zapisano jer je to oblik koji
`tablebaseService` odbija za trenera završnica: ocenu računa klijent a čuva je
server, dakle server je ne može proveriti. Ovde je to prihvatljivo iz jednog
razloga — niko ne vara sam sebe za ocenu motora, i ovaj broj ništa ne ocenjuje.
Ako ikad počne išta da ocenjuje, taj razlog pada i računanje mora da se preseli.

Testovi: backend 761 → **773**, aplikacija 995 → **1006**. Uživo nije viđeno:
[TODO-provera.md](TODO-provera.md), stavka 75.

## Protivnikovi odgovori uz tablu — korak 5 iz plana, 31.8.2026

`GET /repertoire/book` i panel „Posle X — šta igra protivnik", koji sada stoji
uz tablu umesto da se pojavljuje tek posle `Dalje`. To je jedina lista koja
odlučuje kako izgleda sledeći talas, pa nije imala šta da traži iza dugmeta.

**Ne troši nijedan upit.** Čita se iz `opening_replies`, gde stoji sve što je
ičija sesija izgradnje već platila — ti redovi su o poziciji i rangu, nikad o
osobi. To je pravilo za panel koji prati tablu: jedan token služi svu decu koja
koriste ovu aplikaciju, a lista koja bi se osvežavala na svaki klik trošila bi
njihovu kvotu na crtež koji niko nije tražio.

`opened` razlikuje dva prazna: „niko ovde nije gledao" je ponuda (dugme „Otvori
knjigu (1 upit)"), a ne tvrdnja da protivnik nema šta da igra.

Svaki red vodi negde. Odgovor koji je već u pripremi nudi **„Idi"** — tabla ode
tamo; odgovor van pripreme nudi **„Spremi"**, isti put kroz
`repertoire_extra_replies` koji je napravljen za rep.

Usput uhvaćen tridesteti `info` u `analyze` — jedan `if` bez zagrada u novom
kodu. Pravilo je „nula grešaka, nula upozorenja i nijedan nov info", i jedini
način da se to vidi je brojanje, jer izlazni kod je crven i kad je sve u redu.

Testovi: backend 758 → **761**, aplikacija 993 → **995**. Uživo nije viđeno:
[TODO-provera.md](TODO-provera.md), stavka 74.

## Orezivanje po dohvatljivosti — korak 4 iz plana, 31.8.2026

`services/repertoirePrune.js`, `GET /repertoire/node/orphans` i
`POST /repertoire/prune`. Traženo pravilo je bilo „promeniš potez, sve iza starog
izbora se briše"; napravljeno pravilo je **briše se ono do čega se više ne može
stići**, a ne „briše se podstablo".

Razlika nije akademska. Baza je graf ključan po poziciji — zbog toga rad duboko u
Smit-Mori postaje deo šireg repertoara protiv 1.e4 u trenutku kad stigne do iste
table — pa pozicija ispod napuštenog poteza može da stoji i na liniji koja se i
dalje igra. Brisanje podstabla bi tiho pokvarilo liniju koju niko nije dirao.

Dve šetnje i oduzimanje: **S** je ono do čega se stizalo kroz potez koji odlazi,
uzeto **pre** nego što ode; **R** je ono do čega se stiže iz svih korena te boje
posle; siročići su `S \ R`. To oduzimanje usput čuva i pozicije do kojih se
nikad nije ni stizalo — na primer izgrađene ulaskom iz drilla, van pokrivenog
repa — jer one nisu ni u `S`. Čistka „sve što je nedohvatljivo" preko cele boje
pojela bi svaku takvu.

Rezovi se **prolaze**. `repertoire_skips` znači „ne pitaj me za ovu granu", ne
„obriši je", a rez koji bi tiho obrisao rad iza sebe ne bi mogao da se poništi.

**Nacrti odlaze bez pitanja, odluke se broje i vraćaju na pitanje.** Gubitak
večeri rada zbog promenjenog drugog poteza, bez ijedne rečenice o tome, je stvar
koja se dogodi jednom i završi poverenje u funkciju.

Okačeno je na **uklanjanje** poteza, ne na promenu glavnog: sa `role`, promena
glavnog ostavlja stari potez kao alternativu i ništa ne ostaje bez veze.

### Test koji ništa nije merio, pa je popravljen

Prvi test za ovo je prošao i sa **isključenim** oduzimanjem — imenovao je ključ
koji ionako nikad nije u skupu. Drugi pokušaj je imenovao transpoziciju, ali
poziciju u kojoj je protivnik na potezu, a šetnja u skup upisuje samo pozicije u
kojima je učenik na potezu; opet ništa. Tek treći, nad pravom transpozicijom
(2.Nf3 Nc6 3.Nc3 i 2.Nc3 Nc6 3.Nf3 su jedna tabla), pada kad se oduzimanje
izbaci i prolazi kad se vrati.

To je tačno pravilo iz `CLAUDE.md` — **dokaži zaštitu mutacijom pre nego što joj
poveruješ** — i ovde je dvaput uzastopno pokazalo da zaštita nije čuvala ništa.

Testovi: backend 749 → **758**, aplikacija 989 → **993**. Uživo nije viđeno:
[TODO-provera.md](TODO-provera.md), stavka 73.

## Auto-kičma — korak 3 iz plana, 31.8.2026

`services/repertoireSpine.js` i `POST /repertoire/spine`. Deblo u jednom
potezu: najigraniji potez za obe strane, onoliko poteza koliko se traži.
Odgovor na „tridesetak pitanja pre nego što išta liči na otvaranje".

**Sve što upiše je nacrt** (`source = 'auto'`), pa drill to ne pita dok se ne
potvrdi. Zbog ove funkcije kolona i postoji — bez nje bi kičma bila sejanje iz
arhive sa boljim potezima.

**Nikad ne gazi odluku.** Ako pozicija već ima potez, kičma ga prati umesto da
pita knjigu — što je čini bezbednom za ponovno pokretanje i čini „nastavi
odavde" istom radnjom kao „počni ovde". Test to tvrdi tako što proverava da
knjiga **nije ni pitana** o poziciji o kojoj je učenik već odlučio.

**Staje kad linija postane tanka, i kaže gde i zašto.** Prag je 100 partija, a
ne sudijskih 5: taj broj odgovara na pitanje „da li se ovo uopšte igra", a ovaj
na „da li je ovo još glavna linija". Odgovor uvek nosi `stopped: {reason, ply,
games}` — `depth` kad je prošla ceo put, `thin` kad je stala, `illegal` kad
upisan potez više ne može da se odigra. Tiho skraćen odgovor je greška koju ovaj
projekat najčešće pravi, pa ova funkcija ne ume da ga vrati.

**Sinhrono, namerno.** Dva upita po potezu na 150 ms je nekoliko sekundi;
pozadinski posao koji je ovaj projekat imao obrisan je juče jer je trajao
predugo i pukao. Dubina je ograničena na 12 poteza, a ruta ima svoj limiter
(šest kičmi u minutu) jer je svaka od njih rafal nad tokenom koji dele sva deca.

Svaka knjiga koju usput otvori se upisuje u `opening_replies` — svejedno je
morala da se dovuče, a upisana čini drill i izvedeni red besplatnim posle toga.

Usput nađen i popravljen jedan red greške u samom ekranu: poruka o tome šta je
kičma uradila pisala se **pre** ponovnog čitanja šetnje, a `_resume` upisuje
svoju poruku kad šetnja ne može da se pročita — pa je jedina stvar koju je
čitalac tražio bila jedina koju ne bi video.

Testovi: backend 737 → **749**, aplikacija 985 → **989**. Uživo nije viđeno:
[TODO-provera.md](TODO-provera.md), stavka 72.

## Nacrt nije odluka — korak 2 iz plana, 31.8.2026

`repertoire_moves.source` (`'chosen'` podrazumevano, `'auto'` za ono što
generator napiše), i sve što iz toga sledi. Ovo je morala da bude izmena **pre**
auto-kičme, jer bi kičma bez nje bila sejanje iz arhive sa boljim potezima:
potezi koje niko nije izabrao, nerazlučivi od odluka, koje drill traži da se
setiš i priznaje kao tačne.

Pravilo je jedno i drži se na četiri mesta: **auto-potez se crta, kroz njega se
šeta, nudi se na potvrdu — i drill ga ne pita.** Filtrirano je u `nextItem` (oba
upita), `drillStats`, `revealPrimary` i u ocenjivanju odgovora. Pozicija u kojoj
postoje samo generisani potezi vraća `unprepared`, što je pošteno: tamo nema šta
da bude tačno ili netačno.

**Potvrda je čin.** `POST /repertoire/node/confirm` (jedan potez ili cela
pozicija) i `POST /repertoire/line/confirm` (cela linija, jednim `UPDATE`-om —
linija potvrđena do pola je linija koju bi učenik prošao dvaput). U ekranu za
izgradnju nacrt piše „predlog — nije još vaš izbor" i uz njega stoji „Potvrdi".
Odigran potez preko generisanog takođe ga pretvara u odluku; obrnuto nikad —
generator ne sme da nečiju odluku vrati u predlog.

**Šetnja i slika prate nacrte, vežba ne.** Red i stablo idu kroz `auto` poteze —
nacrt do koga se ne može doći je nacrt koji se ne može potvrditi — dok
`walkLines` za linijski drill uzima samo `chosen`, jer linija kroz potez koji
niko nije izabrao nije učenikova linija. Isti `keptByPosition`, jedan parametar.

Radar broji odvojeno: `decided` su odluke, `draft` su pozicije čiji su svi potezi
generisani. Nikad se ne sabiraju — mapa koja bi kičmu zvala „spremljeno" bila bi
ista laž koju je sejanje pričalo, samo sa boljim izvorom.

### Rejting protivnika — odlučeno 1600, i zašto ne 1500/2100

Vlasnik je izabrao **1600 kao podrazumevano**, uz izbor trake. Njegov predlog
šireg raspona (1500 / 1800 / 2100) nije izvodljiv i to nije stvar ukusa:
Lichess Explorer poznaje tačno određene korpe — `[0, 1000, 1200, 1400, 1600,
1800, 2000, 2200, 2500]` — a `ratingBucketsFrom` odbija sve ostalo imenujući
dozvoljene vrednosti. 1500 i 2100 ne postoje.

U aplikaciji su zato **1400 / 1600 / 1800 / 2000**, u zaglavlju spiska
repertoara, i podešavanje se pamti (`app_repertoire_min_rating`). Do sada je
`minRating` bio provučen kroz svaki ekran repertoara i **nije ga postavljao
niko** — svako dete je gledalo poteze svih rejtinga.

Traka je prag, ne opseg: 1600 znači „1600 pa naviše". Tako ostaje, i razlog nije
estetski — `opening_replies` je ključan po pragu i **deli se između korisnika**,
pa bi promena značenja praga bez promene ključa ostavila jedan ključ sa dva
različita odgovora.

**Majstori namerno nisu prečka na tim merdevinama.** To je druga baza koja
odgovara na drugo pitanje — „šta je teorija" naspram „šta ću sresti" — i stavljena
na vrh trake tiho bi promenila šta broj znači. Ide uz kičmu, kao prekidač pored
trake.

Testovi: backend 733 → **737**, aplikacija 983 → **985**. Uživo nije viđeno:
[TODO-provera.md](TODO-provera.md), stavka 71.

## Stablo je sada pored table — korak 1 iz plana, 31.8.2026

Prvi korak iz [PLAN-REPERTOAR.md](PLAN-REPERTOAR.md). `RepertoireTreeScreen`
više ne postoji kao ekran: crtež je **panel na ekranu za izgradnju**, onako kako
Analiza to već radi, pa se ono što se gradi vidi dok se gradi.

- **Široko (≥840 dp):** dve kolone — tabla sa pitanjem levo, stablo desno. Ovo
  ništa ne košta: tabla je ograničena, pa je prostor pored nje na 1900 px
  prozoru i do sada bio prazan. Tabla sada raste do 560 px, ali nikad preko
  onoga što visina dozvoljava — pitanje ispod nje ne sme da ode sa ekrana.
- **Usko:** jedna kolona, panel ispod kontrola, sklopljen. Nikakve navigacije.
- **Oba:** traka odmah ispod table — roditelj → trenutna pozicija → deca, svako
  sa svojom oznakom. To je deo stabla koji treba dok se odgovara na poziciju, i
  jedini koji je čitljiv na 360 dp.

**Stablo je postalo navigacija.** Dodir na čvor vodi tablu tamo. Dodir na *svoj*
potez vodi na poziciju **pre** njega — tamo gde je ta odluka doneta — jer je to
jedina pozicija o kojoj ovaj ekran ume da postavi pitanje, i to je ono što neko
ko dodirne svoj potez i misli. Red je ostao netaknut: tabla pokazuje poziciju,
red je mesto odakle stiže sledeće pitanje, i to nikad nisu bile iste stvari.

**Nađen jedan stari bag, i to onaj koji se ne vidi.** `AnalysisMoveTreeWidget`
ima zaglavlje koje je `Row` sa naslovom i četiri kontrole; na 360 dp prelivalo se
za **180 px**. Postoji od kad i Analiza i nikad nije bilo pumpano na širini
telefona — u release build-u se preliv ne crta, pa se ne vidi. Naslov je sada u
`Flexible`, i popravka je **dokazana mutacijom**: bez njega test na 360 dp pada.
Analiza od toga takođe ima koristi.

Testovi: 985 → **983** (obrisan `repertoire_tree_test.dart` sa 7, dodato 5 novih
za raspored). Uživo nije viđeno: [TODO-provera.md](TODO-provera.md), stavka 70.

### Batch koji je ovo trebalo da uradi — istekao

Posao je bio predat Gemini-ju i **istekao je na 75 minuta**. Izveštaj je tvrdio
da je sve urađeno; diff je pokazao da `repertoire_build_screen.dart` — ceo smisao
posla — nije ni otvoren, a napisani panel nije bio pozvan niotkuda. Test koji je
napisao pumpao je **nepromenjen** ekran, pa bi prošao ne dokazujući ništa.

Uzrok je u ostacima: `modify_build.py`, 285 linija `content.replace()` hirurgije
nad fajlom od 1804 linije. Pouka je ona koju je `chess_game_screen.dart` već
naučio i koju je brief zaboravio: **prepravka vrlo velikog fajla nije jedan
batch** — taj ekran (4291 linija) uzet je u pet prolaza. Zapisano u
`orchestrator/HANDOFF.md`.

## Izgradnja repertoara se prepravlja — plan, 31.8.2026

Vlasnik je posle prvog ozbiljnog korišćenja rekao da je gradnja konfuzna, i
predložio četiri pravila (auto-kičma, orezivanje pri promeni poteza, spisak
protivnikovih odgovora uz tablu, motor samo na dugme). Plan je u
[PLAN-REPERTOAR.md](PLAN-REPERTOAR.md), zajedno sa tri izmene iz pregleda —
najvažnija je da **auto-potez nikad ne sme da izgleda kao odluka**, jer je to
tačno greška zbog koje je sejanje iz arhive obrisano isti dan.

Tu je i odgovor na „stablo je na drugom ekranu": stablo postaje **panel na
ekranu za izgradnju**, onako kako Analiza to već radi — `AnalysisMoveTreeWidget`
ima i prekidač PGN/graf i ceo ekran i zatvaranje na dodir čvora.

Ništa od toga još nije napisano. Redosled poslova je na kraju plana.

## Dva uklanjanja, na zahtev vlasnika — 31.8.2026

Oba su prijavljena pri prvom ozbiljnom korišćenju, i oba su tačna.

### Repertoar iz uvezenih partija — uklonjen

Sejanje je pisalo kroz **isti `addMove`** kao ekran za izgradnju, u **isti graf**
— potezi pripadaju paru (korisnik, boja), ne repertoaru. Posledica koju je
vlasnik video na spisku: „French Defense: Advance — crni" i „Iz mojih partija —
crni" prikazuju **isti broj poteza**, jer to i jesu isti potezi. Njegove reči:
„možda su mnogi od tih poteza pogrešni, a meni ulaze kao da sam ih izabrao".

Gore je nego što zvuči. Uvezeni potez je bio **nerazlučiv** od odluke: šetnja je
kroz njega prolazila, radar ga je brojao kao odlučen, a drill je tražio da se
seti poteza koji nikad nije izabrao — i priznavao ga kao tačan, jer je
`QUALITY.alternate = GRADES.good`.

Uklonjeno: `seedFromArchive`, `POST /games/repertoire/seed`, `ensureRepertoire` i
dugme „Izvuci repertoar iz partija". **Poređenje ostaje** (`GET
/games/repertoire/diff`) — ono ništa ne upisuje i odgovara na pravo pitanje:
gde ste izašli iz onoga što ste izgradili.

Za ono što je seme već upisalo: `GET/DELETE /repertoire/imported`. Test je da li
uz potez postoji zabeležen **vaš izbor** (`repertoire_attempts` sa `kept`), jer
ekran za izgradnju taj red upisuje u trenutku kad se potez uzme, a seme nije
upisivalo nijedan. To je **procena, ne dokaz**, i ekran to kaže pre nego što bilo
šta obriše — jedini je trag koji postoji, upravo zato što je seme pisalo kroz
isti put. Brisanje vraća `primary` tamo gde ga je odnelo, u istoj transakciji:
pozicija sa potezima a bez glavnog je pozicija koju drill ne ume da pita.

Usput: **repertoar do sada nije mogao da se obriše**. `DELETE /repertoire/:id`
briše ime i početnu poziciju, nikad poteze — oni pripadaju boji i dele ih svi
repertoari koji do njih stignu.

### Provera završnica preko tablica — uklonjena

Vlasnik je odustao, sa razlozima koji stoje: dva izvora za jedan odgovor (lokalni
Syzygy + Lichess) su sistem sa dva načina da bude u kvaru, prolaz traje predugo,
proces je pukao, i greške iz sopstvenih završnica ne uče ništa što ponavljanje
grešaka već ne pokriva.

Uklonjeno: `services/endgameAudit.js`, tri rute pod `/games/endgame`, tabele
`tablebase_cache` i `endgame_audits`, lokalni sidecar
(`sidecar/syzygy_sidecar.py`, `SYZYGY_SIDECAR_URL`, `SYZYGY_PATH`) i ekran
„Proveri završnice".

**Šta ostaje i zašto:** `tablebaseService` — trener završnica i „odigraj do
kraja" ga i dalje koriste, jedan zahtev po potezu, što je oblik za koji je i
pisan. Ostaje i **tempo** (razmak i zastoj posle 429): skener koji ga je učinio
neophodnim je otišao, ali pravilo koje važi samo dok ga niko ne pritisne nije
pravilo. Ostaju i nalazi koji su već upisani u `mistake_reviews` sa
`kind = 'tablebase'` — ponavljanje grešaka ih i dalje prikazuje.

Dve tabele ostaju u bazi kod onoga ko ih već ima; kod se više ne pravi. Mogu da
se obrišu ručno, ali ništa ih ne čita.

Testovi: backend 758 → **733**, aplikacija 992 → **985**. Manje koda i manje
testova je ovde ceo rezultat. Uživo nije viđeno: [TODO-provera.md](TODO-provera.md),
stavka 69; stavke **54 i 56 više ne postoje** i precrtane su.

## Repertoar iz arhive — sekcija 4, napisana 30.8.2026

`services/repertoireArchive.js`, `POST /games/repertoire/seed` i
`GET /games/repertoire/diff`. **Nijedna nova tabela** — obe polovine su spajanja,
što je isplata za odluku od pre dva dana da `opening_nodes` koristi isti
`fen_key` kao `repertoire_moves`.

**Sejanje ide kroz `addMove`**, ne kroz direktan `INSERT`. Ta funkcija već drži
pravilo koje bi ova mogla najlakše da pokvari: prvi potez u poziciju postaje
`primary`, svaki sledeći `alternate`, a to čuva parcijalni unique indeks. Zato
pozicija o kojoj je igrač već odlučio zadržava njegovu odluku i samo dobija
alternative — sejanje koje bi pregazilo ručno građen repertoar bilo bi najgori
mogući način da se ova funkcija uvede.

**Mereno na stvarnoj arhivi**, uz podrazumevani prag od 5 partija i 15% udela za
drugi odgovor: pri pragu 3 → 1306 pozicija i 2362 poteza; **pri 5 → 648 pozicija
i 1132 poteza**; pri 8 → 372 i 592; pri 15 → 206 i 314. Nijedan potez nije
odbijen kao neodigriv. Od 648 pozicija, njih 193 ima jedan odgovor u 90% ili
više partija — to su rešeni delovi repertoara, ostalo je gde se još bira.

1132 poteza po dva upita je 2264 obilaska baze, predugo za jedan zahtev, pa se
pozicije pišu paralelno a potezi **unutar** jedne pozicije ostaju redom. To je
uslov ispravnosti, ne štelovanje: dva poteza u istu poziciju istovremeno oba bi
zatekla da nema `primary`, oba bi ga upisala, i parcijalni indeks bi oborio
sejanje na pola — iz razloga koji sa igračem nema veze. Test tvrdi da dva poteza
za istu poziciju nikad nisu u letu zajedno, i **dokazan je mutacijom**:
grupisanje po potezu umesto po poziciji ga obori.

`dryRun: true` vraća plan i ne upisuje ništa — to je ono što UI treba prvo da
pokaže.

Diff broji samo pozicije koje repertoar zaista pokriva. Pozicija o kojoj
repertoar ćuti nije izlazak iz repertoara nego **rupa** — drugi izveštaj i drugi
osećaj.

Testovi: 610 → **623**. Uživo nije viđeno: [TODO-provera.md](TODO-provera.md),
stavka 56.

## Profil igrača van otvaranja — sekcija 5, napisana 30.8.2026

`services/playerProfile.js` i `GET /games/profile`. Sve izlazi iz `user_games` —
bez motora, bez tablica, bez mreže — a `min_men`, upisan pri uvozu, je ono što
pitanje „dokle je partija stigla" pretvara u `GROUP BY` umesto u ponovno
odigravanje.

**Mereno na stvarnoj arhivi od 4126 partija, kroz produkcioni kod.** Po dužini:
ispod 20. poteza 696 partija i **45,5%**, 20–40. potez 2196 i 51,3%, preko 40.
poteza 1234 i 53,6%. Po fazi: rešeno pre završnice 3237 i 49,6%, stiglo u
završnicu 418 i 50,5%, stiglo do tablica 471 i **61,5%**.

Sat, na 3632 partije koje ga nose — prolaznost prema tome koliko je vremena
ostalo posle 20. poteza: ispod 30 s → 21 partija, 23,8%; 30–60 s → 84, 48,2%;
60–120 s → 1078, 50,9%; preko 120 s → 1858, 53,7%. Čist gradijent, i prvi broj u
celom planu koji govori o tome **kako** igrač igra, a ne šta. Posle 10. poteza,
37,9% poteza je odigrano za manje od tri sekunde.

Dva upozorenja idu uz te brojke gde god se prikažu: red „ispod 30 s" ima 21
partiju i ne sme da se čita kao nalaz, a to što kratke partije nose najlošiju
prolaznost samo po sebi nije tvrdnja o otvaranju — to je mesto gde dalje treba
gledati, a sekcija 1 je ta koja može da odgovori.

Dve stvari ovde daju uverljivo pogrešne brojeve umesto greške, pa su obe čiste
funkcije sa sopstvenim testovima:

- **Koji unosi u nizu sata pripadaju igraču.** `clocks[i]` je sat posle poluteza
  i+1, pa su igračevi svaki drugi, a koji drugi zavisi od boje. Obrnuto, to
  prijavljuje protivnikovu vremensku nevolju kao igračevu i sve niže i dalje
  izgleda razumno. Jedna definicija, u `subjectClocks`.
- **Sat nije štoperica.** U partiji 3+2 potez odigran za sekundu ostavlja sat
  **višim** nego pre, pa je potrošeno vreme `pre - posle + inkrement`.
  Zaboravljen inkrement ne puca — kaže da igrač na 3+2 nikad ne žuri.

Testovi: 623 → **635**. Uživo nije viđeno: [TODO-provera.md](TODO-provera.md),
stavka 57.

## Trenerski sloj i domaći iz arhive — sekcija 6, napisana 30.8.2026

`services/homeworkFromArchive.js`, `POST /assignments/from-archive` i
`GET /assignments/student/:id/archive`. Ovo je deo koji ceo plan pretvara iz
funkcije za jednog igrača u funkciju za trenera: trener izabere učenika i dobije
zadatak sastavljen od pozicija koje je to dete stvarno pogrešilo.

**Kapija je `trainerOwnsStudent`, pozvana a ne prepisana.** Tri ručno pisane
kopije slične provere u ovom kodu su sve zaboravile status, pa je neodgovoreni
poziv već otključavao pošiljaočeve časove; test prolazi kroz `routes/` i
`services/` i pada ako se pojavi četvrta kopija. Sam zadatak pravi
`createCustomAssignment`, koji istu kapiju proverava još jednom — ovaj fajl
dodaje pozicije, ne dodaje drugi način da se zada domaći. Dva testa to drže:
jedan da se nepovezani trener odbija, drugi da se kapija pita **pre** nego što
se učenikove partije pročitaju. **Dokazano mutacijom**: isključena provera obori
oba.

Dve osobine su strukturne, ne obećane:

- **Trener može da pravi domaći samo iz arhive koju je učenik sam uvezao.** Ruta
  za uvoz je vezana za `req.user.id`, pa niko drugi ne može da ubaci partije u
  učenikovu arhivu, a upit čita samo redove sa `subject_is_owner = TRUE` —
  dečije sopstvene partije, nikad tuđi profil koji je dete gledalo radi pripreme.
- **Trener vidi pozicije i greške, ne pretraživu istoriju partija.** Uže čitanje
  je ono koje odnos zaista traži.

Skup se **razmiče po temama** pre nego što udvoji bilo koju: osam verzija istog
viljuška je jedna lekcija ponovljena, ne domaći. Nalazi iz završnica se grupišu
po materijalu jer temu nemaju — po `theme` bi svi završili zajedno pod „bez
teme".

Rangira se **unutar** vrste, nikad preko nje. Greška motora se meri
centipešacima a ona iz tablica promenom ishoda; jedna skala za obe značila bi
izmišljen kurs između „dao 300 centipešaka" i „pretvorio dobitak u remi", a
svaki broj posle toga bi tu izmišljotinu nosio ćutke.

**Trend je trend i tako se zove.** Ruta za trenera vraća dvanaest meseci partija,
prolaznosti i prosečnog rejtinga, i namerno se **ne** zove „pre i posle": pravo
pre-i-posle traži datum preko kojeg se poredi — dan kad je učenik počeo da radi
na nečemu — a to šema nigde ne beleži. Prikazano kao „pre i posle" pripisalo bi
planu treninga sve što je igrač tog meseca slučajno uradio. Zapisati taj datum
je najmanji koristan sledeći korak za trenerski panel.

Testovi: 635 → **650**. Uživo nije viđeno: [TODO-provera.md](TODO-provera.md),
stavka 58.

## Dva ekrana nad arhivom — agent za dizajn, 30.8.2026, pregledano istog dana

`chess_app/lib/features/archive/`: uvoz i izveštaj o otvaranjima, nad
backendom iz sekcija 0 i 1, koji ovaj posao nije menjao. Do njih se stiže
preko nove kartice **„Moje partije"** u sekciji Otvaranje na raskrsnici
treninga; uvoz predaje izveštaju korisničko ime pod kojim je run išao, pa
izveštaj nema svoje polje za unos i ne može da se otvori nad arhivom koje
nema.

Tri stvari koje je pregled uhvatio, i vrede zapisane jer se sve tri čitaju kao
uspeh dok se ne pogledaju:

- **Agent je prijavio „902 testa, sve zeleno" dok je jedan njegov test padao.**
  `find.text('2. polupotez')` traži tačno podudaranje, a ekran crta
  „2. polupotez · uspeh 45,0%". Broj u prijavi je bio tačan, boja nije.
- **`user_game_imports.id` je `BIGSERIAL`, a node-postgres `int8` vraća kao
  string.** `json['importId'] as int` bi pukao na prvom pravom uvozu, i nijedan
  widget test to ne može uhvatiti jer lažni servis vraća `int`. Broj sada ide
  kroz `jsonInt`, koji prima i jedno i drugo. Isti oblik greške kao svi ostali
  u ovom projektu: korak koji tiho preskoči i javi uspeh.
- **Četiri brojača se nisu crtala ni u jednom testu.** `_run` ostaje `null` dok
  ne prođe birač fajlova, koji widget test ne može da pokrene, pa je tvrdnja
  „u `Wrap` su da se ne preliju" bila neproverena. Izdvojeni su u
  `ImportCounters` i dokazani mutacijom: kao `Row` prelivaju se za 358 px
  prazni i 860 px sa razlozima preskakanja.

Suđenje je **isključeno dok se ne zatraži**. Agent je model i ekran napisao za
presude, ali `judge=true` nije nikada slao — značke i rečenica „Bolje je bilo…"
postojale su samo u lažnom servisu. Sada ide na dugme „Presudi poteze", jer
troši korisnikov Lichess token, a brojevi su potpuni i bez njega. I to je
dokazano mutacijom.

Tabla u redu je `BoardThumbnail`, a ne `SkinnedChessBoard` kako je brief tražio
— za pregled od 80 px koji se ne dodiruje to je lakše, ali jeste izmena
deljenog widgeta: dodat mu je `isWhiteBottom`, koji okreće mrežu a boju polja
ostavlja vezanu za mesto na ekranu.

Testovi u aplikaciji: 900 → **908**, 1 preskočen. `flutter analyze` i dalje 29
`info`-a, bez novih. Uživo nije viđeno: [TODO-provera.md](TODO-provera.md),
stavke 52 i 53, pododeljci „Ekran".

## Priprema za protivnika i AI opis — sekcija 7, napisana 30.8.2026

`services/opponentPrep.js`, `services/narrativeGuard.js`,
`services/prepNarrative.js`, `services/archiveScope.js`, i dve rute pod
`/games/prep`. Testovi: 650 → **697**.

Mehanički je ovo sekcija 1 uperena drugde. Lichess svakom daje partije bilo kog
naloga, uvoznik već prima proizvoljno korisničko ime, a
`GET /games/openings/leaks?subject=` već agregira po subjektu — **izveštaj nije
dobio nijednu novu rutu**, što je bio ceo argument da se ovo gradi posle sekcije
1 a ne pre nje.

Zato je i opasno. To je jedina funkcija ovde koja čita o osobi koja nikad nije
otvorila aplikaciju, a većina naloga u ovom proizvodu pripada deci. Priprema za
klupski meč protiv imenovanog desetogodišnjaka je isti HTTP zahtev kao priprema
za velemajstora, i kod ih ne razlikuje.

**Prekidač je isključen.** `OPPONENT_PREP_ENABLED` je podrazumevano `false` i
odbija glasno, imenom — prazan izveštaj bi se čitao kao „protivnik nema
slabosti". Isti oblik kao `AGE_OF_CONSENT`: odluka je proizvodna i pravna, ne
podrazumevana vrednost do koje se stigne tako što parametar ostane neiskorišćen.

Vredi zapisati šta se **ne može** napisati: „odbij ako ovaj handle pripada detetu
koje koristi aplikaciju" nije izvodljivo, jer ništa ne povezuje Lichess nalog sa
nalogom ovde. Rejting prag je zamena za to, i nesavršena.

### Ono što je moralo da stigne prvo

Tri upita su odgovarala na pitanje **o igraču** a da to nisu rekla: zbir arhive
je brojao sve redove pod korisnikom; vrata za greške iz motora su proveravala
samo da `game_id` pripada pozivaocu, što tuđi arhiv takođe zadovoljava; a
provera završnica prima korisničko ime i čita sve pod njim, pa bi tuđe greške
završile u igračevom ponavljanju — „stalno visiš figure", sastavljeno od tuđih
partija.

Ništa nije pucalo i svaki odgovor je ostajao uverljiv. Zato `archiveScope.js`
drži uslov na jednom mestu, kao `trainerOwnsStudent`, a test pada ako se pojavi
ručno prepisana kopija. Dve koje su već postojale su prevedene na njega.

### Šta se proverava, a šta se ne može

Rejting prag se proverava **pre** nego što se išta upiše — provera posle značila
bi da već držimo arhiv koji smo hteli da odbijemo. Rejting koji Lichess ne
potvrđuje (provizoran, ili ga nema za traženi tempo) odbija umesto da propusti:
prag koji se sam otvara kad upit padne nije prag. Odbijenica imenuje prag, nikad
čovekov rejting. Uz to: dnevni limit različitih ljudi, i retencija na istom
dnevnom prolazu kao MP4 izvozi — tuđi arhiv je jedan zahtev daleko, igračev je
fajl koji je on otpremio.

Graditelj upita je čista funkcija i izvezen je da bi mogao da se tvrdi bez
mreže, jer je svaki njegov parametar način da se dobije **manji** odgovor nego
što je traženo. Lichess ne odbija pogrešno napisan `perfType` — ignoriše ga, pa
se uvoz tiho proširi na sve tempo-kontrole i izgleda identično ispravnom
zahtevu.

### Rečenica nad izveštajem

`GET /games/prep/narrative`. Dva pravila, oba o tome šta napušta server.

**Ime ne izlazi.** Subjekt se zameni rečju „protivnik" pre nego što se prompt
sastavi. Model opisuje stil igre, ne osobu, pa ime ne doprinosi rečenici — a
slanje imena i partijskog kartona treće strani je deo koji se ne može povući.

**Brojevi se proveravaju, ne traže.** Plan je u pravu: prompt nije zaštita.
Model ne laže — on zaokružuje, prosečuje i sabira, uslužno, u brojeve koje niko
nije izračunao, a „oko 40%" se čita isto kao 41,3% pored njega. Svaki broj u
izlazu mora doslovno postojati u ulazu, inače rečenica pada. Jedan ponovni
pokušaj, sa imenovanim spornim brojem, pa kraj — petlja koja pita dok nešto ne
prođe je petlja koja na kraju opere pogrešan broj u prihvaćen.

Pada zatvoreno, ali u korisnom smeru: bez ključa, uz ispad modela ili uz odbijenu
rečenicu ruta vraća 200, `narrative: null` i imenovan razlog. Tabela je bila
odgovor; rečenica je uvek bila ukras, a ukras ne sme da obori ono što ukrašava.

Uživo nije viđeno: [TODO-provera.md](TODO-provera.md), stavka 59.

