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
cd chess_app && flutter test          # 1884 tests, 1 skipped, rest green
cd chess_app && flutter analyze       # exits 1 on 29 known infos — read the list
cd chess_backend && npm test          # node --test, 1172 tests, all green
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

**Measured again on `master` on 7.9.2026: 1717 in the app with 1 skipped, 958
on the backend with `.env` moved aside.** Between 1554 and here: the „PGN" tab
(`PLAN-PGN-TEKST`), then five pieces of one day's live feedback — a result
marker glued to the last move being counted as a rejected one, the board's
orientation reaching the child at last, `splitForQuestion`, and the panel's
three actions with the naming that goes with them.

Three things from that day worth carrying. **A guard that asks for a word
boundary on both sides of `*` can never match one at the end of a line** — the
star stayed on `Nxb4*`, the move was refused as unplayable, and a space in
front of it made the same line work. **Absence is a third answer**: a stored
step that says nothing about its orientation is not a step that says „White",
and a part read back adopts the guess the viewer was already making rather than
stamping `false` over every old black-to-move part on the next save. And **a
new place for a string breaks an old assertion of uniqueness** — a part is now
named by its first sentence, which put that sentence in the list of parts as
well as in the field it was typed into, and `findsOneWidget` over the whole
screen went red in a file with nothing to do with naming. Third time in this
repository; scope the finder, do not weaken it.

**Four more on 7.9.2026 — 1721 in the app, 1 skipped; the backend is
untouched.** A fork was drawn nowhere the child could see it: the branch
chooser opened only from the „Sledeći potez" button, and the narrated walk
stops at a fork on purpose, so a listening child met the end of the lesson
instead of a choice. It cost most in the shape `splitForQuestion` now writes,
where the continuation part **opens** on the fork. Two things worth carrying.
**A feature can be complete, tested and unreachable** — the sidelines were
parsed, stored, round-tripped and offered by a sheet nobody knew to open; every
layer was right and the child still never saw them, which no test of any layer
could say. And, fourth time now: **an assertion of absence is a claim about the
whole screen.** `tutorial_branching_test.dart` said the chooser's sentence was
absent after one move to mean „no sheet opened", and the sentence is written
inline now; it asks about `BottomSheet` instead. Scope the finder, do not
weaken it.

**Six more the same day — 1727 in the app, 1 skipped.** A move could be taken
back only by retyping the line in the „PGN" tab. `AnalysisMoveTreeWidget` has
drawn „Unapredi u Glavnu Liniju" and „Obriši Ovu Varijantu" on a long-press
since the Analysis Studio was built, and the tutorial studio took the widget
**without either callback**: the sheet opened, the trainer pressed „Obriši",
the sheet closed and the move stayed. **A widget that draws an action it was
given no way to perform is this repository's recurring fault wearing a menu** —
the entries are drawn only where a callback exists now, and the sheet does not
open at all when none does. Deleting asks first only when the move carries
words, drawings or moves under it: a dialog on every deletion is a dialog that
gets dismissed unread. Three mutations, all three caught; the one worth keeping
is that the cursor must leave a subtree before it is detached, or the board is
left standing on a position the part no longer holds.

**Three more, and the count is 1730 on 7.9.2026.** Two live findings that had
been written down as „good, but…" under a fix that had just landed: „Primeni"
put the trainer back on the opening position after they had typed a move on the
end of the line, and a part added with „Odavde" came up White-side-down under a
trainer who had turned the board. **A note filed under a green tick is still a
report** — both of these were sitting inside items marked ok, and the wording
that found them was „da, to je dobro, ali…".

