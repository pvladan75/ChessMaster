// `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`, phase 1.2b: `annotateNodeChain` and
// `tagBlunders` are gone. The whole-game review is `GameReviewJudge`'s now
// (`game_review_runner.dart`), which marks mistakes by winning chances
// (`mistake_rule.dart`) rather than a pawn threshold this walker computed, so
// cases 4 and 5 below (which tested exactly that threshold, including the
// "already decided → larger threshold" dampening) are deleted rather than
// rewritten — the winning-chances scale makes that dampening unnecessary (a
// swing from +19 to +14 is no swing in chances at all; see
// `test/core/game_review_judge_test.dart`, and `markMistakes`'s own case
// there, "?? on exactly the review's mistakes"). Cases 3 and 6 held a rule
// about `analyzeGame` itself (no comment is written onto anything it visits,
// and a walked king's positional diff does not invent a shield finding), so
// they are rewritten to call it directly instead of through the deleted
// `annotateNodeChain` wrapper — they never needed the node tree at all.

import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/core/services/game_analysis_walker_service.dart';
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
    final eval =
        callIndex < evalSequence.length ? evalSequence[callIndex] : '0.00';
    callIndex++;
    return [
      AnalysisLine.fromPv(
          multipv: 1, depth: depth, eval: eval, pvString: '', startingFen: fen)
    ];
  }
}

void main() {
  group('GameAnalysisWalkerService', () {
    late GameAnalysisWalkerService service;

    setUp(() {
      service = GameAnalysisWalkerService();
    });

    test('1. Computes mover-relative swing correctly for both White and Black',
        () async {
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

      final blackMove = moments[1];
      // Black-relative: was +3.00 (mirrored from -3.00), now +2.80.
      expect(blackMove.evalBeforeForMover, closeTo(3.00, 1e-9));
      expect(blackMove.evalAfterForMover, closeTo(2.80, 1e-9));
      expect(blackMove.swingForMover, closeTo(-0.20, 1e-9));
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

    test(
        '3. analyzeGame writes nothing anywhere, and the moment keeps the '
        'finding', () async {
      // Since 22.9.2026 the findings are not shown to the reader: a review
      // no longer writes them under a move. They travel in the moments,
      // which a tutorial reads.
      final moments = await service.analyzeGame(
        startingFen: '3r2k1/8/8/8/8/8/8/6KQ w - - 0 1',
        // From h1, not d1: on the open d-file the queen was already hanging
        // before the move, and a finding that was true on both sides of a
        // move is not a comment on it.
        uciMoves: ['h1d5'],
        analyzer: _SequencedFakeEngine(['+0.00', '-9.00']).analyze,
      );

      expect(
          moments.single.combinedComment,
          contains('The white queen on d5 is attacked by the black rook on d8 '
              'and has no defender.'));
      // Sentences, not clauses behind a separator a voice would read out.
      expect(moments.single.combinedComment, isNot(contains('|')));
    });

    test('4. A king that walks without a pawn shield gets no shield finding',
        () async {
      // The walker has to hand the move to the positional diff: without it a
      // king stepping g1-h1 reads as a shield lost on h1 and one no longer
      // lost on g1, which is a false positive on a bare board with no pawns
      // at all.
      final moments = await service.analyzeGame(
        startingFen: '4k3/8/8/8/8/8/8/6K1 w - - 0 1',
        uciMoves: ['g1h1'],
        analyzer: _SequencedFakeEngine(['0.00', '0.00']).analyze,
      );

      expect(moments.single.positionalComment, isEmpty);
    });
  });
}
