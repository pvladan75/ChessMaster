import 'package:flutter/material.dart';

/// The colours a trainer picks when drawing an arrow on the board, and the
/// colours the engine uses for its ranked lines.
///
/// Deliberately **not** `AppColorTokens` and not a `ThemeExtension`, for the
/// same reason as `BoardSkin` in `board_skins.dart`: an arrow colour is a
/// domain colour, it survives a switch between the light and dark themes
/// unchanged, and it has to be readable from a `CustomPainter` that has no
/// `BuildContext`. Rule 14 in `.agents/agents/flutter_token_migrator.md` was
/// amended a third time to allow exactly this.
///
/// Chosen by the reader in the arrow picker and stored by [id]; the id is never
/// translated and never renamed, because it is what sits in a saved arrow and a
/// renamed id silently rewrites what a trainer drew.
///
/// ## Why these five values and not the old ones
///
/// The five they replace were `#FF5252`, `#00E676`, `#00B0FF`, `#FF9100` and
/// `#E040FB`, and they failed a measurement taken on 29.8.2026:
///
/// - `R` and `P` measured **1.04:1** under protanopia. Red and purple were one
///   colour, not two.
/// - `B` and `O` measured **1.07:1 under ordinary vision** — that pair had been
///   separated by hue alone for every reader since it was written.
///
/// Under both modelled deficiencies these five collapse onto two hue axes, so
/// every pair has to be separated by **luminance**, which is why the set below
/// is spread from a light green through to a navy rather than being five
/// equally bright colours. That spread is the whole design.
///
/// The bar is **1.5:1 on every pair under every kind of vision**, and 1.5 is
/// not a preference: with five colours held within 20° of their own names, a
/// search of the space puts the ceiling at exactly 1.50. Pushing to 1.77 is
/// possible and costs the names — an earlier attempt reached it with an orange
/// of `#88370E`, which is brown. The separation given up by stopping at 1.5 is
/// made back by the arrow's second channel, not by colour: see the halo in
/// `board_overlay_painter.dart`, the same move as the last-move marker's
/// black-and-white brackets.
///
/// `test/arrow_color_contrast_test.dart` holds every one of those claims.
@immutable
class ArrowColor {
  /// Stored in a saved arrow. Never translated, never renamed.
  final String id;

  /// Shown in the picker's tooltip, in Serbian.
  final String name;

  final Color color;

  const ArrowColor({
    required this.id,
    required this.name,
    required this.color,
  });

  /// Hue 0°, and dark enough to read as red rather than pink. Held below
  /// [o] in hue by the test, because a picker offering "crvena" above
  /// "narandžasta" where the first is the oranger of the two is worse than
  /// either colour being slightly off.
  static const ArrowColor r = ArrowColor(
    id: 'R',
    name: 'Crvena',
    color: Color(0xFFFF2929),
  );

  /// Hue 30°. The old `#FF9100` was already a good orange; it moves only
  /// enough to clear its neighbours by luminance.
  static const ArrowColor o = ArrowColor(
    id: 'O',
    name: 'Narandžasta',
    color: Color(0xFFFF9429),
  );

  /// Hue 120°, and the lightest of the five. Something has to be, and green
  /// survives being light better than red does — a pale red reads as pink.
  static const ArrowColor g = ArrowColor(
    id: 'G',
    name: 'Zelena',
    color: Color(0xFF85FF85),
  );

  /// Hue 230°, and the darkest of the five. Blue is the one colour a dichromat
  /// still sees as its own hue, so it can afford to carry the bottom of the
  /// luminance range.
  static const ArrowColor b = ArrowColor(
    id: 'B',
    name: 'Plava',
    color: Color(0xFF00188F),
  );

  static const ArrowColor p = ArrowColor(
    id: 'P',
    name: 'Ljubičasta',
    color: Color(0xFF910FB3),
  );

  /// Drawn for an id no build recognises — a saved arrow from a newer version,
  /// or one whose colour has since been dropped.
  ///
  /// Deliberately **not** one of the five, and deliberately grey. A fallback
  /// that returns a colour from the vocabulary says something specific and
  /// untrue: green *means* the engine's best line, so an unreadable arrow drawn
  /// green is a lie rather than a default. Grey means nothing, which is the
  /// correct thing for a value that means nothing.
  static const ArrowColor fallback = ArrowColor(
    id: '?',
    name: 'Nepoznata',
    color: Color(0xFF9E9E9E),
  );

  /// Every colour the picker offers, in the order it offers them.
  /// [fallback] is not among them: it is drawn, never chosen.
  static const List<ArrowColor> all = [r, o, g, b, p];

  /// Falls back rather than throws: an id can come from a saved arrow written
  /// by a newer build. That is not a reason to fail to draw a board.
  static ArrowColor byId(String? id) {
    for (final arrowColor in all) {
      if (arrowColor.id == id) return arrowColor;
    }
    return fallback;
  }
}
