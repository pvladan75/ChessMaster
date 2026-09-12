import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/move_between_positions.dart';

/// The pure core of phase 2b of `docs/PLAN-OZNAKE-NA-TABLI.md`.
///
/// Landed before the widget that uses it, on the rule this repository already
/// keeps: where a batch has a provable centre, prove the centre first and the
/// widget has nothing left to be wrong about.
void main() {
  /// [fen] after [san] has been played on it, which is how every expectation
  /// below is built — writing the "after" FEN by hand is how a test comes to
  /// assert the thing it was supposed to check.
  String after(String fen, String san) {
    final game = chess.Chess.fromFEN(fen);
    expect(game.move(san), isTrue, reason: '$san is not legal in $fen');
    return game.fen;
  }

  const start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  group('an ordinary move', () {
    test('a pawn two squares forward', () {
      expect(moveBetweenPositions(start, after(start, 'e4')),
          (from: 'e2', to: 'e4'));
    });

    test('a knight out', () {
      expect(moveBetweenPositions(start, after(start, 'Nf3')),
          (from: 'g1', to: 'f3'));
    });

    test('black answering', () {
      final afterE4 = after(start, 'e4');
      expect(moveBetweenPositions(afterE4, after(afterE4, 'c5')),
          (from: 'c7', to: 'c5'));
    });
  });

  group('the moves a square-by-square diff would need a special case for', () {
    // Each of these is the reason this function asks the rules instead of
    // comparing placements itself.
    test('castling short moves two pieces and is reported as the king\'s', () {
      const fen =
          'rnbqk2r/pppp1ppp/5n2/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 1';
      expect(
          moveBetweenPositions(fen, after(fen, 'O-O')), (from: 'e1', to: 'g1'));
    });

    test('castling long', () {
      const fen =
          'r3kbnr/pppqpppp/2np4/8/3PP3/2N2N2/PPPQ1PPP/R3KB1R w KQkq - 0 1';
      expect(moveBetweenPositions(fen, after(fen, 'O-O-O')),
          (from: 'e1', to: 'c1'));
    });

    test('en passant empties a square no piece arrived on', () {
      const fen =
          'rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 3';
      expect(moveBetweenPositions(fen, after(fen, 'exf6')),
          (from: 'e5', to: 'f6'));
    });

    test('promotion changes what the piece is', () {
      const fen = '8/4P3/8/8/8/8/8/4K2k w - - 0 1';
      expect(moveBetweenPositions(fen, after(fen, 'e8=Q')),
          (from: 'e7', to: 'e8'));
    });

    test('under-promotion is a different position and a different answer', () {
      const fen = '8/4P3/8/8/8/8/8/4K2k w - - 0 1';
      final queen = after(fen, 'e8=Q');
      final knight = after(fen, 'e8=N');
      expect(queen, isNot(knight));
      expect(moveBetweenPositions(fen, knight), (from: 'e7', to: 'e8'));
    });

    test('a capture, where the destination was already occupied', () {
      const fen =
          'rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2';
      expect(moveBetweenPositions(fen, after(fen, 'exd5')),
          (from: 'e4', to: 'd5'));
    });
  });

  group('no single move gets there, so nothing is claimed', () {
    test('an unrelated position — a new puzzle being loaded', () {
      expect(moveBetweenPositions(start, '4k3/8/8/8/8/8/8/4K2R w K - 0 1'),
          isNull);
    });

    test('two moves away', () {
      final one = after(start, 'e4');
      final two = after(one, 'e5');
      expect(moveBetweenPositions(start, two), isNull);
    });

    test('the same position — a rebuild with nothing played', () {
      expect(moveBetweenPositions(start, start), isNull);
    });

    test('a move taken back', () {
      final afterE4 = after(start, 'e4');
      expect(moveBetweenPositions(afterE4, start), isNull,
          reason: 'undoing is not a move, and marking e2-e4 on a board that no '
              'longer has the pawn there is a lie about the position');
    });

    test('the same placement with the other side to move', () {
      // A null move. Without the side-to-move in the comparison this would be
      // "no change" — and with a naive placement-only check, a legal move that
      // happened to restore the placement would match.
      const white = '4k3/8/8/8/8/8/8/4K3 w - - 0 1';
      const black = '4k3/8/8/8/8/8/8/4K3 b - - 0 1';
      expect(moveBetweenPositions(white, black), isNull);
    });
  });

  group('a FEN that is not one', () {
    test('rubbish in either position answers null', () {
      const good = '4k3/8/8/8/8/8/8/4K2R w K - 0 1';
      for (final bad in [
        '',
        'not a fen',
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR',
        'xxxxxxxx/8/8/8/8/8/8/8 w - - 0 1',
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR x KQkq - 0 1',
      ]) {
        expect(moveBetweenPositions(bad, good), isNull, reason: 'before: $bad');
        expect(moveBetweenPositions(good, bad), isNull, reason: 'after: $bad');
      }
    });

    test('a placement the engine silently refuses is not an empty board', () {
      // Nine pawns on a rank. It looks like a placement — eight ranks, nothing
      // but piece letters and digits — so it gets past the shape check, and
      // `fromFEN` answers **an empty board** rather than throwing. Without the
      // check that the board took the position it was given, "I could not read
      // this" and "nothing was played here" would be the same answer, and the
      // first would be silent.
      const nine = 'ppppppppp/8/8/8/8/8/8/8 w - - 0 1';
      expect(placementOf(nine), isNotNull,
          reason: 'if the shape check now refuses this, the guard below is '
              'being tested through the wrong door');
      expect(chess.Chess.fromFEN(nine).fen, '8/8/8/8/8/8/8/8 w - - 0 1',
          reason: 'the engine stopped answering an empty board for a placement '
              'it cannot read, so this test no longer says what it means');
      expect(
          moveBetweenPositions(nine, '4k3/8/8/8/8/8/8/4K3 b - - 0 1'), isNull);
    });
  });

  group('the counters are not part of the comparison', () {
    test('a differing halfmove clock is the same position', () {
      // A screen that builds its own FEN may not keep the counters the engine
      // would, and a board is not drawn any differently for them.
      final played = after(start, 'e4');
      final parts = played.split(' ');
      final retuned = '${parts[0]} ${parts[1]} ${parts[2]} ${parts[3]} 7 42';
      expect(moveBetweenPositions(start, retuned), (from: 'e2', to: 'e4'));
    });
  });

  group('placementOf', () {
    test('keeps the pieces and the turn, and drops the rest', () {
      expect(placementOf('4k3/8/8/8/8/8/8/4K2R w K - 3 17'),
          '4k3/8/8/8/8/8/8/4K2R w');
    });

    test('refuses what is not a placement', () {
      for (final bad in [
        '',
        'x',
        // Four ranks, not eight.
        '4k3/8/8/8 w - - 0 1',
        // No side to move.
        '4k3/8/8/8/8/8/8/4K3',
        // Eight ranks of letters that are not pieces. This one is why the
        // alphabet is checked at all: it reaches `fromFEN` otherwise, and that
        // answers an empty board without saying so.
        'xxxxxxxx/8/8/8/8/8/8/8 w - - 0 1',
        // A side to move that is neither side.
        '4k3/8/8/8/8/8/8/4K3 x - - 0 1',
      ]) {
        expect(placementOf(bad), isNull, reason: bad);
      }
    });
  });
}
