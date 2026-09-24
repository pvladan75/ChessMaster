// What the review asks the engine for puzzles — docs/PLAN-ZAGONETKE-IZ-PARTIJE.md,
// phase 1.3.
//
// The walk asks one line a position; a mistake's confirming look asks two.
// That is enough for the `??` marks and for most mistake puzzles, but not for
// two things 1.3 adds: **the only moves a player found** (the player played the
// walk's best move, so no look ever asked for a second line there), and **a
// mate with a second mate beside it**, where `B` is measured against the best
// move that does not mate and so needs a third line. Both are searches only a
// review that keeps puzzles pays for, only for the side chosen, and only where
// they can end in a puzzle: never in the book, a decided position, a trivial
// find, or a position the tablebase judges. What the walk thought the best
// move was is kept beside the deciding look's, so „the same best move at both
// depths" can be asked afterwards.
//
// The engine here answers by position; every search is recorded as
// „p<position> d<depth> pv<lines>" (and „ only" for `searchmoves`), which is
// what these cases assert on — the question, not only the answer (rule 7).

import 'dart:math' as math;

import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/game_analysis_walker_service.dart';
import 'package:chess_app/core/services/game_review_judge.dart';
import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/masters_walk.dart';
import 'package:chess_app/models/analysis_models.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// 1.e4 e5 2.Nf3 Nc6 3.Bc4 Nf6: no capture, no check, many legal moves.
const _italian = ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'g8f6'];

/// Kb6 and Rh1 against Ka8, three men: Rh8 mates at once, Rh7 in two.
const _rookFen = 'k7/8/1K6/8/8/8/8/7R w - - 0 1';
const _rookMoves = ['h1h2', 'a8b8', 'h2h8'];

const _d = 20;

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
  }

  final String start;
  final List<String> ucis;
  final List<String> fens = [];

  List<String> legal(int i) => [
        for (final m in legalMoves(chess.Chess.fromFEN(fens[i])))
          '${m['from']}${m['to']}${m['promotion'] ?? ''}'
      ];
}

/// An engine that answers position i of [game]. Its best move is, unless a
/// case says otherwise, **the move the game played there** — the player found
/// the engine's move every time — at [value] (White's view, default level).
/// [bestWide] is the best move a search of two lines or more names instead,
/// so a case can make the walk and the confirming look disagree. The second
/// and third lines are (move, evaluation) pairs, defaulting to another legal
/// move at the same value.
class _Engine {
  _Engine(this.game);

  final _Game game;
  final Map<int, String> value = {};
  final Map<int, String> best = {};
  final Map<int, String> bestWide = {};
  final Map<int, (String, String)> second = {};
  final Map<int, (String, String)> third = {};
  final List<String> asked = [];

