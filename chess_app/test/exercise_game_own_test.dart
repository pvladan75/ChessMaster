// exercise_game_own_test.dart — what `docs/gates/exercise_game_test.dart`
// cannot reach: the sheet's layout and refusals for a game exercise, the
// exercise screen waiting for the server's word at a move target, and the
// homework row saying a game was played and not yet judged.
//
// `docs/briefs/BRIEF-EXERCISE-FAZA3B-APP.md`, „Your own tests".

import 'dart:async';
import 'dart:convert';

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/models/engine_game_task.dart';
import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/exercises/widgets/make_exercise_sheet.dart';
import 'package:chess_app/features/homework/screens/homework_assignment_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/screens/ai_studio_screen.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board/skinned_chess_board.dart';

import 'support/landscape.dart';

/// King, rook and lone king — three pieces, well inside the tablebase's
/// seven, so „Win"/„Draw or better" for N moves is judged, never refused.
const _krk = '8/8/8/8/8/4k3/8/R3K3 w - - 0 1';

/// The starting position: 32 pieces, well past the tablebase's seven.
const _fullBoard = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

class _Recorder {
  final requests = <http.Request>[];
  Map<String, dynamic> bodyOf(int i) =>
      jsonDecode(requests[i].body) as Map<String, dynamic>;
}

Future<void> _pumpAtSize(WidgetTester tester, Size size, Widget child) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: Scaffold(body: Builder(builder: (context) => child)),
  ));
  await tester.pumpAndSettle();
}

Widget _sheet({required http.Client client, required MoveTree tree}) =>
    MakeExerciseSheet(
      api: ExerciseApiService(authToken: 't', client: client),
      moveTree: tree,
      availableUserLabels: const [],
    );

// --- the exercise screen: helpers copied from engine_game_screen_test.dart,
// which cannot export its own private functions.

final _session = UserSession(
    id: 1, token: 'tok', email: 'e@x.com', name: 'N', role: 'ucenik');

