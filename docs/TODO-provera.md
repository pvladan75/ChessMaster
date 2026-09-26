# TODO — šta još nije provereno uživo

Sve ovde je napravljeno i prolazi testove, ali **niko nije video kako radi
uživo**. Automatski testovi pokrivaju logiku; ne pokrivaju da li je dugme na
pravom mestu i da li tok ima smisla.

Spisak je preuređen 25.9.2026: stavke su poređane **po mestu u aplikaciji**.
Prvo oblast — tabovi `Home`, `Practise`, `Analyse`, `Teach`, pa soba, nalog,
podešavanja i server — a u oblasti ekran. Prolazi se oblast po oblast, ekran po
ekran; na istom ekranu novije stavke stoje prve.

Svaka stavka ima isti oblik:

- **O čemu se radi** — šta je ta funkcija i šta je menjano, da se zna na šta se
  stavka odnosi.
- **Gde** — putanja od početka aplikacije. Ono u `ovakvoj` oznaci je natpis
  tačno kako stoji u aplikaciji (aplikacija je na engleskom); ono u zagradi je
  opis, ne natpis.
- **Uradi** — koraci, redom.
- **Treba da vidiš** — šta mora da se vidi da bi stavka prošla. Ako se vidi
  nešto drugo, to je nalaz.
- **Potrebno** — na čemu (Windows, telefon ili oba) i šta mora da bude spremno.

Broj u uglastoj zagradi, npr. [243.2], je broj stavke u starom spisku: odeljak
243, stavka 2. Po njemu se na stavku pozivaju drugi dokumenti i komentari u
kodu. Stari spisak, ceo i sa odgovorima, je u
[arhiva/TODO-provera-26.8-do-25.9.2026.md](arhiva/TODO-provera-26.8-do-25.9.2026.md) — tamo piše i šta je potvrđeno, šta je
otpalo pre provere i zašto. Stavke zatvorene pre 26.8.2026 su u
[arhiva/TODO-provera-do-26.8.2026.md](arhiva/TODO-provera-do-26.8.2026.md).

Stavka se štiklira tek kad vlasnik potvrdi da radi uživo — u alatu za proveru
ili ovde, sa datumom.

## Priprema

Ono što većina stavki traži, jednom pre provere:

- **Server:** `D:\Projekti\pokreni.ps1` → [1] Backend. Ako `npm run dev` stoji
  na startu bez poruke, ovaj računar je ispao sa liste dozvoljenih adresa na
  bazi (Trusted Sources) — nije lozinka.
- **Tablebase**, samo za stavke koje ga traže: `pokreni.ps1` → [5] Tablebase.
- **Aplikacija:** `pokreni.ps1` → [2] Aplikacija; `install.ps1` pita za
  platformu i build. Glavni prolaz je *release*. *Debug* samo za stavke koje to
  traže: u release-u se prelivanje (žuto-crne pruge) ne crta, dugme koje je
  ispalo van ekrana prosto nema.
- **Telefon:** na istom Wi-Fi-ju kao računar, jer aplikacija ide na backend na
  računaru. Ako Windows radi a telefon javlja grešku mreže, to je Windows
  Firewall koji ne pušta port 3000 sa drugog uređaja.
- **Dva naloga** za stavke sa „nalog trenera i učenika": jedan nalog pošalje
  poziv drugom, drugi ga prihvati. Najlakše je jedan na računaru, drugi na
  telefonu.
- **Podaci:** uvezene sopstvene partije (arhiva, izveštaj o otvaranjima,
  greške), jedan PGN fajl sa varijantama i komentarima, jedna PDF knjiga sa
  dijagramima.
- **Alat za proveru:** `pokreni.ps1` → [3]. Sam spoji ovaj spisak, napravi
  stranicu i pokrene je; odgovori ostaju u alatu, a posle prolaza se prenose
  ovde.

Nova stavka (za sledeće sesije) ide u svoju oblast i pod svoj ekran — nov
`###` ako ga nema — u istom obliku, sa sledećim slobodnim brojem u zagradi:
[246.1], [246.2] … za prvu seriju posle 25.9.2026, [247.1] … za
`docs/PLAN-MAPA-DELOVA.md` (26.9.2026). Datum i plan idu u „O čemu
se radi". **Tekst stavke na koju je već odgovoreno u alatu se ne menja**: alat
je prepoznaje po tekstu, pa izmenjena stavka postaje nova, a stari odgovor
odlazi na kraj spiska u alatu.

## Nalog i prijava

### Nalog i prijava — Prijava i registracija

1. [ ] **Registracija trenera i deteta uz lokalni SMTP.** [S35.b934]
   O čemu se radi: Kod lokalno podešenog SMTP-a kod za verifikaciju emaila
   stvarno stiže na poštu — ovo je priprema za proveru stavki o sobama,
   godinama i saglasnosti roditelja.
   Gde: Ekran za prijavu → `Don't have an account? Register with email`.
   Uradi: Registrovati nov nalog trenera i nov nalog deteta preko email
   registracije, sa lokalno podešenim SMTP-om.
   Treba da vidiš: Oba naloga prime kod za verifikaciju na mejl i uspešno se
   prijave (ekran `Enter Verification Code`).
   Potrebno: Windows i telefon; server.

2. [ ] **Uređaj sa obrisanim nalogom se sam odjavljuje.** [38.b1284]
   O čemu se radi: Prijava na uređaju važi dok ne istekne, ali sama ne dokazuje
   da nalog još postoji. Server na svaki zahtev proverava da li nalog postoji;
   ako ne postoji, aplikacija sama odjavi uređaj.
   Gde: (pokretanje aplikacije) → kratko `Home` → automatski → `Sign In`.
   Uradi: Na test-nalogu koji je i dalje zapamćen na ovom uređaju obriši taj
   red iz tabele naloga na serveru (server neka ostane upaljen), pa ponovo
   pokreni aplikaciju na tom uređaju.
   Treba da vidiš: Aplikacija ne ostaje na `Home` — u roku od par sekundi
   prebacuje na `Sign In` sa porukom "This account no longer exists on the
   server." iznad forme za prijavu.
   Potrebno: Windows i telefon; server.

3. [ ] **Ponovna registracija iste adrese menja lozinku na najnoviji kod.**
   [167.2]
   O čemu se radi: Ako se ista adresa registruje dva puta sa različitim
   lozinkama, važi lozinka potvrđena poslednjim unesenim kodom.
   Gde: `Register with email`.
   Uradi: Registruj adresu lozinkom A, ne unosi kod. Registruj istu adresu
   lozinkom B, unesi najnoviji stigli kod. Probaj prijavu lozinkom A, pa
   lozinkom B.
   Treba da vidiš: Prijava lozinkom A ne prolazi; prijava lozinkom B prolazi.
   Potrebno: Windows; internet.

4. [ ] **Zapamćen token obrisanog naloga se odbija (account-gone).** [S35.b936]
   O čemu se radi: Ako nalog na uređaju ostane prijavljen zapamćenim tokenom
   (`Remember me`) čiji je red u bazi obrisan (ili je ID ponovo iskorišćen
   posle „RESTART IDENTITY"), aplikacija to mora da otkrije umesto da tiho
   izgleda prijavljeno.
   Gde: Ekran za prijavu → kvačica `Remember me`.
   Uradi: Prijaviti se uz `Remember me`, pa nalogu u bazi obrisati red (ili
   resetovati ID sekvencu), pa ponovo pokrenuti aplikaciju na tom uređaju.
   Treba da vidiš: Aplikacija ne ostaje tiho prijavljena — prva provera
   prepoznaje da nalog više ne postoji i vraća na ekran za prijavu.
   Potrebno: Windows i telefon; server.

5. [ ] **Registracija i odjava/prijava i dalje rade.** [167.1]
   O čemu se radi: Osnovni tok naloga posle sigurnosnog pregleda 16.9.2026.
   Gde: `Sign in with email` / `Register with email`.
   Uradi: Registruj se sa novom adresom, unesi kod koji stigne, pa se odjavi i
   ponovo prijavi istom lozinkom.
   Treba da vidiš: Registracija, unos koda i ponovna prijava rade bez greške.
   Potrebno: Windows; internet.

### Nalog i prijava — Godina rođenja

1. [ ] **Nemoguća godina: poruka, ništa se ne šalje.** [35.b1100]
   O čemu se radi: Nemoguća godina rođenja (van 1900–ova godina, ili prazno)
   mora da bude odbijena na uređaju, bez ijednog zahteva serveru.
   Gde: Ekran za prijavu → age gate → polje `Birth year`.
   Uradi: Upisati 2999, pa 1899, pa ostaviti prazno, i svaki put pritisnuti
   `Save`.
   Treba da vidiš: Poruka poput „Enter a birth year between 1900 and <ova
   godina>." — ništa se ne šalje na server, ekran ostaje otvoren.
   Potrebno: Windows i telefon.

2. [ ] **Ugašen backend: pitanje ostaje otvoreno uz poruku.** [35.b1102]
   O čemu se radi: Ako backend nije dostupan dok se godina čuva, pitanje mora
   da ostane otvoreno uz poruku, a ne da se tiho zatvori kao da je uspelo.
   Gde: Ekran za prijavu → age gate → polje `Birth year`.
   Uradi: Ugasiti backend, upisati ispravnu godinu i pritisnuti `Save`.
   Treba da vidiš: Pitanje ostaje otvoreno, uz poruku
   `Server is not available — check if the backend is running.`.
   Potrebno: Windows i telefon.

3. [ ] **Prag iz .env se vidi u tekstu pitanja.** [35.b1110]
   O čemu se radi: Prag godina se čita iz podešavanja servera i ispisuje se u
   tekstu age gate ekrana, ne fiksno na 16.
   Gde: Ekran za prijavu → age gate → polje `Birth year`.
   Uradi: Postaviti AGE_OF_CONSENT=13 u chess_backend/.env, restartovati
   backend, otvoriti age gate na nalogu bez upisane godine.
   Treba da vidiš: Tekst pominje prag 13 (rečenica oblika „Parental consent is
   required for anyone under 13."), ne fiksnih 16. Vratiti na 16 posle provere.
   Potrebno: Windows i telefon.

4. [ ] **Gost ne dobija pitanje za godinu.** [35.b1088]
   O čemu se radi: Gost (bez prijave) nema nalog kome bi se godina upisala, pa
   pitanje za njega ne sme da se pojavi.
   Gde: `Continue as Guest` na ekranu za prijavu.
   Uradi: Ući u aplikaciju kao gost, bez prijave.
   Treba da vidiš: Pitanje za `Birth year` se ne pojavljuje.
   Potrebno: Windows i telefon.

5. [ ] **Već prihvaćena veza: trener dobija obaveštenje, status se ne menja.**
   [36.b1207]
   O čemu se radi: Kad nalog sa VEĆ prihvaćenom vezom naknadno upiše
   maloletničku godinu, treneru se javlja obaveštenje, ali sama veza (status i
   pravo na mikrofon) ostaje nepromenjena — „javi, ne menjaj".
   Gde: Nalog sa već prihvaćenom vezom → `Settings` (zupčanik) → red
   `Birth year` → upisati maloletničku godinu.
   Uradi: Na nalogu koji već ima prihvaćenu vezu sa trenerom, upisati godinu
   rođenja koja ga čini maloletnim.
   Treba da vidiš: Treneru stigne obaveštenje o tome da je učenik upisao godinu
   rođenja (rečenica pominje da je mikrofon sada trenerova odluka), a status
   veze i pravo na mikrofon ostaju nepromenjeni.
   Potrebno: Windows i telefon; nalog trenera i učenika.

6. [ ] **Punoletan nalog upiše godinu: nema obaveštenja.** [36.b1210]
   O čemu se radi: Kad punoletan nalog upiše godinu rođenja, nema razloga da
   bilo ko bude obavešten.
   Gde: Nalog sa već prihvaćenom vezom → `Settings` (zupčanik) → red
   `Birth year` → upisati punoletnu godinu.
   Uradi: Upisati godinu rođenja koja nalog čini punoletnim (na nalogu koji je
   već imao vezu).
   Treba da vidiš: Nijedno obaveštenje ne odlazi treneru.
   Potrebno: Windows i telefon; nalog trenera i učenika.

7. [ ] **Google prijava takođe pita za godinu rođenja.** [35.b1080]
   O čemu se radi: Age gate (pitanje za godinu rođenja) se oslanja na jednu
   proveru za svaki način prijave, uključujući Google.
   Gde: `Sign in / Register with Google` (na ekranu za prijavu) → prvi put u
   aplikaciji.
   Uradi: Prijaviti se prvi put preko Google naloga koji još nema upisanu
   godinu rođenja.
   Treba da vidiš: Pitanje za `Birth year` prekriva ceo ekran, isto kao i posle
   obične registracije.
   Potrebno: Windows i telefon.

8. [ ] **Odjava sa age gate ekrana radi.** [35.b1105]
   O čemu se radi: Age gate je obavezan ekran (nema Cancel), ali mora da ostavi
   izlaz preko odjave.
   Gde: Ekran za prijavu → age gate → `Sign out`.
   Uradi: Na obaveznom pitanju za godinu pritisnuti `Sign out`.
   Treba da vidiš: Nalog se odjavljuje — ekran nije ćorsokak.
   Potrebno: Windows i telefon.

### Nalog i prijava — Veza trener–učenik i roditelj

1. [ ] **Ugašen server ne odjavljuje, samo javlja da nema veze.** [38.b1287]
   O čemu se radi: Razlika između "nalog je obrisan" i "server je nedostupan"
   mora ostati vidljiva — ugašen backend ne sme izgledati kao obrisan nalog,
   jer bi to odjavilo svakog korisnika pri svakom ispadu servera.
   Gde: `Home` → (kartica dobrodošlice, obaveštenje o vezi).
   Uradi: Ugasi backend na uređaju koji je već prijavljen, pa otvori ili osveži
   `Home`.
   Treba da vidiš: Ostaješ prijavljen na `Home`; ispod pozdrava piše "No
   connection to server — sign-in is saved on the device, but nothing is being
   saved or loaded." — nema odjave ni prebacivanja na `Sign In`.
   Potrebno: Windows i telefon.

2. [ ] **Dete bez emaila roditelja prihvata poziv.** [36.b1197]
   O čemu se radi: Dete bez upisane adrese roditelja koje prihvati poziv
   trenera ne sme da izazove slanje mejla nikome — mora jasno da kaže da adrese
   nema.
   Gde: Nalog deteta (bez upisanog emaila roditelja) → ikonica zvona
   (`Notifications and Invitations`) → `Accept`.
   Uradi: Prihvatiti poziv trenera sa nalogom deteta koje nema upisanu adresu
   roditelja.
   Treba da vidiš: Poruka kaže da adrese roditelja nema (i da je treba upisati
   u Podešavanjima), veza ostaje „čeka roditelja", i nijedan mejl ne odlazi.
   Potrebno: Windows i telefon; nalog trenera i učenika.

3. [ ] **Nova pozivnica trener-učenik je engleska.** [132.1]
   O čemu se radi: Poruke koje server upisuje u obaveštenja su prevedene
   8-9.9.2026 — svaka NOVA poruka je engleska. Stare, upisane pre te izmene,
   ostaju srpske i to je očekivano (podaci se ne prepisuju).
   Gde: Zvonce za obaveštenja u zaglavlju (pored `Settings` ikonice) →
   `Notifications and Invitations`.
   Uradi: Napravi novu vezu trener-učenik (pošalji zahtev sa jednog naloga na
   drugi) i otvori zvonce za obaveštenja na primaocu.
   Treba da vidiš: Nova poruka je na engleskom (npr. „... wants to enroll you
   as a student.” ili „... wants you to be their trainer.”). Ako neka STARA
   poruka u istoj listi ostane srpska, to je očekivano, ne kvar.
   Potrebno: Windows i telefon; nalog trenera i učenika.

4. [ ] **Prazan PUBLIC_BASE_URL: veza ostaje „čeka roditelja"** [36.b1140]
   O čemu se radi: Prazan (ne neispravan) PUBLIC_BASE_URL ne sme da spreči
   server, ali mora da spreči da veza tiho pređe u prihvaćeno bez poslatog
   mejla roditelju.
   Gde: (isprazniti PUBLIC_BASE_URL u chess_backend/.env), pa `Teach` →
   prihvatiti zahtev maloletnika.
   Uradi: Isprazniti PUBLIC_BASE_URL, restartovati backend, pa prihvatiti
   zahtev za povezivanje sa maloletnim nalogom.
   Treba da vidiš: Server radi; poruka kaže da mejl roditelju nije poslat, a
   veza ostaje na „čeka saglasnost roditelja" — ne prelazi tiho u prihvaćeno.
   Potrebno: server; nalog trenera i učenika; server.

5. [ ] **Maloletnik kao učenik šalje zahtev punoletnom treneru.** [33.b1036]
   O čemu se radi: Provera godina blokira samo maloletnika u ulozi trenera; kao
   učenik maloletnik normalno šalje zahtev za povezivanje.
   Gde: `Teach` → (kartica „Students and trainers") → `I am a student` → uneti
   email trenera → `Send a request`.
   Uradi: Sa maloletnim nalogom (upisana godina koja ga čini maloletnim)
   poslati zahtev punoletnom treneru, birajući `I am a student`.
   Treba da vidiš: Zahtev prolazi normalno, bez poruke o godinama.
   Potrebno: Windows i telefon; nalog trenera i učenika.

## Home

### Home — Domaći i lekcije (My Assignments)

1. [ ] **Poslat tutorijal je video koji učenik skida.** [246.1]
   O čemu se radi: Od 25.9.2026 učeniku se ne šalje tutorijal nego njegov
   video (`docs/PLAN-TUTORIJAL-VIDEO.md`, faze 2–3). Učenik ga skida, a zadatak
   je urađen kad ceo fajl stigne. Da li je gledan, ne zna niko.
   Gde: (kao učenik) `Home` → `Set for me` → red sa videom.
   Uradi: Kao trener pošalji tutorijal koji ima video (vidi [246.4]). Kao
   učenik otvori ga i pritisni `Download video`; kad pregledač završi, vrati se
   u aplikaciju.
   Treba da vidiš: Na ekranu `Tutorial video` naslov, napomena trenera, dužina
   i rezolucija (npr. „3 min 14 s · 720p") i `Not downloaded yet.`; dodir
   otvara pregledač koji skida fajl; po povratku piše „Downloaded on 25.9.2026."
   (današnji datum) i dugme je `Download again`. U spisku red kaže
   „Video · downloaded".
   Potrebno: Windows **i** telefon — pregledač koji skida je drugačiji, a
   server beleži samo skidanje koje je stiglo do kraja; nalog trenera i
   učenika; backend pokrenut sa novim kodom.

2. [ ] **Prekinuto skidanje se ne računa.** [246.2]
   O čemu se radi: Zadatak se beleži kao urađen tek kad server pošalje
   poslednji bajt fajla; prekinuto skidanje ne beleži ništa.
   Gde: (kao učenik) `Home` → `Set for me` → red sa videom.
   Uradi: Pritisni `Download video` i u pregledaču otkaži preuzimanje pre
   kraja. Vrati se u aplikaciju.
   Treba da vidiš: I dalje `Not downloaded yet.`, a trener ne dobija
   obaveštenje. Posle jednog celog skidanja: „Downloaded on …".
   Potrebno: Windows; video dovoljno dug da se skidanje stigne prekinuti.

3. [ ] **Video u domaćem otvara zaključanu stavku iza sebe.** [246.3]
   O čemu se radi: Stavka `A tutorial video` u domaćem je urađena kad se video
   skine, pa se otključava stavka iza nje koja čeka na prethodnu.
   Gde: (kao trener) domaći → dodaj stavku → `A tutorial video`; (kao učenik)
   `Home` → `Set for me` → domaći.
   Uradi: Napravi domaći: prvo video, iza njega bilo koja stavka sa bravom
   (ne pre nego što je prethodna urađena). Pošalji ga. Kao učenik skini video.
   Treba da vidiš: Pre skidanja druga stavka je zaključana; posle skidanja je
   otključana, a kod videa piše `Video downloaded`.
   Potrebno: nalog trenera i učenika; tutorijal sa videom.

4. [ ] **Desni klik na tabli u domaćem ne kopira FEN.** [193.3]
   O čemu se radi: Dok se domaći rešava, ne sme biti puta do motora, Analize ni
   FEN-a (pravilo iz faze 12) — uključujući prečicu za kopiranje FEN-a desnim
   klikom.
   Gde: Home → `Set for me` → My Assignments → domaći → stavka sa pozicijama
   ili tutorijal iz domaćeg.
   Uradi: Otvori stavku sa pozicijama (ili tutorijal) unutar domaćeg i klikni
   desnim tasterom miša na tablu.
   Treba da vidiš: Ništa se ne dešava — nema kontekst menija, ne pojavljuje se
   poruka o kopiranju, u clipboard-u ostaje šta je i bilo.
   Potrebno: Windows; nalog trenera i učenika.

5. [ ] **Ctrl+C u domaćem ne kopira FEN.** [193.4]
   O čemu se radi: Ista zabrana kao kod desnog klika (faza 12): dok se stavka
   domaćeg rešava, prečica za kopiranje pozicije je isključena.
   Gde: Home → `Set for me` → My Assignments → bilo koja stavka domaćeg.
   Uradi: Otvori bilo koju stavku domaćeg i pritisni Ctrl+C dok je tabla u
   fokusu.
   Treba da vidiš: U clipboard-u posle toga nije FEN te pozicije (proveri
   nalepivši ga u editor teksta).
   Potrebno: Windows; nalog trenera i učenika.

6. [ ] **Posle odgovora, desni klik u stavci domaćeg opet kopira FEN.**
   [193.7]
   O čemu se radi: Zabrana motora/Analize/FEN-a važi samo dok se stavka rešava;
   jednom kad je stavka odgovorena (ili taktički zadatak rešen), kopiranje
   pozicije se vraća.
   Gde: Home → `Set for me` → My Assignments → domaći → već odgovorena stavka
   sa pozicijom ili rešen taktički zadatak.
   Uradi: Odgovori na stavku sa pozicijom (ili reši taktički zadatak), pa
   probaj desni klik na tabli te iste, već odgovorene stavke. Zatim probaj dva
   netačna pokušaja na još nerešenoj stavci.
   Treba da vidiš: Na već odgovorenoj stavci desni klik ponovo kopira FEN. Dva
   netačna pokušaja na nerešenoj stavci i dalje ne otvaraju ništa.
   Potrebno: Windows; nalog trenera i učenika.

7. [ ] **Učenik vidi istu presudu i isti pregled partije.** [190.6]
   O čemu se radi: Pregled odigrane partije nije samo trenerov — učenik na svom
   domaćem vidi iste presude i isti sadržaj pregleda.
   Gde: Home → `Set for me` → My Assignments → domaći → stavka odigrane
   partije.
   Uradi: Kao učenik otvori istu odigranu „Play it out“ stavku i njen pregled.
   Treba da vidiš: Presuda (Goal met / Goal not met) i sadržaj pregleda su isti
   kao što ih vidi trener.
   Potrebno: Windows i telefon; nalog trenera i učenika.

8. [ ] **„Win for 2 moves“ čeka server pre nego što kaže presudu.** [186.7]
   O čemu se radi: Kad partija ima ≤7 figura, presudu daje tablebase preko
   servera; posle poslednjeg dozvoljenog poteza tabla staje, a presuda se ne
   ispisuje dok server ne odgovori.
   Gde: Home → `Set for me` → My Assignments → domaći → „Play it out: play 2
   moves“ (≤7 figura, cilj Win).
   Uradi: Kao učenik odigraj oba dozvoljena poteza te stavke.
   Treba da vidiš: Posle drugog poteza partija stane; „Goal met“ ili „Goal not
   met“ se pojavljuje tek malo kasnije, kad server odgovori — ne odmah.
   Potrebno: Windows i telefon; nalog trenera i učenika; tablebase (pokreni.ps1
   [5]).

9. [ ] **Bez veze ka tablebase-u, stavka ostaje „not judged yet“** [186.8]
   O čemu se radi: Ako server ne može da pita tablebase, to se ne tumači kao
   neuspeh — stavka ostaje otvorena za docniju presudu, a sledeća stavka
   domaćeg se ipak otključava.
   Gde: Home → `Set for me` → My Assignments → domaći → „Play it out“ stavka
   (≤7 figura).
   Uradi: Odigraj tu stavku do kraja u trenutku kad server nema vezu ka
   tablebase-u (ili je simuliraj). Zatim zatvori i ponovo otvori domaći
   kasnije.
   Treba da vidiš: Odmah po završetku piše „not judged yet“, a red u domaćem
   pokazuje „Played — not judged yet“ sa ikonicom peščanog sata; sledeća stavka
   je otključana. Kad se domaći kasnije ponovo otvori, presuda je stigla.
   Potrebno: Windows i telefon; nalog trenera i učenika.

10. [ ] **Preskakanje u domaćem i dalje ne beleži pokušaj.** [176.6]
   O čemu se radi: Novo brojanje pokušaja (stavka 176) namerno ne dira domaći —
   tamo i dalje važi jedan pokušaj po stavci, kao pre.
   Gde: Home → `Set for me` → My Assignments → domaći sa zagonetkom.
   Uradi: U stavci domaćeg preskoči zagonetku (ako postoji ta opcija) ili je
   pogrešno odgovori, pa proveri napredak domaćeg.
   Treba da vidiš: Preskakanje/pokušaj u domaćem ne menja ništa u brojanju van
   onoga što je već i ranije beleženo — nema nove linije napretka.
   Potrebno: Windows i telefon; nalog trenera i učenika.

11. [ ] **Pogrešan potez u Find zadatku pokazuje rešenje i zaključava tablu.**
   [198.2]
   O čemu se radi: Od 20.9.2026 je „Find the move“ svuda jedan potez — stara
   mašinerija za nizove poteza ([]„Try again“, „Keep going“) je obrisana. Ovo
   proverava šta se dešava kad učenik promaši.
   Gde: Home → `Set for me` → My Assignments → domaći sa `Find the move`
   stavkom.
   Uradi: Otvori tu stavku kao učenik i odigraj potez koji nije rešenje.
   Treba da vidiš: Tabla se vrati na početnu poziciju stavke, ispod nje piše
   tačno rešenje, i tabla više ne prima nijedan sledeći potez — nigde se ne
   pojavljuje dugme za novi pokušaj.
   Potrebno: Windows i telefon; nalog trenera i učenika.

### Home — Reprodukcija snimka

1. [ ] **Izvoz snimljenog časa dobija iste koordinate van table.** [155.2]
   O čemu se radi: Ova izmena je namerna i za ovaj izvoz — zahtev je o izgledu
   oznaka, ne o jednom konkretnom izvozu.
   Gde: `Home` → (red snimka) → `Play` → izvoz MP4.
   Uradi: Izvezi snimljeni čas kao MP4.
   Treba da vidiš: Isti raspored koordinata kao u tutorijalu — van table, u
   prigušenom pojasu.
   Potrebno: Windows i telefon; server; snimljen čas (Preparation).

2. [ ] **Izvoz snimljenog časa je nedirnut ovim pravilom.** [154.5]
   O čemu se radi: Snimljeni čas šalje jedan `init` bez spoja delova, pa ga ovo
   pravilo uopšte ne dotiče.
   Gde: `Home` → (red snimka) → `Play` → izvoz MP4.
   Uradi: Izvezi snimljeni čas kao MP4.
   Treba da vidiš: Pod tablom na prvom kadru i dalje piše 'Starting position',
   kao i pre ove stavke.
   Potrebno: Windows i telefon; server; snimljen čas (Preparation).

3. [ ] **Ugašene oznake vraćaju tabli ceo prostor.** [155.3]
   O čemu se radi: Kad se koordinate isključe u dijalogu, prazan pojas ne sme
   da ostane.
   Gde: `Home` → (red snimka) → `Play` → izvoz MP4 → `Video Settings`.
   Uradi: U dijalogu za izvoz snimljenog časa isključi elemente sa oznakama
   (koordinate), pa izvezi.
   Treba da vidiš: Tabla uzima ceo prostor nazad, bez praznog pojasa gde su
   koordinate bile.
   Potrebno: Windows i telefon; server; snimljen čas (Preparation).

4. [ ] **Deljena lekcija ima zvuk i za učenika, ne samo za trenera.** [219.41]
   O čemu se radi: Iz plejera sopstvene lekcije (Preparation),
   `Share with students…` deli je preko čipova grupa/učenika; učenik dobija
   obaveštenje i vidi lekciju na Home → Recordings, gde je pušta sa zvukom.
   Stari snimci iz žive sobe nemaju dugme za deljenje.
   Gde: `Home` → `Recordings` → `Play` (na deljenoj lekciji); deljenje preko
   `Home` → `Recordings` → snimak snimljen u Preparation →
   `Share with students…`.
   Uradi: Snimi kratku lekciju u Preparation, podeli je preko
   `Share with students…` sa jednim učenikom (čip, kvačica, `Share`). Na nalogu
   učenika otvori `Home` → `Recordings` i pusti je preko `Play`.
   Treba da vidiš: Učenik dobija obaveštenje (ikona filma) i vidi snimak u
   `Recordings`; puštanje ima zvuk kao i kod trenera. Stariji snimak iz žive
   sobe (ne iz Preparation) nema `Share with students…` dugme.
   Potrebno: Windows i telefon; nalog trenera i učenika; drugi uređaj.

5. [ ] **Izvoz snimka časa i dalje izgleda isto (regresiona provera).** [133.8]
   O čemu se radi: Izvoz MP4 snimka časa (Replay → izvoz) je odvojen put od
   izvoza tutorijala i ne sme da promeni geometriju/izgled — čak i film bez
   rečenica.
   Gde: `Home` → (kartica) `Recordings` → `Play` → `Export to MP4 Video`.
   Uradi: Izvezi u MP4 neki snimljen čas (po mogućstvu bez narisanih rečenica).
   Treba da vidiš: Izgled izvezenog videa (raspored table, koordinate,
   elementi) je isti kao pre — bez promene geometrije.
   Potrebno: Windows.

6. [ ] **Izvoz snimka časa nema izbor kompleta figura.** [133.12]
   O čemu se radi: Dijalog za izvoz snimka časa u video ima tačno četiri stavke
   (tabla, orijentacija, elementi prikaza, rezolucija) — bez posebnog izbora
   kompleta figura; video uvek izlazi u figurama iz aplikacije.
   Gde: `Home` → (kartica) `Recordings` → `Play` → `Export to MP4 Video`.
   Uradi: Otvori dijalog `Video Settings` za izvoz snimka časa.
   Treba da vidiš: Dijalog nudi tačno četiri kontrole (tabla/tema,
   orijentacija, elementi prikaza, rezolucija) — nema posebnog izbora kompleta
   figura; izvezen video koristi iste figure kao aplikacija.
   Potrebno: Windows.

7. [ ] **Razmak pušta/pauzira snimak.** [26.b797]
   O čemu se radi: Taster razmak je isto što i dugme za puštanje/pauzu ispod
   table u reprodukciji snimljenog časa.
   Gde: `Home` → kartica `Recordings` → `Play` (ili `Teach` → `Library` →
   snimak → `Play`).
   Uradi: Otvoriti reprodukciju snimka i pritisnuti razmak, bez prethodnog
   klika na dugme za puštanje.
   Treba da vidiš: Snimak se pusti/pauzira, isto kao klik na dugme ispod table.
   Potrebno: Windows.

8. [ ] **Razmak pripada prethodno kliknutom dugmetu.** [26.b798]
   O čemu se radi: Ako se prvo klikne na neko drugo dugme na ekranu, razmak
   posle toga aktivira baš to dugme (standardno ponašanje fokusa), a ne
   puštanje/pauzu snimka.
   Gde: `Home` → kartica `Recordings` → `Play`.
   Uradi: U reprodukciji snimka kliknuti na neko drugo dugme na ekranu (npr.
   izbor brzine), pa pritisnuti razmak.
   Treba da vidiš: Razmak aktivira to dugme na koje se kliknulo, a ne
   puštanje/pauzu snimka — dok se ponovo ne klikne na dugme za puštanje.
   Potrebno: Windows.

9. [ ] **Kontrole plejera snimka su desno, strelica nazad radi u AI vežbama.**
   [172.6]
   O čemu se radi: Deo prve provere koji vlasnik nije prijavio kao problem (i
   dalje važi, per stavka 173).
   Gde: Home → `Recordings` → `Play` (telefon položeno).
   Uradi: Pusti snimak na telefonu položeno; zatim otvori neku AI vežbu (npr.
   sa Practise) i pritisni strelicu nazad gore levo.
   Treba da vidiš: Kontrole plejera (pusti/pauziraj, brzina, klizač) su desno
   od snimka; strelica nazad u AI vežbama radi i vraća na prethodni ekran.
   Potrebno: telefon; telefon položeno.

### Home — Home i obaveštenja

1. [ ] **Na Home-u više nema ponavljanja iz tutorijala.** [246.10]
   O čemu se radi: „Due for review" je hranilo isključivo učenikovo prolaženje
   kroz tutorijal, pa je otišlo s njim (`docs/PLAN-TUTORIJAL-VIDEO.md`, D9).
   Gde: (kao učenik koji ima trenera) `Home`.
   Uradi: Otvori `Home`.
   Treba da vidiš: Karticu `Set for me` sa tekstom „Drills and videos your
   trainer set you, and your progress." i nijednu karticu za ponavljanje.
   Potrebno: nalog učenika sa prihvaćenim trenerom.

2. [ ] **Traka bez veze sa serverom se sama povuče.** [13.b578]
   O čemu se radi: Ovo je opšta traka na Početnoj (ne samo za skener): ponavlja
   proveru na 10 sekundi, a povezivanje soketa se odmah računa kao dokaz da je
   veza uspostavljena.
   Gde: `Home` (traka se pojavljuje kad server nije dostupan).
   Uradi: Ugasiti backend (traka se pojavi), pa ga ponovo upaliti i sačekati.
   Treba da vidiš: Traka koja počinje sa `No connection to server` (i
   objašnjava da se ništa ne čuva niti učitava) nestane sama, najkasnije za 10
   sekundi (ili odmah po povezivanju soketa).
   Potrebno: Windows i telefon.

3. [ ] **Zvono javlja kad je film gotov, i preuzimanje sa reda radi.** [143.3]
   O čemu se radi: Kad se render završi u pozadini, trener mora da bude
   obavešten bez da čeka otvorenu traku.
   Gde: zvono (`Notifications and Invitations`) posle završenog izvoza.
   Uradi: Sačekaj da se render iz 143.1 završi (radi nešto drugo u aplikaciji u
   međuvremenu).
   Treba da vidiš: Na zvonu se pojavi obaveštenje o gotovom filmu sa ikonom
   filma; `Download video` na redu u Biblioteci radi.
   Potrebno: Windows i telefon; server.

4. [ ] **Nema više dvostrukog zaglavlja iznad naslova taba.** [180.9]
   O čemu se radi: Vlasnik je 18.9.2026 tražio uživo da se ukloni gornja traka
   ljuske („taj gornji deo mi uopšte nije potreban“) — reč „Chess Trainer“ sa
   zupčanikom i zvonom je stajala iznad naslova samog taba, dva zaglavlja koja
   kažu isto.
   Gde: Home, Practise, Teach (naslov taba sa zvonom i zupčanikom `Settings`) —
   Analyse nema posebno zaglavlje.
   Uradi: Otvori redom Home, Practise, Analyse i Teach, i uspravno i položeno.
   Treba da vidiš: Home, Practise i Teach imaju samo svoj naslov sa zvonom i
   zupčanikom (`Settings`) desno, bez ijedne dodatne trake iznad. Analyse nema
   nijedno sopstveno zaglavlje — njeno telo je Analiza sa svojom trakom, a
   `Settings` je među njenim radnjama. Gost i dalje ima `Sign In`, sada u
   zaglavlju taba.
   Potrebno: Windows i telefon.

## Practise

### Practise — Svoji zadaci i domaći

1. [ ] **Sačuvane zagonetke: greška bez pomena poteza, jedini potez sa svojim
   uputstvom.** [241.5]
   O čemu se radi: Sačuvana zagonetka-greška otvara poziciju pre greške sa
   uputstvom `A mistake was made in this position. Find the best move.` bez
   pomena odigranog poteza; sačuvana zagonetka jedinog poteza ima uputstvo
   `The player found the only good move here. Find it.`.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`; zatim
   `Library` → `Exercises`.
   Uradi: Sačuvaj jednu grešku i jedan „jedini potez“ iz liste nakon pregleda.
   Otvori obe u Biblioteci.
   Treba da vidiš: Zagonetka-greška: pozicija pre greške, uputstvo
   `A mistake was made in this position. Find the best move.`, tvoj odigrani
   potez se nigde ne pominje. Zagonetka jedinog poteza: uputstvo
   `The player found the only good move here. Find it.`.
   Potrebno: Windows; uvezene partije.

2. [ ] **Đački pregled još ne pokazuje granicu prema već viđenoj poziciji (P2
   nije rađen).** [154.7]
   O čemu se radi: Ovo je poznato ograničenje, ne kvar — provera je da li
   nedostatak zaista smeta u praksi.
   Gde: `Home` → `My Assignments` (ili poslat tutorijal) → otvori referentni
   tutorijal.
   Uradi: Prođi referentni tutorijal 'Master the Rook and King Checkmate'
   (kopija u D:/chess/tutorijal/reference/) kao đak, preko granice koja u filmu
   ima natpis o povratku.
   Treba da vidiš: U đakovom pregledu se ta granica ne vidi nikako (nema
   natpisa); ako to smeta u praksi, treba nova faza koja poziva isto pravilo,
   ne novo.
   Potrebno: Windows i telefon; nalog trenera i učenika; referentni tutorijal
   'Master the Rook and King Checkmate' (kopija u
   D:/chess/tutorijal/reference/).

3. [ ] **Pre poteza, zadatak ne otkriva potez iz partije.** [242.2]
   O čemu se radi: Pre nego što se odigra potez, zagonetka pokazuje samo
   poziciju i uputstvo — nigde se ne pominje koji je potez zapravo odigran u
   izvornoj partiji.
   Gde: `Library` → `Exercises` → otvori sačuvanu zagonetku iz pregleda partije
   (`Solve`).
   Uradi: Otvori jednu od novih zagonetki iz Biblioteke (`Exercises`) preko
   `Solve`, pre nego što odigraš bilo koji potez.
   Treba da vidiš: Vidi se samo pozicija i rečenica
   `A mistake was made in this position. Find the best move.` — nigde se ne
   pominje koji je potez odigran u partiji.
   Potrebno: Windows i telefon.

4. [ ] **Pogrešan odgovor otkriva dve pločice sa linijama koje se mogu
   prelistati.** [242.3]
   O čemu se radi: Posle pogrešnog poteza, ispod presude se prikazuju pločice
   „What was played: …“ (sa „Its refutation“ ili „How the advantage went“) i
   „What was best: …“; dodir na pločicu otvara tablu sa strelicom i trakom za
   prelistavanje linije napred-nazad, sa dugmetom za povratak na zadatak.
   Gde: `Library` → `Exercises` → otvori sačuvanu zagonetku iz pregleda partije
   (`Solve`).
   Uradi: Odigraj namerno pogrešan potez u zagonetki. Dodirni pločicu „What was
   played“, prelistaj liniju napred i nazad (i strelicama na tastaturi na
   Windows-u), pa se vrati na zadatak.
   Treba da vidiš: Ispod presude su pločice `What was played: …` i
   `What was best: …`; prva nosi podnaslov `Its refutation` ili
   `How the advantage went`. Dodir na pločicu vraća tablu na vrh ekrana (cela
   je vidljiva), strelica pokazuje odigrani potez, a traka ispod table vodi
   napred/nazad kroz liniju; `Back to the puzzle` vraća prikaz zadatka.
   Potrebno: Windows i telefon.

5. [ ] **Treća pločica se javlja samo kad se tvoj potez poklapa sa drugom
   linijom motora.** [242.4]
   O čemu se radi: Ako je odigrani pogrešan potez baš druga linija motora,
   dodaje se pločica `Your move: …` sa njenom linijom; ako se ne poklapa,
   umesto nje piše `No line for this move.` — nikad se ne prikazuje tuđa linija
   pod tvojim potezom.
   Gde: `Library` → `Exercises` → otvori sačuvanu zagonetku iz pregleda partije
   (`Solve`).
   Uradi: Odigraj potez koji je drugorangirana linija motora u toj poziciji, pa
   odigraj (u drugoj zagonetki) neki treći, nepredviđen potez.
   Treba da vidiš: Kad se tvoj potez poklapa sa drugom linijom motora,
   pojavljuje se pločica `Your move: …` sa tom linijom. Kad se ne poklapa,
   umesto nje piše `No line for this move.`.
   Potrebno: Windows i telefon.

6. [ ] **Tačan odgovor prikazuje iste pločice bez rečenice o tvom potezu.**
   [242.5]
   O čemu se radi: Kad se zagonetka reši tačno, i dalje se prikazuju pločice
   `What was played`/`What was best` (koje sada opisuju isti, tačan potez), ali
   bez posebne pločice o „tvom“ potezu.
   Gde: `Library` → `Exercises` → otvori sačuvanu zagonetku iz pregleda partije
   (`Solve`).
   Uradi: Reši drugu (ili istu, ponovo) zagonetku tačnim potezom i pogledaj
   prikazane pločice.
   Treba da vidiš: Iste pločice kao kod pogrešnog odgovora se prikazuju, bez
   dodatne pločice `Your move: …` (pošto je odigrani potez i najbolji).
   Potrebno: Windows i telefon.

7. [ ] **Na telefonu, uspravno, sve pločice i traka staju cele.** [242.6]
   O čemu se radi: Na uskom ekranu (360 dp, uspravna orijentacija) pločice sa
   linijama i traka za prelistavanje se moraju u potpunosti čitati, bez sečenja
   teksta.
   Gde: `Library` → `Exercises` → otvori sačuvanu zagonetku iz pregleda partije
   (`Solve`).
   Uradi: Na telefonu, u uspravnoj orijentaciji (360 dp širine), odigraj
   pogrešan potez u zagonetki iz pregleda i pogledaj prikaz.
   Treba da vidiš: Sve pločice (`What was played`, `What was best`, eventualno
   `Your move`) i traka ispod table se u potpunosti čitaju — nijedan tekst nije
   odsečen niti prelazi van ekrana.
   Potrebno: telefon; telefon položeno.

8. [ ] **Zadatak iz arhive stigne učeniku sa uputstvom.** [58.4]
   O čemu se radi: Uputstvo pozicija je danas na engleskom ("In this position
   you played …. Find a better move."), ne na srpskom kako je pisalo kad je
   stavka nastala — jezik aplikacije je od pivota 8-9.9.2026 isključivo
   engleski.
   Gde: (trener) POST /assignments/from-archive bez dryRun; (učenik)
   `My Assignments`.
   Uradi: Pošalji zadatak bez dryRun; na učenikovom nalogu otvori zadatak u
   `My Assignments`.
   Treba da vidiš: Učenik dobija obaveštenje, zadatak se vidi u listi, a svaka
   pozicija nosi uputstvo na engleskom oblika "In this position you played ….
   Find a better move."
   Potrebno: Windows i telefon; nalog trenera i učenika.

9. [ ] **Osam zadatih pozicija pokriva različite teme.** [58.5]
   O čemu se radi: Zadati skup pozicija ne sme biti isti motiv ponovljen osam
   puta.
   Gde: (trener) POST /assignments/from-archive bez dryRun; (učenik)
   `My Assignments`.
   Uradi: Pošalji zadatak bez dryRun; na učenikovom nalogu otvori zadatak u
   `My Assignments` i pogledaj svih osam pozicija.
   Treba da vidiš: Pozicije pokrivaju različite motive, ne isti motiv osam puta
   zaredom.
   Potrebno: Windows i telefon; nalog trenera i učenika.

10. [ ] **Dugmad na kartici odgovaraju vrsti stavke
   (tutorijal/zadatak/pozicija/analiza).** [205.3]
   O čemu se radi: Svaka kartica u Biblioteci ima samo dugmad koja joj
   pripadaju: tutorijal (video, pošalji, kanta), zadatak (`Add to tutorial` i
   `Assign to student` ili `Make exercise`, zavisno da li je zadatak), obična
   pozicija (samo `Add to tutorial`), analiza (nijedno). Nijedno dugme ne sme
   da deluje na susednu karticu.
   Gde: `Teach` → `Library`.
   Uradi: Pregledaj po jednu karticu svake vrste (tutorijal, zadatak sa
   rešenjem, obična pozicija, analiza) i uporedi dugmad sa vrstom kartice.
   Probaj dugme na jednoj kartici i proveri da ne menja susednu.
   Treba da vidiš: Tutorijal: video/pošalji/kanta dugmad. Pravi zadatak
   (isExercise, npr. sken sa predloženim rešenjem ili nešto napravljeno preko
   „Make exercise“): `Assign to student` (uz prihvaćenog učenika) i
   `Add to tutorial`. Obična pozicija (još nije zadatak): `Make exercise` i
   `Add to tutorial`. Analiza: nijedno dugme za akciju osim brisanja. Nijedan
   pritisak ne utiče na susednu karticu.
   Potrebno: Windows; nalog trenera i učenika.

11. [ ] **Na telefonu, zaglavlje filtera se skroluje zajedno sa karticama.**
   [233.6]
   O čemu se radi: Pod čipom `Exercises` u Biblioteci, na uskom ekranu,
   zaglavlje sa filterima i pretragom se skroluje zajedno sa listom kartica —
   ranije je zaglavlje bilo više od ekrana i nijedna kartica se nije videla.
   Gde: `Teach` → `Library` → čip `Exercises`.
   Uradi: Otvori Biblioteku na telefonu (uspravno) i izaberi čip `Exercises`.
   Treba da vidiš: Filteri i kartice zadataka se vide; zaglavlje (filteri,
   pretraga) se pomera zajedno sa listom pri skrolovanju — nije zaglavlje samo
   previše visoko da bi se ijedna kartica videla.
   Potrebno: telefon; telefon položeno.

12. [ ] **Zadatak sa rešenjem ima „Assign“, ne „Make exercise“** [215.6]
   O čemu se radi: Sken sa rešenjem (kroz predlog strane/odgovora pri
   skeniranju) i zadatak napravljen u Preparation su već zadaci (isExercise),
   pa na svojoj kartici u Biblioteci imaju dugme `Assign to student`, a ne
   `Make exercise`.
   Gde: `Teach` → `Library` → čip `Exercises`.
   Uradi: Napravi zadatak u Preparation (`Make exercise`) i skeniraj poziciju
   sa predloženim rešenjem; pogledaj njihove kartice u Biblioteci.
   Treba da vidiš: Obe kartice imaju dugme `Assign to student` (uz prihvaćenog
   učenika); nijedna od njih nema `Make exercise` (već je zadatak).
   Potrebno: Windows; PDF knjiga.

13. [ ] **Prazna polica u Biblioteci ima rečenicu, ne praznu kutiju.** [205.9]
   O čemu se radi: Kad nijedan filter/čip u Biblioteci nema nijednu stavku,
   prikazuje se objašnjavajuća rečenica umesto vizuelno prazne kutije bez
   teksta.
   Gde: `Teach` → `Library` → čip bez ijedne stavke (npr. `Recordings` bez
   snimaka).
   Uradi: Otvori čip u Biblioteci za koji znaš da nema nijednu stavku (npr. na
   svežem nalogu).
   Treba da vidiš: Umesto prazne kutije, ispisuje se rečenica koja objašnjava
   da tu ništa nema (npr. objašnjava odakle bi stavke došle).
   Potrebno: Windows.

### Practise — Repertoar — spisak, nov, izvoz i tura

1. [ ] **Red repertoara na listi ne pokazuje procenat pokrivenosti.** [170.3]
   O čemu se radi: Red ispod imena repertoara sada kaže samo stranu, izvor
   („via …“) i broj poteza u grafu — bez starog procenta odgovorenosti.
   Gde: Practise → `Opening repertoire`.
   Uradi: Pogledaj red ispod imena repertoara na listi.
   Treba da vidiš: Piše samo strana, „via …“ (ako postoji) i „N moves in graph“
   — nigde „unanswered positions“ ni „all answered“.
   Potrebno: Windows.

2. [ ] **Komentar na poziciju repertoara se izvozi uz svoj potez.** [170.10]
   O čemu se radi: Tekstualni komentar napisan na poziciji u repertoaru mora da
   se pojavi u izvezenom PGN-u u vitičastim zagradama, uz taj isti potez.
   Gde: Practise → `Opening repertoire` → otvori repertoar → napiši komentar,
   pa `Export as PGN`.
   Uradi: Napiši komentar na neku poziciju u repertoaru i izvezi ga.
   Treba da vidiš: Rečenica stoji u vitičastim zagradama uz taj potez u
   izvezenom tekstu.
   Potrebno: Windows.

3. [ ] **Repertoar koji počinje dublje nosi FEN zaglavlje i rečenicu o
   liniji.** [170.12]
   O čemu se radi: Ako repertoar ne počinje od prvog poteza (napravljen iz
   pozicije preko `Extract into new opening` ili gradnje od pozicije), izvezen
   fajl mora da nosi `[SetUp "1"]`/`[FEN …]` i rečenicu koja imenuje liniju.
   Gde: Practise → `Opening repertoire` → repertoar napravljen iz pozicije →
   `Export as PGN`.
   Uradi: Izvezi repertoar koji počinje od prve pozicije, pa izvezi jedan
   napravljen preko `Extract into new opening` (počinje dublje).
   Treba da vidiš: Prvi fajl počinje od 1. poteza, bez `[FEN]`. Drugi ima
   `[SetUp "1"]` i `[FEN …]`, a linija je opisana rečenicom „Repertoire line:
   …“.
   Potrebno: Windows.

4. [ ] **Prazan repertoar se odbija umesto da izveze prazan tekst.** [170.13]
   O čemu se radi: Repertoar bez ijednog poteza nema šta da izveze —
   `Export as PGN` mora to da kaže umesto da otvori prazan prozor.
   Gde: Practise → `Opening repertoire` → novonapravljen repertoar bez poteza →
   `Export as PGN`.
   Uradi: Pritisni `Export as PGN` na repertoaru koji nema nijedan potez.
   Treba da vidiš: Prikazuje se poruka da nema poteza; prozor sa tekstom se ne
   otvara.
   Potrebno: Windows.

5. [ ] **Izvoz u PGN postoji na listi repertoara i kopira tekst.** [170.8]
   O čemu se radi: Izvoz je vraćen na listu repertoara (meni `More`), a tekst
   se odmah kopira u clipboard.
   Gde: Practise → `Opening repertoire` → red repertoara → `More` →
   `Export as PGN`.
   Uradi: Izaberi `Export as PGN` na nekom repertoaru.
   Treba da vidiš: Otvori se prozor sa PGN tekstom, i taj tekst je već u
   clipboard-u.
   Potrebno: Windows.

6. [ ] **Izvezen fajl piše glavnu liniju kao tvoj potez + najigraniji
   odgovor.** [170.9]
   O čemu se radi: Glavna linija u PGN fajlu je tvoj glavni potez sa
   najigranijim odgovorom; ostali tvoji potezi idu kao varijante u zagradama,
   bez zvezdica ili procenata.
   Gde: Practise → `Opening repertoire` → red repertoara → `More` →
   `Export as PGN`.
   Uradi: Izvezi repertoar koji ima bar dva tvoja poteza na istoj poziciji i
   pogledaj tekst.
   Treba da vidiš: Glavna linija je tvoj glavni potez + najigraniji odgovor;
   ostali tvoji potezi su u zagradama kao varijante; nigde u fajlu nema ★ ni
   procenata.
   Potrebno: Windows.

7. [ ] **Sačuvan .pgn fajl nosi ime repertoara i otvara se u drugim čitačima.**
   [170.11]
   O čemu se radi: „Save as .pgn“ predlaže ime po repertoaru (ne generičko ime
   sa datumom); fajl mora da bude čitljiv i drugim PGN alatima.
   Gde: Practise → `Opening repertoire` → red repertoara → `More` →
   `Export as PGN` → `Save as .pgn`.
   Uradi: Izvezi repertoar, pa u dijalogu sa tekstom pritisni `Save as .pgn` i
   sačuvani fajl otvori u nekom drugom čitaču PGN-a (ChessBase, Lichess uvoz,
   SCID).
   Treba da vidiš: Predloženo ime je po repertoaru (npr.
   „Smith-Morra-Black.pgn“), ne „analysis-…“; fajl se u drugom čitaču normalno
   odigrava.
   Potrebno: Windows.

8. [ ] **Prazan spisak repertoara objašnjava gde su potezi i kako se brišu.**
   [84.8]
   O čemu se radi: Kad nema nijednog repertoara na spisku (sve obrisane, ili
   potezi obrisani a repertoari individualno takođe), ekran objašnjava da su
   ranije odabrani potezi i dalje sačuvani uz boju.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (obriši sve repertoare sa spiska).
   Uradi: Obriši (pojedinačno) sve repertoare sa spiska dok lista ne postane
   prazna.
   Treba da vidiš: Piše „No repertoires yet." i ispod toga rečenica da su
   ranije birani potezi i dalje sačuvani uz boju, sa uputstvom da se brišu
   preko „Delete moves from database" u meniju iznad.
   Potrebno: Windows i telefon; server.

9. [ ] **Repertoari (ime i početna pozicija) preživljavaju pražnjenje cele
   boje.** [84.7]
   O čemu se radi: Dugme za brisanje svih poteza jedne boje (u zaglavlju liste)
   ne briše same repertoare — samo poteze; imena i početne pozicije ostaju na
   spisku.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (zaglavlje, meni boje) → `Delete moves from database`.
   Uradi: Sa bar jednim repertoarom na spisku, otvori meni u zaglavlju i
   izaberi „Delete moves from database" za tu boju, potvrdi.
   Treba da vidiš: Ime repertoara i njegova početna pozicija su i dalje na
   spisku posle pražnjenja; poruka kaže da „The repertoires themselves (name
   and starting position) stay — delete them individually."
   Potrebno: Windows i telefon; server.

10. [ ] **Dril i sparing su sužani na kapiju repertoara.** [85.7]
   O čemu se radi: „Entire repertoire" u listu grana drila i sparing ne
   postavljaju pitanja iz drugog otvaranja izvan kapije.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Otvori `Drill` na repertoaru sa kapijom i prođi kroz par pitanja,
   uključujući „Entire repertoire".
   Treba da vidiš: Sva pitanja dolaze samo iz grane kapije, nikad iz drugog
   otvaranja iz iste početne pozicije.
   Potrebno: Windows i telefon; server.

11. [ ] **„Drill <potez>" na račvi zaista suzi liniju drila (popravka).**
   [85.11]
   O čemu se radi: Posle izbora „Drill <potez>" u listu „Another decision"
   (section 82), sledeća dva-tri pitanja moraju stvarno da dolaze iz izabrane
   grane.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Na račvi u drilu izaberi „Drill <potez>" i odgovori na dva-tri
   sledeća pitanja.
   Treba da vidiš: Sva ta pitanja pripadaju izabranoj grani, ne bilo kojoj
   drugoj.
   Potrebno: Windows i telefon; server.

12. [ ] **„Another line" daje stvarno drugu liniju i posle tri pritiska.**
   [85.12]
   O čemu se radi: Pritisak na „Another line" tri puta zaredom mora da vrati
   tri različite ponude, ne istu.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Pritisni `Another line` tri puta zaredom u drilu i uporedi ponuđena
   pitanja.
   Treba da vidiš: Sva tri puta je ponuđeno različito pitanje/linija.
   Potrebno: Windows i telefon; server.

13. [ ] **Otvaranje repertoara sa kapijom čisti stablo od drugih otvaranja.**
   [85.2]
   O čemu se radi: Kad repertoar ima kapiju (koren + prvi potez), gradnja i
   stablo prikazuju samo tu granu — ništa iz druge kapije iz iste početne
   pozicije.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `More` → `Which move it goes through`.
   Uradi: Postavi kapiju na repertoaru (npr. na 1.e4) preko
   `Which move it goes through`. Otvori taj repertoar u gradnji.
   Treba da vidiš: U stablu nema poteza iz drugog prvog poteza (npr. 1.d4) niti
   bilo čega ispod njega.
   Potrebno: Windows i telefon; server.

14. [ ] **Ekran kaže da je repertoar sužen kapijom.** [85.3]
   O čemu se radi: Kad je kapija postavljena, ekran gradnje to ispisuje
   rečenicom iznad table/pitanja.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `More` → `Which move it goes through`.
   Uradi: Otvori repertoar sa postavljenom kapijom u gradnji.
   Treba da vidiš: Piše rečenica oblika „This repertoire goes through <potez> —
   the rest of this position is not shown."
   Potrebno: Windows i telefon; server.

15. [ ] **Redovi za odlučivanje/pokrivenost ne računaju pozicije iz druge grane
   kapije.** [85.4]
   O čemu se radi: Brojevi „N u redu"/pokrivenost u listi i gradnji moraju da
   broje samo ono što je iza kapije, ne celu boju.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `More` → `Which move it goes through`.
   Uradi: Uporedi brojeve (u redu, pokrivenost) na repertoaru sa kapijom i na
   repertoaru bez kapije iz iste početne pozicije.
   Treba da vidiš: Brojevi sa kapijom su manji/drugačiji i odgovaraju samo toj
   grani, ne celoj boji.
   Potrebno: Windows i telefon; server.

16. [ ] **Radar pokrivenosti (Gaps in repertoire) prikazuje samo grane
   kapije.** [85.6]
   O čemu se radi: Ekran „Gaps in repertoire" za repertoar sa kapijom crta samo
   ono što je iza kapije.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `More` → `Gaps in repertoire`.
   Uradi: Otvori `More` → `Gaps in repertoire` na repertoaru sa postavljenom
   kapijom.
   Treba da vidiš: Radar/mapa pokrivenosti prikazuje samo grane koje počinju
   kapijom, ne ceo graf boje.
   Potrebno: Windows i telefon; server.

17. [ ] **Kapija se može ukloniti izborom „No restrictions"** [85.9]
   O čemu se radi: U istom izborniku kapije postoji opcija koja uklanja
   ograničenje i vraća ceo graf od korena.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `More` → `Which move it goes through`.
   Uradi: Na repertoaru sa postavljenom kapijom otvori
   `Which move it goes through` i izaberi „No restrictions".
   Treba da vidiš: Kapija se ukloni; stablo, dril i pokrivenost ponovo
   prikazuju ceo graf kao pre postavljanja kapije.
   Potrebno: Windows i telefon; server.

18. [ ] **Skok na drugu poziciju (iz radara ili drila) ne nasleđuje kapiju.**
   [85.10]
   O čemu se radi: Kad se iz radara pokrivenosti ili drila otvori gradnja na
   nekoj dubljoj poziciji direktno (ne od korena), ta gradnja nije sužena
   kapijom niti ispisuje rečenicu o njoj.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `More` → `Which move it goes through`.
   Uradi: Iz `Gaps in repertoire` ili iz drila (dugme za gradnju nepokrivene
   pozicije) otvori gradnju na dubljoj poziciji.
   Treba da vidiš: Na tom ekranu nema rečenice o kapiji, i ništa nije skriveno
   iz stabla te podpozicije.
   Potrebno: Windows i telefon; server.

19. [ ] **List za izbor kapije i rečenica o kapiji se ne seku na telefonu.**
   [85.14]
   O čemu se radi: List „Which move does this repertoire go through?" i
   rečenica o kapiji iznad table u gradnji moraju da stanu na 360 dp u release
   build-u.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `More` → `Which move it goes through`.
   Uradi: Na telefonu (360 dp, release build) otvori izbor kapije preko
   `Which move it goes through`, pa otvori gradnju repertoara sa postavljenom
   kapijom.
   Treba da vidiš: Ni list za izbor ni rečenica o kapiji iznad table se ne seku
   niti izlaze van ekrana.
   Potrebno: telefon; server; release build; telefon položeno.

20. [ ] **Dijalog brisanja pokazuje broj poteza i koliko je sam korisnik
   izabrao.** [84.2]
   O čemu se radi: Dijalog za brisanje repertoara (meni kartice →
   `Delete repertoire`) pokazuje unapred koliko poteza u koliko pozicija drži
   samo taj repertoar, i koliko je od toga korisnik sam odabrao.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (kartica repertoara) → `More` → `Delete repertoire`.
   Uradi: Na kartici repertoara sa odigranim potezima otvori `More` →
   `Delete repertoire`.
   Treba da vidiš: U dijalogu piše „Also delete moves: N in M positions" i
   ispod toga „Of which K were chosen by you" — sa stvarnim brojevima, ne 0/0
   kad ih ima.
   Potrebno: Windows i telefon; server.

21. [ ] **Deljene pozicije se ne broje kao brisane u dijalogu.** [84.3]
   O čemu se radi: Ako dva repertoara iste boje dele deo puta, dijalog brisanja
   jednog mora da kaže da neke pozicije ostaju jer ih drži i drugi repertoar.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (kartica jednog od dva preklapajuća repertoara) → `More` →
   `Delete repertoire`.
   Uradi: Napravi dva repertoara iste boje koji se preklapaju u prvih par
   poteza. Otvori brisanje jednog od njih.
   Treba da vidiš: U dijalogu piše rečenica oblika „…while K positions remain
   because another repertoire of the same color holds them."
   Potrebno: Windows i telefon; server.

22. [ ] **Komentari ostaju posle brisanja repertoara, sem ako se to izričito
   zatraži.** [84.5]
   O čemu se radi: Kvačica „Also delete my comments (N)" u dijalogu brisanja je
   podrazumevano isključena — komentar preživljava brisanje repertoara i vraća
   se čim se pozicija ponovo dosegne.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (kartica repertoara sa napisanim komentarom) → `More` → `Delete repertoire`.
   Uradi: Napiši komentar na jednoj poziciji repertoara. Obriši repertoar sa
   uključenim „Also delete moves" ali BEZ kvačice „Also delete my comments".
   Ponovo dođi do te pozicije (iz drugog repertoara iste boje ili nove
   gradnje). Zatim ponovi sa uključenom kvačicom za komentare.
   Treba da vidiš: Bez kvačice za komentare — komentar je i dalje tu. Sa
   uključenom kvačicom — komentar je nestao.
   Potrebno: Windows i telefon; server.

23. [ ] **Novi repertoar iz pozicije sa već odigranim potezima nudi izbor
   kapije sa svim legalnim potezima.** [85.8]
   O čemu se radi: Kad se pravi novi repertoar od pozicije koja već ima poteze
   te boje, dijalog nudi izbor kapije preko svih legalnih poteza, ne samo onih
   koji su već izabrani u drugim repertoarima.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `New`.
   Uradi: Napravi novi repertoar od pozicije u kojoj već postoje sačuvani
   potezi te boje/pozicije.
   Treba da vidiš: Otvori se izbor „Which move does this repertoire go
   through?" sa svim legalnim potezima (već odigrani su na vrhu i označeni), ne
   samo sa prethodno izabranim.
   Potrebno: Windows i telefon; server.

24. [ ] **Dugačka imena varijanti se skraćuju sa „…" na telefonu.** [79.6]
   O čemu se radi: Birač otvaranja pri pravljenju novog repertoara (isti kao u
   Analysis) mora da skrati duga imena varijanti umesto da ih prelije preko
   ivice reda.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` → `New`
   → `Choose opening` → (otvaranje sa dugim imenima varijanti).
   Uradi: U novom repertoaru pritisni „Choose opening", izaberi otvaranje sa
   mnogo dugih imena varijanti (npr. neko sicilijansko razgranje) i pogledaj
   spisak na 360 dp u release build-u.
   Treba da vidiš: Dugačka imena se seku sa „…" na kraju reda i ne prelivaju se
   u sledeći red niti van ekrana.
   Potrebno: telefon; server; release build; telefon položeno.

25. [ ] **Tabla u oknu je okrenuta ka strani repertoara.** [209.4]
   O čemu se radi: Kad se u širokom prozoru izabere red repertoara, tabla u
   desnom oknu je okrenuta ka strani za koju je taj repertoar napravljen (za
   crnog — crni dole).
   Gde: `Practise` → (Opening) `Opening repertoire` → `Open repertoire`.
   Uradi: U širokom prozoru, izaberi (klikni) repertoar napravljen za crnog.
   Treba da vidiš: Tabla u oknu pored liste je okrenuta tako da je crni dole.
   Potrebno: Windows.

26. [ ] **Repertoar bez zapamćene linije kaže „From the start“** [209.5]
   O čemu se radi: Stariji repertoar (ili napravljen iz nalepljene FEN
   pozicije) nema zapamćenu izmišljenu liniju/naziv otvaranja, pa okno umesto
   naziva otvaranja piše „From the start“.
   Gde: `Practise` → (Opening) `Opening repertoire` → `Open repertoire`.
   Uradi: Izaberi stariji repertoar ili repertoar napravljen nalepljenom FEN
   pozicijom (bez prepoznatog imena otvaranja) i pogledaj okno.
   Treba da vidiš: Umesto imena otvaranja, okno pokazuje tekst
   `From the start`.
   Potrebno: Windows.

27. [ ] **Dugi pritisak i dalje bira više redova; u tom režimu klik čekira.**
   [209.7]
   O čemu se radi: Dugi pritisak na red i dalje ulazi u režim višestrukog
   izbora (za `Drill selected (…)`); dok je taj režim uključen, klik na red
   čekira/otčekirava ga umesto da ga bira za prikaz u oknu.
   Gde: `Practise` → (Opening) `Opening repertoire` → `Open repertoire`.
   Uradi: Napravi dugi pritisak na jedan red da uđeš u režim izbora, pa klikni
   (kratko) na drugi red.
   Treba da vidiš: Dugi pritisak uključuje režim izbora sa trakom
   `Drill selected (…)` na dnu. Dok je taj režim aktivan, klik na red menja
   njegovu kvačicu (bira/skida za drill), a ne prikazuje ga u desnom oknu.
   Potrebno: Windows.

28. [ ] **U uskom prozoru, klik na red otvara repertoar (nema okna).** [209.8]
   O čemu se radi: Ispod granice širokog prozora (Breakpoints.wide), okno pored
   liste ne postoji — klik na red otvara repertoar direktno (izgradnja
   repertoara), kao pre uvođenja okna.
   Gde: `Practise` → (Opening) `Opening repertoire` → `Open repertoire`.
   Uradi: Suzi prozor na Windows-u do najmanje moguće širine i klikni na red
   repertoara.
   Treba da vidiš: Nema okna pored liste; klik na red odmah otvara ekran
   izgradnje tog repertoara.
   Potrebno: Windows.

29. [ ] **Biranje repertoara u oknu ne pravi nove zahteve ka serveru.**
   [209.10]
   O čemu se radi: Okno crta prikaz repertoara iz podataka koje je lista već
   učitala — biranje različitih repertoara u oknu ne sme da izazove vidljivu
   pauzu niti nov mrežni zahtev.
   Gde: `Practise` → (Opening) `Opening repertoire` → `Open repertoire`.
   Uradi: U širokom prozoru, brzo biraj (klikni) nekoliko različitih repertoara
   jedan za drugim i posmatraj okno.
   Treba da vidiš: Okno se ažurira odmah, bez primetne pauze ili indikatora
   učitavanja pri svakom biranju.
   Potrebno: Windows.

30. [ ] **Tura preskače neodgovorene grane kad ih ima više.** [104.6]
   O čemu se radi: Kad protivnik na nekoj poziciji ima dva ili više odgovora
   bez tvog pripremljenog poteza, tura „Tour your repertoire” ih više ne
   obilazi jedan po jedan — sve takve grane se preskaču, jer ih je grananje pre
   njih već nabrojalo rečenicom o broju odgovora.
   Gde: `Practise` → (kartica) `Opening repertoire` → `Open repertoire` → (red
   repertoara) → meni `More` → `Explore repertoire`.
   Uradi: Pokreni turu do pozicije gde protivnik ima bar dva odgovora, a
   nijedan nemaš pripremljen (spremljen je samo tvoj sledeći potez posle te
   grane).
   Treba da vidiš: Tura se ne zaustavlja ni na jednoj od tih grana — nastavlja
   odmah do tvog sledećeg poteza, pošto je pre toga već rekla „From here the
   opponent has … replies: …”.
   Potrebno: Windows i telefon.

31. [ ] **Usamljena rupa se i dalje pokazuje u turi.** [104.7]
   O čemu se radi: Izuzetak od prethodnog pravila: kad protivnik ima tačno
   jedan neodgovoren potez (nema drugih grana na toj poziciji), tura se i dalje
   zaustavlja na njoj — jer se rečenica o grananju izgovara samo kad ima više
   odgovora, pa je to jedino mesto gde se ta rupa uopšte pominje.
   Gde: `Practise` → (kartica) `Opening repertoire` → `Open repertoire` → (red
   repertoara) → meni `More` → `Explore repertoire`.
   Uradi: Pokreni turu do pozicije gde protivnik ima tačno jedan potez, i taj
   potez nemaš odgovoren.
   Treba da vidiš: Tura se zaustavlja na toj poziciji i čuje se/piše rečenica
   „Against …, you have no reply.” (ili sa procentom: „Against …, in … of
   games, you have no reply.”).
   Potrebno: Windows i telefon.

32. [ ] **Govor na granama je ređi nego pre popravke.** [104.9]
   O čemu se radi: Otkad tura preskače pojedinačne neodgovorene grane (kad ih
   ima dve ili više) umesto da stane na svaku, na takvim mestima se čuje samo
   jedna rečenica (grananje pre njih), ne po jedna za svaku granu.
   Gde: `Practise` → (kartica) `Opening repertoire` → `Open repertoire` → (red
   repertoara) → meni `More` → `Explore repertoire`.
   Uradi: Uključi govor i prođi turu kroz nekoliko pozicija gde protivnik ima
   više neodgovorenih odgovora.
   Treba da vidiš: Na takvim mestima se čuje samo rečenica o grananju („…the
   opponent has … replies: …”), a ne po jedna dodatna rečenica za svaku od tih
   grana. Ako ti i dalje zvuči kao ponavljanje, zabeleži tačno gde.
   Potrebno: Windows i telefon.

33. [ ] **Nema više posebnog ekrana za stablo.** [70.10]
   O čemu se radi: Stablo je sada ugrađeno u ekran izgradnje; u meniju spiska
   repertoara nema stavke za posebno stablo, niti u zaglavlju „Gaps in
   repertoire" postoji ikonica koja vodi na stablo.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (red) → `More`.
   Uradi: Otvoriti meni `More` na kartici repertoara i pregledati stavke;
   odvojeno otvoriti `Gaps in repertoire`.
   Treba da vidiš: Meni `More` nema stavku za poseban ekran stabla, a „Gaps in
   repertoire" nema ikonicu koja vodi na stablo — stablo se vidi samo u
   izgradnji.
   Potrebno: Windows i telefon; server.

34. [ ] **„Clean imported moves" prvo javlja procenu, pa pita.** [69.3]
   O čemu se radi: Stavka menija `Clean imported moves` prvo pokaže koliko
   poteza i pozicija nema zapis da ih je korisnik sam izabrao, uz napomenu da
   je to procena, pre nego što se bilo šta obriše.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (red) → `More`
   → `Clean imported moves`.
   Uradi: Pritisnuti `More` na repertoaru sa uvezenim potezima, pa
   `Clean imported moves`. Pritisnuti `Cancel`.
   Treba da vidiš: Dijalog javlja broj poteza/pozicija i tekst da je to
   procena, ne dokaz; posle `Cancel` ništa nije obrisano.
   Potrebno: Windows i telefon; server; repertoar sa uvezenim potezima.

35. [ ] **Čišćenje smanjuje broj poteza u grafu.** [69.4]
   O čemu se radi: Posle potvrde čišćenja, broj poteza koji kartica repertoara
   prijavljuje (koliko poteza ima u grafu) mora da padne, i to za obe kartice
   istog boja.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (red) → `More`
   → `Clean imported moves` → (potvrditi).
   Uradi: Zapamtiti broj poteza sa kartice repertoara, izvršiti
   `Clean imported moves` i potvrditi, pa ponovo pogledati broj na kartici.
   Treba da vidiš: Broj poteza na kartici je manji nego pre čišćenja.
   Potrebno: Windows i telefon; server; repertoar sa uvezenim potezima.

36. [ ] **Sopstveni ručno izgrađeni potezi ostaju posle čišćenja.** [69.5]
   O čemu se radi: Potez koji je korisnik sam odigrao u izgradnji mora da
   preživi čišćenje uvezenih poteza, sa zvezdicom kao glavni.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (izgraditi
   jedan potez ručno) → (red) → `More` → `Clean imported moves`.
   Uradi: Ručno odigrati bar jedan potez u izgradnji, pa izvršiti „Clean
   imported moves", pa se vratiti u izgradnju na istu poziciju.
   Treba da vidiš: Ručno odigrani potez je i dalje tu, sa zvezdicom.
   Potrebno: Windows i telefon; server.

37. [ ] **Brisanje jednog repertoara ne dira drugi istog boja.** [69.7]
   O čemu se radi: Brisanje jednog repertoara uklanja samo njegovu karticu;
   drugi repertoar iste boje zadržava svoje poteze.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (red) → `More`
   → `Delete repertoire`.
   Uradi: Napraviti (ili koristiti) dva repertoara iste boje, svaki sa bar
   jednim potezom. Obrisati jedan preko `More` → `Delete repertoire`.
   Treba da vidiš: Obrisana kartica nestaje sa spiska; drugi repertoar iste
   boje i dalje ima svoje poteze nedirnute.
   Potrebno: Windows i telefon; server; dva repertoara istog boja.

38. [ ] **Novi repertoar: potezi odigrani na tabli ispisuju liniju.** [29.b826]
   O čemu se radi: Dugme `New` otvara ekran sa tablom na kojoj se otvaranje
   igra potez po potez; odigrana linija se ispisuje ispod table.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` →
   `Open repertoire` → `New`.
   Uradi: Na novom repertoaru odigrati poteze
   `1.e4 c5 2.d4 cxd4 3.c3 dxc3 4.Nxc3` na tabli.
   Treba da vidiš: Odigrana linija se ispisuje ispod table.
   Potrebno: Windows i telefon.

39. [ ] **Ime repertoara se samo predloži iz baze otvaranja.** [29.b828]
   O čemu se radi: Ime repertoara se samo predlaže iz baze otvaranja dok
   korisnik ništa ne otkuca ručno; ručno otkucano ime se više ne dira.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` →
   `Open repertoire` → `New`.
   Uradi: Odigrati poznato otvaranje (npr. sicilijanku) i pogledati polje
   `Name`; zatim ručno otkucati neko drugo ime i odigrati još jedan potez.
   Treba da vidiš: Polje `Name` se samo popuni predlogom oblika „<otvaranje> —
   White/Black" (npr. „Sicilian Defense — Black"); pošto se ime ručno otkuca,
   sledeći potezi ga više ne menjaju.
   Potrebno: Windows i telefon.

40. [ ] **„Choose opening" postavlja liniju, stranu i predlaže ime.** [29.b829]
   O čemu se radi: Isto pretraživanje otvaranja kao u Analizi.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` →
   `Open repertoire` → `New` → `Choose opening`.
   Uradi: Pritisnuti `Choose opening`, ukucati „Smith-Morra" i kliknuti na
   rezultat.
   Treba da vidiš: Cela linija se postavi na tablu, strana na potezu se
   izabere, a ime se predloži.
   Potrebno: Windows i telefon.

41. [ ] **„Back" vraća potez, „Reset" celu liniju.** [29.b830]
   O čemu se radi: Dva odvojena dugmeta menjaju liniju drugačije: jedno vraća
   jedan potez, drugo celu liniju.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` →
   `Open repertoire` → `New`.
   Uradi: Odigrati nekoliko poteza, pa pritisnuti `Back`, pa `Reset`.
   Treba da vidiš: `Back` vraća jedan potez unazad; `Reset` vraća na početnu
   poziciju (praznu liniju).
   Potrebno: Windows i telefon.

42. [ ] **„Create" ugašeno dok na potezu nije izabrana strana.** [29.b831]
   O čemu se radi: Dugme `Create` je ugašeno dok na potezu nije strana za koju
   se repertoar gradi, a rečenica iznad kaže čiji je potez.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` →
   `Open repertoire` → `New`.
   Uradi: Odigrati potez tako da na potezu bude suprotna strana od izabrane
   (`White`/`Black`), pa pogledati dugme `Create` i rečenicu iznad njega; zatim
   promeniti izabranu stranu.
   Treba da vidiš: `Create` je ugašeno, a rečenica iznad kaže „… is to move.
   Play one more move, or switch sides." posle promene strane dugme se pali.
   Potrebno: Windows i telefon.

43. [ ] **„Paste FEN": neispravan niz kaže da nije ispravan.** [29.b833]
   O čemu se radi: Dugme `Paste FEN` postavlja poziciju iz unetog niza;
   neispravan niz mora da kaže da nije ispravan, ne „nije sačuvano".
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` →
   `Open repertoire` → `New` → `Paste FEN`.
   Uradi: Pritisnuti `Paste FEN` i uneti nasumičan tekst koji nije ispravan
   FEN.
   Treba da vidiš: Poruka kaže `That position is invalid — check the FEN.`, ne
   „nije sačuvano".
   Potrebno: Windows i telefon.

44. [ ] **Prazno ime: „Create" ugašeno i piše zašto.** [29.b835]
   O čemu se radi: Dok je polje `Name` prazno, dugme `Create` je ugašeno i
   ispod njega mora da piše zašto.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` →
   `Open repertoire` → `New`.
   Uradi: Postaviti ispravnu poziciju (stranu na potezu tačnu) ali ostaviti
   polje `Name` prazno.
   Treba da vidiš: Dugme `Create` je ugašeno, a ispod stoji
   `Enter a repertoire name.`.
   Potrebno: Windows i telefon.

45. [ ] **Napravljen repertoar se odmah otvara sa imenom u naslovu.** [29.b838]
   O čemu se radi: Kad se repertoar napravi (`Create`), on se odmah otvara sa
   svojim imenom u naslovu.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` →
   `Open repertoire` → `New` → `Create`.
   Uradi: Popuniti ime i pritisnuti `Create`.
   Treba da vidiš: Repertoar se odmah otvori, a ime stoji u naslovu ekrana.
   Potrebno: Windows i telefon.

46. [ ] **Isto ime drugi put: poruka da je zauzeto.** [29.b839]
   O čemu se radi: Server odbija drugi repertoar sa istim imenom, drugačijom
   porukom od greške o poziciji ili serveru.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` →
   `Open repertoire` → `New`.
   Uradi: Napraviti repertoar, pa pokušati da se napravi drugi sa istim imenom.
   Treba da vidiš: Poruka kaže da je to ime već zauzeto (server javlja „That
   name is already taken.").
   Potrebno: Windows i telefon.

47. [ ] **Ugašen backend: poruka da server nije dostupan.** [29.b840]
   O čemu se radi: Kad backend nije dostupan, dugme `Create` javlja to jasno,
   drugačije od greške o imenu ili poziciji.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` →
   `Open repertoire` → `New`.
   Uradi: Ugasiti backend i pokušati `Create`.
   Treba da vidiš: Poruka kaže
   `Server is unavailable — check if the backend is running.`.
   Potrebno: Windows i telefon.

### Practise — Repertoar — izgradnja

1. [ ] **Ask engine posle sopstvenog poteza analizira tu istu poziciju.**
   [170.5]
   O čemu se radi: Kad tabla stane posle tvog poteza (protivnik na potezu),
   motor mora da analizira baš tu poziciju, ne onu iza nje.
   Gde: Practise → `Opening repertoire` → otvori repertoar → odigraj svoj
   potez.
   Uradi: Odigraj svoj potez u gradnji repertoara i sačekaj da tabla stane.
   Pritisni `Ask engine`.
   Treba da vidiš: `Ask engine` je vidljivo i radi; panel `Engine` pokazuje
   linije za poziciju na kojoj tabla stoji (posle tvog poteza).
   Potrebno: Windows; debug build.

2. [ ] **Ask engine radi i kad knjiga ćuti, strelica motora se vidi.** [170.6]
   O čemu se radi: Kad knjiga nema odgovor za poziciju, motor i dalje može da
   se pita, i njegova strelica se ubaci tamo gde knjiga nije nacrtala nijednu.
   Gde: Practise → `Opening repertoire` → otvori repertoar → linija bez
   odgovora knjige.
   Uradi: Uđi u liniju gde piše „The book has no reply here“ i pritisni
   `Ask engine`.
   Treba da vidiš: `Ask engine` i dalje postoji i radi; kad motor odgovori, na
   tabli se vidi njegova strelica, tamo gde knjiga nije nacrtala nijednu.
   Potrebno: Windows; debug build.

3. [ ] **Obrisan protivnikov odgovor se ne vraća sam kad se potez ponovi.**
   [166.4]
   O čemu se radi: Kad se obriše protivnikov odgovor iz stabla, on ne sme da se
   automatski vrati samo zato što se tvoj potez ispred njega ponovo odigra.
   Gde: Practise → `Opening repertoire` → otvori repertoar.
   Uradi: Obriši protivnikov odgovor (dugi pritisak →
   `Delete this opponent move`), pa ponovo odigraj svoj prethodni potez od
   početne pozicije.
   Treba da vidiš: Obrisani odgovor se ne vraća u stablo.
   Potrebno: Windows.

4. [ ] **Brisanje poteza pita samo kad bi povuklo dalje poteze.** [166.6]
   O čemu se radi: Brisanje sopstvenog poteza koji ima nastavak mora da pita i
   kaže koliko poteza ide s njim; potez bez nastavka se briše bez pitanja.
   Gde: Practise → `Opening repertoire` → otvori repertoar → stablo.
   Uradi: Obriši sopstveni potez iza kog postoje tvoji dalji potezi. Zatim
   obriši potez koji nema ništa iza sebe.
   Treba da vidiš: Prvo brisanje pita „Delete …?“ i kaže koliko poteza ide s
   njim; drugo brisanje se izvrši bez pitanja.
   Potrebno: Windows.

5. [ ] **Govor u gradnji repertoara čita samo pitanje i kratku poruku.**
   [166.7]
   O čemu se radi: Govor ne čita niz poteza — samo tekuće pitanje i kratku
   poruku o dodatom potezu; broj neodgovorenih pozicija se od stavke 170 više
   ne izgovara.
   Gde: Practise → `Opening repertoire` → otvori repertoar → uključi govor.
   Uradi: Uključi govor i odigraj nekoliko poteza u gradnji repertoara.
   Treba da vidiš: Čuje se samo pitanje i kratka poruka o dodatom potezu —
   nikad niz poteza ni broj neodgovorenih pozicija.
   Potrebno: Windows.

6. [ ] **Ekran objašnjava pravilo: svaki potez se igra na tabli.** [166.8]
   O čemu se radi: Ispod pitanja stoji stalno objašnjenje pravila i savet da se
   za svoju stranu preferira jedan potez, a za protivnika jedan ili više.
   Gde: Practise → `Opening repertoire` → otvori repertoar.
   Uradi: Otvori gradnju repertoara i pročitaj rečenicu ispod pitanja.
   Treba da vidiš: Piše da je svaki potez u repertoaru odigran na tabli, i
   savet „For your side, prefer one move per position; for the opponent, enter
   one or more.“
   Potrebno: Windows.

7. [ ] **Ocena motora se pamti uz poziciju.** [170.7]
   O čemu se radi: Posle pitanja motora, red „Saved: …“ ostaje uz dubinu i
   datum kad se pozicija ponovo poseti.
   Gde: Practise → `Opening repertoire` → otvori repertoar → `Ask engine`.
   Uradi: Pitaj motor na jednoj poziciji, napusti je i vrati se na nju kasnije.
   Treba da vidiš: Red „Saved: …“ (sa dubinom i datumom) je i dalje tu.
   Potrebno: Windows; debug build.

8. [ ] **Dugmad gradnje repertoara stanu u jedan čitljiv red.** [172.4]
   O čemu se radi: Vlasnik je tražio da se tri dugmeta na dnu stisnu u red i
   smanje ako treba. Popravljeno isti dan (stavka 173.3): `Ask engine`,
   `Next position` i `Drill this branch` sad stoje u jednom redu koji se
   prelama po potrebi, a traka iznad njih je takođe jedan red bez pominjanja
   Lichess-a.
   Gde: Practise → `Opening repertoire` → `Open repertoire` → otvori repertoar
   (telefon položeno).
   Uradi: Na telefonu položeno otvori gradnju repertoara i odigraj svoj potez.
   Treba da vidiš: `Ask engine`, `Next position` i `Drill this branch` su
   čitljivi u jednom redu; traka iznad njih je takođe jedan red. Presuda na
   tvom potezu stiže sama, bez pominjanja Lichess-a.
   Potrebno: telefon; telefon položeno.

9. [ ] **Gradnja repertoara ne broji neodgovorene pozicije.** [170.1]
   O čemu se radi: Brojač neodgovorenih pozicija je namerno uklonjen; ostaje
   samo broj odlučenih poteza.
   Gde: Practise → `Opening repertoire` → `Open repertoire` → otvori repertoar.
   Uradi: Otvori gradnju repertoara sa nekoliko odigranih i nekoliko
   neodgovorenih grana.
   Treba da vidiš: Ispod pitanja (npr. „What do you play with White?“) nema
   rečenice o broju neodgovorenih pozicija; u redu ispod stoji samo „decided N“
   (i „preview shortened“ ako je slika skraćena) — bez „open N“.
   Potrebno: Windows.

10. [ ] **Govor u gradnji repertoara ne izgovara brojeve, samo pitanje.**
   [170.2]
   O čemu se radi: Govor prati istu izmenu — ne čita broj neodgovorenih
   pozicija, i ne ponavlja isto pitanje dva puta zaredom.
   Gde: Practise → `Opening repertoire` → `Open repertoire` → uključi govor.
   Uradi: Uključi govor i pređi kroz nekoliko pozicija, uključujući dve
   uzastopne koje postavljaju isto pitanje, pa jednu koja prelazi na «After … —
   which opponent moves do you prepare?».
   Treba da vidiš: Čuje se samo pitanje, nikad broj. Kad se pitanje ne menja,
   rečenica se ne ponavlja; kad se pitanje promeni, čuje se nova rečenica.
   Potrebno: Windows.

11. [ ] **Gradnja obeležava poslednji potez sa oba polja i uglovima, ne samo
   bojom.** [88.1]
   O čemu se radi: Posle svakog poteza, tabla u gradnji obeležava polje odakle
   je potez pošao i polje gde je stigao.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (dodir na karticu repertoara — otvara Build).
   Uradi: Odigraj potez u gradnji repertoara i pogledaj tablu.
   Treba da vidiš: Oba polja (polazno i dolazno) su obeležena, prepoznatljivo i
   uglovima, ne samo bojom polja.
   Potrebno: Windows i telefon; server.

12. [ ] **Dril obeležava poslednji potez isto kao gradnja.** [88.2]
   O čemu se radi: Ista oznaka poslednjeg poteza mora da postoji i u drilu, ne
   samo u gradnji.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (dodir na karticu repertoara — otvara Build).
   Uradi: Odigraj potez u drilu i pogledaj tablu.
   Treba da vidiš: Oba polja poslednjeg poteza su obeležena isto kao u gradnji.
   Potrebno: Windows i telefon; server.

13. [ ] **Oznaka poslednjeg poteza nestaje kad tabla skoči na drugu poziciju.**
   [88.3]
   O čemu se radi: Skok tablom (iz radara pokrivenosti, ili otvaranje drugog
   repertoara) ne sme da ostavi oznaku sa pozicije koja više nije na ekranu.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (dodir na karticu repertoara — otvara Build).
   Uradi: Odigraj potez (oznaka se pojavi), pa skoči na drugu poziciju preko
   radara ili otvori drugi repertoar.
   Treba da vidiš: Stara oznaka poslednjeg poteza nije više vidljiva na novoj
   poziciji.
   Potrebno: Windows i telefon; server.

14. [ ] **Oznaka poslednjeg poteza preživljava uključivanje strelica.** [88.4]
   O čemu se radi: Kad se uključe strelice (knjige ili motora) preko
   `Board view` menija, oznaka poslednjeg poteza mora i dalje da bude vidljiva
   ispod njih.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (dodir na karticu repertoara — otvara Build).
   Uradi: Odigraj potez, pa uključi `Arrows with statistics` ili
   `Engine arrows` preko `Board view`.
   Treba da vidiš: Oznaka poslednjeg poteza je i dalje vidljiva zajedno sa
   strelicama.
   Potrebno: Windows i telefon; server.

15. [ ] **Traka iznad table piše ECO i ime otvaranja.** [88.5]
   O čemu se radi: Banner iznad table u gradnji ispisuje ECO kod i ime
   otvaranja za trenutnu poziciju.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (dodir na karticu repertoara — otvara Build).
   Uradi: Odigraj par poznatih poteza (npr. 1.e4 e5 2.Nf3) u gradnji.
   Treba da vidiš: Iznad table piše nešto poput „C60 · Ruy Lopez" (ECO kod i
   ime).
   Potrebno: Windows i telefon; server.

16. [ ] **Ime otvaranja se ne gubi duboko u liniji — pamti se poslednje poznato
   ime.** [88.6]
   O čemu se radi: Baza imenuje otvaranja, ne svaku poziciju; traka drži
   poslednje poznato ime umesto da se isprazni kad pozicija više nema svoje
   ime.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (dodir na karticu repertoara — otvara Build).
   Uradi: Prošetaj liniju osam do deset poteza duboko u gradnji, dalje od
   poslednje imenovane pozicije.
   Treba da vidiš: Traka iznad table i dalje pokazuje poslednje poznato ime
   otvaranja, ne prazno polje.
   Potrebno: Windows i telefon; server.

17. [ ] **Drugo otvaranje menja traku sa imenom.** [88.7]
   O čemu se radi: Kad se pređe na poziciju drugog (imenovanog) otvaranja,
   traka se ažurira na novo ime.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (dodir na karticu repertoara — otvara Build).
   Uradi: Iz pozicije jednog otvaranja pređi (novom granom ili novim
   repertoarom) na poziciju drugog, jasno imenovanog otvaranja.
   Treba da vidiš: Traka iznad table promeni ECO/ime na ono novog otvaranja.
   Potrebno: Windows i telefon; server.

18. [ ] **Traka sa otvaranjem i tabla se ne seku na telefonu.** [88.8]
   O čemu se radi: Banner sa ECO/imenom iznad table ne sme da iseče tablu ispod
   sebe na 360 dp u release build-u.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (dodir na karticu repertoara — otvara Build).
   Uradi: Na telefonu (360 dp, release build) otvori gradnju na poziciji sa
   imenovanim otvaranjem.
   Treba da vidiš: Traka sa imenom nije isečena, i tabla ispod nje se i dalje
   vidi cela.
   Potrebno: telefon; server; release build; telefon položeno.

19. [ ] **Komentar prati poziciju i kroz transpoziciju.** [84.11]
   O čemu se radi: Komentar je vezan za FEN pozicije, ne za put kojim se do nje
   stiglo — do iste pozicije stignute drugim redosledom poteza treba da nosi
   isti komentar.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (dodir na karticu repertoara — otvara Build) → (napiši komentar na poziciji)
   → (dođi do iste pozicije drugim redosledom poteza).
   Uradi: Napiši komentar na poziciji koja je dostižna transpozicijom (dva
   različita redosleda poteza vode do iste pozicije). Dođi do nje drugim
   redosledom.
   Treba da vidiš: Isti komentar je vidljiv i kad se do pozicije stigne drugim
   putem.
   Potrebno: Windows i telefon; server.

20. [ ] **Desni klik na sopstveni potez u stablu menja glavnu liniju.** [76.5]
   O čemu se radi: U grafičkom stablu gradnje, dugi pritisak (telefon) ili
   desni klik (Windows) na karticu sopstvenog poteza otvara meni sa „Promote to
   Main Line" i brisanjem. Ovo je i dalje isti mehanizam koji je bio proveravan
   31.8.2026, samo mu se od tada promenio jezik na engleski.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (dodir na karticu repertoara — otvara Build) → (stablo ispod ili pored
   table) → (desni klik na svoj potez).
   Uradi: Odigraj bar dva svoja poteza tako da postoji alternativa u istoj
   poziciji (npr. e4 i d4 kao dva zadržana poteza). Napravi da alternativa, ne
   glavni potez, bude ★. U stablu desnim klikom (ili dugim pritiskom) na
   karticu alternative izaberi `Promote to Main Line`.
   Treba da vidiš: ★ oznaka pređe na kliknutu karticu, poruka na dnu ekrana
   kaže da je taj potez sad glavni, i karticu koja je dodirnuta desnim klikom
   pa `Delete this move` — kartica i sve što je pod njom nestaju iz stabla.
   Potrebno: Windows i telefon; server.

21. [ ] **Numeracija poteza u stablu počinje od prave pozicije.** [76.9]
   O čemu se radi: Grafičko stablo (deljeno sa Analizom) crta brojeve poteza iz
   FEN-a korena repertoara, ne od prvog poteza partije — bitno kad repertoar
   kreće sa kapije dublje u liniji.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (dodir na karticu repertoara — otvara Build) → (napravi ili otvori repertoar
   sa kapijom na četvrtom potezu) → (stablo).
   Uradi: Napravi (ili nađi) repertoar čija je kapija/koren na poziciji posle
   3. poteza (npr. posle 1.e4 c5 2.Nf3 d6), pa u stablu odigraj sledeći potez.
   Treba da vidiš: Kartica u stablu i traka iznad table pokazuju potez sa
   brojem 4 (npr. „4. c3"), ne „1. c3".
   Potrebno: Windows i telefon; server.

22. [ ] **Kartice belih i crnih poteza imaju različito svetle ivice u stablu.**
   [76.10]
   O čemu se radi: Deljeni grafički prikaz stabla boji ivicu kartice po strani
   koja je potez odigrala (`context.colors.sideWhite` naspram tamnije verzije),
   a izabrana kartica je dodatno označena — nezavisno od stare gradnje preko
   upita.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (dodir na karticu repertoara — otvara Build) → (stablo).
   Uradi: Otvori repertoar sa bar dva poteza obe strane i pogledaj ivice
   kartica belih i crnih poteza, pa dodirni jednu karticu da postane izabrana.
   Treba da vidiš: Kartice belih poteza imaju svetliju ivicu, crnih tamniju
   (ili obrnuto, ali dosledno), a izabrana kartica se jasno razlikuje od
   neizabranih bez obzira na tu boju.
   Potrebno: Windows i telefon; server.

23. [ ] **Miš i tastatura se slažu na svakom ekranu sa granama.** [78.7]
   O čemu se radi: Pravilo važi na svakom ekranu sa trakom za kretanje kroz
   poteze: dugme za sledeći potez i strelica desno postavljaju isto pitanje o
   grani.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (dodir na karticu repertoara — otvara Build) i `Analyse` → (pozicija sa
   granom) → dugme naspram strelice desno.
   Uradi: Na bar dva ekrana sa granama (Repertoire i Analysis Studio) uporedi
   šta se desi kad se pritisne dugme za sledeći potez naspram strelice desno na
   tastaturi, na istoj poziciji.
   Treba da vidiš: Na svakom ekranu dugme i strelica desno daju identičan
   rezultat — ili oba otvore isti izbor grane, ili oba pređu na isti sledeći
   potez.
   Potrebno: Windows i telefon; server.

24. [ ] **„Ask AI about position" daje odgovor i nudi da ga prenese u
   komentar.** [84.16]
   O čemu se radi: Dugme sa ikonicom „auto_awesome" pita model o poziciji;
   ponuđeni tekst se prenosi u editor komentara tek preko „Add to my comment",
   a ništa se ne snima dok se komentar posebno ne sačuva. Bez konfigurisanog
   ključa za model server vraća rezervni tekst, ne grešku.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (dodir na karticu repertoara — otvara Build) → (traka ispod table) →
   `Ask AI about position`.
   Uradi: Na bilo kojoj poziciji pritisni `Ask AI about position` i sačekaj
   odgovor. U dijalogu pritisni `Add to my comment`, pa proveri da li se
   komentar snimio bez pritiska na `Save`.
   Treba da vidiš: Dijalog „AI on position" prikaže smislen tekst (ili razuman
   rezervni tekst ako model nije dostupan); posle `Add to my comment` se otvori
   editor sa tim tekstom, ali komentar nije sačuvan dok se ne pritisne `Save` u
   editoru.
   Potrebno: Windows i telefon; server.

25. [ ] **Prekidač `Arrows with statistics` gasi samo knjižne strelice u
   gradnji repertoara.** [93.4]
   O čemu se radi: Isti ekran kao prethodna stavka (izgradnja repertoara),
   obrnut prekidač. Tabla crta jedan sloj strelica u zavisnosti od toga ko je
   na potezu: posle tvog poteza strelice iz knjige (ako je
   `Arrows with statistics` uključen i knjiga ima nešto za tu poziciju), inače
   strelice motora; pre tvog poteza strelice motora, inače tvoj sačuvani potez.
   Ako posle isključivanja nema nijedne strelice, to je često očekivano — nema
   knjige za tu poziciju, ili si na potezu ti.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (dodir na karticu repertoara — otvara Build) → (ikonica table, gore desno) →
   `Board view`.
   Uradi: Odigraj sopstveni potez na poziciji gde knjiga ima poznate
   protivničke odgovore (tabla sad stoji „posle vašeg poteza", knjižne strelice
   bi trebalo da se vide). Uključi sva tri prekidača u `Board view`, potvrdi da
   se vide knjižne strelice, pa isključi samo `Arrows with statistics`. Zatim,
   na poziciji **pre** vašeg poteza (vaš je red), proveri da `Engine arrows`
   ili „Arrows for the selected move" i dalje crtaju svoju strelicu.
   Treba da vidiš: Posle isključivanja `Arrows with statistics`, knjižne
   strelice nestanu sa pozicije posle vašeg poteza, dok na poziciji pre vašeg
   poteza strelice motora (ili vašeg zadržanog poteza, ako je motor isključen)
   i dalje stoje — nijedan drugi sloj ne nestaje zajedno sa knjižnim.
   Potrebno: Windows i telefon; server.

26. [ ] **Strelice knjige na tabli: najviše četiri, ništa ispod 2%.** [77.5]
   O čemu se radi: Kad je uključen prekidač `Arrows with statistics` (meni
   `Board view` na tabli), poteze iz knjige aplikacija crta kao strelice,
   ograničene na najčešće i na udeo od bar 2% — dok red čipova ispod table i
   dalje nudi sve poteze.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (dodir na karticu repertoara — otvara Build) → (ikonica table, gore desno) →
   `Board view` → uključi `Arrows with statistics`.
   Uradi: Otvori poziciju posle sopstvenog poteza gde knjiga poznaje više
   odgovora. Uključi „Arrows with statistics" u meniju table i prebroj nacrtane
   strelice, pa uporedi sa punim redom čipova ispod table.
   Treba da vidiš: Na tabli je najviše četiri strelice i nijedna ne predstavlja
   potez ispod 2% udela, dok red čipova ispod table i dalje nabraja sve poznate
   poteze.
   Potrebno: Windows i telefon; server.

27. [ ] **Naknadno dodat protivnikov odgovor se odmah računa u drilu.** [83.5]
   O čemu se radi: Kad se u gradnji doda još jedan protivnikov odgovor na već
   pokrivenu poziciju, taj odgovor sme da se pojavi u sledećem drilu iako ga
   knjiga ne zna kao najigraniji.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (dodir na karticu repertoara — otvara Build) → (odigraj dodatni protivnikov
   odgovor na tabli) → (nazad na listu) → `Drill` (ikonica na kartici
   repertoara).
   Uradi: U gradnji, na poziciji gde protivnik već ima jedan unet odgovor,
   odigraj na tabli još jedan njegov potez i uveri se da je upisan u stablo.
   Zatim otvori dril iste grane.
   Treba da vidiš: Dril u toj poziciji ume da postavi i taj naknadno dodati
   protivnikov potez, ne samo prvobitni.
   Potrebno: Windows i telefon; server.

28. [ ] **Brisanje celog teksta komentara uklanja karticu komentara.** [84.12]
   O čemu se radi: Snimanje praznog teksta u editoru komentara se tumači kao
   brisanje komentara, ne kao komentar od nula karaktera.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (dodir na karticu repertoara — otvara Build) → (navigaciona traka ispod
   table) → `Edit comment` → (obriši sav tekst) → `Save`.
   Uradi: Na poziciji sa napisanim komentarom otvori uređivanje komentara,
   obriši sav tekst i sačuvaj.
   Treba da vidiš: Kartica komentara nestaje i ispod table i u koloni/panelu sa
   komentarom, kao da komentara nikad nije bilo.
   Potrebno: Windows i telefon; server.

29. [ ] **Pozicija koju knjiga ne poznaje ostavlja prazno polje imena, bez
   izmišljenog naziva.** [90.3]
   O čemu se radi: U dijalogu „Fork into new opening", polje za ime novog
   otvaranja je prazno sa kursorom kad pozicija nije u ECO bazi — aplikacija ne
   izmišlja ime.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (dodir na karticu) → (traka ispod table) → `Extract into new opening`.
   Uradi: Otvori „Extract into new opening" na poziciji koju lokalna baza
   otvaranja ne prepoznaje po imenu.
   Treba da vidiš: Polje za ime u dijalogu „Fork into new opening" je prazno,
   spremno za kucanje, bez unapred popunjenog izmišljenog naziva.
   Potrebno: Windows i telefon; server.

30. [ ] **Dijalog „Fork into new opening" nudi izbor kapije koji sme da se
   preskoči.** [90.4]
   O čemu se radi: Dijalog za izdvajanje u novo otvaranje nudi isti izbornik
   kapije kao svuda drugde („Which move does it go through?"), sa opcijom da se
   ne postavi ništa.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (dodir na karticu) → (traka ispod table) → `Extract into new opening`.
   Uradi: Otvori „Extract into new opening" na poziciji sa više mogućih
   nastavaka i pogledaj ponuđeni izbor kapije unutar tog dijaloga.
   Treba da vidiš: U dijalogu stoji izbor „Which move does it go through?" sa
   istim oblikom kao u glavnom izboru kapije, uključujući opciju bez
   ograničenja; izbor sme da se preskoči/ostavi prazan.
   Potrebno: Windows i telefon; server.

31. [ ] **Traka sa dugmadima ispod table se prelama na telefonu, tastatura ne
   pokriva komentar.** [84.16]
   O čemu se radi: Traka ispod table u gradnji ima tri dodatna dugmeta (fork,
   komentar, AI) pored navigacije; na 360 dp moraju da se prelome u dva reda
   bez sečenja, a tastatura pri pisanju komentara ne sme da prekrije polje za
   unos.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (dodir na karticu repertoara — otvara Build) → (traka ispod table:
   `Extract into new opening`, `Add comment`, `Ask AI about position`).
   Uradi: Na telefonu (360 dp, release build) pogledaj traku ispod table sa
   svom dugmadi. Zatim otvori uređivanje komentara i dodirni polje za tekst da
   se otvori tastatura.
   Treba da vidiš: Dugmad se prelome u dva reda bez sečenja ijednog. List za
   uređivanje komentara se podigne iznad tastature — polje za pisanje ostaje
   vidljivo.
   Potrebno: telefon; server; release build; telefon položeno.

32. [ ] **Paleta ispod table i tastatura pomeraju liniju u gradnji.** [76.8]
   O čemu se radi: Traka za kretanje (prva/prethodna/sledeća/poslednja
   pozicija) je od 18.9.2026 ista u celoj aplikaciji, a strelice na tastaturi
   (←, →, Home, End) rade isto što i njena dugmad.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (dodir na karticu repertoara — otvara Build) → (paleta ispod table:
   `Go to start` / `Previous move` / `Next move` / `Go to end`).
   Uradi: U izgradnji repertoara odigraj tri-četiri poteza. Koristi dugmad
   palete da se vratiš na početak i ponovo odeš na kraj, pa isto probaj
   tastaturom: Home, ←, →, End.
   Treba da vidiš: Tabla i pitanje iznad nje prate poziciju na svakom koraku,
   dugmetom i tasterom podjednako; na početku su `Go to start`/`Previous move`
   onemogućeni, na kraju `Next move`/`Go to end`.
   Potrebno: Windows i telefon; server.

33. [ ] **Na račvi „napred" pita kojom granom ići — dugme i strelica se
   slažu.** [78.1, 77.3]
   O čemu se radi: Kad pozicija ima više nastavaka, dugme za sledeći potez i
   strelica desno na tastaturi moraju da otvore isti izbor grane. Vlasnik je
   1.9.2026 prijavio da strelica desno ne radi ništa, a strelica dole prolazi
   glavnom granom bez pitanja; popravljeno je tako da strelica pita isto što i
   dugme.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (dodir na karticu repertoara — otvara Build) → (pozicija sa dva ili više
   zadržana poteza) → (dugme `Next move` ili strelica desno).
   Uradi: Napravi poziciju sa dva zadržana poteza za istu stranu (npr. e4 i d4
   posle iste prethodne linije). Pritisni dugme za sledeći potez u paleti ispod
   table, zatvori izbor, pa probaj isto strelicom desno na tastaturi. Zatim
   probaj strelicu dole i taster End.
   Treba da vidiš: I dugme i strelica desno otvaraju list „Multiple lines from
   here — which one?" sa istim granama; izbor vodi tablu tom granom. Strelica
   dole i End idu do kraja linije bez pitanja — to je namerno (odlazak „na
   kraj" nikad ne pita).
   Potrebno: Windows i telefon; server.

34. [ ] **List za izbor grane i poruke ne preklapaju ekran na telefonu.**
   [77.6]
   O čemu se radi: Lista „Multiple lines from here — which one?" i poruke na
   dnu ekrana moraju da stanu na telefonu (360 dp) u release build-u, bez
   preklapanja ili sečenja.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (dodir na karticu repertoara — otvara Build) → (na 360 dp, release build) →
   (pozicija sa granom) → `Next move`.
   Uradi: Na telefonu (ili emulatoru 360 dp) u release build-u otvori granatu
   poziciju, pritisni dugme za sledeći potez da se otvori list izbora, izaberi
   granu i posmatraj poruku koja se javi.
   Treba da vidiš: List sa granama se u potpunosti vidi i ne seče se; poruka na
   dnu ekrana posle izbora ne preklapa list niti traku ispod table.
   Potrebno: telefon; server; release build; telefon položeno.

35. [ ] **Mašina bez instaliranog glasa ne ruši ekran i to se vidi u
   podešavanjima.** [92.7]
   O čemu se radi: Windows po pravilu nema srpski/engleski glas dok se ne
   instalira — to je uredno stanje, ne kvar: panel mora da se crta isto, a
   zvučnik ne sme ni da obori ekran ni da ćuti bez objašnjenja.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (dodir na karticu repertoara — otvara Build) i `Practise` → (kartica
   „Opening repertoire") → `Open repertoire` → `Drill` (ikonica na kartici
   repertoara) → (Settings → govor).
   Uradi: Na Windows mašini bez instaliranog glasa za TTS, otvori gradnju ili
   dril repertoara i pritisni zvučnik. Zatim proveri podešavanja govora u
   Settings.
   Treba da vidiš: Ekran se crta normalno i ništa se ne ruši; podešavanja
   govora jasno kažu da nema dostupnog glasa (ne samo u logu).
   Potrebno: Windows; server.

36. [ ] **Desni klik na stablu javlja rezultat porukom na dnu ekrana.** [77.4]
   O čemu se radi: Posle „Promote to Main Line" ili brisanja poteza iz menija u
   stablu, ekran mora da kaže šta se desilo porukom na dnu ekrana, ne samo tiho
   da promeni stablo.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (dodir na karticu repertoara — otvara Build) → (stablo) → (desni klik na
   potez) → `Promote to Main Line` / `Delete this move`.
   Uradi: Desnim klikom na sopstveni potez izaberi `Promote to Main Line`;
   zatim na drugi potez (svoj ili protivnikov) izaberi brisanje.
   Treba da vidiš: Posle svake radnje se na dnu ekrana pojavi kratka poruka
   (npr. „X is now your main move.", ili poruka o brisanju) — ne samo promena u
   stablu bez ikakve poruke.
   Potrebno: Windows i telefon; server.

37. [ ] **Tabla okrenuta ka izabranoj boji, pitanje „What do you play"**
   [29.b845]
   O čemu se radi: Ekran za gradnju repertoara na tabli pita „What do you play
   with White?"/„…Black?" prema izabranoj boji, a tabla je okrenuta na tu
   stranu.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` → otvoriti
   repertoar građen za crnog.
   Uradi: Otvoriti takav repertoar.
   Treba da vidiš: Tabla je okrenuta sa crnim dole, a iznad table piše
   `What do you play with Black?`.
   Potrebno: Windows i telefon.

38. [ ] **Rokada se ispravno odigra i markira kao sopstveni potez.** [29.b854]
   O čemu se radi: U gradnji repertoara na tabli, odigrana rokada mora da se
   markira zvezdicom u panelu „Your moves here" kao svaki drugi potez; klik na
   čip „O-O" u knjizi otvaranja mora da odigra rokadu.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` → otvoriti
   repertoar → pozicija gde je rokada moguća.
   Uradi: Odigrati O-O na tabli; zatim, na drugoj poziciji, kliknuti na čip
   „O-O" u redu knjige otvaranja.
   Treba da vidiš: Rokada se odigra ispravno i pojavljuje se u panelu „Your
   moves here" markirana zvezdicom; klik na čip „O-O" takođe ispravno odigra
   rokadu.
   Potrebno: Windows i telefon.

39. [ ] **Dodir na potez u „Your moves here" ga postavlja za glavni.**
   [29.b859]
   O čemu se radi: U panelu „Your moves here" dodir na potez koji nije glavni
   ga postavlja za glavni (zvezdica se pomeri) — to je potez koji će dril
   tražiti.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` → otvoriti
   repertoar.
   Uradi: U istoj poziciji odigrati drugi potez (postaje alternativa u panelu
   „Your moves here"), pa dodirnuti taj red.
   Treba da vidiš: Zvezdica se pomeri na dodirnuti potez — on postaje glavni,
   isti koji će dril tražiti.
   Potrebno: Windows i telefon.

40. [ ] **Isti potez uzet dvaput ne pravi duplikat.** [29.b867]
   O čemu se radi: Isti potez uzet dvaput na istoj poziciji ne sme da napravi
   duplikat u panelu „Your moves here".
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` → otvoriti
   repertoar.
   Uradi: Odigrati isti potez dvaput na istoj poziciji (npr. vratiti se pa ga
   ponovo odigrati).
   Treba da vidiš: U panelu „Your moves here" potez se pojavljuje samo jednom,
   bez duplikata.
   Potrebno: Windows i telefon.

41. [ ] **Izabrani potezi ostaju posle zatvaranja i ponovnog otvaranja.**
   [29.b868]
   O čemu se radi: Zatvaranje i ponovno otvaranje repertoara mora da sačuva sve
   izabrane poteze (red pozicija u redu za gradnju ne mora da bude isti — to je
   namerno).
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` → otvoriti
   repertoar.
   Uradi: Zatvoriti repertoar i ponovo ga otvoriti iz spiska.
   Treba da vidiš: Svi ranije odigrani/markirani potezi su i dalje tu (red
   pozicija u redu za gradnju ne mora da bude isti — to je namerno).
   Potrebno: Windows i telefon.

42. [ ] **„Ask engine" daje linije na izabranoj dubini i broju linija.**
   [29.b855]
   O čemu se radi: Dugme `Ask engine` otvara panel „Engine" sa dva klizača
   (dubina i broj linija); klik na liniju odigra njen prvi potez, koji prolazi
   kroz isti sud kao ručno odigran potez.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` → otvoriti
   repertoar → `Ask engine`.
   Uradi: Pritisnuti `Ask engine` i pogledati klizače dubine i broja linija u
   panelu „Engine"; kliknuti na jednu ponuđenu liniju.
   Treba da vidiš: Prikazuju se linije prema podešenoj dubini i broju linija;
   klik na liniju odigra njen prvi potez na tabli.
   Potrebno: Windows i telefon.

43. [ ] **Motor radi lokalno, bez Lichess tokena.** [29.b856]
   O čemu se radi: Motor za predloge u gradnji repertoara radi lokalno i ne
   zahteva Lichess token.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` → otvoriti
   repertoar → `Ask engine`.
   Uradi: Bez unetog Lichess tokena pritisnuti `Ask engine`.
   Treba da vidiš: Motor ipak odgovara linijama (radi lokalno, ne troši kvotu).
   Potrebno: Windows i telefon.

44. [ ] **Promena dubine odmah ponovo pokreće motor.** [29.b857]
   O čemu se radi: Promena dubine ili broja linija u panelu „Engine" mora odmah
   da ponovo pokrene motor, ne da ostavi stari odgovor.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` → otvoriti
   repertoar → `Ask engine`.
   Uradi: Dok motor prikazuje linije, promeniti klizač dubine (ili broja
   linija) u panelu „Engine".
   Treba da vidiš: Motor se odmah ponovo pokreće na novoj dubini/broju linija —
   stari odgovor ne ostaje da stoji.
   Potrebno: Windows i telefon.

45. [ ] **Stari odgovor motora ne sme da se pojavi u novoj poziciji.**
   [29.b858]
   O čemu se radi: Ako se pozicija promeni pre nego što motor odgovori, stari
   odgovor ne sme da se pojavi u novoj poziciji.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` → otvoriti
   repertoar → `Ask engine`.
   Uradi: Pritisnuti `Ask engine` na visokoj dubini, pa pre nego što motor
   odgovori odigrati potez (ili preći na drugu poziciju).
   Treba da vidiš: Stari odgovor se ne pojavljuje u novoj poziciji.
   Potrebno: Windows i telefon.

46. [ ] **Tabla uzima pola visine i na telefonu.** [104.24]
   O čemu se radi: Tabla u izgradnji repertoara zauzima najviše polovinu visine
   prozora, da ispod nje ostane mesta za pitanje i odgovore — isto pravilo na
   telefonu i na računaru.
   Gde: `Practise` → (kartica) `Opening repertoire` → `Open repertoire` → (red
   repertoara).
   Uradi: Otvori gradnju repertoara na telefonu, u uspravnom položaju.
   Treba da vidiš: Tabla zauzima otprilike pola visine ekrana, nije prevelika
   ni presitna za igru, a ispod nje ostaje vidljivo mesta za pitanje/odgovore
   bez potrebe za skrolovanjem samo do table.
   Potrebno: telefon.

47. [ ] **Ime otvaranja u zaglavlju ne nestaje pri promeni širine prozora.**
   [104.28]
   O čemu se radi: Baner sa imenom otvaranja pamti poslednje imenovano
   otvaranje (ne briše ga kad tabla ode dublje u liniju bez svog imena) i
   preživljava selidbu između zaglavlja (na širini preko 1200 dp) i kolone
   pored table (ispod 1200 dp), jer nosi stalan ključ.
   Gde: `Practise` → (kartica) `Opening repertoire` → `Open repertoire` → (red
   repertoara).
   Uradi: Odigraj poteze dok ne stigneš do pozicije koja više nema svoje ime
   otvaranja (dublje u liniji), na prozoru širem od 1200 dp. Zatim vuci desnu
   ivicu Windows prozora preko 1200 dp granice gore-dole nekoliko puta.
   Treba da vidiš: Ime poslednjeg imenovanog otvaranja ostaje vidljivo cело
   vreme (u zaglavlju iznad 1200 dp, pored table ispod te širine) — ne nestaje
   ni na jednoj strani praga.
   Potrebno: Windows.

48. [ ] **Rupa (?) se vidi u tamnoj temi bez čitanja oznake.** [97.1]
   O čemu se radi: Kartica sa upitnikom (?) predstavlja potez bez pripremljenog
   odgovora u repertoaru. Popravka je ivicu rupe učinila punom jačinom i deblje
   (3.0) od svih drugih kartica, sa blagom ispunom iza nje, umesto stare
   providne ivice koja se gubila u tamnoj temi.
   Gde: `Practise` → (kartica) `Opening repertoire` → `Open repertoire` → (red
   repertoara) → stablo sa bar jednom rupom.
   Uradi: Otvori repertoar koji ima bar jedan neodgovoren protivnikov potez
   (karticu sa `?`). U Podešavanjima postavi `App theme:` na `Dark`. Pogledaj
   grafičko stablo bez čitanja teksta na karticama.
   Treba da vidiš: Kartica sa `?` se izdvaja od ostalih golim okom — ivica joj
   je vidno deblja i puna, sa blagom ispunom iza. Ako sve kartice deluju
   podjednako i rupa se mora tražiti čitanjem oznaka, to je pad provere.
   Potrebno: Windows i telefon.

49. [ ] **Ivica rupe više ne kodira boju koja je na potezu.** [97.2]
   O čemu se radi: Stara ivica rupe je bojom (belo/crno) govorila čija je
   strana na potezu, uz manju providnost. Popravka od 4.9.2026 je to namerno
   uklonila: svaka rupa sada ima istu neutralnu punu ivicu, jer je unutar
   jednog repertoara strana uvek ista (repertoar je ili za belog ili za crnog),
   pa je boja na ivici bila suvišan podatak koji je nosio i manji kontrast.
   Gde: `Practise` → (kartica) `Opening repertoire` → `Open repertoire` → (red
   repertoara) → stablo sa bar dve rupe.
   Uradi: Otvori repertoar sa bar dve rupe — jednu na poziciji gde je upravo
   odigran beli potez, jednu gde je upravo odigran crn potez (ili uporedi rupu
   u repertoaru za belog i rupu u repertoaru za crnog). Pogledaj ivice obe
   kartice.
   Treba da vidiš: Sada je namerno tako da obe ivice izgledaju isto (ista
   neutralna boja i debljina 3.0), bez obzira čija je strana na potezu — to
   više nije regresija nego svesna izmena, jer boja strane unutar jednog
   repertoara ionako ne razlikuje ništa (uvek je ista). Ako ti ovo ne odgovara
   i želiš da se strana i dalje vidi po boji ivice, reci — to bi bila nova
   odluka, ne popravka kvara.
   Potrebno: Windows i telefon.

50. [ ] **Rupa u svetloj temi nije tamna mrlja.** [97.3]
   O čemu se radi: Ista izmena ivice rupe (puna jačina, deblja ivica, blaga
   ispuna) je jedna implementacija bez posebne grane za svetlu temu — boja
   ivice i ispune se sama prilagođava temi.
   Gde: `Practise` → (kartica) `Opening repertoire` → `Open repertoire` → (red
   repertoara) → stablo sa bar jednom rupom.
   Uradi: Isti repertoar iz prethodne dve stavke, sada u Podešavanjima postavi
   `App theme:` na `Light`.
   Treba da vidiš: Rupa je i dalje samo deblje/punije uokvirena kartica, ne
   tamna ili obojena mrlja koja odudara od ostatka stabla.
   Potrebno: Windows i telefon.

51. [ ] **Sačuvana ocena motora ostaje uz poziciju.** [75.1]
   O čemu se radi: Ocena motora zatražena preko `Ask engine` se čuva uz
   poziciju (tekst, dubina i datum) i ostaje i posle napuštanja i ponovnog
   otvaranja ekrana.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (otvoriti
   repertoar) → `Ask engine`.
   Uradi: Pritisnuti `Ask engine`, sačekati odgovor, otići na drugu poziciju i
   vratiti se; zatim zatvoriti i ponovo otvoriti ekran izgradnje.
   Treba da vidiš: Uz tablu i dalje piše sačuvana ocena, oblika „Saved: … ·
   depth … · datum".
   Potrebno: Windows i telefon; server; lokalni Stockfish motor.

52. [ ] **Dubina i datum stoje uz ocenu.** [75.2]
   O čemu se radi: Sačuvana ocena prikazuje dubinu i datum u istom redu sa
   brojem ocene; datum mora biti današnji odmah posle pitanja motora.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (otvoriti
   repertoar) → `Ask engine`.
   Uradi: Pitati motor o poziciji i pogledati prikazani tekst.
   Treba da vidiš: U istom redu piše ocena, „depth N" i današnji datum.
   Potrebno: Windows i telefon; server.

53. [ ] **Plića ocena ne gazi dublju.** [75.3]
   O čemu se radi: Ako je pozicija već ocenjena na većoj dubini, ponovno
   pitanje na manjoj dubini ne sme da zameni sačuvanu (dublju) ocenu.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (podesiti veću
   dubinu analize, pitati motor, pa smanjiti dubinu i pitati opet).
   Uradi: Postaviti veću dubinu analize i pitati motor o poziciji, pa smanjiti
   dubinu i pitati ponovo o istoj poziciji.
   Treba da vidiš: Sačuvana ocena i njena (veća) dubina ostaju iste — ne
   zamenjuju se plićim rezultatom.
   Potrebno: Windows i telefon; server.

54. [ ] **Nema druge presude uz potez osim sudije otvaranja.** [75.10]
   O čemu se radi: Uz potez na tabli i dalje stoji samo verdikt sudije
   otvaranja (sudija otvaranja); ocena motora se ne pretvara u dodatnu presudu
   tipa „dobar"/„loš" potez.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (otvoriti
   repertoar) → `Ask engine`.
   Uradi: Odigrati potez i pitati motor o novoj poziciji; pogledati sve
   tekstove uz potez.
   Treba da vidiš: Jedina presuda o odigranom potezu dolazi od sudije
   otvaranja; ocena motora se nigde ne pretvara u „good"/„bad" oznaku poteza.
   Potrebno: Windows i telefon; server.

55. [ ] **Telefon, release build: prikaz sačuvane ocene se ne seče.** [75.11]
   O čemu se radi: Tekst sačuvane ocene motora (sa dubinom i datumom) mora da
   stane na uskom ekranu (360 dp) u release build-u.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (otvoriti
   repertoar) → `Ask engine`.
   Uradi: Pitati motor o poziciji na telefonu (360 dp, release build) i
   pogledati prikazani tekst ocene.
   Treba da vidiš: Tekst sačuvane ocene (Saved/depth/datum) se ne seče niti
   prelazi ivicu ekrana.
   Potrebno: telefon; server; release build.

56. [ ] **Brisanje poteza sa posledicama prvo pita.** [73.2]
   O čemu se radi: Brisanje sopstvenog poteza posle kog postoje dalji sopstveni
   potezi koji bi ostali nedostupni prvo prikazuje dijalog sa brojem tih
   poteza, pre nego što se bilo šta obriše.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (otvoriti
   repertoar sa linijom od bar dva poteza) → `Delete this move`.
   Uradi: Ručno izgraditi bar dva poteza duboko u jednoj liniji, pa iz kartice
   iznad njih izabrati `Delete this move`. Pritisnuti `Cancel`.
   Treba da vidiš: Pojavljuje se dijalog „Delete …?" koji kaže koliko poteza bi
   ostalo bez veze; posle `Cancel` ništa nije obrisano.
   Potrebno: Windows i telefon; server; linija duga bar dva poteza posle tačke
   brisanja.

57. [ ] **Potvrda brisanja zaista briše potomke.** [73.3]
   O čemu se radi: Potvrda u istom dijalogu briše i potez i sve sopstvene
   poteze koji su kroz njega jedino bili dostupni.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (isto kao 73.2)
   → `Delete this move` → `Delete`.
   Uradi: Ponoviti scenario iz prethodne stavke, ali potvrditi sa `Delete`.
   Treba da vidiš: Obrisan potez i njegovi potomci nestaju iz stabla.
   Potrebno: Windows i telefon; server; linija duga bar dva poteza posle tačke
   brisanja.

58. [ ] **Transpozicija preživljava brisanje.** [73.4]
   O čemu se radi: Ako dve linije vode u istu poziciju (transpozicija),
   brisanje poteza sa jedne linije ne sme da obriše zajedničku poziciju niti
   ono ispod nje ako je i dalje dostupna drugim putem.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (izgraditi dve
   linije koje se spajaju, npr. 2.Nf3 Nc6 3.Nc3 i 2.Nc3 Nc6 3.Nf3).
   Uradi: Izgraditi dve linije koje se spajaju u istu poziciju, pa obrisati
   potez sa samo jedne od njih.
   Treba da vidiš: Zajednička pozicija i sve što je ispod nje ostaju dostupni
   preko druge linije.
   Potrebno: Windows i telefon; server; dve linije koje se spajaju u istu
   poziciju.

59. [ ] **Brisanje bez posledica prolazi bez pitanja.** [73.6]
   O čemu se radi: Uklanjanje poteza iza kog nema ničega prolazi bez ikakvog
   dijaloga upozorenja.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (potez bez
   potomaka) → `Delete this move`.
   Uradi: Obrisati potez iza kog nema nijednog daljeg sopstvenog poteza.
   Treba da vidiš: Potez se odmah briše, bez ikakvog dijaloga upozorenja.
   Potrebno: Windows i telefon; server.

60. [ ] **Drill radi normalno posle brisanja poteza.** [73.7]
   O čemu se radi: Posle brisanja poteza (sa ili bez potomaka), nijedna
   pozicija ne sme da ostane bez glavnog poteza — drill mora i dalje da pita
   normalno.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (posle
   brisanja) → `Drill`.
   Uradi: Posle brisanja nekoliko poteza otvoriti drill nad istim repertoarom.
   Treba da vidiš: Drill postavlja pitanja normalno, bez pozicija na koje nema
   odgovora.
   Potrebno: Windows i telefon; server.

61. [ ] **Na Windows-u stablo stoji pored table.** [70.1]
   O čemu se radi: U izgradnji repertoara, na širokom prozoru, stablo
   repertoara se crta desno od table umesto praznog prostora.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (otvoriti
   repertoar).
   Uradi: Otvoriti izgradnju na punom Windows prozoru.
   Treba da vidiš: Desno od table se vidi crtež stabla repertoara.
   Potrebno: Windows; server; izgrađen repertoar.

62. [ ] **Tabla je veća, pitanje ostaje vidljivo bez skrolovanja.** [70.2]
   O čemu se radi: Otkad stablo stoji pored table, tabla je uvećana; pitanje
   ispod nje mora i dalje da se vidi bez skrolovanja na punom prozoru.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (otvoriti
   repertoar).
   Uradi: Otvoriti izgradnju na punom Windows prozoru i pogledati raspored.
   Treba da vidiš: Tabla je vidno veća nego u ranijem izgledu, a pitanje/tekst
   ispod nje se vidi bez skrolovanja.
   Potrebno: Windows; server.

63. [ ] **Traka ispod table: roditelj → pozicija → deca.** [70.3]
   O čemu se radi: Ispod table stoji traka koja pokazuje put od roditeljske
   pozicije preko trenutne do dečjih poteza, sa oznakama stanja; dodir na
   stavku vodi tamo.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (otvoriti
   repertoar sa razgranatom pozicijom).
   Uradi: Otvoriti poziciju koja ima i roditelja i decu u stablu, pogledati
   traku ispod table i dodirnuti jednu stavku.
   Treba da vidiš: Traka pokazuje roditelja, trenutnu poziciju i decu sa
   oznakama; dodir na stavku pomera tablu na tu poziciju.
   Potrebno: Windows; server.

64. [ ] **Dodir na protivnikov potez u stablu pomera tablu.** [70.4]
   O čemu se radi: Dodir na karticu protivnikovog poteza u ugrađenom stablu
   pomera tablu na tu poziciju, a linija iznad table se produžava.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (otvoriti
   repertoar sa protivnikovim potezom u stablu).
   Uradi: U stablu pored/ispod table dodirnuti karticu protivnikovog poteza.
   Treba da vidiš: Tabla se pomera na poziciju posle tog poteza, i linija iznad
   table se produžava za taj potez.
   Potrebno: Windows i telefon; server.

65. [ ] **Dodir na sopstveni potez u stablu stavlja tablu posle njega.** [70.5]
   O čemu se radi: Dodir na karticu sopstvenog poteza pomera tablu na poziciju
   posle njega i prikazuje šta knjiga kaže da igra protivnik tu.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (otvoriti
   repertoar sa sopstvenim potezom u stablu).
   Uradi: U stablu dodirnuti karticu sopstvenog poteza.
   Treba da vidiš: Tabla se pomera na poziciju posle tog poteza; ispod nje se
   vidi šta o toj poziciji kaže sačuvana knjiga.
   Potrebno: Windows i telefon; server.

66. [ ] **Skakanje po stablu ne remeti red za izgradnju.** [70.6]
   O čemu se radi: Posle dodira na karticu u stablu, dugmad `Ask engine` i
   `Next position` i dalje rade normalno, a red pozicija za izgradnju se ne
   menja samim skakanjem.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (otvoriti
   repertoar sa razgranatom pozicijom).
   Uradi: Dodirnuti nekoliko kartica u stablu, pa proveriti da `Next position`
   i dalje vodi na sledeću pravu poziciju za izgradnju.
   Treba da vidiš: `Next position` posle skakanja po stablu i dalje vodi na
   sledeću pravu poziciju reda, bez promene redosleda zbog samog skakanja.
   Potrebno: Windows i telefon; server.

67. [ ] **Stablo prati tablu bez ručnog osvežavanja.** [70.7]
   O čemu se radi: Posle odigranog poteza, ugrađeno stablo se samo osveži i
   nova grana se odmah vidi.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (otvoriti
   repertoar).
   Uradi: Odigrati novi potez u izgradnji i pogledati stablo pored/ispod table.
   Treba da vidiš: Nova grana se odmah pojavljuje u stablu, bez potrebe za
   ručnim osvežavanjem.
   Potrebno: Windows i telefon; server.

68. [ ] **Telefon, release build: panel stabla se ne seče.** [70.8]
   O čemu se radi: Na telefonu panel stabla stoji ispod kontrola, sklopljen; u
   release build-u se ne sme videti odsečen tekst ili preliv.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (otvoriti
   repertoar).
   Uradi: Otvoriti izgradnju na telefonu (360 dp, release build) i
   pogledati/otvoriti panel stabla ispod kontrola.
   Treba da vidiš: Zaglavlje i sadržaj panela stabla se ne seku niti prelivaju
   van svojih granica.
   Potrebno: telefon; server; release build.

69. [ ] **Dodir na trenutnu poziciju ne briše postojeću analizu.** [70.11]
   O čemu se radi: Ako je tabla već na poziciji čija je kartica dodirnuta u
   stablu, dodir ne sme da obriše već prikazane linije motora.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (otvoriti
   repertoar) → `Ask engine`.
   Uradi: Pitati motor o trenutnoj poziciji, sačekati linije, pa dodirnuti
   karticu te iste pozicije u stablu.
   Treba da vidiš: Linije motora ostaju prikazane, ne nestaju zbog dodira na
   kartu na kojoj tabla već stoji.
   Potrebno: Windows i telefon; server.

70. [ ] **Drill pita normalno posle čišćenja.** [69.6]
   O čemu se radi: Posle čišćenja uvezenih poteza nijedna pozicija ne sme da
   ostane bez glavnog poteza — drill mora i dalje normalno da pita.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (red) → `More`
   → `Clean imported moves` → (potvrditi) → `Drill`.
   Uradi: Posle čišćenja otvoriti drill nad istim repertoarom.
   Treba da vidiš: Drill postavlja pitanja normalno, bez pozicija na koje nema
   zapisanog odgovora.
   Potrebno: Windows i telefon; server.

71. [ ] **Veliki repertoar ne obara stablo pored table.** [67.9]
   O čemu se radi: Stablo repertoara je sada ugrađeno u ekran izgradnje; treba
   proveriti da se crta i da zumiranje radi i nad repertoarom sa mnogo grana.
   (Zasejavanje iz partija više ne postoji, pa veliki repertoar treba ručno
   izgraditi — npr. nekoliko puta preko „Choose opening" i igranjem više
   grana.).
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (otvoriti
   veliki repertoar).
   Uradi: Ručno izgraditi repertoar sa mnogo grana i poteza (ili koristiti
   postojeći ako takav već postoji), pa otvoriti izgradnju.
   Treba da vidiš: Stablo pored table se iscrta bez greške i
   zumiranje/pomeranje po njemu radi.
   Potrebno: Windows; server; veliki, ručno izgrađen repertoar.

72. [ ] **„Drill this branch" vežba samo tu granu.** [65.7]
   O čemu se radi: U izgradnji, na poziciji sa bar jednim sopstvenim potezom,
   dugme `Drill this branch` otvara drill koji pita samo pozicije iz te grane.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (otvoriti
   repertoar, stati na poziciju sa odigranim potezom) → `Drill this branch`.
   Uradi: Otvoriti izgradnju, stati na poziciju sa sopstvenim potezom,
   pritisnuti `Drill this branch`.
   Treba da vidiš: Drill koji se otvori pita samo pozicije iz te grane;
   pozicija iz druge grane repertoara se ne pojavljuje.
   Potrebno: Windows i telefon; server; izgrađena grana sa bar jednim potezom.

73. [ ] **Odigrani potezi se vide kao strelice na tabli, glavni sa zvezdicom.**
   [63.1]
   O čemu se radi: Potezi koje je student već odigrao na datoj poziciji se
   crtaju kao strelice na tabli; glavni (primarni) potez nosi zvezdicu „★"
   pored procenta.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (otvoriti
   repertoar, stati na poziciju sa već odigranim potezom).
   Uradi: Otvoriti poziciju u kojoj je već odigran bar jedan sopstveni potez.
   Pogledati strelice na tabli, bez oslanjanja na boju.
   Treba da vidiš: Glavni potez se prepoznaje po zvezdici „★" uz strelicu
   (deblja linija/oznaka), ne samo po boji strelice.
   Potrebno: Windows i telefon; server; izgrađen repertoar sa bar jednim
   potezom.

74. [ ] **Procenat uz strelicu se javlja samo kad je knjiga učitana za tu
   poziciju.** [63.2]
   O čemu se radi: Kad je statistika knjige za trenutnu poziciju učitana, uz
   zvezdicu glavnog poteza piše i procenat (npr. „★ 60%"); dok se knjiga
   učitava, piše samo „★".
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (otvoriti
   repertoar sa odigranim potezima).
   Uradi: Otvoriti izgrađenu poziciju i posmatrati oznaku uz strelicu odmah po
   dolasku na poziciju i posle kratkog čekanja.
   Treba da vidiš: Dok se statistika knjige za tu poziciju još ne učita, uz
   zvezdicu stoji samo „★"; kad se učita, dodaje se procenat.
   Potrebno: Windows i telefon; server.

75. [ ] **Linija iznad table, numerisana kao u knjizi.** [62.1, 62.8]
   O čemu se radi: Iznad pitanja na tabli za izgradnju repertoara stoji cela
   linija odigranih poteza, numerisana kao u šahovskoj knjizi (npr. „1. e4 e5
   2. Nf3").
   Gde: `Practise` → (odeljak „Opening") → `Opening repertoire` →
   `Open repertoire` → (otvoriti izgrađeni repertoar).
   Uradi: Otvoriti repertoar sa bar tri odigrana poteza. Pogledati tekst iznad
   table. Na telefonu (360 dp, release build) proveriti da duža linija ne
   izlazi van ekrana.
   Treba da vidiš: Iznad table stoji cela numerisana linija od prvog poteza do
   trenutne pozicije; na telefonu se linija ne seče niti prelazi ivicu ekrana.
   Potrebno: Windows i telefon; server; izgrađen repertoar sa bar tri poteza.

76. [ ] **Izgradnja nastavlja tamo gde je stala.** [62.3]
   O čemu se radi: Red pozicija za izgradnju (šetnja po repertoaru) živi na
   serveru; izlazak i ponovni ulazak u izgradnju treba da ponudi iste pozicije
   u istom redosledu.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (otvoriti
   repertoar sa bar dve nerešene pozicije).
   Uradi: Zapamtiti prve dve-tri ponuđene pozicije, izaći dugmetom `Back`, pa
   se ponovo vratiti u izgradnju.
   Treba da vidiš: Iste pozicije se nude istim redosledom kao pre izlaska.
   Potrebno: Windows i telefon; server; izgrađen repertoar sa bar dve nerešene
   pozicije.

77. [ ] **Ugašen server se ne prikazuje kao završen repertoar.** [62.6]
   O čemu se radi: Kad se sve pozicije reda potroše, ekran prikazuje „You have
   answered all positions reachable by this repertoire." sa dugmetom
   `Open repertoire`; ovaj tekst nikad nije viđen uz stvarno ugašen server.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (otvoriti
   repertoar) — pa ugasiti backend i ponovo otvoriti/osvežiti izgradnju.
   Uradi: Ugasiti backend server, pa otvoriti ili osvežiti ekran izgradnje
   repertoara.
   Treba da vidiš: Mora da se pojavi jasna poruka o grešci (server nedostupan),
   a ne rečenica „You have answered all positions reachable by this
   repertoire." koja tvrdi da je posao gotov.
   Potrebno: Windows; izgrađen repertoar; server (pa ugašen).

### Practise — Repertoar — drill

1. [ ] **Dril igra samo poteze koji su uneti u stablo.** [166.9]
   O čemu se radi: Protivnik u drilu nikad ne igra potez koji nije u tvom
   stablu — samo poteze koje si uneo (plus automatski dodat najigraniji).
   Gde: Practise → `Opening repertoire` → red repertoara → `Drill`.
   Uradi: Pokreni `Drill` na repertoaru sa nekoliko odigranih poteza i prati
   protivnikove odgovore kroz nekoliko linija.
   Treba da vidiš: Protivnik nikad ne odigra potez van onoga što je uneto u
   stablo repertoara.
   Potrebno: Windows.

2. [ ] **Dve otvaranja različitih boja se odbijaju rečenicom pri kombinovanoj
   sesiji.** [90.9]
   O čemu se radi: Kad se pokuša da se u istu kombinovanu sesiju uključi
   repertoar druge boje, aplikacija to odbija porukom umesto da tiho ignoriše.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (uključi izbor kvačicama na dve ili više kartica iste boje) →
   `Drill selected …`.
   Uradi: Izaberi kvačicom jedan repertoar za belo, pa pokušaj da kvačicom
   dodaš i repertoar za crno.
   Treba da vidiš: Pojavi se poruka „A single session can only ask about one
   side." i broj izabranih se ne menja.
   Potrebno: Windows i telefon; server.

3. [ ] **Kombinovana sesija pita samo iz izabranih otvaranja, ne iz cele
   boje.** [90.10]
   O čemu se radi: Kad se izabere nekoliko repertoara iste boje za kombinovani
   dril, pitanja moraju da dolaze isključivo iz njih, ne iz cele boje.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (uključi izbor kvačicama na dve ili više kartica iste boje) →
   `Drill selected …`.
   Uradi: Izaberi kvačicama dva repertoara koji pokrivaju mali deo cele boje.
   Pokreni `Drill selected …` i odgovori na desetak pitanja.
   Treba da vidiš: Nijedno pitanje ne dolazi iz repertoara koji nije bio
   označen kvačicom.
   Potrebno: Windows i telefon; server.

4. [ ] **„Another decision"/izbor grane radi i u kombinovanoj sesiji, sa imenom
   otvaranja.** [90.11]
   O čemu se radi: U kombinovanom drilu, svaka grana u listu grana nosi ime
   otvaranja iz kog dolazi.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (uključi izbor kvačicama na dve ili više kartica iste boje) →
   `Drill selected …`.
   Uradi: U kombinovanoj sesiji otvori list grana (ikonica u zaglavlju).
   Treba da vidiš: Svaki red u listu grana pokazuje i potez i ime
   repertoara/otvaranja kom pripada.
   Potrebno: Windows i telefon; server.

5. [ ] **Dva otvaranja koja počinju istim potezima ostaju dva odvojena reda pri
   izboru.** [90.12]
   O čemu se radi: Ako dva repertoara (npr. Sicilijanka i podvarijanta) dele
   prve poteze, moraju da budu dva odvojena reda na spisku za kombinovanu
   sesiju; štikliranje jednog ne sme da štiklira drugi.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (uključi izbor kvačicama na dve ili više kartica iste boje) →
   `Drill selected …`.
   Uradi: Napravi dva repertoara iste boje koji počinju istim potezima (npr.
   oba 1.e4 c5), pa ih otvori na listi za kombinovanu sesiju i štikliraj samo
   jedan.
   Treba da vidiš: Oba se prikazuju kao dva odvojena reda sa svojim imenima;
   štikliranje jednog ne menja stanje drugog.
   Potrebno: Windows i telefon; server.

6. [ ] **Rečenica o zajedničkom rasporedu je vidljiva pre bilo kakvog
   štikliranja.** [90.13]
   O čemu se radi: „A position reached by both openings is asked once." se vidi
   odmah u listu za kombinovanu sesiju, pre nego što se bilo šta štiklira, bez
   skrolovanja.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (uključi izbor kvačicama na dve ili više kartica iste boje) →
   `Drill selected …`.
   Uradi: Otvori spisak za kombinovanu sesiju (dugo pritisni „Drill" ili otvori
   list preko izbora više kartica) i pogledaj tekst pre štikliranja bilo čega.
   Treba da vidiš: Rečenica „A position reached by both openings is asked
   once." je vidljiva odmah, bez skrolovanja, i to pre bilo kakvog izbora.
   Potrebno: Windows i telefon; server.

7. [ ] **Jedan dodir na red i dalje pokreće tu granu; kvačica je samo za više
   njih.** [90.14]
   O čemu se radi: Dodir na sam red u listu grana ponaša se kao i pre (pokreće
   tu granu); kvačica pored reda služi samo za sakupljanje više grana u jednu
   sesiju.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (uključi izbor kvačicama na dve ili više kartica iste boje) →
   `Drill selected …`.
   Uradi: U listu za kombinovanu sesiju dodirni telo jednog reda (ne kvačicu).
   Treba da vidiš: Ta grana/repertoar se odmah pokreće kao pojedinačna sesija,
   isto kao pre uvođenja kombinovanog drila.
   Potrebno: Windows i telefon; server.

8. [ ] **Više štikliranih grana čine jednu sesiju koja prelazi sa jedne na
   drugu.** [90.15]
   O čemu se radi: Kad se prazni prva izabrana grana, sesija sama pređe na
   sledeću umesto da javi kraj.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (uključi izbor kvačicama na dve ili više kartica iste boje) →
   `Drill selected …`.
   Uradi: Štikliraj dve kratke grane i pokreni `Drill selected …`; isprazni
   prvu do kraja.
   Treba da vidiš: Posle poslednjeg pitanja iz prve grane, dril nastavlja
   pitanjima iz druge, bez poruke da je gotovo.
   Potrebno: Windows i telefon; server.

9. [ ] **Pozicija koju dostižu oba izabrana otvaranja se pita samo jednom po
   sesiji.** [90.16]
   O čemu se radi: Ako se ista pozicija dostiže iz oba izabrana otvaranja, u
   istoj kombinovanoj sesiji se pita samo jednom.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (uključi izbor kvačicama na dve ili više kartica iste boje) →
   `Drill selected …`.
   Uradi: Izaberi dva otvaranja koja dele zajedničku poziciju, pokreni
   kombinovanu sesiju, odgovori na tu zajedničku poziciju kad se prvi put
   pojavi.
   Treba da vidiš: Ista pozicija se ne pojavljuje ponovo u istoj sesiji.
   Potrebno: Windows i telefon; server.

10. [ ] **Govor u drilu izgovara tačno ono što piše na pitanju i presudi.**
   [92.3]
   O čemu se radi: Vlasnik je 3.9.2026 prijavio da se u drilu ne čuje ništa kad
   je govor uključen. Od tada su i tekst (sada engleski) i govor menjani, a
   uzrok (kod ili glas koji nije instaliran na uređaju) nije utvrđen — zato
   ponovna provera.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara) → (zvučnik u zaglavlju).
   Uradi: Proveri u podešavanjima govora da mašina ima aktivan glas. Uđi u
   dril, uključi zvučnik u zaglavlju, sačekaj pitanje i odigraj tačan potez.
   Treba da vidiš: Pitanje („What do you play as White/Black?" plus rečenica
   ispod) se izgovori kao jedna celina, a presuda posle tačnog odgovora se
   pročita sa notacijom izgovorenom rečima. Ako se ne čuje ništa iako mašina
   ima aktivan glas, to je bug; ako mašina nema glas, to je već pokriveno
   stavkom 92.7.
   Potrebno: Windows; server; internet.

11. [ ] **Proveriti da protivnik u drilu/sparingu ne izlazi van
   pripremljenog.** [83.1]
   O čemu se radi: Od 16.9.2026 protivnik u drilu igra samo odgovore koji su
   uneti u repertoar, pa bi poruka da protivnikov potez „nije pokriven" trebalo
   da bude retka ili nemoguća. Aplikacija i dalje ume da je prikaže, pa se
   proverava da li se ikad pojavi.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Odigraj oko dvadeset poteza kroz dril i sparing na repertoaru sa
   nekoliko unetih protivničkih odgovora po poziciji.
   Treba da vidiš: Rečenica „Opponent replied … — you have not covered this."
   se ne pojavljuje ni jednom; ako se pojavi, to je nalaz vredan prijave.
   Potrebno: Windows i telefon; server.

12. [ ] **Protivnik i dalje ne igra uvek isti odgovor na istu granu.** [83.2]
   O čemu se radi: Protivnik bira ponderisano brojem partija među unetim
   odgovorima; ista grana puštena dvaput treba negde da se razminu njeni
   protivnikovi potezi.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Pusti istu granu (sparing) dvaput zaredom i uporedi nizove
   protivnikovih poteza.
   Treba da vidiš: Bar na jednoj poziciji se protivnikov potez razlikuje između
   dva puštanja iste grane.
   Potrebno: Windows i telefon; server.

13. [ ] **Kraj pripreme zaustavlja i dril i sparing bez daljeg protivnikovog
   poteza.** [83.3]
   O čemu se radi: Na poziciji gde nijedan protivnikov odgovor nije unet, dril
   ne nudi nastavak, a sparing javlja da je grana odigrana do kraja.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Dovedi red (ili sparing) do pozicije gde je protivnik na potezu, a
   nijedan njegov odgovor nije unet u repertoar.
   Treba da vidiš: U šetnji nema dugmeta `Continue line`; u sparingu se ispiše
   „Branch played to the end." (ili „Branch goes this far — no further move of
   yours.").
   Potrebno: Windows i telefon; server.

14. [ ] **„Build this position" i dalje postoji za nepokrivenu sopstvenu
   poziciju.** [83.4]
   O čemu se radi: Ovo su jedina preostala vrata ka izgradnji iz drila: na
   pokrivenoj poziciji gde korisnik još nije izabrao potez, ekran nudi
   izgradnju baš tu.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Dovedi red do pozicije koja je pokrivena (protivnik je odgovorio),
   ali u njoj korisnik još nije izabrao svoj potez.
   Treba da vidiš: Piše „You have not covered this position" (ili slično) i
   ponuđeno je dugme `Build this position` koje vodi u gradnju baš te pozicije.
   Potrebno: Windows i telefon; server.

15. [ ] **„Another decision" dugme stoji samo na pravoj račvi.** [82.1]
   O čemu se radi: Dugme za izbor druge odluke se pojavljuje samo kad pozicija
   ima dva ili više zadržanih poteza; na poziciji sa jednim zadržanim potezom
   ga nema.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Nađi poziciju sa jednim zadržanim potezom i poziciju sa dva, u istoj
   šetnji.
   Treba da vidiš: Dugme „Another decision" je vidljivo samo na poziciji sa dva
   (ili više) zadržana poteza.
   Potrebno: Windows i telefon; server.

16. [ ] **Drugi potez se ne imenuje pre pritiska na dugme.** [82.2]
   O čemu se radi: Pre nego što se pritisne „Another decision", nigde na ekranu
   ne piše koji je drugi zadržani potez.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Na poziciji sa dva zadržana poteza, pre pritiska na dugme, pregledaj
   ceo ekran.
   Treba da vidiš: Nigde ne piše ime drugog poteza — samo se zna da postoji
   „druga odluka".
   Potrebno: Windows i telefon; server.

17. [ ] **List „Another decision" nudi red za svaki drugi potez.** [82.3]
   O čemu se radi: List koji se otvori nudi naslov „Another decision in this
   position" i po jedan red „Drill <potez>" za svaki drugi zadržani potez.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Pritisni „Another decision" na račvi.
   Treba da vidiš: Otvori se list sa naslovom „Another decision in this
   position" i redom (redovima) „Drill <SAN poteza>".
   Potrebno: Windows i telefon; server.

18. [ ] **Izbor druge odluke menja liniju i piše to iznad table.** [82.4]
   O čemu se radi: Posle izbora u listu, vežbanje ide kroz izabrani potez, a
   iznad table stoji rečenica koja to imenuje.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: U listu „Another decision" izaberi jedan od ponuđenih poteza.
   Treba da vidiš: Iznad table (u panelu „Rehearse line") piše „This line goes
   through <potez> — play it."
   Potrebno: Windows i telefon; server.

19. [ ] **„Back to queue" vraća raspored i uklanja rečenicu o izabranom putu.**
   [82.5]
   O čemu se radi: Dugme „Back to queue" briše izabranu granu i vraća
   uobičajeni raspored, uklanjajući rečenicu „This line goes through …".
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Posle izbora druge odluke pritisni `Back to queue`.
   Treba da vidiš: Rečenica o izabranom putu nestaje, a sledeća pitanja dolaze
   iz redovnog rasporeda kao pre izbora.
   Potrebno: Windows i telefon; server.

20. [ ] **Rad na izabranom putu ne upisuje se u raspored.** [82.6]
   O čemu se radi: Dok je izabrana grana/odluka aktivna, odgovaranje na pitanja
   ne sme da pomeri brojeve dospelog rasporeda.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Zapamti brojeve rasporeda, izaberi „Another decision", odgovori na
   par pitanja na tom putu.
   Treba da vidiš: Brojevi rasporeda ostaju isti kao pre — rad na izabranom
   putu se ne upisuje.
   Potrebno: Windows i telefon; server.

21. [ ] **„Another line" daje stvarno drugu liniju svaki put.** [82.7]
   O čemu se radi: Pritisak na dugme za drugu liniju mora da vrati različitu
   liniju/pitanje pri uzastopnim pritiscima, ne uvek istu.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Pritisni `Another line` dva-tri puta zaredom i uporedi šta se ponudi
   svaki put.
   Treba da vidiš: Pitanja se razlikuju između pritisaka — ako je uvek isto, to
   je nalaz (stara greška).
   Potrebno: Windows i telefon; server.

22. [ ] **`Skip` ponaša se isto kao „Another line" — pozicija se ne vraća
   odmah.** [82.8]
   O čemu se radi: Preskakanje pitanja stavlja ga na kraj reda umesto da ga
   odmah vrati; oba dugmeta dele isti mehanizam.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Pritisni `Skip` na trenutnom pitanju i posmatraj da li se ono odmah
   vraća.
   Treba da vidiš: Pitanje se ne pojavljuje odmah ponovo — ide na kraj reda kao
   i „Another line".
   Potrebno: Windows i telefon; server.

23. [ ] **Kad se sve preskoči, red počinje ispočetka umesto poruke „ništa nije
   na redu"** [82.9]
   O čemu se radi: Ako se sva pitanja jedno za drugim preskoče, ekran ne sme da
   kaže da nema ničeg na redu — pitanja kreću ponovo od početka.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: U kratkom repertoaru/grani preskoči redom baš sva pitanja koja se
   ponude.
   Treba da vidiš: Posle poslednjeg preskoka se pojavi prvo pitanje ponovo
   (krug ispočetka), a ne poruka da ničeg nema.
   Potrebno: Windows i telefon; server.

24. [ ] **Izbor grane ili sparing brišu izabrani put iz „Another decision"**
   [82.10]
   O čemu se radi: Kad se posle izbora „Another decision" otvori list grana i
   uzme druga grana (ili pokrene sparing), rečenica o izabranom putu nestaje.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Izaberi „Another decision" pa neki potez; zatim otvori list grana
   (ikonica u zaglavlju) i izaberi drugu granu.
   Treba da vidiš: Rečenica „This line goes through …" više ne stoji iznad
   table.
   Potrebno: Windows i telefon; server.

25. [ ] **Na samoj račvi piše koju granu treba odigrati kad je izabrana.**
   [82.12]
   O čemu se radi: Posle izbora „Drill <potez>", na poziciji gde je račva ekran
   eksplicitno kaže koji potez treba odigrati, umesto da obe grane izgledaju
   isto.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Izaberi „Drill d4" (ili sličan potez) u listu „Another decision", pa
   dođi ponovo do same račve.
   Treba da vidiš: Iznad table piše „This line goes through d4 — play it." (ili
   odgovarajući potez).
   Potrebno: Windows i telefon; server.

26. [ ] **Rečenica o alternativi i rečenica o izabranom putu se ne prikazuju
   zajedno.** [82.13]
   O čemu se radi: Kad je put već izabran preko „Another decision", stara
   rečenica o alternativi („In this position you have multiple moves…") se gasi
   — stoji samo rečenica o izabranom putu.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Izaberi „Another decision" na račvi i pogledaj tekst iznad table.
   Treba da vidiš: Vidljiva je samo jedna od dve rečenice (o izabranom putu),
   ne obe odjednom.
   Potrebno: Windows i telefon; server.

27. [ ] **Put bez ičeg iza sebe to jasno kaže, ne „Ništa nije na redu"**
   [82.14]
   O čemu se radi: Ako se izabere potez iza kog nema izgrađene linije, ekran
   mora jasno da kaže da tu nema šta dalje da se vežba (uz „Back to queue"),
   umesto opšte poruke da ničeg nema na redu.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: U listu „Another decision" izaberi potez za koji iza njega ništa nije
   izgrađeno.
   Treba da vidiš: Ekran kaže nešto poput „Nothing due behind <potez>." (ili
   slično, imenujući baš taj potez), sa dugmetom `Back to queue` — ne opštu
   poruku bez imena poteza.
   Potrebno: Windows i telefon; server.

28. [ ] **Red „This line goes through …" i list odluka se ne seku na
   telefonu.** [82.11]
   O čemu se radi: Red sa rečenicom o izabranom putu i dugmetom
   `Back to queue`, kao i list „Another decision", moraju da stanu na 360 dp u
   release build-u.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Na telefonu (360 dp, release build) izaberi „Another decision" i
   pogledaj i list i red sa rečenicom o putu.
   Treba da vidiš: Ni list ni red sa rečenicom i dugmetom `Back to queue` se ne
   seku niti izlaze van ekrana.
   Potrebno: telefon; server; release build; telefon položeno.

29. [ ] **Linija kroz alternativu se najavi bez imenovanja poteza.** [81.1]
   O čemu se radi: Kad je red na poziciji gde korisnik ima dva zadržana poteza,
   a raspored vodi kroz alternativu (ne glavni), ekran to kaže rečenicom, bez
   da imenuje traženi potez.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Nađi poziciju sa dva sopstvena zadržana poteza i sačekaj (ili dovedi
   red preko sparinga van rasporeda) da raspored ponudi liniju kroz
   alternativu.
   Treba da vidiš: Iznad table piše „In this position you have multiple moves —
   this line goes through the alternative, not the main move." — bez imena
   poteza.
   Potrebno: Windows i telefon; server.

30. [ ] **Linija kroz glavni potez ne najavljuje ništa posebno.** [81.2]
   O čemu se radi: Ista provera na poziciji gde linija ide kroz glavni (★)
   potez: rečenica o alternativi se ne pojavljuje.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Na istoj vrsti pozicije, kad red vodi kroz glavni potez, proveri
   tekst iznad table.
   Treba da vidiš: Rečenice o alternativi nema; stoji samo obično pitanje.
   Potrebno: Windows i telefon; server.

31. [ ] **Sopstveni drugi potez se ne računa kao greška.** [81.3]
   O čemu se radi: Kad je red na alternativi, a korisnik odigra svoj DRUGI
   zadržani potez (i on je legalan izbor u repertoaru), ekran to kaže plavom
   bojom, ne kao grešku.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Na poziciji gde raspored traži alternativu, odigraj glavni (drugi)
   sopstveni potez umesto tražene alternative.
   Treba da vidiš: Piše rečenica oblika „<potez> is also your move — but this
   line drills <traženi potez>." u plavoj (info) boji, ne u
   narandžastoj/crvenoj boji greške.
   Potrebno: Windows i telefon; server.

32. [ ] **Tuđi potez ostaje pogrešan, bez ocenjivanja ponavljanja.** [81.4]
   O čemu se radi: Kad korisnik odigra bilo koji potez koji nije njegov (ni
   glavni ni alternativa), i dalje se ocenjuje kao netačno.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Odigraj potez koji nije nijedan od zadržanih poteza za tu poziciju.
   Treba da vidiš: Ekran ga označi kao netačan (crveno/narandžasto), sa
   napomenom da se ponavljanje ne broji u rejting.
   Potrebno: Windows i telefon; server.

33. [ ] **Ispravka: tačan potez se prvo prikaže sam, pa tek onda odgovori
   protivnik.** [81.5]
   O čemu se radi: Kad se prikazuje tačan potez posle greške, prvo se na tabli
   vidi taj potez sam (obeležen), a tek posle toga stiže protivnikov odgovor —
   ne oba u istom kadru.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Namerno odigraj pogrešan potez, pa pritisni dugme koje prikazuje
   tačan potez.
   Treba da vidiš: Prvo se na tabli vidi samo tačan potez (sa
   strelicom/markerom), a protivnikov odgovor stiže tek posle toga, ne u istom
   trenutku.
   Potrebno: Windows i telefon; server.

34. [ ] **Tačan odgovor u šetnji vodi dalje sam, bez klika.** [81.6]
   O čemu se radi: Kad je odgovor tačan, sledeća pozicija se otvara automatski
   posle kratke pauze u kojoj se čita presuda, bez potrebe za dodirom.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Odigraj tačan potez i sačekaj bez dodira na ekran.
   Treba da vidiš: Posle kratke pauze se pređe na sledeće pitanje, bez ikakvog
   dodira.
   Potrebno: Windows i telefon; server.

35. [ ] **Presuda iznad sledećeg pitanja pominje protivnikov odgovor i
   raspored.** [81.7]
   O čemu se radi: Nad sledećim pitanjem stoji kratka presuda o prethodnom
   potezu, protivnikovom odgovoru i kad se pozicija vraća.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Odigraj tačan potez i pogledaj tekst iznad sledećeg pitanja.
   Treba da vidiš: Piše nešto poput „Correct — Nc6." i „Opponent replied Nf3."
   i „Next returns in N days." — sve tri informacije prisutne.
   Potrebno: Windows i telefon; server.

36. [ ] **Greška u šetnji zaustavlja i tek tad se pojavljuje „Continue line"**
   [81.8]
   O čemu se radi: Kad je odgovor pogrešan, šetnja stane; dugme za nastavak
   linije se pojavljuje tek posle greške, ne pre.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Odigraj pogrešan potez u šetnji.
   Treba da vidiš: Šetnja stane na toj poziciji i pojavi se dugme
   `Continue line` (koga do tada nije bilo).
   Potrebno: Windows i telefon; server.

37. [ ] **Nepokriven protivnikov odgovor takođe zaustavlja šetnju.** [81.9]
   O čemu se radi: Ako protivnik (u knjizi ili unetim odgovorima) odgovori
   potezom koji korisnik nije pokrio dalje, šetnja stane i ponudi izgradnju te
   pozicije.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Nađi ili napravi poziciju gde je tvoj potez tačan, ali protivnikov
   odgovor posle njega nema tvoj dalji potez pripremljen.
   Treba da vidiš: Šetnja stane sa porukom da ta pozicija nije pokrivena i
   ponudi izgradnju („Build this position" ili slično), umesto da nastavi sama.
   Potrebno: Windows i telefon; server.

38. [ ] **Kraj knjige ne nudi „Continue line"** [81.10]
   O čemu se radi: Kad protivnik nema nijedan odgovor (kraj pripreme), dugme za
   nastavak linije se ne pojavljuje — ranije je to vodilo u pitanje u poziciji
   gde korisnik nije na potezu.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Dovedi red do pozicije gde je protivnikova strana na potezu i nema
   ničeg dalje pripremljenog za nju.
   Treba da vidiš: Šetnja se završi bez dugmeta za nastavak linije — ne otvara
   se pitanje u poziciji gde nije korisnikov red.
   Potrebno: Windows i telefon; server.

39. [ ] **Prolaz kroz nedospele pozicije ne pomera raspored, sem prvog puta.**
   [81.11]
   O čemu se radi: Šetnja kroz pozicije koje nisu bile due ne sme da pomeri
   postojeći raspored, ali pozicija koja nikad nije ponavljana treba da se
   upiše prvi put.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Zapamti brojeve rasporeda, prošetaj kroz par pozicija koje nisu bile
   due, pa ih ponovo proveri.
   Treba da vidiš: Brojevi rasporeda ostaju isti za već ponavljane pozicije;
   pozicija koja nikad nije ponavljana sada ima upisan datum sledećeg
   ponavljanja.
   Potrebno: Windows i telefon; server.

40. [ ] **Red sa presudom se ne seče na telefonu.** [81.12]
   O čemu se radi: Rečenica sa presudom („Correct — … Opponent replied … Next
   returns in …") je najduži tekst na ekranu drila i mora da stane na 360 dp u
   release build-u.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Na telefonu (360 dp, release build) odigraj tačan potez i pogledaj
   presudu iznad sledećeg pitanja.
   Treba da vidiš: Cela rečenica se vidi (prelama se u više redova ako treba),
   bez sečenja teksta.
   Potrebno: telefon; server; release build; telefon položeno.

41. [ ] **Ikonica grane u zaglavlju drila otvara spisak grana.** [80.1]
   O čemu se radi: Zaglavlje drila ima ikonicu koja otvara listu sa „Entire
   repertoire" i svakom granom posebno, sa brojem pitanja koja su na redu.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Otvori `Drill` na repertoaru sa bar dve grane. Pritisni ikonicu grane
   u zaglavlju.
   Treba da vidiš: Otvori se list: prvi red „Entire repertoire", pa svaka grana
   sa tekstom „due N of M" (i „knows N" gde ima naučenih).
   Potrebno: Windows i telefon; server.

42. [ ] **Izbor grane sužava dril na tu granu.** [80.2]
   O čemu se radi: Kad se u listu izabere jedna grana (dodirom na red, ne
   kvačicom), pitanja u drilu dolaze samo iz nje dok se ne izabere „Entire
   repertoire".
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: U listu grana dodirni jednu granu (ne kvačicu). Odgovori na par
   pitanja, pa se vrati u list i izaberi „Entire repertoire".
   Treba da vidiš: Dok je grana izabrana, pitanja dolaze samo iz nje; posle
   „Entire repertoire" se vraćaju pitanja iz celog repertoara.
   Potrebno: Windows i telefon; server.

43. [ ] **Ikonica ▶ na grani pokreće „sparing"** [80.3]
   O čemu se radi: Svaki red grane u listi ima ikonicu ▶ („Play branch to the
   end") koja pušta granu unapred, bez čekanja na raspored.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: U listu grana pritisni ▶ ikonicu pored jedne grane.
   Treba da vidiš: Tabla ode na početak te grane i iznad linije piše „Sparring:
   <grana> · played N".
   Potrebno: Windows i telefon; server.

44. [ ] **Protivnik u sparingu ne igra uvek isto.** [80.4]
   O čemu se radi: Protivnik u sparingu bira među unetim odgovorima ponderisano
   brojem partija, pa ista grana puštena dvaput ne mora da ide identično.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Pusti sparing na istoj grani dva puta zaredom (izađi i vrati se) i
   uporedi poteze protivnika.
   Treba da vidiš: Bar na jednom mestu se niz protivnikovih poteza razlikuje
   između dva puštanja — ako je oba puta identičan, to je nalaz.
   Potrebno: Windows i telefon; server.

45. [ ] **Tačan potez u sparingu vodi dalje sam od sebe.** [80.5]
   O čemu se radi: Posle tačnog odgovora u sparingu, protivnikov sledeći potez
   se odigra automatski posle kratke pauze, bez dodira.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: U sparingu odigraj tačan potez i sačekaj, bez ikakvog dodira na
   ekran.
   Treba da vidiš: Protivnikov odgovor se prikaže na tabli, i posle njega se
   samo od sebe otvori sledeće pitanje.
   Potrebno: Windows i telefon; server.

46. [ ] **Greška u sparingu zaustavlja trku na toj poziciji.** [80.6]
   O čemu se radi: Pogrešan potez u sparingu zaustavlja automatski tok; ekran
   nudi da pokaže tačan potez i da nastavi liniju.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: U sparingu namerno odigraj pogrešan potez.
   Treba da vidiš: Sparing stane na toj poziciji i ponudi dugmad za prikaz
   tačnog poteza i za nastavak linije.
   Potrebno: Windows i telefon; server.

47. [ ] **Kraj grane u sparingu javlja rezultat i nudi izbor dalje.** [80.7]
   O čemu se radi: Kad se grana odigra do kraja, ekran ispisuje koliko je
   odigrano i koliko je grešaka bilo, i nudi drugu granu ili povratak na
   raspored.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Pusti sparing kroz kratku granu do samog kraja (bez ijedne ili sa par
   grešaka).
   Treba da vidiš: Piše rečenica oblika „Branch played to the end." sa brojem
   odigranih poteza i grešaka, i dugmad za drugu granu ili povratak na
   `Back to queue`.
   Potrebno: Windows i telefon; server.

48. [ ] **Sparing van rasporeda ne pomera brojeve dospelog.** [80.8]
   O čemu se radi: Sparing kroz granu u kojoj ništa nije bilo due ne sme da
   promeni brojeve rasporeda (rating se ne upisuje van reda).
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Zapamti brojeve „due N of M" na grani u kojoj ništa trenutno nije
   due, pusti sparing kroz nju, pa ponovo otvori list grana.
   Treba da vidiš: Brojevi „due" i „positions" na toj grani su isti kao pre
   sparinga.
   Potrebno: Windows i telefon; server.

49. [ ] **List sa granama i sparing se ne seku na telefonu.** [80.9]
   O čemu se radi: List grana i red „Sparring: …" u zaglavlju drila moraju da
   stanu na 360 dp u release build-u.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   `Drill` (ikonica na kartici repertoara).
   Uradi: Na telefonu (360 dp, release build) otvori list grana i pokreni
   sparing na jednoj od njih.
   Treba da vidiš: Ni list grana ni red „Sparring: …" se ne seku niti izlaze
   van ekrana.
   Potrebno: telefon; server; release build; telefon položeno.

50. [ ] **Dijalog izdvajanja, traka izbora i zaglavlje lista grana se ne seku
   na telefonu.** [90.17]
   O čemu se radi: Tri mesta su ranije bila preširoka na 360 dp: dugmad u
   dijalogu izdvajanja, traka „Cancel / Drill selected (N)" u listu za
   kombinovanu sesiju, i zaglavlje lista za izbor grane.
   Gde: `Practise` → (kartica „Opening repertoire") → `Open repertoire` →
   (izbor više kartica kvačicom, za trak izbora) i (dodir na karticu → traka
   ispod table → `Extract into new opening`, za dijalog izdvajanja).
   Uradi: Na telefonu (360 dp, release build) otvori dijalog „Fork into new
   opening", zatim izbor za kombinovanu sesiju sa trakom „Drill selected (N)",
   i list za izbor grane.
   Treba da vidiš: Dugmad u sva tri mesta stanu na ekran bez sečenja i bez
   izlaska ispod donje ivice ekrana.
   Potrebno: telefon; server; release build; telefon položeno.

51. [ ] **Bez dovoljno građenih pozicija, dril nema šta da pita.** [30.b877]
   O čemu se radi: Dril nema šta da pita kad repertoar ima premalo izgrađenih
   pozicija; ekran o tome ima svoj tačan tekst.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` → red repertoara →
   `Drill`.
   Uradi: Pokrenuti dril na repertoaru bez (ili sa vrlo malo) izgrađenih
   pozicija.
   Treba da vidiš: Ekran kaže `Nothing to drill yet.` uz uputstvo da se prvo
   izgradi nekoliko pozicija.
   Potrebno: Windows i telefon.

52. [ ] **Pitanje dolazi bez odgovora.** [30.b880]
   O čemu se radi: Dril pita bez otkrivanja odgovora — dugme `Show` je jedini
   način da se pre poteza sazna koji je potez tačan.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` → red repertoara →
   `Drill`.
   Uradi: Pokrenuti dril na repertoaru sa nekoliko izgrađenih pozicija i
   pogledati ekran pre poteza.
   Treba da vidiš: Nigde na ekranu ne piše koji je potez tačan dok se ne odigra
   ili ne pritisne `Show`.
   Potrebno: Windows i telefon.

53. [ ] **Tačan potez: „Correct" i rečenica o vraćanju.** [30.b882]
   O čemu se radi: Tačan potez u drilu javlja verdikt i rečenicu o vraćanju
   pozicije na ponavljanje.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` → red repertoara →
   `Drill`.
   Uradi: Odigrati tačan potez u drilu.
   Treba da vidiš: Ekran pokaže `Correct — …` (odigrani potez) i rečenicu o
   tome kad se pozicija vraća na ponavljanje.
   Potrebno: Windows i telefon.

54. [ ] **Sopstvena alternativa: „Also yours", uz ime glavnog poteza.**
   [30.b883]
   O čemu se radi: Odgovor koji je sopstvena, nemarkirana alternativa iz
   repertoara se broji kao tačan, uz naznaku koji je potez glavni.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` → red repertoara →
   `Drill`.
   Uradi: U drilu odigrati alternativu koju ste sami ranije uzeli (nije
   glavni/zvezdica potez).
   Treba da vidiš: Ekran pokaže `Also yours — …` (odigrani potez) i imenuje
   glavni potez.
   Potrebno: Windows i telefon.

55. [ ] **Dobar potez koji nije vaš: „Incorrect", uz vaš potez.** [30.b884]
   O čemu se radi: Namerno: dril sudi po tome šta ste odlučili da igrate, ne po
   opštoj kvaliteti poteza — čak i savršeno zdrav potez koji niste uzeli broji
   se kao netačan.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` → red repertoara →
   `Drill`.
   Uradi: U drilu odigrati potpuno zdrav potez koji NIJE u vašem repertoaru.
   Treba da vidiš: Ekran pokaže `Incorrect — …` (odigrani potez) i imenuje vaš
   pravi (uneti) potez.
   Potrebno: Windows i telefon.

56. [ ] **„Show" pa tačan potez i dalje prolazi, ali se vraća ranije.**
   [30.b886]
   O čemu se radi: Pogađanje potez posle `Show` i pogađanje iz glave oba
   prolaze, ali sa različitim rokom vraćanja na ponavljanje (niža ocena za
   otkriveno rešenje).
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` → red repertoara →
   `Drill`.
   Uradi: U drilu pritisnuti `Show`, pa zatim ipak odigrati tačan potez;
   uporediti sa slučajem kad se potez pogodi bez `Show`.
   Treba da vidiš: Oba slučaja prolaze kao tačno, ali pozicija posle `Show` se
   vraća na ponavljanje ranije (za manje dana) nego kad se pogodi iz glave.
   Potrebno: Windows i telefon.

57. [ ] **Nepokriven protivnički odgovor je označen žutom bojom.** [30.b888]
   O čemu se radi: Protivnik u drilu ponekad sam odigra potez van izgrađenog
   repertoara; taj slučaj je posebno obojen.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` → red repertoara →
   `Drill`.
   Uradi: U drilu pustiti da protivnik nekoliko puta sam odgovori, dok se ne
   desi da odigra potez van izgrađenog repertoara.
   Treba da vidiš: Takav odgovor je označen upozoravajućom (žutom) bojom, uz
   tekst „Opponent replied … — you have not covered this."
   Potrebno: Windows i telefon.

58. [ ] **„Continue line" nastavlja odakle je stalo.** [30.b890]
   O čemu se radi: Posle netačnog odgovora koji zaustavi liniju, dugme
   `Continue line` nastavlja odakle je stalo.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` → red repertoara →
   `Drill`.
   Uradi: Posle netačnog odgovora koji zaustavi liniju, pritisnuti
   `Continue line`.
   Treba da vidiš: Nastavlja se tačno od pozicije u kojoj se stalo, ne od
   početka.
   Potrebno: Windows i telefon.

59. [ ] **Neizgrađena pozicija nudi „Build this position" tačno tu.** [30.b891]
   O čemu se radi: Kad dril dođe do pozicije koja nije izgrađena, nudi dugme
   koje otvara gradnju baš na toj poziciji.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` → red repertoara →
   `Drill`.
   Uradi: U drilu doći do pozicije koja nije izgrađena.
   Treba da vidiš: Piše `You have not covered this position` i dugme
   `Build this position` otvara gradnju baš na toj poziciji, ne od početka
   repertoara.
   Potrebno: Windows i telefon.

60. [ ] **Brojač „due/fresh" se menja u zaglavlju.** [30.b893]
   O čemu se radi: Broj dospelih i novih pozicija u zaglavlju drila se osvežava
   posle svakog odgovora.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` → red repertoara →
   `Drill`.
   Uradi: Odgovoriti na nekoliko pitanja u drilu i pratiti zaglavlje ekrana
   pored naslova `Drill — …`.
   Treba da vidiš: Pored naslova `Drill — …` stoji brojač oblika „due: N ·
   fresh: M" koji se menja posle svakog odgovora.
   Potrebno: Windows i telefon.

61. [ ] **Dril radi bez interneta, ali ne bez backenda.** [30.b894]
   O čemu se radi: Ocenjivanje u drilu ide isključivo preko sopstvenog backenda
   (bez ijednog Lichess poziva), pa radi bez interneta i otkazuje samo kad
   backend nije dostupan.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` → red repertoara →
   `Drill`.
   Uradi: Isključiti internet (ali ostaviti backend upaljen na lokalnoj mreži)
   i nastaviti dril; zatim ugasiti i sam backend.
   Treba da vidiš: Pitanja i ocene rade dok je backend dostupan; dril otkaže
   tek kad backend nije dostupan.
   Potrebno: Windows i telefon; server.

62. [ ] **Na 360 dp telefonu tabla, poruka i dugmad staju bez sečenja.**
   [30.b896]
   O čemu se radi: Na uskom telefonu red dugmadi u drilu koristi `Wrap` da bi
   stao bez sečenja.
   Gde: `Practise` → (faza „Opening") → `Opening repertoire` → red repertoara →
   `Drill`.
   Uradi: Na telefonu (360 dp) otvoriti dril i pogledati tablu, poruku i red
   dugmadi.
   Treba da vidiš: Ništa nije odsečeno niti izlazi van ekrana.
   Potrebno: telefon.

63. [ ] **Poruke u drilu repertoara su engleske i koriste reč „drill”** [132.7]
   O čemu se radi: Poruke oko vežbanja repertoara do greške su na engleskom i
   dosledno koriste reč „drill”, ne „practice”.
   Gde: `Practise` → (kartica) `Opening repertoire` → `Open repertoire` → (red
   repertoara) → ikonica `Drill`.
   Uradi: Vežbaj (`Drill`) liniju do greške — odigraj potez koji nije u
   repertoaru.
   Treba da vidiš: Poruke o toku i rezultatu drila su na engleskom i koriste
   reč „drill” (npr. u sažetku „Today you drilled …”), ne „practice”.
   Potrebno: Windows.

64. [ ] **Prazan drill kaže kada se vraća.** [67.1]
   O čemu se radi: Kad je sve u grani već uvežbano i ništa nije dospelo, ekran
   drila kaže da ništa nije na redu i koliko se pozicija zna, ne samo da nema
   ničega.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (red) → `Drill`
   → `Choose branch` → (grana koja je sva već uvežbana).
   Uradi: Uzeti granu u kojoj je sve već uvežbano i sačekati da drill dođe do
   kraja.
   Treba da vidiš: Ekran kaže da ništa trenutno nije na redu i pokazuje koliko
   se pozicija zna od ukupnog broja u grani, ne prazan ekran bez objašnjenja.
   Potrebno: Windows i telefon; server; sve pozicije grane već uvežbane.

65. [ ] **„Drill anyway" postoji i radi.** [67.2]
   O čemu se radi: Kad ima šta da se vežba, ali ništa nije dospelo po
   rasporedu, dugme `Drill anyway` otvara pitanje van rasporeda.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (red) → `Drill`
   → (ništa trenutno dospelo).
   Uradi: Otvoriti drill u trenutku kad ništa nije dospelo, pritisnuti
   `Drill anyway`.
   Treba da vidiš: Otvara se pitanje; iznad njega piše da je drill van
   rasporeda.
   Potrebno: Windows i telefon; server; izgrađena grana, ništa trenutno
   dospelo.

66. [ ] **Drill van rasporeda ne pomera rok.** [67.3]
   O čemu se radi: Tačan odgovor u drilu van rasporeda ne pomera SM-2 rok
   pozicije — ista pozicija ostaje dospela kad zaista dođe na red.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (red) → `Drill`
   → `Drill anyway`.
   Uradi: Odgovoriti tačno na pitanje otvoreno preko `Drill anyway`, pa se
   vratiti na ekran drila.
   Treba da vidiš: Ista pozicija i dalje broji se kao nedospela po rasporedu
   (poruka o rokovima se ne menja zbog ovog odgovora).
   Potrebno: Windows i telefon; server.

67. [ ] **Prazna grana nema dugme „Drill anyway"** [67.4]
   O čemu se radi: U grani u kojoj nikad ništa nije izgrađeno, dugme
   `Drill anyway` se ne nudi.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (red) → `Drill`
   → `Choose branch` → (prazna grana).
   Uradi: Otvoriti drill nad granom u kojoj nikad ništa nije izgrađeno.
   Treba da vidiš: Ekran ne nudi dugme `Drill anyway`.
   Potrebno: Windows i telefon; server.

68. [ ] **Ponavljanje linije pre pitanja.** [65.1]
   O čemu se radi: Drill repertoara pre pravog pitanja ponekad prvo ponovi
   liniju koja vodi do njega, sa oznakom koliko poteza od dospele pozicije
   preostaje.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (red) →
   `Drill`.
   Uradi: Otvoriti drill nad repertoarom koji ima liniju od bar tri-četiri
   poteza pre dospele pozicije za ponavljanje.
   Treba da vidiš: Umesto gole table, ekran najpre traži ponavljanje linije, sa
   numerisanom linijom iznad table i oznakom koliko poteza ostaje do pitanja.
   Potrebno: Windows i telefon; server; izgrađena linija od bar tri-četiri
   poteza.

69. [ ] **Protivnik odgovara sam tokom ponavljanja.** [65.2]
   O čemu se radi: Tokom ponavljanja linije, posle poteza korisnika,
   protivnikov odgovor se odigra automatski, bez posebnog pitanja.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (red) → `Drill`
   → (ponavljanje linije).
   Uradi: U toku ponavljanja odigrati svoj potez i posmatrati tablu.
   Treba da vidiš: Protivnikov odgovor se odigra sam, bez pitanja, i linija
   iznad table poraste za oba poteza.
   Potrebno: Windows i telefon; server.

70. [ ] **Pogrešan potez u ponavljanju se ne ocenjuje.** [65.3]
   O čemu se radi: Ponavljanje linije nije ocenjeno — pogrešan potez tokom
   njega vraća pravi potez na tablu i kaže da se ponavljanje ne ocenjuje.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (red) → `Drill`
   → (ponavljanje linije).
   Uradi: U toku ponavljanja namerno odigrati potez koji nije potez linije.
   Treba da vidiš: Pojavljuje se tekst da „Rehearsal is not graded", potez
   linije se odigra na tabli, i ne pojavljuje se nikakva ocena poput
   „Correct"/„Not quite".
   Potrebno: Windows i telefon; server.

71. [ ] **Pravo pitanje je tek na kraju poznate linije.** [65.4]
   O čemu se radi: Kad se prefiks koji se samo ponavlja potroši, ekran
   postavlja pravo pitanje i tek se taj potez ocenjuje.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (red) → `Drill`
   → (sačekati kraj ponavljanja).
   Uradi: Proći kroz ponavljanje linije do kraja i odigrati potez na tom mestu.
   Treba da vidiš: Tek na poslednjem potezu prefiksa se pojavljuje ocena
   (Correct/Not quite), ne ranije.
   Potrebno: Windows i telefon; server.

72. [ ] **Ponavljanje kreće od poslednje poznate pozicije.** [65.5]
   O čemu se radi: Ako je jedna pozicija uvežbana do tri tačna ponavljanja,
   drill linije koja ide ispod nje kreće od te pozicije, sa rečenicom da
   počinje „from where you know by heart".
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (red) →
   `Drill`.
   Uradi: Uvežbati jednu poziciju do tri tačna odgovora (vraćajući se drilu
   nekoliko puta), pa uzeti liniju koja ide ispod nje u drilu.
   Treba da vidiš: Ponavljanje počinje od pozicije koja je već dobro poznata,
   uz rečenicu „Starting from where you know by heart — move … of …", ne od
   korena repertoara.
   Potrebno: Windows i telefon; server; pozicija ponovljena do tri tačna
   odgovora.

73. [ ] **„Skip rehearsal" preskače pravo na pitanje.** [65.6]
   O čemu se radi: Dugme `Skip rehearsal` vodi direktno na pravo pitanje, uz
   liniju iznad table koja i dalje pokazuje ceo put.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (red) → `Drill`
   → (ponavljanje linije) → `Skip rehearsal`.
   Uradi: U toku ponavljanja pritisnuti `Skip rehearsal`.
   Treba da vidiš: Ekran odmah prelazi na pravo pitanje; linija iznad table i
   dalje prikazuje ceo put do te pozicije.
   Potrebno: Windows i telefon; server.

74. [ ] **Prazna grana kaže da nema šta da se vežba.** [65.8]
   O čemu se radi: Ako se izabere drill za granu u kojoj još ništa nije
   izgrađeno (ili u kojoj nema sopstvenih poteza), ekran to i kaže umesto da
   izgleda kao da je sve naučeno.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (red) → `Drill`
   → `Choose branch` → (izabrati praznu granu).
   Uradi: Otvoriti drill, preko `Choose branch` izabrati granu u kojoj još
   ništa nije izgrađeno.
   Treba da vidiš: Pojavljuje se rečenica da ta grana nije pripremljena ili da
   u njoj nema sopstvenih poteza (npr. „Not preparing this branch or no moves
   of yours in it yet."), ne prazan/uspešan ekran.
   Potrebno: Windows i telefon; server.

75. [ ] **Ugašen server u drilu ne izgleda kao „sve naučeno"** [65.10]
   O čemu se radi: Otvaranje drila dok je backend ugašen treba da da vidljivu
   grešku, ne tih ekran koji izgleda kao da je sve gotovo/naučeno.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (red) → `Drill`
   — pa ugasiti backend i ponovo otvoriti.
   Uradi: Ugasiti backend server, pa otvoriti ili osvežiti drill repertoara.
   Treba da vidiš: Pojavljuje se poruka o grešci ili staro pitanje sa napomenom
   da nema veze sa serverom — nikako ekran koji izgleda kao da nema šta više da
   se vežba.
   Potrebno: Windows i telefon; server (pa ugašen).

76. [ ] **Telefon: linija iznad table u drilu se ne seče.** [65.11]
   O čemu se radi: Linija iznad table tokom ponavljanja može biti duga; na
   uskom ekranu (360 dp) u release build-u ne sme da izlazi van ekrana (debug
   build crta žuto-crne pruge upozorenja koje release ne crta).
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (red) →
   `Drill`.
   Uradi: Otvoriti drill na telefonu (360 dp, release build) nad linijom od bar
   pet-šest poteza.
   Treba da vidiš: Linija iznad table se ne seče niti prelazi ivicu ekrana.
   Potrebno: telefon; server; release build.

### Practise — Repertoar — pokrivenost

1. [ ] **Mapa pokrivenosti i dalje broji neodgovorene pozicije.** [170.4]
   O čemu se radi: Za razliku od liste i gradnje, mapa `Gaps in repertoire`
   namerno zadržava brojanje — ona se otvara baš zbog toga.
   Gde: Practise → `Opening repertoire` → red repertoara → `More` →
   `Gaps in repertoire`.
   Uradi: Otvori mapu pokrivenosti repertoara.
   Treba da vidiš: Mapa i dalje kaže koliko pozicija nema odgovor.
   Potrebno: Windows.

2. [ ] **Mapa pokrivenosti pokazuje brojeve, ne procente.** [166.10]
   O čemu se radi: Mapa (`Gaps in repertoire`) prikazuje brojeve poput „3
   decided · 1 open“, bez procenata i bez „not preparing“.
   Gde: Practise → `Opening repertoire` → red repertoara → `More` →
   `Gaps in repertoire`.
   Uradi: Otvori mapu pokrivenosti repertoara.
   Treba da vidiš: Brojevi su prikazani kao „N decided · M open“ (ne procenti),
   i nigde ne piše „not preparing“.
   Potrebno: Windows.

3. [ ] **Grane pokrivenosti: najigranija prva, numerisana linija i procenat
   partija.** [66.1]
   O čemu se radi: Ekran „Gaps in repertoire" (radar pokrivenosti) nabraja
   grane repertoara, svaku sa numerisanom linijom, imenom otvaranja ako ga
   knjiga zna, i procentom partija u kojima se ta grana igra.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (red) → `More`
   → `Gaps in repertoire`.
   Uradi: Otvoriti „Gaps in repertoire" nad repertoarom sa bar dve grane.
   Treba da vidiš: Grane su poređane najigranija prva; svaka ima numerisanu
   liniju i tekst „played in X%".
   Potrebno: Windows i telefon; server; izgrađen repertoar sa bar dve grane.

4. [ ] **Stanje grane se razaznaje bez oslanjanja na boju.** [66.5]
   O čemu se radi: Svaka grana na ekranu „Gaps in repertoire" nosi ikonicu i
   tekst koji kažu da li je gotova; ovo mora biti čitljivo bez gledanja u boju.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (red) → `More`
   → `Gaps in repertoire`.
   Uradi: Pogledati spisak grana i proveriti da se stanje svake (gotova/nije
   gotova) čita iz ikonice i teksta.
   Treba da vidiš: Stanje grane je čitljivo iz ikonice i teksta reda, nijedna
   informacija ne postoji samo kao boja.
   Potrebno: Windows i telefon; server.

5. [ ] **Oba dugmeta na grani rade.** [66.6]
   O čemu se radi: Na grani sa bar jednom odlukom stoje dugmad `Build here`
   (otvara izgradnju baš u toj grani) i `Drill branch` (otvara drill koji pita
   samo pozicije iz nje).
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (red) → `More`
   → `Gaps in repertoire`.
   Uradi: Na grani sa bar jednom odlukom pritisnuti `Build here`, vratiti se,
   pa pritisnuti `Drill branch`.
   Treba da vidiš: `Build here` otvara izgradnju tačno na toj grani;
   `Drill branch` otvara drill koji pita samo pozicije iz nje.
   Potrebno: Windows i telefon; server; izgrađena grana sa bar jednim potezom.

6. [ ] **Grana bez odluka nema dugme za vežbu.** [66.7]
   O čemu se radi: Grana u kojoj još nije odigrana nijedna sopstvena odluka
   nema dugme `Drill branch` — nema šta da se pita.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (red) → `More`
   → `Gaps in repertoire`.
   Uradi: Naći granu bez ijedne odigrane sopstvene odluke.
   Treba da vidiš: Ta grana nema dugme `Drill branch`, samo `Build here`.
   Potrebno: Windows i telefon; server.

7. [ ] **Prazan repertoar i ugašen server izgledaju različito.** [66.8]
   O čemu se radi: Nov repertoar bez ijednog poteza i repertoar koji ne može da
   se pročita zbog ugašenog servera treba da daju različite poruke na ekranu
   „Gaps in repertoire".
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (red bez
   ijednog poteza ili sa ugašenim serverom) → `More` → `Gaps in repertoire`.
   Uradi: Otvoriti „Gaps in repertoire" nad novim, praznim repertoarom; zatim,
   odvojeno, ugasiti backend i ponovo otvoriti isti ekran.
   Treba da vidiš: Prazan repertoar daje jednu poruku (npr. da još nije izabran
   nijedan potez), a ugašen server drugu, jasno o grešci — mapa se ne prikazuje
   prazna u oba slučaja.
   Potrebno: Windows i telefon; server (pa ugašen).

8. [ ] **Dubina grane raste sa brojem poteza.** [66.9]
   O čemu se radi: Svaka grana pokazuje na koji potez posle korena ide („to
   move N after root"); broj mora rasti kako se grana produbljuje.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (red) → `More`
   → `Gaps in repertoire`.
   Uradi: Uporediti dubinu prikazanu za granu od dva poteza i za granu od
   četiri poteza.
   Treba da vidiš: Dublja grana pokazuje veći broj poteza posle korena.
   Potrebno: Windows i telefon; server; izgrađena grana od bar dva poteza.

9. [ ] **Telefon: red grane u „Gaps in repertoire" se ne seče.** [66.10]
   O čemu se radi: Red grane na uskom ekranu (360 dp) ima dugu liniju i dva
   dugmeta ispod nje; u release build-u ovo se mora videti bez sečenja.
   Gde: `Practise` → `Opening repertoire` → `Open repertoire` → (red) → `More`
   → `Gaps in repertoire`.
   Uradi: Otvoriti „Gaps in repertoire" na telefonu (360 dp, release build).
   Treba da vidiš: Ni tekst linije ni dugmad se ne seku niti prelaze ivicu
   ekrana.
   Potrebno: telefon; server; release build.

### Practise — My games — arhiva, izveštaj o otvaranjima, profil

1. [ ] **Presuda motora na svakoj označenoj poziciji otvaranja.** [237.2]
   O čemu se radi: Ispod svake označene pozicije otvaranja, presuda motora kaže
   `Your move holds — the problem comes later` ili
   `Your move loses: X was better`; po merenju od 24.9., skoro sve (82 od 84)
   treba da kažu „holds“.
   Gde: `Practise` → (Opening) `My games` → `Import games` → izaberi partije →
   `View opening leaks`.
   Uradi: Pritisni `Judge with the engine` i sačekaj da presudi sve označene
   pozicije.
   Treba da vidiš: Svaka označena pozicija ima presudu
   `Your move holds — the problem comes later` ili
   `Your move loses: … was better`; velika većina (u merenju: 82 od 84) je
   „holds“.
   Potrebno: Windows; uvezene partije; debug build.

2. [ ] **„Losing habits your score doesn't show“ pokazuje skrivene navike.**
   [237.3]
   O čemu se radi: Poseban odeljak `Losing habits your score doesn't show`
   prikazuje pozicije u kojima igrač dobro prolazi, a motor kaže da odigrani
   potez zapravo gubi.
   Gde: `Practise` → (Opening) `My games` → `Import games` → izaberi partije →
   `View opening leaks`.
   Uradi: Posle presude motora, pronađi odeljak
   `Losing habits your score doesn't show` i otvori dve navedene pozicije u
   Analizi.
   Treba da vidiš: Odeljak `Losing habits your score doesn't show` postoji i
   nabraja pozicije koje inače nisu označene kao problematične; ručna provera u
   Analizi potvrđuje da je predloženi bolji potez zaista bolji.
   Potrebno: Windows; uvezene partije; debug build.

3. [ ] **Ponovni pritisak na presudu ne ponavlja posao.** [237.4]
   O čemu se radi: Kad su sve pozicije već presuđene na istoj dubini (20),
   ponovni pritisak na `Judge with the engine` javlja da nije presuđeno nijedno
   novo pitanje.
   Gde: `Practise` → (Opening) `My games` → `Import games` → izaberi partije →
   `View opening leaks`.
   Uradi: Posle prve presude, pritisni `Judge with the engine` još jednom.
   Treba da vidiš: Rezultat javlja da je presuđeno 0 novih poteza — nema
   ponovne pretrage svih pozicija.
   Potrebno: Windows; uvezene partije; debug build.

4. [ ] **Prekid presude na Crnim čuva ono što je već poslato.** [237.5]
   O čemu se radi: Kad se prebaci na presudu za crne i posle nekoliko pozicija
   pritisne `Cancel`, presuda staje, ali ono što je do tada poslato ostaje
   sačuvano — ponovni ulazak pokazuje presude za te pozicije.
   Gde: `Practise` → (Opening) `My games` → `Import games` → izaberi partije →
   `View opening leaks` (segment `Black`).
   Uradi: Prebaci na `Black`, pritisni `Judge with the engine`, pa posle
   nekoliko presuđenih pozicija pritisni `Cancel`. Osveži/ponovo otvori ekran.
   Treba da vidiš: Presuda odmah staje. Pozicije koje su stigle do prekida
   imaju svoju presudu i posle ponovnog otvaranja ekrana (nisu izgubljene).
   Potrebno: Windows; uvezene partije; debug build.

5. [ ] **Bez motora, dugme za presudu je ugašeno sa razlogom.** [237.6]
   O čemu se radi: Na telefonu (ili na računaru bez preuzetog lokalnog motora),
   dugme `Judge with the engine` je sivo i ispod njega piše zašto.
   Gde: `Practise` → (Opening) `My games` → `Import games` → izaberi partije →
   `View opening leaks`.
   Uradi: Otvori isti ekran na telefonu (ili na računaru bez preuzetog
   Stockfish-a).
   Treba da vidiš: Dugme `Judge with the engine` je neaktivno (sivo), a ispod
   njega stoji rečenica koja objašnjava da motor nije dostupan na ovom uređaju.
   Potrebno: telefon.

6. [ ] **„Drill these … losing habits“ dodaje navike u My mistakes bez
   duplikata.** [237.7]
   O čemu se radi: Ispod odeljka o skrivenim navikama, dugme
   `Drill this losing habit`/`Drill these … losing habits` dodaje ih u „My
   mistakes“ (tema „opening habit“); ponovni pritisak javlja da su već tamo,
   bez duplog dodavanja.
   Gde: `Practise` → (Opening) `My games` → `Import games` → izaberi partije →
   `View opening leaks`; zatim `Practise` → (Opening) `My mistakes` →
   `Drill mistakes`.
   Uradi: Pritisni `Drill these … losing habits` (ili
   `Drill this losing habit`), pa proveri `My mistakes` → `Drill mistakes`.
   Pritisni dugme još jednom.
   Treba da vidiš: Posle prvog pritiska: poruka sa brojem dodatih navika, i te
   pozicije se nude u drilu (tema „opening habit“, sa izgubljenim
   centipawnima). Posle drugog pritiska: poruka da su te navike već tamo, bez
   dupliranja u drilu.
   Potrebno: Windows; uvezene partije; debug build.

7. [ ] **Nema više dugmeta za sejanje repertoara iz partija.** [69.8]
   O čemu se radi: Zasejavanje repertoara iz uvezenih partija je u celini
   uklonjeno (31.8.2026); ekran za poređenje sad samo prikazuje rečenicu da se
   uvezene partije ne upisuju u repertoar.
   Gde: `Practise` → `My games` → `Import games` → (izabrati boju, otvoriti
   poređenje sa repertoarom).
   Uradi: Otvoriti ekran koji upoređuje uvezene partije sa repertoarom.
   Treba da vidiš: Nigde na ekranu ne postoji dugme za izvlačenje/sejanje
   repertoara iz partija; stoji rečenica da se uvezene partije ne dodaju u
   repertoar automatski.
   Potrebno: Windows i telefon; server.

8. [ ] **Nema više dugmeta „Proveri završnice"** [69.9]
   O čemu se radi: Provera pozicija naspram tablica završnica pri uvozu je
   uklonjena; drill grešaka i dalje radi, uključujući starije nalaze iz
   završnica koji su ranije upisani.
   Gde: `Practise` → `My games` → `Import games`.
   Uradi: Otvoriti ekran arhive partija i, ako se uvozi nova datoteka, pratiti
   uvoz do kraja.
   Treba da vidiš: Nigde se ne pojavljuje dugme za proveru završnica; „My
   mistakes" drill i dalje radi normalno.
   Potrebno: Windows i telefon; server.

9. [ ] **Četiri brojača uvoza stoje na telefonu od 360dp.** [52.b2025]
   O čemu se radi: Brojači napretka uvoza moraju stati na uzak ekran telefona
   bez prelivanja.
   Gde: `Practise` → `My games` → `Import games` → `Import more games`.
   Uradi: Na telefonu pokreni uvoz PGN fajla i posmatraj brojače dok uvoz
   traje.
   Treba da vidiš: Sva četiri brojača stoje jedan pored drugog bez prelivanja
   van ekrana.
   Potrebno: telefon; PGN fajl.

10. [ ] **"preskočeno" pokazuje razloge, ne samo broj.** [52.b2029]
   O čemu se radi: Broj preskočenih partija mora objasniti razloge, ne samo
   broj.
   Gde: `Practise` → `My games` → `Import games` → `Import more games`.
   Uradi: Uvezi PGN fajl u koji je namerno ubačena jedna partija u varijanti
   šaha koja nije standardna i jedna partija bez ijednog poteza.
   Treba da vidiš: Piše da su preskočene 2 partije i imenovan je razlog za
   svaku, ne go broj 2.
   Potrebno: Windows i telefon; PGN fajl.

11. [ ] **importId (broj kao string) se ispravno čita na klijentu.** [52.b2032]
   O čemu se radi: user_game_imports.id je BIGSERIAL i node-postgres ga vraća
   kao string; klijent ga mora čitati preko jsonInt-a. Lažni servis u testovima
   vraća int, pa ovo widget test ne može da uhvati.
   Gde: `Practise` → `My games` → `Import games` → `Import more games`.
   Uradi: Pokreni pravi uvoz (ne test) i prati da ekran prati napredak do
   kraja.
   Treba da vidiš: Uvoz se prati i završava normalno; da je importId pukao,
   ekran bi ostao zaglavljen ili odmah prijavio grešku.
   Potrebno: server; PGN fajl.

12. [ ] **Anketa na 2s se gasi kad se ekran napusti usred uvoza.** [52.b2036]
   O čemu se radi: Anketa koja proverava napredak uvoza na svake 2 sekunde ne
   sme nastaviti da radi pošto je ekran napušten.
   Gde: `Practise` → `My games` → `Import games` → `Import more games`.
   Uradi: Pokreni uvoz veće arhive, odmah napusti ekran dok uvoz traje,
   posmatraj zahteve ka serveru narednih desetak sekundi.
   Treba da vidiš: Zahtevi za proveru statusa uvoza prestaju čim se ekran
   napusti.
   Potrebno: server; PGN fajl.

13. [ ] **"View opening leaks" se pojavi tek kad je uvoz gotov.** [52.b2037]
   O čemu se radi: Dugme koje vodi na izveštaj o otvaranjima sme da se pojavi
   tek kad je uvoz stvarno gotov.
   Gde: `Practise` → `My games` → `Import games` → `Import more games`.
   Uradi: Pokreni uvoz i posmatraj dugme dok run nije gotov; posle završetka ga
   pritisni.
   Treba da vidiš: Dugme `View opening leaks` je odsutno dok uvoz nije gotov, a
   posle se pojavljuje i vodi na izveštaj za isto korisničko ime.
   Potrebno: Windows i telefon; PGN fajl.

14. [ ] **Ograničen uzorak za sat je prijavljen na ekranu.** [57.3]
   O čemu se radi: clock.sampled ume da bude manje od gamesWithClocks kad je
   uzorak ograničen; to mora da se vidi u interfejsu, ne samo u odgovoru
   servera.
   Gde: `Practise` → `My games` → red naloga → `Profile and habits`.
   Uradi: Otvori profil za nalog sa velikim brojem partija sa satom.
   Treba da vidiš: Ako je uzorak manji od ukupnog broja partija sa satom, to
   piše negde na ekranu.
   Potrebno: Windows i telefon; uvezene partije.

15. [ ] **Dva sumnjiva nalaza se ne prikazuju kao zaključak.** [57.6]
   O čemu se radi: "ispod 30s" na uzorku od 21 partije i "kratke partije idu
   lošije" ne smeju biti prikazani kao nalaz — prvi je premali uzorak, drugi je
   pitanje a ne odgovor.
   Gde: `Practise` → `My games` → red naloga → `Profile and habits`.
   Uradi: Pregledaj sekcije o vremenu i o dužini partije za nalog sa poznatom
   arhivom.
   Treba da vidiš: Nijedna od te dve tvrdnje se ne pojavljuje na ekranu kao
   zaključak.
   Potrebno: Windows i telefon; uvezene partije.

16. [ ] **Nalaz izveštaja ima smisla za vlasnika naloga.** [53.7]
   O čemu se radi: Jedina provera koju kod ne može da uradi — da li nalaz
   odgovara utisku igrača.
   Gde: `Practise` → `My games` → red naloga → `View opening leaks`.
   Uradi: Otvori izveštaj za sopstvenu arhivu i pogledaj dve-tri najjače
   pozicije.
   Treba da vidiš: Pozicije koje izveštaj ističe kao naviku zaista liče na
   mesta gde igraš loše.
   Potrebno: Windows i telefon; uvezene partije.

17. [ ] **Tabla u redu izveštaja je okrenuta prema boji.** [53.b2067]
   O čemu se radi: Tabla u redu izveštaja mora biti okrenuta prema strani koja
   je na potezu.
   Gde: `Practise` → `My games` → red naloga → `View opening leaks`.
   Uradi: Otvori izveštaj i uporedi redove za belog i za crnog.
   Treba da vidiš: Red za crnog nije nacrtan naopako i polja ne menjaju boje.
   Potrebno: Windows i telefon; uvezene partije.

18. [ ] **Suđenje počinje tek na dugme, ne samo od sebe.** [53.b2070]
   O čemu se radi: Suđenje poteza troši Lichess token pa ne sme da krene samo
   od sebe.
   Gde: `Practise` → `My games` → `View opening leaks` → `Judge moves`.
   Uradi: Otvori izveštaj (samo sa brojevima) i pritisni `Judge moves`.
   Treba da vidiš: Presuda se pojavljuje tek posle klika, ne pri otvaranju
   izveštaja; `Judge moves` posle toga nestaje.
   Potrebno: Windows i telefon; uvezene partije; internet.

19. [ ] **Bez tokena izveštaj ostaje, poruka se dodaje pored brojeva.**
   [53.b2074]
   O čemu se radi: Nedostatak tokena ne sme obrisati već prikazane brojeve
   izveštaja.
   Gde: `Practise` → `My games` → `View opening leaks` → `Judge moves` (bez
   tokena u `Settings`).
   Uradi: Ukloni Lichess token iz `Settings`, otvori izveštaj i pritisni
   `Judge moves`.
   Treba da vidiš: Brojevi ostaju vidljivi; poruka o nedostatku tokena se
   dodaje pored njih.
   Potrebno: Windows i telefon; uvezene partije.

20. [ ] **"unknown" presuda se ne crta kao greška.** [53.b2077]
   O čemu se radi: Pozicija koju niko nije ocenio (unknown) ne sme izgledati
   kao greška.
   Gde: `Practise` → `My games` → `View opening leaks` → `Judge moves`.
   Uradi: Nakon suđenja pronađi poziciju koju Lichess nije ocenio.
   Treba da vidiš: Ta pozicija nema nikakvu oznaku greške ni upozorenja.
   Potrebno: Windows i telefon; uvezene partije; internet.

21. [ ] **Boja nije jedini kanal na značkama izveštaja.** [53.b2079]
   O čemu se radi: Vlasnik projekta je daltonista; ovo je provera koju samo on
   može da uradi.
   Gde: `Practise` → `My games` → `View opening leaks` → `Judge moves`.
   Uradi: Pogledaj sve vrste znački u izveštaju.
   Treba da vidiš: Svaka značka nosi i ikonu i tekstualni naziv, ne samo boju.
   Potrebno: Windows i telefon; uvezene partije.

22. [ ] **Dugme za dopunu se pojavljuje i nestaje po potrebi.** [53.b2082]
   O čemu se radi: Dugme za dopunu starijih partija treba da se pojavljuje i
   nestaje prema stvarnom stanju.
   Gde: `Practise` → `My games` → red naloga sa starijim partijama →
   `View opening leaks`.
   Uradi: Otvori izveštaj za nalog koji ima nedopunjene starije partije,
   pritisni dugme za dopunu.
   Treba da vidiš: Dugme je vidljivo dok ima nedopunjenih partija i nestaje
   posle uspešne dopune.
   Potrebno: Windows i telefon; uvezene partije.

### Practise — My mistakes

1. [ ] **„Open this game in Analysis“ iz My mistakes i dalje radi.** [195.6]
   O čemu se radi: Faza 13 je dodala dugme „Open in Analysis“ na odigranu
   domaću partiju; ova stavka proverava da stariji ulaz u Analizu iz arhive
   grešaka (koji deli isti mehanizam) nije pokvaren tom izmenom.
   Gde: Practise → `My mistakes` → red greške → `Open this game in Analysis`.
   Uradi: Otvori My mistakes sa bar jednom greškom iz uvezene partije i
   pritisni `Open this game in Analysis`.
   Treba da vidiš: Analyse se otvori sa celom partijom te greške, tabla stoji
   na potezu greške, kretanje unazad/unapred radi kao pre.
   Potrebno: Windows i telefon; uvezene partije.

2. [ ] **"recurrence" rečenica ima smisla za igrača.** [55.6]
   O čemu se radi: Rečenica o ponavljajućem obrascu grešaka (recurrence) je
   jedina provera koju kod ne može da uradi.
   Gde: `Practise` → `My mistakes`.
   Uradi: Otvori `My mistakes` za sopstvenu arhivu i pročitaj rečenicu o
   ponavljajućem obrascu.
   Treba da vidiš: Rečenica zvuči tačno u odnosu na sopstveni utisak o svojoj
   igri.
   Potrebno: Windows i telefon; uvezene partije.

3. [ ] **„Remove from drill“ pita, uklanja i prelazi dalje, partija ostaje.**
   [226.10]
   O čemu se radi: U drilu grešaka, `Remove from drill` traži potvrdu, ukloni
   tu grešku iz drila (ne vraća se više) i pređe na sledeću; sama partija u
   arhivi ostaje netaknuta.
   Gde: `Practise` → (Opening) `My mistakes` → `Drill mistakes`.
   Uradi: U toku drila grešaka, na jednoj poziciji pritisni `Remove from drill`
   i potvrdi.
   Treba da vidiš: Traži se potvrda (`Remove this mistake?` sa
   `Cancel`/`Remove`). Posle potvrde, drill odmah prelazi na sledeću grešku, a
   ta se više ne pojavljuje; partija ostaje u arhivi (`My games`) nepromenjena.
   Potrebno: Windows; uvezene partije.

4. [ ] **Iz arhive grešaka otvara se cela partija u Analizi.** [161.6]
   O čemu se radi: U „My mistakes“ (arhiva) dugme `Open this game in Analysis`
   otvara celu partiju u Analizi, sa tablom na potezu greške, okrenutom ka
   strani igrača.
   Gde: `Practise` → (Opening) `My mistakes` → `Drill mistakes` → red greške →
   `Open this game in Analysis`.
   Uradi: Otvori grešku iz partije sa rokadom (npr. partija sa Lichess-a gde je
   rokada zapisana kao `e1h1`) preko `Open this game in Analysis`, pa odigraj
   partiju do kraja.
   Treba da vidiš: Analiza se otvara sa celom partijom, tabla stoji na potezu
   greške i okrenuta je ka strani igrača koji je pogrešio. Partija sa `e1h1`
   rokadom se odigra do kraja bez greške u tumačenju poteza.
   Potrebno: Windows; uvezene partije.

5. [ ] **Zadatak bez best_uci se ne nudi u drilu grešaka.** [60.3]
   O čemu se radi: Drill „My mistakes" ponavlja greške iz partija; filtriranje
   po tome da li greška ima poznat najbolji potez i dalje postoji u kodu ekrana
   i nikad nije gledano uživo.
   Gde: `Practise` → (odeljak „Opening") → `My mistakes` → `Drill mistakes`.
   Uradi: Otvoriti drill grešaka i proći kroz nekoliko pitanja. Ako je moguće,
   proveriti preko servera da li postoje greške bez zapisanog najboljeg poteza.
   Treba da vidiš: Nijedna pozicija u drilu nema tekst „Puzzle" bez ponuđenog
   rešenja — svaka prikazana pozicija ima potez koji se ocenjuje kad se otkrije
   rešenje.
   Potrebno: Windows i telefon; server.

6. [ ] **Ocena „Good" pomera rok, rečenica dolazi sa servera.** [60.4]
   O čemu se radi: Posle prikazanog rešenja korisnik ocenjuje koliko dobro je
   znao potez (Again/Hard/Good/Easy); server vraća sledeći rok i rečenicu koja
   se prikazuje.
   Gde: `Practise` → `My mistakes` → `Drill mistakes` → (otkriti rešenje) →
   `Good`.
   Uradi: Odgovoriti na jednu poziciju, otvoriti rešenje, pritisnuti `Good`.
   Zapamtiti poruku koja se pojavi. Ponoviti sledećeg dana ili proveriti da se
   ista pozicija ne vraća odmah.
   Treba da vidiš: Posle ocene se pojavljuje poruka koja zvuči kao rečenica, ne
   kao „interval: 3" — to je tekst koji je poslao server, ne sastavljen od
   broja u aplikaciji.
   Potrebno: Windows i telefon; server.

7. [ ] **Nalaz iz tablice završnica ne prikazuje centipione.** [60.5]
   O čemu se radi: Greška može doći iz motora (centipioni + tema) ili iz
   tablice završnica (WDL: pobeda/remi/gubitak); ekran ih prikazuje različito.
   Gde: `Practise` → `My mistakes` → `Drill mistakes`.
   Uradi: Rešavati pozicije dok se ne pojavi jedna iz tablice završnica (WDL
   redak, bez protivnika/otvaranja iz partije nije odlučujuće — prepoznaje se
   po tekstu „Tablebase: …").
   Treba da vidiš: Uz nalaz iz tablice završnica piše samo „Tablebase:
   Won/Lost/Draw -> …", nikad „… cp" (centipioni se ispisuju samo kad je nalaz
   iz motora).
   Potrebno: Windows i telefon; server.

8. [ ] **Česte greške: taktika i završnice su dve odvojene liste.** [60.6]
   O čemu se radi: Na ekranu „Done for today" / „Nothing due" stoji odeljak
   „Your frequent mistakes" sa dva pododeljka, „Tactics (motifs)" i „Endgames",
   svaki sa svojim brojevima.
   Gde: `Practise` → `My mistakes` → `Drill mistakes` → (rešiti sve dospele
   pozicije).
   Uradi: Rešiti dovoljno pozicija da se stigne do ekrana „Done for today." ili
   „Nothing due.". Pogledati odeljak „Your frequent mistakes" ako se pojavi.
   Treba da vidiš: „Tactics (motifs)" i „Endgames" su dva odvojena spiska sa
   svojim brojevima — nijedan red iz jednog ne prelazi u drugi niti se rangira
   zajedno s njim.
   Potrebno: Windows i telefon; server.

9. [ ] **Ocena pomera rok ponavljanja.** [55.2]
   O čemu se radi: Ponavljanje sopstvenih grešaka koristi isti SM-2 mehanizam
   kao ponavljanje lekcija.
   Gde: `Practise` → `My mistakes` → `Show answer` → ocena.
   Uradi: Otvori stavku, pritisni `Show answer`, oceni je sa `Good`; drugu
   oceni sa `Again`.
   Treba da vidiš: Posle `Good` se rok pomera unapred; posle `Again` se stavka
   vraća na isti dan.
   Potrebno: Windows i telefon.

### Practise — Završnice i greške iz partija

1. [ ] **Kartica završnica ima dve imenovane linije napretka.** [176.4]
   O čemu se radi: Prijavljeno uživo 18.9.2026 („piše solved 0 i solved 1“,
   zbunjuje) i popravljeno isti dan — kartica završnica nosi dva izvora
   (Win/Hold a draw sabrani, i posebno Game blunders), pa su obe linije dobile
   ime.
   Gde: Practise → `Endgames from master games`.
   Uradi: Reši po jednu zagonetku iz završnica i iz partija-grešaka (Game
   blunders), pa se vrati na Practise.
   Treba da vidiš: Kartica pokazuje dva reda: „Endgames: Solved … · … to retry“
   i ispod „Game blunders: Solved …“ — dva imenovana broja, ne jedan koji sam
   sebi protivreči.
   Potrebno: Windows i telefon.

2. [ ] **Presuda završnice je na engleskom (Position: draw/win/loss).** [169.1]
   O čemu se radi: Deo engleskog pivota — presuda o rezultatu pozicije se
   ispisuje na engleskom, nigde na srpskom „remi“.
   Gde: Practise → `Endgames from master games` → dril.
   Uradi: Dovedi drill do pozicije čiji je ishod remi, dobitak i gubitak i
   pogledaj oznaku presude.
   Treba da vidiš: Presuda piše „Position: draw“ / „win“ / „loss“ — nigde reč
   „remi“.
   Potrebno: Windows.

3. [ ] **Tablebase findings se u drilu otvaraju desno, ne kao donji list.**
   [172.5]
   O čemu se radi: Deo prve provere koji vlasnik nije prijavio kao problem (i
   dalje važi, per stavka 173).
   Gde: Practise → `Endgames from master games` → `Win`/`Hold a draw` → dril
   (telefon položeno).
   Uradi: U drilu završnica ili grešaka iz partija, na telefonu položeno,
   otvori `Tablebase findings`.
   Treba da vidiš: Nalazi se pojavljuju u panelu desno od table, ne kao donji
   list koji prekriva ekran.
   Potrebno: telefon; telefon položeno.

4. [ ] **Pat motorovim potezom se sad javlja dijalogom.** [181.3]
   O čemu se radi: Teško je izazvati (motor retko pravi pat), ali ako se desi,
   mora da se prikaže isti dijalog kao za pat sopstvenim potezom, ne stara tiha
   poruka pri dnu ekrana.
   Gde: Practise → `Practice basic checkmates` ili `Find the winning path`.
   Uradi: Odigraj partiju do pozicije gde motor može da napravi pat (retko,
   možda treba više pokušaja ili posebno pripremljena pozicija).
   Treba da vidiš: Ako se pat motorovim potezom desi, prikazuje se dijalog (ne
   tiha poruka „Stalemate/Draw“ pri dnu), sa `Try again` i `Next Position`.
   Potrebno: Windows; debug build.

5. [ ] **„Why it is bad" pa „Skip": nema zaostalog dugmeta.** [0k.b155]
   O čemu se radi: U šetnji kroz partiju sa greškama, dugme `Why it is bad`
   automatski odigra kaznu (refutaciju); prelazak na sledeću partiju
   (`Skip`/`Next game`) mora da očisti to stanje, da ne bi ostalo zaglavljeno
   dugme `Back to game` iz prethodne partije.
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Game blunders` → stati na neodgovorenu
   grešku → `Why it is bad` → `Skip` (ili `Next game`).
   Uradi: Na neodgovorenoj grešci pritisnuti `Why it is bad`, sačekati da se
   kazna odigra, pa pritisnuti `Skip` (ili `Next game`).
   Treba da vidiš: Nova partija se igra normalno — dugme `Back to game` iz
   prethodne partije se ne pojavljuje niti ostaje aktivno.
   Potrebno: Windows i telefon.

6. [ ] **Panel javlja da tabla nije za igru dok kazna traje.** [0k.b157]
   O čemu se radi: Dok se refutacija (kazna) automatski odigrava posle
   `Why it is bad`, panel iznad table javlja da se tu ne igra i da
   `Back to game` vraća na šetnju.
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Game blunders` → `Why it is bad`.
   Uradi: Pritisnuti `Why it is bad` na neodgovorenoj grešci i, dok se kazna
   sama odigrava, pogledati tekst iznad table.
   Treba da vidiš: Piše
   `The board cannot be played here — you are watching the refutation.` i da
   dugme `Back to game` vraća na šetnju.
   Potrebno: Windows i telefon.

7. [ ] **Šetnja nastavlja i kad glas ne javi kraj izgovora.** [0k.b171]
   O čemu se radi: Ako mehanizam za govor nikad ne javi da je pročitao
   rečenicu, tajmer izračunat iz dužine teksta ipak pusti šetnju dalje, uz red
   u dnevniku aplikacije.
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Game blunders`, sa uključenim govorom.
   Uradi: Sa uključenim govorom pustiti šetnju kroz partiju sa greškama i
   navesti situaciju u kojoj mehanizam za govor ne prijavi kraj rečenice (npr.
   isključiti zvuk uređaja pa pratiti dnevnik/konzolu).
   Treba da vidiš: Šetnja ipak nastavi posle roka izračunatog iz dužine
   rečenice, a u dnevniku stoji red
   `[Speech] End of utterance was never reported, carrying on.`.
   Potrebno: Windows i telefon; debug build.

8. [ ] **„Start over" u kazni vraća na poziciju posle greške.** [0d.b82]
   O čemu se radi: Kad se prava greška iz partije kažnjava (dugme `Punish`),
   kažnjavanje počinje od pozicije odmah posle greške; `Start over` za vreme
   kažnjavanja mora da vrati baš tu poziciju, ne početak cele partije.
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Hold a draw` → izabrati sve → `Start` → naći
   poziciju sa stvarnom greškom (rečenica „In the game, ... was played and the
   draw was lost." iznad table) → `Punish`.
   Uradi: Otvoriti takvu poziciju, pritisnuti `Punish`, odigrati par poteza, pa
   pritisnuti `Start over`.
   Treba da vidiš: Tabla se vrati na poziciju odmah posle greške iz partije
   (onu koju je `Punish` otvorio), a ne na sam početak vežbe.
   Potrebno: Windows i telefon.

9. [ ] **Bezpešačka pozicija bez pravog remija dobija „Conclude draw"**
   [0l.b247]
   O čemu se radi: Kad se za vreme držanja remija izgube svi pešaci, pojavljuje
   se dugme `Conclude draw`, koje proverava kod tablica i zatvara vežbu ako je
   remi zaista mrtav.
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Hold a draw` → `Start` → `Play to the end`.
   Uradi: U poziciji za držanje remija odigrati do stanja bez ijednog pešaka na
   tabli, pa pritisnuti `Conclude draw`.
   Treba da vidiš: Ako je pozicija zaista mrtav remi: poruka
   `Draw is concluded — no pawns left...` i vežba se zatvori.
   Potrebno: Windows i telefon.

10. [ ] **Kad remi nije mrtav, broji se „To draw: …"** [0l.b249]
   O čemu se radi: Ako `Conclude draw` proveri kod tablica da pozicija još nije
   dokazano mrtav remi, umesto zatvaranja postavlja se brojač koliko poteza
   treba održati remi.
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Hold a draw` → `Start` → `Play to the end` →
   `Conclude draw` na poziciji koja još nije dokazano mrtav remi.
   Uradi: Pritisnuti `Conclude draw` na poziciji koja tehnički još nije
   dokazano mrtav remi.
   Treba da vidiš: Poruka imenuje potez koji gubi remi i postavlja čip
   `To draw: …`; posle osam održanih poteza vežba se sama zatvori
   (`Draw held for … more moves — drill completed.`).
   Potrebno: Windows i telefon.

11. [ ] **Ako se remi ispusti, čip „To draw" nestaje.** [0l.b251]
   O čemu se radi: Za vreme brojanja preostalih poteza (čip `To draw: …`),
   potez koji ispusti remi mora odmah da ukloni čip i zaustavi vežbu kao i
   inače.
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Hold a draw` → `Start` → `Play to the end` →
   `Conclude draw` → za vreme brojanja `To draw: …`.
   Uradi: Za vreme brojanja `To draw: …` odigrati potez koji ispušta remi.
   Treba da vidiš: Čip `To draw: …` nestaje i vežba staje kao i inače (imenuje
   se izgubljen rezultat).
   Potrebno: Windows i telefon.

12. [ ] **Trostruko ponavljanje se razlikuje od pravila pedeset poteza.**
   [0l.b253]
   O čemu se radi: Kad se vežba igranja do kraja sama zatvori jer je pozicija
   dosegla remi po pravilu, poruka mora imenovati pravi razlog — trostruko
   ponavljanje ili pedeset poteza bez kapture/pešačkog poteza — a ne ih mešati.
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Hold a draw` → `Start` → `Play to the end`.
   Uradi: Dovesti poziciju do trostrukog ponavljanja; posebno, dovesti drugu
   poziciju do pedeset poteza bez uzimanja/pešačkog poteza.
   Treba da vidiš: Za ponavljanje piše `Threefold repetition — draw held.`; za
   pravilo pedeset poteza piše `Fifty moves without a capture — draw held.` —
   dve različite poruke.
   Potrebno: Windows i telefon.

13. [ ] **Katalog završnica piše engleski, sa ispravnom jedninom.** [132.4]
   O čemu se radi: Imena familija i pojedinačnih materijala u katalogu
   završnica su engleska, sa ispravnom jedninom/množinom (npr. „rook and pawn
   versus rook”, ne „rooks” kad je jedan top).
   Gde: `Practise` → (kartica) `Endgames from master games` → `Win` ili
   `Hold a draw`.
   Uradi: Otvori birač završnica i prođi kroz nekoliko kategorija (npr. „Rook
   endgames”, „Pawn endgames”) i pojedinačnih materijala.
   Treba da vidiš: Sva imena su engleska; naziv materijala pravilno koristi
   jedninu kad ima samo jedan top/pešak/itd. (npr. „rook and pawn versus rook”,
   ne „rooks and pawns”).
   Potrebno: Windows.

14. [ ] **Taster N radi odmah po otvaranju ekrana.** [26.b783]
   O čemu se radi: Taster N je isto što i dugme za sledeću poziciju
   (`Next`/`Skip`) i mora da radi bez ijednog prethodnog klika, jer ekran sam
   uzme fokus tastature.
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Win` ili `Hold a draw` → `Start`.
   Uradi: Otvoriti vežbu na Windows-u i, bez ijednog klika mišem, pritisnuti
   taster N.
   Treba da vidiš: Prelazi se na sledeću poziciju, isto kao dugme `Skip` (ili
   `Next` kad je pozicija rešena).
   Potrebno: Windows.

15. [ ] **Taster H daje pomoć, ćuti kad dugmeta nema.** [26.b785]
   O čemu se radi: Taster H je isto što i dugme `Hint`, koje nestaje čim je
   pozicija rešena — taster tada ne sme ništa da uradi.
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Win` ili `Hold a draw` → `Start`.
   Uradi: Pritisnuti H pre rešenja pozicije, pa ponovo posle rešenja.
   Treba da vidiš: Pre rešenja se pojavljuje rečenica oblika
   `Move leads to square ...`; posle rešenja (kad dugmeta `Hint` nema) taster H
   ništa ne radi.
   Potrebno: Windows.

16. [ ] **Taster R pokreće „Start over" samo za vreme igranja do kraja.**
   [26.b787]
   O čemu se radi: Taster R je danas vezan za dugme `Start over` (nekadašnje
   „Pokušaj ponovo"/„Ispočetka"), i radi samo dok se pozicija igra do kraja ili
   kažnjava — u običnom rešavanju pogrešan potez se sam vraća bez posebnog
   dugmeta, pa tu R ništa ne radi.
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Win` ili `Hold a draw` → `Start` → `Punish`
   ili `Play to the end`.
   Uradi: Za vreme igranja do kraja pritisnuti R; zatim probati R u običnom
   rešavanju pozicije (pre nego što se igra do kraja).
   Treba da vidiš: Za vreme igranja do kraja R pokreće isto što i dugme
   `Start over`; u običnom rešavanju (gde tog dugmeta nema) taster ne radi
   ništa.
   Potrebno: Windows.

17. [ ] **Taster T otvara/zatvara nalaz tablica samo u igranju do kraja.**
   [26.b789]
   O čemu se radi: Taster T je isto što i dugme
   `Tablebase findings`/`Hide findings`, i radi samo dok se pozicija igra do
   kraja.
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Win` ili `Hold a draw` → `Start` → `Punish`
   ili `Play to the end`.
   Uradi: Za vreme igranja do kraja na širokom prozoru pritisnuti T, pa ponovo
   T.
   Treba da vidiš: Prvi pritisak otvara panel `Tablebase findings`; drugi ga
   zatvara, isto kao dugme `Hide findings`.
   Potrebno: Windows.

18. [ ] **Taster U vraća potez tek posle greške.** [26.b791]
   O čemu se radi: Taster U je isto što i dugme `Take back`, koje se pojavljuje
   tek pošto je neki potez tokom igranja do kraja ispustio rezultat.
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Win` ili `Hold a draw` → `Start` → `Punish`
   ili `Play to the end`.
   Uradi: Za vreme igranja do kraja odigrati tačan potez pa pritisnuti U (ne
   treba ništa da se desi); zatim odigrati potez koji ispušta rezultat pa
   pritisnuti U.
   Treba da vidiš: U ne radi ništa dok nijedan potez nije ispustio rezultat;
   posle takvog poteza U vraća potez, isto kao dugme `Take back`.
   Potrebno: Windows.

19. [ ] **N, R i U ne rade dok tablica odgovara.** [26.b792]
   O čemu se radi: Dok je tabla zaključana zbog čekanja na tablicu, tasteri N,
   R i U ne smeju ništa da urade — isto kao ugašena dugmad.
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Win` ili `Hold a draw` → `Start` → `Punish`
   ili `Play to the end`.
   Uradi: Za vreme igranja do kraja odigrati potez i, dok tabla čeka odgovor
   tablica (tabla zaključana), brzo pritisnuti N, R i U.
   Treba da vidiš: Nijedan od tri tastera ništa ne radi dok je tabla
   zaključana; posle odgovora ponovo rade.
   Potrebno: Windows.

20. [ ] **Dugmad vežbe u redu na uskom telefonu.** [0c.b66]
   O čemu se radi: Kad se pozicija do sedam figura igra do kraja, ispod table
   stoji red dugmadi (`Hint`, `Save for later`, `Play to the end`, `Punish`,
   `Next`/`Skip`) koji se lomi u novi red (`Wrap`) kad ne stane u širinu
   ekrana.
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Win` ili `Hold a draw` → izabrati pozicije →
   `Start` → rešiti ili igrati do kraja poziciju do sedam figura.
   Uradi: Na telefonu (360 dp širine) otvoriti vežbu do sedam figura i
   pogledati red dugmadi ispod table, uključujući `Play to the end`.
   Treba da vidiš: Nijedno dugme nije odsečeno niti izlazi van ekrana — dugmad
   se prelamaju u novi red kad ne stanu, nema horizontalnog prelivanja.
   Potrebno: telefon.

21. [ ] **Pozicija „dobitak → remi" nema dugme za kaznu.** [0d.b84]
   O čemu se radi: Dugme `Punish` postoji samo za pozicije gde je remi bačen
   (moglo je da se drži remi, a greška ga je pretvorila u gubitak); pozicija
   gde je dobitak spao na remi nema šta da se „uzme", pa dugme izostaje.
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Win` → izabrati sve → `Start` → naći
   poziciju gde je dobitak spao na remi (rečenica „In the game, ... was played
   and the win was dropped.").
   Uradi: Otvoriti nekoliko pozicija tipa `Win` sa stvarnom greškom (dobitak →
   remi) i proveriti donji red dugmadi.
   Treba da vidiš: Dugme `Punish` se ne pojavljuje ni na jednoj takvoj
   poziciji.
   Potrebno: Windows i telefon.

22. [ ] **Čip „Mistakes: N" raste posle svakog vraćanja.** [0d.b93]
   O čemu se radi: Za vreme kažnjavanja ili igranja do kraja, dugme `Take back`
   vraća poslednji potez besplatno, ali svaki neuspeli potez pre toga već
   poveća čip „Mistakes: N" u zaglavlju — vraćanje ga ne umanjuje.
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Win` ili `Hold a draw` → `Start` → `Punish`
   ili `Play to the end`.
   Uradi: Za vreme igranja do kraja odigrati potez koji ne drži rezultat
   (pojavljuje se dugme `Take back`), pritisnuti `Take back`, pa ponoviti isto
   još jednom.
   Treba da vidiš: Čip `Mistakes: …` u zaglavlju raste za jedan pri svakoj
   takvoj grešci i ne opada kad se potez vrati.
   Potrebno: Windows i telefon.

23. [ ] **Klik na potez iz nalaza ga odigra; čip „Exploring" i dugme „Back to
   position"** [0l.b240]
   O čemu se radi: Nalaz tablica se otvara dugmetom `Tablebase findings` pored
   igranja do kraja; klik na neki od ponuđenih poteza ga odigra na tabli i
   prebacuje ekran u istraživanje.
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Win` ili `Hold a draw` → `Start` →
   `Tablebase findings`.
   Uradi: Otvoriti `Tablebase findings` i kliknuti na neki ponuđeni potez.
   Treba da vidiš: Potez se odigra na tabli, pojavi se čip `Exploring` i dugme
   `Back to position`.
   Potrebno: Windows i telefon.

24. [ ] **U istraživanju se pomera i protivnička strana, bez brojanja
   grešaka.** [0l.b242]
   O čemu se radi: U režimu `Exploring` (posle klika na potez iz nalaza) mogu
   da se pomeraju obe strane, a potezi se ne broje kao greške.
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Win` ili `Hold a draw` → `Start` →
   `Tablebase findings` → klik na potez.
   Uradi: U režimu `Exploring` odigrati poteze za obe strane.
   Treba da vidiš: Panel prati novu poziciju, potezi se ne broje kao greške
   (poruka `Exploring — moves are not graded here.`).
   Potrebno: Windows i telefon.

25. [ ] **„Save for later" stoji i pre i posle odgovora.** [0j.b262]
   O čemu se radi: Dugme za čuvanje nejasne pozicije radi u oba ekrana (treneru
   završnica i šetnji kroz partiju), i pre i posle odgovora na poziciju.
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Win`/`Hold a draw`/`Game blunders`.
   Uradi: Pogledati dugme `Save for later` pre nego što se pozicija reši, pa i
   posle.
   Treba da vidiš: Dugme stoji na oba mesta pre i posle odgovora; klik ga menja
   u `Saved` i ne dozvoljava dvostruko čuvanje iste pozicije, a poruka kaže
   `Saved in "My positions", tagged "Unclear".`.
   Potrebno: Windows i telefon.

26. [ ] **Kad server ne odgovori, dugme za čuvanje ostaje aktivno.** [0j.b269]
   O čemu se radi: Ako čuvanje pozicije ne uspe (server nije dostupan), dugme
   `Save for later` ne sme trajno da ostane onemogućeno — mora da se može
   probati ponovo.
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Win`/`Hold a draw`/`Game blunders` →
   `Save for later`.
   Uradi: Ugasiti backend i pritisnuti `Save for later`.
   Treba da vidiš: Poruka kaže `Could not save position right now.`, a dugme
   ostaje aktivno (nije zamenjeno sa `Saved`) — može se probati ponovo.
   Potrebno: Windows i telefon.

27. [ ] **Rečenica o tome zašto potez drži stoji uz odgovor.** [0h.b292]
   O čemu se radi: Posle tačnog odgovora se, kad je nešto zajedničko svim
   potezima koji drže, pojavljuje rečenica poput `Only the king moves hold.` —
   na oba ekrana (treneru i šetnji).
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Win`/`Hold a draw`/`Game blunders`.
   Uradi: Rešiti nekoliko pozicija u oba ekrana i pratiti tekst posle tačnog
   odgovora.
   Treba da vidiš: Rečenica se pojavljuje uz odgovor (ne pre njega) na oba
   ekrana; kad drži samo jedan potez, rečenica o „svim potezima" izostaje, a
   rečenica o liniji/vrsti sme da stoji; kod otprilike polovine pozicija
   rečenice nema (namerno).
   Potrebno: Windows i telefon.

28. [ ] **Promena nivoa menja i ukupan i broj po vrsti.** [0g.b311]
   O čemu se radi: Ekran za izbor završnica pre vežbe prikazuje ukupan izabrani
   broj u dnu i broj po svakoj vrsti materijala; promena nivoa mora oba da
   osveži odmah, bez novog zahteva serveru.
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Win` ili `Hold a draw`.
   Uradi: Promeniti izbor u odeljku `Level` (npr. sa `All levels` na uži
   opseg).
   Treba da vidiš: Broj u dnu (`Selected: …`) i brojevi uz svaku porodicu/vrstu
   materijala se odmah promene, tačno i bez čekanja na server.
   Potrebno: Windows i telefon.

29. [ ] **Sve isključeno: „Start" ugašeno, piše da ništa ne odgovara.**
   [0g.b312]
   O čemu se radi: Kad ni jedna vrsta materijala nije izabrana, dugme za start
   mora biti ugašeno i reći da ništa ne odgovara izboru.
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Win` ili `Hold a draw`.
   Uradi: Isključiti sve kvačice (sve porodice/vrste materijala).
   Treba da vidiš: Dugme `Start` je ugašeno, a piše
   `No positions match this selection`.
   Potrebno: Windows i telefon.

30. [ ] **„Start" sa svim uključenim daje pun izbor.** [0g.b313]
   O čemu se radi: Sa svim porodicama uključenim, `Start` mora da ponudi pun
   raspon pozicija, kao pre nego što je ovaj ekran uveden.
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Win` ili `Hold a draw`.
   Uradi: Sa svim uključenim pritisnuti `Start`.
   Treba da vidiš: Vežba servira pozicije iz cele zbirke, bez suženja.
   Potrebno: Windows i telefon.

31. [ ] **Uzak izbor stvarno servira samo taj tip.** [0g.b314]
   O čemu se radi: Izbor samo jedne vrste materijala mora zaista da suzi šta se
   servira, ne samo brojku u zaglavlju.
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Win` ili `Hold a draw`.
   Uradi: Izabrati samo jednu vrstu materijala (npr. samo top i pešak protiv
   topa), pritisnuti `Start`, i rešiti nekoliko pozicija zaredom.
   Treba da vidiš: Sve servirane pozicije su tog istog tipa — proveriti oznaku
   tipa na svakoj.
   Potrebno: Windows i telefon.

32. [ ] **Prekidač „samo raznobojni lovci" radi.** [0g.b316]
   O čemu se radi: Prekidač za pozicije sa raznobojnim lovcima se prikazuje
   samo kad ih ima u zbirci i mora stvarno da suzi izbor kad se uključi.
   Gde: `Practise` → (faza „Endgame and technique") →
   `Endgames from master games` → `Win` ili `Hold a draw`.
   Uradi: Uključiti `Opposite-colored bishops only` (prikazuje se samo ako
   takvih pozicija ima u zbirci).
   Treba da vidiš: Spisak se suzi samo na pozicije sa raznobojnim lovcima; nivo
   (`Level`) tada ne utiče (rečenica ispod to i kaže).
   Potrebno: Windows i telefon.

### Practise — AI Studio i zagonetke

1. [ ] **AI Studio ima prekidače za strelice motora.** [93.11]
   O čemu se radi: Vlasnik je 3.9.2026 prijavio da AI Studio nema prekidače na
   tabli. Meni na tabli je od tada dodat u AI Studio; prekidač za motor nije
   ponuđen samo dok se rešava zadatak iz domaćeg.
   Gde: `Practise` → (kartica AI zadataka) → (otvoren zadatak sa uključenom
   evaluacijom) → `Board view`.
   Uradi: U AI Studiju otvori zadatak (ne dodeljeni od strane trenera) sa
   uključenim prikazom evaluacije, tako da se strelice motora crtaju na tabli.
   Otvori meni `Board view` i isključi `Engine arrows`.
   Treba da vidiš: Meni nudi prekidače, uključujući `Engine arrows`;
   isključivanjem strelice motora nestaju, tabla ostaje.
   Potrebno: Windows i telefon; server.

2. [ ] **Vodoravna traka evaluacije se čita preko granice.** [45.b1712]
   O čemu se radi: Ista provera kao za uspravnu traku, ali za vodoravni oblik
   korišćen u vežbama.
   Gde: `Practise` → `Find the winning path` →
   `Start practicing winning positions`.
   Uradi: Pokreni vežbu protiv motora i posmatraj vodoravnu traku evaluacije.
   Treba da vidiš: Broj ispisan preko granice bele i crne polovine trake se
   čita jasno u oba slučaja.
   Potrebno: Windows i telefon.

3. [ ] **Pobeda posle zamene strana ostaje pobeda.** [44.b1683]
   O čemu se radi: Kad se u stablu vratiš na motorov potez i odigraš ga sam,
   motor od tog trenutka igra tvoju staru stranu; mat koji zadaš novom stranom
   mora javiti pobedu, ne poraz.
   Gde: `Practise` → `Find the winning path` →
   `Start practicing winning positions`.
   Uradi: U toku vežbe vrati se u stablu na poziciju gde je motor na potezu,
   odigraj taj potez ručno (zamena strana), pa odigraj do mata novom stranom.
   Treba da vidiš: Javlja se dijalog "VICTORY!", ne dijalog poraza.
   Potrebno: Windows i telefon.

4. [ ] **"Try again" vraća istu poziciju, "Next Position" novu.** [44.b1686]
   O čemu se radi: Dugmad posle poraza u vežbi moraju raditi razliku između
   probe iste pozicije i prelaska na sledeću.
   Gde: `Practise` → `Find the winning path` →
   `Start practicing winning positions`.
   Uradi: Izgubi vežbu (pusti motora da matira), pritisni `Try again`; zatim
   izgubi ponovo i pritisni `Next Position`.
   Treba da vidiš: `Try again` vrati istu početnu poziciju; `Next Position`
   učita drugu.
   Potrebno: Windows i telefon.

5. [ ] **Traka o zameni strana se ne pojavljuje pri normalnoj igri.**
   [44.b1688]
   O čemu se radi: Traka o zameni strana treba da se javlja samo kad zamena
   stvarno postoji, ne pri običnoj igri.
   Gde: `Practise` → `Find the winning path` →
   `Start practicing winning positions`.
   Uradi: Odigraj celu vežbu od prvog do poslednjeg poteza svojom stranom, bez
   ikakvog vraćanja u stablu.
   Treba da vidiš: Traka o zameni strana se nijednom ne pojavi.
   Potrebno: Windows i telefon.

6. [ ] **Traka o zameni strana je čitljiva u jednoj boji.** [45.b1718]
   O čemu se radi: Traka je od paketa tokena obojena jednobojno (infoContainer)
   umesto ranijim dvema bojama po strani; strana se sad vidi po ivici i
   ikonici, jedina namerna vidljiva promena tog paketa.
   Gde: `Practise` → `Practice basic checkmates` ili `Find the winning path`.
   Uradi: Na telefonu izazovi zamenu strana i pogledaj traku iznad table.
   Treba da vidiš: Traka je čitljiva; strana se prepoznaje po ivici/ikonici, ne
   samo po tekstu.
   Potrebno: telefon.

7. [ ] **Stara traka čipova poteza je nestala, stablo rešenja nije.**
   [43.b1650]
   O čemu se radi: Traka poteza kao niz čipova ("Početak", "1. Bd1", …) je
   zamenjena zajedničkim traka za kretanje kroz poteze-om (paket UI
   unifikacije, 20.8.2026); u zadatku "Mat u N poteza" ostaje samo grafičko
   stablo rešenja.
   Gde: `Practise` → `Puzzles: Mate in 1, 2 or 3 moves` → `Mate in 2`.
   Uradi: Reši ili predaj se u nekoliko pozicija tipa mat, pregledaj svaki
   ekran gde se ranije javljala traka poteza.
   Treba da vidiš: Nigde se ne pojavljuje traka čipova poteza; grafičko stablo
   rešenja radi kao i pre.
   Potrebno: Windows i telefon.

8. [ ] **Broj „to retry“ je tačan odmah po povratku na Practise.** [176.2]
   O čemu se radi: Prijavljeno 18.9.2026 kao pogrešan broj, nađeno i
   popravljeno isti dan: upis pokušaja i čitanje kartice su se prestizali. Sada
   kartica čeka da se upis završi pre nego što pročita broj.
   Gde: Practise → `Puzzles: Mate in 1, 2 or 3 moves`.
   Uradi: Reši jedan mat u 2, promaši drugi, preskoči treći dugmetom
   `Next Position`, pa se odmah vrati na Practise (bez odlaska na drugi ekran).
   Treba da vidiš: Kartica odmah pokazuje „Solved 1 · 2 to retry“ i dugme
   `Retry failed (…)` — tačan broj bez potrebe da se prvo ode na drugi ekran i
   vrati.
   Potrebno: Windows i telefon.

### Practise — Practise — ostalo

1. [ ] **Isti panel stabla radi i u Analizi.** [70.9]
   O čemu se radi: Panel stabla koji koristi izgradnja repertoara je deljen sa
   Analizom; treba proveriti da mu zaglavlje izgleda normalno i tamo, na
   širokom prozoru.
   Gde: `Analyse` → (otvoriti analizu partije sa varijantama).
   Uradi: Otvoriti Analizu na širokom prozoru sa partijom koja ima varijante,
   pogledati panel stabla.
   Treba da vidiš: Zaglavlje i prikaz panela stabla u Analizi izgledaju
   normalno, bez preliva.
   Potrebno: Windows; server.

2. [ ] **Practise je stari hub bez trake Resume, sa linijama napretka.**
   [177.3]
   O čemu se radi: Traka „Resume“ je prešla na Home; Practise zadržava naslov i
   kartice sa linijama napretka iz stavke 176.
   Gde: Practise (naslov `Practise`).
   Uradi: Otvori Practise sa nekim rešenim i nekim promašenim zagonetkama.
   Treba da vidiš: Naslov taba je `Practise`, nigde na tabu nema trake
   „Resume“, kartice pokazuju linije napretka (npr. „Solved N · M to retry“).
   Potrebno: Windows i telefon.

3. [ ] **Tab Practise ima jedan naslov, ne dva.** [46.b1781]
   O čemu se radi: Nekadašnji "Trening" tab (danas Practise, isti ekran) je
   nekad crtao i sopstveni gornja traka i naslov iz školjke; ugrađen u tab
   treba da pokaže samo jedan naslov.
   Gde: `Practise`.
   Uradi: Otvori tab `Practise` i pogledaj vrh ekrana.
   Treba da vidiš: Na vrhu stoji tačno jedan naslov "Practise", ne dva reda
   jedan iznad drugog.
   Potrebno: Windows i telefon.

4. [ ] **Ekrani bez strelica imaju samo dugme za koordinate, ni jedan prekidač
   strelica.** [93.1]
   O čemu se radi: Stavka je o meniju na tabli, ne o motoru: na ekranima koji
   ne crtaju strelice (reprodukcija, taktika, završnice, šetnja kroz greške,
   zadaci i domaći, ponavljanje, nov repertoar) meni na tabli nudi samo
   `Coordinates`, bez tri prekidača za strelice. Analysis, sesija i izgradnja
   repertoara crtaju strelice i imaju svoje stavke.
   Gde: `Practise`/`Analyse`/`Teach` → (svaki od nabrojanih ekrana) → (ikonica
   table, gore desno).
   Uradi: Prođi redom kroz replay, taktiku, završnice, blunder-šetnju, zadatak
   (domaći ili sopstveni), pregled odigrane partije i novi repertoar. Na svakom
   otvori meni na tabli (ikonica gore desno). Ako neki od tih ekrana pokreće
   partiju/vežbu protiv motora („igra") pod drugim imenom, uključi i njega u
   proveru.
   Treba da vidiš: Na svakom od ovih ekrana meni nudi samo `Coordinates` i ne
   crtaju se strelice motora. Ako se na nekom od njih ipak vide strelice motora
   bez načina da se sklone, zapiši koji je to ekran — to je nalaz.
   Potrebno: Windows i telefon; server.

## Analyse

### Analyse — Pregled partije (Review entire game)

1. [ ] **Bez lokalnih tabela, pregled pada nazad na Lichess bez greške.**
   [244.3]
   O čemu se radi: Kad lokalni tablebase server nije pokrenut, pregled partije
   se svejedno završava normalno — server prepoznaje da lokalne tabele ne
   odgovaraju i vraća se na Lichess za svaku poziciju sa 5 figura i manje.
   Gde: `Analyse` → ista partija kao malopre → `Review entire game`.
   Uradi: Zatvori terminal tab sa lokalnim tablebase serverom (pokreni.ps1 [5])
   i ponovi isti pregled partije.
   Treba da vidiš: Pregled se završi normalno (bez greške ili zastoja); u logu
   backenda se za svaku poziciju sa 5 figura i manje vidi red koji počinje sa
   `[TABLEBASE]` i pominje da lokalne tabele nisu odgovorile, pa se pita
   Lichess.
   Potrebno: server; internet; uvezene partije.

2. [ ] **Telefon takođe koristi server (a ne Lichess direktno) za tablebase.**
   [244.4]
   O čemu se radi: I na telefonu, pregled partije pita naš backend server za
   tablebase (koji dalje odlučuje lokalne tabele ili Lichess) — telefon nikad
   ne pita Lichess direktno.
   Gde: `Analyse` → uvezi/otvori istu partiju na telefonu, prijavljen na nalog
   → `Review entire game`.
   Uradi: Na telefonu, prijavljen na nalog, sa backendom dostupnim preko mreže,
   pokreni isti pregled partije.
   Treba da vidiš: U logu backend servera se vide upiti za te pozicije (server
   ih je primio i obradio); telefon sâm ne kontaktira Lichess.
   Potrebno: telefon; server; internet; tablebase (pokreni.ps1 [5]); uvezene
   partije.

3. [ ] **Kućica za AI komentare se pojavljuje tek uz Blunder Alert ili
   zagonetke.** [243.1]
   O čemu se radi: U dijalogu `Review entire game`, kućica
   `Comment key moments with AI` je sakrivena dok nije uključen bar jedan od
   `Blunder Alert` ili `Extract puzzles from detected blunders`; kad se pojavi,
   nije štiklirana.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Otvori `Review entire game` sa oba prekidača (Blunder Alert, Extract
   puzzles) isključenim, pa uključi jedan od njih.
   Treba da vidiš: Sa oba isključena, kućica `Comment key moments with AI` se
   ne vidi. Čim se uključi bar jedan, kućica se pojavljuje neštiklirana.
   Potrebno: Windows; uvezene partije.

4. [ ] **AI komentari na pravim mestima: greška, bolji potez, pobijanje.**
   [243.2]
   O čemu se radi: Uz uključen `Blunder Alert` i kućicu
   `Comment key moments with AI`, na kraju piše „Wrote N AI comments.“; na
   potezu sa `??` je rečenica, na liniji „Better move“ piše „Better move. …“, a
   posle poteza-greške postoji i linija „Refutation. …“ (ili je rečenica na
   samom potezu ako je odgovor motora baš odigran potez).
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Uvezi partiju sa jasnom greškom (najbolje pravu partiju sa online
   sata, sa `%clk` u potezima), uključi `Blunder Alert` i
   `Comment key moments with AI`, pokreni pregled.
   Treba da vidiš: Rezultat javlja „Wrote N AI comment(s).“ sa N > 0. Na potezu
   obeleženom `??` postoji komentar; linija „Better move“ ima komentar koji
   počinje sa „Better move.“; ako motorov odgovor nije baš odigrani potez,
   postoji i posebna linija „Refutation.“ sa svojim komentarom. Na potezu koji
   je bio jedini dobar i nađen postoji komentar bez oznake greške.
   Potrebno: Windows; uvezene partije; DeepSeek ključ na serveru; internet.

5. [ ] **Sopstveni komentar na potezu ostaje posle AI pregleda.** [243.3]
   O čemu se radi: Ako trener ručno napiše komentar na potez koji će pregled
   kasnije označiti, taj komentar mora ostati nepromenjen posle pregleda sa
   uključenom AI kućicom.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Napiši svoj komentar na potez za koji znaš da će biti označen (npr.
   greška), pa pokreni `Review entire game` sa `Comment key moments with AI`
   uključenim.
   Treba da vidiš: Posle pregleda, komentar na tom potezu je isti tekst koji si
   upisao — AI ga nije prepisao niti dopisao.
   Potrebno: Windows; uvezene partije; DeepSeek ključ na serveru; internet.

6. [ ] **Nijedan AI komentar ne pominje potez kog nema na tabli.** [243.4]
   O čemu se radi: Svaki napisani komentar sme da imenuje samo poteze koji su
   zaista u partiji ili u prikazanim linijama pored tog poteza; komentar koji
   bi imenovao izmišljen potez se odbija, a broj odbačenih se javlja u
   rezultatu.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Pokreni pregled sa AI komentarima na partiji sa nekoliko grešaka i
   pročitaj sve napisane komentare.
   Treba da vidiš: Nijedan komentar ne pominje potez koji nije odigran niti se
   nalazi u prikazanim linijama tog momenta. Ako je nešto odbijeno, rezultat
   javlja „N comment(s) left out: …“ sa razlogom.
   Potrebno: Windows; uvezene partije; DeepSeek ključ na serveru; internet.

7. [ ] **Bez pro naloga ili servera, oznake i zagonetke rade, AI komentari
   ne.** [243.6]
   O čemu se radi: Na nalogu bez Premium plana (ili sa ugašenim serverom), isti
   pregled i dalje stavlja `??` oznake i pravi zagonetke, ali javlja „No AI
   comments were written: …“ sa razlogom. Bez štiklirane kućice se AI uopšte ne
   pita (nema poziva u logu servera).
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Pokreni pregled sa AI kućicom uključenom na nalogu bez Premium plana.
   Zatim, odvojeno, pokreni pregled bez AI kućice i pogledaj log servera.
   Treba da vidiš: Bez Premium plana: oznake `??` i zagonetke i dalje nastaju,
   a rezultat javlja „No AI comments were written: …“ sa razlogom. Bez
   štiklirane kućice, u logu servera nema reda sa `[REVIEW-WORDS]`.
   Potrebno: Windows; uvezene partije.

8. [ ] **Nove zagonetke iz pregleda nose linije, stare ne.** [242.1]
   O čemu se radi: Zagonetke sačuvane preko `Review entire game` (sa uključenim
   zagonetkama) posle odgovora prikazuju linije umesto samo
   `Correct`/`Not quite`; zagonetke sačuvane pre ove promene ostaju na starom,
   jednostavnom prikazu.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Pokreni `Review entire game` sa zagonetkama na partiji sa greškom i
   sačuvaj dve zagonetke.
   Treba da vidiš: Zagonetke se uspešno sačuvaju (potvrda sa brojem sačuvanih).
   Za poređenje, otvori i neku stariju sačuvanu zagonetku (sačuvanu pre ove
   promene) — ona i dalje pokazuje samo `Correct`/`Not quite`.
   Potrebno: Windows; uvezene partije; internet.

9. [ ] **Izbor strane važi i za izdvajanje zagonetki.** [241.1]
   O čemu se radi: U `Review entire game`, uz uključeno samo
   `Extract puzzles from detected blunders…` (bez Blunder Alert-a), nudi se
   izbor `Both`/`White`/`Black`; izabrana strana ograničava koje se zagonetke
   izvlače.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Otvori `Review entire game`, uključi samo zagonetke (Blunder Alert
   isključen), izaberi svoju boju i pokreni pregled.
   Treba da vidiš: Ponuđen je izbor `Both`/`White`/`Black`. Sa izabranom svojom
   bojom, sve nađene zagonetke su na potezima koje si ti odigrao.
   Potrebno: Windows; uvezene partije.

10. [ ] **Lista posle pregleda pokazuje poziciju pre greške.** [241.2]
   O čemu se radi: U listi nađenih zagonetki posle pregleda, sličica prikazuje
   poziciju **pre** odigranog lošeg poteza, red imenuje potez i izgubljene
   šanse (npr. „23. Qe7 · lost N“), i pokazuje `Answer: …`.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Pokreni pregled sa zagonetkama i pogledaj listu nađenih zagonetki
   (panel za čuvanje) posle završetka.
   Treba da vidiš: Sličica svakog reda prikazuje poziciju pre pogrešnog poteza
   (ne posle), red ima oblik „<potez> · lost <broj>“ i ispod stoji `Answer: …`.
   Potrebno: Windows; uvezene partije.

11. [ ] **Izvučene zagonetke imaju jedan jasno najbolji potez.** [241.3]
   O čemu se radi: Otkako se zagonetke biraju po pravilu iz pregleda partije,
   ima ih manje nego ranije, ali svaka ima jedan potez koji se jasno izdvaja
   kao odgovor — ne jedan od nekoliko podjednako dobrih.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Pokreni pregled sa zagonetkama i otvori bar dve nađene zagonetke
   (npr. u Biblioteci posle čuvanja).
   Treba da vidiš: U obe zagonetke, odgovor je jedan potez koji se jasno
   izdvaja po vrednosti — ne jedan od više podjednako dobrih poteza.
   Potrebno: Windows; uvezene partije.

12. [ ] **Jedini pronađeni potezi su odvojeni pod svojim naslovom.** [241.4]
   O čemu se radi: Zagonetke gde je igrač našao jedini dobar potez (ne greška)
   su grupisane pod naslovom `Only moves the player found`, bez kvačice po
   podrazumevanom; `Keep` broji samo one koje su ostale označene.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Pokreni pregled na partiji koja ima i grešku i moment sa jedinim
   dobrim potezom; pogledaj listu nađenih zagonetki.
   Treba da vidiš: Postoji odeljak `Only moves the player found` sa stavkama
   koje po podrazumevanom nisu štiklirane. Dugme `Keep …` broji samo trenutno
   označene stavke (iz oba odeljka).
   Potrebno: Windows; uvezene partije.

13. [ ] **Čista partija javlja da nema zagonetki.** [241.6]
   O čemu se radi: Pregled partije bez ijedne greške ili jedinog poteza, sa
   uključenim zagonetkama, završava se porukom da nijedna zagonetka nije
   nađena.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Pokreni pregled sa uključenim zagonetkama na partiji za koju znaš da
   nema grešaka na izabranoj dubini.
   Treba da vidiš: Rezultat pregleda sadrži rečenicu
   `No puzzle found in this game.`.
   Potrebno: Windows; uvezene partije.

14. [ ] **Pregled sa zagonetkama traje nešto duže nego bez njih.** [241.7]
   O čemu se radi: Traženje zagonetki dodaje po jednu dodatnu pretragu motora
   za svaki potez koji je igrač našao (jedini potez), pa pregled sa uključenim
   zagonetkama treba da traje malo duže nego isti pregled bez njih.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Na telefonu, na istoj partiji, pokreni pregled dva puta na istoj
   dubini: jednom bez zagonetki, jednom sa uključenim
   `Extract puzzles from detected blunders…`. Zabeleži oba vremena.
   Treba da vidiš: Vreme sa uključenim zagonetkama je malo duže od vremena bez
   njih (razlika u redu veličine jedne dodatne pretrage po pronađenom jedinom
   potezu).
   Potrebno: telefon; uvezene partije.

15. [ ] **Klizač za prag u pešacima je uklonjen iz pregleda partije.** [240.1]
   O čemu se radi: Otkako pregled bira greške po pravilu (ne po pragu u
   pešacima), dijalog `Review entire game` više nema klizač „Blunder threshold:
   N pawns“.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Otvori dijalog `Review entire game` i pregledaj sve kontrole u njemu.
   Treba da vidiš: Nigde u dijalogu ne postoji klizač oblika „Blunder
   threshold: N pawns“.
   Potrebno: Windows; uvezene partije.

16. [ ] **Zatvaranje prozora ne prekida pregled u toku.** [240.2]
   O čemu se radi: Pregled partije nastavlja u pozadini i posle zatvaranja
   dijaloga (dugme za zatvaranje dok radi) ili prelaska na drugi ekran/tab; po
   završetku iskače poruka, gde god korisnik bio.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Pokreni pregled sa uključenim Blunder Alert-om, pa zatvori dijalog
   dugmetom za zatvaranje dok pregled još radi. Pređi na drugi tab ili ekran
   dok se ne završi.
   Treba da vidiš: Bez obzira gde se korisnik nalazi kad se pregled završi, na
   dnu ekrana iskače poruka koja počinje sa `Game review done`; kad se partija
   ponovo otvori u Analizi, `??` oznake su upisane.
   Potrebno: Windows; uvezene partije.

17. [ ] **Ponovno otvaranje dijaloga tokom rada pokazuje isti napredak.**
   [240.3]
   O čemu se radi: Ako se `Review entire game` ponovo otvori dok pregled još
   radi, pokazuje se napredak (faza rečima i traka), ne početna podešavanja;
   posle završetka rezultat ostaje prikazan dok se ne pritisne `Close`, a
   zagonetke se čuvaju iz tog prikaza.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Pokreni pregled, zatvori dijalog, pa ga tokom rada ponovo otvori
   preko `Review entire game`.
   Treba da vidiš: Dijalog se ponovo otvara na ekranu napretka (faza i traka),
   ne na podešavanjima. Posle završetka, rezultat ostaje prikazan dok se ne
   pritisne `Close`; ako je bilo nađenih zagonetki, mogu se sačuvati odatle.
   Potrebno: Windows; uvezene partije.

18. [ ] **Rezultat pregleda navodi dubinu, broj oznaka i nepresuđene poteze.**
   [240.4]
   O čemu se radi: Na kraju pregleda piše na kojoj dubini pregled stoji, koliko
   je pozicija označeno, koliko poteza nije presuđeno ili smireno (ako ih ima)
   i koliko odgovora je iskorišćeno iz ranijih pretraga; na čistoj partiji piše
   da nije nađena greška na toj dubini.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Pokreni pregled do kraja na partiji sa greškama, pročitaj rezultat.
   Ponovi (drugi put) isti pregled da vidiš broj odgovora iz ranijih pretraga.
   Probaj i na partiji bez greške.
   Treba da vidiš: Rezultat navodi dubinu pregleda, broj označenih grešaka, i
   (ako ih ima) broj poteza koji nisu presuđeni/smireni; pri drugom pokretanju
   navodi i broj odgovora preuzetih iz ranijih pretraga. Bez greške: rečenica
   oblika `No mistake found at depth ….`.
   Potrebno: Windows; uvezene partije.

19. [ ] **Šetnja između tabova tokom pregleda ne kvari rezultat.** [240.6]
   O čemu se radi: Prelazak na drugi tab i nazad, više puta, dok pregled radi u
   pozadini, ne sme da poveća broj nepresuđenih poteza u odnosu na isti pregled
   bez šetnje.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Pokreni pregled, pa nekoliko puta pređi na drugi tab i nazad na
   Analyse dok pregled traje. Uporedi rezultat (broj oznaka, broj nepresuđenih)
   sa istim pregledom pokrenutim bez šetnje po tabovima.
   Treba da vidiš: Na kraju su `??` oznake upisane kao i inače, a broj „nije
   presuđeno“ se ne razlikuje (nije veći) u odnosu na pregled bez šetnje.
   Potrebno: Windows; uvezene partije.

20. [ ] **Cancel zaista prekida pregled, bez oznaka i poruke.** [240.7]
   O čemu se radi: Dugme `Cancel` u dijalogu napretka zatvara pregled; posle
   par sekundi motor je slobodan, u partiji nema oznaka i ne javlja se poruka o
   završetku.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Pokreni pregled i, dok radi, pritisni `Cancel`. Sačekaj par sekundi i
   proveri partiju i eventualnu poruku.
   Treba da vidiš: Nema `??` oznaka u partiji i ne pojavljuje se poruka
   `Game review done`. Motor je posle par sekundi ponovo slobodan (npr. Analiza
   ga može koristiti).
   Potrebno: Windows; uvezene partije.

21. [ ] **Promena partije usred pregleda upozorava i ne upisuje oznake.**
   [240.8]
   O čemu se radi: Ako se pregled pokrene, dijalog zatvori, pa se u Analizu
   učita druga partija dok pregled prve još radi, rezultat po završetku
   upozorava da se partija promenila i da oznake nisu upisane; nova partija
   ostaje netaknuta.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Pokreni pregled na partiji A, zatvori dijalog dok radi, pa u Analizu
   učitaj drugu partiju B (npr. novi uvoz).
   Treba da vidiš: Kad se pregled partije A završi, poruka/rezultat upozorava
   da se partija u međuvremenu promenila i da oznake nisu upisane; partija B na
   ekranu ostaje bez `??` oznaka iz tog pregleda.
   Potrebno: Windows; uvezene partije.

22. [ ] **Odjava usred pregleda ne upisuje ništa.** [240.9]
   O čemu se radi: Ako se korisnik odjavi dok pregled radi u pozadini, po
   prijavi (na isti ili drugi nalog) nema poruke o završetku pregleda niti
   oznaka upisanih u nacrt partije.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Pokreni pregled, zatvori dijalog, odjavi se dok pregled još radi
   (Settings → Log out), pa se prijavi ponovo (na isti ili drugi nalog).
   Treba da vidiš: Nema poruke `Game review done` posle prijave, i partija u
   nacrtu nema `??` oznaka iz tog pregleda.
   Potrebno: Windows; nalog trenera i učenika.

23. [ ] **Ponovljeni pregled iste partije, iste dubine, je brz.** [239.1]
   O čemu se radi: Odgovori motora se čuvaju lokalno po nalogu i dubini
   (sačuvane ocene motora), pa ponovljeni pregled iste partije na istoj dubini
   treba da bude znatno brži nego prvi put.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Pokreni `Review entire game` (Blunder Alert uključen) na jednoj
   partiji i zapamti trajanje. Odmah zatim pokreni isti pregled ponovo, na
   istoj partiji i istoj dubini.
   Treba da vidiš: Drugi pregled se završava za nekoliko sekundi (znatno brže
   od prvog) i daje iste `??` oznake kao prvi put.
   Potrebno: Windows; uvezene partije.

24. [ ] **Brzina ponovljenog pregleda preživljava restart aplikacije.** [239.2]
   O čemu se radi: Sačuvani odgovori motora su na disku, ne samo u memoriji —
   pregled ostaje brz i posle potpunog gašenja i ponovnog pokretanja
   aplikacije.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Posle prethodne provere, potpuno zatvori aplikaciju, ponovo je
   pokreni, i ponovi isti pregled iste partije na istoj dubini.
   Treba da vidiš: Pregled je i dalje brz (nekoliko sekundi), kao pre gašenja
   aplikacije.
   Potrebno: Windows; uvezene partije.

25. [ ] **Dublji sačuvan odgovor služi plićem pitanju, ne obrnuto.** [239.3]
   O čemu se radi: Pregled na dubini 20 posle pregleda iste partije na dubini
   22 treba da bude brz (dublji odgovor iz keša služi plićem pitanju); obrnuti
   redosled (22 posle 20) ne može da koristi keš i traje kao prvi put.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Pokreni pregled na dubini 22, pa isti pregled iste partije na dubini
   20. Zatim, na drugoj partiji, pokreni prvo dubinu 20 pa dubinu 22.
   Treba da vidiš: 20 posle 22 je brzo (koristi već sačuvane, dublje odgovore).
   22 posle 20 traje otprilike koliko i prvi, „hladan“ pregled (ne može da
   iskoristi plići keš).
   Potrebno: Windows; uvezene partije.

26. [ ] **Odjava briše lokalno sačuvane odgovore motora.** [239.4]
   O čemu se radi: Kad se korisnik odjavi (i prijavi ponovo, na isti ili drugi
   nalog), lokalno sačuvani odgovori motora se brišu — ponovljeni pregled iste
   partije traje ponovo koliko i prvi put.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Pokreni pregled da napuniš keš, pa se odjavi i ponovo prijavi
   (Settings → Log out, pa prijava).
   Treba da vidiš: Isti pregled iste partije, na istoj dubini, posle
   odjave/prijave traje ponovo kao prvi put (nije ubrzan).
   Potrebno: Windows; nalog trenera i učenika.

27. [ ] **Bez izabranog prekidača, pregled se ne može pokrenuti.** [238.1]
   O čemu se radi: Kad su i `Blunder Alert` i
   `Extract puzzles from detected blunders…` isključeni, dugme `Start analysis`
   je ugašeno i iznad njega piše zašto.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Otvori `Review entire game` i ostavi oba prekidača (Blunder Alert,
   Extract puzzles) isključena.
   Treba da vidiš: Dugme `Start analysis` je sivo (neaktivno) i iznad njega
   piše rečenica koja počinje sa `Turn on Blunder Alert or puzzles` i
   objašnjava da bez ijednog od njih pregled nema šta da pokaže.
   Potrebno: Windows; uvezene partije.

28. [ ] **Jedan uključen prekidač je dovoljan za start.** [238.2]
   O čemu se radi: Čim se uključi samo jedan od dva prekidača (Blunder Alert
   ili Extract puzzles), dugme `Start analysis` postaje aktivno i upozoravajuća
   rečenica nestaje.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Uključi samo `Blunder Alert` (ili samo
   `Extract puzzles from detected blunders…`) i pogledaj dugme `Start analysis`
   i tekst iznad njega.
   Treba da vidiš: Dugme `Start analysis` postaje aktivno (može se pritisnuti),
   a upozoravajuća rečenica o tome da nema šta da se pokaže nestaje.
   Potrebno: Windows; uvezene partije.

29. [ ] **Uvodni tekst ne obećava komentare pod potezima.** [238.3]
   O čemu se radi: Uvodna rečenica dijaloga jasno kaže da pregled ne piše
   komentar ispod svakog poteza i upućuje na `Generate AI comment` za to.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Otvori `Review entire game` i pročitaj uvodni tekst na vrhu dijaloga.
   Treba da vidiš: Tekst kaže da ovaj pregled ne piše komentar pod svaki potez
   i pominje `Generate AI comment` kao alatku za to (odvojenu, po potezu).
   Potrebno: Windows.

30. [ ] **Rezultat kaže koliko je pregledano i koliko je označeno.** [238.4]
   O čemu se radi: Posle pregleda, rezultat javlja
   `Done — reviewed N positions.` i `Tagged N blunders.`, a u partiji su `??`
   oznake tačno na tim potezima.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Pokreni pregled sa Blunder Alert-om na partiji sa bar jednom greškom,
   sačekaj kraj.
   Treba da vidiš: Rezultat sadrži rečenice `Done — reviewed … positions.` i
   `Marked … mistakes.` sa brojevima većim od nule; partija u Analizi ima `??`
   oznake tačno na tim potezima.
   Potrebno: Windows; uvezene partije.

31. [ ] **I poslednji potez partije kao greška dobija odgovor ili jasan
   otkaz.** [234.4]
   O čemu se radi: Kad je greška baš na poslednjem potezu partije, motor se
   pita još jednom za odgovor na toj poziciji; ako ne može da ga nađe,
   zagonetka se ne pravi i javlja se razlog.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`.
   Uradi: Pokreni pregled sa zagonetkama na partiji čija je poslednja odigrana
   greška baš poslednji potez partije.
   Treba da vidiš: Ta zagonetka ili dobija normalan odgovor (kao svaka druga),
   ili se, ako motor ne može da nađe odgovor, javlja poruka servera da odgovor
   nije nađen i da se stavka ne može sačuvati — i ta zagonetka se ne nudi za
   čuvanje.
   Potrebno: Windows; uvezene partije.

32. [ ] **Pregled cele partije i dalje piše komentare i NAG.** [103.14]
   O čemu se radi: Brisanje ocene sa čvorova nije dirnulo automatski pregled
   partije (`Review entire game`) — greške i dalje dobijaju komentar i NAG
   oznaku, samo bez broja na kartici.
   Gde: `Analyse` → alatnica → `Review entire game`.
   Uradi: Pusti `Review entire game` na partiji sa bar jednom greškom (uključi
   `Blunder Alert` u dijalogu) i pogledaj obeležene poteze u stablu posle.
   Treba da vidiš: Greške u liniji dobijaju komentar i NAG oznaku (npr. `?`) na
   kartici, isto kao pre — jedino broj u zagradi i dalje ne postoji.
   Potrebno: Windows i telefon.

33. [ ] **Pregled partije koristi lokalni tablebase za 5 figura i manje.**
   [244.2]
   O čemu se radi: U pregledu partije („Review entire game“ sa Blunder Alert),
   pozicije sa 6-7 figura i dalje idu na Lichess (sporije), a sa 5 figura i
   manje se pitaju lokalne tabele, što ubrzava taj deo pregleda.
   Gde: `Analyse` → uvezi partiju sa dugom završnicom (malo figura) →
   `Review entire game` → uključi `Blunder Alert`.
   Uradi: Pokreni pregled uz uključen lokalni tablebase server (pokreni.ps1
   [5]) na sopstvenoj partiji koja ide do završnice sa malo figura, i posmatraj
   log backend servera.
   Treba da vidiš: U logu backenda se za pozicije sa 6-7 figura vidi pitanje ka
   Lichess-u (sporije, otprilike jedna pozicija u sekundi); za pozicije sa 5 i
   manje figura nema traga poziva ka Lichess-u, a taj deo pregleda je primetno
   brži nego pre uvođenja lokalnog tablebase-a.
   Potrebno: Windows; tablebase (pokreni.ps1 [5]); internet; uvezene partije.

34. [ ] **Motor javlja da je zauzet pregledom, na svakom ekranu koji ga
   koristi.** [240.5]
   O čemu se radi: Dok pregled radi, engine panel u Analizi pokazuje da je
   motor zauzet pregledom partije (prekidač i dalje radi kao kontrola), a na
   drugom ekranu koji koristi motor (npr. igra protiv računara) jednom iskače
   poruka o zauzetosti; kad se pregled završi, Analiza ponovo sama računa.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`; dok
   pregled radi, otvori i `Engine analysis panel` u Analizi (drugi tab), i,
   odvojeno, ekran igre protiv motora.
   Uradi: Pokreni pregled, pa u Analizi (drugi tab/prozor) uključi engine
   analizu. Zatim otvori i ekran gde se igra protiv motora.
   Treba da vidiš: Iznad engine panela u Analizi piše
   `The engine is busy with the game review.`, a prekidač ostaje uključen (samo
   neaktivan). Na ekranu igre protiv motora se jednom pojavi poruka da je motor
   zauzet pregledom. Posle završetka pregleda, Analiza ponovo sama računa
   poziciju.
   Potrebno: Windows; uvezene partije; debug build.

35. [ ] **Sačuvana zagonetka iz pregleda nosi objašnjenje.** [243.5]
   O čemu se radi: Kad se uz AI kućicu koristi
   `Extract puzzles from detected blunders`, sačuvana zagonetka posle rešavanja
   prikazuje rečenicu objašnjenja iznad prikazanih linija.
   Gde: `Analyse` → otvori/uvezi partiju → alatka `Review entire game`; zatim
   `Practise` → `Tactics tailored to you` / `Library` → `Exercises`.
   Uradi: Pokreni pregled sa `Extract puzzles from detected blunders` i
   `Comment key moments with AI` uključenim, sačuvaj jednu zagonetku dugmetom
   za čuvanje (Keep N as an exercise), pa je reši u Biblioteci.
   Treba da vidiš: Posle odigranog poteza, iznad prikazanih linija stoji
   rečenica objašnjenja (AI komentar), ne samo `Correct`/`Not quite`.
   Potrebno: Windows; uvezene partije; DeepSeek ključ na serveru; internet.

36. [ ] **Tutorijal uči iste greške koje „Review entire game“ označi sa ??**
   [245.4]
   O čemu se radi: Tutorijal i pregled partije koriste isto pravilo za grešku,
   pa potezi koje pregled označi sa ?? treba da budu upravo oni koje tutorijal
   uči (najviše 8 momenata po tutorijalu).
   Gde: `Analyse` → otvori istu partiju → prvo `Use in a tutorial` →
   `New tutorial from this game`, zatim (posebno) `Review entire game`.
   Uradi: Na istoj partiji napravi tutorijal (zapamti koje poteze uči) i,
   odvojeno, pokreni `Review entire game` sa uključenim Blunder Alert-om na
   istoj dubini.
   Treba da vidiš: Potezi koje pregled označi sa `??` odgovaraju potezima koje
   tutorijal uči kao „mistake“ momente (do najviše 8 — ako partija ima više
   grešaka, tutorijal uzima 8 najskupljih po izgubljenim šansama).
   Potrebno: Windows; uvezene partije.

### Analyse — Tutorijal iz partije

1. [ ] **Vrata za korak su sada jedno dugme.** [108.17]
   O čemu se radi: Stara dva odvojena dugmeta pored „Export PGN” („Napravi
   korak od ove pozicije” i „Uredi korake lekcije”) su spojena u jedno dugme
   `Use in a tutorial` koje otvara list sa svim opcijama; „Review entire game”
   ostaje svoje posebno dugme u traci i na uskom prozoru ide u meni tek posle
   njega, ne pre.
   Gde: `Analyse` → alatnica → `Use in a tutorial`.
   Uradi: Otvori `Use in a tutorial` u alatnici Analysis Studija na poziciji sa
   linijom. Proveri i na telefonu da `Review entire game` ostaje vidljivo dugme
   u traci (prvo od dva koja ne idu u meni), ne u meniju `More tools`.
   Treba da vidiš: List nudi „Add this position to a tutorial…” i „Open a
   tutorial to edit…” (i još tri opcije za nov tutorijal). Na telefonu
   `Setup Position / PGN` i `Review entire game` ostaju direktno na traci;
   ostatak (uključujući `Use in a tutorial`) ide u meni `More tools`.
   Potrebno: Windows i telefon.

2. [ ] **Prvi dijalog: dubina bez klizača pragova, pamti se.** [161.2, 245.1]
   O čemu se radi: Od 25.9.2026 dijalog `Make a tutorial from this game` više
   nema klizač „Teach a move that cost X pawns“ — samo dubinu pretrage, koja
   sada počinje na 20 (ranije 18), sa procenom vremena pored nje, i pamti se za
   sledeći put.
   Gde: `Analyse` → otvori partiju na tabli → alatka `Use in a tutorial` →
   `New tutorial from this game`.
   Uradi: Otvori dijalog `Make a tutorial from this game`. Izaberi drugu dubinu
   klizačem, zatvori dijalog (`Cancel`), pa ga ponovo otvori.
   Treba da vidiš: Nema klizača za prag u pešacima. Dijalog otvara na dubini 20
   prvi put; posle promene i ponovnog otvaranja pamti poslednje izabranu
   dubinu, sa vremenom pored nje.
   Potrebno: Windows; uvezene partije.

3. [ ] **Tok pretrage pominje pravilo pregleda partije.** [245.2]
   O čemu se radi: Posle faze pretrage motora, korak napretka prelazi na tekst
   „Checking which moves are mistakes, the way a game review does.“ — jer
   tutorijal sada bira momente istim pravilom kao „Review entire game“, ne
   pragom u pešacima.
   Gde: `Analyse` → otvori partiju na tabli → alatka `Use in a tutorial` →
   `New tutorial from this game`.
   Uradi: Pokreni izradu tutorijala i posmatraj tekst faze u dijalogu
   `Making the tutorial` nakon što pretraga motora završi.
   Treba da vidiš: Vidi se rečenica „Checking which moves are mistakes, the way
   a game review does.“ pre nego što se pojavi dijalog `What the engine found`.
   Potrebno: Windows; uvezene partije.

4. [ ] **Drugi dijalog javlja broj grešaka i jedinih poteza, bez klizača.**
   [245.3]
   O čemu se radi: Dijalog `What the engine found` kaže koliko je grešaka i
   „only one move held“ momenata nađeno i koliko od njih postaje delova
   tutorijala; na partiji bez ijednog takvog momenta piše da nema šta da se uči
   na toj dubini i dugme za pisanje je ugašeno.
   Gde: `Analyse` → otvori partiju na tabli → alatka `Use in a tutorial` →
   `New tutorial from this game`.
   Uradi: Dovrši pretragu na partiji sa greškama i pogledaj dijalog
   `What the engine found`. Ponovi na (skoro) čistoj partiji bez grešaka.
   Treba da vidiš: Sa greškama: rečenica oblika „N mistakes and M moves where
   only one move held.“, bez klizača. Bez grešaka: rečenica „Nothing to teach
   from at depth 20.“ (ili druga izabrana dubina) i dugme `Write the tutorial`
   je ugašeno.
   Potrebno: Windows; uvezene partije.

5. [ ] **Deo o jedinom potezu nikad ne kaže da ga partija nije odigrala.**
   [245.5]
   O čemu se radi: Kada je jedini potez koji drži poziciju baš onaj koji je
   partija odigrala, deo pita „nađi potez“, a posle otkriva da je partija baš
   njega odigrala — formulacija „which the game did not play“ (rezervisana za
   greške) se tu nikad ne koristi.
   Gde: `Analyse` → otvori partiju na tabli → alatka `Use in a tutorial` →
   `New tutorial from this game`.
   Uradi: Napravi tutorijal od partije koja ima moment gde je igrač našao
   jedini dobar potez, i pregledaj taj deo (pitanje i odgovor).
   Treba da vidiš: Tekst kaže da je to jedini potez koji drži i da ga je
   partija odigrala („The game found it.“) — nigde se ne pojavljuje fraza da
   partija taj potez NIJE odigrala.
   Potrebno: Windows; uvezene partije.

6. [ ] **Dugme za tutorijal iz partije je tamo gde je partija.** [161.1]
   O čemu se radi: „Napravi tutorijal iz ove partije“ se pokreće iz Analyse
   trake preko `Use in a tutorial` → `New tutorial from this game`; na poziciji
   bez odigranih poteza red javlja da nema poteza i ništa se ne pokreće.
   Gde: `Analyse` → otvori partiju na tabli → alatka `Use in a tutorial` →
   `New tutorial from this game`.
   Uradi: Uvezi partiju u Analizu (Setup Position / PGN) i otvori
   `Use in a tutorial`. Zatim probaj isto na praznoj tabli (bez odigranih
   poteza).
   Treba da vidiš: Sa partijom se otvara dijalog
   `Make a tutorial from this game`. Bez poteza se umesto toga javlja poruka da
   nema poteza za tutorijal i ništa se ne pokreće.
   Potrebno: Windows; uvezene partije.

7. [ ] **Napredak analize govori istinu o vremenu.** [161.3]
   O čemu se radi: Tokom pretrage prikazuje se „N of M positions“ sa procenom
   preostalog vremena, koja se ne vraća unazad više od jednom-dvaput.
   Gde: `Analyse` → otvori partiju na tabli → alatka `Use in a tutorial` →
   `New tutorial from this game`.
   Uradi: Pokreni izradu tutorijala i posmatraj traku napretka tokom cele
   pretrage.
   Treba da vidiš: Broj pregledanih pozicija raste, a procena preostalog
   vremena se smanjuje uglavnom monotono — ne skače unazad više od
   jednom-dvaput. Ukupno vreme je u redu veličine minuta u skladu sa izabranom
   dubinom.
   Potrebno: Windows; uvezene partije.

8. [ ] **Na kraju se nude dva tutorijala, otvara se jedan.** [161.5]
   O čemu se radi: Posle pisanja rečenica nude se dve verzije: `Key moments`
   (samo momenti vredni učenja) i `Whole game` (cela partija sa tim momentima
   na svom mestu); obe se otvaraju u studiju, nesačuvane.
   Gde: `Analyse` → otvori partiju na tabli → alatka `Use in a tutorial` →
   `New tutorial from this game`.
   Uradi: Dovrši izradu tutorijala do kraja i pogledaj završni dijalog. Otvori
   jednu od dve ponuđene verzije.
   Treba da vidiš: Dijalog nudi `Key moments` i `Whole game` dugmad, svako sa
   brojem delova. Klik na jedno otvara taj tutorijal u studiju za uređivanje,
   nesačuvan. Ako je nešto navedeno pod „sentences to check“, lista je
   razumljiva i kratka.
   Potrebno: Windows; uvezene partije.

9. [ ] **Svako odbijanje izrade tutorijala je razumljiva rečenica.** [161.7]
   O čemu se radi: Kad se tutorijal ne može napraviti (nema motora, nalog nije
   pro/premium, nestane internet posle analize, računar ode u san usred nje),
   dijalog `No tutorial was made` / `A Premium feature` objašnjava zašto; bez
   motora nudi i dugme `Engine settings`.
   Gde: `Analyse` → otvori partiju na tabli → alatka `Use in a tutorial` →
   `New tutorial from this game`.
   Uradi: Ponovi pokušaj izrade tutorijala u četiri stanja: (a) bez preuzetog
   Stockfish-a, (b) na nalogu bez pro/premium plana, (c) prekini internet posle
   završene analize (u fazi pisanja reči), (d) pusti računar u stanje mirovanja
   usred pretrage pa ga probudi.
   Treba da vidiš: (a) Poruka o motoru sa dugmetom `Engine settings`. (b)
   Poruka o nadogradnji naloga. (c) Poruka o mreži, i broj preostalih
   tutorijala se ne menja (proveri pre/posle u Account statistics). (d) Posle
   buđenja računara pretraga nastavlja bez greške motora.
   Potrebno: Windows i telefon; debug build.

10. [ ] **Linija odgovora se ne završava usred žrtve.** [161.12]
   O čemu se radi: Kada najbolja linija nešto žrtvuje, prikaz linije se
   produžava (do granice od najviše 8 poteza) da ne stane na poziciji gde je
   onaj ko je žrtvovao još u minusu, osim ako se linija tu zaista završila.
   Gde: `Analyse` → otvori partiju na tabli → alatka `Use in a tutorial` →
   `New tutorial from this game`.
   Uradi: Napravi tutorijal od partije koja ima moment gde najbolja linija
   nešto daje (žrtvuje materijal), pa pregledaj taj deo (odgovor) u studiju.
   Treba da vidiš: Linija se ne prekida na poziciji gde je strana koja je
   žrtvovala i dalje u minusu bez vidljivog razloga — produžava se dok se
   nadoknada ne vidi (najviše 8 poteza), osim ako se prirodno tu i završava.
   Potrebno: Windows; uvezene partije.

11. [ ] **Rekapitulacija na kraju „Whole game“, ne u „Key moments“** [161.14]
   O čemu se radi: U tutorijalu `Whole game` poslednji deo počinje rečenicom
   „Looking back: the game turned on …“ i ponavlja liniju prelomnog momenta;
   taj deo ne postoji u `Key moments`.
   Gde: `Analyse` → otvori partiju na tabli → alatka `Use in a tutorial` →
   `New tutorial from this game`.
   Uradi: Napravi oba tutorijala (`Key moments` i `Whole game`) od iste partije
   i pregledaj poslednji deo svakog.
   Treba da vidiš: `Whole game` se završava delom čiji tekst počinje sa
   „Looking back: the game turned on“, sa linijom tog momenta ponovljenom.
   `Key moments` nema takav deo. Oceni i da li je označeni momenat zaista taj
   na kome se partija prelomila.
   Potrebno: Windows; uvezene partije.

12. [ ] **„The other line“ se javlja samo kad najbolji potez nešto žrtvuje.**
   [161.15]
   O čemu se radi: Kad najbolja linija nešto žrtvuje, posle dela sa odgovorom
   dodaje se poseban deo „the other line“ o drugom najboljem potezu i zašto je
   slabiji — kao zaseban deo, ne kao račvanje (varijanta) na tabli.
   Gde: `Analyse` → otvori partiju na tabli → alatka `Use in a tutorial` →
   `New tutorial from this game`.
   Uradi: Pregledaj nekoliko momenata (delova) u napravljenom tutorijalu i
   primeti kod kojih se posle odgovora javlja dodatni deo o „the other line“.
   Treba da vidiš: Deo „the other line“ se javlja samo kod momenata gde
   najbolja linija nešto žrtvuje (ređe od svakog momenta, ne svuda) i
   pojavljuje se kao poseban deo koji se prelistava dalje, a ne kao
   grananje/izbor na tabli unutar odgovora.
   Potrebno: Windows; uvezene partije.

13. [ ] **Novi delovi imaju napisane rečenice, ne gomilu upozorenja.** [161.16]
   O čemu se radi: Pošto su dodati novi slotovi (uvod pre momenta, „the other
   line“), proverava se da model u pravom pozivu ispiše sve ponuđene slotove —
   dijalog na kraju ne bi trebalo da prijavi mnogo stavki pod „sentences to
   check“.
   Gde: `Analyse` → otvori partiju na tabli → alatka `Use in a tutorial` →
   `New tutorial from this game`.
   Uradi: Dovrši izradu tutorijala do kraja i pogledaj listu pod „sentences to
   check“ u završnom dijalogu.
   Treba da vidiš: Lista je kratka ili prazna. Ako ima mnogo stavki (veći broj
   nedostajućih rečenica), to je nalaz vredan prijave.
   Potrebno: Windows; uvezene partije; DeepSeek ključ na serveru.

14. [ ] **Analiza ima jedna vrata ka tutorijalu — broj redova zavisi od
   pozicije.** [175.1]
   O čemu se radi: Ispravljeno u opisu 18.9.2026: broj redova ne zavisi od
   platforme (studio radi i na telefonu od faze 6c) nego od toga gde stoji
   kursor — na praznoj tabli su tri reda, usred linije šest.
   Gde: Analyse → `Use in a tutorial`.
   Uradi: Na telefonu (360 dp) stani na potez usred neke linije i otvori
   `Use in a tutorial`. Zatim probaj isto na praznoj početnoj tabli.
   Treba da vidiš: Usred linije se vidi svih šest redova
   (`New tutorial from this position`, `New tutorial from this line`,
   `New tutorial from this game`, `Add this position to a tutorial…`,
   `Add this line to a tutorial…`, `Open a tutorial to edit…`), lista se
   skroluje bez prelivanja. Na praznoj tabli ostaju samo tri (position/add
   position/edit).
   Potrebno: telefon.

15. [ ] **„Sentences to check“ lista je kratka ili prazna.** [162.6]
   O čemu se radi: Poslednji dijalog posle generisanja tutorijala nosi listu
   rečenica koje vredi ručno proveriti (nalaz automatske provere tvrdnji).
   Gde: Analyse → `Use in a tutorial` → `New tutorial from this game` →
   rezultat generisanja.
   Uradi: Generiši pripovedni tutorijal iz partije i pogledaj listu „Sentences
   to check“ u poslednjem dijalogu.
   Treba da vidiš: Lista je kratka ili prazna; ako nije prazna, svaka navedena
   rečenica zaista vredi ručne provere (nalaz o mogućoj netačnoj tvrdnji).
   Potrebno: Windows; DeepSeek ključ na serveru; internet.

16. [ ] **Dubina za tutorijal iz partije je klizač 18–50, ne tri izbora.**
   [180.9b]
   O čemu se radi: Umesto tri fiksna nivoa, dubina se sad bira klizačem 18–50;
   ispod broja piše izmereno vreme za 18/20/22, a iznad 22 piše „not measured“.
   Zapamćena vrednost se vraća sledeći put.
   Gde: Analyse → `Use in a tutorial` → `New tutorial from this game` →
   `Make a tutorial from this game`.
   Uradi: Otvori taj dijalog i pomeri klizač dubine preko celog opsega 18–50.
   Treba da vidiš: Ispod broja se za 18/20/22 vidi izmereno vreme, a za veće
   vrednosti „not measured“. Zatvori i ponovo otvori dijalog — poslednja dubina
   je zapamćena.
   Potrebno: Windows; debug build.

17. [ ] **Greška u priči ide redom: rečenica, plava strelica, pa najbolja
   linija.** [162.2]
   O čemu se radi: Vlasnikova napomena pri ovom pregledu: potez koji sledi
   posle „The best move was …“ se odigra na tabli ali se ne izgovara naglas,
   iako je rečenicom najavljen — ovo ostaje otvoreno i treba proveriti da li je
   i dalje tako.
   Gde: Analyse → `Use in a tutorial` → `New tutorial from this game` →
   `Make a tutorial from this game`.
   Uradi: Napravi pripovedni tutorijal iz partije sa bar jednom jasnom greškom
   (AI komentar priče, ne stari motiv-panel) i pusti ga do momenta greške;
   uporedi i sa izvezenim videom.
   Treba da vidiš: Na momentu greške: deo bez poteza kaže „In this position
   White played [potez]. The best move was…“ uz plavu strelicu tog poteza
   (potez se ne odigra), pa sledeći deo odigra najbolju liniju. Proveri da li
   se sam nastavak posle „The best move was…“ i dalje izgovara naglas dok se
   igra — vlasnik je ranije primetio da se ne izgovara, iako ga rečenica
   najavljuje.
   Potrebno: Windows; DeepSeek ključ na serveru; internet.

18. [ ] **Uvodna rečenica ne otkriva pobednika, poslednja kaže ko je pobedio i
   zašto.** [162.3]
   O čemu se radi: Vlasnikovo otvoreno pitanje pri ovom pregledu: kad se u
   priču ubaci partija (studija) koja nije igrana do kraja i nema jasan
   rezultat, nije jasno na osnovu čega tutorijal ipak izjavljuje pobednika —
   proveri to posebno.
   Gde: Analyse → `Use in a tutorial` → `New tutorial from this game` →
   `Make a tutorial from this game`.
   Uradi: Napravi pripovedni tutorijal iz partije koja ima jasan rezultat (mat
   ili predaja) i pusti ga od početka do kraja. Ponovi sa unetom
   studijom/linijom koja nije odigrana do kraja i nema upisan rezultat.
   Treba da vidiš: Prva rečenica opisuje kakva partija sledi (mirna/puna
   preokreta, taktička/poziciona) i ne otkriva pobednika; poslednja (na
   poslednjem potezu partije) kaže ko je pobedio i zašto, bez rečenice „The
   game ended here.“ Za studiju bez upisanog rezultata, proveri na osnovu čega
   (ili da li pogrešno) tutorijal ipak izjavljuje pobednika.
   Potrebno: Windows; DeepSeek ključ na serveru; internet.

19. [ ] **Rekapitulacija ne pominje cenu u pešacima.** [162.5]
   O čemu se radi: Poslednji deo tutorijala („Looking back, the game turned on
   …“) treba da objasni prekretnicu partije rečima, ne brojem izgubljenih
   pešaka, uz plavu strelicu odigranog poteza.
   Gde: Analyse → `Use in a tutorial` → `New tutorial from this game` →
   `Make a tutorial from this game`.
   Uradi: Pusti pripovedni tutorijal do poslednjeg dela, rekapitulacije.
   Treba da vidiš: Poslednji deo počinje sa „Looking back, the game turned on
   …“, ne pominje broj pešaka (cenu greške), i na tabli je plava strelica
   odigranog poteza.
   Potrebno: Windows; DeepSeek ključ na serveru; internet.

### Analyse — Choose a game

1. [ ] **Na telefonu, i u landscape modu, lista partija se vidi i skroluje.**
   [210.9]
   O čemu se radi: Dijalog „Choose a game“ na uskom ekranu prikazuje dve
   zbijene linije po partiji („Beli vs Crni“ sa rezultatom, pa datum i prvi
   potezi); pretraga i čipovi su iznad liste.
   Gde: `Analyse` → `Setup Position / PGN` → tab `PGN` → (izbor partije iz
   uvezenih) — ili `Library`/`My games` → izbor partije.
   Uradi: Na telefonu, u uspravnoj orijentaciji, otvori „Choose a game“ i
   proveri listu. Zatim okreni telefon u landscape (položeno) i proveri ponovo.
   Treba da vidiš: U oba položaja telefona lista partija je vidljiva i skroluje
   se; ništa nije odsečeno niti visine 0 (redova ima bar nekoliko na ekranu i u
   landscape položaju).
   Potrebno: telefon; uvezene partije; telefon položeno.

2. [ ] **Polje za pretragu i dalje namerno ignoriše datum i rezultat; poseban
   filter po rezultatu postoji.** [203.5]
   O čemu se radi: Polje za pretragu u „Choose a game“ traži samo dva imena
   igrača i poteze — kucanje godine ili rezultata (npr. „1-0“) ga namerno ne
   suzi, da kucanje datuma ne bi tiho premeštalo listu. Posle ove stavke (faza
   7 plana docs/PLAN-LISTE.md, 21.9.2026) dodat je i **poseban filter po
   rezultatu** (čipovi ispod pretrage), odvojen od polja za tekst.
   Gde: `Analyse` → `Setup Position / PGN` → tab `PGN` → (izbor iz više
   uvezenih partija otvara „Choose a game“).
   Uradi: U polje za pretragu upiši godinu (npr. „2024“) i primeti da se lista
   ne suzi po tome. Upiši „1-0“ u isto polje. Zatim, odvojeno, isprobaj filter
   čipove za rezultat ispod pretrage.
   Treba da vidiš: Kucanje godine ili „1-0“ u polje za pretragu ne suzi listu
   (traže se samo imena i potezi). Poseban filter čip za rezultat (ako postoji
   ispod pretrage) suzi listu po ishodu partije, nezavisno od teksta u polju za
   pretragu.
   Potrebno: Windows; uvezene partije.

3. [ ] **Podnaslov reda prikazuje samo glavnu liniju, bez varijanti.** [203.10]
   O čemu se radi: Kad se u Analizu nalepi PGN koji sadrži varijante (npr. iz
   `Setup Position / PGN`), podnaslov reda u „Choose a game“ prikazuje samo
   poteze glavne linije, bez poteza iz zagrada (varijanti).
   Gde: `Analyse` → `Setup Position / PGN` → tab `PGN` → (izbor iz više
   uvezenih partija otvara „Choose a game“).
   Uradi: Nalepi (ili uvezi) PGN partiju koja sadrži varijante u zagradama, i
   pogledaj podnaslov njenog reda u „Choose a game“.
   Treba da vidiš: Podnaslov prikazuje samo poteze glavne linije; potezi iz
   varijanti (zagrada) se ne pojavljuju u podnaslovu.
   Potrebno: Windows; PGN fajl.

### Analyse — PGN i postavka pozicije

1. [ ] **Dijalog za PGN se otvara odmah, bez čekanja na kopiranje.** [157.1]
   O čemu se radi: Ranije se čekalo kopiranje u clipboard pre otvaranja
   dijaloga; sad je tekst na ekranu čim se pritisne dugme.
   Gde: `Analyse` tab → otvori partiju/poziciju → traka alatki → `Export PGN`.
   Uradi: Otvori partiju u Analizi sa komentarima i varijantama, pritisni
   `Export PGN`.
   Treba da vidiš: Tekst PGN-a je na ekranu odmah (dijalog `Exported PGN Text`)
   — nema zastoja pre otvaranja.
   Potrebno: Windows i telefon; uvezene partije.

2. [ ] **Tekst je zaista kopiran čim se dijalog otvori.** [157.2]
   O čemu se radi: Tekst se automatski kopira u clipboard pri otvaranju
   dijaloga.
   Gde: `Analyse` tab → otvori partiju/poziciju → traka alatki → `Export PGN`.
   Uradi: Odmah po otvaranju dijaloga, nalepi (Ctrl+V) u Notepad.
   Treba da vidiš: Zalepljeni tekst je isti kao tekst na ekranu dijaloga.
   Potrebno: Windows i telefon; uvezene partije.

3. [ ] **`Save as .pgn` otvara sistemski dijalog sa ponuđenim imenom i
   filterom.** [157.3]
   O čemu se radi: Ponuđeno ime fajla nosi današnji datum.
   Gde: `Analyse` tab → otvori partiju/poziciju → traka alatki → `Export PGN`.
   Uradi: U dijalogu pritisni `Save as .pgn`.
   Treba da vidiš: Otvara se sistemski dijalog za snimanje, sa ponuđenim imenom
   analysis-<današnji datum>.pgn i filterom na .pgn.
   Potrebno: Windows; uvezene partije.

4. [ ] **Snimljeni fajl sadrži tačno ono što je bilo na ekranu.** [157.4]
   O čemu se radi: Fajl treba da nosi komentare, [%cal] strelice, [%csl] polja
   i sve varijante — isti string kao na ekranu.
   Gde: `Analyse` tab → otvori partiju/poziciju → traka alatki → `Export PGN`.
   Uradi: Sačuvaj PGN sa `Save as .pgn`, pa otvori sačuvan fajl u Notepad-u i
   uporedi ga sa tekstom iz dijaloga.
   Treba da vidiš: Sadržaj fajla je identičan tekstu koji je bio prikazan u
   dijalogu.
   Potrebno: Windows; uvezene partije.

5. [ ] **Sačuvan fajl se otvara u drugom programu i nazad u aplikaciju.**
   [157.5]
   O čemu se radi: Potezi i komentari treba da prežive put napolje i nazad.
   Gde: `Analyse` tab → otvori partiju/poziciju → traka alatki → `Export PGN`.
   Uradi: Uvezi sačuvan .pgn fajl u ChessBase, u Lichess (Import game), i nazad
   u samu aplikaciju.
   Treba da vidiš: Potezi i komentari ostaju isti posle svakog uvoza.
   Potrebno: Windows; uvezene partije.

6. [ ] **Naša slova (š đ č ć ž) prežive kao UTF-8, ne kao smeće.** [157.6]
   O čemu se radi: Fajl se namerno piše u UTF-8; zaglavlja ostaju ASCII zbog
   strožih čitača, ali trenerove rečenice zadržavaju svoja slova.
   Gde: `Analyse` tab → otvori partiju/poziciju → traka alatki → `Export PGN`.
   Uradi: Napiši komentar sa 'š, đ, č, ć, ž', izvezi, otvori sačuvan fajl u
   Notepad-u.
   Treba da vidiš: Slova se vide ispravno. Ako izgledaju kao smeće, zapiši u
   kom programu je otvoren — čitač je taj koji ne zna UTF-8.
   Potrebno: Windows; uvezene partije.

7. [ ] **Poruka posle snimanja kaže celu putanju do fajla.** [157.7]
   O čemu se radi: Bez cele i tačne putanje trener mora da traži fajl po disku.
   Gde: `Analyse` tab → otvori partiju/poziciju → traka alatki → `Export PGN`.
   Uradi: Sačuvaj PGN preko `Save as .pgn`.
   Treba da vidiš: Posle snimanja dijalog se zatvara i dole se pojavljuje
   `Saved: ...` sa celom i tačnom putanjom.
   Potrebno: Windows; uvezene partije.

8. [ ] **Odustajanje od sistemskog dijaloga ne radi ništa.** [157.8]
   O čemu se radi: Zatvaranje sistemskog dijaloga bez izbora imena mora tiho da
   se vrati na tekst.
   Gde: `Analyse` tab → otvori partiju/poziciju → traka alatki → `Export PGN`.
   Uradi: Pritisni `Save as .pgn`, pa zatvori sistemski dijalog za snimanje bez
   izbora imena.
   Treba da vidiš: Nema poruke; dijalog sa PGN tekstom ostaje otvoren, kao pre.
   Potrebno: Windows; uvezene partije.

9. [ ] **Neuspešno snimanje se prijavi, tekst ostaje dostupan za kopiranje.**
   [157.9]
   O čemu se radi: Ako snimanje na disk ne uspe (npr. bez prava upisa), dijalog
   ne sme da nestane.
   Gde: `Analyse` tab → otvori partiju/poziciju → traka alatki → `Export PGN`.
   Uradi: Izazovi grešku pri snimanju (npr. sačuvaj na putanju bez prava
   upisa).
   Treba da vidiš: Piše 'The file could not be saved.', a dijalog sa tekstom
   ostaje otvoren — tekst je i dalje tu da se kopira.
   Potrebno: Windows; uvezene partije.

10. [ ] **Na Androidu fajl ide preko sistemskog plugina, naslov se prelama na
   uskom ekranu.** [157.10]
   O čemu se radi: Android ide drugim putem (sistemski plugin piše fajl, ne
   aplikacija); naslov dijaloga sad prelama red umesto da se seče.
   Gde: `Analyse` tab → otvori partiju/poziciju → traka alatki → `Export PGN`.
   Uradi: Na telefonu izvezi PGN i sačuvaj ga preko Androidove sistemske ponude
   za snimanje.
   Treba da vidiš: Fajl se zaista pojavi tamo gde ga je Android ponudio; tri
   dugmeta i naslov staju na uzak ekran, naslov prelama red umesto da se seče.
   Potrebno: telefon; uvezene partije; telefon položeno.

11. [ ] **Izvezeni PGN nema `[%eval ...]`.** [103.11]
   O čemu se radi: Izvoz partije više ne piše evaluaciju motora u tekst — samo
   ono što stablo zaista nosi: komentar, NAG, nacrtane strelice/polja
   (`[%cal]`/`[%csl]`) i sat.
   Gde: `Analyse` → alatnica → `Export PGN`.
   Uradi: Na partiji sa nekoliko komentara i NAG oznaka pritisni `Export PGN` i
   pogledaj tekst.
   Treba da vidiš: Komentar i NAG (npr. `!`, `?`) su u tekstu; nigde nema
   `[%eval ...]`.
   Potrebno: Windows i telefon.

12. [ ] **Izvoz pa ponovni uvoz istog PGN-a daje isto stablo bez upozorenja.**
   [171.5]
   O čemu se radi: Krug izvoz→uvoz mora biti bezgubitan za stablo sa
   varijantama.
   Gde: Analyse → `Export PGN`, pa `Setup Position / PGN` → tab `PGN` →
   `Paste PGN` → `Import PGN Game`.
   Uradi: Izvezi tekuće stablo preko `Export PGN`, kopiraj tekst, pa ga ponovo
   uvezi kroz tab `PGN` (`Paste PGN` → `Import PGN Game`).
   Treba da vidiš: Dobijeno stablo je identično prethodnom, bez ijednog
   upozorenja o odbačenom potezu.
   Potrebno: Windows.

13. [ ] **Chess.com/Lichess uvoz i dalje učitava partiju, bez sat-komentara u
   stablu.** [171.6]
   O čemu se radi: Sat posle svakog poteza (%clk) se i dalje čita za prikaz,
   ali se ne upisuje kao tekstualni komentar u stablu.
   Gde: Analyse → `Setup Position / PGN` → tab `Online` →
   `Lichess`/`Chess.com`.
   Uradi: Preuzmi jednu partiju sa Lichess ili Chess.com koja ima sat posle
   svakog poteza.
   Treba da vidiš: Partija se učita normalno; nigde u stablu ne piše komentar
   oblika „0:02:59“.
   Potrebno: Windows; internet.

14. [ ] **Uvoz PGN fajla sa 50 poteza učitava celo stablo.** [171.1]
   O čemu se radi: Osnovna provera PGN uvoza sa strankama i komentarima —
   nepromenjena od 16.9.2026.
   Gde: Analyse → `Setup Position / PGN` → tab `PGN` → `Load .pgn file` (ili
   `Paste PGN`) → `Import PGN Game`.
   Uradi: Uvezi PGN fajl partije koja ima bar 50 poteza sa varijantama i
   komentarima.
   Treba da vidiš: Pojavljuje se poruka „PGN loaded — N moves in tree“; tabla
   stane na potezu na kome je bio kursor u fajlu (ili na poslednjem odigranom
   potezu ako kursor nije naveden).
   Potrebno: Windows; PGN fajl.

15. [ ] **Nepoznat potez u PGN tekstu se prijavi žutom porukom, ne zelenom.**
   [171.7]
   O čemu se radi: Kad tekst sadrži potez koji tabla ne može da odigra, uvoz
   staje na poslednjem ispravnom potezu i to jasno kaže.
   Gde: Analyse → `Setup Position / PGN` → tab `PGN` → `Paste PGN`.
   Uradi: Nalepi tekst „1. e4 e5 2. Nf3 Qxz9 *“ (nevalidan potez na kraju) i
   učitaj ga.
   Treba da vidiš: Stablo se učita do 2. Nf3; poruka je žuta (ne zelena) i kaže
   da je potez izostavljen.
   Potrebno: Windows.

### Analyse — Motor, linije i tablebase

1. [ ] **Dijalog sa linijom motora ima `<`/`>`, brojač i okretanje table.**
   [20.b670]
   O čemu se radi: Kad se u Analysis Studiju klikne na liniju iz panela motora,
   otvara se dijalog sa sopstvenom trakom istog izgleda kao svugde u
   aplikaciji.
   Gde: `Analyse` → Analysis Studio → panel motora → kliknuti na liniju.
   Uradi: Otvoriti liniju iz panela motora u Analysis Studiju.
   Treba da vidiš: Dugmad su `<` i `>`, brojač (npr. `3 / 8`) stoji između
   njih, a okretanje table je na kraju istog reda.
   Potrebno: Windows i telefon.

2. [ ] **Onlajn ocena je pozitivna za belog i kad je crni na potezu.**
   [28.b811]
   O čemu se radi: Oblačna (Lichess) ocena se šalje bez preokretanja znaka,
   isto kao nativni motor — obe strane moraju da daju istu ocenu za istu
   poziciju.
   Gde: `Analyse` → Analysis Studio → (motor podešen na onlajn) →
   `Setup Position / PGN` → uneti poteze `1.e4 e5 2.Nf3 Nc6 3.Bb5`.
   Uradi: Postaviti poziciju posle `1.e4 e5 2.Nf3 Nc6 3.Bb5` (crni na potezu,
   beli bolje stoji), sa uključenim onlajn motorom pogledati ocenu, pa
   uporediti sa nativnim motorom.
   Treba da vidiš: Ocena je pozitivna (u korist belog) i sa onlajn i sa
   nativnim motorom.
   Potrebno: Windows i telefon; internet.

3. [ ] **Prebacivanje motora onlajn↔nativni ne prevrće znak.** [28.b814]
   O čemu se radi: Isto pravilo iz i0169 mora da ostane tačno i posle nekoliko
   prebacivanja motora napred-nazad.
   Gde: `Analyse` → Analysis Studio → `Setup Position / PGN` → uneti poteze
   `1.e4 e5 2.Nf3 Nc6 3.Bb5`.
   Uradi: Na istoj poziciji prebaciti motor sa onlajn na nativni i nazad
   nekoliko puta.
   Treba da vidiš: Znak ocene ostaje isti (u korist iste strane) pri svakom
   prebacivanju.
   Potrebno: Windows i telefon; internet.

4. [ ] **Onlajn motor piše mat za crnog kao „-M1"** [28.b816]
   O čemu se radi: Matirajuća ocena mora da imenuje pravu stranu — mat za crnog
   se piše sa minusom, ne kao mat za belog.
   Gde: `Analyse` → Analysis Studio → `Setup Position / PGN` → uneti poteze
   `1.f3 e5 2.g4`.
   Uradi: Postaviti poziciju posle `1.f3 e5 2.g4` (crni na potezu, mat u jednom
   za crnog), sa uključenim onlajn motorom pogledati ocenu.
   Treba da vidiš: Ocena piše `-M1` (mat za crnog), ne mat za belog.
   Potrebno: Windows i telefon; internet.

5. [ ] **Tablebase panel u Analizi ispisuje presudu na engleskom.** [169.2]
   O čemu se radi: Isti pivot — Syzygy panel u Analizi pokazuje presude poput
   „Win“, „Probable win“, „Unknown“, na engleskom.
   Gde: Analyse → `Panels` → uključi `Tablebase (Syzygy)` → pozicija sa ≤7
   figura.
   Uradi: Uključi panel `Tablebase (Syzygy)` i stani na poziciju sa najviše 7
   figura.
   Treba da vidiš: Panel ispisuje presudu na engleskom (npr. `Win`,
   `Probable win`, `Unknown`), nikad na srpskom.
   Potrebno: Windows; tablebase (pokreni.ps1 [5]).

6. [ ] **Dubina motora ide do 50 bez preskakanja, na svim ekranima.** [180.8]
   O čemu se radi: Meni „depth“ je proširen na 6–50 bez preskakanja vrednosti,
   sa engleskim natpisima („depth“, „lines“, „Again“), na tabli Analize,
   repertoara i vežbi. Napomena: „sačuvane pozicije“ kao poseban ekran su
   23.9.2026 obrisane (Library ih je apsorbovala), pa je taj deo originalne
   provere ispušten.
   Gde: Analyse → traka motora → meni dubine (`depth`).
   Uradi: Otvori meni dubine na tabli Analize i prođi ceo opseg; zatim proveri
   `Review entire game` i `Auto Analysis`.
   Treba da vidiš: Analiza ide 6–50 bez preskakanja; `Review entire game` i
   `Auto Analysis` idu do 50.
   Potrebno: Windows; debug build.

### Analyse — Analysis

1. [ ] **Prelazak na drugu aplikaciju i nazad ne izaziva lažnu poruku o
   motoru.** [200.2]
   O čemu se radi: Prelazak na drugu aplikaciju i nazad, kao i Back pa ponovno
   otvaranje ekrana sa motorom, ne sme da izazove poruku o motoru koji ne
   odgovara.
   Gde: `Analyse` (uz uključen motor).
   Uradi: Sa uključenim motorom u Analizi, pređi na drugu aplikaciju pa se
   vrati. Zatim izađi nazad (Back) sa ekrana i ponovo ga otvori.
   Treba da vidiš: Ni u jednom slučaju se ne pojavljuje poruka o motoru koji ne
   odgovara.
   Potrebno: Windows.

2. [ ] **Motor koji zaista zaćuti javlja to jednom, jasnom porukom.** [200.3]
   O čemu se radi: Ako motor prestane da odgovara (nema evaluacije), na ekranu
   se, samo jednom (ne ponavljano na svakih par sekundi), ispisuje „The engine
   is not answering. Close the app completely and open it again.“; posle
   potpunog zatvaranja i ponovnog otvaranja aplikacije motor ponovo radi.
   Gde: `Analyse` (uz uključen motor).
   Uradi: Izazovi (ili sačekaj) da motor prestane da odgovara tokom rada u
   Analizi. Posmatraj da li se poruka ponavlja. Zatvori aplikaciju potpuno i
   ponovo je otvori.
   Treba da vidiš: Poruka „The engine is not answering. Close the app
   completely and open it again.“ se pojavljuje jednom, ne iznova na svakih par
   sekundi. Posle potpunog gašenja i ponovnog pokretanja aplikacije, motor
   ponovo radi normalno.
   Potrebno: Windows; debug build.

3. [ ] **Kad se motor ugasi (Stockfish is not ready), izlazak i povratak
   pokreće nov.** [200.4]
   O čemu se radi: Ako motor stane sasvim (u logu „Stockfish is not ready“), na
   ekranu piše „The engine has stopped. Leave this screen and open it again.“,
   a izlazak sa ekrana pa povratak pokreće nov motor bez potrebe da se cela
   aplikacija gasi.
   Gde: `Analyse` (uz uključen motor).
   Uradi: Izazovi (ili sačekaj) da motor sasvim stane tako da log pokaže
   „Stockfish is not ready“. Pročitaj poruku na ekranu, pa izađi sa ekrana i
   vrati se.
   Treba da vidiš: Poruka na ekranu glasi „The engine has stopped. Leave this
   screen and open it again.“ Posle izlaska i povratka na ekran, pokreće se nov
   motor i rad nastavlja normalno, bez gašenja cele aplikacije.
   Potrebno: Windows; debug build.

4. [ ] **Analyse ulazi sa ugašenim motorom, bez drugog naslova.** [177.4]
   O čemu se radi: Traženo uživo 17. i 18.9.2026: motor se više ne pokreće sam
   pri prvom ulasku u Analizu; uključuje se samo na dodir.
   Gde: `Analyse`.
   Uradi: Uđi u Analyse na svež ulazak. Zatim pređi na drugi tab i vrati se.
   Treba da vidiš: Tabla je odmah tu sa svojom trakom (Setup, motor,
   `Use in a tutorial`…), iznad nje `My games` i `Scan a book`, bez ikakvog
   drugog naslova. Ni traka procene ni strelice motora se ne pojave dok se
   motor ručno ne uključi; posle povratka sa drugog taba, stablo i prekidač
   motora ostaju isti.
   Potrebno: telefon; telefon položeno.

5. [ ] **Komentari iz uvezenog PGN-a se vide uz svoj potez.** [171.3]
   O čemu se radi: Tekstualni komentari iz PGN zagrada moraju da ostanu vezani
   za tačan potez posle uvoza.
   Gde: `Analyse` → panel komentara, posle uvoza PGN-a sa komentarom.
   Uradi: Uvezi PGN sa komentarom na nekom potezu i stani na taj potez.
   Treba da vidiš: Panel komentara pokazuje tekst iz PGN fajla, vezan za taj
   potez.
   Potrebno: Windows; PGN fajl.

6. [ ] **Ime otvaranja iz PGN zaglavlja se ispisuje iznad table.** [171.4]
   O čemu se radi: PGN zaglavlje (Event/Opening) se čita i prikazuje kao naslov
   iznad table.
   Gde: `Analyse` → naslov iznad table, posle uvoza PGN-a sa zaglavljem
   otvaranja.
   Uradi: Uvezi PGN fajl čije zaglavlje imenuje otvaranje (npr. „Repertoire —
   Opponent“).
   Treba da vidiš: Iznad table se ispisuje to ime, uzeto iz zaglavlja fajla.
   Potrebno: Windows; PGN fajl.

7. [ ] **Traka faze za završnicu se jasno vidi.** [45.b1723]
   O čemu se radi: Panel iznad table u Analysis Studiju menja boju/ikonicu
   zavisno od toga da li je pozicija završnica ili otvaranje.
   Gde: `Analyse` → (panel iznad table sa nazivom faze).
   Uradi: Učitaj poziciju koja je već završnica (malo figura na tabli).
   Treba da vidiš: Panel je jasno uokviren i nosi svoju ikonicu, čitljivo
   odvojen od pozadine.
   Potrebno: Windows i telefon.

8. [ ] **Traka za otvaranje se i dalje razlikuje od panela ispod.** [45.b1725]
   O čemu se radi: Isti panel kao gore, u stanju otvaranja (van završnice);
   mora se razlikovati od pozadine.
   Gde: `Analyse` → (panel iznad table sa nazivom faze/otvaranja).
   Uradi: Učitaj poziciju iz otvaranja (van završnice).
   Treba da vidiš: Panel se vidljivo razlikuje bojom od panela koji stoji ispod
   njega.
   Potrebno: Windows i telefon.

9. [ ] **Traka je svetla; dugmad za potez rade — u redu na širokom, u meniju na
   uskom.** [20.b665]
   O čemu se radi: Traka koristi svetlu boju kartice. Od 18.9.2026 dugmad za
   komentar, AI komentar, oznaku i brisanje stoje u istom redu samo na ekranima
   širim od 600 dp — na užim (telefon) su skupljena u jedno dugme „What to do
   with this move" koje otvara listu.
   Gde: `Analyse` → Analysis Studio, sa učitanom partijom.
   Uradi: Na širokom prozoru (Windows) pogledati traku i njena četiri dugmeta;
   zatim isto na uskom ekranu (telefon ili suženi prozor).
   Treba da vidiš: Na širokom prozoru traka je svetla i sva četiri dugmeta
   (komentar, AI komentar, NAG, brisanje) stoje u istom redu i rade; na uskom
   su skupljena iza dugmeta `What to do with this move`, koje otvara listu sa
   istim radnjama.
   Potrebno: Windows i telefon.

10. [ ] **Strelice u šetnji kroz partiju: levo/desno potez, gore/dole
   krajevi.** [0p.b181]
   O čemu se radi: Strelice na tastaturi pomeraju se kroz poteze na svakom
   ekranu koji ima traku za kretanje: levo/desno jedan potez, gore/dole (i
   Home/End) na početak i kraj. Vlasnik je 24.8.2026 prijavio da su bile
   zamenjene; popravljeno je, i test sada drži svaku strelicu na njenoj strani.
   Gde: `Analyse` → Analysis Studio (ili bilo koji drugi ekran sa nizom
   poteza).
   Uradi: Na Windows-u otvoriti ekran sa nizom poteza (npr. Analysis Studio sa
   učitanom partijom), bez ijednog klika mišem pritisnuti strelicu levo/desno,
   pa gore/dole.
   Treba da vidiš: Levo/desno pomera jedan potez nazad/napred; gore/dole (i
   Home/End) ide na početak/kraj niza — ništa nije zamenjeno mestima.
   Potrebno: Windows.

11. [ ] **Strelice posle auto analize pokazuju potez, ne broj.** [103.12]
   O čemu se radi: Strelice koje `Auto Analysis` nacrta na tabli su sada
   obeležene SAN potezom kandidata, ne evaluacijom.
   Gde: `Analyse` → alatnica → `Auto Analysis ⚡`.
   Uradi: Pusti `Auto Analysis ⚡` na nekoj poziciji sa bar dva kandidata i
   pogledaj nacrtane strelice na tabli.
   Treba da vidiš: Uz svaku strelicu piše SAN poteza (npr. `Nf3`), ne broj tipa
   `+0.35`.
   Potrebno: Windows i telefon.

12. [ ] **Analysis Studio ima prekidač za strelice motora.** [93.5]
   O čemu se radi: Vlasnik je 3.9.2026 primetio da u Analysis nema prekidača za
   strelice motora, iako bi trebalo da budu tri (potez, statistika, motor).
   Meni na tabli u Analysis sada nudi sva tri.
   Gde: `Analyse` → (ikonica table, gore desno) → `Board view`.
   Uradi: Otvori Analysis Studio na poziciji gde je motor pitan i crta
   strelice. Otvori meni `Board view` na tabli.
   Treba da vidiš: U meniju stoje sva tri prekidača:
   `Arrows for the selected move`, `Arrows with statistics` i `Engine arrows`;
   isključivanje `Engine arrows` ukloni motorske strelice, ostalo ostaje.
   Potrebno: Windows i telefon; server.

13. [ ] **Panel motora se ne seče na uskom telefonu.** [103.6]
   O čemu se radi: Panel motora je na uskom ekranu složen u red koji se lomi
   (`Wrap`), ne u fiksni red koji release build tiho seče. Natpisi uz prekidače
   smeju da se skrate sa tri tačke, ali ne smeju da nestanu iza ivice ekrana.
   Gde: `Analyse` → panel `Engine`.
   Uradi: Otvori Analysis Studio na telefonu (ili suzi Windows prozor na oko
   360 dp širine). Uključi `Show evaluation`. Pogledaj red sa prekidačem
   `Show evaluation bar` i uvećaj sistemski font pa ponovi pogled.
   Treba da vidiš: Natpis `Show evaluation bar` (i `Show evaluation`) ostaje
   čitljiv, po potrebi skraćen sa „…”, ali nikad odsečen ili sakriven iza desne
   ivice ekrana — ni sa običnim ni sa uvećanim fontom.
   Potrebno: telefon.

14. [ ] **Vrteška motora se vrti samo dok se čeka na liniju.** [103.7]
   O čemu se radi: Mala vrteška pored panela motora se crta samo dok je
   evaluacija uključena, a još nijedna linija nije stigla; čim stignu linije
   ili se evaluacija ugasi, vrteška nestaje.
   Gde: `Analyse` → panel `Engine`.
   Uradi: Uključi `Show evaluation` na svežoj poziciji i odmah pogledaj panel,
   pa sačekaj da stignu linije. Zatim isključi `Show evaluation`.
   Treba da vidiš: Vrteška se vidi samo u kratkom prozoru dok linija još nema;
   čim se pojavi bar jedna linija, vrteška nestaje; dok je `Show evaluation`
   isključen, vrteške nema uopšte.
   Potrebno: Windows i telefon.

15. [ ] **AI objašnjenje pozicije i komentar poteza odgovaraju na engleskom.**
   [132.6]
   O čemu se radi: Parametar za jezik odgovora je u potpunosti obrisan sa oba
   kraja (aplikacija i server) — model se sada uvek pita na engleskom, bez
   obzira na jezik uređaja.
   Gde: `Analyse` → panel `Engine` ili poteza → `Generate AI comment` (ili
   „Explain the position” ako postoji na ekranu).
   Uradi: Pusti AI objašnjenje pozicije ili AI komentar poteza na bilo kojoj
   poziciji.
   Treba da vidiš: Odgovor modela je na engleskom. Ako se pojavi srpski tekst,
   to znači da je model ignorisao uputstvo i to je nalaz.
   Potrebno: Windows i telefon; DeepSeek ključ na serveru; internet.

16. [ ] **Uspravna traka evaluacije prati okretanje table.** [45.b1709]
   O čemu se radi: Traka evaluacije mora ostati čitljiva bez obzira na to koja
   je strana dole.
   Gde: `Analyse` → (panel `Engine`) → `Show evaluation bar`.
   Uradi: Uključi `Show evaluation bar`, pa okreni tablu između belog i crnog
   dole.
   Treba da vidiš: Belo polje trake je dole kad je tabla okrenuta belim dole,
   gore kad crnim.
   Potrebno: Windows i telefon.

17. [ ] **Dubina je na svakom redu motora, nema banera iznad.** [103.2]
   O čemu se radi: Panel motora (`Engine`) je ujednačen na sva tri mesta gde se
   crta (Analysis Studio, AI Studio, soba). Svaka linija sada nosi svoju dubinu
   (`d20`) jer se linije mogu razlikovati po dubini; zajedničkog natpisa sa
   jednom evaluacijom i naslova iznad linija više nema.
   Gde: `Analyse` → panel `Engine` (uključi `Show evaluation`).
   Uradi: Otvori Analysis Studio na nekoj poziciji i uključi `Show evaluation`.
   Pogledaj panel motora iznad i pored svake linije.
   Treba da vidiš: Nema banera tipa „Eval: +0.35 (depth: 20)” ni naslova „Top 3
   Linije/Top 3 Lines” iznad linija — svaka linija nosi sopstvenu oznaku dubine
   (npr. `d20`) pored sebe.
   Potrebno: Windows i telefon.

18. [ ] **U Analizi „napred" na varijanti pita kojom granom ići.** [78.2]
   O čemu se radi: Isti izbor grane kao u repertoaru radi i u Analysis, gde je
   pre 1.9.2026 u varijantu moglo da se uđe samo klikom u stablu. Kvar sa
   strelicom desno, prijavljen za repertoar, važio je i ovde i popravljen je
   zajedno.
   Gde: `Analyse` → (partija sa varijantama) → (pozicija sa varijantom) →
   `Next move` ili strelica desno.
   Uradi: Učitaj ili odigraj partiju sa bar jednom varijantom u Analysis
   Studiju. Na poziciji gde varijanta počinje, pritisni dugme za sledeći potez,
   pa probaj isto strelicom desno na tastaturi.
   Treba da vidiš: I dugme i strelica desno otvaraju „Multiple lines from here
   — which one?" sa glavnim potezom i varijantom; izbor vodi tablu tom granom,
   umesto da se u varijantu ulazi samo klikom u stablu.
   Potrebno: Windows i telefon; server.

19. [ ] **Nema panela taktičkih/pozicionih motiva; „Panels“ nudi samo četiri
   stavke.** [221.1]
   O čemu se radi: Motivi (taktički i pozicioni) su od 22.9.2026 samo za AI
   komentar i tutorijale; u Analizi nema više panela `Tactical motifs` ni
   `Positional factors`, a dugme `Panels` u traci nudi Move tree, Opening
   Explorer, Tablebase i Engine analysis panel.
   Gde: `Analyse` → alatka `Panels`.
   Uradi: Otvori Analizu i pritisni `Panels` u traci alatki.
   Treba da vidiš: Meni `Panels` nudi tačno četiri kućice: `Move tree`,
   `Opening Explorer`, `Tablebase (Syzygy)`, `Engine analysis panel` — nema
   prekidača za automatski komentar niti panela sa nazivom taktičkih/pozicionih
   motiva.
   Potrebno: Windows.

20. [ ] **Traka ishoda u eksploreru otvaranja se razlikuje od panela.**
   [45.b1714]
   O čemu se radi: Traka ishoda po potezu u eksploreru otvaranja mora biti
   čitljiva na daltonistu.
   Gde: `Analyse` → `Panels` → `Opening Explorer`.
   Uradi: Otvori poznatu poziciju iz otvaranja da eksplorer pokaže poteze sa
   statistikom.
   Treba da vidiš: Belo/remi/crno polje trake ishoda se razlikuju međusobno i
   od pozadine panela iza njih.
   Potrebno: Windows i telefon.

21. [ ] **Analiza i dalje ima svih pet kartica za postavljanje pozicije.**
   [130.3]
   O čemu se radi: Analysis Studio je jedino mesto koje prosleđuje uvoz PGN-a u
   ovaj dijalog, pa ono i dalje dobija sve kartice.
   Gde: `Analyse` → alatnica → `Setup Position / PGN`.
   Uradi: Otvori `Setup Position / PGN` u Analysis Studiju.
   Treba da vidiš: Dijalog ima svih pet kartica: `FEN`, `PGN`, `Pieces`,
   `Openings`, `Online`, i uvoz PGN-a radi kao pre.
   Potrebno: Windows.

22. [ ] **Figure u paleti se raspoznaju bez oslanjanja na boju.** [130.4]
   O čemu se radi: U kartici `Pieces`, crne figure stoje na svetlom polju u
   paleti, a izabrana figura je obeležena i drugačijom (debljom) ivicom, ne
   samo drugom podlogom.
   Gde: `Analyse` → alatnica → `Setup Position / PGN` → kartica `Pieces`.
   Uradi: Otvori karticu `Pieces` i pogledaj paletu figura (12 polja, belo i
   crno). Izaberi jednu figuru.
   Treba da vidiš: Crne figure na paleti se jasno vide na svetloj podlozi.
   Izabrana figura ima primetno deblju ivicu/okvir, ne samo drugu boju podloge.
   Potrebno: Windows i telefon.

23. [ ] **Rokade se čitaju kao reč, ne kao sirovo slovo.** [130.5]
   O čemu se radi: Umesto sirovih FEN slova `K`/`Q`/`k`/`q`, čipovi za pravo na
   rokadu sada čitaju „W O-O”/„W O-O-O”/„B O-O”/„B O-O-O”, sa punim imenom u
   tooltipu (npr. „White O-O”).
   Gde: `Analyse` → alatnica → `Setup Position / PGN` → kartica `Pieces`.
   Uradi: Otvori karticu `Pieces` i pogledaj red sa čipovima za rokadu.
   Treba da vidiš: Čipovi pišu „W O-O”, „W O-O-O”, „B O-O”, „B O-O-O” — nigde
   se ne vidi sirovo slovo `K`, `Q`, `k` ili `q`.
   Potrebno: Windows.

24. [ ] **Kartica „Pieces” se skroluje na uskom prozoru, dugme je dostupno.**
   [130.6]
   O čemu se radi: Na uskom prozoru (ili telefonu) kartica za ručno slaganje
   figura se skroluje, tako da je dugme za potvrdu uvek dostižno; na širokom
   prozoru se ništa ne skroluje jer sve staje.
   Gde: `Analyse` → alatnica → `Setup Position / PGN` → kartica `Pieces`.
   Uradi: Otvori karticu `Pieces` na telefonu (ili sa suženim Windows prozorom
   na oko 360 dp).
   Treba da vidiš: Sadržaj kartice se skroluje i dugme
   `Generate and Set Position` se može pritisnuti. Na širokom prozoru isti
   sadržaj staje bez skrolovanja.
   Potrebno: telefon.

25. [ ] **Tri načina brisanja polja i dalje rade.** [130.7]
   O čemu se radi: Na tabli za ručno slaganje polje se prazni klikom na
   naoružano polje, dugim pritiskom ili desnim klikom.
   Gde: `Analyse` → alatnica → `Setup Position / PGN` → kartica `Pieces`.
   Uradi: Postavi figuru na polje. Isprazni je jednom klikom na nju, drugu
   dugim pritiskom, treću desnim klikom.
   Treba da vidiš: Sva tri načina prazne polje.
   Potrebno: Windows.

26. [ ] **Normalan rad motora ne pokazuje crvenu poruku o tišini.** [200.1]
   O čemu se radi: U normalnom radu (Analiza, Preparation, partija protiv
   motora, „Play it out“), poruka o motoru koji ne odgovara ne sme da se
   pojavi, ni pri brzom prelistavanju poteza.
   Gde: `Analyse` (uz uključen motor); `Teach` → `New session` (Preparation);
   Biblioteka → zadatak → `Play`.
   Uradi: Uključi motor u Analizi i brzo prelistavaj poteze napred-nazad neko
   vreme. Ponovi u Preparation i u partiji protiv računara („Play it out“).
   Treba da vidiš: Ni u jednom od ova tri ekrana se ne pojavljuje crvena poruka
   o motoru koji ne odgovara, ni pri brzom prelistavanju.
   Potrebno: Windows.

27. [ ] **Kartica u stablu ne nosi broj evaluacije.** [103.9]
   O čemu se radi: Kartica u grafičkom stablu poteza sada nosi samo broj
   poteza, SAN i NAG oznaku (npr. `!`, `?`). Ocena motora se više ne upisuje u
   čvor — ko želi da je zapamti, piše je u komentar poteza.
   Gde: `Analyse` → panel `Variation Tree`.
   Uradi: Otvori partiju ili repertoar sa nekoliko odigranih poteza u Analysis
   Studiju i pogledaj kartice u grafičkom stablu (isto proveri i u repertoaru).
   Treba da vidiš: Svaka kartica ima samo broj-poteza + SAN (+ NAG ako postoji)
   — ništa u zagradi, nema obojene tačkice pored natpisa.
   Potrebno: Windows i telefon.

28. [ ] **Alatnica grafičkog stabla nema dugme za filter.** [103.10]
   O čemu se radi: Uklonjen je filter po pragu evaluacije zajedno sa brisanjem
   ocene iz čvorova. Alatnica stabla i dalje ima ostala dugmad.
   Gde: `Analyse` → panel `Variation Tree` → (alatnica iznad crteža).
   Uradi: Otvori grafičko stablo u Analysis Studiju i pogledaj plutajuću
   alatnicu iznad crteža.
   Treba da vidiš: Nema ikonice za filter ni trake „Threshold: …” sa klizačem.
   Dugmad `Zoom in`, `Zoom out`, `Center on active move`, `Reset view`,
   prekidač za raspored (`Vertical layout`/`Horizontal layout`) i puštanje
   linije (`Play all (visible) lines`) i dalje postoje.
   Potrebno: Windows i telefon.

29. [ ] **Traka Analize je jedan gust red, bez suvišnog dugmeta za sudiju.**
   [172.1]
   O čemu se radi: Vlasnik je uz ovu stavku prijavio da je navigaciona paleta
   prevelika, da se pominje Lichess i da dugme za ručnu presudu poteza više
   nema smisla (ne troše se tokeni) — sve popravljeno isti dan (16.9.2026):
   traka je zgusnuta u jedan red (potvrđeno uživo, stavka 173.1), dugme za
   presudu poteza je uklonjeno iz Analize (173.2), a pominjanje Lichess-a je
   uklonjeno iz gradnje repertoara (173.3).
   Gde: Analyse (telefon položeno) → ikonica mreže `Board view`.
   Uradi: Uključi eval traku u Analizi na telefonu položeno i pogledaj traku sa
   dugmadima.
   Treba da vidiš: Svih devet dugmadi
   (početak/nazad/napred/kraj/okreni/komentar/AI/NAG/obriši) stoji u jednom
   redu i lako se pogađaju prstom; nigde u Analizi ne postoji dugme za ručnu
   presudu poteza.
   Potrebno: telefon; telefon položeno.

30. [ ] **Board size u Analizi menja tablu bez izlaska sa ekrana.** [180.2]
   O čemu se radi: Klizač veličine table je 17.9.2026 prebačen iz Settings u
   meni `Board view` na samoj Analizi. Prijavljeno uživo 18.9.2026 da položeno
   ima suvišan red iznad table — isti dan popravljeno uklanjanjem srednjeg
   reda; `Scan a book` je dobio svoja vrata u traci Analize (kod telefona iza
   `More tools`).
   Gde: Analyse → ikonica mreže (`Board view`) → `Board size`.
   Uradi: Otvori meni `Board view` i pomeri klizač `Board size` dok je meni
   otvoren, i uspravno i položeno.
   Treba da vidiš: Tabla se smanjuje/povećava dok je meni otvoren, bez
   zatvaranja ekrana. Položeno, iznad table ostaju samo naslov taba i traka
   Analize (bez trećeg, srednjeg reda); `Scan a book` se i dalje otvara iz
   trake (na telefonu iz `More tools`).
   Potrebno: telefon; telefon položeno.

31. [ ] **Panels sheet skida/vraća Move tree, izbor se pamti.** [180.5]
   O čemu se radi: Posle dva pokušaja istog dana (18.9.2026), četiri radnje nad
   potezom (komentar, AI komentar, NAG, brisanje) su spojene iza jednog
   dugmeta, a potez na kome stojiš je natpis u sredini navigacione palete — sve
   stalo u jedan red umesto dva.
   Gde: Analyse → `More tools` (telefon) / ikonica (Windows) → `Panels`.
   Uradi: Isključi `Move tree` u `Panels` sheet-u i posmatraj ekran; ponovo ga
   uključi; restartuj aplikaciju.
   Treba da vidiš: Stablo nestane/vrati se odmah; izbor ostaje posle ponovnog
   pokretanja; navigaciona paleta je jedan red i portretno na 360 dp.
   Potrebno: telefon; telefon položeno.

32. [ ] **Varijante iz uvezenog PGN-a su u stablu, uključujući ugnježdene.**
   [171.2]
   O čemu se radi: Isti uvoz mora da sačuva sve sporedne linije, uključujući
   varijantu unutar varijante.
   Gde: Analyse → `Move tree` panel posle uvoza PGN-a sa varijantama.
   Uradi: Uvezi PGN sa bar dve sporedne linije na istom potezu i jednom
   ugnježdenom varijantom, pa otvori stablo.
   Treba da vidiš: Sve sporedne linije se vide u stablu, uključujući ugnježdenu
   varijantu na svom mestu.
   Potrebno: Windows; PGN fajl.

33. [ ] **Van domaćeg, desni klik i Ctrl+C i dalje kopiraju FEN.** [193.5]
   O čemu se radi: Zabrana iz faze 12 važi samo unutar stavke domaćeg dok se
   rešava; van njega (slobodna taktika, Analiza) kopiranje FEN-a mora da radi
   kao ranije.
   Gde: Analyse (ili Practise → `Tactics tailored to you` → `Start training`).
   Uradi: Otvori Analizu (ili slobodnu tabl za taktiku) i probaj desni klik i
   Ctrl+C na tabli.
   Treba da vidiš: Oba puta se u clipboard-u nalazi FEN tekuće pozicije (desni
   klik dodatno pokazuje poruku o kopiranju).
   Potrebno: Windows.

## Teach

### Teach — Library i zadaci

1. [ ] **Tutorijal bez videa se ne šalje; nudi se izvoz.** [246.4]
   O čemu se radi: Učeniku ide video tutorijala, pa se tutorijal bez videa ne
   može poslati (`docs/PLAN-TUTORIJAL-VIDEO.md`, D5).
   Gde: `Teach` → `Library` → red tutorijala → `Send to student`.
   Uradi: Pritisni `Send to student` na tutorijalu bez videa, pa na tutorijalu
   sa videom.
   Treba da vidiš: Bez videa — prozor `Export the video first` sa dugmetom
   `Export video`, nijedan učenik se ne nudi. Sa videom — `Send the video to a
   student`, a posle izbora učenika `Video sent to the student.`
   Potrebno: jedan tutorijal sa videom i jedan bez; prihvaćen učenik.

2. [ ] **Brisanje tutorijala kaže ko još nije skinuo video.** [246.5]
   O čemu se radi: Video se briše sa tutorijalom, pa učenik koji ga još nije
   skinuo ostaje bez njega; ovo je jedini trenutak kad trener to može da zna
   (D13).
   Gde: `Teach` → `Library` → red tutorijala → `Delete tutorial`.
   Uradi: Pošalji video učeniku koji ga još nije skinuo, pa pritisni
   `Delete tutorial` — i `Cancel`.
   Treba da vidiš: U prozoru rečenicu „1 student has not downloaded its video
   yet, and will not be able to." Posle učenikovog skidanja te rečenice nema.
   Potrebno: poslat video koji učenik još nije skinuo.

3. [ ] **Učenik ne vidi trenerove tutorijale u Biblioteci.** [246.6]
   O čemu se radi: Tutorijal do učenika stiže samo kao poslat video, pa ga više
   nema na učenikovoj polici (D6); trenerove pojedinačne pozicije ostaju.
   Gde: (kao učenik) `Teach` → `Library`.
   Uradi: Pogledaj tutorijale i pozicije.
   Treba da vidiš: Nijedan trenerov tutorijal; trenerove sačuvane pozicije i
   dalje.
   Potrebno: trener koji ima i tutorijal i sačuvanu poziciju.

4. [ ] **`Add to tutorial` pretvara zadatak pozicije u rečenicu dela.** [246.15]
   O čemu se radi: Pozicija sa zadatkom (npr. skenirana „Beli vuče i
   dobija") postaje deo čija je prva rečenica taj zadatak, pa je video
   izgovara i ispisuje; ranije je išla u polje koje video ne čita.
   Gde: `Teach` → `Library` → kartica pozicije sa zadatkom → `Add to tutorial`.
   Uradi: Dodaj je u postojeći tutorijal, otvori tutorijal, izvezi video.
   Treba da vidiš: Novi deo na kraju, sa zadatkom kao komentarom početne
   pozicije; u videu taj tekst ispod table.
   Potrebno: sačuvana pozicija sa zadatkom i jedan tutorijal.

5. [ ] **Drugi mat se priznaje kao tačan.** [13.b572]
   O čemu se radi: Zadatak nađi-potez priznaje svaki potez koji matira, ne samo
   onaj naveden u knjizi; ekran tada objašnjava da je u pitanju drugi mat.
   Gde: `Home` → `My Assignments` (ili `Teach` → `Library` → `Solve`) →
   skenirani zadatak mat u jednom.
   Uradi: Rešiti zadatak mat-u-jednom drugim tačnim matom od onog koji knjiga
   navodi kao rešenje.
   Treba da vidiš: Odgovor se prihvata kao `Correct`, uz objašnjenje
   `Different checkmate from the book — but mate is mate.`.
   Potrebno: Windows i telefon; nalog trenera i učenika; PDF knjiga.

6. [ ] **Library ima šest čipova, Exercises odmah posle Tutorials.** [186.4]
   O čemu se radi: Faza 3a-4 je dodala čip `Exercises`. Od 23.9.2026 je čip za
   skupove zagonetki obrisan (zagonetke se čuvaju kao Find zadaci), pa Library
   danas ima šest čipova, ne sedam kao u originalnom opisu faze.
   Gde: Teach → `Library` → `Open library`.
   Uradi: Otvori Library i pogledaj red čipova, pa izaberi čip `Exercises`.
   Treba da vidiš: Čipovi su `All`, `Tutorials`, `Exercises`, `Positions`,
   `Analyses`, `Recordings` — `Exercises` odmah posle `Tutorials`. Pod njim su
   dva reda filtera (šta zadatak traži, i odakle je); pod čipom `Positions` tih
   redova nema.
   Potrebno: Windows i telefon.

7. [ ] **Biblioteka ima šest čipova; pozicija iz sobe i iz knjige su obe pod
   Positions.** [175.7]
   O čemu se radi: Od faze 5 je Library dobio svoja vrata na tabu Teach.
   Napomena: čip za skupove zagonetki koji je originalno bio deo ovog spiska je
   23.9.2026 obrisan (zagonetke se čuvaju kao Find zadaci), a čip `Exercises`
   je dodat fazom 3a-4 — današnji spisak je zato drugačiji od izvornog opisa.
   Gde: Teach → `Library` → `Open library`.
   Uradi: Otvori Library, pogledaj čipove, pa otvori jednu poziciju iz sobe i
   jednu skeniranu iz knjige (obe pod `Positions`).
   Treba da vidiš: Čipovi su `All`, `Tutorials`, `Exercises`, `Positions`,
   `Analyses`, `Recordings`; pretraga postoji. Pozicija iz sobe i pozicija
   skenirana iz knjige (sa navedenim izvorom) su obe pod `Positions`. Red
   tutorijala nudi `Send`/`Export video`/`Delete` i otvara studio; sačuvana
   analiza se otvara cela (sa varijantama i komentarima); snimak otvara `Play`.
   Potrebno: Windows i telefon.

8. [ ] **Sačuvan Find zadatak pokazuje rešenje bez rednog broja.** [198.3]
   O čemu se radi: Pošto je Find jedan potez, rešenje sačuvanog zadatka se
   ispisuje kao sâm potez i njegove prihvaćene alternative, bez brojanja poteza
   i bez starih „čipova za korake“.
   Gde: Teach → `Library` → `Open library` → čip `Exercises` → svoj sačuvan
   Find zadatak.
   Uradi: Otvori bilo koji svoj sačuvan `Find the move` zadatak koji ima bar
   jednu prihvaćenu alternativu.
   Treba da vidiš: Ispod naslova zadatka piše rešenje u obliku poput „Qh5 (or
   Qf3)“ — bez rednog broja poteza (nema „1.“) i bez ijednog čipa koraka.
   Potrebno: Windows i telefon.

9. [ ] **Potez na tabli u editoru zadatka postaje alternativa.** [198.4]
   O čemu se radi: U ekranu za izmenu sačuvanog Find zadatka, svaki novi potez
   odigran na tabli se dodaje kao prihvaćena alternativa; može se ukloniti
   čipom.
   Gde: Teach → `Library` → `Open library` → čip `Exercises` → svoj Find
   zadatak (otvara editor).
   Uradi: Odigraj na tabli potez koji nije već među prihvaćenim. Zatim pritisni
   „x“ na čipu te nove alternative. Na kraju pritisni `Save`.
   Treba da vidiš: Novi potez se odmah pojavi kao čip alternative sa „x“ za
   uklanjanje; glavni (prvi) potez nema „x“. Posle `Save` lista u Library
   pokazuje izmenjeno rešenje.
   Potrebno: Windows i telefon.

10. [ ] **Skeniran zadatak sa odštampanim rešenjem se otvara u istom editoru.**
   [192.7]
   O čemu se radi: Ekran za izmenu zadatka je jedan, bez obzira da li je
   zadatak napravljen u Preparation ili je sken iz knjige sa odštampanim
   rešenjem.
   Gde: Teach → `Library` → `Open library` → čip `Exercises` → svoj skeniran
   zadatak sa rešenjem.
   Uradi: Otvori sopstveni skeniran Find zadatak koji ima odštampano rešenje
   (nastao skeniranjem knjige).
   Treba da vidiš: Otvori se isti ekran editora kao za ručno napravljen zadatak
   — ime, tabla okrenuta na stranu na potezu, rešenje i mogućnost dodavanja
   alternativa.
   Potrebno: Windows i telefon; PDF knjiga.

11. [ ] **Trenerov zadatak i sken bez rešenja i dalje otvaraju Analizu.**
   [192.9]
   O čemu se radi: Editor zadatka se otvara samo za sopstvene zadatke; tuđi
   zadatak (trenerov, kod učenika) i skeniran materijal bez odštampanog rešenja
   i dalje idu u običnu Analizu, ne u editor.
   Gde: Teach → `Library` → `Open library` → čip `Exercises` (ili `Positions`).
   Uradi: Kao učenik otvori zadatak koji ti je poslao trener. Zatim otvori sken
   bez odštampanog rešenja.
   Treba da vidiš: Oba puta se otvara Analyse (obična tabla/stablo), a ne ekran
   za izmenu zadatka.
   Potrebno: Windows i telefon; nalog trenera i učenika; PDF knjiga.

12. [ ] **Izlazak iz editora zadatka pita samo kad ima nesačuvane izmene.**
   [192.10]
   O čemu se radi: Uobičajeno pravilo za sve editore u aplikaciji — čuva se od
   gubljenja rada, ali ne dosađuje kad ništa nije promenjeno.
   Gde: Teach → `Library` → `Open library` → čip `Exercises` → svoj zadatak.
   Uradi: Otvori svoj zadatak, odigraj novi potez (nesačuvana izmena) i pokušaj
   da izađeš sa ekrana. Zatim otvori isti zadatak bez ijedne izmene i izađi.
   Treba da vidiš: Prvi put se pojavljuje pitanje da li da se izmena odbaci;
   drugi put se izlazi bez ikakvog pitanja.
   Potrebno: Windows i telefon.

13. [ ] **Redovi pozicija/zadataka imaju sličicu table, veći pregled na dodir.**
   [186.5]
   O čemu se radi: Svaki red pozicije ili zadatka u Library-ju nosi malu
   sličicu table (okrenutu na stranu na potezu); dodir na sličicu otvara veći
   pregled sa imenom, zadatkom i tekstom ko je na potezu.
   Gde: Teach → `Library` → `Open library` → čip `Exercises` ili `Positions`.
   Uradi: Na telefonu otvori Library, pronađi zadatak za crnog i dodirni
   njegovu sličicu table; zatim skroluj dugačku listu.
   Treba da vidiš: Sličica zadatka za crnog je okrenuta ka crnom. Dodir otvara
   veću tablu sa imenom, zadatkom i tekstom „White to move“/„Black to move“, i
   dugmetom `Open`. Lista se skroluje glatko, bez sekanja.
   Potrebno: telefon.

14. [ ] **„Play the move“ na praznoj tabli otvara novi Find zadatak.** [198.5]
   O čemu se radi: Ovo je isti tok koji je vlasnik već potvrdio uživo 20.9.2026
   kao stavku 196 — ovde se ponovo proverava posebno, kao deo brisanja stare
   mašinerije za nizove poteza.
   Gde: Teach → `Preparation` → `Open` → postavi poziciju, ne igraj ništa →
   `Make exercise`.
   Uradi: Sa nameštenom pozicijom i bez odigranog poteza pritisni
   `Make exercise`, pa `Play the move`. Odigraj potez kao rešenje.
   Treba da vidiš: Otvori se ekran `New exercise` sa tom pozicijom; posle
   odigranog poteza `Save` postaje dostupan i zadatak se čuva pod čipom
   `Exercises`.
   Potrebno: Windows i telefon.

15. [ ] **Provera pri čuvanju predlaže dodatne pobedničke poteze (≤7 figura).**
   [187.1]
   O čemu se radi: Pri čuvanju Find zadatka sa najviše 7 figura, pravi
   tablebase proverava da li odigrani potez drži dobitak i, ako ima još poteza
   koji ga drže, nudi da se dodaju kao alternative.
   Gde: Teach → `Preparation` → `Open` → pozicija sa ≤7 figura →
   `Make exercise` → `Find the move`.
   Uradi: Postavi poziciju sa najviše 7 figura gde više poteza drži dobitak,
   odigraj jedan od njih kao rešenje i sačekaj.
   Treba da vidiš: Pre nego što se pojavi predlog, lista rešenja se ne menja.
   Posle par sekundi piše koji još potezi drže dobitak i nudi se `Accept`;
   posle dodira se u rešenju vidi „(or …)“.
   Potrebno: Windows; tablebase (pokreni.ps1 [5]).

16. [ ] **Potez koji ispušta dobitak dobija upozorenje bez ponude za
   prihvatanje.** [187.2]
   O čemu se radi: Isti tablebase-proverа, suprotan slučaj: ako odigrani potez
   baca dobitak, provera to kaže bez dugmeta za prihvatanje dodatne
   alternative.
   Gde: Teach → `Preparation` → `Open` → pozicija sa ≤7 figura →
   `Make exercise` → `Find the move`.
   Uradi: Na poziciji sa dobitkom odigraj potez koji ispušta dobitak (npr. vodi
   u remi) kao rešenje zadatka.
   Treba da vidiš: Pojavljuje se upozorenje o tome, bez dugmeta `Accept`.
   Potrebno: Windows; tablebase (pokreni.ps1 [5]).

17. [ ] **„Win“ na remi poziciji ne blokira čuvanje.** [187.3]
   O čemu se radi: Kad je krajnji ishod nemoguć (remi pozicija, ≤7 figura) za
   cilj „Win“, provera to kaže rečenicom, ali `Save` ostaje dostupan — trener
   ipak odlučuje.
   Gde: Teach → `Preparation` → `Open` → remi pozicija (≤7 figura) →
   `Make exercise` → `Win`.
   Uradi: Postavi remi poziciju (≤7 figura), izaberi cilj `Win` i sačekaj
   proveru.
   Treba da vidiš: Piše da se protiv savršene odbrane cilj ne može ispuniti,
   ali `Save` i dalje radi.
   Potrebno: Windows; tablebase (pokreni.ps1 [5]).

18. [ ] **Provera motorom upozorava na slab potez (preko 7 figura).** [187.4]
   O čemu se radi: Sa više od 7 figura tablebase se ne koristi — pravi motor
   procenjuje da li je odigrani potez slabiji od najboljeg za više od pešaka i
   po.
   Gde: Teach → `Preparation` → `Open` → pozicija sa preko 7 figura →
   `Make exercise` → `Win` ili `Draw or better`.
   Uradi: Na poziciji sa preko 7 figura odigraj potez znatno slabiji od
   motorovog kao rešenje. Dok motor razmišlja, probaj `Save`.
   Treba da vidiš: Pojavljuje se rečenica „The engine prefers …“ sa `Accept`;
   dok motor razmišlja, `Save` ostaje dostupan.
   Potrebno: Windows; debug build.

19. [ ] **Provera bez interneta tiho odustaje, čuvanje ostaje moguće.** [187.5]
   O čemu se radi: Kad tablebase ili motor ne mogu da odgovore (nema
   interneta), provera se ne zaglavljuje — „Checking…“ nestaje samo od sebe
   posle desetak sekundi.
   Gde: Teach → `Preparation` → `Open` → `Make exercise` → `Win` ili
   `Draw or better`.
   Uradi: Isključi internet, sačuvaj zadatak sa ciljem koji traži tablebase
   odgovor, i posmatraj poruku „Checking…“.
   Treba da vidiš: „Checking…“ nestane sama od sebe za desetak sekundi, ništa
   se ne prikazuje kao nalaz, a `Save` je bio dostupan sve vreme.
   Potrebno: Windows.

20. [ ] **Promena cilja sa Win na Draw or better skida stari nalaz.** [187.7]
   O čemu se radi: Nalaz provere važi za konkretan cilj; kad se cilj promeni,
   stari nalaz se ne sme zadržati kao da još važi.
   Gde: Teach → `Preparation` → `Open` → `Make exercise` → `Win`.
   Uradi: Sačekaj nalaz provere za cilj `Win`, pa promeni cilj na
   `Draw or better`.
   Treba da vidiš: Stari nalaz (upozorenje ili predlog za `Win`) nestaje čim se
   cilj promeni.
   Potrebno: Windows.

21. [ ] **Partija-zadatak ne traži odigranu liniju, samo poziciju.** [186.3]
   O čemu se radi: Za razliku od Find (koje traži odigran potez kao rešenje),
   zadatak tipa partija (Win / Draw or better / Play N moves) treba samo
   nameštenu poziciju.
   Gde: Teach → `Preparation` → `Open` → postavi poziciju (ne igraj ništa) →
   `Make exercise` → `Win` (ili `Draw or better`, `Play N moves`).
   Uradi: Postavi poziciju u Preparation, ne odigravaj nijedan potez, i izaberi
   `Make exercise` sa ciljem `Win`.
   Treba da vidiš: Dijalog za podešavanje partije se otvara bez ikakvog zahteva
   za odigranim potezom.
   Potrebno: Windows.

22. [ ] **Prazna tabla u Make exercise nudi „Play the move“, ne samo crvenu
   poruku.** [185.1]
   O čemu se radi: Vlasnik je 18.9.2026 primetio da stara crvena poruka ne kaže
   kako da se u istoj radnji postavi pozicija i odigra rešenje. To je rešeno u
   fazi 14 (20.9.2026, stavka 196): umesto poruke bez radnje, dijalog nudi
   dugme `Play the move` koje otvara ekran za odigravanje rešenja.
   Gde: Teach → `Preparation` → `Open` → postavi poziciju, ne igraj ništa →
   `Make exercise`.
   Uradi: Postavi poziciju u Preparation, ne odigravaj nijedan potez, i
   pritisni `Make exercise`.
   Treba da vidiš: Umesto same poruke o grešci, prikazuje se objašnjenje i
   dugme `Play the move`; dugmad pod `Win` i `Draw or better` se ne nude dok se
   ne odigra potez.
   Potrebno: Windows.

23. [ ] **Sačuvan zadatak se pojavljuje u Library pod čipom Exercises.**
   [185.4]
   O čemu se radi: Vlasnik je 18.9.2026 prijavio da se posle čuvanja nije jasno
   videlo šta je zadatak a šta gola pozicija. Faza 10 (stavka 191, Library
   razdvaja pozicije od zadataka) i faza 11 (stavka 192, sačuvan zadatak se
   ponovo otvara u editoru zadatka) su to rešile.
   Gde: Teach → `Preparation` → `Open` → `Make exercise` → odigraj rešenje →
   `Save`.
   Uradi: Napravi i sačuvaj Find zadatak pod novim imenom.
   Treba da vidiš: Posle `Save` piše poruka „Exercise saved.“, a zadatak se
   pojavljuje u Library pod čipom `Exercises`, pod svojim imenom — ne pod
   `Positions`.
   Potrebno: Windows.

24. [ ] **Red tutorijala koji se crta ima ikonu filma i vraća na pravu traku.**
   [143.2]
   O čemu se radi: Sakriveni render mora da se može ponovo naći sa liste.
   Gde: `Teach` → `Library`, dok se izvoz crta u pozadini.
   Uradi: Dok se izvoz iz prethodne provere crta (posle `Hide`), otvori `Teach`
   → `Library`.
   Treba da vidiš: Red tog tutorijala ima ikonu filma (tooltip
   `Rendering — show progress`) umesto kamere; klik ponovo otvara traku sa
   pravim procentom.
   Potrebno: Windows i telefon; server.

25. [ ] **Zastareo (obrisan) film gubi dugme za preuzimanje.** [136.5]
   O čemu se radi: Server pamti ime fajla poslednjeg izvezenog videa za svaki
   tutorijal. Ako je taj MP4 u međuvremenu obrisan sa diska (ručno, ili mu je
   istekao rok), red tog tutorijala mora da prestane da nudi preuzimanje linka
   koji više ne radi.
   Gde: `Teach` → `Library` → (red tutorijala koji ima izvezen film).
   Uradi: Izvezi neki tutorijal kao video (`Export video`). Na serveru ručno
   obriši taj MP4 iz chess_backend/exports/. Osveži Biblioteku (`Refresh`) ili
   je ponovo otvori.
   Treba da vidiš: Na redu se pojavljuje rečenica da je film obrisan da bi se
   sačuvao prostor i da treba ponovo izvesti; dugme `Download video` nestaje sa
   reda, ostaje samo `Export video`.
   Potrebno: Windows i telefon; server.

26. [ ] **Red tutorijala staje na uzak telefon (360 dp).** [136.6]
   O čemu se radi: Kad je ova stavka pisana (9.9.2026) tutorijali su postojali
   samo na Windowsu, pa vlasnik nije imao odakle da dođe do njih sa telefona.
   Otkad je šilj reorganizovan (Teach tab) i studio dobio raspored za telefon,
   Biblioteka i red tutorijala su dostupni i na Androidu — proveri ponovo da li
   sve četiri ikonice i naslov staju.
   Gde: `Teach` → `Library` → (red tutorijala koji ima izvezen film), na
   telefonu od 360 dp.
   Uradi: Na telefonu prijavi se istim nalogom, otvori `Teach` → `Library`,
   pronađi red tutorijala koji ima film.
   Treba da vidiš: Naslov i sve ikonice reda (izvoz/renderuje se, preuzimanje,
   slanje učeniku, brisanje) su vidljivi i dohvatljivi — ništa se ne seče van
   ekrana na 360 dp.
   Potrebno: telefon; server; telefon položeno.

27. [ ] **Birač tutorijala javlja da server nije dostupan.** [14.b635]
   O čemu se radi: Stara ruta (dodavanje pozicije u lekciju preko posebnog
   birača „Mojih pozicija") više ne postoji — pojedinačno biranje pozicija je
   sada u uređivaču domaćeg, a birač koji se otvara sa „Add to tutorial" u
   Biblioteci danas javlja grešku servera drugačijim tekstom.
   Gde: `Teach` → `Library` → kartica pozicije/skenirane pozicije →
   `Add to tutorial`.
   Uradi: Ugasiti backend, pa na nekoj poziciji u Biblioteci pritisnuti
   `Add to tutorial`.
   Treba da vidiš: Dijalog kaže `Could not reach server.` uz dugme `Try again`,
   ne „No tutorials with steps found...".
   Potrebno: Windows i telefon; server.

28. [ ] **Brisanje tutorijala briše i snimak na serveru.** [139.7]
   O čemu se radi: Naracija poslata na server (faza 3) živi u
   chess_backend/uploads/narration/; brisanje tutorijala treba da povuče i taj
   fajl. Pretpostavlja stavku 138 — snimak već postoji na uređaju. Snimanje
   glasa preko tutorijala je pisano kao Windows-only (studio tada nije postojao
   na telefonu); otkad studio ima raspored za uzak ekran, `Record narration` je
   i tamo u `More` meniju, pa vredi probati i na telefonu, ne samo na Windowsu.
   Gde: `Teach` → `Library` → (red tutorijala) → `Delete tutorial`.
   Uradi: Obriši tutorijal koji ima poslat snimak; posle toga proveri
   chess_backend/uploads/narration/ na serveru.
   Treba da vidiš: Fajl snimka za taj tutorijal nestaje iz foldera (poznato i
   otvoreno: brisanje ne uklanja snimak na samom uređaju, samo na serveru).
   Potrebno: Windows i telefon; sačuvan tutorijal sa poslatim snimkom; server.

29. [ ] **Tri ikonice na redu tutorijala vidljive na telefonu.** [133.1]
   O čemu se radi: Svaki red sačuvanog tutorijala nosi tri ikonice
   (video/izvoz, pošalji, obriši); na telefonu (ne na Windows prozoru) sve tri
   moraju da se vide i mogu se pogoditi prstom, i kod dugih imena.
   Gde: `Teach` → (kartica) `Tutorials` → `Saved tutorials`.
   Uradi: Otvori `Saved tutorials` na telefonu i pronađi tutorijal sa dugim
   imenom.
   Treba da vidiš: Sve tri ikonice
   (`Export video`/`Rendering — show progress`/`Download video`,
   `Send to student`, `Delete tutorial`) se vide i svaka se pogađa prstom bez
   teškoća, čak i kod dugog imena.
   Potrebno: telefon.

30. [ ] **Kod učenika polica ne pokazuje trenerove tutorijale kao svoje.**
   [129.1]
   O čemu se radi: Biblioteka razdvaja tutorijale po vlasništvu — učenik na
   svojoj polici vidi samo svoje, ne i sve što je trener ikad sačuvao.
   Gde: `Teach` → (kartica) `Tutorials` → `Saved tutorials` (na nalogu
   učenika).
   Uradi: Uloguj se kao učenik i otvori `Saved tutorials`.
   Treba da vidiš: Na polici nema trenerovih tutorijala — samo ono što je
   učenik sam napisao (ili prazna polica ako ništa nije napisao).
   Potrebno: Windows; nalog trenera i učenika.

31. [ ] **Kod trenera su svi tutorijali na mestu.** [129.2]
   O čemu se radi: Na svom nalogu trener i dalje vidi sve svoje tutorijale i
   ima pristup akcijama nad njima (izvoz videa, slanje, brisanje).
   Gde: `Teach` → (kartica) `Tutorials` → `Saved tutorials`.
   Uradi: Otvori `Saved tutorials` na trenerovom nalogu.
   Treba da vidiš: Svi trenerovi tutorijali su na mestu, svaki red ima ikonice
   za video, slanje i brisanje.
   Potrebno: Windows.

32. [ ] **„Saved tutorials“ otvara Library na čipu Tutorials, bez dijaloga.**
   [179.11]
   O čemu se radi: Posle vlasnikove prijave 17.9.2026 (dijalog na telefonu bez
   naslova tutorijala, bez liste položeno), dijalog je uklonjen — dugme sada
   direktno otvara Library filtriranu na sopstvene tutorijale.
   Gde: Teach → kartica `Tutorials` → `Saved tutorials`.
   Uradi: Otvori `Saved tutorials` na telefonu (uspravno i položeno), na
   Windows-u, i kao učenik kome je trener poslao tutorijal.
   Treba da vidiš: Otvara se Library na čipu `Tutorials`/`Mine`. Portretno:
   naslov tutorijala je čitljiv, četiri dugmeta (video, preuzmi, pošalji,
   obriši) su u redu ispod naslova. Položeno: čipovi i pretraga odlaze nagore
   pri skrolu, redovi ostaju dostupni. Trenerovi tutorijali kod učenika („From
   trainer“) nemaju dugmad, dodir kaže da je tutorijal trenerov. Na Windows-u
   dugmad ostaju u istom redu sa naslovom.
   Potrebno: Windows i telefon.

### Teach — Position Scanner

1. [ ] **PDF bez dijagrama ili zaštićen lozinkom.** [13.b602]
   O čemu se radi: Skener sad prepoznaje kad na poslatim stranama nema nijednog
   šahovskog dijagrama i to jasno kaže; PDF zaštićen lozinkom nema poseban
   tretman u kodu, pa verovatno pada na opštu grešku.
   Gde: `Analyse` → `Scan a book` (ili `Teach` → `Scan a book`).
   Uradi: Poslati na skeniranje PDF bez ijednog šahovskog dijagrama; zatim
   poslati PDF zaštićen lozinkom.
   Treba da vidiš: Za PDF bez dijagrama: razumljiva poruka koja pominje da
   dijagram nije nađen na tim stranama. Za PDF sa lozinkom: proveriti da li se
   dobija razumljiva poruka ili samo generička greška o čitanju dokumenta — to
   drugo je otvoreno pitanje vredno beleženja.
   Potrebno: Windows i telefon; PDF knjiga.

2. [ ] **Skeniranje PDF-a i dalje radi za običan broj pokušaja.** [169.6]
   O čemu se radi: Provera da normalna upotreba skenera (koja ne udara u dnevno
   ograničenje) nije pokvarena kasnijim izmenama skenera.
   Gde: Teach → `Scan a book` → `Select PDF` → `Scan`.
   Uradi: Skeniraj nekoliko strana knjige, u granicama uobičajenog broja
   pokušaja u danu.
   Treba da vidiš: Skeniranje se izvrši i vrati pozicije, bez poruke o
   dostignutom ograničenju.
   Potrebno: Windows; PDF knjiga.

3. [ ] **Filter „needs a look" nad mešanim skupom.** [13.b604]
   O čemu se radi: Filter za pozicije koje treba dodatno pogledati (nekadašnje
   „traži pogled") dosad je viđen samo kao sve-ili-ništa; treba probati na
   knjizi gde je stvarno mešano.
   Gde: `Teach` → `Scan a book` → poslati knjigu → pregled rezultata
   skeniranja.
   Uradi: Skenirati knjigu čiji rezultat ima i pozicije koje trebaju pogled i
   one koje ne, pa uključiti čip koji broji koliko pozicija „… needs a look".
   Treba da vidiš: Filter stvarno suzi spisak na deo skupa (ne 0 i ne sve), a
   broj u čipu odgovara broju prikazanih pozicija.
   Potrebno: Windows i telefon; PDF knjiga.

4. [ ] **Table pri skeniranju sa slikom se vide jedna po redu na telefonu.**
   [232.5]
   O čemu se radi: Posle skeniranja knjige sa dijagramima kao slikama, na
   telefonu se rezultati (predložene/pročitane table) vide jedna ispod druge
   (jedna po redu) — ranije je mreža kartica bila visine 0 px ispod panela i
   ništa se nije videlo.
   Gde: `Teach` → `Scan a book` → izaberi knjigu sa dijagramima kao slikama →
   `Read the pictures`.
   Uradi: Na telefonu, skeniraj nekoliko strana knjige čiji su dijagrami slike,
   i pogledaj rezultat.
   Treba da vidiš: Table se vide, raspoređene jedna po redu (jedna kolona), ne
   prazna/nulte visine mreža.
   Potrebno: telefon; telefon položeno; PDF knjiga.

5. [ ] **Merenje: trajanje čitanja paketa slika na dubini 16.** [232.7]
   O čemu se radi: Deo iz §7 plana skenera slika: treba zabeležiti koliko traje
   čitanje celog paketa strana na dubini 16 (broj tabli i vreme) i koliko
   „confident“ predloga je ručno ispravljeno.
   Gde: `Teach` → `Scan a book` → izaberi knjigu sa dijagramima kao slikama →
   strane → `Read` (dubina 16).
   Uradi: Pokreni čitanje celog paketa strana (do 40) na dubini 16 i zabeleži
   vreme i broj pročitanih tabli. Prebroj koliko predloga označenih kao
   „pouzdano“ (confident) je trebalo ručno ispraviti.
   Treba da vidiš: Zabeleženi broj tabli, ukupno vreme čitanja i broj ručno
   ispravljenih „confident“ predloga — ovo je merenje za dokumentaciju, nema
   unapred određenog praga prolaza/pada.
   Potrebno: Windows; PDF knjiga.

6. [ ] **Skener na engleskom imenuje koji je od tri problema.** [132.3]
   O čemu se radi: Poruke skenera (skenirana knjiga bez teksta / tekst sa
   dijagram-slikama / nepoznat font) su na engleskom — detalji su u posebnim
   stavkama 107.1-107.3 iz ove liste.
   Gde: `Teach` → (kartica) `Scan a book` → `Scan` → `Select PDF`.
   Uradi: Otvori PDF koji nije čitljiva knjiga sa dijagramima šahovskog fonta
   (skeniran, ili sa dijagramima kao slikama) i pritisni `Scan`.
   Treba da vidiš: Poruka je na engleskom i kaže koja od tri stvari nije u redu
   (nema teksta / dijagrami su slike / nepoznat font).
   Potrebno: Windows i telefon; PDF knjiga.

7. [ ] **Skeniran PDF bez ijednog dijagrama kaže to, bez krivice na font.**
   [107.1]
   O čemu se radi: Skener razlikuje tri razloga zašto ne može da pročita knjigu
   i za svaki ima svoju rečenicu. Od 22–23.9.2026 knjiga čiji su dijagrami
   slike ne dobija odbijanje nego odmah otvara kalibraciju, pa se ova poruka
   vidi samo kad na izabranim stranama nema nijednog dijagrama.
   Gde: `Teach` → (kartica) `Scan a book` → `Scan` → `Select PDF`.
   Uradi: Izaberi skeniran PDF (strane su slike, tekst ne može da se markira) u
   kome nema nijednog šahovskog dijagrama — npr. skeniran dopis ili članak. Ako
   se ne otvori kalibracija, unesi strane i pritisni `Scan`.
   Treba da vidiš: Poruka na dnu ekrana: „This book was scanned as an image,
   and no chess diagram was found in the pictures on those pages. Try other
   pages." Ne otvara se kalibracija i ne pominje se font.
   Potrebno: Windows i telefon; PDF knjiga.

8. [ ] **PDF sa tekstom a bez dijagrama kaže šta je tražio.** [107.2]
   O čemu se radi: Drugi od tri razloga: strane imaju tekst, ali na njima nema
   dijagrama ni u šahovskom fontu ni kao slike. Aplikacija tada pokazuje svoju
   rečenicu, napisanu 22.9.2026, koja kaže šta je traženo — font se tu pominje
   kao ono što je traženo, a ne kao krivac (to ostaje samo trećoj poruci, za
   font koji skener ne poznaje). Knjiga čiji su dijagrami slike ovde ne dolazi:
   ona otvara kalibraciju.
   Gde: `Teach` → (kartica) `Scan a book` → `Scan` → `Select PDF`.
   Uradi: Izaberi PDF sa tekstom koji može da se markira mišem, a bez šahovskih
   dijagrama (običan članak ili uputstvo), ili knjigu čiji su dijagrami
   nacrtani linijama. Unesi strane i pritisni `Scan`.
   Treba da vidiš: Poruka na dnu ekrana: „No diagram was found on those pages —
   neither in a chess font nor as a picture. Diagrams drawn with lines cannot
   be read yet." Ako ti smeta što se u njoj pominje font, to je odluka o
   tekstu, ne kvar — zapiši je kao nalaz.
   Potrebno: Windows i telefon; PDF knjiga.

9. [ ] **Prevelik PDF imenuje granicu i traži deljenje.** [107.3]
   O čemu se radi: Granica veličine fajla za skeniranje se od 22.9.2026 podigla
   na 100 MB (dok je vlasnik jedini korisnik); poruka i dalje imenuje trenutnu
   granicu i traži deljenje fajla, umesto starog generičkog „Skeniranje nije
   uspelo (500)”.
   Gde: `Teach` → (kartica) `Scan a book` → `Scan` → `Select PDF`.
   Uradi: Izaberi PDF veći od 100 MB i pritisni `Scan`.
   Treba da vidiš: Poruka imenuje granicu („larger than 100 MB”) i kaže da PDF
   treba podeliti na manje delove. Ne sme da se pojavi generička poruka o
   serverskoj grešci (500).
   Potrebno: Windows i telefon; PDF knjiga.

10. [ ] **Knjiga koja radi i dalje radi (regresiona provera).** [107.4]
   O čemu se radi: Ova stavka proverava da popravka poruka o tri problema nije
   usput pokvarila normalno skeniranje knjige koja se čita bez greške.
   Gde: `Teach` → (kartica) `Scan a book` → `Scan` → `Select PDF`.
   Uradi: Skeniraj `chessboard.pdf`, strane 1–40 (ili bilo koju knjigu za koju
   znaš da radi sa fontom SkakNew-Diagram / LaTeX skak).
   Treba da vidiš: Skeniranje prođe normalno i vrati očekivan broj pozicija
   (npr. 31 pozicija za `chessboard.pdf` strane 1–40), bez greške.
   Potrebno: Windows i telefon; PDF knjiga.

11. [ ] **Poruke o greškama se ne dupliraju ni ostaju.** [107.5]
   O čemu se radi: Svaki zahtev za skeniranje se obrađuje nezavisno — nijedna
   poruka o grešci se ne pamti niti ponavlja preko sledećeg pokušaja.
   Gde: `Teach` → (kartica) `Scan a book` → `Scan` → `Select PDF`.
   Uradi: Izazovi istu grešku dvaput zaredom (npr. dva puta izaberi skeniranu
   knjigu), pa zatim skeniraj knjigu koja radi.
   Treba da vidiš: Poruka o grešci se ne pojavljuje dvaput na ekranu odjednom,
   i nestaje čim sledeće skeniranje uspe — ne ostaje zalepljena preko novog
   rezultata.
   Potrebno: Windows i telefon; PDF knjiga.

12. [ ] **New In Chess se čita fontom (NICRoest), bez kalibracije.** [236.5]
   O čemu se radi: Za PDF „New In Chess“ skener prepoznaje treću mapu fonta
   dijagrama (NICRoest, pored ranijih SkakNew i DiagramTTFritz) i čita ga bez
   potrebe za kalibracijom preko slika.
   Gde: `Teach` → `Scan a book` → `Select PDF` → izaberi knjigu.
   Uradi: Izaberi PDF knjigu New In Chess (`9087.pdf`) u Position Scanner-u i
   pokreni `Scan` na nekoliko prvih strana.
   Treba da vidiš: Skener čita dijagrame direktno (nema poziva na kalibraciju
   preko slika); pronađeni broj dijagrama i pozicije na ranim stranama
   odgovaraju sadržaju knjige (npr. početna pozicija i naredna pozicija na prve
   dve strane sa dijagramima).
   Potrebno: Windows; PDF knjiga.

13. [ ] **Drugi nalog nasleđuje tuđe postavljene table iste knjige.** [229.1]
   O čemu se radi: Kalibracija (postavljene table) knjige sa dijagramima kao
   slikama je deljena po fajlu (po njegovom otisku), ne po nalogu — drugi nalog
   koji izabere isti PDF vidi već postavljene table sa napomenom da ih je
   postavio neko drugi.
   Gde: `Teach` → `Scan a book` → `Select PDF` → izaberi knjigu sa dijagramima
   kao slikama.
   Uradi: Na nalogu A, kalibriši knjigu (npr. Back to Basics) — postavi bar
   jednu tablu. Na nalogu B izaberi isti PDF.
   Treba da vidiš: Nalog B otvara kalibraciju sa tablama koje je postavio nalog
   A, svaka sa napomenom
   `Set up by another user: check it against the picture`.
   Potrebno: Windows; drugi uređaj; PDF knjiga; nalog trenera i učenika.

14. [ ] **Tuđe table se ne računaju dok se ne potvrde.** [229.2]
   O čemu se radi: Table koje je postavio drugi nalog ne ulaze u kalibraciju
   (za čitanje) dok se na svakoj ne pritisne `Correct` (ili `Edit`); dok ima
   nepotvrđenih, `Done — choose pages` je ugašeno; posle potvrde tabla se pamti
   i na tekućem nalogu.
   Gde: `Teach` → `Scan a book` → `Select PDF` → izaberi knjigu sa dijagramima
   kao slikama.
   Uradi: Na nalogu B (iz prethodne provere), pre potvrde bilo koje table,
   proveri dugme `Done — choose pages`. Zatim potvrdi svaku tablu preko
   `Correct` (ili `Edit`, pa sačuvaj).
   Treba da vidiš: Pre potvrde, `Done — choose pages` je ugašeno. Posle potvrde
   svih tabli preko `Correct`/`Edit`, dugme postaje aktivno, a table ostaju
   zapamćene i kad se ekran ponovo otvori na nalogu B.
   Potrebno: Windows; drugi uređaj; PDF knjiga; nalog trenera i učenika.

15. [ ] **Nalog sa nepotpunom kalibracijom dobija samo ono što mu fali.**
   [229.3]
   O čemu se radi: Ako nalog ima svoju nedovršenu kalibraciju iste knjige (npr.
   bez crne dame), od tuđih tabli dobija samo onu koja upravo tu figuru dodaje
   — ne sve table drugog naloga.
   Gde: `Teach` → `Scan a book` → `Select PDF` → izaberi knjigu sa dijagramima
   kao slikama.
   Uradi: Napravi na nalogu B nepotpunu kalibraciju (npr. bez table koja
   pokazuje crnu damu), dok nalog A ima potpuniju kalibraciju iste knjige sa
   više tabli.
   Treba da vidiš: Nalog B dobija na predlog samo onu tablu (ili table) koja
   dodaje figuru koja mu nedostaje, a ne kompletan skup tabli sa naloga A.
   Potrebno: Windows; drugi uređaj; PDF knjiga; nalog trenera i učenika.

16. [ ] **Ime onoga ko je postavio tablu se nigde ne prikazuje.** [229.4]
   O čemu se radi: Napomena o tuđoj tabli kaže samo da ju je postavio „another
   user“, bez imena ili druge identifikacije tog naloga.
   Gde: `Teach` → `Scan a book` → `Select PDF` → izaberi knjigu sa dijagramima
   kao slikama.
   Uradi: Pregledaj sve napomene i detalje oko tuđe (nepotvrđene) table u
   kalibraciji.
   Treba da vidiš: Nigde se ne prikazuje ime, email ili bilo koji identifikator
   naloga koji je tablu postavio — samo generička napomena da je postavio drugi
   korisnik.
   Potrebno: Windows; drugi uređaj; PDF knjiga; nalog trenera i učenika.

17. [ ] **Knjiga sa slikama se sama prepozna, bez pitanja za strane unapred.**
   [228.1]
   O čemu se radi: Kad se izabere PDF, skener kratko proverava vrstu knjige
   („Looking at the book…“), pa odmah otvara kalibraciju (nova knjiga sa
   slikama) ili `Choose the pages to read` (knjiga čija je kalibracija već
   završena) — nikad se strane ne pitaju pre kalibracije.
   Gde: `Teach` → `Scan a book` → `Select PDF`.
   Uradi: Izaberi PDF knjigu sa dijagramima kao slikama (npr. Back to Basics
   ili Silman) koju ranije nisi kalibrisao. Ponovi sa knjigom čija je
   kalibracija već završena.
   Treba da vidiš: Prvi put: kratak tekst „Looking at the book…“, pa se odmah
   otvara ekran kalibracije. Sa već kalibrisanom knjigom: odmah se otvara
   `Choose the pages to read`. Ni u jednom slučaju se strane ne pitaju pre
   toga.
   Potrebno: Windows; PDF knjiga.

18. [ ] **Knjiga u šahovskom fontu i dalje ide direktno na strane.** [228.2]
   O čemu se radi: Za knjigu čiji su dijagrami u prepoznatom šahovskom fontu
   (ne slike), posle izbora fajla se odmah vide polja `From page`/`To page` i
   dugme `Scan`, kao i pre uvođenja kalibracije za slike.
   Gde: `Teach` → `Scan a book` → `Select PDF`.
   Uradi: Izaberi PDF knjigu čiji su dijagrami u prepoznatom fontu (npr.
   `completechesscoursexcerpt.pdf`).
   Treba da vidiš: Posle izbora fajla odmah se vide polja za opseg strana i
   dugme `Scan`, bez ikakve kalibracije preko slika.
   Potrebno: Windows; PDF knjiga.

19. [ ] **Provera opsega strana pre čitanja.** [228.3]
   O čemu se radi: Na ekranu `Choose the pages to read`, neispravan opseg (kraj
   pre početka, ili preko 40 strana) se odbija porukom i ništa se ne šalje;
   ispravan opseg do 40 strana se čita.
   Gde: `Teach` → `Scan a book` → `Select PDF` → izaberi knjigu sa dijagramima
   kao slikama → potvrdi kalibraciju → `Choose the pages to read`.
   Uradi: Unesi opseg strana 60 do 50 i pritisni `Read`. Zatim unesi 1 do 41.
   Na kraju unesi 1 do 40.
   Treba da vidiš: 60–50: poruka „The last page is before the first.“ 1–41:
   poruka „At most 40 pages at a time.“ Ni u jednom od ova dva ništa se ne
   šalje serveru. 1–40: čitanje počinje.
   Potrebno: Windows; PDF knjiga.

20. [ ] **Sa izbora strana može se ući u ažuriranje kalibracije.** [228.4]
   O čemu se radi: Na ekranu izbora strana, dugme `Update the calibration`
   otvara tabelu sa već zapamćenim tablama za doradu; `Done — choose pages`
   vraća nazad na izbor strana.
   Gde: `Teach` → `Scan a book` → `Select PDF` → izaberi knjigu sa dijagramima
   kao slikama → potvrdi kalibraciju → `Choose the pages to read`.
   Uradi: Na ekranu izbora strana pritisni `Update the calibration`, pa se
   vrati preko `Done — choose pages`.
   Treba da vidiš: `Update the calibration` otvara tabelu sa zapamćenim tablama
   (iste koje su ranije postavljene). `Done — choose pages` vraća na ekran
   izbora strana.
   Potrebno: Windows; PDF knjiga.

21. [ ] **„Other pages“ posle čitanja ne dira kalibraciju; oba dugmeta staju na
   telefonu.** [228.5]
   O čemu se radi: Posle čitanja strana, dugme `Other pages` na dnu vraća na
   izbor novog opsega strana bez diranja kalibracije; na uskom telefonu (360
   dp) oba dugmeta (Other pages i ono pored njega) staju na ekran.
   Gde: `Teach` → `Scan a book` → `Select PDF` → izaberi knjigu sa dijagramima
   kao slikama → pročitaj neki opseg strana.
   Uradi: Posle uspešnog čitanja, pritisni `Other pages` i proveri da
   kalibracija nije dirnuta. Ponovi na telefonu (360 dp širine) i pogledaj da
   li oba dugmeta na dnu staju.
   Treba da vidiš: `Other pages` vraća na izbor strana, a kalibracija
   (postavljene table) ostaje ista kao pre. Na telefonu od 360 dp, oba dugmeta
   na dnu ekrana se vide cela, bez sečenja.
   Potrebno: telefon; PDF knjiga; telefon položeno.

22. [ ] **Izlazak iz kalibracije vraća na skener bez polja za strane.** [228.6]
   O čemu se radi: Ako se iz ekrana kalibracije izađe (nazad), skener pokazuje
   karticu „The diagrams in this book are pictures“ sa dugmetom `Continue`, bez
   ijednog polja za opseg strana.
   Gde: `Teach` → `Scan a book` → `Select PDF` → izaberi knjigu sa dijagramima
   kao slikama.
   Uradi: Uđi u kalibraciju nove knjige sa slikama, pa se vrati nazad (izađi iz
   kalibracije) pre nego što je završiš.
   Treba da vidiš: Skener prikazuje karticu sa tekstom
   `The diagrams in this book are pictures` i dugmetom `Continue`, bez polja za
   From page/To page.
   Potrebno: Windows; PDF knjiga.

23. [ ] **„No … in this book“ isključuje traženje figure koje knjiga nema.**
   [227.6]
   O čemu se radi: Čim je bar jedna tabla postavljena, ispod tabele
   nedostajućih figura pojavljuje se po jedno dugme za svaku figuru koje još
   nema u kalibraciji (npr. za crnu damu, oblika `No … in this book`);
   uključivanjem se ta figura više ne traži. Knjiga topovskih završnica ima
   samo šest mogućih figura, i sve mogu da se isključe preko ovih dugmadi.
   Gde: `Teach` → `Scan a book` → `Select PDF` → izaberi knjigu sa dijagramima
   kao slikama.
   Uradi: Postavi bar jednu tablu u kalibraciji, pa pogledaj dugmad za
   nedostajuće figure ispod tabele. Uključi jedno (npr. za crnu damu). Probaj i
   na knjizi topovskih završnica (samo kraljevi, topovi, pešaci).
   Treba da vidiš: Za svaku figuru koje nema u dosadašnjoj kalibraciji postoji
   dugme oblika `No … in this book`; uključeno dugme uklanja tu figuru iz onoga
   što se još traži. Na knjizi topovskih završnica, kad se svih šest mogućih
   nedostajućih figura isključi, `Read` postaje dostupno.
   Potrebno: Windows; PDF knjiga.

24. [ ] **„Improve the calibration“/„Add a board“ vraćaju tabelu tabli bez
   brisanja.** [227.7]
   O čemu se radi: Na ekranu pročitanih tabli, dugme `Improve the calibration`
   (gore desno) ili `Add a board` iz napomene vraćaju tabelu sa zapamćenim
   tablama i njihovim slikama; ništa se ne briše dok se ponovo ne pročita.
   Gde: `Teach` → `Scan a book` → `Select PDF` → izaberi knjigu sa dijagramima
   kao slikama → pročitaj strane.
   Uradi: Na ekranu rezultata čitanja pritisni `Improve the calibration` (ili
   `Add a board` iz napomene, ako je vidljiva).
   Treba da vidiš: Otvara se tabela sa svim ranije postavljenim tablama i
   njihovim slikama iz knjige; nijedna od njih nije obrisana samim otvaranjem —
   brisanje se dešava samo ako se ponovo pokrene čitanje.
   Potrebno: Windows; PDF knjiga.

25. [ ] **Figura koju kalibracija nikad nije videla se posebno naglašava, a
   polja se markiraju „?“** [227.8]
   O čemu se radi: Za staru kalibraciju bez neke figure, iznad tabli u
   kalibracionoj tabeli piše rečenica koja počinje sa
   `No board you set up shows`; na čitanju, polja sa takvom figurom se sada
   markiraju znakom „?“ (ranije je oko 8% takvih polja prolazilo neoznačeno).
   Gde: `Teach` → `Scan a book` → `Select PDF` → izaberi knjigu sa dijagramima
   kao slikama.
   Uradi: Na knjizi (npr. Silman) čija kalibracija ne pokriva neku figuru,
   pogledaj natpis iznad tabli u kalibraciji i pokreni čitanje strana koje tu
   figuru sadrže.
   Treba da vidiš: Iznad tabli u kalibraciji stoji rečenica koja počinje sa
   `No board you set up shows` i imenuje figuru koja nedostaje. Na pročitanim
   tablama, polja sa tom figurom su markirana znakom „?“ (upitnik), ne
   ostavljena neoznačena.
   Potrebno: Windows; PDF knjiga.

26. [ ] **Kalibracija se pamti tokom postavljanja, i pre nego što je gotova.**
   [227.9]
   O čemu se radi: Kalibracija se čuva postepeno posle svake
   postavljene/izmenjene/uklonjene table, ne samo kada je čitanje uspešno
   pokrenuto; izlazak pre `Read` ne gubi već postavljene table, a knjiga sa
   svim potrebnim figurama (ili sve isključenim preko „No …“) ide pravo na
   čitanje.
   Gde: `Teach` → `Scan a book` → `Select PDF` → izaberi knjigu sa dijagramima
   kao slikama.
   Uradi: Postavi jednu ili dve table u kalibraciji pa izađi bez pritiska na
   `Read`. Ponovo izaberi istu knjigu. Nastavi dok kalibracija ne pokrije sve
   figure (ili se sve preostale isključe sa „No …“ dugmadima) i probaj još
   jednom izbor iste knjige. Probaj i sa knjigom topovskih završnica (šest
   mogućih „No …“).
   Treba da vidiš: Posle ponovnog izbora knjige, kalibraciona tabela pokazuje
   ranije postavljene table (nije prazna). Kada kalibracija pokriva sve figure
   (ili su sve preostale isključene), sledeći izbor iste knjige ide pravo na
   čitanje strana, bez ponovnog pitanja za kalibraciju. Knjiga topovskih
   završnica pamti svih šest isključenja i ne pita ponovo.
   Potrebno: Windows; PDF knjiga.

27. [ ] **Listanje knjige u pretpregledu ne troši dnevni limit skeniranja.**
   [227.10]
   O čemu se radi: Prelistavanje stranica knjige u pretpregledu (browsing) ima
   svoj poseban limiter i ne troši isti dnevni limit kao stvarno skeniranje
   (čitanje) ili `Scan`.
   Gde: `Teach` → `Scan a book` → `Select PDF` → izaberi knjigu sa dijagramima
   kao slikama → `Find a board in the book` (pretpregled strana).
   Uradi: Prelistaj knjigu kroz desetak prozora od po 20 strana u pretpregledu
   (npr. preko `Find a board in the book`), pa zatim pokreni `Read` i `Scan`.
   Treba da vidiš: Ni posle desetak prozora prelistavanja se ne javlja poruka o
   prekoračenju broja skeniranja u kratkom periodu, a `Read`/`Scan` posle toga
   i dalje rade normalno.
   Potrebno: Windows; PDF knjiga.

28. [ ] **Filteri i grupni izbor na ekranu pročitanih tabli.** [226.16]
   O čemu se radi: Na ekranu potvrde pročitanih tabli, čipovi
   `All`/`To check`/`Not a position`/`Set up by me` (svaki sa brojem)
   filtriraju prikaz; `Select shown`/`Unselect shown` menjaju izbor samo
   prikazanih, a `Only the ones I set up` ostavlja izabrane samo table koje si
   sâm potvrdio u editoru (te kartice imaju napomenu `Set up by you`). `Save`
   čuva tačno ono što je izabrano.
   Gde: `Teach` → `Scan a book` → `Select PDF` → izaberi knjigu sa dijagramima
   kao slikama → pročitaj strane.
   Uradi: Na ekranu pročitanih tabli isprobaj svaki filter čip, zatim
   `Select shown`/`Unselect shown`, pa `Only the ones I set up`, i na kraju
   `Save`.
   Treba da vidiš: Svaki filter čip prikazuje samo table iz svoje kategorije.
   `Select shown`/`Unselect shown` menjaju kvačice samo na trenutno prikazanim
   tablama. `Only the ones I set up` ostavlja izabrane samo table sa napomenom
   `Set up by you`. `Save` čuva tačno onoliko tabli koliko je bilo izabrano.
   Potrebno: Windows; PDF knjiga.

29. [ ] **Postavljanje table preko editora sada zaista upisuje poziciju.**
   [225.2]
   O čemu se radi: U kalibraciji, „Set up this position“ otvara editor table sa
   slikom iz knjige pored; dugme `Generate and Set Position` treba da postavi
   tu poziciju na kalibracionu tablu i vrati na ekran kalibracije (ne dalje
   unazad).
   Gde: `Teach` → `Scan a book` → `Select PDF` → izaberi knjigu sa dijagramima
   kao slikama → `Set up this position` (na predloženoj tabli).
   Uradi: U kalibraciji, otvori editor preko `Set up this position` (ili
   `Edit`), postavi figure prema slici i pritisni `Generate and Set Position`.
   Treba da vidiš: Dijalog se zatvara i vraća na ekran kalibracije sa upravo
   postavljenom pozicijom prikazanom na toj kartici — ne na prethodni ekran
   (skener) i ne bez upisane pozicije.
   Potrebno: Windows; PDF knjiga.

### Teach — Tutorijal — uvoz iz fajla

1. [ ] **Birač fajlova nudi .pgn pored .json.** [158.1]
   O čemu se radi: Uvoz tutorijala sad prima i partije u PGN formatu, ne samo
   .json.
   Gde: `Teach` → `Tutorials` → `Import from a file`.
   Uradi: Otvori `Import from a file` i pogledaj sistemski birač fajlova.
   Treba da vidiš: Birač prikazuje i .json i .pgn fajlove.
   Potrebno: Windows; PGN fajl.

2. [ ] **Svaka partija u fajlu postaje svoj tutorijal, imenovan iz zaglavlja.**
   [158.2]
   O čemu se radi: Naslov dolazi iz PGN zaglavlja ('Beli - Crni (datum)'), ne
   iz imena fajla.
   Gde: `Teach` → `Tutorials` → `Import from a file`.
   Uradi: Uvezi .pgn fajl sa dve-tri partije.
   Treba da vidiš: Izveštaj ima red po partiji; naslov svakog je 'Beli - Crni
   (datum)' iz zaglavlja te partije, ne ime fajla.
   Potrebno: Windows; PGN fajl sa dve-tri partije.

3. [ ] **Velika baza se preseče na 50 partija, i to piše.** [158.3]
   O čemu se radi: Prvi red izveštaja mora da kaže koliko partija fajl ima i da
   je pročitano samo prvih 50 — ćutanje o preseku je greška.
   Gde: `Teach` → `Tutorials` → `Import from a file`.
   Uradi: Uvezi sopstveni Lichess izvoz (npr. 4126 partija).
   Treba da vidiš: Prvi red izveštaja kaže koliko partija fajl ima i da je
   pročitano prvih 50.
   Potrebno: Windows; uvezene partije.

4. [ ] **Poruka o pokvarenom fajlu imenuje pravi format.** [158.9]
   O čemu se radi: Poruka treba da razlikuje pokvaren PGN od pokvarenog JSON-a.
   Gde: `Teach` → `Tutorials` → `Import from a file`.
   Uradi: Preimenuj neki tekstualni fajl u .pgn i uvezi ga; zatim preimenuj
   pokvaren JSON u .json i uvezi ga.
   Treba da vidiš: Za .pgn, poruka govori o partiji (PGN-u); za .json, poruka
   govori o JSON formatu, ne o partiji.
   Potrebno: Windows; PGN fajl; PGN fajl neispravnog sadržaja.

5. [ ] **Fajl sa greškom imenuje šta ne može da se odigra, i i dalje se
   otvara.** [147.3]
   O čemu se radi: Uvezeni fajl se proverava tako što se pokušava da odigra
   svaki potez; ako neki ne može, dijalog to mora da kaže imenom dela, a fajl
   se ipak sme otvoriti za popravku. Putanja se promenila otkad je šilj
   reorganizovan: uvoz je sad na Teach tabu, ne u Biblioteci.
   Gde: `Teach` → `Tutorials` → `Import from a file`.
   Uradi: Izaberi jedan fajl sa greškom iz originalnog foldera (npr.
   pawn_struct_isolated_queens_pawn.json, ne iz fixed/).
   Treba da vidiš: Dijalog imenuje deo i kaže da se sedam poteza ne može
   odigrati. `Open for editing` i dalje otvara studio, gde se vidi da linija
   nije cela.
   Potrebno: Windows; PGN fajl.

### Teach — Tutorijal — glas i video

1. [ ] **`Export without your voice` izvozi bez zastarelog snimka.** [140.4]
   O čemu se radi: Pretpostavlja stavke 138 i 139. Snimanje glasa preko
   tutorijala je pisano kao Windows-only (studio tada nije postojao na
   telefonu); otkad studio ima raspored za uzak ekran, `Record narration` je i
   tamo u `More` meniju, pa vredi probati i na telefonu, ne samo na Windowsu.
   Gde: studio (traka o zastarelom snimku) → `Export without your voice`.
   Uradi: Iz trake o zastarelom snimku pritisni `Export without your voice`, pa
   u dijalogu izaberi `Synthesised voice` (ili `No voice`) i izvezi.
   Treba da vidiš: Umesto `My recording …` stoji rečenica o izmeni; film se
   napravi sintetizovan ili tih, nikad sa zastarelim snimkom.
   Potrebno: Windows i telefon; sačuvan tutorijal sa snimkom.

2. [ ] **Snimljeni čas prolazi ispred tutorijala u redu, a ne staje 300 s
   uzalud.** [143.10]
   O čemu se radi: Za razliku od tutorijala, izvoz snimljenog časa se i dalje
   crta unutar zahteva (veza traje), pa server mora unapred da proceni da li
   stigne pre nego što nginx preseče vezu na 300 s — to je jedini render koji i
   danas dobija rečenicu da pokuša ponovo za N minuta.
   Gde: `Home` → (red snimka) → `Play` → izvoz MP4, dok drugi nalog izvozi dug
   tutorijal.
   Uradi: Sa naloga A pokreni izvoz dugačkog tutorijala. Dok tutorijal još čeka
   u redu, sa naloga B izvezi snimljeni čas — proveri da čas ide ispred njega.
   Ponovi kad se tutorijal već crta i ostalo mu je više vremena crtanja nego
   što čas ima na raspolaganju do 300 s.
   Treba da vidiš: Dok tutorijal čeka, čas prolazi ispred njega u redu. Dok se
   tutorijal crta i nema dovoljno vremena da čas stigne pre 300 s, čas odmah
   dobija poruku da ne bi stigao pre nego što se veza zatvori i da pokuša
   ponovo za par minuta — umesto da visi do isteka.
   Potrebno: Windows i telefon; server; drugi nalog; snimljen čas
   (Preparation).

3. [ ] **Snimak sam u Preparation se i dalje čuva i pušta.** [167.5]
   O čemu se radi: Osnovna provera snimanja — od 22.9.2026 snimanje postoji
   isključivo u Preparation, kad je odrasla osoba sama; ova stavka i dalje
   proverava taj tok.
   Gde: Teach → `Preparation` → `Open` → `Start recording`.
   Uradi: Sam u Preparation kratko snimi preko `Start recording`, pa
   `Stop and save`.
   Treba da vidiš: Snimak se pojavi na Home kartici `Recordings` i pušta se
   preko `Play`.
   Potrebno: Windows.

4. [ ] **Prva reč naracije se čuje celom, ne odsečeno.** [156.1]
   O čemu se radi: Film počinje sa kratkom tišinom pa prvom rečju; ako zvuči
   odsečeno, problem nije u zvučnom fajlu (izmeren je ceo) nego u plejeru ili
   prekratkom uvodu (LEAD_SECONDS).
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Izvezi referentni tutorijal 'Master the Rook and King Checkmate'
   (kopija u D:/chess/tutorijal/reference/) sa naracijom i preslušaj sam
   početak.
   Treba da vidiš: Prva reč se čuje cela, bez odsecanja na početku.
   Potrebno: Windows i telefon; server; referentni tutorijal 'Master the Rook
   and King Checkmate' (kopija u D:/chess/tutorijal/reference/).

5. [ ] **Ispis rečenice se završava tačno kad i glas.** [156.2]
   O čemu se radi: Poslednja reč natpisa treba da se pojavi u trenutku kad je
   glas izgovori, ne posle.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Gledaj bilo koji takt sa dužom rečenicom u izvezenom filmu.
   Treba da vidiš: Poslednja reč natpisa se pojavljuje tačno kad je glas
   izgovori — ne posle.
   Potrebno: Windows i telefon; server; referentni tutorijal 'Master the Rook
   and King Checkmate' (kopija u D:/chess/tutorijal/reference/).

6. [ ] **Pauza posle glasa traje oko sekunde, ne dve.** [156.3]
   O čemu se radi: Ako je i dalje predugo, broj koji se menja je
   BREATH_SECONDS.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Meri pauzu između dva takta u izvezenom filmu sa naracijom.
   Treba da vidiš: Pauza posle glasa traje oko sekunde, ne dve.
   Potrebno: Windows i telefon; server; referentni tutorijal 'Master the Rook
   and King Checkmate' (kopija u D:/chess/tutorijal/reference/).

7. [ ] **Isti tutorijal je kraći nego pre (rep snimka se ne plaća dvaput).**
   [156.4]
   O čemu se radi: Referentni film je bio 168 s; posle popravke oko 147 s, bez
   brisanja sadržaja.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Izmeri dužinu izvezenog filma za referentni tutorijal 'Master the
   Rook and King Checkmate' (kopija u D:/chess/tutorijal/reference/).
   Treba da vidiš: Film je primetno kraći nego ranije objavljena verzija (oko
   147 s naspram 168 s), bez izbačenog sadržaja.
   Potrebno: Windows i telefon; server; referentni tutorijal 'Master the Rook
   and King Checkmate' (kopija u D:/chess/tutorijal/reference/).

8. [ ] **Nemi film je nedirnut ovom popravkom.** [156.5]
   O čemu se radi: Bez glasa, tempo ostaje na starom pravilu (dvanaest slova u
   sekundi, tri četvrtine takta).
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Izvezi isti tutorijal sa `No voice`.
   Treba da vidiš: Ispis i dužina taktova su kao ranije (dvanaest slova u
   sekundi, tri četvrtine takta) — ova popravka ih ne dotiče.
   Potrebno: Windows i telefon; server; referentni tutorijal 'Master the Rook
   and King Checkmate' (kopija u D:/chess/tutorijal/reference/).

9. [ ] **Bez natpisa, sa glasom: taktovi i dalje prate glas.** [156.6]
   O čemu se radi: Bez teksta se crta jednom u sekundi i zaokružuje na celu
   sekundu, ali sinhronizacija sa glasom ostaje.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Isključi `Comments beside the board`, ostavi naraciju uključenu,
   izvezi.
   Treba da vidiš: Taktovi se i dalje slažu sa glasom, iako se natpis ne crta.
   Potrebno: Windows i telefon; server; referentni tutorijal 'Master the Rook
   and King Checkmate' (kopija u D:/chess/tutorijal/reference/).

10. [ ] **Trenerov snimak i dalje ide markerima, ova popravka ga ne menja.**
   [156.7]
   O čemu se radi: Izvoz sa `My recording ...` ide drugim putem (markeri iz
   snimanja), pa ova popravka tempa naracije ne sme ništa da promeni tamo.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Izvezi tutorijal sa `My recording ...` izabranim.
   Treba da vidiš: Zvuk i tabla i dalje idu tačno zajedno, kao i pre ove
   popravke.
   Potrebno: Windows i telefon; sačuvan tutorijal sa snimkom.

11. [ ] **Film i studio se slažu: koordinate su van table, u prigušenom
   pojasu.** [155.1]
   O čemu se radi: Ranije su koordinate bile crtane preko polja i u filmu i u
   studiju drugačije; sad su van table u oba, i tabla je za taj pojas manja.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Izvezi bilo koji tutorijal i uporedi kadar sa studijom iste pozicije.
   Treba da vidiš: Slova a-h stoje ispod table, brojevi 1-8 levo od nje, u
   prigušenom pojasu — nigde preko polja. Tabla je manja za taj pojas; naslov,
   sat i kolona sa rečenicom stoje gde su i stajali.
   Potrebno: Windows i telefon; server.

12. [ ] **Film kaže na koji potez se vraća kad tabla skoči unazad.** [154.1]
   O čemu se radi: Kad se spajaju dva dela čija tabla nije susedna (druga
   varijanta iz iste pozicije), film mora da kaže na koji je potez tabla
   vraćena, dok se prvi potez tog dela ne odigra.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Izvezi referentni tutorijal 'Master the Rook and King Checkmate'
   (kopija u D:/chess/tutorijal/reference/) i gledaj granicu trećeg i četvrtog
   dela.
   Treba da vidiš: U trenutku kad se tabla vrati na raniju poziciju, ispod nje
   piše 'Back to the position after ...' (sa pravim potezom), i taj natpis
   stoji dok se ne odigra prvi potez tog dela.
   Potrebno: Windows i telefon; server; referentni tutorijal 'Master the Rook
   and King Checkmate' (kopija u D:/chess/tutorijal/reference/).

13. [ ] **Obično nastavljanje (bez skoka) ne dobija lažnu rečenicu.** [154.2]
   O čemu se radi: Do 12.9.2026 je svaki spoj delova pisao 'Starting position'
   i gasio poslednji potez — ispravno je samo kad tabla stvarno skoči na već
   viđenu poziciju.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Isti izvoz, gledaj granicu prvog i drugog dela (gde se tabla
   nastavlja bez skoka).
   Treba da vidiš: Nema nikakve nove rečenice o vraćanju; ispod table i dalje
   piše 'Last move: ...' istog poteza — ne 'Starting position'.
   Potrebno: Windows i telefon; server; referentni tutorijal 'Master the Rook
   and King Checkmate' (kopija u D:/chess/tutorijal/reference/).

14. [ ] **Nemi film drži takt sa povratkom bar četiri sekunde.** [154.3]
   O čemu se radi: Bez glasa nema ko da odredi koliko dugo natpis stoji — pa je
   za taj slučaj postavljen minimum.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Izvezi isti tutorijal sa `No voice`.
   Treba da vidiš: Takt koji se vraća stoji najmanje četiri sekunde — dovoljno
   da se natpis pročita. (U filmu sa glasom dužinu i dalje određuje glas.).
   Potrebno: Windows i telefon; server; referentni tutorijal 'Master the Rook
   and King Checkmate' (kopija u D:/chess/tutorijal/reference/).

15. [ ] **Snimljena naracija ne postaje nevažeća zbog povratka na poziciju.**
   [154.4]
   O čemu se radi: Potpis liste taktova (koji hvata izmene za stavku 140)
   namerno ne zna ništa o vraćanju na poziciju — to ne sme da pokrene lažnu
   poruku o zastarelom snimku.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Record narration`.
   Uradi: Sa snimkom preko referentnog tutorijala, otvori studio i
   `Record narration`.
   Treba da vidiš: Studio ne kaže da snimak više ne odgovara taktovima zbog
   spoja delova.
   Potrebno: Windows i telefon; referentni tutorijal 'Master the Rook and King
   Checkmate' (kopija u D:/chess/tutorijal/reference/); sačuvan snimak preko
   tog tutorijala.

16. [ ] **Deo koji se vraća na nedosegnutu poziciju kaže to bez imenovanja
   poteza.** [154.6]
   O čemu se radi: Ako u filmu nema poteza koji je doveo do prve pozicije (deo
   je bio samo dijagram), rečenica o povratku ne sme da izmisli potez.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Napravi tutorijal: prvi deo je samo dijagram (bez poteza), drugi deo
   je negde drugde, treći se vraća na tu prvu poziciju; izvezi kao video.
   Treba da vidiš: Natpis je 'Back to a position already shown', bez imena
   poteza.
   Potrebno: Windows i telefon; server.

17. [ ] **Izvoz videa nudi srpske glasove za srpski tutorijal (Azure), ne
   hrvatski.** [150.7]
   O čemu se radi: Server sa Azure provajderom ima prave srpske glasove;
   dijalog za izvoz treba da ih ponudi po jeziku tutorijala, a hrvatski glas se
   ne sme lažno ponuditi kao srpski.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Za tutorijal na `Serbian (Latin)`, sa Azure provajderom na serveru,
   otvori `Export video`; zatim ponovi sa piper provajderom (koji nema srpski
   glas).
   Treba da vidiš: Sa Azure, dijalog se otvara na srpskim glasovima, bez
   hrvatskog glasa ponuđenog kao srpski. Sa piperom (bez srpskog glasa),
   dijalog se otvara kao ranije (bez jezičkog filtera na ovaj jezik).
   Potrebno: Windows i telefon; sačuvan tutorijal; server.

18. [ ] **Naša slova (č ć š đ ž) se vide u filmu, ne kao kvadratići.** [146.3]
   O čemu se radi: Font korišćen za crtanje natpisa u filmu mora da pokriva
   srpsku latinicu.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Izvezi tutorijal čiji natpis (naslov ili komentar) ima č, ć, š, đ i ž
   (npr. 'Ovo je početak partije').
   Treba da vidiš: U filmu se vide sva ta slova, i u naslovu i u natpisu —
   nijedno nije kvadratić.
   Potrebno: Windows i telefon; server.

19. [ ] **Brojevi 1-8 i slova a-h stoje uz tablu u filmu.** [146.4]
   O čemu se radi: Koordinate table su nedostajale u filmu od 9.9.2026 do
   popravke.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Izvezi bilo koji tutorijal kao video.
   Treba da vidiš: Uz levu ivicu table stoje brojevi 1-8, a uz donju ivicu
   slova a-h.
   Potrebno: Windows i telefon; server.

20. [ ] **`Hear this voice` pušta uzorak bez renderovanja.** [146.5]
   O čemu se radi: Trener treba da čuje glas pre nego što potroši render na
   njega.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: U dijalogu, pored padajuće liste glasova, pritisni `Hear this voice`;
   promeni glas i ponovi.
   Treba da vidiš: Pušta se jedna rečenica tim glasom, dugme se pretvori u
   spinner dok traje, i ništa se ne renderuje (nema novog fajla, broj
   renderovanja se ne menja); posle promene glasa čuje se novi glas.
   Potrebno: Windows i telefon; server.

21. [ ] **Znaci & i < u komentaru ne obaraju Azure izvoz.** [145.5]
   O čemu se radi: Azure Speech čita SSML, pa & i < moraju biti pravilno
   pobegli (escaped) pre slanja, ili Azure odbija zahtev.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Upiši u komentar nekog takta 'Nimzo & Bogo' ili '1 < 2', pa izvezi sa
   Azure glasom.
   Treba da vidiš: Ta reč se izgovori normalno, ništa se ne odbija, i u
   serverskom logu nema poruke da je Azure odbio zahtev.
   Potrebno: Windows i telefon; server; internet.

22. [ ] **Izbor glasa: prvo `Language`, pa `Voice`, filtrirano po jeziku.**
   [145.6]
   O čemu se radi: Sa Azure provajderom lista ima 655 glasova u 154 jezika —
   bez filtera po jeziku bila bi neupotrebljiva.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Sa Azure provajderom otvori `Export video` i izaberi
   `Synthesised voice`; promeni `Language` (npr. na Serbian (Latin, Serbia)).
   Treba da vidiš: `Voice` lista drži samo glasove tog jezika; promena jezika
   povlači i glas za sobom. Sa piperom (šest glasova, svaki svoj jezik)
   kontrola za jezik takođe postoji; sa jednim instaliranim glasom je nema.
   Potrebno: Windows i telefon; server; internet.

23. [ ] **Narisani film zaista govori, bez lažne poruke o naraciji.** [144.1]
   O čemu se radi: Piper je na razvojnoj mašini prešao u virtualenv; server sad
   pita da li motor uopšte može da se pokrene pre nego što ponudi glas.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Izvezi bilo koji tutorijal sa `Synthesised voice` i izabranim glasom.
   Treba da vidiš: Film ima glas, a poruka na kraju je obična poruka o uspešnom
   renderovanju, bez ijedne rečenice o naraciji (backtick fragment
   `Video rendered successfully`).
   Potrebno: Windows i telefon; server; DeepSeek ključ na serveru.

24. [ ] **Posle popravke .env, glas se vraća sa punom listom.** [144.4]
   O čemu se radi: Kad se PIPER_PYTHON vrati na ispravnu putanju, ponuda glasa
   mora odmah da se vrati u normalu.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Posle vraćanja .env-a i restarta backend-a (iz 144.2/144.3), otvori
   `Export video`.
   Treba da vidiš: `Synthesised voice` je opet ponuđen, sa punim spiskom
   glasova.
   Potrebno: Windows i telefon; server.

25. [ ] **Ekran se ne zamrzava dok se film crta — `Hide`.** [143.1]
   O čemu se radi: Izvoz odgovara čim server prihvati posao (202 i id), pa se
   film crta posle odgovora; traka može da se sakrije bez prekida rendera.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Izvezi medium-12-parts, pa u traci renderovanja pritisni `Hide`.
   Treba da vidiš: Dijalog se zatvori, poruka kaže da se video i dalje
   renderuje, i aplikacija radi normalno dok server crta.
   Potrebno: Windows i telefon; server; dug tutorijal (fixture
   medium-12-parts).

26. [ ] **Drugi izvoz istog tutorijala ne pokreće novi render.** [143.4]
   O čemu se radi: Dok se jedan render tog tutorijala crta, drugi zahtev za
   isti tutorijal ne sme da otvori paralelan posao.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Dok se izvoz iz 143.1 crta, u studiju istog tutorijala ponovo
   pritisni `Export video` → `Export`.
   Treba da vidiš: Stiže poruka da se tutorijal već renderuje i prikazuje se
   traka tog istog filma — drugi render se ne pokreće.
   Potrebno: Windows i telefon; server.

27. [ ] **`Cancel render` prekida crtanje bez traga i bez trošenja kvote.**
   [143.5]
   O čemu se radi: Trenerova eksplicitna otkaza je jedini način da se render
   prekine (od kako je otišla veza-otkine-abandon logika, stavka 134).
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Pokreni izvoz, pa u traci pritisni `Cancel render`.
   Treba da vidiš: Dugme kaže `Cancelling…`, traka se zatvori sa porukom da je
   izvoz otkazan. U chess_backend/exports/ nema novog fajla, broj renderovanja
   na nalogu ne raste, i zvono ne dobija obaveštenje.
   Potrebno: Windows i telefon; server.

28. [ ] **Otkazivanje dok se čeka u redu odmah oslobađa mesto.** [143.6]
   O čemu se radi: Otkaz mora da radi i pre nego što je crtanje uopšte počelo —
   posao izlazi iz reda, ne samo iz crtanja.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Nalog A pusti dug film; nalog B pusti kratak, koji čeka iza njega u
   redu, pa ga B odmah otkaže (`Cancel render` dok B-ov posao još čeka).
   Treba da vidiš: B-ov film odmah nestaje iz reda (A-ov ide dalje nesmetano),
   i B odmah može ponovo da izveze.
   Potrebno: Windows i telefon; server; drugi nalog.

29. [ ] **Restart servera usred rendera javlja prekid, ne visi.** [143.7]
   O čemu se radi: Posao koji je bio u toku kad se server ugasi mora da se
   označi kao neuspeo i da to javi, ne da ostavi trenera da čeka zauvek.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Pokreni izvoz, pa dok crta zaustavi i ponovo pokreni backend (npr.
   preko pokreni.ps1).
   Treba da vidiš: Trener dobija obaveštenje da video nije mogao da se
   renderuje jer je server zaustavljen pre kraja, uz predlog da se ponovo
   izveze; otvorena traka (ako je bila otvorena) kaže isto umesto da ostane da
   stoji.
   Potrebno: server; server.

30. [ ] **Traka renderovanja sa dva dugmeta staje na uzak telefon.** [143.8]
   O čemu se radi: Kad je ova stavka pisana, tutorijali su postojali samo na
   Windowsu, pa je provera bila odložena. Otkad studio ima raspored za telefon,
   uslov je ispunjen — vredi proveriti sada.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Na telefonu od 360 dp pokreni izvoz i pogledaj traku sa `Hide` i
   `Cancel render`.
   Treba da vidiš: Oba dugmeta i tekst trake staju na ekran bez sečenja ili
   prelivanja.
   Potrebno: telefon; server; telefon položeno.

31. [ ] **Snimanje sme do skoro 30 minuta kad server odgovara na pitanje o
   granici.** [143.9]
   O čemu se radi: Studio prvo pita server za granicu (GET
   /lessons/:id/narration vraća maxMs, izvedeno iz plafona od 600 s crtanja)
   pre nego što dozvoli snimanje — granica više nije fiksnih 15 minuta.
   Suprotan slučaj (server nedostupan → 14:59) pokriva stavka 139.9 (i1145).
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Record narration`.
   Uradi: Sa dostupnim serverom otvori `Record narration` i snimaj blizu
   granice.
   Treba da vidiš: Snimanje staje na 29:59 i kaže da je to najduže što jedan
   snimak sme da traje; slanje (oko 57 MB) prolazi, i izvoz tog snimka na 720p
   se nacrta (oko 600 s pri podrazumevanoj brzini).
   Potrebno: Windows i telefon; sačuvan tutorijal; server.

32. [ ] **Predug tutorijal je odbijen odmah, pre crtanja.** [142.1]
   O čemu se radi: Server pre crtanja računa koliko bi film trajao (plafon je
   od 10.9.2026 podignut na 600 s crtanja po filmu) i odbija ga odmah umesto da
   crta dok veza ne pukne. Na 720p, tutorijal od 36 minuta (fixture
   big-40-parts) traje oko 720 s crtanja — i dalje iznad plafona, pa se i danas
   odbija.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Izvezi tutorijal od oko 36 minuta (big-40-parts) na 720p.
   Treba da vidiš: Odgovor stiže za sekundu i kaže koliko bi renderovanje
   trajalo, koliko server može u jednom komadu, i nudi da se tutorijal podeli
   na više kraćih. U chess_backend/exports/ nema novog fajla, i broj
   renderovanja na nalogu ne raste.
   Potrebno: Windows; server; dug tutorijal (fixture big-40-parts u
   mislisha-test/render-fixtures).

33. [ ] **1080p sa dužim tutorijalom je odbijen, isti tutorijal na 720p
   prolazi.** [142.2]
   O čemu se radi: Brojevi iz ove tačke su zastareli: plafon je 10.9.2026
   podignut sa 300 na 600 s crtanja, pa fixture medium-12-parts (10,5 min) na
   1080p (nekad oko 420 s) sada prolazi. Za proveru treba tutorijal od
   dvadesetak minuta: na 1080p oko 800 s (odbijen), na 720p oko 400 s (prolazi)
   — ovo je već zapisano u samom odeljku 142 docs/TODO-provera.md, ne u ovoj
   proveri.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Izvezi tutorijal od dvadesetak minuta na `Higher quality (1080p)`;
   zatim isti tutorijal na 720p (bez tog prekidača).
   Treba da vidiš: Na 1080p je odbijen, rečenica nudi izvoz na 720p; isti
   tutorijal na 720p prolazi.
   Potrebno: Windows; server.

34. [ ] **1080p sa snimkom nudi izvoz bez snimka samo ako bi to stalo.**
   [142.3]
   O čemu se radi: Isti razlog kao 142.2 — treba duži tutorijal (desetak minuta
   i više) da bi se test uopšte dogodio pod plafonom od 600 s.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Sa tutorijalom koji ima snimak od desetak ili više minuta, izaberi
   `My recording …` i `Higher quality (1080p)`, pa `Export`.
   Treba da vidiš: Izvoz je odbijen i nudi 720p; opciju bez tvog snimka nudi
   samo ako bi film bez snimka (kraći, bez markera koji produžuju crtanje) stao
   pod plafon.
   Potrebno: Windows; sačuvan tutorijal sa snimkom; server.

35. [ ] **Sva tri odgovora se nude kad postoje snimak i piper.** [141.1]
   O čemu se radi: Dva stara prekidača (Use my recording, Narrate this video)
   su spojena u jedno pitanje `Narration` sa tri odgovora. Pretpostavlja stavke
   138 i 139. Snimanje glasa preko tutorijala je pisano kao Windows-only
   (studio tada nije postojao na telefonu); otkad studio ima raspored za uzak
   ekran, `Record narration` je i tamo u `More` meniju, pa vredi probati i na
   telefonu, ne samo na Windowsu.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Sa tutorijalom koji ima snimak, i serverom koji ima piper, otvori
   `Export video`.
   Treba da vidiš: Pod `Narration` su tri odgovora: `My recording …`,
   `Synthesised voice`, `No voice`; izabrano je `My recording …`, i nema
   padajuće liste glasova (ona se pojavljuje tek uz `Synthesised voice`).
   Potrebno: Windows i telefon; sačuvan tutorijal sa snimkom; server.

36. [ ] **`Synthesised voice` otvara listu glasova.** [141.2]
   O čemu se radi: Pretpostavlja stavke 138 i 139. Snimanje glasa preko
   tutorijala je pisano kao Windows-only (studio tada nije postojao na
   telefonu); otkad studio ima raspored za uzak ekran, `Record narration` je i
   tamo u `More` meniju, pa vredi probati i na telefonu, ne samo na Windowsu.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: U dijalogu izaberi `Synthesised voice`.
   Treba da vidiš: Pojavljuje se padajuća lista glasova i rečenica
   `A narrated export takes longer.`; izvezen film ima sintetizovan glas, ne
   tvoj.
   Potrebno: Windows i telefon; sačuvan tutorijal sa snimkom; server.

37. [ ] **`No voice` je uvek tih film, i kad server ima piper.** [141.3]
   O čemu se radi: Ranije je isključen snimak na serveru sa piperom značio
   sintetizovan glas — sad je to izričit treći odgovor. Pretpostavlja stavke
   138 i 139. Snimanje glasa preko tutorijala je pisano kao Windows-only
   (studio tada nije postojao na telefonu); otkad studio ima raspored za uzak
   ekran, `Record narration` je i tamo u `More` meniju, pa vredi probati i na
   telefonu, ne samo na Windowsu.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Na serveru sa piperom izaberi `No voice` i izvezi.
   Treba da vidiš: Gotov film je bez ikakvog glasa (tih), iako server ima
   piper.
   Potrebno: Windows i telefon; server.

38. [ ] **Pamti se poslednji izbor koji nije snimak.** [141.4]
   O čemu se radi: Pretpostavlja stavke 138 i 139. Snimanje glasa preko
   tutorijala je pisano kao Windows-only (studio tada nije postojao na
   telefonu); otkad studio ima raspored za uzak ekran, `Record narration` je i
   tamo u `More` meniju, pa vredi probati i na telefonu, ne samo na Windowsu.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Izvezi jednom sa `Synthesised voice`, pa jednom sa `My recording …`,
   pa izmeni jednu rečenicu (snimak prestaje da važi) i ponovo otvori
   `Export video`.
   Treba da vidiš: Izabrano je `Synthesised voice` (poslednji odgovor koji nije
   bio snimak), a ne `No voice`.
   Potrebno: Windows i telefon; sačuvan tutorijal sa snimkom; server.

39. [ ] **Bez snimka i bez pipera nema pitanja `Narration` uopšte.** [141.5]
   O čemu se radi: Pretpostavlja stavke 138 i 139. Snimanje glasa preko
   tutorijala je pisano kao Windows-only (studio tada nije postojao na
   telefonu); otkad studio ima raspored za uzak ekran, `Record narration` je i
   tamo u `More` meniju, pa vredi probati i na telefonu, ne samo na Windowsu.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Na tutorijalu bez snimka, na serveru bez pipera, otvori
   `Export video`; pa isto sa nevažećim (zastarelim) snimkom.
   Treba da vidiš: Bez ijednog odgovora osim nemog filma, `Narration` pitanje
   se uopšte ne nudi — dijalog ima samo `Higher quality (1080p)`. Sa nevažećim
   snimkom stoji samo rečenica zašto snimak ne važi, bez liste odgovora.
   Potrebno: Windows i telefon; server.

40. [ ] **Dijalog za izvoz staje i na nizak Windows prozor.** [141.6]
   O čemu se radi: Sa sva tri odgovora i listom glasova dijalog je merano 49 px
   viši od 360×640 bez skrolovanja. Pretpostavlja stavke 138 i 139. Snimanje
   glasa preko tutorijala je pisano kao Windows-only (studio tada nije postojao
   na telefonu); otkad studio ima raspored za uzak ekran, `Record narration` je
   i tamo u `More` meniju, pa vredi probati i na telefonu, ne samo na Windowsu.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Smanji visinu Windows prozora dok dijalog `Export video` ne prestane
   da staje na ekran; sa sva tri odgovora i izabranim `Synthesised voice`,
   skroluj do `Higher quality (1080p)` i uključi ga.
   Treba da vidiš: Prekidač `Higher quality (1080p)` se vidi i može da se
   uključi skrolovanjem; izvezen film je 1080p.
   Potrebno: Windows; sačuvan tutorijal sa snimkom; server.

41. [ ] **Broj taktova ne bi ništa primetio bez potpisa.** [140.2]
   O čemu se radi: Ovo pokazuje zašto samo brojanje taktova nije dovoljno —
   treba potpis sadržaja. Pretpostavlja stavke 138 i 139. Snimanje glasa preko
   tutorijala je pisano kao Windows-only (studio tada nije postojao na
   telefonu); otkad studio ima raspored za uzak ekran, `Record narration` je i
   tamo u `More` meniju, pa vredi probati i na telefonu, ne samo na Windowsu.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Record narration`.
   Uradi: Sa izmenjenom rečenicom (iz prethodne provere) otvori
   `Record narration`.
   Treba da vidiš: I dalje piše isti broj taktova (npr. N of N beats) —
   brojanje se ne bi promenilo — ali ispod stoji rečenica da je tutorijal
   izmenjen posle snimka (backtick fragment
   `The tutorial has been edited since this was recorded`).
   Potrebno: Windows i telefon; sačuvan tutorijal sa snimkom.

42. [ ] **`Narration` je unapred izabrano na sopstveni snimak.** [139.1]
   O čemu se radi: Otkad je stavka 141 spojila dva prekidača u jedno pitanje,
   `Narration` nudi tri odgovora i po pravilu bira snimak kad postoji.
   Pretpostavlja stavku 138 — snimak već postoji na uređaju. Snimanje glasa
   preko tutorijala je pisano kao Windows-only (studio tada nije postojao na
   telefonu); otkad studio ima raspored za uzak ekran, `Record narration` je i
   tamo u `More` meniju, pa vredi probati i na telefonu, ne samo na Windowsu.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Sa postojećim snimkom otvori `Export video` (iz studija ili sa reda u
   `Library`).
   Treba da vidiš: Pod `Narration` je izabrano `My recording …` (sa dužinom u
   zagradi), ne `Synthesised voice` ni `No voice`.
   Potrebno: Windows i telefon; sačuvan tutorijal; server.

43. [ ] **Prvi izvoz šalje snimak pa crta u trenerovom glasu.** [139.2]
   O čemu se radi: Pretpostavlja stavku 138 — snimak već postoji na uređaju.
   Snimanje glasa preko tutorijala je pisano kao Windows-only (studio tada nije
   postojao na telefonu); otkad studio ima raspored za uzak ekran,
   `Record narration` je i tamo u `More` meniju, pa vredi probati i na
   telefonu, ne samo na Windowsu.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Sa `My recording …` izabranim pritisni `Export`.
   Treba da vidiš: Pojavljuje se `Uploading your recording`, pa traka
   renderovanja. U gotovom filmu se čuje tvoj glas, a tabla se menja tamo gde
   si pritiskao razmak — proveri početak, sredinu i poslednja tri takta.
   Potrebno: Windows i telefon; sačuvan tutorijal; server.

44. [ ] **Drugi izvoz istog snimka ne šalje ga ponovo.** [139.3]
   O čemu se radi: Server pamti poslednji poslati snimak po tutorijalu; drugi
   izvoz sa istim snimkom ne treba novo slanje. Pretpostavlja stavku 138 —
   snimak već postoji na uređaju. Snimanje glasa preko tutorijala je pisano kao
   Windows-only (studio tada nije postojao na telefonu); otkad studio ima
   raspored za uzak ekran, `Record narration` je i tamo u `More` meniju, pa
   vredi probati i na telefonu, ne samo na Windowsu.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Izvezi isti tutorijal drugi put, bez ponovnog snimanja.
   Treba da vidiš: `Uploading your recording` se ovog puta ne pojavljuje —
   odmah ide traka renderovanja.
   Potrebno: Windows i telefon; sačuvan tutorijal; server.

45. [ ] **Novi snimak se ponovo šalje pre izvoza.** [139.4]
   O čemu se radi: Pretpostavlja stavku 138 — snimak već postoji na uređaju.
   Snimanje glasa preko tutorijala je pisano kao Windows-only (studio tada nije
   postojao na telefonu); otkad studio ima raspored za uzak ekran,
   `Record narration` je i tamo u `More` meniju, pa vredi probati i na
   telefonu, ne samo na Windowsu.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Record narration` (novo snimanje), pa `Export video`.
   Uradi: Snimi novi snimak preko starog (`Record again` → `Stop`), pa izvezi
   video.
   Treba da vidiš: `Uploading your recording` se ponovo pojavljuje, i gotov
   film ima novi glas.
   Potrebno: Windows i telefon; sačuvan tutorijal; server.

46. [ ] **`No voice` i `Synthesised voice` isključuju sopstveni snimak.**
   [139.5]
   O čemu se radi: Film sme da ima najviše jedan izvor zvuka — nikad snimak i
   sintetizovan glas zajedno. Pretpostavlja stavku 138 — snimak već postoji na
   uređaju. Snimanje glasa preko tutorijala je pisano kao Windows-only (studio
   tada nije postojao na telefonu); otkad studio ima raspored za uzak ekran,
   `Record narration` je i tamo u `More` meniju, pa vredi probati i na
   telefonu, ne samo na Windowsu.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Izaberi `No voice`, izvezi; pa (ako server ima piper) izaberi
   `Synthesised voice`, izvezi.
   Treba da vidiš: Prvi film je tih; drugi ima sintetizovan glas — nijedan nema
   tvoj snimljeni glas.
   Potrebno: Windows i telefon; sačuvan tutorijal; server.

47. [ ] **Izmena tutorijala obara ponuđeni snimak pri izvozu.** [139.6]
   O čemu se radi: Pretpostavlja stavku 138 — snimak već postoji na uređaju.
   Snimanje glasa preko tutorijala je pisano kao Windows-only (studio tada nije
   postojao na telefonu); otkad studio ima raspored za uzak ekran,
   `Record narration` je i tamo u `More` meniju, pa vredi probati i na
   telefonu, ne samo na Windowsu.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video`.
   Uradi: Dodaj potez u tutorijalu (van ovog ekrana), sačuvaj, pa otvori
   `Export video`.
   Treba da vidiš: Umesto `My recording …` stoji rečenica da je snimak
   napravljen kad je tutorijal imao drugi broj taktova (backtick fragment
   `This recording was made when the tutorial had`).
   Potrebno: Windows i telefon; sačuvan tutorijal; server.

48. [ ] **Bez veze do servera, snimanje staje na 14:59 kao bezbednosna
   rezerva.** [139.9]
   O čemu se radi: Otkad ekran za snimanje pita server za pravu granicu (GET
   /lessons/:id/narration, stavka 143), 14:59 više nije opšta granica nego samo
   rezerva kad server ne može da se pita — normalna granica je sad bliža 30
   minuta (vidi stavku 143.9, i1179). Ova provera je zato preformulisana da
   cilja baš taj slučaj.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Record narration`.
   Uradi: Isključi internet (ili blokiraj server) pre nego što otvoriš
   `Record narration`, pa snimaj blizu petnaest minuta bez prekida.
   Treba da vidiš: Kad server ne može da se pita, snimanje samo stane na 14:59
   i kaže zašto (bezbednosno kraća granica, jer se kraći snimak uvek prima).
   Potrebno: Windows i telefon; sačuvan tutorijal; isključen internet.

49. [ ] **Pauza u snimanju ne ostavlja tišinu u filmu.** [138.3]
   O čemu se radi: Marker takta je pozicija u samom zvučnom fajlu (bajt), ne
   sat na zidu — pauza pre razmaka ne sme da uđe u snimljeni zvuk. Snimanje
   glasa preko tutorijala je pisano kao Windows-only (studio tada nije postojao
   na telefonu); otkad studio ima raspored za uzak ekran, `Record narration` je
   i tamo u `More` meniju, pa vredi probati i na telefonu, ne samo na Windowsu.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Record narration`.
   Uradi: `Record`, pričaj, pa `Pause`; ćutu pet sekundi, pritisni razmak
   (`Next beat (Space)`) dok je još pauzirano, pa `Resume` i nastavi do kraja;
   `Stop`, pa `Listen`.
   Treba da vidiš: Na preslušavanju se takt menja tačno tamo gde glas nastavlja
   — nema tišine od pet sekundi na mestu pauze.
   Potrebno: Windows i telefon; sačuvan tutorijal.

50. [ ] **Kraj snimka se ne razilazi sa taktovima.** [138.5]
   O čemu se radi: Ovo je polovina koju niko obično ne proveri — kraj snimka je
   gde se marker najlakše pomeri. Snimanje glasa preko tutorijala je pisano kao
   Windows-only (studio tada nije postojao na telefonu); otkad studio ima
   raspored za uzak ekran, `Record narration` je i tamo u `More` meniju, pa
   vredi probati i na telefonu, ne samo na Windowsu.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Record narration`.
   Uradi: Snimi ceo tutorijal od bar dva minuta, sa jednom ili dve pauze
   (razmak za svaki sledeći takt), `Stop`, pa `Listen` i preslušaj **poslednja
   tri takta**.
   Treba da vidiš: Tabla se menja u trenutku kad glas to kaže — ne pola sekunde
   pre ili tri sekunde posle.
   Potrebno: Windows i telefon; sačuvan tutorijal.

51. [ ] **Snimak preživi zatvaranje i ponovno otvaranje ekrana.** [138.6]
   O čemu se radi: Snimljena naracija se čuva na uređaju (fazi 1-2), pa ekran
   mora da je nađe ponovo. Snimanje glasa preko tutorijala je pisano kao
   Windows-only (studio tada nije postojao na telefonu); otkad studio ima
   raspored za uzak ekran, `Record narration` je i tamo u `More` meniju, pa
   vredi probati i na telefonu, ne samo na Windowsu.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Record narration`.
   Uradi: Snimi kratak takt, zatvori ekran `Record narration` (strelica nazad),
   pa ga ponovo otvori.
   Treba da vidiš: Piše Recorded sa datumom, dužinom i brojem taktova (npr.
   `… of … beats`), i `Listen` radi.
   Potrebno: Windows i telefon; sačuvan tutorijal.

52. [ ] **Novi pokušaj snimanja: odbaci zadržava stari, Stop zamenjuje.**
   [138.7]
   O čemu se radi: Snimanje glasa preko tutorijala je pisano kao Windows-only
   (studio tada nije postojao na telefonu); otkad studio ima raspored za uzak
   ekran, `Record narration` je i tamo u `More` meniju, pa vredi probati i na
   telefonu, ne samo na Windowsu.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Record narration`.
   Uradi: Sa postojećim snimkom pritisni `Record again`, snimi par taktova, pa
   `Discard` — proveri da je stari snimak i dalje tu (`Listen`). Ponovi
   `Record again`, ovog puta završi sa `Stop`.
   Treba da vidiš: Posle `Discard` stari snimak je nepromenjen; posle `Stop`
   novi snimak je zamenio stari.
   Potrebno: Windows i telefon; sačuvan tutorijal.

53. [ ] **Izlazak nazad usred snimanja pita pre nego što obriše.** [138.8]
   O čemu se radi: Snimanje glasa preko tutorijala je pisano kao Windows-only
   (studio tada nije postojao na telefonu); otkad studio ima raspored za uzak
   ekran, `Record narration` je i tamo u `More` meniju, pa vredi probati i na
   telefonu, ne samo na Windowsu.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Record narration`.
   Uradi: Pritisni `Record`, pričaj par sekundi, pa strelicu nazad (izlaz sa
   ekrana) dok se još snima.
   Treba da vidiš: Pojavljuje se `Discard this recording?` sa `Keep recording`
   / `Discard and leave`; `Discard and leave` izlazi i ne ostavlja snimak.
   Potrebno: Windows i telefon; sačuvan tutorijal.

54. [ ] **Držanje razmaka pomera samo jedan takt.** [138.9]
   O čemu se radi: Držanje tastera ne sme da preskoči više taktova odjednom
   nego da se protumači kao jedan pritisak. Snimanje glasa preko tutorijala je
   pisano kao Windows-only (studio tada nije postojao na telefonu); otkad
   studio ima raspored za uzak ekran, `Record narration` je i tamo u `More`
   meniju, pa vredi probati i na telefonu, ne samo na Windowsu.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Record narration`.
   Uradi: Pritisni `Record`, pa drži razmak (taster) pritisnut oko dve sekunde.
   Treba da vidiš: Pomera se tačno jedan takt (red `Next: …` napreduje za jedno
   mesto), ne dva ili više.
   Potrebno: Windows i telefon; sačuvan tutorijal.

55. [ ] **Izmenjen tutorijal se prepozna pri otvaranju ekrana za snimanje.**
   [138.10]
   O čemu se radi: Snimak nosi potpis liste taktova nad kojom je napravljen;
   posle dodavanja poteza broj taktova se menja, pa ekran za snimanje mora
   odmah da to kaže. Snimanje glasa preko tutorijala je pisano kao Windows-only
   (studio tada nije postojao na telefonu); otkad studio ima raspored za uzak
   ekran, `Record narration` je i tamo u `More` meniju, pa vredi probati i na
   telefonu, ne samo na Windowsu.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Record narration`.
   Uradi: Posle postojećeg snimka dodaj potez negde u tutorijalu (van ovog
   ekrana), sačuvaj, pa otvori `Record narration`.
   Treba da vidiš: Piše da je ovaj snimak napravljen kad je tutorijal imao
   drugi broj taktova (backtick fragment
   `This recording was made when the tutorial had`) i traži novo snimanje.
   Potrebno: Windows i telefon; sačuvan tutorijal.

56. [ ] **Treći izvoz sa istog naloga se odbija.** [137.1]
   O čemu se radi: Red za renderovanje ide naizmenično po nalogu (round-robin)
   i jedan nalog sme da ima najviše dva filma odjednom (jedan se crta, jedan
   čeka). Vlasnik ranije nije mogao ovo da proveri: ekran se zamrzavao pri
   drugom izvozu, a studio tada nije postojao na Androidu, pa nije imao drugi
   nalog za probu. Od tada je izvoz izašao iz zahteva (stavka 143 — traka ima
   `Hide` i aplikacija ne zastaje dok se crta) i studio je dobio raspored za
   telefon, pa oba razloga zamrzavanja i nedostatka drugog uređaja bi trebalo
   da su otklonjeni — vredi probati ponovo, po mogućstvu i sa telefona kao
   drugog naloga.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (tri različita tutorijala)
   → `Export video` → `Export`.
   Uradi: Pokreni izvoz tri različita tutorijala zaredom, sa istog naloga, ne
   čekajući da se prvi završi.
   Treba da vidiš: Treći izvoz se odbija rečenicom da nalog već ima jedan film
   koji se crta i jedan koji čeka — ne opštom rečenicom da server trenutno
   renderuje druge filmove.
   Potrebno: Windows i telefon; server; drugi nalog.

57. [ ] **Drugi nalog i dalje ulazi u red.** [137.2]
   O čemu se radi: Kvota od dva filma po nalogu ne sme da blokira druge naloge.
   Vlasnik ranije nije mogao ovo da proveri: ekran se zamrzavao pri drugom
   izvozu, a studio tada nije postojao na Androidu, pa nije imao drugi nalog za
   probu. Od tada je izvoz izašao iz zahteva (stavka 143 — traka ima `Hide` i
   aplikacija ne zastaje dok se crta) i studio je dobio raspored za telefon, pa
   oba razloga zamrzavanja i nedostatka drugog uređaja bi trebalo da su
   otklonjeni — vredi probati ponovo, po mogućstvu i sa telefona kao drugog
   naloga.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (tutorijal) →
   `Export video` → `Export`, sa drugog naloga.
   Uradi: Dok prvi nalog ima dva izvoza u redu (jedan crta, jedan čeka), sa
   drugog naloga pokreni `Export video`.
   Treba da vidiš: Izvoz drugog naloga uđe u red i krene — nije odbijen.
   Potrebno: Windows i telefon; server; drugi nalog.

58. [ ] **Red poštuje smenu po nalogu, ne po redosledu prijave.** [137.3]
   O čemu se radi: Round-robin znači da se posle jednog filma po nalogu red
   pomera na sledeći nalog. Vlasnik ranije nije mogao ovo da proveri: ekran se
   zamrzavao pri drugom izvozu, a studio tada nije postojao na Androidu, pa
   nije imao drugi nalog za probu. Od tada je izvoz izašao iz zahteva (stavka
   143 — traka ima `Hide` i aplikacija ne zastaje dok se crta) i studio je
   dobio raspored za telefon, pa oba razloga zamrzavanja i nedostatka drugog
   uređaja bi trebalo da su otklonjeni — vredi probati ponovo, po mogućstvu i
   sa telefona kao drugog naloga.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (tutorijal) →
   `Export video` → `Export`, sa dva naloga.
   Uradi: Nalog A pokrene izvoz pa odmah drugi. Nalog B pokrene svoj tek posle
   toga (dok A-ov prvi još crta). Sačekaj da se A-ov prvi izvoz završi.
   Treba da vidiš: B-ov izvoz krene pre A-ovog drugog izvoza.
   Potrebno: Windows i telefon; server; drugi nalog.

59. [ ] **Broj mesta u redu se ispravno menja.** [137.4]
   O čemu se radi: Traka renderovanja dok se čeka pokazuje mesto u redu.
   Vlasnik ranije nije mogao ovo da proveri: ekran se zamrzavao pri drugom
   izvozu, a studio tada nije postojao na Androidu, pa nije imao drugi nalog za
   probu. Od tada je izvoz izašao iz zahteva (stavka 143 — traka ima `Hide` i
   aplikacija ne zastaje dok se crta) i studio je dobio raspored za telefon, pa
   oba razloga zamrzavanja i nedostatka drugog uređaja bi trebalo da su
   otklonjeni — vredi probati ponovo, po mogućstvu i sa telefona kao drugog
   naloga.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (tutorijal) →
   `Export video` → `Export`, traka dok čeka.
   Uradi: Pokreni izvoz koji ostaje da čeka u redu. Sa drugog naloga pusti
   izvoz koji te pretekne po pravilu smene (round-robin).
   Treba da vidiš: Broj mesta koje čekaš u traci poraste kad te neko pretekne.
   Potrebno: Windows i telefon; server; drugi nalog.

60. [ ] **Odbijen treći izvoz ne troši kvotu.** [137.5]
   O čemu se radi: Kvota renderovanja (koliko puta je nalog izvezao video ovog
   meseca) sme da poraste samo posle uspešnog izvoza, ne posle odbijanja.
   Vlasnik ranije nije mogao ovo da proveri: ekran se zamrzavao pri drugom
   izvozu, a studio tada nije postojao na Androidu, pa nije imao drugi nalog za
   probu. Od tada je izvoz izašao iz zahteva (stavka 143 — traka ima `Hide` i
   aplikacija ne zastaje dok se crta) i studio je dobio raspored za telefon, pa
   oba razloga zamrzavanja i nedostatka drugog uređaja bi trebalo da su
   otklonjeni — vredi probati ponovo, po mogućstvu i sa telefona kao drugog
   naloga. Broj se ne vidi nigde u aplikaciji — potvrđuje se upitom nad
   serverskom bazom (tabela usage_counters, metrika za MP4 render, za taj
   nalog).
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (tutorijal) →
   `Export video` → `Export` (treći, odbijen).
   Uradi: Ponovi proveru 137.1 (treći izvoz odbijen), pa na serveru pogledaj
   usage_counters za taj nalog pre i posle.
   Treba da vidiš: Broj upisan za taj nalog i metriku (broj MP4 renderovanja)
   se ne menja posle odbijenog trećeg izvoza.
   Potrebno: Windows i telefon; server; drugi nalog.

61. [ ] **Pregled filma ne čeka iza tuđeg izvoza.** [135.5]
   O čemu se radi: `Preview` u dijalogu za izvoz videa crta par kadrova bez
   ffmpeg-a, pa ne staje u red za renderovanje, ne piše fajl i ne troši kvotu.
   Studio (i Export video) radi i na telefonu otkad je studio dobio raspored za
   uzak ekran, ne samo na Windowsu.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal)
   → `Export video` → `Preview`.
   Uradi: Sa drugog naloga pokreni izvoz dužeg tutorijala (`Export video` →
   `Export`) da traka renderovanja krene. Dok taj izvoz crta, na svom nalogu
   otvori bilo koji sačuvan tutorijal, pritisni `Export video`, pa `Preview`.
   Treba da vidiš: Pregled stigne za par sekundi, bez čekanja — jer pregled
   nije u redu za renderovanje. Posle pregleda dijalog za izvoz ostaje otvoren
   sa istim prekidačima.
   Potrebno: Windows i telefon; server; drugi nalog.

62. [ ] **Izvoz videa tutorijala i dalje prikazuje napredak i završava se.**
   [169.5]
   O čemu se radi: Osnovna, nepromenjena funkcija renderovanja videa — mora i
   dalje pouzdano da radi.
   Gde: Teach → kartica `Tutorials` → otvori tutorijal → `Export video`.
   Uradi: Pokreni izvoz videa na kraćem tutorijalu i sačekaj da se završi.
   Treba da vidiš: Tokom izvoza se vidi napredak (progress bar); izvoz se
   normalno završi dijalogom `Video ready!`.
   Potrebno: Windows.

### Teach — Tutorial studio

1. [ ] **Jedan deo se okreće iz svog reda; „Preview tutorial" više ne postoji.** [246.9]
   O čemu se radi: Okretanje jednog dela bilo je samo u „Preview tutorial"
   (đakov pregled, obrisan); sada je dugme u redu svakog dela (D12).
   Gde: `Teach` → studio → na Windowsu panel `Tutorial contents`, na telefonu
   kartica sa delovima → red dela → dugme za okretanje (natpis na dugmetu:
   „Turn this part (White at the bottom now)").
   Uradi: U tutorijalu od tri dela okreni samo drugi. Sačuvaj, zatvori, otvori
   ponovo; izvezi video.
   Treba da vidiš: Okrenut je samo drugi deo — i posle ponovnog otvaranja, i
   u videu. Dugme `Flip board` i dalje okreće sve delove. Nigde nema „Preview
   tutorial".
   Potrebno: Windows i telefon.

2. [ ] **Studio pravi samo delove koji pokazuju.** [246.11]
   O čemu se radi: Tutorijal je materijal za video, pa deo više ne postavlja
   pitanje; zadatak za učenika je vežba (`docs/PLAN-TUTORIJAL-VIDEO.md`,
   faza 4).
   Gde: `Teach` → `New tutorial` (Windows i telefon).
   Uradi: Odigraj nekoliko poteza, dodaj novi deo, pogledaj panel
   `Tutorial contents` i polja jednog dela; na telefonu kartice na dnu.
   Treba da vidiš: Nigde `Task type`, `Task for student`, `Find the move` ni
   `Choose the answer`. Novi deo se pravi dugmetom `New demonstration`. Na
   telefonu su samo dve kartice, `Line` i `Parts`. Svaki potez odigran na
   tabli ide u liniju dela.
   Potrebno: Windows i telefon.

3. [ ] **Uvoz tutorijala sa pitanjem kaže koji deo smeta.** [246.12]
   O čemu se radi: Fajl pisan za stara pitanja (`ask_move`, `ask_choice`) se
   ne uvozi prepravljen, nego odbija, uz broj dela (D11). Uvoz PGN-a više ne
   nudi da od grešaka napravi pitanja.
   Gde: `Teach` → `Import from a file`.
   Uradi: Uvezi JSON tutorijal čiji je treći deo `"kind": "ask_move"`; zatim
   uvezi jednu PGN partiju.
   Treba da vidiš: Za JSON rečenicu koja počinje sa „Part 3:" i kaže da
   tutorijal samo pokazuje; ništa nije sačuvano. Za PGN nijedno pitanje o
   pravljenju pitanja od grešaka.
   Potrebno: JSON fajl sa pitanjem u trećem delu.

4. [ ] **Tutorijal iz partije ne pita „za učenike ili za video".** [246.13]
   O čemu se radi: Izbor je otišao s pitanjima; iz partije se pravi samo
   tutorijal koji pokazuje.
   Gde: `Analyse` sa učitanom partijom → meni za podučavanje →
   `New tutorial from this game`.
   Uradi: Napravi tutorijal iz jedne partije.
   Treba da vidiš: Nema izbora `For students` / `For a video`; nijedan deo
   ne pita.
   Potrebno: partija u biblioteci.

5. [ ] **Tutorijal kome su obrisana dva pitanja se otvara i pravi video.** [246.14]
   O čemu se radi: Jedini sačuvani tutorijal sa pitanjima imao je dva dela
   `ask_move`; obrisana su 25.9.2026 (10 → 8 delova), po vlasnikovoj reči da
   se test materijal sme brisati.
   Gde: `Teach` → `Saved tutorials` → tutorijal koji je imao pitanja.
   Uradi: Otvori ga, pogledaj delove, izvezi video.
   Treba da vidiš: Osam delova koji pokazuju; video se napravi bez greške.
   Potrebno: Windows.

6. [ ] **`Record again` iz trake gasi traku posle novog snimka.** [140.3]
   O čemu se radi: Pretpostavlja stavke 138 i 139. Snimanje glasa preko
   tutorijala je pisano kao Windows-only (studio tada nije postojao na
   telefonu); otkad studio ima raspored za uzak ekran, `Record narration` je i
   tamo u `More` meniju, pa vredi probati i na telefonu, ne samo na Windowsu.
   Gde: studio (traka o zastarelom snimku) → `Record again`.
   Uradi: Iz trake o zastarelom snimku pritisni `Record again`, snimi ponovo do
   kraja (`Stop`), vrati se u studio.
   Treba da vidiš: Traka o zastarelom snimku je nestala.
   Potrebno: Windows i telefon; sačuvan tutorijal sa snimkom.

7. [ ] **Traka Flow/Tree/PGN stoji na mestu na širokom prozoru.** [155.4]
   O čemu se radi: Traka sa karticama ne sme da beži pri skrolovanju donje
   polovine studija.
   Gde: `Teach` → studio, prozor preko 840 dp.
   Uradi: Na prozoru preko 840 dp skroluj kartice u donjoj polovini studija.
   Treba da vidiš: Traka 'Flow / Tree / PGN' ostaje prikačena na mestu.
   Potrebno: Windows; sačuvan tutorijal sa više delova.

8. [ ] **Traka se prikači tek kad stigne do vrha (uzak prozor).** [155.5]
   O čemu se radi: Na uskom prozoru traka ne sme da bude prikačena pre nego što
   stigne do vrha — iznad nje tabla i spisak delova se normalno skroluju.
   Gde: `Teach` → studio, prozor uži od 840 dp.
   Uradi: Suzi prozor ispod 840 dp, skroluj stranu dok traka ne dođe do vrha.
   Treba da vidiš: Traka se prikači tek kad stigne do vrha; kartice prolaze
   ispod nje posle toga; iznad nje tabla i spisak delova se skroluju normalno.
   Potrebno: Windows; sačuvan tutorijal sa više delova.

9. [ ] **Kartica ne prosijava kroz prikačenu traku.** [155.6]
   O čemu se radi: Kad kartica prolazi ispod prikačene trake, traka mora da je
   potpuno prekrije.
   Gde: `Teach` → studio, prozor uži od 840 dp, skrolovanje.
   Uradi: Dok skroluješ (uzak prozor, iz 155.5), posmatraj granicu trake i
   kartice koja prolazi ispod nje.
   Treba da vidiš: Nema šava i nema teksta kartice koji se vidi kroz traku.
   Potrebno: Windows; sačuvan tutorijal sa više delova.

10. [ ] **Prevlačenje preko table ne skroluje stranu.** [155.7]
   O čemu se radi: Tabla uzima prevlačenje za pomeranje figure, pa strana mora
   da se skroluje kolutićem ili trakom, ne prevlačenjem preko table.
   Gde: `Teach` → studio, prozor uži od 840 dp.
   Uradi: Pokušaj da prevučeš prstom/mišem preko table da bi skrolovao stranu.
   Treba da vidiš: Strana se ne pomera (tabla to uzima za sebe); skrolovanje
   radi kolutićem miša ili trakom za skrolovanje. Ako ovo smeta u praksi,
   rešenje bi bilo skrolovanje van table, ne oduzimanje poteza tabli — zapiši
   ako smeta.
   Potrebno: Windows; sačuvan tutorijal sa više delova.

11. [ ] **Promena takta dok je crtanje uključeno sad gasi crtanje.** [117.7]
   O čemu se radi: Ranije je crtanje ostajalo uključeno kad bi trener promenio
   takt usred povlačenja strelice, pa bi sledeći klik na novoj poziciji
   nastavio da crta umesto da uradi ono što je izgledalo da će uraditi. Na
   vlasnikovu prijavu od 7.9.2026 (baš ova stavka) promenjeno je da promena
   takta u studiju sada u potpunosti isključuje crtanje, ne samo zaboravlja
   polunacrtanu strelicu — dugme za crtanje se ugasi.
   Gde: `Teach` → (kartica) `Tutorials` → (tutorijal) → (studio za tutorijal) →
   traka za crtanje ispod table.
   Uradi: Uključi `Arrow`, klikni jedno polje (počni strelicu), pa promeni takt
   u traci poteza ili tabu „Flow”, pa klikni drugo polje.
   Treba da vidiš: Nijedna strelica se ne nacrta na novoj poziciji. Dugme
   `Arrow` je sada ugašeno (crtanje je isključeno), ne ostaje upaljeno kao
   ranije — ovo je namerna izmena u odnosu na stariji opis stavke, potvrđena
   vlasnikovim zahtevom.
   Potrebno: Windows.

12. [ ] **Pomeranje dela zadržava izabrani deo, redosled se pamti.** [112.1]
   O čemu se radi: Dugmad `Move up`/`Move down` u panelu „Tutorial contents”
   menjaju redosled delova; editor posle pomeranja i dalje prikazuje isti
   (pomereni) deo, ne suseda.
   Gde: `Teach` → (kartica) `Tutorials` → (tutorijal sa bar tri dela) → (studio
   za tutorijal) → panel „Tutorial contents”
   Uradi: Stani na treći deo i pritisni `Move up`. Sačuvaj, pa ponovo otvori
   tutorijal.
   Treba da vidiš: Posle pomeranja editor i dalje pokazuje taj isti (sad drugi
   po redu) deo — naziv u polju je njegov, ne od suseda kog je pretekao. Posle
   ponovnog otvaranja redosled je zapamćen.
   Potrebno: Windows.

13. [ ] **Strelice za pomeranje su ugašene na krajevima spiska.** [112.6]
   O čemu se radi: `Move up` je onemogućeno na prvom delu, `Move down` na
   poslednjem — nema pokušaja da se izađe iz spiska.
   Gde: `Teach` → (kartica) `Tutorials` → (tutorijal sa bar tri dela) → (studio
   za tutorijal) → panel „Tutorial contents”
   Uradi: Stani na prvi deo i pogledaj `Move up`; stani na poslednji i pogledaj
   `Move down`.
   Treba da vidiš: `Move up` je onemogućeno (zasivljeno) na prvom delu,
   `Move down` na poslednjem.
   Potrebno: Windows.

14. [ ] **Strelice na tastaturi šetaju liniju u studiju.** [109.7]
   O čemu se radi: Kretanje kroz odigrane poteze tastaturom (levo/desno) radi u
   studiju isto kao u Analysis Studiju.
   Gde: `Teach` → (kartica) `Tutorials` → (otvori tutorijal) → (studio za
   tutorijal).
   Uradi: Otvori tutorijal sa bar nekoliko odigranih poteza u jednom delu i
   pritisni strelice levo/desno na tastaturi.
   Treba da vidiš: Tabla i traka poteza idu potez napred/nazad na svaki
   pritisak, isto kao dugmad ispod table.
   Potrebno: Windows.

15. [ ] **Izmena i čuvanje ne gube postojeće korake.** [108.21]
   O čemu se radi: Menjanje teksta jednog koraka i čuvanje ne sme da izbriše
   ili pomeša ostale korake; preimenovanje jedne sačuvane pozicije van
   tutorijala (popravka iz 7a) ne sme da dirne tutorijal koji je koristi.
   Gde: `Teach` → (kartica) `Tutorials` → (tutorijal sa bar dva koraka) →
   (studio za tutorijal).
   Uradi: Otvori postojeći tutorijal, promeni tekst jednog koraka, sačuvaj, pa
   ga otvori ponovo. Zatim preimenuj jednu sačuvanu poziciju iz Biblioteke (van
   tutorijala) i proveri da tutorijal sa koracima nije dirnut.
   Treba da vidiš: Svi koraci su tu, istim redom, posle čuvanja i ponovnog
   otvaranja. Preimenovanje pozicije u Biblioteci ne menja ništa u tutorijalu.
   Potrebno: Windows.

16. [ ] **Brisanje dela pita i imenuje ga.** [112.4]
   O čemu se radi: `Delete part` pita pre brisanja i u pitanju imenuje baš taj
   deo; `Cancel` ga ostavlja netaknutog.
   Gde: `Teach` → (kartica) `Tutorials` → (tutorijal sa bar dva dela) → (studio
   za tutorijal) → panel „Tutorial contents” → `Delete part`.
   Uradi: Pritisni `Delete part` na nekom delu. Prvo izaberi `Cancel`, proveri
   da je deo ostao. Ponovi i ovog puta potvrdi brisanje.
   Treba da vidiš: Dijalog za potvrdu imenuje deo koji se briše. `Cancel` ga
   ostavlja netaknutog; potvrda ga briše, a ostali delovi ostaju netaknuti.
   Potrebno: Windows.

17. [ ] **Poslednji deo se ne može obrisati.** [112.5]
   O čemu se radi: Tutorijal mora imati bar jedan deo — na tutorijalu sa samo
   jednim delom `Delete part` odbija brisanje umesto da pita.
   Gde: `Teach` → (kartica) `Tutorials` → (tutorijal sa tačno jednim delom) →
   (studio za tutorijal) → panel „Tutorial contents” → `Delete part`.
   Uradi: Na tutorijalu koji ima samo jedan deo pritisni `Delete part`.
   Treba da vidiš: Prikaže se poruka da poslednji deo ne može da se obriše —
   nema pitanja za potvrdu, ništa se ne briše.
   Potrebno: Windows.

18. [ ] **U videu: rečenica, crtež i okrenuta tabla.** [133.5]
   O čemu se radi: Prvi objavljeni tutorijal (12.9.2026) je dokazao skoro sve
   iz ove stavke osim jednog dela — nije imao deo pisan sa crne strane, pa
   okrenuta tabla u videu nije viđena.
   Gde: `Teach` → (kartica) `Tutorials` → (tutorijal sa bar dva dela, jedan
   pisan sa crne strane) → `Export video`.
   Uradi: Izvezi u video tutorijal koji ima bar dva dela — jedan sa crtežom i
   rečenicom, i jedan pisan/okrenut sa crne strane.
   Treba da vidiš: U snimljenom videu: rečenica ispod table je čitljiva do
   kraja; strelice/obojena polja stoje na potezu kome pripadaju; drugi deo
   počinje bez osvetljenog poteza iz prvog; deo pisan sa crne strane je
   prikazan okrenuto.
   Potrebno: Windows; DeepSeek ključ na serveru.

19. [ ] **Traka napretka ide u koracima od 10%.** [133.11]
   O čemu se radi: Procena preostalog vremena pored procenta pada kako render
   odmiče i na kraju kaže da je posao skoro gotov umesto da broji do nule na
   poslednjih par sekundi.
   Gde: `Teach` → (kartica) `Tutorials` → (tutorijal) → `Export video` →
   `Export`.
   Uradi: Pokreni izvoz videa i prati traku napretka do kraja.
   Treba da vidiš: Procena se ispisuje kao „... about N s left”/„about N
   minute(s) left” i pada kako render odmiče; u poslednjih desetak sekundi
   umesto brojanja do nule piše „... almost done”.
   Potrebno: Windows; DeepSeek ključ na serveru.

20. [ ] **Server ostaje odgovoran dok traje izvoz videa.** [133.14]
   O čemu se radi: Renderovanje videa ne sme da blokira ostatak servera —
   spisak tutorijala, zadaci i ostali pozivi rade normalno dok traje izvoz.
   Gde: `Teach` → (kartica) `Tutorials` → (tutorijal) → `Export video` →
   `Export`.
   Uradi: Pokreni izvoz videa, pa dok traje otvori nešto drugo u aplikaciji
   (spisak tutorijala, `My Assignments`, Biblioteku).
   Treba da vidiš: Ostatak aplikacije radi normalno dok se video renderuje —
   ništa se ne zaglavljuje niti čeka da render završi.
   Potrebno: Windows; DeepSeek ključ na serveru.

21. [ ] **Video bez glasa to i kaže u dijalogu „Video ready!”** [133.15]
   O čemu se radi: Kad je glas tražen ali nije stigao (npr. glasovni sistem
   nije instaliran na serveru), dijalog o gotovom videu nosi dodatnu rečenicu
   koja to objašnjava.
   Gde: `Teach` → (kartica) `Tutorials` → (tutorijal) → `Export video` →
   izaberi glas, pa izvezi na serveru bez instaliranog glasovnog sistema.
   Uradi: Izazovi izvoz sa traženim glasom na serveru koji ne može da ga
   proizvede (ili zatraži od servera/vlasnika da potvrdi ovaj slučaj).
   Treba da vidiš: Dijalog o gotovom videu nosi rečenicu koja počinje sa „It
   has no narration: …” (npr. „...this server has no speech voices
   installed.”), umesto da izgleda kao svaki drugi uspešan izvoz.
   Potrebno: Windows; DeepSeek ključ na serveru.

22. [ ] **Dva istovremena renderovanja dobiju dva fajla.** [133.16]
   O čemu se radi: Dva izvoza u isto vreme (dva naloga, ili dva puta isti
   tutorijal) više ne dele ime fajla. Onaj koji čeka red vidi poruku o čekanju,
   pa pređe na traku sa procentima kad dođe na red.
   Gde: `Teach` → (kartica) `Tutorials` → (tutorijal) → `Export video` →
   `Export` (pokreni dvaput zaredom, ili sa dva naloga).
   Uradi: Pokreni izvoz videa na dva naloga istovremeno (ili dva puta isti
   tutorijal ubrzo jedno za drugim).
   Treba da vidiš: Oba izvoza na kraju stignu, kao dva različita fajla, i oba
   se otvaraju. Onaj koji čeka prikazuje „Your video will start rendering
   shortly — one video ahead of it.” dok čeka, pa pređe na traku sa procentima
   kad dođe na red.
   Potrebno: Windows; DeepSeek ključ na serveru.

23. [ ] **Potezi u naraciji se izgovaraju kao reči, ne slovkaju se.** [133.17]
   O čemu se radi: Sintetizovani glas čita algebarsku notaciju kao govor (npr.
   „bishop d five” na engleskom), ne slovo po slovo; natpis na ekranu ostaje
   nepromenjen (npr. „Bd5”) — menja se samo ono što se izgovara.
   Gde: `Teach` → (kartica) `Tutorials` → (deo sa komentarom „Bd5”, „O-O”,
   „Nxe5+”) → `Export video` (sintetizovan glas).
   Uradi: Napiši u komentaru poteze „Bd5”, „O-O” i „Nxe5+”, izvezi video sa
   sintetizovanim glasom (probaj engleski, i ako je dostupan drugi jezik) i
   preslušaj.
   Treba da vidiš: Glas izgovara potez kao reči (npr. engleski „bishop d
   five”), ne slovka ga slovo po slovo. Natpis na ekranu i dalje piše „Bd5” —
   nepromenjen.
   Potrebno: Windows; DeepSeek ključ na serveru.

24. [ ] **Ocene poteza (?? i !) prežive prvo čuvanje uvezene partije.** [158.8]
   O čemu se radi: Do 12.9.2026 su se ocene gubile pri prvom snimanju posle
   uvoza.
   Gde: `Teach` → `Tutorials` → `Import from a file`.
   Uradi: Otvori uvezenu partiju, izmeni nešto bilo gde, sačuvaj, pa je ponovo
   otvori.
   Treba da vidiš: Oznake ?? i ! i dalje stoje na istim potezima.
   Potrebno: Windows; PGN fajl; uvezene partije.

25. [ ] **Novi deo se dodaje odmah ispod izabranog, prazan.** [112.2]
   O čemu se radi: „New demonstration” dodaje nov, prazan deo tačno ispod dela
   na kom trener stoji (bez pitanja i bez rešenja).
   Gde: `Teach` → (kartica) `Tutorials` → (tutorijal) → (studio za tutorijal) →
   panel „Tutorial contents” → `New demonstration`.
   Uradi: Stani na neki deo i pritisni `New demonstration`. Preimenuj novi deo,
   sačuvaj, pa ponovo otvori tutorijal.
   Treba da vidiš: Novi deo se pojavi odmah ispod izabranog, prazan (bez
   pitanja/rešenja). Posle ponovnog otvaranja i dalje je tu, pod tim nazivom.
   Potrebno: Windows.

26. [ ] **Prazan tutorijal odbija izvoz videa bez slanja serveru.** [133.2]
   O čemu se radi: Izvoz videa na tutorijalu koji nema šta da pokaže se odbija
   odmah na ekranu, bez ijednog zahteva serveru.
   Gde: `Teach` → (kartica) `Tutorials` → `New tutorial` (bez ijednog dela sa
   sadržajem) → `Export video`.
   Uradi: Napravi prazan tutorijal (bez sadržaja) i pritisni `Export video`.
   Treba da vidiš: Pojavi se poruka „This tutorial has nothing to show yet.” i
   ništa se ne šalje serveru (nema trake napretka niti zahteva).
   Potrebno: Windows.

27. [ ] **Pisanje dva primera u jednom dahu, bez gubljenja pozicije.** [111.1]
   O čemu se radi: Trener može da napiše ceo kratak tutorijal u jednom sedenju:
   ime, linija sa komentarom uz svaki potez za prvi primer, pa novi deo za
   drugi primer sa svojim tipom zadatka.
   Gde: `Teach` → (kartica) `Tutorials` → `New tutorial`.
   Uradi: Upiši ime tutorijala. Odigraj liniju sa komentarom uz svaki potez za
   prvi deo. Dodaj novi deo („New demonstration”) za drugi primer, postavi mu
   tip „Ask for move on board” i odigraj tačan potez (bez čuvanja).
   Treba da vidiš: Nakon dodavanja drugog dela tabla ostaje na poziciji na
   kojoj se prvi deo završio (ne resetuje se). Odigran tačan potez na pitanju
   ispisuje „Tačan potez: …”-tipa poruku, ali se sam potez ne dodaje u liniju
   drugog dela.
   Potrebno: Windows.

28. [ ] **Ništa ne ide na server pre „Save tutorial”** [111.2]
   O čemu se radi: Tutorijal se ne pojavljuje u biblioteci dok se eksplicitno
   ne pritisne dugme za čuvanje — rad u nacrtu ostaje lokalan.
   Gde: `Teach` → (kartica) `Tutorials` → `New tutorial`.
   Uradi: Napiši deo tutorijala (ime, par poteza) bez pritiska na
   `Save tutorial`. Otvori `Teach` → `Tutorials` → `Saved tutorials` u drugom
   prozoru/kartici.
   Treba da vidiš: Nov tutorijal se ne pojavljuje na polici dok se ne pritisne
   `Save tutorial` u studiju.
   Potrebno: Windows.

29. [ ] **Ime tutorijala preživi zatvaranje prozora.** [111.4]
   O čemu se radi: Popravka vođe pri spajanju — ime je bilo jedino polje koje
   se nije vraćalo iz nesačuvanog nacrta; sada se vraća kao i sve ostalo.
   Gde: `Teach` → (kartica) `Tutorials` → `New tutorial`.
   Uradi: Upiši ime tutorijala i dodaj bar jedan primer. Zatvori prozor/karticu
   odmah, bez čuvanja. Ponovo otvori studio i nastavi nacrt.
   Treba da vidiš: I ime tutorijala i primeri su tu, netaknuti.
   Potrebno: Windows.

30. [ ] **Nesačuvan nacrt tutorijala preživi zatvaranje prozora.** [109.6]
   O čemu se radi: Studio čuva nesačuvan rad u nacrtu (draft) dok se piše. Ako
   se prozor zatvori pre eksplicitnog čuvanja, sledeće otvaranje studija nudi
   da se taj nacrt nastavi.
   Gde: `Teach` → (kartica) `Tutorials` → `New tutorial` (ili otvori postojeći)
   → (studio za tutorijal).
   Uradi: Odigraj par poteza u studiju bez pritiska na `Save tutorial`. Zatvori
   prozor/karticu odmah (ne čekaj). Ponovo otvori studio (isti tutorijal ili
   `New tutorial`).
   Treba da vidiš: Pojavi se dijalog koji nudi da se nastavi nesačuvan rad
   (`Continue`) ili odbaci (`New`). Izborom nastavka, tabla stoji tačno na
   potezu na kom si stao i svi odigrani potezi su tu.
   Potrebno: Windows.

31. [ ] **Tekst bez svog [FEN]-a pita kad ima šta da ponudi.** [128.1]
   O čemu se radi: Kad nalepljeni tekst nema `[FEN]` zaglavlje i ne igra se sa
   pozicije dela, ali se uredno igra od početne pozicije partije, studio pita
   da li da deo prebaci na početnu poziciju.
   Gde: `Teach` → (kartica) `Tutorials` → (deo koji stoji na nekoj završnici) →
   (studio za tutorijal) → tab `PGN`.
   Uradi: Otvori deo koji stoji na nekoj završnici (ne na početnoj poziciji),
   nalepi običnu partiju od `1. e4` (bez `[FEN]` zaglavlja) i pritisni `Apply`.
   Treba da vidiš: Pojavi se dijalog „Text does not start from here”.
   Potrebno: Windows.

32. [ ] **„Use starting position” odigra celu liniju.** [128.2]
   O čemu se radi: Izbor da se koristi početna pozicija menja deo tako da mu
   tabla postane početna pozicija partije, a nalepljena linija se cela odigra.
   Gde: `Teach` → (kartica) `Tutorials` → (deo koji stoji na nekoj završnici) →
   (studio za tutorijal) → tab `PGN` → dijalog „Text does not start from here”
   Uradi: U dijalogu iz prethodne stavke pritisni `Use starting position`.
   Treba da vidiš: Deo se prebaci na početnu poziciju partije i cela nalepljena
   linija se odigra u „Flow”/tabli.
   Potrebno: Windows.

33. [ ] **„Keep existing” odbije tekst uz poruku.** [128.3]
   O čemu se radi: Ako trener zadrži postojeću poziciju dela, tekst se odbija
   uz poruku koja kaže da tekst nema svoju polaznu poziciju (`[FEN]`) —
   rečenica koja je ranije nedostajala.
   Gde: `Teach` → (kartica) `Tutorials` → (deo koji stoji na nekoj završnici) →
   (studio za tutorijal) → tab `PGN` → dijalog „Text does not start from here”
   Uradi: U dijalogu pritisni `Keep existing`.
   Treba da vidiš: Tekst se odbija, a poruka kaže da tekst nema svoju polaznu
   poziciju (nema `[FEN]`), pored broja poteza koji ne mogu da se odigraju.
   Potrebno: Windows.

34. [ ] **„Cancel” ne menja ništa i ne javlja grešku.** [128.4]
   O čemu se radi: Otkazivanje dijaloga ostavlja tekst u polju netaknut, bez
   ikakve poruke o grešci.
   Gde: `Teach` → (kartica) `Tutorials` → (deo koji stoji na nekoj završnici) →
   (studio za tutorijal) → tab `PGN` → dijalog „Text does not start from here”
   Uradi: U dijalogu pritisni `Cancel`.
   Treba da vidiš: Ništa se ne menja — deo ostaje kakav je bio, tvoj nalepljen
   tekst je i dalje u polju, i ne pojavljuje se nikakva poruka o grešci.
   Potrebno: Windows.

35. [ ] **Tekst koji ne ide nigde i dalje kaže isto.** [128.5]
   O čemu se radi: Kad nalepljen tekst bez `[FEN]`-a ne igra se ni sa pozicije
   dela ni sa početne pozicije partije, nema pitanja (nema šta da se ponudi),
   ali poruka o odbijanju i dalje kaže da tekst nema svoju polaznu poziciju.
   Gde: `Teach` → (kartica) `Tutorials` → (deo) → (studio za tutorijal) → tab
   `PGN`.
   Uradi: Nalepi liniju bez `[FEN]`-a koja se ne može odigrati ni sa pozicije
   dela ni sa početne pozicije partije, i pritisni `Apply`.
   Treba da vidiš: Nema pitanja/dijaloga — odmah se pojavljuje poruka o
   odbijanju, koja i dalje kaže da tekst nema svoju polaznu poziciju.
   Potrebno: Windows.

36. [ ] **Fragment koji se uredno igra odavde se primenjuje bez pitanja.**
   [128.6]
   O čemu se radi: Kad nalepljen tekst bez `[FEN]`-a jednostavno nastavlja
   liniju sa pozicije na kojoj deo već stoji (npr. dopisan potez na kraj), ne
   postavlja se nikakvo pitanje — primeni se odmah, kao i pre ove izmene.
   Gde: `Teach` → (kartica) `Tutorials` → (deo) → (studio za tutorijal) → tab
   `PGN`.
   Uradi: Nalepi kratak fragment (bez `[FEN]`-a) koji se uredno igra sa
   pozicije na kojoj deo već stoji (npr. postojeća linija plus jedan dopisan
   potez), i pritisni `Apply`.
   Treba da vidiš: Tekst se primeni odmah, bez ijednog pitanja.
   Potrebno: Windows.

37. [ ] **Primena PGN teksta drži fokus na poslednjem unetom potezu.** [121.1]
   O čemu se radi: Dve popravke u jednom: zvezdica zalepljena za poslednji
   potez (bez razmaka, npr. „...Nxb4*”) više ne kvari čitanje inače legalne
   linije, i posle `Apply` fokus (tekući takt u „Flow”/tabla) ostaje na
   poslednjem unetom potezu umesto da skoči nazad na početak linije.
   Gde: `Teach` → (kartica) `Tutorials` → (tutorijal) → (studio za tutorijal) →
   tab `PGN`.
   Uradi: Ukucaj liniju koja se završava sa „...exd5 Nxb4*” (bez razmaka ispred
   zvezdice) i pritisni `Apply`.
   Treba da vidiš: Linija se primeni bez greške, poslednji potez (Nxb4) je u
   „Toku”/na tabli, i to je pozicija na kojoj tabla ostaje posle primene — ne
   vraća se na početak linije.
   Potrebno: Windows.

38. [ ] **Odbijanje nemoguće linije imenuje broj poteza.** [120.5]
   O čemu se radi: Kad tekst u tabu „PGN” sadrži potez koji se stvarno ne može
   odigrati sa te pozicije, „Apply” odbija tekst i kaže koliko poteza ne može
   da se odigra, a deo ostaje nepromenjen. Vlasnikova prijava da se ovo
   dešavalo i za sasvim legalnu liniju (zvezdica zalepljena za poslednji potez,
   bez razmaka) je popravljena — vidi stavku 121.1.
   Gde: `Teach` → (kartica) `Tutorials` → (tutorijal) → (studio za tutorijal) →
   tab `PGN`.
   Uradi: Ukucaj u tab `PGN` liniju koja sadrži potez koji se stvarno ne može
   odigrati sa pozicije tog dela (npr. potez nepostojeće figure) i pritisni
   `Apply`.
   Treba da vidiš: Pojavi se poruka „Not applied: N move(s) cannot be played
   from the position of this part.” sa tačnim brojem, a „Flow”/tabla ostaju
   nepromenjeni.
   Potrebno: Windows.

39. [ ] **Prava anotirana partija (komentari, strelice, varijante) preživi
   nalepljivanje.** [120.6]
   O čemu se radi: Ova provera nije rađena jer vlasnik nije imao pri ruci
   anotiranu partiju sa `[%cal]`/`[%csl]` oznakama — sad je potrebno naći jednu
   (npr. sa Lichess-a, iz knjige, ili izlaz alata iz `D:\chess books`) i zaista
   je nalepiti.
   Gde: `Teach` → (kartica) `Tutorials` → (tutorijal) → (studio za tutorijal) →
   tab `PGN`.
   Uradi: Nalepi anotiranu partiju sa komentarima, strelicama (`[%cal]`) i
   obojenim poljima (`[%csl]`) koja počinje sa iste pozicije kao deo, i
   pritisni `Apply`. Pogledaj kroz `Preview tutorial`.
   Treba da vidiš: Komentari, strelice i varijante iz nalepljenog teksta se
   vide i u „Flow”/tabli i u pregledu za učenika — ništa od toga se ne gubi.
   Potrebno: Windows; PGN fajl.

40. [ ] **Nalepljena partija iz druge pozicije pita šta uraditi.** [120.14]
   O čemu se radi: Kad nalepljeni PGN nosi svoj `[FEN]` različit od pozicije na
   kojoj deo stoji, studio pita pre nego što bilo šta primeni, sa tri izbora.
   Gde: `Teach` → (kartica) `Tutorials` → (tutorijal) → (studio za tutorijal) →
   tab `PGN`.
   Uradi: Nalepi PGN koji ima svoj `[FEN]` različit od pozicije dela i pritisni
   `Apply`. Probaj sva tri dugmeta u tri odvojena pokušaja:
   `Use that position`, `Keep existing`, `Cancel`.
   Treba da vidiš: Pojavi se dijalog „Text starts from a different position”.
   `Use that position` prebaci deo na tu poziciju i odigra liniju;
   `Keep existing` odbije tekst uz poruku o broju poteza koji ne mogu da se
   odigraju; `Cancel` ne menja ništa i ne javlja grešku.
   Potrebno: Windows.

41. [ ] **Isti položaj sa drugim brojačima ne pokreće pitanje.** [120.15]
   O čemu se radi: Poređenje pozicije pri lepljenju PGN-a namerno izostavlja
   brojače poteza/poluportova (satove) — deo na koji si stigao igranjem i deo
   napisan iz iste pozicije se smatraju istom tablom.
   Gde: `Teach` → (kartica) `Tutorials` → (tutorijal) → (studio za tutorijal) →
   tab `PGN`.
   Uradi: Nalepi PGN čiji se `[FEN]` razlikuje od pozicije dela samo po brojaču
   poteza (npr. `... 12 34` umesto `... 5 9`), i pritisni `Apply`.
   Treba da vidiš: Nema nikakvog pitanja — tekst se odmah primeni (ili odbije
   po sadržaju poteza), pošto se brojači ne računaju kao razlika u poziciji.
   Potrebno: Windows.

42. [ ] **Studio za tutorijal ima samo dve kartice za postavljanje pozicije.**
   [130.2]
   O čemu se radi: Studio namerno ne prosleđuje uvoz PGN-a u ovaj dijalog (uvoz
   linije je posao Analysis Studija), pa se tu vide samo kartice `FEN` i
   `Pieces` — bez `PGN`, `Openings` ili `Online`.
   Gde: `Teach` → (kartica) `Tutorials` → (tutorijal) → (studio za tutorijal) →
   `Position setup`.
   Uradi: Otvori `Position setup` u studiju za tutorijal.
   Treba da vidiš: Dijalog ima tačno dve kartice: `FEN` i `Pieces`. Nema
   kartica `PGN`, `Openings` ni `Online`.
   Potrebno: Windows.

43. [ ] **Izvoz u PGN kaže na koliko se partija tutorijal deli.** [159.1]
   O čemu se radi: Dijalog „Save as .pgn“ pre upisa fajla kaže da li se delovi
   tutorijala nadovezuju u jednu partiju ili razdvajaju u više njih.
   Gde: `Teach` → `Tutorials` (kartica) → `Saved tutorials` → izaberi tutorijal
   → alatka `Save as .pgn`.
   Uradi: Otvori tutorijal čiji se delovi nadovezuju jedan na drugi (ista
   linija poteza) i pritisni `Save as .pgn`. Zatim otvori tutorijal koji ima
   deo na sasvim drugoj poziciji (npr. drugo otvaranje) i ponovi.
   Treba da vidiš: U prvom slučaju rečenica u dijalogu se završava sa „...one
   game.“ (jedna partija). U drugom slučaju piše „... games —“ sa brojem
   partija većim od 1.
   Potrebno: Windows.

44. [ ] **Dijalog kaže šta PGN ne nosi.** [159.2]
   O čemu se radi: Isti dijalog objašnjava da pitanje dela, odgovor, prihvaćeni
   potezi, strana table, naslov, oznake i jezik ostaju samo u sačuvanom
   tutorijalu — PGN ih ne nosi.
   Gde: `Teach` → `Tutorials` (kartica) → `Saved tutorials` → izaberi tutorijal
   → alatka `Save as .pgn`.
   Uradi: Otvori bilo koji tutorijal i pritisni `Save as .pgn`. Pročitaj
   napomenu ispod rečenice o broju partija.
   Treba da vidiš: Piše da PGN nosi poteze, rečenice, crteže i ocene, a da ono
   što deo pita (odgovor, prihvaćeni potezi, strana table) i
   naslov/oznake/jezik tutorijala ostaju iza — sačuvani tutorijal ih čuva sve.
   Potrebno: Windows.

45. [ ] **Ime izvezenog fajla je naslov tutorijala.** [159.3]
   O čemu se radi: Fajl se imenuje po naslovu tutorijala (razmaci postaju
   crtice); tutorijal bez naslova dobija ime po datumu.
   Gde: `Teach` → `Tutorials` (kartica) → `Saved tutorials` → izaberi tutorijal
   → alatka `Save as .pgn`.
   Uradi: Sačuvaj nazvan tutorijal kroz `Save as .pgn` i pogledaj predloženo
   ime fajla. Napravi (ili nađi) tutorijal bez naslova i ponovi.
   Treba da vidiš: Ime fajla je naslov tutorijala sa razmacima zamenjenim
   crticama (npr. „moj-tutorijal.pgn“). Bez naslova ime je oblika
   `tutorial-GGGG-MM-DD.pgn` sa današnjim datumom.
   Potrebno: Windows; PGN fajl.

46. [ ] **Fajl ima onoliko partija koliko je dijalog najavio.** [159.4]
   O čemu se radi: Kada se tutorijal razdvaja u više partija, fajl ih upisuje
   razdvojene praznim redom, svaka sa svojim zaglavljem; druga i svaka sledeća
   partija koja ne počinje od početne pozicije nosi `[SetUp "1"]` i `[FEN]`.
   Gde: `Teach` → `Tutorials` (kartica) → `Saved tutorials` → izaberi tutorijal
   → alatka `Save as .pgn`.
   Uradi: Sačuvaj tutorijal sa više partija kroz `Save as .pgn` i otvori
   dobijeni .pgn fajl u tekst editoru.
   Treba da vidiš: Broj partija u fajlu (odvojenih praznim redom) odgovara
   broju iz dijaloga; svaka partija ima svoje zaglavlje, a partije koje ne
   počinju od početne pozicije imaju `[SetUp "1"]` i `[FEN ...]` red.
   Potrebno: Windows; PGN fajl.

47. [ ] **Izvezeni PGN se čita nazad bez primedbi.** [159.7]
   O čemu se radi: Put napolje i nazad: fajl izvezen iz tutorijala mora da se
   pročita natrag kroz uvoznik bez ijedne primedbe o pokvarenom potezu.
   Gde: `Teach` → `Tutorials` (kartica) → `Saved tutorials` → izaberi tutorijal
   → alatka `Save as .pgn`; zatim `Teach` → `Tutorials` (kartica) →
   `Import from a file`.
   Uradi: Izvezi tutorijal u .pgn, pa isti fajl uvezi nazad preko
   `Import from a file`.
   Treba da vidiš: Sve partije se pročitaju bez ijedne primedbe (redovi su
   zeleni, nema upozorenja o odbačenom potezu).
   Potrebno: Windows; PGN fajl.

48. [ ] **Izvoz uzima ono što je na ekranu, ne poslednje sačuvano.** [159.8]
   O čemu se radi: `Save as .pgn` izvozi trenutni nacrt (uključujući nesačuvane
   izmene), ne poslednju sačuvanu verziju tutorijala.
   Gde: `Teach` → `Tutorials` (kartica) → `Saved tutorials` → izaberi tutorijal
   → alatka `Save as .pgn`.
   Uradi: Otvori tutorijal, dopiši novu rečenicu u nekom delu, **ne** pritiskaj
   `Save tutorial`, nego odmah `Save as .pgn` i sačuvaj fajl.
   Treba da vidiš: Nova, nesačuvana rečenica se nalazi u izvezenom fajlu.
   Potrebno: Windows.

49. [ ] **Cancel ne radi ništa; uspešan izvoz javlja putanju.** [159.9]
   O čemu se radi: U dijalogu za izvoz, `Cancel` zatvara dijalog bez upisa;
   posle uspešnog snimanja dijalog se zatvara sam i javlja se poruka sa
   putanjom fajla.
   Gde: `Teach` → `Tutorials` (kartica) → `Saved tutorials` → izaberi tutorijal
   → alatka `Save as .pgn`.
   Uradi: Otvori `Save as .pgn`, pritisni `Cancel` i proveri da ništa nije
   upisano. Ponovi i ovog puta sačuvaj kroz `Save as .pgn`.
   Treba da vidiš: Posle `Cancel` nema fajla ni poruke. Posle uspešnog snimanja
   dijalog se zatvara i pojavljuje se poruka koja počinje sa `Saved: …`
   (putanja fajla).
   Potrebno: Windows.

50. [ ] **Traka studija ne seče dugmad na uskom prozoru.** [159.10]
   O čemu se radi: Dugme `Save as .pgn` je sedmo od devet kontrola u gornjoj
   traci studija (Undo, Redo, Discard changes, Position setup, Record
   narration, Export video, Save as .pgn, Preview tutorial, Save tutorial).
   Naslov „Tutorial Studio“ se skraćuje sa tri tačkice kad nema mesta, umesto
   da gura dugmad van ekrana.
   Gde: `Teach` → `Tutorials` (kartica) → `Saved tutorials` → izaberi
   tutorijal.
   Uradi: Otvori tutorijal na Windows-u i suzi prozor postepeno od širokog ka
   uskom (oko 650–700 dp širine trake).
   Treba da vidiš: Nijedno dugme u traci se ne seče niti izlazi van ekrana;
   kada prostora nestane, naslov „Tutorial Studio“ se skraćuje na „Tutorial
   Stud…“ (tri tačkice), a sva dugmad ostaju vidljiva i klikabilna.
   Potrebno: Windows.

51. [ ] **Obrisan deo se vraća sa Undo, i ostaje posle čuvanja.** [151.1]
   O čemu se radi: Vlasnikov odgovor 'ok' je pratila napomena da je navikao da
   čuvanje resetuje Undo/Redo (da se ne može vratiti dok se ne naprave nove
   izmene) — to trenutno nije tako: `Save tutorial` ne prazni istoriju izmena,
   samo gasi `Discard changes`. Osnovna provera (obrisan deo se vraća) ostaje
   da se potvrdi; dodatno primeti da li ti to što Undo radi i posle čuvanja
   smeta u praksi.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (tutorijal sa bar dva dela)
   → studio.
   Uradi: Obriši jedan deo (`Delete part`), pa pritisni `Undo (Ctrl+Z)` (ili
   Ctrl+Z); zatim `Save tutorial`, zatvori studio, otvori ga ponovo.
   Treba da vidiš: Posle Undo-a deo je ponovo na istom mestu; posle čuvanja,
   zatvaranja i ponovnog otvaranja deo je i dalje tu. Primeti (i reci vlasniku)
   da `Undo (Ctrl+Z)` ostaje dostupan i posle `Save tutorial` — ako to ne
   odgovara očekivanju, to je zasebna odluka o ponašanju, ne kvar ove provere.
   Potrebno: Windows i telefon; sačuvan tutorijal sa bar dva dela.

52. [ ] **`Discard changes` vraća potez; `Save tutorial` treba da bude sivo
   posle čuvanja.** [151.6]
   O čemu se radi: Poznat problem, nije popravljen: Dugme `Save tutorial` nema
   uslov onPressed — nikad nije sivo/onemogućeno, ni kad nema izmena za
   čuvanje. Prijavljeno 11.9.2026: `Save tutorial` dugme nikad ne postane sivo,
   ni odmah posle čuvanja kad nema šta drugo da se sačuva. Potvrđeno u kodu
   (25.9.2026) — dugme je uvek klikabilno.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (tutorijal) → studio.
   Uradi: Odigraj potez na tabli, pritisni `Discard changes`, proveri da potez
   nestane i da ga Ctrl+Z vrati; zatim pritisni `Save tutorial`.
   Treba da vidiš: Potez nestaje posle `Discard changes` i Ctrl+Z ga vraća — to
   radi. Ali `Save tutorial` ostaje klikabilno (nije sivo) i posle čuvanja,
   suprotno onome što se očekuje da se vidi.
   Potrebno: Windows i telefon; sačuvan tutorijal.

53. [ ] **Izmena rečenice odmah pokazuje traku o zastarelom snimku.** [140.1]
   O čemu se radi: Marker imenuje takt po redu; prepravljena rečenica (bez
   promene broja taktova) menja glas na pogrešnom mestu, pa potpis liste
   taktova mora to da uhvati. Pretpostavlja stavke 138 i 139. Snimanje glasa
   preko tutorijala je pisano kao Windows-only (studio tada nije postojao na
   telefonu); otkad studio ima raspored za uzak ekran, `Record narration` je i
   tamo u `More` meniju, pa vredi probati i na telefonu, ne samo na Windowsu.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (otvori sačuvan tutorijal
   sa snimkom) → studio, karta Flow.
   Uradi: U studiju, na sačuvanom tutorijalu sa snimkom, izmeni samo jednu
   rečenicu komentara (ništa drugo) — ne zatvaraj ekran.
   Treba da vidiš: Odmah se, iznad spiska delova, pojavljuje traka koja kaže da
   je tutorijal izmenjen posle snimka (backtick fragment
   `This tutorial has been edited since your recording was made`), sa dugmadima
   `Record again` i `Export without your voice`.
   Potrebno: Windows i telefon; sačuvan tutorijal sa snimkom.

54. [ ] **Strelica i krug na tabli ne obaraju snimak.** [140.6]
   O čemu se radi: Pretpostavlja stavke 138 i 139. Snimanje glasa preko
   tutorijala je pisano kao Windows-only (studio tada nije postojao na
   telefonu); otkad studio ima raspored za uzak ekran, `Record narration` je i
   tamo u `More` meniju, pa vredi probati i na telefonu, ne samo na Windowsu.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (tutorijal sa snimkom) →
   studio → tabla.
   Uradi: Nacrtaj strelicu i oboj polje na nekom taktu, sačuvaj.
   Treba da vidiš: Traka o zastarelom snimku se ne pojavljuje; izvoz i dalje
   nudi `My recording …`.
   Potrebno: Windows i telefon; sačuvan tutorijal sa snimkom.

55. [ ] **Snimak napravljen pre potpisa se i dalje sudi po broju taktova.**
   [140.7]
   O čemu se radi: Snimak bez potpisa liste taktova (napravljen pre ove faze)
   ne sme da bude odbijen na pravom tutorijalu — sudi se po starom pravilu
   (broj taktova).
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → (tutorijal sa starijim
   snimkom) → `Export video`.
   Uradi: Otvori tutorijal sa snimkom napravljenim pre ove faze (bez potpisa),
   bez ijedne izmene posle snimka, i otvori `Export video`.
   Treba da vidiš: Ponuđeno je `My recording …` — snimak nije odbijen samo zato
   što nema potpis, dok broj taktova odgovara.
   Potrebno: Windows i telefon; sačuvan tutorijal; stariji snimak bez potpisa.

56. [ ] **Preimenovanje ne obara snimak.** [140.5]
   O čemu se radi: Pola faze — sat vremena snimanja ne sme da propadne zbog
   naslova. Pretpostavlja stavke 138 i 139. Snimanje glasa preko tutorijala je
   pisano kao Windows-only (studio tada nije postojao na telefonu); otkad
   studio ima raspored za uzak ekran, `Record narration` je i tamo u `More`
   meniju, pa vredi probati i na telefonu, ne samo na Windowsu.
   Gde: studio → `Tutorial title` polje, i (preimenovanje dela) → `Rename`.
   Uradi: Preimenuj sam tutorijal (polje `Tutorial title`), sačuvaj; zatim
   preimenuj jedan deo (`Rename`), sačuvaj.
   Treba da vidiš: Traka o zastarelom snimku se ne pojavljuje ni posle jedne
   izmene; `Export video` i dalje nudi `My recording …`.
   Potrebno: Windows i telefon; sačuvan tutorijal sa snimkom.

57. [ ] **Telefon položeno: tabla levo celom visinom, tabovi desno.** [179.7]
   O čemu se radi: Isti raspored kao ostali ekrani u položenom telefonu — tabla
   zauzima levu stranu celom visinom.
   Gde: Teach → kartica `Tutorials` → otvori tutorijal, telefon položeno.
   Uradi: Otvori tutorijal u studiju na telefonu okrenutom položeno.
   Treba da vidiš: Tabla je levo i zauzima celu visinu ekrana; tabovi
   `Line`/`Task`/`Parts` su desno.
   Potrebno: telefon; telefon položeno.

58. [ ] **Tutorijal sačuvan na telefonu se identično otvara na Windows-u.**
   [179.8]
   O čemu se radi: Studio je od faze 6c isti kontroler na oba uređaja; sadržaj
   (delovi, komentari, pitanje) mora da bude potpuno isti bez obzira gde je
   sačuvan.
   Gde: Teach → kartica `Tutorials`.
   Uradi: Napravi i sačuvaj tutorijal sa nekoliko delova i pitanjem na
   telefonu; otvori ga na Windows-u. Zatim obrnuto.
   Treba da vidiš: Isti delovi, isti komentari i isto pitanje se vide na oba
   uređaja.
   Potrebno: Windows i telefon.

59. [ ] **Meni „More“ u studiju na telefonu sadrži sve radnje editora.**
   [179.6]
   O čemu se radi: Posle faze 6a-6c je meni prelivanja dobio i „Details…“
   (naslov/oznake/jezik) i, kasnije, dve radnje za pomeranje delova između
   tutorijala.
   Gde: Teach → kartica `Tutorials` → otvori tutorijal → ⋮ (`More`).
   Uradi: Otvori tutorijal u studiju na telefonu i pritisni ⋮.
   Treba da vidiš: Meni sadrži `Details…`, `Undo`, `Redo`, `Discard changes`,
   `Preview tutorial`, `Record narration`, `Export video`, `Save as .pgn`,
   `Add parts from a tutorial…`, `Take parts into a new tutorial…` i
   `Position setup`.
   Potrebno: telefon.

60. [ ] **Telefon portret: studio ima red poteza ispod table.** [179.2]
   O čemu se radi: Prijavljeno uživo 18.9.2026 da nema trake poteza na telefonu
   (raspored namerno nema Flow/Tree/PGN table). Isto veče je dodat vodoravan
   red odigranih poteza ispod table, sa istim izvorom koji Windows koristi za
   „Flow“, da se dva pogleda ne raziđu.
   Gde: Teach → kartica `Tutorials` → `New tutorial`.
   Uradi: Odigraj 3–4 poteza, napiši komentar na jedan od njih, pa dodirni prvi
   potez u redu ispod table.
   Treba da vidiš: Tabla i tab `Line` odu na prvi potez; potez sa komentarom
   nosi oblačić; tekući potez je uokviren. Ništa ne prelazi ivicu ekrana.
   Potrebno: telefon.

61. [ ] **Drugi potez u delu pravi nov deo, i film ga pokazuje.** [247.1]
   O čemu se radi: Do 26.9.2026 drugi potez iz iste pozicije ostajao je u istom
   delu kao varijanta — sačuvan, vidljiv u `Tree`, a u filmu ga nije bilo
   (`docs/PLAN-MAPA-DELOVA.md`, faza 1, D1). Sada deo ostaje kakav je, a odmah
   posle njega počinje nov deo sa tim potezom. Zamenjuje poslednju rečenicu
   stavke [246.11] („Svaki potez odigran na tabli ide u liniju dela") za potez
   odigran tamo gde linija već ide dalje.
   Gde: `Teach` → `New tutorial` → `Position setup` → `Paste FEN`.
   Uradi: Postavi `r1b2rk1/p3qppp/2p2n2/2ppP3/2nP1B2/2P3P1/P1Q2PBP/R4RK1 w - - 0 17`,
   odigraj `17. Bg5 Nxe5 18. Rfe1 cxd4`, vrati se na `18. Rfe1` i odigraj
   `18... h6`, pa `19. Rxe5`. Sačuvaj i izvezi video (`Export video`).
   Treba da vidiš: Posle `h6` na dnu piše „18... h6 starts part 2. The film
   shows it after part 1."; prvi deo i dalje ima `cxd4`, drugi počinje posle
   `18. Rfe1` sa `h6 Rxe5`. U videu posle `cxd4` dolazi „Back to the position
   after 18. Rfe1" i zatim `18... h6 19. Rxe5`. Jedan Ctrl+Z vraća jedan deo.
   Potrebno: Windows; backend pokrenut (za video).

62. [ ] **Varijante iz PGN teksta i iz fajla postaju delovi.** [247.2]
   O čemu se radi: Varijanta nalepljena u tab `PGN`, preneta iz Analize ili
   uvezena iz fajla deli se na delove redom: do mesta račvanja, svaka sporedna
   linija, pa stara linija dalje (faza 2, D2) — isti red koji je proveren
   12.9.2026 za `Insert a line here` ([151.7] u arhivi).
   Gde: `Teach` → `New tutorial` → tab `PGN`; i `Teach` → `Tutorials` →
   `Import from a file`.
   Uradi: U deo na poziciji `8/3k4/1n3b2/8/8/8/2PK4/2R5 w - - 0 1` nalepi
   `1. Ra1 Kc6 2. Ra6 (2. Ra8 Bb2) Bb2 3. c3 Kb5 *` i pritisni `Apply`. Zatim
   uvezi jedan tvoj PGN fajl koji ima varijante.
   Treba da vidiš: „Applied as 3 parts: every side line is a part of its own.";
   tri dela: `Ra1 Kc6`, `Ra8 Bb2`, `Ra6 Bb2 c3 Kb5`. Uvezena partija sa
   varijantama ima po deo za svaku; komentari, strelice i oznake `!`/`??`
   su na svojim potezima. Partija bez varijanti je i dalje jedan deo.
   Potrebno: Windows; PGN fajl sa varijantama.

63. [ ] **Mapa delova na tvom prozoru: svoja kolona levo od table.** [247.3]
   O čemu se radi: Spisak delova je mapa (faze 3–4): red po delu redom kako ih
   film pušta, a levo linija — puna gde deo nastavlja, isprekidana gde se
   vraća; nova tabla je kvadrat, ostali krug. Na širokom prozoru mapa ima svoju
   kolonu kad pored table u punoj veličini ima mesta (na visini tvog prozora od
   širine 1504 px).
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → tutorijal sa više delova,
   prozor preko celog ekrana.
   Uradi: Otvori deo koji se vraća na raniju poziciju; zatim neki deo dole u
   dugom spisku; smanji prozor dok mapa ne pređe desno.
   Treba da vidiš: Mapa levo, tabla iste veličine kao pre; otvoreni deo ima
   okvir, prsten oko oznake i reči „you are here" — raspoznaje se bez boje.
   Red kaže „4 · back to after 18. Rfe1" i slično. Otvoreni deo je uvek u
   vidu u spisku. Kad se prozor suzi, mapa ide desno iznad otvorenog dela, a
   tabla se ne menja zbog nje.
   Potrebno: Windows.

64. [ ] **Mapa na telefonu, i akcije za otvoreni deo.** [247.4]
   O čemu se radi: Kartica `Parts` na telefonu crta istu mapu. `Move up`,
   `Move down`, `Clone part`, `Rename` i `Delete part` su sada jedan red iznad
   mape i deluju na otvoreni deo, kao na Windowsu; ranije su bili ispod svakog
   reda (faza 3). Brisanje sada pita i na telefonu (faza 4).
   Gde: telefon, `Teach` → tutorijal sa više delova → kartica `Parts`.
   Uradi: Dodirni treći deo, pomeri ga dole, obriši neki deo.
   Treba da vidiš: Svi redovi se čitaju celi (broj, kako počinje, ime, potezi);
   linije među redovima se ne prekidaju; dodir bira deo i tabla ga prati;
   brisanje pita pre nego što obriše; dugme za okretanje je i dalje u svakom
   redu.
   Potrebno: telefon.

65. [ ] **Naziv tutorijala u traci, oznake i jezik iza „Details…".** [247.5]
   O čemu se radi: Naziv je bio polje od oko 155 px u redu sa oznakama i jezikom
   („Broken Pawns a"); sada je gore u traci prozora, a ispod njega jezik,
   oznake i `Details…` — isti prozor koji telefon ima iza `More` (faza 4).
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → tutorijal sa dugim
   nazivom.
   Uradi: Promeni naziv u traci; otvori `Details…`, promeni oznake i jezik,
   `Done`; sačuvaj, zatvori, otvori ponovo.
   Treba da vidiš: Naziv od 60 znakova se vidi ceo; red ispod naziva kaže nov
   jezik i nove oznake čim se prozor zatvori; posle ponovnog otvaranja sve je
   sačuvano. Na telefonu `More` → `Details…` otvara isti prozor.
   Potrebno: Windows i telefon.

66. [ ] **Neprimenjen tekst u tabu PGN se ne gubi.** [247.6]
   O čemu se radi: Tekst otkucan u tabu `PGN` bez `Apply` nestajao je bez reči
   kad bi se otvorio drugi deo — potezom koji pravi nov deo, klikom na drugi
   red, dodavanjem, brisanjem ili Undo (odluke vlasnika 25.9.2026). Sada se to
   zadrži i kaže, a pored `Apply` je `Discard`.
   Gde: `Teach` → tutorijal sa dva dela → tab `PGN`.
   Uradi: Otkucaj nešto u polju bez `Apply`; odigraj drugi potez tamo gde deo
   već ide dalje; klikni drugi deo; pritisni Ctrl+Z u polju; pa `Discard` i
   ponovo klikni drugi deo.
   Treba da vidiš: Potez i klik se ne izvrše, tabla se vrati, a na dnu piše
   „… Apply or discard the text in the PGN tab first."; Ctrl+Z u polju
   vraća tvoje kucanje, ne potez; posle `Discard` klik otvara drugi deo.
   Potrebno: Windows.

67. [ ] **„Add this line to a tutorial…" sa varijantom dodaje više delova.** [247.7]
   O čemu se radi: Linija iz Analize sa varijantom išla je kao jedan korak, pa
   varijanta nije bila u filmu. Sada ide kao po deo za svaku liniju, u jednom
   zahtevu — sve ili ništa (faza 2; ruta `POST /lessons/:id/steps` prima
   `steps`).
   Gde: `Analyse` → partija ili analiza sa varijantom → `Use in a tutorial` →
   `Add this line to a tutorial…`.
   Uradi: Izaberi tutorijal i `From start of line`; otvori taj tutorijal u
   studiju.
   Treba da vidiš: „Added to the tutorial as N parts: every side line is a part
   of its own."; na kraju tutorijala N novih delova, redom kao u [247.2]; stara
   partija u Analizi je nepromenjena.
   Potrebno: Windows; backend pokrenut sa novim kodom.

68. [ ] **„Part N starts here" u Flow i veza u zaglavlju dela.** [247.8]
   O čemu se radi: Isprekidana linija u mapi ima dva kraja koja se mogu
   kliknuti (faza 3): takt na koji se kasniji deo vraća i zaglavlje tog dela.
   Gde: tutorijal iz [247.1] → prvi deo → tab `Flow`.
   Uradi: Na kartici takta posle `18. Rfe1` klikni „Part 2 starts here ·
   18... h6"; zatim u zaglavlju iznad `Flow` klikni „in part 1".
   Treba da vidiš: Prvi klik otvara drugi deo (zaglavlje: „Part 2 of 2 · back to
   after 18. Rfe1"); drugi vraća na prvi deo. Ispod table piše „Part 2 of 2",
   pa „Part 1 of 2".
   Potrebno: Windows.

69. [ ] **Povratak visi o potezu koji imenuje, a strelica kaže smer.** [247.9]
   O čemu se radi: Na vlasnikovo pitanje od 26.9.2026 („nije mi jasan smer"):
   deo koji se vraća sada visi o potezu koji njegov red imenuje („back to after
   5. c3" izlazi iz 5. c3), a ne o poslednjem delu koji je pokazao tu poziciju;
   svaka linija se završava strelicom na delu u koji vodi
   (`docs/PLAN-REDOSLED-GRANA.md`, faza 0). Menja crtež iz [247.3], ne reči u
   redovima.
   Gde: `Teach` → `Tutorials` → `Saved tutorials` → tutorijal sa više
   odgovora na isti potez (npr. „proba 2").
   Uradi: Pogledaj mapu levo od table; otvori deo koji se vraća.
   Treba da vidiš: Delovi 2, 3 i 4 izlaze iz dela 1, iz 5. c3 — 2 punom
   linijom, 3 i 4 isprekidanom, svaki u svojoj traci; nema lanca 2 → 3 → 4.
   Svaka linija ima vrh strelice tamo gde ulazi u deo; linija koja iz dela
   izlazi nema strelicu. Zaglavlje otvorenog dela kaže „… in part 1".
   Potrebno: Windows.

### Teach — Domaći i napredak učenika

1. [ ] **`Send a video` na stranici učenika.** [246.7]
   O čemu se radi: Nekadašnje „Assign tutorial" šalje video; tutorijal bez
   videa se vidi, ali ne može da se izabere.
   Gde: `Teach` → učenici → učenik → `Send a video`.
   Uradi: Otvori prozor i pogledaj spisak.
   Treba da vidiš: Tutorijal sa videom — „… · video ready"; bez videa — sivo,
   `No video yet — export it first`; pojedinačne pozicije se ne nude.
   `Send` šalje izabrani.
   Potrebno: jedan tutorijal sa videom i jedan bez; prihvaćen učenik.

2. [ ] **Trener vidi kad je video skinut.** [246.8]
   O čemu se radi: Skidanje je jedino što se o videu zna; trener dobija
   obaveštenje, a video sam ne čeka u njegovom redu za pregled (D3, D4).
   Gde: obaveštenja; `Teach` → učenici → učenik → zadatak sa videom → pregled.
   Uradi: Posle [246.1] pogledaj obaveštenja i pregled tog zadatka.
   Treba da vidiš: Obaveštenje „Ana downloaded the video: …" (ime učenika);
   u pregledu „Downloaded on …" (ili `Not downloaded yet.` pre skidanja) i
   nikakvu tablu ni ocenu; broj zadataka koji čekaju pregled se zbog videa ne
   povećava.
   Potrebno: [246.1] urađeno.

3. [ ] **Klik na sredinu reda odigrane partije otvara pregled, ne Analizu.**
   [190.3]
   O čemu se radi: U pregledu domaćeg, red sa odigranom „Play it out“ partijom
   ima svoj pregled (presuda, tabla na kraju); klik na sredinu reda ne sme da
   odvede ni u Analizu ni na tablu za igranje.
   Gde: Teach → `Homework` → red domaćeg → stavka odigrane partije.
   Uradi: Kao trener otvori domaći sa odigranom „Play it out“ stavkom i klikni
   na sredinu tog reda (ne na dugme `Open in Analysis`).
   Treba da vidiš: Otvori se pregled te partije (presuda, potezi, dve table) —
   ne Analiza i ne tabla za igru.
   Potrebno: Windows i telefon; nalog trenera i učenika.

4. [ ] **Pregled odigrane partije pokazuje zadatak, poteze i dve table.**
   [190.4]
   O čemu se radi: Faza 9 je definisala šta trener vidi od odigrane partije:
   zadatak rečima, presudu, odigrane poteze i dve table okrenute na učenikovu
   stranu.
   Gde: Teach → `Homework` → red domaćeg → stavka odigrane partije → pregled.
   Uradi: Otvori pregled odigrane „Play it out“ partije.
   Treba da vidiš: Vidi se zadatak rečima (npr. „Checkmate in N moves as
   White“), presuda, odigrani potezi, table „Start“ i „Position reached“
   okrenute na učenikovu stranu, i redovi „Ended: …“ i „Judged by …“. Nigde ne
   piše „board not available“, „viewed“ ni „correct 0“.
   Potrebno: Windows i telefon; nalog trenera i učenika.

5. [ ] **„Draw or better“ sa punom tablom objašnjava ograničenje ocene.**
   [190.5]
   O čemu se radi: Kad ima više od sedam figura, tablebase se ne pita —
   proverava se samo da učenik nije matiran, a konačnu ocenu daje trener;
   pregled to mora da kaže uz „Goal met“.
   Gde: Teach → `Homework` → red domaćeg → stavka „Draw or better“ partije sa
   preko 7 figura → pregled.
   Uradi: Otvori pregled odigrane „Draw or better, for N moves“ partije koja je
   počela sa više od 7 figura na tabli i završila se sa „Goal met“.
   Treba da vidiš: Uz „Goal met“ piše rečenica da je provereno samo da učenik
   nije matiran i da je na treneru da oceni poziciju.
   Potrebno: Windows i telefon; nalog trenera i učenika.

6. [ ] **Pregled odigrane partije se ne seče na telefonu.** [190.7]
   O čemu se radi: Dve table i tekst pregleda moraju da stanu na ekran telefona
   i uspravno i položeno, bez odsecanja.
   Gde: Teach → `Homework` → red domaćeg → stavka odigrane partije → pregled.
   Uradi: Otvori pregled odigrane partije na telefonu, prvo uspravno pa
   položeno.
   Treba da vidiš: Nijedan deo teksta ili table nije odsečen ivicom ekrana ni u
   jednoj orijentaciji.
   Potrebno: telefon; nalog trenera i učenika; telefon položeno.

7. [ ] **Editor domaćeg nema prekidač „mora rešeno“** [185.9]
   O čemu se radi: Prekidač „Solved“/„mora rešeno“ je izbačen 18.9.2026 (stavka
   184.7) i od tada se nije vratio.
   Gde: Teach → `Homework` → domaći → editor stavke.
   Uradi: Otvori editor bilo koje stavke domaćeg i pogledaj njena podešavanja.
   Treba da vidiš: Nigde ne postoji prekidač „Solved“, a učenik nigde ne vidi
   tekst „must be solved“.
   Potrebno: Windows i telefon.

8. [ ] **Domaći sa pozicijom pod revizijom se ne šalje.** [183.4]
   O čemu se radi: Ako neka stavka domaćeg nosi oznaku „needs review“ (pozicija
   bez potvrđene strane na potezu), celo slanje se odbija — učenik ne dobija
   ništa od tog domaćeg, čak ni stavke koje su bile u redu.
   Gde: Teach → `Homework` → domaći sa stavkom pod revizijom → dugme za slanje.
   Uradi: Dodaj u domaći jednu poziciju obeleženu „needs review“ i još jedan
   tutorijal, pa pokušaj da pošalješ domaći učeniku.
   Treba da vidiš: Slanje se odbija rečenicom o poziciji pod revizijom; učenik
   ne dobija ni tutorijal iz istog domaćeg.
   Potrebno: Windows; nalog trenera i učenika.

9. [ ] **Domaći → Add nudi samo prave zadatke, ne i „Play it out“** [186.6]
   O čemu se radi: Birač za dodavanje stavki u domaći nudi tri vrste
   (tutorijal, zadaci, skup zagonetki); gola pozicija bez rešenja se ne nudi, i
   svaki zadatak postaje svoj red.
   Gde: Teach → `Homework` → domaći → `Add`.
   Uradi: Otvori editor domaćeg i pritisni `Add`. Izaberi `Exercises` i dodaj
   jedan Find zadatak i jedan partija-zadatak („Play N moves“ ili sličan).
   Treba da vidiš: Meni pokazuje `A tutorial`, `Exercises`, `A puzzle set` —
   nema stavke za samu poziciju bez rešenja. Dva izabrana zadatka daju dva
   odvojena reda u domaćem.
   Potrebno: Windows i telefon.

10. [ ] **Domaći → Add više ne nudi gole pozicije kao zadatak.** [185.5]
   O čemu se radi: Vlasnik je 18.9.2026 primetio da se gola pozicija (bez
   rešenja) nudi u istom dijalogu kao pravi zadatak, iako se ne može poslati
   kao zadatak. Faza 10 (stavka 191) je preimenovala i suzila birač na
   `Exercises`, koji nudi samo prave zadatke.
   Gde: Teach → `Homework` → domaći → `Add`.
   Uradi: Otvori `Add` u editoru domaćeg i pogledaj šta nudi izbor `Exercises`.
   Treba da vidiš: Nude se samo pravi zadaci (sa rešenjem); gola pozicija bez
   rešenja se ne pojavljuje u ovom birač.
   Potrebno: Windows i telefon.

11. [ ] **Klizač rejtinga za skup zagonetki ide do 2800, ne do 3400.** [183.6]
   O čemu se radi: Opis je 18.9.2026 ispravljen na vlasnikovu primedbu — klizač
   u dijalogu ide 400–2800; birajući usku temu i rejting 2800–2800, server ne
   vraća nijednu zagonetku (ranije je greškom vraćao 500).
   Gde: Teach → `Homework` → domaći → `Add` → `A puzzle set`.
   Uradi: Otvori dijalog skupa zagonetki, pomeri klizač rejtinga do kraja
   (2800) i izaberi retku temu.
   Treba da vidiš: Klizač se ne može pomeriti iznad 2800; sa retkom temom na
   2800–2800 dijalog javlja da nema zagonetki koje odgovaraju izabranom.
   Potrebno: Windows; server.

12. [ ] **FEN se sam dopunjava i razlog nelegalnosti se ispisuje.** [183.1]
   O čemu se radi: Vlasnik je 18.9.2026 prijavio da je dijalog „Play it out“
   odbijao svaki nepotpun FEN istom rečenicom. Isto veče je popravljeno: tabla
   sama dopuni rokade i upiše dopunjen FEN u polje; prekidač strane odlučuje ko
   je na potezu, a poslednja radnja (paste ili klik) uvek pobeđuje; ako je
   pozicija ipak nelegalna, razlog se ispisuje (nedostaje kralj, pešak na prvom
   redu, strana koja nije na potezu je u šahu). Napomena: prekidač „mora
   rešeno“ pomenut u originalnom opisu je u međuvremenu (185.9) sasvim
   uklonjen, pa ga ovaj korak ne pravi.
   Gde: Teach → `Homework` → `New homework` → `Add` → `Exercises` → dijalog za
   postavljanje pozicije partije.
   Uradi: Nalepi FEN koji ima samo raspored figura (bez ostalih pet polja, npr.
   rezultat dijagram-alata). Zatim napravi domaći sa četiri stavke (tutorijal,
   pozicije, skup zagonetki, „odigraj do kraja“), postavi zaključavanje na
   drugu stavku, sačuvaj i promeni im redosled.
   Treba da vidiš: Polje FEN se samo dopuni i pokaže dopunjenu vrednost; ako je
   pozicija nelegalna, ispod se vidi razlog. Posle promene redosleda stavki,
   sačuvane stavke ostaju iste — bez duplikata i bez izgubljenih izbora.
   Potrebno: Windows.

13. [ ] **Pregled domaćeg i dalje pokazuje rešenje Find zadatka.** [198.6]
   O čemu se radi: Posle učenikovog odgovora na Find stavku, i trener i učenik
   u pregledu domaćeg treba da vide rešenje kao i pre prelaska na jedan-potez
   model.
   Gde: Teach → `Homework` → red domaćeg → stavka → `Review` (učenik: Home →
   `Set for me` → My Assignments → domaći → `Review and comments`).
   Uradi: Pošalji domaći sa Find stavkom, neka učenik odgovori (tačno ili
   netačno), pa otvori pregled te stavke i kao trener i kao učenik.
   Treba da vidiš: Oba naloga vide rešenje ispisano uz stavku (potez i
   prihvaćene alternative), isto kao pre.
   Potrebno: Windows i telefon; nalog trenera i učenika.

14. [ ] **Roditeljski izveštaj je engleski, brojevi nepromenjeni.** [132.5]
   O čemu se radi: Naslov, legenda, imena motiva (npr. „back-rank mate”,
   „hanging piece”) i poruka trenera su engleski; brojevi i procenti ostaju
   kakvi jesu.
   Gde: `Teach` → (red učenika) → `Progress` → ikonica `Parent report` →
   `Create` → `Open`.
   Uradi: Napravi roditeljski izveštaj za učenika koji ima bar nešto rešenih
   zagonetki, pa otvori link.
   Treba da vidiš: Naslov, legenda i imena motiva su na engleskom, sekcija sa
   trenerovom porukom je naslovljena „Coach's message”, a brojevi/procenti su
   nepromenjeni (isti kao u aplikaciji).
   Potrebno: Windows; nalog trenera i učenika.

15. [ ] **Trend u trenerskom pregledu nije "pre i posle"** [58.8]
   O čemu se radi: Trend u trenerskom pregledu učenikove arhive ne sme se
   prikazati kao poređenje pre/posle.
   Gde: `Teach` → `Students and trainers` → red učenika → `Progress` → `Games`.
   Uradi: Otvori tab `Games` učenikovog napretka i pogledaj karticu trenda.
   Treba da vidiš: Prikaz je mesečna aktivnost/broj partija/skor, ne uporedni
   prikaz "pre" i "posle".
   Potrebno: Windows i telefon; nalog trenera i učenika.

### Teach — Preparation

1. [ ] **Provera pri čuvanju ne remeti uključenu analizu motora.** [187.6]
   O čemu se radi: Provera pri čuvanju koristi isti motor kao analiza table; ne
   sme da je pokvari ili prekine.
   Gde: Teach → `Preparation` → `Open` → uključi analizu motora →
   `Make exercise`.
   Uradi: Uključi analizu motora na tabli u Preparation, pa napravi i sačuvaj
   zadatak koji pokreće proveru.
   Treba da vidiš: Posle provere, analiza table nastavlja da radi kao pre — bez
   prekida ili greške.
   Potrebno: Windows; debug build.

### Teach — Učenici, grupe i obaveštenja

1. [ ] **Bedž na Teach imenuje šta čeka pregled, ne samo broj.** [177.6]
   O čemu se radi: Dopunjeno 18.9.2026 pošto je vlasnik pitao šta broj na Teach
   znači — ikona sada nosi rečenicu (npr. „Teach — 1 homework to review“, ili
   dodatak „… · N requests to answer“), a broj je i dalje zbir dve stvari koje
   trener može da skine sa spiska.
   Gde: Teach (bedž na tabu) i zvono u zaglavlju →
   `Notifications and Invitations`.
   Uradi: Napravi stanje sa jednim nepregledanim predatim domaćim i jednim
   nerešenim zahtevom za vezu, pa pogledaj bedž na Teach i otvori zvono.
   Treba da vidiš: Bedž na `Teach` pokazuje broj; dodir na zvono otvara
   `Notifications and Invitations` sa rečenicom koja imenuje šta broj znači
   (predati domaći na pregled i/ili zahtevi za odgovor).
   Potrebno: Windows i telefon; nalog trenera i učenika.

2. [ ] **Trener ne može da zada domaći detetu koje čeka saglasnost.**
   [36.b1154]
   O čemu se radi: Trener ne sme da vidi napredak niti da zada domaći detetu
   čija veza čeka saglasnost roditelja — prava se otvaraju tek kad veza pređe u
   prihvaćeno.
   Gde: `Teach` → (kartica „Students and trainers") → red deteta koje čeka
   saglasnost roditelja.
   Uradi: Pokušati da se otvori napredak (`Progress`) ili zada domaći detetu
   čija veza čeka roditelja.
   Treba da vidiš: Dugme `Progress` je ugašeno, i nema načina da se zada
   domaći.
   Potrebno: Windows i telefon; nalog trenera i učenika.

3. [ ] **Tab „Teach" radi isto — nikad nije zvao ukinutu rutu.** [33.b1058]
   O čemu se radi: Rute /friends/add i brisanje preko /friends/:id su ukinute
   (404); tab za učenike/trenere ih nikad nije koristio, pa se ništa nije
   promenilo.
   Gde: `Teach` → (kartica „Students and trainers").
   Uradi: Poslati zahtev, prihvatiti ga, i raskinuti vezu na uobičajen način.
   Treba da vidiš: Sve radi kao i pre — slanje, prihvatanje i raskidanje veze
   rade preko drugih (novih) ruta.
   Potrebno: Windows i telefon.

4. [ ] **Ni u tabu Teach ni u biračima ne piše tuđi email.** [31.b979]
   O čemu se radi: Ni u tabu `Teach` ni u biračima učenika ne sme da piše tuđi
   email; umesto toga stoji ime i status reda.
   Gde: `Teach` → (kartica „Students and trainers").
   Uradi: Pogledati redove u tabu `Teach` i u biračima učenika (npr.
   `Room access`, poziv u sesiju).
   Treba da vidiš: Svuda stoji ime i status reda (npr. `Awaiting confirmation`,
   `Your student`), nikad tuđi email; polje za pozivanje po email-u i dalje
   postoji i radi.
   Potrebno: Windows i telefon; nalog trenera i učenika.

5. [ ] **Ekran za grupe: napraviti, preimenovati, dodati/izbaciti učenike.**
   [31.b968]
   O čemu se radi: Dugme `Groups` na kartici „Students and trainers" otvara
   ekran sa grupama učenika, korišćen za pozivanje cele grupe u sobu odjednom.
   Gde: `Teach` → (kartica „Students and trainers") → `Groups` → `New group`.
   Uradi: Napraviti grupu, preimenovati je (`Rename`), dodati dva učenika
   (`Add students`), pa izbaciti jednog.
   Treba da vidiš: Grupa se pravi, preimenuje, prima i gubi članove bez greške.
   Potrebno: Windows i telefon; nalog trenera i učenika.

6. [ ] **Greške koje ekran crta doslovno su čitljive engleske rečenice.**
   [132.2]
   O čemu se radi: Server odgovara pravom engleskom rečenicom za greške koje
   aplikacija ispisuje direktno sa servera (ne generiše sopstveni tekst) —
   nikad „Instance of…” ili prazna poruka.
   Gde: `Teach` → (kartica) `Homework` → `New homework` → `send` (bez izabranog
   učenika); ili otvori sobu koja nije tvoja; ili nalepi prazan PGN u tab
   `PGN`.
   Uradi: Izazovi bar jednu od ove tri greške: zadaj domaći bez izabranog
   učenika, otvori tuđu sobu (pogrešan kod), ili pošalji prazan PGN na primenu.
   Treba da vidiš: Poruka je čitljiva engleska rečenica (npr. „studentId and
   title are required.”, „That room is not yours.”, „PGN is missing.”) — nikad
   „Instance of…” i nikad prazan poruka na dnu ekrana.
   Potrebno: Windows i telefon; nalog trenera i učenika.

7. [ ] **Nazivi kartica su isti, ekrani na kojima stoje su se promenili.**
   [175.6]
   O čemu se radi: Ispravljeno u opisu 18.9.2026: faza 5 je razdelila kartice
   po tabovima — imena su ostala ista, samo se traže na drugom mestu.
   Gde: Teach (`Tutorials`, `Homework`, `Preparation`, `New session`,
   `Library`, `Students`), Home (`Recordings`), Analyse (red iznad table:
   `Scan a book`).
   Uradi: Pronađi svaku od navedenih kartica na tabu gde ona danas stoji.
   Treba da vidiš: Svaka kartica postoji sa istim imenom na svom tabu:
   `Tutorials`, `Homework`, `Preparation`, `New session`, `Library` i
   `Students` na Teach; `Recordings` na Home; `Scan a book` u redu iznad table
   na Analyse.
   Potrebno: Windows i telefon.

8. [ ] **Priručnik više ne traži Windows za studio.** [179.10]
   O čemu se radi: Stranice write-a-tutorial, analysis i getting-started u
   priručniku su ažurirane pošto studio radi i na telefonu.
   Gde: Settings → `User manual`.
   Uradi: Otvori priručnik i pročitaj stranice o pisanju tutorijala, analizi i
   početku rada.
   Treba da vidiš: Nijedna od te tri stranice više ne kaže da je Windows uslov
   za rad u studiju.
   Potrebno: Windows i telefon; internet.

## Sesija

### Sesija — Ulazak u sesiju i pozivi

1. [ ] **Dete koje čeka saglasnost ne može u sobu.** [36.b1155]
   O čemu se radi: Soba traži prihvaćenu vezu; dete čija veza čeka saglasnost
   roditelja ne sme da uđe.
   Gde: Nalog deteta → obaveštenje o pozivu u sesiju → `Join`.
   Uradi: Poslati detetu poziv u sobu dok mu veza čeka saglasnost roditelja, pa
   pokušati da uđe.
   Treba da vidiš: Ulazak se odbija — soba traži prihvaćenu vezu.
   Potrebno: Windows i telefon; nalog trenera i učenika.

2. [ ] **Poziv učeniku iz sobe stiže odmah i ostaje u zvonu.** [168.6]
   O čemu se radi: Od uvođenja PLAN-SESIJA.md, poziv se šalje samo prihvaćenim
   učenicima kroz `Invite students to session`; birač u dijalogu ne nudi naloge
   bez prihvaćene veze, pa se scenario „poziv nalogu bez veze“ više ne može ni
   pokrenuti kroz ovaj ekran.
   Gde: Teach → soba → `Session` → `Invite students to session`.
   Uradi: Pozovi učenika koji je trenutno u aplikaciji preko
   `Invite students to session`.
   Treba da vidiš: Učeniku se odmah otvori dijalog poziva, i isti poziv se
   pojavi i u njegovom zvonu (`Notifications and Invitations`).
   Potrebno: Windows i telefon; nalog trenera i učenika; drugi uređaj.

3. [ ] **Ugašen backend: „ne zna se" umesto isključenog prekidača.** [32.b1008]
   O čemu se radi: Kad `Room access` ne uspe da pročita da li soba prima goste
   (npr. backend ugašen), prikazuje se nepoznato stanje umesto lažnog
   „isključeno" — ovo ostaje proverljivo i za novu sobu jer se dešava pre nego
   što se stanje uopšte pročita.
   Gde: `Teach` → soba (kao trener) → `Room access`.
   Uradi: Ugasiti backend i otvoriti `Room access`.
   Treba da vidiš: Umesto isključenog prekidača piše rečenica koja počinje sa
   `Unable to determine if room allows guests` i dugme `Try again`.
   Potrebno: Windows i telefon; nalog trenera i učenika.

4. [ ] **Birač poziva nudi samo prihvaćene učenike.** [31.b969]
   O čemu se radi: Birač u dijalogu `Room access` nudi samo učenike sa
   prihvaćenom vezom.
   Gde: `Teach` → soba (kao trener) → `Room access`.
   Uradi: Otvoriti spisak za pojedinačno pozivanje učenika i uporediti ga sa
   punim spiskom „My students" u tabu `Teach`.
   Treba da vidiš: Nude se samo učenici sa prihvaćenom vezom — onaj koji nije
   potvrdio vezu se ne pojavljuje.
   Potrebno: Windows i telefon; nalog trenera i učenika.

5. [ ] **Nigde u tim spiskovima ne stoji tuđi email.** [31.b970]
   O čemu se radi: Ni u tabu `Teach` ni u dijalogu `Room access` ne sme da piše
   tuđi email — samo ime i status.
   Gde: `Teach` → (kartica „Students and trainers") i soba → `Room access`.
   Uradi: Pogledati redove učenika u tabu `Teach` i u dijalogu `Room access`.
   Treba da vidiš: Svuda stoji samo ime i status (npr. `Your student`, „entire
   group"), nikad email adresa.
   Potrebno: Windows i telefon; nalog trenera i učenika.

6. [ ] **Prazan spisak: soba prima sve učenike trenera.** [31.b971]
   O čemu se radi: Prazan spisak zvanica u `Room access` znači da je soba
   otvorena svim učenicima tog trenera.
   Gde: `Teach` → soba (kao trener) → `Room access`.
   Uradi: Otvoriti `Room access` sa praznim spiskom zvanica.
   Treba da vidiš: Piše da je spisak prazan i da je soba otvorena svim njegovim
   učenicima.
   Potrebno: Windows i telefon; nalog trenera i učenika.

7. [ ] **Učenik iz grupe ulazi, učenik van grupe se odbija.** [31.b973]
   O čemu se radi: Kad je soba ograničena na spisak (grupu), učenik sa spiska
   ulazi normalno, a učenik van spiska se odbija.
   Gde: `Teach` → soba → `Room access` (pozvati grupu), pa učenikov nalog
   otvara sobu preko poziva/obaveštenja.
   Uradi: Pozvati grupu u `Room access`, pa sa naloga učenika iz te grupe ući u
   sobu preko obaveštenja/kartice „In a session now"; zatim probati sa nalogom
   istog trenera koji nije u grupi.
   Treba da vidiš: Učenik iz grupe ulazi normalno; učenik van spiska dobija
   poruku da nije na spisku za tu sobu.
   Potrebno: Windows i telefon; nalog trenera i učenika.

8. [ ] **Skidanje grupe sa spiska ponovo otvara sobu svima.** [31.b975]
   O čemu se radi: Kad se poslednja stavka skine sa spiska, soba se ponovo
   otvara svim učenicima tog trenera.
   Gde: `Teach` → soba (kao trener) → `Room access`.
   Uradi: Ukloniti sve stavke sa spiska u `Room access` dok ne ostane prazan.
   Treba da vidiš: Poruka se vrati na to da je spisak prazan i da je soba opet
   otvorena svim učenicima tog trenera.
   Potrebno: Windows i telefon; nalog trenera i učenika.

9. [ ] **Pozivanje cele grupe menja poruku o spisku.** [31.b972]
   O čemu se radi: Čim se pozove prva grupa ili osoba, poruka o tome ko sme u
   sobu se menja.
   Gde: `Teach` → soba (kao trener) → `Room access` → odeljak `Invite group`.
   Uradi: Pozvati celu grupu jednim klikom (čip u odeljku `Invite group`).
   Treba da vidiš: Poruka se promeni u tekst koji kaže da ulaze samo oni sa tog
   spiska.
   Potrebno: Windows i telefon; nalog trenera i učenika.

10. [ ] **Pozivanje jednog učenika poimence.** [31.b974]
   O čemu se radi: Pored grupa, pojedinačni učenik se može pozvati poimence.
   Gde: `Teach` → soba (kao trener) → `Room access` → odeljak
   `Invite individually`.
   Uradi: Pozvati jednog učenika poimence (čip u odeljku
   `Invite individually`), pa proveriti da ulazi.
   Treba da vidiš: Taj učenik ulazi u sobu.
   Potrebno: Windows i telefon; nalog trenera i učenika.

### Sesija — Preparation

1. [ ] **Sačuvana analiza i izvoz PGN nose postavljenu poziciju, ne početnu.**
   [201.9]
   O čemu se radi: Kad je pozicija postavljena preko `Set up position` (ili
   nalepljenog FEN-a) pa odigrano nekoliko poteza, `Save analysis` i njeno
   kasnije otvaranje moraju da vrate baš tu postavljenu poziciju sa odigranim
   potezima na njoj; isto važi i za izvezeni PGN (`[SetUp "1"]` i `[FEN …]`).
   Gde: `Teach` → `New session` (Preparation) → `Set up position` (ili nalepi
   FEN) → odigraj nekoliko poteza → `Save analysis` / `Export PGN`.
   Uradi: U Preparation, postavi poziciju (ili nalepi FEN) različitu od
   početne, odigraj nekoliko poteza, pa sačuvaj preko `Save analysis` i ponovo
   je otvori. Odvojeno, izvezi istu liniju preko `Export PGN`.
   Treba da vidiš: Otvorena sačuvana analiza pokazuje tablu na postavljenoj
   poziciji sa odigranim potezima na njoj (ne od početne pozicije šaha).
   Izvezeni PGN tekst sadrži `[SetUp "1"]` i `[FEN …]` red sa tom pozicijom.
   Potrebno: Windows.

2. [ ] **Izabrana boja strelice ima svetlu ivicu i kvačicu.** [45.b1716]
   O čemu se radi: Birač boje strelice mora jasno pokazati koja je boja
   trenutno izabrana.
   Gde: `Teach` → `Preparation` → `Open` → `Draw arrow` → birač boje.
   Uradi: Uključi crtanje strelica i dodirni jednu od ponuđenih boja.
   Treba da vidiš: Izabrani krug boje dobija svetliju ivicu i kvačicu; ostali
   je nemaju.
   Potrebno: Windows i telefon.

3. [ ] **Natpis koje boje igraš u sobi je i dalje odsutan.** [43.b1611]
   O čemu se radi: Natpis "Igrate kao Beli (Host)"/"Igrate kao Crni" je
   uklonjen 28.8.2026 uz popravku vidljivosti stabla poteza i otad nije vraćen
   niti zamenjen ekvivalentnim tekstom — danas se boja vidi samo iz okrenutosti
   table.
   Gde: `Teach` → `Preparation` → `Open`.
   Uradi: Otvori Preparation i pogledaj oko table i u desnoj koloni.
   Treba da vidiš: Trenutno nema nikakvog natpisa koje boje igraš — samo
   okrenutost table to pokazuje. Ovo je i dalje otvoreno pitanje, ne potvrđen
   kvar — zabeleži da li ti to smeta.
   Potrebno: telefon.

4. [ ] **"To main line" okreće sve račve do korena.** [43.b1618]
   O čemu se radi: Dugme za povratak glavne linije treba da promoviše svaku
   račvu na putu do korena stabla, ne samo najbližu.
   Gde: `Teach` → `Preparation` → `Open` → (desna kolona) → `To main line`.
   Uradi: U stablu napravi dve uzastopne račve (odigraj potez, vrati se dva
   poteza, odigraj drugi; ponovi dalje niz liniju), stani na sporednu granu
   drugog nivoa i pritisni `To main line`.
   Treba da vidiš: Obe račve postaju glavna linija u jednom koraku, ne samo
   najbliža.
   Potrebno: Windows i telefon.

5. [ ] **"Delete variation" seče i vraća na roditelja.** [43.b1619]
   O čemu se radi: Brisanje varijante treba da ukloni tu granu i vrati kursor
   na roditelja.
   Gde: `Teach` → `Preparation` → `Open` → (desna kolona) → `Delete variation`.
   Uradi: Napravi sporednu varijantu, stani na nju i pritisni
   `Delete variation`.
   Treba da vidiš: Grana nestaje iz stabla, a tabla se vraća na
   potez-roditelja.
   Potrebno: Windows i telefon.

6. [ ] **Komentar poteza ostaje posle odlaska i povratka.** [43.b1620]
   O čemu se radi: Polje za komentar pokazuje u zaglavlju koji potez
   komentarišeš (Comment for move) i treba da sačuva tekst kad se pređe na
   drugi potez i vrati.
   Gde: `Teach` → `Preparation` → `Open` → (desna kolona, polje
   `Comment for move …`).
   Uradi: Odigraj potez, upiši nešto u polje komentara, pređi na drugi potez pa
   se vrati.
   Treba da vidiš: Zaglavlje polja imenuje potez na kom stojiš, a otkucani
   tekst je i dalje tu.
   Potrebno: Windows i telefon.

7. [ ] **Linija iz sobe stiže učeniku kao lekcija, kao glavna linija.**
   [43.b1624]
   O čemu se radi: Direktno dugme "Sačuvaj kao lekciju" iz sobe je ukinuto; put
   je sada preko Analysis Studio-a: Export to Analysis → Use in a tutorial →
   New tutorial from this line, pa dodela preko napretka učenika.
   Gde: `Teach` → `Preparation` → `Open` → `More` → `Export to Analysis` →
   `Use in a tutorial` → `New tutorial from this line` → `Start new tutorial` →
   `Save tutorial`; zatim `Teach` → `Students and trainers` → red učenika →
   `Progress` → `Assign tutorial`.
   Uradi: Napravi liniju sa varijantom i komentarom na potezu, sačuvaj je kao
   novi tutorijal gornjim putem, pa je dodeli učeniku. Otvori je učenikovim
   nalogom iz `My Assignments`.
   Treba da vidiš: Učenik vidi trenerov komentar ispod table za tačno taj
   potez, i linija koju vidi je glavna linija, ne sporedna grana.
   Potrebno: Windows i telefon; nalog trenera i učenika.

8. [ ] **Motorova linija ulazi kao varijanta bez pomeranja kursora.**
   [43.b1631]
   O čemu se radi: U sobi/Preparation (za razliku od Analysis Studio-a, koji
   ovo dugme uopšte ne nudi) motorov red ima "Insert as variation", koji
   upisuje evaluaciju na prvi potez linije i ne pomera kursor sa trenutne
   pozicije.
   Gde: `Teach` → `Preparation` → `Open` → (panel `Engine`) → red linije →
   `Insert as variation`.
   Uradi: Uključi motor, klikni na neku njegovu liniju i izaberi
   `Insert as variation`.
   Treba da vidiš: Linija ulazi kao nova varijanta, njen prvi potez nosi
   upisanu evaluaciju, a kursor ostaje tačno tamo gde je bio.
   Potrebno: Windows i telefon.

9. [ ] **Ista motorova linija se ne dupira u stablu.** [43.b1634]
   O čemu se radi: Isto polje kao za umetanje motorove linije (Insert as
   variation); ponovljeni unos ne sme da napravi drugu istovetnu granu.
   Gde: `Teach` → `Preparation` → `Open` → (panel `Engine`) →
   `Insert as variation` (dvaput ista linija).
   Uradi: Ubaci istu motorovu liniju kao varijantu dva puta zaredom.
   Treba da vidiš: Drugi put se ne pojavljuje nova grana — javlja se poruka
   "Line was already in the tree."
   Potrebno: Windows i telefon.

10. [ ] **"Insert evaluation into comment" dopisuje ocenu i dubinu.**
   [43.b1635]
   O čemu se radi: Dugme koje evaluaciju i dubinu trenutne pozicije dopisuje u
   tekst komentara.
   Gde: `Teach` → `Preparation` → `Open` → (desna kolona) →
   `Insert evaluation into comment`.
   Uradi: Uključi motor, stani na neki potez i pritisni
   `Insert evaluation into comment`.
   Treba da vidiš: U polje komentara se dopisuje tekst oblika [+eval / depth
   N], npr. [+2.22 / depth 24].
   Potrebno: Windows i telefon.

11. [ ] **Strelice: ponovljena se briše, Undo/Clear rade svuda.** [43.b1639]
   O čemu se radi: Iste strelice kao svuda u aplikaciji — crtanje, poništavanje
   i brisanje moraju raditi isto u sobi i u Preparation.
   Gde: `Teach` → `Preparation` → `Open` → `Draw arrow`, i `Teach` →
   `New session` → `Start` → `Draw arrows`.
   Uradi: U oba mesta nacrtaj strelicu, pa istu ponovo preko nje; zatim nacrtaj
   dve i pritisni `Undo arrow`; zatim `Clear all arrows`. U sobi posmatraj i
   drugi uređaj.
   Treba da vidiš: Ponovo povučena ista strelica nestaje; `Undo arrow` vraća
   samo poslednju; `Clear all arrows` briše sve. U sobi se promena vidi i na
   drugom uređaju; u Preparation ne, jer tamo nema kome.
   Potrebno: Windows i telefon; drugi uređaj.

12. [ ] **"Import PGN" učita partiju ili ponudi izbor za više njih.**
   [43.b1645]
   O čemu se radi: Dijalog za uvoz PGN-a mora da razlikuje nalepljen tekst
   jedne partije od izvoza sa više partija.
   Gde: `Teach` → `Preparation` → `Open` → (leva kolona) → `Import PGN`.
   Uradi: Otvori `Import PGN`, nalepi tekst jedne partije i pritisni `Load`;
   ponovi sa izvozom koji sadrži više partija.
   Treba da vidiš: Jedna partija se učita pravo na tablu; više partija otvara
   dijalog za izbor koje partije da učita.
   Potrebno: Windows i telefon; PGN fajl.

### Sesija — Soba

1. [ ] **Soba za lekciju ima prekidače za strelice motora.** [93.12]
   O čemu se radi: Vlasnik je 3.9.2026 prijavio da u sobi nema načina da se
   sklone strelice motora kad ih trener pusti. Meni na tabli u sobi od tada
   nudi sva tri prekidača za strelice i veličinu table.
   Gde: `Home` → `In a session now` → (soba, trener pušta motor) →
   `Board view`.
   Uradi: U sobi, kao trener, pusti motor da crta strelice na tabli. Otvori
   meni `Board view`.
   Treba da vidiš: Meni nudi sva tri prekidača; isključivanje `Engine arrows`
   ukloni motorske strelice sa table u sobi.
   Potrebno: Windows i telefon; server; nalog trenera i učenika.

2. [ ] **Učenik vidi strelicu koju trener nacrta.** [118.1]
   O čemu se radi: Crtanje u sobi deli isti kontroler kao studio; strelica koju
   trener nacrta se preko soketa prenosi svim učesnicima.
   Gde: `Home` → `In a session now` → `Join` (učenik) / `Teach` → `New session`
   (trener).
   Uradi: Uđi u istu sobu sa dva uređaja/naloga — trener i učenik. Trener
   uključi crtanje strelica i nacrta jednu.
   Treba da vidiš: Strelica se pojavi i kod učenika, iste boje kao kod trenera.
   Potrebno: Windows i telefon; nalog trenera i učenika; drugi uređaj.

3. [ ] **Brisanje strelica stiže do učenika.** [118.2]
   O čemu se radi: `Undo arrow` (poslednja strelica) i `Clear all arrows` (sve)
   se šalju istim putem kao crtanje.
   Gde: `Home` → `In a session now` → `Join` (učenik) / `Teach` → `New session`
   (trener).
   Uradi: Trener nacrta dve-tri strelice, pa pritisne `Undo arrow`, pa
   `Clear all arrows`.
   Treba da vidiš: Kod učenika strelice nestaju u istom redosledu — jedna pri
   `Undo arrow`, ostatak pri `Clear all arrows`.
   Potrebno: Windows i telefon; nalog trenera i učenika; drugi uređaj.

4. [ ] **Spisak prisutnih se osvežava obema stranama posle prihvatanja
   poziva.** [219.2]
   O čemu se radi: Kad učenik prihvati poziv u sesiju, oba uređaja treba da
   vide oba imena u spisku „Present in classroom“, sa istim kodom sobe u
   naslovu.
   Gde: `Home` → poziv u sesiju (zvonce) → `Join`; ili `Teach` → `New session`
   → `Invite students to session`.
   Uradi: Sa naloga trenera pozovi učenika u sesiju; sa naloga učenika prihvati
   poziv (`Join`). Pogledaj spisak prisutnih na oba uređaja.
   Treba da vidiš: Na oba uređaja spisak prisutnih pokazuje oba imena, a kôd
   sobe u naslovu (Room: …) je isti na oba ekrana.
   Potrebno: Windows i telefon; nalog trenera i učenika; drugi uređaj; server.

5. [ ] **Učitana pozicija/tutorijal se sinhronizuje kod učenika.** [168.3]
   O čemu se radi: Kad trener učita sačuvanu poziciju ili tutorijal na deljenu
   tablu, učenikovo stablo i tabla moraju da prate.
   Gde: Teach → soba → leva kolona `Library` → red pozicije ili tutorijala.
   Uradi: Kao trener učitaj sačuvanu poziciju (ili tutorijal) na tablu i
   odigraj jedan potez.
   Treba da vidiš: Učenikovo stablo nije prazno i njegova tabla je na istoj
   poziciji kao trenerova.
   Potrebno: Windows i telefon; nalog trenera i učenika; drugi uređaj.

6. [ ] **Isti klizač veličine table u sobi i na ekranu vežbi, pamti se.**
   [180.3]
   O čemu se radi: Vrednost `Board size` je zajednička za sobu, ekran vežbi i
   Analizu i preživljava ponovno pokretanje. Prijavljeno uživo 18.9.2026 da
   navigaciona paleta lomi red na 360 dp zbog reči „Navigation“ — popravljeno
   isto veče: natpis je sad prazan po difoltu, dugmad su gušća.
   Gde: Teach → `New session` → `Start` (soba) — meni u zaglavlju.
   Uradi: Promeni `Board size` u sobi, izađi i ponovo uđi (i u sobu i u ekran
   vežbi), pa restartuj aplikaciju.
   Treba da vidiš: Tabla prati klizač na sva tri ekrana; vrednost ostaje ista
   posle ponovnog pokretanja. Navigaciona paleta na 360 dp portretu stane u
   jedan red.
   Potrebno: telefon; telefon položeno.

7. [ ] **Kasni ulazak učenika vidi tekuću poziciju, ne početnu.** [168.2]
   O čemu se radi: Ko god uđe u već započetu sobu treba da vidi trenutnu
   poziciju sobe, ne praznu tablu.
   Gde: Teach → `New session` → `Start` (trener odigra nekoliko poteza pre nego
   što učenik uđe).
   Uradi: Kao trener odigraj nekoliko poteza, pa tek onda pusti učenika da uđe.
   Treba da vidiš: Učenik vidi tekuću poziciju sobe, ne početnu tablu.
   Potrebno: Windows i telefon; nalog trenera i učenika; drugi uređaj.

8. [ ] **Učenikova tabla prati svaki trenerov potez i klik u stablu.** [168.1]
   O čemu se radi: Osnovna sinhronizacija sobe — tabla, ne samo stablo, mora da
   prati trenera na oba uređaja.
   Gde: Teach → `New session` → `Start` (trener) / (učenik, drugi uređaj, preko
   poziva ili `In a session now` → `Join`).
   Uradi: Kao trener odigraj e4; proveri učenikovu tablu. Zatim klikni na
   raniji potez u stablu; proveri opet.
   Treba da vidiš: Učenikova tabla (ne samo stablo) pokazuje e4; posle klika na
   raniji potez u stablu, učenikova tabla ide za njim.
   Potrebno: Windows i telefon; nalog trenera i učenika; drugi uređaj.

9. [ ] **U sobi, čip Exercises u koloni biblioteke učitava zadatak na tablu.**
   [186.9]
   O čemu se radi: Deljena Library kolona u sobi ima isti čip `Exercises`; tap
   na zadatak ga stavlja na tablu kao ranije skeniranu poziciju.
   Gde: Teach → `New session` → `Start` (ili `Preparation`) → leva kolona → čip
   `Exercises`.
   Uradi: U sobi otvori levu kolonu, izaberi čip `Exercises` i dodirni jedan
   zadatak.
   Treba da vidiš: Pozicija tog zadatka se učita na deljenu tablu, isto kao kad
   bi se učitala ranije skenirana pozicija.
   Potrebno: Windows i telefon; nalog trenera i učenika.

10. [ ] **Potezi u sobi i u Preparation ne pokazuju crvenu traku „no
   permission“** [167.4]
   O čemu se radi: Osnovna provera prava — trenerovi (i u Preparation,
   sopstveni) potezi ne smeju da izazovu grešku o dozvoli.
   Gde: Teach → soba (trener) / `Preparation`.
   Uradi: Kao trener odigraj potez u realnoj sobi. Zatim odigraj nekoliko
   poteza u `Preparation`.
   Treba da vidiš: Nijednom se ne pojavljuje crvena traka o nedostatku dozvole,
   ni u sobi ni u Preparation.
   Potrebno: Windows i telefon; nalog trenera i učenika.

11. [ ] **„Edit tutorial“ u sobi na telefonu otvara studio, ne stari panel.**
   [179.9]
   O čemu se radi: Stari poseban panel za izmenu tutorijala u sobi na telefonu
   je zamenjen istim studiom koji koristi Windows.
   Gde: Teach → `Preparation` (ili soba) → leva kolona → red tutorijala → ⋮ →
   `Edit tutorial`.
   Uradi: U sobi na telefonu izaberi `Edit tutorial` na redu tutorijala. Zatim
   iz Analyse probaj `Use in a tutorial` → `Open a tutorial to edit…`.
   Treba da vidiš: Oba puta se otvara isti studio (isti kao na Windows-u), a
   birač za „koji tutorijal“ nudi i redove napravljene u studiju.
   Potrebno: telefon; nalog trenera i učenika.

12. [ ] **Ocene poteza iz PGN-a (??, !) ostaju posle čuvanja pozicije u sobi.**
   [169.4]
   O čemu se radi: Kad se partija sa NAG oznakama učita u sobu i pozicija se
   sačuva, oznake ne smeju da nestanu iz sačuvane linije.
   Gde: Teach → `Preparation` (ili soba) → `Import PGN` → `Save position`.
   Uradi: Učitaj u sobu PGN fajl koji ima poteze sa „??“ i „!“, pa sačuvaj
   poziciju preko `Save position`.
   Treba da vidiš: Otvorena sačuvana pozicija i dalje pokazuje te iste oznake
   uz svoje poteze.
   Potrebno: Windows; nalog trenera i učenika; PGN fajl.

13. [ ] **Save position u sobi čuva sve odigrane poteze.** [168.10]
   O čemu se radi: Osnovna funkcija čuvanja pozicije iz sobe — mora da ponese
   celu odigranu liniju, ne samo poslednji potez.
   Gde: Teach → soba → leva kolona → `Save position`.
   Uradi: Odigraj nekoliko poteza u sobi, pa pritisni `Save position` i posle
   toga otvori sačuvanu poziciju.
   Treba da vidiš: Otvorena sačuvana pozicija sadrži sve odigrane poteze, ne
   samo tablu na kojoj je stala.
   Potrebno: Windows i telefon; nalog trenera i učenika.

14. [ ] **„Force student board to: Black“ okreće učenikovu tablu.** [168.4]
   O čemu se radi: Trener može da nametne orijentaciju table učeniku iz Session
   panela.
   Gde: Teach → soba → `Session` → `Force student board to:` `Black`.
   Uradi: Kao trener pritisni `Force student board to:` pa `Black`.
   Treba da vidiš: Učenikova tabla se odmah okrene na crnu stranu.
   Potrebno: Windows i telefon; nalog trenera i učenika; drugi uređaj.

15. [ ] **Učenikovo deljenje pozicije otvara treneru Load onto board.** [168.5]
   O čemu se radi: Student answer strip dozvoljava učeniku da pošalje svoju
   poziciju treneru na uvid, koji je onda može učitati.
   Gde: Sesija (učenik) → `Show my position to trainer` / (trener) → dijalog
   `Suggested position` → `Load onto board`.
   Uradi: Kao učenik podeli svoju poziciju treneru preko
   `Show my position to trainer`.
   Treba da vidiš: Kod trenera se otvori dijalog `Suggested position`;
   `Load onto board` je učita na deljenu tablu.
   Potrebno: Windows i telefon; nalog trenera i učenika; drugi uređaj.

16. [ ] **Poziv u sesiju stiže treneru, ili se učeniku kaže zašto ne.**
   [219.14]
   O čemu se radi: Kad učenik pravi sesiju i zove trenera, poziv treba da
   iskoči kod trenera; ako server odbije poziv, učenik treba da vidi razlog, ne
   generičku poruku da je poziv uspešno poslat.
   Gde: `Teach` → `New session` (kao učenik, ako je dostupno) → pozovi trenera;
   ili prihvatanje poziva preko Home zvonca.
   Uradi: Sa naloga učenika pokušaj da pozoveš svog trenera u sesiju. Posmatraj
   šta se dešava na oba naloga, i probaj i slučaj gde bi poziv trebalo da bude
   odbijen (npr. trener koji nije u vezi „prihvaćeno“).
   Treba da vidiš: Kod uspešnog poziva, kod trenera iskače dijalog
   `Session Invitation` sa `Join`/`Decline`. Kod odbijenog poziva, učenik
   dobija poruku sa razlogom odbijanja, ne poruku da je poziv uspešno poslat.
   Potrebno: Windows i telefon; nalog trenera i učenika; drugi uređaj; server.

17. [ ] **Bočni panel „Library“ u sobi (STUDIO): jedna kartica u redu, ☰
   radi.** [205.8]
   O čemu se radi: U sobi STUDIO (Preparation), leva kolona „Library“ prikazuje
   jednu karticu po redu, kolona se skroluje zajedno sa ostatkom bočnog panela,
   a klik na tutorijal ga stavlja na tablu. Dugme ☰ u traci otvara taj panel na
   uskom prozoru.
   Gde: `Teach` → `New session` (Preparation) → ☰ (na uskom prozoru) → deo
   „Library“
   Uradi: Otvori Preparation na uskom prozoru (ili suzi Windows prozor) i
   pritisni ☰ gore levo. Proveri raspored kartica u delu „Library“ i klikni na
   jedan tutorijal.
   Treba da vidiš: Pritisak na ☰ otvara bočni panel (nema više „nema
   reakcije“). U delu „Library“, kartice stoje jedna ispod druge (jedna po
   redu), kolona se skroluje sa ostatkom panela, a klik na tutorijal ga
   postavlja na tablu.
   Potrebno: Windows.

18. [ ] **Levi panel (Save analysis/Export PGN) je samo kod onoga ko vodi
   sobu.** [201.10]
   O čemu se radi: Vlasnik je 20.9.2026 prijavio da oba vide panel kad učenik
   napravi sesiju i pozove trenera. Od 21.9.2026 taj slučaj ne može da nastane:
   ko pokrene sesiju poziva samo svoje prihvaćene učenike, a u sobu ulazi samo
   pozvani. Proverava se da panel sa `Save analysis` i `Export PGN` ima samo
   onaj ko vodi sobu.
   Gde: `Teach` → `New session` → (leva kolona, kod trenera koji je napravio
   sobu).
   Uradi: Otvori živu sobu koju je napravio trener i proveri da levi panel (sa
   `Save analysis`/`Export PGN`) postoji kod trenera. Zatim, ako je moguće,
   napravi sobu sa naloga učenika i pozovi trenera — proveri ko od njih dvoje
   ima panel.
   Treba da vidiš: Kad sobu vodi trener (napravio ju je), panel je kod njega, a
   učenik ga nema. Ako sobu napravi učenik i pozove trenera, proveri da panel
   ima samo jedna strana — onaj ko je sobu napravio — a ne obe.
   Potrebno: Windows; nalog trenera i učenika; drugi uređaj.

19. [ ] **Komentar u sobi stiže tek posle pauze u kucanju.** [43.b1622]
   O čemu se radi: U živoj sobi (ne u Preparation) se promena komentara emituje
   drugom učesniku tek 600ms posle poslednjeg slova, ne po svakom pritisku
   tastera.
   Gde: `Teach` → `New session` → `Start`; drugi nalog se pridružuje kao
   učenik.
   Uradi: Na trenerovoj strani upiši komentar u polje `Comment for move …`
   polako, slovo po slovo, i posmatraj drugi uređaj.
   Treba da vidiš: Tekst se kod drugog učesnika ne menja po slovu — skoči na
   pun tekst tek oko 600ms posle poslednjeg pritiska tastera.
   Potrebno: Windows i telefon; drugi uređaj; nalog trenera i učenika.

20. [ ] **Naslov, desni panel i statični natpis „Solo practice” u
   Preparation.** [131.3]
   O čemu se radi: Kad sobu niko drugi ne deli, naslov je „Preparation”, desni
   panel se zove „Preparation controls”, a ispod se vidi natpis „Solo practice
   — classroom is off”. Ovo poslednje je obična (nepritisljiva) traka, ne
   prekidač — stara stavka je to pogrešno opisivala kao prekidač.
   Gde: `Teach` → `Preparation`.
   Uradi: Otvori Preparation (soba bez ijednog učenika) i pogledaj naslov,
   desni panel i traku ispod dugmadi za crtanje.
   Treba da vidiš: Naslov kaže „Preparation”, desni panel „Preparation
   controls”, a statična traka „Solo practice — classroom is off” (nije
   prekidač, ne reaguje na dodir).
   Potrebno: Windows.

21. [ ] **Polunacrtana strelica se zaboravlja kad se pređe na drugi potez.**
   [118.6]
   O čemu se radi: Za razliku od studija (gde promena takta sad gasi crtanje —
   stavka 117.7), u sobi promena poteza samo zaboravlja polunacrtanu strelicu,
   a crtanje ostaje uključeno. Pošto je tabla za igranje poteza zaključana dok
   je crtanje uključeno, potez se ne igra povlačenjem figure nego biranjem
   druge pozicije u spisku poteza/strelicama tastature.
   Gde: `Teach` → `Preparation` (ili soba sa učenikom).
   Uradi: Uključi `Arrow`, klikni jedno polje (počni strelicu), pa pređi na
   drugi potez preko spiska odigranih poteza ili strelica na tastaturi (ne
   povlačenjem figure — tabla je zaključana dok je crtanje uključeno).
   Treba da vidiš: Nijedna strelica se ne nacrta na novoj poziciji
   (polunacrtana je zaboravljena), a dugme `Arrow` ostaje uključeno.
   Potrebno: Windows.

22. [ ] **„Board Setup” u sobi otvara isti dijalog.** [130.1]
   O čemu se radi: Soba (i Preparation) koriste isti dijalog za postavljanje
   pozicije kao Analysis Studio, otvoren unapred popunjen tekućom pozicijom sa
   table, ne iz početne.
   Gde: `Teach` → `Preparation` → (levi panel) → `Set up position`.
   Uradi: Odigraj par poteza u Preparation da tabla nije na početnoj poziciji,
   pa otvori `Set up position`.
   Treba da vidiš: Otvara se isti dijalog za postavljanje pozicije kao u
   Analizi, već popunjen tekućom pozicijom sa table (ne početnom).
   Potrebno: Windows.

23. [ ] **Snimljen čas prikazuje strelicu u trenutku kad je nacrtana.** [118.3]
   O čemu se radi: Reprodukcija snimka pamti strelice koje su nacrtane tokom
   časa i prikazuje ih na poziciji na kojoj su nacrtane.
   Gde: `Teach` → `Preparation` → `Start recording`.
   Uradi: Snimi kratak čas u Preparation u kom u jednom trenutku nacrtaš
   strelicu, sačuvaj snimak, pa ga pusti iz `Home` → (kartica) `Recordings` →
   `Play`.
   Treba da vidiš: Strelica se u reprodukciji pojavljuje tačno u trenutku kad
   je nacrtana, na odgovarajućoj poziciji.
   Potrebno: Windows; nalog trenera i učenika.

24. [ ] **Prazno „Clear all arrows” ne pravi prazan takt u snimku.** [118.4]
   O čemu se radi: Pritisak na `Clear all arrows` kad nema nijedne strelice
   sada ne upisuje ništa u istoriju/snimak — namerna izmena iz P7b, jedina te
   vrste.
   Gde: `Teach` → `Preparation` → `Start recording`.
   Uradi: Tokom snimanja pritisni `Clear all arrows` na potezu koji nema
   nijednu strelicu. Pusti reprodukciju posle.
   Treba da vidiš: U reprodukciji ne postoji prazan/suvišan trenutak na tom
   mestu — pritisak koji ništa nije promenio se ne vidi u snimku.
   Potrebno: Windows; nalog trenera i učenika.

25. [ ] **Traka za poteze u sobi radi, siva kad učenik ne vodi tablu.**
   [20.b654]
   O čemu se radi: U sobi trener uvek vodi tablu; kad prekidač
   `Students may move` isključi pravo učeniku (poruka „Only you move on the
   board."), traka za kretanje mora da ostane siva njemu, ali da i dalje radi
   treneru.
   Gde: `Teach` → soba (kao trener) → prekidač `Students may move`, pa isto na
   strani učenika.
   Uradi: U živoj sobi, kao trener, koristiti traku za kretanje kroz poteze;
   zatim isključiti `Students may move` i na strani učenika pogledati traku.
   Treba da vidiš: Traka radi treneru kao i pre; učeniku, dok mu piše
   `Only you move on the board.`, je dugmad trake sivo i ne rade.
   Potrebno: Windows i telefon; nalog trenera i učenika.

26. [ ] **Mute/Unmute i podignuta ruka rade između dva uređaja.** [168.7]
   O čemu se radi: Osnovna glasovna kontrola — trener može da utiša i vrati
   glas pojedinačnom učeniku ili svima, a učenik može da zatraži reč.
   Gde: Sesija → traka → ikonica glasa → `Voice`.
   Uradi: Oba naloga uključe glas. Kao trener utišaj učenika preko ikone jačine
   zvuka na njegovom redu (tooltip `Mute student`), pa ga vrati preko `Unmute`.
   Kao učenik podigni ruku preko `Raise hand to speak`.
   Treba da vidiš: Utišan učenik se zaista ne čuje; `Unmute` ga odmah vrati.
   Treneru stiže obaveštenje da učenik „wants to speak“.
   Potrebno: Windows i telefon; nalog trenera i učenika; drugi uređaj.

## Podešavanja i izgled

### Podešavanja i izgled — Settings

1. [ ] **Poruka kad nema instaliranog glasa za govor.** [0k.b136]
   O čemu se radi: Sekcija „SPEECH (READING MESSAGES)" u Podešavanjima javlja
   kad nema instaliranog glasa za jezik čitanja, umesto da ćuti ili čita drugim
   glasom. Od pivota na engleski (8-9.9.2026) traži se glas za engleski, ne za
   srpski/hrvatski.
   Gde: `Settings` (zupčanik) → sekcija „SPEECH (READING MESSAGES)"
   Uradi: Na mašini bez instaliranog engleskog glasa za sintezu govora otvoriti
   `Settings` i pogledati govorni panel.
   Treba da vidiš: Panel ispisuje `No installed voice found for this language.`
   i uputstvo kako da se doda glas (Windows: Time & Language → Speech → Add
   voices; Android: Accessibility → Text-to-speech) — umesto da ćuti ili čita
   nekim drugim glasom.
   Potrebno: Windows i telefon.

2. [ ] **Izbor neinstaliranog glasa ne ruši aplikaciju.** [0k.b162]
   O čemu se radi: Ako se u spisku izabere glas koji nije stvarno instaliran,
   greška se hvata i panel javlja da glasa nema — ni pri biranju ni pri
   sledećem ulasku u Podešavanja.
   Gde: `Settings` (zupčanik) → sekcija „SPEECH (READING MESSAGES)" → padajući
   spisak jezika.
   Uradi: Izabrati u spisku jezik/glas koji nije stvarno instaliran u
   operativnom sistemu, pa zatvoriti i ponovo otvoriti `Settings`.
   Treba da vidiš: Aplikacija se ne ruši ni pri izboru ni pri sledećem ulasku;
   panel ispisuje `No installed voice found for this language.`.
   Potrebno: Windows i telefon.

3. [ ] **Potrošena MP4 kvota — proveri da li se uopšte prikazuje.** [133.9]
   O čemu se radi: Server broji potrošenu kvotu za MP4 izvoz, ali nije sigurno
   da aplikacija taj broj igde prikazuje: podešavanja pod `Account statistics`
   pokazuju sačuvane tutorijale i pozicije i sesije ovog meseca. Proverava se
   da li se kvota negde vidi, i da li raste samo posle uspešnog izvoza.
   Gde: `Settings` (zupčanik u zaglavlju) → `Account statistics`; ili proveri
   unutar dijaloga `Export video`.
   Uradi: Izvezi jedan tutorijal u video, pa proveri `Account statistics` u
   Podešavanjima i sam dijalog za izvoz — traži bilo kakav broj/oznaku
   potrošene MP4 kvote. Zatim probaj izvoz koji padne (npr. bez interneta) i
   proveri da se taj broj nije promenio.
   Treba da vidiš: Ako takav brojač postoji, mora da poraste posle uspešnog
   izvoza i da ostane nepromenjen posle neuspešnog. Ako ga uopšte ne nalaziš na
   ekranu, reci — to je nalaz vredan prijave (možda ga treba dodati na
   `Account statistics`).
   Potrebno: Windows.

4. [ ] **Podešavanja → Birth year: ispravka sa „Cancel"** [35.b1107]
   O čemu se radi: Red `Birth year` u Podešavanjima otvara isti ekran kao age
   gate, ali sa `Cancel` umesto `Sign out`, i pokazuje upisanu godinu.
   Gde: `Settings` (zupčanik) → sekcija „ACCOUNT" → red `Birth year`.
   Uradi: Otvoriti red `Birth year` u Podešavanjima, promeniti godinu i
   sačuvati; zatim ponovo otvoriti red.
   Treba da vidiš: Red pokazuje upisanu godinu; ekran koji se otvara ima dugme
   `Cancel` (umesto `Sign out`); ispravka se vidi i u redu u Podešavanjima.
   Potrebno: Windows i telefon.

5. [ ] **Novi glas se ponudi i „Test" ga izgovara bez restarta.** [0k.b138]
   O čemu se radi: Ulazak u Podešavanja sam ponovo očita spisak glasova (isto
   što radi i dugme `Check for voices again`), pa se novoinstalirani glas odmah
   nađe na spisku bez gašenja aplikacije.
   Gde: `Settings` (zupčanik) → sekcija „SPEECH (READING MESSAGES)" → padajući
   spisak jezika, ili dugme `Check for voices again`.
   Uradi: Instalirati u operativnom sistemu još jedan glas za sintezu govora,
   pa — bez restarta aplikacije — samo ući u `Settings` (ili pritisnuti
   `Check for voices again`), pa pritisnuti `Test`.
   Treba da vidiš: Novi glas se pojavljuje na spisku, a `Test` ga izgovara —
   bez ijednog restarta aplikacije.
   Potrebno: Windows i telefon.

6. [ ] **„Parent email" red sakriven za punoletan nalog.** [36.b1201]
   O čemu se radi: Red `Parent email` u Podešavanjima se prikazuje samo
   maloletnom nalogu.
   Gde: `Settings` (zupčanik) → sekcija „ACCOUNT" → red `Parent email`.
   Uradi: Uporediti Podešavanja maloletnog naloga i punoletnog naloga.
   Treba da vidiš: Red `Parent email` se vidi samo maloletnom nalogu, ne i
   punoletnom.
   Potrebno: Windows i telefon.

7. [ ] **Neispravna adresa roditelja: poruka, ništa se ne šalje.** [36.b1203]
   O čemu se radi: Neispravna adresa roditelja (npr. bez @, ili prazna) mora da
   bude odbijena pre slanja.
   Gde: `Settings` (zupčanik) → sekcija „ACCOUNT" → red `Parent email`.
   Uradi: Uneti neispravnu adresu (npr. „roditelj", ili ostaviti prazno) i
   pritisnuti `Send`.
   Treba da vidiš: Poruka `Enter a valid parent email address.` — ništa se ne
   šalje.
   Potrebno: Windows i telefon.

8. [ ] **`User manual` otvara pregledač na pravoj adresi.** [152.1]
   O čemu se radi: Sajt sa priručnikom (site/mislisha/manual/) ima dva ulaza iz
   aplikacije. Dok sajt nije objavljen, očekivano je da stranica ne postoji na
   netu — proveri samo da se pregledač otvara i da je adresa tačna.
   Gde: `Settings` → sekcija HELP → red `User manual`; i F1
   (`Keyboard Shortcuts`) → `User manual`.
   Uradi: Pritisni red `User manual` u Settings; zatim otvori F1 i pritisni
   dugme `User manual` tamo.
   Treba da vidiš: Oba dovode do chesstrainers.app/mislisha/manual/ u
   sistemskom pregledaču — sama adresa je tačna, sadržaj stranice se ne
   ocenjuje dok sajt nije objavljen.
   Potrebno: Windows i telefon; internet.

### Podešavanja i izgled — Cela aplikacija

1. [ ] **Reč „studio” se sreće samo u imenu „Tutorial studio”** [131.5]
   O čemu se radi: Preimenovanje iz faze 1b je ostavilo reč „studio” na tačno
   jednom mestu — imenu ekrana za pisanje tutorijala; Preparation i Analysis su
   čiste imenice bez te reči.
   Gde: cela aplikacija (`Home`, `Practise`, `Analyse`, `Teach`,
   soba/`Preparation`, Podešavanja).
   Uradi: Prođi kroz Preparation, Analysis, Podešavanja i glavne ekrane i traži
   reč „studio”.
   Treba da vidiš: Reč „studio” se pojavljuje samo u nazivu „Tutorial studio”
   (i njegovom meniju/dijalozima) — nigde drugde u aplikaciji.
   Potrebno: Windows.

2. [ ] **Sopstveni tekst aplikacije i dalje govori engleski, bez obzira na
   jezik tutorijala.** [150.8]
   O čemu se radi: Jezik tutorijala menja samo trenerov tekst; tekst koji
   aplikacija sama čita (dugmad, poruke) ostaje engleski.
   Gde: `Practise` → `Tactics tailored to you` (glasovna povratna informacija
   posle poteza).
   Uradi: Otvori tutorijal na srpskom jeziku i pusti ga glasom; zatim u
   `Practise` reši par zagonetki gde aplikacija sama izgovara povratnu
   informaciju (ne trenerov tekst).
   Treba da vidiš: Aplikacijin sopstveni tekst je i dalje engleskim glasom,
   nezavisno od jezika otvorenog tutorijala.
   Potrebno: Windows i telefon.

3. [ ] **Galerija dizajna prikazuje istu traku evaluacije kao prava.**
   [45.b1717]
   O čemu se radi: Maketa u galeriji dizajna postoji da bi se dizajn video bez
   prave partije; mora ostati verna pravom widget-u.
   Gde: `Settings` → (dno ekrana) → `Design Gallery (Debug)`.
   Uradi: Otvori galeriju dizajna u debug gradnji, pronađi maketu trake
   evaluacije i uporedi je sa pravom trakom u `Analyse`.
   Treba da vidiš: Maketa izgleda identično pravoj traci — isti izgled, boje,
   oblik.
   Potrebno: Windows; debug build.

4. [ ] **Razmak i tipografija posle tokena — širi pregled ekrana.** [45.b1731]
   O čemu se radi: Paketi 32-40 migracije na tokene menjali su razmak i
   tipografiju, ne samo boju; "izgleda drugačije" je očekivano, "izgleda
   razbijeno" (tekst/dugmad van ekrana) nije.
   Gde: `Settings`, `Sign In`, `Home`, `Analyse`, `Practise`.
   Uradi: Prođi navedene ekrane na telefonu, prvo u debug gradnji (crta
   upozorenje na prelivanje), pa u release gradnji.
   Treba da vidiš: Nijedan red teksta ili dugme nije odsečeno van ekrana ni u
   jednoj gradnji; razlike u razmaku su prihvatljive, prelivanje nije.
   Potrebno: telefon; debug build; release build.

5. [ ] **Novi nazivi ekrana staju u zaglavlje i na užem prozoru.** [131.6]
   O čemu se radi: Regresiona provera: preimenovanje ekrana
   (Priprema/Analiza/Studio za tutorijal) ne sme da napravi prelivanje naslova
   u zaglavlju.
   Gde: `Teach` → `Preparation`; `Analyse`; `Teach` → (kartica) `Tutorials` →
   (tutorijal).
   Uradi: Otvori sva tri ekrana i suzi prozor (ili pogledaj na telefonu).
   Treba da vidiš: Nijedan naslov u zaglavlju se ne preliva ili seče na uskom
   prozoru.
   Potrebno: Windows i telefon.

## Server i alati

### Server i alati — Sajt i priručnik

1. [ ] **Sadržaj priručnika vodi na svaku od trinaest stranica i nazad.**
   [152.2]
   O čemu se radi: Sajt još nije objavljen — otvori
   site/mislisha/manual/index.html lokalno u pregledaču.
   Gde: site/mislisha/manual/index.html, otvoreno lokalno u pregledaču.
   Uradi: Otvori index.html; klikni redom svih trinaest stavki sadržaja, pa se
   sa svake vrati na sadržaj.
   Treba da vidiš: Svaka stavka otvara svoju stranicu, i sa svake postoji put
   nazad na sadržaj.
   Potrebno: Windows i telefon.

2. [ ] **Tri zadatka po uputstvu, bez znanja iz glave.** [152.3]
   O čemu se radi: Test radi po slovu uputstva, ne po onome što već znaš da
   radiš — ako te uputstvo pošalje na pogrešno mesto, to je greška uputstva.
   Gde: site/mislisha/manual/ stranice 'Write a tutorial', 'Send a tutorial to
   a student', 'Turn a tutorial into a video'.
   Uradi: Otvori svaku od tri stranice i radi tačno ono što piše: napiši kratak
   tutorijal sa jednim pitanjem; pošalji ga nalogu-učeniku; izvezi ga kao
   video.
   Treba da vidiš: Svaki zadatak uspe praćenjem samo teksta stranice; zapiši
   svaki korak gde te uputstvo pošalje na pogrešno mesto.
   Potrebno: Windows i telefon; nalog trenera i učenika.

3. [ ] **Stranice za igrače i učenike opisuju ono što se stvarno vidi na
   ekranu.** [152.4]
   O čemu se radi: Proverava se da li je opis u priručniku razumljiv i tačan,
   ne samo da li nazivi koje pominje postoje u aplikaciji (to već proverava
   automatski test).
   Gde: site/mislisha/manual/ stranice 'Practise on your own', 'Build an
   opening repertoire', 'Analyse a position or a game', 'Work with your
   trainer'.
   Uradi: Pročitaj sve četiri stranice dok istovremeno gledaš odgovarajuće
   ekrane u aplikaciji.
   Treba da vidiš: Svaka stranica tačno opisuje ono što se vidi na ekranu na
   koji upućuje.
   Potrebno: Windows i telefon.

4. [ ] **Stranica za roditelje se slaže sa stranicom saglasnosti.** [152.5]
   O čemu se radi: Roditeljska stranica u priručniku ne sme da protivreči
   pravnom tekstu saglasnosti koji server servira.
   Gde: site/mislisha/manual/ stranica 'For parents'.
   Uradi: Pročitaj stranicu 'For parents' i uporedi je sa stranicom saglasnosti
   koju server šalje roditelju.
   Treba da vidiš: Tekstovi se ne protivreče; stranica je ono što bi vlasnik
   hteo da roditelj pročita.
   Potrebno: Windows i telefon.

5. [ ] **Stranica proizvoda opisuje aplikaciju kako je danas.** [152.6]
   O čemu se radi: Opis je osvežen (tutorijali, časovi, vežbanje, video,
   izveštaj roditelju) — provera da li je to opis pod kojim bi vlasnik objavio
   aplikaciju.
   Gde: site/mislisha.html.
   Uradi: Pročitaj site/mislisha.html u celini.
   Treba da vidiš: Opis odgovara današnjoj aplikaciji i onome pod čim bi je
   vlasnik objavio.
   Potrebno: Windows i telefon.

6. [ ] **Ništa važno ne fali iz sadržaja priručnika.** [152.7]
   O čemu se radi: Poslednja, otvorena provera — traži prazninu, ne potvrđuje
   postojeće.
   Gde: site/mislisha/manual/index.html.
   Uradi: Razmisli o zadatku koji radiš često u aplikaciji, a koji nije
   pokriven nijednom od trinaest stavki sadržaja.
   Treba da vidiš: Ako takav zadatak postoji, to je sledeća stranica koju treba
   dodati priručniku — zapiši koji.
   Potrebno: Windows i telefon.

7. [ ] **Uputstvo (odeljak 8) tačno opisuje izbor jezika i glasa.** [150.9]
   O čemu se radi: Test čita samo da li citirane oznake postoje u kodu; ovde se
   proverava da li je tekst tačan i upotrebljiv.
   Gde: docs/UPUTSTVO-STUDIO.md, odeljak 8.
   Uradi: Pročitaj odeljak 8 posle svih provera 150.1-150.8, uporedi sa onim
   što si zaista video.
   Treba da vidiš: Tekst uputstva opisuje tačno ono ponašanje koje si upravo
   video (izbor jezika, prekriženi zvučnik, izvoz videa).
   Potrebno: Windows i telefon.

### Server i alati — Govor i renderovanje

1. [ ] **Ćirilički Azure glas čita dodate reči na ćirilici.** [146.2]
   O čemu se radi: Slova kolona/vrsta se dodaju izgovoru odvojeno od trenerovog
   teksta; pitanje je da li ćirilički glas uopšte razume latinicu kojom su
   natpisi u aplikaciji pisani.
   Gde: chess_backend — node scripts/tts-probe.js "Odigraj Bc4."
   sr-RS-NicholasNeural.
   Uradi: Pokreni tts-probe.js sa ćiriličkim srpskim glasom
   (sr-RS-NicholasNeural) i istom rečenicom.
   Treba da vidiš: Dodate reči o potezu se čuju na ćirilici; presudi na uho da
   li glas uopšte čita latinicu kojom su natpisi pisani — ako ne, zapiši da je
   sr-Latn-RS jedini upotrebljiv glas za ovaj projekat.
   Potrebno: server; server; internet.

2. [ ] **Azure glas izgovara potez rečima, ne slovka ga.** [145.3]
   O čemu se radi: .env ima TTS_PROVIDER=azure, AZURE_SPEECH_KEY i
   AZURE_SPEECH_REGION (vlasnikov ključ — nikad u repozitorijum). Srpski
   glasovi (sr-RS-Nicholas/Sophie, i sr-Latn-RS blizanci) su već potvrđeni da
   postoje.
   Gde: chess_backend — node scripts/tts-probe.js "Odigraj Bd5, pa O-O." <id
   srpskog glasa>.
   Uradi: Pokreni tts-probe.js sa srpskim glasom i rečenicom o potezima Bd5 i
   O-O, pa preslušaj exports/tts-probe.wav.
   Treba da vidiš: Glas kaže 'lovac d pet' i 'mala rokada' — ne slovka 'be de
   pet'.
   Potrebno: server; server; internet.

3. [ ] **Kad piper ne može da se pokrene, pitanje o glasu nestaje umesto da ga
   ponudi pa otkaže.** [144.2]
   O čemu se radi: Server sad testira motor pre nego što ga ponudi kao odgovor,
   umesto da tek pri crtanju otkrije da ne radi.
   Gde: chess_backend/.env — privremeno pokvari PIPER_PYTHON (npr.
   PIPER_PYTHON=nema-ovoga), restartuj backend.
   Uradi: Pokvari PIPER_PYTHON u .env i restartuj backend, pa u aplikaciji
   otvori `Export video`.
   Treba da vidiš: U dijalogu za izvoz nema pitanja `Narration` uopšte — nudi
   se samo nem film (i sopstveni snimak, ako postoji). U logu servera stoji
   jedna WARN rečenica da su piper glasovi instalirani ali motor ne može da se
   pokrene.
   Potrebno: server; server.

4. [ ] **Server razlikuje 'motor ne radi' od 'nema glasova'.** [144.3]
   O čemu se radi: Naracija se ne može tražiti direktno iz aplikacije u ovom
   slučaju — ovo je serverska provera.
   Gde: POST /lessons/:id/export-video sa narrate: true, direktno na server
   (npr. curl).
   Uradi: Sa pokvarenim PIPER_PYTHON iz prethodne provere, pošalji zahtev za
   izvoz sa narrate: true direktno serveru.
   Treba da vidiš: Odgovor kaže da motor za govor nije mogao da se pokrene, a
   ne da nema instaliranih glasova. Vrati .env na pravu venv putanju i
   restartuj backend pre nastavka.
   Potrebno: server; server.

5. [ ] **Izmeri stvarnu brzinu crtanja na dropletu i upiši je u .env.** [142.6]
   O čemu se radi: RENDER_DRAW_FPS_720P i RENDER_DRAW_FPS_1080P su i dalje
   podrazumevano 12 i 6 — procena sa razvojne mašine, ne izmereno na dropletu.
   Gde: droplet — pokreni izvoz fixture-a medium-12-parts jednom na 720p i
   jednom na 1080p.
   Uradi: Na dropletu izrenderuj medium-12-parts jednom na 720p i jednom na
   1080p, podeli 2528 frejmova sa izmerenim sekundama renderovanja, uzmi
   sporije merenje sa marginom.
   Treba da vidiš: Upisane vrednosti u .env kao RENDER_DRAW_FPS_720P i
   RENDER_DRAW_FPS_1080P (dok se ne uradi, i dalje važe podrazumevane 12/6,
   procenjene na drugoj mašini).
   Potrebno: server; server.

6. [ ] **Server odbija izvoz sa zastarelim snimkom (409), bez trošenja slota.**
   [140.8]
   O čemu se radi: I ako se izmena nekako provuče do zahteva za izvoz, server
   mora da je uhvati — ne samo aplikacija. Pretpostavlja stavke 138 i 139.
   Snimanje glasa preko tutorijala je pisano kao Windows-only (studio tada nije
   postojao na telefonu); otkad studio ima raspored za uzak ekran,
   `Record narration` je i tamo u `More` meniju, pa vredi probati i na
   telefonu, ne samo na Windowsu.
   Gde: POST /lessons/:id/export-video sa starim snimkom posle izmene (npr.
   preko curl/Postman).
   Uradi: Posle izmene tutorijala posle snimka, pošalji zahtev za izvoz sa
   starim snimkom direktno na server (mimo aplikacije).
   Treba da vidiš: Server odgovara 409 sa rečenicom o izmeni i ne troši slot za
   renderovanje (broj renderovanja na nalogu ne raste).
   Potrebno: server; sačuvan tutorijal sa snimkom; server.

7. [ ] **Snimak nije javno dostupan preko direktnog linka.** [139.8]
   O čemu se radi: Pretpostavlja stavku 138 — snimak već postoji na uređaju.
   Snimanje glasa preko tutorijala je pisano kao Windows-only (studio tada nije
   postojao na telefonu); otkad studio ima raspored za uzak ekran,
   `Record narration` je i tamo u `More` meniju, pa vredi probati i na
   telefonu, ne samo na Windowsu.
   Gde: …/uploads/narration/<ime>.wav (direktan URL u pregledaču).
   Uradi: Otvori u pregledaču direktan URL poslatog snimka
   (…/uploads/narration/<ime>.wav) bez prijave.
   Treba da vidiš: Server odgovara 404 — fajl se ne servira javno.
   Potrebno: server; server.

8. [ ] **Snimak se čuva kao WAV plus JSON na uređaju.** [138.11]
   O čemu se radi: Faza 1-2 drži snimak samo na uređaju (slanje na server je
   faza 3, već urađena) — provera je da fajl zaista postoji i da traje onoliko
   koliko ekran kaže.
   Gde: direktorijum podrške aplikacije (getApplicationSupportDirectory),
   podfolder narration\lesson_<id>.
   Uradi: Posle snimanja narod otvori taj folder (npr. preko Windows Explorer-a
   na putanji koju app koristi) i proveri sadržaj.
   Treba da vidiš: U folderu stoji tačno jedan take-….wav i take.json; wav se
   pušta u običnom plejeru, i ffprobe daje isto trajanje koje piše na ekranu za
   snimanje.
   Potrebno: Windows; sačuvan tutorijal; debug build.

9. [ ] **Uzorak radi samo za glasove koje server stvarno nudi.** [146.6]
   O čemu se radi: Ako se sačuvani id piperovog glasa ne poklapa sa onim što
   server sad nudi, dugme za uzorak ne sme da nudi Azure id na piper serveru.
   Gde: chess_backend/.env — TTS_PROVIDER na piper, restart backend, pa
   `Export video` u aplikaciji.
   Uradi: Sa TTS_PROVIDER=piper otvori `Export video` i probaj
   `Hear this voice` za piperov glas; proveri da Azure id nije u listi.
   Treba da vidiš: Uzorak radi za piperove glasove; Azure id se ne pojavljuje u
   listi i ne može da se izabere.
   Potrebno: server; server.

10. [ ] **Piper ostaje rezerva kad se provajder vrati na njega.** [145.7]
   O čemu se radi: Azure je dodat kao provajder, ali piper mora da ostane
   potpuno ispravna rezerva.
   Gde: chess_backend/.env — TTS_PROVIDER=piper, restart backend, pa
   `Export video` u aplikaciji.
   Uradi: Vrati TTS_PROVIDER=piper u .env, restartuj backend, izvezi film sa
   naracijom.
   Treba da vidiš: Film govori piperovim glasom kao i pre — ništa iz Azure
   prelaska nije pokvarilo rezervu.
   Potrebno: server; server.

### Server i alati — Saglasnost roditelja

1. [ ] **„Ne dajem saglasnost" na stranici roditelja.** [36.b1184]
   O čemu se radi: Stranica za saglasnost roditelja je namerno na srpskom
   (tekst odobren od advokata) i ostaje tako; dugme „Ne dajem saglasnost" mora
   da ostavi vezu na čekanju, bez reda u tabeli prijatelja.
   Gde: (otvoriti link iz mejla za saglasnost roditelja) → dugme „Ne dajem
   saglasnost"
   Uradi: Otvoriti drugu vezu (novi zahtev) i na stranici roditelja pritisnuti
   „Ne dajem saglasnost".
   Treba da vidiš: Veza ostaje na „čeka saglasnost roditelja", u bazi je
   upisano da saglasnost nije data sa vremenom, i ne pravi se red u tabeli
   prijatelja.
   Potrebno: server; internet.

2. [ ] **Izmišljen token: „Link nije prepoznat"** [36.b1187]
   O čemu se radi: Izmišljen token u linku mora da bude jasno odbijen, bez
   ijednog upisa u bazu.
   Gde: (otvoriti URL za saglasnost sa izmišljenim tokenom) → stranica za
   saglasnost.
   Uradi: Otvoriti stranicu za saglasnost sa nasumičnim, nepostojećim tokenom u
   adresi.
   Treba da vidiš: Stranica kaže „Link nije prepoznat", bez ijednog traga u
   bazi.
   Potrebno: server; internet.

3. [ ] **Istekao link: druga poruka od nepostojećeg.** [36.b1188]
   O čemu se radi: Istekao link mora da ima drugačiju poruku od nepostojećeg
   linka, da roditelj ne pomisli da je pogrešio adresu.
   Gde: (istekao zahtev za saglasnost) → stranica za saglasnost.
   Uradi: Napraviti zahtev za saglasnost i u bazi mu ručno postaviti isteklo
   vreme, pa otvoriti link.
   Treba da vidiš: Stranica kaže „Link je istekao" — drugačija poruka od one za
   nepostojeći link.
   Potrebno: server; internet.

4. [ ] **Ime deteta sa HTML oznakama se prikazuje kao tekst.** [36.b1191]
   O čemu se radi: Ime deteta koje neko upiše sa HTML oznakama u sebi ne sme da
   se renderuje kao markup na stranici za saglasnost — mora da se vidi kao
   običan tekst.
   Gde: (stranica za saglasnost roditelja) → ime deteta u tekstu stranice.
   Uradi: Postaviti ime deteta na nešto sa <b> u sebi (registracija ili
   ispravka imena), pa otvoriti stranicu za saglasnost.
   Treba da vidiš: Ime se vidi kao običan tekst (sa vidljivim znacima <b>), ne
   kao podebljano.
   Potrebno: server; internet.

5. [ ] **PUBLIC_BASE_URL mora biti dostupna adresa pre provere saglasnosti.**
   [S35.b944]
   O čemu se radi: Link za saglasnost roditelja se pravi od podešavanja
   PUBLIC_BASE_URL; mora da pokazuje na adresu dostupnu i sa drugog uređaja
   (LAN adresa ovog računara), inače link iz mejla ne radi.
   Gde: (podešavanje u chess_backend/.env).
   Uradi: Postaviti PUBLIC_BASE_URL na LAN adresu ovog računara (npr.
   http://<lan-adresa>:3000) pre provere stavki o roditeljskoj saglasnosti.
   Treba da vidiš: Link primljen na mejl se otvara i učitava sa drugog uređaja
   na istoj mreži.
   Potrebno: server; server; drugi uređaj.

### Server i alati — Server

1. [ ] **Practise otvoren kao samostalna ruta ima sopstvenu traku.** [46.b1783]
   O čemu se radi: Ruta /training i dalje postoji i vodi na isti ekran kao tab
   Practise, ali nijedan dodir u aplikaciji je ne otvara — dostupna je samo
   direktnim otvaranjem te rute (deep link/dev alat), gde ekran treba da nosi
   sopstveni gornja traka sa putem nazad.
   Gde: (nema dodira u aplikaciji — otvara se direktno rutom /training).
   Uradi: U debug gradnji otvori aplikaciju direktno na ruti /training
   (razvojni alat ili deep link), umesto kroz tab Practise.
   Treba da vidiš: Ekran ima sopstveni gornja traka sa putem nazad — za razliku
   od istog ekrana unutar taba, koji ga nema.
   Potrebno: Windows; debug build.

2. [ ] **Debug preko release (ili obrnuto) javlja komandu za brisanje.**
   [42.b1567]
   O čemu se radi: Debug i release APK nisu potpisani istim ključem.
   install.ps1 pokreće build_and_deploy.ps1, koje prepoznaje sukob potpisa
   (INSTALL_FAILED_UPDATE_INCOMPATIBLE) i treba da ispiše tačnu adb uninstall
   komandu i upozorenje da ona nosi i prijavu i podešavanja.
   Gde: (chess_app/install.ps1, PowerShell — nije UI aplikacije).
   Uradi: Instaliraj release na telefon (install.ps1 -Platforma android -Mode
   release), pa preko njega pokušaj instalaciju debug varijante (-Mode debug),
   bez prethodnog ručnog brisanja.
   Treba da vidiš: Skripta ne ispisuje golo "Instalacija nije uspela" —
   ispisuje tačnu adb uninstall komandu i rečenicu da brisanje odnosi i prijavu
   i podešavanja na telefonu.
   Potrebno: telefon; telefon; debug build; release build.

3. [ ] **-Install pravi kopiju i prečicu, -Uninstall ih uklanja.** [42.b1585]
   O čemu se radi: build_windows.ps1 uz -Install kopira izlazni folder u stalni
   InstallPath (podrazumevano %LOCALAPPDATA%\Mislisha) i pravi prečicu u Start
   meniju; -Uninstall tu kopiju uklanja.
   Gde: (chess_app/install.ps1, PowerShell — nije UI aplikacije).
   Uradi: Pokreni install.ps1 -Platforma windows -Run i sačekaj kraj, pa
   proveri %LOCALAPPDATA%\Mislisha i Start meni; zatim pokreni install.ps1
   -Platforma windows -Uninstall.
   Treba da vidiš: Posle instalacije: aplikacija stoji u
   %LOCALAPPDATA%\Mislisha i Start meni ima prečicu koja je pokreće. Posle
   deinstalacije: oba nestaju.
   Potrebno: Windows.

4. [ ] **Provera brisanja zaostalog fonta pri sledećoj novoj ikoni.**
   [42.b1587]
   O čemu se radi: build_windows.ps1 sam briše i ponovo gradi
   MaterialIcons-Regular.otf kad taj fajl ostane stariji od početka gradnje
   (release grana); poslednji put font nije bio zaostao pa se ta grana nije
   okinula.
   Gde: (chess_app/build_windows.ps1, PowerShell — nije UI aplikacije).
   Uradi: Kad se sledeći put u kodu doda korišćenje ikone koja se do tada nigde
   nije koristila, pokreni release gradnju (install.ps1 -Platforma windows
   -Mode release) i prati ispis koraka "Font sa ikonama".
   Treba da vidiš: Ispis prijavljuje da je font bio zaostao, obrisan i da je
   gradnja ponovljena — a nova ikona se na kraju vidi na ekranu, ne kao prazno
   polje.
   Potrebno: Windows.

5. [ ] **Restart backenda dok su oba naloga otvorena ne ruši gurac.** [21.b716]
   O čemu se radi: Soket se ponovo poveže sam posle restarta backenda i ponovo
   prijavi nalog; obaveštenja tada opet stižu, bez potrebe da se aplikacija
   ugasi.
   Gde: (nema poseban ekran — opšte ponašanje aplikacije).
   Uradi: Sa oba naloga otvorenim, restartovati backend (`npm run dev`), pa
   jednim nalogom odgovoriti na zahtev/zadatak.
   Treba da vidiš: Aplikacija se ne ruši; posle ponovnog povezivanja soketa,
   obaveštenje ipak stigne drugoj strani.
   Potrebno: server; nalog trenera i učenika; server.

6. [ ] **Promena uloge u bazi važi odmah, bez ponovne prijave.** [S35.b941]
   O čemu se radi: Uloga (role) se čita iz reda u bazi pri svakom zahtevu, ne
   iz starog tokena, pa promena preko SQL-a odmah utiče na aplikaciju.
   Gde: (direktna izmena u bazi, pa posmatranje u aplikaciji).
   Uradi: Dok je nalog prijavljen u aplikaciji, izvršiti UPDATE users SET role
   = 'admin' WHERE email = ... u bazi, bez odjave i ponovne prijave.
   Treba da vidiš: Promena važi odmah u toj istoj sesiji — nema potrebe za
   ponovnom prijavom.
   Potrebno: server; server.

7. [ ] **Server vraća napredak po izvoru i po kategoriji.** [176.7]
   O čemu se radi: Ruta za napredak zagonetki vraća, po izvoru, brojeve
   seen/solved/firstTry/failed/skipped/toRetry; mate zagonetke dodatno imaju
   raspodelu po dubini, a završnice po režimu.
   Gde: server — `GET /api/puzzles/progress` sa tokenom naloga.
   Uradi: Pozovi `GET /api/puzzles/progress` sa važećim tokenom pošto je nalog
   rešio bar po jednu zagonetku iz više izvora.
   Treba da vidiš: Odgovor sadrži po izvoru polja
   seen/solved/firstTry/failed/skipped/toRetry; `mate_puzzle` ima raspodelu
   `buckets` po dubini, `endgame` po režimu.
   Potrebno: server; server; nalog trenera i učenika.

8. [ ] **Gradnja iz necist stabla dobija + na kraju commita.** [42.b1570]
   O čemu se radi: build_and_deploy.ps1 čita git status --porcelain pre gradnje
   i, ako ima nesačuvanih izmena, dodaje + na kraj commit oznake koju kasnije
   ispisuje ekran Settings.
   Gde: (chess_app/install.ps1, pa `Settings` na telefonu).
   Uradi: Napravi bilo koju nesačuvanu izmenu u chess_app/, pokreni install.ps1
   -Platforma android, pa na telefonu otvori `Settings` i pogledaj dno ekrana.
   Treba da vidiš: Red na dnu `Settings` pokazuje commit sa + na kraju; posle
   vraćanja izmene i nove gradnje, + nestaje.
   Potrebno: telefon; telefon.

9. [ ] **Lokalni tablebase server se pokreće i učita tabele.** [244.1]
   O čemu se radi: Naša sopstvena Syzygy tablebase (lila-tablebase) se pokreće
   preko launcher menija i služi pozicije sa 5 ili manje figura umesto
   Lichess-a.
   Gde: pokreni.ps1 → opcija `[5] Tablebase`.
   Uradi: Pokreni `pokreni.ps1` i izaberi opciju `[5] Tablebase`.
   Treba da vidiš: Otvara se novi terminal tab i u njemu se ispisuje red oblika
   „added … tables from D:\syzygy\3-4-5“, bez greške u ispisu.
   Potrebno: server; tablebase (pokreni.ps1 [5]).

10. [ ] **Slanje domaćeg troši kvotu — vidljivo samo u logu servera.** [183.3]
   O čemu se radi: Ekran za prikaz kvote u aplikaciji još ne postoji
   (vlasnikova napomena od 18.9.2026). Do tada se potrošnja proverava samo iz
   servera: slanje jednom učeniku troši jednu jedinicu bez obzira koliko stavki
   domaći ima, a odbijeno slanje ne troši ništa.
   Gde: server — log procesa `chess-backend`.
   Uradi: Pošalji domaći sa pet stavki jednom učeniku i prati log servera oko
   trenutka slanja. Zatim izazovi odbijeno slanje (npr. na nalogu bez preostale
   kvote).
   Treba da vidiš: U logu se za uspešno slanje pojavljuje zapis „Homework sent“
   po tom učeniku (bez obzira na broj stavki unutra); odbijeno slanje ne
   ostavlja takav zapis.
   Potrebno: server; server.

11. [ ] **Log registracije ne ispisuje adresu, samo id.** [169.3]
   O čemu se radi: Privatnost naloga — log servera ne sme da sadrži čitljivu
   email adresu, samo identifikator (u razvojnom okruženju: kod uz maskiranu
   adresu).
   Gde: server — log procesa `chess-backend` u trenutku registracije.
   Uradi: Registruj novi nalog i unesi kod za potvrdu, pa pogledaj log servera
   oko tog trenutka.
   Treba da vidiš: U logu nema pune adrese, samo identifikator naloga (u
   razvoju: kod uz maskiranu adresu oblika „p***@domen“).
   Potrebno: server; server.

### Server i alati — Arhiva partija i izveštaji

1. [ ] **Priprema za protivnika: isključeno = odbijeno.** [59.1]
   O čemu se radi: OPPONENT_PREP_ENABLED je podrazumevano false; ova provera je
   jedina iz sekcije koja mora da prolazi i sa isključenim prekidačem.
   Gde: (POST /games/prep/import, bez menjanja .env).
   Uradi: Sa trenutnim (isključenim) podešavanjem pozovi POST
   /games/prep/import.
   Treba da vidiš: Odgovor je 403 sa reason disabled, ne prazan izveštaj.
   Potrebno: server; server.

2. [ ] **Ništa se ne dohvata dok je priprema isključena.** [59.2]
   O čemu se radi: Kad je priprema za protivnika isključena, nijedan njen poziv
   ne sme ništa upisati u bazu.
   Gde: (POST /games/prep/import, isključeno; provera baze).
   Uradi: Posle odbijenog poziva iz prethodne provere proveri user_games za tog
   protivnika.
   Treba da vidiš: Nijedan novi red nije upisan.
   Potrebno: server; server.

3. [ ] **Uvezene protivnikove partije ne ulaze u sopstvenu statistiku.** [59.3]
   O čemu se radi: Za ovu i naredne stavke sekcije 59 treba privremeno
   postaviti OPPONENT_PREP_ENABLED=true u .env na lokalnom serveru (ne na
   dropletu), pa posle provere vratiti na false.
   Gde: (POST /games/prep/import sa uključenim prekidačem; GET /games/stats).
   Uradi: Uključi prekidač, uvezi protivnikovu arhivu, pa pozovi GET
   /games/stats za sopstveni nalog.
   Treba da vidiš: Svaki uvezeni red ima subject_is_owner = FALSE, GET
   /games/stats broji i dalje samo igračeve partije.
   Potrebno: server; server; internet.

4. [ ] **vs= vraća samo međusobne partije.** [59.4]
   O čemu se radi: Filter vs= treba da vrati samo partije odigrane baš protiv
   sopstvenog naloga.
   Gde: (POST /games/prep/import?vs=<sopstveni handle>).
   Uradi: Uvezi protivnika sa vs=<sopstveni Lichess handle>.
   Treba da vidiš: Broj partija odgovara broju međusobnih partija sa Lichess
   profila, ne celoj arhivi.
   Potrebno: server; server; internet.

5. [ ] **opening=true donosi ECO i naziv otvaranja.** [59.5]
   O čemu se radi: Zastavica opening=true treba da donese podatke o otvaranju
   (ECO/naziv) uz svaku partiju.
   Gde: (POST /games/prep/import?opening=true).
   Uradi: Uvezi protivnika sa zastavicom opening=true, proveri kolone
   eco/opening.
   Treba da vidiš: Kolone eco i opening nisu prazne za uvezene redove.
   Potrebno: server; server; internet.

6. [ ] **Pogrešan perfType se odbija.** [59.6]
   O čemu se radi: Pogrešna vrednost tempa igre (perfType) mora biti odbijena,
   ne tiho zamenjena svim partijama.
   Gde: (POST /games/prep/import?perfType=bliz).
   Uradi: Pozovi uvoz sa nepostojećim perfType.
   Treba da vidiš: Odgovor je 400, ne tihi uvoz sa svim tempo-kontrolama.
   Potrebno: server; server; internet.

7. [ ] **Rejting prag odbija pre upisa.** [59.7]
   O čemu se radi: Rejting prag mora odbiti uvoz pre nego što bilo šta upiše u
   bazu.
   Gde: (POST /games/prep/import sa OPPONENT_PREP_MIN_RATING iznad
   protivnikovog rejtinga).
   Uradi: Postavi prag iznad rejtinga protivnika kog uvoziš, pa pokušaj uvoz.
   Treba da vidiš: Odgovor je 403 i nijedan red se ne upisuje.
   Potrebno: server; server; internet.

8. [ ] **Odbijenica zbog rejtinga ne odaje protivnikov broj.** [59.8]
   O čemu se radi: Poruka o odbijenom uvozu zbog rejtinga ne sme otkriti
   protivnikov stvarni rejting.
   Gde: (isti poziv kao prethodna provera).
   Uradi: Pročitaj poruku odbijenice.
   Treba da vidiš: Poruka imenuje prag, ali ne i protivnikov stvarni rejting.
   Potrebno: server.

9. [ ] **Dnevni limit broji ljude, ne uvoze.** [59.9]
   O čemu se radi: Dnevni limit uvoza protivnika broji različite ljude, ne broj
   uvoza.
   Gde: (POST /games/prep/import, isti protivnik dvaput istog dana).
   Uradi: Uvezi istog protivnika dva puta istog dana.
   Treba da vidiš: To se računa kao jedna osoba prema dnevnom limitu, ne dva.
   Potrebno: server; server; internet.

10. [ ] **Retencija briše samo protivničke partije.** [59.10]
   O čemu se radi: Automatsko brisanje starijih protivničkih partija
   (retencija) ne sme dirati igračevu sopstvenu arhivu.
   Gde: (OPPONENT_PREP_RETENTION_DAYS).
   Uradi: Na dan kad postoje i sopstvene i protivničke partije postavi
   OPPONENT_PREP_RETENTION_DAYS=0, sačekaj čišćenje, pa vrati na 30.
   Treba da vidiš: Protivničke partije su obrisane, sopstvene ostaju netaknute.
   Potrebno: server; server; internet.

11. [ ] **Izveštaj o protivniku ide kroz postojeću rutu.** [59.11]
   O čemu se radi: Izveštaj o protivniku treba da prođe kroz istu rutu koja već
   postoji za sopstvenu arhivu, bez nove rute.
   Gde: (GET /games/openings/leaks?subject=<protivnik>).
   Uradi: Posle uvoza protivnika pozovi istu rutu za izveštaj sa
   subject=protivnik.
   Treba da vidiš: Radi bez ijedne nove rute.
   Potrebno: server; server; internet.

12. [ ] **AI opis protivnika ne šalje ime modelu.** [59.12]
   O čemu se radi: Proverava se iz servera loga, ne iz odgovora aplikacije.
   Gde: (server log tokom generisanja AI opisa protivnika).
   Uradi: Zatraži AI opis pripremljenog protivnika i prati server log za zahtev
   ka modelu.
   Treba da vidiš: U logovanom zahtevu ka modelu se nigde ne pojavljuje
   protivnikov Lichess handle.
   Potrebno: server; server; internet; Gemini ključ na serveru.

13. [ ] **Bez ključa i dalje stiže izveštaj, samo bez rečenice.** [59.14]
   O čemu se radi: Ako AI opis ne može da se generiše (nema ključa), ostatak
   izveštaja i dalje mora stići.
   Gde: (priprema/AI opis protivnika, sa uklonjenim GEMINI_API_KEY).
   Uradi: Privremeno ukloni GEMINI_API_KEY u .env na lokalnom serveru
   (restartuj server), zatraži AI opis protivnika, pa vrati ključ.
   Treba da vidiš: Odgovor je i dalje 200 sa reason model-unavailable, brojevi
   stižu, samo bez AI rečenice.
   Potrebno: server; server.

14. [ ] **Nepovezani trener ne dobija domaći iz tuđe arhive.** [58.1]
   O čemu se radi: Domaći iz učenikove arhive je jedina funkcija koja prelazi
   između dva naloga, pa prava pristupa moraju biti stroga.
   Gde: (POST /assignments/from-archive).
   Uradi: Pozovi rutu sa studentId deteta koje nije na trenerovoj listi.
   Treba da vidiš: Odgovor je 403, i ne ostaje nijedan novi red u bazi.
   Potrebno: server; nalog trenera i učenika.

15. [ ] **Veza koja čeka odgovor ne dobija domaći iz arhive.** [58.2]
   O čemu se radi: Isto pravilo kao za nepovezanog trenera, ali za vezu koja
   još čeka odgovor.
   Gde: (POST /assignments/from-archive sa vezom u stanju pending).
   Uradi: Pošalji zahtev za par sa neprihvaćenom vezom.
   Treba da vidiš: Odgovor je 403.
   Potrebno: server; nalog trenera i učenika.

16. [ ] **dryRun pokazuje izabrane pozicije bez upisa.** [58.3]
   O čemu se radi: Probni režim (dryRun) mora pokazati šta bi se poslalo bez
   stvarnog upisa i trošenja kvote.
   Gde: (POST /assignments/from-archive sa dryRun: true).
   Uradi: Pozovi rutu sa dryRun: true za prihvaćenu vezu.
   Treba da vidiš: Odgovor pokazuje izabrane pozicije, ništa se ne upisuje,
   kvota se vraća.
   Potrebno: server; nalog trenera i učenika.

17. [ ] **Tuđa (protivnikova) arhiva ne ulazi u domaći iz arhive.** [58.6]
   O čemu se radi: Partije koje učenik nije sam igrao (protivničke, uvezene
   radi pripreme) ne smeju ući u domaći iz arhive.
   Gde: (POST /assignments/from-archive za učenika sa subject_is_owner=false
   partijama).
   Uradi: Na učeničkom nalogu uvezi protivnikove partije, pa pokreni domaći iz
   arhive.
   Treba da vidiš: Te partije se ne pojavljuju ni u domaćem zadatku ni u
   trenerskom pregledu.
   Potrebno: server; nalog trenera i učenika.

18. [ ] **Ponovno generisanje ne dupira pozicije.** [58.7]
   O čemu se radi: Ponovno generisanje domaćeg iz iste greške mora ponovo
   koristiti isti puzzle_id, ne praviti novi.
   Gde: (POST /assignments/from-archive ponovljen).
   Uradi: Pošalji domaći iz arhive dva puta za istog učenika.
   Treba da vidiš: Drugi put se ponovo koriste iste pozicije, bez duplikata.
   Potrebno: server; nalog trenera i učenika.

19. [ ] **GET /games/profile brojevi se poklapaju sa merenjem van baze.**
   [57.1]
   O čemu se radi: Osnovna provera tačnosti profila igrača — brojevi moraju
   odgovarati nezavisnom merenju.
   Gde: (GET /games/profile?username=).
   Uradi: Pozovi rutu za nalog sa poznatom, izmerenom arhivom i uporedi brojeve
   po dužini i po fazi partije sa nezavisnim merenjem.
   Treba da vidiš: Brojevi i procenti se poklapaju sa nezavisnim merenjem.
   Potrebno: server; uvezene partije.

20. [ ] **Podaci o satu (clock.atMove20, hurriedShare).** [57.2]
   O čemu se radi: Podaci o brzini igranja (sat) su deo istog profila i moraju
   se poklapati sa merenjem.
   Gde: (GET /games/profile?username=).
   Uradi: Pogledaj polja clock.atMove20 i clock.hurriedShare za nalog sa
   poznatom arhivom.
   Treba da vidiš: Brojevi odgovaraju nezavisnom merenju.
   Potrebno: server; uvezene partije.

21. [ ] **Brzina profila (sedam GROUP BY + nizovi sa satom).** [57.4]
   O čemu se radi: Profil čita sedam agregiranih upita plus nizove poteza sa
   satom — vredi znati brzinu.
   Gde: (GET /games/profile?username=).
   Uradi: Izmeri koliko traje poziv za nalog sa velikom arhivom.
   Treba da vidiš: Vreme odgovora je zabeleženo i prihvatljivo za korišćenje
   uživo.
   Potrebno: server; uvezene partije.

22. [ ] **Partije bez sata ne kvare prosek.** [57.5]
   O čemu se radi: Partije bez zabeleženog sata (starije od kad ga je Lichess
   počeo beležiti) ne smeju kvariti prosek.
   Gde: (GET /games/profile?username= za nalog sa starijim partijama bez sata).
   Uradi: Proveri profil naloga koji ima i partije bez sačuvanog sata (starije
   od kad ih je Lichess počeo beležiti).
   Treba da vidiš: Te partije se broje u gamesWithClocks, ali ne ulaze u
   prosečne brojke o satu.
   Potrebno: server; uvezene partije.

23. [ ] **Isti SM-2 interval kao kod lekcija.** [55.3]
   O čemu se radi: Isti algoritam (SM-2) treba da daje iste brojeve u oba
   konteksta ponavljanja.
   Gde: (poređenje intervala na serveru).
   Uradi: Uporedi interval koji za istu ocenu i iste ease_factor/repetitions
   daje ponavljanje grešaka sa onim za ponavljanje lekcija.
   Treba da vidiš: Brojevi (novi interval, ease_factor) su isti kao za lekcije
   pri istim ulazima.
   Potrebno: server.

24. [ ] **Tuđa partija se ne može podmetnuti kao sopstvena greška.** [55.4]
   O čemu se radi: Sopstvene greške ne smeju moći da se podmetnu tuđom
   partijom.
   Gde: (POST /games/mistakes sa gameId koji nije korisnikov).
   Uradi: Pozovi rutu sa gameId partije koja pripada drugom nalogu.
   Treba da vidiš: Tally prijavljuje game-not-yours i nijedan red se ne
   upisuje.
   Potrebno: server; nalog trenera i učenika.

25. [ ] **Tally se slaže kad su neki nalazi namerno pokvareni.** [55.5]
   O čemu se radi: Paket poslatih nalaza mora imati brojeve koji se slažu i
   imenovane razloge za odbijene.
   Gde: (POST /games/mistakes sa mešovitim paketom).
   Uradi: Pošalji paket sa nekoliko ispravnih i nekoliko namerno pokvarenih
   nalaza.
   Treba da vidiš: read = stored + duplicate + rejected, a razlozi odbijanja su
   imenovani.
   Potrebno: server.

26. [ ] **Ponovni upis istog nalaza ne pravi duplikat.** [55.7]
   O čemu se radi: Ponovni upis istog nalaza ne sme praviti duplikat reda.
   Gde: (POST /games/mistakes, isti nalaz dvaput).
   Uradi: Pošalji isti nalaz (isti user_id, game_id, ply) dva puta.
   Treba da vidiš: Drugi upis ne dodaje novi red.
   Potrebno: server.

27. [ ] **GET /games/openings/leaks vraća nalaze.** [53.1]
   O čemu se radi: Izveštaj o otvaranjima je prva analiza koja se oslanja na
   uvezenu arhivu partija.
   Gde: (GET /games/openings/leaks?subject=...).
   Uradi: Pozovi rutu za nalog sa uvezenom arhivom partija.
   Treba da vidiš: Vraćaju se označene pozicije sa brojem partija i
   prolaznošću; ako je prazno a partija je mnogo, proveri gamesWithoutNodes
   umesto da zaključiš da nema slabosti.
   Potrebno: server; uvezene partije.

28. [ ] **gamesWithoutNodes pada na nulu posle dopune.** [53.2]
   O čemu se radi: Starije partije uvezene pre nego što je uveden zapis čvorova
   otvaranja moraju moći da se dopune naknadno.
   Gde: (GET /games/openings/leaks, POST /games/openings/backfill).
   Uradi: Za starije partije pozovi POST /games/openings/backfill, pa proveri
   ponovo.
   Treba da vidiš: Posle svežeg uvoza je već 0; za starije partije padne na 0
   tek posle backfill-a.
   Potrebno: server; uvezene partije.

29. [ ] **&toPly=30 se odbija sa 400.** [53.3]
   O čemu se radi: Prozor izveštaja (koliko poteza unazad) ne sme moći da se
   proširi preko dozvoljene granice.
   Gde: (GET /games/openings/leaks?...&toPly=30).
   Uradi: Pozovi izveštaj sa &toPly=30 (van dozvoljenog prozora).
   Treba da vidiš: Odgovor je 400 sa objašnjenjem, ne kraći/tihi izveštaj.
   Potrebno: server.

30. [ ] **Brzina GROUP BY upita za izveštaj o otvaranjima.** [53.4]
   O čemu se radi: Prvi GROUP BY upit nad tabelom koja raste po korisniku —
   vredi znati koliko traje.
   Gde: (GET /games/openings/leaks na nalogu sa mnogo partija).
   Uradi: Izmeri koliko traje poziv za nalog sa desetinama hiljada redova
   partija.
   Treba da vidiš: Vreme odgovora je zabeleženo i prihvatljivo za korišćenje
   uživo.
   Potrebno: server; uvezene partije.

31. [ ] **Suđenje bez tokena ne obara izveštaj.** [53.5]
   O čemu se radi: Suđenje poteza je opcioni dodatak izveštaju i ne sme obarati
   osnovne brojeve kad nema tokena.
   Gde: (GET /games/openings/leaks?...&judge=true, bez X-Lichess-Token).
   Uradi: Pozovi izveštaj sa &judge=true bez zaglavlja X-Lichess-Token.
   Treba da vidiš: Vraćaju se brojevi kao inače, a judge.reason je no-token,
   bez greške.
   Potrebno: server.

32. [ ] **Suđenje sa tokenom šalje tačan broj zahteva.** [53.6]
   O čemu se radi: Suđenje sa Lichess tokenom troši korisnikov token, pa broj
   zahteva mora odgovarati očekivanom.
   Gde: (GET /games/openings/leaks?...&judge=true, sa X-Lichess-Token).
   Uradi: Pozovi izveštaj sa tokenom i izbroj koliko zahteva ode ka Lichess-u.
   Treba da vidiš: Broj zahteva odgovara očekivanom; pozicije koje Lichess ne
   oceni ostaju unknown.
   Potrebno: server; internet.

33. [ ] **Otpremanje PGN fajla kroz pravi multipart upload.** [52.0]
   O čemu se radi: Glavni put uvoza je POST /games/import/file; van HTTP-a je
   izmereno 40s/209MB za 4126 partija, ali ne i ponašanje kroz pravi multipart
   upload niti da li se privremeni fajl zaista obriše kad uvoz završi.
   Gde: (POST /games/import/file, curl/Postman).
   Uradi: Pošalji veći PGN fajl kroz POST /games/import/file, prati memoriju
   servera dok traje, a posle završetka proveri da privremeni fajl više ne
   postoji na disku.
   Treba da vidiš: Uvoz prođe bez pada procesa, a privremeni fajl nestaje čim
   run završi.
   Potrebno: server; server; PGN fajl.

34. [ ] **POST /games/import vrati 202 i importId odmah.** [52.1]
   O čemu se radi: Uvoz treba da bude pozadinski posao — ruta koja ga pokreće
   ne sme da čeka da se završi da bi odgovorila.
   Gde: (POST /games/import, curl/Postman).
   Uradi: Pozovi rutu i meri koliko brzo stiže odgovor.
   Treba da vidiš: Odgovor 202 sa importId stiže odmah, ne tek kad se ceo uvoz
   završi.
   Potrebno: server; server; PGN fajl.

35. [ ] **Ceo uvoz se upiše, brojevi se slažu.** [52.2]
   O čemu se radi: Osnovna ispravnost uvoza — svaka pročitana partija mora biti
   ili upisana, ili duplirana, ili preskočena, bez ostatka.
   Gde: (GET /games/imports/:id).
   Uradi: Sačekaj da se uvoz veće arhive završi, pa pozovi GET
   /games/imports/:id.
   Treba da vidiš: status je done i games_read = games_stored + games_duplicate
   + games_skipped, bez neobjašnjenih preskočenih partija.
   Potrebno: server; server; PGN fajl.

36. [ ] **Drugi uvoz odmah zatim povuče skoro ništa.** [52.3]
   O čemu se radi: Ponovljeni uvoz istog naloga treba da povuče samo ono što je
   novo (since radi).
   Gde: (POST /games/import ponovljen odmah posle prvog).
   Uradi: Odmah posle uspešnog uvoza pokreni isti uvoz ponovo za isti nalog.
   Treba da vidiš: games_read je mali, games_duplicate je najviše 1,
   games_stored je 0 ako se ništa nije igralo u međuvremenu.
   Potrebno: server; server; PGN fajl.

37. [ ] **Uvoz tokom uvoza vrati 409.** [52.4]
   O čemu se radi: Dva uvoza istog naloga ne smeju raditi paralelno nad istim
   tokom.
   Gde: (POST /games/import pozvan dvaput istovremeno).
   Uradi: Pokreni uvoz veće arhive, pa dok traje pokreni isti uvoz ponovo za
   isti nalog.
   Treba da vidiš: Drugi poziv vrati 409, prvi nastavlja neometano.
   Potrebno: server; server; PGN fajl.

38. [ ] **Uvoz za nepostojeći nalog vrati 404 sa imenom naloga.** [52.5]
   O čemu se radi: Uvoz za nalog koji ne postoji na Lichess-u treba da se jasno
   odbije umesto da tiho ne uradi ništa.
   Gde: (POST /games/import sa nepostojećim korisničkim imenom).
   Uradi: Pozovi uvoz sa Lichess korisničkim imenom koje sigurno ne postoji.
   Treba da vidiš: Odgovor je 404 sa porukom koja imenuje traženi nalog, a run
   ostaje failed sa tim razlogom upisanim.
   Potrebno: server; server.

39. [ ] **Sat i otvaranje su stvarno upisani u redovima.** [52.6]
   O čemu se radi: Kolone o satu i otvaranju treba da budu stvarno popunjene
   posle uvoza, ne prazne.
   Gde: (GET /games/stats).
   Uradi: Posle uvoza veće, novije arhive pozovi GET /games/stats.
   Treba da vidiš: with_clocks je blizu ukupnog broja partija, a
   reached_tablebase nije nula.
   Potrebno: server; server; uvezene partije.

40. [ ] **Server ostaje odazivan dok uvoz traje.** [52.7]
   O čemu se radi: Uvoz je pozadinski posao u istom procesu kao i ostatak
   servera — ne sme ga usporiti.
   Gde: (druga sesija/soba dok uvoz radi u pozadini).
   Uradi: Pokreni uvoz veće arhive i za to vreme koristi aplikaciju iz drugog
   naloga (otvori sobu, klikni po tabli).
   Treba da vidiš: Ostatak aplikacije ostaje odazivan dok uvoz radi u pozadini.
   Potrebno: server; server; uvezene partije.

41. [ ] **Koliko user_games zauzima posle uvoza.** [52.8]
   O čemu se radi: Tabela sa partijama raste sa korisnikovom istorijom, ne sa
   njegovim radom u aplikaciji, pa je vredno znati red veličine.
   Gde: (SQL upit na serveru).
   Uradi: Posle uvoza veće arhive izmeri veličinu tabele user_games na serveru
   koji radi.
   Treba da vidiš: Veličina je zabeležena i razumna u odnosu na broj partija —
   prva tabela koja raste sa korisnikovom istorijom, ne sa radom u aplikaciji.
   Potrebno: server; server; uvezene partije.

### Server i alati — Nalozi, sobe i saglasnost

1. [ ] **Oduzeta admin uloga važi bez ponovne prijave.** [38.b1290]
   O čemu se radi: Uloga zapisana u prijavi je ona iz trenutka prijave. Server
   na svaki zahtev čita pravu ulogu iz baze, pa oduzimanje admin prava deluje
   odmah, bez ponovne prijave.
   Gde: (bez ekrana aplikacije — proverava se direktno API pozivima).
   Uradi: Prijavi se admin nalogom i pozovi neku admin rutu da potvrdiš da
   prolazi; zatim na serveru izvrši UPDATE users SET role = korisnik za taj
   nalog, bez odjave iz aplikacije, pa istim tokenom ponovo pozovi istu admin
   rutu.
   Treba da vidiš: Prvi poziv prolazi; drugi (posle promene uloge u bazi) biva
   odbijen.
   Potrebno: server; server.

2. [ ] **Neispravan PUBLIC_BASE_URL/PARENT_CONSENT_VERSION sprečava
   pokretanje.** [36.b1137]
   O čemu se radi: PUBLIC_BASE_URL i PARENT_CONSENT_VERSION se proveravaju pri
   pokretanju servera; neispravna vrednost mora da spreči start uz jasnu
   poruku, ne da tiho padne u pogrešno stanje.
   Gde: (pri pokretanju backenda).
   Uradi: Postaviti PUBLIC_BASE_URL=primer.rs (bez šeme) u chess_backend/.env i
   pokrenuti backend; zatim probati PARENT_CONSENT_VERSION sa razmakom u sebi.
   Treba da vidiš: Server se ne pokreće, uz jasnu poruku u dnevniku za svaki od
   dva slučaja. Vratiti ispravne vrednosti.
   Potrebno: server; server.

3. [ ] **AGE_OF_CONSENT van 13-18 sprečava pokretanje servera.** [33.b1048]
   O čemu se radi: Prag godina se čita iz .env pri pokretanju i mora biti ceo
   broj između 13 i 18; van tog opsega server odbija da krene.
   Gde: (pri pokretanju backenda).
   Uradi: Postaviti AGE_OF_CONSENT=20 u chess_backend/.env i pokrenuti backend.
   Treba da vidiš: Server se ne pokreće, uz jasnu poruku u dnevniku (počinje sa
   „FATAL: AGE_OF_CONSENT must be a whole number between 13 and 18"). Vratiti
   na 16 posle provere.
   Potrebno: server; server.

4. [ ] **Poziv osobi bez prihvaćene veze se odbija (403).** [33.b1062]
   O čemu se radi: POST /invitations/send danas zahteva i da je pošiljalac
   trener žive sobe i da je meta prihvaćen učenik; ekran za pozivanje uopšte i
   ne nudi nalog bez prihvaćene veze, pa se odbijanje proverava direktnim
   pozivom rute.
   Gde: (proverava se direktnim pozivom rute, ne kroz ekran za pozivanje).
   Uradi: Sa otvorenom živom sobom, pozvati (curl/Postman) POST
   /invitations/send za nalog koji nije u prihvaćenoj vezi sa tim trenerom.
   Treba da vidiš: Odgovor je 403, i tom nalogu ne stiže obaveštenje u
   zvoncetu.
   Potrebno: server; nalog trenera i učenika; server.

5. [ ] **Log ispisuje razlog za svaki odbijeni ulazak u sobu.** [31.b962]
   O čemu se radi: Kad socket veza pokuša da uđe u sobu bez prava, server to
   upisuje u dnevnik sa razlogom. Put preko kucanja pogrešnog koda je ukinut,
   pa se danas proverava direktnim pokušajem konekcije (npr. socket.io
   test-klijentom) sa kodom sobe koji nalog nema pravo da koristi.
   Gde: (proverava se u dnevniku backenda, ne u aplikaciji).
   Uradi: Sa nalogom koji nema pravo pristupa nekoj sobi, pokušati socket.io
   konekciju na taj room-kod (malim test-skriptom) i pogledati dnevnik servera.
   Treba da vidiš: U dnevniku stoji red koji počinje sa
   `[SOBA] Odbijen ulazak`, sa razlogom.
   Potrebno: server; server.

6. [ ] **Odbijeni nalog ne ulazi ni u glas.** [31.b964]
   O čemu se radi: Isto pravilo za glasovni kanal: nalog bez prava ne može da
   uđe u audio, ni preko table ni direktnim pokušajem.
   Gde: (proverava se direktnim pokušajem konekcije, ne kroz aplikaciju).
   Uradi: Sa istim neovlašćenim nalogom pokušati i audio (Agora) konekciju za
   tu sobu.
   Treba da vidiš: Pristup je odbijen i za audio kanal, sa redom koji počinje
   sa `[AUDIO] Odbijen ulazak` u dnevniku.
   Potrebno: server; server.
