/// The puzzles a review keeps — `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`, phase 1.3.
///
/// Until this phase a puzzle was the position *after* a mistake, one answer,
/// taken from every mistake the review marked, worst first
/// (`buildPuzzlesFromReview`'s old shape, `docs/PLAN-MATERIJAL.md` phase 4).
/// The owner's request of 23.9.2026 reverses the first half: the position
/// *before* the mistake, and only where one move stands out — "+19 against
/// +14 is no difference at all" (§1, §3). A puzzle now needs both criteria:
/// the review's own judgement that the player erred (or, for a move the
/// player found, that they did not), and one move at least `B` = [kStandsOut]
/// chances clear of the second, with the same best move at the walk's depth
/// and at the deciding one. A mate is answered by every mating first move
/// that beats the best non-mating alternative by `B`; nothing trivial is
/// taught as a find; a chance missed again within four plies is one puzzle;
/// the only moves a player found are puzzles of their own, listed and capped
/// apart from the mistakes.
///
/// **The writer reads its own work back** (§4): every answer and every line is
/// replayed from the puzzle's own position before a puzzle is made; one that
/// does not play makes no puzzle and is counted in [ReviewPuzzles.unplayable].
library;

import 'dart:math' as math;

import 'package:chess/chess.dart' as chess;

import 'package:chess_app/core/services/answer_line.dart' show revealLine;
import 'package:chess_app/core/services/game_analysis_walker_service.dart'
    show BlunderAlertSide;
import 'package:chess_app/core/services/game_review_judge.dart';
import 'package:chess_app/core/services/legal_moves.dart' show legalMoves;
import 'package:chess_app/core/services/mistake_rule.dart';
import 'package:chess_app/models/analysis_models.dart';

enum PuzzleKind { mistake, onlyMove }

/// Shown before the student moves — never names the game's move (§4).
const kMistakeInstruction =
    'A mistake was made in this position. Find the best move.';

/// The instruction for a puzzle made from a move the player found (§3, "The
/// only moves a player found") — never "a mistake was made".
const kOnlyMoveInstruction =
    'The player found the only good move here. Find it.';

/// One puzzle a review's judgement kept, the position *before* the game's
/// move — `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`, §4.
class LocalPuzzle {
  const LocalPuzzle({
    required this.id,
    required this.kind,
    required this.fen,
    required this.sourcePlyIndex,
    required this.playedSan,
    required this.playedUci,
    required this.answers,
    this.bestLine = const [],
    this.refutationLine = const [],
    this.secondLine = const [],
    required this.bestChances,
    required this.playedChances,
    this.secondChances,
    this.trivial = false,
    this.missedTimes = 1,
    this.words,
  });

  final String id;
  final PuzzleKind kind;

  /// The position *before* the game's move — the puzzle the student solves.
  final String fen;
  final int sourcePlyIndex;

  /// The game's own move, never shown until the student has answered.
  final String playedSan;
  final String playedUci;

  /// Every right answer, SAN, the best first — a mate may have more than one
  /// forcing first move.
  final List<String> answers;

  /// The line behind the best move, SAN, cut by [revealLine] from [fen].
  final List<String> bestLine;

  /// The line after the game's move — the punishment — SAN, cut by
  /// [revealLine] from the position after it.
  final List<String> refutationLine;

  /// The engine's second line from the confirming search, SAN, cut the same
  /// way — the move a solver is most likely to play instead. Empty when
  /// there is none (a tablebase puzzle with exactly one keeper).
  final List<String> secondLine;

  final double bestChances;
  final double playedChances;

  /// Null when there is no second line.
  final double? secondChances;

  /// A recapture, a move out of check, or three legal moves or fewer — never
  /// true for an only move ([kind] is always [PuzzleKind.mistake] here).
  final bool trivial;

  /// How many times, within 4 plies, the same player missed this chance.
  final int missedTimes;

  /// The language model's explanation, judged by the claim check — null when
  /// the review asked for none or none was kept (phase 3). Absent, never an
  /// empty string that would read as an explanation with nothing in it.
  final String? words;

  /// This puzzle with [words] as its explanation.
  LocalPuzzle withWords(String? words) => LocalPuzzle(
        id: id,
        kind: kind,
        fen: fen,
        sourcePlyIndex: sourcePlyIndex,
        playedSan: playedSan,
        playedUci: playedUci,
        answers: answers,
        bestLine: bestLine,
        refutationLine: refutationLine,
        secondLine: secondLine,
        bestChances: bestChances,
        playedChances: playedChances,
        secondChances: secondChances,
        trivial: trivial,
        missedTimes: missedTimes,
        words: words,
      );

