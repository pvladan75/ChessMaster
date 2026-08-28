import 'package:flutter/material.dart';

export 'app_spacing.dart';
export 'app_radii.dart';

/// Named color roles for the app's dark UI, registered as a [ThemeExtension]
/// so screens read `context.colors.X`.
///
/// Every foreground color is calibrated against the three dark surfaces
/// (canvas #0F172A, surface #1E293B, surfaceRaised #334155) to guarantee WCAG AA
/// compliance (>= 4.5:1 for body text, >= 3.0:1 for large text/icons and UI elements).
/// Exact measured contrast ratios are documented beside each token.
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
    // Surfaces
    canvas: Color(0xFF0F172A), // Slate 900 (relative luminance = 0.0080)
    surface: Color(0xFF1E293B), // Slate 800 (relative luminance = 0.0218)
    surfaceRaised: Color(0xFF334155), // Slate 700 (relative luminance = 0.0527)

    // Structure
    border: Color(0x1FFFFFFF), // 12% white overlay for subtle boundaries
    borderStrong: Color(0x3DFFFFFF), // 24% white overlay for focused boundaries

    // Text (measured contrast on canvas / surface / surfaceRaised)
    // #F8FAFC: 17.06:1 / 13.98:1 / 9.90:1 (WCAG AAA)
    textPrimary: Color(0xFFF8FAFC),
    // #CBD5E1: 12.02:1 / 9.85:1 / 6.97:1 (WCAG AAA / AA)
    textSecondary: Color(0xFFCBD5E1),
    // #94A3B8: 6.96:1 / 5.71:1 / 4.04:1 (WCAG AA on canvas & surface; >=3:1 UI on raised)
    textMuted: Color(0xFF94A3B8),

    // Semantic accents
    // #2DD4BF (Teal 400 - Engine, active interactive state):
    // Contrast: 9.59:1 on canvas / 7.86:1 on surface / 5.56:1 on surfaceRaised (WCAG AA)
    accent: Color(0xFF2DD4BF),

    // #C084FC (Purple 400 - Variations, alternative moves, secondary branches):
    // Contrast: 6.76:1 on canvas / 5.54:1 on surface / 3.92:1 on surfaceRaised (WCAG AA)
    accentAlt: Color(0xFFC084FC),

    // #A78BFA (Violet 400 - Mislisha platform brand identity):
    // Contrast: 6.56:1 on canvas / 5.38:1 on surface / 3.80:1 on surfaceRaised (WCAG AA)
    brand: Color(0xFFA78BFA),

    // #38BDF8 (Sky 400 - Information, hints):
    // Contrast: 8.33:1 on canvas / 6.83:1 on surface / 4.83:1 on surfaceRaised (WCAG AA)
    info: Color(0xFF38BDF8),

    // #FBBF24 (Amber 400 - Warnings, blunder alerts):
    // Contrast: 10.69:1 on canvas / 8.76:1 on surface / 6.20:1 on surfaceRaised (WCAG AA)
    warning: Color(0xFFFBBF24),

    // #FB7185 (Rose 400 - Errors, lost position, invalid moves):
    // Contrast: 6.63:1 on canvas / 5.44:1 on surface / 3.85:1 on surfaceRaised (WCAG AA)
    danger: Color(0xFFFB7185),

    // #4ADE80 (Green 400 - Correct moves, solved puzzles, victories; distinct from Teal accent):
    // Contrast: 10.25:1 on canvas / 8.40:1 on surface / 5.94:1 on surfaceRaised (WCAG AA)
    success: Color(0xFF4ADE80),
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
  AppColorTokens get colors =>
      Theme.of(this).extension<AppColorTokens>() ?? AppColorTokens.dark;
}
