import 'json_int.dart';

class ProfileBucket {
  final String key;
  final int games;
  final double? score;

  const ProfileBucket({
    required this.key,
    required this.games,
    this.score,
  });

  factory ProfileBucket.fromJson(Map<String, dynamic> json) {
    return ProfileBucket(
      key: json['key'] as String,
      games: jsonInt(json['games']),
      score: (json['score'] as num?)?.toDouble(),
    );
  }
}

class ProfileYearBucket extends ProfileBucket {
  final int? avgElo;

  const ProfileYearBucket({
    required super.key,
    required super.games,
    super.score,
    this.avgElo,
  });

  factory ProfileYearBucket.fromJson(Map<String, dynamic> json) {
    return ProfileYearBucket(
      key: json['key'] as String,
      games: jsonInt(json['games']),
      score: (json['score'] as num?)?.toDouble(),
      avgElo: json['avgElo'] == null ? null : jsonInt(json['avgElo']),
    );
  }
}

class ClockProfile {
  final int sampled;
  final int reachedMove20;
  final int lostOnTime;
  final double? hurriedShare;
  final List<ProfileBucket> atMove20;

  const ClockProfile({
    required this.sampled,
    required this.reachedMove20,
    required this.lostOnTime,
    this.hurriedShare,
    required this.atMove20,
  });

  factory ClockProfile.fromJson(Map<String, dynamic> json) {
    return ClockProfile(
      sampled: jsonInt(json['sampled']),
      reachedMove20: jsonInt(json['reachedMove20']),
      lostOnTime: jsonInt(json['lostOnTime']),
      hurriedShare: (json['hurriedShare'] as num?)?.toDouble(),
      atMove20: (json['atMove20'] as List?)
              ?.map((e) => ProfileBucket.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class PlayerProfile {
  final List<ProfileBucket> byColor;
  final List<ProfileBucket> bySpeed;
  final List<ProfileBucket> byTermination;
  final List<ProfileBucket> byLength;
  final List<ProfileBucket> byPhase;
  final List<ProfileYearBucket> byYear;
  final List<ProfileBucket> byOpening;
  final ClockProfile? clock;

  const PlayerProfile({
    required this.byColor,
    required this.bySpeed,
    required this.byTermination,
    required this.byLength,
    required this.byPhase,
    required this.byYear,
    required this.byOpening,
    this.clock,
  });

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    List<ProfileBucket> parseList(String key) =>
        (json[key] as List?)
            ?.map((e) => ProfileBucket.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return PlayerProfile(
      byColor: parseList('byColor'),
      bySpeed: parseList('bySpeed'),
      byTermination: parseList('byTermination'),
      byLength: parseList('byLength'),
      byPhase: parseList('byPhase'),
      byYear: (json['byYear'] as List?)
              ?.map(
                  (e) => ProfileYearBucket.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      byOpening: parseList('byOpening'),
      clock: json['clock'] != null
          ? ClockProfile.fromJson(json['clock'] as Map<String, dynamic>)
          : null,
    );
  }
}
