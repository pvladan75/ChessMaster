import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/core/models/tactical_motif.dart';
import 'package:chess_app/core/services/tactical_motif_detector.dart';

void main() {
  group('TacticalMotifDetector Core Service Unit Tests', () {
    late TacticalMotifDetector detector;

    setUp(() {
      detector = const TacticalMotifDetector();
    });

    test('1. Detects hanging undefended piece', () {
      // Black bishop on a3 is attacked by White queen on g3 (same 3rd rank) and has 0 defenders.
      // FEN: 8/8/1k6/8/8/b5Q1/8/7K b - - 0 1 (Black to move, White queen on g3 attacks a3)
      const fen = '8/8/1k6/8/8/b5Q1/8/7K b - - 0 1';
      final result = detector.detect(fen: fen);

      expect(result.hasMotif, isTrue);
      expect(result.motifs, contains(TacticalMotif.hangingPiece));
      expect(result.affectedSquares, contains('a3'));
      expect(result.description, contains('Napad na nebranjenu figuru'));
    });

    test('2. Detects mate threat via evalText / mateIn parameters', () {
      // Standard initial FEN with forced mate in 1 eval
      const fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 1';
      final result = detector.detect(
        fen: fen,
        evalText: 'M1',
        mateIn: 1,
      );

      expect(result.hasMotif, isTrue);
      expect(result.motifs, contains(TacticalMotif.mateThreat));
      expect(result.description, equals('Pretnja matom'));
    });

    test('3. Detects combined Double Attack: Mate Threat + Piece Attack (mateThreatAndPieceAttack)', () {
      // White Queen on g4 attacks undefended Black bishop on a4 (same 4th rank)
      // FEN: 8/6p1/1k6/8/b5Q1/8/8/7K b - - 0 1
      const fen = '8/6p1/1k6/8/b5Q1/8/8/7K b - - 0 1';
      final result = detector.detect(
        fen: fen,
        evalText: '#1',
        mateIn: 1,
      );

      expect(result.hasMotif, isTrue);
      expect(result.motifs, contains(TacticalMotif.mateThreatAndPieceAttack));
      expect(result.motifs, contains(TacticalMotif.doubleAttack));
      expect(result.motifs, contains(TacticalMotif.hangingPiece));
      expect(result.motifs, contains(TacticalMotif.mateThreat));
      expect(result.affectedSquares, contains('a4'));
      expect(result.description, equals('Dvojni udar: Napad na nebranjenu figuru uz pretnju matom'));
    });

    test('4. Verifies clean signatures for placeholder motif methods', () {
      const fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
      final result = detector.detect(fen: fen);

      expect(result.hasMotif, isFalse);
      expect(result.motifs, isEmpty);
      expect(result.affectedSquares, isEmpty);
    });
  });
}
