import 'package:chess_app/features/assignments/models/solve_order.dart';
import 'package:flutter_test/flutter_test.dart';

/// Homework used to be a queue with no way out of it. These pin the two rules
/// that replace it: the trainer's order still decides what "next" means, and
/// nothing gets left behind by it.
void main() {
  final ids = ['a', 'b', 'c', 'd'];

  test('next means the next one still waiting, in the trainer\'s order', () {
    final next = nextUnanswered(puzzleIds: ids, answered: {'a'}, from: 0);

    expect(next, 1);
  });

  test('answered positions are stepped over rather than offered again', () {
    final next = nextUnanswered(puzzleIds: ids, answered: {'b', 'c'}, from: 0);

    expect(next, 3);
  });

  test('a position skipped early is still reached from the end', () {
    // The child jumped past 'b', answered the rest, and pressed next on the
    // last one. Without wrapping, 'b' would be left behind by a button that
    // says "next" — and they would have to know to go back and look.
    final next = nextUnanswered(
      puzzleIds: ids,
      answered: {'a', 'c', 'd'},
      from: 3,
    );

    expect(next, 1);
  });

  test('nothing left is said with null, not with a position', () {
    final next = nextUnanswered(
      puzzleIds: ids,
      answered: {'a', 'b', 'c', 'd'},
      from: 2,
    );

    expect(next, isNull);
  });

  test('an empty assignment has no next position', () {
    expect(nextUnanswered(puzzleIds: const [], answered: const {}, from: 0),
        isNull);
  });

  test('the current position is never offered as its own next', () {
    // 'c' is unanswered and we are standing on it; next has to move on.
    final next = nextUnanswered(puzzleIds: ids, answered: {'a', 'b'}, from: 2);

    expect(next, 3);
  });

  test('opening lands on the first thing waiting, not where they left off', () {
    // 'b' was skipped and 'c' answered. The first thing still waiting is 'b',
    // and that is where the assignment should reopen.
    final start = firstUnanswered(puzzleIds: ids, answered: {'a', 'c'});

    expect(start, 1);
  });

  test('a finished assignment has nowhere to land', () {
    expect(firstUnanswered(puzzleIds: ids, answered: {'a', 'b', 'c', 'd'}),
        isNull);
  });
}