**Seven more, 1737 on 7.9.2026, and the lesson is about where a capability
lives.** „Ne postoji mogućnost brisanja tutorijala" and „tutorijal ne može da
se pošalje đaku" were both true for the user while the server had `DELETE
/lessons/:id` and `POST /assignments/lesson`, and the app called both — from
the lesson list inside a room, and from „Napredak učenika". **A capability that
exists at every layer and is reachable from nowhere the user goes is a
capability they do not have**, and no test of any layer can say so. Both live
on the saved-tutorials list now, which is also why that button stopped saying
„Otvori sačuvani tutorijal": somebody looking for a way to delete one does not
open a door labelled „open". Two mutations worth keeping: a row leaves the list
only when the server says it is gone, and a student who has not accepted the
invitation is not offered — the same `status = 'accepted'` this repository has
already lost three times.

**Three more, 1740 on 7.9.2026, and one of them replaced a rule this file was
proud of.** The narrated walk used to stop at a part that opened on a different
position — „a join is a continuation, a new diagram is a page-turn the child
turns themselves" — and it had a test saying so by name. The trainer pressed
the play button, watched one part, and reported the second one as missing.
**A ▶ promises the whole thing**, and the child that walk exists for is the one
listening rather than pressing; the rule also predated „Traži potez na tabli",
which now routinely cuts one part into a chain of three. It crosses every
boundary now, waits a beat before a board it is about to rearrange, and still
stops where the child has something to do — a fork, a question, the end. The
button says „Pusti tutorijal".

Two things about the harness came with it. **The analyzer reported 30, and the
30th was a `warning` in a test file committed one commit earlier** — a fixture
parameter with no test using it — while that commit's message said „analyze
unchanged at 29 infos". Analyze had been run *before* the file was written. Run
it after, and read the summary line. And **a test for a pause passed with the
pause deleted**: with an instant voice every sentence resolves in a microtask,
so a part whose first beat is silent spends its first 1400 ms in the ordinary
wait for a wordless move, and the assertion could not tell the two waits apart.
The fixture writes a sentence on the root now. Third time in this file: a check
that cannot fail is not a check.

**Four more on 8.9.2026 — 1744 in the app, 1 skipped.** A pasted PGN with no
`[FEN]` was refused with a count of moves that would not play and no question,
because there was nothing to ask *about*: the text says nothing about where it
starts. What was missing is that **a game with no header is a game from the
standard opening position** — so when the text replays cleanly from there and
not from the part's own board, the same three-way question can be asked, and it
is grounded in a second reading rather than in a guess about what the trainer
meant. It is offered only when that reading is whole: a text that half fits the
opening position is not a game from it, and moving the part onto a position
that also rejects moves would trade one silent loss for another. When nothing
can be offered, the refusal now says the text carries no starting position,
which is the answer to „why did it not ask me anything?".

**One more the same day, and it is a lesson about a flag with three readers.**
A student on Windows opened their trainer's tutorial from „Sačuvani
tutorijali", edited it, and was refused only at save. `GET /lessons` hands an
account everything the trainers who teach them have saved, marked
`is_trainer_lesson`; every write path is closed (`user_id = me OR trainer_id =
me` on update, delete and clone), so nothing leaked and nothing could be
changed. **The card was simply the one reader of that flag that ignored it** —
the room's lesson list splits its two sections by it and „Dodeli lekciju"
filters on it. Worth noticing what it cost the day before: the bin and the
„pošalji" added on 7.9.2026 were being drawn on rows the account could never
act on, one commit after a lesson about exactly that. **When a flag says
„somebody else's", every list that draws actions has to read it**, and the way
to find the readers is to grep the flag rather than to trust that the newest
list was written knowing about it.

**Five more with phase 1a of `docs/PLAN-ZAVRSNICA.md` — 1749, 1 skipped.** Two
board-setup dialogs, two files with the same name, and the owner met the
difference before the code admitted it. The survivor is the one that can open
**on the position in front of you**; the room's own always came up on the
standard opening, so setting a study up from the board you were looking at
meant building it again from nothing. Three things came out of it.

**Three of the five tabs were dead in one caller.** „PGN Uvoz", „Otvaranja" and
„Chess.com/Lichess" hand their result over through `onPgnLoaded`, and the
tutorial studio passes none — deliberately, because importing a PGN into a tree
is the Analysis Studio's job. So picking „Najdorf" there closed the dialog and
dropped the opening. Same shape as the tree menu two days earlier, and the
third instance in a week: **a widget that takes optional callbacks must draw
only what it was given.**

**A test caught the change that a squeeze would have hidden.** Naming the
castling rights („Beli O-O" instead of `K`) pushed the row onto a second line
and overflowed a 320 dp phone by sixteen pixels — invisible in a release build,
where the chips would simply have been unreachable, which is the exact bug that
test file was written for. The fix is a branch, not a squeeze: on a tab too
narrow or too short the column scrolls and the board is sized from the width.
And the first threshold was wrong for a reason worth keeping — **controls that
grow sideways pay for it in height**, so a height test alone let the phone
through.

**A source-reading gate reads by matching parentheses.** The one added here
asserts every caller passes `initialFen:`, and its first version sliced 400
characters — the same mistake as the 1600-character function slice this file
already records. It also counted the dialog's own constructor as a caller.

**Three more with phase 1b — 1752, 1 skipped.** The screens were renamed, not
merged: „Priprema" for the room alone with your library, „Analiza" for the
engine and the tree, „Soba" and „Studio za tutorijal" unchanged, so the word
*studio* names one thing. The finding that made the rename obvious is worth
keeping: **the two screens that „look the same" had home-screen descriptions
that described the same thing** — „Samostalni rad, FEN postavljanje, PGN i
Stockfish analiza" against „Slobodna šahovska tabla za duboku analizu … rad sa
PGN/FEN pozicijama". The names were never the whole problem; the sentences under
them were. `test/screen_names_test.dart` keeps both halves: the retired names
stay retired, and each card still says what is different about its screen.

**Twenty more with phase 2's core — 1772, 1 skipped.** `tutorialVideoOf` turns
a tutorial into the event list `chess_backend/videoRenderer.js` renders, and it
is the **lead's** half on purpose: batch 61's lesson was that a batch with a
finished core has nothing left to be wrong about. Three mutations, all caught.

**The list is built in the app and not on the server, and that is a rule rather
than a convenience.** The server stores a step's `pgn` as opaque text and has no
PGN reader; giving it one would be a second parser disagreeing with this app's,
which this project has already paid for once.

**`MoveTree` names its own root `'Root'`**, and `readStepTree` copied that
through as a move — so the opening position of every reopened part carried a
move called Root with a `from`/`to` built from two empty strings. Nothing drew
it: „Tok" decides by index and `moveNumberLabel` by parentage, so it sat there
for as long as the reader existed and surfaced the first time something asked
the node itself. Fixed at the crossing *and* at the new caller, because a
producer that trusts a placeholder is one refactor from printing it.

And the harness gained its first non-Flutter gate: `gate_backend_tests` runs
`npm test` **with `.env` moved aside**, which is the environment CI has —
`middleware/auth` calls `process.exit(1)` at import without `JWT_SECRET`, and
that has already taken 895 tests down silently. It skips itself when a batch
left `chess_backend/` alone. Proved both ways before use: it passes at 958,
fails on a raised expectation, and fails on a deliberately broken test.

**Two more in the app and six on the backend on 8.9.2026, with the age floor —
1774 and 964.** The app now ships as a General Audience product, 13+, rather
than as one directed to children, and that declaration was **false in the code
until this landed**: there was no minimum age anywhere. `AGE_OF_CONSENT`
defaults to 16 but that is a consent threshold, not a floor, and an
eight-year-old could open an account — whereupon `parentConsentService` routed
them into a parent's confirmation, which is machinery built to let a child *in*.

**COPPA triggers on actual knowledge**, and an app that asks for a birth year
has it, so a declaration cannot answer for a stored `birth_year` saying eleven.
The route refuses now and **does not write the year** — storing it would leave
the one row the decision exists to avoid, and would lock out the correction the
route documents (a mistyped 2017 must be restatable).

Two things worth carrying. **The floor reads the same conservative age
everything else does** — `statedAge`, which answers with the age certainly
reached, since a year alone cannot say whether a birthday has passed. A second,
more generous reading invented for this one question is how two definitions of
one number come to disagree. The cost is stated rather than hidden: somebody
born thirteen calendar years ago waits until the year turns. And **the parental
machinery needed no new concept** — with nothing below thirteen reaching it, the
band it covers is exactly 13 to `AGE_OF_CONSENT - 1`, so it stopped answering
„may this child be here at all" and started answering „is this teenager in a
country whose threshold is above thirteen?". One changed question, no new code.

**Batch 65a merged on 8.9.2026 and the count did not move: 1772 passing, 1
skipped, 29 infos, zero warnings, zero errors, all re-measured on `master` with
nothing else running.** It translated 29 files — the analysis studio, the AI
hub and the position scanner, 268 lines — and 17 test files with them, so a
suite that stayed still is the correct result rather than a suspicious one. All
eleven gates green in one round, which is the first time in this series.

Three things from it are worth carrying.

**When a batch touches one end of a vocabulary whose other end is already
written, quote the written end into the brief.** The two findings panels label
the motifs that `tactical_motif_detector.dart` and
`positional_evaluator_service.dart` name in whole sentences, and a panel saying
„Double pawns" over a sentence saying „Doubled pawns" is the vocabulary coming
apart in the one place a user sees both at once. The brief carried a second
table of 21 terms *already shipped* alongside the table of new ones; all 21 came
back matching.

**A translation can widen a matcher without anybody choosing to.** The scanner
test asserted `contains('slika')` against a message whose sibling says `slike` —
not a substring, so it discriminated. Translated, that became `contains('image')`
against a sibling saying `images` — which *is* a substring, so that one
assertion stopped discriminating. A mutation swapping the two classifications is
still caught, by the neighbouring test's `contains('images')`, so nothing was
changed; but only the mutation could say so. **Read a translated negative or
narrow assertion again: English substrings nest where Serbian inflections do
not.**

**A plural test is renamed, never trimmed.** `gamesLabel` went from three
Serbian forms to two English ones and kept all eight inputs (1, 2, 4, 5, 11, 21,
22, 112). Batch 64's equivalent dropped two whole tests and the suite count fell
by two — defensible, and checked input by input at the time, but the rename is
the shape that does not need checking.

**And the third report in a row with accurate numbers and an invented section.**
Sections 5.3 and 5.5 quoted Serbian originals and English replacements that
`grep` finds nowhere — a scanner message about „low lighting or a blurry image"
for a feature that reads **text-typeset diagrams and never an image**, two board
legality messages, and four invented opening names beside four real ones.
Section 3 is subtler and more instructive: its per-file table is honest
arithmetic — the total, 558, is exactly `git diff --numstat` added lines —
wearing the wrong label, „translated literals", where the real count is 268. **A
true number under a false name is harder to catch than an invented one**, and it
is the reason the count in a report is never taken without re-deriving what it
counts.

**The English pivot closed on 8.9.2026 and the count is 1762, 1 skipped, with
`flutter analyze` at 29 infos and zero warnings.** `gate_english_ui` over all
**258** files under `chess_app/lib` is clean: no Serbian letter survives in any
string literal. `docs/gates/` is empty — `vocabulary_en_test.dart` and
`screen_names_en_test.dart` are ordinary tests now and the Serbian pair they
succeed is deleted.

The arithmetic, because a moving count is where a suite quietly stops running
half of itself: 1772 + 1 (the voice fix replaced two tests with three) − 12 (the
two `serbian_plural` files, 7 + 5, counted before deleting) − 8 + 9 (the Serbian
anchors out, the English ones in) = **1762**. Every step was measured.

Four things from the last two batches are worth carrying.

**When a batch touches one end of a vocabulary whose other end is already
written, quote the written end into the brief.** 65a's brief carried a second
table of 21 terms *already shipped* in `tactical_motif_detector.dart` and
`positional_evaluator_service.dart`, because two panels in that batch label the
motifs those files name in whole sentences. All 21 came back matching. A panel
reading „Double pawns" over a sentence reading „Doubled pawns" is the vocabulary
coming apart in the one place a user sees both at once.

**English substrings nest where Serbian inflections do not.** `contains('slika')`
is not a substring of `slike`; `contains('image')` **is** a substring of
`images`, so one scanner assertion silently stopped discriminating when it was
translated. A mutation proved the file still bites on its neighbour, which is the
only thing that could have said so. Re-read every translated `contains` and
`isNot(contains(...))`: ask whether the new string can also match the case the
test rules out.

**A guard can contradict the contract it enforces.** The vocabulary anchor
failed the finished sweep on nine „Lesson" hits, and not one was the word on a
screen — two wire values, a hero tag, two route paths, four interpolations of a
local variable called `lesson`. The glossary already says *in code, `lesson`
means the tutorial*, and the table, the wire type and the routes are
deliberately not renamed. Fixed in the gate, not with nine allowances: `${...}`
is stripped **from the line** before literals are found (a literal holding
nested quotes is sliced by a naive regex into the gap *between* two literals,
which reads as copy), and a literal with no capital and no space is a value
rather than a sentence. The narrowing was proved by two mutations before it was
believed, because a narrowing that cannot fail is the same as deleting the test.

**A fixture can encode the very assumption under test.** The pivot left
`SpeechService` still asking for `['sr', 'hr', 'bs', 'sh', 'me']`, and it never
falls back to an unrelated language — deliberately, since a voice reading the
wrong language sounds like the feature works. So on an ordinary English machine
the state is `noVoice` and **every read-aloud button in the app says nothing**.
No test could see it: all five files that touch speech handed the service a fake
engine reporting `['sr-RS']`, and `VoicelessTts` returned `['en-US']` in order
to *mean* „no voice". It was found by a log line in a test run. Twenty-odd tests
agreed with each other and with nothing real.

**The count went *down* on 8.9.2026, from 1774 to 1772, and that is correct.**
Batch 64 translated the repertoire and the trainers, and two tests went with the
language: `tactics_skipped_homework_test.dart` had four, one per Serbian
plural form — singular accusative, paucal, genitive plural, and the teens that
catch a naive implementation — and English has two. **Every input the four
asserted is asserted by the two** (1, 21, 101, 2, 4, 23, 5, 10, 0, 11, 12, 14,
111), so nothing is uncovered; there were simply two fewer forms to name. A
falling count is exactly what the test gate exists to stop, so it was checked
input by input before it was believed.

Three things from that batch are worth carrying, and none is about the code it
produced.

**A timeout is not a failure of the worker's pace when the brief caused it.**
Round one hit 75 minutes having finished every one of the twenty-six files —
`gate_english_ui` confirmed it — and having updated almost none of the tests,
because the task said „after each file, run the tests for the test files you
touched". Twenty-six suite runs of three minutes each. The instruction was
mine and it is withdrawn.

**Two rounds were lost to a worker that would not stop saying „I will wait for
the test run to finish", and the cause is now settled — it was the network.**
Written first as „this worker cannot wait for a subprocess". The owner corrected
that on 8.9.2026: their internet had dropped during the run. **Batch 65a
settled it the same day.** That run says the same nine „I have launched the full
test suite and am waiting for the execution to complete" sentences — and then
comes back with the number, in 48 minutes of a 75-minute budget, all gates
green. On a working connection the model waits for a subprocess perfectly well.
The lesson is about the lead, not the worker: **a stall has an environment as
well as a model, and naming the model first is the cheaper story, not the
likelier one.**

What does *not* depend on which is true: **brief a batch so it needs at most one
full suite run, at the end.** Batch 64 was told to run the tests after each of
twenty-six files, and twenty-six runs at three minutes is seventy-eight — more
than the whole budget, before the model does any thinking at all. That
instruction was mine and it is withdrawn on arithmetic, not on a diagnosis.

**A translation's failing assertions are recoverable from the failure output.**
`Found 0 widgets with text "…"` names the exact string, and the English for it
is already in the diff — so the remaining forty-one were finished by reading
the test output and the worker's own diff rather than by inventing wording.
Multi-line assertions are what a line-by-line pass misses, and they are the
ones that were left.

**The server speaks English too, as of 9.9.2026 — batches 66a and 66b, 71
files.** The counts did not move: **1762 in the app with 1 skipped, 964 on the
backend** with `.env` moved aside, analyze at 29 infos, all re-measured on
`master` with nothing else running. A translation that changes no count is the
correct result rather than a suspicious one. What stays Serbian is deliberate
and short: server logs and code comments, `routes/consent.js` and the
parent-consent mail (a lawyer's wording for Serbia), and the role values in
`db.js`'s CHECK constraint.

Five things from that pair are worth carrying, and only the first is about
translation.

**A string on the server is either a sentence or a value, and three of them
were both.** `customPuzzleJudge.judgeAttempt` returns a `reason` that the
tutorial viewer prints to a student verbatim when the answer is wrong — and that
`custom_puzzle_solver_screen.dart` *compares*, character for character, to
explain that a different mate still counted. `positionScanner/verify.mjs` wrote
`sideSource = 'nepoznato'`, and `ScannedPosition.needsReview` fires on that
word: it is the flag that puts a doubtful scan in front of the trainer, so
translating the one word would have stopped flagging them, silently, with both
suites green. **A batch told not to touch `chess_app/` cannot be handed a string
like that** — the lead moved both ends in one commit first, and took those two
files out of the batch's list.

**A gate that matches a literal with no newline in it cannot see a document.**
`gate_english_backend` matched a backtick template with no newline in it, so
every template literal that
wraps was invisible: the parent report's HTML, and both model prompts, 135 lines
in all. A batch could have translated every one-line literal, left three whole
documents in Serbian, and been told it was clean. Fourth entry in the family
that already holds the 1600-character function slice, the `\s+` that could not
match a warning at column 0, and the log-skip that compiled with a backspace
byte where a word-boundary escape was meant. **When a check reads source as text, ask what shape
of the thing it is reading it cannot represent.**

**A source-reading test must strip strings, not just comments.**
`repertoire_route_wiring.test.js` asks which request parameters a handler
actually uses, and stripped comments only. While the messages were Serbian no
sentence happened to contain `color`, so nothing showed; the English pivot made
it ordinary and the batch was failed for writing „Could not read color status."
inside the `/color` handler — then **reworded two messages to get past the
check**, which is what a gate that cannot be satisfied always buys. The false
pass was the worse half and had been there from the start: a parameter read out
of the request and never passed on counts as used the moment any message names
it, which is the exact bug that file was written to catch. A template literal is
not blanked whole — `${color}` inside a sentence is a real use.

**Two English words are not evidence of Serbian.** `table` and `figure` came out
of the no-diacritic word list the moment the gate was pointed at a server:
`table` is in every SQL statement and every `<table>` in the report, and the
Serbian those entries existed for is carried by `tabla`, `tablu`, `tabli`,
`figura` and `figuru` anyway. A gate that fires on `FROM user_games` is a gate
the next round argues with.

**Quote the written end into the brief, and then check the batch quoted it
back.** `reportService.js`'s motif table is a hand-kept duplicate of the app's,
which was already English, so the brief said copy it key for key — and the two
tables now agree value for value, which was verified by comparing them rather
than by reading the report's claim that they do. The same brief's vocabulary
table said „vežbanje → practice" **without checking the app**, where every
repertoire screen says *Drill*; the batch's report caught it. A vocabulary rule
written from the outside is a guess until somebody greps the end that already
exists.

One more about reading a report: its per-file table was honest work and its
stated total was not — the rows sum to 389 and the line above them says 328.
Same family as the „true number under a false name" already in this file, and
the same remedy: re-derive any number you are about to repeat.

**Phase 2 of `docs/PLAN-ZAVRSNICA.md` closed on 9.9.2026 — a tutorial exports as
a video — and the counts are 1766 in the app with 1 skipped and 985 on the
backend**, both measured on `master` with nothing else running. Twenty-one of
the backend's are the renderer's first tests ever, and they read pixels out of a
rendered frame.

**Nobody had ever looked at a frame**, and one trial render found two faults
that were in every export this project has produced. The title carried `♟`,
which no font on that server has, so every frame has shown a tofu box. And not
one file letter has ever been drawn: they were painted in the colour of the
square they stand on, eight times over — the parity that is right for the ranks
is inverted for the files, and one expression served both. The feature was
verified live, twice, by people watching the video; nobody looked at a *frame*.
**When a feature's output is a picture, look at the picture.**

Four things about the tests written for it, and three are about tests that
proved nothing.

**A pixel probe can be answered by the wrong thing.** „The file letters are
readable" asked whether anything in the strip along the bottom edge differed
from the square above it — and the pieces standing on rank one answered yes on
their own, so putting the bug back left it green. The board is empty in that
test now and the question is asked per file: is there ink on this square that is
not the colour of this square?

**An assertion with an escape clause is not an assertion.** „The board is the
size the caption band left it" was written as *within 6 px, or bigger* — and
bigger is the exact failure it existed to catch. It measures the board's width
now, which cannot be confused with the caption drawn below it.

**A layout fault can be one tap away from where you are looking.** A throwaway
probe at 360 dp reported an 88 px overflow on the saved-tutorials row, and I
read it as three icons crowding the row. Measuring said the row was fine: the
overflow was the „Video ready!" dialog, whose title is drawn in the theme's
headline size, and it appears only *after* the export finishes. The compact
buttons I had already written were reverted — **churn a measurement does not
support** — and what was real was the missing ellipsis on a row title, because a
tutorial is named by its first sentence and the test fixture was a single word.
**A fixture that is shorter than the real thing is a fixture that cannot fail.**

**And `takeException` is not a layout assertion.** An overflow throws in a test
build and paints nothing in a release one, so a test that asks only for the
exception passes the moment the widget tree is disposed differently. Ask whether
the button is inside the dialog: that is what „unreachable" actually means.

**Measured on `master` on 9.9.2026: 1778 in the app with 1 skipped, and 1036 on
the backend with `.env` moved aside**, after the video renderer stopped carrying
pieces the app does not draw. Three sets lived on the server — an „Alpha", a
„Staunton" and the app's own — named by a `pieceStyle` on the wire and offered
by a dropdown in the replay export dialog, and **the piece-skin recolouring
iterated the Staunton one**. So a trainer who had chosen nothing got a film in
shapes they had never seen, one commit after the export was taught to wear the
app's colours. Two sets and the wire value are deleted; a skin is colours over
the one set, which is what the app itself does.

Three things from it are worth carrying.

**A colour substitution must be one pass over the attributes, not a chain.** The
classic skin fills a black piece `#000000` and outlines it `#000000`; a chain
that turns the fill into the new colour and then looks for the decoration's
colour can paint the same attribute twice, and the skin that triggers it is the
default one. `repaint()` rewrites each `fill=`/`stroke=` at most once.

