// The gate for phase 2 of `docs/PLAN-PRIPREMA.md` — material in, material out.
//
// Written by the lead while phase 1 was being built, and kept here, outside
// `chess_app/test/`, until phase 1 has landed: it names constructor parameters
// the screen does not have yet. It moves to
// `chess_app/test/preparation_material_test.dart` when phase 2 is briefed, and
// is watched going red on phase 1's finished screen first.
//
// ---------------------------------------------------------------------------
// THE FROZEN CONTRACT
//
// **The screen gains five seams**, every one optional and built by the screen
// itself where it is not given:
//
//   positionLibrary   PositionLibraryService   what the Library holds
//   lessonApi         LessonApiService         a tutorial's parts; „Position"
//   scannerApi        ScannerApiService        a side nobody set
//   exerciseApi       ExerciseApiService       „Exercise…"
//   onOpenInAnalysis  void Function(AnalysisNode tree)
//                                              „Open in Analysis"; the screen
//                                              pushes Analysis itself when
//                                              nothing is given
//
// A saved analysis is read and written through
// `AnalysisPersistenceService.instance`, which a test replaces.
//
// **The bar**, on a desktop window and on a phone held on its side:
//
//   Key('prep-library')      „Library"     opens and shuts the drawer
//   Key('prep-board-menu')   „Board"       what puts something on the board
//   Key('prep-save-menu')    „Save as…"    what keeps what is on it
//
// On a phone held upright the Library is the fourth tab, and both menus'
// items are behind ⋮ — Key('prep-more') — under their two headings.
//
// **The items**, keyed the same wherever they are drawn:
//
//   Key('prep-board-setup')     „Set up position…"
//   Key('prep-board-fen')       „Paste FEN…"
//   Key('prep-board-pgn')       „Import PGN…"
//   Key('prep-board-start')     „Starting position"
//   Key('prep-save-position')   „Position"
//   Key('prep-save-exercise')   „Exercise…"
//   Key('prep-save-analysis')   „Analysis"
//   Key('prep-save-pgn')        „PGN"
//   Key('prep-open-analysis')   „Open in Analysis"
//
// **The Library's drawer**: Key('prep-library-drawer'), holding the app's one
// `LibraryList` with the chips All, Tutorials, Analyses, Exercises, Positions
// — never a recording. Its rows carry **no actions**: renaming, editing and
// deleting are the Library's. It shuts when a row has been put on the board.
//
// **A tutorial on the board** is walked part by part from the bar:
//
//   Key('prep-part-label')   „Part 1 of 2 · <the part's title>"
//   Key('prep-part-prev')    Key('prep-part-next')    Key('prep-part-close')
//
// and it costs the board nothing: the board is the size it was.
//
// **Copy** — and nothing else new:
//
//   'Library', 'Board', 'Save as…', and the nine items above
//   'Part N of M'
//   'Paste a position (FEN)'        the FEN dialog's title
//   'Load'                          its button
//   'There is nothing on this board to keep yet.'
//   'There are no moves on this board to export yet.'   (the room's, as it is)
//
// **What goes on the board, by what the entry is** (D1):
//
//   a tutorial      its parts, each with its line
//   an analysis     its whole tree, as it was saved
//   an exercise,
//   a position,
//   a scan          the position alone — a line it carries is not loaded, and
//                   an exercise's answer is nowhere on the screen
//
// **What „Save as…" keeps**:
//
//   Position        the board in front of the trainer — the position of the
//                   move the cursor stands on — and no line
//   Exercise…       the app's exercise sheet, opened on that same position
//   Analysis        the whole tree
//   PGN             the whole tree as text, header `Event "Preparation"`,
//                   file `preparation-YYYY-MM-DD.pgn`
//   Open in Analysis a copy of the whole tree, never the screen's own nodes
// ---------------------------------------------------------------------------

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_persistence_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/board_setup_dialog.dart';
import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/exercises/widgets/make_exercise_sheet.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/library/widgets/library_list.dart';
import 'package:chess_app/features/position_scanner/services/scanner_api_service.dart';
import 'package:chess_app/features/preparation/screens/preparation_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/game_selector_dialog.dart';
import 'package:chess_app/widgets/pgn_import_dialog.dart';
import 'package:chess_app/widgets/save_position_dialog.dart';

