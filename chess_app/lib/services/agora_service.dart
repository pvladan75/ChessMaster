import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:chess_app/constants.dart';

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
