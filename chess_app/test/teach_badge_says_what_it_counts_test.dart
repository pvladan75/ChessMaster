// The number on „Teach" says what it is counting.
//
// Reported live on 18.9.2026 against TODO-provera 177.6: „Ne razumem ovu
// notifikaciju na tabu Teach gde piše 1". The number was right — one piece of
// homework handed in and not opened — and said so nowhere.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/trainer_panel/models/trainer_panel.dart';

void main() {
  PanelAssignment assignment(int id) => PanelAssignment(
        id: id,
        studentId: id,
        studentName: 'Student $id',
        title: 'Homework $id',
      );

  test('nothing waiting explains nothing', () {
    expect(const TrainerPanel().waitingExplanation, isNull);
    expect(
      TrainerPanel(awaitingReview: [assignment(1)], waiting: 0)
          .waitingExplanation,
      isNull,
      reason: 'the badge is not drawn, so there is nothing to explain',
    );
  });

  test('one homework, and the sentence the owner was missing', () {
    final panel = TrainerPanel(awaitingReview: [assignment(1)], waiting: 1);
    expect(panel.waitingExplanation, '1 homework to review');
  });

  test('both halves of the number are named, and both are plural-aware', () {
    final panel = TrainerPanel(
      awaitingReview: [assignment(1), assignment(2)],
      waiting: 5,
      requests: 3,
    );
    expect(panel.waitingExplanation,
        '2 homeworks to review · 3 requests to answer');
  });

  test('a number this client cannot break down still says something', () {
    // The server owns `waiting`; a section added there and not here must not
    // turn the badge back into a bare number with no sentence.
    const panel = TrainerPanel(waiting: 4);
    expect(panel.waitingExplanation, '4 waiting for you');
  });

  test('the request half is read off the wire, not subtracted', () {
    final panel = TrainerPanel.fromJson({
      'awaitingReview': [
        {'id': 1, 'student_id': 1, 'student_name': 'A', 'title': 'H'}
      ],
      'counts': {'waiting': 3, 'requests': 2},
    });
    expect(panel.requests, 2);
    expect(panel.waitingExplanation,
        '1 homework to review · 2 requests to answer');
  });
}
