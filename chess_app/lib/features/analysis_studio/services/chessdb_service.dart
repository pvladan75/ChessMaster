import 'package:http/http.dart' as http;
import 'package:chess_app/services/app_logger.dart';

/// A single candidate move as scored by ChessDB.cn's shared cloud database —
/// community/engine consensus (centipawn score + implied winrate), not real
/// game popularity like the Lichess Explorer.
class ChessDbMove {
  final String uci;
  final int score; // centipawns, from the mover's perspective
  final int rank;
  final double winrate; // 0-100, from the mover's perspective

  ChessDbMove({
    required this.uci,
    required this.score,
    required this.rank,
    required this.winrate,
  });
}

class ChessDbResult {
  final String fen;
  final List<ChessDbMove> moves;

  ChessDbResult({required this.fen, required this.moves});
}

/// Free, no-auth alternative to the (now token-gated) Lichess Opening
/// Explorer. Source: https://www.chessdb.cn — a community-maintained cloud
/// database of engine-analyzed positions. It reports move quality (score,
/// winrate) from shared analysis, not how often real players chose a move.
class ChessDbService {
  ChessDbService._();
  static final ChessDbService instance = ChessDbService._();

  static const _baseUrl = 'https://www.chessdb.cn/cdb.php';

  final Map<String, ChessDbResult?> _cache = {};

  Future<ChessDbResult?> lookup(String fen) async {
    if (_cache.containsKey(fen)) return _cache[fen];

    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'action': 'queryall',
        'board': fen,
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 6));

      if (res.statusCode != 200) {
        AppLogger.log('[ChessDB] ⚠️ HTTP ${res.statusCode} for FEN: $fen');
        return null;
      }

      final body = res.body.trim();
      if (body.isEmpty || body.startsWith('unknown') || body.startsWith('invalid')) {
        final result = ChessDbResult(fen: fen, moves: []);
        _cache[fen] = result;
        return result;
      }

      final moves = <ChessDbMove>[];
      for (final entry in body.split('|')) {
        final fields = <String, String>{};
        for (final pair in entry.split(',')) {
          final idx = pair.indexOf(':');
          if (idx <= 0) continue;
          fields[pair.substring(0, idx)] = pair.substring(idx + 1);
        }
        final uci = fields['move'];
        if (uci == null || uci.isEmpty) continue;
        moves.add(ChessDbMove(
          uci: uci,
          score: int.tryParse(fields['score'] ?? '') ?? 0,
          rank: int.tryParse(fields['rank'] ?? '') ?? 0,
          winrate: double.tryParse(fields['winrate'] ?? '') ?? 50.0,
        ));
      }

      // Best move first; ChessDB already orders by rank/score, but don't rely on it.
      moves.sort((a, b) {
        final rankCompare = b.rank.compareTo(a.rank);
        return rankCompare != 0 ? rankCompare : b.score.compareTo(a.score);
      });

      final result = ChessDbResult(fen: fen, moves: moves);
      AppLogger.log('[ChessDB] ✅ Parsed: ${result.moves.length} poteza za FEN: $fen');
      _cache[fen] = result;
      return result;
    } catch (e) {
      AppLogger.log('[ChessDB] ❌ Lookup failed: $e');
      return null;
    }
  }
}
