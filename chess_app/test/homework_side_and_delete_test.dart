// One rule the phase-3b gate and its companion do not reach, found while
// grading that phase (`docs/PLAN-DOMACI-ZADATAK.md` §9):
//
//   **Deleting a homework template asks first.** It is one tap beside a
//   row and there is no undo.
//
// A second rule used to live here — **the position says who is on the move,
// or the trainer is asked** — guarded through the editor's old „Play it out"
// door (`pickEngineGameTask`). **Superseded 18.9.2026**
// (`docs/PLAN-EXERCISE.md` phase 4): that door is gone, a game exercise is
// now made in Preparation, and it is `MakeExerciseSheet` — phase 3b's file,
// not this worker's — that owns the question now. The rule itself is not
// lost: the runtime still honours a task whose turn is not the student's
// side (`ai_studio_screen.dart` asks the engine to move when
// `turn != task.side`; `engineGameTask.js` counts the student's own moves by
// whose turn it was), only the dialog that authored one by hand is gone.
//
// Every assertion reads the recorded request rather than what the fake
// answered: a `MockClient` answers whatever it is asked, so a wrong address
// or a missing field is invisible unless the request itself is read
// (CLAUDE.md rule 7).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/homework/screens/homework_list_screen.dart';
import 'package:chess_app/features/homework/services/homework_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';

class _Recorder {
  _Recorder({this.homeworks = const []});

  final List<Map<String, dynamic>> homeworks;
  final List<http.Request> requests = [];

  http.Client client() => MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path == '/homeworks' && request.method == 'GET') {
          return http.Response(jsonEncode({'homeworks': homeworks}), 200);
        }
        if (path == '/homeworks' && request.method == 'POST') {
          return http.Response(
              jsonEncode({
                'id': 1,
                'title': (jsonDecode(request.body) as Map)['title'],
                'items': <dynamic>[],
              }),
              201);
        }
        if (request.method == 'DELETE') {
          return http.Response(jsonEncode({'success': true}), 200);
        }
        return http.Response('{"error":"not found"}', 404);
      });

  List<http.Request> of(String method) =>
      requests.where((r) => r.method == method).toList();

  /// The last body sent with [method], as the server would read it.
  Map<String, dynamic> body(String method) =>
      jsonDecode(of(method).last.body) as Map<String, dynamic>;
}

Widget _app(Widget home) => MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: home,
    );

void main() {
  group('deleting a template', () {
    /// One saved homework, already sent twice — the row the taps below act on.
    _Recorder listRecorder() => _Recorder(homeworks: [
          {
            'id': 4,
            'title': 'Thursday',
            'item_count': 3,
            'sent_count': 2,
          },
        ]);

    testWidgets('asks first, and a cancelled ask deletes nothing',
        (tester) async {
      final recorder = listRecorder();
      final api =
          HomeworkApiService(authToken: 'tok', client: recorder.client());

      await tester.pumpWidget(_app(HomeworkListScreen(api: api)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('homework-list-delete-4')));
      await tester.pumpAndSettle();

      expect(find.text('Delete "Thursday"?'), findsOneWidget);
      expect(
        find.textContaining('already sent stay with the students'),
        findsOneWidget,
        reason: 'what a delete does not do is the part worth saying',
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(recorder.of('DELETE'), isEmpty);
      expect(find.byKey(const Key('homework-list-row-4')), findsOneWidget);
    });

    testWidgets('goes through once confirmed, to that homework',
        (tester) async {
      final recorder = listRecorder();
      final api =
          HomeworkApiService(authToken: 'tok', client: recorder.client());

      await tester.pumpWidget(_app(HomeworkListScreen(api: api)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('homework-list-delete-4')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('homework-delete-confirm')));
      await tester.pumpAndSettle();

      final sent = recorder.of('DELETE');
      expect(sent, hasLength(1));
      expect(sent.single.url.path, '/homeworks/4',
          reason: 'the address is the identity — a MockClient answers any URL');
    });
  });
}
