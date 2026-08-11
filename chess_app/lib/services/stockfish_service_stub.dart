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

  // ─── SUBSCRIBER STACK ───
  // Mirrors the native implementation: screens attach while on top of the
  // navigation stack, and detaching reactivates the screen underneath rather
  // than leaving the shared engine with no listener.
  final List<_EngineSubscriber> _subscribers = [];

  void attach(
    Object owner, {
    Function(String evaluation, String bestMove, String continuation, int multipv, int depth, bool isFinal, String analyzedFen)? onEvaluation,
    Function(Map<int, AnalysisLine> lines)? onMultiPV,
  }) {
    _subscribers.removeWhere((s) => identical(s.owner, owner));
    _subscribers.add(_EngineSubscriber(owner, onEvaluation, onMultiPV));
    _activateTopSubscriber();
  }

  void detach(Object owner) {
    _subscribers.removeWhere((s) => identical(s.owner, owner));
    stopAnalysis();
    _activateTopSubscriber();
  }

  void _activateTopSubscriber() {
    if (_subscribers.isEmpty) {
      onEvaluationChanged = null;
      onMultiPVUpdated = null;
      return;
    }
    final top = _subscribers.last;
    onEvaluationChanged = top.onEvaluation;
    onMultiPVUpdated = top.onMultiPV;
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

  /// Deliberately does not clear callbacks — see the native implementation.
  void dispose() {
    stopAnalysis();
  }

  void shutdown() {
    _isActive = false;
    onEvaluationChanged = null;
    onMultiPVUpdated = null;
  }

  Future<List<AnalysisLine>> analyzePositionSync(
    String fen, {
    required int depth,
    required int multiPV,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await analyzePosition(fen, depth: depth);
    return _engineLines.values.toList();
  }

}

/// One screen's registration with the shared engine.
class _EngineSubscriber {
  final Object owner;
  final Function(String evaluation, String bestMove, String continuation, int multipv, int depth, bool isFinal, String analyzedFen)? onEvaluation;
  final Function(Map<int, AnalysisLine> lines)? onMultiPV;

  _EngineSubscriber(this.owner, this.onEvaluation, this.onMultiPV);
}
