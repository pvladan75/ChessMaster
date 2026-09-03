# Simplicity: the words, the drill, the voice, the board

Agreed 3.9.2026, out of the live pass on the repertoire. Written in English per
`CLAUDE.md`; every user-facing string named here stays Serbian.

## Why this exists

The owner — who built the feature with me and knows every part of it — had to
ask, in one afternoon, what four things on screen meant: „Pregledaj nacrt"
against a banner that disagreed with it, „koji talas i kad će taj talas",
„Napravi kičmu", and „Pokrivenost — pokrivenost čega čime". Their sentence is
the brief: *„Jedva se ja snalazim koji gradi ovo sa tobom, kako li će tek neko
ko se prvi put sreće."*

The same pass turned up four defects, and all four were one shape: **a screen
that knew something the reader could not see** — a count that was stale, a width
that was saved and never sent, a review that asked at the wrong rating band, a
queue that emptied into a dead end. The vocabulary problem and the defect
pattern are the same problem. A screen nobody can read is a screen nobody can
check.

## The rule this plan is built on

**One idea per thing on screen, named by what it does to the reader's work.**

A label may not name a mechanism (`kičma`, `talas`, `red`, `kapija`,
`pokrivenost`) unless that mechanism is something the reader has chosen to
learn. Where a number is on screen, the sentence beside it says what it counts.
Where an action is expected, it looks different from information that is merely
true.

## The glossary — frozen here, used everywhere

The left column stops appearing in the app. Nothing in the code has to be
renamed; this is about what the reader is shown.

| retired | shown instead | why |
|---|---|---|
| kičma | **glavna linija** | „Napravi kičmu" becomes „Predloži glavnu liniju". It writes the most-played move for both sides, N moves deep, as suggestions — the label should say the suggestion, not the anatomy |
| nacrt | **nepotvrđeni potezi** (a pile) / **predlog poteza** (one of them) | Two words because the reader meets it two ways. A count is „N nepotvrđenih poteza"; a single row in the moves list is „predlog poteza — još niste potvrdili". „Nacrt" said neither |
| talas, red | *(gone)* | Removed 3.9.2026. „Još N neodgovorenih" says the same thing without a concept behind it |
| kapija | **ide kroz `<potez>`** | The sentence already exists and is clear. The word itself never appears |
| širina | **koliko odgovora spremamo** | „Samo glavni odgovor" / „Uobičajeno (80%)" / „Široko (95%)" |
| pokrivenost | **rupe u repertoaru** | See below — the screen is read to find holes, and its own comments say so |
| odsečeno | **ne spremam** | The button's own words, on the tree mark and in the replies panel |

**„Pokrivenost" deserves its own line**, because it is the one nobody could
guess. The screen splits the repertoire by the opponent's replies and gives each
branch two numbers: how often that branch is actually played (`igra se u X%`),
and how much of *that* branch runs into a position with no answer of yours
(`bez odgovora Y%`). It is not coverage of a board or of a book — it is how much
of what will really be played against you already has your answer. So it should
be called what it is used for: **rupe u repertoaru**.

## The work, in phases

Sizes are honest: phases 1, 2 and 4 are worker batches; 0, 3 and 5 are the
lead's, on the standing rule that the lead keeps anything touching data,
schedule or contract.

### Phase 0 — lead. Freeze what the batches build against

* The glossary above, as the single source for phase 4.
* `AppSettingsService` keys and defaults for the board switches (the move you
  chose, the Lichess statistics, the engine's lines) and for speech (on/off,
  rate).
* Two widgets, written and tested by the lead so three batches cannot invent
  three versions of each:
  * `ActionBanner` — the one look for "this expects something from you",
    distinct from a sentence that is merely true;
  * `SpeakableInfo` — text plus a speaker control, reading the setting, silent
    when speech is off, and unable to throw into the action it describes
    (`AppFeedback`'s rule, for the same reason).
* The drill's scope contract: what a session covers, in a shape the screen can
  say in one sentence.

### Phase 1 — worker. The board's switches

Three toggles in one board menu, persisted per device: the arrow for the move
you chose, the Lichess statistics arrows, the engine's lines. What each one
defaults to is stated in the brief rather than left to the batch.

No new endpoint. The painter already takes what it needs.

### Phase 2 — worker. The voice

`SpeakableInfo` on every info panel that currently expects reading: the drill's
question and its verdict, the build screen's note and banner, the empty states.
A speaker toggle in the screen's own app bar, so speech can be turned off
**without leaving the screen** — being able to stop it where it happens is what
makes speech bearable at all.

TTS already exists (section 0k of `TODO-provera.md`); this is wiring, not a new
service.

### Phase 3 — lead. The drill says what it covers, and asks more often

Two halves, both touching the schedule, so neither is a batch:

* **What this session covers**, in one line at the top: which repertoire, which
  branch, how many positions, how many are due today.
* **Practising sooner.** SM-2 sends a position six days out after two good
  answers, which is right for retention and wrong for somebody building a habit
  in their first week. The plan: a daily target the reader can see and finish,
  and "practise anyway" as the offered path when nothing is due — it exists
  already (`Vežbaj ipak`) and is currently a corner rather than a door. Nothing
  about it may write to the schedule: practising ahead stays unscored, which is
  exactly what makes it safe to offer.

### Phase 4 — worker. The vocabulary sweep

Every label, banner and empty state in the repertoire, against the glossary.
Nothing structural — the shapes are what phases 0 to 3 leave behind.

**The `strings` gate compares literals byte for byte, so this batch rewrites the
very thing that gate exists to protect.** Its allowance list has to be written
before the run, per file, and this is the one batch where "a string changed" is
the work rather than the defect. That is a brief the lead writes carefully or
does not run at all.

### Phase 5 — lead. Watched running

Items into `TODO-provera.md`, checked live, the way sections 86–91 were.

## Later, and worth remembering

**Explain the words where they are used.** „odlučeno", „otvoreno", „bez
odgovora" are honest numbers that still need a sentence, and the sentence
belongs where the number is — a term the reader can press, answering in a line
what it counts and what it does not. Not now: it is worth doing once the words
themselves have stopped moving, or it is written twice.

## What is not in this plan

**The overlapping-openings model itself stays.** Two repertoires from one
position, told apart by the move they go through, is what makes „moje otvaranje"
mean one opening rather than everything anybody ever played from that board.
What changes is that the reader never meets the word for it: they fork a move
into its own opening, and the app remembers which move that was.

If, after phase 4, it still cannot be explained in one sentence on screen, that
is evidence the model is wrong rather than the wording — and then it is a design
decision taken with the owner, not a batch.
