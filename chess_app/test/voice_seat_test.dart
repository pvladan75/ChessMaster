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

  group('token koji ističe usred časa', _tokenRefreshTests);
}

/// What happens to a voice channel an hour into a lesson.
///
/// The token is issued once, at join, and Agora stops accepting it when it
/// expires — so until 27.8.2026 a lesson longer than `AGORA_TOKEN_TTL_SECONDS`
/// simply lost its sound, with nothing in the log and nothing on the screen.
/// The decision is pinned here rather than the doing, because the doing needs an
/// engine, a lesson and an hour of waiting, and this is precisely the kind of
/// bug that survives a five-minute check.
void _tokenRefreshTests() {
  test('a room that refuses mid-lesson ends the call, it does not renew it',
      () {
    // Removed from the guest list while the lesson runs. Staying in the channel
    // until Agora happens to cut it would be a voice in a room that said no.
    expect(
      AgoraService.refreshAction(
        token: '',
        maySpeak: false,
        refused: 'Niste na spisku za ovu sobu.',
        currentMaySpeak: true,
      ),
      TokenRefresh.leave,
    );
  });

  test('no answer is asked again, never renewed with an empty token', () {
    // `renewToken('')` would drop the connection this call exists to keep.
    expect(
      AgoraService.refreshAction(
        token: '',
        maySpeak: true,
        refused: null,
        currentMaySpeak: true,
      ),
      TokenRefresh.retry,
    );
  });

  test('a right that changed is a rejoin, because the role is set at join', () {
    // `renewToken` swaps the token and nothing else: a student granted the
    // microphone would hold a publisher token as an audience member.
    expect(
      AgoraService.refreshAction(
        token: 'novi',
        maySpeak: true,
        refused: null,
        currentMaySpeak: false,
      ),
      TokenRefresh.rejoin,
    );
    expect(
      AgoraService.refreshAction(
        token: 'novi',
        maySpeak: false,
        refused: null,
        currentMaySpeak: true,
      ),
      TokenRefresh.rejoin,
    );
  });

  test('same seat, new token: renewed in place and nobody hears a gap', () {
    expect(
      AgoraService.refreshAction(
        token: 'novi',
        maySpeak: false,
        refused: null,
        currentMaySpeak: false,
      ),
      TokenRefresh.renew,
    );
    expect(
      AgoraService.refreshAction(
        token: 'novi',
        maySpeak: true,
        refused: null,
        currentMaySpeak: true,
      ),
      TokenRefresh.renew,
    );
  });
}
