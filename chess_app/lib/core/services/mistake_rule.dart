/// What counts as a mistake — one rule, one home.
///
/// `docs/PLAN-MOJE-PARTIJE.md` §9.1, and the first bullet of phase 1 of
/// `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`: the review's `??` marks, its puzzles,
/// its comments, the tutorial's moments and the habits of a player's own
/// opening tree all ask this file, and none of them keeps a copy (rule 12).
///
/// **The scale is winning chances, not pawns.** +19 against +14 is five pawns
/// and no difference at all; +1 against −1 is two pawns and a game changing
/// hands. The curve is the one Lichess fits to its players' games.
///
/// **The numbers are the owner's choices of 24.9.2026**, each measured in
/// phase 0 of the puzzle plan: `A` 10 (96–98% of marks at depth 20 confirmed at
/// depth 24, on three levels of play), `A_gross` 20 and 10 master games for
/// theory (no book move of 52 games lost 15), a forced mate in five or fewer
/// (the owner's missed mates were in two to four).
library;

import 'dart:math' as math;

/// A loss of at least this many chances is a mistake.
const double kMistakeLoss = 10;

/// In theory — a move the masters played at least [kTheoryGames] times — only
/// a loss of this many chances is a mistake.
const double kGrossLossInBook = 20;

/// How many master games make a move theory.
const int kTheoryGames = 10;

/// A forced mate in this many moves or fewer, left by the player, is a mistake
/// whatever the chances say — they put a mate at 100 and a crushing position at
/// 95, so leaving one loses too little to be seen.
const int kMissedMateMoves = 5;

/// A position is decided when the side to move has at least this many chances,
/// or at most `100 −` this many.
const double kDecidedChances = 97;

/// The engine's value of a line for the side to move: centipawns or a mate.
class EngineValue {
  const EngineValue.cp(int this.cp) : mate = null;
  const EngineValue.mate(int this.mate) : cp = null;

  /// From the app's own spelling — [AnalysisLine.evaluation], always from
  /// White's side: `+1.39`, `-0.35`, `0.00`, `M3`, `-M2` — to the side to
  /// move's view. Anything else is refused: an evaluation read as 0 would
  /// judge a move against a position the engine never gave.
  factory EngineValue.fromEvaluation(String evaluation,
      {required bool whiteToMove}) {
    final raw = evaluation.trim();
    final mate = RegExp(r'^(-)?M(\d+)$').firstMatch(raw);
    final sign = whiteToMove ? 1 : -1;
    if (mate != null) {
      final white =
          int.parse(mate.group(2)!) * (mate.group(1) == null ? 1 : -1);
      return EngineValue.mate(white * sign);
    }
    final pawns = double.tryParse(raw);
    if (pawns == null) {
      throw FormatException('Not an evaluation', evaluation);
    }
    return EngineValue.cp((pawns * 100).round() * sign);
  }

  final int? cp;

  /// Moves to mate; positive when the side to move mates.
  final int? mate;
}

/// Winning chances for the side to move, 0 to 100. A mate is 100 or 0 whatever
/// its distance: a slower mate is still a mate.
double winningChances(EngineValue value) {
  final mate = value.mate;
  if (mate != null) return mate > 0 ? 100 : 0;
  return 50 + 50 * (2 / (1 + math.exp(-0.00368208 * value.cp!)) - 1);
}

/// What a value is worth in centipawns for the drill's „Loss: N cp" and its
/// ranking, capped at a thousand either way as Lichess counts an average loss:
/// a mate is a thousand, not infinity. The judgement itself is in chances;
/// this is only the number the drill has always shown.
const int kCentipawnCap = 1000;

int _cappedCentipawns(EngineValue value) {
  final mate = value.mate;
  if (mate != null) return mate > 0 ? kCentipawnCap : -kCentipawnCap;
  return value.cp!.clamp(-kCentipawnCap, kCentipawnCap);
}

