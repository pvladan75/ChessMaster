import 'package:chess/chess.dart' as chess;

class PgnGame {
  final List<String> movesSan;
  final List<String>
      fens; // fens[0] starting position, fens[1] after 1st move...

  PgnGame({required this.movesSan, required this.fens});
}

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
  static String sanitizeForLoadPgn(String pgn) {
    return pgn.replaceAll(RegExp(r'\d+\.\.\.'), '');
  }

  /// Removes PGN variations — everything between a `(` and its matching `)` —
  /// leaving the main line.
  ///
  /// This parser produces a linear list of positions, which is what the lesson
  /// viewer and the review session walk, and a variation written into a lesson
  /// by the studio is not part of that line. Left in, `load_pgn` reads the
  /// sideline's moves as if they continued the game: "1. e4 (1. d4 d5) e5"
  /// came back as e4, d5, e5 — a line nobody played, shown to a student as
  /// their homework.
  ///
  /// Counted rather than matched with a regular expression, because variations
  /// nest: a regex stops at the first `)` and leaves the outer one behind.
  static String stripVariations(String pgn) {
    final out = StringBuffer();
    var depth = 0;
    for (final rune in pgn.runes) {
      final ch = String.fromCharCode(rune);
      if (ch == '(') {
        depth++;
        continue;
      }
      if (ch == ')') {
        // An unbalanced ')' is a malformed PGN, not a reason to start deleting
        // the game: depth stays at zero and the character is simply dropped.
        if (depth > 0) depth--;
        continue;
      }
      if (depth == 0) out.write(ch);
    }
    return out.toString();
  }

  static PgnGame? parse(String pgn) {
    if (pgn.trim().isEmpty) return null;

    // Pre-clean PGN tags and annotations
    var cleaned = pgn;
    // Remove lines starting with [ and ending with ] (PGN tags)
    cleaned = cleaned.replaceAll(RegExp(r'\[.*\]'), '');
    // Remove comments in curly braces { ... }
    cleaned = cleaned.replaceAll(RegExp(r'\{[\s\S]*?\}'), '');
    // And then variations, once no stray bracket inside a comment can be
    // mistaken for one.
    cleaned = stripVariations(cleaned);
    // Remove inline comments with semicolon ;
    cleaned = cleaned.replaceAll(RegExp(r';.*'), '');
    // Remove game result markers (1-0, 0-1, 1/2-1/2, *)
    cleaned = cleaned.replaceAll(RegExp(r'\b(1-0|0-1|1/2-1/2|\*)\b'), '');

    // Attempt 1: Standard load_pgn
    try {
      final game = chess.Chess();
      final success = game.load_pgn(cleaned);
      if (success) {
        final historyMoves = List.from(game.history);
        final List<String> fens = [];
        final List<String> movesSan = [];

        // Reset and gather FENs/SANs
        game.reset();
        fens.add(game.fen);

        for (var entry in historyMoves) {
          final m = entry.move;
          final san = game.move_to_san(m);
          game.make_move(m);
          fens.add(game.fen);
          movesSan.add(san);
        }

        if (movesSan.isNotEmpty) {
          return PgnGame(movesSan: movesSan, fens: fens);
        }
      }
    } catch (_) {
      // Failed standard load_pgn, falling back to manual parse
    }

    try {
      final tokens = cleaned.split(RegExp(r'\s+'));
      final game = chess.Chess();
      final List<String> fens = [game.fen];
      final List<String> movesSan = [];

      for (var token in tokens) {
        token = token.trim();
        if (token.isEmpty) continue;

        // Skip move numbering like "1.", "2.", "1...", "24."
        if (RegExp(r'^\d+(\.+)?$').hasMatch(token)) {
          continue;
        }

        try {
          final success = game.move(token);
          if (success) {
            movesSan.add(token);
            fens.add(game.fen);
          }
        } catch (_) {
          // Skip invalid move tokens
        }
      }

      if (movesSan.isNotEmpty) {
        return PgnGame(movesSan: movesSan, fens: fens);
      }
    } catch (_) {
      // Fallback failed
    }

    return null;
  }
}
