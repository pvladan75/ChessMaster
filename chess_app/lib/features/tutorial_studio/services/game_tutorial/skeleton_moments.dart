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

/// The moves of [rows] that cost at least [minCost] pawns, in game order.
///
/// The one reading of „this move is worth teaching from". Extracted so the
/// trainer can be told how many there are before the words are paid for
/// (`mistakeCount`) without a second copy of the rule deciding a different
/// number from the one that becomes parts — this repository has already lost
/// three days to one subquery written out three times.
///
/// It has no counterpart in `skeleton.py`, which keeps the loop inline: the
/// harness has nobody to tell. The fixture gate proves the two still agree on
/// what comes out.
List<int> heavyIndices(List<Map<String, dynamic>> rows, double minCost) {
  final heavy = <int>[];
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final played = row['played'] as Map<String, dynamic>?;
    final candidates = row['candidates'] as List?;
    if (played != null && candidates != null && candidates.isNotEmpty) {
      if (costValue(played['cost_pawns']) >= minCost) {
        heavy.add(i);
      }
    }
  }
  return heavy;
}

/// How many moves of [facts] cost at least [minCost] pawns.
///
/// Cheap on purpose: it answers while a slider is being dragged, so it counts
/// rows and builds no part, no board and no sentence.
int mistakeCount(Map<String, dynamic> facts, double minCost) => heavyIndices(
      (facts['rows'] as List).cast<Map<String, dynamic>>(),
      minCost,
    ).length;

/// How many plies of [line] the answer part shows.
///
/// [SkeletonParameters.answerPlies] normally, but **never ending while the side
/// that played it is still down material**. The owner found why on 14.9.2026,
/// on „Punish, Count, Retreat": a line cut at four plies ended on a position
/// where White was better with no visible reason, because the piece had been
/// given and the point of giving it was the move after the cut.
///
/// Measured over the ten fixture games before it was written: 16 of 69 answer
/// parts ended with the mover down material, so it is about one in four rather
/// than a corner case, and the rule brings that to 7. On g01 the line
/// `g7 Qe8 h7+ Kxg7 h8=R Qxh8` runs 0, 0, 0, −1, +3, −2 — cut at four it stops
/// on „a pawn down", and one ply further it stops on the promotion, which is
/// the whole idea of the line. The seven that remain are lines whose
/// compensation is not material at all, and they run to the end of what is
/// stored.
///
/// Bounded by [SkeletonParameters.maxAnswerPlies] rather than by the line,
/// because the stored line is six plies today and this must not become „show
/// the whole engine PV" the day that changes.
/// Whether [mover] is ever behind where they started inside [sans].
///
/// „The best move is a sacrifice", asked of the line rather than of the first
/// move: on the ten fixture games not one best move gives material away
/// immediately, and 29 of 69 best lines do so somewhere inside the plies shown.
/// A rule that looked only at the first move would have been a rule that never
/// fired.
bool givesMaterial(String fen, String mover, List<String> sans) {
  final board = chess.Chess.fromFEN(fen);
  final sign = mover == 'White' ? 1 : -1;
  final start = sign * materialOf(board);
  for (final san in sans) {
    if (!board.move(san)) {
      throw StateError('$san cannot be played from ${board.fen}');
    }
    if (sign * materialOf(board) < start) return true;
  }
  return false;
}

int answerPlyCount(String fen, String mover, List<String> line,
    SkeletonParameters parameters) {
  if (line.isEmpty) return 0;
  final board = chess.Chess.fromFEN(fen);
  final sign = mover == 'White' ? 1 : -1;
  final start = sign * materialOf(board);
  final after = <int>[];
  for (final san in line) {
    // `move` answers false and leaves the board where it was, so an unchecked
    // call measures every later ply from the wrong position. python-chess's
    // `push_san` raises; so does this.
    if (!board.move(san)) {
      throw StateError('$san cannot be played from ${board.fen}');
    }
    after.add(sign * materialOf(board));
  }
  final cap = parameters.maxAnswerPlies < after.length
      ? parameters.maxAnswerPlies
      : after.length;
  var cut = parameters.answerPlies < cap ? parameters.answerPlies : cap;
  if (cut == 0) return 0;
  while (cut < cap && after[cut - 1] < start) {
    cut++;
  }
  return cut;
}

