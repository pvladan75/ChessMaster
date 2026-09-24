import 'package:chess_app/core/services/mistake_rule.dart' show MistakeReason;
import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';

/// The verdict of one move judged by the device's engine and the one mistake
/// rule (`docs/PLAN-MOJE-PARTIJE.md` §9.1–§9.3, rule 12: judged once, on the
/// device, and handed to the server as given).
enum HabitVerdict { mistake, holds }

HabitVerdict _habitVerdictOf(String? raw) =>
    raw == 'mistake' ? HabitVerdict.mistake : HabitVerdict.holds;

MistakeReason? _mistakeReasonOf(String? raw) {
  for (final reason in MistakeReason.values) {
    if (reason.name == raw) return reason;
  }
  return null;
}

/// What the device's engine said about one habit move — the `J` shape of
/// `GET /games/openings/nodes` and `GET /games/openings/leaks`. Absent (never
/// judged) is `null` on the move that carries this, never a default that
/// would read as „holds".
class HabitJudgement {
  const HabitJudgement({
    required this.verdict,
    this.reason,
    required this.lostChances,
    required this.bestUci,
    this.bestSan,
    required this.bestLine,
    required this.moveLine,
    this.bookGames,
    required this.depth,
    required this.engine,
  });

  final HabitVerdict verdict;
  final MistakeReason? reason;
  final double lostChances;
  final String bestUci;
  final String? bestSan;
  final List<String> bestLine;
  final List<String> moveLine;
  final int? bookGames;
  final int depth;
  final String engine;

  bool get isMistake => verdict == HabitVerdict.mistake;

