import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/assignments/models/assignment.dart';

const _fen = '5Q2/8/8/8/6p1/8/2NNk3/2K5 w - - 0 1';

Map<String, dynamic> _detail(
        {List<Map<String, dynamic>> positions = const []}) =>
    {
      'id': 7,
      'title': 'Matovi u jedan',
      'kind': 'puzzles',
      'items': [
        {'puzzle_id': 'cust_a', 'position': 0},
        {'puzzle_id': 'cust_b', 'position': 1},
      ],
      'customPositions': positions,
    };

void main() {
  group('CustomPosition', () {
    test('never carries the solution to the student', () {
      // The answer is the thing being asked for; it stays on the server until
      // the student has answered. Nothing in the model can even hold it.
      final json = {
        'puzzle_id': 'cust_a',
        'fen': _fen,
        'side_to_move': 'w',
        'instruction': 'Beli matira u jednom potezu.',
        'solution_san': 'Qf1#',
      };
      final position = CustomPosition.fromJson(json);
      expect(position.instruction, 'Beli matira u jednom potezu.');
      expect(
        CustomPosition.fromJson(json).toString(),
        isNot(contains('Qf1')),
        reason:
            'a solution must not survive anywhere in the student-side model',
      );
    });

    test('a position with no task falls back to nothing, not to a guess', () {
      final position = CustomPosition.fromJson(
          {'puzzle_id': 'cust_a', 'fen': _fen, 'side_to_move': 'b'});
      expect(position.instruction, isNull);
      expect(position.sideToMove, 'b');
    });
  });

  group('AssignmentDetail', () {
    test('knows when homework was built from the trainer\'s own positions', () {
      final plain = AssignmentDetail.fromJson(_detail());
      expect(plain.isCustom, isFalse,
          reason: 'Lichess homework must keep going to the old solver');

      final custom = AssignmentDetail.fromJson(_detail(positions: [
        {'puzzle_id': 'cust_a', 'fen': _fen, 'side_to_move': 'w'},
      ]));
      expect(custom.isCustom, isTrue);
    });

    test('matches a position to the item that refers to it', () {
      final detail = AssignmentDetail.fromJson(_detail(positions: [
        {
          'puzzle_id': 'cust_b',
          'fen': _fen,
          'side_to_move': 'w',
          'instruction': 'Drugi'
        },
        {
          'puzzle_id': 'cust_a',
          'fen': _fen,
          'side_to_move': 'b',
          'instruction': 'Prvi'
        },
      ]));
      expect(detail.positionFor('cust_a')?.instruction, 'Prvi');
      expect(detail.positionFor('cust_b')?.instruction, 'Drugi');
      expect(detail.positionFor('cust_nema'), isNull);
    });
  });

  group('CustomAttemptResult', () {
    test('carries why an answer counted, not just that it did', () {
      final result = CustomAttemptResult.fromJson({
        'correct': true,
        'reason': 'drugi mat, ali mat',
        'playedSan': 'Qh7#',
        'solutionSan': 'Qe6#',
      });
      expect(result.correct, isTrue);
      expect(result.reason, 'drugi mat, ali mat');
      expect(result.playedSan, 'Qh7#');
    });

    test('a wrong answer comes back with the solution attached', () {
      final result = CustomAttemptResult.fromJson({
        'correct': false,
        'reason': 'nije traženi potez',
        'solutionSan': 'Qf1#'
      });
      expect(result.correct, isFalse);
      expect(result.solutionSan, 'Qf1#');
    });
  });
}
