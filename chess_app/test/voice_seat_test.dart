import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/services/agora_service.dart';

/// Who may be **heard** in a lesson.
///
/// The app used to decide this itself: it joined every channel as a broadcaster
/// with the microphone published, and a student was quiet only for as long as
/// the app chose to mute itself. The server now answers instead, and the answer
/// becomes the role in the Agora token — a subscriber token cannot publish audio
/// whatever client is holding it.
///
/// What is pinned here is the direction the app leans when the answer is not a
/// clear yes. A voice published on a guess is a child's voice in somebody's
/// recording, and `uploads/` is the one thing in this project that cannot be
/// reproduced or taken back.
void main() {
  final service = AgoraService();

  tearDown(() => AgoraService.httpClientOverride = null);

  void answerWith(int status, Map<String, dynamic> body) {
    AgoraService.httpClientOverride =
        MockClient((_) async => http.Response(jsonEncode(body), status));
  }

  test('the server decides, and the app carries the answer', () async {
    answerWith(200, {'token': 'abc', 'maySpeak': true, 'role': 'trener'});

    final seat = await service.voiceSeatFor('123456', 7, 'jwt');

    expect(seat.token, 'abc');
    expect(seat.maySpeak, isTrue);
    expect(seat.refused, isNull);
  });

  test('a listener is a listener even though a token came back', () async {
    // The token is still issued — they belong in the room and they hear the
    // lesson. It is a subscriber token, and the app must not treat "I got a
    // token" as "I may speak".
    answerWith(200, {'token': 'abc', 'maySpeak': false, 'role': 'ucenik'});

    final seat = await service.voiceSeatFor('123456', 9, 'jwt');

    expect(seat.token, 'abc');
    expect(seat.maySpeak, isFalse);
  });

  test('a room that says no is passed up, not swallowed', () async {
    // A refusal that reads as "povezivanje…" forever is the failure this project
    // keeps paying for.
    answerWith(403,
        {'error': 'Niste na spisku za ovu sobu.', 'reason': 'not-invited'});

    final seat = await service.voiceSeatFor('123456', 9, 'jwt');

    expect(seat.refused, 'Niste na spisku za ovu sobu.');
    expect(seat.maySpeak, isFalse);
  });

  test('an answer that never came is not a yes', () async {
    // The old code caught the error and joined anyway, publishing. Silence about
    // a right is not the right.
    AgoraService.httpClientOverride =
        MockClient((_) async => throw Exception('mreža'));

    final seat = await service.voiceSeatFor('123456', 9, 'jwt');

    expect(seat.maySpeak, isFalse);
    expect(seat.refused, isNull, reason: 'nije odbijen — samo se ne zna');
  });

  test('a missing field is not a yes either', () async {
    // A server that answers without saying anything about the microphone is an
    // older server, or a bug. Either way the answer is not "publish the child".
    answerWith(200, {'token': 'abc'});

    expect((await service.voiceSeatFor('123456', 9, 'jwt')).maySpeak, isFalse);
  });

  test('nobody signed in is never heard, and the network is not asked',
      () async {
    var asked = false;
    AgoraService.httpClientOverride = MockClient((_) async {
      asked = true;
      return http.Response('{}', 200);
    });

    final seat = await service.voiceSeatFor('123456', 9, '');

    expect(seat.maySpeak, isFalse);
    expect(seat.token, '');
    expect(asked, isFalse, reason: 'gost se ne pita za token');
  });
}
