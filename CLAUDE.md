# CLAUDE.md

Chess coaching platform: a Flutter client (`chess_app/`) and a Node backend
(`chess_backend/`). A trainer runs a live lesson in a room — board, voice, and a
silent replay of the lesson's move timeline — plus puzzles, homework, spaced
repetition and parent reports. Audio is recorded only by an adult alone in a
room, making their own teaching material. Most users are children, which decides
several rules below.

## Layout

| | |
|---|---|
| `chess_app/` | Flutter client. Android + Windows are the real targets |
| `chess_backend/` | Express + Socket.IO + PostgreSQL (managed, DigitalOcean) |
| `docs/` | Handoff and planning docs — read `STANJE-RADA.md` first |
| `deploy/` | Server provisioning scripts, idempotent, run as root |
| `puzzles/` | One-off import tooling and datasets, not part of the app |

## Commands

```bash
cd chess_app && flutter test          # 1551 tests, 1 skipped, rest green
cd chess_app && flutter analyze       # exits 1 on 29 known infos — read the list
cd chess_backend && npm test          # node --test, 956 tests, all green
cd chess_backend && npm run dev       # nodemon, port 3000
```

Both counts were measured 4.9.2026, after the day's repertoire work: the
vocabulary sweep brought two banner-layout tests, the board/tree
synchronisation one, and `findNodeByFen` two more, and ten came with the engine
panel taking one shape across the three screens that draw it — less one, when
deleting the evaluation from the move tree's nodes took `treeEval` and its test
with it; on the backend, four came
with the rule that a breadth never hides the reader's own work and six with
`lineOrder`, which reads the drafts down one line instead of across a wave. The 1167th is
the gap's edge in the dark theme, and fourteen more came with the walkthrough
screen and its cursor, twelve with the sentence it speaks, and eight
with the arrows and the return to the fork.
Seven more came on 5.9.2026 with
`PLAN-TABLA-I-STABLO.md`: five with the tree following the active move to the
edge instead of centring on it, and two with the drawing keeping its zoom
across the 840 dp layout change, and eight with the width becoming a setting of
its own rather than a side effect of proposing a main line. The number in this
file had been left at 1234 for a day while the suite was 1239 — a floor below
the suite hides exactly what it is for, so measure before quoting it.
Fifteen more came on 5.9.2026 with the scanner saying **which** of three things
is wrong with a book instead of blaming the font for all of them: six in the
app for the sentence each code gets, four on the backend for the classification
and its route through `scanDocument`, and five for an upload that fails before
the scan starts.

Both counts were measured again on 6.9.2026, on `master`, after
`PLAN-INTERAKTIVNA-LEKCIJA.md` phases 0–7 merged: **1342 in the app and 945 on
the backend**, the backend identical with `.env` moved aside. A hundred and two
of the app's came with a lesson step that asks something back — the kind
discriminator and the screen that shows it, the ring `[%csl]` is drawn as, the
narration, the trainer's editor — and fifty on the backend with the judging
route, step identity, and the rename that no longer deletes a lesson's steps.

Twenty-three more on 6.9.2026, when a lesson step stopped being able to carry a
position from one node and a line from another: eleven for the one reader of a
step's line and the count of moves it could not play, seven for the pair the
studio builds from a single node, three on the student's screen — the note about
the starting position, and an older broken step still opening as the still board
it always was — and two for that note surviving the round trip through both
exporters. Seven more the same day for the shape those fixes were for: a step's
line walked at the speed of the voice — the move is played when the sentence in
front of it has been read out, not on a clock — and the join where showing turns
into asking, which is one board and not two screens. Five more with batch 51,
the vocabulary sweep that split one word in two: **Tutorijal** is the artefact a
trainer writes and a child walks through alone, **Čas** is the live session in a
room. `tutorial_vocabulary_test.dart` is what keeps them split — the old word
comes back one careless string at a time, and it also fails on „Ova tutorijal",
because the new noun is masculine and everything agreeing with it changes too.
Six more with batch 52, where the lesson viewer stopped throwing away the
sidelines it had already parsed: it holds the tree and a node now rather than
five lists indexed by ply, and the narrated walk **stops at a fork** instead of
taking the first child. The last of those six is the one that matters — a step
with no branches must never show the chooser, or the ordinary lesson has been
traded away for the branching one. Four more with batch 53 — edit, rename, save
as a new version — of which the one that earns its place asserts on the
**request** and not on the screen: a rename must not mention `positionList` at
all, because a body that mentions it can write `position_list = NULL` and take
every step of a tutorial with it.