  factory HabitJudgement.fromJson(Map<String, dynamic> json) {
    return HabitJudgement(
      verdict: _habitVerdictOf(json['verdict'] as String?),
      reason: _mistakeReasonOf(json['reason'] as String?),
      lostChances: (json['lostChances'] as num).toDouble(),
      bestUci: json['bestUci'] as String,
      bestSan: json['bestSan'] as String?,
      bestLine: ((json['bestLine'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      moveLine: ((json['moveLine'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      bookGames: (json['bookGames'] as num?)?.toInt(),
      depth: (json['depth'] as num).toInt(),
      engine: json['engine'] as String,
    );
  }
}

/// The book's answer over one request — `services/openingBook.js`, attached
/// to `GET /games/openings/nodes`. A book that cannot answer says so; it never
/// reads as zero master games, which would make theory look like a mistake.
class OpeningBookAvailability {
  const OpeningBookAvailability({required this.available, this.reason});

  final bool available;
  final String? reason;

  factory OpeningBookAvailability.fromJson(Map<String, dynamic> json) {
    return OpeningBookAvailability(
      available: json['available'] as bool? ?? false,
      reason: json['reason'] as String?,
    );
  }
}

/// `GET /games/openings/nodes` — every frequent node of the report's filters,
/// whatever the score, for the device to judge (`docs/PLAN-MOJE-PARTIJE.md`
/// §9.2–§9.3). Shares [LeakReportNode] and [LeakReportMove] with the leak
/// report: one shape, read by both (rule 12).
class OpeningNodesReport {
  const OpeningNodesReport({
    required this.subject,
    this.color,
    required this.fromPly,
    required this.toPly,
    required this.minGames,
    required this.book,
    required this.nodes,
  });

  final String subject;
  final String? color;
  final int fromPly;
  final int toPly;
  final int minGames;
  final OpeningBookAvailability book;
  final List<LeakReportNode> nodes;

  factory OpeningNodesReport.fromJson(Map<String, dynamic> json) {
    final window = Map<String, dynamic>.from(json['window'] as Map? ?? {});
    return OpeningNodesReport(
      subject: json['subject'] as String,
      color: json['color'] as String?,
      fromPly: (window['fromPly'] as num?)?.toInt() ?? 0,
      toPly: (window['toPly'] as num?)?.toInt() ?? 0,
      minGames: (json['minGames'] as num?)?.toInt() ?? 0,
      book: OpeningBookAvailability.fromJson(
          Map<String, dynamic>.from(json['book'] as Map? ?? {})),
      nodes: ((json['nodes'] as List?) ?? [])
          .map((e) => LeakReportNode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// One frequent node's habit that the engine called a mistake, whatever the
/// node's score — the list the score alone does not show
/// (`docs/PLAN-MOJE-PARTIJE.md` §9.2, „Losing habits your score doesn't
/// show").
class LosingHabit {
  const LosingHabit({
    required this.fenKey,
    required this.fen,
    required this.ply,
    required this.nodeGames,
    required this.nodeScore,
    required this.san,
    this.uci,
    required this.games,
    required this.score,
    required this.share,
    required this.habit,
    this.judgement,
    required this.cost,
  });

  final String fenKey;
  final String fen;
  final int ply;
  final int nodeGames;
  final double nodeScore;
  final String san;
  final String? uci;
  final int games;
  final double score;
  final double share;
  final bool habit;
  final HabitJudgement? judgement;
  final double cost;

  factory LosingHabit.fromJson(Map<String, dynamic> json) {
    final judgementJson = json['judgement'] as Map?;
    return LosingHabit(
      fenKey: json['fenKey'] as String,
      fen: json['fen'] as String,
      ply: (json['ply'] as num).toInt(),
      nodeGames: (json['nodeGames'] as num).toInt(),
      nodeScore: (json['nodeScore'] as num).toDouble(),
      san: json['san'] as String,
      uci: json['uci'] as String?,
      games: (json['games'] as num).toInt(),
      score: (json['score'] as num).toDouble(),
      share: (json['share'] as num).toDouble(),
      habit: json['habit'] as bool? ?? false,
      judgement: judgementJson != null
          ? HabitJudgement.fromJson(Map<String, dynamic>.from(judgementJson))
          : null,
      cost: (json['cost'] as num).toDouble(),
    );
  }
}

/// The tally `POST /games/openings/judgements` answers with — every item
/// accounted for, never a silent drop (`services/openingJudgements.js`).
class JudgementTally {
  const JudgementTally({
    required this.read,
    required this.stored,
    required this.replaced,
    required this.keptDeeper,
    required this.rejected,
    this.rejectedByReason = const {},
  });

  final int read;
  final int stored;
  final int replaced;
  final int keptDeeper;
  final int rejected;
  final Map<String, int> rejectedByReason;

  factory JudgementTally.fromJson(Map<String, dynamic> json) {
    final byReason =
        Map<String, dynamic>.from(json['rejected_by_reason'] as Map? ?? {});
    return JudgementTally(
      read: (json['read'] as num?)?.toInt() ?? 0,
      stored: (json['stored'] as num?)?.toInt() ?? 0,
      replaced: (json['replaced'] as num?)?.toInt() ?? 0,
      keptDeeper: (json['kept_deeper'] as num?)?.toInt() ?? 0,
      rejected: (json['rejected'] as num?)?.toInt() ?? 0,
      rejectedByReason: byReason.map((k, v) => MapEntry(k, (v as num).toInt())),
    );
  }
}

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
    this.uci,
    this.habit = false,
    this.bookGames,
    this.judgement,
  });

  final String san;
  final int games;
  final double score;
  final double share;

  /// Absent on the old report shape (before §9.2); present wherever the
  /// server has attached it.
  final String? uci;

  /// Played at least 3 times and in at least 10% of the node's games — the
  /// one definition, decided on the server (`services/openingLeaks.js`), read
  /// here rather than repeated (rule 12).
  final bool habit;

  /// Master games playing this move here, from `services/openingBook.js`.
  /// `null` when the book was not asked or could not answer — never a bare 0,
  /// which would read as „no master plays this".
  final int? bookGames;

  /// What the device's engine said about this move, or `null` when it has
  /// never been judged. Never defaulted to „holds".
  final HabitJudgement? judgement;

  factory LeakReportMove.fromJson(Map<String, dynamic> json) {
    final judgementJson = json['judgement'] as Map?;
    return LeakReportMove(
      san: json['san'] as String,
      games: (json['games'] as num).toInt(),
      score: (json['score'] as num).toDouble(),
      share: (json['share'] as num).toDouble(),
      uci: json['uci'] as String?,
      habit: json['habit'] as bool? ?? false,
      bookGames: (json['bookGames'] as num?)?.toInt(),
      judgement: judgementJson != null
          ? HabitJudgement.fromJson(Map<String, dynamic>.from(judgementJson))
          : null,
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
    this.losingHabits = const [],
  });

  final String subject;
  final String? color;
  final int games;
  final int gamesWithoutNodes;
  final List<LeakReportNode> nodes;
  final LeakReportJudge judge;

  /// Every frequent node with a habit the engine called a mistake, whatever
  /// its score — `docs/PLAN-MOJE-PARTIJE.md` §9.2. Absent on a report never
  /// judged; `const []` reads the same as „none found" on purpose, since the
  /// screen tells the two apart by whether judging was ever asked for.
  final List<LosingHabit> losingHabits;

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
      losingHabits: ((json['losingHabits'] as List?) ?? [])
          .map((e) => LosingHabit.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
