# Brief — the tree's view never moves itself

Phase 2 of `docs/PLAN-TABLA-I-STABLO.md`. Flutter only, in `chess_app/`, and
**one widget file plus one new test file**. `chess_backend/` is not touched by
this batch at all — no endpoint, no request, no field, no migration.

## 1. Why this exists

The owner's report of 4.9.2026, 21:55:

> „Korisnik je već izabrao veličinu, tj. zum koji mu odgovara... Ako aplikacija
> menja zum, onda korisnik izgubi fokus. Takođe, ne mora trenutni potez da bude
> centriran na sred ekrana, već samo ako priđe ivicama."

And his decision of 5.9.2026, which made it unconditional and closed the
argument about where the change comes from:

> „Zum (veličina prikaza) u grafičkom stablu poteza ne treba da se menja
> automatski, već to korisnik radi. Dakle, aplikacija nikad ne menja sama zum."

Two separate complaints live in those quotes, and they need separate fixes:

1. **The zoom changes by itself.** The reader picks a size, and the app takes it
   away. §2 is about what is and is not known here — read it before you touch
   anything, because most of it is already measured and the wrong half is easy
   to "fix".
2. **The view jumps to centre the active move after every single move.** This
   one is not in doubt and it is the work: §3.

This applies to **every** screen that draws the graphical tree, not only the
repertoire. There is one widget behind all of them.

## 2. What is already measured — do not re-derive it, and do not fix past it

`lib/features/analysis_studio/widgets/visual_move_tree_widget.dart` holds a
`TransformationController` (`_transformController`) driving an
`InteractiveViewer`. **Exactly three places assign to it**, and this was
grepped on master on 5.9.2026, not remembered:

| line | what | changes the scale? |
|---|---|---|
| 370 | `_zoomBy` | **yes** — but only from the `+`/`−` buttons, the `+`/`−` keys and the mouse wheel. All three are the user. |
| 374 | `_resetView` | **yes** — sets `Matrix4.identity()`. Only from the toolbar's „Resetuj pogled". The user again. |
| 397 | `_centerOnActive` | **no.** It reads `getMaxScaleOnAxis()` and writes the same number back. |

So: **inside this file, nothing changes the zoom that the reader did not ask
for.** `_centerOnActive` demonstrably preserves the scale today. If you "fix"
the zoom by editing `_centerOnActive`'s scale handling you will have changed
nothing and reported a fix, which is the one outcome this brief exists to
prevent.

**The leading explanation is state loss, and it is outside this file.**
`_transformController` lives in the widget's `State`. `repertoire_build_screen.dart`
draws the tree in **two different places** depending on the window width:
inside the board column when narrow (line 3064), and in its own `Expanded`
beside the board when wide (line 2768), switching at `Breakpoints.wide` = 840.
A widget that moves to a different slot in the widget tree gets a **new**
`State`, hence a new `TransformationController`, hence scale back to 1.0. This
is the same trap the project already wrote down for `OpeningBanner._lastNamed`
in that very file. The owner works on Windows and resizes windows.

**That is a hypothesis, not a finding.** §5 asks you to *measure* it and report
the numbers. It does **not** ask you to fix it: the fix is in
`repertoire_build_screen.dart`, which another phase just rewrote and which this
batch may not open. **You may not describe the measurement as a fix.**

## 3. What to build

### 3.1 The rule

Today, `build()` does this (around line 424):

```dart
if (_lastCenteredNodeId != widget.activeNode.id) {
  _lastCenteredNodeId = widget.activeNode.id;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _centerOnActive(positioned);
  });
}
```

— so **every** change of active move re-centres the active card in the middle of
the viewport. Walking a line one move at a time therefore drags the whole
picture under the reader on every step, which is the „izgubi fokus" of the
report.

The new rule, in one sentence: **the view moves only when the active card is not
comfortably inside the viewport, and then it moves by the smallest amount that
puts it back inside — never to the centre, and never at a different scale.**

Concretely, in the post-frame callback:

1. Project the active card's rect from canvas coordinates into viewport
   coordinates through the current transform.
