// exercise.dart — a position plus a task, as the wire spells it.
//
// `docs/PLAN-EXERCISE.md`, §7a. A trainer does not send a position, they send
// an exercise: `chess_backend/services/exercise.js` is the one reader of what
// a row means, and this file is its app-side mirror for the „find the move(s)"
// task built in Preparation (`docs/briefs/BRIEF-EXERCISE-FAZA2B-APP.md`). A
// game exercise (phase 3b) is read here too — `task['type'] == 'game'` — and
// `exerciseGameTask` below is what `MakeExerciseSheet` sends to make one.

import 'exercise_task_words.dart' show ExerciseAsk;

/// The one move a find exercise asks of the student.
///
/// `accept[0]` is the author's move — the one shown as the solution; the rest
/// of [accept] are also right. The wire keeps it in a list of exactly one,
/// the shape the rows were stored in while a solution could be a line
/// (`docs/PLAN-EXERCISE.md`, phases 14 and 16).
class ExerciseStep {
  const ExerciseStep({required this.accept});

  final List<String> accept;

  Map<String, dynamic> toJson() => {'accept': accept};

  static ExerciseStep? fromJson(Object? json) {
    if (json is! Map) return null;
    final rawAccept = json['accept'];
    if (rawAccept is! List) return null;
    final accept = rawAccept.whereType<String>().toList();
    if (accept.isEmpty) return null;
    return ExerciseStep(accept: accept);
  }
}

/// One exercise, as `GET`/`POST`/`PUT /exercises` answers it.
class Exercise {
  const Exercise({
    required this.id,
    required this.fen,
    required this.sideToMove,
    required this.name,
    required this.origin,
    this.instruction,
    this.blockedReason,
    this.themes = const [],
    required this.task,
    this.solution,
    required this.assignable,
  });

  final String id;
  final String fen;
  final String sideToMove;
  final String name;
  final String origin;
  final String? instruction;
  final String? blockedReason;
  final List<String> themes;

  /// `{'type': 'find'}` for the one task this phase builds, or the engine-game
  /// task (phase 3b).
  final Map<String, dynamic> task;

  /// Null for a game exercise — its task is not a line to replay.
  final List<ExerciseStep>? solution;

  final bool assignable;

  bool get isGame => task['type'] == 'game';

  static Exercise? fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final fen = json['fen']?.toString();
    final sideToMove = json['sideToMove']?.toString();
    final name = json['name']?.toString();
    final origin = json['origin']?.toString();
    final rawTask = json['task'];
    if (id == null ||
        fen == null ||
        sideToMove == null ||
        name == null ||
        origin == null ||
        rawTask is! Map) {
      return null;
    }

    List<ExerciseStep>? solution;
    final rawSolution = json['solution'];
    if (rawSolution is List) {
      solution = [
        for (final entry in rawSolution)
          if (ExerciseStep.fromJson(entry) != null)
            ExerciseStep.fromJson(entry)!,
      ];
    }

    final rawThemes = json['themes'];
    return Exercise(
      id: id,
      fen: fen,
      sideToMove: sideToMove,
      name: name,
      origin: origin,
      instruction: json['instruction'] as String?,
      blockedReason: json['blockedReason'] as String?,
      themes:
          rawThemes is List ? rawThemes.whereType<String>().toList() : const [],
      task: Map<String, dynamic>.from(rawTask),
      solution: solution,
      assignable: json['assignable'] == true,
    );
  }
}

/// What the „Make exercise" sheet sends. Its shape is the request body, not
/// the row: an edit says nothing about the position (`fen` stays null), and
/// a task with no line (a game, phase 3b) says nothing about `solution`.
class ExerciseDraft {
  const ExerciseDraft({
    required this.name,
    this.fen,
    this.instruction,
    this.themes = const [],
    required this.task,
    this.solution,
  });

  final String name;
  final String? fen;
  final String? instruction;
  final List<String> themes;
  final Map<String, dynamic> task;
  final List<ExerciseStep>? solution;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (fen != null) 'fen': fen,
        if (instruction != null) 'instruction': instruction,
        'themes': themes,
        'task': task,
        if (solution != null)
          'solution': [for (final s in solution!) s.toJson()],
      };
}

/// The `task` map of a game exercise, as `POST /exercises` takes it.
///
/// [side] is the side the **student** plays — never the position's own side
/// to move, which is a different question the position may or may not
/// answer, and does not answer this one either way. Absence is a third
/// answer, all the way to the wire: a choice the trainer did not make is not
/// sent, rather than sent as a guessed default.
Map<String, dynamic> exerciseGameTask({
  required String side,
  required ExerciseAsk ask,
  int? forMoves,
  String? level,
  int? thinkSeconds,
}) {
  if (ask == ExerciseAsk.find) {
    throw ArgumentError('"Find the move" is not a game exercise.');
  }
  if (ask == ExerciseAsk.play && forMoves == null) {
    throw ArgumentError('"Play N moves" needs its number.');
  }
  return {
    'type': 'game',
    'side': side,
    'goal': switch (ask) {
      ExerciseAsk.win => 'win',
      ExerciseAsk.play => 'play',
      _ => 'hold',
    },
    if (forMoves != null) 'surviveMoves': forMoves,
    if (level != null) 'level': level,
    if (thinkSeconds != null) 'thinkSeconds': thinkSeconds,
  };
}
