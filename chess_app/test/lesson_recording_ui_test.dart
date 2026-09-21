// Recording a lesson in Preparation — phase 5b.3 of docs/PLAN-SESIJA.md.
//
// A trainer alone at their own board presses „Start recording", talks, plays and
// steps through a line, stops, names it, and the server gets the voice with the
// board's events stamped on the audio's own clock (`lesson_take.dart`). The
// microphone is a fake that hands over chunks of a known size, and the server a
// MockClient that keeps the request — so what is asserted is what would be
// sent (rule 7), and every timestamp is arithmetic the reader can redo.
//
// Real font (rule 8): with the test font the room's right column overflows.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/tutorial_studio/services/narration_take.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/chess_game_screen.dart';
import 'package:chess_app/services/lesson_recording_api.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';

import 'support/landscape.dart' show loadRoboto, expectOnScreen, sizeLabel;

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const _refusal =
    'Recording requires entering your birth year — only adults may record their voice.';

final _record = find.byKey(const Key('prep-record-lesson'));
final _strip = find.byKey(const Key('lesson-recording-strip'));
final _stop = find.byKey(const Key('lesson-recording-stop'));
final _pause = find.byKey(const Key('lesson-recording-pause'));
final _discard = find.byKey(const Key('lesson-recording-discard'));

class _Mic implements PcmSource {
  final controller = StreamController<Uint8List>();
  bool started = false;

  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<Stream<Uint8List>> start() async {
    started = true;
    return controller.stream;
  }

  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}

  /// [ms] of audio at 32 bytes a millisecond, loud enough to count as live.
  void speak(int ms) {
    final bytes = Uint8List(ms * 32);
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      data.setInt16(i, 8000, Endian.little);
    }
    controller.add(bytes);
  }
}

class _Server {
  _Server({this.allowed = true, List<int>? uploadStatuses})
      : uploadStatuses = uploadStatuses ?? [201];

  final bool allowed;
  final List<int> uploadStatuses;
  final uploads = <http.Request>[];
  int limitsAsked = 0;

