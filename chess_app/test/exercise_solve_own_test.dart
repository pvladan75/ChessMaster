// Solving one's own exercises — the app half of docs/PLAN-MATERIJAL.md,
// phase 1.
//
// Until this phase an exercise could be answered only as homework: a trainer
// could not try their own, a student could not solve the book they scanned,
// and nobody training alone could solve anything they kept. Now:
//
// - the Library card of one's own settled find exercise has **Solve**, which
//   opens the homework's own solver over `POST /exercises/:id/attempt`;
// - Practise has a **My exercises** card, drawn only for an account that owns
//   such an exercise, whose „Solve" and „Retry failed" open `/exercises/solve`
//   (with `retry=1` for the second);
// - the card's „to retry" is the queue's count, the set the retry route
//   serves, not the log's, which still holds failures on exercises deleted
//   since.
//
// One fake server behind every seam (rule 7). A move is played by dragging a
// piece on the board, the way a reader plays it.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/services/puzzle_attempt_api.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_persistence_service.dart';
import 'package:chess_app/features/assignments/screens/custom_puzzle_solver_screen.dart';
import 'package:chess_app/features/exercises/screens/exercise_editor_screen.dart';
import 'package:chess_app/features/exercises/screens/own_exercise_solve_screen.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/homework/services/homework_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/screens/library_screen.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/position_scanner/services/scanner_api_service.dart';
import 'package:chess_app/features/training/screens/training_hub_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/lesson_recording_api.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// White mates with Ra8#.
const _mateFen = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';
const _otherFen = '6k1/5ppp/8/8/8/8/5PPP/1R4K1 w - - 0 1';
const _gameFen = '8/8/8/4k3/8/8/4P3/4K3 b - - 0 1';

final _session =
    UserSession(token: 'tok', id: 1, email: 'e', name: 'N', role: 'korisnik');

Map<String, Object?> _position(String id, String fen) => {
      'puzzle_id': id,
      'fen': fen,
      'side_to_move': 'w',
      'instruction': 'White mates in one.',
    };

class _Server {
  _Server({
    this.progress = const {},
    this.fresh = const [],
    this.retry = const [],
    this.queueFails = false,
  });

  final Map<String, Object?> progress;
  final List<Map<String, Object?>> fresh;
  final List<Map<String, Object?>> retry;
  final bool queueFails;

  final List<http.Request> requests = [];

  List<http.Request> posts(String pathPart) => requests
      .where((r) => r.method == 'POST' && r.url.path.contains(pathPart))
      .toList();

  http.Client get client => MockClient((req) async {
        requests.add(req);
        final path = req.url.path;
        if (path.endsWith('/attempt') && path.startsWith('/exercises/')) {
          final san = (jsonDecode(req.body) as Map)['moveSan'];
          final right = san == 'Ra8#';
          return http.Response(
              jsonEncode({
                'correct': right,
                'reason': right
                    ? "the author's move"
                    : 'That is not the move the exercise asks for.',
                'playedSan': san,
                'solutionSan': 'Ra8#',
              }),
              200);
        }
        if (path == '/exercises/queue') {
          if (queueFails) return http.Response('{}', 500);
          return http.Response(
              jsonEncode({'fresh': fresh, 'retry': retry}), 200);
        }
        if (path == '/api/puzzles/progress') {
          return http.Response(jsonEncode(progress), 200);
        }
        if (path.endsWith('/library/positions')) {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'kind': 'scan',
                  'id': 'cust_find',
                  'title': 'Back rank',
                  'fen': _mateFen,
                  'instruction': 'White mates in one.',
                  'hasSolution': true,
                  'isExercise': true,
                  'assignable': true,
                },
                {
                  'kind': 'scan',
                  'id': 'ex_game',
                  'title': 'Hold it',
                  'fen': _gameFen,
                  'assignable': true,
                  'origin': 'manual',
                  'task': {'type': 'game', 'side': 'b', 'goal': 'hold'},
                  'isExercise': true,
                },
                {
                  'kind': 'scan',
                  'id': 'cust_review',
                  'title': 'Side unknown',
                  'fen': _mateFen,
                  'hasSolution': true,
                  'isExercise': true,
                  'assignable': false,
                  'needsReview': true,
                },
                {
                  'kind': 'scan',
                  'id': 'cust_trainers',
                  'title': 'From my trainer',
                  'fen': _mateFen,
                  'hasSolution': true,
                  'isExercise': true,
                  'assignable': true,
                  'fromTrainer': true,
                },
                {
                  'kind': 'scan',
                  'id': 'cust_bare',
                  'title': 'A bare diagram',
                  'fen': _mateFen,
                },
              ],
            }),
            200,
          );
        }
        if (path.endsWith('/puzzle-sets')) {
          return http.Response(jsonEncode({'items': []}), 200);
        }
        if (path.endsWith('/lessons/labels')) return http.Response('[]', 200);
        if (path.endsWith('/lessons')) return http.Response('[]', 200);
        return http.Response('{"error":"not found"}', 404);
      });
}

