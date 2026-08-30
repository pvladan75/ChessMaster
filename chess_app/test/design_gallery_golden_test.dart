@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/screens/design_gallery_screen.dart';
import 'package:chess_app/widgets/ai_studio/category_selection_hub.dart';
import 'package:chess_app/theme/app_colors.dart';

Widget _buildThemedApp(
    {required Widget child, Brightness brightness = Brightness.dark}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
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

    testWidgets('Gallery - Mobile 360x640 (Light)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _buildThemedApp(
            brightness: Brightness.light, child: const DesignGalleryScreen()),
      );
      await tester.pumpAndSettle();

      // The gallery overrides the ambient theme with its own switch — that is
      // the point of it — so a light shot is taken by pressing the switch, not
      // by handing MaterialApp a light theme it will ignore. It also means
      // this golden fails if the switch stops working.
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(DesignGalleryScreen),
        matchesGoldenFile(
            '../../design-screenshots/gallery_phone_360_light.png'),
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

    testWidgets('Gallery - Desktop 1200x800 (Light)', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _buildThemedApp(
            brightness: Brightness.light, child: const DesignGalleryScreen()),
      );
      await tester.pumpAndSettle();

      // The gallery overrides the ambient theme with its own switch — that is
      // the point of it — so a light shot is taken by pressing the switch, not
      // by handing MaterialApp a light theme it will ignore. It also means
      // this golden fails if the switch stops working.
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(DesignGalleryScreen),
        matchesGoldenFile(
            '../../design-screenshots/gallery_desktop_1200_light.png'),
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
              onSelectMyGames: () {},
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

    testWidgets('Training Hub - Mobile 360x640 (Light)', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _buildThemedApp(
          brightness: Brightness.light,
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
              onSelectMyGames: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
            '../../design-screenshots/training_hub_phone_360_light.png'),
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
              onSelectMyGames: () {},
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

    testWidgets('Training Hub - Desktop 1200x800 (Light)', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _buildThemedApp(
          brightness: Brightness.light,
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
              onSelectMyGames: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile(
            '../../design-screenshots/training_hub_desktop_1200_light.png'),
      );
    });
  });
}