  Future<List<AnalysisLine>> call(
    String fen, {
    required int depth,
    required int multiPV,
    List<String>? searchMoves,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final i = game.fens.indexOf(fen);
    if (i < 0) throw StateError('asked about a position not in the game');
    asked.add('p$i d$depth pv$multiPV${searchMoves == null ? '' : ' only'}');
    AnalysisLine line(int pv, String evaluation, String uci) =>
        AnalysisLine.fromPv(
            multipv: pv,
            depth: depth,
            eval: evaluation,
            pvString: uci,
            startingFen: fen);

    final v = value[i] ?? '0.00';
    if (searchMoves != null) {
      return [line(1, value[i + 1] ?? '0.00', searchMoves.first)];
    }
    final legal = game.legal(i);
    final b = (multiPV >= 2 ? bestWide[i] : null) ??
        best[i] ??
        (i < game.ucis.length ? game.ucis[i] : legal.first);
    // A position with fewer legal moves has fewer lines, as a real engine
    // says — computed only when asked, since position 1 of the rook ending
    // has one legal move and the walk asks it for one line.
    (String, String)? other(Set<String> taken) {
      for (final m in legal) {
        if (!taken.contains(m)) return (m, v);
      }
      return null;
    }

    final s = multiPV >= 2 ? second[i] ?? other({b}) : null;
    final t = multiPV >= 3 && s != null ? third[i] ?? other({b, s.$1}) : null;
    return [
      line(1, v, b),
      if (s != null) line(2, s.$2, s.$1),
      if (t != null) line(3, t.$2, t.$1),
    ];
  }

  List<String> askedAt(int i) => [
        for (final a in asked)
          if (a.startsWith('p$i ')) a
      ];
}

Future<MastersWalk> _noBook(List<String> fens) async =>
    (known: const <String, Map<String, dynamic>>{}, unavailable: null);

BookLookup _book(_Game game, Map<int, Map<String, int>> games) =>
    (fens) async => (
          known: <String, Map<String, dynamic>>{
            for (final e in games.entries)
              game.fens[e.key]: {
                'moves': [
                  for (final m in e.value.entries)
                    {'san': m.key, 'white': m.value, 'draws': 0, 'black': 0}
                ]
              }
          },
          unavailable: null,
        );

Future<GameReviewResult> _review(
  _Engine engine, {
  BlunderAlertSide? puzzles,
  BookLookup? book,
  TablebaseLookup? tablebase,
  List<ReviewProgress>? progress,
}) async {
  final judge = GameReviewJudge(
    analyzer: engine.call,
    book: book ?? _noBook,
    tablebase: tablebase ?? (_) async => null,
  );
  final result = await judge.review(
    startingFen: engine.game.start,
    uciMoves: engine.game.ucis,
    depth: _d,
    puzzles: puzzles,
    onProgress: progress?.add,
  );
  return result!;
}

void main() {
  late _Game italian;
  setUp(() => italian = _Game(_start, _italian));

  group('the only moves a player found', () {
    test('a review that keeps no puzzles asks nothing more than the walk',
        () async {
      final engine = _Engine(italian);
      final progress = <ReviewProgress>[];
      await _review(engine, progress: progress);

      expect(engine.asked, [for (var i = 0; i <= 6; i++) 'p$i d$_d pv1']);
      expect(progress.where((p) => p.stage == ReviewStage.answers), isEmpty);
    });

    test(
        'with puzzles, every move the player found in a live position gets '
        'one search of two lines at the review\'s depth', () async {
      final engine = _Engine(italian);
      final progress = <ReviewProgress>[];
      await _review(engine, puzzles: BlunderAlertSide.both, progress: progress);

      for (var i = 0; i < 6; i++) {
        expect(engine.askedAt(i), ['p$i d$_d pv1', 'p$i d$_d pv2'],
            reason: 'position $i');
      }
      expect(engine.askedAt(6), ['p6 d$_d pv1'],
          reason: 'the last position has no move of the game to find');
      expect(progress.where((p) => p.stage == ReviewStage.answers), isNotEmpty);
    });

    test('only for the side chosen', () async {
      final engine = _Engine(italian);
      await _review(engine, puzzles: BlunderAlertSide.white);

      expect([
        for (final a in engine.asked)
          if (a.endsWith('pv2')) a
      ], [
        'p0 d$_d pv2',
        'p2 d$_d pv2',
        'p4 d$_d pv2'
      ]);
    });

    test('a move that was not the walk\'s best gets none', () async {
      final engine = _Engine(italian)..best[2] = 'd2d4';
      await _review(engine, puzzles: BlunderAlertSide.both);

      expect(engine.askedAt(2), ['p2 d$_d pv1']);
    });

    test('a decided position gets none', () async {
      // From position 1 on, White has 98 chances: every position but the
      // first is decided, and no move loses anything.
      final engine = _Engine(italian);
      for (var i = 1; i <= 6; i++) {
        engine.value[i] = c(98);
      }
      final result = await _review(engine, puzzles: BlunderAlertSide.both);

      expect(result.mistakes, 0);
      expect([
        for (final a in engine.asked)
          if (a.endsWith('pv2')) a
      ], [
        'p0 d$_d pv2'
      ]);
    });

    test('a move the masters play gets none; one they barely play does',
        () async {
      final engine = _Engine(italian);
      await _review(engine,
          puzzles: BlunderAlertSide.both,
          book: _book(italian, {
            0: {'e4': 1200},
            2: {'Nf3': 3},
          }));

      expect(engine.askedAt(0), ['p0 d$_d pv1']);
      expect(engine.askedAt(2), ['p2 d$_d pv1', 'p2 d$_d pv2']);
    });

    test('a move out of check gets none', () async {
      final g = _Game(_start, ['e2e4', 'd7d5', 'f1b5', 'b8c6']);
      final engine = _Engine(g);
      await _review(engine, puzzles: BlunderAlertSide.both);

      expect(engine.askedAt(3), ['p3 d$_d pv1']);
      expect(engine.askedAt(2), ['p2 d$_d pv1', 'p2 d$_d pv2']);
    });

    test('taking back on the square just landed on gets none', () async {
      final g = _Game(_start, ['e2e4', 'd7d5', 'e4d5', 'd8d5']);
      final engine = _Engine(g);
      await _review(engine, puzzles: BlunderAlertSide.both);

      expect(engine.askedAt(3), ['p3 d$_d pv1']);
    });

    test(
        'the search\'s two lines are the move\'s, and the walk\'s best move '
        'is kept', () async {
      final engine = _Engine(italian)..second[4] = ('d2d4', c(40));
      final result = await _review(engine, puzzles: BlunderAlertSide.both);
      final move = result.moves[4];

      expect(move.bestLine!.bestMoveLan, 'f1c4');
      expect(move.secondLine!.bestMoveLan, 'd2d4');
      expect(move.walkBestUci, 'f1c4');
    });
  });

  group('a mistake', () {
    test(
        'the walk\'s best move is kept, even where the deciding look names '
        'another', () async {
      // 3.Bc4 loses 20: the walk prefers d4, the confirming look Nc3.
      final engine = _Engine(italian)
        ..value[4] = c(70)
        ..value[5] = c(50)
        ..best[4] = 'd2d4'
        ..bestWide[4] = 'b1c3'
        ..second[4] = ('a2a3', c(60));
      final result = await _review(engine);
      final move = result.moves[4];

      expect(move.isMistake, isTrue);
      expect(move.walkBestUci, 'd2d4');
      expect(move.bestLine!.bestMoveLan, 'b1c3');
    });

    test(
        'a mate left with a second mate beside it gets one search of three '
        'lines, at the depth of the look that decided it', () async {
      // 1.Rh2 leaves Rh8 mate (and Rh7, mate in two) for a position the
      // engine calls +5. The tablebase does not answer.
      final g = _Game(_rookFen, _rookMoves);
      final engine = _Engine(g)
        ..value[0] = 'M1'
        ..best[0] = 'h1h8'
        ..value[1] = '+5.00'
        ..second[0] = ('h1h7', 'M2')
        ..third[0] = ('b6c6', c(80));
      final result = await _review(engine, puzzles: BlunderAlertSide.both);
      final move = result.moves[0];

      expect(move.isMistake, isTrue);
      expect(
          engine.askedAt(0).where((a) => a.endsWith('pv3')), ['p0 d$_d pv3']);
      expect(move.secondLine!.bestMoveLan, 'h1h7');
      expect(move.thirdLine!.bestMoveLan, 'b6c6');
    });

    test('without puzzles, no third line is asked', () async {
      final g = _Game(_rookFen, _rookMoves);
      final engine = _Engine(g)
        ..value[0] = 'M1'
        ..best[0] = 'h1h8'
        ..value[1] = '+5.00'
        ..second[0] = ('h1h7', 'M2');
      await _review(engine);

      expect(engine.asked.where((a) => a.endsWith('pv3')), isEmpty);
    });
  });

  group('the tablebase', () {
    test(
        'the moves that keep the result are recorded, and a position it '
        'judges gets no search for puzzles', () async {
      final g = _Game(_rookFen, _rookMoves);
      final engine = _Engine(g);
      SyzygyMove move(String uci, SyzygyCategory category) => SyzygyMove(
          uci: uci,
          san: uci,
          category: category,
          zeroing: false,
          checkmate: false,
          stalemate: false);
      final answer = SyzygyResult(
        fen: g.fens[0],
        category: SyzygyCategory.win,
        checkmate: false,
        stalemate: false,
        insufficientMaterial: false,
        moves: [
          move('h1h8', SyzygyCategory.loss),
          move('h1h2', SyzygyCategory.loss),
          move('b6c6', SyzygyCategory.draw),
        ],
      );
      final result = await _review(engine,
          puzzles: BlunderAlertSide.both,
          tablebase: (fen) async => fen == g.fens[0] ? answer : null);
      final first = result.moves[0];

      expect(first.byTablebase, isTrue);
      expect(first.tablebaseKeepers, ['h1h8', 'h1h2']);
      expect(engine.askedAt(0), ['p0 d$_d pv1']);
      expect(result.moves[2].tablebaseKeepers, isNull,
          reason: 'the tablebase did not answer there');
    });
  });
}
