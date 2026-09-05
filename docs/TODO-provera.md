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

## 104. Fokus u stablu i lepeza u turi — 5.9.2026, nije viđeno uživo

Faze 1 i 4 iz `docs/PLAN-TABLA-I-STABLO.md`. Faza 3 (fiksna tabla) ide u zasebnu
stavku kad se spoji.

### A. Crtež stiže do pozicije na kojoj stojiš (faza 1)

Ovo se vidi **samo pri užoj širini**, jer pri „standard" i „broad" retko koji
potez ispadne iz reza. Postaviti repertoar na **„Samo glavna linija"** pre
provere.

1. [ ] **Odigraj potez za protivnika koji nije glavni odgovor** (drugi ili treći
   po učestalosti). U stablu se **odmah pojavi kartica** za tu poziciju, a
   označena je **ta** kartica — ne koren repertoara.
2. [ ] **Isto važi i kad potez prihvatiš iz spiska ispod table** („Potvrdi",
   „Uzmi …"), ne samo kad ga povučeš po tabli. Pravilo visi o tome da si potez
   odobrio, ne kojim putem.
3. [ ] **Idi dva-tri poteza dublje niz tu granu.** Fokus ostaje na poslednjem
   potezu na svakom koraku — nijednom se ne vrati na početak. Ovo je „baca me
   negde" iz prijave.
4. [ ] **Ostatak stabla nije nestao.** Glavna linija i sve ostalo su i dalje
   nacrtani; ovo dodaje tvoju poziciju, ne sužava crtež na nju.
5. [ ] **Prebaci širinu na „standard" i nazad.** Ništa se ne gubi ni ne duplira.

### C. Tabla stoji, ostatak se skroluje (faza 3)

10. [ ] **Skroluj ispod table na telefonu.** Tabla i navigaciona paleta ispod
    nje **ostaju na mestu**; pomera se samo ono ispod — komentar, pitanje,
    odgovori, kontrole, stablo.
11. [ ] **Tabla nije isečena ni na jednom ekranu**, a ispod palete uvek ima šta
    da se skroluje. Proveriti i na uskom prozoru na Windowsu, ne samo na
    telefonu.
12. [ ] **Baner je niži.** „N nepotvrđenih u grafu" sada zauzima oko pola
    prostora koliko ranije. Natpisi su isti — ništa nije skraćeno.
13. [ ] **Dugme „Pregledaj nepotvrđene" se i dalje lako pogađa prstom.** Ovo je
    jedina stvar koju je sažimanje moglo da pokvari: dugme je sada niže (32 px
    umesto 48). Ako je nezgodno pogoditi ga, reci — vraća se u jednom redu.
14. [ ] **Tabla je možda malo manja nego ranije** na običnom telefonu (oko 16 px
    manja stranica), a ispod nje ima oko 100 px više. Ako ti je tabla premala,
    to je jedan broj koji se menja.

### D. Šansa linije i pogled na jednu granu (faza 5)

15. [ ] **Zadrži pokazivač nad kartom u stablu** (ili je dugo pritisni na
    telefonu): piše „Šansa linije: X% (u okviru pokrivenog repertoara)".
    Rečenica mora da bude cela — zagrada nije ukras, bez nje broj laže.
16. [ ] **Broj ima smisla.** Na tvom potezu je isti kao na poziciji pre njega
    (tvoj izbor nije verovatnoća), a na protivnikovom se množi njegovom
    učestalošću. Dublje u liniji broj pada.
17. [ ] **Uporedi na dve širine.** Na „samo glavna linija" isti čvor pokazuje
    osetno veći procenat nego na „standard" — to je tačno i baš zato stoji
    zagrada. Ako ti ta rečenica i dalje deluje nejasno, reci kako bi je ti
    napisao.
18. [ ] **„Prikaži samo od ove pozicije".** Dugme iznad stabla: crtež se svede
    na granu ispod pozicije na tabli, a putanja iznad stabla i dalje čita od
    prvog poteza.
19. [ ] **„Prikaži ceo repertoar" vraća sve.**
20. [ ] **Suženje se samo pušta** kad tablom odeš iznad te pozicije ili u drugu
    granu — crtež se vrati na ceo repertoar bez pritiska na dugme.
21. [ ] **Na kartici nema ocene motora**, a legenda iznad stabla je više ne
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
26. [ ] **Dugme „Pregledaj nepotvrđene" iz zaglavlja radi** i vodi na prvu
    nepotvrđenu poziciju, isto kao ranije.
27. [ ] **Suzi prozor ispod 1200 dp.** Oba se vraćaju iznad table i sve radi kao
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

29. [ ] **Kretanje kroz liniju ne pomera crtež.** Sa uzumiranim stablom idi
    potez po potez dok je aktivna kartica na sredini ekrana. Crtež **stoji** —
    ne skače, ne pomera se ni za piksel. Ovo je „izgubi fokus" iz prijave.
30. [ ] **Kad kartica priđe ivici, crtež se pomeri malo.** Nastavi niz liniju do
    dna vidljivog dela: crtež se pomeri **tek toliko** da kartica uđe unutra, sa
    oko jedne kartice mesta do ivice. Ne skače na sredinu.
31. [ ] **Zum se pri tome ne menja.** Veličina kartica je posle celog hoda ista
    kao pre. Ovo je pola prijave i mora da se pogleda odvojeno od pomeranja.
32. [ ] **Dugme „Centriraj na aktivni potez" i dalje centrira.** Ono je
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
