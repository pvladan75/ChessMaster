// Boards the trainer set up join the book's calibration — the owner's question
// of 23.9.2026: „zar ne mogu pozicije koje sam ispravio ili potvrdio da služe
// kao kalibracija?" (`calibrationGrownBy`, models/image_scan.dart).
//
// Only a board set up in the editor joins, and only for what the reader had to
// guess: a calibration is what every later reading stands on, so one board
// ticked as read could teach the book its own mistake.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/position_scanner/models/image_scan.dart';

ReadBoard _board(int page, String placement,
    {bool fixed = true, bool accepted = true, bool legal = true}) {
  final b = ReadBoard(
    ref: BoardRef(page, 1),
    placement: placement,
    uncertain: const [],
    legal: legal,
    preview: Uint8List(0),
    accepted: accepted,
  );
  b.fixedByHand = fixed;
  return b;
}

CalibrationBoard _cal(int page) =>
    CalibrationBoard(ref: BoardRef(page, 1), placement: '8/8/8/8/8/8/8/K6k');

// A white rook on a1 (dark), a white rook on b1 (light), a black rook on a8
// (light) and on b8 (dark).
const _rookA1 = '4k3/8/8/8/8/8/8/R3K3';
const _rookB1 = '4k3/8/8/8/8/8/8/1R2K3';
const _twoMissing = 'r3k3/8/8/8/8/8/8/R3K3';

void main() {
  group('pieceClassesOf', () {
    test('a8 is light, a1 is dark', () {
      expect(pieceClassesOf('r7/8/8/8/8/8/8/8'), {'r/light'});
      expect(pieceClassesOf('1r6/8/8/8/8/8/8/8'), {'r/dark'});
      expect(pieceClassesOf('8/8/8/8/8/8/8/R7'), {'R/dark'});
      expect(pieceClassesOf('8/8/8/8/8/8/8/1R6'), {'R/light'});
    });

    test('empty squares move the file on', () {
      // e1 is dark (file 4, row 7), h8 is dark (file 7, row 0).
      expect(pieceClassesOf('7k/8/8/8/8/8/8/4K3'), {'k/dark', 'K/dark'});
    });
  });

  group('calibrationGrownBy', () {
    test('a board set up by hand that shows a guessed class joins', () {
      final added = calibrationGrownBy(
        current: [_cal(1), _cal(2), _cal(3)],
        saved: [_board(40, _rookA1)],
        composed: ['R/dark'],
      );
      expect(added.added.map((c) => c.ref.page), [40]);
      expect(added.added.single.placement, _rookA1);
      expect(added.boards, hasLength(4));
      expect(added.removed, isEmpty);
    });

    test('a board only ticked, never set up, does not', () {
      final added = calibrationGrownBy(
        current: [_cal(1)],
        saved: [_board(40, _rookA1, fixed: false)],
        composed: ['R/dark'],
      );
      expect(added.added, isEmpty);
    });

    test('a board that shows nothing guessed does not', () {
      final added = calibrationGrownBy(
        current: [_cal(1)],
        saved: [_board(40, _rookB1)],
        composed: ['R/dark'],
      );
      expect(added.added, isEmpty);
    });

    test('nothing guessed, nothing added', () {
      expect(
          calibrationGrownBy(
              current: [_cal(1)],
              saved: [_board(40, _rookA1)],
              composed: []).added,
          isEmpty);
    });

    test('the board covering the most goes first, and one is enough', () {
      final added = calibrationGrownBy(
        current: [_cal(1)],
        saved: [_board(40, _rookA1), _board(41, _twoMissing)],
        composed: ['R/dark', 'r/light'],
      );
      expect(added.added.map((c) => c.ref.page), [41],
          reason: 'the board covering both was not taken first, or a second '
              'was added for nothing');
    });

    // Replaced on 23.9.2026, on the owner's word („da bude dinamička"): until
    // then a full calibration took no more at all.
    test('a full calibration makes room by dropping a redundant board', () {
      // Seven boards of two kings, and one that alone shows a white queen on a
      // light square (a8).
      final current = [
        for (var p = 1; p <= 7; p++) _cal(p),
        CalibrationBoard(ref: BoardRef(8, 1), placement: 'Q7/8/8/8/8/8/8/K6k'),
      ];
      final growth = calibrationGrownBy(
        current: current,
        saved: [_board(40, _rookA1)],
        composed: ['R/dark'],
      );
      expect(growth.added.map((c) => c.ref.page), [40]);
      expect(growth.boards, hasLength(maxCalibrationBoards));
      expect(growth.removed, hasLength(1));
      expect(growth.removed.single.ref.page, lessThanOrEqualTo(7),
          reason: 'the only board with the queen was dropped');
      expect(growth.boards.map((b) => b.ref.page), contains(8));
    });

    test('with no redundant board, a full calibration keeps what it has', () {
      // Eight boards, each the only one to show its extra piece — a8 is
      // light, b8 dark.
      final extras = ['Q7', '1Q6', 'R7', '1R6', 'B7', '1B6', 'N7', '1N6'];
      final current = [
        for (var i = 0; i < extras.length; i++)
          CalibrationBoard(
              ref: BoardRef(i + 1, 1),
              placement: '${extras[i]}/8/8/8/8/8/8/4K2k'),
      ];
      final growth = calibrationGrownBy(
        current: current,
        saved: [_board(40, '4k3/8/8/8/8/8/P7/4K3')],
        composed: ['P/light'],
      );
      expect(growth.added, isEmpty,
          reason: 'a class the reader had was given up for one it lacked');
      expect(growth.boards, current);
    });

    test('a board made redundant by the newcomer can make room for it', () {
      // Eight boards, each the only one to show its extra piece; the newcomer
      // shows the white queen on a8 as well, so that board is redundant once —
      // and only once — the newcomer is counted.
      final extras = ['Q7', '1Q6', 'R7', '1R6', 'B7', '1B6', 'N7', '1N6'];
      final current = [
        for (var i = 0; i < extras.length; i++)
          CalibrationBoard(
              ref: BoardRef(i + 1, 1),
              placement: '${extras[i]}/8/8/8/8/8/8/4K2k'),
      ];
      final growth = calibrationGrownBy(
        current: current,
        saved: [_board(40, 'Q3k3/8/8/8/8/8/P7/4K3')],
        composed: ['P/light'],
      );
      expect(growth.added.map((c) => c.ref.page), [40]);
      expect(growth.removed.map((c) => c.ref.page), [1],
          reason:
              'the board the newcomer made redundant was not the one to go');
    });

    test('of two redundant boards, the one with fewer pieces goes', () {
      final current = [
        CalibrationBoard(ref: BoardRef(1, 1), placement: 'Q7/8/8/8/8/8/8/K6k'),
        for (var p = 2; p <= 7; p++)
          CalibrationBoard(
              ref: BoardRef(p, 1), placement: 'Q7/8/8/8/8/8/8/K6k'),
        _cal(8),
      ];
      final growth = calibrationGrownBy(
        current: current,
        saved: [_board(40, _rookA1)],
        composed: ['R/dark'],
      );
      expect(growth.removed.map((c) => c.ref.page), [8],
          reason: 'a board with more pieces — more evidence — went first');
    });

    test('a board not saved, not a position, or already in it is not taken',
        () {
      final added = calibrationGrownBy(
        current: [_cal(40)],
        saved: [
          _board(40, _rookA1),
          _board(41, _rookA1, accepted: false),
          _board(42, _rookA1, legal: false),
        ],
        composed: ['R/dark'],
      );
      expect(added.added, isEmpty);
    });
  });
}
