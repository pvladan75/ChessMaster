// The puzzles a review keeps — docs/PLAN-ZAGONETKE-IZ-PARTIJE.md, phase 1.3.
//
// Until 1.3 a puzzle was the position *after* a mistake, one answer, taken
// from every mistake the review marked, worst first. The owner's request of
// 23.9.2026 was the opposite: the position *before* the mistake, and only
// where one move stands out — „+19 against +14 is no difference at all". So a
// puzzle now needs both criteria of §3: the player erred (the review's own
// judgement, 1.2a), and one move is at least `B` = 15 chances better than the
// second, with the same best move at the walk's depth and at the deciding
// one. A mate is answered by every mating first move; nothing trivial is
// taught as a find; a chance missed again within four plies is one puzzle;
// the only moves a player found are puzzles of their own; the lines the
// reveal will show are cut where the point is made, at most twelve plies.
//
// Every case here builds the review's result by hand — no engine — so each
// says exactly what the review found. Positions are real and every line is
// legal in them; the chances are for the side that moved.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/answer_line.dart';
import 'package:chess_app/core/services/game_analysis_walker_service.dart';
import 'package:chess_app/core/services/game_review_judge.dart';
import 'package:chess_app/core/services/legal_moves.dart' show walkGame;
import 'package:chess_app/core/services/local_puzzle_extractor_service.dart';
import 'package:chess_app/core/services/mistake_rule.dart';
import 'package:chess_app/models/analysis_models.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// 1.e4 e5 2.Nf3 Nc6 3.Bc4 Nf6 4.O-O Bc5 5.d3 d6 — White at even plies,
/// Black at odd ones. No capture, no check, twenty legal moves or more.
const _italian = [
  'e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', //
  'g8f6', 'e1g1', 'f8c5', 'd2d3', 'd7d6',
];

/// 1.e4 d5 2.exd5 Nf6 3.Nc3: at ply 3 Qxd5 would take back on d5, the
/// square 2.exd5 landed on.
const _scandinavian = ['e2e4', 'd7d5', 'e4d5', 'g8f6', 'b1c3'];

/// 1.e4 d5 2.Bb5+ Nc6: at ply 3 Black is in check, with five legal moves.
const _check = ['e2e4', 'd7d5', 'f1b5', 'b8c6'];

/// Black to move with three legal moves (Kg8, b6, b5), not in check.
const _fewFen = '7k/1p6/6K1/8/8/8/8/R7 b - - 0 1';

/// Kb6 and Rh1 against Ka8: Rh8 mates at once, Rh7 in two.
const _rookFen = 'k7/8/1K6/8/8/8/8/7R w - - 0 1';

/// White to move, a rook down after the exchange on a7 and the queen on d5
/// to win back — the tutorial's own fixture (`game_tutorial_answer_line_test`).
const _sacFen = 'r5k1/p7/8/3q4/8/8/8/R2Q2K1 w - - 0 1';

/// Sixteen legal plies from [_sacFen] in which White stays a rook down: a line
/// that never pays, so only the cap stops it.
const _sacLine = 'a1a7 a8a7 d1h5 a7a8 h5h6 a8a1 g1f2 a1a2 '
    'f2g3 a2a3 g3g4 a3a4 g4h3 a4a3 h3h2 a3a2';

/// From the position after 1.Qd2 in [_sacFen], Black to move: the queen is
/// given on g2 and Black stays behind to the end — six plies. Cut with Black
/// as the mover it runs to six; cut with White as the mover it stops at four.
const _punishLine = 'd5g2 g1g2 a8b8 a1a7 b8b1 a7a8';

/// The evaluation, from White's side as the app spells it, that gives White
/// [w] winning chances.
String c(double w) {
  final cp = (-math.log(100 / w - 1) / 0.00368208).round();
  final pawns = cp / 100;
  return pawns >= 0 ? '+${pawns.toStringAsFixed(2)}' : pawns.toStringAsFixed(2);
}

class _Game {
  _Game(this.start, this.ucis) {
    final walked = walkGame(startingFen: start, uciMoves: ucis);
    if (walked.appliedUci.length != ucis.length) {
      throw StateError('not a legal game: $ucis from $start');
    }
    fens.addAll(walked.fens);
    sans.addAll(walked.sans);
  }

