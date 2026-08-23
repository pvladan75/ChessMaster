import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/features/endgame_trainer/models/endgame_puzzle.dart';

/// A real row from the mined database: Kamsky 2009, rook and pawn against rook,
/// black to hold. Two different moves draw, and that is the point of it being
/// the fixture here rather than a one-answer position.
EndgamePuzzle twoWaysToDraw() => EndgamePuzzle.fromJson({
      'puzzle_id': 'eg_7c7c0ad46d254d4d',
      'fen': '8/5pk1/8/8/8/8/5PK1/r7 b - - 0 55',
      'type': 'RookPawnVsRook',
      'mode': 'draw',
      'winning_moves': ['a1f1', 'a1e1'],
      'solution': ['a1f1', 'g2g3', 'g7g6'],
      'solution_san': ['Rf1+', 'Kg3', 'Kg6'],
      'piece_count': 5,
      'pawn_count': 1,
      'source': 'syzygy',
      'difficulty': 'medium',
      'difficulty_score': 5,
      'dtz': -18,
      'game': {'white': 'Kamsky,G', 'black': 'Shulman,Y', 'date': '2009.03.20'},
    });

void main() {
  group('EndgamePuzzle', () {
    test('parses the server payload', () {
      final puzzle = twoWaysToDraw();

      expect(puzzle.id, 'eg_7c7c0ad46d254d4d');
      expect(puzzle.mode, EndgameMode.draw);
      expect(puzzle.winningMoves, ['a1f1', 'a1e1']);
      expect(puzzle.isPlayable, isTrue);
      expect(puzzle.isExact, isTrue);
      expect(puzzle.whiteToMove, isFalse);
      expect(puzzle.game!.label, 'Kamsky,G - Shulman,Y, 2009');
    });

    test(
        'a five-piece tablebase position can be played out, an estimate cannot',
        () {
      expect(twoWaysToDraw().canBePlayedOut, isTrue);

      final estimated = EndgamePuzzle.fromJson({
        'puzzle_id': 'x',
        'fen': '8/4k3/8/1p2Pp2/p7/P1K1P3/1P6/8 w - - 1 42',
        'winning_moves': ['c3d3'],
        'piece_count': 9,
        'source': 'engine',
      });
      expect(estimated.canBePlayedOut, isFalse);
      // Defaults to win when the server says nothing, which is the safer read:
      // a position labelled "hold the draw" that is actually won would tell a
      // child to stop looking for the win.
      expect(estimated.mode, EndgameMode.win);
    });

    test('a seven-piece answer from the Lichess tables is exact too', () {
      // Positions past the local six-piece set are judged over the network,
      // and the answer is a tablebase result all the same. Showing one as an
      // estimate would understate what the child is being told.
      final remote = EndgamePuzzle.fromJson({
        'puzzle_id': 'x',
        'fen': '8/8/3pkp1p/7P/4KP2/8/8/8 b - - 6 53',
        'winning_moves': ['e6f7', 'e6d7', 'd6d5'],
        'piece_count': 7,
        'source': 'lichess',
      });
      expect(remote.isExact, isTrue);
      // Still not playable out: judging every move belongs to the server, and
      // the server holds the tables only up to five pieces.
      expect(remote.canBePlayedOut, isFalse);
    });

    test('a payload with no winning moves is not playable', () {
      final puzzle = EndgamePuzzle.fromJson({'puzzle_id': 'x', 'fen': 'x'});
      expect(puzzle.isPlayable, isFalse);
    });

    test('an unknown date is left out of the label rather than shown as ????',
        () {
      const game =
          EndgameGame(white: 'Alekhine', black: 'Yates', date: '????.??.??');
      expect(game.label, 'Alekhine - Yates');
    });
  });

  group('EndgameSolveSession', () {
    test('accepts every move that holds the result, not just the first', () {
      for (final move in ['a1f1', 'a1e1']) {
        final session = EndgameSolveSession(twoWaysToDraw());
        final verdict = session.submit(move);

        expect(verdict.correct, isTrue, reason: '$move drži remi');
        expect(verdict.finished, isTrue);
        expect(session.countsAsSolved, isTrue);
      }
    });

    test('offers the demonstration reply only when the line still applies', () {
      // The engine's own move: the recorded line continues from here.
      final onLine = EndgameSolveSession(twoWaysToDraw()).submit('a1f1');
      expect(onLine.opponentReply, 'g2g3');

      // Equally good, but the recorded line no longer describes this board, so
      // replying from it would show a move that does not follow.
      final offLine = EndgameSolveSession(twoWaysToDraw()).submit('a1e1');
      expect(offLine.correct, isTrue);
      expect(offLine.opponentReply, isNull);
    });

    test('a move that throws the result away fails, and names every answer',
        () {
      final session = EndgameSolveSession(twoWaysToDraw());
      final verdict = session.submit('a1a2', san: 'Ra2');

      expect(verdict.correct, isFalse);
      expect(verdict.accepted, ['a1f1', 'a1e1']);
      expect(session.status, EndgameSolveStatus.failed);
      expect(session.firstWrongSan, 'Ra2');
    });

    test('only the first wrong idea is kept', () {
      final session = EndgameSolveSession(twoWaysToDraw());
      session.submit('a1a2', san: 'Ra2');
      session.retryAfterMistake();
      session.submit('a1b1', san: 'Rb1');

      expect(session.firstWrongSan, 'Ra2');
      expect(session.mistakes, 2);
    });

    test('a retried or hinted solve does not count as solved unaided', () {
      final retried = EndgameSolveSession(twoWaysToDraw());
      retried.submit('a1a2');
      retried.retryAfterMistake();
      retried.submit('a1f1');
      expect(retried.status, EndgameSolveStatus.solved);
      expect(retried.countsAsSolved, isFalse);

      final hinted = EndgameSolveSession(twoWaysToDraw());
      expect(hinted.revealHint(), 'f1'); // the square, not the move
      hinted.submit('a1f1');
      expect(hinted.countsAsSolved, isFalse);
    });

    test('a promotion is recognised however the suffix is written', () {
      final puzzle = EndgamePuzzle.fromJson({
        'puzzle_id': 'p',
        'fen': '8/P7/8/8/8/8/8/K6k w - - 0 1',
        'winning_moves': ['a7a8q'],
        'piece_count': 3,
      });

      expect(EndgameSolveSession(puzzle).submit('a7a8').correct, isTrue);
      expect(EndgameSolveSession(puzzle).submit('a7a8q').correct, isTrue);
      // Underpromotion is a different move and must not be waved through.
      expect(EndgameSolveSession(puzzle).submit('a7a8n').correct, isFalse);
    });

    test('a move already found is neither a mistake nor progress', () {
      final second =
          EndgameSolveSession(twoWaysToDraw(), alreadyFound: {'a1f1'});

      final repeat = second.submit('a1f1');
      expect(repeat.correct, isTrue);
      expect(repeat.alreadyFound, isTrue);
      // Still open: they are hunting for the other one.
      expect(second.isComplete, isFalse);
      expect(second.mistakes, 0);
      expect(second.remainingMoves, ['a1e1']);

      final fresh = second.submit('a1e1');
      expect(fresh.correct, isTrue);
      expect(fresh.alreadyFound, isFalse);
      expect(second.isComplete, isTrue);
      expect(second.foundMove, 'a1e1');
    });

    test('the hint points at a move not yet found', () {
      final first = EndgameSolveSession(twoWaysToDraw());
      expect(first.revealHint(), 'f1');

      final second =
          EndgameSolveSession(twoWaysToDraw(), alreadyFound: {'a1f1'});
      expect(second.revealHint(), 'e1');
    });

    test('nothing is accepted once the attempt is over', () {
      final session = EndgameSolveSession(twoWaysToDraw());
      session.submit('a1f1');
      expect(session.submit('a1e1').correct, isFalse);
    });
  });
}
