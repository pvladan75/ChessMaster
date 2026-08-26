# Saglasnost roditelja — Chess Master

> **PREVAZIĐENO 26.8.2026.** Obavezujući tekst je stranica koju server prikazuje
> roditelju (`routes/consent.js`), a objašnjenje uz nju je
> `site/saglasnost-roditelja.html`. Ovaj fajl je ostao kao nacrt iz kog su oni
> nastali i **ne sme se koristiti kao obrazac** — dva teksta o istoj stvari se
> razilaze, a ovaj nema verziju koja se beleži uz saglasnost.
>
> Zadržan je zbog obrazloženja u drugoj polovini. Sadržaj je usklađen sa novim
> pravilom da se čas ne snima.
>
> Popunite: `[IME I PREZIME / NAZIV]`, `[EMAIL ZA PRIVATNOST]`, `[URL]`.

## Zašto je ovo potrebno

Dete ima nalog u aplikaciji, a trener vidi njegov napredak — rezultate zadataka,
tačnost i teme na kojima greši. To su lični podaci maloletnika, pa je za njih
potrebna saglasnost roditelja ili staratelja.

**Čas se ne snima.** Glas deteta se ne beleži ni u jednom slučaju — takva
mogućnost u aplikaciji ne postoji, pa ni saglasnost za nju nema šta da pokrije.
Zvuk može da snimi samo punoletan korisnik koji je **sam u sobi**.

Ovaj obrazac popunjava roditelj jednom, pre prvog časa.

---

## Obrazac

**Podaci o detetu**

- Ime i prezime deteta: ______________________________
- Godište: ______________
- Email adresa naloga deteta: ______________________________

**Podaci o roditelju / staratelju**

- Ime i prezime: ______________________________
- Kontakt email: ______________________________
- Kontakt telefon: ______________________________

**Podaci o treneru**

- Ime i prezime trenera: ______________________________

---

### Na šta dajete saglasnost

Označite ono na šta pristajete. **Prve dve stavke su neophodne** da bi dete
uopšte moglo da koristi aplikaciju. Treća je opciona i možete je odbiti, a da
dete i dalje pohađa časove.

- [ ] **1. Otvaranje naloga.** Saglasan/na sam da moje dete ima nalog u
      aplikaciji Chess Master i da se u njemu čuvaju: email adresa, ime,
      odigrani potezi, rezultati zagonetki i zadataka, i rejting po šahovskim
      temama.

- [ ] **2. Uvid trenera.** Saglasan/na sam da gore navedeni trener vidi napredak
      mog deteta — rezultate zadataka, tačnost i teme na kojima dete greši — i da
      mu na osnovu toga zadaje vežbe.

---

### Šta se **ne** radi

- Podaci deteta se **ne prodaju** i ne ustupaju oglašivačima.
- Detetu se **ne prikazuju reklame**.
- Snimci se **ne objavljuju** javno niti dele van kruga učesnika časa.
- Servisu veštačke inteligencije **ne šalje se nijedan lični podatak deteta** —
  samo šahovske pozicije.

---

### Vaša prava kao roditelja

U svakom trenutku možete, pisanjem na `[EMAIL ZA PRIVATNOST]`:

- tražiti uvid u sve podatke koji se čuvaju o vašem detetu,
- tražiti ispravku netačnih podataka,
- **povući ovu saglasnost**, čime prestaje i veza sa trenerom,
- tražiti **brisanje celog naloga** i svih vezanih podataka.

Povlačenje saglasnosti ne utiče na zakonitost obrade obavljene do tog trenutka.

Puna politika privatnosti: `[URL]/politika-privatnosti`

---

**Datum:** ______________

**Potpis roditelja / staratelja:** ______________________________

---

## Napomena za trenera

Saglasnost pribavljate **pre prvog snimljenog časa**, ne posle. Čuvate je kod
sebe i na zahtev je pokazujete. Ako roditelj nije označio stavku 3, **taj čas ne
smete snimati** — ni „samo ovaj put”.

Ako na času učestvuje više dece, saglasnost je potrebna za svako od njih.

## Napomena o tehničkoj primeni

Ovaj obrazac je trenutno papirni/PDF proces koji vodi trener. Ako se pokaže da je
to usko grlo, sledeći korak je da se saglasnost unese u samu aplikaciju:

- polje `parental_consent` na nalogu učenika, sa datumom i identifikatorom
  roditelja koji je potvrdio,
- provera pri pokretanju snimanja: zvuk se snima samo dok je korisnik **sam u
  sobi** i punoletan, a server ga odbija i zaustavlja čim uđe još neko.

Druga stavka je važnija od prve — ona pretvara pravilo iz obećanja u nešto što
sistem stvarno sprovodi. Ta rečenica je 25.8.2026. bila tačna i neispunjena:
kolona `parent_allows_recording` je bila upisivana i nikad čitana. Ishod
26.8.2026. nije bio da se pravilo bolje sprovede, nego da nestane ono što je
trebalo sprovoditi — čas se više ne snima uopšte.
