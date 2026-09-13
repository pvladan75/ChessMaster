import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/core/models/tactical_motif.dart';
import 'package:chess_app/core/services/tactical_motif_detector.dart';

MotifFinding _only(MotifResult result, TacticalMotif motif, {String? square}) {
  final matching = result.findings
      .where((f) =>
          f.motifs.contains(motif) &&
          (square == null || f.affectedSquares.contains(square)))
      .toList();
  expect(matching, hasLength(1),
      reason: 'expected one $motif finding'
          '${square == null ? '' : ' on $square'}, got '
          '${result.findings.map((f) => f.description).toList()}');
  return matching.single;
}

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
      // The king is named first: the most valuable target leads.
      expect(_only(result, TacticalMotif.fork).description,
          'The white knight on c7 forks the black king on e8 and the rook on a8.');
    });

    test('2. Detects Absolute Pin with Bishop along diagonal', () {
      // Black Bishop on b4 pins White Pawn on d2 to White King on e1 along b4-c3-d2-e1 diagonal.
      // FEN: r1bqk1nr/pppp1ppp/8/4p3/1b2P3/8/PPPPNPPP/R1BQKB1R w KQkq - 2 3
      const fen =
          'r1bqk1nr/pppp1ppp/8/4p3/1b2P3/8/PPPPNPPP/R1BQKB1R w KQkq - 2 3';
      final result = detector.detect(fen: fen);

      expect(result.hasMotif, isTrue);
      expect(result.motifs, contains(TacticalMotif.pin));
      expect(result.affectedSquares, containsAll(['b4', 'd2', 'e1']));
      // The pinning piece is named — „pinned to the king" by what, otherwise?
      expect(_only(result, TacticalMotif.pin, square: 'b4').description,
          'The black bishop on b4 pins the white pawn on d2 to the king on e1.');
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
      expect(
          _only(result, TacticalMotif.discoveredAttack).description,
          'The move from e5 uncovers a discovered check: '
          'the white queen on e2 now attacks the black king on e8.');
    });

    test('4. Detects Skewer along horizontal/orthogonal line', () {
      // White Rook on a1 attacks Black King on a5, behind which is undefended Black Queen on a8.
      // FEN: q6k/8/8/k7/8/8/8/R6K b - - 0 1 (Black is to move)
      const fen = 'q6k/8/8/k7/8/8/8/R6K b - - 0 1';
      final result = detector.detect(fen: fen);

      expect(result.hasMotif, isTrue);
      expect(result.motifs, contains(TacticalMotif.skewer));
      expect(result.affectedSquares, containsAll(['a1', 'a5', 'a8']));
      expect(_only(result, TacticalMotif.skewer).description,
          'The white rook on a1 skewers the black king on a5 and the queen on a8 behind it.');
    });

    test('5. Verifies empty motif result for quiet starting position', () {
      const fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
      final result = detector.detect(fen: fen);

      expect(result.hasMotif, isFalse);
      expect(result.motifs, isEmpty);
      expect(result.affectedSquares, isEmpty);
    });

    test(
        '6. Detects hanging Queen via SEE even when defender count matches attacker count',
        () {
      // Black Queen on d5 attacked only by White pawn c4, "defended" only by
      // Black rook d8. Naive attacker/defender counting (1 vs 1) would call
      // this safe, but the Queen is worth far more than the pawn: SEE must
      // recognize White profits massively from the trade.
      const fen = '3r2k1/8/8/3q4/2P5/8/8/6K1 b - - 0 1';
      final result = detector.detect(fen: fen);

      expect(result.motifs, contains(TacticalMotif.hangingPiece));
      expect(result.affectedSquares, contains('d5'));
      // It is defended, so it must not be called undefended: the sentence
      // says what actually loses it.
      expect(
          _only(result, TacticalMotif.hangingPiece, square: 'd5').description,
          'The black queen on d5 is attacked by the white pawn on c4, a cheaper piece.');
    });

    test('7. Ignores an absolutely pinned piece as a defender', () {
      // Black Rook on e5 is pinned to the Black King (e8) by White Rook e1.
      // It can geometrically reach d5 along the rank, but moving there is
      // illegal, so the Black pawn on d5 (attacked by White Bishop b3) is
      // actually hanging despite the apparent "defender".
      const fen = '4k3/8/8/3pr3/8/1B6/8/K3R3 b - - 0 1';
      final result = detector.detect(fen: fen);

      expect(result.motifs, contains(TacticalMotif.hangingPiece));
      expect(result.affectedSquares, contains('d5'));
    });

    test(
        '8. Flags a piece the mover left hanging for the opponent (favorsMover=false)',
        () {
      // White Queen on d5 is attacked by Black Rook d8 with no defender.
      // Earlier the detector only ever looked at threats the mover creates
      // against the opponent — it never checked whether the mover's own
      // move left one of their own pieces hanging. Black is to move here.
      const fen = '3r2k1/8/8/3Q4/8/8/8/6K1 b - - 0 1';
      final result = detector.detect(fen: fen);

      final blunder = result.findings.firstWhere(
        (f) => !f.favorsMover && f.motifs.contains(TacticalMotif.hangingPiece),
        orElse: () =>
            throw StateError('expected a favorsMover=false hanging finding'),
      );
      expect(blunder.affectedSquares, contains('d5'));
      expect(blunder.description,
          'The white queen on d5 is attacked by the black rook on d8 and has no defender.');
    });

    test('9. explainMove flags a freshly hung Queen as "created"', () {
      // White plays Qd1-d5 straight into an undefended square attacked by
      // the Black Rook on d8 — a pure blunder that didn't exist before it.
      const beforeFen = '3r2k1/8/8/8/8/8/8/3Q2K1 w - - 0 1';
      const afterFen = '3r2k1/8/8/3Q4/8/8/8/6K1 b - - 0 1';

      final diff = detector.explainMove(
          beforeFen: beforeFen, afterFen: afterFen, lastMoveUci: 'd1d5');

      final blunder = diff.created.firstWhere(
        (f) => !f.favorsMover && f.motifs.contains(TacticalMotif.hangingPiece),
        orElse: () =>
            throw StateError('expected a newly-created hanging finding'),
      );
      expect(blunder.affectedSquares, contains('d5'));

      // A threat against the side who moved carries no prefix: the sentence
      // says whose queen it is.
      final comment = detector.describeMoveDiff(diff);
      expect(
          comment,
          contains(
              'The white queen on d5 is attacked by the black rook on d8 and has no defender.'));
      expect(comment, isNot(contains('Watch out')));
      expect(comment, isNot(contains('Resolved')));
      expect(comment, isNot(contains('|')));
    });

    test('10. explainMove flags a hanging piece the move fixed as "resolved"',
        () {
      // White Knight on e5 was hanging to Black Bishop b8 (no defender);
      // White plays Ne5-d3 to safety. The pre-existing threat should show up
      // as resolved, and nothing new should be created for White.
      const beforeFen = '1b5k/8/8/4N3/8/8/8/K7 w - - 0 1';
      const afterFen = '1b5k/8/8/8/8/3N4/8/K7 b - - 0 1';

      final diff = detector.explainMove(
          beforeFen: beforeFen, afterFen: afterFen, lastMoveUci: 'e5d3');

      final saved = diff.resolved.firstWhere(
        (f) => !f.favorsMover && f.motifs.contains(TacticalMotif.hangingPiece),
        orElse: () => throw StateError('expected a resolved hanging finding'),
      );
      expect(saved.affectedSquares, contains('e5'));
      expect(diff.created.any((f) => !f.favorsMover), isFalse);

      // What ended is said as a sentence of its own, not a prefix on the
      // sentence that is no longer true.
      expect(saved.goneDescription,
          'The white knight on e5 is no longer hanging.');
      expect(detector.describeMoveDiff(diff),
          'The white knight on e5 is no longer hanging.');
      expect(detector.candidateCommentLines(diff),
          ['The white knight on e5 is no longer hanging.']);
    });

    test(
        '11. Detects deflection: attacking the sole defender exposes what it guards',
        () {
      // White Rook a1 attacks Black Knight a5, whose only defender is Black
      // Queen a8. White Rook h8 attacks that same queen along the 8th rank —
      // luring/forcing it away from a8 abandons the knight's only defense.
      const fen = 'q6R/8/8/n7/5k2/8/8/R3K3 b - - 0 1';
      final result = detector.detect(fen: fen);

      final deflection = result.findings.firstWhere(
        (f) => f.motifs.contains(TacticalMotif.deflection),
        orElse: () => throw StateError('expected a deflection finding'),
      );
      expect(deflection.affectedSquares, containsAll(['a8', 'a5']));
      // The attacker is named: „under attack itself" said by what.
      expect(
          deflection.description,
          'The black queen on a8 is the only defender of the knight on a5, '
          'and it is attacked by the white rook on h8.');
    });

    test('12. A capture that walks into immediate mate is not a real threat',
        () {
      // Black pawn g6 can geometrically capture the undefended White Rook on
      // f5, but doing so allows White to answer Qa2-g8#: the queen travels
      // the long a2-g8 diagonal, defended by the Knight on f6, while the
      // Black king is boxed in by its own g7/h7 pawns. The rook must NOT be
      // flagged as hanging — g6 isn't a real attacker.
      const fen = '7k/6pp/5Np1/5R2/8/8/Q7/K7 b - - 0 1';
      final result = detector.detect(fen: fen);

      final rookFlaggedHanging = result.findings.any(
        (f) =>
            f.motifs.contains(TacticalMotif.hangingPiece) &&
            f.affectedSquares.contains('f5'),
      );
      expect(rookFlaggedHanging, isFalse);
    });

    test(
        '13. describeMoveDiff drops a low-significance finding when something bigger happened',
        () {
      // A hanging pawn shouldn't crowd out a fork on a queen/rook in the
      // same comment — it isn't newsworthy by comparison.
      const diff = MoveMotifDiff(
        created: [
          MotifFinding(
            motifs: [TacticalMotif.fork],
            description:
                'The white knight on e5 forks the black queen on d7 and the rook on c6.',
            goneDescription: 'The fork by the white knight on e5 is over.',
            affectedSquares: ['e5'],
            favorsMover: true,
            significance: 9,
          ),
          MotifFinding(
            motifs: [TacticalMotif.hangingPiece],
            description:
                'The white pawn on a2 is attacked by the black rook on a8 and has no defender.',
            goneDescription: 'The white pawn on a2 is no longer hanging.',
            affectedSquares: ['a2'],
            favorsMover: false,
            significance: 1,
          ),
        ],
        resolved: [],
      );

      final comment = detector.describeMoveDiff(diff);

      expect(comment,
          'The white knight on e5 forks the black queen on d7 and the rook on c6.');
    });

    test(
        '14. describeMoveDiff keeps a low-significance finding when it is all that happened',
        () {
      const diff = MoveMotifDiff(
        created: [
          MotifFinding(
            motifs: [TacticalMotif.hangingPiece],
            description:
                'The white pawn on a2 is attacked by the black rook on a8 and has no defender.',
            goneDescription: 'The white pawn on a2 is no longer hanging.',
            affectedSquares: ['a2'],
            favorsMover: false,
            significance: 1,
          ),
        ],
        resolved: [],
      );

      final comment = detector.describeMoveDiff(diff);

      expect(comment, contains('a2'));
    });

    test(
        '15. describeMoveDiff writes sentences joined by a space, and says only what ended against the mover',
        () {
      const diff = MoveMotifDiff(
        created: [
          MotifFinding(
            motifs: [TacticalMotif.pin],
            description:
                'The white bishop on b5 pins the black knight on c6 to the king on e8.',
            goneDescription: 'The black knight on c6 is no longer pinned.',
            affectedSquares: ['b5', 'c6', 'e8'],
            favorsMover: true,
            significance: 5,
          ),
        ],
        resolved: [
          MotifFinding(
            motifs: [TacticalMotif.hangingPiece],
            description:
                'The white knight on f3 is attacked by the black pawn on e4, a cheaper piece.',
            goneDescription: 'The white knight on f3 is no longer hanging.',
            affectedSquares: ['f3'],
            favorsMover: false,
            significance: 3,
          ),
          // A threat the mover had against the opponent that ended is not
          // narrated — this one must not appear.
          MotifFinding(
            motifs: [TacticalMotif.hangingPiece],
            description:
                'The black rook on a8 is attacked by the white queen on d5 and has no defender.',
            goneDescription: 'The black rook on a8 is no longer hanging.',
            affectedSquares: ['a8'],
            favorsMover: true,
            significance: 5,
          ),
        ],
      );

      expect(
          detector.describeMoveDiff(diff),
          'The white bishop on b5 pins the black knight on c6 to the king on e8. '
          'The white knight on f3 is no longer hanging.');
      expect(detector.candidateCommentLines(diff), [
        'The white bishop on b5 pins the black knight on c6 to the king on e8.',
        'The white knight on f3 is no longer hanging.',
      ]);
    });

    test('16. Two pins are two findings, each one sentence', () {
      // Rook e1 pins the knight on e5 to the king; bishop b5 pins the knight
      // on c6 to the same king. One finding holding both as „Pin: a | b" was
      // what the checklist dialog could never match again.
      const fen = '4k3/8/2n5/1B2n3/8/8/8/4R1K1 b - - 0 1';
      final result = detector.detect(fen: fen);

      final pins = result.findings
          .where((f) => f.motifs.contains(TacticalMotif.pin))
          .map((f) => f.description)
          .toList();
      expect(
          pins,
          unorderedEquals([
            'The white bishop on b5 pins the black knight on c6 to the king on e8.',
            'The white rook on e1 pins the black knight on e5 to the king on e8.',
          ]));
    });

    test(
        '17. A piece attacked more often than it is defended says so in counts',
        () {
      // Black knight e5: attacked by the knights on d3 and f3, defended by the
      // knight on c6 alone. No attacker is cheaper, and it has a defender.
      const fen = '4k3/8/2n5/4n3/8/3N1N2/8/4K3 b - - 0 1';
      final result = detector.detect(fen: fen);

      expect(
          _only(result, TacticalMotif.hangingPiece, square: 'e5').description,
          'The black knight on e5 is attacked twice and defended only once.');
    });

    test('18. An overloaded defender names what it alone holds', () {
      // Black rook e5 is the only defender of the knight on a5 (attacked by
      // the pawn on b4) and of the knight on e8 (attacked by the rook on h8).
      const fen = 'k3n2R/8/8/n3r3/1P6/8/8/6K1 b - - 0 1';
      final result = detector.detect(fen: fen);

      final overloaded = _only(result, TacticalMotif.overloading);
      expect(overloaded.description,
          'The black rook on e5 is overloaded: it alone defends the knight on a5 and the knight on e8.');
      expect(overloaded.goneDescription,
          'The black rook on e5 is no longer overloaded.');
    });

    test('19. A mate on the board is called a mate, not a threat', () {
      const fen = '3R2k1/5ppp/8/8/8/8/8/6K1 b - - 0 1';
      final result = detector.detect(fen: fen);

      expect(_only(result, TacticalMotif.mateThreat).description,
          'The black king on g8 is checkmated.');
    });

    test('20. The result joins its findings as sentences', () {
      const fen = '3r2k1/8/8/3Q4/8/8/8/6K1 b - - 0 1';
      final result = detector.detect(fen: fen);

      expect(result.description, isNot(contains('|')));
      for (final finding in result.findings) {
        expect(finding.description, endsWith('.'));
        expect(finding.goneDescription, endsWith('.'));
        expect(result.description, contains(finding.description));
      }
    });
  });
}
