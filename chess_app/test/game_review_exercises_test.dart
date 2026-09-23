// Puzzles from a game review are exercises — docs/PLAN-MATERIJAL.md, phase 4.
//
// „Review entire game" used to save its blunders at once as a puzzle set: a
// device copy and a server table, opened by the studio's puzzle mode, judged by
// nothing and sent to nobody. Now the puzzles are **listed** first, each
// ticked, and „Keep N as exercises" writes one Find exercise per ticked puzzle
// through `POST /exercises` — origin „mistakes", the engine's answer to the
// blunder as the solution, the game as the source — after replaying that
// answer on the position (the writer reads its own work back).
//
// One fake server records every request (rule 7); the engine is a stand-in
// that implements `StockfishService` and answers by position.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/services/local_puzzle_extractor_service.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/widgets/game_review_dialog.dart';
import 'package:chess_app/features/analysis_studio/widgets/keep_puzzles_panel.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_persistence_service.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/screens/library_screen.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/theme/app_colors.dart';

/// White to move; Qd5+ hangs the queen to the rook on d8.
const _start = '3r2k1/8/8/8/8/8/8/3Q2K1 w - - 0 1';
const _afterQd5 = '3r2k1/8/8/3Q4/8/8/8/6K1 b - - 1 1';

/// Black to move after 12...Qe7??: White wins it with Rxe7.
const _other = '6k1/4q3/8/8/8/8/8/4R1K1 w - - 3 13';

LocalPuzzle _puzzle(String id,
        {required String fen,
        required String fenBefore,
        required String move,
        String? answer,
        String? theme}) =>
    LocalPuzzle(
      id: id,
      fen: fen,
      themeLabel: theme ?? 'Opponent made a mistake',
      themeKey: theme,
      swing: -9,
      sourceMoveSan: move,
      sourcePlyIndex: 0,
      fenBefore: fenBefore,
      refutationSan: answer,
    );

final _hanging = _puzzle('a',
    fen: _afterQd5,
    fenBefore: _start,
    move: 'Qd5+',
    answer: 'Rxd5',
    theme: 'hangingPiece');
final _rookTakes = _puzzle('b',
    fen: _other,
    fenBefore: '6k1/8/8/8/8/8/2q5/4R1K1 b - - 2 12',
    move: 'Qe7',
    answer: 'Rxe7');
final _unanswered = _puzzle('c',
    fen: '6k1/8/8/8/8/8/8/6K1 w - - 0 40',
    fenBefore: '6k1/8/8/8/8/8/8/6K1 b - - 0 39',
    move: 'Kg8');

class _Server {
  final List<http.Request> posts = [];

  http.Client get client => MockClient((req) async {
        if (req.method == 'POST' && req.url.path == '/exercises') {
          posts.add(req);
          final sent = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
              jsonEncode({
                'exercise': {
                  'id': 'ex_${posts.length}',
                  'fen': sent['fen'],
                  'sideToMove': 'b',
                  'name': sent['name'],
                  'themes': sent['themes'],
                  'origin': sent['origin'],
                  'task': sent['task'],
                  'solution': sent['solution'],
                  'assignable': true,
                },
              }),
              201);
        }
        return http.Response('{}', 404);
      });

  List<Map<String, dynamic>> get bodies => [
        for (final r in posts) jsonDecode(r.body) as Map<String, dynamic>,
      ];
}

Future<({_Server server, List<int> done})> _panel(
    WidgetTester tester, List<LocalPuzzle> puzzles) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final server = _Server();
  final done = <int>[];
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: Scaffold(
      body: SingleChildScrollView(
        child: KeepPuzzlesPanel(
          puzzles: puzzles,
          defaultName: 'Game of test',
          api: ExerciseApiService(authToken: 'tok', client: server.client),
          onDone: done.add,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return (server: server, done: done);
}

Future<void> _keep(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('keep-puzzles-save')));
  await tester.pumpAndSettle();
}

/// An engine that answers by position, and counts what it was asked.
class _FakeEngine implements StockfishService {
  _FakeEngine(this.answers);

  /// FEN → (evaluation, best line in UCI).
  final Map<String, (String, String)> answers;
  final List<String> asked = [];

