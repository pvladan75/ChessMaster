import 'package:chess/chess.dart' as chess;

import 'package:chess_app/features/tutorial_studio/services/game_tutorial/board_queries.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/evaluation_words.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_parameters.dart';

/// Python's `round(val)`: half-to-even, and only on a value that is **exactly**
/// a half.
///
/// A tolerance is wrong in both directions: `100 * 0.545` is
/// `54.50000000000001`, which Python rounds to 55 and a 1e-9 window called a
/// tie and rounded to 54. Doubling a double is exact, so an exact half is
/// precisely a value whose double is an odd integer.
int roundHalfToEven(double val) {
  final twice = val * 2;
  if (twice == twice.truncateToDouble() && twice.toInt().isOdd) {
    final floor = val.floor();
    return floor.isEven ? floor : floor + 1;
  }
  return val.round();
}

/// Python's `'%.1f' % val`.
///
/// `toStringAsFixed(1)` rounds the exact binary value correctly except on an
/// exact tie, which it rounds away from zero where Python rounds to even:
/// `0.25` is `0.3` here and `0.2` there. A one-decimal tie is `(2k + 1) / 20`,
/// and the only such values a double holds exactly are the odd quarters —
/// `x.25` and `x.75` — so a tie is precisely a value whose fourfold is an odd
/// integer (multiplying by four is exact too).
String oneDecimal(double val) {
  final quarters = val * 4;
  if (quarters == quarters.truncateToDouble() && quarters.toInt().isOdd) {
    final tenths = roundHalfToEven(val * 10);
    return (tenths / 10).toStringAsFixed(1);
  }
  return val.toStringAsFixed(1);
}

String formatMaterial(int mat) => mat >= 0 ? '+$mat' : '$mat';

String costText(Map<String, dynamic> played) {
  final cost = played['cost_pawns'];
  if (cost == 'mate') {
    return played['cost_mate'] as String? ?? 'cost a forced mate';
  }
  if (cost == null) {
    return 'cost an unknown amount';
  }
  return 'cost $cost pawns';
}

double costValue(Object? cost) {
  if (cost == 'mate') return 1e9;
  if (cost is num) return cost.toDouble();
  return -1.0;
}

String shareWords(num share) {
  final s = share.toDouble();
  if (s >= 0.10) {
    return '${roundHalfToEven(100 * s)}%';
  }
  if (s >= 0.001) {
    return '${oneDecimal(100 * s)}%';
  }
  return 'under 0.1%';
}

String bookWords(Map<String, dynamic> row) {
  final book = row['book'] as Map<String, dynamic>?;
  if (book == null) return '';
  final played = (book['played'] as Map<String, dynamic>?) ?? {};
  final games = book['games'] as int;
  final reached = games == 1
      ? '1 master game has reached this position'
      : '$games master games have reached this position';
  String said;
  final playedGames = played['games'] as int?;
  if (playedGames != null && playedGames > 0 && games == 1) {
    said = '$reached, and it played ${played['move']}';
  } else if (playedGames != null && playedGames > 0) {
    said =
        '$reached, and ${shareWords(played['share'] as num)} of them played ${played['move']}';
  } else {
    final playedMove = played['move'] ?? 'this move';
    said = '$reached and not one of them played $playedMove';
  }
  final alternatives = (book['alternatives'] as List?) ?? const [];
  final others = [
    for (final a in alternatives)
      '${a['move']} ${shareWords(a['share'] as num)}'
  ].join(', ');
  if (others.isNotEmpty) {
    said += '; the other moves played here are $others';
  }
  if (book['opening'] != null) {
    said += '. The opening is the ${book['opening']}';
  }
  return said;
}

