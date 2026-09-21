import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/models/recording_models.dart';
import 'package:chess_app/services/app_logger.dart';

/// Whether this account may record a lesson, and for how long — asked before
/// the microphone opens, so a refusal is said before anybody has spoken.
class LessonRecordingPermit {
  const LessonRecordingPermit({
    required this.allowed,
    this.reason,
    this.maxMs,
  });

  final bool allowed;

  /// The server's sentence when it may not — a missing birth year, or an age.
  final String? reason;

  /// The server's cap (derived there from the render budget); never a copy.
  final int? maxMs;
}

/// What the server said to a recorded lesson.
class LessonUploadResult {
  const LessonUploadResult({required this.ok, this.id, this.error});

  final bool ok;
  final int? id;

  /// The server's own sentence when it refused, or the app's when it could
  /// not be reached. Either way the file stays on this device.
  final String? error;
}

/// A lesson recorded alone in Preparation — phase 5b.3 of
/// `docs/PLAN-SESIJA.md`. The server's half is `routes/recordings.js`
/// (`/recordings/lesson`, `/recordings/lesson-limits`).
class LessonRecordingApi {
  LessonRecordingApi({required this.authToken, http.Client? client})
      : _client = client ?? http.Client();

  final String authToken;
  final http.Client _client;

  Map<String, String> get _auth =>
      {if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken'};

  /// **A server that does not answer is a refusal with a reason**, not a
  /// permission: recording without knowing the cap is recording something the
  /// server may then turn away after half an hour.
  Future<LessonRecordingPermit> permit() async {
    try {
      final res = await _client
          .get(Uri.parse('$backendUrl/recordings/lesson-limits'),
              headers: _auth)
          .timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body is Map) {
        return LessonRecordingPermit(
          allowed: body['allowed'] == true,
          reason: body['reason'] as String?,
          maxMs: (body['maxMs'] as num?)?.toInt(),
        );
      }
      return LessonRecordingPermit(
        allowed: false,
        reason: body is Map && body['error'] is String
            ? body['error'] as String
            : 'The server could not say whether you may record.',
      );
    } catch (e) {
      AppLogger.log('[LessonRecording] Could not ask for limits: $e');
      return const LessonRecordingPermit(
        allowed: false,
        reason: 'The server did not answer, so recording cannot start.',
      );
    }
  }

  /// Sends the take. The server reads the wav's own header and judges the
  /// events against it (`services/lessonRecording.js`); a refusal comes back
  /// as its sentence.
  Future<LessonUploadResult> upload({
    required String audioPath,
    required String title,
    required List<TimelineEvent> events,
    required int durationMs,
  }) async {
    try {
      final request = http.MultipartRequest(
          'POST', Uri.parse('$backendUrl/recordings/lesson'));
      request.headers.addAll(_auth);
      request.fields['title'] = title;
      request.fields['durationMs'] = '$durationMs';
      request.fields['events'] =
          jsonEncode([for (final e in events) e.toJson()]);
      // Read whole: a file streamed from disk is asynchronous I/O that a
      // widget test's clock never lets finish (the narration's upload).
      request.files.add(http.MultipartFile.fromBytes(
          'audio', File(audioPath).readAsBytesSync(),
          filename: 'lesson.wav'));
      final streamed =
          await _client.send(request).timeout(const Duration(minutes: 5));
      final res = await http.Response.fromStream(streamed);
      final body = res.body.isEmpty ? null : jsonDecode(res.body);
      if (res.statusCode == 201 && body is Map && body['recording'] is Map) {
        return LessonUploadResult(
          ok: true,
          id: ((body['recording'] as Map)['id'] as num?)?.toInt(),
        );
      }
      return LessonUploadResult(
        ok: false,
        error: body is Map && body['error'] is String
            ? body['error'] as String
            : 'The recording could not be uploaded (${res.statusCode}).',
      );
    } catch (e) {
      AppLogger.log('[LessonRecording] Upload failed: $e');
      return const LessonUploadResult(
          ok: false, error: 'Cannot connect to server.');
    }
  }
}
