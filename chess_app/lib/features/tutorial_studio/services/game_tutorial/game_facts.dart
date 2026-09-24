/// The facts of a game, built on the device — phase 2 of `docs/PLAN-SKELET.md`.
///
/// A port of `tools/game_annotate/make_facts.py`, and held to it:
/// `test/game_tutorial_facts_test.dart` rebuilds the rows of the ten fixture
/// games from their own candidates and asks for the harness's rows back, and
/// `facts_cases.json` — written by the harness — carries the cases no game
/// reaches: a mate among the candidates, a margin of exactly half a pawn, a
/// share that is an exact tie at the fourth decimal.
///
/// **What runs where.** The rows, the masters statistics and the arithmetic are
/// pure and live here. The engine is a [PositionAnalyzer], so the builder never
/// knows whether it is talking to a process, to the app's plugin or to a test;
/// on Windows it is given one single-threaded process per worker, each position
/// searched from an empty hash, which is what phase 0 measured identical to the
/// harness.
///
/// **A search that did not finish is not a fact** (the plan's rule 1): every
/// answer must reach the asked depth with as many lines as were asked, or as
/// there are legal moves. A miss is searched once more and then the build fails
/// with a sentence. A miss that happened while the computer was asleep is not
/// counted against that one retry — phase 0 met it, when a laptop's battery ran
/// out in the middle of a game.
library;

import 'package:chess/chess.dart' as chess;

import 'package:chess_app/core/services/game_analysis_walker_service.dart';
import 'package:chess_app/features/analysis_studio/services/auto_tree_generator_service.dart'
    show PositionAnalyzer;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/masters_walk.dart'
    show totalOf;
import 'package:chess_app/models/analysis_models.dart';

/// `make_facts.MATE`: a mate in n is worth `mate - n` to the side giving it.
const int kFactsMate = 100000;
const int kFactsMultiPv = 4;
const double kFactsMarginPawns = 0.5;
const int kFactsLineLength = 6;

/// How many failed searches may coincide with a sleep before the build stops
/// believing it was the sleep.
const int kFactsSleepRetries = 5;

