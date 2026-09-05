# Brief — the board stays, the rest scrolls

Phase 3 of `docs/PLAN-TABLA-I-STABLO.md`. Flutter only, in `chess_app/`.
**`chess_backend/` is not touched by this batch at all** — no endpoint, no
request, no field.

## 1. Why this exists

The owner's report of 5.9.2026, 08:35, with a screenshot:

> „Tabla sa navigacionom paletom ispod se skrolovanjem ne vidi, treba da bude
> statična, a da se pomera samo ono što je ispod. Na slici je ono što je iznad
> table, možda da se izbaci ili pomeri taj deo kako bi se povećao prostor ispod
> table."

He builds a repertoire by looking at the board and answering the question
underneath it. Today the whole column scrolls as one, so reading the question
scrolls the board off the top — and the board is the thing the question is
about.

## 2. What the screen looks like today

`lib/features/repertoire/screens/repertoire_build_screen.dart`,
`_buildBoardColumn` (around line 2670) is **one `SingleChildScrollView` around
one `Column`**, whose children in order are:

1. `OpeningBanner` — the opening's name.
2. `UnconfirmedBanner` — „N nepotvrđenih u grafu" plus its button.
3. `Center(BoardWithCoordinates(...))` — the board.
4. …the navigation strip, `_buildNavigation(context)`.
5. …then everything else: the comment panel, the question, the answers, the
   verdict, the kept moves, the book.

It is reached from a `LayoutBuilder` (around line 2551) on two paths — narrow,
where it is the whole screen, and wide, where the tree sits beside it and
`commentBeside: true` is passed. **Both paths must get the new behaviour**; it
is one method and the complaint applies to both.

## 3. What to build

`Column[ fixed header, Expanded(SingleChildScrollView(the rest)) ]`.

* **The fixed header** is children 1–4 above: both banners, the board, and the
  navigation strip. They do not move when the region below is scrolled.
* **The scrolling region** is everything from child 5 down, and it keeps the
  padding the column has today.

The restructure itself is a few lines. **It is not the work.** §4 is.

## 4. The real work: `boardSize` must know the height

`_boardSize(BoxConstraints constraints, bool wide)` (around line 2614) today:

```dart
double _boardSize(BoxConstraints constraints, bool wide) {
  if (!wide) return (constraints.maxWidth - 24).clamp(200.0, 420.0);
  final byWidth = (constraints.maxWidth * 0.42).clamp(420.0, 620.0) - 24;
  final byHeight =
      constraints.maxHeight.isFinite ? constraints.maxHeight - 280 : byWidth;
  final smaller = byWidth < byHeight ? byWidth : byHeight;
  return smaller.clamp(200.0, 560.0);
}
```

**The wide branch already clamps by height. The narrow branch does not** — it is
width alone. Its own doc comment gives the reason the wide branch has it:

> „Wide, it grows — but never past what the height allows, or the question below
> it goes off the bottom, which is the one thing worse than a small board."

That reasoning is exactly what pinning the board makes true of a phone as well.
Today the board can scroll partly off-screen and the user scrolls it back. Pin
it, and a board sized by width alone either clips or leaves the scrolling region
with nothing in it.

So: **the narrow branch must clamp by the available height too**, the same shape
as the wide one. What is subtracted is the fixed header's own cost — the two
banners plus the navigation strip — plus a floor for the scrolling region, so
something is always visible below the board to say there is more.

**Do not hard-code the header's height as a constant you measured once.** A
banner that is not shown costs nothing, `UnconfirmedBanner` returns
`SizedBox.shrink()` at `total == 0`, and the strip's height depends on the
theme. Derive it, or lay it out and measure it — but do not paste 134.

## 5. The banner, and the numbers it must beat

The owner's decision of 5.9.2026:

> „Baner sažmi u jedan kompaktan red u ravni sa dugmetom, da ne gura tablu
> nadole."

**Measured on master, 5.9.2026**, `UnconfirmedBanner` with `total: 5`, the full
widget in a `Column`:

| viewport width | banner height today |
|---|---|
| 360 dp | **134 px** |
| 500 dp | 115 px |
| 900 dp | 78 px |

134 px is a fifth of a 640 px screen, spent above the board, before anything is
asked. That is the complaint.

