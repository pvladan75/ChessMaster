/// The review's judgement of a game — `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`,
/// phase 1.2a.
///
/// Every move of a game judged by the one mistake rule
/// (`mistake_rule.dart`, rule 12): walked at the review's depth, the opening
/// judged by the masters book, seven men or fewer by the tablebase, and every
/// move that comes near a threshold looked at again — confirmed at the same
/// depth, and deepened where the two looks disagree, within a budget counted
/// in searches so the phone and the desktop settle the same work.
///
/// **No UI, no HTTP.** The engine, the book and the tablebase are injected, so
/// the whole judgement is held by pure tests (`game_review_judge_test.dart`).
library;

import 'dart:math' as math;

import 'package:chess/chess.dart' as chess;

import 'package:chess_app/core/services/eval_cache.dart' show MoveAnalyzer;
import 'package:chess_app/core/services/game_analysis_walker_service.dart'
    show BlunderAlertSide;
import 'package:chess_app/core/services/legal_moves.dart' show walkGame;
import 'package:chess_app/core/services/mistake_rule.dart';
import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart'
    show SyzygyCategory, SyzygyMove, SyzygyResult;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/game_facts.dart'
    show searchProblem;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/masters_walk.dart'
    show MastersWalk, totalOf;
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/services/app_logger.dart';

/// The deepening's budget, in searches — the same on every device. Derived in
/// the plan (1.2a) from the owner's three minutes on the idle desktop.
const int kDeepeningSearches = 24;

/// Each deepening goes this much deeper than the last look.
const int kDeepenStep = 4;

/// At most this many deepenings of one move; a move still disagreeing after
/// them is unsettled.
const int kDeepenLevels = 3;

/// A search that did not answer is asked once more this much shallower.
const int kRetryShallower = 4;

/// How long one search may take before it is stopped and what it had is
/// returned — a guard against an engine that stopped answering, not a budget:
/// the phone is five times slower than the desktop, and a search stopped
/// early is a shorter answer, which the review then refuses.
const Duration kWalkTimeout = Duration(seconds: 60);
const Duration kConfirmTimeout = Duration(seconds: 120);
const Duration kDeepenTimeout = Duration(seconds: 300);

/// The masters book for a game's positions, as `walkMastersBook` answers it.
typedef BookLookup = Future<MastersWalk> Function(List<String> fens);

/// The tablebase's answer for a position, or null when it did not answer.
typedef TablebaseLookup = Future<SyzygyResult?> Function(String fen);

/// [words] is the runner's, not the judge's: the comments asked of the
/// server once the judgement is done (phase 3).
enum ReviewStage { walk, book, tablebase, confirm, deepen, answers, words }

/// Where a review is: [done] of [total] in [stage]. For [ReviewStage.deepen]
/// the total is the budget, and done the searches spent.
class ReviewProgress {
  const ReviewProgress(this.stage, this.done, this.total);

  final ReviewStage stage;
  final int done;
  final int total;
}

/// One move of the game, judged.
class ReviewedMove {
  const ReviewedMove({
    required this.ply,
    required this.san,
    required this.uci,
    required this.fenBefore,
    required this.fenAfter,
    required this.whiteMoved,
    this.judgement,
    this.unjudgedWhy,
    this.unsettled = false,
    this.depth,
    this.nodes,
    this.bestLine,
    this.replyLine,
    this.secondLine,
    this.thirdLine,
    this.bookGames,
    this.byTablebase = false,
    this.deepened = false,
    this.walkBestUci,
    this.tablebaseKeepers,
  });

  /// Index of the move among the moves reviewed, from 0.
  final int ply;
  final String san;
  final String uci;
  final String fenBefore;
  final String fenAfter;
  final bool whiteMoved;

  /// The judgement the review stands on: the deepest look's for a move looked
  /// at again, the walk's for any other. Null when the move could not be
  /// judged ([unjudgedWhy] says why).
  final MoveJudgement? judgement;
  final String? unjudgedWhy;

  /// A move whose looks still disagreed when the budget or the levels ran
  /// out. Never a mistake; counted. Its [judgement] is the deepest look's.
  final bool unsettled;

  /// The depth the judgement stands on — the shallowest line it read. Null
  /// when unjudged, and for a judgement by the rules alone (a mate on the
  /// board) the depth of the position before.
  final int? depth;

