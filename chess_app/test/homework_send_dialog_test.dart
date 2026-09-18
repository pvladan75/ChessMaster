// Phase 4's app half — `docs/PLAN-DOMACI-ZADATAK.md` §5: giving a written
// homework to students.
//
// The rules under test, all of which the server already keeps its half of:
//
//   * **One request per student.** That is what makes the quota rule true —
//     the server charges one unit per request, so three students cost three
//     units and a five-item homework still costs one each. A batched call
//     would have to answer „two of your three" with a single status code.
//   * **A refusal names the student**, and the students who did get it are
//     still reported as sent. Half a send is a fact, not an error to swallow.
//   * **Only students who have accepted** are offered: an unanswered
//     invitation grants nothing and the server refuses it.
//   * **The second save of a new homework is an edit, not a second
//     homework** — found while wiring this phase, see the group at the end.
//
// Every assertion reads the recorded request, never what the fake answered: a
// `MockClient` answers whatever it is handed, so a wrong address or a missing
// field is invisible unless the request itself is read (CLAUDE.md rule 7).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/features/homework/models/homework.dart';
import 'package:chess_app/features/homework/screens/homework_editor_screen.dart';
import 'package:chess_app/features/homework/screens/homework_list_screen.dart';
import 'package:chess_app/features/homework/services/homework_api_service.dart';
import 'package:chess_app/features/homework/widgets/homework_send_dialog.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/theme/app_colors.dart';

import 'support/landscape.dart';

/// Two accepted students and one whose invitation nobody has answered.
const _students = [
  {'id': 11, 'name': 'Ana', 'status': 'accepted'},
  {'id': 13, 'name': 'Marko', 'status': 'accepted'},
  {'id': 17, 'name': 'Nenad', 'status': 'pending'},
];

/// Records every request and answers the three addresses this flow uses.
/// [refuseFor] is the student the server turns away, with its own sentence.
class _Recorder {
  _Recorder({this.refuseFor, this.sent = const []});

  final int? refuseFor;
  final List<Map<String, dynamic>> sent;
  final List<http.Request> requests = [];

  http.Client client() => MockClient((request) async {
        requests.add(request);
        final path = request.url.path;

        if (path == '/trainer/students' && request.method == 'GET') {
          return http.Response(jsonEncode({'students': _students}), 200);
        }
        if (path == '/homeworks' && request.method == 'GET') {
          return http.Response(
              jsonEncode({
                'homeworks': [
                  {
                    'id': 4,
                    'title': 'Thursday',
                    'item_count': 3,
                    'sent_count': 1
                  },
                ],
              }),
              200);
        }
        if (path == '/homeworks/4' && request.method == 'GET') {
          return http.Response(jsonEncode(_homeworkBody()), 200);
        }
        if (path.endsWith('/send') && request.method == 'POST') {
          final studentId =
              (jsonDecode(request.body) as Map)['studentId'] as int?;
          if (refuseFor != null && studentId == refuseFor) {
            return http.Response(
                jsonEncode({
                  'error': 'A position in this homework needs review.',
                }),
                422);
          }
          return http.Response(
              jsonEncode({'id': 90, 'title': 'Thursday'}), 201);
        }
        // A new homework saved for the first time, then edited.
        if (path == '/homeworks' && request.method == 'POST') {
          return http.Response(jsonEncode(_savedBody()), 201);
        }
        if (path == '/homeworks/1' && request.method == 'PUT') {
          return http.Response(jsonEncode(_savedBody()), 200);
        }
        return http.Response('{"error":"not found"}', 404);
      });

  Map<String, dynamic> _homeworkBody() => {
        'id': 4,
        'title': 'Thursday',
        'instructions': 'Read first.',
        'items': [
          {
            'item_key': 'ia1b2c3d4',
            'position': 0,
            'kind': 'lesson',
            'task': {'lessonId': 31},
            'gate': false,
            'require_solved': false,
          },
        ],
        'sent': sent,
      };

  /// What the server answers a save with: the homework as it now stands,
  /// every item carrying the key the server minted for it.
  Map<String, dynamic> _savedBody() => {
        'id': 1,
        'title': 'Friday',
        'instructions': null,
        'items': [
          {
            'item_key': 'iminted01',
            'position': 0,
            'kind': 'puzzles',
            'task': {
              'count': 6,
              'themes': ['pin'],
              'minRating': null,
              'maxRating': null
            },
            'gate': false,
            'require_solved': false,
          },
        ],
        'sent': <dynamic>[],
      };

  List<http.Request> to(String path, {String? method}) => requests
      .where(
          (r) => r.url.path == path && (method == null || r.method == method))
      .toList();

  Map<String, dynamic> bodyOf(http.Request request) =>
      jsonDecode(request.body) as Map<String, dynamic>;
}

