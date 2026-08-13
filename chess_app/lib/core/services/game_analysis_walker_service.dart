import 'dart:async';
import 'package:chess/chess.dart' as chess;
import 'package:chess_app/core/models/game_moment.dart';
import 'package:chess_app/core/services/tactical_motif_detector.dart';
import 'package:chess_app/core/services/positional_evaluator_service.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/auto_tree_generator_service.dart' show PositionAnalyzer;

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
      for (final m in game.moves({'verbose': true})) {
        if (m['from'] == from && m['to'] == to && (promo == null || m['promotion'] == promo)) {
          san = m['san'] as String?;
          break;
        }
      }
      if (san == null) break;

      final applied = game.move({'from': from, 'to': to, if (promo != null) 'promotion': promo});
      if (!applied) break;

      sans.add(san);
      appliedUci.add(uci);
      fens.add(game.fen);
    }

    if (appliedUci.isEmpty) return const [];

    final total = fens.length;
    final evalsRaw = <String?>[];
    for (var i = 0; i < fens.length; i++) {
      if (_cancelled) return const [];
      String? eval;
      try {
        final lines = await analyzer(fens[i], depth: depth, multiPV: 1, timeout: const Duration(seconds: 12));
        eval = lines.isNotEmpty ? lines.first.evaluation : null;
      } catch (_) {
        eval = null;
      }
      evalsRaw.add(eval);
      onProgress?.call(i + 1, total);
    }

    final moments = <GameMoment>[];
    for (var i = 0; i < appliedUci.length; i++) {
      final fenBefore = fens[i];
      final fenAfter = fens[i + 1];
      final moverColor = chess.Chess.fromFEN(fenBefore).turn;

      final beforeForMover = _evalForMover(evalsRaw[i], moverColor);
      final afterForMover = _evalForMover(evalsRaw[i + 1], moverColor);
      final swing = (beforeForMover != null && afterForMover != null) ? afterForMover - beforeForMover : null;

      final tacticalDiff = tacticalDetector.explainMove(
        beforeFen: fenBefore,
        afterFen: fenAfter,
        lastMoveUci: appliedUci[i],
      );
      final positionalDiff = positionalEvaluator.explainMove(beforeFen: fenBefore, afterFen: fenAfter);

      moments.add(GameMoment(
        plyIndex: i,
        moveSan: sans[i],
        moveUci: appliedUci[i],
        fenBefore: fenBefore,
        fenAfter: fenAfter,
        moverColor: moverColor,
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

  /// Walks [rootNode]'s main line (first child at every step) and writes
  /// each move's combined tactical+positional comment and White-relative
  /// eval into the corresponding node. Existing non-empty comments are left
  /// alone unless [overwriteExisting] is true.
  Future<void> annotateNodeChain({
    required AnalysisNode rootNode,
    required PositionAnalyzer analyzer,
    int depth = _defaultDepth,
    bool overwriteExisting = false,
    void Function(int processed, int total)? onProgress,
  }) async {
    final chain = <AnalysisNode>[];
    var cur = rootNode;
    while (cur.children.isNotEmpty) {
      cur = cur.children.first;
      chain.add(cur);
    }
    if (chain.isEmpty) return;

    final uciMoves = chain.map((n) => n.moveUci ?? '').toList();
    final moments = await analyzeGame(
      startingFen: rootNode.fen,
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

      final afterEval = _parseWhiteRelativeEval(moment.evalAfterRaw);
      if (afterEval != null) {
        node.eval = afterEval;
      }
    }
  }

  double? _evalForMover(String? whiteRelativeRaw, chess.Color moverColor) {
    final whiteRelative = _parseWhiteRelativeEval(whiteRelativeRaw);
    if (whiteRelative == null) return null;
    return moverColor == chess.Color.WHITE ? whiteRelative : -whiteRelative;
  }

  /// Parses an engine eval string ("1.23", "-0.50", "M4", "-M4") into a
  /// White-relative pawn-unit value. Mate scores collapse to a large but
  /// finite magnitude (100 minus the mate distance) so they still compare
  /// sensibly against ordinary evals without needing special-casing at every
  /// call site.
  double? _parseWhiteRelativeEval(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    final numeric = double.tryParse(raw);
    if (numeric != null) return numeric;

    final mateMatch = RegExp(r'(-)?M(\d+)').firstMatch(raw);
    if (mateMatch == null) return null;
    final distance = int.tryParse(mateMatch.group(2)!) ?? 1;
    final magnitude = 100.0 - distance;
    return mateMatch.group(1) != null ? -magnitude : magnitude;
  }
}
