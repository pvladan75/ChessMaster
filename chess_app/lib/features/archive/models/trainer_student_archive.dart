import 'json_int.dart';
import 'leak_report.dart';
import 'mistake_recurrence.dart';

class MistakeSummaryCounts {
  final int total;
  final int due;
  final int mature;
  final Map<String, int> byKind;

  const MistakeSummaryCounts({
    required this.total,
    required this.due,
    required this.mature,
    required this.byKind,
  });

  factory MistakeSummaryCounts.fromJson(Map<String, dynamic> json) {
    final byKindRaw = json['byKind'] as Map? ?? {};
    return MistakeSummaryCounts(
      total: jsonInt(json['total'] ?? 0),
      due: jsonInt(json['due'] ?? 0),
      mature: jsonInt(json['mature'] ?? 0),
      byKind: byKindRaw.map((k, v) => MapEntry(k as String, jsonInt(v))),
    );
  }
}

class TrendMonth {
  final String month;
  final int games;
  final double? score;
  final int? avgElo;

  const TrendMonth({
    required this.month,
    required this.games,
    this.score,
    this.avgElo,
  });

  factory TrendMonth.fromJson(Map<String, dynamic> json) {
    return TrendMonth(
      month: json['month'] as String,
      games: jsonInt(json['games']),
      score: (json['score'] as num?)?.toDouble(),
      avgElo: json['avgElo'] == null ? null : jsonInt(json['avgElo']),
    );
  }
}

class TrainerStudentArchive {
  final String? subject;
  final int games;
  final LeakReport? leaks;
  final MistakeSummaryCounts? mistakes;
  final MistakeRecurrence? recurrence;
  final List<TrendMonth>? trend;

  const TrainerStudentArchive({
    this.subject,
    required this.games,
    this.leaks,
    this.mistakes,
    this.recurrence,
    this.trend,
  });

  factory TrainerStudentArchive.fromJson(Map<String, dynamic> json) {
    return TrainerStudentArchive(
      subject: json['subject'] as String?,
      games: jsonInt(json['games'] ?? 0),
      leaks: json['leaks'] != null
          ? LeakReport.fromJson(json['leaks'] as Map<String, dynamic>)
          : null,
      mistakes: json['mistakes'] != null
          ? MistakeSummaryCounts.fromJson(
              json['mistakes'] as Map<String, dynamic>)
          : null,
      recurrence: json['recurrence'] != null
          ? MistakeRecurrence.fromJson(
              json['recurrence'] as Map<String, dynamic>)
          : null,
      trend: (json['trend'] as List?)
          ?.map((e) => TrendMonth.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
