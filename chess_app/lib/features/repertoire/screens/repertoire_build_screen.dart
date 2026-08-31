import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/opening_judge_panel_widget.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/repertoire/line_text.dart';
import 'package:chess_app/features/repertoire/widgets/repertoire_tree_panel.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/breakpoints.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/board_coordinates_button.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/engine_analysis_dials.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// Building a repertoire by being asked, not by being told.
///
/// The loop is the whole idea: the board shows a position, the student plays
/// what they would play, the judge says what it is worth, and the student
/// decides whether to keep it. Only then does the opponent's side of the
/// position open up, one wave at a time. Nobody is shown a line to memorise,
/// and the moves that end up stored are the student's own choices — which is
/// the difference between a repertoire somebody owns and one they were handed.
///
/// Three rules hold this together, and each of them is a decision rather than
/// an accident:
///
///   * **The first move kept in a position is the primary.** Alternates are
///     welcome, but one move has to be the answer, or the drill has nothing to
///     ask for. The database holds that rule, not this screen.
///   * **The opponent's replies stop at a share, not at a number the student
///     picks.** The server covers what 80% of games actually play, up to four
///     moves, and says how much is left outside. A position with no end is a
///     repertoire that never gets built.
///   * **The rejected attempts are kept too.** They are where the instinct is
///     wrong, and they are what the drill should ask about first.
class RepertoireBuildScreen extends StatefulWidget {
  const RepertoireBuildScreen({
    super.key,
    required this.name,
    required this.color,
    required this.rootFen,
    this.rootPath = const [],
    this.minRating,
    this.api,
    this.judge,
    this.analyse,
    this.onDrillHere,
  });

  final String name;

  /// 'w' or 'b' — the side being prepared. The board is turned this way and
  /// only these moves are ever asked for.
  final String color;

  final String rootFen;

  /// The moves that led to [rootFen], in SAN.
  ///
  /// A repertoire may start anywhere, so without this the breadcrumb would
  /// begin mid-air: a Smith-Morra repertoire whose root is move four would read
  /// as though the game started there. Empty for a repertoire built from a
  /// pasted position, where there is no line to tell.
  final List<String> rootPath;

  /// The rating band the opponent's replies are counted in. A child meets the
  /// moves of their own opponents, not a grandmaster's.
  final int? minRating;

  /// Injected in tests, which have neither a server nor a Lichess token.
  final RepertoireApiService? api;
  final OpeningJudgeService? judge;

  /// Called with the position in front of the student, so the screen above can
  /// open the drill over that branch alone.
  ///
  /// A callback rather than a push from here, the same way the drill screen
  /// hands a position back to be built: the two screens stay strangers, and
  /// whoever opened them decides what happens between them.
  final void Function(String fen)? onDrillHere;

  /// Runs the engine on one position and answers with the lines. The local
  /// Stockfish by default — injected in tests, which have no engine binary and
  /// must not wait ten seconds for one.
  final Future<List<AnalysisLine>> Function(String fen, int depth, int multiPV)?
      analyse;

  @override
  State<RepertoireBuildScreen> createState() => _RepertoireBuildScreenState();
}

class _RepertoireBuildScreenState extends State<RepertoireBuildScreen> {
  final ChessBoardController _boardController = ChessBoardController();

  late final RepertoireApiService _api = widget.api ?? RepertoireApiService();
  late final OpeningJudgeService _judge =
      widget.judge ?? OpeningJudgeService.instance;

  /// Positions still to be answered, most-reached first — and, the point of the
  /// type, the way each one was reached.
  ///
  /// The queue used to hold bare FENs, which is why this screen could never say
  /// where the student was: a board with no history and a count of an invisible
  /// list. The path costs one list per position and turns "Još 14 u redu" into
  /// a line the reader can find themselves in.
  ///
  /// A list rather than a queue, because the order is not arrival order. New
  /// positions used to be appended, so a main line opened halfway through a
  /// session waited behind every sideline enqueued before it — and the same
  /// walk, resumed tomorrow, came back in a different order, since the server
  /// sorts by `reach`. Two orders for one walk is the worse half of that: the
  /// student learns the shape of a session rather than the shape of the tree.
  final List<_Pending> _queue = [];

  /// Every position that has already been queued, so a transposition does not
  /// come round twice. Keyed the way the server keys them: no move counters.
  final Set<String> _seen = {};

  /// The repertoire as a picture, and the same thing converted for the tree
  /// widget. Beside the board rather than on another screen: it was a screen
  /// for one day, which is one day of it being useless — seeing what you were
  /// building meant leaving the board and coming back.
  ///
  /// Costs no Lichess allowance, like everything that reads what was built, so
  /// it can be re-read whenever the store changes.
  RepertoireTree? _tree;
  AnalysisNode? _treeRoot;

  _Pending? _node;

  /// The position on the board. A getter so the FEN reads the same everywhere
  /// it did before the queue learned to carry paths.
  String? get _current => _node?.fen;

  /// The walk this screen resumed from, kept for the header. Null until the
  /// server has answered, and after a server that did not.
  RepertoireFrontier? _frontier;
  bool _resuming = true;

  List<RepertoireMove> _kept = const [];

  String? _proposalUci;
  String? _proposalSan;
  OpeningJudgement? _verdict;
  String? _verdictReason;

  /// The book, once the student has said they do not know. Opening it is
  /// allowed and is written down — a position answered by looking is not the
  /// same as one answered by thinking, and the drill should know the
  /// difference.
  OpponentReplies? _book;
  bool _lookedUp = false;

  /// What the opponent answers the student's own move with.
  ///
  /// These were fetched and thrown away: `Dalje` spent a Lichess request on
  /// them, counted what they covered, and moved on without ever putting them in
  /// front of the person who paid for them. They are the whole reason the next
  /// wave looks the way it does, so they are now shown — on the board, from the
  /// position they are answers to, with how often each is played.
  OpponentReplies? _answers;

  /// The position the answers belong to: after the student's primary move.
  /// Kept for the same reason `_linesFen` is — an answer drawn on the wrong
  /// board is worse than no answer.
  String? _answersFen;
  String? _answersSan;

  /// The branches cut in this session: "I am not preparing this."
  ///
  /// Kept here as well as on the server so the header can say how many there
  /// are without asking for the whole walk again. The walk is read once, on the
  /// way in; re-reading it after every cut would be a request per press to
  /// change one number.
  final List<_Pending> _cutHere = [];

  /// What the opponent plays after the student's main move here, out of the
  /// stored book — no Lichess request. Beside the board rather than behind a
  /// button, because it is the thing that decides what the next wave looks
  /// like.
  StoredBook? _stored;

  /// The position the stored book belongs to: after the primary move. Kept for
  /// the same reason the engine keeps its own — a list drawn for the previous
  /// board names moves that cannot be played on this one.
  String? _storedFor;

  /// The opponent's moves prepared by hand in this session, past the cut.
  ///
  /// Kept so the row can say it is done without asking the server again — the
  /// walk already knows, and this screen only needs to stop offering a button
  /// that has been pressed.
  final Set<String> _preparedUcis = {};

  /// Whether the tail is showing. Folded away by default: ten moves at one per
  /// cent each under every position would bury the answers that matter.
  bool _showTail = false;

  /// The last branch cut, and the only one the undo button offers back.
  ///
  /// One step is enough here and more would be a second list to keep straight:
  /// cutting is a considered answer to a position on the board, not a stream of
  /// keystrokes, and the ones before it are on the server where the whole list
  /// can be shown when there is a screen for it.
  _Pending? _lastCut;

  /// How many questions this session has cost the student's Lichess allowance.
  /// On screen, because it is their allowance and they should not have to guess.
  int _asked = 0;

  bool _busy = false;
  String? _note;

  /// The engine's opinion, when it has been asked for one.
  ///
  /// Asked for by hand and answered once, rather than left running: this screen
  /// is a conversation about one position at a time, and an engine that streams
  /// in the background would be turning a phone warm to answer a question
  /// nobody asked yet. It costs no Lichess allowance at all — it is the local
  /// engine, and its depth and number of lines are the reader's to set.
  List<AnalysisLine> _lines = const [];
  bool _thinking = false;

  /// The position the lines belong to.
  ///
  /// Not bookkeeping — the whole difference between an opinion and a wrong one.
  /// A deep search takes seconds, the reader can walk on while it runs, and the
  /// answer then arrives for a board nobody is looking at. It was on screen:
  /// the engine offered `Bxb2` in a position with no capture on b2, because
  /// that move was legal one position earlier. Every answer here is checked
  /// against the position it was asked for, the same way the endgame trainer
  /// keeps its readout's FEN and the analysis board keeps its judged node.
  String? _linesFen;

  bool get _forWhite => widget.color == 'w';

  @override
  void initState() {
    super.initState();
    _resume();
  }

