// Sending a homework to a group — item 9 of the owner's review of 21.9.2026,
// from his report of 20.9.2026: „Omogućiti treneru da šalje celoj grupi, ne
// samo pojedinim učenicima."
//
// Decided with the owner the same day:
//
//   * **A group chip ticks the group's members as they are now.** A student
//     who joins later does not get the homework on their own: every copy is a
//     unit of quota, the due date and the note belong to one sending, and a
//     rule that fires later by itself is the shape this codebase keeps paying
//     for. The server is not touched — the dialog already sends one request
//     per student.
//   * **A student who already has this homework is not ticked by the chip.**
//     The server does not refuse a second copy (there is no unique key on
//     homework and student), so without this, sending to a group again after
//     somebody joined would give everyone else a second copy and a second
//     unit. They are marked „already has it", and can still be ticked by hand.
//   * **Only accepted students**, as before; a member whose invitation is not
//     answered is not ticked, and the dialog says so — a chip that silently
//     does less than it says is a door that lies.
//
// Every assertion that matters reads the recorded requests (rule 7).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/features/homework/services/homework_api_service.dart';
import 'package:chess_app/features/homework/widgets/homework_send_dialog.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/theme/app_colors.dart';

/// Three accepted students and one whose invitation nobody has answered.
const _students = [
  {'id': 11, 'name': 'Ana', 'status': 'accepted'},
  {'id': 13, 'name': 'Marko', 'status': 'accepted'},
  {'id': 15, 'name': 'Jovana', 'status': 'accepted'},
  {'id': 17, 'name': 'Nenad', 'status': 'pending'},
];

/// „Thursday group" holds Ana, Marko and Nenad — Jovana is outside it, so a
/// chip that ticked everybody would be seen. „Advanced" holds Jovana alone.
const _members = {
  5: [
    {'id': 11, 'name': 'Ana'},
    {'id': 13, 'name': 'Marko'},
    {'id': 17, 'name': 'Nenad'},
  ],
  6: [
    {'id': 15, 'name': 'Jovana'},
  ],
};

class _Server {
  _Server({this.alreadySentTo = const [], this.groupsReachable = true});

  /// Students this homework was sent to before the dialog opened.
  final List<int> alreadySentTo;
  final bool groupsReachable;
  final List<http.Request> requests = [];

  http.Client client() => MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path == '/trainer/students') {
          return http.Response(jsonEncode({'students': _students}), 200);
        }
        if (path == '/groups') {
          if (!groupsReachable) return http.Response('{}', 503);
          return http.Response(
              jsonEncode({
                'groups': [
                  {'id': 5, 'name': 'Thursday group', 'members': 3},
                  {'id': 6, 'name': 'Advanced', 'members': 1},
                ],
              }),
              200);
        }
        final members = RegExp(r'^/groups/(\d+)/members$').firstMatch(path);
        if (members != null) {
          final id = int.parse(members.group(1)!);
          return http.Response(
              jsonEncode({'members': _members[id] ?? const []}), 200);
        }
        if (path == '/homeworks/4' && request.method == 'GET') {
          return http.Response(
              jsonEncode({
                'id': 4,
                'title': 'Thursday',
                'instructions': null,
                'items': [
                  {
                    'item_key': 'ia1b2c3d4',
                    'position': 0,
                    'kind': 'lesson',
                    'task': {'lessonId': 31},
                    'gate': false,
                  },
                ],
                'sent': [
                  for (final id in alreadySentTo)
                    {
                      'id': 900 + id,
                      'student_id': id,
                      'student_name': 'x',
                      'created_at': '2026-09-20T10:00:00Z',
                      'completed_at': null,
                      'child_total': 1,
                      'child_completed': 0,
                    }
                ],
              }),
              200);
        }
        if (path == '/homeworks/4/send' && request.method == 'POST') {
          return http.Response(
              jsonEncode({'id': 90, 'title': 'Thursday'}), 201);
        }
        return http.Response('{"error":"not found"}', 404);
      });

  List<int> sentTo() => [
        for (final r in requests)
          if (r.url.path == '/homeworks/4/send' && r.method == 'POST')
            (jsonDecode(r.body) as Map)['studentId'] as int
      ];
}

