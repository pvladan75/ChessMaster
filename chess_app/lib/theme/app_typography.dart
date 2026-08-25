import 'package:flutter/material.dart';

/// A named type scale distilled from how the app already sizes text (see the
/// frequency audit in the P2 commit: 10/11/12/13/14/16/18/22 cover the large
/// majority of usages). Pulling them behind names doesn't change how anything
/// looks — it stops every panel from picking its own ad hoc pixel size and
/// gives future screens a scale to reach for instead of a fresh guess.
///
/// These are deliberately plain `TextStyle` constants, not a `TextTheme` —
/// most call sites need a one-off color override (per-state, per-eval-sign,
/// etc.), which `.copyWith(color: ...)` on a const style handles directly.
abstract final class AppText {
  /// 10px. Tiny badges and dense inline chips — use sparingly.
  static const TextStyle micro = TextStyle(fontSize: 10);

  /// 11px. The app's most common size: secondary labels, panel metadata.
  static const TextStyle caption = TextStyle(fontSize: 11);
  static const TextStyle captionBold =
      TextStyle(fontSize: 11, fontWeight: FontWeight.bold);

  /// 12px. Default body text within cards and panels.
  static const TextStyle body = TextStyle(fontSize: 12);
  static const TextStyle bodyBold =
      TextStyle(fontSize: 12, fontWeight: FontWeight.bold);

  /// 13px. Slightly emphasized body — list tile titles, active values.
  static const TextStyle bodyLarge = TextStyle(fontSize: 13);
  static const TextStyle bodyLargeBold =
      TextStyle(fontSize: 13, fontWeight: FontWeight.bold);

  /// 14px. Sub-headings within a card.
  static const TextStyle subtitle =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

  /// 16px. Section/dialog titles.
  static const TextStyle title =
      TextStyle(fontSize: 16, fontWeight: FontWeight.bold);

  /// 18px. Screen-level headings.
  static const TextStyle headline =
      TextStyle(fontSize: 18, fontWeight: FontWeight.bold);

  /// 22-24px. Rare — top-level numbers/avatars initials.
  static const TextStyle display =
      TextStyle(fontSize: 22, fontWeight: FontWeight.bold);
}
