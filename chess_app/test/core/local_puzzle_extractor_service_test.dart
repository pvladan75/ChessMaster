import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/core/services/local_puzzle_extractor_service.dart';
import 'package:chess_app/models/analysis_models.dart';

class _SequencedFakeEngine {
  final List<String> evalSequence;

  /// The engine's line at each call, in UCI; empty names no move.
  final List<String> pvSequence;
  int callIndex = 0;

  _SequencedFakeEngine(this.evalSequence, [this.pvSequence = const []]);

  Future<List<AnalysisLine>> analyze(
    String fen, {
    required int depth,
    required int multiPV,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final eval =
        callIndex < evalSequence.length ? evalSequence[callIndex] : '0.00';
    final pv = callIndex < pvSequence.length ? pvSequence[callIndex] : '';
    callIndex++;
    return [
      AnalysisLine.fromPv(
          multipv: 1, depth: depth, eval: eval, pvString: pv, startingFen: fen)
    ];
  }
}

void main() {
  group('LocalPuzzleExtractorService', () {
    late LocalPuzzleExtractorService service;

    setUp(() {
      service = LocalPuzzleExtractorService();
    });

    test(
        '1. Extracts a puzzle from a hanging-queen blunder and labels it via TacticalMotifDetector',
        () async {
      // White plays Qd1-d5 straight into the Black Rook on d8 — a pure
      // blunder (matches the "created" hanging-queen test already covered
      // in tactical_motif_detector_test.dart).
      final puzzles = await service.extractPuzzles(
        startingFen: '3r2k1/8/8/8/8/8/8/3Q2K1 w - - 0 1',
        uciMoves: ['d1d5'],
        analyzer: _SequencedFakeEngine(['+0.00', '-9.00']).analyze,
      );

      expect(puzzles, hasLength(1));
      final puzzle = puzzles.first;
      expect(puzzle.fen, '3r2k1/8/8/3Q4/8/8/8/6K1 b - - 1 1');
      expect(puzzle.themeKey, 'hangingPiece');
      expect(puzzle.swing, lessThanOrEqualTo(-2.0));

      // The game's last move: no next moment to take the answer from. The
      // review asks the engine once for these (docs/PLAN-MATERIJAL.md,
      // phase 4); until then this said how the puzzle mode would read it.
      expect(puzzle.refutationSan, isNull);
    });

    test(
        'the answer is the best move of the next moment — the reply the engine '
        'found to the blunder, not the blunder itself', () async {
      // Qd5?? and then Black takes it: the engine, asked about the position
      // after Qd5, already named Rxd5.
      final puzzles = await service.extractPuzzles(
        startingFen: '3r2k1/8/8/8/8/8/8/3Q2K1 w - - 0 1',
        uciMoves: ['d1d5', 'd8d5'],
        analyzer: _SequencedFakeEngine(
            ['+0.00', '-9.00', '-9.00'], ['d1d3', 'd8d5', '']).analyze,
      );

      expect(puzzles, hasLength(1));
      expect(puzzles.single.sourceMoveSan, 'Qd5+');
      expect(puzzles.single.refutationSan, 'Rxd5');
    });

    test(
        '2. Does not extract a puzzle when the swing stays under the threshold',
        () async {
      final puzzles = await service.extractPuzzles(
        startingFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        uciMoves: ['e2e4'],
        analyzer: _SequencedFakeEngine(['+0.20', '-0.90']).analyze,
        blunderThreshold: 2.0,
      );

      expect(puzzles, isEmpty);
    });

    test('3. Caps results at maxPuzzles, worst blunder first', () async {
      // Three moves in a row, each a big blunder of increasing severity for
      // whoever is on move (alternating White/Black), capped to 2 puzzles.
      final puzzles = await service.extractPuzzles(
        startingFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        uciMoves: ['e2e4', 'e7e5', 'g1f3'],
        analyzer:
            _SequencedFakeEngine(['0.00', '-3.00', '3.50', '-2.50']).analyze,
        blunderThreshold: 2.0,
        maxPuzzles: 2,
      );

      expect(puzzles, hasLength(2));
      // Worst (most negative) swing sorts first.
      expect(puzzles[0].swing, lessThanOrEqualTo(puzzles[1].swing));
    });
  });
}
