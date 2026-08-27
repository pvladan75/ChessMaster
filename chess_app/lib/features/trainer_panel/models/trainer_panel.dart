/// The trainer's day, as the server answers it.
///
/// One model for one endpoint: the sections are drawn together and go stale
/// together, so they are parsed together rather than as five lists that could
/// disagree about which minute they describe.
class TrainerPanel {
  final List<PanelLesson> today;
  final List<PanelAssignment> dueSoon;
  final List<PanelAssignment> awaitingReview;

  /// Homework that has stopped moving — with a deadline still far off, or with
  /// none at all. Without this section an assignment nobody set a date for was
  /// invisible everywhere, and one that stalled halfway vanished from [idle]
  /// the moment the student solved their first puzzle.
  final List<PanelAssignment> stalled;

  final List<PanelIdleStudent> idle;

  /// What the tab badge shows: work the trainer can clear by acting.
  final int waiting;

  const TrainerPanel({
    this.today = const [],
    this.dueSoon = const [],
    this.awaitingReview = const [],
    this.stalled = const [],
    this.idle = const [],
    this.waiting = 0,
  });

  /// Nothing to show and nothing waiting — the state of anybody who teaches
  /// nobody, which is most people who open this app.
  static const TrainerPanel empty = TrainerPanel();

  /// Whether the panel has anything to draw at all.
  ///
  /// A trainer with students but a quiet day gets no panel rather than a stack
  /// of empty headings: a heading over nothing reads as a screen that failed to
  /// load.
  bool get isEmpty =>
      today.isEmpty &&
      dueSoon.isEmpty &&
      awaitingReview.isEmpty &&
      stalled.isEmpty &&
      idle.isEmpty;

  factory TrainerPanel.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) =>
        ((json[key] as List?) ?? const [])
            .map((e) => parse(Map<String, dynamic>.from(e as Map)))
            .toList();

    final counts = Map<String, dynamic>.from(
        (json['counts'] as Map?) ?? const <String, dynamic>{});

    return TrainerPanel(
      today: list('today', PanelLesson.fromJson),
      dueSoon: list('dueSoon', PanelAssignment.fromJson),
      awaitingReview: list('awaitingReview', PanelAssignment.fromJson),
      stalled: list('stalled', PanelAssignment.fromJson),
      idle: list('idle', PanelIdleStudent.fromJson),
      waiting: (counts['waiting'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A lesson this trainer is hosting today.
class PanelLesson {
  final int id;
  final String roomCode;
  final String title;

  /// Whoever was invited and has not declined. Names rather than ids: the row
  /// exists to be read, and the trainer knows their students by name.
  final List<String> guests;

  final DateTime? scheduledAt;

  const PanelLesson({
    required this.id,
    required this.roomCode,
    required this.title,
    this.guests = const [],
    this.scheduledAt,
  });

  factory PanelLesson.fromJson(Map<String, dynamic> json) => PanelLesson(
        id: (json['id'] as num?)?.toInt() ?? 0,
        roomCode: json['room_code']?.toString() ?? '',
        title: json['title']?.toString() ?? 'Čas',
        guests: ((json['guests'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        scheduledAt: _parseDate(json['scheduled_at']),
      );
}

/// One piece of homework, seen from the trainer's side.
///
/// The same class for both sections: a deadline and a hand-in are the same row
/// read at two moments, and splitting them would mean two parsers for one
/// endpoint's one shape.
class PanelAssignment {
  final int id;
  final String title;
  final int studentId;
  final String studentName;
  final int totalItems;
  final int attemptedItems;
  final int solvedItems;
  final DateTime? dueAt;
  final DateTime? completedAt;

  /// The last time anything happened to this homework — the student's most
  /// recent answer, or when it was set if there has never been one. Only the
  /// stalled section fills it in.
  final DateTime? lastMoveAt;

  const PanelAssignment({
    required this.id,
    required this.title,
    required this.studentId,
    required this.studentName,
    this.totalItems = 0,
    this.attemptedItems = 0,
    this.solvedItems = 0,
    this.dueAt,
    this.completedAt,
    this.lastMoveAt,
  });

  factory PanelAssignment.fromJson(Map<String, dynamic> json) =>
      PanelAssignment(
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: json['title']?.toString() ?? 'Zadatak',
        studentId: (json['student_id'] as num?)?.toInt() ?? 0,
        studentName: json['student_name']?.toString() ?? 'Učenik',
        totalItems: (json['total_items'] as num?)?.toInt() ?? 0,
        attemptedItems: (json['attempted_items'] as num?)?.toInt() ?? 0,
        solvedItems: (json['solved_items'] as num?)?.toInt() ?? 0,
        dueAt: _parseDate(json['due_at']),
        completedAt: _parseDate(json['completed_at']),
        lastMoveAt: _parseDate(json['last_move_at']),
      );
}

/// A student who has not solved anything for a while.
class PanelIdleStudent {
  final int id;
  final String name;

  /// Null when they have never attempted anything at all — a longer silence
  /// than any number of days, and the one the panel puts first.
  final DateTime? lastActiveAt;

  const PanelIdleStudent({
    required this.id,
    required this.name,
    this.lastActiveAt,
  });

  factory PanelIdleStudent.fromJson(Map<String, dynamic> json) =>
      PanelIdleStudent(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name']?.toString() ?? 'Učenik',
        lastActiveAt: _parseDate(json['last_active_at']),
      );
}

/// A timestamp, or null if it is missing or unparseable.
///
/// Local time, not UTC: every date on this panel is read as "today", and a
/// lesson at 17:00 displayed as 15:00 would be worse than no lesson at all.
DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}
