import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/services/session_service.dart';

/// One move the student decided to play in a position.
class RepertoireMove {
  const RepertoireMove({
    required this.uci,
    required this.san,
    required this.role,
    this.verdict,
    this.source = 'chosen',
  });

  final String uci;
  final String san;

  /// `primary` or `alternate`. One primary per position, held by the database:
  /// three equal answers cannot be drilled, because everything is correct and
  /// nothing is ever learned past having to stop and think.
  final String role;

  /// What the judge said when the move was kept, if it was judged.
  final String? verdict;

  /// `chosen` or `auto`. A generated move is a draft: drawn, walked through,
  /// offered for confirmation, and never asked about by the drill until
  /// somebody says yes to it.
  ///
  /// The archive seed had no such distinction, which is why moves nobody had
  /// chosen ended up indistinguishable from decisions — and why it was deleted.
  final String source;

  bool get isPrimary => role == 'primary';
  bool get isDraft => source == 'auto';

  factory RepertoireMove.fromJson(Map<String, dynamic> json) => RepertoireMove(
        uci: json['uci'] as String? ?? '',
        san: json['san'] as String? ?? '',
        role: json['role'] as String? ?? 'alternate',
        verdict: json['verdict'] as String?,
        source: json['source'] as String? ?? 'chosen',
      );
}

/// A repertoire, which is a *name for a starting position* rather than a box.
///
/// The moves belong to (user, colour), so two repertoires for Black share every
/// position they both reach — which is the whole point: work done deep in the
/// Smith-Morra is already part of a later, broader repertoire against 1.e4 the
/// moment it reaches the same board.
class RepertoireSummary {
  const RepertoireSummary({
    required this.id,
    required this.name,
    required this.color,
    required this.rootFen,
    required this.moves,
    this.rootPath = const [],
  });

  final int id;
  final String name;

  /// 'w' or 'b' — the side this repertoire is built for.
  final String color;
  final String rootFen;

  /// The moves that led to the root, in SAN — how the student got to the
  /// position they said "build from here" about.
  ///
  /// Empty for every repertoire made before this was stored, and for one
  /// started from a pasted position, where there is no line to tell. The
  /// breadcrumb then reads from the root rather than inventing an opening.
  final List<String> rootPath;

  /// How many moves the whole graph for this colour holds. Honest rather than
  /// flattering: two doors into one graph show the same number.
  final int moves;

  bool get forWhite => color == 'w';

  factory RepertoireSummary.fromJson(Map<String, dynamic> json) =>
      RepertoireSummary(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        color: json['color'] as String? ?? 'w',
        rootFen:
            json['rootFen'] as String? ?? json['root_fen'] as String? ?? '',
        rootPath: sanPath(json['rootPath'] ?? json['root_path']),
        moves: (json['moves'] as num?)?.toInt() ?? 0,
      );
}

/// A path of SAN moves, whether the server sent a list or the stored string.
///
/// One reader for both shapes because both are real: `root_path` is stored as
/// one space-separated string and a frontier node's path arrives as a list.
List<String> sanPath(Object? raw) {
  if (raw is List) {
    return raw.whereType<String>().where((san) => san.isNotEmpty).toList();
  }
  if (raw is String && raw.trim().isNotEmpty) {
    return raw.trim().split(RegExp(r'\s+'));
  }
  return const [];
}

/// One position the student still owes an answer to.
class FrontierNode {
  const FrontierNode({
    required this.fen,
    required this.path,
    required this.reach,
    required this.kind,
  });

  final String fen;

  /// The moves from the repertoire's root to here. Joined with the root's own
  /// path for a breadcrumb that reads from move one.
  final List<String> path;

  /// How often a game played down this repertoire actually arrives here — the
  /// product of the opponent's shares along the way. It is the order the
  /// positions come in, and it is why a main line at ply eight is offered
  /// before a third-choice sideline at ply two.
  final double reach;

  /// `undecided` — nothing kept here yet, play something.
  /// `unopened` — decided, but the opponent's replies were never taken, so the
  /// line stops here until they are.
  /// `pruned` — cut on purpose. Not a question at all: it arrives in its own
  /// list so a branch that was refused can be found and put back.
  final String kind;

  int get ply => path.length;
  bool get isUnopened => kind == 'unopened';

  factory FrontierNode.fromJson(Map<String, dynamic> json) => FrontierNode(
        fen: json['fen'] as String? ?? '',
        path: sanPath(json['path']),
        reach: (json['reach'] as num?)?.toDouble() ?? 0,
        kind: json['kind'] as String? ?? 'undecided',
      );
}

