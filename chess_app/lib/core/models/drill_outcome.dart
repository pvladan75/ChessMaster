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
  /// The reader delivered mate, or the engine gave up.
  readerWon,

  /// The reader was mated, or resigned.
  readerLost,

  /// Stalemate, a draw by rule, or the move limit.
  drawn,

  /// The game is still going.
  undecided,
}

/// Why the game is over — the half of the verdict a report and a homework
/// goal need (`docs/PLAN-DOMACI-ZADATAK.md`, §3): „hold" is met by any draw,
/// „survive" by reaching the limit, and the student is told which it was.
///
/// The first five are read off the board. The last two cannot be: the board
/// does not know how many moves a trainer allowed, or that somebody gave up,
/// so [verdictFor] takes them as inputs.
enum GameEnding {
  checkmate,
  stalemate,
  insufficientMaterial,
  threefoldRepetition,
  fiftyMoves,

  /// The drill's move limit was reached with the game still undecided. Read as
  /// a draw: a „win" goal is not met, a „hold" or „survive" goal is.
  moveLimit,
  resignation,
}

/// The verdict: the outcome for the reader and the reason. [ending] is null
/// exactly when [outcome] is [DrillOutcome.undecided].
class GameVerdict {
  const GameVerdict(this.outcome, this.ending);

  final DrillOutcome outcome;
  final GameEnding? ending;

  bool get isOver => outcome != DrillOutcome.undecided;

  static const undecided = GameVerdict(DrillOutcome.undecided, null);
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
///
/// The board is asked first and in a fixed order — mate, then stalemate, then
/// the draws by rule — so a position that satisfies two rules at once (a
/// stalemate with bare kings) is always named the same way. [resigned] loses
/// only a game the board has not already ended, and [plyCap] ends only a game
/// nothing else has: the plies are counted from the position the drill was
/// loaded at, which is what `game.history` holds after `Chess.fromFEN`.
GameVerdict verdictFor(
  chess.Chess game,
  chess.Color userColor, {
  int? plyCap,
  bool resigned = false,
}) {
  if (game.in_checkmate) {
    return GameVerdict(
      game.turn == userColor ? DrillOutcome.readerLost : DrillOutcome.readerWon,
      GameEnding.checkmate,
    );
  }
  if (game.in_stalemate) {
    return const GameVerdict(DrillOutcome.drawn, GameEnding.stalemate);
  }
  if (game.insufficient_material) {
    return const GameVerdict(
        DrillOutcome.drawn, GameEnding.insufficientMaterial);
  }
  if (game.in_threefold_repetition) {
    return const GameVerdict(
        DrillOutcome.drawn, GameEnding.threefoldRepetition);
  }
  if (game.half_moves >= 100) {
    return const GameVerdict(DrillOutcome.drawn, GameEnding.fiftyMoves);
  }
  if (resigned) {
    return const GameVerdict(DrillOutcome.readerLost, GameEnding.resignation);
  }
  if (plyCap != null && game.history.length >= plyCap) {
    return const GameVerdict(DrillOutcome.drawn, GameEnding.moveLimit);
  }
  return GameVerdict.undecided;
}

/// The outcome alone, for the callers that only ask who won. One rule: this
/// is [verdictFor] with the reason dropped, never a second reading.
DrillOutcome outcomeFor(chess.Chess game, chess.Color userColor) =>
    verdictFor(game, userColor).outcome;

/// How an ending is named to the reader. One home for the words, so the
/// drill's dialog, a homework's report and a tutorial's sentence agree.
String endingLabel(GameEnding ending) => switch (ending) {
      GameEnding.checkmate => 'checkmate',
      GameEnding.stalemate => 'stalemate',
      GameEnding.insufficientMaterial => 'not enough material to mate',
      GameEnding.threefoldRepetition => 'the same position three times',
      GameEnding.fiftyMoves => 'fifty moves without a capture or a pawn move',
      GameEnding.moveLimit => 'the move limit was reached',
      GameEnding.resignation => 'resignation',
    };

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
