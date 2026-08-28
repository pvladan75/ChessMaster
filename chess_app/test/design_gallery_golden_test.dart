@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/screens/design_gallery_screen.dart';
import 'package:chess_app/widgets/ai_studio/category_selection_hub.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

Widget _buildThemedApp({required Widget child}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    themeMode: ThemeMode.dark,
    darkTheme: ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColorTokens.dark.brand,
      scaffoldBackgroundColor: AppColorTokens.dark.canvas,
      colorScheme: ColorScheme.dark(
        primary: AppColorTokens.dark.brand,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFF4C1D95),
        onPrimaryContainer: AppColorTokens.dark.brand,
        secondary: AppColorTokens.dark.accent,
        onSecondary: Colors.black,
        secondaryContainer: const Color(0xFF134E4A),
        onSecondaryContainer: AppColorTokens.dark.accent,
        tertiary: AppColorTokens.dark.accentAlt,
        onTertiary: Colors.black,
        error: AppColorTokens.dark.danger,
        onError: Colors.black,
        surface: AppColorTokens.dark.surface,
        onSurface: AppColorTokens.dark.textPrimary,
        onSurfaceVariant: AppColorTokens.dark.textSecondary,
        outline: AppColorTokens.dark.border,
        outlineVariant: AppColorTokens.dark.borderStrong,
      ),
      useMaterial3: true,
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: AppRadii.cardShape,
      ).copyWith(color: AppColorTokens.dark.surface),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColorTokens.dark.surface,
        elevation: 6,
        shape: AppRadii.dialogShape,
        titleTextStyle: AppText.title,
        contentTextStyle: AppText.body,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColorTokens.dark.canvas,
        foregroundColor: AppColorTokens.dark.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.headline,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColorTokens.dark.brand,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 48),
          padding: AppSpacing.buttonPadding,
          shape: AppRadii.buttonShape,
          textStyle: AppText.bodyLargeBold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColorTokens.dark.surfaceRaised,
          foregroundColor: AppColorTokens.dark.textPrimary,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: AppSpacing.buttonPadding,
          shape: AppRadii.buttonShape,
          textStyle: AppText.bodyLargeBold,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColorTokens.dark.textPrimary,
          side: BorderSide(
            color: AppColorTokens.dark.borderStrong,
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
          foregroundColor: AppColorTokens.dark.accent,
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
        backgroundColor: AppColorTokens.dark.surfaceRaised,
        disabledColor: AppColorTokens.dark.surface,
        selectedColor: AppColorTokens.dark.accent.withValues(alpha: 0.2),
        labelStyle: AppText.bodyBold.copyWith(
          color: AppColorTokens.dark.textPrimary,
        ),
        secondaryLabelStyle: AppText.bodyBold.copyWith(
          color: AppColorTokens.dark.textPrimary,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: AppRadii.chipShape,
        side: BorderSide(color: AppColorTokens.dark.border),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColorTokens.dark.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 14.0,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadii.roundedMd,
          borderSide: BorderSide(color: AppColorTokens.dark.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.roundedMd,
          borderSide: BorderSide(color: AppColorTokens.dark.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.roundedMd,
          borderSide: BorderSide(
            color: AppColorTokens.dark.accent,
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.roundedMd,
          borderSide: BorderSide(
            color: AppColorTokens.dark.danger,
            width: 1.5,
          ),
        ),
        hintStyle: AppText.body.copyWith(
          color: AppColorTokens.dark.textMuted,
        ),
        labelStyle: AppText.body.copyWith(
          color: AppColorTokens.dark.textSecondary,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColorTokens.dark.border,
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
          color: AppColorTokens.dark.surfaceRaised,
          borderRadius: AppRadii.roundedSm,
          border: Border.all(color: AppColorTokens.dark.border),
        ),
        textStyle: AppText.caption.copyWith(
          color: AppColorTokens.dark.textPrimary,
        ),
      ),
      extensions: const [AppColorTokens.dark],
    ),
    home: child,
  );
}

/// Load real glyphs before rendering a golden.
///
/// Without this, `flutter test` has no font and every character is drawn as a
/// filled box — the screenshot shows layout and colour and not one letter,
/// which makes it useless as the artefact a design review is supposed to read.
/// The files come from the Flutter SDK itself, located through `FLUTTER_ROOT`
/// (set by `flutter test`), so no path is hardcoded and no package is added.
Future<void> _loadRealFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final fonts = Directory(
    '$root/bin/cache/artifacts/material_fonts',
  );
  if (!fonts.existsSync()) return;

  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final file = File('${fonts.path}/$f');
      if (!file.existsSync()) continue;
      loader.addFont(
        Future.value(file.readAsBytesSync().buffer.asByteData()),
      );
    }
    await loader.load();
  }

  await load('Roboto', ['roboto-regular.ttf', 'roboto-bold.ttf']);
  await load('MaterialIcons', ['materialicons-regular.otf']);
}

void main() {
  setUpAll(_loadRealFonts);

  group('Golden Screenshots', () {
    testWidgets('Gallery - Mobile 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _buildThemedApp(child: const DesignGalleryScreen()),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(DesignGalleryScreen),
        matchesGoldenFile('../../design-screenshots/gallery_phone_360.png'),
      );
    });

    testWidgets('Gallery - Desktop 1200x800', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _buildThemedApp(child: const DesignGalleryScreen()),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(DesignGalleryScreen),
        matchesGoldenFile('../../design-screenshots/gallery_desktop_1200.png'),
      );
    });

    testWidgets('Training Hub - Mobile 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _buildThemedApp(
          child: Scaffold(
            appBar: AppBar(title: const Text('Trening')),
            body: CategorySelectionHubWidget(
              onSelectMatePuzzle: (_) {},
              onSelectBasicMate: (_) {},
              onSelectWinningPosition: () {},
              onSelectTactics: () {},
              onSelectEndgameWin: () {},
              onSelectEndgameDraw: () {},
              onSelectBlunderGames: () {},
              onSelectRepertoire: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
            '../../design-screenshots/training_hub_phone_360.png'),
      );
    });

    testWidgets('Training Hub - Desktop 1200x800', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _buildThemedApp(
          child: Scaffold(
            appBar: AppBar(title: const Text('Trening')),
            body: CategorySelectionHubWidget(
              onSelectMatePuzzle: (_) {},
              onSelectBasicMate: (_) {},
              onSelectWinningPosition: () {},
              onSelectTactics: () {},
              onSelectEndgameWin: () {},
              onSelectEndgameDraw: () {},
              onSelectBlunderGames: () {},
              onSelectRepertoire: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
            '../../design-screenshots/training_hub_desktop_1200.png'),
      );
    });
  });
}
