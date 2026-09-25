// An engine that answers from a tutorial's facts — `docs/PLAN-ZAGONETKE-IZ-
// PARTIJE.md`, phase 1b.
//
// The ten fixture games carry the engine's answers for every position they
// reach (`facts.rows[].candidates`). Phase 1b judges a game with the review's
// own judge (`GameReviewJudge`) and writes its verdicts into the facts; for
// the fixtures to hold those verdicts without a real engine — and so that the
// tool that writes them and the tests that read them get the very same ones —
// the judge is run against this: every position answered from its stored
// candidates, and „the played move alone" (`searchmoves`) from the stored
// answer of the position the move leads to. It answers at whatever depth it is
// asked, so the judge's looks always agree and nothing is deepened: the
// fixtures' verdicts are the rule applied to the fixtures' own numbers.
//
// Shared by `tool/judge_facts.dart` (which writes the verdicts into the
// harness's input facts) and the tests that run the tutorial end to end.

import 'package:chess/chess.dart' as chess;

import 'package:chess_app/core/services/eval_cache.dart' show MoveAnalyzer;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/masters_walk.dart';
import 'package:chess_app/models/analysis_models.dart';

/// A FEN without its en-passant field: the harness writes one only where a
/// capture is legal, the app wherever a pawn has just moved two squares.
String withoutEp(String fen) {
  final f = fen.trim().split(RegExp(r'\s+'));
  return [f[0], f[1], f[2], f[4], f[5]].join(' ');
}

/// A facts evaluation (`+0.39`, `#3`, `#-2`, White's view) as the app spells
/// it (`+0.39`, `M3`, `-M2`).
String appEval(String factsEval) {
  if (factsEval.startsWith('#')) {
    final m = int.parse(factsEval.substring(1));
    return m > 0 ? 'M$m' : '-M${m.abs()}';
  }
  final v = double.parse(factsEval);
  return v > 0 ? '+${v.toStringAsFixed(2)}' : v.toStringAsFixed(2);
}

/// The UCI moves of [sans] played from [fen]; it stops at the first move that
/// cannot be played.
List<String> uciOfLine(String fen, List<String> sans) {
  final board = chess.Chess.fromFEN(fen);
  final out = <String>[];
  for (final san in sans) {
    if (!board.move(san)) break;
    final m = board.history.last.move;
    out.add('${m.fromAlgebraic}${m.toAlgebraic}${m.promotion?.name ?? ''}');
  }
  return out;
}

List<String> _sansOf(Object? line) => (line as String? ?? '')
    .split(RegExp(r'\s+'))
    .where((t) => t.isNotEmpty)
    .toList();

/// A [MoveAnalyzer] answering from [facts]. [onCall] sees every question.
MoveAnalyzer factsEngine(
  Map<String, dynamic> facts, {
  void Function(int call)? onCall,
}) {
  final rows = (facts['rows'] as List).cast<Map<String, dynamic>>();
  final byPosition = <String, Map<String, dynamic>>{
    for (final r in rows) withoutEp(r['fen'] as String): r,
  };
  var calls = 0;

  AnalysisLine lineOf(
    String fen,
    int rank,
    int depth,
    String eval,
    List<String> uci,
  ) =>
      AnalysisLine.fromPv(
        multipv: rank,
        depth: depth,
        eval: eval,
        pvString: uci.join(' '),
        startingFen: fen,
      );

  return (String fen,
      {required int depth,
      required int multiPV,
      List<String>? searchMoves,
      Duration timeout = const Duration(seconds: 1)}) async {
    onCall?.call(++calls);
    final row = byPosition[withoutEp(fen)];
    if (row == null) throw StateError('not in the facts: $fen');
    final cands = (row['candidates'] as List).cast<Map<String, dynamic>>();

    if (searchMoves != null && searchMoves.isNotEmpty) {
      final move = searchMoves.first;
      for (final c in cands) {
        final uci = uciOfLine(fen, _sansOf(c['line']));
        if (uci.isNotEmpty && uci.first == move) {
          return [lineOf(fen, 1, depth, appEval(c['eval'] as String), uci)];
        }
      }
      // Not among the stored lines: the move, then the stored answer of the
      // position it leads to — the value the facts give the move played.
      final board = chess.Chess.fromFEN(fen);
      final played = board.move({
        'from': move.substring(0, 2),
        'to': move.substring(2, 4),
        if (move.length > 4) 'promotion': move.substring(4),
      });
      if (!played) throw StateError('$move cannot be played from $fen');
      final after = byPosition[withoutEp(board.fen)];
      final afterCands = (after?['candidates'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
      if (afterCands.isEmpty) {
        final whiteMoved = fen.split(' ')[1] == 'w';
        final eval = board.in_checkmate ? (whiteMoved ? 'M1' : '-M1') : '0.00';
        return [
          lineOf(fen, 1, depth, eval, [move])
        ];
      }
      final reply = uciOfLine(board.fen, _sansOf(afterCands.first['line']));
      return [
        lineOf(fen, 1, depth, appEval(afterCands.first['eval'] as String),
            [move, ...reply]),
      ];
    }

    return [
      for (var i = 0; i < cands.length && i < multiPV; i++)
        lineOf(fen, i + 1, depth, appEval(cands[i]['eval'] as String),
            uciOfLine(fen, _sansOf(cands[i]['line']))),
    ];
  };
}

/// The masters answers [facts] were built from, keyed by [fens] — the app's
/// own FENs of the same positions, in order.
Future<MastersWalk> factsMasters(
  Map<String, dynamic> facts,
  List<String> fens,
) async {
  final rows = (facts['rows'] as List).cast<Map<String, dynamic>>();
  final known = <String, Map<String, dynamic>>{};
  for (var i = 0; i < rows.length && i < fens.length; i++) {
    final book = rows[i]['book'] as Map<String, dynamic>?;
    if (book == null) break;
    final played = book['played'] as Map<String, dynamic>?;
    known[fens[i]] = {
      'white': book['games'],
      'draws': 0,
      'black': 0,
      if (book.containsKey('opening')) 'opening': {'name': book['opening']},
      'moves': [
        if (played != null && (played['games'] as num) > 0)
          {'san': played['move'], 'white': played['games']},
        for (final alt in book['alternatives'] as List)
          {'san': alt['move'], 'white': alt['games']},
      ],
    };
  }
  return (known: known, unavailable: null);
}