import 'support/landscape.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
// With its en passant square: what the app's own player writes after a
// pawn's double step. The draft of this gate had `-` there, which no board
// of this app ever holds.
const _afterE4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
const _lucena = '1K1k4/1P6/8/8/8/8/r7/2R5 w - - 0 1';
const _rookEnding = '8/8/4k3/8/8/4K3/4P3/8 w - - 0 1';
const _sideless = '4k3/8/8/8/8/8/8/R3K3 w - - 0 1';

const _desktop = Size(1536, 792);
const _phone = Size(360, 640);

/// A part as the owner's own games arrive: a clock on every move, a sentence,
/// an arrow, a square and a variation.
const _partOnePgn = '1. e4 { [%clk 0:03:00] Takes the centre. [%cal Ge2e4] '
    '[%csl Rd5] } 1... e5 { [%clk 0:02:58] } ( 1... c5 2. Nf3 ) 2. Nf3';
const _partTwoPgn = '1. Rc4 { The bridge. } 1... Ra1 2. Rd4+';

/// Every request the screen made, for the cases that read them.
final List<http.Request> _sent = [];

/// The tree a saved analysis comes back as.
AnalysisNode _savedTree() {
  final root = AnalysisNode(fen: _start);
  final e4 = root.addChild(childFen: _afterE4, san: 'e4', uci: 'e2e4');
  e4.comment = 'My main weapon.';
  root.addChild(
    childFen: 'rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq - 0 1',
    san: 'd4',
    uci: 'd2d4',
  );
  return root;
}

http.Client _server({bool libraryDown = false}) => MockClient((req) async {
      _sent.add(req);
      final path = req.url.path;
      http.Response json(Object body, [int status = 200]) =>
          http.Response(jsonEncode(body), status,
              headers: {'content-type': 'application/json; charset=utf-8'});

      if (path.endsWith('/library/positions')) {
        if (libraryDown) return json({'error': 'down'}, 503);
        return json({
          'items': [
            {
              'kind': 'tutorial',
              'id': '14',
              'title': 'Rook endings',
              'fen': _start,
              'partsCount': 2,
              'fromTrainer': false,
            },
            {
              'kind': 'analysis',
              'id': '7',
              'title': 'My first moves',
              'fen': _start,
              'fromTrainer': false,
            },
            // An exercise: the line it carries is its answer.
            {
              'kind': 'scan',
              'id': 'x1',
              'title': 'Mate in one',
              'fen': _rookEnding,
              'pgn': '1. Kd4',
              'solutionSan': 'Kd4',
              'hasSolution': true,
              'isExercise': true,
              'fromTrainer': false,
            },
            // A position saved with a line, as the room saved them.
            {
              'kind': 'position',
              'id': '12',
              'title': 'Lucena',
              'fen': _lucena,
              'pgn': _partTwoPgn,
              'fromTrainer': false,
            },
            // A diagram whose side nobody set.
            {
              'kind': 'scan',
              'id': 'u1',
              'title': 'Side not set',
              'fen': _sideless,
              'needsReview': true,
              'fromTrainer': false,
            },
            // On the shelf, never in this drawer.
            {'kind': 'recording', 'id': '3', 'title': 'Tuesday', 'fen': ''},
          ],
        });
      }
      if (path.endsWith('/lessons/labels')) {
        return json(<String>['endgame', 'rook']);
      }
      if (req.method == 'GET' && path.endsWith('/lessons/14')) {
        return json({
          'id': 14,
          'title': 'Rook endings',
          'position_list': [
            {
              'id': 'step0001',
              'title': 'The centre',
              'fen': _start,
              'pgn': _partOnePgn,
            },
            {
              'id': 'step0002',
              'title': 'The bridge',
              'fen': _lucena,
              'pgn': _partTwoPgn,
            },
          ],
        });
      }
      if (req.method == 'POST' && path.endsWith('/lessons/save')) {
        return json({'id': 31, 'title': 'kept'}, 201);
      }
      if (req.method == 'GET' && path.endsWith('/analysis/7')) {
        return json({'id': 7, 'tree_json': _savedTree().toJson()});
      }
      if (req.method == 'GET' && path.endsWith('/analysis')) {
        return json(<Object>[]);
      }
      if (req.method == 'POST' && path.endsWith('/analysis')) {
        return json({
          'id': 9,
          'title': 'kept',
          'starting_fen': _start,
          'created_at': '2026-09-27T00:00:00Z',
        }, 201);
      }
      if (req.method == 'PATCH' && path.endsWith('/scans/puzzles/u1')) {
        final side = (jsonDecode(req.body) as Map)['sideToMove'];
        return json({'fen': '4k3/8/8/8/8/8/8/R3K3 $side - - 0 1'});
      }
      return json({'error': 'not in this fixture: ${req.method} $path'}, 404);
    });

