/// A homework template, written once and sent as a set of assignments —
/// `docs/PLAN-DOMACI-ZADATAK.md` §4 variant A, phase 3 (authoring).
///
/// This file is read by `docs/gates/homework_editor_test.dart`; its header
/// states the exact shape below. Two wire spellings meet here on purpose:
/// what the server *sends* about a saved item uses `item_key`
/// (`chess_backend/services/homeworkTemplate.js`), and what the editor
/// *sends back* uses `itemKey` and omits `position` altogether — order is the list, and the server renumbers it
/// from scratch on every save. A key that followed the index instead of
/// travelling with its item is the exact bug `assignment_items.step_key` and
/// `review_items.step_key` were both migrated to fix.
library;

/// The four kinds of item a homework can hold, and what `task` carries for
/// each — `lesson` (`{lessonId}`), `positions` (`{puzzleIds: [...]}`),
/// `puzzles` (`{themes, count, minRating, maxRating}`) and `engineGame` (the
/// „play it out" task read by `EngineGameTask.fromJson`).
enum HomeworkItemKind { lesson, positions, puzzles, engineGame }

/// The wire spelling the server checks — `chess_backend/routes/homeworks.js`.
String wireKindOf(HomeworkItemKind kind) => switch (kind) {
      HomeworkItemKind.lesson => 'lesson',
      HomeworkItemKind.positions => 'positions',
      HomeworkItemKind.puzzles => 'puzzles',
      HomeworkItemKind.engineGame => 'engine_game',
    };

/// The kind a wire spelling names, or null for one this app does not know —
/// refused rather than guessed, the same rule as everywhere else a wire value
/// picks an enum.
HomeworkItemKind? kindFromWire(String wire) => switch (wire) {
      'lesson' => HomeworkItemKind.lesson,
      'positions' => HomeworkItemKind.positions,
      'puzzles' => HomeworkItemKind.puzzles,
      'engine_game' => HomeworkItemKind.engineGame,
      _ => null,
    };

/// One row of a homework, as the editor shows it.
///
/// [itemKey] is the identity a sent homework's children point back at — never
/// derived from the row's position in the list, which changes on every
/// reorder. Null means the row was added in this sitting and has never been
/// saved; the server mints a key for it on the next save.
class HomeworkItem {
  const HomeworkItem({
    required this.itemKey,
    required this.kind,
    required this.task,
    required this.gate,
  });

  final String? itemKey;
  final HomeworkItemKind kind;

  /// The kind-specific payload. Read through the kind's own reader
  /// (`EngineGameTask.fromJson` for `engineGame`) rather than a second one
  /// grown here — this class carries the map, it does not validate it.
  final Map<String, dynamic> task;

  /// „Not before the previous item is done." Meaningless on the first row —
  /// the server ignores a gate with nothing before it — but still part of
  /// the wire shape every item carries.
  ///
  /// „Done" is *attempted*. There was a second switch that narrowed it to
  /// *solved*; the owner removed it on 18.9.2026 (`docs/PLAN-EXERCISE.md`
  /// §8.3), because it was the one thing here that could trap a student.
  final bool gate;

  HomeworkItem copyWith({
    bool? gate,
    Map<String, dynamic>? task,
  }) =>
      HomeworkItem(
        itemKey: itemKey,
        kind: kind,
        task: task ?? this.task,
        gate: gate ?? this.gate,
      );

  /// What the editor sends. `itemKey` is left out entirely when there is
  /// none — an empty string or a null value on the wire would both read as
  /// „a key", which a new item does not have yet.
  Map<String, dynamic> toJson() => {
        if (itemKey != null) 'itemKey': itemKey,
        'kind': wireKindOf(kind),
        'task': task,
        'gate': gate,
      };

  /// Reads one item as the server sent it (`GET /homeworks/:id`), or refuses.
  /// An unknown kind or a missing task is not guessed at — the row simply
  /// cannot be shown, and a homework this app cannot fully read must not open
  /// with a blank stand-in for the row it could not understand.
  static HomeworkItem? fromJson(Map<String, dynamic> json) {
    final kindRaw = json['kind'];
    if (kindRaw is! String) return null;
    final kind = kindFromWire(kindRaw);
    if (kind == null) return null;

    final taskRaw = json['task'];
    if (taskRaw is! Map) return null;

    return HomeworkItem(
      itemKey: json['item_key']?.toString(),
      kind: kind,
      task: Map<String, dynamic>.from(taskRaw),
      gate: json['gate'] == true,
    );
  }
}

