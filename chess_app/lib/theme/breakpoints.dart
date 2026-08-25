import 'package:flutter/widgets.dart';

/// Shared width thresholds for "is there room for a side-by-side layout".
///
/// Before this, home_screen used 800 and chess_game_screen used 900 for what
/// was conceptually the same question, so the same physical window could
/// count as "wide" on one screen and "narrow" on another. [wide] follows
/// Material 3's "expanded" window size class (>= 840dp).
abstract final class Breakpoints {
  static const double wide = 840.0;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wide;
}
