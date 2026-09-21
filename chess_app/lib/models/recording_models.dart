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
/// arrows drawn on it — phase 5b of `docs/PLAN-SESIJA.md`.
///
/// Pure, so the rule the player replays by has a test of its own; the server's
/// film reads the same timeline (`videoRenderer.applyEvent`), and the two must
/// agree about it (rule 13).
class ReplayFrame {
  const ReplayFrame({this.fen, this.orientation, this.arrows = const []});

  /// Null before anything has happened.
  final String? fen;
  final String? orientation;

  /// Each with `from`, `to` and `colorCode`.
  final List<Map<String, String>> arrows;
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
  var positionAt = -1;
  var arrowsAt = -1;
  List<dynamic> rawArrows = const [];
  for (var i = 0; i < events.length; i++) {
    final event = events[i];
    if (event.timestampMs > ms) break;
    if (_positionKinds.contains(event.eventType)) {
      final value = event.data['fen'];
      if (value is String) fen = value;
      positionAt = i;
    } else if (event.eventType == 'orientation_changed') {
      final value = event.data['orientation'];
      if (value is String) orientation = value;
    } else if (event.eventType == 'arrow_drawn') {
      final value = event.data['arrows'];
      rawArrows = value is List ? value : const [];
      arrowsAt = i;
    }
  }
  // Arrows belong to the position they were drawn on: a change of position
  // after them clears them. Judged by order, not by the clock — two events in
  // one millisecond are one audio chunk apart, and their order is what the
  // trainer did.
  final arrows = arrowsAt > positionAt
      ? [
          for (final a in rawArrows)
            if (a is Map)
              {
                'from': '${a['from'] ?? ''}',
                'to': '${a['to'] ?? ''}',
                // The film's key (`color`, what a tutorial and a lesson write)
                // and the room's (`colorCode`).
                'colorCode': '${a['colorCode'] ?? a['color'] ?? 'G'}',
              },
        ]
      : <Map<String, String>>[];
  return ReplayFrame(fen: fen, orientation: orientation, arrows: arrows);
}