List<Map<String, dynamic>> skeletonMoments(
  Map<String, dynamic> facts, {
  SkeletonParameters parameters = const SkeletonParameters(),
}) {
  final rows = (facts['rows'] as List).cast<Map<String, dynamic>>();

  final heavy = <int>[];
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final played = row['played'] as Map<String, dynamic>?;
    final candidates = row['candidates'] as List?;
    if (played != null && candidates != null && candidates.isNotEmpty) {
      if (costValue(played['cost_pawns']) >= parameters.minCost) {
        heavy.add(i);
      }
    }
  }

  // Stable sort by cost descending, then index ascending (Divergence 1)
  heavy.sort((a, b) {
    final costA = costValue(rows[a]['played']?['cost_pawns']);
    final costB = costValue(rows[b]['played']?['cost_pawns']);
    final cmp = costB.compareTo(costA);
    if (cmp != 0) return cmp;
    return a.compareTo(b);
  });

  final picked = heavy.take(parameters.maxMoments).toList()..sort();

  final out = <Map<String, dynamic>>[];
  for (var number = 1; number <= picked.length; number++) {
    final i = picked[number - 1];
    final mid = 'm$number';
    final row = rows[i];
    final mover = row['to_move'] as String;
    final black = mover == 'Black';
    final candidates = (row['candidates'] as List).cast<Map<String, dynamic>>();
    final best = candidates[0];
    final near = (parameters.near * 100).round();
    final bestVal = best['value_for_mover'] as num;
    final correct = candidates
        .where((c) => bestVal - (c['value_for_mover'] as num) <= near)
        .toList();
    final asks = correct.length <= parameters.maxCorrect;

    String? boardHere =
        i > 0 ? (rows[i - 1]['motifs_after_played'] as String?) : null;
    if (boardHere == null || boardHere.isEmpty) {
      final bw = bookWords(row);
      boardHere = bw.isNotEmpty ? bw : null;
    }

    final played = row['played'] as Map<String, dynamic>;
    final slots = <String, String>{};
    final slotFacts = <String, Map<String, dynamic>>{};
    final parts = <Map<String, dynamic>>[];

    // The lead-in: the game moves that brought the board here.
    final start =
        (i - parameters.leadPlies) < 0 ? 0 : (i - parameters.leadPlies);
    if (start < i) {
      final board = chess.Chess.fromFEN(rows[start]['fen'] as String);
      final before = materialOf(board);
      final moves = <Map<String, dynamic>>[];
      for (var r = start; r < i; r++) {
        final gameMove = rows[r]['played'] as Map<String, dynamic>;
        final sid = '$mid.lead.${moves.length + 1}';
        final info = playMoveOnBoard(board, gameMove['move'] as String);
        var text =
            '${info['words']}; played in the game; afterwards ${wordsFor(gameMove['eval'] as String?)}';
        if (rows[r]['motifs_after_played'] != null &&
            (rows[r]['motifs_after_played'] as String).isNotEmpty) {
          text += '; on the board after it: ${rows[r]['motifs_after_played']}';
        }
        final book = bookWords(rows[r]);
        if (book.isNotEmpty) {
          text += '. In the masters database: $book';
        }
        slots[sid] = text;
        slotFacts[sid] = {
          ...info,
          'motifs': rows[r]['motifs_after_played'] ?? '',
        };
        moves.add({
          'san': gameMove['move'],
          'slot': sid,
          'ply': r,
          'fen_before': rows[r]['fen'],
        });
      }
      final intro = '$mid.lead.intro';
      slots[intro] =
          'the board before these moves (${rows[start]['to_move']} to move); material White minus Black is ${formatMaterial(before)} before them and ${formatMaterial(materialOf(board))} after them';
      slotFacts[intro] = {
        'gain': 0,
        'mate': false,
        'fork': false,
        'pin': false,
        'motifs': '',
      };
      parts.add({
        'kind': 'show',
        'fen': rows[start]['fen'],
        'intro': intro,
        'moves': moves,
        'lead': true,
      });
    }

    // The question.
    if (asks) {
      final qid = '$mid.question';
      final alsoCorrect = [
        for (var c = 1; c < correct.length; c++) correct[c]['move'] as String
      ].join(', ');
      final boardText = boardHere != null ? ' On the board: $boardHere.' : '';
      slots[qid] =
          '$mover to move. The best move is ${best['move']}, and afterwards ${wordsFor(best['eval'] as String?)}. Also counted correct: ${alsoCorrect.isNotEmpty ? alsoCorrect : 'nothing else'}. What follows the best move: ${best['line']}. In the game ${played['move']} was played instead; it ${costText(played)} and afterwards ${wordsFor(played['eval'] as String?)}.$boardText Ask for the move in one sentence, without naming it or its destination square.';

      final bestMoveStr = best['move'] as String;
      final cleanMove = bestMoveStr.replaceAll(RegExp(r'[+#]+$'), '');
      final destSquare = cleanMove.length >= 2
          ? cleanMove.substring(cleanMove.length - 2)
          : cleanMove;
      slotFacts[qid] = {
        'gain': 0,
        'mate': false,
        'fork': false,
        'pin': false,
        'motifs': boardHere ?? '',
        'question': true,
        'names': [bestMoveStr, destSquare],
      };
      parts.add({
        'kind': 'ask_move',
        'fen': row['fen'],
        'instruction': qid,
        'solution': best['move'],
        'accepted': [
          for (var c = 1; c < correct.length; c++) correct[c]['move'] as String
        ],
      });
    }

    // The answer: the best line.
    final board = chess.Chess.fromFEN(row['fen'] as String);
    final before = materialOf(board);
    final moves = <Map<String, dynamic>>[];
    final lineMoves = (best['line'] as String)
        .split(RegExp(r'\s+'))
        .take(parameters.answerPlies)
        .toList();
    for (var k = 1; k <= lineMoves.length; k++) {
      final san = lineMoves[k - 1];
      final sid = '$mid.answer.$k';
      final info = playMoveOnBoard(
        board,
        san,
        verb: k == 1 ? 'should have played' : 'would answer',
      );
      slots[sid] =
          '${info['words']}${k == 1 ? '; not played - the best move the game missed' : '; not played - the line goes on'}';
      slotFacts[sid] = {
        ...info,
        'motifs': '',
      };
      moves.add({'san': san, 'slot': sid});
    }
    final intro = '$mid.answer.intro';
    // **The introduction does not name the move, and that is the point.** It
    // used to open „$mover should have played ${best['move']} instead of the game
    // move ${played['move']}", and the slot right after it opens „should have
    // played ${best['move']}" too — so every answer part said the same move
    // twice in two consecutive sentences (the owner, 14.9.2026, on „Lost
    // chances"). The model was faithful; it was handed the same fact twice.
    // The introduction frames what the game did and what the line is worth,
    // the first move of the line names it as it appears on the board — which
    // is also the better lesson, since a move read before it is played is a
    // move given away. The instruction is written into the fact the way the
    // question slot's already is; that is the idiom here, not a new one.
    slots[intro] =
        'the answer: the game went ${played['move']}, which ${costText(played)}. At the end of the best line ${wordsFor(best['eval'] as String?)}; material White minus Black goes from ${formatMaterial(before)} to ${formatMaterial(materialOf(board))} over the moves shown. Say in one sentence that $mover had something better here, without naming the move or its destination square - the move after this sentence names it.';
    final change = materialOf(board) - before;
    final gain = change > 0
        ? (!black ? change : 0)
        : (change < 0 ? (black ? -change : 0) : 0);
    slotFacts[intro] = {
      'gain': gain,
      'mate': false,
      'fork': false,
      'pin': false,
      'motifs': '',
    };
    parts.add({
      'kind': 'show',
      'fen': row['fen'],
      'intro': intro,
      'moves': moves,
    });

    for (final entry in slots.entries) {
      slotFacts[entry.key]!['text'] = entry.value;
    }

    out.add({
      'id': mid,
      'index': i,
      'label': row['label'],
      'mover': mover,
      'played': played['label'],
      'cost': played['cost_pawns'],
      'cost_text': costText(played),
      'left_book': played['left_book'] == true,
      'best': best['move'],
      'asks': asks,
      'correct': [for (final c in correct) c['move']],
      'board': boardHere,
      'parts': parts,
      'slots': slots,
      'facts': slotFacts,
    });
  }

  return out;
}