2. Take the viewport rect, deflated by a margin (§3.2) on all four sides.
3. If the projected card is **entirely inside** the deflated rect, **do
   nothing** — do not assign to `_transformController` at all. Not "assign the
   same matrix": a needless assignment still notifies listeners, and a test can
   tell the difference.
4. Otherwise translate by the minimum offset on each axis that brings the card
   fully inside the deflated rect. The two axes are independent — a card that is
   off the right edge but vertically fine moves horizontally only.
5. **The scale is never touched**, on any path.

### 3.2 The margin

**48.0 logical pixels of the viewport**, as a named constant with its reasoning
in a doc comment.

Where the number comes from: a node card is 124 × 40 (`_nodeWidth`,
`_nodeHeight`). 48 is a card's height plus a little, so when the rule does fire,
the card lands with roughly one card's worth of room between it and the edge —
enough for the reader to see the edge that connects it to its parent, which is
what tells them where they are. It is measured against the **viewport**, in
viewport pixels, never as a fraction of the canvas: the canvas grows as the tree
grows, and a fraction of it would mean a different margin every session.

If your own measurement says 48 is wrong, change it and **say so in the report
with the numbers** — but do not change it silently and do not make it a
fraction.

### 3.3 What stays exactly as it is

* **`_centerOnActive` itself stays, and stays centring.** The toolbar's
  „Centriraj na aktivni potez" button calls it, and that is the user asking,
  which the rule explicitly permits. Only the *automatic* call site changes.
* „Resetuj pogled", the `+`/`−` buttons, the `+`/`−` keys, the mouse wheel and
  pinch-to-zoom: untouched.
* The auto-player. It changes the active node repeatedly, so it goes through the
  new rule like anything else — which is an improvement, not a special case, and
  needs no code of its own.
* The horizontal/vertical layout toggle, the transposition menu, the card
  drawing, the tooltips, the four looks. None of that is this batch.

## 4. What already exists — reuse, do not rebuild

| | |
|---|---|
| `visual_move_tree_widget.dart` `_centerOnActive` (line 377) | the centring maths, including how a canvas point is turned into a transform. Your edge rule is a near neighbour of it; read it first. |
| the same file, `_zoomBy` (line 357) | how a transform is composed here — `translateByDouble` / `scaleByDouble` on a cloned matrix, and `toScene` for viewport→canvas. Use the same idiom. |
| `_viewportSize` | assigned in the `LayoutBuilder` builder during build, so it is populated by the time the post-frame callback runs. Keep that arrangement; do not read the size some other way. |
| `_PositionedNode` (`positioned`) | the laid-out cards, each with `x`, `y`, `width`, `height` in canvas coordinates. The active one is found by `pn.node.id == widget.activeNode.id`. |
| `test/repertoire_tree_looks_test.dart` | **the model for your test file.** It has a `pumpTree` helper that mounts `VisualMoveTreeWidget` at a fixed `tester.view.physicalSize`, and helpers that find a card by its SAN. Copy the shape. |
| `test/tree_depth_follows_reader_test.dart` | another tree test, if you want a second example of building an `AnalysisNode` tree in a test. |

**Reading the transform from a test.** The controller is private, but the
`InteractiveViewer` that uses it is not:

```dart
final iv = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
final m = iv.transformationController!.value;
final scale = m.getMaxScaleOnAxis();
```

That is the honest way in — no test-only hooks, no `@visibleForTesting` field
added to production code for the convenience of a test.

**Where the card is on screen** is `tester.getRect(find.text('<san>'))` against
the widget's own rect from `tester.getRect(find.byType(VisualMoveTreeWidget))`.
Two ways of asking the same question; use both, because the matrix agreeing with
itself proves less than the pixels agreeing with the matrix.

## 5. The measurement you must report and must not fix

Reproduce the state-loss hypothesis of §2 at the widget level, without the
screen and without a backend:

* Mount `VisualMoveTreeWidget` in a `LayoutBuilder` that puts it in one subtree
  slot below a width threshold and a **different** slot above it — e.g. a child
  of a `Column` versus a child of a `Row`'s `Expanded` — mirroring what
  `repertoire_build_screen.dart` does at 840.