**Which colour means what is read off `chess_vectors_flutter`'s own
parameters.** On a white piece the black `fill=` is the knight's eye, which the
app paints with `strokeColor`; on a black piece a white `stroke=` is an inlay —
the rook's lines, the king's cross — which it paints with `decorationColor`.
Guessing from the attribute alone would have painted the eye and the outline the
same and stopped a knight looking like a knight.

**The test asserts on path data, not on a name.** „`pieceStyle: 'classic'`" was
true in every request all along; the file it named held a different set. A guard
that reads the knight's own curve is the one a swapped set cannot pass.

The bar the app draws now moves in ten-point steps and says how long is left —
both asked for live. The estimate is a rate measured over this render, from its
own first reading, so a captioned film at 4 fps and a silent one at 1 fps are
each timed by their own frames; it is null until there are two readings to take
a rate from, and null again on the last frame, where what is left is ffmpeg
closing the file. **Null is „no estimate", never zero** — and under ten seconds
the words stop counting down and say „almost done", because a countdown to zero
is a promise the frame count cannot keep.

**1779 in the app with 1 skipped and 1037 on the backend, measured on `master`
on 9.9.2026**, after the progress bar was reported live as never moving: it said
„Starting…" from the first frame to the last and then the video appeared. The
percentage was right, `renderProgress` held it, the route read it, the app
polled every 900 ms — and **not one poll was answered until the render
finished.**

