import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/core/models/positional_factor.dart';
import 'package:chess_app/core/models/tactical_motif.dart';
import 'package:chess_app/core/services/positional_evaluator_service.dart';
import 'package:chess_app/core/services/tactical_motif_detector.dart';

/// Two things about a finding that decide what a move's comment says, apart
/// from its words: whether it is the *same* finding before and after the move,
/// and how much it matters.
///
/// Until 13.9.2026 a finding was the same only if it stood on the same squares,
/// so a piece that moved took its finding to a new identity: a queen hanging on
/// d1 that moved to d5 and hung there too was reported both as „no longer
/// hanging" and as newly hanging. And a finding mattered as much as the most
/// valuable piece *on* it — the attacker included — so a queen pinning a pawn
/// counted as nine pawns of material.
void main() {
  const detector = TacticalMotifDetector();
  const positional = PositionalEvaluatorService();

  MotifFinding only(MotifResult result, TacticalMotif motif) {
    final matching =
        result.findings.where((f) => f.motifs.contains(motif)).toList();
    expect(matching, hasLength(1),
        reason: '${result.findings.map((f) => f.description).toList()}');
    return matching.single;
  }

  group('a finding keeps its identity when its piece moves', () {
    test('a queen moving from one attacked square to another is still hanging',
        () {
      // The d-file is open, so the queen on d1 was already attacked by the
      // rook on d8. Qd5 changes nothing about that — it adds a fork.
      final diff = detector.explainMove(
        beforeFen: '3r2k1/8/8/8/8/8/8/3Q2K1 w - - 0 1',
        afterFen: '3r2k1/8/8/3Q4/8/8/8/6K1 b - - 0 1',
        lastMoveUci: 'd1d5',
      );

      bool hanging(MotifFinding f) =>
          f.motifs.contains(TacticalMotif.hangingPiece);
      expect(diff.resolved.where(hanging), isEmpty);
      expect(diff.created.where(hanging), isEmpty);
      expect(detector.describeMoveDiff(diff),
          'The white queen on d5 forks the black king on g8 and the rook on d8.');
    });

    test('a rook sliding along the line of its pin still pins the same knight',
        () {
      final diff = detector.explainMove(
        beforeFen: '4k3/8/8/4n3/8/8/8/4R1K1 w - - 0 1',
        afterFen: '4k3/8/8/4n3/8/8/4R3/6K1 b - - 0 1',
        lastMoveUci: 'e1e2',
      );

      expect(diff.created.where((f) => f.motifs.contains(TacticalMotif.pin)),
          isEmpty);
      expect(detector.describeMoveDiff(diff), '');
    });

    test('a king walking without a pawn shield has not found or lost one', () {
      // Before this, every step of the king wrote „the white king is no longer
      // without a pawn shield" beside „the white king on h1 has lost its pawn
      // shield".
      final diff = positional.explainMove(
        beforeFen: '4k3/8/8/8/8/8/8/6K1 w - - 0 1',
        afterFen: '4k3/8/8/8/8/8/8/7K b - - 0 1',
        lastMoveUci: 'g1h1',
      );

      bool shield(PositionalFinding f) =>
          f.factors.contains(PositionalFactor.kingShield);
      expect(diff.created.where(shield), isEmpty);
      expect(diff.resolved.where(shield), isEmpty);
    });
  });

  group('a finding matters as much as what it can win, not what attacks', () {
    test('a queen pinning a pawn to the king is worth a pawn', () {
      // Was 1000: the king on the line, and before that the queen, counted.
      final result = detector.detect(fen: '7k/8/8/8/3p4/8/8/Q5K1 b - - 0 1');

      expect(only(result, TacticalMotif.pin).significance, 1);
    });

    test('a pin to the queen is worth the queen', () {
      final result =
          detector.detect(fen: '3rq2k/8/2n5/1B6/8/8/8/6K1 b - - 0 1');

      expect(only(result, TacticalMotif.pin).significance, 9);
    });

    test('a knight skewered onto a pawn is worth the pawn', () {
      // The knight is at stake as a hanging piece, which is a finding of its
      // own; what the skewer wins is what stands behind.
      final result = detector.detect(fen: '7k/8/8/4p3/8/2n5/8/Q5K1 b - - 0 1');

      expect(only(result, TacticalMotif.skewer).significance, 1);
    });

    test('a discovered attack is worth the piece it uncovers an attack on', () {
      final result = detector.detect(
          fen: '4k3/4b3/8/8/8/8/8/4R1K1 b - - 0 1', lastMoveUci: 'e4c5');

      expect(only(result, TacticalMotif.discoveredAttack).significance, 3);
    });

    test('a queen forking two rooks is worth a rook', () {
      final result = detector.detect(
          fen: 'r7/7r/8/8/4Q3/8/8/k5K1 b - - 0 1', lastMoveUci: 'e1e4');

      expect(only(result, TacticalMotif.fork).significance, 5);
    });

    test('a fork with check is worth the king', () {
      final result = detector.detect(
          fen: 'r3k3/2N5/8/8/8/8/8/7K b - - 0 1', lastMoveUci: 'c2c7');

      expect(only(result, TacticalMotif.fork).significance, 1000);
    });

    test('an overloaded rook is worth the knights it holds', () {
      final result =
          detector.detect(fen: 'k3n2R/8/8/n3r3/1P6/8/8/6K1 b - - 0 1');

      expect(only(result, TacticalMotif.overloading).significance, 3);
    });

    test('a deflected queen is worth the knight it leaves', () {
      final result = detector.detect(fen: 'q6R/8/8/n7/5k2/8/8/R3K3 b - - 0 1');

      expect(only(result, TacticalMotif.deflection).significance, 3);
    });
  });
}
