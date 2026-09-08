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
  group('how many puzzles were skipped, in English', () {
    test('singular', () {
      expect(puzzleCountLabel(1), '1 puzzle');
    });

    test('plural', () {
      expect(puzzleCountLabel(0), '0 puzzles');
      expect(puzzleCountLabel(2), '2 puzzles');
      expect(puzzleCountLabel(4), '4 puzzles');
      expect(puzzleCountLabel(5), '5 puzzles');
      expect(puzzleCountLabel(10), '10 puzzles');
      expect(puzzleCountLabel(11), '11 puzzles');
      expect(puzzleCountLabel(12), '12 puzzles');
      expect(puzzleCountLabel(14), '14 puzzles');
      expect(puzzleCountLabel(21), '21 puzzles');
      expect(puzzleCountLabel(23), '23 puzzles');
      expect(puzzleCountLabel(101), '101 puzzles');
      expect(puzzleCountLabel(111), '111 puzzles');
    });
  });
}
