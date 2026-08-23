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
      expect(movesLeftText(1), 'Postoji još 1 takav potez.');
    });

    test('two to four take the paucal, and the plural verb with it', () {
      // The report from the phone: it said "Postoji još 2 takvih poteza",
      // which is wrong twice - the verb and the case of both words.
      expect(movesLeftText(2), 'Postoje još 2 takva poteza.');
      expect(movesLeftText(3), 'Postoje još 3 takva poteza.');
      expect(movesLeftText(4), 'Postoje još 4 takva poteza.');
    });

    test('five and up take the genitive plural', () {
      expect(movesLeftText(5), 'Postoji još 5 takvih poteza.');
      expect(movesLeftText(11), 'Postoji još 11 takvih poteza.');
    });
  });
}
