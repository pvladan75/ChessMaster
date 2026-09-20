// exercise_check.dart — what the tablebase and the engine say of an exercise
// **when it is made**, not when it is solved (`docs/PLAN-EXERCISE.md`, decision
// 5). Pure, no I/O: `ExerciseChecker` (`exercise_checker.dart`) is the runner
// that asks the two real services and hands their answers here.
//
// Two rules above all others:
//   1. The check advises; it never blocks a save. Every function below either
//      answers instantly from data already in hand or, for a missing answer
//      (`null`, an empty line, an unreadable evaluation), says nothing rather
//      than guessing.
//   2. A finding is never applied by itself. `acceptFinding` is the only
//      thing that changes a solution, and only a trainer's own tap calls it.

import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart'
    show SyzygyCategory, SyzygyResult;
import 'package:chess_app/features/position_scanner/services/side_proposal.dart'
    show parseEval;
import 'package:chess_app/models/analysis_models.dart';

import 'exercise.dart';

/// The server's `MAX_ACCEPTED` (`chess_backend/services/exercise.js`) — a
/// step's `accept` list never grows past this, however many moves a finding
/// offers.
const int maxAcceptedMoves = 8;

/// How much better (in pawns, from the mover's own side) the engine's choice
/// has to be than the trainer's move before it is worth a word.
const double enginePrefersByPawns = 1.5;

enum ExerciseFindingKind {
  /// Other moves keep the result too: offered for accepting.
  alsoKeeps,

  /// The trainer's own move does not keep the result: a warning, no offer.
  mainMoveLetsGo,

  /// So many moves keep the result that accepting all of them is impossible.
  tooManyKeep,

  /// A game task best play cannot meet.
  taskImpossible,

  /// The engine's choice is clearly better than the trainer's main move.
  enginePrefers,
}

/// One thing the check found, in the trainer's own words — never a category
/// or a number of centipawns.
class ExerciseFinding {
  const ExerciseFinding({
    required this.kind,
    required this.sans,
    required this.words,
  });

  final ExerciseFindingKind kind;

  /// The moves offered for accepting. Empty for a warning: nothing to apply.
  final List<String> sans;

  /// One sentence for the trainer.
  final String words;
}

String _stripDecoration(String san) => san.replaceAll(RegExp(r'[+#?!=]+$'), '');

bool _isWhiteToMove(String fen) {
  final parts = fen.trim().split(RegExp(r'\s+'));
  return parts.length < 2 || parts[1] != 'b';
}

/// „Keeps the result": the side to move wins → a move keeps it when the
/// opponent is then `loss`; it draws (draw, cursedWin, blessedLoss) → when
/// the opponent is then draw, cursedWin or blessedLoss. A side that is lost,
/// or a category that is no outcome (unknown, maybe*), yields nothing.
bool _keepsResult(SyzygyCategory position, SyzygyCategory afterMove) {
  switch (position) {
    case SyzygyCategory.win:
      return afterMove == SyzygyCategory.loss;
    case SyzygyCategory.draw:
    case SyzygyCategory.cursedWin:
    case SyzygyCategory.blessedLoss:
      return afterMove == SyzygyCategory.draw ||
          afterMove == SyzygyCategory.cursedWin ||
          afterMove == SyzygyCategory.blessedLoss;
    case SyzygyCategory.loss:
    case SyzygyCategory.unknown:
    case SyzygyCategory.maybeWin:
    case SyzygyCategory.maybeLoss:
      return false;
  }
}

/// A drawish category (draw, cursedWin, blessedLoss) reads the same word as
/// a plain draw — the trainer is never told a centipawn-shaped distinction.
bool _hasOutcome(SyzygyCategory c) =>
    c == SyzygyCategory.win ||
    c == SyzygyCategory.draw ||
    c == SyzygyCategory.cursedWin ||
    c == SyzygyCategory.blessedLoss;

String _resultWord(SyzygyCategory position) =>
    position == SyzygyCategory.win ? 'win' : 'draw';

/// [result] is the tablebase's word on the exercise's position, null where it
/// had no answer.
List<ExerciseFinding> tablebaseFindings({
  required ExerciseStep answer,
  required SyzygyResult? result,
}) {
  final findings = <ExerciseFinding>[];
  if (result == null || !_hasOutcome(result.category)) return findings;

  final acceptedNorm = answer.accept.map(_stripDecoration).toSet();
  final mainNorm = _stripDecoration(answer.accept.first);

  final keeping = [
    for (final m in result.moves)
      if (_keepsResult(result.category, m.category)) m,
  ];
  final mainIsKeeper = keeping.any((m) => _stripDecoration(m.san) == mainNorm);

  if (!mainIsKeeper) {
    findings.add(ExerciseFinding(
      kind: ExerciseFindingKind.mainMoveLetsGo,
      sans: const [],
      words: 'Your move ${answer.accept.first} lets the '
          '${_resultWord(result.category)} go.',
    ));
  }

  if (keeping.length > maxAcceptedMoves) {
    findings.add(ExerciseFinding(
      kind: ExerciseFindingKind.tooManyKeep,
      sans: const [],
      words: '${keeping.length} moves keep the '
          '${_resultWord(result.category)} here — too many to accept; '
          'this may not be an exercise.',
    ));
  } else {
    final offerable = [
      for (final m in keeping)
        if (!acceptedNorm.contains(_stripDecoration(m.san))) m.san,
    ];
    if (offerable.isNotEmpty) {
      findings.add(ExerciseFinding(
        kind: ExerciseFindingKind.alsoKeeps,
        sans: offerable,
        words: '${offerable.join(' and ')} also '
            '${offerable.length == 1 ? 'keeps' : 'keep'} the '
            '${_resultWord(result.category)}. Accept '
            '${offerable.length == 1 ? 'it' : 'them'}?',
      ));
    }
  }
  return findings;
}

