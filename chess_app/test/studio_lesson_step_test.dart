import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/studio_lesson_step.dart';
import 'package:chess_app/move_tree.dart';

/// „Napravi korak od ove pozicije", and the rule it broke: a step's `fen` and
/// its `pgn` must come from the same node.
///
/// The old call site took the position from the node the trainer was standing
/// on and the line from the root of the tree. Every test here walks a whole
/// tree and asserts the pair holds at *every* node, because the failure was
/// decided by where the trainer happened to be standing — and by parity, so
/// half the positions in a tree looked fine.
void main() {
  const start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  // White Ke3 and a pawn on e2, black Ke6 — the position the opposition is
  // taught from, and the line the report asked about: 1.Ke4 Kd6 2.Kd4 Ke6 3.e4.
  const opposition = '8/8/4k3/8/8/4K3/4P3/8 w - - 0 1';

  /// Plays [sans] onto [parent], as the studio does when the trainer moves a
  /// piece, and writes each move's note.
  AnalysisNode play(AnalysisNode parent, List<String> sans,
      {String notePrefix = 'komentar uz '}) {
    final game = chess.Chess.fromFEN(parent.fen);
    var node = parent;
    for (final san in sans) {
      expect(game.move(san), isTrue, reason: '$san must be legal');
      final made = game.history.last.move;
      node = node.addChild(
        childFen: game.fen,
        san: san,
        uci: '${made.fromAlgebraic}${made.toAlgebraic}',
      );
      node.comment = '$notePrefix$san';
    }
    return node;
  }

  List<AnalysisNode> everyNode(AnalysisNode root) {
    final all = <AnalysisNode>[];
    void walk(AnalysisNode n) {
      all.add(n);
      for (final c in n.children) {
        walk(c);
      }
    }

    walk(root);
    return all;
  }

  test('every node of a line makes a step that replays', () {
    // The opposition lesson from the report that started this: five half-moves,
    // a note on each.
    final root = AnalysisNode(fen: opposition);
    play(root, ['Ke4', 'Kd6', 'Kd4', 'Ke6', 'e4']);

    for (final node in everyNode(root)) {
      final step = StudioLessonStep.from(node);
      expect(step.replays, isTrue,
          reason: 'a step made from ${node.moveSan ?? "the root"} must replay');
      expect(step.rejectedMoves, 0);
      expect(step.fen, node.fen,
          reason: 'the board opens on the node it was made from');
    }
  });

  test('the step made here carries exactly what follows here', () {
    final root = AnalysisNode(fen: opposition);
    play(root, ['Ke4', 'Kd6', 'Kd4', 'Ke6', 'e4']);

    final afterTwo = root.children.first.children.first; // 1.Ke4 Kd6
    final step = StudioLessonStep.from(afterTwo);

    expect(step.line.movesSan, ['Kd4', 'Ke6', 'e4']);
    expect(step.line.comments,
        ['komentar uz Kd4', 'komentar uz Ke6', 'komentar uz e4']);
  });

  test('the step made from the root carries the whole line', () {
    final root = AnalysisNode(fen: opposition);
    play(root, ['Ke4', 'Kd6', 'Kd4', 'Ke6', 'e4']);

    final step = StudioLessonStep.from(root);

    expect(step.line.movesSan, ['Ke4', 'Kd6', 'Kd4', 'Ke6', 'e4']);
    expect(step.line.comments.first, 'komentar uz Ke4');
  });

  test('a tree with sidelines still replays from every node', () {
    // Variations are the case where "the line" is ambiguous, so the pair has to
    // hold on the sidelines too — a trainer saving a step is often standing in
    // one.
    final root = AnalysisNode(fen: start);
    final e4 = play(root, ['e4']);
    play(e4, ['e5', 'Nf3', 'Nc6']);
    play(e4, ['c5', 'Nf3', 'd6']); // Sicilian, as a sideline of 1...e5
    play(root, ['d4', 'd5']);

    for (final node in everyNode(root)) {
      final step = StudioLessonStep.from(node);
      expect(step.replays, isTrue,
          reason: 'step from ${node.moveSan ?? "root"} must replay');
    }
  });

  test('arrows and squares survive into the step', () {
    final root = AnalysisNode(fen: opposition);
    final ke4 = play(root, ['Ke4']);
    ke4.arrows = [ChessArrow(from: 'e3', to: 'e4', colorCode: 'G')];
    ke4.squares = [SquareMark(square: 'd6', colorCode: 'R')];
    root.squares = [SquareMark(square: 'e6', colorCode: 'G')];

    final step = StudioLessonStep.from(root);

    expect(step.line.arrows.first.single.toString(), 'Ge3e4');
    expect(step.line.squares.first.single.toString(), 'Rd6');
    expect(step.line.rootSquares.single.toString(), 'Ge6');
  });

  test('the note about the starting position reaches the step', () {
    final root = AnalysisNode(fen: opposition);
    root.comment = 'Beli je na potezu i treba mu opozicija.';
    play(root, ['Ke4', 'Kd6']);

    final step = StudioLessonStep.from(root);

    expect(step.line.rootComment, 'Beli je na potezu i treba mu opozicija.');
    expect(step.line.movesSan, ['Ke4', 'Kd6']);
  });

  test('the step sent to the backend is the pair that was checked', () {
    final root = AnalysisNode(fen: opposition);
    final node = play(root, ['Ke4', 'Kd6']);
    final step = StudioLessonStep.from(node);

    final json = step.toJson(title: 'Opozicija');

    expect(json['fen'], node.fen);
    expect(json['pgn'], step.pgn);
    expect(json['title'], 'Opozicija');
  });
}
