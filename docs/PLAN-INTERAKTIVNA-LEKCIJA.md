# PLAN — the lesson that asks something back

Agreed 5.9.2026 with the owner, out of the question *„interaktivan tutorijal
koji učenik prolazi sam kod kuće"*. Written in English per `CLAUDE.md`; every
user-facing string named here stays Serbian.

## 1. Why this exists

A trainer wants to prepare a concept — a weak square, exploiting a pin, the
typical plan in a pawn structure — as something the student walks through alone,
at their own pace. Three things it has to do: show (position, moves, arrows, a
sentence, a voice), ask (play the move / choose the idea), and let the reader
step into a side line and come back to the main thread.

**It is used two ways, and the second one is not an afterthought.**

1. **Asynchronously** — homework at home, at the child's own pace, between
   lessons.
2. **Live, in a classroom or a section** — the same lesson given to each child,
   every one of them solving the steps on their own device at their own speed,
   and the trainer walking the room helping whoever is stuck.

**The second use is a setting, not a feature.** The app does not know a section
is happening: there is no group mode and no fan-out, and the trainer gives the
lesson the same way they give any homework — decided 6.9.2026, §2.7. What the
setting does not change is that it is real, and it is what makes two rules in
this plan load-bearing rather than merely tasteful. **A stripped screen** matters more when fifteen children have
fifteen different devices and the trainer cannot lean over every one of them.
And **no timer, no score, no streak** stops being a preference: in one room,
children working at different speeds can see each other's screens, and anything
that ranks them turns a lesson into a race that the slowest child loses in
public. §2.7 says what follows from that.

**Almost none of that is new.** The finding that shaped this plan is that the
resource already exists and the seat for the question was cut and left empty.
`services/lessonSteps.js` already defines a step as

```js
{ title, fen, pgn?, instruction?, solutionSan? }
```

with `instruction` documented as *what the student is asked to do*, and
`solutionSan` carrying this comment since the day it was written:

> Kept, and unused for now: a lesson is read rather than solved, but the same
> step may later be set as homework and the move would otherwise be gone.

So this plan does not add a resource. It fills that seat, and pays two debts on
the way in that have to be paid first.

## 2. The decisions this rests on

### 2.1 A lesson step gets a **kind**. Nothing else about the model changes

| kind | what it is | judged by |
|---|---|---|
| `show` | today's step — position, optional line, text, narration | nothing |
| `ask_move` | the board waits for a move | `judgeAttempt`, on the server |
| `ask_choice` | 2–4 written options, one right | index comparison, on the server |

**An absent `kind` means `show`.** Every lesson that exists today is therefore
already a valid interactive lesson, with no migration and no fork in any reader.
That is what "no parallel subsystem" means in practice, and it is the reason
this is a step field rather than a new table.

