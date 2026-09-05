import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/reviews/services/review_api_service.dart';

/// Phase 1 of `docs/PLAN-INTERAKTIVNA-LEKCIJA.md`, on the client's side of the
/// wire.
///
/// The schedule is keyed on the step's own name, not on where the step sits: a
/// trainer inserting a step ahead of it changes `position` and changes nothing
/// about which board the student is being asked. So the key has to survive the
/// trip out of JSON and back into the grade — dropped here, the app would go on
/// grading by index against a server that has stopped listening to it.
void main() {
  Map<String, dynamic> due({String? stepKey, int position = 0}) => {
        'id': 1,
        'lessonId': 5,
        if (stepKey != null) 'stepKey': stepKey,
        'position': position,
        'lessonTitle': 'Slaba polja',
        'repetitions': 1,
        'step': {
          'title': 'Korak',
          'fen': '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1',
        },
      };

  test('the step key survives the trip out of JSON', () {
    final item = ReviewItem.fromJson(due(stepKey: 'bbbb0002', position: 2));

    expect(item.stepKey, 'bbbb0002');
    expect(item.position, 2);
  });

  test('a server that does not send a key yet leaves it empty, not null', () {
    // An older backend answers without `stepKey`. The item still has to parse —
    // the review session is the screen a child opens, and a null here would
    // take the whole queue down rather than one field.
    final item = ReviewItem.fromJson(due());

    expect(item.stepKey, '');
    expect(item.lessonId, 5);
  });

  test('the key is what tells two items of one lesson apart', () {
    // Both rows are lesson 5. Before the key, `position` was the only thing
    // separating them, and it is exactly what an edit moves.
    final first = ReviewItem.fromJson(due(stepKey: 'aaaa0001', position: 1));
    final second = ReviewItem.fromJson(due(stepKey: 'bbbb0002', position: 1));

    expect(first.lessonId, second.lessonId);
    expect(first.position, second.position);
    expect(first.stepKey, isNot(second.stepKey));
  });
}
