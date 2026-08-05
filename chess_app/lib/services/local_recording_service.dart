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
    String? audioPath,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String localId = 'local_${DateTime.now().millisecondsSinceEpoch}';

    final recItem = {
      'id': localId,
      'roomId': roomId,
      'title': title,
      'createdAt': DateTime.now().toIso8601String(),
      'timelineEvents': events.map((e) => e.toJson()).toList(),
      'audioPath': audioPath,
      'isSynced': false,
      'serverId': null,
      'serverAudioUrl': null,
    };

    final rawList = prefs.getStringList(_prefsKey) ?? [];
    rawList.insert(0, jsonEncode(recItem));
    await prefs.setStringList(_prefsKey, rawList);

    print('[LOCAL_RECORDING] Recording "$title" saved instantly locally as $localId');
    return recItem;
  }

  /// Get all local recordings
  static Future<List<Map<String, dynamic>>> getLocalRecordings() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_prefsKey) ?? [];
    return rawList.map((str) => Map<String, dynamic>.from(jsonDecode(str))).toList();
  }

  /// Non-blocking background sync to server
  static Future<void> syncPendingRecordings(String userToken) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_prefsKey) ?? [];
    if (rawList.isEmpty) return;

    List<Map<String, dynamic>> list = rawList.map((str) => Map<String, dynamic>.from(jsonDecode(str))).toList();
    bool updated = false;

    for (int i = 0; i < list.length; i++) {
      final item = list[i];
      if (item['isSynced'] == true) continue;

      try {
        print('[SYNC_RECORDING] Syncing local recording ${item['id']} to server...');
        final request = http.MultipartRequest('POST', Uri.parse('$backendUrl/recordings/save'));
        request.headers['Authorization'] = 'Bearer $userToken';
        request.fields['roomId'] = item['roomId'] ?? '';
        request.fields['title'] = item['title'] ?? 'Snimak časa';
        request.fields['timelineJson'] = jsonEncode(item['timelineEvents'] ?? []);

        final String? audioPath = item['audioPath'];
        if (audioPath != null) {
          final audioFile = File(audioPath);
          if (await audioFile.exists()) {
            request.files.add(await http.MultipartFile.fromPath('audio', audioFile.path));
          }
        }

        final streamedRes = await request.send().timeout(const Duration(seconds: 120));
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
          print('[SYNC_RECORDING] Local recording ${item['id']} synced to server!');
        }
      } catch (e) {
        print('[SYNC_RECORDING_ERROR] Background sync failed for ${item['id']}: $e');
      }
    }

    if (updated) {
      final updatedRaw = list.map((item) => jsonEncode(item)).toList();
      await prefs.setStringList(_prefsKey, updatedRaw);
    }
  }
}
