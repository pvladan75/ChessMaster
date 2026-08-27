# TODO — šta još nije provereno u aplikaciji

Sve navedeno je napisano, prolazi testove i `flutter analyze`, ali **nije viđeno
kako radi uživo**. Automatski testovi pokrivaju logiku; ne pokrivaju da li je
dugme na pravom mestu i da li tok ima smisla.

Poređano od najbržeg za proveru ka najsporijem.

---

> Kad neki odeljak upućuje na `STANJE-RADA.md` po imenu („vidi *…*") a
> tamo ga nema: zatvorena istorija je 27.8.2026. izdvojena u
> [arhiva/STANJE-RADA-do-26.8.2026.md](arhiva/STANJE-RADA-do-26.8.2026.md).
> `grep` po naslovu nađe odeljak u jednom od ta dva fajla.

## 0. Trener završnica — ✅ provereno uživo 22.8.2026

Korisnik je prošao tok u Windows verziji: AI Studio → kartica „Završnice iz
majstorskih partija" → oba dugmeta. Potvrđeno na više pozicija da se prihvata
**svaki** potez koji drži rezultat, da se posle rešenja nudi „Nađi i ostale"
sa brojačem, da to vraća polazni položaj, i da već nađen potez daje „Taj potez
ste već našli. Potražite drugi." bez kažnjavanja.

Provereno i: oznaka „Tačno iz tablica" na pozicijama sa pet i manje figura,
razlika u tekstu između režima („održite remi" / „zadržite dobitak"), tabla
okrenuta prema strani koja rešava, i imena igrača sa godinom.

**Nađeno pri toj probi, popravljeno istog dana:** posle rešenja je pisalo
koliko još poteza drži rezultat, ali se **nije moglo videti koji su** niti
ponovo odigrati istu poziciju. Brojka bez poteza ne uči ništa — cela poenta
pozicije sa više odgovora je koji su. Dodati su izbor „Nađi i ostale" i
„Pokaži".

**Dodato 23.8.2026, nije viđeno uživo.** Cela zbirka je presuđena iz tablica
(vidi [ZAVRSNICE.md](ZAVRSNICE.md), „Ponovno suđenje postojeće zbirke"), pa je
jedna pozicija dobila potez više, a sedmofiguraške sada nose `source = lichess`:

- [ ] `6k1/5p2/7p/8/4r2P/2Q5/6K1/8 w - - 9 55` (QueenVsRook, dobitak): `Qc8+`
      mora da bude prihvaćen, uz `Qf3` i `Qg3+`. Ranije je vraćao „netačno".
- [ ] Neka sedmofiguraška pozicija i dalje nosi oznaku „Tačno iz tablica".

## 0c. Igranje do kraja — ✅ prošlo uživo 23.8.2026, dve stavke otvorene

Dugme „Odigraj do kraja" na pozicijama do sedam figura. Backend sudi svaki potez
iz tablica; protivnik brani tablično najbolje.

Korisnik je 23.8.2026, na Windows verziji, prošao ceo tok i potvrdio sve osim
dve stavke na dnu:

- [x] Dugme se vidi na poziciji sa pet figura, a ne vidi se na onoj sa devet.
- [x] Potez koji drži dobitak → „Tačno — dobitak je zadržan i prišli ste bliže",
      pa protivnikov odgovor odigran na tabli.
- [x] Potez koji drži ali ne napreduje (šetnja kraljem) → „Tačno, dobitak je
      zadržan — ali niste prišli bliže".
- [x] Potez koji ispušta dobitak → vežba staje i imenuje potez.
- [x] Odigrati jednu do kraja: **završava se matom**, ne vrti se u krug. Ovo je
      ista ona greška koju je odigravanje partije našlo istog dana pri izradi;
      sada je i uživo potvrđeno da je nema.
- [x] „Nazad na zadatak" vraća početnu poziciju i običan režim rešavanja.

Ostaje:

- [ ] Nedostupna tablica: postaviti `LICHESS_TABLEBASE_URL` na nepostojeći host,
      restartovati backend i odigrati potez. Mora da kaže da tablica nije
      dostupna i da **vrati tablu na prethodni položaj**, a ne da ostavi
      nepresuđen potez da stoji kao presuđen.
- [ ] Na telefonu: tri dugmeta vežbe u jednom redu na 360 dp.



## 0d. Greške iz partija i kazna — ✅ prošlo uživo 23.8.2026

12.683 pozicije iz stvarnih partija, gde je igrač promenio ishod. Trener ih
servira zajedno sa rudarenim; pozicija nosi i šta je odigrano i rejting onoga
ko je pogrešio.

- [ ] Pozicija sa greškom kaže „U partiji je odigrano X i remi je izgubljen",
      uz čip sa rejtingom.
- [ ] Na takvoj poziciji stoje **oba** dugmeta: „Odigraj do kraja" i „Kazni".
- [ ] „Kazni" postavlja poziciju **posle** greške, okreće tablu na stranu koja
      dobija, i naslov postaje „Kaznite grešku".
- [ ] Kazna se odigra do mata — protivnik brani tablično najbolje.
- [ ] „Ispočetka" u kazni vraća poziciju posle greške, ne početnu.
- [ ] „Nazad na zadatak" vraća početnu poziciju **i početni smer table**.
- [ ] Pozicija tipa „dobitak → remi" nema dugme „Kazni" (nema šta da se uzme).

Korisnik je prošao ceo tok 23.8.2026 na Windows verziji i potvrdio da sve gore
radi. Iz te probe su ispale dve zamerke; obe su napravljene istog dana i
**nisu viđene uživo**:

- [ ] **„Vrati potez"** posle greške u vežbi vraća položaj pre tog poteza i
      pušta da se nastavi. Dosad je jedini izlaz bio „Ispočetka", što na
      dvadeset osmom potezu baca dvadeset sedam poteza koji su bili tačni.
- [ ] Čip **„Greške: N"** raste sa svakim vraćanjem — vraćanje je besplatno,
      ali nije nevidljivo.
- [ ] **Koordinate na tabli**: slova linija ispod, brojevi redova levo. Kad se
      tabla okrene, oznake se okreću s njom.
- [ ] Na 360 dp koordinate ne smeju da prošire tablu preko ekrana — traka se
      uzima iz veličine koju ekran već daje, ne dodaje se na nju.

## 0e. Šetnja kroz partiju — ✅ prošlo na desktopu 23.8.2026

AI Studio → „Greške iz partija". Otvara se na poziciji gde je partija prvi put
pošla naopako; kad se nađe potez koji drži, partija se **na tabli** odigra dalje
do sledeće greške.

- [ ] Naslov kaže ko je pogrešio i šta je odigrao („Crni je ovde odigrao Rd3 i
      izgubio remi"), ispod stoji šta se traži.
- [ ] Pogrešan potez se odbija i tabla ostaje na istom položaju.
- [ ] Prihvata se **svaki** potez koji drži, ne samo prvi iz spiska.
- [ ] Posle tačnog odgovora tabla **ne skače** na sledeću grešku — ostaje gde
      jeste, pa se potezi odigraju jedan po jedan.
- [ ] Igranje staje tačno na sledećoj grešci i tabla tu postaje živa.
- [ ] Dodirivanje trake za kretanje **preuzima kontrolu** — igranje prestaje i
      dalje se korača ručno.
- [ ] Ručno se ne može preko neodgovorene greške, ni tasterom „na kraj".
- [ ] **Ispod table nema dugmadi sa potezima** — potezi se vide na tabli.
- [ ] Tabla se **ne okreće sama** kad grešku napravi drugi igrač; okreće je
      dugme u traci.
- [ ] „Na grešku" se pojavljuje kad se stoji iza neodgovorene greške i vraća na
      nju.
- [ ] „Pokaži" otvara prolaz, imenuje poteze koji su držali, i broji se
      odvojeno od nađenih.
- [ ] Posle **poslednje** greške ostatak partije je otključan do kraja: traka
      ide skroz napred, a poruka to i kaže. Odigra se dvanaest poteza, pa se
      stane — ostatak se prolazi rukom, jer četvrtina partija ima preko dvadeset
      poteza posle poslednje greške, a najduža sto pedeset pet.
- [ ] Na 360 dp ništa ne izlazi iz ekrana.

## 0k. Govor (TTS) — napisano 23.8.2026, nije viđeno uživo

Podešavanja → „GOVOR (ČITANJE PORUKA)". Podrazumevano isključeno; na ovoj
Windows mašini glasa za srpski nema dok se ne instalira hrvatski.

- [ ] Sa isključenim prekidačem aplikacija ćuti, i posle restarta je i dalje
      isključeno.
- [ ] Bez instaliranog glasa panel kaže da ga nema i kako se dodaje — a ne
      ćuti i ne čita engleskim glasom.
- [ ] Posle instaliranja hrvatskog glasa spisak jezika ga nudi i „Probaj" ga
      izgovara — **bez restarta aplikacije**, samo ulaskom u Podešavanja ili
      dugmetom „Potraži glasove ponovo".
- [ ] „Probaj" pročita `Rd3` kao „top de tri", a `Kf2` kao „kralj ef dva".
- [ ] Linija `g` se čuje kao g u „gitara" (zapis `gje`), a ne kao englesko „dž".
- [ ] U treneru završnica se presuda čuje čim se pojavi u panelu.
- [ ] Nova presuda prekida prethodnu, ne čeka je da se dovrši.
- [ ] Ista poruka se ne ponavlja kad se prozor promeni ili panel prerisuje.
- [ ] Brzina čitanja se čuje kad se pomeri klizač.
- [x] Isto na telefonu, sa srpskim glasom iz Google-ovog mehanizma —
      **prošlo 23.8.2026**, uz dve zamerke ispod.
- [ ] Brojevi u padežu: „Postoje još 2 takva poteza" (ne „2 takvih poteza"),
      „Postoji još 1 takav potez", „Postoji još 5 takvih poteza".
- [ ] `e6.` na kraju rečenice se čuje kao „e šest", ne „e šesti".
- [ ] Kazna kaže „Ovako se kažnjava potez Qxb2", sa potezom na kraju.
- [ ] Isključivanje govora u Podešavanjima **pre nego što je išta rečeno** ne
      ruši aplikaciju (ovo je bio pravi pad, `stop()` pre prvog `speak()`).
- [ ] „Zašto je loše" pa „Preskoči": nova partija se igra normalno, bez
      zaostalog dugmeta „Nazad na partiju".
- [ ] Dok kazna traje panel piše da se tabla tu ne igra.
- [ ] Rečenica se čuje do kraja: tabla ne odigra sledeći potez preko nje, i
      sledeća poruka je ne preseca nego sačeka.
- [ ] Govor prestaje kad korisnik dodirne traku za kretanje, odigra potez, ili
      izađe sa ekrana — i ne nastavlja se posle toga.
- [ ] Izbor glasa koji nije stvarno instaliran **ne ruši aplikaciju** — ni pri
      biranju, ni pri sledećem ulasku u Podešavanja; panel kaže da glasa nema.
- [ ] Prekidač „Uključi i online partije" u izboru završnica: isključen daje
      samo partije za tablom, uključen i online. Isto važi za šetnju kroz
      partiju, koja se ne otvara kroz taj ekran.
- [ ] U spisku glasova uz srpski/hrvatski piše „čita srpski", a strani glas
      sme da se izabere i tada čita naš tekst svojom fonetikom.
- [ ] Tabla čeka da se rečenica dovrši pa tek onda odigra sledeći potez — i u
      šetnji kroz partiju i u prikazu kazne.
- [ ] Ako glas ne javi kraj izgovora, šetnja se ipak nastavi (rok iz dužine
      rečenice), a u dnevniku stoji red o tome.

## 0p. Desktop prečice — 24.8.2026, nije viđeno uživo

- [ ] **Esc** zatvara ono što je otvoreno preko rada (podešavanja, vežbu,
      analizu) i vraća tačno gde si bio.
- [ ] **Esc na ljusci ne radi ništa** — prozor se ne prazni.
- [ ] **Ctrl+,** otvara podešavanja; držanje prečice ih ne otvara dvaput.
      (Nije radilo pri prvoj probi — vezano je i za fizički taster.)
- [ ] **Strelice** u šetnji kroz partiju: levo/desno potez, gore/dole krajevi.
- [ ] Dok je fokus u polju za tekst, strelice pripadaju polju.
- [ ] **Desni klik na tablu** kopira FEN i kaže da je kopiran — probaj na više
      ekrana (analiza, soba, završnice).

## 0o. Četiri taba — 24.8.2026, nije viđeno uživo

- [ ] Aplikacija se otvara na **Treningu**, ne na sobama.
- [ ] Izlazak iz vežbe **strelicom u ekranu** vraća na Trening sa tabovima —
      i u punom prozoru i u uskom. (Ovo je puklo pri prvoj probi 24.8.2026.)
- [ ] Podešavanja se otvaraju **iz podnožja rail-a** u punom prozoru, i iz
      trake u uskom. (Na Windows-u ih posle prve izmene nije bilo nigde.)
- [ ] Statistika naloga je u Podešavanjima, u odeljku „NALOG", i brojevi su
      tačni (isti kao ranije na Početnoj).
- [ ] Na „Časovima" te statistike više nema.
- [ ] Traka „Nastavi" se pojavi kad soba traje ili kad postoji sačuvana
      analiza, a inače se **ne vidi uopšte**.
- [ ] Dodir na „Nastavi čas" vraća u sobu, na „Nastavi analizu" u analizu.
- [ ] Tabovi su: Trening, Časovi, Biblioteka, Ljudi — i na traci dole i na
      rail-u sa strane.
- [ ] Podešavanja se otvaraju ikonicom u traci i **vraćaju tamo gde si bio**.
- [ ] Na 360 dp četiri odredišta staju bez preklapanja teksta.
- [ ] Sve što je bilo na staroj Početnoj i dalje radi iz „Časova": nova sesija,
      pridruživanje kodom, Studio, moji zadaci, ponavljanje, snimci.

## 0n. Zadaci dobili putanje — 24.8.2026, nije viđeno uživo

- [ ] „Moji zadaci" sa Početne se otvaraju i „nazad" vraća na Početnu.
- [ ] Otvaranje zadatka iz liste radi kao i pre (objekat se prosleđuje, nema
      novog dohvatanja i nema treptaja).
- [ ] Ocena zadatka se otvara sa sva tri mesta: iz liste, iz pregleda pozicija
      i iz napretka učenika.
- [ ] „Ponavljanje" sa Početne radi, a značka se osveži po povratku.
- [ ] Napredak učenika prikazuje ime u naslovu (stiže kroz `?name=`).

## 0m. Raskrsnica Treninga izdvojena — 24.8.2026, nije viđeno uživo

- [ ] Kartica „Trening" otvara listu kartica, bez table ispod.
- [ ] Svaka od sedam kartica vodi tamo gde piše, a „nazad" vraća na listu.
- [ ] Mat u 1/2/3 otvara zadatu dubinu; osnovno matiranje zadatu težinu.
- [ ] Red dugmadi ispod table (`Analiza`, `Probaj Ponovo`, `Naredna Pozicija`)
      staje na 360 dp — pre ovoga se prelivao za 80 piksela.
- [ ] Izlazak iz vežbe usred motorovog razmišljanja ništa ne ostavlja za sobom.

- [ ] Zadatak sa zagonetkama se otvara iz liste i nastavlja **tamo gde je
      stalo**, ne iz početka.
- [ ] Zadatak kojem je sve rešeno kaže da je završen umesto da otvori praznu
      vežbu.
- [ ] Izlazak iz vežbe usred motorove analize ništa ne ostavlja za sobom
      (`basic_mate` je do 24.8.2026. ostavljao tajmer).

## 0l. Nalaz tablica i „Zaključi remi" — napisano 24.8.2026, nije viđeno uživo

- [ ] „Nalaz tablica" u vežbi otvara spisak: prvo potezi koji drže, među njima
      prvo oni koji nuliraju brojač (zvezdica), pa oni koji gube.
- [ ] Na Windows-u je to **panel pored table**, ispod info panela, i **ostaje**
      dok se igra; dugme se pretvara u „Sakrij nalaz".
- [ ] Posle svakog poteza panel pokazuje nalaz za **novu** poziciju.
- [ ] Na telefonu je i dalje prozorčić i ništa se ne preliva na 360 dp.
- [ ] Klik na potez iz nalaza ga odigra na tabli; pojavi se čip „Istraživanje"
      i dugme „Nazad na poziciju".
- [ ] U tom režimu se pomera i protivnikova strana, potezi se ne broje kao
      greške, a panel prati novu poziciju.
- [ ] „Nazad na poziciju" vrati tačno položaj odakle se krenulo.
- [ ] Uz svaki potez piše ishod i DTZ; ispod stoji šta DTZ znači.
- [ ] Posle korišćenja se pojavi čip „Nalaz: n", i nestaje na sledećoj poziciji.
- [ ] U KRP–KR koje pređe u KR–KR pojavi se „Zaključi remi" i zatvori vežbu.
- [ ] U poziciji sa pešakom tog dugmeta nema.
- [ ] Kad remi nije mrtav, dugme kaže **koji potez** još gubi i postavi brojač
      „Do remija: 8"; posle osam održanih poteza vežba se zatvori sama.
- [ ] Ako se remi u međuvremenu ispusti, brojač nestaje i vežba staje kao i
      inače.
- [ ] Kad se pozicija ponovi tri puta, poruka kaže „ponovila se", a ne
      „pedeset poteza".

## 0j. „Zapamti za kasnije" — napisano 23.8.2026, nije viđeno uživo

Kad pozicija ostane nejasna i pored svih objašnjenja, dugme je sačuva u
biblioteku sa oznakom **„Nejasno"**, pa se kasnije otvori u Analysis Studiju.
Ne pravi novu tabelu — to je obična sačuvana pozicija.

- [ ] Dugme stoji **i pre i posle odgovora**, u treneru i u šetnji.
- [ ] Posle klika piše da je zapamćeno, dugme postaje „Zapamćeno" i ne može
      dvaput da sačuva istu poziciju.
- [ ] Sledeća pozicija vraća dugme u početno stanje.
- [ ] U „Mojim pozicijama" se pojavljuje sa oznakom **Nejasno**, a opis nosi
      kontekst: šta je odigrano, šta je držalo, pravilo, rejting, partija.
- [ ] Ista pozicija se otvara u Analysis Studiju iz biblioteke.
- [ ] Kad server ne odgovara, kaže se to i dugme ostaje aktivno.

## 0i. Kazna kao odgovor na „zašto" — napisano 23.8.2026, nije viđeno uživo

U šetnji, kad je greška iza tebe, dugme **„Zašto je loše"** odigrava na tabli
tablično najbolju kaznu za taj potez — jer razlog zbog kog je potez loš jeste
to što postoji konkretan način da se kazni.

- [ ] Dugme se pojavljuje **tek kad je greška odgovorena**, ne dok stojiš na
      njoj (tada bi bilo rešenje).
- [ ] Kazna se odigrava na tabli, potez po potez, iz pozicije **posle** greške.
- [ ] Traka za kretanje kroz partiju **nestaje** dok kazna traje — ona hoda
      partiju, a ovo nije partija.
- [ ] „Nazad na partiju" vraća tablu tačno tamo gde je bila.
- [ ] Ako tablica ne odgovara, kaže se to i tabla se ne dira.

## 0h. Zašto potez drži — napisano 23.8.2026, nije viđeno uživo

Posle tačnog odgovora (i posle „Pokaži") uz poruku stoji i rečenica o tome šta
je zajedničko svim potezima koji drže: „Top mora da ostane na G-liniji", „Drže
samo potezi kralja", „Drži samo uzimanje". Računa se na uređaju iz pozicije i
liste poteza, bez zahteva serveru.

- [ ] Rečenica se pojavljuje uz odgovor, i u treneru i u šetnji.
- [ ] **Ne pojavljuje se dok je pozicija otvorena** — pre odgovora bi bila
      nagoveštaj, i to jak.
- [ ] Kad drži samo jedan potez, ne piše „drže samo potezi kralja" (množina o
      jednom potezu), ali pravilo o liniji sme da stoji.
- [ ] Kod otprilike **polovine pozicija rečenice nema** — to je namerno, a ne
      kvar: ćutanje je bolje od izmišljene pouke.
- [ ] Ako je pozicija iz stvarne greške, rečenica bira ono pravilo koje je
      odigrani potez prekršio (npr. potez kralja kad drže samo topovi).

## 0g. Izbor završnica i nivoa — napisano 23.8.2026, nije viđeno uživo

AI Studio → „Dobij" ili „Održi remi" sada prvo otvara izbor, pa tek onda tablu.

- [ ] Otvara se sa **svim uključenim**, i „Počni" odmah radi kao ranije.
- [ ] Prva porodica je otvorena, ostale sklopljene; strelica ih otvara.
- [ ] Kvačica na porodici pali i gasi sve njene vrste; kad je deo izabran,
      kvačica je na crtici.
- [ ] Broj u dnu se menja **odmah** i tačan je — bez novog zahteva serveru.
- [ ] Izbor nivoa menja i broj u dnu i brojeve uz svaku vrstu.
- [ ] Kad se sve isključi, „Počni" je ugašen i piše da ništa ne odgovara.
- [ ] „Počni" sa sve uključenim daje isto ponašanje kao pre ovog ekrana.
- [ ] „Počni" sa uskim izborom (npr. samo `KRPvKR`) stvarno servira samo te
      pozicije — proveriti čip sa tipom na nekoliko uzastopnih.
- [ ] Prekidač „samo raznobojni lovci" se vidi (u zbirci ih je 43) i radi.
- [ ] Na 360 dp lista i donja traka staju bez prelivanja.

## 0f. Panel sa obaveštenjima — ✅ prošlo na desktopu 23.8.2026
Korisnik je 23.8.2026. prošao obe tačke na Windows verziji i sve navedeno radi,
uključujući i ono što je ispravljeno u tri kruga istog dana. **Na telefonu nije
gledano** — a to je jedina platforma na kojoj panel ide ispod table i na kojoj
se raspored može prelomiti, pa stavke sa 360 dp ostaju otvorene.

Sve što ekran ima da kaže stoji u jednom bloku, na sva tri ekrana završnica:
desno od table na širokom prozoru, ispod table na telefonu. Ranije je zadatak
bio iznad table a odgovor ispod, pa se za jednu vežbu gledalo na dva mesta.

- [ ] Na desktopu (prozor preko 840 dp): panel je **desno** od table, a zadatak,
      čipovi i odgovor su u njemu — iznad i ispod table nema teksta.
- [ ] Suzi prozor ispod 840 dp: panel pređe **ispod** table, i tabla se ne
      pomeri kad se odgovor pojavi ili nestane.
- [ ] Isto važi na sva tri ulaza: „Dobij", „Održi remi" i „Greške iz partija".
- [ ] Tabla je na širokom prozoru i dalje dovoljno velika — panel uzima 280 dp.
- [ ] Na 360 dp ništa ne izlazi iz ekrana ni u jednom od tri ekrana.

Ispravljeno posle prve probe na desktopu 23.8.2026, **nije viđeno uživo**:

- [ ] Panel je **uz tablu**, ne odgurnut na ivicu ekrana. Tabla se širi do 720 dp
      umesto do 560, a razmak do panela je 16 dp bez obzira na širinu prozora.
- [ ] Redosled u panelu: **partija gore, šta se traži ispod, odgovor na dnu**.
- [ ] U šetnji, kad stojiš između dve greške, naslov kaže **„Idite napred do
      sledeće greške"** i ispod piše koliko poteza — a dugme **„Na grešku" se
      pojavljuje**. Ranije se nije pojavljivalo nikad.
- [ ] Kad stojiš na grešci, piše **„Odigrajte na tabli potez koji drži remi"** —
      dakle šta da uradiš, ne samo šta se desilo.

Iz druge probe na desktopu 23.8.2026, **nije viđeno uživo**:

- [ ] Kad se stigne na grešku, **stara poruka „Tačno" nestaje**. Ranije je
      stajala ispod novog pitanja i čitala se kao odgovor na njega.
- [ ] Na grešci se **crvenom strelicom** označi potez koji je izgubio rezultat,
      i strelica se **sama skloni posle četiri sekunde** — pre nego što počneš
      da probaš poteze po tim istim poljima.
- [ ] Strelica se pojavi i kad se do greške dođe ručno, trakom.
- [ ] Kad se dođe do kraja partije: **„Kraj partije — nema više poteza"**, sa
      brojem nađenih.
- [ ] Ako je poslednja greška ujedno i poslednji potez, poruka to kaže, a ne
      nudi da se prolazi ostatak kog nema.

**Planirano, nije napravljeno:** zvuk za tačan i netačan potez. To je drugi
kanal za istu stvar — kad se čuje da li je potez prošao, ne mora ni da se gleda.

---

## 0a. Obaveštenja posle popravke — 17.8.2026, nije viđeno uživo

**Kako:** otvori zvonce na **oba** rasporeda — na Androidu je u zaglavlju, na
Windows-u je sada u levoj traci (`NavigationRail`), gde ga ranije nije bilo.

**Na šta obratiti pažnju:**

- Lista se otvara i kad među obaveštenjima ima onih **bez sobe** (zahtev za
  odnos, odbijanje). Do sada je to bio beo ekran.
- Pozivnica u sobu i dalje ima „Pridruži se" i ulazi u sobu; zahtev za odnos
  nema dugme nego uputstvo da se odgovara u tabu Prijatelji.
- **Značka broji nepročitana.** Posle otvaranja i čitanja broj mora da padne.
  Zatečeno stanje: jedno staro obaveštenje (#7) je odgovoreno pre popravke koja
  ih zatvara, pa će ostati nepročitano dok ga ne otvoriš.
- Na telefonu proveri i da se naslov dijaloga ne preliva.

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

## 8. Preimenovanje paketa

Aplikacija je sada `rs.pejovic.chesscoach`.

- [x] **Obrisana 20.8.2026** sa korisnikovog telefona (`adb uninstall
      com.example.chess_app`), pa je na uređaju ostala samo
      `rs.pejovic.chesscoach`. Istog dana je i ujela: otvorena je stara ikona,
      prijava je prošla, i aplikacija je izgledala kao prazan nalog — bez
      zadataka i bez trenera, jer se backend nije menjao a stara instalacija se
      ne ažurira. `build_and_deploy.ps1` od sada upozorava na nju posle svake
      instalacije, za slučaj da se pojavi na drugom uređaju. Stara se neće ažurirati,
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

## 12. Skener pozicija iz knjige — backend proveren uživo 19.8.2026, ekran nije

**Backend je stvarno pozvan**, ne samo testiran jedinično. Token mintovan istim
`JWT_SECRET`-om koji server koristi, pa ceo lanac preko HTTP-a:

- `POST /scans` sa pravim PDF-om od 5,4 MB, strane 32–51 uz rešenja 972–980 →
  **200 za 1,3 s**, 120 pozicija, nijedna sporna, font prepoznat kao
  `SkakNew-Diagram`. Prva: `#97` sa `Qf1#`, strana na potezu pročitana iz
  rešenja.
- `POST /scans/confirm` sa 3 ispravne pozicije i **jednom namerno pokvarenom** →
  201, sačuvano 3, odbijeno 1 uz razlog (`Invalid FEN: castling availability is
  invalid`). Dakle provera na serveru radi i ne propušta smeće.
- `GET /scans/puzzles` vratio tačno ta tri reda, sa temama i `needs_review`.
- Redovi napravljeni probom su posle obrisani; `custom_puzzles` je opet prazna.

**Nađeno pri toj probi i popravljeno istog dana.** Privremeni PDF se briše u
`finally` — ali `finally` se ne izvrši ako proces bude ubijen usred zahteva.
Nodemon koji se restartuje na snimanje fajla je dovoljan, i tako je i otkriveno:
kopija knjige od 5,4 MB ostala je da leži u `%TEMP%\chess-scans`. Sad se pri
pokretanju servera brišu svi zaostali `scan_*` fajlovi, uz upozorenje u dnevniku.
Provereno posle popravke: direktorijum je prazan odmah po skeniranju.

**Ekran je prošao uživo 19.8.2026.** Korisnik je skenirao `23.pdf`, strane
32–51, i potvrdio čuvanje: u bazi stoji **120 pozicija, svih 120 sa proverenim
rešenjem, nijedna obeležena kao sporna**. Time je usput potvrđeno i troje što je
ranije bilo nepoznato: `file_picker` na Windows-u **vraća putanju** za PDF, mreža
sa 120 dijagrama je upotrebljiva, i ulaz iz Biblioteke vodi gde treba.

**Nađeno pri toj probi:** pozicije su sačuvane, a korisnik nije imao gde da ih
vidi — ekran je čuvao u prazno. Dodato istog dana: `GET`/`DELETE
/scans/puzzles`, ekran „Moje pozicije" (mreža, filter po knjizi, brisanje,
dodir otvara poziciju na tabli za analizu), dugme u Biblioteci, i poruka posle
čuvanja koja sad nosi „Pogledaj".

**Drugo nađeno na slici, popravljeno istog dana:** pozicije su se prikazivale
redosledom upisa — `#97 #100 #98 #101 #99 #102`. Skener obilazi stranu po
položaju (prvo naniže, pa nadesno), a knjiga numeriše niz levu kolonu pa niz
desnu; uz to svih 120 redova deli isti `created_at`, pa sortiranje po vremenu
nije sortiranje. Sad se sortira po broju dijagrama, i to **kao broj a ne kao
tekst**, inače 100 dolazi pre 97. Provereno na živim podacima: 97, 98, 99, 100…

**Provereno uživo 19.8.2026, drugi krug.** Skeniranje bez odeljka sa rešenjima
(strane 45–64, sve „nepoznato"), preklapanje raspona, ekran „Moje pozicije",
pitanje „ko je na potezu" i otvaranje table za analizu sa tim FEN-om — sve
prošlo. Duplikati su se pojavili tačno kako je predviđeno, pa je pravilo
dopunjavanja ugrađeno i stari duplikati počišćeni (240 → 198).

**Skup je zatvoren 19.8.2026.** Posle drugog skeniranja sa rešenjima i ispravke
devet pozicija kojima je strana bila pogrešna: **198 pozicija, svih 198 sa
rešenjem koje stvarno igra i daje mat, nijedna obeležena, nijedna bez rešenja.**
Provereno upitom nad bazom, a ne na oko.

## 13. Zadavanje skeniranih pozicija učeniku — ✅ ceo lanac prošao uživo 19.8.2026

Knjiga → skener → potvrda → zadatak → dete → ocena → napredak, sa dva naloga i
prihvaćenim odnosom trener–učenik.

Potvrđeno okom: izbor pozicija dugim pritiskom, zadavanje učeniku, učenikov ekran
sa zadatkom u okviru („Beli matira u jednom potezu."), tabla okrenuta ka strani na
potezu, ocena posle poteza, **„Mat u 333: 2/2 urađeno, tačnost 100%"**, napredak
prešao sa 0/4 na 1/4, i izveštaj za roditelja sa ispravno razdvojenim temama.

**Tri greške nađene baš tom probom, sve popravljene istog dana:**

1. **Potez deteta nije radio ništa, bez ijedne poruke.** `move_to_san` mora da se
   pita pre nego što je potez odigran; pozvan posle, puca. Izuzetak u `async`
   rukovaocu otišao je u prazno.
2. **Tabla nikad nije prijavljivala matirajući potez.** Pitala je koliko poteza
   *preostaje* i nulu čitala kao „ništa nije odigrano" — a mat je tačan odgovor u
   svih 198 pozicija. Pogađa i živu sesiju: mat se nije emitovao drugoj strani.
3. **Izveštaj je istu temu zvao i jakom i slabom**, jer su obe liste bile krajevi
   istog niza.

Ostalo iz ovog lanca — čekirano 20.8.2026. kroz probu u stavkama 14–17:

- [ ] **Da li se drugi mat priznaje.** Najlakše na #122 (knjiga `Qe6#`, ali i
      `Qh7#` matira) — očekuje se „Tačno" i objašnjenje „Drugi mat od onog u
      knjizi". Logika je pokrivena testovima, ali okom nije viđena.
- [x] Šta se prikaže posle **netačnog** odgovora (rešenje se otkriva tek tada).
- [x] **Zadatak u lekciji kod učenika** — uokvireni tekst iznad table u
      `lesson_viewer_screen`. Traži zadatu lekciju sa upisanim zadatkom po koraku.
- [ ] Da li se traka „nema veze sa serverom" sama povuče kad server krene
      (ponavlja proveru na 10 s, a povezivanje socketa je računa kao dokaz).
- [x] **Odigran potez se upisuje** (`assignment_items.played_san`, 20.8.2026).
      Kolona se dodaje pri pokretanju servera — u dnevniku mora da stoji
      `Verified database table & indexes: assignment_items`. Pusti dete da
      odgovori na jednu poziciju, tačno i netačno, pa proveri:

      ```sql
      SELECT puzzle_id, solved, played_san FROM assignment_items
       WHERE assignment_id = <id> ORDER BY position;
      ```

      Očekuje se potez u notaciji za oba reda. `NULL` posle stvarnog odgovora
      znači da tabla nije umela da odigra ono što je klijent poslao — u tom
      slučaju u dnevniku stoji `Custom attempt could not be resolved to a move`
      i to je stvarno neslaganje, ne kozmetika. Redovi odgovoreni pre 20.8.2026.
      ostaju prazni i to je ispravno.

---

Ostalo neprovereno:

- [ ] Knjiga sa **drugim fontom** — mapa za `TacticsCourse.pdf` nije završena,
      pa je sve mereno na jednoj knjizi.
- [ ] Šta se dešava kad se pošalje PDF **bez ijednog dijagrama** ili zaštićen
      lozinkom.
- [ ] Filter „traži pogled" nad **mešanim** skupom — dosad je bio ili 0/120 ili
      120/120, nikad delimičan.

Napomena: `custom_puzzles` je nastala pri restartu 19.8.2026
(`Verified database table & indexes: custom_puzzles`), pa taj korak više ne
stoji na putu.

## 14. Biblioteka pozicija i „Dodaj u lekciju" — ✅ provereno uživo 20.8.2026

Backend je pozvan preko HTTP-a (203 stavke iz tri izvora, dopisivanje koraka
201, tri odbijanja svako sa svojim razlogom, probna lekcija obrisana), a
**korisnik je 20.8.2026. prošao i ekrane**: birač sa sve tri police, skenirana
pozicija ušla u lekciju sa svojim zadatkom, korak bez zadatka narandžast,
„Dodaj u lekciju" nad više izabranih pozicija.

Ostalo je neprovereno samo ponašanje kad je **server ugašen** — jedino
stanje koje ova proba nije dodirnula.

**Kako:** Sesija → „Kreiraj lekciju" → **Dodaj iz biblioteke**. Pa Biblioteka →
„Moje pozicije" → dugi pritisak na jednu ili više → **Dodaj u lekciju**.

**Na šta obratiti pažnju:**

- [x] U biraču se vide **sve tri vrste** — iz knjige, sačuvane pozicije, analize
      — i čipovi ih filtriraju.
- [x] **Skenirana pozicija zaista uđe u lekciju** i u koraku piše njen zadatak
      („Beli matira u jednom potezu."), ne samo naslov.
- [x] Kad se doda **analiza**, korak nosi varijante (PGN), a ne samo početnu
      tablu. Ako učitavanje stabla ne uspe, mora da stigne poruka i pozicija —
      ne tiho preskakanje.
- [x] Traženje po tekstu radi (kuca se, pa se posle kratke pauze osvežava lista).
- [ ] Kad je server ugašen, birač kaže **„Nije moguće doći do servera"**, a ne
      „Nema sačuvanih pozicija".
- [x] „Dodaj u lekciju" nad **više izabranih** pozicija: poruka mora da kaže i
      koliko je dodato i koliko nije.
- [x] Na telefonu traka sa tri dugmeta („Poništi", „Dodaj u lekciju", „Zadaj
      učeniku") mora da se prelomi, ne da iscuri sa ekrana.

## 20. Jedna traka za kretanje kroz poteze — 20.8.2026, nije viđeno uživo

Faza 2 unifikacije. Šest zasebnih redova dugmadi `<< < > >>` zamenjeno je
jednim, preko `MoveCursor` adaptera. Server nije menjan; ovo je čisto klijentska
izmena. Objašnjenje je u [STANJE-RADA.md](STANJE-RADA.md), odeljak o
unifikaciji.

**Kako:** proći kroz svih šest mesta. Svugde ista dugmad, isti raspored, isti
oblačići sa nazivima.

**Na šta obratiti pažnju:**

- [ ] **Lekcija u sobi** (kao trener) — traka radi kao pre, a kad učenik nema
      pravo da vodi tablu, dugmad su siva i ne rade.
- [ ] **AI Studio** — čipovi sa potezima i dalje stoje iznad dugmadi. Novo:
      kad si na početku, čip „Početak" je **označen** (ranije nikad nije bio).
- [ ] **Pregled zadate lekcije** (kao učenik, korak sa linijom poteza) — brojač
      „Potez 3 od 12" se **preselio iznad dugmadi u sam red**, između `<` i `>`.
      Traka je sada u kartici, kao na ostalim ekranima.
- [ ] **Ponavljanje u razmacima** — posle „Prikaži nastavak" traka izgleda isto
      kao svugde i **ima dugme za okretanje table**, kog ranije nije bilo.
- [ ] Okreni tablu u ponavljanju: tekst iznad table i dalje kaže tačno ko je na
      potezu. Ne sme da se promeni sa okretanjem.
- [ ] **Analysis Studio** — traka je sada svetla (`cardColor`), ne tamnosiva.
      Dugmad za komentar, AI komentar, NAG i brisanje stoje na istom mestu, u
      istom redu, i rade.
- [ ] U Analysis Studio-u uđi u varijantu pa pritisni `<<`: mora da te vrati na
      **mesto gde se varijanta odvojila**, a ne na prvi potez partije.
- [ ] **Dijalog sa linijom motora** (Analysis Studio → klik na liniju) — dugmad
      su sada `<` i `>` kao svugde (ranije druge ikone), brojač `3 / 8` stoji
      između njih, okretanje table na kraju reda.
- [x] Na telefonu se nijedna traka ne preliva — naročito „Potez 12 od 24" u
      pregledu lekcije, gde je natpis najduži.

**Provereno na telefonu 20.8.2026** (Analysis Studio i tabla u sobi). Pri tome
su nađene tri greške koje su odmah popravljene — sve tri **nevidljive u release
build-u**, gde Flutter ne crta prugasto upozorenje o prelivu niti išta upisuje u
log:

- Traka je imala devet dugmadi u jednom redu. Devet × 48 dp = 432 dp, a telefon
  ima 360–410, pa su **NAG i brisanje poteza bili van ekrana**. Sad je `Wrap`,
  pa se prelama u drugi red. Test u `move_cursor_test.dart` pada na starom
  `Row`-u — provereno vraćanjem.
- Gornji red u Analysis Studio-u je imao devet radnji, a `AppBar` ih ne prelama
  nego **seče**: „Podešavanja" i „Unos Pozicije / PGN" nisu bili dohvatljivi. Dve
  ostaju na traci, ostatak je u meniju sa tri tačke, i to samo na uskom ekranu.
- „Vraćena je vaša poslednja analiza." je snackbar od šest sekundi koji na tom
  telefonu stoji minutima. Dobio je **✕**; šta god zaustavlja tajmer, poruka bez
  izlaza je greška sama po sebi.

- [x] Analysis Studio na telefonu: svih devet dugmadi trake se vidi, u dva reda.
- [x] Gornji red: naslov se vidi ceo, a „Podešavanja" je u meniju sa tri tačke.
- [x] Baner o vraćenoj analizi se gasi na ✕.

## 21. Obaveštenja stižu dok je aplikacija otvorena — 20.8.2026, nije viđeno uživo

Rupa nađena pri proveri stavke 19, pa proširena: `accept` sada šalje
obaveštenje, zadaci i pregledi ga uopšte nisu slali, a sve zajedno gura drugu
stranu preko soketa umesto da čeka sledeće pokretanje. **Backend je menjan** —
mora se restartovati (`npm run dev`).

**Kako:** opet treba drugi nalog, i oba treba da budu **otvorena u isto vreme**,
jer se baš to proverava.

**Na šta obratiti pažnju:**

- [x] A pošalje zahtev dok B stoji u aplikaciji: **B-ova značka poraste sama**,
      bez restarta i bez izlaska iz taba. *(2 → 3, gledano na telefonu.)*
- [x] B prihvati dok A **stoji u tabu Prijatelji**: A-ov red se sam pretvori iz
      „čeka potvrdu" u običan odnos. Ovo je ono što je prijavljeno.
- [x] A dobije obaveštenje „<ime> je prihvatio vaš zahtev." sa ikonom rukovanja.
- [ ] Odbijanje i dalje radi isto, i sad se takođe vidi odmah.
- [ ] Ugasi aplikaciju kod A, pa neka B odgovori, pa je upali: obaveštenje je
      tu. Soket je samo gurac, red u bazi je ono što se pamti.
- [ ] Restartuj backend dok su oba naloga otvorena, pa odgovori na zahtev:
      ništa ne puca, a posle ponovnog povezivanja gurac opet radi.

**Drugi deo — zadaci i pregledi.** Za ovo trener i učenik treba da budu otvoreni
u isto vreme, na dva naloga. Koristi neki **nov** odnos, ne `pavle → Vladan`.

- [x] Trener zada domaći sa zagonetkama → **učeniku poraste značka odmah**, i u
      zvoncetu piše „<ime> vam je zadao: <naslov>" sa ikonom zadatka.
- [ ] Isto i za zadatak od trenerovih **skeniranih pozicija**, i za **lekciju**.
- [x] Učenik uradi **poslednju** stavku zadatka → **treneru** stigne „<ime> je
      uradio zadatak: <naslov>".
- [ ] Učenik ponovo otvori taj isti, već gotov zadatak i prošeta kroz njega →
      **ne stiže drugo obaveštenje**. Sme da bude tačno jedno.
- [x] Učenik napiše poruku u „Pregled i komentari" → **treneru** stigne „<ime>
      je napisao poruku o zadatku: <naslov>". *(Smer trener → učenik nije
      posebno gledan; ista ruta, ista funkcija.)*
- [ ] Poziv na čas i zakazan čas i dalje rade, i sada takođe stižu odmah.
- [ ] Ono što se **ne** očekuje: učenik koji stoji u „Moji zadaci" neće videti
      nov zadatak u spisku dok se ne vrati na njega. Zvonce hoće. To je poznato
      i zapisano.

**Nađeno pri proveri 20.8.2026, popravljeno istog dana:** kod zadatka od
lekcije sačuvane kao jedna pozicija, „Pregled i komentari" je pokazivao prazan
kvadrat umesto table. Vidi „Koraci lekcije su se čitali na četiri načina" u
[STANJE-RADA.md](STANJE-RADA.md).

- [ ] Otvori taj isti pregled ponovo — tabla se sada vidi, a naslov je naziv
      pozicije umesto „Pozicija 1". (Backend je restartovan sam, ne treba ništa.)
- [ ] Lekcija sa **više** koraka i dalje pokazuje svoj korak, ne svoju prvu
      poziciju.

## Značka je stajala i posle čitanja — nađeno i popravljeno 20.8.2026

Korisnik je primetio da zvonce i dalje pokazuje 3 pošto je sve pročitao. Broj je
bio tačan (1 neodgovoren zahtev + 2 nepročitana obaveštenja), ali se **ništa
nikad nije označavalo kao pročitano**: jedino je poziv u sobu dobijao `is_read`,
i to tek kad se na njega pridruži. Sve ostale vrste su ostajale nepročitane
zauvek, pa broj nije mogao da padne.

Sad otvaranje zvonca označava ono što prikazuje (`POST /notifications/read`).
Zahtev koji čeka odgovor time nije dirnut — on se broji iz
`/relationships/pending`, ne iz svog obaveštenja, i baš zato je bezbedno
označiti sve pročitanim. Test čita rutu i pada ako ikad dodirne
`trainer_students`.

- [x] Otvori zvonce, zatvori ga: **značka padne** na broj neodgovorenih zahteva.
      *(Telefon: 3 → nema značke. Windows: 5 → 0. Oba uz 0 zahteva na čekanju.)*
- [x] Redovi koji su bili podebljani sada stoje sivi, sa „Odgovoreno." gde
      treba.
- [x] Iznad liste piše od čega je broj sastavljen. *(Windows, 20.8.2026:
      „5 novih obaveštenja".)* Ovo je nastalo iz zapažanja korisnika da ga je
      broj prevario — sabira nepročitane poruke i neodgovorene zahteve, a
      zahtev se broji dok se ne **odgovori**, ne dok se ne pročita.
- [ ] Sa **jednim neodgovorenim zahtevom**: posle čitanja značka treba da
      pokazuje 1, a rečenica da glasi „1 zahtev čeka vaš odgovor". Aritmetika je
      potvrđena sa obe strane (3 = 1 zahtev + 2 nepročitana, pa 5 = 0 + 5), ali
      tačno ta kombinacija nije viđena. Ne vredi je praviti namerno — videće se
      prvi put kad neko pošalje zahtev.

## 26. Slova u treneru završnica i razmak u reprodukciji — 24.8.2026, nije viđeno uživo

Poslednja stavka iz dogovorenog spiska prečica. Pravilo je isto svuda: **taster
pritiska dugme koje je u tom trenutku na ekranu**, i ne radi ništa kad tog
dugmeta nema ili je ugašeno.

Trener završnica (Windows, AI Studio → „Završnice iz majstorskih partija"):

- [ ] **N** — sledeća pozicija, isto što i dugme „Sledeća" / „Preskoči". Radi
      **odmah po otvaranju ekrana**, bez ijednog klika pre toga.
- [ ] **H** — pomoć; poruka kaže na koje polje potez vodi. Kad je pozicija
      rešena, dugmeta „Pomoć" nema — pa ni **H** ne sme ništa da uradi.
- [ ] **R** — „Pokušaj ponovo" posle netačnog poteza; u igranju do kraja
      „Ispočetka". Kad tog dugmeta nema, taster ćuti.
- [ ] **T** — „Nalaz tablica", i to samo dok se pozicija igra do kraja. Na
      širokom prozoru drugi pritisak zatvara panel, isto što i „Sakrij nalaz".
- [ ] **U** — „Vrati potez", i to tek pošto je neki potez ispustio rezultat.
- [ ] Dok tablica odgovara (tabla je zaključana), N, R i U ne rade — isto kao
      što su i dugmad tada ugašena.

Reprodukcija snimka (ekran sa snimljenim časom):

- [ ] **Razmak** pušta i pauzira snimak, isto što i dugme ispod table.
- [ ] Kliknuti prvo na neko dugme na tom ekranu, pa pritisnuti razmak: razmak
      tada pripada **tom dugmetu**. Ovo je namerno — ko šeta ekran Tab-om mora
      da može da pritisne ono na čemu je stao.

Ovo poslednje je jedino mesto gde prečica namerno ustupa taster, pa je vredno
videti oba slučaja.

## 28. Znak ocene u onlajn motoru — 24.8.2026, nije viđeno uživo

Popravka nađena pri izradi sudije: Lichess-ova oblačna ocena je iz ugla belog, a
aplikacija ju je obrtala za pozicije sa crnim na potezu. Za nativni motor
obrtanje ostaje ispravno, pa se proverava da se dva izvora sada slažu.

- [ ] Analiza, pozicija sa **crnim na potezu** u kojoj beli stoji bolje (npr.
      posle 1.e4 e5 2.Nf3 Nc6 3.Bb5): sa **onlajn** motorom ocena je pozitivna,
      kao i sa nativnim. Ranije je bila negativna.
- [ ] Ista pozicija, prebaciti motor sa onlajn na nativni i nazad: broj se ne
      prevrće oko nule.
- [ ] Pozicija sa matom za crnog i crnim na potezu (1.f3 e5 2.g4): onlajn motor
      piše mat za **crnog** (`-M1`), ne za belog.

## 29. Repertoar — režim izgradnje, 24.8.2026, nije viđeno uživo

Trening → „Repertoar otvaranja". Traži **vaš** Lichess token (isti kao sudija) i
pokrenut backend. Baza pravi tri nove tabele pri pokretanju servera.

Pravljenje (izmenjeno 25.8.2026 — pozicija se postavlja na tabli):

- [ ] „Novi" otvara ekran sa tablom. Odigrati otvaranje potezima, na primer
      `1.e4 c5 2.d4 cxd4 3.c3 dxc3 4.Nxc3`; linija se ispisuje ispod table.
- [ ] Ime se **samo predloži** iz baze otvaranja (npr. „Sicilian Defense — crni"); dovoljno je pritisnuti „Napravi". Kad se ime otkuca ručno, predlog ga više ne menja.
- [ ] „Nađi otvaranje" → ukucati „Smith-Morra": klik na rezultat postavi celu liniju na tablu, izabere stranu koja je na potezu i predloži ime. Ista pretraga koja je u Analizi.
- [ ] „Nazad" vraća jedan potez, „Ispočetka" celu liniju.
- [ ] Dugme „Napravi" je **ugašeno** dok na potezu nije strana za koju se gradi,
      a rečenica iznad kaže čiji je potez. Promena strane ga oživi.
- [ ] „Nalepi FEN" postavlja poziciju iz niza; neispravan niz kaže da nije
      ispravan, a ne „nije sačuvano".
- [ ] Dok je ime prazno, dugme je ugašeno **i ispod table piše zašto** („Upišite ime repertoara.“).
      Nađeno pri prvoj upotrebi: pozicija je bila u redu, red ispod table zelen, a dugme sivo bez ijedne reči.
- [ ] Na širokom prozoru polje za ime stoji uz tablu, a ne razvučeno preko celog ekrana.
- [ ] Napravljen repertoar se odmah otvara; ime stoji u naslovu.
- [ ] Isto ime drugi put → **„Već imate repertoar sa tim imenom."**
- [ ] Ugašen backend → **„Server nije dostupan — proverite da li backend radi."**
      Tri uzroka, tri rečenice; ovo je bila greška nađena pri prvoj upotrebi.

Petlja (probati sa Smit-Morom: `1.e4 c5 2.d4 cxd4 3.c3 dxc3 4.Nxc3`, crni):

- [ ] Tabla je okrenuta prema izabranoj boji, a pitanje glasi „Šta igrate
      crnim?".
- [ ] Odigran potez se **odmah** sudi; brojač u uglu poraste za jedan.
- [ ] „Uzmi" ga dodaje kao čip sa zvezdicom (glavni). Drugi uzet potez dobija
      praznu zvezdicu — klik na njega ga postavlja za glavnog.
- [ ] „Odbaci" ga ne dodaje, ali ga zabeleži: to se vidi kasnije u drillu, a
      sada bar ne sme ništa da padne.
- [ ] **Čim se potez odigra, spisak „Šta se ovde igra" iskoči sam**, sa procentom partija i procentom učinka za stranu na potezu; potez koji ste upravo odigrali je označen strelicom, a već uzeti zvezdicom.
- [ ] „Ne znam" pokaže isti spisak **pre** odluke — i samo se to broji kao rešeno gledanjem.
- [ ] **Rokada:** odigrati O-O i proveriti da je u spisku označena kao vaš potez (strelica), a ne da piše „nije među ovim potezima". Isto i u panelu Analize: klik na „O-O" u bazi otvaranja odigra rokadu.
- [ ] „Pitaj motor" daje linije na izabranoj **dubini** i u izabranom **broju linija**; obe kontrole su u panelu. Klik na liniju odigra njen prvi potez i on prolazi kroz isti sud kao potez odigran rukom.
- [ ] Motor radi i kad Lichess token nije unet — lokalni je i ne troši kvotu.
- [ ] **Promena dubine odmah ponovo pokreće motor** (ne ostaje stari odgovor). Isto i promena broja linija.
- [ ] **Pitati motor na dubini 28, pa preći na sledeću poziciju pre nego što odgovori:** stari odgovor se ne sme pojaviti u novoj poziciji. Ovo je bila greška nađena na slici — motor je nudio potez koji u novoj poziciji nije ni moguć.
- [ ] Uzeti drugi potez u istoj poziciji pa dodirnuti red sa njim: postaje glavni (zvezdica se pomeri). To je ono što će drill tražiti.
- [ ] „Dalje" otvara odgovore belog i javlja koliko je pokriveno i koliko je
      poteza ostalo van toga; sledeća pozicija je opet sa crnim na potezu.
- [ ] Kad se red isprazni, ekran to kaže i **zadrži** poslednji izveštaj o
      pokrivenosti.

Ono što se lako previdi:

- [ ] Isti potez uzet dvaput ne pravi duplikat.
- [ ] Zatvaranje i ponovno otvaranje repertoara: izabrani potezi su tu (red
      pozicija nije — to je namerno).
- [ ] Na telefonu 360 dp: tabla i dugmad staju bez sečenja.

## 30. Repertoar — drill, 24.8.2026, nije viđeno uživo

Trening → „Repertoar otvaranja" → dugme sa tegom na kartici. **Ne troši token**,
pa radi i kad je kvota potrošena — to je i deo provere.

- [ ] Pre vežbe izgraditi bar tri-četiri pozicije, inače drill nema šta da pita
      („Još nema šta da se vežba." je tačan ekran, ali nije ono što se
      proverava).
- [ ] Pitanje dolazi **bez odgovora**: nigde na ekranu ne piše koji je potez
      izabran dok se ne odigra ili ne pritisne „Pokaži".
- [ ] Tačan potez → „Tačno" i rečenica kad se pozicija vraća.
- [ ] Alternativa koju ste sami uzeli → „I to je vaše", uz ime glavnog poteza.
- [ ] **Dobar potez koji nije vaš** (npr. potpuno zdrav razvojni potez koji
      niste uzeli) → „Nije to", uz vaš potez. Ovo je namerno i vredi videti.
- [ ] „Pokaži" pa zatim tačan potez → i dalje prolaz, ali se pozicija vraća
      ranije nego kad se pogodi iz glave.
- [ ] Protivnik odgovori sam, i ponekad odgovori nešto što niste pokrili — tada
      to piše žutim („to niste pokrili").
- [ ] „Nastavi liniju" nastavlja iz pozicije u kojoj se stalo.
- [ ] Kad se dođe do pozicije koju niste gradili: „Ovu poziciju niste pokrili" i
      dugme „Izgradi ovu poziciju" otvara izgradnju **baš tu**, ne od početka.
- [ ] Posle nekoliko odgovora, brojač „na redu / novo" u naslovu se menja.
- [ ] Isključiti internet i vežbati dalje — pitanja i ocene rade, jer je sve
      naše; padne samo ako backend nije dostupan.
- [ ] Na telefonu 360 dp: tabla, poruka i tri dugmeta staju bez sečenja.

## Baza ispražnjena 25.8.2026 — pre stavki 31–37

Svi nalozi i sve što su napravili obrisani su namerno, da se stavke 31–37
proveravaju nad onim što će stvarno postojati kad aplikacija izađe. Uvezene
zagonetke i završnice su ostale.

**Postavka dogovorena 25.8.2026** — tri sopstvene adrese, po jedna na nalog.
Koje su tačno ne piše ovde: repozitorijum je javan, a adresa je lični podatak i
kad je tvoja.

| uređaj | nalog | godište | uloga |
|---|---|---|---|
| Windows | adresa A | *punoletno* | trener |
| telefon | adresa B | 2014 → **11** | učenik, maloletan |
| telefon | adresa V | 2002 → **23** | učenik, punoletan |

Punoletan učenik je najvažniji nalog na spisku: on je kontrola koja pokazuje da
saglasnost i zabrana snimanja **ne** pogađaju sve. Bez njega stavke 36 i 37
pokazuju samo da nešto blokira.

Treneru pri prvom pokretanju takođe stiže pitanje za godinu — **unese
punoletno godište**, jer ga inače `ageService.mayRelate` odbija kao trenera.

Ono što ova postavka **ne** pokriva, i kako se zaobilazi:

* **Dva maloletnika** (stavka 33, „u oba smera odbijeno") — nema drugog deteta.
  Privremeno prebaciti punoletnog učenika na 2014 kroz Podešavanja → Godina
  rođenja, uraditi proveru, pa vratiti na 2002. Time se usput proverava i da
  ispravka godine radi (stavka 35).
* **Dva učenika istovremeno u sobi** — oba su na istom telefonu. Nijedna stavka
  to ne traži: snimanje u stavci 37 kreće dok je trener sam, pa dete ulazi.
  Ostalo ide u dva prolaza, sa odjavom između.
* **Gost** (stavke 31 i 32) ne traži nalog — odjavljena aplikacija *jeste* gost.

Pre prve provere:

- [ ] Registrovati nalog **trenera** i nalog **deteta** (SMTP radi lokalno, pa
      kodovi za verifikaciju stvarno stižu).
- [ ] **Odjaviti se na svakom uređaju pre registracije**, ili obrisati podatke
      aplikacije. Zapamćen token starog naloga i dalje stoji u telefonu, a
      `RESTART IDENTITY` znači da će peti novi nalog dobiti ID 5 — server ga
      sada odbija (`account-gone`), ali aplikacija bi do prve provere izgledala
      prijavljeno.
- [ ] Ako treba admin: `UPDATE users SET role = 'admin' WHERE email = ...`.
      Bootstrap-a nema, i to je jedini put. Uloga se od 25.8.2026 čita **iz
      reda**, ne iz tokena, pa važi odmah — bez ponovne prijave.
- [ ] Za stavku 36 podesiti `PUBLIC_BASE_URL` u `chess_backend/.env`.

Ono što je već potvrđeno uživo pre pražnjenja (stavka 34 u celini, i deo stavki
33 i 35) **ostaje potvrđeno** — kod se od tada nije menjao osim popravke fokusa u
age gate-u. Nove naloge treba iskoristiti za ono što još nije viđeno.

## 31. Soba sa spiskom zvanica i grupe — 25.8.2026, nije viđeno uživo

Backend je napisan, ekrana za grupe još nema — proverava se ono što se vidi kroz
postojeći tok. Treba dva naloga (trener i učenik) i pokrenut backend.

- [ ] Trener napravi sobu, učenik sa **prihvaćenom vezom** uđe kodom — radi kao
      i pre.
- [ ] Nalog **bez veze** sa trenerom uđe istim kodom → poruka „Niste na spisku
      za ovu sobu" i vraćanje nazad, a ne večno „povezivanje".
- [ ] **Neprijavljen gost** sa kodom → „Ova soba ne prima goste". (Ranije je
      ulazio i u tablu i u glas.)
- [ ] Nepostojeći kod → „Ne postoji soba sa tim kodom".
- [ ] U dnevniku backenda za svako odbijanje stoji `[SOBA] Odbijen ulazak` ili
      `[AUDIO] Odbijen ulazak` sa razlogom.
- [ ] Glas: odbijeni nalog ne može da uđe ni u glas ni kad pokuša direktno.

Grupe i spisak zvanica (ekrani napisani 25.8.2026):

- [ ] „Ljudi" → dugme sa grupama otvara ekran; napraviti grupu, preimenovati je, dodati dva učenika, izbaciti jednog.
- [ ] U biraču se nude **samo prihvaćeni** učenici — onaj koji nije potvrdio vezu se ne pojavljuje.
- [ ] Nigde u tim spiskovima ne stoji tuđ email.
- [ ] U sobi, trener → „Ko sme u sobu": prazan spisak kaže da soba prima sve njegove učenike.
- [ ] Pozvati **celu grupu** jednim klikom; poruka se promeni u „Ulaze samo oni sa ovog spiska".
- [ ] Učenik **iz te grupe** uđe kodom; učenik istog trenera **van grupe** dobije „Niste na spisku za ovu sobu".
- [ ] Pozvati i **jednog** učenika poimence — ulazi i on.
- [ ] Skinuti grupu sa spiska: kad spisak ostane prazan, soba se opet otvara svim učenicima tog trenera.

Uz to, sitno ali vidljivo:

- [ ] U tabu „Ljudi" i u biračima učenika **više ne piše tuđ email** — stoji
      ime i šta je taj red („Čeka potvrdu", „Vaš učenik"). Polje za pozivanje po
      email-u i dalje postoji i radi.

## 32. Prekidač „soba prima goste" — 25.8.2026, nije viđeno uživo

Kolona `rooms.allow_guests` je postojala od prvog dana spiska zvanica, ali je
nije bilo nigde u aplikaciji — pravilo koje niko ne vidi je pravilo na koje niko
ne može da se osloni. Sad je u dijalogu „Ko sme u sobu", ispod spiska.

Treba trener, jedan nalog **bez veze** sa njim i jedan neprijavljen uređaj
(dovoljno je odjaviti se).

- [ ] Trener → „Ko sme u sobu": pri dnu stoji prekidač **Soba prima goste**,
      **isključen**, uz rečenicu „ulaze samo prijavljeni koje ste pozvali".
- [ ] Uključiti ga: tekst se menja u onaj koji kaže da ulazi **svako ko zna kod**
      i da je i to u snimku, a pri vrhu dijaloga se pojavi upozorenje.
- [ ] Zatvoriti i ponovo otvoriti dijalog — prekidač je i dalje uključen (dakle
      sačuvan u bazi, a ne samo na ekranu).
- [ ] Dok je uključen: **neprijavljen** gost sa kodom ulazi i vidi tablu; u
      dnevniku backenda stoji `[SOBA] … gosti dozvoljeni`.
- [ ] Dok je uključen: **prijavljen nalog bez veze** sa trenerom takođe ulazi —
      i to kao *gost*, ne kao učenik (ne pomera figure). Ranije je bio odbijen,
      dok je neprijavljeni stranac ulazio; to je bilo naopako.
- [ ] Isključiti ga: oba ta naloga se odbijaju, sa porukom, bez večnog
      „povezivanje…".
- [ ] Sa **spiskom zvanica** i uključenim prekidačem: učenik van spiska ulazi kao
      gost, a ne kao učenik. Dijalog to i kaže („bez obzira na spisak") — spisak
      bira ko je *učenik* u sobi, prekidač da li iko sme da gleda.
- [ ] Ugasiti backend i otvoriti dijalog: umesto isključenog prekidača stoji
      „Ne znam da li soba prima goste" i dugme *Pokušaj ponovo*. (Isključen
      prekidač bi ovde bio laž o tome ko sme unutra.)

## 33. Maloletnik ima samo trenera — pravilo o godinama ✅ provereno uživo 25.8.2026

**Potvrđeno 25.8.2026, nad ispražnjenom bazom i nalozima napravljenim iznova.**
Pravilo drži na **oba** mesta u kodu — i pri slanju i pri prihvatanju — i oba su
proverena zasebno, jer su to dve različite funkcije. Ostaje deo o zakazivanju i
pozivima, niže.

Usput nađeno: prva tri pokušaja slanja nisu ni stigla do pravila o godinama —
zaustavile su ih ranije ograde („zahtev u suprotnom smeru već čeka", „zahtev
već stoji"). Da bi se pravilo uopšte dotaklo, par mora da bude bez ijednog
zatečenog reda.

**Pažnja pri proveri:** dok se ne napravi age gate, nijedan nalog nema upisanu
godinu rođenja, pa pravilo ne odbija nikoga. Da bi se videlo kako radi, godina
se za sada upisuje ručno u bazi:

```sql
UPDATE users SET birth_year = 2014 WHERE email = 'dete@primer.rs';
```

- [x] Nalog sa `birth_year` koji ga čini maloletnim pošalje zahtev kao **trener**
      → odbijeno, uz poruku „Maloletnik ne može da bude trener".
      **Potvrđeno uživo 25.8.2026**, sa godinom unetom kroz age gate umesto
      ručno u bazi. Posle odbijanja: `trainer_students` i `friends` **prazni**.
- [ ] Isti taj nalog pošalje zahtev kao **učenik** punoletnom treneru → prolazi
      normalno.
- [x] Zahtev poslat **pre** upisa godine, pa tek onda upisana godina maloletnika
      na stranu trenera: prihvatanje se odbija istom porukom. (Ovo je stvarni
      slučaj — svi postojeći zahtevi su poslati dok se za godine nije ni
      pitalo.) **Potvrđeno 25.8.2026 sa obe strane** — i kod deteta na telefonu
      i kod punoletnog trenera na Windows-u; zahtev je posle odbijanja ostao
      `pending`, nije ni nestao ni postao veza.
- [x] Dva maloletna naloga, u oba smera → oba puta odbijeno. **Potvrđeno
      25.8.2026.** Drugi smer je onaj koji nešto dokazuje: dete koje šalje
      „ja sam učenik" drugom detetu je odbijeno zato što bi **primalac** bio
      trener — pravilo gleda ko predaje, ne ko je poslao.
- [ ] `AGE_OF_CONSENT=20` u `.env` → **server ne startuje**, uz jasnu poruku u
      dnevniku. (Tiho vraćanje na 16 bi bilo pravilo o deci koje ćutke prestane
      da važi.) Vratiti na 16 posle provere.

Prijatelji i pozivi:

- [x] `POST /friends/add` više ne postoji — provera se radi ručno (curl ili
      Postman): odgovor je **404**, ne 200. Isto i `DELETE /friends/:id`.
      **Provereno 25.8.2026:** obe rute 404, a `GET /friends` i dalje 200 —
      čitanje je ostalo, pisanje bez pristanka nije.
- [ ] U aplikaciji se ništa nije promenilo: tab „Ljudi" radi kao pre, jer tu
      rutu nikad nije ni zvao.
- [ ] Zakazivanje časa u **tuđoj** sobi (curl, sa kodom sobe drugog trenera) →
      **403**, i taj nalog i dalje ne može da uđe u tu sobu.
- [ ] Poziv (`POST /invitations/send`) nekome ko nije u prihvaćenoj vezi →
      **403**, i toj osobi ne stiže zvonce.

## 35. Age gate — pitanje za godinu rođenja, 25.8.2026, nije viđeno uživo

Ovo je ono što stavkama 33 i 34 daje zube: dok nijedan nalog nema `birth_year`,
pravilo „maloletnik nije trener" i početni nivo glasa ne odbijaju nikoga.

Pre provere obrisati upisano, da se vidi stanje u kom je danas svaki nalog:

```sql
UPDATE users SET birth_year = NULL, birth_year_stated_at = NULL WHERE id = ...;
```

- [x] **Postojeći nalog**, prijavljen zapamćenim tokenom, pri pokretanju
      aplikacije dobija pitanje za godinu. **Potvrđeno 25.8.2026.** (Ovo je cela
      poenta: pitanje postavljeno samo pri registraciji ne bi videla većina
      naloga, jer kroz registraciju nisu ni prošli.)
- [ ] Isto i posle prijave kroz **Google** — nalog koji nikad nije video formu
      za registraciju.
- [x] Pitanje **prekriva ceo ekran** i ispod njega se ne može ništa dodirnuti.
      **Potvrđeno 25.8.2026.**
- [x] **Uneta godina može da se ispravi pre potvrde.** Nađeno pokvareno
      25.8.2026 i popravljeno istog dana: prva otkucana vrednost je ostajala
      zauvek, jer je fokus vratio ekran ispod. Vidi „Pitanje je pokrivalo ekran,
      ali ne i tastaturu" u `STANJE-RADA.md`. **Ponovo proveriti.**
- [ ] **Gost** (bez prijave) ne dobija pitanje.
- [x] **Backend ugašen**, pa pokrenuta aplikacija sa zapamćenim tokenom →
      pitanja **nema** i aplikacija radi kao i pre. („Server nije odgovorio" nije
      isto što i „niko nije pitan"; da su ta dva stanja spojena, pao backend bi
      zaključao sve.)
- [x] Uneta godina koja daje maloletnika (npr. 2014) → pitanje se zatvara,
      a `SELECT birth_year, birth_year_stated_at FROM users WHERE id = ...`
      pokazuje upisano i vreme upisa.
- [x] Odmah zatim: taj nalog ne može da pošalje zahtev **kao trener** (stavka
      33), a nova veza u kojoj je on učenik kreće od `listen` (stavka 34).
      **Potvrđeno 25.8.2026** — u sobi samo sluša, bez mogućnosti da uključi
      mikrofon.
- [ ] Nemoguća godina (`2999`, `1899`, prazno) → poruka, i **ništa se ne šalje
      na server**.
- [ ] Ugašen backend pa pokušaj čuvanja → pitanje **ostaje**, uz poruku da server
      nije dostupan. (Zatvaranje pitanja posle neuspelog upisa izgledalo bi
      identično uspehu i ostavilo nalog tačno u stanju zbog kog gate postoji.)
- [ ] **Odjavi se** na tom ekranu radi — nalog na koji se greškom ušlo nije
      ćorsokak.
- [ ] Podešavanja → **NALOG → Godina rođenja** pokazuje upisanu godinu; otvara
      isti ekran, ovaj put sa **Odustani**; ispravka se vidi i u bazi i u redu u
      Podešavanjima.
- [ ] Prag iz `.env` se vidi na ekranu: `AGE_OF_CONSENT=13` → tekst kaže
      „mlađe od 13". (Vratiti na 16.)

## 36. Roditeljska saglasnost — glavni tok ✅ provereno uživo 25.8.2026

**Ceo srećni put je prošao 25.8.2026**, sa nalozima napravljenim iznova nad
ispražnjenom bazom. Nađena je i popravljena jedna prava greška — vidi
„Stranica se otvarala, a dugme nije radilo" u `STANJE-RADA.md`: forma je slala
`Origin` koji nije bio na spisku dozvoljenih, pa se stranica otvarala a dugme
vraćalo `{"error":"Origin not allowed"}`. Nijedan test to nije mogao da uhvati.

Ostaje odbijanje, rubovi linka i podešavanja — niže.

**Pre probe treba podesiti dve stvari u `chess_backend/.env`:**

```
PUBLIC_BASE_URL=http://192.168.0.19:3000
PARENT_CONSENT_VERSION=rs-2026-08-25
```

Prva je adresa **sa koje je server dostupan sa telefona** — LAN adresa radi dok
su telefon i računar na istom wi-fi-ju, i to je jedini način da se ovo isproba
pre prebacivanja na server. Kao „roditelja" uzeti svoju drugu adresu; SMTP je
lokalno podešen, pa poruka stvarno odlazi.

Treba nalog trenera i nalog deteta sa upisanom godinom maloletnika (stavka 35).

- [ ] `PUBLIC_BASE_URL` sa smećem umesto adrese (`primer.rs`, bez šeme) →
      **server ne startuje**, uz jasnu poruku. Isto i `PARENT_CONSENT_VERSION`
      sa razmakom u sebi. (Vratiti ispravne vrednosti.)
- [ ] `PUBLIC_BASE_URL` **prazan** → server radi, ali prihvatanje veze sa
      maloletnikom kaže da poruka nije poslata. Veza ipak stoji na
      „čeka roditelja". (Tiho prelaženje u „prihvaćeno" je ono što ovde ne sme.)

Glavni tok:

- [x] Dete pošalje zahtev, trener prihvati → poruka **ne** kaže da je odnos
      uspostavljen. **Potvrđeno 25.8.2026**; pošto adrese roditelja nije bilo,
      poruka je rekla baš to.
- [x] `SELECT status FROM trainer_students WHERE ...` → `awaiting_parent`. ✅
- [x] `SELECT * FROM friends WHERE ...` → **nema reda**. ✅ Red se pojavio tek
      posle roditeljevog „da" — dva reda, oba smera.
- [x] Kod deteta red piše „Čeka saglasnost roditelja — **dodirnite**", sivo, sa
      ikonom porodice. ✅ Trenerova strana istog reda još nije pogledana.
- [ ] Trener ne može da zada domaći tom detetu i ne vidi mu napredak.
- [ ] Dete ne može da uđe u trenerovu sobu (spisak zvanica traži
      **prihvaćenu** vezu).
- [x] Mejl je stigao i link je otvoren **sa drugog uređaja** (Windows, isti
      wi-fi) — dokaz da `PUBLIC_BASE_URL` pokazuje na dostupnu adresu. ✅
- [x] Stranica se vidi bez prijave, imena tačna, verzija `rs-2026-08-25` na
      dnu, tamna tema poštovana. ✅
- [x] **Bez** kvačice → „Dajem saglasnost": veza `accepted`,
      `parent_consent_at/ip/version` popunjeni (IP je stvarna adresa uređaja
      sa kog je otvoreno), `friends` dobio dva reda, `parent_allows_recording`
      **false**, `voice_level` ostao `listen`. **Svih jedanaest polja tačno.** ✅
- [x] `users.parent_consent_at` i `parent_consent_version` na nalogu deteta
      popunjeni **u istoj transakciji** — nema stanja u kom je jedno tu a drugo
      nije. ✅
- [x] Isti link ponovo → **„Već ste odgovorili"**, i `answered_at` je ostao na
      istoj sekundi. ✅ Poruka je prava od tri, ne opšte „link nije ispravan" —
      roditelj koji je već potvrdio ne sme da pomisli da nije prošlo.
- [x] Aplikacija kod oba korisnika sad pokazuje običnu vezu („Vaš učenik" /
      „Vaš trener"), dugme za napredak je upaljeno, a treneru se pojavilo i
      **Grupe učenika**. ✅
- [x] **Kontrola, i najvažnija provera stavke: punoletan učenik.** Trener
      pozvao nalog sa 2002, učenik prihvatio → veza ide **pravo u `accepted`**,
      bez `awaiting_parent`; **nijedno pismo nije poslato** (broj zahteva za
      saglasnost ostao 1, onaj za dete); `voice_level = talk`; red u `friends`
      odmah; treneru stiglo obično „Zahtev je prihvaćen". **Potvrđeno
      25.8.2026.** Bez ovoga stavka dokazuje samo da nešto blokira; sa njom
      dokazuje da blokira one koje treba.

Odbijanje i rubovi:

- [ ] Druga veza, pa na stranici „Ne dajem saglasnost" → veza ostaje
      `awaiting_parent`, `granted = false` upisan sa vremenom, i nema reda u
      `friends`.
- [ ] Izmišljen token u URL-u → „Link nije prepoznat", bez ijednog traga u bazi.
- [ ] Istekao link: `UPDATE parent_consent_requests SET expires_at = NOW() -
      INTERVAL '1 day' WHERE ...` → „Link je istekao", drugačija poruka od
      prethodne.
- [ ] Ime deteta postavljeno na nešto sa `<b>` u sebi → na stranici se vidi kao
      tekst, ne kao podebljano. (Ime je ono što je neko ukucao u registraciju.)
- [ ] Stranica se čita i na uskom telefonu i u tamnoj temi.

Adresa roditelja:

- [ ] Dete **bez** upisane adrese roditelja prihvati poziv → poruka kaže da
      adrese nema, veza stoji na `awaiting_parent`, i **nijedan mejl ne odlazi**.
- [ ] Dete dodirne taj red → otvara se pitanje za email roditelja. Unese
      adresu → **poruka odlazi odmah**, bez ijedne dodatne radnje.
- [ ] Ista adresa se vidi i u Podešavanjima → NALOG → **Email roditelja**, i
      taj red se punoletnom nalogu **ne prikazuje**.
- [ ] Neispravna adresa (`roditelj`, prazno) → poruka, ništa se ne šalje.

Zatečene veze (odluka „javi, ne menjaj"):

- [ ] Nalog sa **već prihvaćenom** vezom upiše godinu maloletnika → treneru
      stigne zvonce („mikrofon je od sada vaša odluka"), a `status` i
      `voice_level` te veze ostaju **nepromenjeni**.
- [ ] Punoletan nalog upiše godinu → **nikakvo** obaveštenje ne odlazi.

## 37. Snimanje traži da si sam u sobi — 26.8.2026, nije viđeno uživo

**Stavka je 27.8.2026. napisana iznova, jer je pravilo koje je proveravala
ukinuto.** Do 26.8.2026. glasila je „snimanje poštuje saglasnost roditelja" i
merila se prema `parent_allows_recording`; ta kolona danas ništa ne odlučuje.
Stari spisak je u
[arhiva/TODO-provera-do-26.8.2026.md](arhiva/TODO-provera-do-26.8.2026.md)
samo kroz stavku 4 — sam spisak je obrisan, jer je opisivao tok koji ne postoji
i jedna mu je kutijica bila **naopako** („gost ne blokira snimanje"; danas
blokira).

Pravilo je sada jedno, i stoji u
[recordingConsent.js](../chess_backend/services/recordingConsent.js): **zvuk
snima samo punoletan vlasnik sobe dok je u njoj sam.** Čas između trenera i
učenika ne snima se uopšte, ni uz čiju saglasnost. Reprodukcija časa nije
dirana — snimak je `timeline_json`, a `audio_url` je oduvek smeo da bude prazan.

Za probu treba trener sam u sobi, pa jedan učenik, pa jedan gost.

Dugme i razlog ispod njega (`recording_consent` stiže na svaku promenu spiska):

- [ ] Punoletan trener **sam u sobi** → „Započni snimanje" je upaljeno, ispod
      njega ne piše ništa.
- [ ] Uđe **učenik** → dugme se gasi, a ispod piše rečenica koja **imenuje** ko
      smeta. (Odbijanje koje ne ume da kaže koga se tiče je odbijanje po kome
      niko ne može da postupi.)
- [ ] Učenik izađe → dugme se **samo** vraća, bez osvežavanja ekrana.
- [ ] Uđe **gost bez naloga** → dugme se gasi isto kao za učenika, a gost je u
      razlogu nazvan gostom. Ovo je obrnuto od starog pravila, pod kojim je gost
      bio nevidljiv jer nema nalog ni godine.
- [ ] Nalog **bez upisane godine** sam u sobi → dugme je **ugašeno**, uz poruku
      da snimanje traži godinu rođenja. (Svuda drugde u ovom kodu neupisana
      godina prolazi; ovde namerno ne prolazi — „nismo pitali" ne sme da se čita
      kao „da".)
- [ ] Nalog sa godinom **ispod 18** sam u sobi → ugašeno, uz poruku da je
      snimanje samo za punoletne. Granica je 18 i **nije** `AGE_OF_CONSENT`:
      to je drugo pitanje i druga brojka.

Brava, a ne samo dugme:

- [ ] Trener pokrene snimanje **pa** neko uđe → stiže `recording_must_stop`,
      snimanje **staje samo**, a onaj ko je ušao **ostaje na času**. Ponuđeno je
      čuvanje onoga što je snimljeno pre njegovog ulaska — u tom delu ga nema.
- [ ] Snimanje pokrenuto bez prava → stiže `recording_denied`, snimak se
      **baca**, ne nudi se „Sačuvaj". (Odbijen snimak koji ostane na uređaju i
      čeka dugme je odbijen snimak koji će biti sačuvan.)
- [ ] Isto sa pauzom: pokreni, pauziraj, pusti nekoga unutra, nastavi →
      snimanje ne kreće ponovo.

Upis (traži `curl` ili Postman):

- [ ] `POST /recordings/save` za sobu u kojoj je bio još neko → **403**, i u
      `chess_backend/uploads/` **nema novog fajla**. (Multer ga zapiše pre
      provere, pa je brisanje deo popravke — ovo je jedina provera koja to
      hvata.)
- [ ] Isti pokušaj iz aplikacije → snimak ostaje na uređaju, u dnevniku piše
      `Odbijen snimak`, i **ne pokušava ponovo** pri svakoj sinhronizaciji.
- [ ] Restart backend-a usred snimanja, pa čuvanje → snimak **prolazi**, uz
      poruku da provera nije mogla da se obavi. (Odbijanje bi uništilo pravi
      snimak zbog tuđeg restarta; tiho prolaženje bi bilo laž.)

## 38. Obrisan nalog gubi prijavu — 25.8.2026, delimično provereno

Popravka nađena pri pražnjenju baze: token je važio 7 dana i posle brisanja
naloga. **Provereno protiv živog servera istog dana** — ostaje ono što traži
aplikaciju.

- [x] Potpisan token za nepostojeći nalog → **401** i `reason: account-gone`.
      Provereno 25.8.2026 (`curl` na `/me/standing`).
- [x] Bez tokena → 401; izmišljen potpis → 403. Provereno istog dana.
- [x] Socket sa tokenom nepostojećeg naloga → `connect_error`; gost prolazi;
      izmišljen potpis pada. Provereno istog dana.
- [ ] **U aplikaciji:** uređaj sa zapamćenim tokenom obrisanog naloga, pa
      pokretanje → sam se odjavljuje i vodi na prijavu, uz poruku „Ovaj nalog
      više ne postoji na serveru". (Ovo je jedino što `curl` ne pokriva.)
- [ ] **Backend ugašen** sa istim uređajem → **ne** odjavljuje se, nego kaže da
      nema veze sa serverom. („Nisam mogao da pitam" ne sme da se čita kao
      „nalog je obrisan" — inače jedan ispad odjavi sve.)
- [ ] Oduzimanje admin uloge (`UPDATE users SET role = 'korisnik' ...`) važi
      **odmah**, bez ponovne prijave: admin rute odbijaju na sledeći zahtev.

## Gde je provera stala — 26.8.2026

Nastavlja se odavde. Nalozi i veze **stoje u bazi**, ne treba ih praviti iznova.

**Zatečeno stanje:**

| | |
|---|---|
| nalozi | trener (1975), učenik 1 (2014, maloletan), učenik 2 (2002) |
| veza sa detetom | `accepted`, saglasnost roditelja data, glas `listen`. (`parent_allows_recording` u toj vezi stoji na `false`, ali **od 26.8.2026. ništa ne odlučuje** — snimanje više ne zavisi od roditelja nego od toga da li je vlasnik sam u sobi.) |
| veza sa punoletnim | `accepted`, glas `talk`, roditelj nije ni pitan |
| soba | `961671`, tvorac trener, spisak zvanica prazan, `allow_guests = false` |
| `.env` | `PUBLIC_BASE_URL` i `PARENT_CONSENT_VERSION` podešeni |

**Gotovo:** stavka 33 u celini (pravilo o godinama, oba smera, i slanje i
prihvatanje), stavka 36 glavni tok (uključujući kontrolu sa punoletnim
učenikom), **stavka 34 u celini** (korisnik je potvrdio sve kutijice 25.8.2026 —
raniji zapis da je ostao „daj/oduzmi mikrofon" bio je zastareo), stavka 31
dijalog „Ko sme u sobu", stavka 38 preko `curl`-a. Sve zaključene stavke su
27.8.2026. izdvojene u
[arhiva/TODO-provera-do-26.8.2026.md](arhiva/TODO-provera-do-26.8.2026.md).

**Prvo sledeće — stavka 37, ali po novom pravilu.** Spisak od 25.8.2026. koji je
ovde stajao proveravao je da roditeljsko odbijanje zaustavlja snimanje; to
pravilo je ukinuto 26.8.2026. i zamenjeno jednim koje ne zavisi ni od kakve
saglasnosti: **snima samo punoletan vlasnik sobe dok je sam u njoj.** Nov spisak
je u samoj stavci 37 i traži trenera samog, pa učenika, pa gosta bez naloga —
gost sada blokira snimanje, što je obrnuto od onoga što je pisalo ovde.

Windows aplikacija i dalje traži **hot restart (`R`)** ili nov `flutter run`
pre te probe; server je nodemon već pokupio.

**Zatim, po redu:** stavka 31 sa grupama, stavka 32 prekidač za goste, ostatak
35 i 36 (odbijanje roditelja, rubovi linka, `.env` provere), stavka 38 u
aplikaciji.

**Poznate sitnice, zapisane a nepopravljene:**

- zvonce radi iz snimka — zahtev rešen drugde i dalje nudi dugmad dok se dijalog
  ne otvori ponovo
- odgovor na zahtev drži spinner dok se ne osveže tri liste; treba vratiti
  odgovor odmah i osvežiti posle
- ponovljen zahtev za par koji već ima red kaže „Zahtev je poslat" iako ništa
  nije poslato
- ~~**87 poziva `ScaffoldMessenger.of(context)`** bez ograde u `lib/`~~ —
  urađeno 25.8.2026: svih 82 (u 23 fajla) idu kroz `AppFeedback`, a
  `test/app_feedback_guard_test.dart` pada ako se ijedan vrati. Usput se
  pokazalo da je i sama ograda pucala na zatvorenom ekranu — vidi „Poruka koja
  obori radnju" u `STANJE-RADA.md`. **Zato aplikacija mora da se pokrene ispočetka
  pre stavke 37** (`R` u `flutter run`, ili nov build): izmena dira `lib/` široko
  i hot reload je ne prenosi celu. (Rečenica je do 27.8.2026. stajala
  nedovršena — ovako je i mišljena.)
