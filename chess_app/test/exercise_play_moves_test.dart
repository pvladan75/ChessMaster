// „Play N moves" — a game with no goal, judged by the trainer —
// `docs/PLAN-EXERCISE.md`, §10, phase 15.
//
// The owner (20.9.2026): a trainer wants to see how a student plays a
// middlegame, not whether some goal was met; he is the judge, and to be one he
// needs the game on a board (phase 13) and somewhere to say what he thinks.
// Until this phase nothing let a trainer record a verdict at all — „the
// position reached is yours to judge" was a sentence with no button under it.
//
// Stands on the `play` half of `docs/gates/engine_game_cases.json`, which the
// server's `engine_game_play.test.js` and `homework_gate.test.js` read too.
//
// THE WIRE the review card uses: `POST /assignments/:id/game-verdict`, body
// `{ met: true | false }` → `{ goalMet, judgedBy: 'trainer', pending: false }`.

import 'dart:convert';
import 'dart:io';

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/core/models/drill_outcome.dart';
import 'package:chess_app/core/models/engine_game_said.dart';
import 'package:chess_app/core/models/engine_game_task.dart';
import 'package:chess_app/features/assignments/screens/assignment_review_screen.dart';
import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/features/exercises/models/exercise.dart';
import 'package:chess_app/features/exercises/models/exercise_task_words.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/exercises/services/exercise_checker.dart';
import 'package:chess_app/features/exercises/widgets/make_exercise_sheet.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/theme/app_colors.dart';

import 'support/landscape.dart' show loadRoboto;

Map<String, dynamic> _play() {
  final file = File('../docs/gates/engine_game_cases.json');
  if (!file.existsSync()) {
    throw StateError('the shared fixture is missing: ${file.absolute.path}');
  }
  final all = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return all['play'] as Map<String, dynamic>;
}

String _outcomeName(DrillOutcome outcome) => switch (outcome) {
      DrillOutcome.readerWon => 'won',
      DrillOutcome.readerLost => 'lost',
      DrillOutcome.drawn => 'drawn',
      DrillOutcome.undecided => 'undecided',
    };

EngineGameVerdict _verdictOf(Map<String, dynamic> c) {
  final task =
      EngineGameTask.fromJson(Map<String, dynamic>.from(c['task'] as Map));
  if (task == null) throw StateError('unreadable task in: ${c['name']}');
  final game = chess.Chess.fromFEN(task.fen);
  var ownMoves = 0;
  for (final san in (c['moves'] as List).cast<String>()) {
    if (game.turn == task.side) ownMoves++;
    if (!game.move(san)) throw StateError('illegal in fixture: $san');
  }
  return engineGameVerdict(task: task, game: game, ownMoves: ownMoves);
}

/// The real checker over two askers that only count — the client is faked,
/// not the method, so a question that goes missing is seen to go missing.
class _CountingChecker {
  int asked = 0;

  late final ExerciseChecker checker = ExerciseChecker(
    tablebase: (fen) async {
      asked++;
      return null;
    },
    engine: (fen) async {
      asked++;
      return const [];
    },
  );
}

const _trainerId = 9;
const _studentId = 1;
const _krk = '8/8/8/8/8/4k3/8/R3K3 w - - 0 1';

UserSession _session(int id) => UserSession(
      token: 'tok',
      id: id,
      email: 'a@example.com',
      name: id == _trainerId ? 'Trainer' : 'Student',
      role: id == _trainerId ? 'trener' : 'ucenik',
    );

Map<String, dynamic> _gameItem({
  String goal = 'play',
  bool? solved,
  String? judgedBy,
  bool pending = true,
  bool attempted = true,
  String ending = 'moveTarget',
}) =>
    {
      'itemId': 7,
      'position': 0,
      'puzzleId': null,
      'kind': 'game',
      'attempted': attempted,
      'attemptedAt': attempted ? '2026-09-20T14:00:00.000Z' : null,
      'solved': solved,
      'msTaken': null,
      'playedSan': null,
      'title': null,
      'instruction': null,
      'fen': _krk,
      'task': {'type': 'game', 'side': 'w', 'goal': goal, 'surviveMoves': 2},
      'moves': attempted ? ['Ra8', 'Kd3', 'Ra3+'] : <String>[],
      'finalFen': attempted ? '8/8/8/8/8/R2k4/8/4K3 b - - 3 2' : null,
      'ending': attempted ? ending : null,
      'judgedBy': judgedBy,
      'pending': pending,
    };

