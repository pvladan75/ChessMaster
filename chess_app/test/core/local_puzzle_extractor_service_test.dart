import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/core/services/local_puzzle_extractor_service.dart';
import 'package:chess_app/models/analysis_models.dart';

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
  group('LocalPuzzleExtractorService', () {
    late LocalPuzzleExtractorService service;

    setUp(() {
      service = LocalPuzzleExtractorService();
    });

    test('1. Extracts a puzzle from a hanging-queen blunder and labels it via TacticalMotifDetector', () async {
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

      final map = puzzle.toPuzzleMap();
      expect(map['type'], 'winning_position');
      expect(map['solutions'], isEmpty);
      expect(map['isLocal'], isTrue);
      expect(map['fen'], puzzle.fen);
    });

    test('2. Does not extract a puzzle when the swing stays under the threshold', () async {
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
        analyzer: _SequencedFakeEngine(['0.00', '-3.00', '3.50', '-2.50']).analyze,
        blunderThreshold: 2.0,
        maxPuzzles: 2,
      );

      expect(puzzles, hasLength(2));
      // Worst (most negative) swing sorts first.
      expect(puzzles[0].swing, lessThanOrEqualTo(puzzles[1].swing));
    });
  });
}
