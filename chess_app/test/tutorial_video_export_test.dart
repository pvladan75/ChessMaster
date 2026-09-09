// tutorial_video_export_test.dart
// Tests for tutorial video export door on saved-tutorial rows:
//
// 7. the icon is on the row and disabled while it is busy;
// 8. an empty tutorial is refused with no request sent — assert on the fake API;
// 9. a normal tutorial sends the events and seconds tutorialVideoOf produces
//    for that draft. Assert on the request.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'dart:async';
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
import 'package:chess_app/features/tutorial_studio/services/tutorial_video_export.dart';
import 'package:chess_app/features/tutorial_studio/tutorial_studio_availability.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_library_card.dart';
import 'package:chess_app/models/user_session.dart';

const String _fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

// A part with a move and a sentence on it, which is what a tutorial is. The
// fixture used to be a bare starting position with neither, and it passed only
// because the list screen refused an export by looking at `position_list`
// being empty rather than at whether there was anything to film. There is one
// rule for that now, and a part like the old fixture is correctly refused: two
// seconds of an untouched board with nothing said over it is not a video
// anybody wants, and the server would charge a render for it.
final Map<String, dynamic> _normalTutorialRow = {
  'id': 12,
  'title': 'Opozicija',
  'position_list': [
    {
      'id': 's1',
      'fen': _fen,
      'title': 'Uvod',
      'kind': 'show',
      'pgn': '1. e4 {Beli zauzima centar.} e5',
    },
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
    int? progressPercent,
    int? progressEtaSeconds,
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
      if (req.method == 'GET' && req.url.path.contains('/progress')) {
        return http.Response(
          jsonEncode({
            'percent': progressPercent ?? 0,
            'done': false,
            'etaSeconds': progressEtaSeconds,
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

/// The same `#rrggbb` the exporter sends, for comparing against a skin.
String _hexOf(Color c) =>
    '#${((c.a * 255).round() << 24 | (c.r * 255).round() << 16 | (c.g * 255).round() << 8 | (c.b * 255).round()).toRadixString(16).padLeft(8, '0').substring(2)}';

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

  testWidgets('7. the icon opens the export dialog, and nothing is sent yet',
      (tester) async {
    // The options moved out of the list and into the moment of export, so that
    // the same dialog can be opened from the studio where the tutorial is
    // written. Pressing the icon asks; pressing Cancel sends nothing.
    final requests = <http.Request>[];
    final api = _TestLessonApi(
      requests: requests,
      ttsAvailable: true,
      ttsVoices: [
        {'id': 'en_US-lessac-medium', 'name': 'lessac', 'language': 'en-US'},
      ],
    );

    await openList(tester, api: api);
    expect(actionOn('Opozicija', 'Export video'), findsOneWidget);
    expect(actionOn('Prazan tutorijal', 'Export video'), findsOneWidget);

    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();

    expect(find.text('Export video'), findsWidgets,
        reason: 'the dialog opened');
    expect(find.text('Narrate this video'), findsOneWidget);

    // Scoped: the saved-tutorials dialog has a Cancel of its own, and an
    // unscoped finder would be asking which of two screens to close.
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog).last, matching: find.text('Cancel')));
    await tester.pumpAndSettle();
    expect(requests.where((r) => r.url.path.contains('/export-video')), isEmpty,
        reason: 'cancelling asks for nothing');
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
      '10. available: false -> no question asked, and no narrate in the request',
      (tester) async {
    final requests = <http.Request>[];
    final api = _TestLessonApi(requests: requests, ttsAvailable: false);

    await openList(tester, api: api);
    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();

    // Nothing to ask about, so nothing is asked: the export just runs.
    expect(find.text('Narrate this video'), findsNothing);
    expect(find.byType(Switch), findsNothing);

    final exportRequests =
        requests.where((r) => r.url.path.contains('/export-video')).toList();
    expect(exportRequests, hasLength(1));
    final body = jsonDecode(exportRequests.single.body) as Map<String, dynamic>;
    expect(body.containsKey('narrate'), isFalse,
        reason: 'narrate must be omitted when the server cannot speak');
    expect(body.containsKey('voice'), isFalse);
  });

  testWidgets(
      '11. available: true -> the switch and the chosen voice are in the request',
      (tester) async {
    final requests = <http.Request>[];
    final api = _TestLessonApi(
      requests: requests,
      ttsAvailable: true,
      ttsVoices: [
        {'id': 'en_US-lessac-medium', 'name': 'lessac', 'language': 'en-US'},
        {
          'id': 'de_DE-thorsten-medium',
          'name': 'thorsten',
          'language': 'de-DE'
        },
      ],
    );

    await openList(tester, api: api);
    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();

    expect(find.text('A narrated export takes longer.'), findsOneWidget);
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);
    expect(tester.widget<Switch>(switchFinder).value, isTrue);

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('thorsten').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    final exportRequests =
        requests.where((r) => r.url.path.contains('/export-video')).toList();
    expect(exportRequests, hasLength(1));
    final body = jsonDecode(exportRequests.single.body) as Map<String, dynamic>;
    expect(body['narrate'], isTrue);
    expect(body['voice'], 'de_DE-thorsten-medium',
        reason: 'the voice chosen in the dialog is the one that is sent');
  });

  testWidgets('12. the chosen voice is remembered for the next export',
      (tester) async {
    final requests = <http.Request>[];
    final api = _TestLessonApi(
      requests: requests,
      ttsAvailable: true,
      ttsVoices: [
        {'id': 'en_US-lessac-medium', 'name': 'lessac', 'language': 'en-US'},
        {
          'id': 'de_DE-thorsten-medium',
          'name': 'thorsten',
          'language': 'de-DE'
        },
      ],
    );

    await openList(tester, api: api);

    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('thorsten').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // Second time round, the dialog opens on the voice chosen the first time.
    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    final exportRequests =
        requests.where((r) => r.url.path.contains('/export-video')).toList();
    expect(exportRequests, hasLength(2));
    final second = jsonDecode(exportRequests.last.body) as Map<String, dynamic>;
    expect(second['voice'], 'de_DE-thorsten-medium',
        reason: 'a trainer chooses their voice once, not once per export');
  });

  testWidgets('the studio exports the tutorial it is writing', (tester) async {
    // „Dijalog za renderovanje premestimo tamo gde se tutorijal pravi." Same
    // door, same dialog, one owner — `exportTutorialVideo` — so the two places
    // cannot drift into being two features.
    final requests = <http.Request>[];
    final api = _TestLessonApi(
      requests: requests,
      ttsAvailable: true,
      ttsVoices: [
        {'id': 'en_US-lessac-medium', 'name': 'lessac', 'language': 'en-US'},
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: TutorialStudioScreen(
        session: session,
        entry: TutorialEntry.saved(_normalTutorialRow),
        lessonApi: api,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('export-video')));
    await tester.pumpAndSettle();

    expect(find.text('Narrate this video'), findsOneWidget,
        reason: 'the same options as the list offers');

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    final exportRequests =
        requests.where((r) => r.url.path.contains('/export-video')).toList();
    expect(exportRequests, hasLength(1));
    expect(exportRequests.single.url.path, '/lessons/12/export-video',
        reason: 'the tutorial being written is the one exported');
  });

  testWidgets('the voice can be turned off, and then nothing is spoken',
      (tester) async {
    // A trainer writing in a language none of the installed voices speaks must
    // be able to say no: „neki Indijac piše tutorijal na indijskom i nema
    // opciju da isključi glas". The switch is the answer, and this is the test
    // that it is wired to the request rather than to the dialog only.
    final requests = <http.Request>[];
    final api = _TestLessonApi(
      requests: requests,
      ttsAvailable: true,
      ttsVoices: [
        {'id': 'en_US-lessac-medium', 'name': 'lessac', 'language': 'en-US'},
      ],
    );

    await openList(tester, api: api);
    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Voice'), findsNothing,
        reason: 'with narration off there is no voice to choose');

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    final body = jsonDecode(requests
        .lastWhere((r) => r.url.path.contains('/export-video'))
        .body) as Map<String, dynamic>;
    expect(body['narrate'], isFalse, reason: 'a silent film was asked for');
  });

  testWidgets('the export carries the board, pieces and theme the trainer uses',
      (tester) async {
    // „Renderovani video preuzima temu aplikacije, stil table i figura koje
    // trener trenutno koristi." Colours rather than names: the app has five
    // board skins, three piece skins and a light and a dark theme, and none of
    // that survives being called „wood".
    final requests = <http.Request>[];
    final api = _TestLessonApi(requests: requests, ttsAvailable: false);

    await openList(tester, api: api);
    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();

    final body = jsonDecode(requests
        .lastWhere((r) => r.url.path.contains('/export-video'))
        .body) as Map<String, dynamic>;
    final look = body['look'] as Map<String, dynamic>;

    for (final key in [
      'lightSquare',
      'darkSquare',
      'background',
      'text',
      'accent',
      'whiteFill',
      'whiteStroke',
      'blackFill',
      'blackStroke',
      'blackDecoration',
    ]) {
      expect(look[key], matches(RegExp(r'^#[0-9a-fA-F]{6}$')),
          reason: '$key must be a colour the renderer will accept');
    }

    // The board's own colours, from the skin Settings is showing.
    expect(
        look['lightSquare'],
        equalsIgnoringCase(
            _hexOf(AppSettingsService.instance.boardSkin.lightSquare)));
    expect(
        look['whiteFill'],
        equalsIgnoringCase(
            _hexOf(AppSettingsService.instance.pieceSkin.whiteFill)));
  });

  testWidgets('a render reports its progress, and the bar closes when it ends',
      (tester) async {
    // „Nema info o tome" — a render takes tens of seconds. The percentage is
    // the server's own frame count rather than an animation pretending to be
    // one, and the request carries the job id the app polls for.
    final requests = <http.Request>[];
    final completer = Completer<void>();
    final api = _TestLessonApi(
      requests: requests,
      ttsAvailable: false,
      onExportVideo: () => completer.future,
      progressPercent: 42,
      progressEtaSeconds: 95,
    );

    await openList(tester, api: api);
    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Exporting video'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    final body = jsonDecode(requests
        .lastWhere((r) => r.url.path.contains('/export-video'))
        .body) as Map<String, dynamic>;
    expect(body['jobId'], isNotNull,
        reason: 'the client names its own render so it can watch it');

    // The bar is refreshed from a poll, which the server answers every ten per
    // cent with an estimate of what is left. „Nek šalje na svakih 10 procenata
    // osvežavanje i procenu vremena završetka".
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('42% · about 2 minutes left'), findsOneWidget);

    completer.complete();
    await tester.pumpAndSettle();
    expect(find.text('Exporting video'), findsNothing,
        reason: 'the bar closes itself when the render answers');
    expect(find.text('Video ready!'), findsOneWidget);
  });

  test('the time left is said in words a person reads at a glance', () {
    // The number comes from the frames drawn so far, so a render that says
    // „37 s" and takes fifty has been more wrong than one that said „about a
    // minute". Under ten seconds it stops counting down: the last of the work
    // is ffmpeg closing the file, which the frame count knows nothing about.
    expect(remainingText(null), '');
    expect(remainingText(0), '');
    expect(remainingText(-4), '');
    expect(remainingText(3), ' · almost done');
    expect(remainingText(9), ' · almost done');
    expect(remainingText(12), ' · about 10 s left');
    expect(remainingText(38), ' · about 40 s left');
    expect(remainingText(59), ' · about 1 minute left');
    expect(remainingText(60), ' · about 1 minute left');
    expect(remainingText(95), ' · about 2 minutes left');
    expect(remainingText(600), ' · about 10 minutes left');
  });
}
