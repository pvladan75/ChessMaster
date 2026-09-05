/// One quirk-fix for PGN text, and nothing else any more.
///
/// This file used to hold a second parser: `PgnParser.parse` replayed a PGN into
/// a flat list of positions after deleting `{comments}` and `(variations)`, and
/// `stripVariations` existed to stop `chess.load_pgn` reading a sideline as the
/// game. Both were removed in phase 2 of `docs/PLAN-INTERAKTIVNA-LEKCIJA.md`.
///
/// They were not switched off, they were deleted, and deliberately: while a
/// parser that throws away comments, branches and arrows still exists, the next
/// screen that needs a line can call it — and everything an interactive lesson
/// is made of is exactly what it discards. `MoveTree.parsePgn` reads all of it
/// and `MoveTree.mainLine()` flattens it when a screen wants a line, so there is
/// one reader and one place to fix.
class PgnParser {
  /// Neutralises a quirk in the `chess` package's own `load_pgn`: it strips
  /// plain move numbers ("12.") with a naive regex, but PGN convention writes
  /// a resumed black move as "12..." whenever a comment interrupts the pair —
  /// and every game exported from Chess.com carries a `{[%clk ..]}` comment
  /// after each move, so this hits every single import from there. The naive
  /// regex only eats the first dot, leaving ".." behind as a stray token that
  /// then fails to parse as a move and rejects the whole PGN.
  ///
  /// Removing the elided-number pattern ourselves, before handing the PGN to
  /// `load_pgn`, leaves it exactly as if the black move had never been
  /// interrupted — headers and comments are untouched.
  ///
  /// Still here because the Analysis Studio hands PGN to `load_pgn` directly.
  static String sanitizeForLoadPgn(String pgn) {
    return pgn.replaceAll(RegExp(r'\d+\.\.\.'), '');
  }
}
