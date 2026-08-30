import 'package:chess_app/features/archive/models/json_int.dart';

class EndgameAudit {
  final String id;
  final String subject;
  final String status;
  final int gamesTotal;
  final int gamesDone;
  final int positionsProbed;
  final int cacheHits;
  final int positionsUnknown;
  final int mistakesFound;
  final String? error;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  EndgameAudit({
    required this.id,
    required this.subject,
    required this.status,
    required this.gamesTotal,
    required this.gamesDone,
    required this.positionsProbed,
    required this.cacheHits,
    required this.positionsUnknown,
    required this.mistakesFound,
    this.error,
    this.startedAt,
    this.finishedAt,
  });

  factory EndgameAudit.fromJson(Map<String, dynamic> json) {
    return EndgameAudit(
      id: json['id'] as String,
      subject: json['subject'] as String,
      status: json['status'] as String,
      gamesTotal: jsonInt(json['games_total']),
      gamesDone: jsonInt(json['games_done']),
      positionsProbed: jsonInt(json['positions_probed']),
      cacheHits: jsonInt(json['cache_hits']),
      positionsUnknown: jsonInt(json['positions_unknown']),
      mistakesFound: jsonInt(json['mistakes_found']),
      error: json['error'] as String?,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'])
          : null,
      finishedAt: json['finished_at'] != null
          ? DateTime.parse(json['finished_at'])
          : null,
    );
  }
}