  /// The instruction shown before solving, by [kind].
  String get instruction =>
      kind == PuzzleKind.mistake ? kMistakeInstruction : kOnlyMoveInstruction;

  /// `max(0, bestChances − playedChances)`.
  double get lostChances => math.max(0.0, bestChances - playedChances);
}

/// The puzzles a review kept, mistakes and only moves capped apart
/// ("Only moves are capped by *Max puzzles* on their own", the brief of
/// phase 1.3).
class ReviewPuzzles {
  const ReviewPuzzles({
    this.mistakes = const [],
    this.onlyMoves = const [],
    this.unplayable = 0,
  });

  final List<LocalPuzzle> mistakes;
  final List<LocalPuzzle> onlyMoves;

  /// A line whose answer or line did not replay from its own position — never
  /// made a puzzle, never counted twice.
  final int unplayable;

  /// The mistakes, then the only moves.
  List<LocalPuzzle> get all => [...mistakes, ...onlyMoves];
}

/// What one attempt at a puzzle found: [puzzle], or [unplayable] when a line
/// that would have made one failed to replay.
class _Attempt {
  const _Attempt({this.puzzle, this.unplayable = false});
  final LocalPuzzle? puzzle;
  final bool unplayable;
}

const _noAttempt = _Attempt();
_Attempt _failedReplay() => const _Attempt(unplayable: true);
_Attempt _madePuzzle(LocalPuzzle p) => _Attempt(puzzle: p);

class LocalPuzzleExtractorService {
  /// The puzzles a review's judgement kept: the mistakes where one move
  /// stands out, and the only moves the player found — `docs/PLAN-ZAGONETKE-
  /// IZ-PARTIJE.md`, phase 1.3.
  ReviewPuzzles buildPuzzlesFromReview(
    GameReviewResult result, {
    required int maxPuzzles,
    BlunderAlertSide side = BlunderAlertSide.both,
  }) {
    var unplayable = 0;

    bool sideMatches(bool whiteMoved) => switch (side) {
          BlunderAlertSide.both => true,
          BlunderAlertSide.white => whiteMoved,
          BlunderAlertSide.black => !whiteMoved,
        };

    String? previousUciFor(int ply) =>
        ply > 0 ? result.moves[ply - 1].uci : null;

    final rawMistakes = <LocalPuzzle>[];
    for (final m in result.moves) {
      if (!m.isMistake || !sideMatches(m.whiteMoved)) continue;
      final attempt = _mistakePuzzle(m, previousUciFor(m.ply));
      if (attempt.unplayable) unplayable++;
      if (attempt.puzzle != null) rawMistakes.add(attempt.puzzle!);
    }

    final grouped = _groupMissedChances(rawMistakes);
    grouped.sort((a, b) {
      final trivialCmp = (a.trivial ? 1 : 0).compareTo(b.trivial ? 1 : 0);
      if (trivialCmp != 0) return trivialCmp;
      final lostCmp = b.lostChances.compareTo(a.lostChances);
      if (lostCmp != 0) return lostCmp;
      return a.sourcePlyIndex.compareTo(b.sourcePlyIndex);
    });
    final mistakes = grouped.take(maxPuzzles).toList();

    final rawOnlyMoves = <LocalPuzzle>[];
    for (final m in result.moves) {
      if (m.judgement == null || m.unsettled || m.isMistake) continue;
      if (!sideMatches(m.whiteMoved)) continue;
      final attempt = _onlyMovePuzzle(m, previousUciFor(m.ply));
      if (attempt.unplayable) unplayable++;
      if (attempt.puzzle != null) rawOnlyMoves.add(attempt.puzzle!);
    }
    rawOnlyMoves.sort((a, b) {
      final ag =
          a.secondChances == null ? null : a.bestChances - a.secondChances!;
      final bg =
          b.secondChances == null ? null : b.bestChances - b.secondChances!;
      if (ag == null && bg == null) {
        return a.sourcePlyIndex.compareTo(b.sourcePlyIndex);
      }
      if (ag == null) return 1;
      if (bg == null) return -1;
      final gapCmp = bg.compareTo(ag);
      return gapCmp != 0
          ? gapCmp
          : a.sourcePlyIndex.compareTo(b.sourcePlyIndex);
    });
    final onlyMoves = rawOnlyMoves.take(maxPuzzles).toList();

    return ReviewPuzzles(
      mistakes: mistakes,
      onlyMoves: onlyMoves,
      unplayable: unplayable,
    );
  }

  // --- A mistake becomes a puzzle -----------------------------------------

  _Attempt _mistakePuzzle(ReviewedMove m, String? previousUci) {
    if (m.byTablebase) return _tablebaseMistake(m, previousUci);
    return _engineMistake(m, previousUci);
  }

