/// Where the text of an exported PGN came from.
///
/// T1 of `docs/PLAN-PGN-TEKST.md`. A model rather than part of the exporter's
/// file, so that a screen can read the map without importing the writer:
/// `test/tutorial_authoring_test.dart` fails if anything under
/// `lib/features/tutorial_studio/` reaches for `PgnExporterService`, and it is
/// right to — the pairing of a step's `fen` and `pgn` has one home, and that is
/// `StudioLessonStep`.
library;

/// What a span of exported PGN text is about.
enum PgnSpanKind {
  /// The move token itself. The number prefix is **not** part of it and the NAG
  /// is: `1. e4!` spans `e4!`.
  move,

  /// The whole `{ … }`, braces included — what the trainer wrote and what they
  /// drew, since both live in one comment.
  comment,
}

/// Where one node's text sits inside an exported PGN.
///
/// T1 of `docs/PLAN-PGN-TEKST.md`. The right-click menu on the „PGN" tab has to
/// answer „which move is the caret in", and this is that answer — produced by
/// the **writer**, which knows exactly where it wrote each node, rather than by
/// re-tokenising the text afterwards. `MoveTree.parsePgn` rewrites its input
/// before splitting it, so offsets into what it parses do not point at the
/// trainer's text; and teaching the one parser to carry offsets, for the sake
/// of a menu, is not a trade worth making.
class PgnSpan {
  const PgnSpan({
    required this.nodeId,
    required this.kind,
    required this.start,
    required this.end,
  });

  /// [AnalysisNode.id] of the node this text belongs to.
  final String nodeId;

  final PgnSpanKind kind;

  /// Offsets into the **returned** PGN string: [start] inclusive, [end]
  /// exclusive, so `pgn.substring(start, end)` is exactly this token.
  final int start;
  final int end;

  /// A caret at either edge counts as inside.
  ///
  /// A text cursor sits *between* characters, and the one just after `e4` is
  /// what somebody means when they have clicked at the end of the move.
  bool contains(int offset) => offset >= start && offset <= end;
}

/// An export, and the map of where everything in it came from.
class PgnWithSpans {
  const PgnWithSpans({required this.pgn, required this.spans});

  final String pgn;

  /// In writing order, and never overlapping.
  final List<PgnSpan> spans;

  /// The node whose text contains [offset], or null.
  ///
  /// **Null rather than the nearest guess.** The whitespace between two moves
  /// belongs to neither of them, and a menu that put an arrow on „whichever
  /// move was nearest" would put it on the wrong one often enough to be worse
  /// than no menu at all. A caller offers nothing where this answers nothing.
  String? nodeIdAt(int offset) => spanAt(offset)?.nodeId;

  /// The span containing [offset], for a caller that needs to know whether the
  /// caret is in a move or in its comment.
  PgnSpan? spanAt(int offset) {
    for (final span in spans) {
      if (span.contains(offset)) return span;
    }
    return null;
  }
}
