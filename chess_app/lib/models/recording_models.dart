import 'dart:convert';

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
