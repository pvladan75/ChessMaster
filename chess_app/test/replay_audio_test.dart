// A lesson's sound on a phone — the owner's live pass of 22.9.2026.
//
// The student heard nothing on Android while the trainer heard the lesson on
// Windows. The phone's log said why: the player was handed the `http://` URL,
// Android's platform player opens it through the system's network stack, and
// that stack refuses unencrypted traffic the manifest does not allow — ten
// retries, then MEDIA_ERROR_UNKNOWN. The app's own requests go through Dart and
// were never refused, so the sound is now fetched by the app's client and the
// player is given a file (`downloadLessonAudio`).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/replay_player_screen.dart';
import 'package:chess_app/services/lesson_audio_download.dart';
import 'package:chess_app/theme/app_colors.dart';

const _sound = '/recordings/lesson-audio/lesson_1_ab.wav?token=signed-for-2';

Map<String, Object?> _row() => {
      'id': 5,
      'room_id': null,
      'source': 'preparation',
      'host_id': 1,
      'host_name': 'Vladan',
      'title': 'Lucena',
      'audio_url': _sound,
      'video_download_url': null,
      'duration_ms': 4000,
      'timeline_json': [
        {
          'timestampMs': 0,
          'eventType': 'init',
          'data': {'fen': '8/8/8/8/8/8/8/K6k w - - 0 1'}
        },
      ],
      'created_at': '2026-09-22T12:00:00.000Z',
    };

void main() {
  testWidgets('the sound is fetched through the app\'s own client',
      (tester) async {
    final asked = <Uri>[];
    final client = MockClient((req) async {
      asked.add(req.url);
      if (req.url.path == '/recordings/5') {
        return http.Response(jsonEncode(_row()), 200);
      }
      if (req.url.path.startsWith('/recordings/lesson-audio/')) {
        return http.Response.bytes(List.filled(64, 1), 200);
      }
      return http.Response('[]', 200);
    });
    final dir = Directory.systemTemp.createTempSync('replay_audio_');

    // The platform player, stood in for: every call it is asked to make. Its
    // event channels are answered too — one global, one per player, named by
    // the id the player's `create` call carries — or listening on them throws
    // before any of this is reached.
    final player = <MethodCall>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    final sinks = <String, MockStreamHandlerEventSink>{};
    void silentEvents(String name) {
      messenger.setMockStreamHandler(EventChannel(name),
          MockStreamHandler.inline(onListen: (_, sink) {
        sinks[name] = sink;
      }));
      addTearDown(
          () => messenger.setMockStreamHandler(EventChannel(name), null));
    }

    silentEvents('xyz.luan/audioplayers.global/events');
    for (final name in [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global'
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
        player.add(call);
        final args = call.arguments;
        if (call.method == 'create' && args is Map) {
          silentEvents('xyz.luan/audioplayers/events/${args['playerId']}');
        }
        // As the platform does: a source set is followed by „prepared", and
        // a seek by „seek complete" — `setSource` and `seek` wait for them.
        const answers = {
          'setSourceUrl': {'event': 'audio.onPrepared', 'value': true},
          'seek': {'event': 'audio.onSeekComplete'},
        };
        final answer = answers[call.method];
        if (answer != null && args is Map) {
          final events = 'xyz.luan/audioplayers/events/${args['playerId']}';
          Future<void>.microtask(() => sinks[events]?.success(answer));
        }
        return null;
      });
      addTearDown(
          () => messenger.setMockMethodCallHandler(MethodChannel(name), null));
    }

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData().copyWith(extensions: const [AppColorTokens.light]),
      home: ReplayPlayerScreen(
        recordingId: 5,
        userSession:
            UserSession(id: 2, token: 'tok', email: 'e', name: 'N', role: 'x'),
        client: client,
        audioDirectory: () async => dir,
      ),
    ));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }

    final sound = asked
        .where((u) => u.path == '/recordings/lesson-audio/lesson_1_ab.wav');
    expect(sound, hasLength(1),
        reason: 'the sound was not asked for through the app\'s client — '
            'a URL handed to the platform player is refused on Android');
    expect(sound.single.queryParameters['token'], 'signed-for-2',
        reason: 'the signed link lost its token on the way');

    // Play, then let the voice start: it must resume the source it has, not
    // set it again — on the phone that aborted a load still under way.
    await tester.tap(find.byIcon(Icons.play_arrow));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(player.map((c) => c.method), contains('resume'),
        reason: 'Play did not start the voice');
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();

    final sources = player.where((c) => c.method == 'setSourceUrl').toList();
    expect(sources, hasLength(1), reason: 'the source is set once');
    final args = sources.single.arguments as Map;
    expect(args['isLocal'], isTrue,
        reason: 'the platform player was handed a URL, not a file');
    expect(args['url'], startsWith(dir.path));
    await tester.pumpWidget(const SizedBox());
    // The screen deletes its file as it goes; the folder only after that.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await dir.delete(recursive: true);
    });
  });

  group('downloadLessonAudio', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('lesson_'));
    tearDown(() => dir.delete(recursive: true));

    test('writes what the server sent', () async {
      final client = MockClient(
          (req) async => http.Response.bytes([82, 73, 70, 70, 9], 200));
      final file = await downloadLessonAudio(
          client, Uri.parse('http://h/a.wav'), File('${dir.path}/a.wav'));
      expect(file, isNotNull);
      expect(await file!.readAsBytes(), [82, 73, 70, 70, 9]);
    });

    test('a refusal is no sound, and leaves no file', () async {
      final client = MockClient((req) async =>
          http.Response('{"error":"Invalid or expired download token"}', 403));
      final target = File('${dir.path}/b.wav');
      expect(
          await downloadLessonAudio(
              client, Uri.parse('http://h/b.wav'), target),
          isNull);
      expect(target.existsSync(), isFalse);
    });

    test('a dead network is no sound, not an exception', () async {
      final client =
          MockClient((req) async => throw const SocketException('down'));
      expect(
          await downloadLessonAudio(
              client, Uri.parse('http://h/c.wav'), File('${dir.path}/c.wav')),
          isNull);
    });
  });
}
