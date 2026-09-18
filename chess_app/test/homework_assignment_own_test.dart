// Phase 5 of docs/PLAN-DOMACI-ZADATAK.md: what the copied gate
// (test/homework_student_test.dart) cannot reach — a finished homework, both
// shapes of phone, a stale
// screen answered with a lock instead of an empty assignment, and that coming
// back re-reads the homework rather than trusting what the screen already
// has.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/features/assignments/widgets/assignment_detail_gate.dart';
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

Map<String, dynamic> _child({
  required int id,
  required String title,
  required String kind,
  required int position,
  String? completedAt,
  bool locked = false,
  int? blockedBy,
}) =>
    {
      'id': id,
      'title': title,
      'kind': kind,
      'position': position,
      'item_key': 'i$id',
      'lesson_id': null,
      'gate': true,
      'gate_opened_at': null,
      'completed_at': completedAt,
      'task': null,
      'total_items': 1,
      'attempted_items': completedAt == null ? 0 : 1,
      'solved_items': completedAt == null ? 0 : 1,
      'passed': completedAt != null,
      'locked': locked,
      'blocked_by': blockedBy,
    };

/// Every child finished — the shape a finished homework has, so "0 of 0" (an
/// item-based reading, which a parent's own `total_items` would give) does
/// not read as complete when it is.
Map<String, dynamic> _finishedParent() => {
      'id': 7,
      'title': 'Thursday',
      'instructions': 'Read first, then solve.',
      'kind': 'homework',
      'trainer_id': _trainerId,
      'student_id': _studentId,
      'trainer_name': 'Trainer',
      'due_at': null,
      'completed_at': '2026-09-17T12:00:00.000Z',
      'total_items': 0,
      'attempted_items': 0,
      'solved_items': 0,
      'child_total': 3,
      'child_completed': 3,
      'children': [
        _child(
            id: 601,
            title: 'Read it',
            kind: 'lesson',
            position: 0,
            completedAt: '2026-09-17T10:00:00.000Z'),
        _child(
            id: 602,
            title: 'Solve two',
            kind: 'puzzles',
            position: 1,
            completedAt: '2026-09-17T10:30:00.000Z'),
        _child(
            id: 603,
            title: 'Play it out',
            kind: 'engine_game',
            position: 2,
            completedAt: '2026-09-17T11:00:00.000Z'),
      ],
    };

/// Two open items, neither done — a homework in the middle of being worked.
Map<String, dynamic> _openParent() => {
      'id': 7,
      'title': 'Thursday',
      'instructions': 'Read first, then solve.',
      'kind': 'homework',
      'trainer_id': _trainerId,
      'student_id': _studentId,
      'trainer_name': 'Trainer',
      'due_at': null,
      'completed_at': null,
      'total_items': 0,
      'attempted_items': 0,
      'solved_items': 0,
      'child_total': 2,
      'child_completed': 0,
      'children': [
        _child(id: 701, title: 'First set', kind: 'puzzles', position: 0),
        _child(id: 702, title: 'Second set', kind: 'puzzles', position: 1),
      ],
    };

http.Client _clientAnswering(Map<String, dynamic> parentJson,
    {int parentId = 7, void Function(http.Request)? onRequest}) {
  return MockClient((request) async {
    onRequest?.call(request);
    if (request.url.path == '/assignments/$parentId' &&
        request.method == 'GET') {
      return http.Response(jsonEncode(parentJson), 200);
    }
    // Any child opened from this screen: answer with a minimal detail so a
    // push does not hang on "could not load".
    if (RegExp(r'^/assignments/\d+$').hasMatch(request.url.path) &&
        request.method == 'GET') {
      final id = int.parse(request.url.path.substring('/assignments/'.length));
      return http.Response(
          jsonEncode({
            'id': id,
            'title': 'Item $id',
            'kind': 'puzzles',
            'total_items': 1,
            'attempted_items': 0,
            'solved_items': 0,
            'items': [
              {'puzzle_id': 'p1', 'position': 0}
            ],
          }),
          200);
    }
    return http.Response('{"error":"not found"}', 404);
  });
}

