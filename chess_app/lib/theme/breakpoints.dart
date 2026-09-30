import 'package:flutter/widgets.dart';

/// Shared width thresholds for "is there room for a side-by-side layout".
///
/// Before this, home_screen used 800 and chess_game_screen used 900 for what
/// was conceptually the same question, so the same physical window could
/// count as "wide" on one screen and "narrow" on another. [wide] follows
/// Material 3's "expanded" window size class (>= 840dp).
abstract final class Breakpoints {
  static const double wide = 840.0;

  /// Room in the app bar for a second line of text beside the title — the
  /// repertoire build screen's opening name, which overflowed the bar at 900.
  ///
  /// It was first the width for a *third* column beside the board and its
  /// tree, the repertoire's comment. That column went on 30.9.2026, and the
  /// question of how many columns fit beside a board is now asked of the
  /// board's own size (`RepertoireLayout`), not of a fixed width.
  static const double ultraWide = 1200.0;

  /// Material 3's compact height class: below this a window is too short for
  /// anything but the board beside its panels. Every phone held sideways is
  /// under it (360–430 dp); a tablet on its side is not.
  static const double compactHeight = 480.0;

  /// Material 3's compact *width* class: a phone held upright. Every row that
  /// has to fit the screen's whole width is tight here — 360 dp is the common
  /// case and the one the overflow reports keep coming from.
  static const double compactWidth = 600.0;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wide;

  static bool isUltraWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= ultraWide;
}
