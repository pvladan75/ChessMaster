import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/models/recording_transcript.dart';
import 'package:chess_app/services/app_logger.dart';

/// What the server offers for a recording's transcript — never a crash, never
/// a message: an answer that is not the shape the server promises is „no
/// transcript, not offered", the same rule the player already applies to
/// every unknown path (rule 6: a fixture that is shorter, simpler or luckier
/// than the real thing cannot fail, so this is proved on `[]`, `{}` and a 500,
/// not only on the shape that happens to parse).
class TranscriptAvailability {
  const TranscriptAvailability({
    this.available = false,
    this.languages = const [],
    this.transcript,
  });

  final bool available;
  final List<String> languages;
  final RecordingTranscript? transcript;
}

/// The result of asking for a transcript, or a correction to be saved: the
/// transcript the server now holds, or its own sentence when it refused.
class TranscriptOutcome {
  const TranscriptOutcome.ok(RecordingTranscript this.transcript)
      : error = null;
  const TranscriptOutcome.failed(String this.error) : transcript = null;

  final RecordingTranscript? transcript;
  final String? error;

  bool get ok => transcript != null;
}

/// The one client for `chess_backend/routes/recordingTranscript.js` — beside
/// `lesson_recording_api.dart`. Takes the player's `http.Client` (rule 7: fake
/// the client, not the method) so a test can assert on the request the same
/// way it does for sharing and the video export.
class RecordingTranscriptApi {
  RecordingTranscriptApi({required this.authToken, required http.Client client})
      : _client = client;

  final String authToken;
  final http.Client _client;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (authToken.isNotEmpty) 'Authorization': 'Bearer $authToken',
      };

  Uri _uri(int recordingId) =>
      Uri.parse('$backendUrl/recordings/$recordingId/transcript');

  /// `GET /recordings/:id/transcript`. Anything that is not the server's own
  /// shape reads as nothing offered, so the player is left as it was rather
  /// than shown a crash.
  Future<TranscriptAvailability> fetch(int recordingId) async {
    try {
      final res = await _client
          .get(_uri(recordingId), headers: _headers)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return const TranscriptAvailability();
      final body = jsonDecode(res.body);
      if (body is! Map) return const TranscriptAvailability();
      final rawLanguages = body['languages'];
      final languages = rawLanguages is List
          ? rawLanguages.whereType<String>().toList()
          : const <String>[];
      final rawTranscript = body['transcript'];
      RecordingTranscript? transcript;
      if (rawTranscript is Map) {
        try {
          transcript = RecordingTranscript.fromJson(
              Map<String, Object?>.from(rawTranscript));
        } catch (e) {
          AppLogger.log('[Transcript] Could not read the transcript: $e');
        }
      }
      return TranscriptAvailability(
        available: body['available'] == true,
        languages: languages,
        transcript: transcript,
      );
    } catch (e) {
      AppLogger.log('[Transcript] Could not ask for the transcript: $e');
      return const TranscriptAvailability();
    }
  }

  /// `POST /recordings/:id/transcript` — the sound is heard in the chosen
  /// [language]. Takes seconds to minutes, so the caller holds the button
  /// rather than the player.
  Future<TranscriptOutcome> transcribe(int recordingId, String language) async {
    try {
      final res = await _client
          .post(_uri(recordingId),
              headers: _headers, body: jsonEncode({'language': language}))
          .timeout(const Duration(minutes: 2));
      return _readWrite(res);
    } catch (e) {
      AppLogger.log('[Transcript] Transcribe failed: $e');
      return const TranscriptOutcome.failed('Cannot connect to server.');
    }
  }

  /// `PUT /recordings/:id/transcript` — every sentence's text, corrected or
  /// not; nothing else is read from the body. Times cannot be edited.
  Future<TranscriptOutcome> correct(int recordingId, List<String> texts) async {
    try {
      final res = await _client
          .put(_uri(recordingId),
              headers: _headers, body: jsonEncode({'texts': texts}))
          .timeout(const Duration(seconds: 30));
      return _readWrite(res);
    } catch (e) {
      AppLogger.log('[Transcript] Correction failed: $e');
      return const TranscriptOutcome.failed('Cannot connect to server.');
    }
  }

  TranscriptOutcome _readWrite(http.Response res) {
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Handled below: no body worth reading is a refusal too.
    }
    if ((res.statusCode == 200 || res.statusCode == 201) &&
        body != null &&
        body['transcript'] is Map) {
      try {
        return TranscriptOutcome.ok(RecordingTranscript.fromJson(
            Map<String, Object?>.from(body['transcript'] as Map)));
      } catch (e) {
        AppLogger.log('[Transcript] Could not read the answer: $e');
      }
    }
    final message = body != null && body['error'] is String
        ? body['error'] as String
        : 'The server refused (${res.statusCode}).';
    return TranscriptOutcome.failed(message);
  }
}
