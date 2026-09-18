// exercise_line_play.dart — the solver's own memory of a line in progress.
//
// No widgets: `custom_puzzle_solver_screen.dart` keeps one of these per
// position, and a widget test can drive it directly.
//
// **The report keeps the first verdict** (`docs/briefs/
// BRIEF-EXERCISE-FAZA2B-APP.md`): a wrong move may be tried again, but that is
// the *screen's* bookkeeping (`_answered`, `onAnswered`), not this class's — a
// wrong `apply` here simply changes nothing, so the same position can be sent
// again.
import 'package:chess/chess.dart' as chess;

import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/board_queries.dart'
    show findMove;

class ExerciseLinePlay {
  ExerciseLinePlay({required String fen}) : _fen = fen;

  String _fen;
  final List<String> _moves = [];
  bool _done = false;

  /// The board to show now.
  String get fen => _fen;

  /// The student's own moves the server has accepted, in the order sent.
  List<String> get moves => List.unmodifiable(_moves);

  bool get done => _done;

  /// What to send next: every move accepted so far, plus [san].
  List<String> attempt(String san) => [..._moves, san];

  /// Folds the server's verdict for [san] into what is remembered.
  ///
  /// A wrong move leaves everything as it was. A right move is remembered
  /// exactly as sent — the server judges every move in the list, so [san] is
  /// what must be resent — and the board goes on from `result.continuesOn`
  /// when an accepted alternative was played, then the reply: the reply was
  /// written after the author's move and may not even be legal after another.
  void apply(String san, CustomAttemptResult result) {
    if (!result.correct) return;
    _moves.add(san);

    final board = chess.Chess.fromFEN(_fen);
    final forward = result.continuesOn ?? san;
    board.make_move(findMove(board, forward));
    final reply = result.reply;
    if (reply != null && reply.isNotEmpty) {
      board.make_move(findMove(board, reply));
    }
    _fen = board.fen;
    _done = result.done;
  }
}