**Nothing in the frame loop returned to the event loop.** `canvas.toBuffer`
draws the PNG on this thread, the piece set is cached after the first frame, and
an `await` on an already-settled promise is a microtask: the whole render was
one uninterrupted burst, and every request arriving during it waited behind the
one being served. That is not only the poll — a render made the whole process
unresponsive for its duration. One `await new Promise(setImmediate)` per frame
fixes it, and `test/render_yields.test.js` proves it by counting how many times
a `setImmediate` chain gets its turn during a twelve-frame render: eight or more
with the yield, **exactly one** without it.

Two things worth carrying. **Every layer can be right and the feature still
dead** — this is the same shape as the arrows nothing wrote and the sheet nobody
could open, except that here the broken part was not a layer at all but the
runtime underneath them. And **the tests could not see it because each half was
tested alone**: the backend suite calls `report` and `statusOf` directly, the
widget test fakes the HTTP, and neither ever asks whether this process would
answer while it is busy. When a feature is „A writes, B reads, while C runs",
one of the tests has to run C.

The film also got a 1080p switch, asked for live. Two resolutions, not three:
720p is what a video watched on a phone wants, and 1080p is for YouTube — which
gives a 720p upload a lower bitrate ladder, and the caption text and the thin
piece outlines go first — or a projector. Measured on an eighteen-second film:
1.2 s and 129 KB against 2.5 s and 192 KB. 480p is not offered, because it saves
about 30 KB on that film — flat graphics on flat colour give h.264 almost
nothing to compress — and pays for it in the caption a child reads. The export
sheet now opens for **every** export rather than only where the server can
speak: a switch reachable only where piper happens to be installed is one half
the trainers do not have.