/// [level] of `standing` as the words a narration uses, from [side]'s view.
String stands(String side, int? level) {
  if (level == null) return 'the evaluation is unknown';
  if (level == 4) return '$side has a forced mate';
  if (level == -4) return '$side is getting mated';
  if (level == 0) return 'it is about even';
  final who = level > 0 ? side : _other(side);
  const names = ['slightly better', 'clearly better', 'winning'];
  return '$who is ${names[level.abs() - 1]}';
}

String _other(String side) => side == 'White' ? 'Black' : 'White';

String points(int n) =>
    n == 1 ? '1 point of material' : '$n points of material';

bool quickMate(String? evalText) =>
    evalText != null &&
    evalText.startsWith('#') &&
    int.parse(evalText.substring(1)).abs() <= 3;

/// Whether a shown line is material given for activity — `_sacrifice` in
/// `skeleton.py`.
///
/// Asked at the end of the line, never inside it: [answerPlyCount] already runs
/// a line on while its mover is behind, so a line still behind where it ends is
/// one whose compensation is not material — and the transient deficit inside
/// `d4 cxd4 exd4` is a trade in progress, which „ever behind" called a
/// sacrifice on the first draft of the rule (`docs/PLAN-NARACIJA.md`).
bool sacrifice(String fen, String mover, List<String> sans, String? endEval) {
  if (sans.isEmpty) return false;
  final board = chess.Chess.fromFEN(fen);
  final sign = mover == 'White' ? 1 : -1;
  final start = sign * materialOf(board);
  for (final san in sans) {
    if (!board.move(san)) {
      throw StateError('$san cannot be played from ${board.fen}');
    }
  }
  final end = standing(endEval, mover);
  return sign * materialOf(board) < start &&
      end != null &&
      end >= 0 &&
      !quickMate(endEval);
}

