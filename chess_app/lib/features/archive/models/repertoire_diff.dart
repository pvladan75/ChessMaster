import 'package:chess_app/features/archive/models/json_int.dart';

class RepertoireDiffMove {
  final String san;
  final int games;
  final double? score;

  const RepertoireDiffMove({
    required this.san,
    required this.games,
    this.score,
  });

  factory RepertoireDiffMove.fromJson(Map<String, dynamic> json) {
    return RepertoireDiffMove(
      san: json['san'] as String,
      games: jsonInt(json['games']),
      score: json['score'] != null ? (json['score'] as num).toDouble() : null,
    );
  }
}

class RepertoireDiffPosition {
  final String fenKey;
  final String fen;
  final String color;
  final int ply;
  final int games;
  final int leftGames;
  final List<RepertoireDiffMove> prepared;
  final List<RepertoireDiffMove> played;

  const RepertoireDiffPosition({
    required this.fenKey,
    required this.fen,
    required this.color,
    required this.ply,
    required this.games,
    required this.leftGames,
    this.prepared = const [],
    this.played = const [],
  });

  factory RepertoireDiffPosition.fromJson(Map<String, dynamic> json) {
    return RepertoireDiffPosition(
      fenKey: json['fenKey'] as String,
      fen: json['fen'] as String,
      color: json['color'] as String,
      ply: jsonInt(json['ply']),
      games: jsonInt(json['games']),
      leftGames: jsonInt(json['leftGames']),
      prepared: (json['prepared'] as List?)
              ?.map(
                  (e) => RepertoireDiffMove.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      played: (json['played'] as List?)
              ?.map(
                  (e) => RepertoireDiffMove.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class RepertoireDiff {
  final String subject;
  final String color;
  final int coveredGames;
  final int followedGames;
  final int leftGames;
  final List<RepertoireDiffPosition> positions;

  const RepertoireDiff({
    required this.subject,
    required this.color,
    required this.coveredGames,
    required this.followedGames,
    required this.leftGames,
    this.positions = const [],
  });

  factory RepertoireDiff.fromJson(Map<String, dynamic> json) {
    return RepertoireDiff(
      subject: json['subject'] as String,
      color: json['color'] as String,
      coveredGames: jsonInt(json['coveredGames']),
      followedGames: jsonInt(json['followedGames']),
      leftGames: jsonInt(json['leftGames']),
      positions: (json['positions'] as List?)
              ?.map((e) =>
                  RepertoireDiffPosition.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class RepertoireSeedPlanPosition {
  final String color;
  final String fenKey;
  final String fen;
  final String san;
  final String uci;
  final int games;
  final double share;
  final int ply;

  const RepertoireSeedPlanPosition({
    required this.color,
    required this.fenKey,
    required this.fen,
    required this.san,
    required this.uci,
    required this.games,
    required this.share,
    required this.ply,
  });

  factory RepertoireSeedPlanPosition.fromJson(Map<String, dynamic> json) {
    return RepertoireSeedPlanPosition(
      color: json['color'] as String,
      fenKey: json['fenKey'] as String,
      fen: json['fen'] as String,
      san: json['san'] as String,
      uci: json['uci'] as String,
      games: jsonInt(json['games']),
      share: (json['share'] as num).toDouble(),
      ply: jsonInt(json['ply']),
    );
  }
}

class RepertoireSeedResult {
  final bool dryRun;
  final int positionsCount;
  final int movesCount;
  final int unplayable;
  final List<RepertoireSeedPlanPosition>? plan;
  final int? added;
  final int? primary;

  const RepertoireSeedResult({
    required this.dryRun,
    required this.positionsCount,
    required this.movesCount,
    required this.unplayable,
    this.plan,
    this.added,
    this.primary,
  });

  factory RepertoireSeedResult.fromJson(Map<String, dynamic> json) {
    return RepertoireSeedResult(
      dryRun: json['dryRun'] as bool,
      positionsCount: jsonInt(json['positions']),
      movesCount: jsonInt(json['moves']),
      unplayable: jsonInt(json['unplayable']),
      plan: (json['plan'] as List?)
          ?.map((e) =>
              RepertoireSeedPlanPosition.fromJson(e as Map<String, dynamic>))
          .toList(),
      added: json['added'] != null ? jsonInt(json['added']) : null,
      primary: json['primary'] != null ? jsonInt(json['primary']) : null,
    );
  }
}
