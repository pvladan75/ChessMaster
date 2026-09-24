// Puzzles from a game review are exercises — docs/PLAN-MATERIJAL.md, phase 4.
//
// „Review entire game" used to save its blunders at once as a puzzle set: a
// device copy and a server table, opened by the studio's puzzle mode, judged by
// nothing and sent to nobody. Now the puzzles are **listed** first, each
// ticked, and „Keep N as exercises" writes one Find exercise per ticked puzzle
// through `POST /exercises` — origin „mistakes", the answer as the solution,
// the game as the source — after replaying that answer on the position (the
// writer reads its own work back).
//
// One fake server records every request (rule 7); the engine is a stand-in
// that implements `StockfishService` and answers by position.
//
// `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`, phase 1.2b: the one test here that
// opened `GameReviewDialog` now passes it a `GameReviewRunner` instead of
// `onCompleted`, and no longer relies on the dialog's own last-move search
// (deleted — `GameReviewJudge`'s walk already asks about the last position).
//
// Phase 1.3 (24.9.2026): a puzzle is now the position *before* the game's
// move, not after it, and its instruction no longer names the move — most of
// that wiring is now the gate's own, `test/keep_review_puzzles_test.dart`
// (a mistake ticked, an only move apart, the position and the instruction,
// an answer that does not play). What stays here is what that gate does not
// cover: several puzzles kept in one „Keep", the source/label a kept exercise
// carries, and the dialog wired end to end through a real `GameReviewJudge`
// walk that turns a mistake into a puzzle on its own.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/services/local_puzzle_extractor_service.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/game_review_runner.dart';
import 'package:chess_app/features/analysis_studio/widgets/game_review_dialog.dart';
import 'package:chess_app/features/analysis_studio/widgets/keep_puzzles_panel.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_persistence_service.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/screens/library_screen.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/masters_walk.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/theme/app_colors.dart';

/// White to move; 1.Qd5+?? hangs the queen to the rook on d8 — 1.Qd3 holds it.
const _start = '3r2k1/8/8/8/8/8/8/3Q2K1 w - - 0 1';
const _afterQd5 = '3r2k1/8/8/3Q4/8/8/8/6K1 b - - 1 1';

/// Black to move after 11...Qc2, about to blunder with 12...Qe4?? (13.Rxe4
/// wins it); 12...Qc1 held. (12...Qe7 until phase 4 of
/// docs/PLAN-ZAGONETKE-IZ-PARTIJE.md — a move the queen on c2 cannot make,
/// which nothing replayed until the draft began replaying the game's move.)
const _otherBefore = '6k1/8/8/8/8/8/2q5/4R1K1 b - - 2 12';

LocalPuzzle _puzzle(
  String id, {
  required String fen,
  required String move,
  required String answer,
  double bestChances = 90,
  double playedChances = 10,
}) =>
    LocalPuzzle(
      id: id,
      kind: PuzzleKind.mistake,
      fen: fen,
      sourcePlyIndex: 0,
      playedSan: move,
      playedUci: '0000',
      answers: [answer],
      // A puzzle always carries the line behind its answer — the builder makes
      // none without one — and since phase 4 of docs/PLAN-ZAGONETKE-IZ-PARTIJE.md
      // a puzzle whose line does not play cannot be kept at all.
      bestLine: [answer],
      bestChances: bestChances,
      playedChances: playedChances,
    );

final _hanging = _puzzle('a', fen: _start, move: 'Qd5+', answer: 'Qd3');
final _rookTakes = _puzzle('b', fen: _otherBefore, move: 'Qe4', answer: 'Qc1');

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
            201,
          );
        }
        return http.Response('{}', 404);
      });

  List<Map<String, dynamic>> get bodies => [
        for (final r in posts) jsonDecode(r.body) as Map<String, dynamic>,
      ];
}

Future<({_Server server, List<int> done})> _panel(
  WidgetTester tester,
  List<LocalPuzzle> puzzles,
) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final server = _Server();
  final done = <int>[];
  await tester.pumpWidget(
    MaterialApp(
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
    ),
  );
  await tester.pumpAndSettle();
  return (server: server, done: done);
}

