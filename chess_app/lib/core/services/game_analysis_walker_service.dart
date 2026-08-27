import 'dart:async';
import 'dart:math' as math;

import 'package:chess/chess.dart' as chess;
import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess_app/core/models/game_moment.dart';
import 'package:chess_app/core/services/tactical_motif_detector.dart';
import 'package:chess_app/core/services/positional_evaluator_service.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/auto_tree_generator_service.dart'
    show PositionAnalyzer;
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/core/services/eval_parsing.dart';

/// Which side's mistakes a blunder alert should flag — see
/// [GameAnalysisWalkerService.tagBlunders].
enum BlunderAlertSide { white, black, both }

/// Walks an already-known sequence of moves (a real game, not engine-searched
/// branches) one ply at a time: gets the engine eval at every position,
/// derives each move's swing from the mover's own perspective, and runs both
/// [TacticalMotifDetector] and [PositionalEvaluatorService] on the
/// before/after pair. This is the shared foundation for whole-game
/// annotation (`annotateNodeChain`) and blunder/puzzle extraction
/// (`LocalPuzzleExtractorService`), which both just need "what happened on
/// every move" and differ only in what they do with it.
class GameAnalysisWalkerService {
  bool _cancelled = false;

  void cancel() => _cancelled = true;

  static const int _defaultDepth = 14;

  /// Analyzes every move in [uciMoves] starting from [startingFen]. Returns
  /// one [GameMoment] per move (empty if [uciMoves] is empty or a move fails
  /// to apply). [onProgress] reports positions evaluated so far out of the
  /// total (moves.length + 1, since the starting position is evaluated too).
  Future<List<GameMoment>> analyzeGame({
    required String startingFen,
    required List<String> uciMoves,
    required PositionAnalyzer analyzer,
    int depth = _defaultDepth,
    void Function(int processed, int total)? onProgress,
  }) async {
    _cancelled = false;
    const tacticalDetector = TacticalMotifDetector();
    const positionalEvaluator = PositionalEvaluatorService();

    final fens = <String>[startingFen];
    final sans = <String>[];
    final appliedUci = <String>[];

    var game = chess.Chess.fromFEN(startingFen);
    for (final uci in uciMoves) {
      if (uci.length < 4) break;
      final from = uci.substring(0, 2);
      final to = uci.substring(2, 4);
      final promo = uci.length > 4 ? uci.substring(4, 5) : null;

      String? san;
      // `legalMoves` rather than the package's own list: its verbose maps have
      // no promotion in them, so a UCI carrying one (`d7d8q`) matched nothing,
      // `san` stayed null, and the walk **stopped at the first promotion of the
      // game** — silently, halfway through somebody's analysis.
      for (final m in legalMoves(game)) {
        if (m['from'] == from &&
            m['to'] == to &&
            (promo == null || m['promotion'] == promo)) {
          san = m['san'] as String?;
          break;
        }
      }
      if (san == null) break;

      final applied = game.move(
          {'from': from, 'to': to, if (promo != null) 'promotion': promo});
      if (!applied) break;

      sans.add(san);
      appliedUci.add(uci);
      fens.add(game.fen);
    }

    if (appliedUci.isEmpty) return const [];

    final total = fens.length;
    final evalsRaw = <String?>[];
    final linesRaw = <AnalysisLine?>[];
    for (var i = 0; i < fens.length; i++) {
      if (_cancelled) return const [];
      String? eval;
      AnalysisLine? line;
      try {
        final lines = await analyzer(fens[i],
            depth: depth, multiPV: 1, timeout: const Duration(seconds: 12));
        line = lines.isNotEmpty ? lines.first : null;
        eval = line?.evaluation;
      } catch (_) {
        eval = null;
        line = null;
      }
      evalsRaw.add(eval);
      linesRaw.add(line);
      onProgress?.call(i + 1, total);
    }

    final moments = <GameMoment>[];
    for (var i = 0; i < appliedUci.length; i++) {
      final fenBefore = fens[i];
      final fenAfter = fens[i + 1];
      final moverColor = chess.Chess.fromFEN(fenBefore).turn;

      final beforeForMover = _evalForMover(evalsRaw[i], moverColor);
      final afterForMover = _evalForMover(evalsRaw[i + 1], moverColor);
      final swing = (beforeForMover != null && afterForMover != null)
          ? afterForMover - beforeForMover
          : null;

      final tacticalDiff = tacticalDetector.explainMove(
        beforeFen: fenBefore,
        afterFen: fenAfter,
        lastMoveUci: appliedUci[i],
      );
      final positionalDiff = positionalEvaluator.explainMove(
          beforeFen: fenBefore, afterFen: fenAfter);

      moments.add(GameMoment(
        plyIndex: i,
        moveSan: sans[i],
        moveUci: appliedUci[i],
        fenBefore: fenBefore,
        fenAfter: fenAfter,
        moverColor: moverColor,
        engineLineBefore: linesRaw[i],
        evalBeforeRaw: evalsRaw[i],
        evalAfterRaw: evalsRaw[i + 1],
        evalBeforeForMover: beforeForMover,
        evalAfterForMover: afterForMover,
        swingForMover: swing,
        tacticalComment: tacticalDetector.describeMoveDiff(tacticalDiff),
        positionalComment: positionalEvaluator.describeMoveDiff(positionalDiff),
      ));
    }

    return moments;
  }

