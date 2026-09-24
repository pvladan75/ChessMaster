/// Judging a player's opening habits on the desktop —
/// `docs/PLAN-MOJE-PARTIJE.md` §9.3.
///
/// The server (§9.2) has already said which moves are habits and what the
/// device already judged them at. This file does the rest: for every habit
/// move not yet judged at [depth] or deeper, it asks the tutorial's own
/// engine pool for two lines at the node and, when a habit move heads neither
/// of them, one more line with `searchmoves` for that move alone
/// (`UciEngine.analyze`, phase 9.3's own addition). Every verdict comes from
/// the one mistake rule (`lib/core/services/mistake_rule.dart`, rule 12) —
/// nothing here decides what a mistake is.
///
/// **No UI, no HTTP.** [analyzers] is [HabitAnalyzer] — `UciEngine.analyze`'s
/// own shape, `searchmoves` included, which `PositionAnalyzer` (the tutorial
/// builder's shared typedef, used by callers that never ask for
/// `searchmoves`) does not carry — and [send] is however the caller wants a
/// batch delivered: a fake in a test, `ArchiveApiService.sendJudgements` on
/// the device. That is what lets this be tested without an engine and
/// without a server.
library;

import 'dart:async';

import 'package:chess_app/core/services/mistake_rule.dart';
import 'package:chess_app/features/archive/models/leak_report.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/game_facts.dart'
    show searchProblem;
import 'package:chess_app/models/analysis_models.dart';

/// The depth §9.3 asks for. A move already judged at this depth or deeper is
/// not searched again.
const int kOpeningJudgeDepth = 20;

/// How many judgements to send in one call, matching the server's own pace
/// (`services/openingJudgements.js`, `MAX_ITEMS_PER_CALL`).
const int kOpeningJudgeBatchSize = 25;

/// `UciEngine.analyze`'s own signature — the `PositionAnalyzer` shape plus
/// `searchMoves`, which this judge needs and that shared typedef does not
/// carry (other callers never ask for it). A `UciEngine.analyze` tear-off
/// satisfies this directly.
typedef HabitAnalyzer = Future<List<AnalysisLine>> Function(
  String fen, {
  required int depth,
  required int multiPV,
  List<String>? searchMoves,
  Duration timeout,
});

/// Positions judged so far ([done]) of the total that had anything left to
/// judge ([total]) — never the whole node count, since a node with every habit
/// move already judged is never searched again.
class OpeningTreeJudgeProgress {
  const OpeningTreeJudgeProgress(this.done, this.total);

  final int done;
  final int total;
}

/// Delivers one batch of judgement items (the wire shape of
/// `POST /games/openings/judgements`'s `judgements` list). When it answers the
/// server's [JudgementTally], the counts are added up and said at the end — a
/// rejection is not a reason to re-judge, but it is not a silence either. A
/// sender that throws stops the run; the caller says so.
typedef JudgementSender = Future<Object?> Function(
    List<Map<String, dynamic>> batch);

/// A habit move that could not be judged, and why. Never sent: a judgement
/// the engine did not give at the depth claimed is not one.
class UnjudgedMove {
  const UnjudgedMove(this.fenKey, this.moveUci, this.why);

  final String fenKey;
  final String moveUci;
  final String why;
}

/// What a run did, to be said when it ends.
class OpeningTreeJudgeResult {
  OpeningTreeJudgeResult();

  /// Judgements made and handed to the sender.
  int judged = 0;
  final List<UnjudgedMove> unjudged = [];
  int stored = 0;
  int replaced = 0;
  int keptDeeper = 0;
  int rejected = 0;
  bool cancelled = false;

  void _add(Object? answer) {
    if (answer is! JudgementTally) return;
    stored += answer.stored;
    replaced += answer.replaced;
    keptDeeper += answer.keptDeeper;
    rejected += answer.rejected;
  }

  /// One sentence for the screen: what was judged, and every part that was
  /// not — never a success that hides a miss.
  String get summary {
    final parts = <String>[
      judged == 1 ? 'Judged 1 move.' : 'Judged $judged moves.',
      if (unjudged.isNotEmpty)
        unjudged.length == 1
            ? '1 move could not be judged.'
            : '${unjudged.length} moves could not be judged.',
      if (rejected > 0)
        rejected == 1
            ? 'The server refused 1.'
            : 'The server refused $rejected.',
      if (cancelled) 'Stopped before the end.',
    ];
    return parts.join(' ');
  }
}

class OpeningTreeJudge {
  OpeningTreeJudge({
    required List<HabitAnalyzer> analyzers,
    required String engine,
    required JudgementSender send,
    this.depth = kOpeningJudgeDepth,
    this.batchSize = kOpeningJudgeBatchSize,
  })  : assert(analyzers.isNotEmpty),
        _analyzers = analyzers,
        _engine = engine,
        _send = send;

  final List<HabitAnalyzer> _analyzers;
  final String _engine;
  final JudgementSender _send;
  final int depth;
  final int batchSize;

  bool _cancelled = false;

  /// Stops the run before its next search or send. A batch already sent
  /// stays sent — this only keeps more from going out.
  void cancel() => _cancelled = true;

  /// A move worth asking the engine about: a habit not already judged at
  /// [depth] or deeper.
  bool _pending(LeakReportMove move) {
    if (!move.habit || move.uci == null) return false;
    final judged = move.judgement;
    return judged == null || judged.depth < depth;
  }

  List<LeakReportMove> _pendingOf(LeakReportNode node) => [
        for (final m in node.moves)
          if (_pending(m)) m
      ];

