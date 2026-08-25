import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:chess_app/constants.dart';
import 'package:chess_app/models/recording_models.dart';

class LocalRecordingService {
  static const String _prefsKey = 'local_session_recordings_list';

  /// Save recording instantly on client (< 50 milliseconds)
  static Future<Map<String, dynamic>> saveLocally({
    required String roomId,
    required String title,
    required List<TimelineEvent> events,
    List<PauseInterval> pauses = const [],
    String? audioPath,
    List<int>? participants,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String localId = 'local_${DateTime.now().millisecondsSinceEpoch}';

    final recItem = {
      'id': localId,
      'roomId': roomId,
      'title': title,
      'createdAt': DateTime.now().toIso8601String(),
      'timelineEvents': events.map((e) => e.toJson()).toList(),
      // Carried alongside the audio so the server can cut these stretches out
      // of it; the microphone ran straight through them.
      'pauseIntervals': pauses.map((p) => p.toJson()).toList(),
      'audioPath': audioPath,
      'participants': participants ?? [],
      'isSynced': false,
      'serverId': null,
      'serverAudioUrl': null,
    };

    final rawList = prefs.getStringList(_prefsKey) ?? [];
    rawList.insert(0, jsonEncode(recItem));
    await prefs.setStringList(_prefsKey, rawList);

    print(
        '[LOCAL_RECORDING] Recording "$title" saved instantly locally as $localId');
    return recItem;
  }

  /// Get all local recordings
  static Future<List<Map<String, dynamic>>> getLocalRecordings() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_prefsKey) ?? [];
    return rawList
        .map((str) => Map<String, dynamic>.from(jsonDecode(str)))
        .toList();
  }

  /// Sends everything still waiting on this device, and returns what the
  /// server had to say about it.
  ///
  /// The return value is the point. The server answers a save with a sentence —
  /// *„snimanje je zaustavljeno jer roditelj nije dozvolio snimanje"*, or that
  /// it could not check the consent at all — and until 25.8.2026 nothing in
  /// `lib/` read it: the reply was parsed for `recording` and thrown away. A
  /// warning composed by the server and read by nobody is this project's oldest
  /// failure, and here it was aimed at the one answer a parent actually gave.
  static Future<List<String>> syncPendingRecordings(String userToken) async {
    final notices = <String>[];
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_prefsKey) ?? [];
    if (rawList.isEmpty) return notices;

    List<Map<String, dynamic>> list = rawList
        .map((str) => Map<String, dynamic>.from(jsonDecode(str)))
        .toList();
    bool updated = false;

    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      if (item['isSynced'] == true) continue;
      // A recording the server refused is not one to keep offering it. Without
      // this it would be re-uploaded on every sync, forever, and the reason
      // would never reach anybody.
      if (item['syncRefused'] == true) continue;

      try {
        print(
            '[SYNC_RECORDING] Syncing local recording ${item['id']} to server...');
        final request = http.MultipartRequest(
            'POST', Uri.parse('$backendUrl/recordings/save'));
        request.headers['Authorization'] = 'Bearer $userToken';
        request.fields['roomId'] = item['roomId'] ?? '';
        request.fields['title'] = item['title'] ?? 'Snimak časa';
        request.fields['timelineJson'] =
            jsonEncode(item['timelineEvents'] ?? []);
        request.fields['pauseIntervals'] =
            jsonEncode(item['pauseIntervals'] ?? []);
        request.fields['participants'] = jsonEncode(item['participants'] ?? []);

        final String? audioPath = item['audioPath'];
        if (audioPath != null) {
          final audioFile = File(audioPath);
          if (await audioFile.exists()) {
            request.files.add(
                await http.MultipartFile.fromPath('audio', audioFile.path));
          }
        }

        final streamedRes =
            await request.send().timeout(const Duration(seconds: 120));
        final response = await http.Response.fromStream(streamedRes);

        if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          final serverRec = data['recording'];
          item['isSynced'] = true;
          if (serverRec != null) {
            item['serverId'] = serverRec['id'];
            item['serverAudioUrl'] = serverRec['audio_url'];
          }
          updated = true;
          print(
              '[SYNC_RECORDING] Local recording ${item['id']} synced to server!');
          // Saved, but not without a remark: the recording was cut short by a
          // parent's refusal, or the server could not check that refusal at
          // all. Either way it is the trainer's to know before they share it.
          final flagged = data['consentStopped'] == true ||
              data['consentUnverified'] == true;
          if (flagged && data['message'] is String) {
            item['serverNotice'] = data['message'];
            notices.add(data['message'] as String);
            print('[SYNC_RECORDING] Napomena servera: ${data['message']}');
          }
        } else if (response.statusCode == 403) {
          // The server refused it: somebody in that lesson is a child whose
          // parent has not agreed to a recording. It stays on this device — it
          // is the trainer's own — and it stops being offered to the server.
          String reason = 'Server je odbio snimak.';
          try {
            final data = jsonDecode(response.body);
            if (data is Map && data['error'] is String) {
              reason = data['error'] as String;
            }
          } catch (_) {
            // A body that is not JSON says nothing about why.
          }
          item['syncRefused'] = true;
          item['syncRefusedReason'] = reason;
          updated = true;
          notices.add('Server je odbio snimak: $reason '
              'Snimak ostaje na ovom uređaju.');
          print('[SYNC_RECORDING] Odbijen snimak ${item['id']}: $reason');
        }
      } catch (e) {
        print(
            '[SYNC_RECORDING_ERROR] Background sync failed for ${item['id']}: $e');
      }
    }

    if (updated) {
      final updatedRaw = list.map((item) => jsonEncode(item)).toList();
      await prefs.setStringList(_prefsKey, updatedRaw);
    }
    return notices;
  }
}
