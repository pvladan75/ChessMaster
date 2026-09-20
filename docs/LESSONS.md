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

**Three of the owner's seven repertoire reports — 16.9.2026, 2693 in the app
with 1 skipped**, analyze at 26 infos and zero warnings; the backend is
untouched at 1289. The arithmetic: 2670 + 3 (the engine and the spoken
sentence) + 13 (the file) + 7 (the door to it). Fifteen mutations, all caught,
each by the test written for it. Live check: `TODO-provera.md`, item 170.

**Both halves of one report were one state.** „Let the user have the engine
when the opponent is to move, and when the book has run out" read as two asks
and is one: after a move of the student's own, the board stands a ply on with
the opponent to move (`_standingAfter`), and that is exactly where the book
answers „no reply here" — and `if (!_afterMyMove)` hid both the button and the
panel there, while `_askEngine` asked about `_node` rather than about the
board. The comment panel had followed the board since it was written
(`_commentFen => _boardFen`); the engine had not. **When a screen has two
notions of „here", the fault is wherever the two disagree**, and a report that
names two symptoms may be naming one line.

**Dropping a count from a spoken sentence changes when it is spoken.**
`SpeakableInfo` speaks on mount and whenever its text changes, and
`SpeechService` swallows a repeat — so while the sentence carried „4 more
unanswered positions" it changed at every position and was read out every time,
which is what the owner reported. With the count gone, two positions that ask
the same thing are the same string and the question is spoken once. That is the
intent and it is written next to the code, because it is the kind of silence
that reads as a broken feature to whoever meets it next.

**A number removed has to be removed everywhere it is written, including in
shorter words.** The sentence said „4 more unanswered positions"; the line two
below said `open 4`; the card in the repertoire list said „5 unanswered
positions". Deleting one and keeping the others is the rank numbers staying
invisible for two days after the file letters were fixed. What stays is
`decided N` — a count of work done — and the coverage map, which is opened on
purpose to see what is unanswered.

**The last reader of a number is the last reader of the request behind it.**
The card was the only caller of `GET /repertoire/progress`, which is a walk per
repertoire on every open of that list. Removing the line and keeping the fetch
would have left the server doing a third of a second per repertoire for a
number nobody draws — so `progress()` and `RepertoireProgress` went with it,
and the test asserts the path is never asked for rather than that the sentence
is absent. The route stays; deleting it is the server's own change. **Follow a
removed number up its own pipe**, and when the pipe ends at the client, do not
leave the method behind: `disagreements` was left that way on 3.9.2026 and
turned up this same morning as a capability reachable from nowhere.

**A grep over `lib/` and `site/` is not a grep over `test/`.**
`repertoire_counts_refresh_test.dart` asserted the whole string `decided 2 ·
open 1`, in a file about something else entirely, and it was the one red in a
2692-test run. This file already says to grep the old word in the tests after a
rename; it was greped everywhere else first.

**The drawing's tree is not the export's tree.** `repertoireTreeToNodes` writes
a card's label into `AnalysisNode.nag` — ` ★`, ` 45% ?` — and `PgnExporterService`
writes `nag` straight after the move, so exporting the picture would have put
`1. e4 ★ 62%` into the file. `repertoire_pgn.dart` builds its own. **A model
reused for a second purpose carries the first purpose's decorations**, and the
place that notices is the one that serialises it.

**Which move is the main one needed no convention.** The server already returns
the student's primary first and the opponent's replies by descending share, and
PGN's main line is the first child at every step — so the file's main line *is*
the repertoire's, and the alternates are its variations. The version of this
that goes wrong is a `{main}` marker invented beside an ordering that already
says it.

**A fake that cannot supply the number cannot see the number come back.** The
card test's first version asserted that no „unanswered" sentence is on screen,
against a `MockClient` answering `{}` to everything — so putting the whole
feature back left it green, because the restored code asked, got nothing
usable, and drew nothing. The fake answers the progress request with real
numbers now, and the screen simply never asks: with that body, the absence
assertion and „the path is never requested" both go red on the restore.
**An absence test has to be run against a fixture where the thing could
appear**, which is the same family as the empty board under the file letters.

**An `unused_element_parameter` warning was a missing test.** The fake API in
the door test took the comments and no test passed any — which is the analyzer
saying that nothing asserted the **screen** hands the comments to the exporter,
a separate line from the exporter writing them. The test was written and a
mutation fails it. Zero warnings is worth holding for reasons that are not
tidiness.

**The repertoire branch merged after the audit — 16.9.2026, 2712 in the app with
1 skipped, backend 1376 with `.env` moved aside, analyze at 26.** The
arithmetic: 2689 on `master` + 23 from the branch (3 + 13 + 7; the card test
was replaced one for one). The branch had been cut before the audit and sat
unmerged under eight commits, and was not found by a grep of `master` — **ask
`git branch -a --no-merged` before saying a feature was never built.** Two
collisions git could not see as conflicts: both sides had claimed item 167 in
`TODO-provera.md` (the repertoire's became 170), and the branch still wrote its
lessons into `CLAUDE.md`, where they no longer live. The first backend run hung
in `render_fairness.test.js` for over ten minutes; the file passes alone in
0.13 s and the whole suite in 14 s on a rerun, so the hang was not reproduced
and its cause is not known. A stopped background task does not run its shell's
`trap`: `.env` stayed aside until it was moved back by hand.

**The Analysis import reads what the app exports — 16.9.2026, 2718 in the app
with 1 skipped, analyze at 26.** The arithmetic: 2712 + 10 in
`analysis_pgn_import_test.dart` − 4 in `pgn_parser_sanitize_test.dart`, deleted
with `lib/pgn_parser.dart` once its one method had no caller. Six mutations, all
caught.

**A writer checked against its own reader is not checked against the other
readers.** The repertoire export was proved by reading it back through
`MoveTree.parsePgn`, and it was right. The Analysis import beside it still went
through `chess.load_pgn`, which refuses the whole text on a bracketed variation
and on the space the exporter leaves before `1.` — so the first thing a user did
with the new file, paste it into Analysis, said „Invalid PGN format". The
reader had been named as lossy in two doc comments for weeks and left in
place. Every door a text can come in through is a reader; **when a feature
starts writing a format, list every place that format can be pasted.**

**Landscape on a phone — 16.9.2026, 2769 in the app with 1 skipped, analyze at
26.** The arithmetic: 2718 + 14 in `landscape_board_layout_test.dart` + 23 in
`landscape_screens_test.dart` + 2 each in seven existing screen tests. With the
17 changed files under `lib/` put back to `HEAD`, 34 of the new tests went red;
the three that stayed green were meant to (an upright screen, a keyboard on a
layout that always scrolled, a dialog that already fitted at 932×430).

**A layout that changes shape when it needs to scroll will drop the keyboard.**
The first version of the shared layout wrapped itself in a scroll view only
when the body fell below its minimum height — and the keyboard is what makes
it fall. The tree changed shape, the text field was rebuilt, focus went and the
keyboard closed: typing would have been impossible on every landscape screen
with a field. Found by a test that taps the field, raises `viewInsets` and
asserts the `EditableText` state is the *same object*; proven by putting the
conditional back. **Wrap always, and size to the larger of the space and the
minimum.**

**Decide "phone on its side" by height, not width.** A large phone on its side
is 915–932 dp wide, past the 840 breakpoint, so the wide layouts written for
desktop windows picked it up — the room drew two 300 dp sidebars beside a board
on a 430 dp tall screen. Every `isWide` check has to lose to the landscape one.

**Landscape, after the first look on a phone — 16.9.2026, 2807 in the app with
1 skipped, analyze at 26.** The arithmetic: 2769 + 32 from running every screen's
landscape test at two more sizes (760×360 and 760×430: sixteen loops of two) +
3 more one-row sizes and 2 new tests in `landscape_board_layout_test.dart`
(side inset, real font) + 1 net in the step editor (two tests replaced by
three).

**A width test in the test font measures squares.** The repertoire strip's
"Move N of M" label is about 80 dp in Roboto and about 150 in the test font, so
the strip "wrapped" in the test and not on the phone — and the Analysis strip,
all icons, passed the test at 800 dp and wrapped on a real 760. Both halves of
rule 8 at once: the fixture was luckier than the phone (800, no eval bar, no
system buttons), and the glyphs were not the phone's. `loadRoboto()` loads the
SDK's Roboto and throws if it cannot, and one test proves the font took
(`iiii` narrower than `MMMM`) — the golden test's loader returns silently when
the files are missing, which is the check that cannot fail.

**Four reports on the same evening — 16.9.2026, 2819 in the app with 1 skipped,
analyze at 26.** The arithmetic: 2807 + 5 in `home_landscape_test.dart` + 1 in
`analysis_draft_restore_quiet_test.dart` + 4 in
`core/mating_move_comment_test.dart` + 2 in
`analysis_mating_move_comment_test.dart`.

**Silence a sentence where it is written, not where its facts are found.** The
owner wanted no comment under a mating move. The first cut emptied the
detectors' `explainMove` after a mate, and `game_tutorial_facts_test` went red:
those findings are a tutorial's facts too, compared with the Python harness
byte for byte. One reader's wish had been written into the source of a second
reader. The rule now sits in `autoMoveComment`, which only the three writers of
a move's comment call, and the facts are as they were.

**A mutation that survives because the fixture has nothing to say is still a
question.** The positional half of the rule survived: in the reported position,
and in three hand-picked mates, the positional evaluator had no comment to
silence. Walking 400 random games to a mate with the rule taken out found 160
where it did, and the test stands on one of them.


**Phase 0 of the reorganisation and of the puzzle progress — 17.9.2026, backend
1376 → 1387, app unchanged at 2819 (+10 in `analysis_teach_menu_test.dart` on
the working tree, not yet in the quoted number).** The eleven are
`test/puzzle_progress.test.js`: the fold that derives solved-first-try, failed
and skipped from the first and the latest row of each puzzle, and the one SQL
line behind it. Five mutations, each caught by the test it names.

**A `trap` in a tool call that is moved to the background never fires.** The
first full backend run with `.env` moved aside did not return inside the tool's
ten minutes and was pushed to the background; when it was looked at, no node
process existed, no output had been written, and `.env` was still aside — the
`mv … && trap` pattern the rule prescribes restores nothing if the shell that
set the trap is killed. Restored by hand from the backup. The second run,
started detached with a hard `timeout` and the restore *after* it in the same
script, took 14 seconds. Two rules from it: **copy, never move, the thing a
trap is meant to put back**, and a suite that took 14 s the second time did not
hang the first time — the tool did, so look at the process list before blaming
the tests.

**A widget test that measures in the real font is a test of where the font is.**
Two CI runs in a row (8437b3e, bd64f9c) failed nine layout files in `setUpAll`:
`loadRoboto()` reads the SDK's `material_fonts` cache, and on the runner that
directory has no `roboto-regular.ttf`. The loader was right to throw — a
silent fallback would have measured squares and said nothing — but the path was
the machine's. The fonts now travel with the tests (`test/fonts/`, Apache 2.0,
three files), and the loader reads the repository, not the SDK.

**The sheet's own overflow test caught its own overflow.** Six dense rows and a
title are nine pixels taller than the 9/16 of a 360 × 640 phone a modal sheet
may take by default. The test written to guard the phone went red on the first
run, and the column scrolls inside the sheet now — the rule that a new test is
watched failing, met by accident and worth the note.

**Puzzle progress phase 1 — 17.9.2026, backend 1387 → 1406.** The nineteen are
the routes gate, `test/puzzle_progress_routes.test.js`. What the worker's
report taught, in three lines. **A worktree checked out with `autocrlf` turns
a byte-for-byte fixture test red**: `tutorial_words.test.js` compares the
prompt with a template file, the worktree wrote that file with CRLF, and ten
tests failed there that pass in the main tree and on CI — the instrument, not
the work; the template belongs in `.gitattributes` as `text eol=lf` before the
next worker meets it. **A worktree made by the agent tool may sit behind the
commit the brief names** — this one was at `bd64f9c` with the brief saying
`b879423`; the worker fast-forwarded and said so, which is the right answer,
and the brief should tell the next one to check `git log -1` first. **A gate
that reads a bound parameter fails a literal that means the same thing**: the
Lichess insert had `'lichess'` written into the SQL, the gate looked for it in
the parameter list, and the worker bound it rather than editing the gate —
the sentence in the brief about a wrong test working as intended.

**Reorganisation phase 1 — 17.9.2026, app 2819 → 2831, 1 skipped, analyze 26.**
The arithmetic: 2819 + 10 in `analysis_teach_menu_test.dart` (the lead's
sheet) + 4 in `analysis_teach_door_test.dart` (the gate, copied from
`docs/gates/`) − 2 in `game_tutorial_door_test.dart` (two assertions the gate
now holds). Measured by the lead in the worker's worktree, not taken from the
worker's report, which said the same.

**An agent's worktree starts behind the commit its brief names.** Both
implementer worktrees of this day were made at `bd64f9c` although the briefs
named `8bb0034` and `b879423` — the files the briefs pointed at were not
there. Both workers noticed, fast-forwarded, and said so, which is the right
answer; the brief now has to say *check `git log -1` first and fast-forward to
the named commit*, because the third worker may not notice. Same family as the
worktree that ran `flutter pub get` and left the platform registrants
modified: a tree that is not what the brief says it is.

**Reorganisation phase 2 and the manual batch — 17.9.2026, app 2831 → 2839,
1 skipped, analyze 26.** The arithmetic: 2831 + 15 in `manual_places_test.dart`
(1 + 13 pages + 1) − 7 deleted with `create_course_dialog.dart` (2 in
`course_dialog_labels_test`, 2 in `dialog_layout_test`, 1 each in
`lesson_editor_test`, `part_titles_shown_test`, `tutorial_versions_test`).
Measured on `master` with nothing else running — the reading before it said
229 analyzer issues and no suite at all, taken while a worktree was being
created beside it; rule 19 holds for the analyzer too.

**An enum that grows breaks every `values` loop that meant three of them.**
`LibraryKind` gained `tutorial`, `recording` and `puzzleSet` for the one
library; `PositionPickerDialog` drew a chip per `LibraryKind.values`, six chips
wrapped to a second row, and `dialog_layout_test` overflowed by 17 pixels. The
picker now names its three shelves (`pickerKinds`). The rule: a `for (x in
Enum.values)` in a widget is a claim that every future member belongs there —
write the list the widget means, or the day the enum grows is the day a
dialog overflows in silence in a release build.

**The manual outran the code by design, and the merge order followed it.** The
batch's pages were merged *before* phase 2 so that phase 2's quote edits to the
same five pages lost cleanly to the rewritten ones (`git checkout --ours`),
instead of the batch losing to phase 2's older sentences.

**Reorganisation phase 3a — 17.9.2026, app 2839 → 2859, backend 1406 → 1412.**
The arithmetic: + 9 in `library_list_test.dart` (the gate) + 11 in
`puzzle_attempt_api_test.dart` (the lead's wire for the progress plan, on the
same day); backend + 6 in `library_kinds.test.js`.

**A card must not repeat the name of the tab it sits on.** The worker headed
the Library tab's new card „Library"; `home_tabs_test` counts how many times a
tab's name is drawn and read the card as a second header. The test's absolute
count was made relative first (rule 5 — a claim about the whole screen), and
then the card was renamed „Everything you keep", because a reader under a
heading „Library" does not need the word again a hand's width below it.

**A seam the brief forbids the worker to add is the lead's to add the same
day.** The Library opens a saved analysis; the Analysis screen took a FEN or a
main line, so the worker flattened the tree and said so — variations,
comments and arrows dropped. `initialTree` went in beside `initialGame` in
one lead commit and the screen opens the tree whole. The report's section 3
is where this was found; a report without it would have shipped the main
line.

**Two suites on one machine, and `opening_book_service_test` times out** —
rule 19 again: the phase-3 worker saw it while the progress worker's suite
ran beside it. Grade one tree at a time.

**Puzzle progress phase 2 — 17.9.2026, app 2859 → 2878.** The arithmetic:
+ 8 in `hub_progress_test.dart` (the gate) + 11 in the three drill recording
tests the worker wrote against a fake client. Backend unchanged at 1412.

**A brief's premise is a claim, and the worker is the first reader who can
test it.** The brief said the mate drill's `_submitPuzzleResult(true)` fired
for winning positions and basic mates too; it did not — those two recorded
nothing, ever, and the „Incorrect Move" sheet's two buttons recorded nothing
either. All three surfaced in the report's section 3, which is why that
section is asked for before the numbers. **An `int` on the wire for an id
that is a string in the model drops rows in silence** — the worker parsed and
skipped, said so, and the wire now takes the id as it is; the fixture with
`'bg_test'` is the test.

**The one screen with no seam is the one with no test.** `ai_studio_screen.dart`
starts a real engine in `initState`, so its recording — mates, winning
positions, basic mates — is checked by reading and by the live item 176, not
by a test. Phase 6a's lesson applies here too: a 3200-line screen that owns its
services cannot be handed to a widget test, and the day it gets a controller
is the day it gets one.

**A doc edit that dies before the commit line under it.** Twice in a row a
Python heredoc failed to parse — first blamed on the console's encoding, then
found to be a plain `"` inside a double-quoted string — and the `git commit`
chained after it went through with the *other* files, recording half a phase.
Read the tool's output above the commit line before trusting it; put a script
with quotes and dashes in a file, not a heredoc.

**Reorganisation phase 5 — 17.9.2026, app 2878 → 2882.** The arithmetic: + 5
from `home_map_test.dart`, the gate that moved into `test/` green (four in the
phase-2 group, one in the phase-5 group; its 6c group stayed behind as
`docs/gates/one_editor_test.dart`) − 1 in `manual_places_test.dart`, whose
„no page quotes a retired label" test went with the retired list it read,
because the words are gone from `lib/` and the labels test now catches them.
Backend unchanged at 1412; analyze 26.

**A source-reading test names a file, and a phase that deletes the file
breaks it a suite later.** `screen_names_en_test` read the Library tab to
check that the cards for Preparation and Analysis said what was different
between them; phase 5 deleted the tab and made Analysis a tab of its own, and
the named tests were green because none of them was this one. The full suite
was run before the commit for exactly this — and the one red was the right
red. The rule survived the file: the two doors that now share a room are
Preparation and New session on Teach, and the test reads those. Proved by
mutation: „no student" removed from the card, the test red, restored.