/// How far one of the opponent's first answers has been taken.
///
/// A branch is named by the opponent's choice rather than the student's — the
/// Advance, the Exchange, the Two Knights — because in a repertoire the
/// student's own first move is already decided, and what splits the work is
/// what the other side does about it.
class CoverageBranch {
  const CoverageBranch({
    required this.key,
    required this.path,
    required this.fen,
    required this.share,
    this.decided = 0,
    this.open = 0,
    this.undecided = 0,
    this.unopened = 0,
    this.pruned = 0,
    this.draft = 0,
    this.openWithin = 0,
    this.prunedWithin = 0,
    this.maxPly = 0,
  });

  /// The two moves that open the branch, as one string.
  final String key;

  /// Those two moves — the student's, then the opponent's answer.
  final List<String> path;

  /// The position the branch starts from, so it can be built or drilled from
  /// the map without going looking for it.
  final String fen;

  /// How often the opponent goes this way at all. Kept apart from everything
  /// below it: a branch played in one game in twenty is not urgent however
  /// unfinished it is, and one played in half of them is urgent even when it is
  /// nearly done.
  final double share;

  final int decided;
  final int open;
  final int undecided;
  final int unopened;
  final int pruned;

  /// Positions in this branch that are still a generated draft.
  final int draft;

  /// What share of the games that come down *this* branch run into a position
  /// with no answer — measured against the branch, never against the whole
  /// repertoire, where a rare sideline would read as almost finished merely
  /// because few games go there.
  final double openWithin;

  /// And what share runs into a branch that was cut. Never added to the one
  /// above and never subtracted from it: those games are still played.
  final double prunedWithin;

  /// How deep the repertoire goes here, in plies from the repertoire's root.
  final int maxPly;

  /// What is answered: everything that is neither open nor refused.
  double get coveredWithin =>
      (1 - openWithin - prunedWithin).clamp(0, 1).toDouble();

  bool get isFinished => openWithin <= 0 && prunedWithin <= 0 && decided > 0;

  factory CoverageBranch.fromJson(Map<String, dynamic> json) => CoverageBranch(
        key: json['key'] as String? ?? '',
        path: sanPath(json['path']),
        fen: json['fen'] as String? ?? '',
        share: (json['share'] as num?)?.toDouble() ?? 0,
        decided: (json['decided'] as num?)?.toInt() ?? 0,
        open: (json['open'] as num?)?.toInt() ?? 0,
        undecided: (json['undecided'] as num?)?.toInt() ?? 0,
        unopened: (json['unopened'] as num?)?.toInt() ?? 0,
        pruned: (json['pruned'] as num?)?.toInt() ?? 0,
        draft: (json['draft'] as num?)?.toInt() ?? 0,
        openWithin: (json['openWithin'] as num?)?.toDouble() ?? 0,
        prunedWithin: (json['prunedWithin'] as num?)?.toDouble() ?? 0,
        maxPly: (json['maxPly'] as num?)?.toInt() ?? 0,
      );
}

/// The whole shape of a repertoire: where its root is, what is still open, and
/// how much of it is finished.
///
/// Derived on the server from the moves already kept and the books already
/// fetched — so it costs no Lichess request, and it is the same on every
/// device. This is what replaced a queue that lived in one screen's memory and
/// died with it.
class RepertoireFrontier {
  const RepertoireFrontier({
    this.rootPath = const [],
    this.open = const [],
    this.pruned = const [],
    this.branches = const [],
    this.decided = 0,
    this.draft = 0,
    this.unopened = 0,
    this.maxPly = 0,
    this.openReach = 0,
    this.prunedReach = 0,
    this.truncated = false,
  });

  final List<String> rootPath;
  final List<FrontierNode> open;

  /// The branches the student said they are not preparing. Handed back so they
  /// can be put back: a cut nobody can find again is a hole in the repertoire
  /// rather than a decision about it.
  final List<FrontierNode> pruned;

  /// The coverage map: how far each of the opponent's first answers has been
  /// taken, most played first. Out of the same walk — there is no second
  /// request behind it, and no second set of numbers to disagree with these.
  final List<CoverageBranch> branches;

  /// Positions where the student has decided on at least one move.
  final int decided;

  /// Positions whose every move was generated and none confirmed. Counted apart
  /// from [decided] and never added into it: a repertoire that called a
  /// generated spine "prepared" would be telling the seed's lie with a better
  /// source.
  final int draft;

  /// Of the open ones, how many are lines that were decided and then left.
  final int unopened;
  final int maxPly;

  /// The share of games reaching this repertoire that run into a position with
  /// no answer yet. The one number that says how finished it is — and the only
  /// one a wide shallow tree cannot flatter.
  final double openReach;

