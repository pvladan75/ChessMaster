import 'dart:convert';
import 'package:http/http.dart' as http;

class StockfishService {
  Function(String evaluation, String bestMove, String continuation, int multipv)? onEvaluationChanged;

  bool _isActive = false;
  int _requestId = 0;

  bool get isActive => _isActive;
  bool get isSupported => true;
  bool get isOnline => true;

  void initEngine() {
    _isActive = true;
  }

  Future<void> analyzePosition(String fen, {int depth = 10, bool isInfinite = false}) async {
    if (!_isActive) return;

    final reqId = ++_requestId;
    
    // The online API supports depth 5-15.
    final targetDepth = isInfinite ? 15 : (depth > 15 ? 15 : depth);

    try {
      final url = 'https://stockfish.online/api/s/v2.php?fen=${Uri.encodeComponent(fen)}&depth=$targetDepth';
      final response = await http.get(Uri.parse(url));

      if (reqId != _requestId) return; // Ignore outdated responses

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
            onEvaluationChanged!(eval, bestMove, continuation, 1);
          }
        }
      }
    } catch (_) {
      // Ignore network errors gracefully
    }
  }

  void dispose() {
    _isActive = false;
  }
}
