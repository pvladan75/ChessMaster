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

/// Every square from [from] to [to] inclusive, when the two stand on one line
/// of the board, and null when they do not.
///
/// A file (`a2`-`a7`), a rank (`a2`-`e2`) or a diagonal (`a2`-`d5`). **A pair
/// that is none of the three answers null rather than a rectangle**: inferring
/// a block from two corners would surprise anyone who mis-clicked, and a
/// rectangle is a different feature that can be asked for on its own.
///
/// The order is from [from] towards [to], which nothing depends on today and
/// which is worth keeping anyway: a caller that wanted to colour a line by
/// degrees would need it, and an arbitrary order is harder to test.
List<String>? squaresBetween(String from, String to) {
  final a = _coordsOf(from);
  final b = _coordsOf(to);
  if (a == null || b == null) return null;

  final df = b.file - a.file;
  final dr = b.rank - a.rank;
  if (df == 0 && dr == 0) return [from];

  final straight = df == 0 || dr == 0;
  final diagonal = df.abs() == dr.abs();
  if (!straight && !diagonal) return null;

  final stepFile = df == 0 ? 0 : df ~/ df.abs();
  final stepRank = dr == 0 ? 0 : dr ~/ dr.abs();
  final steps = df.abs() > dr.abs() ? df.abs() : dr.abs();

  return [
    for (var i = 0; i <= steps; i++)
      _nameOf(a.file + stepFile * i, a.rank + stepRank * i),
  ];
}

({int file, int rank})? _coordsOf(String square) {
  if (square.length != 2) return null;
  final file = square.codeUnitAt(0) - 0x61; // 'a'
  final rank = square.codeUnitAt(1) - 0x31; // '1'
  if (file < 0 || file > 7 || rank < 0 || rank > 7) return null;
  return (file: file, rank: rank);
}

String _nameOf(int file, int rank) =>
    String.fromCharCode(0x61 + file) + String.fromCharCode(0x31 + rank);

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

  /// Whether the next two taps name a line of squares rather than one square.
  ///
  /// A mode rather than a modifier key, and that is the whole design decision
  /// here. SHIFT is the obvious way in and it does not exist on a phone, so a
  /// SHIFT-only range would ship this to half the users — Android is a real
  /// target. The screen sets this from a button in the annotation bar, and
  /// passes `asRange: true` to [tap] when either that button or SHIFT says so:
  /// one code path, two ways to reach it.
  ///
  /// Only meaningful in [AnnotationMode.square]; an arrow already takes two
  /// taps and means something else by them.
  bool rangeMode = false;

  /// The first square of a range that has been started and not finished.
  ///
  /// Cleared by everything that could make it stale, for the same reason
  /// [pendingFrom] is: a half-named line on a position the author has left is a
  /// line that lands somewhere nobody asked for.
  String? pendingRangeFrom;

  /// The first square of an arrow that has been started and not finished.
  ///
  /// Only ever set in [AnnotationMode.arrow]. It is cleared by everything that
  /// could make it stale — a mode change, a colour change is deliberately not
  /// one of them — because an arrow half-drawn on a position the author has
  /// left is an arrow that lands somewhere nobody asked for.
  String? pendingFrom;

  bool get isDrawing => mode != AnnotationMode.off;

  /// Switches what a tap means, and forgets a half-drawn arrow or range.
  void setMode(AnnotationMode value) {
    mode = value;
    pendingFrom = null;
    pendingRangeFrom = null;
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
    pendingRangeFrom = null;
  }

  /// One tap on a square, in whatever mode the controller is in.
  ///
  /// Returns true when [arrows] or [squares] changed. In arrow mode the first
  /// tap only remembers, so it returns false; tapping the same square twice
  /// cancels and returns false too, which is how an author who started the
  /// wrong arrow gets out of it without drawing one.
  ///
  /// [asRange] makes two taps in square mode name a line rather than two
  /// squares. The caller passes it when its own range button is on **or** when
  /// SHIFT is held, which is why this is an argument and not read off
  /// [rangeMode] here: one code path, and the desktop shortcut is not a second
  /// implementation of it.
  bool tap(
    String square, {
    required List<ChessArrow> arrows,
    required List<SquareMark> squares,
    bool asRange = false,
  }) {
    switch (mode) {
      case AnnotationMode.off:
        return false;
      case AnnotationMode.square:
        if (!asRange) {
          // A range half-started and then abandoned by turning the button off
          // must not colour a line on the next ordinary tap.
          pendingRangeFrom = null;
          return _toggleSquare(square, squares);
        }
        final start = pendingRangeFrom;
        if (start == null) {
          pendingRangeFrom = square;
          return false;
        }
        pendingRangeFrom = null;
        return _applyRange(start, square, squares);
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

  /// A line of squares, all set to the current colour — or cleared, when every
  /// one of them is already marked.
  ///
  /// **It sets rather than toggling each square**, and that is not a detail. A
  /// range drawn over a half-marked file would otherwise come out
  /// checkerboarded, which is nobody's intention and takes another range to
  /// undo. Repeating the same range when all of it is already marked clears it,
  /// so one gesture is still reversible by itself.
  ///
  /// "Already marked" ignores the colour, exactly as [_toggleSquare] does:
  /// the mistake being corrected is „wrong squares", not „right squares, wrong
  /// colour", and having to remember which colour they were drawn in would be
  /// worse than the button it replaces.
  ///
  /// A pair that is not on one line marks **only the square just tapped** —
  /// see [squaresBetween] for why that rather than a rectangle.
  bool _applyRange(String from, String to, List<SquareMark> squares) {
    final line = squaresBetween(from, to) ?? [to];
    final marked = squares.map((s) => s.square).toSet();

    if (line.every(marked.contains)) {
      final before = squares.length;
      squares.removeWhere((s) => line.contains(s.square));
      return squares.length != before;
    }

    var changed = false;
    for (final square in line) {
      final at = squares.indexWhere((s) => s.square == square);
      if (at >= 0) {
        if (squares[at].colorCode == colorCode) continue;
        squares[at] = SquareMark(square: square, colorCode: colorCode);
      } else {
        squares.add(SquareMark(square: square, colorCode: colorCode));
      }
      changed = true;
    }
    return changed;
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