* Zoom in twice (drive the `+` button, do not call anything private), print the
  scale.
* Change `tester.view.physicalSize` across the threshold, pump, print the scale
  again.

Print both numbers in the report. If the second is 1.0, you have reproduced it
and that is a finding worth more than the rest of the batch.

**Do not fix it.** Do not add a `GlobalKey`. Do not hoist the controller into a
`widget` parameter. Do not touch `repertoire_build_screen.dart`. Do this as a
scratch file, print the numbers, delete the scratch file, and quote the printed
output in the report. A leftover scratch file fails the worktree gate.

## 6. Rules that bite

* **`flutter analyze` does not exit clean and has not for a long time.** It
  reports 29 `info` issues, all `curly_braces_in_flow_control_structures`. The
  rule is zero errors, zero warnings and **no new infos** — compare the list,
  not the exit code. If you add a one-line `if` without braces in this file you
  will make it 30 and fail.
* **`dart format` every Dart file you touch, last.** CI does not enforce it; an
  unformatted file turns the next diff into noise.
* **Do not call `ScaffoldMessenger`.** `AppFeedback` only, and
  `test/app_feedback_guard_test.dart` fails on a raw call. Nothing in this batch
  should need to say anything to anybody, so a message here is itself a finding.
* **Do not edit an existing test to agree with your code.** A test you had to
  change is a finding: report it and stop. In particular
  `repertoire_tree_looks_test.dart` and `tree_depth_follows_reader_test.dart`
  mount this widget and must pass untouched.
* **Do not grade yourself on golden tests.** They are skipped unconditionally in
  `dart_test.yaml`, and `--tags golden` alone still skips them — the run exits 0
  saying „All tests skipped". Widget tests over the real widget, or nothing.
* **Exactly one test in the suite is skipped** (the golden group). If your run
  reports two, you added a skip, and a skipped test is not a passing one.
* **Prove every new test by mutation.** Break the code the test guards, watch it
  go red, restore it, watch it go green. A guard you have not seen fail is not a
  guard — this project has shipped three that did not guard, one of which read a
  fixed 1600 characters from the start of a function and so still matched after
  the check it guarded was deleted.
* **Nothing user-facing changes.** No new string, no changed string, no changed
  tooltip. The toolbar keeps „Centriraj na aktivni potez", „Resetuj pogled",
  „Uvećaj", „Umanji" exactly as written. A new string in this diff means you
  built something nobody asked for.

## 7. How this will be judged

Gates: `tests` (count and exit), `analyze` (the 29-item list, not the exit
code), `format`, `worktree` (no untracked files beyond the one test file and the
report), `strings` (empty allowance — any added user-facing string fails).

Then four questions the work has to answer, and you can check every one
yourself:

1. **Does the scale survive a move?** Zoom in, change the active node, read the
   scale. Identical, exactly — not "close".
2. **Does the view stay put when it should?** An active node comfortably inside
   the viewport must produce **no transform change at all** — the whole matrix,
   not just the scale.
3. **Does it move when it must, and only just?** An active node past the edge
   ends up inside the deflated viewport — and **not** at the viewport's centre.
   That distinction is the whole batch: a test that only checks "the card is
   visible now" passes against the old centring code too, and would have told
   you nothing.
4. **Does the user's own button still centre?** Tapping „Centriraj na aktivni
   potez" with the card far off puts it in the middle. If that broke, the rule
   was applied to the wrong call site.

## 8. Not in scope

* `chess_backend/` — anything at all.
* `repertoire_build_screen.dart`, `move_tree_widget.dart`,
  `repertoire_tree_panel.dart`, `analysis_studio_screen.dart`. The rule lives in
  one widget and reaches every screen through it. If you believe one of these
  must change, **write in the report which change and why, and stop.**
* The state-loss bug of §2 and §5. Measured, reported, **not fixed** by this
  batch.
* The „fokus na liniju" / „prikaži samo ovu liniju" idea from the same evening's
  reports. That is a different item with its own decisions still open.
* Anything about the board, the banners or the scrolling column. Phase 3 did
  that and it is already merged.

**If you cannot find a file this brief names, stop and say so — do not
substitute the nearest plausible one.**