  /// The nodes the deciding search reported, when it was searched and the
  /// engine said; null when the answer came from the store.
  final int? nodes;

  /// The best line in the position before the move, from the deepest look —
  /// what the review inserts as „Better move".
  final AnalysisLine? bestLine;

  /// The best line in the position after the move — the punishment, and
  /// today's puzzle answer.
  final AnalysisLine? replyLine;

  /// The engine's second line in the position before, when a confirming
  /// search asked for two (phase 1.3 reads it).
  final AnalysisLine? secondLine;

  /// A third line in the position before, when a puzzle search asked for one
  /// — a mistake whose two deciding lines both mate (phase 1.3).
  final AnalysisLine? thirdLine;

  /// Master games with the played move in the position before; null outside
  /// the book, or when the book did not answer.
  final int? bookGames;

  /// Judged by the tablebase, not the engine.
  final bool byTablebase;

  /// Searched deeper than the review's depth.
  final bool deepened;

  /// The walk's own best move in the position before (its line 1's first
  /// move), whatever a later look said. Null when the walk did not answer
  /// there.
  final String? walkBestUci;

  /// For a move judged by the tablebase: the UCI of every move whose result,
  /// read for the mover, equals the position's own — in the tablebase's own
  /// order. Null when the move was not judged by the tablebase, or the
  /// tablebase did not answer there.
  final List<String>? tablebaseKeepers;

  bool get isMistake => !unsettled && (judgement?.isMistake ?? false);
}

class GameReviewResult {
  const GameReviewResult({
    required this.moves,
    required this.reviewDepth,
    this.bookUnavailable,
    this.tablebaseUnanswered = 0,
    this.deepeningSearches = 0,
  });

  final List<ReviewedMove> moves;

  /// The depth the review was asked for.
  final int reviewDepth;

  /// Why the book could not be asked (`walkMastersBook`'s reason), or null.
  final String? bookUnavailable;

  /// Positions of seven men or fewer the tablebase did not settle; the engine
  /// judged them.
  final int tablebaseUnanswered;

  /// Searches the deepening spent of its budget.
  final int deepeningSearches;

  /// The smallest depth over the judged moves — what „no mistake found at
  /// depth N" may claim. Null when nothing was judged.
  int? get depth {
    int? least;
    for (final m in moves) {
      final d = m.depth;
      if (m.judgement == null || d == null) continue;
      if (least == null || d < least) least = d;
    }
    return least;
  }

  int get unsettled => moves.where((m) => m.unsettled).length;
  int get unjudged => moves.where((m) => m.judgement == null).length;
  int get mistakes => moves.where((m) => m.isMistake).length;

  /// Nothing marked, nothing unsettled, nothing unjudged — among the moves
  /// [include] keeps (all of them when null).
  bool cleanWhere([bool Function(ReviewedMove move)? include]) {
    for (final m in moves) {
      if (include != null && !include(m)) continue;
      if (m.isMistake || m.unsettled || m.judgement == null) return false;
    }
    return true;
  }
}

class GameReviewJudge {
  GameReviewJudge({
    required this.analyzer,
    required this.book,
    required this.tablebase,
    this.deepeningBudget = kDeepeningSearches,
  });

  /// The engine, asked through the store (`EvalCache.wrapMoves`).
  final MoveAnalyzer analyzer;
  final BookLookup book;
  final TablebaseLookup tablebase;

  /// Searches the deepening may spend.
  final int deepeningBudget;

  bool _cancelled = false;

  /// Stops a review under way; [review] then answers null.
  void cancel() => _cancelled = true;