  final String start;
  final List<String> ucis;
  final List<String> fens = [];
  final List<String> sans = [];

  bool whiteMoved(int i) => fens[i].split(' ')[1] == 'w';
}

/// Move [i] of [g] as the review left it. [bestW], [secondW] and [thirdW] are
/// the mover's chances; [bestEval] and friends, when given, are the raw
/// evaluation from White's side instead (a mate). [walkBest] defaults to the
/// best line's first move — the walk and the deciding look agreed.
ReviewedMove _m(
  _Game g,
  int i, {
  double lost = 0,
  MistakeReason? reason,
  bool judged = true,
  bool unsettled = false,
  String? best,
  double bestW = 60,
  String? bestEval,
  String? second,
  double? secondW,
  String? secondEval,
  String? third,
  double? thirdW,
  String? thirdEval,
  String? walkBest,
  String? reply,
  int? bookGames,
  bool byTablebase = false,
  List<String>? keepers,
}) {
  final white = g.whiteMoved(i);
  String ev(double w) => c(white ? w : 100 - w);
  AnalysisLine? line(int pv, String? uci, String? raw, double? w) => uci == null
      ? null
      : AnalysisLine.fromPv(
          multipv: pv,
          depth: 20,
          eval: raw ?? ev(w ?? 50),
          pvString: uci,
          startingFen: g.fens[i]);
  final bestLine = line(1, best, bestEval, bestW);
  return ReviewedMove(
    ply: i,
    san: g.sans[i],
    uci: g.ucis[i],
    fenBefore: g.fens[i],
    fenAfter: g.fens[i + 1],
    whiteMoved: white,
    judgement: judged ? MoveJudgement(lost, reason) : null,
    unjudgedWhy: judged ? null : 'the position after it was never answered',
    unsettled: unsettled,
    depth: judged ? 20 : null,
    bestLine: bestLine,
    secondLine: line(2, second, secondEval, secondW),
    thirdLine: line(3, third, thirdEval, thirdW),
    replyLine: reply == null
        ? null
        : AnalysisLine.fromPv(
            multipv: 1,
            depth: 20,
            eval: '0.00',
            pvString: reply,
            startingFen: g.fens[i + 1]),
    walkBestUci: walkBest ?? bestLine?.bestMoveLan,
    bookGames: bookGames,
    byTablebase: byTablebase,
    tablebaseKeepers: keepers,
  );
}

/// Every move of [g] unremarkable — judged, no loss, no second line, the
/// engine preferring a move the player did not play — except those in
/// [special].
GameReviewResult _result(_Game g, Map<int, ReviewedMove> special) =>
    GameReviewResult(reviewDepth: 20, moves: [
      for (var i = 0; i < g.ucis.length; i++)
        special[i] ??
            _m(g, i, best: g.whiteMoved(i) ? 'h2h3' : 'h7h6', walkBest: 'x'),
    ]);

/// A mistake at [i] of the Italian game: the best move a rook's pawn, a
/// clear 16 over the second, [lost] chances lost.
ReviewedMove _mistake(_Game g, int i, {double lost = 20, double gap = 16}) =>
    _m(g, i,
        lost: lost,
        reason: MistakeReason.lostChances,
        best: g.whiteMoved(i) ? 'a2a3' : 'a7a6',
        bestW: 70,
        second: g.whiteMoved(i) ? 'h2h3' : 'h7h6',
        secondW: 70 - gap);

ReviewPuzzles _build(GameReviewResult r,
        {int maxPuzzles = 10, BlunderAlertSide side = BlunderAlertSide.both}) =>
    LocalPuzzleExtractorService()
        .buildPuzzlesFromReview(r, maxPuzzles: maxPuzzles, side: side);

List<int> _plies(List<LocalPuzzle> ps) =>
    [for (final p in ps) p.sourcePlyIndex];

