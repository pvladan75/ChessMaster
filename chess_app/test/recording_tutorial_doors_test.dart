// The doors of phase 8 of docs/PLAN-PRIPREMA.md — „Make a tutorial" from a
// recording, and the recording's voice in the export. The core is built and
// graded (lib/features/tutorial_studio/services/recording_tutorial.dart,
// test/recording_to_tutorial_test.dart); the server route too
// (POST /lessons/:id/narration/from-recording, chess_backend/test/
// recording_voice_copy.test.js). This gate holds what a trainer reaches.
//
// The contract this gate holds, and nothing else of the implementation:
//
//   lib/features/tutorial_studio/services/recording_tutorial_flow.dart
//     Future<int?> makeTutorialFromRecording(BuildContext context, {
//       required UserSession session,
//       required int recordingId,
//       required http.Client client,
//     })
//     Every request goes through [client]. In order:
//       GET  /recordings/<id>                 the recording (timeline, length,
//                                             source, title)
//       GET  /recordings/<id>/transcript      its transcript, if any
//       POST /lessons/save                    the tutorial: title = the
//                                             recording's, language = the
//                                             transcript's, positionList =
//                                             recordingTutorialOf(...)'s draft
//       POST /lessons/<new id>/narration/from-recording
//                                             { recordingId, markersMs, beats,
//                                               signature } — the core's
//     and then the Tutorial Studio opens on the saved tutorial.
//     Returns the new tutorial's id, or null when none was made.
//     A second call for a recording whose first is still running sends
//     nothing and returns null.
//
//   What a trainer reads (AppFeedback, or the dialog):
//     a room recording     „Only a lesson recorded in Preparation can become
//                           a tutorial." — before anything is sent
//     the core refuses     its own sentence (RecordingTutorialRefused.reason)
//     the save is refused  the server's sentence; nothing else is sent and
//                           the studio does not open
//     the voice is refused the studio opens all the same (the tutorial is
//                           made), and the message says it was made „without
//                           your voice" and gives the server's sentence
//     no transcript        a dialog whose text contains „no transcript",
//                           with `recording-tutorial-without-words` („Make it
//                           without words") and `recording-tutorial-cancel`
//
//   The doors:
//     Library — a recording card whose entry says `fromPreparation: true`
//       has an IconButton with the tooltip „Make a tutorial"; one that does
//       not, has none. LibraryScreen takes an optional `http.Client? client`
//       for the flow.
//     Player — `transcript-make-tutorial`, a button with the words „Make a
//       tutorial", inside the transcript panel (so only ever the host's, on a
//       recording made in Preparation).
//
//   The export (exportTutorialVideo), when this device holds no take and the
//   server's GET /lessons/<id>/narration answers `follows: 'positions'`:
//     - offered as `export-voice-recording`, with a line containing „From the
//       recording", when its `beats` is the film's number of beats and its
//       `signature` is filmPositionsSignatureOf(filmBeatsOf(draft));
//     - exported with useRecording true, no takeId, that signature, and
//       nothing uploaded;
//     - otherwise not offered, with the sentence
//       „Your recording was laid over <n> beats, and the tutorial has <m>
//        now. …" or, the same count, „… since it was made from your
//        recording …".
//     A corrected sentence keeps the voice (D18); a replaced move does not.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/services/analysis_persistence_service.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/screens/library_screen.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/position_scanner/services/scanner_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/narration_take.dart';
import 'package:chess_app/features/tutorial_studio/services/recording_tutorial.dart';
import 'package:chess_app/features/tutorial_studio/services/recording_tutorial_flow.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_video.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_video_export.dart';
import 'package:chess_app/models/recording_models.dart';
import 'package:chess_app/models/recording_transcript.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/replay_player_screen.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/lesson_recording_api.dart';
import 'package:chess_app/theme/app_colors.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const _afterE4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
const _afterE5 =
    'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2';

const _host = 1;
final _session =
    UserSession(token: 'tok', id: _host, email: 'e', name: 'N', role: 'trener');

List<Map<String, Object?>> _timeline() => [
      {
        'timestampMs': 0,
        'eventType': 'init',
        'data': {'fen': _start, 'pgn': ''},
      },
      {
        'timestampMs': 4000,
        'eventType': 'move',
        'data': {'fen': _afterE4, 'from': 'e2', 'to': 'e4'},
      },
      {
        'timestampMs': 6500,
        'eventType': 'arrow_drawn',
        'data': {
          'arrows': [
            {'from': 'g1', 'to': 'f3', 'color': 'G'},
          ],
        },
      },
      {
        'timestampMs': 9000,
        'eventType': 'move',
        'data': {'fen': _afterE5, 'from': 'e7', 'to': 'e5'},
      },
    ];

