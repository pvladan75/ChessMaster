import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/assignments/models/assignment.dart';

const _fen = '5Q2/8/8/8/6p1/8/2NNk3/2K5 w - - 0 1';

void main() {
  group('LessonStep instruction', () {
    test('carries the task a trainer wrote for this step', () {
      final step = LessonStep.fromJson({
        'title': 'Završnica sa skakačem',
        'fen': _fen,
        'instruction': 'Beli je na potezu — nađi mat.',
      });
      expect(step.title, 'Završnica sa skakačem');
      expect(step.instruction, 'Beli je na potezu — nađi mat.');
    });

    test('a step written before the field existed simply has none', () {
      // Lessons already saved must keep working; the viewer says nothing
      // rather than inventing a task for them.
      final step = LessonStep.fromJson({'title': 'Korak', 'fen': _fen});
      expect(step.instruction, isNull);
    });

    test('blank text counts as no task, not as an empty one', () {
      expect(
          LessonStep.fromJson({'title': 'x', 'fen': _fen, 'instruction': ''})
              .instruction,
          isNull);
      expect(
          LessonStep.fromJson({'title': 'x', 'fen': _fen, 'instruction': '   '})
              .instruction,
          isNull);
    });

    test('surrounding spaces are trimmed off what the trainer typed', () {
      final step = LessonStep.fromJson({
        'title': 'x',
        'fen': _fen,
        'instruction': '  Nađi dobitak figure  '
      });
      expect(step.instruction, 'Nađi dobitak figure');
    });

    test('the title is not used as a fallback task', () {
      // A name is not a question. Showing "Završnica sa skakačem" where the
      // task belongs would look like an instruction while telling the student
      // nothing about what to do.
      final step =
          LessonStep.fromJson({'title': 'Završnica sa skakačem', 'fen': _fen});
      expect(step.instruction, isNot('Završnica sa skakačem'));
      expect(step.instruction, isNull);
    });
  });
}
