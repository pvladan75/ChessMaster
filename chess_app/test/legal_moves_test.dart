import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/legal_moves.dart';

/// **A pawn that reaches the last rank has to be able to become something.**
///
/// Reported live on 27.8.2026 in "Pronađite dobitni put": promotion did not
/// work, and the log said `Could not match move in chess.js legal moves!`.
///
/// The cause is one line missing in the package: `chess.dart`'s `make_pretty`
/// builds its verbose move map without a `promotion` key, while its own
/// documentation says it puts one there. Everything downstream believed the
/// documentation. The first test here is the package's behaviour itself,
/// because the day it changes, this file should say so rather than quietly
/// keep repairing something that no longer needs repairing.
void main() {
  /// White to move with a pawn on d7 and a free d8. From the user's own game.
  chess.Chess promotionPosition() =>
      chess.Chess.fromFEN('8/3P2P1/1R6/P3n2K/4k2P/1P6/8/8 w - - 5 23');

  test('the package still leaves the promotion out of its verbose map', () {
    final game = promotionPosition();
    final raw = game.moves({'verbose': true});
    final d8 = raw.firstWhere((m) => m['from'] == 'd7' && m['to'] == 'd8');

    expect(d8['promotion'], isNull,
        reason: 'ako ovo padne, paket je popravljen — proveri da li je ceo '
            'ovaj fajl još potreban');
    expect(d8['san'], contains('='), reason: 'SAN je jedino mesto gde piše');
  });

  test('a promotion map fed straight back to move() is refused', () {
    // The bug itself, in three lines. `move()` matches on
    // `move['promotion'] == candidate.promotion.name`, and a missing key never
    // equals 'q' — so the move is not played, `move()` says so, and every
    // caller in this app went on as though it had been.
    final game = promotionPosition();
    final raw = game.moves({'verbose': true});
    final d8 = raw.firstWhere((m) => m['from'] == 'd7' && m['to'] == 'd8');

    expect(game.move(d8), isFalse);
    expect(game.fen, promotionPosition().fen, reason: 'ništa se nije desilo');
  });

  test('the repaired list says what each promotion promotes to', () {
    final moves = legalMoves(promotionPosition());
    final d8 = moves.where((m) => m['from'] == 'd7' && m['to'] == 'd8');

    expect(d8.length, 4, reason: 'dama, top, lovac i skakač');
    expect(d8.map((m) => m['promotion']).toSet(), {'q', 'r', 'b', 'n'});
  });

  test('an ordinary move promotes to nothing, and says so', () {
    final moves = legalMoves(promotionPosition());
    final rookMove = moves.firstWhere((m) => m['from'] == 'b6');

    expect(rookMove['promotion'], '');
    // The point of '' rather than null: building a UCI string needs no special
    // case, which is what the callers were getting wrong.
    expect(
        '${rookMove['from']}${rookMove['to']}${rookMove['promotion']}'.length,
        4);
  });

  test('playMove plays the promotion the map names', () {
    for (final piece in kPromotionPieces) {
      final game = promotionPosition();
      final move = legalMoves(game).firstWhere((m) =>
          m['from'] == 'd7' && m['to'] == 'd8' && m['promotion'] == piece);

      expect(playMove(game, move), isTrue);
      expect(game.get('d8')?.type.name, piece,
          reason: 'podpromocija mora da preživi put do table');
    }
  });

  test('playMove leaves an ordinary move alone', () {
    final game = promotionPosition();
    final move = legalMoves(game)
        .firstWhere((m) => m['from'] == 'b6' && m['to'] == 'b7');

    expect(playMove(game, move), isTrue);
    expect(game.get('b7')?.type.name, 'r');
  });

  test('a promotion is recognised from the position, not from the rank', () {
    final game = promotionPosition();

    expect(isPromotionMove(game, 'd7', 'd8'), isTrue);
    expect(isPromotionMove(game, 'g7', 'g8'), isTrue);
    // The rook is on the eighth rank's file and moves along it without becoming
    // anything; asking the squares alone would get this wrong.
    expect(isPromotionMove(game, 'b6', 'b8'), isFalse);
    expect(isPromotionMove(game, 'h5', 'g6'), isFalse);
  });

  test('a capture that promotes counts too', () {
    // A pawn taking on the last rank is the promotion people forget: it never
    // stands on the square it promotes on.
    final game = chess.Chess.fromFEN('1n6/P7/8/8/8/8/8/K6k w - - 0 1');

    expect(isPromotionMove(game, 'a7', 'b8'), isTrue);
    final take = legalMoves(game).firstWhere(
        (m) => m['from'] == 'a7' && m['to'] == 'b8' && m['promotion'] == 'n');
    expect(playMove(game, take), isTrue);
    expect(game.get('b8')?.type.name, 'n');
  });

  test('a hand-built map that does carry a promotion is trusted', () {
    // Maps in this app do not all come from the package: some are read back
    // from a solution tree or a saved line.
    expect(promotionOf({'from': 'd7', 'to': 'd8', 'promotion': 'R'}), 'r');
    expect(promotionOf({'from': 'd7', 'to': 'd8', 'san': 'd8=N+'}), 'n');
    expect(promotionOf({'from': 'b6', 'to': 'b8', 'san': 'Rb8+'}), '');
    expect(promotionOf({}), '');
  });
}
