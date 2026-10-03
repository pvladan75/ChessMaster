// The gate of phase 9 of docs/PLAN-EKRANI.md: My games and Import games as the
// owner chose from `docs/skice/ekrani/compare_games.png` and
// `compare_import.png`.
//
// My games: the players' cards in columns on a window (`AdaptiveCardGrid`,
// rule R7), each card's three doors quiet text buttons of one kind (R4 —
// today two are filled and one is not), and „Import games" in the bar.
// Import games: one centred column of reading width instead of a field the
// width of the window, „Select PGN file" the one filled button, and the
// finished import said in its result card rather than a snackbar (R3), its
// doors text buttons.
//
// The app's own theme with real Roboto, as phase 1 taught.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/archive/models/archive_run.dart';
import 'package:chess_app/features/archive/models/archive_subject.dart';
import 'package:chess_app/features/archive/screens/archive_home_screen.dart';
import 'package:chess_app/features/archive/screens/archive_import_screen.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/theme/app_theme.dart';
import 'package:chess_app/widgets/adaptive_card_grid.dart';

import 'features/archive/archive_import_screen_test.dart'
    show FakeArchiveApiService;
import 'support/landscape.dart';
import 'support/render_look.dart';

const _window = Size(1536, 792);
const _phone = Size(360, 640);

const _doors = [
  'View opening leaks',
  'Repertoire from games',
  'Profile and habits'
];

class _Api extends FakeArchiveApiService {
  @override
  Future<List<ArchiveSubject>> getSubjects() async => [
        for (final (name, games) in [
          ('pvladan', 4126),
          ('anapetrovic_sah', 1873),
          ('markoilic07', 962),
          ('jelena_m', 640),
          ('magnuscarlsen', 5210),
          ('nikola_dj', 305),
        ])
          ArchiveSubject(
              subject: name, games: games, reachedTablebase: 0, withClocks: 0),
      ];

  @override
  Future<List<ArchiveRun>> listImports() async => [
        const ArchiveRun(
          id: 1,
          source: 'lichess',
          subject: 'pvladan',
          status: 'done',
          gamesRead: 4126,
          gamesStored: 3880,
          gamesDuplicate: 214,
          gamesSkipped: 32,
          skippedByReason: {},
          startedAt: '2026-10-02',
        ),
      ];
}

Finder _button<T extends Widget>(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is T),
    );

Finder _inBar(Finder f) =>
    find.descendant(of: find.byType(AppBar), matching: f);

Future<void> _pumpGames(WidgetTester tester, Size size) async {
  ArchiveApiService.setMock(_Api());
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: robotoTheme(AppTheme.dark),
    home: ArchiveHomeScreen(key: UniqueKey()),
  ));
  await tester.pumpAndSettle();
}

Future<void> _pumpImport(WidgetTester tester, Size size) async {
  ArchiveApiService.setMock(FakeArchiveApiService());
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('miguelruivo.flutter.plugins.filepicker'),
    (call) async => [
      {'name': 'games.pgn', 'path': '/games.pgn', 'size': 100, 'bytes': null}
    ],
  );
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('miguelruivo.flutter.plugins.filepicker'), null));
  await tester.pumpWidget(MaterialApp(
    theme: robotoTheme(AppTheme.dark),
    home: ArchiveImportScreen(key: UniqueKey()),
  ));
  await tester.pumpAndSettle();
}

/// Types a name, picks a file, and lets the poll see the import done.
Future<void> _import(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), 'pvladan');
  expect(find.text('Select PGN file'), findsOneWidget);
  await tester.tap(find.text('Select PGN file'));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadRoboto);

  group('My games', () {
    testWidgets(
        'on a window: the cards in columns, the doors text buttons, Import '
        'games in the bar', (tester) async {
      await _pumpGames(tester, _window);
      expect(tester.takeException(), isNull);
      // Either half of pattern A will do; what matters is columns and no air.
      // Widened at grading (3.10.2026): the grid's one cell height left every
      // card some 70 px of empty band under its doors — 3a's fault again.
      expect(
          find.byType(AdaptiveCardGrid).evaluate().length +
              find.byType(AdaptiveCardRows).evaluate().length,
          1);
      final first = tester.getRect(find.text('pvladan'));
      final second = tester.getRect(find.text('anapetrovic_sah'));
      expect(second.top, closeTo(first.top, 1),
          reason: 'two cards on one row: the width is used (R7)');
      for (final door in _doors) {
        expect(_button<TextButton>(door), findsNWidgets(6), reason: door);
        expect(_button<FilledButton>(door), findsNothing, reason: door);
      }
      expect(_inBar(find.text('Import games')), findsOneWidget);
      // No empty band: the last door sits near its card's bottom edge.
      final door = find.text('Profile and habits').first;
      final card = find.ancestor(of: door, matching: find.byType(Card)).first;
      expect(tester.getRect(card).bottom - tester.getRect(door).bottom,
          lessThan(40),
          reason: 'a card as tall as what it holds, not a fixed cell');
    });

    testWidgets('on a 360 dp phone: nothing overflows, Import games in the bar',
        (tester) async {
      await _pumpGames(tester, _phone);
      expect(tester.takeException(), isNull);
      expect(_inBar(find.text('Import games')), findsOneWidget);
    });
  });

  group('Import games', () {
    testWidgets(
        'on a window: one centred column of reading width, Select PGN file '
        'the filled button', (tester) async {
      await _pumpImport(tester, _window);
      expect(tester.takeException(), isNull);
      final field = tester.getRect(find.byType(TextField));
      expect(field.width, lessThanOrEqualTo(640),
          reason: 'a field of reading width, not the window\'s');
      expect(field.center.dx, closeTo(_window.width / 2, 40),
          reason: 'the column is centred');
      expect(_button<FilledButton>('Select PGN file'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is ElevatedButton), findsNothing);
    });

    testWidgets(
        'a finished import is said in its card, not a snackbar, with its '
        'doors as text buttons', (tester) async {
      await _pumpImport(tester, _window);
      await _import(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(SnackBar), findsNothing,
          reason: 'the result is said where the result is (R3)');
      expect(find.textContaining('Import completed'), findsOneWidget);
      for (final door in _doors) {
        expect(_button<TextButton>(door), findsOneWidget, reason: door);
      }
      expectOnScreen(tester, _window, find.textContaining('Import completed'));
    });

    testWidgets('on a 360 dp phone: nothing overflows after an import',
        (tester) async {
      await _pumpImport(tester, _phone);
      await _import(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