/// One copy of this homework already sent, as `GET /homeworks/:id` lists it
/// under `sent` (`homeworkTemplate.loadHomework`).
///
/// A copy is an ordinary parent assignment and goes on living after the
/// template is edited or deleted — `assignments.homework_id` is
/// `ON DELETE SET NULL` — so this is a record of what a student *has*, not a
/// view of what the template says today. That is the whole reason writing a
/// homework and sending it are two acts.
class HomeworkSentCopy {
  const HomeworkSentCopy({
    required this.assignmentId,
    required this.studentId,
    required this.studentName,
    this.sentAt,
    this.completedAt,
    this.itemsTotal = 0,
    this.itemsDone = 0,
  });

  final int assignmentId;
  final int studentId;
  final String studentName;
  final DateTime? sentAt;
  final DateTime? completedAt;

  /// The children of that copy, not the template's items: an item added to
  /// the template afterwards is not in a homework already sent.
  final int itemsTotal;
  final int itemsDone;

  bool get isComplete => completedAt != null;

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

  static HomeworkSentCopy? fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt();
    if (id == null) return null;
    return HomeworkSentCopy(
      assignmentId: id,
      studentId: (json['student_id'] as num?)?.toInt() ?? 0,
      studentName: json['student_name']?.toString() ?? 'Student',
      sentAt: _date(json['created_at']),
      completedAt: _date(json['completed_at']),
      itemsTotal: (json['child_total'] as num?)?.toInt() ?? 0,
      itemsDone: (json['child_completed'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A homework template: a title, an optional note, and its items in order.
class Homework {
  const Homework({
    this.id,
    required this.title,
    this.instructions,
    required this.items,
    this.itemCount,
    this.sentCount,
    this.sent = const [],
    this.updatedAt,
  });

  /// Null for a homework never saved.
  final int? id;
  final String title;
  final String? instructions;
  final List<HomeworkItem> items;

  /// Carried only by the summary `GET /homeworks` returns, which does not
  /// send the items themselves — the list screen's row, not the editor's.
  final int? itemCount;
  final int? sentCount;

  /// The copies already sent, newest first. Only `GET /homeworks/:id` carries
  /// them; the summary in the list carries [sentCount] instead.
  final List<HomeworkSentCopy> sent;
  final DateTime? updatedAt;

  /// What the editor sends: title, instructions and the items in the order
  /// shown. No `id` (the endpoint says which homework) and no `position` on
  /// any item (the list order is the order; the server numbers it).
  Map<String, dynamic> toJson() => {
        'title': title,
        'instructions': instructions,
        'items': items.map((i) => i.toJson()).toList(),
      };

  /// Reads a homework the server sent, or refuses — a title is the one thing
  /// every homework must have, and an item this app cannot read is not
  /// silently dropped: the whole homework is refused rather than opened one
  /// row short of what the trainer actually wrote.
  static Homework? fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    if (title is! String || title.trim().isEmpty) return null;

    final items = <HomeworkItem>[];
    final itemsRaw = json['items'];
    if (itemsRaw is List) {
      for (final raw in itemsRaw) {
        if (raw is! Map) return null;
        final item = HomeworkItem.fromJson(Map<String, dynamic>.from(raw));
        if (item == null) return null;
        items.add(item);
      }
    }

    // A copy this app cannot read is dropped rather than refusing the whole
    // homework: the items are the contract the editor writes back, while
    // these are a record of what has already gone out, and one unreadable
    // row of it must not shut the editor.
    final sent = <HomeworkSentCopy>[];
    for (final raw in (json['sent'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final copy = HomeworkSentCopy.fromJson(Map<String, dynamic>.from(raw));
      if (copy != null) sent.add(copy);
    }

    return Homework(
      id: (json['id'] as num?)?.toInt(),
      title: title,
      instructions: json['instructions']?.toString(),
      items: items,
      itemCount: (json['item_count'] as num?)?.toInt(),
      sentCount: (json['sent_count'] as num?)?.toInt(),
      sent: sent,
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }
}
