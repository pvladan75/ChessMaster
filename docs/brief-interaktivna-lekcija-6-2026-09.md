# Brief: the lesson step draws what the author drew, and says what it shows

Phase 6 of [PLAN-INTERAKTIVNA-LEKCIJA.md](PLAN-INTERAKTIVNA-LEKCIJA.md). Flutter
only, in `chess_app/lib/`. There is no server work in this batch, no new
endpoint, and nothing to migrate.

## 1. Why this job exists

A trainer prepares a lesson about one idea. Half of what those ideas are made of
is not a move but a **square** — a weak square, an outpost, the hole a pawn left
behind — and the other half is a sentence the trainer would say out loud in the
room. The lesson viewer today shows a board, a line to step through, and the
note under the move. It draws none of the trainer's arrows, none of their
squares, and offers to read nothing aloud.

Every part needed for that already exists and is already tested:

* `MoveTree.parsePgn` has read `[%cal]` and `[%csl]` since phase 2, keeps them
  on the node, and writes them back out on export.
* `PgnLine` (what `mainLine()` returns) carries `arrows` and `squares` **per
  move**, and — since 5.9.2026 — `rootArrows`, `rootSquares` and `rootComment`
  for what the author wrote before the first move.
* `ChessBoardWithOverlay` gained a `squares` parameter on 5.9.2026 and has had
  `arrows` for a long time. Both are drawn by `ChessBoardPainter`.
* `SpeakableInfo` is the one way a screen offers to read a sentence out, and has
  been since phase 0 of `PLAN-JEDNOSTAVNOST`.

**None of it is wired into `LessonViewerScreen`.** That wiring is the whole job.
If you find yourself writing a parser, a painter, or a speech service, stop and
read this section again.

## 2. The rule everything else follows from

**Speech is a second channel over words that are on the screen. It is never the
only copy of them.**

A `SpeakableInfo` whose sentence is not also drawn is a sentence most readers of
this app never get: children, on school tablets, with the sound off, in a room
with fourteen other children. `SpeakableInfo` refuses to compose its own text
for exactly this reason — you hand it what the screen already shows.

The gate tests this as a property over the whole screen, not case by case: every
`SpeakableInfo` on screen must have its `text` inside the words its own subtree
draws. A panel that speaks a summary of what is drawn under it fails.

## 3. The contract — what is where

### 3.1 `PgnLine`, from `MoveTree.parsePgn(pgn, startingFen: step.fen).mainLine()`

```dart
class PgnLine {
  final List<String> fens;            // n + 1: the position before move 1, then one per move
  final List<String> movesSan;        // n
  final List<String> comments;        // n
  final List<List<ChessArrow>> arrows;   // n
  final List<List<SquareMark>> squares;  // n

  final String rootComment;              // what was written before move 1
  final List<ChessArrow> rootArrows;     // ...and drawn before move 1
  final List<SquareMark> rootSquares;
}
```

The screen already reads `fens`, `movesSan` and `comments` out of this and holds
them in `_fens`, `_moves` and `_comments`, keyed by `_moveIndex` where **0 is the
position before the first move**. `_comments[_moveIndex - 1]` is the existing
pattern; arrows and squares are indexed the same way, and at `_moveIndex == 0`
they come from the three `root*` fields.

This alignment is the one thing in this batch that is easy to get wrong, and the
gate has a test for each of its three cases: the root's drawing before any move,
the move's drawing after one, and the root's again after stepping back.

### 3.2 `ChessBoardWithOverlay`

```dart
ChessBoardWithOverlay(
  arrows: <ChessArrow>[...],   // already passed as `const []` by this screen
  squares: <SquareMark>[...],  // new, defaulted to const []
  ...
)
```

Nothing else about the board changes. Do not touch
`chess_app/lib/widgets/board_overlay_painter.dart` or
`chess_app/lib/widgets/game_screen/chess_board_with_overlay.dart` — they were
finished on 5.9.2026 for this batch and they are shared by every screen in the
app.

### 3.3 `SpeakableInfo`

```dart
SpeakableInfo(
  text: theSentenceAlreadyOnScreen,
  style: ...,            // optional
  child: ...,            // optional: draw it yourself, `text` is still what is spoken
  autoSpeak: false,      // leave it false — see §5
  hideButtonWhenOff: false,
)
```

