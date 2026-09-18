// Four rules added while grading phase 5 of `docs/PLAN-DOMACI-ZADATAK.md`,
// none of them reached by the phase's gate or by its own companion tests:
//
//   1. **Three answers, not two**, from `fetchDetail`: the detail, „locked
//      and here is what blocks it", or „the request was not answered". The
//      server sends a locked item as **423** — the companion test sends it
//      as 200, so a check written against a status rather than the body
//      would pass there and fail in front of a student.
//   2. The trainer's own screen does not say „your trainer" to the trainer.
//   3. A child that has been worked on offers its **review** — the parent has
//      none, because `buildReview` is built from `assignment_items`.
//   4. One wording for „how far is this homework", shared by the three rows
//      that show it (`Assignment.itemsSummary`).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/assignments/screens/assignment_review_screen.dart';
import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/features/homework/screens/homework_assignment_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';

import 'support/landscape.dart';

const _studentId = 1;
const _trainerId = 9;

UserSession _session(int id) => UserSession(
      token: 'tok',
      id: id,
      email: 'a@example.com',
      name: id == _trainerId ? 'Trainer' : 'Student',
      role: id == _trainerId ? 'trener' : 'ucenik',
    );

/// A tutorial already read (three parts, so it has something to review) and a
/// game the trainer unlocked early.
Map<String, dynamic> _parent() => {
      'id': 7,
      'title': 'Thursday',
      'kind': 'homework',
      'trainer_id': _trainerId,
      'student_id': _studentId,
      'total_items': 0,
      'attempted_items': 0,
      'solved_items': 0,
      'child_total': 3,
      'child_completed': 1,
      'children': [
        {
          'id': 501,
          'title': 'My Tutorial',
          'kind': 'lesson',
          'position': 0,
          'item_key': 'ia1b2c3d4',
          'lesson_id': 31,
          'gate': false,
          'gate_opened_at': null,
          'completed_at': '2026-09-17T10:00:00.000Z',
          'total_items': 3,
          'attempted_items': 3,
          'solved_items': 0,
          'passed': true,
          'locked': false,
          'blocked_by': null,
        },
        {
          'id': 502,
          'title': 'Two positions',
          'kind': 'puzzles',
          'position': 1,
          'item_key': 'ie5f6a7b8',
          'gate': true,
          'gate_opened_at': null,
          'completed_at': null,
          'total_items': 2,
          'attempted_items': 0,
          'solved_items': 0,
          'passed': false,
          'locked': false,
          'blocked_by': null,
        },
        {
          'id': 503,
          'title': 'Play it out: win it',
          'kind': 'engine_game',
          'position': 2,
          'item_key': 'i90c1d2e3',
          'gate': true,
          'gate_opened_at': '2026-09-17T11:00:00.000Z',
          'completed_at': null,
          'task': {
            'fen': '4k3/8/8/8/8/8/8/4K2R w - - 0 1',
            'side': 'w',
            'goal': 'win',
          },
          'total_items': 1,
          'attempted_items': 0,
          'solved_items': 0,
          'passed': false,
          'locked': false,
          'blocked_by': null,
        },
      ],
    };

http.Client _client(List<http.Request> seen) => MockClient((request) async {
      seen.add(request);
      final path = request.url.path;
      if (path == '/assignments/7' && request.method == 'GET') {
        return http.Response(jsonEncode(_parent()), 200);
      }
      // The review of one child: its own screen asks for it, and this test
      // is about which assignment is reviewed, not about the review itself.
      if (path.endsWith('/review')) {
        return http.Response('{"error":"nothing here"}', 404);
      }
      return http.Response('{"error":"not found"}', 404);
    });

Widget _wrap(Widget home) => ProviderScope(
      child: MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: home,
      ),
    );

Future<List<http.Request>> _open(WidgetTester tester, int sessionId) async {
  final seen = <http.Request>[];
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_wrap(HomeworkAssignmentScreen(
    session: _session(sessionId),
    assignmentId: 7,
    api: AssignmentApiService(authToken: 'tok', client: _client(seen)),
  )));
  await tester.pumpAndSettle();
  return seen;
}

void main() {
  setUpAll(loadRoboto);

  group('asking for one assignment has three answers', () {
    /// The status the server actually sends for a locked item
    /// (`routes/assignments.js`: `res.status(423)`).
    test('a 423 with a locked body is „locked", with the blocker', () async {
      final api = AssignmentApiService(
        authToken: 'tok',
        client: MockClient((_) async => http.Response(
              jsonEncode({
                'error': 'This item unlocks when the one before it is done.',
                'locked': true,
                'blockedBy': 502,
              }),
              423,
            )),
      );

      final result = await api.fetchDetail(503);
      expect(result.locked, isTrue);
      expect(result.lockedBy, 502);
      expect(result.detail, isNull);
    });

    test('a server that did not answer is not a closed gate', () async {
      final api = AssignmentApiService(
        authToken: 'tok',
        client: MockClient((_) async => http.Response('gateway away', 502)),
      );

      final result = await api.fetchDetail(503);
      expect(result.locked, isFalse,
          reason: '„the server did not answer" must not reach a student as '
              '„you are locked out"');
      expect(result.lockedBy, isNull);
      expect(result.detail, isNull);
    });

    test('and a homework comes back with its children', () async {
      final api = AssignmentApiService(
        authToken: 'tok',
        client: _client([]),
      );

      final result = await api.fetchDetail(7);
      expect(result.locked, isFalse);
      expect(result.detail, isNotNull);
      expect(result.detail!.children.map((c) => c.id), [501, 502, 503]);
    });
  });

  group('who unlocked it', () {
    testWidgets('the student is told their trainer did', (tester) async {
      await _open(tester, _studentId);

      expect(
        find.descendant(
          of: find.byKey(const Key('homework-child-503')),
          matching: find.text('Unlocked early by your trainer.'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the trainer is not told their trainer did', (tester) async {
      await _open(tester, _trainerId);

      expect(find.text('Unlocked early by your trainer.'), findsNothing,
          reason: 'the trainer reading their own screen has no trainer');
      expect(
        find.descendant(
          of: find.byKey(const Key('homework-child-503')),
          matching: find.text('You unlocked this early.'),
        ),
        findsOneWidget,
      );
    });
  });

  group("a child's review", () {
    testWidgets('is offered on an item that was worked on, and opens that item',
        (tester) async {
      await _open(tester, _studentId);

      expect(find.byKey(const Key('homework-child-review-502')), findsNothing,
          reason: 'nothing has been answered on that item yet');

      await tester.tap(find.byKey(const Key('homework-child-review-501')));
      await tester.pumpAndSettle();

      final review = tester
          .widget<AssignmentReviewScreen>(find.byType(AssignmentReviewScreen));
      expect(review.assignmentId, 501,
          reason: 'the child is reviewed, not its parent — a parent has no '
              'items and therefore no review');
      expect(review.title, 'My Tutorial');
    });
  });

  test('one wording for how far a homework has got', () {
    expect(Assignment.fromJson(_parent()).itemsSummary, '1 of 3 items');
    // Not the item counters, which are zero on every parent.
    expect(Assignment.fromJson(_parent()).totalItems, 0);
  });
}