**Twenty-one more on the backend the same day — 1058 — and they came from asking
piper's own phonemiser a question instead of guessing at it, and then from
asking what happens when two trainers press render at once.** „Vidi da li se
potezi navedeni u komentaru izgovaraju dobro na drugim jezicima." Nothing
anywhere expanded notation, so every voice spelled it:

    en-US  Bd5 → „bee dee five"     de  Bd5 → „beh deh fünf"
    es     Bd5 → „be de cinco"      it  Bd5 → „bi di cinque"
    fr     Bd5 → „boulevard cinq"   and O-O → „oh oh" in all five

The French one is the argument in one line: espeak knows `Bd` as the
abbreviation for *boulevard*, so a bishop move became a street. A `+` came out
as „plus" and a `#` as „hash". `services/spokenMoves.js` writes a move out in
the language of the voice — „Läufer d 5", „alfil d 5", „fou d 5" — and the
expansions were phonemised back to check they land where they should.

Three things worth carrying. **The caption and the voice are two texts now**:
the screen keeps the trainer's „Bd5" and only what goes to the synthesiser is
expanded, which is exactly what a trainer at a board does. **A rewriter that
runs inside a trainer's sentence has to be strict** — a from-file with no piece
letter is only legal in a capture, and without that rule a word like „be4"
reads as a move; the guard is mutation-proved, as is the English fallback,
because „bishop d 5" in the wrong accent is still a move and „boulevard cinq" is
not. And **the notation read is English SAN and only that**: a German trainer's
„Ld5" is left alone, because this app writes English SAN and the PGN standard
stores it — one parser, not two disagreeing.

**How to find out what a voice will do with a string, without listening to
it**: piper hands the text to eSpeak-NG, and that is askable directly —

```python
from piper.phonemize_espeak import EspeakPhonemizer
print(''.join(EspeakPhonemizer().phonemize('fr', 'Bd5')[0]))
```

**And the server was the second writer of a rule the app already had.** The
first version of `spokenMoves.js` was written from scratch, and
`chess_app/lib/core/services/speech_text.dart` has been reading moves aloud
correctly since long before the film could speak — better, too: it says the rank
as a *word* („e six", not „e 6") because a digit before a full stop is read as
an ordinal in more than one language, it keeps the file as a bare letter because
spelling one out made the g-file come out as „dzh" in the Serbian build, and it
names the pawn in a capture because „e takes d five" sounds like a piece whose
name was swallowed. The server's module is that file's rules now, with five
vocabularies instead of one, and the first test in `spoken_moves.test.js`
asserts the **app's own expected strings** from `speech_text_test.dart`, so the
two ends cannot drift. Look for the existing implementation before writing the
second one — this file already records three cases where it existed and nobody
found it, and here it was better than what replaced it.

**„Šta se dešava ako dva ili više korisnika renderuju u isto vreme?"** They
interleave, and that is only true since the yield: three concurrent renders took
6.8 s against 2.4 s for one, and all three finished together rather than one
starving the others. Two places where concurrent renders wrote to one path did
not survive the question. **A clock is not a name** — the export filename ended
at `Date.now()`, so two renders of one tutorial starting in the same millisecond
agreed on it, the second overwrote the first, and both download links pointed at
that one file; the signed token did not help, being bound to a filename that
both tokens named. And **the TTS cache was written in place**: the key is the
sentence and the voice, so two films narrating the same sentence at once both
found it missing and both copied onto the final path, where a half-written clip
is a beat with the wrong length and audio that drifts for the rest of the film.
It lands beside the target and is renamed onto it now.

**A before-and-after assertion cannot see atomicity** — a straight copy also
ends with the right bytes in the right place — so that test watches
`fs.copyFileSync` and asserts the cache path is never its destination. Same
family as every other check in this file that could not fail.

**The answer to that was a queue** — „neko od korisnika će time svoj video
dobiti pre, a ovaj drugi kasnije (kao što bi i dobio da rade paralelno)", which
is exactly right: the same total, differently distributed, and the first
trainer is served in their own time instead of everybody finishing late
together. `services/renderQueue.js` draws one film at a time (`RENDER_CONCURRENCY`),
narration included, since synthesis is the same machine doing the same work.

**The waiting is bounded, and that is the part worth carrying.** The render
happens inside the request the client already made, and that request has two
ceilings above it: nginx closes a proxied request after 300 s (`deploy/
app-setup.sh`) and the app's own HTTP timeout is five minutes. An unbounded
queue turns „you are fourth" into a request that dies on the wire while the
server carries on drawing a film nobody will collect — so a full queue
(`RENDER_QUEUE_MAX`, two waiting) is refused at once with a 429 and a sentence,
before any work is done and before anything is metered. **A queue is a promise
about time, and a promise longer than the connection is a lie.**

Two smaller things. The screen had to learn a third state: a queued render is
not „Starting…" over an empty bar, because that is precisely what a render that
began and froze looks like — it says how many films are in front of it, and the
bar stays indeterminate until its turn. And the position is re-announced every
time the queue moves, because a place that never changes is indistinguishable
from a queue that has stopped.

**A test's own hold can be the thing that hangs it.** The first version of the
full-queue test released the one hold that existed, the next filler started and
built a new one, and the queue never drained — the file timed out at fifteen
seconds a test, in tests that had nothing to do with queues. One gate that every
filler awaits, rather than a hold made inside each task.

