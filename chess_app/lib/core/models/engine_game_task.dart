/// „Play it out": a homework item where the student plays a position against
/// the engine until the game ends (docs/PLAN-DOMACI-ZADATAK.md §3, phase 2).
///
/// This file is the app's half of a task both ends read. The server judges
/// again from the moves when the result is recorded
/// (`chess_backend/services/engineGameTask.js`) — nothing here is trusted on
/// its own — but the app has to decide *on its own board* when the game is
/// over, to stop it and say what happened. The two readings are held to one
/// another by a shared fixture, `docs/gates/engine_game_cases.json`.
library;

import 'package:chess/chess.dart' as chess;

import 'package:chess_app/features/exercises/models/exercise_task_words.dart'
    show exercisePieceCount, tablebasePieces;
import 'package:chess_app/services/fen_legality.dart';

import 'drill_outcome.dart';

/// The three goals the first version offers.
enum EngineGameGoal { win, hold, survive }

/// The default and the ceiling for [EngineGameTask.plyCap] — the same numbers
/// the server uses, so a task neither end refuses reads the same limit on
/// both boards.
const int kDefaultEngineGamePlyCap = 200;
const int _maxPlyCap = 600;
const int _maxSurviveMoves = 200;

const List<String> _kEngineLevels = ['lako', 'srednje', 'tesko'];

/// A task as the trainer set it, or nothing: [fromJson] refuses rather than
/// guesses, everywhere it matters. A homework item this app cannot read must
/// not open as a board with an invented goal on it.
class EngineGameTask {
  const EngineGameTask({
    required this.fen,
    required this.side,
    required this.goal,
    this.surviveMoves,
    this.level,
    this.thinkSeconds,
    this.plyCap = kDefaultEngineGamePlyCap,
  });

  /// The position, as the trainer set it.
  final String fen;

  /// The side the student plays; the engine plays the other.
  final chess.Color side;

  final EngineGameGoal goal;

  /// A number of the student's own moves, or null for a game played to its
  /// end. On „hold" and „survive" it is how long to last; on „win" it is
  /// **checkmate in this many moves** — mate on the board by then, or missed.
  final int? surviveMoves;

  /// `'lako'`, `'srednje'` or `'tesko'` — the engine's strength, chosen by the
  /// trainer and travelling on the task. Null leaves the app's own default in
  /// force, the same as the server does for an unset level.
  final String? level;

  /// How long the engine may think, in seconds (1..60), or null for the
  /// app's own default.
  final int? thinkSeconds;

  /// A cap so a game neither side can finish still ends and still counts.
  final int plyCap;

  /// Reads a task from JSON, or refuses it.
  ///
  /// A malformed FEN does not throw here: `chess.Chess.fromFEN` accepts
  /// nonsense silently (measured 17.9.2026 — an "empty board", no exception),
  /// so the check is [isFenLegal] rather than a `try`/`catch` around the
  /// package.
  static EngineGameTask? fromJson(Map<String, dynamic> json) {
    final fenRaw = json['fen'];
    if (fenRaw is! String) return null;
    final fen = fenRaw.trim();
    if (fen.isEmpty || !isFenLegal(fen)) return null;

    final chess.Color side;
    switch (json['side']) {
      case 'w':
        side = chess.Color.WHITE;
        break;
      case 'b':
        side = chess.Color.BLACK;
        break;
      default:
        return null;
    }

    final EngineGameGoal goal;
    switch (json['goal']) {
      case 'win':
        goal = EngineGameGoal.win;
        break;
      case 'hold':
        goal = EngineGameGoal.hold;
        break;
      case 'survive':
        goal = EngineGameGoal.survive;
        break;
      default:
        return null;
    }

    // The number of the student's own moves. `survive` has always needed it;
    // since phase 3a of `docs/PLAN-EXERCISE.md` a `hold` may carry one too —
    // hold the draw for the next N moves. On a `win` the same number means
    // **checkmate in N moves** (the owner's live pass, 19.9.2026): the rules
    // judge it alone, so it has no limit on pieces.
    // `surviveMoves` stays the field's one name on the wire, the same as the
    // server (`chess_backend/services/engineGameTask.js`).
    int? surviveMoves;
    final saidMoves =
        json.containsKey('surviveMoves') && json['surviveMoves'] != null;
    if (goal == EngineGameGoal.survive || saidMoves) {
      final n = _asInt(json['surviveMoves']);
      if (n == null || n < 1 || n > _maxSurviveMoves) return null;
      surviveMoves = n;
    }

    String? level;
    if (json['level'] != null) {
      final s = json['level'].toString();
      if (!_kEngineLevels.contains(s)) return null;
      level = s;
    }

    int? thinkSeconds;
    if (json['thinkSeconds'] != null) {
      final n = _asInt(json['thinkSeconds']);
      if (n == null || n < 1 || n > 60) return null;
      thinkSeconds = n;
    }

    var plyCap = kDefaultEngineGamePlyCap;
    if (json['plyCap'] != null) {
      final n = _asInt(json['plyCap']);
      if (n == null || n < 1 || n > _maxPlyCap) return null;
      plyCap = n;
    }

    return EngineGameTask(
      fen: fen,
      side: side,
      goal: goal,
      surviveMoves: surviveMoves,
      level: level,
      thinkSeconds: thinkSeconds,
      plyCap: plyCap,
    );
  }
}

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is String) return int.tryParse(v);
  return null;
}