void main() {
  late _Game italian;
  setUp(() => italian = _Game(_start, _italian));

  group('a mistake becomes a puzzle', () {
    test('the position before the mistake, the best move its answer', () {
      final r = _result(italian, {
        4: _m(italian, 4,
            lost: 20,
            reason: MistakeReason.lostChances,
            best: 'd2d4 d7d6',
            bestW: 70,
            second: 'b1c3',
            secondW: 54,
            reply: 'g8f6 d2d3'),
      });
      final puzzles = _build(r);

      expect(_plies(puzzles.mistakes), [4]);
      expect(puzzles.onlyMoves, isEmpty);
      final p = puzzles.mistakes.single;
      expect(p.kind, PuzzleKind.mistake);
      expect(p.fen, italian.fens[4], reason: 'the position before 3.Bc4');
      expect(p.playedSan, 'Bc4');
      expect(p.playedUci, 'f1c4');
      expect(p.answers, ['d4']);
      expect(p.bestLine, ['d4', 'd6']);
      expect(p.secondLine, ['Nc3']);
      expect(p.refutationLine, ['Nf6', 'd3']);
      expect(p.instruction, kMistakeInstruction);
      expect(p.instruction, isNot(contains('Bc4')),
          reason: 'the game\'s move is not named before the student moves');
      expect(p.bestChances, closeTo(70, 0.1));
      expect(p.playedChances, closeTo(50, 0.1));
      expect(p.secondChances, closeTo(54, 0.1));
      expect(p.trivial, isFalse);
      expect(p.missedTimes, 1);
    });

    test('B: 15 over the second is a puzzle, under 15 is not', () {
      ReviewPuzzles gap(double second) => _build(_result(italian, {
            4: _m(italian, 4,
                lost: 20,
                reason: MistakeReason.lostChances,
                best: 'd2d4',
                bestW: 70,
                second: 'b1c3',
                secondW: second),
          }));

      expect(_plies(gap(54.5).mistakes), [4]);
      expect(gap(55.5).mistakes, isEmpty);
    });

    test('+19 against +14 is no mistake, so no puzzle, whatever the gap', () {
      final r = _result(italian, {
        4: _m(italian, 4,
            lost: 0.5,
            best: 'd2d4',
            bestEval: '+19.00',
            second: 'b1c3',
            secondW: 50),
      });

      expect(_build(r).mistakes, isEmpty);
    });

    test('a move the looks still disagreed on is no puzzle', () {
      final r = _result(italian, {
        4: _m(italian, 4,
            lost: 20,
            reason: MistakeReason.lostChances,
            unsettled: true,
            best: 'd2d4',
            bestW: 70,
            second: 'b1c3',
            secondW: 40),
      });

      expect(_build(r).mistakes, isEmpty);
    });

    test(
        'a best move that changed between the walk and the deciding look is '
        'no puzzle, whatever its gap', () {
      final r = _result(italian, {
        4: _m(italian, 4,
            lost: 30,
            reason: MistakeReason.lostChances,
            best: 'd2d4',
            bestW: 80,
            second: 'b1c3',
            secondW: 30,
            walkBest: 'b1c3'),
      });

      expect(_build(r).mistakes, isEmpty);
    });

    test('without a second line nothing stands out: no puzzle', () {
      final r = _result(italian, {
        4: _m(italian, 4,
            lost: 30,
            reason: MistakeReason.lostChances,
            best: 'd2d4',
            bestW: 80),
      });

      expect(_build(r).mistakes, isEmpty);
    });

    test('only the side chosen', () {
      final r = _result(italian, {
        1: _mistake(italian, 1, lost: 25),
        4: _mistake(italian, 4),
      });

      expect(_plies(_build(r).mistakes), [1, 4]);
      expect(_plies(_build(r, side: BlunderAlertSide.white).mistakes), [4]);
      expect(_plies(_build(r, side: BlunderAlertSide.black).mistakes), [1]);
    });
  });

  group('a mate', () {
    late _Game rook;
    setUp(() => rook = _Game(_rookFen, ['h1h2', 'a8b8', 'h2h8']));

    ReviewedMove missed(
            {required String third, String? thirdEval, double? thirdW}) =>
        _m(rook, 0,
            lost: 5,
            reason: MistakeReason.missedMate,
            best: 'h1h8',
            bestEval: 'M1',
            second: 'h1h7',
            secondEval: 'M2',
            third: third,
            thirdEval: thirdEval,
            thirdW: thirdW,
            walkBest: 'h1h7');

    test(
        'every first move that forces the mate is an answer, and B is '
        'measured against the best move that does not mate', () {
      final r = _result(rook, {0: missed(third: 'b6c6', thirdW: 80)});
      final p = _build(r).mistakes.single;

      expect(p.answers, ['Rh8#', 'Rh7']);
      expect(p.secondLine.first, 'Kc6');
      expect(p.secondChances, closeTo(80, 0.1));
      expect(p.bestChances, 100);
    });

    test('three mating lines leave nothing to measure against: no puzzle', () {
      final r = _result(rook, {0: missed(third: 'h1g1', thirdEval: 'M3')});

      expect(_build(r).mistakes, isEmpty);
    });

    test('the best move that does not mate within 15 of the mate: no puzzle',
        () {
      final r = _result(rook, {0: missed(third: 'b6c6', thirdW: 90)});

      expect(_build(r).mistakes, isEmpty);
    });
  });

  group('nothing trivial is taught as a find', () {
    test('taking back on the square the last move landed on is trivial', () {
      final g = _Game(_start, _scandinavian);
      final r = _result(g, {
        3: _m(g, 3,
            lost: 30,
            reason: MistakeReason.lostChances,
            best: 'd8d5',
            bestW: 70,
            second: 'c7c6',
            secondW: 40),
      });

      expect(_build(r).mistakes.single.trivial, isTrue);
    });

    test('a move out of check is trivial', () {
      final g = _Game(_start, _check);
      final r = _result(g, {
        3: _m(g, 3,
            lost: 30,
            reason: MistakeReason.lostChances,
            best: 'c7c6',
            bestW: 70,
            second: 'c8d7',
            secondW: 40),
      });

      expect(_build(r).mistakes.single.trivial, isTrue);
    });

    test('three legal moves or fewer is trivial', () {
      final g = _Game(_fewFen, ['h8g8']);
      final r = _result(g, {
        0: _m(g, 0,
            lost: 30,
            reason: MistakeReason.lostChances,
            best: 'b7b5',
            bestW: 70,
            second: 'b7b6',
            secondW: 40),
      });

      expect(_build(r).mistakes.single.trivial, isTrue);
    });

    test('a trivial mistake is ranked last, so Max puzzles drops it first', () {
      final g = _Game(_start, _scandinavian);
      final r = _result(g, {
        3: _m(g, 3,
            lost: 30,
            reason: MistakeReason.lostChances,
            best: 'd8d5',
            bestW: 70,
            second: 'c7c6',
            secondW: 40),
        4: _m(g, 4,
            lost: 20,
            reason: MistakeReason.lostChances,
            best: 'a2a3',
            bestW: 70,
            second: 'h2h3',
            secondW: 50),
      });

      expect(_plies(_build(r).mistakes), [4, 3]);
      expect(_plies(_build(r, maxPuzzles: 1).mistakes), [4]);
    });
  });

  group('a chance missed again is one puzzle', () {
    test('one player, two plies apart: one puzzle, the first', () {
      final r = _result(italian, {
        0: _mistake(italian, 0, lost: 15),
        2: _mistake(italian, 2, lost: 40),
      });
      final ps = _build(r).mistakes;

      expect(_plies(ps), [0]);
      expect(ps.single.missedTimes, 2);
    });

    test('each within four plies of the last: one puzzle, missed three times',
        () {
      final r = _result(italian, {
        0: _mistake(italian, 0),
        4: _mistake(italian, 4),
        8: _mistake(italian, 8),
      });
      final ps = _build(r).mistakes;

      expect(_plies(ps), [0]);
      expect(ps.single.missedTimes, 3);
    });

    test('six plies apart are two chances', () {
      final r = _result(italian, {
        0: _mistake(italian, 0),
        6: _mistake(italian, 6),
      });
      final ps = _build(r).mistakes;

      expect(_plies(ps)..sort(), [0, 6]);
      expect([for (final p in ps) p.missedTimes], [1, 1]);
    });

    test('two players one ply apart are two chances', () {
      final r = _result(italian, {
        2: _mistake(italian, 2),
        3: _mistake(italian, 3),
      });

      expect(_plies(_build(r).mistakes)..sort(), [2, 3]);
    });

    test('a mistake that is no puzzle does not swallow the next one', () {
      final r = _result(italian, {
        0: _mistake(italian, 0, gap: 5),
        2: _mistake(italian, 2),
      });
      final ps = _build(r).mistakes;

      expect(_plies(ps), [2]);
      expect(ps.single.missedTimes, 1);
    });
  });

  test('worst first by chances lost, at most Max puzzles', () {
    final r = _result(italian, {
      0: _mistake(italian, 0, lost: 12),
      5: _mistake(italian, 5, lost: 30),
      8: _mistake(italian, 8, lost: 20),
    });

    expect(_plies(_build(r).mistakes), [5, 8, 0]);
    expect(_plies(_build(r, maxPuzzles: 2).mistakes), [5, 8]);
  });

  group('the only moves a player found', () {
    ReviewedMove found(_Game g, int i,
            {double bestW = 60,
            double gap = 16,
            int? bookGames,
            String? second}) =>
        _m(g, i,
            best: g.ucis[i],
            bestW: bestW,
            second: second ?? (g.whiteMoved(i) ? 'a2a3' : 'a7a6'),
            secondW: bestW - gap,
            bookGames: bookGames);

    test('found, one move 15 clear: an only-move puzzle of its own', () {
      final r = _result(italian, {4: found(italian, 4)});
      final puzzles = _build(r);

      expect(puzzles.mistakes, isEmpty);
      final p = puzzles.onlyMoves.single;
      expect(p.kind, PuzzleKind.onlyMove);
      expect(p.fen, italian.fens[4]);
      expect(p.answers, ['Bc4']);
      expect(p.playedSan, 'Bc4');
      expect(p.instruction, kOnlyMoveInstruction);
      expect(p.refutationLine, isEmpty);
      expect(p.secondLine, ['a3']);
    });

    test('under 15 clear it is not', () {
      expect(
          _build(_result(italian, {4: found(italian, 4, gap: 14.5)})).onlyMoves,
          isEmpty);
    });

    test('in a decided position it is not', () {
      expect(
          _build(_result(italian, {4: found(italian, 4, bestW: 98, gap: 20)}))
              .onlyMoves,
          isEmpty);
    });

    test('a move the masters play is not', () {
      expect(
          _build(_result(
                  italian, {4: found(italian, 4, bookGames: kTheoryGames)}))
              .onlyMoves,
          isEmpty);
    });

    test('a trivial one never is — here, out of check', () {
      final g = _Game(_start, _check);
      expect(_build(_result(g, {3: found(g, 3, second: 'c7c6')})).onlyMoves,
          isEmpty);
    });

    test('the walk named another move: not an only move', () {
      final r = _result(italian, {
        4: _m(italian, 4,
            best: 'f1c4',
            bestW: 60,
            second: 'a2a3',
            secondW: 40,
            walkBest: 'd2d4'),
      });

      expect(_build(r).onlyMoves, isEmpty);
    });

    test('only the side chosen', () {
      final r = _result(italian, {4: found(italian, 4), 5: found(italian, 5)});

      expect(_plies(_build(r, side: BlunderAlertSide.black).onlyMoves), [5]);
    });

    test('capped by Max puzzles on their own, the clearest first', () {
      final r = _result(italian, {
        0: found(italian, 0, gap: 16),
        2: _mistake(italian, 2),
        4: found(italian, 4, gap: 30),
        8: found(italian, 8, gap: 20),
      });
      final puzzles = _build(r, maxPuzzles: 2);

      expect(_plies(puzzles.onlyMoves), [4, 8]);
      expect(_plies(puzzles.mistakes), [2]);
      expect(_plies(puzzles.all), [2, 4, 8],
          reason: 'the mistakes first, then the only moves');
    });
  });

  group('with seven men or fewer, the tablebase', () {
    late _Game rook;
    setUp(() => rook = _Game(_rookFen, ['h1h2', 'a8b8', 'h2h8']));

    test(
        'one move keeps the result, and the engine\'s best is that move: a '
        'puzzle, answered by it', () {
      final r = _result(rook, {
        0: _m(rook, 0,
            lost: 30,
            reason: MistakeReason.worseResult,
            byTablebase: true,
            keepers: const ['h1h8'],
            best: 'h1h8',
            bestEval: 'M1'),
      });
      final p = _build(r).mistakes.single;

      expect(p.answers, ['Rh8#']);
      expect(p.secondLine, isEmpty);
      expect(p.secondChances, isNull);
    });

    test('two moves keep it: no puzzle', () {
      final r = _result(rook, {
        0: _m(rook, 0,
            lost: 30,
            reason: MistakeReason.worseResult,
            byTablebase: true,
            keepers: const ['h1h8', 'h1h7'],
            best: 'h1h8',
            bestEval: 'M1'),
      });

      expect(_build(r).mistakes, isEmpty);
    });

    test('the one move that keeps it, found in a live position: an only move',
        () {
      final r = _result(rook, {
        0: _m(rook, 0,
            byTablebase: true,
            keepers: const ['h1h2'],
            best: 'h1h2',
            bestEval: '0.00'),
      });

      expect(_plies(_build(r).onlyMoves), [0]);
    });
  });

  group('the lines the reveal will show', () {
    test('a line run on while the mover is behind stops at twelve plies', () {
      final g = _Game(_sacFen, ['d1d2']);
      final m = _m(g, 0,
          lost: 25,
          reason: MistakeReason.lostChances,
          best: _sacLine,
          bestW: 70,
          second: 'a1b1',
          secondW: 50);
      final p = _build(_result(g, {0: m})).mistakes.single;

      expect(m.bestLine!.sanMoveList, hasLength(16),
          reason: 'the review keeps the whole line');
      expect(kRevealPlies, 12);
      expect(p.bestLine, hasLength(12));
      expect(p.bestLine.first, 'Rxa7');
    });

    test('a quiet line stops at four', () {
      final r = _result(italian, {
        4: _m(italian, 4,
            lost: 20,
            reason: MistakeReason.lostChances,
            best: 'd2d4 d7d6 c2c3 h7h6 a2a3 a7a6 h2h3 b7b6',
            bestW: 70,
            second: 'b1c3',
            secondW: 50,
            reply: 'g8f6 d2d3 f8c5 c2c3 d7d6 e1g1'),
      });
      final p = _build(r).mistakes.single;

      expect(p.bestLine, ['d4', 'd6', 'c3', 'h6']);
      expect(p.refutationLine, ['Nf6', 'd3', 'Bc5', 'c3']);
    });

    test('the refutation is cut with the side that punishes as the mover', () {
      final g = _Game(_sacFen, ['d1d2']);
      final r = _result(g, {
        0: _m(g, 0,
            lost: 25,
            reason: MistakeReason.lostChances,
            best: 'a1a7',
            bestW: 70,
            second: 'a1b1',
            secondW: 50,
            reply: _punishLine),
      });

      expect(_build(r).mistakes.single.refutationLine,
          ['Qg2+', 'Kxg2', 'Rb8', 'Rxa7', 'Rb1', 'Ra8+']);
    });

    test('a line that does not replay makes no puzzle, and is counted', () {
      final good = _mistake(italian, 4);
      final bad = ReviewedMove(
        ply: good.ply,
        san: good.san,
        uci: good.uci,
        fenBefore: good.fenBefore,
        fenAfter: good.fenAfter,
        whiteMoved: good.whiteMoved,
        judgement: good.judgement,
        depth: 20,
        bestLine: AnalysisLine(
          multipv: 1,
          depth: 20,
          evaluation: c(70),
          bestMoveLan: 'a2a3',
          bestMoveSan: 'a3',
          continuationLan: 'a2a3 h7h5',
          continuationSan: '3. a3 Qxh7',
          sanMoveList: const ['a3', 'Qxh7'],
          fenList: [good.fenBefore],
          fromSquare: 'a2',
          toSquare: 'a3',
        ),
        secondLine: good.secondLine,
        walkBestUci: 'a2a3',
      );
      final puzzles = _build(_result(italian, {4: bad}));

      expect(puzzles.mistakes, isEmpty);
      expect(puzzles.unplayable, 1);
    });
  });
}
