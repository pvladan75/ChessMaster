import 'json_int.dart';

class ArchiveHomeworkCandidate {
  final String mistakeId;
  final String? kind;
  final String? theme;
  final String fen;
  final String playedSan;
  final String solutionSan;
  final String? playedAt;
  final String? opening;

  const ArchiveHomeworkCandidate({
    required this.mistakeId,
    this.kind,
    this.theme,
    required this.fen,
    required this.playedSan,
    required this.solutionSan,
    this.playedAt,
    this.opening,
  });

  factory ArchiveHomeworkCandidate.fromJson(Map<String, dynamic> json) {
    return ArchiveHomeworkCandidate(
      mistakeId: json['mistakeId'] as String, // From string as per brief
      kind: json['kind'] as String?,
      theme: json['theme'] as String?,
      fen: json['fen'] as String,
      playedSan: json['playedSan'] as String,
      solutionSan: json['solutionSan'] as String,
      playedAt: json['playedAt'] as String?,
      opening: json['opening'] as String?,
    );
  }
}

class ArchiveHomeworkResponse {
  final bool dryRun;
  final int? candidatesCount;
  final List<ArchiveHomeworkCandidate>? chosen;
  final Map<String, dynamic>? assignment;
  final List<dynamic>? items;
  final int? skipped;

  const ArchiveHomeworkResponse({
    required this.dryRun,
    this.candidatesCount,
    this.chosen,
    this.assignment,
    this.items,
    this.skipped,
  });

  factory ArchiveHomeworkResponse.fromJson(Map<String, dynamic> json) {
    return ArchiveHomeworkResponse(
      dryRun: json['dryRun'] as bool? ?? false,
      candidatesCount:
          json['candidates'] != null ? jsonInt(json['candidates']) : null,
      chosen: (json['chosen'] as List?)
          ?.map((e) =>
              ArchiveHomeworkCandidate.fromJson(e as Map<String, dynamic>))
          .toList(),
      assignment: json['assignment'] as Map<String, dynamic>?,
      items: json['items'] as List?,
      skipped: json['skipped'] != null ? jsonInt(json['skipped']) : null,
    );
  }
}