/// A build that cannot go on, in a sentence a trainer can read.
class GameFactsException implements Exception {
  const GameFactsException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The trainer pressed cancel. Not a failure, and not reported as one.
class GameFactsCancelled implements Exception {
  const GameFactsCancelled();
}

// --- One answer ---------------------------------------------------------------

/// A line as the facts file keeps it: `make_facts.candidates_of`.
///
/// [AnalysisLine.evaluation] is the app's own spelling, always from White's
/// side: `+1.39`, `-0.35`, `0.00`, `M3`, `-M2`. The facts spell it the harness's
/// way (`+0.00`, `#3`, `#-2`) and add the one number every rule reads, the
/// evaluation from the side to move.
Map<String, dynamic> candidateOf(AnalysisLine line,
    {required bool whiteToMove}) {
  final raw = line.evaluation.trim();
  final mate = RegExp(r'^(-)?M(\d+)$').firstMatch(raw);
  final int valueForMover;
  final String eval;
  if (mate != null) {
    final distance = int.parse(mate.group(2)!);
    final whiteMate = mate.group(1) == null ? distance : -distance;
    final whiteValue = (kFactsMate - distance) * (whiteMate > 0 ? 1 : -1);
    valueForMover = whiteToMove ? whiteValue : -whiteValue;
    eval = '#$whiteMate';
  } else {
    final pawns = double.tryParse(raw);
    if (pawns == null) {
      throw GameFactsException(
          'The engine gave an evaluation the facts cannot read: "$raw".');
    }
    final whiteCp = (pawns * 100).round();
    valueForMover = whiteToMove ? whiteCp : -whiteCp;
    eval =
        '${whiteCp < 0 ? '-' : '+'}${(whiteCp.abs() / 100).toStringAsFixed(2)}';
  }
  return {
    'move': line.sanMoveList.first,
    'eval': eval,
    'value_for_mover': valueForMover,
    'line': line.sanMoveList.take(kFactsLineLength).join(' '),
  };
}

/// Why [lines] is not an answer for [fen] at [depth], or null when it is.
String? searchProblem(String fen, List<AnalysisLine> lines,
    {required int depth, int multiPv = kFactsMultiPv}) {
  final legal = chess.Chess.fromFEN(fen).moves().length;
  final wanted = legal < multiPv ? legal : multiPv;
  if (lines.length != wanted) {
    return '${lines.length} lines where $wanted were asked';
  }
  final ranks = [for (final l in lines) l.multipv]..sort();
  for (var i = 0; i < ranks.length; i++) {
    if (ranks[i] != i + 1) return 'the lines are not ranked 1 to $wanted';
  }
  final shallow = [
    for (final l in lines)
      if (l.depth < depth) l.depth
  ];
  if (shallow.isNotEmpty) {
    return 'a line stopped at depth ${shallow.join('/')} of $depth';
  }
  // A line with no moves is not asked about here: `candidateOf` cannot read
  // one, and the build counts that as a miss like any other.
  return null;
}

// --- The rows -----------------------------------------------------------------

/// `make_facts.walk`: every position of the game with what needs no engine —
/// the label, the position, who is to move, the move played, a finished game,
/// and the motif detector's sentence about the move played.
///
/// The sentences are `GameAnalysisWalkerService`'s with no engine behind it,
/// which is exactly how the harness's reviewed games were written.
Future<List<Map<String, dynamic>>> gameRows({
  required String startFen,
  required List<String> uciMoves,
}) async {
  final moments = await GameAnalysisWalkerService().analyzeGame(
    startingFen: startFen,
    uciMoves: uciMoves,
    analyzer: _noEngine,
  );
  if (moments.length != uciMoves.length) {
    final at = moments.length;
    throw GameFactsException(
        'Move ${at + 1} of the game (${uciMoves[at]}) cannot be played, so the '
        'game cannot be analysed.');
  }

  final rows = <Map<String, dynamic>>[];
  var label = 'start';
  for (var index = 0; index <= moments.length; index++) {
    final fen = index == 0 ? startFen : moments[index - 1].fenAfter;
    final board = chess.Chess.fromFEN(fen);
    final white = board.turn == chess.Color.WHITE;
    final row = <String, dynamic>{
      'label': label,
      'fen': fen,
      'to_move': white ? 'White' : 'Black',
    };
    final over = _gameOver(board);
    if (over != null) {
      row['game_over'] = over;
      row['candidates'] = <Map<String, dynamic>>[];
    }
    if (index < moments.length) {
      final san = moments[index].moveSan;
      final number = fen.split(' ')[5];
      final played = <String, dynamic>{
        'move': san,
        'label': white ? '$number. $san' : '$number... $san',
      };
      row['played'] = played;
      final comment = moments[index].combinedComment.trim();
      if (comment.isNotEmpty) row['motifs_after_played'] = comment;
      label = played['label'] as String;
    }
    rows.add(row);
  }
  return rows;
}

Future<List<AnalysisLine>> _noEngine(
  String fen, {
  required int depth,
  required int multiPV,
  Duration timeout = const Duration(seconds: 1),
}) async =>
    const [];

/// python-chess's `is_game_over(claim_draw=False)` as far as a game reaches:
/// mate, stalemate, bare material. The 75-move rule and fivefold repetition
/// are not asked.
String? _gameOver(chess.Chess board) {
  if (board.in_checkmate) {
    return board.turn == chess.Color.WHITE ? '0-1' : '1-0';
  }
  if (board.in_stalemate || board.insufficient_material) return '1/2-1/2';
  return null;
}

// --- The masters database -----------------------------------------------------

/// `make_facts.add_book`: what the masters database says, onto [rows].
///
/// [known] is the walk's answer — the explorer's own shape, by position — and
/// it is read until the first position it does not hold. Three things go in:
/// `book` on every such row, `left_book` on the first move no master played,
/// and the removal of the motif sentence wherever the move played is theory.
/// Returns the number of rows in the book.
int applyMastersBook(
    List<Map<String, dynamic>> rows, Map<String, Map<String, dynamic>> known) {
  if (known.isEmpty) return 0;
  var left = false;
  for (final row in rows) {
    final data = known[row['fen']];
    if (data == null) break;
    final here = totalOf(data);
    final played = row['played'] as Map<String, dynamic>?;
    final entry = <String, dynamic>{'games': here};
    final opening = data['opening'];
    if (opening is Map && opening.isNotEmpty) {
      entry['opening'] = opening['name'];
    }
    final moves = [
      for (final m in (data['moves'] as List? ?? const []))
        <String, dynamic>{
          'move': m['san'],
          'games': totalOf(m as Map),
          'share': pythonRound4(totalOf(m) / here),
        }
    ];
    if (played != null) {
      Map<String, dynamic>? mine;
      for (final m in moves) {
        if (m['move'] == played['move']) {
          mine = m;
          break;
        }
      }
      entry['played'] =
          mine ?? {'move': played['move'], 'games': 0, 'share': 0.0};
      if (mine == null && !left) {
        played['left_book'] = true;
        left = true;
      }
      if (mine != null) row.remove('motifs_after_played');
    }
    entry['alternatives'] = [
      for (final m in moves)
        if (played == null || m['move'] != played['move']) m
    ].take(3).toList();
    row['book'] = entry;
  }
  return rows.where((r) => r.containsKey('book')).length;
}

/// Python's `round(x, 4)`.
///
/// `toStringAsFixed` agrees with it everywhere but on an exact binary tie,
/// where Python rounds to even and Dart rounds up. At four decimals the only
/// ties a double can hold are odd multiples of 1/32 — and a position with 32
/// master games reaches one.
double pythonRound4(double x) {
  final thirtySeconds = x * 32;
  if (thirtySeconds == thirtySeconds.roundToDouble() &&
      thirtySeconds.round().isOdd) {
    final floor = (x * 10000).floor();
    return (floor.isEven ? floor : floor + 1) / 10000;
  }
  return double.parse(x.toStringAsFixed(4));
}

// --- The arithmetic -----------------------------------------------------------

Object _pawns(int value) =>
    value.abs() > kFactsMate / 2 ? 'mate' : value / 100.0;

/// `make_facts.set_cost`: what the move played cost against the best move.
void setCost(Map<String, dynamic> played, Map<String, dynamic> best) {
  final value = played['value_for_mover'] as int;
  final bestValue = best['value_for_mover'] as int;
  played.remove('cost_mate');
  if (played['move'] == best['move'] || bestValue <= value) {
    played['cost_pawns'] = 0;
    return;
  }
  int side(int v) =>
      (v > kFactsMate / 2 ? 1 : 0) - (v < -kFactsMate / 2 ? 1 : 0);
  if (side(bestValue) == side(value)) {
    played['cost_pawns'] = side(value) == 0 ? _pawns(bestValue - value) : 0;
    return;
  }
  played['cost_pawns'] = 'mate';
  final gaveUp = bestValue > kFactsMate / 2;
  final walkedIn = value < -kFactsMate / 2;
  played['cost_mate'] = gaveUp && walkedIn
      ? 'gave up a forced mate and allowed one'
      : gaveUp
          ? 'gave up a forced mate'
          : walkedIn
              ? 'allowed a forced mate'
              : 'cost a forced mate';
}

/// `make_facts.finish`: stands-out, the margin, and for every move played its
/// evaluation, rank and cost. [rows] must already carry their candidates.
List<Map<String, dynamic>> finishFacts(List<Map<String, dynamic>> rows,
    {double marginPawns = kFactsMarginPawns}) {
  final margin = (marginPawns * 100).round();
  for (var index = 0; index < rows.length; index++) {
    final row = rows[index];
    final cands = (row['candidates'] as List).cast<Map<String, dynamic>>();
    if (cands.isNotEmpty) {
      final best = cands[0]['value_for_mover'] as int;
      if (cands.length == 1) {
        row['best_stands_out'] = false;
        row['why'] = 'only one legal move';
      } else {
        final second = cands[1]['value_for_mover'] as int;
        final bestMate = best.abs() > kFactsMate / 2;
        final secondMate = second.abs() > kFactsMate / 2;
        if (bestMate && best > 0 && !(secondMate && second > 0)) {
          row['best_stands_out'] = true;
          row['margin_pawns'] = 'mate';
        } else if (secondMate) {
          // `make_facts.py` also asks `best_mate` here, and it can never
          // decide: the best line being mated means the second is too.
          row['best_stands_out'] = false;
          row['margin_pawns'] = 'mate';
        } else {
          row['margin_pawns'] = _pawns(best - second);
          row['best_stands_out'] = (best - second) >= margin;
        }
      }
    }

    final played = row['played'] as Map<String, dynamic>?;
    if (played != null && cands.isNotEmpty) {
      final after = rows[index + 1];
      final afterCands = (after['candidates'] as List);
      final int value;
      if (afterCands.isNotEmpty) {
        final top = afterCands[0] as Map<String, dynamic>;
        value = -(top['value_for_mover'] as int);
        played['eval'] = top['eval'];
      } else if (after['game_over'] == '1-0' || after['game_over'] == '0-1') {
        value = kFactsMate;
        played['eval'] = 'checkmate';
      } else {
        value = 0;
        played['eval'] = 'draw';
      }
      played['value_for_mover'] = value;
      final at = [for (final c in cands) c['move']].indexOf(played['move']);
      played['rank'] = at < 0 ? null : at + 1;
      setCost(played, cands[0]);
    }
  }
  return rows;
}

// --- The build ----------------------------------------------------------------

/// One game's facts, from the moves to the finished rows.
class GameFactsBuilder {
  GameFactsBuilder({
    required this.analyzers,
    this.depth = 18,
    this.multiPv = kFactsMultiPv,
    this.marginPawns = kFactsMarginPawns,
    this.searchTimeout = const Duration(minutes: 15),
    int Function()? sleeps,
  })  : assert(analyzers.isNotEmpty),
        _sleeps = sleeps ?? (() => 0);

