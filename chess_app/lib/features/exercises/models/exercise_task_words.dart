// exercise_task_words.dart — what an exercise asks, in the words a trainer and
// a student read (`docs/PLAN-EXERCISE.md`, decision 1).
//
// One home, because three screens say it — the sheet that makes an exercise,
// the Library row that lists it, the homework row that sends it — and a task
// worded three ways is three tasks to whoever reads them. Written by the lead
// before phases 3b and 4 were briefed, so that two workers building in
// parallel share it rather than each growing their own.
//
// The task is the wire's map, as `GET /library/positions` and `GET
// /exercises/:id` send it: `{type: 'find'}`, or `{type: 'game', side, goal,
// surviveMoves, …}`. `surviveMoves` on a hold is „for N moves"; on a win it is
// „checkmate in N moves" (19.9.2026). The goal `survive` is the older
// spelling of „draw or better, for N moves" and is read as that.

/// What the Library filters an exercise by. A closed set on purpose: a filter
/// the reader cannot name is a filter they cannot use.
enum ExerciseAsk {
  find('Find the move'),
  win('Win'),
  hold('Draw or better');

  const ExerciseAsk(this.label);

  final String label;
}

/// Which of the three an exercise's [task] is. A task this app cannot read is
/// „find": every row written before tasks existed has none, and means that.
ExerciseAsk exerciseAskOf(Map<String, dynamic>? task) {
  if (task == null || task['type'] != 'game') return ExerciseAsk.find;
  return task['goal'] == 'win' ? ExerciseAsk.win : ExerciseAsk.hold;
}

/// The task's number of moves, or null when the game is played to its end.
int? exerciseForMoves(Map<String, dynamic>? task) {
  if (task == null || task['type'] != 'game') return null;
  final raw = task['surviveMoves'];
  final n = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}');
  return (n != null && n > 0) ? n : null;
}

/// The task in one line: „Find the move", „Find the moves", „Win as White",
/// „Checkmate in 5 moves as White", „Draw or better as Black, for 4 moves".
///
/// [solutionMoves] is the number of the student's own moves in a find
/// exercise's line, when the caller knows it; a list that does not carry the
/// solution passes null and reads „Find the move", which is never wrong.
String exerciseTaskWords(Map<String, dynamic>? task, {int? solutionMoves}) {
  final ask = exerciseAskOf(task);
  if (ask == ExerciseAsk.find) {
    return (solutionMoves ?? 1) > 1 ? 'Find the moves' : ExerciseAsk.find.label;
  }
  final side = switch (task!['side']) {
    'w' => ' as White',
    'b' => ' as Black',
    _ => '',
  };
  final n = exerciseForMoves(task);
  if (n == null) return '${ask.label}$side';
  final moves = '$n ${n == 1 ? 'move' : 'moves'}';
  return ask == ExerciseAsk.win
      ? 'Checkmate in $moves$side'
      : '${ask.label}$side, for $moves';
}

/// Who is to move in [fen], in words — never as a colour alone: a dot of one
/// hue beside a dot of another tells a colour-blind reader nothing.
String sideToMoveWords(String fen) {
  final parts = fen.trim().split(RegExp(r'\s+'));
  return (parts.length > 1 && parts[1] == 'b')
      ? 'Black to move'
      : 'White to move';
}

/// How many pieces stand on the board of [fen], kings included. Seven is as
/// far as a tablebase reaches (`chess_backend/services/engineGameTask.js`).
int exercisePieceCount(String fen) => RegExp(r'[a-zA-Z]')
    .allMatches(fen.trim().split(RegExp(r'\s+')).first)
    .length;

const int tablebasePieces = 7;

/// Who will judge a game exercise — said to the trainer when it is written,
/// because whether the final position can be checked is known then: pieces
/// only leave the board.
enum ExerciseJudge {
  /// Played to the end: the rules of the game are the verdict.
  rules,

  /// Checkmate in N moves: mate on the board by then, or missed. The rules
  /// again — no tablebase, and any number of pieces.
  mateInMoves,

  /// Draw or better for N moves, seven pieces or fewer: the tablebase checks
  /// what was reached.
  tablebase,

  /// Draw or better for N moves, more pieces: only „not mated" can be checked.
  notMatedOnly,
}

ExerciseJudge exerciseJudgeFor({
  required String fen,
  required ExerciseAsk ask,
  required int? forMoves,
}) {
  if (ask == ExerciseAsk.find || forMoves == null) return ExerciseJudge.rules;
  if (ask == ExerciseAsk.win) return ExerciseJudge.mateInMoves;
  return exercisePieceCount(fen) <= tablebasePieces
      ? ExerciseJudge.tablebase
      : ExerciseJudge.notMatedOnly;
}

/// The sentence for [judge], shown under the two questions.
String exerciseJudgeWords(ExerciseJudge judge) => switch (judge) {
      ExerciseJudge.rules => 'Judged by how the game ends.',
      ExerciseJudge.tablebase =>
        'The position reached after the last move is checked against the tablebase.',
      ExerciseJudge.notMatedOnly =>
        'More than seven pieces: only "not checkmated" can be checked.',
      ExerciseJudge.mateInMoves =>
        "Met only by checkmate within that many of the student's own moves.",
    };
