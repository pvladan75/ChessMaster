/// What happened on one piece of homework, position by position — and what the
/// two of them said about it.
///
/// Both sides read the same screen off this. Until it existed, homework was
/// only arithmetic: "2/2 urađeno, tačnost 100%" told a trainer that something
/// went wrong somewhere and nothing about where.
library;

/// Which shelf an item came from. They are kept apart rather than flattened:
/// a scanned position asks one move, a Lichess puzzle is a forced line, and a
/// lesson step is read rather than solved.
enum ReviewItemKind {
  custom,
  lichess,
  step,

  /// The puzzle row is gone — a deleted position, or an id never imported. The
  /// attempt still happened, and dropping it would quietly change the count.
  unknown,
}

ReviewItemKind _kindFrom(String? raw) => switch (raw) {
      'custom' => ReviewItemKind.custom,
      'lichess' => ReviewItemKind.lichess,
      'step' => ReviewItemKind.step,
      _ => ReviewItemKind.unknown,
    };

class ReviewItem {
  const ReviewItem({
    required this.itemId,
    required this.position,
    required this.kind,
    required this.attempted,
    this.puzzleId,
    this.title,
    this.fen,
    this.instruction,
    this.themes = const [],
    this.solved,
    this.msTaken,
    this.playedSan,
    this.solutionSan,
    this.solutionMoves,
    this.solutionHidden = false,
    this.attemptedAt,
  });

  final int itemId;
  final int position;
  final ReviewItemKind kind;
  final String? puzzleId;

  final String? title;
  final String? fen;
  final String? instruction;
  final List<String> themes;

  /// Whether the student got to this position at all.
  final bool attempted;

  /// Null means the question was never one of right and wrong — a lesson step
  /// is read, not solved.
  final bool? solved;

  final int? msTaken;

  /// What the student actually played. **Null means it is not known**, not that
  /// they played nothing: rows answered before the move was stored have none,
  /// and the Lichess path reports only whether the puzzle was solved. The
  /// screen must keep those two apart.
  final String? playedSan;

  /// The author's move, released only once it may be shown.
  final String? solutionSan;

  /// A Lichess line, in the notation it is stored in.
  final String? solutionMoves;

  /// True when there *is* an answer and this viewer may not see it yet. A
  /// position with a hidden solution and one with no solution at all are
  /// different things and must not look alike.
  final bool solutionHidden;

  final DateTime? attemptedAt;

  factory ReviewItem.fromJson(Map<String, dynamic> json) => ReviewItem(
        itemId: (json['itemId'] as num).toInt(),
        position: (json['position'] as num?)?.toInt() ?? 0,
        kind: _kindFrom(json['kind']?.toString()),
        puzzleId: json['puzzleId']?.toString(),
        title: _text(json['title']),
        fen: _text(json['fen']),
        instruction: _text(json['instruction']),
        themes: (json['themes'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        attempted: json['attempted'] == true,
        solved: json['solved'] is bool ? json['solved'] as bool : null,
        msTaken: (json['msTaken'] as num?)?.toInt(),
        playedSan: _text(json['playedSan']),
        solutionSan: _text(json['solutionSan']),
        solutionMoves: _text(json['solutionMoves']),
        solutionHidden: json['solutionHidden'] == true,
        attemptedAt: json['attemptedAt'] == null
            ? null
            : DateTime.tryParse(json['attemptedAt'].toString()),
      );

  /// The name to show, or a fallback built from the order it was set in.
  String label(int index) => title ?? 'Pozicija ${index + 1}';
}

/// One thing said about the homework, or about one position in it.
class AssignmentNote {
  const AssignmentNote({
    required this.id,
    required this.body,
    required this.mine,
    this.itemId,
    this.authorName,
    this.createdAt,
  });

  final int id;

  /// Null means it is about the whole assignment rather than one position.
  final int? itemId;

  final String body;

  /// Whether the reader wrote it. Decided on the server, so the same comparison
  /// is not made in three places where it could disagree with itself.
  final bool mine;

  final String? authorName;
  final DateTime? createdAt;

  factory AssignmentNote.fromJson(Map<String, dynamic> json) => AssignmentNote(
        id: (json['id'] as num).toInt(),
        itemId: (json['itemId'] as num?)?.toInt(),
        body: json['body']?.toString() ?? '',
        mine: json['mine'] == true,
        authorName: _text(json['authorName']),
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.tryParse(json['createdAt'].toString()),
      );
}

class AssignmentReview {
  const AssignmentReview({
    required this.assignmentId,
    required this.title,
    required this.isTrainer,
    this.kind,
    this.instructions,
    this.trainerName,
    this.studentName,
    this.items = const [],
    this.notes = const [],
  });

  final int assignmentId;
  final String title;
  final String? kind;
  final String? instructions;
  final String? trainerName;
  final String? studentName;

  /// Which side is reading. It changes the words on screen — "tvoj potez" and
  /// "učenikov potez" are the same field and not the same sentence.
  final bool isTrainer;

  final List<ReviewItem> items;
  final List<AssignmentNote> notes;

  bool get isLesson => kind == 'lesson';

  /// Notes about the assignment as a whole.
  List<AssignmentNote> get generalNotes =>
      notes.where((n) => n.itemId == null).toList();

  List<AssignmentNote> notesFor(int itemId) =>
      notes.where((n) => n.itemId == itemId).toList();

  int get attemptedCount => items.where((i) => i.attempted).length;
  int get solvedCount => items.where((i) => i.solved == true).length;

  AssignmentReview withNote(AssignmentNote note) => AssignmentReview(
        assignmentId: assignmentId,
        title: title,
        kind: kind,
        instructions: instructions,
        trainerName: trainerName,
        studentName: studentName,
        isTrainer: isTrainer,
        items: items,
        notes: [...notes, note],
      );

  AssignmentReview withoutNote(int noteId) => AssignmentReview(
        assignmentId: assignmentId,
        title: title,
        kind: kind,
        instructions: instructions,
        trainerName: trainerName,
        studentName: studentName,
        isTrainer: isTrainer,
        items: items,
        notes: notes.where((n) => n.id != noteId).toList(),
      );

  factory AssignmentReview.fromJson(Map<String, dynamic> json) {
    final assignment =
        Map<String, dynamic>.from(json['assignment'] as Map? ?? const {});
    final viewer =
        Map<String, dynamic>.from(json['viewer'] as Map? ?? const {});

    return AssignmentReview(
      assignmentId: (assignment['id'] as num?)?.toInt() ?? 0,
      title: assignment['title']?.toString() ?? 'Zadatak',
      kind: assignment['kind']?.toString(),
      instructions: _text(assignment['instructions']),
      trainerName: _text(assignment['trainerName']),
      studentName: _text(assignment['studentName']),
      isTrainer: viewer['isTrainer'] == true,
      items: ((json['items'] as List?) ?? const [])
          .map((e) => ReviewItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      notes: ((json['notes'] as List?) ?? const [])
          .map((e) => AssignmentNote.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}
