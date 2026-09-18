/// One item of a sent homework, as `homeworkService.childrenOf` selects it
/// (`chess_backend/services/homeworkService.js`), and the three states the
/// student's screen draws it in (docs/PLAN-DOMACI-ZADATAK.md §6, phase 5).
library;

/// Done, open or locked. The server cannot send `done` and `locked`
/// together — `childLockedSql` requires `completed_at IS NULL` — but the
/// ordering below still has to put done first: that exact mistake already
/// survived a mutation once, in the server's own tests, and a finished item
/// drawn as a locked one is the worst of the three to get wrong.
enum HomeworkChildState { done, open, locked }

/// One child of a homework, or nothing: [fromJson] refuses a row it cannot
/// read (no id, no kind) rather than guessing — an item nobody can open must
/// not be drawn as an item, and the kind decides which screen the row opens.
class HomeworkChild {
  const HomeworkChild({
    required this.id,
    required this.title,
    required this.kind,
    required this.position,
    required this.itemKey,
    this.lessonId,
    this.gate = true,
    this.gateOpenedAt,
    this.completedAt,
    this.task,
    this.totalItems = 0,
    this.attemptedItems = 0,
    this.solvedItems = 0,
    this.pendingItems = 0,
    this.passed = false,
    this.locked = false,
    this.blockedBy,
  });

  final int id;
  final String title;

  /// The wire spelling: `lesson`, `puzzles` or `engine_game`.
  final String kind;
  final int position;
  final String itemKey;
  final int? lessonId;
  final bool gate;
  final DateTime? gateOpenedAt;
  final DateTime? completedAt;

  /// The task, for `kind == 'engine_game'` — a „play it out" goal and
  /// position. `null` for every other kind.
  final Map<String, dynamic>? task;

  final int totalItems;
  final int attemptedItems;
  final int solvedItems;

  /// A game played and not yet judged (`docs/PLAN-EXERCISE.md`, phase 3b): the
  /// tablebase could not be reached, the game still counts as done, and it is
  /// judged the next time anybody opens the homework. `pending_items` on the
  /// wire; 0 when the server does not send it.
  final int pendingItems;
  final bool passed;

  /// Whether the server currently refuses this item. Never true together
  /// with a set [completedAt] — see [state].
  final bool locked;

  /// The id of the item directly before this one — **an id, not a
  /// position and not a title** — or `null` when nothing blocks it. The
  /// student is told which item this is by resolving the id against the
  /// homework's own children, never by reading it as an index.
  final int? blockedBy;

  /// Done wins over locked, whatever the server's `locked` flag says: work
  /// the student already finished does not disappear because a gate closed
  /// behind it.
  HomeworkChildState get state => completedAt != null
      ? HomeworkChildState.done
      : (locked ? HomeworkChildState.locked : HomeworkChildState.open);

  /// The trainer used the escape hatch on this item. Shown so the escape
  /// hatch is visible rather than silent.
  bool get openedByTrainer => gateOpenedAt != null;

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

  static HomeworkChild? fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as num?)?.toInt();
    final kind = json['kind']?.toString();
    if (id == null || kind == null || kind.isEmpty) return null;

    return HomeworkChild(
      id: id,
      title: json['title']?.toString() ?? '',
      kind: kind,
      position: (json['position'] as num?)?.toInt() ?? 0,
      itemKey: json['item_key']?.toString() ?? '',
      lessonId: (json['lesson_id'] as num?)?.toInt(),
      gate: json['gate'] != false,
      gateOpenedAt: _date(json['gate_opened_at']),
      completedAt: _date(json['completed_at']),
      task: json['task'] is Map
          ? Map<String, dynamic>.from(json['task'] as Map)
          : null,
      totalItems: (json['total_items'] as num?)?.toInt() ?? 0,
      attemptedItems: (json['attempted_items'] as num?)?.toInt() ?? 0,
      solvedItems: (json['solved_items'] as num?)?.toInt() ?? 0,
      pendingItems: (json['pending_items'] as num?)?.toInt() ?? 0,
      passed: json['passed'] == true,
      locked: json['locked'] == true,
      blockedBy: (json['blocked_by'] as num?)?.toInt(),
    );
  }
}