  /// Judges every habit move of [nodes] not already judged deep enough,
  /// sending items in batches of [batchSize] as they are made. Never searches
  /// a node whose habit moves are all already judged.
  Future<OpeningTreeJudgeResult> run(
    List<LeakReportNode> nodes, {
    void Function(OpeningTreeJudgeProgress progress)? onProgress,
  }) async {
    final result = OpeningTreeJudgeResult();
    final toDo = [
      for (final node in nodes)
        if (_pendingOf(node).isNotEmpty) node
    ];
    final total = toDo.length;
    var done = 0;
    onProgress?.call(OpeningTreeJudgeProgress(done, total));
    if (toDo.isEmpty) return result;

    var next = 0;
    var pending = <Map<String, dynamic>>[];

    Future<void> flush({required bool all}) async {
      while (pending.length >= batchSize || (all && pending.isNotEmpty)) {
        if (_cancelled) return;
        final take = all ? pending.length : batchSize;
        final batch = pending.sublist(0, take);
        pending = pending.sublist(take);
        result._add(await _send(batch));
      }
    }

    Future<void> drain(HabitAnalyzer analyzer) async {
      while (true) {
        if (_cancelled) return;
        if (next >= toDo.length) return;
        final node = toDo[next++];
        final items = await _judgeNode(analyzer, node, result.unjudged);
        if (_cancelled) return;
        result.judged += items.length;
        pending.addAll(items);
        done += 1;
        onProgress?.call(OpeningTreeJudgeProgress(done, total));
        await flush(all: false);
      }
    }

    await Future.wait([for (final a in _analyzers) drain(a)]);
    if (!_cancelled) await flush(all: true);
    result.cancelled = _cancelled;
    return result;
  }

  /// The line among [lines] that starts with [uci], or null when neither of
  /// the two does — the move needs its own search then.
  AnalysisLine? _headedBy(List<AnalysisLine> lines, String uci) {
    for (final line in lines) {
      if (line.bestMoveLan == uci) return line;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _judgeNode(HabitAnalyzer analyzer,
      LeakReportNode node, List<UnjudgedMove> unjudged) async {
    final pending = _pendingOf(node);
    if (pending.isEmpty) return const [];
    void miss(Iterable<LeakReportMove> moves, String why) {
      for (final m in moves) {
        unjudged.add(UnjudgedMove(node.fenKey, m.uci!, why));
      }
    }

    final whiteToMove = node.fen.split(' ')[1] == 'w';
    final List<AnalysisLine> twoLines;
    try {
      twoLines =
          await analyzer(node.fen, depth: depth, multiPV: 2, timeout: _timeout);
    } catch (e) {
      miss(pending, 'the engine failed: $e');
      return const [];
    }
    // A search stopped by its timeout answers what it had — a shallower
    // depth, or fewer lines — and that is not a judgement at [depth]. The
    // tutorial's own check decides it (rule 12).
    final twoProblem =
        searchProblem(node.fen, twoLines, depth: depth, multiPv: 2);
    if (twoProblem != null) {
      miss(pending, twoProblem);
      return const [];
    }
    final bestLine = twoLines.firstWhere((l) => l.multipv == 1,
        orElse: () => twoLines.first);
    final best = EngineValue.fromEvaluation(bestLine.evaluation,
        whiteToMove: whiteToMove);

    final items = <Map<String, dynamic>>[];
    for (final move in pending) {
      final uci = move.uci!;
      if (_cancelled) break;
      final headed = _headedBy(twoLines, uci);
      final AnalysisLine playedLine;
      if (headed != null) {
        playedLine = headed;
      } else {
        final List<AnalysisLine> searched;
        try {
          searched = await analyzer(node.fen,
              depth: depth, multiPV: 1, searchMoves: [uci], timeout: _timeout);
        } catch (e) {
          miss([move], 'the engine failed: $e');
          continue;
        }
        final problem =
            searchProblem(node.fen, searched, depth: depth, multiPv: 1);
        if (problem != null) {
          miss([move], problem);
          continue;
        }
        // An engine that ignored `searchmoves` answers its own best move, and
        // read as this one it would make any habit hold.
        if (searched.first.bestMoveLan != uci) {
          miss([move],
              'the engine searched ${searched.first.bestMoveLan}, not $uci');
          continue;
        }
        playedLine = searched.first;
      }
      if (bestLine.sanMoveList.isEmpty || playedLine.sanMoveList.isEmpty) {
        miss([move], 'a line with no moves');
        continue;
      }
      final played = EngineValue.fromEvaluation(playedLine.evaluation,
          whiteToMove: whiteToMove);
      final judgement =
          judgeMove(best: best, played: played, bookGames: move.bookGames ?? 0);
      items.add({
        'fenKey': node.fenKey,
        'moveUci': uci,
        'wBest': winningChances(best),
        'wMove': winningChances(played),
        // The drill's own measure (§9.4): kept now, while the engine's values
        // are here, because a judgement read back later has only chances.
        'lossCp': lossInCentipawns(best: best, played: played),
        'bestUci': bestLine.bestMoveLan,
        'bestLine': bestLine.sanMoveList,
        'moveLine': playedLine.sanMoveList,
        'verdict': judgement.isMistake ? 'mistake' : 'holds',
        'reason': judgement.reason?.name,
        'bookGames': move.bookGames,
        'engine': _engine,
        'depth': depth,
      });
    }
    return items;
  }

  static const _timeout = Duration(minutes: 2);
}
