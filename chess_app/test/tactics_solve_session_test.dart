import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/features/tactics_trainer/models/tactics_puzzle.dart';

/// A real row from the dataset:
/// FEN is before f2g3; the puzzle asks for e6e7 after that move is played.
TacticsPuzzle realPuzzle() => TacticsPuzzle.fromJson({
      'puzzle_id': '00008',
      'fen': 'r6k/pp2r2p/4Rp1Q/3p4/8/1N1P2R1/PqP2bPP/7K b - - 0 24',
      'setup_move': 'f2g3',
      'solution': ['e6e7', 'b2b1', 'b3c1', 'b1c1', 'h6c1'],
      'rating': 1939,
      'themes': ['crushing', 'hangingPiece', 'long', 'middlegame'],
      'trainable_themes': ['hangingPiece'],
    });

void main() {
  group('TacticsPuzzle', () {
    test('parses the server payload and counts the user\'s moves', () {
      final puzzle = realPuzzle();

      expect(puzzle.id, '00008');
      expect(puzzle.setupMove, 'f2g3');
      expect(puzzle.isPlayable, isTrue);
      // Five plies means three moves for the user, two replies.
      expect(puzzle.userMoveCount, 3);
    });

    test('a payload without a setup move is not playable', () {
      final puzzle = TacticsPuzzle.fromJson(
          {'puzzle_id': 'x', 'fen': 'x', 'solution': []});
      expect(puzzle.isPlayable, isFalse);
    });
  });

  group('TacticsSolveSession', () {
    test('walks the line, returning each forced reply in turn', () {
      final session = TacticsSolveSession(realPuzzle());

      final first = session.submit('e6e7');
      expect(first.correct, isTrue);
      expect(first.opponentReply, 'b2b1',
          reason: 'the reply is the next ply, not the next user move');
      expect(first.puzzleSolved, isFalse);

      final second = session.submit('b3c1');
      expect(second.correct, isTrue);
      expect(second.opponentReply, 'b1c1');
      expect(second.puzzleSolved, isFalse);

      final third = session.submit('h6c1');
      expect(third.correct, isTrue);
      expect(third.opponentReply, isNull,
          reason: 'the line ends on the user\'s move');
      expect(third.puzzleSolved, isTrue);
      expect(session.status, SolveStatus.solved);
    });

    test('the setup move is never accepted as the answer', () {
      final session = TacticsSolveSession(realPuzzle());
      // Playing the opponent's blunder back is the classic off-by-one here.
      final verdict = session.submit('f2g3');

      expect(verdict.correct, isFalse);
      expect(verdict.expected, 'e6e7');
    });

    test('a wrong move fails the puzzle and reveals what was expected', () {
      final session = TacticsSolveSession(realPuzzle());
      final verdict = session.submit('a8a1');

      expect(verdict.correct, isFalse);
      expect(verdict.expected, 'e6e7');
      expect(session.status, SolveStatus.failed);
      expect(session.mistakes, 1);
    });

    test('a promotion is accepted whether or not the piece is spelled out', () {
      final puzzle = TacticsPuzzle.fromJson({
        'puzzle_id': 'p',
        'fen': 'x',
        'setup_move': 'a7a6',
        'solution': ['e7e8q'],
        'rating': 1500,
      });

      // The board hands back "e7e8"; the dataset stores "e7e8q". Comparing raw
      // strings would reject a correct promotion.
      expect(TacticsSolveSession(puzzle).submit('e7e8').correct, isTrue);
      expect(TacticsSolveSession(puzzle).submit('e7e8q').correct, isTrue);
    });

    test('an under-promotion is not accepted as a queen promotion', () {
      final puzzle = TacticsPuzzle.fromJson({
        'puzzle_id': 'p',
        'fen': 'x',
        'setup_move': 'a7a6',
        'solution': ['e7e8n'],
        'rating': 1500,
      });

      expect(TacticsSolveSession(puzzle).submit('e7e8q').correct, isFalse);
      expect(TacticsSolveSession(puzzle).submit('e7e8n').correct, isTrue);
    });

    test('a different move that delivers mate still solves the puzzle', () {
      final session = TacticsSolveSession(realPuzzle());
      // A forced mate the database did not happen to record is still a solution,
      // and telling the user otherwise would be indefensible.
      final verdict = session.submit('a8a1', givesCheckmate: true);

      expect(verdict.correct, isTrue);
      expect(verdict.puzzleSolved, isTrue);
      expect(session.status, SolveStatus.solved);
    });

    test('a hinted solve does not count towards rating', () {
      final session = TacticsSolveSession(realPuzzle());

      expect(session.revealHint(), 'e6',
          reason: 'the hint is the origin square, not the move');
      session.submit('e6e7');
      session.submit('b3c1');
      session.submit('h6c1');

      expect(session.status, SolveStatus.solved);
      // Solved, but not evidence the user could find it unaided.
      expect(session.countsAsSolved, isFalse);
    });

    test('a solve after a mistake does not count towards rating', () {
      final session = TacticsSolveSession(realPuzzle());

      session.submit('a8a1');
      session.retryAfterMistake();
      session.submit('e6e7');
      session.submit('b3c1');
      session.submit('h6c1');

      expect(session.status, SolveStatus.solved);
      expect(session.mistakes, 1);
      expect(session.countsAsSolved, isFalse);
    });

    test('a clean solve counts', () {
      final session = TacticsSolveSession(realPuzzle());

      session.submit('e6e7');
      session.submit('b3c1');
      session.submit('h6c1');

      expect(session.countsAsSolved, isTrue);
    });

    test('retrying restores play without rewinding progress', () {
      final session = TacticsSolveSession(realPuzzle());

      session.submit('e6e7');
      session.submit('nonsense');
      expect(session.status, SolveStatus.failed);

      session.retryAfterMistake();
      expect(session.status, SolveStatus.solving);
      // The first move stays found — the user should not replay what they solved.
      expect(session.expectedMove, 'b3c1');
    });

    test('moves submitted after the puzzle ends are ignored', () {
      final session = TacticsSolveSession(realPuzzle());

      session.submit('e6e7');
      session.submit('b3c1');
      session.submit('h6c1');
      expect(session.status, SolveStatus.solved);

      // A late tap arriving after the animation must not reopen a solved puzzle.
      expect(session.submit('a8a1').correct, isFalse);
      expect(session.status, SolveStatus.solved);
    });

    test('a single-move puzzle solves immediately', () {
      final puzzle = TacticsPuzzle.fromJson({
        'puzzle_id': 'one',
        'fen': 'x',
        'setup_move': 'a2a3',
        'solution': ['d1h5'],
        'rating': 900,
      });
      final session = TacticsSolveSession(puzzle);

      final verdict = session.submit('d1h5');
      expect(verdict.puzzleSolved, isTrue);
      expect(verdict.opponentReply, isNull);
      expect(puzzle.userMoveCount, 1);
    });
  });

  test('the first wrong idea is kept, the later tries are not', () {
    final session = TacticsSolveSession(realPuzzle());

    session.submit('a1a2', san: 'Ra2');
    session.retryAfterMistake();
    session.submit('b3c1', san: 'Nc1');

    // Later tries are attempts at correcting the first idea; the one that
    // started it says more than a list of them.
    expect(session.firstWrongSan, 'Ra2');
    expect(session.mistakes, 2);
  });

  test('a clean solve reports no wrong move, which is not "unknown"', () {
    final session = TacticsSolveSession(realPuzzle());

    session.submit('e6e7', san: 'Re7');

    expect(session.firstWrongSan, isNull);
    expect(session.mistakes, 0);
  });

  test('a wrong move with no notation still counts as a mistake', () {
    final session = TacticsSolveSession(realPuzzle());

    // The caller could not read the move. That must not be stored as an empty
    // one, and must not stop the attempt being marked.
    session.submit('a1a2');

    expect(session.firstWrongSan, isNull);
    expect(session.mistakes, 1);
  });
}