Widget _wrap(Widget home) => ProviderScope(
      child: MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: home,
      ),
    );

String _stateOf(WidgetTester tester, int id) {
  final row = find.byKey(Key('homework-child-state-$id'));
  final widget = tester.widget(row);
  if (widget is Text) return widget.data!;
  return tester
      .widget<Text>(find.descendant(of: row, matching: find.byType(Text)))
      .data!;
}

void main() {
  setUpAll(loadRoboto);

  group('a finished homework', () {
    testWidgets('every row reads Done, and the progress is 3 of 3',
        (tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final client = _clientAnswering(_finishedParent());
      await tester.pumpWidget(_wrap(HomeworkAssignmentScreen(
        session: _session(_studentId),
        assignmentId: 7,
        api: AssignmentApiService(authToken: 'tok', client: client),
      )));
      await tester.pumpAndSettle();

      expect(find.text('3 of 3 items'), findsOneWidget);
      expect(_stateOf(tester, 601), 'Done');
      expect(_stateOf(tester, 602), 'Done');
      expect(_stateOf(tester, 603), 'Done');
    });
  });

  group('both shapes of phone', () {
    for (final size in [const Size(360, 800), const Size(800, 360)]) {
      testWidgets(
          '${size.width.toInt()}x${size.height.toInt()}: nothing '
          'overflows', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final client = _clientAnswering(_finishedParent());
        await tester.pumpWidget(_wrap(HomeworkAssignmentScreen(
          session: _session(_trainerId),
          assignmentId: 7,
          api: AssignmentApiService(authToken: 'tok', client: client),
        )));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('homework-progress')), findsOneWidget);
        expect(find.byKey(const Key('homework-child-601')), findsOneWidget);
      });
    }
  });

  group('a stale screen', () {
    testWidgets(
        'a locked answer says which item is in the way, not an empty '
        'assignment', (tester) async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': 'This item unlocks when the one before it is done.',
            'locked': true,
            'blockedBy': 502,
          }),
          200,
        );
      });

      await tester.pumpWidget(_wrap(AssignmentDetailGate(
        session: _session(_studentId),
        assignmentId: 503,
        api: AssignmentApiService(authToken: 'tok', client: client),
        builder: (detail) => Scaffold(
          body: Text('opened as: "${detail.assignment.title}"'),
        ),
      )));
      await tester.pumpAndSettle();

      // The builder must never run on a locked answer: that would be the
      // empty assignment (no title, no items) the brief warns against.
      expect(find.textContaining('opened as:'), findsNothing);
      expect(find.textContaining('502'), findsOneWidget,
          reason: 'the student is told which item is in the way');
    });
  });

  group('coming back re-reads', () {
    testWidgets(
        'returning from an item asks the server for the homework '
        'again', (tester) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final requests = <http.Request>[];
      final client = _clientAnswering(_openParent(), onRequest: (r) {
        requests.add(r);
      });

      await tester.pumpWidget(_wrap(HomeworkAssignmentScreen(
        session: _session(_studentId),
        assignmentId: 7,
        api: AssignmentApiService(authToken: 'tok', client: client),
      )));
      await tester.pumpAndSettle();

      final before =
          requests.where((r) => r.url.path == '/assignments/7').length;
      expect(before, 1);

      await tester.tap(find.byKey(const Key('homework-child-702')));
      await tester.pumpAndSettle();

      // Back out of whatever the item opened on.
      await tester.pageBack();
      await tester.pumpAndSettle();

      final after =
          requests.where((r) => r.url.path == '/assignments/7').length;
      expect(after, 2,
          reason: 'the screen reads the homework again rather than trusting '
              'what it already had');
    });
  });
}
