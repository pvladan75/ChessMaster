# The replacement table — phase 4 of the simplicity plan

Draft, 3.9.2026. **The wording needs the owner's sign-off before the batch is
briefed**, because these are the sentences Serbian children read; everything
else here is settled.

This file is the contract for phase 4 and it is read twice: by the brief, and
by the `strings` gate, which now takes it as a table of decided replacements
(`allow_rewritten`) instead of failing every edit. The gate checks that each
`old` is gone, each `new` is present, and **nothing else in those files
changed** — so a wording invented by the worker fails, and so does an entry it
skipped.

## What the scan found

| | |
|---|---|
| 36 | literals the gate can see, listed below |
| 3 | literals **nested inside an interpolation**, which the gate cannot see |
| 2 | false positives that must not be touched |

**The two false positives are the reason this is a table and not a rule.**

* `chess_game_screen.dart:3231` — `'Nacrtaj strelicu'`. Matches the stem
  `nacrt`; means *draw an arrow*. A mechanical sweep renames a board control.
* `opening_judge_service.dart:403` — `'pokriveno ${...}%'` inside an
  `AppLogger.log`. Not user-facing at all.

**The three the gate cannot see** are all in `repertoire_coverage_screen.dart`,
inside `${... ? "..." : ""}` interpolations. `scan_strings` walks into an
interpolation to keep quotes paired and does **not** record the strings it finds
there, so these can change with the gate saying nothing. They are listed in
their own section and have to be checked by eye — or by the grep in the brief.

While reading them I found a latent defect, not part of this batch:
`repertoire_build_screen.dart:1965` has
`${below.length == 1 ? "pozicija" : "pozicija"}` — both arms identical, so a
plural somebody meant to write never happens. Serbian wants *pozicija* for 1,
*pozicije* for 2–4, *pozicija* for 5+. It has never been visible to the gate for
exactly the reason above.

## The table — what the gate will enforce

### `repertoire_build_screen.dart`

| old | new |
|---|---|
| `Napravi kičmu` | `Predloži glavnu liniju` |
| `Pravim kičmu — ovo troši $ident do ${...} upita.` | `Predlažem glavnu liniju — ovo troši $ident do ${...} upita.` |
| `Kičma nije napravljena.` | `Glavna linija nije predložena.` |
| `$ident$ident Kičma: $ident Potvrdite ono sa čim se slažete.` | `$ident$ident Glavna linija: $ident Potvrdite ono sa čim se slažete.` |
| `Pregledaj nacrt` | `Pregledaj nepotvrđene` |
| `Pregledaj nacrt (${...})` | `Pregledaj nepotvrđene (${...})` |
| `Nacrti nisu mogli da se pročitaju.` | `Nepotvrđeni potezi nisu mogli da se pročitaju.` |
| `Ispod tog nacrta su ${...} vaše odluke. Obrisati i njih?` | `Ispod tog predloga su ${...} vaše odluke. Obrisati i njih?` |
| `nacrt ${...}` | `nepotvrđeno ${...}` |
| `nepotvrđenih nacrta.` | `nepotvrđenih poteza.` |
| `Grana posle ${...} je odsečena — više je nema u crtežu.` | `Granu posle ${...} više ne spremam — nema je u crtežu.` |
| `Grana je odsečena. Neće se više javljati.` | `Ovu granu više ne spremam. Neće se javljati.` |
| `Grana je odsečena — sa njom je iz reda izašlo još` | `Ovu granu više ne spremam — s njom je otpalo još` |
| `Grana nije odsečena — server nije odgovorio.` | `Grana je ostala — server nije odgovorio.` |
| `odsečeno $ident${...}` | `ne spremam $ident${...}` |
| `✂ odsečeno · ${...} partija` | `✂ ne spremam · ${...} partija` |
| `Vidi odsečeno` | `Vidi šta ne spremam` |
| `Vrati odsečenu granu` | `Ipak spremi ovu granu` |
| `Nijedan odgovor nije stigao — pozicija ostaje nepokrivena.` | `Nijedan odgovor nije stigao — pozicija ostaje bez vašeg odgovora.` |
| `Pokriveno $ident% onoga što ćete sresti;` | `Spremno je $ident% onoga što ćete sresti;` |