/// [result] is the tablebase's word for the side TO MOVE at the exercise's
/// position; the student may be the other side.
ExerciseFinding? gameFinding({
  required Map<String, dynamic> task,
  required SyzygyResult? result,
}) {
  if (result == null || !_hasOutcome(result.category)) return null;

  final side = task['side'] as String?;
  final positionTurn = result.fen.trim().split(RegExp(r'\s+')).length > 1 &&
          result.fen.trim().split(RegExp(r'\s+'))[1] == 'b'
      ? 'b'
      : 'w';
  final studentIsMover = side == positionTurn;

  // From the mover's side: win/loss as reported, cursedWin and blessedLoss
  // read as a draw — a distinction the trainer is never asked to weigh.
  String moverOutcome;
  switch (result.category) {
    case SyzygyCategory.win:
      moverOutcome = 'win';
      break;
    case SyzygyCategory.loss:
      moverOutcome = 'loss';
      break;
    default:
      moverOutcome = 'draw';
  }
  const flip = {'win': 'loss', 'loss': 'win', 'draw': 'draw'};
  final studentOutcome = studentIsMover ? moverOutcome : flip[moverOutcome]!;

  final goal = task['goal'] as String?;
  final met =
      goal == 'win' ? studentOutcome == 'win' : studentOutcome != 'loss';
  if (met) return null;

  final goalWord = goal == 'win' ? 'Win' : 'Draw or better';
  final outcomeWord = studentOutcome == 'draw' ? 'a draw' : 'lost';
  return ExerciseFinding(
    kind: ExerciseFindingKind.taskImpossible,
    sans: const [],
    words: 'With best play this position is $outcomeWord, so "$goalWord" '
        'cannot be met against a perfect defence.',
  );
}

/// [lines] as `StockfishService.analyzePositionSync` returns them, best
/// first; their evaluation is from White's side.
ExerciseFinding? engineFinding({
  required String fen,
  required ExerciseStep first,
  required List<AnalysisLine> lines,
}) {
  if (lines.isEmpty) return null;
  final bestEvalRaw = parseEval(lines.first.evaluation);
  if (bestEvalRaw == null) return null;

  final moverSign = _isWhiteToMove(fen) ? 1.0 : -1.0;
  final bestSan = lines.first.bestMoveSan;
  final bestSanNorm = _stripDecoration(bestSan);

  final acceptedNorm = first.accept.map(_stripDecoration).toSet();
  if (acceptedNorm.contains(bestSanNorm)) return null;

  final mainNorm = _stripDecoration(first.accept.first);
  double? mainMoverEval;
  for (final line in lines) {
    if (_stripDecoration(line.bestMoveSan) == mainNorm) {
      final raw = parseEval(line.evaluation);
      if (raw != null) mainMoverEval = raw * moverSign;
      break;
    }
  }

  final bestMoverEval = bestEvalRaw * moverSign;
  final notListed = mainMoverEval == null;
  if (!notListed && (bestMoverEval - mainMoverEval) < enginePrefersByPawns) {
    return null;
  }

  return ExerciseFinding(
    kind: ExerciseFindingKind.enginePrefers,
    sans: [bestSan],
    words: 'The engine prefers $bestSan to your ${first.accept.first}. '
        'Accept it too?',
  );
}

/// [steps] with the finding's moves accepted as well, after the ones already
/// there. A finding that offers no moves returns [steps] unchanged.
List<ExerciseStep> acceptFinding(
    List<ExerciseStep> steps, ExerciseFinding finding) {
  if (finding.sans.isEmpty || steps.isEmpty) return steps;
  return [_appendAccepted(steps.first, finding.sans)];
}

ExerciseStep _appendAccepted(ExerciseStep step, List<String> sans) {
  final merged = List<String>.from(step.accept);
  final seen = merged.map(_stripDecoration).toSet();
  for (final san in sans) {
    if (merged.length >= maxAcceptedMoves) break;
    final norm = _stripDecoration(san);
    if (seen.contains(norm)) continue;
    merged.add(san);
    seen.add(norm);
  }
  return ExerciseStep(accept: merged);
}
