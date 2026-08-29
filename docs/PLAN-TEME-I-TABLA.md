# Plan: app themes, board colours, piece colours

Written 29.8.2026, after the colour-token migration finished (batches 14–44 on
master). It continues the order `DESIGN-PROPOSALS.md` §2 set out — literals
first, light tokens second, the setting last — and adds the board, which that
document only sketched as a proposal (§3, `ChessColorTokens`).

Scope decided by the project owner on 29.8.2026:

- **Themes: light + dark + system.** No extra named palettes.
- **Pieces: recolour, not new art.** No new assets, no `flutter_svg`, no piece
  sets. `chess_vectors_flutter` already takes `fillColor`/`strokeColor`.
- **Board skin is independent of the app theme.** A green board in light mode is
  a legitimate choice and every chess program allows it. The app theme decides
  the panels around the board; the skin decides the board.

---

## What the code actually does today, measured

Four facts decide the whole shape of this work. Each was read out of the source,
not assumed.

**1. Light mode is not merely off — it is a trap.** `AppSettingsService.init()`
hardcodes `_themeMode = ThemeMode.dark` and *overwrites* any stored value, and
the light `ThemeData` in `main.dart` is a bare `ColorScheme.fromSeed(deepPurple)`
carrying **no `AppColorTokens` extension**. `context.colors` therefore falls back
to `AppColorTokens.dark` (`app_colors.dart`, the `?? AppColorTokens.dark` at the
bottom), so every one of the 29 screens would paint dark-theme text on a light
Material scaffold. The force-to-dark in `init()` is not paranoia; it is the only
thing standing between a stored preference and an unreadable app.

**2. Square colours cannot be themed at all.** `flutter_chess_board` 1.0.1 paints
the board with `Image.asset("images/brown_board.png", package:
'flutter_chess_board')` — four baked PNGs (`brown`, `darkBrown`, `green`,
`orange`) chosen by an enum. There is no colour parameter and there will not be
one: the package declares `sdk: ">2.12.0 <3.0.0"` and still calls
`onWillAccept`/`onAccept`. **Board colours require replacing that widget.** No
tint, filter or overlay gets two independently chosen square colours out of one
photograph of a board.

**3. Piece colours are free.** Every class in `chess_vectors_flutter` takes
`fillColor` and `strokeColor` (defaulting to white/black). Nothing passes them:
not the package's `BoardPiece`, not `chessPieceWidget()` in
`board_thumbnail.dart`, not `pieceImageForAnimation()` in
`board_overlay_painter.dart`. Three call sites, twelve constructors, no assets.

**4. One animation is welded to the PNG.** `AnimatedMovePiece` covers the
destination square during a slide by positioning the **board image** at negative
offset inside a clipped square — a sprite-sheet crop
(`board_overlay_painter.dart`, the inner `Stack`). Painted squares have no image
to crop, so that cover becomes "fill this square with its own colour". Miss it
and every animated move ends with the arriving piece drawn over a hole.

A fifth fact is not a blocker but is worth collecting on the way: because the
package renders the board, **dragging** a pawn to the last rank still opens the
package's own dialog — English, `WhiteQueen()` regardless of who is moving. The
app already has the Serbian answer (`askPromotionPiece`, used by every
tap-to-move path) and `promotion_picker.dart` documents the gap in its header.
Replacing the board closes it without a separate task.

---

## Division of labour

The rule that made the last two rounds merge without a single conflict was not
luck: **an agent gets whole files nobody else is editing, and everything else it
has to say goes in a proposal document.** In Flutter a design change and a
behaviour change live in the same widget tree, so two parallel writers on one
screen means one of them is wasted.

So:

| | Owner | Files |
|---|---|---|
| Palette values, contrast measurement, gallery | **Gemini** | `lib/theme/*`, `test/*_contrast_test.dart`, the design gallery |
| Widget trees, settings, persistence, board rendering | **Claude** | `lib/widgets/board/*`, the 5 board call sites, `app_settings_service.dart`, `settings_screen.dart` |