Map<String, Object?> _recording({
  String source = 'preparation',
  List<Map<String, Object?>>? timeline,
}) =>
    {
      'id': 31,
      'room_id': null,
      'source': source,
      'host_id': _host,
      'host_name': 'Vladan',
      'title': 'Italijanska',
      'audio_url': null,
      'video_download_url': null,
      'duration_ms': 12000,
      'timeline_json': timeline ?? _timeline(),
      'created_at': '2026-09-27T12:00:00.000Z',
    };

List<Map<String, Object?>> _sentences() => [
      {
        'startMs': 500,
        'endMs': 3000,
        'text': 'Počinjemo iz početne pozicije.',
        'heard': 'Počinjemo iz početne pozicije.',
      },
      {
        'startMs': 4500,
        'endMs': 8000,
        'text': 'Beli igra e4 i skakač ide na f3.',
        'heard': 'Beli igra e4 i skakač ide na f3.',
      },
    ];

Map<String, Object?> _transcript() => {
      'language': 'sr-Latn',
      'vendor': 'groq',
      'model': 'whisper-large-v3',
      'durationMs': 12000,
      'sentences': _sentences(),
      'updatedAt': '2026-09-27T12:10:00.000Z',
    };

/// What the core makes of the same recording — the flow must send this, and
/// nothing it composed a second way.
RecordingTutorial _core({bool withWords = true}) => recordingTutorialOf(
      events: [
        for (final e in _timeline())
          TimelineEvent.fromJson(Map<String, dynamic>.from(e))
      ],
      durationMs: 12000,
      sentences: withWords
          ? [
              for (final s in _sentences())
                TranscriptSentence.fromJson(Map<String, Object?>.from(s))
            ]
          : const [],
      title: 'Italijanska',
      language: withWords ? 'sr-Latn' : null,
    );

/// A PGN's text without the date its exporter stamps on every call.
String _undated(Object? positionList) => jsonEncode(positionList)
    .replaceAll(RegExp(r'\[Date \\"[^\\]*\\"\]'), '[Date]');

/// JSON in utf-8, as Express sends it: the fixtures' Serbian letters are not
/// latin1, which is what package:http assumes when no charset is named.
http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
      utf8.encode(jsonEncode(body)),
      status,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

/// One server behind every seam, answering what the real one answers and
/// recording what it is asked.
class _Server {
  _Server({
    this.source = 'preparation',
    this.timeline,
    this.withTranscript = true,
    this.saveStatus = 201,
    this.voiceStatus = 201,
    this.fromPreparation = true,
  });

  final String source;
  final List<Map<String, Object?>>? timeline;
  final bool withTranscript;
  final int saveStatus;
  final int voiceStatus;
  final bool fromPreparation;
  final requests = <http.Request>[];

  late final http.Client client = MockClient((req) async {
    requests.add(req);
    final path = req.url.path;
    if (req.method == 'GET' && path == '/recordings/31') {
      return _json(_recording(source: source, timeline: timeline));
    }
    if (req.method == 'GET' && path == '/recordings/31/transcript') {
      return _json({
        'available': true,
        'languages': ['en', 'sr-Latn'],
        'transcript': withTranscript ? _transcript() : null,
      });
    }
    if (req.method == 'POST' && path == '/lessons/save') {
      if (saveStatus != 201) {
        return _json({'error': 'The library is full.'}, saveStatus);
      }
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      return _json({
        'id': 77,
        'title': body['title'],
        'language': body['language'],
        'position_list': [
          for (final (i, step) in (body['positionList'] as List).indexed)
            {...(step as Map), 'id': 'step-$i'},
        ],
      }, 201);
    }
    if (req.method == 'POST' &&
        path == '/lessons/77/narration/from-recording') {
      if (voiceStatus != 201) {
        return _json({
          'error': 'The recording\'s sound is missing.',
        }, voiceStatus);
      }
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      return _json({
        'narration': {
          'ms': 12000,
          'beats': (body['markersMs'] as List).length,
          'follows': 'positions',
          'recordedAt': '2026-09-27T12:20:00.000Z',
        },
      }, 201);
    }
    if (req.method == 'GET' && path == '/lessons/77') {
      return _json({
        'id': 77,
        'title': 'Italijanska',
        'language': 'sr-Latn',
        'position_list': _core().draft.positionList,
      });
    }
    if (path.endsWith('/library/positions')) {
      return _json({
        'items': [
          {
            'kind': 'recording',
            'id': '31',
            'title': 'Italijanska',
            'fen': '',
            'fromPreparation': fromPreparation,
          },
          {
            'kind': 'recording',
            'id': '32',
            'title': 'An old room lesson',
            'fen': '',
            'fromPreparation': false,
          },
        ],
      });
    }
    if (path.endsWith('/lessons/labels')) return _json(<Object>[]);
    if (path == '/lessons') return _json(<Object>[]);
    return _json(<Object>[], 200);
  });

