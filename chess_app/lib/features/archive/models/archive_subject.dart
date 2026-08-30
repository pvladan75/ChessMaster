import 'package:chess_app/features/archive/models/json_int.dart';

class ArchiveSubject {
  final String subject;
  final int games;
  final int reachedTablebase;
  final int withClocks;
  final String? oldest;
  final String? newest;
  final String? lastImportAt;

  const ArchiveSubject({
    required this.subject,
    required this.games,
    required this.reachedTablebase,
    required this.withClocks,
    this.oldest,
    this.newest,
    this.lastImportAt,
  });

  factory ArchiveSubject.fromJson(Map<String, dynamic> json) {
    return ArchiveSubject(
      subject: json['subject'] as String,
      games: jsonInt(json['games']),
      reachedTablebase: jsonInt(json['reached_tablebase']),
      withClocks: jsonInt(json['with_clocks']),
      oldest: json['oldest'] as String?,
      newest: json['newest'] as String?,
      lastImportAt: json['last_import_at'] as String?,
    );
  }
}
