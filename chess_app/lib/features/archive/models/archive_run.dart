import 'package:chess_app/features/archive/models/json_int.dart';

class ArchiveRun {
  const ArchiveRun({
    required this.id,
    required this.source,
    required this.subject,
    required this.status,
    required this.gamesRead,
    required this.gamesStored,
    required this.gamesDuplicate,
    required this.gamesSkipped,
    required this.skippedByReason,
    this.error,
    required this.startedAt,
    this.finishedAt,
  });

  final int id;
  final String source;
  final String subject;
  final String status;
  final int gamesRead;
  final int gamesStored;
  final int gamesDuplicate;
  final int gamesSkipped;
  final Map<String, int> skippedByReason;
  final String? error;
  final String startedAt;
  final String? finishedAt;

  factory ArchiveRun.fromJson(Map<String, dynamic> json) {
    return ArchiveRun(
      id: jsonInt(json['id']),
      source: json['source'] as String,
      subject: json['subject'] as String,
      status: json['status'] as String,
      gamesRead: (json['games_read'] as num).toInt(),
      gamesStored: (json['games_stored'] as num).toInt(),
      gamesDuplicate: (json['games_duplicate'] as num).toInt(),
      gamesSkipped: (json['games_skipped'] as num).toInt(),
      skippedByReason: (json['skipped_by_reason'] as Map?)
              ?.map((k, v) => MapEntry(k as String, (v as num).toInt())) ??
          {},
      error: json['error'] as String?,
      startedAt: json['started_at'] as String,
      finishedAt: json['finished_at'] as String?,
    );
  }
}
