// The review's judgement — docs/PLAN-ZAGONETKE-IZ-PARTIJE.md, phase 1.2a.
//
// Until 1.2a „Review entire game" marked a move `??` when it lost two pawns,
// with a larger swing once the game was decided, from one walk at one depth,
// no book and no tablebase: +19 against +14 was five pawns and a „blunder", a
// mate in three left for a won position was nothing, and a position the
// engine did not answer read as a quiet one. Now every move is judged by the
// one mistake rule, the moves near a threshold are looked at again, and what
// could not be settled or judged is counted rather than hidden.
//
// The engine here answers by position and by depth, so each case says exactly
// what each look sees; the book and the tablebase are fakes of the shapes the
// real ones answer.

import 'dart:math' as math;

import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/eval_cache.dart';
import 'package:chess_app/core/services/game_analysis_walker_service.dart';
import 'package:chess_app/core/services/game_review_judge.dart';
import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess_app/core/services/mistake_rule.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/masters_walk.dart';
import 'package:chess_app/models/analysis_models.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// 1.e4 e5 2.Nf3 Nc6 3.Bc4 Nf6 — White moves at plies 0, 2 and 4, Black at
/// 1, 3 and 5. What the engine thinks of it is each case's to say.
const _italian = ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'g8f6'];

/// Kb6 and Rh1 against Ka8, White to move: three men. Rh2, Kb8, Rh8 mate.
const _rookEnding = 'k7/8/1K6/8/8/8/8/7R w - - 0 1';
const _rookMoves = ['h1h2', 'a8b8', 'h2h8'];

const _d = 20;

/// The evaluation, from White's side as the app spells it, that gives White
/// [w] winning chances — so a case can speak in chances.
String c(double w) {
  final cp = (-math.log(100 / w - 1) / 0.00368208).round();
  final pawns = cp / 100;
  return pawns >= 0 ? '+${pawns.toStringAsFixed(2)}' : pawns.toStringAsFixed(2);
}

typedef ByDepth = String Function(int depth);
ByDepth at(String evaluation) => (_) => evaluation;

class _Game {
  _Game(this.start, this.ucis) {
    fens.add(start);
    final game = chess.Chess.fromFEN(start);
    for (final u in ucis) {
      final ok = game.move({
        'from': u.substring(0, 2),
        'to': u.substring(2, 4),
        if (u.length > 4) 'promotion': u.substring(4),
      });
      if (!ok) throw StateError('not a legal move: $u');
      fens.add(game.fen);
    }
  }

  final String start;
  final List<String> ucis;
  final List<String> fens = [];

  /// The legal moves in position [i], the move the game played there left out.
  List<String> otherMoves(int i) => [
        for (final m in legalMoves(chess.Chess.fromFEN(fens[i])))
          '${m['from']}${m['to']}${m['promotion'] ?? ''}',
      ].where((u) => i >= ucis.length || u != ucis[i]).toList();
}

/// An engine that answers position [i] of [game]: its best line at [value],
/// its second at [second], the move played there searched alone at [alone]
/// (by default what the next position is worth — as a real engine would say).
/// Every value may depend on the depth reported.
class _Engine {
  _Engine(this.game);

  final _Game game;
  final Map<int, ByDepth> value = {};
  final Map<int, ByDepth> second = {};
  final Map<int, ByDepth> alone = {};
  final Map<int, String Function(int depth)> best = {};
  final Map<int, String> secondMove = {};

  /// The deepest depth position i is ever answered at — a search stopped by
  /// its timeout. 0: nothing at all.
  final Map<int, int> reaches = {};

  /// Position i answered at least this deep, whatever is asked — an answer a
  /// store kept from a deeper search.
  final Map<int, int> answersAt = {};

  /// An engine that ignores `searchmoves` and answers its own best move.
  bool ignoresSearchMoves = false;

  final List<String> asked = [];

  void walk(List<String> evaluations) {
    for (var i = 0; i < evaluations.length; i++) {
      value[i] = at(evaluations[i]);
    }
  }

  void chances(List<double> white) => walk([for (final w in white) c(w)]);

