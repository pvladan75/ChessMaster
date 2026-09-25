import 'dart:convert';

import 'package:chess/chess.dart' as chess;
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/studio_lesson_step.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/board_queries.dart'
    show findMove;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/evaluation_words.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_moments.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_parameters.dart';
import 'package:chess_app/move_tree.dart' show ChessArrow;

const String kGameTitle = ' (whole game)';

const Map<String, List<String>> kLexicon = {
  // Said where the game picks up straight after a sideline and the move that
  // carries it already has words of its own — a moment's lead-in, in either
  // mode. Short, because it is a prefix and not the sentence.
  'back_to_game': [
    'Back to the game.',
    'Now back to the game as it was played.',
    'Returning to the moves of the game.',
  ],
  // Where the game picks up again on a moment's own board. The story voice
  // (docs/PLAN-NARACIJA.md): the same facts, told.
  'resumed': [
    'Back in the game, {mover} played {move}, and {after}.',
    'Returning to the game, {mover} chose {move}, and {after}.',
    'But the game went on with {move}, and {after}.',
  ],
  'story_first_big_mistake': [
    'This is the first mistake of the game that hands one side a big advantage.',
  ],
  'story_chance_taken': [
    '{mover} takes the chance.',
    'And {mover} does not let the chance go.',
  ],
  'story_chance_missed': [
    '{mover} lets the chance go.',
    'The chance was there, and {mover} misses it.',
  ],
  'story_last_chance_missed': [
    'That was the last chance of the game, and {mover} lets it go.',
  ],
  'story_activity': [
    '{mover} is down material, and has activity for it.',
  ],
  'advantage_gone': [
    'This lets the advantage go.',
    'The advantage is gone after this move.',
    'This throws the advantage away.',
  ],
  'opponent_better': [
    'This hands the opponent the better game.',
    'After this, the opponent has the better position.',
    'This gives the opponent the upper hand.',
  ],
  'opponent_winning': [
    'A serious mistake: from here the opponent is winning.',
    'A serious mistake, and it leaves the opponent winning.',
    'This is the move that leaves the opponent winning.',
  ],
  'misses_mate': [
    'This misses a forced mate.',
    'There was a forced mate here, and this move misses it.',
    'This lets a forced mate slip away.',
  ],
};

class SkeletonAssembly {
  const SkeletonAssembly({
    required this.report,
    required this.tutorial,
    required this.tutorialGame,
  });

  final Map<String, dynamic> report;
  final Map<String, dynamic>? tutorial;
  final Map<String, dynamic>? tutorialGame;
}

String stampOf(Map<String, dynamic> facts) =>
    '${facts['game']} d${facts['depth']} mpv${facts['multipv']} ${facts['generated']}';

