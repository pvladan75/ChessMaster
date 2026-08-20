import 'package:chess_app/features/assignments/models/assignment_review.dart';
import 'package:flutter_test/flutter_test.dart';

/// The review is the first thing that shows a finished piece of homework as
/// something other than two numbers, so what its model does with an absent
/// field decides what the screen tells a child about their own work.
void main() {
  Map<String, dynamic> payload({
    List<Map<String, dynamic>>? items,
    List<Map<String, dynamic>>? notes,
    bool isTrainer = false,
  }) =>
      {
        'assignment': {
          'id': 7,
          'title': 'Mat u 333',
          'kind': 'custom',
          'instructions': 'Uradi do petka',
          'trainerName': 'Trener',
          'studentName': 'Učenik',
        },
        'viewer': {'isTrainer': isTrainer, 'isStudent': !isTrainer},
        'items': items ?? const [],
        'notes': notes ?? const [],
      };

  test('an unrecorded move is unknown, never "played nothing"', () {
    final review = AssignmentReview.fromJson(payload(items: [
      {
        'itemId': 1,
        'position': 0,
        'kind': 'custom',
        'attempted': true,
        'solved': false,
        'playedSan': null,
      },
    ]));

    // Rows answered before the move was stored have none, and the Lichess path
    // never reports one. The screen has to be able to tell that apart from a
    // position that was never opened.
    expect(review.items.single.playedSan, isNull);
    expect(review.items.single.attempted, isTrue);
  });

  test('a hidden solution is not the same as no solution', () {
    final review = AssignmentReview.fromJson(payload(items: [
      {
        'itemId': 1,
        'position': 0,
        'kind': 'custom',
        'attempted': false,
        'solutionSan': null,
        'solutionHidden': true,
      },
    ]));

    expect(review.items.single.solutionSan, isNull);
    expect(review.items.single.solutionHidden, isTrue);
  });

  test('a lesson step has no verdict, rather than a false one', () {
    final review = AssignmentReview.fromJson(payload(items: [
      {
        'itemId': 2,
        'position': 0,
        'kind': 'step',
        'attempted': true,
        'solved': null,
        'title': 'Vezivanje',
      },
    ]));

    expect(review.items.single.kind, ReviewItemKind.step);
    expect(review.items.single.solved, isNull);
  });

  test('an item whose puzzle is gone is still an item', () {
    final review = AssignmentReview.fromJson(payload(items: [
      {
        'itemId': 3,
        'position': 0,
        'kind': 'unknown',
        'attempted': true,
        'solved': true
      },
    ]));

    expect(review.items.single.kind, ReviewItemKind.unknown);
    expect(review.items.single.fen, isNull);
    expect(review.solvedCount, 1);
  });

  test('notes split into the assignment and the position they are about', () {
    final review = AssignmentReview.fromJson(payload(
      items: [
        {'itemId': 11, 'position': 0, 'kind': 'custom', 'attempted': true},
      ],
      notes: [
        {
          'id': 1,
          'itemId': null,
          'body': 'Bravo',
          'mine': false,
          'authorName': 'Trener'
        },
        {'id': 2, 'itemId': 11, 'body': 'Ovu nisam razumeo', 'mine': true},
      ],
    ));

    expect(review.generalNotes.map((n) => n.id), [1]);
    expect(review.notesFor(11).map((n) => n.id), [2]);
    expect(review.notesFor(999), isEmpty);
  });

  test('a new note appears without refetching, and can be taken back', () {
    var review = AssignmentReview.fromJson(payload());

    review = review.withNote(
        const AssignmentNote(id: 5, body: 'pitanje', mine: true, itemId: 11));
    expect(review.notesFor(11).single.body, 'pitanje');

    review = review.withoutNote(5);
    expect(review.notes, isEmpty);
    // The rest of the review survives both operations.
    expect(review.title, 'Mat u 333');
    expect(review.instructions, 'Uradi do petka');
  });

  test('which side is reading comes from the server, not from a guess', () {
    expect(
        AssignmentReview.fromJson(payload(isTrainer: true)).isTrainer, isTrue);
    expect(AssignmentReview.fromJson(payload()).isTrainer, isFalse);
  });

  test('an item with no name falls back to its place in the order', () {
    final item = ReviewItem.fromJson(
        {'itemId': 1, 'position': 2, 'kind': 'lichess', 'attempted': true});

    expect(item.label(2), 'Pozicija 3');
  });

  test('a puzzle keeps the first wrong idea, not "the move played"', () {
    final review = AssignmentReview.fromJson(payload(items: [
      {
        'itemId': 4,
        'position': 0,
        'kind': 'lichess',
        'attempted': true,
        'solved': true,
        'playedSan': 'Qe2+',
        'solutionMoves': 'Rb7 Rxb7 g8=Q',
      },
    ]));

    // Solved, and still carrying a wrong move: a puzzle refuses the wrong move
    // and lets the student try again, so the two are not in conflict.
    final item = review.items.single;
    expect(item.kind, ReviewItemKind.lichess);
    expect(item.solved, isTrue);
    expect(item.playedSan, 'Qe2+');
    expect(item.solutionMoves, 'Rb7 Rxb7 g8=Q');
  });

  test('a puzzle solved cleanly carries no move at all', () {
    final review = AssignmentReview.fromJson(payload(items: [
      {
        'itemId': 5,
        'position': 0,
        'kind': 'lichess',
        'attempted': true,
        'solved': true,
        'playedSan': null,
      },
    ]));

    // Nothing went wrong, so there is nothing to show — which the screen must
    // not render as "nije zabeležen".
    expect(review.items.single.playedSan, isNull);
    expect(review.items.single.solved, isTrue);
  });
}
