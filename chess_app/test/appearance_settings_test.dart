import 'package:flutter/material.dart';
// The package's barrel re-exports `package:chess`, whose `Color` enum would
// otherwise shadow Flutter's.
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/settings_screen.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/board_skins.dart';
import 'package:chess_app/widgets/board/chess_piece_image.dart';
import 'package:chess_app/widgets/board/skinned_chess_board.dart';

/// Phase 5 of `docs/PLAN-TEME-I-TABLA.md`: the picker.
///
/// Every assertion here is about what gets **painted** after a tap, never about
/// what got stored. A setting that writes a value nothing draws from is the
/// recurring bug in this codebase — a step that skips silently, reports success
/// and fails one layer later — and a test that reads the value back out of the
/// service would pass for exactly that bug.
void main() {
  final session = UserSession(
    token: 't',
    id: 1,
    email: 'a@b.c',
    name: 'Trener',
    role: 'korisnik',
  );

  /// The settings screen under a `MaterialApp` wired the way `main.dart` wires
  /// it: both themes registered, the mode read from the service, the whole
  /// thing rebuilt when the service notifies. Anything less would test the
  /// harness rather than the app.
  Future<void> pumpSettings(WidgetTester tester) async {
    // A phone, because that is where a row too wide to fit gets clipped in
    // release and throws in a test.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(AnimatedBuilder(
      animation: AppSettingsService.instance,
      builder: (context, _) => MaterialApp(
        themeMode: AppSettingsService.instance.themeMode,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: SettingsScreen(session: session),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// `ensureVisible`, not `scrollUntilVisible`: the whole card is one widget,
  /// so the label is already in the tree — a thousand pixels below the fold —
  /// and a finder-based scroll stops before it has scrolled at all.
  ///
  /// `.first` because two catalogues legitimately hold a skin called "Visoki
  /// kontrast", one board and one set of pieces.
  Future<void> tapChoice(WidgetTester tester, String label) async {
    final target = find.text(label).first;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(
          body: Center(child: SizedBox(width: 400, height: 400, child: child)),
        ),
      );

  group('the stored theme mode is read rather than overwritten', () {
    // Until 29.8.2026 `init()` assigned ThemeMode.dark and wrote 'dark' back
    // over whatever was there, because the light ThemeData carried no
    // AppColorTokens and "Svetla" meant dark-theme text on a light scaffold.
    // AppTheme.light exists now (batch 45), so these three cases are the
    // preferences that come back to life.
    for (final (stored, expected) in const [
      ('light', ThemeMode.light),
      ('system', ThemeMode.system),
      ('dark', ThemeMode.dark),
    ]) {
      test('"$stored" comes back as $expected', () async {
        SharedPreferences.setMockInitialValues({'app_theme_mode': stored});
        await AppSettingsService.instance.init();
        expect(AppSettingsService.instance.themeMode, expected);
        // And it is still there afterwards: an init that normalises the key is
        // an init that eats the choice it was asked to read.
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('app_theme_mode'), stored);
      });
    }

    test('nothing stored is dark, and stays unwritten', () async {
      SharedPreferences.setMockInitialValues({});
      await AppSettingsService.instance.init();
      expect(AppSettingsService.instance.themeMode, ThemeMode.dark);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_theme_mode'), isNull,
          reason: 'a default is not a choice and must not be written as one');
    });

    test('a value from some other build falls back to dark', () async {
      SharedPreferences.setMockInitialValues({'app_theme_mode': 'sepia'});
      await AppSettingsService.instance.init();
      expect(AppSettingsService.instance.themeMode, ThemeMode.dark);
    });

    test('what the setter writes is what init reads back', () async {
      SharedPreferences.setMockInitialValues({});
      await AppSettingsService.instance.init();
      for (final mode in ThemeMode.values) {
        await AppSettingsService.instance.setThemeMode(mode);
        await AppSettingsService.instance.init();
        expect(AppSettingsService.instance.themeMode, mode);
      }
    });
  });

  group('the picker changes what is painted', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AppSettingsService.instance.init();
    });

    testWidgets('choosing Svetla puts the light tokens under the screen',
        (tester) async {
      // Compared field by field rather than by identity: `Theme` animates
      // between two `ThemeData`s and hands out a *lerped* `AppColorTokens`
      // while it does, so the instance under the screen is never the constant
      // even once it has settled on its values.
      void expectTokens(AppColorTokens expected, Brightness brightness) {
        final context = tester.element(find.byType(SettingsScreen));
        expect(Theme.of(context).brightness, brightness);
        final tokens = context.colors;
        expect(tokens.canvas, expected.canvas);
        expect(tokens.surface, expected.surface);
        expect(tokens.textPrimary, expected.textPrimary);
        expect(tokens.border, expected.border);
      }

      await pumpSettings(tester);

      // The screen opens dark, which is what an install with no stored choice
      // has always looked like.
      expectTokens(AppColorTokens.dark, Brightness.dark);

      await tapChoice(tester, 'Svetla');
      // The tokens, not just the Material brightness: every screen in this app
      // paints from `context.colors`, and the whole reason the picker was
      // removed in the first place was a light theme that carried the dark
      // tokens — `?? AppColorTokens.dark` at the bottom of `app_colors.dart`
      // makes that failure silent.
      expectTokens(AppColorTokens.light, Brightness.light);

      await tapChoice(tester, 'Tamna');
      expectTokens(AppColorTokens.dark, Brightness.dark);
    });

    testWidgets('choosing a board repaints the board every screen draws',
        (tester) async {
      await pumpSettings(tester);
      await tapChoice(tester, 'Zelena');

      // Not "is the id stored" — is the live board green. `SkinnedChessBoard`
      // with no override is what the five board screens build.
      await tester.pumpWidget(
          wrap(SkinnedChessBoard(controller: ChessBoardController())));
      expect(
        find.byType(SkinnedChessBoard),
        paints
          ..rect(color: BoardSkin.green.lightSquare)
          ..rect(color: BoardSkin.green.darkSquare),
      );
    });

    testWidgets('choosing pieces repaints the pieces every screen draws',
        (tester) async {
      await pumpSettings(tester);
      await tapChoice(tester, 'Tople');

      // `chessPieceWidget` with no override is the one place a piece becomes a
      // widget — the board, the animation, both editors, the thumbnails.
      final pawn = chessPieceWidget('P') as WhitePawn;
      expect(pawn.fillColor, PieceSkin.warm.whiteFill);
      expect(pawn.strokeColor, PieceSkin.warm.whiteStroke);

      final knight = chessPieceWidget('n') as BlackKnight;
      expect(knight.decorationColor, PieceSkin.warm.blackDecoration);
    });

    testWidgets('the board keeps its skin across a change of theme',
        (tester) async {
      // The one thing the plan is explicit about: a skin is a taste, not a
      // palette. A green board in the light theme is a legitimate choice.
      await pumpSettings(tester);
      await tapChoice(tester, 'Plava');
      await tapChoice(tester, 'Svetla');

      await tester.pumpWidget(
          wrap(SkinnedChessBoard(controller: ChessBoardController())));
      expect(
        find.byType(SkinnedChessBoard),
        paints..rect(color: BoardSkin.blue.lightSquare),
      );
    });

    testWidgets('every skin in both catalogues is offered', (tester) async {
      await pumpSettings(tester);

      // A catalogue that grows and a picker that does not is the silent half
      // of this feature: the skin exists, is measured by the contrast test,
      // and is unreachable.
      for (final skin in BoardSkin.all) {
        expect(find.text(skin.name), findsWidgets, reason: skin.id);
      }
      for (final skin in PieceSkin.all) {
        expect(find.text(skin.name), findsWidgets, reason: skin.id);
      }
      for (final name in AppSettingsService.kThemeModeNames.values) {
        expect(find.text(name), findsWidgets, reason: name);
      }
    });

    testWidgets('the card lays out on a 360 dp phone in both themes',
        (tester) async {
      // In a release build an overflowing Row is silently clipped; in a test
      // build it throws. That asymmetry is why this test exists at all.
      await pumpSettings(tester);
      await tester.ensureVisible(find.text('Boja table:'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tapChoice(tester, 'Svetla');
      expect(tester.takeException(), isNull);
    });
  });
}
