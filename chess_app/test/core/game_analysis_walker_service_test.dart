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
  int callIndex = 0;

  _SequencedFakeEngine(this.evalSequence);

  Future<List<AnalysisLine>> analyze(
    String fen, {
    required int depth,
    required int multiPV,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final eval = callIndex < evalSequence.length ? evalSequence[callIndex] : '0.00';
    callIndex++;
    return [AnalysisLine.fromPv(multipv: 1, depth: depth, eval: eval, pvString: '', startingFen: fen)];
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
        rootNode: root,
        analyzer: _SequencedFakeEngine(['+0.00', '-9.00']).analyze,
      );

      expect(child.eval, closeTo(-9.00, 1e-9));
      // The queen-hanging blunder should produce a real comment.
      expect(child.comment, contains('nebranjen'));

      child.comment = 'moj ručni komentar';
      await service.annotateNodeChain(
        rootNode: root,
        analyzer: _SequencedFakeEngine(['+0.00', '-9.00']).analyze,
        overwriteExisting: false,
      );

      expect(child.comment, 'moj ručni komentar');
    });
  });
}
