import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:chess_app/services/app_logger.dart';

/// WDL category as reported by the Lichess Syzygy tablebase API, always
/// expressed from the perspective of the side to move in the position it
/// describes.
enum SyzygyCategory {
  win,
  maybeWin,
  cursedWin,
  draw,
  blessedLoss,
  maybeLoss,
  loss,
  unknown,
}

SyzygyCategory syzygyCategoryFromString(String? raw) {
  switch (raw) {
    case 'win':
      return SyzygyCategory.win;
    case 'maybe-win':
      return SyzygyCategory.maybeWin;
    case 'cursed-win':
      return SyzygyCategory.cursedWin;
    case 'draw':
      return SyzygyCategory.draw;
    case 'blessed-loss':
      return SyzygyCategory.blessedLoss;
    case 'maybe-loss':
      return SyzygyCategory.maybeLoss;
    case 'loss':
      return SyzygyCategory.loss;
    default:
      return SyzygyCategory.unknown;
  }
}

/// Lower rank sorts first. Ranked from the perspective of the side about to
/// play the move (i.e. inverted from [SyzygyCategory], since the API reports
/// each move's category for the opponent who is to move afterwards).
int _moveRankForMover(SyzygyCategory category) {
  switch (category) {
    case SyzygyCategory.loss:
      return 0; // opponent loses => best for the mover
    case SyzygyCategory.maybeLoss:
      return 1;
    case SyzygyCategory.blessedLoss:
      return 2;
    case SyzygyCategory.draw:
    case SyzygyCategory.unknown:
      return 3;
    case SyzygyCategory.cursedWin:
      return 4;
    case SyzygyCategory.maybeWin:
      return 5;
    case SyzygyCategory.win:
      return 6; // opponent wins => worst for the mover
  }
}

class SyzygyMove {
  final String uci;
  final String san;
  final SyzygyCategory category;
  final int? dtz;
  final int? dtm;
  final bool zeroing;
  final bool checkmate;
  final bool stalemate;

  SyzygyMove({
    required this.uci,
    required this.san,
    required this.category,
    this.dtz,
    this.dtm,
    required this.zeroing,
    required this.checkmate,
    required this.stalemate,
  });

  factory SyzygyMove.fromJson(Map<String, dynamic> json) {
    return SyzygyMove(
      uci: json['uci'] as String? ?? '',
      san: json['san'] as String? ?? '',
      category: syzygyCategoryFromString(json['category'] as String?),
      dtz: json['dtz'] as int?,
      dtm: json['dtm'] as int?,
      zeroing: json['zeroing'] as bool? ?? false,
      checkmate: json['checkmate'] as bool? ?? false,
      stalemate: json['stalemate'] as bool? ?? false,
    );
  }
}

class SyzygyResult {
  final String fen;
  final SyzygyCategory category;
  final int? dtz;
  final int? dtm;
  final bool checkmate;
  final bool stalemate;
  final bool insufficientMaterial;
  final List<SyzygyMove> moves;

  SyzygyResult({
    required this.fen,
    required this.category,
    this.dtz,
    this.dtm,
    required this.checkmate,
    required this.stalemate,
    required this.insufficientMaterial,
    required this.moves,
  });

  factory SyzygyResult.fromJson(String fen, Map<String, dynamic> json) {
    final movesJson = (json['moves'] as List?) ?? const [];
    final moves = movesJson
        .whereType<Map<String, dynamic>>()
        .map(SyzygyMove.fromJson)
        .toList()
      ..sort((a, b) {
        final rankDiff = _moveRankForMover(a.category)
            .compareTo(_moveRankForMover(b.category));
        if (rankDiff != 0) return rankDiff;
        return (a.dtz ?? 0).abs().compareTo((b.dtz ?? 0).abs());
      });

    return SyzygyResult(
      fen: fen,
      category: syzygyCategoryFromString(json['category'] as String?),
      dtz: json['dtz'] as int?,
      dtm: json['dtm'] as int?,
      checkmate: json['checkmate'] as bool? ?? false,
      stalemate: json['stalemate'] as bool? ?? false,
      insufficientMaterial: json['insufficient_material'] as bool? ?? false,
      moves: moves,
    );
  }
}

/// Looks up exact endgame results (win/draw/loss + distance-to-zero) from the
/// public Lichess Syzygy tablebase API. Only meaningful for positions with 7
/// or fewer pieces on the board.
class SyzygyTablebaseService {
  SyzygyTablebaseService._();
  static final SyzygyTablebaseService instance = SyzygyTablebaseService._();

  static const _baseUrl = 'https://tablebase.lichess.ovh/standard';

  final Map<String, SyzygyResult?> _cache = {};

  Future<SyzygyResult?> lookup(String fen) async {
    if (_cache.containsKey(fen)) return _cache[fen];

    try {
      final url = '$_baseUrl?fen=${Uri.encodeComponent(fen)}';
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));

      if (res.statusCode != 200) {
        AppLogger.log(
            '[Syzygy] ⚠️ Tablebase HTTP ${res.statusCode} for FEN: $fen');
        return null;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final result = SyzygyResult.fromJson(fen, data);
      _cache[fen] = result;
      return result;
    } catch (e) {
      AppLogger.log('[Syzygy] ❌ Tablebase lookup failed: $e');
      return null;
    }
  }
}
