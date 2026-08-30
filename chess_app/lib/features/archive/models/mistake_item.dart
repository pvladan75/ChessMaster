import 'package:chess_app/features/archive/models/json_int.dart';

class MistakeItem {
  final String id;
  final String gameId;
  final int ply;
  final String fenBefore;
  final String playedUci;
  final String? bestUci;
  final String kind;
  final String? theme;
  final int? swingCp;
  final int? wdlBefore;
  final int? wdlAfter;
  final int intervalDays;
  final int repetitions;
  final int lapses;
  final DateTime dueAt;
  final DateTime playedAt;
  final String? opponent;
  final String? result;
  final String? subjectColor;
  final String? opening;

  const MistakeItem({
    required this.id,
    required this.gameId,
    required this.ply,
    required this.fenBefore,
    required this.playedUci,
    this.bestUci,
    required this.kind,
    this.theme,
    this.swingCp,
    this.wdlBefore,
    this.wdlAfter,
    required this.intervalDays,
    required this.repetitions,
    required this.lapses,
    required this.dueAt,
    required this.playedAt,
    this.opponent,
    this.result,
    this.subjectColor,
    this.opening,
  });

  factory MistakeItem.fromJson(Map<String, dynamic> json) {
    return MistakeItem(
      id: json['id']
          .toString(), // jsonInt is for converting numbers to int, but Postgres returns id as String. We should keep it as String per section 4
      gameId: json['game_id'].toString(),
      ply: jsonInt(json['ply']),
      fenBefore: json['fen_before'] as String,
      playedUci: json['played_uci'] as String,
      bestUci: json['best_uci'] as String?,
      kind: json['kind'] as String,
      theme: json['theme'] as String?,
      swingCp: json['swing_cp'] != null ? jsonInt(json['swing_cp']) : null,
      wdlBefore:
          json['wdl_before'] != null ? jsonInt(json['wdl_before']) : null,
      wdlAfter: json['wdl_after'] != null ? jsonInt(json['wdl_after']) : null,
      intervalDays: jsonInt(json['interval_days']),
      repetitions: jsonInt(json['repetitions']),
      lapses: jsonInt(json['lapses']),
      dueAt: DateTime.parse(json['due_at'] as String),
      playedAt: DateTime.parse(json['played_at'] as String),
      opponent: json['opponent'] as String?,
      result: json['result'] as String?,
      subjectColor: json['subject_color'] as String?,
      opening: json['opening'] as String?,
    );
  }
}

class GradeResponse {
  final bool ok;
  final int? intervalDays;
  final DateTime? dueAt;
  final String? description;
  final Map<String, dynamic>? item;
  final String? error;

  const GradeResponse({
    required this.ok,
    this.intervalDays,
    this.dueAt,
    this.description,
    this.item,
    this.error,
  });

  factory GradeResponse.fromJson(Map<String, dynamic> json) {
    if (json['error'] != null) {
      return GradeResponse(
        ok: false,
        error: json['error'] as String,
      );
    }
    return GradeResponse(
      ok: json['ok'] as bool? ?? true,
      intervalDays:
          json['intervalDays'] != null ? jsonInt(json['intervalDays']) : null,
      dueAt: json['dueAt'] != null
          ? DateTime.parse(json['dueAt'] as String)
          : null,
      description: json['description'] as String?,
      item: json['item'] as Map<String, dynamic>?,
    );
  }
}
