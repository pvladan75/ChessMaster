// The trainer's own recording in the export dialog — phases 4 and 6 of
// `docs/PLAN-SNIMANJE.md`. Driven through `exportTutorialVideo` with a fake
// server and a real directory of takes.
//
// What it must never do:
//
//   * send a take the server already holds;
//   * export over a recording the server refused, or say nothing about why;
//   * send a recording and a synthesised voice for the same film;
//   * offer a take that cannot make this film, without saying why not;
//   * forget what the trainer wants when there is no recording, because they
//     chose the recording when there was one.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/assignments/models/assignment.dart'
    show LessonStepKind;
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/narration_take.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_video.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_video_export.dart';
import 'package:chess_app/services/app_settings_service.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// Three beats: the opening position, e4 and e5.
TutorialDraft draftOf({
  String pgn = '{ White takes the centre. } 1. e4 { Black answers. } e5',
}) =>
    TutorialDraft(
      lessonId: 12,
      title: 'Centre',
      sections: [
        TutorialSection(
          root: readStepTree(
            fen: _start,
            pgn: pgn,
          ).root,
          title: 'Part',
          kind: LessonStepKind.show,
        ),
      ],
    );

Uint8List chunkOf({int peak = 8000}) {
  final data = ByteData(2560);
  for (var i = 0; i < 2560; i += 2) {
    data.setInt16(i, (i ~/ 2).isEven ? peak : -peak, Endian.little);
  }
  return data.buffer.asUint8List();
}

class FakeServer {
  FakeServer({
    this.heldTake,
    this.uploadStatus = 201,
    this.uploadError,
    this.canSpeak = false,
  });

  /// Whether the server offers a synthesised voice — without one, `narrate`
  /// is never in a request and „never both voices" cannot be seen.
  final bool canSpeak;

  /// The take id the server says it holds, or null for none.
  final String? heldTake;
  final int uploadStatus;
  final String? uploadError;
  final requests = <http.Request>[];

  late final LessonApiService api =
      LessonApiService(authToken: 'tok', client: MockClient(_answer));

  Future<http.Response> _answer(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    http.Response json(Object body, [int status = 200]) => http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );

    if (path == '/lessons/tts/voices') {
      return json(canSpeak
          ? {
              'available': true,
              'voices': [
                {
                  'id': 'en_US-lessac-medium',
                  'language': 'en-US',
                  'tier': 'medium',
                },
              ],
            }
          : {'available': false, 'voices': <Object>[]});
    }
    if (path == '/lessons/12/narration' && request.method == 'GET') {
      return json(heldTake == null
          ? {'status': 'none'}
          : {'status': 'ready', 'takeId': heldTake});
    }
    if (path == '/lessons/12/narration' && request.method == 'POST') {
      if (uploadStatus != 201) {
        return json({'error': uploadError}, uploadStatus);
      }
      return json({
        'narration': {'ms': 800, 'beats': 3},
      }, 201);
    }
    if (path.contains('/progress')) {
      return json({'percent': 0, 'done': false, 'queuedAhead': 0});
    }
    if (path == '/lessons/12/export-video') {
      return json({
        'message':
            'Video rendered successfully, saved, and ready for download!',
        'downloadUrl': '/recordings/export-download/x.mp4?token=t',
      });
    }
    return json({'error': 'Not found'}, 404);
  }

  /// What was asked, in order, without the progress polls.
  List<String> get calls => [
        for (final r in requests)
          if (!r.url.path.contains('/progress')) '${r.method} ${r.url.path}',
      ];

  Map<String, dynamic> get exportBody => jsonDecode(
          requests.lastWhere((r) => r.url.path.endsWith('/export-video')).body)
      as Map<String, dynamic>;
}

late Directory _dir;
late NarrationTakeStore _store;

