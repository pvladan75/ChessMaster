import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/features/assignments/models/assignment.dart';

Map<String, dynamic> assignmentJson({
  int total = 10,
  int attempted = 0,
  int solved = 0,
  String? dueAt,
  String? completedAt,
}) =>
    {
      'id': 1,
      'title': 'Vežba: vezivanje',
      'total_items': total,
      'attempted_items': attempted,
      'solved_items': solved,
      'due_at': dueAt,
      'completed_at': completedAt,
      'themes': ['pin'],
    };

void main() {
  group('Assignment', () {
    test('progress and accuracy reflect what has been attempted', () {
      final assignment = Assignment.fromJson(
        assignmentJson(total: 10, attempted: 4, solved: 3),
      );

      expect(assignment.progress, 0.4);
      // Accuracy is over attempts, not over the whole assignment — otherwise a
      // half-finished assignment would always look like failure.
      expect(assignment.accuracy, 75);
    });

    test('accuracy is null before anything is attempted', () {
      final assignment = Assignment.fromJson(assignmentJson(attempted: 0));

      expect(assignment.accuracy, isNull,
          reason: '0% would read as "gets everything wrong"');
      expect(assignment.progress, 0);
    });

    test('an assignment with no items does not divide by zero', () {
      final assignment = Assignment.fromJson(assignmentJson(total: 0));

      expect(assignment.progress, 0);
      expect(assignment.accuracy, isNull);
    });

    test('completion is reached either by the stamp or by finishing every item',
        () {
      expect(
        Assignment.fromJson(assignmentJson(total: 5, attempted: 5)).isComplete,
        isTrue,
      );
      expect(
        Assignment.fromJson(
          assignmentJson(
              total: 5, attempted: 2, completedAt: '2026-08-15T10:00:00Z'),
        ).isComplete,
        isTrue,
      );
      expect(
        Assignment.fromJson(assignmentJson(total: 5, attempted: 2)).isComplete,
        isFalse,
      );
    });

    test('a finished assignment is never flagged overdue', () {
      final past =
          DateTime.now().subtract(const Duration(days: 3)).toIso8601String();

      final done = Assignment.fromJson(
        assignmentJson(total: 5, attempted: 5, dueAt: past),
      );
      final unfinished = Assignment.fromJson(
        assignmentJson(total: 5, attempted: 1, dueAt: past),
      );

      // Nagging about work that is already done helps nobody.
      expect(done.isOverdue, isFalse);
      expect(unfinished.isOverdue, isTrue);
    });

    test('an assignment without a deadline is never overdue', () {
      expect(
          Assignment.fromJson(assignmentJson(attempted: 1)).isOverdue, isFalse);
    });
  });

  group('lesson assignments', () {
    Map<String, dynamic> lessonJson({int total = 4, int attempted = 0}) => {
          ...assignmentJson(total: total, attempted: attempted, solved: 0),
          'kind': 'lesson',
          'lesson_id': 12,
        };

    test('a lesson never reports an accuracy', () {
      final lesson = Assignment.fromJson(lessonJson(total: 4, attempted: 4));

      expect(lesson.kind, AssignmentKind.lesson);
      // Stepping through a lesson has no right answer; solved_items stays 0, so
      // a percentage here would report a finished lesson as 0% correct.
      expect(lesson.accuracy, isNull);
      expect(lesson.progress, 1.0);
      expect(lesson.isComplete, isTrue);
    });

    test('an unrecognised kind falls back to puzzles', () {
      final unknown =
          Assignment.fromJson({...assignmentJson(), 'kind': 'something_new'});
      expect(unknown.kind, AssignmentKind.puzzles);
    });

    test('lesson steps parse alongside their progress items', () {
      final detail = AssignmentDetail.fromJson({
        ...lessonJson(total: 3, attempted: 1),
        'items': [
          {'position': 0, 'attempted_at': '2026-08-15T10:00:00Z'},
          {'position': 1},
          {'position': 2},
        ],
        'steps': [
          {'title': 'Uvod', 'fen': '8/8/8/8/8/8/8/K6k w - - 0 1', 'pgn': null},
          {'title': 'Ključna pozicija', 'fen': '8/8/8/8/8/8/8/K6k b - - 0 1'},
          {'title': 'Zaključak', 'fen': '8/8/8/8/8/8/8/K6k w - - 0 1'},
        ],
      });

      expect(detail.steps.length, 3);
      expect(detail.steps.first.title, 'Uvod');
      // Lesson items carry no puzzle id — they are identified by position.
      expect(detail.items.first.puzzleId, isNull);
    });

    test('resuming lands on the first unread step', () {
      final detail = AssignmentDetail.fromJson({
        ...lessonJson(total: 3, attempted: 2),
        'items': [
          {'position': 0, 'attempted_at': '2026-08-15T10:00:00Z'},
          {'position': 1, 'attempted_at': '2026-08-15T10:05:00Z'},
          {'position': 2},
        ],
        'steps': [
          {'title': 'a', 'fen': 'x'},
          {'title': 'b', 'fen': 'y'},
          {'title': 'c', 'fen': 'z'},
        ],
      });

      expect(detail.resumeStepIndex, 2,
          reason: 'must not restart a half-read lesson');
    });

    test('a fully read lesson resumes on its last step, not past the end', () {
      final detail = AssignmentDetail.fromJson({
        ...lessonJson(total: 2, attempted: 2),
        'items': [
          {'position': 0, 'attempted_at': '2026-08-15T10:00:00Z'},
          {'position': 1, 'attempted_at': '2026-08-15T10:05:00Z'},
        ],
        'steps': [
          {'title': 'a', 'fen': 'x'},
          {'title': 'b', 'fen': 'y'},
        ],
      });

      // Re-opening a finished lesson is normal; an out-of-range index would crash.
      expect(detail.resumeStepIndex, 1);
    });

    test('a lesson with no items resumes at zero', () {
      final detail = AssignmentDetail.fromJson(
          {...lessonJson(), 'items': [], 'steps': []});
      expect(detail.resumeStepIndex, 0);
    });
  });

  group('AssignmentDetail', () {
    test('pending keeps only the untouched items, in order', () {
      final detail = AssignmentDetail.fromJson({
        ...assignmentJson(total: 3, attempted: 1),
        'items': [
          {
            'puzzle_id': 'a',
            'position': 0,
            'attempted_at': '2026-08-15T10:00:00Z',
            'solved': true
          },
          {'puzzle_id': 'b', 'position': 1},
          {'puzzle_id': 'c', 'position': 2},
        ],
      });

      // Returning to a half-done assignment must resume, not restart.
      expect(detail.pending.map((item) => item.puzzleId), ['b', 'c']);
      expect(detail.items.first.isDone, isTrue);
    });

    test('an assignment with no items yields nothing pending', () {
      final detail =
          AssignmentDetail.fromJson({...assignmentJson(), 'items': []});
      expect(detail.pending, isEmpty);
    });
  });

  group('StudentProgress', () {
    test('parses the report and its assignment counters', () {
      final progress = StudentProgress.fromJson({
        'periodDays': 30,
        'overallRating': 1620,
        'totalAttempts': 40,
        'solvedAttempts': 26,
        'accuracy': 65,
        'activeDays': 9,
        'lifetimeSolved': 210,
        'weakestThemes': [
          {'theme': 'pin', 'attempts': 8, 'solved': 2, 'accuracy': 25},
        ],
        'strongestThemes': [
          {'theme': 'fork', 'attempts': 12, 'solved': 11, 'accuracy': 92},
        ],
        'assignments': {'total': 6, 'completed': 4, 'overdue': 1},
      });

      expect(progress.hasData, isTrue);
      expect(progress.accuracy, 65);
      expect(progress.weakestThemes.single.theme, 'pin');
      expect(progress.assignmentsOverdue, 1);
    });

    test('a student with no attempts reports no data rather than zero accuracy',
        () {
      final progress =
          StudentProgress.fromJson({'totalAttempts': 0, 'accuracy': null});

      expect(progress.hasData, isFalse);
      expect(progress.accuracy, isNull);
      expect(progress.weakestThemes, isEmpty);
    });

    test('a truncated payload degrades to safe defaults', () {
      final progress = StudentProgress.fromJson({});

      expect(progress.overallRating, 1500);
      expect(progress.hasData, isFalse);
      expect(progress.assignmentsTotal, 0);
    });
  });

  group('themeLabel', () {
    test('translates known Lichess motifs into Serbian', () {
      expect(themeLabel('pin'), 'vezivanje');
      expect(themeLabel('hangingPiece'), 'nezaštićena figura');
    });

    test('falls back to the raw tag so a new motif is still shown', () {
      // Hiding an unlabelled theme would silently drop it from a trainer's report.
      expect(themeLabel('someNewLichessTheme'), 'someNewLichessTheme');
    });
  });
}
