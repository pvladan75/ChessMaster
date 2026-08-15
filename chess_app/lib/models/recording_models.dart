import 'dart:convert';

/// A stretch the recording was paused for, measured in wall-clock milliseconds
/// from the moment recording started.
///
/// Deliberately *not* on the same clock as [TimelineEvent.timestampMs], which
/// has paused time subtracted out. This one is the microphone's clock: Agora
/// offers no way to pause a recording, so it keeps capturing straight through a
/// pause and the resulting file still contains those seconds. These intervals
/// are what the server cuts out so the audio ends up the same length as the
/// board timeline.
class PauseInterval {
  final int startMs;
  final int endMs;

  const PauseInterval({required this.startMs, required this.endMs});

  int get durationMs => endMs - startMs;

  Map<String, dynamic> toJson() => {'startMs': startMs, 'endMs': endMs};

  factory PauseInterval.fromJson(Map<String, dynamic> json) => PauseInterval(
        startMs: json['startMs'] ?? 0,
        endMs: json['endMs'] ?? 0,
      );

  @override
  String toString() => 'PauseInterval($startMs..$endMs)';
}

class TimelineEvent {
  final int timestampMs;
  final String eventType; // 'init', 'move', 'fen_change', 'arrow_drawn', 'lesson_loaded', 'orientation_changed'
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
  final String? videoUrl;
  final List<TimelineEvent> timelineEvents;
  final DateTime createdAt;

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
  });

  factory SessionRecording.fromJson(Map<String, dynamic> json) {
    List<TimelineEvent> events = [];
    if (json['timeline_json'] != null) {
      dynamic raw = json['timeline_json'];
      if (raw is String) {
        raw = jsonDecode(raw);
      }
      if (raw is List) {
        events = raw.map((item) => TimelineEvent.fromJson(Map<String, dynamic>.from(item))).toList();
      }
    }

    return SessionRecording(
      id: json['id'] ?? 0,
      roomId: json['room_id'] ?? '',
      hostId: json['host_id'] ?? 0,
      hostName: json['host_name'] ?? 'Trener',
      title: json['title'] ?? 'Snimak časa',
      audioUrl: json['audio_url'],
      videoUrl: json['video_url'],
      timelineEvents: events,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
    );
  }
}
