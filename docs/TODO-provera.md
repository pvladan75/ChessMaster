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
- [x] **Google prijava neće raditi na Androidu** dok se ne registruje nov OAuth
      klijent za novi paket. Vidi `TODO-objavljivanje.md`, korak 2.
      **Radi od 16.9.2026** — vlasnik je registrovao Android klijent sa debug
      SHA-1 i zamenio `google-services.json`, i prijavio se na telefonu.
      Release i Play ključ ostaju za objavljivanje.
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
PUBLIC_BASE_URL=http://<adresa-ovog-racunara>:3000
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

## 39. Panel trenera u tabu „Ljudi" — 27.8.2026, delimično provereno

**Provereno uživo 27.8.2026 (korisnik):** panel se vidi na Windows-u i na
Androidu, prikazuje se **samo onome ko ima učenike**, „Nije vežbao" i dugme
„Otvori" rade. Iz te probe su ispale tri izmene — „Domaći stoji", izbacivanje
učenika sa otvorenim domaćim iz „Nije vežbao", i poruka učeniku o preskočenim
zagonetkama (vidi „Šta je prva proba panela pokazala" u
[STANJE-RADA.md](STANJE-RADA.md)). **Te tri izmene nisu viđene uživo** — spisak
ispod je prepravljen prema njima, koraci 3, 6, 10 i 11 su novi.

Napomena za sledeću probu: zadaci koji već stoje u bazi su od 27.8.2026, pa se
u „Domaći stoji" pojavljuju **tek 30.8.2026** (prag je 3 dana bez pomaka). Ranije
se to vidi samo tako što se pragu privremeno spusti vrednost `STALLED_DAYS` u
`services/trainerPanelService.js`.

Izabrana varijanta A („Danas") kao odeljak, plus značka iz varijante C. Zašto
odeljak a ne peti tab — vidi „Panel trenera — izabrano i napisano" u
[STANJE-RADA.md](STANJE-RADA.md).

Traži nalog **trenera sa bar jednim prihvaćenim učenikom**. Nalozi iz stavke 31
i dalje stoje u bazi.

Redom, jer svaki korak pravi ulaz za sledeći:

1. **Prazan panel.** Prijaviti se kao učenik (ili trener kome je dan prazan) i
   otvoriti „Ljudi". Panela **nema uopšte** — ne prazan okvir sa četiri
   naslova, nego ništa. Na znački nema broja.
2. **Danas.** Kao trener zakazati čas za danas (Časovi → zakaži), pa se vratiti
   na „Ljudi". Red nosi vreme, naziv, ime pozvanog i kod sobe; „Uđi" otvara
   sobu **kao domaćin** (tabla se sme pomerati). Čas koji je već počeo pre
   manje od dva sata **i dalje stoji** — to je namerno.
3. **Domaći ističe.** Zadati učeniku vežbu sa rokom u toku dana. Red kaže
   „0 od N urađeno" i „rok danas u HH:MM". Kad rok prođe, red **ne nestaje**
   nego menja tekst u „rok je istekao" i boju u crvenu.
4. **Za pregled i značka.** Učenik reši ceo zadatak. Kod trenera: broj na tabu
   „Ljudi" poraste, u panelu se pojavi red „predato danas" sa tačnošću.
   Kucnuti „Pregledaj" → otvara se pregled po pozicijama. **Vratiti se nazad:**
   red je nestao i **broj na znački je pao za jedan**. Ponovo otvoriti isti
   pregled — broj se ne menja (drugo gledanje ništa ne piše).
5. **Učenik ne prazni trenerov spisak.** Isti zadatak otvoriti **kao učenik**
   (svoj pregled) pre nego što ga trener pogleda, pa proveriti da je kod
   trenera i dalje u „Za pregled". Ovo je razlog zašto je obeležavanje zasebna
   ruta, i jedina stvar na spisku koja se ne vidi na trenerovom ekranu.
6. **Nije vežbao — samo bez zadatog domaćeg.** Učenik koji sedam dana nije
   rešio ništa stoji pod „Nije vežbao" i red piše „nema zadatog domaćeg";
   onaj koji nikad ništa nije rešio stoji **prvi**. Čim mu se zada domaći,
   **nestaje odatle** i pojavljuje se u redu o domaćem — nikad na oba mesta.
   „Otvori" vodi na njegov napredak, gde su i dugmad „Zadaj lekciju" / „Zadaj
   vežbu".
7. **Zahtevi u broju.** Poslati zahtev sa trećeg naloga ka treneru: broj na
   znački poraste i bez ijednog domaćeg. Odgovoriti na zahtev — broj padne.
8. **Telefon, 360 dp.** Ovo je jedini deo koji test ne može da zameni:
   `test/trainer_panel_test.dart` crta panel na 360×640 i pada na prelivanje,
   ali **release build ne crta žuto-crne trake** (vidi `CLAUDE.md`). Pogledati
   na telefonu da nijedno dugme („Uđi", „Pregledaj", „Otvori") nije odsečeno uz
   ivicu, sa dugim imenom učenika i dugim naslovom zadatka.
9. **Rail na Windows-u.** Prvi tab se u bočnoj traci sada zove „Trening", isto
   kao u donjoj traci na telefonu (ranije je pisalo „Početna").
10. **Domaći stoji.** Zadati domaći **bez roka** i ne dirati ga tri dana (ili
    privremeno spustiti `STALLED_DAYS`). Red se pojavljuje pod „Domaći stoji",
    piše „nije ni otvoren · N zadataka" i „bez roka". Isto proveriti i za
    zadatak koji je stao na pola: tekst je „stao na 8 od 10". Zadatak kome rok
    ističe u naredna 48 sata **ne sme** biti u oba odeljka.
11. **Učenik zna da nije predao.** Kao učenik krenuti u domaći i **preskočiti**
    bar jednu zagonetku, pa odraditi ostale. Na kraju piše **„Domaći još nije
    predat"** sa brojem preskočenih i objašnjenjem da trener ne dobija
    obaveštenje — a ne „Zadatak je završen". Dugme „Uradi preskočene" vraća
    **samo** preskočene, ne ceo zadatak. Kad se i one urade: kod trenera stiže
    obaveštenje i red pod „Za pregled", **bez izlaska iz taba** (osvežava se
    preko soketa). Preskočena jedna → „1 zagonetku", dve → „2 zagonetke".

**Poznato unapred, da se ne prijavljuje kao greška:** u maketi je kod „Domaći
ističe" stajalo dugme „Podseti", a kod nas piše „Otvori" — poruka učeniku nije
napisana. I odeljak „Izveštaji roditeljima" iz varijante C ne postoji, jer
`student_reports` nema stanje „sastavljen, nije poslat".

## 40. Ekran za prijavu — 27.8.2026, nije viđeno uživo

Izmene su iz prve prolaznosti korisnika kroz aplikaciju (bagovi 2–6). Zašto je
lozinka namerno ostala nesačuvana i kako je razdvojen ekran — vidi „Ekran za
prijavu — pet nalaza" u [STANJE-RADA.md](STANJE-RADA.md).

1. **Razdvojena dva puta unutra.** Na ekranu za prijavu: prvo Google blok sa
   tekstom „Prijava / Registracija preko Google-a" i napomenom „Ako još nemate
   nalog, napraviće se sam.", pa linija „ili", pa email forma. Dugme dole piše
   „Prijavi se email adresom", a ispod njega „Nemate nalog? Registrujte se
   email adresom".
2. **Registracija ima isti Google blok.** Kucnuti na „Registrujte se email
   adresom": Google dugme je i dalje tu (ranije ga u tom režimu nije bilo),
   pojavi se polje „Ime i Prezime", a glavno dugme piše „Registruj se email
   adresom".
3. **Ništa ne izgleda označeno dok se kuca.** Kliknuti u polje za adresu i
   kucati: Google dugme ostaje neutralno (siva ivica), a naglašeno je samo
   „Prijavi se email adresom".
4. **Adresa se pamti, lozinka ne.** Prijaviti se sa „Zapamti me", pa se
   **odjaviti**. Na ekranu za prijavu adresa je već upisana, polje za lozinku je
   prazno, a kursor stoji **u lozinki**. Bez zapamćene adrese kursor je u polju
   za adresu.
5. **Menadžer lozinki.** Na Androidu, pri prvoj prijavi, sistem nudi „Sačuvaj
   lozinku?" — to je `finishAutofillContext()`. Sledeći put nudi da je popuni.
   Na Windows-u isto radi ako je nalog u menadžeru pretraživača/sistema.
   Aplikacija sama lozinku nikad ne prikazuje ni ne čuva.
6. **„Zapamti me" bez čekiranja.** Odčekirati, prijaviti se, ugasiti i upaliti
   aplikaciju: traži prijavu iznova, i adresa **nije** upisana.
7. **Windows bez Google klijenta.** U trenutnom Windows build-u Google blok se
   uopšte ne prikazuje (ni dugme ni „ili"), a email prijava radi normalno.

**8. Google prijava na Windows-u — tek kad postoji klijent.** Redom:

   a. Google Cloud konzola → APIs & Services → Credentials → *Create
      credentials* → *OAuth client ID* → tip **Desktop app**. Ne „Web
      application": za desktop tip Google sam dozvoljava `http://localhost` sa
      bilo kojim portom, pa se ne upisuju redirect URI-jevi.
   b. Zabeležiti *Client ID* i *Client secret*. Kod desktop klijenata secret
      nije stvarna tajna (putuje u svakoj kopiji aplikacije) — zato tok i koristi
      PKCE — ali **ne sme u repozitorijum**, koji je javan.
   c. Na serveru u `.env`: dodati taj ID u `GOOGLE_CLIENT_IDS`, **zarezom** na
      postojeći. Bez toga svaka desktop prijava pada sa „Google token nije izdat
      za ovu aplikaciju".
   d. Graditi Windows sa:
      `flutter build windows --dart-define=GOOGLE_DESKTOP_CLIENT_ID=... --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=...`
   e. Proba: Google blok se sada vidi. Klik otvara **sistemski pretraživač** na
      Google prijavi, traži izbor naloga (uvek, i kad je nalog već prijavljen),
      a posle potvrde stranica kaže „Prijava je gotova." i aplikacija je
      prijavljena.
   f. Rubovi: zatvoriti karticu bez prijave (aplikacija se ne zaglavi, dugme se
      vrati); odbiti pristup (poruka „Prijava preko Google-a je otkazana.");
      prijaviti se Google nalogom koji **već ima** email nalog u aplikaciji —
      mora da uđe u isti nalog, a ne da napravi drugi.

**Poznato:** `oauth_pkce.dart` je pokriven testovima (uključujući primer iz RFC
7636), ali soket i pretraživač nisu i ne mogu biti — ovo je zato ceo tok koji
niko nije video da radi.

**✅ Provereno uživo 27.8.2026 (korisnik):** ceo tok na Windows-u iz prve —
sistemski pretraživač, ekran „Sign in to Mislisha", stranica „Prijava je
gotova.", i aplikacija prijavljena. Google nalog čija adresa **već ima** nalog u
aplikaciji ulazi u **taj isti** nalog, ne pravi drugi. Ostaje da se probaju
rubovi iz tačke 8f (zatvorena kartica, odbijen pristup).

9. **Verifikovan nalog ne prolazi kroz `/verify-email`.** Popravljena rupa,
   27.8.2026 — ranije je ta ruta izdavala token bez provere kôda. Proba:
   registrovati se, verifikovati kôd, pa **ponovo** poslati isti kôd sa ekrana
   za verifikaciju (ili `curl`-om). Odgovor mora biti odbijanje sa porukom
   „Ovaj nalog je već verifikovan…", a aplikacija se vraća na formu za prijavu.
   **Ni u jednom slučaju se ne sme dobiti token.**

## 41. Pogrešan potez i engine koji razmišlja — 27.8.2026, nije viđeno uživo

Bagovi 1 i 7 sa prolaska kroz aplikaciju. Zašto je „Pokušaj ponovo" uklonjeno i
šta je bila ona jedna sekunda — vidi „Bagovi 1 i 7" u
[STANJE-RADA.md](STANJE-RADA.md).

1. **Taktika po vašoj meri, pogrešan potez.** Odigrati pogrešan potez: figura se
   vraća, piše „Nije to. Probajte drugi potez.", i **odmah** se može igrati
   sledeći potez — bez ijednog dugmeta između. Dugmeta „Pokušaj ponovo" nema.
2. **Tabla se ne da razvlačiti.** Posle pogrešnog poteza povući nekoliko figura
   redom, i belih i crnih. Nijedna ne sme da ostane na novom polju: pozicija na
   ekranu je uvek pozicija koja se rešava.
3. **Domaći ima jedan pokušaj.** Otvoriti zadatak koji je zadao trener i
   namerno pogrešiti. Piše „Nije to. Zadatak ima jedan pokušaj, potez je
   zabeležen.", tabla se zaključava, i **ne** može se igrati ponovo. „Prikaži
   rešenje" radi i pokazuje liniju do kraja. Kod trenera taj zadatak stoji kao
   pokušan, sa pogrešnim potezom u pregledu.
4. **Završnice.** Isto ponašanje kao pod 1 i 2 (režim „Održi remi" ili „Dobij").
   Taster **R** više ne radi ništa — dugme koje je pozivao ne postoji.
5. **Osnovno matiranje, potez preko engine-a.** Ovo je bag 1: dok engine
   razmišlja **i u sekundi između njegove odluke i poteza**, pokušati odigrati
   potez. Tabla ne sme da primi ništa u tom trenutku, a engine mora da nastavi
   da igra normalno posle toga. Ranije je odigrao još jedan potez i stao.
6. **Log je čist.** Uz otvoren backend log: pri svakom prelasku na novu poziciju
   **ne sme** da se pojavi „FEN string must contain six space-delimited fields"
   ni „Discarding stale ... from old FEN:  " sa praznim FEN-om.
7. **Ako engine ipak ne odgovori,** posle jednog ponovnog pokušaja piše „Engine
   nije odgovorio. Odigrajte potez ponovo." i tabla je opet slobodna — nikad
   zaključana bez izlaza.

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
aplikaciji, i **stavka 39** (panel trenera, napisan 27.8.2026) — koja koristi
iste ove naloge i vezu, pa se lako nadovezuje.

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

---

## 42. Skripta pita debug ili release, aplikacija kaže koji je build — 28.8.2026, nije viđeno uživo

Nastalo iz jednog prolaza kroz `build_and_deploy.ps1` 27.8.2026: instalacija je
uspela, a skripta je prijavila pad i stala **pre** provere stare instalacije —
one koja postoji zato što je zamena stare i nove aplikacije već jednom pojela
vreme. Uzrok je PowerShell 5.1: uz `$ErrorActionPreference = "Stop"` svaki red
koji izvorna komanda napiše na stderr postaje terminirajuća greška čim se stderr
preusmerava, a `monkey` uvek piše `args: [...]`.

**Šta je dokazano bez telefona:** greška je reprodukovana pod Windows PowerShell
5.1 (`NativeCommandError`), a novi obrazac — `Invoke-Adb`, koji oko poziva
spušta preference na `Continue` — proveren je u istom obliku u kom stoji u
skripti: stderr ne obara poziv ni pri uspehu ni pri padu, `$LASTEXITCODE` se
čuva, sukob potpisa se prepoznaje, i `Stop` se vraća posle poziva. Skripta
prolazi i parser (`Parser::ParseFile`, bez grešaka).

**Prolaz sa telefonom, release grana — proverio korisnik 28.8.2026:**

- [x] Skripta pita, i release grana radi od pitanja do kraja.
- [x] Stiže do `[4/4]` i ispisuje `(rs.pejovic.chesscoach, release 6849caf)` —
      dakle i režim i commit stoje u ispisu. **To je tačno ono što je 27.8.2026.
      izostalo**, jer je skripta dotad padala na `monkey`-jevom stderr-u.
- [x] **Provera stare instalacije se izvršila** i nije ništa javila, dakle
      `com.example.chess_app` na tom telefonu više nema. Do 27.8.2026. se do te
      provere nikad nije ni stizalo.
- [x] Ispis `adb install` je uvučen, dakle `Invoke-Adb -Prikazi` radi.
- [x] Na dnu Podešavanja piše `Mislisha 1.1.0+2 • 6849caf • release •
      2026-08-28T00:04`, bez `+` jer je stablo bilo čisto — i **dodir ga
      kopira**, provereno lepljenjem.

**Prolaz sa telefonom, debug grana — proverio korisnik 29.8.2026:**

- [x] Debug grana radi od pitanja do instalacije, i debug APK se nađe.
- [x] U Podešavanjima piše `Mislisha 1.1.0+2 • 8404148 • debug •
      2026-08-29T16:48`. Dakle **režim se vidi** (`debug`, ne `release`) i
      commit imenuje kod: `8404148` je bio HEAD od 16:45 do 16:48, kad ga je
      zamenio `28dc27b`. Bez `+`, dakle stablo je bilo čisto — i to se
      poklapa, jer je build napravljen između ta dva commita.

**Ostalo neprovereno:**

- [ ] Instalacija debug-a preko release-a (ili obrnuto) → skripta prepozna sukob
      potpisa i ispiše **komandu za brisanje sa upozorenjem da odnosi prijavu i
      podešavanja**, umesto golog „Instalacija nije uspela".
- [ ] Build iz prljavog radnog stabla ima `+` na kraju commita.
- [ ] `flutter run` ili APK iz CI-ja → piše „build nije označen". Verzija se
      **ne** prikazuje sama, jer `1.1.0+2` je isti niz na svim gradnjama ove
      nedelje i izgledao bi kao odgovor.

**Windows, `build_windows.ps1` — 29.8.2026:** skripta od tog dana radi isto
što i Android — pita debug ili release i žigoše build. Dokazano do `.exe`:
gradnja je ispisala `Mislisha 1.1.0+2 (release 28dc27b+)`, sa `+` jer je sama
skripta tada bila nekomitovana, što je uzgred i provera žiga za prljavo stablo.
Ostaje da se vidi uživo:

- [x] Podešavanja u Windows verziji ispisuju isti red — korisnik 29.8.2026:
      `Mislisha 1.1.0+2 • faf2630 • release • 2026-08-29T17:04`. Bez `+`,
      dakle iz čistog stabla, i `faf2630` je baš commit koji je žig i uveo.
      Do tog dana je tu pisalo „build nije označen“.
- [ ] `-Install` napravi kopiju u `%LOCALAPPDATA%\Mislisha` i prečicu u Start
      meniju, a `-Uninstall` ih ukloni.
- [ ] **Grana koja sama briše zaostao font sa ikonama nije se okinula** — font
      je bio svež u toj gradnji. Kad se sledeći put doda nova ikona, gledati
      da li se ispiše brisanje i ponovna gradnja, pa da ikona ne izađe prazna.

---

## 43. Jedanaest nalaza sa prolaska kroz aplikaciju — 28.8.2026, nije viđeno uživo

Sve iz `TESTING_LOG.md` (dnevnik provere koji korisnik vodi van repozitorijuma).
`flutter analyze` je čist, `flutter test` prolazi 767 (bilo 746). Ništa od
navedenog **nije viđeno kako radi**.

**Raspored ekrana — traži telefon, ne izlazi u testovima.** Release build ne crta
upozorenje o prekoračenju, pa se ovo ne vidi ni u `analyze` ni u logu:

- [ ] Uspravno, `Šahovski studio` i `Časovi → Nova sesija`: tabla stoji, a
      **sve ispod nje se skroluje zajedno** — navigacija, motor, bočni panel.
      Traka je do sada bila zakucana i jela ~64 dp na telefonu.
- [ ] Položeno: leva kolona je **samo tabla**, desna sve ostalo uključujući
      navigaciju. Provera koja se traži: **vide li se redovi 7 i 8** — do sada
      su bili odsečeni jer je traka delila levu kolonu sa tablom.
- [ ] Ista dva rasporeda i sa uključenom evaluacionom linijom (tabla se tada
      smanjuje sa 94% na 84% visine) i sa uvećanjem table iz Podešavanja
      preko 1.0.
- [ ] Natpis „Igrate kao Beli (Host)" je nestao sa sva tri rasporeda.

**Stablo poteza i komentari — glavni deo posla:**

- [ ] Odigrati liniju, vratiti se dva poteza, odigrati drugi potez → **izvorni
      nastavak se i dalje vidi** u „Stablo poteza", u zagradi, i dodir na njega
      vraća tablu na njega. To je stavka zbog koje je sve ostalo pisano.
- [ ] „U glavnu liniju" okreće **sve račve do korena**, ne samo najbližu.
- [ ] „Obriši varijantu" seče i vraća na roditelja.
- [ ] Komentar se kuca u polje ispod stabla; zaglavlje imenuje potez. Prelazak
      na drugi potez pa nazad → komentar je i dalje tu.
- [ ] U sobi (ne studiju): komentar stiže i drugom učesniku, i to **tek pošto
      se prestane kucati** (600 ms), a ne po slovu.
- [ ] Sačuvati kao lekciju → dodeliti učeniku → učenik u pregledaču vidi
      **trenerov komentar ispod table** za potez na kom stoji, i **linija je
      glavna linija**, ne sporedna. Ovo je put na kom je nađen bag sa
      varijacijama; vredi ga proći sa lekcijom koja **ima** varijaciju.

**Motor u stablo:**

- [ ] Dugme na redu linije i „Ubaci kao varijaciju" u dijalogu → linija ulazi
      kao varijanta, evaluacija se upisuje na njen prvi potez, a **kursor ostaje
      gde je bio**.
- [ ] Ista linija dvaput → „Linija je već bila u stablu", bez druge iste grane.
- [ ] „Ubaci evaluaciju u komentar" dopisuje `[+2.22 / dubina 24]`.

**Sitnije:**

- [ ] Strelice: ponovo povučena ista strelica se briše; „Poništi strelicu" vraća
      poslednju; „Izbriši sve strelice" i dalje briše sve. Provera i u sobi, gde
      se promena emituje, i u studiju, gde se ne emituje.
- [ ] Postavljanje pozicije: dodir na polje sa **istom** figurom je uklanja, dug
      pritisak i desni klik prazne polje bez brisača. Oba dijaloga — sobin i onaj
      u Analysis Studio-u.
- [ ] „Uvezi PGN (fajl ili tekst)" otvara dijalog; nalepljena partija se učita, a
      nalepljen izvoz sa više partija ponudi izbor (to staro polje nije umelo).
- [ ] „Taktika po vašoj meri" izgovara poruke kao „Završnice" — i **ćuti** kad se
      pređe na sledeću zagonetku ili napusti ekran. Windows bez srpskog glasa i
      dalje ćuti, kao i dosad.
- [ ] Traka sa čipovima poteza („Početak", „1. Bd1", …) više se ne pojavljuje
      **nigde**, a grafičko stablo rešenja u „Mat u N poteza" je netaknuto.

---

## 44. Strana igrača u vežbama protiv motora — 28.8.2026, delimično viđeno uživo

Prijavio korisnik: u vežbi protiv motora može se u stablu poteza vratiti na
poziciju gde je motor na potezu, odigrati taj potez sam, i od tada motor igra
ono što je bila korisnikova strana. Uzrok je bio da pojam „korisnikova strana"
nije ni postojao — motor je bio definisan čisto reaktivno.

Zamena je namerno **ostavljena kao mogućnost** (gledati kako motor igra tvoju
stranu je razlog zbog kog neko to radi), ali se sada javlja, a presude se čitaju
sa table kroz `outcomeFor` umesto iz kategorije vežbe.

**Viđeno uživo, korisnik, 28.8.2026** (`Vežbanje: easy — Matirajte Stockfish-a`):

- [x] Povratak u stablu na motorov potez, odigran ručno → traka **„↔ Od ove
      pozicije igrate crnim, Stockfish belim"**, i motor od tog trenutka vuče
      belim. Potvrđeno i logom: `b8c7`, `c7b6` (crni kralj), pa `d4d6`, `c4c5`,
      `d7e7`, `e7a7` (beli top i kralj).
- [x] Mat koji je motor zadao → dijalog **„Mat — Stockfish vam je zadao mat"**
      sa „Pokušaj ponovo" i „Sledeća Pozicija".

- [x] **`Pronađite dobitni put` (`winning_position`) kad motor zada mat** —
      korisnik, 28.8.2026. Ovo je bila kategorija u kojoj je bag zapravo živeo:
      ranije se tu prikazivao dijalog **pobede** („Uspešno ste zadali mat
      Stockfish-u") i vežba se obeležavala kao rešena. Sada se ponaša isto kao
      `basic_mate` — traka o zameni strana i dijalog poraza.

**Nije viđeno:**

- [ ] Pobeda **posle** zamene strana: matirati novom stranom → mora „POBEDA",
      ne poraz.
- [ ] Pat/remi posle zamene → „🤝 Pat / Remi u poziciji", bez ijednog dijaloga.
- [ ] „Pokušaj ponovo" u dijalogu poraza vraća **istu** poziciju, a „Sledeća
      Pozicija" učitava novu.
- [ ] Da traka o zameni **ne** iskoči kad se igra normalno, od prvog do
      poslednjeg poteza svojom stranom.

---

## 45. Migracija na tokene — 29.8.2026, nije viđeno uživo

Paketi 14–43 su spojeni u `master` (`71d3452`): 90 fajlova, ceo vizuelni sloj
prebačen na tokene razmaka, tipografije i boje. **Testovi i kapije to ne mogu da
provere** — boja nema kapiju koja zna koju je ulogu literal tražio, a 805 zelenih
testova kaže samo da se ništa nije srušilo. Ovo se proverava očima.

**Prvi pogled, telefon, debug build — korisnik 29.8.2026:** „Na telefonu
ekstra izgleda.“ Dakle ništa razbijeno na prvi pogled, i to je vredno — 90
fajlova je moglo da iseče red van ekrana. **Nijedna stavka ispod se time ne
štiklira**, jer nisu prošle jedna po jedna: opšti utisak i provera trake
evaluacije u obe orijentacije nisu ista tvrdnja. Ovo je bio build
`8404148 • debug`.

**Prvo ono što bi pogrešna zamena pokvarila tiho:**

- [ ] **Traka evaluacije, obe orijentacije.** Belo je dole kad je tabla okrenuta
      belom, gore kad je okrenuta crnom. Zamena grana u ternaru ovde okreće
      traku za pola korisnika, a svi testovi ostaju zeleni.
- [ ] **Vodoravna traka evaluacije** u AI studiju — bela i crna polovina, broj
      preko granice između njih mora da se čita (nosi crni poteg).
- [ ] **Traka ishoda u eksploreru otvaranja**: tri polja, belo / remi / crno,
      moraju da se razlikuju međusobno i od panela iza.
- [ ] **Birač strelica**: izabrani krug ima svetlu ivicu i kvačicu.
- [ ] Galerija dizajna, maketa trake evaluacije — ista slika kao prava traka.
- [ ] **Traka sa ciljem u AI studiju (paket 44) sada ima jednu boju umesto
      dve.** Ranije se bojila po strani koju igraš (blueGrey / teal); sada je
      `infoContainer`, a strana se vidi po ivici i ikonici. Ovo je jedina
      namerna vidljiva promena iz paketa 44 — pogledati je li razlika još
      čitljiva na telefonu.
- [ ] Traka faze u Analysis Studiju (završnica) — indigo panel je sada
      `groupedContainer`; ivica i ikonica moraju da se vide na njemu.
- [ ] Traka sa vežbama u Analysis Studiju — bila teal, sada `surfaceRaised`,
      dakle neutralna. Proveriti da se i dalje razlikuje od panela ispod.

**Zatim ekrani koje su paketi 32–40 prošli**, jer je tu menjan i razmak i
tipografija, a ne samo boja:

- [ ] Podešavanja, prijava, početni ekran, Analysis Studio, AI Studio, traka
      koraka u kursu.
- [ ] **Na telefonu, i to prvo u DEBUG buildu.** Ovo je ispravka onoga što je
      ovde prvo pisalo („u release buildu“), jer je obrazloženje bilo naopako:
      release **ne** crta žuto-crne pruge preko prelivanja — red koji je postao
      preširok se samo iseče i dugmad iza ivice ne postoje. Debug ih crta i puca
      na tvrdnji, pa je on instrument za ovaj prolaz; release ide posle, da se
      vidi šta korisnik zapravo dobija i kako radi punom brzinom.
      Cena: debug i release nisu potpisani istim ključem, pa prelazak traži
      `adb uninstall rs.pejovic.chesscoach` i odnosi prijavu i podešavanja na
      tom telefonu. Sporost i trzanje u debug buildu **nisu** nalaz.

Ako nešto izgleda pomereno a ne pokvareno, to je i dalje nalaz: paketi su
menjali razmake na skalu, pa je „izgleda drugačije“ očekivano, a „izgleda
razbijeno“ nije.

---

## 46. Nalazi sa živog prolaza 29.8.2026 — nije viđeno uzivo

Četiri stvari prijavljene sa telefona i Windows-a istog dana, sve popravljene
i sve nepregledane. Prva je jedina koja je nešto činila **nedohvatljivim**.

### Dijalog za unos pozicije (ISSUE-015)

- [ ] Telefon, tab „Ručno Slaganje“: sva četiri čipa za rokadu (`K`, `Q`, `k`,
      `q`) moraju da se vide i da se mogu dodirnuti. Do 29.8.2026. su tri bila
      iza desne ivice — u release buildu bez ijednog traga da postoje.
- [ ] Telefon: dijalog je sada širi (inset 12 umesto 40 po strani), tabla bi
      trebalo da dobije oko 56 piksela.
- [ ] Windows: „Postavi poziciju“ ide u dve kolone (tabla levo, paleta i
      kontrole desno) i **ne sme da traži skrolovanje** da bi se stiglo do
      „Učitaj na tablu“.
- [ ] Windows: „Unos Pozicije (Board Setup)“ je 760 širok umesto 550.

### Info panel posle skeniranja (ISSUE-012)

- [ ] Skeniraj pozicije → Sačuvaj: traka ima **X** i može da se sklonu, pa se
      vidi poslednji red pozicija.
- [ ] Napustiti ekran dok traka stoji → traka nestaje sama.
- [ ] „Pogledaj“ vodi u „Moje pozicije“ i posle promene ekrana, umesto da pukne
      i ostane zaglavljena. **Ovo nije pokriveno testom** — da bi se ekran doveo
      u to stanje treba pravi fajl i mrežni scan, pa je ovo jedina provera koja
      postoji.

### Navigacija (ISSUE-013 i ISSUE-014)

- [ ] Windows i telefon u pejzažu: uz ikone u rail-u stoje i nazivi (Trening,
      Časovi, Biblioteka, Ljudi), i rail time nije pojeo previše širine.
- [ ] Sva četiri taba imaju naslov na vrhu, na istom mestu i istim stilom.
- [ ] Prvi tab (Trening) ima **jedan** naslov, ne dva — njegov sopstveni AppBar
      se unutar tabova više ne crta.
- [ ] Trening otvoren kao ruta (ne kao tab) i dalje ima svoj AppBar sa putem
      nazad.

## 47. Tabla se crta iz teme, ne iz slike — 29.8.2026, nije viđeno uživo

Faza 2 plana iz [PLAN-TEME-I-TABLA.md](PLAN-TEME-I-TABLA.md). Do sada je tablu
crtao `flutter_chess_board` — četiri gotove PNG slike, biralo se enumom. Sada je
crta `SkinnedChessBoard` iz `BoardSkin`, a figure uzimaju boje iz `PieceSkin`.
Podrazumevana koža (`classic`) nosi **iste piksele** koje je nosila i slika
(#F0DAB5 / #B58763), pa provera nije „da li je lepše" nego **da li se išta
promenilo**.

Testovi pokrivaju bojenje polja, boje figura, pokrivku ispod animacije i
promociju; ono što test ne vidi je kako to izgleda na pravom ekranu.

Proveriti, na Windows buildu i na telefonu:

1. **Tabla izgleda isto kao pre** na svim ekranima sa tablom — soba za čas,
   Analysis Studio, AI studio, plejer snimka, dijalog sa linijom motora.
   Ivice između polja su sada oštre; pre su bile mutne, jer je slika 375 px, a
   375/8 nije ceo broj.
2. **Dijalog sa linijom motora** je jedina tabla koja je *namerno* bila druge
   boje (zelena) — sada je iste kao i ostale.
3. **Prevlačenje pešaka na poslednji red pita na srpskom.** Ranije je taj jedan
   put otvarao dijalog paketa: „Choose promotion", i to sa četiri **bele**
   figure ma ko bio na potezu. Proveriti i za crnog.
4. **Odustajanje u tom dijalogu ne odigra potez.**
5. **Animacija poteza** — figura kliza, a polje na koje sleće je prekriveno
   svojom bojom dok ne stigne. Gledati da ne bljesne rupa ni pogrešna boja,
   posebno pri kretanju sa svetlog na tamno polje.
6. **Vučena figura je velika koliko i polje.** Ranije je bila fiksnih 45 px —
   slučajno tačno na telefonu od 360 dp, premala na svakom desktop ekranu.
7. **Editor pozicije** (i onaj u Analysis Studiju) i **sličice u listama** crtaju
   istu tablu kao i ona velika. Do sada su bili tri različita: mrka, zelena i
   tirkizna.

Kože se u fazi 2 još nisu birale — u katalogu je bila samo `classic`. Birač je
došao u fazi 5 (stavka 49), a ostale kože u paketu 46 (stavka 48).

## 48. Kože table i figura — 29.8.2026, nije viđeno uživo

Paket 46 dodao je pet tabli i tri kompleta figura. **Birač postoji od faze 5**
(stavka 49), u Podešavanjima → „IZGLED". Proveriti:

1. **Svaku tablu sa svakim kompletom figura**, na telefonu. Brojke kažu da sve
   ivice figura prolaze 3.0:1 na oba polja svake table; ono što brojke ne kažu
   je kako izgleda `Visoki kontrast` (bele figure su **žute**, #FFFF00) — to je
   odluka koju treba videti pre nego što se ponudi deci.
2. **Bela figura na tabli „Visoki kontrast"** je čist obris: belo na belom polju
   meri 1.00:1 po ispuni, a nosi ga crna ivica na 21:1. Namerno, ali treba
   videti da li se čita.
3. **Oznaka poslednjeg poteza, po koži.** Ovo je u međuvremenu rešeno bez
   gledanja — oznaka je dobila crno-bele uglove, jer je merenje reklo da amber
   sam nosi 1.03:1 u najgorem slučaju. Ostaje da se pogleda kako **izgleda**, ne
   da li se vidi: stavka 50.
4. **Animacija poteza na svakoj koži** — pokrivka polja uzima boju te table, pa
   svaka koža ima svoju.

## 49. Birač teme, table i figura — 29.8.2026, nije viđeno uživo

Faza 5 plana iz [PLAN-TEME-I-TABLA.md](PLAN-TEME-I-TABLA.md): odeljak „IZGLED" u
Podešavanjima, iznad „NALOG". Testovi tvrde šta se iscrtava posle dodira; ono što
ne vide je kako to izgleda i da li se iko u tome snađe.

Proveriti, na Windows buildu i na telefonu:

1. **Svetla tema.** Ovo je prvi put da je iko vidi na pravom ekranu — pisana je
   28.8.2026 i do sada je bila mrtav kod. Proći kroz **sve** ekrane, ne samo
   Podešavanja: soba za čas, Analysis Studio, AI studio, trening, zadaci,
   izveštaji. Tražiti tekst koji je nestao u podlogu i ivicu koje nema.
2. **Sistemska tema prati telefon.** Prebaciti telefon u noćni režim dok je
   aplikacija otvorena — tema se menja bez ponovnog pokretanja.
3. **Izbor preživi gašenje aplikacije.** Izabrati svetlu, ubiti proces, otvoriti
   ponovo. Ovo je ono što je do juče bilo pokvareno: `init()` je prepisivao
   sačuvani izbor na `dark` na svakom pokretanju.
4. **Tabla se ne menja sa temom.** Izabrati zelenu tablu, pa prebaciti temu iz
   tamne u svetlu — tabla ostaje zelena. To je namerno i to je jedina stvar oko
   koje je plan bio izričit.
5. **Pločice se ne prelamaju čudno** na telefonu od 360 dp. Red teme se namerno
   prelama 2 + 1; table idu 3 + 2, figure 2 + 1. Ako je uređaj uži ili je font
   uvećan, gledati da ništa nije odsečeno — release build ne crta prugice.
6. **Pregled figura je čitljiv.** Četiri figure na 30 px; ako se na telefonu ne
   raspoznaje razlika između „Klasične" i „Tople", pregled ne radi svoj posao i
   polje treba da poraste.
7. **Kartica motora i kartica naloga** — dva reda koja su se prelivala (303 px i
   26 px) sada su `Expanded`. Proveriti da natpis nije prelomljen ružno i da
   vrednost desno stoji gde je i stajala.

Stavka 48 je spisak *kombinacija* koje treba pogledati kad birač postoji; ova je
o samom biraču.

## 50. Oznaka poslednjeg poteza i crno-beli uglovi — 29.8.2026, nije viđeno uživo

Amber ispuna i obod su ostali; preko njih se sada crtaju **četiri prava ugla ka
unutra**, crni oreol sa belim jezgrom. Razlog je merenje, ne ukus: `warning` na
45% naspram polja ispod sebe daje **1.03:1** u najgorem slučaju, pa se oznaka
videla samo kao promena tona — a ton je ono što crveno-zeleni deficit oduzima.
Detalji i brojke su u [STANJE-RADA.md](STANJE-RADA.md), odeljak „Vid i boje".

Testovi tvrde da se uglovi crtaju, na oba polja poteza, i da im boje drže ivicu
na svakoj koži. Ono što test ne vidi je da li oznaka sada izgleda pretrpano.

**Provereno uživo, sa screenshot-ima u oba pravca.** Jedna prava greška nađena
i popravljena usput — birač je zatamnjivao boje koje prikazuje (`7bc589f`),
otkriveno tako što je vlasnik poslao sliku pločica, pa su boje **izmerene onako
kako se crtaju** umesto procenjene okom.

Šta je potvrđeno:

1. ✅ **Obrub nije predebeo.** Strelice se čitaju na plavoj i klasičnoj koži, u
   obe teme, i nijedna se ne gubi u polju.
2. ✅ **Rangovi motora se i dalje razlikuju po debljini** — 1. linija je vidno
   deblja od 5.
3. ✅ **Značka evaluacije u svetloj temi.** Ovo je bio pravi bag: tekst je merio
   **1.55:1**. Potvrđeno na svih pet rangova u obe teme — `+0.13` belim na
   ljubičastoj, `+0.17` crnim na narandžastoj, `+0.05` belim na crvenoj.
4. ✅ **Plava i ljubičasta se razlikuju.** Ovo je najvrednija potvrda u celoj
   stavci: par je tačno na 1.50:1, što je dokazani plafon, i ja sam ostavio
   otvoreno pitanje da li je to dovoljno u praksi. **Vlasnik projekta, koji je
   daltonista, kaže da ih razlikuje.** Znači kanal (isprekidana linija, slovo uz
   rep strelice) **ne treba dodavati** — ako neko ubuduće bude „popravljao" taj
   par, ovo je razlog da ne.
5. ✅ **Pločice u biraču**, posle popravke: pet boja, prava boja, slova C, N, Z,
   P, Lj.

Ostaje samo ovo, i traži decu a ne programera:

- **Da li slova na pločicama deci znače nešto** na 28 px. Ako ne, alternativa je
  oblik a ne veća pločica.
- Koža „Visoki kontrast" nije gledana sa strelicama; beli deo obruba se tu gubi
  na čisto belom polju, i to je u redu jer crni nosi — ali nije viđeno.

Original stavke, radi traga šta je traženo:

1. **Da li je oznaka prejaka.** Uglovi su 28% stranice polja, jezgro 7%, oreol
   oko 15%. Na tabli od 360 dp to je ugao od ~13 px. Ako deluje kao da viče,
   smanjuje se `arm` i `coreWidth` u `_paintLastMoveBrackets` — ali **ne** tako
   što se vrati na samo boju.
2. **Sve kože.** Uglovi su isti na svih pet tabli, jer su crno-beli; treba
   videti da nigde ne izgledaju kao greška u crtanju, posebno na „Visoki
   kontrast" gde je svetlo polje čisto belo (belo jezgro se tu gubi, i to je u
   redu — crni oreol nosi).
3. **Figura na obeleženom polju.** Ugao i figura dele polje. Gledati da ugao ne
   seče figuru tako da se ne prepoznaje koja je.
4. **Animacija poteza preko obeleženog polja** — pokrivka polja se crta ispod
   ove oznake.
5. **Obe teme.** Amber dolazi iz `warning`, koji je različit u svetloj i tamnoj
   paleti; uglovi nisu i ne menjaju se.

Ako oznaka prođe, ovo zatvara i tačku 3 stavke 48.

## 51. Strelice — boje, obrub, značka i birač — ✅ vlasnik projekta, 29.8.2026

Pet boja strelica je promenjeno, svaka strelica je dobila crno-beli obrub, tekst
značke evaluacije se više ne bira iz teme, a pločice u biraču imaju slova.
Brojke i razlozi su u [STANJE-RADA.md](STANJE-RADA.md), odeljci „Zašto je prag za
strelice 1.5" i „Ožičenje strelica".

Proveriti, na telefonu i na Windows buildu:

1. **Da li je obrub predebeo.** Crni je +5 px a beli +2.5 px preko strelice od
   6 px, pa je ukupno 11 px tamo gde je pre bilo 6. Na tabli od 360 dp to je
   osetno deblje. Ako smeta, menjaju se `arrowHaloShadeWidth` i
   `arrowHaloLightWidth` — ali **ne** tako što se obrub ukloni.
2. **Strelice motora i dalje idu od debele ka tankoj.** Rang 1 je 7 px, rang 5
   je 1 px; sa obrubom to postaje 12 i 6. Poredak je očuvan, ali proveriti da se
   peta linija još uvek vidi kao tanja, a ne kao „ista strelica".
3. **Značka evaluacije u svetloj temi.** Ovo je bio pravi bag: tekst je bio
   1.55:1 i praktično nečitljiv. Otvoriti Analysis Studio u svetloj temi sa
   uključenim strelicama motora i pročitati brojku na svakoj od pet.
4. **Slova na pločicama birača — sada ih je pet: Z, C, P, N, Lj.**

   Vlasnik je 29.8.2026. prijavio da vidi samo četiri (Z, C, P, N) i bio je u
   pravu: birač je nudio `G`, `R`, `B` i `O`, dok je katalog držao pet.
   Ljubičastu je motor crtao za 4. liniju a niko nije mogao da je izabere. Ova
   stavka je prvo tražila da se provere pet slova i to je bila **greška u
   stavci** — činjenica je stajala u komentaru uz stari `arrowPalette`, obrisan
   pri ožičenju.

   Popravljeno tako da se ne može ponoviti: red se **generiše iz
   `ArrowColor.all`** umesto da se nabraja, pa se šesta boja pojavljuje time što
   postoji. Red je i `Wrap` a ne `Row`, jer pet krugova od 28 px sa razmacima
   ide na oko 190 dp, a release build seče bez reči.

   Ostaje da se pogleda: **da li se slova čitaju na 28 px i znače li deci
   nešto.** Ako ne, alternativa je oblik a ne veća pločica.

   **Zamka pri čitanju koda:** slovo na *plavoj* pločici je `P` (Plava), a `P`
   je ujedno i *id* ljubičaste (`Ljubičasta`). U interfejsu se ne sudaraju — svih
   pet slova je različito — ali u kodu i u dokumentima se lako pomešaju.
5. **Plava i ljubičasta strelica jedna pored druge.** Merenje kaže 1.50, što je
   plafon; render pod simulacijom kaže da su vrlo slične. Pitanje za oko: da li
   je to problem u praksi, s obzirom da onaj ko crta bira iz obeleženog birača.
   Ako jeste, sledeći korak je kanal (isprekidana linija ili slovo uz rep), ne
   nova boja.
6. **Sve na koži „Visoki kontrast"**, gde je svetlo polje čisto belo — beli deo
   obruba se tu gubi, i to je u redu, jer crni nosi.

## 52. Uvoz sopstvene arhive partija — 30.8.2026, nije viđeno uživo

Prva stvar u projektu koja u bazu upisuje **stvarne partije korisnika**, i prva
koja jedan HTTP poziv drži otvorenim minutima. Sve što piše dole je testirano
kodom (13 testova, uključujući dokaz mutacijom za deljenje streama) i nijednom
gledano kako radi.

Priprema: nalog na koji se prijavljuje mora imati Lichess korisničko ime koje se
unosi ručno — veze naloga sa Lichess-om još nema.

0. [ ] **Otpremanje fajla je glavni put** (`POST /games/import/file`,
   multipart, polje `archive`). Korisnik sam skine PGN sa Lichess-a i preda ga
   aplikaciji. Na fajlu od 8,7 MB (4126 partija) servis je izmeren van HTTP-a:
   40 s, 209 MB RSS, nijedna partija preskočena. Ono što se **nije** videlo je
   kako se to ponaša kroz multipart na dropletu i da li se privremeni fajl
   zaista briše kad run završi.
1. [ ] **`POST /games/import` vrati 202 i `importId` odmah**, ne posle četiri
   minuta. Ako čeka, ruta ne radi ono zbog čega je napisana.
2. [ ] **Cela arhiva stigne.** Na kraju `GET /games/imports/:id` mora imati
   `status = done` i `games_read = games_stored + games_duplicate +
   games_skipped`. Za arhivu od ~4126 partija očekuje se ~4126 upisanih i
   nula preskočenih — na PGN fajlu od 29.8.2026 modul nije odbio nijednu.
3. [ ] **Drugi uvoz odmah zatim povuče skoro ništa.** Ovo je provera da
   `since` radi: `games_read` mali, `games_duplicate` eventualno 1 (poslednja
   partija se ponovo pročita namerno), `games_stored` 0 ako se ništa nije
   igralo u međuvremenu.
4. [ ] **Drugi uvoz *tokom* prvog vrati 409**, a ne dva paralelna streama.
5. [ ] **Nepostojeći nalog** vrati 404 sa porukom koja imenuje nalog, i run
   ostane `failed` sa tim razlogom upisanim.
6. [ ] **Sat i otvaranje su stvarno u redovima.** `GET /games/stats` treba da
   pokaže `with_clocks` blizu ukupnog broja za noviju arhivu, i `reached_
   tablebase` oko 11% (na merenoj arhivi 471 od 4126).
7. [ ] **Server ostaje odazivan dok uvoz traje.** Uvoz je pozadinski posao u
   istom procesu; ako se soba ili čas u međuvremenu koče, to treba znati pre
   nego što se pusti korisnicima.
8. [ ] **Veličina.** Posle uvoza pogledati koliko je `user_games` zauzeo na
   dropletu od 960 MB — `moves` i `clocks` su nizovi po partiji, a ovo je prva
   tabela koja raste sa istorijom korisnika, ne sa njegovim radom u aplikaciji.

### Ekran za uvoz (30.8.2026, nije viđeno uživo)

Dodat 30.8.2026, zajedno sa izveštajem ispod. Do njega se stiže preko kartice
„Moje partije" u treningu, u sekciji Otvaranje.

- [ ] **Četiri brojača stoje na telefonu od 360 dp i sabiraju se.** Test to
  tvrdi nad izdvojenim `ImportCounters` i dokazan je mutacijom (kao `Row`
  prelivaju se za 358 px prazni i 860 px sa razlozima), ali nijednom nije
  viđeno kroz pravi uvoz.
- [ ] **`preskočeno` nije go broj.** Uvesti PGN u koji je namerno ubačena
  partija u nekoj varijanti i partija bez poteza, pa proveriti da piše
  „preskočeno 2: 1 nije standardni šah, 1 bez poteza".
- [ ] **`importId` prolazi.** `user_game_imports.id` je `BIGSERIAL`, a
  node-postgres `int8` vraća kao **string**; klijent zato broj čita kroz
  `jsonInt`. Ovo je jedina stvar ovde koja bi pukla na prvom pravom uvozu i
  nijedan widget test je ne može uhvatiti, jer lažni servis vraća `int`.
- [ ] **Anketa na 2 s ne ostaje da radi** kad se ekran napusti usred uvoza.
- [ ] **Dugme „Pogledaj rupe u otvaranju"** se pojavi tek kad je run `done` i
  vodi na izveštaj sa istim korisničkim imenom pod kojim je uvoz išao.

## 53. Izveštaj o otvaranjima — 30.8.2026, nije viđeno uživo

Prva analiza koja se oslanja na uvezenu arhivu. Sve dole je mereno van baze, na
PGN fajlu, kroz isti kod koji ide u produkciju — ali nijednom kroz Postgres.

1. [ ] **`GET /games/openings/leaks?subject=...` vrati nalaze.** Očekivano na
   arhivi od 4126 partija: oko 78 označenih pozicija, najjača sa 121 partijom i
   prolaznošću oko 41%. Ako vrati prazno a `games` je veliko, pogledati
   `gamesWithoutNodes` — to znači da čvorovi nisu upisani, ne da nema slabosti.
2. [ ] **`gamesWithoutNodes` je 0 posle uvoza**, i različit od nule za partije
   uvezene pre nego što je `opening_nodes` postojala. Za njih
   `POST /games/openings/backfill`, pa opet provera da je palo na nulu.
3. [ ] **Prozor se ne da proširiti.** `&toPly=30` mora da vrati 400 sa
   objašnjenjem, a ne kraći izveštaj.
4. [ ] **Brzina upita.** Ovo je prvi `GROUP BY` nad tabelom koja po korisniku
   ima desetine hiljada redova; izmeriti koliko traje na dropletu, ne samo da
   li radi.
5. [ ] **Suđenje bez tokena ne obara izveštaj.** `&judge=true` bez
   `X-Lichess-Token` mora da vrati brojeve i `judge.reason = 'no-token'`.
6. [ ] **Suđenje sa tokenom** — proveriti da je deset zahteva zaista deset, i
   da `unknown` ostaje `unknown` umesto da se prikaže kao greška.
7. [ ] **Nalaz ima smisla za igrača.** Jedina provera koju kod ne može da
   uradi: da li je pozicija koju izveštaj proglasi navikom zaista mesto gde
   vlasnik projekta misli da igra loše.

### Ekran izveštaja (30.8.2026, nije viđeno uživo)

- [ ] **Tabla u redu je okrenuta prema boji.** Crtana je kroz `BoardThumbnail`,
  kome je dodat `isWhiteBottom`; proveriti da red za crnog nije nacrtan naopako
  i da polja nisu zamenila boje.
- [ ] **Suđenje se ne pokreće samo od sebe.** Izveštaj se otvara samo sa
  brojevima, a `judge=true` ide tek na dugme „Presudi poteze" — troši
  korisnikov Lichess token. Test to tvrdi i dokazan je mutacijom; uživo treba
  videti da se posle klika zaista pojavi presuda i da dugme nestane.
- [ ] **Bez tokena izveštaj ostaje.** Kliknuti „Presudi poteze" bez tokena u
  Podešavanjima: brojevi moraju ostati, a poruka o tokenu se pojaviti pored
  njih, ne umesto njih.
- [ ] **`unknown` se ne crta kao greška.** Nema značke „Sumnjiv potez" nad
  pozicijom koju niko nije ocenio.
- [ ] **Boja nije jedini kanal.** Svaka značka nosi i ikonu i srpski naziv
  („Glavna teorija", „Sumnjiv potez"); vlasnik projekta je daltonista i ovo je
  provera koju samo on može da uradi.
- [ ] **Dugme za dopunu** se pojavi kad je `gamesWithoutNodes > 0` i nestane
  posle dopune.

## ~~54. Provera završnica preko Syzygy tablica~~ — funkcija uklonjena 31.8.2026

Vlasnik je odustao: dva izvora za jedan odgovor, predugo, i pukao proces.
Ništa ispod se više ne proverava.

Prvi posao u projektu koji minutima priča sa tuđim servisom u pozadini. Sve dole
je mereno lokalno, kroz produkcioni kod, ali nijednom uz stvarnu tablicu.

1. [ ] **`POST /games/endgame/audit` vrati 202 odmah**, pa
   `GET /games/endgame/audits/:id` prati napredak. Očekivano na arhivi od 4126
   partija: `games_total` oko 471, `positions_probed` oko 4255, trajanje oko
   10–11 minuta prvi put.
2. [ ] **Drugi prolaz je gotovo trenutan.** `cache_hits` mora da bude blizu
   `positions_probed` iz prvog prolaza, a `positions_probed` blizu nule. Ako
   nije, keš ne radi i to je jedina stvar koja ovu funkciju čini ponovljivom.
3. [ ] **`positions_unknown` je vidljiv i nije nula bez objašnjenja.** Ako
   tablica ne presudi mnogo pozicija, to treba da se vidi kao broj, ne da
   nestane.
4. [ ] **Nalazi imaju smisla.** `GET /games/endgame/mistakes` vraća pozicije
   sortirane po veličini pada. Otvoriti dve-tri na tabli i proveriti da je
   „imao si dobijeno" zaista tačno — ovo je jedina provera koju kod ne može da
   uradi umesto čoveka.
5. [ ] **Presude su rekonstruisane iz `mistake_reviews`**, sa `wdl_before` i
   `wdl_after` na svakom redu, i drugi prolaz ne pravi duplikate (isti
   `user_id, game_id, ply`).
6. [ ] **Tablica koja padne ne ostavlja poluzavršen posao kao uspešan** — run
   mora da završi kao `failed` sa razlogom, a ne kao `done`.
7. [ ] **Server ostaje odazivan** dok deset minuta traje pozadinski posao u
   istom procesu. Isto pitanje kao kod uvoza, i još nije odgovoreno.

## 55. Ponavljanje sopstvenih grešaka — 30.8.2026, nije viđeno uživo

1. [ ] **Nalazi iz provere završnica su odmah na redu za ponavljanje.**
   `GET /games/mistakes/due` treba da ih vrati bez ijednog dodatnog koraka —
   provera završnica ih upisuje sa `due_at` na sada.
2. [ ] **Ocena pomera rok.** Oceniti istu stavku sa „good" pa proveriti da je
   `due_at` otišao unapred i `interval_days` porastao; pa „again" na drugoj i
   provera da se vratila u isti dan.
3. [ ] **Isti SM-2 kao lekcije.** Ista ocena nad stavkom sa istim
   `ease_factor`/`repetitions` mora da da isti interval kao u ponavljanju
   lekcija. Ovo test već tvrdi, ali vredi videti brojeve jednom uživo.
4. [ ] **Tuđa partija se ne može podmetnuti.** `POST /games/mistakes` sa
   `gameId` koji nije korisnikov mora da vrati `game-not-yours` u tally-ju, a
   ne da upiše red.
5. [ ] **Tally se slaže.** Poslati paket u kome je nekoliko nalaza namerno
   pokvarenih i proveriti da `read = stored + duplicate + rejected` i da su
   razlozi imenovani.
6. [ ] **`recurrence` daje rečenicu koja ima smisla.** Za arhivu vlasnika
   projekta, da li „stalno gubiš topovske završnice" odgovara utisku? Ovo je
   provera koju kod ne može da uradi.
7. [ ] **Ponovni upis istog nalaza ne pravi duplikat** (isti
   `user_id, game_id, ply`).

## ~~56. Repertoar iz arhive~~ — sejanje uklonjeno 31.8.2026

Pisalo je u isti graf kao ručna izgradnja, pa su uvezeni potezi bili
nerazlučivi od odluka. Poređenje (diff) ostaje i proverava se u stavci 60.

1. [ ] **Prvo `dryRun`.** `POST /games/repertoire/seed` sa `dryRun: true` mora
   da vrati plan i **ništa** ne upiše. Očekivano na arhivi od 4126 partija:
   oko 648 pozicija i 1132 poteza pri podrazumevanom pragu.
2. [ ] **Sejanje ne gazi ručni repertoar.** Napraviti jednu poziciju ručno sa
   `primary` potezom, pa pustiti sejanje — taj `primary` mora da ostane, a novi
   potezi da uđu kao `alternate`.
3. [ ] **Koliko traje.** 1132 poteza je 2264 upita; izmeriti stvarno vreme na
   dropletu. Ako pređe petnaestak sekundi, sejanje treba da pređe na obrazac
   pozadinskog posla, isti kao uvoz i provera završnica.
4. [ ] **Ponovno sejanje ništa ne kvari** — drugi prolaz treba da doda nula
   novih poteza i ne promeni nijednu ulogu.
5. [ ] **Diff daje rečenicu.** `GET /games/repertoire/diff` mora da vrati tri
   broja: partije koje su stigle u pripremljenu poziciju, koliko ih je pratilo
   pripremu i koliko je izašlo. Proveriti da zbir prve dve daje treću.
6. [ ] **Rupa nije izlazak.** Pozicija koju repertoar ne pokriva ne sme da se
   pojavi u diff-u.
7. [ ] **Drill radi nad zasejanim repertoarom.** Postojeći trenažer repertoara
   mora da radi nad onim što je sejanje napravilo, bez ijedne izmene — ako ne
   radi, sejanje piše nešto što drill ne ume da pročita.

## 57. Profil igrača van otvaranja — 30.8.2026, nije viđeno uživo

1. [ ] **`GET /games/profile?username=` vraća brojeve koji se poklapaju sa
   merenjem van baze.** Očekivano: po dužini 696 / 2196 / 1234 partije sa
   45,5% / 51,3% / 53,6%; po fazi 3237 / 418 / 471 sa 49,6% / 50,5% / 61,5%.
   Ako se razlikuju, ne veruj ni jednom broju dok se ne nađe zašto.
2. [ ] **Sat.** `clock.atMove20` treba da da gradijent 23,8% → 48,2% → 50,9% →
   53,7%, a `clock.hurriedShare` oko 0,379.
3. [ ] **Uzorak je ograničen i prijavljen.** `clock.sampled` ne sme tiho da
   bude manji od `gamesWithClocks` — ako jeste, to je granica uzorka i mora da
   se vidi u interfejsu.
4. [ ] **Brzina.** Sedam `GROUP BY` upita plus čitanje do 2000 nizova sa satom;
   izmeriti koliko traje na dropletu. Nizovi su ono što ovde nosi bajtove.
5. [ ] **Partije bez sata ne kvare profil** — starije od trenutka kad ih je
   Lichess počeo beležiti moraju da se prebroje u `gamesWithClocks` a da ne uđu
   u proseke.
6. [ ] **Dva broja se ne smeju prikazati kao nalaz**: red „ispod 30 s" (21
   partija) i „kratke partije idu lošije". Prvi je premali uzorak, drugi je
   pitanje a ne odgovor.

## 58. Domaći iz učenikove arhive — 30.8.2026, nije viđeno uživo

Jedina funkcija u ovom planu koja prelazi između naloga, i većina tih naloga su
deca. Provera se radi sa **dva naloga** — trenerskim i učeničkim — i vezom koja
je prihvaćena.

1. [ ] **Nepovezani trener ne prolazi.** `POST /assignments/from-archive` sa
   `studentId` deteta koje nije na listi mora da vrati 403, a u bazi ne sme da
   ostane nijedan novi red u `custom_puzzles` ni u `assignments`.
2. [ ] **Veza koja čeka odgovor ne prolazi.** Isto to sa vezom u stanju
   `pending` — mora 403.
3. [ ] **Prvo `dryRun`.** Sa `dryRun: true` trener vidi izabrane pozicije i
   ništa se ne upisuje; kvota se vraća.
4. [ ] **Zadatak stigne detetu.** Bez `dryRun`, učenik dobija obaveštenje i
   zadatak se vidi u njegovoj listi, a pozicije nose uputstvo na srpskom
   („U ovoj poziciji si odigrao … Nađi bolji potez.").
5. [ ] **Skup nije osam istih zadataka.** Pogledati zadatih osam pozicija —
   treba da pokrivaju različite teme, ne isti motiv osam puta.
6. [ ] **Tuđa arhiva ne ulazi.** Ako učenik uveze protivnikove partije
   (`subject_is_owner = false`), one ne smeju da se pojave ni u domaćem ni u
   trenerskom pregledu.
7. [ ] **Ponovno generisanje ne pravi duplikate pozicija** — `puzzle_id` se
   izvodi iz same greške, pa drugi prolaz treba da ponovo upotrebi iste
   pozicije.
8. [ ] **Trenerski pregled**: `GET /assignments/student/:id/archive` daje
   `leaks`, `mistakes`, `recurrence` i `trend`. Proveriti da `trend` nije nigde
   prikazan kao „pre i posle" — to je pitanje za interfejs, a odgovor je ne.

## 59. Priprema za protivnika i AI opis — 30.8.2026, nije viđeno uživo

Prva stvar u projektu koja čita o **osobi koja nikad nije otvorila aplikaciju**,
i zato jedina koja stiže isključena. Sve dole je pokriveno kodom (40 testova,
sedam dokaza mutacijom) i nijednom pušteno.

Priprema: `OPPONENT_PREP_ENABLED=true` u `.env`, i tek onda ostalo. Dok stoji na
`false`, tačka 1 je jedina koja se može proveriti — i mora da prođe.

1. [ ] **Isključeno znači odbijeno, ne prazno.** `POST /games/prep/import` bez
   uključenog prekidača mora da vrati 403 i `reason: 'disabled'`. Prazan
   izveštaj bi se čitao kao „protivnik nema slabosti", što je jedini odgovor
   koji isključena funkcija ne sme da da.
2. [ ] **Ništa se ne dohvata dok je isključeno.** Proveriti da u `user_games`
   nije upisan nijedan red posle odbijenog poziva.
3. [ ] **`subject_is_owner = FALSE` na svakom uvezenom redu**, i — odmah zatim —
   da `GET /games/stats` i dalje broji samo igračeve partije. Ovo je provera
   zbog koje je `services/archiveScope.js` i napisan.
4. [ ] **`vs=` vraća samo međusobne partije.** Uvesti protivnika sa
   `vs=<sopstveni handle>` i proveriti da je broj partija onaj koji Lichess
   pokazuje na profilu, a ne ceo arhiv.
5. [ ] **`opening=true` zaista donosi `[ECO]` i `[Opening]`.** Kolone `eco` i
   `opening` u `user_games` ne smeju biti prazne posle ovog uvoza — arhiv od
   29.8.2026 ih nema samo zato što je izvezen bez te zastavice.
6. [ ] **Pogrešan `perfType` je odbijen, ne prećutan.** `perfType=bliz` mora da
   vrati 400. Lichess bi ga ignorisao i vratio sve tempo-kontrole, što izgleda
   isto kao ispravan odgovor.
7. [ ] **Rejting prag odbija pre nego što išta upiše.** Sa
   `OPPONENT_PREP_MIN_RATING` iznad protivnikovog rejtinga: 403, i nijedan red
   u bazi. Provera posle uvoza bi značila da već držimo arhiv koji smo hteli da
   odbijemo.
8. [ ] **Odbijenica ne odaje rejting.** Poruka sme da imenuje prag, ne i broj
   koji je taj čovek dobio.
9. [ ] **Dnevni limit broji ljude, ne uvoze.** Dva uvoza istog protivnika su
   jedan čovek.
10. [ ] **Retencija briše samo protivnike.** Postaviti
    `OPPONENT_PREP_RETENTION_DAYS=0` na dan kad ima i svojih i tuđih partija,
    pa vratiti na 30 i proveriti da su igračeve netaknute. Igračev arhiv je
    jedina stvar ovde koja se ne može ponovo dohvatiti.
11. [ ] **Izveštaj o protivniku ide kroz postojeću rutu.**
    `GET /games/openings/leaks?subject=<protivnik>` mora da radi bez ijedne nove
    rute — to je bio ceo argument da se sekcija 7 gradi posle sekcije 1.
12. [ ] **AI opis: ime ne izlazi sa servera.** Ovo se ne vidi iz odgovora nego
    iz loga — proveriti da u zahtevu ka Gemini-ju nema handle-a. Test to tvrdi;
    uživo treba videti jednom.
13. [x] **Izmišljen broj ne prolazi** — Claude, 30.8.2026, prvi prolaz nad
    stvarnim modelom (`gemini-flash-latest`, osam poziva). Tri rečenice su
    prošle i u sve tri je **svaki** broj ručno upoređen sa tabelom: udeo 76%,
    prolaznost 38%, e5 na 51%, 12. polupotez a6 u 98% na 38%, 16. polupotez
    Ng4 u 98% na 39%. Nijedan izmišljen. Ostaje da se ponovi nad **stvarnom**
    arhivom umesto nad fiksiranim izveštajem, i sa Pro modelom kad bude
    dostupan — ovo je jedan model, jedan izveštaj i osam poziva, što nije
    dokaz nego prvi znak.

    Nađeno pritom, i popravljeno: model je pisao „udeo 0.76" i
    „prolaznost 0.38". Svaki broj tačan, i nečitljiv za dete. Prompt sada
    **zahteva** procente umesto što ih dozvoljava, a test pada ako to pravilo
    nestane. Zaštita od izmišljenih brojeva ne hvata prozu koja je tačna i
    beskorisna.
14. [ ] **Bez ključa nema rečenice, ali ima izveštaja.** Ukloniti
    `GEMINI_API_KEY` i proveriti da ruta i dalje vraća 200 sa
    `reason: 'model-unavailable'`.

## 60. Ekrani za greške i repertoar iz arhive — 30.8.2026, nije viđeno uživo

Batch 48, agent za dizajn, pregledano istog dana. Do drila se stiže preko
kartice „Moje greške" u treningu; do poređenja repertoara sa ekrana za uvoz,
pošto mu treba korisničko ime.

1. [ ] **Boja stiže kao „w", ne „white".** Ovo je uhvaćeno pri pregledu i
   popravljeno, ali nijednom nije viđeno kroz pravi server: ekran drži
   „white"/„black" jer to piše na dugmetu, a `requireColor` prima samo slova i
   vraća 400. Otvoriti poređenje repertoara i proveriti da uopšte odgovori.
   Isto važi za zasejavanje.
2. [ ] **Izveštaj bez boje ne puca.** `color: null` sa servera znači „obe
   boje", ne „nedostaje polje".
3. [ ] **Greška bez `best_uci` se ne nudi kao zadatak.** Filtriranje postoji u
   kodu; uživo treba videti da drill ne prikaže poziciju na koju nema odgovora.
4. [ ] **Ocena pomera rok.** Oceniti isti nalaz sa „Dobro" pa proveriti da je
   `due_at` otišao unapred, i da rečenica koju ekran prikaže dolazi sa servera
   (`description`), a ne da je sastavljena iz broja.
5. [ ] **Tablebase nalaz nema centipione.** Za `kind = 'tablebase'` ne sme da
   piše „0 centipoena" — taj nalaz taj broj nema.
6. [ ] **Ponavljanja se ne mešaju.** Motivi i završnice su dve liste; ništa se
   ne rangira preko obe.
7. [ ] **Zasejavanje prvo pokazuje plan.** `dryRun` mora da se vidi pre nego
   što se bilo šta upiše, i drugi pritisak da bude svestan.
8. [ ] **`uci` stiže u poređenju.** Dodat na backendu 30.8.2026 baš zbog ovog
   ekrana; proveriti da drill može da odigra potez iz poređenja, i da
   `unplayable` bude nula.


## 61. Ulaz u arhivu i ime zasejanog repertoara — ✅ delimično, vlasnik projekta, 30.8.2026

Batch 51 i 52. Dve stavke su viđene uživo i potvrđene; treća, provera završnica,
**i dalje nije** — vidi stavku 54 i napomenu na kraju.

1. ✅ **Arhiva ima ulaz koji preživljava uvoz.** `Trening → Moje partije` vodi
   na `/archive`, arhiva od 4126 partija se vidi bez ponovnog uvoza, i sva
   četiri prolaza (rupe u otvaranju, završnice, repertoar, profil) su odatle
   dostupna. Ovo je bio kvar zbog kog je ekran bio neupotrebljiv: dugmad su
   postojala samo u sekundama posle uvoza, a ponovni uvoz iste datoteke daje
   `games_stored = 0` jer je svaka partija duplikat, pa se nisu vraćala.
2. ✅ **Zasejani repertoar se vidi u listi, sa imenom.** `repertoire_moves`
   pripada paru (korisnik, boja) i sejanje nije pisalo red u `repertoires`, pa
   je 2376 poteza ležalo tamo gde ih niko ne vidi. Sada `ensureRepertoire`
   upisuje „Iz mojih partija — beli" odnosno „— crni", pa se pojavljuje i crni
   repertoar koji ranije nije imao nijednu karticu.

**Šta ovde još nije potvrđeno, i namerno se ne štiklira:**

3. [ ] **Provera završnica se pokreće i ne obara aplikaciju.** Ovo je original
   kvar od 30.8.2026 i **nije ponovljen uživo posle popravki**. Dok se ne vidi
   kako brojači rastu, ne znamo ni da li se aplikacija i dalje gasi, ni da li
   tempiranje prema Lichess-u drži na 471 partiji. Stavka 54 ostaje otvorena u
   celini.
4. [ ] **Trag posle pada.** `CrashBreadcrumbService` hvata Dart izuzetke.
   Original pad je bio gašenje procesa, koje nikad ne stigne do Dart rukovaoca
   — ako se prozor opet zatvori a `crash.log` ostane prazan, to je nalaz, ne
   propust: znači da uzrok nije Dart izuzetak.

## 62. Putanja i izvedena granica u repertoaru — 31.8.2026, nije viđeno uživo

Sve ispod se proverava u „Repertoar → otvori repertoar", nad repertoarom koji
već ima nešto izgrađeno. Backend mora biti pokrenut jednom **posle** ove izmene,
da `ALTER TABLE repertoires ADD COLUMN root_path` prođe.

1. [ ] **Linija piše iznad table.** Otvoriti repertoar napravljen *posle* ove
   izmene (igranjem poteza od početne pozicije, pa „gradi odavde"). Iznad
   pitanja „Šta igrate belim/crnim?" mora da stoji cela linija od prvog poteza,
   numerisana kao u knjizi.
2. [ ] **Stari repertoar ne laže.** Otvoriti repertoar napravljen *pre* ove
   izmene — `root_path` mu je prazan, pa numeracija ide iz FEN-a korena
   (`4...Nc6 5.Nf3`). Ne sme da se pojavi „1." ako partija tu nije počela.
3. [ ] **Nastavlja se tamo gde je stalo.** Ući u izgradnju, uzeti odgovore za
   jednu poziciju, izaći na Nazad, pa opet ući. Mora da ponudi iste pozicije, u
   istom redosledu, i **brojač „upita:" mora da ostane 0** dok se ne odigra
   potez — ako skoči, granica se ne izvodi nego se ponovo kupuje.
4. [ ] **Glavna linija ide prva.** Pri povratku prva ponuđena pozicija treba da
   bude ona sa najvećim `reach`, ne najplića. Proveriti da dublja pozicija na
   glavnoj liniji pretekne pliću stranputicu.
5. [ ] **Pozicija koja čeka odgovore to i kaže.** Izabrati potez i izaći **ne**
   pritisnuvši „dalje". Pri povratku ta pozicija mora da se vrati sa rečenicom
   „ovde ste već izabrali potez — ostalo je samo da uzmete odgovore", a ne kao
   prazno pitanje.
6. [ ] **Ugašen server ne izgleda kao gotov posao.** Ugasiti backend i otvoriti
   izgradnju: mora da se vidi koren i rečenica „počinjete od početne pozicije
   repertoara", nikako ekran „Nema više pozicija u redu".
7. [ ] **Brojevi u zaglavlju imaju smisla.** „odlučeno / otvoreno / bez odgovora
   %" — na praznom repertoaru „bez odgovora" je 100%, i mora da pada kako se
   grade linije koje se zaista sreću.
8. [ ] **Telefon.** Sve gore na 360 dp: linija poteza može da bude duga, pa
   proveriti da ne izlazi iz ekrana u *release* build-u, gde nema žuto-crnih
   pruga.

## 63. Strelice sa statistikom u izgradnji repertoara — 31.8.2026, nije viđeno uživo

1. [ ] **Moji potezi se vide na tabli.** U poziciji u kojoj već imam izabran
   potez, strelica mora da stoji na tabli, sa zvezdicom na glavnom. Proveriti da
   se glavni razaznaje **bez gledanja u boju** — zvezdica i debljina linije.
2. [ ] **Procenat uz moj potez.** Kad je knjiga otvorena (posle odigranog
   poteza), uz strelicu stoji i udeo, npr. `★ 60%`. Kad knjiga nije otvorena
   (pozicija se vraća iz ranije sesije), stoji samo `★` — i **brojač „upita:"
   ne sme da se pomeri** zbog crtanja strelice.
3. [ ] **`Dalje` staje umesto da preskoči.** Posle `Dalje` ekran mora da pokaže
   „Odgovori protivnika", strelice protivnikovih poteza sa procentima, i dugme
   `Sledeća pozicija`. Ranije je odmah prelazio na sledeću poziciju.
4. [ ] **Tabla je zaključana u tom stanju.** Pokušati povući potez dok su
   odgovori na tabli — ne sme da se odigra ništa.
5. [ ] **Linija poteza uključuje moj potez.** U stanju odgovora linija iznad
   table mora da se završava mojim potezom, jer je tabla pomerena za njega.
6. [ ] **Rep je imenovan.** Ako ima nepokrivenih poteza, mora da piše koliko ih
   je i koliko procenata partija nose — to je jedini pošten način da se kaže da
   repertoar nije gotov.
7. [ ] **Telefon, 360 dp.** Panel „Odgovori protivnika" ima dug pasus i red po
   odgovoru. Proveriti u *release* build-u, gde nema žuto-crnih pruga.

## 64. Red po dometu i odsecanje grane — 31.8.2026, nije viđeno uživo

Sve u „Repertoar → otvori repertoar". Backend mora biti pokrenut jednom **posle**
ove izmene, da tabela `repertoire_skips` nastane.

1. [ ] **Nova linija pretiče staru stranputicu.** Ući u izgradnju gde u redu
   stoji bar jedna plitka stranputica. Uzeti potez na glavnoj liniji i pritisnuti
   `Dalje`, pa `Sledeća pozicija`. Sledeće pitanje mora da bude iz linije koja je
   tek otvorena, ako je njen procenat veći — ne ona koja je u redu duže.
2. [ ] **Isti red posle izlaska.** Zapamtiti prve tri linije u redu, izaći na
   Nazad i vratiti se. Redosled mora biti isti, i **brojač „upita:" mora ostati
   0** dok se ne odigra potez.
3. [ ] **„Ne spremam ovo" postoji i nestaje na korenu.** Dugme se vidi na svakoj
   poziciji osim na korenu repertoara — tamo ga ne sme biti.
4. [ ] **Rez odnosi i ono ispod.** Odseći granu koja u redu ima potomke (liniju
   po kojoj se već išlo dublje). Poruka mora da kaže koliko je pozicija izašlo iz
   reda, i te pozicije se ne smeju kasnije pojaviti.
5. [ ] **Odsečeno se broji odvojeno.** U zaglavlju mora da se pojavi
   `odsečeno N (X%)`, a „bez odgovora %" ne sme da se pravi da je posao urađen —
   procenat odsečenog je udeo partija koje se i dalje igraju.
6. [ ] **Rez preživi izlazak.** Izaći na Nazad i vratiti se: odsečena grana se ne
   sme vratiti u red sama od sebe. Ovo je jedina provera koja stvarno gleda bazu.
7. [ ] **Vraćanje radi, i sa praznog ekrana.** Pritisnuti `Vrati odsečenu granu`
   — grana se vraća u red na svoje mesto. Isto probati kad je rez ispraznio red i
   vidi se ekran „Nema više pozicija": dugme mora biti i tamo.
8. [ ] **Potez u odsečenoj poziciji nije izgubljen.** Ako je u odsečenoj poziciji
   ranije izabran potez, drill i dalje sme da ga traži — odsecanje kaže dokle se
   sprema, ne šta se zaboravlja.
9. [ ] **Ugašen server ne laže o rezu.** Ugasiti backend i pritisnuti „Ne spremam
   ovo": mora da piše da grana **nije** odsečena i pozicija ostaje na ekranu.
10. [ ] **Telefon, 360 dp.** Traka sada ima peto dugme. Proveriti u *release*
    build-u, gde nema žuto-crnih pruga.

## 65. Vežba kao linija, blok i početak od poznatog — 31.8.2026, nije viđeno uživo

Sve u „Repertoar → dugme sa tegom" nad repertoarom koji ima bar jednu liniju
dugu tri-četiri poteza.

1. [ ] **Pitanje stiže na kraju linije.** Umesto gole table mora da piše
   „Ponovite liniju", iznad table cela linija numerisana kao u knjizi, i „potez 1
   od N do pitanja".
2. [ ] **Protivnik odgovara sam.** Posle vašeg poteza protivnikov odgovor se
   odigra bez pitanja, i linija iznad table poraste za oba poteza.
3. [ ] **Ponavljanje se ne ocenjuje.** Namerno odigrati **pogrešan** potez u
   ponavljanju: mora da piše „U ovoj liniji ide X. Ponavljanje se ne ocenjuje.",
   potez linije ode na tablu, i **ne sme** da se pojavi ocena („Tačno", „Nije
   to", „Vraća se za...").
4. [ ] **Na kraju linije je pravo pitanje.** Kad se prefiks potroši, ekran kaže
   „Šta igrate belim/crnim?" i tek taj potez se ocenjuje.
5. [ ] **Kreće od poznatog.** Uvežbati jednu poziciju do tri tačna ponavljanja
   (vraća se za nekoliko minuta, pa opet), pa uzeti liniju koja ide ispod nje:
   ponavljanje mora da počne **od te pozicije**, uz rečenicu „odatle dokle znate
   napamet", a ne od početka repertoara.
6. [ ] **Preskakanje radi.** Dugme „Preskoči ponavljanje" vodi pravo na pitanje,
   a linija iznad table i dalje pokazuje ceo put.
7. [ ] **Blok iz jednog čvora.** U izgradnji, na nekoj poziciji, pritisnuti
   „Vežbaj ovu granu": vežba sme da pita **samo** pozicije iz te grane. Proveriti
   da pozicija iz druge grane ne dođe na red.
8. [ ] **Prazna grana to i kaže.** Isto dugme na poziciji ispod koje još nema
   ničega: mora da piše „U ovoj grani nema šta da se vežba", nikako „Još nema šta
   da se vežba".
9. [ ] **Odsečena grana se ne ponavlja.** Odseći granu (stavka 64), pa otvoriti
   vežbu: nijedna pozicija ispod reza ne sme da bude pitanje.
10. [ ] **Ugašen server ne ćuti.** Ugasiti backend i otvoriti vežbu: ili prazan
    ekran sa razlogom, ili staro pitanje uz rečenicu „bez ponavljanja" — nikako
    ekran koji izgleda kao da je sve naučeno.
11. [ ] **Telefon, 360 dp.** Linija iznad table može da bude duga. Proveriti u
    *release* build-u, gde nema žuto-crnih pruga.

## 66. Radar pokrivenosti — 31.8.2026, nije viđeno uživo

Spisak repertoara → ikonica radara u redu (na mestu gde je ranije bila strelica
udesno).

1. [ ] **Grane se vide, najigranija prva.** Svaka nosi liniju numerisanu kao u
   knjizi, ime otvaranja ako ga knjiga zna, i „igra se u X% partija".
2. [ ] **Tri broja, i sva tri pišu.** „spremljeno X% · bez odgovora Y%", i
   „odsečeno Z%" samo ako je nečega odsečeno. Zbir spremljeno + bez odgovora +
   odsečeno mora biti 100% po grani.
3. [ ] **Retka grana se ne hvali.** Napraviti granu koja se igra u malom
   procentu i ne dirati je: mora da piše „spremljeno 0%", a ne visok procenat
   zato što kroz nju ide malo partija.
4. [ ] **Odsečena grana nije gotova grana.** Odseći granu (stavka 64) i otvoriti
   mapu: mora da stoji „odsečeno 100%" i makaze, nikako kvačica i „spremljeno".
5. [ ] **Bez boje se sve razaznaje.** Pogledati ekran i proveriti da se stanje
   svake grane čita iz ikonice i teksta — kvačica, peščani sat, makaze — i da
   nijedna informacija ne postoji samo kao boja.
6. [ ] **Obe vrata rade.** „Gradi ovde" otvara izgradnju baš u toj grani;
   „Vežbaj granu" otvara vežbu koja pita samo pozicije iz nje.
7. [ ] **Grana bez ijedne odluke nema dugme za vežbu.** Tamo nema šta da se
   pita, pa se dugme ne nudi.
8. [ ] **Prazan repertoar i ugašen server izgledaju različito.** Nov repertoar
   bez ijednog poteza → „Prvi potez još nije izabran". Ugašen backend → „Mapa
   nije mogla da se pročita", nikako prazna mapa.
9. [ ] **Dubina ima smisla.** „do N. poteza posle korena" mora da raste kako se
   grana produbljuje.
10. [ ] **Telefon, 360 dp.** Linija grane može da bude duga i ispod nje stoje dva
    dugmeta. Proveriti u *release* build-u, gde nema žuto-crnih pruga.

## 67. Vežba van rasporeda i stablo repertoara — 31.8.2026, nije viđeno uživo

Prva tri iz prvog prolaza vlasnika kroz trenažer (31.8.2026).

1. [ ] **Prazna vežba kaže kada se vraća.** Uzeti granu u kojoj je sve već
   vežbano: mora da piše „U ovoj grani ništa nije na redu." i „Sledeća se vraća
   sutra / za N dana", a ne samo da ničega nema.
2. [ ] **„Vežbaj ipak" postoji i radi.** Dugme se vidi kad ima šta da se vežba a
   ništa nije dospelo; klik otvara pitanje, a u zaglavlju piše „van rasporeda".
3. [ ] **Vežba van rasporeda se ne upisuje.** Odgovoriti tačno, pa se vratiti:
   ista pozicija mora i dalje da bude nedospela, i **ne sme** da piše „Vraća se
   za N dana". Ovo je jedina provera koja stvarno gleda bazu.
4. [ ] **Prazna grana i dalje nema to dugme.** U grani u kojoj nikad ništa nije
   izgrađeno „Vežbaj ipak" se ne nudi.
5. [ ] **Stablo se otvara sa radara.** Ikonica stabla u zaglavlju „Pokrivenost".
6. [ ] **Potez bez uzetih odgovora se vidi na crtežu.** Otvoriti stablo
   repertoara u kome je potez izabran a „Dalje" nije pritisnuto: taj potez mora
   da bude kartica sa `…`, ne da nedostaje.
7. [ ] **Kartice kažu stanje bez boje.** Proveriti da se na crtežu razaznaju
   `★` (glavni), procenat uz protivnikov potez, `?`, `…` i `✂`.
8. [ ] **Dubina radi.** Prebaciti na 8 poluporeza: crtež se skrati i pojavi se
   rečenica da je skraćen. Vratiti na 24 i proveriti da se produbi.
9. [ ] **Velik repertoar ne obara ekran.** Otvoriti stablo nad zasejanim
   repertoarom („Iz mojih partija") na 24 poluporeza — proveriti da se crta i da
   zumiranje radi.
10. [ ] **Obe vrata sa crteža.** Klik na protivnikov potez → „Gradi odavde" i
    „Vežbaj ovu granu" vode u tu poziciju. Klik na **svoj** potez → umesto
    dugmadi stoji rečenica da je tamo protivnik na potezu.
11. [ ] **Ugašen server.** Stablo mora da kaže da nije moglo da se pročita, ne
    da je repertoar prazan.

## 68. Spremanje poteza iz repa — 31.8.2026, nije viđeno uživo

Backend mora biti pokrenut jednom **posle** ove izmene, da nastane tabela
`repertoire_extra_replies`.

1. [ ] **Spisak se otvara i sklapa.** U izgradnji, posle „Dalje", ispod rečenice
   „Van pripreme još N poteza" stoji „Spremi i neki od njih". Klik otvara spisak
   nepokrivenih poteza sa procentom i brojem partija; ponovni klik ga sklapa.
2. [ ] **„Spremi" radi i kaže šta je uradio.** Klik na dugme uz jedan potez →
   poruka „U pripremi je i X" i red se produži za jedan.
3. [ ] **Ulazi po dometu, ne na vrh.** Ako je potez redak, ne sme odmah da bude
   sledeće pitanje — proveriti da brojač „Još N u redu" poraste, ali da sledeća
   pozicija ostane ona sa većim procentom.
4. [ ] **Preživljava izlazak — ovo je jedina provera koja stvarno gleda bazu.**
   Spremiti jedan potez iz repa, izaći na Nazad, pa ponovo ući u izgradnju: ta
   pozicija mora i dalje da bude u redu. Ako nestane, šetnja ne prati dodate
   poteze.
5. [ ] **Dodat potez se vidi i na stablu i na radaru.** Otvoriti stablo: nova
   grana mora da postoji sa `?`. Na radaru „bez odgovora %" te grane raste, jer
   je pripremljeno više nego ranije a odgovora još nema.
6. [ ] **Dvaput isti potez nije greška.** Ako se isti potez spremi dvaput (npr.
   posle povratka na istu poziciju), ne sme da se pojavi greška — samo poruka da
   je već u pripremi.
7. [ ] **Ugašen server ne laže.** Ugasiti backend i pritisnuti „Spremi": mora da
   piše da potez **nije** dodat, i red ne sme da poraste.
8. [ ] **Tuđa priprema ostaje tuđa.** Ovo se ne može proveriti sa jednim
   nalogom, ali vredi zapamtiti: dodavanje je po korisniku, i ne sme da promeni
   šta drugi nalog vidi kao pokriveno.
9. [ ] **Telefon, 360 dp.** Red repa ima potez, procenat, broj partija i dugme.
   Proveriti u *release* build-u, gde nema žuto-crnih pruga.

## 69. Čišćenje uvezenih poteza i brisanje repertoara — 31.8.2026, nije viđeno uživo

1. [ ] **Menija ima na svakom redu.** U spisku repertoara, uz dugme sa tegom
   stoji ⋮ sa četiri stavke: Pokrivenost, Stablo poteza, Očisti poteze iz uvoza,
   Obriši repertoar.
2. [ ] **Stablo se otvara odatle.** Ovo je i odgovor na „ne vidim stablo" —
   ranije je bilo samo u zaglavlju Pokrivenosti.
3. [ ] **Brojanje pre brisanja.** „Očisti poteze iz uvoza" prvo javlja koliko
   poteza i u koliko pozicija nema zapis da ste ih vi izabrali, i **kaže da je
   to procena**. Odustajanje ne sme ništa da obriše.
4. [ ] **Brisanje smanjuje graf.** Posle potvrde, broj poteza u spisku (redak
   „N poteza u grafu") mora da padne, i to za obe kartice iste boje.
5. [ ] **Ono što ste sami izabrali ostaje.** Pre čišćenja izgraditi ručno bar
   jednu poziciju; posle čišćenja ona mora i dalje da bude tu, sa zvezdicom.
6. [ ] **Nijedna pozicija ne ostaje bez glavnog poteza.** Otvoriti drill posle
   čišćenja: mora da pita normalno, bez pozicija na koje nema odgovora.
7. [ ] **Brisanje repertoara ne dira poteze.** Obrisati „Iz mojih partija —
   beli": kartica nestaje, a drugi repertoar iste boje i dalje ima svoje poteze.
8. [ ] **Nema više dugmeta za sejanje.** Na ekranu „Repertoar iz partija" nema
   „Izvuci repertoar iz partija", a stoji rečenica da se uvezene partije u
   repertoar ne upisuju.
9. [ ] **Nema više provere završnica.** Na ekranu arhive i posle uvoza nema
   dugmeta „Proveri završnice". Ponavljanje grešaka i dalje radi, uključujući
   nalaze iz završnica koji su ranije upisani.

## 70. Stablo pored table — 31.8.2026, nije viđeno uživo

1. [ ] **Na Windows-u su tabla i stablo jedno pored drugog.** Otvoriti
   repertoar: desno od table stoji crtež, i prostor koji je ranije bio prazan
   sada nosi stablo.
2. [ ] **Tabla je veća nego ranije** na punom prozoru, ali pitanje ispod nje se
   i dalje vidi bez skrolovanja.
3. [ ] **Traka ispod table.** Roditelj → trenutna pozicija → deca, sa oznakama
   (★, procenat, ?, …, ✂). Dodir na stavku vodi tamo.
4. [ ] **Dodir na protivnikov potez vodi tablu na tu poziciju**, i linija iznad
   table se produži.
5. [ ] **Dodir na svoj potez stavlja tablu posle njega**, a ispod stoji
   „Posle X — šta igra protivnik" iz sačuvane knjige. Brojač „upita:" se ne sme
   pomeriti. Dugme „Nazad na X" vraća pitanje na poziciju iz koje je potez
   odigran.
6. [ ] **Red nije poremećen.** Posle skakanja po stablu, „Preskoči" i „Dalje"
   i dalje rade, i „Još N u redu" se nije promenio zbog samog skakanja.
7. [ ] **Crtež prati tablu.** Posle „Uzmi" i „Dalje", stablo se osveži i nova
   grana se vidi bez ručnog osvežavanja.
8. [ ] **Telefon, 360 dp, release build.** Panel je ispod kontrola, sklopljen.
   Ovo je mesto gde je nađen preliv od 180 px u zaglavlju panela — proveriti da
   se ništa ne seče, naročito naslov „Stablo Varijanti".
9. [ ] **Analiza i dalje radi.** Isti panel se koristi u Analizi; otvoriti je i
   proveriti da zaglavlje izgleda normalno na širokom prozoru.
10. [ ] **Nema više zasebnog ekrana za stablo.** U spisku repertoara u ⋮ meniju
    nema stavke „Stablo poteza", i u zaglavlju „Pokrivenost" nema ikonice
    stabla — jer je stablo tamo gde se gradi.
11. [ ] **Dodir na poziciju na kojoj tabla već stoji ne briše ništa.** Pitati
    motor, sačekati linije, pa dodirnuti tu istu karticu: linije ostaju.

## 71. Nacrt, potvrda i rejting traka — 31.8.2026, nije viđeno uživo

Backend mora biti pokrenut jednom **posle** ove izmene, da prođe
`ALTER TABLE repertoire_moves ADD COLUMN source`.

1. [ ] **Postojeći potezi su i dalje vaši.** Otvoriti repertoar napravljen
   ranije: nijedan potez ne sme da piše „predlog — nije još vaš izbor", i drill
   mora da radi kao pre. Kolona ima podrazumevanu vrednost `chosen`, i ovo je
   provera da je to zaista tako u vašoj bazi.
2. [ ] **Traka rejtinga postoji i pamti se.** U zaglavlju spiska repertoara,
   ikonica sa ljudima → 1400 / 1600 / 1800 / 2000, sa kvačicom na 1600.
   Promeniti na 1800, izaći iz aplikacije i vratiti se: izbor je zapamćen.
3. [ ] **Traka menja knjigu.** Sa 1400 pa sa 2000, na istoj poziciji otvoriti
   „Ne znam": spisak poteza i procenti moraju da se razlikuju. Ako su isti,
   traka nije stigla do zahteva.
4. [ ] **Brojač upita.** Promena trake znači novu knjigu, pa prvi zahtev u novoj
   traci troši upit; drugi put na istoj poziciji ne sme.
5. [ ] **Nacrt se vidi kao nacrt.** Ovo se može proveriti tek kad postoji
   auto-kičma (korak 3). Do tada je dovoljno da ništa ne piše „predlog".
6. [ ] **Zaglavlje broji nacrte odvojeno.** Kad ih bude, u redu „odlučeno · …"
   pojavljuje se i „nacrt N", i taj broj se ne sabira sa „odlučeno".

## 72. Auto-kičma — 31.8.2026, nije viđeno uživo

Traži **vaš Lichess token** (isti kao sudija), jer troši vašu kvotu.

1. [ ] **Dugme postoji na svakoj poziciji.** U izgradnji, „Napravi kičmu" →
   dijalog sa 4 / 6 / 8 / 10 / 12 poteza i rečenicom da su to predlozi.
2. [ ] **Prazan repertoar dobije deblo.** Napraviti nov repertoar i pustiti
   kičmu na 6 poteza: red poraste, stablo dobije granu, i poruka ispiše celu
   liniju numerisanu kao u knjizi.
3. [ ] **Sve što je upisala piše „predlog".** U „Vaši potezi ovde" svaki takav
   potez ima „predlog — nije još vaš izbor" i dugme „Potvrdi".
4. [ ] **Vežba ih ne pita.** Odmah posle kičme otvoriti vežbu: ne sme da traži
   nijedan potez koji niste potvrdili. Ako pita — filter po `source` ne radi.
5. [ ] **Potvrda menja to.** Potvrditi jedan potez pa otvoriti vežbu: sada sme
   da ga pita.
6. [ ] **Ponovno pokretanje ne gazi.** Odigrati svoj potez na nekoj poziciji
   (svesno **drugi** od predloženog), pa pustiti kičmu ponovo od korena: vaš
   potez mora da ostane, i kičma mora da nastavi kroz njega.
7. [ ] **Staje i kaže zašto.** Pustiti kičmu na 12 poteza u nekoj retkoj liniji:
   poruka mora da kaže da je stalo jer je pretanko, sa brojem partija i pragom.
8. [ ] **Bez tokena kaže da nema tokena**, ne „greška na serveru".
9. [ ] **Brojač upita raste.** „upita:" u zaglavlju mora da poraste otprilike
   dvostruko od broja poteza koje je napisala.
10. [ ] **Traka rejtinga se poštuje.** Ista pozicija na 1400 i na 2000 ume da
    da različitu kičmu — proveriti bar da se prvi potez ili procenti razlikuju.
11. [ ] **Telefon, 360 dp.** Traka kontrola sada ima sedam dugmadi. Proveriti u
    *release* build-u, gde nema žuto-crnih pruga.

## 73. Orezivanje po dohvatljivosti — 31.8.2026, nije viđeno uživo

1. [ ] **Uklanjanje poteza odnese nacrte iza njega.** Pustiti kičmu, pa ukloniti
   jedan potez blizu korena (× u „Vaši potezi ovde"): javi „Uklonjeno i N poteza
   do kojih se više nije moglo stići", i stablo se skrati.
2. [ ] **Vaši potezi se ne brišu bez pitanja.** Napraviti ručno bar dva poteza
   duboko u jednoj liniji, pa ukloniti potez iznad njih: mora da se pojavi
   pitanje „Ostalo je bez veze" sa brojem, i „Ostavi" ne sme ništa da obriše.
3. [ ] **„Obriši i njih" briše.** Isto, ali potvrditi: potezi nestaju iz stabla.
4. [ ] **Transpozicija preživi.** Ovo je poenta cele stavke. Napraviti dve
   linije koje se spajaju (npr. 2.Nf3 Nc6 3.Nc3 i 2.Nc3 Nc6 3.Nf3), pa ukloniti
   potez sa jedne: zajednička pozicija i sve ispod nje moraju da ostanu.
5. [ ] **Odsečena grana se ne briše.** Odseći granu, pa ukloniti neki potez
   drugde: rad iza reza mora da ostane, jer rez nije brisanje.
6. [ ] **Uklanjanje bez posledica ćuti.** Ukloniti potez iza koga nema ničega:
   nema poruke o orezivanju i nema pitanja.
7. [ ] **Nijedna pozicija ne ostaje bez glavnog poteza.** Posle svega otvoriti
   vežbu: mora da pita normalno.

## 74. Odgovori protivnika uz tablu — 31.8.2026, nije viđeno uživo

1. [ ] **Panel stoji sam od sebe.** U izgradnji, na poziciji gde već imate
   glavni potez, ispod „Vaši potezi ovde" stoji „Posle X — šta igra protivnik".
   Nije potrebno pritisnuti „Dalje".
2. [ ] **Ne troši upit.** Brojač „upita:" ne sme da poraste ni za jedan dok se
   samo krećete kroz pozicije koje su ranije otvarane.
3. [ ] **Neotvorena pozicija nudi da se otvori.** Na poziciji koju niko nije
   otvarao piše „još niko nije otvarao" i stoji „Otvori knjigu (1 upit)".
   Pritisak poveća brojač tačno za jedan, i lista se pojavi.
4. [ ] **„Idi" vodi tablu.** Klik na „Idi" uz pripremljen odgovor pomeri tablu
   na poziciju posle njega, i linija iznad table poraste za dva poteza.
5. [ ] **„Spremi" dodaje u pripremu.** Klik uz odgovor van pripreme: red poraste
   i taj odgovor sledeći put nosi „Idi" umesto „Spremi".
6. [ ] **Posle „Dalje" nema dve iste liste.** Kad su odgovori talasa na ekranu,
   ovaj panel se ne prikazuje.
7. [ ] **Telefon, 360 dp.** Red ima potez, procenat, broj partija i dugme.
   Proveriti u *release* build-u.

## 75. Ocena motora na čvoru — 31.8.2026, nije viđeno uživo

1. [ ] **Ocena ostaje.** U izgradnji pritisnuti „Pitaj motor", sačekati, otići
   na drugu poziciju i vratiti se: uz tablu piše „Sačuvano: +0.35 · dubina 20 ·
   datum". Zatvoriti ekran i otvoriti ga ponovo — i dalje piše.
2. [ ] **Dubina i datum se vide.** Oboje u istom redu sa ocenom, i datum je
   današnji.
3. [ ] **Plića ocena ne gazi dublju.** Postaviti dubinu na 30, pitati motor;
   pa na 12 i pitati opet. Broj i „dubina 30" moraju ostati.
4. [ ] **„Evaluiraj celu liniju (N pozicija)".** N je broj pozicija bez ocene
   te dubine, a ne dužina linije. Posle prolaza dugme kaže „Cela linija je
   ocenjena" i ne može da se pritisne.
5. [ ] **Prolaz može da se zaustavi.** Tokom prolaza piše „Ocenjujem liniju:
   3/9" i stoji „Zaustavi". Pritisak zaustavi prolaz, a poruka kaže posle koje
   je pozicije stao.
6. [ ] **Brojač „upita:" se ne miče.** Ni za jedan, ni pri pojedinačnom pitanju
   ni tokom celog prolaza — ovo je lokalni motor.
7. [ ] **Ocene su na karticama stabla.** Posle prolaza kartice u grafičkom
   stablu nose broj u zagradi.
8. [ ] **„Gde se motor ne slaže".** Otvara spisak sortiran po ceni neslaganja;
   dodir na red vodi tablu na tu poziciju. Red koji nosi „nacrt" je potez koji
   je napisala kičma, a ne vi.
9. [ ] **Tri različite tišine.** Pre bilo kakvog računanja spisak kaže „motor
   još nije pitan"; kad se sve slaže, kaže da se slaže i sa koliko od koliko.
10. [ ] **Nema druge presude na kartici.** Uz potez i dalje stoji samo ono što
   kaže sudija otvaranja; ocena motora nigde ne nosi „dobar"/„loš".
11. [ ] **Telefon, 360 dp.** Panel motora, dugme sa brojem i dijalog spiska —
   proveriti u *release* build-u da ništa nije odsečeno.

## 76. Gradnja bez kviza, i stablo koje se može menjati — 31.8.2026, nije viđeno uživo

1. [ ] **„Šta se ovde igra" stoji samo od sebe**, na svakoj poziciji, i brojač
   „upita:" se ne miče dok se krećete kroz pozicije koje je neko otvarao.
2. [ ] **„Igraj" iz liste** ponudi potez na isti način kao potez povučen po
   tabli — sa sudijom i sa „Uzmi X".
3. [ ] **Dugmeta „Ne znam" nema.** Neotvorenu poziciju i dalje otvara „Otvori
   knjigu (1 upit)", i brojač poraste tačno za jedan.
4. [ ] **Dva panela se razlikuju.** „Šta se ovde igra" (pozicija na tabli) i
   „Posle X — šta igra protivnik" (posle vašeg glavnog poteza) ne smeju da
   izgledaju isto ni da nose isto dugme.
5. [ ] **Desni klik na moj potez u stablu.** „Unapredi u glavnu liniju" zaista
   promeni glavni potez (zvezdica se pomeri), „Obriši ovu varijantu" ga ukloni.
6. [ ] **Desni klik na protivnikov potez.** „Obriši ovu varijantu" odseče granu
   (ista poruka kao „Ne spremam ovo"), a „Unapredi" kaže da to nije vaš potez.
7. [ ] **Odsečena grana nestane iz crteža**, a iznad stabla piše „Prikaži
   odsečene grane (N)". Klik je vrati, klik ih opet sakrije.
8. [ ] **Paleta ispod table.** Strelice napred/nazad/početak/kraj rade, i
   **tastatura** takođe (←, →, Home, End).
9. [ ] **Numeracija počinje od prave pozicije.** Repertoar građen od četvrtog
   poteza crta `4. c3`, ne `1. c3`.
10. [ ] **Ivice kartica.** Potezi belog i crnog imaju različito svetle ivice;
    izabrana kartica se i dalje razaznaje bez ikakve sumnje.
11. [ ] **Telefon, 360 dp, release build.** Ekran je dobio dva panela i paletu
    više — proveriti da se dugmad ispod table i dalje dohvate skrolom i da se
    ništa ne seče.

## 77. Jedna lista, već izabran potez, izbor grane — 1.9.2026, nije viđeno uživo

1. [ ] **Potez koji je već u repertoaru.** Odigrati na tabli potez koji tu već
   stoji (i glavni i alternativu): nema „Uzmi X", tabla stane posle njega i
   ispod je „Posle X — šta igra protivnik". Brojač „upita:" se ne miče.
2. [ ] **Samo jedna Lichess lista.** Posle odigranog i uzetog poteza ne sme da
   se pojavi drugi panel sa istim potezima. Brojač poraste za **jedan** (sudija),
   ne za dva.
3. [ ] **Navigacija u granatoj poziciji.** Na poziciji sa više nastavaka,
   „napred" otvori spisak „Odavde ide više linija — kojom?"; izbor vodi tablu
   tom granom. Gde grananja nema, ide se bez pitanja.
4. [ ] **Desni klik javi šta je uradio.** Posle „Unapredi", „Obriši" i reza na
   protivnikovom potezu pojavi se poruka na dnu ekrana.
5. [ ] **Strelice na tabli.** Najviše četiri, ništa ispod 2% — a lista ispod
   table i dalje ima sve poteze.
6. [ ] **Telefon, 360 dp, release build.** List za izbor grane i poruke
   `AppFeedback`-a ne smeju ništa da preklope ni da iseku.

## 78. Izbor grane na svim ekranima — 1.9.2026, nije viđeno uživo

1. [ ] **Repertoar.** Na poziciji sa više nastavaka „napred" (dugme i strelica
   desno) otvori „Odavde ide više linija — kojom?"; izbor vodi tablu tom granom.
2. [ ] **Analiza.** Isto na poziciji sa varijantama — do sada se u varijantu
   moglo ući samo klikom u stablu.
3. [ ] **Soba za lekciju i AI Studio.** Isto, tamo gde partija ima varijante.
4. [ ] **Lekcije i ponavljanja se nisu promenili.** Tamo nema grana; „napred"
   ide bez ikakvog pitanja.
5. [ ] **Zatvaranje lista ne pomera tablu.** Otvoriti izbor pa ga zatvoriti
   klikom pored — pozicija mora da ostane ista.
6. [ ] **„Na kraj" ne pita.** Dugme „|>" ide do kraja linije bez pitanja na
   usputnim račvanjima.
7. [ ] **Miš i tastatura se slažu.** Isto ponašanje na dugmetu i na strelici
   desno.

## 79. Biranje otvaranja sa spiska — 1.9.2026, nije viđeno uživo

1. [ ] **„Izaberi otvaranje" otvara spisak.** Odmah, bez kucanja, stoji spisak
   otvaranja po abecedi (od „Alekhine Defense").
2. [ ] **Otvaranje se otvara u svoje varijante.** Klik na otvaranje daje spisak
   njegovih linija, prva je „Osnovna linija", a iznad stoji ime sa strelicom
   nazad.
3. [ ] **Izbor varijante popuni ekran.** Tabla ode na tu poziciju, linija se
   ispiše, ime repertoara se predloži, boja se postavi po strani na potezu.
4. [ ] **Kucanje seče popreko.** Ukucati „Najdorf" dok je otvoreno neko drugo
   otvaranje: rezultati su svi Najdorf redovi, a povratna strelica nestaje.
5. [ ] **Drugi put je odmah.** Zatvoriti i ponovo otvoriti izbor — spisak je tu
   bez treptaja „Učitavanje…".
6. [ ] **Telefon, 360 dp, release build.** Duga imena varijanti se seku sa „…",
   ne prelivaju.

## 80. Grana kao sesija i sparing — 1.9.2026, nije viđeno uživo

1. [ ] **Ikonica grane u zaglavlju drila** otvara spisak: „Ceo repertoar" i
   grane, svaka sa „dospelo N od M".
2. [ ] **Izbor grane sužava dril.** Posle izbora pitanja dolaze samo iz te
   grane; „Ceo repertoar" vraća sve.
3. [ ] **▶ pokreće sparing.** Tabla ode na početak grane, iznad piše
   „Sparing: e4 c5 · odigrano N".
4. [ ] **Protivnik odgovara sam**, i ne uvek isto — pustiti istu granu dvaput i
   videti da li se negde razišla.
5. [ ] **Tačan potez vodi dalje sam od sebe**, posle kratke pauze u kojoj se
   vidi protivnikov odgovor.
6. [ ] **Greška zaustavlja trku** i ostaje na toj poziciji, sa „Pokaži" i
   „Nastavi liniju".
7. [ ] **Kraj grane kaže šta je bilo**: „Grana odigrana do kraja. Odigrano N,
   greške: M." i nudi „Druga grana" / „Nazad na red".
8. [ ] **Raspored se ne pomera bez razloga.** Pustiti sparing kroz granu u
   kojoj ništa nije dospelo, pa proveriti da se brojevi dospelog nisu promenili.
9. [ ] **Telefon, 360 dp, release build.** List sa granama i red „Sparing…" —
   ništa da se ne seče.

## 81. Šetnja linijom: alternativa, ispravka i nastavak — 1.9.2026, nije viđeno uživo

Ovo je odgovor na ono što je vlasnik video 1.9.2026 u Petrovljevoj odbrani:
odigrao je svoj glavni potez d4, dobio narandžastu opomenu i crnog skakača na
c3, a potez Nc3 nigde nije bio prikazan.

1. [ ] **Linija kroz alternativu se najavljuje.** Naći poziciju u kojoj su
   zadržana dva svoja poteza i sačekati da red donese liniju kroz alternativu —
   iznad table treba da stoji „U ovoj poziciji imate više svojih poteza — ova
   linija ide kroz alternativu, ne kroz glavni." Potez se **ne** imenuje.
2. [ ] **Linija kroz glavni potez ne kaže ništa.** Ista provera na liniji koja
   ide kroz glavni: te rečenice nema.
3. [ ] **Svoj drugi potez nije greška.** Odigrati u toj poziciji glavni potez
   dok linija traži alternativu: „I d4 je vaš potez — ali ova linija vežba Nc3",
   i to **plavo**, ne narandžasto.
4. [ ] **Tuđi potez je i dalje samo pogrešan**, narandžasto, sa „Ponavljanje se
   ne ocenjuje."
5. [ ] **Ispravka se vidi.** Potez linije ostaje sam na tabli, sa strelicom na
   sebi, pa tek onda stiže protivnikov odgovor. Ovo je glavna stavka: pre je
   figura osvitala na polju na koje ništa nije viđeno da ide.
6. [ ] **Tačan odgovor vodi dalje sam.** Bez klika, posle pauze u kojoj se
   pročita presuda.
7. [ ] **Presuda ide sa šetnjom.** Iznad sledećeg pitanja: „Tačno — Nc6 ·
   protivnik Nf3 · vraća se za 6 dana."
8. [ ] **Greška zaustavlja šetnju** i tek tu se pojavljuje „Nastavi liniju".
9. [ ] **Nepokriven protivnikov odgovor takođe zaustavlja**, sa „to niste
   pokrili" i ponudom da se pozicija izgradi.
10. [ ] **Kraj knjige ne nudi „Nastavi liniju".** Kad protivnik nema odgovor,
    dugmeta nema — ranije je vodilo u pitanje u poziciji u kojoj nisi na potezu.
11. [ ] **Raspored se ne pomera bez razloga.** Prošetati kroz nekoliko pozicija
    koje nisu bile dospele, pa proveriti da se brojevi dospelog nisu promenili;
    pozicija koja nikad nije ponavljana **treba** da se upiše.
12. [ ] **Telefon, 360 dp, release build.** Red sa presudom je najduža rečenica
    na ekranu — ne sme da se seče.

## 82. Biranje račve i preskakanje koje preskače — 1.9.2026, nije viđeno uživo

1. [ ] **„Druga odluka" stoji samo na račvi.** U poziciji sa jednim zadržanim
   potezom dugmeta nema; u poziciji sa dva stoji.
2. [ ] **Ništa se ne imenuje dok se ne pritisne.** Pre pritiska nigde ne piše
   koji je drugi potez — sa dve odluke to bi odalo i onu koja se traži.
3. [ ] **List nudi „Vežbaj d4"** (po jedan red za svaki drugi potez).
4. [ ] **Izbor menja liniju.** Posle izbora vežbanje ide kroz izabrani potez, a
   iznad table stoji „Vežbate liniju kroz d4."
5. [ ] **„Nazad na red" vraća raspored** i uklanja tu rečenicu.
6. [ ] **Ništa se ne upisuje dok je put izabran** — proveriti da se brojevi
   dospelog nisu pomerili posle nekoliko odgovora na izabranom putu.
7. [ ] **„Druga linija" daje drugu liniju.** Pritisnuti dva-tri puta zaredom i
   videti da pitanje **nije** isto. Ovo je popravka: ranije se vraćalo isto.
8. [ ] **„Preskoči" nad pitanjem isto tako** — pozicija se ne vraća odmah.
9. [ ] **Kad se sve preskoči, gomila se okrene** — ekran ne sme da kaže „Ništa
   nije na redu" posle preskakanja svega; pitanja kreću ispočetka.
10. [ ] **Grana i sparing brišu izabrani put.** Izabrati račvu, pa otvoriti
    spisak grana i uzeti drugu granu — rečenice „Vežbate liniju kroz…" više
    nema.
11. [ ] **Telefon, 360 dp, release build.** Red „Vežbate liniju kroz… / Nazad
    na red" i list sa odlukama — ništa da se ne seče.
12. [ ] **Izabrani potez se imenuje na račvi.** Posle „Vežbaj d4", na toj
    poziciji piše „Ova linija ide kroz d4 — odigrajte ga." Ovo je popravka
    prijave „ne mogu da pređem na glavnu liniju": izbor je radio, ali se iznad
    račve obe linije čitaju identično, pa se nije video.
13. [ ] **Rečenica o alternativi se tu gasi** — ne stoje obe odjednom.
14. [ ] **Put bez ičega iza sebe to kaže.** Izabrati potez iza kog nije
    izgrađena linija: „Iza poteza d4 ništa nije na redu." (ili „još nema šta da
    se vežba"), sa dugmetom „Nazad na red" — a **ne** „Ništa nije na redu".

## 83. Protivnik ostaje unutar pripremljenog — 1.9.2026, nije viđeno uživo

1. [ ] **Poruka „to niste pokrili" se više ne pojavljuje.** Odigrati dvadesetak
   poteza kroz dril i sparing — nijednom.
2. [ ] **Protivnik i dalje ne igra uvek isto.** Ista grana dvaput mora negde da
   se raziđe; ako uvek ide istim potezom, izvlačenje je palo na jedan red.
3. [ ] **Kraj pripreme je kraj linije.** U poziciji u kojoj nije pokriven
   nijedan odgovor, protivnik ne odgovara — nema „Nastavi liniju", a sparing
   kaže „Grana odigrana do kraja".
4. [ ] **„Izgradi ovu poziciju" i dalje postoji.** Doći do pozicije koja jeste
   pokrivena a u njoj nije izabran potez: „Ovu poziciju niste pokrili" i ponuda
   za izgradnju. Ovo je jedina preostala vrata ka izgradnji i ne smeju da
   nestanu sa ovom izmenom.
5. [ ] **Potez „spremi i ovo" se računa.** Dodati jedan protivnikov odgovor
   preko „Spremi", pa ga sačekati u drilu — sme da se odigra iako u knjizi nije
   pokriven.

## 84. Brisanje poteza iz baze i sopstveni komentari — 2.9.2026, nije viđeno uživo

Backend mora biti pokrenut bar jednom posle ove izmene (nova tabela
`repertoire_comments`), inače svaki poziv oko komentara vraća 500.

1. [ ] **Brisanje repertoara i dalje podrazumevano ostavlja poteze.** Obrisati
   jedan repertoar bez kvadratića i otvoriti drugi iste boje — potezi su tu.
2. [ ] **Broj pre pitanja.** U dijalogu za brisanje piše koliko poteza u koliko
   pozicija drži **samo** taj repertoar, i koliko je od toga „sami ste
   izabrali".
3. [ ] **Deljene pozicije se ne broje.** Napraviti dva repertoara iste boje koji
   se preklapaju; u dijalogu za brisanje jednog mora pisati da neke pozicije
   ostaju jer ih drži još neki repertoar.
4. [ ] **Kvadratić „Obriši i poteze" stvarno briše.** Posle brisanja sa
   kvadratićem, novi repertoar iz iste pozicije **ne** zna te poteze.
5. [ ] **Komentari ostaju.** Isti test kao gore, sa napisanim komentarom na
   nekoj od tih pozicija: komentar je i dalje tu kad se pozicija ponovo dosegne.
   Sa uključenim drugim kvadratićem — nije.
6. [ ] **Pražnjenje boje radi i kad nema nijednog repertoara.** Obrisati sve
   repertoare, pa iz gornje trake („Brisanje poteza iz baze") obrisati poteze za
   tu boju; zatim „Novi" — stablo je prazno.
7. [ ] **Repertoari preživljavaju pražnjenje boje.** Sa bar jednim repertoarom:
   posle pražnjenja ime i početna pozicija su i dalje na spisku.
8. [ ] **Prazan spisak objašnjava.** Kad nema nijednog repertoara, na ekranu
   piše da su potezi sačuvani uz boju i gde se brišu.
9. [ ] **Komentar se piše i vidi.** Ispod table pritisnuti dugme za komentar,
   napisati nešto, sačuvati — tekst se pojavi ispod table.
10. [ ] **Komentar preživi povratak.** Izaći iz ekrana, vratiti se i doći do iste
    pozicije: komentar je tu.
11. [ ] **Transpozicija ga nosi.** Doći do iste pozicije drugim redosledom
    poteza — komentar je i tamo.
12. [ ] **Prazan tekst briše.** Obrisati sav tekst i sačuvati: kartica komentara
    nestaje (i ispod table i u koloni).
13. [ ] **Windows, širok prozor (≥1200 dp):** komentar je u trećoj koloni, desno
    od stabla, i **nije** istovremeno ispod table.
14. [ ] **Windows, sužen prozor (oko 1000 dp):** komentar se seli ispod table,
    tabla ne postaje manja, ništa se ne preklapa.
15. [ ] **Telefon, 360 dp, release build.** Traka ispod table sa dva nova
    dugmeta — prelama se u dva reda, ništa nije isečeno. Tastatura ne pokriva
    polje za pisanje (list se podiže).
16. [ ] **„Pitaj AI o poziciji".** Odgovor se pojavi; „U moj komentar" otvara
    editor sa tim tekstom, a **ništa nije sačuvano** dok se ne pritisne
    „Sačuvaj". Bez ključa za model odgovor je i dalje smislen (rezervni tekst).
17. [ ] **Kvota se troši samo na AI dugme.** Pisanje i čitanje komentara ne
    dodiruje `ai_comments`.

## 85. Kapija repertoara i popravka „Vežbaj X" — 2.9.2026, nije viđeno uživo

Backend mora biti pokrenut bar jednom posle ove izmene (`ALTER TABLE
repertoires ADD COLUMN via_uci`).

1. [ ] **Postojećem repertoaru se postavlja kapija.** Na kartici: „Kroz koji
   potez ide" → potez koji se već igra stoji na vrhu i označen je → izabrati ga.
   Na kartici posle toga piše „kroz <potez>".
2. [ ] **Stablo se očisti.** Otvoriti taj repertoar: u stablu nema poteza iz
   drugog otvaranja iz iste pozicije, ni bilo čega ispod njega.
3. [ ] **Ekran kaže da je filtriran** — „Ovaj repertoar ide kroz … — ostalo iz
   ove pozicije se ne prikazuje."
4. [ ] **Red za odlučivanje je isto sužen.** Brojevi („još N u redu",
   pokrivenost) ne računaju pozicije iz druge grane.
5. [ ] **Drugi repertoar iz iste pozicije pokazuje svoje.** Postaviti mu kapiju
   na njegov potez i proveriti da su dva ekrana zaista dva otvaranja.
6. [ ] **Radar pokrivenosti** za taj repertoar prikazuje samo grane iz kapije.
7. [ ] **Vežbanje je suženo.** „Izaberi granu" nudi samo grane te kapije, a
   „Ceo repertoar" ne postavlja pitanja iz drugog otvaranja.
8. [ ] **Novi repertoar iz pozicije koja već ima poteze** nudi izbor kapije
   („U ovoj poziciji već igrate: …"), i to sa **svim** legalnim potezima, ne
   samo onima koji su već izabrani.
9. [ ] **Kapija se može skinuti** („Bez ograničenja") i tada je sve kao pre.
10. [ ] **Skok na drugu poziciju ne nasleđuje kapiju.** Iz radara ili drila
    otvoriti izgradnju na nekoj poziciji dublje — tamo nema rečenice o kapiji i
    ništa nije skriveno.
11. [ ] **„Vežbaj X" na račvi sada stvarno menja liniju** (popravka): posle
    izbora dva-tri pitanja moraju biti iz izabrane grane.
12. [ ] **„Druga linija" daje drugu liniju** — pritisnuti tri puta zaredom.
13. [ ] **Lista neslaganja se otvara.** Ranije je padala na svaki poziv;
    proveriti da vraća listu (ili pošteno „nema neslaganja"), a ne grešku.
14. [ ] **Telefon, 360 dp, release build.** List za izbor kapije i rečenica o
    kapiji — ništa isečeno.


## 86. Vežba govori istinu — protivnik ostaje u odlukama — 3.9.2026, nije viđeno uživo

Faza 0 druge iteracije repertoara (`3691e8f`). `pickReply` je proveravao jedan
uslov gde su potrebna tri: knjiga mora da kaže da se potez ovde igra, učenik ne
sme da je odsekao poziciju u koju vodi, i mora da ima svoju odluku u njoj.
Šetnja linijom je to poštovala mesecima, živi protivnik nije — pa je sparing
umeo da odigra baš onaj potez koji je učenik izbacio.

Ništa od ovoga se ne vidi na ekranu dok se ne odseče grana i ne odigra sparing.
Zato je ovo prva sekcija: sve ostalo se gradi iznad vežbe koja govori istinu.

1. [ ] **Protivnik ne igra u odsečenu granu.** Odseći jedan odgovor
   („Ne spremam ovo"), pa iz vežbe pokrenuti „Odigraj granu do kraja" desetak
   puta na toj grani. Odsečeni potez ne sme da se pojavi **nijednom** — protivnik
   bira nasumično po učestalosti, pa jedan prolaz ne dokazuje ništa.
2. [ ] **Protivnik ne izlazi iz pripremljenog.** Igra samo odgovore posle kojih
   vi imate izabran potez. Ako odigra nešto na šta nemate odgovor, ovo je pao.
3. [ ] **Sparing bez ijednog takvog odgovora se završava rečenicom**, ne
   pitanjem: „Grana odigrana do kraja." ili „Dovde ide grana — dalje nema vašeg
   poteza."
4. [ ] **Vraćanje grane vraća i protivnika.** Potvrditi ranije odsečenu poziciju
   (kroz pregled nacrta) i proveriti da je protivnik ponovo igra.
5. [ ] **Pitanja se nisu promenila.** Red za vežbu i dalje pita isto što i pre —
   ovaj posao dira samo protivnikov potez, ne izbor pitanja.


## 87. Širina repertoara i ugovor ispod njega — 3.9.2026, nije viđeno uživo

Faza 1, zamrznuta pre nego što je ijedan radni agent počeo (`3691e8f`). Sve
ispod je server; vidi se samo kroz ekrane koje su faze 2–4 dogradile.

`standard` je tačno onih 80% koliko je i do sada bilo upisano, pa ništa
napravljeno ranije ne sme da se pomeri. Druge dve širine se računaju iz `share`
pri čitanju i **nikad** ne pišu u `opening_replies`, tabelu koju dele svi
korisnici ovog servera — zato drugi repertoar ne sme da oseti tuđi izbor.

1. [ ] **Širina se pamti.** Napraviti kičmu sa „Široko (95%)", ugasiti
   aplikaciju i otvoriti je ponovo: stablo i radar i dalje računaju 95%. Ranije
   se ovakav izbor vraćao na 80% sledeće sesije, bez ijedne reči na ekranu.
2. [ ] **Tri širine daju tri različita broja.** Isti repertoar sa „Samo glavni odgovor", „Uobičajeno (80%)" i „Široko (95%)" — broj u redu za odlučivanje i
   pokrivenost moraju stvarno da se razlikuju.
3. [ ] **Tuđa širina se ne oseća.** Drugi repertoar iste boje ostaje na svojoj
   širini pošto se prvom promeni. Ako se pomeri i on, negde se piše u zajedničku
   tabelu.
4. [ ] **Dva broja o nacrtima se razlikuju, i to je namerno.** Značka na kartici
   je po boji, traka u izgradnji je po šetnji i poštuje kapiju — pa mogu da
   pokažu različit broj u istom trenutku. Proveriti da se manji broj u traci ne
   čita kao greška.
5. [ ] **„Odigraj drugi potez" je jedan potez, ne dva.** Posle njega u stablu
   nema ni odbijenog nacrta ni onoga do čega se stizalo samo kroz njega, a vaše
   odluke koje se dohvataju drugim putem ostaju.
6. [ ] **Ugašen server ne ostavlja pola upisa.** Ugasiti backend pa pokušati isto:
   „Nije sačuvano — server nije odgovorio.", i posle paljenja servera stablo je
   nedirnuto.

Traka rejtinga je druga polovina iste priče, dopisana 3.9.2026 pošto se ispostavilo
da odlučuje o svemu što se vidi, a nigde ne piše koja je. Knjiga se čuva **po
traci** (`opening_replies` je ključan po `(fen_key, min_rating, uci)`), pa ista
pozicija dohvaćena na 1600+ ne postoji na 2000+. Podrazumevano je 1600+ i niko
nikada ne pita.

7. [ ] **Crtež kaže na čemu je nacrtan.** Iznad stabla stoje dve rečenice —
   „Knjiga: partije od 1600+" i „Širina: samo glavna linija / standardno 80% /
   široko 95%". Menjaju se kad se promeni podešavanje.
8. [ ] **Traka se bira iz zaglavlja Repertoara** (ikona sa ljudima, „Rejting
   protivnika"), kvačica stoji uz izabranu, i po izboru piše „Knjiga sada
   odgovara iz partija od N naviše."
9. [ ] **Promena trake ništa ne uništava.** Prebaciti na 2000+ — stablo omršavi
   jer pozicije nisu dohvaćene u toj traci — pa vratiti na 1600+: sve se vraća
   istog trenutka i **bez novog trošenja Lichess upita** (brojač upita u
   zaglavlju se ne pomera). Ovo je najvažnija stavka ove sekcije: ako se pri
   povratku troše upiti, keš po traci ne radi.
10. [ ] **Traka je po uređaju, ne po repertoaru.** Windows i telefon mogu da
    stoje na različitim trakama i da crtaju različito stablo istog repertoara.
    Ovo je poznato ponašanje — proveriti da se **razume** sa ekrana (rečenica
    iznad stabla to i kaže), ne da se ispravlja.


## 88. Poslednji potez na tabli i traka sa otvaranjem — 3.9.2026, nije viđeno uživo

Faza 2, radni agent (`098e786`). Dve stvari koje su na tabli, a ne u podacima.

Oznaka poslednjeg poteza se crta kao pranje polja **i uglovi u crno-belom**, pa
se vidi i bez razlikovanja boja. Ako se vidi samo kao promena boje, to je nalaz.

1. [ ] **Izgradnja pokazuje poslednji potez.** Odigrati potez: polje sa kog je
   pošao i polje na koje je došao su označena, oba, i uglovima a ne samo bojom.
2. [ ] **Vežba isto.**
3. [ ] **Oznaka nestaje kad tabla skoči.** Skok iz radara ili otvaranje drugog
   repertoara: nema oznake sa pozicije koja više nije na ekranu.
4. [ ] **Oznaka preživi crtanje strelica.** Uključiti crtanje i proveriti da
   oznaka i dalje stoji — crta je drugi sloj i ranije ga je gasio.
5. [ ] **Traka iznad table piše ECO i ime** („C60 · Ruy Lopez…").
6. [ ] **Ime se ne gubi u dubini.** Prošetati liniju osam do deset poteza duboko:
   traka drži **poslednje poznato** ime, ne prazni se. Baza imenuje otvaranja, ne
   svaku poziciju u njima. Ovo je bio kvar koji je prošao sve testove — ekran je
   traci davao ključ koji se menja na svaki korak, pa se ime brisalo baš tamo gde
   pravilo postoji.
7. [ ] **Drugo otvaranje menja traku.**
8. [ ] **Telefon, 360 dp, release build.** Traka iznad table i tabla ispod nje —
   ništa isečeno, tabla se i dalje cela vidi.


## 89. Nepotvrđeni potezi i značka na kartici — 3.9.2026, nije viđeno uživo

Faza 3, radni agent (`936d202`). „Predloži glavnu liniju" upisuje poteze koje
učenik nije birao, a vežba pita samo ono što jeste — pa je repertoar od
četrdeset poteza umeo da kaže da nema šta da se vežba, dok četrdeset pozicija
čeka na „da". Potvrđivanje je postojalo; red za njega nije.

**Prepisano 4.9.2026, pošto ekran opisan u stavkama 4, 6 i 11 više ne
postoji.** „Pregledaj nepotvrđene" ne otvara više zaseban list sa naslovom
„Pregled nacrta (N ostalo)" i tri dugmeta — ono vodi **tablu izgradnje** na
prvu nepotvrđenu poziciju, a potvrda se dešava u panelu „Vaši potezi ovde".
Uz to je reč „nacrt" povučena rečnikom (faza 4 plana jednostavnosti), pa je i
ostatak sekcije preveden na „nepotvrđeni potezi" / „predlog poteza".

1. [ ] **Značka na kartici.** Repertoar sa nepotvrđenim potezima ima žutu
   pilulu sa brojem i ikonicom; bez njih je nema.
2. [ ] **Dodir na značku vodi na prvu nepotvrđenu poziciju**, ne na koren.
3. [ ] **Traka u izgradnji** piše „N nepotvrđenih u grafu" i nudi „Pregledaj nepotvrđene".
4. [ ] **„Pregledaj nepotvrđene" vodi tablu, ne otvara list.** Tabla izgradnje
   ode na prvu nepotvrđenu poziciju. U panelu „Vaši potezi ovde" taj potez
   stoji kao **„predlog — nije još vaš izbor"** (žuto) i pored njega je dugme
   **„Potvrdi"**. Ako se pojavi zaseban list sa naslovom „Pregled nacrta", to
   je stari ekran i nalaz je.
5. [ ] **Svaki odgovor se upisuje sam za sebe.** Potvrditi jedan, pa otići sa
   ekrana i vratiti se: potvrđeno je ostalo potvrđeno i brojač je manji.
   Pregled se sme napustiti u svakom trenutku — nema koraka koji mora da se
   dovrši.
6. [ ] **Brisanje pita.** Ukloniti (×) predlog ispod kog stoje vaše odluke:
   mora prvo da se javi dijalog **„Obrisati vaše odluke?"** sa rečenicom
   „Ispod tog predloga su N vaše odluke. Obrisati i njih?" — i bez potvrde da
   ne obriše ništa.
7. [ ] **Kad se sve reši:** „Nema više nepotvrđenih poteza."
8. [ ] **Vežba više ne laže da nema posla.** U repertoaru u kome su svi potezi
   nepotvrđeni otvoriti vežbu: piše „Još N nepotvrđenih poteza čeka u ovom
   repertoaru." i nudi „Pregledaj nepotvrđene".
9. [ ] **Dijalog „Predloži glavnu liniju odavde"** ima naslov „Koliko odgovora
   spremamo" nad tri izbora, nudi i dubinu, i kaže da su to predlozi koje vežba
   neće pitati dok se ne potvrde.
10. [ ] **Svetla tema, traka sa nepotvrđenim potezima.** Tekst na žutoj podlozi
    mora da se čita, a dugme je obrisano (outlined), ne puno — puno dugme se u
    svetloj temi nije razlikovalo od podloge iza sebe. Pogledati u obe teme.
11. [ ] **Telefon, 360 dp, release build.** Traka „N nepotvrđenih u grafu" i
    panel „Vaši potezi ovde" sa dugmetom „Potvrdi" — ništa isečeno.


## 90. Izdvajanje u novo otvaranje i kombinovani dril — 3.9.2026, nije viđeno uživo

Faza 4, radni agent pa dovršeno rukom (`4cdace2`). Tri kvara su nađena čitanjem
diffa i popravljena — nijedan nije viđen uživo, ni pokvaren ni popravljen:
dugme „Izdvoji" je pucalo van testa, kombinovana sesija je slala pitanja iz cele
boje umesto iz izabranih otvaranja, i tri reda su bila preširoka za 360 dp.

Ono što ovde treba razumeti pre provere: **izdvajanje ništa ne kopira.** Potezi
pripadaju paru (korisnik, boja), a red u `repertoires` je vrata u taj graf — pa
novo otvaranje vidi iste poteze, a staro ne gubi nijedan.

1. [ ] **Dugme postoji i ne puca.** U izgradnji, u redu ispod table, ikona
   grananja („Izdvoji u novo otvaranje") otvara dijalog. Otvoriti aplikaciju
   normalno, ne kroz test: baš tu je pucalo.
2. [ ] **Ime je popunjeno iz knjige** („C60 · Ruy Lopez"), i može da se izmeni.
3. [ ] **Pozicija koju knjiga ne zna ostavlja prazno polje** sa kursorom u njemu,
   bez izmišljenog imena.
4. [ ] **Kapija se bira** kroz isti izbornik kao svuda, i sme da se preskoči.
5. [ ] **Ništa se ne kopira.** Posle izdvajanja: stari repertoar ima sve poteze
   koje je imao, novi vidi iste poteze ispod svog korena, i „N poteza u grafu"
   se **ne udvostručuje**. Ako je broj skočio, negde se pisalo u graf.
6. [ ] **Novo otvaranje je u listi**, sa svojim imenom i svojom kapijom.
7. [ ] **Izbor više otvaranja.** Dugi pritisak na karticu ulazi u izbor,
   čekboksi se vide na svim karticama, dole stoji „Vežbaj izabrane (N)".
8. [ ] **Izabrano je izabrano čekboksom, ne bojom** — kartica se ne razlikuje
   samo nijansom.
9. [ ] **Dve boje se odbijaju rečenicom:** „Jedna sesija može da pita samo o
   jednoj strani.", i brojač ostaje isti.
10. [ ] **Sesija pita samo iz izabranih otvaranja.** Ovo je kvar zbog kog je
    faza pala na ocenjivanju: pitanja su išla iz **cele** boje. Izabrati dva
    otvaranja koja pokrivaju mali deo boje i proveriti da nijedno pitanje ne
    dolazi spolja.
11. [ ] **„Izaberi granu" radi i u kombinovanoj sesiji**, i svaka grana nosi ime
    otvaranja iz kog je došla.
12. [ ] **Dva otvaranja koja počinju istim potezima su dva reda.** Sicilijanka i
    Otvorena sicilijanka koje obe počinju 1.e4 c5 moraju da se vide kao dva reda
    sa dva imena; štikliranje jednog ne sme da štiklira drugi.
13. [ ] **Rečenica o zajedničkom rasporedu** — „Pozicija koju oba otvaranja
    dostižu pita se jednom." — vidi se **pre** nego što se bilo šta štiklira, bez
    skrolovanja.
14. [ ] **Jedan dodir na granu i dalje pokreće tu granu.** Čekboks je za više
    njih; dodir na red je ono što je oduvek radio.
15. [ ] **Više štikliranih grana je jedna sesija.** Kad se prva isprazni, vežba
    prelazi na sledeću umesto da kaže da je gotovo.
16. [ ] **Pozicija koju oba otvaranja dostižu pita se jednom.** Odgovoriti je u
    prvom otvaranju i proveriti da se u istoj sesiji ne pojavi ponovo.
17. [ ] **Telefon, 360 dp, release build.** Tri mesta koja su bila preširoka:
    dugmad u dijalogu izdvajanja, traka „Odustani / Vežbaj izabrane (N)" u listi
    (bila je četiri piksela ispod dna ekrana), i zaglavlje lista za izbor grane.
    Ništa isečeno i ništa van ekrana.


## 91. Popravke nađene u samoj proveri — 3.9.2026, nije viđeno uživo

Četiri kvara nađena za jedno popodne provere, sva četiri popravljena istog dana
i **nijedan viđen uživo ni pokvaren ni popravljen** — sve što sledi traži build
napravljen posle `50fe6d2`. Stoje zajedno zato što su nađeni zajedno i zato što
se posle jednog builda proveravaju u nizu.

Zajedničko im je i nešto gore od svakog pojedinačno: **nijedan nije bio vidljiv
za 1088 testova.** Sva četiri žive u procepu između onoga što klijent pošalje i
onoga što test gleda — `MockClient` odgovara na šta god dobije i nikad ne gleda
URL. To je ista pouka kao `ids` iz faze 4, po četvrti put.

1. [ ] **Pregled nacrta uopšte nalazi nacrte.** `minRating` je odlazio prazan
   (`minRating=`), server je čitao `Number('') || 0`, pa je svaki pregled pitao
   u traci 0 — u kojoj vaše pozicije nisu ni dohvatane. Otvoriti repertoar u
   kome traka kaže „N nepotvrđenih u grafu" i pritisnuti „Pregledaj nepotvrđene":
   mora da ponudi tih N, a ne „Nema više nepotvrđenih poteza."
2. [ ] **Traka se osveži kad se pregled zatvori.** Potvrditi jedan nacrt, pa
   zatvoriti list: broj u traci mora da bude manji za jedan, a ne isti.
   Ranije se čitao samo pri otvaranju ekrana, pa je nudio posao koji je već
   urađen — a jedini način da se to sazna bio je da se pritisne.
3. [ ] **Isto u vežbi.** Rečenica „Još N nepotvrđenih poteza čeka" posle
   pregleda pokazuje novi broj.
4. [ ] **Širina stvarno menja crtež.** Postaviti „Samo glavni odgovor" pa
   pogledati stablo: ispod svakog vašeg poteza stoji **jedan** protivnikov, ne
   tri. Ovo je bio kvar zbog kog je izbor bio potpuno bez dejstva — red u bazi
   je bio ispravan, a nijedan poziv nije slao `breadth`, pa je server uvek
   računao na 80%. Mereno na Benoniju: `main` crta 3 protivnikova poteza,
   `standard` 23, `broad` 48.
5. [ ] **Dijalog kičme se otvara na već izabranoj širini.** Repertoar na „Samo glavni odgovor" → „Predloži glavnu liniju" → mora da bude štiklirana glavna linija.
   Ranije je uvek pisalo „Uobičajeno (80%)", pa je svako otvaranje dijaloga
   tiho vraćalo repertoar na 80%.
6. [ ] **Prazan red nije ćorsokak.** Otvoriti repertoar u kome je red za
   odlučivanje prazan: ekran kaže „Nema više pozicija u redu." i nudi **„Otvori
   repertoar"**, koje vraća tablu i stablo. Ranije je nudio samo „Nazad", pa je
   repertoar sa sto poteza bio nedostupan sa sopstvenog ekrana — dok je ista ta
   rečenica govorila da se vratite na neku poziciju i uzmete još odgovora.


## 92. Govor na panelima i prekidač u zaglavlju — 3.9.2026, nije viđeno uživo

Faza 2 plana jednostavnosti, radni agent (`1e8822d`). Traži build napravljen
posle tog spoja.

**Najvažnije prvo: govor je podrazumevano isključen, i tako ostaje dok se ne
pritisne.** Sve ispod se proverava i sa ugašenim govorom — ekran mora da izgleda
i radi tačno kao pre. Drugo po važnosti: **mašina možda uopšte nema srpski
glas.** Windows ga po pravilu nema dok se ne instalira, i to je uredno stanje, a
ne kvar — panel se crta isto, zvučnik ne sme da obori ekran ni da ćuti bez
objašnjenja.

1. [ ] **Ugašeno je stvarno ugašeno.** Ući u vežbu bez diranja podešavanja:
   ništa se ne izgovara, nijedan panel nije pomeren, pitanje stoji gde je i
   stajalo.
2. [ ] **Prekidač u zaglavlju radi bez izlaska iz ekrana.** Zvučnik u traci
   vežbe i izgradnje: pritisak ga pali, ikona se menja, sledeće pitanje se
   izgovori.
3. [ ] **Izgovara se ono što piše.** Pitanje („Šta igrate crnim?" plus rečenica
   ispod njega) izgovara se kao jedna rečenica, a presuda posle tačnog odgovora
   („Tačno — Nc6 · protivnik Nf3 · vraća se za 6 dana") čita se sa notacijom u
   rečima: „skakač c šest". Ako se čuje nešto što na ekranu ne piše, to je nalaz.
4. [ ] **Samo pitanje i presuda govore sami od sebe.** Baner „N nepotvrđenih u
   grafu", završni ekran izgradnje i „Još nema šta da se vežba." ćute dok se ne
   pritisne njihov zvučnik.
10. [ ] **I izgradnja čita svoje pitanje.** Ovo je bio drugi nalaz od 3.9.2026 —
    „ništa se ne čuje kad uđem u izgradnju repertoara". Faza 2 je na tom ekranu
    obukla baner, belešku i završnu rečenicu, a **promašila jedini panel koji
    nešto pita**. Ući u izgradnju sa upaljenim govorom: „Šta igrate belim/
    crnim?" zajedno sa rečenicom ispod („Još N neodgovorenih.") mora da se
    pročita sama od sebe, isto kao u vežbi. Kad se stoji posle svog poteza,
    pitanje glasi „Posle <potez> — ovo igra protivnik" i važi isto.
11. [ ] **Ono što se ne izgovara nije ni obuhvaćeno.** Ispod pitanja u izgradnji
    ume da stoji i „Ovde ste već izabrali potez…" ili red o napretku. Te
    rečenice **nisu** unutar zvučnika i ne čitaju se — zvučnik koji vizuelno
    obuhvata rečenicu koju ne čita je nalaz.
5. [ ] **Zvučnik nikad nije mrtvo dugme.** Sa ugašenim govorom pritisnuti
   zvučnik pored rečenice: pali govor **i** izgovara je. Ovo je pravilo iz faze
   0 i najlakše ga je slučajno pokvariti.
6. [ ] **Gašenje ućutkuje odmah.** Dok rečenica traje, pritisnuti prekidač u
   zaglavlju: glas prestaje na mestu, ne dovršava rečenicu.
7. [ ] **Mašina bez glasa.** Na Windowsu bez srpskog glasa: svi paneli se crtaju,
   ništa ne puca, a stanje se vidi u podešavanjima govora („nema glasa"), ne
   samo u logu.
8. [ ] **Telefon, 360 dp, release build.** Zaglavlje vežbe sada nosi i zvučnik:
   brojač desno („na redu: N · novo: M", odnosno „van rasporeda") mora da bude
   **ceo vidljiv i čitljiv**. U testu je 360 dp prelivalo za jedan piksel bez
   smanjivanja, a release build ne crta trake — samo iseca. Isto pogledati i na
   ekranu izgradnje, gde brojač „upita: N" namerno **nije** smanjivan.
9. [ ] **Paljenje čita ono što je već na ekranu.** Kvar koji je vlasnik našao
   uživo 3.9.2026 („TTS se u drilu uključuje tek na kraju linije"), popravljen
   istog dana. Panel je govorio samo kad se **napravi** ili kad mu se **promene
   reči**, a paljenje prekidača nije ni jedno ni drugo: dril je ćutao na pitanju
   koje čitalac gleda, pa je prva izgovorena stvar bila presuda na kraju linije
   — rečenica zbog koje se govor i pali bila je jedina koja se nije čula.
   Provera: ući u vežbu sa **ugašenim** govorom, sačekati pitanje, pa pritisnuti
   zvučnik u zaglavlju. Pitanje mora da se pročita **odmah**, ne tek na sledećoj
   poziciji.


## 93. Meni na tabli i tri prekidača za strelice — 3.9.2026, nije viđeno uživo

Faza 1 plana jednostavnosti, radni agent (`c26b83c`). Upisano naknadno, 3.9.2026
— faza je spojena pre nego što je stavka napisana, pa ovde nema ničega što je
neko već gledao.

`BoardViewMenu` je zamenio `BoardCoordinatesButton` na **četrnaest mesta u
trinaest fajlova** (to je ispravka samog radnog agenta: brief je rekao deset,
jer je `grep` promašio `const` oblike). Koordinate su svuda; tri prekidača za
strelice samo tamo gde ekran crta strelice — izgradnja repertoara, vežba i
Analysis Studio.

**Sva tri prekidača su podrazumevano uključena**, i to je namerno: prekidač čiji
podrazumevani položaj tiho uklanja nešto posle nadogradnje ne čita se kao novo
podešavanje nego kao izgubljena funkcija.

1. [ ] **Meni je tamo gde je dugme bilo.** Proći ekrane koji su imali dugme za
   koordinate — igra, replay, taktika, završnice, blunder-šetnja, zadaci,
   pregledi, sopstveni zadaci, novi repertoar — i na svakom videti isti meni na
   istom mestu u zaglavlju. Na tim ekranima meni nudi **samo** koordinate, bez
   strelica.
   AI Studio i soba su ispali sa ovog spiska 4.9.2026: oni **crtaju** strelice
   motora, pa im idu i prekidači — vidi stavke 11 i 12. Dok je AI Studio stajao
   ovde, ova stavka je tražila da se potvrdi upravo ono što je bio kvar.
2. [ ] **Koordinate i dalje rade.** Uključiti i isključiti: slova i brojevi oko
   table se pojave i nestanu, i to ostaje posle izlaska i povratka.
3. [ ] **Prekidač za vaše poteze.** U izgradnji repertoara isključiti „vaši
   izabrani potezi": strelice vaših odluka nestaju sa table, a statistika i
   motor **ostaju**. Ovo je mesto gde je greška najverovatnija — tri izvora
   stižu do table kao ista vrsta strelice, pa prekidač koji vrati praznu listu
   umesto da preskoči svoj izvor obriše i sve ispod sebe.
4. [ ] **Prekidač za statistiku.** Isto, obrnuto: statistika ode, vaši potezi i
   motor ostanu.
5. [ ] **Prekidač za motor.** Isto u Analysis Studiju: strelice motora nestaju,
   ostalo stoji.
6. [ ] **Ekran vežbe sluša isti prekidač.** „Vežba" je ekran drila — onaj koji se
   otvara dugmetom „Vežbaj ovu granu", gde vas aplikacija pita „Šta igrate
   belim/crnim?". Kad se u toj vežbi ponavlja linija, strelica koja se pokaže
   **jeste vaš izabrani potez**, pa je gasi prekidač „Strelice odabranog
   poteza" — ne „Strelice motora" i ne „Strelice sa statistikom".
7. [ ] **Tabla se precrta bez izlaska sa ekrana.** Prekidač se pomera dok se
   gleda tabla: strelice nestanu **odmah**, bez izlaska i povratka. Podešavanje
   se čita preko `ChangeNotifier`-a; ako treba izaći i vratiti se, pročitano je
   jednom u polje i to je nalaz.
8. [ ] **Preživi restart.** Ugasiti dva od tri prekidača, ubiti aplikaciju,
   pokrenuti ponovo: ista dva su i dalje ugašena.
9. [ ] **Uključeno se vidi bez boje.** Vlasnik ne razlikuje boje na koje se ovakvi
   prekidači obično oslanjaju: položaj prekidača mora da se čita kao uključen po
   **obliku i položaju**, ne po nijansi. Ako se razlika svodi na boju, to je nalaz.
10. [ ] **Telefon, 360 dp, release build.** Meni otvoren preko table: ništa nije
    isečeno, sve tri stavke se vide cele, i zatvaranje menija vraća tablu kakva
    je bila.

Sledeće tri stavke su dopisane 3.9.2026, posle nalaza vlasnika da AI Studio crta
strelice motora nad tablom čiji meni nudi samo koordinate. Kad se to popravilo
(`526bcb5`), ispalo je da isto važi i za sobu — brief faze 1 je rekao „tačno tri
ekrana" i nabrojao ih, a spisak u prozi ne može da primeti četvrti ekran.

11. [ ] **AI Studio ima prekidače.** Otvoriti zadatak sa uključenom „Prikaži
    evaluaciju": strelice motora stoje na tabli, a meni na tabli sada nudi i tri
    prekidača. Isključiti „Strelice motora" — strelice nestaju, tabla ostaje.
12. [ ] **Soba za čas ima prekidače.** Isto tamo gde trener pusti motor: meni
    nudi prekidače, i „Strelice motora" ih gasi. Ranije su se crtale i nije
    postojao način da se sklone.
13. [ ] **Replay ništa ne izgubi.** U replayu snimka strelice lekcije se i dalje
    vide — one nisu motorove i prekidač ih ne dira. (Lista strelica motora tamo
    se nikad nije ni punila, pa je obrisana.)

**Stavke 11 i 12 traže build napravljen posle `526bcb5`** (3.9.2026, 22:04).
Vlasnik ih je 4.9.2026 ujutru gledao u Windows build-u i javio „ovde toga nema";
`board_arrows_reach_test.dart` čita izvor sa uparenim zagradama i pada ako i
jedan `BoardViewMenu` na ekranu koji crta strelice ostane bez `arrows: true`, a
prolazi. `flutter build windows` ume da ponese i stari font ikona — vidi
CLAUDE.md. Dakle: prvo nov build, pa onda nalaz.


## 94. Množina u tri rečenice — 3.9.2026, nije viđeno uživo

Popravka `b5e8073`. Tri mesta su imala `n == 1 ? "pozicija" : "pozicija"` —
obe grane ista reč, pa se oblik nikad nije menjao. `serbian_plural.dart` je sve
vreme postojao, sa tri oblika; nijedno od tri mesta ga nije zvalo.

**Pravilo koje se proverava**, isto na sva tri mesta: 1 → *pozicija*, 2–4 →
*pozicije*, 5 i više → *pozicija*, a **11 do 14 idu sa peticom** iako se
završavaju na 1–4. Glagol ide uz imenicu: „2 pozicije **čekaju**", „5 pozicija
**čeka**".

Brojevi se ne mogu naručiti, pa se ovo gleda usput — kad se zatekne broj, gleda
se da li oblik odgovara. Ako se zatekne samo jedan broj, dovoljno je da taj
bude tačan.

1. [ ] **Početna, red o ponavljanju.** Sa 1 pozicijom: „1 pozicija čeka na
   ponavljanje." Sa 2, 3 ili 4: „2 pozicije **čekaju** na ponavljanje." Sa 5 i
   više: „5 pozicija čeka na ponavljanje."
2. [ ] **Izgradnja, poruka posle uzimanja odgovora.** „Dodata 1 pozicija.",
   „Dodate 2 pozicije.", „Dodato 5 pozicija." — participijum se menja zajedno
   sa imenicom, što je i bio ceo kvar.
3. [ ] **Izgradnja, poruka posle „Ne spremam ovo".** Kad ispod grane ima još
   pozicija: „sa njom je iz reda **izašla** još 1 pozicija", „**izašle** još 2
   pozicije", „**izašlo** još 5 pozicija".
4. [ ] **Jedanaest do četrnaest.** Ako se negde zatekne takav broj: „12
   pozicija čeka", nikako „12 pozicije čekaju". Ovo je oblik koji svi
   promaše.


## 95. Šest popravki iz odgovora na proveru — 4.9.2026, delimično potvrđeno

Sve šest su nastale iz vlasnikovih odgovora i prijava od 30.8. do 4.9.2026.
Svaka ima test dokazan mutacijom — test je obaran, gledano da pada, pa vraćen —
jer je jedan raniji čuvar u ovom fajlu prolazio i sa isečenom zaštitom.

1. [x] **Strelice na tastaturi rade i tamo gde ima stabla.** — potvrdio
   vlasnik na uređaju 4.9.2026: navigacija strelicama radi bez greške. U Analizi i u
   Repertoaru: kliknuti čvor u grafičkom stablu (time stablo uzima fokus), pa
   levo/desno — jedan potez napred i nazad, isto što rade dugmad ispod table, sa
   pitanjem „Odavde ide više linija — kojom?" na račvanju. Gore i dole idu na
   krajeve linije, **ne** na roditelja i prvo dete. Ranije je stablo držalo sva
   četiri tastera za sebe: dole je išlo glavnom granom bez pitanja, a levo i
   desno u poziciji bez braće nisu radili ništa. (Nalazi i0054, i0559, i0560 —
   jedan uzrok, tri prijave.) `+` i `-` i dalje zumiraju stablo.
2. [x] **Nemoguća pozicija ne ruši aplikaciju.** — potvrdio vlasnik na
   uređaju 4.9.2026: motor ne pada i uredno ispisuje upozorenje. Postaviti poziciju bez kralja
   (Postavi poziciju / nalepljen FEN), uvesti je i uključiti motor: mora da se
   javi „Motor ne može da računa: Nedostaje beli kralj." i ekran da ostane živ.
   Probati na sva tri mesta koja imaju motor — Analysis Studio, AI Studio i soba
   (uključujući „Šahovski studio"). Ranije je aplikacija padala.
3. [ ] **Poruke u izgradnji se čuju.** Sa uključenim govorom, u izgradnji
   repertoara: posle „Ne spremam ovo" i posle uzimanja odgovora, rečenica ispod
   table („Dodate 2 pozicije.", „Ovu granu više ne spremam — s njom je izašla
   još 1 pozicija.") **izgovara se** i ima zvučnik pored sebe. Ranije se videla
   kao siv tekst i nikad se nije čula.
4. [ ] **„Nema više nepotvrđenih poteza" je istina kad se kaže.** Repertoar čija
   širina ne dohvata sopstvene nacrte (napravi kičmu široko, pa prebaci na „Samo glavni odgovor") na „Pregledaj nepotvrđene" mora da kaže koliko ih ima u grafu, a ne
   da ih nema. Mereno uživo 4.9.2026 na „Druga": 21 nacrt, walk ih je video 0.
5. [ ] **Dijalog kaže čemu širina pripada.** „Predloži glavnu liniju odavde" →
   naslov nad tri izbora je „Koliko odgovora spremamo", a ispod njega stoji da
   to važi za ceo repertoar, ne samo za ovu liniju. Predložiti glavnu liniju iz
   pozicije van nje sa izabranim „Samo glavni odgovor": ako stablo tu poziciju
   više ne crta, poruka ispod table mora to da kaže i da imenuje izbor.
6. [x] **Stablo se crta dovoljno duboko.** — potvrdio vlasnik na uređaju
   4.9.2026: potezi koji ranije nisu ulazili u stablo sada ulaze. Raditi na potezu 7 ili dubljem i uzeti
   odgovor: novi čvor se vidi u stablu **odmah**. Ranije se crtež tražio na 16
   polupoteza (8 poteza) i ono što se uzme na sedmom potezu je padalo preko
   ivice. Ako se i dalje javi „Crtež je skraćen na N polupoteza", to je uredno —
   ali mora da bude dublje od pozicije na kojoj stojite.
7. [ ] **Brojevi ispod table kažu šta broje.** Rečenica ispod pitanja sada glasi
   „Posle ove u redu je još N pozicija." — red, bez pozicije na tabli. Legenda
   pored i dalje kaže `otvoreno N`, što je walk i broji i ovu. Dva broja koja se
   razlikuju za jedan su tačna; prijava je bila da se ne zna koji je koji.

8. [ ] **Vaši potezi se vide i na „Samo glavni odgovor".** Repertoar sa kičmom
   napravljenom široko, pa prebačen na „Samo glavni odgovor": stablo i dalje crta
   sve što ste sami uneli, a **ne** crta grane u kojima nemate nijedan potez.
   Mereno na „Druga" 4.9.2026: pre popravke 4 čvora i 0 od 21 nacrta, posle 38
   čvorova i svih 21. Ako se posle ovoga na „Samo glavni odgovor" vidi i ono gde
   niste ništa odlučili, to je nalaz — pravilo sme da doda samo vaše.
9. [ ] **Vežba nije proširena.** Ista promena, druga strana: broj pozicija u
   vežbi za taj repertoar ostaje isti, jer nacrt nije odluka i dril ga ne pita.
   („Druga" ima 4 i pre i posle.)


## 96. Rečnik u repertoaru — 4.9.2026, nije viđeno uživo

Faza 4 plana jednostavnosti, spojena u `8ce6a6e`. 47 zamena po
`docs/TABELA-RECNIK-2026-09.md` u sedam fajlova repertoara, plus tri unutar
interpolacija koje kapija ne vidi. **Ovo je jedina faza koja ne menja nijedno
ponašanje** — ako se nešto drugačije *radi*, a ne samo drugačije piše, to je
nalaz.

Povučene reči i ono što ih menja: kičma → glavna linija, nacrt → nepotvrđeni
potezi (gomila) / predlog poteza (jedan), širina → koliko odgovora spremamo,
pokrivenost → rupe u repertoaru, odsečeno → ne spremam.

1. [ ] **Nijedna povučena reč ne stoji na ekranu.** Proći sedam ekrana
   repertoara — spisak, izgradnja, vežba, rupe (radar), dijalog za glavnu
   liniju, stablo, traka sa nepotvrđenima — i ne naći nijedno „kičma", „nacrt",
   „širina", „pokrivenost" ni „odsečeno". Ovo je ceo posao ove faze; sve ispod
   je gde se najlakše sakrilo.
2. [ ] **Reč koja mora da ostane.** Na tabli je i dalje „Nacrtaj strelicu" — to
   je crtanje strelice, nema veze sa nacrtom. Ako je i ona preimenovana, sweep
   je otišao predaleko. (Druga takva je `pokriveno %` u logu motora — nije na
   ekranu, pa se ne proverava odavde.)
3. [ ] **Traka na telefonu, 360 dp, release build.** „N nepotvrđenih u grafu" i
   dugme „Pregledaj nepotvrđene": dugme stoji **ispod** rečenice i celo se vidi.
   Novo ime je duže od starog za četiri znaka i u release build-u se višak ne
   crta prugicama — prosto se odseče i dugme se ne može pritisnuti. U širokom
   prozoru (desktop) njih dvoje stoje **jedno pored drugog**; ako i tamo idu
   jedno ispod drugog, popravka je otišla na drugu stranu.
4. [ ] **Dugmad u izgradnji.** „Predloži glavnu liniju", „Pregledaj
   nepotvrđene", „Vežbaj ovu granu", „Ne spremam ovo", „Ipak spremi ovu granu" —
   i u punom prozoru i na 360 dp, gde se prelamaju u dva reda umesto da se seku.
5. [ ] **Radar.** U ⋮ meniju kartice piše „Rupe u repertoaru", a zaglavlje
   ekrana je „Rupe u repertoaru — <ime>". Po granama: „ne spremam" umesto
   „odsečeno", uz iste makaze.
6. [ ] **Dijalog za glavnu liniju.** Naslov „Predloži glavnu liniju odavde",
   nad izborima „Koliko odgovora spremamo", tri izbora „Samo glavni odgovor",
   „Uobičajeno (80%)", „Široko (95%)". Isti izbori istim redom kao pre.
7. [ ] **Stablo.** U legendi „✂ grana koju ne spremam", iznad „Koliko odgovora:
   uobičajeno 80%", i dugme „Prikaži/Sakrij grane koje ne spremam (N)".
8. [ ] **Rečenice ispod table.** Posle uzimanja odgovora „Spremno je X% onoga
   što ćete sresti"; posle „Ne spremam ovo" — „Ovu granu više ne spremam — s
   njom je izašla još N pozicija."; kad server ne odgovori — „Grana je ostala —
   server nije odgovorio." Brojevi i množina moraju da se slažu kao i pre: 1
   pozicija, 2 pozicije, 5 pozicija.
9. [ ] **Ono što se čuje je ono što piše.** Sa uključenim govorom (faza 2), sve
   rečenice iz stavke 8 se izgovaraju **novim** rečima. Ako se čuje stara reč,
   negde postoji drugi tekst za govor — što je tačno ono što `SpeakableInfo`
   postoji da spreči.
10. [ ] **Brisanje i dalje kaže šta odnosi.** U spisku, brisanje nacrta i
    brisanje boje: „Idu i grane koje ne spremate, dodati odgovori, raspored za
    vežbanje…", i „Ispod tog predloga su N vaše odluke. Obrisati i njih?"
11. [ ] **Vežba, prazna stanja.** „Ovu granu ne spremam ili u njoj još nema
    vaših poteza.", „Još N nepotvrđenih poteza čeka u ovom repertoaru." i dugme
    „Pregledaj nepotvrđene".

**Šta ovde nije dirano, pa ne treba tražiti promenu:** `chess_backend/` i
njegove srpske poruke, imena u kodu (`_widthNames`, `breadthName`, `draft`,
`pruned`), i bilo koji ekran van repertoara. Ako se povučena reč nađe tamo, to
je zaseban posao, ne propust ove faze.


## 97. Rupa u stablu u tamnoj temi — 4.9.2026, nije viđeno uživo

Jedna promena, u `visual_move_tree_widget.dart`. Vlasnik je 4.9.2026 prijavio da
se u tamnoj temi rupa („?") ne razlikuje dovoljno od pokrivenog odgovora.
Debljina nije bila kriva — rupa je već bila na 2.4 naspram 1.2; kriva je bila
providnost ivice (`alpha: 0.75`, koju dobija svaka kartica van glavne linije).

1. [ ] **Rupa bode oči u tamnoj temi.** Otvoriti stablo repertoara sa bar jednom
   rupom, u **tamnoj** temi: kartica sa `?` mora da se nađe bez čitanja oznaka,
   po ivici koja je punom jačinom i deblja (3.0) od svih ostalih.
2. [ ] **Ivica i dalje kaže ko je na potezu.** Uporediti dve rupe — jednu posle
   belog i jednu posle crnog poteza: ivice moraju da ostanu različite. Ako sve
   rupe izgledaju isto, popravka je kupila kontrast tako što je pojela kanal o
   strani koja je na potezu, i to je nalaz.
3. [ ] **Svetla tema nije pokvarena.** Ista slika u svetloj temi: rupa je i dalje
   samo deblja, ne i tamnija mrlja.


## 98. Ekran „Upoznaj repertoar" — 4.9.2026, nije viđeno uživo

Faza 4 plana, spojena u `a3b32d5`. Ceo ekran je nov i **ništa od ovoga nije
gledano kako radi** — testovi znaju samo ono što im je rečeno da provere.

1. [ ] **Ulaz postoji i vodi tamo.** Na kartici repertoara, meni „Još" → prva
   stavka „Upoznaj repertoar". Otvara tablu sa prvim potezom već odigranim.
2. [ ] **Traka i strelice voze turu.** Napred ide potez po potez; na kraju
   linije **penje se nazad do račvanja** i izlazi drugom granom. Nazad poništava
   tačno taj korak — ne vodi na roditelja. Levo/desno na tastaturi rade isto.
3. [ ] **Na protivnikovom potezu se vidi lista.** Kartica kaže „Odavde protivnik
   ima N odgovora:" i ispod stoje čipovi sa procentom i `?` za rupu. Dodir na
   čip vodi turu tamo. Ovo je ono zbog čega ekran postoji — ako se lista ne
   vidi bez otvaranja lista, to je nalaz.
4. [ ] **Rupa nudi vrata.** Na `?` čvoru: „Na <potez>, X% partija, nemate
   odgovor." i dugme „Napravi odgovor" koje otvara izgradnju **u toj poziciji**,
   ne u korenu.
5. [ ] **Na Windowsu stablo stoji pored table i prati turu.** Označena kartica
   se pomera kako tura ide; dodir na karticu u stablu vodi turu tamo. Na
   telefonu stabla nema.
6. [ ] **Na telefonu (360 dp) ništa nije odsečeno.** Račvanje sa više odgovora:
   svi čipovi se vide, red se prelama. U release buildu prelivanje se ne crta,
   pa se gleda da li poslednji čip postoji.
7. [ ] **Dugme za okretanje table okreće tablu.** Bilo je vezano za praznu
   funkciju; sada mora da radi u oba smera.
8. [ ] **Vaša napomena se vidi.** Pozicija o kojoj ste nešto napisali: ispod
   rečenice stoji „Vaša napomena:" i tekst.
9. [ ] **Tura ništa ne upisuje.** Proći celu turu, izaći, pa otvoriti izgradnju:
   ništa nije dodato, obrisano ni promenjeno.


## 99. Govor u turi „Upoznaj repertoar" — 4.9.2026, nije viđeno uživo

Faza 5. Sve se sluša sa uključenim govorom (zvučnik u zaglavlju ili pored
kartice).

1. [ ] **Glavna linija ćuti.** Proći nekoliko poteza kroz liniju bez račvanja i
   bez rupa: tabla se pomera, kartica piše, **ništa se ne čuje**. Ako se čuje
   svaki potez, faza je promašila ono zbog čega postoji.
2. [ ] **Račvanje govori i imenuje odgovore.** Na svom potezu ispod kog
   protivnik ima više odgovora: čuje se „Odavde protivnik ima N odgovora: …" sa
   procentima, i rupa je u toj rečenici označena sa „bez odgovora".
3. [ ] **Rupa govori.** Na `?` čvoru se čuje „Na <potez>, X% partija, nemate
   odgovor."
4. [ ] **Napomena se čuje poslednja**, i počinje sa „Vaša napomena:".
5. [ ] **Izgovoreno je ono što piše.** Sve što se čuje mora da stoji na
   kartici. Ako se čuje nešto čega nema na ekranu, to je nalaz.
6. [ ] **Rečenica se ne preseca.** Krenuti dalje dok govori: nova rečenica
   dolazi na red, aplikacija ne puca i ne ućuti zauvek. (Na Windowsu je ovo
   mesto na kome je `stop()` ranije obarao proces.)
7. [ ] **Sa isključenim govorom se ne gubi ništa** osim zvuka — sve rečenice su
   i dalje na kartici.


## 100. Strelice i povratak na račvanje u turi — 4.9.2026, nije viđeno uživo

Traženo pošto je vlasnik gledao turu kako radi.

1. [ ] **Na račvanju stoje strelice.** Na svom potezu ispod kog protivnik ima
   više odgovora: strelice na tabli, sa procentom u znački. Najdeblja je onaj
   odgovor koji je **prvi čip** na kartici — ne onaj sa najvećim procentom, ako
   se to dvoje razlikuje.
2. [ ] **Rupa se na strelici poznaje bez boje.** Značka rupe ima `?` pored
   procenta.
3. [ ] **Jedan odgovor ne dobija strelicu.** Tabla ionako ide tamo sledećim
   pritiskom.
4. [ ] **Kraj linije vraća na račvanje.** Posle poslednjeg poteza linije jedan
   pritisak napred vraća **tablu** na poziciju iz koje se račva, sa strelicama,
   i kartica kaže „Videli smo liniju posle X. Sada ide Y." Sledeći pritisak
   ulazi u novu liniju. Proveriti da je **tabla stvarno na toj poziciji**, ne
   samo tekst — figure moraju da budu tamo gde su bile.
5. [ ] **Nazad poništava tačno taj korak.** Sa takta povratka jedan nazad vraća
   na poslednji potez prethodne linije.
6. [ ] **Na taktu povratka traka ne pita „kojom linijom".** Tura je upravo
   rekla kojom ide; pritisak napred mora da ide tamo, a ne da otvori list.
7. [ ] **Tura dolazi do kraja.** Proći celu turu do poslednjeg poteza. Ako
   dugme napred u nekom trenutku prestane da radi, to je ovaj kvar ponovo.
8. [ ] **Meni na tabli nudi samo prekidač koji radi.** „Prikaz na tabli" na
   ovom ekranu ima „Koordinate" i „Strelice sa statistikom" — i ništa više.
   Isključivanje tog prekidača skida strelice.


## 101. Prekidač za govor u turi i ivica rupe, drugi pokušaj — 4.9.2026, nije viđeno uživo

Oboje iz vlasnikove provere od 4.9.2026 uveče.

1. [ ] **Prekidač u zaglavlju gasi govor za ceo pregled.** „Upoznaj repertoar",
   zvučnik gore desno: isključiti ga i proći kroz nekoliko račvanja i rupa —
   **ništa se ne izgovara ni na jednom stajanju**. Ranije je zvučnik ispod
   table ćutao samo do sledeće pozicije u kojoj ima šta da se kaže.
2. [ ] **Dok je gore isključeno, ispod table nema zvučnika.** Da se ne pritisne
   nešto što ne može da proizvede zvuk. Kad se gore uključi, zvučnik ispod
   table se vrati i ponavlja rečenicu.
3. [ ] **Rupa u tamnoj temi, drugi pokušaj.** Ivica je sada svetla (ne više
   nijansa strane koja je na potezu) i kartica ima blagu ispunu. Rupa mora da
   se nađe **bez čitanja oznaka**, na obe teme. Prva popravka je merena na
   0.002 luminancije — crna linija na crnoj podlozi — i vlasnik je rekao da se
   teško uočava; ovo je zamena, ne dorada.
4. [ ] **Pokriven odgovor nije počeo da liči na rupu.** Prazna pilula, tanka
   ivica, bez ispune — i dalje jasno drugačija od oprane.

## 102. Redosled kroz nepotvrđene poteze — 4.9.2026, nije viđeno uživo

Iz vlasnikove prijave od 4.9.2026: „prvo potvrđujem 5. potez od početka u svim
granama, pa onda prelazi na sve šeste". Sada ide po jednoj liniji do kraja, pa
nazad na poslednje račvanje. Redosled dolazi sa servera i traži se po jedna
pozicija, pa se ovo vidi samo uzastopnim pritiskanjem dugmeta.

Traži repertoar sa **bar dva račvanja** i nacrtima u obe grane — spina napisana
čarobnjakom je to. Najlakše na „Druga", gde je 21 nacrt.

1. [ ] **Pritisnuti „Pregledaj nepotvrđene" nekoliko puta zaredom, potvrđujući
   svaki put.** Pozicije moraju da **slede jedna iz druge** — ista linija, potez
   dublje svaki put — dok se linija ne završi, pa tek onda skok na drugu granu.
   Ranije je nakon svake potvrde skakalo u drugu granu na istoj dubini.
2. [ ] **Redosled se poklapa sa stablom na ekranu.** Otvoriti grafičko stablo i
   pratiti: pregled ide **od gore na dole i sleva nadesno** — moj glavni potez,
   pa najčešći protivnikov odgovor, pa niz tu liniju do kraja. Ovo je vlasnikova
   sopstvena slika i jedini način da se redosled proveri bez čitanja koda.
3. [ ] **Moja alternativa ide posle cele glavne grane**, čak i kad je odgovor na
   nju češći od svega u glavnoj. Vidi se u repertoaru gde ima drugi prvi potez.
4. [ ] **Isto iz sva tri ulaza.** Traka na ekranu za gradnju, „Idi na nacrte" u
   drilu, i otvaranje kartice sa liste (kartica sa značkom nacrta vodi na prvu
   nepotvrđenu poziciju). Sva tri traže isti prvi element sa servera.
5. [ ] **Brojka u traci se nije promenila.** Redosled je izmenjen, skup nije —
   „N nepotvrđenih" mora da bude isti broj kao pre potvrđivanja minus potvrđeno.
6. [ ] **Odsečena grana i dalje ćuti.** Odseći granu u kojoj ima nacrta, pa
   proći pregled do kraja: ništa iz nje se ne nudi na potvrdu.

## 103. Motor: jedan panel, i nijedna ocena u stablu — 4.9.2026, nije viđeno uživo

Dve izmene istog dana, namerno spojene u jednu proveru: panel motora je dobio
jedan oblik, a stablo je ostalo **bez ijedne evaluacije na čvorovima**.

### A. Panel motora ima jedan oblik

Vlasnikova odluka: „Zadrži prekidač i dijalog, ujednači samo izgled panela."
Menjan je jedan vidžet (`stockfish_analysis_widget.dart`), pa se isti panel vidi
na tri mesta — i sva tri treba pogledati, jer se razlikuju po tome koja dugmad
im je prosleđena.

1. [ ] **Analysis Studio, AI Studio i soba imaju isti panel.** Otvoriti sva tri
   i uporediti sa „Pitaj motor" u repertoaru: okvir sa ivicom (ne obojena
   kartica), naslov „Motor", ispod njega jedan sitan red o tome koji motor
   odgovara i da je ocena iz ugla belog.
2. [ ] **Dubina je na svakom redu (`d20`), a ne u baneru iznad.** Banera
   `Eval: +0.35 (depth: 20)` i naslova „Top 3 Linije" više nema.
3. [ ] **Prekidač „Prikaži evaluaciju" i dalje pali i gasi motor**, na sva tri
   ekrana. Ovo je izričito zadržano — nije zamenjeno dugmetom.
4. [ ] **Dodir linije i dalje otvara pun pregled** (`EngineLineDialog`), a ne
   odigrava potez. Takođe zadržano namerno.
5. [ ] **„Ubaci liniju kao varijaciju" radi tamo gde ga ima.** Ikonica sa
   račvom, na ekranima koji imaju stablo poteza.
6. [ ] **Na telefonu (360 dp) ništa nije isečeno.** Naročito red „Prikaži
   evaluacionu liniju" sa prekidačem — natpis sme da se skrati sa „…", ali ne
   sme da nestane iza ivice. Isto proveriti sa uvećanim sistemskim fontom.
7. [ ] **Vrteška se vrti dok motor ćuti i nestane kad stignu linije.** Ne sme da
   se vrti dok je evaluacija ugašena.
8. [ ] **Zaključan motor kaže „Zaključano od strane trenera"** i ništa ne
   računa iza te poruke.

### B. Evaluacija je obrisana iz čvorova stabla

Vlasnikova odluka istog dana: ocena motora se **uopšte ne upisuje** u čvor. Ko
hoće da je zapamti, upisuje je kao komentar. Ovo je brisanje, pa se proverava i
šta je nestalo i šta je preživelo.

**Šta mora da nestane:**

9. [ ] **Na kartici u stablu nema broja.** Ni u Analysis Studiju ni u
   repertoaru: kartica nosi broj poteza, SAN i oznaku (`!`, `?`…) — i ništa u
   zagradi. Nema ni obojene tačkice pored natpisa.
10. [ ] **U alatnici grafičkog stabla nema dugmeta za filter.** Ikonice
    `filter_alt` više nema, a sa njom ni traka „Prag: 1.5 / 5.0" sa klizačem
    dole. Ostala dugmad (uvećaj, umanji, centriraj, reset, raspored, puštanje)
    su tu.
11. [ ] **Izvezeni PGN nema `[%eval …]`.** Izvesti partiju sa komentarima i
    oznakama i pogledati tekst: komentar i NAG jesu unutra, evaluacije nema.
12. [ ] **Strelice motora pokazuju potez, ne broj.** Posle „auto analize" na
    tabli se crtaju strelice — na njima piše SAN (npr. `Nf3`), ne `+0.35`.

**Šta mora da preživi:**

13. [ ] **Traka evaluacije i panel motora rade kao pre.** Brisanje je bilo u
    čvoru, a ne u prikazu uživo — `Prikaži evaluaciju` i evaluaciona linija
    ispod table i dalje pokazuju broj za poziciju na ekranu.
14. [ ] **Pregled cele partije i dalje piše komentare i oznake.** Pusti
    „analizu cele partije": greške dobijaju komentar i NAG. Samo broj na čvoru
    više ne postoji.
15. [ ] **Komentar se i dalje može upisati ručno**, i to je sada jedino mesto
    gde ocena može da ostane zapamćena uz potez. Upisati npr. „+0.35, motor
    d20", zatvoriti i otvoriti stablo — tekst je tu.
16. [ ] **Staro sačuvano stablo se i dalje otvara.** Ako postoji stablo
    sačuvano pre ove izmene (u kursu ili lekciji), otvoriti ga: mora da se
    učita normalno, samo bez brojeva na karticama.
17. [ ] **AI komentar se i dalje generiše.** „Generiši AI komentar" na potezu
    radi — s tim da mu evaluacija više ne stiže kao ulaz, pa se oslanja na
    taktičke i pozicione nalaze. Ako ispadne primetno slabiji nego ranije,
    zabeležiti; to je poznata posledica, ne kvar.

## 104. Fokus u stablu i lepeza u turi — 5.9.2026, delimično potvrđeno

Faze 1 i 4 iz `docs/PLAN-TABLA-I-STABLO.md`. Faza 3 (fiksna tabla) ide u zasebnu
stavku kad se spoji.

### A. Crtež stiže do pozicije na kojoj stojiš (faza 1)

Ovo se vidi **samo pri užoj širini**, jer pri „standard" i „broad" retko koji
potez ispadne iz reza. Postaviti repertoar na **„Samo glavna linija"** pre
provere.

1. [x] **Odigraj potez za protivnika koji nije glavni odgovor** (drugi ili treći
   po učestalosti). U stablu se **odmah pojavi kartica** za tu poziciju, a
   označena je **ta** kartica — ne koren repertoara.
2. [x] **Isto važi i kad potez prihvatiš iz spiska ispod table** („Potvrdi",
   „Uzmi …"), ne samo kad ga povučeš po tabli. Pravilo visi o tome da si potez
   odobrio, ne kojim putem.
3. [x] **Idi dva-tri poteza dublje niz tu granu.** Fokus ostaje na poslednjem
   potezu na svakom koraku — nijednom se ne vrati na početak. Ovo je „baca me
   negde" iz prijave.
4. [x] **Ostatak stabla nije nestao.** Glavna linija i sve ostalo su i dalje
   nacrtani; ovo dodaje tvoju poziciju, ne sužava crtež na nju.
5. [x] **Prebaci širinu na „standard" i nazad.** Ništa se ne gubi ni ne duplira.

### C. Tabla stoji, ostatak se skroluje (faza 3)

10. [x] **Skroluj ispod table na telefonu.** Tabla i navigaciona paleta ispod
    nje **ostaju na mestu**; pomera se samo ono ispod — komentar, pitanje,
    odgovori, kontrole, stablo.
11. [x] **Tabla nije isečena ni na jednom ekranu**, a ispod palete uvek ima šta
    da se skroluje. Proveriti i na uskom prozoru na Windowsu, ne samo na
    telefonu.
12. [x] **Baner je niži.** „N nepotvrđenih u grafu" sada zauzima oko pola
    prostora koliko ranije. Natpisi su isti — ništa nije skraćeno.
13. [ ] **Dugme „Pregledaj nepotvrđene" se i dalje lako pogađa prstom.** Ovo je
    jedina stvar koju je sažimanje moglo da pokvari: dugme je sada niže (32 px
    umesto 48). Ako je nezgodno pogoditi ga, reci — vraća se u jednom redu.
14. [x] **Tabla je možda malo manja nego ranije** na običnom telefonu (oko 16 px
    manja stranica), a ispod nje ima oko 100 px više. Ako ti je tabla premala,
    to je jedan broj koji se menja.

### D. Šansa linije i pogled na jednu granu (faza 5)

15. [x] **Zadrži pokazivač nad kartom u stablu** (ili je dugo pritisni na
    telefonu): piše „Šansa linije: X% (u okviru pokrivenog repertoara)".
    Rečenica mora da bude cela — zagrada nije ukras, bez nje broj laže.
16. [x] **Broj ima smisla.** Na tvom potezu je isti kao na poziciji pre njega
    (tvoj izbor nije verovatnoća), a na protivnikovom se množi njegovom
    učestalošću. Dublje u liniji broj pada.
17. [x] **Uporedi na dve širine.** Na „samo glavna linija" isti čvor pokazuje
    osetno veći procenat nego na „standard" — to je tačno i baš zato stoji
    zagrada. Ako ti ta rečenica i dalje deluje nejasno, reci kako bi je ti
    napisao.
18. [x] **„Prikaži samo od ove pozicije".** Dugme iznad stabla: crtež se svede
    na granu ispod pozicije na tabli, a putanja iznad stabla i dalje čita od
    prvog poteza.
19. [x] **„Prikaži ceo repertoar" vraća sve.**
20. [x] **Suženje se samo pušta** kad tablom odeš iznad te pozicije ili u drugu
    granu — crtež se vrati na ceo repertoar bez pritiska na dugme.
    **Provereno 5.9.2026: ne pušta se, i vlasnik je to prihvatio** („može samo u
    okviru stabla trenutno prikazanog, ali nije problem, meni odgovara").
    Razlog: dok je suženo, kretanje ide kroz ono što je nacrtano, pa nema načina
    da se izađe iz grane — pravilo koje pušta suženje nema šta da okine. Izlaz
    je dugme „Prikaži ceo repertoar", i to je za sada dovoljno.
21. [x] **Na kartici nema ocene motora**, a legenda iznad stabla je više ne
    pominje (ostatak od brisanja iz stavke 103).

### E. Prostor ispod table na desktopu (5.9.2026)

22. [x] **Potvrdio vlasnik 5.9.2026, na svežem bildu.** „Mnogo bolje" — na
    slici se ispod table vide i paleta, i traka linije, i napomena o kapiji, i
    pitanje sa brojkama, sve bez skrolovanja.
    **Na širokom prozoru ispod table ima osetno više mesta** nego na slici
    od 5.9.2026 ujutru. Tabla je manja (oko 470 umesto 560 na prozoru visine
    1000), a ispod nje staje pitanje sa odgovorima bez skrolovanja.
23. [x] **Potvrdio vlasnik 5.9.2026**: 472 px je ostalo dovoljno krupno za rad.
    **Tabla nije premala.** Ovo je jedan broj (`_boardShare`, sada 0,50) i
    menja se u minutu. Ako ti je tabla sada premala a prostor ispod prevelik,
    reci u kom pravcu.
24. [ ] **Isto pravilo važi i na telefonu** — tabla i tamo uzima pola visine.
    Proveri da nije ispalo premala na malom ekranu.

### F. Oba banera u zaglavlju na širokom prozoru (5.9.2026)

Prag je **1200 dp** (`ultraWide`), ne 840 — izmereno: na 900 dp zaglavlje se
prelilo 25 px sa imenom repertoara i banerom, a 139 px kad se doda i ime
otvaranja, jer dugme „Pregledaj nepotvrđene" ne može da se skupi.

25. [ ] **Na širokom prozoru (preko 1200 dp) i ime otvaranja i „N nepotvrđenih"
    stoje u zaglavlju**, pored naziva repertoara. Iznad table nema nijedne
    kartice — tabla je odmah ispod zaglavlja.
    **Prvo napravi nepotvrđene poteze** („Predloži glavnu liniju"), inače se
    baner ne crta ni na jednom mestu i stavka se ne može proveriti. Provera
    5.9.2026 je pala baš na tome: na slici je repertoar sa nula nepotvrđenih —
    ime otvaranja **jeste** bilo u zaglavlju, a banera nije bilo jer ga nema šta
    da prijavi. Kontrola: red ispod table tada ne kaže „nepotvrđeno N".
26. [x] **Dugme „Pregledaj nepotvrđene" iz zaglavlja radi** i vodi na prvu
    nepotvrđenu poziciju, isto kao ranije.
27. [x] **Suzi prozor ispod 1200 dp.** Oba se vraćaju iznad table i sve radi kao
    pre. Proširi nazad — vraćaju se gore.
28. [ ] **Ime otvaranja ne nestaje pri promeni veličine prozora.** Ovo je jedina
    prava zamka u ovoj izmeni: baner pamti **poslednje imenovano** otvaranje, pa
    ga treba dovesti u poziciju bez imena (dublje u liniji), pa vući ivicu
    prozora preko 1200 dp gore-dole. Ime mora da ostane.
29. [ ] **U zaglavlju nema zvučnika uz „N nepotvrđenih".** Namerno: ta ikonica ne
    može da se skupi i gurala je zaglavlje preko ivice. Zaglavlje ima svoj
    prekidač za govor, ali to **nije ista kontrola** — ako ti nedostaje čitanje
    baš te rečenice, reci.
30. [ ] **Na telefonu (uspravno i položeno) ništa se nije promenilo** — oba su i
    dalje iznad table. Telefon u položenom je oko 770 dp, dakle daleko ispod
    praga.

### G. Stablo ne pomera pogled samo od sebe (faza 2)

Vlasnikova prijava od 4.9.2026 21:55 i odluka od 5.9.2026: „aplikacija nikad ne
menja sama zum", i „ne mora trenutni potez da bude centriran na sred ekrana,
već samo ako priđe ivicama". Važi na **svakom** ekranu koji crta grafičko
stablo, ne samo u repertoaru — jedan vidžet je iza svih.

**Prvo zumiraj**, jer bez toga se ništa od ovoga ne vidi: `+` u alatnici stabla
dva-tri puta.

29. [x] **Kretanje kroz liniju ne pomera crtež.** Sa uzumiranim stablom idi
    potez po potez dok je aktivna kartica na sredini ekrana. Crtež **stoji** —
    ne skače, ne pomera se ni za piksel. Ovo je „izgubi fokus" iz prijave.
30. [x] **Kad kartica priđe ivici, crtež se pomeri malo.** Nastavi niz liniju do
    dna vidljivog dela: crtež se pomeri **tek toliko** da kartica uđe unutra, sa
    oko jedne kartice mesta do ivice. Ne skače na sredinu.
31. [x] **Zum se pri tome ne menja.** Veličina kartica je posle celog hoda ista
    kao pre. Ovo je pola prijave i mora da se pogleda odvojeno od pomeranja.
32. [x] **Dugme „Centriraj na aktivni potez" i dalje centrira.** Ono je
    korisnikov zahtev i namerno je ostalo kakvo je bilo — kartica ide na sredinu.
33. [ ] **„Resetuj pogled", `+`, `−`, kolo miša i pinch rade kao pre.**
34. [ ] **Isto u Analizi, ne samo u repertoaru.** Otvori Analysis Studio,
    uzumiraj stablo i prođi partiju strelicama.

**Ono što ova faza nije popravila, popravljeno je istog dana i ima svoj deo:**
promena širine prozora preko 840 px vraćala je zum na 100% (izmereno dva puta
5.9.2026, 1,5625 → 1,0). To je **deo H** ispod.

### H. Zum i pogled prežive promenu veličine prozora (5.9.2026)

Isti vlasnikov zahtev kao G — „aplikacija nikad ne menja sama zum" — ali drugi
uzrok, i zato zaseban deo. Stablo se u gradnji repertoara crta na dva mesta:
pored table na širokom prozoru, ispod kontrola na uskom, a granica je 840 dp.
Vidžet koji se pri prelasku premesti dobijao je **novo stanje**, pa nov
kontroler pogleda, pa zum 1,0. Sada nosi stalan ključ, kao i baner sa imenom
otvaranja, pa isto stanje preživi selidbu.

**Ovo se vidi samo na Windowsu** (i na desktopu uopšte) — telefon ne menja
širinu prozora.

35. [ ] **Uzumiraj stablo, pa vuci desnu ivicu prozora preko 840 dp gore-dole.**
    Veličina kartica ostaje ista i posle prelaska, u oba smera. Ranije se
    vraćala na 100%.
36. [ ] **I pomeraj (pan) ostaje.** Odvuci crtež u stranu pre prelaska; posle
    prelaska si na istom delu stabla. Izuzetak koji je u redu: ako se aktivna
    kartica u užem prozoru nađe uz ivicu, crtež se pomeri **tek toliko** da uđe
    unutra — to je pravilo iz dela G, ne resetovanje.
37. [ ] **Prekidač „graf / notacija" ostaje kako si ga ostavio.** Prebaci na
    notaciju, pa pređi prag: i dalje je notacija.
38. [ ] **Stablo je na ekranu tačno jednom pri svakoj širini.** Vuci ivicu polako
    kroz 840 dp: nema trenutka u kome se vide dva crteža, i nema crvenog ekrana
    sa greškom.
39. [ ] **Ime otvaranja i dalje preživi svoj prag (1200 dp)** — deo F, stavka 28.
    Ova izmena je istog oblika i ne sme da ga pokvari.

### B. Lepeza neodgovorenih odgovora u turi (faza 4)

6. [ ] **„Upoznaj repertoar" na poziciji gde protivnik ima više odgovora i ni na
   jedan nemaš odgovor.** Tura se **ne zaustavlja** ni na jednom od njih —
   linija se završava **tvojim** potezom, a račva pre njega ih je već nabrojala
   („Odavde protivnik ima N odgovora: …").
7. [ ] **Usamljena rupa se i dalje pokazuje.** Pozicija sa **tačno jednim**
   neodgovorenim odgovorom i dalje ima svoje stajanje i i dalje kaže „Na …
   nemate odgovor." Ovo je izuzetak koji je namerno zadržan.
8. [ ] **Mešana pozicija.** Gde je jedan odgovor odgovoren a drugi nije: u
   odgovoreni se ulazi kao i pre, a neodgovoreni ostaje kao stajanje (jer je
   sam).
9. [ ] **Govor je ređi nego ranije** na takvim mestima — jedna rečenica umesto
   pet. Ako ti se čini da se i dalje ponavlja, zabeleži gde.

## 105. Širina se menja iz legende, bez pisanja poteza — potvrđeno 5.9.2026

Prijava od 5.9.2026 uveče: „nema smisla da biram šta igra protivnik, kad mi se
potezi sami dodaju." Odgovor je u dva dela — objašnjenje (protivnikovi odgovori
dolaze iz statistike, a širina kaže koliko ih se uzima) i popravka (do širine se
više ne stiže kroz dijalog koji usput upiše celu liniju predloga).

1. [x] **Ispod crteža stoji „Koliko odgovora: uobičajeno 80%" i to je dugme** —
   ima ikonicu i otvara se na dodir. Ranije je bio običan tekst.
2. [x] **Otvara se dijalog „Koliko odgovora spremamo"**, sa tri izbora i bez
   ijedne dubine. Naslova „Predloži glavnu liniju odavde" nema.
3. [x] **Dijalog je otvoren na širini koju repertoar već ima** — ne na
   „Uobičajeno" bez obzira na stanje.
4. [x] **„Sačuvaj" menja crtež odmah.** Izaberi „Samo glavni odgovor": ispod
   svakog tvog poteza ostaje **jedan** protivnikov odgovor umesto talasa, a red
   legende sada kaže „samo glavni odgovor".
5. [ ] **Ništa nije upisano.** Nijedan nov potez se nije pojavio u stablu, a red
   ispod table kaže isto što je govorio pre promene širine — „odlučeno N ·
   otvoreno M", i „nepotvrđeno K" **samo ako ga je i pre bilo**. Ovo je cela
   poenta izmene.
   Stavka je 5.9.2026 prvo bila napisana preko banera „N nepotvrđenih", koji na
   repertoaru bez nepotvrđenih poteza uopšte ne postoji — pa je izgledala kao
   kvar („ne vidim baner"). Broj u redu ispod table je isti podatak i vidi se
   uvek.
6. [x] **„Odustani" ne menja ništa** — ni širinu, ni crtež.
7. [x] **Ono što si sam uzeo ostaje i na najužoj širini.** Ako si negde
   pritisnuo „Spremi i ovo", taj protivnikov potez mora da se vidi i na „Samo
   glavni odgovor". Isto važi za pozicije u kojima si već odlučio.
8. [x] **Vrati na „Uobičajeno (80%)"** — sve se vraća kako je bilo. Širine su
   ugnežđene, pa proširivanje sme samo da dodaje.
9. [x] **Zatvori i otvori repertoar iz spiska** — širina je i dalje ona koju si
   izabrao, dakle upisana je u red repertoara, a ne samo u ekran.
10. [x] **U turi „Upoznaj repertoar" taj red nije dugme.** Tura je pregled, ne
    mesto za menjanje repertoara.

## 106. Crtež stiže do table posle „Idi" — potvrđeno 5.9.2026

Prijava od 5.9.2026: „posle izbora poteza protivnika, taj potez se ne prikazuje
na stablu poteza, a trebalo bi — da vidim i u stablu na šta treba da
odgovaram." Server je bio ispravan; klijent je crtež ponovo čitao samo kad se
nešto upiše, a crtež se od 4.9. čita **od mesta gde je tabla**.

1. [ ] **Dodirni svoj potez u stablu**, pa u spisku „Posle <potez> — šta igra
   protivnik" pritisni **„Idi"** na odgovoru koji je već u pripremi.
2. [x] **Taj protivnikov potez se vidi u stablu**, i to je **osvetljena**
   kartica — dakle vidi se i gde si i na šta odgovaraš.
3. [x] **Isto važi dublje u liniji.** Ponovi to nekoliko poteza zaredom: svaki
   put kartica postoji i osvetljena je. Ranije je osvetljenje ostajalo na
   prethodnom potezu.
4. [x] **Kretanje unutar crteža je i dalje trenutno** — dodirivanje kartica
   koje se već vide ne pravi novo učitavanje i ne trese sliku.
5. [x] **Zum se pri tome ne menja** (stavke 104-G i 104-H). Ponovno čitanje
   crteža ne sme da vrati razmeru na 100%.
6. [x] **Ako se potez i dalje ne vidi**, zapiši koji je, na kojoj širini i na
   kojoj dubini — tada je uzrok server (transpozicija ili knjiga bez tog reda),
   a ne ovo.


## 107. Skener kaže koji je od tri problema — 5.9.2026, nije viđeno uživo

Napravljeno 5.9.2026 posle četiri knjige koje su pale iz četiri različita
razloga uz istu poruku. Odeljak „Skener kaže koji je od tri problema" u
[STANJE-RADA.md](STANJE-RADA.md) ima brojke.

Za ovu proveru trebaju tri fajla: bilo koja **skenirana** knjiga (strane su
slike), knjiga sa **tekstom ali slikama umesto dijagrama** (npr. bilo šta sa
archive.org što se može selektovati mišem), i bilo koji PDF **veći od 25 MB**.

1. [ ] **Skenirana knjiga** → poruka kaže da je knjiga slika i da u njoj nema
   teksta. Ne sme da pomene font.
2. [ ] **Knjiga sa tekstom, dijagrami slike** → poruka kaže da teksta ima ali da
   su dijagrami slike. Ni ovde se font ne pominje.
3. [ ] **PDF veći od 25 MB** → poruka imenuje granicu („veća od 25 MB") i kaže
   da se PDF podeli. Ranije je pisalo „Skeniranje nije uspelo (500)".
4. [ ] **Knjiga koja radi i dalje radi.** `chessboard.pdf`, strane 1–40: 31
   pozicija, font `SkakNew-Diagram (LaTeX skak)`. Ovo je jedina stavka koja
   proverava da popravka nije ništa pokvarila.
5. [ ] **Nijedna poruka se ne pojavi dvaput** i nijedna ne ostane na ekranu
   posle sledećeg skeniranja.


## 108. Interaktivna lekcija — korak koji pita (faza 9)

Napravljeno 5–6.9.2026, faze 0–7 na grani `feat/interactive-lessons`. Ovo je
živa provera iz faze 9 plana [PLAN-INTERAKTIVNA-LEKCIJA.md](PLAN-INTERAKTIVNA-LEKCIJA.md).
**Više ne čeka ništa** — trenerski uređivač je gotov, pa se korak pravi u
aplikaciji a ne ručno u `position_list`.

Redosled je namerno ovakav: prvo se korak **napravi** (stavke 17–22), pa se onda
proverava kako izgleda **detetu** (stavke 1–16). Treba jedna lekcija sa tri
koraka: jedan `show`, jedan `ask_move` (sa `acceptedSans`, da se vidi i druga
tačna varijanta) i jedan `ask_choice`.

1. [ ] **Stara lekcija bez `kind`-a i dalje radi** — otvori bilo koji postojeći
   zadatak lekcije. Tabla se igra, ništa ne pita, nema banera. Ovo je jedina
   stavka koja proverava da ništa nije pokvareno.
2. [ ] **`ask_move`, tačan potez** → „Tačno." i ništa više.
3. [ ] **`ask_move`, druga tačna varijanta** → „Tačno. Mi nastavljamo posle
   `<potez>`." Figure ostaju tamo gde si ih ti odigrao — rečenica kaže odakle
   lekcija ide dalje, tabla se ne pomera sama.
4. [ ] **`ask_move`, pogrešan potez** → poruka je **serverova** („taj potez nije
   moguć u ovoj poziciji" i „nije traženi potez" su dve različite poruke i moraju
   da se razlikuju), a **figure se vrate na početnu poziciju koraka**. Odigraj
   odmah drugi potez: mora da bude primljen normalno, bez pritiska na išta.
5. [ ] **„Pokaži mi" se ne nudi posle prve greške**, a posle druge se pojavi.
   Pritisni ga: pokaže „Rešenje: `<potez>`".
6. [ ] **`ask_choice`** → opcije se vide, **tabla se ne igra** (probaj da
   povučeš figuru — ne sme da se pomeri), izbor šalje odgovor i verdikt stiže.
7. [ ] **Tačno i netačno se razlikuju i bez boje.** Vlasnik je daltonista:
   gledaj ikonicu i oblik banera, ne nijansu.
8. [ ] **Na telefonu (360 dp) ništa nije odsečeno.** Izmereno u testu 5.9.2026 i
   čisto je, ali release build ne crta upozorenje pa se gleda okom. **Opcije kod
   `ask_choice` su ispod prevoja** — treba skrolovati ispod table da bi se
   videle. To nije kvar; odluka je da li je prihvatljivo detetu koje prvi put
   vidi ekran.
9. [ ] **Isključi mrežu usred odgovora** → „Odgovor nije poslat — proveri vezu."
   i tabla ostaje tamo gde je bila. Dete sme odmah da pokuša ponovo.
10. [ ] **Nigde nema tajmera, bodova ni niza.** Ovaj ekran se koristi u sekciji
    gde deca vide ekrane jedno drugom.

Uz to, faza 6 (crtež i glas, paket 49) — za ovo treba korak čiji PGN nosi
`[%csl]` i `[%cal]`, jedan pre prvog poteza i jedan uz potez:

11. [ ] **Polje koje je autor obojio se vidi kao prsten**, i vidi se **pre**
    prvog poteza. Prsten ima crnu i belu ivicu oko boje — to je ono što ga drži
    čitljivim na svakoj tabli i za svako oko; ako se vidi samo boja, nešto nije
    nacrtano kako treba.
12. [ ] **Prsten se ne meša sa poslednjim potezom** (uglovi) ni sa poljem sa
    kog trener crta (pun krug). Razlika je oblik, ne nijansa.
13. [ ] **Korak napred menja crtež**, korak nazad ga vraća. Prođi liniju do
    kraja i natrag.
14. [ ] **`[%csl Yd5]` daje siv prsten**, jer paleta nema žutu. To je poznato i
    zapisano; pitanje za uživo je da li je sivo dovoljno ili paleti treba šesta
    boja — a šesta se **meri** u postojeći skup (1.5:1 na svaki par, pod
    protanopijom i deuteranopijom), ne bira.
15. [ ] **Zvučnik pored zadatka i pored beleške radi**, i čita **tačno ono što
    piše**. Ništa se ne izgovara što nije napisano.
16. [ ] **Sa isključenim govorom ekran ne gubi ništa** — svaka rečenica koja bi
    se čula i dalje stoji napisana.

Trenerova strana, faza 7 (paket 50) — ovim se lekcija iz gornjih stavki i pravi:

17. [ ] **Dva dugmeta postoje u Analitičkom studiju**, pored „Izvezi PGN":
    „Napravi korak od ove pozicije" i „Uredi korake lekcije". Proveri i na
    telefonu: **„Analiziraj celu partiju" mora i dalje da bude u traci**, ne u
    meniju — jedno od njih je bilo ubačeno na prvo mesto i tiho ga izbacilo.
17a. [ ] **„Uredi korake lekcije" zaista otvara editor.** Pitanje glasi „Koju
    lekciju uređuješ?", izbor otvara ekran sa koracima. Ovo je stavka zbog koje
    je 7c i postojala: panel je bio napravljen i testiran, a nijedan ekran ga
    nije otvarao.
18. [ ] **Korak napravljen iz studija nosi crtež.** Nacrtaj strelicu i oboji
    polje u studiju, napravi korak, pa ga otvori kao đak — strelica i prsten su
    tu. To je i razlog zašto dugme stoji baš na tom ekranu.
19. [ ] **Tri polja rade:** rečenica, vrsta koraka, odgovor. Tačan potez se
    **odigra na tabli**, ne kuca.
20. [ ] **Server odbija, a trener vidi zašto.** Napravi `ask_move` bez rešenja i
    sačuvaj: poruka mora da kaže koje je pravilo prekršeno, a ne „Čuvanje nije
    uspelo". Isto za `ask_choice` sa dva tačna odgovora.
21. [ ] **Izmena ne gubi korake.** Otvori postojeću lekciju, promeni tekst
    jednog koraka, sačuvaj, pa je otvori ponovo — svi koraci su tu, istim
    redom. Zatim **preimenuj jednu pojedinačnu poziciju** i proveri da lekcija
    sa koracima nije dirnuta (to je popravka iz 7a).
22. [ ] **„Pregled" pokazuje đačkov ekran i ništa ne šalje.** Odigraj potez u
    pregledu: piše da je ovo pregled i da potez nije poslat na proveru. Ne sme
    da se pojavi „Odgovor nije poslat — proveri vezu." ni ocena.
23. [ ] **U `CreateCourseDialog` više nema unosa zadatka** — samo redosled i
    izbor pozicija. Tekst koraka se piše u studiju.

Popravke od 6.9.2026 — korak nosi liniju, ne samo sliku:

24. [ ] **Korak napravljen usred linije zaista nosi poteze.** U studiju odigraj
    liniju od bar tri poteza sa komentarom uz svaki, stani na treći potez i
    napravi korak. Kao đak: traka „Potez N od M" postoji, listanje menja
    poziciju, i uz svaki potez stoji komentar koji si napisao. Ranije se ovde
    dobijala **nepomična slika**, bez trake i bez ijednog komentara, a trener je
    pri čuvanju video „Korak uspešno dodat".
25. [ ] **Pitanje „Odakle počinje korak?"** iskoči kad ne stojiš na početnoj
    poziciji stabla — „Od početka linije" daje celu liniju, „Odavde" samo ono
    što sledi. Ako stojiš u **sporednoj varijanti**, u pitanju stoji i
    upozorenje da „od početka linije" prikazuje glavnu, a ne tvoju liniju.
    Kad stojiš na korenu, pitanja nema.
26. [ ] **Rečenica o početnoj poziciji stiže do đaka.** U studiju napiši
    komentar dok tabla stoji na **prvoj** poziciji koraka (pre ijednog poteza),
    napravi korak, otvori kao đak: rečenica se vidi odmah, na potezu 0. Kreni
    napred — zameni je komentar prvog poteza; vrati se nazad — opet je tu.

Pedagoški šablon iz 6.9.2026 — lekcija se sluša, pa se pita.

**Tačke 24–29 se namerno drže na čekanju do faze 5 `PLAN-TUTORIJAL.md`** —
zajedničke provere uživo na uređajima, odluka vlasnika 6.9.2026. Razlog je da se
ne proverava tri puta isti ekran: pregledač je od tada dobio i grananje (batch
52), pa se sve ovo gleda odjednom, na telefonu i na Windowsu, kad autorska
strana bude gotova. Ništa od ovoga nije viđeno kako radi.


27. [ ] **Linija se šeta brzinom glasa.** Uključi govor, otvori korak sa
    linijom i pritisni „Pročitaj mi liniju" u traci poteza. Svaki potez se
    odigra **tek kad se rečenica ispred njega dovrši** — ne ranije, i ne po
    tajmeru. Test za ovo je lekcija o opoziciji iz razgovora:
    `8/8/8/3k4/8/8/3PK3/8 w - - 0 1` sa `1. Kd3 … Ke5 … 2. Kc4 … Kd6 3. Kd4`.
    Proveri i da zelena polja e4/d4/c4 stoje **dok** se čita rečenica o Kd3, i
    da nestanu sa sledećim potezom.
27a. [ ] **Dete može da preuzme.** Pritisak na „Prethodni potez", na strelicu,
    ili potez odigran rukom — zaustavlja čitanje i glas ućuti. „Zaustavi
    čitanje" isto. Sa isključenim govorom dugmeta za čitanje nema, a listanje
    radi kao i pre.
28. [ ] **Demonstracija prelazi u pitanje bez skoka.** Napravi lekciju od dva
    koraka: `show` sa linijom koja se zaustavi na nekoj poziciji, pa
    `ask_move` **na toj istoj poziciji**. Sa uključenim govorom: po kraju
    linije lekcija sama pređe na pitanje, narator ga izgovori, i tabla se
    otključa — **bez treptaja, bez okretanja table, bez učitavanja novog
    ekrana**. Ovo je tačka koju treba gledati u oči: ako se tabla makar na
    trenutak „resetuje", nije dobro.
28a. [ ] **Isto važi i rukom.** Sa isključenim govorom dođi do kraja linije i
    pritisni „Sledeći korak" — ista tabla, ista orijentacija, samo se otključa.
29. [ ] **Korak koji počinje drugde se ne otvara sam.** Ako sledeći korak stoji
    na nekoj **drugoj** poziciji, čitanje stane na kraju linije i čeka dete.

## 109. Studio za tutorijal — školjka — 6.9.2026, nije viđeno uživo

Faza 4a iz `docs/PLAN-TUTORIJAL.md`. **Samo Windows** — na Androidu vrata nisu
nacrtana i to je jedna od stavki. Kao i tačke 24–29, **čeka fazu 5**: ekran je
tek pola gotov (polja i lista primera su batch E), pa se gleda odjednom kad
autorska strana bude cela.

1. [ ] **Vrata postoje tamo gde treba.** U Analiznom studiju na Windowsu, u
   traci alata, stoji „Kreiraj interaktivni tutorijal". **Na telefonu ga
   nema** — ni u traci, ni u meniju „Još alata".
2. [ ] **Pozicija se prenosi.** Stani na neku poziciju bez nastavka i otvori
   vrata: novi ekran se otvori na **toj** poziciji, sa istom stranom table.
3. [ ] **Cela linija se prenosi.** Stani na potez iza kojeg ima nastavka i
   varijanti; na pitanje odgovori „Celu liniju". U stablu novog ekrana su svi
   ti potezi i sve varijante.
4. [ ] **Analiza se ne menja.** Vrati se u Analizni studio i proveri da je
   stablo tamo netaknuto — potez odigran u tutorijalu ga ne sme dirati.
5. [ ] **Grananje pita.** Na novom ekranu odigraj potez, vrati se nazad, pa
   odigraj **drugi** potez iz iste pozicije. Vrati se na početak i pritisni
   „Sledeći potez": pojavi se izbor sa oba poteza, ne šeta u prvi sam.
6. [ ] **Nacrt preživi zatvaranje.** Odigraj par poteza i **zatvori prozor
   odmah**, ne čekajući — pa otvori ekran ponovo. Sve je tu, i tabla stoji na
   potezu na kojem si stao. Ovo je tačka koju treba gledati u oči: greška bi se
   videla samo ako se zatvori u prvoj sekundi.
7. [ ] **Strelice na tastaturi šetaju liniju**, kao u Analiznom studiju.

## 110. Pitanje ne nosi odgovor — 6.9.2026, nije viđeno uživo

Popravka od 6.9.2026 u `LessonStepEditorPanel`. Kao i tačke 24–29 i 109, ide u
zajedničku proveru uz fazu 5 `PLAN-TUTORIJAL.md`.

1. [ ] **Pita pre nego što se desi.** Otvori tutorijal čiji korak nosi liniju i
   postavi mu tip „Traži potez na tabli". Pojavi se pitanje „Dete bi videlo
   odgovor"; „Odustani" vraća tip na ono što je bio — proveri da padajući meni
   **stvarno pokazuje stari tip**, ne novi.
2. [ ] **„Ukloni liniju i postavi pitanje"** ukloni liniju i postavi pitanje; u
   „Pregled" se vidi da trake poteza više nema.
3. [ ] **Stari korak se prijavi sam.** Ako neki već sačuvan korak ima i liniju i
   „Traži potez na tabli", pri otvaranju stoji crveno upozorenje, čuvanje se
   odbija i poruka imenuje baš taj korak. Posle „Ukloni liniju" čuvanje prođe i
   **tačan potez ostaje zapisan**.
4. [ ] **Pitanje sa ponuđenim odgovorima i dalje sme da nosi liniju** — ništa ne
   pita i ništa ne odbija.

## 111. Studio za tutorijal — pisanje i čuvanje — 6.9.2026, nije viđeno uživo

Faza 4b (batch 54). Ide zajedno sa tačkom 109, uz fazu 5.

1. [ ] **Napiši tutorijal od dva primera u jednom dahu.** Ime tutorijala, pa
   linija sa rečenicom uz svaki potez, pa „+ Dodaj sledeću poziciju u
   tutorijal" — tabla ostaje na poziciji na kojoj se linija završila. Drugi
   primer postavi kao „Traži potez na tabli" i odigraj tačan potez: piše
   „Tačan potez: …", a potez **se ne dodaje u liniju**.
2. [ ] **Do „Sačuvaj tutorijal" ništa nije otišlo na server** — tutorijal se ne
   pojavljuje u biblioteci dok ne pritisneš to dugme.
3. [ ] **Otvori sačuvani tutorijal kao đak.** Primer 1 se čita kao linija sa
   rečenicama, pa se bez učitavanja table pređe na pitanje.
4. [ ] **Ime preživi zatvaranje.** Upiši ime, zatvori prozor odmah, otvori
   ponovo — i ime i primeri su tu. (Ovo je popravka vođe pri spajanju; ime je
   bilo jedino što se nije vraćalo.)
5. [ ] **Pitanje sa ponuđenim odgovorima:** dodaj dva odgovora, označi tačan,
   sačuvaj; pa probaj da sačuvaš bez označenog — odbija se **pre** slanja.

## 112. Koraci tutorijala — dodaj, obriši, premesti — 6.9.2026, nije viđeno uživo

Faza 4c (batch 55), u editoru koraka. Ide uz tačke 109 i 111, uz fazu 5.

1. [ ] **Premesti korak.** Otvori tutorijal sa tri koraka, stani na treći,
   „Pomeri gore". Redosled se promeni, a **editor i dalje pokazuje taj isti
   korak** — naziv u polju je njegov, ne od suseda. Sačuvaj, pa ponovo otvori
   tutorijal: redosled je zapamćen.
2. [ ] **Dodaj korak.** Stani na neki korak, „Dodaj korak" — novi se pojavi
   **odmah ispod** njega, na istoj poziciji, prazan (bez pitanja i bez rešenja).
   Daj mu naziv, sačuvaj, pa ponovo otvori: tu je, pod tim nazivom.
3. [ ] **Ovo je tačka koju treba gledati u oči.** Ako je neki đak već radio taj
   tutorijal, posle dodavanja i čuvanja **njegov napredak na ostalim koracima
   mora da ostane**. To je ceo razlog zbog kojeg su oznake koraka pisane ovako;
   proveri na nalogu koji je već odgovarao bar jedan korak.
4. [ ] **Obriši korak.** Pita pre brisanja i **imenuje korak**. „Odustani" ga
   ostavlja. Posle brisanja ostali koraci su netaknuti.
5. [ ] **Poslednji korak se ne briše.** Na tutorijalu sa jednim korakom
   „Obriši korak" kaže da ne može i ništa ne pita.
6. [ ] **Strelice na krajevima su ugasene** — gore na prvom, dole na poslednjem.

## 113. Panel „Delovi tutorijala" — 6.9.2026, nije viđeno uživo

P5a (batch 57), u studiju za tutorijale. Ide uz tačku 111.

1. [ ] **Izbor pomera sve.** Napravi dva dela, u svakom po jedan potez i po
   jednu rečenicu. Klikni na „Deo 1" — **tabla, stablo i rečenica** su njegovi,
   ne od dela u kome si upravo stajao. Ovo je jedina stvar zbog koje panel
   postoji; ako red posivi a tabla ostane, sve ostalo je nevažno.
2. [ ] **Ništa ne ide na server dok ne pritisneš „Sačuvaj tutorijal".**
   Dodavanje, pomeranje, kloniranje i brisanje su lokalni.
3. [ ] **„+ Dodaj deo" pita gde počinje.** „Nastavi odavde" otvara deo na
   poziciji na kojoj se prethodnom linija završila; „Nova pozicija" na praznoj
   tabli; „Otkaži" ne dodaje ništa.
4. [ ] **Spojnica.** Posle „Nastavi odavde" drugi deo nosi znak lanca sa
   objašnjenjem „Nastavlja se na prethodni deo". Pomeri ga gore — znak nestaje,
   jer više ne stoji iza dela na čijem se kraju nalazio. **To je ceo razlog
   zbog kog spojnica postoji: da autor vidi šta je razmeštanjem pokvario.**
5. [ ] **Poslednji deo se ne briše.** Na tutorijalu sa jednim delom „Obriši
   deo" kaže rečenicu i ništa ne pita.
6. [ ] **Brisanje pita.** Na dva dela „Obriši deo" pita „Brisanje dela";
   „Odustani" ga ostavlja.
7. [ ] **Kloniranje ostavlja tebe na kopiji**, i kopija nosi rečenicu
   originala.
8. [ ] **Numeracija prati redosled i posle čuvanja.** Pomeri deo, sačuvaj,
   zatvori i otvori tutorijal ponovo — imena su „Deo 1", „Deo 2" po novom
   redosledu. (Ovo je popravka vođe; kapija radnika je gledala ekran, a ekran
   je crtao tačne reči preko netačnih podataka.)
9. [ ] **Pogledaj kontraste, jer ih kapija nije merila.** Izabrani red se
   razlikuje od neizabranog i po podlozi i po debljini slova, a znak lanca ima
   svoj oblik — ništa ne sme da zavisi od boje same.

## 114. Podeljeni raspored studija — 6.9.2026, nije viđeno uživo

P5b (batch 58), u studiju za tutorijale. Ide zajedno sa tačkom 113 — isti ekran,
isti prolaz.

1. [ ] **Dve polovine, dva skrola.** Otvori tutorijal sa nekoliko delova, pa
   skroluj donju polovinu do stabla. **Spisak delova ostaje na mestu.** To je
   ceo razlog zbog kog je raspored promenjen; ako se spisak pomera zajedno sa
   poljima, ništa drugo nije važno.
2. [ ] **Tabla raste sa prozorom, polja ne.** Razvuci prozor — tabla postaje
   veća, desna kolona ostaje iste širine. Suzi ga nazad; ništa se ne iseca.
3. [ ] **Tabla stoji na sredini svoje polovine**, a ne uz levu ivicu, kad je
   prozor širok (tada je tabla ograničena visinom pa ostaje prazan prostor).
4. [ ] **„Sačuvaj tutorijal" je u traci na vrhu** i vidi se uvek, bez obzira
   koliko skrolovao. Sačuvaj tutorijal bez naziva: poruka o grešci se pojavi na
   dnu i **ne prekriva dugme** — to je i razlog zašto je dugme gore.
5. [ ] **Uzak prozor.** Suzi prozor ispod ~840 px: raspored se vraća na tablu
   gore i jednu kolonu ispod, kao pre. Ništa se ne iseca i ne vidi se žuto-crna
   traka. Sačuvaj je i dalje u traci na vrhu.
6. [ ] **Spisak delova sa mnogo delova.** Na tutorijalu sa desetak delova gornja
   polovina skroluje **unutar sebe**, a donja ostaje gde je bila.

## 115. Hronologija „Tok" — 7.9.2026, nije viđeno uživo

P6a (batch 59), u studiju za tutorijale, na dnu desne kolone. Ide zajedno sa
tačkama 113 i 114 — isti ekran, isti prolaz.

1. [ ] **„Tok" je ono što se otvori.** Otvori sačuvan tutorijal: dole stoje dve
   kartice, „Tok" je napred, i linija se čita odozgo nadole — „Polazna
   pozicija", pa „posle 1. e4", pa dalje.
2. [ ] **Rečenica stoji između dva poteza.** Na taktu na kome si nešto napisao,
   tekst je **ispod** naslova a **iznad** „pa se igra: …". Tako to dete i dobija:
   prvo mu se kaže šta da vidi, pa se onda odigra potez.
3. [ ] **Brojevi poteza su tačni**, i na delu koji počinje iz sredine partije —
   napravi deo iz pozicije sa, recimo, 12. potezom i proveri da piše „posle
   12. …", a ne „posle 1. …".
4. [ ] **Klik na karticu pomera tablu.** Klikni na neki takt: tabla ode na tu
   poziciju, a oznaka tekućeg takta se preseli na tu karticu.
5. [ ] **Grananje.** Na delu sa sporednom linijom, na taktu grananja stoje čipovi
   sa oba odgovora. Pritisni onaj koji nije uzet — **hronologija se precrta niz
   tu granu**, a stara se više ne vidi.
6. [ ] **„Stablo" je i dalje tu.** Prebaci na „Stablo": stablo je isto kao pre.
   Zumiraj ga, prebaci na „Tok" pa nazad — **zum je ostao**. (To je razlog zbog
   kog obe kartice ostaju napravljene.)
7. [ ] **Pogledaj oznake.** Tekući takt i uzeti čip razlikuju se po podlozi,
   okviru, debljini slova i ikonici — ništa ne sme da zavisi od same boje.

## 116. Tutorijal se piše u hronologiji — 7.9.2026, nije viđeno uživo

P6b (batch 60), isti ekran kao 113–115 i ide u istom prolazu. Ovo je prvi put
da se lekcija piše na mestu na kome se čita, pa je težište na tome gde tekst
**završi**, a ne kako izgleda.

1. [ ] **Polja su otišla iz kolone.** Iznad kartica „Tok"/„Stablo" stoje samo
   naziv tutorijala i spisak delova. Nigde drugde nema polja za rečenicu ni za
   pitanje.
2. [ ] **Svaka kartica ima svoje polje.** Napiši različitu rečenicu na tri
   uzastopna takta, sačuvaj, zatvori i otvori tutorijal ponovo — **svaka
   rečenica je na svom potezu**. (Ovo je jedina tačka koju vredi uraditi dvaput.)
3. [ ] **Klik u tuđe polje ne guta kucanje.** Stani na jedan takt, pa **klikni
   direktno u polje druge kartice i odmah kucaj** — slova moraju da uđu u to
   polje. Kartica postaje tekuća, tabla ode na tu poziciju, a kursor ostaje gde
   si kliknuo. (Ovo je popravljeno na sluh testom, ali se vidi tek uživo.)
4. [ ] **Nalepnica „Komentar za trenutni potez" stoji samo na tekućoj kartici.**
   Ostale kartice imaju polje bez nalepnice. Ako ti izgleda golo, reci — to je
   odluka o tekstu, ne o kodu.
5. [ ] **Pitanje je na kraju linije.** Kartica sa „Tip zadatka" stoji **ispod
   poslednjeg takta**, jednom, i nigde drugde. Promeni tip na „Traži odgovor iz
   liste": tu se pojave i zadatak i ponuđeni odgovori.
6. [ ] **Pitanje preživi čuvanje.** Postavi pitanje sa dva odgovora, sačuvaj,
   otvori ponovo — tip, zadatak i odgovori su tu. (Do 7.9.2026 nisu bili; vidi
   tačku 111.)
7. [ ] **Grananje nosi i polja.** Na delu sa sporednom linijom pritisni čip
   neuzete grane: kartice se precrtaju niz tu granu i **u poljima je tekst te
   grane**, a ne rečenice linije koju si napustio.
8. [ ] **Duga linija.** Napravi deo od desetak poteza i proveri da se donja
   polovina skroluje do kartice sa pitanjem — ništa ne sme da ostane
   nedohvatljivo ispod ivice.

## 117. Trener crta po tabli u studiju — 7.9.2026, nije viđeno uživo

P7a (batch 61), studio za tutorijale, traka ispod table. Ide u istom prolazu kao
113–116. Do ovoga je **svaka strelica u svakoj lekciji bila ukucana rukom u
PGN**, pa je ovo prvi put da neko crta iz aplikacije.

1. [ ] **Traka je ispod table**, iznad dugmadi za kretanje kroz poteze: „Strelica",
   „Polje", pet krugova sa bojama i „Obriši oznake".
2. [ ] **Strelica.** Pritisni „Strelica" (dugme se oboji), pa klikni dva polja —
   strelica se nacrta. Klikni ista dva polja opet — nestane.
3. [ ] **Brisanje ne gleda boju.** Nacrtaj zelenu strelicu, promeni boju na
   crvenu, pa klikni ista dva polja — strelica **mora** da nestane. (Namerno je
   tako: ispravlja se „pogrešna strelica", ne „pogrešna boja".)
4. [ ] **Polje.** Pritisni „Polje" pa klikni polje — nacrta se prsten. Klikni
   isto polje opet — nestane.
5. [ ] **Dok crtaš, figure se ne pomeraju.** U režimu crtanja povuci figuru —
   ništa se ne sme odigrati.
6. [ ] **Oznake stoje na potezu na kome si ih nacrtao.** Nacrtaj strelicu na
   trećem taktu, prošetaj napred-nazad po hronologiji — strelica se vidi samo na
   tom taktu.
7. [ ] **Polunacrtana strelica ne preskače na drugu poziciju.** Klikni prvo
   polje, pa **promeni takt** u „Toku", pa klikni drugo polje — ne sme da se
   pojavi nikakva strelica. Crtanje ostaje uključeno.
8. [ ] **Oznake na polaznoj poziciji.** Napravi deo bez ijednog poteza, nacrtaj
   na njemu polje i strelicu, sačuvaj, otvori ponovo — sve je tu. („Pogledaj
   polje d5" je ceo deo lekcije.)
9. [ ] **Dete to vidi.** Otvori isti tutorijal kao učenik i proveri da su
   strelice i polja na tabli, na istim potezima.
10. [ ] **Boje.** Krugovi imaju slova (C, N, Z, P, Lj) i izabrani ima prsten —
    proveri da razlikuješ izabranu boju **bez** oslanjanja na samu boju.

## 118. Crtanje u sobi posle selidbe na kontroler — 7.9.2026, nije viđeno uživo

P7b. Ovo nije nova funkcija nego prepravka postojeće, pa je provera kratka i
gađa **tačno ono što testovi ne mogu da vide**: emitovanje i snimanje. Dvanaest
testova pokriva ponašanje na tabli; `_publishArrows` upisuje u `timeline_json` i
šalje preko socket-a, a to nijedan test ne dohvata.

1. [ ] **Dete vidi strelicu.** Uđi u sobu sa druge mašine (ili drugog naloga)
   kao učenik. Trener nacrta strelicu — **pojavi se i kod deteta**, iste boje.
2. [ ] **Brisanje stigne do deteta.** Trener pritisne „Poništi strelicu" pa
   „Izbriši sve strelice" — kod deteta nestaju.
3. [ ] **Snimak.** Snimi kratak čas u kome nacrtaš strelicu, pa pusti reprodukciju
   — strelica se pojavljuje u trenutku u kom je nacrtana.
4. [ ] **Prazan „Izbriši sve" ne pravi takt.** Pritisni „Izbriši sve strelice"
   na potezu bez ijedne strelice, pa pogledaj reprodukciju — **ne sme** da
   postoji prazan trenutak na tom mestu. (To je jedina namerna promena
   ponašanja u P7b.)
5. [ ] **Boja i poništavanje.** Nacrtaj zelenu pa crvenu strelicu, „Poništi
   strelicu" skida crvenu; nacrtaj zelenu i sa izabranom crvenom klikni ista dva
   polja — zelena nestaje (brisanje ne gleda boju).
6. [ ] **Crtanje i potezi.** Uključi crtanje, klikni jedno polje, pa odigraj
   potez — polunacrtana strelica se zaboravlja, a crtanje ostaje uključeno.

## 119. Odbrane studija i gašenje starog editora — 7.9.2026, nije viđeno uživo

P8. Poslednja tačka `PLAN-STUDIO-REDIZAJN`-a. Ide uz 113–118, isti prolaz.

1. [ ] **Pitanje sa linijom se ne čuva, i kaže se koji deo.** Napravi deo sa
   nekoliko poteza, prebaci ga na „Traži potez na tabli" — pojavi se pitanje
   „Dete bi videlo odgovor". Izaberi „Odustani": tip ostaje „Samo prikaži" i
   linija je netaknuta.
2. [ ] **„Ukloni liniju i postavi pitanje"** briše poteze, ostavlja polaznu
   poziciju, komentar i nacrtane oznake na njoj.
3. [ ] **Pitanje sa strelicom se čuva.** Napravi deo bez poteza, napiši
   „Nađi najbolji potez", nacrtaj strelicu, postavi „Traži potez na tabli" i
   sačuvaj — **mora da prođe.** (Do 7.9.2026 je bilo odbijeno, jer se deo
   procenjivao po izvezenom tekstu, a ne po tome ima li poteza.)
4. [ ] **Stari tutorijal koji curi kaže to na otvaranju.** Otvori tutorijal koji
   ima `ask_move` deo sa linijom — gore stoji crvena traka koja imenuje taj deo.
5. [ ] **Ponuđeni odgovori.** Jedan odgovor se odbija, pet se odbija, dva bez
   ijednog tačnog se odbija, dva sa jednim tačnim prolazi.
6. [ ] **„Pregledaj kao učenik"** otvara tutorijal onako kako ga dete vidi, i
   **ništa ne šalje na server** — odgovori u pregledu ne upisuju pokušaj.
7. [ ] **„Uredi" na Windows-u otvara studio**, a ne stari editor koraka. Na
   Android telefonu isti tutorijal se i dalje uređuje starim editorom.


## 120. „PGN" tab u studiju — 7.9.2026, nije viđeno uživo

T1 i T2 iz `docs/PLAN-PGN-TEKST.md`. Ovo je i jedini put kojim anotirana linija
spolja može da uđe u tutorijal, pa tačka 6 nije kozmetika nego cela poenta.

1. [ ] **Tab pokazuje deo.** Otvori deo sa nekoliko poteza i komentarom: u tabu
   „PGN" stoji tekst sa tim potezima i komentarom u vitičastim zagradama.
2. [ ] **Legenda.** Iznad polja piše šta su `[%cal]` i `[%csl]` i koje slovo je
   koja boja — proveri da ih ima **pet**.
3. [ ] **Kucanje ništa ne menja dok ne pritisneš „Primeni".** Ukucaj drugu
   liniju, pređi na „Tok" — stara linija je i dalje tamo; vrati se na „PGN" —
   tvoj tekst je i dalje tu, i piše „izmenjeno".
4. [ ] **Primeni.** Pritisni „Primeni": „Tok" i tabla pokazuju novu liniju, a
   oznaka pređe na „primenjeno".
5. [ ] **Odbijanje.** Ukucaj liniju sa potezom koji se ne može odigrati —
   poruka kaže **koliko** poteza, i deo ostaje nepromenjen.
6. [ ] **Nalepi pravu partiju.** Uzmi anotiranu partiju sa komentarima i
   `[%cal]`/`[%csl]` (Lichess, knjiga, ili izlaz iz `D:\chess books`), nalepi
   je u deo koji počinje iz iste pozicije i primeni — **komentari, strelice i
   varijante moraju da prežive**. Pa je pogledaj kroz „Pregledaj kao učenik".
7. [ ] **Crtanje i tekst se slažu.** Nacrtaj strelicu po tabli pa pogledaj tab
   „PGN": u tekstu stoji `[%cal ...]` na tom potezu.
8. [ ] **Deo bez poteza.** Deo koji ima samo komentar prikazuje se u tabu kao
   zaglavlje i `{ … }` — i primena takvog teksta ga ne prazni.
9. [ ] **Karet bira potez.** Klikni mišem unutar nekog poteza u tekstu — tabla
   ode na tu poziciju, a u „Toku" se tekući takt preseli na taj potez.
10. [ ] **I obrnuto.** Klikni karticu u „Toku" pa se vrati na „PGN" — karet
    stoji na tom potezu (potez je označen).
11. [ ] **Desni klik.** Desni klik unutar poteza daje tri stavke: „Dodaj
    strelicu", „Označi polje", „Dodaj komentar". U praznini između poteza ih
    nema, kao ni dok tekst piše „izmenjeno".
12. [ ] **Strelica iz menija.** „Dodaj strelicu" postavi kursor na taj potez i
    uključi crtanje — nacrtaj je na tabli i proveri da je u tekstu `[%cal ...]`
    baš na tom potezu.
13. [ ] **Komentar iz menija.** „Dodaj komentar" otvara polje sa postojećim
    tekstom tog poteza; „Odustani" ne menja ništa.
14. [ ] **Nalepljena partija iz druge pozicije.** Nalepi PGN koji nosi svoj
    `[FEN]` različit od pozicije dela — pojavi se pitanje. „Uzmi tu poziciju"
    prebaci deo na nju i linija se odigra; „Zadrži postojeću" odbije tekst uz
    poruku; „Odustani" ne uradi ništa i **ne** javlja grešku.
15. [ ] **Isti položaj, drugi satovi.** PGN čiji se `[FEN]` razlikuje samo po
    brojačima ne sme ništa da pita.

## 121. Tri popravke iz žive provere — 7.9.2026, nije viđeno uživo

Prve dve su iz prijava od 7.9.2026, treća je iz beleške uz stavku 117/7.
Prva se vidi samo ako se zvezdica na kraju linije **ne** odvoji razmakom —
tako je i prijavljena, i tako je i pukla.

1. [ ] **Zvezdica zalepljena za poslednji potez.** U tab „PGN" ukucaj liniju
   koja se završava sa `... exd5 Nxb4*` — bez razmaka ispred zvezdice — i
   pritisni „Primeni". **Primeni se**, i poslednji potez je u „Toku".
   Ranije je javljalo „1 potez ne može da se odigra" za sasvim legalnu liniju.
2. [ ] **Isto sa razmakom** (`Nxb4 *`) i dalje radi, kao i `1-0`.
3. [ ] **Crtanje se gasi kad promeniš takt.** Uključi „Strelica", pa klikni
   drugi takt u „Toku": dugme više nije upaljeno, i klik po tabli ne crta.
4. [ ] **Orijentacija table stiže do deteta.** U studiju okreni tablu na delu
   („Okreni tablu" ispod table), sačuvaj, pa otvori „Pregledaj kao učenik" —
   tabla stoji onako kako si je ostavio. Isto i kroz pravi zadatak kod deteta.
5. [ ] **Svaki deo pamti svoju.** Okreni tablu na prvom delu, izaberi drugi
   deo (koji nije okrenut), pa se vrati na prvi — prvi je i dalje okrenut, a
   drugi nije. Sačuvaj, izađi, otvori ponovo: isto.
6. [ ] **Stari tutorijal se ne prevrće.** Otvori tutorijal napravljen pre ove
   izmene koji ima deo sa pozicijom u kojoj je crni na potezu, sačuvaj ga bez
   ijedne izmene, pa ga pogledaj kao učenik — tabla stoji **isto kao pre**
   (okrenuta ka crnom). Ovo je tačka koju treba gledati u oči: greška bi bila
   tiha i videla bi se tek kod deteta.

## 122. Tri akcije umesto „dodaj deo" — 7.9.2026, nije viđeno uživo

Korisnikov predlog od 7.9.2026: sakriti reč „Deo" i ponuditi tri didaktičke
akcije. Dva dugmeta ne dodaju ništa — ona **preseku** deo koji pišeš na taktu na
kome stojiš, jer korak koji nosi liniju pokazuje detetu odgovor.

1. [ ] **Tri dugmeta.** U panelu piše „Sadržaj tutorijala", a ne „Delovi
   tutorijala", i stoje tri dugmeta: „Novi prikaz", „Traži potez na tabli",
   „Traži odgovor iz liste". Nema više „+ Dodaj deo".
2. [ ] **Presecanje.** Odigraj `1. e4 e5 2. Nf3 Nc6 3. Bb5`, vrati se na
   poziciju posle `2. Nf3` i pritisni „Traži potez na tabli". Dobiješ **tri**
   dela: prikaz do `2. Nf3`, pitanje na toj poziciji (bez poteza, sa tačnim
   potezom `Nc6`), i prikaz koji nastavlja sa `Nc6 3. Bb5`. Sva tri imaju
   ikonicu lanca — nadovezuju se.
3. [ ] **Ostaješ na pitanju.** Posle presecanja si u delu koji pita, sa poljem
   „Zadatak za učenika" pred sobom.
4. [ ] **Kod deteta je jedna tabla.** „Pregledaj kao učenik": demonstracija,
   pitanje na istoj poziciji **bez ponovnog postavljanja figura**, pa
   nastavak. Ovo je cela poenta — ako tabla trepne, javi.
5. [ ] **Grana se ne gubi.** Uradi isto na delu koji ima sporednu liniju posle
   poteza koji pitaš — sporedna linija mora da bude u trećem delu.
6. [ ] **Pitanje na sporednoj liniji.** Stani na potez iz sporedne linije pa
   pitaj: prvi deo mora da **vodi do te pozicije** (ta linija postaje glavna),
   a ne do stare glavne.
7. [ ] **Prazan deo.** Na delu bez ijednog poteza „Traži potez na tabli" ne
   pravi nove delove — deo prosto postane pitanje.
8. [ ] **Nazivi.** Deo se u spisku zove po prvoj rečenici koju nosi (ili po
   zadatku, ako pita). Bez ijedne reči — „Deo 1".
9. [ ] **Preimenuj.** Olovka otvara „Naziv"; upisano ime pobeđuje sve. Isprazni
   polje pa sačuvaj — vraća se naziv po rečenici.
10. [ ] **Ime stiže do deteta.** Isti naziv koji vidiš u spisku mora da stoji i
    kad tutorijal otvoriš kao učenik.
11. [ ] **„Novi prikaz"** pita „Odakle počinje?" — „Odavde" nastavlja tamo gde
    je stala linija (ikonica lanca), „Nova tabla" počinje iz početne pozicije.
12. [ ] **Uzak prozor.** Suzi prozor studija na oko 840 dp: panel sa sadržajem
    ne sme da preliva (u release buildu se preliv ne vidi, samo se dugmad ne
    mogu pritisnuti).

## 123. Račva se vidi kod deteta — 7.9.2026, nije viđeno uživo

Iz žive provere stavke 122: „ne prikazuje se druga grana, samo jedna". Grana je
sve vreme bila u koraku — deo koji nastavlja posle pitanja **počinje** račvom,
jer su odgovor i njegove alternative prva stvar u njemu — ali se do nje dolazilo
samo pritiskom na strelicu „Sledeći potez", koja otvara list. Ništa na ekranu
nije govorilo da ima šta da se bira, a šetnja sa glasom staje na račvi bez reči:
dete koje sluša nikad nije srelo drugu liniju.

List ostaje (to rade traka i strelice na tastaturi na svakom ekranu); ista
rečenica se sada piše i tu gde dete već gleda.

1. [ ] **Oba poteza stoje na ekranu.** Otvori kao učenik tutorijal čiji korak
   ima sporednu liniju: ispod komentara piše „Odavde ide više linija — kojom?"
   i stoje dva čipa sa potezima.
2. [ ] **Presečen tutorijal.** Uradi „Traži potez na tabli" na poziciji iz koje
   ide više odgovora, pa „Pregledaj kao učenik": treći deo se **otvara** sa oba
   poteza na ekranu.
3. [ ] **Klik vodi u tu liniju.** Pritisni čip sporedne linije — tabla i
   komentar su te grane, i čipova više nema jedan potez niže.
4. [ ] **Bez račve nema pitanja.** Korak sa jednom linijom nema ni rečenicu ni
   čipove — to je pravilo iz serije 52 i ono se ne sme izgubiti.
5. [ ] **Glavna linija se poznaje po obliku.** Prvi čip nosi zvezdicu, ostali
   strelicu — razlika ne sme da zavisi od boje.
6. [ ] **Traka i dalje pita.** Strelica „Sledeći potez" na račvi i dalje otvara
   list sa istim potezima.

## 124. Potez se briše iz stabla i iz „Toka" — 7.9.2026, nije viđeno uživo

Iz žive provere 7.9.2026: „ne mogu da se brišu potezi (ili ne vidim kako)", pa
zatim „može iz pgn prikaza … ali ne iz stabla ili toka". Meni na čvoru stabla
je sve vreme postojao — dugi pritisak ili desni klik otvara „Unapredi u Glavnu
Liniju" i „Obriši Ovu Varijantu" — ali studio za tutorijal nije prosleđivao
nijednu od te dve akcije, pa se list otvarao, dugme se pritiskalo i **ništa se
nije dešavalo**. To je stara greška ove baze u obliku u kome je korisnik sreće.

1. [ ] **Iz „Toka".** Svaka kartica koja jeste potez ima dugme sa gumicom
   (`Obriši ovaj potez`) u zaglavlju. Kartica „Polazna pozicija" ga **nema** —
   to nije potez, i za nju postoji „Obriši deo".
2. [ ] **Go potez ne pita.** Odigraj tri poteza i obriši poslednji — nestaje
   odmah, bez pitanja.
3. [ ] **Potez sa napisanim ne ide bez pitanja.** Napiši rečenicu na potez (ili
   nacrtaj strelicu, ili igraj dalje od njega) pa ga obriši — pita „Obriši
   potez?" i imenuje ga. „Odustani" ne menja ništa.
4. [ ] **Tabla ne ostaje na obrisanoj poziciji.** Stani na potez, pa obriši
   potez **iznad** njega — tabla i „Tok" se vrate na potez pre obrisanog.
5. [ ] **Iz stabla.** U tabu „Stablo" desni klik (ili dugi pritisak) na potez
   daje isti izbor, i „Obriši Ovu Varijantu" sada zaista briše.
6. [ ] **Glavna linija se bira.** Napravi sporednu liniju, desni klik na njen
   prvi potez, „Unapredi u Glavnu Liniju" — od tada „Tok" ide tom granom i
   dete se vodi njome.
7. [ ] **Nigde više mrtvog menija.** Ako neki ekran ne nudi te akcije, meni se
   ne otvara prazan — ne sme da postoji dugme koje ne radi ništa.
8. [ ] **Sačuvaj pa otvori ponovo** — obrisani potez se nije vratio.

## 125. Dve popravke iz žive provere — 7.9.2026, nije viđeno uživo

Obe su iz stavke 121, gde su zapisane kao „dobro je, ali…".

1. [ ] **Posle „Primeni" stojiš na poslednjem potezu.** U tabu „PGN" dopiši
   potez na kraj linije i pritisni „Primeni" — u „Toku" je tekuća **poslednja**
   kartica, a tabla je na toj poziciji. Ranije te je vraćalo na polaznu.
2. [ ] **Novi deo počinje kako si ostavio tablu.** Okreni tablu, pa „Novi
   prikaz" → „Odavde": novi deo je okrenut isto. To je cela poenta nastavka —
   dete prelazi spoj bez ponovnog postavljanja figura, pa tabla ne sme da se
   prevrne baš tu.
3. [ ] **Isto i za „Nova tabla".** Ko piše iz ugla crnog, piše iz ugla crnog i
   na sledećem dijagramu.
4. [ ] **Stari deo se ne dira.** Otvori sačuvan tutorijal sa delom koji je
   okrenut i delom koji nije, sačuvaj bez izmena — obe orijentacije su ostale
   kakve su bile.

## 126. Sačuvani tutorijali: obriši i pošalji — 7.9.2026, nije viđeno uživo

Iz žive provere 7.9.2026: „ne postoji mogućnost brisanja tutorijala" i
„tutorijal ne može da se pošalje đaku". Oboje je bilo tačno za korisnika, a
server je sve vreme imao i `DELETE /lessons/:id` i `POST /assignments/lesson` —
aplikacija ih je zvala sa dva ekrana na koja onaj ko piše tutorijal nema zašto
da svrati (spisak lekcija u sobi, i „Napredak učenika"). **Mogućnost koja
postoji na svakom sloju, a ne može se dohvatiti odande gde korisnik ide, je
mogućnost koju korisnik nema.**

Dugme na kartici se sada zove **„Sačuvani tutorijali"**, ne „Otvori sačuvani
tutorijal" — ko traži brisanje ne otvara vrata na kojima piše „otvori".

1. [ ] **Spisak.** Biblioteka → „Sačuvani tutorijali": svaki red ima naziv i
   dve ikonice — avionče („Pošalji učeniku") i kantu („Obriši tutorijal").
2. [ ] **Otvaranje je i dalje tu.** Klik na naziv otvara tutorijal u studiju,
   kao i pre.
3. [ ] **Brisanje pita i imenuje.** Kanta pita „Obriši tutorijal?" i u pitanju
   stoji naziv; „Odustani" ne briše ništa.
4. [ ] **Posle brisanja spisak ostaje otvoren**, bez obrisanog reda, pa možeš
   da obrišeš i drugi.
5. [ ] **Obrisan je stvarno obrisan.** Zatvori pa opet otvori spisak — nema ga.
6. [ ] **Slanje.** Avionče nudi spisak tvojih učenika; u njemu su **samo oni
   koji su prihvatili poziv**. Izaberi jednog — poruka kaže da je poslato.
7. [ ] **Kod deteta.** Uloguj se kao taj učenik: tutorijal stoji u zadacima i
   otvara se.
8. [ ] **Bez učenika.** Nalog bez ijednog prihvaćenog učenika dobija rečenicu,
   a ne prazan spisak.

## 127. Play pušta ceo tutorijal — 7.9.2026, nije viđeno uživo

Iz žive provere 7.9.2026: „zavaralo me play dugme, mislio sam da pušta ceo
tutorijal kroz sve delove". Šetnja sa glasom je stajala na kraju dela koji ne
stoji na istoj poziciji kao sledeći — po pravilu da je spoj nastavak, a nov
dijagram stranica koju dete okreće samo. Trener je to pročitao kao da se drugi
deo uopšte ne prikazuje, i bio je u pravu u onome što je važno: dugme sa ▶
obećava ceo tutorijal, a dete zbog kog ta šetnja postoji je baš ono koje sluša
umesto da pritiska.

1. [ ] **Dugme kaže šta radi.** Ispod table piše „Pusti tutorijal", ne
   „Pročitaj mi liniju".
2. [ ] **Dva prikaza su jedna šetnja.** Tutorijal sa dva „prikaži" dela, drugi
   iz svoje pozicije: pritisni play jednom — pročita prvi deo, pa **sam pređe**
   u drugi i pročita i njega.
3. [ ] **Tabla se ne postavlja ispod rečenice.** Na prelazu u deo koji počinje
   drugde sačeka se kratko pre nego što se figure prerasporede.
4. [ ] **Pitanje i dalje zaustavlja.** Deo koji nešto pita: pitanje se pročita
   i šetnja stane, da dete odgovori.
5. [ ] **Račva i dalje zaustavlja.** Na račvi šetnja stane i čipovi sa oba
   poteza stoje na ekranu (stavka 123).
6. [ ] **Kraj je kraj.** Na poslednjem delu šetnja stane i dugme se vrati na ▶.
7. [ ] **Stop radi u svakom trenutku**, i posle prelaska u sledeći deo.

## 128. Nalepljen PGN bez svoje pozicije — 8.9.2026, nije viđeno uživo

Iz stavke 120.15 („samo mi ovo javi"): tekst bez `[FEN]` ne govori odakle
počinje, pa nije imalo šta da se pita — trener je dobijao samo broj poteza koji
ne mogu da se odigraju. Ali partija bez zaglavlja je partija iz **početne
pozicije**, pa kad se tekst čisto odigra odatle a ne odavde, isto pitanje se
može postaviti, i sada je zasnovano na čitanju a ne na pogađanju.

1. [ ] **Pita kad ima šta da ponudi.** Otvori deo koji stoji na nekoj
   završnici, nalepi u tab „PGN" običnu partiju od `1. e4` (bez `[FEN]`) i
   pritisni „Primeni" — pojavi se „Tekst ne počinje odavde".
2. [ ] **„Uzmi početnu poziciju"** prebaci deo na početnu poziciju i linija se
   odigra cela.
3. [ ] **„Zadrži postojeću"** odbije tekst, i poruka kaže **da tekst nema svoju
   polaznu poziciju** — to je rečenica koja je nedostajala.
4. [ ] **„Odustani"** ne menja ništa i **ne** javlja grešku; tvoj tekst ostaje
   u polju.
5. [ ] **Tekst koji ne ide nigde.** Nalepi liniju koja se ne može odigrati ni
   odavde ni iz početne — nema pitanja, ali poruka i dalje kaže da tekst nema
   svoju polaznu poziciju.
6. [ ] **Ništa se ne pita kad nema zašto.** Fragment koji se uredno igra iz
   pozicije ovog dela (npr. dopisan potez na kraj linije) primenjuje se bez
   ijednog pitanja, kao i pre.

## 129. Tuđi tutorijali nisu na tvojoj polici — 8.9.2026, nije viđeno uživo

Iz žive provere 8.9.2026: „učenik vidi sve tutorijale trenera" i „ne može da
sačuva promene, ali može da menja". Provereno u kodu: **nije tako da su
tutorijali dostupni svim nalozima.** `GET /lessons` vraća tri stvari — tvoje,
one gde si ti trener, i sve što su sačuvali treneri koji su **tebe prihvatili**;
ta treća grupa je označena poljem `is_trainer_lesson`. Pisanje je zatvoreno na
sva tri puta (izmena, brisanje i kloniranje traže `user_id` ili `trainer_id`),
pa promena nikad nije mogla da se sačuva — što si i video.

Greška je bila da spisak „Sačuvani tutorijali" jedini nije gledao tu oznaku,
iako je soba deli u dve sekcije a „Dodeli lekciju" po njoj filtrira. Od
7.9.2026 je bilo i gore: na tuđem redu su stajale kanta i avionče koje taj
nalog nikad ne bi mogao da upotrebi.

1. [ ] **Kod učenika je polica prazna** (ili ima samo ono što je sam napisao).
   Uloguj se kao učenik na Windows-u, Biblioteka → „Sačuvani tutorijali":
   trenerovih tutorijala nema.
2. [ ] **Kod trenera je sve na svom mestu** — svi njegovi tutorijali, sa sve
   tri akcije.
3. [ ] **Zadaci se ne diraju.** Tutorijal koji je trener **poslao** učeniku i
   dalje stoji u zadacima i otvara se — to je drugi put i on ostaje.

**Ostaje odluka za tebe, nije popravljeno:** da li učenik uopšte treba da u
listi lekcija vidi sve što je trener ikad sačuvao (soba to prikazuje u sekciji
„od trenera"). To je smisao `acceptedTrainersOf` i dira zadatke i lekcije, pa
nije stvar za usput.

## 130. Jedan dijalog za postavljanje pozicije — 8.9.2026, nije viđeno uživo

Faza 1a iz `docs/PLAN-ZAVRSNICA.md`. Bila su dva dijaloga, i to dva fajla istog
imena: onaj iz sobe (samo slaganje figura, uvek se otvarao iz početne pozicije)
i onaj iz Analize (pet kartica). Ostao je drugi — jer jedini može da se otvori
**na poziciji koju gledaš** — a soba mu sada prosleđuje svoju tablu.

Uz to su ispravljene tri mrtve kartice: „PGN Uvoz", „Otvaranja" i
„Chess.com/Lichess" predaju rezultat kroz `onPgnLoaded`, a studio za tutorijal
ga namerno ne prosleđuje — pa se biranjem otvaranja prozor zatvarao i ništa se
nije dešavalo.

1. [ ] **Soba.** „Postavi poziciju (Board Setup)" otvara isti dijalog kao
   Analiza, i **na poziciji koja je na tabli**, ne iz početne.
2. [ ] **Studio za tutorijal.** Ikonica „Unos pozicije" daje **dve** kartice —
   „FEN String" i „Ručno Slaganje". Nema više „Otvaranja" ni uvoza.
3. [ ] **Analiza.** I dalje ima svih pet kartica i uvoz radi kao pre.
4. [ ] **Figure se vide.** U paleti crne figure stoje na svetlom polju —
   proveri da se raspoznaju **bez** oslanjanja na boju; izabrana figura ima i
   deblji okvir, ne samo drugu podlogu.
5. [ ] **Rokade se čitaju.** Piše „Beli O-O", „Beli O-O-O", „Crni O-O", „Crni
   O-O-O" umesto `K`, `Q`, `k`, `q`.
6. [ ] **Na uskom prozoru.** Suzi prozor (ili otvori na telefonu): kartica
   „Ručno Slaganje" se skroluje, i dugme „Generiši i Postavi Poziciju" se može
   pritisnuti. Na širokom se ne skroluje ništa.
7. [ ] **Tri načina brisanja polja** i dalje rade: klik na naoružanu figuru,
   dugi pritisak, desni klik.

## 131. Imena ekrana — 8.9.2026, nije viđeno uživo

Faza 1b iz `docs/PLAN-ZAVRSNICA.md`. Ekrani se ne spajaju; menjaju se imena,
jer su dva od njih na početnom ekranu **opisivala istu stvar** („Samostalni rad,
FEN postavljanje, PGN i Stockfish analiza" naspram „Slobodna šahovska tabla za
duboku analizu … rad sa PGN/FEN pozicijama"). Reč „studio" ostaje na jednom
mestu.

| bilo | sada |
|---|---|
| „Šahovski studio" | **„Priprema"** |
| „Tabla za Analizu" | **„Analiza"** |
| „Studio Kontrole" | „Kontrole pripreme" |
| „Studio Režim (Samostalan rad…)" | „Samostalan rad — učionica je isključena" |
| „Video Studio — Podešavanje Videa" | „Podešavanje videa" |

1. [ ] **Početni ekran.** Kartica „Priprema" piše „Vaše sačuvane pozicije i
   tutorijali, na tabli — bez učenika."; kartica „Analiza" piše „Motor, baza
   otvaranja i stablo varijanti…". Pročitaj obe i reci da li se sada vidi
   razlika.
2. [ ] **Biblioteka.** Dugmad su „Otvori Pripremu sa praznom tablom" i „Otvori
   Analizu".
3. [ ] **U samom ekranu.** Naslov sobe bez učenika je „Priprema"; desni panel
   piše „Kontrole pripreme"; prekidač piše „Samostalan rad — učionica je
   isključena".
4. [ ] **Analiza** se u zaglavlju zove „Analiza", a u podešavanjima piše
   „Paneli u Analizi:".
5. [ ] **Reč „studio"** se sreće još samo u „Studio za tutorijal".
6. [ ] **Ništa se nije prelomilo** — proveri da naslovi staju u zaglavlje i na
   užem prozoru.

## 132. Server govori engleski — 9.9.2026, nije viđeno uživo

Batch-evi 66a i 66b preveli su 71 fajl u `chess_backend/`. **Nijedna od tih
rečenica nije viđena na ekranu** — testovi ih porede sa nizovima, ne sa
prozorom, a aplikacija veliki deo njih crta doslovno (`res.json({ error })`).
Ovo je najveća količina neproverenog teksta u projektu.

Vredi znati unapred: **stari redovi u `user_notifications` ostaju srpski.**
Poruke upisane pre 8.9.2026 su podaci, ne kod; prevedeni generator menja samo
ono što se piše od sada. Isto važi za naslov domaćeg „Iz tvojih partija" i za
grešku zaustavljenog uvoza koja stoji u `user_game_imports`.

1. [ ] **Obaveštenja i pozivnice.** Napravi novu vezu trener–učenik i pogledaj
   šta piše u dijalogu: nova poruka mora biti engleska. Stare ostaju srpske i
   to je očekivano.
2. [ ] **Greške koje ekran crta doslovno.** Zadaj domaći bez izabranog učenika,
   otvori tuđu sobu, pošalji prazan PGN — poruka je engleska rečenica, ne
   „Instance of…" i ne prazan SnackBar.
3. [ ] **Zagonetke i skener.** Otvori PDF koji nije knjiga sa dijagramima:
   poruka mora reći **koja** od tri stvari nije u redu (nema teksta / nema
   dijagrama / nepoznat font), na engleskom.
4. [ ] **Završnice.** Katalog piše `rook and two pawns versus rook`, ne
   `rooks` u jednini i ne srpski. Prođi kroz nekoliko kategorija — imena
   familija su „Rook endgames", „Pawn endgames"…
5. [ ] **Roditeljski izveštaj.** Otvori link izveštaja: naslov, legenda, imena
   motiva („back-rank mate", „hanging piece") i „Coach's message" su engleski,
   a brojevi i procenti nepromenjeni.
6. [ ] **AI objašnjenje pozicije.** „Objasni poziciju" i AI komentar poteza sada
   **odgovaraju na engleskom** — parametar `userLanguage` je obrisan sa oba
   kraja. Ako se vrati srpski tekst, model ignoriše prompt i to je nalaz.
7. [ ] **Repertoar.** „Vežbaj" liniju do greške (npr. potez koji nije u
   repertoaru) — poruke su engleske i koriste reč **drill**, ne „practice".
8. [ ] **Priprema protiv protivnika.** Pusti pripremu sa Lichess-a: rečenica o
   protivniku je engleska, a **svaki procenat u njoj mora postojati u
   podacima** — `narrativeGuard` odbija izmišljen broj, pa ako se rečenica ne
   pojavi, pogledaj log servera pre nego što prijaviš da je pokvarena.

## 133. Tutorijal kao video — delimično provereno uživo 12.9.2026

Faza 2 `PLAN-ZAVRSNICA.md`. Renderovanje je dokazano na mašini vođe (dvodelni
tutorijal, strelice, obojena polja, rečenice i okrenuta tabla u drugom delu, 19
sekundi MP4-a), a do 12.9.2026 **niko nije bio pritisnuo dugme u aplikaciji** —
to se tog dana promenilo, vidi odeljak ispod.

Za ovo treba nalog kome je uključen `mp4_export` (plaćeno pravo) i pokrenut
lokalni backend sa `ffmpeg` u putanji.

**Prvi objavljen tutorijal, 12.9.2026.** Vlasnik je u studiju napisao „Master
the Rook and King Checkmate" — četiri dela, 37 taktova, sav sa bele strane —
izvezao ga na 1080p sa Azure glasom na engleskom, preuzeo fajl i objavio film na
YouTube. Fajl je `exports/tutorial_50_wood_1080p_….mp4`: 1920×1080, 30 fps,
2:50, 2,66 MB, ~125 kbps, glas 22 050 Hz mono (srednje −23,7 dB), nacrtan za
2 min 16 s (`tutorial_render_jobs` za lekciju 50 stoji na `done`). Kopija
tutorijala i sva merenja stoje u `D:/chess/tutorijal/reference/` — van
repozitorijuma, kao i ostali generisani tutorijali.

Time su dokazane stavke **3** (izvoz javi „Video ready!" sa linkom — na Windowsu;
telefon nije gledan), **4** (fajl se preuzima i pušta), **6** i **7** (na kadru
na 01:02 stoje slova a–h duž donje ivice i naslov bez prazne kutijice), **10**
(figure i tabla su iz aplikacije — koža nadjačava `boardTheme`, pa ime fajla i
dalje kaže „wood" iako polja nisu drvena) i **13** (1080p, provereno upravo na
YouTube uploadu; vidi „60 fps za YouTube — mereno i odbijeno" u
`docs/STANJE-RADA.md` za lestvicu koju YouTube od toga napravi).

Stavka **5** je dokazana do pola: rečenica se čita do kraja, a strelice i
obojena polja stoje na svom potezu — ali ovaj tutorijal nema deo pisan sa crne
strane, pa okrenuta tabla i dalje nije viđena. Sve ostalo u ovom odeljku — prazan
tutorijal, kvota, traka od 10 %, dva rendera u isto vreme, izvoz snimka časa —
nije gledano.

1. [ ] **Vrata.** „Sačuvani tutorijali" → svaki red ima tri ikonice: video,
   pošalji, obriši. Na telefonu (ne na Windows prozoru!) proveri da se sve tri
   vide i da se svaka može pogoditi prstom, i kod tutorijala sa dugim imenom.
2. [ ] **Prazan tutorijal** kaže „This tutorial has nothing to show yet." i
   **ne** šalje ništa serveru.
3. [x] **Običan tutorijal** javi „Exporting video…", pa posle nekoliko desetina
   sekundi otvori „Video ready!" sa linkom. Dijalog mora da stane na ekran
   telefona.
4. [x] **Fajl se otvara.** Dugme „Download" otvara sistemski pregledač i video
   se pušta.
5. [ ] **U videu:** rečenica ispod table je čitljiva do kraja; strelice i
   obojena polja stoje na potezu kome pripadaju; drugi deo tutorijala počinje
   **bez** osvetljenog poteza iz prvog; deo pisan sa crne strane je okrenut.
6. [x] **Slova kolona (a–h) se vide** duž donje ivice table. To je ispravka iz
   ove faze — do 9.9.2026 nijedno nije bilo nacrtano ni u jednom izvozu.
7. [x] **Naslov nema praznu kutijicu** ispred sebe.
8. [ ] **Izvoz snimka časa** (`Replay` → izvoz MP4) i dalje izgleda isto kao
   pre. Ovo je regresiona provera: film bez rečenica ne sme da promeni
   geometriju.
9. [ ] **Kvota.** Posle izvoza, „Moj nalog" prikazuje potrošenu MP4 kvotu; izvoz
   koji padne ne sme da je potroši.
10. [x] **Figure su iste kao u aplikaciji.** Uporedi kadar iz videa sa
    Studijom za tutorijal: isti oblici, ista tabla, ista tema. Do 9.9.2026 su
    na serveru živela tri kompleta („Alpha", „Staunton" i onaj iz aplikacije),
    a bojenje po koži je posezalo za pogrešnim — pa je video stizao u
    figurama koje trener nigde u aplikaciji nije video. Sada postoji jedan
    komplet i to je onaj iz aplikacije.
11. [ ] **Traka napretka se pomera u koracima od 10 %** i pored procenta piše
    procena („about 40 s left", „about 2 minutes left"). Procena pada kako
    render odmiče, a na kraju kaže „almost done" umesto da broji do nule.
12. [ ] **Izvoz snimka časa nema više izbor kompleta figura** — u dijalogu su
    sada četiri stavke (tabla, orijentacija, elementi, rezolucija), a video
    izlazi u figurama iz aplikacije.
13. [x] **Prekidač „Higher quality (1080p)"** stoji u dijalogu pre renderovanja
    (sada se taj dijalog otvara i kada server ne ume da govori). Isključen je
    podrazumevano, pamti se za sledeći put, a uključen daje vidno oštriji tekst
    — proveri na YouTube uploadu ili na projektoru.
14. [ ] **Server odgovara dok renderuje.** Dok traje izvoz, otvori bilo šta
    drugo u aplikaciji (spisak tutorijala, zadaci) — mora da radi. Do 9.9.2026
    je ceo proces stajao dok se film crta, pa se ni traka napretka nije
    pomerala.
15. [ ] **Video bez glasa to i kaže.** Ako je glas tražen a nije stigao (npr.
    piper nije instaliran), dijalog „Video ready!" nosi rečenicu „It has no
    narration: …". Do 9.9.2026 je takav izvoz izgledao kao svaki drugi.
16. [ ] **Dva renderovanja u isto vreme.** Pokreni izvoz na dva naloga (ili dva
    puta isti tutorijal) i proveri da oba stignu, da su **dva različita fajla**
    i da se oba otvaraju. Do 9.9.2026 su dva izvoza istog tutorijala u istoj
    milisekundi delila ime fajla. Drugi izvoz mora da kaže „Your video will
    start rendering shortly — one video ahead of it." dok čeka, pa da pređe na
    traku sa procentima kad dođe na red.
16a. [ ] **Četvrti izvoz se odbija.** Sa tri u redu (jedan crta, dva čekaju),
    četvrti dobija poruku „The server is rendering other videos right now. Try
    again in a minute or two." i **ne troši kvotu**.
17. [ ] **Potezi se izgovaraju, ne slovkaju.** Napiši u komentaru „Bd5", „O-O"
    i „Nxe5+" pa preslušaj: engleski glas kaže „bishop d five", nemački
    „Läufer d fünf", francuski „fou d cinq". Do 9.9.2026 je francuski čitao
    „Bd5" kao *boulevard cinq*, a „+" kao „plus". **Natpis na ekranu ostaje
    „Bd5"** — menja se samo ono što se izgovara.


## 134. Napušten render se prekida — 9.9.2026, nije viđeno uživo na dropletu

Do 9.9.2026 je render koji je klijent napustio nastavljao da crta do kraja i
**držao jedini slot** — mereno lokalno: klijent je odustao na 300 s, film od 36
minuta je dovršen, a MP4 od 14,4 MB je ostao u `exports/` sa linkom koji niko
nije dobio. Zbog toga su drugi treneri u tom prozoru čekali iza filma koji niko
neće pokupiti, ili dobijali 429. Rešenje je opisano u `docs/STANJE-RADA.md`,
odeljak „Render koji je klijent napustio se prekida".

Lokalno je provereno pravim socketom i pravim ffmpeg-om
(`mislisha-test/render-fixtures/abort-live-check.js`): prekid na 3,0 s, server
stao na 3,5 s, fajl obrisan, sledeći posao krenuo za 0,00 s. **Na dropletu vezu
zatvara nginx, a ne klijent, i to nije isto** — zato ova stavka.

1. [ ] **Zatvori aplikaciju usred izvoza.** Pokreni izvoz dugog tutorijala i
   ubij aplikaciju (ili isključi mrežu) dok traka stoji na pola. U logu servera
   mora da se pojavi `[RENDER] abandoned: client gone, drawing stopped, slot
   released`, i to **u roku od nekoliko sekundi**, ne na kraju filma.
2. [ ] **Nijedan fajl ne ostaje.** Posle toga u `chess_backend/exports/` ne sme
   da bude novog MP4 za taj tutorijal, ni polovičnog `.wav` iz naracije.
3. [ ] **Sledeći trener odmah dolazi na red.** Dok prvi izvoz još „traje", sa
   drugog naloga pokreni svoj — čim prvi klijent ode, drugi mora da krene, a ne
   da čeka do kraja napuštenog filma.
4. [ ] **Kvota nije potrošena.** Napušteni izvoz se **ne knjiži** — proveri da
   broj renderovanja na nalogu nije porastao.
5. [ ] **Nginx tajmaut, ne samo zatvoren laptop.** Isto ponovi tako što pustiš
   izvoz duži od 300 s na dropletu: vezu zatvara nginx, server mora da stane
   isto kao gore. Ovo je jedini deo koji lokalno ne može da se proveri.
6. [ ] **Naracija.** Sa instaliranim piperom prekini vezu **dok traje sinteza**
   (pre nego što traka krene) — piper proces mora da nestane. To je jedini deo
   prekida koji nije pokriven testom, nego samo konstrukcijom.

## 135. Pregled pre renderovanja — 9.9.2026, nije viđeno uživo

`renderFrameBuffer` crta jedan kadar bez ffmpeg-a, pa pregled ne troši mesto u
redu za renderovanje, ne piše fajl i ne knjiži kvotu. Dugme je u dijalogu za
izvoz, pored „Export".

1. [ ] **Tri kadra.** „Preview" na tutorijalu sa više delova daje tri slike —
   početak, sredina, kraj — kroz koje se prelazi strelicama.
2. [ ] **Rezolucija se poštuje.** Uključi „Higher quality (1080p)" pa pusti
   pregled: naslov kaže „Preview · 1080p", a tekst natpisa je vidno oštriji
   nego na 720p.
3. [ ] **Ništa nije renderovano.** Posle pregleda u `chess_backend/exports/`
   nema novog fajla, a broj renderovanja na nalogu nije porastao.
4. [ ] **Dijalog za izvoz ostaje.** Zatvaranje pregleda vraća trenera u isti
   dijalog, sa prekidačima kako ih je ostavio.
5. [ ] **Pregled odgovara i dok se nešto drugo renderuje.** Pusti dug izvoz sa
   drugog naloga, pa u toku njega traži pregled — mora da stigne odmah, jer
   pregled namerno **nije** u redu za renderovanje.
6. [ ] **Slika je ono što će film biti.** Uporedi kadar iz pregleda sa istim
   taktom u gotovom videu: ista tabla, iste strelice, ista rečenica, isti
   raspored.

## 136. Tutorijal pamti svoj film — 9.9.2026, nije viđeno uživo

Do 9.9.2026 se renderovani video nigde nije pamtio: link je živeo samo u
odgovoru na izvoz, a token mu traje trideset minuta. Sada `saved_lessons` nosi
ime fajla, a red u „Sačuvani tutorijali" dobija ikonicu za preuzimanje — **samo
ako film postoji**.

**Kolona je napisana, 12.9.2026.** Posle objavljenog izvoza
`saved_lessons.video_filename` za lekciju 50 nosi `tutorial_50_wood_1080p_….mp4`
(pročitano iz baze), pa je zapisivanje dokazano; ikonica na redu i svež link
nisu gledani.

1. [ ] **Izvezi pa zatvori dijalog.** Ne pritiskaj „Download". Zatvori spisak,
   otvori ga ponovo: na tom redu stoji ikonica za preuzimanje i daje isti film.
2. [ ] **Kasnije, ili sa drugog uređaja.** Isti nalog, drugi uređaj — dugme
   radi, jer se link kuje u trenutku kad se pita.
3. [ ] **Jedan film po tutorijalu.** Izvezi isti tutorijal drugi put pa
   pogledaj `chess_backend/exports/`: stari fajl više ne postoji, novi je tu.
   Do sada je svaki izvoz ostavljao svoj fajl.
4. [ ] **Red bez filma nema to dugme.** Tutorijal koji nikad nije izvezen ima
   samo kameru, „pošalji" i kantu.
5. [ ] **Film koji je zastareo.** (Pre četrnaest dana se izaziva ručnim
   brisanjem fajla iz `exports/`.) Poruka je „This video has been deleted to
   save space. Export it again", i dugme **nestaje** sa reda.
6. [ ] **Telefon od 360 dp.** Red sa filmom ima četiri ikonice i dug naslov —
   proveri na uskom telefonu da su sve dohvatljive.

## 137. Jedan trener ne zauzima ceo red — 9.9.2026, nije viđeno uživo

Do 9.9.2026 je jedan nalog sa tri izvoza punio red i svi ostali su dobijali 429.
Sada red ide **round-robin po nalogu**, a jedan nalog sme da ima najviše dva
filma (jedan se crta, jedan čeka).

1. [ ] **Tri izvoza sa istog naloga.** Treći mora da bude odbijen rečenicom
   „You already have a video rendering and another one waiting…" — a **ne**
   „The server is rendering other videos right now".
2. [ ] **Drugi nalog i dalje prolazi.** Dok prvi trener ima svoja dva, sa
   drugog naloga pusti izvoz: mora da uđe u red, ne da bude odbijen.
3. [ ] **Red poštuje smenu.** Trener A pusti izvoz pa odmah još jedan; trener B
   pusti svoj posle toga. Kad se prvi zavrsi, **B ide pre A-ovog drugog**.
4. [ ] **Broj u traci je tačan.** Onaj ko čeka vidi mesto koje se obistini —
   ako ga neko pretekne po pravilu smene, broj mu poraste, i to vidi.
5. [ ] **Kvota nije potrošena na odbijanje.** Posle odbijenog trećeg izvoza broj
   renderovanja na nalogu nije porastao.

## 138. Snimanje glasa preko tutorijala — 10.9.2026, nije viđeno uživo

Faze 1 i 2 iz `docs/PLAN-SNIMANJE.md`: trener priča preko tutorijala, razmak
pomera takt, a marker je **pozicija u samom zvuku** (bajtovi ÷ byte rate), ne
sat na zidu. Snimak ostaje na uređaju; slanje na server je faza 3 i nije
urađeno. Samo Windows — studio ne postoji na Androidu.

1. [ ] **Vrata.** U studiju, na **sačuvanom** tutorijalu, ikonica mikrofona
   pored „Export video" otvara ekran „Record narration". Na nesačuvanom kaže
   „Save the tutorial first, then record it." i ništa ne otvara.
2. [ ] **Snimanje.** „Record", pričaj, razmak za svaki sledeći takt. Tabla i
   rečenica prate; red „Next: …" tačno kaže šta će razmak postaviti.
3. [ ] **Pauza nema rupu.** Pauziraj pet sekundi, **pritisni razmak dok je
   pauzirano**, nastavi. Na preslušavanju takt se menja tačno tamo gde glas
   nastavlja, bez tišine od pet sekundi.
4. [ ] **Utišan mikrofon.** Utišaj mikrofon u Windowsu i pritisni „Record": za
   oko tri sekunde mora da se pojavi „Nothing is reaching the microphone".
   Uključi mikrofon — poruka nestaje. Snimak koji je ceo bio utišan posle „Stop"
   kaže da je nem.
5. [ ] **Kraj se ne razilazi.** Snimi ceo tutorijal od bar dva minuta sa jednom
   ili dve pauze, pa preslušaj **poslednja tri takta**: tabla se menja kad glas
   kaže, ne pola sekunde ili tri sekunde ranije. To je polovina koju niko ne
   proverava, i baš tu bi zidni sat pogrešio.
6. [ ] **Ponovno otvaranje.** Zatvori ekran i otvori ga opet: „Recorded … ·
   m:ss · N of M beats" i „Listen" radi.
7. [ ] **Novi pokušaj i odbacivanje.** „Record again" pa „Discard": stari snimak
   je i dalje tu. „Record again" pa „Stop": novi je zamenio stari.
8. [ ] **Izlazak usred snimanja.** Strelica nazad dok se snima pita „Discard this
   recording?"; „Discard and leave" izlazi i ništa ne ostaje.
9. [ ] **Držanje razmaka.** Drži razmak dve sekunde: pomera se **jedan** takt.
10. [ ] **Izmenjen tutorijal.** Posle snimka dodaj potez u studiju i otvori ekran:
    mora da kaže „This recording was made when the tutorial had N beats…".
11. [ ] **Fajl.** U direktorijumu podrške aplikacije
    (`getApplicationSupportDirectory`), podfolder `narration\lesson_<id>`, stoji
    jedan `take-….wav` i `take.json`. Wav se otvara u običnom plejeru, a
    `ffprobe` daje isto trajanje koje piše na ekranu.

## 139. Video u trenerovom glasu — 10.9.2026, nije viđeno uživo

Faze 3 i 4 iz `docs/PLAN-SNIMANJE.md`: snimak odlazi na server pri izvozu, i
film se crta po markerima snimka umesto po procenjenoj brzini čitanja. Pretpostavlja
stavku 138 (snimak postoji na uređaju).

1. [ ] **Pitanje.** Posle celog snimka, „Export video" u studiju ili u „Sačuvani
   tutorijali": pod „Narration" je **izabrano** „My recording (m:ss)". (Do faze 6
   ovo je bio prekidač „Use my recording"; vidi stavku 141.)
2. [ ] **Prvi izvoz.** Pojavi se „Uploading your recording", pa traka
   renderovanja. Film ima tvoj glas, a tabla se menja tamo gde si pritiskao
   razmak — proveri početak, sredinu i **poslednja tri takta**.
3. [ ] **Drugi izvoz bez novog snimka.** Nema „Uploading" — server već ima baš
   taj snimak.
4. [ ] **Novi snimak, pa izvoz.** „Uploading" se opet pojavi, i film ima novi
   glas.
5. [ ] **Drugi odgovor.** Izaberi „No voice", ili „Synthesised voice" ako server
   ima piper: film ide bez tvog glasa — tih, odnosno sintetizovan — a **nikad sa
   oba**.
6. [ ] **Izmenjen tutorijal.** Dodaj potez, pa „Export video": umesto odgovora
   „My recording" stoji „Your recording was made when the tutorial had N beats…".
7. [ ] **Brisanje.** Obriši tutorijal iz biblioteke: fajl u
   `chess_backend/uploads/narration/` nestaje.
8. [ ] **Nije javno.** `…/uploads/narration/<ime>.wav` u pregledaču daje 404.
9. [ ] **Petnaest minuta.** Snimanje blizu granice samo stane na 14:59 i kaže
   zašto; izvoz tog snimka prolazi.

Poznato i otvoreno: brisanje tutorijala **ne briše snimak na uređaju**, samo na
serveru.

## 140. Snimak zna kojim taktovima pripada — 10.9.2026, nije viđeno uživo

Faza 5 iz `docs/PLAN-SNIMANJE.md`. Broj taktova vidi dodat i obrisan takt, ali ne
vidi **prepravljenu rečenicu** — a marker imenuje takt po redu, pa posle takve
izmene film ima pravu sliku i pogrešan glas, negde od sredine. Sada svaki snimak
nosi potpis liste taktova nad kojom je napravljen. Pretpostavlja stavke 138 i 139.

1. [ ] **Prepravljena rečenica.** Snimi ceo tutorijal, pa u studiju **izmeni
   jednu rečenicu** i ne diraj ništa drugo. Odmah, bez zatvaranja ekrana, iznad
   spiska delova stoji traka „This tutorial has been edited since your recording
   was made…" sa dva dugmeta.
2. [ ] **Broj taktova je isti.** Na ekranu za snimanje piše i dalje „N of N
   beats" — dakle brojanje ne bi ništa primetilo — a ispod stoji „The tutorial
   has been edited since this was recorded".
3. [ ] **„Record again".** Dugme iz trake otvara ekran za snimanje. Snimi ponovo
   do kraja i vrati se: **traka je nestala**.
4. [ ] **„Export without your voice".** Iz trake otvara dijalog za izvoz; umesto
   odgovora „My recording" stoji rečenica o izmeni, a biraju se „Synthesised
   voice" ili „No voice". Film se napravi sintetizovan ili tih.
5. [ ] **Preimenovanje ništa ne košta.** Preimenuj **tutorijal** i preimenuj
   **deo**: traka se ne pojavljuje, izvoz i dalje bira „My recording". Ovo je
   pola faze — sat vremena snimanja ne sme da propadne zbog naslova.
6. [ ] **Strelica i krug ništa ne koštaju.** Nacrtaj strelicu i oboj polje na
   nekom taktu: traka se ne pojavljuje, izvoz i dalje nudi snimak.
7. [ ] **Stariji snimak.** Snimak napravljen pre ove verzije (nema potpis) sudi
   se po broju taktova kao i ranije — ne sme da bude odbijen na pravom
   tutorijalu.
8. [ ] **Server ne pušta.** Ako se izmena nekako provuče do izvoza, server
   odgovara 409 sa rečenicom o izmeni i **ne troši slot za renderovanje**.

## 141. Jedno pitanje za zvuk filma — 10.9.2026, nije viđeno uživo

Faza 6 iz `docs/PLAN-SNIMANJE.md`. Dva prekidača („Use my recording" i „Narrate
this video") postala su jedno pitanje „Narration" sa tri odgovora: „My recording
(m:ss)", „Synthesised voice" i „No voice". Pretpostavlja stavke 138 i 139.

1. [ ] **Sva tri.** Tutorijal sa snimkom, server sa piperom: pod „Narration" su
   tri odgovora, izabran je „My recording", i nema liste glasova.
2. [ ] **„Synthesised voice".** Izaberi ga: pojavi se lista glasova i „A narrated
   export takes longer." Film ima sintetizovan glas i ništa tvoje.
3. [ ] **„No voice" je tih film** i kad server ima piper — ranije je isključen
   snimak na takvom serveru značio sintetizovan glas.
4. [ ] **Pamti se ono što nije snimak.** Izvezi jednom sa „Synthesised voice",
   pa jednom sa snimkom, pa izmeni jednu rečenicu (snimak više ne važi) i otvori
   izvoz: izabran je „Synthesised voice", a ne „No voice".
5. [ ] **Nema pitanja sa jednim odgovorom.** Bez snimka i bez pipera nema
   „Narration" uopšte — samo 1080p. Sa nevažećim snimkom i bez pipera stoji
   samo rečenica zašto snimak ne važi.
6. [ ] **Nizak prozor.** Tutorijali postoje samo na Windowsu (stavka 136, korak
   6), pa telefon ovde ne dolazi u obzir: smanji **visinu** Windows prozora dok
   dijalog ne prestane da staje, pa sa sva tri odgovora i izabranim „Synthesised
   voice" skroluj do „Higher quality (1080p)" i uključi ga; film je 1080p.
   Izmereno u testu: bez skrolovanja je dijalog 49 px viši od 360 × 640, i
   prekidač bi stajao ispod dugmadi.

## 142. Render koji ne može da stane se odbija pre crtanja — 10.9.2026, nije viđeno uživo

Tačka 4 drugog dela `docs/PLAN-SNIMANJE.md`. Server sada pre crtanja računa
koliko bi film trajao i odbija ga **odmah**, sa rečenicom, umesto da crta dok
veza posle 300 s ne pukne. Tutorijali za proveru su u
`mislisha-test/render-fixtures` (README tamo ima i PowerShell skripte).

1. [ ] **Predug tutorijal.** Izvezi `big-40-parts` (36 minuta) na 720p: odgovor
   stiže za sekundu, i kaže koliko bi renderovanje trajalo, koliko server može u
   jednom komadu, i „Split the tutorial into … shorter ones". U `exports/` nema
   novog fajla i broj renderovanja na nalogu nije porastao.
2. [ ] **1080p.** `medium-12-parts` (10,5 minuta) na 1080p: odbijen, a rečenica
   nudi „export it at 720p". Isti na 720p prolazi.
3. [ ] **Snimak.** Tutorijal sa snimkom od desetak minuta, izvezen na 1080p:
   odbijen, i nudi 720p — a „without your recording" samo ako bi film bez
   snimka stao.
4. [ ] **Red bez vremena.** Pusti `medium-12-parts` sa jednog naloga, pa odmah
   sa drugog naloga još jedan `medium-12-parts`: drugi dobija „Try again in about
   N minutes", **ne** „The server is rendering other videos right now".
5. [ ] **Kratak i dalje ulazi.** Dok se `medium-12-parts` renderuje, pusti
   `concurrent-a` (2 minuta) sa drugog naloga: ulazi u red i završi se.
6. [ ] **Droplet: izmeri brzinu.** Na dropletu izrenderuj `medium-12-parts`
   jednom na 720p i jednom na 1080p, podeli 2528 frejmova sa sekundama
   renderovanja, uzmi sporije merenje sa marginom i upiši ga u `.env` kao
   `RENDER_DRAW_FPS_720P` i `RENDER_DRAW_FPS_1080P`. Dok se to ne uradi,
   podrazumevane vrednosti (12 i 6) su procena o drugoj mašini.

Posle tačke 5 (stavka 143) ova stavka se menja na tri mesta:

* **Plafon je 600 s crtanja po filmu** (`RENDER_MAX_DRAW_SECONDS`, odluka
  vlasnika 10.9.2026), ne 300. Korak 1 važi i dalje — `big-40-parts` (36 min) na
  720p je oko 720 s crtanja, pa je odbijen. Koraci 2 i 3 **ne važe kako su
  napisani**: `medium-12-parts` na 1080p je oko 420 s i sada prolazi, a isto i
  desetominutni snimak na 1080p. Za njih treba tutorijal od dvadesetak minuta
  na 1080p (oko 800 s, odbijen; na 720p oko 400 s, prolazi).
* **Koraci 4 i 5 ne važe za tutorijal**: nijedna veza ne čeka njegov film, pa
  „Try again in about N minutes" tutorijal više ne dobija — film iza dugačkog
  samo čeka svoj red. Tu rečenicu sada dobija samo izvoz snimljenog časa (korak
  10 stavke 143).
* Snimak glasa sme da traje do 30 minuta (izvedeno iz plafona), ne 15.

## 143. Render izlazi iz zahteva — 10.9.2026, nije viđeno uživo

Tačka 5 drugog dela `docs/PLAN-SNIMANJE.md`. Izvoz tutorijala odgovara čim
server prihvati film (202 i id posla), a film se crta posle odgovora. Traka može
da se sakrije („Hide") ili da prekine render („Cancel render"); kad se film
završi ili padne, stiže obaveštenje na zvonce. Tutorijali za proveru su u
`mislisha-test/render-fixtures`.

**Posao je izašao iz zahteva, 12.9.2026.** Objavljeni izvoz je prošao tim putem:
`tutorial_render_jobs` nosi red za lekciju 50 sa `status = done`, imenom fajla i
razlikom od 2 min 16 s između `created_at` i `finished_at` — dakle film je crtan
posle odgovora, a ne u njemu. „Hide", „Cancel render" i zvonce nisu gledani.

1. [ ] **Ekran se više ne zamrzava.** Izvezi `medium-12-parts`. Traka ima dva
   dugmeta. Pritisni „Hide": dijalog se zatvori, poruka kaže da se video i dalje
   renderuje, a aplikacija radi normalno dok server crta.
2. [ ] **Pronađi ga ponovo.** Otvori „Saved tutorials" dok se film crta: red tog
   tutorijala umesto kamere ima ikonu filma („Rendering — show progress"). Klik
   otvara istu traku, sa pravim procentom.
3. [ ] **Obaveštenje.** Kad se film završi, na zvoncetu je „Your video of … is
   ready" sa ikonom filma, a „Download video" na redu radi.
4. [ ] **Drugi izvoz istog tutorijala.** Dok se film crta, u studiju pritisni
   „Export video" za isti tutorijal: posle „Export" stiže poruka da se tutorijal
   već renderuje i prikazuje se traka tog filma — drugi se ne pokreće.
5. [ ] **Prekid.** Pokreni izvoz i pritisni „Cancel render": dugme kaže
   „Cancelling…", traka se zatvori sa „Video export cancelled.", u `exports/` nema
   novog fajla, broj renderovanja na nalogu nije porastao, i nema obaveštenja.
6. [ ] **Prekid dok čeka u redu.** Sa naloga A pusti dugačak film, sa naloga B
   kratak, koji čeka iza njega, pa ga B prekine: B-ov film odmah nestaje iz reda
   (A-ov ide dalje), i B može odmah da izveze ponovo.
7. [ ] **Restart servera usred rendera.** Pusti film, pa zaustavi i ponovo pokreni
   backend. Trener dobije obaveštenje „… could not be rendered. The server stopped
   rendering this video before it was finished. Export it again.", a traka koja je
   bila otvorena kaže to isto umesto da stoji.
8. [ ] **Telefon na 360 dp.** Traka sa oba dugmeta staje na ekran (ovo važi tek kad
   tutorijali budu dostupni i na telefonu — vidi „What the live check changed" u
   planu).
9. [ ] **Snimak od 30 minuta.** U studiju otvori „Record narration": studio prvo
   pita server za granicu (`GET /lessons/:id/narration` sada vraća `maxMs`).
   Snimanje staje samo na 29:59 i kaže „30 minutes is the most one recording may
   be"; slanje (oko 57 MB) prolazi, a izvoz tog snimka na 720p se nacrta (oko
   600 s na podrazumevanoj brzini). Kad server ne može da se pita, ekran staje na
   14:59 — namerno kraće, jer se kraći snimak uvek prima.
10. [ ] **Snimljeni čas i dugačak tutorijal.** Sa naloga A pusti izvoz dugačkog
    tutorijala (nekoliko minuta crtanja), pa odmah sa naloga B izvezi snimljeni
    čas. Dok tutorijal još **čeka** u redu, čas ide ispred njega. Dok se tutorijal
    već **crta** i ostalo mu je više vremena nego što čas ima, čas odmah dobija
    „… could not finish it before the connection closes. Try again in about N
    minutes" — umesto da visi 300 s dok ga nginx ne preseče.

## 144. Film progovara, a nemi film kaže zašto — 10.9.2026, nije viđeno uživo

Posle prijave od 10.9.2026 („renderuje video bez glasa iako sam stavio jezik").
Dve izmene: piper je na razvojnoj mašini prešao u virtualenv
(`PIPER_PYTHON=C:/Users/Admin/.piper/env/Scripts/python.exe`), i server sada
pita **da li motor uopšte može da se pokrene** pre nego što ponudi glas. Vidi
„Glas koji ne može da progovori se sada zna pre crtanja" u `docs/STANJE-RADA.md`.

1. [ ] **Naracija zaista govori.** Izvezi bilo koji tutorijal sa „Narrate this
   video" i izabranim glasom: film ima glas, a poruka na kraju je obična „Video
   rendered successfully…" bez ijedne rečenice o naraciji.
2. [ ] **Kad motora nema, prekidača nema.** Privremeno pokvari `PIPER_PYTHON` u
   `.env` (npr. `PIPER_PYTHON=nema-ovoga`) i restartuj backend. U izvoznom listu
   pitanja o zvuku više nema — nudi se samo nem film (i sopstveni snimak, ako
   postoji), jer server ne nudi nijedan glas. U logu stoji jedna `WARN` rečenica:
   „piper voices are installed but the engine cannot start".
3. [ ] **Rečenica koja razlikuje dva kvara.** Sa pokvarenim `PIPER_PYTHON`
   izvezi tutorijal (naracija se ne može tražiti iz aplikacije — ovo je provera
   servera, npr. `curl`-om sa `narrate: true`): odgovor kaže „the speech engine
   could not start", a **ne** „no speech voices installed". Vrati `.env` na
   venv putanju i restartuj.
4. [ ] **Vraćanje u normalu.** Posle vraćanja `.env`-a prekidač „Narrate this
   video" je opet tu, sa punim spiskom glasova.

## 145. Azure Speech govori, i srpski se izgovara kao srpski — 11.9.2026, nije viđeno uživo

Traži vlasnikov ključ i region, pa se ne može proveriti bez njega. U `.env`:
`TTS_PROVIDER=azure`, `AZURE_SPEECH_KEY=<ključ iz portala>`,
`AZURE_SPEECH_REGION=<npr. northeurope>` — region kao kratko ime, ne URL. Ključ
nikad ne ide u repozitorijum, u dokument ni u poruku komita. Vidi „Azure Speech,
i srpski koji je vraćen a ne preveden" u `docs/STANJE-RADA.md`.

1. [x] **Nalog odgovara.** ✅ Vlasnik, 11.9.2026: `provider: azure`,
   **655 glasova u 154 jezika**, i `exports/tts-probe.wav` je napisan za 678 ms.
   Ostaje samo da se odsluša — ako ikad odgovori 401, ključ je pogrešan; 403
   znači da region ne odgovara resursu.
2. [x] **Ima li srpskog glasa.** ✅ Vlasnik, 11.9.2026: **ima, četiri** —
   `sr-RS-NicholasNeural` i `sr-RS-SophieNeural`, plus `sr-Latn-RS-` blizanci.
   U tri fajla je stajalo da ga nema, a provereno je bilo protiv Googleove
   liste; komentari su ispravljeni. Za tekst pisan latinicom uzmi `sr-Latn-RS`
   glas — `sr-RS` je ćirilički lokalitet.
3. [ ] **Srpski izgovor poteza.** Ako srpski glas postoji:
   `node scripts/tts-probe.js "Odigraj Bd5, pa O-O." <id tog glasa>` — voice
   mora reći „lovac d pet" i „mala rokada", a ne da slovka „be de pet".
4. [x] **Film sa Azure glasom.** ✅ Vlasnik, 12.9.2026: „Master the Rook and
   King Checkmate" izvezen sa engleskim Azure glasom i objavljen na YouTube.
   Film govori kroz celu dužinu (22 050 Hz mono, tačno Azureov
   `riff-22050hz-16bit-mono-pcm`, srednje −23,7 dB); takte je odredio glas, ne
   nemi sat — za ovaj tekst nemi sat daje ~159 s, a film traje 170 s; poruka
   posla je obična „Video rendered successfully, saved, and ready for
   download!", bez rečenice o naraciji.
5. [ ] **Rečenica sa `&` ili `<`.** Napiši u nekom taktu „Nimzo & Bogo" ili
   „1 < 2" pa izvezi: glas te reči izgovori normalno, ništa se ne odbija, i u
   logu nema `Azure refused`.
6. [ ] **Filter po jeziku.** Otvori izvozni list sa Azure provajderom: prvo se
   bira **jezik** (imenom, „Serbian (Latin, Serbia)"), pa glas — i lista glasova
   drži samo taj jezik. Promena jezika povlači i glas za sobom. Sa piperom, gde
   svih šest glasova ima svoj jezik, kontrola za jezik takođe postoji; sa jednim
   instaliranim glasom je nema. Vidi „Izbor glasa: prvo jezik, pa glas" u
   `docs/STANJE-RADA.md`.
6b. [ ] **Prvi izvoz posle promene provajdera.** Zapamćen piperov glas više ne
   postoji na Azureu: list se otvara na engleskom i šalje Azure glas, a ne stari
   id (i ne afrikans, koji je prvi na sortiranoj listi od 655).
7. [ ] **Piper i dalje radi.** Vrati `TTS_PROVIDER=piper`, restartuj backend,
   izvezi film sa naracijom: govori kao pre. Rezerva mora da ostane rezerva.

## 146. Slova se čuju i vide, i glas se sluša pre renderovanja — 11.9.2026, delimično provereno

Četiri prijave od 11.9.2026, vidi „Četiri prijave uživo: slova, glas i uzorak"
u `docs/STANJE-RADA.md`.

1. [x] **Srpski izgovor slova kolone.** ✅ Sintetizovano pravim glasom
   11.9.2026: `node scripts/tts-probe.js "Odigraj Bc4, pa O-O."
   sr-Latn-RS-NicholasNeural` → „Odigraj lovac ce četiri, pa mala rokada",
   2,86 s u `exports/tts-probe.wav`. **Ostaje da se odsluša** i potvrdi da se
   „ce" sada čuje jasno.
2. [ ] **Ćirilički glas.** `node scripts/tts-probe.js "Odigraj Bc4."
   sr-RS-NicholasNeural` — dodate reči su na ćirilici („ловац це четири"), a
   trenerova rečenica ostaje kako je napisana. Pitanje na koje samo uho
   odgovara: čita li ćirilički glas uopšte latinicu kojom su natpisi pisani?
   Ako ne, `sr-Latn-RS` je jedini upotrebljiv za ovaj projekat i to treba
   zapisati.
3. [ ] **Dijakritike u filmu.** Izvezi tutorijal čiji natpis ima č, ć, š, đ i ž
   („Ovo je početak partije"): u filmu se vide sva slova, i u naslovu i u
   natpisu. Ranije je svako bilo kvadratić.
4. [ ] **Brojevi redova na tabli.** U istom filmu, uz levu ivicu table stoje
   brojevi 1–8, a uz donju slova a–h. Brojevi su nedostajali od 9.9.2026.
5. [ ] **Slušanje glasa pre renderovanja.** U izvoznom listu, pored padajuće
   liste glasova, dugme sa zvučnikom: pritisak pušta jednu rečenicu tim glasom
   („Odigraj Bc4…"), dugme se pretvori u spinner dok traje, i **ništa se ne
   renderuje**. Promeni glas pa pritisni ponovo — čuje se novi glas.
6. [ ] **Glas koji server nema.** (Za onoga ko dira `.env`.) Sa `TTS_PROVIDER`
   na piperu, uzorak radi za piperove glasove; Azure id više nije u listi i ne
   može da se izabere.

## 147. Tutorijal se učitava iz fajla, i oznake filtriraju listu — 11.9.2026, nije viđeno uživo

Vidi „Tutorijal iz fajla, i oznake koje su oduvek postojale" u
`docs/STANJE-RADA.md`. Radi se na Windows build-u, jer je studio tamo.
Popravljeni fajlovi su u `fixed/` podfolderu onog u kome su tutorijali.

1. [ ] **Jedan fajl, pogled pre čuvanja.** Biblioteka → Interaktivni tutorijali
   → „Import from a file" → izaberi jedan **čist** fajl (npr.
   `01_direktna_opozicija...`). Dijalog kaže koliko delova ima i da nema
   primedbi. „Open for editing" otvara studio sa naslovom i svim delovima, a
   tabla pokazuje prvi. **Ništa još nije sačuvano**: zatvori studio bez čuvanja,
   otvori „Sačuvani tutorijali" — tutorijala nema.
2. [ ] **Isti fajl, pa sačuvan.** Ponovi, ali u studiju pritisni „Sačuvaj
   tutorijal". Sada je u „Sačuvani tutorijali", otvara se ponovo i delovi su
   isti.
3. [ ] **Fajl sa greškom.** Izaberi `pawn_struct_isolated_queens_pawn.json` iz
   **originalnog** foldera (ne iz `fixed/`): dijalog imenuje deo i kaže da se
   sedam poteza ne može odigrati. Fajl se i dalje može otvoriti — u studiju se
   vidi da linija nije cela.
4. [ ] **Fajl koji server ne bi primio.** `adv_endgame_queen_vs_rook_and_pawn.json`
   iz `fixed/`: dijalog kaže da se rešenje „Qe5+" ne može odigrati u toj
   poziciji. (Jedan fajl se i dalje može otvoriti da bi se popravio.)
5. [ ] **Više fajlova odjednom.** Izaberi svih 27 iz `fixed/` (Ctrl+A u
   biraču). Dijalog kaže koliko ih može da se sačuva i koliko ne, i imenuje
   one koje ne može. Upiši „endgame" u polje za oznake i pritisni „Save … to
   the library". Poruka kaže koliko ih je uvezeno.
6. [ ] **Oznake filtriraju.** Otvori „Sačuvani tutorijali": iznad liste stoji
   pretraga i čip „endgame", a svaki red ispod naslova piše svoje oznake.
   Pritisak na čip ostavlja samo te tutorijale; drugi pritisak ih vraća.
   Ukucaj deo imena u pretragu — lista se suzi.
7. [ ] **Oznaka iz studija.** Otvori jedan tutorijal, u polju „Labels" dopiši
   „, rook", sačuvaj, vrati se na listu: čip „rook" postoji i taj tutorijal je
   pod njim.
8. [ ] **Opis preživi čuvanje.** (Ovo je greška koja je popravljena usput.)
   Uvezen tutorijal ima opis iz fajla. Otvori ga u studiju, pritisni „Sačuvaj
   tutorijal" bez ijedne izmene, pa ga otvori ponovo — opis i oznake su i dalje
   tu. Ranije bi oboje nestalo.
9. [ ] **Dete vidi tutorijal.** Pošalji jedan uvezen tutorijal đaku („pošalji"
   na redu liste) i prođi ga kao dete: delovi se smenjuju, pitanje traži potez,
   i **odgovor se ne vidi unapred** ni na jednom pitanju.


## 148. Ispis prati glas — 11.9.2026, nije viđeno uživo

Prijava od 11.9.2026. 11:11: u „Pregledaj kao učenik", na ▶, govor se završi
pre nego što se rečenica ispiše do kraja, pa ostatak stigne odjednom.

1. [ ] **Ispis i govor se završavaju zajedno.** Otvori tutorijal sa dužim
   komentarima, „Pregledaj kao učenik", pa ▶. Prva rečenica sme da se razmine
   (dotad se nema šta izmeriti); od druge nadalje poslednje slovo stiže kad i
   poslednja reč. Ne sme da se desi da glas ućuti a trećina rečenice skoči
   odjednom.
2. [ ] **Klizač za brzinu govora se poštuje.** Podešavanja → brzina na
   maksimum, pa isti tutorijal: ispis je brži tačno onoliko koliko i glas. Pa
   na minimum — ispis je sporiji. Ranije je išao istom brzinom u oba slučaja,
   i to je bila polovina greške.
3. [ ] **Promena glasa ne vuče staru brzinu.** Ako uređaj ima dva glasa: pusti
   tutorijal jednim, promeni glas u Podešavanjima, pusti ponovo — od druge
   rečenice ispis se poklapa sa **novim** glasom.
4. [ ] **Uputstvo govori istinu.** `docs/UPUTSTVO-STUDIO.md`, odeljak 8: bez
   ijednog upotrebljivog glasa na uređaju dugme ▶ se ne crta, a tutorijal se i
   dalje prolazi dugmadima.


## 149. Video bez komentara pored table — ✅ provereno uživo 11.9.2026

Potvrdio vlasnik 11.9.2026: „super sve radi". Vidi „Video bez komentara pored
table" u `docs/STANJE-RADA.md`. Tutorijal sa
komentarima, izvoz iz „Sačuvani tutorijali" ili iz studija.

1. [x] **Pregled pokazuje izbor.** U dijalogu za izvoz isključi „Comments
   beside the board", pa „Preview": tabla je na sredini kadra, pored nje nema
   teksta. Uključi ga i opet „Preview" — kolona sa rečenicom je tu, tabla levo.
2. [x] **Film je samo tabla, a glas i dalje čita.** Isključi komentare, izaberi
   neki glas u naraciji, izvezi. U videu nema teksta pored table, a glas
   izgovara svaku rečenicu u trenutku kad je takt na ekranu.
3. [x] **„No voice" daje nemi film bez teksta.** Isto, ali sa „No voice":
   taktovi i dalje stoje onoliko dugo koliko bi trebalo za čitanje — ne
   protrče.
4. [x] **Izbor se pamti.** Zatvori i ponovo otvori dijalog za izvoz: prekidač
   je isključen, kako je ostavljen. Uključi ga, izvezi, i sledeći put je opet
   uključen.
5. [x] **Telefon.** Na Androidu (360 dp) prekidač se vidi i može da se
   pritisne, a dugme „Export" ga ne pokriva.


## 150. Tutorijal se čita glasom svog jezika — 11.9.2026, nije viđeno uživo

`docs/PLAN-JEZIK-GLASA.md`, faze 1–5. Tutorijal kaže na kom je jeziku (jedan od
sedam), i čita ga glas tog jezika sa uređaja — ili niko. Nikad glas drugog
jezika. Tekst same aplikacije i dalje čita engleski glas.

**Priprema:** jedan tutorijal sa srpskim komentarima u kojima se pominju potezi
(„Posle Bc4 beli preti f7"). Jezik mu se bira u studiju, u polju „Language"
pored naziva. Za tačke 2 i 3 tutorijal treba dodeliti đaku ili ga otvoriti na
telefonu.

1. [ ] **Studio: izbor jezika.** Polje „Language" stoji u redu sa nazivom i
   oznakama; „Serbian (Latin)" i „Serbian (Cyrillic)" se čitaju cela, a u polje
   za naziv još može normalno da se kuca. Izaberi „Serbian (Latin)", „Save
   tutorial", zatvori, otvori ponovo iz „Saved tutorials" — i dalje piše
   „Serbian (Latin)".
2. [ ] **Windows, hrvatski glas `Matej`.** „Preview tutorial", pa ▶: čita
   Matej, i potezi se čuju na srpskom („lovac ce četiri"). **Presudi na uho**
   da li je „lovac ce četiri" dobro, ili bi „lovac c četiri" (samo slovo) bilo
   bolje — zadržava se ono što zvuči prirodno. Od druge rečenice ispis i govor
   se završavaju zajedno.
3. [ ] **Android.** Isti tutorijal na telefonu, kod đaka: čita Googleov srpski
   glas (ili hrvatski, ako srpskog nema), potezi na srpskom, isto pitanje kao u
   tački 2.
4. [ ] **Uređaj bez glasa za taj jezik.** Najlakše bez brisanja glasova:
   prebaci tutorijal na „German" (ili drugi jezik čiji glas nemaš), sačuvaj,
   „Preview tutorial". Umesto ▶ stoji prekriženi zvučnik („No voice for this
   tutorial's language"); dodir kaže da uređaj nema glas i šta da se instalira.
   Dugmad za poteze rade normalno, i ništa se ne čuje engleskim glasom.
5. [ ] **Ćirilica traži srpski glas.** Tutorijal na „Serbian (Cyrillic)" na
   Windows-u koji ima samo hrvatski: nema ▶, stoji prekriženi zvučnik.
6. [ ] **Bez jezika je kao pre.** Vrati tutorijal na „Not set", sačuvaj: čita
   ga glas iz Podešavanja, kao ranije. Isto za neki stari tutorijal koji nikad
   nije dobio jezik, i za jedan na „English".
7. [ ] **Izvoz videa.** Za tutorijal na „Serbian (Latin)" dijalog za izvoz se
   otvara na srpskim glasovima, ako ih server ima (Azure). Hrvatski glas se tu
   **ne** nudi kao srpski. Sa piper-om, koji nema srpski glas, dijalog se
   otvara kao ranije.
8. [ ] **Aplikacija i dalje govori engleski.** Tamo gde aplikacija čita svoj
   tekst (ne trenerov), to je i dalje engleski glas, bez obzira na jezik
   otvorenog tutorijala.
9. [ ] **Uputstvo govori istinu.** `docs/UPUTSTVO-STUDIO.md`, odeljak 8 opisuje
   baš ovo što si video.
10. [ ] **„h-linija" se čita „ha linija".** Prijava vlasnika od 11.9.2026: crtica
    se čitala kao „minus", a samo „h" se nije čulo. Komentar „Top ide na
    h-liniju, a c-pešak je slab." treba da se čuje kao „ha liniju" i „ce pešak".
    Redni brojevi se ne ispravljaju u kodu: piše se „sedmi red", ne „7. red"
    (`UPUTSTVO-STUDIO.md`, odeljak 5).

## 151. Istorija u studiju: undo, sačuvana verzija i nova linija — 11.9.2026, nije viđeno uživo

`docs/PLAN-STUDIO-ISTORIJA.md`, faze 1–3. Uputstvo: `docs/UPUTSTVO-STUDIO.md`,
odeljak 2 („Insert a line here") i odeljak 7 („Vraćanje unazad i sačuvana
verzija"). Da deo vraćen undo-om i deo posle reza zadržavaju svoju oznaku na
serveru (pa rad đaka ostaje vezan za njih) proverava se u testovima, jer se na
ekranu ne vidi.

**Priprema:** jedan sačuvan tutorijal sa bar dva dela, na Windows-u.

1. [ ] **Obrisan deo se vraća.** Obriši deo, pa Undo (zakrivljena strelica gore
   desno, ili Ctrl+Z): deo je ponovo na istom mestu. „Save tutorial", zatvori,
   otvori ponovo — deo je tu.
2. [ ] **Rečenica je jedan korak.** Otkucaj rečenicu u komentar bez pauze: jedan
   Ctrl+Z briše celu rečenicu, ne slovo po slovo. Pa otkucaj rečenicu, odigraj
   potez dok je kursor još u polju, i pritisni Ctrl+Z: vraća se potez, rečenica
   ostaje.
3. [ ] **Redo.** Ctrl+Y vraća ono što je Undo uklonio. Nova izmena posle Undo-a
   gasi Redo.
4. [ ] **Pitanje pri otvaranju.** Obriši deo, **ne čuvaj**, zatvori studio.
   Otvori isti tutorijal iz „Saved tutorials": pita „This tutorial has changes
   you have not saved". **„Open the saved version"** → deo je tu; Ctrl+Z → opet
   ga nema. Zatvori, otvori ponovo, pa **„Continue with my changes"** → deo
   nema, a „Discard changes" (sat sa strelicom, pored Undo/Redo) svetli.
5. [ ] **Bez izmena nema pitanja.** Otvori sačuvan tutorijal, prošetaj po
   taktovima i delovima bez menjanja, zatvori, otvori ponovo: ništa ne pita, a
   „Discard changes" je siva.
6. [ ] **Discard changes.** Odigraj potez, pa „Discard changes": potez nestaje;
   Ctrl+Z ga vraća. Posle „Save tutorial" dugme je sivo.
7. [ ] **Vlasnikov primer.** Pozicija `8/3k4/1n3b2/8/8/8/2PK4/2R5 w - - 0 1`,
   linija `1. Ra1 Kc6 2. Ra6 Bb2 3. c3 Kb5`, sa komentarom, strelicom i poljem
   na nekoliko poteza. U „Flow" stani na karticu „after 1... Kc6" i pritisni
   ikonicu račvanja („Insert a line here"): nastaju tri dela, a studio stoji na
   početku nove linije. Odigraj `2. Ra8 Bb2`. Sačuvaj, pa „Preview tutorial":
   prvi deo i nova linija su jedna tabla, nastavak ponovo postavlja poziciju
   posle `Kc6`, i svaki komentar i oznaka su na svom potezu.
8. [ ] **Rez se vraća.** Ponovi rez, pa jedan Ctrl+Z: opet je jedan deo, sa
   celom linijom.
9. [ ] **Ikonica je samo gde ima smisla.** Na kartici takta na kome stojiš — da;
   na ostalim karticama, na delu bez poteza i na pitanju — ne.
10. [ ] **„Preview tutorial" rečima.** Na širokom prozoru stoji dugme sa rečima;
    na uskom (ispod 840) ikonica kape sa istim imenom. Ikonice Undo, Redo i
    Discard (`Icons.redo` i `Icons.restore` su nove) se vide — ako je neka
    prazna, obriši `chess_app/build/flutter_assets/fonts/MaterialIcons-Regular.otf`
    i builduj ponovo (CLAUDE.md, „stale icon font").
11. [ ] **Prečice su zapisane.** F1 → „Keyboard Shortcuts" ima grupu „Tutorial
    Studio" sa Ctrl+Z, Ctrl+Y i Ctrl+Shift+Z.
12. [ ] **Uputstvo govori istinu.** `docs/UPUTSTVO-STUDIO.md`, odeljci 2, 5
    (crtanje se gasi na novom taktu) i 7 opisuju baš ovo što si video.

## 152. Priručnik na sajtu, i put do njega iz aplikacije — 11.9.2026, nije viđeno uživo

`docs/PLAN-PRIRUCNIK.md`, faza 4 plana završnice. Trinaest stranica u
`site/mislisha/manual/`, pisanih **po zadacima**, i dva ulaza iz aplikacije.
Kapija `chess_app/test/manual_labels_test.dart` već proverava da svaka oznaka
koju priručnik citira postoji u `lib/`; ovde se proverava ono što test ne može
— da li je tekst **tačan i upotrebljiv**.

**Priprema:** sajt još nije objavljen (`TODO-objavljivanje`, korak 3a), pa se
stranice čitaju lokalno — otvori
`site/mislisha/manual/index.html` u pregledaču. Kad sajt bude objavljen,
ponoviti tačku 1.

1. [ ] **Link iz aplikacije.** Settings → sekcija „HELP" → red
   „User manual" otvara pregledač na
   `chesstrainers.app/mislisha/manual/`. Isto i dugme „User manual" na F1
   strani. Dok sajt nije objavljen, očekivano je da stranica ne postoji —
   proveri samo da se pregledač otvara i da je adresa tačna.
2. [ ] **Sadržaj vodi kuda kaže.** Na `index.html` svaka od trinaest stavki
   otvara svoju stranicu, i sa svake se vraća na sadržaj.
3. [ ] **Uradi tri zadatka po uputstvu.** Bez znanja iz glave: otvori stranicu i
   radi tačno ono što piše.
   - „Write a tutorial" — napiši kratak tutorijal sa jednim pitanjem.
   - „Send a tutorial to a student" — pošalji ga nekom svom nalogu-učeniku.
   - „Turn a tutorial into a video" — izvezi ga kao video.
   Ako te uputstvo na bilo kom koraku pošalje na pogrešno mesto, to je greška
   uputstva, ne tvoja — zapiši gde.
4. [ ] **Stranice za igrače i učenike.** „Practise on your own",
   „Build an opening repertoire", „Analyse a position or a game" i
   „Work with your trainer" — pročitaj i reci da li opisuju ono što zaista
   vidiš na ekranu.
5. [ ] **Stranica za roditelje.** „For parents" — da li je to ono što bi hteo da
   roditelj pročita, i slaže li se sa stranicom saglasnosti koju server
   servira.
6. [ ] **Stranica proizvoda.** `site/mislisha.html` — opis aplikacije je
   osvežen (tutorijali, časovi, vežbanje, video, izveštaj roditelju). Da li je
   to opis pod kojim bi je objavio.
7. [ ] **Ništa ne fali.** Ako ti nedostaje zadatak koji radiš često, a nema ga
   u sadržaju — to je sledeća stranica.

Napomena: engleska politika privatnosti na sajtu je starija od odluke 13+ i
nije usklađena sa današnjim ponašanjem aplikacije — to je zaseban, pravni
zadatak i ne proverava se ovde.

## 153. Oznake na tabli: poslednji potez ispod figura, trenerovo polje u okviru — 12.9.2026, nije viđeno uživo

`docs/PLAN-OZNAKE-NA-TABLI.md`, sve četiri faze. Iz četiri vlasnikove prijave
od 12.9.2026. Četiri dela, jer su četiri različite stvari za gledanje.

**A. Poslednji potez se vidi tamo gde se ranije nije.** Otvori „Tactics
tailored to you" i odigraj potez: i polje sa kog je figura krenula i polje na
koje je stigla treba da potamne, **i isto to za protivnikov odgovor** — to je
bila prijava („nekad ne vidim da je suprotna strana odgovorila"). Zatim isto u
**sobi** (živi čas), pa u „Find the winning path" i u završnicama. Pre ovoga je
crtalo 5 od 15 ekrana; sada crtaju svi.

**B. Vidi se, ali nije preglasno.** Figura na obeleženom polju mora da ostane
bar jednako čitljiva kao ranije — senka je ispod figure, ne preko nje. Ako je
pretiho na telefonu po danu, to je jedan broj na jednom mestu
(`LastMovePainter.wash`, crna 22%); alternativa koja je merena i radi je
tamnoplava 35%.

**C. Stari tutorijal, pisan pre ovoga.** Otvori neki koji već ima obeležena
polja — u studiju i u đakovom pregledu. Krugova više nema nigde; na njihovom
mestu je tanak okvir po obodu polja, u boji koju si birao. Ništa sačuvano nije
menjano, pa i najstariji tutorijal treba da izgleda ispravno.

**D. Isti taj tutorijal kao video.** Izvezi ga i pogledaj: okviri i poslednji
potez treba da izgledaju kao na ekranu. Do ovoga je film imao svoju žutu boju
za poslednji potez i svoje prstenove.

**E. Niz polja (novo).** U studiju, „Square" pa „Line", pa klik na a2 i klik na
a7 — cela linija se oboji. Isto za red (a2→e2) i dijagonalu (a2→d5). Par koji
nije ni jedno ni drugo (a2→c7) oboji samo polje na koje si kliknuo. Ponovi isti
niz — briše se. Na Windowsu isto radi i držanje SHIFT-a bez dugmeta. Na telefonu
dugme je jedini način i mora da radi.

## 154. Vraćanje na već viđenu poziciju — 12.9.2026, nije viđeno uživo

`docs/PLAN-VRACANJE-NA-POZICIJU.md`, iz vlasnikovog zahteva posle prvog
objavljenog tutorijala. Film sada pod tablom kaže i **„Back to the position
after 12. Rh7"**, a spoj dva dela ne gasi poslednji potez. Za ovo je dovoljan
tutorijal u kom je jedna linija isečena na delove i iz jedne pozicije izlaze dve
varijante — „Master the Rook and King Checkmate" je tačno takav, i kopija mu
stoji u `D:/chess/tutorijal/reference/`.

1. [ ] **Vraćanje se vidi.** Izvezi taj tutorijal i gledaj granicu trećeg i
   četvrtog dela: u trenutku kad se tabla vrati, ispod nje piše „Back to the
   position after 3... Kd6" (ili koji je potez u tvojoj verziji), i taj natpis
   stoji dok se ne odigra prvi potez tog dela.
2. [ ] **Spoj ništa ne kaže.** Na granici prvog i drugog dela — gde se tabla ne
   menja — nema nikakve nove rečenice, a ispod table i dalje piše „Last move:
   …" istog poteza, **ne** „Starting position". Do 12.9.2026 je pisalo
   „Starting position" i potez pod tablom se gasio.
3. [ ] **Takt se vidi dovoljno dugo.** U **nemom** filmu (u izvoznom listu „No
   voice") takt koji se vraća stoji najmanje četiri sekunde — dovoljno da se
   natpis pročita. U filmu sa glasom dužinu odlučuje glas, kao i inače.
4. [ ] **Snimljena naracija ostaje važeća.** Ako imaš snimak preko tog
   tutorijala, studio **ne** sme da kaže da snimak više ne odgovara taktovima.
   Potpis liste taktova o ovome namerno ne zna ništa.
5. [ ] **Izvoz snimljenog časa izgleda isto.** `Replay` → izvoz MP4: pod tablom
   na prvom kadru piše „Starting position" kao i pre. Taj izvoz šalje jedan
   `init` bez spoja i ovo pravilo ga ne dotiče.
6. [ ] **Deo koji se otvara na poziciji koju niko nije dosegao.** Napravi
   tutorijal u kom je prvi deo samo dijagram (bez poteza), drugi deo negde
   drugde, a treći se vraća na tu prvu poziciju: natpis je „Back to a position
   already shown", bez poteza — jer poteza koji je do te table doveo u filmu
   nema.
7. [ ] **Dečji ekran još ne kaže ništa** (P2 nije rađen). U đakovom pregledu se
   granica prema već viđenoj poziciji ne vidi; ako ti to zafali u praksi, to je
   sledeća faza i treba da pozove isto pravilo, a ne novo.


## 155. Oznake van table i traka koja ne beži — 12.9.2026, nije viđeno uživo

Dve prijave od 12.9.2026, sa slikama: oznake kolona i redova su u filmu bile
unutar table a u studiju su spolja, i traka „Flow / Tree / PGN" je odlazila sa
ekrana pri skrolovanju. Vidi „Oznake van table, i kartice koje ne beže" u
`docs/STANJE-RADA.md`.

1. [ ] **Film i studio se slažu.** Izvezi bilo koji tutorijal i uporedi kadar
   sa studijom: slova a–h stoje **ispod** table, brojevi 1–8 **levo** od nje, u
   pojasu, prigušeni — i nigde na poljima. Tabla je za pojas manja nego pre;
   naslov, sat i kolona sa rečenicom stoje gde su i stajali.
2. [ ] **Izvoz snimljenog časa.** `Replay` → izvoz MP4: isto tako. Ovaj izvoz
   se menja namerno — zahtev je o tome kako oznake izgledaju, ne o jednom
   izvozu.
3. [ ] **Ugašene oznake.** U dijalogu za izvoz snimljenog časa isključi
   elemente sa oznakama: tabla uzima ceo prostor natrag, bez praznog pojasa.
4. [ ] **Traka stoji (širok prozor).** U studiju, na prozoru preko 840 dp,
   skroluj kartice u donjoj polovini: „Flow / Tree / PGN" ostaje na mestu.
5. [ ] **Traka stoji (uzak prozor).** Suzi prozor pod 840 dp, skroluj stranu
   dok traka ne dođe do vrha — tu stane i kartice prolaze ispod nje. Iznad nje
   su tabla i spisak delova i oni se normalno skroluju; traka ne može da bude
   prikačena pre nego što dođe do vrha, i to je tačno ono što je traženo.
6. [ ] **Kartica ne prosijava kroz traku.** Dok kartica prolazi ispod trake,
   traka mora da je prekrije — bez šava i bez teksta koji se vidi kroz nju.
7. [ ] **Uzak prozor, skrolovanje mišem.** Prevlačenje prstom/mišem **preko
   table** ne skroluje stranu (tabla to uzima za sebe, jer je to pomeranje
   figure) — koristi kolutić ili traku za skrolovanje. Ako ti ovo zafali u
   praksi, reci: rešenje bi bilo skrolovanje van table, a ne oduzimanje poteza
   tabli.


## 156. Ispis prati glas, a ne fajl — 12.9.2026, nije viđeno uživo

Iz dve prijave od 12.9.2026 (prva reč se ne čuje cela, i čekanje posle glasa).
Vidi „Ispis prati glas, a ne fajl" u `docs/STANJE-RADA.md`. Za sve ovo treba
izvoz sa naracijom — najbolje isti „Master the Rook and King Checkmate",
da može da se uporedi sa objavljenim filmom.

1. [ ] **Prva reč se čuje.** Film počinje sa 0,4 s tišine pa „Checkmating…".
   Ako se i sada čuje odsečeno, problem nije u fajlu — zvuk je izmeren i bio je
   ceo — nego u plejeru ili u uvodu koji je prekratak; onda je rešenje veći
   `LEAD_SECONDS`, ne traženje odsečenih semplova.
2. [ ] **Ispis se završava sa glasom.** Gledaj bilo koji takt sa dužom
   rečenicom: poslednja reč treba da se pojavi u trenutku kad je glas izgovori,
   a ne posle njega.
3. [ ] **Posle glasa se ne čeka dugo.** Pauza između dva takta treba da bude
   oko sekunde, ne dve. Ako je i dalje predugo, broj je `BREATH_SECONDS`.
4. [ ] **Film je kraći.** Isti tutorijal je po meri sa 168 s na oko 147 s, a
   ništa nije izbačeno — samo je prestalo da se dva puta plaća rep snimke.
5. [ ] **Nemi film je nedirnut.** Izvezi isti tutorijal sa „No voice": ispis i
   dužina taktova su kao pre (dvanaest slova u sekundi, tri četvrtine takta).
6. [ ] **Film bez natpisa, sa glasom.** „Comments beside the board" isključeno,
   glas uključen: taktovi se i dalje slažu sa glasom (tu se crta jednom u
   sekundi, pa se zaokružuje na celu sekundu).
7. [ ] **Trenerov snimak.** Izvoz sa „My recording" ide drugim putem (markeri iz
   snimanja) i ovim se ne menja — proveri da zvuk i tabla i dalje idu zajedno.


## 157. PGN izlazi iz aplikacije kao fajl — 12.9.2026, nije viđeno uživo

Tačka 4 iz `D:\chess\tutorijal\pgn_tutorial_question.txt`: izvoz je do sada
umeo samo u clipboard. Alatka **„Export PGN"** u ekranu **Analiza**; dijalog
sada ima tri dugmeta — „Close", „Save as .pgn" i „Copied".

Sam upis fajla je jedino što nijedan test ne može da dokaže: bira ga sistemski
dijalog, a to je platformski kanal. Zato je ovde.

1. [ ] **Dijalog se otvara odmah.** Tekst PGN-a je na ekranu čim se pritisne
   „Export PGN". Kopiranje u clipboard više se ne čeka pre otvaranja — ako se
   dijalog pojavljuje sa zastojem, promena nije odradila posao.
2. [ ] **„Copied" i dalje znači kopirano.** Nalepi u Notepad odmah po otvaranju
   dijaloga: tekst treba da bude tu, isti kao na ekranu.
3. [ ] **„Save as .pgn" otvara sistemski dijalog za snimanje**, sa ponuđenim
   imenom `analysis-2026-09-12.pgn` (današnji datum) i filterom na `.pgn`.
4. [ ] **Fajl postoji i sadrži ono što je bilo na ekranu** — komentari,
   `[%cal]` strelice, `[%csl]` polja i sve varijante. Uporedi sa tekstom iz
   dijaloga; to je isti string.
5. [ ] **Fajl se otvara u drugom programu.** Uvezi ga u ChessBase, Lichess
   („Import game") ili natrag u aplikaciju: potezi i komentari treba da prežive
   put napolje i nazad.
6. [ ] **Naša slova prežive.** Napiši komentar sa „š, đ, č, ć, ž", izvezi,
   otvori fajl u Notepad-u. Fajl se piše u UTF-8 namerno — zaglavlja ostaju
   ASCII zbog strožih čitača, ali trenerove rečenice su njegove reči. Ako se
   vide kao smeće, čitač je taj koji ne zna UTF-8, pa reci u kom programu.
7. [ ] **Poruka kaže gde je fajl.** Posle snimanja dijalog se zatvara i dole se
   pojavljuje „Saved: <putanja>". Putanja mora da bude cela i tačna — bez nje
   trener traži fajl po disku.
8. [ ] **Odustajanje ne radi ništa.** Pritisni „Save as .pgn" pa zatvori
   sistemski dijalog: nema poruke, dijalog sa tekstom ostaje otvoren.
9. [ ] **Neuspeh se prijavi.** Ako uspeš da izazoveš grešku (npr. snimanje na
   disk bez prava upisa), treba da piše „The file could not be saved.", a
   dijalog da ostane otvoren — tekst je i dalje tu da se kopira.
10. [ ] **Na telefonu.** Android ide drugim putem kroz plugin (fajl upisuje on,
    ne mi). Proveri da se fajl zaista pojavi tamo gde ga je Android ponudio, i
    da tri dugmeta i naslov stanu na uzak ekran — naslov sada prelama red
    umesto da se seče.


## 158. PGN ulazi u aplikaciju kao tutorijal — 13.9.2026, nije viđeno uživo

Tačka 1 iz `D:\chess\tutorijal\pgn_tutorial_question.txt`, faze 1–3 iz
`docs/PLAN-PGN-TUTORIJAL.md`. „Uvezi iz fajla" na listi sačuvanih tutorijala
sada prima i `.pgn` pored `.json`; jedna partija postaje jedan tutorijal, a gde
je „Review entire game" ostavio `??` sa engine-ovim potezom pored, ponudi se da
od toga naprave pitanja.

1. [ ] **Birač fajlova nudi `.pgn`.** „Uvezi iz fajla" → u sistemskom dijalogu
   se vide i `.json` i `.pgn` fajlovi.
2. [ ] **Jedna partija, jedan tutorijal.** Uvezi fajl sa dve-tri partije:
   izveštaj ima red po partiji, a naslov je „Beli - Crni (datum)" iz zaglavlja,
   ne ime fajla.
3. [ ] **Velika baza se preseče i to piše.** Uzmi svoj Lichess izvoz (4126
   partija): prvi red mora da kaže koliko partija fajl ima i da je pročitano
   prvih 50. Ako ništa ne piše, presek je tih — a to je greška.
4. [ ] **Pitanje o greškama se pojavi samo kad ima šta da se pita.** Uvezi
   partiju bez oznaka: dijalog „Make questions from the mistakes?" ne sme da
   se pojavi. Uvezi partiju kroz „Review entire game": treba da se pojavi i da
   kaže koliko ih je.
5. [ ] **„Just the games" ostavlja partije kakve jesu** — svaki tutorijal je
   jedan deo, `Show`.
6. [ ] **„Make questions" seče.** Otvori dobijeni tutorijal u studiju: pre
   pitanja ide demonstracija, pitanje je gola pozicija, a deo posle njega nosi
   odgovor. Rečenica pitanja ne sme da tvrdi da je odgovor jedini potez.
7. [ ] **Odgovor je engine-ov potez**, ne onaj koji je odigran u partiji.
8. [ ] **Ocene preživljavaju.** Otvori uvezenu partiju, promeni nešto bilo gde,
   sačuvaj, pa je otvori ponovo: `??` i `!` moraju i dalje da stoje na
   potezima. Do 12.9.2026. su se gubile pri prvom snimanju.
9. [ ] **Pokvaren fajl kaže šta je pokvareno.** Preimenuj neki tekst u `.pgn` i
   uvezi ga: poruka govori o partiji. Preimenuj pokvaren JSON u `.json`: poruka
   govori o JSON-u, ne o partiji.

## 159. Tutorijal izlazi kao PGN — 13.9.2026, nije viđeno uživo

Tačka 2 iz istog fajla, faza 4. Dugme **„Save as .pgn"** (ikona diskete) u
alatnoj traci **Studija za tutorijal**, pored izvoza videa. Upis fajla je opet
ono što nijedan test ne dokazuje.

1. [ ] **Dijalog kaže kako se tutorijal deli.** Otvori tutorijal čiji se delovi
   nastavljaju jedan na drugi: mora da piše „… one game". Otvori onaj sa
   delom na sasvim drugoj poziciji: „… 2 games".
2. [ ] **Rečenica o gubitku je tu i tačna** — šta deo pita, odgovor, primljeni
   potezi, orijentacija table, naslov, oznake i jezik ostaju u sačuvanom
   tutorijalu, ne u fajlu.
3. [ ] **Ime fajla je naslov tutorijala** (razmaci u crtice), a bez naslova
   `tutorial-2026-09-13.pgn`.
4. [ ] **Fajl ima onoliko partija koliko je dijalog rekao**, razdvojene praznim
   redom, svaka sa svojim zaglavljem; druga i svaka sledeća imaju `[SetUp "1"]`
   i `[FEN]`.
5. [ ] **Pitanje se u fajlu vidi kao rečenica na svojoj poziciji.** Izvezi
   tutorijal sa `ask_move` delom: tekst pitanja mora da stoji kao komentar pre
   poteza o kome se pita.
6. [ ] **Strelica se ne duplira.** Izvezi tutorijal koji je sečen na pitanje
   tamo gde je nacrtana strelica: u fajlu sme da stoji samo jedno `[%cal]` za
   nju.
7. [ ] **Put napolje i nazad.** Uvezi dobijeni fajl natrag kroz „Uvezi iz
   fajla": partije moraju da se pročitaju bez ijedne primedbe (zeleni redovi).
8. [ ] **Izvozi se ono što je na ekranu.** Napiši novu rečenicu u delu, **ne**
   pritiskaj „Save tutorial", pa izvezi: rečenica mora da bude u fajlu.
9. [ ] **Odustajanje ne radi ništa**, a posle snimanja se dijalog zatvara i
   piše „Saved: <putanja>".
10. [ ] **Traka studija i dalje staje.** Dugme je osmo u traci; na uskom
    prozoru (oko 700 dp) proveri da se ništa ne seče i da se naslov „Tutorial
    Studio" skraćuje sa tri tačke umesto da gura dugmad van ekrana.

## 160. Komentari detektora motiva su rečenice — 13.9.2026, nije viđeno uživo

Rečnik detektora (`tactical_motif_detector.dart`,
`positional_evaluator_service.dart`): nalazi su rečenice bez „Watch out —" i
„Resolved —", spajaju se razmakom umesto „ | ", i više se ne broje lažne
viljuške, iskošenja na braneni pešak, vezivanja pešaka za braneni skakač i
„branjenje" kralja; slabost boje polja je okrenuta na ispravnu stranu. Testovi
čitaju rečenice, ali nijedan ne vidi ekran ni ne sluša glas.

1. [ ] **„Review entire game" piše rečenice.** U Analizi pusti pregled cele
   partije: komentari moraju biti obične rečenice sa tačkom, bez „Watch out",
   „Resolved" i uspravne crte.
2. [ ] **Izmena komentara vraća štiklirane nalaze.** Na potezu sa dva nalaza
   (npr. dve vezane figure) otvori „Add / Edit Comment": oba nalaza moraju biti
   štiklirana, a slobodno polje prazno. Dodaj svoju belešku, sačuvaj, otvori
   ponovo — beleška je u slobodnom polju, nalazi i dalje štiklirani.
3. [ ] **Stari komentar ne nestaje.** Otvori analizu sačuvanu pre ovoga (sa
   „Pin: … | Resolved — …"): ceo stari tekst mora da stoji u slobodnom polju.
4. [ ] **Glas čita komentar kao govor.** Uvezi pregledanu partiju kao tutorijal
   i pusti ga: između dva nalaza mora da se čuje pauza rečenice, a ne „vertical
   bar" ili „pipe".
5. [ ] **Jedan pogled šahista.** Na tri partije iz `tools/game_annotate/input/`
   pročitaj nekoliko regenerisanih komentara: viljuška navodi samo ono što može
   da osvoji, a „weak" boja polja je ona koju pešaci ne pokrivaju.

## 161. Tutorijal iz partije, jednim dugmetom — 14.9.2026, nije viđeno uživo

`docs/PLAN-SKELET.md`, faze 2–4: u Analizi „Make a tutorial from this game" pokreće
Stockfish na uređaju, pita lokalnu majstorsku bazu na serveru, šalje skelet ruti
za reči (DeepSeek) i otvara tutorijal u studiju. Testovi voze sve to sa lažnim
motorom, lažnim serverom i lažnim modelom; **pravi poziv DeepSeek-u sa servera
nije napravljen nikad**. Pre provere vlasnik traži da mu se nalogu dodeli pro
nivo; na serveru moraju da postoje `DEEPSEEK_API_KEY` i `MASTERS_BOOK_PATH`.

**14.9.2026: vlasnik je prvi put prošao ceo put uživo** — analiza partije,
tutorijal, izvoz videa — i javio da radi; iz toga su nastala dva tutorijala,
„Lost chances: a fork, a pawn, a mate" i „Punish, Count, Retreat: Three Missed
Chances". To pokriva **tačke 1, 3 i 5** i polovinu tačke 2 (dubina je izabrana i
analiza je otišla do kraja; da li je izbor zapamćen nije javljeno). **Tačke 4,
6, 7 i 8 i dalje nisu proverene** i ostaju otvorene — nijedna nije ni pomenuta
u prijavi.

Iz te provere je izašlo devet prijava, sve popravljene istog dana; stavke 9–16
niže su te popravke i **nijedna od njih nije viđena uživo**. Pošto su menjale
skelet, tačke 3 i 5 treba proći ponovo.

Jedna napomena pre svega: `MASTERS_BOOK_PATH` se čita **pri pokretanju servera**
(`createMastersBook()` na importu rute), a `nodemon` ne prati `.env`. Ako
dijalog na kraju kaže `not-configured`, prvo uporediti kad je server startovan sa
tim kad je `.env` upisan.

1. [ ] **Dugme je tamo gde je partija.** Na Windows-u otvori partiju u Analizi
   (uvezi PGN): u traci stoji dugme sa kapom „Make a tutorial from this game".
   Na poziciji bez poteza isto dugme kaže da nema poteza, i ništa se ne pokreće.
2. [ ] **Dubina sa vremenom, i zapamćena.** Izbor nudi 18 / 20 / 22 sa vremenom
   pored svake; izaberi 20, pokreni, prekini. Sledeći put je 20 već izabrano.
   *(Od 14.9.2026 isti dijalog nosi i klizač za prag — vidi stavku 13.)*
3. [ ] **Napredak govori istinu.** Posle nekoliko pozicija piše „N of M
   positions · about X minutes left", a procena se ne vraća unazad više od
   jednom-dvaput. Uporedi ukupno vreme sa tabelom faze 0 (dubina 18: 39–109 s).
4. [ ] **Odustajanje gasi motor.** Tokom analize pritisni Cancel: dijalog piše
   „Cancelling…" i zatvara se u roku od par sekundi; u Task Manageru nema
   zaostalih `stockfish` procesa. Ponovo pokreni istu partiju na istoj dubini:
   već analizirane pozicije se ne traže ponovo (brojač skače brzo).
5. [ ] **Dva tutorijala, jedan otvoren.** Na kraju se nudi „Key moments" i
   „Whole game"; oba se otvaraju u studiju, sa rečima na delovima i pitanjima
   koja se mogu rešiti na tabli. Ako je nešto „to check", lista je razumljiva.
6. [ ] **Sa arhive u Analizu.** U arhivi otvori grešku („Mistake drill") i
   pritisni „Open this game in Analysis": otvara se cela partija, tabla stoji na
   potezu greške i okrenuta je strani igrača. Partija sa rokadom iz Lichess-a
   (`e1h1`) mora da se odigra do kraja.
7. [ ] **Svako odbijanje je rečenica.** (a) Bez Stockfish-a: poruka i dugme koje
   vodi u podešavanja motora. (b) Nalog bez pro/premium: poruka o nadogradnji.
   (c) Bez interneta posle analize: poruka o mreži, i kredit se ne troši
   (proveri broj preostalih tutorijala pre i posle). (d) Laptop u sleep usred
   analize: posle buđenja nastavlja, ne javlja grešku motora.
8. [ ] **Ime igrača ne izlazi sa uređaja.** Uz partiju sa pravim imenima u
   zaglavlju, u logu servera (ili u zahtevu) partija ide samo kao potezi.

Ispod su popravke od 14.9.2026, napravljene posle prve provere uživo. Za njih
treba **nova partija** (stara je keširana sa starim skeletom samo utoliko što su
reči snimljene; činjenice se ponovo koriste, pa analiza ide brzo).

9. [ ] **Tabla se ne okreće usred tutorijala.** Napravi tutorijal: **svaki** deo
   stoji belom stranom dole, i u studiju i u izvezenom videu — i oni u kojima je
   crni na potezu. *(Do večeri 14.9.2026 tutorijal je pratio orijentaciju table
   u Analizi; po pravilu vlasnika istog dana novi tutorijal je uvek beli dole, a
   okreće se u studiju ili u „Preview tutorial" — stavke 18 i 19.)*
10. [ ] **Odgovor ne kaže isti potez dvaput.** U delu sa odgovorom uvodna
    rečenica kaže šta je partija odigrala i koliko je koštalo, **ne imenuje**
    najbolji potez; prvi potez linije ga imenuje. Ranije su obe rečenice
    počinjale isto („White should have played Qe3…").
11. [ ] **Povratak na partiju se kaže.** Posle svake sporedne linije sledeći deo
    počinje rečenicom tipa „Back to the game" / „Back in the game" / „Returning
    to the game" — i **ne istom** svaki put. Proveri u oba tutorijala: u „Whole
    game" jedan po momentu, u „Key moments" jedan manje (pre prvog momenta ga
    nema).
12. [ ] **Linija ne staje usred žrtve.** Nađi deo u kom najbolja linija nešto
    daje: linija se ne završava na poziciji u kojoj je onaj ko je odigrao u
    minusu, osim ako se linija tu prosto završila. Ovo je bila prijava koja je
    pokrenula popravku — „beli je bolji a ne vidi se zašto".
13. [ ] **Prag i broj grešaka.** (a) U prvom dijalogu klizač „Teach a move that
    cost X pawns or more"; izaberi 2.0 i pokreni — sledeći put je 2.0 već tu.
    (b) Kad se analiza završi dolazi „What the engine found" sa brojem; pomeri
    klizač i broj se menja **odmah** (bez motora, bez čekanja). (c) Spusti prag
    dok ne ostane manje od dva — dugme „Write the tutorial" je ugašeno i piše da
    treba spustiti prag. (d) Pritisni Cancel tu: ništa se ne troši, a broj
    preostalih tutorijala je isti kao pre.
14. [ ] **Kritičan momenat i rekapitulacija.** U „Whole game" **poslednji** deo
    počinje sa „Looking back: the game turned on …" i ponavlja liniju tog
    momenta. U „Key moments" tog dela **nema**. Proceni i da li je označeni
    momenat zaista onaj na kom se partija prelomila.
15. [ ] **Drugi najbolji potez.** Tamo gde najbolja linija nešto žrtvuje, posle
    dela sa odgovorom stoji još jedan deo: „the other line" — šta radi sledeći
    najbolji potez i zašto je slabiji. Ne treba da se pojavljuje svuda (mereno:
    oko 29 od 69 momenata), i **ne sme** da bude račvanje na tabli — to je
    zaseban deo, a ne varijanta.
16. [ ] **Reči na novim delovima.** Pošto su dodati novi slotovi, proveri da
    dijalog na kraju ne prijavljuje gomilu „sentences to check": u pravom
    pozivu model piše sve ponuđene slotove. Ako ih ima mnogo, to je nalaz.

Druga provera uživo, 14.9.2026 uveče, na „The bishop pair and the open e-file
(whole game)" (sačuvana lekcija 57), dala je šest prijava (A–F). Popravke A, D i
E su u kodu istog dana; B, C i naracija su u `docs/PLAN-NARACIJA.md`, F je
odgovor. **Ništa od ovoga nije viđeno uživo.**

17. [ ] **Uzimanje nazad nije „figura bez odbrane".** U partiji sa razmenom
    (npr. `Bxf6 Nxf6`) komentar na potezu koji uzima **ne kaže** „the bishop on f6
    is attacked … and has no defender". Ali dama koja uzme skakača i stane pod
    pešaka i dalje dobija tu rečenicu. Za ovo treba **nova analiza partije**
    („Review entire game" ili novi tutorijal), jer su stari komentari sačuvani.
18. [ ] **Flip u studiju okreće sve delove.** U studiju sa tutorijalom od više
    delova pritisni „Flip board" ispod table: okreće se **svaki** deo, svaki
    suprotno od onoga kako je stajao (delovi 1 i 3 crni dole, 2 beli dole →
    1 i 3 beli dole, 2 crni dole). Proveri i posle „Save tutorial" i ponovnog
    otvaranja.
19. [ ] **„Preview tutorial" okreće jedan deo.** U pregledu dugme sa strelicama
    gore-desno („Flip this part") okreće samo deo koji se gleda, **i to ostaje**:
    idi na drugi deo i vrati se, zatvori pregled, sačuvaj, otvori ponovo — i u
    videu taj deo stoji tako. Radi i na delu sa pitanjem (tu nema trake sa
    potezima). Kod učenika tog dugmeta nema, a flip ispod table je samo pogled.
20. [ ] **Za učenike ili za video.** U poslednjem dijalogu („The same words made
    two tutorials") izbor „For students" / „For a video". Za video broj delova
    se odmah smanjuje, a otvoreni tutorijal nema nijedan deo sa pitanjem; ništa
    se ne plaća ponovo. Za učenike je kao do sada.

## 234. Zagonetke iz partije su zadaci; puzzle sets više nema — 23.9.2026, nije viđeno uživo

**Aplikacija i server** (nov build, restart backenda — tabela `puzzle_sets` je
obrisana 23.9.2026 na vlasnikovo da). `PLAN-MATERIJAL.md`, faza 4.

1. [ ] **Review entire game** sa uključenim „Extract puzzles…": posle
   analize dijalog **navodi** nađene zagonetke — tabla, „After 23...Qe7",
   odgovor motora, pad ocene, motiv — sve štiklirane, ime (igrači ako ih
   partija ima, inače „Game of dd.mm.yyyy") i „Keep N as exercises".
2. [ ] **Čuvanje.** Odštikliraj jednu i sačuvaj: poruka „Kept N exercises";
   u Biblioteci pod Exercises → „From mistakes" su tačno one, sa imenom
   „…, move N", i zadatkom „White/Black just played …".
3. [ ] **Rešavanje.** „Solve" na jednoj od njih: odgovor motora je tačan
   odgovor; drugi potez nije.
4. [ ] **Poslednji potez partije** kao greška: i ona ima odgovor (motor je
   pitan još jednom), ili piše „No answer found — cannot be kept".
5. [ ] **Nema više setova.** U Biblioteci nema čipa „Puzzle sets" (šest
   čipova), a u Analizi nema „Saved puzzle sets" među alatima.

## 233. Biblioteka je jedina polica; zadatak na mestu — 23.9.2026, nije viđeno uživo

**Aplikacija i server** (nov build, restart backenda). `PLAN-MATERIJAL.md`,
faza 3. Saved Positions više ne postoji.

1. [ ] **Posle skeniranja** poruka kaže „In the Library: …", a „View" otvara
   Biblioteku na toj knjizi (Exercises ako većina tabli ima rešenje, inače
   Positions), sa izabranim izvorom.
2. [ ] **Zadatak na mestu.** Na skeniranoj poziciji bez rešenja „Make
   exercise": ime je već upisano (naslov kartice). Sačuvaj — kartica prelazi
   pod Exercises, pod „From a book", i dalje nosi knjigu i stranu; nema nove
   kopije pod Positions.
3. [ ] **Izvor i „Needs attention".** Pod Exercises i Positions je izbor
   izvora („All sources" / ime knjige) i, kad ima takvih, „Needs attention
   (n)". Pod ostalim čipovima ih nema.
4. [ ] **Pretraga** nalazi po imenu knjige, po broju dijagrama iz knjige i po
   rečima zadatka, ne samo po naslovu.
5. [ ] **„Assign to student"** se ne vidi na nalogu bez prihvaćenog učenika; na
   trenerovom nalogu se vidi.
6. [ ] **Telefon uspravno.** Biblioteka → Exercises: filteri i kartice se
   vide, zaglavlje se pomera zajedno sa listom (do sada je zaglavlje bilo više
   od ekrana i kartica nije bilo).

## 232. Strana i odgovor pre čuvanja, na oba skenera — 23.9.2026, nije viđeno uživo

**Aplikacija i server** (nov build, restart backenda — nova kolona
`custom_puzzles.solution_source`, dodaje je `initDB`). `PLAN-MATERIJAL.md`,
faza 2. Lokalni motor mora da radi (Windows: Settings → Local engine).

1. [ ] **Knjiga u fontu.** Position Scanner → skeniraj opseg gde knjiga ne kaže
   ko je na potezu. Ispod zbira je dugme „Suggest sides with the engine" sa
   izborom dubine. Pokreni: „n of N" raste, ispod svake table bez strane stiže
   predlog (strana, potez, razlog, obe ocene) i dugmad „Set side" / „Set side
   and answer". Tabla čiju stranu je dala knjiga ili koju si okrenuo rukom pre
   pokretanja **nema** predlog.
2. [ ] **Slike.** Isto na knjizi sa slikama posle kalibracije, ispod dugmadi
   „Select shown…". Tabla koja nije pozicija se ne pita.
3. [ ] **Prihvatanje.** „Set side" menja stranu i skida oznaku „check"; „Set
   side and answer" još upisuje potez („answer (engine): …" na fontu). „Accept
   all confident (N)" uzima samo sigurne; „likely" ostaju. Posle čuvanja, u
   Biblioteci zadatak sa odgovorom motora je pod Exercises i može se rešiti
   („Solve", stavka 231).
4. [ ] **Stop** zaustavlja posle table koja se računa; predlozi koji su stigli
   ostaju.
5. [ ] **Telefon (font).** Posle skeniranja na telefonu table se vide, jedna
   po redu — do sada je mreža bila visoka 0 px ispod panela i zbira.
6. [ ] **Rukom okrenuta strana na fontu** se čuva kao postavljena (bez oznake
   za proveru), kao na slikama.
7. [ ] **Merenje (§7 plana):** koliko traje ceo paket slika na dubini 16 (upiši
   broj tabli i vreme), i koliko „confident" predloga si okrenuo rukom.

## 231. Rešavanje svojih zadataka, i zadatak-partija kroz domaći — 23.9.2026, nije viđeno uživo

**Aplikacija i server** (nov build, i restart backenda — nove rute
`POST /exercises/:id/attempt` i `GET /exercises/queue`). `PLAN-MATERIJAL.md`,
faze 0 i 1.

1. [ ] **Faza 0: zadatak-partija se dodeljuje.** Biblioteka → Exercises →
   kartica zadatka „Win" / „Draw or better" / „Play N moves" → „Assign to
   student": otvara se editor domaćeg sa tom jednom stavkom (ne crveni prozor
   kao do sada). Sačuvaj, pošalji učeniku — stiže mu kao partija.
2. [ ] **Faza 0: samo prihvaćeni učenici.** „Assign to student" na Find
   zadatku: u listi „Student" nema nikoga ko još nije prihvatio vezu.
3. [ ] **Solve iz Biblioteke.** Na kartici svog Find zadatka (ne na poziciji,
   ne na partiji, ne na onom sa oznakom „Side to move not set") je dugme sa
   slagalicom, „Solve". Otvara tablu sa zadatkom; jedan potez je odgovor:
   „Correct" ili „Not quite" sa rešenjem, i tabla više ne prima poteze.
4. [ ] **„Open" posle odgovora** vodi na ekran tog zadatka (rešenje, reči,
   oznake).
5. [ ] **Practise → Tactics → „My exercises".** Kartica postoji samo ako
   nalog ima bar jedan svoj Find zadatak. Posle nekoliko rešavanja piše
   „Solved N" ili „Solved N · M to retry"; „Solve" daje prvo nerešavane, pa
   promašene; „Retry failed (M)" samo promašene. Posle povratka broj je
   osvežen.
6. [ ] **Domaći se ne menja.** Isti zadatak rešen sam ne označava ništa u
   domaćem koji ga sadrži; učenik i dalje rešava domaći kao pre.

## 230. Pozicija bez strane na potezu se ne koristi dok se ne pita — 23.9.2026, nije viđeno uživo

**Samo aplikacija** (nov build). Pozicija čiju stranu niko nije postavio čuva
se kao „beli na potezu" sa oznakom za proveru; do sada ju je samo Saved
Positions pitao.

1. [ ] **Biblioteka pokazuje oznaku.** Kartica takve pozicije počinje sa „Side to
   move not set · …"; pozicija sa poznatom stranom nema tu oznaku.
2. [ ] **Otvaranje.** Tap na takvu karticu pita „Who is to move?"; posle
   odgovora otvara Analysis sa tom stranom, a kartica gubi oznaku. Pozicija sa
   poznatom stranom se otvara odmah, bez pitanja.
3. [ ] **Make exercise.** Prvo pitanje, pa tek onda prozor za vežbu, i vežba je
   na odabranoj strani. „Cancel" ne otvara ništa.
4. [ ] **Add to tutorial.** Iz Biblioteke i iz Saved Positions: prvo pitanje, pa
   izbor tutorijala; deo tutorijala ima odabranu stranu.
5. [ ] **Soba.** Tap na takvu poziciju u koloni sobe pita pre nego što je stavi
   na zajedničku tablu, i tabla je na odabranoj strani.

## 229. Deljena kalibracija — 23.9.2026, nije viđeno uživo

**Server i aplikacija** (server se sam restartovao; nov build). Plan:
`PLAN-SKENER-SLIKE.md`, faza 3g. Za proveru trebaju **dva naloga** i isti PDF.

1. [ ] **Drugi korisnik dobija table.** Nalog A kalibriše knjigu (npr. Back to
   Basics). Nalog B izabere isti PDF: otvara se kalibracija sa A-ovim tablama,
   svaka sa „Set up by another user: check it against the picture".
2. [ ] **Ne računaju se dok se ne provere.** Na B tabela ostaje prazna dok se na
   tabli ne pritisne „Correct" (ili „Edit"); „Done — choose pages" je ugašeno
   dok ima neproverenih; posle provere tabla se pamti na B-ovom nalogu.
3. [ ] **Samo ono što fali.** Nalog sa sopstvenom nedovršenom kalibracijom (npr.
   bez crne dame) dobija samo tablu koja to dodaje, ne sve A-ove.
4. [ ] **Ime se ne vidi.** Nigde se ne pojavljuje ko je postavio table.

## 228. Prvo kalibracija, pa strane — 23.9.2026, nije viđeno uživo

**Server i aplikacija** (server se sam restartovao; nov build). Plan:
`PLAN-SKENER-SLIKE.md`, faza 3f.

1. [ ] **Knjiga sa slikama se prepozna sama.** Skener → Select PDF → Back to
   Basics (ili Silman): kratko „Looking at the book…", pa se odmah otvara
   kalibracija (nova knjiga) ili „Choose the pages to read" (knjiga sa
   završenom kalibracijom). Nigde se ne pitaju strane pre kalibracije.
2. [ ] **Knjiga u fontu ide kao pre.** Knjiga sa dijagramima u šahovskom fontu
   (npr. `completechesscoursexcerpt.pdf`): posle izbora se vide polja From / To
   i „Scan", kao ranije.
3. [ ] **Strane.** „Choose the pages to read": 60 do 50 kaže „The last page is
   before the first", 1 do 41 „At most 40 pages at a time", i ništa se ne
   šalje; 1 do 40 čita.
4. [ ] **Ažuriranje kalibracije.** Na izboru strana „Update the calibration"
   otvara tabelu sa zapamćenim tablama; „Done — choose pages" vraća na strane.
5. [ ] **Druge strane.** Posle čitanja, dole „Other pages" vraća na izbor
   strana bez diranja kalibracije; na telefonu (360) oba dugmeta stanu.
6. [ ] **Nazad na skener.** Izađi iz kalibracije: skener pokazuje „The diagrams
   in this book are pictures" i „Continue", bez polja za strane.

## 227. Kalibraciju bira trener, uz tabelu šta nedostaje — 23.9.2026, nije viđeno uživo

**Server i aplikacija** (server se sam restartovao; nov build). Plan:
`PLAN-SKENER-SLIKE.md`, faza 3e.

1. [ ] **Prazna tabela.** Nova knjiga sa slikama (ili „Improve the calibration"
   pa ukloni sve): ekran „Teach the scanner this book" pokazuje tabelu White /
   Black × light / dark, sve ○, i „Find a board in the book". Knjiga se ne šalje
   dok ne pritisneš to dugme.
2. [ ] **Listanje knjige.** „Find a board in the book" otvara prozor „Choose a
   board" na stranama oko onih koje čitaš (20 strana odjednom); strelice i „Go
   to page" idu kroz celu knjigu. Strana bez slika kaže „No diagram pictures on
   these pages." Tabla koju si već izabrao je bleda i ne može se izabrati ponovo.
3. [ ] **Tabela prati table.** Izaberi tablu i postavi je: ćelije te figure
   postanu ✓, a druga boja polja ≈ (pogađa se). Rečenica ispod kaže šta još
   treba, prvo figure kojih nema nigde. „Read pages …" je ugašeno dok bilo koja
   figura nije viđena ni na jednoj boji polja.
4. [ ] **„Adds".** Na drugoj i sledećim tablama piše šta dodaju; tabla koja ne
   dodaje ništa kaže „Shows nothing the other boards do not." i ima „Remove".
5. [ ] **Tabla sa bilo koje strane.** Na Silmanu nađi damu (ili šta tabela
   traži) daleko od strana koje čitaš; posle „Read" čitanje radi, i ta tabla je
   zapamćena sa ostalima (sledeće skeniranje čita odmah).
6. [ ] **„No … in this book".** Čim je jedna tabla postavljena, ispod rečenice
   je po dugme za svaku figuru koje nema („No black queen in this book");
   uključeno, figura se više ne traži. Knjiga topovskih završnica (kraljevi,
   topovi, pešaci): šest dugmadi, sva uključena, i „Read" radi.
7. [ ] **Popravka kalibracije.** Na ekranu pročitanih tabli „Improve the
   calibration" (gore desno) ili „Add a board" u napomeni: vraća tabelu sa
   zapamćenim tablama i njihovim slikama; ništa se ne briše dok ne pročitaš
   ponovo.
8. [ ] **Figura koju skener nikad nije video.** Stara kalibracija bez neke
   figure: iznad tabli piše „No board you set up shows a … at all". Na skenu
   (Silman) polja sa takvom figurom su sada označena „?" (ranije je oko 8% njih
   prolazilo neoznačeno).
9. [ ] **Kalibracija se pamti dok se postavlja.** Postavi jednu ili dve table
   pa izađi bez „Read": sledeći put ista knjiga otvara tabelu sa tim tablama
   (ne praznu). Kad tabela pokazuje sve figure (ili su ostale označene „No …
   in this book"), knjiga ide pravo na čitanje. Knjiga topovskih završnica
   pamti šest „No …" i ne pita ponovo.
10. [ ] **Listanje ne troši skeniranja.** Prelistaj knjigu kroz desetak prozora
   od 20 strana, pa „Read" i „Scan": ne javlja se „Too many scans in a short
   time".

## 226. Posle živog prolaza 22.9.2026: kalibracija, font Fritz, brisanje bez poruke — nije viđeno uživo

**Server i aplikacija** (server se sam restartovao; nov build).

1. [ ] **Kalibracija ostaje.** Skener → knjiga sa slikama → „Read the pictures" →
   „Set up this position" → postavi tablu → „Generate and Set Position". Editor
   se zatvori, ostaješ na ekranu kalibracije, a ta tabla je postavljena (kvačica,
   dugme „Edit"). Isto za sve tri; zatim „Read 3 boards" čita knjigu.
2. [ ] **Velika knjiga.** Silman (preko 25 MB) se sada skenira; granica je 100 MB.
3. [ ] **Fritz font.** `D:\chess books\pawnvsking.pdf`, strane 1–21 → „Scan".
   Umesto poruke o slikama dolazi 16 pozicija (kraljevi i pešaci), 14 sa brojem
   dijagrama; prva, sa strane 13: crni kralj e8, beli kralj f6, beli pešak e5.
4. [ ] **Brisanje bez poruke.** Obriši nekoliko snimaka zaredom (Library i Home),
   pa set zagonetki, analizu, tutorijal, domaći, varijantu u Analizi i potez ili
   stranu u repertoaru: stavka nestane iz liste, a na dnu ekrana **ne** iskače
   zelena poruka. Kad brisanje ne uspe (npr. ugašen server), poruka o grešci i
   dalje stoji.
5. [ ] **Zvuk lekcije na telefonu.** Nov APK. Na telefonu (učenik, pa i trener)
   otvori podeljenu lekciju u plejeru i pritisni Play: glas se čuje, i drži
   korak sa tablom. Pauza, pomeranje klizača i ponovo Play: glas nastavlja od
   mesta na tabli. Na Windowsu i dalje radi kao pre.
6. [ ] **Tekst skenera.** Prazan ekran skenera kaže da se čitaju i dijagrami u
   fontu i dijagrami-slike; knjiga u kojoj nema ni jednog ni drugog dobija
   poruku koja to kaže, bez „only reads … chess font".
7. [ ] **Brisanje pozicije i vežbe.** Library: kartica pozicije ima kantu
   („Delete position"), vežba „Delete exercise"; obe se brišu i nestanu. Vežba
   koja je u domaćem koji učenik još nije završio (ili u sačuvanom, neposlatom
   domaćem) se **ne** briše: kartica ostaje, a poruka kaže koji domaći i koji
   učenik. Kad se domaći završi ili povuče, brisanje prolazi.
8. [ ] **Tutorijal sa videom.** Brisanje tutorijala koji ima video: dijalog kaže
   da se briše i video i nudi „Download video" (to ništa ne briše). Posle
   „Delete" u `chess_backend/exports/` više nema tog MP4. Isto iz Preparation
   kolone; tamo pozicija pita „Delete position?", ne „Delete tutorial?".
9. [ ] **Brisanje partija.** My games: na kartici igrača kanta; dijalog kaže
   koliko partija i čijih; posle „Delete" igrača nema na listi, a greške iz tih
   partija nestaju iz drila. Dok uvoz tog igrača traje, brisanje se odbija sa
   porukom. Ponovni uvoz ih vraća.
10. [ ] **Greška iz drila.** Mistake drill: „Remove from drill" pita, pa
    prelazi na sledeću grešku; ta se više ne vraća. Partija ostaje u arhivi.
11. [ ] **Obaveštenja.** Zvonce: svako obaveštenje ima × i nestane; „Clear all"
    briše sva, a zahtev koji čeka odgovor ostaje. Posle zatvaranja i ponovnog
    otvaranja obrisana se ne vraćaju.
12. [ ] **Editor u skeneru ne pita ko je na potezu.** Kalibracija i „Fix" na
    pročitanoj tabli: nema „To move" ni rokada, stoji rečenica da se čuva samo
    raspored figura. Tabla na kojoj je crni kralj u šahu (dakle crni na potezu)
    se prihvata.
13. [ ] **Kartica zna knjigu.** Skeniraj Silman ili 1001 (kalibrisane 22.9):
    kartica kaže „You set up this book before…", i „Read the pictures" čita
    odmah, bez tri table. Isto sa kopijom fajla pod drugim imenom. Za novu
    knjigu kartica i dalje objašnjava tri table.
14. [ ] **Kalibracija raste.** Silman: na tabli „to check" otvori editor, potvrdi
    (ili ispravi) i sačuvaj. Poruka kaže „The calibration now includes page …";
    sledeće skeniranje drugih strana te knjige više ne navodi tu figuru u
    napomeni o pogađanju. Kad je kalibracija puna (8), nova tabla zauzme mesto
    one koja ne pokazuje ništa što druge ne pokazuju, i poruka kaže koje. Tabla
    samo štiklirana, bez editora, ne ulazi.
15. [ ] **Strana na potezu bez Analize.** Saved Positions: na kartici bez potvrđene
    strane vidi se ceo red „Side to move not confirmed — set it" (ranije je bio
    odsečen); klik pita ko je na potezu, pamti odgovor i ostaje na listi. Klik
    na samu poziciju i dalje prvo pita, pa otvara Analizu.
16. [ ] **Filteri i izbor u skeneru slika.** Iznad tabli: „All / To check / Not a
    position / Set up by me" sa brojem, i klik prikazuje samo te table. „Select
    shown" / „Unselect shown" rade na prikazanim; „Only the ones I set up"
    ostavlja izabrane samo table potvrđene u editoru, a na njihovoj kartici piše
    „Set up by you". Save onda čuva tačno njih.

## 225. Dijagrami kao slike: kalibracija i potvrda — 22.9.2026, nije viđeno uživo

**Server i aplikacija** (server restartovan — nova tabela `book_calibrations`
se pravi sama pri pokretanju; nov build). Knjige: *Back to Basics*
(`D:\chess\pdf_books`), Reinfeld 1001 i Silman.

1. [ ] **Vrata.** Position Scanner → Silman, strane 40–60 → „Scan". Umesto
   crvene poruke stoji kartica „The diagrams in this book are pictures" sa
   brojem dijagrama i dugmetom „Read the pictures". Za knjigu u šahovskom fontu
   (npr. `completechesscoursexcerpt.pdf`) kartice nema, sken radi kao i pre.
2. [ ] **Kalibracija.** „Read the pictures" → tri predložene table, svaka sa
   slikom iz knjige i praznom tablom pored. „Read N boards" je sivo dok sve tri
   nisu postavljene. „Set up this position" otvara editor table **sa slikom iz
   knjige** (na Windowsu pored kontrola, na telefonu iznad palete).
   „Choose a different board" nudi ostale table.
3. [ ] **Čitanje.** Posle tri table → „Read N boards" → svaka tabla kao slika
   pored pročitanog; nesigurno polje ima **isprekidan okvir i „?"** — vidi se
   po obliku, ne po boji. Tabla koja nije pozicija nema kvadratić dok se ne
   ispravi dodirom na tablu.
4. [ ] **Pamćenje.** Isti PDF, druge strane (npr. 61–80) → posle „Read the
   pictures" nema kalibracije, ide pravo na čitanje. Isto na **drugom uređaju**
   sa istim nalogom (kalibracija je na nalogu, ne na uređaju).
5. [ ] **Čuvanje.** „Save (N)" → „In Saved Positions: …". U Saved Positions:
   table čiji potez nije menjan su označene za proveru, one gde je potez
   postavljen nisu.
6. [ ] **Napomena o pogađanju.** Ako tri table ne pokazuju neku figuru na nekoj
   boji polja, iznad tabli stoji napomena koja je imenuje („a white rook on a
   light square") i nudi „Set up again".
7. [ ] **Previše tabli.** *Back to Basics*, strane 41–80 (izmereno: 72
   dijagrama) → poruka koja kaže koliko ih ima (72), da se čita najviše 60, i
   da se izabere manje strana. (Opseg preko 40 strana odbija se ranije, sa
   drugom porukom.)

## 224. Skener na Teach — 22.9.2026, nije viđeno uživo

**Samo aplikacija** (nov build, server bez izmena).

1. [ ] **Kartica postoji.** Teach: pored „Preparation" i „New session" stoji
   „Scan a book" sa dugmetom „Scan"; na širokom prozoru sve tri u jednom redu,
   iste visine; na telefonu jedna ispod druge, „Scan a book" poslednja.
2. [ ] **Vodi u skener.** „Scan" otvara ekran skenera; „Back" vraća na Teach.
3. [ ] **Stara vrata rade.** U Analizi „Scan a book" (na telefonu iza ⋮) i
   dalje otvara isti ekran.

## 223. Jedna sesija na dupli klik, jedna kopija na Windowsu — 22.9.2026, nije viđeno uživo

**Server i aplikacija** (server restartovan sa novim `routes/rooms.js` i
`services/roomLifecycle.js`, nov **release** build — debug build je namerno
izuzet iz provere kopija).

1. [ ] **Dupli klik.** Teach → New session → „Start" dvaput što brže. Otvara se
   jedan ekran sobe; „Back" vodi na Teach, ne u drugu sobu. Na Home učenika je
   jedna sesija tog trenera.
2. [ ] **Dugme čeka.** Dok soba ne odgovori, „Start" je sivo sa kružićem (vidi
   se najlakše sa ugašenim serverom: posle poruke o grešci dugme je ponovo
   „Start").
3. [ ] **Druga kopija na Windowsu.** Pokreni Mislisha dok je već otvorena
   (prečica, ili dvaput `Mislisha.exe`). Nova kopija se ne otvara; postojeći
   prozor dođe napred, i ako je bio minimizovan — vrati se.
4. [ ] **Posle zatvaranja.** Zatvori aplikaciju, pokreni je ponovo — otvara se
   normalno.

## 222. Brisanje snimka — 22.9.2026, nije viđeno uživo

**Server i aplikacija** (server restartovan sa novim `routes/recordings.js`,
nov build). Snimci stoje u bazi (`session_recordings`), ne na uređaju;
`DELETE /recordings/:id` briše red samo domaćinu, a deljenja i zvučni fajl
(`uploads/lessons/…`) idu sa njim — odluka vlasnika od 22.9.2026.

1. [ ] **Library → Recordings.** Na kartici snimka pored „Play" je crvena kanta;
   pita „Delete recording?", „Cancel" ne briše ništa, „Delete" skida karticu i
   kaže „Recording deleted.". Posle „Refresh" snimak se ne vraća.
2. [ ] **Home → Recordings.** Isto na svom snimku; na snimku koji je trener
   podelio sa tobom (nalog učenika) kante nema.
3. [ ] **Kod učenika nestaje.** Snimak koji je bio podeljen sa učenikom posle
   brisanja više nije u njegovoj listi.
4. [ ] **Zvuk je obrisan.** Pre brisanja zapiši ime fajla (najnoviji
   `lesson_<id>_….wav` u `chess_backend/uploads/lessons/`); posle brisanja tog
   fajla više nema, a ostali snimci se i dalje puštaju sa zvukom.

## 221. Motivi samo za AI — 22.9.2026, nije viđeno uživo

**Samo aplikacija** (nov build). Taktički i pozicioni motivi se više ne vide i ne
računaju na promenu table; računaju se samo za „Generate AI comment" i za
tutorijal iz partije.

1. [ ] **Nema panela.** U Analizi nema „Tactical motifs" ni „Positional factors";
   dugme u traci se zove „Panels" i nudi Move tree, Opening Explorer, Tablebase i
   Engine analysis panel — bez prekidača za automatski komentar.
2. [ ] **Potez bez komentara.** Odigraj nekoliko poteza (i jednu viljušku): nijedan
   ne dobija komentar sam od sebe.
3. [ ] **Urednik je tekst.** „Add Comment" / „Add / Edit Comment" otvara samo polje
   za tekst, bez dve liste za štikliranje; sačuvan tekst stoji ispod poteza.
4. [ ] **AI komentar radi.** „Generate AI comment" na potezu vraća rečenicu u isto
   polje za tekst, i ona se čuva na „Save".
5. [ ] **Review i Auto Analysis.** „Review entire game" stavlja oznake (?, ?!), ali
   ne piše rečenice ispod poteza, i nema „Overwrite existing comments"; Auto
   Analysis gradi linije bez komentara.
6. [ ] **Tutorijal iz partije** i dalje priča o motivima (viljuška, vezivanje…) kao
   do sada — oni mu stižu iz Review-a, ne sa table.

## 220. Pad na Windowsu sa čitačem ekrana, i klizači koje crta aplikacija — 22.9.2026, pad ✅ proveren uživo 22.9.2026, izgled klizača nije viđen

**Samo aplikacija** (nov Windows build). Pad je bio u motoru, u
`AccessibilityBridge::SetRoleFromFlutterUpdate`, i dešavao se samo dok je neki
UI Automation klijent bio uključen (Narrator, tastatura na dodir). Vlasnik je
22.9.2026. prošao Preparation, sesiju, Analizu i Settings sa Narratorom i
debug buildom: nijedno odbijeno ažuriranje, nijedan pad. Ostaje da se pogleda
kako klizači izgledaju i rade — sada ih crta aplikacija (`AppSlider`), ne Flutter.

1. [ ] **Klizači rade mišem.** Board view → Board size (Preparation i Analiza),
   Settings (dva klizača), Auto-analysis, Game review, Quick extend, protivnik
   motor, tutorijal iz partije, replay: klik na traku pomera palac tamo, prevlačenje
   ga vuče, a iznad palca se vidi broj dok se vuče.
2. [ ] **Izgledaju prihvatljivo.** Traka, palac i podeoci na klizačima sa
   koracima; isključen klizač je siv.
3. [ ] **Tastatura.** Tab do klizača, strelice levo/desno pomeraju ga za jedan korak.
4. [ ] **Težina u domaćem i u Create assignment.** Umesto dvostrukog klizača:
   „From [−] 1200 [+]  To [−] 1800 [+]", korak 100, 400–2800. „From" ne može preko
   „To" (dugme se isključi), a poslati domaći nosi baš te brojeve.
5. [ ] **Build za izdanje.** Isto kao gore u release buildu (`Mislisha.exe`) sa
   Narratorom: posle desetak minuta rada nema pada u Event Logu (Application,
   „Application Error", `flutter_windows.dll`).

## 219. Sesija se završava, i stari poziv više nije vrata — 21.9.2026, nije viđeno uživo

**Server i aplikacija** (restart servera — dodaje kolone `rooms.created_at` i
`ended_at`; nov build za oba uređaja). Faza 1 iz `docs/PLAN-SESIJA.md`. Treba
dva naloga na dva uređaja, u prihvaćenoj vezi.

1. [ ] **Jedno „New session".** Teach → New session otvara sobu odmah, bez
   dijaloga za biranje prijatelja. U sobi si trener; poziv se šalje iznutra
   („Invite friends to session").
2. [ ] **Oba u istoj sobi.** Učenik prihvati poziv → u spisku „Present in
   classroom" na oba uređaja stoje oba imena, i kôd sobe u naslovu je isti.
3. [ ] **GLAS — ovo je glavno, i prvi put se gleda.** Oboje „Turn on voice" /
   „Join conversation": čujete li se u oba smera? Ako ne — šta piše u kartici
   „Audio Classroom" na svakom uređaju, i šta u logu servera (`[AGORA]`,
   `[AUDIO]`). Od ovog odgovora zavisi obim faze 4.
4. [ ] **„End session" završava za sve.** Trener ima „End session" (crveni
   stop), učenik „Leave session". Trener potvrdi → oba uređaja se vrate na
   Home sa „The session has ended.", a „Resume session" se ne nudi nijednom.
5. [ ] **Stari poziv nije vrata.** Posle 4, učenik otvori zvonce: na tom pozivu
   piše „This session has ended." i **nema dugmeta Join**.
6. [ ] **Nova sesija gasi staru.** Trener otvori sesiju A, učenik uđe; trener
   izađe na Home (strelica nazad, ne End) i pokrene New session → učenik u A
   dobija „The session has ended." i vraća se na Home; poziv za A više nema Join.
7. [ ] **Zapamćena mrtva soba ne blokira.** (Stanje od danas popodne.) Uređaj
   koji je pamtio staru sobu: posle otvaranja Home „Resume session" nestane sam,
   i Join na novom pozivu ulazi bez dijaloga o aktivnoj sesiji.
8. [ ] **Živa tuđa sesija se napušta pitanjem.** Učenik je u živoj sesiji,
   izađe strelicom na Home, i pritisne Join na pozivu za **drugu** živu sobu
   (treba drugi trener) → „Leave the other session?" → „Leave and continue"
   ulazi. *Ako nema drugog trenera, preskoči.*
9. [ ] **Gosti.** Room access (ikona grupe u sobi): nema prekidača „Room allows
   guests".
10. [ ] **Trainer panel** nema odeljak „Today".
11. [ ] **„Leave voice" ne izlazi iz sobe** (popravka posle prve probe; restart
    servera). Oboje u sobi, trener uključi glas pa „Leave voice". Zatim: učenik
    povuče potez → vidi se kod trenera; učenik izađe i ponovo uđe → spisak kod
    trenera se menja. Isto sa zamenjenim ulogama (učenik napusti glas).
12. [ ] **Poziv stiže i posle sobe.** Učenik uđe u sesiju, izađe strelicom na
    Home; trener mu odmah pošalje novi poziv iz sobe → dijalog poziva iskoči bez
    otvaranja zvonca. U logu nema „User disconnected: ID n" red posle „User
    registered" za isti nalog.
13. [ ] **Soba kaže ko je tu** (faza 2, nov build). U traci sobe, ispod „Room:
    …": trener sam → peščani sat i „Nobody has joined yet"; učenik sam →
    „Waiting for the trainer"; oboje → ikona ljudi i „With <ime>". Telefon
    položen: isto, u jednom redu pored koda sobe.
14. [ ] **Učenik pravi sesiju i zove trenera** (prijava 21.9: „trener ne dobija
    poziv, a učeniku piše da je poslat"). Posle restarta servera sa popravkom
    prisustva: poziv iskoči kod trenera. Ako server odbije poziv, učeniku se
    kaže zašto — a ne „successfully sent".
15. [ ] **Nema kucanja koda** (nov build, restart servera). Na Home više nema
    kartice „Join a session" ni polja za kôd. Kad je trener u sesiji, učeniku se
    na Home pojavi „In a session now" sa imenom trenera i dugmetom Join — i bez
    poziva. Kad trener završi sesiju i učenik se vrati na Home, kartice nema.
16. [ ] **Poziv grupi.** U sobi „Invite students to session": iznad spiska su
    čipovi grupa („Tuesday (4)"). Dodir na grupu štiklira njene članove u
    spisku; jedno ime može da se skine; „Send invitations (n)" šalje tim
    ljudima. U spisku su samo učenici koji su prihvatili — trenera nema.
    Telefon položen: spisak se skroluje i ime može da se štiklira.
17. [ ] **Vrata su jednosmerna.** Učenik pokrene svoju sesiju: treneru se na Home
    **ne** pojavljuje „In a session now" za nju, a u učenikovom dijalogu za
    poziv trenera nema.
18. [ ] **Jedan voditelj, dva stanja table** (faza 3; nov build, restart
    servera). Trener u sobi: umesto liste „Student permissions" stoji prekidač
    „Students may move", na početku isključen („Only you move on the board.").
    Učenik tada vidi katanac i „Board is locked by the trainer." i ne može da
    povuče potez; trener uključi → kod učenika „You may move on the board." i
    potezi rade. Nigde ne piše `host_only` ni „Permission status".
19. [ ] **Trener otvara sobu sa belima dole**, učenik sa crnima — bez ručnog
    okretanja. (Od „New session" je trener otvarao sa crnima dole.)
20. [ ] **Nema unapređivanja.** U spisku „Present in classroom" pored učenika
    nema menija ⋮ („Promote to Host" / „Demote to User").
21. [ ] **„Grant / Revoke microphone" stiže učeniku u sobi** (faza 4, samo
    server — restart). Oboje u sobi, oboje u glasu. Trener na učeniku pritisne
    „Revoke microphone" → učeniku odmah iskoči poruka da mu je mikrofon
    isključen i on ostaje da sluša; „Grant microphone" → poruka i mikrofon
    radi. (Do sada poruka nije stizala dok je učenik u sobi.)
22. [ ] **Glas koji ne krene kaže zašto** (faza 4, aplikacija; nov build).
    Ugasi server (ili isključi mrežu na telefonu), u sobi koja je već otvorena
    pritisni „Turn on voice": iznad dugmeta crveno piše „Voice could not
    start: the server did not answer." i dugme je i dalje tu. Do sada se panel
    samo vratio na „off" bez reči — ili se vrteo beskonačno.
23. [ ] **„*Ime* is in voice — Join voice".** Trener uključi glas, učenik ne.
    Kod učenika se ispod trake sobe pojavi zelena traka „*Ime trenera* is in
    voice" sa dugmetom „Join voice"; dugme uključuje glas i traka nestaje.
    Proveri na telefonu uspravno **i** položeno (traka uzima 40 px table dok
    stoji). Kod trenera trake nema dok je sam u glasu.
24. [ ] **Traka nestaje kad poslednji izađe** (traži server — tačka 27).
    Trener pritisne „Leave voice" dok je učenikov glas isključen: kod učenika
    traka nestaje odmah, i u panelu više ne piše „In call: …". Do sada je
    poslednje ime ostajalo na ekranu dok se soba ne zatvori.
25. [ ] **Glas preživi restart servera.** Oboje u glasu; restartuj server
    (sačuvaj bilo koji `.js`). Razgovor se ne prekida, a posle par sekundi
    spisak „Participants in audio call" kod oboje opet ima oba imena, trener sa
    „[Trainer]" — bez ponovnog pritiskanja dugmeta.
26. [ ] **Windows bez mikrofona.** Na Windowsu isključi mikrofon (Device
    Manager ili izvuci slušalice sa mikrofonom) i uđi u glas kao trener: u
    panelu žuto piše „Others cannot hear you: no microphone was found.", a
    dugmad ostaju. Priključi mikrofon i uđi ponovo: poruke nema.
27. [ ] **Kratak prekid veze ne skida nikoga sa spiska** (server). Učenik u
    sobi i u glasu; na telefonu isključi pa uključi Wi-Fi u roku od par
    sekundi. Sačekaj minut: učenik je i dalje u „Present in classroom" i u
    spisku glasa kod trenera. (Stari soket se gasio pola minuta kasnije i
    brisao mesto koje je novi već zauzeo.)
28. [ ] **Soba se ne snima** (faza 5a; nov build, restart servera). Trener sam
    u sobi: u desnoj koloni nema kartice „Session recording (Timeline)" ni
    dugmeta „Start recording" — ni kad učenik uđe. Izlazak strelicom nazad i
    „End session" ne pitaju ništa o snimku („Recording in progress" ne postoji).
29. [ ] **Stari snimci su tu.** Home → Recordings (i Library na Teach): snimci
    od ranije se otvaraju i puštaju, razmaknica pušta i pauzira, a dugme videa
    („Export to MP4 Video")
    pravi video kao pre. U `chess_backend/uploads/` ništa nije nestalo.
30. [ ] **Traka sobe** (faza 6; nov build, restart servera). Telefon uspravno,
    trener: ☰ · rečenica o prisutnima · slušalice · „Session" (klizači) · ⋮ ·
    crveni stop. Nema oblaka. Rečenica („Nobody has joined yet") se čita cela,
    u dva reda; kôd sobe je u panelu Session. Učenik: isto bez ☰ i bez
    „Session", i vrata umesto stopa. Proveri i položeno i na Windowsu.
31. [ ] **Ikona glasa kaže stanje.** Isključen glas → precrtane slušalice;
    dok se povezuje → kružić; uključen mikrofon → mikrofon; utišan → precrtan
    mikrofon; samo sluša → slušalice; greška → uzvičnik. Dodir otvara panel
    „Voice" sa desne strane, i u njemu je sve što je bila kartica „Audio
    Classroom".
32. [ ] **Panel Session.** Trener dodirne klizače: „Present in classroom" sa
    imenima, „Invite students to session", „Students may move", „Force student
    board to:", „Room access". Kad učenik uđe dok je panel otvoren, ime se
    pojavi bez zatvaranja panela.
33. [ ] **Učenik odgovara ispod table.** Telefon uspravno: odmah ispod table
    „Show my position to trainer", „Yes", „No", „I didn't understand" — bez
    skrolovanja, i **bez uključenog glasa**. Trener dobije odgovor. Položeno:
    isto, na vrhu kolone pored table.
34. [ ] **Učenik nema motor.** U sobi učenik nema panel „Engine" ni traku
    ocene; trener ima oba. U panelu Session nema „Allow Stockfish for
    student".
35. [ ] **Spuštena ruka.** Učenik u glasu, utišan: „Raise hand to speak" →
    kod trenera obaveštenje; zatim „Lower hand" → dugme se vrati na „Raise
    hand to speak", i sledeće podizanje opet javlja treneru.
36. [ ] **Nema „Mute all students".** Trener utišava učenike jednog po jednog,
    ikonom zvučnika u njihovom redu u panelu „Voice".
37. [ ] **Snimanje u Preparation** (faza 5b; nov build, restart servera —
    dodaje kolone i tabelu). U Preparation crvena tačka u traci („Start
    recording"). Nalog bez godine rođenja ili mlađi od 18: poruka odmah, snimanje
    ne počinje. Punoletan: ispod trake traka sa satom, Pause, Stop, Discard.
38. [ ] **Glas i tabla zajedno.** Snimi par minuta: pričaj, učitaj poziciju iz
    Library, prođi kroz liniju strelicom, nacrtaj strelicu, pauziraj pa
    nastavi. Stop → naslov → Save → „Recording saved. It is under Recordings."
    Na Home → Recordings otvori ga: glas i tabla idu zajedno do kraja (i posle
    poslednjeg poteza, ako si još pričao), strelice se vide, trajanje u kartici
    je tačno.
39. [ ] **Video lekcije.** U plejeru „Export to MP4 Video": video prati tablu
    kroz učitane pozicije i korake, glas je ceo.
40. [ ] **Ne izlazi se usred snimanja.** Dok snima, strelica nazad ne izlazi i
    piše „Stop or discard the recording first."; posle Discard izlazi.
    Isključi mrežu pa Save: „Try again" posle uključivanja pošalje lekciju.
41. [ ] **Deljenje.** U plejeru svoje lekcije „Share with students…": čipovi
    grupa, štikliranje, Share. Učenik dobije obaveštenje (ikona filma) i
    lekciju vidi na Home → Recordings; pušta je sa glasom. Na starom snimku iz
    sobe dugmeta za deljenje nema.
42. [ ] **Video za učenika.** Učenik u plejeru „Download video": pre nego što
    trener napravi video piše „No video yet — ask your trainer."; posle
    trenerovog Export-a dobija link i video se preuzima. Dugmeta za Export
    učenik nema.
43. [ ] **Deljenje prestaje sa vezom.** Kad trener ukloni učenika, lekcija
    nestaje sa učenikovog Home → Recordings; skidanje svih kvačica u
    „Share with students…" isto.

## 218. Stockfish 19 u aplikaciji — 21.9.2026, nije viđeno uživo

**Aplikacija** (nov build za telefon i Windows; server nije diran). Motor na
Androidu je sada Stockfish 19 iz `chess_app/packages/stockfish/`; APK je manji
za 13,88 MB. Pozadina: „Stockfish 19 u aplikaciji" u `STANJE-RADA.md`.

1. [ ] **Telefon: motor radi.** Analyse → uključi motor na početnoj poziciji:
   pojavljuju se tri linije i ocena, dubina raste kao ranije.
2. [ ] **Telefon: pozicija koju 19 ne prima ne gasi aplikaciju.** Analyse →
   postavi poziciju / nalepi FEN `4k3/8/8/8/8/8/8/4K3 w - e3 0 1` i uključi
   motor: ekran kaže da se pozicija odbija (en passant), aplikacija ostaje
   otvorena. Isto sa `4k3/8/8/8/8/8/8/4K3 w - - 40000 1`.
3. [ ] **Windows: „Download engine" radi.** Settings → motor → preuzimanje:
   završi se bez greške, a u logu piše `stockfish-windows-x86-64-universal`.
   (Do sada je od 5.9.2026 svaki pokušaj bio 404.)
4. [ ] **Poredjenje 18 i 19** (po želji vlasnika): isti položaji na telefonu,
   dubina i brzina (`nps`) u oba builda.

## 217. Domaći celoj grupi, ista imena analiza, i ko ima alate za podučavanje u sobi — 21.9.2026, nije viđeno uživo

**Aplikacija i server** (nov build za telefon i Windows; server je već
restartovan 21.9.2026 sa novom rutom `PUT /analysis/:id`). Tačke 9, 4 i 5 iz
pregleda komentara, sve tri po odlukama vlasnika od 21.9.2026.

**Napomena uz 201.10:** tamo je pisalo da učenik panel „Board" u sobi nema; to
nije bilo tačno, i po odluci vlasnika i ne treba — dugmad za čuvanje sopstvene
kopije (Save position, Save analysis, Export PGN) ostaju svakome ko sme da
pomera tablu, a alati za podučavanje idu po odnosu (tačke 7–10 ispod). Tekst
stavke 201.10 nije menjan, jer je već odgovorena.

1. [ ] **Čip grupe.** Teach → Homework → neki domaći → „Send": iznad liste
   učenika stoje čipovi grupa. Pritisak na grupu štiklira njene članove koji
   su prihvatili poziv, i samo njih. Ponovni pritisak ih odštiklira.
2. [ ] **Ko nije prihvatio** se ne štiklira, i ispod čipova to piše imenom.
3. [ ] **Ko već ima taj domaći** ima u listi „already has it", a čip ga
   **ne** štiklira (piše i to, imenom). Pošalji grupi, dodaj nekog u grupu,
   pa pošalji opet: dobija ga samo novi član, a ostali ne dobijaju drugu kopiju.
4. [ ] **Ručno se i dalje može** štiklirati i onaj ko ga već ima, ako se to
   hoće namerno.
5. [ ] **Isto ime analize.** Analyse → sačuvaj analizu pod imenom koje već
   postoji (i sa drugačijim velikim slovima ili razmakom na kraju): pita
   „Replace the saved analysis?" sa „Cancel / Keep both / Replace". „Replace"
   piše preko postojeće — u Library je i dalje **jedna** sa tim imenom, a
   otvorena ima nove poteze. „Keep both" pravi drugu, kao ranije.
6. [ ] **Isto iz Preparation** („Save analysis" u sobi): isto pitanje.
7. [ ] **Soba koju je otvorio učenik** (Windows, širok prozor, i telefon):
   učenik **nema** „Make exercise" ni ⋮/kantu na tutorijalima u listi, a ima
   „Save position", „Save analysis", „Export PGN". Trener koji je ušao **ima**
   „Make exercise" i akcije tutorijala.
8. [ ] **Trener otvori sobu pre nego što učenik udje**: „Make exercise" je tu od
   početka.
9. [ ] **Učenik u trenerovoj sobi**: nema „Make exercise" ni akcija tutorijala.
10. [ ] **Preparation** je nepromenjena: sve je tu.

## 216. „Find the move": potez ostaje na tabli, i rešenje se može skinuti — 21.9.2026, nije viđeno uživo

**Samo aplikacija, nov build** (Windows i telefon); server se ne dira. Tačka 8
iz pregleda komentara — vlasnikova sugestija na stavci 196.3. Menja dva
pravila koja je vlasnik već potvrdio (192.4 i 198.4: „glavni potez nema ×"),
na njegovu reč.

1. [ ] **Potez ostaje na tabli.** Preparation, postavi poziciju, „Make
   exercise" → „Play the move". Odigraj rešenje: potez **ostaje** na tabli,
   obeležen, oko **dve sekunde**, a iznad piše „… is the answer.". Za to vreme
   tabla ne prima potez.
2. [ ] **Pa se vraća i traži alternativu.** Posle dve sekunde tabla je opet na
   početnoj poziciji i piše „Play another move that should also count, or
   Save.". Odigraj alternativu: isto, sa „… is accepted as well.".
3. [ ] **Odbijen potez se ne zadržava.** Odigraj isti potez drugi put: tabla se
   odmah vraća i crveno piše zašto.
4. [ ] **Rešenje ima ×.** Ispod linije je i rešenje kao čip „Qh5 · answer" sa ×.
   Skini ga: prva alternativa postaje rešenje (linija piše samo nju). Skini i
   nju: ekran opet traži potez, a „Save" je sivo.
5. [ ] **„Start over" i dalje briše sve odjednom.**
6. [ ] **Sačuvan zadatak.** Library → „Exercises" → svoj „Find the move"
   zadatak: rešenje ima ×, skidanje ga menja alternativom, a kad ne ostane
   nijedan potez „Save" je sivo. Sačuvaj sa novim rešenjem i otvori opet —
   rešenje je ono novo.
7. [ ] **Telefon, uspravno i položeno**: čipovi i rečenice staju, ništa se ne
   seče.

## 215. Brisanje iz Biblioteke, „Make exercise" na poziciji, i oznake i jezik na telefonu — 21.9.2026, nije viđeno uživo

**Samo aplikacija, nov build** (Windows i telefon); server se ne dira. Tačke
3, 6 i 7 iz pregleda komentara 21.9.2026: prijava 211.4 („Nema dugme za
brisanje"), prijava od 20.9.2026 („U portret orjentaciji ne vide se label i
jezik tutorijala") i nalaz 205.3 (pozicija nudi slanje učeniku).

1. [ ] **Brisanje seta zagonetki iz Biblioteke.** Teach → Library → čip
   „Puzzle sets": na kartici je crvena kanta. Pritisak pita „Delete puzzle
   set?"; „Cancel" ne briše ništa, „Delete" ga skida sa police i piše „Puzzle
   set deleted.".
2. [ ] **Važi svuda** (ovo je bila stavka 211.4). Posle brisanja na jednom
   uredjaju, osveži Library na drugom (isti nalog): seta nema.
3. [ ] **Brisanje analize iz Biblioteke.** Čip „Analyses": na kartici je kanta,
   isto pitanje, i analiza nestaje; Analyse → ikona oblaka je više ne nudi.
4. [ ] **Server nedostupan.** Ugasi backend pa pokušaj da obrišeš set: kartica
   **ostaje**, a crvena poruka kaže da nije obrisan. Upali backend, osveži:
   set je i dalje tu (ranije bi nestao sa uredjaja pa se vratio pri sledećem
   učitavanju). Isto u Analizi → „Saved puzzle sets".
5. [ ] **Pozicija nema „Assign".** Čip „Positions": sken iz knjige **bez**
   rešenja i pozicija sačuvana iz sobe imaju „Add to tutorial" i **„Make
   exercise"** (ikona kvačice), a nemaju „Assign to student".
6. [ ] **Zadatak i dalje ima „Assign".** Čip „Exercises": sken sa rešenjem i
   zadatak napravljen u Preparation imaju „Assign to student", a nemaju „Make
   exercise".
7. [ ] **„Make exercise" sa kartice.** Otvara isti list kao „Make exercise" u
   sobi, na **toj** poziciji. Pod „Find the move" stoji „Play the move" (ekran
   zadatka); „Win", „Draw or better" i „Play N moves" se čuvaju iz lista.
   Posle „Save": „Exercise saved.", i zadatak je pod „Exercises"; originalna
   pozicija je i dalje pod „Positions".
8. [ ] **Oznake i jezik na telefonu.** Teach → Tutorials → New tutorial,
   telefon uspravno: ⋮ „More" → **„Details…"** otvara list sa „Labels" i
   „Language". Upiši oznake, izaberi jezik, „Done", sačuvaj tutorijal. U
   Library ga nalaziš po toj oznaci; na Windows-u otvoren pokazuje isti jezik.
9. [ ] **Isto položeno**, i sa otvorenom tastaturom: list se skroluje, ništa se
   ne seče.

## 214. Tudja analiza posle promene naloga, i motor koji staje kad se ode — ✅ provereno uživo 21.9.2026

**Samo aplikacija, nov build** (Windows i telefon); server se ne dira. Dva
nalaza iz pregleda 21.9.2026: prvi je prijava od 20.9.2026 („kada se promeni
nalog, i dalje imam opciju da nastavim analizu koji je prethodni nalog
pokrenuo"), koja se vratila posle popravke od 18.9 (stavka 177.2); drugi je
vlasnikov zahtev istog dana — motor staje kad se napusti ekran i **ostaje
ugašen**. Čip „Resume analysis" je uklonjen na vlasnikovu reč.

**Vlasnik je prošao sve tačke ispod i potvrdio ih istog dana, 21.9.2026**
(„sve ok"), na novom buildu za telefon i Windows.

1. [x] **Tudja analiza, glavni slučaj.** Nalog A: Analyse, odigraj nekoliko
   poteza. Odjavi se (Settings → Sign out). Prijavi se kao nalog B. Na Home
   **nema** „Resume analysis", a Analyse tab je **prazna početna tabla**, ne
   A-ova linija.
2. [x] **Isti nalog zadržava svoje.** Nalog A odigra nekoliko poteza u Analyse,
   ode na Home pa se vrati: linija je tu. Zatvori aplikaciju i otvori je opet
   (i dalje prijavljen kao A): linija je i dalje tu.
3. [x] **Gost koji se prijavi zadržava svoje.** Bez prijave odigraj nekoliko
   poteza u Analyse, pa se prijavi: linija je i dalje tu.
4. [x] **Tutorijal isto.** Nalog A: Teach → New tutorial, odigraj par poteza i
   upiši ime, **ne čuvaj**. Odjavi se, prijavi kao B, otvori New tutorial:
   nema pitanja o nezavršenom tutorijalu naloga A.
5. [x] **Motor staje kad se promeni tab.** Analyse, uključi motor (i traku
   ocene). Predji na Home, sačekaj par sekundi, vrati se na Analyse: motor je
   **ugašen**, nema linija ni trake, i ne pali se sam. Uključi ga — radi
   odmah.
6. [x] **Motor staje kad se preko Analize otvori drugi ekran.** Sa uključenim
   motorom otvori Settings (zupčanik u traci Analize) pa se vrati: motor je
   ugašen. Isto uspravno i položeno na telefonu.
7. [x] **Dijalog nije odlazak.** Sa uključenim motorom otvori „Setup Position"
   ili neki drugi dijalog i zatvori ga: motor je i dalje uključen.
8. [x] **Drugi ekran dobija motor.** Sa uključenim motorom u Analizi predji na
   Practise → „Basic mates" i igraj protiv motora: motor odgovara odmah, bez
   zastoja. Vrati se na Analyse: tamo je motor ugašen.

## 213. Home i Practise koriste širinu — ✅ provereno uživo 21.9.2026

**Samo aplikacija.** Faze 3 i 4 plana `PLAN-POCETNI-TABOVI.md`. Home više nema
granicu od 700 px; Practise više ne pita širinu prozora. Sekcije stoje jedna
ispod druge, a ono što je u njima teče u kolone koliko ih stane.

**Vlasnik je prošao sve tačke ispod i potvrdio ih istog dana, 21.9.2026.** U
istom prolazu je tražio da se kartica „Chess trainer and drills" na vrhu
Practise-a ukloni — uklonjena odmah posle.

1. [x] **Home, Windows, prozor oko 1400 px.** **Set for me · Due for review ·
   Join a session u jednom redu**, sve tri kartice iste visine (donje ivice u
   istoj liniji iako „Join a session" ima polje i dugme). Ne vide se kartice
   učenika ako nemaš trenera i nemaš ništa za ponavljanje — to je kao i pre.
2. [x] **Trainer panel.** Redovi ispod svakog naslova („To review", „Homework
   due soon"…) stoje **jedan pored drugog**, dugme desno u svakom redu.
   „Review", „Open" i „Enter" rade kao i pre. Razmak izmedju redova je
   malo veći nego ranije (12 umesto 8 px) — i na telefonu.
3. [x] **Recordings.** Svaki snimak je sada **mala kartica sa okvirom**, a
   kartice stoje jedna pored druge; „Play" otvara snimak kao i pre. *Na
   telefonu su kartice jedna ispod druge, sa okvirom umesto linije izmedju.*
4. [x] **Practise, prozor oko 1400 px.** **Tri kolone: Opening │ Tactics │
   Endgame and technique**, svaka faza u svojoj. Kartice se ne šire preko
   jedne širine kartice ni u najširem prozoru — sa strane ostaje prazno. To je
   jedina izrečena granica na ovim tabovima.
5. [x] **Najmanji prozor (900 px).** Tabu ostaje oko 800 px (traka sa
   leve strane uzima 77), pa Practise ima **dve** kolone — Opening i Tactics
   levo, Endgame and technique desno, kao do sada — a Home dve kartice u
   redu, „Join a session" ispod njih. Tri kolone na Practise počinju negde oko
   prozora od 1000 px. Ništa odsečeno, nijedno dugme van kartice.
6. [x] **Telefon.** Oba taba kao do sada: jedna kartica po redu, isti redosled.

## 212. Teach koristi širinu — ✅ provereno uživo 21.9.2026

**Samo aplikacija.** Faza 2 plana `PLAN-POCETNI-TABOVI.md`: Teach više nema
granicu od 700 px i ne pita širinu prozora. Sekcije stoje jedna ispod druge,
a ono što je u njima teče u kolone koliko ih stane.

**Vlasnik je 21.9.2026 pogledao Teach u širokom prozoru i na telefonu i
potvrdio raspored, uključujući Library odmah ispod Homework (tačke 1 i 4).**
Tačke 2 (slanje zahteva i „Progress") i 3 (prozor od 900 px) potvrdio je
kasnije istog dana, uz stavku 213 — sve četiri su zatvorene.

1. [x] **Windows, prozor oko 1400 px.** Teach: **Tutorials · Homework ·
   Library u jednom redu**, sve tri kartice istog okvira (donje ivice u
   istoj liniji iako Tutorials ima tri dugmeta). Ispod njih **Preparation ·
   New session** u drugom redu, sa svojim obojenim ivicama.
2. [x] **Studenti.** U kartici „Students and trainers" obrazac za zahtev
   (čipovi, rečenica, email, „Send a request") zauzima **jednu kolonu levo**,
   a spisak ljudi ostatak; učenici idu **jedan pored drugog** kad ih ima više.
   Slanje zahteva i „Progress" rade kao i pre.
3. [x] **Najmanji prozor (900 px).** Isto, samo manje kolona; ništa nije
   odsečeno, nijedno dugme nije van kartice.
4. [x] **Telefon.** Jedna kartica po redu, obrazac iznad spiska kao do sada.
   **Jedina promena redosleda:** Library je sada odmah ispod Homework, a ne
   posle Preparation / New session — uz stvari koje čuva. *Ako ti se ne
   dopada, vraća se u jednom redu koda.*

## 211. Puzzle sets pripadaju nalogu, ne uredjaju — 21.9.2026, nije viđeno uživo

**Server i aplikacija.** Prijava vlasnika: „Library - Puzzle sets na telefonu
ne prikazuje puzzle uopšte, iako na istom nalogu u windows-u prikazuje."
Setovi su do sada živeli u `SharedPreferences` **onog uredjaja** koji je
pokrenuo „Review entire game" — Windows ih je pokazivao zato što ih je i
napravio.

**Pre provere:** backend mora da se pokrene ponovo (`initDB` pravi tabelu
`puzzle_sets`), i treba nov build za telefon.

1. [ ] **Windows prvo.** Otvori Library → čip „Puzzle sets". Setovi su tu kao
   i pre. *Prvo otvaranje ih tiho prebacuje na server; ništa se ne briše.*
2. [ ] **Pa telefon.** Isti nalog, Library → „Puzzle sets": **sada se vide
   isti setovi**. Kucni jedan — otvara se u Analizi (to je stavka 207 A).
3. [ ] **Novi set sa telefona.** U Analizi na telefonu uradi „Review entire
   game" nad nekom partijom. Set se pojavi i **na Windows-u** posle osvežavanja.
4. [ ] **Brisanje važi svuda.** Obriši set u „Saved puzzles" na jednom
   uredjaju; posle osvežavanja ga nema ni na drugom.
5. [ ] **Bez servera se ne gubi ništa.** Ugasi backend pa otvori „Puzzle sets"
   na Windows-u: setovi tog uredjaja se i dalje vide. *Nedostupan server ne
   sme da se pročita kao „nalog je prazan".*
6. [ ] **Ne duplira se.** Otvori i zatvori Library nekoliko puta, na oba
   uredjaja: broj setova ostaje isti. *Dizanje na server ide upsert-om baš
   zbog ovoga.*
7. [ ] **Stari setovi su preživeli.** Nijedan set koji si imao na Windows-u
   pre ove izmene nije nestao.

**Zamenjeno 23.9.2026** (`PLAN-MATERIJAL.md`, faza 4): puzzle sets su obrisani — tabela, rute, kopija na uređaju, čip i „puzzle mode" u Analizi, na vlasnikovo da (5 setova, 25 zagonetki). Zagonetke iz „Review entire game" su sada zadaci iz „mistakes"; proverava se u stavci 234.

## 210. „Choose a game" kao prava tabela — 21.9.2026, nije viđeno uživo

Samo aplikacija, faza 7 plana `PLAN-LISTE.md` — tražio je vlasnik pošto su mu
„sirovi tekst i kartice i dalje boli oči". Time je plan odgradjen u celosti.

Otvara se iz Analize → „Choose a game" (ili gde god se bira partija iz
kolekcije).

1. [ ] **Windows: tabela, ne kartice.** Zaglavlje sa pet kolona — **White ·
   Black · Date · Result · First moves** — i ispod njega vrste visoke oko 38
   px. Nema kartica, nema dve linije po partiji.
2. [ ] **Kolone se poklapaju.** Ime belog stoji tačno ispod „White", datum
   ispod „Date" i tako redom, na svakoj vrsti.
3. [ ] **Vidi se mnogo više partija nego ranije.** Prebroj grubo: treba da ih
   stane bar dvostruko više nego pre (bilo je oko osam).
4. [ ] **Potezi bez satova.** U koloni „First moves" piše `1. e4 c5 2. Nf3…`,
   **nigde** `{ [%clk 0:03:00] }`. *Ovo je popravljeno u fazi 1b, koju još
   nisi video — build koji si testirao 20.9. je stariji od nje.*
5. [ ] **Filter po rezultatu.** Ispod pretrage stoje čipovi **All · 1-0 · ½-½
   · 0-1**. Pritisni „1-0" — ostaju samo partije koje je beli dobio.
6. [ ] **Filter i pretraga rade zajedno.** Upiši ime u pretragu pa pritisni
   čip: lista se suzi po **oba**, ne samo po čipu. Isključi čip („All") —
   vraća se ono što pretraga daje.
7. [ ] **Brojač u naslovu prati.** „… — N of 4126" se menja i sa pretragom i
   sa čipom.
8. [ ] **Klik na vrstu bira partiju** i dijalog se zatvara. Nema posebnog
   dugmeta „Izaberi" u vrsti — cela vrsta je meta, namerno.
9. [ ] **Telefon.** Umesto tabele dve zbijene linije po partiji: „Beli vs
   Crni" sa rezultatom desno, pa „datum · prvi potezi". Pretraga i čipovi su
   tu isto. Ništa nije odsečeno.
10. [ ] **Dijalog je veći nego pre** na širokom prozoru (do 900 px širine),
    ali ne preko celog ekrana.
11. [ ] **Telefon na boku.** *Ovo si prijavio 21.9.2026: „ne vidi se lista
    partija, nije skrolabilno" — izmereno, lista je bila **0 px visoka**.*
    Okreni telefon i otvori „Choose a game": vidi se **bar tri-četiri**
    partije, lista se skroluje, i „Cancel" je na ekranu. Pretraga i čipovi
    filtera stoje **u istom redu**, ne jedan ispod drugog — tako ostane mesta
    za same partije.

## 209. Repertoar sa oknom pored liste — 20.9.2026, nije viđeno uživo

Samo aplikacija, faza 6 plana `PLAN-LISTE.md` — poslednja gradjena faza tog
plana. Na širokom prozoru se ekran „Repertoire" deli: lista levo, okno desno.

**Jedna promena ponašanja koju treba pogledati pre svega ostalog.** Na širokom
prozoru kucanje na vrstu **bira** repertoar (crta ga u oknu) umesto da ga
otvori; otvara se dugmetom „Open" u oknu. Na uskom prozoru i na telefonu je
sve kao i do sada — kucanje otvara. Razlog za razliku u odnosu na Biblioteku:
kartica u Biblioteci ima dve mete (tabla i ostatak), pa je tabla postala
„pokaži mi" a kartica je ostala „otvori". Vrsta repertoara ima samo jednu.

**Ako ti se ovo ne svidja, reci — vraća se u jedan potez.**

1. [ ] **Windows, širok prozor.** Practise → Repertoire. Desno stoji okno sa
   rečenicom „Choose a repertoire to see where it starts."
2. [ ] **Kucni vrstu.** U oknu: ime, red sa bojom / „via" potezom / brojem
   poteza, **linija do korena** („1. d4 Nf6 2. c4 c5 3. d5 e6"), tabla te
   pozicije, pa „Open" i „Drill".
3. [ ] **Obeležena je samo jedna vrsta**, i to **okvirom** (ne bojom).
3.1 [ ] **Tabla je cela.** Donji red table (beli top, skakač, lovac…) se vidi
   u celini, nije presečen. *Vlasnikov nalaz sa slike 20.9.2026: tabla je bila
   396 široka a 360 visoka, pa je poslednji red bio nacrtan van nje i tiho
   odsečen — ni test ni release build o tome ne kažu ništa, jer to nije
   prelivanje nego kliještenje. Pogledaj i na širem i na užem prozoru.*
4. [ ] **Tabla je okrenuta ka tvojoj strani.** Za repertoar za crnog crni je
   dole.
5. [ ] **Repertoar bez zapamćene linije** (stariji, ili napravljen iz
   nalepljene pozicije) piše „From the start" umesto izmišljenog otvaranja.
6. [ ] **„Open" otvara** taj repertoar; **„Drill"** pokreće vežbu nad njim.
7. [ ] **Dugi pritisak i dalje bira više njih** za „Drill selected (N)", i
   dok je taj režim uključen kucanje **čekira** umesto da bira za okno.
8. [ ] **Uzak prozor.** Suzi do najmanjeg — kucanje na vrstu opet **otvara**
   repertoar, okna nema.
9. [ ] **Telefon.** Sve kao i pre: jedna kolona, kucanje otvara.
10. [ ] **Ništa se ne učitava iznova.** Biranje raznih repertoara u oknu ne
    sme da pravi pauzu — okno crta iz onoga što je lista već donela, bez
    ijednog novog zahteva ka serveru.

## 208. Biblioteka sa oknom pored police — 20.9.2026, nije viđeno uživo

Samo aplikacija, faza 5 plana `PLAN-LISTE.md`. Na širokom prozoru Biblioteka
se deli: police levo, okno desno. Kucanje na **sličicu table** više ne otvara
dijalog preko liste nego crta tu poziciju u oknu. Na uskom prozoru i u sobi
se ništa ne menja — dijalog kao i do sada.

1. [ ] **Windows, širok prozor.** Teach → Library. Desno stoji okno sa
   rečenicom „Tap a board to see it here." Police su levo i i dalje pune
   kartica.
2. [ ] **Kucni sličicu.** Tabla se pojavi **u oknu**, veća, sa imenom iznad,
   rečenicom ko je na potezu (i zadatkom ako je zadatak) i dugmetom „Open".
   **Dijalog se ne otvara.**
3. [ ] **Kucni drugu sličicu.** Okno pokaže tu drugu. Uvek je obeležena samo
   jedna kartica, **okvirom** (ne bojom).
4. [ ] **Kucni karticu, ne sličicu.** Otvara se sama stvar, kao i pre — okno
   nije promenilo to.
5. [ ] **„Open" u oknu** otvara ono što je u oknu.
6. [ ] **Suzi prozor ispod pola ekrana.** Okno nestaje i kucanje na sličicu
   opet otvara **dijalog**, sa „Close" kao i ranije.
7. [ ] **Soba je netaknuta.** Otvori sobu (STUDIO) na širokom prozoru i u
   koloni „Library" kucni sličicu — otvara se **dijalog**, ne okno.
8. [ ] **Telefon.** Biblioteka kao i pre: jedna kolona, sličica otvara
   dijalog.

**Ovo ispod je popravka greške koja je postojala i ranije** (od faze 3b), a
faza 5 je na nju naletela:

10. [ ] **Sličica na kartici je cela.** Na **Windows-u** pogledaj kartice
    zadataka i pozicija u Biblioteci: mala tabla levo ima sav donji red, nije
    presečena. *Bila je 56 × 48 na desktopu i 56 × 56 na telefonu — odsečena
    otkad postoji, a na telefonu ispravna, pa se nikad nije prijavila. Sada je
    48 × 48 svuda, dakle **malo manja nego pre** na telefonu.*

9. [ ] **Najmanji mogući prozor.** Suzi prozor do kraja — Windows ga ne pušta
   ispod 900 px (`win32_window.cpp`, `ptMinTrackSize`). Na toj širini polica
   drži **jednu karticu preko cele širine** pored okna, i nijedno dugme na
   kartici nije odsečeno.

   *Zašto baš tu:* okno uzima 420, polici ostaje 444. Bez pravila o najmanjoj
   širini kartice mreža bi tu tražila **dve kolone po 216**, a kartica na 216
   preliva svoju visinu za 48 px — i release build to ne crta kao upozorenje
   nego tiho odseče. Greška je postojala od faze 3b, ali je do faze 5 bila
   **nedostižna**: bez okna je polica na 900 px prozoru široka 876 i uvek je
   imala dve pune kolone. Okno ju je probudilo, što je tačno ono što `CLAUDE.md`
   zove „a dormant bug wakes when the feature it depends on ships".

## 207. Tri nalaza vlasnikove provere 20.9.2026 uveče — nije viđeno uživo

Tri stvari nadjene uživo iste večeri, u kodu istu noć. Prva i treća su
aplikacija; druga je i server, pa **backend mora da bude restartovan** pre
provere.

**A. Zagonetke iz Biblioteke se otvaraju.** Prijava: „Library - Puzzle sets.
Klikom na set puzzle se ništa ne dešava." Kartica je stajala na polici i nije
odgovarala ni na šta, jer se u režim zagonetki ulazilo samo kroz dijalog na
ekranu Analize na kom su izvučene.

1. [ ] **Kucni set u Biblioteci.** Teach → Library → čip „Puzzle sets", pa
   kucni karticu. Otvara se Analiza sa **tom** zagonetkom: tabla, a dole
   poruka sa temom („🧩 fork" i slično).
2. [ ] **Baš taj set.** Sa dva ili više setova kucni **drugi po redu** —
   otvara se on, ne najnoviji.
3. [ ] **Skica se ne meša.** Ako si ostavio nezavršenu analizu, otvaranje seta
   je ne vraća preko zagonetke.
4. [ ] **Telefon.** Isto radi u jednoj koloni.
5. [ ] **Prazan set.** Ako ga imaš, kucanje kaže da nema zagonetki umesto da
   otvori prazan ekran.

**B. Brojevi u „What to drill" prate prekidač.** Prijava uz stavku 206 tačka 5:
„očekivao sam da uključivanje/isključivanje online partija menja brojeve, ali
ne menja brojeve." Nije bio samo mrtav prekidač — katalog je brojao **i online
partije**, a sam trening ih po podrazumevanom podešavanju **ne servira**, pa je
ukupan broj bio veći od onoga što se može dobiti.

**Zamenjeno 23.9.2026** (`PLAN-MATERIJAL.md`, faza 4): tačke 1–5 više nemaju šta da provere — puzzle sets su obrisani, na vlasnikovo da. Zagonetke iz „Review entire game" su sada zadaci; proverava se u stavci 234.

6. [ ] **Prekidač pomera broj.** Practise → Endgames → bilo koja kartica.
   Uključi „Include online games": „Selected: N positions" u dnu se **poveća**.
   Isključi: **vrati se** na staro.
7. [ ] **Kvačice preživljavaju.** Skini kvačicu sa jedne porodice, pa okreni
   prekidač: ta porodica je i dalje bez kvačice. Ne vraća se sve na početak.
8. [ ] **Broj je iskren.** Suzi izbor na nešto malo, upamti broj, pritisni
   „Start" i prodji kroz zadatke — ne sme da se desi da trening kaže da nema
   pozicija dok je pisalo da ih ima.
9. [ ] **Nivo i dalje radi** uz uključen prekidač: čip nivoa menja broj.

**C. ☰ u sobi se lakše pogadja.** Prijava: „radi, ali je u takvom delu ekrana,
da jedva odgovara na pritisak". Izmereno: dugme je stajalo 4 px od leve ivice,
a leva ivica telefona položeno je i traka za Androidov gest „nazad".

10. [ ] **Telefon položeno, soba.** Otvori sobu (STUDIO) na telefonu **na
    boku**. ☰ gore levo se pogadja iz prve, više puta zaredom.
11. [ ] **Otvara ono što je otvarao.** Iza njega je i dalje leva kolona sa
    „Library", i kucanje na tutorijal ga stavlja na tablu.
12. [ ] **Uspravno je nepromenjeno.** Isti ekran uspravno: ☰ radi kao i pre.
    *Ovo je jedino od trojeg što nije potvrdjeno merenjem nego pretpostavkom —
    ako i dalje slabo odgovara, uzrok nije mesto nego nešto drugo i traži novu
    dijagnozu.*

## 206. „What to drill" u kolonama — 20.9.2026, nije viđeno uživo

Samo aplikacija, faza 4 plana `PLAN-LISTE.md`. Porodice završnica (topovske,
pešačke, još pet) više ne stoje jedna ispod druge u jednoj koloni nego se
dele po širini prozora. Nivoi i dva prekidača ostaju **jedno zaglavlje preko
cele širine** — to je pitanje postavljeno celom katalogu, ne jednoj koloni.

Ovo **nije** ista mreža kao stavke 204 i 205. Kartica porodice raste kad se
otvori (topovske završnice imaju trinaest oblika), pa ćelije nisu jednake
visine: kolone su obične kolone, a ne tabela. Zbog toga je tačka 3 ovde
najvažnija.

Otvara se iz **Practise → Endgames**, obe kartice („win" i „hold the draw").

1. [ ] **Windows, širok prozor.** Porodice stoje **dve, tri ili četiri u
   redu**, ne jedna preko celog ekrana. Na svakoj: kvačica, ime, red ispod
   („1769 positions, 13 types") i strelica za otvaranje.
2. [ ] **Zaglavlje je i dalje jedno.** „Level" sa čipovima i prekidač
   „Include online games" idu preko cele širine, **iznad** kolona — nisu
   postali jedna od kartica.
3. [ ] **Otvaranje ne pomera susede.** Otvori topovske završnice (trinaest
   oblika). Porodica koja stoji **desno od nje** ostaje tamo gde je bila,
   ne skače naniže. Otvori još jednu u drugoj koloni — isto.
4. [ ] **Ništa nije odsečeno.** Sa otvorenom najvećom porodicom suzi prozor
   u koracima do telefonske širine: broj kolona pada sam, nigde žuto-crnih
   traka i nijedna kvačica nije nedostupna. *U release gradnji nema
   upozorenja o prelivanju — seče se tiho, zato je ovo pogled a ne test.*
5. [ ] **Brojevi se i dalje slažu.** Skidanje kvačice sa jedne porodice
   menja „Selected: N positions" u dnu; čip nivoa isto. „Start" je siv kad
   je sve skinuto.
6. [ ] **Telefon.** Jedna porodica u redu, kao i pre. Otvaranje topovskih
   završnica se skroluje normalno i ništa se ne preliva.
7. [ ] **Kratak prozor.** Na Windowsu smanji **visinu** prozora na otprilike
   pola pa otvori najveću porodicu: lista se skroluje, ništa se ne seče.

## 205. Biblioteka u karticama — 20.9.2026, nije viđeno uživo

Samo aplikacija, faza 3b plana `PLAN-LISTE.md`. `LibraryList` više nije
`ListView` sa vrstama nego mreža kartica, a crta se na **dva mesta**: ekran
Biblioteke (Teach → Library) i **uska leva kolona u sobi**. Kolona je 300 px i
po konstrukciji ostaje jedna kartica u redu — ali baš zato je treba pogledati.

1. [ ] **Windows, Biblioteka na širokom prozoru.** Stoje **tri ili četiri
   kartice u redu**, ne jedna preko celog ekrana. Na kartici: sličica table
   ili ikonica, naslov, red ispod njega („6 parts · video", „Mat u 333",
   „saved position"…) i dugmad te vrste.
2. [ ] **Suzi prozor.** Broj kolona pada sam — 4, 3, 2, pa 1. Nigde
   žuto-crnih traka i nijedno dugme nije odsečeno.
3. [ ] **Dugmad su na svojoj kartici.** Kod tutorijala: video, pošalji, kanta
   (i „Download video" gde ga ima); kod zadatka: „Add to tutorial" i „Assign";
   kod pozicije samo „Add to tutorial"; kod analize nijedno. Proveri da nijedno
   dugme ne radi nad **susednom** karticom.
4. [ ] **Kartica nije prazna iznutra.** Sadržaj stoji uz vrh kartice; prazan
   prostor je ispod, ne između naslova i dugmadi. *Kartice su iste visine — to
   je mreža; ali kartica sa manje dugmadi ne sme da razvuče svoj sadržaj.*
5. [ ] **Sličica table i pregled.** Kod zadatka i pozicije kartica vodi
   sličicom. Kucni **sličicu** — otvara se pregled table. Kucni bilo gde drugde
   na kartici — otvara se sama stvar. Dve različite radnje na istoj kartici,
   a kartica je veća meta nego stara vrsta.
6. [ ] **Čipovi, pretraga i etikete i dalje stoje iznad mreže**, i sužavaju
   je: „Exercises", pa „Win", pa upisana reč.
7. [ ] **Telefon, Biblioteka.** Jedna kolona, kao i pre. Kartica nije odsečena
   ni previsoka; dugmad stoje ispod naslova i mogu se pritisnuti.
8. [ ] **Soba, leva kolona.** Otvori sobu (STUDIO) i pogledaj kolonu
   „Library": **jedna kartica u redu**, kolona se i dalje skroluje kao celina
   sa ostatkom sidebara, i kucanje na tutorijal ga i dalje stavlja na tablu.
9. [ ] **Prazna polica.** Bez ijedne stvari piše rečenica, a ne prazna kutija.

## 204. Mreža na domaćim zadacima i sačuvanim zagonetkama — 20.9.2026, nije viđeno uživo

Samo aplikacija. Prve dve liste koje koriste širinu umesto da je troše:
spisak domaćih zadataka (Teach → Homework) i „Saved puzzles" (Analysis).
Telefon ostaje isti — jedna kolona, po konstrukciji.

1. [ ] **Windows, spisak domaćih.** Na širokom prozoru stoje **dve ili tri
   kartice u redu**, ne jedna preko celog ekrana. Naslov, „N items", i „sent
   to M" gde je slato.
2. [ ] **Dugmad na kartici rade.** „Pošalji" otvara izbor učenika; kanta pita
   pre brisanja i piše šta brisanje **ne** dira.
3. [ ] **Suzi prozor.** Kako se prozor sužava, broj kolona pada sam — 3, pa 2,
   pa 1. Nigde žuto-crne trake.
4. [ ] **Telefon, spisak domaćih.** Jedna kolona, kao i pre. Kartica nije
   odsečena ni previsoka.
5. [ ] **„Saved puzzles" na Windows-u, sa VIŠE skupova.** Dijalog je **širi
   nego pre** i skupovi stoje jedan pored drugog. Naslov, broj zagonetki, kanta
   i „Open".
5.1. [ ] **Sa JEDNIM skupom** dijalog je **uzak** (oko 460), a kartica popunjava
   ceo red — nema prazne kolone pored nje. *Ovo je popravka nalaza od
   20.9.2026: ranije je dijalog uzimao punih 640 i pola je bilo prazno.*
5.2. [ ] **Kartica nije prazna iznutra** — kanta i „Open" stoje odmah ispod
   broja zagonetki, ne odvojeni rupom.
6. [ ] **„Open" otvara baš taj skup** — zagonetke iz tog reda, ne iz nekog
   drugog.
7. [ ] **„Saved puzzles" na telefonu.** *Ovo je popravka greške koja je
   postojala i ranije:* dijalog se prelivao za 1.3 px i to se u release build-u
   ne vidi, samo se odseče. Gledaj da kanta i „Open" **oba** stanu i da se
   mogu pritisnuti.
8. [ ] **Prazan slučaj.** Bez sačuvanih zagonetki dijalog i dalje kaže da ih
   nema, umesto prazne kutije.

---

## 203. Pretraga u „Choose a game" — 20.9.2026, nije viđeno uživo

Samo aplikacija, jedan dijalog. Otvara se kad učitaš ili nalepiš PGN sa **više
partija** — na tabli (Analysis → učitaj `.pgn` ili nalepi tekst) i u Board
Setup. Vlasnikova kolekcija ima 4126 partija, a do sada se videlo oko pet
vrsta odjednom, bez pretrage.

1. [ ] **Dijalog se otvori sa kolekcijom.** Naslov kaže ukupan broj u
   zagradi, a polje za pretragu stoji iznad liste.
2. [ ] **Na Windows-u lista je viša nego pre.** Vidi se osetno više od pet
   vrsta; ako je i dalje niska, to je prijava.
3. [ ] **Pretraga po imenu igrača.** Upiši deo svog protivničkog imena — lista
   se suzi, a naslov kaže „X of 4126".
4. [ ] **Pretraga po potezima.** Upiši npr. `Nf3` ili `1. d4` — nalazi partije
   po otvaranju.
4.1. [ ] **Dva poteza zaredom.** Upiši `e4 c5` — **nalazi** sicilijanke.
   *Ovo je popravka nalaza od 20.9.2026: ranije nije nalazilo ništa, jer je
   između dva poteza stajao `{ [%clk 0:03:00] }`.*
4.2. [ ] **Sa brojem ili bez.** `1. e4 c5` i `e4 c5` daju **isti** rezultat.
4.3. [ ] **Podnaslov vrste pokazuje poteze, ne satove.** Treba da piše
   `1. e4 c5 2. Nf3 d6 3. d4 …`, bez `{ [%clk …] }` — oko osam poteza umesto
   dva.
5. [ ] **Pretraga po datumu ili rezultatu ne radi, i to je namerno.** Upiši
   godinu ili „1-0": lista se **ne** suzi po tome. Traže se samo dva imena i
   potezi — inače bi kucanje datuma tiho premeštalo listu.
6. [ ] **Ništa ne odgovara.** Upiši besmislicu — piše rečenica da nema
   partije, a ne prazna kutija.
7. [ ] **Izbor partije radi kao i pre.** Klik na vrstu zatvori dijalog i
   učita partiju — i na tabli i u Board Setup (gde tekst upadne u polje).
8. [ ] **Telefon.** Isti dijalog na 360 dp: ništa ne izlazi iz ekrana, polje
   za pretragu se vidi, tastatura ne pojede listu.
9. [ ] **Podnaslov vrste.** Potezi ispod imena više ne staju usred poteza
   (npr. `2. N...`), nego se prekidaju na razmaku.
10. [ ] **Nalepi PGN sa varijantama** (iz Analysis, „Setup Position / PGN") —
   u podnaslovu stoji samo glavna linija, bez poteza iz zagrada.

---

## 202. Spajanje tutorijala i izdvajanje delova — 20.9.2026, nije viđeno uživo

Samo aplikacija. Dva nova ulaza, oba **kopiraju** — izvorni tutorijal uvek
ostaje ceo. Na Windows-u su pod malom ikonom (dve strelice) desno od naslova
„Tutorial contents"; na telefonu su u meniju „More" gore desno.

1. [ ] **Windows, ikona se vidi i otvara se.** Desno od „Tutorial contents"
   stoji ikona; klik nudi „Add parts from a tutorial…" i „Take parts into a new
   tutorial…". Meta je namerno mala (20 x 20) — ako je premala za rad, to je
   prijava, ne greška: znači da panel treba preurediti.
2. [ ] **Prozor oko 840 x 800.** Panel se i dalje vidi ceo, bez žuto-crnih
   traka, a u gornjoj traci „Preview tutorial" je **i dalje ispisano rečima**.
3. [ ] **Dodavanje delova.** Novi tutorijal (bez imena) → „Add parts from a
   tutorial…" → izaberi neki svoj tutorijal → svi delovi su čekirani → „Add".
   Prazan prvi deo **nestaje**, delovi su na njegovom mestu, i poruka kaže
   koliko ih je došlo.
4. [ ] **Isto, ali u tutorijal koji već ima delove**: novi se dodaju **na kraj**,
   a ekran stoji na prvom pridošlom.
5. [ ] **Imenovan pa prazan.** Upiši ime tutorijala, ne diraj tablu, pa dodaj
   delove: prazan „Part 1" i tada nestaje, ime ostaje tvoje.
6. [ ] **Izvor ostaje ceo.** Otvori tutorijal iz koga su delovi uzeti — svi su
   tamo, nijedan nije nestao.
7. [ ] **Spajanje dva u treći.** Nov tutorijal → „Add parts…" iz A → „Add
   parts…" iz B → „Save tutorial". Redosled je A pa B, kako su dodavani.
8. [ ] **Izdvajanje.** „Take parts into a new tutorial…" → odčekiraj neke →
   upiši ime → „Create". Poruka kaže da je sačuvan i koliko delova ima, sa
   dugmetom „Open". Ekran **ne skače** — ostaješ u tutorijalu koji pišeš.
9. [ ] **„Open" iz te poruke** otvara nov tutorijal u studiju; izlazak iz njega
   vraća na onaj koji si pisao, nedirnut.
10. [ ] **Dugme je nedostupno dok nema imena** i dok nije čekiran nijedan deo.
11. [ ] **Novi tutorijal nasleđuje jezik i oznake** izvornog (Library ga nalazi
    po istim oznakama), ali **ne i opis**.
12. [ ] **Telefon.** „More" → oba ulaza su tu i rade isto. Lista delova u
    dijalogu se skroluje ako ih je mnogo.
13. [ ] **Isti tutorijal.** „Add parts…" pa izaberi tutorijal koji upravo
    uređuješ: kaže da je to taj i upućuje na „Clone part".

## 201. Preparation čuva liniju i izvozi je u PGN — 20.9.2026, nije viđeno uživo

Samo aplikacija. Panel „Board" u sobi (Preparation) ima sada četiri reda umesto
šest: „Set up position", pa par „Import PGN | Export PGN", pa par „Save position |
Save analysis", pa „Make exercise". Uparivanje nije ukras — dva dodatna reda su
listu tutorijala ispod gurnula ispod donje ivice prozora 1200 x 800.

1. [ ] **Windows, prozor oko 1200 x 800.** Otvoriti Preparation: vide se sva
   četiri reda **i** lista tutorijala ispod njih, bez skrolovanja panela.
   Natpisi na uparenim dugmadima nisu odsečeni (ovo release gradnja ne prijavljuje).
2. [ ] **Telefon.** Isti panel je u fioci (ikona gore levo): oba nova dugmeta se
   vide i natpisi se ne prelamaju.
3. [ ] **Export PGN, prazna tabla.** Bez ijednog poteza: crvena poruka „There are
   no moves on this board to export yet.", dijalog se ne otvara.
4. [ ] **Export PGN, odigrana linija sa varijantom.** Odigrati liniju, napraviti
   bar jednu varijantu i napisati komentar uz neki potez. „Export PGN" otvara
   poznati dijalog: tekst je već na klipbordu, u njemu su i glavna linija i
   varijanta i komentar, a gore stoji zaglavlje `[Event "Preparation"]`.
5. [ ] **Sačuvati kao fajl.** „Save as .pgn" nudi ime oblika
   `preparation-2026-09-20.pgn`. Otvoriti sačuvani fajl u Lichess uvozu (ili
   ponovo u aplikaciji, „Import PGN") — linija je cela, sa varijantom.
6. [ ] **Save analysis, prazna tabla.** Crvena poruka „There are no moves on this
   board yet…", i **ne** pita za ime. (Ime koje se traži pa se posle odbije je
   gore nego odmah rečeno „nema šta da se čuva".)
7. [ ] **Save analysis, odigrana linija.** Traži naslov (ponuđen je „Analysis
   20.9.2026"), pa „Analysis … saved."
8. [ ] **Otvoriti sačuvano.** Analyse tab → ikona oblaka („Saved analyses") →
   red sa tim naslovom → otvara se **cela** linija sa varijantama i komentarima,
   ne samo početna pozicija. Isto i u Library, red vrste „analyses".
9. [ ] **Postavljena pozicija, ne od početka.** „Set up position" (ili zalepljen
   FEN), pa nekoliko poteza, pa „Save analysis" i otvaranje: tabla je ta
   postavljena pozicija, a potezi su na njoj. Isto i u izvezenom PGN-u
   (`[SetUp "1"]` i `[FEN …]`).
10. [ ] **Soba sa učenikom, ne samo Preparation.** Ista dva dugmeta stoje i u
    živoj sobi kod trenera (isti panel) — proveriti da rade i da učenik taj
    panel nema.

## 200. Motor koji ne odgovara kaže to na ekranu — 20.9.2026, nije viđeno uživo

Samo aplikacija. Posle popravke iz stavke 199 kvar se više ne dobija izlaskom na
Back, pa je ovo teško izazvati namerno — tačke 1 i 2 su kontrola da poruka **ne**
iskače kad je sve u redu.

1. [ ] Normalan rad (Analysis, Preparation, partija protiv motora, „Play it out"):
   crvena poruka o motoru se **ne** pojavljuje, ni pri brzom prelistavanju poteza.
2. [ ] Prelazak u drugu aplikaciju i nazad, i Back pa ponovno otvaranje: bez poruke.
3. [ ] Ako motor ikad zaćuti (nema evaluacije): na ekranu piše „The engine is not
   answering. Close the app completely and open it again." — jednom, ne na svakih
   par sekundi; posle potpunog zatvaranja aplikacije motor radi.
4. [ ] Ako motor stane (u logu „Stockfish is not ready"): piše „The engine has
   stopped. Leave this screen and open it again.", i izlazak sa ekrana pa povratak
   pokreće novi motor.

## 199. Motor na telefonu posle izlaska iz aplikacije — 20.9.2026, nije viđeno uživo

**Tačke 3 i 6 viđene uživo 20.9.2026 — vlasnik, telefon, log u 10:10: posle Back i
ponovnog otvaranja `uciok` i `readyok` stižu za sekundu, pretraga ide do dubine 43.**

Prijava od 20.9.2026 (Preparation bez evaluacije; u logu posle „Stockfish 18 by…"
motor ne ispisuje više ništa). Samo aplikacija. Uzrok je pročitan iz koda, nije
reprodukovan — prve dve tačke ga potvrđuju ili obaraju.

1. [ ] **Na starom buildu** (pre ove izmene): uključi motor na bilo kom ekranu, izađi
   iz aplikacije dugmetom **Back** sa početnog ekrana, otvori je ponovo → motor
   ćuti (nema evaluacije).
2. [ ] Na istom buildu: Settings → Apps → **Force stop**, pa otvori → motor radi.
3. [x] **Na novom buildu**: ponovi tačku 1 → motor radi i posle povratka.
4. [ ] Posle domaćeg sa partijom protiv motora („Play it out"), pa Back i ponovo
   otvaranje: evaluacija na Preparation i u Analizi se pojavljuje.
6. [x] **Drugi nalaz, isti dan** (log u 09:50: „Stockfish is not ready (StockfishState.disposed)"):
   posle Back i ponovnog otvaranja motor **ne** izlazi odmah — u logu posle `uci` stiže
   `uciok`. Prvo otvaranje posle instalacije može još jednom da zatekne zaostali `quit`
   starog builda; tada izlazak sa ekrana i povratak pokreće novi motor
   („The engine has exited … Starting a new one").
5. [ ] Prelazak u drugu aplikaciju i nazad (bez izlaska) ne gasi motor — evaluacija
   se nastavlja bez ponovnog pokretanja.

## 198. Mašinerija za više poteza je obrisana: „Find" je svuda jedan potez — 20.9.2026, nije viđeno uživo

`docs/PLAN-EXERCISE.md`, faza 16. **I server i aplikacija moraju da budu novi** —
žica pokušaja se promenila (`moveSan`, a ne spisak poteza), pa stara aplikacija
na novom serveru dobija 400. Jedini stari zadatak sa linijom
(`ex_69822c23d741397c`, K+D protiv K, šest poteza) obrisan je iz baze uz
vlasnikovo „da".

1. [ ] **Učenik**, „Find the move" zadatak u domaćem: tačan potez ostaje na tabli i
   piše „Correct"; prihvaćena alternativa je takođe tačna.
2. [ ] Pogrešan potez se vraća, prikazuje se rešenje, i tabla više ne prima potez —
   nema „Try again", nema „Keep going".
3. [ ] **Trener**, Library → Exercises → sačuvan „Find" zadatak: ispod naslova piše
   odgovor kao „Qh5 (or Qf3)" — bez rednog broja i bez čipova za korake.
4. [ ] Potez odigran na toj tabli postaje alternativa, „x" na čipu je uklanja,
   glavni potez nema „x"; „Save" šalje izmenu i lista je pokazuje.
5. [ ] „Make exercise" → „Find the move" → „Play the move" radi kao u stavci 196.
6. [ ] Pregled domaćeg (trener i učenik posle odgovora) prikazuje rešenje kao i pre.

## 197. „Play N moves": partija bez cilja, sudija je trener — 20.9.2026, nije viđeno uživo

**Viđeno uživo 20.9.2026 — vlasnik, sve tačke „ok“ u QA dnevniku.**

`docs/PLAN-EXERCISE.md`, faza 15. **Server mora da bude restartovan** — pri
pokretanju `initDB` proširuje dozvoljene vrednosti kolone `judged_by` rečju
`trainer` (menja se samo ograničenje, nijedan red).

1. [x] **Pravljenje**: „Make exercise" → četvrti čip **„Play N moves"**. Pita „How
   many moves?" sa poljem za broj (nema „To the end of the game"), stranu učenika
   i jačinu motora; ispod piše „No automatic verdict: you look at the game
   afterwards and judge it." „Save" je sivo dok nema imena, strane i čitljivog
   broja. Ne pojavljuje se „Checking…".
2. [x] Zadatak je u biblioteci pod „Exercises" kao „Play 12 moves as White", filter
   „Play N moves" ga nalazi, i može da se doda u domaći.
3. [x] **Učenik**: red u domaćem glasi „Play it out: play 12 moves"; nad tablom
   „You are White — play 12 moves · 12 left" i broj opada; posle dvanaestog svog
   poteza partija staje, dijalog kaže „Not judged yet" i „The game ended: 12 moves
   played. Your trainer will look at it." — peščani sat, ne zastavica.
4. [x] U domaćem kod učenika ta stavka je urađena (sledeća se otključava ako je
   bila zaključana), a piše da čeka ocenu — ne „Goal not met".
5. [x] **Trener**, pregled te stavke: „Play 12 moves as White", „Not judged yet",
   rečenica „This game has no goal — how it was played is yours to judge.", dugme
   „Open in Analysis" (stavka 195) i dva dugmeta **„Mark as met"** (pehar) i
   **„Mark as not met"** (zastavica). Nigde na kartici ne piše „Goal met" dok se
   ne oceni.
6. [x] „Mark as met" → kartica kaže „Goal met" i „Judged by the trainer"; dugmad
   ostaju, i „Mark as not met" menja ocenu. U domaćem sada piše „Goal met" /
   „Goal not met" kod obe strane.
7. [x] **Učenik** na istom pregledu: pre ocene „Your trainer will look at this
   game.", bez dugmadi; posle ocene vidi ocenu i „Judged by the trainer".
8. [x] Partija koju su ocenila pravila ili tablebase (npr. „Checkmate in 2 moves")
   **nema** ta dva dugmeta.
9. [x] Ako se nađe „Draw or better, for N moves" partija na koju tablebase nije
   odgovorio („No tablebase answer yet…"), i ona sada ima oba dugmeta — trener
   kao sudija poslednje instance.
10. [x] Na telefonu, uspravno: oba dugmeta i „Open in Analysis" se vide cela.

## 196. „Find the move" je jedan potez, i igra se na ekranu zadatka — 20.9.2026, nije viđeno uživo

**Viđeno uživo 20.9.2026 — vlasnik, sve tačke „ok“ u QA dnevniku.**

`docs/PLAN-EXERCISE.md`, faza 14. **Server mora da bude restartovan** (novo
pravilo pri čuvanju zadatka).

1. [x] **Prazna tabla u sobi** (postavi poziciju, ne igraj ništa) → „Make
   exercise": umesto crvene rečenice stoji objašnjenje i dugme **„Play the
   move"**. Pod „Win" i „Draw or better" tog dugmeta nema.
2. [x] „Play the move" otvara ekran „New exercise" sa tom pozicijom, tabla je
   okrenuta na stranu koja je na potezu, „Save" je sivo dok se ništa ne odigra.
3. [x] Prvi odigran potez je rešenje, svaki sledeći je prihvaćena alternativa
   (piše „1. Qf7# (or Qa8#, Qa7)"); tabla se posle svakog poteza vraća na
   početnu poziciju. Alternativa se skida krstićem, **„Start over"** briše sve.
4. [x] „Save" → isti list kao i do sada (ime, instrukcija, oznake; samo čip „Find
   the move"), „Save" → sve se zatvara, u sobi piše „Exercise saved.", zadatak
   je u biblioteci pod „Exercises" i može da se pošalje i reši.
5. [x] Izlazak sa ekrana posle odigranog a nesačuvanog poteza pita „Discard the
   unsaved change?".
6. [x] **Potez već odigran u sobi** (sa varijantom na istom potezu) → „Make
   exercise" ga čita kao i pre: rešenje + alternativa, bez odlaska na drugi
   ekran. Ako je u sobi odigrano više od jednog poteza, list kaže „Only the
   first move is asked. The moves after it are not used." i čuva samo prvi.
7. [x] Uspravno i položeno na telefonu: ništa nije odsečeno na ekranu „New
   exercise".
8. [x] Stari zadatak sa **više poteza** i dalje se otvara i rešava kao pre (ništa
   mu nije dirano); pokušaj da se takav sačuva iz editora server odbija
   rečenicom „A find exercise asks for one move…". To je očekivano — ti zadaci
   se brišu u fazi 16.

## 195. Odigrana partija iz domaćeg se otvara u Analizi sa potezima — 20.9.2026, nije viđeno uživo

**Tačke 1–5 viđene uživo 20.9.2026 — vlasnik, QA dnevnik; tačka 6 je još bez odgovora.**

`docs/PLAN-EXERCISE.md`, faza 13. Samo aplikacija — server se ne dira i ne mora
da se restartuje. Treba jedan domaći sa „Play it out" stavkom koju je učenik
odigrao (bar dva-tri poteza).

1. [x] **Trener**, pregled tog domaćeg: na kartici partije, pored „Comment", stoji
   **„Open in Analysis"**. Otvara Analizu sa **celom partijom** — stoji se na
   poslednjem potezu, strelicama se ide unazad do početne pozicije, tabla je
   okrenuta na stranu koju je učenik igrao, i motor može da se uključi.
2. [x] Na telefonu (uspravno) oba dugmeta na kartici se vide cela; ako ne stanu u
   jedan red, prelaze u dva — ništa nije odsečeno.
3. [x] **Učenik**, isti pregled: ima isto dugme i dobija istu partiju.
4. [x] **Učenik, na samom ekranu partije**: dok igra, vrata u Analizu nema (stavka
   193); kad se partija završi i dijalog zatvori, dugme za Analizu otvara **partiju
   sa potezima**, a ne samo poziciju na kojoj je stala.
5. [x] Kartica partije koja **nije odigrana** nema dugme „Open in Analysis".
6. [ ] Kontrola: arhiva grešaka → „otvori partiju u Analizi" radi kao i pre (deli
   ista vrata).

## 194. Ručni zadatak se otvara na tabli, i ko je na potezu — 20.9.2026, nije viđeno uživo

**Server mora da bude restartovan.** Bez ponovnog slanja — isti zadaci koji su se
otvarali na „Assignment complete".

1. [ ] **Učenik**: zadatak „Daj mat u jednom ili 2 poteza" poslat direktno otvara
   tablu sa pozicijom; `Qf7#` je tačno, a i `Qa7` se priznaje.
2. [ ] Isti zadatak **unutar domaćeg** („Daj mat u 1 ili 2 poteza") otvara tablu.
3. [ ] **Trener**, Teach → učenik → taj zadatak: ne piše „Assignment complete" dok
   učenik nije ništa odigrao.
4. [ ] **„Play it out", učenik je crni a beli je na potezu**: iznad table piše „The
   engine is thinking…" sa peščanim satom dok motor ne odigra, pa „Your move" sa
   rukom. Uspravno i položeno.
5. [ ] Posle kraja partije taj red nestaje.

## 193. Zadatak: u stavci domaćeg nema motora, Analize ni FEN-a — 19.9.2026, nije viđeno uživo

`PLAN-EXERCISE.md`, faza 12. Samo aplikacija — server ne mora da se restartuje.
Kao **učenik**, sa domaćim koji ima „Play it out", pozicije i tutorijal.

1. [ ] **„Play it out" iz domaćeg**, uspravno i položeno: nigde nema dugmeta
   „Analysis", nema panela motora, a u meniju table nema prekidača za strelice
   motora.
2. [ ] Ista partija **van domaćeg** (Practise) i dalje ima sve to.
3. [ ] Windows, **desni klik na tablu** u stavci sa pozicijama i u tutorijalu iz
   domaćeg: ništa se ne kopira, ne piše „FEN copied."
4. [ ] Windows, **Ctrl+C** u bilo kojoj stavci domaćeg: u clipboard-u nije FEN.
5. [ ] Slobodna taktika i Analiza: desni klik i Ctrl+C kopiraju FEN kao i do sada.
6. [ ] **Čim je partija iz domaćeg završena** (mat, remi, predaja): dugme „Analysis",
   panel motora i prekidač strelica motora su se vratili, na istom ekranu.
7. [ ] **Pozicija na koju je odgovoreno** i **rešen zadati taktički zadatak**: desni
   klik ponovo kopira FEN. Dva pogrešna pokušaja još uvek ne otvaraju ništa.
8. [ ] **Tutorijal iz domaćeg**: na koraku koji samo pokazuje, a posle kog dolazi
   pitanje, FEN se ne kopira; posle poslednjeg tačnog odgovora (ili „Show me")
   kopira se. Već predat tutorijal kopira od početka.

## 192. Zadatak: otvaranje i izmena sačuvanog zadatka — 19.9.2026, nije viđeno uživo

`PLAN-EXERCISE.md`, faza 11. Samo aplikacija — server ne mora da se restartuje.

1. [ ] **Library → „Exercises" → pritisak na svoj „Find the move" zadatak** otvara
   ekran zadatka, a ne Analizu: ime, zadatak rečima, tabla okrenuta na učenikovu
   stranu i rešenje kao linija („1. Qh5 (or Qf3) g6  2. Qxe5+").
2. [ ] **Potez odigran na tabli** na izabranom koraku pojavljuje se u liniji kao
   „(or …)". Isti potez drugi put, ili potez koji pozicija ne dozvoljava, ne menja
   ništa; za prvi piše zašto.
3. [ ] Izbor **drugog koraka** linije pomera tablu na poziciju koju učenik tamo vidi,
   i potez odigran tu postaje alternativa na tom koraku, ne na prvom.
4. [ ] Alternativa ima dugme za uklanjanje; **glavni potez ga nema**.
5. [ ] **Save** otvara list „Edit exercise" sa već upisanim imenom, uputstvom i
   oznakama; nema čipova „Win" / „Draw or better". Posle „Save" zadatak u Library
   nosi novo ime, a ponovo otvoren pokazuje dodate alternative.
6. [ ] **Učenik** kome je taj zadatak već poslat u domaćem: dodata alternativa mu se
   sada priznaje kao tačan potez.
7. [ ] **Skenirani zadatak sa odštampanim rešenjem** otvara se i menja na isti način.
8. [ ] **Partija („Win" / „Draw or better")**: ekran pokazuje tablu, „Save" otvara list
   sa već izabranim ciljem, brojem poteza, stranom i jačinom; nema čipa „Find the move".
9. [ ] **Zadatak mog trenera** i **sken bez rešenja** otvaraju se kao do sada (Analiza).
10. [ ] Izlazak sa ekrana sa nesačuvanom izmenom prvo pita; bez izmene ne pita.
11. [ ] **Preparation → Make exercise**, „Find the move" sa odigranom linijom: ispod
    rešenja piše da je varijanta na učenikovom potezu prihvaćena alternativa.
12. [ ] Telefon, uspravno i položeno: ništa nije odsečeno, „Save" se može dohvatiti.

## 191. Zadatak: „Exercises" i birač za domaći prikazuju samo zadatke — 19.9.2026, nije viđeno uživo

`PLAN-EXERCISE.md`, faza 10. Samo aplikacija — server ne mora da se restartuje.

1. [ ] **Library → „Exercises"**: skenirane pozicije **bez rešenja** više nisu tu;
   ostaju skenovi koji imaju odštampano rešenje, zadaci napravljeni u Preparation
   i partije („Win", „Draw or better").
2. [ ] **Library → „Positions"**: tu su sada i skenovi bez rešenja; red kaže knjigu i
   stranu, a **ne** „Find the move".
3. [ ] **Domaći → Add → exercises**: u dijalogu više nema redova „has no solution, so
   an answer cannot be judged" — nude se samo zadaci.
4. [ ] Zadatak označen „needs review" se i dalje vidi u tom dijalogu, siv, sa
   razlogom „is marked for review".

## 190. Zadatak: šta trener vidi od odigrane partije — 19.9.2026, nije viđeno uživo

`PLAN-EXERCISE.md`, faza 9. Server mora da bude restartovan. Potreban je domaći sa
bar dve stavke „Play it out", koji su uradila dva učenika — jedan dobro, drugi loše.

1. [ ] **Trener, otvoren domaći učenika koji je sve uradio dobro**: ispod naslova
   svake odigrane partije piše „Goal met" sa ikonom pehara; kod učenika koji nije
   uspeo piše „Goal not met" sa ikonom zastavice. Dva učenika se više ne čitaju isto.
2. [ ] Stavka sa pozicijama pokazuje „N of M correct"; tutorijal ne pokazuje ništa.
3. [ ] **Pritisak po sredini reda odigrane partije (kao trener)** otvara pregled
   partije, a ne Analizu ni tablu za igru.
4. [ ] U pregledu: zadatak rečima („Checkmate in N moves as White"), presuda,
   potezi koje je učenik odigrao („1. … 2. …"), dve table — „Start" i „Position
   reached" — okrenute na stranu koju je učenik igrao, „Ended: …" i „Judged by …".
   Nigde ne piše „board not available", „viewed" ni „correct 0".
5. [ ] „Draw or better, for N moves" sa **više od sedam figura**: uz „Goal met" piše
   da je provereno samo da učenik nije matiran i da je pozicija tvoja da je oceniš.
6. [ ] **Učenik** na svom domaćem vidi iste presude, i svoj pregled partije.
7. [ ] Pregled partije na telefonu, uspravno i položeno: ništa nije odsečeno.

## 189. Zadatak: „Checkmate in N moves", zadatak koji se vidi, i „3 of 3 items" — 19.9.2026, nije viđeno uživo

Iz vlasnikove provere 19.9.2026 (`PLAN-EXERCISE.md` §9, faza 8). Server mora da
bude restartovan. **Domaći poslat pre ove izmene zadržava stari naslov stavke**
(„Play it out: win it") — naslov se piše pri slanju, pa za tačke 2–4 napravi i
pošalji nov.

1. [ ] **Preparation → „Make exercise" → „Win"**: drugi čip pod „How long?" glasi
   „Checkmate in N moves", a ispod piše da se cilj ispunjava samo matom u toliko
   učenikovih poteza. Pod „Draw or better" isti čip i dalje glasi „For N moves".
2. [ ] Sa **punom tablom** (više od sedam figura) „Win" + „Checkmate in N moves" se
   čuva — ranije je „Save" bio ugašen.
3. [ ] **Učenik, lista stavki domaćeg**: stavka sa brojem glasi „Play it out:
   checkmate in N moves", a stavka bez broja „Play it out: win it" — dve različite
   stavke se više ne čitaju isto. Iznad piše „0 of 3 items", ne „0 of 0 items".
4. [ ] **Učenik, tabla**: traka iznad table kaže „You are White — checkmate in N
   moves · K left" i K opada posle svakog učenikovog poteza.
5. [ ] Namerno prekorači broj poteza u dobijenoj poziciji (dama i kralj protiv
   kralja): dijalog kaže **„Goal not met"** i „The game ended: no checkmate in N
   moves." — odmah, bez „Not judged yet". Ranije je ovde pisalo „Goal met".
6. [ ] Daj mat **tačno u N-tom potezu**: „Goal met".
7. [ ] „Draw or better, for N moves" radi kao i pre: posle N poteza u nerešenoj
   poziciji „Goal met", a dijalog kaže „you were not beaten in N moves".
8. [ ] **Trener, otvoren domaći**: iznad stavki piše „K of 3 items" sa pravim
   brojevima, isto što i lista domaćih.

## 188. Board Setup: paleta u dva reda i tabla koja staje — ✅ provereno uživo 19.9.2026

Isti dijalog otvaraju tri ekrana: Analyse (pet kartica), Teach → Preparation i
soba (po dve kartica). Prijavljeno uživo 19.9.2026: na Windowsu se do crne dame
i crnog kralja nije moglo doći, a na Androidu u landscape modu tabla nije stala
na ekran.

**Vlasnik je prošao dijalog na Windowsu i na telefonu (uspravno i položeno) i
potvrdio sve stavke ispod istog dana, 19.9.2026.**

Izmereno pre popravke: red palete je uvek bio 848 dp u vodoravnom skrolu, a
dijalog mu daje 728 — poslednja tri polja su bila van ivice; tabla na 932×430
bila je 724×724 u dijalogu visokom 398.

1. [x] **Windows, kartica „Piece Placement".** Sve figure se vide odjednom: šest
   belih u gornjem redu, šest crnih ispod, istim redosledom. Ništa se ne skroluje
   ustranu i crna dama i crni kralj se klikću.
2. [x] **Windows, raspored.** Tabla je levo, paleta i ostalo desno; tabla je
   osetno veća nego ranije (mereno 433 dp umesto 288). Dugme „Generate and Set
   Position" je na dnu i vidi se bez skrolovanja.
3. [x] **Gumica.** „Erase" stoji pored „Clear board" i „Starting position", i
   ostaje upaljena dok je izabrana. Briše figuru na dodir; dugi pritisak i desni
   klik i dalje brišu polje bez nje.
4. [x] **Android, landscape.** Cela tabla staje na ekran, kartice su u jednom
   redu bez ikonica, i dugme na dnu se vidi. Paleta je desno od table.
5. [x] **Android, portret.** Paleta je u dva reda, ispod nje tri mala dugmeta
   samo sa ikonicom (gumica, kanta, restart) — dugi pritisak pokaže ime. Tabla je
   preko cele širine. **Ovo je jedino mesto koje i dalje traži skrolovanje** da
   bi se videla prva vrsta i prava rokade: reci ako smeta, tabla može da se
   smanji da sve stane odjednom.
6. [x] **Imena kartica.** „FEN", „PGN", „Pieces", „Openings", „Online" — svih
   pet u jednom redu, ništa nije preseceno i traka se ne pomera ustranu ni na
   Windowsu ni na telefonu položeno. U Teach → Preparation ih je dve i dele
   širinu. **Uspravno na telefonu, u Analyse, pet kartica se i dalje skroluje** —
   to je očekivano; reci ako smeta, alternativa je da ostanu samo ikonice.
7. [x] **Redosled desne kolone.** Paleta, pa „To move" i rokade, pa red
   „Starting position" + „Clear board" (jednako široki), pa „Erase" ispod njih.
   Na telefonu položeno (667×300) kolona ima **106 dp ispod pregiba**: „Erase" i
   dno reda rokada traže mali skrol. Na većem telefonu položeno (932×430) sve
   staje bez skrola.
7a. [x] **Rokade.** „W O-O", „W O-O-O", „B O-O", „B O-O-O" — **dva reda po dva**
   na Windowsu i u portretu, **jedan red od četiri** na telefonu položeno, sve
   četiri jednake širine i nijedna reč nije presečena. Upaljeno pravo se
   razlikuje **ispunom i debljim okvirom** (nema više kvačice) — proveri da se
   upaljeno i ugašeno razlikuju na tvom ekranu. Duži pritisak pokaže puno ime
   („White kingside").
8. [x] **Zaglavlje na telefonu položeno.** Naslov „Board Setup" i kartice su u
   **jednom** redu, a cela tabla staje.
9. [x] **Nelegalna pozicija se ne može postaviti.** Probaj redom: obriši tablu
   (nema kraljeva), stavi drugog belog kralja, dodaj deveti i deseti beli pešak,
   stavi belog pešaka na osmi red, i postavi kulu tako da crni kralj bude u šahu
   dok je beli na potezu. Svaki put: crveni razlog iznad dugmeta i **dugme je
   ugašeno**; klik na njega ne radi ništa i dijalog ostaje otvoren. Kad je
   pozicija ispravna, dugme radi kao pre.
10. [x] **Postavljena pozicija je tačna.** Nameštena pozicija (uključujući stranu
   na potezu i rokade) stigne na tablu ista u sva tri ekrana koja otvaraju
   dijalog.

## 187. Zadatak (Exercise), faza 5: provera pri čuvanju — 19.9.2026, nije viđeno uživo

Jedino mesto gde se vidi **pravi** tablebase i **pravi** motor iza provere — u
testovima su trčali samo lažni.

1. [ ] **Pozicija sa ≤7 figura, „Find the move"**, odigran jedan od više poteza
   koji drže dobitak: posle par sekundi piše koji još potezi drže dobitak i nudi
   „Accept". Pre dodira rešenje u listu se **ne menja**; posle dodira se vidi
   „(or …)".
2. [ ] Odigran potez koji **ispušta** dobitak: piše upozorenje, bez „Accept".
3. [ ] **„Win" na remi poziciji** (≤7 figura): piše da se protiv savršene
   odbrane ne može ispuniti; „Save" i dalje radi.
4. [ ] **Više od 7 figura**, potez slabiji od motorovog za više od pešaka i
   po: „The engine prefers …" sa „Accept". Dok motor misli, „Save" radi.
5. [ ] **Bez interneta**: „Checking…" nestane samo od sebe za desetak sekundi,
   ništa se ne prikaže, „Save" radi sve vreme.
6. [ ] Ako je u Preparation **uključena analiza motora**, provera je ne kvari:
   posle provere analiza table nastavlja kao pre. (Provera koristi isti motor.)
7. [ ] Promena sa „Win" na „Draw or better" skida nalaz koji je važio za „Win".

## 186. Zadatak (Exercise), faze 3a–4: partija na N poteza, Biblioteka i sličice — 19.9.2026, nije viđeno uživo

1. [ ] **Preparation → „Make exercise"**: prvo se bira šta se traži — „Find the
   move", „Win", „Draw or better". Za partiju: „To the end" / „For N moves",
   strana koju učenik igra (**ništa nije unapred izabrano**, „Save" ne radi dok
   se ne izabere), jačina.
2. [ ] Ispod pitanja piše **ko sudi**: sa 7 ili manje figura i „For N moves" —
   tablebase; sa više figura — samo „not checkmated"; „Win" na N poteza sa
   više od 7 figura — odbijeno, „Save" ne radi.
3. [ ] Za partiju **ne treba** odigrana linija — samo pozicija.
4. [ ] **Biblioteka**: sedam čipova, „Exercises" posle „Tutorials"; ispod njega
   dva reda filtera (šta traži / odakle je) i „New exercise" koje otvara
   Preparation. Pod „Positions" tih redova **nema**.
5. [ ] Redovi pozicija i zadataka imaju **sličicu table**; zadatak za crnog je
   okrenut ka crnom. Dodir na sličicu otvara veću tablu sa imenom, zadatkom i
   „White/Black to move" **rečima**; „Open" otvara stavku. Dugačka lista se
   skroluje glatko na telefonu.
6. [ ] **Domaći → Add**: „A tutorial · Exercises · A puzzle set" — nema „Play
   it out". Birač nudi samo zadatke (gola pozicija se ne nudi). Jedan „find" i
   jedan „game" zadatak daju **dva reda**.
7. [ ] **Učenik, „Win for 2 moves"** sa ≤7 figura: posle drugog poteza partija
   staje, i tek kad server odgovori piše „Goal met" ili „Goal not met".
8. [ ] Isto to **bez interneta ka tablebase-u**: piše „not judged yet" (nije
   neuspeh), red u domaćem „Played — not judged yet" sa peščanim satom; sledeća
   stavka je otključana; kad se domaći kasnije ponovo otvori, presuda stigne.
9. [ ] U **sobi**, kolona biblioteke ima čip „Exercises" i zadatak se učitava
   na tablu kao ranije skenirana pozicija.

## 185. Zadatak (Exercise), faze 1–2b: napravljen u Preparation, rešen kao niz — 18.9.2026, nije viđeno uživo

`docs/PLAN-EXERCISE.md`. Pri prvom pokretanju servera migracija dodaje kolone
na `custom_puzzles`, dodaje `assignment_items.judged_by` i **briše**
`require_solved` sa `assignments` i `homework_items`.

1. [ ] **Preparation → „Make exercise"** (pored „Save position"): sa praznom
   tablom piše da prvo treba odigrati rešenje i nema „Save".
2. [ ] Odigraj dva poteza belog sa odgovorom crnog, i jednu varijantu na
   **prvom belom** potezu: list pokazuje „1. … (or …) …  2. …", „Find the
   moves", i „Save" radi tek kad se upiše ime.
3. [ ] Ako glavna linija završava protivnikovim potezom, piše da taj potez
   nije deo rešenja.
4. [ ] Posle „Save": poruka „Exercise saved.", i zadatak je u Biblioteci među
   zadacima, pod svojim imenom (čip „Exercises", stavka 186.4).
5. [ ] **Domaći → Add → positions**: zadatak se bira i šalje kao i skenirana
   pozicija.
6. [ ] **Učenik**: prvi tačan potez → „Correct. Keep going.", na tabli je
   protivnikov odgovor; pogrešan potez → „Not that move. Try again.", tabla se
   vraća, rešenje se **ne** prikazuje; poslednji tačan potez završava zadatak.
7. [ ] Učenik odigra **prihvaćenu alternativu**: tabla nastavlja od trenerovog
   poteza, pa odgovor.
8. [ ] **Pregled**: posle pogrešnog pa tačnog, stavka ostaje „netačno" (pamti
   se prvi pokušaj), a trener vidi ceo niz.
9. [ ] U editoru domaćeg **nema** prekidača „Solved", a učenik ne vidi „must
   be solved". (Stavka 184.7 time otpada.)

## 184. Domaći, faza 5: učenikov domaći i trenerovo otključavanje — 18.9.2026, nije viđeno uživo

Za ovo treba poslat domaći, a prozor za slanje je još app-pola faze 4 — do
tada se šalje ručno kroz zahtev (`POST /homeworks/:id/send`).

1. [ ] **Učenik**: „My Assignments" ima **jedan** red za domaći, sa „1 of 3
   items" (ne „0/0 completed"); otvaranje daje stavke u trenerovom
   redosledu, sa Done / Open / Locked.
2. [ ] **Zaključana stavka** se ne otvara na dodir i piše **ime** stavke
   koja je drži zatvorenu (ne „item #502").
3. [ ] **„Odigraj do kraja" se otvara iz domaćeg** — tabla sa zadatom
   pozicijom, jačina engin-a je trenerova (nema izbora jačine), a kraj
   partije se javlja serveru. Ovo je jedini put do faze 2b, pa se ovde
   prvi put i vidi.
4. [ ] **Trener** iz učenikovog napretka otvara isti ekran (ne prazan
   review): na zaključanoj stavki „Unlock for student"; posle toga učenik
   vidi „Unlocked early by your trainer", a trener „You unlocked this
   early".
5. [ ] **Review po stavki** radi sa obe strane (roditelj ga nema).
6. [ ] **Vraćanje sa stavke** osvežava stanje — sledeća stavka se otvara
   bez povlačenja liste nadole.
7. [–] *Povučeno 18.9.2026:* „mora rešeno" je izbačeno (stavka 185.9).

## 183. Domaći, faze 3a–4: šablon, editor i slanje — 17.9.2026, nije viđeno uživo

Sve je prohodno kroz ekrane od 18.9.2026 — prozor za slanje otvara se iz reda
u listi domaćih i iz editora.

0. [ ] **Vrata**: kartica „Homework" na Teach tabu i vrata „Homework" u
   Biblioteci otvaraju istu listu; na telefonu se oboje vide bez skrolovanja
   udesno. „New homework" otvara prazan editor.
0b. [ ] **„Odigraj do kraja"**: u biraču izaberi poziciju gde je beli na
   potezu, pa izaberi da učenik igra **crnim** — rečenica ispod kaže da motor
   otvara. Pošlji i proveri kod učenika: motor odigra prvi potez sam.
0c. [ ] **Brisanje šablona** pita pre brisanja; ako je domaći već poslat,
   rečenica kaže da poslato ostaje — i posle brisanja učenikov domaći je
   netaknut.
1. [ ] **Prijavljeno uživo 18.9.2026, ispravljeno istog dana** — „ne mogu da
   ubacim pozicije, fen nije dobar". FEN je bio
   `rnbqkbnr/ppp2ppp/4p3/3p4/3PP3/8/PPP2PPP/RNBQKBNR`: **tabla i ništa više**,
   jedno polje od šest — ono što daje alat za dijagrame. Dijalog „Play it out"
   ga je odbijao i na svaku grešku odgovarao istom rečenicom („Not a valid
   position for 'play it out'"), pa se nije moglo videti da tabla nije bila
   problem. Tri promene:
   - **tabla sama se dopunjava**: rokada se čita sa table (kralj i topovi na
     svojim poljima), a dopunjeni FEN se **upisuje u polje** da ga trener vidi
     i ispravi — nagađanje o pravilima partije koja se zadaje ne sme da bude
     nevidljivo;
   - **prekidač strane odlučuje ko je na potezu**, a pastovanje FEN-a postavlja
     prekidač onako kako FEN kaže. Pravilo koje je vlasnik dao: *last action
     always wins* — posle pastovanja važi FEN, posle klika važi prekidač. Pri
     promeni strane briše se i en passant polje, jer ono važi samo za stranu
     koja tu može da uzme;
   - **razlog se vidi**: `fenIllegalReason` zna da li fali kralj, da li pešak
     stoji na prvom redu i da li je strana koja nije na potezu u šahu — sada se
     ta rečenica i prikazuje.
   Čuvari: `fen_completion_test`, `homework_play_it_out_fen_test`.

   **Napiši domaci** sa četiri stavke (tutorijal, pozicije, set
   zagonetki, „odigraj do kraja"), sa branom na drugoj i „mora rešeno" na
   četvrtoj; preuredi ih — posle čuvanja redosled je novi, a stavke su iste
   (ne pojavljuju se duplikati i ne gube se izbori).
2. [ ] **Pošalji jednom učeniku**: učenikova lista ima **jedan** red
   („Thursday", 0/4), ne četiri; jedno obaveštenje „New homework".
3. [ ] **Kvota** — **nema gde da se vidi u aplikaciji** (vlasnik, 18.9.2026:
   „ne znam gde se gledaju kvote, to ćemo tek da implementiramo"). Do tada se
   proverava iz servera: log „Homework sent" po učeniku, i odbijeno slanje koje
   ne piše red. Ekran za kvote je poseban posao.
   Na besplatnom planu slanje troši jednu jedinicu po učeniku
   (pet stavki unutra ne menja ništa); odbijeno slanje ne troši ništa.
4. [ ] **Pozicija pod revizijom**: obeleži jednu poziciju iz domaćeg kao
   „needs review", pošalji — odbija se sa rečenicom o reviziji i učenik ne
   dobija **ništa** (ni tutorijal koji je bio u redu).
5. [ ] **Izmeni šablon posle slanja** (dodaj i obriši stavku): već poslati
   domaći se ne menja — isti naslov, iste stavke, isti napredak.
6. [ ] **Uzak filter zagonetki** (tema + najviši rejting koji klizač daje):
   **ispravljeno u opisu 18.9.2026** — vlasnik: „mogu samo do 2800". Klizač u
   dijalogu ide 400–2800, pa se 3200–3400 iz starog opisa ne može ni izabrati;
   uzmi 2800–2800 sa retkom temom. Ruta kaže da
   nema zagonetki po tim kriterijumima; ranije je vraćala 500.
7. [ ] **Prozor za slanje**: nudi samo učenike koji su prihvatili poziv;
   izaberi dvoje, pošalji — obojica dobijaju po jedan red, a kvota se
   umanji za **dva**. Rok i napomena stignu do učenika.
8. [ ] **Odbijanje jednog učenika** (npr. potrošena kvota na drugom nalogu
   ili pozicija pod revizijom): rečenica imenuje tog učenika, a onaj drugi
   je i dalje dobio domaci.
9. [ ] **Slanje iz editora**: dugme je ugašeno dok domaci nije sačuvan; posle
   čuvanja radi, a ispod stavki piše šta je već poslato i dokle je stiglo.
10. [ ] **Dva čuvanja u istom sedenju** prave **jedan** domaci, ne dva (i
   posle drugog čuvanja stavke su iste, bez duplikata).

## 182. Domaći, faza 2: zadata partija, i portret ekrana vežbi — 17.9.2026, nije viđeno uživo

`docs/PLAN-DOMACI-ZADATAK.md`, faze 2a i 2b. Zadata partija se još ne šalje
(to je faza 4), pa se tačke 1–3 gledaju na **portretu ekrana vežbi**, a 4–5
kad slanje bude gotovo.

1. [ ] **Telefon uspravno, „Basic mates"**: u app baru gore desno stoje
   ikonica robota („Engine opponent") i ikonica mreže („Board view") —
   ranije ih uspravno **nije bilo nigde**. Naslov se skraćuje sa „…" ako
   treba, ništa ne prelazi ivicu.
2. [ ] **Rečenica cilja** stoji nad tablom uspravno (npr. „Practice: …
   (Checkmate Stockfish)"), kao i položeno u zaglavlju.
3. [ ] **Nema više kartice „Back to selection"** ispod table — izlaz je
   strelica u app baru (i ona radi).
4. [ ] **Zadata partija** (posle faze 4): tabla na trenerovoj poziciji i
   strani; **nema** ikonice robota; rečenica kaže cilj (pobeda / remi /
   preživi N poteza); „Resign" umesto „Try Again"/„Next Position".
5. [ ] **Kraj partije**: dijalog kaže zbog čega je partija gotova i da li je
   cilj ispunjen; trener u pregledu vidi poteze i završetak; drugi pokušaj
   nije moguć.

## 181. Domaći, faza 0: presuda partije na ekranu vežbi — 17.9.2026, nije viđeno uživo

`docs/PLAN-DOMACI-ZADATAK.md`, §7 faza 0. Ekran vežbi, „Basic mates" ili
„Winning position" — remi se sada saopštava kao i poraz, dijalogom koji kaže
*zbog čega*, i motor se ne pita za potez u završenoj partiji.

1. [ ] **Pat vašim potezom** (npr. K+Q vs K: stavi damu tako da kralj nema
   potez, a nije šah): odmah dijalog „Draw — The game is drawn: stalemate.
   Try again." sa „Try again" i „Next Position"; motor **ne** vuče, ništa se
   ne vrti. Ranije: tišina.
2. [ ] **Nedovoljan materijal vašim potezom** (uzmi poslednju figuru tako da
   ostane K+B vs K ili K+N vs K): isti dijalog, „not enough material to
   mate".
3. [ ] **Pat potezom motora** (teško izazvati; ako se desi): dijalog umesto
   ranije poruke „Stalemate / Draw" pri dnu.
4. [ ] **Mat i dalje kao pre**: vaš mat → „VICTORY!", motorov mat →
   „Checkmate". Mate-in-N zagonetke nepromenjene.

## 180. Veličina table i paneli Analize prelaze iz Settings na ekran — 17.9.2026, nije viđeno uživo

Pregled odeljka „Board and panel appearance" (vlasnik, 17.9.2026). „Board
size" je menjao tablu na samo tri ekrana (soba, ekran vežbi, Analiza), a
šest kvačica „Panels in Analysis" čita samo Analiza — oboje je izbačeno iz
Settings. „Board coordinates" važi na svakoj tabli i ostaje.

1. [ ] **Settings**: u „Board and panel appearance" više nema „Board size"
   ni „Panels in Analysis"; ostaju koordinate, animacija poteza i ručni
   komentari.
2. [ ] **Analiza**: ikonica mreže (Board view) → „Board size" sa klizačem
   60–100%; tabla se smanjuje **dok je meni otvoren**, bez izlaska sa ekrana.
   Isto portret i položeno.
   **Prijavljeno uživo 18.9.2026, ispravljeno istog dana** („u landscape
   orjentaciji veliki deo površine iznad table je pokriven nepotrebnim
   elementima"): iznad table su stajala **tri** zaglavlja — naslov taba,
   red sa „My games"/„Scan a book", pa traka Analize. Srednji red je ukinut.
   „My games" ima svoja vrata na Practise (kartica), a „Scan a book" nije
   imao **nijedna druga** — `/scan/saved` se dohvata tek posle skeniranja —
   pa je prešao u traku Analize (na telefonu u ⋮ „More tools"), a nije
   obrisan. Provera: položeno, iznad table ostaju naslov taba i traka
   Analize; „Scan a book" se i dalje otvara iz ⋮.
3. [ ] **Soba** (ikonica mreže pored flip-a) i **ekran vežbi** (meni u
   zaglavlju, portret i položeno): isti klizač, tabla prati. Vrednost je zajednička za
   sva tri ekrana i ostaje posle ponovnog pokretanja.
   **Prijavljeno uživo 18.9.2026, ispravljeno istog dana** („moglo bi da se u
   portret modu navigaciona paleta svede na jedan red"): paleta je imala
   podrazumevani natpis „Navigation" u sredini, koji ne kaže ništa o poziciji
   a bio je dovoljno širok da gurne flip i board-view u drugi red na 360 dp.
   Natpis je sada podrazumevano prazan (ekrani koji hoće natpis šalju pravi —
   „Move 3 of 12"), a dugmad su gušća i u portretu, ne samo položeno. Izmereno,
   ne procenjeno: `nav_strip_one_row_test` meri visinu palete na 360 dp.
4. [ ] **Drugi ekrani** (npr. taktike, repertoar): u meniju table **nema**
   klizača.
5. [ ] **Analiza → „Panels"** (na telefonu u ⋮ „More tools", na Windows-u
   ikonica): skini „Move tree" — stablo nestaje ispod otvorenog lista; vrati
   ga. Izbor ostaje posle ponovnog pokretanja.
   **Prijavljeno uživo 18.9.2026, ispravljeno istog dana** („u portret modu se
   deo ispod navigacione palete uopšte ne vidi"): tri stvari su uzimale visinu.
   Red „My games"/„Scan a book" je ukinut (v. 180.2), dugmad palete su gušća, i
   **četiri radnje nad potezom** (komentar, AI komentar, NAG, brisanje) više ne
   vise o navigacionoj paleti. Devet dugmadi od 40 dp traži 360 dp pre ivica,
   pa se paleta lomila u dva reda na svakom telefonu.
   **Drugi pokušaj istog dana**, pošto je prvi („četiri radnje u svom redu
   ispod palete") dao „malo je bolje, ali nije najbolje" — ekran je i dalje
   trošio dve kartice hroma između table i bilo čega vrednog čitanja. Sada su
   **dva reda postala jedan**: potez na kome stojiš je natpis u sredini palete
   (mesto koje za to i postoji, a do tog jutra ga je trošila reč „Navigation"),
   a četiri radnje su iza jednog dugmeta koje otvara list sa imenima. To je
   pravilo koje traka alata ovog ekrana ionako prati — ikone gde ima mesta,
   meni gde nema — pa na Windows-u i dalje stoje kao četiri ikone. Panel
   komentara je vraćen na ono što jeste: **sadržaj**, crta se samo kad potez
   zaista nosi rečenicu.
6. [ ] **Upoznaj repertoar**: tabla sada ima slova i brojeve po ivici, a
   „Coordinates" u meniju ih pali i gasi (ranije prekidač nije radio ništa).
9. [ ] **Nema gornje trake ljuske** (18.9.2026, traženo uživo: „taj gornji deo
   mi uopšte nije potreban"). Reč „Chess Trainer" sa zupčanikom i zvonom je
   stajala **iznad** naslova samog taba — dva zaglavlja koja kažu isto, 56 dp
   pre nego što tab išta nacrta. Ništa novo nije izmišljeno umesto nje:
   položeni telefon je zvono i zupčanik već držao na kraju `_TabHeader`-a, pa
   sada isto radi i portret. Provera: Home, Practise i Teach imaju svoj naslov
   sa zvonom i zupčanikom desno; **Analyse nema nijedno zaglavlje** — telo mu
   je ekran Analize sa sopstvenom trakom, a „Settings" je među njenim
   radnjama. **Poznato i namerno**: zvono se sa Analyse ne vidi (tako je bilo i
   u položenom telefonu od faze 5, v. 177.7). Gost i dalje ima „Sign In", sad
   u zaglavlju taba.

7. [ ] **Komentari u Analizi**: „Manual comment selection" više nije u
   Settings. Analiza → „Panels and comments" → „Comment new moves
   automatically": uključeno — odigran potez dobija komentar; isključeno —
   ne dobija. Važi i za Auto Analysis.
8. [ ] **Dubina do 50, svaka vrednost**: meni „depth" na tabli Analize,
   repertoara i vežbi ima 6–50 bez preskakanja (natpisi su sada engleski:
   „depth", „lines", „Again"); „Review entire game" i „Auto Analysis" idu do
   50; „Check with engine" u sačuvanim pozicijama 12–50.
9. [ ] **„Make a tutorial from this game"**: klizač dubine 18–50 umesto tri
   izbora; ispod broja vreme — za 18/20/22 izmereno, iznad 22 „not
   measured". Zapamćena dubina se vraća sledeći put.
10. [ ] **Motor kao protivnik**: u Settings odeljak „Stockfish engine" više
    nema jačine ni vremena razmišljanja (ostaje napomena i, na Windows-u,
    lokalni .exe). Na ekranu vežbi ikonica robota (pored ikonice mreže,
    portret i položeno) otvara list „Engine opponent": Easy/Medium/Hard i
    klizač 1–60 s. Promeni na Hard usred partije — sledeći potez motora
    ide dublje (u logu „Zadata dubina dostignuta (30 >= 30)"). Vrednosti
    ostaju posle ponovnog pokretanja.

## 179. Reorganizacija, faze 6a–6c: studio na telefonu, jedan urednik — 17.9.2026, nije viđeno uživo

`docs/PLAN-REORGANIZACIJA.md`, §7 (6a kontroler, vođa; 6b raspored za
telefon i 6c jedan urednik, implementeri). Windows i telefon.

1. [ ] **Windows, nepromenjeno**: Tutorial Studio radi kao pre 6a — potez,
   komentar, deo, pitanje, undo/redo, „Discard changes", čuvanje, video,
   naracija, .pgn. (543 testa studija prošla neizmenjena; ovo je pogled.)
2. [ ] **Telefon, portret**: Teach → kartica „Tutorials" postoji (ranije
   samo Windows) → „New tutorial" otvara studio sa tablom gore, **listom
   poteza** (Start · 1. e4 · 1… e5 …), pa trakom za kretanje (strelice i
   okretanje table), pa tabovima „Line | Task | Parts"; ništa ne prelazi
   ivicu ekrana.
   **Prijavljeno uživo 18.9.2026, ispravljeno istog dana** („Ne vidim traku
   poteza… mislio sam da nema Flow/Tree/PGN panel"): raspored za telefon
   namerno nema te tri table, pa se linija mogla graditi i nije se mogla
   pročitati — bile su samo strelice. Sada je pod tablom red poteza koji se
   skroluje vodoravno: tap vodi na potez, tekući je uokviren, a potez sa
   komentarom nosi oblačić. Isti red je i u položenom telefonu. Izvor je
   `beatsOf`, isti kojim Windows crta „Flow", da se dva pogleda ne raziđu.
   Provera: odigraj 3–4 poteza, napiši komentar na jedan, pa se tapom vrati
   na prvi — tabla i tab „Line" moraju otići na njega.
3. [ ] **Line**: komentar na potez na kome stojite; „Insert a line here" i
   „Delete this move" gde imaju smisla; crtanje strelica i polja istom
   trakom kao u sobi; okretanje table.
4. [ ] **Task**: vrsta (Show only / Ask for move on board / Ask for answer
   from list), tekst zadatka, odgovori sa dodavanjem i brisanjem, „Correct
   move" posle poteza na tabli kod pitanja za potez.
5. [ ] **Parts**: „New part" sa tri vrste, lista delova, gore/dole/kloniraj/
   preimenuj/obriši, tap bira deo i tabla ga prati.
6. [ ] **Prelivanje (⋮)**: Undo, Redo, Discard changes, Preview tutorial,
   Record narration, Export video, Save as .pgn, Position setup.
7. [ ] **Telefon položeno**: tabla levo celom visinom, tabovi desno.
8. [ ] **Isti sadržaj**: tutorijal sačuvan sa telefona otvara se na Windows-u
   sa istim delovima, komentarima i pitanjem — i obratno.
9. [ ] **Soba na telefonu**: „Edit tutorial" na redu tutorijala otvara studio
   (ranije stari panel); Analiza → „Use in a tutorial" nudi i redove studija.
11. [ ] **„Saved tutorials" otvara Library** (prijave vlasnika 17.9.2026:
    na telefonu dijalog bez tutorijala, pa redovi bez naslova i položeno bez
    liste; vlasnik izabrao varijantu B — dijalog uklonjen). Teach → Tutorials →
    „Saved tutorials" otvara ekran Library na čipu „Tutorials" i „Mine":
    - **portret**: naslov tutorijala čitljiv, četiri dugmeta (video, preuzmi,
      pošalji, obriši) u redu ispod naslova;
    - **položeno**: čipovi, oznake i pretraga odlaze nagore sa listom kad se
      skroluje; redovi su dostupni;
    - **„From trainer"**: trenerovi tutorijali bez dugmadi, tap kaže da je
      tutorijal trenerov;
    - **Windows**: dugmad ostaju u istoj liniji sa naslovom;
    - tap na red otvara studio; „Label Filter Matrix" i „Search" sužavaju.
10. [ ] **Priručnik** (write-a-tutorial, analysis, getting-started) više ne
    pominje Windows kao uslov.

## 178. Reorganizacija, faza 3b: kolona sobe je deljena lista — 17.9.2026, nije viđeno uživo

`docs/PLAN-REORGANIZACIJA.md`, faza 3b (vođa). Leva kolona sobe i Pripreme
(Windows; na telefonu fioka) čita istu listu kao Library na Teach.

1. [ ] **Kolona**: pod „Board" isti tasteri kao pre (Set up position, Import
   PGN, Save position, FEN); pod „Library" čipovi All · Tutorials · Positions
   pa Mine · From trainer, ispod „Label Filter Matrix" (samo ako imate
   oznake), pa polje „Search", pa redovi — bez sličice table, sa ikonom vrste
   i redom „N parts" / „saved position" / izvorom iz knjige.
2. [ ] **Tap na tutorijal** stavlja prvi deo na tablu i otvara traku delova
   iznad table; tap na poziciju stavlja je na tablu (i sa linijom, ako je
   sačuvana sa PGN-om). Pozicija iz skenirane knjige je pod Positions i ide
   na tablu isto.
3. [ ] **Radnje**: tutorijal ima ⋮ (Edit tutorial · Rename · Save as new
   version) i kantu; pozicija olovku i kantu. Kod učenika, trenerovi redovi
   (From trainer) nemaju ništa.
4. [ ] **Oznake**: uključi jednu oznaku u matrici — lista se sužava i za
   tutorijale i za pozicije (tutorijal nosi svoje oznake od ove faze); dugi
   pritisak isključuje.
5. [ ] **Pretraga** hvata i naslov i oznaku.
6. [ ] **Pad servera** dok se kolona puni: „The library could not be loaded."
   i „Try again", ne prazna lista.
7. [ ] **Library na Teach** sada ima istu matricu oznaka ispod čipova (ako
   imate oznake).

## 177. Reorganizacija, faza 5: Home · Practise · Analyse · Teach — 17.9.2026, nije viđeno uživo

`docs/PLAN-REORGANIZACIJA.md`, faza 5 (vođa). Priručnik na sajtu sada opisuje
aplikaciju kakva jeste; sajt sme na droplet.

1. [ ] **Četiri taba**, na Windows-u levo, na telefonu dole: Home, Practise,
   Analyse, Teach; „Settings" je zupčanik, ne tab. Ctrl+1…4 ih menja.
2. [ ] **Home** otvara aplikaciju. Bez trenera i bez učenika: pozdrav, polje
   „Join a session" i „Recordings" — ni „Set for me" ni „Today". Sa učenikom
   koji je predao domaći: blok „To review" sa dugmetom; sa trenerom: „Set for
   me" i „Due for review". Napuštena sesija: čip „Resume session …" na vrhu.
   **Prijavljeno uživo 18.9.2026, ispravljeno istog dana**: nov nalog je na
   Home zatekao čip „Resume analysis" koji otvara **stablo prethodnog
   naloga**. `signOut()` je brisao samo prijavu; svaka lokalna beleška se
   piše pod jednim ključem bez vlasnika. `AccountLocalState` sada predaje
   uređaj onome ko se prijavljuje i briše tuđe: analiza, nacrt tutorijala,
   aktivna soba i lista rešenih lokalnih zagonetki. Gost koji se prijavi
   **zadržava** svoj rad (isti čovek), a snimci koji nisu stigli na server i
   imenovani skupovi zagonetki se namerno ne brišu — vide se i dalje.
   Provera: nalog A analizira, odjava, nalog B → Home bez čipa; pa gost
   analizira, prijava → čip ostaje.
3. [ ] **Practise** je stari hub, bez trake „Resume" (ona je na Home);
   naslov „Practise". Linije napretka iz stavke 176 i dalje na karticama.
4. [ ] **Analyse**: tabla je odmah tu, sa svojom trakom (Setup, motor, „Use in
   a tutorial"…); iznad nje „My games" i „Scan a book"; **nema** drugog
   naslova iznad trake. **Motor je ugašen na ulasku** — ni traka procene ni
   strelice dok se ne uključi; promena taba i povratak zatiče isto stablo i
   isti prekidač. Telefon položeno: tabla levo kao u stavci 172.
   (Traženo 17.9. i 18.9.2026: „U Analizu treba da se ulazi sa ugašenim
   engin-om". Do tada je prvi ulazak pokretao motor sam.)
5. [ ] **Teach**: kartica tutorijala (Windows), „Preparation" → „Open",
   „New session" → „Start", „Library" → „Open library", pa „Students" —
   kartica „Students and trainers" sa „Send a request", dugme „Groups" uvek
   vidljivo, red učenika ima „Progress" (isključen dok roditelj ne potvrdi).
   Na telefonu se tab skroluje ceo, bez unutrašnjeg skrola.
6. [ ] **Zvono** sa zahtevima: bedž na ikoni „Teach" (bio na „People"); zvono
   otvara isti dijalog „Notifications and Invitations".
   **Dopunjeno 18.9.2026** (vlasnik: „Ne razumem ovu notifikaciju na tabu
   Teach gde piše 1"): broj je bio tačan — jedan predat domaći koji nije
   otvoren — i nije se nigde predstavljao. Sada ikona nosi rečenicu („Teach —
   1 homework to review", „… · N requests to answer"), a broj je i dalje
   zbir dve stvari koje trener može da skine sa spiska. Ono što je i dalje
   otvoreno pitanje za vlasnika: bedž stoji na **Teach**, a red za pregled se
   crta na **Home** („Trainer panel / TO REVIEW").
7. [ ] **Telefon položeno** (stavka 174): naslov taba i zupčanik gore desno na
   Home, Practise i Teach; na Analyse je red sa „My games"/„Scan a book" pa
   traka Analize — zvono tu nije dostupno (poznato).

## 176. Napredak u vežbama: šta je rešeno, šta se vraća — 17.9.2026, nije viđeno uživo

`docs/PLAN-NAPREDAK-VEZBI.md`, faze 1 i 2 (spojeno `da433d3`, `1677f34`).

1. [ ] **Kartice ćute dok nema ničega.** Nov nalog, tab Training: nijedna kartica
   ne piše „Solved 0" ni dugme „Retry failed".
2. [ ] **Linija posle prvog pokušaja.** Reši jedan mat u 2, promaši drugi, preskoči
   treći („Next Position"). Vrati se na hub: kartica matova piše
   „Solved 1 · 2 to retry" i dugme „Retry failed (2)".
   **Prijavljeno 18.9.2026 kao „Solved 1 · 1 to retry", nađeno i ispravljeno
   istog dana — ali nije bilo u pisanju nego u čitanju.** Zapis je bio
   ispravan sve vreme: „Next Position" na nerešenoj zagonetki šalje
   `skipped: true`, a server broji i promašaj i preskok u `toRetry`. Kartica
   je pokazivala **staro čitanje**. Vlasnik je to i izmerio: čekanje ne pomaže
   (ništa se ne čita ponovo od samog stajanja), ali odlazak na bilo koji drugi
   ekran i povratak odmah osveži broj — jer je to drugo čitanje.
   Uzrok: pokušaj se šalje „ispali i zaboravi" (tabla ne sme da čeka poruku o
   tabli), a `context.push` se razrešava čim se ekran napusti, pa je čitanje
   preticalo upis. Sada `PuzzleAttemptWrites` drži upise u letu, a hub čeka
   `settled()` pre nego što pročita. Čuvari: `puzzle_attempt_writes_test`
   (pet testova) i `hub_refresh_after_drill_test` (čitanje se dešava, i čeka).
   Provera: reši → promaši → preskoči, pa **odmah** nazad — broj mora biti
   tačan bez odlaska na drugi ekran.
3. [ ] **Retry servira baš te.** Pritisni „Retry failed (2)": naslov ima „— retry",
   stižu upravo promašena i preskočena zagonetka, po redu. Reši jednu; hub
   posle povratka kaže „Solved 2 · 1 to retry".
4. [ ] **Taktika, završnice, šetnja kroz partiju** pišu isto: po jedan pokušaj u
   svakoj, pa linija na kartici. Završnice: „Win" i „Hold a draw" se sabiraju na
   jednoj kartici; za šetnju kroz partiju linija bez dugmeta (nema by-id).
   **Prijavljeno uživo 18.9.2026, ispravljeno istog dana** („Malo zbunjuje,
   piše solved 0 i solved 1"): kartica završnica nosi dva izvora, a obe
   linije su bile bez imena, pa su se čitale kao jedan broj koji sam sebi
   protivreči. Sada piše „Endgames: Solved 0 · 2 to retry" i ispod „Game
   blunders: Solved 1". Kartica sa jednom linijom je i dalje bez imena —
   naslov kartice je ime.
5. [ ] **Osnovni matovi**: preset odigran do mata → linija na kartici; bez dugmeta.
6. [ ] **Domaći zadatak nije dirnut.** Preskakanje u zadatku i dalje ne beleži
   ništa (jedan pokušaj, kao do sada).
7. [ ] **Server**: `GET /api/puzzles/progress` sa tokenom vraća po izvoru
   `seen/solved/firstTry/failed/skipped/toRetry`; `mate_puzzle` ima
   `buckets` po dubini, `endgame` po režimu.

## 175. Reorganizacija, faze 1–3a: jedna vrata, jedna biblioteka, imena — 17.9.2026, nije viđeno uživo

`docs/PLAN-REORGANIZACIJA.md`, faze 1, 2 i 3a (spojeno `bfeaadb`, `6a7ac83`,
`2671241`). **Priručnik na sajtu već opisuje tabove iz faze 5** — ne isporučivati
sajt pre nje.

1. [ ] **Analiza ima jedna vrata.** U traci je jedno dugme „Use in a tutorial"
   (ikona škole); ostala četiri (Create step, Edit tutorial steps, Create
   interactive tutorial, Make a tutorial from this game) ne postoje.
   Na 360 dp list se skroluje, ništa ne preliva.
   **Ispravljeno u opisu 18.9.2026** (vlasnik: „Ima 6 u windows-u, a tri u
   androidu"): od faze 6c svih šest redova postoji i na telefonu, jer studio
   od tada radi i tamo. Broj redova ne zavisi od platforme nego od pozicije:
   „New tutorial from this line" i „Add this line…" traže poteze **posle**
   kursora, „New tutorial from this game" traži glavnu liniju. Na praznoj
   tabli ostaju tri (position, add position, edit) — što je ono što je
   viđeno na telefonu. Provera: stani na potez usred linije na telefonu i
   list mora imati šest.
2. [ ] **Svaki red radi ono što piše**: „New tutorial from this line" otvara
   Studio sa celom linijom; „Add this position to a tutorial…" pita samo koji
   tutorijal; „Add this line…" pita još i „Where does the step begin?";
   „Open a tutorial to edit…" otvara birač.
3. [ ] **Soba i Priprema**: leva kolona ima naslov „Board" (Set up position,
   Import PGN, Save position, FEN) pa „Library"; nema „Create tutorial
   (multiple positions)"; meni reda tutorijala nema „Edit positions".
   „Save position" dijalog: naslov „Save position", polje „Position name".
4. [ ] **Priprema nije sesija.** Iz Pripreme na početni ekran: nema banera
   „Active session (code: STUDIO)" ni čipa „Resume session STUDIO".
5. [ ] **Join proverava kod.** Na tabu Sessions ukucaj „12" i „Join": poruka
   „Enter a valid 6-digit code", ništa se ne otvara.
6. [ ] **Imena**: kartica „New session" (podnaslov „Open a room and invite your
   student."), „Recordings" / „No recordings yet.", „Students and trainers",
   „Tutorials" (bila „Interactive tutorials"), „Scan a book"; ikona
   „Student groups" vidljiva i bez učenika.
   **Ispravljeno u opisu 18.9.2026** (vlasnik: „nije kao u opisu, nego kao na
   slikama"): faza 5 je ove kartice razdelila po tabovima, pa se imena traže
   tamo gde sada stoje — „Tutorials", „Homework", „Preparation", „New
   session", „Library" i „Students" na tabu **Teach**, „Recordings" na
   **Home**, „Scan a book" u redu iznad table na **Analyse**. Imena su ista,
   ekran nije.
7. [ ] **Biblioteka**: tab **Teach** → kartica „Library" („Everything you keep
   — tutorials, positions, analyses, recordings.") → „Open library".
   (Do faze 5 je to bio zaseban tab „Library"; ispravljeno u opisu 18.9.2026
   na vlasnikovu primedbu „Pomerili smo na Tab Teach".) Čipovi All · Tutorials · Positions · Analyses · Recordings ·
   Puzzle sets; pretraga; pozicija iz sobe i pozicija iz knjige obe pod
   „Positions" (knjiga sa izvorom). Tutorijal: red ima Send / Export video /
   Delete i otvara Studio; sačuvana analiza se otvara **cela** (sa
   varijantama i komentarima); snimak → Play; skup zagonetki je nacrtan bez
   akcije (poznato, 3b).
8. [ ] **Server nedostupan** u biblioteci kaže „The library could not be
   loaded." sa „Try again", ne „Nothing here yet.".

## 174. Četiri prijave: podešavanja, mat, obaveštenje — 16.9.2026, nije viđeno uživo

`docs/STANJE-RADA.md`, „Četiri prijave iste večeri".

1. [ ] **Početni ekran položeno.** Zvono i zupčanik („Settings") su gore desno,
   u redu sa naslovom kartice; zupčanik otvara podešavanja. Naslov („Training")
   je ispod sata i baterije, ne preko njih. Okreni uspravno: sve kao pre.
2. [ ] **Mat bez komentara.** U Analizi odigraj potez koji matira (ili učitaj
   partiju koja se završava matom i pusti „Review entire game"): ispod matnog
   poteza nema komentara. Potez koji nije mat i dalje dobija komentar.
3. [ ] **Nema poruke o vraćenoj analizi.** Uđi u Analizu posle rada u njoj:
   stablo je tu, a dole nema „Your latest analysis has been restored".

## 173. Telefon položeno, posle prve provere — 16.9.2026, viđeno uživo

`docs/STANJE-RADA.md`, „Telefon položeno: posle prve provere". Ispravke za
stavke 1, 4 i 7 iz 172; ostale tačke 172 (3, 5, 6, 8, 9) važe i dalje.

1. [ ] **Analiza, traka u jednom redu.** Sa uključenom eval trakom: svih devet
   dugmadi (početak, nazad, napred, kraj, okreni, komentar, AI, NAG, obriši) u
   jednom redu, i dugmad se lako pogađaju prstom.
2. [ ] **Analiza bez sudije.** Nema panela „Move Verdict" ni dugmeta „Judge
   move", a u Settings nema prekidača „Move evaluation".
3. [ ] **Gradnja repertoara.** „Ask engine", „Next position" i „Drill this
   branch" u jednom redu, čitljivi; traka iznad njih takođe u jednom redu.
   Presuda na tvom potezu i dalje stiže sama i ne pominje Lichess.
4. [ ] **Uređivač delova, kartica Board.** Tabla levo, desno spisak delova sa
   ikonicama gore/dole/dodaj/obriši; izbor dela menja tablu; „Save step" i
   „Preview" dole desno.
5. [ ] **Uređivač delova, kartica Text.** Naslov, zadatak i vrsta preko cele
   širine; kucanje ne zatvara tastaturu; naslov otkucan ovde se vidi u spisku
   na kartici Board.
6. [ ] **Ništa pod sistemskom dugmadi** na desnoj (ili levoj) ivici, ni u
   uređivaču ni na drugim ekranima.

## 172. Telefon položeno — 16.9.2026, nije viđeno uživo

`docs/STANJE-RADA.md`, „Telefon položeno: tabla levo, sve ostalo desno".
Na telefonu, okrenutom položeno. Za svaki ekran: tabla levo, cela vidljiva, i
**ne pomera se** kad se desna kolona skroluje; traka sa potezima (gde je ima)
i dugmad su pri dnu desne kolone i vide se bez skrolovanja.

1. [ ] **Analiza.** Uključi eval traku: stoji uspravno levo od table, iste
   visine. Komentar poteza je iznad trake sa potezima, traka je u jednom redu.
   „Setup Position / PGN": sve kartice se otvaraju, dugme na dnu kartice je
   dostupno (skrolom ako treba), i kucanje FEN-a ne zatvara tastaturu.
2. [ ] **Soba (studio).** Tabla levo, motor i kontrole desno, traka pri dnu;
   lekcije se otvaraju iz Drawera (hamburger), ne stoje pored table.
3. [ ] **Učenik:** lekcija (duga rečenica ne pomera traku), pozicije iz
   domaćeg, taktika, ponavljanje, moje greške — dugmad za ocenu su na ekranu.
4. [ ] **Repertoar:** novi (kucaj ime — tastatura ostaje otvorena), gradnja
   (stablo desno ispod pitanja), dril (odigraj potez na tabli), obilazak.
5. [ ] **Endšpil i greške iz partija:** „Tablebase findings" u drilu se otvara
   desno, ne kao donji list.
6. [ ] **Plejer snimka i AI vežbe:** kontrole plejera desno; u AI vežbama
   strelica nazad gore levo radi.
7. [ ] **Uređivač delova tutorijala (Android, „Edit tutorial steps").** Kucaj
   naslov dela: tastatura ostaje, ništa se ne preliva.
8. [ ] **Okreni nazad uspravno** na bar dva ekrana usred rada: stanje ostaje
   (potez, stablo), raspored se vraća na stari.
9. [ ] **Telefon sa notch-om:** ništa ne ulazi pod izrez sa strane.

## 171. Analiza uvozi PGN sa varijantama — 16.9.2026, nije viđeno uživo

`docs/STANJE-RADA.md`, „Analiza uvozi PGN sa varijantama".

1. [ ] **Prijavljeni fajl.** Otvori `D:\chess\Italian-Game-Evans-Gambit-Accepted-—-White.pgn`,
   kopiraj ceo tekst, Analiza → postavka table → „PGN Uvoz" → nalepi → učitaj.
   Poruka „PGN loaded — 50 moves in tree", tabla stoji posle 14. Nxe5.
2. [ ] **Varijante su u stablu.** Posle 5. c3 u stablu su Ba5, Be7 i Bc5; posle
   6. d4 je i 6... exd4 sa ugnježdenom 8... dxc3.
3. [ ] **Komentari su tu.** Na 4... Bxb4 stoji „This is Evans Gambit Accepted".
4. [ ] **Imena.** Iznad table piše „Repertoire — Opponent".
5. [ ] **Nazad i napred.** „Export PGN" iz Analize, pa taj tekst ponovo „PGN
   Uvoz": isto stablo, bez upozorenja.
6. [ ] **Chess.com/Lichess** kartica i dalje učitava partiju (sa satom posle
   svakog poteza), bez komentara „0:02:59" u stablu.
7. [ ] **Pokvaren potez se kaže.** Nalepi `1. e4 e5 2. Nf3 Qxz9 *`: učita se
   do 2. Nf3, a poruka kaže da je potez izostavljen (žuta, ne zelena).

## 170. Motor na tabli, brojač koji je otišao, i repertoar kao PGN — 16.9.2026, nije viđeno uživo

Tri od sedam prijava od 16.9.2026 (segment „Opening repertoire"). Server mora
biti restartovan i imati `MASTERS_BOOK_PATH`; za tačku 6 treba lokalni
Stockfish.

1. [ ] **Brojač je otišao.** Otvori gradnju repertoara: ispod pitanja („What do
   you play with White?") **nema** rečenice o neodgovorenim pozicijama. U redu
   ispod stoji samo „decided N" (i „preview shortened" ako je slika skraćena),
   bez „open N".
2. [ ] **Govor ne broji.** Uključi govor i pređi kroz nekoliko pozicija: čuje se
   samo pitanje. Kad dve uzastopne pozicije pitaju isto, rečenica se **ne**
   ponavlja; kad se pređe sa „What do you play…" na „After … — which opponent
   moves do you prepare?", čuje se nova rečenica.
3. [ ] **Kartica u listi ne broji.** Na listi repertoara red ispod imena kaže
   samo stranu, „via …" ako postoji, i „N moves in graph" — nema „5 unanswered
   positions" ni „all answered". (Ako gledaš mrežni saobraćaj: lista više ne
   traži `GET /repertoire/progress` uopšte.)
4. [ ] **Mapa i dalje broji.** „Gaps in repertoire" i dalje kaže koliko pozicija
   nema odgovor — to je namerno ostavljeno, jer se ta mapa otvara baš zbog toga.
5. [ ] **Motor posle sopstvenog poteza.** Odigraj svoj potez i sačekaj da tabla
   stane posle njega (protivnik na potezu). „Ask engine" je vidljivo, radi, i
   panel „Engine" pokazuje linije **za tu poziciju** (ne za onu iza nje).
6. [ ] **Motor kad knjiga ćuti.** Uđi u liniju u kojoj knjiga nema odgovor
   (poruka „The book has no reply here"). „Ask engine" i dalje postoji, a kad
   odgovori, na tabli se vidi i strelica motora — tamo gde knjiga nije nacrtala
   nijednu.
7. [ ] **Ocena se pamti uz poziciju.** Posle pitanja motora, red „Saved: …"
   stoji uz dubinu i datum; vrati se na tu poziciju kasnije i ocena je i dalje
   tu.
8. [ ] **Izvoz u PGN postoji tamo gde je repertoar.** Lista repertoara → meni
   „More" na redu → „Export as PGN". Otvara se prozor sa tekstom, tekst je već
   na klipbordu.
9. [ ] **Fajl je repertoar.** U tekstu: glavna linija je tvoj glavni potez sa
   najigranijim odgovorom, ostali tvoji potezi su u zagradama kao varijante.
   Nigde u fajlu nema ★ ni procenata.
10. [ ] **Komentari su unutra.** Napiši komentar na neku poziciju u repertoaru,
    pa izvezi ponovo: rečenica stoji u vitičastim zagradama uz **taj** potez.
11. [ ] **Fajl se snima pod imenom repertoara.** „Save as .pgn" nudi ime po
    repertoaru (npr. `Smith-Morra-Black.pgn`), a ne `analysis-2026-09-16.pgn`.
    Otvori sačuvani fajl u nekom čitaču PGN-a (ChessBase, Lichess uvoz, SCID) i
    potezi se odigravaju.
12. [ ] **Repertoar koji počinje dublje.** Izvezi repertoar napravljen iz
    pozicije („Extract into new opening" ili gradnja od pozicije): ako se put
    odigrava od prvog poteza, fajl počinje od 1. poteza i nema `[FEN]`; ako ne,
    ima `[SetUp "1"]` i `[FEN …]`, a linija je napisana rečima („Repertoire
    line: …").
13. [ ] **Prazan repertoar se ne izvozi.** Na repertoaru bez ijednog poteza
    „Export as PGN" kaže da nema poteza i ne otvara prozor sa tekstom.

## 169. Ostatak revizije (blok C) — 16.9.2026, nije viđeno uživo

`docs/STANJE-RADA.md`, „Ostatak revizije (blok C)". Server restartovan.

1. [ ] **Trener završnica** piše „Position: draw" / „win" / „loss" — nigde „remi".
2. [ ] **Tablica u analizi** (Syzygy panel) piše „Win", „Probable win", „Unknown".
3. [ ] **Registracija u logu servera**: registruj se i unesi kod; u logu nema
   adrese, samo id (u razvoju: kod uz maskiranu adresu `p***@domen`).
4. [ ] **PGN sa ocenama u sobi**: učitaj partiju sa `??` i `!` u sobu i sačuvaj
   poziciju; u sačuvanom su oznake i dalje tu.
5. [ ] **Izvoz videa** i dalje prikazuje napredak i završava se normalno.
6. [ ] **Skeniranje PDF-a** i dalje radi (običan broj pokušaja ne udara u granicu).

## 168. Soba sa dva uređaja — 16.9.2026, nije viđeno uživo

`docs/STANJE-RADA.md`, „Soba iz revizije (blok B)". **Dva uređaja ili dve
instance aplikacije, dva naloga sa prihvaćenom vezom trener–učenik.** Server
restartovan. Ovo je prva provera sobe na dva uređaja posle 10.8.2026.

1. [ ] **Tabla prati potez.** Trener odigra e4; učenikova **tabla** (ne samo
   stablo) pokazuje e4. Trener klikne na raniji potez u stablu; učenikova tabla
   ide za njim.
2. [ ] **Kasni ulazak.** Trener odigra nekoliko poteza, pa učenik uđe; učenik
   vidi poziciju sobe, ne početnu.
3. [ ] **Učitana pozicija.** Trener učita sačuvanu poziciju ili tutorijal i
   odigra potez; učenikovo stablo nije prazno i tabla je na istoj poziciji.
4. [ ] **Okretanje table.** „Force student board to Black" — učenikova tabla se
   okrene.
5. [ ] **Deljenje pozicije.** Učenik podeli poziciju treneru; treneru se otvori
   dijalog i „Load onto board" je učita.
6. [ ] **Poziv sa spiska učenika.** Trener pozove učenika koji je u aplikaciji;
   učeniku se odmah otvori poziv, i poziv je i u zvoncu. Nalog bez veze dobija
   poruku o odbijanju, ne „Invitation sent".
7. [ ] **Glas.** Oba uključe glas. Trener utiša učenika — učenik se zaista ne
   čuje; „Unmute" ga vrati. „Mute all students" — isto. Utišan učenik podigne
   ruku — treneru stigne „wants to speak".
8. [ ] **Dozvola za motor.** Trener uključi motor za učenike, pa učenik uđe —
   prekidač motora mu je odmah dostupan.
9. [ ] **Uloga.** Trener promoviše učenika — samo on dobije obaveštenje; pri
   običnom ulasku nema obaveštenja o ulozi.
10. [ ] **Save position.** Posle nekoliko poteza „Save position"; otvori
    sačuvano — svi potezi su tu.
11. [ ] **Edit positions.** Tutorijalu sa oznakama promeni redosled koraka i
    sačuvaj; oznake su ostale.

## 167. Sigurnosni blok iz revizije — 16.9.2026, nije viđeno uživo

`docs/STANJE-RADA.md`, „Sigurnosni blok iz revizije". Server mora biti
restartovan.

1. [ ] **Registracija i dalje radi.** Nova adresa → kod stiže → unos koda →
   ulaz u aplikaciju. Odjava, prijava istom lozinkom.
2. [ ] **Ponovna registracija menja lozinku.** Registruj adresu lozinkom A, ne
   unosi kod. Registruj istu adresu lozinkom B, unesi najnoviji kod. Prijava
   lozinkom A ne prolazi, lozinkom B prolazi.
3. [ ] **Ulazak u sobu kodom.** Trener pravi sobu; učenik sa prihvaćenom vezom
   ulazi kodom. Nalog bez veze dobija „does not exist, or you are not on its
   guest list" — isti tekst kao za kod koji ne postoji.
4. [ ] **Potezi u sobi.** Trener odigra potez; nijedna crvena traka „no
   permission" nigde. U „Pripremi" (STUDIO) nekoliko poteza — takođe bez trake.
5. [ ] **Snimak se i dalje čuva.** Odrasla osoba sama u svojoj sobi snimi kratko
   i sačuva; snimak je u listi i pušta se.

## 166. Repertoar se gradi na tabli — 16.9.2026, nije viđeno uživo

`docs/PLAN-REPERTOAR-RUCNO.md`. **Pre provere:** obriši postojeće repertoare na
listi, pa u zaglavlju liste „Delete moves from database" za belog i za crnog —
stari podaci su iz modela sa širinom i nacrtima. Server mora biti restartovan i
imati `MASTERS_BOOK_PATH`.

1. [ ] **Nema dugmeta za prihvatanje.** Napravi repertoar za belog od početne
   pozicije i odigraj e4 na tabli. Potez je odmah u stablu; nigde nema „Take",
   „Discard", „Open book", brojača upita, „Suggest main line", „Review
   unconfirmed", „Do not prepare this", „Next" ni „Back to …".
2. [ ] **Najigraniji odgovor ide sa potezom.** Posle e4 u stablu je i c5 (ili
   šta god knjiga kaže da je najigranije), tabla stoji posle tog odgovora i pita
   „What do you play with White?". Poruka ispod kaže koji je odgovor dodat.
   Drugi odgovori (e5, e6…) **nisu** dodati.
3. [ ] **Protivnikov potez se igra na tabli.** Klikni svoj potez e4 u stablu (ili
   strelicom unazad), pa odigraj e5 na tabli. e5 je u stablu kao drugi odgovor, a
   tabla stoji posle njega. Isto za potez koji knjiga ne zna (npr. a6): ulazi u
   stablo bez procenta.
4. [ ] **Ponovo odigran potez ne vraća obrisani odgovor.** Obriši c5 iz stabla
   (dugo pritisni → „Delete this opponent move"), pa ponovo odigraj e4 sa
   početne pozicije. c5 se **ne** vraća.
5. [ ] **Knjiga su čipovi.** Ispod table je red čipova kao u Analizi, sa
   procentom i brojem partija („Nf3 (45%) · 1.1M"). Klik na čip igra potez. Na
   potezu koji je već u repertoaru stoji ★ (glavni) ili ✓. Nema tabele sa
   dugmićima „Play".
6. [ ] **Brisanje pita kad treba.** Obriši svoj potez posle kojeg postoje tvoji
   dalji potezi: pita „Delete …?" i kaže koliko tvojih poteza ide s njim. Potez
   bez ičega iza sebe se briše bez pitanja.
7. [ ] **Govor.** Uključi govor: ne čita se niz poteza, samo pitanje i kratka
   poruka o dodatom potezu. (Broj neodgovorenih pozicija je izgovaran do
   16.9.2026; uklonjen je — vidi stavku 170.)
8. [ ] **Pravilo je na ekranu.** Ispod pitanja stoji rečenica da je svaki potez u
   repertoaru odigran na tabli i savet „For your side, prefer one move per
   position; for the opponent, enter one or more."
9. [ ] **Dril.** „Drill" posle nekoliko poteza: protivnik igra samo poteze koje si
   uneo (i dodati najigraniji), nikad nešto što nije u stablu.
10. [ ] **Pokrivenost.** Mapa repertoara prikazuje brojeve („3 decided · 1 open")
    umesto procenata, bez „not preparing".

## 165. Panel otvaranja iz naše knjige, bez ChessDB i bez rejtinga — 15.9.2026, nije viđeno uživo

`docs/PLAN-OTVARANJA-LOKALNO.md`, faza 4 (batch 71, `46c2cb2`). Server mora
biti restartovan i imati `MASTERS_BOOK_PATH`.

1. [ ] **Panel u Analizi, prijavljen.** Otvori Analizu i odigraj 1. e4: naslov
   panela je ime otvaranja („King's Pawn Game" sa ECO kodom), ispod je broj
   partija, a procenti poteza se sabiraju do najviše 100 — nema padajuće liste
   rejtinga ni pomena ChessDB-a. Klik na potez ga igra.
2. [ ] **Dublje od knjige.** Učitaj poziciju posle 26+ poteza neke partije: panel
   kaže „This position is deeper than the opening book goes.", a ne „No master
   game reached this position.".
3. [ ] **Gost.** Odjavi se i otvori Analizu: panel kaže „Sign in to see the
   opening book." i ne prikazuje poteze.
4. [ ] **Server bez knjige.** Zakomentariši `MASTERS_BOOK_PATH`, restartuj:
   panel kaže „The opening book is not available on this server.". Vrati
   putanju.
5. [ ] **Settings.** Nema odeljka „OPENING EXPLORER" ni polja za Lichess token;
   ostatak ekrana stoji kako je stajao.
6. [ ] **Repertoar.** Na listi repertoara nema ikonice „Opponent rating", a
   ispod stabla u gradnji piše samo „Breadth: …", bez „Book: games from …+".

## 164. Sudija i repertoar bez Lichess tokena — 15.9.2026, nije viđeno uživo

`docs/PLAN-OTVARANJA-LOKALNO.md`, faze 0 i 3 (STANJE-RADA, „Otvaranja iz naše
baze"). Server mora biti restartovan, jer se putanja knjige čita pri
pokretanju. Sačuvani odgovori u razvojnoj bazi su 15.9.2026 u 13:09 prepisani
iz fajla od 50 polupoteza.

1. [ ] **Nalog koji nikad nije video lichess.org.** (Posle faze 4 polja za
   token više nema, a sačuvan token se briše pri pokretanju.) U Analizi odigraj potez i pritisni
   „Judge …": presuda stiže, i nigde na panelu se ne pominje token.
2. [ ] **Repertoar od nule.** Istim nalogom napravi nov repertoar i pusti
   „Suggest main line" na 12 poteza. Linija se upiše; ako stane pre kraja,
   rečenica kaže zašto — „too thin" sa brojem partija, ili „where the opening
   book ends", a ne jedno umesto drugog.
3. [ ] **Stari repertoar i dalje ima grane.** Otvori repertoar koji je postojao
   pre ove promene: stablo crta protivnikove odgovore kao i ranije, a drill ih
   igra.
4. [ ] **Server bez knjige.** Zakomentariši `MASTERS_BOOK_PATH` u `.env`,
   restartuj, i pritisni „Judge …": panel kaže „The opening book is not
   available on this server", a ne presudu. Vrati putanju.
5. [ ] **Izveštaj o rupama.** „Judge moves" u izveštaju o otvaranjima radi bez
   tokena i ne prikazuje baner o tokenu.

## 163. Izlazak iz masters baze, i kraj linije bez reči — 15.9.2026, nije viđeno uživo

Tri prijave vlasnika od 15.9.2026 (STANJE-RADA, „Izlazak iz masters baze…").
Isto što i stavka 162: server mora biti restartovan, jer se šablon prompta čita
pri pokretanju.

1. [ ] **„And the line goes on" više nema.** Kroz ceo tutorijal — u delu sa
   najboljom linijom i u delu sa drugim najboljim potezom — nijedna rečenica ne
   kaže samo da se linija nastavlja („the line goes on", „and the line
   continues"). Tamo gde potez nema šta da kaže, tabla ćuti.
2. [ ] **Statistika stoji na pravoj poziciji.** Rečenica „Up to here the game
   followed the masters database: N master games reached this position and
   played …" pojavljuje se **na potezu pre** onog kojim se izašlo iz baze — dakle
   dok je na tabli poslednja pozicija koja je zaista bila u bazi — i tek posle nje
   se odigra potez koji je igrač odigrao.
3. [ ] **Strelice.** Na toj istoj poziciji nacrtane su **zelene strelice** za one
   poteze koje rečenica nabraja (jedan do tri), a ne za odigrani. Proveri i u
   videu.
4. [ ] **Broj se slaže.** N u rečenici je broj partija koje su stigle do pozicije
   na tabli, a ne do one posle poteza. Ako je moguće, uporedi sa Lichess
   masters explorer-om za tu poziciju.
5. [ ] **Studija, a ne cela partija.** Otvori u Analizi poziciju koja nije
   početna (FEN ili studija), odigraj nekoliko poteza kao glavnu liniju, dodaj
   jednu sporednu liniju sa komentarom, pa „Make a tutorial from this game".
   Očekivano: radi, polazi od te pozicije, ide **samo glavnom linijom**, a
   sporedna linija i postojeći komentari se **ne** koriste. Ako partija nema bar
   dva poteza koja koštaju dovoljno, kaže se da nema od čega da se pravi
   tutorijal i ništa se ne troši.

## 162. Tutorijal iz partije kao priča — 15.9.2026, nije viđeno uživo

`docs/PLAN-NARACIJA.md`: novi prompt (priča) potpuno zamenjuje stari. Mereno na
deset partija iz harnessa, ali **nijedan tutorijal iz aplikacije sa novim
promptom nije napravljen uživo**. Treba nova partija (ili ista, ponovo: činjenice
su keširane, pa motor ide brzo, a reči se plaćaju ponovo). Server mora da bude
restartovan, jer se šablon prompta čita pri pokretanju.

1. [ ] **Nema najave poteza.** Kroz ceo tutorijal nijedna rečenica ne počinje sa
   „White plays …" niti kaže „the queen from d8 to c7".
2. [ ] **Greška ide redom.** Na momentu greške: deo bez poteza koji kaže „In this
   position White played Bd3. The best move was…", sa **plavom strelicom** tog
   poteza na tabli (potez se ne odigra); sledeći deo igra najbolju liniju; zatim
   (ako postoji) drugi najbolji potez; zatim partija nastavlja odigranim potezom.
   Proveri i u videu da se strelica vidi.
3. [ ] **Početak i kraj.** Prva rečenica tutorijala kaže kakva partija sledi
   (mirna ili puna preokreta, taktička ili poziciona) i ne otkriva pobednika;
   poslednja (na poslednjem potezu partije, ne na rekapitulaciji) kaže ko je
   izašao kao pobednik i zašto. „The game ended here." se ne pojavljuje.
4. [ ] **Prekretnice.** Tamo gde je partija promenila tok, rečenica to kaže
   („takes the chance", „lets the chance go", „the first mistake of the game…"),
   i to se slaže sa onim što se vidi na tabli.
5. [ ] **Rekapitulacija.** Poslednji deo „Looking back, the game turned on …" ne
   pominje pešake (cenu), a na tabli je plava strelica odigranog poteza.
6. [ ] **„Sentences to check".** U poslednjem dijalogu lista je kratka ili prazna;
   ako nije, pročitaj te rečenice — to je nalaz za proveru tvrdnji.