  /// The share of games that run into a branch the student cut.
  ///
  /// Shown beside [openReach] and never folded into it. Cutting makes
  /// [openReach] fall without a single question having been answered, and this
  /// is the number that says those games are still going to be played.
  final double prunedReach;

  /// True when the walk hit its ceiling. Said out loud rather than quietly
  /// returning a short answer, which is this codebase's oldest bug.
  final bool truncated;

  bool get isEmpty => open.isEmpty && decided == 0;

  /// True while the first move itself is still undecided. The root belongs to
  /// no branch — it is the position every branch leaves from — so a repertoire
  /// stuck here has an empty map and one question, and the map has to say which
  /// of the two kinds of empty it is looking at.
  bool get rootOpen => open.any((node) => node.path.isEmpty);

  /// How deep the repertoire goes, in whole moves.
  int get depthInMoves => (maxPly / 2).ceil();

  factory RepertoireFrontier.fromJson(Map<String, dynamic> json) {
    final root = json['root'] is Map
        ? Map<String, dynamic>.from(json['root'] as Map)
        : const <String, dynamic>{};
    final summary = json['summary'] is Map
        ? Map<String, dynamic>.from(json['summary'] as Map)
        : const <String, dynamic>{};
    return RepertoireFrontier(
      rootPath: sanPath(root['path']),
      open: ((json['open'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => FrontierNode.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      pruned: ((json['pruned'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => FrontierNode.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      branches: ((json['branches'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => CoverageBranch.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      decided: (summary['decided'] as num?)?.toInt() ?? 0,
      draft: (summary['draft'] as num?)?.toInt() ?? 0,
      unopened: (summary['unopened'] as num?)?.toInt() ?? 0,
      maxPly: (summary['maxPly'] as num?)?.toInt() ?? 0,
      openReach: (summary['openReach'] as num?)?.toDouble() ?? 0,
      prunedReach: (summary['prunedReach'] as num?)?.toDouble() ?? 0,
      truncated: summary['truncated'] as bool? ?? false,
    );
  }
}

/// One move in the repertoire's tree, and everything under it.
///
/// One node per ply, unlike the walk the frontier and the drill work in — those
/// think in whole waves, my move and the answer to it, because that is the unit
/// a question is asked in. A drawing is not: a move I chose is a card of its
/// own even when nothing has been taken after it.
class RepertoireTreeMove {
  const RepertoireTreeMove({
    required this.uci,
    required this.san,
    required this.fen,
    required this.mine,
    this.role,
    this.share = 0,
    this.state = '',
    this.children = const [],
  });

  final String uci;
  final String san;

  /// The position this move leads to.
  final String fen;

  /// Whose move it is. Mine carries [role]; theirs carries [share] and [state].
  final bool mine;

  /// `primary` or `alternate`, for the student's own moves.
  final String? role;

  /// How often the opponent plays it.
  final double share;

  /// What the position after it is: `open`, `unopened`, `cut` or `decided`.
  /// This is what makes the tree worth drawing — without it the picture is a
  /// decoration, and with it the holes are visible.
  final String state;

  final List<RepertoireTreeMove> children;

  bool get isPrimary => role == 'primary';

  factory RepertoireTreeMove.fromJson(Map<String, dynamic> json) =>
      RepertoireTreeMove(
        uci: json['uci'] as String? ?? '',
        san: json['san'] as String? ?? '',
        fen: json['fen'] as String? ?? '',
        mine: json['mine'] as bool? ?? false,
        role: json['role'] as String?,
        share: (json['share'] as num?)?.toDouble() ?? 0,
        state: json['state'] as String? ?? '',
        children: ((json['children'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) =>
                RepertoireTreeMove.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// The repertoire as a picture.
class RepertoireTree {
  const RepertoireTree({
    required this.rootFen,
    this.rootPath = const [],
    this.state = '',
    this.children = const [],
    this.maxPly = 16,
    this.truncated = false,
  });

  final String rootFen;
  final List<String> rootPath;

  /// The state of the root position itself, so a repertoire whose first move is
  /// still undecided says so instead of drawing an empty page.
  final String state;

  final List<RepertoireTreeMove> children;

  /// How deep the drawing goes. A seeded repertoire runs to thousands of moves
  /// and nobody reads a picture of all of them.
  final int maxPly;
  final bool truncated;

  bool get isEmpty => children.isEmpty;

  factory RepertoireTree.fromJson(Map<String, dynamic> json) {
    final root = json['root'] is Map
        ? Map<String, dynamic>.from(json['root'] as Map)
        : const <String, dynamic>{};
    return RepertoireTree(
      rootFen: root['fen'] as String? ?? '',
      rootPath: sanPath(root['path']),
      state: json['state'] as String? ?? '',
      children: ((json['children'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => RepertoireTreeMove.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      maxPly: (json['maxPly'] as num?)?.toInt() ?? 16,
      truncated: json['truncated'] as bool? ?? false,
    );
  }
}

/// One question the drill is about to ask.
class DrillItem {
  const DrillItem({
    required this.fen,
    required this.fresh,
    required this.repetitions,
    required this.moves,
    this.path = const [],
  });

  /// The full position, six fields — the repertoire keeps four, and the server
  /// fills the counters back in so any board can load it.
  final String fen;

  /// True the first time a position is drilled at all.
  final bool fresh;
  final int repetitions;

  /// How many moves the student kept here. The moves themselves deliberately do
  /// not travel with the question.
  final int moves;

  /// The moves from the repertoire's root to this position, in SAN. Empty for
  /// a question asked on its own, where nothing knows how the board arose —
  /// which is the thing the line drill exists to fix.
  final List<String> path;

  factory DrillItem.fromJson(Map<String, dynamic> json) => DrillItem(
        fen: json['fen'] as String? ?? '',
        fresh: json['fresh'] as bool? ?? true,
        repetitions: (json['repetitions'] as num?)?.toInt() ?? 0,
        moves: (json['moves'] as num?)?.toInt() ?? 0,
        path: sanPath(json['path']),
      );
}

/// One move of a line being rehearsed.
class LineMove {
  const LineMove({required this.uci, required this.san, required this.mine});

  final String uci;
  final String san;

  /// Whose move it is. The student is asked for their own and the opponent's
  /// are played back at them.
  final bool mine;

  factory LineMove.fromJson(Map<String, dynamic> json) => LineMove(
        uci: json['uci'] as String? ?? '',
        san: json['san'] as String? ?? '',
        mine: json['mine'] as bool? ?? false,
      );
}

/// A line to play through, and the question waiting at the end of it.
///
/// The drill used to put up a bare board four moves into something with no way
/// to tell how it arose. A repertoire is played forwards, and this is the
/// difference between remembering a line and recognising a photograph of it.
///
/// **The rehearsed moves are not graded.** A prefix is played many times a day
/// on the way to whatever is due below it; grading it would push those
/// positions' intervals out on rehearsals nobody had to remember cold. Only
/// [question] is answered, and only it is scheduled.
class DrillLine {
  const DrillLine({
    this.rootPath = const [],
    this.startFen,
    this.startPath = const [],
    this.startKnown = false,
    this.prefix = const [],
    this.question,
    this.reason,
    this.stats = const DrillStats(positions: 0, due: 0, known: 0, fresh: 0),
    this.ahead = false,
    this.truncated = false,
  });

  /// The moves that led to the repertoire's own root, so the line reads from
  /// move one instead of beginning mid-air.
  final List<String> rootPath;

  /// Where the rehearsal begins: the deepest position on the way to the
  /// question that the student already knows cold. Null when nothing is due.
  final String? startFen;
  final List<String> startPath;

  /// True when the replay was shortened because the student has earned it,
  /// false when it simply begins where the repertoire does. Two different
  /// sentences, and only one of them is something they did.
  final bool startKnown;

  /// The moves between the start and the question, in order.
  final List<LineMove> prefix;

  /// The position to be answered. Null when nothing is waiting — and [reason]
  /// says which kind of nothing.
  final DrillItem? question;

  /// `nothing-due` or `nothing-built`. Only one of them is good news.
  final String? reason;

  final DrillStats stats;

  /// True when this line was taken before its position was due. The screen has
  /// to say so, because the answer at the end of it is not written down.
  final bool ahead;

  /// True when the walk hit its ceiling, said out loud rather than quietly
  /// handing back a shorter line.
  final bool truncated;

  bool get hasQuestion => question != null;

  factory DrillLine.fromJson(Map<String, dynamic> json) {
    final root = json['root'] is Map
        ? Map<String, dynamic>.from(json['root'] as Map)
        : const <String, dynamic>{};
    final start = json['start'] is Map
        ? Map<String, dynamic>.from(json['start'] as Map)
        : null;
    final question = json['question'] is Map
        ? Map<String, dynamic>.from(json['question'] as Map)
        : null;
    return DrillLine(
      rootPath: sanPath(root['path']),
      startFen: start?['fen'] as String?,
      startPath: sanPath(start?['path']),
      startKnown: start?['known'] as bool? ?? false,
      prefix: ((json['prefix'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => LineMove.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      question: question == null ? null : DrillItem.fromJson(question),
      reason: json['reason'] as String?,
      stats: DrillStats.fromJson(
          Map<String, dynamic>.from((json['stats'] as Map?) ?? const {})),
      ahead: json['ahead'] as bool? ?? false,
      truncated: json['truncated'] as bool? ?? false,
    );
  }
}

/// How much is waiting, and whether there is anything at all.
class DrillStats {
  const DrillStats({
    required this.positions,
    required this.due,
    required this.known,
    required this.fresh,
    this.nextDueAt,
  });

  final int positions;
  final int due;
  final int known;

  /// Never drilled. "Nothing is due" and "nothing was ever built" are different
  /// empty states, and only one of them is good news.
  final int fresh;

  /// When the soonest position comes back. Null when nothing is scheduled at
  /// all. Without it "nothing is due" reads as "you cannot practise this",
  /// which is how it read the first time a branch of one position — drilled
  /// once, scheduled for tomorrow — was opened.
  final DateTime? nextDueAt;

  factory DrillStats.fromJson(Map<String, dynamic> json) => DrillStats(
        positions: (json['positions'] as num?)?.toInt() ?? 0,
        due: (json['due'] as num?)?.toInt() ?? 0,
        known: (json['known'] as num?)?.toInt() ?? 0,
        fresh: (json['fresh'] as num?)?.toInt() ?? 0,
        nextDueAt: DateTime.tryParse(json['nextDueAt'] as String? ?? ''),
      );
}

/// What the drill made of one answer.
class DrillAnswer {
  const DrillAnswer({
    required this.outcome,
    this.primary,
    this.alternates = const [],
    this.intervalDays,
    this.reply,
    this.replyCovered = true,
    this.practice = false,
  });

  /// `primary`, `alternate`, `unknown` — or `unprepared`, which is not a mark
  /// at all: it means the position was never built, so there was nothing to be
  /// right or wrong about.
  final String outcome;

  final RepertoireMove? primary;
  final List<RepertoireMove> alternates;

  /// When the position comes back, in days. Zero means "in a few minutes", and
  /// null means nothing was written down at all — see [practice].
  final int? intervalDays;

  /// True when the answer was given ahead of the position's schedule. It is
  /// judged and then thrown away: a position run through five times in one
  /// evening must not come back in a month on the strength of it.
  final bool practice;

  /// What the opponent plays next, drawn by how often it is really played —
  /// out of the book stored while the position was built, so a drill costs no
  /// Lichess request.
  final String? reply;

  /// False when the opponent has just played something the student never
  /// prepared for. Not a fault: it is the drill doing the one thing a book
  /// cannot, which is showing them the edge of what they covered.
  final bool replyCovered;

  bool get isPrepared => outcome != 'unprepared';

  static RepertoireMove? _move(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    return RepertoireMove(
      uci: map['uci'] as String? ?? '',
      san: map['san'] as String? ?? '',
      role: 'primary',
    );
  }

  factory DrillAnswer.fromJson(Map<String, dynamic> json) {
    final reply = json['reply'] is Map
        ? Map<String, dynamic>.from(json['reply'] as Map)
        : null;
    return DrillAnswer(
      outcome: json['outcome'] as String? ?? 'unknown',
      primary: _move(json['primary']),
      alternates: ((json['alternates'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => RepertoireMove(
                uci: (e['uci'] as String?) ?? '',
                san: (e['san'] as String?) ?? '',
                role: 'alternate',
              ))
          .toList(),
      intervalDays: (json['intervalDays'] as num?)?.toInt(),
      reply: reply?['uci'] as String?,
      replyCovered: reply?['covered'] as bool? ?? true,
      practice: json['practice'] as bool? ?? false,
    );
  }
}

/// The student's own decisions, on our own server.
///
/// Nothing here talks to Lichess, and that is worth keeping straight: the judge
/// spends the reader's allowance to say what a move is worth, while this only
/// records what they decided about it. A repertoire built last week can be
/// read, edited and drilled with no allowance spent at all.
class RepertoireApiService {
  RepertoireApiService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${SessionService.instance.current.token}',
        'Content-Type': 'application/json',
      };

  Future<List<RepertoireSummary>> list() async {
    final res =
        (await _send(() => _get(Uri.parse('$backendUrl/repertoire')))).res;
    if (res == null) return const [];
    final data = jsonDecode(res.body);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => RepertoireSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Makes a repertoire, or says why it could not.
  Future<({RepertoireSummary? made, String? error})> create({
    required String name,
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
  }) async {
    final sent = await _send(() => _post('$backendUrl/repertoire', {
          'name': name,
          'color': color,
          'rootFen': rootFen,
          'rootPath': rootPath,
        }));
    final res = sent.res;
    if (res == null) return (made: null, error: sent.error);
    return (
      made: RepertoireSummary.fromJson(
          Map<String, dynamic>.from(jsonDecode(res.body) as Map)),
      error: null,
    );
  }

  /// Where the student actually is: what is still open, in the order it is
  /// worth answering.
  ///
  /// Costs nothing at Lichess — it is read from the moves already kept and the
  /// books already fetched. Null when the server could not be reached, which
  /// the caller must tell apart from an empty walk: "nothing is open" and "we
  /// could not find out" are different, and only one of them means finished.
  Future<RepertoireFrontier?> frontier({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int? minRating,
  }) async {
    final uri = Uri.parse('$backendUrl/repertoire/frontier').replace(
      queryParameters: {
        'color': color,
        'rootFen': rootFen,
        if (rootPath.isNotEmpty) 'rootPath': rootPath.join(' '),
        if (minRating != null) 'minRating': '$minRating',
      },
    );
    final res = (await _send(() => _get(uri))).res;
    if (res == null) return null;
    return RepertoireFrontier.fromJson(
        Map<String, dynamic>.from(jsonDecode(res.body) as Map));
  }

  /// How many moves in this colour nobody was ever asked about.
  ///
  /// Until 31.8.2026 a repertoire could also be built out of imported games,
  /// through the same call the build screen uses and into the same graph — so a
  /// move nobody had chosen was indistinguishable from a decision, and the
  /// drill went on to ask for it. This counts what that left behind: moves with
  /// no kept attempt recorded against them.
  ///
  /// A heuristic, and the screen says so before anything is deleted. Null when
  /// the server did not answer.
  Future<({int moves, int positions})?> importedMoves(
      {required String color}) async {
    final uri = Uri.parse('$backendUrl/repertoire/imported')
        .replace(queryParameters: {'color': color});
    final res = (await _send(() => _get(uri))).res;
    if (res == null) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      moves: (data['moves'] as num?)?.toInt() ?? 0,
      positions: (data['positions'] as num?)?.toInt() ?? 0,
    );
  }

  /// Takes them out, and puts a primary back where removing one took it away.
  Future<bool> forgetImportedMoves({required String color}) async {
    final uri = Uri.parse('$backendUrl/repertoire/imported')
        .replace(queryParameters: {'color': color});
    return (await _send(() => _delete(uri))).res != null;
  }

  /// Removes a repertoire — its name and starting point, never its moves.
  ///
  /// The moves belong to (user, colour) and are shared by every repertoire that
  /// reaches them, so deleting them here would empty one door's worth of work
  /// out of every other door.
  Future<bool> deleteRepertoire(int id) async {
    final uri = Uri.parse('$backendUrl/repertoire/$id');
    return (await _send(() => _delete(uri))).res != null;
  }

  /// What the student already plays in this position, primary first.
  Future<List<RepertoireMove>> movesAt({
    required String color,
    required String fen,
  }) async {
    final uri = Uri.parse('$backendUrl/repertoire/node')
        .replace(queryParameters: {'color': color, 'fen': fen});
    final res = (await _send(() => _get(uri))).res;
    if (res == null) return const [];
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return ((data['moves'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => RepertoireMove.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<bool> keepMove({
    required String color,
    required String fen,
    required String uci,
    required String san,
    String? verdict,
  }) async {
    final sent = await _send(() => _post('$backendUrl/repertoire/node/move', {
          'color': color,
          'fen': fen,
          'uci': uci,
          'san': san,
          'verdict': verdict,
        }));
    return sent.res != null;
  }

  Future<bool> makePrimary({
    required String color,
    required String fen,
    required String uci,
  }) async {
    final sent =
        await _send(() => _post('$backendUrl/repertoire/node/primary', {
              'color': color,
              'fen': fen,
              'uci': uci,
            }));
    return sent.res != null;
  }

  Future<bool> removeMove({
    required String color,
    required String fen,
    required String uci,
  }) async {
    final uri = Uri.parse('$backendUrl/repertoire/node/move')
        .replace(queryParameters: {'color': color, 'fen': fen, 'uci': uci});
    return (await _send(() => _delete(uri))).res != null;
  }

  /// "I am not preparing this branch."
  ///
  /// The only control in the build loop that makes the tree smaller, so it is
  /// stored rather than said by closing the screen — which says the same thing
  /// for one session and forgets it. It stops the walk at this position; a move
  /// already kept here stays kept and stays drilled.
  Future<bool> skipNode({required String color, required String fen}) async {
    final sent = await _send(() => _post('$backendUrl/repertoire/node/skip', {
          'color': color,
          'fen': fen,
        }));
    return sent.res != null;
  }

  /// A generated move becomes a decision.
  ///
  /// Without [uci], every draft in the position; with it, one move. Confirming
  /// is an act on purpose: until somebody says "yes, this one", a generated
  /// move is scaffolding, and the drill leaves it alone.
  Future<bool> confirmNode({
    required String color,
    required String fen,
    String? uci,
  }) async {
    final sent =
        await _send(() => _post('$backendUrl/repertoire/node/confirm', {
              'color': color,
              'fen': fen,
              if (uci != null) 'uci': uci,
            }));
    return sent.res != null;
  }

  /// A whole line at once, in one statement — a line half confirmed is a line
  /// the student would have to walk twice.
  Future<bool> confirmLine({
    required String color,
    required List<String> fens,
  }) async {
    if (fens.isEmpty) return false;
    final sent =
        await _send(() => _post('$backendUrl/repertoire/line/confirm', {
              'color': color,
              'fens': fens,
            }));
    return sent.res != null;
  }

  /// "Prepare this opponent move too" — one reply past the coverage cut.
  ///
  /// [fen] is the position the opponent answers *from*, after the student's own
  /// move. The wave covers 80% of what is played and names the remainder; this
  /// is the way through that wall, one move at a time, and the walk follows it
  /// afterwards so the position is still there tomorrow.
  Future<bool> prepareReply({
    required String color,
    required String fen,
    required String uci,
    String? san,
  }) async {
    final sent = await _send(() => _post('$backendUrl/repertoire/node/reply', {
          'color': color,
          'fen': fen,
          'uci': uci,
          'san': san,
        }));
    return sent.res != null;
  }

  /// Takes one back out of the preparation.
  Future<bool> unprepareReply({
    required String color,
    required String fen,
    required String uci,
  }) async {
    final uri = Uri.parse('$backendUrl/repertoire/node/reply')
        .replace(queryParameters: {'color': color, 'fen': fen, 'uci': uci});
    return (await _send(() => _delete(uri))).res != null;
  }

  /// Puts a cut branch back.
  Future<bool> unskipNode({required String color, required String fen}) async {
    final uri = Uri.parse('$backendUrl/repertoire/node/skip')
        .replace(queryParameters: {'color': color, 'fen': fen});
    return (await _send(() => _delete(uri))).res != null;
  }

  /// Writes down what the student reached for, kept or not.
  ///
  /// Deliberately fire-and-forget from the caller's point of view: this is a
  /// note for later, and a screen must not stop working because a note failed
  /// to save. It is still logged, so a systematic failure is visible.
  Future<void> recordAttempt({
    required String color,
    required String fen,
    required String uci,
    String? san,
    String? verdict,
    bool kept = false,
    bool lookedUp = false,
  }) async {
    await _send(() => _post('$backendUrl/repertoire/attempt', {
          'color': color,
          'fen': fen,
          'uci': uci,
          'san': san,
          'verdict': verdict,
          'kept': kept,
          'lookedUp': lookedUp,
        }));
  }

  /// The next position to be asked about, and how much is waiting.
  Future<({DrillItem? item, DrillStats stats})> nextDrill(
      {required String color}) async {
    final uri = Uri.parse('$backendUrl/repertoire/drill/next')
        .replace(queryParameters: {'color': color});
    final res = (await _send(() => _get(uri))).res;
    if (res == null) {
      return (
        item: null,
        stats: const DrillStats(positions: 0, due: 0, known: 0, fresh: 0)
      );
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final raw = data['item'];
    return (
      item: raw is Map
          ? DrillItem.fromJson(Map<String, dynamic>.from(raw))
          : null,
      stats: DrillStats.fromJson(
          Map<String, dynamic>.from((data['stats'] as Map?) ?? const {})),
    );
  }

  /// The repertoire as a tree of single moves, for drawing.
  ///
  /// Same walk and same two tables as everything else that reads what was
  /// built, so it costs no Lichess allowance. Null when the server did not
  /// answer — which the caller must tell apart from a repertoire with nothing
  /// in it.
  Future<RepertoireTree?> repertoireTree({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int? minRating,
    int maxPly = 16,
  }) async {
    final uri = Uri.parse('$backendUrl/repertoire/tree').replace(
      queryParameters: {
        'color': color,
        'rootFen': rootFen,
        if (rootPath.isNotEmpty) 'rootPath': rootPath.join(' '),
        if (minRating != null) 'minRating': '$minRating',
        'maxPly': '$maxPly',
      },
    );
    final res = (await _send(() => _get(uri))).res;
    if (res == null) return null;
    return RepertoireTree.fromJson(
        Map<String, dynamic>.from(jsonDecode(res.body) as Map));
  }

  /// A line to rehearse and the question at the end of it.
  ///
  /// Costs nothing at Lichess, like everything that reads what was built.
  /// [fromFen] narrows it to one branch — the ten positions built yesterday are
  /// what somebody sits down to practise, and the rest of the repertoire is in
  /// the way.
  ///
  /// Null when the server could not be reached, which the caller must tell
  /// apart from a line with no question in it: "we could not find out" and
  /// "nothing is due" are different, and only one of them means rest.
  Future<DrillLine?> drillLine({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int? minRating,
    String? fromFen,
    bool ahead = false,
  }) async {
    final uri = Uri.parse('$backendUrl/repertoire/drill/line').replace(
      queryParameters: {
        'color': color,
        'rootFen': rootFen,
        if (rootPath.isNotEmpty) 'rootPath': rootPath.join(' '),
        if (minRating != null) 'minRating': '$minRating',
        if (fromFen != null) 'fromFen': fromFen,
        if (ahead) 'ahead': '1',
      },
    );
    final res = (await _send(() => _get(uri))).res;
    if (res == null) return null;
    return DrillLine.fromJson(
        Map<String, dynamic>.from(jsonDecode(res.body) as Map));
  }

  /// Asks to be shown the answer. Its own call, so looking is a decision the
  /// schedule gets to know about.
  Future<RepertoireMove?> revealDrill({
    required String color,
    required String fen,
  }) async {
    final uri = Uri.parse('$backendUrl/repertoire/drill/reveal')
        .replace(queryParameters: {'color': color, 'fen': fen});
    final res = (await _send(() => _get(uri))).res;
    if (res == null) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final primary = data['primary'];
    if (primary is! Map) return null;
    return RepertoireMove(
      uci: primary['uci'] as String? ?? '',
      san: primary['san'] as String? ?? '',
      role: 'primary',
    );
  }

  Future<DrillAnswer?> answerDrill({
    required String color,
    required String fen,
    required String uci,
    bool revealed = false,
    int? minRating,
    bool practice = false,
  }) async {
    final res =
        (await _send(() => _post('$backendUrl/repertoire/drill/answer', {
                  'color': color,
                  'fen': fen,
                  'uci': uci,
                  'revealed': revealed,
                  if (minRating != null) 'minRating': minRating,
                  if (practice) 'practice': true,
                })))
            .res;
    if (res == null) return null;
    return DrillAnswer.fromJson(
        Map<String, dynamic>.from(jsonDecode(res.body) as Map));
  }

  Future<http.Response> _get(Uri uri) =>
      _client?.get(uri, headers: _headers) ?? http.get(uri, headers: _headers);

  Future<http.Response> _delete(Uri uri) =>
      _client?.delete(uri, headers: _headers) ??
      http.delete(uri, headers: _headers);

  Future<http.Response> _post(String url, Map<String, dynamic> body) {
    final uri = Uri.parse(url);
    final encoded = jsonEncode(body);
    return _client?.post(uri, headers: _headers, body: encoded) ??
        http.post(uri, headers: _headers, body: encoded);
  }

  /// One place where a failed call becomes a reason, not merely a null.
  ///
  /// The reason is the point. "The name is taken", "the server is not running"
  /// and "that position is not valid" are three different things to whoever is
  /// looking at the screen: one they fix in the field in front of them, one
  /// they fix in a terminal, and one is not their fault at all. One sentence
  /// for all three is the same silent failure this project keeps meeting, one
  /// layer up — and it was on screen the first time somebody used this.
  Future<({http.Response? res, String? error})> _send(
      Future<http.Response> Function() call) async {
    try {
      final res = await call().timeout(const Duration(seconds: 12));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return (res: res, error: null);
      }
      AppLogger.log('[Repertoar] ⚠️ ${res.statusCode}: ${res.body}');
      return (res: null, error: _errorOf(res));
    } catch (e) {
      AppLogger.log('[Repertoar] ❌ $e');
      return (
        res: null,
        error: 'Server nije dostupan — proverite da li backend radi.',
      );
    }
  }

  /// What the server said, in its own words where it had any.
  String _errorOf(http.Response res) {
    if (res.statusCode == 409) return 'Već imate repertoar sa tim imenom.';
    if (res.statusCode == 401 || res.statusCode == 403) {
      return 'Niste prijavljeni ili je prijava istekla.';
    }
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } catch (_) {
      // A body that is not JSON says nothing about why, and inventing a reason
      // here would be worse than admitting the status code.
    }
    if (res.statusCode >= 500) {
      return 'Greška na serveru (${res.statusCode}). Ako je baza tek dobila '
          'nove tabele, backend treba restartovati.';
    }
    return 'Server je odgovorio ${res.statusCode}.';
  }

  @visibleForTesting
  static RepertoireApiService withClient(http.Client client) =>
      RepertoireApiService(client: client);
}
