import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Central theme definitions for the Mislisha app.
abstract final class AppTheme {
  /// Dark theme configuration with token-driven components and WCAG-compliant contrast.
  static ThemeData get dark {
    const colors = AppColorTokens.dark;
    const darkSurfaceText = Color(0xFF0F172A);

    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: colors.brand,
      scaffoldBackgroundColor: colors.canvas,
      colorScheme: ColorScheme.dark(
        primary: colors.brand,
        onPrimary: darkSurfaceText,
        primaryContainer: const Color(0xFF4C1D95),
        onPrimaryContainer: colors.brand,
        secondary: colors.accent,
        onSecondary: darkSurfaceText,
        secondaryContainer: const Color(0xFF134E4A),
        onSecondaryContainer: colors.accent,
        tertiary: colors.accentAlt,
        onTertiary: darkSurfaceText,
        error: colors.danger,
        onError: darkSurfaceText,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        onSurfaceVariant: colors.textSecondary,
        outline: colors.border,
        outlineVariant: colors.borderStrong,
      ),
      useMaterial3: true,
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: AppRadii.cardShape,
      ).copyWith(color: colors.surface),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        elevation: 6,
        shape: AppRadii.dialogShape,
        titleTextStyle: AppText.title.copyWith(color: colors.textPrimary),
        contentTextStyle: AppText.body.copyWith(color: colors.textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.canvas,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.headline.copyWith(color: colors.textPrimary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.brand,
          foregroundColor: darkSurfaceText,
          minimumSize: const Size(48, 48),
          padding: AppSpacing.buttonPadding,
          shape: AppRadii.buttonShape,
          textStyle: AppText.bodyLargeBold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.surfaceRaised,
          foregroundColor: colors.textPrimary,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: AppSpacing.buttonPadding,
          shape: AppRadii.buttonShape,
          textStyle: AppText.bodyLargeBold,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(
            color: colors.borderStrong,
            width: 1.5,
          ),
          minimumSize: const Size(48, 48),
          padding: AppSpacing.buttonPadding,
          shape: AppRadii.buttonShape,
          textStyle: AppText.bodyLargeBold,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accent,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: AppRadii.buttonShape,
          textStyle: AppText.bodyLargeBold,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceRaised,
        disabledColor: colors.surface,
        selectedColor: colors.accent.withValues(alpha: 0.2),
        labelStyle: AppText.bodyBold.copyWith(
          color: colors.textPrimary,
        ),
        secondaryLabelStyle: AppText.bodyBold.copyWith(
          color: colors.textPrimary,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: AppRadii.chipShape,
        side: BorderSide(color: colors.border),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 14.0,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadii.roundedMd,
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.roundedMd,
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.roundedMd,
          borderSide: BorderSide(
            color: colors.accent,
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.roundedMd,
          borderSide: BorderSide(
            color: colors.danger,
            width: 1.5,
          ),
        ),
        hintStyle: AppText.body.copyWith(
          color: colors.textMuted,
        ),
        labelStyle: AppText.body.copyWith(
          color: colors.textSecondary,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        minLeadingWidth: 24,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: AppRadii.roundedSm,
          border: Border.all(color: colors.border),
        ),
        textStyle: AppText.caption.copyWith(
          color: colors.textPrimary,
        ),
      ),
      extensions: const [AppColorTokens.dark],
    );
  }

  /// Light theme configuration with token-driven components and WCAG-compliant contrast.
  static ThemeData get light {
    const colors = AppColorTokens.light;
    const lightSurfaceText = Color(0xFFFFFFFF);

    return ThemeData(
      brightness: Brightness.light,
      primaryColor: colors.brand,
      scaffoldBackgroundColor: colors.canvas,
      colorScheme: ColorScheme.light(
        primary: colors.brand,
        onPrimary: lightSurfaceText,
        primaryContainer: const Color(0xFFF5F3FF),
        onPrimaryContainer: colors.brand,
        secondary: colors.accent,
        onSecondary: lightSurfaceText,
        secondaryContainer: const Color(0xFFCCFBF1),
        onSecondaryContainer: colors.accent,
        tertiary: colors.accentAlt,
        onTertiary: lightSurfaceText,
        error: colors.danger,
        onError: lightSurfaceText,
        surface: colors.surface,
        onSurface: colors.textPrimary,
        onSurfaceVariant: colors.textSecondary,
        outline: colors.border,
        outlineVariant: colors.borderStrong,
      ),
      useMaterial3: true,
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: AppRadii.cardShape,
      ).copyWith(color: colors.surface),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        elevation: 6,
        shape: AppRadii.dialogShape,
        titleTextStyle: AppText.title.copyWith(color: colors.textPrimary),
        contentTextStyle: AppText.body.copyWith(color: colors.textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.canvas,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.headline.copyWith(color: colors.textPrimary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.brand,
          foregroundColor: lightSurfaceText,
          minimumSize: const Size(48, 48),
          padding: AppSpacing.buttonPadding,
          shape: AppRadii.buttonShape,
          textStyle: AppText.bodyLargeBold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.surfaceRaised,
          foregroundColor: colors.textPrimary,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: AppSpacing.buttonPadding,
          shape: AppRadii.buttonShape,
          textStyle: AppText.bodyLargeBold,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(
            color: colors.borderStrong,
            width: 1.5,
          ),
          minimumSize: const Size(48, 48),
          padding: AppSpacing.buttonPadding,
          shape: AppRadii.buttonShape,
          textStyle: AppText.bodyLargeBold,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accent,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: AppRadii.buttonShape,
          textStyle: AppText.bodyLargeBold,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.surfaceRaised,
        disabledColor: colors.surface,
        selectedColor: colors.accent.withValues(alpha: 0.2),
        labelStyle: AppText.bodyBold.copyWith(
          color: colors.textPrimary,
        ),
        secondaryLabelStyle: AppText.bodyBold.copyWith(
          color: colors.textPrimary,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: AppRadii.chipShape,
        side: BorderSide(color: colors.border),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 14.0,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadii.roundedMd,
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.roundedMd,
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.roundedMd,
          borderSide: BorderSide(
            color: colors.accent,
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.roundedMd,
          borderSide: BorderSide(
            color: colors.danger,
            width: 1.5,
          ),
        ),
        hintStyle: AppText.body.copyWith(
          color: colors.textMuted,
        ),
        labelStyle: AppText.body.copyWith(
          color: colors.textSecondary,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        minLeadingWidth: 24,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: AppRadii.roundedSm,
          border: Border.all(color: colors.border),
        ),
        textStyle: AppText.caption.copyWith(
          color: colors.textPrimary,
        ),
      ),
      extensions: const [AppColorTokens.light],
    );
  }
}
