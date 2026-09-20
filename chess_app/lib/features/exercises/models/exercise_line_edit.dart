// exercise_line_edit.dart — the trainer's own making and editing of a find
// exercise's answer (`docs/PLAN-EXERCISE.md`, phases 11, 14 and 16): one move,
// and the moves accepted beside it.
//
// No widgets: `ExerciseEditorScreen` keeps one of these per exercise, and a
// widget test can drive it directly. Every change goes through
// `ExerciseLine.read` — the app's one reader of what an accepted move is —
// so this class has no rule of its own about legality, duplicates or the
// limit of eight; it only asks the reader again with the candidate list and
// keeps the answer, win or refuse.
import 'exercise.dart';
import 'exercise_line.dart';

class ExerciseLineEdit {
  ExerciseLineEdit({required String fen, required List<ExerciseStep> steps})
      : _fen = fen {
    _apply(steps);
  }

  /// An exercise being made, with no answer yet (phase 14). Not a refusal:
  /// [error] stays null until a move is actually turned down.
  ExerciseLineEdit.empty({required String fen}) : _fen = fen;

  final String _fen;
  List<ExerciseStep> _steps = const [];
  String? _error;

  /// A move played on the editor's board: the first is the answer, every
  /// further one an accepted alternative to it. False — with [error] set and
  /// [steps] unchanged — when the reader refuses it.
  bool play(String san) {
    final accept = _steps.isEmpty ? const <String>[] : _steps.first.accept;
    return _try([...accept, san]);
  }

  bool _try(List<String> accept) {
    final reading = ExerciseLine.read(
      fen: _fen,
      steps: [ExerciseStep(accept: accept)],
    );
    if (!reading.ok) {
      _error = reading.error;
      return false;
    }
    _steps = reading.steps;
    _error = null;
    return true;
  }

  /// Gives the answer back, alternatives and all — the answer cannot be taken
  /// out alone ([remove]), so while an exercise is being made a wrong first
  /// move is undone by starting over.
  void clear() {
    _steps = const [];
    _error = null;
  }

  /// As `ExerciseLine.read` spells them. Empty when the answer given cannot
  /// be read — [error] then says why.
  List<ExerciseStep> get steps => _steps;

  /// The last refusal, in the reader's own words; null after a success.
  String? get error => _error;

  void _apply(List<ExerciseStep> steps) {
    final reading = ExerciseLine.read(fen: _fen, steps: steps);
    _steps = reading.steps;
    _error = reading.error;
  }

  /// Takes an alternative back. Never the answer itself — that is undone by
  /// starting over ([clear]). False when [san] is the answer or is not there.
  bool remove(String san) {
    final accept = _steps.isEmpty ? const <String>[] : _steps.first.accept;
    final index = accept.indexOf(san);
    if (index <= 0) {
      _error = 'There is no accepted alternative "$san".';
      return false;
    }
    return _try(List<String>.from(accept)..removeAt(index));
  }
}
