// exercise_line_edit.dart — the trainer's own edit of a saved line
// (`docs/PLAN-EXERCISE.md`, phase 11).
//
// No widgets: `ExerciseEditorScreen` keeps one of these per exercise, and a
// widget test can drive it directly. Every change goes through
// `ExerciseLine.read` — the app's one reader of what an accepted move is —
// so this class has no rule of its own about legality, duplicates or the
// limit of eight; it only asks the reader again with the candidate list and
// keeps the answer, win or refuse.
import 'package:chess/chess.dart' as chess;

import 'package:chess_app/features/tutorial_studio/services/game_tutorial/board_queries.dart'
    show findMove;

import 'exercise.dart';
import 'exercise_line.dart';

class ExerciseLineEdit {
  ExerciseLineEdit({required String fen, required List<ExerciseStep> steps})
      : _fen = fen {
    _apply(steps);
  }

  final String _fen;
  List<ExerciseStep> _steps = const [];
  String? _error;

  /// As `ExerciseLine.read` spells them. Empty when the line given does not
  /// replay — [error] then says why.
  List<ExerciseStep> get steps => _steps;

  /// The last refusal, in the reader's own words; null after a success.
  String? get error => _error;

  void _apply(List<ExerciseStep> steps) {
    final reading = ExerciseLine.read(fen: _fen, steps: steps);
    _steps = reading.steps;
    _error = reading.error;
  }

  /// The board the student sees at [step]: the position after the main moves
  /// and replies before it. `fenBefore(0)` is the exercise's own.
  String fenBefore(int step) {
    final board = chess.Chess.fromFEN(_fen);
    for (var i = 0; i < step && i < _steps.length; i++) {
      final s = _steps[i];
      board.make_move(findMove(board, s.accept.first));
      final reply = s.reply;
      if (reply != null) board.make_move(findMove(board, reply));
    }
    return board.fen;
  }

  /// Accepts [san] at [step] as well, after the ones already there, as the
  /// board spells it. False — with [error] set and [steps] unchanged — when
  /// the reader refuses the result, or [step] is out of range.
  bool add(int step, String san) {
    if (step < 0 || step >= _steps.length) {
      _error = 'There is no step $step to add a move to.';
      return false;
    }
    final candidate = [
      for (var i = 0; i < _steps.length; i++)
        if (i == step)
          ExerciseStep(
            accept: [..._steps[i].accept, san],
            reply: _steps[i].reply,
          )
        else
          _steps[i],
    ];
    final reading = ExerciseLine.read(fen: _fen, steps: candidate);
    if (!reading.ok) {
      _error = reading.error;
      return false;
    }
    _steps = reading.steps;
    _error = null;
    return true;
  }

  /// Takes an alternative back. Never `accept[0]`: the replies were written
  /// after it. False when [san] is the main move or is not there.
  bool remove(int step, String san) {
    if (step < 0 || step >= _steps.length) {
      _error = 'There is no step $step to remove a move from.';
      return false;
    }
    final current = _steps[step];
    final index = current.accept.indexOf(san);
    if (index <= 0) {
      _error = 'There is no accepted alternative "$san" at that step.';
      return false;
    }
    final remaining = List<String>.from(current.accept)..removeAt(index);
    final candidate = [
      for (var i = 0; i < _steps.length; i++)
        if (i == step)
          ExerciseStep(accept: remaining, reply: current.reply)
        else
          _steps[i],
    ];
    final reading = ExerciseLine.read(fen: _fen, steps: candidate);
    if (!reading.ok) {
      _error = reading.error;
      return false;
    }
    _steps = reading.steps;
    _error = null;
    return true;
  }
}