**The header is drawn by the shell, and one tab draws its own.** Analyse
mounts the Analysis screen whole, with its app bar; drawing the shell's
`_TabHeader` above it put two bars on one screen. The header is skipped for
that tab alone, in portrait — in short landscape the screen already draws
nothing above the board and the shell's bar is the only one. Item 177 says
which.

**A gate's date stays on the file that moved.** `home_map_test` kept its
„written 17.9.2026, red on master at bd64f9c" line when it moved into
`test/`; the day it went green is the day the shell changed, and a reader who
finds it in the suite should know it was once a gate and where the rest of it
is.

**Reorganisation phase 3b — 17.9.2026, app 2882 → 2894.** The arithmetic:
+ 7 in `library_list_test.dart` (the phase-3b group: a subset of chips, the
Mine / From trainer split, no origin chips unasked, the label filter, no
labels no panel, search by label, own height in a scrolling column) + 5 in
`room_library_test.dart` (two that read the screen, three that drive the
column). Backend unchanged at 1412 — the tutorial shelf's tags were asserted
inside the existing tutorial test. Analyze 26.

**A second list is a second search, a second filter and a second row.** The
room's column had its own search field (server-side, by title and tag), its
own label matrix (server-side, include/exclude/mode on the wire), its own
three category chips and its own row widget with a board thumbnail — 350
lines beside a widget that drew the same things for the Library screen. What
it needed that the widget lacked was four parameters, and the label filter,
once it had a home in the widget, came to the Library screen for free — where
the manual had promised it since the batch that rewrote the page. Rule 12 is
cheaper than it looks when the second copy is read for what it *needs* rather
than what it *does*.

**A ListTile under a coloured Container asserts, and only a widget test with
tiles in it sees that.** The column was `Container(color:)`; the old rows
were `Card`s, which are Materials, so nothing asserted. The shared list's rows
are bare tiles, and the room test threw three assertions per frame — the same
fault the right sidebar's comment describes, fixed the same way.