/// The played move's loss against the best in capped centipawns, never below
/// zero.
int lossInCentipawns(
        {required EngineValue best, required EngineValue played}) =>
    math.max(0, _cappedCentipawns(best) - _cappedCentipawns(played));

/// Whether a position with [chances] for the side to move is already decided.
bool isDecided(double chances) =>
    chances >= kDecidedChances || chances <= 100 - kDecidedChances;

enum MistakeReason {
  /// Lost at least [kMistakeLoss] chances out of the book.
  lostChances,

  /// Lost at least [kGrossLossInBook] chances with a move the masters play.
  grossInBook,

  /// Left a forced mate in [kMissedMateMoves] or fewer.
  missedMate,

  /// With [kTablebaseMen] or fewer, made the result worse.
  worseResult,
}

class MoveJudgement {
  const MoveJudgement(this.lostChances, this.reason);

  /// `W(best) − W(played)`, never below zero.
  final double lostChances;

  /// Why it is a mistake; null when it is not one.
  final MistakeReason? reason;

  bool get isMistake => reason != null;
}

/// Judges the move played against the best, from the side to move's view.
/// [bookGames] is how many master games played this move here.
MoveJudgement judgeMove({
  required EngineValue best,
  required EngineValue played,
  int bookGames = 0,
}) {
  final lost = math.max(0.0, winningChances(best) - winningChances(played));
  final bestMate = best.mate;
  final playedMates = (played.mate ?? 0) > 0;
  if (bestMate != null &&
      bestMate > 0 &&
      bestMate <= kMissedMateMoves &&
      !playedMates) {
    return MoveJudgement(lost, MistakeReason.missedMate);
  }
  if (bookGames >= kTheoryGames) {
    return MoveJudgement(
        lost, lost >= kGrossLossInBook ? MistakeReason.grossInBook : null);
  }
  return MoveJudgement(
      lost, lost >= kMistakeLoss ? MistakeReason.lostChances : null);
}

// --- The review's second look (docs/PLAN-ZAGONETKE-IZ-PARTIJE.md, 1.2a) ----

/// How far below its threshold a move's loss at the walk's depth may be and
/// still be looked at again: two of 35 grandmaster moves that lost 5–10 at
/// depth 16 lost 15 or more at depth 24 (phase 0).
const double kCandidateMargin = 5;

/// Two depths disagree about a move when its losses differ by more than this
/// — or when one calls it a mistake and the other does not. The owner's gap
/// of 24.9.2026: 3 deepened twice as many positions for no fewer errors.
const double kDeepenGap = 5;

/// With this many men or fewer, the tablebase knows the result and the engine's
/// number is only an estimate of it.
const int kTablebaseMen = 7;

/// Whether a move judged [judgement] at the walk's depth is looked at again:
/// its loss is within [kCandidateMargin] of the threshold that applies to it,
/// or it is a mistake for another reason (a missed mate).
bool isCandidate(MoveJudgement judgement, {int bookGames = 0}) {
  if (judgement.isMistake) return true;
  final threshold = bookGames >= kTheoryGames ? kGrossLossInBook : kMistakeLoss;
  return judgement.lostChances >= threshold - kCandidateMargin;
}

/// Whether two depths' judgements of one move agree.
bool judgementsAgree(MoveJudgement a, MoveJudgement b) =>
    a.isMistake == b.isMistake &&
    (a.lostChances - b.lostChances).abs() <= kDeepenGap;

/// A result the tablebase knows, for the side to move.
enum TablebaseOutcome { loss, draw, win }

/// Judges a move by the result alone: a mistake when it makes the result worse
/// than the position's — a win given away for a draw, a draw for a loss —
/// however small the engine's number; a slower win is not one. [lostChances]
/// is carried for the reader, and decides nothing here.
MoveJudgement judgeByTablebase({
  required TablebaseOutcome position,
  required TablebaseOutcome played,
  required double lostChances,
}) =>
    MoveJudgement(lostChances,
        played.index < position.index ? MistakeReason.worseResult : null);
