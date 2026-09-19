// exercise_line.dart — the app's own `readSolution`, move for move.
//
// `chess_backend/services/exercise.js`'s `readSolution` is the rule: a line
// the server refuses is a line the app should never have sent, so this reader
// repeats it, reason for reason, and normalises a solution the same way — as
// the board spells it, decoration included.
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

const int _maxSolutionSteps = 20;
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

  /// The server's `readSolution`, played out on the app's own board.
  ///
  /// Every accepted move is tried from a fresh copy of the position — so one
  /// alternative failing does not chain into the next — and only the first
  /// stays played. A reply is legal only after that first move: it was
  /// written to go there, and may not even be legal after another.
  static ExerciseLineReading read({
    required String fen,
    required List<ExerciseStep> steps,
  }) {
    if (steps.isEmpty) {
      return const ExerciseLineReading(
        steps: [],
        error: 'The solution must be a list of at least one move.',
      );
    }
    if (steps.length > _maxSolutionSteps) {
      return const ExerciseLineReading(
        steps: [],
        error: 'The solution is longer than $_maxSolutionSteps moves.',
      );
    }

    final valid = chess.Chess.validate_fen(fen);
    if (valid['valid'] != true) {
      return const ExerciseLineReading(
        steps: [],
        error: 'The position is not valid.',
      );
    }
    final board = chess.Chess.fromFEN(fen);

    final out = <ExerciseStep>[];
    for (var i = 0; i < steps.length; i++) {
      final where = 'move ${i + 1}';
      final raw = steps[i];
      final accept =
          raw.accept.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (accept.isEmpty) {
        return ExerciseLineReading(
          steps: const [],
          error: '$where: nothing is accepted, so nothing can be right.',
        );
      }
      if (accept.length > _maxAccepted) {
        return ExerciseLineReading(
          steps: const [],
          error: '$where: more than $_maxAccepted accepted moves.',
        );
      }

      // Every accepted move is tried on a copy of the position before this
      // step; only the first stays played on [board].
      final played = <String>[];
      for (final san in accept) {
        final probe = chess.Chess.fromFEN(board.fen);
        chess.Move? move;
        try {
          move = findMove(probe, san);
        } catch (_) {
          move = null;
        }
        if (move == null) {
          return ExerciseLineReading(
            steps: const [],
            error: '$where: "$san" cannot be played here.',
          );
        }
        played.add(probe.move_to_san(move));
      }
      if (Set<String>.from(played).length != played.length) {
        return ExerciseLineReading(
          steps: const [],
          error: '$where: the same move is accepted twice.',
        );
      }

      board.make_move(findMove(board, accept.first));

      final isLast = i == steps.length - 1;
      final rawReply = raw.reply?.trim();
      String? reply;
      if (rawReply != null && rawReply.isNotEmpty) {
        chess.Move? replyMove;
        try {
          replyMove = findMove(board, rawReply);
        } catch (_) {
          replyMove = null;
        }
        if (replyMove == null) {
          return ExerciseLineReading(
            steps: const [],
            error: '$where: the reply "${raw.reply}" cannot be played.',
          );
        }
        reply = board.move_to_san(replyMove);
        board.make_move(replyMove);
      } else if (!isLast && !board.game_over) {
        // A line that goes on needs the move it goes on after. Without one
        // the student's next move would be asked of the wrong side.
        return ExerciseLineReading(
          steps: const [],
          error: '$where: the line goes on, but there is no reply to go on '
              'from.',
        );
      }
      if (isLast && reply != null) {
        return ExerciseLineReading(
          steps: const [],
          error: '$where: the line ends on a reply, which nobody is asked '
              'to find.',
        );
      }

      out.add(ExerciseStep(accept: played, reply: reply));
    }
    return ExerciseLineReading(steps: out);
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
              ExerciseStep(accept: [for (final m in moves) m.san], reply: null)
            ],
    );
    return ExerciseLineReading(
      steps: reading.steps,
      error: reading.error,
      laterMovesIgnored: moves.any((m) => m.children.isNotEmpty),
    );
  }
}