**A fake that answers the old read keeps an old test green until the read
moves.** `part_titles_shown_test` served `/lessons` and answered `{}` to
everything else; when the column moved to `/library/positions` the room drew
nothing and the test failed on a tap — the right red, from the full suite, not
from the eleven files run first. Two fakes were extended (that one and the
versions test's); each now serves the shelf and the row from one client so one
fake tells one story.

**A snackbar that queues behind another is not a message a test can wait
for.** The tap's „Loaded step 1/1" sits behind the room's own „Position
loaded and synchronized!" for the first one's full timer. The test asserts on
the course bar over the board — the thing the tap actually does — and says
why the snackbar is not the assertion.

**Reorganisation phase 6a — 17.9.2026, app 2894 → 2908.** The arithmetic:
+ 14 in `tutorial_draft_controller_test.dart`, every one of them a plain
`test()` with no frame pumped. The 46 studio test files (543 tests) passed
unedited, which was the other half of the gate. Backend unchanged at 1412;
analyze 26.

**The screen was the model, and the extraction is mostly deletion.** The
studio kept the open part's kind, task, answers, recorded move and
orientation in fields of its own and wrote them back in
`_syncSelectedSection` before anything was persisted — the shape behind the
bug of 7.9.2026, where a field left at its default was written over the part.
With the fields writing through to the model there is nothing to sync, and
the six places that called sync-then-persist became one method each on the
controller. 2693 lines became 2219 and 660 of them are the controller.

**Two signals, not one.** A controller that notifies on every change makes
the screen rebuild its text fields on every keystroke, and a text field
rebuilt from the model under the caret moves the caret. So `notifyListeners`
means „redraw" and `generation` means „the open part or the draft was
replaced — rebuild your fields", and typing bumps the first only when the
undo buttons change and the second never. The board follows the cursor's
identity the same way: loaded when the node the cursor stands on is a
different object, not on every notify.

**A rule the editor implied lived in a field, and a frameless test found it.**
A stored question with two right answers came back with one because the
screen's radio group could hold only one and the first sync wrote that back.
With write-through nothing normalised it, and the refusals test — a widget
test — went red. The rule now runs where a draft comes in, and the
controller's own test pins it. The old place was accidental; the new one is a
sentence with a reason.

**A save with unchanged content replaces the current history step, so an
undo goes past it in one move.** The first ids test asked for an undo after
a rename after a save, which restored the post-save snapshot and never
exercised `_giveBackIds` — the mutation survived. The test now undoes
straight after the save and lands on the snapshot from before any id
existed, which is the case the method is for. A surviving mutation is a
question about the test (rule 2), and here the answer was that the test had
not read `DraftHistory.record`.

**Reorganisation phase 6c — 17.9.2026, app 2908 → 2872.** A drop, and an
expected one, written into the brief before the worker started. The
arithmetic: − 30 in the four test files of the deleted panel
(`lesson_editor_test` 7, `lesson_step_order_test` 12,
`lesson_step_order_extra_test` 3, `lesson_answer_stays_hidden_test` 8);
− 6 in `landscape_screens_test` (the panel's group, three tests over four
phone sizes — the brief said „one case", the worker read the file and said
six); − 4 single tests whose whole point was „without the studio"
(`tutorial_editor_door_test`, `tutorial_ulaz_test`,
`tutorial_import_flow_test`, `analysis_teach_menu_test`); + 1 in
`tutorial_draft_controller_test` (a rule re-homed: a question from a list
may keep its line); + 3 in `one_editor_test.dart`, the gate moved into
`test/`. Backend unchanged at 1412; analyze 26.

**A deletion batch is graded on what it kept.** The brief told the worker
to read the deleted panel's tests for rules that outlive the panel before
deleting them, and it found one the studio side did not pin. It moved the
rule onto the controller and proved it by mutation before deleting the
file. The report's section 1 named two tests the brief had not — a menu
test the parameter removal broke, and a guard test that froze the
deleted file's name in a set — which is what that section is for.

**A gate written by hand had a `''` in it, twice.** The same escape
that broke `home_map_test` broke `one_editor_test`, and a chained
`git commit` recorded the broken gate before the test's compile error was
read — the heredoc lesson, again, with a `;` instead of a `&&`. Fixed with
an editor, not a shell substitution, and the unpushed commit amended. A
check that cannot compile is not a red.

**Reorganisation phase 6b — 17.9.2026, app 2872 → 2876.** The arithmetic:
+ 4 in `tutorial_phone_layout_test.dart`, the gate moved into `test/`. The
studio set stands at 561 (543 after 6a, + 14 controller tests, + 4 gate).
Backend unchanged at 1412; analyze 26 — after five warnings the worker never
saw, because it never ran analyze: an extension on a `State` calling
`setState`, which is protected. Three one-line methods on the state fixed it;
the grade is the lead's measurement, not the report.

**A worker that stops on a gate it believes wrong is the sentence in every
brief doing its job.** Two defects, both the gate's, both proved with a
repro before the report: a `tearDown` that resets
`debugDefaultTargetPlatformOverride` runs after the binding has already
checked it is null, so the reset belongs inside the test; and the
byte-equality test opened the desktop half through the Studio's door, which
adopts an open draft by design, so the phone's draft leaked across and the
desktop PUT to the tutorial the phone had just made. The worker patched a
local copy to show its layout passed, deleted the copy, and left the gate
untouched. Rule 6 in a new coat: the fixture (one device slot for two
screens) was luckier than the real thing.

**`Theme.of(context).platform` is Android inside `flutter test`.** Every
narrow-window test of the desktop studio would have routed into the phone
layout; eleven cases in four files did. The layout reads the test override
where a test set it and `dart:io` otherwise — the same split the deleted
platform guard used, and the reason it was a one-line change to reverse.

**A rule held per file is a rule a second file escapes.**
`move_keys_everywhere_test` reads each file that draws the move strip and
asks for the keyboard shortcuts in the same file; the phone layout is a
`part` and drew the strip without them — and, since the phone branch
returns its own `Scaffold` before the desktop's wrapper, it really did not
answer the arrow keys. The full suite on master found it; the worker's
studio set could not. The rule was right, the layout was wrong, and the fix
was the wrapper the rule asks for.

**A tap lands on a widget's centre.** A `ListTile` whose subtitle held five
buttons put its centre on „Clone part", and a tap meant to select part 0
cloned it. The buttons moved out of the tile. The gate's byte-equality
test caught it as a third part where two were expected — which is what a
test on the wire sees that a test on the screen does not.

**„Saved tutorials" empty on a phone — 17.9.2026, app 2876 → 2879.** The
arithmetic: + 3 in `saved_tutorials_phone_test.dart` (two phone sizes and
Windows). Backend unchanged; analyze 26.

**A touch target is a size the desktop never draws.** The owner saw the
dialog on Android with its search box, fourteen label chips and no
tutorials, while Windows listed them all. The rows had loaded — the chips
are read off them. Flutter's default `materialTapTargetSize` pads a chip to
48 dp on Android and iOS and leaves it at 30 on a desktop, so the same
fourteen labels wrapped into seven rows in a narrower dialog, overflowed a
fixed 400 dp cap by 288 px, and left a `Flexible` list zero height. Every
widget test of this dialog ran with the test's default platform and a few
labels, where it fits. It is the second of the two release-build traps in
`CLAUDE.md` — the overflow that paints nothing — with the platform deciding
the size, and the fix is the rule's: nothing above a list may take all its
room. Found by the owner, reproduced by measuring before a line was
changed, and the test is the owner's own labels.

**„Saved tutorials" opens the Library — 17.9.2026, app 2879 → 2879.** The
arithmetic: − 3 in the first `saved_tutorials_phone_test.dart` (the dialog
at two phone sizes and Windows), replaced by 7 on the Library (four sizes in
both orientations, the trainer's own tutorials, search and a label, Windows);
− 4 in `tutorial_import_flow_test.dart`, the group that tested the dialog's
own chips and search box, whose rules now live in `library_list_test`.
Analyze 26; backend unchanged.

**A first fix measured on a lucky fixture is a second report.** The fix for
the empty dialog was tested with tutorials that had no film — three buttons,
not four — and titles of two words, and it passed. The owner's phone had
films and sentences for names: each row was four icons and no title, and
held sideways the chips took the height again. Rule 6, again, the same day:
the fixture has to be what the owner's screen holds, and the second test is
built from their screenshot, not from the first test.

**When a second copy of a list breaks, delete the copy.** The dialog was the
Library's list, search, labels and four actions written a second time, in a
container that cannot give a phone room. Offered three ways, the owner chose
to open the Library instead; the rows' fit on a phone was then fixed once, in
`LibraryList`, for the Library, the Saved-tutorials door and the room's
column together. The Library had its own dormant faults the dialog did not —
a trainer's tutorials offered send and delete to a student, a download that
found no film left its button — and routing a busy door through it woke both
(rule 14), which is when they were fixed.

**A recorded deletion is a claim, and it can be false.** Phase 5 wrote that
`biblioteka_tab.dart` was deleted; the file was still tracked, untouched, and
a source-reading test was still reading it. The `git rm` never reached the
commit. `git ls-files` answers the question; the handoff does not.

**Settings reviewed: board size and Analysis panels move to their screens —
17.9.2026, app 2879 → 2886.** The arithmetic: + 2 in `board_view_menu_test`
(no slider unless asked; the slider sets the scale), + 3 in the new
`board_view_menu_reach_test` (the slider exactly where the scale is read, a
board menu always over a framed board, the Analysis board following the
slider), + 2 in the new `analysis_panels_sheet_test` (panels read only by
the Studio and chosen only in its sheet; a panel unticked disappears under
the open sheet). Analyze 26, the same list; backend unchanged.

**A setting in Settings claims to apply everywhere.** „Board size" sized three
boards of eighteen, and the six „Panels in Analysis" boxes were read by one
screen, which the reader had to leave to change. Answered by grepping the
readers, not by reading the Settings page. The same sweep found the other
side of it: the walkthrough offered „Coordinates" over a board that drew
none. Once a control sits on the screen it changes, the screen has to listen:
the Analysis Studio re-read the scale only when a page on top of it closed,
which the test caught by mutation before any phone did.

**The comment switch leaves Settings, and every depth picker reaches 50 —
17.9.2026, app 2886 → 2892.** The arithmetic: + 1 in
`analysis_panels_sheet_test` (the sheet's switch is the manual mode reversed;
the source guard now covers the comment setting too, inside an existing
test), + 4 in the new `engine_depth_ceiling_test` (the ceiling, the scanner's
depths, the Review dialog at a remembered 42, Auto Analysis at 50), + 1 in
`game_tutorial_flow_test` (the slider runs 18 to 50). Changed in place, no
count: two dial tests and two `game_tutorial_slice_test` tests that tapped
the old radio buttons. Analyze 26, the same list.

**A limit written in five places is five limits.** The board remembered
depths up to 50 while the Review dialog, opened from that board, stopped at
30 — a remembered 42 put the slider's value past its own end. It had not
happened only because the board's dial skipped from 30 to 34. The ceiling is
now `AppSettingsService.kMaxEngineDepth`, and the dialogs read it (rule 12).

**Grep a key before changing the widget that carries it.** The first full run
after replacing the tutorial's radio buttons failed two tests in a file that
the search for the list's *name* had not found: they tapped the radios by
their key string.

**The engine opponent moves onto the exercise screen — 17.9.2026, app
2892 → 2895.** + 3 in the new `engine_opponent_sheet_test` (read only by the
exercise screen and set only in its sheet, and the screen offers the sheet
wherever it offers its board menu; the sheet sets level and time; the button
opens it). Analyze 26, the same list.

**A guard on who reads a setting does not see the button go missing.** The
first version checked readers and writers; removing the portrait header's
button passed it, because the screen still read the setting. The guard now
counts the screen's board menus against its opponent buttons. Same shape as
the arrow-switch guard: a setting with a reader and no control on the screen
it was moved to is the „menu that does nothing" from the other side.

**Homework, phase 0: the game's ending has a name — 17.9.2026, app
2895 → 2906.** + 11 in `drill_outcome_test`: five endings, one position
each, every one proven to satisfy its rule and none of the other four; a
running game; the move limit; resignation; the board before the inputs;
`outcomeFor` equal to the verdict's outcome; every ending has words. Seven
mutations, seven right reds. Analyze 26.

**Measure the gap before planning to fill it.** The plan said the exercise
screen „detects checkmate and nothing else". It read its verdict through a
function that already covered every draw by rule; the grep that produced the
sentence matched `in_checkmate` in the screen and stopped there. The gap was
real but different — the reason was missing, and the verdict was read after
the engine's move only — and the phase shrank from a service to a widening
of one function. Rule 12 from the other side: before writing a second
implementation, find the first; before *planning* one, find it too.

**Homework, phase 1: the schema and the gate, on a real database —
17.9.2026, backend 1412 → 1437.** + 24 in the new `homework_gate.test.js`,
+ 1 for its suite line: 1437 with `TEST_DATABASE_URL`, 1413 without, where
the suite reports as one skipped line (`﹣`) although node's `skipped`
counter says 0. 22 mutations, each red on the right test. App unchanged.

**A stub pool cannot fail a WHERE clause.** Every backend test until this
one answered queries with canned rows, and the gate of this phase is nothing
but WHERE clauses and CHECKs. A local PostgreSQL 17 binary was already on the
machine, so the tests build a throwaway cluster and database instead of a new
dependency; CI gets a service container, and in CI a missing URL fails the
run — a gate that skips wherever it is not configured cannot fail (rule 1).

**A harness that cannot read the result reports every mutant as survived.**
The first mutation run said all sixteen survived, with a pass count of `?`:
Python decoded node's `✔` as cp1250 and the regex found nothing. Sixteen
„survived" and zero information. The harness now refuses to report a run it
cannot parse. Rule 3 again — a result is only a result if it is the right one.

**Two survivors, two blind spots in the tests, none in the code.** A helper
that read „passed" before „locked" could not see a completed item become
locked; the trainer's use of the review route was never exercised, so a guard
that refused the trainer too survived. Both were asserted directly after.

**Homework, phase 2a: „play it out", judged by the server — 17.9.2026,
backend 1437 → 1470.** + 28 in the new `engine_game_task.test.js` (16 fixture
cases, 5 refusals, and 7 of its own), + 5 in `homework_gate.test.js` for the
route. 1470 with the database, 1441 without. 24 mutations, each red on the
right test. App unchanged; its half is a brief and a gate.

**A fixture typed from memory is not a fixture.** Five of sixteen cases in the
shared file were wrong when written: three had a queen moving to a square it
already stood on, one claimed a mate that left the king an escape, and one
claimed a threefold repetition two plies before it was one. They were found by
replaying every case on a real board — and only after the probe was fixed,
because its first version printed the *claim* beside the case name instead of
what the board said, so five broken cases read as five green lines.

**A guard in front of a guard hides a mutation.** „Anyone may play this game"
survived, because the test used a gated item: the lock refused the request
before the ownership check was reached. The same shape as two survivors in
phase 1 — the test has to stand on the boundary the check owns, not behind an
earlier one (rule 6).

**Homework, phase 2b: the app half, graded and merged — 17.9.2026, app
2906 → 2943.** + 34 from the implementer (24 the gate, 10 the screen), + 2
from the lead's correction of the gate, + 1 for the portrait reachability
test. Analyze 26, the same list; backend untouched. Four mutations on the
lead's own fixes, each red on the right test.

**A gate can be wrong, and „stop and say so" is what saves it.** The gate
asked the app to refuse a task using information the task does not contain:
the fixture's „illegal move" entry carries a task byte-for-byte identical to
an accepted case. The worker's report opened with it and did not touch the
test — the sentence every brief carries earned its keep. The fix also closed
the hole that made the mistake possible: a test now asserts both kinds of
refusal are present, so neither loop can pass by being empty.

**A guard that counts controls in the source cannot see them reach the
screen.** `engine_opponent_sheet_test` counted board menus against opponent
buttons in `ai_studio_screen.dart` and passed — while both, plus the goal
banner, sat in a `backButtonCard` that portrait never placed in its tree. The
lead had reported that button as „in both headers" on the strength of that
count. Found by the worker while reading the screen, fixed by moving the two
controls into the app bar, and proved by a widget test that pumps the real
screen at 360×640. Rule 10 from the side that is easiest to miss: the layer
was right and the control was unreachable.

**„A pre-existing overflow" was the test's own font.** The worker's screen
test consumed a first-frame `RenderFlex overflowed by 134 pixels`, documented
as reproducing on master. It does not: without `loadRoboto` every glyph is a
square a full em wide, and the AppBar's title row only overflows in that
measurement (rule 8). The font is loaded now and nothing is consumed — and
the same test then caught a real 18 px overflow the lead's own app-bar
actions introduced.

**Homework, phase 3a: the template a trainer writes — 17.9.2026, backend
1470 → 1486 with the test database (1441 without).** + 16 in the new
`homework_template.test.js`: the reorder gate, keys minted rather than
indexed, an item added in the middle, an item removed, a key from another
homework treated as new, the per-kind task validation, ownership, the twenty
ceiling, and the routes' status codes. 14 mutations, each red on the right
test. App unchanged.

**The third time, designed in rather than migrated.**
`assignment_items.step_key` and `review_items.step_key` were both migrations
away from an index used as an identity. `homework_items.item_key` is minted
from the start, and the reconcile step is written so a reorder rewrites
`position` and touches no key — with a test that fails if a key is ever
derived from an index.

**A key the client sends is a claim, not a fact.** The editor sends each
item's key back, so `saveHomework` first reads which keys the homework really
holds: a key belonging to another homework is treated as a new item instead
of writing over somebody else's row. Proved by a test that hands one
homework's key to another and then reads the first one back untouched.

**Homework, phase 4: sending — 17.9.2026, backend 1486 → 1503 with the test
database (1441 without).** + 12 in the new `homework_send.test.js`, + 5 in
`puzzle_resolution.test.js`. 15 mutations, each red on the right test. App
unchanged.

**A whole homework or nothing.** `sendHomework` plans every item — loading
the tutorial, re-checking each position, resolving the puzzle set for *this*
student — before it opens its transaction, so a refusal writes nothing and
the route can hand the quota unit back. Four tests send a homework whose
content went bad in between and then count the student's assignments: zero,
not „the good items landed".

**The bug the impossible fixture found.** A homework with a deliberately
unmatchable puzzle set (theme `zugzwang`, rating 3200–3400) made
`resolvePuzzles` throw `could not determine data type of parameter $4`: the
fallback query drops the `NOT EXISTS`, so the student's id it still carried
was a parameter nothing referenced. It fires only when the first query comes
back empty — the one case the fallback exists for — so a trainer's narrow
filter answered 500 on `POST /assignments` instead of „no puzzles match".
Eight months of stub-pool tests could not see it, because a stub answers
whatever it is told; the real-database test that found it took four lines.

**A fixture whose ids look like indexes cannot see an index used as an id.**
The mutation „steps travel by index" survived: the tutorial fixture's steps
were `p0, p1, p2`, which is exactly what `p${index}` produces. The ids are
now `s21x, s28x, s35x` and the mutation dies. Rule 6, and the third time in
two days that a survivor was the fixture's fault rather than the code's.

**Homework, phase 3b: the trainer's editor — 17.9.2026, app 2943 → 2966
tests, 1 skipped; analyze back to the 26 known infos.** 12 from the gate, 6
from the implementer, 5 from grading. Backend untouched.

**A brief that contradicts its own gate costs the worker a round.** The brief
said „do not offer the gate switch on the first row"; the gate taps exactly
that row's switch (`homework-gate-ia1b2c3d4`, position 0 in the fixture). The
implementer stopped, said so, and kept the gate — the second time in two days
that sentence about stopping rather than working around has paid for itself.
The gate was the right one: a control hidden on row 1 swallows the setting of
an item the trainer dragged to the top, invisible and un-editable until they
move it back. **Read the brief against the gate before handing both over.**

**The gate itself was one info above baseline.** `requests.add(request as
http.Request)` — `MockClient` already types its handler's parameter, so the
cast was `unnecessary_cast`. The worker measured it the only honest way
(remove the file, analyze, put it back: 26 → 27), refused to edit the gate,
and reported it. A gate is code and gets reviewed like code.

**A default is not a choice.** The „play it out" picker read the student's
side off the FEN's turn field, which reads correctly on every fixture in
`docs/gates/engine_game_cases.json` and cannot express „hold this draw, engine
to move" — a task `ai_studio_screen.dart` and `judgeEngineGame` both already
handle (`turn != task.side` makes the engine open; own moves are counted by
turn). The FEN is now the default and the trainer picks. The test that proves
it uses the *same* position twice, once with each side to move: a suite that
only ever tries a white-to-move FEN cannot tell a real reading from `'w'`.

**A fresh clone on Windows had ten red backend tests — 18.9.2026.** The
phase-5 worktree reported `test/tutorial_words.test.js` failing 10 of 27 and
called it „pre-existing"; on this checkout the same file passes 27 of 27, so
it was neither pre-existing nor the worker's doing. A worktree is a fresh
checkout, and `chess_backend/services/prompts/tutorial_words.txt` — stored
LF, carrying only `text=auto` — comes out of a fresh checkout on Windows as
CRLF. That file's bytes are the contract: the server must build, byte for
byte, the prompt `skeleton.py` wrote into the fixtures, and the test compares
them. This checkout was green only because its working copy predates the
conversion.

Proved both ways before fixing: the working copy converted to CRLF by hand
made the same 10 fail here, and after `chess_backend/services/prompts/*.txt
text eol=lf` a delete-and-check-out brought the file back as LF and all 27
passed. CI is Linux, so it never saw this; the next person to clone the
repository on Windows would have.

Two rules out of it. **A worker's „pre-existing failure" is a claim about
master, and master is where it has to be measured** — this is the third time
in three days that a reported pre-existing problem was the worker's own
environment. And **a file whose bytes are a contract needs `eol=lf`, not
`text=auto`**: `*.sh` already had it for the same reason, one layer away.

**Homework, phase 5: the student's screen — 18.9.2026, app 2966 → 2994
tests, 1 skipped; analyze unchanged at the 26 known infos.** 15 from the
gate, 6 from the implementer, 7 from grading. Backend untouched.

**A feature can be finished, proved and unreachable.** Phase 2b built the
assigned game and the server's judge, mutation-proved both, and shipped a
screen whose only caller in the whole repository was its own test — because
a „play it out" item exists only inside a homework, and the homework screen
did not exist yet. Rule 10 again, and the lesson for planning: when a phase
builds a screen nothing yet opens, write down which later phase is its door.

**No test could answer the network here, and nobody noticed for months.**
`AssignmentApiService` called the top-level `http.get`, so the student's
list, the assignment detail and everything built on them had never had a test
that could see a wrong address or a missing field. The seam took twenty
minutes; the phase could not have been graded without it. Ask of any service:
*what would a test have to fake to see this go wrong?*

**Two answers where there are three.** `fetchDetail` first came back as
„the detail, or a blocker id", so „the server did not answer" and „you are
locked out" were the same answer with a null in it — the shape the account
guard was rewritten for in August. It now says `locked` in its own field.
The same reading fixed a second thing: the server answers a locked item with
**423**, not 200 as my brief claimed, and a check written against the status
would have passed the companion test (which sent 200) and failed in front of
a student. **Read the flag, not the status, and fixture the status the
server actually sends.**

**A surviving mutation was the mutation's fault.** Making the review button's
condition always true left the test green, because the outer guard on the
whole row of actions still suppressed it for an untouched item. Both guards
mutated together, the test went red. Rule 2 holds either way: the survivor
is a question, and here the answer was „you mutated dead ground".

**Homework, phase 4's app half: sending — 18.9.2026, app 2994 → 3008
tests, 1 skipped; analyze unchanged at the 26 known infos.** 14 new, 10
mutations each red on the right test, the phase-3b gate green throughout.

**A quota rule is kept by the shape of the request, not by a sentence.** One
student is one request because the server charges one unit per request; a
batched send would have to answer „two of your three" with a single status
code, and the trainer would not learn which two. The dialog therefore loops,
names every student the server refused with the server's own sentence, and
still reports the ones that went — half a send is a fact, not an error to
swallow.

**A screen that speaks after it closes says nothing.** The dialog first popped
itself and then called `AppFeedback`, whose context was by then gone — so the
guard correctly stayed silent and the trainer would have learned nothing at
all. The result now travels back to the caller, which still has a screen to
say it on. Same shape as the two older cases: **do the thing, then say it —
from somewhere that still exists.**

**Saving twice made two homeworks.** Phase 3b's editor built its save payload
with `id: widget.homeworkId`, which a POST never updates, so the second save
in one sitting posted again. Nothing caught it because no test saved twice —
the gate asserts what one save sends. The id now comes from what was saved,
and the rows adopt the keys the server minted, which is what makes the second
save an edit rather than a delete-and-mint. **Ask of any create-or-update
screen: what does the second one do?**

**The owner's live pass of 18.9.2026: five fixes — app 3008 → 3023 tests, 1
skipped; analyze unchanged at the 26 known infos; backend unchanged at 1441.**
15 new (7 + 1 + 5 + 1 + 1), each proved by mutation on the code it guards.

**A sign-out that is narrow on purpose still has to name what it leaves.**
`SessionService.signOut()` was deliberately narrowed from `prefs.clear()`
because that wiped the engine path and the board scale — things about the
*device*. What nobody then wrote down is the other half of that list: the
analysis draft, the tutorial draft, the active room and the solved-puzzle list
are about the *person*, and they sat under unscoped keys. A brand-new account
signed in and Home offered „Resume analysis“, which opened the previous
account's tree. The fix is one place that owns the question —
`AccountLocalState` — called from all three doors a session opens or closes
through, so there is no fourth that skips it. **When a sweep is narrowed, the
things it stops covering are a list, and the list belongs in the code.**

**Two categories, and only one of them may be deleted.** Scratch (a draft, a
room, a „don't show me this again“ list) costs a session. A recording that has
not reached the server, and a puzzle set somebody named, cost work that cannot
be re-made — so they stay on the device and stay visible to the next account,
which is a hole, and a deliberate one: **a thing seen can be taken back, a
thing deleted cannot.** The third rule is the one that is easy to break while
building the first two: a guest who signs in *keeps* their draft. Same person,
same thought. Four of the seven tests go red when the wiring is removed and
three stay green — that split is the point of the file.

**Two true numbers under no labels read as one number contradicting itself.**
The endgames card carries two sources — endgames and the blunders from the
reader's own games, which have no card of their own — and drew „Solved 0 · 2
to retry“ over „Solved 1“. Both right, and the owner read them as a
contradiction. A card with one line needs no label, because its title is the
label; the moment a second line appears, both need one.

**A badge nobody can read is a badge that gets ignored**, which is the opposite
of what it is for. The „1“ on „Teach“ was exactly right — one piece of homework
handed in and not opened — and said so nowhere. The sentence now lives beside
the two numbers it sums (`TrainerPanel.waitingExplanation`), not in the screen,
and the model reads `counts.requests` off the wire rather than having somebody
subtract two lists.

**`Scrollable.ensureVisible` climbs through every scrollable above the widget,
not just the nearest one.** The phone studio's new row of moves keeps the
current beat centred in itself; written with the static helper it also centred
that beat in the *page*, so the board jumped up the screen on every move
played. Asking the row's own `ScrollPosition` moves the row and leaves the page
where the trainer put it. The widget test caught the symptom sideways — a tap
that „would not hit test“ — which is what a clipped, scrolled-away widget looks
like from the outside.

**A layout that leaves panels out on purpose has to be asked what it left with
them.** The studio on a phone drops Flow, Tree and PGN — correctly, there is no
room — and the phase gate checked that the three tabs are there and nothing
overflows. What no test asked is whether the trainer can still *read the line
they are building*: the answer was four arrow buttons and their memory. Rule 10
in a new coat — every layer right, and the thing still unusable.

**A Python rewrite of a CRLF file can double-space it, and every test still
passes.** Writing a text that already carries CRLF through a writer told to
translate every newline to CRLF turned 452 lines into 3439, and Dart does not
care about blank lines, so the gate ran green on a file that had been mangled.
It showed up only in a byte count. Edit a file in this repository by reading
bytes, replacing a substring and writing bytes — never by splitting and
re-joining lines with a terminator the writer will translate again. Same shape
as the doubled CR in `docs/TODO-provera.md` that `.gitattributes` was written
for: **one conversion applied twice.**

**The same pass, second round: the stale card was a read, not a write — app
3023 → 3030 tests, 1 skipped; analyze back at the 26 known infos; backend
unchanged at 1441.**

**The owner's measurement beat the lead's reasoning, twice.** Round one read
the code, found the skip correctly recorded at both ends, and concluded the
screenshot had been taken one puzzle early. It had not. What settled it was a
fact no amount of reading would have produced: *waiting does not mend it, but
going to any other screen and straight back does.* That sentence is a
description of a second **read**, and it moved the whole search off the write
path in one step. **When a report and the code disagree, ask the reporter for
the thing the code cannot tell you — what makes it change.**

**A fire-and-forget write and a read on the way back need an order between
them, and neither screen owns it.** Recording must not hold up the board, so
the attempt is fired and not awaited; the hub's `context.push` resolves the
moment the reader leaves, so `progress()` goes out at once and can be answered
with the log as it was one attempt ago. Three paths write that log and one
reads it, so the barrier (`PuzzleAttemptWrites`) sits beside the source list
rather than in any one of them. It is bounded at five seconds and deliberately
quiet when the bound is reached: a write that will not finish may leave a stale
number — where we already were — but must never leave a screen that does not
load.

**Rule out the loud suspect by measuring it, not by reading it.** „The refresh
is never called“ was the obvious cause and it was wrong:
`hub_refresh_after_drill_test` pushes a route, pops it, and watches the read
happen — and the fake answers a *different* tally each time, so a card that
never re-read and one that did are told apart by what they say, not by a
counter the test keeps to itself. The seam it needed (`attemptApi` on the hub)
is the one the three drill screens already carried.

**A mutation harness that silently does nothing reports a surviving mutation.**
Removing the tracking from the barrier left every test green — for a moment a
real question about the tests. The replacement had simply not matched, because
the script called `str.replace` without asserting the target was there. With
the same mutation actually applied, three tests went red. **Assert that a
mutation applied before believing what it proves**; an unverified mutation is
not evidence, and this is the fifth face of the same bug the whole file is
about.

**Dead UI answers a question nobody can ask.** Hunting for where the number is
read turned up a second `CategorySelectionHubWidget` inside the puzzle screen,
passed no progress at all. The first instinct — and what was asked for — was
to wire it to the same read. It could not be reached: both call sites always
pass an `initialCategory` (the route falls back to `'mate_puzzle'`), and every
path back to the hub is guarded by `!ownRoute`, so it was painted for one
frame as a drill opened. **Before wiring a screen up, ask who can stand on
it.** Deleting it took 145 lines out and put 83 back.

**Settings' second pass, 18.9.2026: the chrome above the board — app 3030 →
3034 tests, 1 skipped; analyze 26 known infos, checked as a list and not as a
count.**

**„There are other doors“ is a claim to check, not a reason to delete.** The
owner asked for two buttons to go from a row above the board, „postoje ulazi sa
tabova“. For „My games“ that was true — Practise has its card. For „Scan a
book“ it was not: `/scan/saved` is pushed only from the scan review screen,
so the button was the *only* way into the book scanner and removing it would
have removed the feature. It moved into the Analysis toolbar instead. Rule 10
wearing the other face: the usual question is whether a user can reach a new
feature; this one is whether they can still reach an old one afterwards.

**A default that names the widget costs layout.** The navigation strip's
`centerLabel` defaulted to the word „Navigation“ — it said what the row was,
never anything about the position, and it was wide enough to push two buttons
onto a second row on a 360 dp phone. Every screen that wanted a label was
already passing a real one; the three on the default wanted nothing. The
cheapest fix for a cramped row is often a word nobody reads.

**A workaround in one file is a defect in the shared one.** `dense` on that
strip keyed off landscape alone, and the phone studio passed `dense: true` by
hand with a comment saying why — „a phone's width is the same problem in
portrait“. The note was right and had been sitting there since 6b; it belonged
in the widget, not beside one caller. **When a caller writes down why it is
overriding a default, read it as a bug report against the default.**

**Nine 40 dp targets do not fit 360 dp, and that is arithmetic worth writing
into a test.** The Analysis strip carried four navigation buttons, a flip, and
four actions on the current move. No amount of tightening fits them; the
actions moved to the row that shows the move they act on. The test records
the nine-button case as *still wrapping* rather than asserting a row it cannot
have — so the next reader knows the row was measured and left, not missed.

**Moving a button changes when it is drawn.** The current-move row rendered
nothing when the move had no comment and no NAG, which was harmless while
„Add Comment“ lived in the strip and wrong the moment it moved in: the button
for writing the *first* comment cannot be hidden until a comment exists. Ask
of anything moved into a conditional container: what is its condition, and is
it still the right one for the new tenant?

**The formatter can add a lint.** Bracing a one-line `if` that `dart format`
had split across two lines was the difference between 26 infos and 27. The
count is checked against the *list* — `analysis_studio_screen.dart` is not one
of the five files that own the known ones, so a single info there is a new one
however familiar the rule looks.

**The second answer to the same screen — app 3034 → 3040 tests, 1 skipped;
analyze 26.**

**„A bit better, but not best“ is a verdict on the approach, not a request for
more of it.** The first pass at the crowded Analysis screen shaved: a row
deleted, buttons made denser, four actions moved down one level. All of it
true, and the screen still spent two cards of chrome between the board and
anything worth reading. The second pass asked a different question — not „what
can come off“ but „why are there two rows at all“ — and the two became one:
the move you stand on is the strip's centre label, and its four actions are one
button and a named sheet. **When a fix is received as insufficient rather than
wrong, stop tuning it and re-read the structure.**

**The screen already had the rule; it just was not applied here.** The Analysis
toolbar has always drawn its actions „as icons on a wide screen and behind a
menu on a narrow one“. The four move actions sat in a `Wrap` that could only
overflow. Reaching for a screen's own established idiom beats inventing a
second one beside it — and it is the difference between a change that needs
explaining and one that needs none.

**A slot that is being wasted is cheaper than a row that is missing.** The
strip's centre label had spent years on the word „Navigation“. It is exactly
where „where am I“ belongs, and using it for the current move removed a whole
card without adding a pixel.

**Deleting chrome is only safe once you know what it carried.** The shell's
„Chess Trainer“ bar held Settings, the notification bell and a guest's „Sign
In“. It went, but nothing new was built for them: landscape had already put
the same two at the end of `_TabHeader`, so portrait adopted that and „Sign In“
went with them. The one thing that genuinely does not survive is the bell on
the Analyse tab — which was already its state in landscape and accepted as
known. **Say the loss out loud instead of letting it be discovered**; a cost
named in the handoff is a decision, the same cost found on a phone is a bug
report.

**„Play it out“ takes the board a diagram gives you — app 3040 → 3054 tests,
1 skipped; analyze 26.**

**One sentence for every fault is no sentence at all.** The dialog refused a
FEN with „Not a valid position for 'play it out'“ while `fenIllegalReason`, one
call away, knew whether a king was missing, a pawn stood on the first rank, or
the side not to move was in check. The owner could not tell that the board —
the part they had actually typed — was never the problem. **A validator that
produces reasons and a caller that throws them away is worse than no validator
there at all**, because the caller looks checked.

**Accept the shape the world hands you, and show what you inferred.** A
diagram tool gives a board and nothing else; demanding all six FEN fields
refuses the commonest input there is. Castling is now read off the board — the
most permissive legal reading, and a guess, because a diagram cannot say
whether a king has moved. So the completed FEN is *written into the field the
trainer is looking at* rather than used out of sight: a guess about the rules
of a game being set for a student belongs where it can be corrected.

**Three rules for one control in one afternoon, and the third needs no rule at
all.** Two controls said the same thing and the question was which wins. First
the switch was a default; then „last action always wins“, which is at least
symmetric and testable. The owner then found the one that dissolves the
question: **if the FEN names its side there is nothing to decide, so the switch
is not drawn; if it does not, the trainer is asked — with nothing
pre-selected.** A control that can contradict its own data is a rule waiting to
be written; a control that only exists when the data is silent is not. **When
two inputs keep needing a precedence rule, ask whether one of them should be
absent.**

And the reason for the empty selection is worth keeping on its own: an answer
offered in advance is an answer half-given, and this one decides which colour a
student is asked to play.

**A test that cannot fail will pass a mutation twice.** The paste-wins test had
the owner tap the side the FEN already named, so the assertion held whatever
the code did; the second version re-entered *identical* text, which fires no
change event at all. Both times the mutation said so and the test was rewritten
until every step moved something. **Read a green mutation as a claim about the
test before it is a claim about the code.**

**A red test can be an earlier decision, not a stale one.** The two that broke
encoded §9 item 2 of the homework plan — the trainer picks the student's colour
*against* the position's turn, so „hold this draw, engine to move“ could be
set. The new rule makes that unsayable in this dialog. They were rewritten with
the supersession recorded in the file, and the cost was put to the owner rather
than absorbed: the runtime still plays such tasks, so nothing already saved
broke — only this dialog can no longer author one. **When a test written for a
decision fails, find the decision before you change the test.**

## 18.9.2026 — The exercise, phase 1: one reader for `solution_san`, and two writers nobody ran

Phase 1 of `docs/PLAN-EXERCISE.md`: `custom_puzzles` gains `name`, `origin`,
`task`, `solution`; `services/exercise.js` is the one place that says what a
row asks; six consumers moved onto it. Backend **1503 → 1522** with the test
database (−3 tests moved out of `customPuzzleJudge.test.js`, +12 `exercise`,
+5 `exercise_schema`, +3 `exercise_one_reader`, +1 route test in
`homework_gate`, +1 in `position_library`), **1441 → 1454** without (the same
minus the five database tests and the one route test). App untouched, not run.

**A fake pool accepts an INSERT the table refuses.** `origin` is NOT NULL with
no default, on purpose, so a writer that forgets it fails loudly. The mutation
„the scan writer forgets `origin`" **survived**: every test of `POST
/scans/confirm` and of the mistake archive fakes the pool, so the suite was
green over a server that would have answered 500 to every scan a trainer
confirmed. Both writers now run once against the real table. **A loud failure
is only loud where something runs it — after adding a constraint, run every
writer of that table on a real database, not only the new code.**

**The gate I wrote in the plan was wrong, and reading the code said so before a
test did.** „`solution_san` is read in `exercise.js` only" cannot hold: the
scan pipeline verifies and re-verifies the printed move and the mistake archive
writes one. The rule that can hold is about *meaning* — who decides what a
student is judged against — so the guard is an allow-list with a reason beside
each file, and a consumer selects through `exerciseColumns()` and never names
the column. **Before writing „only X reads Y", list who writes Y.**

**An unescaped `_` in `LIKE` is a wildcard, and a template literal eats one
backslash.** The backfill reads the id's prefix once (`hw_` → mistakes). `'hw_%'`
matches `hwx…`; `'hw\_%'` in a JS template literal reaches PostgreSQL as
`'hw_%'` again. It needs `\\_` in the source, and the test plants an `hwx…` id
so the difference is a red. The shell layer used to write these files ate the
same backslash three times in one session — **check an escape by its bytes
(`od -c`), not by how a tool prints it.**

**Editing what a running server loads is a migration on the real database.**
The owner's nodemon was up (port 3000), and it runs `initDB` on every `.js`
save — so a half-written `ALTER` would have run against the managed database
mid-edit. The work was done in a git worktree with a junction to
`node_modules`, proven on the throwaway cluster, and applied to the working
tree as one patch; the new process listening after `await initDB()` is the
evidence the migration ran. Rule 20, applied to `db.js`.

**A default can close a door before the feature that opens it exists.**
`assignableProblem(row, { as = 'find' })`: a game exercise is refused as a
find-the-move item unless the caller says it can send a game. No writer of
game exercises exists yet; four paths that build puzzle-kind assignments do.
Rule 14 from the other side — look at what the *next* phase will newly
exercise, and make the wrong use fail today.

## 18.9.2026 — The exercise, phase 2a: a line judged one move at a time

Phase 2a of `docs/PLAN-EXERCISE.md`: `judgeLine` in `customPuzzleJudge.js`, the
attempt route taking `moves`, `services/exerciseAuthoring.js` and
`routes/exercises.js` (POST, GET one, PUT), and the shared fixture
`docs/gates/exercise_line_cases.json`. Backend **1522 → 1565** with the test
database (+26 `exercise_line`, +12 `exercise_authoring`, +4 in
`homework_gate`, +1 in `assignment_review`), **1454 → 1486** without (the same
minus the seven database tests of `exercise_authoring` and the four in
`homework_gate`). 17 mutations, each red on the right test; two survived the
first pass.

**A key added to a response is a new way for the answer to leak.** The review
learned to carry the whole line (`solution`) beside `solutionSan`, guarded by
the same `reveal` — and the mutation that dropped the guard **survived**: every
reveal test looked at `solutionSan`. A student who had not answered would have
been handed the line under the other key. **When a second field carries the
same secret, the test of the first does not cover it; assert on the serialised
body that the secret is absent, not on one key that it is null.**

**Code no test can reach is a mutation that cannot die, so delete it before it
is written down as a rule.** `judgeLine` first had a branch „a different mate
ends the line early". A main move that mates can only be the last step — a
line cannot go on after mate — so the branch could never change an answer. It
went; the doc comment says why the case cannot arise.

**Judge every move in the list, not the last one.** The route takes the
student's moves so far. A judge that replays the author's line and checks only
the newest move is asking the client to be honest about the earlier ones:
`['anything', 'Qxe5+']` would be judged on the last step of a line never
played. The fixture has that case by name.

**The line goes on from the author's move, whatever accepted move was played**
— the rule tutorials already keep, reused rather than re-decided. The replies
were written after the author's move and may be illegal after another;
`continuesOn` tells the app which move to show before the reply.

**Measured rather than argued (§8.3):** with „must be solved" on, one wrong
move in a line keeps the next item locked even after the student finishes the
line on a second try, until the trainer opens it. Nobody chose that for lines;
it follows from „the first verdict is final" and „done means solved". It is
pinned as a test named *measured for the owner*, so changing either rule shows
up as a decision.

**The shell layer eats backslashes and chokes on apostrophes in long
heredocs.** Files with escapes or prose are written with the Write tool; the
shell is for commands.

## 18.9.2026 — „Must be solved" removed: a feature whose escape hatch is its best argument against it

Put to the owner as two options for lines (leave it, or let „solved" mean
„finished the line"), and the owner asked the better question: is the switch
needed at all? It was not. Backend **1565 → 1564** with the test database (−2
tests of the rule, −1 *measured for the owner*, +2: „done is attempted and
nothing else", and the column gone from both tables), **1486, unchanged,** without — every test touched needs the database, which I first got wrong by subtracting them anyway.
The app's count is in the entry below this one, re-derived from a full run.

**When a feature needs an escape hatch, ask what the feature is for before
polishing the hatch.** The gate's job is order — read the tutorial first. „Must
be solved" made it a mastery gate, which can hold a student on one board for
good; the trainer's unlock existed largely to undo that. The trainer loses
nothing they were using: the review shows solved and failed per item.

**A DROP COLUMN tested on a fresh database cannot fail.** A fresh schema never
had the column, so „the column is gone" passed with the DROP deleted. The test
now plants the column the way every older database has it, runs `initDB`, and
then looks. Same shape as the backfill test in phase 1: **a migration is tested
from the state it migrates, not from the state it produces.**

**Removing a parameter from an INSERT shifts every placeholder after it.**
`$10::jsonb` had to become `$9::jsonb` by hand in `homeworkSend.js`; a fake pool
would have accepted the shifted list. The real-database tests are what made
this a two-minute fix rather than a live 500.

**A fixture removed with the feature it was named after may have a second
user.** `_mixedParent` was built for the „must be solved" notice and also fed
„coming back re-reads". The compile error caught it; it came back as
`_openParent`, named for what it is rather than what it was first for.

## 18.9.2026 — The app after „must be solved", and the gate for phase 2b

App **3054 → 3053** (a full run, 1 skipped, 0 failed): the group „must be
solved is scoped to its own row" went with the notice it tested; the editor's
„two switches" test became „the gate switch", with an assertion that nothing of
the old switch travels. Analyze: the same 26 infos.

**Prove a gate's assumptions about code that exists, before handing it over.**
The 2b gate reads a fixture containing `Rd8` for a move whose real spelling is
`Rd8#`. A scratch test said what no reading would have: the Dart `chess`
package's `move('Rd8')` answers **false**, where the server's chess.js plays
it. Two parsers that must agree, disagreeing on decoration. The brief now
opens with that fact and points at `findMove`, which already strips it — so the
worker neither trips on it nor writes a second matcher. **A gate is code that
runs against a library; run the library's half of it.**

**Say it on the wire rather than let the client infer it.** The solver needed
to know whether a wrong move may be played again. It could have been read off
`solutionSan == null` — true today, and a coincidence of two other rules. The
route now sends `retry`.

## 18.9.2026 — The exercise, phase 3a: a game judged by where it ends

Phase 3a of `docs/PLAN-EXERCISE.md`. Backend **1564 → 1592** with the test
database (+22 `engine_game_for_moves`, +6 in `homework_gate`), **1486 → 1508**
without (+22; the six need the database). 15 mutations, each red on the right
test, none surviving — the first pass in this plan where that happened, and the
first where the fixture was written *before* the tests, with a test of the
fixture itself (both answers for every goal, both sides to move).

**The plan said rename; the tree said no.** `surviveMoves` was to become
`forMoves`. The app on master reads and writes `surviveMoves`, and 3b is a
later phase — so a rename on the server alone is a master where a trainer's
„survive 4" task stops being understood. The owner's „no compatibility for old
homeworks" is about *data*; this was about the two halves of the same commit
history. The field keeps its name and is simply allowed on more goals. **A
rename across a wire is one change on both ends or no change.**

**A red test can be an earlier decision** (again, and recorded the same way):
„a number to survive means nothing to a win goal" was §9.2 of the homework
plan, asserted in `engine_game_task.test.js`. It is superseded, the assertion
is gone, and the comment left in its place says where the rule went.

**„No answer" and „a fault" are different, and only one of them may wait.**
`askTablebase` turns `TablebaseUnavailable` — and nothing else — into
`{ judged: false }`. A `TypeError` from the same call throws: recording fails
with nothing written, because a bug swallowed as „the tablebase is down" is a
homework that waits for ever. On a *read* the same fault is logged and the
read goes on, because the asking must not be able to stop the screen it is
asked from. Same error, opposite handling, and each has a mutation.

**Fake the client under the real one.** The tablebase in the tests is
`createTablebase({ fetchImpl })` — the real probe, cache and error mapping over
a fake network that records URLs — so „asked about the position reached, not
the first" is an assertion on the request. A mutation that probed `task.fen`
went red on exactly that line.

**My own fixture was wrong once, and the code was right.** „A mate inside N
moves" used a nine-piece position with `win` + N, which the new rule refuses.
The red said so in one run. A fixture is code; it gets the same suspicion.

## 18.9.2026 — The exercise, phase 2b: graded by machine, and what the worker's own mutation found

The implementer built the app half of the line against
`docs/gates/exercise_make_test.dart`. App **3053 → 3077** (+18 gate, +6 own), 1
skipped, 0 failed, analyze the same 26 infos — the worker's numbers, and the
lead's re-measurement on master after taking the commit, agree. Grading, in
the order that costs least: the gate compared byte for byte with the copy in
`test/`; the file list (nothing outside `chess_app/`); a grep of the diff for
`// ignore`; then 12 mutations over the gate and the worker's own file, each
red on the right test; then the full suite with nothing else running.

**The sentence in the brief that asks for a mutation paid for itself.** „Watch
each new test fail once on wrong code" is where the worker found its own bug: a
line's first wrong move was written into the map that also locks the board, so
a move the server said could be retried froze the screen instead. Two facts —
„this position has a verdict" and „this board is finished" — had one home. The
fix is two maps, and the report says so under *what the brief got wrong*. **Ask
a worker to break its own tests; it is the only review that runs.**

**A brief should say what exists, not only what to build.** It told the worker
to add a `@visibleForTesting` hook „if there is no way to play a move in a
widget test". There was a way — `tap_to_move_test.dart` drives the real board —
and the worker found it. It also had to add an `api` seam to the solver that
the brief's file list did not name. Both are the lead not having grepped the
tests before writing „if". **Before writing „if there is no way", look.**

**Prove the library's half of the gate first** held up: the brief opened with
„Dart `chess` refuses `Rd8` for `Rd8#`", the worker imported `findMove` and
never met the problem.

## 19.9.2026 — The exercise, phases 3b and 4: two workers at once, and a brief that contradicted a test

Two implementers in two worktrees, files divided between them in both briefs;
the two commits landed one on top of the other with no conflict. App **3083 →
3125** (+25 phase 3b, +15 net phase 4 — +14 gate, +11 own, +1, −4 and −7 with
the dialog that went — and +2 from the lead), 1 skipped, 0 failed; analyze the
same 26 infos; backend **1594** with the test database, measured. Both numbers
were written down before the run and matched.

**Read a brief against the tests that exist, not only against its own gate.**
The 3b brief said „keep `engine_game_screen_test` green, unchanged" and asked
for the rule that breaks one of its cases: „survive 2 moves" reaches three
pieces, so since phase 3a a tablebase judges it, and that test's fake server
answered `{"ok":true}` — no verdict. The screen rightly said „not judged yet";
the test expected „Goal met". The worker left the test alone, left the rule
alone, proved the red was not load, and wrote it up. The test was re-aimed by
the lead: the fake answers as `recordEngineGameResult` does. **A fake that
answers less than the real server does is a fixture that was always lucky.**

**What two workers share is written before either starts.** The words for a
task — „Win as White", „Draw or better as Black, for 4 moves" — are needed by
the sheet (3b) and by the Library's rows (4). Briefed separately they would
have been written twice. `exercise_task_words.dart` went in first, with its
tests, and both briefs say „use it; do not word a task anywhere else".

**My premise was wrong, and reading the code said so before a worker did.**
The owner approved „rename the Scans chip, six stay six". There was no Scans
chip: `LibraryChip.positions` held both. It was found while writing the phase 4
gate, amended in the plan, and put to the owner as the one-line choice it is
(seven chips, confirmed). **A decision made on a description of the code is
made on the description; check it against the code before briefing it.**

**`dart format` can create the one lint this project counts.** It splits a
long `if (...) return x;` onto two lines without braces, which is exactly
`curly_braces_in_flow_control_structures`. It happened to the lead's own file.
Format first, analyze after.

**A surviving mutation found an untested promise** — the board turned to the
student's side, in three widgets. Eleven own tests and a gate, and none looked
at `isWhiteBottom`.

**A worker's background process outlives the worker.** One left `find /
-iname flutter_chess_board*` crawling the whole disk for two hours after it had
reported. It was found by its command line and stopped. The brief for the next
worker says: no search from `/`, and stop what you start.

## 19.9.2026 — The exercise, phase 5: the check on save, and a report that said „no process left"

The implementer built the check against `docs/gates/exercise_check_test.dart`:
a pure core (`exercise_check.dart`), a runner that never throws and never
outlasts its timeout (`exercise_checker.dart`), and the sheet showing findings
with *Accept*. App **3125 → 3157** (+24 gate, +7 own, +1 from the lead), 1
skipped, 0 failed; analyze the same 26 infos. Nine mutations by the lead: eight
red on the right test, one survived.

**Green because of what one machine does is not green.** The worker reported,
honestly, that the two older sheet tests now reach the real engine and the real
network through the default checker, and pass because „this workstation fails
fast". That is rule 8 in a new coat: on a machine where the engine waits out
its own ten-second timer, a pending `Timer` fails tests that have nothing to do
with the check. The default askers now say nothing under `flutter test`
(`FLUTTER_TEST` in the environment). No test was written for that guard: on
this machine it could not fail, and **a check that cannot fail is not a check**
— it is recorded as a guard for another machine, and CI is that machine.

**The survivor was a race.** The sheet re-runs the check when the task changes
and drops an answer whose token is stale. The worker's „switching the task"
test uses a checker that answers at once, so an old answer never arrives after
a new question, and deleting the token guard changed nothing. The lead's test
holds the first answer back with a `Completer`, changes the task, then releases
it. **To test a guard against lateness, something has to be late.**

**Prove the library's half of the gate first — again.** A scratch test run
before the hand-over showed `SyzygyResult.fromJson` *sorts* its moves, best for
the mover first. A gate that compared the offered moves in wire order would
have been wrong in a way no reading showed; it compares them unordered, and the
brief says why.

**A report's „no background process left" is a claim like any other.** The
brief forbade searching from `/`; the worker did it anyway („accidental"),
checked for `flutter`, `dart` and `stockfish` before reporting, and declared
itself clean with a whole-disk `find` still crawling. The lead's own process
listing found it. Two of three workers in this plan left one. **Grade the
machine, not the sentence — and list processes by what they are, not by what
you expect them to be.**

**A red full run is read before it is believed, and the number waits for a
clean one.** The first full run after phase 5 took **50 minutes** instead of
four and a half and ended 3150 passed, 7 failed: six in
`opening_book_service_test`, one the live Lichess tablebase test. Both files
passed alone in seconds, neither is touched by the phase, and 3150 + 7 was
exactly the predicted 3157 — so the reds were load and the network, the two
causes rule 19 names. What slowed that run was never found. The docs were not
given a number until a quiet run came back 3157, 0 failed, in under four
minutes.

## 19.9.2026 — Four CI runs frozen for six hours, and the wait that had no ceiling

The owner asked why a run had been going four hours. The backend step is
normally **26 seconds**. `gh` told the rest: of the seven runs since
`a171fb5` (17.9, 20:50 — the commit that brought `test/support/pgTestDb.js`
and the `postgres:17` service container), **four froze inside `npm test`** and
sat there until GitHub's six-hour job limit killed them; of the sixty runs
before it, none ever did. 18.9 04:23, 18.9 18:16, 18.9 18:30, 19.9 02:06.

**Where it stops is readable, and it is not a coincidence.** `node --test`
reports in file order — proved locally, the slow database files appear in
their alphabetical slots, not their completion order — so the log's last line
names the last file that finished. In the two runs whose logs could be read it
was `puzzle_resolution.test.js` and `exercise_authoring.test.js`: two of the
six files that touch a real database, out of a hundred and thirty. The one
run that could be read to the end carried GitHub's annotation for a runner
that stopped answering.

**What could not be proved:** the stall itself. The same suite runs green in
16 seconds against a throwaway cluster, three times over, on sixteen cores; CI
has four and a container. Nothing was reproduced locally, and nothing here
says which call is the one that waits.

**What could be proved is that nothing had a ceiling.** `pg` defaults
`connectionTimeoutMillis` to **0** — measured against a TCP port that accepts
and then says nothing, the old pool was *still waiting after 40 seconds*; the
guarded one gives up at 15 with „Connection terminated due to connection
timeout". `node --test` has no default timeout, so a hook that never returns
freezes the run with no name and no line. And the workflow had no
`timeout-minutes`, so each freeze cost six hours of Actions minutes and left a
log that ends mid-sentence.

Three ceilings, each watched failing before being believed: `--test-timeout`
in the `test` script (a planted test that never answers is now *named* and
failed), the two timeouts in `pgTestDb.js`, and `timeout-minutes` on the job
and on the backend step. Counts unmoved: 1594 with the database, 1510 without.
A fourth guard needs no proof: a `concurrency` group, because the run started
at 18:16 was still frozen when 18:30 pushed and nothing cancelled it.

**The lesson is the old one about loud failures, in the one place nobody had
looked: a wait.** A guard that turns a six-hour silence into a sixty-second
red does not fix the bug — it makes the next occurrence say where it is. Until
one of these ceilings is hit in CI, the cause is still open.

**It took one run.** The very next CI run went red at the backend step in 22
seconds, and it named a line: „Test … at test/homework_gate.test.js:217
generated asynchronous activity after the test ended. This activity created
the error *terminating connection due to administrator command* … but instead
triggered an uncaughtException." That message is what PostgreSQL sends to
every backend when `DROP DATABASE … WITH (FORCE)` runs — this file's own
teardown. And `pg` emits `error` **on the pool** when an idle client loses its
connection, so a pool with no `error` listener is an `EventEmitter` with no
`error` listener: it throws, the exception belongs to no test, and the child
process exits 1 with the file failed as a whole and no assertion to point at.
`pgTestDb.js` had never installed that listener. Proved by mutation, against a
real cluster: with it, the process survives the terminate and prints which
pool lost the client; with it removed, `throw er; // Unhandled 'error' event`
and exit 1.

The counts never moved — 1594 and 1510, green — because nothing the tests
*assert* was ever wrong. The whole fault lived in teardown, which is why five
weeks of green runs hid it and why it only showed on a four-core runner with
PostgreSQL in a container. **An `EventEmitter` you did not give an `error`
listener is a process you agreed to lose**, and the place it will be lost is
the place no assertion is watching.

## 19.9.2026 — The freeze, named: `end()` is a request to close, not a close

The ceiling added that morning paid for itself twice. The first run named a
missing `error` listener; the second named the freeze itself. Backend step
red in 80 seconds, `tests 1597, pass 1594, fail 0, **cancelled 3**`:

    ok 305 - exercises on a real database        (duration_ms: 776)
    not ok 26 - test/exercise_authoring.test.js  (duration_ms: 60002)
      failureType: 'testTimeoutFailure'

Three database files, `exercise_authoring`, `exercise_schema` and
`puzzle_resolution`. **Every test in them passed, the suite closed, and then
the process did not exit.** `node --test` waits for its child, so the run
waited — sixty seconds now, six hours before the ceiling. And `ok 305` is
character for character where the frozen 02:06 run had stopped.

**The first guess was wrong, and measuring it took four minutes.** `pino` is
configured with a `pino-pretty` transport unless `NODE_ENV=production`, a
transport is a worker thread, CI has no `.env` — and the only files that log
are the six that run `initDB`. It fits so well that it was worth a probe: a
test file that writes forty lines through the real logger exits in 143 ms.
Not it. **A hypothesis that explains everything is still a hypothesis.**

**What it is: `pool.end()` resolves before the socket is closed.** `pg` sends
`Terminate` and waits for the *server* to hang up. Measured, immediately after
`await drop()` returned and with the pool reporting `total=0 idle=0
ended=true`:

    holding: ["TCPSocketWrap","PipeWrap","PipeWrap"]
    Socket local:57222 remote:::1:54329 destroyed=false readable=true writable=true

An open `TCPSocketWrap` is a handle, and a handle is a process that will not
exit. On this workstation the server hangs up a moment later and the socket
goes; five weeks of local runs therefore saw nothing. On a four-core runner
with PostgreSQL in a container, not always — and nobody is coming to close it.

`drop()` now destroys what `end()` only asked to close, waiting for each
socket's own `'close'` rather than a guessed number of ticks, bounded at five
seconds so a socket that will not die is an assertion and not another hang.
`test/pg_test_db_teardown.test.js` asserts the helper holds nothing when
`drop()` returns — two cases, the ordinary one and one where the backends were
killed first, both watched red on the mutant that leaves the stragglers alone.
Backend 1594 → **1596** with the database, 1510 without.

**The lesson has three parts.** A method called `end` that resolves is not a
thing that ended. A test suite's *teardown* is code nothing asserts on, so it
is where this class of fault lives — twice in one morning, both in the same
fifteen lines. And the reason four freezes went five weeks without a diagnosis
is that a hang reports nothing: the fix was not cleverness, it was **giving
every wait a ceiling and reading what came out.**

## 19.9.2026 - Three hung files became one, and the one would not reproduce

The socket fix went to CI: `pass 1596, cancelled 1`. The new teardown gate
passed there, `exercise_schema` and `puzzle_resolution` exit now, and
`exercise_authoring.test.js` still passes every test and then sits until the
ceiling. It is the only database file that loads a route, so the route was
probed: requiring it leaves nothing running, its handlers use `pool.query`
only, and the file itself - run the way CI runs it, no `.env`, `CI=true`, a
real PostgreSQL - passes 12 of 12 and exits in a second on the workstation.

**A hang that will not reproduce is diagnosed where it happens or not at
all.** `test/support/whatHoldsMe.js` is preloaded in CI through `NODE_OPTIONS`:
in a child of `node --test` still alive after twenty seconds, an unref'd timer
prints every open handle - sockets with both ends, timers, servers, child
processes. Watched on a planted hang (it names the file and what it holds) and
on a healthy file (silent); limited to children, because the runner lives as
long as the suite and its pipes are not news.

The runner counts a support file with no tests in it as one passing test, so
the counts moved by one without a test being written: **1597** with the
database, **1511** without. That is also why `pgTestDb.js` has always been in
the total.

## 19.9.2026 - The freeze was the logger after all, and the probe that cleared it was a test of one machine

`whatHoldsMe.js` spoke on its first CI run, from two files that had passed
every test twenty seconds earlier:

    [whatHoldsMe] ... test/exercise_authoring.test.js
      resources: ["PipeWrap","PipeWrap","MessagePort"]
    [whatHoldsMe] ... node_modules/thread-stream/lib/worker.js
      resources: ["MessagePort","Timeout"]

`thread-stream` is pino's transport worker. `services/logger.js` asks for
`pino-pretty` unless `NODE_ENV=production`; CI has no `.env`, so every test
process that *logged* started a worker thread, and on Linux with Node 22 that
worker kept the finished process alive. Only the files that run `initDB` log,
which is why it was always the database files, why it arrived with `a171fb5`,
and why `node --test` - which waits for its child - froze until the six-hour
job limit.

**This was the first guess of the morning, and it was thrown away on a bad
measurement.** The probe - a test file writing forty lines through the real
logger - exited in 143 ms, and the entry above this one records the guess as
wrong. The probe ran on Windows with Node 25, where the same worker lets go.
It was rule 8 exactly, committed by the person citing it: *a test that depends
on what one machine does is a test of that machine.* A hypothesis about CI can
be confirmed on the workstation; it cannot be **refuted** there. What settled
it was not a better argument but the process describing itself where it hung.

The socket that outlives `pool.end()` was real too and its fix stays - it took
the hung files from three to two - but it was the smaller half.

The logger now writes plainly when `NODE_TEST_CONTEXT` is set: pretty printing
is for a person at a terminal, and a test run has none.
`test/logger_no_worker.test.js` asserts on the process, not on the options -
after a log line, no `MessagePort` and no `Worker` among the active resources -
and was watched red on the mutant with `["PipeWrap","PipeWrap","MessagePort",
"Immediate"]`, the very handle CI printed. Backend **1598** with the database,
**1512** without.

## 19.9.2026 - A palette that was 848 wide in a 728 box, and a board sized from the wrong dimension

Two faults in one dialog, reported live from two machines, and both of them
invisible to the test written for exactly this widget.

`AnalysisBoardSetupDialog` is the one position editor left - three screens open
it (Analyse, Teach's Preparation, the room), since the second one was deleted on
8.9.2026. Its palette was thirteen chips in a `SingleChildScrollView` laid out
along the horizontal axis. Measured, not guessed: **the row is 848 dp wide on
every screen size, and the dialog gives it 728**. Black's queen, Black's king and
the eraser sat past the right edge. On Windows a mouse wheel scrolls the other
axis and there was no scrollbar, so those three were not merely off-screen -
they were unreachable. On Android landscape the second fault: the short branch
sized the board from `constraints.maxWidth` alone, which on a 932x430 phone is
the **large** dimension. A **724x724 board inside a 398-tall dialog**.

`board_setup_dialog_layout_test.dart` had a case at exactly 932x430 and it was
green, because **nothing inside a scroll view can overflow** and the case asked
only `takeException(), isNull`. Rule 1 again, in its quietest form: the check
could not fail. The same test also proved the confirm button *existed* while it
sat at y=918 on a 640-tall screen.

Three things the fix turns on:

* **A board is sized from both dimensions or it is sized wrong.** `min(width,
  height)`. A first attempt used `height * 0.6`, which fixed landscape and cost
  portrait a quarter of its board - 300 down to 220 - because upright the width
  is already the smaller number. The fraction was protecting against a case the
  `min` already covers.
* **A layout chosen by the screen's shape, not by which phone it is.** Above 620
  dp of content the dialog is a row - board left, everything that acts on it
  right. Landscape stops being a special case and becomes the desktop case at a
  smaller size, and the desktop finally uses its width: the board went 288 ->
  433 at 1280x800.
* **The finishing button is pinned, not scrolled to.** `Column[Expanded(body),
  button]`, so no size can put it below the fold.

Proving the new checks cost three mutations and the first two were wrong reds.
The first put all twelve pieces back in one scrolling row - and failed with
"Found 2 widgets with key palette-P", because the mutation called the row
builder twice. The second sized the board from the width again and the suite
stayed **green**: a `SizedBox` is clamped by what its parent offers, so a board
asked for at 437 inside a 260-tall row does not come out too big, it comes out
**437x260**. A squashed board passes every question about whether it fits. The
check that catches it asks whether the board is **square**; with that, and a
600x400 case that reaches the scrolling branch, the mutation prints "the board
is 514.0 tall inside a 228.0 dialog" - the reported bug, in the test's own
words.

`manual_labels_test` then failed, and it was right to: dropping the emoji from
„Clear board 🗑️" left the manual quoting a button that no longer exists. That
guard is the only thing in the repository that reads the site against `lib/`.

**The tab labels were the same fault one row higher up**, and asked for
separately. „FEN String", „PGN Import", „Piece Placement", „Openings" and
„Chess.com/Lichess" measure **846 dp of text and a 974 dp strip against a 728 dp
bar - 314 past the right edge on every size, a desktop included**. That is why
the first tab read „N String" on a phone. They are now „FEN", „PGN", „Pieces",
„Openings", „Online": 443 of tabs, and the bar fills its width rather than
scrolling wherever they fit, so nothing can scroll out of reach at all.

Two things that only measuring showed. The first mutation for this check
restored **one** long label and stayed green at 1280x800 and 932x430 - once the
dialog stopped being 550 wide on a landscape phone, four short labels and one
long one fit. The claim in the comment („566dp") was invented from the
screenshot and wrong by half; the number in the code now is one that was
measured, and the mutation that proves the check uses a label long enough to
fail everywhere. The second: a filled bar is **not** always better. At 360dp
five tabs get 61 each and every label is cut off mid-word - unreadable, where a
scrolled strip at least shows whole words. So the bar fills only where the
labels fit, and upright with five tabs it still scrolls. That one is a genuine
limit, not a bug: five words do not go into 304dp.

App **3178** tests (3157 + 21), 1 skipped; `flutter analyze` unchanged at 26
known infos.

## 19.9.2026 - The editor was the last door a position that is not chess could come through

`fenIllegalReason` has existed since 30.8.2026, when a hand-made position with
no king reached the engine and took the application down. Five callers ask it:
the engine guard, its stub, the tutorial importer, the room's paste-FEN field -
and the FEN tab of the setup dialog. **The piece editor beside that tab did
not.** So the exact fault the guard was written for could still be built by
hand, one piece at a time, and the guard would meet it one layer later.

The fix is four lines: ask the rule, show what it says, turn the button off.
What makes it the right four lines is that it asks **the** rule. A second
opinion about what chess is would be a second answer the day one of them is
corrected, and this one already knows things a fresh implementation would not:
not just two kings and ten pawns, but that promotions must be paid for in
pawns, that a pawn cannot stand on the first rank, and that the side **not** to
move cannot already be in check.

That last one caught its own test. "A couple of kings and a queen" was written
as white king e1, black king a8, white queen e4 - and the queen sees a8 down
the long diagonal, so Black was in check on White's move. The guard refused it
and the test went red for the right reason. A test that asserts a legal
position is legal is worth writing precisely because it can be wrong that way.

The mutation that proves the file replaces the call with `null`: five of the
six refusals go red and both positive cases stay green, which is the shape to
look for - a guard that refuses everything would fail the two that say yes.

**And the layout finished moving.** The owner's phone reports **667x300** held
sideways, so the 700 threshold read it as an upright phone and gave it the 550
width - 518 for the contents, under the 620 at which the board and its controls
can sit side by side. Both numbers were guesses. 620 was 180 too high: the
controls need 260 and a board needs 140, which is 412 with the gap. With 640
and 440 the phone gets the side-by-side layout, and the board went 142 -> 162
there, 198 -> 288 at 932x430, and 128 -> 222 at 800x360.

The header gave up its second row on short dialogs: title and tabs stacked are
48 + 12 + 46 = 106 of the 284 that phone has, and on one row they are 46. Asked
for in those words - "prostor iznad moze da se smanji sto je moguce vise". The
title stays: a dialog that does not say what it is would be a worse trade than
a smaller board.

The buttons moved under the side to move and the castling rights, and the two
that replace the whole board are now a row of two with the eraser beneath them.
They are not the same kind of thing - "Erase" arms the pointer and stays lit,
the other two happen once and are over - and a row of three equals said they
were. The cost is honest and stated: on a 667x300 phone the control column is
270 of content in 218, so the eraser is a short scroll down.

**The castling rights, a day later and a third measurement.** They shared one
`Wrap` with the „To move" label and its dropdown, and a Wrap fills each line
before starting the next - so „White O-O" ended up beside the dropdown, the
next two shared a line and the fourth sat alone. Asked for: two rows of two
where there is room, one row where there is not, shortened.

The first threshold for „one row fits" was 380 and it was **64 short**, which
the gate caught rather than a screenshot: „W O-O-O" is **70dp** of text at 10pt
and a chip was adding **38** - 18 of it Material's tick - so four of them and
three gaps came to **444**, and a phone held sideways has 393. The chips were
not too wide for the row; the row was cutting the words inside them, which no
overflow exception and no eye on a box-text screenshot would report. The check
that sees it compares each label's **drawn** width against what a `TextPainter`
says it wants: a `Text` in a box narrower than its line is handed the box's
width and paints an ellipsis, so its own size tells you nothing.

The tick is what the row could not afford, and it is not how the palette four
inches above says a thing is on: a brighter fill and a thicker border, which is
lightness and shape rather than a tick, and which the reader of this app needs
because they do not read hue. Same cue in both places, and the four fit in 372.
Putting `showCheckmark` back is the mutation that proves the check, and it
prints „the label „W O-O-O" is cut: it is drawn 55.25 wide and wants 70.0".

One more number was read against the wrong box on the way: the castling row
measured as fitting inside the `TabBarView`, which includes the pinned button
below the scroll. Against the scroll viewport it is 30 below the fold at
667x300. **The box a thing must fit inside is the one that clips it**, not the
nearest ancestor with a convenient name - and the picture is what disagreed
with the number.

App **3190** tests (3178 + 12), 1 skipped; `flutter analyze` unchanged at 26
known infos.

## 19.9.2026 — a task nobody was told, and a rule only the database half knew

The owner's live pass of the exercise work (`PLAN-EXERCISE.md` §9). He set „Win,
for N moves", passed the number on purpose with a queen and king against a king,
and was told „Goal met". **The judging was exactly as decided** — a win *kept*
for N moves, checked by the tablebase — and the decision was what was wrong: he
read the words as a mate to give, the first time he saw them, and he wrote them.
A rule is tested by handing its sentence to somebody who did not write the
code. The amended rule, „checkmate in N moves", is also the simpler one: the
rules judge it alone, so the seven-piece refusal went with it.

Why he could not see it coming is rule 12, three times over. What an exercise
asks was worded in **four** places: `exerciseTaskWords` (right), the server's
`childTitle` („win it", whatever the number), the board's banner („win the
game") and `endingLabel` („the number of moves to survive was reached", under a
win). The one home existed and three screens did not read it. And the homework
opened as „0 of 0 items" because the detail's query never sent the two counters
the lists' query sends, and `?? 0` turned the absence into a number — rule 11
at a `fromJson`.

**The half of the backend suite that needs a database caught what the other
half could not.** Without `TEST_DATABASE_URL` the change was green at 1510. With
the throwaway cluster up, four tests in `homework_gate` went red: they stood on
the fixture's „win kept for two moves" by **index** (`fm.judged[0]`), so a case
that changed meaning kept its place and took them with it. They now find their
case by what it is. CI would have caught it, since there a missing database
fails the run — but only after a push; a change to anything the gate file
reads is worth the two minutes of `initdb` first.

Two wrong reds on the way, both mine, both rule 3. A test title with an
apostrophe inside single quotes failed the whole file at load — `pass 0,
fail 1`, which a mutation run printed twice and which would have read as two
catches had the counts not been looked at. And a `require` placed below the
`const` that used it made all 39 tests of the gate file red at once,
including ones untouched: **when everything fails, nothing was tested** — read
the first error, not the list.

One finder changed meaning silently: `fm.judged.find(moveTarget &&
!needsTablebase)` used to mean „more than seven pieces" and, after the fixture
grew a missed mate at index 0, meant that instead. It now says `goal ===
'hold'` as well. A finder by predicate is only better than an index if the
predicate names everything that makes the case the one you want.

App **3195** tests (3190 + 5: two for the words on the board, one screen test
for the missed mate, two new fixture cases), 1 skipped; `flutter analyze`
unchanged at 26 known infos. Backend **1597** with the database, **1511** without (were 1598 / 1512:
`engine_game_for_moves` 22 → 21 — two cases added, five tablebase rows for a
win removed, a test that the function throws and a test of the row title; 1511
measured with `.env` aside, 1597 is the measured 1596 plus that one pure test).
Eight mutations, each red on the right test.

## 19.9.2026 — stored, never read; and a fixture that wrote what the server forgot

Phase 9 of `PLAN-EXERCISE.md` began with a measurement, and the measurement was
most of the phase: a played game's moves, ending, judge and verdict were **all
in `assignment_items` already**. The review read none of them, because a game
item has no `puzzle_id` and `shapeItem`'s first branch takes „no puzzle id" to
mean „a lesson step" — so the trainer got a step with no step: „board not
available", „viewed", `solved: null`. A dormant branch, woken by the feature
that started writing rows it had never seen (rule 14). Before adding a column,
read what the table holds.

And why no test saw „0 of 0 items": `homework_assignment_own_test.dart` builds
the homework **detail** by hand, and its fixture has `child_total: 3,
child_completed: 3` in it — the two fields the real detail never sent. The
test seeded the state the server was meant to write (rule 6), asserted „3 of 3
items", and passed for as long as the screen was wrong. A hand-built response
is a claim about the server; the claim needs a test on the server's side, which
`homework_gate` now has.

Backend **1603** with the database, **1516** without (1597 / 1511 + 5 pure
tests of the shaping + 1 on the real database; the 5 watched red first, the 1
proved by two mutations — the query without the game columns, and the task not
reaching the shaper).

## 19.9.2026 — the worker's code was right and the gate could not have known

Phase 9's app half, built by the implementer against a gate the lead wrote
first. Graded by machine: gate byte-identical, three files and nothing else, no
new `ignore`, green on master. Then five mutations of **the worker's** code —
and one survived: forcing both review boards to White's side changed no test.
The worker had turned them to the student's side because the brief said so; the
gate never asked. **A brief can say what a gate cannot check, and then only the
brief's reader is holding the rule.** The gate asks it now, from a game played
as Black, and the mutation is red.

Two of my own mutation runs proved nothing and said so only to somebody
reading the counts: a `sed` written for LF against a CRLF file changed nothing
(„All tests passed" under a mutant is a question about the mutant first), and a
Python patch through a Bash heredoc lost the backslash in `'`, so the gate did
not parse and *every* mutant was „red" at load. Check that the mutation
applied — a `grep -c`, an assert on the replace — before reading the colour.

App **3212** tests (3195 + the gate's 17), 1 skipped; `flutter analyze`
unchanged at 26 known infos.

## 19.9.2026 — a fixture that left out a field the server always sends

Phase 10. The owner asked where his scanned diagrams had got the status of an
exercise. Half of them had earned it — a scan whose book printed an answer has
been a find-the-move exercise since phase 1. The other half had it by default:
`isExercise` was `kind == scan`, and `exerciseAskOf` reads a row with no task as
„find", which is right for an exercise and is exactly how every diagram became
one. Two defaults, each reasonable, multiplied.

The server was never wrong. Every row of `GET /library/positions` has carried
`hasSolution` since phase 4, and the app read it into `LibraryEntry` and asked
it of nothing. No test could notice, because **every fixture that built a
scanned row left the field out** — eleven tests across four files went red the
moment the rule read it, none of them about the rule. That is rule 6 in its
quietest form: not a fixture that is wrong, a fixture that is *shorter than the
wire*. A `fromJson` that defaults an absent field makes the short fixture
compile and pass; the new test file spells a row the way `listScanned` does,
field for field, and says so at the top.

One older test asserted the opposite of the new rule — „an entry that cannot be
homework says so instead of vanishing" — and it was right to, for its case.
The rule was narrowed, not deleted: an exercise the trainer can fix (marked for
review) stays visible and greyed; a diagram with nothing to judge was never an
exercise. When a new rule breaks an old test, ask which of the old test's cases
the owner would still want.

And on tooling, twice in one hour: a script that patches a script, to fix an
anchor that matched four times, failed on the same anchor. After the second
failed patch, open the file.

App **3218** tests (3212 + 6), 1 skipped; `flutter analyze` unchanged at 26 known
infos. Four mutations, each asserted to have applied, each red on the right
test.

## 19.9.2026 — phase 11 of the exercise plan: a saved exercise, opened and changed

`docs/PLAN-EXERCISE.md`, phase 11. App only. Measured before anything was
written: the server had the whole of it since phase 2a (`GET` and
`PUT /exercises/:id`, tested on a hand-made row and a scanned one) and the app
had `load` and `update` since 2b. **Nothing called them** — a client method with
no caller for three phases, found only because the owner tapped a row. Rule 10
again: every layer right, the feature unreachable.

The implementer built it against the lead's gate and the gate passed unchanged.
**Every fault found afterwards was in the gate, and all three are rule 6 — a
fixture luckier than the real thing:**

- The gate's game exercise had Black to move *and* Black as the student, so a
  board turned by `sideToMove` passed. A fixture in which two different
  questions have the same answer cannot tell which one the code asked. Found by
  reading the code, not by a test.
- „The main move cannot be removed" stood on the scholar line, where removing
  `Qh5` leaves `Qf3 g6 Qxe5+`, which does not replay — so **the reader refused
  it and the guard was never what made the test green**. Deleting the guard
  survived. On the back rank both moves mate and nothing follows; only the
  guard can say no. When one rule hides behind another, the test needs a case
  the other rule allows.
- The gate played its moves through the board's `onMove`, which the screen reads
  against `fenBefore(step)` — so nothing looked at the board the trainer sees
  after choosing a step. A seam that bypasses the screen tests the model twice.

And on tooling: a mutation runner that wrote the mutant, then crashed decoding
the test output (cp1250 on this workstation), **left the mutant in the file**.
The restore belongs in a `finally`, the output is read as bytes, and after any
runner dies the first command is a grep for the mutant.

App **3257** tests (3218 + 24 gate + 11 the worker's + 4 the lead's), 1 skipped;
`flutter analyze` unchanged at 26 known infos. Seventeen mutations, each
asserted to have applied, each red on the right test — two only after the
lead's tests were added. Backend untouched.

## 19.9.2026 — phase 12 of the exercise plan: no engine, no Analysis, no FEN inside an assigned item

`docs/PLAN-EXERCISE.md`, phase 12. App only, built inline by the lead: one
parameter on the board and conditionals on four screens cost less than a brief.

**A switch that turns something off has to keep its seat.** Ctrl+C asks
`BoardOnScreen` for whoever is on top. The obvious way to close a board is not
to register it — and then the shortcut is answered by the board of the screen
*underneath*, silently, with the wrong position. A closed board registers and
says no; „play it out", whose own board never copied, registers a no-op for the
same reason. Absence is a third answer here too: *not present* and *present and
refusing* are different, and only the second one is a guard.

The test was green the first time it ran, which proves nothing (rule 1). Fifteen
mutations, one per door — three Analysis buttons, two engine panels, two menus,
four boards, both directions of the tactics condition — each red on the right
test, and the controls (the same screens outside an assignment) red when the
guard was made unconditional. Two doors shared identical text and needed the
n-th occurrence mutated rather than a unique string.

**A third worker reported itself clean with a process running**: the phase 11
implementer's monitor loop polled a log file it had already deleted, so it could
never end, and `tasklist | grep dart` — its own check — cannot see a `bash`
loop. The owner saw it in the app's task list 28 minutes later. When grading,
list processes by *command line*, not by image name.

App **3268** tests (3257 + 11), 1 skipped; `flutter analyze` unchanged at 26 known
infos. Backend untouched.

## 19.9.2026 — phase 12, amended: the purpose decides when a closed door opens

The first version of phase 12 closed the engine, Analysis and the FEN for as
long as an assigned item was open, and left „what about after?" as a note. The
owner answered it with the rule the code should have started from: *they are
off so the student uses no help; the moment he stops solving, they may open.*
**A restriction carries its own end condition — ask what it is for, and the
answer says when it stops.** Written as „off inside a homework item" it would
have kept a student from analysing his own finished game, which is the most
useful thing he could do with it.

„Handed in" is a different moment on each of the four screens — a finished
game, a verdict, a complete puzzle — and on the tutorial it is not the current
step. A step that only shows a position very often stands on the position the
next step asks about, so „this step asks nothing" would hand out the question's
FEN one step early. The rule reads every question **from this step on**
(`lessonBoardGivesFen`), and two wrong tries are still solving.

The pure function's test could not see whether the screen ever *records* a
settled question: removing the line survived at two of its three sites until
the multiple-choice answer and „Show me" were each played through the screen.
A rule tested as a function is tested once; every place that feeds it is a
separate claim.

App **3275** tests (3268 + 7), 1 skipped; `flutter analyze` unchanged at 26 known
infos. Thirteen mutations, both directions, each red on the right test.

## 20.9.2026 — a hand-made exercise that opened on „Assignment complete", and whose move it is

The owner's live pass. A find-the-move exercise made by hand, sent directly and
inside a homework, opened — for the student *and* for the trainer — on
„Assignment complete. Your trainer can see the result." Nobody had played a move.

**A prefix is not a column — the plan said so in §3, about this very table, and
one reader kept reading the prefix anyway.** `getAssignmentDetail` told a
trainer's position from a Lichess puzzle by `id.startsWith('cust_')`, written
when a scanned book was the only writer of `custom_puzzles`. Phase 2a gave the
table a second writer (`ex_…`); the mistakes archive had been a third (`hw_…`)
for longer. Both travelled without their board. Rule 14 exactly: *a dormant bug
wakes when the feature it depends on ships — usually not the feature that
contains it.* **No test anywhere read `customPositions`**, so four phases of
gates, each proved by mutation, stood on a field nobody looked at; the phase 2b
and 4 tests pumped the solver directly with positions handed to it, and never
came in through the door a student uses. Now the table is asked and the id is
not read.

The other half is the recurring bug of this codebase, a sixth time. The tactics
screen, handed an id it could not load, **skipped it in silence, reached the end
of the list and announced success**. Skipping one bad row so the rest can be
solved is right; the silence is not. The end screen already had this lesson once
(„skipped puzzles are not a finished homework") and learned it for one cause
only. *When a screen can end by running out of things, ask of every way a thing
can leave the list whether the ending still tells the truth.*

On the suggestion — whose move it is in „play it out": a surviving mutation
showed two sources for one fact (`_isOpponentTurn` and the board). The board is
the one that is right from the first frame and flips the instant a move is
made, so the flag went. And in the one-line landscape header the turn stands
*before* the goal: an ellipsis eats the end of a row, and the end must not be
the new information.

Tooling: `Color` in `ai_studio_screen.dart` is ambiguous with the chess
package's — pass a flag and resolve the colour inside. A long Bash command with
heredocs containing apostrophes fails to parse as a whole and writes nothing;
files with prose go through the Write tool.

App **3283** tests (3275 + 5 + 3), 1 skipped; `flutter analyze` unchanged at 26
known infos. Backend **1607** with the throwaway database, **1520** without
(1603 / 1516 + 4). The fixed function was also run, read-only, against the real
assignment: the board arrives, the solution does not.

## 20.9.2026 — two „is this how it should be?" from the owner, both answered yes, one pinned

An exercise solved through a direct assignment showed as done inside a homework
the student never opened. It is the rule — `recordPuzzleResult` writes by student
and position, not by the assignment the answer came through — and **it was
pinned by no test**: the function's tests covered the stored move and the first
verdict, never a second assignment. Behaviour an owner has to ask about is
behaviour a refactor could remove without a red. Now one test on the real
database holds all of it: every open copy, the same first verdict, a locked copy
left alone, another student's never touched, the homework stamped complete.

The mutations ran in a scratch worktree with a junction to `node_modules`, not
in the main checkout: the owner's nodemon serves that file, and a mutant of the
SQL that records a student's answer must not be live on port 3000 even for the
seconds a test takes. **Before mutating, ask who else is running the file.**

Backend **1608** with the throwaway database (1607 + 1), **1520** without — the
new test lives in the half that needs a database. App untouched.

## 20.9.2026 — any mate is a right answer

The owner's Qa8# was accepted although he had listed only Qf7# and Qa7, and he
asked whether that was meant. It was: since 8.9.2026 a different mate counts
where the author's own move mates. The question it raised was the other half —
**the rule read the author's move to decide what a checkmate is worth.** With
the quiet move written first and the mate as its alternative, a third move,
mate on the spot, would have been „wrong". Same exercise, same position, a
different order of two clicks in the editor. A rule about the board should read
the board: any mate is right; short of mate, only what the author wrote.

In a line this needed one more thing the single move never did. A mate at step
one of three is correct *and ends the line*: no reply, nothing to continue on —
the replies were written for a game that is no longer being played. Without it
the solver would have shown the author's move and the opponent's answer on a
board where the king was already mated.

The surviving mutation was `isCheckmate` → `isCheck`: every wrong move in the
tests was a quiet one, so „any check counts" passed. A rule with a boundary
needs a case standing on it — here Qa3+, a check that lets the king out.

Backend **1612** with the throwaway database, **1524** without (1608 / 1520 + 4).
App untouched; the four test files that stand on the shared fixture re-run green.

## 20.9.2026 — a played homework game opens in Analysis with its moves (PLAN-EXERCISE, phase 13)

**The plan's own measurement was wrong, and the fix was to keep looking.** §10
said „Analysis takes a bare FEN and nothing else from outside", read off
`AppRoutes.analysisPath(fen:)`. True of the *route*; the *screen* has had
`initialGame` since D4 of the skeleton plan — the mistake archive's door for a
whole game. The phase as written („one door into Analysis … through the PGN
loader") would have built a second one. Grep the widget's constructor, not only
the route that usually leads to it. What was actually missing was a converter:
the archive keeps a game in UCI, a homework keeps it in SAN.

`analysisTreeFromMoves` ends a line at the move it cannot play and says how far
it got — right for an archive. For a game a trainer is about to judge, a shorter
game shown as the whole one is the 6.9.2026 shape again, so
`analysisGameFromSans` answers null and the opener says so in words. The opener
moved to one home (`open_game_in_analysis.dart`) with its test override; the
archive, the review card and the finished game all go through it.

The surviving mutation: removing the check that the position is a position.
The test sent a broken FEN *with a move*, and the move failed on the broken
board — refused, for the wrong reason. The check only decides anything for a
game with **no** moves, so that is where the test now stands. Seven mutations
in all, each red on the right test.

App **3283 → 3295** (5 in `game_from_moves_test.dart`, 7 in
`homework_game_in_analysis_test.dart`), 1 skipped, a full run alone on the
machine, 12 minutes. Analyze: the same 26 infos. Backend untouched. Live: item
195.

## 20.9.2026 — Find is one move, played on the exercise's own screen (PLAN-EXERCISE, phase 14)

The owner's parked question — „Make exercise wants the solution played first
and nobody knows" — was first answered with a bigger editor, then with a
solution tree, and ended as a **smaller feature**: once a find exercise is one
move, there is nothing to play in advance, and the screen phase 11 built for
alternatives is already the place to play it. Ask what the feature is for
before building the door to it; the cheapest fix for „nobody knows where to
start" was to remove the thing that had to be started.

**A cap belongs to the writer, not the reader.** The plan said „`ExerciseLine`'s
limit follows". It cannot: the reader also reads the lines that exist, and a
reader that refuses stored rows turns a rule about new work into a fault in old
data. Server: `parseExercise` asks the length *after* `readSolution` — mutation
„length asked first" goes red on the fixture's refusals, because a two-move
line that does not replay must be told that, not that it is long. App: no cap
at all; `fromTree` and the making screen cannot produce a second step.

**An assertion of absence dies with the thing it names** (rule 5, again).
`exercise_game_own_test` asserted that „Play the solution on the board first"
is *not* shown under a game task. The sentence left `lib/` in this phase, so
the assertion could no longer fail under any code. Grepping the old words in
the tests after removing them from the app found it; it now looks for the
button that replaced the sentence.

Tooling, paid for twice today: `pg_ctl start` inside a piped Bash command
never returns — the server inherits the pipe — and stopping that shell stops
the database with it. Start it detached and check with `pg_isready`. And a
Python heredoc on this console mangles non-ASCII (`„`, `→`): write the script
to a file and run `python -X utf8`.

Backend **1612 → 1614** with the throwaway database, **1524 → 1526** without
(two pure tests), `.env` moved aside. App **3295 → 3307**: 17 new, 5 moved out
of the 2b gate. 1 skipped, a full run alone, 4 minutes. Analyze: the same 26
infos. Live: item 196.

## 20.9.2026 — „Play N moves", and the verdict a trainer could never give (PLAN-EXERCISE, phase 15)

**„The trainer judges" had been a sentence since phase 6 was closed, with no
route under it.** `judged_by` was written as `rules`, `tablebase` or nothing;
the review told the trainer the position was his to judge and gave him nowhere
to say so. Measuring before planning found it — the plan for a new task type
turned out to owe an old one its button. A decision that names a person as the
fallback is not built until that person can act.

**One meaning spelled twice is two meanings.** „Played and not judged" was
`judged_by IS NULL AND game_ending = 'moveTarget'` in `childrenOf`, and the
same in the review's `pending` — true while the only thing that could leave a
game unjudged was a tablebase at a move target. A game with no goal waits
however it ends; one that ended in mate would have been neither judged nor
waiting, a card with nothing on it. The database tests found the first copy
because they played a mate; the second was found by reading, because those
tests never looked at the review. Rule 12, and rule 14: the dormant half woke
with a feature that does not contain it.

**A gate from another phase was right against my own design.** The verdict
buttons first read „Goal met" / „Goal not met" — one vocabulary with the
verdict they give. Phase 9's gate went red: an unjudged card must not carry
those words anywhere. It was protecting exactly this reader — two labels that
read as a status on a card that has none. They are „Mark as met" / „Mark as
not met" now. When an old test fails on new work, ask what it was written to
protect before re-aiming it.

**The surviving mutation was a dead condition**, not a missing test: the
buttons asked `item.attempted` as well as `pending || judgedBy == 'trainer'`,
and the server's `pending` already means played. Removed. And a hard-coded
„four sentences" in `exercise_task_words_test` became a count of the enum: a
typed number is one judge behind the day one is added.

`dart format` split `if (n == null) return …;` across two lines and so made a
27th `curly_braces` info — compare the list per file before and after, not the
total, to find which file grew one.

Backend **1614 → 1632** with the throwaway database, **1526 → 1539** without
(12 + 5 + 1, the 5 need the database), `.env` moved aside. App **3307 → 3334**
(27). 1 skipped, a full run alone, 4 minutes. Analyze: the same 26 infos. Live:
item 197, after a restart — `initDB` widens the `judged_by` constraint.

## 20.9.2026 — the multi-move machinery deleted (PLAN-EXERCISE, phase 16)

**The precondition looked unmet because I read the wrong book.** Phase 16 waits
for 195–197 „watched running", and `TODO-provera.md` said „nije viđeno uživo"
on all three. The owner had answered them that morning — in the QA log outside
the repository, which is where live answers have gone since 3.9. The document
is what the QA page is *built from*; it is not where the answers land. Ask the
log before asking the owner.

**A heading is an id.** Marking those three as seen, I rewrote their `##`
lines. The QA tool files answers under *(section heading, item number, lead
phrase)* — a reworded heading would have orphaned 23 answers at the next
regeneration. The headings went back byte for byte; the ticks and a sentence
under each heading say who saw it. Before editing a line in a document a tool
reads, find out what the tool keys on.

**A rule that protected a reader dies with the reader.** Phase 14 put the
one-move cap in the writer, *after* the read, so a line that did not replay was
told so rather than told it was long. With the replies gone nothing can replay
a line at all, so the cap moved into `readSolution` and length is refused
first. One home instead of two — and the reader's refusal is what stands
between a leftover row and being judged on its first move, which is why that
case has its own test on both ends and in the real-database gate.

**The half of the suite that skips locally hid one red.** `homework_gate`
asserted `retry: false`, a field this phase removed; without the throwaway
cluster the file is one `﹣` line and the run is green. Run the database half
before believing a server change — CI would have been the first to say.

**Two surviving mutants, both questions about my own tests.** „The editor's
board goes back to the position" was asserted after calling `onMove` on the
widget — the controller never had the move, so it had nothing to go back from
(rule 6: never seed the state the code was meant to write; here, never skip
it). The test plays the move on the controller first now, as the real board
does. And the solver refuses a second answer twice — `isAllowedToMove` and a
guard in `_onMove` — so removing either alone changes nothing; both off, the
test goes red. Defence in depth reads as a dead condition to a single mutation.

**My own slip, caught by the analyzer:** a scripted edit cut from one anchor to
the *next occurrence* of a second one, which belonged to an earlier class, and
took three classes with it. `replace` was guarded by a count; `index` slices
were not. Every anchor of a scripted edit is asserted unique, not only the
replaced ones.

Backend **1632 → 1624** with the throwaway database (the line judge's file
29 → 19, `exercise.test.js` +1, the database half 3 → 4), **1539 → 1530**
without, `.env` moved aside. App **3334 → 3327** (−5 the solver's line play,
−1 the step's board, −1 the editor's step, −1 the checker's walk, +1 the
solver on the real screen). 1 skipped, a full run alone, 6 minutes. Analyze:
the same 26 infos. Live: item 198 — both ends must be new, the wire changed.

## 20.9.2026 — an engine that printed its banner and never another line

The owner's report from the phone: no evaluation on Preparation, with the log.
**The log's shape was the finding**: after `Stockfish 18 by…` the engine wrote
nothing at all — no `uciok`, no `readyok`, no `info`, no `bestmove` — from the
first command, on every screen, while every wait timed out politely and
„proceeded anyway". Windows was fine; the owner added that he had just played a
homework game against the engine.

Ruled out first, because it has this codebase's favourite shape: the package's
Android build fetches the two network files with a bare CMake `file(DOWNLOAD)`
— no hash, no status — so a failed download is an empty file and a green
build. The files on this workstation are whole (109 MB and 3.5 MB). Still a
trap for a build on a bad network; nothing here guards it.

**What the code says, not reproduced on a device:** `StockfishService.shutdown`
had one caller, the engine settings dialog. On Android, Back destroys the
activity and the Flutter engine but usually not the process; the native engine
is a thread of that process blocked reading stdin, and nobody told it to quit.
The package's bridge makes new pipes per instance and `dup2`s them onto the
process's one stdin/stdout, so the next run's engine prints its banner and then
waits behind a reader that never finishes. `EngineWatch` sends the quit on
`AppLifecycleState.detached` — a synchronous write into the pipe, so it lands
even if the isolate sees nothing after it. **Do the thing, then say it.**

The way to know the cause rather than believe it, on the old build: use the
engine, leave with Back from Home, open again → silent; Force stop → it
answers. Item 199.

Still open, and a decision: an engine that answers nothing is *silence*, not
an error — every timeout „proceeds anyway". A loud version would notice that
`uci` never earned its `uciok` and say so on the screen.

App **3327 → 3329** (the watch's two tests; two mutations, each red on its own
test). Analyze: the same 26 infos.

**The fix woke a dormant bug within the hour (rule 14).** The owner installed
it and sent a second log: banner, then every write refused — `Stockfish is not
ready (StockfishState.disposed)`. Not hung this time: *exited*, code 0, before
reading `uci`. `shutdown()` sent `quit` and then called the package's
`dispose()`, which is `quit` again. The engine takes both in one read; the
first ends it, the second stays in the process's one `std::cin` buffer — and
the next engine in that process reads it as its first command. Harmless while
`shutdown()` had no caller at exit; `EngineWatch` gave it one. `quit` now goes
exactly once, last. And `initEngine` asks the package's state: an engine that
is `disposed` or `error` is dropped and started again, instead of being written
to forever. **Neither is covered by a test** — the native service has no seam
under the FFI package; the phone is the only gate (item 199). **The owner ran it the same
morning**: engine on, Back from Home, reopen — `uciok` within a second, a search
to depth 43, no timeout. The general
shape: a process-global outlives everything that thinks it owns it.

## 20.9.2026 — an engine that answers nothing says so on the screen

The decision left open that morning, taken the same day by the owner. Every
wait on the engine timed out, logged a line and „proceeded anyway"; the user
saw a board with no evaluation and no reason.

`EngineSilence` is the reason, as one sentence or null — no engine in it and no
widgets, so `fake_async` drives it. The service feeds it in four places: `uci`
starts a five-second wait for an answer; any line from the engine clears it; an
`isready` that earns no `readyok` sets it (an engine that is reading answers
`isready` at once, even mid-search — three seconds of nothing is not a slow
engine); a refused write says the *other* sentence, because „has stopped" has a
different remedy from „is not answering". `EngineNotice` sits above the router
beside `EngineWatch` and says it through `AppFeedback`, once per fault: the
notifier changes only when the answer changes.

**The banner is not an answer.** The first failing log was exactly: banner,
then nothing. A detector that took „any line" as life would have been reassured
by the one line a stuck engine does print. The test plays that log.

**A test named for a behaviour it could not see.** „An engine coming back says
nothing" called `heard()` on a notifier that was already null — no change, no
notification, nothing for the notice to get wrong. The mutant that made the
notice speak on recovery was caught by its neighbour instead. Rule 6: stand on
the boundary — from a fault, then back. And the first form of that mutant was a
compile error (`String?` into `String`), rule 3's wrong red; it was rewritten
to keep the promotion.

**A detector must not accuse the engine of the service's own bookkeeping.**
`_stopAndDrain` can run twice at once — fast stepping through moves — and the
second call takes over the first one's `readyok` waiter, so the first times out
on an engine that answered. A timeout therefore counts only if the engine said
*nothing at all* since the `isready` went out (`mark` / `unansweredSince`).
Found by reading the owner's first log for what else prints „isready timeout",
before the phone could find it as a red bar over a working engine. The
overwritten waiter itself is still there; it costs three seconds of delay, not
a wrong answer, and is a separate fix.

Not covered by machine: the four call sites in the native service, as before.
App **3329 → 3338** (nine tests in `engine_silence_test.dart`; nine mutations,
each red on its own test once two were re-aimed). 1 skipped, a full run alone,
12 minutes. Analyze: the same 26 infos, no `ignore` added. Live: item 200.


## Preparation čuva liniju — i panel koji je prerastao svoj prozor (20.9.2026)

Vlasnik je tražio izvoz u PGN iz Preparation-a, pa dodao: „napravi i mogućnost
čuvanja — izvinjavam se, mislio sam na čuvanje a napisao export". Dva dugmeta,
i ispalo je da je treća stvar bila skuplja od obe.

**Čuvanje nije postojalo, a izgledalo je kao da postoji.** Soba je umela da
sačuva *poziciju* („Save position"), da napravi korak tutorijala i da napravi
zadatak — sve troje je nešto što se **daje učeniku**. Trener koji sprema sam
nije imao ništa što prosto zadrži rad: izlazak iz sobe je bacao stablo, a
„Export to Analysis 🔬" nosi samo FEN pozicije na kojoj stojiš. Otkriveno
čitanjem, ne testom.

**Prelaz je već postojao, i ne sme da bude drugi.** Soba piše `MoveTree`, sve
što čuva stablo drži `AnalysisNode`. `readPreparedLine` ide kroz jedan put koji
svi ostali uvozi već koriste — `MoveTree.exportToPgn` piše, `readStepTree` →
`LessonStepLine` → `MoveTree.parsePgn` čita, `_convert` prelazi. Nijedan potez
se ne parsira ovde. Okretanje kroz PGN umesto direktnog kopiranja čvorova je
namerno: to je pravilo od 6.9.2026 — **pisac pročita svoj rad kroz čitaočev
parser pre nego što ga sačuva** — i `rejectedMoves` je broj koji iz toga ispada.
Čuvanje odbija kad je iznad nule; izvoz ne odbija, nego preda sirov tekst sobe
uz rečenicu koliko poteza nije pročitano, jer ponovo ispisano skraćeno stablo je
tiha verzija istog gubitka, a trener koji ne može da sačuva mora bar da prepiše.

**Grana koju nijedan pošten fixture ne može da dosegne.** Odbijanje se pali samo
kad se piščev i čitaočev sud razilaze, a stablo građeno legalnim potezima se
uvek slaže sa sobom. Zato je odluka izvučena u `preparedLineRefusal(PreparedLine)`
nad zapisom (record), koji test može da napravi ručno — i zato postoji
`_unreadableTree()`, stablo sa ručno zakucanim `e5` kao prvim belim potezom,
pošto `appendLine` odbija nelegalan potez. Pravilo 6: stani na granicu.

**A onda ono što je stvarno koštalo.** Dva nova dugmeta preko cele širine su
prošla svih 14 novih testova, a oborila `part_titles_shown_test` — test o
imenima delova tutorijala, koji sa mojom izmenom nema nikakve veze. Panel „Board"
skroluje, a red liste tutorijala ispod njega je već stajao **13 px iznad donje
ivice** prozora 1200 x 800; dva reda su ga odnela na y = 875 i `tap()` je
promašio. Flutter to ne prijavljuje kao grešku nego kao *warning* ispod koga
test pada tri reda dalje, na tvrdnji koja s tim nema veze.

Popravka nije „pomeri test": dugmad su uparena u dva reda — **Import PGN | Export
PGN** i **Save position | Save analysis** — pa panel dobija čitanje (uvoz ↔ izvoz,
ova tabla ↔ cela linija) i **ne dobija nijedan piksel visine**. Šest redova je
opet četiri.

**Prva verzija čuvara tog pravila nije bila čuvar.** Tvrdio je da naslov
„Library" ostaje iznad ivice — a naslov je *iznad* liste, pa je mutacija koja
vraća slaganje dugmadi prošla zeleno. Čuvar sada gleda **red same liste**
(fixture kome je polica prazna ne može da vidi da je panel prerastao prozor —
pravilo 6 opet) i još ga i tapne, jer promašen tap ispisuje upozorenje a ne
grešku. Tek tada mutacija pada, i to sa rečenicom koja imenuje šta je ispalo.

Mereno: aplikacija **3338 → 3353** (petnaest testova u
`room_prepared_line_test.dart`), 1 preskočen, pun prolaz sam. Analyze: istih 26
`info`, nijedan nov, nijedan `ignore` dodat. Sedam mutacija, svaka crvena na
svom testu: odbijanje izgubljenog poteza, prepoznavanje prazne table, gutanje
`rejectedMoves`, izvoz bez standardnog pisca, sačuvano stablo bez poteza,
čuvanje koje šalje golu poziciju, i slaganje dugmadi umesto uparivanja.
`AnalysisPersistenceService` je dobio ubrizgljiv `http.Client` (pravilo 7:
lažiraj klijenta, ne metod) — dotad ga nijedan test nije mogao videti.

Van mašine: da li sačuvana analiza zaista otvara celu liniju u Analyse i u
Library, i kako ta dva reda izgledaju na telefonu. Uživo: **stavka 201**.

## Spajanje tutorijala, i tri pune površine (20.9.2026)

Vlasnikova stavka 2: spojiti tutorijale u novi, i izdvojiti delove u novi.
Ispalo je da je sama radnja mala, a da je **mesto za dugme** koštalo ceo dan.

**Radnja je već postojala, rasuta.** `TutorialSection.copy()` pravi deo bez
`stepId` — dva dela sa istim korakom su napredak deteta u pogrešnoj polovini
tutorijala, pa model odbija da ga nosi. `TutorialDraftController` već ima
dodaj/pomeri/kloniraj/obriši sa undo-om. `CoursePickerDialog` već bira tutorijal,
`GET /lessons/:id` već vraća njegove delove, a `commitDraft` prima **bilo koji**
nacrt. Nije trebala nijedna izmena na serveru. Dve operacije — „dodaj delove iz
tutorijala" i „izdvoji delove u novi" — i spajanje A + B u treći je nov tutorijal
pa prva operacija dvaput, a ne treća funkcija.

**Kopira, ne premešta** (vlasnikova odluka istog dana). Premeštanje je dva upisa
i drugi može da padne posle prvog; kopiranje je jedan upis koji ne može da
poluuspe, a ko hoće da ih nema u izvoru briše ih dugmetom koje već postoji.
Izdvojen tutorijal se **odmah čuva** i nudi „Open" umesto da se otvori
nesačuvan — studio drži jedan nacrt, pa bi otvaranje moralo da pita šta sa
nesačuvanim izmenama u onom koji se piše, a odgovor na to pitanje vredi manje
nego da se pitanje nikad ne postavi.

**Test je našao pogrešan predikat.** Prva verzija je pitala `isEmptyDraft` da bi
zamenila prazan prvi deo umesto da doda iza njega — a `isEmptyDraft` traži i
**prazan naslov**, jer odgovara na drugo pitanje („vredi li ponuditi ovaj
sačuvan nacrt"). Trener koji prvo upiše ime tutorijala je tačno onaj kome bi
ostao prazan „Part 1" ispred svega. Sada `holdsOnlyABlankPart`, koje pita samo
za sadržaj — i za ime *dela*, jer deo koji je trener imenovao je deo koji je
mislio, i sa praznom tablom.

**A onda mesto.** Dugme je prvo otišlo u Wrap panela „Tutorial contents", gde su
sve ostale radnje nad delom. Panel ima **dva piksela** mesta na 840 dp
(`tutorial_raspored_test`) i jedna stavka više u tom Wrap-u košta ceo red — 2 px
preko. Red sa naslovom iznad njega: 19 px preko. Gornja traka studija: imala je
15 px, a ikona košta 48 — 33 px preko. Traku sam pokušao da platim time što
„Preview tutorial" postaje ikona već ispod 960 umesto ispod 840 — i to je oborilo
`tutorial_editor_door_test`, koji drži vlasnikovo pravilo od 11.9.2026 da se na
840 piše rečima. **Tuđe merilo se ne prepravlja da bi stala moja izmena.** Traka
je vraćena u bajt isti oblik, a vrata su otišla u red sa naslovom kao dugme
20 × 20, koje taj red ne može da poraste. Mala meta je cena toga da se ništa što
trener već hvata u jedan klik ne pomeri dublje; na telefonu su ista dva ulaza u
meniju „More", pune veličine.

**I vrata koja na telefonu ne bi postojala.** Test na 360 dp je prvo merio
*desktop* traku stisnutu u 360 (215 px preko i pre moje izmene) — ekran koji
aplikacija nikad ne crta, jer se telefonski raspored bira po širini **i** po
platformi. Sa `debugDefaultTargetPlatformOverride` se vidi pravi raspored — i u
njemu novih vrata nije bilo uopšte. Funkcija koja postoji na jednom rasporedu a
ne na drugom je funkcija koju trener nađe jednom pa je više ne nađe.

Mereno: aplikacija **3353 → 3383** (30 testova u `tutorial_parts_transfer_test`
i `tutorial_parts_doors_test`), 1 preskočen, pun prolaz sam. Analyze: istih 26
`info`. Jedanaest mutacija, svaka crvena na svom testu; jedna je prvo bila
greška prevođenja (`final` polje) i prepisana je, pravilo 3 — crveno koje nije
pravo crveno ne važi.

Van mašine: da li je 20 × 20 dovoljno za rad mišem, i da li „Open" iz poruke
zaista vraća netaknut nacrt ispod sebe. Uživo: **stavka 202**.

---

## Pretraga u „Choose a game", i rupa u kapiji koju je našla mutacija — 20.9.2026

Faza 1 iz `docs/PLAN-LISTE.md`. `game_selector_dialog.dart` je imao 4126
partija u kutiji `SizedBox(width: 400, height: 300)`, bez pretrage: oko pet
vidljivih vrsta. Dodata je pretraga po dva imena igrača i po potezima, brojač
u naslovu („12 of 4126"), rečenica kad ništa ne odgovara, veličina iz
`MediaQuery`, i podnaslov koji više ne seče usred poteza.

**Prvo, šta je kapija našla pre nego što je iko išta gradio.** Napisana je
tvrdnja o *širini*: na prozoru od 1400 px lista mora biti šira od 640. Pala je
— u smislu da je **prošla na master-u**, gde je greška još stajala. `SizedBox`
traži 400 i **dobija 912**: `AlertDialog` ređa naslov, sadržaj i akcije pod
`IntrinsicWidth`, koji uzme najširi intrinsic — ovde naslovni tekst — i
nametne ga svakoj deci. Znači širina danas nije zakovana nego *slučajna*, prati
tekst naslova i font. Zakovana je **visina**, 300, i to je broj koji znači „pet
vrsta od 4126". Tvrdnja je preusmerena na visinu. Pravilo 1: **provera koja ne
može da padne nije provera** — a ova je izgledala kao da radi.

**Drugo, mutacija je našla rupu u kapiji posle implementacije.** Slučaj
„zatvori dijalog pa javi pozivaocu" tvrdio je da se **oboje** dogodilo i nije
mogao da vidi **redosled**: zamena `Navigator.pop` i `onGameSelected` ostavila
je svih devet slučajeva zelenim, i testove oba pozivaoca takođe. Redosled je
izbor originalnog koda i brief ga je tražio — ali ga ništa nije držalo. Pop se
vidi **samo u trenutku kad se desi**, pa novi slučaj gleda navigator
(`NavigatorObserver`), ne stablo: `expect(events, ['pop', 'told'])`. Crven pod
zamenom, zelen inače. Rupa je bila u **vodećoj kapiji**, ne u radu radnika.

Šest mutacija, svaka crvena na svom testu: cela mapa zaglavlja umesto dva
imena (zamka „Zagreb Open"), izbačeni potezi, zamenjen redosled pop/callback,
brojač koji uvek kaže ukupno, izmenjena rečenica praznog rezultata, visina
vraćena na konstantu.

Mereno: aplikacija **3383 → 3393** (10 slučajeva u
`game_selector_search_test`), 1 preskočen, pun prolaz sam, 8 min 23 s.
Analyze: istih 26 `info`, ista raspodela po fajlovima, nijedan iz izmenjenog
fajla.

Još jedno, o delegiranju: brief faze 0 je rekao „zaustavi sve što pokreneš u
pozadini pre nego što javiš". Radnik je pokrenuo `flutter test` u pozadini i
vratio se bez brojeva — dva puta — pa javio tek iz trećeg pokušaja. **Pravilo
koje radnik može da ispuni tako što ćuti nije pravilo**; sad je pitanje na koje
izveštaj mora da odgovori. I: kad se radnik vrati prazan, prvo pogledaj mašinu.
Jedan `dart` i osam `flutter_tester` procesa su rekli da prvo merenje još
traje — drugo bi dalo crveno koje je zapravo zagušenje.

Uživo: **stavka 203**.

---

## `AdaptiveCardGrid`: broj kolona koji se nigde ne piše — 20.9.2026

Faza 2 iz `docs/PLAN-LISTE.md`. Jedan omotač oko
`SliverGridDelegateWithMaxCrossAxisExtent(420)`, i cela poenta je broj koji se
**ne sme upisati**: koliko kolona. Izvodi se iz ograničenja koje widget dobije,
pa `LibraryList` u uskoj koloni sobe dobije jednu kolonu a da ga niko nije
pitao sa kog je ekrana, a telefon ostaje isti po konstrukciji.

**Prvo je napisana namerno pogrešna implementacija** — fiksne dve kolone — da
bi se videlo da test to hvata. Pao je na 360, 1200 i 1920... ali **na 840 nije**,
jer su tu dve kolone slučajno tačan odgovor. Da je test merio samo jednu
širinu, i to baš 840, prošao bi nad implementacijom koja ne radi ništa od
onoga zbog čega postoji. Pravilo 1 u praksi: provera se gleda kako pada, ne
samo kako prolazi.

Visina pločice ide kroz `mainAxisExtent`, ne kroz `childAspectRatio`: sa
odnosom stranica ista kartica bila bi niska i široka u jednoj koloni, a visoka
i uska u pet, pa bi dvoredni podnaslov stao na desktopu a prelio se na
telefonu.

Tri mutacije: 420 → 600 (crveno na tri slučaja), `mainAxisExtent` → odnos
stranica (crveno na visini), i razmak 12 → 0 — **koji je preživeo**. To je
ovde tačan odgovor, ne rupa: nijedna od četiri merene širine ne stoji na
granici opsega, pa promena razmaka ne može tiho da prevrne broj. (Opsezi se
inače pomeraju sa razmakom: pri unutrašnjih 850, 420 daje tri kolone a 432
dve.) Zapisano u samom testu, da se sledeći put ne postavlja isto pitanje.

Mereno: aplikacija **3393 → 3400** (7 slučajeva), 1 preskočen, pun prolaz sam,
8 min 36 s. Analyze: istih 26 `info`. Nijedan ekran ga još ne koristi — to je
faza 3, i tek tada ima šta da se gleda uživo.

---

## Dve greške u jednom dijalogu koje liče na jednu — 20.9.2026

Faza 3a iz `docs/PLAN-LISTE.md`: `HomeworkListScreen` i `SavedPuzzleSetsDialog`
na `AdaptiveCardGrid`.

**Kapija je našla grešku pre nego što je iko išta gradio.** Slučaj „na telefonu
i dalje jedan po redu, bez prelivanja" pisan je da **čuva** telefon od moje
izmene — a pao je na master-u: `A RenderFlex overflowed by 1.3 pixels on the
right`. Dijalog se već prelivao na 360 dp, i niko to nije video jer release
build ne crta upozorenje nego **tiho seče**.

**Mutacija je zatim rekla šta je tačno krivo, a brief je bio nepecizan.** U
brief-u je pisalo da se to leči time što dijalog uzme veličinu iz `MediaQuery`.
Nije tačno. Vraćanje širine na staro `460` ostavlja telefon **zelenim**;
uklanjanje `insetPadding: 16` sâmo **vraća prelivanje**. Dakle: podrazumevani
`insetPadding` dijaloga (40 sa svake strane, ostavlja oko 280 za `Container`
koji traži 460) je ono što je lomilo telefon, a zakovana širina je ono što je
široki prozor držalo na jednoj koloni. Dve nezavisne greške u istom widgetu
koje spolja liče na jednu — i kapija drži svaku posebno.

Sporedno, ali košta ako se previdi: **kapija sama nije bila `dart format`
čista**, pa bi `dart format test/` tiho razbio uslov „bajt u bajt". Radnik je to
prijavio; fajl u `docs/gates/` je sada formatiran. Kapija mora da preživi alat
koji se svakako pušta preko nje.

Četiri mutacije vodećeg, svaka crvena na svom testu: širina nazad na 460,
pločica spuštena na 40, preimenovan ključ vrste, uklonjen `insetPadding`.

Mereno: aplikacija **3400 → 3407** (7 slučajeva iz kapije, nijedan radnikov),
1 preskočen, pun prolaz sam, 9 min 4 s. Analyze: istih 26 `info`, nijedan iz
dva izmenjena fajla. Uživo: **stavka 204**.

---

## Širina koja se traži a ne popunjava — 20.9.2026, nalaz vlasnika uživo

Nastavak faze 3a. Vlasnik je otvorio „Saved puzzles" na Windows-u, sa **jednim**
sačuvanim skupom, i poslao sliku. Dijalog je uzeo punih 640 px koliko mu je
dozvoljeno, mreža je ispravno rezervisala **dve** kolone, i **polovina dijaloga
je bila prazna**. Mereno: kartica popunjava 49% reda; 29 px mrtvog prostora
između „5 puzzles" i dugmadi, jer je `Spacer` gurao dugmad na dno pločice više
od svog sadržaja.

To je **ista vlasnikova zamerka u novom odelu**, i ja sam je napravio. Dijalog
je bio osposobljen da *može* da koristi širinu, ali ne i da uzme **samo onoliko
koliko može da popuni**. Mreža je tačan odgovor za mnogo kartica i pogrešan za
jednu.

Kapija faze 3a je pitala „stoje li **dva** skupa jedan pored drugog na 1400?" i
nikad nije pitala kako izgleda **jedan**. Prošla je. Novi slučajevi: jedan skup
popunjava red (>90%), **dva i dalje dele red** — taj drugi postoji da se
popravka ne bi svela na „suzi dijalog zauvek" — i razmak između teksta i
dugmadi ispod 12 px.

Popravka: dijalog traži onoliko kolona koliko ima kartica
(`columns * maxTileWidth + razmaci + padding`, ograničeno ekranom). Jedan skup
→ dijalog 460, popunjenost 100%, razmak 4 px. Dva → 640, i dalje jedan pored
drugog.

Usput, i vredi zapisati: prvo sam skinuo `tileHeight` na podrazumevanih 112,
„izračunato" iz sadržaja. Prelilo se **za 3 px**, šest puta. Procena visine iz
glave je procena; kapija je to uhvatila odmah, pa je visina 120 sa marginom, a
ne 112 iz računa.

Mereno: aplikacija **3407 → 3410**, 1 preskočen, pun prolaz sam. Analyze: istih
26 `info`.

**Otvoreno, iz iste provere:** u „Choose a game" podnaslov vrste pokazuje
`1. e4 { [%clk 0:03:00] } 1... c5 ...` — komentari sa satom pojedu red, pa se
vide dva poteza umesto osam, i **pretraga po potezima je oslabljena** (kucanje
`e4 c5` ne nalazi ništa, jer je između njih `{ [%clk ... ] }`). Uzrok je moj
fixture iz faze 1: čist PGN `1. d4 d5 2. c4 e6`, dok vlasnikovih 4126 partija
dolazi sa onlajn servisa i nosi `%clk` na svakom potezu. Pravilo 6, od reči do
reči. Nije faza 7 (to je tabela) nego ispravka faze 1.

---

## Sat u PGN-u je pojeo i prikaz i pretragu — 20.9.2026, faza 1b

Vlasnik je otvorio „Choose a game" na Windows-u i poslao sliku: podnaslov svake
vrste glasi `1. e4 { [%clk 0:03:00] } 1... c5 { [%clk 0:03:00] } 2. Nf3…`. Vide
se **dva poteza tamo gde bi stalo osam**. Gore od izgleda: **pretraga po
potezima je bila polumrtva** — kucanje `e4 c5` ne nalazi ništa, jer je između
njih anotacija, a `pgnBody` je upravo string koji je filter čitao.

Uzrok je moj fixture iz faze 1: čist tekst poteza, `1. d4 d5 2. c4 e6`. Vlasnikove
4126 partije dolaze sa onlajn servisa i nose `%clk` posle **svakog** poteza.
Pravilo 6 od reči do reči: fixture jednostavniji od stvarnog ne može da padne.
Kapija je bila zelena nad pretragom koja na pravim podacima radi pola posla.

Popravka ima jedan dom: `MoveTree.sanTokens` — čita samo poteze iz tela partije
(napolje idu `{ … }` komentari, `;` komentari, `$N` NAG-ovi, varijante —
najdublje prvo, pa i ugnježdene — brojevi poteza i rezultat). Kroz njega idu
**i prikaz i pretraga**, pa `1. e4 c5` i `e4 c5` daju isti odgovor. Prikaz se
sada **ispisuje iz poteza**, ne seče iz fajla: `1. e4 c5 2. Nf3 d6 3. d4 cxd4
4. Nxd4`.

**Dve pouke o samim mutacijama.**

Prve dve mutacije nisu bile ispravne: brisanje linije je oborilo **prevođenje**,
a greška prevođenja nije pravo crveno (pravilo 3). Ponovljene tako što regex
postane nešto što se ne poklapa ni sa čim — kod se i dalje prevodi, a ponašanje
umire. Tek tada su obe pale na tačnom testu.

Treća je **preživela**: isključivanje uklanjanja varijanti nije promenilo
ništa, jer u fixture-ima dijaloga nema nijedne varijante. `sanTokens` je od sada
deljeni API, a namerno ponašanje koje ništa ne proverava je upravo ono što
istrune — pa je dobio **svoj čist test** (`san_tokens_test.dart`, 10 slučajeva).
Ista mutacija sada pada na oba slučaja sa varijantama.

Svesno ograničenje, zapisano u kodu a ne ostavljeno kao iznenađenje: telo koje
počinje sa crnim na potezu se i dalje numeriše od 1. Broj koji je za jedan
pomeren vredi manje nego drugi parser koji bi ga pogodio.

Mereno: aplikacija **3410 → 3423** (3 u kapiji dijaloga, 10 u čistom testu),
1 preskočen, pun prolaz sam. Analyze: istih 26 `info`, nijedan iz dva izmenjena
fajla. Uživo: **stavka 203**, dopunjena.

---

## Deveti fajl koji grep nije našao — 20.9.2026, faza 3b

Faza 3b plana `PLAN-LISTE.md`: `LibraryList` prestaje da bude `ListView` sa
vrstama i postaje mreža kartica. Sam kod je pedesetak linija. Plan je unapred
rekao gde je rizik — „površina testova je veća polovina" — i propisao čuvara:
**posle svake faze pretraži izmenjene test fajlove za `ListTile`.**

Pre gradnje sam pretražio `LibraryList` i `library-row-` i dobio osam fajlova.
Svih osam je posle izmene bilo zeleno. Deveti je pao tek u punom prolazu:
`saved_tutorials_phone_test.dart`, slučaj **„on Windows the rows keep their
buttons beside the title"** — tvrdnja da dugme „Send" stoji u istoj liniji sa
naslovom, unutar 24 px. Posle izmene je izmereno **68**.

Taj fajl **ne pominje `LibraryList` nigde**. Do vrste dolazi preko deljenog
pomoćnika `libraryRow` iz `test/support/shelf_over_lessons.dart`. Pouka je
uska i ponovljiva: **pretraži i deljene pomoćnike i konstantu koju brišeš, ne
samo ime widgeta.** Deljeni pomoćnik je upravo mesto gde se finder sakrije,
jer je napravljen da pozivaoca oslobodi znanja o tome šta crta ekran.

Druga polovina je šta se radi kad takav test padne. Tvrdnja je bila **tačna i
namerna** kad je pisana (vlasnikova prijava od 17.9.2026: na telefonu četiri
dugmeta nisu ostavila naslovu širine), a faza 3b je **namerno ukida**: kartica
nikad nije šira od 420, prag `actionsBesideFrom = 480` se više ne može
dosegnuti i obrisan je. Zato slučaj nije ni obrisan ni „popravljen" tiho —
prepisan je otvoreno, sa objašnjenjem iznad njega, a ono zbog čega fajl
postoji (naslov ima prostora, sva četiri dugmeta su na ekranu i dohvatljiva)
nije ni pipnuto. Četiri telefonska slučaja u istom fajlu su ostala zelena, što
je dokaz da fajl i dalje radi svoj posao.

**Tri mutacije su preživele, sve tri iz istog razloga.** `Spacer` između
pločice i dugmadi, i `MainAxisAlignment.spaceBetween`, ne menjaju ništa — jer
je `cardHeight = 132` tesno oko najviše kartice, pa na tutorijalu ima 4 px da
se razvuče. Tvrdnja o rupi ugrize tek kad višak postoji: `cardHeight = 180` sa
`spaceBetween` pada, i to je doslovno greška iz faze 3a (29 px mrtvog
prostora). Treća preživela kaže granicu kapije naglas: **previše velika
visina kartice sama po sebi ne pada nigde.** Sadržaj stoji uz vrh, ništa se ne
preliva, nijedno pravilo koje je kapija zapisala nije prekršeno — a prostor se
troši. To je pitanje o testu, ne presuda.

Mereno: aplikacija **3423 → 3437** (14 u kapiji), 1 preskočen, pun prolaz sam.
Analyze: istih 26 `info`, nijedan iz četiri izmenjena fajla. Uživo: **stavka
205**.
