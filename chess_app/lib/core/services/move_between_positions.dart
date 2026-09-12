import 'package:chess/chess.dart' as chess;

/// The move that turns [beforeFen] into [afterFen], or null if no single legal
/// move does.
///
/// ## Why this exists
///
/// Phase 2 of `docs/PLAN-OZNAKE-NA-TABLI.md` set out to make every board draw
/// its own last move instead of waiting to be told, by reading the move out of
/// the game's history. That works, and on nine of the ten screens it was
/// written for it is a no-op — because **`loadFen` clears the history**, and
/// those screens drive their board by loading a position rather than by playing
/// a move on it. The tactics trainer is the pattern: it plays the move on its
/// own `chess.Chess`, then calls `_boardController.loadFen(game.fen)` to put
/// the board in step. Measured, not reasoned about: after the drag the history
/// holds `e2e4`, and after the sync it is empty.
///
/// So the board has to work out what changed, and the only honest way to do
/// that is to ask the rules.
///
/// ## Why it searches legal moves instead of diffing squares
///
/// Comparing the two placements square by square looks cheaper and is a second
/// set of chess rules: castling moves two pieces, en passant empties a square
/// no piece arrived on, promotion changes what a piece *is*. Every one of those
/// is a special case somebody has to remember, and this repository has paid for
/// a second implementation of a rule more than once — most recently a server
/// module rewritten from scratch when a better one already existed in the app.
///
/// Generating the legal moves and asking which of them produces the position in
/// front of us needs no special cases at all: `chess.dart` already knows how
/// every one of them works. It is also unambiguous — from a given position, two
/// different legal moves cannot leave the pieces in the same places.
///
/// ## What it deliberately answers null to
///
/// A position that is not one move away. Loading an unrelated puzzle, jumping
/// to another node of a tree, taking a move back, or setting a board up by hand
/// are all "no move was played here", and a mark on two squares nobody moved
/// between would be a lie about the position. Null is the answer for a FEN that
/// is not one, too: these come from stored tutorials and from a screen's own
/// model.
///
/// ## `chess.Chess.fromFEN` does not throw, and that is the trap
///
/// Measured, because the first version of this function guessed: handed `''`,
/// `'not a fen'`, `'////////'`, a rank of nine pawns or a board of four ranks,
/// it returns **an empty board** and reports no error at all. So a `try`/`catch`
/// around it is dead code, and the check that actually matters is the one after
/// it — that the board took the position it was given. Without it a FEN this
/// function could not read would quietly become "no pieces anywhere", which has
/// no legal moves, which looks exactly like "nothing was played".
({String from, String to})? moveBetweenPositions(
    String beforeFen, String afterFen) {
  // One early exit, and it is the only guard in this function. Mutation says it
  // cannot be made to fail — a null `wanted` would never equal a real board's
  // placement, so the loop already answers null — and it stays because it says
  // the contract here rather than two steps away in a library's failure mode.
  // `beforeFen` is deliberately **not** checked: see the note below.
  final wanted = placementOf(afterFen);
  if (wanted == null) return null;

  // No second guard on what `fromFEN` made of it, and the reason is worth
  // writing down rather than rediscovering: its failure answer is an **empty
  // board**, which has no king, which generates no moves — so a position this
  // function cannot read already falls out of the loop below with null. A check
  // here could not be made to fail, and two guards that prove the same thing
  // prove neither. The property it leans on is pinned instead, in the
  // nine-pawns test, which fails if the engine ever starts answering something
  // else.
  final board = chess.Chess.fromFEN(beforeFen);

  for (final move in board.generate_moves()) {
    board.make_move(move);
    final reached = placementOf(board.fen);
    board.undo_move();
    if (reached == wanted) {
      return (from: move.fromAlgebraic, to: move.toAlgebraic);
    }
  }
  return null;
}

/// Where the pieces are, and whose turn it is — the first two fields of a FEN.
///
/// **The move counters are deliberately not compared.** A screen loading a
/// position it built itself may write a different halfmove clock from the one
/// the engine would, and two positions that differ only in a counter are the
/// same position as far as anything drawn on a board is concerned. The side to
/// move *is* compared, because a position reached by a move always hands the
/// turn over, and without it a null move would look like a match.
///
/// Castling rights and the en-passant square are left out for the same reason
/// as the counters: they are bookkeeping a screen may not have got exactly
/// right, and the placement plus the turn already identifies the move uniquely.
///
/// Null for anything that is not a FEN with at least those two fields.
String? placementOf(String fen) {
  final parts = fen.trim().split(RegExp(r'\s+'));
  if (parts.length < 2) return null;
  final placement = parts[0];
  final turn = parts[1];
  if (turn != 'w' && turn != 'b') return null;
  // Eight ranks, and nothing but the characters a placement is made of. A
  // cheap shape check, so a sentence that happens to contain a space does not
  // reach `fromFEN`.
  final ranks = placement.split('/');
  if (ranks.length != 8) return null;
  if (!RegExp(r'^[pnbrqkPNBRQK1-8]+$')
      .hasMatch(placement.replaceAll('/', ''))) {
    return null;
  }
  return '$placement $turn';
}