/// The turning points of a game, in game order, as facts a narration may say —
/// `game_story` in `skeleton.py`.
///
/// The owner's point of 14.9.2026: a comment's core is the swings — the first
/// mistake that hands one side a big advantage, a chance one side gives the
/// other and the other takes or misses, the last chance missed, and material
/// given for activity. Every event is read off the evaluations and the board,
/// so the model narrates it and cannot invent it.
///
/// Each event is `ply`, `kind`, `side` (whose event it is) and `text`.
List<Map<String, dynamic>> gameStory(List<Map<String, dynamic>> rows) {
  final events = <Map<String, dynamic>>[];
  var firstBig = false;
  final missed = <Map<String, dynamic>>[];

  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final played = row['played'] as Map<String, dynamic>?;
    final cands = row['candidates'] as List?;
    if (played == null || cands == null || cands.isEmpty) continue;
    final mover = row['to_move'] as String;
    final before = standing((cands[0] as Map)['eval'] as String?, mover);
    final after = standing(played['eval'] as String?, mover);
    if (before == null || after == null) continue;

    // Material for activity, among the game's own moves: the reply takes on
    // the square this move landed on, the side is still down against where it
    // stood after its own next move — so a trade half made is not a
    // sacrifice — and it is not worse for it, with no mate in three behind the
    // evaluation. Without the square „16. Kh1 gives up material" on g05: a
    // piece left loose earlier was taken after it.
    var takenThere = false;
    if (i + 1 < rows.length && rows[i + 1]['played'] != null) {
      final here = chess.Chess.fromFEN(row['fen'] as String);
      final landed = findMove(here, played['move'] as String).toAlgebraic;
      here.move(played['move'] as String);
      final reply =
          findMove(here, (rows[i + 1]['played'] as Map)['move'] as String);
      takenThere = reply.toAlgebraic == landed && isCapture(here, reply);
    }
    if (takenThere && i + 2 < rows.length && rows[i + 2]['played'] != null) {
      final sign = mover == 'White' ? 1 : -1;
      final thenPlayed = rows[i + 2]['played'] as Map<String, dynamic>;
      final later = chess.Chess.fromFEN(rows[i + 2]['fen'] as String)
        ..move(thenPlayed['move'] as String);
      final given = sign *
          (materialOf(later) -
              materialOf(chess.Chess.fromFEN(row['fen'] as String)));
      final then = standing(thenPlayed['eval'] as String?, mover);
      if (given <= -1 &&
          then != null &&
          then >= 0 &&
          !quickMate(thenPlayed['eval'] as String?)) {
        events.add({
          'ply': i,
          'kind': 'activity',
          'side': mover,
          'text': 'with ${played['label']} $mover gives up material, and two '
              'moves later is still ${points(-given)} behind and '
              '${stands(mover, then)} - material for activity',
        });
      }
    }

    if (!(after <= -2 && -2 < before)) continue;
    if (!firstBig) {
      firstBig = true;
      events.add({
        'ply': i,
        'kind': 'first_big_mistake',
        'side': mover,
        'text':
            '${played['label']} is the first mistake of the game that gives '
                'one side a big advantage: afterwards ${stands(mover, after)}',
      });
    }
    final next = i + 1 < rows.length ? rows[i + 1] : null;
    final nextPlayed = next?['played'] as Map<String, dynamic>?;
    final nextCands = next?['candidates'] as List?;
    if (next == null ||
        nextPlayed == null ||
        nextCands == null ||
        nextCands.isEmpty) {
      continue;
    }
    final nextMover = next['to_move'] as String;
    final reply = standing(nextPlayed['eval'] as String?, nextMover);
    if (reply == null) continue;
    final chance = _other(mover);
    final event = <String, dynamic>{
      'ply': i + 1,
      'kind': reply >= 2 ? 'chance_taken' : 'chance_missed',
      'side': chance,
      'text': '${played['label']} hands $chance a chance, and $chance '
          '${reply >= 2 ? 'takes' : 'misses'} it with ${nextPlayed['label']}: '
          'afterwards ${stands(nextMover, reply)}',
    };
    events.add(event);
    if (reply < 2) missed.add(event);
  }
  if (missed.isNotEmpty) {
    final last = missed.last;
    last['kind'] = 'last_chance_missed';
    last['text'] = (last['text'] as String).replaceFirst(' misses it with ',
        ' misses it - the last chance of the game given and not taken - with ');
  }
  // Stable, as Python's `sort` is.
  final ordered = [for (var k = 0; k < events.length; k++) (k, events[k])]
    ..sort((a, b) {
      final byPly = (a.$2['ply'] as int).compareTo(b.$2['ply'] as int);
      return byPly != 0 ? byPly : a.$1.compareTo(b.$1);
    });
  return [for (final e in ordered) e.$2];
}

const _tactical = [
  'fork', 'pin', 'skewer', 'hanging', 'attacked', 'defender', 'mate', //
  'discovered', 'overload', 'deflect', 'trapped', 'defended only',
];
const _positional = [
  'isolated', 'backward', 'doubled', 'weak', 'open file', 'open g-file', //
  'bishop pair', 'centre', 'passed', 'outpost', 'space', 'squares',
  'half-open', 'pawn chain',
];

