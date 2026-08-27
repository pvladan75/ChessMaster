import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/tactics_trainer/screens/tactics_trainer_screen.dart';

/// The sentence a student reads when they reach the end of their homework
/// without having answered all of it.
///
/// Reported live on 27.8.2026: two puzzles were skipped, the last one was
/// answered, and the screen said "Zadatak je završen. Vaš trener vidi
/// rezultat." None of that was true — the assignment stays open until every
/// item has been attempted, so nothing was submitted and the trainer was never
/// told. The student reasonably went away.
///
/// Only the counting is pinned here. Everything around it needs a puzzle
/// fetched over the network, so the flow itself is a live check (item 39 in
/// `docs/TODO-provera.md`).
void main() {
  group('how many puzzles were skipped, in Serbian', () {
    test('one takes the singular accusative', () {
      expect(puzzleCountLabel(1), '1 zagonetku');
      expect(puzzleCountLabel(21), '21 zagonetku');
      expect(puzzleCountLabel(101), '101 zagonetku');
    });

    test('two to four take the plural', () {
      expect(puzzleCountLabel(2), '2 zagonetke');
      expect(puzzleCountLabel(4), '4 zagonetke');
      expect(puzzleCountLabel(23), '23 zagonetke');
    });

    test('five and up take the genitive plural', () {
      expect(puzzleCountLabel(5), '5 zagonetaka');
      expect(puzzleCountLabel(10), '10 zagonetaka');
      expect(puzzleCountLabel(0), '0 zagonetaka');
    });

    test('the teens are the exception that catches naive versions', () {
      // 11 ends in 1 and 12–14 end in 2–4, but all of them take the same form
      // as 5. A version that reads only the last digit says "11 zagonetku".
      expect(puzzleCountLabel(11), '11 zagonetaka');
      expect(puzzleCountLabel(12), '12 zagonetaka');
      expect(puzzleCountLabel(14), '14 zagonetaka');
      expect(puzzleCountLabel(111), '111 zagonetaka');
    });
  });
}