  /// Judges the moves [uciMoves] played from [startingFen], at [depth]. Null
  /// when cancelled. The moves stop at the first one that cannot be played,
  /// as the walk has always done.
  Future<GameReviewResult?> review({
    required String startingFen,
    required List<String> uciMoves,
    required int depth,
    BlunderAlertSide? puzzles,
    void Function(ReviewProgress progress)? onProgress,
  }) async {
    _cancelled = false;

    final walked = walkGame(startingFen: startingFen, uciMoves: uciMoves);
    final fens = walked.fens;
    final sans = walked.sans;
    final appliedUci = walked.appliedUci;
    final n = appliedUci.length;
    final total = fens.length; // n + 1

    if (n == 0) return GameReviewResult(moves: const [], reviewDepth: depth);

    final whiteToMove = [for (final f in fens) f.split(' ')[1] == 'w'];

    // Terminal positions are judged by the rules, never searched.
    final terminals = List<_Terminal?>.filled(total, null);
    for (var i = 0; i < total; i++) {
      final board = chess.Chess.fromFEN(fens[i]);
      if (board.in_checkmate) {
        terminals[i] = _Terminal.mate;
      } else if (board.in_stalemate || board.insufficient_material) {
        terminals[i] = _Terminal.draw;
      }
    }

    // --- The walk: every non-terminal position, one line, at depth. --------
    final walkAnswers = List<_Usable?>.filled(total, null);
    final positionValue = List<EngineValue?>.filled(total, null);
    final positionDepth = List<int?>.filled(total, null);
    for (var i = 0; i < total; i++) {
      if (_cancelled) return null;
      if (terminals[i] == null) {
        walkAnswers[i] = await _searchWithRetry(
          fens[i],
          depth: depth,
          multiPv: 1,
          timeout: kWalkTimeout,
        );
        if (walkAnswers[i] != null) {
          positionValue[i] = EngineValue.fromEvaluation(
            walkAnswers[i]!.line1.evaluation,
            whiteToMove: whiteToMove[i],
          );
          positionDepth[i] = walkAnswers[i]!.line1.depth;
        }
      }
      onProgress?.call(ReviewProgress(ReviewStage.walk, i + 1, total));
    }
    if (_cancelled) return null;

    // --- Per-move raw values from the walk alone ----------------------------
    final bestValue = List<EngineValue?>.filled(n, null);
    final playedValueWalk = List<EngineValue?>.filled(n, null);
    final walkDepth = List<int?>.filled(n, null);
    final unjudgedWhy = List<String?>.filled(n, null);

    // The walk's own best move in the position before — kept beside whatever
    // a later look says, so "the same best move at both depths" (1.3) can be
    // asked afterwards.
    final walkBestUci = [
      for (var i = 0; i < n; i++) walkAnswers[i]?.line1.bestMoveLan,
    ];

    for (var i = 0; i < n; i++) {
      final beforeValue = positionValue[i];
      final afterTerm = terminals[i + 1];
      final afterValue = positionValue[i + 1];
      if (beforeValue == null) {
        unjudgedWhy[i] = 'the position before it was never answered';
        continue;
      }
      if (afterTerm == null && afterValue == null) {
        unjudgedWhy[i] = 'the position after it was never answered';
        continue;
      }
      bestValue[i] = beforeValue;
      if (afterTerm != null) {
        playedValueWalk[i] = afterTerm == _Terminal.mate
            ? const EngineValue.mate(1)
            : const EngineValue.cp(0);
        walkDepth[i] = positionDepth[i];
      } else {
        playedValueWalk[i] = _negate(afterValue!);
        final bd = positionDepth[i];
        final ad = positionDepth[i + 1];
        walkDepth[i] = bd == null ? ad : (ad == null ? bd : math.min(bd, ad));
      }
    }

    // --- The book, once for the whole game ----------------------------------
    if (_cancelled) return null;
    String? bookUnavailable;
    var known = const <String, Map<String, dynamic>>{};
    try {
      final result = await book(fens);
      known = result.known;
      bookUnavailable = result.unavailable;
    } catch (_) {
      bookUnavailable = 'error';
    }
    onProgress?.call(const ReviewProgress(ReviewStage.book, 1, 1));

    final bookGames = List<int?>.filled(n, null);
    for (var i = 0; i < n; i++) {
      final data = known[fens[i]];
      if (data == null) continue;
      var games = 0;
      final moves = data['moves'];
      if (moves is List) {
        for (final m in moves) {
          if (m is Map && m['san'] == sans[i]) {
            games = totalOf(m);
            break;
          }
        }
      }
      bookGames[i] = games;
    }

    // The walk's own judgement, now that theory is known.
    final walkJudgement = List<MoveJudgement?>.filled(n, null);
    for (var i = 0; i < n; i++) {
      final best = bestValue[i];
      final played = playedValueWalk[i];
      if (best == null || played == null) continue;
      walkJudgement[i] = judgeMove(
        best: best,
        played: played,
        bookGames: bookGames[i] ?? 0,
      );
    }

    // --- The tablebase, seven men or fewer -----------------------------------
    var tablebaseUnanswered = 0;
    final byTablebase = List<bool>.filled(n, false);
    final tablebaseJudgement = List<MoveJudgement?>.filled(n, null);
    final tablebaseKeepers = List<List<String>?>.filled(n, null);
    final eligible = [
      for (var i = 0; i < n; i++)
        if (_menCount(fens[i]) <= kTablebaseMen) i,
    ];
    for (var k = 0; k < eligible.length; k++) {
      if (_cancelled) return null;
      final i = eligible[k];
      SyzygyResult? tb;
      try {
        tb = await tablebase(fens[i]);
      } catch (_) {
        tb = null;
      }
      onProgress?.call(
        ReviewProgress(ReviewStage.tablebase, k + 1, eligible.length),
      );
      if (tb == null) {
        tablebaseUnanswered++;
        continue;
      }
      final positionOutcome = _outcomeOf(tb.category);
      SyzygyMove? playedEntry;
      for (final m in tb.moves) {
        if (m.uci == appliedUci[i]) {
          playedEntry = m;
          break;
        }
      }
      final playedRaw =
          playedEntry == null ? null : _outcomeOf(playedEntry.category);
      if (positionOutcome == null || playedRaw == null) {
        tablebaseUnanswered++;
        continue;
      }
      final playedOutcome = _invert(playedRaw);
      final fallbackLoss = walkJudgement[i]?.lostChances ?? 0.0;
      tablebaseJudgement[i] = judgeByTablebase(
        position: positionOutcome,
        played: playedOutcome,
        lostChances: fallbackLoss,
      );
      byTablebase[i] = true;
      tablebaseKeepers[i] = [
        for (final m in tb.moves)
          if (_outcomeOf(m.category) != null &&
              _invert(_outcomeOf(m.category)!) == positionOutcome)
            m.uci,
      ];
    }

    // --- Candidates: the confirming look, then the deepening ---------------
    final finalJudgement = List<MoveJudgement?>.filled(n, null);
    final finalDepth = List<int?>.filled(n, null);
    final finalLine1 = List<AnalysisLine?>.filled(n, null);
    final finalLine2 = List<AnalysisLine?>.filled(n, null);
    final finalLine3 = List<AnalysisLine?>.filled(n, null);
    final finalNodes = List<int?>.filled(n, null);
    final finalDeepened = List<bool>.filled(n, false);
    final finalUnsettled = List<bool>.filled(n, false);

    final candidates = <_Candidate>[];
    for (var i = 0; i < n; i++) {
      if (byTablebase[i]) {
        finalJudgement[i] = tablebaseJudgement[i];
        finalDepth[i] = walkDepth[i];
        finalLine1[i] = walkAnswers[i]?.line1;
        finalNodes[i] = walkAnswers[i]?.line1.nodes;
        continue;
      }
      if (unjudgedWhy[i] != null) {
        finalLine1[i] = walkAnswers[i]?.line1;
        continue;
      }
      final judgement = walkJudgement[i]!;
      if (!isCandidate(judgement, bookGames: bookGames[i] ?? 0)) {
        finalJudgement[i] = judgement;
        finalDepth[i] = walkDepth[i];
        finalLine1[i] = walkAnswers[i]?.line1;
        finalNodes[i] = walkAnswers[i]?.line1.nodes;
        continue;
      }
      candidates.add(
        _Candidate(
          ply: i,
          fenBefore: fens[i],
          fenAfter: fens[i + 1],
          uci: appliedUci[i],
          whiteBefore: whiteToMove[i],
          whiteAfter: whiteToMove[i + 1],
          afterTerminal: terminals[i + 1],
          bookGames: bookGames[i],
          walkJudgement: judgement,
          walkDepth: walkDepth[i]!,
          walkLine1: walkAnswers[i]!.line1,
        ),
      );
    }

    // Every candidate is confirmed once, unconditionally, at the review's
    // own depth — before any deepening is considered.
    for (var k = 0; k < candidates.length; k++) {
      if (_cancelled) return null;
      final c = candidates[k];
      final look = await _lookAt(c, depth, timeout: kConfirmTimeout);
      onProgress?.call(
        ReviewProgress(ReviewStage.confirm, k + 1, candidates.length),
      );
      if (look.judgement == null) {
        // No usable answer at all beyond the walk: looking ends here, on the
        // walk's own judgement (already seeded onto the candidate).
        c.unsettled = true;
        continue;
      }
      c.currentJudgement = look.judgement!;
      c.currentDepth = look.depth!;
      c.currentLine1 = look.line1!;
      c.currentLine2 = look.line2;
      c.currentNodes = look.nodes;
      final isBookMove = (c.bookGames ?? 0) >= kTheoryGames;
      if (!isBookMove && judgementsAgree(c.walkJudgement, look.judgement!)) {
        c.settled = true;
      }
      // A book move is never settled before at least one deepening — it
      // stays in the pool below regardless of agreement.
    }

    // The deepening: the candidate closest to its own threshold first, and
    // never a new round with fewer than two searches left in the budget — a
    // round may cost up to two calls (the two-line search, and the played
    // move's own).
    var deepeningSearchesUsed = 0;
    while (deepeningBudget - deepeningSearchesUsed >= 2) {
      final active =
          candidates.where((c) => !c.settled && !c.unsettled).toList();
      if (active.isEmpty) break;
      active.sort((a, b) {
        final da = (a.currentJudgement.lostChances - a.threshold).abs();
        final db = (b.currentJudgement.lostChances - b.threshold).abs();
        final cmp = da.compareTo(db);
        return cmp != 0 ? cmp : a.ply.compareTo(b.ply);
      });
      final chosen = active.first;
      if (_cancelled) return null;
      chosen.levelsUsed++;
      final newDepth = depth + kDeepenStep * chosen.levelsUsed;
      final look = await _lookAt(chosen, newDepth, timeout: kDeepenTimeout);
      deepeningSearchesUsed += look.calls;
      onProgress?.call(
        ReviewProgress(
          ReviewStage.deepen,
          deepeningSearchesUsed,
          deepeningBudget,
        ),
      );
      if (look.judgement == null) {
        chosen.unsettled = true;
        continue;
      }
      final previous = chosen.currentJudgement;
      chosen.currentJudgement = look.judgement!;
      chosen.currentDepth = look.depth!;
      chosen.currentLine1 = look.line1!;
      chosen.currentLine2 = look.line2;
      chosen.currentNodes = look.nodes;
      chosen.everDeepened = true;
      // A look that came back deeper than this level actually asked for — a
      // stored answer overshooting the request — already stands past every
      // level the deepening would ever reach; nothing more to ask.
      final overshotTheSchedule =
          look.depth! >= depth + kDeepenStep * kDeepenLevels &&
              look.depth! > newDepth;
      if (judgementsAgree(previous, look.judgement!) || overshotTheSchedule) {
        chosen.settled = true;
      } else if (chosen.levelsUsed >= kDeepenLevels) {
        chosen.unsettled = true;
      }
    }
    // Anything the loop leaves neither settled nor explicitly unsettled ran
    // out of budget rather than levels — still unsettled, at its last look.
    for (final c in candidates) {
      if (!c.settled && !c.unsettled) c.unsettled = true;
    }

    for (final c in candidates) {
      finalJudgement[c.ply] = c.currentJudgement;
      finalDepth[c.ply] = c.currentDepth;
      finalLine1[c.ply] = c.currentLine1;
      finalLine2[c.ply] = c.currentLine2;
      finalNodes[c.ply] = c.currentNodes;
      finalDeepened[c.ply] = c.everDeepened;
      finalUnsettled[c.ply] = c.unsettled;
      AppLogger.log(
        '[GameReviewJudge] ply ${c.ply} settled at depth '
        '${c.currentDepth} (${c.currentNodes ?? '?'} nodes)',
      );
    }

    // --- The puzzle stage (docs/PLAN-ZAGONETKE-IZ-PARTIJE.md, 1.3) ----------
    // The walk stays at one line, so a move the player found in a live
    // position needs a search of its own, and a mate with a second mate
    // beside it needs a third line to measure B against. Both are searches
    // only a review that keeps puzzles pays for, only for the side chosen,
    // and only where they can end in a puzzle: never on a move already
    // unsettled or judged by the tablebase.
    if (puzzles != null) {
      final eligible = [
        for (var i = 0; i < n; i++)
          if (finalJudgement[i] != null &&
              !finalUnsettled[i] &&
              !byTablebase[i] &&
              switch (puzzles) {
                BlunderAlertSide.both => true,
                BlunderAlertSide.white => whiteToMove[i],
                BlunderAlertSide.black => !whiteToMove[i],
              })
            i,
      ];
      for (var k = 0; k < eligible.length; k++) {
        if (_cancelled) return null;
        final i = eligible[k];
        final judgement = finalJudgement[i]!;
        final whiteBefore = whiteToMove[i];
        if (judgement.isMistake) {
          final best = finalLine1[i];
          final second = finalLine2[i];
          if (best != null &&
              second != null &&
              _matesForMover(best, whiteBefore) &&
              _matesForMover(second, whiteBefore)) {
            final atDepth = finalDepth[i] ?? depth;
            final look = await _ask(
              fens[i],
              depth: atDepth,
              multiPv: 3,
              timeout: kConfirmTimeout,
            );
            if (look != null && look.line2 != null && look.line3 != null) {
              finalLine1[i] = look.line1;
              finalLine2[i] = look.line2;
              finalLine3[i] = look.line3;
            }
          }
        } else {
          final best = finalLine1[i];
          if (best != null &&
              walkBestUci[i] == appliedUci[i] &&
              (bookGames[i] ?? 0) < kTheoryGames &&
              bestValue[i] != null &&
              !isDecided(winningChances(bestValue[i]!)) &&
              !isTrivialFind(
                fens[i],
                appliedUci[i],
                previousUci: i > 0 ? appliedUci[i - 1] : null,
              )) {
            final look = await _ask(
              fens[i],
              depth: depth,
              multiPv: 2,
              timeout: kConfirmTimeout,
            );
            if (look != null && look.line2 != null) {
              finalLine1[i] = look.line1;
              finalLine2[i] = look.line2;
            }
          }
        }
        onProgress?.call(
          ReviewProgress(ReviewStage.answers, k + 1, eligible.length),
        );
      }
    }

    // --- Assembly ------------------------------------------------------------
    final moves = <ReviewedMove>[];
    for (var i = 0; i < n; i++) {
      final afterTerm = terminals[i + 1];
      final afterAns = walkAnswers[i + 1];
      final replyLine = afterTerm == null ? afterAns?.line1 : null;

      moves.add(
        ReviewedMove(
          ply: i,
          san: sans[i],
          uci: appliedUci[i],
          fenBefore: fens[i],
          fenAfter: fens[i + 1],
          whiteMoved: whiteToMove[i],
          judgement: finalJudgement[i],
          unjudgedWhy: byTablebase[i] ? null : unjudgedWhy[i],
          unsettled: finalUnsettled[i],
          depth: finalDepth[i],
          nodes: finalNodes[i],
          bestLine: finalLine1[i],
          replyLine: replyLine,
          secondLine: finalLine2[i],
          thirdLine: finalLine3[i],
          bookGames: bookGames[i],
          byTablebase: byTablebase[i],
          deepened: finalDeepened[i],
          walkBestUci: walkBestUci[i],
          tablebaseKeepers: tablebaseKeepers[i],
        ),
      );
    }

    return GameReviewResult(
      moves: moves,
      reviewDepth: depth,
      bookUnavailable: bookUnavailable,
      tablebaseUnanswered: tablebaseUnanswered,
      deepeningSearches: deepeningSearchesUsed,
    );
  }