/// What the first words may promise and the last words may say — `game_arc`
/// in `skeleton.py`.
///
/// The owner, 14.9.2026: the beginning should tell what kind of game is coming
/// and the end who won. The result is the board's (mate, stalemate) or the last
/// evaluation, because the Analysis export records no result, and a
/// resignation nobody recorded is not a fact. Counts are said per side, because
/// „4 turning points (2 chances missed)" was read as „two chances each side
/// lets slip".
Map<String, String> gameArc(List<Map<String, dynamic>> rows) {
  final events = gameStory(rows);
  final turns = events.where((e) => e['kind'] != 'activity').toList();
  final missed = events
      .where((e) =>
          e['kind'] == 'chance_missed' || e['kind'] == 'last_chance_missed')
      .toList();
  final bySide = {
    for (final side in const ['White', 'Black'])
      side: missed.where((e) => e['side'] == side).length,
  };
  var tactical = 0;
  var positional = 0;
  for (final row in rows) {
    final motifs = row['motifs_after_played'] as String? ?? '';
    for (final sentence in motifs.split(RegExp(r'(?<=[.])\s+'))) {
      final low = sentence.toLowerCase();
      if (_tactical.any(low.contains)) {
        tactical++;
      } else if (_positional.any(low.contains)) {
        positional++;
      }
    }
  }
  final played = rows.where((r) => r['played'] != null).toList();
  final last = rows.last;
  final board = chess.Chess.fromFEN(last['fen'] as String);
  final String result;
  final lastCands = last['candidates'] as List?;
  if (board.in_checkmate) {
    final white = board.turn == chess.Color.WHITE;
    result = '${white ? 'White' : 'Black'} is checkmated: '
        '${white ? 'Black' : 'White'} wins';
  } else if (board.in_stalemate) {
    result = 'stalemate: a draw';
  } else if (lastCands != null && lastCands.isNotEmpty) {
    result = 'no result is recorded; when the game stops, '
        '${wordsFor((lastCands[0] as Map)['eval'] as String?)}';
  } else {
    result = 'no result is recorded and the last position has no evaluation';
  }
  final named = [
    for (final r in rows)
      if (r['book'] is Map && (r['book'] as Map)['opening'] != null)
        (r['book'] as Map)['opening'] as String
  ];
  final kind = tactical >= 2 * positional
      ? 'mostly tactical'
      : positional > tactical
          ? 'mostly positional'
          : 'tactical and positional in turn';
  final missedWords = missed.isEmpty
      ? 'none'
      : [
          for (final entry in bySide.entries)
            if (entry.value > 0) '${entry.key} missed ${entry.value}'
        ].join(', ');
  final character = '${(played.length + 1) ~/ 2} moves; ${turns.length} '
      'turning points in all; chances missed: $missedWords; the motif sentences '
      'of the game are $tactical tactical and $positional positional - $kind';
  final opening = 'before the first move: $character'
      '${named.isNotEmpty ? '; the opening is the ${named.last}' : ''}. The '
      'program names the opening right after this, so do not name it. In one or '
      'two sentences tell the student what kind of game is coming - quiet or '
      'full of turns, a tactical or a positional fight - and what to watch for, '
      'without saying who wins and without naming a move.';
  final lastLabel = played.isNotEmpty
      ? (played.last['played'] as Map)['label'] as String
      : 'no moves';
  final ending = 'after the last move ($lastLabel): $result; '
      '${turns.isNotEmpty ? 'the last turning point: ${turns.last['text']}' : 'nothing in the story changed who stands better'}. '
      'In one sentence end the story: who came out on top and what decided it, '
      'from the story of the game. Do not invent a resignation, a clock or a '
      'result that is not here.';
  return {'opening': opening, 'ending': ending};
}

