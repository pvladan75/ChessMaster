import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/serbian_plural.dart';
import 'package:chess_app/features/endgame_trainer/models/endgame_puzzle.dart';

void main() {
  group('which form a number takes', () {
    test('one, and every number that ends in one', () {
      expect(serbianCountForm(1), SerbianCount.one);
      expect(serbianCountForm(21), SerbianCount.one);
      expect(serbianCountForm(101), SerbianCount.one);
    });

    test('two to four, and every number that ends in them', () {
      for (final n in [2, 3, 4, 22, 33, 44, 102]) {
        expect(serbianCountForm(n), SerbianCount.few, reason: '$n');
      }
    });

    test('five and up', () {
      for (final n in [0, 5, 9, 10, 20, 25, 100]) {
        expect(serbianCountForm(n), SerbianCount.many, reason: '$n');
      }
    });

    test('eleven to fourteen are the exception that catches everyone', () {
      // They end in 1-4 and still take the last form: "jedanaest takvih
      // poteza", never "jedanaest takav potez".
      for (final n in [11, 12, 13, 14, 111, 112]) {
        expect(serbianCountForm(n), SerbianCount.many, reason: '$n');
      }
    });
  });

  group('how many other moves also hold', () {
    test('one move keeps the verb and the noun singular', () {
      expect(movesLeftText(1), 'There is 1 other move.');
    });

    test('two to four take the plural', () {
      expect(movesLeftText(2), 'There are 2 other moves.');
      expect(movesLeftText(3), 'There are 3 other moves.');
      expect(movesLeftText(4), 'There are 4 other moves.');
    });

    test('five and up take the plural', () {
      expect(movesLeftText(5), 'There are 5 other moves.');
      expect(movesLeftText(11), 'There are 11 other moves.');
    });
  });
}
