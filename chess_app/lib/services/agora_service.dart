import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:chess_app/constants.dart';

/// What an expiring Agora token turns into once the server has been asked again.
///
/// Four answers rather than one, because "get a new token" is only correct when
/// nothing else changed: the room can refuse in the middle of a lesson, the
/// right to speak can be granted or taken back while it runs, and the server can
/// fail to answer at all — and none of those is a token swap.
enum TokenRefresh { renew, rejoin, leave, retry }

class AgoraService {
  static final AgoraService _instance = AgoraService._internal();
  factory AgoraService() => _instance;
  AgoraService._internal();

  /// Override per build with --dart-define=AGORA_APP_ID=...
  /// The default is the App ID this project has always shipped with; it is not a
  /// secret (App IDs are public by design), but the App Certificate on the server
  /// is what actually protects channels. See /agora/token on the backend.
  static const String appId = String.fromEnvironment(
    'AGORA_APP_ID',
    defaultValue: "7e604da275014643839b616702e1c0d2",
  );
  RtcEngine? _engine;
  bool _isInitialized = false;
  bool _isJoined = false;
  bool _isMuted = false;

  /// What the server said in this channel: may this person be heard at all.
  ///
  /// Different from [_isMuted], which is a choice made during a lesson and can
  /// be undone. This one is a right, and while it is false the app holds a
  /// subscriber token that cannot publish audio however the buttons are pressed.
  bool _maySpeak = false;

  /// The join this service is currently holding, kept so an expiring token can
  /// be replaced without the screen having to remember anything.
  ///
  /// A token is issued once, at join, and lives `AGORA_TOKEN_TTL_SECONDS`
  /// (an hour by default). Nothing renewed it until 27.8.2026, so a lesson
  /// longer than the TTL lost its voice in the middle — quietly, an hour after
  /// the mistake, which is the shape of failure this project keeps paying for.
  String? _channelId;
  int? _uid;
  String _userToken = '';

  /// Set while a refresh is waiting to be tried again. Cancelled on leave, so a
  /// timer cannot wake up and renew a channel nobody is in.
  Timer? _renewRetry;
  int _renewAttempts = 0;

  /// How many times a refresh that got no answer is retried, and how long it
  /// waits. Agora warns 30 s ahead, so three tries eight seconds apart all fall
  /// inside the window the warning opens.
  static const int _maxRenewAttempts = 3;
  static const Duration _renewRetryDelay = Duration(seconds: 8);

  // uids of active speakers (volume > 0)
  final Set<int> _activeSpeakers = {};

  Function(Set<int> activeSpeakers)? onActiveSpeakersChanged;
  Function(bool isMuted)? onMuteStateChanged;
  Function(bool isJoined, String? error)? onJoinStateChanged;

  bool get isJoined => _isJoined;
  bool get isMuted => _isMuted;
  bool get maySpeak => _maySpeak;