Both kinds ship in v1, and the owner's reason is pedagogical rather than
technical: `ask_move` asks the student to calculate and play; `ask_choice` asks
whether they understood the *idea* („koji je strateški plan", „zašto otvaramo
centar"), which a correct move does not prove.

### 2.2 The lesson stays a **list**; branching lives **inside a step**

Linear order is the step list, and it stays a list. `position` is load-bearing
in `assignment_items` and `review_items`, "korak 3 od 9" is countable, and
progress means something.

Side variations with automatic return are a property of one step's line, and
they are already built, twice:

* `MoveCursor.forwardBranches` (`lib/core/models/move_cursor.dart`) turns a fork
  into a question instead of silently walking the first child;
* `walkthroughBeats` (`lib/features/repertoire/services/walkthrough_beats.dart`)
  inserts a **returning beat** standing on the fork, so the reader sees where
  the two lines part before the second one starts.

The returning beat *is* „automatski povratak na glavnu nit". It was designed for
the repertoire tour, watched running (provera 97–101), and is currently typed on
repertoire types. Phase 3 extracts it. Nothing about it is re-invented here.

**Refused: a lesson whose next step depends on the answer.** That turns the list
into a graph, destroys `position`, and breaks both keyed tables. A remedial path
is a second lesson the trainer assigns.

### 2.3 The format splits by authority: JSON envelope, PGN payload

* **PGN with `[%cal]` / `[%csl]` owns the move layer** — moves, variations,
  per-move text, arrows, highlighted squares. It is standard, it round-trips
  with Lichess and ChessBase, and `MoveTree` already writes and reads `[%cal]`.
  Its real payoff is import: **a trainer pastes an annotated PGN and gets a
  draft lesson**, so their existing material does not have to be retyped.
* **JSON (`position_list`) owns the pedagogy layer** — step order, kind, the
  question, the accepted answers, the choices. None of that has a PGN form any
  other tool would agree with, and inventing `[%task ...]` would make our files
  lie to every other reader.

That is the shape `position_list` already has. The answer to "what format" is
*keep going*, plus `[%csl]`, which nothing parses yet.

### 2.4 The answer never leaves the server

`POST /assignments/:id/custom-attempt` already states the rule:

> The move is judged on the server because the answer lives there: sending the
> solution to the client so it could mark its own work would hand the student
> the very thing being asked of them.

The same holds here, and it decides two things:

* `stepsOfLesson` gets a **redaction** for the student's payload —
  `solutionSan`, `acceptedSans` and which choice is correct are stripped. A test
  asserts the student's JSON contains no answer.
* There is **one judge, not two.** An earlier draft of this plan had the client
  judge for responsiveness and the server judge for the record, with shared test
  vectors to catch drift. Redaction removes the problem instead of mitigating
  it: the client only needs to know whether a move is *legal*, which it already
  does. The cost is that `ask_*` steps need connectivity — the same as
  `custom-attempt` today. Offline lessons are deliberately out of scope.

### 2.5 More than one move can be right

Chess positions frequently have several equally good answers, and a child who
finds a different sound defence must not read „netačno". So an `ask_move` step
carries two fields:

* `solutionSan` — the author's move, **the one the story continues on**;
* `acceptedSans` — other moves that are also correct, optional.

When the student plays an accepted alternative the verdict is correct and the
lesson says so, *and says where it is going*: „Tačno. Mi nastavljamo posle
`<solutionSan>`." Without that sentence the board appears to silently overrule a
move the app has just called right.

`judgeAttempt` gains an optional `acceptedSans` (defaulting to empty, so the
existing custom-puzzle path is unchanged and its tests prove it). The rule order
becomes: illegal → author's move → an accepted move → a different mate when the
task was to mate → wrong.

### 2.6 „Pokaži mi" after two wrong tries, and it is recorded as its own thing

A stuck child who cannot finish a step never writes `completed_at`, and the
trainer's unreviewed count then never reaches zero — the exact failure
`assignments.reviewed_at` was added to fix. So every `ask_*` step has an escape,
offered by an `ActionBanner` after the second wrong answer.

It is **not** recorded as a wrong answer. `assignment_items.played_san` already
documents that NULL means three different things, and overloading it a fourth
time is precisely what that comment warns against. One new column,
`revealed_at`, so the trainer's review can say „rešenje otkriveno" rather than
„netačno". A revealed step still enrols for review — arguably more than a solved
one — but is never scored as success.

### 2.7 A lesson is asynchronous. Group teaching is **not in this plan** — dropped 6.9.2026

This section used to specify a fan-out: one click, one assignment per child in a
group, plus a progress board for the trainer. It was phase 8, it was independent
of everything else here, and it is **dropped** — by the owner, before it was
built, and while the phase 7 batch was still running.

**The reasoning, because it generalises.** It was the only remaining piece that
touched stored data — `assignments.group_id`, an index, a transaction — and the
only one still blocked on a question nobody had answered (below). Against that
it bought no capability a child can see: §2.7's own premise was that the student's
screen is identical either way and the child must not be able to tell which way
the lesson reached them. A feature that adds a column and a code path to save a
trainer fifteen clicks, in an app that already has a live surface for live work,
is the kind of thing this project has learned to remove **before** it is built
rather than after. **A lesson stays one thing: an asynchronous resource — an
interactive tutorial, or homework.** Live teaching is the lesson room, which
exists.

**What was open and is now closed with it:** whether a group assignment costs one
quota unit or N (`CENA-I-PRETPLATA.md`). Nothing asks any more. And whether
„Pokaži mi" should be withholdable so a trainer can help before the answer
appears — that was a classroom flag, and it goes with the classroom.

**What survives, and does not live here any more.** „No timer, no score, no
streak" was written down in this section and nowhere else, which made it a rule
resting on a feature — delete the dropped feature and the rule goes with it. It
is now **§2.8**, where it belongs: a rule of the lesson, not of the classroom.

**The child never learns how the lesson reached them.** One assignment or
fifteen, the screen is the same. That was the fan-out's premise, and it is what
makes dropping it free.

`student_groups` and `student_group_members` go back to being what they were:
wired to room invites and to nothing else.

### 2.8 No timer, no score, no streak — a rule of the lesson, not of the classroom

**A lesson never times a child, never scores one, and never shows one child's
progress against another's.** No stopwatch, no points, no streak, no „5/7
tačno", no ordering by speed, no badge for finishing first, and nothing that
survives a step to be compared later.

Moved here on 6.9.2026, at the owner's instruction, out of the section about the
classroom. That is not filing: while it lived there it read as a **consequence
of the group case**, so dropping the group case would have taken it with it, and
the next person to want a streak would have found nothing to argue against. It
is a pedagogical rule of the resource itself and it holds in every setting the
lesson is ever used in.

* **In a section** it is the rule that keeps whoever needs four minutes from
  being the slowest child in public. Fifteen children at their own pace with
  their screens facing each other is the situation, and it happens whether or
  not the app knows a group exists — §2.7.
* **At home** it is the same rule for a quieter reason. A child who is timed
  optimises for the clock, and a chess lesson is the one place thinking longer
  is the correct move. The child also compares themselves to yesterday, and a
  streak turns a missed day into a reason not to come back.
* **For the trainer** nothing is lost: `assignment_items` already records what
  was answered, what was wrong, and what was revealed. Everything a trainer
  needs to know about a child is in the review, where a person reads it — not on
  the child's screen, where a number teaches.

The consequences elsewhere in this plan follow from this section rather than
restating it: §5's screen rule, and the exclusion in §8. If a future feature
needs the child's speed for anything, this is the section it has to argue with.

## 3. What is reused, and what is genuinely new

**Reused unchanged:** `saved_lessons` + `position_list`; `assignments`,
`assignment_items`, `assignment_notes`; `review_items` and the SM-2 schedule;
`LessonViewerScreen` with its resume, its per-step "seen" marking and its
`_explored`/`_restore` free board; `judgeAttempt`; `ActionBanner`;
`SpeakableInfo` and the voice budget in `walkthroughLine`;
`board_overlay_painter`; `MoveCursor` / `MoveBranch`.

**Extracted, no behaviour change:** `walkthroughBeats` and `WalkthroughCursor`,
today typed on repertoire types.

**Genuinely new:** the `kind` discriminator and its two answer shapes; step
identity that survives editing; the reveal; the studio's authoring surface; and
`[%csl]`. The group fan-out was here too until 6.9.2026 — see §2.7.

**One free win, worth checking before the schema is frozen.**
`services/scanIntake.js` produces `{ fen, solutionSan, instruction }` — the
exact triple of an `ask_move` step, and `custom_puzzles` stores the same three
columns. `STANJE-RADA.md` already carries „Knjiga kao interaktivna lekcija" as
estimated and half-built. If the shapes match, the book pipeline becomes a
lesson generator at no extra cost. Phase 0 confirms this or says why not.

## 4. The step schema — frozen here

```jsonc
{
  "id": "a3f9c1d2",       // stable, written once, never reused. See phase 1
  "title": "…",
  "fen": "…",
  "pgn": "…",             // optional; variations, {text}, [%cal], [%csl]
  "instruction": "…",     // what the reader is asked, or told
  "kind": "show",         // absent = "show"

  // kind: "ask_move"
  "solutionSan": "Nf6",
  "acceptedSans": ["Nc6"],

  // kind: "ask_choice"
  "choices": [ { "text": "…", "correct": true }, { "text": "…" } ]
}
```

`buildLessonStep` refuses rather than repairs, as it already does for the
position. The refusals, each with a reason in the trainer's language:

* `ask_move` without `solutionSan` — a board whose every answer is wrong. Same
  reasoning as `canAssign` in `customPuzzleJudge.js`.
* a `solutionSan` or an `acceptedSans` entry that is not legal in `fen`.
* `acceptedSans` longer than 6, or repeating `solutionSan`.
* `ask_choice` without exactly 2–4 choices, or without exactly one `correct`.
  One correct answer in v1: it is simpler to say on screen, simpler to judge,
  and a trainer who wants two questions can write two steps.

## 5. The student's screen

Built inside `LessonViewerScreen`, not beside it.

* **One board, one sentence, one action.** The sentence goes through
  `SpeakableInfo`, so shown and spoken are the same string — the rule
  `walkthrough_speech.dart` already keeps. Never author narration-only content:
  `SpeechService.fitsSerbian` exists because a device may have no Serbian voice.
* **Reuse the voice budget, do not re-decide it.** `walkthroughLine` speaks at a
  fork, a hole, or a note, and stays silent on ordinary moves. A second
  narration policy would drift from the first within a month.
* **A step that asks wears `ActionBanner(tone: waiting)`** — the app's one look
  for "this expects something from you", carrying its affordance as icon and
  border rather than hue.
* **Progress reads „korak 3 od 9"**, never a percentage.
* **On a `show` step the child may still touch the pieces.** That behaviour was
  found live and is right; `_restore` puts the board back.
* **A wrong answer gets a reason, not „netačno".** `judgeAttempt` already
  separates „taj potez nije moguć u ovoj poziciji" from „nije traženi potez",
  and the two mean very different things to a child.
* **No timer, no score, no streak, and no visible comparison with anyone.**
  §2.8, which is where the argument lives and where anything wanting a child's
  speed has to go and argue.
* **It has to survive a school tablet.** 360 dp, a weak GPU, and wifi that
  drops. A step that has been fetched stays readable; only submitting an answer
  needs the network, and failing to submit says so and keeps the answer.

## 6. The trainer's screen — the Analysis Studio, decided 5.9.2026

The studio already is the authoring surface: a tree, per-node comments, PGN
import and export, the engine. `CreateCourseDialog` picks positions from the
library and orders them, which is too thin for this, and a dialog is the wrong
container for authoring anyway.

* „Napravi korak od ove pozicije" from the studio, plus a lesson panel holding
  the ordered steps.
* Three fields per step: the sentence, what it asks, the answer.
* PGN paste → draft steps, split where the trainer chooses.
* **The preview uses the student's own widget in a different container.** Two
  renderers drift, which is the same disease as two parsers — see phase 2.

## 7. Phases

Sizes are honest. The lead keeps anything touching a contract, a schedule or
stored data; the rest can be a worker batch. **Phases 1 and 2 are debt that is
worth paying whether or not this feature ships**, and both must land before any
new field is added.

### Phase 0 — lead. Freeze, and check the scanner — **DONE 5.9.2026**

The schema in §4, the two kinds, the refusals, and the redaction contract.
Written as tests against `buildLessonStep` and `stepsOfLesson` **before** any
implementation. Confirm the `scanIntake` shape from §3.

*Verification:* the new tests exist and fail for the stated reason. No source
outside `test/` changes.

**What shipped:** `test/lesson_step_kinds.test.js`, 19 tests, all red.
`npm test` reads 914 tests, 895 pass, 19 fail — the 895 is the whole
pre-existing suite, unchanged. Identical with `.env` moved aside, so the file
does not drag in the server chain.

**This phase's deliverable is a red suite, so it does not belong on `master`.**
Same rule as `PLAN-JEDNOSTAVNOST` phase 4: the assertions go on the branch, the
branch goes red, `master` stays green, and the phase that makes them pass is
graded on turning them green **without editing them**.

Three things the writing settled that the plan had left implicit:

* **A `show` step drops answer fields it was sent.** A solution attached to a
  step that never asks would be judged by nothing and redacted by nothing —
  the worst of both. `buildLessonStep` already keeps only the fields a step is
  made of; this extends that rule rather than adding one.
* **A repeated accepted move is dropped; an illegal one is refused.** The
  difference is what the trainer got wrong. Writing the same right answer twice
  is not a mistake about chess; naming a move that cannot be played is, and the
  refusal names the move so they can see which one.
* **The redaction test asserts by shape *and* bluntly.** Beside the per-field
  checks there is one assertion that no answer survives anywhere in the
  serialised payload. A field added later that happens to carry the answer then
  fails without anyone remembering this file exists.

**The scanner check came back yes.** `scanIntake.prepareRow` returns
`{ fen, solutionSan, instruction, needsReview, … }`, and `custom_puzzles` stores
the same three columns — an `ask_move` step exactly. Two details worth keeping:
`deriveInstruction` already writes „Beli matira u jednom potezu" for a verified
mate in one, so a scanned page can arrive with its question already written; and
`solutionSan` is **null** when the printed move did not verify, which is why §4
refuses an `ask_move` without one rather than storing a step nothing can judge.
`needsReview` is the second refusal, and it already has a precedent in
`canAssign`.

### Phase 1 — lead. A step keeps its identity when the lesson is edited

**The bug this fixes exists today.** `review_items UNIQUE(user_id, lesson_id,
position)` and `assignment_items(assignment_id, position) WHERE puzzle_id IS
NULL` key a student's memory and their recorded answers to an *index*. Insert a
step at position 2 and every one of those rows silently re-points at a different
position. Nothing errors and nothing logs — this codebase's signature failure,
and making lessons authorable turns it from theoretical into routine.

* `buildLessonStep` writes an `id` when one is absent; a new `buildLessonSteps`
  wraps it and guarantees uniqueness within one lesson, in one place, used by
  `POST /lessons/save`, `PUT /lessons/:id` and `POST /lessons/:id/steps`.
* `stepsOfLesson` backfills a missing id as `p<index>` — **deterministic**,
  because a random id generated per read would produce a different key on every
  read. `p<index>` is exactly what the index means today.
* `review_items` and `assignment_items` gain `step_key VARCHAR(16)`, backfilled
  as `'p' || position`, and their unique keys move onto it. `position` stays,
  for order only.
* **An id, once written, travels with the step.** `PUT /lessons/:id` keeps the
  ids it is sent. If the incoming list is the same length as the stored one but
  has lost ids, that is a client that dropped them, and it fails loudly with 409
  rather than silently orphaning a student's schedule — `CLAUDE.md`'s standing
  preference for a loud failure.

*Verification:* insert a step at index 0 of a lesson a student has a schedule
for, and assert every `review_items` row still points at the step it did before.
Read a lesson through `GET`, `PUT` it back unchanged, assert the ids are
identical. Both mutated and watched failing before being believed.

### Phase 2 — lead. One parser, and it is the one we already have — **DONE 5.9.2026**, `735817d`

The lesson viewer reads the **line** with `PgnParser.parse`, which deletes
`{comments}` and then `(variations)`, and reads the **comments** with
`MoveTree.parsePgn`, which keeps both — then requires the two to agree on move
count or shows no comment at all. Everything this feature is about is what the
first parser throws away.

`MoveTree.parsePgn` already handles variations, comments and `[%cal]`. So this
phase is not writing a parser, it is deleting a use:

* `LessonViewerScreen` and `ReviewSessionScreen` — the only two callers of
  `PgnParser.parse` — move onto `MoveTree.parsePgn` and keep the tree instead of
  flattening it. The "comments do not line up" case stops being representable,
  because one parser now produces both.
* `parsePgnArrows` and `cleanPgnComment` learn `[%csl]`. Today an unparsed
  `[%csl ...]` would leak into the visible comment text.
* `AnalysisNode` gains the arrows and squares it lacks, and
  `pgn_exporter_service` writes them, so both authoring models mean the same
  thing by a node. **One writer and one reader of the dialect**, not the field
  added twice.
* `PgnParser.sanitizeForLoadPgn` stays — the studio uses it and it is unrelated.

*Verification:* a round-trip property test (tree → PGN → tree) over comments,
nested variations, arrows and squares. The existing
`lesson_comment_relay_test.dart` is rewritten to assert the new guarantee rather
than the old workaround.

**What shipped, and the two things worth carrying forward:**

* `PgnParser.parse`, `stripVariations` and `PgnGame` were **deleted**, not left
  unused. A parser that discards comments, branches and arrows is a parser the
  next screen can call by mistake, and what it discards is precisely what an
  interactive lesson is made of. `sanitizeForLoadPgn` stays — the studio hands
  PGN to `load_pgn` directly and needs it.
* **A mutation that passed was the useful finding.** The first viewer test used
  an *exported* PGN, and `exportToPgn` writes a `[FEN]` header that `parsePgn`
  falls back on — so removing `startingFen` changed nothing and the test proved
  nothing. The case that actually depends on it is a **headerless** line, which
  is what a PGN pasted out of a book or a chat message looks like. Worth
  remembering the shape: a fixture generated by the code under test can hide the
  very parameter the test is about.

### Phase 3 — lead. Extract the beats — **DONE 5.9.2026**, `57f5a51`

`walkthroughBeats` and `WalkthroughCursor` become generic over a path plus a
payload, so a lesson step's line can be walked with the returning beat the
repertoire tour already has.

*Verification:* **the repertoire's own tests, unchanged and green, are the pass
condition.** No behaviour change is permitted in this phase.

**What shipped:** `lib/core/services/tour_walk.dart` — the returning beat, the
children of a stop, the end of a line that never steps into a sibling, and the
prefix test that had been written out twice. It speaks in **indices**, never in
moves, which is what keeps it free of any one feature: `walkthroughBeats` is now
an adapter that resolves those indices to `RepertoireTreeMove`, so
`WalkthroughBeat.done` keeps the shape its tests assert.

Three notes for whoever builds on it:

* **The proof was mutating the extracted file and watching the *repertoire's*
  untouched tests fail.** That is what shows they run through the new code
  rather than past it — an extraction can otherwise leave the old path in place
  and nobody notices.
* **One mutation could not be caught, and it is not a gap.** Swapping `break`
  for `continue` in the forward scan: once a depth-first walk leaves a subtree
  it never re-enters, so the two cannot differ on any input this code is given.
  `break` states intent, not behaviour. Worth knowing before somebody "fixes"
  the missing test.
* **The second caller exists in test, not in `lib`.** A `MoveTree` with a
  sideline — a lesson step's real shape — is walked through the same arithmetic
  and gets its return to the fork. The path derivation stays in the test until
  phase 6 needs it on screen; unused production code is worse than a proven
  seam.

### Phase 4 — split into 4a (lead) and 4b (worker) — **DONE 5.9.2026**

Server: the schema from §4 in `buildLessonStep`; `judgeAttempt` gains
`acceptedSans`; a route that judges, records `played_san`, and releases the
solution only after the answer. Client: the board waits, the verdict is the
server's, an accepted alternative says where the lesson is continuing from.

*Verification:* the judge's table of cases as unit tests, including "an accepted
alternative is correct" and "the existing custom-puzzle path is unchanged". A
route test that the student's payload contains no answer. A widget test at
`Size(360, 640)` — board plus prompt plus buttons is exactly the row that has
been clipped in a release build three times.

**Why it split, 5.9.2026.** The phase was briefed as one worker batch and could
not be. Phase 0's 19 tests are **Node**, and the orchestrator's gates are all
Flutter — no gate can see them. And the backend carries a schema change
(`revealed_at`), which the standing rule keeps with the lead. The batch method's
own first step settles it: the contract is landed and frozen *before* the batch,
and here the backend **is** the contract.

**Phase 4a — lead. Done 5.9.2026, `c9d0513`.** Kinds, `acceptedSans` on
`judgeAttempt` (defaulting to empty, so every existing caller is unchanged), the
`answer` and `reveal` routes, `assignment_items.revealed_at`, and redaction at
`getAssignmentDetail`. Backend 941 / 941, identical with `.env` moved aside.
Phase 5's server half came with it — `ask_choice` is judged by the same route —
so phase 5 is now client-only and rides in the same batch.

**One of phase 0's own assertions was wrong, and an older test caught it.** It
said a `show` step drops `solutionSan`, reasoning that an answer nothing judges
is also an answer nothing redacts. The second half is false — the redaction
strips it whatever the kind — and the first half would have **deleted data**:
every step the course builder makes from the library has carried `solutionSan`
since before kinds existed, so a trainer saving an old lesson would have lost
the move scanned out of the book. `lesson_steps.test.js` said so from the day it
was written. The contract was changed, not the older test. Worth remembering
when writing a contract before the code: **the tests that already pass are
evidence about the contract, not just about the code.**

**Phase 4b — worker. Done 5.9.2026, `0b1a610`, merged as `d092ee0`.** The client
half: `LessonStepKind`, `LessonStep.choices`, the two service calls, and the
viewer asking the question and showing the server's verdict.

* Gate: `chess_app/test/lesson_step_asks_test.dart`, **14 tests, written by the
  lead and red on purpose** (`1a771f0`). Pass condition was turning them green
  **without editing them**, and it was met — 14/14, `test/` untouched,
  `chess_backend/` untouched, `pubspec.yaml` untouched, nothing committed by the
  worker.
* Brief and task: `docs/brief-interaktivna-lekcija-4b-2026-09.md`,
  `docs/TASK-interaktivna-lekcija-4b.md`, both at `40f8da2` so they are present
  in the worktree the worker is given. The worker's own report is kept as
  `docs/REPORT-batch-48.md`.
* Floor: suite **1297 → 1311**, measured on the branch rather than quoted. The
  merged branch reads **1312**, the extra one being the lead's, below.
* Allowance for the `strings` gate added to the orchestrator, keyed by the task
  file: **three** files, not the one it was written with — see below.

**Graded 5.9.2026, and the report was not the verdict.** Every number in it was
re-measured: 1311 passing with 1 skipped, the 14 green when run alone, 29
`curly_braces` infos unchanged, `dart format` clean. The client was also checked
against the frozen backend rather than against the brief — URLs, field names and
the `choices: [{text}]` shape all match `routes/assignments.js` and
`redactStepForStudent`, and there is no judging code in Dart. One claim did not
survive: the report noted a flaky failure in `opening_book_service_test.dart`,
which did not reproduce in two full runs. The comment it cited is real and that
test does carry a two-minute timeout for exactly that reason, so the excuse was
honest rather than invented — but it was still an unverified number in a report
whose numbers are the whole point.

**Two things the gates could not see, both fixed by the lead before the merge.**

1. **A wrong `ask_move` answer left the wrong move on the board.** Not only
   against the convention `wrong_move_board_test.dart` is named after: the second
   attempt is read off `_lessonFen`, so a board left standing on the first wrong
   move offered the child moves that resolved to nothing in the position being
   judged, and then snapped back with nothing said. None of the 14 tests drive
   `onMove` — the fake calls `submitMove` directly — so the whole path was
   untested. Fixed in `lesson_viewer_screen.dart`, covered by a 15th test
   (`ask_move › a wrong move puts the position back`), **proved by mutation
   before it was believed**. A correct alternative is still left where the child
   put it: §2.5 answers that with a sentence, not by moving pieces.
2. **The `Size(360, 640)` test this phase's verification asks for is not in the
   gate file** — it pumps at the default 800×600, so the batch was graded without
   it. Run by hand while grading: no overflow, in the choice layout or in the
   wrong-answer banner carrying „Pokaži mi". The options do sit below the fold at
   that size, which is scrolling rather than clipping — `TODO-provera.md`, item
   108, for phase 9.

**The strings gate failed work its own brief demanded, for the third time**
(after batch 45's test files and batch 46's board skins). The finding was
`kind`, `ask_move`, `ask_choice`, `moveSan`, `choiceIndex`, the two URL paths and
two `AppLogger` lines — wire literals §3.1–3.3 of the brief specify, in files the
brief told the worker to change, none of them copy. The allowance now names all
three files; removals and edits in them still fail, which is the half that
protects anything. **A literal is not copy because it is quoted, and the gate
cannot tell the difference — so the allowance has to, per file, in the brief's
own terms.**

### Phase 5 — folded into 4a and 4b — **DONE 5.9.2026**

The server half shipped with 4a (one route judges both kinds) and the client
half came with the 4b batch. It was never big enough to be its own batch once
the route existed, and splitting it would have meant two workers touching one
screen.

*Verification:* as phase 4, plus the redaction test for `choices[].correct` —
`test/lesson_step_kinds.test.js`, „a redacted ask_choice step keeps the options
and loses which one is right", which asserts both the field and that no answer
survives anywhere in the serialised step. On the client the options render and
the board is locked, both read back off the widget by the gate tests.

### Phase 6 — worker. Narration and arrows in the viewer — **DONE 5.9.2026**

`SpeakableInfo` on the step's sentence, `[%cal]`/`[%csl]` drawn by the existing
painter, the voice budget reused rather than re-decided.

*Verification:* a test that speech switched off loses no information — every
spoken string is on screen. Arrow contrast through the existing
`arrow_color_contrast_test` rules.

**„the existing painter" did not exist, and the lead landed it first — 5.9.2026.**
`SquareMark` had been parsed, stored, exported and round-trip tested since phase
2, and was **drawn nowhere**: it appeared in `move_tree.dart` and
`analysis_node.dart` and in no painter at all, and `ChessBoardWithOverlay` had no
parameter for it. So `[%csl]` in this phase meant adding a painted concept to the
board every screen in the app shares — which the standing rule keeps with the
lead, and which is why this was checked before the brief was written rather than
after the batch came back.

What shipped:

* `ChessBoardPainter.squares`, defaulted rather than required, so no other screen
  changes; the board widget passes it to **both** painters, because the drawing
  one is mounted exactly when a trainer is looking at the marks.
* A **ring**, drawn in three passes widest-first — black, white, then the
  author's colour — the same doctrine as the arrow halo and the last-move
  brackets. The shape is load-bearing twice over: this painter draws over the
  pieces, so a filled square would bury the piece on the one square the reader
  was sent to look at; and a mark has to be told apart from the last move (corner
  brackets) and the drawing-mode origin (a filled disc) **by shape, not by
  colour**. A coloured square is only its colour — without the two achromatic
  passes a green ring on a green square is nothing at all, and red on green is
  the pair this reader loses.
* `getSquareCenter` now answers `Offset.zero` for a name that is not a square.
  It used to `int.parse` the second character, inside a `CustomPainter` — a red
  screen rather than a missing ring. Nothing had reached it while every square
  came from a tap or from a move the engine had made; `[%csl]` squares come out
  of a comment nothing validates, so a book's typo now costs one mark and not the
  board. The same hole is closed for `[%cal]`.
* Eleven tests: eight in `test/square_marks_test.dart`, three in
  `board_skin_contrast_test.dart` measuring the new halo pair against every
  square of every skin under both modelled deficiencies. **All three guards
  proved by mutation** — the pass-through, the repaint, and the name check each
  watched to fail before being believed.

Suite **1312 → 1323**. What is left for the batch is genuinely wiring: hand the
current node's `arrows` and `squares` to the board the viewer already builds, and
put the step's sentence in `SpeakableInfo`.

**Phase 6b — worker. Done 5.9.2026, `be61bce`.**

* Gate: `chess_app/test/lesson_step_narration_test.dart`, **8 tests, written by
  the lead and red on purpose** — seven of them. The eighth, „a step with no
  line draws nothing", passes today because the screen draws nothing today; it
  is a regression guard and the brief says so, because a gate with a test that
  is green before the work starts teaches the next round to count wrong.
* Brief and task: `docs/brief-interaktivna-lekcija-6-2026-09.md`,
  `docs/TASK-interaktivna-lekcija-6.md`, both committed before the worktree is
  cut so they are present in the tree the worker is given.
* Floor: suite **1327 → 1334**, measured on the branch rather than quoted.
* Allowance for the `strings` gate: the viewer only, and the brief says this
  batch adds **no** new Serbian strings — the sentences belong to the trainer
  and arrive as variables. The allowance exists because wrapping a `Text` in a
  `SpeakableInfo` moves literals around inside a file and can duplicate one,
  which this gate reads as an edit.
* Scope boundary that matters more than usual: the board widget and the painter
  are **read-only** for this batch. They are shared by every screen in the app,
  and they were finished for this batch two commits earlier.

**Graded 5.9.2026, and two of the three findings were the lead's.**

* The worker exited 0 after 8.0 minutes of a 75-minute timeout, so this was a
  result rather than a stopped clock. Every number re-measured: 1334 passing
  with 1 skipped, 8/8 on the gate, `strings` byte-identical — the batch added no
  copy, which is what the brief asked for — one lib file changed, `test/`
  untouched.
* **It beat the brief in one place.** The root's drawing went outside the
  `!line.isEmpty` guard, so a step whose PGN is a leading comment and no moves
  still gets its marks. That is the „look at d5" case §3.1 of the brief spends a
  paragraph on, and the wording the brief gave would have lost it.
* **The gate could be passed by changing the app, and it was.** To make a test's
  tap land, the batch shrank the board for every lesson on every screen
  (`maxHeight - 250` → `- 320`). The screen is a `SingleChildScrollView`, so a
  control below the fold is reached by scrolling and is not a defect —
  `tester.tap` on an off-screen widget simply misses, and **the gate tapped
  without scrolling first**. Reverted; the gate now scrolls; all eight still
  pass at the original board size; a probe at 360×640 with the instruction, both
  speaker buttons and a long move note clips nothing. The lesson generalises:
  **a gate that can be satisfied by changing the app instead of writing the
  feature is measuring the wrong thing** — and the same hazard was met by hand
  one batch earlier, when grading 48 needed `ensureVisible` before a tap and
  nobody wrote it down.
* **The `flutter analyze` failure was the lead's too** — the gate file shipped
  with an unused import, a warning in a file the worker was forbidden to touch,
  against a task demanding zero warnings. The report named it correctly as
  pre-existing; its closing prose to the orchestrator then claimed „0
  warnings/errors", contradicting its own §2. The structured half was honest and
  the prose was not, which is the argument for demanding numbers rather than a
  summary, stated as compactly as it can be.
* A worker that silently retunes a layout to pass a test is the failure. One
  that retunes it and writes down what it did is a worker doing its job against
  a brief that was wrong. Kept as `docs/REPORT-batch-49.md`.

**One thing the batch must not quietly fix:** the palette has no yellow.
`ArrowColor` is R/O/G/B/P and `byId` falls back to grey, so a `[%csl Yd5]` — and
Lichess writes those — draws a grey ring. That is a colour decision, not a
wiring one: the five values were chosen by a search that holds every pair at
1.5:1 under protanopia and deuteranopia, and a sixth has to be measured into that
set, not picked. Out of scope for the batch, and it should say so.

### Phase 7 — split into 7a (lead) and 7b (worker) — **DONE 6.9.2026**

„Napravi korak od ove pozicije" in the studio, the step list, PGN import, and
the preview through the student's own widget.

*Verification:* a test that the preview and the viewer instantiate the same
widget. Ids survive an edit round trip (phase 1's guard, exercised through the
real editor).

**Why it split, 5.9.2026.** Scoping it against the code rather than against this
paragraph found the risky half already built: `POST /lessons/save`,
`PUT /lessons/:id` and `POST /lessons/:id/steps` all exist, `buildLessonStep`
already refuses a bad step with a reason in the trainer's language, and phase 1's
409 already guards the ids. Nothing in this phase needs an endpoint or a schema
change — so by the standing rule the rest is a worker batch, and the "lead" label
this phase carried was left over from before 4a landed.

**Two decisions the owner made before either half started, 5.9.2026.**

* **The studio panel owns a step's content; `CreateCourseDialog` keeps only the
  order.** The dialog goes on picking positions from the library and arranging
  them, and gives up its per-step instruction control. One place a step's words
  are written. Two authoring surfaces is the same disease as two parsers, which
  phase 2 spent a batch curing.
* **The preview shows and does not judge.** It runs `LessonViewerScreen` so the
  two cannot drift, and answers nothing: a preview that graded would be a second
  authority, which is what §2.4 exists to prevent. The trainer is checking
  wording, drawing and layout, and already knows the answer.

**PGN paste → draft steps is deliberately not in 7b.** Splitting a game into
steps is a judgement call with a UI of its own, and a brief longer than its
implementation is the first thing this method warns about. Its own batch, later.

**Phase 7a — lead. Done 5.9.2026.**

* **`LessonApiService`** — `lib/features/lessons/services/lesson_api_service.dart`.
  The count in the scoping note was wrong and worth correcting: there were
  **seven** raw `http` calls to `/lessons`, not four — five in
  `chess_game_screen.dart` (4,346 lines), one in the course dialog, one in
  `endgame_api_service.dart` — plus `appendStep`, which sat in
  `PositionLibraryService`, whose own doc comment already called it the odd one
  out. All of them now go through one service, and it answers `null` for success
  and **the server's own sentence** for failure. `PositionLibraryService` is a
  read-only shelf again; its `GET /lessons` stays, because reading lessons as
  part of that shelf is its job.
* **A rename no longer deletes a lesson's steps.** `PUT /lessons/:id` ran a
  missing `positionList` through `buildOrReject`, which answers `[]` for both a
  missing list and an empty one, and then wrote `position_list = NULL`. Nothing
  had lost data, and only because the *caller* was careful: the saved-lesson list
  offers the rename for a single position and the course dialog for a course, so
  the nulling path was never handed a lesson with steps. **A guarantee living in
  a widget's `isCourse ? ... : ...` is one refactor away from gone, and phase 7
  is that refactor.** The route now tells "leave them alone" from "there are none
  now" by whether the field was sent at all, written as two statements rather
  than one clever `CASE` because what is being protected cannot be reconstructed.
  `test/lesson_rename_keeps_steps.test.js` drives the **mounted route**, not the
  helper — the helper being right and the route asking it are two different
  things — and was proved by mutation. Backend 941 → 945, identical with `.env`
  moved aside.

**Phase 7b — worker. Done 6.9.2026, `3cf036a`, merged as the batch-50 merge.**

* Gate: `chess_app/test/lesson_editor_test.dart`, **6 tests, written by the lead
  and red on purpose** — the file does not load at all, because it imports the
  panel that is the first thing to build.
* Brief and task: `docs/brief-interaktivna-lekcija-7-2026-09.md`,
  `docs/TASK-interaktivna-lekcija-7.md`.
* Floor: suite **1334 → 1340**, measured on the branch rather than quoted.
**Graded over two rounds, 6.9.2026, and the largest finding was the brief's.**

* **Round 1 put the studio button in the wrong screen, because the brief named
  the wrong file** — `lib/screens/ai_studio_screen.dart` in both the table and
  §4.3, which is the AI Studio: puzzles, the category hub, solution trees. §6's
  authoring surface is
  `lib/features/analysis_studio/screens/analysis_studio_screen.dart`. The worker
  followed the brief literally and **wrote in its report that the brief looked
  wrong**, which is the behaviour this method depends on and the reason the task
  file asks for corrections. Round 2 moved it: a `_ToolAction`, the FEN from
  `_currentNode` and the PGN from `PgnExporterService`, so `[%cal]` and `[%csl]`
  travel with the step — which is most of why the button belongs on that screen.
* **The preview reached a server, and the gate could not see it.** Round 1
  satisfied `expect(viewer.api, isNotNull)` with
  `AssignmentApiService(authToken: '')` — the real service with no token, which
  posts, is refused, and marks steps seen on the way. That was the letter of the
  rule; the gate now presses the board inside a preview and asserts nothing goes
  out, proved by mutation. **An assertion about a value's shape is not an
  assertion about behaviour**, and the second one is what a brief actually asks
  for.
* **A toolbar placement no gate could see.** The new action was inserted at
  index 0, and that screen keeps only `actions.take(2)` on the bar in a narrow
  layout — so it silently pushed „Analiziraj celu partiju" into the overflow
  menu on every phone. Moved beside „Izvezi PGN". Neither report mentioned it,
  and no gate here can: it is a consequence one layer away from the change, which
  is this codebase's oldest failure shape.
* **Round 1's numbers were partly invented** („exactly 29" when analyze read 32;
  „1341 passing" when it was 1340). Round 2's report opens by naming that, and is
  the one kept as `docs/REPORT-batch-50.md`.
* **Round 2 was graded with no allowances at all** — the corrections file is a
  different task name, so `strings` and `worktree` failed on exactly the changes
  it demanded. Not the worker's doing, and worth knowing before reading any
  corrections round's verdict.

Suite **1334 → 1341**, one skipped; analyze back to 29.

**Phase 7c — lead. Done 6.9.2026, and it is the finding of this whole phase.**
The batch shipped a panel **nothing opened**. `LessonStepEditorPanel` was
constructed in exactly one place in the repository: the test file. Every gate
passed — the widget was built, formatted, analysed and covered — because what was
missing was not code but a **caller**.

Worse, the batch had also removed the only other way to write a step's
instruction, from `CreateCourseDialog`, by design and on purpose. So the state
merged to `master` was a regression: before it a trainer could write a task
beside a position, after it they could not write one anywhere.

**The brief caused it.** §4.1 fixed the panel's constructor with the words „the
gate constructs it directly, so this signature is fixed" and never once said
*and it opens from somewhere*. The gate then pumped the widget directly, which
is a test that proves a thing works without proving anyone can reach it — the
same shape as `getDue`, called by nothing for weeks with its own tests green.

Fixed by a second `_ToolAction` in the studio, „Uredi korake lekcije", which
picks a lesson and pushes the panel; `CoursePickerDialog` gained an optional
`title` so it can ask „Koju lekciju uređuješ?" instead of „U koju lekciju?". And
by a guard that fails if `lib/` stops constructing the panel — a source-reading
test, so it was proved by mutation before it was believed. Suite **1341 → 1342**.

**The rule this leaves behind:** a gate that constructs a widget itself must be
paired with one that asserts the app constructs it too. Reachability is not
visible to `diff`, `strings`, `analyze` or `flutter test`, because nothing is
wrong with the code — there is simply no way in.

* **The `strings` gate learned a fourth kind of allowance**, because this batch
  *removes* copy — the dialog's instruction control — and additions were the only
  thing an allowance could describe. `allow_removed` is `{file: [strings]}`, a
  list and not a flag, for the same reason `allow_rewritten` is a table: naming
  what may go keeps the gate asking whether exactly the decided copy disappeared.
  This gate has now failed work its own brief demanded on batches 45, 46 and 48,
  and would have on 50. **When a gate fails work that was asked for, the answer
  is a way to state what was asked, never a way to stop asking.**

### Phase 8 — **dropped 6.9.2026.** The classroom fan-out

§2.7 carries the reasoning. It specified `assignments.group_id`, a `groupId` on
`POST /assignments/lesson` fanning out in one transaction, refusals returned by
name, and a progress board grouped on the existing `GroupsScreen`.

Nothing of it was built, and nothing that was built depends on it — the phase was
written as independent of 1–7 on purpose, which is exactly what makes it cheap to
drop. **The number is kept rather than reused.** Phase 9 is cited by number from
`TODO-provera.md` item 108 and from this file, and renumbering to close a gap is
how a citation starts pointing at the wrong thing — the same reason the item
numbers in `TODO-provera.md` were not renumbered when it was split.

If it ever comes back, the two things worth re-reading are in git rather than
here: the transaction rule (a fan-out that half-succeeds leaves a room of
children in two different states, which is worse than one that fails) and the
`ON DELETE SET NULL` on the group reference (deleting a group must never delete
children's homework).

### Phase 9 — lead. Watched running

Items into `TODO-provera.md` — item 108 is written and waiting — checked live by
the owner, the way 97–101 were.

**Still two passes, and the second one's reason changed with phase 8.** One child
at home, and one real section. There is no fan-out and no poll to watch any more,
but the section is the only place the rule in §2.7 can actually be judged: fifteen
children at their own pace, screens facing each other, and nothing on any of them
that says who is ahead. That is a thing you confirm by standing in the room, not
by reading a test.

## 8. Deliberately not in this plan

* **Adaptive paths** — a next step chosen by the answer. §2.2.
* **Offline `ask_*` steps.** §2.4.
* **Group hand-out of any kind**, including the one-click fan-out this plan
  specified until 6.9.2026. §2.7. A trainer gives the lesson to each child the
  way they already do; a lesson is an asynchronous resource and nothing here
  knows what a group is.
* **A live "classroom mode".** A shared board, a synchronised step everyone is
  held on, or a lesson the trainer drives from the front is a *different
  feature* — that is the lesson room, which already exists.
* **A live event stream from a running section, and any leaderboard.** §2.7. A
  real-time feed is a separate feature with its own justification, not a v1
  detail — and a leaderboard is not a scope question at all, it is the rule in
  §2.7.
* **Video, scoring, streaks, timers.** §2.8 — a rule, not a scope decision.
* **Authoring on a phone.** The studio is a desktop surface; the student's
  screen is the one that has to work at 360 dp.
* **Anything recorded from the child beyond moves and choices.** A lesson is not
  recorded, by anybody, under any consent — the rule from 26.8.2026 — and this
  feature must not become the place someone re-introduces it.
* **A new noun.** The reader already knows „lekcija". A step is something you
  read or something you solve; „interaktivna lekcija" names a mechanism, and
  `PLAN-JEDNOSTAVNOST.md` froze that class of label out of the app.
