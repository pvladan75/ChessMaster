import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/core/models/tactical_motif.dart';
import 'package:chess_app/core/services/tactical_motif_detector.dart';

void main() {
  group('TacticalMotifDetector Full Geometric Detection Unit Tests', () {
    late TacticalMotifDetector detector;

    setUp(() {
      detector = const TacticalMotifDetector();
    });

    test('1. Detects Knight Fork (King + Queen/Rook attack)', () {
      // White Knight on c7 attacks Black King on e8 AND Black Rook on a8.
      // FEN: r3k3/2N5/8/8/8/8/8/7K b - - 0 1 (Black to move, White Knight on c7 just moved)
      const fen = 'r3k3/2N5/8/8/8/8/8/7K b - - 0 1';
      final result = detector.detect(
        fen: fen,
        lastMoveUci: 'c2c7',
      );

      expect(result.hasMotif, isTrue);
      expect(result.motifs, contains(TacticalMotif.fork));
      expect(result.motifs, contains(TacticalMotif.doubleAttack));
      expect(result.affectedSquares, containsAll(['c7', 'e8', 'a8']));
      expect(result.description, contains('Viljuška'));
    });

    test('2. Detects Absolute Pin with Bishop along diagonal', () {
      // Black Bishop on b4 pins White Pawn on d2 to White King on e1 along b4-c3-d2-e1 diagonal.
      // FEN: r1bqk1nr/pppp1ppp/8/4p3/1b2P3/8/PPPPNPPP/R1BQKB1R w KQkq - 2 3
      const fen = 'r1bqk1nr/pppp1ppp/8/4p3/1b2P3/8/PPPPNPPP/R1BQKB1R w KQkq - 2 3';
      final result = detector.detect(fen: fen);

      expect(result.hasMotif, isTrue);
      expect(result.motifs, contains(TacticalMotif.pin));
      expect(result.affectedSquares, containsAll(['b4', 'd2', 'e1']));
      expect(result.description, contains('Vezivanje'));
    });

    test('3. Detects Discovered Check when Knight unblocks slider ray', () {
      // White Queen on e2, White Knight was on e5, Black King on e8.
      // Knight moves e5d7 (lastMoveUci: 'e5d7'), opening the e-file for White Queen on e2 to attack e8 (King).
      // FEN after e5d7: r1bqk2r/pppp1ppp/8/8/8/8/PPP1QPPP/RNB1KB1R b KQkq - 0 1
      const fen = 'r1bqk2r/pppp1ppp/8/8/8/8/PPP1QPPP/RNB1KB1R b KQkq - 0 1';
      final result = detector.detect(
        fen: fen,
        lastMoveUci: 'e5d7',
      );

      expect(result.hasMotif, isTrue);
      expect(result.motifs, contains(TacticalMotif.discoveredAttack));
      expect(result.affectedSquares, containsAll(['e2', 'e5', 'e8']));
      expect(result.description, contains('Otkriveni šah'));
    });

    test('4. Detects Skewer along horizontal/orthogonal line', () {
      // White Rook on a1 attacks Black King on a5, behind which is undefended Black Queen on a8.
      // FEN: q6k/8/8/k7/8/8/8/R6K b - - 0 1 (Black is to move)
      const fen = 'q6k/8/8/k7/8/8/8/R6K b - - 0 1';
      final result = detector.detect(fen: fen);

      expect(result.hasMotif, isTrue);
      expect(result.motifs, contains(TacticalMotif.skewer));
      expect(result.affectedSquares, containsAll(['a1', 'a5', 'a8']));
      expect(result.description, contains('Ražanj'));
    });

    test('5. Verifies empty motif result for quiet starting position', () {
      const fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
      final result = detector.detect(fen: fen);

      expect(result.hasMotif, isFalse);
      expect(result.motifs, isEmpty);
      expect(result.affectedSquares, isEmpty);
    });
  });
}
