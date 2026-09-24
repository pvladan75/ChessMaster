// „Review entire game" says what it does — reported from a phone on 24.9.2026.
//
// Since 22.9.2026 the review writes no comment under a move, yet the dialog
// still promised „a tactical and positional comment plus eval for each" and
// ended on „Done! Commented on 115 positions." With Blunder Alert and puzzles
// both off (the defaults) the walk took six minutes and changed nothing, and
// the owner went looking for the comments. Now Start stays off until one of
// the two is on, the promise is gone, and the end names what was found.
//
// Rewritten for `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`, phase 1.2b: the dialog no
// longer marks its own `rootNode` directly — the review runs through
// `GameReviewRunner` and lands on whichever `ReviewBoard` holds the game
// (`test/review_runner_test.dart`), so this file attaches one, the way
// `AnalysisStudioScreen` does. "Tagged N blunder(s)." became "Marked N
// mistake(s)." — the review's own wording, held by
// `test/review_dialog_test.dart`'s "the end says what the judgement found".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/game_review_runner.dart';
import 'package:chess_app/features/analysis_studio/widgets/game_review_dialog.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/masters_walk.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/theme/app_colors.dart';

/// White to move; Qd5+ hangs the queen to the rook on d8.
const _start = '3r2k1/8/8/8/8/8/8/3Q1K2 w - - 0 1';
const _afterQd5 = '3r2k1/8/8/3Q4/8/8/8/5K2 b - - 1 1';

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
    List<String>? searchMoves,
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

class _Board implements ReviewBoard {
  _Board(this.reviewRoot);
  @override
  final AnalysisNode reviewRoot;
  @override
  void reviewLanded() {}
}

Future<({AnalysisNode root, _FakeEngine engine, GameReviewRunner runner})>
    _open(WidgetTester tester) async {
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
  final runner = GameReviewRunner(book: _noBook, tablebase: (_) async => null);
  final board = _Board(root);
  runner.attachBoard(board);
  addTearDown(() => runner.detachBoard(board));
  final client = MockClient((_) async => http.Response('{}', 500));
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: Scaffold(
      body: GameReviewDialog(
        exerciseApi: ExerciseApiService(authToken: 'tok', client: client),
        rootNode: root,
        currentNode: root,
        stockfishService: engine,
        runner: runner,
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return (root: root, engine: engine, runner: runner);
}

FilledButton _startButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.ancestor(
        of: find.text('Start analysis'), matching: find.byType(FilledButton)));

void main() {
  testWidgets(
      'with neither Blunder Alert nor puzzles on, Start is off and says why, '
      'and the engine is asked nothing', (tester) async {
    final (:root, :engine, runner: _) = await _open(tester);

    expect(_startButton(tester).onPressed, isNull,
        reason: 'a walk that writes nothing must not start');
    expect(find.byKey(const Key('review-needs-output')), findsOneWidget);

    await tester.tap(find.text('Start analysis'));
    await tester.pumpAndSettle();
    expect(engine.asked, isEmpty);
    expect(root.children.single.nag, isNull);
  });

  testWidgets('either option alone turns Start on', (tester) async {
    await _open(tester);
    await tester.tap(
        find.text('Blunder Alert — tag mistakes and suggest a better move'));
    await tester.pumpAndSettle();
    expect(_startButton(tester).onPressed, isNotNull);
    expect(find.byKey(const Key('review-needs-output')), findsNothing);

    await tester.tap(
        find.text('Blunder Alert — tag mistakes and suggest a better move'));
    await tester.tap(find.text('Extract puzzles from detected blunders'));
    await tester.pumpAndSettle();
    expect(_startButton(tester).onPressed, isNotNull);
  });

  testWidgets(
      'the dialog promises no comment, and the end says what was found, '
      'never „commented"', (tester) async {
    final (:root, engine: _, runner: _) = await _open(tester);

    expect(
        find.textContaining('writes no comment under a move'), findsOneWidget);
    expect(find.textContaining('comment plus eval'), findsNothing);

    await tester.tap(
        find.text('Blunder Alert — tag mistakes and suggest a better move'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start analysis'));
    await tester.pumpAndSettle();

    expect(find.text('Done — reviewed 2 positions.'), findsOneWidget);
    expect(find.textContaining('Commented'), findsNothing);
    expect(find.text('Marked 1 mistake.'), findsOneWidget);
    expect(root.children.first.nag, '??',
        reason: 'what the end reports must be on the game');
  });
}