  Future<void> initAgora() async {
    if (_isInitialized) return;
    try {
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(const RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            _isJoined = true;
            if (onJoinStateChanged != null) {
              onJoinStateChanged!(true, null);
            }
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            // A remote user joined
          },
          // Thirty seconds' notice, which is the whole reason this can be done
          // without anyone noticing. Not awaited: the callback returns at the
          // first await inside anyway, and blocking an SDK callback on an HTTP
          // round trip is its own bug.
          onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
            unawaited(_refreshVoiceToken());
          },
          // The token is already gone — the notice above was missed or its
          // refresh never landed. Attempts start over, because this is a new
          // occasion and not a continuation of the failed one.
          onRequestToken: (RtcConnection connection) {
            _renewAttempts = 0;
            unawaited(_refreshVoiceToken());
          },
          onUserOffline: (RtcConnection connection, int remoteUid,
              UserOfflineReasonType reason) {
            _activeSpeakers.remove(remoteUid);
            if (onActiveSpeakersChanged != null) {
              onActiveSpeakersChanged!(_activeSpeakers);
            }
          },
          onAudioVolumeIndication: (RtcConnection connection,
              List<AudioVolumeInfo> speakers,
              int speakerNumber,
              int totalVolume) {
            final oldActive = Set<int>.from(_activeSpeakers);
            _activeSpeakers.clear();
            for (var speaker in speakers) {
              if (speaker.volume != null && speaker.volume! > 5) {
                // speaker.uid == 0 means local speaker
                final uid =
                    speaker.uid == 0 ? connection.localUid : speaker.uid;
                if (uid != null) {
                  _activeSpeakers.add(uid);
                }
              }
            }
            if (onActiveSpeakersChanged != null &&
                !_setEquals(oldActive, _activeSpeakers)) {
              onActiveSpeakersChanged!(_activeSpeakers);
            }
          },
        ),
      );

      // Enable audio volume indication
      await _engine!.enableAudioVolumeIndication(
        interval: 250,
        smooth: 3,
        reportVad: true,
      );

      _isInitialized = true;
    } catch (e) {
      print("Failed to initialize Agora RTC engine: $e");
    }
  }

  bool _setEquals(Set<int> a, Set<int> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }

  /// Asks the backend who this user is in this channel.
  ///
  /// Two answers come back, and the second one is new: the token, and **whether
  /// this person may be heard**. The microphone stopped being the app's decision
  /// on 25.8.2026 — a student who may only listen is joined as an *audience*
  /// member with a subscriber token, which cannot publish audio whatever the
  /// client does with it. Muting oneself is a courtesy; a subscriber token is a
  /// rule.
  ///
  /// The token is empty when the server has no App Certificate configured, which
  /// keeps the previous tokenless behaviour working. `maySpeak` is still
  /// honoured then — it is just advice at that point, since anybody holding the
  /// App ID could join the channel anyway. That is a server configuration
  /// problem and the server says so in its own answer.
  ///
  /// `refused` means the room said no. It is passed up rather than swallowed:
  /// a refusal that reads as "povezivanje…" forever is the failure this project
  /// keeps paying for.
  /// Stands in for the network in tests. The seat this returns decides whether
  /// a child's microphone is published, which is worth being able to test
  /// without a phone, a lesson and an Agora account.
  @visibleForTesting
  static http.Client? httpClientOverride;

  @visibleForTesting
  Future<({String token, bool maySpeak, String? refused})> voiceSeatFor(
          String channelId, int uid, String userToken) =>
      _fetchVoiceSeat(channelId, uid, userToken);

  Future<({String token, bool maySpeak, String? refused})> _fetchVoiceSeat(
      String channelId, int uid, String userToken) async {
    // Nobody signed in: a guest listens. There is no version of "unknown" that
    // means "may be heard".
    if (userToken.isEmpty) return (token: '', maySpeak: false, refused: null);

    try {
      final uri = Uri.parse('$backendUrl/agora/token');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $userToken',
      };
      final body = jsonEncode({'channelName': channelId, 'uid': uid});
      final client = httpClientOverride;
      final res = await (client == null
              ? http.post(uri, headers: headers, body: body)
              : client.post(uri, headers: headers, body: body))
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final token = data['token'];
        if (data['warning'] != null) {
          print('[AGORA] ${data['warning']}');
        }
        return (
          token: token is String ? token : '',
          maySpeak: data['maySpeak'] == true,
          refused: null,
        );
      }

      if (res.statusCode == 403) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return (
          token: '',
          maySpeak: false,
          refused: data['error'] as String? ?? 'Niste na spisku za ovu sobu.',
        );
      }

      print('[AGORA] Token request failed with status ${res.statusCode}');
    } catch (e) {
      print('[AGORA] Token request error: $e');
    }

    // No answer. Joining silently is the safe direction — a voice published on
    // a guess is a voice in somebody's recording — and the screen says the right
    // was not confirmed rather than pretending it was refused.
    return (token: '', maySpeak: false, refused: null);
  }

  /// Joins the lesson's voice channel in the seat the **server** gives.
  ///
  /// The order matters and it is the opposite of what it used to be: ask first,
  /// then join. Before, the app set itself up as a broadcaster, asked for the
  /// microphone, and only then fetched a token — so the answer arrived after the
  /// decision it was supposed to make.
  ///
  /// A listener is joined as `clientRoleAudience` and the microphone is never
  /// requested at all. That is the part worth keeping: a child who only listens
  /// is never asked for a permission they have no use for, and nothing on the
  /// device is ever in a position to publish their voice.
  Future<bool> joinChannel(String channelId, int uid,
      {String userToken = ''}) async {
    try {
      if (_isJoined) {
        await leaveChannel();
      }
      await initAgora();
      if (_engine == null) return false;

      final seat = await _fetchVoiceSeat(channelId, uid, userToken);
      if (seat.refused != null) {
        onJoinStateChanged?.call(false, seat.refused);
        return false;
      }
      _maySpeak = seat.maySpeak;

      // Remembered here rather than at the top: a refused join holds nothing to
      // refresh later.
      _channelId = channelId;
      _uid = uid;
      _userToken = userToken;
      _renewAttempts = 0;

      // Asked for only where it will be used. A listener joins without ever
      // seeing the microphone dialog.
      if (seat.maySpeak && !kIsWeb) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) {
          // Not a refusal by the room: they may speak, the phone says no. They
          // still belong in the lesson, so they join as a listener instead of
          // being turned away from it.
          _maySpeak = false;
          onJoinStateChanged?.call(false, 'Nije odobrena dozvola za mikrofon.');
        }
      }

      final role = _maySpeak
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience;

      await _engine!.setClientRole(role: role);
      await _engine!.enableAudio();

      await _engine!.joinChannel(
        token: seat.token,
        channelId: channelId,
        uid: uid,
        options: ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: _maySpeak,
          clientRoleType: role,
        ),
      );

      // A listener is not "muted": muting is something you can undo, and this is
      // not. The two are kept apart so no screen offers a button that cannot
      // work.
      _isMuted = !_maySpeak;
      return true;
    } catch (e) {
      print("Error joining Agora channel: $e");
      if (onJoinStateChanged != null) {
        onJoinStateChanged!(false, e.toString());
      }
      return false;
    }
  }

  /// What to do with a seat fetched to replace an expiring token.
  ///
  /// Kept apart from the doing so it can be tested without an Agora engine, a
  /// lesson and an hour of waiting — the bug this exists for only shows itself
  /// after the TTL runs out, which is exactly the kind of thing nobody notices
  /// in a five-minute check.
  @visibleForTesting
  static TokenRefresh refreshAction({
    required String token,
    required bool maySpeak,
    required String? refused,
    required bool currentMaySpeak,
  }) {
    // The room said no while the lesson was running — removed from the guest
    // list, relationship ended. The honest answer is out of the channel, said
    // out loud, rather than a voice that stays until Agora happens to cut it.
    if (refused != null) return TokenRefresh.leave;

    // No answer, or a server with no App Certificate. Handing Agora an empty
    // token would drop the connection this call exists to keep, so the only
    // thing left is to ask again.
    if (token.isEmpty) return TokenRefresh.retry;

    // The right itself changed. `renewToken` swaps the token and nothing else —
    // the client role is set at join, so a student who was granted the
    // microphone would hold a publisher token as an audience member, and a
    // student who lost it would keep publishing until the channel ends.
    if (maySpeak != currentMaySpeak) return TokenRefresh.rejoin;

    return TokenRefresh.renew;
  }

  /// Replaces the token this join is holding, before Agora stops accepting it.
  Future<void> _refreshVoiceToken() async {
    final channelId = _channelId;
    final uid = _uid;
    if (_engine == null || channelId == null || uid == null) return;

    final seat = await _fetchVoiceSeat(channelId, uid, _userToken);
    switch (refreshAction(
      token: seat.token,
      maySpeak: seat.maySpeak,
      refused: seat.refused,
      currentMaySpeak: _maySpeak,
    )) {
      case TokenRefresh.leave:
        await leaveChannel();
        onJoinStateChanged?.call(false, seat.refused);
        return;
      case TokenRefresh.rejoin:
        await joinChannel(channelId, uid, userToken: _userToken);
        return;
      case TokenRefresh.renew:
        try {
          await _engine!.renewToken(seat.token);
          _renewAttempts = 0;
        } catch (e) {
          print('[AGORA] renewToken failed: $e');
          _scheduleRenewRetry();
        }
        return;
      case TokenRefresh.retry:
        _scheduleRenewRetry();
        return;
    }
  }

  /// Asks again, a bounded number of times.
  ///
  /// When the tries run out the channel is **left alone**: a server that cannot
  /// be reached is not a room that refused, and the voice keeps working until
  /// Agora itself ends it — at which point `onRequestToken` starts this over.
  void _scheduleRenewRetry() {
    _renewRetry?.cancel();
    if (_renewAttempts >= _maxRenewAttempts) {
      print('[AGORA] Token refresh gave up after $_renewAttempts attempts.');
      return;
    }
    _renewAttempts++;
    _renewRetry =
        Timer(_renewRetryDelay, () => unawaited(_refreshVoiceToken()));
  }

  Future<void> toggleMute(bool mute) async {
    if (_engine == null) return;
    // Un-muting somebody who holds a subscriber token would do nothing at the
    // Agora end and everything on the screen: the button would light up, the
    // roster would say they are speaking, and nobody would hear them. Refused
    // here so the lie is never drawn.
    if (!mute && !_maySpeak) return;
    try {
      await _engine!.muteLocalAudioStream(mute);
      _isMuted = mute;
      if (onMuteStateChanged != null) {
        onMuteStateChanged!(_isMuted);
      }
    } catch (e) {
      print("Error toggling mute: $e");
    }
  }

  Future<void> leaveChannel() async {
    // Before the engine check, and unconditionally: a timer that outlives the
    // channel would wake up and renew a seat nobody is sitting in.
    _renewRetry?.cancel();
    _renewRetry = null;
    _renewAttempts = 0;
    _channelId = null;
    _uid = null;

    if (_engine == null) return;
    try {
      if (_isJoined) {
        await _engine!.leaveChannel();
        _isJoined = false;
        _isMuted = false;
        _activeSpeakers.clear();
        if (onJoinStateChanged != null) {
          onJoinStateChanged!(false, null);
        }
      }
    } catch (e) {
      print("Error leaving Agora channel: $e");
    }
  }

  Future<bool> startAudioRecording(String filePath) async {
    if (_engine == null) return false;
    try {
      await _engine!.startAudioRecording(AudioRecordingConfiguration(
        filePath: filePath,
        sampleRate: 16000,
        quality: AudioRecordingQualityType.audioRecordingQualityMedium,
      ));
      return true;
    } catch (e) {
      print("Error starting Agora audio recording: $e");
      return false;
    }
  }

  Future<void> stopAudioRecording() async {
    if (_engine == null) return;
    try {
      await _engine!.stopAudioRecording();
    } catch (e) {
      print("Error stopping Agora audio recording: $e");
    }
  }
}