It reads `AppSettingsService.instance` and `SpeechService.instance` itself. Do
not inject anything, do not call `SpeechService` from the screen, and do not
add a speech switch to this screen — the speaker button on the panel *is* the
switch.

### 3.4 What already exists and must be reused

| | |
|---|---|
| `lib/features/assignments/screens/lesson_viewer_screen.dart` | the screen, and the only file this batch should need to change |
| `lib/widgets/speakable_info.dart` | every spoken sentence. Do not write a second speaker |
| `lib/widgets/game_screen/chess_board_with_overlay.dart` | `arrows` and `squares`. **Read only** |
| `lib/move_tree.dart` | `PgnLine`, `ChessArrow`, `SquareMark`. **Read only** |
| `lib/widgets/action_banner.dart` | the look for "this expects something from you", already used by the step that asks |

## 4. Serbian strings

**This batch adds none.** Every sentence it speaks or draws is one the trainer
wrote — the step's `instruction`, the note on a move — or one that is already on
this screen from phase 4b. The `strings` gate has an allowance for the viewer,
because moving a literal inside the file counts as a change, but an *added*
sentence in Serbian is a sign you invented copy that the author was supposed to
write.

If you believe a new string is genuinely needed, say which and why in the report
and leave it out.

## 5. What gets this rejected

* **A sentence that is spoken and not drawn.** §2.
* **`autoSpeak: true`.** A step that announces itself the moment it appears is
  the noise this feature is trying not to be, and fourteen tablets doing it at
  once in one room is worse. The reader presses the speaker.
* **A second speaker widget, a second banner, or a raw `ScaffoldMessenger`** —
  `AppFeedback` exists because a snackbar once threw and took down the recording
  it was reporting on.
* **Editing anything under `test/`.** The tests are the grade. If one looks
  wrong, say so in the report and stop.
* **Touching the painter or the board widget**, or `move_tree.dart`. They are
  finished and they are shared.
* **A timer, a score, a streak,** or anything ranking one child against another.
* **Colour as the only difference between two things.** The owner is
  colourblind and their live sign-off is what this ships on. You should not need
  a colour decision in this batch at all; if you think you do, you have found
  something for the report.
* **New packages.** Nothing goes in `pubspec.yaml`.
* **The palette has no yellow, and this batch does not add one.**
  `ArrowColor` is R/O/G/B/P and `byId` falls back to grey, so `[%csl Yd5]` — and
  Lichess writes those — draws a grey ring. The five values come out of a search
  that holds every pair at 1.5:1 under protanopia and deuteranopia; a sixth has
  to be measured into that set, not picked. Out of scope. Do not "fix" it.

## 6. How you will be judged

Machine-checked, in this order:

1. `flutter test` — **the 8 tests in `test/lesson_step_narration_test.dart` must
   pass**, and the whole suite must be at least **1334** passing with 1 skipped.
   Measure both numbers yourself; do not trust these.
2. `flutter analyze` — 29 issues, all `info`, all
   `curly_braces_in_flow_control_structures`. **It does not exit clean and never
   has.** Zero errors, zero warnings, and no info that is not already on that
   list.
3. `dart format` on every file you touched.
4. The `strings`, `idioms`, `contrast`, `scale` and `worktree` gates.

**One of the eight is green before you start** — „a step with no line draws
nothing" passes today, because the screen draws nothing today. It is there to
catch a regression, not to measure progress. The other seven are the work.

## 7. Your report

Not a summary. Numbers you computed in this run:

* `flutter test` before and after, both measured by you;
* the `flutter analyze` count and whether the list changed;
* **proof of the property, not the mechanism.** „The arrows follow the move
  index" is proved by stepping forward and back and reading `arrows` off the
  board widget — which is what the gate does — not by saying you indexed it;
* every file you added a user-facing string to, if you added any at all;
* **anything this brief got wrong.** A correction is worth more than a clean
  report, and previous batches on this project have found real errors in briefs
  — including one that named a type which did not appear in the section it
  cited, so check the citation before you file the correction.
