/// Preparation keeps its work: „Save analysis" and „Export PGN".
///
/// Until now the room's tree left the screen only as something a student is
/// given — a lesson step, an exercise — or as a single board („Save position").
/// A trainer preparing alone had no way to keep the line itself, and „Export to
/// Analysis" carries the FEN of wherever they stand and nothing else.
///
/// The rule this is built on is CLAUDE.md's from 6.9.2026: the writer reads its
/// own work back through the reader's parser before saving it. So the tests
/// here ask about the **request** and about the **refusal**, not about a
/// snackbar: a save that stores a shorter line than the trainer built is the
/// silent failure this repository keeps paying for, and a guard that cannot
/// fire is not a guard.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_persistence_service.dart';
import 'package:chess_app/features/analysis_studio/services/prepared_line.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/screens/chess_game_screen.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// A tree built the way the room builds one — by playing the moves.
MoveTree _playedTree(List<String> lanMoves) {
  final tree = MoveTree(startingFen: _startFen);
  final appended = MoveTree.appendLine(tree.root, lanMoves);
  tree.current = appended.end;
  return tree;
}

/// A tree whose text its own reader cannot replay.
///
/// Built by hand rather than played, because `appendLine` refuses an illegal
/// move — which is the point: the only way into the refusal branch is a tree
/// that disagrees with its own position, and that is precisely the state the
/// guard exists to catch. `e5` is not a legal first move for White.
MoveTree _unreadableTree() {
  final tree = MoveTree(startingFen: _startFen);
  tree.root.children.add(MoveNode(
    san: 'e5',
    fen: _startFen,
    from: 'e2',
    to: 'e5',
    parent: tree.root,
  ));
  return tree;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('readPreparedLine', () {
    test('a played line comes back whole, and replays', () {
      final line = readPreparedLine(_playedTree(['e2e4', 'e7e5', 'g1f3']));

      expect(line.rejectedMoves, 0);
      expect(line.moveCount, 3);
      expect(line.pgn, contains('e4'));

      // The tree the rest of the app would hold: the main line, in order.
      final sans = <String>[];
      var node = line.root;
      while (node.children.isNotEmpty) {
        node = node.children.first;
        sans.add(node.moveSan!);
      }
      expect(sans, ['e4', 'e5', 'Nf3']);
    });

    test('a sideline is counted and carried', () {
      final tree = _playedTree(['e2e4', 'e7e5']);
      MoveTree.appendLine(tree.root.children.first, ['c7c5']);

      final line = readPreparedLine(tree);
      expect(line.rejectedMoves, 0);
      expect(line.moveCount, 3, reason: 'e4, e5 and the c5 sideline');
      expect(line.root.children.first.children, hasLength(2));
    });

    test('an empty board is no moves rather than a refusal of its own', () {
      final line = readPreparedLine(MoveTree(startingFen: _startFen));
      expect(line.rejectedMoves, 0);
      expect(line.moveCount, 0);
    });

    test('a line its own reader cannot replay is reported, not swallowed', () {
      final line = readPreparedLine(_unreadableTree());
      expect(line.rejectedMoves, 1);
      expect(line.moveCount, 0);
    });
  });

  group('preparedLineRefusal', () {
    AnalysisNode bareRoot() => AnalysisNode(fen: _startFen);

    test('passes a line that read back whole', () {
      expect(
        preparedLineRefusal(
            (root: bareRoot(), pgn: '1. e4', rejectedMoves: 0, moveCount: 1)),
        isNull,
      );
    });

    test('refuses a line with a move that could not be read back', () {
      final said = preparedLineRefusal(
          (root: bareRoot(), pgn: '1. e5', rejectedMoves: 1, moveCount: 0));
      expect(said, isNotNull);
      expect(said, contains('1 move'));
      expect(said, contains('Nothing was saved'));
    });

    test('counts more than one in the plural', () {
      final said = preparedLineRefusal(
          (root: bareRoot(), pgn: '', rejectedMoves: 3, moveCount: 0));
      expect(said, contains('3 moves'));
    });

    test('refuses an empty board, and says what to do instead', () {
      final said = preparedLineRefusal(
          (root: bareRoot(), pgn: '', rejectedMoves: 0, moveCount: 0));
      expect(said, isNotNull);
      expect(said, contains('no moves'));
    });

    test('a board whose every move was lost is not an empty board', () {
      expect(
        preparedLineIsEmpty(
            (root: bareRoot(), pgn: '', rejectedMoves: 2, moveCount: 0)),
        isFalse,
        reason: 'two moves were written and neither was read back',
      );
      expect(
        preparedLineIsEmpty(
            (root: bareRoot(), pgn: '', rejectedMoves: 0, moveCount: 0)),
        isTrue,
      );
      // And the two get different sentences, which is the whole reason the
      // predicate is separate from the message.
      expect(
        preparedLineRefusal(
            (root: bareRoot(), pgn: '', rejectedMoves: 2, moveCount: 0)),
        isNot(contains('no moves on this board yet')),
      );
    });
  });

  group('in the room', () {
    late List<Map<String, dynamic>> saved;

    /// Answers every request the screen makes on the way up, and records the
    /// one this is about.
    ///
    /// The shelf answers with one tutorial on purpose. An empty shelf draws an
    /// empty-state line where a real trainer has a list, and the row of that
    /// list is the lowest thing on this panel — so a fixture with nothing on
    /// the shelf is a fixture that cannot see the panel outgrow its window.
    MockClient recordingClient() => MockClient((request) async {
          if (request.method == 'POST' &&
              request.url.path.endsWith('/analysis')) {
            saved.add(jsonDecode(request.body) as Map<String, dynamic>);
            return http.Response(
                jsonEncode({
                  'id': 5,
                  'title': 'Prepared line',
                  'starting_fen': _startFen,
                  'created_at': DateTime.now().toIso8601String(),
                }),
                201);
          }
          if (request.method == 'GET' &&
              request.url.path.endsWith('/library/positions')) {
            return http.Response(
                jsonEncode({
                  'items': [
                    {
                      'kind': 'tutorial',
                      'id': '42',
                      'title': 'Shelved line',
                      'fen': _startFen,
                      'partsCount': 2,
                    },
                  ],
                }),
                200);
          }
          return http.Response('[]', 200);
        });

    setUp(() {
      saved = <Map<String, dynamic>>[];
      SharedPreferences.setMockInitialValues({});
      AnalysisPersistenceService.setInstance(
          AnalysisPersistenceService.withClient(recordingClient()));
    });

    tearDown(AnalysisPersistenceService.resetInstance);

    Future<void> openPreparation(WidgetTester tester,
        {Size size = const Size(1600, 1200)}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: ChessGamePage(
          roomCode: 'STUDIO',
          userSession: UserSession(
              token: 't',
              id: 7,
              email: 'a@b.c',
              name: 'Trainer',
              role: 'trener'),
          lessonApi:
              LessonApiService(authToken: 'tok', client: recordingClient()),
          positionLibrary: PositionLibraryService(
              authToken: 'tok', client: recordingClient()),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 200));
    }

    Future<void> play(WidgetTester tester, String from, String to) async {
      final board = tester.widget<ChessBoardWithOverlay>(
          find.byType(ChessBoardWithOverlay).first);
      board.controller.makeMove(from: from, to: to);
      board.onMove(from, to, '');
      await tester.pump(const Duration(milliseconds: 50));
    }

    /// Torn down by hand: the room starts a socket and a recorder, and a test
    /// that walks out on them leaves timers running into the next one.
    Future<void> leave(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('both doors are on the board panel', (tester) async {
      await openPreparation(tester);

      expect(find.byKey(const Key('prep-save-analysis')), findsOneWidget);
      expect(find.byKey(const Key('prep-export-pgn')), findsOneWidget);

      await leave(tester);
    });

    testWidgets('the board panel still ends above the fold on a small window',
        (tester) async {
      // The size that caught the first attempt at this feature. Two more
      // full-width buttons pushed „Library" — and with it the tutorial list a
      // trainer taps — off the bottom of the panel, and the only thing that
      // noticed was an unrelated test tapping a row it could no longer reach.
      // Frozen here so the next row added to this panel has to answer for it.
      const laptop = Size(1200, 800);
      await openPreparation(tester, size: laptop);

      for (final door in const [
        'Set up position',
        'Import PGN',
        'Export PGN',
        'Save position',
        'Save analysis',
        'Library',
        // The lowest thing on the panel, and the one that actually went
        // missing: a trainer reaches their material by tapping this row.
        'Shelved line',
      ]) {
        expect(find.text(door), findsOneWidget, reason: door);
        expect(tester.getCenter(find.text(door)).dy, lessThan(laptop.height),
            reason: '"$door" is below the fold of a $laptop window');
      }

      // And it is reachable, not merely drawn: the warning a missed tap prints
      // is not a failure, so a row half off the bottom would pass the check
      // above and still refuse to open.
      await tester.tap(find.text('Shelved line'));
      await tester.pump();

      await leave(tester);
    });

    testWidgets('a saved line replays the moves that were played',
        (tester) async {
      await openPreparation(tester);
      await play(tester, 'e2', 'e4');
      await play(tester, 'e7', 'e5');
      await play(tester, 'g1', 'f3');

      await tester.tap(find.byKey(const Key('prep-save-analysis')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      expect(saved, hasLength(1));
      expect(saved.single['startingFen'], _startFen);

      // Read back the way the Analysis board reads a saved tree, so this
      // asserts the thing that will actually be reopened.
      final tree = AnalysisNode.fromJson(
          Map<String, dynamic>.from(saved.single['tree'] as Map));
      final sans = <String>[];
      var node = tree;
      while (node.children.isNotEmpty) {
        node = node.children.first;
        sans.add(node.moveSan!);
      }
      expect(sans, ['e4', 'e5', 'Nf3']);

      await leave(tester);
    });

    testWidgets('an empty board is refused, and nothing is sent',
        (tester) async {
      await openPreparation(tester);

      await tester.tap(find.byKey(const Key('prep-save-analysis')));
      await tester.pumpAndSettle();

      expect(saved, isEmpty);
      expect(find.textContaining('no moves on this board'), findsOneWidget);
      // The title prompt must not have opened: a refusal that still asks for a
      // name is a refusal the trainer only discovers after typing one.
      expect(find.widgetWithText(ElevatedButton, 'Save'), findsNothing);

      await leave(tester);
    });

    testWidgets('the exported text carries the line and its sidelines',
        (tester) async {
      await openPreparation(tester);
      await play(tester, 'e2', 'e4');
      await play(tester, 'e7', 'e5');

      await tester.tap(find.byKey(const Key('prep-export-pgn')));
      await tester.pumpAndSettle();

      expect(find.text('Exported PGN Text'), findsOneWidget);
      final shown = tester
          .widget<SelectableText>(find.byType(SelectableText).first)
          .data!;
      expect(shown, contains('e4'));
      expect(shown, contains('e5'));
      // The seven-tag roster, which `MoveTree.exportToPgn` does not write and a
      // reader outside this app expects.
      expect(shown, contains('[Event "Preparation"]'));

      await leave(tester);
    });

    testWidgets('an empty board has nothing to export', (tester) async {
      await openPreparation(tester);

      await tester.tap(find.byKey(const Key('prep-export-pgn')));
      await tester.pumpAndSettle();

      expect(find.text('Exported PGN Text'), findsNothing);
      expect(find.textContaining('no moves on this board'), findsOneWidget);

      await leave(tester);
    });
  });
}