  _Attempt _tablebaseMistake(ReviewedMove m, String? previousUci) {
    final keepers = m.tablebaseKeepers;
    final best = m.bestLine;
    if (keepers == null || keepers.length != 1 || best == null) {
      return _noAttempt;
    }
    if (best.bestMoveLan != keepers.first) return _noAttempt;
    final bestChances = winningChances(
      EngineValue.fromEvaluation(best.evaluation, whiteToMove: m.whiteMoved),
    );
    return _finish(
      m,
      kind: PuzzleKind.mistake,
      answers: [best.bestMoveSan],
      bestLine: best,
      secondLine: null,
      bestChances: bestChances,
      secondChances: null,
      previousUci: previousUci,
    );
  }

  _Attempt _engineMistake(ReviewedMove m, String? previousUci) {
    final best = m.bestLine;
    final second = m.secondLine;
    if (best == null || second == null) return _noAttempt;
    final whiteBefore = m.whiteMoved;

    if (_matesForMover(best, whiteBefore)) {
      final lines = [best, second, if (m.thirdLine != null) m.thirdLine!];
      final matingLines = <AnalysisLine>[];
      for (final line in lines) {
        if (_matesForMover(line, whiteBefore)) {
          matingLines.add(line);
        } else {
          break;
        }
      }
      if (matingLines.length == lines.length) return _noAttempt;
      final matingUcis = [for (final l in matingLines) l.bestMoveLan];
      if (m.walkBestUci == null || !matingUcis.contains(m.walkBestUci)) {
        return _noAttempt;
      }
      final nonMating = lines[matingLines.length];
      const bestChances = 100.0;
      final secondChances = winningChances(
        EngineValue.fromEvaluation(
          nonMating.evaluation,
          whiteToMove: whiteBefore,
        ),
      );
      if (bestChances - secondChances < kStandsOut) return _noAttempt;
      return _finish(
        m,
        kind: PuzzleKind.mistake,
        answers: [for (final l in matingLines) l.bestMoveSan],
        bestLine: best,
        secondLine: nonMating,
        bestChances: bestChances,
        secondChances: secondChances,
        previousUci: previousUci,
      );
    }

    if (m.walkBestUci != best.bestMoveLan) return _noAttempt;
    final bestChances = winningChances(
      EngineValue.fromEvaluation(best.evaluation, whiteToMove: whiteBefore),
    );
    final secondChances = winningChances(
      EngineValue.fromEvaluation(second.evaluation, whiteToMove: whiteBefore),
    );
    if (bestChances - secondChances < kStandsOut) return _noAttempt;
    return _finish(
      m,
      kind: PuzzleKind.mistake,
      answers: [best.bestMoveSan],
      bestLine: best,
      secondLine: second,
      bestChances: bestChances,
      secondChances: secondChances,
      previousUci: previousUci,
    );
  }

  // --- The only moves a player found --------------------------------------

  _Attempt _onlyMovePuzzle(ReviewedMove m, String? previousUci) {
    if (m.walkBestUci != m.uci) return _noAttempt;
    if ((m.bookGames ?? 0) >= kTheoryGames) return _noAttempt;

    AnalysisLine? best;
    AnalysisLine? second;
    if (m.byTablebase) {
      final keepers = m.tablebaseKeepers;
      if (keepers == null || keepers.length != 1 || keepers.first != m.uci) {
        return _noAttempt;
      }
      final line = m.bestLine;
      if (line == null || line.bestMoveLan != m.uci) return _noAttempt;
      best = line;
    } else {
      final line = m.bestLine;
      final sec = m.secondLine;
      if (line == null || line.bestMoveLan != m.uci || sec == null) {
        return _noAttempt;
      }
      best = line;
      second = sec;
    }

    final bestChances = winningChances(
      EngineValue.fromEvaluation(best.evaluation, whiteToMove: m.whiteMoved),
    );
    if (isDecided(bestChances)) return _noAttempt;

    double? secondChances;
    if (second != null) {
      secondChances = winningChances(
        EngineValue.fromEvaluation(
          second.evaluation,
          whiteToMove: m.whiteMoved,
        ),
      );
      if (bestChances - secondChances < kStandsOut) return _noAttempt;
    }

    if (isTrivialFind(m.fenBefore, m.uci, previousUci: previousUci)) {
      return _noAttempt;
    }

    return _finish(
      m,
      kind: PuzzleKind.onlyMove,
      answers: [m.san],
      bestLine: best,
      secondLine: second,
      bestChances: bestChances,
      secondChances: secondChances,
      previousUci: previousUci,
      playedChancesOverride: bestChances,
    );
  }

  // --- Shared: replay, cut the lines, build the puzzle --------------------

