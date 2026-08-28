import 'package:chess/chess.dart' as chess;

/// How a drill against the engine ended, from the reader's side.
///
/// This exists because the answer used to be read off the wrong thing. In the
/// AI Studio drills the outcome was decided by which drill it was: inside the
/// engine's own move handler, `basic_mate` said "Stockfish mated you" and every
/// other category fell through to the victory dialog. So in `winning_position`
/// a mate delivered *by* the engine congratulated the reader on delivering it,
/// and marked the drill solved.
///
/// The board already knows. After a checkmate the side to move is the mated
/// one — that is what checkmate is — so the only other thing needed is which
/// side the reader is playing. Both are read here, and neither is guessed from
/// the category or from who happened to move last.
enum DrillOutcome {
  /// The reader delivered mate.
  readerWon,

  /// The reader was mated.
  readerLost,

  /// Stalemate, or a draw by rule.
  drawn,

  /// The game is still going.
  undecided,
}

/// The side to move in [fen] — the side a drill hands to the reader.
///
/// Falls back to white on a FEN without a side field rather than throwing: a
/// malformed position is a loading problem, and it should surface as a board
/// that looks wrong, not as an exception thrown from a verdict.
chess.Color sideToMoveOf(String fen) {
  final parts = fen.split(' ');
  return (parts.length > 1 && parts[1] == 'b')
      ? chess.Color.BLACK
      : chess.Color.WHITE;
}

/// Reads the verdict off the board, for the reader playing [userColor].
///
/// Deliberately takes no category and no "who moved last". Those are the two
/// inputs that produced the wrong answer, and neither is needed: a mate names
/// its victim by whose turn it is.
DrillOutcome outcomeFor(chess.Chess game, chess.Color userColor) {
  if (game.in_checkmate) {
    return game.turn == userColor
        ? DrillOutcome.readerLost
        : DrillOutcome.readerWon;
  }
  if (game.in_stalemate || game.in_draw) return DrillOutcome.drawn;
  return DrillOutcome.undecided;
}

/// Whether a move by [movingColor] means the reader has taken over the other
/// side.
///
/// Stepping back through the move tree to a position the engine was to play
/// and playing it is allowed — watching the engine play your own side is a
/// reason people do it. It only has to stop being silent, because from the
/// next reply onwards the engine answers the reader's new side, and every
/// verdict after that depends on knowing it happened.
bool isSideSwap(chess.Color? userColor, chess.Color movingColor) =>
    userColor != null && movingColor != userColor;
