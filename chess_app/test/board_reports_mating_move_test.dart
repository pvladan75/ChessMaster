import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// Diagram 97 of the trainer's scanned set: white mates with Qf1#.
const _mateInOne = '5Q2/8/8/8/6p1/8/2NNk3/2K5 w - - 0 1';

void main() {
  test('the mating move is still reported, though no moves remain after it',
      () {
    // The board used to ask whether any legal moves *remained* and read "none"
    // as "nothing was played". Checkmate is exactly that case — and checkmate
    // is the answer to every mate-in-one exercise, so the child's correct move
    // was the one move the board never told anybody about.
    final game = chess.Chess.fromFEN(_mateInOne);
    game.move({'from': 'f8', 'to': 'f1', 'promotion': 'q'});

    expect(game.moves(), isEmpty,
        reason: 'this is the trap: mate leaves no moves');
    expect(game.in_checkmate, isTrue);

    final played = ChessBoardWithOverlay.lastMoveSquares(game);
    expect(played, isNotNull);
    expect(played!.from, 'f8');
    expect(played.to, 'f1');
  });

  test('an ordinary move is reported the same way', () {
    final game = chess.Chess.fromFEN(_mateInOne);
    game.move({'from': 'f8', 'to': 'f2', 'promotion': 'q'});
    final played = ChessBoardWithOverlay.lastMoveSquares(game);
    expect(played?.from, 'f8');
    expect(played?.to, 'f2');
  });

  test('a stalemating move is reported too, for the same reason', () {
    // Not a puzzle answer, but the same shape of ending: no moves remain and
    // somebody still has to hear what was played.
    final game = chess.Chess.fromFEN('7k/8/8/8/8/8/5Q2/7K w - - 0 1');
    game.move({'from': 'f2', 'to': 'f7', 'promotion': 'q'});
    expect(game.moves(), isEmpty);
    expect(ChessBoardWithOverlay.lastMoveSquares(game), isNotNull);
  });

  test('nothing played means nothing reported', () {
    final game = chess.Chess.fromFEN(_mateInOne);
    expect(ChessBoardWithOverlay.lastMoveSquares(game), isNull);
  });
}