Future<_Server> _open(WidgetTester tester, _Server server) async {
  tester.view.physicalSize = const Size(500, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final client = server.client();
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: Scaffold(
      body: Builder(
        builder: (context) => FilledButton(
          key: const Key('open-send'),
          onPressed: () => showHomeworkSendDialog(
            context,
            api: HomeworkApiService(authToken: 'tok', client: client),
            homeworkId: 4,
            title: 'Thursday',
            groupApi: GroupApiService(client: client),
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.byKey(const Key('open-send')));
  await tester.pumpAndSettle();
  return server;
}

final _thursday = find.byKey(const Key('homework-send-group-5'));
final _confirm = find.byKey(const Key('homework-send-confirm'));

bool _ticked(WidgetTester tester, int studentId) => tester
    .widget<CheckboxListTile>(
        find.byKey(Key('homework-send-student-$studentId')))
    .value!;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'remember_me': true,
      'user_token': 'test-token',
      'user_id': 9,
      'user_email': 't@example.com',
      'user_name': 'Trainer',
      'user_role': 'trener',
    });
    await SessionService.instance.init();
  });

  testWidgets('a group chip ticks its accepted members, and only them',
      (tester) async {
    final server = await _open(tester, _Server());
    expect(_thursday, findsOneWidget, reason: 'no chip for the group');

    await tester.tap(_thursday);
    await tester.pumpAndSettle();
    expect(_ticked(tester, 11), isTrue);
    expect(_ticked(tester, 13), isTrue);
    expect(_ticked(tester, 15), isFalse,
        reason: 'a student outside the group was ticked');
    expect(find.textContaining('Nenad has not accepted'), findsOneWidget,
        reason: 'a member was left out without a word');

    await tester.tap(_confirm);
    await tester.pumpAndSettle();
    expect(server.sentTo(), [11, 13]);
  });

  testWidgets('a student who already has it is not ticked by the chip',
      (tester) async {
    // The case the owner's „no" rests on: Marko joined after the first
    // sending, and the group is sent to again.
    final server = await _open(tester, _Server(alreadySentTo: const [11]));

    expect(
        find.descendant(
            of: find.byKey(const Key('homework-send-student-11')),
            matching: find.text('already has it')),
        findsOneWidget);

    await tester.tap(_thursday);
    await tester.pumpAndSettle();
    expect(_ticked(tester, 11), isFalse,
        reason: 'Ana would get a second copy and cost a second unit');
    expect(_ticked(tester, 13), isTrue);
    expect(find.textContaining('Ana already has'), findsOneWidget);

    await tester.tap(_confirm);
    await tester.pumpAndSettle();
    expect(server.sentTo(), [13]);
  });

  testWidgets('one who already has it can still be ticked by hand',
      (tester) async {
    final server = await _open(tester, _Server(alreadySentTo: const [11]));
    await tester.tap(find.byKey(const Key('homework-send-student-11')));
    await tester.pumpAndSettle();
    await tester.tap(_confirm);
    await tester.pumpAndSettle();
    expect(server.sentTo(), [11],
        reason: 'a deliberate second copy is the trainer\'s to decide');
  });

  testWidgets('tapping the chip again unticks the group', (tester) async {
    await _open(tester, _Server());
    await tester.tap(_thursday);
    await tester.pumpAndSettle();
    await tester.tap(_thursday);
    await tester.pumpAndSettle();
    expect(_ticked(tester, 11), isFalse);
    expect(_ticked(tester, 13), isFalse);
    expect(tester.widget<FilledButton>(_confirm).onPressed, isNull);
  });

  testWidgets('a group whose members all have it says so, and ticks nobody',
      (tester) async {
    final server = await _open(tester, _Server(alreadySentTo: const [11, 13]));
    await tester.tap(_thursday);
    await tester.pumpAndSettle();
    expect(_ticked(tester, 11), isFalse);
    expect(_ticked(tester, 13), isFalse);
    expect(find.textContaining('Nobody in „Thursday group" is left to send to'),
        findsOneWidget);
    expect(server.sentTo(), isEmpty);
  });

  testWidgets('with no groups to be had, the students are still there',
      (tester) async {
    await _open(tester, _Server(groupsReachable: false));
    expect(_thursday, findsNothing);
    expect(find.byKey(const Key('homework-send-student-11')), findsOneWidget);
  });
}
