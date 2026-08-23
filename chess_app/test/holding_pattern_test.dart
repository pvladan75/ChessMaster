import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/endgame_trainer/services/holding_pattern.dart';

void main() {
  group('what the moves that hold have in common', () {
    test('only the king may move, and that is the lesson', () {
      // White to move with a rook and a king. Suppose the tables say only the
      // two king moves hold: that is a rule about the position, not a list.
      const fen = '8/8/8/8/8/1k6/8/R3K3 w - - 0 1';
      final lesson = holdingLesson(
        fen: fen,
        holdingUci: const ['e1d2', 'e1f2'],
      );
      expect(lesson, 'Drže samo potezi kralja.');
    });

    test('the rook has to stay on its rank', () {
      // Every holding move slides the rook along the first rank. That is a rule
      // about rook endings, and it survives the walk to the next position.
      const fen = '8/8/8/8/8/1k6/8/R3K3 w - - 0 1';
      final lesson = holdingLesson(
        fen: fen,
        holdingUci: const ['a1b1', 'a1c1', 'a1d1'],
      );
      expect(lesson, 'Top mora da ostane na 1. redu.');
    });

    test('a pattern the played move breaks is the one worth saying', () {
      // Two things are true of the answer set here: they are all rook moves,
      // and they all stay on the rank. The mistake was a king move, so the
      // first is what answers "why was mine wrong".
      const fen = '8/8/8/8/8/1k6/8/R3K3 w - - 0 1';
      final patterns = describeHolding(
        fen: fen,
        holdingUci: const ['a1b1', 'a1c1'],
        playedUci: 'e1d2',
      );
      expect(patterns.first.explainsPlayed, isTrue);
      expect(patterns.first.text, contains('topa'));
    });

    test('nothing is claimed when the moves that hold share nothing', () {
      // A king move and a rook move together: no piece in common, no rank in
      // common, no check, no capture. Saying anything here would be inventing.
      const fen = '8/8/8/8/8/1k6/8/R3K3 w - - 0 1';
      expect(
        holdingLesson(fen: fen, holdingUci: const ['a1a8', 'e1f2']),
        isNull,
      );
    });

    test('a pattern that rules out nothing is not a pattern', () {
      // When every legal move holds there is no lesson: the position asks
      // nothing of the player.
      const fen = '8/8/8/8/8/1k6/8/R3K3 w - - 0 1';
      final all = describeHolding(
        fen: fen,
        holdingUci: const [
          'a1a2',
          'a1a3',
          'a1a4',
          'a1a5',
          'a1a6',
          'a1a7',
          'a1a8',
          'a1b1',
          'a1c1',
          'a1d1',
          'e1d1',
          'e1f1',
          'e1d2',
          'e1e2',
          'e1f2',
        ],
      );
      expect(all, isEmpty);
    });

    test('a check-only answer set is noticed', () {
      // Both of these give check, and the detector should see that even though
      // a sharper thing is also true of them. Which one gets shown is the
      // ranking's business; that this one is found is this test's.
      const fen = '8/8/8/8/8/1k6/8/R3K3 w - - 0 1';
      final patterns = describeHolding(
        fen: fen,
        holdingUci: const ['a1a3', 'a1b1'],
      );
      expect(patterns.map((p) => p.text), contains('Drži samo šah.'));
    });

    test('an unreadable position produces silence, not a guess', () {
      expect(holdingLesson(fen: 'ovo-nije-fen', holdingUci: const ['a1a2']),
          isNull);
      expect(
          holdingLesson(
              fen: '8/8/8/8/8/1k6/8/R3K3 w - - 0 1', holdingUci: const []),
          isNull);
    });

    test('a move nobody can play is not counted as holding', () {
      // The list comes from the server and the board from the client. If they
      // ever disagree the answer is silence, not a sentence about a move that
      // does not exist.
      const fen = '8/8/8/8/8/1k6/8/R3K3 w - - 0 1';
      expect(
        holdingLesson(fen: fen, holdingUci: const ['h7h8']),
        isNull,
      );
    });
  });

  group('ranking', () {
    test('explaining the mistake outweighs ruling out more moves', () {
      const fen = '8/8/8/8/8/1k6/8/R3K3 w - - 0 1';
      final patterns = describeHolding(
        fen: fen,
        holdingUci: const ['a1b1', 'a1c1', 'a1d1'],
        playedUci: 'a1a8',
      );
      // "Stays on the rank" excludes fewer moves than "is a rook move", but it
      // is the one the played move broke.
      expect(patterns.first.explainsPlayed, isTrue);
      expect(patterns.first.text, contains('1. redu'));
    });
  });
}