List<Map<String, dynamic>> skeletonMoments(
  Map<String, dynamic> facts, {
  SkeletonParameters parameters = const SkeletonParameters(),
}) {
  final rows = (facts['rows'] as List).cast<Map<String, dynamic>>();
  final story = gameStory(rows);

  final heavy = heavyIndices(rows, parameters.minCost);

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
      // „The board just before these moves, with Black to play. Material is
      // level." — the owner, 14.9.2026: a sentence with no meaning to a
      // listener, faithfully made of the fact this slot used to carry.
      final startCands = rows[start]['candidates'] as List?;
      final startEval = startCands != null && startCands.isNotEmpty
          ? (startCands[0] as Map)['eval'] as String?
          : null;
      final materialWords = before == 0
          ? 'material is level'
          : '${before > 0 ? 'White' : 'Black'} is ${points(before.abs())} up';
      slots[intro] =
          'the scene, a few moves before the moment: ${rows[start]['to_move']} to move, ${wordsFor(startEval)}, $materialWords. Say in one sentence where the fight stands here - who is pressing and what the game is about - so the moves after it are heard as part of the story. Do not describe the board, count material or say what is about to be played.';
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
    final moves = <Map<String, dynamic>>[];
    final lineSans = (best['line'] as String)
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
    final lineMoves = lineSans
        .take(answerPlyCount(row['fen'] as String, mover, lineSans, parameters))
        .toList();
    for (var k = 1; k <= lineMoves.length; k++) {
      final san = lineMoves[k - 1];
      final sid = '$mid.answer.$k';
      final info = playMoveOnBoard(board, san);
      // A move of the best line did not happen, and the slot says so in its
      // own words — a student met „Black plays Qf6 instead of the game move
      // bxa3" and, one click later, „Black plays Qf6 … this is the best move".
      //
      // **Not „the best line goes on".** That phrase was written here as a
      // fact and came back out of the model as a sentence, on every ply of
      // every answer line — „Black would answer Ra7. Not played either; best
      // line goes on." The owner read it on 15.9.2026 and asked for it to
      // stop. A fact a model has nothing to add to is a fact it repeats, so
      // the marker is the two words the prompt's rule keys on and nothing
      // more; the prompt now also says that a move with nothing to tell gets
      // an empty slot rather than a sentence about the line continuing.
      var text =
          '${info['words']}${k == 1 ? '; the best move, which the game did not play' : '; not played'}';
      final bestEval = best['eval'] as String?;
      if (k == 1 &&
          sacrifice(row['fen'] as String, mover, lineMoves, bestEval)) {
        text +=
            '; this line gives material for activity: at its end $mover is still material down and ${stands(mover, standing(bestEval, mover))}, and not because of a quick mate';
      }
      slots[sid] = text;
      slotFacts[sid] = {
        ...info,
        'motifs': '',
      };
      moves.add({'san': san, 'slot': sid});
    }
    // **The owner's order at a mistake**, 14.9.2026: first what was played —
    // drawn as a blue arrow and not played — then „The best move was…", and
    // only then the line, in a part of its own. The program says it; the model
    // is not asked to, and the answer part has no introduction.
    final fork = '$mid.fork';
    final playedMove = findMove(
        chess.Chess.fromFEN(row['fen'] as String), played['move'] as String);
    final program = <String, String>{
      fork: 'In this position $mover played ${played['move']}. '
          'The best move was…',
    };
    parts.add({
      'kind': 'show',
      'fen': row['fen'],
      'intro': fork,
      'moves': <Map<String, dynamic>>[],
      'program': true,
      'arrow': [playedMove.fromAlgebraic, playedMove.toAlgebraic],
    });
    // Marked, not inferred from the slot ids: what follows this part is the
    // game again, and the student has to be told so.
    parts.add({
      'kind': 'show',
      'fen': row['fen'],
      'intro': null,
      'moves': moves,
      'sideline': true,
    });

    // **And what the next-best move does instead, where the best one gives
    // something up.** The owner asked for it on 14.9.2026, and asked for it
    // scoped: „kad je žrtva opravdana i najbolji potez". Written first for
    // every moment with a worse alternative, it fired on 67 of the 69 fixture
    // moments — a second part on almost every answer, which is not what was
    // asked and doubles what a child reads. Gated on the best line actually
    // giving material up it is 29 of 69, which is the question a child really
    // has there: why give that, and what was wrong with keeping it.
    //
    // `correct` is every candidate within `near` of the best, so the one after
    // it is the best move that is **clearly** worse — the first it would be
    // true to call a second choice. Anything inside `correct` is as good, and
    // calling it the lesser move would be a sentence the facts do not bear out.
    //
    // **A part of its own, not a variation of the answer part.** The child's
    // viewer breaks the narrated walk at a fork and asks them to choose
    // (`lesson_viewer_screen.dart`), so a variation here would stop „Pusti
    // tutorijal" at the very moment the answer is being shown, and offer a
    // choice between the right move and a worse one with nothing said yet
    // about either. The film ignores variations too — its beats follow the
    // spine — so as a variation this would be invisible in every exported
    // video. As a part it is read, spoken and filmed like any other.
    final others = candidates.skip(correct.length).toList();
    if (others.isNotEmpty &&
        givesMaterial(row['fen'] as String, mover, lineMoves)) {
      final other = others.first;
      final otherSans = (other['line'] as String)
          .split(RegExp(r'\s+'))
          .where((token) => token.isNotEmpty)
          .toList();
      final otherShown =
          answerPlyCount(row['fen'] as String, mover, otherSans, parameters);
      if (otherShown > 0) {
        final otherBoard = chess.Chess.fromFEN(row['fen'] as String);
        final otherMoves = <Map<String, dynamic>>[];
        for (var k = 1; k <= otherShown; k++) {
          final san = otherSans[k - 1];
          final sid = '$mid.other.$k';
          final info = playMoveOnBoard(otherBoard, san);
          slots[sid] =
              '${info['words']}${k == 1 ? '; the next best move, and not as good as ${best['move']}' : '; not played'}';
          slotFacts[sid] = {...info, 'motifs': ''};
          otherMoves.add({'san': san, 'slot': sid});
        }
        final otherIntro = '$mid.other.intro';
        slots[otherIntro] =
            'the other line: the next best move here is not as good as ${best['move']}. At the end of it ${wordsFor(other['eval'] as String?)}, against ${wordsFor(best['eval'] as String?)} at the end of the best line. Say that there was a second choice and that it is weaker, in one sentence, without naming it - the move after this sentence names it.';
        slotFacts[otherIntro] = {
          'gain': 0,
          'mate': false,
          'fork': false,
          'pin': false,
          'motifs': '',
        };
        parts.add({
          'kind': 'show',
          'fen': row['fen'],
          'intro': otherIntro,
          'moves': otherMoves,
          'sideline': true,
          'alternative': true,
        });
      }
    }

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
      'program': program,
      'events': [
        for (final e in story)
          if (e['ply'] == i) e['text']
      ],
    });
  }

  final turning = decisiveMoment(out, rows);
  for (final m in out) {
    m['turning_point'] = m['id'] == turning;
  }
  return out;
}

