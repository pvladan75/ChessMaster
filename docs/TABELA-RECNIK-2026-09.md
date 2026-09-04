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

**Reconciled with master on 4.9.2026, and it moved.** Six live findings were
fixed that day on these same screens, so the table was re-checked against the
sources with the gate's own `scan_strings` before anything was briefed. It found
two things:

* **Five of the thirty-six keys had lost a trailing space** in transcription —
  `…onoga što ćete sresti;` for `…onoga što ćete sresti; ` and four more. The
  gate compares byte for byte, so all five would have failed the run and read as
  „the worker skipped these". Fixed here, not in the brief.
* **Seven new literals** carrying a retired word arrived with those fixes, and
  `Širina` in the dialog became `Širina repertoara`. All are in the table below.
  One more — „Posle ove u redu je još N pozicija." — put the retired *red*
  straight back and was rewritten in the app instead (`58722e2`), because a
  glossary decision undone by accident is not a sweep's job to catch.

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

While reading them I found a latent defect — **fixed 3.9.2026, before this
batch, in `b5e8073`**. It was not one site but three: `Dodato $added …`, the cut
branch's `… izašlo još …`, and the dashboard's `… pozicija čeka …` each carried
a ternary whose two arms were the same word, so an inflection somebody had meant
to write did nothing at all. `serbian_plural.dart` already existed, with three
forms and its own tests; none of the three called it. Two of the three sat
inside an interpolation, which is why nothing ever saw them.

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
| `Grana je odsečena — sa njom je iz reda $ident` | `Ovu granu više ne spremam — s njom je $ident` |
| `Grana nije odsečena — server nije odgovorio.` | `Grana je ostala — server nije odgovorio.` |
| `odsečeno $ident${...}` | `ne spremam $ident${...}` |
| `✂ odsečeno · ${...} partija` | `✂ ne spremam · ${...} partija` |
| `Vidi odsečeno` | `Vidi šta ne spremam` |
| `Vrati odsečenu granu` | `Ipak spremi ovu granu` |
| `Nijedan odgovor nije stigao — pozicija ostaje nepokrivena.` | `Nijedan odgovor nije stigao — pozicija ostaje bez vašeg odgovora.` |
| `Pokriveno $ident% onoga što ćete sresti; ` | `Spremno je $ident% onoga što ćete sresti; ` |
| `$ident Ova pozicija je van širine „${...}", pa je ` | `$ident Ova pozicija je izvan onoga što spremate („${...}"), pa je ` |
| `U ovom repertoaru nema nepotvrđenih poteza koje njegova širina ` | `U ovom repertoaru nema nepotvrđenih poteza koje ovoliko odgovora ` |
| `stablo ne crta — proširite širinu da biste videli šta je upisano.` | `stablo ne crta — spremajte više odgovora da biste videli šta je upisano.` |

`Grana je odsečena — sa njom je iz reda $ident` also retires **red**, which the
glossary removed in phase 3 and which survived here.

That key changed shape on 3.9.2026, when the plural bug below it was fixed: the
count and its noun moved into a local (`serbianCount`, three forms) so they
would be **top-level literals the gate can see** rather than one more string
nested in an interpolation. The three forms — `izašla još ${...} pozicija`,
`izašle …e`, `izašlo …a` — carry no retired word and are therefore not on this
table; they stay as they are.

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
| `Ova grana je odsečena ili u njoj još nema vaših ` | `Ovu granu ne spremam ili u njoj još nema vaših ` |
| `U ovom repertoaru nema nepotvrđenih poteza koje njegova širina ` | `U ovom repertoaru nema nepotvrđenih poteza koje ovoliko odgovora ` |

### `repertoire_list_screen.dart`

| old | new |
|---|---|
| `Pokrivenost` | `Rupe u repertoaru` |
| `Idu i odsečene grane, dodati odgovori, raspored za ` | `Idu i grane koje ne spremate, dodati odgovori, raspored za ` |
| `\nIdu i odsečene grane, dodati odgovori, ` | `\nIdu i grane koje ne spremate, dodati odgovori, ` |

### `breadth_dialog.dart`

| old | new |
|---|---|
| `Napravi kičmu odavde` | `Predloži glavnu liniju odavde` |
| `Širina repertoara` | `Koliko odgovora spremamo` |
| `Ovo je širina celog repertoara, ne širina kičme — kičma je ` | `Ovo važi za ceo repertoar, ne samo za ovu liniju — glavna linija je ` |
| `uvek jedna linija. Uža širina sakriva grane koje ste već ` | `uvek jedna linija. Manje odgovora skriva grane koje ste već ` |
| `nepoznata širina` | `nepoznato` |
| `Samo glavna linija` | `Samo glavni odgovor` |
| `Standardno (80%)` | `Uobičajeno (80%)` |

The last two are the glossary's own third column and were missing from this
table until 4.9.2026 — found by listing the test assertions the sweep breaks,
which is a better reader of a table than the table's author. They matter more
than they look: „Samo glavna linija" is the reason the owner read this dial as
the shape of the kičma rather than as how much of the opponent's book the whole
repertoire follows, which cost a live finding. „Široko (95%)" is unchanged.

`Napravi kičmu` in `repertoire_build_screen.dart` is the button that opens this
dialog; the two have to move together or the button and its dialog stop agreeing
about what they are for.

### `repertoire_tree_panel.dart`

| old | new |
|---|---|
| `Širina: ${...}` | `Koliko odgovora: ${...}` |
| `samo glavna linija` | `samo glavni odgovor` |
| `standardno 80%` | `uobičajeno 80%` |
| `Prikaži odsečene grane ($ident)` | `Prikaži grane koje ne spremam ($ident)` |
| `Sakrij odsečene grane ($ident)` | `Sakrij grane koje ne spremam ($ident)` |
| `✂ odsečena grana. Broj u zagradi je ocena motora — dubina i datum ` | `✂ grana koju ne spremam. Broj u zagradi je ocena motora — dubina i datum ` |

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