Widget _wrap(Widget home) => MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: home,
    );

/// A screen whose one button opens the send dialog, so the message the
/// trainer actually reads is shown on a context that still exists.
class _Host extends StatelessWidget {
  const _Host({required this.api, required this.groupApi});

  final HomeworkApiService api;
  final GroupApiService groupApi;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Builder(
            builder: (inner) => FilledButton(
              key: const Key('open-send'),
              onPressed: () => showHomeworkSendDialog(
                inner,
                api: api,
                homeworkId: 4,
                title: 'Thursday',
                groupApi: groupApi,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
}

/// Opens the dialog and ticks [names]. Returns the recorder.
Future<_Recorder> _openAndPick(
  WidgetTester tester,
  List<String> names, {
  int? refuseFor,
}) async {
  final recorder = _Recorder(refuseFor: refuseFor);
  final client = recorder.client();

  tester.view.physicalSize = const Size(500, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_wrap(_Host(
    api: HomeworkApiService(authToken: 'tok', client: client),
    groupApi: GroupApiService(client: client),
  )));
  await tester.tap(find.byKey(const Key('open-send')));
  await tester.pumpAndSettle();

  for (final name in names) {
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }
  return recorder;
}

void main() {
  setUpAll(loadRoboto);

  setUp(() async {
    // GroupApiService reads the token from the session rather than taking it,
    // so a test that uses it has to have one.
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

  group('sending a homework', () {
    testWidgets('is one request per student, each carrying that student',
        (tester) async {
      final recorder = await _openAndPick(tester, ['Ana', 'Marko']);

      await tester.tap(find.byKey(const Key('homework-send-confirm')));
      await tester.pumpAndSettle();

      final sends = recorder.to('/homeworks/4/send', method: 'POST');
      expect(sends, hasLength(2),
          reason: 'one unit of quota per student is one request per student');
      expect(sends.map((r) => recorder.bodyOf(r)['studentId']), [11, 13]);
    });

    testWidgets('sends nothing for a student nobody ticked', (tester) async {
      final recorder = await _openAndPick(tester, ['Marko']);

      await tester.tap(find.byKey(const Key('homework-send-confirm')));
      await tester.pumpAndSettle();

      final sends = recorder.to('/homeworks/4/send', method: 'POST');
      expect(sends, hasLength(1));
      expect(recorder.bodyOf(sends.single)['studentId'], 13);
    });

    testWidgets('offers only the students who accepted', (tester) async {
      await _openAndPick(tester, const []);

      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Marko'), findsOneWidget);
      expect(find.text('Nenad'), findsNothing,
          reason: 'an invitation nobody has answered grants nothing, and the '
              'server would refuse it');
    });

    testWidgets('cannot be sent to nobody', (tester) async {
      await _openAndPick(tester, const []);

      final button = tester
          .widget<FilledButton>(find.byKey(const Key('homework-send-confirm')));
      expect(button.onPressed, isNull);
    });

    testWidgets(
        'names the student the server refused, and still reports the '
        'one it did not', (tester) async {
      final recorder =
          await _openAndPick(tester, ['Ana', 'Marko'], refuseFor: 13);

      await tester.tap(find.byKey(const Key('homework-send-confirm')));
      await tester.pumpAndSettle();

      expect(recorder.to('/homeworks/4/send', method: 'POST'), hasLength(2),
          reason: 'a refusal for one student does not stop the next');
      expect(
        find.textContaining('Sent to Ana.'),
        findsOneWidget,
        reason: 'the student who got it is told about, not swallowed by the '
            'other one failing',
      );
      expect(
          find.textContaining('Marko: A position in this homework needs '
              'review.'),
          findsOneWidget);
    });
  });

  group('what travels with a sending', () {
    test('a note is trimmed, and an empty one is not sent at all', () async {
      final recorder = _Recorder();
      final api =
          HomeworkApiService(authToken: 'tok', client: recorder.client());

      await api.send(homeworkId: 4, studentId: 11, note: '  Do it by Friday ');
      await api.send(homeworkId: 4, studentId: 11, note: '   ');

      final sends = recorder.to('/homeworks/4/send', method: 'POST');
      expect(recorder.bodyOf(sends[0])['note'], 'Do it by Friday');
      expect(recorder.bodyOf(sends[1]).containsKey('note'), isFalse,
          reason: 'saying nothing is not the same as sending an empty note; '
              'the server keeps the homework\'s own instructions then');
      expect(recorder.bodyOf(sends[0]).containsKey('dueAt'), isFalse);
    });

    test('a due date travels as a date the server can read', () async {
      final recorder = _Recorder();
      final api =
          HomeworkApiService(authToken: 'tok', client: recorder.client());

      await api.send(
        homeworkId: 4,
        studentId: 11,
        dueAt: DateTime(2026, 9, 25, 18, 30),
      );

      final body = recorder
          .bodyOf(recorder.to('/homeworks/4/send', method: 'POST').single);
      expect(DateTime.parse(body['dueAt'] as String),
          DateTime(2026, 9, 25, 18, 30));
    });

    test('a refusal comes back as the server\'s own sentence', () async {
      final api = HomeworkApiService(
        authToken: 'tok',
        client: MockClient((_) async => http.Response(
            jsonEncode({'error': 'Your plan is spent for this month.'}), 402)),
      );

      expect(await api.send(homeworkId: 4, studentId: 11),
          'Your plan is spent for this month.');
    });
  });

  group('the doors to sending', () {
    testWidgets('the list row opens it for that homework', (tester) async {
      final recorder = _Recorder();
      final client = recorder.client();

      await tester.pumpWidget(_wrap(HomeworkListScreen(
        api: HomeworkApiService(authToken: 'tok', client: client),
        groupApi: GroupApiService(client: client),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('homework-list-send-4')));
      await tester.pumpAndSettle();

      expect(find.text('Send "Thursday"'), findsOneWidget);
    });

    testWidgets('the editor will not send a homework that was never saved',
        (tester) async {
      await tester.pumpWidget(_wrap(HomeworkEditorScreen(
        homeworkId: null,
        api: HomeworkApiService(authToken: 'tok', client: _Recorder().client()),
      )));
      await tester.pumpAndSettle();

      final button =
          tester.widget<IconButton>(find.byKey(const Key('homework-send')));
      expect(button.onPressed, isNull,
          reason: 'there is nothing on the server to copy from yet');
    });
  });

  group('the copies already sent', () {
    testWidgets('are listed under the homework being edited', (tester) async {
      final recorder = _Recorder(sent: [
        {
          'id': 90,
          'student_id': 11,
          'student_name': 'Ana',
          'created_at': '2026-09-17T09:00:00.000Z',
          'completed_at': null,
          'child_total': 4,
          'child_completed': 1,
        },
      ]);

      tester.view.physicalSize = const Size(500, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(HomeworkEditorScreen(
        homeworkId: 4,
        api: HomeworkApiService(authToken: 'tok', client: recorder.client()),
      )));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('homework-sent-90')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('homework-sent-90')),
          matching: find.textContaining('Ana'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('homework-sent-90')),
          matching: find.textContaining('1 of 4 items'),
        ),
        findsOneWidget,
        reason: 'that copy\'s own progress, not the template\'s item count',
      );
    });

    test('a copy the app cannot read is dropped, the homework still opens', () {
      final homework = Homework.fromJson({
        'id': 4,
        'title': 'Thursday',
        'items': <dynamic>[],
        'sent': [
          {'student_name': 'No id here'},
          {'id': 91, 'student_name': 'Ana', 'child_total': 2},
        ],
      });

      expect(homework, isNotNull);
      expect(homework!.sent.map((c) => c.assignmentId), [91]);
    });
  });

  group('saving twice in one sitting', () {
    testWidgets('edits the homework instead of making a second one',
        (tester) async {
      final recorder = _Recorder();

      tester.view.physicalSize = const Size(500, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(HomeworkEditorScreen(
        homeworkId: null,
        api: HomeworkApiService(authToken: 'tok', client: recorder.client()),
      )));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('homework-title')), 'Friday');
      await tester.tap(find.byKey(const Key('homework-save')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('homework-save')));
      await tester.pumpAndSettle();

      expect(recorder.to('/homeworks', method: 'POST'), hasLength(1),
          reason: 'the second save is an edit of the homework the first one '
              'made, not another homework');
      final put = recorder.to('/homeworks/1', method: 'PUT');
      expect(put, hasLength(1));
      expect(
        (recorder.bodyOf(put.single)['items'] as List)
            .map((i) => (i as Map)['itemKey']),
        ['iminted01'],
        reason: 'the rows adopted the key the server minted, so the item is '
            'edited rather than deleted and minted again',
      );
    });

    testWidgets('and can be sent once it has been saved', (tester) async {
      final recorder = _Recorder();

      tester.view.physicalSize = const Size(500, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_wrap(HomeworkEditorScreen(
        homeworkId: null,
        api: HomeworkApiService(authToken: 'tok', client: recorder.client()),
        groupApi: GroupApiService(client: recorder.client()),
      )));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('homework-send')))
            .onPressed,
        isNull,
      );

      await tester.enterText(find.byKey(const Key('homework-title')), 'Friday');
      await tester.tap(find.byKey(const Key('homework-save')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('homework-send')))
            .onPressed,
        isNotNull,
        reason: 'the save minted an id, and that is all sending needed',
      );
    });
  });
}
