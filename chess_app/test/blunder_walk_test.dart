import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/endgame_trainer/models/blunder_game.dart';

/// Seger - Lambert 2005, exactly as the detector recorded it: three mistakes in
/// six moves, and they alternate between the two players. Black lets a draw go,
/// White hands the win straight back, Black loses it again.
BlunderGame game() => BlunderGame.fromJson({
      'game_id': 'bg_test',
      'white': 'Seger, Ruediger',
      'black': 'Lambert, Andreas',
      'white_elo': 2416,
      'black_elo': 2204,
      'date': '2005.03.13',
      'start_fen': '8/8/k1K5/P6R/8/5r2/7P/8 b - - 1 59',
      'moves': ['Rd3', 'h4', 'Rd1', 'Rh6', 'Kxa5', 'Rc4'],
      'blunders': [
        {
          'ply': 0,
          'fen': '8/8/k1K5/P6R/8/5r2/7P/8 b - - 1 59',
          'side': 'black',
          'played': 'Rd3',
          'should_play': ['Rb3', 'Rf2'],
          'should_play_uci': ['f3b3', 'f3f2'],
          'outcome_before': 'draw',
          'outcome_after': 'loss',
          'material': 'KRPPvKR',
          'cause': 'outcome',
        },
        {
          'ply': 1,
          'fen': '8/8/k1K5/P6R/8/3r4/7P/8 w - - 2 60',
          'side': 'white',
          'played': 'h4',
          'should_play': ['Kc5', 'Rh6'],
          'should_play_uci': ['c6c5', 'h5h6'],
          'outcome_before': 'win',
          'outcome_after': 'draw',
          'material': 'KRPPvKR',
          'cause': 'outcome',
        },
        {
          'ply': 4,
          'fen': '8/8/k1K5/P6R/7P/8/8/3r4 b - - 0 62',
          'side': 'black',
          'played': 'Kxa5',
          'should_play': ['Rc4+'],
          'should_play_uci': ['d1c1'],
          'outcome_before': 'draw',
          'outcome_after': 'loss',
          'material': 'KRPvKR',
          'cause': 'outcome',
        },
      ],
    });

void main() {
  test('a walk opens on the first mistake and cannot move until it is answered',
      () {
    final walk = BlunderWalk(game());

    expect(walk.cursor, 0);
    expect(walk.pending, isNotNull);
    expect(walk.pending!.played, 'Rd3');
    // The wall. Without it a child pages forward and reads the answer off the
    // board instead of finding it.
    expect(walk.canGoForward, isFalse);
    expect(walk.canGoBack, isFalse);
    expect(walk.forward(), isFalse);
    expect(walk.cursor, 0);
  });

  test('a wrong move is refused and the wall stays up', () {
    final walk = BlunderWalk(game());

    final verdict = walk.submit('f3f8', san: 'Rf8');
    expect(verdict.correct, isFalse);
    expect(walk.pending, isNotNull);
    expect(walk.canGoForward, isFalse);
  });

  test('any move that held is accepted, not just the first one listed', () {
    // Two moves drew here. Telling a child the second one is wrong is simply
    // false, and it is the reason should_play is a list.
    final walk = BlunderWalk(game());
    expect(walk.submit('f3f2', san: 'Rf2').correct, isTrue);
    expect(walk.pending, isNull);
  });

  test('answering opens the way to the next mistake and no further', () {
    final walk = BlunderWalk(game());
    walk.submit('f3b3');

    // The next stop is one ply on, so that is as far as the cursor goes.
    expect(walk.frontier, 1);
    expect(walk.forward(), isTrue);
    expect(walk.cursor, 1);
    expect(walk.canGoForward, isFalse);
    expect(walk.pending!.side, 'white');
    expect(walk.pending!.played, 'h4');
  });

  test('moves already seen can be walked back over and forward again', () {
    final walk = BlunderWalk(game());
    walk.submit('f3b3');
    walk.forward();
    walk.submit('c6c5');

    // Three plies of real game before the last mistake at ply four.
    expect(walk.frontier, 4);
    while (walk.canGoForward) {
      walk.forward();
    }
    expect(walk.cursor, 4);

    expect(walk.back(), isTrue);
    expect(walk.cursor, 3);
    expect(walk.back(), isTrue);
    expect(walk.forward(), isTrue);
    expect(walk.cursor, 3);
    // Stepping back over an answered stop still knows what happened there.
    walk.back();
    walk.back();
    walk.back();
    expect(walk.cursor, 0);
    expect(walk.atCursor, isNotNull);
    expect(walk.pending, isNull);
    expect(walk.canGoBack, isFalse);
  });

  test('the next stop is known even when the cursor is nowhere near it', () {
    // The bug this guards against reached a screenshot. `pending` is the
    // mistake *at* the cursor, and the screen used it to answer "is there one
    // ahead" - so between two stops it read null, the heading fell through to a
    // vague sentence, and the button that jumps to the mistake could never
    // appear because its condition was unsatisfiable.
    final walk = BlunderWalk(game());
    walk.submit('f3b3');
    walk.forward();
    walk.submit('c6c5');

    // Standing at ply one, with the last mistake three plies ahead.
    expect(walk.cursor, 1);
    expect(walk.pending, isNull);
    expect(walk.nextStop, isNotNull);
    expect(walk.nextStop!.ply, 4);
    expect(walk.nextStop!.played, 'Kxa5');
  });

  test('there is no next stop once every mistake is answered', () {
    final walk = BlunderWalk(game());
    walk.submit('f3b3');
    walk.forward();
    walk.submit('c6c5');
    walk.toPending();
    walk.submit('d1c1');

    expect(walk.nextStop, isNull);
    expect(walk.pending, isNull);
  });

  test('the last answer opens the game to its end', () {
    final walk = BlunderWalk(game());
    walk.submit('f3b3');
    walk.forward();
    walk.submit('c6c5');
    walk.toPending();
    expect(walk.cursor, 4);
    walk.submit('d1c1');

    expect(walk.frontier, 6);
    while (walk.canGoForward) {
      walk.forward();
    }
    expect(walk.cursor, 6);
    expect(walk.isFinished, isTrue);
  });

  test('being shown the answer opens the way but is not counted as finding it',
      () {
    // A wall with no door is how a session ends with the app closed. Seeing the
    // rest of the game is worth more than holding the line on one position.
    final walk = BlunderWalk(game());
    final shown = walk.reveal();

    expect(shown!.shouldPlay, contains('Rb3'));
    expect(walk.pending, isNull);
    expect(walk.canGoForward, isTrue);
    expect(walk.answeredCount, 1);
    expect(walk.solvedCount, 0);
    expect(walk.wasRevealed(0), isTrue);
  });

  test('a solved walk counts what was found and what was shown apart', () {
    final walk = BlunderWalk(game());
    walk.submit('f3b3');
    walk.forward();
    walk.reveal();
    walk.toPending();
    walk.submit('d1c1');

    expect(walk.totalCount, 3);
    expect(walk.answeredCount, 3);
    expect(walk.solvedCount, 2);
  });

  test('submitting where nothing is pending says so rather than judging', () {
    final walk = BlunderWalk(game());
    walk.submit('f3b3');
    walk.forward();
    walk.submit('c6c5');
    walk.forward();

    final verdict = walk.submit('a1a2');
    expect(verdict.alreadyOver, isTrue);
    expect(verdict.correct, isFalse);
  });

  test('the game names itself the way a person would', () {
    expect(
        game().label, 'Seger, Ruediger (2416) - Lambert, Andreas (2204), 2005');
  });
}