Future<void> _pumpScreen(
  WidgetTester tester,
  Size size, {
  required EngineGameTask task,
  int assignmentId = 42,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: AiStudioScreen(
        userSession: _session,
        initialCategory: 'engine_game',
        engineGameTask: task,
        assignmentId: assignmentId,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tapSquare(WidgetTester tester, String square,
    {required bool whiteAtBottom}) async {
  final rect = tester.getRect(find.byType(SkinnedChessBoard).first);
  final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
  final rank = int.parse(square.substring(1));
  final col = whiteAtBottom ? file : 7 - file;
  final row = whiteAtBottom ? 8 - rank : rank - 1;
  final squareSize = rect.width / 8;
  final point = rect.topLeft +
      Offset(
          col * squareSize + squareSize / 2, row * squareSize + squareSize / 2);
  await tester.tapAt(point);
  await tester.pump();
}

Future<void> _playMove(WidgetTester tester, String from, String to,
    {required bool whiteAtBottom}) async {
  await _tapSquare(tester, from, whiteAtBottom: whiteAtBottom);
  await _tapSquare(tester, to, whiteAtBottom: whiteAtBottom);
}

String _fenAfter(String startFen, List<String> sanMoves) {
  final game = chess.Chess.fromFEN(startFen);
  for (final san in sanMoves) {
    if (!game.move(san)) {
      throw StateError('test setup: "$san" is not legal after $sanMoves '
          'from $startFen');
    }
  }
  return game.fen;
}

Future<void> _fakeEngineReply(
    WidgetTester tester, String bestMove, String analyzedFen) async {
  final service = StockfishService();
  final callback = service.onEvaluationChanged;
  expect(callback, isNotNull,
      reason: 'the screen must have attached to the engine by now');
  callback!('1.00', bestMove, '', 1, 40, true, analyzedFen);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1100));
  await tester.pump();
}

/// The moves of the fixture's first `forMoves.judged` case
/// (`docs/gates/engine_game_cases.json`): the student plays White, Ra8, the
/// engine replies Kd3, and Ra3+ reaches the move target with three pieces
/// left. As a **hold** a tablebase must judge what was reached; as a **win**
/// it is a checkmate in two that was not given, and nobody is asked.
EngineGameTask _holdForTwoMovesTask() => EngineGameTask.fromJson({
      'fen': _krk,
      'side': 'w',
      'goal': 'hold',
      'surviveMoves': 2,
    })!;

EngineGameTask _mateInTwoTask() => EngineGameTask.fromJson({
      'fen': _krk,
      'side': 'w',
      'goal': 'win',
      'surviveMoves': 2,
    })!;

Future<void> _playToTheMoveTarget(WidgetTester tester) async {
  await _playMove(tester, 'a1', 'a8', whiteAtBottom: true);
  await tester.pump();
  await _fakeEngineReply(tester, 'e3d3', _fenAfter(_krk, ['Ra8']));
  await _playMove(tester, 'a8', 'a3', whiteAtBottom: true);
  await tester.pump();
}

void main() {
  setUpAll(loadRoboto);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final service = StockfishService();
    service.onEvaluationChanged = null;
    service.onMultiPVUpdated = null;
    AppSettingsService.instance.setEnginePlayLevel('srednje');
  });

  group('the sheet: a game exercise', () {
    for (final size in [const Size(360, 640), const Size(640, 360)]) {
      testWidgets(
          'Win, for N moves, at ${size.width.toInt()}x${size.height.toInt()}: '
          'no overflow, Save off until a side is chosen, the judge sentence '
          'is there', (tester) async {
        await _pumpAtSize(
          tester,
          size,
          _sheet(
            client: MockClient((r) async => http.Response('{}', 500)),
            tree: MoveTree(startingFen: _krk),
          ),
        );

        await tester.tap(find.byKey(const Key('exercise-ask-win')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('exercise-length-forMoves')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'the sheet must lay out at this size');

        expect(find.byKey(const Key('exercise-judge-words')), findsOneWidget);

        await tester
            .ensureVisible(find.byKey(const Key('exercise-name-field')));
        await tester.enterText(
            find.byKey(const Key('exercise-name-field')), 'Rook endgame');
        await tester.pump();
        final beforeSide = tester.widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Save'));
        expect(beforeSide.onPressed, isNull,
            reason: 'a side is not chosen yet — nothing is pre-selected');

        await tester.ensureVisible(find.byKey(const Key('exercise-side-w')));
        await tester.tap(find.byKey(const Key('exercise-side-w')));
        await tester.pump();
        final afterSide = tester.widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Save'));
        expect(afterSide.onPressed, isNotNull,
            reason: 'a side is chosen, the position is judgeable: Save works');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
        'an empty tree, Draw or better: Save works, and the request carries '
        'the task, no solution, and the root\'s fen', (tester) async {
      final rec = _Recorder();
      final tree = MoveTree(startingFen: _krk);
      await tester.pumpWidget(MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: Scaffold(
          body: Builder(
            builder: (context) => _sheet(
              client: MockClient((r) async {
                rec.requests.add(r);
                return http.Response(
                    jsonEncode({
                      'exercise': {
                        'id': 'ex_1',
                        'fen': _krk,
                        'sideToMove': 'w',
                        'name': 'Hold it',
                        'origin': 'manual',
                        'task': {'type': 'game', 'side': 'w', 'goal': 'hold'},
                        'assignable': true,
                      }
                    }),
                    201);
              }),
              tree: tree,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('exercise-ask-hold')));
      await tester.pumpAndSettle();

      // No line is played on the board — the tree is empty — yet this is
      // not the „play the solution first" refusal, which applies to Find
      // alone.
      expect(find.textContaining('Play the solution on the board first'),
          findsNothing);
      await tester.ensureVisible(find.byKey(const Key('exercise-side-w')));
      await tester.tap(find.byKey(const Key('exercise-side-w')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('exercise-name-field')));
      await tester.enterText(
          find.byKey(const Key('exercise-name-field')), 'Hold it');
      await tester.pump();

      final save = tester
          .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Save'));
      expect(save.onPressed, isNotNull);

      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      expect(rec.requests, hasLength(1));
      final body = rec.bodyOf(0);
      expect(body['fen'], _krk);
      expect(body.containsKey('solution'), isFalse,
          reason: 'a game exercise has no line to replay');
      final task = body['task'] as Map<String, dynamic>;
      expect(task['type'], 'game');
      expect(task['side'], 'w');
      expect(task['goal'], 'hold');
      expect(task.containsKey('surviveMoves'), isFalse,
          reason: 'to the end of the game: no number is sent');
    });

    testWidgets(
        'more than seven pieces, Win, checkmate in N moves: said in those '
        'words, Save on, the number sent', (tester) async {
      final rec = _Recorder();
      await _pumpAtSize(
        tester,
        const Size(400, 800),
        _sheet(
          client: MockClient((r) async {
            rec.requests.add(r);
            return http.Response('{}', 500);
          }),
          tree: MoveTree(startingFen: _fullBoard),
        ),
      );
      // Under „Draw or better" the same chip keeps its old words.
      await tester.tap(find.byKey(const Key('exercise-ask-hold')));
      await tester.pumpAndSettle();
      expect(find.text('For N moves'), findsOneWidget);
      expect(find.text('Checkmate in N moves'), findsNothing);

      await tester.tap(find.byKey(const Key('exercise-ask-win')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('exercise-length-forMoves')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('exercise-side-w')));
      await tester.tap(find.byKey(const Key('exercise-side-w')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('exercise-name-field')));
      await tester.enterText(
          find.byKey(const Key('exercise-name-field')), 'Too many pieces');
      await tester.pump();

      expect(find.text('Checkmate in N moves'), findsOneWidget);
      expect(find.text('For N moves'), findsNothing);
      expect(
        find.text("Met only by checkmate within that many of the student's "
            'own moves.'),
        findsOneWidget,
      );
      final save = tester
          .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Save'));
      expect(save.onPressed, isNotNull,
          reason: 'the rules judge a mate: thirty-two pieces are no obstacle');

      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();
      expect(rec.requests, hasLength(1));
      final task = (jsonDecode(rec.requests.single.body)
          as Map<String, dynamic>)['task'] as Map<String, dynamic>;
      expect(task['goal'], 'win');
      expect(task['surviveMoves'], 5);
    });
  });

  group('checkmate in N moves, not given', () {
    testWidgets(
        'still winning with three pieces: „Goal not met" at once, in its own '
        'words — and a server that says otherwise is not believed',
        (tester) async {
      await http.runWithClient(() async {
        await _pumpScreen(tester, const Size(800, 900), task: _mateInTwoTask());
        expect(find.text('You are White — checkmate in 2 moves · 2 left'),
            findsOneWidget);
        await _playToTheMoveTarget(tester);
        await tester.pumpAndSettle();

        expect(find.text('Goal not met'), findsOneWidget);
        expect(find.text('Goal met'), findsNothing);
        expect(find.text('Not judged yet'), findsNothing);
        expect(find.text('The game ended: no checkmate in 2 moves.'),
            findsOneWidget);
      },
          () => MockClient((request) async => http.Response(
              jsonEncode({
                'ok': true,
                'goalMet': true,
                'judgedBy': 'tablebase',
                'pending': false,
              }),
              200)));
    });
  });

  group('the exercise screen waits for the server at a move target', () {
    testWidgets(
        'goalMet: true — the dialog is absent before the answer, then says '
        'the server\'s word', (tester) async {
      final completer = Completer<http.Response>();
      await http.runWithClient(() async {
        await _pumpScreen(tester, const Size(800, 900),
            task: _holdForTwoMovesTask());
        await _playToTheMoveTarget(tester);

        expect(find.text('Goal met'), findsNothing);
        expect(find.text('Not judged yet'), findsNothing,
            reason: 'the dialog is absent before the answer, not showing a '
                'placeholder either');

        completer.complete(http.Response(
            jsonEncode({
              'ok': true,
              'goalMet': true,
              'judgedBy': 'tablebase',
              'pending': false,
            }),
            200));
        await tester.pumpAndSettle();

        expect(find.text('Goal met'), findsOneWidget);
      }, () => MockClient((request) async => completer.future));
    });

    testWidgets('pending: true — „not judged yet", never „Goal not met"',
        (tester) async {
      await http.runWithClient(() async {
        await _pumpScreen(tester, const Size(800, 900),
            task: _holdForTwoMovesTask());
        await _playToTheMoveTarget(tester);
        await tester.pumpAndSettle();

        expect(find.text('Not judged yet'), findsOneWidget);
        expect(find.text('Goal not met'), findsNothing);
        expect(find.text('Goal met'), findsNothing);
      },
          () => MockClient((request) async => http.Response(
              jsonEncode({
                'ok': true,
                'goalMet': null,
                'judgedBy': null,
                'pending': true
              }),
              200)));
    });

    testWidgets(
        'a failed request — still „not judged yet", the game still '
        'ends on screen', (tester) async {
      await http.runWithClient(() async {
        await _pumpScreen(tester, const Size(800, 900),
            task: _holdForTwoMovesTask());
        await _playToTheMoveTarget(tester);
        await tester.pumpAndSettle();

        expect(find.text('Not judged yet'), findsOneWidget);
      }, () => MockClient((request) async => throw Exception('offline')));
    });
  });

  group('the homework row: a game played and not judged', () {
    testWidgets('the words are there, scoped to that row', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final parent = {
        'id': 55,
        'title': 'Endgame practice',
        'instructions': null,
        'kind': 'homework',
        'trainer_id': 9,
        'student_id': 1,
        'trainer_name': 'Trainer',
        'due_at': null,
        'completed_at': null,
        'total_items': 0,
        'attempted_items': 0,
        'solved_items': 0,
        'child_total': 1,
        'child_completed': 0,
        'children': [
          {
            'id': 901,
            'title': 'Play it out',
            'kind': 'engine_game',
            'position': 0,
            'item_key': 'k0',
            'lesson_id': null,
            'gate': true,
            'gate_opened_at': null,
            'completed_at': null,
            'task': null,
            'total_items': 1,
            'attempted_items': 1,
            'solved_items': 0,
            'pending_items': 1,
            'passed': false,
            'locked': false,
            'blocked_by': null,
          },
        ],
      };

      final client = MockClient((request) async {
        if (request.url.path == '/assignments/55') {
          return http.Response(jsonEncode(parent), 200);
        }
        return http.Response('{"error":"not found"}', 404);
      });

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: ThemeData.dark()
              .copyWith(extensions: const [AppColorTokens.dark]),
          home: HomeworkAssignmentScreen(
            session: UserSession(
                token: 'tok',
                id: 1,
                email: 's@example.com',
                name: 'Student',
                role: 'ucenik'),
            assignmentId: 55,
            api: AssignmentApiService(authToken: 'tok', client: client),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final row = find.byKey(const Key('homework-child-901'));
      expect(row, findsOneWidget);
      expect(
        find.descendant(
            of: row,
            matching: find.byKey(const Key('homework-child-pending-901'))),
        findsOneWidget,
      );
      expect(
        find.descendant(
            of: row, matching: find.text('Played — not judged yet')),
        findsOneWidget,
      );
    });
  });
}
