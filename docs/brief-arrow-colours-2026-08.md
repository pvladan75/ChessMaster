# Brief: the arrow colours

Written 29.8.2026, for the design agent on `design/gemini-pass`. It is a
follow-on from `dizajn-brief-2026-08.md`, and everything in that file's §4
("Rules that bite") still applies. This one is narrow: **five colours, one new
file, one new test.**

Read the whole thing before editing. §3 is the part that decides whether the
work can be merged at all.

---

## 1. Why this job exists

The project owner is colourblind, and the users are Serbian children — roughly
one boy in twelve has a red-green deficiency. That is not a reason to stop using
colour. It is the reason colour must never be the **only** channel carrying a
meaning, and the reason this is settled with a measurement instead of an
opinion.

On 29.8.2026 the last-move marker was fixed the same way and is the worked
example to copy: it kept its amber, and gained a black-and-white corner bracket
beside it. The colour was not the problem; the colour being *alone* was.

## 2. What the code does today, measured

Every number below came out of `chess_app/test/support/color_vision.dart` — a
Viénot, Brettel & Mollon (1999) dichromat simulation applied in linear RGB. It
is the instrument you will also be measured by. **Recompute all of these
yourself rather than quoting them**; if one of your numbers disagrees with one
of mine, say so in your report, because one of us is wrong and it matters which.

`ChessBoardPainter.arrowPalette` holds five colours, used in two places:

| code | value | user arrows | engine arrows |
|---|---|---|---|
| `R` | `#FF5252` | red | rank 5 |
| `G` | `#00E676` | green | rank 1 (best line) |
| `B` | `#00B0FF` | blue | rank 2 |
| `O` | `#FF9100` | orange | rank 3 |
| `P` | `#E040FB` | purple | rank 4 |

**Finding 1 — two pairs are the same colour to a dichromat, and one pair is
nearly the same colour to everybody.** Worst contrast within each pair, across
normal vision, protanopia and deuteranopia:

- `R`/`P` — **1.04:1** (protanopia). Red and purple are one colour.
- `R`/`B` — 1.07:1 (deuteranopia).
- `B`/`O` — **1.07:1 under normal vision.** This pair is separated by hue alone
  even for a trichromat; it simply has not been noticed.
- Best pair in the whole set: `G`/`P`, and only 2.00:1.

**Finding 2 — every arrow colour vanishes on some square.** Composited at the
0.75 alpha they are drawn with, against the square underneath, worst case across
all five board skins and all three kinds of vision: `R` 1.02, `G` 1.02, `B` 1.04,
`O` 1.12, `P` 1.01. **This one is not yours to fix** — see §4.

**Finding 3 — the engine arrows are much less broken than they look**, and this
is the trap in this task. Rank is already encoded twice: colour *and* stroke
width, `7.0 - (rank - 1) * 1.5`, so the best line is a 7 px arrow and the fifth
is a 1 px one. Green-vs-red for best-vs-worst measures 1.53:1 under
deuteranopia, which sounds alarming and is survivable, because thickness already
says it. **Do not redesign the engine ranks.** If your palette happens to
improve them, good; that is a side effect, not the goal.

The one that has no second channel at all is the **user-drawn** arrow: every one
is 6 px, and colour is the only thing separating a trainer's "danger here" from
their "play here".

## 3. What you may change

**Edit freely — and nothing else:**

- `chess_app/lib/theme/arrow_colors.dart` — **new file, yours.** See §5.
- `chess_app/test/arrow_color_contrast_test.dart` — **new file, yours.**
- `DESIGN-PROPOSALS.md` at the repo root — append a section.

**Off-limits, and each for a specific reason rather than by default:**

- `chess_app/lib/widgets/board_overlay_painter.dart` — the wiring is Claude's,
  and it is the file where a merge conflict would actually cost something.
- `chess_app/lib/widgets/game_screen/arrow_color_button.dart` — same.
- `chess_app/test/support/color_vision.dart` — this is the instrument. If you
  believe it is wrong, say so in your report with the arithmetic; do not edit
  the ruler you are being measured with.
- Everything in `dizajn-brief-2026-08.md` §3's off-limits list, unchanged.

You are **not** expected to make the new colours take effect. Producing a file
nothing imports yet is the correct outcome of this task, and Claude wires it in
afterwards. Say so plainly in your report rather than reaching for the painter
to prove it works.

