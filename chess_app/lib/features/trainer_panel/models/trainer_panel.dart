/// The trainer's day, as the server answers it.
///
/// One model for one endpoint: the sections are drawn together and go stale
/// together, so they are parsed together rather than as five lists that could
/// disagree about which minute they describe.
class TrainerPanel {
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

  /// Relationship requests nobody has answered — the other half of [waiting],
  /// carried so the badge can say what its number is made of rather than have
  /// the reader subtract two lists.
  final int requests;

  const TrainerPanel({
    this.dueSoon = const [],
    this.awaitingReview = const [],
    this.stalled = const [],
    this.idle = const [],
    this.waiting = 0,
    this.requests = 0,
  });

  /// What the badge on „Teach" is counting, in words, or null when it is not
  /// drawn at all.
  ///
  /// Reported live on 18.9.2026 (TODO-provera 177.6): „Ne razumem ovu
  /// notifikaciju na tabu Teach gde piše 1". The number was right — one piece
  /// of homework handed in and not opened — and said so nowhere. A badge
  /// nobody can read is a badge that gets ignored, which is the opposite of
  /// what it is for.
  String? get waitingExplanation {
    if (waiting <= 0) return null;
    final toReview = awaitingReview.length;
    final parts = <String>[
      if (toReview > 0)
        toReview == 1
            ? '1 homework to review'
            : '$toReview homeworks to review',
      if (requests > 0)
        requests == 1 ? '1 request to answer' : '$requests requests to answer',
    ];
    // The server's number is the one the badge shows, so a count it explains
    // with nothing — a section this client does not know about — still says
    // something rather than nothing.
    if (parts.isEmpty) return '$waiting waiting for you';
    return parts.join(' · ');
  }

  /// Nothing to show and nothing waiting — the state of anybody who teaches
  /// nobody, which is most people who open this app.
  static const TrainerPanel empty = TrainerPanel();

  /// Whether the panel has anything to draw at all.
  ///
  /// A trainer with students but a quiet day gets no panel rather than a stack
  /// of empty headings: a heading over nothing reads as a screen that failed to
  /// load.
  bool get isEmpty =>
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
      dueSoon: list('dueSoon', PanelAssignment.fromJson),
      awaitingReview: list('awaitingReview', PanelAssignment.fromJson),
      stalled: list('stalled', PanelAssignment.fromJson),
      idle: list('idle', PanelIdleStudent.fromJson),
      waiting: (counts['waiting'] as num?)?.toInt() ?? 0,
      requests: (counts['requests'] as num?)?.toInt() ?? 0,
    );
  }
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
        title: json['title']?.toString() ?? 'Assignment',
        studentId: (json['student_id'] as num?)?.toInt() ?? 0,
        studentName: json['student_name']?.toString() ?? 'Student',
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
        name: json['name']?.toString() ?? 'Student',
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
