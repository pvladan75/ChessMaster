# Politika privatnosti — Chess Master

> **NACRT ZA PRAVNU PROVERU.** Ovaj dokument je sastavljen na osnovu onoga što
> aplikacija stvarno prikuplja, prema pregledu izvornog koda i šeme baze. Nije
> pravni savet. Pre objavljivanja mora ga proveriti advokat, posebno delove koji
> se tiču maloletnika i prenosa podataka van Srbije.
>
> Popunite pre objave: `[IME I PREZIME / NAZIV]`, `[ADRESA]`, `[EMAIL ZA
> PRIVATNOST]`, `[DATUM]`, `[URL]`.

**Poslednja izmena:** [DATUM]

## 1. Ko obrađuje vaše podatke

Rukovalac podacima je `[IME I PREZIME / NAZIV]`, `[ADRESA]`, Republika Srbija.

Kontakt za sva pitanja o privatnosti i za ostvarivanje prava iz ove politike:
`[EMAIL ZA PRIVATNOST]`.

## 2. Na koga se ova politika odnosi

Chess Master je aplikacija za šahovsku obuku. Koriste je **treneri** i
**učenici**, a značajan deo učenika su **deca**. Ako imate manje od 15 godina,
nalog sme da bude otvoren samo uz saglasnost roditelja ili staratelja — vidi
odeljak 8.

## 3. Koje podatke prikupljamo

### 3.1 Podaci koje unosite sami

| Podatak | Zašto ga imamo |
|---|---|
| Email adresa | Prijava na nalog, verifikacioni kod, obaveštenja o časovima |
| Ime | Prikaz drugim učesnicima časa i vašem treneru |
| Lozinka | Čuva se isključivo kao bcrypt heš — originalnu lozinku ne možemo pročitati |
| Naslovi i opisi lekcija, komentari uz poteze | Sadržaj koji sami kreirate |

Ako se prijavljujete preko Google naloga, od Google-a dobijamo samo **email
adresu i ime**. Ne dobijamo vašu Google lozinku niti pristup ostalim Google
uslugama.

### 3.2 Podaci koji nastaju korišćenjem

| Podatak | Zašto ga imamo |
|---|---|
| Odigrani potezi, pozicije, strelice i oznake na tabli | Rad na času i kasniji pregled |
| Rejting po taktičkim temama, broj rešenih i promašenih zagonetki, vreme rešavanja | Prilagođavanje težine i izveštaj o napretku |
| Zadaci koje vam je trener zadao i rezultati po zadatku | Praćenje domaćih zadataka |
| Potez koji ste odigrali na svakoj poziciji iz zadatka | Da trener vidi *šta* ste probali, a ne samo da li je tačno |
| Poruke koje vi i vaš trener pišete uz zadatak ili uz pojedinačnu poziciju | Povratna informacija o domaćem zadatku |
| Lista prijatelja i veza trener–učenik | Pozivanje na časove i deljenje lekcija |
| Zakazani termini i obaveštenja | Podsetnici na čas |

### 3.3 Snimci časova

Ako trener uključi snimanje, čuvamo:

- **zvučni zapis časa**, uključujući glasove svih učesnika,
- vremenski tok poteza, pozicija i oznaka na tabli,
- listu učesnika,
- izrenderovani video zapis, ako ga trener napravi.

**Snimanje uvek pokreće trener i o njemu morate biti obavešteni pre početka.**
Snimak je vidljiv treneru koji ga je napravio i učesnicima tog časa.

### 3.4 Podaci o plaćanju

Pretplate se naplaćuju preko **Google Play-a**. Google je prodavac i on obrađuje
vaše podatke o plaćanju — **mi ne vidimo i ne čuvamo broj kartice niti bilo koji
platni podatak**. Od Google-a dobijamo samo identifikator kupovine, naziv
proizvoda, status pretplate i datum isteka.

### 3.5 Podaci o potrošnji resursa

Beležimo zbirno, po nalogu i po mesecu: broj sekundi glasovne komunikacije, broj
izrenderovanih video zapisa i broj zatraženih AI komentara. Ovo koristimo
isključivo da bismo znali koliko nas usluga košta i da bismo sprečili zloupotrebu.

## 4. Šta **ne** radimo

- Ne prodajemo vaše podatke.
- Ne koristimo ih za reklamiranje niti ih ustupamo oglašivačima.
- Ne pravimo profile za marketinške svrhe.
- Ne šaljemo vaše ime, email niti bilo koji lični podatak servisu veštačke
  inteligencije (vidi 5.2).

