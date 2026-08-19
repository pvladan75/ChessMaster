/// Homework as the two sides see it: what was set, and how far it has got.
library;

/// One assignment, with its progress counters already aggregated by the server.
/// What kind of work an assignment holds. Puzzles are graded; a lesson is
/// stepped through, so it has progress but no notion of correctness.
enum AssignmentKind { puzzles, lesson }

class Assignment {
  final int id;
  final String title;
  final String? instructions;
  final AssignmentKind kind;
  final int? lessonId;
  final DateTime? dueAt;
  final DateTime? completedAt;
  final List<String> themes;
  final int totalItems;
  final int attemptedItems;
  final int solvedItems;

  /// Present on a student's list.
  final String? trainerName;

  /// Present on a trainer's list.
  final String? studentName;
  final int? studentId;

  const Assignment({
    required this.id,
    required this.title,
    this.instructions,
    this.kind = AssignmentKind.puzzles,
    this.lessonId,
    this.dueAt,
    this.completedAt,
    this.themes = const [],
    this.totalItems = 0,
    this.attemptedItems = 0,
    this.solvedItems = 0,
    this.trainerName,
    this.studentName,
    this.studentId,
  });

  bool get isComplete =>
      completedAt != null || (totalItems > 0 && attemptedItems >= totalItems);

  /// Overdue only while there is still work left — a late-but-finished
  /// assignment is finished, and nagging about it helps nobody.
  bool get isOverdue =>
      !isComplete && dueAt != null && dueAt!.isBefore(DateTime.now());

  double get progress => totalItems == 0 ? 0 : attemptedItems / totalItems;

  /// Accuracy over what has actually been attempted.
  ///
  /// Null before anything is attempted, and null for a lesson — stepping through
  /// a lesson has no right answer, so a percentage there would report a finished
  /// lesson as 0% correct.
  int? get accuracy => kind == AssignmentKind.lesson || attemptedItems == 0
      ? null
      : ((solvedItems / attemptedItems) * 100).round();

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

