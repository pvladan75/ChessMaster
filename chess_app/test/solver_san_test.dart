import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';

/// The move the student drags has to reach the server as SAN, and the chess
/// package will only produce it from the position *before* the move. Asked
/// afterwards it throws — and inside an async handler that exception is
/// invisible, which is how a child's move silently did nothing at all.
String? sanFor(String fen, String from, String to) {
  try {
    final game = chess.Chess.fromFEN(fen);
    if (!game.move({'from': from, 'to': to, 'promotion': 'q'})) return null;
    final made = game.history.last.move;
    game.undo_move();
    return game.move_to_san(made);
  } catch (_) {
    return null;
  }
}

const _mateInOne = '5Q2/8/8/8/6p1/8/2NNk3/2K5 w - - 0 1';

void main() {
  test('asking after the move throws — the bug this guards against', () {
    final game = chess.Chess.fromFEN(_mateInOne);
    game.move({'from': 'f8', 'to': 'f1', 'promotion': 'q'});
    expect(() => game.move_to_san(game.history.last.move), throwsA(anything),
        reason: 'if this ever stops throwing the workaround can go');
  });

  test('asking before the move gives the move the server expects', () {
    expect(sanFor(_mateInOne, 'f8', 'f1'), 'Qf1#');
  });

  test('an illegal drag produces nothing rather than a wrong move', () {
    // f8 and a1 share neither a line nor a diagonal, and there is no piece on
    // a2 to drag in the first place.
    expect(sanFor(_mateInOne, 'f8', 'a1'), isNull);
    expect(sanFor(_mateInOne, 'a2', 'a3'), isNull);
  });

  test('a legal move that is not the solution still becomes SAN', () {
    // Judging is the server's job; this only has to report what was played.
    expect(sanFor(_mateInOne, 'f8', 'f2'), 'Qf2+');
  });

  test('a nonsense position produces nothing rather than throwing', () {
    expect(sanFor('ovo nije fen', 'e2', 'e4'), isNull);
  });

  test('black to move is read from the position, not assumed', () {
    const black = '6R1/5k2/8/4K3/8/7Q/8/8 b - - 0 1';
    expect(sanFor(black, 'f7', 'e7'), 'Ke7');
  });
}
