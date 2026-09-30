// The Analysis bar — docs/PLAN-ANALIZA-TRAKA.md.
//
// Twelve unlabelled icons became four words and two icons, in the order the
// work goes: „Board" puts something on the board, „Engine" works on it,
// „Save as…" keeps it, „Tutorial" makes teaching material of it; then what
// the screen shows, and the rest. „Engine Logs" and „Scan a book" left the
// screen on the owner's word of 30.9.2026.
//
// Written before the bar and proved red on master at acc192c2.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_persistence_service.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_import.dart';
import 'package:chess_app/features/analysis_studio/widgets/board_setup_dialog.dart';
import 'package:chess_app/features/analysis_studio/widgets/game_review_dialog.dart';
import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/features/analysis_studio/widgets/position_study_dialog.dart';
import 'package:chess_app/features/analysis_studio/widgets/quick_extend_dialog.dart';
import 'package:chess_app/features/analysis_studio/widgets/teach_menu.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/exercises/widgets/make_exercise_sheet.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/save_position_dialog.dart';

import 'support/dart_source.dart';

const _desktop = Size(1280, 900);
const _phone = Size(360, 640);

const _boardMenu = Key('analysis-board-menu');
const _engineMenu = Key('analysis-engine-menu');
const _saveMenu = Key('analysis-save-menu');
const _tutorialMenu = Key('analysis-tutorial-menu');
const _more = Key('analysis-more');

const _boardRows = [
  (Key('analysis-board-setup'), 'Set up position…'),
  (Key('analysis-board-fen'), 'Paste FEN…'),
  (Key('analysis-board-pgn'), 'Import PGN…'),
  (Key('analysis-board-openings'), 'Opening by name…'),
  (Key('analysis-board-online'), 'Game from Lichess / Chess.com…'),
  (Key('analysis-board-saved'), 'Saved analysis…'),
  (Key('analysis-board-start'), 'Starting position'),
];

const _engineRows = [
  (Key('analysis-engine-review'), 'Review entire game'),
  (Key('analysis-engine-study'), 'Study this position'),
  (Key('analysis-engine-extend'), 'Extend this line'),
];

const _saveRows = [
  (Key('analysis-save-position'), 'Position'),
  (Key('analysis-save-exercise'), 'Exercise…'),
  (Key('analysis-save-analysis'), 'Analysis'),
  (Key('analysis-save-pgn'), 'PGN'),
];

final List<http.Request> _sent = [];

MockClient _server() => MockClient((req) async {
      _sent.add(req);
      http.Response json(Object body, [int status = 200]) =>
          http.Response(jsonEncode(body), status,
              headers: {'content-type': 'application/json; charset=utf-8'});
      final path = req.url.path;
      if (req.method == 'GET' && path.endsWith('/lessons/labels')) {
        return json(['endgame', 'rook']);
      }
      if (req.method == 'POST' && path.endsWith('/lessons/save')) {
        return json({'id': 31, 'title': 'kept'}, 201);
      }
      if (req.method == 'GET' && path.endsWith('/analysis')) {
        return json(<Object>[]);
      }
      return json({'error': 'not in this fixture: ${req.method} $path'}, 404);
    });

