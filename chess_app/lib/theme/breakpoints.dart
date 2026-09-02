import 'package:flutter/widgets.dart';

/// Shared width thresholds for "is there room for a side-by-side layout".
///
/// Before this, home_screen used 800 and chess_game_screen used 900 for what
/// was conceptually the same question, so the same physical window could
/// count as "wide" on one screen and "narrow" on another. [wide] follows
/// Material 3's "expanded" window size class (>= 840dp).
abstract final class Breakpoints {
  static const double wide = 840.0;

  /// Room for a *third* column beside the board and its tree.
  ///
  /// Material 3's expanded class starts at 840, which is two columns: at that
  /// width the board already takes 42% and the tree what is left, so a third
  /// panel would be carved out of a picture that is barely readable. 1200 is
  /// where the tree keeps a usable width with a 320 px panel taken off it —
  /// measured on the repertoire build screen, which is the first screen to want
  /// one, and a desktop window is normally well past it.
  ///
  /// Below this the third panel does not go somewhere smaller; it goes **under
  /// the board**, where the Analysis Studio has always put its comment.
  static const double ultraWide = 1200.0;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wide;

  static bool isUltraWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= ultraWide;
}