  /// The walk's answer for [fen]: [depth], or once more at
  /// `depth - kRetryShallower` when the first search has nothing usable. Null
  /// when neither does.
  Future<_Usable?> _searchWithRetry(
    String fen, {
    required int depth,
    required int multiPv,
    required Duration timeout,
  }) async {
    final usable = await _ask(
      fen,
      depth: depth,
      multiPv: multiPv,
      timeout: timeout,
    );
    if (usable != null) return usable;
    final shallower = math.max(1, depth - kRetryShallower);
    if (shallower == depth) return null;
    return _ask(fen, depth: shallower, multiPv: multiPv, timeout: timeout);
  }

  /// Asks the engine once and normalizes the answer: sorted by `multipv`, cut
  /// to [multiPv] lines, usable only when [searchProblem] passes line 1. An
  /// analyzer that throws answers nothing, same as one that came back short.
  Future<_Usable?> _ask(
    String fen, {
    required int depth,
    required int multiPv,
    List<String>? searchMoves,
    required Duration timeout,
  }) async {
    List<AnalysisLine> lines;
    try {
      lines = await analyzer(
        fen,
        depth: depth,
        multiPV: multiPv,
        searchMoves: searchMoves,
        timeout: timeout,
      );
    } catch (_) {
      return null;
    }
    final sorted = [...lines]..sort((a, b) => a.multipv.compareTo(b.multipv));
    final kept = sorted.where((l) => l.multipv <= multiPv).toList();
    AnalysisLine? line1;
    for (final l in kept) {
      if (l.multipv == 1) {
        line1 = l;
        break;
      }
    }
    if (line1 == null) return null;
    if (searchProblem(fen, [line1], depth: depth, multiPv: 1) != null) {
      return null;
    }
    AnalysisLine? line2;
    for (final l in kept) {
      if (l.multipv == 2) {
        line2 = l;
        break;
      }
    }
    AnalysisLine? line3;
    for (final l in kept) {
      if (l.multipv == 3) {
        line3 = l;
        break;
      }
    }
    return _Usable(line1, line2, line3);
  }

