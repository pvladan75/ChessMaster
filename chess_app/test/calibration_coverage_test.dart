// What a calibration teaches the reader — phase 3e of
// docs/PLAN-SKENER-SLIKE.md. The reader compares a square only with examples
// on its own colour, so a calibration needs twelve pieces on a light and a
// dark square; the table the trainer sees is worked out here, from the
// placements alone.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/position_scanner/models/image_scan.dart';

void main() {
  test('a8 is light: a rook there and one on a1 are different classes', () {
    // A white rook on a8 (light) only.
    final c = CalibrationCoverage.of(['R7/8/8/8/8/8/8/8']);
    expect(c.stateOf('R', dark: false), ClassState.seen);
    expect(c.stateOf('R', dark: true), ClassState.guessed);
    // And on a1 (dark) only: the other way round.
    final d = CalibrationCoverage.of(['8/8/8/8/8/8/8/R7']);
    expect(d.stateOf('R', dark: true), ClassState.seen);
    expect(d.stateOf('R', dark: false), ClassState.guessed);
  });

  test('a piece on neither colour is unknown, and reading waits for it', () {
    // Kings and a white queen only.
    final c = CalibrationCoverage.of(['4k3/8/8/8/8/8/8/3QK3']);
    expect(c.stateOf('q', dark: false), ClassState.unknown);
    expect(c.stateOf('q', dark: true), ClassState.unknown);
    expect(c.unknownPieces, ['P', 'N', 'B', 'R', 'p', 'n', 'b', 'r', 'q']);
    expect(c.ready, isFalse);
  });

  test('ready exactly when the last unknown piece is shown on either colour',
      () {
    // Every piece shown except the black queen.
    const most = 'rnb1kbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR';
    expect(CalibrationCoverage.of([most]).unknownPieces, ['q']);
    expect(CalibrationCoverage.of([most]).ready, isFalse);
    // A black queen on d8, a dark square: now nothing is unknown, and the
    // queen on a light square is guessed.
    final c = CalibrationCoverage.of([most, '3qk3/8/8/8/8/8/8/4K3']);
    expect(c.ready, isTrue);
    expect(c.guessedClasses, contains('q/light'));
    expect(c.guessedClasses, isNot(contains('q/dark')));
  });

  test('a piece said to be absent is not asked for', () {
    const most = 'rnb1kbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR';
    final c = CalibrationCoverage.of([most], absent: {'q'});
    expect(c.unknownPieces, isEmpty);
    expect(c.ready, isTrue);
    expect(c.stillNeeded, isNot(contains('black queen')));
  });

  test('counts are boards, not squares', () {
    // Eight white pawns on one board are one board showing them.
    final c = CalibrationCoverage.of([
      '4k3/8/8/8/8/8/PPPPPPPP/4K3',
      '4k3/8/8/8/8/8/P7/4K3',
    ]);
    // a2 is light (rank 2, file a: (6 + 0) % 2 == 0 in the a8-first count).
    expect(c.counts['P/light'], 2);
    expect(c.counts['P/dark'], 1);
  });

  test('what is still needed: unknown pieces first, then guessed classes', () {
    final c = CalibrationCoverage.of(['4k3/8/8/8/8/8/8/R3K3']);
    final needed = c.stillNeeded;
    expect(needed.indexOf('a white pawn, on any square'), 0);
    expect(needed, contains('a white rook on a light square'));
    expect(needed.indexOf('on any square'),
        lessThan(needed.indexOf('a white rook on a light square')));
    // Everything shown on both colours: nothing is needed.
    const light = 'RNBQKBNR/PPPPPPPP/8/8/8/8/pppppppp/rnbqkbnr';
    const dark = 'NBQKBNRR/PPPPPPPP/8/8/8/8/pppppppp/nbqkbnrr';
    final all = CalibrationCoverage.of([light, dark]);
    expect(all.guessedClasses, isEmpty);
    expect(all.stillNeeded, isEmpty);
  });

  test('what a board adds is what no other board shows', () {
    const first = '4k3/8/8/8/8/8/8/R3K3';
    const second = '4k3/8/8/8/8/8/8/R3K2R';
    // h1 is light: the second board adds a white rook on a light square.
    expect(classesAddedBy(second, [first]), {'R/light'});
    // The first adds nothing the second does not show.
    expect(classesAddedBy(first, [second]), isEmpty);
    // Alone, a board adds all it shows.
    expect(classesAddedBy(first, const []), pieceClassesOf(first));
  });
}
