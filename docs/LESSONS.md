# Lessons

The running log of what this project's test counts, mutations, live checks and
batches taught, in the order they happened. Until 16.9.2026 it lived in
`CLAUDE.md` under "Commands", where it was loaded into every session and every
subagent — about 45k tokens before any work began. It was moved here unchanged.

**Do not read this file whole.** `grep` for the phrase you need and read the
entry around the hit. The rules that keep recurring are distilled at the top of
`CLAUDE.md` ("What the log keeps teaching"); this file is the evidence behind
them.

**New entries go at the end of this file**, in the same shape: a bold opening
sentence with the date and the counts measured on `master`, the arithmetic when a
count moves, then only what is worth carrying. Update the counts in `CLAUDE.md`'s
"Commands" block in the same change. If an entry teaches a rule that has now
recurred, add or sharpen a line in `CLAUDE.md`'s distilled list too.

Code comments, briefs and older docs that say "CLAUDE.md records…" or "for the
reason CLAUDE.md gives" written before 16.9.2026 mean this file, unless the
rule is one of the sections still in `CLAUDE.md` (Rules that bite, the recurring
bug, the release-build traps, Server, Consent).

---

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

**Seven more in the app on 11.9.2026 — 1891 with 1 skipped, 29 infos and zero
warnings; the backend stays at 1186.** The owner's own Azure account answered
with **655 voices across 154 languages**, which turned the export sheet's voice
dropdown into a list nobody scrolls to the end of. It asks for a language first
now, and the voice list is that language's. Seven mutations, all caught.

**The probe settled a fact three files had asserted from one list.** „Neither
Google nor Azure has a Serbian voice" was written in `google.js`'s header, in a
test comment and in `tts/index.js`, and had only ever been checked against
Google. Azure has four — `sr-RS-NicholasNeural` and `sr-RS-SophieNeural`, with
their `sr-Latn-RS-` twins, in both scripts. The comments say what was checked
and against what now. **A fact repeated in three places is a fact nobody
rechecks**, and one command answered it.

**„The first voice on the list" stopped being a sane default the moment a
provider had 154 languages.** The caller fell back to `tts.voices.first` when
nothing was remembered, and the list is sorted by language — so a first-time
trainer opened on Afrikaans. It sends null now and the sheet picks: the language
of the remembered voice, else the app's own, else the top. Null also covers a
remembered voice the server no longer offers, which is what switching
`TTS_PROVIDER` does to every id at once.