  /// Walks [startNode]'s main line (first child at every step — [startNode]
  /// need not be the tree's true root, so this also covers "analyze just
  /// from here onward" over a sub-sequence of the game) and writes each
  /// move's combined tactical+positional comment and White-relative eval
  /// into the corresponding node. Existing non-empty comments are left alone
  /// unless [overwriteExisting] is true.
  ///
  /// Returns the walked node chain alongside the raw [GameMoment]s so a
  /// caller can run further passes (e.g. [tagBlunders], puzzle extraction)
  /// over the same engine walk instead of re-analyzing the game.
  Future<({List<AnalysisNode> chain, List<GameMoment> moments})>
      annotateNodeChain({
    required AnalysisNode startNode,
    required PositionAnalyzer analyzer,
    int depth = _defaultDepth,
    bool overwriteExisting = false,
    void Function(int processed, int total)? onProgress,
  }) async {
    final chain = <AnalysisNode>[];
    var cur = startNode;
    while (cur.children.isNotEmpty) {
      cur = cur.children.first;
      chain.add(cur);
    }
    if (chain.isEmpty) return (chain: chain, moments: const <GameMoment>[]);

    final uciMoves = chain.map((n) => n.moveUci ?? '').toList();
    final moments = await analyzeGame(
      startingFen: startNode.fen,
      uciMoves: uciMoves,
      analyzer: analyzer,
      depth: depth,
      onProgress: onProgress,
    );

    for (var i = 0; i < moments.length && i < chain.length; i++) {
      final node = chain[i];
      final moment = moments[i];

      if (overwriteExisting || node.comment.isEmpty) {
        if (moment.combinedComment.isNotEmpty) {
          node.comment = moment.combinedComment;
        }
      }

      final afterEval = parseWhiteRelativeEval(moment.evalAfterRaw);
      if (afterEval != null) {
        node.eval = afterEval;
        node.evalDepth = depth;
      }
    }

    return (chain: chain, moments: moments);
  }

  /// Marks every move in [chain] that lost at least [threshold] pawns for
  /// the side in [side] with a '??' NAG, and — when [insertAlternativeLine]
  /// is true — inserts the engine's own suggestion from that point as a
  /// short sibling variation (capped at [alternativeLinePlies] plies) so the
  /// better continuation is visible right next to the mistake.
  ///
  /// Once a position is already decided (the mover's own eval before the
  /// move was at least [decidedEvalCutoff] pawns either way), an ordinary
  /// [threshold]-sized swing is normal noise between winning-technique lines
  /// rather than a real mistake — simplifying into a won endgame routinely
  /// costs a few pawns of raw eval without changing the outcome. In that
  /// case the swing has to clear the larger [decidedSwingThreshold] instead,
  /// so only a swing that actually changes the position's character (e.g.
  /// +15 collapsing to +6) still gets flagged.
  ///
  /// Returns how many moves were tagged as blunders.
  int tagBlunders({
    required List<AnalysisNode> chain,
    required List<GameMoment> moments,
    required double threshold,
    BlunderAlertSide side = BlunderAlertSide.both,
    bool insertAlternativeLine = true,
    int alternativeLinePlies = 4,
    double decidedEvalCutoff = 8.0,
    double decidedSwingThreshold = 6.0,
  }) {
    var tagged = 0;
    for (var i = 0; i < moments.length && i < chain.length; i++) {
      final moment = moments[i];

      final alreadyDecided = moment.evalBeforeForMover != null &&
          moment.evalBeforeForMover!.abs() >= decidedEvalCutoff;
      final effectiveThreshold = alreadyDecided
          ? math.max(threshold, decidedSwingThreshold)
          : threshold;
      if (!moment.isBlunderBeyond(effectiveThreshold)) continue;
      if (side == BlunderAlertSide.white &&
          moment.moverColor != chess.Color.WHITE) continue;
      if (side == BlunderAlertSide.black &&
          moment.moverColor != chess.Color.BLACK) continue;

      final node = chain[i];
      node.nag = '??';
      tagged++;

      if (!insertAlternativeLine) continue;
      final betterLine = moment.engineLineBefore;
      final parent = node.parent;
      if (betterLine == null ||
          parent == null ||
          betterLine.sanMoveList.isEmpty) continue;
      if (betterLine.bestMoveLan == moment.moveUci) continue;

      _insertAlternativeLine(parent, betterLine, alternativeLinePlies);
    }
    return tagged;
  }

  /// Replays up to [maxPlies] moves of [line]'s principal variation onto
  /// [parent] as a new branch (or reuses an existing one with the same first
  /// move), tagging the first move '!' with a "Bolji potez" comment.
  void _insertAlternativeLine(
      AnalysisNode parent, AnalysisLine line, int maxPlies) {
    final plies = line.sanMoveList.take(maxPlies).toList();
    if (plies.isEmpty) return;

    final game = chess.Chess.fromFEN(parent.fen);
    var cur = parent;
    for (var i = 0; i < plies.length; i++) {
      final san = plies[i];
      if (!game.move(san)) break;
      final moveObj = game.history.last.move;
      final uci = moveObj.fromAlgebraic +
          moveObj.toAlgebraic +
          (moveObj.promotion?.name ?? '');
      final child = cur.addChild(childFen: game.fen, san: san, uci: uci);
      if (i == 0) {
        child.nag = '!';
        if (child.comment.isEmpty) child.comment = 'Bolji potez';
      }
      cur = child;
    }
  }

  double? _evalForMover(String? whiteRelativeRaw, chess.Color moverColor) {
    final whiteRelative = parseWhiteRelativeEval(whiteRelativeRaw);
    if (whiteRelative == null) return null;
    return moverColor == chess.Color.WHITE ? whiteRelative : -whiteRelative;
  }
}
