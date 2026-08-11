import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  
  // uids of active speakers (volume > 0)
  final Set<int> _activeSpeakers = {};
  
  Function(Set<int> activeSpeakers)? onActiveSpeakersChanged;
  Function(bool isMuted)? onMuteStateChanged;
  Function(bool isJoined, String? error)? onJoinStateChanged;

  bool get isJoined => _isJoined;
  bool get isMuted => _isMuted;

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
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            _activeSpeakers.remove(remoteUid);
            if (onActiveSpeakersChanged != null) {
              onActiveSpeakersChanged!(_activeSpeakers);
            }
          },
          onAudioVolumeIndication: (RtcConnection connection, List<AudioVolumeInfo> speakers, int speakerNumber, int totalVolume) {
            final oldActive = Set<int>.from(_activeSpeakers);
            _activeSpeakers.clear();
            for (var speaker in speakers) {
              if (speaker.volume != null && speaker.volume! > 5) {
                // speaker.uid == 0 means local speaker
                final uid = speaker.uid == 0 ? connection.localUid : speaker.uid;
                if (uid != null) {
                  _activeSpeakers.add(uid);
                }
              }
            }
            if (onActiveSpeakersChanged != null && !_setEquals(oldActive, _activeSpeakers)) {
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

  /// Asks the backend for a channel-scoped RTC token.
  ///
  /// Returns an empty string when the server has no App Certificate configured,
  /// which keeps the previous tokenless behaviour working. Once the certificate is
  /// set server-side, every join is authenticated without any client change.
  Future<String> _fetchRtcToken(String channelId, int uid, String userToken) async {
    if (userToken.isEmpty) return '';
    try {
      final res = await http
          .post(
            Uri.parse('$backendUrl/agora/token'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $userToken',
            },
            body: jsonEncode({'channelName': channelId, 'uid': uid}),
          )
          .timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final token = data['token'];
        if (token is String && token.isNotEmpty) return token;
        if (data['warning'] != null) {
          print('[AGORA] ${data['warning']}');
        }
      } else {
        print('[AGORA] Token request failed with status ${res.statusCode}');
      }
    } catch (e) {
      print('[AGORA] Token request error, joining without token: $e');
    }
    return '';
  }

  Future<bool> joinChannel(String channelId, int uid, {String userToken = ''}) async {
    try {
      if (_isJoined) {
        await leaveChannel();
      }
      await initAgora();
      if (_engine == null) return false;

      bool permissionGranted = true;
      if (!kIsWeb) {
        final status = await Permission.microphone.request();
        permissionGranted = status.isGranted;
      }

      if (!permissionGranted) {
        if (onJoinStateChanged != null) {
          onJoinStateChanged!(false, "Nije odobrena dozvola za mikrofon.");
        }
        return false;
      }

      // Set client role to broadcaster
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      
      // Enable audio
      await _engine!.enableAudio();

      final rtcToken = await _fetchRtcToken(channelId, uid, userToken);

      await _engine!.joinChannel(
        token: rtcToken,
        channelId: channelId,
        uid: uid,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
      
      _isMuted = false;
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
