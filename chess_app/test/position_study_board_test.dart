// What a position study reads off a board without an engine —
// docs/PLAN-STUDIJA-POZICIJE.md, §2: the position with the other side to
// move, the material in words, and the moves a reader looks at first.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/services/position_study/study_board.dart';
import 'package:chess_app/services/fen_legality.dart';

const _owner1 =
    'rn2kbnr/pp2pppp/2p5/3PNb2/8/1P4P1/1P1PPP1P/RNB1KB1R b KQkq - 0 7';
const _owner2 =
    'rn2kbnr/pp2pppp/2p5/3PN3/4b3/1P4P1/1P1PPP1P/RNB1KB1R w KQkq - 1 8';

void main() {
  group('the position with the other side to move', () {
    test(
        'the side turns, the en passant square goes, the number turns over '
        'after Black', () {
      const afterE4 =
          'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
      expect(passedFen(afterE4),
          'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 1 2');
      const start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
      expect(passedFen(start),
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 1 1');
    });

    test('nobody passes out of a check', () {
      // The engine ends the process on a position whose side not to move is
      // in check — on Android that is the app's own process.
      const inCheck = '4k3/8/8/8/8/8/4R3/4K3 b - - 0 1';
      expect(passedFen(inCheck), isNull);
    });

    test('what it answers is a position the engine takes', () {
      for (final fen in [_owner1, _owner2]) {
        final passed = passedFen(fen);
        expect(passed, isNotNull);
        expect(fenIllegalReason(passed!), isNull);
      }
    });

    test('a side with no move cannot be passed to', () {
      // White passes, and Black — not in check — has no move: stalemate
      // would be the engine's answer to a question nobody asked.
      const blackStuck = '7k/5Q2/8/8/8/8/8/K7 w - - 0 1';
      expect(passedFen(blackStuck), isNull);
    });
  });

  group('the material, in words', () {
    String of(String board) => materialWords('$board w - - 0 1');

    test('level, a pawn up, the exchange', () {
      expect(of('4k3/pppp4/8/8/8/8/PPPP4/4K3'), 'Material is level.');
      expect(of('4k3/ppp5/8/8/8/8/PPPP4/4K3'), 'White is a pawn up.');
      expect(of('4k3/pppp4/8/8/8/8/PP6/4K3'), 'Black is two pawns up.');
      expect(of('2b1k3/pppp4/8/8/8/8/PPPP4/R3K3'), 'White is the exchange up.');
      expect(of('2b1k3/pppp4/8/8/8/8/PPP5/R3K3'),
          'White is the exchange up, for a pawn.');
    });

    test('a bishop against a knight is level, and said beside it', () {
      expect(of('2b1k3/pppp4/8/8/8/8/PPPP4/1N2K3'),
          'Material is level. White has a knight for a bishop.');
      expect(of('2b1k3/ppp5/8/8/8/8/PPPP4/1N2K3'),
          'White is a pawn up. White has a knight for a bishop.');
    });

    test('a queen for a rook and a bishop', () {
      expect(of('r1b1k3/pppp4/8/8/8/8/PPPP4/3QK3'),
          'White has a queen for a rook and a bishop.');
    });

    test('the owner\'s position: White is a pawn up', () {
      expect(materialWords(_owner1), 'White is a pawn up.');
    });
  });

  group('what a side won over a line', () {
    test('a piece, by name', () {
      final taken = playSan(_owner2, 'dxc6')!;
      final won = wonBetween(_owner2, taken.fenAfter, 'White');
      expect(won.points, 1);
      expect(won.words, 'a pawn');
    });

    test('nothing, for the side that lost it', () {
      final taken = playSan(_owner2, 'dxc6')!;
      final won = wonBetween(_owner2, taken.fenAfter, 'Black');
      expect(won.points, 0);
      expect(won.words, isNull);
    });

    test('a bishop given for a knight is nothing won', () {
      final line = playLine(_owner1, ['Bxb1', 'Rxb1']);
      expect(line, hasLength(2));
      expect(wonBetween(_owner1, line.last.fenAfter, 'Black').points, 0);
      expect(wonBetween(_owner1, line.last.fenAfter, 'White').points, 0);
    });

    test('a line with a promotion is said in points', () {
      final line = playLine(
          _owner2, ['dxc6', 'Bxh1', 'Rxa7', 'Rxa7', 'c7', 'e6', 'cxb8=Q+']);
      expect(line, hasLength(7));
      final won = wonBetween(line[1].fenBefore, line.last.fenAfter, 'White');
      expect(won.points, greaterThan(0));
      expect(won.words, isNot(contains('queen')),
          reason: 'the pieces cannot be named without telling the line');
    });
  });

  group('the moves a reader looks at first', () {
    test(
        '7...Be4 is one of them: it attacks the rook, and Bxh1 is what it '
        'is for', () {
      final be4 = naturalMoves(_owner1).firstWhere((n) => n.move.san == 'Be4');
      expect(be4.kind, NaturalKind.attack);
      expect(be4.aim?.san, 'Bxh1');
      expect(be4.aim?.captured, 'rook');
    });

    test('a capture is ranked above an attack on the same piece', () {
      final natural = naturalMoves(_owner1);
      final sans = [for (final n in natural) n.move.san];
      expect(sans.first, 'Bxb1', reason: 'it takes a knight');
      expect(sans.indexOf('Bxb1'), lessThan(sans.indexOf('Be4')));
      expect(sans, contains('cxd5'), reason: 'the pawn that can be taken back');
    });

    test(
        'an attack is new by the square it aims at, not by the move that '
        'takes', () {
      // From c2 the bishop attacks the knight on b1 it already attacked
      // from f5.
      expect(
        naturalMoves(_owner1).where((n) => n.move.san == 'Bc2'),
        isEmpty,
      );
    });

    test('with a rook hanging, nobody goes after a bishop', () {
      final sans = [for (final n in naturalMoves(_owner2)) n.move.san];
      expect(sans, isNot(contains('Ra4')));
      expect(sans, isNot(contains('Nc3')));
      expect(sans, contains('f3'), reason: 'it answers the attack');
      // 8.dxc6 leaves the rook to be taken: it is the engine's move and
      // not what the eye goes to, which is why it needs explaining.
      expect(sans, isNot(contains('dxc6')));
    });

    test(
        'a piece already attacked is not attacked anew from another '
        'square', () {
      // The bishop on f3 can take the rook on a8 now; from e4, d5, c6 or b7
      // it could still take it, by another move — and that is no new threat.
      const rookAttacked = 'r5k1/8/8/8/8/5B2/8/6K1 w - - 0 1';
      final sans = [for (final n in naturalMoves(rookAttacked)) n.move.san];
      expect(sans, contains('Bxa8'));
      for (final quiet in ['Be4', 'Bc6', 'Bb7']) {
        expect(sans, isNot(contains(quiet)), reason: quiet);
      }
    });

    test('a move that mates is not tempting, it is the move', () {
      const mateInOne = '6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1';
      expect([for (final n in naturalMoves(mateInOne)) n.move.san],
          isNot(contains('Ra8#')));
    });
  });

  group('moves as data', () {
    test('a move knows what it took, and its label its number', () {
      final move = playUci(_owner2, 'd5c6')!;
      expect(move.san, 'dxc6');
      expect(move.captured, 'pawn');
      expect(move.taken, 1);
      expect(move.label, '8. dxc6');
      final reply = playSan(move.fenAfter, 'Bxh1')!;
      expect(reply.label, '8... Bxh1');
      expect(reply.captured, 'rook');
    });

    test('a move that does not play is null, and a line stops at it', () {
      expect(playUci(_owner2, 'a1a8'), isNull);
      expect(playSan(_owner2, 'Qd4'), isNull);
      expect(playLine(_owner2, ['dxc6', 'Qd4', 'Rxa7']), hasLength(1));
    });

    test('every piece on the board, side by side, and never a FEN', () {
      final pieces = pieceList(_owner2);
      expect(pieces, startsWith('White: Ke1, Ra1, Rh1, Bc1, Bf1, Nb1, Ne5, '));
      expect(pieces, contains('Black: Ke8, Ra8, Rh8, Be4, Bf8, Nb8, Ng8, '));
      expect(pieces, isNot(contains('/')));
    });
  });
}