## 5. Kome se podaci prosleđuju

Koristimo sledeće pružaoce usluga. Svaki dobija samo ono što mu je neophodno.

### 5.1 Agora (glasovna komunikacija)

Prenosi zvuk uživo tokom časa. Agora obrađuje audio tok i tehničke podatke o
vezi. Prenos se odvija van Srbije.

### 5.2 Google Gemini (AI objašnjenja poteza)

Kada zatražite AI komentar, šaljemo **samo šahovske podatke**: poziciju (FEN),
evaluaciju motora, oznaku poteza i unapred izračunate taktičke i pozicione
nalaze. **Ne šaljemo vaše ime, email, identifikator naloga niti bilo koji drugi
lični podatak** — Google iz tog zahteva ne može da zaključi ko ste.

### 5.3 Google Play (naplata) i Google prijava

Vidi 3.4. Google prijava koristi se samo za potvrdu identiteta.

### 5.4 Lichess i servisi za šahovsku evaluaciju

Radi analize pozicije šaljemo **samo poziciju (FEN)**, bez ikakvog podatka o
korisniku.

### 5.5 Hosting i email

Podaci se čuvaju na serverima `[NAZIV HOSTING PROVAJDERA, npr. DigitalOcean]` u
`[REGION]`. Verifikacione poruke šalju se preko `[SMTP PROVAJDER]`.

## 6. Koliko dugo čuvamo podatke

| Podatak | Rok |
|---|---|
| Podaci o nalogu | Dok nalog postoji |
| Snimci časova i video zapisi | `[npr. 12 meseci]` od nastanka, ili do brisanja od strane trenera |
| Rezultati zagonetki i zadataka | Dok nalog postoji — čine istoriju napretka |
| Poruke uz zadatke | Dok zadatak postoji; brisanjem zadatka nestaju i one |
| Podaci o pretplati | Koliko nalažu poreski propisi |
| Zbirni podaci o potrošnji resursa | `[npr. 24 meseca]` |

**Brisanjem naloga trajno se brišu i svi vezani podaci** — lekcije, snimci,
rezultati i zadaci. Ova radnja se ne može poništiti.

## 7. Vaša prava

Imate pravo da: pristupite svojim podacima, tražite ispravku netačnih podataka,
tražite brisanje, ograničite obradu, prigovorite obradi i prenesete podatke
drugom rukovaocu.

Zahtev šaljete na `[EMAIL ZA PRIVATNOST]`. Odgovaramo u roku od 30 dana.

Ako smatrate da su vam prava povređena, možete se obratiti **Povereniku za
informacije od javnog značaja i zaštitu podataka o ličnosti** Republike Srbije.

## 8. Deca

Značajan deo naših korisnika su deca. Zato:

- Nalog za dete mlađe od 15 godina sme se otvoriti **samo uz saglasnost
  roditelja ili staratelja**.
- **Snimanje časa na kome učestvuje dete zahteva prethodnu saglasnost roditelja.**
  Trener je dužan da tu saglasnost pribavi pre snimanja.
- Roditelj u svakom trenutku može da traži uvid u podatke deteta, njihovo
  brisanje ili brisanje pojedinačnog snimka, pisanjem na `[EMAIL ZA PRIVATNOST]`.
- Ne prikazujemo deci reklame i ne koristimo njihove podatke ni za šta osim za
  obuku i izveštaj njihovom treneru i roditelju.

Obrazac saglasnosti nalazi se na `[URL]/saglasnost-roditelja`.

## 9. Bezbednost

Lozinke se čuvaju kao bcrypt heš. Komunikacija sa serverom ide preko HTTPS-a.
Pristup podacima učenika ima **samo trener sa kojim je učenik povezan** — nijedan
drugi trener ne može da vidi tuđe učenike.

Nijedna mera nije apsolutna. U slučaju povrede podataka koja može da ugrozi vaša
prava, obavestićemo vas i Poverenika u skladu sa zakonom.

## 10. Izmene

Ako izmenimo ovu politiku, novu verziju objavljujemo na `[URL]` i menjamo datum
na vrhu. O značajnim izmenama obaveštavamo vas emailom.

## 11. Kontakt

`[IME I PREZIME / NAZIV]`
`[ADRESA]`
`[EMAIL ZA PRIVATNOST]`
