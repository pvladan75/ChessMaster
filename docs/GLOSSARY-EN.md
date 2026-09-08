# The English glossary

The app goes English-only — the owner's decision on 8.9.2026, on the ground that
the market is global and the Serbian audience too small to carry the format.
There is no i18n layer and none is being added: the Serbian literals in `lib/`
are replaced in place.

**This file is the contract for that replacement.** It does not list the 1700
strings — those are prose and the sweep translates them. It fixes the words that
must never drift, because a word that means two things is what this project has
already paid for once, and the manual in Phase 4 of `docs/PLAN-ZAVRSNICA.md` is
written against exactly these terms.

## The distinction everything else hangs on

| | |
|---|---|
| **Tutorial** | The thing a trainer *writes*. A child walks it alone, at their own pace, whenever they like. Asynchronous. |
| **Session** | The thing a trainer *runs*. Trainer and student are in a room at the same time, on one board, with voice. Live. |

Serbian froze this pair on 6.9.2026 as **Tutorijal** and **Čas**, after one word
had meant both — so „Poziv na lekciju" (a room opening this minute) and „Zadaj
lekciju" (homework for Thursday) read to a child as the same event.
`tutorial_vocabulary_test.dart` is what has kept them apart since.

**„Session", not „Lesson", and the reason is not taste.** The code has already
spent the word *lesson* on the artefact: the table is `saved_lessons`, the wire
type is `LessonStep`, the child's screen is `LessonViewerScreen`, the service is
`LessonApiService`. If the interface called the *live* thing a Lesson, then
every bug report, every log line and every conversation would carry a word that
means one thing in the UI and the opposite in the code. „Session" costs nothing
and removes that.

The residue is honest and worth writing down once: **in code, `lesson` means
the tutorial.** That mismatch predates this decision — it exists in the Serbian
build too — and it is not being renamed, because renaming a database table and
a wire contract to improve a developer's reading is a migration, not a
translation.

`UserSession` is the login, and it is not user-facing. It is the only other
place the word appears and it never reaches a screen.

## The screens

| Serbian | English | What it is |
|---|---|---|
| Soba | **Room** | The live session, with a student in it |
| Priprema | **Preparation** | The same room alone, with your own library — your material |
| Analiza | **Analysis** | The engine, the opening database, the tree — one position |
| Studio za tutorijal | **Tutorial Studio** | Writing a tutorial, and the only „studio" there is |

„Preparation" over „My board" or „Workspace" for the reason „Priprema" won in
Serbian: it names the work rather than the furniture, and it is the word a
trainer already uses. „Prep" is fine in prose, never as a title.

## The parts of a tutorial

| Serbian | English | Note |
|---|---|---|
| Deo | **Part** | One entry of `position_list`. The model calls it a `TutorialSection` and the wire calls it a step; **Part** is the word a trainer reads, and the three are not being unified. |
| Takt | **Beat** | One stop on the line — a position, what is written on it, what is drawn on it. Already the model's word (`TutorialBeat`). |
| Tok | **Flow** | The timeline a tutorial is written on. Already the panel's word (`TutorialFlowPanel`). |
| Stablo | **Tree** | |
| Polazna pozicija | **Starting position** | |
| Zadatak za učenika | **Task** | What the child is asked. The field, not the tutorial. |
| Ponuđeni odgovori | **Answers** | |
| Samo prikaži / Traži potez na tabli / Traži odgovor iz liste | **Show / Find the move / Choose the answer** | The three kinds. The wire keeps `show`, `ask_move`, `ask_choice`. |

## The people, and what passes between them

| Serbian | English | Note |
|---|---|---|
| Trener | **Trainer** | Not „coach". The code says trainer everywhere, including `trainer_students`. |
| Učenik | **Student** | The child. „Student" in the relationship sense, not the university one. |
| Roditelj | **Parent** | |
| Saglasnost | **Consent** | The parent's, and the word the legal texts use. |
| Zadatak (domaći) | **Assignment** | Homework. Matches `assignments` on the wire. Distinct from **Task**, which is what one part asks. |
| Poziv | **Invitation** | |
| Grupa | **Group** | |

## The rest of the app

| Serbian | English |
|---|---|
| Repertoar | **Repertoire** |
| Otvaranje | **Opening** |
| Partija | **Game** |
| Potez | **Move** |
| Varijanta / sporedna linija | **Variation** / **sideline** |
| Zagonetka | **Puzzle** |
| Vežba, dril | **Drill** |
| Završnica | **Endgame** |
| Motor | **Engine** |
| Ocena, evaluacija | **Evaluation** |
| Snimak | **Recording** |
| Biblioteka | **Library** |
| Strelica / polje | **Arrow** / **square** |
| Tabla | **Board** |
| Nalog | **Account** |
| Pretplata | **Subscription** |

## Rules for the sweep

1. **Nothing outside `lib/` is translated.** The legal texts
   (`docs/politika-privatnosti.md`, `docs/saglasnost-roditelja.md`) stay Serbian
   until somebody decides what to do about the lawyer's approval, which covers
   Serbia and does not travel with a translation. `docs/` is English already by
   convention; `.env.example`, log lines and code comments are not user-facing
   and are not the sweep's business.
2. **A string's meaning is translated, not its words.** „Nema odigranih
   poteza." is „No moves yet.", not „There are no played moves."
3. **The terms in this file are used exactly.** A synonym that reads better in
   one sentence is how a vocabulary comes apart; if a term here is wrong, change
   this file first.
4. **Gender agreement has no English counterpart, and that is the one thing
   that gets easier.** What replaces it as the trap is **plurals and
   interpolation**: „Posle ove u redu je još 1 pozicija." has three forms in
   Serbian and two in English, and the app's own helpers (`_partsWord`,
   `_movesWord`) exist for the Serbian ones. Each one is a decision, not a
   find-and-replace.
5. **Tests are part of the string.** Hundreds of tests assert on exact copy
   with `find.text`. A string changed without its test fails the suite, and a
   test changed without its string fails it too — which is why the suite is the
   real gate for these batches, and why `gate_strings`, which compares copy byte
   for byte, has to step aside for the files being swept.

## What grades a translation batch

`gate_strings` cannot: it asks whether the copy is byte-identical, and every
byte is supposed to change. Three things take its place, and together they ask a
stronger question than it did.

* **`gate_english_ui`** — no Serbian letter survives in any string literal under
  `chess_app/lib`. Mechanical, and it cannot be satisfied by a half-finished
  file.
* **`flutter test`** — 1772 tests, a large part of them asserting on the exact
  words on screen. This is what catches a string renamed without its test.
* **The vocabulary anchors** — `docs/gates/vocabulary_en_test.dart` and
  `docs/gates/screen_names_en_test.dart`, which pin the terms in this file.
  They live in `docs/gates/` until the sweep makes them green, for the reason
  every anchor in this project has: a red suite hides the next real failure.