The one shared file is `lib/theme/board_skins.dart`. **Claude writes its API and
one skin; Gemini fills the catalogue.** The API is a widget-layer decision and
the values are a palette decision, and splitting it that way means neither waits
for the other. Gemini rebases onto master before batch 46, which is a
fast-forward: `design/gemini-pass` is fully merged (master is 8 ahead, 0 behind).

---

## Phases, in dependency order

### Phase 1 — the skin API (Claude, master) — **done, `b937af9`**

`lib/theme/board_skins.dart`, new:

```dart
@immutable
class BoardSkin {
  final String id;          // stored in prefs; never translated
  final String name;        // Serbian, shown in Settings
  final Color lightSquare;
  final Color darkSquare;
}

@immutable
class PieceSkin {
  final String id;
  final String name;
  final Color whiteFill, whiteStroke;
  final Color blackFill, blackStroke, blackDecoration;
}
```

Both narrower than the first sketch, and both narrowed by reading the code
rather than by taste:

- **No coordinate colours.** `BoardWithCoordinates` draws its labels in the
  *gutter*, outside the board, from `Theme.of(context).textTheme`. Nothing is
  ever painted on a square, so a skin has nothing to say about it.
- **No highlight colours.** `lastMove`, the drawing-mode tint and the badge text
  are already token-driven at all five call sites (`context.colors.warning`,
  `.accent`, `.canvas`). They are semantic — warning *means* the last move —
  and moving them into the skin would trade a meaning for a decoration. What
  this does create is a measurement nobody has taken: `warning` was chosen to
  read on a dark canvas, and it will now be laid over a pale square in either
  theme. That belongs in batch 46's test, not in the skin.
- **`blackDecoration` is not optional.** Every black piece except the pawn takes
  a third colour in `chess_vectors_flutter` — the knight's eye and mane, the
  king's cross, the rook and queen inlays — defaulting to white. A `PieceSkin`
  without it can only produce silhouettes.

Plus exactly one of each — `BoardSkin.classic` and `PieceSkin.classic` — holding
today's values, so phase 2 is provably a no-op on screen.

Not a `ThemeExtension`, and deliberately so. A `ThemeExtension` is read from the
theme, and the board skin is **not** part of the app theme: it survives a switch
from light to dark, it is chosen separately, and a piece of it (the piece skin)
has to be reachable from a `CustomPainter` that has no `BuildContext`. It is a
plain value looked up by id, handed down like `boardOrientation` already is.

`AppSettingsService` grows `boardSkinId` / `pieceSkinId` (persisted, defaulting
to `classic`) in the same phase, with no UI. Nothing visible changes.

### Phase 2 — the board renders from the skin (Claude) — **done**

`lib/widgets/board/skinned_chess_board.dart`: the ~250 lines of
`flutter_chess_board`'s `ChessBoard`, vendored, with the PNG replaced by painted
squares, the pieces given the skin's fill and stroke, and the promotion dialog
routed to `askPromotionPiece`. Drag-and-drop behaviour is preserved verbatim;
this is not the moment to redesign how a piece is picked up.

**The package stays in `pubspec.yaml`.** `PlayerColor` appears 178 times and
`ChessBoardController` 42 times across 35 files; dropping the dependency means
touching all of them for no gain. Only the rendering widget is replaced —
`ChessBoard(` has 5 call sites.

Also in this phase, because they all draw squares or pieces and would otherwise
disagree with the board:

- `AnimatedMovePiece` — the crop becomes a filled square (fact 4 above).
- `pieceImageForAnimation()` and `chessPieceWidget()` — take the piece skin.
- `BoardThumbnail` (2 literals), `widgets/board_setup_dialog.dart` (2),
  `features/analysis_studio/widgets/board_setup_dialog.dart`.
- `BoardColor` disappears from `lib/` (9 references).

The deliberate-literal count in `lib/` drops from **35 to 29**: the four board
squares and the two `main.dart` seed colours (the latter in phase 3). That
number is documented in `STANJE-RADA.md` and must be updated in the same commit,
or the next person will count 29 and go looking for what was lost.