  /// A confirming or deepening look at [atDepth] for candidate [c]: two
  /// lines, and the played move alone (`searchmoves`) unless it heads one of
  /// them — falling back to the position after, turned round, when the
  /// engine ignores `searchmoves` and answers a different move.
  Future<_LookOutcome> _lookAt(
    _Candidate c,
    int atDepth, {
    required Duration timeout,
  }) async {
    var calls = 0;
    final confirm = await _ask(
      c.fenBefore,
      depth: atDepth,
      multiPv: 2,
      timeout: timeout,
    );
    calls++;
    if (confirm == null) return _LookOutcome(calls: calls);

    final bestValue = EngineValue.fromEvaluation(
      confirm.line1.evaluation,
      whiteToMove: c.whiteBefore,
    );
    final EngineValue playedValue;
    AnalysisLine? extraLine;
    if (c.afterTerminal != null) {
      playedValue = c.afterTerminal == _Terminal.mate
          ? const EngineValue.mate(1)
          : const EngineValue.cp(0);
    } else if (confirm.line1.bestMoveLan == c.uci) {
      playedValue = bestValue;
    } else if (confirm.line2 != null && confirm.line2!.bestMoveLan == c.uci) {
      playedValue = EngineValue.fromEvaluation(
        confirm.line2!.evaluation,
        whiteToMove: c.whiteBefore,
      );
    } else {
      final alone = await _ask(
        c.fenBefore,
        depth: atDepth,
        multiPv: 1,
        searchMoves: [c.uci],
        timeout: timeout,
      );
      calls++;
      if (alone != null && alone.line1.bestMoveLan == c.uci) {
        playedValue = EngineValue.fromEvaluation(
          alone.line1.evaluation,
          whiteToMove: c.whiteBefore,
        );
        extraLine = alone.line1;
      } else {
        final after = await _ask(
          c.fenAfter,
          depth: atDepth,
          multiPv: 1,
          timeout: timeout,
        );
        calls++;
        if (after == null) return _LookOutcome(calls: calls);
        playedValue = _negate(
          EngineValue.fromEvaluation(
            after.line1.evaluation,
            whiteToMove: c.whiteAfter,
          ),
        );
        extraLine = after.line1;
      }
    }
    final judgement = judgeMove(
      best: bestValue,
      played: playedValue,
      bookGames: c.bookGames ?? 0,
    );
    var lookDepth = confirm.line1.depth;
    if (extraLine != null && extraLine.depth < lookDepth) {
      lookDepth = extraLine.depth;
    }
    return _LookOutcome(
      judgement: judgement,
      depth: lookDepth,
      line1: confirm.line1,
      line2: confirm.line2,
      nodes: confirm.line1.nodes,
      calls: calls,
    );
  }
}

