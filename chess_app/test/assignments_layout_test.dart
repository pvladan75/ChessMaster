// The gate of phase 11 of docs/PLAN-EKRANI.md: My Assignments and a
// homework's items, as the owner chose from `docs/skice/ekrani/compare_myasg.png`
// and `compare_homework.png`.
//
// My Assignments: the assignments as cards in columns on a window
// (`AdaptiveCardGrid`, rule R7), each card's „Review and comments" beside the
// card's own figures instead of alone at the far edge of a 1500 px row, and
// Open / Done / All filters counted from the list itself.
// A homework's items: one numbered list of reading width, one line a step
// (today a 120 px card each), the step that can be done now the one filled
// `Continue` (R4), a finished step's `Review` a text button.
//
// The app's own theme with real Roboto, as phase 1 taught.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/assignments/screens/my_assignments_screen.dart';
import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/features/homework/screens/homework_assignment_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_theme.dart';
import 'package:chess_app/widgets/adaptive_card_grid.dart';

import 'support/landscape.dart';
import 'support/render_look.dart';

const _window = Size(1536, 792);
const _phone = Size(360, 640);

UserSession _student() => UserSession(
    token: 'tok', id: 1, email: 'a@example.com', name: 'S', role: 'ucenik');

Finder _button<T extends Widget>(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byWidgetPredicate((w) => w is T),
    );

/// A trainer's instruction longer than a line of a card: it is the trainer's
/// word to the student, and is drawn whole, never cut to one line.
const _longInstruction = 'Ten positions. Look for the checks first, then '
    'the captures, then the threats - in that order, every time.';

// ── My Assignments ───────────────────────────────────────────────────────

/// Four open and two finished, none overdue: the filters have something to
/// tell apart.
class _Mine extends AssignmentApiService {
  _Mine() : super(authToken: 'tok');

  static Map<String, dynamic> _a(int id, String title,
          {String? completedAt, int total = 10, int attempted = 4}) =>
      {
        'id': id,
        'title': title,
        'kind': 'puzzles',
        'due_at': '2099-10-06T00:00:00.000Z',
        'completed_at': completedAt,
        'total_items': total,
        'attempted_items': attempted,
        'solved_items': attempted,
        'trainer_name': 'Marko Ilić',
        if (id == 1) 'instructions': _longInstruction,
      };

  @override
  Future<List<Assignment>> fetchMine() async => [
        for (final json in [
          _a(1, 'Back-rank mates, set 3'),
          _a(2, 'Forks from the Italian Game', attempted: 2),
          _a(3, 'Pins and skewers', attempted: 0),
          _a(4, 'Rook endings', attempted: 1),
          _a(5, 'Mate in 2 warm-up',
              completedAt: '2026-10-01T10:00:00.000Z', total: 6, attempted: 6),
          _a(6, 'Knight forks',
              completedAt: '2026-09-28T10:00:00.000Z', total: 5, attempted: 5),
        ])
          Assignment.fromJson(json)
      ];

  @override
  Future<StudentProgress?> fetchProgress(
          {int days = 30, int? studentId}) async =>
      null;
}

Future<void> _pumpMine(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: robotoTheme(AppTheme.dark),
    home: MyAssignmentsScreen(
        key: UniqueKey(), session: _student(), api: _Mine()),
  ));
  await tester.pumpAndSettle();
}

// ── a homework's items ───────────────────────────────────────────────────

Map<String, dynamic> _child(int id, String title, int position,
        {String? completedAt, bool locked = false, int? blockedBy}) =>
    {
      'id': id,
      'title': title,
      'kind': 'puzzles',
      'position': position,
      'item_key': 'i$id',
      'lesson_id': null,
      'gate': true,
      'gate_opened_at': null,
      'completed_at': completedAt,
      'task': null,
      'total_items': 4,
      'attempted_items': completedAt == null ? 1 : 4,
      'solved_items': completedAt == null ? 1 : 4,
      'passed': completedAt != null,
      'locked': locked,
      'blocked_by': blockedBy,
    };