Future<void> _keep(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('keep-puzzles-save')));
  await tester.pumpAndSettle();
}

/// An engine that answers by position with up to two lines, the second
/// clearly below the first — phase 1.3: a mistake with no second line, or one
/// not `kStandsOut` clear of the best, is no puzzle, so a fixture that wants
/// one kept has to supply it. Ignores `searchMoves`, as it always has: a
/// caller asking about the played move gets the same best line back, which is
/// what sends the judge's confirming look to the position after instead
/// (`GameReviewJudge._lookAt`'s own fallback).
class _FakeEngine implements StockfishService {
  _FakeEngine(this.answers);

  /// FEN → (line1 eval, line1 uci, line2 eval, line2 uci). The second pair
  /// may be empty when a position is never asked for two lines.
  final Map<String, (String, String, String, String)> answers;
  final List<String> asked = [];

  @override
  Future<List<AnalysisLine>> analyzePositionSync(
    String fen, {
    required int depth,
    required int multiPV,
    List<String>? searchMoves,
    Duration timeout = const Duration(seconds: 10),
    void Function(List<AnalysisLine> partial)? onProgress,
  }) async {
    asked.add(fen);
    final a = answers[fen];
    final (eval1, pv1, eval2, pv2) = a ?? ('0.00', '', '', '');
    final lines = [
      AnalysisLine.fromPv(
        multipv: 1,
        depth: depth,
        eval: eval1,
        pvString: pv1,
        startingFen: fen,
      ),
    ];
    if (multiPV >= 2 && pv2.isNotEmpty) {
      lines.add(
        AnalysisLine.fromPv(
          multipv: 2,
          depth: depth,
          eval: eval2,
          pvString: pv2,
          startingFen: fen,
        ),
      );
    }
    return lines;
  }

  /// No name: the review's store keeps these answers for the run only.
  @override
  Future<String?> answerStoreName() async => null;

  @override
  void hold(Object owner) {}

