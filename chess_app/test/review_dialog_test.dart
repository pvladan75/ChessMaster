// The Review dialog on a review that belongs to the app —
// docs/PLAN-ZAGONETKE-IZ-PARTIJE.md, phase 1.2b.
//
// The dialog starts a review and then only watches it: it may be closed while
// the review runs, reopened to see where it is, and the end is said wherever
// the reader is — in the dialog when it is open, as a message when it is not.
// What the end says is the judgement's own numbers: the depth the review
// stands on, what was marked, what could not be judged, what came from the
// store, and — when nothing was marked, left unsettled or unjudged — that the
// game is clean. The pawn slider is gone: a mistake is what the one rule says
// (`mistake_rule.dart`), not a number of pawns the reader picks.

import 'dart:async';
import 'dart:math' as math;

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/services/eval_cache.dart';
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
import 'package:chess_app/widgets/review_notice.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const _italian = ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'g8f6'];
const _queensPawn = ['d2d4', 'd7d5'];

String c(double w) {
  final cp = (-math.log(100 / w - 1) / 0.00368208).round();
  final pawns = cp / 100;
  return pawns >= 0 ? '+${pawns.toStringAsFixed(2)}' : pawns.toStringAsFixed(2);
}

class _Game {
  _Game(this.start, this.ucis) {
    fens.add(start);
    final game = chess.Chess.fromFEN(start);
    for (final u in ucis) {
      final ok = game.move({'from': u.substring(0, 2), 'to': u.substring(2, 4)});
      if (!ok) throw StateError('not a legal move: $u');
      fens.add(game.fen);
    }
  }

  final String start;
  final List<String> ucis;
  final List<String> fens = [];

  List<String> otherMoves(int i) => [
        for (final m in legalMoves(chess.Chess.fromFEN(fens[i])))
          '${m['from']}${m['to']}${m['promotion'] ?? ''}'
      ].where((u) => i >= ucis.length || u != ucis[i]).toList();
}

/// Answers position i at White's chances [chances][i]; a position in [silent]
/// is never answered; the first question about [pauseAt] waits for [resume].
class _Engine implements StockfishService {
  _Engine(this.game, List<double> chances)
      : value = [for (final w in chances) c(w)];

  final _Game game;
  final List<String> value;
  final Set<int> silent = {};
  int? pauseAt;
  final Completer<void> _resumed = Completer<void>();
  final List<String> asked = [];

  void resume() {
    if (!_resumed.isCompleted) _resumed.complete();
  }

