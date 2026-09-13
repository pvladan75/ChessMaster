import 'dart:convert';

import 'package:chess/chess.dart' as chess;
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/studio_lesson_step.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/evaluation_words.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_moments.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_parameters.dart';

const String kGameTitle = ' (whole game)';

const Map<String, List<String>> kLexicon = {
  'resumed': [
    'Back in the game, {mover} played {move} instead; afterwards {after}.',
    'Returning to the game, {mover} played {move} instead; afterwards {after}.',
    'Back on the board, the game continued with {move} instead; afterwards {after}.',
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

List<String> claimsFor(
  String sid,
  String text,
  Map<String, dynamic> facts,
) {
  final found = <String>[];
  final low = text.toLowerCase();
  final shown =
      ('${facts['text'] ?? ''} ${facts['motifs'] ?? ''}').toLowerCase();

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
      !shown.contains('winning')) {
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

  if (question) {
    final names =
        (facts['names'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final rawAnswer = names.isNotEmpty ? names[0] : '';
    final answer = rawAnswer.replaceAll(RegExp(r'[+#]+$'), '');
    final sqName = names.length > 1 ? names[1] : '';
    if ((answer.isNotEmpty && text.contains(answer)) ||
        (sqName.isNotEmpty && low.contains(sqName))) {
      found.add('$sid names its answer or its square');
    }
    final moveMatches = RegExp(
      r'\b([KQRBN][a-h]?[1-8]?x?[a-h][1-8][+#]?|[a-h]x[a-h][1-8][+#]?|O-O(?:-O)?)\b',
    ).allMatches(text);
    final others = <String>{};
    for (final m in moveMatches) {
      final matched = m.group(0)!;
      if (matched.replaceAll(RegExp(r'[+#]+$'), '') != answer) {
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

String? mistakeKind(int? before, int? after) {
  if (before == null || after == null || after >= before) return null;
  if (after <= -3 && -3 < before) return 'opponent_winning';
  if (before == 4) return 'misses_mate';
  if (before < 0 || after > 0) return null;
  return after == 0 ? 'advantage_gone' : 'opponent_better';
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
  Map<String, int> used,
) {
  final row = rows[r];
  final played = row['played'] as Map<String, dynamic>;
  final mover = row['to_move'] as String;
  final eval = played['eval'] as String?;
  final after = wordsFor(eval);
  final said = <String>[];

  if (resumed) {
    final afterVal =
        (after == 'about even' || after == 'a draw' || after == 'checkmate')
            ? 'it is $after'
            : (after == 'unknown' ? 'the evaluation is unknown' : after);
    said.add(
      pickLexicon('resumed', used)
          .replaceAll('{mover}', mover)
          .replaceAll('{move}', played['move'] as String)
          .replaceAll('{after}', afterVal),
    );
  } else if (costValue(played['cost_pawns']) >= parameters.minCost &&
      row['candidates'] != null &&
      (row['candidates'] as List).isNotEmpty) {
    final candidates = row['candidates'] as List;
    final best = candidates[0]['eval'] as String?;
    final kind = mistakeKind(standing(best, mover), standing(eval, mover));
    if (kind != null) {
      final picked = pickLexicon(kind, used);
      said.add(
        '$mover plays ${played['move']}. $picked With the best move: ${wordsFor(best)}. After this one: $after.',
      );
    }
  }

  final book = row['book'] as Map<String, dynamic>?;
  if (played['left_book'] == true && book != null) {
    final games = book['games'] as int;
    final gamesText = games == 1 ? '1 master game' : '$games master games';
    said.add(
      'This move left the masters database: $gamesText reached this position and none played it.',
    );
  }

  return said.join(' ');
}

String pgnForPart(Map<String, dynamic> part, Map<String, dynamic> words) {
  final fen = part['fen'] as String;
  final introKey = part['intro'] as String?;
  final rootComment =
      (introKey != null ? (words[introKey] as String?) : null) ?? '';
  final root = AnalysisNode(fen: fen, comment: rootComment);
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
  final parts = <Map<String, dynamic>>[];
  final lexiconUsed = <String, int>{};
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

  final reportGame = <String, dynamic>{
    'filler_parts': fillerParts,
    'filler_moves': fillerMoves,
    'filler_sentences': fillerSentences,
    'lexicon': lexiconUsed,
    'merged': merged,
    'parts': parts.length,
  };

  return (parts, words, reportGame);
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
    for (final sid in momentSlots.keys) {
      if (!used.contains(sid)) continue;
      wanted.add(sid);
      final text = given[sid];
      if (text == null || text.isEmpty) {
        report['missing_slots'].add(sid);
      } else {
        report['claims'].addAll(claimsFor(sid, text, momentFacts[sid]!));
      }
    }
    blocks.add((moment, parts));
  }

  final unused = given.keys.where((k) => !wanted.contains(k)).toList()..sort();
  report['unused_slots'] = unused;
  report['trimmed'] = trimmed;

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
    'positionList': stepsFor(momentsOnly, given),
  };

  final rows = (facts['rows'] as List).cast<Map<String, dynamic>>();
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
