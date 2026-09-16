# Specifikacija: Interaktivni Trenažer Repertoara Otvaranja

Koncept trenažera bazira se na **frontalnom učenju repertoara po širini (Breadth-First Discovery)** kroz metodu pokušaja i grešaka (*Trial & Error*), uz podršku **Lichess Opening Explorer API-ja** i **Stockfish engine-a**.

---

## 1. Osnovna Filozofija Učenja

* **Učenje kroz otkrivanje:** Umesto pasivnog memorisanja gotovih stabala, korisnik sam povlači potez koji mu deluje prirodno.
* **Frontalni napredak (Talasi dubine):** Grane repertoara se razvijaju ravnomerno. Pre nego što se pređe na dublje poteze, pokrivaju se svi glavni odgovori protivnika na trenutnom nivou.
* **Višestruki odgovori (Multi-Candidate Moves):** Za istu poziciju korisnik može registrovati više validnih linija (npr. i `3...Bf5` i `3...c5` u Karo-Kanu).

---

## 2. Hibridni Validacioni Filter (Lichess API + Stockfish)

Svaki potez koji korisnik predloži prolazi kroz troslojnu proveru kako bi se izbegle mane oslanjanja na samo jedan izvor:


```

```
              [ Korisnik odigra potez ]
                          │
   ┌──────────────────────┴──────────────────────┐
   ▼                                             ▼

```

1. Lichess Masters Baza                       2. Lichess Baza (1800+)
(Poznat teorijski potez)                      (Popularan odgovor)
│                                             │
DA ──► 🟢 GLAVNA TEORIJA                      DA ──► Provera Stockfish-om
│
▼
Eval >= -0.40 pešaka?
├── DA ──► 🔵 PRAKTIČNA ALTERNATIVA
└── NE ──► 🔴 GREŠKA / ZAMKA

```

### Kategorije povratne informacije:
* 🟢 **Glavna teorija (Masters baza):** Potez ima stabilnu statistiku među velemajstorima. Potez se automatski upisuje u repertoar.
* 🔵 **Praktična alternativa (Engine + Amateri):** Nije u vrhu popularnosti kod majstora, ali je poziciono potpuno zdravo i igrivo. Korisnik dobija opciju da ga uvrsti u svoj repertoar.
* 🔴 **Sumnjiv potez / Greška:** Potez kvari poziciju ili upada u taktički problem. Engine vraća tablu nazad uz kratko objašnjenje zašto ideja ne radi.

---

## 3. Struktura Podataka Repertoara (Graph Model)

Repertoar se u lokalnoj bazi čuva kao usmereni graf povezivanjem FEN pozicija:

```json
{
  "opening_id": "caro_kann_black",
  "opening_name": "Caro-Kann Defence",
  "nodes": [
    {
      "fen": "rnbqkbnr/pp2pppp/2p5/3pP3/3P4/8/PPP2PPP/RNBQKBNR b KQkq - 0 3",
      "variation_name": "Advance Variation (3.e5)",
      "depth": 3,
      "accepted_moves": [
        {
          "san": "Bf5",
          "type": "mainline",
          "source": "masters",
          "note": "Klasični odgovor, razvoj lovca van pešačkog lanca."
        },
        {
          "san": "c5",
          "type": "alternative",
          "source": "engine_viable",
          "note": "Arkell-Khenkin linija, direktan udar na pešački centar."
        }
      ]
    }
  ]
}

```

---

## 4. Režimi Rada u Aplikaciji

### A. Režim Izgradnje (Discovery / Build Mode)

* Aplikacija igra poteze protivnika redom po popularnosti.
* Korisnik pogađa potez. Ako pogodi, otključava sledeću granu.
* Mogućnost dodavanja alternativnih odgovora pre prelaska na sledeći talas.

### B. Režim Uvežbavanja (Spaced Repetition Drill)

* Sistem nasumično servira pozicije iz svih istraženih grana.
* Potezi protivnika biraju se proporcionalno učestalosti u bazi.
* Greške se automatski beleže i češće vraćaju u narednim sesijama pomoću intervalnog ponavljanja (SRS / SM-2).

### C. Vizuelna Mapa Pokrivenosti (Coverage Radar)

* Prikaz napretka po granama (npr. *Advance: 5. potez*, *Exchange: 4. potez*, *Two Knights: Nije istraženo*).
* Jasna vizuelna metrika koliko je repertoar kompletan do željene dubine.

```

```