Map<String, dynamic> _homework() => {
      'id': 7,
      'title': 'Thursday',
      'instructions': 'Read first, then solve, then play the ending out.',
      'kind': 'homework',
      'trainer_id': 9,
      'student_id': 1,
      'trainer_name': 'Marko Ilić',
      'due_at': null,
      'completed_at': null,
      'total_items': 0,
      'attempted_items': 0,
      'solved_items': 0,
      'child_total': 6,
      'child_completed': 2,
      'children': [
        _child(601, 'Back-rank mates, set 3', 0,
            completedAt: '2026-10-01T10:00:00.000Z'),
        _child(602, 'Pins', 1, completedAt: '2026-10-01T11:00:00.000Z'),
        _child(603, 'Forks from the Italian Game', 2),
        _child(604, 'Find the pin', 3, locked: true, blockedBy: 603),
        _child(605, 'Play it out: win it', 4, locked: true, blockedBy: 604),
        _child(606, 'Rook behind the passed pawn', 5,
            locked: true, blockedBy: 605),
      ],
    };

Future<void> _pumpHomework(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final client = MockClient((request) async {
    if (request.url.path == '/assignments/7' && request.method == 'GET') {
      return http.Response(jsonEncode(_homework()), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    return http.Response('{"error":"not found"}', 404);
  });
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      theme: robotoTheme(AppTheme.dark),
      home: HomeworkAssignmentScreen(
        key: UniqueKey(),
        session: _student(),
        assignmentId: 7,
        api: AssignmentApiService(authToken: 'tok', client: client),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Rect _stateRect(WidgetTester tester, int id) =>
    tester.getRect(find.byKey(Key('homework-child-state-$id')));

void main() {
  setUpAll(loadRoboto);

  group('My Assignments', () {
    testWidgets(
        'on a window: cards in columns, Review beside the card\'s own figures',
        (tester) async {
      await _pumpMine(tester, _window);
      expect(tester.takeException(), isNull);
      // Either half of pattern A; what matters is columns and nothing cut.
      // Widened at grading (3.10.2026): a fixed 148 px cell cut the
      // trainer's instruction to one line.
      expect(
          find.byType(AdaptiveCardGrid).evaluate().length +
              find.byType(AdaptiveCardRows).evaluate().length,
          1);
      final instruction =
          tester.renderObject<RenderParagraph>(find.text(_longInstruction));
      expect(instruction.didExceedMaxLines, isFalse,
          reason: 'the instruction of the trainer is drawn whole');
      final first = tester.getRect(find.text('Back-rank mates, set 3'));
      final second = tester.getRect(find.text('Forks from the Italian Game'));
      expect(second.top, closeTo(first.top, 1),
          reason: 'two cards on one row: the width is used (R7)');
      // The card's action stands within a card's reach of its title, not at
      // the far edge of the window.
      final review = tester.getRect(find.text('Review and comments').first);
      expect(review.right - first.left, lessThan(560));
    });

    testWidgets('Open, Done and All filter the list they are counted from',
        (tester) async {
      await _pumpMine(tester, _window);
      expect(find.textContaining('Open (4)'), findsOneWidget);
      expect(find.textContaining('Done (2)'), findsOneWidget);
      await tester.tap(find.textContaining('Done (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Mate in 2 warm-up'), findsOneWidget);
      expect(find.text('Back-rank mates, set 3'), findsNothing);
      await tester.tap(find.textContaining('Open (4)'));
      await tester.pumpAndSettle();
      expect(find.text('Back-rank mates, set 3'), findsOneWidget);
      expect(find.text('Mate in 2 warm-up'), findsNothing);
    });

    testWidgets('on a 360 dp phone nothing overflows', (tester) async {
      await _pumpMine(tester, _phone);
      expect(tester.takeException(), isNull);
    });
  });

  group('a homework\'s items', () {
    testWidgets(
        'on a window: one list of reading width, one line a step, Continue '
        'the one filled button', (tester) async {
      await _pumpHomework(tester, _window);
      expect(tester.takeException(), isNull);
      final first = _stateRect(tester, 601);
      final second = _stateRect(tester, 602);
      expect(second.top - first.top, lessThan(76),
          reason: 'one line a step, not a 120 px card');
      final last = _stateRect(tester, 606);
      expect(last.right - first.left, lessThan(900),
          reason: 'a list of reading width, not the window\'s');
      expectOnScreen(
          tester, _window, find.byKey(const Key('homework-child-state-606')));
      expect(find.byWidgetPredicate((w) => w is FilledButton), findsOneWidget);
      expect(_button<FilledButton>('Continue'), findsOneWidget);
      expect(_button<TextButton>('Review'), findsWidgets);
    });

    testWidgets('on a 360 dp phone nothing overflows', (tester) async {
      await _pumpHomework(tester, _phone);
      expect(tester.takeException(), isNull);
      expect(_button<FilledButton>('Continue'), findsOneWidget);
    });
  });
}
