import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/core/services/game_analysis_walker_service.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/models/analysis_models.dart';

/// Returns a fixed, caller-supplied sequence of White-relative eval strings,
/// one per position visited, in the order `analyzeGame` visits them (fens[0],
/// fens[1], ...). Lets a test dictate exactly how the "game" swings without
/// needing a real engine.
class _SequencedFakeEngine {
  final List<String> evalSequence;

  /// When set, every returned line carries this UCI principal variation
  /// (e.g. "e2e4 e7e5") instead of an empty one — needed to exercise
  /// [GameAnalysisWalkerService.tagBlunders]'s alternative-line insertion,
  /// which needs a non-empty `sanMoveList` to have anything to insert.
  final String? pvOverride;

  int callIndex = 0;

  _SequencedFakeEngine(this.evalSequence, {this.pvOverride});

  Future<List<AnalysisLine>> analyze(
    String fen, {
    required int depth,
    required int multiPV,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final eval = callIndex < evalSequence.length ? evalSequence[callIndex] : '0.00';
    callIndex++;
    return [AnalysisLine.fromPv(multipv: 1, depth: depth, eval: eval, pvString: pvOverride ?? '', startingFen: fen)];
  }
}

void main() {
  group('GameAnalysisWalkerService', () {
    late GameAnalysisWalkerService service;

    setUp(() {
      service = GameAnalysisWalkerService();
    });

    test('1. Computes mover-relative swing correctly for both White and Black', () async {
      // Position0 (White to move): eval +0.20.
      // White plays e4 -> Position1 (Black to move): eval -3.00. Eval is
      // White-relative, so this means White handed Black a swing to +3
      // pawns of advantage — the mover-relative computation must reflect
      // that as a White blunder, not a White gain (the sign-direction bug
      // class already found and fixed in TacticalMotifDetector's mate-eval
      // handling).
      // Black then plays e5 -> Position2: eval -2.80 (small, not a blunder).
      final moments = await service.analyzeGame(
        startingFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        uciMoves: ['e2e4', 'e7e5'],
        analyzer: _SequencedFakeEngine(['+0.20', '-3.00', '-2.80']).analyze,
      );

      expect(moments, hasLength(2));

      final whiteMove = moments[0];
      expect(whiteMove.evalBeforeForMover, closeTo(0.20, 1e-9));
      expect(whiteMove.evalAfterForMover, closeTo(-3.00, 1e-9));
      expect(whiteMove.swingForMover, closeTo(-3.20, 1e-9));
      expect(whiteMove.isBlunderBeyond(2.0), isTrue);

      final blackMove = moments[1];
      // Black-relative: was +3.00 (mirrored from -3.00), now +2.80.
      expect(blackMove.evalBeforeForMover, closeTo(3.00, 1e-9));
      expect(blackMove.evalAfterForMover, closeTo(2.80, 1e-9));
      expect(blackMove.swingForMover, closeTo(-0.20, 1e-9));
      expect(blackMove.isBlunderBeyond(2.0), isFalse);
    });

    test('2. Parses mate-score evals into a large finite magnitude', () async {
      final moments = await service.analyzeGame(
        startingFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        uciMoves: ['e2e4'],
        analyzer: _SequencedFakeEngine(['+0.20', 'M3']).analyze,
      );

      expect(moments, hasLength(1));
      expect(moments.first.evalAfterForMover, greaterThan(50));
    });

    test('3. annotateNodeChain writes eval into each node and respects overwriteExisting', () async {
      final root = AnalysisNode(fen: '3r2k1/8/8/8/8/8/8/3Q2K1 w - - 0 1');
      final child = root.addChild(
        childFen: '3r2k1/8/8/3Q4/8/8/8/6K1 b - - 0 1',
        san: 'Qd5',
        uci: 'd1d5',
      );

      await service.annotateNodeChain(
        startNode: root,
        analyzer: _SequencedFakeEngine(['+0.00', '-9.00']).analyze,
      );

      expect(child.eval, closeTo(-9.00, 1e-9));
      // The queen-hanging blunder should produce a real comment.
      expect(child.comment, contains('nebranjen'));

      child.comment = 'moj ručni komentar';
      await service.annotateNodeChain(
        startNode: root,
        analyzer: _SequencedFakeEngine(['+0.00', '-9.00']).analyze,
        overwriteExisting: false,
      );

      expect(child.comment, 'moj ručni komentar');
    });

    test('4. tagBlunders marks only the requested side and inserts the engine\'s alternative', () async {
      // Position0 (White to move, best line here would be a quiet e4 as far
      // as the fake engine is concerned): eval +0.20.
      // White plays a4 (a genuine blunder relative to the fake engine's
      // 'e2e4' suggestion) -> Position1: eval -3.00 (a big swing for White).
      // Black then plays a small, non-blunder move.
      final root = AnalysisNode(fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      final whiteChild = root.addChild(childFen: 'rnbqkbnr/pppppppp/8/8/P7/8/1PPPPPPP/RNBQKBNR b KQkq a3 0 1', san: 'a4', uci: 'a2a4');
      final blackChild = whiteChild.addChild(childFen: 'rnbqkbnr/1ppppppp/8/8/p7/8/1PPPPPPP/RNBQKBNR w KQkq - 0 2', san: 'a5', uci: 'a7a5');

      final result = await service.annotateNodeChain(
        startNode: root,
        analyzer: _SequencedFakeEngine(['+0.20', '-3.00', '-2.90'], pvOverride: 'e2e4 e7e5').analyze,
      );

      // Only White's move (index 0) is a blunder beyond the 2.0 threshold;
      // filtering to Black should tag nothing.
      final taggedForBlack = service.tagBlunders(
        chain: result.chain,
        moments: result.moments,
        threshold: 2.0,
        side: BlunderAlertSide.black,
      );
      expect(taggedForBlack, 0);
      expect(whiteChild.nag, isNull);

      final taggedForWhite = service.tagBlunders(
        chain: result.chain,
        moments: result.moments,
        threshold: 2.0,
        side: BlunderAlertSide.white,
      );
      expect(taggedForWhite, 1);
      expect(blackChild.nag, isNull);
      expect(whiteChild.nag, '??');

      // The engine's suggested improvement (e2e4) should now be a sibling
      // variation under root, distinct from the actually-played a4.
      expect(root.children, hasLength(2));
      final altChild = root.children.firstWhere((c) => c.moveUci == 'e2e4');
      expect(altChild.moveSan, 'e4');
      expect(altChild.nag, '!');
    });

    test('5. tagBlunders dampens ordinary swings in an already-decided position but still flags a drastic one', () async {
      // White is already crushing (+15) before the move in both cases —
      // simplifying into a won position naturally costs a few pawns of raw
      // eval without the outcome actually changing, so an ordinary swing
      // (here -3, above the normal 2.0 threshold) should NOT be flagged.
      final quietRoot = AnalysisNode(fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      quietRoot.addChild(childFen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1', san: 'e4', uci: 'e2e4');

      final quietResult = await service.annotateNodeChain(
        startNode: quietRoot,
        analyzer: _SequencedFakeEngine(['+15.00', '+12.00']).analyze,
      );
      final quietTagged = service.tagBlunders(
        chain: quietResult.chain,
        moments: quietResult.moments,
        threshold: 2.0,
      );
      expect(quietTagged, 0);
      expect(quietResult.chain.first.nag, isNull);

      // Same starting advantage, but the move gives back most of it (+15 ->
      // +6) — a real mistake even though White is still winning afterward,
      // so it should still be flagged.
      final drasticRoot = AnalysisNode(fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      drasticRoot.addChild(childFen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1', san: 'e4', uci: 'e2e4');

      final drasticResult = await service.annotateNodeChain(
        startNode: drasticRoot,
        analyzer: _SequencedFakeEngine(['+15.00', '+6.00']).analyze,
      );
      final drasticTagged = service.tagBlunders(
        chain: drasticResult.chain,
        moments: drasticResult.moments,
        threshold: 2.0,
      );
      expect(drasticTagged, 1);
      expect(drasticResult.chain.first.nag, '??');
    });
  });
}
