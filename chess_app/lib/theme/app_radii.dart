import 'package:flutter/material.dart';

/// Standard corner radii and shape constants for Mislisha.
///
/// Gives cards, dialogs, buttons, and chips a cohesive, friendly rounded feel
/// without arbitrary per-widget numbers.
abstract final class AppRadii {
  /// 4px. Subtle rounding for small tags or progress indicators.
  static const double xs = 4.0;

  /// 8px. Small rounding for chips, badges, and inner nested items.
  static const double sm = 8.0;

  /// 12px. Medium rounding for buttons, input fields, and compact panels.
  static const double md = 12.0;

  /// 16px. Large rounding for standard cards and action sheets.
  static const double lg = 16.0;

  /// 20px. Extra large rounding for featured hero cards and dialogs.
  static const double xl = 20.0;

  /// 28px. Large modal bottom sheets or floating panels.
  static const double xxl = 28.0;

  /// 999px. Fully rounded pill / capsule shape.
  static const double pill = 999.0;

  // ── Pre-composed BorderRadius constants ──

  static const BorderRadius roundedXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius roundedSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius roundedMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius roundedLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius roundedXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius roundedPill =
      BorderRadius.all(Radius.circular(pill));

  // ── Pre-composed Outlines & Shapes ──

  static const RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
    borderRadius: roundedMd,
  );

  static const RoundedRectangleBorder cardShape = RoundedRectangleBorder(
    borderRadius: roundedLg,
  );

  static const RoundedRectangleBorder dialogShape = RoundedRectangleBorder(
    borderRadius: roundedXl,
  );

  static const RoundedRectangleBorder chipShape = RoundedRectangleBorder(
    borderRadius: roundedPill,
  );
}
