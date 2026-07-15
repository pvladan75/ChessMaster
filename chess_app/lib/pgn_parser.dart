import 'package:chess/chess.dart' as chess;

class PgnGame {
  final List<String> movesSan;
  final List<String> fens; // fens[0] starting position, fens[1] after 1st move...

  PgnGame({required this.movesSan, required this.fens});
}

class PgnParser {
  static PgnGame? parse(String pgn) {
    if (pgn.trim().isEmpty) return null;

    // Pre-clean PGN tags and annotations
    var cleaned = pgn;
    // Remove lines starting with [ and ending with ] (PGN tags)
    cleaned = cleaned.replaceAll(RegExp(r'\[.*\]'), '');
    // Remove comments in curly braces { ... }
    cleaned = cleaned.replaceAll(RegExp(r'\{[\s\S]*?\}'), '');
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