Future<StoredNarration> keepTake({
  int eventCount = 3,
  List<int> markers = const [0, 400, 600],

  /// The beats it was recorded against — phase 5. Null is a take from before
  /// phase 5, which is what every other test in this file uses and which is
  /// judged by its count as it always was.
  String? signature,
}) async {
  final path = await _store.newRecordingPath(12);
  final sink = WavFileSink(path);
  for (var i = 0; i < 10; i++) {
    sink.add(chunkOf());
  }
  await sink.finish();
  return _store.keep(
    12,
    NarrationTake(
      markersMs: markers,
      durationMs: 800,
      eventCount: eventCount,
      peakDbfs: -12,
      recordedAt: DateTime(2026, 9, 10),
      signature: signature,
    ),
    path,
  );
}

/// A take kept in [dir] through a store of its own, for a test whose own store
/// is made to answer slow.
Future<void> keepTakeIn(Directory dir) async {
  final own = _store;
  _store = NarrationTakeStore(() async => dir);
  try {
    await keepTake();
  } finally {
    _store = own;
  }
}

Future<void> openExport(
  WidgetTester tester,
  FakeServer server, {
  Size size = const Size(1400, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => exportTutorialVideo(
            context: context,
            api: server.api,
            lessonId: 12,
            title: 'Centre',
            draft: draftOf(),
            narrationStore: _store,
          ),
          child: const Text('go'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

Future<void> pressExport(WidgetTester tester) async {
  await tester.tap(find.text('Export'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsService.instance.init();
    _dir = Directory.systemTemp.createTempSync('export_recording_');
    _store = NarrationTakeStore(() async => _dir);
  });

  tearDown(() {
    try {
      _dir.deleteSync(recursive: true);
    } catch (_) {
      // A handle the platform still holds on Windows; the OS owns temp.
    }
  });

  testWidgets('a usable take is offered, sent, and the film uses it',
      (tester) async {
    final kept = await keepTake();
    final server = FakeServer();
    await openExport(tester, server);

    expect(find.byKey(const Key('export-voice-recording')), findsOneWidget);
    expect(find.textContaining('My recording (0:00)'), findsOneWidget);

    // Nothing is touched: what goes out is the default.
    await pressExport(tester);

    expect(server.calls, [
      'GET /lessons/tts/voices',
      'GET /lessons/12/narration',
      'POST /lessons/12/narration',
      'POST /lessons/12/export-video',
    ]);
    expect(server.exportBody['useRecording'], isTrue,
        reason: 'a recorded take is the default');
    expect(server.exportBody['takeId'], kept.takeId);
    expect(server.exportBody.containsKey('narrate'), isFalse,
        reason: 'a film is never sent a recording and a synthesised voice');
  });

  testWidgets('a take the server already holds is not sent again',
      (tester) async {
    final kept = await keepTake();
    final server = FakeServer(heldTake: kept.takeId);
    await openExport(tester, server);
    await pressExport(tester);

    expect(server.calls, isNot(contains('POST /lessons/12/narration')));
    expect(server.exportBody['useRecording'], isTrue);
    expect(server.exportBody['takeId'], kept.takeId);
  });

  testWidgets('a different take on the server is replaced by this one',
      (tester) async {
    await keepTake();
    final server = FakeServer(heldTake: '0000000000000000');
    await openExport(tester, server);
    await pressExport(tester);

    expect(server.calls, contains('POST /lessons/12/narration'));
  });

  testWidgets('answered „No voice", the film goes without it', (tester) async {
    await keepTake();
    final server = FakeServer();
    await openExport(tester, server);

    await tester.tap(find.byKey(const Key('export-voice-none')));
    await tester.pumpAndSettle();
    await pressExport(tester);

    expect(server.calls.where((c) => c.contains('/narration')), isEmpty);
    expect(server.exportBody.containsKey('useRecording'), isFalse);
    expect(server.exportBody.containsKey('takeId'), isFalse);
  });

  testWidgets('a take made for other beats is explained, not offered',
      (tester) async {
    await keepTake(eventCount: 5, markers: [0, 100, 200, 300, 400]);
    final server = FakeServer();
    await openExport(tester, server);

    expect(find.byKey(const Key('export-voice-recording')), findsNothing);
    expect(
        find.textContaining('had 5 beats, and it has 3 now'), findsOneWidget);

    await pressExport(tester);
    expect(server.calls.where((c) => c.contains('/narration')), isEmpty);
  });

  testWidgets('a take of the same beats saying something else is not offered',
      (tester) async {
    // Phase 5, and the case no count can see: three beats before, three now,
    // and the middle one about another sentence. The switch must not be there
    // at all — a take offered and then refused by the render is the worst of
    // both.
    await keepTake(
        signature: filmSignatureOf(filmBeatsOf(draftOf(
      pgn: '{ White takes the middle. } 1. e4 { Black answers. } e5',
    ))));
    final server = FakeServer();
    await openExport(tester, server);

    expect(find.byKey(const Key('export-voice-recording')), findsNothing);
    expect(find.textContaining('has been edited'), findsOneWidget);

    await pressExport(tester);
    expect(server.calls.where((c) => c.contains('/narration')), isEmpty);
  });

  testWidgets('the beats travel with the take and with the film',
      (tester) async {
    // Both ends, because they answer different questions. The upload's is what
    // the server stores beside the recording; the export's is what the server
    // compares it with — and the take on the server may have come from another
    // device, against beats that have moved since.
    final signature = filmSignatureOf(filmBeatsOf(draftOf()));
    await keepTake(signature: signature);
    final server = FakeServer();
    await openExport(tester, server);
    await pressExport(tester);

    final upload = server.requests.lastWhere(
        (r) => r.url.path.endsWith('/narration') && r.method == 'POST');
    // Read as bytes: the body carries a wav, so decoding it as text throws.
    // Asked as a whole multipart field rather than as a substring anywhere in
    // it — a digest sent under some other field's name is not the same request.
    expect(latin1.decode(upload.bodyBytes),
        contains('name="signature"\r\n\r\n$signature'),
        reason: 'the server would store a recording it cannot judge again');
    expect(server.exportBody['signature'], signature);
  });

  testWidgets('a film without the recording carries no beats to compare',
      (tester) async {
    // The signature answers one question — „is this recording still the right
    // one" — and a film that is not asking it must not send an answer.
    await keepTake(signature: filmSignatureOf(filmBeatsOf(draftOf())));
    final server = FakeServer();
    await openExport(tester, server);

    await tester.tap(find.byKey(const Key('export-voice-none')));
    await tester.pumpAndSettle();
    await pressExport(tester);

    expect(server.exportBody.containsKey('signature'), isFalse);
  });

  testWidgets('a refused upload stops the export, and says why',
      (tester) async {
    const sentence = 'The recording arrived incomplete: 0:00 of the 0:01 that '
        'were recorded. Upload it again.';
    await keepTake();
    final server = FakeServer(uploadStatus: 400, uploadError: sentence);
    await openExport(tester, server);
    await pressExport(tester);

    expect(find.text(sentence), findsOneWidget);
    expect(server.calls, isNot(contains('POST /lessons/12/export-video')),
        reason: 'a film was rendered over a recording the server refused');
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('with a synthesised voice on offer, the recording goes alone',
      (tester) async {
    await keepTake();
    final server = FakeServer(canSpeak: true);
    await openExport(tester, server);

    expect(find.byType(DropdownButton<String>), findsNothing,
        reason: 'a synthesised voice was being chosen beside the recording');
    await pressExport(tester);

    expect(server.exportBody['useRecording'], isTrue);
    expect(server.exportBody.containsKey('narrate'), isFalse);
    expect(server.exportBody.containsKey('voice'), isFalse);
  });

  testWidgets('answered „Synthesised voice", the recording stays behind',
      (tester) async {
    await keepTake();
    final server = FakeServer(canSpeak: true);
    await openExport(tester, server);

    await tester.tap(find.byKey(const Key('export-voice-synthesised')));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButton<String>), findsOneWidget);
    await pressExport(tester);

    expect(server.exportBody['narrate'], isTrue);
    expect(server.exportBody.containsKey('useRecording'), isFalse);
  });

  testWidgets('a lookup that answers after the dialog has gone touches nothing',
      (tester) async {
    // The folder is asked for and answers late — a slow disk, or a platform
    // call — and the trainer has already cancelled.
    final slow = Completer<Directory>();
    _store = NarrationTakeStore(() => slow.future);
    await keepTakeIn(_dir);
    final server = FakeServer();
    await openExport(tester, server);
    expect(find.byKey(const Key('export-voice-recording')), findsNothing);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    slow.complete(_dir);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(server.calls.where((c) => c.contains('/export-video')), isEmpty);
  });

  testWidgets('with no take on this device there is nothing to offer',
      (tester) async {
    final server = FakeServer();
    await openExport(tester, server);

    expect(find.byKey(const Key('export-voice-recording')), findsNothing);
    expect(find.byKey(const Key('export-recording-unusable')), findsNothing);
    await pressExport(tester);
    expect(server.calls.where((c) => c.contains('/narration')), isEmpty);
    expect(_dir.listSync(), isEmpty,
        reason: 'looking for a take left a folder behind');
  });

  testWidgets('one question, three answers, and „No voice" is a silent film',
      (tester) async {
    // Phase 6. Every answer the sheet can give is drawn, and the one that
    // turns both voices down is not the absence of the other two: with piper
    // installed, a film with nothing chosen used to be a synthesised one.
    await keepTake();
    final server = FakeServer(canSpeak: true);
    await openExport(tester, server);

    expect(find.byKey(const Key('export-voice-recording')), findsOneWidget);
    expect(find.byKey(const Key('export-voice-synthesised')), findsOneWidget);
    expect(find.byKey(const Key('export-voice-none')), findsOneWidget);

    await tester.tap(find.byKey(const Key('export-voice-none')));
    await tester.pumpAndSettle();
    await pressExport(tester);

    expect(server.exportBody['narrate'], isFalse,
        reason: 'a silent film was asked for');
    expect(server.exportBody.containsKey('useRecording'), isFalse);
    expect(server.calls.where((c) => c.contains('/narration')), isEmpty);
  });

  testWidgets('choosing the recording keeps the answer given without one',
      (tester) async {
    // The recording is the default wherever there is one, so choosing it says
    // nothing about the tutorial edited after recording or the next one not
    // yet recorded — and those must still open on the synthesised voice the
    // trainer asked for last time.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_video_narrate', true);
    await keepTake();
    final server = FakeServer(canSpeak: true);
    await openExport(tester, server);
    await pressExport(tester);

    expect(server.exportBody['useRecording'], isTrue);
    expect(prefs.getBool('tutorial_video_narrate'), isTrue,
        reason: 'exporting with the recording turned the synthesised voice off '
            'for every film without one');
  });

  testWidgets('on a phone, the quality can still be reached', (tester) async {
    // The tallest the sheet gets: all three answers, the voice dropdown and
    // its note, and the quality under them. A release build clips an overflow
    // without a word, so what is asked is whether the switch at the bottom
    // still works — not whether something threw.
    await keepTake();
    final server = FakeServer(canSpeak: true);
    await openExport(tester, server, size: const Size(360, 640));

    await tester.tap(find.byKey(const Key('export-voice-synthesised')));
    await tester.pumpAndSettle();
    final quality = find.descendant(
      of: find.ancestor(
          of: find.text('Higher quality (1080p)'), matching: find.byType(Row)),
      matching: find.byType(Switch),
    );
    await tester.ensureVisible(quality);
    await tester.pumpAndSettle();
    await tester.tap(quality);
    await tester.pumpAndSettle();
    await pressExport(tester);

    expect(server.exportBody['resolution'], '1080p');
  });
}