### Phase 3 — light tokens (Gemini, batch 45) — **done, merged `b4fb881`**

`AppColorTokens.light`, all 30 tokens, and `AppTheme.light` mirroring
`AppTheme.dark` component for component. Registered as `theme:` in `main.dart`,
replacing the seed. **No visible change**, because `themeMode` is still
`ThemeMode.dark` — which is exactly what makes it safe to land before phase 5.

Contrast is asserted by a test that computes it, not by a comment that claims
it. The three untrue contrast claims found on 28.8.2026 were all comments.

### Phase 4 — the skin catalogue (Gemini, batch 46) — after phase 1 lands

Four or five board skins and three or four piece skins, each with measured
numbers, plus `test/board_skin_contrast_test.dart`. The measurement that matters
is not skin-against-panel; it is **every piece skin against every square of
every board skin**. A white piece on a pale board and a black piece on a walnut
board are the two ways this feature fails, and a catalogue of N×M combinations
fails them silently unless something multiplies it out in a loop — a hand-picked
list of cases stops covering the catalogue the moment someone adds to it.

The bar belongs to the **stroke**, not the fill: white fill on the classic light
square is already about 1.3:1 and always has been, because the black outline is
what draws a white piece. Two further numbers the same test owns: fill against
stroke *within* a piece skin (a pair that is too close is a silhouette), and the
theme's `warning` and `accent` over both squares of every skin, which is the
highlight measurement phase 1 declined to move into the skin.

### Phase 5 — the setting (Claude) — after phases 2, 3 and 4

A "Izgled" section in `settings_screen.dart`: theme (Sistem / Svetla / Tamna),
board skin, piece skin, each with a live `BoardThumbnail` preview.
`setThemeMode` persists, and the force-to-dark in `init()` is removed.

**Removing that line resurrects old preferences.** Anyone who chose light or
system before the picker was removed has that value still sitting in
`SharedPreferences` under `app_theme_mode`; the current `init()` stamps it back
to `dark` on every launch. Once it stops, those users land in light mode on
first launch — fine once phase 3 exists, and a white-on-white bug report if this
phase ever merges before it. That is the whole reason for the ordering.

### Phase 6 — watched running (Claude + owner)

Windows build and the phone, both themes, every skin. Specifically:

- **The 14 arrow literals in `board_overlay_painter.dart`** were tuned against a
  brown board on a dark canvas and are the most likely casualty of a pale skin.
  They stay literals by decision; whether they stay *visible* is a measurement
  nobody has taken.
- The golden gallery doubles: dark and light. Note that button labels still
  render as boxes in goldens — `AppText` has no `fontFamily`, a known open item.
- `docs/TODO-provera.md` gets one item per phase, ticked only after the owner
  confirms live.

---

## Risks worth naming up front

**A recoloured piece is not a repainted piece.** `chess_vectors_flutter` draws
each piece as fill + stroke, and some pieces (the knight's eye, the king's
cross) rely on the stroke reading as a line. A piece skin whose fill and stroke
are close collapses into a silhouette. The catalogue test measures fill-vs-stroke
as well as piece-vs-square for that reason.

**The vendored board is a fork, and forks rot.** It is ~250 lines of a package
that has not been updated since Dart 2, so the alternative is depending on code
that already cannot be updated. Vendoring it is the smaller debt, and it buys
the Serbian promotion dialog on drag. It goes in with a header saying where it
came from and what was changed.

**Test counts are gates, not trivia.** 805 Flutter tests / 1 skipped today. Each
phase adds tests; a phase that ends with fewer is a phase that broke something
quietly. `flutter analyze` stays at 29 known infos — compare the list, not the
exit code.

**Do not let a phase report success one layer above where it failed.** The
recurring bug in this codebase, and every phase here has a version of it: a skin
that is stored but never read, a theme that is registered but never selected, a
setting that changes a value nothing paints from. Each phase's test asserts the
*painted* result, not the stored one.
