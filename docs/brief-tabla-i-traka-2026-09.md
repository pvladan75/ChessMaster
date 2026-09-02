# Brief: the board says what was just played, and what it is called

Written 3.9.2026. Pairs with [TASK-tabla-i-traka.md](TASK-tabla-i-traka.md),
which holds the scope and the method. This file holds the *why* and the
contract.

This is Phase 2 of [PLAN-REPERTOAR-2.md](PLAN-REPERTOAR-2.md) — requirements 1
and 7 of nine. Phases 0 and 1 are merged; the backend is frozen.

## 1. Why this job exists

Two complaints from the project owner, both about the same thing: the repertoire
screens show a board and tell you nothing about how it got there.

**The last move is invisible.** You answer a drill question, the opponent
replies, and the position changes with nothing marking which piece moved. On a
board you have been staring at for ten minutes that is a genuine "wait, what
just happened" — and the drill's whole premise is that you are reading the
position rather than the move list.

**The opening has no name.** The build screen walks you through positions with a
breadcrumb of SAN above them. `1.e4 c5 2.Nf3 d6 3.d4` is a breadcrumb; "B54 ·
Sicilian, Open" is a name. The owner builds repertoires by opening, and the
screen never once says which opening he is in.

Neither is a hard problem, and that is the point: this batch is **wiring, not
invention**. Both halves already exist in the codebase and are not connected.

## 2. What to build

### 2.1 The highlight is already drawn — it is not passed in

`ChessBoardPainter` in `chess_app/lib/widgets/board_overlay_painter.dart`
already takes `lastMoveFrom`, `lastMoveTo` and `lastMoveColor`, and already
paints, at line 231 onward: an amber wash at 45% alpha, a border, **and
black-and-white corner brackets**. Read that block before you write anything.

`ChessBoardWithOverlay` does not expose the two squares. It constructs
`ChessBoardPainter` twice — once inside the drawing-mode `GestureDetector` and
once in the `if (!widget.isDrawingMode)` branch — and passes `lastMoveColor` to
both while passing the squares to neither.

So step 1 is two optional fields forwarded to two constructors. **Both.** If you
wire only the non-drawing one, the highlight disappears the moment the trainer
picks up the pen, which is exactly when they are pointing at the move.

Do not edit the painter. The drawing is finished and correct.

### 2.2 Who tracks the move

The Analysis Studio and the AI Studio already track `_lastMoveFrom` /
`_lastMoveTo` in their own state and pass them to their own paint layer. **Leave
both alone.** They work, and unifying them is a different job that this batch
must not start.

The build screen and the drill screen get the same treatment: two nullable
strings in state, passed down to `ChessBoardWithOverlay`.

The half that is easy to get wrong is **clearing** them. A repertoire screen
moves the board for reasons that are not a move being played: the walk hands
back the next position, the tree panel is tapped, a drill line is replayed from
its start. In every one of those the previous move's squares are meaningless, and
leaving them lit points at two squares from a position that is no longer on
screen. Clear on every board change that is not a played move.

`ChessBoardWithOverlay.lastMoveSquares(game)` (a static, around line 80) reads
the pair off a `chess.Chess` history, promotion included. Where you have the game
object, use it instead of tracking squares by hand — it already survived a bug
about checkmate that the obvious implementation did not.

### 2.3 The banner, and the last-named-position rule

A new widget above the board on both screens, showing `ECO · Name`.

The trap: **the ECO dataset only names openings, not every position in them.**
Walk four moves into a real line and `lookupByFen` returns null — not because
something failed, but because nobody gave that position a name. A banner that
renders whatever the lookup just returned goes blank exactly where the student
is doing the most work.

So the rule is: **carry the last name forward.** The banner holds the most recent
non-null lookup and keeps displaying it until a *different* named position
replaces it. Walking deeper into the Open Sicilian keeps saying "B54 · Sicilian,
Open"; it does not blink out and it does not claim a name it was not given.

Reset the carried name when the board jumps to an unrelated position — a
different repertoire, a new root — for the same reason the highlight is cleared.

There is a banner of this shape already written, in
`analysis_studio_screen.dart` around line 1681
(`'${bookEntry.eco} · ${bookEntry.name}'`). **Read it for the format and build
your own widget.** Do not import it or move it: it is entangled with that
screen's phase/endgame logic, which the repertoire screens have no use for.

### 2.4 Why the lookup must be injectable

`OpeningBookService` is a singleton whose `_load()` calls `compute()` — a
background isolate. **`compute()` never completes inside `testWidgets`.** A
widget test that waits for `ensureLoaded()` hangs until the test timeout; one
that does not wait gets `lookupByFen` returning null forever, because it is
guarded by `if (!_loaded) return null`.

Either way the banner is untestable through the real service. So the widget takes
its lookup as a parameter:

```dart
final OpeningBookEntry? Function(String fen)? lookup;
```

defaulting to `OpeningBookService.instance.lookupByFen` when null. The screens
pass nothing; the tests pass a map.

This is not a testing nicety bolted on — it is the only way this widget can be
tested at all, and an untested banner is how the last-named rule silently stops
working.

## 3. The API, exactly

**No route changes, and no new client methods.** Everything this batch needs is
local to the app.

| What | Where | Shape |
|---|---|---|
| the last move | `ChessBoardWithOverlay.lastMoveSquares(chess.Chess)` | `({String from, String to, String promotion})?` — null when no move has been played |
| the opening | `OpeningBookService.instance.lookupByFen(String fen)` | `OpeningBookEntry?` with `.eco` and `.name`, both `String` |
| FEN normalisation | `OpeningBookService.normalizeFen(String)` | first **four** fields only — the index is keyed this way, so a raw FEN with move counters will miss |

