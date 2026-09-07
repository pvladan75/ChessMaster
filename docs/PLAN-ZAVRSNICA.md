# The closing plan

Written 8.9.2026, after the owner's live pass through tutorial authoring and a
review of what the four open questions would actually cost. **The scope is
frozen by this document**: what is not in it does not get built before release,
and the reason for each exclusion is written down so the decision does not have
to be taken twice.

**The phases are logical, not calendar.** The owner has other obligations and
will not necessarily move one phase per day. The *order* is fixed — a phase does
not start before the one in front of it is finished — but no date is promised
anywhere in this file, and none should be added to it.

## What was decided

| | | |
|---|---|---|
| Video of a tutorial | **in** | Server-side, through the renderer that already exists |
| „Predloži rečenicu" in the studio | **in** | LLM writes prose about a chosen position, never moves |
| One board-setup dialog | **in** | Two files with the same name is a fault, not a preference |
| Naming the board screens | **in** | Renaming entries, **not** merging screens |
| TTS through a public API | out | See „What is deliberately not being done" |
| Video rendered on the device | out | Same |
| Monetisation beyond what is built | out | Same |
| Reorganising the app by function | out | Same |

## Phase 1 — the freeze, and two cuts

Nothing new is designed after this phase. Two things are cut because they are
faults rather than improvements.

### 1a. One dialog for setting up a position

Reported live on 8.9.2026: the same act has two different dialogs. It does —
**two files, both named `board_setup_dialog.dart`**:

* `lib/widgets/board_setup_dialog.dart` — 393 lines, a piece-placement editor
  and nothing else. Takes `onFenGenerated` and **no `initialFen`**, so it always
  opens on the standard position and cannot be opened on the board in front of
  you. Used by the room. This is the one the owner called good.
* `lib/features/analysis_studio/widgets/board_setup_dialog.dart` — 820 lines,
  tabbed: FEN entry, PGN import (file, chess.com, Lichess), an opening picker, a
  game selector. Takes `initialFen`, `onPositionSet`, and an optional
  `onPgnLoaded`. Used by the Analysis Studio and by the tutorial studio.

So this is not one thing written twice — it is a better *editor* and a better
*shell*, and the resolution is neither „delete A" nor „delete B":

**One dialog. The shell is B, its first tab is A's editor, opened on the
position the caller is looking at. A is deleted.** The room passes the board's
current FEN where it passed nothing. Nothing else about the room changes.

The gate for it:

1. Every entry — room, Analysis Studio, tutorial studio — reaches the same
   dialog, and a source-reading test fails if a second one appears.
2. The room's dialog opens on the position that is on the board, which it never
   could before.
3. The tutorial studio's entry behaves as it does today: no `onPgnLoaded`,
   because importing a PGN into a tree is the Analysis Studio's job and a second
   importer beside the first is how the two disagree.
4. **The palette is legible.** The owner's words: „u ovom se crne figure skoro i
   ne vide od iste pozadine". Read as a luminance problem, not a hue one — the
   owner is colourblind and their sign-off proves lightness and shape, never
   colour.

### 1b. The names say what the screen is for

Three screens carry a board and side panels, and two of them look alike enough
that the owner asked why both exist:

* the room with a student in it — „Soba: 589388"
* the same room alone, with the lesson library on the left — **„Šahovski
  studio"**
* the analysis board — **„Tabla za Analizu"**

and a fourth, „Studio za tutorijal", takes the word *studio* a third time.

**The screens are not merged.** They do different work, they were built for
different work, and merging them is the multi-week job this plan exists to
avoid. What changes is the name and the door: each entry says what the screen is
for, and the word „studio" belongs to exactly one of them.

This is a wording decision and it is the owner's. It is made in this phase,
before anything is renamed, and it obeys the glossary contract
(`docs/TABELA-RECNIK-2026-09.md`): the strings gate takes a table of decided
replacements, so the new names are written there first and the sweep is checked
against it.

### 1c. The freeze

After 1a and 1b, no new feature is designed. Anything found from here on is
either a fault (fixed), or written into `docs/TODO-provera.md` and left.

## Phase 2 — a tutorial becomes a video

### What already exists

`chess_backend/videoRenderer.js`, 319 lines, verified live: `@napi-rs/canvas`
draws one PNG per second, `ffmpeg` turns the pipe into an MP4 with an audio
track. It is driven from `POST /recordings/:id/export`, takes a title, a list of
events, an optional audio file, a duration, a perspective, a resolution, a piece
set and a board theme, and it already ages its output out on a retention timer.
`ENT.MP4_EXPORT` already exists as a paid entitlement.

Its event shape is small:

```js
{ timestampMs, eventType: 'init' | 'move', data: { fen, from, to, san } }
```

### What it does not do, which is the work

**It draws no arrows, no coloured squares and no sentence.** For a recorded
lesson that was right — the voice carried the teaching. For a tutorial it is
most of the teaching: `[%cal]`, `[%csl]` and the trainer's sentence are what a
part *is*, and a video without them is a slideshow of positions.

So Phase 2 is four pieces, in this order:

1. **A tutorial becomes a list of events.** `beatsOf` already turns a part into
   the beats a child meets, in the child's order; a video is those beats with a
   timestamp each. Every part of the tutorial in sequence, joins included.
   Pure function, gated by tests, no screen involved.
2. **A dwell time per beat.** There is no voice to wait for, so the sentence
   has to stay up long enough to be read: proportional to its length, with a
   floor. A beat with nothing written keeps today's short beat.
3. **The renderer learns three things**: a caption band under the board for the
   sentence, `[%cal]` arrows, `[%csl]` squares. The board's orientation comes
   from the part's `blackOrientation` — the field that already travels to the
   child — mapped onto the renderer's `perspective`.
