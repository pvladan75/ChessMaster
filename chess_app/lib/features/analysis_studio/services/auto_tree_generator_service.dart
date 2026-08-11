import 'dart:async';
import 'package:chess/chess.dart' as chess;
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/services/stockfish_service.dart';

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

class AutoTreeGeneratorService {
  bool _isCancelled = false;

  void cancel() {
    _isCancelled = true;
  }

  /// Generates variation tree recursively for startNode based on params.
  Future<void> generateTree({
    required AnalysisNode startNode,
    required AutoAnalysisParams params,
    required StockfishService stockfishService,
    Function(int processed, int total, String statusMsg)? onProgress,
  }) async {
    _isCancelled = false;
    int processedCount = 0;
    final int estimatedTotal = _calculateEstimatedNodes(params.pliesDepth, params.candidateCount);

    await _expandNodeRecursive(
      currentNode: startNode,
      currentPly: 0,
      params: params,
      stockfishService: stockfishService,
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
    required StockfishService stockfishService,
    required Function(String statusMsg) onProgress,
  }) async {
    if (_isCancelled || currentPly >= params.pliesDepth) return;

    final game = chess.Chess.fromFEN(currentNode.fen);
    if (game.game_over) return;

    final moves = game.moves({'verbose': true});
    if (moves.isEmpty) return;

    // Get candidate moves (up to n top candidates)
    final candidateMoves = moves.take(params.candidateCount).toList();

    for (var moveObj in candidateMoves) {
      if (_isCancelled) break;

      final from = moveObj['from'] as String;
      final to = moveObj['to'] as String;
      final promo = (moveObj['promotion'] as String?) ?? '';
      final san = (moveObj['san'] as String?) ?? '$from$to';
      final uci = '$from$to$promo';

      final tempGame = chess.Chess.fromFEN(currentNode.fen);
      tempGame.move({'from': from, 'to': to, if (promo.isNotEmpty) 'promotion': promo});
      final childFen = tempGame.fen;

      final childNode = currentNode.addChild(
        childFen: childFen,
        san: san,
        uci: uci,
      );

      onProgress('Analiziram $san (Sloj ${currentPly + 1}/${params.pliesDepth})...');
      await Future.delayed(const Duration(milliseconds: 20));

      // Recurse to next ply
      await _expandNodeRecursive(
        currentNode: childNode,
        currentPly: currentPly + 1,
        params: params,
        stockfishService: stockfishService,
        onProgress: onProgress,
      );
    }
  }

  int _calculateEstimatedNodes(int plies, int candidates) {
    int total = 0;
    int currentLevel = 1;
    for (int i = 0; i < plies; i++) {
      currentLevel *= candidates;
      total += currentLevel;
    }
    return total;
  }
}
