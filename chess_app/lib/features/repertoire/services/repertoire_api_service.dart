import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/services/app_settings_service.dart';
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
    this.viaUci,
    this.viaSan,
    this.breadth = 'standard',
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

  /// The move this repertoire goes through at its root — its **gate**.
  ///
  /// Two repertoires can start from the same position and mean two different
  /// openings: after 1.e4 e5 2.Nf3 Nc6 3.Bc4 Bc5 one plays 4.b4 and the other
  /// 4.0-0. The moves belong to (user, colour) and stay in one graph, because a
  /// position reached both ways is one position with one answer. What the gate
  /// splits is the **view**: the walk follows only this move out of the root,
  /// so the tree, the queue, the map and the drill are about one opening.
  ///
  /// Null for every repertoire made before this existed, and for one whose root
  /// holds a single first move — where there is nothing to tell apart.
  final String? viaUci;

  /// The same move written the way it is read — "O-O", not "e1g1". Worked out
  /// by the server, which has the board.
  final String? viaSan;

  /// How many moves the whole graph for this colour holds. Honest rather than
  /// flattering: two doors into one graph show the same number.
  final int moves;

  /// How wide this repertoire's walk reads: `main`, `standard` or `broad`.
  ///
  /// The server has sent it since the column existed; this model dropped it,
  /// which is why the setting was inert — the screens had nothing to pass on,
  /// so every read fell back to the server's `standard`.
  final String breadth;

  bool get forWhite => color == 'w';

  factory RepertoireSummary.fromJson(Map<String, dynamic> json) =>
      RepertoireSummary(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        color: json['color'] as String? ?? 'w',
        rootFen:
            json['rootFen'] as String? ?? json['root_fen'] as String? ?? '',
        rootPath: sanPath(json['rootPath'] ?? json['root_path']),
        viaUci: json['viaUci'] as String? ?? json['via_uci'] as String?,
        viaSan: json['viaSan'] as String?,
        moves: (json['moves'] as num?)?.toInt() ?? 0,
        breadth: json['breadth'] as String? ?? 'standard',
      );
}