`Grana je odsečena — sa njom je iz reda izašlo još` also retires **red**, which
the glossary removed in phase 3 and which survived here.

### `repertoire_coverage_screen.dart`

| old | new |
|---|---|
| `Pokrivenost — ${...}` | `Rupe u repertoaru — ${...}` |
| `odsečeno` | `ne spremam` |

### `repertoire_drill_screen.dart`

| old | new |
|---|---|
| `Pregledaj nacrt` | `Pregledaj nepotvrđene` |
| `Nacrti nisu mogli da se pročitaju.` | `Nepotvrđeni potezi nisu mogli da se pročitaju.` |
| `Još $ident nepotvrđenih nacrta čeka u ovom repertoaru.` | `Još $ident nepotvrđenih poteza čeka u ovom repertoaru.` |
| `Ova grana je odsečena ili u njoj još nema vaših` | `Ovu granu ne spremam ili u njoj još nema vaših` |

### `repertoire_list_screen.dart`

| old | new |
|---|---|
| `Pokrivenost` | `Rupe u repertoaru` |
| `Idu i odsečene grane, dodati odgovori, raspored za` | `Idu i grane koje ne spremate, dodati odgovori, raspored za` |
| `\nIdu i odsečene grane, dodati odgovori,` | `\nIdu i grane koje ne spremate, dodati odgovori,` |

### `breadth_dialog.dart`

| old | new |
|---|---|
| `Napravi kičmu odavde` | `Predloži glavnu liniju odavde` |
| `Širina` | `Koliko odgovora spremamo` |

### `repertoire_tree_panel.dart`

| old | new |
|---|---|
| `Širina: ${...}` | `Koliko odgovora: ${...}` |
| `Prikaži odsečene grane ($ident)` | `Prikaži grane koje ne spremam ($ident)` |
| `Sakrij odsečene grane ($ident)` | `Sakrij grane koje ne spremam ($ident)` |
| `✂ odsečena grana. Broj u zagradi je ocena motora — dubina i datum` | `✂ grana koju ne spremam. Broj u zagradi je ocena motora — dubina i datum` |

### `unconfirmed_banner.dart`

| old | new |
|---|---|
| `Pregledaj nacrt` | `Pregledaj nepotvrđene` |

## The three the gate cannot see

All in `repertoire_coverage_screen.dart`, all inside an interpolation. The brief
names them by line and the batch is checked on them by hand.

| line | old | new |
|---|---|---|
| 250 | `", odsečeno $cut%"` | `", ne spremam $cut%"` |
| 317 | `" · odsečeno ${_percent(branch.prunedWithin)}"` | `" · ne spremam ${_percent(branch.prunedWithin)}"` |
| 326 | `" · ${branch.pruned} odsečeno"` | `" · ${branch.pruned} ne spremam"` |

## Two wordings worth arguing about before this is signed off

* **`Vrati odsečenu granu` → `Ipak spremi ovu granu`.** The obvious swap is
  „Vrati granu u pripremu", but *priprema* is a new noun for a thing the reader
  has no other name for — the glossary's whole point is fewer nouns, not
  different ones. „Ipak spremi" uses the verb the rest of the sweep introduces
  and says what the button does.
* **`Pokriveno $ident%` → `Spremno je $ident%`.** The retired word here is a
  label, not this sentence, and the sentence is one of the good ones. It is
  swept anyway so that *pokriven-* stops appearing at all; if you would rather
  keep it, that is one line out of the table and nothing else changes.

## Still to write, after the wording is signed off

1. The 23 test assertions, rewritten by the lead on the batch branch — the
   suite goes red there, `master` stays green, and the worker's pass condition
   becomes "make it green without touching a test".
2. `TASK-recnik.md` and `brief-recnik-2026-09.md`.
3. The `BATCH_ALLOWANCES` entry: `rewritten` pointing at this table, generated
   from it rather than retyped.