  Future<List<AnalysisLine>> call(
    String fen, {
    required int depth,
    required int multiPV,
    List<String>? searchMoves,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final i = game.fens.indexOf(fen);
    if (i < 0) throw StateError('asked about a position not in the game');
    asked.add(
      'p$i d$depth pv$multiPV'
      '${searchMoves == null ? '' : ' only ${searchMoves.join(',')}'}',
    );
    var reported = math.max(depth, answersAt[i] ?? 0);
    final cap = reaches[i];
    if (cap != null) {
      if (cap == 0) return const [];
      reported = math.min(reported, cap);
    }
    AnalysisLine line(int pv, String evaluation, String uci) =>
        AnalysisLine.fromPv(
          multipv: pv,
          depth: reported,
          eval: evaluation,
          pvString: uci,
          startingFen: fen,
        );

    if (searchMoves != null && !ignoresSearchMoves) {
      final e = (alone[i] ?? value[i + 1] ?? at('0.00'))(reported);
      return [line(1, e, searchMoves.first)];
    }
    // A position whose only legal move is the one played answers with it.
    final others = game.otherMoves(i);
    final bestUci = best[i]?.call(reported) ??
        (others.isEmpty ? game.ucis[i] : others.first);
    return [
      line(1, (value[i] ?? at('0.00'))(reported), bestUci),
      // A position with one legal move has one line, as a real engine says.
      if (multiPV >= 2 && others.any((m) => m != bestUci))
        line(
          2,
          (second[i] ?? value[i] ?? at('0.00'))(reported),
          secondMove[i] ?? others.firstWhere((m) => m != bestUci),
        ),
    ];
  }

  bool wasAsked(String prefix) => asked.any((a) => a.startsWith(prefix));
}

Future<MastersWalk> _noBook(List<String> fens) async =>
    (known: const <String, Map<String, dynamic>>{}, unavailable: null);

/// A book that knows position i with the moves and games given.
BookLookup _book(
  _Game game,
  Map<int, Map<String, int>> games, {
  List<int>? calls,
}) {
  return (fens) async {
    calls?.add(fens.length);
    return (
      known: <String, Map<String, dynamic>>{
        for (final e in games.entries)
          game.fens[e.key]: {
            'moves': [
              for (final m in e.value.entries)
                {'san': m.key, 'white': m.value, 'draws': 0, 'black': 0},
            ],
          },
      },
      unavailable: null,
    );
  };
}

class _Tablebase {
  _Tablebase(this.answers);
  final Map<String, SyzygyResult> answers;
  int asked = 0;

