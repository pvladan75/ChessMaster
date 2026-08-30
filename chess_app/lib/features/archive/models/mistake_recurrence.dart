import 'package:chess_app/features/archive/models/json_int.dart';

class RecurrenceBucket {
  final String key;
  final int count;
  final int worstSwing;
  final String example;

  const RecurrenceBucket({
    required this.key,
    required this.count,
    required this.worstSwing,
    required this.example,
  });

  factory RecurrenceBucket.fromJson(Map<String, dynamic> json) {
    return RecurrenceBucket(
      key: json['key'] as String,
      count: jsonInt(json['count']),
      worstSwing: jsonInt(json['worstSwing']),
      example:
          json['example'].toString(), // Postgres BIGINT example comes as string
    );
  }
}

class MistakeRecurrence {
  final List<RecurrenceBucket> motifs;
  final List<RecurrenceBucket> endings;

  const MistakeRecurrence({
    this.motifs = const [],
    this.endings = const [],
  });

  factory MistakeRecurrence.fromJson(Map<String, dynamic> json) {
    return MistakeRecurrence(
      motifs: (json['motifs'] as List?)
              ?.map((e) => RecurrenceBucket.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      endings: (json['endings'] as List?)
              ?.map((e) => RecurrenceBucket.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
