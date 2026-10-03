// `sanOfUci`, the inverse of `uciOfSan` (phase 3 of docs/PLAN-EKRANI.md): the
// move a person reads, worked out from the position it is played in.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/move_motif.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// The Italian after 3...Bc5: White may castle.
const _castle =
    'r1bqk1nr/pppp1ppp/2n5/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4';

/// Black may castle long.
const _blackCastleLong = 'r3kbnr/ppp1pppp/2nq4/3p1b2/3P1B2/2N5/PPPQPPPP/'
    'R3KBNR b KQkq - 6 5';

/// After 1.e4 d5, White may take.
const _capture =
    'rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 2';

/// White's pawn on e7 may promote on e8 or by taking on d8.
const _promotion = '3r3k/4P3/8/8/8/8/8/4K3 w - - 0 1';

void main() {
  group('sanOfUci', () {
    test('a pawn push and a knight move', () {
      expect(sanOfUci(_start, 'e2e4'), 'e4');
      expect(sanOfUci(_start, 'g1f3'), 'Nf3');
    });

    test('castling, both ways, is O-O and O-O-O', () {
      expect(sanOfUci(_castle, 'e1g1'), 'O-O');
      expect(sanOfUci(_blackCastleLong, 'e8c8'), 'O-O-O');
    });

    test('a capture names the file of the pawn that takes', () {
      expect(sanOfUci(_capture, 'e4d5'), 'exd5');
    });

    test('a promotion names its piece, and a check is marked', () {
      expect(sanOfUci(_promotion, 'e7e8q'), 'e8=Q+');
      expect(sanOfUci(_promotion, 'e7e8n'), 'e8=N');
      expect(sanOfUci(_promotion, 'e7d8r'), 'exd8=R+');
    });

    test('a promotion without its piece is no legal move', () {
      expect(sanOfUci(_promotion, 'e7e8'), isNull);
    });

    test('an illegal move, or one from the wrong side, is null', () {
      expect(sanOfUci(_start, 'e2e5'), isNull);
      expect(sanOfUci(_start, 'e7e5'), isNull);
      expect(sanOfUci(_start, ''), isNull);
    });

    test('it is the inverse of uciOfSan', () {
      for (final san in ['e4', 'Nf3', 'a3']) {
        expect(sanOfUci(_start, uciOfSan(_start, san)!), san);
      }
    });
  });
}
