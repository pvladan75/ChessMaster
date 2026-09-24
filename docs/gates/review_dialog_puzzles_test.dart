// The Review dialog when it keeps puzzles — docs/PLAN-ZAGONETKE-IZ-PARTIJE.md,
// phase 1.3.
//
// Blunder Alert's Both / White / Black applies to the puzzles too (the
// owner, 23.9.2026), so the choice is offered whenever either Blunder Alert
// or the puzzles are on — until 1.3 it sat inside Blunder Alert and a review
// that kept puzzles alone took puzzles from both sides. And a review asked for
// puzzles that finds none says so, rather than ending on a Close button that
// looks like the puzzles were forgotten.

import 'dart:math' as math;

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/services/eval_cache.dart';
import 'package:chess_app/core/services/game_analysis_walker_service.dart';
import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/game_from_moves.dart';
import 'package:chess_app/features/analysis_studio/services/game_review_runner.dart';
import 'package:chess_app/features/analysis_studio/widgets/game_review_dialog.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/masters_walk.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/theme/app_colors.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const _italian = ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'g8f6'];

const _blunderAlert = 'Blunder Alert — tag mistakes and suggest a better move';
const _puzzles = 'Extract puzzles from detected blunders';

String c(double w) {
  final cp = (-math.log(100 / w - 1) / 0.00368208).round();
  final pawns = cp / 100;
  return pawns >= 0 ? '+${pawns.toStringAsFixed(2)}' : pawns.toStringAsFixed(2);
}

/// Level everywhere, and never the move the game played: no mistake, and no
/// move the player found — so a review finds no puzzle at all.
class _Engine implements StockfishService {
  _Engine(this.fens);

  final List<String> fens;

  @override
  Future<List<AnalysisLine>> analyzePositionSync(
    String fen, {
    required int depth,
    required int multiPV,
    List<String>? searchMoves,
    Duration timeout = const Duration(seconds: 10),
    void Function(List<AnalysisLine> partial)? onProgress,
  }) async {
    final i = fens.indexOf(fen);
    if (i < 0) throw StateError('asked about a position not in the game');
    final played = i < _italian.length ? _italian[i] : null;
    final others = [
      for (final m in legalMoves(chess.Chess.fromFEN(fen)))
        '${m['from']}${m['to']}${m['promotion'] ?? ''}'
    ].where((u) => u != played).toList();
    AnalysisLine line(int pv, String uci) => AnalysisLine.fromPv(
        multipv: pv,
        depth: depth,
        eval: c(50),
        pvString: uci,
        startingFen: fen);
    if (searchMoves != null) return [line(1, searchMoves.first)];
    return [
      line(1, others.first),
      if (multiPV >= 2) line(2, others[1]),
      if (multiPV >= 3) line(3, others[2]),
    ];
  }

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

Future<GameReviewRunner> _app(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'app_analysis_depth': 20});
  await AppSettingsService.instance.init();
  EvalCache.instance.clear();
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final game = analysisTreeFromMoves(_start, _italian);
  final AnalysisNode root = game.root;
  final fens = walkGame(startingFen: _start, uciMoves: _italian).fens;
  final runner = GameReviewRunner(book: _noBook, tablebase: (_) async => null);
  final client = MockClient((_) async => http.Response('{}', 500));
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<int>(
            context: context,
            barrierDismissible: false,
            builder: (_) => GameReviewDialog(
              exerciseApi: ExerciseApiService(authToken: 'tok', client: client),
              rootNode: root,
              currentNode: root,
              stockfishService: _Engine(fens),
              runner: runner,
            ),
          ),
          child: const Text('open review'),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('open review'));
  await tester.pumpAndSettle();
  return runner;
}

Future<void> _startReview(WidgetTester tester) async {
  await tester.tap(find.text('Start analysis'));
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('with neither Blunder Alert nor puzzles, no side is offered',
      (tester) async {
    await _app(tester);

    expect(find.text('White'), findsNothing);
  });

  testWidgets(
      'with puzzles alone, the side can be chosen, and the review takes it',
      (tester) async {
    final runner = await _app(tester);
    await tester.tap(find.text(_puzzles));
    await tester.pumpAndSettle();

    expect(find.text('White'), findsOneWidget);
    await tester.tap(find.text('White'));
    await tester.pumpAndSettle();
    await _startReview(tester);

    expect(runner.current!.options.findPuzzles, isTrue);
    expect(runner.current!.options.side, BlunderAlertSide.white);
  });

  testWidgets('a review asked for puzzles that finds none says so',
      (tester) async {
    final runner = await _app(tester);
    await tester.tap(find.text(_puzzles));
    await tester.pumpAndSettle();
    await _startReview(tester);

    expect(runner.current!.status, ReviewRunStatus.done);
    expect(runner.current!.puzzles, isEmpty);
    expect(find.byKey(const Key('review-no-puzzles')), findsOneWidget);
  });

  testWidgets('a review not asked for puzzles says nothing about them',
      (tester) async {
    await _app(tester);
    await tester.tap(find.text(_blunderAlert));
    await tester.pumpAndSettle();
    await _startReview(tester);

    expect(find.byKey(const Key('review-done')), findsOneWidget);
    expect(find.byKey(const Key('review-no-puzzles')), findsNothing);
  });
}