  List<String> get calls => [
        for (final r in requests)
          if (!r.url.path.contains('/progress')) '${r.method} ${r.url.path}',
      ];

  List<String> get writes => calls.where((c) => !c.startsWith('GET')).toList();

  Map<String, dynamic> bodyOf(String call) {
    final r = requests.lastWhere((r) => '${r.method} ${r.url.path}' == call);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}

/// A button that runs the flow, on a window wide enough for the studio.
Future<void> _pumpFlow(WidgetTester tester, _Server server,
    {int times = 1}) async {
  SharedPreferences.setMockInitialValues({});
  await TutorialDraftService.instance.clear();
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light().copyWith(extensions: const [AppColorTokens.light]),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () {
            for (var i = 0; i < times; i++) {
              makeTutorialFromRecording(context,
                  session: _session, recordingId: 31, client: server.client);
            }
          },
          child: const Text('make'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('make'));
  await tester.pumpAndSettle();
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the flow', () {
    testWidgets(
        'a recording with a transcript becomes the core\'s tutorial, gets its '
        'voice, and opens in the studio', (tester) async {
      final server = _Server();
      await _pumpFlow(tester, server);

      expect(server.calls.take(4).toList(), [
        'GET /recordings/31',
        'GET /recordings/31/transcript',
        'POST /lessons/save',
        'POST /lessons/77/narration/from-recording',
      ]);

      final core = _core();
      final saved = server.bodyOf('POST /lessons/save');
      expect(saved['title'], 'Italijanska');
      expect(saved['language'], 'sr-Latn');
      expect(
          _undated(saved['positionList']), _undated(core.draft.positionList));

      final voice = server.bodyOf('POST /lessons/77/narration/from-recording');
      expect(voice['recordingId'], 31);
      expect(voice['markersMs'], core.markersMs);
      expect(voice['beats'], core.beats);
      expect(voice['signature'], core.signature);

      expect(find.byType(TutorialStudioScreen), findsOneWidget);
      await _close(tester);
    });

    testWidgets(
        'a refused voice leaves the tutorial made and opened, and says why',
        (tester) async {
      final server = _Server(voiceStatus: 404);
      await _pumpFlow(tester, server);

      expect(server.writes, [
        'POST /lessons/save',
        'POST /lessons/77/narration/from-recording',
      ]);
      expect(find.byType(TutorialStudioScreen), findsOneWidget,
          reason: 'the tutorial exists; the studio opens on it');
      expect(find.textContaining('without your voice'), findsOneWidget);
      expect(find.textContaining('The recording\'s sound is missing.'),
          findsOneWidget);
      await _close(tester);
    });

    testWidgets('a refused save sends nothing more and opens nothing',
        (tester) async {
      final server = _Server(saveStatus: 500);
      await _pumpFlow(tester, server);

      expect(server.writes, ['POST /lessons/save']);
      expect(find.byType(TutorialStudioScreen), findsNothing);
      expect(find.textContaining('The library is full.'), findsOneWidget);
      await _close(tester);
    });

    testWidgets(
        'with no transcript it asks first; „Cancel" sends nothing, and '
        '„Make it without words" makes a wordless tutorial', (tester) async {
      final cancelled = _Server(withTranscript: false);
      await _pumpFlow(tester, cancelled);
      expect(find.textContaining('no transcript'), findsOneWidget);
      await tester.tap(find.byKey(const Key('recording-tutorial-cancel')));
      await tester.pumpAndSettle();
      expect(cancelled.writes, isEmpty);
      expect(find.byType(TutorialStudioScreen), findsNothing);
      await _close(tester);

      final made = _Server(withTranscript: false);
      await _pumpFlow(tester, made);
      await tester
          .tap(find.byKey(const Key('recording-tutorial-without-words')));
      await tester.pumpAndSettle();
      final core = _core(withWords: false);
      expect(_undated(made.bodyOf('POST /lessons/save')['positionList']),
          _undated(core.draft.positionList));
      expect(
          made.bodyOf('POST /lessons/77/narration/from-recording')['markersMs'],
          core.markersMs);
      expect(find.byType(TutorialStudioScreen), findsOneWidget);
      await _close(tester);
    });

    testWidgets('a room recording is refused before anything is sent',
        (tester) async {
      final server = _Server(source: 'room');
      await _pumpFlow(tester, server);
      expect(server.writes, isEmpty);
      expect(
          find.text(
              'Only a lesson recorded in Preparation can become a tutorial.'),
          findsOneWidget);
      await _close(tester);
    });

    testWidgets('what the core refuses is said in its words, and nothing sent',
        (tester) async {
      final server = _Server(timeline: const []);
      await _pumpFlow(tester, server);
      expect(server.writes, isEmpty);
      expect(find.text('This recording has no board to make a tutorial of.'),
          findsOneWidget);
      await _close(tester);
    });

    testWidgets('two starts on one recording make one tutorial',
        (tester) async {
      final server = _Server();
      await _pumpFlow(tester, server, times: 2);
      expect(server.writes.where((w) => w == 'POST /lessons/save').length, 1);
      await _close(tester);
    });
  });

  group('the Library\'s door', () {
    Future<_Server> openLibrary(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await TutorialDraftService.instance.clear();
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final server = _Server();
      final client = server.client;
      AnalysisPersistenceService.setInstance(
          AnalysisPersistenceService.withClient(client));
      addTearDown(AnalysisPersistenceService.resetInstance);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.light()
            .copyWith(extensions: const [AppColorTokens.light]),
        home: LibraryScreen(
          session: _session,
          positionLibrary:
              PositionLibraryService(authToken: 'tok', client: client),
          lessonApi: LessonApiService(authToken: 'tok', client: client),
          exerciseApi: ExerciseApiService(authToken: 'tok', client: client),
          recordingApi: LessonRecordingApi(authToken: 'tok', client: client),
          scannerApi: ScannerApiService(authToken: 'tok', client: client),
          client: client,
        ),
      ));
      await tester.pumpAndSettle();
      return server;
    }

    Finder button(String id) => find.descendant(
        of: find.byKey(ValueKey('library-row-recording-$id')),
        matching: find.byTooltip('Make a tutorial'));

    testWidgets(
        'a Preparation recording offers „Make a tutorial"; a room one does not',
        (tester) async {
      await openLibrary(tester);
      expect(find.byKey(const ValueKey('library-row-recording-31')),
          findsOneWidget);
      expect(button('31'), findsOneWidget);
      expect(find.byKey(const ValueKey('library-row-recording-32')),
          findsOneWidget);
      expect(button('32'), findsNothing);
      await _close(tester);
    });

    testWidgets('the door makes the tutorial and opens it', (tester) async {
      final server = await openLibrary(tester);
      await tester.tap(button('31'));
      await tester.pumpAndSettle();
      expect(server.writes, [
        'POST /lessons/save',
        'POST /lessons/77/narration/from-recording',
      ]);
      expect(find.byType(TutorialStudioScreen), findsOneWidget);
      await _close(tester);
    });
  });

  group('the player\'s door', () {
    Future<_Server> openPlayer(WidgetTester tester,
        {int reader = _host}) async {
      SharedPreferences.setMockInitialValues({});
      await TutorialDraftService.instance.clear();
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final server = _Server();
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.light()
            .copyWith(extensions: const [AppColorTokens.light]),
        home: ReplayPlayerScreen(
          recordingId: 31,
          userSession: UserSession(
              token: 'tok', id: reader, email: 'e', name: 'N', role: 'trener'),
          client: server.client,
        ),
      ));
      await tester.pumpAndSettle();
      return server;
    }

    testWidgets('the host of a Preparation recording makes a tutorial of it',
        (tester) async {
      final server = await openPlayer(tester);
      final door = find.byKey(const Key('transcript-make-tutorial'));
      expect(door, findsOneWidget);
      expect(find.descendant(of: door, matching: find.text('Make a tutorial')),
          findsOneWidget);
      await tester.tap(door);
      await tester.pumpAndSettle();
      expect(server.writes, [
        'POST /lessons/save',
        'POST /lessons/77/narration/from-recording',
      ]);
      expect(find.byType(TutorialStudioScreen), findsOneWidget);
      await _close(tester);
    });

    testWidgets('a student watching it has no such door', (tester) async {
      await openPlayer(tester, reader: 3);
      expect(find.byKey(const Key('transcript-make-tutorial')), findsNothing);
      await _close(tester);
    });
  });

  group('the copied voice in the export', () {
    /// Three beats: the opening position, e4 and e5.
    TutorialDraft draftOf(String pgn) => TutorialDraft(
          lessonId: 12,
          title: 'Centre',
          sections: [
            TutorialSection(
                root: readStepTree(fen: _start, pgn: pgn).root, title: 'Part'),
          ],
        );
    const said = '{ White takes the centre. } 1. e4 { Black answers. } e5';
    final positions = filmPositionsSignatureOf(filmBeatsOf(draftOf(said)));

    Future<List<http.Request>> export(WidgetTester tester, TutorialDraft draft,
        Map<String, Object?> narration) async {
      SharedPreferences.setMockInitialValues({});
      await AppSettingsService.instance.init();
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final requests = <http.Request>[];
      final api = LessonApiService(
          authToken: 'tok',
          client: MockClient((req) async {
            requests.add(req);
            final path = req.url.path;
            if (path == '/lessons/tts/voices') {
              return _json({'available': false, 'voices': <Object>[]});
            }
            if (path == '/lessons/12/narration' && req.method == 'GET') {
              return _json(narration);
            }
            if (path.contains('/progress')) {
              return _json({
                'status': 'done',
                'percent': 100,
                'done': true,
                'queuedAhead': 0,
                'message': 'Video ready.',
                'downloadUrl': '/recordings/export-download/x.mp4?token=t',
              });
            }
            if (path == '/lessons/12/export-video') {
              return _json({'jobId': 'job-12', 'status': 'running'}, 202);
            }
            return _json({'error': 'Not found'}, 404);
          }));
      // An empty store: this device holds no take of the tutorial.
      final dir = _emptyDir();
      addTearDown(() {
        try {
          dir.deleteSync(recursive: true);
        } catch (_) {}
      });
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => exportTutorialVideo(
                context: context,
                api: api,
                lessonId: 12,
                title: 'Centre',
                draft: draft,
                narrationStore: NarrationTakeStore(() async => dir),
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      return requests;
    }

    Map<String, Object?> copied({int beats = 3, String? signature}) => {
          'status': 'ready',
          'maxMs': 1800000,
          'takeId': null,
          'ms': 12000,
          'beats': beats,
          'recordedAt': '2026-09-27T12:20:00.000Z',
          'follows': 'positions',
          'signature': signature ?? positions,
        };

    Map<String, dynamic> exportBody(List<http.Request> requests) =>
        jsonDecode(requests
            .lastWhere((r) => r.url.path.endsWith('/export-video'))
            .body) as Map<String, dynamic>;

    testWidgets(
        'held on the server and still following the positions, it is offered '
        'and used, and nothing is uploaded', (tester) async {
      final requests = await export(tester, draftOf(said), copied());
      expect(find.byKey(const Key('export-voice-recording')), findsOneWidget);
      expect(find.textContaining('From the recording'), findsOneWidget);
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      expect(
          requests.where(
              (r) => r.method == 'POST' && r.url.path.endsWith('/narration')),
          isEmpty,
          reason: 'the voice is already on the server; nothing is sent');
      final body = exportBody(requests);
      expect(body['useRecording'], isTrue);
      expect(body['takeId'], isNull);
      expect(body['signature'], positions);
      expect(body.containsKey('narrate'), isFalse);
    });

    testWidgets('a corrected sentence keeps the voice (D18)', (tester) async {
      await export(
          tester,
          draftOf('{ White takes the center. } 1. e4 { Black answers. } e5'),
          copied());
      expect(find.byKey(const Key('export-voice-recording')), findsOneWidget);
    });

    testWidgets('a replaced move does not, and says so', (tester) async {
      final requests = await export(
          tester,
          draftOf('{ White takes the centre. } 1. d4 { Black answers. } d5'),
          copied());
      expect(find.byKey(const Key('export-voice-recording')), findsNothing);
      expect(find.textContaining('since it was made from your recording'),
          findsOneWidget);
      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      expect(exportBody(requests).containsKey('useRecording'), isFalse);
    });

    testWidgets('another number of beats does not, and says so',
        (tester) async {
      await export(
          tester,
          draftOf('{ White takes the centre. } { And holds it. } 1. e4 '
              '{ Black answers. } e5'),
          copied());
      expect(find.byKey(const Key('export-voice-recording')), findsNothing);
      expect(
          find.textContaining('laid over 3 beats, and the tutorial has 4 now'),
          findsOneWidget);
    });

    testWidgets(
        'a take recorded over the tutorial elsewhere is not offered '
        'from the server', (tester) async {
      await export(tester, draftOf(said), {
        ...copied(),
        'follows': null,
        'takeId': 'abcdef0123456789',
      });
      expect(find.byKey(const Key('export-voice-recording')), findsNothing);
    });
  });
}

Directory _emptyDir() => Directory.systemTemp.createTempSync('no_take_');
