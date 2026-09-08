import 'package:chess/chess.dart' as chess;

/// Whether a FEN is not merely well written but a **possible game**.
///
/// `chess.Chess.validate_fen` checks the notation only: the number of squares,
/// the permitted letters, correct castling rights and en passant. It checks no
/// rule of the game — the word "king" does not appear in it once. A position
/// with no king therefore parses cleanly, passes as valid, reaches the engine,
/// and that is where the application falls over.
///
/// Found live 30.8.2026: a position is set up by hand with no king, imported
/// into the Studio, the engine is switched on — and the app crashes. The fault
/// is not in the engine but here: it was handed something that is not chess.
///
/// Returns `null` when all is well, or the reason when it is not.
///
/// Translated on 8.9.2026 with the English pivot. It had been missed by every
/// sweep, and the reason is worth keeping: its Serbian was written **without
/// diacritics** — "vise", "pesaka", "moze" — so `gate_english_ui`, which looks
/// for `čćžšđ`, could not see a single line of it.
String? fenIllegalReason(String fen) {
  final text = fen.trim();
  if (text.isEmpty) return 'No FEN given.';

  // The notation first, because everything below assumes it can be read.
  try {
    final check = chess.Chess.validate_fen(text);
    if (check['valid'] != true) return 'Malformed FEN.';
  } catch (_) {
    return 'Malformed FEN.';
  }

  final fields = text.split(RegExp(r'\s+'));
  final board = fields.first;

  // Exactly one king of each colour. Neither none nor two — for the engine two
  // white kings are as impossible as none, they just break it somewhere else.
  final white = 'K'.allMatches(board).length;
  final black = 'k'.allMatches(board).length;
  if (white == 0 && black == 0) return 'There are no kings on the board.';
  if (white == 0) return 'The white king is missing.';
  if (black == 0) return 'The black king is missing.';
  if (white > 1) return 'There is more than one white king on the board.';
  if (black > 1) return 'There is more than one black king on the board.';

  // How much of what is on the board. Only the first FEN field is counted;
  // digits are empty squares and do not matter.
  int count(String letter) => letter.allMatches(board).length;

  for (final side in const [
    ('White', 'PNBRQK'),
    ('Black', 'pnbrqk'),
  ]) {
    final name = side.$1;
    final letters = side.$2;
    final pawns = count(letters[0]);
    final total = letters.split('').fold<int>(0, (n, c) => n + count(c));

    // Eight pawns is everything you start with; a ninth comes from nowhere.
    if (pawns > 8) return 'Too many pawns for $name: $pawns.';
    // Sixteen pieces is the whole army. More than that is not a game.
    if (total > 16) return 'Too many pieces for $name: $total.';

    // And the thing that ties those two numbers together: every piece beyond
    // the starting set must have come from a promotion, and a promotion spends
    // a pawn. So a spare queen and eight pawns cannot both be there — without
    // this, 8 pawns and 3 queens would pass, because neither number is on its
    // own too large.
    final spare = [
      (count(letters[4]) - 1), // queens
      (count(letters[3]) - 2), // rooks
      (count(letters[2]) - 2), // bishops
      (count(letters[1]) - 2), // knights
    ].map((n) => n > 0 ? n : 0).fold<int>(0, (a, b) => a + b);

    if (spare > 8 - pawns) {
      return '$name has too few pawns for that many promotions '
          '($pawns on the board, and $spare promotions would be needed).';
    }
  }

  // A pawn on the first or the last rank cannot arise in a game: it only ever
  // reaches the eighth rank in order to promote at once.
  final ranks = board.split('/');
  if (ranks.length == 8) {
    for (final r in [0, 7]) {
      if (ranks[r].contains('P') || ranks[r].contains('p')) {
        return 'A pawn cannot stand on the ${r == 0 ? 'eighth' : 'first'} rank.';
      }
    }
  }

  // The side that is *not* to move must not already be in check: that would
  // mean the previous move left a king under attack, which no game can produce.
  // The engine does not accept such a position.
  try {
    final game = chess.Chess.fromFEN(text);
    final toMove = game.turn;
    final opponent =
        toMove == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;
    if (game.king_attacked(opponent)) {
      return 'The side that is not to move is in check — no game can reach '
          'that position.';
    }
  } catch (_) {
    return 'The position cannot be read.';
  }

  return null;
}

/// The short check, for places that only want yes or no.
bool isFenLegal(String fen) => fenIllegalReason(fen) == null;
