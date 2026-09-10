// The trainer's recorded narration, on its way to the server — phase 3 of
// `docs/PLAN-SNIMANJE.md`, the app's half.
//
// Asserted on the request, because the request is the contract: the server
// reads `markersMs`, `durationMs`, `beats` and a file field called `audio`
// (`routes/lessons.js`, `saveNarration`), and a field that arrives under
// another name is a take refused for a reason nobody can see from the app.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';

void main() {
  late File take;

  setUp(() {
    final dir = Directory.systemTemp.createTempSync('narration_api_');
    take = File('${dir.path}${Platform.pathSeparator}take-ab12.wav')
      ..writeAsBytesSync(List<int>.filled(64, 7));
  });

  tearDown(() => take.parent.deleteSync(recursive: true));

  test('the take goes up with its beats, its length and its count', () async {
    late http.Request sent;
    final api = LessonApiService(
      authToken: 'tok',
      client: MockClient((request) async {
        sent = request;
        return http.Response(
          jsonEncode({
            'narration': {'ms': 1200, 'beats': 3, 'recordedAt': 'x'},
          }),
          201,
        );
      }),
    );

    final result = await api.uploadNarration(
      lessonId: 12,
      audioPath: take.path,
      markersMs: [0, 480, 880],
      durationMs: 1200,
      beats: 3,
      takeId: 'ab12',
    );

    expect(result.ok, isTrue);
    expect(result.ms, 1200);
    expect(result.beats, 3);

    expect(sent.method, 'POST');
    expect(sent.url.path, '/lessons/12/narration');
    expect(sent.headers['Authorization'], 'Bearer tok');
    final body = latin1.decode(sent.bodyBytes);
    expect(body, contains('name="markersMs"'));
    expect(body, contains('[0,480,880]'));
    expect(body, contains('name="durationMs"'));
    expect(body, contains('name="beats"'));
    expect(body, contains('name="takeId"'));
    expect(body, contains('name="audio"; filename="take.wav"'));
  });

  test('a refusal comes back as the server\'s own sentence', () async {
    const sentence = 'Nothing reached the microphone during this recording, '
        'so it is silent. Check the mute key and the input device, then '
        'record again.';
    final api = LessonApiService(
      authToken: 'tok',
      client: MockClient(
          (_) async => http.Response(jsonEncode({'error': sentence}), 422)),
    );

    final result = await api.uploadNarration(
      lessonId: 12,
      audioPath: take.path,
      markersMs: [0],
      durationMs: 80,
      beats: 1,
    );

    expect(result.ok, isFalse);
    expect(result.error, sentence);
  });
}