  @override
  void release(Object owner) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<MastersWalk> _noBook(List<String> fens) async =>
    (known: const <String, Map<String, dynamic>>{}, unavailable: null);

void main() {
  group('the list, and what is kept', () {
    testWidgets('each ticked puzzle is one POST /exercises, the body whole', (
      tester,
    ) async {
      final (:server, :done) = await _panel(tester, [_hanging, _rookTakes]);
      expect(find.text('Keep 2 as exercises'), findsOneWidget);
      await _keep(tester);

      expect(server.posts, hasLength(2));
      expect(server.bodies.first, {
        'name': 'Game of test, move 1',
        'fen': _start,
        'instruction': kMistakeInstruction,
        'themes': [],
        'task': {'type': 'find'},
        'solution': [
          {
            'accept': ['Qd3'],
          },
        ],
        'origin': 'mistakes',
        'source': {'title': 'Game of test', 'label': '1.Qd5+'},
        // Since phase 4 of docs/PLAN-ZAGONETKE-IZ-PARTIJE.md the review goes
        // with it — still the whole body, so anything else that starts
        // travelling shows.
        'review': {
          'played': 'Qd5+',
          'bestLine': ['Qd3'],
          'refutationLine': [],
          'secondLine': [],
          'chances': {'best': 90.0, 'played': 10.0},
        },
      });
      expect(server.bodies[1]['name'], 'Game of test, move 12');
      expect(server.bodies[1]['instruction'], kMistakeInstruction);
      expect(server.bodies[1]['source'], {
        'title': 'Game of test',
        'label': '12...Qe4',
      });
      expect(done, [2]);
    });

    testWidgets('an unticked puzzle is not sent', (tester) async {
      final (:server, done: _) = await _panel(tester, [_hanging, _rookTakes]);
      await tester.tap(find.byKey(const ValueKey('keep-puzzle-tick-1')));
      await tester.pumpAndSettle();
      await _keep(tester);
      expect(server.bodies.map((b) => b['fen']), [_start]);
    });

    // "a puzzle with no answer says so and cannot be ticked" — deleted, phase
    // 1.3 (docs/PLAN-ZAGONETKE-IZ-PARTIJE.md): `LocalPuzzle.answers` is a
    // required list, and the extractor never keeps a puzzle it could not
    // answer (§4) — there is no "no answer" state left for the panel to show,
    // so its checkbox is never disabled for one. The failure mode 1.3 does
    // have — an answer that does not play — is the case right below, and
    // `test/keep_review_puzzles_test.dart`'s "an answer that does not play is
    // not sent, and it is said" holds it too.

    testWidgets('an answer that does not play is not sent, and it is said', (
      tester,
    ) async {
      // No knight anywhere on the board: guaranteed not to play, wherever.
      final wrong = _puzzle('w', fen: _start, move: 'Qd5+', answer: 'Nf3');
      final (:server, :done) = await _panel(tester, [wrong]);
      await _keep(tester);
      expect(server.posts, isEmpty);
      expect(find.textContaining('does not play'), findsOneWidget);
      expect(done, isEmpty);
    });
  });

  test('the draft is the puzzle\'s own: its answer, not the blunder', () {
    final draft = puzzleExerciseDraft(_hanging, name: 'A game')!;
    expect(draft.solution!.single.accept, ['Qd3']);
    expect(draft.origin, 'mistakes');
    expect(draft.fen, _start);
  });

  testWidgets(
    'the review of a game whose last move is the blunder asks the engine '
    'about it too — the walk covers the last position — and keeps the '
    'answer',
    (tester) async {
      // Rewritten for `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md` phase 1.2b: the
      // dialog's own last-move search is gone (`ReviewedMove.replyLine` already
      // carries it, since `GameReviewJudge`'s walk asks about every position,
      // including the last one's) — this now goes through `GameReviewRunner`
      // rather than the deleted walker directly. Rewritten again for phase 1.3:
      // the fake engine now answers a second, clearly worse line at the
      // position before the blunder, since a mistake with no second line —
      // or one not 15 chances clear of the best — is no puzzle any more, and
      // the puzzle is now the position *before* the move.
      SharedPreferences.setMockInitialValues({'app_analysis_depth': 12});
      await AppSettingsService.instance.init();
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final root = AnalysisNode(fen: _start);
      root.addChild(childFen: _afterQd5, san: 'Qd5+', uci: 'd1d5');
      final engine = _FakeEngine({
        _start: ('0.00', 'd1d3', '-2.00', 'd1d2'),
        _afterQd5: ('-9.00', 'd8d5', '', ''),
      });
      final server = _Server();
      final runner = GameReviewRunner(
        book: _noBook,
        tablebase: (_) async => null,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: const [AppColorTokens.dark],
          ),
          home: Scaffold(
            body: GameReviewDialog(
              exerciseApi: ExerciseApiService(
                authToken: 'tok',
                client: server.client,
              ),
              gameTitle: 'Ana – Boris',
              rootNode: root,
              currentNode: root,
              stockfishService: engine,
              runner: runner,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Extract puzzles from detected blunders'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start analysis'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Answer: Qd3'),
        findsOneWidget,
        reason: 'the best move was not found',
      );
      await _keep(tester);

      expect(server.bodies, hasLength(1));
      expect(server.bodies.single['name'], 'Ana – Boris, move 1');
      expect(server.bodies.single['solution'], [
        {
          'accept': ['Qd3'],
        },
      ]);
      expect(server.bodies.single['origin'], 'mistakes');
    },
  );

  testWidgets(
    'a Library that cannot be read says so — it is not an empty account',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final client = MockClient((req) async => http.Response('{}', 503));
      AnalysisPersistenceService.setInstance(
        AnalysisPersistenceService.withClient(client),
      );
      addTearDown(AnalysisPersistenceService.resetInstance);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: const [AppColorTokens.light],
          ),
          home: LibraryScreen(
            session: UserSession(
              token: 'tok',
              id: 1,
              email: 'e',
              name: 'N',
              role: 'korisnik',
            ),
            positionLibrary: PositionLibraryService(
              authToken: 'tok',
              client: client,
            ),
            lessonApi: LessonApiService(authToken: 'tok', client: client),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('The library could not be loaded.'), findsOneWidget);
      expect(find.text('Nothing here yet.'), findsNothing);
    },
  );
}
