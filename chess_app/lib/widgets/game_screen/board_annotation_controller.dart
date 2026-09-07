import 'package:chess_app/move_tree.dart';
import 'package:chess_app/theme/arrow_colors.dart';

/// What the next tap on a board means.
enum AnnotationMode {
  /// Taps belong to the game: pieces are moved, nothing is drawn.
  off,

  /// Two taps draw an arrow between them.
  arrow,

  /// One tap colours a square.
  square,
}

/// The drawing interaction of a board, with no widget and no board in it.
///
/// It exists because the room had it and the studio needed it. Until 7.9.2026
/// the whole of it — the mode flag, the pending square, the selected colour and
/// the toggle — was private inside `chess_game_screen.dart`, so the trainer's
/// authoring screen could show the arrows a lesson already carried and could
/// not draw one. A sixth private copy of a helper is how `playedMove` came to
/// be needed in the first place; this is the first copy, extracted before the
/// second was written.
///
/// **It holds the interaction, never the marks.** The marks belong to the node
/// the author is standing on, and the two screens keep two different node types
/// (`MoveNode` in the room, `AnalysisNode` in the studio) that happen to carry
/// the same two lists. So every operation is handed those lists and edits them
/// in place, and the caller decides what „changed" means — a `setState`, a
/// draft write, a socket broadcast. Each returns whether anything actually
/// changed, so a caller never records an event for a tap that did nothing.
class BoardAnnotationController {
  BoardAnnotationController({
    this.mode = AnnotationMode.off,
    String? colorCode,
  }) : colorCode = colorCode ?? ArrowColor.g.id;

  /// What a tap means right now.
  AnnotationMode mode;

  /// The colour the next mark is drawn in — an [ArrowColor] id, never a
  /// `Color`. What is stored in a PGN is the letter, and the palette is free to
  /// change what it looks like.
  String colorCode;

  /// The first square of an arrow that has been started and not finished.
  ///
  /// Only ever set in [AnnotationMode.arrow]. It is cleared by everything that
  /// could make it stale — a mode change, a colour change is deliberately not
  /// one of them — because an arrow half-drawn on a position the author has
  /// left is an arrow that lands somewhere nobody asked for.
  String? pendingFrom;

  bool get isDrawing => mode != AnnotationMode.off;

  /// Switches what a tap means, and forgets a half-drawn arrow.
  void setMode(AnnotationMode value) {
    mode = value;
    pendingFrom = null;
  }

  /// Leaves drawing mode. The same as `setMode(AnnotationMode.off)`, named for
  /// the callers that only ever do this.
  void stop() => setMode(AnnotationMode.off);

  /// Picks the colour of the *next* mark. Marks already drawn keep theirs.
  void setColor(String code) {
    colorCode = code;
  }

  /// Forgets a half-drawn arrow without leaving drawing mode.
  ///
  /// Called when the board moves under the author — a different node, a
  /// different part, a different position — because [pendingFrom] names a
  /// square on the board they were looking at.
  void cancelPending() {
    pendingFrom = null;
  }

  /// One tap on a square, in whatever mode the controller is in.
  ///
  /// Returns true when [arrows] or [squares] changed. In arrow mode the first
  /// tap only remembers, so it returns false; tapping the same square twice
  /// cancels and returns false too, which is how an author who started the
  /// wrong arrow gets out of it without drawing one.
  bool tap(
    String square, {
    required List<ChessArrow> arrows,
    required List<SquareMark> squares,
  }) {
    switch (mode) {
      case AnnotationMode.off:
        return false;
      case AnnotationMode.square:
        return _toggleSquare(square, squares);
      case AnnotationMode.arrow:
        final from = pendingFrom;
        if (from == null) {
          pendingFrom = square;
          return false;
        }
        pendingFrom = null;
        if (from == square) return false;
        return _toggleArrow(from, square, arrows);
    }
  }

  /// Draws the arrow, or takes it back if the same one is already there.
  ///
  /// Redrawing a square pair to remove it is what Lichess and chess.com do, and
  /// it is the only way to correct one arrow that does not go through the
  /// board's whole annotation. **The colour is deliberately not part of the
  /// match**: the mistake being corrected is usually „wrong arrow", not „right
  /// arrow, wrong colour", and having to remember which colour it was drawn in
  /// to erase it would be worse than the button it replaces. Carried over
  /// verbatim from the room, where that rule was already true.
  bool _toggleArrow(String from, String to, List<ChessArrow> arrows) {
    final existing = arrows.indexWhere((a) => a.from == from && a.to == to);
    if (existing >= 0) {
      arrows.removeAt(existing);
      return true;
    }
    arrows.add(ChessArrow(from: from, to: to, colorCode: colorCode));
    return true;
  }

  /// The same rule for a square: tapping a marked square unmarks it, whatever
  /// colour it was marked in.
  bool _toggleSquare(String square, List<SquareMark> squares) {
    final existing = squares.indexWhere((s) => s.square == square);
    if (existing >= 0) {
      squares.removeAt(existing);
      return true;
    }
    squares.add(SquareMark(square: square, colorCode: colorCode));
    return true;
  }

  /// Takes back the arrow drawn last on this node.
  ///
  /// Returns false when there was none, so the caller can say so rather than
  /// silently doing nothing — which is the behaviour the room already had.
  bool undoLastArrow(List<ChessArrow> arrows) {
    if (arrows.isEmpty) return false;
    arrows.removeLast();
    return true;
  }

  /// Takes back the square marked last on this node.
  bool undoLastSquare(List<SquareMark> squares) {
    if (squares.isEmpty) return false;
    squares.removeLast();
    return true;
  }

  /// Removes every arrow on this node, and nothing else.
  ///
  /// Separate from [clearMarks] because the room's button says „Izbriši sve
  /// strelice" and a button that also silently removed the coloured squares of
  /// an imported lesson would be a button that lies.
  bool clearArrows(List<ChessArrow> arrows) {
    if (arrows.isEmpty) return false;
    arrows.clear();
    return true;
  }

  /// Removes every mark on this node, arrows and squares alike.
  bool clearMarks({
    required List<ChessArrow> arrows,
    required List<SquareMark> squares,
  }) {
    if (arrows.isEmpty && squares.isEmpty) return false;
    arrows.clear();
    squares.clear();
    return true;
  }
}
