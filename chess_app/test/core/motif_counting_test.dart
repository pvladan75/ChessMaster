import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/core/models/tactical_motif.dart';
import 'package:chess_app/core/services/tactical_motif_detector.dart';

/// What the detector counts as a motif, as opposed to how it says it.
///
/// Written on 13.9.2026, after a model reading the review of three games
/// repeated every finding word for word — so a finding that is geometrically
/// true and teaches nothing became a sentence in a tutorial. Every „must not"
/// below is a position one of those games reached, named by the move that led
/// to it and the sentence the detector wrote there; every „must" is the case
/// the same rule has to keep.
void main() {
  const detector = TacticalMotifDetector();

  List<MotifFinding> motifs(MotifResult result, TacticalMotif motif) =>
      result.findings.where((f) => f.motifs.contains(motif)).toList();

  bool touches(MotifFinding f, List<String> squares) =>
      squares.every(f.affectedSquares.contains);

  group('a skewer needs a piece that must move and a piece worth winning', () {
    test('pvladan 19. Rg3: a queen skewered onto a defended pawn is not one',
        () {
      // Was: „Skewer: the black queen on g5 has to move, exposing the black
      // pawn on g6" — the pawn is held by f7 and h7. The reverse line, the
      // white rook on g3 in front of g2, is defended by f2 and is not forced
      // to move by a queen at all.
      final result = detector.detect(
          fen: 'r4rk1/p4pbp/1p4p1/2pNp1q1/4P3/6RP/PPP1QPP1/3R2K1 b - - 2 19',
          lastMoveUci: 'd3g3');

      final skewers = motifs(result, TacticalMotif.skewer);
      expect(skewers.where((f) => touches(f, ['g5', 'g6'])), isEmpty);
      expect(skewers.where((f) => touches(f, ['g3', 'g2'])), isEmpty);
    });

    test('philidor 10. Qxb7: a knight in front of a defended pawn is not one',
        () {
      // Was: „Skewer: the black knight on c6 has to move, exposing the black
      // pawn on d5" — d5 is held by the knight on f6 and the queen on d8.
      final result = detector.detect(
          fen:
              'r2q3r/pQp1bkpp/2n2n2/3p4/3PP1b1/5N2/PP1N1PPP/R1B1K2R b KQ - 0 10',
          lastMoveUci: 'b3b7');

      expect(
          motifs(result, TacticalMotif.skewer)
              .where((f) => touches(f, ['c6', 'd5'])),
          isEmpty);
    });

    test('a defended rook attacked by a queen does not have to move', () {
      // The rook on c3 is held by the pawn on b4: taking it costs the queen.
      final result =
          detector.detect(fen: '4k3/8/8/4b3/1p6/2r5/8/Q5K1 b - - 0 1');

      expect(motifs(result, TacticalMotif.skewer), isEmpty);
    });

    test(
        'a defended queen attacked by a bishop, with a defended rook behind it, is one',
        () {
      // Both black pieces are defended — the pawn on b4 holds c3, the king on
      // f6 holds e5 — so only their worth makes this a skewer: a queen is
      // worth more than the bishop, and a rook is worth winning.
      final result =
          detector.detect(fen: '8/8/5k2/4r3/1p6/2q5/8/B5K1 b - - 0 1');

      expect(motifs(result, TacticalMotif.skewer).map((f) => f.description), [
        'The white bishop on a1 skewers the black queen on c3 and the rook on e5 behind it.',
      ]);
    });

    test('a queen in front of a loose pawn it alone defends is skewered', () {
      // The pawn on a7 is worth winning only because nothing holds it once
      // the queen has stepped off the file — the queen is its one defender.
      final result = detector.detect(fen: '7k/p7/8/8/q7/8/8/R5K1 b - - 0 1');

      expect(motifs(result, TacticalMotif.skewer).map((f) => f.description), [
        'The white rook on a1 skewers the black queen on a4 and the pawn on a7 behind it.',
      ]);
    });

    test('a loose knight in front of a loose pawn is skewered by a queen', () {
      // A knight is worth less than the queen, so it has to move only because
      // nothing defends it.
      final result = detector.detect(fen: '7k/8/8/4p3/8/2n5/8/Q5K1 b - - 0 1');

      expect(motifs(result, TacticalMotif.skewer).map((f) => f.description), [
        'The white queen on a1 skewers the black knight on c3 and the pawn on e5 behind it.',
      ]);
    });
  });

  group('a pin needs something behind worth more than the pinning piece', () {
    test('pvladan 3. Bc4: a pawn in front of a defended knight is not pinned',
        () {
      // Was: „Pin: the black pawn on f7 is pinned to the black knight on g8".
      // Knight for bishop is an even trade, and the rook on h8 holds g8.
      final result = detector.detect(
          fen:
              'r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3',
          lastMoveUci: 'f1c4');

      expect(
          motifs(result, TacticalMotif.pin)
              .where((f) => f.affectedSquares.contains('f7')),
          isEmpty);
    });

    test('a knight in front of the queen is pinned', () {
      // The rook on d8 holds the queen: it is its worth, not its being loose,
      // that makes the knight unable to move.
      final result =
          detector.detect(fen: '3rq2k/8/2n5/1B6/8/8/8/6K1 b - - 0 1');

      expect(motifs(result, TacticalMotif.pin).map((f) => f.description), [
        'The white bishop on b5 pins the black knight on c6 to the queen on e8.',
      ]);
    });

    test('a pawn in front of an undefended knight is pinned', () {
      // Knight for bishop is even, but nothing takes back on e6.
      final result =
          detector.detect(fen: '6k1/8/4n3/3p4/2B5/8/8/6K1 b - - 0 1');

      expect(
          motifs(result, TacticalMotif.pin)
              .where((f) => touches(f, ['c4', 'd5', 'e6'])),
          hasLength(1));
    });

    test('a bishop pinned to a rook that only the bishop defends is pinned',
        () {
      // The rook is worth less than the queen, and the bishop is the one
      // piece holding it: once the bishop leaves the line, e5 is loose.
      final result = detector.detect(fen: '7k/8/8/4r3/8/2b5/8/Q5K1 b - - 0 1');

      expect(motifs(result, TacticalMotif.pin).map((f) => f.description), [
        'The white queen on a1 pins the black bishop on c3 to the rook on e5.',
      ]);
    });
  });

  group('a fork counts only the targets it can win', () {
    test('pvladan 26... Rxd7: the queen forks the two rooks, not five pieces',
        () {
      // Was: „Fork: the white queen on d5 attacks five black pieces: the black
      // rook on a8, the black pawn on c5, the black rook on d7, the black pawn
      // on e5 and the black pawn on f7". Every pawn there is defended; both
      // rooks are not.
      final result = detector.detect(
          fen: 'r5k1/p2r1pbp/1p3qp1/2pQp3/4P3/2N4P/PPP2PP1/3R2K1 w - - 0 27');

      final forks = motifs(result, TacticalMotif.fork);
      expect(forks.map((f) => f.description), [
        'The white queen on d5 forks the black rook on a8 and the rook on d7.',
      ]);
      expect(forks.single.affectedSquares, unorderedEquals(['d5', 'a8', 'd7']));
    });

    test('french 17... Bxe3+: check and a defended pawn is not a fork', () {
      // Was: „Fork: the black bishop on e3 attacks two white pieces: the white
      // pawn on f4 and the white king on g1" — the rook on f1 holds f4.
      final result = detector.detect(
          fen: '3rk2r/p1q2pp1/1p2b3/3pPpNp/5P2/2PQb3/PP4PP/3R1RK1 w k - 0 18',
          lastMoveUci: 'c5e3');

      expect(motifs(result, TacticalMotif.fork), isEmpty);
    });

    test('pvladan 8. dxe5: a pawn attacking a knight and a pawn is not a fork',
        () {
      // Was: „Fork: the white pawn on e5 attacks two black pieces: the black
      // pawn on d6 and the black knight on f6". d6 is defended three times.
      final result = detector.detect(
          fen:
              'r2q1rk1/ppp1bppp/2np1n2/4P3/2B1P1b1/2N2N2/PPP2PPP/R1BQR1K1 b - - 0 8',
          lastMoveUci: 'd4e5');

      expect(motifs(result, TacticalMotif.fork), isEmpty);
    });

    test('philidor 9. Qb3+: check and an undefended pawn is a fork', () {
      // The game went 10. Qxb7 — this one was real.
      final result = detector.detect(
          fen:
              'r2q3r/ppp1bkpp/2np1n2/8/3PP1b1/1Q3N2/PP1N1PPP/R1B1K2R b KQ - 1 9',
          lastMoveUci: 'd1b3');

      expect(motifs(result, TacticalMotif.fork).map((f) => f.description), [
        'The white queen on b3 forks the black king on f7 and the pawn on b7.',
      ]);
    });

    test('a knight forking the king and a defended rook is a fork', () {
      // The bishop on b7 holds a8, but a rook is worth more than a knight.
      final result = detector.detect(
          fen: 'r3k3/1bN5/8/8/8/8/8/7K b - - 0 1', lastMoveUci: 'c2c7');

      expect(motifs(result, TacticalMotif.fork).map((f) => f.description), [
        'The white knight on c7 forks the black king on e8 and the rook on a8.',
      ]);
    });

    test('a queen attacking two defended rooks is not a fork', () {
      final result = detector.detect(
          fen: 'rk5r/7r/8/8/4Q3/8/8/6K1 b - - 0 1', lastMoveUci: 'e1e4');

      expect(motifs(result, TacticalMotif.fork), isEmpty);
    });

    test('a queen attacking two undefended rooks is a fork', () {
      final result = detector.detect(
          fen: 'r7/7r/8/8/4Q3/8/8/k5K1 b - - 0 1', lastMoveUci: 'e1e4');

      expect(motifs(result, TacticalMotif.fork).map((f) => f.description), [
        'The white queen on e4 forks the black rook on a8 and the rook on h7.',
      ]);
    });
  });

  group('overloading and deflection guard pieces, not the king', () {
    List<MotifFinding> defenders(MotifResult result) => result.findings
        .where((f) =>
            f.motifs.contains(TacticalMotif.overloading) ||
            f.motifs.contains(TacticalMotif.deflection))
        .toList();

    test('french 17... Bxe3+: a rook is not overloaded by „defending" the king',
        () {
      // Was: „Overloaded piece: the white rook on f1 defends two white pieces
      // at once (the white pawn on f4 and the white king on g1)".
      final result = detector.detect(
          fen: '3rk2r/p1q2pp1/1p2b3/3pPpNp/5P2/2PQb3/PP4PP/3R1RK1 w k - 0 18',
          lastMoveUci: 'c5e3');

      expect(defenders(result).where((f) => f.affectedSquares.contains('g1')),
          isEmpty);
    });

    test('french 20... Qxd4+: a king is never „left undefended"', () {
      // Was: „the white rook on d1 is the only defender of the white king on
      // g1, and is under attack itself — if it moves away, the white king is
      // left undefended".
      final result = detector.detect(
          fen: '3r1rk1/p4pp1/1p2b3/3pPpNp/3q1P2/2P2R2/PP4PP/3R2K1 w - - 0 21',
          lastMoveUci: 'c5d4');

      expect(defenders(result).where((f) => f.affectedSquares.contains('g1')),
          isEmpty);
    });

    test('pvladan 22. Qc4: a pawn guarding a pawn is a pawn chain, not a motif',
        () {
      // Was: „Deflection: the black pawn on b6 is the only defender of the
      // black pawn on c5, and is under attack itself".
      final result = detector.detect(
          fen: 'r2qr1k1/p4pbp/1p4p1/2pNp3/2Q1P3/6RP/PPP2PP1/3R2K1 b - - 8 22',
          lastMoveUci: 'e2c4');

      expect(defenders(result).where((f) => touches(f, ['b6', 'c5'])), isEmpty);
    });
  });
}