  @override
  Future<List<AnalysisLine>> analyzePositionSync(
    String fen, {
    required int depth,
    required int multiPV,
    List<String>? searchMoves,
    Duration timeout = const Duration(seconds: 10),
    void Function(List<AnalysisLine> partial)? onProgress,
  }) async {
    final i = game.fens.indexOf(fen);
    if (i < 0) throw StateError('asked about a position not in the game');
    asked.add('p$i');
    if (i == pauseAt) await _resumed.future;
    if (silent.contains(i)) return const [];
    AnalysisLine line(int pv, String evaluation, String uci) =>
        AnalysisLine.fromPv(
            multipv: pv,
            depth: depth,
            eval: evaluation,
            pvString: uci,
            startingFen: fen);
    if (searchMoves != null) {
      return [line(1, value[i + 1], searchMoves.first)];
    }
    final others = game.otherMoves(i);
    return [
      line(1, value[i], others.first),
      if (multiPV >= 2 && others.length > 1) line(2, value[i], others[1]),
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

class _Board implements ReviewBoard {
  _Board(this.reviewRoot);

  @override
  final AnalysisNode reviewRoot;

  @override
  void reviewLanded() {}
}

AnalysisNode _tree(List<String> ucis) =>
    analysisTreeFromMoves(_start, ucis).root;

List<String?> _nags(AnalysisNode root) {
  final out = <String?>[];
  var node = root;
  while (node.children.isNotEmpty) {
    node = node.children.first;
    out.add(node.nag);
  }
  return out;
}

const _twoMistakes = <double>[50, 50, 50, 50, 50, 20, 60];
const _level = <double>[50, 50, 50, 50, 50, 50, 50];

const _blunderAlert = 'Blunder Alert — tag mistakes and suggest a better move';

/// An app with the notice above everything, as `main.dart` has it, and a
/// button that opens the dialog on [root] — the way Analysis opens it.
Future<GameReviewRunner> _app(
  WidgetTester tester, {
  required AnalysisNode root,
  required StockfishService engine,
  GameReviewRunner? runner,
}) async {
  SharedPreferences.setMockInitialValues({'app_analysis_depth': 20});
  await AppSettingsService.instance.init();
  EvalCache.instance.clear();
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final r =
      runner ?? GameReviewRunner(book: _noBook, tablebase: (_) async => null);
  final board = _Board(root);
  r.attachBoard(board);
  addTearDown(() => r.detachBoard(board));

  final client = MockClient((_) async => http.Response('{}', 500));
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    builder: (context, child) => ReviewNotice(runner: r, child: child!),
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
              stockfishService: engine,
              runner: r,
            ),
          ),
          child: const Text('open review'),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return r;
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open review'));
  await tester.pumpAndSettle();
}

/// Ticks Blunder Alert and presses Start.
Future<void> _startReview(WidgetTester tester) async {
  await tester.tap(find.text(_blunderAlert));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Start analysis'));
  await tester.pump();
  await tester.pump();
}

FilledButton _startButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.ancestor(
        of: find.text('Start analysis'), matching: find.byType(FilledButton)));