  Future<SyzygyResult?> call(String fen) async {
    asked++;
    return answers[fen];
  }
}

SyzygyResult _tb(
  String fen,
  SyzygyCategory category,
  Map<String, SyzygyCategory> moves,
) =>
    SyzygyResult(
      fen: fen,
      category: category,
      checkmate: false,
      stalemate: false,
      insufficientMaterial: false,
      moves: [
        for (final m in moves.entries)
          SyzygyMove(
            uci: m.key,
            san: m.key,
            category: m.value,
            zeroing: false,
            checkmate: false,
            stalemate: false,
          ),
      ],
    );

GameReviewJudge _judge(
  _Engine engine, {
  BookLookup? book,
  TablebaseLookup? tablebase,
  int budget = kDeepeningSearches,
}) =>
    GameReviewJudge(
      analyzer: engine.call,
      book: book ?? _noBook,
      tablebase: tablebase ?? _Tablebase(const {}).call,
      deepeningBudget: budget,
    );

Future<GameReviewResult> _review(
  _Engine engine, {
  BookLookup? book,
  TablebaseLookup? tablebase,
  int budget = kDeepeningSearches,
}) async {
  final result = await _judge(
    engine,
    book: book,
    tablebase: tablebase,
    budget: budget,
  ).review(
    startingFen: engine.game.start,
    uciMoves: engine.game.ucis,
    depth: _d,
  );
  return result!;
}

void main() {
  late _Game italian;
  setUp(() => italian = _Game(_start, _italian));

  group('what a mistake is', () {
    test('+19 against +14 is no mistake, and is not looked at again', () async {
      final engine = _Engine(italian)
        ..walk([
          '+19.00',
          '+19.00',
          '+19.00',
          '+19.00',
          '+19.00',
          '+14.00',
          '+14.00',
        ]);
      final tablebase = _Tablebase(const {});
      final result = await _review(engine, tablebase: tablebase.call);

      final move = result.moves[4];
      expect(move.judgement, isNotNull);
      expect(move.isMistake, isFalse);
      expect(move.judgement!.lostChances, lessThan(1));
      expect(engine.wasAsked('p4 d20 pv2'), isFalse);
      expect(result.mistakes, 0);
      expect(result.cleanWhere(), isTrue);
      expect(result.depth, _d);
      // Thirty-two men: nothing for the tablebase to say.
      expect(tablebase.asked, 0);
    });

    test('a mate in 3 left for a move at 86 chances is a mistake', () async {
      final engine = _Engine(italian)
        ..walk(['M5', 'M4', 'M3', c(86), c(86), c(86), c(86)]);
      final result = await _review(engine);

      expect(result.moves[2].isMistake, isTrue);
      expect(result.moves[2].judgement!.reason, MistakeReason.missedMate);
      expect(result.mistakes, 1);
    });

    test('a mate in 18 left in a won ending is not', () async {
      final engine = _Engine(italian)
        ..walk(['M19', 'M18', 'M18', c(94), c(94), c(94), c(94)]);
      final result = await _review(engine);

      expect(result.moves[2].judgement, isNotNull);
      expect(result.moves[2].isMistake, isFalse);
    });

    test('a slower mate is a mate', () async {
      final engine = _Engine(italian)
        ..walk(['M3', 'M2', 'M2', 'M4', 'M4', 'M4', 'M4']);
      final result = await _review(engine);

      expect(result.moves[2].isMistake, isFalse);
      expect(result.mistakes, 0);
    });

    test(
      'a move that mates ends the game: judged by the rules, not searched',
      () async {
        final ending = _Game(_rookEnding, _rookMoves);
        final engine = _Engine(ending)..walk(['M2', 'M2', 'M1']);
        final result = await _review(
          engine,
          tablebase: _Tablebase(const {}).call,
        );

        expect(result.moves[2].judgement, isNotNull);
        expect(result.moves[2].isMistake, isFalse);
        expect(engine.wasAsked('p3 '), isFalse);
        expect(result.unjudged, 0);
      },
    );
  });

  group('the book', () {
    test(
      'a book move losing 16 is theory, looked at deeper, and not marked',
      () async {
        final engine = _Engine(italian)..chances([60, 60, 60, 44, 44, 44, 44]);
        final calls = <int>[];
        final result = await _review(
          engine,
          book: _book(
              italian,
              {
                2: {'Nf3': 12},
              },
              calls: calls),
        );

        final move = result.moves[2];
        expect(move.bookGames, 12);
        expect(
          move.deepened,
          isTrue,
          reason: 'a book move is judged on the deepened value',
        );
        expect(move.isMistake, isFalse);
        expect(calls, hasLength(1), reason: 'the book is asked once a game');
      },
    );

    test('a book move losing 22 at every depth is a gross mistake', () async {
      final engine = _Engine(italian)..chances([60, 60, 60, 38, 38, 38, 38]);
      final result = await _review(
        engine,
        book: _book(italian, {
          2: {'Nf3': 12},
        }),
      );

      expect(result.moves[2].isMistake, isTrue);
      expect(result.moves[2].judgement!.reason, MistakeReason.grossInBook);
      expect(result.moves[2].deepened, isTrue);
    });

    test(
      'a book move losing 22 at the walk but 18 deeper is not marked',
      () async {
        final engine = _Engine(italian)..chances([60, 60, 60, 38, 38, 38, 38]);
        engine.alone[2] = (d) => d >= 24 ? c(42) : c(38);
        final result = await _review(
          engine,
          book: _book(italian, {
            2: {'Nf3': 12},
          }),
        );

        final move = result.moves[2];
        expect(move.isMistake, isFalse);
        expect(move.unsettled, isFalse);
        // 22 at 20 against 18 at 24 disagree — one a mistake, one not — and
        // 18 at 28 agrees with 24.
        expect(move.depth, 28);
      },
    );

    test('a move nine master games played is not theory', () async {
      final engine = _Engine(italian)..chances([60, 60, 60, 48, 48, 48, 48]);
      final result = await _review(
        engine,
        book: _book(italian, {
          2: {'Nf3': 9},
        }),
      );

      expect(result.moves[2].isMistake, isTrue);
      expect(result.moves[2].judgement!.reason, MistakeReason.lostChances);
    });

    test('a book that did not answer leaves the engine, and says so', () async {
      final engine = _Engine(italian)..chances([60, 60, 60, 48, 48, 48, 48]);
      final result = await _review(
        engine,
        book: (fens) async => (
          known: const <String, Map<String, dynamic>>{},
          unavailable: 'network',
        ),
      );

      expect(result.bookUnavailable, 'network');
      expect(result.moves[2].isMistake, isTrue);
      expect(result.moves[2].bookGames, isNull);
    });
  });

  group('the second look', () {
    test('a move below the margin is never looked at again', () async {
      final engine = _Engine(italian)..chances([60, 60, 60, 56, 56, 56, 56]);
      engine.alone[2] = at(c(40));
      final result = await _review(engine);

      expect(result.moves[2].isMistake, isFalse);
      expect(engine.wasAsked('p2 d20 pv2'), isFalse);
    });

    test(
      'a loss of 7 is a candidate, and 13 then 12 deeper is a mistake',
      () async {
        final engine = _Engine(italian)..chances([60, 60, 60, 53, 53, 53, 53]);
        engine.alone[2] = (d) => d >= 24 ? c(48) : c(47);
        final result = await _review(engine);

        final move = result.moves[2];
        expect(move.isMistake, isTrue);
        expect(move.deepened, isTrue);
        expect(move.depth, 24);
        expect(move.judgement!.lostChances, closeTo(12, 0.3));
      },
    );

    test('the best line is the deepest look\'s', () async {
      final engine = _Engine(italian)..chances([60, 60, 60, 53, 53, 53, 53]);
      engine.alone[2] = (d) => d >= 24 ? c(48) : c(47);
      engine.best[2] = (d) => d >= 24 ? 'd2d4' : 'b1c3';
      final result = await _review(engine);

      expect(result.moves[2].bestLine!.bestMoveLan, 'd2d4');
      expect(result.moves[2].replyLine, isNotNull);
    });

    test('two looks that agree settle a move without going deeper', () async {
      final engine = _Engine(italian)..chances([60, 60, 60, 48, 48, 48, 48]);
      engine.alone[2] = at(c(46));
      final result = await _review(engine);

      expect(result.moves[2].isMistake, isTrue);
      expect(result.moves[2].deepened, isFalse);
      expect(result.deepeningSearches, 0);
      expect(engine.wasAsked('p2 d24'), isFalse);
    });

    test('a loss of 40 against 30 is deepened too', () async {
      final engine = _Engine(italian)..chances([70, 70, 70, 30, 30, 30, 30]);
      engine.alone[2] = at(c(40));
      final result = await _review(engine);

      expect(result.moves[2].deepened, isTrue);
      expect(result.moves[2].isMistake, isTrue);
    });

    test('settled when the two deepest looks agree', () async {
      final engine = _Engine(italian)..chances([60, 60, 60, 53, 53, 53, 53]);
      engine.alone[2] = (d) => {20: c(47), 24: c(41), 28: c(42)}[d] ?? c(42);
      final result = await _review(engine);

      final move = result.moves[2];
      expect(move.depth, 28);
      expect(move.isMistake, isTrue);
      expect(move.judgement!.lostChances, closeTo(18, 0.3));
    });

    test('looks that never agree are unsettled after three levels', () async {
      final engine = _Engine(italian)..chances([60, 60, 60, 53, 53, 53, 53]);
      engine.alone[2] = (d) => (d ~/ kDeepenStep).isEven ? c(47) : c(41);
      final result = await _review(engine);

      final move = result.moves[2];
      expect(move.unsettled, isTrue);
      expect(move.isMistake, isFalse);
      expect(result.unsettled, 1);
      expect(engine.wasAsked('p2 d32'), isTrue);
      expect(engine.wasAsked('p2 d36'), isFalse);
      expect(result.cleanWhere(), isFalse);
    });

    test(
      'the budget goes to the move closest to its threshold first',
      () async {
        // Ply 2 loses 30 at the walk and 22 at the confirming look — far from
        // 10; ply 4 loses 5 and then 11 — one away. One deepening fits.
        final engine = _Engine(italian)..chances([70, 70, 70, 40, 40, 35, 35]);
        engine.alone[2] = at(c(48));
        engine.alone[4] = at(c(29));
        final result = await _review(engine, budget: 2);

        expect(result.moves[4].deepened, isTrue);
        expect(result.moves[4].isMistake, isTrue);
        expect(result.moves[2].unsettled, isTrue);
        expect(result.moves[2].isMistake, isFalse);
        expect(result.unsettled, 1);
        expect(result.deepeningSearches, 2);
      },
    );

    test(
      'the played move heading the second line needs no search of its own',
      () async {
        final engine = _Engine(italian)..chances([60, 60, 60, 48, 48, 48, 48]);
        engine.secondMove[2] = 'g1f3';
        engine.second[2] = at(c(47));
        final result = await _review(engine);

        expect(result.moves[2].isMistake, isTrue);
        expect(result.moves[2].secondLine, isNotNull);
        expect(
          engine.asked.where((a) => a.startsWith('p2 ') && a.contains('only')),
          isEmpty,
        );
      },
    );

    test(
      'an engine that ignores searchmoves is read from the next position',
      () async {
        final engine = _Engine(italian)
          ..chances([60, 60, 60, 48, 48, 48, 48])
          ..ignoresSearchMoves = true;
        final result = await _review(engine);

        expect(result.moves[2].judgement, isNotNull);
        expect(result.moves[2].isMistake, isTrue);
        expect(result.moves[2].judgement!.lostChances, closeTo(12, 0.3));
      },
    );
  });

  group('what could not be judged', () {
    test('a position that never answers leaves two moves unjudged', () async {
      final engine = _Engine(italian)..reaches[3] = 0;
      final result = await _review(engine);

      expect(result.moves[2].judgement, isNull);
      expect(result.moves[2].unjudgedWhy, isNotNull);
      expect(result.moves[3].judgement, isNull);
      expect(result.unjudged, 2);
      expect(
        result.cleanWhere(),
        isFalse,
        reason: 'a game with an unjudged move is never clean',
      );
      expect(
        engine.wasAsked('p3 d16 pv1'),
        isTrue,
        reason: 'retried once, shallower',
      );
    });

    test(
        'a search stopped short is asked again shallower, and the review '
        'says the smaller depth', () async {
      final engine = _Engine(italian)..reaches[3] = 17;
      final result = await _review(engine);

      expect(result.unjudged, 0);
      expect(result.moves[2].depth, 16);
      expect(result.depth, 16);
    });

    test('the depth a review states is the smallest it stands on', () async {
      final mixed = _Engine(italian)..answersAt[0] = 30;
      expect((await _review(mixed)).depth, _d);

      final deep = _Engine(italian);
      for (var i = 0; i < italian.fens.length; i++) {
        deep.answersAt[i] = 30;
      }
      expect((await _review(deep)).depth, 30);
    });

    test('clean for one side while the other erred', () async {
      // Black's third move loses 12.
      final engine = _Engine(italian)..chances([50, 50, 50, 50, 62, 62, 62]);
      final result = await _review(engine);

      expect(result.moves[3].isMistake, isTrue);
      expect(result.cleanWhere(), isFalse);
      expect(result.cleanWhere((m) => m.whiteMoved), isTrue);
    });

    test('a review can be stopped, and then answers nothing', () async {
      final engine = _Engine(italian);
      final judge = _judge(engine);
      final result = await judge.review(
        startingFen: _start,
        uciMoves: _italian,
        depth: _d,
        onProgress: (p) {
          if (p.stage == ReviewStage.walk && p.done == 3) judge.cancel();
        },
      );
      expect(result, isNull);
      expect(engine.asked.length, lessThan(italian.fens.length));
    });
  });

  group('seven men or fewer', () {
    late _Game ending;
    setUp(() => ending = _Game(_rookEnding, _rookMoves));

    test('a slower win is no mistake, whatever the engine says', () async {
      final engine = _Engine(ending)..walk(['M1', '+6.00', 'M1']);
      final tablebase = _Tablebase({
        ending.fens[0]: _tb(ending.fens[0], SyzygyCategory.win, {
          'h1h8': SyzygyCategory.loss,
          'h1h2': SyzygyCategory.loss,
        }),
      });
      final result = await _review(engine, tablebase: tablebase.call);

      expect(result.moves[0].byTablebase, isTrue);
      expect(result.moves[0].isMistake, isFalse);
      expect(
        engine.wasAsked('p0 d20 pv2'),
        isFalse,
        reason: 'the tablebase judges it; the engine is not asked again',
      );
    });

    test(
      'a win given away for a draw is, however small the engine\'s number',
      () async {
        final engine = _Engine(ending)..walk(['+6.00', '+5.80', 'M1']);
        final tablebase = _Tablebase({
          ending.fens[0]: _tb(ending.fens[0], SyzygyCategory.win, {
            'h1h8': SyzygyCategory.loss,
            'h1h2': SyzygyCategory.draw,
          }),
        });
        final result = await _review(engine, tablebase: tablebase.call);

        expect(result.moves[0].isMistake, isTrue);
        expect(result.moves[0].judgement!.reason, MistakeReason.worseResult);
      },
    );

    test(
        'a win the fifty-move rule takes away is a draw: holding it is no '
        'mistake', () async {
      final engine = _Engine(ending)..walk(['+6.00', '+0.00', 'M1']);
      final tablebase = _Tablebase({
        ending.fens[0]: _tb(ending.fens[0], SyzygyCategory.cursedWin, {
          'h1h2': SyzygyCategory.draw,
        }),
      });
      final result = await _review(engine, tablebase: tablebase.call);

      expect(result.moves[0].byTablebase, isTrue);
      expect(result.moves[0].isMistake, isFalse);
    });

    test(
      'a tablebase that does not answer leaves the engine, and is counted',
      () async {
        final engine = _Engine(ending)..walk(['M1', '+6.00', 'M1']);
        final tablebase = _Tablebase(const {});
        final result = await _review(engine, tablebase: tablebase.call);

        expect(result.moves[0].byTablebase, isFalse);
        expect(result.moves[0].isMistake, isTrue);
        expect(result.moves[0].judgement!.reason, MistakeReason.missedMate);
        expect(result.tablebaseUnanswered, 3);
      },
    );
  });

  group('the store', () {
    test(
      'a review run again asks the engine nothing it already answered',
      () async {
        final engine = _Engine(italian)..chances([60, 60, 60, 53, 53, 53, 53]);
        engine.alone[2] = (d) => d >= 24 ? c(48) : c(47);
        final store = EvalCache();
        Future<String?> name() async => 'engine-a';

        Future<GameReviewResult?> run(EngineAnswerTally tally) =>
            GameReviewJudge(
              analyzer: store.wrapMoves(
                engine.call,
                engine: name,
                tally: tally,
              ),
              book: _noBook,
              tablebase: _Tablebase(const {}).call,
            ).review(startingFen: _start, uciMoves: _italian, depth: _d);

        final first = await run(EngineAnswerTally());
        final asked = engine.asked.length;
        final tally = EngineAnswerTally();
        final second = await run(tally);

        expect(
          engine.asked.length,
          asked,
          reason: 'a stopped review resumes from the store',
        );
        expect(tally.searched, 0);
        expect(tally.fromStore, greaterThan(0));
        expect(first!.moves[2].isMistake, isTrue);
        expect(second!.moves[2].isMistake, isTrue);
      },
    );
  });

  group('what the review leaves on the game', () {
    late AnalysisNode root;
    late List<AnalysisNode> chain;

    setUp(() {
      root = AnalysisNode(fen: _start);
      chain = [];
      var node = root;
      final game = chess.Chess.fromFEN(_start);
      for (final u in _italian) {
        final san = legalMoves(
          game,
        ).firstWhere((m) => '${m['from']}${m['to']}' == u)['san'] as String;
        game.move({'from': u.substring(0, 2), 'to': u.substring(2, 4)});
        node = node.addChild(childFen: game.fen, san: san, uci: u);
        chain.add(node);
      }
    });

    ReviewedMove move(
      int i, {
      double lost = 0,
      MistakeReason? reason,
      bool unsettled = false,
      bool judged = true,
      String bestPv = 'd2d4 d7d5',
      String replyPv = '',
    }) =>
        ReviewedMove(
          ply: i,
          san: chain[i].moveSan!,
          uci: _italian[i],
          fenBefore: i == 0 ? _start : chain[i - 1].fen,
          fenAfter: chain[i].fen,
          whiteMoved: i.isEven,
          judgement: judged ? MoveJudgement(lost, reason) : null,
          unsettled: unsettled,
          depth: judged ? _d : null,
          bestLine: AnalysisLine.fromPv(
            multipv: 1,
            depth: _d,
            eval: '+0.50',
            pvString: i == 2 ? bestPv : '',
            startingFen: i == 0 ? _start : chain[i - 1].fen,
          ),
          replyLine: replyPv.isEmpty
              ? null
              : AnalysisLine.fromPv(
                  multipv: 1,
                  depth: _d,
                  eval: '+0.50',
                  pvString: replyPv,
                  startingFen: chain[i].fen,
                ),
        );

    GameReviewResult result() => GameReviewResult(
          reviewDepth: _d,
          moves: [
            move(0),
            move(1,
                lost: 30, reason: MistakeReason.lostChances, unsettled: true),
            move(2,
                lost: 12, reason: MistakeReason.lostChances, replyPv: 'f8c5'),
            move(3,
                lost: 25, reason: MistakeReason.lostChances, replyPv: 'd2d4'),
            move(4, judged: false),
            move(5, lost: 4),
          ],
        );

    test(
      '?? on exactly the review\'s mistakes, the better line beside them',
      () {
        final marked = GameAnalysisWalkerService().markMistakes(
          chain: chain,
          result: result(),
        );

        expect(marked, 2);
        expect(
          [for (final n in chain) n.nag],
          [null, null, '??', '??', null, null],
        );
        final parent = chain[1];
        expect(parent.children, hasLength(2));
        final better = parent.children[1];
        expect(better.moveSan, 'd4');
        expect(better.nag, '!');
        expect(better.comment, 'Better move');
        expect(better.children.single.moveSan, 'd5');
      },
    );

    test('only the side chosen', () {
      final marked = GameAnalysisWalkerService().markMistakes(
        chain: chain,
        result: result(),
        side: BlunderAlertSide.white,
        insertAlternativeLine: false,
      );

      expect(marked, 1);
      expect(
        [for (final n in chain) n.nag],
        [null, null, '??', null, null, null],
      );
      expect(chain[1].children, hasLength(1));
    });

    // "today's puzzles from the mistakes, worst first" — superseded by
    // `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md` phase 1.3: a puzzle is now the
    // position *before* the mistake, not after it, and needs `B` = 15 over
    // the second best, not merely a loss (§1, §3). `buildPuzzlesFromReview`
    // also returns a `ReviewPuzzles` (mistakes and the only moves a player
    // found, apart), not a flat list, so this case no longer compiles against
    // the new API. What it asserted lives in
    // `test/core/review_puzzles_test.dart`: "worst first by chances lost, at
    // most Max puzzles" (the ranking and the cap) and "the position before
    // the mistake, the best move its answer" (the position and the answer).
  });
}