Future<_Server> _openLibrary(WidgetTester tester,
    {Size size = const Size(1400, 1600)}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final server = _Server();
  final client = server.client;
  AnalysisPersistenceService.setInstance(
      AnalysisPersistenceService.withClient(client));
  addTearDown(AnalysisPersistenceService.resetInstance);

  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light().copyWith(extensions: const [AppColorTokens.light]),
    home: LibraryScreen(
      session: _session,
      positionLibrary: PositionLibraryService(authToken: 'tok', client: client),
      lessonApi: LessonApiService(authToken: 'tok', client: client),
      exerciseApi: ExerciseApiService(authToken: 'tok', client: client),
      homeworkApi: HomeworkApiService(authToken: 'tok', client: client),
      recordingApi: LessonRecordingApi(authToken: 'tok', client: client),
      scannerApi: ScannerApiService(authToken: 'tok', client: client),
    ),
  ));
  await tester.pumpAndSettle();
  return server;
}

Finder _solveOn(String id) => find.descendant(
      of: find.byKey(ValueKey('library-row-scan-$id')),
      matching: find.byTooltip('Solve'),
    );

Offset _square(WidgetTester tester, String square) {
  final rect = tester.getRect(find.byType(ChessBoardWithOverlay));
  return rect.topLeft + getSquareCenter(square, rect.width, PlayerColor.white);
}

Future<void> _drag(WidgetTester tester, String from, String to) async {
  await tester.dragFrom(
      _square(tester, from), _square(tester, to) - _square(tester, from));
  await tester.pumpAndSettle();
}

/// The hub, inside a router that records every place it is sent.
Future<List<Uri>> _openHub(WidgetTester tester, _Server server) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  PuzzleAttemptWrites.reset();
  addTearDown(PuzzleAttemptWrites.reset);

  final visited = <Uri>[];
  final router = GoRouter(initialLocation: '/', routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => TrainingHubScreen(
        session: _session,
        attemptApi: PuzzleAttemptApi(authToken: 'tok', client: server.client),
        exerciseApi:
            ExerciseApiService(authToken: 'tok', client: server.client),
      ),
    ),
    GoRoute(
      path: '/exercises/solve',
      builder: (_, state) {
        visited.add(state.uri);
        return const Scaffold(body: Text('solving'));
      },
    ),
  ]);
  await tester.pumpWidget(MaterialApp.router(
    routerConfig: router,
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
  ));
  await tester.pumpAndSettle();
  return visited;
}

const _ownCard = Key('hub-own-exercises');

Finder _inOwnCard(Finder f) =>
    find.descendant(of: find.byKey(_ownCard), matching: f);

