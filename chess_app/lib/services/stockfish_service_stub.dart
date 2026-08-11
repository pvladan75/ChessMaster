import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:chess_app/models/analysis_models.dart';

class StockfishService {
  // ─── SINGLETON ───
  static final StockfishService _instance = StockfishService._internal();
  factory StockfishService() => _instance;
  StockfishService._internal();

  Function(String evaluation, String bestMove, String continuation, int multipv, int depth, bool isFinal, String analyzedFen)? onEvaluationChanged;
  Function(Map<int, AnalysisLine> lines)? onMultiPVUpdated;
  final Map<int, AnalysisLine> _engineLines = {};

  bool _isActive = false;
  int _requestId = 0;

  bool get isActive => _isActive;
  bool get isSupported => true;
  bool get isOnline => true;
  bool get isCustomEngineActive => false;

  Future<void> initEngine() async {
    _isActive = true;
  }

  void clearCallbacks() {
    onEvaluationChanged = null;
    onMultiPVUpdated = null;
  }

  Future<void> analyzePosition(String fen, {int depth = 10, bool isInfinite = false}) async {
    _isActive = true;

    final reqId = ++_requestId;
    
    final targetDepth = isInfinite ? 50 : depth.clamp(5, 50);

    try {
      final url = 'https://stockfish.online/api/s/v2.php?fen=${Uri.encodeComponent(fen)}&depth=$targetDepth';
      final response = await http.get(Uri.parse(url));

      if (reqId != _requestId) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          String eval = '0.00';
          if (data['mate'] != null) {
            final mate = data['mate'] as int;
            eval = mate > 0 ? 'M$mate' : '-M${mate.abs()}';
          } else if (data['evaluation'] != null) {
            final double score = (data['evaluation'] as num).toDouble();
            eval = score > 0 ? '+$score' : '$score';
          }

          String bestMove = '-';
          if (data['bestmove'] != null) {
            final bestStr = data['bestmove'] as String;
            final match = RegExp(r'bestmove\s+(\S+)').firstMatch(bestStr);
            if (match != null) {
              bestMove = match.group(1)!;
            }
          }

          String continuation = '';
          if (data['continuation'] != null) {
            continuation = data['continuation'] as String;
          }

          if (onEvaluationChanged != null) {
            onEvaluationChanged!(eval, bestMove, continuation, 1, targetDepth, true, fen);
          }

          _engineLines[1] = AnalysisLine.fromPv(
            multipv: 1,
            eval: eval,
            pvString: continuation.isNotEmpty ? continuation : bestMove,
            startingFen: fen,
          );
          if (onMultiPVUpdated != null) {
            onMultiPVUpdated!(_engineLines);
          }
        }
      }
    } catch (_) {
      // Ignore network errors gracefully
    }
  }

  void stopAnalysis() {
    _requestId++;
    _isActive = false;
  }

  void setMultiPV(int count) {}

  void dispose() {
    stopAnalysis();
    clearCallbacks();
  }

  void shutdown() {
    _isActive = false;
    onEvaluationChanged = null;
    onMultiPVUpdated = null;
  }
}
