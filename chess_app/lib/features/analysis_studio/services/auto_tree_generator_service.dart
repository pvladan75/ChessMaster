import 'dart:async';
import 'package:chess/chess.dart' as chess;
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/models/analysis_models.dart';

class AutoAnalysisParams {
  final int pliesDepth; // N: 2 to 6 plies
  final int candidateCount; // n: 1 to 3 candidate moves
  final int engineDepth; // d: 10 to 20
  final double deltaCutoff; // delta: e.g. 1.5 pawns (150 cp)

  AutoAnalysisParams({
    this.pliesDepth = 4,
    this.candidateCount = 2,
    this.engineDepth = 12,
    this.deltaCutoff = 1.5,
  });
}

/// How the generator asks for an evaluated position.
///
/// [StockfishService.analyzePositionSync] satisfies this directly; tests supply a
/// deterministic stand-in so the tree logic can be exercised without a real engine
/// or a network round-trip.
typedef PositionAnalyzer = Future<List<AnalysisLine>> Function(
  String fen, {
  required int depth,
  required int multiPV,
  Duration timeout,
});

class AutoTreeGeneratorService {
  bool _isCancelled = false;

  void cancel() {
    _isCancelled = true;
  }

  /// Generates variation tree recursively for startNode based on params.
  ///
  /// Pass [analyzer] to drive a specific engine; it defaults to the shared
  /// StockfishService singleton, which is what the app uses.
  Future<void> generateTree({
    required AnalysisNode startNode,
    required AutoAnalysisParams params,
    PositionAnalyzer? analyzer,
    StockfishService? stockfishService,
    Function(int processed, int total, String statusMsg)? onProgress,
  }) async {
    _isCancelled = false;
    int processedCount = 0;
    final int estimatedTotal = calculateEstimatedNodes(params.pliesDepth, params.candidateCount);

    final resolvedAnalyzer =
        analyzer ?? (stockfishService ?? StockfishService()).analyzePositionSync;

    await _expandNodeRecursive(
      currentNode: startNode,
      currentPly: 0,
      params: params,
      analyzer: resolvedAnalyzer,
      onProgress: (msg) {
        processedCount++;
        onProgress?.call(processedCount, estimatedTotal, msg);
      },
    );
  }

  Future<void> _expandNodeRecursive({
    required AnalysisNode currentNode,
    required int currentPly,
    required AutoAnalysisParams params,
    required PositionAnalyzer analyzer,
    required Function(String statusMsg) onProgress,
  }) async {
    if (_isCancelled || currentPly >= params.pliesDepth) return;

    final game = chess.Chess.fromFEN(currentNode.fen);
    if (game.game_over) return;

    AppLogger.log('[AutoTree] 🌳 Generišem n=${params.candidateCount} kandidata za čvor na dubini d=${params.engineDepth} | FEN: ${currentNode.fen}');
    AppLogger.log('[AutoTree] ⏱️ Čekam Stockfish odgovor za depth ${params.engineDepth}...');
    onProgress('Analiziram poziciju (Sloj ${currentPly + 1}/${params.pliesDepth})...');

    final lines = await analyzer(
      currentNode.fen,
      depth: params.engineDepth,
      multiPV: params.candidateCount,
      timeout: const Duration(seconds: 12),
    );

    if (_isCancelled) return;

    if (lines.isEmpty) {
      AppLogger.log('[AutoTree WARNING] ⚠️ Stockfish nije vratio linije za FEN: ${currentNode.fen}. Preskačem grananje čvora.');
      return;
    }

    final isWhiteToMove = currentNode.fen.contains(' w ');

    // Parse eval to numeric double score from White's perspective
    double parseEvalToNumeric(String evalStr) {
      if (evalStr.contains('M')) {
        final mateNum = int.tryParse(evalStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
        return evalStr.contains('-') ? (-1000.0 + mateNum) : (1000.0 - mateNum);
      }
      return double.tryParse(evalStr.replaceAll('+', '')) ?? 0.0;
    }

    final sortedLines = List<AnalysisLine>.from(lines);
    sortedLines.sort((a, b) {
      final scoreA = parseEvalToNumeric(a.evaluation);
      final scoreB = parseEvalToNumeric(b.evaluation);
      return isWhiteToMove ? scoreB.compareTo(scoreA) : scoreA.compareTo(scoreB);
    });

    final topScore = parseEvalToNumeric(sortedLines.first.evaluation);

    for (var line in sortedLines.take(params.candidateCount)) {
      if (_isCancelled) break;

      final moveUci = line.bestMoveLan;
      final moveSanStr = line.bestMoveSan;
      if (moveUci.isEmpty && moveSanStr.isEmpty) continue;

      final lineScore = parseEvalToNumeric(line.evaluation);
      final evalDelta = isWhiteToMove ? (topScore - lineScore) : (lineScore - topScore);

      // Check pruning delta
      if (evalDelta > params.deltaCutoff) {
        AppLogger.log('[AutoTree] ✂️ Potez ${moveSanStr.isNotEmpty ? moveSanStr : moveUci} orezan (eval: ${line.evaluation}, delta > ${params.deltaCutoff})');
        continue;
      }

      // Convert move to legal chess move on current board FEN
      final tempGame = chess.Chess.fromFEN(currentNode.fen);
      bool moveOk = false;

      // Try UCI format first (e.g. e2e4)
      if (moveUci.length >= 4) {
        final from = moveUci.substring(0, 2);
        final to = moveUci.substring(2, 4);
        final promo = moveUci.length > 4 ? moveUci.substring(4, 5) : null;
        try {
          moveOk = tempGame.move({'from': from, 'to': to, if (promo != null) 'promotion': promo});
        } catch (_) {}
      }

      // Try SAN format if UCI failed
      if (!moveOk && moveSanStr.isNotEmpty) {
        try {
          moveOk = tempGame.move(moveSanStr);
        } catch (_) {}
      }

      if (!moveOk) {
        AppLogger.log('[AutoTree WARNING] ⚠️ Nevalidan potez ${moveSanStr.isNotEmpty ? moveSanStr : moveUci} za FEN: ${currentNode.fen}');
        continue;
      }

      final childFen = tempGame.fen;
      final moveObj = tempGame.history.last.move;
      final san = moveSanStr.isNotEmpty ? moveSanStr : (moveObj.fromAlgebraic + moveObj.toAlgebraic);
      final uci = moveObj.fromAlgebraic + moveObj.toAlgebraic + (moveObj.promotion?.name ?? '');

      final childNode = currentNode.addChild(
        childFen: childFen,
        san: san,
        uci: uci,
      );
      childNode.eval = lineScore;

      // Recurse to next ply
      await _expandNodeRecursive(
        currentNode: childNode,
        currentPly: currentPly + 1,
        params: params,
        analyzer: analyzer,
        onProgress: onProgress,
      );
    }
  }

  int calculateEstimatedNodes(int plies, int candidates) {
    int total = 0;
    int currentLevel = 1;
    for (int i = 0; i < plies; i++) {
      currentLevel *= candidates;
      total += currentLevel;
    }
    return total;
  }
}
