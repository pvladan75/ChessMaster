// Cases added beside the frozen gate `test/replay_transcript_test.dart` — the
// brief's own "Cases you add" for phase 7 of docs/PLAN-PRIPREMA.md, each
// watched red on the wrong code before green:
//
//  1. The client answers `[]`, `{}` and a 500 as "nothing to draw", and never
//     throws (rule 6/7: fake the client, assert on the seam, not only the
//     shape that happens to parse).
//  2. A room recording, read by its host at 360 x 640, is asked nothing and
//     draws no "Transcript" button either — the gate already proves a
//     student is asked nothing; this is the door the gate does not reach.
//  3. 400 sentences: the panel builds without drawing all 400 at once, a
//     scroll reaches the last one, and a tap on it still moves the player.
//
// Fixture text here is ASCII on purpose: `http.Response(String, ...)`
// defaults to latin1 when no header names a charset, and this suite must
// not depend on that default agreeing with the words it carries.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/replay_player_screen.dart';
import 'package:chess_app/services/recording_transcript_api.dart';
import 'package:chess_app/theme/app_colors.dart';

const _host = 1;

Map<String, Object?> _row({String source = 'preparation'}) => {
      'id': 5,
      'room_id': null,
      'source': source,
      'host_id': _host,
      'host_name': 'Vladan',
      'title': 'Italian Game',
      'audio_url': null,
      'video_download_url': null,
      'duration_ms': 95000,
      'timeline_json': [
        {
          'timestampMs': 0,
          'eventType': 'init',
          'data': {
            'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'
          }
        },
      ],
      'created_at': '2026-09-27T12:00:00.000Z',
    };

Future<void> _player(WidgetTester tester, http.Client client,
    {int me = _host, Size size = const Size(1200, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData().copyWith(extensions: const [AppColorTokens.light]),
    home: ReplayPlayerScreen(
      key: UniqueKey(),
      recordingId: 5,
      userSession:
          UserSession(id: me, token: 'tok', email: 'e', name: 'N', role: 'x'),
      client: client,
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

final _panel = find.byKey(const Key('replay-transcript-panel'));
final _openSheet = find.byKey(const Key('replay-transcript-open'));
Finder _sentence(int i) => find.byKey(Key('transcript-sentence-$i'));
Finder _clock(String mmss) => find.text(mmss);

void main() {
  group('the client on a malformed answer', () {
    test('a GET answering [] is nothing to draw, and does not throw', () async {
      final client = MockClient((req) async => http.Response('[]', 200));
      final api = RecordingTranscriptApi(authToken: 'tok', client: client);
      final result = await api.fetch(5);
      expect(result.available, isFalse);
      expect(result.languages, isEmpty);
      expect(result.transcript, isNull);
    });

    test('a GET answering {} is nothing to draw, and does not throw', () async {
      final client = MockClient((req) async => http.Response('{}', 200));
      final api = RecordingTranscriptApi(authToken: 'tok', client: client);
      final result = await api.fetch(5);
      expect(result.available, isFalse);
      expect(result.languages, isEmpty);
      expect(result.transcript, isNull);
    });

    test('a GET answering 500 is nothing to draw, and does not throw',
        () async {
      final client = MockClient(
          (req) async => http.Response(jsonEncode({'error': 'no'}), 500));
      final api = RecordingTranscriptApi(authToken: 'tok', client: client);
      final result = await api.fetch(5);
      expect(result.available, isFalse);
      expect(result.languages, isEmpty);
      expect(result.transcript, isNull);
    });

    test(
        'a POST answering something that is not the shape is a refusal, '
        'not a crash', () async {
      final client = MockClient((req) async => http.Response('[]', 200));
      final api = RecordingTranscriptApi(authToken: 'tok', client: client);
      final result = await api.transcribe(5, 'en');
      expect(result.ok, isFalse);
      expect(result.transcript, isNull);
      expect(result.error, isNotNull);
    });
  });

  group('a room recording read by its host', () {
    testWidgets(
        'at 360 x 640 asks the server nothing, and draws no Transcript '
        'button either', (tester) async {
      final gets = <http.Request>[];
      final client = MockClient((req) async {
        if (req.url.path == '/recordings/5') {
          return http.Response(jsonEncode(_row(source: 'room')), 200);
        }
        if (req.url.path == '/recordings/5/transcript') {
          gets.add(req);
        }
        return http.Response('[]', 200);
      });
      await _player(tester, client, size: const Size(360, 640));
      expect(gets, isEmpty,
          reason: 'a room recording is never asked about a transcript, '
              'host or not');
      expect(_panel, findsNothing);
      expect(_openSheet, findsNothing,
          reason: 'the deck\'s new button is absent for a room recording '
              'too, not only for a student');
      expect(tester.takeException(), isNull);
      await _close(tester);
    });
  });

  group('a long transcript', () {
    testWidgets(
        '400 sentences: the panel builds, scrolls to the last, and '
        'a tap on it moves the player', (tester) async {
      final sentences = [
        for (var i = 0; i < 400; i++)
          {
            'startMs': i * 1000,
            'endMs': i * 1000 + 800,
            'text': 'Sentence number $i.',
            'heard': 'Sentence number $i.',
          },
      ];
      final transcript = {
        'language': 'en',
        'vendor': 'groq',
        'model': 'whisper-large-v3',
        'durationMs': 400000,
        'sentences': sentences,
        'updatedAt': '2026-09-27T12:10:00.000Z',
      };
      final client = MockClient((req) async {
        if (req.url.path == '/recordings/5') {
          return http.Response(jsonEncode(_row()), 200);
        }
        if (req.url.path == '/recordings/5/transcript' && req.method == 'GET') {
          return http.Response(
              jsonEncode({
                'available': true,
                'languages': ['en'],
                'transcript': transcript,
              }),
              200);
        }
        return http.Response('[]', 200);
      });
      await _player(tester, client);
      expect(_panel, findsOneWidget);
      // Only some of the 400 are ever built at once — the point of the
      // ConstrainedBox + ListView.builder over a Column of 400 Text widgets.
      expect(_sentence(399), findsNothing);

      // Until the row is *visible*, not merely built: a list builds rows in
      // its cache band below the edge, and the first draft stopped there and
      // tapped a row that was mostly outside the list (grading, 27.9.2026 —
      // it passed only while the list was a fixed 420 px tall).
      final list = find.byKey(const Key('transcript-sentence-list'));
      await tester.scrollUntilVisible(_sentence(399), 500,
          maxScrolls: 200,
          scrollable:
              find.descendant(of: list, matching: find.byType(Scrollable)));
      await tester.pump();
      expect(_sentence(399), findsOneWidget);
      expect(tester.getRect(_sentence(399)).bottom,
          lessThanOrEqualTo(tester.getRect(list).bottom));

      await tester.tap(_sentence(399));
      await _settle(tester);
      // 399 * 1000 ms = 399 s = 6:39.
      expect(_clock('06:39'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _close(tester);
    });
  });
}