/// The verdict of an assigned game in progress or just ended.
class EngineGameVerdict {
  const EngineGameVerdict({
    required this.ending,
    required this.outcome,
    required this.goalMet,
    required this.ownMoves,
    required this.needsTablebase,
  });

  /// Null while the game is running.
  final GameEnding? ending;
  final DrillOutcome outcome;
  final bool goalMet;
  final int ownMoves;

  /// True exactly when a „hold" or „survive" game ended at its move target
  /// (`GameEnding.moveTarget`) with seven pieces or fewer on the board. Such
  /// a position is one only a tablebase can judge exactly — the app cannot
  /// ask one, so [goalMet] above is only ever this app's own guess for such a
  /// game, and the caller must wait for the server's word rather than show it
  /// (`docs/PLAN-EXERCISE.md`, phase 3b, decision 1).
  final bool needsTablebase;
}

/// Reads the verdict of an assigned game through [verdictFor] and adds only
/// what a board cannot know: the „survive" target.
///
/// One rule, one home — the five board endings, resignation and the move
/// limit are [verdictFor]'s; this asks `chess.Chess` about none of them a
/// second time. [ownMoves] is not recounted here either: it is the caller's
/// count of the student's own moves played so far (the board's own history
/// starts empty at [EngineGameTask.fen], so plies played and plies allowed
/// mean the same thing to both readers).
EngineGameVerdict engineGameVerdict({
  required EngineGameTask task,
  required chess.Chess game,
  required int ownMoves,
  bool resigned = false,
}) {
  final boardVerdict = verdictFor(
    game,
    task.side,
    plyCap: task.plyCap,
    resigned: resigned,
  );

  var ending = boardVerdict.ending;
  var outcome = boardVerdict.outcome;

  // The board has nothing to say about a move target: it does not know how
  // many of the student's own moves the trainer asked for. Reaching the
  // number is not itself a win or a draw, so the outcome stays undecided even
  // though the game is, from here, over. Since phase 3a of
  // `docs/PLAN-EXERCISE.md` this applies to every goal that carries
  // `surviveMoves`. For a win it is where „checkmate in N moves" is missed:
  // `goalMet` below stays false, and that is final.
  if (ending == null &&
      task.surviveMoves != null &&
      ownMoves >= task.surviveMoves!) {
    ending = GameEnding.moveTarget;
  }

  var goalMet = false;
  if (ending != null) {
    switch (task.goal) {
      case EngineGameGoal.win:
        goalMet = outcome == DrillOutcome.readerWon;
        break;
      case EngineGameGoal.hold:
      case EngineGameGoal.survive:
        // „hold" is anything that is not a loss; „survive" is not losing,
        // either to the end of the game or for the number of the student's
        // own moves the trainer asked for.
        goalMet = outcome != DrillOutcome.readerLost;
        break;
    }
  }

  // With seven pieces or fewer, the position a move target reached is one a
  // tablebase can judge exactly. The app cannot ask one. A win is never
  // asked about: no mate after N moves is a missed goal however won the
  // position still is, and waiting for the server would let it say otherwise.
  final needsTablebase = ending == GameEnding.moveTarget &&
      task.goal != EngineGameGoal.win &&
      exercisePieceCount(game.fen) <= tablebasePieces;

  return EngineGameVerdict(
    ending: ending,
    outcome: outcome,
    goalMet: goalMet,
    ownMoves: ownMoves,
    needsTablebase: needsTablebase,
  );
}

/// The banner over the board: the goal in words and, when the trainer set a
/// number, how many of the student's own moves are left. One home — a goal
/// that carries a number under a sentence that leaves it out is how a student
/// plays on past a limit nobody told them of (the live pass of 19.9.2026).
String engineGameGoalSentence(EngineGameTask task, {required int ownMoves}) {
  final side = task.side == chess.Color.WHITE ? 'White' : 'Black';
  final total = task.surviveMoves;
  if (total == null) {
    return task.goal == EngineGameGoal.win
        ? 'You are $side — win the game'
        : 'You are $side — hold a draw';
  }
  final left = (total - ownMoves).clamp(0, total);
  final moves = '$total ${total == 1 ? 'move' : 'moves'}';
  final ask = task.goal == EngineGameGoal.win
      ? 'checkmate in $moves'
      : 'do not lose for $moves';
  return 'You are $side — $ask · $left left';
}

/// How the game ended, for the dialog that closes it. [endingLabel] names
/// every ending but one: at a move target the words depend on what the number
/// was for — reaching it meets a „hold" and misses a „checkmate in N".
String engineGameEndingWords(EngineGameTask? task, GameEnding ending) {
  if (ending != GameEnding.moveTarget || task == null) {
    return endingLabel(ending);
  }
  final n = task.surviveMoves ?? 0;
  final moves = '$n ${n == 1 ? 'move' : 'moves'}';
  return task.goal == EngineGameGoal.win
      ? 'no checkmate in $moves'
      : 'you were not beaten in $moves';
}
