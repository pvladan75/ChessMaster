import 'package:chess_app/features/archive/models/json_int.dart';

class EndgameMistake {
  final String id;
  final String gameId;
  final int ply;
  final String fenBefore;
  final String playedUci;
  final String? bestUci;
  final int wdlBefore;
  final int wdlAfter;
  final DateTime? dueAt;
  final DateTime? playedAt;
  final String? opponent;
  final String? result;

  EndgameMistake({
    required this.id,
    required this.gameId,
    required this.ply,
    required this.fenBefore,
    required this.playedUci,
    this.bestUci,
    required this.wdlBefore,
    required this.wdlAfter,
    this.dueAt,
    this.playedAt,
    this.opponent,
    this.result,
  });

  factory EndgameMistake.fromJson(Map<String, dynamic> json) {
    return EndgameMistake(
      id: json['id'] as String,
      gameId: json['game_id'] as String,
      ply: jsonInt(json['ply']),
      fenBefore: json['fen_before'] as String,
      playedUci: json['played_uci'] as String,
      bestUci: json['best_uci'] as String?,
      wdlBefore: jsonInt(json['wdl_before']),
      wdlAfter: jsonInt(json['wdl_after']),
      dueAt: json['due_at'] != null ? DateTime.parse(json['due_at']) : null,
      playedAt:
          json['played_at'] != null ? DateTime.parse(json['played_at']) : null,
      opponent: json['opponent'] as String?,
      result: json['result'] as String?,
    );
  }
}