Future<void> _open(
  WidgetTester tester, {
  Size size = _desktop,
  String token = 'tok',
  String? pgn,
}) async {
  SharedPreferences.setMockInitialValues({});
  await AppSettingsService.instance.init();
  _sent.clear();
  final client = _server();
  AnalysisPersistenceService.setInstance(
      AnalysisPersistenceService.withClient(client));
  addTearDown(AnalysisPersistenceService.resetInstance);

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  // Closed here and not in the case: a case that fails half way must not
  // leave its menu or dialog standing for the next one.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: AnalysisStudioScreen(
      key: UniqueKey(),
      userSession: UserSession(
          token: token, id: 7, email: 'a@b.c', name: 'N', role: 'korisnik'),
      initialFen: pgn == null
          ? 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'
          : null,
      initialTree: pgn == null ? null : readAnalysisPgn(pgn)!.root,
      lessonApi: LessonApiService(authToken: token, client: client),
      exerciseApi: ExerciseApiService(authToken: token, client: client),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final target = find.byKey(key);
  expect(target, findsOneWidget, reason: '$key is not on the screen');
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _menu(WidgetTester tester, Key menu, Key row) async {
  await _tap(tester, menu);
  await _tap(tester, row);
}

/// The rows of the menu that is open, top to bottom, by their keys.
void _expectRowsInOrder(WidgetTester tester, List<(Key, String)> rows) {
  double? above;
  for (final (key, label) in rows) {
    final row = find.byKey(key);
    expect(row, findsOneWidget, reason: '„$label" is not in the menu');
    expect(find.descendant(of: row, matching: find.text(label)), findsOneWidget,
        reason: 'the row $key does not read „$label"');
    final top = tester.getTopLeft(row).dy;
    if (above != null) {
      expect(top, greaterThan(above), reason: '„$label" is out of order');
    }
    above = top;
  }
}

int _setupTab(WidgetTester tester) {
  final dialog = find.byType(AnalysisBoardSetupDialog);
  expect(dialog, findsOneWidget, reason: 'the setup dialog did not open');
  final bar = tester.widget<TabBar>(
      find.descendant(of: dialog, matching: find.byType(TabBar)));
  return bar.controller!.index;
}

String _setupTabLabel(WidgetTester tester) {
  final dialog = find.byType(AnalysisBoardSetupDialog);
  final bar = tester.widget<TabBar>(
      find.descendant(of: dialog, matching: find.byType(TabBar)));
  final tab = bar.tabs[_setupTab(tester)] as Tab;
  return tab.text!;
}

AnalysisMoveTreeWidget _tree(WidgetTester tester) =>
    tester.widget(find.byType(AnalysisMoveTreeWidget, skipOffstage: false));

Map<String, String> _sourcesOfLib() => {
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          file.path.replaceAll('\\', '/'): file.readAsStringSync(),
    };

void main() {
  group('the desktop bar', () {
    testWidgets('is four words and two icons, in the order the work goes',
        (tester) async {
      await _open(tester);
      expect(tester.takeException(), isNull);

      final doors = [
        (find.byKey(_boardMenu), 'Board'),
        (find.byKey(_engineMenu), 'Engine'),
        (find.byKey(_saveMenu), 'Save as…'),
        (find.byKey(_tutorialMenu), 'Tutorial'),
      ];
      double edge = 0;
      for (final (door, word) in doors) {
        expect(door, findsOneWidget, reason: '„$word" is not in the bar');
        expect(find.descendant(of: door, matching: find.text(word)),
            findsOneWidget,
            reason: 'the door does not read „$word"');
        final rect = tester.getRect(door);
        expect(rect.left, greaterThanOrEqualTo(edge),
            reason: '„$word" is out of order');
        expect(rect.height, greaterThanOrEqualTo(40),
            reason: '„$word" is a target ${rect.height} px tall');
        edge = rect.right;
      }
      final view = tester.getRect(find.byTooltip('Board view'));
      expect(view.left, greaterThanOrEqualTo(edge));
      final more = tester.getRect(find.byKey(_more));
      expect(more.left, greaterThanOrEqualTo(view.right));
      expect(more.right, lessThanOrEqualTo(_desktop.width));

      // Nothing of the twelve is left beside them.
      for (final gone in [
        'Setup Position / PGN',
        'Review entire game',
        'Study this position',
        'Extend branch (engine best line)',
        'Use in a tutorial',
        'Scan a book',
        'Export PGN',
        'Saved analyses',
        'Panels',
        'Settings',
        'Engine Logs 📜',
        'More tools',
      ]) {
        expect(find.byTooltip(gone), findsNothing,
            reason: 'the icon „$gone" is still in the bar');
      }
    });

    testWidgets('fits the narrowest window that draws it', (tester) async {
      await _open(tester, size: const Size(840, 700));
      expect(tester.takeException(), isNull);
      final title = tester.getRect(find.text('Analysis'));
      final board = tester.getRect(find.byKey(_boardMenu));
      expect(board.left, greaterThan(title.right),
          reason: 'the words run into the title');
      expect(tester.getRect(find.byKey(_more)).right, lessThanOrEqualTo(840));
    });
  });

  group('Board', () {
    testWidgets('lists the ways onto the board', (tester) async {
      await _open(tester);
      await _tap(tester, _boardMenu);
      _expectRowsInOrder(tester, _boardRows);
    });

    for (final (key, tab) in const [
      (Key('analysis-board-setup'), 'Pieces'),
      (Key('analysis-board-fen'), 'FEN'),
      (Key('analysis-board-pgn'), 'PGN'),
      (Key('analysis-board-openings'), 'Openings'),
      (Key('analysis-board-online'), 'Online'),
    ]) {
      testWidgets('$key opens the setup dialog on „$tab"', (tester) async {
        await _open(tester);
        await _menu(tester, _boardMenu, key);
        expect(tester.takeException(), isNull);
        expect(_setupTabLabel(tester), tab);
      });
    }

    testWidgets('„Saved analysis…" opens the list of them', (tester) async {
      await _open(tester);
      await _menu(tester, _boardMenu, const Key('analysis-board-saved'));
      expect(find.text('Saved analyses'), findsOneWidget);
    });

    testWidgets('„Starting position" asks before it drops a line',
        (tester) async {
      await _open(tester, pgn: '1. e4 e5 2. Nf3 Nc6');
      expect(_tree(tester).rootNode.children, isNotEmpty);

      await _menu(tester, _boardMenu, const Key('analysis-board-start'));
      expect(find.byKey(const Key('analysis-start-over')), findsOneWidget,
          reason: 'a line was about to be dropped without a question');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(_tree(tester).rootNode.children, isNotEmpty,
          reason: 'Cancel dropped the line');

      await _menu(tester, _boardMenu, const Key('analysis-board-start'));
      await tester.tap(find.byKey(const Key('analysis-start-over')));
      await tester.pumpAndSettle();
      expect(_tree(tester).rootNode.children, isEmpty);
      expect(_tree(tester).rootNode.fen,
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
    });

    testWidgets('„Starting position" asks nothing of a board with no move',
        (tester) async {
      await _open(tester);
      await _menu(tester, _boardMenu, const Key('analysis-board-start'));
      expect(find.byKey(const Key('analysis-start-over')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Engine', () {
    testWidgets('names its three jobs and what each one covers',
        (tester) async {
      await _open(tester);
      await _tap(tester, _engineMenu);
      _expectRowsInOrder(tester, _engineRows);
      for (final scope in ['The whole game', 'This position', 'This line']) {
        expect(find.textContaining(scope), findsOneWidget,
            reason: 'no row says it covers „$scope"');
      }
    });

    testWidgets('each row opens its own dialog', (tester) async {
      await _open(tester, pgn: '1. e4 e5 2. Nf3 Nc6');
      await _menu(tester, _engineMenu, const Key('analysis-engine-study'));
      expect(find.byType(PositionStudyDialog), findsOneWidget);
    });

    testWidgets('„Review entire game" opens the review', (tester) async {
      await _open(tester, pgn: '1. e4 e5 2. Nf3 Nc6');
      await _menu(tester, _engineMenu, const Key('analysis-engine-review'));
      expect(find.byType(GameReviewDialog), findsOneWidget);
    });

    testWidgets('„Extend this line" opens the extension', (tester) async {
      await _open(tester, pgn: '1. e4 e5 2. Nf3 Nc6');
      await _menu(tester, _engineMenu, const Key('analysis-engine-extend'));
      expect(find.byType(QuickExtendDialog), findsOneWidget);
      expect(find.text('Extend this line'), findsOneWidget,
          reason: 'the dialog is named otherwise than its row');
    });
  });

  group('Save as…', () {
    testWidgets('lists the four ways to keep the board', (tester) async {
      await _open(tester);
      await _tap(tester, _saveMenu);
      _expectRowsInOrder(tester, _saveRows);
    });

    testWidgets('„Position" keeps the board and no line', (tester) async {
      await _open(tester, pgn: '1. e4 e5 2. Nf3 Nc6');
      // Off the root, so that „the board in front of the reader" and „where
      // the tree starts" are two positions and the wrong one can be told.
      await tester.tap(find.byTooltip('Next move'));
      await tester.pumpAndSettle();
      await _menu(tester, _saveMenu, const Key('analysis-save-position'));
      final dialog = find.byType(SavePositionDialog);
      expect(dialog, findsOneWidget);
      expect(tester.widget<SavePositionDialog>(dialog).availableUserLabels,
          ['endgame', 'rook']);
      await tester.enterText(
          find.widgetWithText(TextField, 'Position name'), 'Start');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      final saved = [
        for (final r in _sent)
          if (r.method == 'POST' && r.url.path.endsWith('/lessons/save')) r,
      ];
      expect(saved, hasLength(1));
      final body = jsonDecode(saved.single.body) as Map;
      expect(body['title'], 'Start');
      expect(body['fen'],
          startsWith('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq'),
          reason: 'the position kept is not the one on the board');
      expect(body['pgn'] ?? '', isEmpty,
          reason: 'a position is kept without a line');
      expect(find.text('Position saved.'), findsOneWidget);
    });

    testWidgets('„Exercise…" is of the position the board stands on',
        (tester) async {
      await _open(tester, pgn: '1. e4 e5 2. Nf3 Nc6');
      await tester.tap(find.byTooltip('Next move'));
      await tester.pumpAndSettle();
      await _menu(tester, _saveMenu, const Key('analysis-save-exercise'));
      final sheet = find.byType(MakeExerciseSheet);
      expect(sheet, findsOneWidget);
      expect(tester.widget<MakeExerciseSheet>(sheet).moveTree!.root.fen,
          startsWith('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq'),
          reason: 'the exercise starts somewhere else than the board stands');
      expect(tester.widget<MakeExerciseSheet>(sheet).availableUserLabels,
          ['endgame', 'rook']);
    });

    testWidgets('„Analysis" asks for a name, „PGN" shows the text',
        (tester) async {
      await _open(tester, pgn: '1. e4 e5 2. Nf3 Nc6');
      await _menu(tester, _saveMenu, const Key('analysis-save-analysis'));
      expect(find.text('Save analysis'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      await _menu(tester, _saveMenu, const Key('analysis-save-pgn'));
      expect(find.text('Exported PGN Text'), findsOneWidget);
      expect(find.textContaining('1. e4 e5 2. Nf3 Nc6'), findsOneWidget);
    });

    testWidgets(
        'a guest is told to sign in, and nothing is asked of the server',
        (tester) async {
      await _open(tester, token: '', pgn: '1. e4 e5');
      for (final key in const [
        Key('analysis-save-position'),
        Key('analysis-save-exercise'),
        Key('analysis-save-analysis'),
      ]) {
        await _menu(tester, _saveMenu, key);
        expect(
            find.text('Saving requires a signed-in account.'), findsOneWidget,
            reason: '$key said nothing to a guest');
        expect(find.byType(SavePositionDialog), findsNothing);
        expect(find.byType(MakeExerciseSheet), findsNothing);
        expect(find.text('Save analysis'), findsNothing);
        // The message leaves before the next row is tried.
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      }
      expect(_sent, isEmpty);
    });
  });

  group('Tutorial', () {
    testWidgets('holds the six rows of the sheet, in its order',
        (tester) async {
      await _open(tester, pgn: '1. e4 e5 2. Nf3 Nc6');
      await _tap(tester, _tutorialMenu);
      double? above;
      for (final label in [
        TeachMenuSheet.newFromPosition,
        TeachMenuSheet.newFromLine,
        TeachMenuSheet.newFromGame,
        TeachMenuSheet.addPosition,
        TeachMenuSheet.addLine,
        TeachMenuSheet.edit,
      ]) {
        final row = find.text(label);
        expect(row, findsOneWidget, reason: '„$label" is not in the menu');
        final top = tester.getTopLeft(row).dy;
        if (above != null) expect(top, greaterThan(above), reason: label);
        above = top;
      }
      expect(find.byType(TeachMenuSheet), findsNothing,
          reason: 'a window has a menu under the word, not a sheet');
    });

    testWidgets('draws only the rows a bare board can deliver', (tester) async {
      await _open(tester);
      await _tap(tester, _tutorialMenu);
      expect(find.text(TeachMenuSheet.newFromPosition), findsOneWidget);
      expect(find.text(TeachMenuSheet.addPosition), findsOneWidget);
      expect(find.text(TeachMenuSheet.edit), findsOneWidget);
      expect(find.text(TeachMenuSheet.newFromLine), findsNothing);
      expect(find.text(TeachMenuSheet.newFromGame), findsNothing);
      expect(find.text(TeachMenuSheet.addLine), findsNothing);
    });
  });

  group('what the screen shows, and the rest', () {
    testWidgets('the panels are ticked in the board view menu', (tester) async {
      await _open(tester);
      addTearDown(
          () => AppSettingsService.instance.setPanelVisible('move_tree', true));
      final tree = find.byType(AnalysisMoveTreeWidget, skipOffstage: false);
      expect(tree, findsOneWidget);

      await tester.tap(find.byTooltip('Board view'));
      await tester.pumpAndSettle();
      expect(find.text('Coordinates'), findsOneWidget);
      for (final panel in [
        'Move tree',
        'Opening Explorer',
        'Tablebase (Syzygy)',
        'Engine analysis panel',
      ]) {
        expect(find.byKey(Key('analysis-panel-$panel')), findsOneWidget,
            reason: '„$panel" is not in the menu');
      }

      await tester.tap(find.byKey(const Key('analysis-panel-Move tree')));
      await tester.pumpAndSettle();
      expect(AppSettingsService.instance.isPanelVisible('move_tree'), isFalse);
      expect(find.text('Coordinates'), findsOneWidget,
          reason: 'the menu closed on the first tick');
      expect(tree, findsNothing);
    });

    testWidgets('⋮ holds Settings and nothing about logs', (tester) async {
      await _open(tester);
      await _tap(tester, _more);
      expect(find.byKey(const Key('analysis-more-settings')), findsOneWidget);
      expect(find.textContaining('log'), findsNothing);
      expect(find.textContaining('Log'), findsNothing);
      expect(find.text('Scan a book'), findsNothing);
    });
  });

  group('the phone bar', () {
    testWidgets('is four buttons, all on the screen', (tester) async {
      await _open(tester, size: _phone);
      expect(tester.takeException(), isNull);
      expect(find.byKey(_saveMenu), findsNothing);
      expect(find.byKey(_tutorialMenu), findsNothing);
      double edge = 0;
      for (final door in [
        find.byTooltip('Board view'),
        find.byTooltip('Board'),
        find.byTooltip('Engine'),
        find.byTooltip('More'),
      ]) {
        expect(door, findsOneWidget);
        final rect = tester.getRect(door);
        expect(rect.left, greaterThanOrEqualTo(edge));
        expect(rect.width, greaterThanOrEqualTo(40));
        edge = rect.right;
      }
      expect(edge, lessThanOrEqualTo(_phone.width));
    });

    testWidgets('its Board and Engine buttons hold the same rows',
        (tester) async {
      await _open(tester, size: _phone);
      await _tap(tester, _boardMenu);
      expect(tester.takeException(), isNull);
      for (final (key, _) in _boardRows) {
        expect(find.byKey(key, skipOffstage: false), findsOneWidget);
      }
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await _tap(tester, _engineMenu);
      expect(tester.takeException(), isNull);
      _expectRowsInOrder(tester, _engineRows);
      final menu = tester.getRect(find.byKey(_engineRows.last.$1));
      expect(menu.right, lessThanOrEqualTo(_phone.width));
    });

    testWidgets('⋮ keeps the board, opens the tutorial sheet, and has Settings',
        (tester) async {
      await _open(tester, size: _phone, pgn: '1. e4 e5 2. Nf3 Nc6');
      await _tap(tester, _more);
      expect(tester.takeException(), isNull);
      expect(find.text('Keep what is on the board'), findsOneWidget);
      _expectRowsInOrder(tester, _saveRows);
      expect(find.byKey(const Key('analysis-more-settings')), findsOneWidget);

      await _tap(tester, const Key('analysis-more-tutorial'));
      expect(find.byType(TeachMenuSheet), findsOneWidget);
      expect(find.text(TeachMenuSheet.newFromGame), findsOneWidget);
    });
  });

  group('what left the screen', () {
    test('the engine log is gone from lib/, door, dialog and buffer', () {
      final sources = _sourcesOfLib();
      expect(sources.length, greaterThan(200), reason: 'lib/ was walked');
      final literals = {
        for (final src in sources.values) ...literalsIn(src),
      };
      expect(literals.where((s) => s.contains('Engine Logs')), isEmpty);
      for (final entry in sources.entries) {
        final code = codeOf(entry.value);
        expect(code, isNot(contains('showLogsDialog')), reason: entry.key);
        expect(code, isNot(contains('AppLogger.logs')), reason: entry.key);
        expect(code, isNot(contains('formattedLogs')), reason: entry.key);
      }
    });

    test('the scanner is not a door of this screen', () {
      final sources = _sourcesOfLib();
      for (final path in [
        'lib/features/analysis_studio/screens/analysis_studio_screen.dart',
        'lib/widgets/home/analyse_tab.dart',
      ]) {
        final src = sources[path];
        expect(src, isNotNull, reason: '$path was not read');
        expect(codeOf(src!), isNot(contains('onOpenScanner')), reason: path);
        expect(literalsIn(src), isNot(contains('Scan a book')), reason: path);
      }
      // And it is still a card on Teach.
      expect(literalsIn(sources['lib/widgets/home/teach_tab.dart']!),
          contains('Scan a book'));
    });

    test('no icon-only tool list is left in the screen', () {
      final src = File(
              'lib/features/analysis_studio/screens/analysis_studio_screen.dart')
          .readAsStringSync();
      expect(codeOf(src), isNot(contains('_ToolAction')));
    });
  });
}