/// Checkmate, stalemate or the chess package's own draw (insufficient
/// material) — never searched; a mate is the mover's win, a draw is level.
enum _Terminal { mate, draw }

/// The position-after's value, from the mover's side, given the value from
/// the side to move there.
EngineValue _negate(EngineValue v) {
  final mate = v.mate;
  if (mate != null) return EngineValue.mate(-mate);
  return EngineValue.cp(-(v.cp!));
}

/// How many men are on [fen]'s board — the tablebase's own boundary.
int _menCount(String fen) =>
    RegExp(r'[a-zA-Z]').allMatches(fen.split(' ').first).length;

/// [category] for the side to move, mapped onto [TablebaseOutcome]: a cursed
/// win or a blessed loss count as a draw (§3, "With seven men or fewer");
/// null for anything not settled.
TablebaseOutcome? _outcomeOf(SyzygyCategory category) {
  switch (category) {
    case SyzygyCategory.win:
      return TablebaseOutcome.win;
    case SyzygyCategory.cursedWin:
    case SyzygyCategory.draw:
    case SyzygyCategory.blessedLoss:
      return TablebaseOutcome.draw;
    case SyzygyCategory.loss:
      return TablebaseOutcome.loss;
    case SyzygyCategory.maybeWin:
    case SyzygyCategory.maybeLoss:
    case SyzygyCategory.unknown:
      return null;
  }
}