  /// One per worker. Each is used by one search at a time.
  final List<PositionAnalyzer> analyzers;
  final int depth;
  final int multiPv;
  final double marginPawns;
  final Duration searchTimeout;

  /// How many times the computer has been found asleep so far. A failed
  /// search during which this changed is searched again for free.
  final int Function() _sleeps;

  /// [known] holds the answers already built for this game at this depth by
  /// this engine, by position — a resumed build searches only the rest — and
  /// [onAnswer] is told every new one, so it can be kept.
  Future<Map<String, dynamic>> build({
    required String game,
    required String startFen,
    required List<String> uciMoves,
    Map<String, Map<String, dynamic>> masters = const {},
    Map<String, List<Map<String, dynamic>>> known = const {},
    void Function(String fen, List<Map<String, dynamic>> candidates)? onAnswer,
    void Function(int done, int total)? onProgress,
    bool Function()? cancelled,
    String engine = 'stockfish',
    DateTime Function() now = DateTime.now,
  }) async {
    final rows = await gameRows(startFen: startFen, uciMoves: uciMoves);
    final inBook = applyMastersBook(rows, masters);

    final todo = [
      for (var i = 0; i < rows.length; i++)
        if (!rows[i].containsKey('candidates')) i
    ];
    var done = 0;
    var next = 0;
    Future<void> drain(PositionAnalyzer analyzer) async {
      while (next < todo.length) {
        if (cancelled?.call() ?? false) throw const GameFactsCancelled();
        final row = rows[todo[next++]];
        final fen = row['fen'] as String;
        final stored = known[fen];
        if (stored != null) {
          row['candidates'] = stored;
        } else {
          final candidates =
              await _search(analyzer, row, cancelled ?? () => false);
          row['candidates'] = candidates;
          onAnswer?.call(fen, candidates);
        }
        onProgress?.call(++done, todo.length);
      }
    }

    await Future.wait([for (final a in analyzers) drain(a)]);
    finishFacts(rows, marginPawns: marginPawns);

    return {
      'game': game,
      'depth': depth,
      'multipv': multiPv,
      'margin_pawns': marginPawns,
      'engine': engine,
      'in_book': inBook,
      'generated': now().toIso8601String().substring(0, 19),
      'rows': rows,
    };
  }