4. **The route and the door.** A tutorial export beside the recording export,
   metered by the entitlement that already exists, and one button where a
   trainer already stands: the saved-tutorials list.

**The video is silent, by decision.** The sentences are on screen. Audio would
need TTS, and TTS is out of scope — see below. Nothing in this phase makes
adding a voice later harder: the renderer already takes an audio file.

The gate for it: a two-part tutorial with a comment, an arrow and a coloured
square renders to a file that plays, with the arrow on the move it belongs to,
the sentence readable, and the board the way round the trainer left it.

## Phase 3 — „Predloži rečenicu" in the studio

### What already exists

`chess_backend/geminiService.js`, `gemini-flash-latest`, with
`explainPosition` and `generateMoveComment`, both carrying a hand-written
fallback for when there is no key. Wired into puzzles and game analysis, and
metered: `ENT.AI_COMMENTS`, quotas 10 / 500 / 2000 / unlimited by tier.

### The rule this feature is built under

**The model writes prose about a position the trainer has already chosen. It
never proposes, plays, or edits a move.** A model that invents a variation is
worse than no help at all, because the material goes to children and the trainer
would be reviewing chess rather than reviewing writing.

Concretely:

1. One button on the current beat card in „Tok". It fills the sentence field
   and nothing else — not the kind, not the task, not the answers, and never the
   tree.
2. **Nothing is saved by pressing it.** The trainer edits or deletes the text
   like any other; the draft is written by the same path as typing.
3. What travels: the FEN, the move that arrived at the beat, and the engine's
   evaluation if it is already on screen. **Not the tutorial's other parts, not
   the trainer's name, not any child's name or id.** The smallest thing that can
   answer the question.
4. A refusal is a sentence, not a silence: no key, no quota left, or no answer
   all say so, and the field is left exactly as it was.

The gate for it: the button never changes a tree; a failed call leaves the
field untouched; the request carries a position and nothing about a person.

## Phase 4 — the live pass

This is the phase that decides whether the project is finished, and it is the
largest. Measured on 8.9.2026:

| | |
|---|---|
| 1037 | verification items in `docs/TODO-provera.md` |
| 418 | confirmed live |
| 592 | **never seen running** |
| 20 | marked as failing |
| 6 | untestable as written |

592 will not all be walked. Pretending otherwise is how a release date slips
twice and then is met by not looking. So they are **triaged**, and the rule is
written here rather than decided item by item:

**A gate — must be walked before release:**

1. Anything a child or a parent touches: consent, the age gate, what a minor's
   account can do, what reaches a parent.
2. Anything that takes money or grants a paid right.
3. The paths a first real user walks end to end: sign up, find a trainer, be
   accepted, get a tutorial, do it; and on the other side: sign up, invite a
   student, write a tutorial, send it.
4. The 20 items already marked as failing. A known fault at release is a
   decision; a forgotten one is an accident.

**Not a gate — recorded as unverified:** everything else, moved to
`docs/arhiva/` with its status intact and a sentence saying it was never
watched. That sentence is the deliverable. „Tested in code, never run live" has
already hidden one real fault in this project (`getDue`, a missing import that
compiled), and the honest record is what makes the next person look.

## Phase 5 — publishing

`docs/TODO-objavljivanje.md`, in the dependency order it already has. Its long
poles are external and cannot be compressed by working harder: the Play Console
product setup, the service account for purchase verification, RTDN, the first
real purchase, and the app-size question that Stockfish's 114 MB opens. The
backend also has to be switched on — the droplet is provisioned and the service
deliberately stopped, and that switch happens once, in one direction, when a
domain is chosen.

## What is deliberately not being done

**Video rendered on the user's device.** The reason for wanting it was cost, and
the cost it avoids is a few processor-seconds per video on a droplet whose
`exports/` already expires. What it would add is an ffmpeg binary in a Windows
build that is already fighting its size, a frame renderer written a second time
in Dart, and a class of failure that only appears on other people's machines.
If it is ever wanted, it is **additive**: the same event list, a different
renderer.

**TTS through a public API.** Roughly $4–16 per million characters; a beat is
about 120 characters, so a tutorial is about 2400 and a thousand of them read
once is $10–40 — cheap, but only with a cache, because the same sentence
otherwise pays on every play. It is worth revisiting only if the device voice's
Serbian is materially worse to the ear, which is a thirty-second test and not a
build. Its one genuine attraction is that it sends the trainer's own text and
never a child's voice or name.

**Monetisation beyond what exists.** Tiers, entitlements, quotas and the app's
billing service are built; the six open items in `docs/CENA-I-PRETPLATA.md` §7
are business decisions, not code, and they are better made against a month of
real measurements than against a guess.

**Reorganising the app by function**, one home for everything the app produces,
and merging the analysis board with the room. This is the right instinct and the
wrong moment: it is a redesign, it would consume everything left, and the part
of it that actually hurts — two dialogs for one act, and screens whose names do
not say what they are — is Phase 1. Written up here so the instinct is not lost.

## Where the numbers stood when this was written

* App: **1744 tests, 1 skipped**, measured on `master` on 8.9.2026 with nothing
  else running. `flutter analyze`: 29 issues, all `info`, zero warnings.
* Backend: **958**, last measured 7.9.2026 with `.env` moved aside. Not
  re-measured for this document.
* Open on the board and unrelated to this plan: three design questions from the
  7.9.2026 reports — orientation as a property of a chain of beats, whether a
  beat may hold more than one task type, and a comment before *and* after a
  move. None is a fault; all three are recorded and none is in scope.