List<http.Request> _requests(String method, String pathEnd) => [
      for (final r in _sent)
        if (r.method == method && r.url.path.endsWith(pathEnd)) r,
    ];

/// What „Open in Analysis" handed over, for the cases that read it.
final List<AnalysisNode> _openedInAnalysis = [];

Future<void> _open(
  WidgetTester tester, {
  Size size = _desktop,
  String? fen,
  AnalysisNode? tree,
  bool libraryDown = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  _sent.clear();
  _openedInAnalysis.clear();
  final client = _server(libraryDown: libraryDown);
  AnalysisPersistenceService.setInstance(
      AnalysisPersistenceService.withClient(client));
  addTearDown(AnalysisPersistenceService.resetInstance);

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: PreparationScreen(
      key: UniqueKey(),
      userSession: UserSession(
          token: 'tok',
          id: 7,
          email: 'a@b.c',
          name: 'Trainer',
          role: 'korisnik'),
      initialFen: fen,
      initialTree: tree,
      positionLibrary: PositionLibraryService(authToken: 'tok', client: client),
      lessonApi: LessonApiService(authToken: 'tok', client: client),
      scannerApi: ScannerApiService(authToken: 'tok', client: client),
      exerciseApi: ExerciseApiService(authToken: 'tok', client: client),
      onOpenInAnalysis: _openedInAnalysis.add,
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 400));
}

ChessBoardWithOverlay _board(WidgetTester tester) {
  final board = find.byType(ChessBoardWithOverlay);
  expect(board, findsOneWidget, reason: 'there is no board on the screen');
  return tester.widget<ChessBoardWithOverlay>(board);
}

AnalysisMoveTreeWidget _tree(WidgetTester tester) {
  final tree = find.byType(AnalysisMoveTreeWidget, skipOffstage: false);
  expect(tree, findsOneWidget, reason: 'there is no move tree on the screen');
  return tester.widget<AnalysisMoveTreeWidget>(tree);
}

Future<void> _press(WidgetTester tester, Key key) async {
  expect(find.byKey(key), findsOneWidget, reason: 'nothing is keyed $key');
  await tester.tap(find.byKey(key));
  await _settle(tester);
}

Future<void> _play(WidgetTester tester, String from, String to) async {
  _board(tester).onMove(from, to, '');
  await tester.pump(const Duration(milliseconds: 50));
}

/// Opens the drawer and taps the row called [title].
Future<void> _putOnBoard(WidgetTester tester, String title) async {
  await _press(tester, const Key('prep-library'));
  final drawer = find.byKey(const Key('prep-library-drawer'));
  expect(drawer, findsOneWidget, reason: 'the Library\'s drawer did not open');
  final row = find.descendant(of: drawer, matching: find.text(title));
  expect(row, findsOneWidget, reason: '„$title" is not in the drawer');
  // Five rows of 132 do not fit a drawer 520 tall; a trainer scrolls to the
  // fifth, and so does this.
  await tester.ensureVisible(row);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(row);
  await _settle(tester);
}

Future<void> _menu(WidgetTester tester, Key menu, Key item) async {
  await _press(tester, menu);
  await _press(tester, item);
}

List<String?> _mainLine(AnalysisNode root) => [
      for (AnalysisNode? n = root.children.isEmpty ? null : root.children.first;
          n != null;
          n = n.children.isEmpty ? null : n.children.first)
        n.moveSan,
    ];