  @override
  Future<List<AnalysisLine>> analyzePositionSync(
    String fen, {
    required int depth,
    required int multiPV,
    Duration timeout = const Duration(seconds: 10),
    void Function(List<AnalysisLine> partial)? onProgress,
  }) async {
    asked.add(fen);
    final (eval, pv) = answers[fen] ?? ('0.00', '');
    return [
      AnalysisLine.fromPv(
          multipv: 1, depth: depth, eval: eval, pvString: pv, startingFen: fen)
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('the list, and what is kept', () {
    testWidgets('each ticked puzzle is one POST /exercises, the body whole',
        (tester) async {
      final (:server, :done) =
          await _panel(tester, [_hanging, _rookTakes, _unanswered]);
      expect(find.text('Keep 2 as exercises'), findsOneWidget,
          reason: 'the unanswered one is ticked, or the answered ones not');
      await _keep(tester);

      expect(server.posts, hasLength(2));
      expect(server.bodies.first, {
        'name': 'Game of test, move 1',
        'fen': _afterQd5,
        'instruction': 'White just played Qd5+.',
        'themes': ['hangingPiece'],
        'task': {'type': 'find'},
        'solution': [
          {
            'accept': ['Rxd5']
          }
        ],
        'origin': 'mistakes',
        'source': {'title': 'Game of test', 'label': '1.Qd5+'},
      });
      expect(server.bodies[1]['name'], 'Game of test, move 12');
      expect(server.bodies[1]['instruction'], 'Black just played Qe7.');
      expect(server.bodies[1]['source'],
          {'title': 'Game of test', 'label': '12...Qe7'});
      expect(done, [2]);
    });

    testWidgets('an unticked puzzle is not sent', (tester) async {
      final (:server, done: _) = await _panel(tester, [_hanging, _rookTakes]);
      await tester.tap(find.byKey(const ValueKey('keep-puzzle-tick-1')));
      await tester.pumpAndSettle();
      await _keep(tester);
      expect(server.bodies.map((b) => b['fen']), [_afterQd5]);
    });

    testWidgets('a puzzle with no answer says so and cannot be ticked',
        (tester) async {
      await _panel(tester, [_unanswered]);
      expect(find.text('No answer found — cannot be kept'), findsOneWidget);
      final tick = tester
          .widget<Checkbox>(find.byKey(const ValueKey('keep-puzzle-tick-0')));
      expect(tick.value, isFalse);
      expect(tick.onChanged, isNull);
    });

    testWidgets('an answer that does not play is not sent, and it is said',
        (tester) async {
      final wrong = _puzzle('w',
          fen: _afterQd5, fenBefore: _start, move: 'Qd5+', answer: 'Qa1');
      final (:server, :done) = await _panel(tester, [wrong]);
      await _keep(tester);
      expect(server.posts, isEmpty);
      expect(find.textContaining('does not play there'), findsOneWidget);
      expect(done, isEmpty);
    });
  });

  test('the draft is the puzzle\'s own: its answer, not the blunder', () {
    final draft = puzzleExerciseDraft(_hanging, name: 'A game')!;
    expect(draft.solution!.single.accept, ['Rxd5']);
    expect(draft.origin, 'mistakes');
    expect(draft.fen, _afterQd5);
  });

  testWidgets(
      'the review of a game whose last move is the blunder asks the engine '
      'once for the answer, and keeps it', (tester) async {
    SharedPreferences.setMockInitialValues({'app_analysis_depth': 12});
    await AppSettingsService.instance.init();
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final root = AnalysisNode(fen: _start);
    root.addChild(childFen: _afterQd5, san: 'Qd5+', uci: 'd1d5');
    final engine = _FakeEngine({
      _start: ('0.00', 'd1d3'),
      _afterQd5: ('-9.00', 'd8d5'),
    });
    final server = _Server();

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: Scaffold(
        body: GameReviewDialog(
          exerciseApi:
              ExerciseApiService(authToken: 'tok', client: server.client),
          gameTitle: 'Ana – Boris',
          rootNode: root,
          currentNode: root,
          stockfishService: engine,
          onCompleted: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Extract puzzles from detected blunders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start analysis'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Answer: Rxd5'), findsOneWidget,
        reason: 'the last move\'s answer was not found');
    await _keep(tester);

    expect(server.bodies, hasLength(1));
    expect(server.bodies.single['name'], 'Ana – Boris, move 1');
    expect(server.bodies.single['solution'], [
      {
        'accept': ['Rxd5']
      }
    ]);
    expect(server.bodies.single['origin'], 'mistakes');
  });

  testWidgets(
      'a Library that cannot be read says so — it is not an empty account',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final client = MockClient((req) async => http.Response('{}', 503));
    AnalysisPersistenceService.setInstance(
        AnalysisPersistenceService.withClient(client));
    addTearDown(AnalysisPersistenceService.resetInstance);
    await tester.pumpWidget(MaterialApp(
      theme:
          ThemeData.light().copyWith(extensions: const [AppColorTokens.light]),
      home: LibraryScreen(
        session: UserSession(
            token: 'tok', id: 1, email: 'e', name: 'N', role: 'korisnik'),
        positionLibrary:
            PositionLibraryService(authToken: 'tok', client: client),
        lessonApi: LessonApiService(authToken: 'tok', client: client),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('The library could not be loaded.'), findsOneWidget);
    expect(find.text('Nothing here yet.'), findsNothing);
  });
}