  /// Picks the walk back up where it was, rather than starting again.
  ///
  /// The queue is not stored anywhere and never was — the server rebuilds it
  /// from the moves already kept and the books already fetched, which costs no
  /// Lichess request at all. That is what makes closing this screen safe: come
  /// back tomorrow, or on the other machine, and the same positions are
  /// waiting, in the same order.
  ///
  /// A server that does not answer falls back to the root. It has to be the
  /// root and not an empty screen: "we could not find out" must never be shown
  /// as "there is nothing left to do".
  Future<void> _resume() async {
    final walk = await _api.frontier(
      color: widget.color,
      rootFen: widget.rootFen,
      rootPath: widget.rootPath,
      minRating: widget.minRating,
    );
    if (!mounted) return;
    if (walk == null) {
      _enqueue(widget.rootFen, const [], reach: 1);
      setState(() {
        _resuming = false;
        _note = 'Nije moglo da se pročita dokle ste stigli — počinjete od '
            'početne pozicije repertoara.';
      });
    } else {
      for (final node in walk.open) {
        _enqueue(node.fen, node.path, kind: node.kind, reach: node.reach);
      }
      setState(() {
        _frontier = walk;
        _resuming = false;
      });
    }
    await _advance();
    // Read after the queue rather than beside it: the walk decides what is on
    // the board, and a picture that arrives first would highlight a position
    // nobody is standing on yet.
    await _loadTree();
  }

  /// Re-reads the picture. Called after anything that changes the store, and
  /// never on a plain advance: the tree only moves when the moves do.
  Future<void> _loadTree() async {
    final tree = await _api.repertoireTree(
      color: widget.color,
      rootFen: widget.rootFen,
      rootPath: widget.rootPath,
      minRating: widget.minRating,
    );
    if (!mounted || tree == null) return;
    setState(() {
      _tree = tree;
      _treeRoot = repertoireTreeToNodes(tree);
    });
  }

  /// The node the board is standing on, for the tree to highlight.
  AnalysisNode? get _activeNode {
    final root = _treeRoot;
    final fen = _current;
    if (root == null || fen == null) return null;
    return findNodeByFen(root, fen) ?? root;
  }

  /// Takes the board to a position in the tree.
  ///
  /// A tap on a card whose position is the opponent's to move lands on its
  /// parent instead — the position where that move was *chosen*, which is the
  /// only one this screen can ask a question about, and what somebody tapping
  /// their own move means by it.
  ///
  /// The queue is left alone. The board shows a position; the queue is where
  /// the next question comes from, and those were never the same thing.
  Future<void> _jumpTo(AnalysisNode node) async {
    var target = node;
    if (!_isMine(target.fen) && target.parent != null) {
      target = target.parent!;
    }
    if (!_isMine(target.fen)) return;
    await _show(_Pending(fen: target.fen, path: _pathTo(target)));
  }

  /// Whether the student is the one to move here.
  bool _isMine(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    return parts.length >= 2 && parts[1] == widget.color;
  }

  /// The moves from the repertoire's root down to a node.
  List<String> _pathTo(AnalysisNode node) {
    final moves = <String>[];
    AnalysisNode? at = node;
    while (at != null && at.moveSan != null) {
      moves.insert(0, at.moveSan!);
      at = at.parent;
    }
    return moves;
  }

  String _keyOf(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    return parts.length >= 4 ? parts.sublist(0, 4).join(' ') : fen;
  }

  /// Puts a position in the queue where its `reach` says it belongs.
  ///
  /// The same rule the server sorts by, applied to positions that arrive during
  /// a session: most-reached first, and among equals the shallower one. Sorted
  /// on insert rather than appended, so what opens deep in the main line
  /// overtakes a sideline that was queued earlier — and so leaving the screen
  /// and coming back does not reshuffle the walk.
  void _enqueue(String fen, List<String> path,
      {String kind = 'undecided', double reach = 0}) {
    final key = _keyOf(fen);
    if (_seen.contains(key)) return;
    _seen.add(key);
    final node = _Pending(fen: fen, path: path, kind: kind, reach: reach);
    var at = 0;
    while (at < _queue.length &&
        (_queue[at].reach > node.reach ||
            (_queue[at].reach == node.reach &&
                _queue[at].path.length <= node.path.length))) {
      at += 1;
    }
    _queue.insert(at, node);
  }

  /// Moves to the next position in the queue, or to the "nothing left" state.
  Future<void> _advance() => _show(_queue.isEmpty ? null : _queue.removeAt(0));

  /// Puts one position on the board, or the finished screen when there is none.
  ///
  /// Everything belonging to the previous position is cleared here, in one
  /// place. A verdict, a book, an engine line or a set of answers that outlived
  /// the board it was about is a bug this screen has met more than once, and it
  /// is only ever avoided by there being a single door.
  Future<void> _show(_Pending? node) async {
    setState(() {
      _proposalUci = null;
      _proposalSan = null;
      _verdict = null;
      _verdictReason = null;
      _book = null;
      _lookedUp = false;
      _answers = null;
      _answersFen = null;
      _answersSan = null;
      _showTail = false;
      _preparedUcis.clear();
      _lines = const [];
      _linesFen = null;
      _thinking = false;
      _node = node;
      _kept = const [];
    });
    final fen = _current;
    if (fen == null) return;
    _boardController.loadFen(fen);
    await _loadKept();
  }

  /// The line that leads to the board in front of the student, numbered the way
  /// a book numbers it.
  ///
  /// The repertoire's own root path first, so a repertoire built from move four
  /// reads from move one rather than pretending the game began where the
  /// student stopped playing.
  String _lineText() {
    final moves = [
      ...widget.rootPath,
      ...?_node?.path,
      // The board is one move further on while the answers are up, and a
      // breadcrumb that stopped short of it would name a position that is not
      // the one being looked at.
      if (_answers != null && _answersSan != null) _answersSan!,
    ];
    // With a root path the game began at move one; without one, the root FEN is
    // the only thing that knows where the counting starts.
    return numberedLine(
      moves,
      from: widget.rootPath.isEmpty ? widget.rootFen : null,
    );
  }

  Future<void> _loadKept() async {
    final fen = _current;
    if (fen == null) return;
    final moves = await _api.movesAt(color: widget.color, fen: fen);
    if (!mounted) return;
    setState(() => _kept = moves);
    await _loadStoredBook();
  }

  /// Reads the opponent's book for the position after the main move here.
  ///
  /// Free: it comes out of `opening_replies`, which holds whatever anybody's
  /// build session already paid for. A panel that follows the board and
  /// refetched on every move would spend the reader's allowance on a drawing
  /// they never asked for — one token serves every child using this app.
  Future<void> _loadStoredBook() async {
    final fen = _current;
    final primary = _kept.isEmpty ? null : _kept.first;
    if (fen == null || primary == null) {
      if (!mounted) return;
      setState(() {
        _stored = null;
        _storedFor = null;
      });
      return;
    }
    final after = _fenAfter(fen, primary.uci);
    if (after == null) return;
    final book = await _api.storedBook(
      color: widget.color,
      fen: after,
      minRating: widget.minRating,
    );
    if (!mounted) return;
    // The book that arrives is the book for the board it was asked about.
    if (_current != fen) return;
    setState(() {
      _stored = book;
      _storedFor = after;
    });
  }

