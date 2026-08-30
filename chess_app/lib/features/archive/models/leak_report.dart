import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';

class LeakJudgement {
  const LeakJudgement({
    required this.verdict,
    this.lossCp,
    this.better,
  });

  final OpeningVerdict verdict;
  final int? lossCp;
  final String? better;

  factory LeakJudgement.fromJson(Map<String, dynamic> json) {
    final eval = json['eval'] is Map
        ? Map<String, dynamic>.from(json['eval'] as Map)
        : const <String, dynamic>{};

    OpeningVerdict verdictOf(String? raw) {
      switch (raw) {
        case 'theory':
          return OpeningVerdict.theory;
        case 'playable':
          return OpeningVerdict.playable;
        case 'mistake':
          return OpeningVerdict.mistake;
        default:
          return OpeningVerdict.unknown;
      }
    }

    return LeakJudgement(
      verdict: verdictOf(json['verdict'] as String?),
      lossCp: (eval['lossCp'] as num?)?.toInt(),
      better: eval['better'] as String?,
    );
  }
}

class LeakReportMove {
  const LeakReportMove({
    required this.san,
    required this.games,
    required this.score,
    required this.share,
  });

  final String san;
  final int games;
  final double score;
  final double share;

  factory LeakReportMove.fromJson(Map<String, dynamic> json) {
    return LeakReportMove(
      san: json['san'] as String,
      games: (json['games'] as num).toInt(),
      score: (json['score'] as num).toDouble(),
      share: (json['share'] as num).toDouble(),
    );
  }
}

class LeakReportNode {
  const LeakReportNode({
    required this.fenKey,
    required this.fen,
    required this.ply,
    required this.games,
    required this.score,
    required this.moves,
    this.judgement,
  });

  final String fenKey;
  final String fen;
  final int ply;
  final int games;
  final double score;
  final List<LeakReportMove> moves;
  final LeakJudgement? judgement;

  factory LeakReportNode.fromJson(Map<String, dynamic> json) {
    final judgementJson = json['judgement'] as Map?;
    return LeakReportNode(
      fenKey: json['fenKey'] as String,
      fen: json['fen'] as String,
      ply: (json['ply'] as num).toInt(),
      games: (json['games'] as num).toInt(),
      score: (json['score'] as num).toDouble(),
      moves: ((json['moves'] as List?) ?? [])
          .map((e) => LeakReportMove.fromJson(e as Map<String, dynamic>))
          .toList(),
      judgement: judgementJson != null
          ? LeakJudgement.fromJson(Map<String, dynamic>.from(judgementJson))
          : null,
    );
  }
}

class LeakReportJudge {
  const LeakReportJudge({
    required this.requested,
    required this.judged,
    required this.nodes,
    this.reason,
  });

  final bool requested;
  final int judged;
  final int nodes;
  final String? reason;

  factory LeakReportJudge.fromJson(Map<String, dynamic> json) {
    return LeakReportJudge(
      requested: json['requested'] as bool? ?? false,
      judged: (json['judged'] as num?)?.toInt() ?? 0,
      nodes: (json['nodes'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String?,
    );
  }
}

class LeakReport {
  const LeakReport({
    required this.subject,
    this.color,
    required this.games,
    required this.gamesWithoutNodes,
    required this.nodes,
    required this.judge,
  });

  final String subject;
  final String? color;
  final int games;
  final int gamesWithoutNodes;
  final List<LeakReportNode> nodes;
  final LeakReportJudge judge;

  factory LeakReport.fromJson(Map<String, dynamic> json) {
    return LeakReport(
      subject: json['subject'] as String,
      color: json['color'] as String?,
      games: (json['games'] as num).toInt(),
      gamesWithoutNodes: (json['gamesWithoutNodes'] as num).toInt(),
      nodes: ((json['nodes'] as List?) ?? [])
          .map((e) => LeakReportNode.fromJson(e as Map<String, dynamic>))
          .toList(),
      judge: LeakReportJudge.fromJson(
          Map<String, dynamic>.from(json['judge'] as Map? ?? {})),
    );
  }
}
