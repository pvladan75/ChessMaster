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
import 'package:chess_app/services/app_settings_service.dart';
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

/// A real 1x1 PNG. The frames a preview draws are the server's business; what
/// this file asks is whether the door exists and what goes through it, so the
/// image only has to be something `Image.memory` can actually decode.
const String _tinyPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

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

/// A tutorial that has already been rendered once. `has_video` is what the
/// list route says, and it is what decides whether the download button exists
/// at all.
final Map<String, dynamic> _renderedTutorialRow = {
  'id': 12,
  'title': 'Opozicija',
  'has_video': true,
  'video_rendered_at': '2026-09-09T20:00:00.000Z',
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

/// The one render the fake server runs, as its progress route describes it.
///
/// Mutable on purpose. Since item 5 of part two of `docs/PLAN-SNIMANJE.md` the
/// export request is answered before the film is drawn, and the dialog learns
/// that the film has ended from this route — so a test moves the render along
/// by changing it, the way the server would.
class _Render {
  String status = 'done';
  int percent = 0;
  int? etaSeconds;
  int queuedAhead = 0;
  String? error;

  Map<String, dynamic> toJson() => {
        'status': status,
        'percent': status == 'done' ? 100 : percent,
        'done': status != 'running',
        'etaSeconds': etaSeconds,
        'queuedAhead': queuedAhead,
        if (status == 'done') ...{
          'message':
              'Video rendered successfully, saved, and ready for download!',
          'downloadUrl':
              '/recordings/export-download/tutorial_12.mp4?token=fresh',
        },
        if (error != null) 'error': error,
      };
}

/// The export request itself — not a poll of its progress, whose path carries
/// the same words, and not a cancel.
bool _isExport(http.Request r) =>
    r.method == 'POST' && r.url.path.endsWith('/export-video');

bool _isProgress(http.Request r) => r.url.path.endsWith('/progress');

class _TestLessonApi extends LessonApiService {
  _TestLessonApi._(
    this.requests,
    this.render,
    http.Client client,
  ) : super(authToken: 'tok', client: client);

  final List<http.Request> requests;
  final _Render render;

  factory _TestLessonApi({
    required List<http.Request> requests,
    // Accepted: the server names the job and draws the film behind the answer.
    int status = 202,
    String responseBody = '{"jobId":"job-12","status":"running"}',
    List<Map<String, dynamic>>? rows,
    Future<void> Function()? onExportVideo,
    bool ttsAvailable = false,
    List<Map<String, dynamic>>? ttsVoices,
    int sampleStatus = 200,
    _Render? render,
    int previewStatus = 200,
    int videoLinkStatus = 200,
  }) {
    final effectiveRows = rows ?? [_normalTutorialRow, _emptyTutorialRow];
    final job = render ?? _Render();
    final client = MockClient((req) async {
      requests.add(req);
      if (req.method == 'GET' && req.url.path == '/lessons') {
        return http.Response(
          jsonEncode(effectiveRows),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (req.method == 'GET' && req.url.path == '/lessons/tts/sample') {
        if (sampleStatus != 200) {
          return http.Response(
            jsonEncode({'error': 'This server does not have that voice'}),
            sampleStatus,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        // A wav header and nothing after it: what the test is about is which
        // voice was asked for, and no test opens an audio device.
        return http.Response.bytes(
          <int>[0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x41, 0x56, 0x45],
          200,
          headers: {'content-type': 'audio/wav'},
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
      if (req.method == 'GET' && _isProgress(req)) {
        return http.Response(
          jsonEncode(job.toJson()),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (req.method == 'DELETE' &&
          req.url.path.startsWith('/lessons/export-video/')) {
        // Stopped; its row says so by the next poll, as the real one does.
        job.status = 'cancelled';
        return http.Response(
          '{"status":"cancelling"}',
          202,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (req.method == 'GET' && req.url.path.endsWith('/video')) {
        if (videoLinkStatus == 200) {
          return http.Response(
            jsonEncode({
              'status': 'ready',
              'filename': 'tutorial_12.mp4',
              'downloadUrl':
                  '/recordings/export-download/tutorial_12.mp4?token=fresh',
              'renderedAt': '2026-09-09T20:00:00.000Z',
              'resolution': '720p',
              'narrated': false,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode({
            'status': videoLinkStatus == 410 ? 'expired' : 'none',
            'error': videoLinkStatus == 410
                ? 'This video has been deleted to save space. Export it again.'
                : 'This tutorial has no video yet.',
          }),
          videoLinkStatus,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (req.method == 'POST' && req.url.path.contains('/preview-frames')) {
        return http.Response(
          jsonEncode({
            'frames': [
              {'beatIndex': 0, 'png': _tinyPng},
              {'beatIndex': 1, 'png': _tinyPng},
            ],
          }),
          previewStatus,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (_isExport(req)) {
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
    return _TestLessonApi._(requests, job, client);
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

  /// The export sheet's switch for [label], which is the one in its row.
  ///
  /// There are two switches in that sheet now — narration and quality — so a
  /// bare `find.byType(Switch)` asks which of them without saying.
  Finder switchFor(String label) => find.descendant(
        of: find.ancestor(of: find.text(label), matching: find.byType(Row)),
        matching: find.byType(Switch),
      );

  /// Press the row's export icon and then „Export" in the sheet.
  ///
  /// **The sheet opens for every export now**, not only where the server can
  /// speak: the quality is a choice everywhere, and a switch reachable only
  /// where piper happens to be installed is one half the trainers do not have.
  /// Pass `settle: false` where the render is deliberately left in flight.
  Future<void> startExport(
    WidgetTester tester,
    String title, {
    bool settle = true,
  }) async {
    await tester.tap(actionOn(title, 'Export video'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog).last,
      matching: find.text('Export'),
    ));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('Preview draws stills without rendering anything',
      (tester) async {
    // **The point of the feature.** A film costs tens of seconds of the one
    // render slot on the server; until this, finding out that a part stood the
    // wrong way round meant rendering the whole thing and watching it.
    final requests = <http.Request>[];
    final api = _TestLessonApi(requests: requests);
    await openList(tester, api: api);

    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('export-preview')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('preview-dialog')), findsOneWidget);

    final preview =
        requests.where((r) => r.url.path.contains('/preview-frames'));
    expect(preview, hasLength(1), reason: 'one preview request went out');

    // **Nothing was rendered.** A preview that quietly exported would be worse
    // than no preview: it would spend the slot it exists to save.
    expect(
      requests.where((r) => _isExport(r)),
      isEmpty,
    );

    final body = jsonDecode(preview.first.body) as Map<String, dynamic>;
    expect(body['resolution'], '720p');
    expect((body['events'] as List), isNotEmpty);
  });

  testWidgets('the preview is drawn at the quality that is switched on',
      (tester) async {
    // A still at 720p answers nothing about a 1080p export: the caption text
    // and the thin piece outlines are exactly what the two resolutions differ
    // in, and they are why the switch exists.
    final requests = <http.Request>[];
    final api = _TestLessonApi(requests: requests);
    await openList(tester, api: api);

    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();
    await tester.tap(switchFor('Higher quality (1080p)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export-preview')));
    await tester.pumpAndSettle();

    final preview =
        requests.lastWhere((r) => r.url.path.contains('/preview-frames'));
    expect(jsonDecode(preview.body)['resolution'], '1080p');
  });

  testWidgets('the export sheet is still standing when the preview closes',
      (tester) async {
    // A preview is a look, not a decision — closing it must leave the trainer
    // where they were, with the switches they had set.
    final requests = <http.Request>[];
    final api = _TestLessonApi(requests: requests);
    await openList(tester, api: api);

    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export-preview')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('preview-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('preview-dialog')), findsNothing);
    expect(find.text('Export video'), findsWidgets,
        reason: 'the sheet the trainer was standing in is still open');
    expect(find.byKey(const Key('export-preview')), findsOneWidget);
  });

  testWidgets('the frames can be paged through', (tester) async {
    final requests = <http.Request>[];
    final api = _TestLessonApi(requests: requests);
    await openList(tester, api: api);

    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export-preview')));
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
    await tester.tap(find.byKey(const Key('preview-next')));
    await tester.pumpAndSettle();
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('a preview the server refuses says so and renders nothing',
      (tester) async {
    final requests = <http.Request>[];
    final api = _TestLessonApi(requests: requests, previewStatus: 500);
    await openList(tester, api: api);

    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export-preview')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('preview-dialog')), findsNothing);
    expect(
      requests.where((r) => _isExport(r)),
      isEmpty,
    );
  });

  testWidgets('the download button is drawn only where there is a film',
      (tester) async {
    // An action offered on a row that cannot perform it is this repository's
    // most frequent fault — the tree menu that drew „Delete this variation"
    // with no callback, the sheet nobody could open.
    final requests = <http.Request>[];
    final api = _TestLessonApi(
      requests: requests,
      rows: [_renderedTutorialRow, _emptyTutorialRow],
    );
    await openList(tester, api: api);

    expect(iconButtonOn('Opozicija', 'Download video'), findsOneWidget);
    expect(iconButtonOn('Prazan tutorijal', 'Download video'), findsNothing);
  });

  testWidgets('Download video asks the server for a fresh link',
      (tester) async {
    // **The whole reason the tutorial keeps its filename.** The link handed out
    // when a film is rendered carries a token that dies in thirty minutes, so
    // this must be a new request rather than something the app remembered.
    final requests = <http.Request>[];
    final api = _TestLessonApi(
      requests: requests,
      rows: [_renderedTutorialRow],
    );
    await openList(tester, api: api);

    await tester.tap(iconButtonOn('Opozicija', 'Download video'));
    await tester.pumpAndSettle();

    final asked = requests.where(
      (r) => r.method == 'GET' && r.url.path.endsWith('/lessons/12/video'),
    );
    expect(asked, hasLength(1));
    // And nothing was rendered to get it.
    expect(
      requests.where((r) => _isExport(r)),
      isEmpty,
    );
  });

  testWidgets('a film that has aged out says so, and the button goes away',
      (tester) async {
    // „There is no film" and „the film was deleted to save space, export it
    // again" lead to different buttons, so they must not read the same. And a
    // row whose file the retention timer has taken must stop offering it.
    final requests = <http.Request>[];
    final api = _TestLessonApi(
      requests: requests,
      rows: [_renderedTutorialRow],
      videoLinkStatus: 410,
    );
    await openList(tester, api: api);

    await tester.tap(iconButtonOn('Opozicija', 'Download video'));
    await tester.pumpAndSettle();

    expect(find.textContaining('deleted to save space'), findsOneWidget);
    expect(iconButtonOn('Opozicija', 'Download video'), findsNothing);
  });

  testWidgets('a row with a film still fits a 360 dp phone', (tester) async {
    // The fourth icon on that row. The file this test lives in exists because
    // the same row overflowed once already, and in a release build there are no
    // stripes — the buttons past the edge are simply unreachable.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final longTitle = Map<String, dynamic>.from(_renderedTutorialRow)
      ..['title'] = 'Pogledaj kako beli pesak na d5 oduzima polje konju i '
          'zasto crni to ne sme da dozvoli';

    final api = _TestLessonApi(requests: <http.Request>[], rows: [longTitle]);
    await openList(tester, api: api);

    expect(tester.takeException(), isNull);
    // `takeException` alone is not a layout assertion — an overflow throws in a
    // test build and paints nothing in a release one. What „unreachable" means
    // is that the button is not inside the dialog.
    final dialog = tester.getRect(find.byType(AlertDialog).last);
    final button = tester
        .getRect(iconButtonOn(longTitle['title'] as String, 'Download video'));
    expect(button.right, lessThanOrEqualTo(dialog.right + 0.5),
        reason: 'the download button is inside the dialog, not past its edge');
  });

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
    await startExport(tester, longTitle);
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
    expect(find.byKey(const Key('export-voice-synthesised')), findsOneWidget);

    // Scoped: the saved-tutorials dialog has a Cancel of its own, and an
    // unscoped finder would be asking which of two screens to close.
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog).last, matching: find.text('Cancel')));
    await tester.pumpAndSettle();
    expect(requests.where((r) => _isExport(r)), isEmpty,
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
    final exportRequests = requests.where((r) => _isExport(r)).toList();
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

    await startExport(tester, 'Opozicija');

    // Assert on the request
    final exportRequests = requests.where((r) => _isExport(r)).toList();
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
      '10. available: false -> nothing is asked about the voice, and no narrate in the request',
      (tester) async {
    final requests = <http.Request>[];
    final api = _TestLessonApi(requests: requests, ttsAvailable: false);

    await openList(tester, api: api);
    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();

    // An answer the server cannot honour is not drawn, and with no recording
    // either, „No voice" is the only one left — which is not a question. The
    // sheet still opens, because the quality is a choice everywhere.
    expect(find.byWidgetPredicate((w) => w is RadioListTile), findsNothing,
        reason: 'a question with one answer was asked');
    expect(find.text('Voice'), findsNothing);
    expect(switchFor('Higher quality (1080p)'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget,
        reason: 'the quality switch, and no narration one beside it');

    await tester.tap(find.descendant(
      of: find.byType(AlertDialog).last,
      matching: find.text('Export'),
    ));
    await tester.pumpAndSettle();

    final exportRequests = requests.where((r) => _isExport(r)).toList();
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
    expect(find.byKey(const Key('export-voice-synthesised')), findsOneWidget);
    expect(find.byKey(const Key('export-voice-voice')), findsOneWidget,
        reason: 'a synthesised voice is the default where the server has one');

    // Two languages on offer, so the language is asked first - and the voice
    // follows it, because a voice of the language nobody chose must not stay
    // selected. `find.byType` was enough here while the sheet had one dropdown;
    // it is scoped rather than weakened now that it has two.
    await tester.tap(find.byKey(const Key('export-voice-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('de-DE').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export-voice-voice')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('thorsten').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    final exportRequests = requests.where((r) => _isExport(r)).toList();
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
    await tester.tap(find.byKey(const Key('export-voice-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('de-DE').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // Second time round, the dialog opens on the voice chosen the first time -
    // and therefore on its language, or the trainer would have to find German
    // again every time they exported.
    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();
    expect(find.text('de-DE'), findsOneWidget,
        reason: 'the sheet opens on the language of the remembered voice');
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    final exportRequests = requests.where((r) => _isExport(r)).toList();
    expect(exportRequests, hasLength(2));
    final second = jsonDecode(exportRequests.last.body) as Map<String, dynamic>;
    expect(second['voice'], 'de_DE-thorsten-medium',
        reason: 'a trainer chooses their voice once, not once per export');
  });

  // A cloud account's list, in miniature. The real one answered with 655 voices
  // across 154 languages on 11.9.2026, which is what these tests are about: one
  // dropdown of 655 is a list nobody scrolls to the end of.
  final cloudVoices = <Map<String, dynamic>>[
    {
      'id': 'af-ZA-AdriNeural',
      'name': 'Adri',
      'language': 'af-ZA',
      'languageName': 'Afrikaans (South Africa)',
      'tier': 'Neural',
    },
    {
      'id': 'de-DE-KatjaNeural',
      'name': 'Katja',
      'language': 'de-DE',
      'languageName': 'German (Germany)',
      'tier': 'Neural',
    },
    {
      'id': 'en-US-JennyNeural',
      'name': 'Jenny',
      'language': 'en-US',
      'languageName': 'English (United States)',
      'tier': 'Neural',
    },
    {
      'id': 'sr-Latn-RS-NicholasNeural',
      'name': 'Nicholas',
      'language': 'sr-Latn-RS',
      'languageName': 'Serbian (Latin, Serbia)',
      'tier': 'Neural',
    },
    {
      'id': 'sr-Latn-RS-SophieNeural',
      'name': 'Sophie',
      'language': 'sr-Latn-RS',
      'languageName': 'Serbian (Latin, Serbia)',
      'tier': 'Neural',
    },
  ];

  testWidgets('the voice list is only the language that was chosen',
      (tester) async {
    final api = _TestLessonApi(
      requests: <http.Request>[],
      ttsAvailable: true,
      ttsVoices: cloudVoices,
    );

    await openList(tester, api: api);
    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();

    // The language a person reads, not the code: „Serbian (Latin, Serbia)" is
    // the difference between choosing and guessing at `sr-Latn-RS`.
    await tester.tap(find.byKey(const Key('export-voice-language')));
    await tester.pumpAndSettle();
    expect(find.text('Serbian (Latin, Serbia)'), findsWidgets);
    await tester.tap(find.text('Serbian (Latin, Serbia)').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('export-voice-voice')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nicholas'), findsWidgets);
    expect(find.textContaining('Sophie'), findsWidgets);
    expect(find.textContaining('Katja'), findsNothing,
        reason: 'a voice of another language is not in this list');
    expect(find.textContaining('Jenny'), findsNothing);
  });

  testWidgets('the second voice of a language is the one that is sent',
      (tester) async {
    // The filter has to narrow the list and change nothing about what travels:
    // the request carries the id the trainer picked, not the first of the
    // language they picked it in.
    final requests = <http.Request>[];
    final api = _TestLessonApi(
      requests: requests,
      ttsAvailable: true,
      ttsVoices: cloudVoices,
    );

    await openList(tester, api: api);
    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('export-voice-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Serbian (Latin, Serbia)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export-voice-voice')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Sophie').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    final body = jsonDecode(requests.where(_isExport).single.body)
        as Map<String, dynamic>;
    expect(body['voice'], 'sr-Latn-RS-SophieNeural');
  });

  testWidgets('a first export opens on English, not on the top of the list',
      (tester) async {
    // The list is sorted by language, so „the first voice" was Afrikaans the
    // moment a provider answered with 154 of them. A trainer who has chosen
    // nothing gets the app's own language, and a real voice id in the request
    // rather than none at all - which a cloud provider refuses outright.
    final requests = <http.Request>[];
    final api = _TestLessonApi(
      requests: requests,
      ttsAvailable: true,
      ttsVoices: cloudVoices,
    );

    await openList(tester, api: api);
    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();
    expect(find.text('English (United States)'), findsOneWidget);
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    final body = jsonDecode(requests.where(_isExport).single.body)
        as Map<String, dynamic>;
    expect(body['voice'], 'en-US-JennyNeural');
  });

  testWidgets('a remembered voice the server no longer offers is not sent',
      (tester) async {
    // What switching TTS_PROVIDER does: every id on the server changes at once,
    // and the one in this trainer's preferences names a piper model that is no
    // longer installed. Sending it would be answered with a message about the
    // voice, and the film would come back silent.
    SharedPreferences.setMockInitialValues(
        {'tutorial_video_voice': 'de_DE-thorsten-medium'});
    final requests = <http.Request>[];
    final api = _TestLessonApi(
      requests: requests,
      ttsAvailable: true,
      ttsVoices: cloudVoices,
    );

    await openList(tester, api: api);
    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    final body = jsonDecode(requests.where(_isExport).single.body)
        as Map<String, dynamic>;
    expect(body['voice'], 'en-US-JennyNeural',
        reason:
            'the stale id is dropped, and English is where the sheet opens');
  });

  testWidgets('a voice with no language of its own does not break the sheet',
      (tester) async {
    // Reachable, and that is the point of it: this is the state where a value
    // names no item in the dropdown, which is what `DropdownButton` throws on.
    // The server's own providers all drop a voice with no language, so nothing
    // shipped produces this - a proxy, a cache or a hand-written fixture can,
    // and a red screen in a trainer's face is not the way to find out.
    SharedPreferences.setMockInitialValues(
        {'tutorial_video_voice': 'mystery-voice'});
    final requests = <http.Request>[];
    final api = _TestLessonApi(
      requests: requests,
      ttsAvailable: true,
      ttsVoices: [
        {'id': 'mystery-voice', 'name': 'Mystery'},
        ...cloudVoices,
      ],
    );

    await openList(tester, api: api);
    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    final body = jsonDecode(requests.where(_isExport).single.body)
        as Map<String, dynamic>;
    expect(body['voice'], 'en-US-JennyNeural',
        reason: 'a voice in no language is not one the sheet can offer');
  });

  testWidgets('a voice can be heard before a film is spent on it',
      (tester) async {
    // „Ili da se pusti sample sa glasom da čuje, da ne ide odmah u
    // renderovanje" — auditioning by export is minutes and a queue slot per
    // voice, and this account offers 655 of them.
    //
    // What is asserted is the request: playing it needs an audio device and a
    // temporary directory, neither of which a widget test has, and the
    // question a trainer is asking is which voice speaks.
    final requests = <http.Request>[];
    final api = _TestLessonApi(
      requests: requests,
      ttsAvailable: true,
      ttsVoices: cloudVoices,
    );
    // Everything the button does except the sound: the fetch is real and goes
    // through the fake server, and only the audio device is left out. The gate
    // holds the answer so the button can be caught mid-sentence — a fake that
    // answers at once is a fake that cannot show a spinner.
    final gate = Completer<bool>();
    debugPlayVoiceSample = (api, voice) async {
      await api.fetchVoiceSample(voice);
      return gate.future;
    };
    addTearDown(() => debugPlayVoiceSample = null);

    await openList(tester, api: api);
    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('export-voice-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Serbian (Latin, Serbia)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export-voice-sample')));
    // Frames, not `pumpAndSettle`: while the sample is being fetched the button
    // is a spinner, and a spinner never settles.
    await tester.pump();
    expect(
        find.descendant(
            of: find.byKey(const Key('export-voice-sample')),
            matching: find.byType(CircularProgressIndicator)),
        findsOneWidget,
        reason: 'the button says it is working');
    gate.complete(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final sample = requests.where((r) => r.url.path == '/lessons/tts/sample');
    expect(sample, hasLength(1));
    expect(
        sample.single.url.queryParameters['voice'], 'sr-Latn-RS-NicholasNeural',
        reason: 'the voice under the cursor, not the one the sheet opened on');

    // And nothing was rendered by pressing it: this is the whole point.
    expect(requests.where(_isExport), isEmpty);

    // The spinner goes back to being a button, or a second voice can never be
    // heard.
    expect(
        find.descendant(
            of: find.byKey(const Key('export-voice-sample')),
            matching: find.byType(CircularProgressIndicator)),
        findsNothing);
  });

  testWidgets('a voice that cannot be played says so', (tester) async {
    // The server refuses a voice it does not have, and a trainer who pressed a
    // button and heard nothing must not be left wondering whether their
    // speakers are off.
    final api = _TestLessonApi(
      requests: <http.Request>[],
      ttsAvailable: true,
      ttsVoices: cloudVoices,
      sampleStatus: 404,
    );
    debugPlayVoiceSample =
        (api, voice) async => (await api.fetchVoiceSample(voice)) != null;
    addTearDown(() => debugPlayVoiceSample = null);

    await openList(tester, api: api);
    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export-voice-sample')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.textContaining('could not be played'), findsOneWidget);
  });

  testWidgets('one language on offer is not a question', (tester) async {
    // The same rule the narration question above follows: an answer that cannot
    // be chosen is not drawn. A server with one installed voice, or six of one
    // language, asks about the voice and not about the language.
    final api = _TestLessonApi(
      requests: <http.Request>[],
      ttsAvailable: true,
      ttsVoices: [
        {'id': 'en_US-lessac-medium', 'name': 'lessac', 'language': 'en-US'},
        {'id': 'en_US-amy-medium', 'name': 'amy', 'language': 'en-US'},
      ],
    );

    await openList(tester, api: api);
    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('export-voice-language')), findsNothing);
    expect(find.byKey(const Key('export-voice-voice')), findsOneWidget);
  });

  testWidgets('both voice controls are reachable on a 360 dp phone',
      (tester) async {
    // Measured, not assumed. This sheet has been 49 px too tall for a phone
    // once already, and a release build clips that without a word - the control
    // under the fold is not „off screen", it is a tap that presses Export. The
    // proof is the request: a language and a voice chosen at 360 x 640 arrive
    // in it.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final requests = <http.Request>[];
    final api = _TestLessonApi(
      requests: requests,
      ttsAvailable: true,
      ttsVoices: cloudVoices,
    );

    await openList(tester, api: api);
    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('export-voice-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Serbian (Latin, Serbia)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('export-voice-voice')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Sophie').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    final body = jsonDecode(requests.where(_isExport).single.body)
        as Map<String, dynamic>;
    expect(body['voice'], 'sr-Latn-RS-SophieNeural');
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

    expect(find.byKey(const Key('export-voice-synthesised')), findsOneWidget,
        reason: 'the same options as the list offers');

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    final exportRequests = requests.where((r) => _isExport(r)).toList();
    expect(exportRequests, hasLength(1));
    expect(exportRequests.single.url.path, '/lessons/12/export-video',
        reason: 'the tutorial being written is the one exported');
  });

  testWidgets('the voice can be turned off, and then nothing is spoken',
      (tester) async {
    // A trainer writing in a language none of the installed voices speaks must
    // be able to say no: „neki Indijac piše tutorijal na indijskom i nema
    // opciju da isključi glas". „No voice" is the answer, and this is the test
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

    await tester.tap(find.byKey(const Key('export-voice-none')));
    await tester.pumpAndSettle();
    expect(find.text('Voice'), findsNothing,
        reason: 'with narration off there is no voice to choose');

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    final body = jsonDecode(requests.lastWhere((r) => _isExport(r)).body)
        as Map<String, dynamic>;
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
    await startExport(tester, 'Opozicija');

    final body = jsonDecode(requests.lastWhere((r) => _isExport(r)).body)
        as Map<String, dynamic>;
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
    // one. Since item 5 of part two the export is answered before the film is
    // drawn, so the bar also learns from its poll that the film has ended.
    final requests = <http.Request>[];
    final render = _Render()
      ..status = 'running'
      ..percent = 42
      ..etaSeconds = 95;
    final api = _TestLessonApi(
      requests: requests,
      ttsAvailable: false,
      render: render,
    );

    await openList(tester, api: api);
    await startExport(tester, 'Opozicija', settle: false);

    expect(find.text('Exporting video'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // The server names the job now: a key the client chooses is one another
    // client can choose too.
    final body =
        jsonDecode(requests.lastWhere(_isExport).body) as Map<String, dynamic>;
    expect(body.containsKey('jobId'), isFalse);

    // The bar is refreshed from a poll, which the server answers every ten per
    // cent with an estimate of what is left. „Nek šalje na svakih 10 procenata
    // osvežavanje i procenu vremena završetka".
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.text('42% · about 2 minutes left'), findsOneWidget);
    expect(requests.where(_isProgress).map((r) => r.url.path).toSet(),
        {'/lessons/export-video/job-12/progress'},
        reason: 'the job the server named is the one watched');

    render.status = 'done';
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Exporting video'), findsNothing,
        reason: 'the bar closes itself when the render ends');
    expect(find.text('Video ready!'), findsOneWidget);
    expect(find.textContaining('token=fresh'), findsOneWidget,
        reason: 'the link is the one the progress route minted just now');
  });

  testWidgets('1080p is asked for by a switch, and remembered', (tester) async {
    // „A može uvodjenje prekidača za 1080p". Two resolutions rather than three:
    // 720p is what a video watched on a phone wants, 1080p is for YouTube —
    // which gives a 720p upload a lower bitrate ladder, and the caption text
    // goes first — or a projector. 480p is not offered: it saves about 30 KB on
    // an eighteen-second film, because this is flat graphics on flat colour,
    // and it pays for it in the caption a child reads.
    final requests = <http.Request>[];
    final api = _TestLessonApi(requests: requests, ttsAvailable: false);

    await openList(tester, api: api);

    // Off by default, and the ordinary export is the one nobody has to think
    // about.
    await startExport(tester, 'Opozicija');
    var body = jsonDecode(requests.lastWhere((r) => _isExport(r)).body)
        as Map<String, dynamic>;
    expect(body['resolution'], '720p');
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();
    await tester.tap(switchFor('Higher quality (1080p)'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog).last,
      matching: find.text('Export'),
    ));
    await tester.pumpAndSettle();

    body = jsonDecode(requests.lastWhere((r) => _isExport(r)).body)
        as Map<String, dynamic>;
    expect(body['resolution'], '1080p',
        reason: 'the switch is wired to the request, not to the dialog only');
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // Remembered, for the same reason the voice is: a trainer who publishes to
    // YouTube publishes to it every time.
    await tester.tap(actionOn('Opozicija', 'Export video'));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(switchFor('Higher quality (1080p)')).value,
        isTrue);
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog).last,
      matching: find.text('Export'),
    ));
    await tester.pumpAndSettle();
    body = jsonDecode(requests.lastWhere((r) => _isExport(r)).body)
        as Map<String, dynamic>;
    expect(body['resolution'], '1080p');
  });

  testWidgets('a render that is waiting for the machine says so',
      (tester) async {
    // „Možda ispisati poruku „Vaš video će uskoro početi da se renderuje", a
    // kad počne, onda ide onaj progres bar." The server draws one film at a
    // time — two side by side share one CPU and finish together, both late — so
    // an export can spend its first stretch waiting. „Starting…" over an empty
    // bar is exactly what a render that had begun and frozen would show, which
    // is why a queued one says something else.
    final requests = <http.Request>[];
    final render = _Render()
      ..status = 'running'
      ..queuedAhead = 2;
    final api = _TestLessonApi(
      requests: requests,
      ttsAvailable: false,
      render: render,
    );

    await openList(tester, api: api);
    await startExport(tester, 'Opozicija', settle: false);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(
        find.text(
            'Your video will start rendering shortly — 2 videos ahead of it.'),
        findsOneWidget);
    final bar = tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(bar.value, isNull,
        reason: 'a bar stuck at 0 % reads as a render that started and froze');

    render.status = 'done';
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Video ready!'), findsOneWidget);
  });

  test('the wait is said in words, and one video is not two', () {
    expect(waitingText(1),
        'Your video will start rendering shortly — one video ahead of it.');
    expect(waitingText(3),
        'Your video will start rendering shortly — 3 videos ahead of it.');
    // Its turn came between two polls: there is nothing in front of it any
    // more, and the bar takes over from here.
    expect(waitingText(0), 'Starting…');
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

  // ------------------------------------------------ item 5: after the request
  //
  // „Ne mogu da pošaljem sa istog naloga, jer se ekran zamrzne kad pošaljem na
  // renderovanje." The film is drawn after its request since item 5 of part two
  // of docs/PLAN-SNIMANJE.md, so the bar can be put away, found again, and
  // stopped.

  testWidgets('Hide puts the bar away, and the film goes on rendering',
      (tester) async {
    final requests = <http.Request>[];
    final render = _Render()
      ..status = 'running'
      ..percent = 10;
    final api =
        _TestLessonApi(requests: requests, ttsAvailable: false, render: render);

    await openList(tester, api: api);
    await startExport(tester, 'Opozicija', settle: false);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Exporting video'), findsOneWidget);

    await tester.tap(find.byKey(const Key('render-hide')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Exporting video'), findsNothing);
    expect(find.textContaining('keeps rendering'), findsOneWidget);
    expect(requests.where((r) => r.method == 'DELETE'), isEmpty,
        reason: 'hiding is not stopping');

    // The row shows the render rather than offering a second one.
    expect(
        iconButtonOn('Opozicija', 'Rendering — show progress'), findsOneWidget);
    expect(iconButtonOn('Opozicija', 'Export video'), findsNothing);

    // And nothing goes on asking once the bar is gone.
    final polls = requests.where(_isProgress).length;
    await tester.pump(const Duration(seconds: 3));
    expect(requests.where(_isProgress).length, polls,
        reason: 'a hidden bar kept polling');
    await tester.pumpAndSettle();
  });

  testWidgets(
      'a render running on a row is shown again, and nothing new is started',
      (tester) async {
    // A hidden render has to be somewhere a trainer can find it again. The list
    // says which tutorial has one (`render_job_id`).
    final requests = <http.Request>[];
    final api = _TestLessonApi(
      requests: requests,
      rows: [
        {..._normalTutorialRow, 'render_job_id': 'job-7'},
      ],
    );
    await openList(tester, api: api);

    expect(iconButtonOn('Opozicija', 'Export video'), findsNothing);
    await tester.tap(iconButtonOn('Opozicija', 'Rendering — show progress'));
    await tester.pumpAndSettle();

    expect(requests.where(_isExport), isEmpty,
        reason: 'shown again, not started again');
    final watched = requests.where(_isProgress).map((r) => r.url.path);
    expect(watched, isNotEmpty);
    expect(watched, everyElement('/lessons/export-video/job-7/progress'));
    expect(find.text('Video ready!'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(iconButtonOn('Opozicija', 'Download video'), findsOneWidget,
        reason: 'the film it made is on the row now');
    expect(iconButtonOn('Opozicija', 'Export video'), findsOneWidget);
  });

  testWidgets('Cancel render stops it on the server, and the bar says so',
      (tester) async {
    final requests = <http.Request>[];
    final render = _Render()
      ..status = 'running'
      ..percent = 30;
    final api =
        _TestLessonApi(requests: requests, ttsAvailable: false, render: render);

    await openList(tester, api: api);
    await startExport(tester, 'Opozicija', settle: false);
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byKey(const Key('render-cancel')));
    await tester.pump();
    // The bar stays until the render says it has stopped: a film finished in
    // the same moment is still a film.
    expect(find.text('Cancelling…'), findsOneWidget);
    expect(find.text('Exporting video'), findsOneWidget);
    final cancels = requests.where((r) => r.method == 'DELETE').toList();
    expect(cancels, hasLength(1));
    expect(cancels.single.url.path, '/lessons/export-video/job-12');

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Exporting video'), findsNothing);
    expect(find.text('Video export cancelled.'), findsOneWidget);
    expect(find.text('Video ready!'), findsNothing);
    expect(iconButtonOn('Opozicija', 'Export video'), findsOneWidget,
        reason: 'a cancelled render leaves the row free to export again');
  });

  testWidgets('a render that failed says why, in the server\'s words',
      (tester) async {
    final requests = <http.Request>[];
    final render = _Render()
      ..status = 'failed'
      ..error = 'With narration, this video would take about 12 minutes to '
          'render. Export it without narration.';
    final api =
        _TestLessonApi(requests: requests, ttsAvailable: false, render: render);

    await openList(tester, api: api);
    await startExport(tester, 'Opozicija');

    expect(find.textContaining('about 12 minutes to render'), findsOneWidget);
    expect(find.text('Video ready!'), findsNothing);
    expect(find.text('Exporting video'), findsNothing);
  });

  testWidgets(
      'a tutorial already rendering shows that render rather than starting another',
      (tester) async {
    final requests = <http.Request>[];
    final api = _TestLessonApi(
      requests: requests,
      status: 409,
      responseBody: '{"error":"This tutorial is already being rendered.",'
          '"jobId":"job-7","alreadyRendering":true}',
    );

    await openList(tester, api: api);
    await startExport(tester, 'Opozicija');

    expect(find.textContaining('already rendering'), findsOneWidget,
        reason: 'the choices just made are not what it is drawn with — said');
    expect(requests.where(_isProgress).map((r) => r.url.path).toSet(),
        {'/lessons/export-video/job-7/progress'});
    expect(find.text('Video ready!'), findsOneWidget);
  });

  testWidgets('a refusal is said at once, and nothing is watched',
      (tester) async {
    final requests = <http.Request>[];
    final api = _TestLessonApi(
      requests: requests,
      status: 422,
      responseBody: '{"error":"This video would take about 40 minutes to '
          'render.","tooLong":true}',
    );

    await openList(tester, api: api);
    await startExport(tester, 'Opozicija');

    expect(find.textContaining('about 40 minutes to render'), findsOneWidget);
    expect(requests.where(_isProgress), isEmpty);
    expect(find.text('Exporting video'), findsNothing);
  });

  testWidgets('the bar and both its buttons fit a 360 dp phone',
      (tester) async {
    // Measured, not assumed: a release build clips an overflow without a word,
    // and a button past the edge of this dialog is a render nobody can stop.
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final render = _Render()
      ..status = 'running'
      ..percent = 40
      ..etaSeconds = 95;
    final api = _TestLessonApi(requests: <http.Request>[], render: render);
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
    await startExport(tester, 'Opozicija', settle: false);
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    final dialog = tester.getRect(find.ancestor(
        of: find.text('Exporting video'), matching: find.byType(AlertDialog)));
    for (final key in ['render-hide', 'render-cancel']) {
      final button = tester.getRect(find.byKey(Key(key)));
      expect(button.left, greaterThanOrEqualTo(dialog.left),
          reason: '$key starts inside the dialog');
      expect(button.right, lessThanOrEqualTo(dialog.right),
          reason: '$key ends inside the dialog');
      expect(button.bottom, lessThanOrEqualTo(dialog.bottom),
          reason: '$key is not cut off below it');
    }

    render.status = 'done';
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });
}
