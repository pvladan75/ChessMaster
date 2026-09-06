import 'package:chess_app/move_tree.dart';

/// What a lesson step's `pgn` comes to when it is read back against that step's
/// own `fen`.
///
/// One definition on purpose. The student's screen replays a step's line, and
/// the trainer's studio now checks a step before saving it — and a check that
/// parses the line differently from the reader proves nothing about the reader.
/// Both go through here.
///
/// The reason it exists at all: `MoveTree.parsePgn` skips a move it cannot play
/// and says nothing. A step whose `pgn` was written from one position and whose
/// `fen` names another therefore arrived as a tree with no moves in it —
/// indistinguishable, on screen, from a step that was always meant to be a
/// still picture. [rejectedMoves] is the difference between those two.
class LessonStepLine {
  const LessonStepLine({required this.line, required this.rejectedMoves});

  /// The main line, with each move's words, arrows and squares beside it.
  final PgnLine line;

  /// How many of the PGN's move tokens could not be played from the position
  /// the walk had reached. Anything above zero means the `pgn` and the `fen`
  /// describe different games.
  final int rejectedMoves;

  /// True when every move in the PGN belongs to this step's position.
  bool get replays => rejectedMoves == 0;

  /// A step with no line: a single position, which is most of what a lesson is.
  static const none = LessonStepLine(
    line: PgnLine(
      fens: [],
      movesSan: [],
      comments: [],
      arrows: [],
      squares: [],
    ),
    rejectedMoves: 0,
  );

  static LessonStepLine read({required String fen, String? pgn}) {
    if (pgn == null || pgn.trim().isEmpty) return none;
    try {
      final tree = MoveTree.parsePgn(pgn, startingFen: fen);
      if (tree == null) return none;
      return LessonStepLine(
        line: tree.mainLine(),
        rejectedMoves: tree.rejectedMoves,
      );
    } catch (_) {
      // A PGN this parser cannot open at all is not a line that disagrees with
      // its position; it is no line. The caller falls back to the still board.
      return none;
    }
  }
}