**Two facts from the same measurement, so you do not chase the wrong thing:**

* The sentence is inside an `Expanded`, so **shortening the sentence changes
  nothing**. It was measured: „5 nepotvrđenih" and „5 nepotvrđenih u grafu"
  give an identical width. Only the fixed items cost anything.
* At 360 dp the banner deliberately stacks into two rows, and the reason is
  written in the file: with the button on the same row it overflows a 360 dp
  phone. **You may not make it one row at 360 by shortening any string.**

So compress what is not a string: the vertical padding, the bottom margin, the
speaker's tap target and the button's. `visualDensity` and `minimumSize` on the
`OutlinedButton`, a denser icon button for the speaker.

**Targets, and they are the gate:**

* **≤ 96 px at 360 dp** (from 134).
* **≤ 64 px at 900 dp** (from 78).
* No overflow at any width from 320 dp up.

Those numbers come from the reductions named above and today's measurements. If
you cannot reach them **without changing a single user-facing string**, report
the number you did reach and stop. Do not shorten „Pregledaj nepotvrđene".

## 6. What must not change

* **Any user-facing string.** Not the button's label, not the sentence, not the
  tooltip. This app's strings are Serbian and settled; a new one fails the batch.
* **`visual_move_tree_widget.dart` and `move_tree_widget.dart`.** Another batch
  owns those files in a parallel worktree. Touching them fails this one.
* The wide layout's structure — the tree beside the board, `commentBeside`, the
  three-column arrangement. The header/scroll split applies inside the board
  column; the columns around it stay as they are.
* `ScaffoldMessenger` must not be called. `AppFeedback` only —
  `test/app_feedback_guard_test.dart` fails on a raw call.
* The board's orientation, its controller, and everything about what it does.
  This is layout, not behaviour.

## 7. How it will be judged

New file `test/repertoire_board_sticky_test.dart`, pumping the real build
screen. Every one of these is a size or a rect, which is why this batch is
gradeable at all:

1. **At 360×640, 360×740 and 900×800**: the board is fully inside the viewport,
   and so is the navigation strip. Assert on rects, not on „finds one widget".
2. **The board does not move when the lower region scrolls.** Take the board's
   rect, fling the scrolling region, pump, take it again — identical.
3. **There is something to scroll.** After the header, the remaining region has
   a non-zero height at all three sizes. A layout that pins everything and
   leaves nothing below is the failure mode this test exists for.
4. **No overflow at any of the three sizes.** In a test build an overflowing
   `Row` or `Column` throws; in a release build it is silently clipped, which is
   why this is a widget test and not a look at a phone.
5. **The banner's height** is ≤ 96 at 360 dp and ≤ 64 at 900 dp, measured on
   `UnconfirmedBanner` itself.
6. **The banner's button is still hittable at 360 dp** — tap it and assert the
   callback fired.

**Prove tests 2 and 3 by mutation.** Put the whole column back inside one
`SingleChildScrollView` and watch test 2 fail; give the board the full height
and watch test 3 fail. Report which test failed and the message. A guard nobody
has watched fail is not a guard, and this project has shipped two that did not
guard.

## 8. The rules of this codebase that bite here

* `flutter test` on the branch **before you change anything**. Measure it
  yourself and report it; do not trust a number quoted at you. It should be
  **1212 passing, 1 skipped**. Lower means something is wrong before you start —
  stop and report.
* `flutter analyze` must stay at **29** issues, every one `info`, every one
  `curly_braces_in_flow_control_structures`. **Compare the list, not the exit
  code** — it has exited 1 for a long time and that is the normal state.
* **`dart format` every Dart file you touch, last.**
* A release build paints no overflow warning: a `Row` wider than the screen is
  simply clipped and the buttons past the edge are unreachable. Three of those
  have been found on this project by looking at a phone. Where a row can grow,
  `Wrap`; where a width is fixed, take it from `MediaQuery`.
* Golden tests are skipped unconditionally; `--tags golden` alone still skips
  them and the run exits 0 saying „All tests skipped". Do not grade yourself on
  them.
* If a file this brief names is **not there**, stop and say so. Do not
  substitute the nearest plausible one.