/// A position as the store keys it: the first four FEN fields, no move
/// counters.
///
/// The same rule the server keeps, and it has to be the same one — the same
/// board reached at move 12 and at move 16 is one position to a repertoire, and
/// a client that keyed on the whole FEN would look up notes that are there and
/// find nothing.
String fenKeyOf(String fen) {
  final parts = fen.trim().split(RegExp(r'\s+'));
  return parts.length >= 4 ? parts.sublist(0, 4).join(' ') : fen.trim();
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

/// What one run of the auto-spine did.
class SpineResult {
  const SpineResult({
    this.written = 0,
    this.followed = 0,
    this.path = const [],
    this.reason = 'depth',
    this.games = 0,
    this.minGames = 100,
  });

  /// Moves the spine wrote, all of them drafts.
  final int written;

  /// Positions it walked through because they already had a move — a decision
  /// or a draft from an earlier run. Never overwritten.
  final int followed;

  final List<String> path;

  /// Why it stopped: `depth` when it ran the whole way, `thin` when the line
  /// ran out of games, `illegal` when a stored move would not replay.
  final String reason;

  /// How many games the move that stopped it had, when it was `thin`.
  final int games;
  final int minGames;

  bool get ranTheWholeWay => reason == 'depth';

  factory SpineResult.fromJson(Map<String, dynamic> json) {
    final stopped = json['stopped'] is Map
        ? Map<String, dynamic>.from(json['stopped'] as Map)
        : const <String, dynamic>{};
    return SpineResult(
      written: (json['written'] as num?)?.toInt() ?? 0,
      followed: (json['followed'] as num?)?.toInt() ?? 0,
      path: sanPath(json['path']),
      reason: stopped['reason'] as String? ?? 'depth',
      games: (stopped['games'] as num?)?.toInt() ?? 0,
      minGames: (json['minGames'] as num?)?.toInt() ?? 100,
    );
  }
}

/// One of the opponent's moves, as the stored book has it.
class StoredReply {
  const StoredReply({
    required this.uci,
    required this.san,
    required this.games,
    required this.share,
    this.covered = false,
    this.prepared = false,
  });

  final String uci;
  final String san;
  final int games;
  final double share;

  /// True for the moves the 80% rule prepared for.
  final bool covered;

  /// True for the ones this student added by hand from past that cut.
  final bool prepared;

  bool get isInPreparation => covered || prepared;

  factory StoredReply.fromJson(Map<String, dynamic> json) => StoredReply(
        uci: json['uci'] as String? ?? '',
        san: json['san'] as String? ?? '',
        games: (json['games'] as num?)?.toInt() ?? 0,
        share: (json['share'] as num?)?.toDouble() ?? 0,
        covered: json['covered'] as bool? ?? false,
        prepared: json['prepared'] as bool? ?? false,
      );
}

/// What the opponent plays in a position, out of what was already fetched.
///
/// **No Lichess request behind this.** `opening_replies` holds what anybody's
/// build session paid for, so a panel that follows the board is free — and only
/// a position nobody has ever opened costs anything, which is then an offer
/// rather than something that happens on its own.
class StoredBook {
  const StoredBook({
    required this.fen,
    this.opened = false,
    this.replies = const [],
  });

  final String fen;

  /// False when nobody has ever looked here. Told apart from an empty list on
  /// purpose: "nobody has looked" and "the opponent plays nothing" are
  /// different sentences, and only one of them is an invitation.
  final bool opened;

  final List<StoredReply> replies;

  factory StoredBook.fromJson(Map<String, dynamic> json) => StoredBook(
        fen: json['fen'] as String? ?? '',
        opened: json['opened'] as bool? ?? false,
        replies: ((json['replies'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => StoredReply.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// What the *student* wrote about one position, in their own words.
///
/// The one thing in a repertoire nothing can recompute. An evaluation comes
/// back at any depth, a book row comes back from Lichess, a move comes back by
/// playing it again; a sentence somebody typed at a board comes back only if it
/// was kept. That is why it has its own table on the server, its own lifetime,
/// and why deleting moves leaves it alone unless it is asked for by name.
///
/// Keyed by position like everything else here, so a plan written deep in one
/// line is on screen the moment another line transposes into that board.
class RepertoireComment {
  const RepertoireComment({
    required this.fenKey,
    required this.body,
    this.updatedAt,
  });

  final String fenKey;
  final String body;
  final DateTime? updatedAt;

  factory RepertoireComment.fromJson(Map<String, dynamic> json) =>
      RepertoireComment(
        fenKey: json['fenKey'] as String? ?? '',
        body: json['body'] as String? ?? '',
        updatedAt: json['updatedAt'] is String
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
      );
}

/// What deleting a repertoire would take with it.
///
/// Read before the button does anything. What is counted is what *only* this
/// repertoire reaches — reachable from its root minus everything reachable from
/// the other roots of the same colour — and [shared] is what stays behind
/// because another repertoire is still standing on it.
///
/// [positions] counts the ones that actually hold moves, because that is what
/// the sentence on screen is made of: "18 moves in 12 positions". The sweep
/// itself covers every stranded position, some of which hold nothing.
class RepertoireRemoval {
  const RepertoireRemoval({
    required this.name,
    required this.color,
    required this.positions,
    required this.moves,
    required this.decisions,
    required this.drafts,
    required this.comments,
    required this.shared,
  });

  final String name;
  final String color;
  final int positions;
  final int moves;

  /// Moves the student chose themselves, as against the ones a generator drew.
  /// The number worth reading twice before pressing anything.
  final int decisions;
  final int drafts;
  final int comments;
  final int shared;

  factory RepertoireRemoval.fromJson(Map<String, dynamic> json) =>
      RepertoireRemoval(
        name: json['name'] as String? ?? '',
        color: json['color'] as String? ?? 'w',
        positions: (json['positions'] as num?)?.toInt() ?? 0,
        moves: (json['moves'] as num?)?.toInt() ?? 0,
        decisions: (json['decisions'] as num?)?.toInt() ?? 0,
        drafts: (json['drafts'] as num?)?.toInt() ?? 0,
        comments: (json['comments'] as num?)?.toInt() ?? 0,
        shared: (json['shared'] as num?)?.toInt() ?? 0,
      );
}

/// Everything stored for one side, counted.
///
/// The answer to the question that had none: delete every repertoire of a
/// colour and the moves stay — they belong to the colour, not to the name — and
/// with no root left there is no walk that can even find them.
class RepertoireColorStats {
  const RepertoireColorStats({
    required this.color,
    required this.repertoires,
    required this.positions,
    required this.moves,
    required this.decisions,
    required this.drafts,
    required this.comments,
  });

  final String color;
  final int repertoires;
  final int positions;
  final int moves;
  final int decisions;
  final int drafts;
  final int comments;

  bool get isEmpty => moves == 0 && comments == 0;

  factory RepertoireColorStats.fromJson(Map<String, dynamic> json) =>
      RepertoireColorStats(
        color: json['color'] as String? ?? 'w',
        repertoires: (json['repertoires'] as num?)?.toInt() ?? 0,
        positions: (json['positions'] as num?)?.toInt() ?? 0,
        moves: (json['moves'] as num?)?.toInt() ?? 0,
        decisions: (json['decisions'] as num?)?.toInt() ?? 0,
        drafts: (json['drafts'] as num?)?.toInt() ?? 0,
        comments: (json['comments'] as num?)?.toInt() ?? 0,
      );
}

/// What the engine said about one position in this repertoire.
///
/// Information, never a verdict. The build screen already has a judge — the
/// opening judge, which answers "is this move sound, judged by the games real
/// people played", and for a repertoire that is the better question. A second
/// opinion from a different notion of "good" on the same card is how a screen
/// starts contradicting itself in front of a child. What the number is for is
/// [RepertoireDisagreement]: one list, gone through deliberately.
class RepertoireNote {
  const RepertoireNote({
    required this.fenKey,
    required this.evalCp,
    this.mateIn,
    this.evalDepth = 0,
    this.bestUci,
    this.bestLineSan,
    this.updatedAt,
  });

  final String fenKey;

  /// White-relative centipawns. A mate is collapsed into it as well, so
  /// anything that sorts or subtracts has one number to use.
  final int evalCp;

  /// Signed moves to mate, positive when White mates. Null for an ordinary
  /// evaluation, and kept apart from [evalCp] because a forced mate written as
  /// a large number of pawns reads as an evaluation, which it is not.
  final int? mateIn;

  /// The depth it was found at. On screen beside the number, always: an eval
  /// without its depth is a number that ages invisibly.
  final int evalDepth;

  final String? bestUci;
  final String? bestLineSan;
  final DateTime? updatedAt;

  /// The evaluation as it is read: `+0.35`, `-1.20`, `M4`, `-M4`.
  String get text {
    final mate = mateIn;
    if (mate != null) return mate < 0 ? '-M${-mate}' : 'M$mate';
    final pawns = evalCp / 100;
    return pawns > 0
        ? '+${pawns.toStringAsFixed(2)}'
        : pawns.toStringAsFixed(2);
  }

  factory RepertoireNote.fromJson(Map<String, dynamic> json) => RepertoireNote(
        fenKey: json['fenKey'] as String? ?? '',
        evalCp: (json['evalCp'] as num?)?.toInt() ?? 0,
        mateIn: (json['mateIn'] as num?)?.toInt(),
        evalDepth: (json['evalDepth'] as num?)?.toInt() ?? 0,
        bestUci: json['bestUci'] as String?,
        bestLineSan: json['bestLineSan'] as String?,
        updatedAt: json['updatedAt'] is String
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
      );
}

/// One position where the engine plays something other than what was chosen.
///
/// The whole point of storing evals: no flag on any card, one list sorted by
/// how much the disagreement costs. A position the engine was never asked about
/// is not in the list at all — "not asked" and "agrees" are different answers.
class RepertoireDisagreement {
  const RepertoireDisagreement({
    required this.fen,
    required this.path,
    required this.mineUci,
    required this.mineSan,
    this.mineSource = 'chosen',
    required this.engineUci,
    this.engineSan,
    this.engineLine,
    this.evalDepth = 0,
    this.loss,
  });

  final String fen;

  /// SAN from the repertoire's root down to this position.
  final List<String> path;

  final String mineUci;
  final String mineSan;

  /// `chosen` or `auto`. A draft is exactly what somebody wants a second look
  /// at before confirming it, so it is in the list and says so.
  final String mineSource;

  final String engineUci;
  final String? engineSan;
  final String? engineLine;

  final int evalDepth;

  /// How much the engine thinks the move gives up, in centipawns from the
  /// student's own side. Null when the position after their move has never been
  /// evaluated — and null is not zero, which would read as "no difference".
  final int? loss;

  bool get isDraft => mineSource == 'auto';

  /// The loss in pawns, as a reader reads it.
  String get lossText {
    final value = loss;
    if (value == null) return '?';
    return (value / 100).toStringAsFixed(2);
  }

  factory RepertoireDisagreement.fromJson(Map<String, dynamic> json) {
    final mine = json['mine'] is Map
        ? Map<String, dynamic>.from(json['mine'] as Map)
        : const <String, dynamic>{};
    final engine = json['engine'] is Map
        ? Map<String, dynamic>.from(json['engine'] as Map)
        : const <String, dynamic>{};
    return RepertoireDisagreement(
      fen: json['fen'] as String? ?? '',
      path: sanPath(json['path']),
      mineUci: mine['uci'] as String? ?? '',
      mineSan: mine['san'] as String? ?? '',
      mineSource: mine['source'] as String? ?? 'chosen',
      engineUci: engine['uci'] as String? ?? '',
      engineSan: engine['san'] as String?,
      engineLine: engine['line'] as String?,
      evalDepth: (json['evalDepth'] as num?)?.toInt() ?? 0,
      loss: (json['loss'] as num?)?.toInt(),
    );
  }
}

/// The review list, and the two numbers that say what a short one means.
class DisagreementReport {
  const DisagreementReport({
    this.positions = 0,
    this.evaluated = 0,
    this.rows = const [],
    this.truncated = false,
  });

  /// Positions in this branch the student has a move in.
  final int positions;

  /// How many of those the engine has ever been asked about. Without it, a
  /// short list reads as "the engine agrees with almost everything", when it
  /// may only mean nobody has run it yet.
  final int evaluated;

  final List<RepertoireDisagreement> rows;
  final bool truncated;

  factory DisagreementReport.fromJson(Map<String, dynamic> json) =>
      DisagreementReport(
        positions: (json['positions'] as num?)?.toInt() ?? 0,
        evaluated: (json['evaluated'] as num?)?.toInt() ?? 0,
        rows: ((json['disagreements'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) =>
                RepertoireDisagreement.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        truncated: json['truncated'] as bool? ?? false,
      );
}

class DrillBranchRepertoire {
  const DrillBranchRepertoire({required this.id, required this.name});
  final int id;
  final String name;
  factory DrillBranchRepertoire.fromJson(Map<String, dynamic> json) =>
      DrillBranchRepertoire(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
      );
}

class DrillBranchRoot {
  const DrillBranchRoot({required this.fen, this.path = const []});
  final String fen;
  final List<String> path;
  factory DrillBranchRoot.fromJson(Map<String, dynamic> json) =>
      DrillBranchRoot(
        fen: json['fen'] as String? ?? '',
        path: sanPath(json['path']),
      );
}

/// One of the opponent's first answers, and how much of it is waiting.
///
/// The unit a practice session is chosen by. A repertoire is a handful of
/// branches — what they play against your first move — and the ten positions
/// that hang together are the ones worth meeting in a row; one queue over the
/// whole colour is right for a schedule and wrong for sitting down.
class DrillBranch {
  const DrillBranch({
    required this.id,
    required this.key,
    required this.fen,
    required this.san,
    this.repertoire,
    this.root,
    this.gateUci,
    this.breadth = 'standard',
    this.path = const [],
    this.share = 0,
    this.positions = 0,
    this.due = 0,
    this.known = 0,
    this.dueKeys = const [],
  });

  /// The repertoire id and branch key joined. Key list rows by this.
  final String id;

  /// The two moves that open it, in UCI.
  final String key;

  /// The repertoire this branch belongs to. Null if fetched by root.
  final DrillBranchRepertoire? repertoire;

  /// The root of the repertoire this branch came from.
  final DrillBranchRoot? root;

  final String? gateUci;
  final String breadth;

  /// Where a run through this branch begins: after your move and their reply.
  final String fen;

  /// The two moves that open it — "e4 c5" — which is how the coverage map
  /// names branches too.
  final String san;

  final List<String> path;
  final double share;

  final int positions;
  final int due;
  final int known;

  /// The positions in it that are actually due. A run through the branch
  /// grades those and leaves the rest alone: replaying a whole branch with
  /// every position graded would push the schedule out on the strength of
  /// moves nobody had to remember cold.
  final List<String> dueKeys;

  factory DrillBranch.fromJson(Map<String, dynamic> json) {
    final rep = json['repertoire'];
    final rootMap = json['root'];
    return DrillBranch(
      id: json['id'] as String? ?? '',
      key: json['key'] as String? ?? '',
      repertoire: rep is Map
          ? DrillBranchRepertoire.fromJson(Map<String, dynamic>.from(rep))
          : null,
      root: rootMap is Map
          ? DrillBranchRoot.fromJson(Map<String, dynamic>.from(rootMap))
          : null,
      gateUci: json['gateUci'] as String?,
      breadth: json['breadth'] as String? ?? 'standard',
      fen: json['fen'] as String? ?? '',
      san: json['san'] as String? ?? '',
      path: sanPath(json['path']),
      share: (json['share'] as num?)?.toDouble() ?? 0,
      positions: (json['positions'] as num?)?.toInt() ?? 0,
      due: (json['due'] as num?)?.toInt() ?? 0,
      known: (json['known'] as num?)?.toInt() ?? 0,
      dueKeys:
          ((json['dueKeys'] as List?) ?? const []).whereType<String>().toList(),
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
/// One of the student's other decisions in the same position.
class LineAlternative {
  const LineAlternative({required this.uci, required this.san});

  final String uci;
  final String san;

  factory LineAlternative.fromJson(Map<String, dynamic> json) =>
      LineAlternative(
        uci: json['uci'] as String? ?? '',
        san: json['san'] as String? ?? '',
      );
}

class LineMove {
  const LineMove({
    required this.uci,
    required this.san,
    required this.mine,
    this.role = 'primary',
    this.alts = const [],
  });

  final String uci;
  final String san;

  /// Whose move it is. The student is asked for their own and the opponent's
  /// are played back at them.
  final bool mine;

  /// `primary` or `alternate` — which of the student's own decisions this move
  /// is. A line runs through whichever move leads to the question, so a
  /// rehearsal can perfectly well be asking for an alternate, and asking for
  /// one without saying so is asking somebody to guess.
  final String role;

  /// The student's other moves in this position, empty when they only kept
  /// one. It is what tells a move of their own apart from a move that is
  /// simply not in the repertoire — the two must not read the same.
  final List<LineAlternative> alts;

  /// True when this position holds more than one of the student's decisions.
  bool get isFork => mine && alts.isNotEmpty;

  factory LineMove.fromJson(Map<String, dynamic> json) => LineMove(
        uci: json['uci'] as String? ?? '',
        san: json['san'] as String? ?? '',
        mine: json['mine'] as bool? ?? false,
        role: json['role'] as String? ?? 'primary',
        alts: json['alts'] is List
            ? (json['alts'] as List)
                .whereType<Map>()
                .map((e) =>
                    LineAlternative.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const [],
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
  /// prepared for.
  ///
  /// The server stopped being able to send that on 1.9.2026: `pickReply` draws
  /// only from replies the student covered, and a position with none of those
  /// answers with no reply at all. The field and the sentence the screen builds
  /// from it are kept because they are the honest reading of a flag the server
  /// still sends — if the draw is ever widened again, the screen says so
  /// without being changed back.
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

/// One unconfirmed position in the walk.
/// How much of one repertoire is still waiting, from its own walk.
///
/// Two piles, never added together: [open] is a position this repertoire
/// reaches that holds no decision of yours, [draft] is one holding a generated
/// move waiting for a yes. Null in both when the walk could not be read — a
/// zero would read as "nothing left", which is the one thing a failure must
/// not be able to say.
class RepertoireProgress {
  const RepertoireProgress({
    required this.id,
    this.open,
    this.draft,
    this.decided,
  });

  final int id;
  final int? open;
  final int? draft;
  final int? decided;

  factory RepertoireProgress.fromJson(Map<String, dynamic> json) =>
      RepertoireProgress(
        id: (json['id'] as num?)?.toInt() ?? 0,
        open: (json['open'] as num?)?.toInt(),
        draft: (json['draft'] as num?)?.toInt(),
        decided: (json['decided'] as num?)?.toInt(),
      );
}

/// What has actually been practised since the reader's day started.
///
/// [positions] is the number a daily target is read against — distinct
/// positions, so answering the same board four times is one position practised
/// and not four. [scored] and [practice] split the same answers by whether the
/// schedule was told about them, and are never added together on screen: both
/// are work, only one moves a due date.
class PracticeToday {
  const PracticeToday({
    this.positions = 0,
    this.answers = 0,
    this.scored = 0,
    this.practice = 0,
  });

  final int positions;
  final int answers;
  final int scored;
  final int practice;

  factory PracticeToday.fromJson(Map<String, dynamic> json) => PracticeToday(
        positions: (json['positions'] as num?)?.toInt() ?? 0,
        answers: (json['answers'] as num?)?.toInt() ?? 0,
        scored: (json['scored'] as num?)?.toInt() ?? 0,
        practice: (json['practice'] as num?)?.toInt() ?? 0,
      );
}

class UnconfirmedNode {
  const UnconfirmedNode({
    required this.fen,
    required this.fenKey,
    required this.path,
    required this.ply,
    required this.moves,
  });

  final String fen;
  final String fenKey;
  final List<String> path;
  final int ply;
  final List<RepertoireMove> moves;

  factory UnconfirmedNode.fromJson(Map<String, dynamic> json) =>
      UnconfirmedNode(
        fen: json['fen'] as String? ?? '',
        fenKey: json['fenKey'] as String? ?? '',
        path: sanPath(json['path']),
        ply: _tolerantInt(json['ply']),
        moves: ((json['moves'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => RepertoireMove.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// The result of walking the drafts.
class RepertoireUnconfirmedWalk {
  const RepertoireUnconfirmedWalk({
    this.rootPath = const [],
    this.positions = const [],
    this.total = 0,
    this.truncated = false,
  });

  final List<String> rootPath;
  final List<UnconfirmedNode> positions;
  final int total;
  final bool truncated;

  factory RepertoireUnconfirmedWalk.fromJson(Map<String, dynamic> json) {
    final root = json['root'] is Map
        ? Map<String, dynamic>.from(json['root'] as Map)
        : const <String, dynamic>{};
    return RepertoireUnconfirmedWalk(
      rootPath: sanPath(root['path']),
      positions: ((json['positions'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => UnconfirmedNode.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      total: _tolerantInt(json['total']),
      truncated: json['truncated'] as bool? ?? false,
    );
  }
}

/// Draft counts for one color.
class UnconfirmedColorCount {
  const UnconfirmedColorCount({
    this.positions = 0,
    this.moves = 0,
  });

  final int positions;
  final int moves;

  factory UnconfirmedColorCount.fromJson(Map<String, dynamic> json) =>
      UnconfirmedColorCount(
        positions: _tolerantInt(json['positions']),
        moves: _tolerantInt(json['moves']),
      );
}

/// Draft counts for both colors.
class RepertoireUnconfirmedCounts {
  const RepertoireUnconfirmedCounts({
    this.w = const UnconfirmedColorCount(),
    this.b = const UnconfirmedColorCount(),
  });

  final UnconfirmedColorCount w;
  final UnconfirmedColorCount b;

  factory RepertoireUnconfirmedCounts.fromJson(Map<String, dynamic> json) {
    final w = json['w'] is Map
        ? Map<String, dynamic>.from(json['w'] as Map)
        : const <String, dynamic>{};
    final b = json['b'] is Map
        ? Map<String, dynamic>.from(json['b'] as Map)
        : const <String, dynamic>{};
    return RepertoireUnconfirmedCounts(
      w: UnconfirmedColorCount.fromJson(w),
      b: UnconfirmedColorCount.fromJson(b),
    );
  }
}

/// The result of playing an alternative to a draft.
class AlternativeResult {
  const AlternativeResult({
    required this.played,
    required this.rejected,
    this.orphans = 0,
    this.removed = 0,
    this.decisions = 0,
    this.drafts = 0,
  });

  final RepertoireMove played;
  final String rejected;
  final int orphans;
  final int removed;
  final int decisions;
  final int drafts;

  factory AlternativeResult.fromJson(Map<String, dynamic> json) {
    final played = json['played'] is Map
        ? Map<String, dynamic>.from(json['played'] as Map)
        : const <String, dynamic>{};
    return AlternativeResult(
      played: RepertoireMove.fromJson(played),
      rejected: json['rejected'] as String? ?? '',
      orphans: _tolerantInt(json['orphans']),
      removed: _tolerantInt(json['removed']),
      decisions: _tolerantInt(json['decisions']),
      drafts: _tolerantInt(json['drafts']),
    );
  }
}

int _tolerantInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class RepertoireApiService {
  RepertoireApiService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${SessionService.instance.current.token}',
        'Content-Type': 'application/json',
      };

  Future<RepertoireUnconfirmedWalk?> unconfirmedPositions({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    String? gateUci,
    String? breadth,
    int? minRating,
    int? limit,
  }) async {
    final uri = Uri.parse('$backendUrl/repertoire/unconfirmed').replace(
      queryParameters: {
        'color': color,
        'rootFen': rootFen,
        if (rootPath.isNotEmpty) 'rootPath': rootPath.join(' '),
        if (gateUci != null) 'gateUci': gateUci,
        if (breadth != null) 'breadth': breadth,
        // Interpolated, not empty. These went out as `minRating=` and `limit=`
        // for as long as this endpoint existed: the server reads
        // `Number('') || 0`, so every review asked at band 0 — a band the
        // opening book holds no replies for — and answered "nothing left to
        // confirm" on a repertoire with drafts waiting in it.
        if (minRating != null) 'minRating': '$minRating',
        if (limit != null) 'limit': '$limit',
      },
    );
    final res = (await _send(() => _get(uri))).res;
    if (res == null) return null;
    return RepertoireUnconfirmedWalk.fromJson(
        Map<String, dynamic>.from(jsonDecode(res.body) as Map));
  }

  /// The unanswered count for every repertoire at once.
  ///
  /// A walk each, so the list screen asks for this after it has drawn its
  /// cards. Null when the server could not be reached, which the caller shows
  /// as nothing rather than as zero.
  Future<List<RepertoireProgress>?> progress({int? minRating}) async {
    final uri = Uri.parse('$backendUrl/repertoire/progress').replace(
      queryParameters: {
        if (minRating != null) 'minRating': '$minRating',
      },
    );
    final res = (await _send(() => _get(uri))).res;
    if (res == null) return null;
    final data = jsonDecode(res.body);
    if (data is! Map || data['items'] is! List) return null;
    return (data['items'] as List)
        .whereType<Map>()
        .map((e) => RepertoireProgress.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// How much has been practised since [since] — the start of the reader's own
  /// day, which only the client knows.
  ///
  /// Null when the server could not be reached. The screen shows nothing rather
  /// than a zero: "you have practised nothing today" is a hard enough sentence
  /// to be told when it is true.
  Future<PracticeToday?> practiceToday({
    required DateTime since,
    String? color,
  }) async {
    final uri = Uri.parse('$backendUrl/repertoire/practice/today').replace(
      queryParameters: {
        'since': since.toUtc().toIso8601String(),
        if (color != null) 'color': color,
      },
    );
    final res = (await _send(() => _get(uri))).res;
    if (res == null) return null;
    return PracticeToday.fromJson(
        Map<String, dynamic>.from(jsonDecode(res.body) as Map));
  }

  Future<RepertoireUnconfirmedCounts?> unconfirmedCounts() async {
    final uri = Uri.parse('$backendUrl/repertoire/unconfirmed/count');
    final res = (await _send(() => _get(uri))).res;
    if (res == null) return null;
    return RepertoireUnconfirmedCounts.fromJson(
        Map<String, dynamic>.from(jsonDecode(res.body) as Map));
  }

  Future<({AlternativeResult? result, String? error})> playAlternative({
    required String color,
    required String fen,
    required String uci,
    required String san,
    required String rejectedUci,
    int? minRating,
    bool includeDecisions = false,
  }) async {
    final sent = await _send(() => _post('$backendUrl/repertoire/alternative', {
          'color': color,
          'fen': fen,
          'uci': uci,
          'san': san,
          'rejectedUci': rejectedUci,
          if (minRating != null) 'minRating': minRating,
          'includeDecisions': includeDecisions,
        }));
    final res = sent.res;
    if (res == null) return (result: null, error: sent.error);
    return (
      result: AlternativeResult.fromJson(
          Map<String, dynamic>.from(jsonDecode(res.body) as Map)),
      error: null,
    );
  }

  Future<bool> setBreadth({
    required int id,
    required String breadth,
  }) async {
    final sent = await _send(() => _put('$backendUrl/repertoire/breadth', {
          'id': id,
          'breadth': breadth,
        }));
    return sent.res != null;
  }

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
    String? viaUci,
  }) async {
    final sent = await _send(() => _post('$backendUrl/repertoire', {
          'name': name,
          'color': color,
          'rootFen': rootFen,
          'rootPath': rootPath,
          // The gate. Sent only when the reader chose one, which is when the
          // starting position already holds somebody else's first move.
          if (viaUci != null) 'viaUci': viaUci,
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
    String? gateUci,
    String? breadth,
  }) async {
    final uri = Uri.parse('$backendUrl/repertoire/frontier').replace(
      queryParameters: {
        'color': color,
        'rootFen': rootFen,
        if (rootPath.isNotEmpty) 'rootPath': rootPath.join(' '),
        if (minRating != null) 'minRating': '$minRating',
        if (gateUci != null) 'gateUci': gateUci,
        // The width, which is stored on the repertoire's row and means nothing
        // until somebody sends it: absent, the server falls back to `standard`
        // and the queue is computed at 80% for a repertoire set to `main`.
        if (breadth != null) 'breadth': breadth,
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

  /// Removes a repertoire — its name and starting point, and its moves only
  /// when [withMoves] says so.
  ///
  /// The moves belong to (user, colour) and are shared by every repertoire that
  /// reaches them, which is why they are not taken by default: deleting them
  /// here would empty one door's worth of work out of every other door. With
  /// [withMoves], what goes is what *only this repertoire reaches* — the count
  /// [removalPreview] hands back before the question is asked.
  ///
  /// [includeComments] takes what the student wrote as well. Off by default,
  /// because prose is the one thing here nothing can recompute.
  Future<bool> deleteRepertoire(
    int id, {
    bool withMoves = false,
    bool includeComments = false,
  }) async {
    final uri = Uri.parse('$backendUrl/repertoire/$id').replace(
      queryParameters: {
        if (withMoves) 'moves': '1',
        if (withMoves && includeComments) 'comments': '1',
      },
    );
    return (await _send(() => _delete(uri))).res != null;
  }

  /// Sets, changes or clears the move a repertoire goes through at its root.
  ///
  /// Its own door because the repertoires that most need a gate are the ones
  /// that already exist — built from the same position before this could be
  /// said at all, each showing the other's opening in its tree.
  ///
  /// Null clears it: back to the whole graph from that root, which is what a
  /// repertoire whose root holds one move wants.
  Future<({bool saved, String? viaUci, String? viaSan})> setGate(
    int id, {
    String? viaUci,
  }) async {
    final sent = await _send(() => _put('$backendUrl/repertoire/gate', {
          'id': id,
          'viaUci': viaUci,
        }));
    final res = sent.res;
    if (res == null) return (saved: false, viaUci: null, viaSan: null);
    final data = jsonDecode(res.body);
    if (data is! Map) return (saved: false, viaUci: null, viaSan: null);
    return (
      saved: true,
      viaUci: data['viaUci'] as String?,
      viaSan: data['viaSan'] as String?,
    );
  }

  /// What deleting this repertoire would strand, before anything is deleted.
  ///
  /// Null when the server did not answer — which the caller must tell apart
  /// from "nothing would be stranded", since one of them is a reason to stop.
  Future<RepertoireRemoval?> removalPreview(int id, {int? minRating}) async {
    final uri = Uri.parse('$backendUrl/repertoire/removal').replace(
      queryParameters: {
        'id': '$id',
        if (minRating != null) 'minRating': '$minRating',
      },
    );
    final res = (await _send(() => _get(uri))).res;
    if (res == null) return null;
    final data = jsonDecode(res.body);
    if (data is! Map) return null;
    return RepertoireRemoval.fromJson(Map<String, dynamic>.from(data));
  }

  /// Everything stored for one side, counted.
  Future<RepertoireColorStats?> colorStats({required String color}) async {
    final uri = Uri.parse('$backendUrl/repertoire/color')
        .replace(queryParameters: {'color': color});
    final res = (await _send(() => _get(uri))).res;
    if (res == null) return null;
    final data = jsonDecode(res.body);
    if (data is! Map) return null;
    return RepertoireColorStats.fromJson(Map<String, dynamic>.from(data));
  }

  /// Empties a side: every move, cut, extra reply, attempt, review and
  /// evaluation stored for it.
  ///
  /// The repertoires themselves stay — they are a name and a starting point,
  /// and emptying the moves is starting that opening over rather than disowning
  /// it. This is the only door that opens when no repertoire is left at all.
  Future<bool> eraseColor({
    required String color,
    bool includeComments = false,
  }) async {
    final uri = Uri.parse('$backendUrl/repertoire/color').replace(
      queryParameters: {
        'color': color,
        if (includeComments) 'comments': '1',
      },
    );
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

  /// The trunk, in one action: the most played move for both sides.
  ///
  /// Everything it writes is a draft the drill will not ask about until it is
  /// confirmed, and it never overwrites a position that already has a move —
  /// which is what makes it safe to run again from anywhere.
  ///
  /// Carries the reader's own Lichess token, like the judge and the book: it is
  /// their allowance being spent, up to two requests per move of depth.
  Future<({SpineResult? result, String? error})> buildSpine({
    required String color,
    required String rootFen,
    int depth = 8,
    int? minRating,
    int? minGames,
  }) async {
    final sent = await _send(() {
      final uri = Uri.parse('$backendUrl/repertoire/spine');
      final body = jsonEncode({
        'color': color,
        'rootFen': rootFen,
        'depth': depth,
        if (minRating != null) 'minRating': minRating,
        if (minGames != null) 'minGames': minGames,
      });
      final headers = {
        ..._headers,
        'X-Lichess-Token': AppSettingsService.instance.lichessApiToken.trim(),
      };
      return _client?.post(uri, headers: headers, body: body) ??
          http.post(uri, headers: headers, body: body);
    });
    final res = sent.res;
    if (res == null) return (result: null, error: sent.error);
    return (
      result: SpineResult.fromJson(
          Map<String, dynamic>.from(jsonDecode(res.body) as Map)),
      error: null,
    );
  }

  /// The opponent's book for a position, out of storage. Costs nothing.
  Future<StoredBook?> storedBook({
    required String color,
    required String fen,
    int? minRating,
  }) async {
    final uri = Uri.parse('$backendUrl/repertoire/book').replace(
      queryParameters: {
        'color': color,
        'fen': fen,
        if (minRating != null) 'minRating': '$minRating',
      },
    );
    final res = (await _send(() => _get(uri))).res;
    if (res == null) return null;
    return StoredBook.fromJson(
        Map<String, dynamic>.from(jsonDecode(res.body) as Map));
  }

  /// What removing a move would leave with no way back to it.
  ///
  /// Asked *before* the removal: "would this still be reachable without that
  /// move" cannot be answered once the move is gone. Nothing is written.
  ///
  /// Positions, and how many moves in them are drafts and how many decisions —
  /// the first can go silently, the second has to be asked about.
  Future<({List<String> keys, int drafts, int decisions})?> orphansOfRemoving({
    required String color,
    required String fen,
    required String uci,
    int? minRating,
  }) async {
    final uri = Uri.parse('$backendUrl/repertoire/node/orphans').replace(
      queryParameters: {
        'color': color,
        'fen': fen,
        'uci': uci,
        if (minRating != null) 'minRating': '$minRating',
      },
    );
    final res = (await _send(() => _get(uri))).res;
    if (res == null) return null;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      keys: ((data['keys'] as List?) ?? const []).whereType<String>().toList(),
      drafts: (data['drafts'] as num?)?.toInt() ?? 0,
      decisions: (data['decisions'] as num?)?.toInt() ?? 0,
    );
  }

  /// Takes out positions nothing reaches any more.
  ///
  /// Drafts go by default; decisions only when [includeDecisions] says so. The
  /// server re-checks every key against the roots first, so a list that has
  /// gone stale cannot delete a line that is back in use.
  Future<int> prune({
    required String color,
    required List<String> keys,
    bool includeDecisions = false,
    int? minRating,
  }) async {
    if (keys.isEmpty) return 0;
    final sent = await _send(() => _post('$backendUrl/repertoire/prune', {
          'color': color,
          'keys': keys,
          'includeDecisions': includeDecisions,
          if (minRating != null) 'minRating': minRating,
        }));
    final res = sent.res;
    if (res == null) return 0;
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['removed'] as num?)?.toInt() ?? 0;
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
    List<String> alongPath = const [],
    int? minRating,
    int maxPly = 16,
    String? gateUci,
    String? breadth,
  }) async {
    final uri = Uri.parse('$backendUrl/repertoire/tree').replace(
      queryParameters: {
        'color': color,
        'rootFen': rootFen,
        if (rootPath.isNotEmpty) 'rootPath': rootPath.join(' '),
        // The line the reader is standing on, in SAN from `rootFen`. The walk
        // follows it whatever the breadth says, so the drawing always holds a
        // card for the position on the board.
        //
        // The same shape as `maxPly` beside it, and for the same reason: the
        // picture has to be able to reach the reader. That was fixed for depth
        // on 4.9.2026; this is the other half of it, for width. Without it a
        // move played outside the cut left the board on a position the drawing
        // had no card for, and the highlight fell back to the repertoire's
        // root — being thrown to the beginning mid-thought.
        if (alongPath.isNotEmpty) 'alongPath': alongPath.join(' '),
        if (minRating != null) 'minRating': '$minRating',
        'maxPly': '$maxPly',
        // The gate: with it the picture is one opening, which is the whole
        // reason it exists — two repertoires from one position drew each
        // other's moves.
        if (gateUci != null) 'gateUci': gateUci,
        // Same as the gate, and for the same reason: the picture is drawn at
        // the width the repertoire was set to, not at the server's default.
        if (breadth != null) 'breadth': breadth,
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
  ///
  /// The door is either [ids] — several repertoires drilled as one sitting —
  /// or a [rootFen], never both: given ids the server reads each door's root,
  /// gate and breadth from its own row, so sending them beside it would be
  /// three parallel answers to one question.
  Future<DrillLine?> drillLine({
    required String color,
    String? rootFen,
    List<String> rootPath = const [],
    int? minRating,
    String? fromFen,
    String? viaFen,
    String? viaUci,
    List<String> exclude = const [],
    bool ahead = false,
    String? gateUci,
    String? breadth,
    List<int>? ids,
  }) async {
    final byIds = ids != null && ids.isNotEmpty;
    assert(byIds || rootFen != null, 'a drill line needs ids or a rootFen');
    final uri = Uri.parse('$backendUrl/repertoire/drill/line').replace(
      queryParameters: <String, dynamic>{
        'color': color,
        if (byIds) 'ids': ids.join(','),
        if (!byIds) ...{
          if (rootFen != null) 'rootFen': rootFen,
          if (rootPath.isNotEmpty) 'rootPath': rootPath.join(' '),
          if (gateUci != null) 'gateUci': gateUci,
          // Beside the root and never beside `ids`, which carry their own.
          if (breadth != null) 'breadth': breadth,
        },
        if (minRating != null) 'minRating': '$minRating',
        if (fromFen != null) 'fromFen': fromFen,
        // Which decision to walk through, for somebody standing at a fork who
        // wants the other road rather than the one the schedule offered.
        if (viaFen != null && viaUci != null) ...{
          'viaFen': viaFen,
          'viaUci': viaUci,
        },
        // The positions already refused. Without them "another line" is a
        // promise the queue cannot keep: it is deterministic, and skipping
        // writes nothing down.
        if (exclude.isNotEmpty) 'exclude': exclude,
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
    bool onlyIfDue = false,
  }) async {
    final res =
        (await _send(() => _post('$backendUrl/repertoire/drill/answer', {
                  'color': color,
                  'fen': fen,
                  'uci': uci,
                  'revealed': revealed,
                  if (minRating != null) 'minRating': minRating,
                  if (practice) 'practice': true,
                  if (onlyIfDue) 'onlyIfDue': true,
                })))
            .res;
    if (res == null) return null;
    return DrillAnswer.fromJson(
        Map<String, dynamic>.from(jsonDecode(res.body) as Map));
  }

  /// Every eval this student has for that side, keyed by position.
  ///
  /// One call per tree draw rather than one per card, and free — it reads what
  /// was already computed and spends no Lichess allowance and no engine time.
  Future<Map<String, RepertoireNote>> notes({required String color}) async {
    final uri = Uri.parse('$backendUrl/repertoire/notes')
        .replace(queryParameters: {'color': color});
    final res = (await _send(() => _get(uri))).res;
    if (res == null) return const {};
    final data = jsonDecode(res.body);
    if (data is! Map || data['notes'] is! List) return const {};
    final notes = (data['notes'] as List)
        .whereType<Map>()
        .map((e) => RepertoireNote.fromJson(Map<String, dynamic>.from(e)));
    return {for (final note in notes) note.fenKey: note};
  }

  /// Stores what the engine said about one position.
  ///
  /// The answer is the note that is now on the node, which is not always the
  /// one just sent: a shallower search never overwrites a deeper one, and the
  /// screen has to draw what is stored rather than what it asked for.
  Future<RepertoireNote?> putNote({
    required String color,
    required String fen,
    required int evalCp,
    int? mateIn,
    int evalDepth = 0,
    String? bestUci,
    String? bestLineSan,
  }) async {
    final sent = await _send(() => _put('$backendUrl/repertoire/note', {
          'color': color,
          'fen': fen,
          'evalCp': evalCp,
          if (mateIn != null) 'mateIn': mateIn,
          'evalDepth': evalDepth,
          if (bestUci != null) 'bestUci': bestUci,
          if (bestLineSan != null) 'bestLineSan': bestLineSan,
        }));
    final res = sent.res;
    if (res == null) return null;
    final data = jsonDecode(res.body);
    if (data is! Map || data['note'] is! Map) return null;
    return RepertoireNote.fromJson(
        Map<String, dynamic>.from(data['note'] as Map));
  }

  /// Every comment this student wrote for that side, keyed by position.
  ///
  /// One call beside [notes], read by the same screen at the same moment: a
  /// tree of a hundred cards must not cost a hundred requests.
  Future<Map<String, RepertoireComment>> comments(
      {required String color}) async {
    final uri = Uri.parse('$backendUrl/repertoire/comments')
        .replace(queryParameters: {'color': color});
    final res = (await _send(() => _get(uri))).res;
    if (res == null) return const {};
    final data = jsonDecode(res.body);
    if (data is! Map || data['comments'] is! List) return const {};
    final all = (data['comments'] as List)
        .whereType<Map>()
        .map((e) => RepertoireComment.fromJson(Map<String, dynamic>.from(e)));
    return {for (final one in all) one.fenKey: one};
  }

  /// Writes what the student says about a position, or clears it.
  ///
  /// An empty body deletes the row on the server, so the comment coming back is
  /// null both when it was cleared and when the call failed. [saved] is what
  /// tells those apart — they look identical from the outside and only one of
  /// them means the screen should complain.
  Future<({bool saved, RepertoireComment? comment})> putComment({
    required String color,
    required String fen,
    required String body,
  }) async {
    final sent = await _send(() => _put('$backendUrl/repertoire/comment', {
          'color': color,
          'fen': fen,
          'body': body,
        }));
    final res = sent.res;
    if (res == null) return (saved: false, comment: null);
    final data = jsonDecode(res.body);
    if (data is! Map) return (saved: false, comment: null);
    final one = data['comment'];
    return (
      saved: true,
      comment: one is Map
          ? RepertoireComment.fromJson(Map<String, dynamic>.from(one))
          : null,
    );
  }

  /// Takes the comment off a position.
  Future<bool> deleteComment({
    required String color,
    required String fen,
  }) async {
    final uri = Uri.parse('$backendUrl/repertoire/comment')
        .replace(queryParameters: {'color': color, 'fen': fen});
    return (await _send(() => _delete(uri))).res != null;
  }

  /// Where the engine plays something other than what was chosen, worst first.
  ///
  /// Derived from the notes already stored, so it costs nothing at Lichess and
  /// nothing in engine time. [fromFen] narrows it to one branch — the ten
  /// positions built yesterday are what somebody sits down to go through.
  Future<DisagreementReport?> disagreements({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int? minRating,
    String? fromFen,
    String? gateUci,
  }) async {
    final uri = Uri.parse('$backendUrl/repertoire/disagreements').replace(
      queryParameters: {
        'color': color,
        'rootFen': rootFen,
        if (rootPath.isNotEmpty) 'rootPath': rootPath.join(' '),
        if (minRating != null) 'minRating': '$minRating',
        if (fromFen != null) 'fromFen': fromFen,
        if (gateUci != null) 'gateUci': gateUci,
      },
    );
    final res = (await _send(() => _get(uri))).res;
    if (res == null) return null;
    return DisagreementReport.fromJson(
        Map<String, dynamic>.from(jsonDecode(res.body) as Map));
  }

  /// The opponent's first answers, each with how much of it is waiting.
  ///
  /// Free, like everything that reads what was built. Empty when the server
  /// could not be reached, which the caller shows as "the whole repertoire"
  /// rather than as "you have no branches".
  ///
  /// Asked by [ids], the branches of several repertoires come back as one list,
  /// each tagged with the repertoire it came from. Asked by [rootFen], that tag
  /// is null — there is only one door and the caller is standing in it.
  Future<List<DrillBranch>> drillBranches({
    required String color,
    String? rootFen,
    List<String> rootPath = const [],
    int? minRating,
    String? gateUci,
    String? breadth,
    List<int>? ids,
  }) async {
    final byIds = ids != null && ids.isNotEmpty;
    assert(byIds || rootFen != null, 'a branch list needs ids or a rootFen');
    final uri = Uri.parse('$backendUrl/repertoire/drill/branches').replace(
      queryParameters: <String, dynamic>{
        'color': color,
        if (byIds) 'ids': ids.join(','),
        if (!byIds) ...{
          if (rootFen != null) 'rootFen': rootFen,
          if (rootPath.isNotEmpty) 'rootPath': rootPath.join(' '),
          if (gateUci != null) 'gateUci': gateUci,
          if (breadth != null) 'breadth': breadth,
        },
        if (minRating != null) 'minRating': '$minRating',
      },
    );
    final res = (await _send(() => _get(uri))).res;
    if (res == null) return const [];
    final data = jsonDecode(res.body);
    if (data is! Map || data['branches'] is! List) return const [];
    return (data['branches'] as List)
        .whereType<Map>()
        .map((e) => DrillBranch.fromJson(Map<String, dynamic>.from(e)))
        .toList();
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

  Future<http.Response> _put(String url, Map<String, dynamic> body) {
    final uri = Uri.parse(url);
    final encoded = jsonEncode(body);
    return _client?.put(uri, headers: _headers, body: encoded) ??
        http.put(uri, headers: _headers, body: encoded);
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