## 4. What is deliberately not your problem

Three things that a reasonable agent would try to fix and should not, because
they are being fixed structurally on the other side and your palette would be
tuned against a board that is about to change:

1. **Arrow-vs-square visibility (finding 2).** Claude is adding an achromatic
   halo under the arrow stroke — the same two-tone trick as the last-move
   bracket, which guarantees an edge on any square of any skin. So **do not pick
   extreme colours to survive a pale board.** Assume the halo exists and spend
   your whole budget on telling the five apart from each other.
2. **The eval badge is illegible in the light theme.** `badgeTextColor` is
   `context.colors.canvas`, which is near-black in the dark theme (8.8:1, fine)
   and near-white in the light one — rank 1 measures **1.55:1**. That is a real
   bug, it is Claude's, and it is not a palette question: the badge's text has to
   be chosen from the badge's own luminance rather than from the theme.
3. **The `Colors.tealAccent` fallback** in `_getColor` and `_getEngineColor`.
   Claude's.

## 5. What to deliver

**`lib/theme/arrow_colors.dart`** — five colours, in the shape `BoardSkin` and
`PieceSkin` already use in `lib/theme/board_skins.dart`: an `@immutable` class
with a never-translated `id`, a Serbian `name`, the colour, and a `static const`
list plus a `byId` that falls back rather than throws. Read that file first and
match it; it is the house style for exactly this.

Keep the five ids `R`, `G`, `B`, `O`, `P`. They are persisted in saved arrows and
renaming one silently rewrites what a trainer drew.

Keep each colour recognisable as its name. A trainer who picks "crvena" and gets
a brown arrow will file a bug, and the tooltip says the name out loud.

**`test/arrow_color_contrast_test.dart`** — importing `../test/support/
color_vision.dart` and asserting, in loops over the catalogue rather than as a
hand-written list of cases:

- **Every pair, under all three visions, ≥ 1.8:1.** Today's worst is 1.04.
  Before you decide this is arbitrary: with five colours the mathematical
  ceiling is about **2.14:1** between adjacent pairs, because (L + 0.05) spans a
  factor of 21 and 21^(1/4) ≈ 2.14 — and that ceiling assumes pure black to pure
  white, which these cannot be. 1.8 is most of what is achievable and is meant
  to be hard.
- **Each colour against both squares of every board skin, ≥ 3.0:1 for the
  *stroke halo pairing***. You cannot test the halo — it does not exist in your
  allowlist — so instead assert the property the halo needs: that no arrow colour
  sits within 1.2:1 of **both** black and white simultaneously. Any colour that
  does would disappear into its own halo.
- Set every bar by **measuring first**, then writing the number the palette
  already clears. A bar chosen before the measurement is a bar that gets relaxed
  until it passes, which is worse than no bar.

**A report**, per the harness rules. It must state the full 10-pair matrix, all
three visions, as numbers.

## 6. Rules that bite, specific to this task

- **`flutter analyze` must stay at exactly 29 known infos**, all
  `curly_braces_in_flow_control_structures`. Compare the list, not the exit code.
- **The Flutter suite is 881 tests, 1 skipped.** Ending with fewer means
  something stopped running.
- **Run `dart format` on every file you touch.**
- **Serbian names are required here**, not a violation. The `strings` gate has
  failed two batches for adding Serbian strings the brief asked for; it now takes
  a list of files a batch may add strings in, and `lib/theme/arrow_colors.dart`
  must be on it. **Fill that allowance in before launching, not after.**
- **Do not write a contrast number into a comment.** Three untrue contrast claims
  were found on 28.8.2026 and every one of them was a comment. If a number is
  worth stating, it is worth computing in the test.
- **Prove the test by mutation before believing it.** Add a sixth, deliberately
  bad colour, watch the loop catch it, remove it. Batch 46 did this and it is why
  batch 46 was trusted.

## 7. How this gets finished

1. Gemini: this brief → `arrow_colors.dart` + its test + report.
2. Claude: reviews and recomputes every number independently — this has caught
   real problems twice and confirmed the numbers twice.
3. Claude: wires the palette into `board_overlay_painter.dart`, adds the
   achromatic arrow halo, fixes the eval badge, and gives the picker swatch a
   non-colour label so that five circles are not distinguished by colour alone.
4. `docs/TODO-provera.md` gets one item, ticked only after the owner sees it
   running.