String cleanText(Object? text) {
  final str = (text == null || text == '') ? '' : text.toString();
  final replaced = str.replaceAll('{', '(').replaceAll('}', ')');
  return replaced.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String bookSummary(List<dynamic> rows) {
  final named = <String>[];
  for (final r in rows) {
    if (r is Map && r['book'] is Map && (r['book'] as Map)['opening'] != null) {
      named.add((r['book'] as Map)['opening'] as String);
    }
  }
  Map<String, dynamic>? left;
  for (final r in rows) {
    if (r is Map &&
        r['played'] is Map &&
        (r['played'] as Map)['left_book'] == true) {
      left = r.cast<String, dynamic>();
      break;
    }
  }
  if (named.isEmpty && left == null) return '';
  final said = <String>[];
  if (named.isNotEmpty) {
    said.add('The opening is the ${named.last}');
  }
  if (left != null) {
    final book = left['book'] as Map<String, dynamic>;
    final games = book['games'] as int;
    final playedLabel = (left['played'] as Map<String, dynamic>)['label'];
    said.add(
      '$playedLabel left the masters database: $games master game${games == 1 ? '' : 's'} had reached that position and not one played it',
    );
  } else if (named.isNotEmpty) {
    said.add('the game never left the masters database');
  }
  return '${said.join('. ')}.';
}

/// A move in notation inside a sentence: a piece move, a capture, castling. A
/// plain pawn push is left out on purpose — „the pawn on e4" is a square, and
/// the text cannot tell the two apart.
final _sanInText = RegExp(
  r'\b([KQRBN][a-h]?[1-8]?x?[a-h][1-8][+#]?|[a-h]x[a-h][1-8][+#]?|O-O(?:-O)?)\b',
);

String _bareSan(String san) => san.replaceAll(RegExp(r'[+#]+$'), '');

List<String> claimsFor(
  String sid,
  String text,
  Map<String, dynamic> facts, [
  String context = '',
]) {
  final found = <String>[];
  // A story carries a pin or a mate from one slot to the next, and a check
  // reading one slot at a time flagged „the pin is broken" on the move after
  // the pin (round one of docs/PLAN-NARACIJA.md). What was shown for the moment
  // so far — [context] — backs a word too; and a word said not to be there
  // („no mate") is not a claim that it is.
  final low = text.toLowerCase().replaceAll(
      RegExp(r"\b(no|not|without|never|isn't|is no longer)\b[^.,;]{0,24}"),
      ' ');
  final shown = ('${facts['text'] ?? ''} ${facts['motifs'] ?? ''} $context')
      .toLowerCase();

  if (RegExp(r'[+-]\d+\.\d+|\b\d+\.\d+\b').hasMatch(text)) {
    found.add('$sid prints an evaluation');
  }

  final hasWin = RegExp(r'\b(win|wins|won|winning a)\b').hasMatch(low);
  final gain = facts['gain'] as num? ?? 0;
  final mate = facts['mate'] == true;
  final question = facts['question'] == true;
  if (hasWin &&
      !low.contains('winning') &&
      gain == 0 &&
      !mate &&
      !question &&
      !shown.contains('winning') &&
      !shown.contains(' mates in ')) {
    found.add('$sid says a move wins, and the facts show no material won');
  }

  if (RegExp(r'\b(checkmate|mates|mate)\b').hasMatch(low) &&
      !mate &&
      !shown.contains('mate') &&
      !question) {
    found.add('$sid speaks of mate, and the facts of that slot have none');
  }

  final fork = facts['fork'] == true;
  if (low.contains('fork') && !fork && !shown.contains('fork')) {
    found.add('$sid names a fork the facts do not show');
  }

  final pin = facts['pin'] == true;
  if (RegExp(r'\bpin').hasMatch(low) && !pin && !shown.contains('pin')) {
    found.add('$sid names a pin the facts do not show');
  }

  for (final entry in const [
    ('skewer', 'skewer'),
    ('discover', 'discover'),
    ('trapped', 'trap'),
  ]) {
    if (low.contains(entry.$1) && !shown.contains(entry.$2)) {
      found.add('$sid names a ${entry.$1} the facts do not show');
    }
  }

  final squareMatches =
      RegExp(r'\b(?:to|on to|onto)\s+([a-h][1-8])\b').allMatches(low);
  final squares = {for (final m in squareMatches) m.group(1)!};
  final to = facts['to'] as String?;
  if (to != null &&
      to.isNotEmpty &&
      squares.isNotEmpty &&
      !squares.contains(to)) {
    final sortedSquares = squares.toList()..sort();
    found.add(
      '$sid says a piece goes to ${sortedSquares.join(', ')}, and this move goes to $to',
    );
  }

  // The third mode (docs/PLAN-ZAGONETKE-IZ-PARTIJE.md, §3a and phase 3): a
  // review's comment and a puzzle's explanation are not questions, so a move
  // they name is refused unless it is in the moment's own lines — the game's
  // move, the better line, the refutation and the second line.
  final lines = facts['lines'];
  if (lines is List) {
    final allowed = {for (final m in lines) _bareSan(m.toString())};
    final outside = <String>{
      for (final m in _sanInText.allMatches(text))
        if (!allowed.contains(_bareSan(m.group(0)!))) m.group(0)!,
    };
    if (outside.isNotEmpty) {
      final sortedOutside = outside.toList()..sort();
      found.add(
        '$sid names ${sortedOutside.join(', ')}, a move not in its lines',
      );
    }
  }

  if (question) {
    final names =
        (facts['names'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final rawAnswer = names.isNotEmpty ? names[0] : '';
    final answer = _bareSan(rawAnswer);
    final sqName = names.length > 1 ? names[1] : '';
    if ((answer.isNotEmpty && text.contains(answer)) ||
        (sqName.isNotEmpty && low.contains(sqName))) {
      found.add('$sid names its answer or its square');
    }
    final others = <String>{};
    for (final m in _sanInText.allMatches(text)) {
      final matched = m.group(0)!;
      if (_bareSan(matched) != answer) {
        others.add(matched);
      }
    }
    if (others.isNotEmpty) {
      final sortedOthers = others.toList()..sort();
      found.add(
        '$sid names ${sortedOthers.join(', ')}, a move that is not the answer',
      );
    }
  }

  return found;
}

String pickLexicon(String pool, Map<String, int> used) {
  final n = used[pool] ?? 0;
  used[pool] = n + 1;
  final options = kLexicon[pool]!;
  return options[n % options.length];
}

String fillerWords(
  List<Map<String, dynamic>> rows,
  int r,
  SkeletonParameters parameters,
  bool resumed,
  Map<String, int> used, [
  List<Map<String, dynamic>> events = const [],
]) {
  final row = rows[r];
  final played = row['played'] as Map<String, dynamic>;
  final mover = row['to_move'] as String;
  final eval = played['eval'] as String?;
  final said = <String>[];

  if (resumed) {
    said.add(
      pickLexicon('resumed', used)
          .replaceAll('{mover}', mover)
          .replaceAll('{move}', played['move'] as String)
          .replaceAll('{after}', stands(mover, standing(eval, mover))),
    );
  } else if ((played['judged'] as Map?)?['mistake'] == true &&
      row['candidates'] != null &&
      (row['candidates'] as List).isNotEmpty) {
    final candidates = row['candidates'] as List;
    final best = candidates[0]['eval'] as String?;
    final kind = mistakeKind(standing(best, mover), standing(eval, mover));
    if (kind != null) {
      // „White plays b4. This hands the opponent the better game. With the
      // best move: about even. After this one: Black is slightly better." was
      // the driest sentence of every tutorial; the board plays b4.
      said.add(
        '${pickLexicon(kind, used)} Now ${stands(mover, standing(eval, mover))}.',
      );
    }
  }
  // The turning points the model did not narrate, said where they happened.
  for (final event in events) {
    said.add(pickLexicon('story_${event['kind']}', used)
        .replaceAll('{mover}', mover));
  }

  return said.join(' ');
}

/// The arrows of one node: blue for a move that was played, green for the
/// moves masters play.
///
/// Two colours because they answer two different questions, and the student
/// meets both on one board at the departure from the book: „this is what was
/// played" and „this is what the database plays".
List<ChessArrow> drawnArrows(List? played, List? masters) => [
      // Blue, the owner's choice for „what was played here" (14.9.2026).
      if (played != null)
        ChessArrow(
            from: played[0] as String, to: played[1] as String, colorCode: 'B'),
      for (final a in (masters ?? const []))
        ChessArrow(
            from: (a as List)[0] as String, to: a[1] as String, colorCode: 'G'),
    ];

String pgnForPart(Map<String, dynamic> part, Map<String, dynamic> words) {
  final fen = part['fen'] as String;
  final introKey = part['intro'] as String?;
  final rootComment =
      (introKey != null ? (words[introKey] as String?) : null) ?? '';
  final root = AnalysisNode(
    fen: fen,
    comment: rootComment,
    arrows: drawnArrows(part['arrow'] as List?, part['arrows'] as List?),
  );
  var parent = root;
  final board = chess.Chess.fromFEN(fen);
  final moves = (part['moves'] as List?) ?? const [];
  for (final mv in moves) {
    final san = mv['san'] as String;
    // `move` answers false and leaves the board where it was, so an unchecked
    // call writes every later position from the wrong board without a word.
    // python-chess's `parse_san` raises; so does this.
    if (!board.move(san)) {
      throw StateError('$san cannot be played from ${board.fen}');
    }
    final slotKey = mv['slot'] as String;
    final comment = (words[slotKey] as String?) ?? '';
    final node = AnalysisNode(
      fen: board.fen,
      moveSan: san,
      comment: comment,
      parent: parent,
      arrows: drawnArrows(null, mv['arrows'] as List?),
    );
    parent.children.add(node);
    parent = node;
  }
  return StudioLessonStep.from(root).pgn;
}

List<Map<String, dynamic>> stepsFor(
  List<Map<String, dynamic>> parts,
  Map<String, dynamic> words,
) {
  final steps = <Map<String, dynamic>>[];
  for (final part in parts) {
    final kind = part['kind'] as String;
    final step = <String, dynamic>{
      'title': 'Part ${steps.length + 1}',
      'fen': part['fen'],
      'kind': kind,
    };
    if (kind == 'show') {
      step['pgn'] = pgnForPart(part, words);
    } else {
      final instKey = part['instruction'] as String?;
      step['instruction'] = (instKey != null ? words[instKey] : null) ?? '';
      step['solutionSan'] = part['solution'];
      final accepted = part['accepted'] as List?;
      if (accepted != null && accepted.isNotEmpty) {
        step['acceptedSans'] = accepted;
      }
      step['pgn'] = '';
    }
    steps.add(step);
  }
  return steps;
}

/// The first slot of [part] the student actually reads words from.
///
/// A part is read introduction, then question, then move by move; an empty slot
/// is read as nothing at all, so it is skipped rather than written into.
String? firstTextKey(Map<String, dynamic> part, Map<String, dynamic> words) {
  final keys = <String>[
    if (part['intro'] != null) part['intro'] as String,
    if (part['instruction'] != null) part['instruction'] as String,
    for (final mv in (part['moves'] as List? ?? const []))
      (mv as Map)['slot'] as String,
  ];
  for (final key in keys) {
    if ((words[key] as String? ?? '').trim().isNotEmpty) return key;
  }
  return keys.isEmpty ? null : keys.first;
}

/// „Back to the game" wherever the game resumes straight after a sideline.
///
/// The answer part is a line that was **not** played, and the part after it is
/// the game again — a change of footing the student was never told about. In
/// whole-game mode the filler already says it (`resumed`), but only where a
/// filler exists: two mistakes close together leave none, because the second
/// moment's lead-in reaches back past the first, and then the game resumed with
/// no word at all. In key-moments mode there is no filler ever, so it was
/// missing at every join. The owner asked for it on 14.9.2026, having seen both
/// halves of one tutorial; measured over the ten harness games, whole-game mode
/// was short one bridge in four of them and key-moments mode had none in any.
///
/// Written here rather than asked of the model, and rotated through three
/// wordings rather than fixed, because the same sentence three times in one
/// tutorial is what a reader stops seeing.
///
/// A part that already carries a `resumed` sentence is left alone: that
/// sentence says the same thing and says it with the move.
Map<String, dynamic> bridged(
  List<Map<String, dynamic>> parts,
  Map<String, dynamic> words,
  Map<String, int> used,
) {
  final out = Map<String, dynamic>.of(words);
  var afterSideline = false;
  for (final part in parts) {
    if (afterSideline && part['sideline'] != true && part['resumed'] != true) {
      final key = firstTextKey(part, out);
      if (key != null) {
        final said = (out[key] as String? ?? '').trim();
        out[key] = '${pickLexicon('back_to_game', used)} $said'.trim();
      }
    }
    afterSideline = part['sideline'] == true;
  }
  return out;
}

/// The story's first words before the first part, its last after the last —
/// `_framed` in `skeleton.py`.
///
/// The owner, 14.9.2026: the beginning should say what kind of game is coming
/// and the end who came out on top, where the tutorial said only „The game
/// ended here".
Map<String, dynamic> framed(
  List<Map<String, dynamic>> parts,
  Map<String, dynamic> words,
  Map<String, dynamic> given,
) {
  final out = Map<String, dynamic>.of(words);
  if (parts.isEmpty) return out;
  final opening = given['story.opening'] as String?;
  final ending = given['story.ending'] as String?;
  if (opening != null && opening.isNotEmpty) {
    final first = parts.first;
    final key = (first['intro'] as String?) ?? firstTextKey(first, out);
    if (key != null) {
      final said = (out[key] as String? ?? '').trim();
      out[key] = '$opening $said'.trim();
    }
  }
  if (ending != null && ending.isNotEmpty) {
    final last = parts.last;
    final moves = (last['moves'] as List?) ?? const [];
    final keys = moves.isNotEmpty
        ? [for (final mv in moves) (mv as Map)['slot'] as String]
        : [
            for (final k in [last['intro'], last['instruction']])
              if (k != null) k as String
          ];
    if (keys.isNotEmpty) {
      final said = (out[keys.last] as String? ?? '')
          .replaceAll('The game ended here.', '')
          .trim();
      out[keys.last] = '$said $ending'.trim();
    }
  }
  return out;
}

/// Where the game stopped following the masters, said on the last position that
/// really was in the database — `_masters_departure` in `skeleton.py`.
///
/// The sentence used to be [fillerWords]' last line, written onto the move that
/// left the book — which in PGN is the comment on the position *after* it. So a
/// student stood on a position no master game had ever reached and read „698
/// master games reached this position and none played it". The owner read it on
/// 15.9.2026 and asked for the statistic to be written where it is true: on the
/// position before the move, together with the moves the database does play
/// there, drawn as arrows.
///
/// The three arrows and the three names are the same three moves
/// (`book['alternatives']`, already capped at three by [applyMastersBook]),
/// because a list of names with no arrows is a list a listener cannot follow
/// and an arrow with no name is a line nobody can look up.
///
/// [parts] is written back into rather than mutated through: a moment's parts
/// are shared with the key-moments tutorial, which was assembled before this
/// runs.
///
/// Returns the row index the sentence was written at, or null.
int? mastersDeparture(
  List<Map<String, dynamic>> parts,
  Map<String, dynamic> words,
  List<Map<String, dynamic>> rows,
) {
  int? r;
  for (var i = 0; i < rows.length; i++) {
    final played = rows[i]['played'] as Map<String, dynamic>?;
    if (played != null &&
        played['left_book'] == true &&
        rows[i]['book'] != null) {
      r = i;
      break;
    }
  }
  if (r == null) return null;
  final row = rows[r];
  final book = row['book'] as Map<String, dynamic>;
  final games = book['games'] as int;
  final reached = games == 1 ? '1 master game' : '$games master games';
  final alternatives = (book['alternatives'] as List?) ?? const [];
  final played = alternatives.isEmpty
      ? ''
      : ' and played ${[
          for (final a in alternatives)
            '${a['move']} ${shareWords(a['share'] as num)}'
        ].join(', ')}';
  final sentence =
      'Up to here the game followed the masters database: $reached reached '
      'this position$played. ${row['to_move']} played '
      '${(row['played'] as Map<String, dynamic>)['move']}, which none of them '
      'did.';

  final board = chess.Chess.fromFEN(row['fen'] as String);
  final arrows = <List<String>>[
    for (final a in alternatives)
      () {
        final move = findMove(board, a['move'] as String);
        return [move.fromAlgebraic, move.toAlgebraic];
      }()
  ];

  for (var index = 0; index < parts.length; index++) {
    final part = parts[index];
    final moves =
        (part['moves'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    var at = -1;
    for (var i = 0; i < moves.length; i++) {
      if (moves[i]['ply'] == r) {
        at = i;
        break;
      }
    }
    if (at < 0) continue;
    final String slot;
    if (at > 0) {
      // The move before it: its comment is read on the position the departing
      // move is about to be played from.
      slot = moves[at - 1]['slot'] as String;
      final fresh = List<Map<String, dynamic>>.of(moves);
      if (arrows.isNotEmpty) {
        fresh[at - 1] = {...fresh[at - 1], 'arrows': arrows};
      }
      parts[index] = {...part, 'moves': fresh};
    } else {
      // It is the part's first move, so that position is the part's own board
      // and the sentence belongs to the root.
      slot = (part['intro'] as String?) ?? 'game.book.$r';
      parts[index] = {
        ...part,
        'intro': slot,
        if (arrows.isNotEmpty) 'arrows': arrows,
      };
    }
    words[slot] = [words[slot] as String?, sentence]
        .where((t) => t != null && t.isNotEmpty)
        .join(' ')
        .trim();
    return r;
  }
  return null;
}

/// The decisive part again, with a closing sentence.
Map<String, dynamic>? recapPart(
  List<(Map<String, dynamic>, List<Map<String, dynamic>>)> blocks,
  Map<String, dynamic> words,
  List<Map<String, dynamic>> rows,
) {
  final chosen = decisiveMoment([for (final (m, _) in blocks) m], rows);
  for (final (moment, mparts) in blocks) {
    if (moment['id'] != chosen) continue;
    final answer = mparts
        .where((p) => p['sideline'] == true && p['alternative'] != true)
        .firstOrNull;
    if (answer == null || (answer['moves'] as List?)?.isEmpty != false) {
      return null;
    }
    // No pawns counted aloud, and the move played drawn again as it was at the
    // moment itself.
    words['recap.intro'] = 'Looking back, the game turned on '
        '${moment['played']}. This is what was there instead.';
    final fork = mparts.where((p) => p['arrow'] != null).firstOrNull;
    return {
      'kind': 'show',
      'fen': answer['fen'],
      'intro': 'recap.intro',
      'moves': answer['moves'],
      'sideline': true,
      'moment': moment['id'],
      'arrow': fork?['arrow'],
    };
  }
  return null;
}

(List<Map<String, dynamic>>, Map<String, dynamic>, Map<String, dynamic>)
    wholeGame(
  List<Map<String, dynamic>> rows,
  List<(Map<String, dynamic>, List<Map<String, dynamic>>)> blocks,
  Map<String, dynamic> given,
  SkeletonParameters parameters,
) {
  var end = 0;
  for (final row in rows) {
    if (row['played'] != null) end++;
  }
  for (var r = 0; r < end; r++) {
    if (rows[r]['played'] == null) {
      throw ArgumentError('a row inside the game has no move played');
    }
  }

  final words = Map<String, dynamic>.of(given);
  final story = gameStory(rows);
  final parts = <Map<String, dynamic>>[];
  final lexiconUsed = <String, int>{};
  String? reportRecap;
  var fillerParts = 0;
  var fillerMoves = 0;
  var fillerSentences = 0;

  Map<String, dynamic>? fill(int start, int stop) {
    if (start >= stop) return null;
    final board = chess.Chess.fromFEN(rows[start]['fen'] as String);
    final intro = 'game.$start.intro';
    if (start == 0) {
      final named = <String>[];
      for (final row in rows) {
        if (row['book'] is Map && (row['book'] as Map)['opening'] != null) {
          named.add((row['book'] as Map)['opening'] as String);
        }
      }
      if (named.isNotEmpty) {
        words[intro] = 'The opening is the ${named.last}.';
      }
    }

    final moves = <Map<String, dynamic>>[];
    for (var r = start; r < stop; r++) {
      final san = rows[r]['played']['move'] as String;
      final sid = 'game.$r';
      var text = fillerWords(
        rows,
        r,
        parameters,
        r == start && start > 0,
        lexiconUsed,
        [
          for (final e in story)
            if (e['ply'] == r) e
        ],
      );
      board.move(san);
      if (r == end - 1) {
        final endPhrase = board.in_checkmate
            ? 'Checkmate.'
            : (board.in_stalemate ? 'Stalemate.' : 'The game ended here.');
        text = ('$text $endPhrase').trim();
      }
      if (text.isNotEmpty) {
        words[sid] = text;
        fillerSentences++;
      }
      moves.add({'san': san, 'slot': sid, 'ply': r});
    }

    fillerMoves += moves.length;
    if (words.containsKey(intro)) {
      fillerSentences++;
    }

    return {
      'kind': 'show',
      'fen': rows[start]['fen'],
      'intro': intro,
      'moves': moves,
      'resumed': start > 0,
    };
  }

  var cursor = 0;
  var merged = 0;
  for (final (moment, mparts) in blocks) {
    var workingParts = List<Map<String, dynamic>>.of(mparts);
    final first = workingParts[0];
    final firstMoves = (first['moves'] as List).cast<Map<String, dynamic>>();
    final stop = first['lead'] == true
        ? firstMoves[0]['ply'] as int
        : moment['index'] as int;
    final filler = fill(cursor, stop);
    if (filler != null && first['lead'] == true) {
      final fillerMovesList =
          (filler['moves'] as List).cast<Map<String, dynamic>>();
      final lastSlot = fillerMovesList.last['slot'] as String;
      final firstIntro = first['intro'] as String?;
      final joined = [
        words[lastSlot] as String?,
        if (firstIntro != null) words[firstIntro] as String?,
      ].where((t) => t != null && t.isNotEmpty).join(' ');
      if (joined.isNotEmpty) {
        words[lastSlot] = joined;
      }
      final newFirst = {
        ...first,
        'fen': filler['fen'],
        'intro': filler['intro'],
        'moves': [...fillerMovesList, ...firstMoves],
        'resumed': filler['resumed'],
      };
      workingParts = [newFirst, ...workingParts.sublist(1)];
      merged++;
    } else if (filler != null) {
      parts.add(filler);
      fillerParts++;
    }
    parts.addAll(workingParts);
    cursor = moment['index'] as int;
  }

  final filler = fill(cursor, end);
  if (filler != null) {
    parts.add(filler);
    fillerParts++;
  }

  // **The moment the game turned, once more at the end** — point 8 of the
  // owner's live pass, 14.9.2026, and whole-game mode only: in key-moments mode
  // the tutorial is short enough that the recap would repeat a part the student
  // has just read.
  //
  // The same position and the same line, so the words are the ones already
  // written for it and nothing new is asked of the model; only the sentence
  // that frames it is new, and that is written here rather than asked for.
  final recap = recapPart(blocks, words, rows);
  if (recap != null) {
    parts.add(recap);
    reportRecap = recap['moment'] as String;
  }

  final leftBookAt = mastersDeparture(parts, words, rows);

  // The recap is the last part, and the story ends on the game's own last move
  // rather than on a line that was never played.
  final bridgedWords = framed(
    [
      for (final p in parts)
        if (p['moment'] == null) p
    ],
    bridged(parts, words, lexiconUsed),
    given,
  );

  final reportGame = <String, dynamic>{
    'filler_parts': fillerParts,
    'filler_moves': fillerMoves,
    'filler_sentences': fillerSentences,
    'lexicon': lexiconUsed,
    'merged': merged,
    if (reportRecap != null) 'recap': reportRecap,
    if (leftBookAt != null) 'left_book_at': leftBookAt,
    'parts': parts.length,
  };

  return (parts, bridgedWords, reportGame);
}

SkeletonAssembly assembleSkeleton(
  Map<String, dynamic> facts,
  String answerText, {
  SkeletonParameters parameters = const SkeletonParameters(),
}) {
  final report = <String, dynamic>{
    'parameters': parameters.toJson(),
    'facts': stampOf(facts),
    'problems': <String>[],
    'missing_slots': <String>[],
    'unused_slots': <String>[],
    'claims': <String>[],
  };

  Map<String, dynamic> answer;
  try {
    final decoded = jsonDecode(answerText);
    if (decoded is! Map<String, dynamic>) {
      report['problems'].add('the answer is not JSON');
      return SkeletonAssembly(
        report: report,
        tutorial: null,
        tutorialGame: null,
      );
    }
    answer = decoded;
  } on FormatException {
    report['problems'].add('the answer is not JSON');
    return SkeletonAssembly(
      report: report,
      tutorial: null,
      tutorialGame: null,
    );
  }

  final momentsList = skeletonMoments(facts, parameters: parameters);
  final offered = {for (final m in momentsList) m['id'] as String: m};
  final asked = ((answer['chosen'] as List?) ?? const [])
      .map((e) => e.toString())
      .toList();
  final chosen = [
    for (final c in asked)
      if (offered.containsKey(c)) c
  ];
  report['chosen'] = chosen;

  for (final c in asked) {
    if (!offered.containsKey(c)) {
      report['problems'].add("chose '$c', which was not offered");
    }
  }
  if (chosen.length < 2 || chosen.length > 3) {
    report['problems'].add('chose ${chosen.length} moments, not two or three');
  }

  final rawSlots = (answer['slots'] as Map?) ?? const {};
  final given = <String, String>{
    for (final entry in rawSlots.entries)
      entry.key.toString(): cleanText(entry.value),
  };

  final wanted = <String>{};
  final blocks = <(Map<String, dynamic>, List<Map<String, dynamic>>)>[];
  int? previous;
  final trimmed = <String>[];

  final sortedChosen = chosen.toList()
    ..sort((a, b) =>
        (offered[a]!['index'] as int).compareTo(offered[b]!['index'] as int));

  for (final mid in sortedChosen) {
    final moment = offered[mid]!;
    final parts = <Map<String, dynamic>>[];
    for (var part in (moment['parts'] as List).cast<Map<String, dynamic>>()) {
      final moves =
          (part['moves'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      if (part['lead'] == true &&
          previous != null &&
          moves.isNotEmpty &&
          (moves[0]['ply'] as int) < previous) {
        final kept =
            moves.where((mv) => (mv['ply'] as int) >= previous!).toList();
        final droppedMsg = kept.isEmpty ? ', and is dropped' : '';
        trimmed.add(
          '$mid lead-in starts at ply $previous instead of ${moves[0]['ply']}$droppedMsg',
        );
        if (kept.isEmpty) {
          continue;
        }
        part = {
          ...part,
          'moves': kept,
          'fen': kept[0]['fen_before'],
          'intro': null,
        };
      }
      parts.add(part);
    }
    previous = moment['index'] as int;

    final used = <String>{};
    for (final part in parts) {
      if (part['intro'] != null) used.add(part['intro'] as String);
      if (part['instruction'] != null) used.add(part['instruction'] as String);
      for (final mv in (part['moves'] as List?)?.cast<Map<String, dynamic>>() ??
          const []) {
        used.add(mv['slot'] as String);
      }
    }

    final momentSlots = (moment['slots'] as Map).cast<String, String>();
    final momentFacts =
        (moment['facts'] as Map).cast<String, Map<String, dynamic>>();
    var context = [
      ...((moment['events'] as List?) ?? const []).cast<String>(),
      (moment['board'] as String?) ?? '',
    ].join(' ');
    for (final sid in momentSlots.keys) {
      context += ' ${momentSlots[sid]}';
      if (!used.contains(sid)) continue;
      wanted.add(sid);
      final text = given[sid];
      // A move the model chose to leave in silence, which the voice rule
      // allows — never the first move of a best line.
      if (text != null &&
          text.isEmpty &&
          rawSlots.containsKey(sid) &&
          RegExp(r'[.](lead|answer|other)[.][0-9]+$').hasMatch(sid) &&
          !sid.endsWith('.answer.1')) {
        (report['silent_slots'] ??= <String>[]).add(sid);
        continue;
      }
      if (text == null || text.isEmpty) {
        report['missing_slots'].add(sid);
      } else {
        report['claims']
            .addAll(claimsFor(sid, text, momentFacts[sid]!, context));
      }
    }
    blocks.add((moment, parts));
  }

  final rows = (facts['rows'] as List).cast<Map<String, dynamic>>();
  final arc = gameArc(rows);
  final storyFacts = [for (final e in gameStory(rows)) e['text']].join(' ');
  for (final key in const ['opening', 'ending']) {
    final sid = 'story.$key';
    wanted.add(sid);
    final text = given[sid];
    if (text == null || text.isEmpty) {
      report['missing_slots'].add(sid);
    } else {
      report['claims'].addAll(
          claimsFor(sid, text, {'text': arc[key], 'motifs': ''}, storyFacts));
    }
  }

  final unused = given.keys.where((k) => !wanted.contains(k)).toList()..sort();
  report['unused_slots'] = unused;
  report['trimmed'] = trimmed;
  for (final (moment, _) in blocks) {
    given.addAll(
        ((moment['program'] as Map?) ?? const {}).cast<String, String>());
  }

  final rawTags = (answer['tags'] as List?) ?? const [];
  final tags = [for (final t in rawTags) cleanText(t)].take(2).toList();
  final head = <String, dynamic>{
    'title': cleanText(answer['title']),
    'description': cleanText(answer['description']),
    'tags': tags,
    'language': 'en',
  };

  final momentsOnly = [for (final (_, parts) in blocks) ...parts];
  final tutorial = <String, dynamic>{
    ...head,
    'positionList': stepsFor(momentsOnly,
        framed(momentsOnly, bridged(momentsOnly, given, {}), given)),
  };

  final (gameParts, gameWords, gameReport) =
      wholeGame(rows, blocks, given, parameters);
  report['game'] = gameReport;

  final tutorialGame = <String, dynamic>{
    ...head,
    'title': '${head['title']}$kGameTitle',
    'positionList': stepsFor(gameParts, gameWords),
  };

  return SkeletonAssembly(
    report: report,
    tutorial: tutorial,
    tutorialGame: tutorialGame,
  );
}
