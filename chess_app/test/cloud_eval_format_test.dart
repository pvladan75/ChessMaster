import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/services/cloud_eval_format.dart';

/// The sign of a cloud evaluation, pinned.
///
/// This is worth a test of its own because getting it wrong is invisible: the
/// number is there, it is plausible, it updates when the position changes — and
/// it is backwards, and only in positions with Black to move. The online engine
/// path negated every one of those for months.
///
/// The values below are what the live API returned on 24.8.2026 for positions
/// whose sign is not arguable.
void main() {
  test('a cloud evaluation is drawn from White\'s side, unflipped', () {
    // 1.e4 e5, White to move: White a fifth of a pawn better.
    expect(cloudEvalLabel(cp: 22), '+0.22');
    // Black better is a minus, whoever is to move.
    expect(cloudEvalLabel(cp: -50), '-0.50');
    expect(cloudEvalLabel(cp: 0), '0.00');
  });

  test('mate keeps the side it was reported for', () {
    // "3qk3/8/8/8/8/8/8/4K3 w" — Black a queen up, White to move: mate: -8,
    // meaning White gets mated. A minus, not a plus.
    expect(cloudEvalLabel(mate: -8), '-M8');
    // "4k3/8/8/8/8/8/8/R3K3 b" — White a rook up, Black to move: mate: 14.
    expect(cloudEvalLabel(mate: 14), 'M14');
    // 1.f3 e5 2.g4 Qh4#, Black to move: mate: -1.
    expect(cloudEvalLabel(mate: -1), '-M1');
  });

  test('mate outranks any centipawn score it is given beside', () {
    // Both present should never happen, but if it does, the mate is the fact.
    expect(cloudEvalLabel(cp: 900, mate: -2), '-M2');
  });

  test('an answer with neither is not turned into a claim', () {
    expect(cloudEvalLabel(), '0.00');
  });
}