void main() {
  final fixture = _play();
  final judged = (fixture['judged'] as List).cast<Map<String, dynamic>>();
  final rejected = (fixture['rejected'] as List).cast<Map<String, dynamic>>();

  setUpAll(loadRoboto);

  group('the app stops where the server stops, and judges nothing', () {
    test('the fixture has what the loops below need', () {
      expect(judged.length, greaterThanOrEqualTo(4));
      expect(rejected.length, greaterThanOrEqualTo(2));
      expect(judged.any((c) => (c['expect'] as Map)['ending'] == 'checkmate'),
          isTrue);
      expect(judged.any((c) => (c['expect'] as Map)['ending'] == null), isTrue);
    });

    for (final c in judged) {
      test('${c['name']}', () {
        final verdict = _verdictOf(c);
        final want = c['expect'] as Map<String, dynamic>;
        expect(verdict.ending?.name, want['ending'], reason: 'ending');
        expect(verdict.needsTrainer, isTrue, reason: 'the trainer judges');
        expect(verdict.needsTablebase, isFalse, reason: 'nobody else is asked');
        if (want.containsKey('outcome')) {
          expect(_outcomeName(verdict.outcome), want['outcome']);
        }
        if (want.containsKey('ownMoves')) {
          expect(verdict.ownMoves, want['ownMoves']);
        }
      });
    }

    test('control: the same game under a goal is nobody\'s to judge', () {
      final c = fixture['control'] as Map<String, dynamic>;
      final verdict = _verdictOf(c);
      expect(verdict.needsTrainer, isFalse);
      expect(verdict.goalMet, (c['expect'] as Map)['goalMet']);
    });

    for (final c in rejected) {
      test('refused: ${c['name']}', () {
        expect(
          EngineGameTask.fromJson(Map<String, dynamic>.from(c['task'] as Map)),
          isNull,
        );
      });
    }

    test('whatever the server answers, a game with no goal is not judged yet',
        () {
      // Won on the board, and a server that (wrongly) said „met": neither is
      // a verdict. Only the trainer's is.
      final mated = _verdictOf(judged
          .firstWhere((c) => (c['expect'] as Map)['ending'] == 'checkmate'));
      for (final server in [
        null,
        const EngineGameServerVerdict(
            goalMet: true, judgedBy: 'rules', pending: false),
        const EngineGameServerVerdict(
            goalMet: null, judgedBy: null, pending: true),
      ]) {
        expect(engineGameSaid(mated, server), EngineGameSaid.notJudged);
      }
    });
  });

  group('the words', () {
    const task = {
      'type': 'game',
      'side': 'w',
      'goal': 'play',
      'surviveMoves': 12
    };

    test('what is asked, in every place that says it', () {
      expect(exerciseAskOf(task), ExerciseAsk.play);
      expect(exerciseTaskWords(task), 'Play 12 moves as White');
      expect(exerciseTaskWords({...task, 'side': 'b', 'surviveMoves': 1}),
          'Play 1 move as Black');
      // The other goals read as they did.
      expect(exerciseAskOf({...task, 'goal': 'hold'}), ExerciseAsk.hold);
      expect(exerciseAskOf({...task, 'goal': 'survive'}), ExerciseAsk.hold);
      expect(exerciseAskOf({...task, 'goal': 'win'}), ExerciseAsk.win);
    });

    test('over the board and in the closing dialog', () {
      final t = EngineGameTask.fromJson({...task, 'fen': _krk})!;
      expect(engineGameGoalSentence(t, ownMoves: 5),
          'You are White — play 12 moves · 7 left');
      expect(
          engineGameEndingWords(t, GameEnding.moveTarget), '12 moves played');
    });

    test('the trainer is told there is no automatic verdict', () {
      final judge =
          exerciseJudgeFor(fen: _krk, ask: ExerciseAsk.play, forMoves: 12);
      expect(judge, ExerciseJudge.trainer);
      expect(exerciseJudgeWords(judge), contains('No automatic verdict'));
    });

    test('the task that is sent, and never without its number', () {
      expect(
        exerciseGameTask(
            side: 'b', ask: ExerciseAsk.play, forMoves: 8, level: 'tesko'),
        {
          'type': 'game',
          'side': 'b',
          'goal': 'play',
          'surviveMoves': 8,
          'level': 'tesko'
        },
      );
      expect(() => exerciseGameTask(side: 'b', ask: ExerciseAsk.play),
          throwsArgumentError);
    });
  });

  group('the sheet', () {
    Future<(List<http.Request>, _CountingChecker)> pumpSheet(
      WidgetTester tester, {
      Size size = const Size(900, 1400),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final requests = <http.Request>[];
      final checker = _CountingChecker();
      final client = MockClient((request) async {
        requests.add(request);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'exercise': {
              'id': 'ex_0123456789abcdef',
              'fen': body['fen'],
              'sideToMove': 'w',
              'name': body['name'],
              'instruction': null,
              'themes': <String>[],
              'origin': 'manual',
              'task': body['task'],
              'solution': null,
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
          body: MakeExerciseSheet(
            api: ExerciseApiService(authToken: 't', client: client),
            moveTree: MoveTree(startingFen: _krk),
            availableUserLabels: const [],
            checker: checker.checker,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return (requests, checker);
    }

    ElevatedButton save(WidgetTester tester) => tester
        .widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Save'));

    testWidgets('asks how many moves, and has no „to the end"', (tester) async {
      await pumpSheet(tester);
      // Control: the other game tasks do offer it.
      await tester.tap(find.byKey(const Key('exercise-ask-win')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('exercise-length-toEnd')), findsOneWidget);
      expect(find.byKey(const Key('exercise-for-moves-field')), findsNothing);

      await tester.tap(find.byKey(const Key('exercise-ask-play')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('exercise-length-toEnd')), findsNothing);
      expect(find.byKey(const Key('exercise-length-forMoves')), findsNothing);
      expect(find.byKey(const Key('exercise-for-moves-field')), findsOneWidget);
      expect(find.byKey(const Key('exercise-play-the-move')), findsNothing,
          reason: 'that is Find\'s');
      expect(
          tester
              .widget<Text>(find.byKey(const Key('exercise-judge-words')))
              .data,
          contains('No automatic verdict'));
    });

    testWidgets('saves the task with its number, and checks nothing',
        (tester) async {
      final (requests, checker) = await pumpSheet(tester);
      await tester.tap(find.byKey(const Key('exercise-ask-play')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('exercise-side-b')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('exercise-name-field')), 'Middlegame');
      await tester.pump();

      // A number that cannot be read is not a task to save.
      await tester.enterText(
          find.byKey(const Key('exercise-for-moves-field')), '');
      await tester.pump();
      expect(save(tester).onPressed, isNull);
      await tester.enterText(
          find.byKey(const Key('exercise-for-moves-field')), '12');
      await tester.pump();
      expect(save(tester).onPressed, isNotNull);

      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      expect(requests, hasLength(1));
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body['fen'], _krk);
      expect(body['task'], {
        'type': 'game',
        'side': 'b',
        'goal': 'play',
        'surviveMoves': 12,
        'level': 'srednje',
      });
      expect(body['solution'], isNull);
      expect(checker.asked, 0,
          reason: 'there is no goal for a tablebase or an engine to doubt');
    });

    testWidgets('control: a goal is still checked as it is made',
        (tester) async {
      final (_, checker) = await pumpSheet(tester);
      await tester.tap(find.byKey(const Key('exercise-ask-win')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('exercise-side-w')));
      await tester.pumpAndSettle();
      expect(checker.asked, greaterThan(0));
    });

    for (final size in [const Size(360, 640), const Size(640, 360)]) {
      testWidgets('holds at ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        await pumpSheet(tester, size: size);
        await tester.tap(find.byKey(const Key('exercise-ask-play')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('the trainer\'s verdict', () {
    final met = find.byKey(const Key('review-game-judge-met-7'));
    final notMet = find.byKey(const Key('review-game-judge-not-met-7'));
    final card = find.byKey(const Key('review-game-7'));

    Future<List<http.Request>> pumpReview(
      WidgetTester tester,
      Map<String, dynamic> item, {
      int viewer = _trainerId,
      Size size = const Size(900, 1400),
      Map<String, dynamic>? afterVerdict,
      int verdictStatus = 200,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final isTrainer = viewer == _trainerId;
      var current = item;
      final posts = <http.Request>[];
      final client = MockClient((request) async {
        if (request.url.path == '/assignments/603/review') {
          return http.Response(
            jsonEncode({
              'assignment': {
                'id': 603,
                'title': 'Play it out',
                'kind': 'engine_game',
                'instructions': null,
                'dueAt': null,
                'completedAt': '2026-09-20T14:00:00.000Z',
                'createdAt': '2026-09-20T13:00:00.000Z',
                'trainerName': 'Trainer',
                'studentName': 'Ana',
              },
              'viewer': {'isTrainer': isTrainer, 'isStudent': !isTrainer},
              'items': [current],
              'notes': <dynamic>[],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.method == 'POST') {
          posts.add(request);
          if (verdictStatus != 200) {
            return http.Response(
                jsonEncode({
                  'error': 'This game has been judged already, and not by you.'
                }),
                verdictStatus,
                headers: {'content-type': 'application/json; charset=utf-8'});
          }
          // What the server stored is what the next read shows.
          if (afterVerdict != null) current = afterVerdict;
          return http.Response(
              jsonEncode(
                  {'goalMet': true, 'judgedBy': 'trainer', 'pending': false}),
              200);
        }
        return http.Response('{"error":"not found"}', 404);
      });
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: ThemeData.dark()
              .copyWith(extensions: const [AppColorTokens.dark]),
          home: AssignmentReviewScreen(
            session: _session(viewer),
            assignmentId: 603,
            title: 'Play it out',
            api: AssignmentApiService(authToken: 'tok', client: client),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return posts;
    }

    Finder inCard(Finder what) => find.descendant(of: card, matching: what);

    testWidgets('a game with no goal waits for the trainer, in words',
        (tester) async {
      await pumpReview(tester, _gameItem());
      expect(inCard(find.text('Play 2 moves as White')), findsOneWidget);
      expect(inCard(find.text('Not judged yet')), findsOneWidget);
      // The buttons say what they do; nothing on an unjudged card reads as a
      // verdict already given.
      expect(inCard(find.text('Goal met')), findsNothing);
      expect(inCard(find.text('Goal not met')), findsNothing);
      expect(inCard(find.text('Mark as met')), findsOneWidget);
      expect(inCard(find.text('Mark as not met')), findsOneWidget);
      expect(inCard(find.textContaining('has no goal')), findsOneWidget);
      expect(inCard(find.textContaining('tablebase')), findsNothing);
      expect(met, findsOneWidget);
      expect(notMet, findsOneWidget);
    });

    testWidgets('the verdict is sent, and the card shows what was stored',
        (tester) async {
      final posts = await pumpReview(
        tester,
        _gameItem(),
        afterVerdict:
            _gameItem(solved: true, judgedBy: 'trainer', pending: false),
      );
      await tester.ensureVisible(met);
      await tester.tap(met);
      await tester.pumpAndSettle();

      expect(posts, hasLength(1));
      expect(posts.single.url.path, '/assignments/603/game-verdict');
      expect(jsonDecode(posts.single.body), {'met': true});
      expect(inCard(find.text('Judged by the trainer')), findsOneWidget);
      expect(inCard(find.text('Goal met')), findsOneWidget);
      expect(inCard(find.text('Not judged yet')), findsNothing);
      // Still the trainer's to change.
      expect(notMet, findsOneWidget);
    });

    testWidgets('„not met" sends a no, not an absence', (tester) async {
      final posts = await pumpReview(tester, _gameItem());
      await tester.ensureVisible(notMet);
      await tester.tap(notMet);
      await tester.pumpAndSettle();
      expect(jsonDecode(posts.single.body), {'met': false});
    });

    testWidgets('a refusal is said in the server\'s words and changes nothing',
        (tester) async {
      await pumpReview(tester, _gameItem(), verdictStatus: 409);
      await tester.ensureVisible(met);
      await tester.tap(met);
      await tester.pumpAndSettle();
      expect(find.textContaining('judged already'), findsOneWidget);
      expect(inCard(find.text('Not judged yet')), findsOneWidget);
    });

    testWidgets('the student is told who will judge, and has no buttons',
        (tester) async {
      await pumpReview(tester, _gameItem(), viewer: _studentId);
      expect(inCard(find.text('Your trainer will look at this game.')),
          findsOneWidget);
      expect(inCard(find.textContaining('yours to judge')), findsNothing);
      expect(met, findsNothing);
      expect(notMet, findsNothing);
    });

    testWidgets('what the rules or a tablebase judged is not the trainer\'s',
        (tester) async {
      for (final by in ['rules', 'tablebase']) {
        await pumpReview(
          tester,
          _gameItem(goal: 'hold', solved: false, judgedBy: by, pending: false),
        );
        expect(card, findsOneWidget);
        expect(met, findsNothing, reason: by);
        expect(notMet, findsNothing, reason: by);
      }
    });

    testWidgets('the judge of last resort: a game no tablebase answered',
        (tester) async {
      await pumpReview(tester, _gameItem(goal: 'hold'));
      expect(inCard(find.textContaining('No tablebase answer yet')),
          findsOneWidget);
      expect(met, findsOneWidget);
    });

    testWidgets('a game nobody played has nothing to judge', (tester) async {
      await pumpReview(tester, _gameItem(attempted: false, pending: false));
      expect(card, findsOneWidget);
      expect(met, findsNothing);
    });

    testWidgets('the card holds its buttons on a phone', (tester) async {
      await pumpReview(tester, _gameItem(), size: const Size(360, 640));
      await tester.ensureVisible(notMet);
      expect(tester.takeException(), isNull);
    });
  });
}
