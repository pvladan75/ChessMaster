// tutorial_video_export_test.dart
// Tests for tutorial video export door on saved-tutorial rows:
//
// 7. the icon is on the row and disabled while it is busy;
// 8. an empty tutorial is refused with no request sent — assert on the fake API;
// 9. a normal tutorial sends the events and seconds tutorialVideoOf produces
//    for that draft. Assert on the request.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_video.dart';
import 'package:chess_app/features/tutorial_studio/tutorial_studio_availability.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_library_card.dart';
import 'package:chess_app/models/user_session.dart';

const String _fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

final Map<String, dynamic> _normalTutorialRow = {
  'id': 12,
  'title': 'Opozicija',
  'position_list': [
    {'id': 's1', 'fen': _fen, 'title': 'Uvod', 'kind': 'show'},
  ],
};

final Map<String, dynamic> _emptyTutorialRow = {
  'id': 14,
  'title': 'Prazan tutorijal',
  'position_list': <Map<String, dynamic>>[],
};

class _TestLessonApi extends LessonApiService {
  _TestLessonApi._(
    this.requests,
    http.Client client,
  ) : super(authToken: 'tok', client: client);

  final List<http.Request> requests;

  factory _TestLessonApi({
    required List<http.Request> requests,
    int status = 200,
    String responseBody =
        '{"message":"Video rendered successfully, saved, and ready for download!","jobId":"job_12_1","status":"completed","downloadUrl":"/recordings/export-download/tutorial_12.mp4?token=tok","filename":"tutorial_12.mp4"}',
    List<Map<String, dynamic>>? rows,
    Future<void> Function()? onExportVideo,
    bool ttsAvailable = false,
    List<Map<String, dynamic>>? ttsVoices,
  }) {
    final effectiveRows = rows ?? [_normalTutorialRow, _emptyTutorialRow];
    final client = MockClient((req) async {
      requests.add(req);
      if (req.method == 'GET' && req.url.path == '/lessons') {
        return http.Response(
          jsonEncode(effectiveRows),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (req.method == 'GET' && req.url.path == '/lessons/tts/voices') {
        return http.Response(
          jsonEncode({
            'available': ttsAvailable,
            'voices': ttsVoices ?? <Map<String, dynamic>>[],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (req.method == 'POST' && req.url.path.contains('/export-video')) {
        if (onExportVideo != null) {
          await onExportVideo();
        }
        return http.Response(
          responseBody,
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('{"error":"Not found"}', 404);
    });
    return _TestLessonApi._(requests, client);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final session = UserSession(
    token: 'tok',
    id: 7,
    email: 'a@b.c',
    name: 'Trener',
    role: 'trener',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
    debugTutorialStudioAvailable = true;
  });

  tearDown(() => debugTutorialStudioAvailable = null);

  Future<void> openList(
    WidgetTester tester, {
    required LessonApiService api,
  }) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TutorialLibraryCard(
            session: session,
            api: api,
            assignmentApi: AssignmentApiService(authToken: 'tok'),
            groupApi: GroupApiService(),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved tutorials'));
    await tester.pumpAndSettle();
  }

  Finder actionOn(String title, String tooltip) => find.descendant(
        of: find.ancestor(
          of: find.text(title),
          matching: find.byType(ListTile),
        ),
        matching: find.byTooltip(tooltip),
      );

  Finder iconButtonOn(String title, String tooltip) => find.descendant(
        of: find.ancestor(
          of: find.text(title),
          matching: find.byType(ListTile),
        ),
        matching: find.byWidgetPredicate(
          (w) => w is IconButton && w.tooltip == tooltip,
        ),
      );

  testWidgets('the row and the finished dialog both fit a 360 dp phone',
      (tester) async {
    // Added by the lead while grading, after a throwaway probe at 360 dp found
    // an 88 px overflow. Two corrections came out of chasing it, and both are
    // the reason this test looks the way it does.
    //
    // **The overflow was not in the row.** It was the „Video ready!" dialog,
    // whose title is drawn in the theme's headline size and wanted 320 dp of a
    // phone's 232 — and it only appeared *after* a tap, which is why the first
    // version of this test, which only looked at the row at rest, passed on it.
    //
    // **And a title without an ellipsis pushes the actions off the edge.** A
    // tutorial is named by its first sentence, so `'Opozicija'` is not a fair
    // fixture; the long one below is what a real row holds. In a release build
    // there are no stripes — the buttons past the edge are simply unreachable.
    final api = _TestLessonApi(
      requests: <http.Request>[],
      rows: [
        {
          ..._normalTutorialRow,
          'title': 'Pogledaj polje d5: beli konj i lovac oba gadjaju to polje',
        },
      ],
    );
    const longTitle =
        'Pogledaj polje d5: beli konj i lovac oba gadjaju to polje';

    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TutorialLibraryCard(
            session: session,
            api: api,
            assignmentApi: AssignmentApiService(authToken: 'tok'),
            groupApi: GroupApiService(),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved tutorials'));
    await tester.pumpAndSettle();

    // Not `takeException`: an overflow throws in a test build and paints
    // nothing in a release one, and the first version of this test — which
    // asked only for the exception — passed with the row put back the way it
    // overflowed. What matters is whether a finger can reach the button, so
    // that is what is measured.
    // Not `takeException`: what matters is whether a finger can reach the
    // button, so that is what is measured.
    final dialog = tester.getRect(find.byType(AlertDialog));
    for (final tooltip in [
      'Export video',
      'Send to student',
      'Delete tutorial'
    ]) {
      final box = tester.getRect(actionOn(longTitle, tooltip));
      expect(box.left, greaterThanOrEqualTo(dialog.left),
          reason: '$tooltip starts inside the dialog');
      expect(box.right, lessThanOrEqualTo(dialog.right),
          reason: '$tooltip ends inside the dialog, not past its edge');
      expect(box.width, greaterThanOrEqualTo(32),
          reason: '$tooltip is still big enough to hit');
    }

    // And the dialog the export ends in, which is where the overflow actually
    // was. It is reached by a tap, so no test that stops at the row can see it.
    await tester.tap(actionOn(longTitle, 'Export video'));
    await tester.pumpAndSettle();
    expect(find.text('Video ready!'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'the finished dialog fits the phone it is drawn on');

    final ready = tester.getRect(find.byType(AlertDialog).last);
    final download =
        tester.getRect(find.widgetWithText(ElevatedButton, 'Download'));
    expect(download.right, lessThanOrEqualTo(ready.right + 1),
        reason: 'the download button is inside the dialog');
  });

  testWidgets('7. the icon is on the row and disabled while it is busy',
      (tester) async {
    final requests = <http.Request>[];
    final completer = Completer<void>();

    final api = _TestLessonApi(
      requests: requests,
      onExportVideo: () => completer.future,
    );

    await openList(tester, api: api);

    // Both rows offer "Export video"
    expect(actionOn('Opozicija', 'Export video'), findsOneWidget);
    expect(actionOn('Prazan tutorijal', 'Export video'), findsOneWidget);

    // Initial state: not busy
    final btnBefore =
        tester.widget<IconButton>(iconButtonOn('Opozicija', 'Export video'));
    expect(btnBefore.onPressed, isNotNull);

    // Trigger export, which makes row busy while waiting for completer
    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pump(); // Advance frame to trigger setState(_busy = true)

    final btnWhileBusy =
        tester.widget<IconButton>(iconButtonOn('Opozicija', 'Export video'));
    expect(btnWhileBusy.onPressed, isNull,
        reason: 'Export video button must be disabled while row is busy');

    final deleteWhileBusy =
        tester.widget<IconButton>(iconButtonOn('Opozicija', 'Delete tutorial'));
    expect(deleteWhileBusy.onPressed, isNull,
        reason: 'Delete tutorial button must share the busy flag');

    // Complete the in-flight export request
    completer.complete();
    await tester.pumpAndSettle();

    // Dialog shown and busy cleared
    expect(find.text('Video ready!'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    final btnAfter =
        tester.widget<IconButton>(iconButtonOn('Opozicija', 'Export video'));
    expect(btnAfter.onPressed, isNotNull);
  });

  testWidgets(
      '8. an empty tutorial is refused with no request sent — assert on the fake API',
      (tester) async {
    final requests = <http.Request>[];
    final api = _TestLessonApi(requests: requests);

    await openList(tester, api: api);

    // Tap Export video on empty tutorial
    await tester.tap(actionOn('Prazan tutorijal', 'Export video'));
    await tester.pumpAndSettle();

    // Refusal feedback must be displayed
    expect(find.text('This tutorial has nothing to show yet.'), findsOneWidget);

    // Assert on the request: NO export request was sent
    final exportRequests =
        requests.where((r) => r.url.path.contains('/export-video')).toList();
    expect(exportRequests, isEmpty,
        reason:
            'Empty tutorial must be refused client-side without sending an API request');
  });

  testWidgets(
      '9. a normal tutorial sends the events and seconds tutorialVideoOf produces for that draft. Assert on the request.',
      (tester) async {
    final requests = <http.Request>[];
    final api = _TestLessonApi(requests: requests);

    await openList(tester, api: api);

    // Expected video parameters from tutorialVideoOf
    final draft = TutorialDraft.fromLesson(_normalTutorialRow);
    final expectedVideo = tutorialVideoOf(draft);

    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();

    // Assert on the request
    final exportRequests =
        requests.where((r) => r.url.path.contains('/export-video')).toList();
    expect(exportRequests, hasLength(1),
        reason: 'Exactly one export-video request must be sent');

    final req = exportRequests.single;
    expect(req.method, 'POST');
    expect(req.url.path, '/lessons/12/export-video');

    final body = jsonDecode(req.body) as Map<String, dynamic>;
    expect(body['title'], 'Opozicija');
    expect(body['seconds'], expectedVideo.seconds);
    expect(body['events'], jsonDecode(jsonEncode(expectedVideo.events)),
        reason:
            'events sent to backend must match tutorialVideoOf(draft).events exactly');

    // Dialog showing the result must appear with download action
    expect(find.text('Video ready!'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
  });

  testWidgets(
      '10. available: false -> no switch on screen, and no narrate in the request',
      (tester) async {
    final requests = <http.Request>[];
    final api = _TestLessonApi(
      requests: requests,
      ttsAvailable: false,
    );

    await openList(tester, api: api);

    // No switch or narration controls on screen
    expect(find.text('Narrate this video'), findsNothing);
    expect(find.byType(Switch), findsNothing);

    // Export video
    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();

    final exportRequests =
        requests.where((r) => r.url.path.contains('/export-video')).toList();
    expect(exportRequests, hasLength(1));

    final body = jsonDecode(exportRequests.single.body) as Map<String, dynamic>;
    expect(body.containsKey('narrate'), isFalse,
        reason: 'narrate must be omitted when TTS is unavailable');
    expect(body.containsKey('voice'), isFalse,
        reason: 'voice must be omitted when TTS is unavailable');
  });

  testWidgets(
      '11. available: true -> the switch and the chosen voice are in the request',
      (tester) async {
    final requests = <http.Request>[];
    final api = _TestLessonApi(
      requests: requests,
      ttsAvailable: true,
      ttsVoices: [
        {'id': 'sr-RS-Standard-A', 'name': 'Standard A'},
        {'id': 'sr-RS-Standard-B', 'name': 'Standard B'},
      ],
    );

    await openList(tester, api: api);

    // Controls are visible
    expect(find.text('Narrate this video'), findsOneWidget);
    expect(find.text('A narrated export takes longer.'), findsOneWidget);
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);
    expect(tester.widget<Switch>(switchFinder).value, isTrue);

    // Select second voice via DropdownButton
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard B').last);
    await tester.pumpAndSettle();

    // Export video
    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();

    final exportRequests =
        requests.where((r) => r.url.path.contains('/export-video')).toList();
    expect(exportRequests, hasLength(1));

    final body = jsonDecode(exportRequests.single.body) as Map<String, dynamic>;
    expect(body['narrate'], isTrue,
        reason: 'narrate must be true when switch is on');
    expect(body['voice'], 'sr-RS-Standard-B',
        reason: 'chosen voice id must be passed in the request');
  });

  testWidgets('12. the chosen voice survives reopening the sheet',
      (tester) async {
    final requests = <http.Request>[];
    final api = _TestLessonApi(
      requests: requests,
      ttsAvailable: true,
      ttsVoices: [
        {'id': 'sr-RS-Standard-A', 'name': 'Standard A'},
        {'id': 'sr-RS-Standard-B', 'name': 'Standard B'},
      ],
    );

    // First open
    await openList(tester, api: api);

    // Pick voice B
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard B').last);
    await tester.pumpAndSettle();

    // Close dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Reopen dialog
    await tester.tap(find.text('Saved tutorials'));
    await tester.pumpAndSettle();

    // Verify switch is still on and voice B is still selected
    final switchWidget = tester.widget<Switch>(find.byType(Switch));
    expect(switchWidget.value, isTrue,
        reason: 'Switch state must survive reopening the sheet');

    expect(find.text('Standard B'), findsOneWidget,
        reason: 'Chosen voice must survive reopening the sheet');
  });

  test(
      '13. real transport: LessonApiService passes narrate and voice, fetchTtsVoices parses',
      () async {
    final requests = <http.Request>[];
    final client = MockClient((req) async {
      requests.add(req);
      if (req.method == 'GET' && req.url.path == '/lessons/tts/voices') {
        return http.Response(
          jsonEncode({
            'available': true,
            'voices': [
              {'id': 'sr-RS-Standard-A', 'name': 'Standard A'},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (req.method == 'POST' && req.url.path == '/lessons/15/export-video') {
        return http.Response(
          jsonEncode({
            'message': 'ok',
            'downloadUrl': '/download/15.mp4',
            'filename': 'tutorial_15.mp4',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('{"error":"Not found"}', 404);
    });

    final api = LessonApiService(authToken: 'test-token', client: client);

    // 1. fetchTtsVoices
    final ttsResult = await api.fetchTtsVoices();
    expect(ttsResult.available, isTrue);
    expect(ttsResult.voices, hasLength(1));
    expect(ttsResult.voices[0]['id'], 'sr-RS-Standard-A');

    // 2. exportVideo with narrate and voice
    final exportResult = await api.exportVideo(
      lessonId: 15,
      events: [_normalTutorialRow],
      seconds: 10,
      narrate: true,
      voice: 'sr-RS-Standard-A',
    );
    expect(exportResult.downloadUrl, '/download/15.mp4');

    final postReq = requests.firstWhere((r) => r.method == 'POST');
    final body = jsonDecode(postReq.body) as Map<String, dynamic>;
    expect(body['narrate'], isTrue);
    expect(body['voice'], 'sr-RS-Standard-A');
  });
}