  /// Opens the book for a position nobody has looked at yet. One request, and
  /// only because the reader pressed for it.
  Future<void> _openStoredBook() async {
    final after = _storedFor;
    if (after == null || _busy) return;
    setState(() => _busy = true);
    final lookup = await _judge.replies(after, minRating: widget.minRating);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _asked += 1;
      if (!lookup.isAvailable) {
        _note = 'Knjiga nije dostupna (${lookup.reason}).';
      }
    });
    // The route stores what it fetched, so reading it back is free from now on.
    await _loadStoredBook();
  }

  /// The student's own move, offered to the judge at once.
  ///
  /// Judged automatically rather than on a button, because in this mode that is
  /// the point of playing the move at all. The counter above says what it cost.
  Future<void> _onMove(String from, String to, String promotion) async {
    final fen = _current;
    if (fen == null || _busy || _proposalUci != null) return;

    final board = chess.Chess.fromFEN(fen);
    final isPromotion = _isPromotion(board, from, to);
    // The piece the reader picked on the board. A repertoire line is stored as
    // UCI, and 'e8q' and 'e8n' are different lines.
    final piece = promotion.isEmpty ? 'q' : promotion;
    final ok = board.move({
      'from': from,
      'to': to,
      if (isPromotion) 'promotion': piece,
    });
    if (ok == false) {
      // An illegal drag must never leave the board showing a position nobody
      // asked about.
      _boardController.loadFen(fen);
      return;
    }
    final san = board.getHistory().last.toString();
    final uci = isPromotion ? '$from$to$piece' : '$from$to';

    setState(() {
      _busy = true;
      _proposalUci = uci;
      _proposalSan = san;
      _verdict = null;
      _verdictReason = null;
    });

    final lookup = await _judge.judge(fen, uci, minRating: widget.minRating);
    if (!mounted) return;
    if (_current != fen) return;
    setState(() {
      _busy = false;
      _asked += 1;
      _verdict = lookup.judgement;
      _verdictReason = lookup.reason;
    });

    // And now the book, without being asked for it.
    //
    // The rule is about *when*, not whether: hidden while the student is still
    // deciding, free the moment they have committed. Choosing between
    // candidates is the work, and a verdict on one move says whether that move
    // is sound — not whether something better was sitting next to it. There is
    // nothing left to spoil once the move has been played.
    await _loadBook(marksLookedUp: false);
  }

  /// The moves played from the position in front of the student, and how those
  /// games went. Fetched once per position; the counter says what it cost.
  Future<void> _loadBook({required bool marksLookedUp}) async {
    final fen = _current;
    if (fen == null || _book != null) return;
    // Without a token there is no book to fetch, and the verdict panel already
    // says why. A second sentence about the same missing token is noise.
    if (!_judge.hasPersonalToken) return;
    setState(() => _busy = true);
    final lookup = await _judge.replies(fen, minRating: widget.minRating);
    if (!mounted) return;
    // The book that arrives is the book for the board it was asked about.
    if (_current != fen) return;
    setState(() {
      _busy = false;
      _asked += 1;
      _book = lookup.replies;
      if (marksLookedUp) _lookedUp = true;
      if (!lookup.isAvailable) {
        _note = 'Knjiga nije dostupna (${lookup.reason}).';
      }
    });
  }

  bool _isPromotion(chess.Chess board, String from, String to) {
    final piece = board.get(from);
    if (piece == null || piece.type != chess.PieceType.PAWN) return false;
    final rank = to.substring(1);
    return rank == '8' || rank == '1';
  }

  Future<void> _keep() async {
    final fen = _current;
    final uci = _proposalUci;
    final san = _proposalSan;
    if (fen == null || uci == null || san == null) return;

    setState(() => _busy = true);
    final verdict = _verdict?.verdict.name;
    final saved = await _api.keepMove(
      color: widget.color,
      fen: fen,
      uci: uci,
      san: san,
      verdict: verdict,
    );
    await _api.recordAttempt(
      color: widget.color,
      fen: fen,
      uci: uci,
      san: san,
      verdict: verdict,
      kept: true,
      lookedUp: _lookedUp,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _note = saved ? null : 'Potez nije sačuvan — server nije odgovorio.';
    });
    if (saved) {
      await _loadKept();
      await _loadTree();
    }
    _clearProposal();
  }

  Future<void> _discard() async {
    final fen = _current;
    final uci = _proposalUci;
    if (fen == null || uci == null) return;
    // Written down even though it was thrown away. This is the row the drill
    // will read: it is where the first instinct was wrong.
    await _api.recordAttempt(
      color: widget.color,
      fen: fen,
      uci: uci,
      san: _proposalSan,
      verdict: _verdict?.verdict.name,
      kept: false,
      lookedUp: _lookedUp,
    );
    _clearProposal();
  }

  void _clearProposal() {
    final fen = _current;
    setState(() {
      _proposalUci = null;
      _proposalSan = null;
      _verdict = null;
      _verdictReason = null;
    });
    if (fen != null) _boardController.loadFen(fen);
  }

  /// Opens the book for the position in front of the student.
  Future<void> _showBook() => _loadBook(marksLookedUp: true);

  /// What the engine makes of this position, at the reader's depth and with as
  /// many lines as they asked for.
  /// This board's analysis dials — see [EngineAnalysisDials]. Up to 50 plies
  /// here: on a repertoire position it is worth waiting for, and the old
  /// ceiling of 28 was a leftover from when this number also decided how long
  /// the engine thought before playing a move.
  int _analysisDepth = AppSettingsService.instance.analysisDepth;
  int _analysisLines = AppSettingsService.instance.analysisLines;

  /// What the board draws, and in which order of precedence.
  ///
  /// One layer at a time, never two. Three arrow sets answering three different
  /// questions on one board is not richer, it is unreadable — and the badges
  /// would then be percentages of different things sitting next to each other.
  ///
  /// Every arrow here is drawn for the position actually on the board. That is
  /// not bookkeeping: an arrow from the previous position points at pieces that
  /// have moved, which is the same bug the engine readout had.
  List<EngineArrow> _boardArrows() {
    // Standing after our own move, looking at what comes back.
    if (_answers != null) return _replyArrows(_answers!);
    // The engine, if it was asked about this position and answered.
    final engine = _engineArrows();
    if (engine.isNotEmpty) return engine;
    // A move is on the board waiting to be judged, so the pieces are no longer
    // where the kept moves start.
    if (_proposalUci != null) return const [];
    return _keptArrows();
  }

  /// A share, as a reader reads it. Below one percent is `<1%` rather than
  /// `0%`, which would say "never played" about a move that is on screen
  /// precisely because it was.
  String _shareText(double share) {
    final percent = share * 100;
    if (percent <= 0) return '';
    return percent < 1 ? '<1%' : '${percent.round()}%';
  }

  /// The opponent's answers, most played first.
  ///
  /// The number beside each is its **share** of games from that position, not
  /// how those games ended. Share is what decides whether a move has to be
  /// prepared for; the result percentage says how it went for people who are
  /// not this student, and putting it on an arrow invites picking the biggest
  /// number, which is the wrong lesson. It is still in the panel below, where
  /// there is room to say what it means.
  List<EngineArrow> _replyArrows(OpponentReplies answers) {
    final arrows = <EngineArrow>[];
    var rank = 1;
    for (final reply in answers.replies) {
      if (reply.uci.length < 4) continue;
      arrows.add(EngineArrow(
        from: reply.uci.substring(0, 2),
        to: reply.uci.substring(2, 4),
        evalText: _shareText(reply.share),
        rank: rank,
      ));
      rank += 1;
    }
    return arrows;
  }

  /// The moves the student has already decided on here.
  ///
  /// The primary is marked with a star and drawn thickest — rank carries stroke
  /// width as well as colour, and the star is a third channel again. Which move
  /// is the main one must never rest on hue alone.
  ///
  /// The share comes from the book when the book happens to be open. It is not
  /// fetched for this: an arrow is not worth a Lichess request the student did
  /// not ask for, and the star says the thing that matters without one.
  List<EngineArrow> _keptArrows() {
    final book = _book;
    final shares = <String, double>{
      if (book != null)
        for (final move in (book.all.isNotEmpty ? book.all : book.replies))
          move.uci: move.share,
    };

    final arrows = <EngineArrow>[];
    var rank = 1;
    for (final move in _kept) {
      if (move.uci.length < 4) continue;
      final share = shares[move.uci];
      final percent = share == null ? '' : _shareText(share);
      arrows.add(EngineArrow(
        from: move.uci.substring(0, 2),
        to: move.uci.substring(2, 4),
        evalText:
            move.isPrimary ? (percent.isEmpty ? '★' : '★ $percent') : percent,
        rank: rank,
      ));
      rank += 1;
    }
    return arrows;
  }

  /// One arrow per engine line, carrying that line's evaluation.
  ///
  /// Only for the position on the board: lines from the previous one would
  /// point at pieces that have moved.
  List<EngineArrow> _engineArrows() {
    if (_linesFen != _current) return const [];
    final arrows = <EngineArrow>[];
    for (var i = 0; i < _lines.length && i < _analysisLines; i++) {
      final line = _lines[i];
      if (line.fromSquare.isEmpty || line.toSquare.isEmpty) continue;
      arrows.add(EngineArrow(
        from: line.fromSquare,
        to: line.toSquare,
        evalText: line.evaluation,
        rank: i + 1,
      ));
    }
    return arrows;
  }

  /// A dial moved: remember it and ask again about this position.
  Future<void> _applyAnalysisDials({int? depth, int? lines}) async {
    setState(() {
      if (depth != null) _analysisDepth = depth;
      if (lines != null) _analysisLines = lines;
    });
    if (depth != null) {
      await AppSettingsService.instance.setAnalysisDepth(depth);
    }
    if (lines != null) {
      await AppSettingsService.instance.setAnalysisLines(lines);
    }
    if (!mounted) return;
    // Asked again at once. Leaving the old lines up under a new depth reads as
    // an engine that stopped working — which is exactly how it was reported.
    await _askEngine();
  }

  Future<void> _askEngine() async {
    final fen = _current;
    if (fen == null || _thinking) return;

    setState(() {
      _thinking = true;
      _lines = const [];
      _linesFen = null;
    });

    final run = widget.analyse ??
        (String f, int depth, int multiPV) async {
          final engine = StockfishService();
          await engine.initEngine();
          return engine.analyzePositionSync(
            f,
            depth: depth,
            multiPV: multiPV,
            // A deep search takes a while, and a panel that says nothing until
            // it finishes is indistinguishable from an engine that is not
            // answering. The lines are shown as they come and simply get
            // better; the depth beside each one says how much to trust it.
            timeout: Duration(seconds: 5 + depth),
            onProgress: (partial) {
              if (!mounted || _current != f) return;
              setState(() {
                _lines = partial;
                _linesFen = f;
              });
            },
          );
        };

    List<AnalysisLine> lines;
    try {
      lines = await run(fen, _analysisDepth, _analysisLines);
    } catch (e) {
      lines = const [];
    }
    if (!mounted) return;

    // Asked about one position, answered about that one. A reader who moved on
    // while the engine was thinking gets no opinion rather than the wrong one.
    if (_current != fen) return;

    setState(() {
      _thinking = false;
      _lines = lines;
      _linesFen = fen;
      // Silence from the engine is said out loud rather than looking like a
      // position it had no opinion about.
      _note = lines.isEmpty ? 'Motor nije odgovorio na vreme.' : null;
    });
  }

  /// Plays the engine's move as the reader's own proposal, so it goes through
  /// the same judging and the same decision as a move played by hand. A
  /// suggestion is not a decision.
  void _playLine(AnalysisLine line) {
    if (line.fromSquare.isEmpty || line.toSquare.isEmpty) return;
    // The engine's LAN carries the promotion as a fifth character when there is
    // one — `d7d8q`. Read from there rather than defaulted, because an engine
    // that says `d8n` means it.
    final lan = line.bestMoveLan;
    final promotion = lan.length > 4 ? lan[4].toLowerCase() : '';
    _onMove(line.fromSquare, line.toSquare, promotion);
  }

  /// Opens the opponent's side of every move kept here, then moves on.
  Future<void> _openReplies() async {
    final kept = _kept;
    final node = _node;
    if (node == null || kept.isEmpty) return;

    setState(() => _busy = true);
    var added = 0;
    var coveredSum = 0.0;
    var tailMoves = 0;
    var counted = 0;
    OpponentReplies? shown;
    String? shownFen;
    String? shownSan;

    for (final move in kept) {
      final after = _fenAfter(node.fen, move.uci);
      if (after == null) continue;
      final lookup = await _judge.replies(after, minRating: widget.minRating);
      if (!mounted) return;
      _asked += 1;
      final replies = lookup.replies;
      if (replies == null) continue;
      counted += 1;
      // The first kept move is the primary — the server hands them back that
      // way — so this is the line the student actually plays, and its answers
      // are the ones worth putting on the board. The alternates are opened all
      // the same; they are simply not what the board is showing.
      if (shown == null) {
        shown = replies;
        shownFen = after;
        shownSan = move.san;
      }
      coveredSum += replies.coveredShare;
      tailMoves += replies.tailMoves;
      for (final reply in replies.replies) {
        final next = _fenAfter(after, reply.uci);
        if (next != null) {
          final before = _queue.length;
          // Two moves further from the root than the position we are standing
          // on: the student's own, and the opponent's answer to it.
          //
          // The reach is this position's, multiplied by how often the opponent
          // plays that reply — and only by that. The student's own move does
          // not divide it: which of their moves they play is a decision, not a
          // coin. Same arithmetic as the server's, so the queue built here and
          // the queue derived tomorrow are the same queue.
          _enqueue(
            next,
            [...node.path, move.san, reply.san],
            reach: node.reach * reply.share,
          );
          if (_queue.length > before) added += 1;
        }
      }
    }

    final covered = counted == 0 ? 0 : (coveredSum / counted * 100).round();
    setState(() {
      _busy = false;
      _answers = shown;
      _answersFen = shownFen;
      _answersSan = shownSan;
      _note = counted == 0
          ? 'Nijedan odgovor nije stigao — pozicija ostaje nepokrivena.'
          : 'Dodato $added ${added == 1 ? "pozicija" : "pozicija"}. '
              'Pokriveno $covered% onoga što ćete sresti; '
              'van toga još $tailMoves ${tailMoves == 1 ? "potez" : "poteza"}.';
    });

    // A stop, not a step. These answers cost a Lichess request and they decide
    // what the whole next wave looks like; walking straight past them is how
    // the student ended up building a tree whose shape nobody had seen.
    // A wave of replies is new branches, so the picture moved too.
    await _loadTree();
    if (shownFen == null) {
      await _advance();
      return;
    }
    _boardController.loadFen(shownFen);
  }

  String? _fenAfter(String fen, String uci) {
    final board = chess.Chess.fromFEN(fen);
    final ok = board.move({
      'from': uci.substring(0, 2),
      'to': uci.substring(2, 4),
      if (uci.length > 4) 'promotion': uci.substring(4, 5),
    });
    return ok == false ? null : board.fen;
  }

  /// "I am not preparing this branch."
  ///
  /// The only control in this loop that makes the tree *smaller*. Every other
  /// one adds: each wave of replies multiplies the queue, and a repertoire that
  /// answers every sideline is one nobody finishes. Without it the only way to
  /// say this is to close the screen, which says it for one session and then
  /// forgets — and the same dead line is back tomorrow, on every device.
  ///
  /// Everything below the cut leaves the queue with it. A cut that left the
  /// positions underneath it would make the tree exactly as big as it was,
  /// which is how a control teaches people not to press it.
  ///
  /// The moves kept here are left alone, deliberately. Cutting says how far to
  /// prepare, not what to forget, and the drill goes on asking for them.
  Future<void> _cutBranch() async {
    final node = _node;
    if (node == null || _busy) return;

    setState(() => _busy = true);
    final done = await _api.skipNode(color: widget.color, fen: node.fen);
    if (!mounted) return;
    if (!done) {
      setState(() {
        _busy = false;
        _note = 'Grana nije odsečena — server nije odgovorio.';
      });
      return;
    }

    // Everything below it goes too. A queued position is below this one exactly
    // when its line starts with this line — the same test the server makes by
    // simply not walking past a cut node.
    final below = _queue.where((p) => _isBelow(p, node)).toList();
    for (final gone in below) {
      _queue.remove(gone);
      // Out of `_seen` as well, not only out of the queue. One of these
      // positions may also be reachable down a line that was *not* cut, and a
      // key left behind would keep it out of the queue when it arrives that
      // other way — cutting one branch would then quietly cut a second.
      _seen.remove(_keyOf(gone.fen));
    }

    setState(() {
      _busy = false;
      _cutHere.add(node);
      _lastCut = node;
      _note = below.isEmpty
          ? 'Grana je odsečena. Neće se više javljati.'
          : 'Grana je odsečena — sa njom je iz reda izašlo još '
              '${below.length} ${below.length == 1 ? "pozicija" : "pozicija"}.';
    });
    await _advance();
    await _loadTree();
  }

  /// "Prepare this one too" — one opponent move from past the covered wave.
  ///
  /// The wave stops at 80% of what is played, up to four moves, and names the
  /// remainder. That is a good default and a bad wall: the owner met it on his
  /// first line, with twenty-eight moves left over carrying a sixth of the
  /// games and no way at all to say "that one as well".
  ///
  /// It is written down on the server rather than only queued here, and that is
  /// the whole difference between this and a position the screen shows once.
  /// The frontier follows only covered replies — deliberately, or the queue
  /// would fill with moves nobody enqueued — so a hand-picked one has to be
  /// stored, or closing the screen would lose it.
  Future<void> _prepareReply(
    OpponentReply reply, {
    String? fromFen,
    String? afterSan,
  }) async {
    final from = fromFen ?? _answersFen;
    final san = afterSan ?? _answersSan;
    final node = _node;
    if (from == null || san == null || node == null || _busy) return;

    setState(() => _busy = true);
    final done = await _api.prepareReply(
      color: widget.color,
      fen: from,
      uci: reply.uci,
      san: reply.san,
    );
    if (!mounted) return;
    if (!done) {
      setState(() {
        _busy = false;
        _note = 'Potez nije dodat u pripremu — server nije odgovorio.';
      });
      return;
    }

    final next = _fenAfter(from, reply.uci);
    final before = _queue.length;
    if (next != null) {
      // Ordered by reach like everything else. Choosing it deliberately says it
      // must be prepared, not that it is suddenly common — a move played in one
      // game in twenty waits behind the ones that are not.
      _enqueue(
        next,
        [...node.path, san, reply.san],
        reach: node.reach * reply.share,
      );
    }
    setState(() {
      _busy = false;
      _preparedUcis.add(reply.uci);
      _note = _queue.length > before
          ? 'U pripremi je i ${reply.san}. Vratiće se u red i sutra.'
          : '${reply.san} je već u pripremi.';
    });
    await _loadTree();
  }

  /// Whether a queued position lies under [root] — its line starts with that
  /// one.
  bool _isBelow(_Pending node, _Pending root) {
    if (node.path.length <= root.path.length) return false;
    for (var i = 0; i < root.path.length; i++) {
      if (node.path[i] != root.path[i]) return false;
    }
    return true;
  }

  /// Puts the last cut branch back, and puts the student back on it.
  ///
  /// Cutting has to be as cheap to undo as it is to do, or it stops being a
  /// decision and becomes a risk — and nobody prunes a tree they cannot
  /// unprune. What was below the cut does not come back with it: those
  /// positions are opened again by taking the replies, which is where they came
  /// from in the first place.
  Future<void> _restoreBranch() async {
    final node = _lastCut;
    if (node == null || _busy) return;

    setState(() => _busy = true);
    final done = await _api.unskipNode(color: widget.color, fen: node.fen);
    if (!mounted) return;
    if (!done) {
      setState(() {
        _busy = false;
        _note = 'Grana nije vraćena — server nije odgovorio.';
      });
      return;
    }

    setState(() {
      _busy = false;
      _cutHere.remove(node);
      _lastCut = null;
      _note = 'Grana je vraćena u red.';
      // Back into the queue in its own place, not at the front: it is worth
      // exactly as much as its reach said it was before it was cut.
      _seen.remove(_keyOf(node.fen));
    });
    _enqueue(node.fen, node.path, kind: node.kind, reach: node.reach);
    // Only when there is nothing on the board. Undo returns the branch to the
    // queue, in its own place; it does not shove aside the position the student
    // is in the middle of answering.
    if (_current == null) await _advance();
    await _loadTree();
  }

  /// Builds the trunk from the position on the board.
  ///
  /// The answer to "thirty questions before it looks like an opening". What it
  /// writes is a draft — drawn, walked through, never drilled until confirmed —
  /// and it follows any move already here instead of overwriting it, so running
  /// it again from further down is the same action as starting.
  Future<void> _buildSpine() async {
    final fen = _current;
    if (fen == null || _busy) return;

    final depth = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Napravi kičmu odavde'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              'Upisuje najigraniji potez za obe strane, koliko poteza kažete. '
              'To su predlozi, ne vaše odluke — vežba ih neće pitati dok ih ne '
              'potvrdite. Staje ranije ako linija postane retka.',
              style: AppText.caption.copyWith(color: context.colors.textMuted),
            ),
          ),
          for (final option in const [4, 6, 8, 10, 12])
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(option),
              child: Text('$option poteza'),
            ),
        ],
      ),
    );
    if (depth == null || !mounted) return;

    setState(() {
      _busy = true;
      _note = 'Pravim kičmu — ovo troši $depth do ${depth * 2} upita.';
    });
    final out = await _api.buildSpine(
      color: widget.color,
      rootFen: fen,
      depth: depth,
      minRating: widget.minRating,
    );
    if (!mounted) return;
    final result = out.result;
    if (result == null) {
      setState(() {
        _busy = false;
        _note = out.error ?? 'Kičma nije napravljena.';
      });
      return;
    }

    // The line is built from where the spine *started*, so it is read before
    // the walk is re-read and the board moves on.
    final note = _spineNote(result, from: _node?.path ?? const []);
    setState(() {
      _busy = false;
      _asked += result.path.length;
    });
    // The queue and the picture both changed, and neither costs an allowance.
    await _resume();
    if (!mounted) return;
    // Said *after* the reload, not before it. `_resume` writes its own note
    // when the walk cannot be read, and setting this first meant the one thing
    // the reader had just asked for was the one thing they did not get told.
    setState(() => _note = note);
  }

  /// What the spine did, in one sentence that never claims more than it did.
  String _spineNote(SpineResult result, {required List<String> from}) {
    if (result.path.isEmpty) {
      return 'Ništa nije upisano — već na ovoj poziciji je linija pretanka '
          '(ispod ${result.minGames} partija).';
    }
    final line = numberedLine(
      [...widget.rootPath, ...from, ...result.path],
      from: widget.rootPath.isEmpty ? widget.rootFen : null,
    );
    final wrote = 'Upisano ${result.written} '
        '${result.written == 1 ? "predlog" : "predloga"}';
    final tail = result.ranTheWholeWay
        ? '.'
        : ' — stalo jer je dalje pretanko (${result.games} partija, prag '
            '${result.minGames}).';
    return '$wrote$tail Kičma: $line. Potvrdite ono sa čim se slažete.';
  }

  /// Says yes to a generated move.
  ///
  /// The act the whole draft idea rests on. A move somebody generated is drawn
  /// and walked through and never drilled; this is what turns it into a
  /// decision, and it is deliberately something the student does rather than
  /// something that happens to them.
  Future<void> _confirm(RepertoireMove move) async {
    final fen = _current;
    if (fen == null || _busy) return;
    setState(() => _busy = true);
    final done = await _api.confirmNode(
      color: widget.color,
      fen: fen,
      uci: move.uci,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _note = done ? null : 'Potez nije potvrđen — server nije odgovorio.';
    });
    if (done) {
      await _loadKept();
      await _loadTree();
    }
  }

  Future<void> _makePrimary(RepertoireMove move) async {
    final fen = _current;
    if (fen == null) return;
    await _api.makePrimary(color: widget.color, fen: fen, uci: move.uci);
    await _loadKept();
    await _loadTree();
  }

  /// Removes a move, and takes with it whatever nothing can reach any more.
  ///
  /// The rule as the owner asked for it is "everything behind the old choice
  /// goes". The rule as it has to be built is **unreachable**, not "behind":
  /// the store is a graph, so a position under the move being dropped may also
  /// stand on a line that is still played, and a subtree delete would silently
  /// damage a line nobody touched.
  ///
  /// Drafts go without a word. Decisions are counted and asked about, because
  /// losing an evening's work to a changed second move with no sentence about
  /// it is the kind of thing that happens once and ends trust in a feature.
  Future<void> _remove(RepertoireMove move) async {
    final fen = _current;
    if (fen == null || _busy) return;

    setState(() => _busy = true);
    // Before the removal. Afterwards the question has no answer: the move that
    // reached those positions is gone.
    final orphans = await _api.orphansOfRemoving(
      color: widget.color,
      fen: fen,
      uci: move.uci,
      minRating: widget.minRating,
    );
    await _api.removeMove(color: widget.color, fen: fen, uci: move.uci);
    if (!mounted) return;

    var swept = 0;
    if (orphans != null && orphans.keys.isNotEmpty) {
      if (orphans.drafts > 0) {
        swept += await _api.prune(
          color: widget.color,
          keys: orphans.keys,
          minRating: widget.minRating,
        );
      }
      if (!mounted) return;
      if (orphans.decisions > 0) {
        final also = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ostalo je bez veze'),
            content: Text(
              'Bez tog poteza do ${orphans.decisions} '
              '${orphans.decisions == 1 ? "vašeg poteza" : "vaših poteza"} '
              'više nema kako da se stigne. Obrisati i njih?\n\n'
              'Ako ih ostavite, biće tu ali ih ništa neće dosezati dok ne '
              'napravite put do njih.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Ostavi'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Obriši i njih'),
              ),
            ],
          ),
        );
        if (also == true && mounted) {
          swept += await _api.prune(
            color: widget.color,
            keys: orphans.keys,
            includeDecisions: true,
            minRating: widget.minRating,
          );
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _note = swept == 0
          ? null
          : 'Uklonjeno i $swept ${swept == 1 ? "potez" : "poteza"} do kojih se '
              'više nije moglo stići.';
    });
    await _loadKept();
    await _loadTree();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: Text(widget.name),
        elevation: 0,
        actions: [
          const BoardCoordinatesButton(),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(
              child: Text(
                // Their allowance, so the number is theirs to see.
                'upita: $_asked',
                style: AppText.micro.copyWith(color: context.colors.textMuted),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    // Told apart on purpose. "Still working out where you were" and "there is
    // nothing left to do" look identical if both render the finished screen,
    // and only one of them is good news.
    if (_resuming) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_current == null) return _buildDone();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Where there is room, the tree sits beside the board instead of on
        // another screen. This costs nothing: the board is capped, and on a
        // desktop window the space it does not use was empty.
        final wide = constraints.maxWidth >= Breakpoints.wide;
        if (!wide) {
          return _buildBoardColumn(context, _boardSize(constraints, wide));
        }
        // Wide enough for two: the board and its question on the left, the
        // picture on the right. The left column is the board plus its padding
        // and no more — everything past that belongs to the tree.
        final left = (constraints.maxWidth * 0.42).clamp(420.0, 620.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: left,
              child: _buildBoardColumn(context, _boardSize(constraints, wide)),
            ),
            VerticalDivider(width: 1, color: context.colors.border),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: _buildTree(context),
              ),
            ),
          ],
        );
      },
    );
  }

  /// How big the board may be here.
  ///
  /// Minus the padding, not the raw width: BoardWithCoordinates takes `size` as
  /// the whole thing, gutter included, so handing it the outer width overflows
  /// by exactly the padding — 24 px, invisible in a release build.
  ///
  /// The old ceiling of 420 is a phone number, and on a 1900 px window it left
  /// a phone layout wearing a desktop. Wide, it grows — but never past what the
  /// height allows, or the question below it goes off the bottom, which is the
  /// one thing worse than a small board.
  double _boardSize(BoxConstraints constraints, bool wide) {
    if (!wide) return (constraints.maxWidth - 24).clamp(200.0, 420.0);
    final byWidth = (constraints.maxWidth * 0.42).clamp(420.0, 620.0) - 24;
    final byHeight =
        constraints.maxHeight.isFinite ? constraints.maxHeight - 280 : byWidth;
    final smaller = byWidth < byHeight ? byWidth : byHeight;
    return smaller.clamp(200.0, 560.0);
  }

  /// The tree, drawn by the analysis board's own widget.
  ///
  /// Nothing until the walk has answered; an empty canvas would read as an
  /// empty repertoire, which is the one sentence this screen must not say by
  /// accident.
  Widget _buildTree(BuildContext context) {
    final root = _treeRoot;
    final active = _activeNode;
    if (root == null || active == null) return const SizedBox.shrink();
    return RepertoireTreePanel(
      root: root,
      active: active,
      onSelect: _jumpTo,
      truncatedAt: _tree?.truncated == true ? _tree?.maxPly : null,
    );
  }

  /// The board and everything that belongs to the position standing on it.
  Widget _buildBoardColumn(BuildContext context, double boardSize) {
    final active = _activeNode;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: BoardWithCoordinates(
              size: boardSize,
              orientation: _forWhite ? PlayerColor.white : PlayerColor.black,
              builder: (inner) => ChessBoardWithOverlay(
                controller: _boardController,
                boardOrientation:
                    _forWhite ? PlayerColor.white : PlayerColor.black,
                boardSize: inner,
                // Nothing to play while the answers are up: the board is
                // showing a position it is the opponent's turn in, and a
                // move dragged there would be judged as the student's own.
                isAllowedToMove:
                    !_busy && _proposalUci == null && _answers == null,
                isDrawingMode: false,
                drawingStartSquare: null,
                arrows: const [],
                // The engine's answer, on the board rather than only in a
                // list underneath it: one arrow per line, its evaluation
                // written beside it. Reading a move as "Nxd4" and finding
                // it on the board is work a beginner should not have to do
                // to see what the engine means.
                engineArrows: _boardArrows(),
                onMove: _onMove,
                onSquareTapForDrawing: (_) {},
              ),
            ),
          ),
          // Where you came from, where you are, and what comes next. The
          // part of the tree you need while answering a position, and the
          // only part readable at 360 dp — where the canvas below is one
          // scroll away rather than the thing you read.
          if (active != null) ...[
            const SizedBox(height: AppSpacing.sm),
            RepertoireLineStrip(active: active, onSelect: _jumpTo),
          ],
          const SizedBox(height: AppSpacing.md),
          _buildQuestion(context),
          const SizedBox(height: AppSpacing.sm),
          // One thing at a time. While the opponent's answers are on the
          // board, the verdict, the kept moves, the engine and the book all
          // belong to a position that is no longer the one being shown.
          if (_answers != null) _buildAnswers(context, _answers!),
          if (_answers == null && _proposalSan != null) _buildVerdict(context),
          if (_answers == null && _kept.isNotEmpty) _buildKept(context),
          // One thing at a time: while the wave's answers are up they are the
          // same list, drawn for the board that is showing.
          if (_answers == null) _buildStoredReplies(context),
          // Open once the engine has been asked about *this* position —
          // including when it came back with nothing, because that is
          // exactly when the reader wants the depth dial and another go.
          if (_answers == null && (_thinking || _linesFen == _current))
            _buildEngine(context),
          if (_answers == null && _book != null) _buildBook(context),
          if (_note != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_note!,
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted)),
          ],
          const SizedBox(height: AppSpacing.md),
          _buildControls(context),
          // Narrow: under the controls rather than beside them, and never a
          // navigation away. The panel caps its own height, so it sits in
          // this scroll view without eating the board.
          if (!Breakpoints.isWide(context)) ...[
            const SizedBox(height: AppSpacing.lg),
            _buildTree(context),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestion(BuildContext context) {
    final left = _queue.length;
    final line = _lineText();
    final walk = _frontier;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (line.isNotEmpty) ...[
          // Where this board came from. Without it the screen is a position
          // with no history and a count of an invisible list, which is exactly
          // how it felt to use: the moves were being kept and nothing on screen
          // said which line they belonged to.
          Text(
            line,
            style: AppText.caption.copyWith(color: context.colors.accent),
          ),
          const SizedBox(height: AppSpacing.xxs),
        ],
        Text(
          _answers != null
              ? 'Posle $_answersSan — ovo igra protivnik'
              : (_forWhite ? 'Šta igrate belim?' : 'Šta igrate crnim?'),
          style: AppText.bodyBold.copyWith(color: context.colors.textPrimary),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          left == 0 ? 'Poslednja pozicija u ovom talasu.' : 'Još $left u redu.',
          style: AppText.caption.copyWith(color: context.colors.textMuted),
        ),
        if (_answers == null && _node?.kind == 'unopened') ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Ovde ste već izabrali potez — ostalo je samo da uzmete odgovore.',
            style: AppText.caption.copyWith(color: context.colors.textMuted),
          ),
        ],
        if (walk != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            _progressText(walk),
            style: AppText.micro.copyWith(color: context.colors.textMuted),
          ),
        ],
      ],
    );
  }

  /// How finished the repertoire is, in the one number that cannot flatter it.
  ///
  /// Not "how many positions you have" — a wide, one-move-deep tree scores well
  /// on that and loses games. This is the share of games arriving in the
  /// repertoire that run into a position with no answer yet, which starts at
  /// 100% and only falls when something the student will actually meet gets an
  /// answer.
  String _progressText(RepertoireFrontier walk) {
    final open = (walk.openReach * 100).clamp(0, 100).round();
    final parts = <String>[
      'odlučeno ${walk.decided}',
      'otvoreno ${walk.open.length}',
      'bez odgovora $open%',
      if (walk.draft > 0) 'nacrt ${walk.draft}',
    ];
    // Cut branches are counted apart and never taken off "bez odgovora".
    // Cutting makes that number fall without a single question having been
    // answered, so the share of games that run into a cut line is said out
    // loud beside it — those games are still going to be played.
    final cut = walk.pruned.length + _cutHere.length;
    if (cut > 0) {
      final reach = walk.prunedReach +
          _cutHere.fold<double>(0, (sum, node) => sum + node.reach);
      final percent = (reach * 100).clamp(0, 100).round();
      parts.add('odsečeno $cut${percent > 0 ? " ($percent%)" : ""}');
    }
    if (walk.truncated) parts.add('pregled skraćen');
    return parts.join(' · ');
  }

  Widget _buildVerdict(BuildContext context) {
    // The same panel the analysis board uses, so a verdict is worded in one
    // place and cannot come to mean two different things.
    return OpeningJudgePanelWidget(
      hasToken: _judge.hasPersonalToken,
      moveSan: _proposalSan,
      isLoading: _busy,
      judgement: _verdict,
      reason: _verdictReason,
    );
  }

  /// The moves kept here, and which of them is the main one.
  ///
  /// Rows rather than chips, and a line that says what the star means: the
  /// choice was always there — tapping a chip promoted it — but nothing on
  /// screen said so, and a control nobody can see is a control that does not
  /// exist. The main move is what the drill will ask for; the rest are yours
  /// and are accepted, with a word saying which one you settled on.
  Widget _buildKept(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Vaši potezi ovde',
              style: AppText.bodyBold.copyWith(color: context.colors.accent)),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            _kept.length == 1
                ? 'Zvezdica je glavni potez — to će drill tražiti od vas.'
                : 'Zvezdica je glavni potez — to će drill tražiti od vas. '
                    'Dodirnite drugi potez da on postane glavni.',
            style: AppText.micro.copyWith(color: context.colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final move in _kept)
            InkWell(
              onTap: move.isPrimary || _busy ? null : () => _makePrimary(move),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(
                      move.isPrimary ? Icons.star : Icons.star_border,
                      size: 18,
                      color: move.isPrimary
                          ? context.colors.accent
                          : context.colors.textMuted,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(move.san,
                        style:
                            (move.isPrimary ? AppText.bodyBold : AppText.body)
                                .copyWith(color: context.colors.textPrimary)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        move.isDraft
                            ? 'predlog — nije još vaš izbor'
                            : (move.isPrimary
                                ? 'glavni'
                                : 'dodirnite za glavni'),
                        style: AppText.micro.copyWith(
                          color: move.isDraft
                              ? context.colors.warning
                              : context.colors.textMuted,
                        ),
                      ),
                    ),
                    // Saying yes is an act. Until it happens the drill leaves
                    // this move alone, which is what makes offering generated
                    // moves safe at all.
                    if (move.isDraft)
                      TextButton(
                        onPressed: _busy ? null : () => _confirm(move),
                        child: const Text('Potvrdi'),
                      ),
                    IconButton(
                      tooltip: 'Ukloni',
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: _busy ? null : () => _remove(move),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// What the opponent answers the main move with — beside the board, always.
  ///
  /// Drawn from the stored book, so it costs nothing and can simply sit there.
  /// It is also the one list that decides what the next wave looks like, which
  /// is why it stopped being something you only get after pressing `Dalje`.
  ///
  /// Every row leads somewhere: a reply already in the preparation takes the
  /// board there, and one from past the cut offers to prepare it.
  Widget _buildStoredReplies(BuildContext context) {
    final book = _stored;
    final after = _storedFor;
    final primary = _kept.isEmpty ? null : _kept.first;
    if (book == null || after == null || primary == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.5),
        borderRadius: AppRadii.roundedSm,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alt_route, size: 16, color: context.colors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Posle ${primary.san} — šta igra protivnik',
                    style: AppText.bodyBold
                        .copyWith(color: context.colors.accent)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            book.opened
                ? 'Iz sačuvane knjige — ne troši upit.'
                : 'Ovu poziciju još niko nije otvarao.',
            style: AppText.micro.copyWith(color: context.colors.textMuted),
          ),
          if (!book.opened)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _openStoredBook,
                icon: const Icon(Icons.menu_book, size: 18),
                label: const Text('Otvori knjigu (1 upit)'),
              ),
            )
          else
            for (final reply in book.replies)
              _storedRow(context, reply, after: after, mine: primary.san),
        ],
      ),
    );
  }

  Widget _storedRow(BuildContext context, StoredReply reply,
      {required String after, required String mine}) {
    final node = _node;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(reply.san,
                style:
                    AppText.body.copyWith(color: context.colors.textPrimary)),
          ),
          SizedBox(
            width: 52,
            child: Text(_shareText(reply.share),
                style:
                    (reply.isInPreparation ? AppText.bodyBold : AppText.caption)
                        .copyWith(color: context.colors.textPrimary)),
          ),
          Expanded(
            child: Text('${reply.games} partija',
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted)),
          ),
          if (reply.isInPreparation)
            TextButton(
              // Already prepared, so the useful thing is to go and work on it.
              onPressed: _busy || node == null
                  ? null
                  : () {
                      final landed = _fenAfter(after, reply.uci);
                      if (landed == null) return;
                      _show(_Pending(
                        fen: landed,
                        path: [...node.path, mine, reply.san],
                      ));
                    },
              child: const Text('Idi'),
            )
          else
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _prepareReply(
                        OpponentReply(
                          uci: reply.uci,
                          san: reply.san,
                          games: reply.games,
                          share: reply.share,
                        ),
                        fromFen: after,
                        afterSan: mine,
                      ),
              child: const Text('Spremi'),
            ),
        ],
      ),
    );
  }

  /// What is played here, as a list to choose from.
  ///
  /// Popularity alone cannot answer "is there a better move", so every row
  /// carries the score from the side to move as well — how those games ended,
  /// which is history and not an evaluation, and it says so. Kept moves wear
  /// their star here too, and the move just proposed is marked, so the
  /// comparison is with the thing actually being decided.
  /// The opponent's answers, in words, beside the same arrows on the board.
  ///
  /// The board says *where*; this says *how often*, and names the part that was
  /// left out. The tail is the point of printing it at all: "four moves
  /// covered, 86% of what you will meet" is honest, and "prepared" without the
  /// remainder is the sentence that lets somebody think a repertoire is
  /// finished when it is not.
  Widget _buildAnswers(BuildContext context, OpponentReplies answers) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.5),
        borderRadius: AppRadii.roundedSm,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alt_route, size: 16, color: context.colors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Odgovori protivnika',
                    style: AppText.bodyBold
                        .copyWith(color: context.colors.accent)),
              ),
              Text('${answers.total} partija',
                  style:
                      AppText.micro.copyWith(color: context.colors.textMuted)),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Broj uz strelicu je koliko se često taj potez igra — to odlučuje '
            'da li morate da ga spremite. Drugi procenat je kako su te partije '
            'prošle po vas.',
            style: AppText.micro.copyWith(color: context.colors.textMuted),
          ),
          const SizedBox(height: 6),
          if (answers.replies.isEmpty)
            Text('Nijedan odgovor nije stigao iz baze.',
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted))
          else
            for (final reply in answers.replies) _answerRow(context, reply),
          if (answers.tailMoves > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Van pripreme još ${answers.tailMoves} '
              '${answers.tailMoves == 1 ? "potez" : "poteza"} — '
              '${(answers.tailShare * 100).round()}% partija. Njih ćete sresti '
              'bez spremljenog odgovora.',
              style: AppText.caption.copyWith(color: context.colors.warning),
            ),
            // The way through the wall. Folded away rather than always open:
            // ten moves at one per cent each under every position would bury
            // the answers that decide the shape of the next wave.
            if (_tailOf(answers).isNotEmpty)
              TextButton.icon(
                onPressed:
                    _busy ? null : () => setState(() => _showTail = !_showTail),
                icon: Icon(_showTail ? Icons.expand_less : Icons.expand_more,
                    size: 18),
                label: Text(_showTail
                    ? 'Sakrij ostale poteze'
                    : 'Spremi i neki od njih'),
              ),
            if (_showTail)
              for (final reply in _tailOf(answers)) _tailRow(context, reply),
          ],
        ],
      ),
    );
  }

  /// The opponent's moves the wave left outside, most played first.
  ///
  /// Out of what the book already returned — no request is made for this. The
  /// book keeps a dozen moves and the rest of a long tail is a fraction of a
  /// per cent each, which is not a decision anybody needs offered to them.
  List<OpponentReply> _tailOf(OpponentReplies answers) {
    // Both tests, and on purpose. `covered` is the flag the server sets while
    // it applies the rule, and the covered list is what it applied the rule to;
    // an answer missing one of the two still comes out right, and a move that
    // is already being prepared never appears as something to add.
    final covered = {for (final reply in answers.replies) reply.uci};
    return [
      for (final reply in answers.all)
        if (!reply.covered && !covered.contains(reply.uci)) reply,
    ];
  }

  Widget _tailRow(BuildContext context, OpponentReply reply) {
    final prepared = _preparedUcis.contains(reply.uci);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(reply.san,
                style:
                    AppText.body.copyWith(color: context.colors.textPrimary)),
          ),
          SizedBox(
            width: 52,
            child: Text(_shareText(reply.share),
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted)),
          ),
          Expanded(
            child: Text('${reply.games} partija',
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted)),
          ),
          if (prepared)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check, size: 16, color: context.colors.success),
                const SizedBox(width: 4),
                Text('u pripremi',
                    style: AppText.micro
                        .copyWith(color: context.colors.textMuted)),
              ],
            )
          else
            OutlinedButton(
              onPressed: _busy ? null : () => _prepareReply(reply),
              child: const Text('Spremi'),
            ),
        ],
      ),
    );
  }

  Widget _answerRow(BuildContext context, OpponentReply reply) {
    final score = reply.scoreFor(white_: _forWhite);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(reply.san,
                style:
                    AppText.body.copyWith(color: context.colors.textPrimary)),
          ),
          SizedBox(
            width: 52,
            child: Text(_shareText(reply.share),
                style: AppText.bodyBold
                    .copyWith(color: context.colors.textPrimary)),
          ),
          Expanded(
            child: Text(
              '${score.round()}% po vas · ${reply.games} partija',
              style: AppText.caption.copyWith(color: context.colors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBook(BuildContext context) {
    final book = _book!;
    final moves = book.all.isNotEmpty ? book.all : book.replies;
    final kept = {for (final move in _kept) move.uci};

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.5),
        borderRadius: AppRadii.roundedSm,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book, size: 16, color: context.colors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Šta se ovde igra',
                    style: AppText.bodyBold
                        .copyWith(color: context.colors.accent)),
              ),
              Text('${book.total} partija',
                  style:
                      AppText.micro.copyWith(color: context.colors.textMuted)),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Drugi procenat je koliko su te partije donele strani na potezu — '
            'kako je prošlo, ne koliko je dobro.',
            style: AppText.micro.copyWith(color: context.colors.textMuted),
          ),
          const SizedBox(height: 6),
          if (moves.isEmpty)
            Text('Nijedna partija iz baze ne prolazi kroz ovu poziciju.',
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted))
          else
            for (final reply in moves)
              _bookRow(context, reply, kept.contains(reply.uci)),
          if (_proposalUci != null &&
              moves.isNotEmpty &&
              !moves.any((m) => m.uci == _proposalUci))
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '$_proposalSan nije među ovim potezima — ovde se retko igra.',
                style: AppText.caption.copyWith(color: context.colors.warning),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bookRow(BuildContext context, OpponentReply reply, bool isKept) {
    final mine = reply.uci == _proposalUci;
    final score = reply.scoreFor(white_: _forWhite);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: isKept
                ? Icon(Icons.star, size: 14, color: context.colors.accent)
                : (mine
                    ? Icon(Icons.arrow_right,
                        size: 16, color: context.colors.textPrimary)
                    : const SizedBox.shrink()),
          ),
          SizedBox(
            width: 64,
            child: Text(
              reply.san,
              style: (mine ? AppText.bodyBold : AppText.body).copyWith(
                color: mine
                    ? context.colors.textPrimary
                    : context.colors.textSecondary,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text('${(reply.share * 100).round()}%',
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted)),
          ),
          Expanded(
            child: Text(
              '${score.round()}% za ${_forWhite ? "belog" : "crnog"}',
              style:
                  AppText.caption.copyWith(color: context.colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    // Wrap and not Row: four Serbian labels do not fit a 360 dp phone, and a
    // release build clips the overflow without drawing a stripe.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        if (_answers != null) ...[
          FilledButton.icon(
            onPressed: _busy ? null : _advance,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Sledeća pozicija'),
          ),
        ] else if (_proposalSan != null) ...[
          FilledButton.icon(
            onPressed: _busy ? null : _keep,
            icon: const Icon(Icons.playlist_add, size: 18),
            label: Text('Uzmi $_proposalSan'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _discard,
            icon: const Icon(Icons.undo, size: 18),
            label: const Text('Odbaci'),
          ),
        ] else ...[
          OutlinedButton.icon(
            // Before deciding, this is a confession and is written down as one.
            // After a move is played the same list arrives by itself and costs
            // the student nothing in the schedule.
            onPressed: _busy || _book != null ? null : _showBook,
            icon: const Icon(Icons.menu_book, size: 18),
            label: const Text('Ne znam'),
          ),
          OutlinedButton.icon(
            onPressed: _busy || _thinking ? null : _askEngine,
            icon: const Icon(Icons.psychology_outlined, size: 18),
            label: const Text('Pitaj motor'),
          ),
          FilledButton.icon(
            onPressed: _busy || _kept.isEmpty ? null : _openReplies,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('Dalje'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _advance,
            icon: const Icon(Icons.skip_next, size: 18),
            label: const Text('Preskoči'),
          ),
          // Told apart from "Preskoči" on purpose, and the labels have to carry
          // the difference: skipping puts the position at the back of the same
          // queue, cutting takes it and everything under it out of the walk for
          // good — until it is put back.
          //
          // Never offered on the repertoire's own root. Cutting that is not
          // pruning, it is deleting the repertoire from inside the screen that
          // builds it, and it is the one cut that leaves no way back in.
          if (_node != null && _node!.path.isNotEmpty)
            OutlinedButton.icon(
              onPressed: _busy ? null : _cutBranch,
              icon: const Icon(Icons.content_cut, size: 18),
              label: const Text('Ne spremam ovo'),
            ),
          // The branch in front of the student, practised on its own. This is
          // where it belongs: the ten positions just built are what somebody
          // sits down to drill, and from the list screen the whole repertoire
          // is the only thing that can be asked for.
          // The trunk, from wherever the board is standing. Offered on every
          // position rather than only at the root, because "continue from here"
          // and "start here" are the same action.
          OutlinedButton.icon(
            onPressed: _busy ? null : _buildSpine,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Napravi kičmu'),
          ),
          if (widget.onDrillHere != null && _node != null)
            OutlinedButton.icon(
              onPressed: _busy ? null : () => widget.onDrillHere!(_node!.fen),
              icon: const Icon(Icons.fitness_center, size: 18),
              label: const Text('Vežbaj ovu granu'),
            ),
        ],
        if (_lastCut != null && _answers == null && _proposalSan == null)
          TextButton.icon(
            onPressed: _busy ? null : _restoreBranch,
            icon: const Icon(Icons.undo, size: 18),
            label: const Text('Vrati odsečenu granu'),
          ),
      ],
    );
  }

  /// The engine's lines, and the two dials that decide what it answers.
  ///
  /// Depth and the number of lines sit here rather than in Settings because
  /// this is where the question is asked — and they *are* the settings, the
  /// same ones the analysis board uses, so changing them here changes them
  /// everywhere rather than making a second copy nobody can find.
  Widget _buildEngine(BuildContext context) {
    final settings = AppSettingsService.instance;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.5),
        borderRadius: AppRadii.roundedSm,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_outlined,
                  size: 16, color: context.colors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Motor',
                    style: AppText.bodyBold
                        .copyWith(color: context.colors.accent)),
              ),
              if (_thinking)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: context.colors.accent),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Lokalni motor — ne troši Lichess kvotu. Ocena je iz ugla belog.',
            style: AppText.micro.copyWith(color: context.colors.textMuted),
          ),
          const SizedBox(height: 6),
          EngineAnalysisDials(
            depth: _analysisDepth,
            lines: _analysisLines,
            enabled: !_thinking,
            onRestart: _askEngine,
            onDepthChanged: (value) => _applyAnalysisDials(depth: value),
            onLinesChanged: (value) => _applyAnalysisDials(lines: value),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final line in (_linesFen == _current ? _lines : const []))
            InkWell(
              onTap:
                  _busy || _proposalUci != null ? null : () => _playLine(line),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(line.evaluation,
                          style: AppText.bodyBold
                              .copyWith(color: context.colors.textPrimary)),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(line.bestMoveSan,
                          style: AppText.body
                              .copyWith(color: context.colors.textPrimary)),
                    ),
                    Expanded(
                      child: Text(
                        line.continuationSan,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption
                            .copyWith(color: context.colors.textMuted),
                      ),
                    ),
                    if (line.depth > 0)
                      Text('d${line.depth}',
                          style: AppText.micro
                              .copyWith(color: context.colors.textMuted)),
                  ],
                ),
              ),
            ),
          if (_lines.isNotEmpty &&
              _linesFen == _current &&
              _proposalUci == null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text('Dodirnite liniju da odigrate njen prvi potez.',
                  style:
                      AppText.micro.copyWith(color: context.colors.textMuted)),
            ),
        ],
      ),
    );
  }

  Widget _engineDial(
    BuildContext context, {
    required String label,
    required int value,
    required List<int> values,
    required Future<void> Function(int) onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ',
            style: AppText.micro.copyWith(color: context.colors.textMuted)),
        DropdownButton<int>(
          value: values.contains(value) ? value : values.first,
          isDense: true,
          underline: const SizedBox.shrink(),
          style: AppText.caption.copyWith(color: context.colors.textPrimary),
          items: [
            for (final option in values)
              DropdownMenuItem(value: option, child: Text('$option')),
          ],
          onChanged: _thinking
              ? null
              : (picked) {
                  if (picked != null) onChanged(picked);
                },
        ),
      ],
    );
  }

  Widget _buildDone() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 40),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Nema više pozicija u redu.',
              style: AppText.bodyBold,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Sve što ste izabrali je sačuvano. Sledeći talas se otvara kad se '
              'vratite na neku od pozicija i uzmete još odgovora.',
              style: AppText.caption.copyWith(color: context.colors.textMuted),
              textAlign: TextAlign.center,
            ),
            // What the last wave covered, said here too. Emptying the queue is
            // exactly when the number matters most, and it used to vanish with
            // the position it was written under.
            if (_note != null) ...[
              const SizedBox(height: 10),
              Text(
                _note!,
                style: AppText.caption.copyWith(color: context.colors.accent),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            // Here as well as in the controls, because a cut is exactly what
            // can empty the queue — and an undo that disappears with the last
            // position is an undo nobody can reach when they need it.
            if (_lastCut != null)
              TextButton.icon(
                onPressed: _busy ? null : _restoreBranch,
                icon: const Icon(Icons.undo, size: 18),
                label: const Text('Vrati odsečenu granu'),
              ),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Nazad'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One position waiting for an answer, and the way it was reached.
///
/// The path is the whole reason this type exists. A queue of bare FENs cannot
/// tell anybody where they are, and "where am I in this tree" was the first
/// thing the screen was asked for and could not do.
class _Pending {
  const _Pending({
    required this.fen,
    required this.path,
    this.kind = 'undecided',
    this.reach = 0,
  });

  final String fen;

  /// SAN from the repertoire's root to here. Joined with the repertoire's own
  /// root path to read from move one.
  final List<String> path;

  /// `undecided` — nothing kept here yet.
  /// `unopened` — kept, but the opponent's replies were never taken, so this
  /// came back not to be answered again but to be opened.
  final String kind;

  /// How often a game played down this repertoire actually arrives here — the
  /// product of the opponent's shares along the path. It is the queue's order,
  /// and it is the same number the server sorts by, so a session's order and a
  /// resumed walk's order are one order.
  final double reach;
}
