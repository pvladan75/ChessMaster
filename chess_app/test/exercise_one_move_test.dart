// A find exercise is ONE move, and it is made on the exercise's own screen —
// `docs/PLAN-EXERCISE.md`, §10, phase 14.
//
// The owner's parked question 2 (20.9.2026): „Make exercise → Find the move"
// wanted the solution played on the room's board *first*, and said so only
// after the sheet had opened over a board with nothing on it — a red sentence
// and a dead Save. With one move there is nothing to play in advance: the
// sheet offers „Play the move", the exercise's screen opens on the position,
// the first move played there is the answer and every further one an accepted
// alternative.
//
// Stands on `docs/gates/exercise_line_cases.json` (`oneMove`), the fixture the
// server's writer is held to by `chess_backend/test/exercise_authoring.test.js`.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/exercises/models/exercise.dart';
import 'package:chess_app/features/exercises/models/exercise_line.dart';
import 'package:chess_app/features/exercises/models/exercise_line_edit.dart';
import 'package:chess_app/features/exercises/screens/exercise_editor_screen.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/exercises/widgets/make_exercise_sheet.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

import 'support/landscape.dart' show loadRoboto;

Map<String, dynamic> _fixture() {
  final file = File('../docs/gates/exercise_line_cases.json');
  if (!file.existsSync()) {
    throw StateError('the shared fixture is missing: ${file.absolute.path}');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

List<Map<String, dynamic>> _wire(List<ExerciseStep> steps) =>
    [for (final s in steps) s.toJson()];

class _Recorder {
  final requests = <http.Request>[];
  Map<String, dynamic> bodyOf(int i) =>
      jsonDecode(requests[i].body) as Map<String, dynamic>;
}

void main() {
  final fixture = _fixture();
  final positions = (fixture['positions'] as Map).cast<String, String>();
  final solutions = (fixture['solutions'] as Map).cast<String, dynamic>();
  final scholar = positions['scholar']!;
  final scholarFirst =
      (solutions['scholarFirst'] as Map)['normalised'] as List<dynamic>;

  setUpAll(loadRoboto);

  MoveTree tree(String pgn) {
    final parsed = MoveTree.parsePgn(pgn, startingFen: scholar);
    if (parsed == null) throw StateError('the test\'s own PGN did not parse');
    return parsed;
  }

  group('the writer reads the first move and nothing after it', () {
    test('the fixture\'s one-move solution is what it names', () {
      // Control: everything below compares against this.
      expect(scholarFirst, [
        {
          'accept': ['Qh5', 'Qf3'],
          'reply': null
        }
      ]);
    });

    test('the first move, its variations as alternatives, no reply', () {
      final reading = ExerciseLine.fromTree(tree('2. Qh5 (2. Qf3)'));
      expect(reading.ok, isTrue, reason: reading.error);
      expect(_wire(reading.steps), scholarFirst);
      expect(reading.laterMovesIgnored, isFalse);
    });

    test('a line that goes on is cut after the first move, and says so', () {
      // The line phase 2b wrote whole: it is two moves, which the server now
      // refuses (`oneMove.refused`). What this app sends is its first.
      final reading =
          ExerciseLine.fromTree(tree('2. Qh5 (2. Qf3) 2... g6 3. Qxe5+'));
      expect(reading.ok, isTrue, reason: reading.error);
      expect(_wire(reading.steps), scholarFirst);
      expect(reading.laterMovesIgnored, isTrue);
    });

    test('moves under an alternative are later moves too', () {
      final reading = ExerciseLine.fromTree(tree('2. Qh5 (2. Qf3 Nc6)'));
      expect(_wire(reading.steps), scholarFirst);
      expect(reading.laterMovesIgnored, isTrue);
    });

    test('nothing this writer makes is longer than the server takes', () {
      for (final pgn in [
        '2. Qh5',
        '2. Qh5 g6',
        '2. Qh5 (2. Qf3) 2... g6 3. Qxe5+ Qe7 4. Qxh8',
      ]) {
        expect(ExerciseLine.fromTree(tree(pgn)).steps, hasLength(1),
            reason: pgn);
      }
    });

    test('a tree with no moves is not a solution', () {
      final reading = ExerciseLine.fromTree(MoveTree(startingFen: scholar));
      expect(reading.ok, isFalse);
    });

    test('the move is the root\'s, wherever the trainer is standing', () {
      final t = tree('2. Qh5 (2. Qf3) 2... g6 3. Qxe5+');
      var node = t.root;
      while (node.children.isNotEmpty) {
        node = node.children.first;
      }
      t.current = node;
      expect(_wire(ExerciseLine.fromTree(t).steps), scholarFirst);
    });
  });

  group('the answer, entered from nothing', () {
    test('an empty answer is not a refusal', () {
      final edit = ExerciseLineEdit.empty(fen: scholar);
      expect(edit.steps, isEmpty);
      expect(edit.error, isNull);
      expect(edit.fenBefore(0), scholar);
    });

    test('the first move is the answer, the next ones its alternatives', () {
      final edit = ExerciseLineEdit.empty(fen: scholar);
      expect(edit.play('Qh5'), isTrue);
      expect(edit.play('Qf3'), isTrue);
      expect(_wire(edit.steps), scholarFirst);
    });

    test('a move the board cannot play is refused and changes nothing', () {
      final edit = ExerciseLineEdit.empty(fen: scholar);
      expect(edit.play('Qh6'), isFalse);
      expect(edit.steps, isEmpty);
      expect(edit.error, contains('cannot be played'));
      // And from a line that has its answer.
      expect(edit.play('Qh5'), isTrue);
      expect(edit.error, isNull);
      expect(edit.play('Qh5'), isFalse, reason: 'the same move twice');
      expect(edit.steps.single.accept, ['Qh5']);
    });

    test('starting over gives the answer back', () {
      final edit = ExerciseLineEdit.empty(fen: scholar)
        ..play('Qf3')
        ..play('Qh5');
      edit.clear();
      expect(edit.steps, isEmpty);
      expect(edit.error, isNull);
      expect(edit.play('Qh5'), isTrue);
      expect(edit.steps.single.accept, ['Qh5']);
    });
  });

  group('from an empty board to the request', () {
    Future<_Recorder> pumpDoor(
      WidgetTester tester, {
      Size size = const Size(900, 1200),
      List<Exercise>? saved,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final recorder = _Recorder();
      final client = MockClient((request) async {
        recorder.requests.add(request);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'exercise': {
              'id': 'ex_0123456789abcdef',
              'fen': body['fen'],
              'sideToMove': 'w',
              'name': body['name'],
              'instruction': null,
              'themes': body['themes'] ?? <String>[],
              'origin': 'manual',
              'task': body['task'],
              'solution': body['solution'],
              'needsReview': false,
              'assignable': true,
              'blockedReason': null,
            }
          }),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      await tester.pumpWidget(MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: Scaffold(
          body: MakeExerciseButton(
            api: ExerciseApiService(authToken: 't', client: client),
            moveTree: MoveTree(startingFen: scholar),
            availableUserLabels: const [],
            onSaved: (e) => saved?.add(e),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Make exercise'));
      await tester.pumpAndSettle();
      return recorder;
    }

    final playTheMove = find.byKey(const Key('exercise-play-the-move'));
    final editorSave = find.byKey(const Key('exercise-editor-save'));

    ChessBoardWithOverlay board(WidgetTester tester) => tester
        .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay));

    testWidgets('the sheet over an empty board leads, it does not refuse',
        (tester) async {
      await pumpDoor(tester);
      final sheet = find.byType(MakeExerciseSheet);
      expect(sheet, findsOneWidget);
      expect(playTheMove, findsOneWidget);
      // Scoped to the sheet: what it must not say, in any wording it had.
      expect(
          find.descendant(
              of: sheet, matching: find.textContaining('on the board first')),
          findsNothing);
      expect(
          find.descendant(
              of: sheet, matching: find.textContaining('at least one move')),
          findsNothing);
    });

    testWidgets('a game task over the same empty board has no such button',
        (tester) async {
      await pumpDoor(tester);
      await tester.tap(find.byKey(const Key('exercise-ask-win')));
      await tester.pumpAndSettle();
      expect(playTheMove, findsNothing);
    });

    testWidgets('the move is played on the exercise\'s screen and saved',
        (tester) async {
      final saved = <Exercise>[];
      final recorder = await pumpDoor(tester, saved: saved);

      await tester.tap(playTheMove);
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseEditorScreen), findsOneWidget);

      // Nothing played yet: nothing to save.
      expect(tester.widget<FilledButton>(editorSave).onPressed, isNull);

      board(tester).onMove('d1', 'h5', '');
      await tester.pumpAndSettle();
      board(tester).onMove('d1', 'f3', '');
      await tester.pumpAndSettle();
      expect(find.textContaining('Qh5'), findsWidgets);
      expect(find.textContaining('Qf3'), findsWidgets);
      // The board is for entering moves, never for playing on: it stands on
      // the exercise's own position after each.
      expect(board(tester).controller.getFen(), scholar);

      await tester.ensureVisible(editorSave);
      await tester.tap(editorSave);
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('exercise-name-field')), 'Queen out early');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      expect(recorder.requests, hasLength(1));
      expect(recorder.requests.single.method, 'POST');
      expect(recorder.requests.single.url.path, '/exercises');
      final body = recorder.bodyOf(0);
      expect(body['fen'], scholar);
      expect(body['task'], {'type': 'find'});
      expect(body['solution'], scholarFirst);
      expect(body['name'], 'Queen out early');

      // Everything that opened has closed, and the room is told.
      expect(find.byType(ExerciseEditorScreen), findsNothing);
      expect(find.byType(MakeExerciseSheet), findsNothing);
      expect(saved.single.id, 'ex_0123456789abcdef');
    });

    testWidgets('starting over takes the answer back', (tester) async {
      await pumpDoor(tester);
      await tester.tap(playTheMove);
      await tester.pumpAndSettle();
      board(tester).onMove('d1', 'f3', '');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(editorSave).onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('exercise-editor-start-over')));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(editorSave).onPressed, isNull);
      expect(find.textContaining('Qf3'), findsNothing);
    });

    for (final size in [const Size(360, 640), const Size(640, 360)]) {
      final at = '${size.width.toInt()}x${size.height.toInt()}';
      testWidgets('the making screen holds at $at', (tester) async {
        await pumpDoor(tester, size: size);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(playTheMove);
        await tester.tap(playTheMove);
        await tester.pumpAndSettle();
        board(tester).onMove('d1', 'h5', '');
        await tester.pumpAndSettle();
        board(tester).onMove('d1', 'f3', '');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
