// Two rules the phase-3b gate and its companion do not reach, both found
// while grading that phase (`docs/PLAN-DOMACI-ZADATAK.md` §9):
//
//   1. **The switch decides who is on the move**, and the student is the one
//      on it. Written for §9 item 2, which answered the same question the
//      other way round: the trainer picked the student's colour *against* the
//      position's own turn, so „hold this draw, engine to move" could be set.
//      **Superseded on 18.9.2026** by the owner, in these words: „last action
//      always wins" — a pasted FEN sets the switch, and moving the switch
//      rewrites the FEN, so the two cannot disagree and the student always
//      opens.
//
//      What that costs is written down rather than lost: the runtime still
//      honours a task whose turn is not the student's side, so anything
//      already saved that way still plays. It is this dialog that can no
//      longer author one. The picker started
//      by reading it off the FEN's turn field, and both ends still judge the
//      other case (`ai_studio_screen.dart` asks the engine to move when
//      `turn != task.side`; `engineGameTask.js` counts the student's own
//      moves by whose turn it was).
//   2. **Deleting a homework template asks first.** It is one tap beside a
//      row and there is no undo.
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

import 'package:chess_app/features/homework/screens/homework_editor_screen.dart';
import 'package:chess_app/features/homework/screens/homework_list_screen.dart';
import 'package:chess_app/features/homework/services/homework_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';

import 'support/landscape.dart';

/// White to move, White up a rook — the ordinary „win it" shape.
const _whiteToMove = '4k3/8/8/8/8/8/8/4K2R w - - 0 1';

/// The same position with Black to move: the default side must follow this,
/// so a test that only ever used a white-to-move FEN could not tell a real
/// reading from a hardcoded `'w'`.
const _blackToMove = '4k3/8/8/8/8/8/8/4K2R b - - 0 1';

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

/// Opens the editor on a fresh homework and adds one „play it out" item with
/// [fen], tapping [sideLabel] first when one is given. Returns the recorder.
Future<_Recorder> _addPlayItOut(
  WidgetTester tester, {
  required String fen,
  String? sideLabel,
}) async {
  final recorder = _Recorder();
  final api = HomeworkApiService(authToken: 'tok', client: recorder.client());

  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester
      .pumpWidget(_app(HomeworkEditorScreen(homeworkId: null, api: api)));
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(const Key('homework-title')), 'Thursday');
  await tester.tap(find.byKey(const Key('homework-add')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Play it out'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('homework-engine-fen')), fen);
  await tester.pumpAndSettle();

  if (sideLabel != null) {
    await tester.tap(find.descendant(
      of: find.byKey(const Key('homework-engine-side')),
      matching: find.text(sideLabel),
    ));
    await tester.pumpAndSettle();
  }

  await tester.tap(find.byKey(const Key('homework-engine-submit')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('homework-save')));
  await tester.pumpAndSettle();

  expect(tester.takeException(), isNull);
  return recorder;
}

Map<String, dynamic> _taskSaved(_Recorder recorder) {
  final items = (recorder.body('POST')['items'] as List).cast<Map>();
  expect(items, hasLength(1), reason: 'one item was added');
  return Map<String, dynamic>.from(items.single['task'] as Map);
}

void main() {
  setUpAll(loadRoboto);

  group('the side the student plays', () {
    testWidgets('is the switch, and the position follows it', (tester) async {
      final recorder = await _addPlayItOut(
        tester,
        fen: _whiteToMove,
        sideLabel: 'Black',
      );

      final task = _taskSaved(recorder);
      expect(task['fen'], _blackToMove,
          reason: 'the switch was the last thing touched, so the position was '
              'rewritten to hand Black the move');
      expect(task['side'], 'b');
      expect(task['goal'], 'win');
    });

    testWidgets('follows the position until the trainer picks', (tester) async {
      final recorder = await _addPlayItOut(tester, fen: _blackToMove);

      // Black to move, nothing chosen: the student is Black. A default of
      // „White" would pass on the other FEN and fail here.
      expect(_taskSaved(recorder)['side'], 'b');
    });

    testWidgets('and what is shown says who opens', (tester) async {
      final recorder = _Recorder();
      final api =
          HomeworkApiService(authToken: 'tok', client: recorder.client());

      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester
          .pumpWidget(_app(HomeworkEditorScreen(homeworkId: null, api: api)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('homework-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Play it out'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('homework-engine-fen')), _whiteToMove);
      await tester.pumpAndSettle();

      expect(
        find.text('The student moves first; the engine takes the other side.'),
        findsOneWidget,
      );

      await tester.tap(find.descendant(
        of: find.byKey(const Key('homework-engine-side')),
        matching: find.text('Black'),
      ));
      await tester.pumpAndSettle();

      // The same sentence after the tap: it is true of every task this dialog
      // can now make, which is what replaced the old pair.
      expect(
        find.text('The student moves first; the engine takes the other side.'),
        findsOneWidget,
        reason: 'the trainer is told what the switch does to the position',
      );
    });
  });

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
