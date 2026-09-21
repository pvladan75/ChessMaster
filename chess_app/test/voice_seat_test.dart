import 'dart:convert';

import 'package:agora_rtc_engine/agora_rtc_engine.dart'
    show
        ClientRoleOptions,
        ClientRoleType,
        ConnectionChangedReasonType,
        LocalAudioStreamReason,
        LocalAudioStreamState,
        RtcEngine,
        RtcEngineContext,
        RtcEngineEventHandler;
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
  group('a voice that does not start says why', _failureReasonTests);
}

/// **A join that fails names its reason** — phase 4 of `docs/PLAN-SESIJA.md`.
///
/// Until 21.9.2026 two failures were a `print` and nothing else: a server that
/// did not answer was joined anyway, as a listener holding an empty token, and
/// an engine that could not be created returned `false` with no word — the
/// panel flipped back to „Turn on voice" as though the button had not been
/// pressed.
void _failureReasonTests() {
  final service = AgoraService();

  tearDown(() {
    AgoraService.httpClientOverride = null;
    AgoraService.engineFactoryOverride = null;
    service.onJoinStateChanged = null;
  });

  /// Everything the screen was told, in order.
  List<(bool, String?)> listen() {
    final said = <(bool, String?)>[];
    service.onJoinStateChanged = (joined, err) => said.add((joined, err));
    return said;
  }

  test('no answer is a failure, and it is not a refusal', () async {
    AgoraService.httpClientOverride =
        MockClient((_) async => throw Exception('mreža'));

    final seat = await service.voiceSeatFor('123456', 9, 'jwt');

    expect(seat.failure, isNotNull);
    expect(seat.refused, isNull);
    expect(seat.maySpeak, isFalse);
  });

  test('an answer that is neither yes nor no is a failure with its status',
      () async {
    AgoraService.httpClientOverride =
        MockClient((_) async => http.Response('{"error":"x"}', 500));

    final seat = await service.voiceSeatFor('123456', 9, 'jwt');

    expect(seat.failure, contains('500'));
    expect(seat.refused, isNull);
  });

  test('an empty token from a server that answered is not a failure', () async {
    // A server with no App Certificate answers 200 with no token, and that is
    // a working setup. The boundary this file stands on: the token is empty in
    // both cases, and only one of them is a failure.
    AgoraService.httpClientOverride = MockClient((_) async =>
        http.Response(jsonEncode({'token': null, 'maySpeak': true}), 200));

    final seat = await service.voiceSeatFor('123456', 9, 'jwt');

    expect(seat.token, '');
    expect(seat.failure, isNull);
    expect(seat.maySpeak, isTrue);
  });

  test('a silent server stops the join, says so, and no engine is started',
      () async {
    var enginesAsked = 0;
    AgoraService.engineFactoryOverride = () {
      enginesAsked++;
      throw StateError('engine must not be asked for');
    };
    AgoraService.httpClientOverride =
        MockClient((_) async => throw Exception('mreža'));
    final said = listen();

    final joined = await service.joinChannel('123456', 9, userToken: 'jwt');

    expect(joined, isFalse);
    expect(said, [
      (false, 'Voice could not start: the server did not answer.'),
    ]);
    expect(enginesAsked, 0,
        reason: 'the seat is asked for before the engine is started');
  });

  test('a refusal is still the room\'s own sentence, and no engine is started',
      () async {
    var enginesAsked = 0;
    AgoraService.engineFactoryOverride = () {
      enginesAsked++;
      throw StateError('engine must not be asked for');
    };
    AgoraService.httpClientOverride = MockClient((_) async => http.Response(
        jsonEncode({'error': 'This session has ended.', 'reason': 'ended'}),
        403));
    final said = listen();

    final joined = await service.joinChannel('123456', 9, userToken: 'jwt');

    expect(joined, isFalse);
    expect(said, [(false, 'This session has ended.')]);
    expect(enginesAsked, 0);
  });

  test('an engine that starts and then fails the join says that too', () async {
    // The one failure the cases above cannot reach: everything came up, and
    // the join itself threw. It used to be said as a raw `toString()`.
    AgoraService.engineFactoryOverride = () => _EngineThatFailsToJoin();
    addTearDown(service.forgetEngineForTest);
    AgoraService.httpClientOverride = MockClient((_) async =>
        http.Response(jsonEncode({'token': 'abc', 'maySpeak': false}), 200));
    final said = listen();

    final joined = await service.joinChannel('123456', 9, userToken: 'jwt');

    expect(joined, isFalse);
    expect(said, [(false, 'Voice could not start: the channel is busy.')]);
  });

  group('a microphone that does not work', () {
    // On Windows `permission_handler` answers "granted" whatever is plugged
    // in, so a join with no microphone looked exactly like a working one: the
    // button lit up, the roster said "speaking", and nobody heard a word. The
    // only witness is Agora's own local-audio state.
    String? said(LocalAudioStreamState state, LocalAudioStreamReason reason) =>
        AgoraService.microphoneProblemFor(state, reason);

    test('no device is said as what it means for the person', () {
      expect(
        said(LocalAudioStreamState.localAudioStreamStateFailed,
            LocalAudioStreamReason.localAudioStreamReasonNoRecordingDevice),
        'Others cannot hear you: no microphone was found.',
      );
    });

    test('busy and forbidden are different sentences, because the cure differs',
        () {
      final busy = said(LocalAudioStreamState.localAudioStreamStateFailed,
          LocalAudioStreamReason.localAudioStreamReasonDeviceBusy);
      final forbidden = said(LocalAudioStreamState.localAudioStreamStateFailed,
          LocalAudioStreamReason.localAudioStreamReasonDeviceNoPermission);
      expect(busy, contains('another app'));
      expect(forbidden, contains('allow'));
      expect(busy, isNot(forbidden));
    });

    test('a missing speaker is not a microphone problem', () {
      expect(
        said(LocalAudioStreamState.localAudioStreamStateFailed,
            LocalAudioStreamReason.localAudioStreamReasonNoPlayoutDevice),
        startsWith('You cannot hear the session:'),
      );
    });

    test('every failure has a sentence, and a working microphone has none', () {
      for (final reason in LocalAudioStreamReason.values) {
        expect(said(LocalAudioStreamState.localAudioStreamStateFailed, reason),
            isNotEmpty,
            reason: reason.name);
      }
      // The state decides, not the reason: Agora reports the last reason again
      // beside a stream that has since started.
      for (final state in LocalAudioStreamState.values) {
        if (state == LocalAudioStreamState.localAudioStreamStateFailed) {
          continue;
        }
        expect(
            said(state,
                LocalAudioStreamReason.localAudioStreamReasonNoRecordingDevice),
            isNull,
            reason: state.name);
      }
    });
  });

  test('a channel Agora drops has a sentence, whatever the reason', () {
    expect(
      AgoraService.connectionFailureText(
          ConnectionChangedReasonType.connectionChangedInvalidToken),
      'the voice service did not accept this seat',
    );
    expect(
      AgoraService.connectionFailureText(
          ConnectionChangedReasonType.connectionChangedJoinFailed),
      'the voice service could not be reached',
    );
    // Every reason the SDK has, today's and tomorrow's: never blank, and never
    // the same words for "set up wrong" as for "the network dropped".
    for (final reason in ConnectionChangedReasonType.values) {
      expect(AgoraService.connectionFailureText(reason), isNotEmpty,
          reason: reason.name);
    }
    expect(
      AgoraService.connectionFailureText(
          ConnectionChangedReasonType.connectionChangedLost),
      contains('connectionChangedLost'),
    );
  });

  test('an engine that cannot be created is said, with its own reason',
      () async {
    AgoraService.engineFactoryOverride =
        () => throw StateError('no audio device');
    AgoraService.httpClientOverride = MockClient((_) async =>
        http.Response(jsonEncode({'token': 'abc', 'maySpeak': false}), 200));
    final said = listen();

    final joined = await service.joinChannel('123456', 9, userToken: 'jwt');

    expect(joined, isFalse);
    expect(said, hasLength(1));
    expect(said.single.$1, isFalse);
    expect(said.single.$2, startsWith('Voice could not start:'));
    expect(said.single.$2, contains('no audio device'));
  });
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

/// Comes up like a real engine and refuses at the first call of the join.
class _EngineThatFailsToJoin extends Fake implements RtcEngine {
  @override
  Future<void> initialize(RtcEngineContext context) async {}

  @override
  void registerEventHandler(covariant RtcEngineEventHandler eventHandler) {}

  @override
  Future<void> enableAudioVolumeIndication(
      {required int interval,
      required int smooth,
      required bool reportVad}) async {}

  @override
  Future<void> setClientRole(
          {required ClientRoleType role, ClientRoleOptions? options}) =>
      throw StateError('the channel is busy');
}
