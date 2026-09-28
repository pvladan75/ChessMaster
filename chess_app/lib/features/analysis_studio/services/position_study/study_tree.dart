/// A study written into the move tree — `docs/PLAN-STUDIJA-POZICIJE.md`, §1
/// and §4.
///
/// The lines go under the node the study started from; the words go on the
/// moves they are about, each as a beat of its own so nothing a reader wrote
/// there is replaced; and **a mark is drawn only in a beat whose sentence
/// names it** — a study without words draws none.
library;

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/position_study/study_board.dart';
import 'package:chess_app/features/analysis_studio/services/position_study/study_facts.dart';
import 'package:chess_app/features/analysis_studio/services/position_study/study_words.dart'
    show stepGetsWords;
import 'package:chess_app/move_tree.dart';

/// What [writeStudy] did.
class StudyWritten {
  const StudyWritten({
    required this.firstMove,
    required this.lastMove,
    required this.moves,
    required this.sentences,
  });

  /// The first and the last node of the main line.
  final AnalysisNode firstMove;
  final AnalysisNode lastMove;

  /// Nodes that were not in the tree before.
  final int moves;

  /// Beats written with words.
  final int sentences;
}

/// Writes [study] under [start], with [words] (slot id → sentence) where a
/// slot has any. [start] must stand on the position the study was made of.
StudyWritten writeStudy(
  AnalysisNode start,
  PositionStudy study, {
  Map<String, String> words = const {},
}) {
  if (start.fen != study.fen) {
    throw ArgumentError('The study is of another position than the node.');
  }
  final writer = _Writer(words);

  // --- The start: what stands on the board, and the threat -------------------
  writer.say(
    start,
    's.position',
    squares: [
      for (final sq in study.squares) SquareMark(square: sq, colorCode: 'Y'),
    ],
  );
  final threat = study.threat;
  if (threat != null) {
    writer.say(
      start,
      's.threat',
      arrows: [
        ChessArrow(from: threat.move.from, to: threat.move.to, colorCode: 'R'),
      ],
      squares: [SquareMark(square: threat.move.to, colorCode: 'R')],
    );
  }

  // --- The main line, and the traps beside it --------------------------------
  var at = start;
  var moves = 0;
  var traps = 0;
  AnalysisNode? first;
  for (var i = 0; i < study.mainLine.length; i++) {
    final step = study.mainLine[i];
    final before = at;
    at = writer.play(before, step.move);
    first ??= at;
    if (step.onlyMove && !step.forced) at.nag ??= '!';

    if (stepGetsWords(study, i)) {
      moves++;
      final idea = i == 0 ? study.idea : null;
      writer.say(
        at,
        'm$moves.move',
        arrows: [
          if (idea != null)
            ChessArrow(from: idea.move.from, to: idea.move.to, colorCode: 'B'),
        ],
      );
    }

    final trap = step.trap;
    if (trap != null) {
      traps++;
      writer.trap(before, trap, 'w$traps.capture', 'w$traps.punish');
    }
  }
  final last = at;
  writer.say(last, 'e.outcome');

  // --- The alternatives ------------------------------------------------------
  for (var i = 0; i < study.alternatives.length; i++) {
    final line = study.alternatives[i].line;
    final node = writer.line(start, line);
    if (node != null) writer.say(node, 'a${i + 1}.move');
  }

  // --- The tempting moves ----------------------------------------------------
  for (var i = 0; i < study.tempting.length; i++) {
    final t = study.tempting[i];
    final id = 't${i + 1}';
    final tempted = writer.play(start, t.move);
    if (t.nag != null) tempted.nag ??= t.nag;
    writer.say(tempted, '$id.move');

    final reply = writer.play(tempted, t.defence.first);
    writer.say(reply, '$id.reply');
    final greedy = t.greedy;
    if (greedy != null) {
      // The trap first: it is the story the move is shown for, and a
      // tutorial's part walks first children. The best defence stands
      // beside it.
      reply.nag ??= '!';
      writer.trap(reply, greedy, '$id.greedy', '$id.punish');
    }
    writer.line(reply, t.defence.sublist(1));
  }

  return StudyWritten(
    firstMove: first!,
    lastMove: last,
    moves: writer.added,
    sentences: writer.said,
  );
}

class _Writer {
  _Writer(this.words);

  final Map<String, String> words;
  int added = 0;
  int said = 0;

  /// [move] as a child of [parent]; the node that was already there when the
  /// tree had the move.
  AnalysisNode play(AnalysisNode parent, StudyMove move) {
    final had = parent.children.length;
    final node =
        parent.addChild(childFen: move.fenAfter, san: move.san, uci: move.uci);
    if (parent.children.length > had) added++;
    return node;
  }

  /// [line] from [parent], move after move; the first node of it.
  AnalysisNode? line(AnalysisNode parent, List<StudyMove> line) {
    AnalysisNode? first;
    var at = parent;
    for (final move in line) {
      at = play(at, move);
      first ??= at;
    }
    return first;
  }

  /// The capture, marked `?`, and what punishes it, its first move marked
  /// `!`, under [parent].
  void trap(
      AnalysisNode parent, StudyTrap trap, String capture, String punish) {
    final taken = play(parent, trap.move);
    taken.nag ??= '?';
    say(taken, capture);
    final first = line(taken, trap.punishment);
    if (first != null) {
      first.nag ??= '!';
      say(first, punish);
      // The engine's own defence, where the line shown takes a piece the
      // engine declines: beside it, after the move it answers.
      line(first, trap.declined);
    }
  }

  /// The words of [slot] on [node], with their marks: into the node's first
  /// beat when that is empty, as a new beat after the last otherwise. Nothing
  /// is written — marks included — for a slot without words.
  void say(
    AnalysisNode node,
    String slot, {
    List<ChessArrow> arrows = const [],
    List<SquareMark> squares = const [],
  }) {
    final text = words[slot]?.trim();
    if (text == null || text.isEmpty) return;
    final beat = node.beats.first.isEmpty ? node.beats.first : node.addBeat();
    beat
      ..comment = text
      ..arrows = [...arrows]
      ..squares = [...squares];
    said++;
  }
}