Two behaviours to respect rather than smooth over:

* `lookupByFen` returns null both for "not loaded yet" and for "no name for this
  position". The widget cannot tell them apart and **must not try** — the
  last-named rule handles both correctly.
* `isLoaded` is false until the isolate returns. On a real device the first
  paint of the screen will usually have no name. That is fine and must not be
  rendered as an error or a spinner; it is an empty banner that fills in.

If you believe you need a new endpoint or a new client method to finish this
batch, **stop and say so in the report** rather than inventing one.

## 4. What already exists — reuse, do not rebuild

| | |
|---|---|
| `ChessBoardPainter` | draws the highlight, brackets included. Finished |
| `ChessBoardWithOverlay.lastMoveSquares` | computes the pair, promotion-safe |
| `Breakpoints.isWide(context)` (`lib/theme/breakpoints.dart`, 840 dp) | the app-wide "is there room for two columns". Do not introduce another threshold |
| `AppText`, `AppSpacing`, `AppRadii`, `context.colors` | the theme. Hardcoded colours and spacings fail review |
| `AppFeedback` | the only way to show a message. See §5 |
| `test/repertoire_gate_test.dart` | the `_FakeApi extends RepertoireApiService` over `MockClient` pattern. Copy it |

Friction worth knowing: `RepertoireApiService` is subclassed by a fake in each
repertoire test file. You are not adding methods to it in this batch, so none of
those should need touching. If you find yourself editing several fakes, you have
drifted out of scope — stop and report.

## 5. Rules that bite

**Colour is never the only carrier of a fact.** The project owner is colourblind.
His sign-off on a screen proves luminance and shape, never hue. This is why the
last-move highlight is a wash *plus* black-and-white corner brackets — the
brackets are the part that works, and the amber is decoration. If you add any
new marking, it carries its meaning in shape, position or text. Do not argue that
a hue shift reads anyway; it does not, for the person who has to use this.

**A release build paints no overflow warning.** In debug a too-wide `Row` gets
the yellow-and-black stripes and an assertion. In release it is simply clipped —
the row looks shorter than it is and anything past the edge is unreachable. Three
of these shipped before they were found by looking at a phone. The card's
`trailing:` on the list screen is already a `Row` with two buttons, and the
banner you are adding sits above a board on a 360 dp screen with an opening name
that can run to forty characters. **Use `Wrap` where a row can grow, and take
widths from `MediaQuery` rather than hardcoding them.** A widget test at
`Size(360, 640)` catches it, because in a test build the overflow *does* throw —
which is why every new widget test in this batch pumps at that size.

**Never call `ScaffoldMessenger` directly.** All 82 raw calls in `lib/` were
moved onto `AppFeedback` on 25.8.2026 and a guard test fails if one comes back.
The reason: a message must never be able to take down the action it reports on.
Twice in this project a `showSnackBar` threw before the work it was announcing —
once a recording that would not stop for a child whose parent had refused it.
**Do the thing, then say it**, through `AppFeedback`, which cannot throw.

**`flutter analyze` does not exit clean and has not for a long time.** It reports
29 issues, every one `info`, every one `curly_braces_in_flow_control_structures`.
A red exit code is the normal state here, so the exit code tells you nothing —
compare the list. Adding a thirtieth fails this batch.

**User-facing strings stay Serbian.** Comments and your report are English.

## 6. How this will be judged

Gates, each an exit code rather than a sentence:

* `git diff --name-only` must not match `chess_backend/` — a hard boundary;
* `flutter analyze` still exactly the 29 known infos, **list compared, not
  counted**, in `positional_evaluator_service.dart` (8),
  `tactical_motif_detector.dart` (3), `game_analysis_walker_service.dart` (3),
  `review_api_service.dart` (1), `ai_studio_screen.dart` (12) and
  `matrix_filter_panel.dart` (2);
* `flutter test` at or above **1068 passing, 1 skipped** — measured by you before
  you start and again at the end. A suite that quietly stops running half of
  itself still exits 0, so the count is the signal;
* `dart format --set-exit-if-changed`;
* `test/app_feedback_guard_test.dart` green;
* a widget test at `Size(360, 640)` for the banner.

Then the three questions the work has to answer, phrased so you can check them
yourself:

1. **Does the highlight survive drawing mode?** Naming two call sites is not
   proof — the broken version has two call sites. Pump the board in drawing mode
   with the squares set and assert the painter got them.
2. **Does the banner hold its name past the end of the dataset?** A test that
   feeds a known position, then an unknown one, and reads the name still there.
3. **Does a stale highlight ever survive a jump?** Move the board without
   playing a move and assert the squares are null.

## 7. Not in scope

* **The Analysis Studio and AI Studio last-move layers.** They work. Unifying
  them onto `ChessBoardWithOverlay` is a real and separate job.
* **`board_overlay_painter.dart`.** No edits. If you believe the drawing is
  wrong, say so in the report and leave it.
* **Anything under `chess_backend/`.**
* **The breadth dialog, the draft review, the workspace banner, the card badge.**
  Those are Phase 3 and have their own brief; building them here collides with
  another worker.
* **The 29 known analyze infos.** Clearing them is a fine standalone chore and
  would fail this batch's gate, which compares the list.
* Any bug you find that this brief did not name. Report it, do not fix it, and
  do not claim to have fixed it.
