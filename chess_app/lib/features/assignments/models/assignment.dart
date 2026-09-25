/// Homework as the two sides see it: what was set, and how far it has got.
library;

import 'package:chess_app/features/assignments/models/puzzle_review.dart';
import 'package:chess_app/features/homework/models/homework_child.dart';

/// One assignment, with its progress counters already aggregated by the server.
/// What kind of work an assignment holds. Puzzles are graded; a lesson is
/// stepped through, so it has progress but no notion of correctness; a
/// homework is a parent of its own children (docs/PLAN-DOMACI-ZADATAK.md §6);
/// an engine game is „play it out", reachable only from inside a homework.
enum AssignmentKind { puzzles, lesson, homework, engineGame }

AssignmentKind _kindOf(dynamic wire) {
  switch (wire?.toString()) {
    case 'lesson':
      return AssignmentKind.lesson;
    case 'homework':
      return AssignmentKind.homework;
    case 'engine_game':
      return AssignmentKind.engineGame;
    default:
      // An unknown kind stays the ordinary one, not a homework whose
      // children would never load and not a game with no task to read.
      return AssignmentKind.puzzles;
  }
}

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

  /// Who set this assignment. Read from the payload and compared against the
  /// session's own id — never a flag a caller could pass wrongly — to decide
  /// whether the reader is the trainer.
  final int? trainerId;

  /// Present on a student's list.
  final String? trainerName;

  /// Present on a trainer's list.
  final String? studentName;
  final int? studentId;

  /// A homework counts its children, not its (non-existent) items — a parent
  /// has no `assignment_items` at all.
  final int childTotal;
  final int childCompleted;

  /// The task, for `kind == AssignmentKind.engineGame` — a bare engine-game
  /// assignment fetched by its own id. `null` for every other kind.
  final Map<String, dynamic>? task;

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
    this.trainerId,
    this.trainerName,
    this.studentName,
    this.studentId,
    this.childTotal = 0,
    this.childCompleted = 0,
    this.task,
  });

  bool get isHomework => kind == AssignmentKind.homework;

  bool get isComplete =>
      completedAt != null || (totalItems > 0 && attemptedItems >= totalItems);

  /// Overdue only while there is still work left — a late-but-finished
  /// assignment is finished, and nagging about it helps nobody.
  bool get isOverdue =>
      !isComplete && dueAt != null && dueAt!.isBefore(DateTime.now());

  /// A homework's progress counts its children: a parent has no
  /// `assignment_items` at all, so the item-based number would read every
  /// homework as 0.
  double get progress {
    if (isHomework) {
      return childTotal == 0 ? 0 : childCompleted / childTotal;
    }
    return totalItems == 0 ? 0 : attemptedItems / totalItems;
  }

  /// Accuracy over what has actually been attempted.
  ///
  /// Null before anything is attempted, and null for a lesson — stepping through
  /// a lesson has no right answer, so a percentage there would report a finished
  /// lesson as 0% correct.
  int? get accuracy => kind == AssignmentKind.lesson || attemptedItems == 0
      ? null
      : ((solvedItems / attemptedItems) * 100).round();

  /// The one line a row shows about how far a **homework** has got. It
  /// counts items — children — because a parent holds no puzzles and no
  /// steps of its own, so the item counters every other kind uses would read
  /// „0/0 completed“ for a homework of five items. One wording, one home:
  /// the student's list, the homework screen and the trainer's list all say
  /// it the same way.
  String get itemsSummary => '$childCompleted of $childTotal items';

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

  factory Assignment.fromJson(Map<String, dynamic> json) => Assignment(
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: json['title']?.toString() ?? '',
        instructions: json['instructions']?.toString(),
        kind: _kindOf(json['kind']),
        lessonId: (json['lesson_id'] as num?)?.toInt(),
        dueAt: _date(json['due_at']),
        completedAt: _date(json['completed_at']),
        themes: ((json['themes'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        totalItems: (json['total_items'] as num?)?.toInt() ?? 0,
        attemptedItems: (json['attempted_items'] as num?)?.toInt() ?? 0,
        solvedItems: (json['solved_items'] as num?)?.toInt() ?? 0,
        trainerId: (json['trainer_id'] as num?)?.toInt(),
        trainerName: json['trainer_name']?.toString(),
        studentName: json['student_name']?.toString(),
        studentId: (json['student_id'] as num?)?.toInt(),
        childTotal: (json['child_total'] as num?)?.toInt() ?? 0,
        childCompleted: (json['child_completed'] as num?)?.toInt() ?? 0,
        task: json['task'] is Map
            ? Map<String, dynamic>.from(json['task'] as Map)
            : null,
      );
}

/// One assigned item and how it went.
///
/// [puzzleId] is null for a tutorial's film and a game played out, each the
/// assignment's one item.
class AssignmentItem {
  final String? puzzleId;
  final int position;
  final int? puzzleRating;
  final bool? solved;
  final DateTime? attemptedAt;

  /// The move the student played, where it was recorded. Null means it is not
  /// known — true for everything answered before it was stored, and for the
  /// Lichess path, which reports only whether the puzzle was solved. It never
  /// means they played nothing.
  final String? playedSan;

  const AssignmentItem({
    required this.puzzleId,
    required this.position,
    this.puzzleRating,
    this.solved,
    this.attemptedAt,
    this.playedSan,
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
        playedSan: json['played_san']?.toString().trim().isEmpty ?? true
            ? null
            : json['played_san'].toString().trim(),
      );
}

/// What a tutorial assignment's film is, as the student is told it —
/// `docs/PLAN-TUTORIJAL-VIDEO.md`. A tutorial reaches a student only as its
/// film, and the file itself is fetched through a link signed for them
/// (`AssignmentApiService.fetchVideoLink`), never named here.
class AssignmentVideo {
  const AssignmentVideo({
    required this.ready,
    this.seconds,
    this.resolution,
    this.renderedAt,
  });

  /// False when the tutorial is gone or its film is no longer on the server.
  final bool ready;
  final int? seconds;
  final String? resolution;
  final DateTime? renderedAt;

  /// Null when the server said nothing — anything that is not a tutorial.
  static AssignmentVideo? fromJson(Object? json) {
    if (json is! Map) return null;
    return AssignmentVideo(
      ready: json['status'] == 'ready',
      seconds: (json['seconds'] as num?)?.toInt(),
      resolution: json['resolution']?.toString(),
      renderedAt: DateTime.tryParse(json['renderedAt']?.toString() ?? ''),
    );
  }
}

/// One of the trainer's own positions, as the student receives it.
///
/// The solution is deliberately absent. It is the answer to the question being
/// asked, and it stays on the server until the student has answered — sending
/// it here so the app could mark its own work would hand them the very thing
/// being asked of them.
class CustomPosition {
  const CustomPosition({
    required this.puzzleId,
    required this.fen,
    required this.sideToMove,
    this.instruction,
    this.themes = const [],
    this.sourceTitle,
    this.sourceLabel,
  });

  final String puzzleId;
  final String fen;
  final String sideToMove;

  /// What the student is asked to do here.
  final String? instruction;

  final List<String> themes;
  final String? sourceTitle;
  final String? sourceLabel;

  factory CustomPosition.fromJson(Map<String, dynamic> json) => CustomPosition(
        puzzleId: json['puzzle_id']?.toString() ?? '',
        fen: json['fen']?.toString() ?? '',
        sideToMove: json['side_to_move']?.toString() ?? 'w',
        instruction: (json['instruction']?.toString().trim().isEmpty ?? true)
            ? null
            : json['instruction'].toString().trim(),
        themes: (json['themes'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        sourceTitle: json['source_title']?.toString(),
        sourceLabel: json['source_label']?.toString(),
      );
}

/// The server's verdict on one answer, and the solution it then released.
class CustomAttemptResult {
  const CustomAttemptResult({
    required this.correct,
    required this.reason,
    this.playedSan,
    this.solutionSan,
    this.review,
  });

  final bool correct;

  /// The server's own words — "the author's move", "a different mate, but
  /// mate". The second one matters: a student who found a different mate
  /// deserves to be told they were right *and* why it counted, and
  /// `custom_puzzle_solver_screen.dart` compares this string to say so. It is
  /// a wire value as much as a sentence: see `customPuzzleJudge.js`.
  final String reason;

  final String? playedSan;
  final String? solutionSan;

  /// What a puzzle from a game reveals, released with the answer
  /// (`docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`, phases 2 and 5); null for every
  /// other exercise.
  final PuzzleReview? review;

  factory CustomAttemptResult.fromJson(Map<String, dynamic> json) {
    return CustomAttemptResult(
      correct: json['correct'] == true,
      reason: json['reason']?.toString() ?? '',
      playedSan: json['playedSan']?.toString(),
      solutionSan: json['solutionSan']?.toString(),
      review: PuzzleReview.fromJson(json['review']),
    );
  }
}

class AssignmentDetail {
  final Assignment assignment;
  final List<AssignmentItem> items;

  /// The tutorial's film, present only for a tutorial assignment.
  final AssignmentVideo? video;

  /// Positions the trainer scanned or built themselves, present when the
  /// homework was set from their own shelf rather than from the Lichess set.
  final List<CustomPosition> customPositions;

  /// The homework's own items, in the trainer's order. Empty for anything
  /// that is not a homework — a parent has no `assignment_items`, so this is
  /// the only place its work is listed.
  final List<HomeworkChild> children;

  const AssignmentDetail({
    required this.assignment,
    required this.items,
    this.video,
    this.customPositions = const [],
    this.children = const [],
  });

  /// True when this homework is made of the trainer's own positions.
  bool get isCustom => customPositions.isNotEmpty;

  /// The position for one item, or null if it did not travel with the detail.
  CustomPosition? positionFor(String puzzleId) {
    for (final p in customPositions) {
      if (p.puzzleId == puzzleId) return p;
    }
    return null;
  }

  /// The items still to be done, in the order the trainer set them.
  List<AssignmentItem> get pending =>
      items.where((item) => !item.isDone).toList();

  /// When the student downloaded a tutorial's film, or null — its one item's
  /// `attempted_at` (`docs/PLAN-TUTORIJAL-VIDEO.md`, D3).
  DateTime? get downloadedAt => items.isEmpty ? null : items.first.attemptedAt;

  factory AssignmentDetail.fromJson(Map<String, dynamic> json) =>
      AssignmentDetail(
        assignment: Assignment.fromJson(json),
        items: ((json['items'] as List?) ?? const [])
            .map((e) => AssignmentItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        video: AssignmentVideo.fromJson(json['video']),
        customPositions: ((json['customPositions'] as List?) ?? const [])
            .map((e) => CustomPosition.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        children: ((json['children'] as List?) ?? const [])
            .map((e) => HomeworkChild.fromJson(Map<String, dynamic>.from(e)))
            .whereType<HomeworkChild>()
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

/// Human-readable labels for the Lichess motif tags, so a trainer's report does
/// not read as jargon.
const Map<String, String> themeLabels = {
  'fork': 'fork',
  'pin': 'pin',
  'skewer': 'skewer',
  'discoveredAttack': 'discovered attack',
  'doubleCheck': 'double check',
  'deflection': 'deflection',
  'attraction': 'attraction',
  'clearance': 'clearance',
  'interference': 'interference',
  'intermezzo': 'intermezzo',
  'xRayAttack': 'x-ray attack',
  'zugzwang': 'zugzwang',
  'sacrifice': 'sacrifice',
  'hangingPiece': 'hanging piece',
  'trappedPiece': 'trapped piece',
  'defensiveMove': 'defensive move',
  'quietMove': 'quiet move',
  'capturingDefender': 'capturing defender',
  'exposedKing': 'exposed king',
  'backRankMate': 'back-rank mate',
  'smotheredMate': 'smothered mate',
  'advancedPawn': 'advanced pawn',
  'promotion': 'promotion',
  'underPromotion': 'underpromotion',
  'attackingF2F7': 'attacking f2/f7',
  'kingsideAttack': 'kingside attack',
  'queensideAttack': 'queenside attack',
  'enPassant': 'en passant',
  'mateIn1': 'mate in 1',
  'mateIn2': 'mate in 2',
  'mateIn3': 'mate in 3',
  'mateIn4': 'mate in 4',
  'mateIn5': 'mate in 5',
  'rookEndgame': 'rook endgame',
  'pawnEndgame': 'pawn endgame',
  'knightEndgame': 'knight endgame',
  'bishopEndgame': 'bishop endgame',
};

/// Falls back to the raw tag rather than hiding an unlabelled motif — a new
/// Lichess theme should still show up, just untranslated.
String themeLabel(String theme) => themeLabels[theme] ?? theme;
