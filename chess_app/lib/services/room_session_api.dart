import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants.dart';

/// What the server says about a room the app remembers.
enum RoomState {
  /// Still a session, and this account may walk in.
  live,

  /// The trainer ended it, or started another.
  ended,

  /// No such room, or not one this account may enter. The server does not say
  /// which, so that an answer never confirms a code exists.
  notYours,
}

/// A session the account could walk into now: [trainerName] is in it.
class LiveSession {
  const LiveSession({required this.roomCode, required this.trainerName});

  final String roomCode;
  final String trainerName;
}

/// The two questions a session's lifecycle adds (`docs/PLAN-SESIJA.md`, phase
/// 1): is the room I remember still there, and — for the trainer — end it.
///
/// Until 21.9.2026 a room never ended. The app kept a saved „active session"
/// until somebody pressed Leave, blocked every other room while it was set, and
/// offered only the way back into it — which is how the owner sat alone in a
/// room from an old invitation while his student sat alone in the new one.
class RoomSessionApi {
  RoomSessionApi({required this.authToken, http.Client? client})
      : _client = client ?? http.Client();

  final String authToken;
  final http.Client _client;

  Map<String, String> get _headers => {'Authorization': 'Bearer $authToken'};

  /// **Null means the server could not be asked** — offline, a timeout, a 500,
  /// a body that is not an answer. That is not „ended": a session must not be
  /// forgotten because the phone was in a tunnel when Home opened.
  Future<RoomState?> state(String roomCode) async {
    try {
      final res = await _client
          .get(Uri.parse('$backendUrl/rooms/$roomCode/state'),
              headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body);
      return switch (body is Map ? body['state'] : null) {
        'live' => RoomState.live,
        'ended' => RoomState.ended,
        'not-yours' => RoomState.notYours,
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }

  /// The sessions of the people who teach this account, running now
  /// (`GET /rooms/live`). What replaced typing a room code.
  ///
  /// Empty when the server could not be asked. Here that is the honest
  /// drawing: Home shows a block only when it has rows, and an invitation or
  /// the next load still gets the student in.
  Future<List<LiveSession>> live() async {
    try {
      final res = await _client
          .get(Uri.parse('$backendUrl/rooms/live'), headers: _headers)
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return const [];
      final body = jsonDecode(res.body);
      final rows = body is Map ? body['sessions'] : null;
      return [
        for (final row in rows is List ? rows : const [])
          if (row is Map && row['roomCode'] is String)
            LiveSession(
              roomCode: row['roomCode'] as String,
              trainerName: '${row['trainerName'] ?? 'Your trainer'}',
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// Ends the caller's own session for everybody in it. True when the server
  /// answered — whether this call ended it or it was over already, the room is
  /// not live afterwards, which is what the caller wants to know.
  Future<bool> end(String roomCode) async {
    try {
      final res = await _client
          .post(Uri.parse('$backendUrl/rooms/$roomCode/end'), headers: _headers)
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
