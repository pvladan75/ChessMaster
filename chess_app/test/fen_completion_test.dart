// A board with no fields after it is still a position somebody meant.
//
// Reported live on 18.9.2026: „ne mogu da ubacim pozicije, fen nije dobar",
// with this FEN and nothing else on the line:
//
//   rnbqkbnr/ppp2ppp/4p3/3p4/3PP3/8/PPP2PPP/RNBQKBNR
//
// One field of six - what a diagram tool hands you. The dialog refused it and
// said only „Not a valid position for 'play it out'", so there was no way to
// see that the board was never the problem.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/services/fen_legality.dart';

void main() {
  const owners = 'rnbqkbnr/ppp2ppp/4p3/3p4/3PP3/8/PPP2PPP/RNBQKBNR';

  test('the reason names the fields, not the board', () {
    final reason = fenIllegalReason(owners);
    expect(reason, isNotNull);
    expect(reason, contains('six fields'));
    expect(reason, contains('this one has 1'));
    expect(reason, isNot(contains('Malformed')),
        reason: 'the board is the one part that was right');
  });

  test('the owner\'s FEN completes to a legal position', () {
    final done = completedFen(owners);
    expect(done, '$owners w KQkq - 0 1',
        reason: 'nothing has moved off its home square, so every castle is '
            'still on the table');
    expect(fenIllegalReason(done!), isNull);
  });

  test('castling is read off the board, not assumed', () {
    // White king on e1 but no rook on a1; black king has moved to e7.
    const moved = 'rnbq1bnr/ppppkppp/8/8/8/8/PPPPPPPP/1NBQKBNR';
    expect(completedFen(moved), '$moved w K - 0 1');

    // Kings off their squares entirely: nobody may castle.
    const kingsOut = '8/8/4k3/8/8/4K3/4P3/8';
    expect(completedFen(kingsOut), '$kingsOut w - - 0 1');
  });

  test('a side already given is kept', () {
    expect(completedFen('$owners b'), '$owners b KQkq - 0 1');
  });

  test('a FEN that is already whole is left alone', () {
    expect(completedFen('$owners w KQkq - 0 1'), isNull);
    expect(completedFen('8/8/4k3/8/8/4K3/4P3/8 b - - 3 40'), isNull);
  });

  test('nothing to work with is not completed into something', () {
    expect(completedFen(''), isNull);
    expect(completedFen('not a fen'), isNull,
        reason: 'one field, but not eight ranks');
    expect(completedFen('8/8/8/8'), isNull, reason: 'half a board');
  });
}
