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
      // And playable out, because the server asks the same tables rather than
      // holding a set of its own: the ceiling is where tablebases end, not
      // where a droplet's disk does.
      expect(remote.canBePlayedOut, isTrue);
    });

    test('past seven pieces there is nothing to play out against', () {
      final tooBig = EndgamePuzzle.fromJson({
        'puzzle_id': 'x',
        'fen': '8/4k3/8/1p2Pp2/p7/P1K1P3/1P6/8 w - - 1 42',
        'winning_moves': ['c3d3'],
        'piece_count': 9,
        'source': 'syzygy',
      });
      expect(tooBig.isExact, isTrue);
      expect(tooBig.canBePlayedOut, isFalse);
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

    // Until 1.10.2026 two cases here held the stored line's reply — the line's
    // second move after its own first, none after another holding move.
    // Superseded by docs/PLAN-TRENER-ZAVRSNICA.md D8: the reply comes from the
    // server for every found move, so the session gives none; what is left to
    // hold is that either holding move is a plain correct verdict.
    test('either holding move is a correct verdict, with no reply in it', () {
      for (final move in ['a1f1', 'a1e1']) {
        final verdict = EndgameSolveSession(twoWaysToDraw()).submit(move);
        expect(verdict.correct, isTrue, reason: move);
        expect(verdict.finished, isTrue, reason: move);
      }
    });

    test('Show solution: revealed, complete, never counted, and closed', () {
      final session = EndgameSolveSession(twoWaysToDraw());
      session.reveal();
      expect(session.status, EndgameSolveStatus.revealed);
      expect(session.isComplete, isTrue);
      expect(session.countsAsSolved, isFalse);

      final after = session.submit('a1f1');
      expect(after.correct, isFalse, reason: 'submit is refused once shown');
      expect(session.status, EndgameSolveStatus.revealed);
    });

    test('a solved attempt is not turned into a shown one', () {
      final session = EndgameSolveSession(twoWaysToDraw())..submit('a1f1');
      session.reveal();
      expect(session.status, EndgameSolveStatus.solved);
      expect(session.countsAsSolved, isTrue);
    });

    test('a move that throws the result away fails, and names every answer',
        () {
      final session = EndgameSolveSession(twoWaysToDraw());
      final verdict = session.submit('a1a2', san: 'Ra2');

      expect(verdict.correct, isFalse);
      // `verdict.accepted` was asserted here until 1.10.2026; no screen read
      // it, and it went with docs/PLAN-TRENER-ZAVRSNICA.md phase 1. The
      // answers are the puzzle's own `winningMoves`.
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

    // Was „a retried or hinted solve": the Hint was deleted on the owner's word of
    // 3.10.2026 (docs/PLAN-GOVOR-IZ-KLIPOVA.md, phase 4b), so only the retry is
    // left to be unaided or not.
    test('a retried solve does not count as solved unaided', () {
      final retried = EndgameSolveSession(twoWaysToDraw());
      retried.submit('a1a2');
      retried.retryAfterMistake();
      retried.submit('a1f1');
      expect(retried.status, EndgameSolveStatus.solved);
      expect(retried.countsAsSolved, isFalse);
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

    test('nothing is accepted once the attempt is over', () {
      final session = EndgameSolveSession(twoWaysToDraw());
      session.submit('a1f1');
      expect(session.submit('a1e1').correct, isFalse);
    });
  });
}
