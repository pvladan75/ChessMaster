/// What the app sends the words route — phase 4 of `docs/PLAN-SKELET.md`.
///
/// A port of `words_request` in `tools/game_annotate/skeleton.py`, held to it:
/// every fixture game carries `expected.wordsRequest`, and the server's own test
/// holds the prompt it writes from that request to the harness byte for byte.
/// So a request equal to the fixture's is a prompt equal to the harness's.
///
/// **The skeleton as data, never a prompt**, and **the game as moves only**:
/// a trainer's game names its players, who are the trainer's students, and the
/// server refuses a game that carries headers. [movetextOf] writes the moves
/// from the positions the app already holds, with nothing else in them.
library;

import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_assembly.dart'
    show bookSummary;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_moments.dart'
    show gameArc, gameStory, skeletonMoments;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_parameters.dart';

/// The request for the words of [facts]' tutorial.
///
/// [movetext] is the game's moves, as [movetextOf] writes them.
Map<String, dynamic> wordsRequestOf(
  Map<String, dynamic> facts, {
  required String movetext,
  SkeletonParameters parameters = const SkeletonParameters(),
}) {
  final rows = (facts['rows'] as List).cast<Map<String, dynamic>>();
  final opening = bookSummary(rows);
  return {
    'game': movetext,
    'opening': opening.isEmpty ? null : opening,
    // The turning points and the arc are facts the program computes; the
    // server writes them into the prompt as it writes the slots
    // (docs/PLAN-NARACIJA.md).
    'story': [for (final e in gameStory(rows)) e['text']],
    'arc': gameArc(rows),
    'moments': [
      for (final m in skeletonMoments(facts, parameters: parameters))
        _momentRequest(m),
    ],
  };
}

/// One moment, with its slots in the order the student meets them: each part's
/// introduction, then its question, then its moves — the order the prompt
/// lists them in.
Map<String, dynamic> _momentRequest(Map<String, dynamic> m) {
  final texts = (m['slots'] as Map).cast<String, String>();
  final slots = <Map<String, dynamic>>[];
  for (final part in (m['parts'] as List).cast<Map<String, dynamic>>()) {
    // The program's own sentence — „In this position White played Bd3." — is
    // no slot of the model's.
    if (part['program'] == true) continue;
    final ids = <String>[
      if (part['intro'] != null) part['intro'] as String,
      if (part['instruction'] != null) part['instruction'] as String,
      for (final move in (part['moves'] as List? ?? const []))
        (move as Map)['slot'] as String,
    ];
    for (final id in ids) {
      slots.add({'id': id, 'text': texts[id]});
    }
  }
  return {
    'id': m['id'],
    'label': m['label'],
    'mover': m['mover'],
    'played': m['played'],
    'cost_text': m['cost_text'],
    'best': m['best'],
    'asks': m['asks'],
    'correct': m['correct'],
    'left_book': m['left_book'],
    'turning_point': m['turning_point'],
    'board': m['board'],
    'events': m['events'],
    'slots': slots,
  };
}

/// The moves [sans], numbered from [startFen], on one line and with nothing
/// else: `1. e4 e5 2. Nf3`, or `5... e5 6. Nf3` when Black moves first.
String movetextOf(String startFen, List<String> sans) {
  final fields = startFen.trim().split(RegExp(r'\s+'));
  var whiteToMove = fields.length < 2 || fields[1] == 'w';
  var number = fields.length > 5 ? int.tryParse(fields[5]) ?? 1 : 1;
  final out = StringBuffer();
  for (var i = 0; i < sans.length; i++) {
    if (whiteToMove) {
      if (out.isNotEmpty) out.write(' ');
      out.write('$number. ${sans[i]}');
    } else {
      out.write(i == 0 ? '$number... ${sans[i]}' : ' ${sans[i]}');
      number++;
    }
    whiteToMove = !whiteToMove;
  }
  return out.toString();
}