**A guard on a control that nothing can reach is not a guard.** The voice
dropdown's `value` was written as „the chosen one if the list has it, else
null", and a mutation deleting that changed nothing — because every path already
kept the two in step. It is a rule at the door instead („the sheet opens on a
voice of the language it opens on"), which a fixture with a languageless voice
reaches and a mutation fails. Same family as every other check in this file that
could not fail.

**One existing assertion changed rather than a fixture, and that was right.**
`find.byType(DropdownButton<String>)` was `findsOneWidget` in two tests; there
are two dropdowns now. Both are scoped to keys rather than weakened to
`findsWidgets` — the fifth time this repository has met a finder that stopped
being unique because the screen grew.

**Four live findings on 11.9.2026, all from one evening with a real Azure
account — 1893 in the app with 1 skipped, 1202 on the backend** with `.env`
moved aside, analyze at 29 infos and zero warnings. Twenty-four mutations, all
caught.

**A rule this file was proud of had the opposite answer in another language.**
„Kad izgovara poteze Bc4, ovo c se skoro i ne čuje." Files have been bare
letters everywhere since the app's Serbian build spelled „ge" and had it read by
an English table as „dzh" — so the rule became „never spell a file". With a
Serbian voice reading Serbian that is wrong: a lone consonant is a sound and not
a word. What the old fault was really about is a voice reading a language that
is not its own, so the table belongs to the **language**: `files` is absent from
the five vocabularies whose voices already say the letter properly and present
in the two Serbian ones (be, ce, de, ef, ge, ha). Verified against the real
voice, not only in a test.

**Serbian has two scripts and Azure has both.** `sr-Latn-RS` is the Latin locale
and a plain `sr-RS` is Cyrillic, and the id is the only thing that says which,
so there are two Serbian vocabularies. What a trainer wrote is untouched either
way; only the words *added* on the way to the voice are written in the voice's
own script.

**`sans-serif` is not a font.** It is whatever the machine hands back, and on the
owner's Windows box it was a family with no Latin Extended-A — so every š, đ, č,
ć and ž in every caption of every film has been a box, since the renderer was
written. The family is not named in the fix either: it is **chosen by drawing
with it**, because `č` and `ć` are two glyphs and a font that has neither draws
the same box twice. `services/renderFont.js` compares the two, and `ж`/`ф` for
Cyrillic. **The existing pixel test could not have caught this: it asked whether
there was ink, and a box is ink.** And the test written for it failed CI for a
day, because it asserted the reported fault itself — that `sans-serif` cannot
draw č. That was true of the owner's Windows machine, and false on Ubuntu, where
`sans-serif` is DejaVu. It asks with two unassigned code points now, which every
font lacks. **A test that reproduces a fault by naming what one machine has
installed is a test of that machine.**

**The rank numbers had been invisible since the file letters were fixed.** The
9.9.2026 fix set `fillStyle` for the files and left the ranks reading it, so the
parity that was wrong for one became wrong for the other — eight numbers, none
of them drawn, two days. Both labels now ask the board's own `(row + col) % 2`
rather than a hand-written parity, and the rank test is written as the file
test's twin so the pair cannot be half-fixed again. **A fix that moves a fault
from one line to the next is what a shared `ctx` state does.**

**655 voices means a trainer needs to hear one before spending a film on it.**
„Ili da se pusti sample sa glasom da čuje, da ne ide odmah u renderovanje."
`GET /lessons/tts/sample?voice=…` speaks one sentence — through `spokenMoves`,
so what is heard is the treatment a beat will get, „lovac ce četiri" and all —
and it is refused for a voice this server did not itself list, because an
unchecked name reaches Azure as a 400 and piper as a *different model*, which
would have a trainer choosing by a voice they never heard.

Two things about testing it, both about platform channels.

**A spinner never settles.** `pumpAndSettle` after tapping a button that shows a
`CircularProgressIndicator` times out with no useful message — pump frames
explicitly, and hold the answer in a `Completer` so the button can be caught
mid-sentence. A fake that answers at once cannot show a spinner at all.

**Both halves of playing a sound are plugins**, and in a widget test neither
answers: the button spun for ever. `debugPlayVoiceSample` is the seam, in the
shape `debugTutorialStudioAvailable` already had — and the test's fake still
makes the real HTTP request, so everything but the sound is proved.

**A tutorial written outside the app can be opened inside it — 11.9.2026, and
the counts are 1942 in the app with 1 skipped and 1206 on the backend** with
`.env` moved aside, analyze at 29 infos and zero warnings. Ten mutations, all
caught. Twenty-seven tutorials had been generated as JSON against
`PGN-TUTORIAL-FORMAT.md` and there was no way to get one in but `curl`. Live
check: `TODO-provera.md`, item 147.

**The reader was already there, and that is why this is small.** A file's
`positionList` is the shape `position_list` already has, so
`TutorialDraft.fromLesson` reads it and `readStepTree` → `LessonStepLine` parses
the line — the child's own parser. What `readTutorialJson` adds is the question
that parser cannot ask: **is this file worth opening**, and if not, in which
part. It tells two faults apart, and the difference is the whole design: what
the server would **refuse** (an unloadable FEN, a solution that cannot be
played) is never sent, and what would be **stored and wrong** (a line that does
not replay, a question carrying its own answer) is reported and left to the
trainer. One file opens in the studio unsaved; several go to the library at
once, because opening twelve in an authoring screen one at a time is a chore
that gets skipped.

**The label was in the database the whole time and reachable from nowhere a
tutorial goes.** `saved_lessons.tags`, `GET /lessons/labels`, the
`includeTags`/`excludeTags` filter, `SavePositionDialog`'s chip field and
`MatrixFilterPanel` all existed; the studio simply never wrote the column. Same
shape as the arrows nothing wrote and the sheet nobody could open. Asked „should
we add a label field", the answer was to *reach* the one that was there.

**And wiring it woke a fault that had been silent because nothing exercised
it.** `PUT /lessons/:id` wrote `description = $2, tags = $3` on every request
out of `body.x || null`, and `commitDraft` mentions neither — so opening a saved
tutorial and pressing „Save tutorial" erased its description. Nothing in the app
had ever written a tutorial's description, so nobody had seen it; the JSON
import writes one, and it would have been lost on the first save. The rule
`positionList` already had now covers three columns: **a request that says
nothing about a column leaves it alone**, and an explicit `null` still clears.
Fourth time a dormant fault woke when the feature it depends on shipped.

**A parser that is lenient where the app's is strict is a repair that breaks
lines.** The one-off repair script replayed every line with python-chess, which
accepts `Bd6+` on a move that gives no check — `MoveTree.parsePgn` refuses it,
so a file that „replayed cleanly" lost four moves in the app. Writing each move
back as the board's own SAN settles wrong check marks and wrong disambiguation
in one step, and it took the clean files from 14 of 27 to 23. **When two parsers
must agree, make one of them write what the other reads.**

**A test that passes for an afternoon can be reading the test before it.** The
labels file gave every fixture lesson 31; the studio adopts a stored draft whose
`lessonId` matches and flushes on dispose, asynchronously — so one test read
labels the previous one had typed. It passed until a layout change moved the
timing. Mint an id per test; CLAUDE.md already said so and the file still did
it.

**One new field in the authoring pane overflowed the 840 dp window by 24 px.**
That pane ends in a parts list held against the bottom, and batch 58 had already
squeezed the panel's own header to fit; a release build would have drawn a parts
list with its last row missing. The title and the labels share one row now, so
the labels cost no height at all. And two gates failed the copy rather than the
code — „Open in the studio" against the rule that *studio* names one screen, and
„missing from the lesson" against the Lesson/Tutorial split. Both were reworded,
which is cheaper than an allowance that has to be argued.

**A film can be the board alone — 11.9.2026, 1956 in the app with 1 skipped and
1213 on the backend** with `.env` moved aside, analyze at 29 infos and zero
warnings. (The app's count here had stayed at 1942 while the suite was 1951 —
„the writing follows the voice" added nine and did not touch this file.)
Seventeen mutations, all caught. Live check: `TODO-provera.md`, item 149.

**Hiding the words is a drawing flag, never a text change.** `data.text` is also
the script the voice reads and, in a silent film, what decides how long a beat
holds the screen — so a film sent without its sentences would be muted and
raced at once. The flag enters at `captionBandLines`, because a band of zero
lines is already the whole answer: the layout, the frame rate and the render
budget all read it from there, and a flag applied further down would have left
two of the three believing in a column that is not drawn.

**Two of the seventeen were caught only by tests written after the harness
was drafted.** Nothing asserted that the route's budget reads the flag, and
nothing asserted that the choice is *written* to preferences — the test that
the sheet opens on last time's answer seeded that answer itself. **A test that
seeds the state it checks cannot catch the code that was meant to write it.**

**A tutorial says its language, on the server — 11.9.2026, backend 1226** with
`.env` moved aside; the app is untouched at 1956. Phase 1 of
`docs/PLAN-JEZIK-GLASA.md`. Fourteen mutations, all caught.

**The route that matters is the one the reader uses, and the plan named the
wrong one.** It said `assignmentReview.js`; the student's viewer is fed by
`getAssignmentDetail` in `assignmentService.js`, and the review is the
trainer's. Found by reading the app's call before writing the server's half —
grep the client for the URL, then follow it, rather than trusting a name that
sounds right.

**A fake that answers a question nobody asked cannot see the question go
missing.** The first fake pool returned `language` whatever the `SELECT`
named, so deleting the column from the student route's query left every test
green. It returns only what was selected now. Same family as every check in
this file that could not fail.

**Seven languages in the app's voice core — 11.9.2026, app 1971 with 1
skipped, backend 1226.** Phase 2 of `docs/PLAN-JEZIK-GLASA.md`. Fifteen
mutations, all caught.

**One file of expected outputs, read by both suites**, replaced a list of the
app's English expectations hand-copied into `spoken_moves.test.js` —
`chess_backend/test/fixtures/spoken_moves_cases.json`. Writing it found the two
ends already disagreeing: the server's end-of-sentence rule knew Š and Č as
capitals, the app's knew only A–Z, and neither knew Cyrillic. **A copied list
checks only what was copied.**

**A gate taught a new alphabet the day the alphabet arrived.**
`vocabulary_en_test.dart` knew only the Latin Serbian letters, so a Cyrillic
label on a screen would have passed — unnoticed only because `lib/` held no
Cyrillic. It knows Cyrillic now, and exempts voice vocabulary **by structure**
(inside a `SpeechVocabulary(...)`) rather than by file, because a file
allowance also hides next year's label. Proved with four probes, one of them a
Serbian string on the line after a vocabulary closes.

**A backslash-u escape in a tool's input arrives as the character.** The edit
that wrote the Cyrillic range as escapes into two regexes put the characters
Ѐ–Я there instead, because the tool input is JSON-decoded; the regex still
worked, so only reading the bytes showed it — and the same decoding then broke
the script meant to fix it. Build the backslash with `chr(92)` when a literal
escape has to land in a file.

**A tutorial's language on its way through the app — 11.9.2026, app 1983
with 1 skipped; the backend is untouched at 1226.** Phase 3 of
`docs/PLAN-JEZIK-GLASA.md`. Fifteen mutations, all caught.

**Three answers need a type, not a nullable.** The server keeps a column the
request does not mention, clears it on null and stores a value — and the API's
`if (x != null) 'x': x` can say only two of those. A draft kept on this device
before the field existed does not know the language, and sending „not said"
from it would wipe one set elsewhere. `LanguageWrite` (`silent`, `unsaid`, a
code) defaults to `silent`, so every caller written before sends exactly what it
sent before. Same rule as `positionList` and `description`, one level further
out: **absence is a third answer, all the way to the wire.**

**A translation must not inherit the label of the language it came from.**
Without `--code`, `translate.py` removes the field rather than copying it — an
English source translated into Serbian would otherwise still say `en`, and be
read by exactly the wrong voice.

**A tutorial read in its own voice — 11.9.2026, app 2009 with 1 skipped;
backend untouched at 1226.** Phase 4 of `docs/PLAN-JEZIK-GLASA.md`.
Twenty-one mutations, all caught.

**Read a test for the mutation that would survive it, before running the
mutations.** Two gaps were found that way and closed first: nothing asked
which voice's reading speed the writing used, and the test tutorial had no
question part, so a question read without its language would have passed.
Cheaper than a survivor, and the same lesson this file already records for
phase 4 of the recording plan.

**A test that fails can fail its neighbour.** Under one mutation the studio
preview test failed at its expectation, never reached `close`, and left the
studio mounted to flush its draft into the one slot the next test reads — so
two tests went red for one fault. It closes in `addTearDown` now. A red under a
mutation is only the right red when it is the only one.

**A feature that must never fall back needs a test where falling back would
look fine.** The walk on a Windows that lists Croatian and has none: `speak`
returned at once, and without the check after each sentence the tutorial
played its moves with no voice and no wait. The test watches that the walk
stops, that it says why, and that nothing was spoken in English instead.

**The trainer picks it — 11.9.2026, app 2018 with 1 skipped; backend
untouched at 1226.** Phase 5 of `docs/PLAN-JEZIK-GLASA.md`, a „Language"
dropdown in the studio's title row. Eight mutations, all caught.

**Measure text with the font that will draw it.** A widget test draws every
glyph as a square one font-size wide, so „Serbian (Cyrillic)" measures 288 px
there and 116 px in Segoe UI. The placement probe loaded
`C:/Windows/Fonts/segoeui.ttf` through `FontLoader` as `Roboto` and measured
the real row: a third equal share left the label 63 px and cut both Serbian
entries to „Serbia…", and a row of its own cost 56 px and overflowed
840 × 800. The dropdown takes its own width now. A probe like that cannot be a
committed test, since CI has no Windows fonts, which is why the numbers are in
the comment on `_headerFields`.

**A form field keeps the value it was built with.** The studio swaps in a
stored draft of the same tutorial one frame after it opens, so a
`DropdownButtonFormField` would have gone on showing the language of a draft
that was no longer there. It is a `DropdownButton` reading the draft on every
build, and a test adopts a stored draft to prove it.

**A closed dropdown builds every entry.** „German is shown" found German
whichever language was chosen, so the assertion could not fail. The tests ask
for the button's `value`.

**„Deo 3" became „Part 3" — 11.9.2026, app 2024 with 1 skipped.** The one
Serbian word the English pivot left in the studio: a part's generated name. The
gates never saw it because it has no Serbian letter. The rule lives in
`features/lessons/models/part_titles.dart` now. Eleven mutations caught, and
one survived because nothing can observe it.

**A word stored on the server outlives the code that wrote it.** Every
tutorial saved before this still says „Deo 2", and the studio rewrites it only
when that tutorial is saved again. So every screen that shows a stored part name
reads it through `shownPartTitle`: the child's viewer, the room's two messages
and its step menu, and the course editor. The number shown is where the part
stands, not the one stored. The frozen phone step editor is left alone,
because its title field edits the stored text itself.

**Four assertions of absence went vacuous with the rename.** A test saying
`find.text('Deo 2'), findsNothing` still passes once „Deo 2" cannot appear at
all. They were changed along with the ones that went red. After a rename,
grep the old word in the tests; running them is not enough.

**A mutation harness has to prove the baseline first.** Its first run reported
every mutation caught, but one edited test file did not compile, and
`flutter test` with several files fails all of them to load together. The
harness now refuses to judge mutations until the untouched tree is green.

**Undo and redo in the tutorial studio — 11.9.2026, app 2051 with 1 skipped;
the backend is untouched.** Phase 1 of `docs/PLAN-STUDIO-ISTORIJA.md`, and
analyze stays at 29 infos. Twenty-six mutations were caught; a twenty-seventh
showed a line no test could fail, and the line was deleted.

**The history holds snapshots, not operations.** Every change already went
through `_persist()`, which already encoded the whole draft for the device
slot. Keeping those encodings is the whole mechanism, so no action needs an
inverse written for it.

**A snapshot from before a save knows no ids.** Restored as it was, the next
save would have created a second tutorial and new step ids. Each part carries
a `localKey` on the device; the studio learns which step id each key was
given, and the lesson id never goes back to null. The test reads the request.

**Two guards that prove the same thing prove neither.** A `_sealed` flag and
two position checks both stopped typing from merging after an undo. Deleting
any one of them left the tests green, so the position checks went. Chasing the
one survivor found a real gap: nothing asked that typing merges again after
the trainer carries on from an undo.

**A field that never called `_persist()` is a change undo cannot see.** The
task and the answers were edited through their controllers alone. They were
saved correctly, but an undo would have taken them back together with the next
unrelated change.

**The saved version of a tutorial — 11.9.2026, app 2066 with 1 skipped,
backend 1234** with `.env` moved aside; analyze at 29 infos. Phase 2 of
`docs/PLAN-STUDIO-ISTORIJA.md`: `GET /lessons/:id`, the question on open, and
„Discard changes". Twenty-four mutations were caught, one of them only after a
test was added for it.

**A single-row route shares the list's access rule; it does not copy it.**
`READER_COLUMNS` and `READABLE_BY_READER` are one constant each, used by both
queries. The test asserts that the single-row query holds the list's condition
character for character, plus `AND id = $2`. With no database in the tests,
that is what proves „another trainer's tutorial" and „an invitation not
accepted" without a fake that pretends to be one.

**Do not wait on the network for something the user can already see.** The
draft kept on the device is adopted at once, and the server's answer is
compared when it arrives. Asking first would have held the studio for up to
twenty seconds and swapped out anything written in that time. So the question
is asked only while nothing has changed.

**What a save counts as saved is taken before the request goes out.** Taken
from the answer, it would mark words typed during the request as saved. A
held `Completer` in the test is what shows the difference.

**A guess about layout was measured and was wrong.** Windows defaults to
compact density, so the app bar's icon buttons were expected to be narrower
there than in a test. They are 48 px on both. (The title widths first written
here were measured on squares; see the entry after the next.)

**„Insert a line here" — 11.9.2026, app 2079 with 1 skipped; the backend is
untouched at 1234.** Phase 3 of `docs/PLAN-STUDIO-ISTORIJA.md`. Of nineteen
mutations, eighteen were caught; the nineteenth showed a line nothing could
observe, and the line was deleted.

**A probe that loads a font measures only the text that asks for it.** Every
„real Windows font" number from phases 1–3 for the app bar and the parts panel
was measured on squares, and one of them turned a button into an icon. The
probe loaded Segoe UI as `Roboto` and `Segoe UI`, which reaches text that
inherits the theme's font family. But this app's theme hands buttons, the app
bar title, dialogs, chips, input labels and tooltips `AppText` styles, which
name **no** family, and a button uses its style's text style as the whole
default rather than merging it with the theme. On Windows the engine draws a
null family in Segoe UI; `flutter_test` draws it in the square test font.
Loading a font under the test font's own name changes nothing. „Choose the
answer" measured 221 px as a button label and 121 px as a plain `Text` beside
it, and „Tutorial Studio" measured exactly 15 squares of 16 px.

**Before believing a probe, print the font family of the text it measures.** A
width that equals the number of characters times the font size is squares. A
faithful probe gives those null-family styles `fontFamily: 'Segoe UI'` in a
`ThemeData.copyWith`, which is exactly what the Windows engine does, and
changes nothing else. Measured that way: the title is 111 px and whole down to
~610 dp; „Preview as student" as words is 147 px and fits at 700; the parts
list is 114 px at 1366 × 768 and 840 × 700 does not overflow. A task was
spawned to fix a „cramped panel" that did not exist. The table is in
`docs/PLAN-STUDIO-ISTORIJA.md`, „The measurements were wrong". The
voice-language plan's dropdown measurement stands: its entries inherit the
theme's family.

**What exposed it was arithmetic, one task later.** The spawned task's prompt
quoted a 17-character button as ~287 px wide, and 17 × 14 plus an icon and
padding is 287. A panel that had shipped for a week and was „already cramped
to 26 px" on an ordinary laptop was a number worth doubting on its own. Measured
correctly, a fourth action in the parts panel costs a row of icons, 44 px of
list; on the current beat's card in „Flow" the button costs nothing, so that is
where it went.

**A test that reads the wall clock is a test of the machine's load.** Phase 1's
typing test passed alone and failed in the full suite, because the history
merged keystrokes by `DateTime.now`. It reads `package:clock` now, the test's
fake time inside `testWidgets`. The proof was a copy of the test that sleeps
1.5 s of real time between letters: it passes on `clock` and fails on
`DateTime.now`.

**When the test font and the real one disagree, pick the width where both
agree.** Phase 4 of the same plan put „Preview tutorial" back as words, at the
owner's request. On Windows they fit at 700 dp; in a widget test the label is
squares and overflowed 700 by 77 px, and that test is the only overflow guard
CI has. So the words show from `Breakpoints.wide` (840), where they fit in
both, with an icon of the same name below. Weakening the test would have
removed the guard; forcing the words everywhere would have failed it for a
layout that is fine.

**A gate can hold a worker to the labels and not to the truth — 11.9.2026,
the user's manual.** Phase 4 of `docs/PLAN-ZAVRSNICA.md`, carried by
`docs/PLAN-PRIRUCNIK.md`: thirteen task-shaped pages on the site, linked from
Settings and the F1 page. `test/manual_labels_test.dart` fails if a page quotes
a label that is not a string literal in `lib/`, and it is read with a lexer
rather than a regular expression — this repository's comments quote retired
labels („Not 'Snimljeni časovi' any more"), so a text match would accept the
comment as proof that the label still exists.

**The worker batch passed all twelve gates and its pages were discarded.** Not
one invented label got through — the gate works — and almost every sentence
around the labels was invented anyway: „mobile web browsers" for an app with no
web build, three board themes that do not exist, shortcuts `?` and `F` that are
not bound, a scanner that „captures a photo … using your webcam" when it reads
a PDF's typeset diagrams and never an image. The brief had asked for
`file:line` beside every claim so grading would be cheap; the citations do not
resolve — `age_gate_screen.dart:176` is an error message, not the „Birth year"
label. **Ask a worker for what a gate can check; prose about behaviour costs
the same to verify as to write.** What was worth keeping was the structure: the
page list, the section order, the length of a page.

One leftover found on the way: the Training hub drew „Trening" as its own
screen's title, three days after the English pivot, because a Serbian word with
no Serbian letter is invisible to `gate_english_ui`. The harness's word list
knows „trening" and „delovi" now — and not „deo", which fires on the regex that
recognises parts named before the rename.

**A notation the parser refuses is a test's own mistake first.** The test's
first fixture wrote `2. Ra6+`, which is not check: the knight on b6 blocks the
rank. `MoveTree.parsePgn` refused it and the move after it, as it is meant to.
The owner's line had it right.

**Measured on `master` on 12.9.2026: 2181 in the app with 1 skipped**, analyze
at 29 infos and zero warnings; the backend is untouched. Eight of those are „Save
as .pgn" — the Analysis export, which since it was written could reach the
clipboard and nowhere else, so a trainer wanting a file pasted the text into
Notepad. The number in this file had been left at 2066 while the suite was 2173;
re-derive a count before repeating it, which is what this paragraph is for.

Three things, and none of them is the feature.

**A dialog that awaits the platform is a dialog that does not open in a test** —
this file already recorded it from the export sheet, and `exportPgnDialog` had
the same shape all along: `await PgnExporterService.copyToClipboard(...)` stands
in front of `showDialog`, and the clipboard is a platform channel. Every test
that opened this dialog found nothing to tap. The copy is unawaited now, its
failure logged rather than raised, and the dialog opens at once — which is also
better for a trainer on a slow channel. **A shape this file has already named is
the first thing to look for, not the last.**

**A 360 dp test found a fault in the title, not in what was added.** The new
button made three actions, so the dialog was measured on a phone for the first
time — and the overflow was the title `Row`, an icon beside a `Text` that cannot
shrink. Fourth instance of that exact shape here. It is `Flexible` now. What the
same test could *not* see is that the pre-existing „Copied to Clipboard!" is
twenty characters of squares in the test font and about half that in Segoe UI:
the label was shortened to „Copied" because three actions no longer leave room
for a sentence pretending to be a button, not because a real phone clipped it.

**The picker writes the bytes; nothing here writes the file.** `FilePicker
.saveFile` with `bytes` writes them at the chosen path on every platform this
app ships to, and a `File.writeAsBytes` beside it is how a file comes to be
written twice on one platform and not at all on another. `debugSavePgnFile` is
the seam, in the shape `debugPlayVoiceSample` already had. Five mutations, all
five caught.

**2190 the same day, and nine of them are a field one end wrote and no end ever
read.** `AnalysisNode.nag` has existed since the Analysis Studio was built and
`PgnExporterService` has always written it — but `MoveTree.parsePgn` stripped
`!` and `?` to get at the move and threw them away, `MoveNode` had nowhere to
put them, and `readStepTree` could not carry across what it was never given. So
„Review entire game" wrote `c5??`, the file kept it, and the first time a
trainer reopened that part and touched anything the re-export wrote `c5`: the
blunder marks of a whole game, silently. **Same family as `acceptedSans`
missing from the model, and found the same way** — by asking what an unbuilt
feature would need to read, which is the cheapest moment to find it.

**A parser also reads what other programs write.** A game annotated anywhere
but here says `$4` where this app says `??`, so the six codes that have a glyph
in this app's vocabulary are read onto the move in front of them, and the other
two hundred are dropped rather than given an invented mark — `$14` means „White
is slightly better", which nothing here can draw or mean.

**And the new test found a second fault nobody was looking for.** `Nf3!*` was
counted as a move that cannot be played: both strips are anchored to the end of
the token, so with the glyph in front of the star neither pattern could see what
it was looking for. That is the 7.9.2026 `Nxb4*` fault one character further
along, and it stayed invisible for as long as the glyph was something to get rid
of rather than something to keep. **A fix aimed at one end of a token is worth
re-reading from the other end.** Four mutations, all four caught.

**A PGN comes in and a tutorial goes back out — 13.9.2026, and the count is
2272 in the app with 1 skipped**, analyze at 29 infos and zero warnings; the
backend is untouched. That is phases 1–4 of `docs/PLAN-PGN-TUTORIJAL.md`, points
1 and 2 of the owner's note: fifty for the reader, the questions and the import
door, and thirty-two for the export. Live checks: `TODO-provera.md`, items 158
and 159.

**The feature was decided by an experiment rather than by an opinion.** Three
games, nine runs through `tools/game_annotate/`, every `ask_move` checked against
Stockfish at depth 22: the arms given „Review entire game" asked questions whose
answer is the engine's first choice by a clear margin, and the arm given only the
moves never once did — it wrote questions that look well formed and are subtly
false („the *only* defensive move", answer ranked third). So a question is made
only where the review already wrote `??` **and** put a `!` line beside it. What
that does not buy is stated in the code: a reviewed PGN carries no evaluations at
all, so nothing in the file says whether a second move was as good. The plan had
claimed it did; that was found while building and corrected in the plan.

**The experiment's own biggest fault was contamination, and it was mine.**
`--add-dir HERE` made the experiment folder the model's workspace, so two arms
read the README and one read a finished `tutorial.json` from the arm before it. A
finding had already been reported off that run; it was withdrawn and all nine
runs re-done in `tempfile.mkdtemp()` with no `--add-dir`. The repository's own
`tools/tutorial_translate/translate.py` already carried a comment prescribing an
empty working directory.

**An existing source-reading gate failed the new export file, and the gate was
right.** `tutorial_authoring_test.dart` fails anything under
`lib/features/tutorial_studio/` that imports `PgnExporterService`, because a
step's `fen` and `pgn` must come from one node through `StudioLessonStep`. A file
export is not a step, so the letter of the rule did not apply — and the fix was
still to go through `StudioLessonStep.gameText`, beside `textWithSpans`, which
exists precisely so the studio never reaches for the exporter itself. **Widening
a gate to admit a special case is how the case after it gets in unasked.**

**Two phase-3 faults were found by the tests that were already there.**
`questionsAvailableIn` counted the questions a file *already had*, so a
hand-written tutorial with a question in it was offered „make questions from the
mistakes" over a file with no mistakes marked anywhere — and the report behind
that dialog never opened; and judging a file by its content alone read a broken
`.json` as a game, which tells a trainer about the wrong reader. Not one of the
three new fixture files had a question in it already, and not one was a `.json`
that failed to parse. **New tests cover the case you thought of; the old suite
covers the case you are standing in.**

**A drawing is merged at a join, not appended.** `splitForQuestion` copies the
cursor's arrows and squares onto the question it makes, because the board does
not reload across a join and a circle that vanished there would be a flicker — so
both parts either side of a join carry the same arrow, and exporting by
concatenation writes it twice, on every question this app has ever cut. The
square is tested as the arrow's twin, since a pair fixed by halves is how the
rank numbers spent two days invisible after the file letters were put right.

**A fixture that types a FEN by hand can disagree with every reader in the
app.** The first export fixture wrote the position after `1. e4 e5` with `-` in
the en passant field, and the two parts refused to join — correctly:
`MoveTree.samePosition` compares that field, the child's viewer compares it, and
`addSection(continueFromEnd: true)` writes the square. The code was right and the
fixture was wrong, which is the order worth checking in.

**The motif detector's vocabulary, 13.9.2026 — 2323 in the app with 1
skipped, 1260 on the backend, analyze at 26 infos.** Findings are sentences
now, and a fork, skewer, pin or overload is counted only when it can win
something (`docs/STANJE-RADA.md`, „Rečnik detektora motiva"). The number in this
file had been left at 2272 while `master` was at 2278. Three things worth
carrying.

**A mutant that does not compile is not a caught mutant.** One replaced
`mate != null && …` with `false`, which removed the null promotion the next line
needed; the harness saw red and said caught. The report listed file names and no
test names — read *which* test failed, and a compile error names none.

**A clause that can never decide is found by reading, before the run.** „The
king always counts" stood beside a value comparison three times, and a king is
worth 1000. Deleted rather than left to survive a mutation.

**When a model repeats its input word for word, the input is the product.** Four
models wrote „skewer" wherever the review did, and „Resolved —" as prose.
Cleaning the words was half of it; the other half was not writing the findings
that teach nothing — a pawn „skewered" behind a queen, a king „left undefended".

**A finding keeps its identity across a move, the same day — 2335 in the app
with 1 skipped.** A finding before a move is compared as its squares stand after
it, and its significance is what it can win, never the attacker
(`docs/STANJE-RADA.md`, „Isti nalaz posle poteza"). Two things worth carrying.

**A test can pin the fault it should catch.** Test 9 said Qd1-d5 „freshly" hung
a queen that was already hanging on the open d-file, and asserted the
square-keyed noise as a created finding; its comment described a board its FEN
did not hold. Read what a fixture's position actually has before believing the
sentence above it.

**A snippet that appears twice is not a mutation.** The harness refused it as
NOT APPLIED instead of taking the first match — which would have mutated the
tactical call, already passing the move, and reported a verdict about the wrong
line.

**Thirty-three more on 13.9.2026 — 2368 in the app with 1 skipped** — and they
are phase 1's first step of `docs/PLAN-SKELET.md`: `wordsFor` and `standing`
ported from `tools/game_annotate/skeleton.py`, held to fixtures the harness
writes itself (`export_fixtures.py`, whose `--check` fails when the two part).
Ten mutations, all caught. The rest of the phase waits in
`docs/gates/game_tutorial_skeleton_test.dart`.

**A gate that cannot be satisfied is found before a batch, not by one.** The
port has to write a part's `pgn` through `StudioLessonStep.from`, and the
fixtures hold python-chess's text, wrapped at 80 columns — so the gate compares
what `LessonStepLine` reads back, and that was proved passable by rebuilding
every part of every fixture through the app's writer before the gate was handed
over. **And a sentence in a brief is a claim like any other:** the first draft
said the motif detector „already asks" python-chess's attack and pin questions;
grep found one private pin check and a legal-capture query, which is not the
same answer, and the gate says so now.

**Forty-four more on 14.9.2026 — 2412 in the app with 1 skipped** — batch 70,
the rest of the skeleton ported by a worker in one round (39 of the gate's), and
five of the lead's. Fifteen mutations, all caught.

**A gate built from real data cannot see what the data never does.** The ten
fixture games have no cost tie at the cut and no masters share that is exactly a
half, so the port could get Python's `round` and `'%.1f'` wrong and pass all 39.
It did, and the worker's report said so — two of three requested divergence
mutations came back „no test failed", which is a finding about the gate and not a
pass. The harness now writes the variants itself (`edge_cases.json`). And the
first of those variants was vacuous: it dealt the breaking shares to rows no
moment quotes, and was only caught by **watching the new test stay green on the
code it was written against**. Run a new test on the wrong code before believing
it — the lead's tests included.

**A rule can be redundant for every input but one.** „A question names its answer
or its square" survived its mutation because every answer contains its square;
castling is the exception (`'O-O-O'[-2:]` is `-O`), so the case that proves the
rule is the one move no fixture had.

**Phase 2 of `docs/PLAN-SKELET.md` on 14.9.2026 — 2489 in the app with 1
skipped, 1278 on the backend** with `.env` moved aside, analyze at 26 infos.
The arithmetic: 2412 + 49 (facts) + 13 (engine) + 7 (store) + 8 (the walk
client); 1260 + 8 (the masters book) + 5 (Polyglot keys) + 5 (the route).
A game's facts are built on the device and are identical to the harness on the
real engine, and the masters statistics come from a local database (D5).

**A question about a token was settled by measuring the alternative.** Whose
Lichess token a game's walk should spend had no good answer, and a SQLite file
built from over-the-board games answered it: the same most-played move in 99%
of 163 positions. Lichess refused the measurement itself with a 429, twice, at
1.2 s spacing.

**The first extraction's draw rate was 6.5 points below Lichess's, and the
cause was the filter, not the data.** An *average* rating of 2200 admits a
2500 against a 1900, and those games draw 23.6% of the time against 37.8%.
Both players 2200+ — the rule Lichess uses — brought the gap to 2.9. A
systematic difference with the score unmoved is worth a hypothesis before it is
filed as noise.

**A mutation that removes a loop's cap does not fail, it hangs** — and with a
fake engine that answers at once, the retry is an endless chain of microtasks
that no test timeout can interrupt. The mutation harness reported it CAUGHT
with no test named. It now runs every mutant under a timeout and prints HUNG;
same family as the render queue's „survived" that had hung.

**A comparison by value cannot see a branch that returns the same number in a
different type.** `cost_pawns` is the integer `0` from one branch and `0.0`
from another; `<` for `<=` survived because `0 == 0.0`. Python's JSON keeps the
difference, so the gate compares numbers by kind as well.

**A purity gate caught I/O in the pure folder, and the files moved.** The
engine, the store, the sleep watch and the HTTP client went into
`game_tutorial/` beside the skeleton port, and
`game_tutorial_skeleton_test.dart` failed them for `dart:io` and `http`. They
live in `game_tutorial_io/` now; the gate was not widened.

**A comment asserted a need nobody had checked.** `setReadBigInts(true)` was
written „because a 64-bit key would round" — but the key is only ever bound as
a parameter, never read back. The line and its reason were deleted.

**Phase 3 the same day — 1316 on the backend** with `.env` moved aside; the
app is unchanged at 2489. 1278 + 21 (the request, the prompt on ten games, the
answer's shape) + 7 (the DeepSeek client) + 10 (the route) = 1316, counted from
the files rather than from memory, which had it as 20 and 11. The words
route writes the harness's prompt byte for byte from the app's request.

**A template retyped is a template that differs.** The prompt holds a `„`, and
the server's copy was written by the harness itself, from its own string, into
the one file both now read. The byte-equal test on ten games is what says the
formatting — Python's `{{` and `}}` — agrees too.

**A validated prompt still sent something it should not.** The harness quoted
the whole PGN file, headers and all; the fixtures only ever named „Player", so
nothing showed. A real trainer's game names their students, and the model is a
third party's. The request now carries moves only, and the server refuses one
with headers rather than stripping them — the app decides what leaves the device.

**Three mutations survived because each test changed two things at once.** A
duplicate moment id was written with duplicate slot ids too, so the slot check
refused it first; the fence test had no braces outside the fence, so the
brace-slicing fallback read it just as well. Change only what the check is for.

**A test's own fake can hang it.** One `release` variable, overwritten by a
second account's call, left the first call waiting for ever: the whole file
sat past its 300 s budget with no output. Node's `--test-timeout` turns that
into a failure, and the mutation harness runs every mutant under one.

**Phase 4 the same day — 2540 in the app with 1 skipped, 1321 on the backend**
with `.env` moved aside, analyze at 26 infos. 2489 + 51: fifteen for the words
request (ten of them one per fixture game), nine for the run, eight for the
dialog, seven for the game tree, five for the client, three for the door and
four for the archive; 1316 + 5 for `GET /games/:id/moves`. Analysis makes both
tutorials in one run. Live check: `TODO-provera.md`, item 161.

**A mutation that does not compile over a promoted nullable is the mutation's
fault.** `if (false)` in front of `onOpenEngineSettings()` and `path == ""` in
front of a `String?` both lose the null promotion the next line needs. Mutate
the condition in a way that keeps it (`!flag && x != null`, `?? ''` at the
source); a compile error is neither caught nor survived.

**Three survivors, and every one was a case the fixtures never reach.** Every
fixture game names an opening, so sending `''` where the harness sends `None`
passed; the too-few-moments test had zero moments, so one was never tried; and
the unplayable-move test followed its illegal move with another illegal one, so
skipping looked exactly like stopping. Same family as `edge_cases.json`: **a
gate built from real data cannot see what the data never does**, and the test
for a boundary has to stand on the boundary.

**The screen-names gate failed „sentences to check in the studio".** The copy
was reworded; the gate stays as it is. It is the third time that gate has
caught a sentence that did not need the word.

**Measured again on `master` on 14.9.2026: 2649 in the app with 1 skipped, 1324
on the backend** with `.env` moved aside, analyze at 26 infos. The day's nine
findings came from the owner's first live run of a game tutorial, and every one
of them is written up in `docs/STANJE-RADA.md`, „Skelet: devet prijava sa prve
provere uživo". Four lessons from it are worth carrying here.

**A configuration fault can look exactly like a code fault.** „The tutorial says
nothing about the opening" was `createMastersBook()` reading
`process.env.MASTERS_BOOK_PATH` **at import**, in a server process started
twenty-six minutes before that line was written into `.env` — and `nodemon`
watches `js,mjs,cjs,json`, not `.env`. Two timestamps settled it in a minute.
Compare when the process started with when the configuration was written before
looking for the bug in the logic.

**Measure the scope of a rule before writing it, and again after.** „Show what
the second-best move does" was built first for every moment with a worse
alternative and fired on 67 of 69 — a second part on almost every answer, which
is not what was asked. Gated on the best line actually giving material up it is
29 of 69. The same discipline found the real size of two other findings: the
answer line ended mid-sacrifice in 16 of 69 parts, and the „back to the game"
bridge was missing from 4 of 10 whole-game tutorials and from every
key-moments one.

**A rule about a line must be asked of the line, not of its first move.** Not
one best move in the ten fixture games gives material away on its first ply, so
`givesMaterial` asked only there would have been a rule that never fired. There
is a test pinning that zero.

**Read what the viewer does before choosing a shape.** The alternative line is a
part of its own rather than a PGN variation because
`lesson_viewer_screen.dart:490` breaks the narrated walk at a fork and asks the
child to choose — a variation would have stopped „Pusti tutorijal" at the moment
the answer is shown — and because the film's beats follow the spine, so a
variation is invisible in every exported video.

**Ten more the same evening — 2659 in the app with 1 skipped**, analyze at 26
infos; the backend is untouched. Three of the owner's second live review:
a recapture no longer called a hanging piece, one orientation per tutorial
turned by part or all at once, and a version for a video with no questions.
Two things worth carrying.

**Ask the database before the code.** „The board turns over between parts"
looked like the same fault as the morning's, and every layer read correct.
One query said lesson 57 had part 1 facing Black and eleven facing White — a
pattern only the studio's per-part flip could write. The code was right; the
control did something nobody could see.

**Hiding a finding on one side of a diff moves it to the other.** Leaving a
trade's recapture out of what a move *created* made the same finding count as
*resolved*, and 2. exd5 said „the white pawn on e4 is no longer hanging" in the
middle of the trade. It surfaced only when the ten reviewed games were rewritten
and compared sentence by sentence — the unit tests were green.

**The story prompt replaced the old one on 15.9.2026 — 2679 in the app with 1
skipped, 1327 on the backend** with `.env` moved aside, analyze at 26 infos. The
arithmetic: 2659 − 12 (`game_tutorial_answer_intro_test.dart`, whose rule is
gone with the answer's introduction) + 32 (`game_tutorial_story_test.dart`);
1324 + 3. `docs/PLAN-NARACIJA.md` has the measurement and the decision.

**A request compared in part is a request compared nowhere in the rest.** The
words request test held `moments` and `opening` to the harness, and the port
added `story` and `arc` beside them — so four mutations to the arc's rules,
including removing checkmate from the result, survived every test. It compares
the key list now, and both new fields.

**A test for two confusable wordings must compare by position, not by value.**
`if (a == b) continue` skipped exactly the clash it existed for: the new
„Back to the game. White played…" opened like the bridge „Back to the game.",
one sentence counted as two bridges, and the guard stayed green.

**Five more on 15.9.2026 — 2684 in the app with 1 skipped; the backend is
untouched at 1327**, analyze at 26 infos and zero warnings. Three live findings,
and the first two are the same lesson twice.

**„And the line goes on" was a fact, not a sentence the model invented.** Every
ply after the first of an answer line carried `; the best line goes on - not
played`, and the second-best line carried `; the line goes on` — so the model
gave them back verbatim, on every ply: „Black would answer Ra7. Not played
either; best line goes on." Second time in this file: **when a model repeats its
input word for word, the input is the product.** The marker is `; not played`
now, which is the two words the prompt's rule keys on, and the prompt gained the
rule that was missing — a sentence whose only content is that the line carries
on is not written, and a move with nothing to tell gets the empty slot that was
already allowed.

**A comment on a move is a comment about the position after it.** „This move
left the masters database: 698 master games reached this position and none
played it" was written onto the departing move, so a student stood on a board no
master game had ever reached and read that 698 had. It goes on the move
*before* it now, names the moves the database plays there with their shares, and
draws them as green arrows — blue stays „this is what was played". The same
mistake in miniature is still in `bookWords`, whose „this position" is read on a
lead-in slot: measured first, it reaches a slot in one of the ten games and
never reaches `boardHere`, so it was left alone rather than reworded into
something circular.

**The gate compared every word of a part's `pgn` and not one arrow.** It reads
both sides back through the child's parser, which strips `[%cal]` out of the
comment — so the blue fork arrow, drawn since 14.9.2026, could have vanished
with the gate still green. Arrows are compared now, root and per move, proved by
deleting each colour in turn. And **all ten games leave the book between ply 3
and ply 13**, so the branch that writes the sentence on a part's own board was
unreachable from real data: `edge_cases.json` carries a g01 whose first move no
master played. Same family as `edge_cases.json` itself.

**And a question answered by measuring rather than by reading the code**:
„can a sequence of moves be sent for a tutorial, not a whole game?" It can, and
it already could — „Make a tutorial from this game" sends `root.fen` and the
tree's main line, so a study position travels as it stands. What does not travel
is the rest of the tree: the walk is `children.first`, so sidelines are dropped,
and only UCI moves go out, so a trainer's own comments never reach the model.
`game_tutorial_flow_test.dart` says both, and both halves were proved by
mutation — **an answer about what a feature already does is a claim like any
other.**

**The opening book becomes ours — 15.9.2026, 1329 on the backend** with `.env`
moved aside; the app is untouched at 2684 with 1 skipped. Phases 0–2 of
`docs/PLAN-OTVARANJA-LOKALNO.md`: the extractor grew `--max-elo` and `--prune`,
the reader is `services/openingBook.js`, and `GET /opening-explorer` answers from a
file on this server instead of proxying the Lichess explorer on a token every
student shared. The arithmetic: 1327 − 19 (the explorer service's own tests,
deleted with it) + 10 (the reader's new half) + 11 (the route) = 1329. Ten
mutations against the reader, all caught.

**The measurement that decided the shape of the data was taken on the whole
file, because a slice overstates it.** 85.1% of the rows in the 2200+ book are
played by exactly one game and 87.3% of positions keep no move at all — but
those rows hold 2.2% of the games in a surviving position on average and **80%**
for the worst one. So `--prune` writes `position_totals` **before** the delete
and only for positions that keep a move: the count a position was reached is
what the panel prints and what the narration says out loud („698 master games
reached this position and none played it"), and computing it from what survived
would have made it quietly too small. „No row" still means „not in the book".

**Pruning shortens the book in eight of the thirteen harness games, and every
ply it takes was carried by one game.** g09 by six plies, g03 by three. The
position where the pruned book ends had been reached by a single master game in
all eight. A correction rather than a cost — but the same simulation is the
thing to run before believing any future change to the extraction, and it is
cheap: walk the games against the old file filtering `w+b+d>1`.

**A field added to an answer can reach a language model.** The shared fixture
`test/fixtures/masters_walk_answer.json` went red the moment `answer()` grew
`unlisted` and `beyondBook`, and the reason is not the fixture:
`walkMastersBook` copies a walked position **whole** into the facts a tutorial
is built from and a model is asked about. `walk()` spells out its five keys now
rather than spreading, with a test that reads them. The fixture is shared by
both suites precisely so a change of shape on either end turns one of them red,
and this is the first time it has had to.

**A grep that timed out is not a grep that found nothing.** The plan was
written saying the extractor „lives untracked beside a 16 GB dataset and is the
only program that can rebuild the data" — and it had been in
`tools/opening_book/` since 14.9.2026, in English, beside `export_polyglot.py`.
The first search for it was a repository-wide grep that hit the tool timeout and
was never re-run narrowly. The cost was real rather than cosmetic: the owner's
Serbian copy was written over the tracked English one, taking a README that
documents both scripts with it, and the half-built database had been made by the
wrong copy — the two name the `chunks` columns differently, so neither can
resume the other's file. Restored, re-patched, and the build restarted by the
script that is actually in the repository.

**A source-reading test that matches a word fails the comment explaining the
word.** The new route's own check — „nothing here reaches Lichess any more" —
failed the route on its header, which says what the route used to be. It strips
comments and asks about `require`, `fetch` and the retired service's name.
Third entry in the family that holds the 1600-character function slice and the
`contains` that matched a doc comment.

**And a threshold cannot test the two halves of the sum under it.** „A position
past the last ply" was green with the ply computed as `(fullmove - 1) * 2`,
whose-move-it-is dropped, because a 30-ply file answers the same for 28 and 29.
`plyOf` is exported and asked directly now. A mutation found it; nothing else
could have.

**Nobody needs a Lichess token for the opening book any more — 15.9.2026, 1343
on the backend** with `.env` moved aside, **2692 in the app with 1 skipped**,
analyze at 26 infos and zero warnings. Phases 0 and 3 of
`docs/PLAN-OTVARANJA-LOKALNO.md`: the ply-50 book is built, pruned to 145 MB and
held to the old file by `tools/opening_book/compare_books.py`, and the judge,
its replies, the spine and the leak report read it with no token anywhere. The
arithmetic: 1329 − 7 (the castling-notation module's test, deleted with it) −
24 (the old judge test) + 29 (the new one) + 6 (the drill's source and refresh)
+ 1 (the spine) + 1 (the frontier) + 8 (the new route test) = 1343. The app
gained seven — 3 (panel) + 1 (service) + 3 (the build screen's stop reasons,
one of them a loop of two) — and measured 2692, not 2691: the 2684 quoted above
was one short of `master` before this change, which is what re-deriving a count
is for. Thirty mutations, all caught, each by the test written for it.

**A watching dev server runs your uncommitted code against the real
database.** The owner's `npm run dev` restarts on every `.js` change, so the
startup migration and the one-time rewrite of `opening_replies` ran at 12:36,
mid-edit, before anything was reviewed — and while `.env` still named the old,
unpruned book, so the rows it wrote were that file's — rewritten again from the
ply-50 book at 13:09, at the owner's request, and checked: no stored reply with
fewer than two games. It ran once and unmutated only because the rewrite is
idempotent and the mutations came after it. A
mutation harness writing server files beside a watching process is the same
risk with worse code in it. **Before editing anything the running server
loads, ask whether its start-up does anything to data.**

**A gate is proved on the wrong input before it is believed on the right one.**
`compare_books.py` was pointed at the old file as if it were the new one before
the new one existed, and its first version passed the walk there: it read the
new file through the same "played twice or more" filter as the simulation it
compared against, so an unpruned file walked exactly like a pruned one. Only the
metadata check caught it. It reads every row now, the way the server does, and
fails eleven checks on the wrong file. Same family as every check in this file
that could not fail.

**A plan's wording can be a claim nobody could satisfy.** "Every position the
ply-30 file answers, the new file answers with the same counts" is false for
any correct deeper extraction — a game that reaches a position only after ply 30
adds to it. The gate asks "none missing, none lower, and say how many rose"
(0.335%), and the plan says why it changed.

**"Clear the cache" was the wrong verb for a cache that is somebody's tree.**
The plan said `opening_replies` would be cleared once. Measured first: the
drill, the tree and the frontier read nothing else, so clearing would have
emptied a real student's repertoire of every opponent reply until each position
was reopened, silently. It gained a `source` column and is rewritten from the
book instead. Measure what reads a table before deciding its rows are
disposable.

**A threshold tuned against one source is re-read against the new one, with
the old answers kept.** `MIN_MASTER_GAMES` stayed at 10 because the harness had
Lichess's masters answers cached for all thirteen games, and at ten the local
book keeps 783 of 795 of Lichess's theory moves. `MIN_SPINE_GAMES` stayed at 100
for the opposite reason: against the rating bands' millions it never bound, and
against the book it now stops a spine 14 to 32 plies in — which is what it
always claimed to do. A cache of an old upstream's answers is what makes a swap
measurable instead of arguable.

**The same notation fault lived in a second place, unconverted.**
`openingMoveNotation.js` existed because Lichess writes castling as "king takes
rook", and it converted the explorer's book moves. Its own header said the cloud
evaluation's lines are written that way too — and `sanLine` never converted
those, so "better was O-O" had always come out as nothing. Found by reading the
module before deleting it. **Read what a deleted file says, not only what it
does.**

**The app stopped asking for a rating, ChessDB or a token — 15.9.2026, 2716 in
the app with 1 skipped**, analyze at 26 infos and zero warnings; the backend is
untouched at 1343. Phase 4 of `docs/PLAN-OTVARANJA-LOKALNO.md`, batch 71
(`46c2cb2`), and the picker's „Osnovna linija" (`d0c6b6c`). The arithmetic:
2692 + 26 (the gate) − 3 (the retired panel test) = 2715 at merge, + 1 for „The
opening itself". Five mutations against the gate, all caught.

**A worker waiting on its own baseline suite is a batch that times out.** It
spent most of 75 minutes saying it was waiting for the suite, and handed back
half the inventory with no report. The harness measures the suite anyway: give
the worker the number and ask for **one** run, at the end.

**„No other assertion changes" is a claim, and the brief made it without
searching.** The full suite found two places the brief never looked: the user's
manual on `site/` quoted three removed controls, and a repertoire test asserted
the very sentence the brief ordered rewritten. Before writing that line, grep
`site/` and `test/` for every string the batch removes or rewrites.

**The repertoire is built on the board — 16.9.2026, 2670 in the app with 1
skipped, 1289 on the backend** with `.env` moved aside, analyze at 26 infos and
zero warnings. `docs/PLAN-REPERTOAR-RUCNO.md`: the spine, breadth, drafts, the
unconfirmed review and skips are gone, and every move in a tree is one the user
played, except the book's top reply stored with a newly kept move. Both counts
**fell**, and that is correct. The declarations were re-derived per file against
`HEAD`. In the app, 2540 → 2492: deleted files −20 (draft review 2, breadth
dialog 2, unconfirmed 4, breadth setting 6, breadth wire 6), changed files −34
(build 16, build layout 9, tree legend 3, walkthrough order 3, tree looks 2,
speech on panels 1), and +6 for the new wire test. On the backend, 1318 → 1264:
deleted −32 (spine 11, unconfirmed 10, alternative 10, breadth rescue 1),
rewritten −30 (frontier 15, line 7, service 4, drill 3, prune 1), and +8 for
`repertoireBook`. Then +3 in the app for the two guards the mutation pass found
unproved, so 2495 declarations. Run counts moved by −46 and −54. The app's extra
one is a parametrised loop.

**Twelve mutations against the build screen, and the two survivors are the two
findings.** A book answer for a position the board has left was never asked
about — `_loadBook` holds `_boardFen != fen`, and deleting that check kept every
test green; and the prune after deleting an opponent move was unreachable from
the build screen's own fake, which has no `removeOpponentMove` and so always
answered „not done", which is why the test for it belongs in the layout file
whose fake has one. A third mutation, `if (false)` over a kept move, took the
null check the next line needs with it: the suite failed to **load**, and a
harness that reads red as proof would have counted a compile error as a catch.
Rerun as `already != null && false`, which keeps the promotion, it is caught.

**A mutation harness beside a watching server runs on a copy.** The owner's
`npm run dev` had already restarted on the edits, so the backend mutations ran
against a copy of `chess_backend/` in the scratchpad. One survived:
`if (played)` guarded a chess.js call that throws on an illegal move and never
returns null, so the line was dead and was deleted.

**The security block of the audit, 16.9.2026 — backend 1338 with `.env` moved
aside; the app is unchanged at 2670 with 1 skipped, analyze at 26.** The
arithmetic: 1289 + 6 (registration) + 5 (recording participants) + 9 (board
events) + 6 (room join) + 5 (script guard) + 4 (body parsers) + 3 (scoped
token) + 8 (assignment guards) + 3 (age floor) = 1338. Every fix was watched red
on the old code or under a mutation on a copy of `chess_backend/`, and every
guard test for an existing check was proved by deleting that check.

**An architecture audit found what nine months of feature work had not**, and it
found it in one afternoon: four read-only Fable runs against a brief that listed
the decisions not to reopen. Every plan had looked at one feature; nothing had
looked across the server's doors. Three of the four worst findings were doors
built correctly on one side and left open on the other — the Google path already
cleared a pre-registered password and the password path did not; the socket's
guest list guarded `joinGame` and not `move`; `participants` was filtered for a
consent stop and trusted for everything else.

**A fix that answers `action_denied` to a stranger answered it to the owner's own
analysis board.** The local Preparation board connects a socket, never joins a
room, and reports every move; refusing unseated sockets out loud would have put a
red bar over every move in it. Found by grepping the app for the event before
changing its server half — the client that sends an event is the first thing to
read before tightening who may send it.

**A test that passes on the old code for the wrong reason is caught by running
it on the old code.** „`audioUrl` from the body is never stored" was green
before the fix, because the fake database knew nobody's age, so consent removed
the sound first. It stands on an adult alone in the room now.

**Security findings are not committed to a public repository before they are
fixed.** The audit files sit in `.git/info/exclude` until the last finding that
reads as instructions is closed.

**The room's socket contract, 16.9.2026 — app 2677 with 1 skipped, backend 1350
with `.env` moved aside, analyze at 26.** The arithmetic: app 2670 + 1 (room
save) + 2 (course dialog labels) + 4 (tree sync); backend 1338 + 7 (contract) + 3
(invitation route) + 2 (board events: three for sharing, one speaker test
deleted with its event).

**A rename on one end of a wire is invisible to both ends' tests.** Commit
`6a6b0dd` renamed the room's socket events on the server; the app kept the old
names, and five weeks of green suites and live checks followed. Each end was
tested alone, and the only thing that could see the break — two clients in one
room — was never run, because the fallback (`pgn_loaded`) kept the move tree
looking right on the one device that was watched. **When two ends agree by a
name, one test has to read both ends.** `test/socket_contract.test.js` does, in
all four directions, so a handler nothing calls is as loud as a call nothing
handles.

**A computed name hides from a name-reading test — and the first version of the
fix wrote one.** `emit(isMuted ? 'a' : 'b')` passed the pairing silently; the
test now also refuses any emit or listener whose name is not a literal.

**The role in the URL is not the seat in the room.** The voice and sharing
controls asked `userSession.role == 'ucenik'`, and joining by code arrives as
`korisnik` — so those handlers would have stayed dead with every name repaired.
Found only because the listeners were read, not just renamed.

**A test that fails to compile is not a red.** The course dialog's label test
was „watched failing" under its mutation — and had failed to load, on a wrong
import path, both with the fix and without it. Read *which* failure it is; this
file already says so, and it still happened.

**A test's simulation can be weaker than the thing it stands in for.** Calling
the board's `onMove` without moving the controller first — which the real board
always does — produced a line whose second move could not play, and a red for
the wrong reason. The helper plays on the controller, then reports.

**An escaped `\b` written through a script arrived as a backspace byte**, twice,
in the contract test's regex — the trap this log already records from
`gate_english_backend`. `grep -c $'\x08'` finds it.

**Block C of the audit, 16.9.2026 — app 2689 with 1 skipped, backend 1374 with
`.env` moved aside, analyze at 26.** The arithmetic: app 2677 + 3 (room PGN
marks) + 1 (no-diacritic Serbian words) + 2 (render poller) + 6 (endgame wire);
backend 1350 + 6 (per-account limits) + 7 (addresses, lists, tokens) + 1
(verification code source) + 3 (step caps) + 7 (endgame route auth). Thirty-five
mutations, all caught — three of them only after the test was fixed.

**A 403 is not the 403 you meant.** The narrative's quota test passed with the
quota deleted, because the route answered 403 for another reason (opponent
preparation off). It asserts the quota's own `quotaExceeded` now. A status code
is a category, not an identity.

**A limiter counted by account cannot be told from one counted by address when
every request in the test comes from one address.** Deleting the account key
survived until the test sent a second account from the same address and
expected it through.

**An old test can be a decision, not a bug.** The audit said the step builder
should refuse long text; `lesson_steps.test.js` said, in a comment, that a
trainer who pastes a paragraph gets a step, not an error. The fix took the half
that breaks meaning (a line cut mid-move, a move cut into another) and left the
decision to the owner rather than overturning it in passing.

**A harness that crashes mid-mutation leaves the mutation behind.** A Python
print died on a `cp1250` console after writing a mutant into the scratch copy,
and the next run's baseline read the mutant. Restore in `finally`, and set
`PYTHONIOENCODING=utf-8` — this log already said the second half once.

**Scripts written through a shell heredoc lose their escapes.** Three times in
one day: `\b` became a backspace, `\n` a newline, an em dash broke the
decoder. A script that must carry a backslash is written as a file first.

**The owner's four decisions on block C, 16.9.2026 — backend 1376 with `.env`
moved aside; the app unchanged at 2689 with 1 skipped, analyze at 26.** The
arithmetic: 1374 − 1 (the test that pinned cutting long text) + 3 (refused at
title, task and choice, kept whole at the cap). The unenforced free-plan limits
were deleted rather than wired, with the two „Unlimited …" lines of the Premium
dialog that sold them.

**A cap on one end moved a cap on another.** Refusing a task over 500
characters instead of cutting it would have turned a model's 501–600 character
question into a generated tutorial that failed at save — `tutorialWords.js`
allowed slots of 600. Grep for the other producers of a field before tightening
what the field accepts.

**A deleted limit takes its advertisement with it.** The model, the switch, the
two entitlements and the card's „n / 20" were the obvious half; the Premium
dialog's „Unlimited saved positions and tutorials (free: up to 20)" was the half
a user reads.