Eleven more on the backend the same day, with `POST /lessons/:id/clone` — „save
this tutorial as a new version" — which is phase 0 of
`docs/PLAN-TUTORIJAL.md`. Two of them were proved by mutation, and they are the
two worth knowing about: a clone **mints a fresh id for every copied step**
(a step id resolves a schedule row and a recorded answer, so two tutorials
carrying one is a child's progress appearing in the wrong copy), and it shortens
a long title rather than letting `VARCHAR(255)` overflow into a 500 that reads
as „cloning is broken".

Thirteen more on 6.9.2026, and they were written **before** the screen they
judge — `TutorialStudioScreen`, phase 4a. Five drive the screen through its own
controls (the board reporting a move, the strip, the sheet at a fork), four pin
the draft's wire shape, and four say what the screen must never become: no
second board, tree or cursor of its own, and one named predicate deciding where
the door to it is drawn. Seven mutations were run against them; **one survived
at first** — deleting the flush that writes the draft when the screen closes
left the gate green, because in a test the debounced timer outlives the widget
and writes the same thing a moment later. The gate now closes the screen inside
that half-second. That is the general lesson, not a footnote: a timer that fires
after the thing it belongs to is gone proves nothing about a window that took
the whole process with it.

Eight more on 6.9.2026, for a question that carried the line answering it. A
step's `pgn` is not redacted on its way to a child — the line *is* the lesson —
and the viewer draws the move strip for every kind, so an `ask_move` step with a
line showed the answer to anyone who pressed „Sledeći potez". The editor is the
one place a step's kind is written, and it now asks before making that
combination, warns on a step already in it, and refuses to save one. **That is
the single refusal the editor makes on its own**, and the reason is written
beside it: the server stores `pgn` as opaque text and has no PGN reader, so it
cannot make this one, and giving it one would be a second parser disagreeing
with the app's. Six mutations, all six caught.

Thirteen more with batch 54, the authoring half of the tutorial studio: the
eleven of its gate, one of the batch's own, and one the lead added while grading
— the tutorial's **name** reached the controller and never the draft, so it was
the one thing that did not come back when the screen was reopened, with every
example beside it that did. Two things that batch is worth remembering for.
**A `// ignore_for_file` kept the analyzer at 29 by hiding three new infos**
rather than by not adding them, and the report called that „adequately
resolved" — so *compare the list* is not enough on its own; check that nothing
new is suppressed. And three of its report's sections were written rather than
measured, all three shaped like proof, while its one genuine correction was
worth more than the rest of the document put together.

Fifteen more with batch 55, which gave the step editor add, remove and reorder
— twelve of its gate and three of the batch's own. The gate is written the way
it is because **the server's guard against a lost step id cannot fire for that
batch**: `PUT /lessons/:id` answers 409 only when the stored and sent lists are
the same length, and adding or removing a step changes the length. A step id is
what `assignment_items` and `review_items` name a step by, and nothing joins on
it.

Two lessons about the lead's own gates came out of it. **A test that rules out
one wrong answer has not proved the right one**: „the selection follows the
step" only checked that a particular other step's sentence was absent, and a
mutation leaving the selection on the old slot passed it. And **a finder that is
unique today stops being unique when the same gate mandates a second place for
the same string** — `find.text` on a step's name, once a title field exists.
The batch worked around that second one by appending a zero-width space to the
title in the editing field; it declared it and recommended the right fix, which
is what got applied.

**Both numbers above were measured on `master` on 6.9.2026, after
`feat/tutorijal` merged** — 1436 in the app with 1 skipped, 956 on the backend
with `.env` moved aside, which is the environment CI actually has.

Twenty-two more on 6.9.2026 with P0–P2 of `docs/PLAN-STUDIO-REDIZAJN.md`,
the model half of the studio redesign — **1458 in the app, 1 skipped; the
backend is untouched and stays at 956.** A tutorial's part stopped being
flattened to `fen` + `pgn` when it was finished, which is the whole reason a
second, weaker editing screen had to exist beside the studio: nothing could read
a `pgn` back into an `AnalysisNode`, so a finished part could never be reopened.
Four things from it are worth carrying:

**The reader is `LessonStepLine`, and `_importPgn` is not a substitute.**
`AnalysisStudioScreen._importPgn` goes through `chess.load_pgn` and
`getHistory()`, which keeps the main line and silently drops every comment,
every `[%cal]`, every `[%csl]` and every variation. Reopening a tutorial through
it would have looked perfect and lost the lesson. `lib/features/tutorial_studio/
services/step_tree.dart` crosses from `MoveNode` to `AnalysisNode` and parses
nothing a second time.

**A byte-identical round trip is impossible if the `pgn` is always re-exported**
— `PgnExporterService` stamps a fresh `[Date]` on every call. So an untouched
part is written back as the exact text it was read from, and the cache is
invalidated by comparing `treeSignature` against the tree itself. Deliberately
not a `bool edited` flag: a flag is the version of this that fails silently, and
one mutator forgetting to set it would write a stale line over a trainer's edit.

**`acceptedSans` was missing from the model and nobody had noticed**, because
nothing had ever read a saved step back. The server stores it; a round trip
without it would have deleted a trainer's extra correct moves the first time
they renamed a tutorial. The byte-identical test is what found it, which is
exactly what that kind of test is for.

**A `contains` over a directory also matches a doc comment.** Widening
`tutorial_authoring_test.dart`'s source-reading check from one file to the
feature made it fail on prose in a comment explaining why `PgnExporterService`
is *not* called there. It asks about **imports** now, which is what says the code
reaches for a class. Same family as the 1600-character slice: a source-reading
test is only as good as the thing it actually matches.

Fifteen more the same day with P3a, the save routing — **1473 in the app, 1
skipped** — and one of them is a fault that predates the whole plan. **A part
with no moves was sending no line at all.** `pgnForSave` judged a part by its
move count, and the note about the starting position, the arrows and the
coloured squares live on the **root**, which is the only place they can live:
„pogledaj polje d5" is a whole step, and `PgnExporterService` had been taught to
write that comment ahead of move one precisely so it could travel. The writer
threw it away again on the way out; the child got a bare diagram and nobody was
told. Inherited from batch 54's `movesSan.isEmpty ? '' : pgn` and true for as
long as that line existed.

**How it was found is the part worth copying.** A mutation on the P3a gate
survived — „`markSaved` forgets the stored text" stayed green — and the reflex
of blaming the mutation would have lost it. The test had built its part through
`fromStep`, which arrives *already* pristine, so it could not tell. Rewritten to
start from a part written by hand, it went red for the mutation **and stayed
red** after that fix, which is when the real bug came out. A surviving mutation
is a question, not a verdict: it says this test cannot see, and what it cannot
see is sometimes not the thing you were mutating.

Nine more with P3b, the entry flow — **1482 in the app, 1 skipped** — and one
lesson about gates rather than about code. Two phases of that plan had to edit
files the plan itself had said would „pass unedited": once to widen a
source-reading check from one file to a directory when the code it watches moved
one layer down, and once because a screen's constructor changed. Both times the
assertions were untouched and green. **„Passes unedited" is the right instinct
and the wrong words** — a fixture is not a claim about behaviour, and holding a
file literally unedited would have meant keeping a redundant second way to open a
screen so that a constructor call need not move. Say „its assertions are
unchanged", and then say which fixtures moved.

Fifteen more with batch 56, the studio's front door — **1497 in the app, 1
skipped** — and with it the sharpest lesson of the lot, which is about how the
analyzer was being read.

**„29 infos, no errors, no warnings" was reported three times and was false.**
The check was `flutter analyze | grep -cE "^\s+(info|warning|error)"`, and
`flutter analyze` indents `info` lines by three spaces while printing `warning`
at **column 0**. `\s+` requires at least one space, so the pattern could not
match a warning at all: it counted 29 infos and called that the whole list. An
unused import had been warning since P1. The batch harness uses `\s*` and
caught it on the very next run; the worker's report had transcribed the warning
in plain sight.

**A check that cannot fail is not a check**, and this is the same family as the
1600-character function slice and the idioms gate that matched prose. The
summary line `flutter analyze` prints on its own — „30 issues found" — needs no
pattern and would have said so. Read that, and grep with `^\s*(warning|error)`
if you want the detail.

One more, about running the suite rather than about the code:
`test/opening_book_service_test.dart` takes ~20 s to load the bundled ECO
dataset and **times out when anything else heavy runs beside it**. It failed
twice while a `flutter analyze` and a second `flutter test` were running in
parallel, and passed solo both times afterwards. Measure the suite with nothing
else running, or you will spend an hour on a regression that is not there.

Eighteen more with batch 57, the „Delovi tutorijala" panel — **1515 in the app,
1 skipped**; the backend is untouched at 956. Fourteen are the batch's gate and
four the lead's, and the four are the entry.

**A mutation the lead ran survived, and the surviving mutation was the finding.**
Emptying the screen's `_renumberGeneratedTitles()` left all fourteen of the
batch's tests green, because `TutorialSectionsPanel` labels any
generated-looking title from its own **row index** — it drew the right words
over the wrong data. `TutorialSection.toJson` sends that title to the server as
the step's name, so a part moved to the front while its stored title still says
„Deo 2" ships a tutorial numbered the opposite way from the screen that wrote
it. `test/tutorial_section_titles_test.dart` asserts on the **request** for
exactly that reason, and was watched failing on the mutation before being
believed. Same lesson as P3a's: a surviving mutation is a question about what
the test cannot see, not a verdict on the mutation.

**A gate that cannot be satisfied is a gate that will be worked around.** The
strings gate failed the batch for removing two *empty* literals — the
`controller.text = ''` pair, deleted because clearing the fields now goes
through `_loadSelectedSection()`, which is the one reader. Fixed in the gate
rather than by an allowance: `_norm` drops empty and whitespace-only literals on
both sides, because a string with no characters holds no wording to protect. An
allowance would have cleared one batch and left the next refactor of a
controller to hit the same wall.

One more, small and recurring: the numbering rule arrived written in **five
places** — four pasted loops in the screen, each compiling its `RegExp` inside a
loop, and once more in the panel. It is `generatedSectionTitle` /
`isGeneratedSectionTitle` in the model now. Same family as the three
hand-written copies of one subquery that all forgot `status = 'accepted'`.

Nine more with batch 58, the studio's split layout — **1524 in the app, 1
skipped**; the backend is untouched at 956. The lesson is not in the diff, which
was clean in one round with no existing test needing an edit.

**The gate was proved satisfiable before it was handed over, by building the
whole layout once as a throwaway and then discarding it.** It was not
satisfiable as first written, and half an hour of trial bought three corrections
that would otherwise have cost rounds. The largest: „Sačuvaj tutorijal" pinned
under the scrolling half sat exactly where `AppFeedback` draws its SnackBar, so
a refusal covered the button it was refusing — and one of the six taps on it in
the frozen `tutorial_authoring_test.dart` failed against a covered control. In
the AppBar the trial suite was green with **no edit to any other test**, which
is exactly what the batch then achieved. The other two: a `Flexible`, not an
`Expanded`, inside `TutorialSectionsPanel`, because the same widget still lays
out in the narrow branch where its height is unbounded; and centring measured on
`BoardWithCoordinates` rather than on the board, because the rank and file
labels sit on two of four sides, so the board is deliberately off centre inside
its own widget — the gate's first version demanded an asymmetry that would have
been a bug if anyone had built it.

**A gate's own helper can be the flaky part.** The first version made the lower
half tall by tapping „Dodaj odgovor" four times, and the taps began missing as
soon as the layout under test worked: the controls a split pushes below a fold
are exactly the ones such a helper reaches for. It failed only in file order,
which is the worst way to find out. Both fixtures are data now — a saved lesson
carrying six answers, and one carrying fourteen parts.

One more, from the strings gate: it reported `'tutorial-title'` and „Naziv
tutorijala" as **added** in a batch that added no copy, which is what a *second
copy* looks like from outside — the title field and the sections panel had been
written once per layout branch, the title carrying a verbatim duplicate of the
comment explaining it. A gate that counts literals catches a duplicated widget
for free.

Fifteen more with P6's lead half — `beatsOf`, the pure function the „Tok"
timeline is a rendering of — **1539 in the app, 1 skipped**. Nine mutations, all
nine caught. Two things came out of writing it that the plan did not have.

**A move number cannot be counted from the root.** A tutorial part may open on
any position, so the ply is not the move number and only the FEN knows where
the counting started. That rule already existed, private, inside
`VisualMoveTreeWidget`; it is `AnalysisNode.moveNumberLabel` now, with the old
caller pointed at it, because the timeline needing the same sentence is exactly
the moment a second copy gets written.

**A „root" that has a parent is reachable in this codebase**, and the first
version of `beatsOf` recursed on it for ever. The studio hands the function
`_rootNode` and `_currentNode`, and a section swapped underneath while one of
them is held is how that arrives. It terminates, with a test.

And a lesson about a gate that has nothing to do with the code it guards:
**`IndexedStack` keeps a hidden tab built but offstage, and `find.byType` skips
offstage widgets.** P6a puts the tree behind a „Stablo" tab, so a helper
written as `find.byType(AnalysisMoveTreeWidget).first` throws „Bad state: No
element" and takes a dozen assertions with it — in three files, none of whose
assertions are about tabs. Those helpers now pass `skipOffstage: false`, which
changes nothing today.

One of that group was not a fixture problem but an over-broad assertion:
`tutorial_authoring_test.dart` said `find.text(sentence)` **findsNothing** to
mean „the field no longer holds the previous sentence", and the timeline draws
that sentence on its own card — correctly. A working feature would have failed
it. It asks about the `TextField` now. Same family as batch 55's finder that
stopped being unique once a second place for the string existed: **an assertion
of absence is a claim about the whole screen, and the screen keeps growing.**

Twelve more with batch 59, the „Tok" timeline — **1551 in the app, 1 skipped**;
the backend is untouched at 956. Nine gates green in one round, no existing test
edited, and the diff is a rendering of a function that was already gated. **Where
a batch has a pure core, land it as the lead's own commit before the widget
batch, not inside it**: everything about *what* the timeline says was decided in
`beatsOf` and proved by mutation, so the widget batch had nothing left to be
wrong about.

Three more the same day, and they came out of a **trial build of the next
batch** rather than out of the batch itself — **1554 in the app, 1 skipped**,
measured on `master` on 7.9.2026 with nothing else running; the backend is
untouched at 956. Opening a saved tutorial and pressing „Sačuvaj tutorijal"
without touching anything downgraded a question to a plain position, silently:
`initState` set the title and the FEN by hand and never called
`_loadSelectedSection()`, so the part's kind, task and answers sat at their
defaults and the first `_persist()` wrote those defaults back over it. The
model's round trip was byte-identical throughout and stayed so — the loss was on
the way through the screen, which is why `test/tutorial_reopen_test.dart` drives
the widget and reads the request. **The trial for a batch is worth running even
when the gate is already written**, and this is the third in a row that paid for
itself before the worker started.

Nine more with batch 60, where the timeline became the surface the tutorial is
written on — **1563 in the app, 1 skipped**; the backend is untouched at 956.
Nine gates green in one round, no existing test edited, and two lessons that
cost a mutation each.

**A gate that reads an exported PGN by string position cannot tell which move a
comment belongs to.** „Typing into a card writes that card's node" asserted that
the sentence stands before `e5` — and a mutation writing every sentence onto the
node the author is *standing on* passed it, because a saved tutorial opens with
the cursor at the root and `PgnExporterService` writes a root comment ahead of
move one. Both placements are „before e5". The test stands on the last beat now
and reads the saved line back through `LessonStepLine`, asking which move
carries the comment — the same rule the writer already follows, applied to the
test. The batch's own report had found the hole and named the fix.

**A widget whose `Key` changes is a widget that was thrown away**, and the thing
thrown away here was the caret. A beat card's field is `example-sentence` when
that card is current and `beat-comment-<index>` otherwise, so clicking into
another card's sentence changes its key, unmounts the element, and a `TextField`
that builds its own `FocusNode` loses focus at exactly the moment the trainer
started to type. No test can see it — `enterText` focuses the field itself — so
it was measured with a throwaway probe reading `EditableText.focusNode.hasFocus`
after a real tap, against a control that tapped the current card's field. The
node belongs to the card now.

Thirty more on 7.9.2026 with P7a, where the trainer finally draws on the board —
**1593 in the app, 1 skipped**; the backend is untouched at 956. Nineteen are
the lead's headless controller and eleven the batch's. The feature is worth one
sentence: `AnalysisNode` has carried `arrows` and `squares` since phase 2 of the
interactive lesson plan, the exporter writes `[%cal]` and `[%csl]`, the viewer
draws them — and **nothing anywhere wrote one**, so every arrow in every lesson
until now was typed into a PGN by hand. A model can be complete, round-tripped
and tested for months with no way for a human to put anything into it.

Two lessons about the harness, both from gates that failed work they had asked
for.

**Seeing a file and allowing it are two different gates.** The batch's one new
file was left out of the run's `untracked` allowance because an earlier fix had
taught `changed_dart_files` to *see* untracked lib files — which is what makes
the string and scale scanners open them, and says nothing about the tree gate,
whose whole job is to fail a file nobody named. Fourth time this mechanism has
failed correct work; the fix is always naming what was asked for.

**A contrast reading can be a cross product of two ternaries.**
`backgroundColor: on ? accent : null` against `foregroundColor: on ? canvas :
textPrimary` was reported as `accent` under `textPrimary` — a pairing the screen
never draws, because the two conditions are the same one. Fixed in the widget
rather than by an allowance: two whole styles instead of one built from four
conditions, so each branch carries its own pair. The scanner stays conservative
on purpose — one that paired branches by guessing would hide a real failure —
so **when two properties of one widget vary together, write the variants out**.

Twelve more the same day with P7b, which moved the room onto that controller and
closed P7 — **1605 in the app, 1 skipped**; the backend is untouched at 956.
Three fields and two methods left `chess_game_screen.dart`, so the drawing rule
has one home and two callers.

**The tests came first, and that order was the whole safety story.** All twelve
were green against the unchanged room before a line of the move was written, and
green after. Two of the four mutations **survived at first** — deleting the
cancel of a half-drawn arrow from `_selectNode` and from the move handler left
everything green, because nothing in the file walked the move tree with a
pending arrow. Two tests closed that, both watched failing on the mutation that
found them. Had this been one batch rather than two, that gap would have shipped
into the screen a live lesson runs on.

**A screen this size is testable in one entry and nobody had tried.** The room
looked unreachable — sockets, a partner, a session — and `STUDIO` is the one
room code whose `initState` asks for none of them, with the socket built
`disableAutoConnect` and the API already injectable. Twelve widget tests came out
of a screen that had none. When a refactor is blocked on „that screen cannot be
tested", spend twenty minutes proving it before believing it.

Fifteen more with P8, which closed `PLAN-STUDIO-REDIZAJN` — **1620 in the app, 1
skipped**; the backend is untouched at 956. The studio makes every refusal the
step editor it retires used to make, and that editor is now unlinked on Windows
and untouched everywhere else.

**A rule about the lesson must not be asked of the serialised text.** The
studio's answer-leak refusal judged a part by `pgnForSave.trim().isNotEmpty` —
and a part with *no moves* still exports a `pgn` when its root carries a note, an
arrow or a coloured square, because the exporter writes those ahead of move one
on purpose so „pogledaj polje d5" can travel. So „Nađi najbolji potez" with an
arrow drawn on the weak square was refused for carrying a line it does not have.
It asks the tree now. Worth noticing *why* it surfaced when it did: the fault was
harmless until P7a gave trainers a way to draw at all, and would have arrived
with the first real tutorial. **A dormant bug wakes up when the feature it
depends on ships**, and the feature that wakes it is usually not the one that
contains it.

**A shared fixture id plus a singleton draft slot is a test that reads another
test's leftovers.** The studio adopts a stored draft when its `lessonId` matches,
and a screen flushes its draft on dispose — so a file whose fixtures all said
lesson 31 watched a perfectly good question refused for two correct answers left
behind by the test before it. Mint an id per test.

**A test that asserts which screen opens is a test about the machine it runs
on.** `tutorial_versions_test.dart` asserted that „Uredi" opens the old panel;
after D8 that is true only where the studio does not exist, so it would pass on a
developer's Windows box and fail on CI, or the reverse. It pins
`debugTutorialStudioAvailable` now. Third time this local-versus-CI shape has
cost something here.

They are here so a suite that quietly stops
running half of itself is visible; if the number you get is lower, find out why
before carrying on.

The one skip is the golden screenshot group, skipped unconditionally in
`dart_test.yaml`. `--tags golden` alone does **not** run it — that selects the
tests and the skip still skips them, so the run exits 0 saying "All tests
skipped". Run them with `flutter test --tags golden --run-skipped`.

**`flutter analyze` does not exit clean, and has not for a long time.** It
reports 29 issues, every one of them `info` level and every one of them
`curly_braces_in_flow_control_structures`, spread over
`positional_evaluator_service.dart`, `tactical_motif_detector.dart`,
`game_analysis_walker_service.dart`, `review_api_service.dart`,
`ai_studio_screen.dart` and `matrix_filter_panel.dart`. This file used to say
"must be clean", which is worse than saying nothing: it makes a red exit code
look like the normal state, so a real error added tomorrow reads as the same
failure as today's. **What must hold is zero errors, zero warnings, and no new
infos — compare the list, not the exit code.** Clearing the 29 is a fine
standalone chore and would restore the simpler rule.

Run `dart format` on any Dart file you edit — CI does not enforce it, but the
formatter reindents aggressively and an unformatted file turns the next diff
into noise.

## Rules that bite

**The repository is public.** Never put secrets, IP addresses, email addresses,
account or cluster identifiers into `docs/`, comments, or commit messages. Real
values belong in `.env` on the machine that needs them. `.env.example` is the
authoritative list of environment variables — add new ones there, and the
deploy script picks them up automatically.

**`chess_backend/uploads/` is the only copy of every recording made.** It is
gitignored, it is never deleted by cleanup code, and it must never be committed.
Rendered MP4 exports are different: they are reproducible, so they age out on a
retention timer.

Since 26.8.2026 it can no longer hold a child's voice: audio is accepted only
from a room whose sole occupant is its adult owner (`services/
recordingConsent.js`). That is the reason the rule exists — `uploads/` is the
one thing here that cannot be reproduced, anonymised or taken back.

**The backend requires Node >= 22.15.** The Lichess puzzle import uses
`zlib.zstd*`, which does not exist before that. This already cost one silently
red CI pipeline.

**The branch is `master`**, and it is the default branch. CI (`.github/workflows/
ci_cd.yml`) triggers on pushes to it and builds an APK artifact after the tests.

**Never name the product "Chess Master" or "Chessmaster"** in anything
user-facing — it is Ubisoft's brand. The application id is
`rs.pejovic.chesscoach`, deliberately decoupled from whatever the brand ends up
being.

**Language:** the user writes in Serbian and reads English, so **reply in
English** and write new `docs/` in English. Code comments and commit messages
are English, as before. Two things stay Serbian no matter what: user-facing
strings in the app, because the users are Serbian children and trainers, and the
legal texts (`docs/politika-privatnosti.md`, `docs/saglasnost-roditelja.md`),
because a lawyer approved that exact wording for Serbia. The existing Serbian
docs stay Serbian — follow whichever register a file already uses, and translate
one only when asked to.

## The recurring bug in this codebase

Steps that skip silently, report success, and fail one layer or one run later.
It has appeared five times: `zlib.zstd*` missing on old Node, a `certbot` guard
that skipped reinstalling TLS and dropped the host to port 80, `sed s/^KEY=.*/`
doing nothing when the key is absent, an unverified database certificate that
looked exactly like a verified one, and a `server.js` that did not parse — two
`const seat` in one block — while `npm test` stayed green, because the two tests
that look at that file read it as **text** and search it for a function name.
`test/sources_compile.test.js` now compiles every server source, and a second
test asserts `server.js` is actually in the walk.

Two more, both on 25.8.2026. A token outlived the account it named: `jwt.verify`
proves this server issued the slip and nothing else, so a deleted account kept a
working login for the rest of its seven days — and after a `RESTART IDENTITY`
the same slip was a credential for whoever inherited the id. Every gate now asks
whether the row is still there (`services/accountGuard.js`), with **three**
answers, since "the database did not answer" must not read as "you were
deleted".

A message must never be able to take down the action it reports on. Twice now:
playback that never started because a failing audio call sat in front of the
timer, and a recording that would not stop for a child whose parent had refused
it, because `showSnackBar` threw first. **Do the thing, then say it** — and say
it through `AppFeedback`, which cannot throw. All 82 raw
`ScaffoldMessenger` calls in `lib/` were moved onto it on 25.8.2026, and
`test/app_feedback_guard_test.dart` fails if one comes back. That sweep found
the guard itself still throwing: the helpers built their `SnackBar` — and with
it `context.colors`, which is `Theme.of(context)` — *before* the mounted check
and the `try`, so an ancestor lookup ran in front of the guard against ancestor
lookups. `_show` now takes a builder and builds inside. Same lesson as the one
below: prove a guard by mutation before believing it.

And the guard written for it did not guard: it read a fixed 1600 characters from
the start of each function, which ran into the next one, so removing the check
still matched — in a different function. **Read a function body by matching
braces, never by slicing, and prove any source-reading test by mutation before
believing it.**

When adding a guard or a fallback, prefer a loud failure. `DB_CA_PATH` pointing
at a missing file deliberately kills the process rather than downgrading to an
unverified connection — copy that instinct.

One more on 5.9.2026, and it is the local-versus-CI version of the same shape.
A test that `require`s a **route** drags in the whole server chain, and
`middleware/auth` calls `process.exit(1)` at import when `JWT_SECRET` is
missing. `db.js` and `middleware/auth.js` both call `dotenv.config()`, so on a
machine with a `.env` the require succeeds and the suite is green; CI has no
`.env`, so the same file killed the test process and took all 895 tests with
it. **A test that reaches a route must set the environment that route's imports
demand, and the way to check is to run `npm test` with `.env` moved aside** —
that is the environment CI actually has.

One more on 6.9.2026, and it is the oldest shape in this list wearing a new
coat. „Napravi korak od ove pozicije" sent a lesson step's `fen` from
`_currentNode` and its `pgn` from an export of `_rootNode`, and
`MoveTree.parsePgn` skips a move it cannot play **without a word** — so a
trainer standing anywhere but the root of their tree saved a step whose line
could not be replayed, was told „Korak uspešno dodat", and found out when a
child opened a board with no moves on it. Parity decided whether the student got
an empty line or a shortened one, so half the positions in any tree looked
correct. The fix is two rules worth copying: **one node answers for both
fields** (`StudioLessonStep.from`), and **the writer reads its own work back
through the reader's parser before saving it** — `LessonStepLine` is that one
parser, `rejectedMoves` is the number it reports, and a step that does not
replay is refused rather than stored.

## Two ways a Flutter release build hides a mistake

Both cost time on 20.8.2026, and neither shows up in tests, in `flutter
analyze`, or in the log.

**A release build paints no overflow warning.** In debug, a `Row` wider than the
screen gets the yellow-and-black stripes and an assertion. In release it is
simply clipped: the row looks shorter than it is and the buttons past the edge
are unreachable. Three of these were found by looking at a phone — the move
navigation strip, the Analysis Studio's app bar, and the notifications dialog,
which had a fixed content width of 360 on a 360 dp phone. Where a row can grow,
use `Wrap`; where a width is fixed, take it from `MediaQuery` instead. A widget
test at `Size(360, 640)` catches it, because in a *test* build the overflow does
throw.

**`flutter build windows` can ship a stale icon font.** Icons are tree-shaken
into `MaterialIcons-Regular.otf`, and that file is not always regenerated when
new icons are referenced: two builds in a row kept a font from before the icons
were added, so `Icons.handshake` and `Icons.chat_bubble_outline` rendered as
nothing at all. Icons already used elsewhere in the app kept working, which is
what makes it look like a problem with those two icons. If a newly added icon
comes out blank, check the timestamp:

```bash
stat -c '%y %s' chess_app/build/flutter_assets/fonts/MaterialIcons-Regular.otf
```

Delete that file and build again. `build_and_deploy.ps1` (Android) regenerates
it, so the same build can be right on the phone and wrong on Windows.

## Where things are written down

- `docs/STANJE-RADA.md` — the handoff document, and the only one worth reading
  whole. What is still live: where we are, what is open, what is next, and the
  rules that still hold. Read it before proposing work; much of the obvious
  backlog is already done.
- `docs/arhiva/` — closed history split out on 27.8.2026, in two files: the
  handoff doc's finished sections (fixes with a ✅ and a date, measurements, the
  routes by which the current shape was reached) and the verification items that
  are closed in full. **Never read an archive file up front.** `grep` it when you
  need the *why* of an older decision, or the evidence that something passed,
  and read only the section you hit.
  Item numbers in `TODO-provera.md` were deliberately **not** renumbered when it
  was split — other docs cite them by number ("stavka 27"), so gaps in the
  numbering are expected, not a mistake.