**Eleven more on the backend on 9.9.2026 — 1069 with `.env` moved aside** — and
they are about a render stopping. A client that hit the 300 s ceiling went away
and the server drew for minutes more, wrote a 14 MB MP4 whose download link was
in the response nobody received, and **held the one render slot** for the rest
of that film, so every other trainer queued behind it or got a 429.
`RENDER_QUEUE_MAX` bounds the queue and says nothing about one render outliving
its own connection. `services/renderAbort.js` is one `AbortSignal` from
`res.on('close')` down to piper and ffmpeg, both killed with SIGKILL.

Three things from it. **`writableFinished` is the whole correctness of that
listener** — a successful response also emits `close`, so without that question
every render would be cancelled at the moment it succeeded. **Two checks in one
loop cannot be proved**: deleting either left the other stopping the render, so
one was deleted and the survivor now fails on mutation. And **a test that hangs
is worse than one that fails** — the mutation „`killOnAbort` does not kill" took
the whole suite to a 300 s stall with no message, which is why every question in
`render_abort.test.js` goes through a deadline. The one guard that stays
unproved is `ffmpeg.stdin.on('error')`: a faked pipe cannot break the way a real
one does, and the line stays because an unhandled stream error takes the process
down. It says so in the code.

**A still of a film nobody has rendered — 9.9.2026, and the counts are 1786 in
the app with 1 skipped and 1080 on the backend** with `.env` moved aside. Eleven
of the backend's are the preview route, five of the app's the door to it.
`renderPreviewFrame` folds the same `applyEvent` the render loop uses and calls
the same `renderFrameBuffer`, so a preview is the film's own drawing rather than
a second one — and it needs no ffmpeg, no queue slot and no file, which is what
makes it answerable while somebody else's film is being drawn.

**The app's count in this file had gone stale at 1779 while the suite was
1781**, left behind by commits that added app tests without touching it. The
delta was re-derived by counting test declarations against `HEAD` rather than
by trusting either number — same rule as everywhere else here: re-derive a count
before repeating it.

Two things from it. **A preview's three frames differed by the clock, not the
board.** „The frames are different" stayed true under a mutation that drew beat
0 three times, because the timer overlay says 00:00, 00:04, 00:09. A second test
gives every beat the same timestamp, so any difference at all is the position —
same family as the file letters answered by the pieces standing on rank one.
And **a comment claimed more than the code did**: `captionBand` reaches
`renderFrameBuffer` only as `captionBand > 0`, so the line count changes
nothing, and the rule worth testing is that a wordless beat inside a talking
film is still drawn with the caption column. The test that failed is what found
the overstatement.

**A tutorial keeps its film — 9.9.2026, 1790 in the app with 1 skipped and 1090
on the backend.** Every export used to write a file named by a clock and tell
nobody: the only reference was the link in the response, whose token expires in
**thirty minutes**, so closing the „Video ready!" dialog meant rendering the
whole film again — while the file sat in `exports/` for a fortnight,
unreachable, until the retention timer took it. Ten exports of one tutorial were
ten orphans. `saved_lessons` now carries the filename, and `GET /lessons/:id/
video` mints a fresh link on demand.

**A filename and not a URL**, because a URL carries a token and a stored token
outlives its own expiry. **The row is written before the old file is deleted**:
a crash between the two leaves a file nothing points at, which retention
collects, while the other order leaves a row naming a file that is gone — a
trainer pressing Download and getting nothing. And **the retention sweep clears
the new column too**, or the list draws a download on a row whose file that same
sweep just deleted.

