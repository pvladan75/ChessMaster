import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/position_scanner/models/scanned_position.dart';

const _mateInOne = '5Q2/8/8/8/6p1/8/2NNk3/2K5 w - - 0 1';

void main() {
  group('ScannedPosition', () {
    test('parses what the scanner sends, including its own doubt', () {
      final position = ScannedPosition.fromJson({
        'fen': _mateInOne,
        'page': 32,
        'label': '97',
        'sideSource': 'resenje',
        'solutionSan': 'Qf1#',
        'solutionLegal': true,
        'themesText': 'pin/undermine',
        'repairs': ['rokada: postavljeno pravo K'],
      });

      expect(position.page, 32);
      expect(position.label, '97');
      expect(position.sideToMove, 'w');
      expect(position.needsReview, isFalse);
      expect(position.accepted, isTrue,
          reason: 'keeping is the default, discarding is a decision');
      expect(position.repairs, hasLength(1));
    });

    test('a position the parser could not reconcile is flagged, not dropped',
        () {
      final position = ScannedPosition.fromJson({
        'fen': _mateInOne,
        'page': 40,
        'problem': 'potez iz knjige "Rh8#" nije legalan',
      });
      expect(position.needsReview, isTrue);
      expect(position.accepted, isTrue);
    });

    test('an unknown side to move counts as needing a look', () {
      final position = ScannedPosition.fromJson({'fen': _mateInOne, 'page': 1});
      expect(position.sideSource, 'nepoznato');
      expect(position.needsReview, isTrue);
    });

    test('flipping the side rewrites the FEN and clears the en passant square',
        () {
      // The en passant square records the *other* side's last move; leaving it
      // behind after the mover changes makes the position illegal.
      final position = ScannedPosition(
          fen: 'rb6/k1p4R/P1P5/PpK5/8/8/8/5B2 w - b6 0 1', page: 3);
      expect(position.sideToMove, 'w');

      position.flipSide();

      expect(position.sideToMove, 'b');
      expect(position.fen.split(' ')[3], '-');
      expect(position.fen.split(' ')[0], 'rb6/k1p4R/P1P5/PpK5/8/8/8/5B2',
          reason: 'flipping the side must not disturb the pieces');
    });

    test('castling rights survive a side flip', () {
      final position = ScannedPosition(
          fen: '8/8/8/8/8/5N2/1pr3PP/r1k1K2R w K - 0 1', page: 9);
      position.flipSide();
      expect(position.fen.split(' ')[2], 'K');
    });

    test("the book's own words for the motif become tags", () {
      final position = ScannedPosition(
        fen: _mateInOne,
        page: 1,
        themesText: 'interference/skewer',
      );
      expect(position.toConfirmJson()['themes'], ['interference', 'skewer']);
    });

    test('a solution that did not verify is not sent as a solution', () {
      final position = ScannedPosition(
        fen: _mateInOne,
        page: 1,
        solutionSan: 'Rh8#',
        solutionLegal: false,
        problem: 'potez iz knjige nije legalan',
      );
      final json = position.toConfirmJson();
      expect(json.containsKey('solutionSan'), isFalse);
      expect(json['needsReview'], isTrue);
    });
  });

  group('ScanResult', () {
    test('counts how many positions need a look', () {
      final result = ScanResult.fromJson({
        'documentName': 'knjiga.pdf',
        'pageCount': 300,
        'scannedFrom': 1,
        'scannedTo': 20,
        'font': 'SkakNew-Diagram',
        'positions': [
          {'fen': _mateInOne, 'page': 1, 'sideSource': 'resenje'},
          {'fen': _mateInOne, 'page': 2, 'sideSource': 'nepoznato'},
          {
            'fen': _mateInOne,
            'page': 3,
            'sideSource': 'resenje',
            'problem': 'ne valja'
          },
        ],
      });
      expect(result.positions, hasLength(3));
      expect(result.needingReview, 2);
    });
  });
}