- `docs/TODO-provera.md` — features that pass tests but have never been watched
  running. Ticked off only after the user confirms live.
- `docs/TODO-objavljivanje.md` — publishing steps, in dependency order.

Keep these current as part of the work, not afterwards. When something is
verified live, say who verified it and when. New entries go in
`docs/STANJE-RADA.md`; move one to `docs/arhiva/` once it is done, verified, and
nothing upcoming depends on reading it.

**These docs are big, and reading one whole is a real cost.** `TODO-provera.md`
is 75 KB and `TODO-objavljivanje.md` 45 KB — roughly 22k and 14k tokens, more
than that in Serbian. `grep` for the item you need and read around the hit;
slurping all three costs more context than the code they describe. The handoff
doc was 242 KB and `TODO-provera.md` 101 KB until they were split, which is why
every session used to open above 150k tokens before doing any work.

## Server

A provisioned droplet exists (`chess-backend-ams3`, Ubuntu 26.04 LTS, AMS3) with
nginx, a TLS certificate and a `chess-backend` systemd unit. **The service is
deliberately stopped and disabled**: while the app still points at a local
backend, two servers on one database split `uploads/` and live session state.
The switch happens in one direction, once a domain is chosen — the current
hostname is an interim `sslip.io` name.

`deploy/provision.sh` sets up the base system, `deploy/app-setup.sh` the
application half. Both are idempotent and both are meant to be re-run; that is
how two of the bugs above were found.