/// Whether the move at [i] changed who stands better.
bool changedHands(List<Map<String, dynamic>> rows, int i) {
  final row = rows[i];
  final mover = row['to_move'] as String;
  final bestEval = (row['candidates'] as List).first['eval'] as String?;
  final playedEval = (row['played'] as Map)['eval'] as String?;
  return mistakeKind(standing(bestEval, mover), standing(playedEval, mover)) !=
      null;
}

/// Which of [moments] the game turned on, by id; null when it is empty.
///
/// Whether the move changed who stands better comes before what it cost,
/// because a game already lost collects expensive blunders that decide
/// nothing — on g01 a move costing a forced mate is passed over for one costing
/// 2.11 pawns, because the first was played from a position already lost and
/// the second is where it was lost. [mistakeKind] is that question and is not
/// asked a second way here: it is the same classifier the filler's lexicon
/// uses, so the sentence the student reads at that move and the moment called
/// decisive cannot disagree. Ties go to the earlier move.
///
/// Asked twice of two different lists, which is the point of it being a
/// function. [skeletonMoments] marks the decisive moment **of the game**,
/// before the model has chosen anything, so the prompt can weight it;
/// `wholeGame` asks again of the moments the model actually chose, so the recap
/// at the end is the most decisive part of the tutorial that exists rather than
/// nothing at all when the model passed the marked one over.
String? decisiveMoment(
    List<Map<String, dynamic>> moments, List<Map<String, dynamic>> rows) {
  if (moments.isEmpty) return null;
  Map<String, dynamic>? best;
  var bestKey = (false, 0.0, 0);
  for (final m in moments) {
    final index = m['index'] as int;
    final key = (changedHands(rows, index), costValue(m['cost']), -index);
    if (best == null ||
        (key.$1 ? 1 : 0) > (bestKey.$1 ? 1 : 0) ||
        (key.$1 == bestKey.$1 &&
            (key.$2 > bestKey.$2 ||
                (key.$2 == bestKey.$2 && key.$3 > bestKey.$3)))) {
      best = m;
      bestKey = key;
    }
  }
  return best!['id'] as String;
}