  late final client = MockClient((req) async {
    final path = req.url.path;
    if (path.endsWith('/library/positions')) {
      return http.Response(
          jsonEncode({
            'items': [
              {
                'kind': 'position',
                'id': '12',
                'title': 'Lucena',
                'fen': _start,
                'pgn': '1. e4 e5 2. Nf3',
                'fromTrainer': false,
              },
            ]
          }),
          200);
    }
    if (path == '/recordings/lesson-limits') {
      limitsAsked++;
      // As Express sends JSON: UTF-8, and saying so. `http.Response(String)`
      // encodes latin1, which cannot carry the refusal's dash.
      return http.Response.bytes(
          utf8.encode(jsonEncode({
            'allowed': allowed,
            'reason': allowed ? null : _refusal,
            'maxMs': 60000,
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    if (path == '/recordings/lesson' && req.method == 'POST') {
      uploads.add(req);
      final status = uploadStatuses.length > 1
          ? uploadStatuses.removeAt(0)
          : uploadStatuses.first;
      return status == 201
          ? http.Response(
              jsonEncode({
                'recording': {'id': 88, 'title': 'x'}
              }),
              201)
          : http.Response(
              jsonEncode({'error': 'The server is out of space.'}), status);
    }
    return http.Response('[]', 200);
  });
}

/// A field of a multipart body, read as text.
String _field(http.Request req, String name) {
  final body = latin1.decode(req.bodyBytes);
  final start = body.indexOf('name="$name"');
  expect(start, isNot(-1), reason: 'no field $name in the upload');
  final from = body.indexOf('\r\n\r\n', start) + 4;
  final to = body.indexOf('\r\n--', from);
  return utf8.decode(latin1.encode(body.substring(from, to)));
}

Future<(_Mic, Directory)> _studio(WidgetTester tester, _Server server,
    {Size size = const Size(1400, 900), String roomCode = 'STUDIO'}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final mic = _Mic();
  final dir = Directory.systemTemp.createTempSync('lesson-ui-');
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(fontFamily: 'Roboto')
        .copyWith(extensions: const [AppColorTokens.light]),
    home: ChessGamePage(
      userSession:
          UserSession(id: 1, token: 'tok', email: 'e', name: 'N', role: 'x'),
      roomCode: roomCode,
      initialRole: 'trener',
      lessonApi: LessonApiService(authToken: 'tok', client: server.client),
      positionLibrary:
          PositionLibraryService(authToken: 'tok', client: server.client),
      groupApi: GroupApiService(client: server.client),
      lessonRecordingApi:
          LessonRecordingApi(authToken: 'tok', client: server.client),
      pcmSourceFactory: () => mic,
      lessonTakeDir: () async => dir,
    ),
  ));
  await tester.pump(const Duration(seconds: 1));
  return (mic, dir);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

List<File> _takes(Directory dir) => dir
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.wav'))
    .toList();

Future<void> _startRecording(WidgetTester tester) async {
  await tester.tap(_record);
  await _settle(tester);
}

Future<void> _saveAs(WidgetTester tester, String title) async {
  await tester.tap(_stop);
  await _settle(tester);
  await tester.enterText(find.byKey(const Key('lesson-title-field')), title);
  await tester.tap(find.byKey(const Key('lesson-save')));
  await _settle(tester);
  await _settle(tester);
}

void main() {
  setUpAll(loadRoboto);

  testWidgets('Preparation offers „Start recording", a room does not',
      (tester) async {
    await _studio(tester, _Server());
    expect(_record, findsOneWidget);
    await tester.pumpWidget(const SizedBox());

    await _studio(tester, _Server(), roomCode: '192803');
    expect(_record, findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a refusal is said before the microphone opens', (tester) async {
    final server = _Server(allowed: false);
    final (mic, dir) = await _studio(tester, server);
    await _startRecording(tester);
    expect(server.limitsAsked, 1);
    expect(find.text(_refusal), findsOneWidget);
    expect(_strip, findsNothing);
    expect(mic.started, isFalse);
    expect(_takes(dir), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'a lesson goes to the server with the board stamped on the audio\'s clock',
      (tester) async {
    final server = _Server();
    final (mic, dir) = await _studio(tester, server);
    await _startRecording(tester);
    expect(_strip, findsOneWidget);
    expect(mic.started, isTrue);

    mic.speak(1000);
    await _settle(tester);
    expect(find.descendant(of: _strip, matching: find.text('0:01')),
        findsOneWidget);

    // The trainer's own path: a position from the Library, then a step.
    await tester.tap(find.text('Lucena'));
    await _settle(tester);
    await tester.tap(find.byTooltip('Next move').first);
    await _settle(tester);
    mic.speak(500);
    await _settle(tester);

    await _saveAs(tester, 'Lucena, bridge');

    expect(server.uploads, hasLength(1));
    final req = server.uploads.single;
    expect(req.headers['Authorization'], 'Bearer tok');
    expect(_field(req, 'title'), 'Lucena, bridge');
    expect(_field(req, 'durationMs'), '1500');
    final events = jsonDecode(_field(req, 'events')) as List;
    expect([for (final e in events) e['eventType']], ['init', 'init', 'move']);
    expect([for (final e in events) e['timestampMs']], [0, 1000, 1000]);
    expect(events[1]['data']['fen'], _start);
    expect(events[2]['data']['fen'], isNot(_start),
        reason: 'the step is a new position');
    expect(latin1.decode(req.bodyBytes), contains('name="audio"'));

    expect(_strip, findsNothing);
    expect(_takes(dir), isEmpty,
        reason: 'the take leaves the device once the server has it');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a failed upload keeps the take and offers to try again',
      (tester) async {
    final server = _Server(uploadStatuses: [507, 201]);
    final (mic, dir) = await _studio(tester, server);
    await _startRecording(tester);
    mic.speak(800);
    await _settle(tester);
    await _saveAs(tester, 'Rook endings');

    expect(find.text('The server is out of space.'), findsOneWidget);
    expect(_takes(dir), hasLength(1), reason: 'the only copy of a voice');
    await tester.tap(find.byKey(const Key('lesson-upload-retry')));
    await _settle(tester);
    await _settle(tester);
    expect(server.uploads, hasLength(2));
    expect(_takes(dir), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('discard sends nothing and keeps nothing', (tester) async {
    final server = _Server();
    final (mic, dir) = await _studio(tester, server);
    await _startRecording(tester);
    mic.speak(500);
    await _settle(tester);
    await tester.tap(_discard);
    await _settle(tester);
    expect(_strip, findsNothing);
    expect(server.uploads, isEmpty);
    expect(_takes(dir), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('back does not leave while a lesson is recording',
      (tester) async {
    // The take is the only copy of a voice; a back press used to be where a
    // recording was lost without a word. Preparation is a pushed route in the
    // app, so it is one here: with the page as the only route, back is the
    // system's and not the page's to refuse.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final server = _Server();
    final mic = _Mic();
    final dir = Directory.systemTemp.createTempSync('lesson-ui-');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      theme: ThemeData(fontFamily: 'Roboto')
          .copyWith(extensions: const [AppColorTokens.light]),
      home: const Scaffold(body: Text('HOME')),
    ));
    unawaited(navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => ChessGamePage(
        userSession:
            UserSession(id: 1, token: 'tok', email: 'e', name: 'N', role: 'x'),
        roomCode: 'STUDIO',
        initialRole: 'trener',
        lessonApi: LessonApiService(authToken: 'tok', client: server.client),
        positionLibrary:
            PositionLibraryService(authToken: 'tok', client: server.client),
        groupApi: GroupApiService(client: server.client),
        lessonRecordingApi:
            LessonRecordingApi(authToken: 'tok', client: server.client),
        pcmSourceFactory: () => mic,
        lessonTakeDir: () async => dir,
      ),
    )));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await _startRecording(tester);
    mic.speak(300);
    await _settle(tester);

    await navigator.currentState!.maybePop();
    await _settle(tester);
    expect(_strip, findsOneWidget, reason: 'still in Preparation');
    expect(find.text('HOME'), findsNothing);
    expect(find.text('Stop or discard the recording first.'), findsOneWidget);

    await tester.tap(_discard);
    await _settle(tester);
    await navigator.currentState!.maybePop();
    await _settle(tester);
    expect(find.text('HOME'), findsOneWidget,
        reason: 'with the take gone, back leaves as always');
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(seconds: 60)));

  for (final size in [const Size(360, 640), const Size(760, 360)]) {
    testWidgets('the strip fits at ${sizeLabel(size)}', (tester) async {
      final server = _Server();
      final (mic, _) = await _studio(tester, server, size: size);
      await _startRecording(tester);
      mic.speak(300);
      await _settle(tester);
      expect(tester.takeException(), isNull);
      for (final button in [_pause, _stop, _discard]) {
        expectOnScreen(tester, size, button);
        final rect = tester.getRect(button);
        expect(rect.width >= 40 && rect.height >= 40, isTrue,
            reason: '$button is ${rect.size}');
      }
      final board = tester.getRect(find.byType(BoardWithCoordinates).first);
      expect(board.width, closeTo(board.height, 0.01));
      expect(
          (Offset.zero & size).contains(board.bottomRight - const Offset(1, 1)),
          isTrue);
      await tester.tap(_discard);
      await _settle(tester);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