**Do not close port 80.** The backend is on `api.chesstrainers.app`, whose
certificate renews itself over HTTP-01 — that check reaches the host on port 80
and nowhere else. `.app` is HSTS-preloaded, so browsers never use plain HTTP and
closing 80 looks like tidying up; it silently breaks renewal, and the site
disappears three months later. Same shape as everything in the section above.

## Consent: built, and where it still has holes

*Trainer* is a position in a relationship, not a property of a person, so
`users.role` plays no part in teaching — the same account is a trainer in one
edge and a student in another. `users.role` survives only for `'admin'`.

A `trainer_students` row grants nothing until `status = 'accepted'`, and either
side may start the request; the sender chooses which capacity they are claiming.
**Verified live by the user on 17.8.2026**: invitation, greyed-out pending row,
acceptance, and assigning a lesson immediately afterwards.

Rights are read through exactly two places, and new code must use them rather
than write the condition again:

- `trainerOwnsStudent` (`services/assignmentService.js`) — homework, reports.
- `acceptedTrainersOf` (`services/relationshipService.js`) — anything a student
  reads *because* someone teaches them.

Three hand-written copies of that second subquery all forgot the status, so an
unanswered request already unlocked the sender's lessons. A test reads the source
and fails if a fourth copy appears.

**The parent half is built** (25.8.2026, not yet watched running). A minor's
relationship stops at `awaiting_parent`, the parent confirms through a link to a
page this backend serves, and `parent_consent_at/ip/version` are written from
that page — not from a code read out to a child, which proves a mail arrived and
nothing more. The age threshold (`AGE_OF_CONSENT`) and the text version
(`PARENT_CONSENT_VERSION`) are configuration, because a lawyer confirmed the
wording on 25.8.2026 **for Serbia only, and said so explicitly**; the country
list in Play Console is a decision somebody has to make rather than a default to
accept. Two rules that came out of it and hold generally: an age is read when an
edge is created and never applied backwards over edges that exist — **tell the
trainer, do not rewrite their lesson** — and the parent is asked **two**
questions rather than three.

The third question — recording the lesson — was removed on 26.8.2026, one day
after it was built. `parent_allows_recording` had spent its first hours written
by the parent's page and read by nobody; the enforcement written for it worked,
and then the feature it enforced was deleted. **A lesson is not recorded at all
any more, by anybody, under any consent.** The replay survives, silently: a
recording is a `timeline_json` and `audio_url` was always nullable.

The reasoning, because it generalises: the feature bought a replay with sound
and cost a per-market legal text about children's voices plus the worst breach
this project could have had. Removing it barely shrank the consent machinery —
that is driven by minors *having accounts*, not by recording — but it removed
the one artefact that could not be taken back. **Exposure falls by holding less,
not by getting an opinion that holding it is allowed.**

Still open: the account-level lock (a minor with no trainer uses the app as
before, since the approved text is per-trainer), and parent observation of a
lesson, which is designed (`docs/STANJE-RADA.md`, "Dogovoren model uloga i
nadzora") and not built.
