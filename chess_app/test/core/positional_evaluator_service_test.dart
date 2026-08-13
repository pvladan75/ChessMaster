import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/core/models/positional_factor.dart';
import 'package:chess_app/core/services/positional_evaluator_service.dart';

void main() {
  group('PositionalEvaluatorService', () {
    late PositionalEvaluatorService service;

    setUp(() {
      service = const PositionalEvaluatorService();
    });

    test('1. Detects doubled and isolated pawns', () {
      // White pawns a2 (no b-pawn -> isolated) and c2/c3 (doubled on the
      // c-file, and isolated too since neither b- nor d-file has a pawn).
      const fen = '4k3/8/8/8/8/2P5/P1P5/4K3 w - - 0 1';
      final result = service.evaluate(fen: fen);

      final doubled = result.findings.firstWhere(
        (f) => f.factors.contains(PositionalFactor.doubledPawn),
        orElse: () => throw StateError('expected a doubled-pawn finding'),
      );
      expect(doubled.affectedSquares, containsAll(['c2', 'c3']));

      final isolated = result.findings.where((f) => f.factors.contains(PositionalFactor.isolatedPawn));
      expect(isolated.any((f) => f.affectedSquares.contains('a2')), isTrue);
      expect(isolated.any((f) => f.affectedSquares.contains('c2')), isTrue);
    });

    test('2. Detects a passed pawn with no enemy pawns ahead', () {
      const fen = '7k/7p/8/P7/8/8/8/7K w - - 0 1';
      final result = service.evaluate(fen: fen);

      final passed = result.findings.firstWhere(
        (f) => f.factors.contains(PositionalFactor.passedPawn) && f.affectedSquares.contains('a5'),
        orElse: () => throw StateError('expected a5 flagged as a passed pawn'),
      );
      expect(passed.description, contains('Prolazni pešak'));
    });

    test('3. Detects a backward pawn controlled by an enemy pawn', () {
      // White d3 is flanked by more-advanced pawns on c4/e4 (so it can't be
      // supported by either advancing) and Black's e5 pawn controls d4, the
      // square d3 would need to advance to.
      const fen = '4k3/8/8/4p3/2P1P3/3P4/8/4K3 w - - 0 1';
      final result = service.evaluate(fen: fen);

      final backward = result.findings.firstWhere(
        (f) => f.factors.contains(PositionalFactor.backwardPawn),
        orElse: () => throw StateError('expected a backward-pawn finding'),
      );
      expect(backward.affectedSquares, contains('d3'));
    });

    test('4. Detects the bishop pair', () {
      const fen = '4k3/8/8/8/8/8/8/2B1KB2 w - - 0 1';
      final result = service.evaluate(fen: fen);

      final pair = result.findings.firstWhere(
        (f) => f.factors.contains(PositionalFactor.bishopPair),
        orElse: () => throw StateError('expected a bishop-pair finding'),
      );
      expect(pair.description, contains('lovačkog para'));
    });

    test('5. Detects a color complex weakness', () {
      // White's only pawns (c4, d3, e4) are all on light squares and White
      // has no light-squared bishop at all.
      const fen = '4k3/8/8/4p3/2P1P3/3P4/8/4K3 w - - 0 1';
      final result = service.evaluate(fen: fen);

      final weakness = result.findings.firstWhere(
        (f) => f.factors.contains(PositionalFactor.colorComplexWeakness),
        orElse: () => throw StateError('expected a color-complex-weakness finding'),
      );
      expect(weakness.description, contains('svetlopoljnog lovca'));
    });

    test('6. Detects a rook controlling an open file', () {
      const fen = '4k3/8/8/8/8/8/8/R3K3 w - - 0 1';
      final result = service.evaluate(fen: fen);

      final openFile = result.findings.firstWhere(
        (f) => f.factors.contains(PositionalFactor.openFile),
        orElse: () => throw StateError('expected an open-file finding'),
      );
      expect(openFile.affectedSquares, contains('a1'));
      expect(openFile.description, contains('otvorenu'));
    });

    test('7. Detects a center-control edge from pawn occupation', () {
      const fen = '4k3/8/8/8/3PP3/8/8/4K3 w - - 0 1';
      final result = service.evaluate(fen: fen);

      final center = result.findings.firstWhere(
        (f) => f.factors.contains(PositionalFactor.centerControl),
        orElse: () => throw StateError('expected a center-control finding'),
      );
      expect(center.description, contains('Beli'));
    });

    test('8. Detects a permanent knight outpost', () {
      // White knight on d5, defended by the c4/e4 pawns, with no Black
      // pawns left on the c- or e-files to ever challenge it.
      const fen = '4k3/8/8/3N4/2P1P3/8/8/4K3 w - - 0 1';
      final result = service.evaluate(fen: fen);

      final outpost = result.findings.firstWhere(
        (f) => f.factors.contains(PositionalFactor.knightOutpost),
        orElse: () => throw StateError('expected a knight-outpost finding'),
      );
      expect(outpost.affectedSquares, contains('d5'));
    });

    test('9. Detects a damaged pawn shield and an open file next to the king', () {
      const fen = '4k3/8/8/8/8/8/8/4K2R w - - 0 1';
      final result = service.evaluate(fen: fen);

      final shieldFindings = result.findings.where((f) => f.factors.contains(PositionalFactor.kingShield));
      expect(shieldFindings.any((f) => f.description.contains('pešačkog štita')), isTrue);
      expect(shieldFindings.any((f) => f.description.contains('otvorena')), isTrue);
    });

    test('10. explainMove diffs positional findings the same way tactical does', () {
      // Before: White knight on b1 (undeveloped, no outpost). After: it
      // jumps to the permanent d5 outpost from test 8.
      const beforeFen = '4k3/8/8/8/2P1P3/8/8/1N2K3 w - - 0 1';
      const afterFen = '4k3/8/8/3N4/2P1P3/8/8/4K3 b - - 0 1';

      final diff = service.explainMove(beforeFen: beforeFen, afterFen: afterFen);

      final created = diff.created.firstWhere(
        (f) => f.factors.contains(PositionalFactor.knightOutpost),
        orElse: () => throw StateError('expected a newly-created outpost finding'),
      );
      expect(created.affectedSquares, contains('d5'));
    });

    test('11. describeMoveDiff and candidateCommentLines format findings consistently', () {
      const beforeFen = '4k3/8/8/8/2P1P3/8/8/1N2K3 w - - 0 1';
      const afterFen = '4k3/8/8/3N4/2P1P3/8/8/4K3 b - - 0 1';
      final diff = service.explainMove(beforeFen: beforeFen, afterFen: afterFen);

      final comment = service.describeMoveDiff(diff);
      final candidates = service.candidateCommentLines(diff);

      expect(comment, contains('uporištu'));
      expect(candidates.any((c) => c.contains('uporištu')), isTrue);
    });

    test('12. describeMoveDiff drops routine "open file near king" churn when shield loss also fires', () {
      // A king losing its whole pawn shield trivially also gets an "open
      // file next to the king" finding on the same move — that fluid signal
      // shouldn't be narrated on top of the much bigger shield-loss story
      // (this is what caused repeated per-square comments during a king
      // hunt: the open-file finding retriggers on every square the king
      // steps to, even when nothing structurally new happened).
      const beforeFen = '4k3/8/8/8/8/8/5PPP/6K1 w - - 0 1';
      const afterFen = '4k3/8/8/8/8/8/8/6K1 b - - 0 1';

      final diff = service.explainMove(beforeFen: beforeFen, afterFen: afterFen);
      final comment = service.describeMoveDiff(diff);

      expect(comment, contains('pešačkog štita'));
      expect(comment, isNot(contains('je otvorena')));

      // Still available for manual selection, just not auto-narrated.
      final candidates = service.candidateCommentLines(diff);
      expect(candidates.any((c) => c.contains('je otvorena')), isTrue);
    });
  });
}