Three answers, told apart on purpose: no film yet (404), a film whose file has
aged out (410, „export it again"), or here it is. They lead a trainer to
different buttons, so they must not read the same.

One lesson about an old test. `retention.test.js` asserted `queries.length ===
1` — a claim about the sweep's *shape* rather than about what it clears, and
false the moment a second table kept a filename. It finds its query by name now.

**One trainer could take the whole machine, and did — 9.9.2026, backend 1098.**
With `RENDER_CONCURRENCY` 1 and `RENDER_QUEUE_MAX` 2, three renders is the
number that fits, so pressing „Export" three times filled the queue and every
other trainer was refused with a 429 until it drained. FIFO has no idea who is
asking. Two rules now, and they answer different questions: **round-robin**
decides order (the next film comes from the account that has gone longest
without a turn), and **`RENDER_ACCOUNT_MAX`** decides admission (two per
account, drawing plus waiting). A job with no owner is its own bucket, so
nothing can block an unrelated job by sharing one.

Three things worth carrying.

**The number a trainer is told has to be the number that comes true.**
Announcing an array index was right while the queue was first-come-first-served
and became a lie the moment it was not — the place is computed by playing the
rule forward over a copy of the queue.

**Two refusals need two sentences.** „The server is rendering other videos" is
false when the other videos are your own, and a trainer told that waits for
somebody else to finish instead of for themselves. `RenderAccountBusy` is a
separate class for exactly that reason.

**A mutation reported „survived" when it had actually hung.** Deleting the cap
does not make the third render fail — it makes it *queue*, so `assert.rejects`
never settles and the file times out. Every refusal test races a deadline now,
and the mutation harness prints HUNG rather than counting it as a pass. Second
time in one day: a test that hangs is worse than one that fails.

One old assertion changed rather than a fixture: `render_queue.test.js` compared
the whole `snapshot()` object, so two fields added for a log line failed four
tests about something else. It asks for `running` and `waiting` now — same
family as `retention.test.js`'s „exactly one query".

**The microphone spike, 10.9.2026 — `docs/PLAN-SNIMANJE.md` phase 0.** The app
gained `record` 7.1.1 for a trainer's own narration; the counts did not move
(1790 in the app, 1098 on the backend), because a dependency and a throwaway
`tool/` entrypoint are not tests.

Four things from it, and only the first is about audio.

**`record` exposes no position at all**, so a marker is `bytes ÷ byte rate` from
`startStream`'s PCM. Measured on both targets, with `ffprobe` agreeing to the
millisecond three times over.

**The microphone warm-up is not a constant** — 668 ms on one Windows run and
100 ms on the next, same machine and code minutes apart. A latency that varies
by half a second cannot be corrected with a fixed offset, which is what settles
the question against a wall clock for good.

**A working clock proves nothing about the audio existing.** The first Windows
take was digital silence at −91 dB with a flawless byte clock, a correct wav
header and a correct `ffprobe` duration; the microphone was muted at system
level and `hasPermission` still returned true, the device still appeared in the
list, and the chunks still arrived at the right rate. An `ffmpeg` DirectShow
capture with Flutter out of the picture recorded the same silence. Same family
as every check in this file that could not fail.

**Adding one plugin broke the whole Windows build**, not just itself:
`record_windows` requires CMake 3.23 and Build Tools 2019 ships 3.20, so the app
stopped building on its main desktop target the moment the line was in
`pubspec.yaml`. After installing Build Tools 2022 the first build still failed
on a stale generator in `build/windows` — delete that directory. Worth knowing
before adding any plugin with native code: check what it does to the *other*
platform's build before believing it is additive.

**A trainer's voice over a tutorial — phases 1 and 2 of `docs/PLAN-SNIMANJE.md`,
10.9.2026: 1832 in the app with 1 skipped**, measured on `master` with nothing
else running; the backend is untouched at 1098. Forty-two tests — twenty-eight
on the core (`narration_take.dart`), fourteen on the screen — and every guard
left in either was proved by mutation. Four that could not fail were deleted
rather than kept. Not yet watched running: `TODO-provera.md`, item 138.

**`await subscription.cancel()` hangs a widget test.** A `StreamController`
with no `onCancel` returns a future already completed in the root zone, and
under `fake_async` the continuation never runs — so Stop and Discard hung in
four screen tests while the core's own tests, which have no fake clock, were
green. A cancel takes effect when it is called; there is nothing to wait for.

**A focus guard was measured, not reasoned about.** `ExcludeFocus` around the
controls and a `requestFocus` after Record both survived mutation, and a
throwaway probe said why: the Space binding sits above every control, so it is
heard before a focused button is asked, and when the Record button disappears
with the focus on it the scope hands the focus back to the node that had it
before. Both were deleted. The keyboard test stays, because it fails without
`autofocus` — which is what actually carries that path.

And `screen_names_en_test.dart` failed the shortcuts page for writing „Tutorial
Studio" inside a sentence. The copy was reworded rather than the gate widened:
the gate exists so that „studio" keeps naming one screen, and a sentence that
does not need the word is cheaper than an allowance that has to be argued.

**Phase 3 the same day — the upload — 1836 in the app with 1 skipped, 1114 on the
backend** with `.env` moved aside, both measured one after the other with
nothing else running. `POST /lessons/:id/narration` judges the file itself (the
wav's own header, the samples, the markers against both), asks who may record
before multer accepts a byte, and keeps the recording under `uploads/narration/`
— which is never served by URL. Nothing in the app calls it until phase 4.

**`uploads/` is served to anyone with a filename**, and has been since the room
could record: `express.static`, no authentication. Found in passing and flagged
as its own task rather than folded into this one; the narration folder is
refused in `middleware/uploadsStatic.js`.

**A test that sends a URL through `fetch` cannot send `..`.** A WHATWG URL
resolves `.`, `..` and `%2E%2E` before the request leaves, so a mutation
deleting the path normalisation survived a test that listed `a/../narration`
among its cases. It sends raw paths through `http.get` now. Same family as
every check in this file that could not fail: the client tidied the input the
guard existed for.

**„NOT APPLIED" is not „caught".** Three mutations never touched the file,
because `routes/lessons.js` has CRLF line endings and the patterns asked for
`\n`. A harness that only counted red runs would have reported them as proof.

**Phase 4 the same day — a film in the trainer's voice — 1846 in the app with 1
skipped, 1121 on the backend**, measured one after the other with nothing else
running; analyze at 29 infos. The export dialog offers the device's own take,
uploads it only when the server holds a different one, and the server draws the
film on the take's markers. Twenty-two mutations, all caught. Live check:
`TODO-provera.md`, item 139.

**Look at what a new path sits next to.** The export route's `finally` deletes
`narrationAudioPath`, the synthesised track, once a film is drawn. Routing a
trainer's recording through that variable — the obvious reuse — would have
deleted the only copy of their voice on the first export. It travels as
`audioFilePath` alone, and a test asserts the file is still there afterwards.

**A dialog that awaits the platform is a dialog that does not open in a test.**
Awaiting the take lookup before the export dialog put `path_provider` in front of
it, and on Windows that is real asynchronous I/O the fake clock never finishes:
twelve existing export tests stopped seeing the dialog. It opens at once now and
the row arrives with the answer — which is also better for a trainer — and a
late answer after the dialog is gone touches nothing, with a test.

**Read a test for the mutation that would survive it before running the
mutation.** Two would have: „never both voices" against a fake server that could
not speak, so `narrate` was absent either way, and „a recorded film is marked
narrated" checked only in the one test that also sent `narrate: true`. Both were
fixed before the script ran.

**Phase 5 the same day — a recording knows which beats it was made over —
1873 in the app with 1 skipped, 1126 on the backend**, measured one after the
other with nothing else running; analyze at 29 infos, zero warnings. The
arithmetic, because a moving count is where a suite quietly stops running half
of itself: +16 for `filmSignatureOf` and `takeMismatchOf`, +8 for the recording
screen and the studio's banner, +3 for the export dialog, +5 on the backend.
Fifteen mutations, and the two that survived are the two findings. Live check:
`TODO-provera.md`, item 140.

**A field no test can fail is a field nobody has read.** The signature was
position, move and sentence; deleting the move left every test green, because a
beat's fen already answers for the move that made it — two lines differing in
one move differ in every position after it. It is gone rather than kept.

**A fixture can prove the wrong component.** The test for „a part opening on
another position" used a part starting one ply later, which also changes the
number of beats — so it said nothing about the fen, and the mutation deleting
the fen survived it. It is the same tutorial on a board without queens now: same
sentences, same moves, nothing but the position different. Same family as the
file letters answered by the pieces standing on rank one.

And one about the harness: a mutation runner reading `flutter test`'s output on
Windows without an explicit encoding died on a `cp1250` decode **in the middle
of the batch**, which would have lost every verdict after it. Read a subprocess
as UTF-8 with `errors='replace'`.

**Phase 6 the same day — one question for the film's sound — 1876 in the app
with 1 skipped; the backend is untouched at 1126**, analyze at 29 infos, zero
warnings. The export sheet's two switches, „Use my recording" and „Narrate this
video", are one `RadioGroup` with three answers, each drawn only where it can be
honoured, and the question only where there are two. Eight mutations, all
caught. Live check: `TODO-provera.md`, item 141.

**A switch that hides another is a radio written as a layout.** Phase 4 kept
„never both voices" by not drawing the synthesised switch while the recording's
was on; a radio cannot hold two answers, so the rule is structural now rather
than a condition three widgets had to agree on.

**A default is not a preference.** The recording is chosen wherever it can be
used and is deliberately not remembered — and choosing it must not overwrite the
synthesised-or-silent answer, because that answer is for exactly the films the
recording cannot make. The test asserts on the stored preference, not on the
screen.

**Measure the sheet on a phone before believing it fits.** With three answers
and the voice dropdown it was 49 px taller than 360 × 640, and the test's tap on
„Higher quality (1080p)" landed on the button bar: in a release build, where an
overflow paints nothing, the switch sat under Export. The test asks for 1080p in
the request, which is what „reachable" means.

**Item 4 of part two the same day — a render that cannot finish is refused
before drawing — 1146 on the backend** with `.env` moved aside; the app is
untouched at 1876. `services/renderBudget.js` counts the frames by the
renderer's own rule and divides by a configured drawing rate; the queue carries
each job's estimate and deadline and refuses a newcomer only for lateness the
queue itself causes. Eighteen mutations, seventeen caught. Live check:
`TODO-provera.md`, item 142.

**A proved function is not a proved caller.** `revise` was mutation-proved in the
queue's own tests, and deleting the one line of the route that calls it left
everything green. The route's half needed its own test, with a harness hook to
act while the fake renderer is „drawing".

**The rule a budget reads must be tested where it lives.** „Captions → four frames
a second" had no test anywhere: a mutation drawing every film once a second
passed the whole backend suite, and that rule now decides whether a film is
refused. `framesPerSecondOf` is the one reading of it, called by the renderer and
by the budget, and it is pinned.

**A red under a mutation is not a catch until it is the right red.** That same
mutation looked caught by the full suite — by test 3, which counts files in the
shared `exports/` while other test files run in parallel. It was a flake, and the
mutation had in fact survived. Read *which* test failed before believing it.

**Item 5 of part two the same day — the render leaves the request — 1884 in the
app with 1 skipped, 1172 on the backend** with `.env` moved aside; analyze at 29
infos. A tutorial export answers 202 and its film is drawn behind the answer;
the job is a row (`tutorial_render_jobs`, `services/renderJobs.js`). With the
owner's four follow-ups the same evening: the film ceiling is 600 s, the
narration cap is derived from it and served to the app as `maxMs`, a job with a
deadline (the recorded-lesson export, still drawn inside its request) goes first
and is refused at its turn when the queue made it late, and `abortOnDisconnect`
is gone. Thirty-four mutations, all caught. Live check: `TODO-provera.md`, item
143.

**A number kept in two places by a comment is two numbers.** The narration cap
was fifteen minutes in `narrationUpload.js` and fifteen in `narration_take.dart`,
each pointing at the other. It is derived on the server now and asked for by the
app, and the app's fallback fails safe: when the server cannot be asked it stops
*earlier*, because a take cut short is always accepted.

**Priority cannot preempt.** One slot draws one film, so „give the synchronous
export priority" means in front of the films waiting, not in front of the one
being drawn. Its deadline is enforced at the door and again at its turn, and the
turn check refuses only lateness the queue caused.

**A middleware that calls `next()` without returning its promise ends a test
early.** `requireEntitlement` does, so awaiting it asserts on a response the
handler has not written yet — 200 read where the route answered 429. Capture the
handler's own promise.

**One test that forgets to open its gate can fail ten others.** A fake renderer
left „drawing" held the one-running-render index for the rest of the file, and
every later export of that tutorial got its correct 409. Read the first failure
before the other ten.

**`.env.aside` is not covered by `.gitignore`.** An earlier session moved `.env`
aside to measure like CI and never put it back; for a day the only copy of the
secrets was an untracked file one `git add` from a public repository. Move it
aside with a `trap` that restores it in the same command.

**Four more on the backend the same day — 1176 with `.env` moved aside; the app
is untouched at 1884.** „Renderuje video bez glasa iako sam stavio jezik": piper
answered `No module named piper`, the film was drawn silent, and it was
announced as ready. Two changes, and only the second is code.

**A capability check that asks about the artefacts is not a capability check.**
`piper.available()` was `modelFiles().length > 0` — is there a `.onnx` in the
voices directory — which says nothing about whether anything can read one. So
the app drew the narration switch, the server accepted `narrate: true`, and the
answer arrived a minute later, after the whole film had been drawn.
`engineReady()` is the other half: one `find_spec("piper.__main__")` per
interpreter, asynchronous because 250-430 ms belongs to a thread that is also
drawing somebody's film, cached for the life of the process. A dead engine now
means an empty voice list, so the switch is never drawn at all.

**„Installed" and „reachable from this process" are two questions.** The install
was `pip install --user`, which lives in `%APPDATA%\Python\PythonXYsite-packages` and is on `sys.path` only while the spawning environment carries
the right `APPDATA` — and `PIPER_PYTHON` was empty, meaning `python` resolved
through PATH. Two guesses, both resolved at spawn time. It is a venv now, whose
`pyvenv.cfg` sits beside its own executable: proved by removing `APPDATA` from
the environment, where the `--user` install fails and the venv imports fine. The
droplet already had this (`deploy/provision.sh` builds `/opt/piper`); the wrong
thing was the developer machine and the `.env.example` line recommending it.

**The log is UTC and the diagnosis turned on that.** `translateTime` without a
`SYS:` prefix means pino-pretty prints UTC, so `21:15:18` was `23:15:18` local —
one minute *after* the still-running server had started, not before it. Its
environment, read out of the PEB twelve minutes later, was correct in every
respect that could hide the module, and the package had not been touched since
the day before. Three ways to produce that exact message were reproduced and
none of them was what happened. **So the class of fault is gone and the trigger
of that one spawn is not explained** — which is worth saying rather than
rounding off, because the first draft of this entry blamed the environment on a
timestamp read an hour wrong.

And one from the mutation run: „`narrateFilm` says `unavailable` whatever the
reason" survived at first. Nothing tested the sentence a trainer actually reads,
and the two refusals send them to different places — one to install voices that
are already there. A test was written after the mutation asked the question.

**Ten more on the backend on 11.9.2026 — 1186 with `.env` moved aside; the app
is untouched at 1884.** Azure Speech is the fourth provider and the first cloud
voice this project can pay for: a subscription key and a region, no OAuth, no
key file, and none of the business payments profile that has kept `google.js`
written and unreachable since 9.9.2026. Piper stays installed as the fallback —
`TTS_PROVIDER` picks. Nine mutations, all caught. Live check: `TODO-provera.md`,
item 145, which needs the owner's own key.

**A trainer's sentence becomes part of an XML document, and that is the whole
risk in this provider.** Google's endpoint takes plain text, and `google.js`
says in as many words why it sends prose rather than SSML: a sentence with a
stray `<` in it is not markup that failed, it is a sentence that would be
refused. Azure's `cognitiveservices/v1` takes SSML and nothing else, so the
choice is not available — `ssmlFor` escapes and is tested, ampersand first,
because escaping `&` last turns the four escapes written before it into „and a
m p semicolon".

**A locale is not always two parts, and Serbian is why.** Azure writes Serbian
`sr-Latn-RS`, with its script in the middle, and a few regional Chinese voices
carry a third segment of their own. `languageOf` takes everything before the
**last** hyphen; the two-part reading that `google.js` uses would have sent
`xml:lang="sr-Latn"` and grouped every Serbian voice under a language that does
not exist.

**The Serbian words were recovered, not written.** `spokenMoves.js` gained an
`sr` vocabulary so „Bd5" is read „lovac d pet" rather than spelled — and the
words are `serbianSpeech` exactly as it stood in `speech_text.dart` before the
English pivot deleted it (`ce012c0^`), which trainers listened to for weeks.
This file already records three cases of a second implementation being written
because nobody looked for the first, and one of them was better than what
replaced it. `git log -S` found it in a minute.

**„Neither Google nor Azure has a Serbian voice" was repeated in three files and
had been checked against one list.** It is written in `google.js`'s header, in a
test comment, and in `tts/index.js`. Whether Azure has one is now answered by
`scripts/tts-probe.js`, which prints the list the account really has — the
comments say what was checked and against what. **A fact repeated in three
places is a fact nobody rechecks.**

One consequence not yet dealt with, and it is the app's: the voice dropdown
draws one `DropdownMenuItem` per voice, which is right for piper's six and
unusable for a cloud list of several hundred. The probe prints the count; a
language filter in the export sheet is the fix if it is as large as expected.

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
