/// Legal moves that say which piece a promotion promotes to.
///
/// `chess.dart`'s own verbose list does not. `make_pretty` builds its map out of
/// `san`, `to`, `from`, `captured` and `flags` — **and nothing else** — while
/// the documentation two lines above it says "the piece, captured, and
/// promotion fields contain the lowercase representation of the applicable
/// piece". So `m['promotion']` is always `null`, for every move, in every
/// position, and reading it tells you nothing.
///
/// That has cost this app every promotion it has ever tried to play through one
/// of those maps, in two different ways:
///
///   * a map handed back to `game.move(m)` **is refused** when the move is a
///     promotion, because `move()` matches `move['promotion'] ==
///     moves[i].promotion!.name` and a missing key is not `'q'`. The move
///     simply does not happen, `move()` returns `false`, and every caller here
///     went on as if it had;
///   * `where((m) => m['promotion'] != null)` selects nothing, so code looking
///     for the promotion among the legal moves concludes there is none.
///
/// Reported live on 27.8.2026 from "Pronađite dobitni put": the pawn would not
/// promote, and the log said `Could not match move in chess.js legal moves!` —
/// the board had a queen on d8 and no legal move the app could build agreed
/// with it, because every candidate it tried was played without a promotion and
/// therefore not played at all.
///
/// The repair is read out of the SAN, which is in the map and does carry it:
/// `d8=Q+` promotes to a queen. Deliberately not read by re-generating the move
/// list a second time as objects and pairing the two by index — that would be
/// two lists trusted to be in the same order, which is the kind of quiet
/// assumption this codebase keeps paying for.
library;

import 'package:chess/chess.dart' as chess;

/// The four pieces a pawn may become, in the order a person expects them.
const List<String> kPromotionPieces = ['q', 'r', 'b', 'n'];

/// What [move] promotes to, lowercase, or `''` when it is not a promotion.
///
/// Takes a verbose move map from `chess.dart` — see the note above on why the
/// map's own `promotion` key cannot be used.
String promotionOf(Map move) {
  final direct = move['promotion'];
  if (direct != null && direct.toString().isNotEmpty) {
    // A map somebody built by hand, or a future version of the package that
    // fills this in. Trust it over the SAN.
    return direct.toString().toLowerCase();
  }

  final san = move['san']?.toString() ?? '';
  final at = san.indexOf('=');
  if (at == -1 || at + 1 >= san.length) return '';
  final piece = san[at + 1].toLowerCase();
  return kPromotionPieces.contains(piece) ? piece : '';
}

/// The legal moves in [game], each one carrying its `promotion`.
///
/// A drop-in replacement for `game.moves({'verbose': true})`: same maps, with
/// the key the package leaves out filled in — `''` for an ordinary move, so
/// `'$from$to${m['promotion']}'` builds the UCI string without a special case.
List<Map<String, dynamic>> legalMoves(chess.Chess game) {
  final moves = game.moves({'verbose': true});
  return [
    for (final move in moves)
      if (move is Map)
        <String, dynamic>{
          ...Map<String, dynamic>.from(move),
          'promotion': promotionOf(move),
        }
  ];
}

/// Plays a verbose move map, promotion included.
///
/// Use this rather than `game.move(m)` wherever `m` came from a legal-move
/// list: without the promotion key that call is a silent no-op on exactly the
/// moves that matter most to a beginner.
bool playMove(chess.Chess game, Map move) {
  final promotion = promotionOf(move);
  return game.move({
    'from': move['from'],
    'to': move['to'],
    // Harmless on an ordinary move: `move()` only compares this when the
    // candidate is a promotion.
    if (promotion.isNotEmpty) 'promotion': promotion,
  });
}

/// Whether moving from [from] to [to] in [game] is a promotion.
///
/// Asked of the position rather than of the squares, so a pawn that reaches the
/// last rank by capturing counts and a rook shuffling along the eighth does
/// not.
bool isPromotionMove(chess.Chess game, String from, String to) {
  for (final move in game.moves({'verbose': true})) {
    if (move is! Map) continue;
    if (move['from'] != from || move['to'] != to) continue;
    if (promotionOf(move).isNotEmpty) return true;
  }
  return false;
}

/// What the move [from]→[to] is called and where it leaves the board.
///
/// Null when it is not legal in [fen], so a board that reported a move its
/// position does not allow is answered by reloading rather than by growing a
/// line out of a move nobody can play.
///
/// [promotion] is `''` for an ordinary move and one of `q r b n` otherwise; it
/// is defaulted to a queen only where the move is a promotion and the caller
/// said nothing, which is what every board in this app already does.
///
/// It exists because the same fifteen lines — play it, read the SAN back, undo
/// — are written five times in `lib/` already (`_sanFor`, in the lesson viewer,
/// the step editor, the puzzle solver, the endgame trainer and the tactics
/// trainer), and each copy answers only half the question: the SAN, never the
/// position it leads to, so its caller keeps a second game object beside it to
/// find that out. New screens use this one. Folding the five existing copies
/// onto it is a separate chore, deliberately not done inside a batch about
/// something else.
({String san, String uci, String fen})? playedMove({
  required String fen,
  required String from,
  required String to,
  String promotion = '',
}) {
  try {
    final game = chess.Chess.fromFEN(fen);
    final piece = promotion.isEmpty ? 'q' : promotion.toLowerCase();
    if (!game.move({'from': from, 'to': to, 'promotion': piece})) return null;

    final made = game.history.last.move;
    // Read back rather than assumed: `made.promotion` is what the position
    // actually promoted to, and it is null on every ordinary move.
    final promoted = made.promotion?.name ?? '';
    final afterFen = game.fen;
    game.undo_move();
    return (
      san: game.move_to_san(made),
      uci: '$from$to$promoted',
      fen: afterFen,
    );
  } catch (_) {
    return null;
  }
}
