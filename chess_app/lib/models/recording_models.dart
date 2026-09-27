import 'dart:convert';

class TimelineEvent {
  final int timestampMs;
  final String
      eventType; // 'init', 'move', 'fen_change', 'arrow_drawn', 'lesson_loaded', 'orientation_changed'
  final Map<String, dynamic> data;

  TimelineEvent({
    required this.timestampMs,
    required this.eventType,
    required this.data,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestampMs': timestampMs,
      'eventType': eventType,
      'data': data,
    };
  }

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    return TimelineEvent(
      timestampMs: json['timestampMs'] ?? 0,
      eventType: json['eventType'] ?? 'move',
      data: json['data'] is Map<String, dynamic>
          ? json['data']
          : Map<String, dynamic>.from(json['data'] ?? {}),
    );
  }
}

class SessionRecording {
  final int id;
  final String roomId;
  final int hostId;
  final String hostName;
  final String title;
  final String? audioUrl;

  /// The latest render, signed for this reader and only while it is still on
  /// the server's disk (`video_download_url`, phase 5b.5) — never the stored
  /// link, which carries the host's token.
  final String? videoUrl;
  final List<TimelineEvent> timelineEvents;
  final DateTime createdAt;

  /// `room` or `preparation`; only the second is shared with students.
  final String source;

  /// The audio's length, when the recording knows it — a lesson recorded in
  /// Preparation does, and plays to the end of its voice rather than its last
  /// move.
  final int? durationMs;

  SessionRecording({
    required this.id,
    required this.roomId,
    required this.hostId,
    required this.hostName,
    required this.title,
    this.audioUrl,
    this.videoUrl,
    required this.timelineEvents,
    required this.createdAt,
    this.source = 'room',
    this.durationMs,
  });

  factory SessionRecording.fromJson(Map<String, dynamic> json) {
    List<TimelineEvent> events = [];
    if (json['timeline_json'] != null) {
      dynamic raw = json['timeline_json'];
      if (raw is String) {
        raw = jsonDecode(raw);
      }
      if (raw is List) {
        events = raw
            .map((item) =>
                TimelineEvent.fromJson(Map<String, dynamic>.from(item)))
            .toList();
      }
    }

    return SessionRecording(
      id: json['id'] ?? 0,
      roomId: json['room_id'] ?? '',
      source: json['source'] as String? ?? 'room',
      durationMs: (json['duration_ms'] as num?)?.toInt(),
      hostId: json['host_id'] ?? 0,
      hostName: json['host_name'] ?? 'Trainer',
      title: json['title'] ?? 'Session recording',
      audioUrl: json['audio_url'],
      videoUrl: json['video_download_url'] as String?,
      timelineEvents: events,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}

/// What a replay shows at one moment: the board, which way it faces, and the
/// arrows and squares marked on it — phase 5b of `docs/PLAN-SESIJA.md`, and
/// phase 3 of `docs/PLAN-PRIPREMA.md` for the squares.
///
/// Pure, so the rule the player replays by has a test of its own; the server's
/// film reads the same timeline (`videoRenderer.applyEvent`), and the two must
/// agree about it (rule 13). They are held to one fixture,
/// `chess_backend/test/fixtures/lesson_timeline.json`.
class ReplayFrame {
  const ReplayFrame({
    this.fen,
    this.orientation,
    this.arrows = const [],
    this.squares = const [],
  });

  /// Null before anything has happened.
  final String? fen;
  final String? orientation;

  /// Each with `from`, `to` and `colorCode`.
  final List<Map<String, String>> arrows;

  /// Each with `square` and `colorCode`.
  final List<Map<String, String>> squares;
}

/// Every kind that puts a position on the board. `init` is one of them, and
/// the latest wins **whatever its kind**: a lesson recorded in Preparation
/// writes `init` each time the trainer loads a new position, and the player
/// used to prefer any earlier `move` to it. `fen_change` and `lesson_loaded`
/// are the room's, kept so its recordings still replay.
const _positionKinds = {'init', 'move', 'fen_change', 'lesson_loaded'};

ReplayFrame replayFrameAt(List<TimelineEvent> events, int ms) {
  String? fen;
  String? orientation;
  List<dynamic> rawArrows = const [];
  List<dynamic> rawSquares = const [];
  for (final event in events) {
    if (event.timestampMs > ms) break;
    if (event.eventType == 'orientation_changed') {
      final value = event.data['orientation'];
      if (value is String) orientation = value;
      continue;
    }
    final position = _positionKinds.contains(event.eventType);
    if (!position && event.eventType != 'arrow_drawn') continue;
    if (position) {
      final value = event.data['fen'];
      if (value is String) fen = value;
    }
    // **The marks are what the latest event said, whatever its kind** — the
    // film's rule (`applyEvent`), word for word. An event that names no
    // arrows has none, so a change of position clears what was drawn on the
    // one before it; and a jump to a move that holds marks of its own brings
    // them, which until phase 3 of `docs/PLAN-PRIPREMA.md` the player dropped
    // and the film drew. Read in the order written, not by the clock: two
    // events in one millisecond are one audio chunk apart, and their order is
    // what the trainer did.
    final arrows = event.data['arrows'];
    rawArrows = arrows is List ? arrows : const [];
    final squares = event.data['squares'];
    rawSquares = squares is List ? squares : const [];
  }
  return ReplayFrame(
    fen: fen,
    orientation: orientation,
    arrows: [
      for (final a in rawArrows)
        if (a is Map)
          {
            'from': '${a['from'] ?? ''}',
            'to': '${a['to'] ?? ''}',
            // The film's key (`color`, what a tutorial and a lesson write)
            // and the room's (`colorCode`).
            'colorCode': '${a['colorCode'] ?? a['color'] ?? 'G'}',
          },
    ],
    squares: [
      for (final s in rawSquares)
        if (s is Map)
          {
            'square': '${s['square'] ?? ''}',
            'colorCode': '${s['colorCode'] ?? s['color'] ?? 'G'}',
          },
    ],
  );
}