void main() {
  setUpAll(loadRoboto);

  final windows = TargetPlatformVariant.only(TargetPlatform.windows);
  final android = TargetPlatformVariant.only(TargetPlatform.android);

  group('the bar', () {
    testWidgets('holds Library, Board and Save as…, each whole at 900 wide',
        (tester) async {
      await _open(tester, size: const Size(900, 700));
      for (final key in const [
        Key('prep-library'),
        Key('prep-board-menu'),
        Key('prep-save-menu'),
      ]) {
        expect(find.byKey(key), findsOneWidget,
            reason: 'nothing is keyed $key');
        expectOnScreen(tester, const Size(900, 700), find.byKey(key));
      }
      expect(find.text('Preparation'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: windows);

    testWidgets('each menu has its items, and only its own', (tester) async {
      await _open(tester);
      await _press(tester, const Key('prep-board-menu'));
      for (final (key, label) in const [
        (Key('prep-board-setup'), 'Set up position…'),
        (Key('prep-board-fen'), 'Paste FEN…'),
        (Key('prep-board-pgn'), 'Import PGN…'),
        (Key('prep-board-start'), 'Starting position'),
      ]) {
        expect(find.byKey(key), findsOneWidget, reason: 'no „$label"');
        expect(find.descendant(of: find.byKey(key), matching: find.text(label)),
            findsOneWidget,
            reason: '$key does not say „$label"');
      }
      expect(find.byKey(const Key('prep-save-position')), findsNothing);
      await tester.tapAt(const Offset(4, 400));
      await _settle(tester);

      await _press(tester, const Key('prep-save-menu'));
      for (final (key, label) in const [
        (Key('prep-save-position'), 'Position'),
        (Key('prep-save-exercise'), 'Exercise…'),
        (Key('prep-save-analysis'), 'Analysis'),
        (Key('prep-save-pgn'), 'PGN'),
        (Key('prep-open-analysis'), 'Open in Analysis'),
      ]) {
        expect(find.byKey(key), findsOneWidget, reason: 'no „$label"');
        expect(find.descendant(of: find.byKey(key), matching: find.text(label)),
            findsOneWidget,
            reason: '$key does not say „$label"');
      }
      expect(find.byKey(const Key('prep-board-setup')), findsNothing);
    }, variant: windows);

    testWidgets('on a phone the Library is a tab and the items are behind ⋮',
        (tester) async {
      await _open(tester, size: _phone);
      expect(find.widgetWithText(Tab, 'Library'), findsOneWidget);
      expect(find.byKey(const Key('prep-library')), findsNothing,
          reason: 'a phone has no room for a drawer\'s button in its bar');
      expect(find.byKey(const Key('prep-board-menu')), findsNothing);

      await _press(tester, const Key('prep-more'));
      for (final key in const [
        Key('prep-board-setup'),
        Key('prep-board-fen'),
        Key('prep-board-pgn'),
        Key('prep-board-start'),
        Key('prep-save-position'),
        Key('prep-save-exercise'),
        Key('prep-save-analysis'),
        Key('prep-save-pgn'),
        Key('prep-open-analysis'),
      ]) {
        expect(find.byKey(key), findsOneWidget,
            reason: 'nothing is keyed $key');
      }
      expect(tester.takeException(), isNull);
    }, variant: android);
  });

  group('the Library\'s drawer', () {
    testWidgets('is the app\'s one list, with what can go on a board',
        (tester) async {
      await _open(tester);
      expect(find.byKey(const Key('prep-library-drawer')), findsNothing,
          reason: 'the drawer is shut until it is asked for');
      final before = tester.getRect(find.byType(BoardWithCoordinates));

      await _press(tester, const Key('prep-library'));
      final drawer = find.byKey(const Key('prep-library-drawer'));
      expect(drawer, findsOneWidget);
      final list = tester.widget<LibraryList>(
          find.descendant(of: drawer, matching: find.byType(LibraryList)));
      expect(list.chips, [
        LibraryChip.all,
        LibraryChip.tutorials,
        LibraryChip.analyses,
        LibraryChip.exercises,
        LibraryChip.positions,
      ]);
      expect(list.labels, ['endgame', 'rook'],
          reason: 'the Library\'s own filter has no labels to filter by');
      expect(list.actionsFor, isNull,
          reason:
              'renaming and deleting are the Library\'s, not the drawer\'s');
      for (final title in [
        'Rook endings',
        'My first moves',
        'Mate in one',
        'Lucena',
        'Side not set',
      ]) {
        expect(find.descendant(of: drawer, matching: find.text(title)),
            findsOneWidget,
            reason: '„$title" is not in the drawer');
      }
      expect(find.text('Tuesday'), findsNothing,
          reason: 'a recording cannot go on a board');
      expect(tester.getRect(find.byType(BoardWithCoordinates)), before,
          reason: 'opening the drawer moved or resized the board');

      await _press(tester, const Key('prep-library'));
      expect(find.byKey(const Key('prep-library-drawer')), findsNothing);
    }, variant: windows);

    testWidgets('a Library that cannot be read says so and offers another try',
        (tester) async {
      await _open(tester, libraryDown: true);
      await _press(tester, const Key('prep-library'));
      expect(find.text('The library could not be loaded.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      final asked = _requests('GET', '/library/positions').length;
      await tester.tap(find.text('Try again'));
      await _settle(tester);
      expect(_requests('GET', '/library/positions').length, asked + 1);
    }, variant: windows);
  });

  group('from the Library onto the board', () {
    testWidgets('a tutorial comes part by part, each with its line',
        (tester) async {
      await _open(tester);
      final before = tester.getRect(find.byType(BoardWithCoordinates));
      await _putOnBoard(tester, 'Rook endings');

      expect(find.byKey(const Key('prep-library-drawer')), findsNothing,
          reason: 'the drawer stays open over the board it just filled');
      expect(tester.getRect(find.byType(BoardWithCoordinates)), before,
          reason: 'a tutorial on the board cost the board its size');

      var root = _tree(tester).rootNode;
      expect(root.fen, _start);
      expect(_mainLine(root), ['e4', 'e5', 'Nf3']);
      final e4 = root.children.single;
      expect(e4.comment, 'Takes the centre.',
          reason: 'the clock is not a sentence, and the sentence is not lost');
      expect(['${e4.arrows.single}', '${e4.squares.single}'], ['Ge2e4', 'Rd5']);
      expect([for (final c in e4.children) c.moveSan], ['e5', 'c5'],
          reason: 'the part\'s variation did not come with it');
      expect(_tree(tester).activeNode, same(root));
      expect(_board(tester).controller.getFen(), _start);

      final label = find.byKey(const Key('prep-part-label'));
      expect(label, findsOneWidget);
      expect(tester.widget<Text>(label).data, contains('Part 1 of 2'));
      expect(tester.widget<Text>(label).data, contains('The centre'));

      await _press(tester, const Key('prep-part-next'));
      root = _tree(tester).rootNode;
      expect(root.fen, _lucena);
      expect(_mainLine(root), ['Rc4', 'Ra1', 'Rd4+']);
      expect(tester.widget<Text>(label).data, contains('Part 2 of 2'));
      expect(_board(tester).controller.getFen(), _lucena);

      await _press(tester, const Key('prep-part-prev'));
      expect(_tree(tester).rootNode.fen, _start);

      await _press(tester, const Key('prep-part-close'));
      expect(find.byKey(const Key('prep-part-label')), findsNothing);
      expect(_tree(tester).rootNode.fen, _start,
          reason: 'closing the tutorial must leave its board where it was');
      expect(tester.getRect(find.byType(BoardWithCoordinates)), before);
    }, variant: windows);

    testWidgets('anything else put on the board closes the tutorial',
        (tester) async {
      await _open(tester);
      await _putOnBoard(tester, 'Rook endings');
      expect(find.byKey(const Key('prep-part-label')), findsOneWidget);
      await _putOnBoard(tester, 'Lucena');
      expect(_tree(tester).rootNode.fen, _lucena);
      expect(find.byKey(const Key('prep-part-label')), findsNothing,
          reason: 'the bar still walks a tutorial that is not on the board');
      expect(find.byKey(const Key('prep-part-next')), findsNothing);
    }, variant: windows);

    testWidgets('an analysis comes with its whole tree', (tester) async {
      await _open(tester);
      await _putOnBoard(tester, 'My first moves');
      final root = _tree(tester).rootNode;
      expect([for (final c in root.children) c.moveSan], ['e4', 'd4']);
      expect(root.children.first.comment, 'My main weapon.');
      expect(_tree(tester).activeNode, same(root));
      expect(_requests('GET', '/analysis/7'), hasLength(1));
      expect(find.byKey(const Key('prep-part-label')), findsNothing);
    }, variant: windows);

    testWidgets('an exercise comes as its position, and its answer stays away',
        (tester) async {
      await _open(tester);
      await _putOnBoard(tester, 'Mate in one');
      expect(_tree(tester).rootNode.fen, _rookEnding);
      expect(_tree(tester).rootNode.children, isEmpty,
          reason: 'an exercise\'s line is its answer (D1)');
      expect(find.textContaining('Kd4'), findsNothing,
          reason: 'the answer is written on the screen');
    }, variant: windows);

    testWidgets('a position comes alone, whatever line it was saved with',
        (tester) async {
      await _open(tester);
      await _putOnBoard(tester, 'Lucena');
      expect(_tree(tester).rootNode.fen, _lucena);
      expect(_tree(tester).rootNode.children, isEmpty,
          reason: 'a position is a position (D1)');
      expect(_board(tester).controller.getFen(), _lucena);
    }, variant: windows);

    testWidgets('a side nobody set is asked for before the board is used',
        (tester) async {
      await _open(tester);
      await _putOnBoard(tester, 'Side not set');
      expect(_tree(tester).rootNode.fen, isNot(_sideless),
          reason: 'the position went up with a side nobody chose');
      expect(find.byKey(const ValueKey('side-to-move-dialog')), findsOneWidget,
          reason: 'nobody was asked whose move it is');
      await tester.tap(find.byKey(const ValueKey('side-to-move-black')));
      await _settle(tester);

      final sent = _requests('PATCH', '/scans/puzzles/u1');
      expect(sent, hasLength(1));
      expect((jsonDecode(sent.single.body) as Map)['sideToMove'], 'b');
      expect(_tree(tester).rootNode.fen, '4k3/8/8/8/8/8/8/R3K3 b - - 0 1');
      expect(
          _board(tester).controller.getFen(), '4k3/8/8/8/8/8/8/R3K3 b - - 0 1');
    }, variant: windows);

    testWidgets('what was on the board is replaced, marks and all',
        (tester) async {
      await _open(tester);
      await _play(tester, 'e2', 'e4');
      await _putOnBoard(tester, 'Lucena');
      expect(_tree(tester).rootNode.fen, _lucena);
      expect(_tree(tester).rootNode.children, isEmpty);
      expect(_board(tester).arrows, isEmpty);
      expect(_board(tester).lastMoveFrom, isNull,
          reason: 'the old board\'s last move is drawn on the new one');
    }, variant: windows);
  });

  group('Board', () {
    testWidgets('„Starting position" is a new board', (tester) async {
      await _open(tester, fen: _lucena);
      await _menu(
          tester, const Key('prep-board-menu'), const Key('prep-board-start'));
      expect(_tree(tester).rootNode.fen, _start);
      expect(_board(tester).controller.getFen(), _start);
    }, variant: windows);

    testWidgets('„Set up position…" opens on the board in front of you',
        (tester) async {
      await _open(tester);
      await _play(tester, 'e2', 'e4');
      await _menu(
          tester, const Key('prep-board-menu'), const Key('prep-board-setup'));
      final dialog = find.byType(AnalysisBoardSetupDialog);
      expect(dialog, findsOneWidget);
      expect(
          tester.widget<AnalysisBoardSetupDialog>(dialog).initialFen, _afterE4);
      tester.widget<AnalysisBoardSetupDialog>(dialog).onPositionSet(_lucena);
      await _settle(tester);
      expect(_tree(tester).rootNode.fen, _lucena);
      expect(_tree(tester).rootNode.children, isEmpty);
    }, variant: windows);

    testWidgets('a pasted position is refused when it is not chess',
        (tester) async {
      await _open(tester);
      await _menu(
          tester, const Key('prep-board-menu'), const Key('prep-board-fen'));
      expect(find.text('Paste a position (FEN)'), findsOneWidget);

      // No kings: the engine does not survive it.
      await tester.enterText(
          find.byKey(const Key('prep-fen-field')), '8/8/8/8/8/8/8/8 w - - 0 1');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Load'));
      await _settle(tester);
      expect(_tree(tester).rootNode.fen, _start,
          reason: 'a position without kings went on the board');

      await tester.enterText(
          find.byKey(const Key('prep-fen-field')), '  $_lucena  ');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Load'));
      await _settle(tester);
      expect(_tree(tester).rootNode.fen, _lucena);
      expect(find.text('Paste a position (FEN)'), findsNothing);
    }, variant: windows);

    testWidgets('a pasted game comes through the app\'s one reader',
        (tester) async {
      await _open(tester);
      await _menu(
          tester, const Key('prep-board-menu'), const Key('prep-board-pgn'));
      final dialog = find.byType(PgnImportDialog);
      expect(dialog, findsOneWidget);
      tester.widget<PgnImportDialog>(dialog).onPasted(_partOnePgn);
      await _settle(tester);

      final root = _tree(tester).rootNode;
      expect(_mainLine(root), ['e4', 'e5', 'Nf3']);
      expect(root.children.single.comment, 'Takes the centre.');
      expect([for (final c in root.children.single.children) c.moveSan],
          ['e5', 'c5']);
      expect('${root.children.single.arrows.single}', 'Ge2e4');
    }, variant: windows);

    testWidgets('a text of several games asks which', (tester) async {
      await _open(tester);
      await _menu(
          tester, const Key('prep-board-menu'), const Key('prep-board-pgn'));
      tester
          .widget<PgnImportDialog>(find.byType(PgnImportDialog))
          .onPasted('[Event "One"]\n[White "A"]\n[Black "B"]\n\n1. e4 e5 *\n\n'
              '[Event "Two"]\n[White "C"]\n[Black "D"]\n\n1. d4 d5 *\n');
      await _settle(tester);
      expect(find.byType(GameSelectorDialog), findsOneWidget);
      expect(_tree(tester).rootNode.children, isEmpty,
          reason: 'a game was loaded before one was chosen');
    }, variant: windows);

    testWidgets('a text that is not a game changes nothing and says so',
        (tester) async {
      await _open(tester);
      await _play(tester, 'e2', 'e4');
      await _menu(
          tester, const Key('prep-board-menu'), const Key('prep-board-pgn'));
      tester
          .widget<PgnImportDialog>(find.byType(PgnImportDialog))
          .onPasted('not a game at all');
      await _settle(tester);
      expect(_mainLine(_tree(tester).rootNode), ['e4']);
      expect(find.text('Pasted text does not contain a valid PGN game.'),
          findsOneWidget);
    }, variant: windows);
  });

  group('Save as…', () {
    testWidgets('„Position" keeps the board in front of you, and no line',
        (tester) async {
      await _open(tester);
      await _play(tester, 'e2', 'e4');
      await _play(tester, 'e7', 'e5');
      await tester.tap(find.byTooltip('Previous move'));
      await _settle(tester);

      await _menu(
          tester, const Key('prep-save-menu'), const Key('prep-save-position'));
      expect(find.byType(SavePositionDialog), findsOneWidget);
      await tester.enterText(
          find.widgetWithText(TextField, 'Position name'), 'After e4');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await _settle(tester);

      final sent = _requests('POST', '/lessons/save');
      expect(sent, hasLength(1));
      final body = jsonDecode(sent.single.body) as Map;
      expect(body['title'], 'After e4');
      expect(body['fen'], _afterE4,
          reason: 'the position kept is not the one on the board');
      expect(body['pgn'] ?? '', isEmpty,
          reason: 'a position is kept without a line');
      expect(body.containsKey('positionList'), isFalse);
      expect(find.text('Position saved.'), findsOneWidget);
    }, variant: windows);

    testWidgets('the trainer\'s own labels are offered where a thing is kept',
        (tester) async {
      await _open(tester);
      expect(_requests('GET', '/lessons/labels'), isEmpty,
          reason: 'the screen asks the server nothing on arrival');
      await _play(tester, 'e2', 'e4');
      await _menu(
          tester, const Key('prep-save-menu'), const Key('prep-save-position'));
      expect(
          tester
              .widget<SavePositionDialog>(find.byType(SavePositionDialog))
              .availableUserLabels,
          ['endgame', 'rook']);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await _settle(tester);

      await _menu(
          tester, const Key('prep-save-menu'), const Key('prep-save-exercise'));
      expect(
          tester
              .widget<MakeExerciseSheet>(find.byType(MakeExerciseSheet))
              .availableUserLabels,
          ['endgame', 'rook']);
      expect(_requests('GET', '/lessons/labels'), hasLength(1),
          reason: 'asked once, and remembered');
    }, variant: windows);

    testWidgets('a position set up with no move on it is kept as an analysis',
        (tester) async {
      await _open(tester, fen: _lucena);
      await _menu(
          tester, const Key('prep-save-menu'), const Key('prep-save-analysis'));
      expect(find.text('Save analysis'), findsOneWidget,
          reason: 'a board somebody set up is not a board with nothing on it');
    }, variant: windows);

    testWidgets('„Analysis" keeps the whole tree', (tester) async {
      await _open(tester);
      await _play(tester, 'e2', 'e4');
      await tester.tap(find.byTooltip('Previous move'));
      await _settle(tester);
      await _play(tester, 'd2', 'd4');

      await _menu(
          tester, const Key('prep-save-menu'), const Key('prep-save-analysis'));
      expect(find.text('Save analysis'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Two first moves');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await _settle(tester);

      final sent = _requests('POST', '/analysis');
      expect(sent, hasLength(1));
      final body = jsonDecode(sent.single.body) as Map;
      expect(body['title'], 'Two first moves');
      expect(body['startingFen'], _start);
      final kept =
          AnalysisNode.fromJson(Map<String, dynamic>.from(body['tree'] as Map));
      expect([for (final c in kept.children) c.moveSan], ['e4', 'd4']);
    }, variant: windows);

    testWidgets('a board with nothing on it is not kept as an analysis',
        (tester) async {
      await _open(tester);
      await _menu(
          tester, const Key('prep-save-menu'), const Key('prep-save-analysis'));
      expect(find.text('Save analysis'), findsNothing);
      expect(find.text('There is nothing on this board to keep yet.'),
          findsOneWidget);
      expect(_requests('POST', '/analysis'), isEmpty);
    }, variant: windows);

    testWidgets('a mark on a later sentence is something to keep',
        (tester) async {
      // Phase 6: „bare" read the first sentence's marks only, so a board
      // whose one mark stood on its second sentence was refused.
      final root = AnalysisNode(fen: _start);
      root
          .addBeat()
          .arrows
          .add(ChessArrow(colorCode: 'G', from: 'e2', to: 'e4'));
      await _open(tester, tree: root);
      await _menu(
          tester, const Key('prep-save-menu'), const Key('prep-save-analysis'));
      expect(find.text('There is nothing on this board to keep yet.'),
          findsNothing);
      expect(find.text('Save analysis'), findsOneWidget);
    }, variant: windows);

    testWidgets('„PGN" hands over the whole tree as text', (tester) async {
      await _open(tester);
      await _play(tester, 'e2', 'e4');
      await tester.tap(find.byTooltip('Previous move'));
      await _settle(tester);
      await _play(tester, 'd2', 'd4');
      await _menu(
          tester, const Key('prep-save-menu'), const Key('prep-save-pgn'));

      final shown = find.byType(SelectableText);
      expect(shown, findsOneWidget, reason: 'the export dialog did not open');
      final text = tester.widget<SelectableText>(shown).data ?? '';
      expect(text, contains('[Event "Preparation"]'));
      expect(text, contains('1. e4'));
      // As `PgnExporterService` writes a variation: no space inside the
      // bracket.
      expect(text, contains('(1. d4'),
          reason: 'the variation is not in the text');
    }, variant: windows);

    testWidgets('a board with no moves has no PGN to hand over',
        (tester) async {
      await _open(tester);
      await _menu(
          tester, const Key('prep-save-menu'), const Key('prep-save-pgn'));
      expect(find.text('There are no moves on this board to export yet.'),
          findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);
    }, variant: windows);

    testWidgets(
        '„Exercise…" opens the app\'s sheet on the board in front of you',
        (tester) async {
      await _open(tester);
      await _play(tester, 'e2', 'e4');
      await _play(tester, 'e7', 'e5');
      await tester.tap(find.byTooltip('Previous move'));
      await _settle(tester);
      await _menu(
          tester, const Key('prep-save-menu'), const Key('prep-save-exercise'));

      final sheet = find.byType(MakeExerciseSheet);
      expect(sheet, findsOneWidget);
      final tree = tester.widget<MakeExerciseSheet>(sheet).moveTree;
      expect(tree, isNotNull);
      expect(tree!.current.fen, _afterE4,
          reason: 'the exercise does not start where the trainer stands');
      expect(tree.current.children.single.san, 'e5',
          reason: 'the line that follows is the exercise\'s answer');
    }, variant: windows);

    testWidgets('„Open in Analysis" hands over a copy of the whole tree',
        (tester) async {
      await _open(tester);
      await _play(tester, 'e2', 'e4');
      await tester.tap(find.byTooltip('Previous move'));
      await _settle(tester);
      await _play(tester, 'd2', 'd4');
      await _menu(
          tester, const Key('prep-save-menu'), const Key('prep-open-analysis'));

      expect(_openedInAnalysis, hasLength(1));
      final handed = _openedInAnalysis.single;
      final own = _tree(tester).rootNode;
      expect(handed, isNot(same(own)),
          reason: 'Analysis was handed the screen\'s own nodes');
      expect(handed.children.first, isNot(same(own.children.first)));
      expect(jsonEncode(handed.toJson()), jsonEncode(own.toJson()));
    }, variant: windows);
  });
}