/// A move's own [SyzygyMove.category] is for the opponent (the side to move
/// after it); this is that same result read for the mover instead.
TablebaseOutcome _invert(TablebaseOutcome o) {
  switch (o) {
    case TablebaseOutcome.win:
      return TablebaseOutcome.loss;
    case TablebaseOutcome.loss:
      return TablebaseOutcome.win;
    case TablebaseOutcome.draw:
      return TablebaseOutcome.draw;
  }
}

/// A usable answer: [line1] passed [searchProblem]; [line2] and [line3] are
/// kept when the search asked for, and got, a second or third line.
class _Usable {
  const _Usable(this.line1, this.line2, [this.line3]);
  final AnalysisLine line1;
  final AnalysisLine? line2;
  final AnalysisLine? line3;
}

/// Whether [line] is a mate for the mover — the side to move in the position
/// [line] starts from, [whiteBefore] whether that side is White.
bool _matesForMover(AnalysisLine line, bool whiteBefore) {
  final mate = EngineValue.fromEvaluation(
    line.evaluation,
    whiteToMove: whiteBefore,
  ).mate;
  return mate != null && mate > 0;
}

/// One confirming or deepening look's outcome. [judgement] is null when the
/// look found no usable answer at all — the candidate's looking ends there,
/// on whatever it already stood on. [calls] is how many analyzer calls this
/// look made, whether or not it ended up usable.
class _LookOutcome {
  const _LookOutcome({
    this.judgement,
    this.depth,
    this.line1,
    this.line2,
    this.nodes,
    required this.calls,
  });
  final MoveJudgement? judgement;
  final int? depth;
  final AnalysisLine? line1;
  final AnalysisLine? line2;
  final int? nodes;
  final int calls;
}