  factory Assignment.fromJson(Map<String, dynamic> json) => Assignment(
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: json['title']?.toString() ?? '',
        instructions: json['instructions']?.toString(),
        kind: json['kind']?.toString() == 'lesson'
            ? AssignmentKind.lesson
            : AssignmentKind.puzzles,
        lessonId: (json['lesson_id'] as num?)?.toInt(),
        dueAt: _date(json['due_at']),
        completedAt: _date(json['completed_at']),
        themes: ((json['themes'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        totalItems: (json['total_items'] as num?)?.toInt() ?? 0,
        attemptedItems: (json['attempted_items'] as num?)?.toInt() ?? 0,
        solvedItems: (json['solved_items'] as num?)?.toInt() ?? 0,
        trainerName: json['trainer_name']?.toString(),
        studentName: json['student_name']?.toString(),
        studentId: (json['student_id'] as num?)?.toInt(),
      );
}

/// One assigned item and how it went.
///
/// [puzzleId] is null for a lesson's steps, which are identified by [position].
class AssignmentItem {
  final String? puzzleId;
  final int position;
  final int? puzzleRating;
  final bool? solved;
  final DateTime? attemptedAt;

  const AssignmentItem({
    required this.puzzleId,
    required this.position,
    this.puzzleRating,
    this.solved,
    this.attemptedAt,
  });

  bool get isDone => attemptedAt != null;

  factory AssignmentItem.fromJson(Map<String, dynamic> json) => AssignmentItem(
        puzzleId: json['puzzle_id']?.toString(),
        position: (json['position'] as num?)?.toInt() ?? 0,
        puzzleRating: (json['puzzle_rating'] as num?)?.toInt(),
        solved: json['solved'] as bool?,
        attemptedAt: json['attempted_at'] == null
            ? null
            : DateTime.tryParse(json['attempted_at'].toString())?.toLocal(),
      );
}

/// One board position in an assigned lesson.
class LessonStep {
  final String title;
  final String fen;
  final String? pgn;

  /// What the student is asked to do at this step.
  ///
  /// [title] is a name — "Završnica sa skakačem" — and a name is not a task. A
  /// student opening an assigned lesson used to get a board and no question,
  /// which is the oldest complaint about this feature. Null for steps written
  /// before the field existed, and the viewer simply says nothing then rather
  /// than inventing a task.
  final String? instruction;

  const LessonStep({
    required this.title,
    required this.fen,
    this.pgn,
    this.instruction,
  });

  factory LessonStep.fromJson(Map<String, dynamic> json) => LessonStep(
        title: json['title']?.toString() ?? '',
        fen: json['fen']?.toString() ?? '',
        pgn: json['pgn']?.toString(),
        instruction: (json['instruction']?.toString().trim().isEmpty ?? true)
            ? null
            : json['instruction'].toString().trim(),
      );
}

class AssignmentDetail {
  final Assignment assignment;
  final List<AssignmentItem> items;

  /// Board positions, present only for a lesson assignment.
  final List<LessonStep> steps;

  const AssignmentDetail({
    required this.assignment,
    required this.items,
    this.steps = const [],
  });

  /// The items still to be done, in the order the trainer set them.
  List<AssignmentItem> get pending =>
      items.where((item) => !item.isDone).toList();

  /// Where a student resuming a lesson should land: the first step they have not
  /// yet been through, or the last one if they finished.
  int get resumeStepIndex {
    final next = items.indexWhere((item) => !item.isDone);
    if (next >= 0) return next;
    return steps.isEmpty ? 0 : steps.length - 1;
  }

  factory AssignmentDetail.fromJson(Map<String, dynamic> json) =>
      AssignmentDetail(
        assignment: Assignment.fromJson(json),
        items: ((json['items'] as List?) ?? const [])
            .map((e) => AssignmentItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        steps: ((json['steps'] as List?) ?? const [])
            .map((e) => LessonStep.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// How a student is doing on one motif.
class ThemeAccuracy {
  final String theme;
  final int attempts;
  final int solved;
  final int? accuracy;

  const ThemeAccuracy({
    required this.theme,
    required this.attempts,
    required this.solved,
    this.accuracy,
  });

  factory ThemeAccuracy.fromJson(Map<String, dynamic> json) => ThemeAccuracy(
        theme: json['theme']?.toString() ?? '',
        attempts: (json['attempts'] as num?)?.toInt() ?? 0,
        solved: (json['solved'] as num?)?.toInt() ?? 0,
        accuracy: (json['accuracy'] as num?)?.toInt(),
      );
}

/// A student's report over a period.
class StudentProgress {
  final int periodDays;
  final int overallRating;
  final int totalAttempts;
  final int solvedAttempts;

  /// Null when nothing has been attempted — distinct from 0%, which would read
  /// as "gets everything wrong".
  final int? accuracy;

  final int activeDays;
  final int lifetimeSolved;
  final List<ThemeAccuracy> weakestThemes;
  final List<ThemeAccuracy> strongestThemes;
  final int assignmentsTotal;
  final int assignmentsCompleted;
  final int assignmentsOverdue;

  const StudentProgress({
    required this.periodDays,
    required this.overallRating,
    required this.totalAttempts,
    required this.solvedAttempts,
    required this.accuracy,
    required this.activeDays,
    required this.lifetimeSolved,
    required this.weakestThemes,
    required this.strongestThemes,
    required this.assignmentsTotal,
    required this.assignmentsCompleted,
    required this.assignmentsOverdue,
  });

  bool get hasData => totalAttempts > 0;

  factory StudentProgress.fromJson(Map<String, dynamic> json) {
    List<ThemeAccuracy> themes(String key) => ((json[key] as List?) ?? const [])
        .map((e) => ThemeAccuracy.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final assignments =
        Map<String, dynamic>.from(json['assignments'] ?? const {});

    return StudentProgress(
      periodDays: (json['periodDays'] as num?)?.toInt() ?? 30,
      overallRating: (json['overallRating'] as num?)?.toInt() ?? 1500,
      totalAttempts: (json['totalAttempts'] as num?)?.toInt() ?? 0,
      solvedAttempts: (json['solvedAttempts'] as num?)?.toInt() ?? 0,
      accuracy: (json['accuracy'] as num?)?.toInt(),
      activeDays: (json['activeDays'] as num?)?.toInt() ?? 0,
      lifetimeSolved: (json['lifetimeSolved'] as num?)?.toInt() ?? 0,
      weakestThemes: themes('weakestThemes'),
      strongestThemes: themes('strongestThemes'),
      assignmentsTotal: (assignments['total'] as num?)?.toInt() ?? 0,
      assignmentsCompleted: (assignments['completed'] as num?)?.toInt() ?? 0,
      assignmentsOverdue: (assignments['overdue'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Serbian labels for the Lichess motif tags, so a trainer's report does not
/// read as English jargon.
const Map<String, String> themeLabels = {
  'fork': 'dvojni napad',
  'pin': 'vezivanje',
  'skewer': 'ražanj',
  'discoveredAttack': 'otkriveni napad',
  'doubleCheck': 'dvostruki šah',
  'deflection': 'odvlačenje',
  'attraction': 'privlačenje',
  'clearance': 'oslobađanje polja',
  'interference': 'presecanje',
  'intermezzo': 'međupotez',
  'xRayAttack': 'rendgenski napad',
  'zugzwang': 'cugcvang',
  'sacrifice': 'žrtva',
  'hangingPiece': 'nezaštićena figura',
  'trappedPiece': 'uhvaćena figura',
  'defensiveMove': 'odbrambeni potez',
  'quietMove': 'tihi potez',
  'capturingDefender': 'uklanjanje branioca',
  'exposedKing': 'izložen kralj',
  'backRankMate': 'mat po zadnjoj liniji',
  'smotheredMate': 'ugušeni mat',
  'advancedPawn': 'napredovali pešak',
  'promotion': 'promocija',
  'underPromotion': 'potpromocija',
  'attackingF2F7': 'napad na f2/f7',
  'kingsideAttack': 'napad na kraljevom krilu',
  'queensideAttack': 'napad na daminom krilu',
  'enPassant': 'en passant',
  'mateIn1': 'mat u 1',
  'mateIn2': 'mat u 2',
  'mateIn3': 'mat u 3',
  'mateIn4': 'mat u 4',
  'mateIn5': 'mat u 5',
  'rookEndgame': 'topovska završnica',
  'pawnEndgame': 'pešačka završnica',
  'knightEndgame': 'skakačka završnica',
  'bishopEndgame': 'lovačka završnica',
};

/// Falls back to the raw tag rather than hiding an unlabelled motif — a new
/// Lichess theme should still show up, just untranslated.
String themeLabel(String theme) => themeLabels[theme] ?? theme;
