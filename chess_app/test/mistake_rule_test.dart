// What counts as a mistake — one rule, one home (`docs/PLAN-MOJE-PARTIJE.md`
// §9.1, and phase 1 of `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`). The numbers are
// the owner's choices of 24.9.2026, measured in that plan's phase 0.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/mistake_rule.dart';

void main() {
  group('winning chances', () {
    // The table of PLAN-ZAGONETKE-IZ-PARTIJE.md §3, to the hundredth.
    for (final (cp, w) in const [
      (1900, 99.91),
      (1400, 99.43),
      (500, 86.31),
      (200, 67.62),
      (300, 75.11),
      (0, 50.00),
      (100, 59.10),
      (-100, 40.90),
    ]) {
      test('$cp centipawns are $w', () {
        expect(winningChances(EngineValue.cp(cp)), closeTo(w, 0.005));
      });
    }

    test('a mate is 100 or 0, whatever its distance', () {
      expect(winningChances(const EngineValue.mate(1)), 100);
      expect(winningChances(const EngineValue.mate(23)), 100);
      expect(winningChances(const EngineValue.mate(-2)), 0);
      expect(winningChances(const EngineValue.mate(-30)), 0);
    });
  });

  group('a move', () {
    MoveJudgement judge(EngineValue best, EngineValue played,
            {int bookGames = 0}) =>
        judgeMove(best: best, played: played, bookGames: bookGames);

    test('+19 against +14 is no difference at all', () {
      final j = judge(EngineValue.cp(1900), EngineValue.cp(1400));
      expect(j.isMistake, isFalse);
      expect(j.lostChances, closeTo(0.48, 0.01));
    });

    test('a loss of 10 is a mistake, a loss just under it is not', () {
      // From +1.00 (59.10): -0.09 loses 9.93, -0.10 loses 10.02.
      expect(judge(EngineValue.cp(100), EngineValue.cp(-9)).isMistake, isFalse);
      expect(judge(EngineValue.cp(100), EngineValue.cp(-10)).isMistake, isTrue);
    });

    test('a slower mate is not a mistake', () {
      final j = judge(const EngineValue.mate(2), const EngineValue.mate(4));
      expect(j.isMistake, isFalse);
      expect(j.lostChances, 0);
    });

    test('a forced mate in five left is a mistake whatever the chances', () {
      // A mate in 5 left for +8: a loss of about 5 chances, under any A.
      final j = judge(const EngineValue.mate(5), EngineValue.cp(800));
      expect(j.lostChances, lessThan(10));
      expect(j.isMistake, isTrue);
      expect(j.reason, MistakeReason.missedMate);
    });

    test('a mate in six left for a winning move is not', () {
      expect(judge(const EngineValue.mate(6), EngineValue.cp(800)).isMistake,
          isFalse);
    });

    test('theory is judged only for a gross loss', () {
      // A loss of 15: a mistake out of the book, not in it.
      final best = EngineValue.cp(100);
      final played = EngineValue.cp(-65);
      expect(judge(best, played).isMistake, isTrue);
      expect(judge(best, played, bookGames: 10).isMistake, isFalse);
      // A loss of 20 or more is a mistake even in the book: 20.15 is, 19.80
      // is not — on the boundary, so a looser A_gross cannot pass.
      final gross = EngineValue.cp(-122);
      expect(judge(best, gross, bookGames: 10).isMistake, isTrue);
      expect(
          judge(best, gross, bookGames: 10).reason, MistakeReason.grossInBook);
      expect(
          judge(best, EngineValue.cp(-118), bookGames: 10).isMistake, isFalse);
    });

    test('a move the book lists nine times is not theory', () {
      final best = EngineValue.cp(100);
      final played = EngineValue.cp(-65);
      expect(judge(best, played, bookGames: 9).isMistake, isTrue);
    });

    test('a move better than the engine\'s best loses nothing', () {
      // The played move searched alone can come back a hair above the best
      // line of a separate search; that is not a negative loss.
      expect(judge(EngineValue.cp(30), EngineValue.cp(45)).lostChances, 0);
    });
  });

  group('the app\'s own spelling, from the side to move', () {
    // `AnalysisLine.evaluation` is always from White's side.
    EngineValue read(String e, {required bool whiteToMove}) =>
        EngineValue.fromEvaluation(e, whiteToMove: whiteToMove);

    test('centipawns turn round for Black', () {
      expect(read('+1.50', whiteToMove: true).cp, 150);
      expect(read('+1.50', whiteToMove: false).cp, -150);
      expect(read('-0.35', whiteToMove: false).cp, 35);
      expect(read('0.00', whiteToMove: true).cp, 0);
    });

    test('a mate turns round for Black, and keeps its distance', () {
      expect(read('M3', whiteToMove: true).mate, 3);
      expect(read('M3', whiteToMove: false).mate, -3);
      expect(read('-M2', whiteToMove: false).mate, 2);
      expect(read('-M2', whiteToMove: true).mate, -2);
    });

    test('something that is not an evaluation is refused, not read as 0', () {
      expect(() => read('', whiteToMove: true), throwsFormatException);
      expect(() => read('mate', whiteToMove: true), throwsFormatException);
    });
  });

  group('the loss in centipawns, for the drill', () {
    int loss(EngineValue best, EngineValue played) =>
        lossInCentipawns(best: best, played: played);

    test('the difference, never below zero', () {
      expect(loss(EngineValue.cp(120), EngineValue.cp(-80)), 200);
      expect(loss(EngineValue.cp(30), EngineValue.cp(45)), 0);
    });

    test('a value is capped at a thousand either way, a mate included', () {
      // As Lichess counts average loss: a mate is a thousand, not infinity.
      expect(loss(const EngineValue.mate(3), EngineValue.cp(800)), 200);
      expect(loss(EngineValue.cp(1500), EngineValue.cp(900)), 100);
      expect(loss(EngineValue.cp(200), const EngineValue.mate(-2)), 1200);
    });
  });

  test('a decided position is one side at 97 or more', () {
    expect(isDecided(97), isTrue);
    expect(isDecided(96.9), isFalse);
    expect(isDecided(3), isTrue);
    expect(isDecided(3.1), isFalse);
  });

  // docs/PLAN-ZAGONETKE-IZ-PARTIJE.md, phase 1.2a: the review's second look.
  group('the second look', () {
    MoveJudgement j(double lost, {MistakeReason? reason}) =>
        MoveJudgement(lost, reason);

    test('a candidate is within five of its threshold, or a missed mate', () {
      expect(isCandidate(j(5)), isTrue);
      expect(isCandidate(j(4.9)), isFalse);
      expect(isCandidate(j(0.5, reason: MistakeReason.missedMate)), isTrue);
    });

    test('in the book the threshold is twenty, so the margin starts at 15', () {
      expect(isCandidate(j(14.9), bookGames: 10), isFalse);
      expect(isCandidate(j(15), bookGames: 10), isTrue);
      // Nine games are not theory: the ordinary threshold applies.
      expect(isCandidate(j(5), bookGames: 9), isTrue);
    });

    test('two depths agree within five, on the same side of the line', () {
      final mistake = MistakeReason.lostChances;
      expect(judgementsAgree(j(13, reason: mistake), j(12, reason: mistake)),
          isTrue);
      expect(judgementsAgree(j(7), j(12, reason: mistake)), isFalse);
      // Far apart, both mistakes: the large losses move most.
      expect(judgementsAgree(j(40, reason: mistake), j(30, reason: mistake)),
          isFalse);
      expect(judgementsAgree(j(40, reason: mistake), j(35, reason: mistake)),
          isTrue);
      expect(judgementsAgree(j(1), j(6.1)), isFalse);
    });

    test('the tablebase: a worse result is a mistake, a slower win is not', () {
      MoveJudgement tb(TablebaseOutcome position, TablebaseOutcome played) =>
          judgeByTablebase(position: position, played: played, lostChances: 1);
      expect(tb(TablebaseOutcome.win, TablebaseOutcome.draw).reason,
          MistakeReason.worseResult);
      expect(
          tb(TablebaseOutcome.draw, TablebaseOutcome.loss).isMistake, isTrue);
      expect(tb(TablebaseOutcome.win, TablebaseOutcome.win).isMistake, isFalse);
      expect(
          tb(TablebaseOutcome.loss, TablebaseOutcome.loss).isMistake, isFalse);
      // The engine's number decides nothing here.
      expect(
          judgeByTablebase(
                  position: TablebaseOutcome.win,
                  played: TablebaseOutcome.win,
                  lostChances: 60)
              .isMistake,
          isFalse);
    });
  });
}
