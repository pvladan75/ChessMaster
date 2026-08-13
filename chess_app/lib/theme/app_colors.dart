import 'package:flutter/material.dart';

/// Named color roles for the app's (currently dark-only) UI, registered as a
/// [ThemeExtension] so screens read `context.colors.X` instead of scattering
/// `Colors.tealAccent` / `Colors.grey.shade900` literals everywhere.
///
/// [dark] intentionally reuses the exact literals already in use across the
/// app (see the frequency audit in the P2 commit) — this is a naming pass,
/// not a repaint. Values only diverge from what a screen already used when
/// that screen is migrated to read the token instead of its own literal.
@immutable
class AppColorTokens extends ThemeExtension<AppColorTokens> {
  // Surfaces, darkest to lightest.
  final Color canvas; // behind panels — trees, graphs, code-style views
  final Color surface; // default card/panel background
  final Color surfaceRaised; // a step lighter — headers, selected rows

  // Structure.
  final Color border;
  final Color borderStrong;

  // Text.
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // Semantic accents.
  final Color accent; // primary interactive accent (engine, active state)
  final Color accentAlt; // secondary accent (variations, alt branches)
  final Color brand; // app-identity accent (distinct from "accent")
  final Color info;
  final Color warning;
  final Color danger;
  final Color success;

  const AppColorTokens({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentAlt,
    required this.brand,
    required this.info,
    required this.warning,
    required this.danger,
    required this.success,
  });

  static const AppColorTokens dark = AppColorTokens(
    canvas: Colors.black,
    surface: Color(0xFF212121), // Colors.grey.shade900
    surfaceRaised: Color(0xFF1E293B),
    border: Colors.white24,
    borderStrong: Colors.white38,
    textPrimary: Colors.white,
    textSecondary: Colors.white70,
    textMuted: Colors.white54,
    accent: Colors.tealAccent,
    accentAlt: Colors.purpleAccent,
    brand: Colors.deepPurpleAccent,
    info: Colors.lightBlueAccent,
    warning: Colors.amberAccent,
    danger: Colors.redAccent,
    success: Colors.greenAccent,
  );

  @override
  AppColorTokens copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceRaised,
    Color? border,
    Color? borderStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? accentAlt,
    Color? brand,
    Color? info,
    Color? warning,
    Color? danger,
    Color? success,
  }) {
    return AppColorTokens(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
      accentAlt: accentAlt ?? this.accentAlt,
      brand: brand ?? this.brand,
      info: info ?? this.info,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      success: success ?? this.success,
    );
  }

  @override
  AppColorTokens lerp(ThemeExtension<AppColorTokens>? other, double t) {
    if (other is! AppColorTokens) return this;
    return AppColorTokens(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentAlt: Color.lerp(accentAlt, other.accentAlt, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      info: Color.lerp(info, other.info, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

/// `context.colors.accent` instead of `Theme.of(context).extension<AppColorTokens>()!.accent`.
extension AppColorTokensX on BuildContext {
  AppColorTokens get colors => Theme.of(this).extension<AppColorTokens>() ?? AppColorTokens.dark;
}