/// A candidate move's state through the confirming and, maybe, the
/// deepening looks — seeded on the walk's own judgement, so a look that
/// never succeeds simply leaves it there.
class _Candidate {
  _Candidate({
    required this.ply,
    required this.fenBefore,
    required this.fenAfter,
    required this.uci,
    required this.whiteBefore,
    required this.whiteAfter,
    required this.afterTerminal,
    required this.bookGames,
    required this.walkJudgement,
    required this.walkDepth,
    required this.walkLine1,
  })  : currentJudgement = walkJudgement,
        currentDepth = walkDepth,
        currentLine1 = walkLine1,
        currentNodes = walkLine1.nodes;

  final int ply;
  final String fenBefore;
  final String fenAfter;
  final String uci;
  final bool whiteBefore;
  final bool whiteAfter;
  final _Terminal? afterTerminal;
  final int? bookGames;
  final MoveJudgement walkJudgement;
  final int walkDepth;
  final AnalysisLine walkLine1;

  MoveJudgement currentJudgement;
  int currentDepth;
  AnalysisLine currentLine1;
  AnalysisLine? currentLine2;
  int? currentNodes;

  /// Deepening levels used so far (0 right after the confirming look).
  int levelsUsed = 0;
  bool settled = false;
  bool unsettled = false;
  bool everDeepened = false;

  /// The threshold this move is judged against — what "closest to its
  /// threshold" in the deepening's scheduling means.
  double get threshold =>
      (bookGames ?? 0) >= kTheoryGames ? kGrossLossInBook : kMistakeLoss;
}