void main() {
  late _Game italian;
  setUp(() => italian = _Game(_start, _italian));

  testWidgets('the pawn slider is gone', (tester) async {
    await _app(tester,
        root: _tree(_italian), engine: _Engine(italian, _twoMistakes));
    await _open(tester);
    expect(find.text('Start analysis'), findsOneWidget);
    expect(find.textContaining('pawns'), findsNothing);
    expect(find.textContaining('Blunder threshold'), findsNothing);
  });

  testWidgets(
      'closed while it runs, the review goes on, and its end is said '
      'wherever the reader is', (tester) async {
    final root = _tree(_italian);
    final engine = _Engine(italian, _twoMistakes)..pauseAt = 3;
    final runner = await _app(tester, root: root, engine: engine);
    await _open(tester);
    await _startReview(tester);
    expect(find.byKey(const Key('review-running')), findsOneWidget);

    await tester.tap(find.byKey(const Key('review-keep-working')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GameReviewDialog), findsNothing);
    expect(runner.isRunning, isTrue,
        reason: 'closing the dialog must not stop the review');

    engine.resume();
    await tester.pumpAndSettle();
    expect(runner.isRunning, isFalse);
    expect(find.textContaining('Game review done'), findsOneWidget,
        reason: 'the end was not said with the dialog closed');
    expect(_nags(root), [null, null, null, null, '??', '??']);

    // Reopened, the dialog shows the finished review — its puzzles are kept
    // from there — until it is closed.
    await _open(tester);
    expect(find.byKey(const Key('review-done')), findsOneWidget);
    await tester.tap(find.byKey(const Key('review-close')));
    await tester.pumpAndSettle();
    await _open(tester);
    expect(find.text('Start analysis'), findsOneWidget);
  });

  testWidgets('reopened during a review, the dialog shows that review',
      (tester) async {
    final engine = _Engine(italian, _twoMistakes)..pauseAt = 3;
    await _app(tester, root: _tree(_italian), engine: engine);
    await _open(tester);
    await _startReview(tester);
    await tester.tap(find.byKey(const Key('review-keep-working')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('open review'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('review-running')), findsOneWidget);
    expect(find.text('Start analysis'), findsNothing);

    engine.resume();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('review-done')), findsOneWidget);
    expect(find.textContaining('Game review done'), findsNothing,
        reason: 'with the dialog open, the end is said in the dialog');
  });

  testWidgets(
      'the end says what the judgement found: positions, depth, and what '
      'was marked', (tester) async {
    await _app(tester,
        root: _tree(_italian), engine: _Engine(italian, _twoMistakes));
    await _open(tester);
    await _startReview(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('review-done')), findsOneWidget);
    expect(find.text('Done — reviewed 7 positions.'), findsOneWidget);
    expect(find.text('Marked 2 mistakes.'), findsOneWidget);
    expect(find.byKey(const Key('review-clean')), findsNothing);
    expect(
        tester
            .widget<Text>(find.byKey(const Key('review-depth')))
            .data,
        contains('depth 20'));
  });

  testWidgets('a clean game is said to be clean, at its depth',
      (tester) async {
    await _app(tester, root: _tree(_italian), engine: _Engine(italian, _level));
    await _open(tester);
    await _startReview(tester);
    await tester.pumpAndSettle();

    final clean = tester.widget<Text>(find.byKey(const Key('review-clean')));
    expect(clean.data, contains('depth 20'));
    expect(find.text('Marked 0 mistakes.'), findsOneWidget);
  });

  testWidgets(
      'a move the engine never answered is counted, and the game is not '
      'called clean', (tester) async {
    final engine = _Engine(italian, _level)..silent.add(3);
    await _app(tester, root: _tree(_italian), engine: engine);
    await _open(tester);
    await _startReview(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('review-clean')), findsNothing);
    final unjudged =
        tester.widget<Text>(find.byKey(const Key('review-unjudged')));
    expect(unjudged.data, contains('2'));
  });

  testWidgets('a review run again says how much came from the store',
      (tester) async {
    await _app(tester,
        root: _tree(_italian), engine: _Engine(italian, _twoMistakes));
    await _open(tester);
    await _startReview(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('review-from-store')), findsNothing,
        reason: 'nothing came from the store the first time');
    await tester.tap(find.byKey(const Key('review-close')));
    await tester.pumpAndSettle();

    await _open(tester);
    await _startReview(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('review-from-store')), findsOneWidget);
  });

  testWidgets('Cancel stops the review, closes the dialog, and marks nothing',
      (tester) async {
    final root = _tree(_italian);
    final engine = _Engine(italian, _twoMistakes)..pauseAt = 3;
    final runner = await _app(tester, root: root, engine: engine);
    await _open(tester);
    await _startReview(tester);

    await tester.tap(find.byKey(const Key('review-cancel')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GameReviewDialog), findsNothing);

    engine.resume();
    await tester.pumpAndSettle();
    expect(runner.isRunning, isFalse);
    expect(_nags(root).whereType<String>(), isEmpty);
    expect(find.textContaining('Game review done'), findsNothing);
  });

  testWidgets(
      'while another game is reviewed, this one cannot start, and says why',
      (tester) async {
    final queensPawn = _Game(_start, _queensPawn);
    final other = _Engine(queensPawn, const [50, 50, 50])..pauseAt = 1;
    final runner = GameReviewRunner(book: _noBook, tablebase: (_) async => null);
    await _app(tester,
        root: _tree(_italian),
        engine: _Engine(italian, _twoMistakes),
        runner: runner);
    final otherRoot = _tree(_queensPawn);
    runner.start(
      root: otherRoot,
      start: otherRoot,
      options: const ReviewOptions(depth: 20, markMistakes: true),
      engine: other,
    );

    await tester.tap(find.text('open review'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('review-other-game')), findsOneWidget);
    await tester.tap(find.text(_blunderAlert));
    await tester.pump();
    expect(_startButton(tester).onPressed, isNull);

    other.resume();
    await tester.pumpAndSettle();
  });
}