  Future<List<Map<String, dynamic>>> _search(PositionAnalyzer analyzer,
      Map<String, dynamic> row, bool Function() cancelled) async {
    final fen = row['fen'] as String;
    final whiteToMove = row['to_move'] == 'White';
    var misses = 0;
    var slept = 0;
    while (true) {
      final sleepsBefore = _sleeps();
      String? why;
      try {
        final lines = await analyzer(fen,
            depth: depth, multiPV: multiPv, timeout: searchTimeout);
        why = searchProblem(fen, lines, depth: depth, multiPv: multiPv);
        if (why == null) {
          final ranked = [...lines]
            ..sort((a, b) => a.multipv.compareTo(b.multipv));
          return [
            for (final l in ranked) candidateOf(l, whiteToMove: whiteToMove)
          ];
        }
      } on GameFactsException {
        rethrow;
      } catch (e) {
        why = 'the engine failed ($e)';
      }
      // Cancelling closes the engines, and a closed engine fails the search it
      // was in: that is the trainer's cancel, not a miss to retry or report.
      if (cancelled()) throw const GameFactsCancelled();
      if (_sleeps() != sleepsBefore) {
        if (++slept > kFactsSleepRetries) {
          throw GameFactsException(
              'The computer went to sleep during the analysis too many times '
              'to finish it. Keep it awake and try again.');
        }
        continue;
      }
      if (++misses >= 2) {
        final at = row['label'] == 'start'
            ? 'the starting position'
            : 'the position after ${row['label']}';
        throw GameFactsException(
            'The engine could not finish $at at depth $depth: $why. Nothing '
            'was spent.');
      }
    }
  }
}