void main() {
  group('the Library card', () {
    testWidgets(
        'Solve posts the move played on the board to /exercises/<id>/attempt, '
        'and never to an assignment', (tester) async {
      final server = await _openLibrary(tester);
      await tester.tap(_solveOn('cust_find'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomPuzzleSolverScreen), findsOneWidget);

      await _drag(tester, 'a1', 'a8');

      final sent = server.posts('/attempt');
      expect(sent, hasLength(1));
      expect(sent.single.url.path, '/exercises/cust_find/attempt');
      expect((jsonDecode(sent.single.body) as Map)['moveSan'], 'Ra8#');
      expect(server.requests.where((r) => r.url.path.contains('/assignments')),
          isEmpty);
      expect(find.text('Correct'), findsOneWidget);
    });

    testWidgets('one move is the answer: the board takes no second',
        (tester) async {
      final server = await _openLibrary(tester);
      await tester.tap(_solveOn('cust_find'));
      await tester.pumpAndSettle();

      await _drag(tester, 'a1', 'a5');
      expect(find.text('Not quite'), findsOneWidget);
      expect(find.text('Solution: Ra8#'), findsOneWidget);

      await _drag(tester, 'a1', 'a8');
      expect(server.posts('/attempt'), hasLength(1),
          reason: 'the board took a second answer after the verdict');
    });

    testWidgets('„Open" under the verdict leads to the exercise\'s own screen',
        (tester) async {
      await _openLibrary(tester);
      await tester.tap(_solveOn('cust_find'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('solver-open')), findsNothing,
          reason: 'the door is under a verdict, not before one');

      await _drag(tester, 'a1', 'a8');
      await tester.tap(find.byKey(const Key('solver-open')));
      await tester.pumpAndSettle();

      final editor = tester
          .widget<ExerciseEditorScreen>(find.byType(ExerciseEditorScreen));
      expect(editor.exerciseId, 'cust_find');
    });

    testWidgets(
        'Solve is on one\'s own settled find exercise only — not a game, '
        'not one marked for review, not a trainer\'s, not a bare position',
        (tester) async {
      await _openLibrary(tester);
      expect(_solveOn('cust_find'), findsOneWidget);
      for (final id in [
        'ex_game',
        'cust_review',
        'cust_trainers',
        'cust_bare',
      ]) {
        expect(find.byKey(ValueKey('library-row-scan-$id')), findsOneWidget,
            reason: 'the card $id is not on the shelf, so its absence of '
                'Solve proves nothing');
        expect(_solveOn(id), findsNothing, reason: '$id offers Solve');
      }
    });

    testWidgets('the card with Solve fits a 360 x 640 phone', (tester) async {
      await _openLibrary(tester, size: const Size(360, 640));
      await tester.ensureVisible(_solveOn('cust_find'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(_solveOn('cust_find'), findsOneWidget);
    });
  });

  group('Practise: My exercises', () {
    testWidgets(
        'the line and the button count what the queue can serve, not the log',
        (tester) async {
      // The log folds three tried and two failed; one of the two failed has
      // since been deleted, and the queue serves the one that is left.
      final server = _Server(
        progress: {
          'own': {
            'seen': 3,
            'solved': 1,
            'firstTry': 1,
            'failed': 2,
            'skipped': 0,
            'toRetry': 2
          },
        },
        fresh: [_position('cust_new', _otherFen)],
        retry: [_position('cust_failed', _mateFen)],
      );
      await _openHub(tester, server);

      expect(find.byKey(_ownCard), findsOneWidget);
      expect(_inOwnCard(find.text('Solved 1 · 1 to retry')), findsOneWidget);
      expect(_inOwnCard(find.text('Retry failed (1)')), findsOneWidget);
    });

    testWidgets('Retry failed opens /exercises/solve?retry=1', (tester) async {
      final visited = await _openHub(
          tester,
          _Server(
            progress: {
              'own': {
                'seen': 1,
                'solved': 0,
                'firstTry': 0,
                'failed': 1,
                'skipped': 0,
                'toRetry': 1
              },
            },
            retry: [_position('cust_failed', _mateFen)],
          ));
      final retry = _inOwnCard(find.text('Retry failed (1)'));
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(visited.map((u) => u.toString()), ['/exercises/solve?retry=1']);
    });

    testWidgets('Solve opens /exercises/solve', (tester) async {
      final visited = await _openHub(
          tester, _Server(fresh: [_position('cust_new', _mateFen)]));
      final solve = _inOwnCard(find.widgetWithText(FilledButton, 'Solve'));
      await tester.ensureVisible(solve);
      await tester.tap(solve);
      await tester.pumpAndSettle();
      expect(visited.map((u) => u.toString()), ['/exercises/solve']);
    });

    testWidgets('an account with no exercise of its own has no card',
        (tester) async {
      await _openHub(tester, _Server());
      expect(find.text('Tactics tailored to you'), findsOneWidget,
          reason: 'the hub itself did not draw');
      expect(find.byKey(_ownCard), findsNothing);
      expect(find.text('My exercises'), findsNothing);
    });
  });

  group('the queue on the board', () {
    Future<_Server> solveScreen(WidgetTester tester,
        {bool retry = false, bool fails = false}) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final server = _Server(
        fresh: [_position('cust_new', _otherFen)],
        retry: [_position('cust_failed', _mateFen)],
        queueFails: fails,
      );
      await tester.pumpWidget(MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: OwnExerciseSolveScreen(
          session: _session,
          retry: retry,
          api: ExerciseApiService(authToken: 'tok', client: server.client),
        ),
      ));
      await tester.pumpAndSettle();
      return server;
    }

    String fenOnBoard(WidgetTester tester) => tester
        .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
        .controller
        .getFen();

    testWidgets('Solve serves the never-tried first, then the failed',
        (tester) async {
      await solveScreen(tester);
      expect(find.text('Position 1 of 2'), findsOneWidget);
      expect(fenOnBoard(tester).split(' ').first, _otherFen.split(' ').first);
    });

    testWidgets('retry serves only the failed', (tester) async {
      final server = await solveScreen(tester, retry: true);
      expect(find.text('Position 1 of 1'), findsOneWidget);
      expect(fenOnBoard(tester).split(' ').first, _mateFen.split(' ').first);
      await _drag(tester, 'a1', 'a8');
      expect(server.posts('/attempt').single.url.path,
          '/exercises/cust_failed/attempt');
    });

    testWidgets('a queue that could not be read says so, not „nothing"',
        (tester) async {
      await solveScreen(tester, fails: true);
      expect(find.text('Could not load your exercises.'), findsOneWidget);
      expect(find.byType(CustomPuzzleSolverScreen), findsNothing);
    });
  });
}