  _Attempt _finish(
    ReviewedMove m, {
    required PuzzleKind kind,
    required List<String> answers,
    required AnalysisLine bestLine,
    required AnalysisLine? secondLine,
    required double bestChances,
    required double? secondChances,
    required String? previousUci,
    double? playedChancesOverride,
  }) {
    final fen = m.fenBefore;
    final answerUcis = <String>[];
    for (final san in answers) {
      final uci = _sanToUci(fen, san);
      if (uci == null) return _failedReplay();
      answerUcis.add(uci);
    }
    final bestCut = _tryCut(fen, bestLine.sanMoveList);
    if (bestCut == null) return _failedReplay();
    var secondCut = const <String>[];
    if (secondLine != null) {
      final cut = _tryCut(fen, secondLine.sanMoveList);
      if (cut == null) return _failedReplay();
      secondCut = cut;
    }
    var refutationCut = const <String>[];
    final reply = m.replyLine;
    if (kind == PuzzleKind.mistake && reply != null) {
      final cut = _tryCut(m.fenAfter, reply.sanMoveList);
      if (cut == null) return _failedReplay();
      refutationCut = cut;
    }

    final trivial = kind == PuzzleKind.mistake &&
        isTrivialFind(fen, answerUcis.first, previousUci: previousUci);
    final playedChances = playedChancesOverride ??
        (bestChances - (m.judgement?.lostChances ?? 0));

    return _madePuzzle(
      LocalPuzzle(
        id: '${kind == PuzzleKind.mistake ? 'mistake' : 'only'}_${m.ply}',
        kind: kind,
        fen: fen,
        sourcePlyIndex: m.ply,
        playedSan: m.san,
        playedUci: m.uci,
        answers: answers,
        bestLine: bestCut,
        secondLine: secondCut,
        refutationLine: refutationCut,
        bestChances: bestChances,
        playedChances: playedChances,
        secondChances: secondChances,
        trivial: trivial,
      ),
    );
  }

  /// A chance missed again within four plies, by the same player, is one
  /// puzzle — the first of them, with [LocalPuzzle.missedTimes] the chain's
  /// length. [puzzles] must already be in ply order.
  List<LocalPuzzle> _groupMissedChances(List<LocalPuzzle> puzzles) {
    final result = <LocalPuzzle>[];
    LocalPuzzle? chainFirst;
    String? chainSide;
    var chainLastPly = 0;
    var chainCount = 0;

    void flush() {
      final first = chainFirst;
      if (first == null) return;
      result.add(chainCount > 1 ? _withMissedTimes(first, chainCount) : first);
    }

    for (final p in puzzles) {
      final side = _sideToMove(p.fen);
      if (chainFirst != null &&
          side == chainSide &&
          p.sourcePlyIndex - chainLastPly <= 4) {
        chainCount++;
        chainLastPly = p.sourcePlyIndex;
      } else {
        flush();
        chainFirst = p;
        chainSide = side;
        chainLastPly = p.sourcePlyIndex;
        chainCount = 1;
      }
    }
    flush();
    return result;
  }
}

bool _matesForMover(AnalysisLine line, bool whiteBefore) {
  final mate = EngineValue.fromEvaluation(
    line.evaluation,
    whiteToMove: whiteBefore,
  ).mate;
  return mate != null && mate > 0;
}

String _sideToMove(String fen) => fen.trim().split(RegExp(r'\s+'))[1];

LocalPuzzle _withMissedTimes(LocalPuzzle p, int times) => LocalPuzzle(
      id: p.id,
      kind: p.kind,
      fen: p.fen,
      sourcePlyIndex: p.sourcePlyIndex,
      playedSan: p.playedSan,
      playedUci: p.playedUci,
      answers: p.answers,
      bestLine: p.bestLine,
      refutationLine: p.refutationLine,
      secondLine: p.secondLine,
      bestChances: p.bestChances,
      playedChances: p.playedChances,
      secondChances: p.secondChances,
      trivial: p.trivial,
      missedTimes: times,
      words: p.words,
    );

/// The UCI of the legal move in [fen] whose SAN is [san], or null when none
/// plays — the writer reads its own work back before a puzzle is made.
String? _sanToUci(String fen, String san) {
  try {
    final board = chess.Chess.fromFEN(fen);
    for (final move in legalMoves(board)) {
      if (move['san'] == san) {
        return '${move['from']}${move['to']}${move['promotion'] ?? ''}';
      }
    }
  } catch (_) {
    // Falls through to null.
  }
  return null;
}

/// [revealLine] guarded: null when a move in [line] does not play from [fen].
List<String>? _tryCut(String fen, List<String> line) {
  try {
    return revealLine(fen, line);
  } catch (_) {
    return null;
  }
}
