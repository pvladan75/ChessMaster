// exercise_line.dart — the app's own `readSolution`, move for move.
//
// `chess_backend/services/exercise.js`'s `readSolution` is the rule: a
// solution the server refuses is one the app should never have sent, so this
// reader repeats it, reason for reason, and normalises a solution the same
// way — as the board spells it, decoration included.
//
// **The Dart `chess` package is stricter than the server's chess.js**: its own
// `Chess.move('Rd8')` answers false where chess.js plays it, when the real
// spelling is `Rd8#`. `findMove` (`board_queries.dart`) is the app's one
// answer to that — strip the decoration, match what is left, then let the
// board spell the move back. It is not copied here: `ExerciseLine` imports it.
import 'package:chess/chess.dart' as chess;

import 'package:chess_app/features/tutorial_studio/services/game_tutorial/board_queries.dart'
    show findMove;
import 'package:chess_app/move_tree.dart';

import 'exercise.dart';

const int _maxAccepted = 8;

/// What reading a solution — typed by hand or flattened from a tree — came
/// back with.
class ExerciseLineReading {
  const ExerciseLineReading({
    required this.steps,
    this.error,
    this.laterMovesIgnored = false,
  });

  /// As the board spells them. Empty when [error] is set.
  final List<ExerciseStep> steps;

  /// The reason it was refused, in the server's own words. Null when [ok].
  final String? error;

  /// `fromTree` only: the tree went on after the first move — a reply, a
  /// second move, a line under an alternative — and none of that was used. A
  /// find exercise asks for one move (`docs/PLAN-EXERCISE.md`, phase 14).
  final bool laterMovesIgnored;

  bool get ok => error == null;
}

class ExerciseLine {
  const ExerciseLine._();

  /// What a longer list is told — the server's own sentence.
  static const String oneMove =
      'A find exercise asks for one move. For more, use Checkmate in N or '
      'Play N moves.';

  /// The server's `readSolution`, on the app's own board: a list of exactly
  /// one step, every accepted move legal in the position and tried from a
  /// fresh copy of it, so one alternative failing does not chain into the
  /// next.
  static ExerciseLineReading read({
    required String fen,
    required List<ExerciseStep> steps,
  }) {
    ExerciseLineReading refuse(String why) =>
        ExerciseLineReading(steps: const [], error: why);

    if (steps.isEmpty) {
      return refuse('The solution must be a list of at least one move.');
    }
    if (steps.length > 1) return refuse(oneMove);

    final valid = chess.Chess.validate_fen(fen);
    if (valid['valid'] != true) return refuse('The position is not valid.');

    final accept = steps.single.accept
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (accept.isEmpty) {
      return refuse('The solution accepts nothing, so nothing can be right.');
    }
    if (accept.length > _maxAccepted) {
      return refuse('More than $_maxAccepted accepted moves.');
    }

    final played = <String>[];
    for (final san in accept) {
      final probe = chess.Chess.fromFEN(fen);
      chess.Move? move;
      try {
        move = findMove(probe, san);
      } catch (_) {
        move = null;
      }
      if (move == null) return refuse('"$san" cannot be played here.');
      played.add(probe.move_to_san(move));
    }
    if (Set<String>.from(played).length != played.length) {
      return refuse('The same move is accepted twice.');
    }
    return ExerciseLineReading(steps: [ExerciseStep(accept: played)]);
  }

  /// The trainer's tree, read **at its root** — never at `tree.current`. The
  /// 6.9.2026 bug (`CLAUDE.md`, „the recurring bug") sent a step's `fen` from
  /// the current node and its line from the root; here both come from
  /// `tree.root`, and the result is read back through [read] before it is
  /// returned, so what this app writes is never what the server would refuse.
  ///
  /// **One move** (phase 14): the root's first child is the answer and its
  /// siblings — variations at the student's move — the accepted alternatives,
  /// in tree order. Whatever the tree holds below them is not used, and the
  /// reading says so (`laterMovesIgnored`). The server refuses a longer find
  /// solution; this writer cannot make one.
  static ExerciseLineReading fromTree(MoveTree tree) {
    final moves = tree.root.children;
    final reading = read(
      fen: tree.root.fen,
      steps: moves.isEmpty
          ? const []
          : [
              ExerciseStep(accept: [for (final m in moves) m.san])
            ],
    );
    return ExerciseLineReading(
      steps: reading.steps,
      error: reading.error,
      laterMovesIgnored: moves.any((m) => m.children.isNotEmpty),
    );
  }
}
