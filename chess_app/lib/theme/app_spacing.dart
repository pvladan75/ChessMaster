import 'package:flutter/widgets.dart';

/// A consistent spacing scale for Mislisha.
///
/// Derived from a 4dp/8dp grid. Using these constants across cards, panels,
/// and dialogs ensures a calm visual rhythm and prevents arbitrary pixel values.
abstract final class AppSpacing {
  /// 2px. Micro spacing (e.g. tight badge padding, border offsets).
  static const double xxs = 2.0;

  /// 4px. Compact spacing between related inline elements or icon-text gaps.
  static const double xs = 4.0;

  /// 8px. Standard small spacing (e.g. chip gaps, list item vertical padding).
  static const double sm = 8.0;

  /// 12px. Medium spacing (e.g. dense card padding, section sub-elements).
  static const double md = 12.0;

  /// 16px. Standard container & card inner padding, row gaps.
  static const double lg = 16.0;

  /// 20px. Comfortable card padding on tablets/desktop, section gaps.
  static const double xl = 20.0;

  /// 24px. Screen margins, major card spacing.
  static const double xxl = 24.0;

  /// 32px. Large section dividers, dialog margins.
  static const double xxxl = 32.0;

  // ── Pre-composed Insets for common layout patterns ──

  /// Standard padding inside a card (16px all sides).
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);

  /// Compact card padding for dense panels (12px all sides).
  static const EdgeInsets cardPaddingCompact = EdgeInsets.all(md);

  /// Generous card padding for featured hubs/desktop (20px all sides).
  static const EdgeInsets cardPaddingComfortable = EdgeInsets.all(xl);

  /// Standard screen content padding (horizontal: 16px, vertical: 12px).
  static const EdgeInsets screenPadding =
      EdgeInsets.symmetric(horizontal: lg, vertical: md);

  /// Child-friendly button padding (horizontal: 20px, vertical: 14px).
  static const EdgeInsets buttonPadding =
      EdgeInsets.symmetric(horizontal: xl, vertical: 14.0);

  /// Compact button padding (horizontal: 14px, vertical: 10px).
  static const EdgeInsets buttonPaddingCompact =
      EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0);
}
