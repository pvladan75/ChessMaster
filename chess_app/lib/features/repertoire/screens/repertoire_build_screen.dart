import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/core/models/move_cursor.dart';
import 'package:chess_app/core/services/eval_parsing.dart';
import 'package:chess_app/features/analysis_studio/services/opening_explorer_service.dart';
import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/opening_explorer_panel_widget.dart';
import 'package:chess_app/features/analysis_studio/widgets/opening_judge_panel_widget.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node_cursor.dart';
import 'package:chess_app/features/repertoire/line_text.dart';
import 'package:chess_app/features/repertoire/widgets/fork_repertoire_dialog.dart';
import 'package:chess_app/features/repertoire/widgets/repertoire_comment_panel.dart';
import 'package:chess_app/features/repertoire/widgets/repertoire_gate_picker.dart';
import 'package:chess_app/features/repertoire/widgets/repertoire_position_ask.dart';
import 'package:chess_app/features/analysis_studio/widgets/visual_move_tree_widget.dart';
import 'package:chess_app/features/repertoire/widgets/repertoire_tree_panel.dart';
import 'package:chess_app/features/repertoire/widgets/opening_banner.dart';
import 'package:chess_app/features/analysis_studio/services/opening_book_service.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/breakpoints.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/speakable_info.dart';
import 'package:chess_app/widgets/board_view_menu.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/landscape_board_layout.dart';
import 'package:chess_app/widgets/engine_analysis_dials.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/game_screen/move_keyboard_shortcuts.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';

/// The rule the build screen stands on, said on the screen and in the manual
/// (docs/PLAN-REPERTOAR-RUCNO.md).
///
/// A move nobody entered is a move nobody went through, thought about or
/// internalised, so every entry in the tree is a move played on the board —
/// with the one exception the second sentence names.
const repertoireBuildPrinciple =
    'Every move in your repertoire is one you played on the board. The book '
    'beside it is a reference: when you play a move, only its most played '
    'reply is added for you.';

/// How many moves to enter, in one sentence kept beside the board.
const repertoireBuildAdvice =
    'For your side, prefer one move per position; for the opponent, enter one '
    'or more.';

/// Building a repertoire by playing it on the board.
///
/// Every move played on the board is kept, for either side, the moment it is
/// played. The student's own move brings the book's most played reply with it,
/// so a line is never built against a sideline while the main continuation is
/// missing; every other opponent move is played by hand, by going back to the
/// position and playing it. Nothing is accepted with a button, and a move that
/// is not wanted is deleted from the tree.
///
/// Two rules still hold, and each is a decision rather than an accident:
///
///   * **The first move kept in a position is the primary.** Alternates are
///     welcome, but one move has to be the answer, or the drill has nothing to
///     ask for. The database holds that rule, not this screen.
///   * **Deleting asks first when it would take the student's own work with
///     it.** The store is a graph, and a move deleted can leave positions with
///     nothing leading to them.
/// How deep the picture is asked for, in plies, from where the board is.
///
/// Sixteen is the old default and the floor. Past that it follows the reader:
/// the line they are actually on, plus four moves of room, so a move taken here
/// lands inside the drawing instead of one ply past its edge. Capped at the
/// forty the server allows — more is a 400.
int treeDepthFor(int plyHere) {
  final wanted = plyHere + 8;
  if (wanted < 16) return 16;
  if (wanted > 40) return 40;
  return wanted;
}

class RepertoireBuildScreen extends StatefulWidget {
  const RepertoireBuildScreen({
    super.key,
    required this.name,
    required this.color,
    required this.rootFen,
    this.rootPath = const [],
    this.gateUci,
    this.api,
    this.judge,
    this.analyse,
    this.explore,
    this.onDrillHere,
    this.openingLookup,
    this.id,
  });

  final String name;
  final int? id;

  /// 'w' or 'b' — the side being prepared. The board is turned this way.
  final String color;

  final String rootFen;

  /// How the banner above the board finds an opening's name, injected for the
  /// same reason [api] and [analyse] are: the real `OpeningBookService` loads
  /// through `compute()`, and `compute()` never completes inside
  /// `testWidgets`.
  final OpeningBookEntry? Function(String fen)? openingLookup;

  /// The moves that led to [rootFen], in SAN.
  ///
  /// A repertoire may start anywhere, so without this the breadcrumb would
  /// begin mid-air. Empty for a repertoire built from a pasted position, where
  /// there is no line to tell.
  final List<String> rootPath;

  /// The move this repertoire goes through at its root — its **gate**.
  ///
  /// Two repertoires can start from the same position and mean two different
  /// openings. The moves stay in one graph — a position reached both ways is one
  /// position — and this narrows the **view** to one of them.
  ///
  /// Null is every repertoire with no twin, and behaves exactly as before.
  final String? gateUci;

  /// Injected in tests, which have no server.
  final RepertoireApiService? api;
  final OpeningJudgeService? judge;

  /// What the opening book says about a position — the same service and the
  /// same chips the Analysis board draws. Injected in tests.
  final Future<OpeningExplorerLookup> Function(String fen)? explore;

  /// Called with the position in front of the student, so the screen above can
  /// open the drill over that branch alone.
  final void Function(String fen)? onDrillHere;

  /// Runs the engine on one position and answers with the lines. The local
  /// Stockfish by default — injected in tests, which have no engine binary.
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

  /// Positions still to be answered — after an opponent move the student
  /// entered, with no move of theirs yet — shallower first, each with the way
  /// it was reached.
  final List<_Pending> _queue = [];

  /// Every position that has already been queued, so a transposition does not
  /// come round twice. Keyed the way the server keys them: no move counters.
  final Set<String> _seen = {};

  /// The repertoire as a picture, and the same thing converted for the tree
  /// widget. Re-read whenever the store changes.
  RepertoireTree? _tree;
  AnalysisNode? _treeRoot;

  String? _lastMoveFrom;
  String? _lastMoveTo;

  /// What each drawn card is, by node id, rebuilt with the drawing itself.
  Map<String, MoveTreeNodeLook> _looks = {};

  /// The opening banner's identity, so its `State` — the last opening it could
  /// name — survives moving between the app bar and the board column.
  final GlobalKey _openingKey = GlobalKey();

  /// The drawing's identity, so its zoom and pan survive the tree moving
  /// between its own column and the space under the controls.
  final GlobalKey _treeKey = GlobalKey();

  /// The drawing narrowed to one branch, or null for the whole repertoire.
  String? _viewFrom;

  /// The line from the repertoire's own root down to [_viewFrom].
  List<String> _viewPath = const [];

  /// The position the student is to move in — the one the queue and the kept
  /// moves belong to.
  _Pending? _node;

  String? get _current => _node?.fen;

  /// The walk this screen resumed from, kept for the counts. Null until the
  /// server has answered, and after a server that did not.
  RepertoireFrontier? _frontier;
  bool _resuming = true;

  /// The moves kept in [_current], primary first.
  List<RepertoireMove> _kept = const [];

  /// Set while the board stands after one of the student's own moves, with the
  /// opponent to move. [_node] stays on the position the move was played from.
  ({String uci, String san, String fen})? _standingAfter;

  /// True while the board is one move further on than [_node].
  bool get _afterMyMove => _standingAfter != null;

  /// The position actually on the board.
  String? get _boardFen => _standingAfter?.fen ?? _current;

  /// The book for the position on the board, and the position it belongs to —
  /// a list drawn for the previous board names moves that cannot be played on
  /// this one.
  OpeningExplorerResult? _book;
  String? _bookReason;
  String? _bookFor;

  /// The last move kept and what the judge said about it. Kept across the
  /// board moving on to the reply entered with it, and cleared by anything
  /// else that moves the board.
  String? _verdictSan;
  String? _verdictKey;
  OpeningJudgement? _verdict;
  String? _verdictReason;
  bool _judging = false;

  bool _busy = false;
  String? _note;

  /// The engine's opinion, when it has been asked for one, and the position it
  /// was asked about — an answer that arrives for a board nobody is looking at
  /// is dropped rather than drawn.
  List<AnalysisLine> _lines = const [];
  bool _thinking = false;
  String? _linesFen;

  /// What the engine has already said about the positions in this repertoire.
  Map<String, RepertoireNote> _notes = const {};

  /// What the student wrote about these positions.
  Map<String, RepertoireComment> _comments = const {};

  bool _savingComment = false;
  bool _asking = false;

  bool get _forWhite => widget.color == 'w';

  int _analysisDepth = AppSettingsService.instance.analysisDepth;
  int _analysisLines = AppSettingsService.instance.analysisLines;

  @override
  void initState() {
    super.initState();
    _resume();
  }

  /// Picks the walk back up where it was, rather than starting again.
  ///
  /// A server that does not answer falls back to the root. It has to be the
  /// root and not an empty screen: "we could not find out" must never be shown
  /// as "there is nothing left to do".
  Future<void> _resume() async {
    final walk = await _api.frontier(
      color: widget.color,
      rootFen: widget.rootFen,
      rootPath: widget.rootPath,
      gateUci: widget.gateUci,
    );
    if (!mounted) return;
    if (walk == null) {
      _enqueue(widget.rootFen, const []);
      setState(() {
        _resuming = false;
        _note = 'Could not read your progress — starting from '
            'the repertoire opening position.';
      });
    } else {
      for (final node in walk.open) {
        _enqueue(node.fen, node.path);
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

  void _narrowToHere() {
    final at = _node;
    if (at == null) return;
    setState(() {
      _viewFrom = at.fen;
      _viewPath = List<String>.from(at.path);
    });
    _loadTree();
  }

  void _widenToWhole() {
    if (_viewFrom == null) return;
    setState(() {
      _viewFrom = null;
      _viewPath = const [];
    });
    _loadTree();
  }

  /// True when the board has walked above or outside the narrowed branch.
  bool get _leftTheNarrowing {
    if (_viewFrom == null) return false;
    final path = _node?.path;
    if (path == null) return false;
    if (path.length < _viewPath.length) return true;
    for (var i = 0; i < _viewPath.length; i++) {
      if (path[i] != _viewPath[i]) return true;
    }
    return false;
  }

  int _treeDepth() => treeDepthFor(_node?.path.length ?? 0);

  /// Re-reads the picture, with the notes and comments beside it.
  Future<void> _loadTree() async {
    if (_leftTheNarrowing) {
      _viewFrom = null;
      _viewPath = const [];
    }
    final from = _viewFrom;
    final drawing = _api.repertoireTree(
      color: widget.color,
      rootFen: from ?? widget.rootFen,
      rootPath:
          from == null ? widget.rootPath : [...widget.rootPath, ..._viewPath],
      // The gate belongs to the repertoire, not to this view.
      gateUci: from == null ? widget.gateUci : null,
      maxPly: _treeDepth(),
    );
    final stored = _api.notes(color: widget.color);
    final written = _api.comments(color: widget.color);
    final tree = await drawing;
    final notes = await stored;
    final comments = await written;
    if (!mounted || tree == null) return;
    setState(() {
      _tree = tree;
      _notes = notes;
      _comments = comments;
      _looks = {};
      _treeRoot = repertoireTreeToNodes(tree, looks: _looks);
    });
  }

  RepertoireNote? get _noteHere {
    final fen = _boardFen;
    return fen == null ? null : _notes[_keyOf(fen)];
  }

  /// The position the comment is about: the one **on the board**.
  String? get _commentFen => _boardFen;

  RepertoireComment? get _commentHere {
    final fen = _commentFen;
    return fen == null ? null : _comments[_keyOf(fen)];
  }

  Future<void> _editComment({String? prefill}) async {
    final fen = _commentFen;
    if (fen == null) return;
    final existing = _commentHere?.body ?? '';
    final typed = await showRepertoireCommentEditor(
      context,
      initial: prefill ?? existing,
      line: _lineText(),
      wide: Breakpoints.isWide(context),
    );
    // Closed without saving. An empty string is "clear it" and is a different
    // answer, which is why this is a null check and not an isEmpty one.
    if (typed == null || !mounted) return;
    await _saveComment(fen, typed);
  }

  Future<void> _saveComment(String fen, String body) async {
    setState(() => _savingComment = true);
    final done = await _api.putComment(
      color: widget.color,
      fen: fen,
      body: body,
    );
    if (!mounted) return;
    final key = _keyOf(fen);
    setState(() {
      _savingComment = false;
      final next = {..._comments};
      final stored = done.comment;
      if (stored != null) {
        next[key] = stored;
      } else if (done.saved) {
        next.remove(key);
      }
      _comments = next;
    });
    if (!done.saved) {
      AppFeedback.error(
          context, 'Comment was not saved — server is not responding.');
    }
  }

  Future<void> _deleteComment() async {
    final fen = _commentFen;
    if (fen == null || _commentHere == null) return;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text(
          'Only what you wrote about this position will be deleted. Moves and evaluations '
          'remain.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    setState(() => _savingComment = true);
    final done = await _api.deleteComment(color: widget.color, fen: fen);
    if (!mounted) return;
    setState(() {
      _savingComment = false;
      if (done) {
        final next = {..._comments};
        next.remove(_keyOf(fen));
        _comments = next;
      }
    });
    if (!done) {
      AppFeedback.error(
          context, 'Comment was not deleted — server is not responding.');
    }
  }

  /// Asks the model about the position on the board. It spends the AI
  /// allowance, which is why it is a button and not something the screen does
  /// on arrival.
  Future<void> _askModel() async {
    final fen = _commentFen;
    if (fen == null || _asking) return;
    setState(() => _asking = true);
    final note = _notes[_keyOf(fen)];
    final advice = await askAboutPosition(
      fen: fen,
      evals: {
        if (note != null) 'cp': note.evalCp,
        if (note?.bestUci != null) 'bestMove': note!.bestUci,
        if (note?.bestLineSan != null) 'continuation': note!.bestLineSan,
      },
    );
    if (!mounted) return;
    setState(() => _asking = false);
    if (advice == null) {
      AppFeedback.error(context, 'AI did not respond about this position.');
      return;
    }
    final keep = await showPositionAdviceDialog(context, advice);
    if (keep == null || !mounted) return;
    await _editComment(prefill: keep);
  }

  /// The node the board is standing on, for the tree to highlight.
  AnalysisNode? get _activeNode {
    final root = _treeRoot;
    final fen = _boardFen;
    if (root == null || fen == null) return null;
    // No `?? root`: a highlight thrown to move one while the reader is four
    // moves deep reads as being sent back to the beginning. If the card is not
    // there, the last card stays lit.
    final found = findNodeByFen(root, fen);
    if (found != null) {
      _lastActiveFen = fen;
      return found;
    }
    final back = _lastActiveFen;
    return back == null ? root : (findNodeByFen(root, back) ?? root);
  }

  String? _lastActiveFen;

  /// Takes the board to a position in the tree.
  ///
  /// The opponent's move puts the board on the position after it, where the
  /// student is to move. One of the student's own stands the board after it,
  /// with the opponent to move, so the next opponent move can be played there.
  Future<void> _jumpTo(AnalysisNode node) async {
    if (_isMine(node.fen)) {
      if (node.fen == _current && !_afterMyMove) return;
      await _show(_Pending(
        fen: node.fen,
        path: _pathTo(node),
        lastUci: node.moveUci,
      ));
      return;
    }

    final from = node.parent;
    final uci = node.moveUci;
    final san = node.moveSan;
    if (from == null || uci == null || san == null || !_isMine(from.fen)) {
      return;
    }
    await _standAfter(from, fen: node.fen, uci: uci, san: san);
  }

  Future<void> _standAfter(
    AnalysisNode from, {
    required String fen,
    required String uci,
    required String san,
  }) async {
    if (from.fen != _current) {
      await _show(_Pending(
        fen: from.fen,
        path: _pathTo(from),
        lastUci: from.moveUci,
      ));
      if (!mounted) return;
    }
    await _standAfterMove(fen: fen, uci: uci, san: san);
  }

  /// Puts the board after one of the student's own moves, with the opponent to
  /// move. Everything belonging to the position behind it is cleared.
  Future<void> _standAfterMove({
    required String fen,
    required String uci,
    required String san,
  }) async {
    setState(() {
      _clearVerdict();
      _lines = const [];
      _linesFen = null;
      _lastMoveFrom = uci.substring(0, 2);
      _lastMoveTo = uci.substring(2, 4);
      _standingAfter = (uci: uci, san: san, fen: fen);
    });
    _boardController.loadFen(fen);
    await _loadBook();
  }

  ({AnalysisNode from, String uci, String san})? _moveOf(AnalysisNode node) {
    final from = node.parent;
    final uci = node.moveUci;
    final san = node.moveSan;
    if (from == null || uci == null || san == null) return null;
    return (from: from, uci: uci, san: san);
  }

  /// "Make main move" on a card. Only the student's own moves have a primary.
  Future<void> _promoteFromTree(AnalysisNode node) async {
    final move = _moveOf(node);
    if (move == null || _busy) return;
    if (!_isMine(move.from.fen)) {
      AppFeedback.info(context,
          "That's an opponent move — only your moves can be set as main.");
      return;
    }
    final kept = await _keptAt(move.from);
    if (kept == null) return;
    final mine = kept.where((m) => m.uci == move.uci).firstOrNull;
    if (mine == null) {
      if (!mounted) return;
      AppFeedback.warning(
          context, '${move.san} is no longer in the repertoire.');
      return;
    }
    await _makePrimary(mine);
    if (!mounted) return;
    AppFeedback.success(context, '${move.san} is now your main move.');
  }

  /// „Extract into new opening" from a card — a fork of the position the
  /// student's move is played from, gated on the move itself.
  Future<void> _forkFromTree(AnalysisNode node) async {
    final move = _moveOf(node);
    if (move == null || _busy) return;
    await showDialog(
      context: context,
      builder: (context) => ForkRepertoireDialog(
        color: widget.color,
        rootFen: move.from.fen,
        rootPath: _pathTo(move.from),
        initialViaUci: move.uci,
        api: _api,
      ),
    );
  }

  /// "Delete this move" on a card, for either side.
  Future<void> _deleteFromTree(AnalysisNode node) async {
    final move = _moveOf(node);
    if (move == null || _busy) return;

    if (!_isMine(move.from.fen)) {
      final mine = move.from;
      final before = mine.parent;
      final myUci = mine.moveUci;
      final mySan = mine.moveSan;
      if (before == null || myUci == null || mySan == null) return;
      final removed = await _removeOpponentMove(
          fromFen: move.from.fen, uci: move.uci, san: move.san);
      if (!removed || !mounted) return;
      // Back to where the deleted move was played from: after the student's
      // own move, where another opponent move can be played instead.
      await _standAfter(before, fen: mine.fen, uci: myUci, san: mySan);
      return;
    }

    final kept = await _keptAt(move.from);
    if (kept == null) return;
    final mine = kept.where((m) => m.uci == move.uci).firstOrNull;
    if (mine == null) {
      if (!mounted) return;
      AppFeedback.warning(
          context, '${move.san} is no longer in the repertoire.');
      return;
    }
    await _remove(mine);
  }

  /// Takes the board to the position a card's move is played from, and hands
  /// back what is kept there. Null when the jump did not land.
  Future<List<RepertoireMove>?> _keptAt(AnalysisNode from) async {
    if (from.fen != _current || _standingAfter != null) {
      await _show(_Pending(fen: from.fen, path: _pathTo(from)));
      if (!mounted) return null;
    }
    return _kept;
  }

  /// Whether the student is the one to move here.
  bool _isMine(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    return parts.length >= 2 && parts[1] == widget.color;
  }

  /// The line the board is standing in: the root, everything down to the
  /// board, and then the main line onwards to its end.
  List<AnalysisNode> _lineNodes() {
    final active = _activeNode;
    if (active == null) return const [];
    final line = <AnalysisNode>[];
    AnalysisNode? at = active;
    while (at != null) {
      line.insert(0, at);
      at = at.parent;
    }
    var deepest = active;
    while (deepest.children.isNotEmpty) {
      deepest = deepest.children.first;
      line.add(deepest);
    }
    return line;
  }

  int _lineIndex() {
    final active = _activeNode;
    if (active == null) return 0;
    var above = 0;
    AnalysisNode? at = active.parent;
    while (at != null) {
      above += 1;
      at = at.parent;
    }
    return above;
  }

  /// The one cursor this screen is walked by — the strip's buttons and the
  /// arrow keys read it from here, and selecting goes through the same door a
  /// tap on a card uses.
  MoveCursor _moveCursor() => AnalysisNodeCursor(
        currentNode: _activeNode ?? AnalysisNode(fen: widget.rootFen),
        onSelect: _jumpTo,
      );

  Widget _buildNavigation(BuildContext context) {
    final line = _lineNodes();
    final wrote = _commentHere != null;
    return MoveNavigationControls(
      cursor: _moveCursor(),
      canNavigate: line.length >= 2,
      centerLabel: line.length >= 2
          ? 'Move ${_lineIndex()} of ${line.length - 1}'
          : null,
      iconSize: 20,
      trailing: [
        IconButton(
          icon: Icon(Icons.call_split,
              size: 18, color: context.colors.textSecondary),
          tooltip: 'Extract into new opening',
          onPressed: _activeNode == null ? null : _forkHere,
        ),
        IconButton(
          icon: Icon(
            wrote ? Icons.sticky_note_2 : Icons.sticky_note_2_outlined,
            size: 18,
            color: context.colors.info,
          ),
          tooltip: wrote ? 'Edit comment' : 'Add comment',
          onPressed: _savingComment || _commentFen == null
              ? null
              : () => _editComment(),
        ),
        IconButton(
          icon: _asking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.auto_awesome,
                  size: 18, color: context.colors.accent),
          tooltip: 'Ask AI about position',
          onPressed: _asking || _commentFen == null ? null : _askModel,
        ),
      ],
    );
  }

  Widget _buildComment(BuildContext context, {required bool dense}) {
    if (_commentFen == null) return const SizedBox.shrink();
    return RepertoireCommentPanel(
      body: _commentHere?.body,
      dense: dense,
      busy: _savingComment,
      onEdit: () => _editComment(),
      onDelete: _commentHere == null ? null : _deleteComment,
    );
  }

  Future<void> _forkHere() async {
    final active = _activeNode;
    if (active == null) return;

    await showDialog(
      context: context,
      builder: (context) => ForkRepertoireDialog(
        color: widget.color,
        rootFen: active.fen,
        rootPath: _pathTo(active),
        api: _api,
      ),
    );
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

  String _keyOf(String fen) => fenKeyOf(fen);

  /// Puts a position in the queue: shallower first, and among equals in the
  /// order they arrived — the order the server's walk hands them back in.
  void _enqueue(String fen, List<String> path) {
    final key = _keyOf(fen);
    if (_seen.contains(key)) return;
    _seen.add(key);
    final node = _Pending(fen: fen, path: path);
    var at = 0;
    while (at < _queue.length && _queue[at].path.length <= node.path.length) {
      at += 1;
    }
    _queue.insert(at, node);
  }

  /// Moves to the next position in the queue, or to the "nothing left" state.
  Future<void> _advance() => _show(_queue.isEmpty ? null : _queue.removeAt(0));

  /// Puts the repertoire's own root back on the board.
  Future<void> _openRoot() async {
    _seen.remove(_keyOf(widget.rootFen));
    _enqueue(widget.rootFen, widget.rootPath);
    await _advance();
  }

  void _clearVerdict() {
    _verdictSan = null;
    _verdictKey = null;
    _verdict = null;
    _verdictReason = null;
    _judging = false;
  }

  /// Puts one position on the board, or the finished screen when there is none.
  ///
  /// Everything belonging to the previous position is cleared here, in one
  /// place. A verdict, a book, an engine line that outlived the board it was
  /// about is a bug this screen has met more than once.
  Future<void> _show(_Pending? node) async {
    setState(() {
      _clearVerdict();
      _standingAfter = null;
      _lastMoveFrom =
          node?.lastUci == null ? null : node!.lastUci!.substring(0, 2);
      _lastMoveTo =
          node?.lastUci == null ? null : node!.lastUci!.substring(2, 4);
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
    // The drawing has to contain the position the board is on. Asked only when
    // the card is actually missing, and only when there is a drawing.
    final drawn = _treeRoot;
    if (drawn != null && findNodeByFen(drawn, fen) == null) await _loadTree();
  }

  /// The line that leads to the board, numbered the way a book numbers it.
  String _lineText() {
    final moves = [
      ...widget.rootPath,
      ...?_node?.path,
      if (_standingAfter != null) _standingAfter!.san,
    ];
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
    await _loadBook();
  }

  /// What the opening book says about the position on the board.
  Future<void> _loadBook() async {
    final fen = _boardFen;
    if (fen == null) return;
    final explore = widget.explore;
    final lookup = explore != null
        ? await explore(fen)
        : await OpeningExplorerService.instance.lookup(fen);
    if (!mounted || _boardFen != fen) return;
    setState(() {
      _book = lookup.result;
      _bookReason = lookup.isAvailable ? null : lookup.reason;
      _bookFor = fen;
    });
  }

  /// A chip in the book, played as if it were dragged on the board.
  void _playFromBook(String uci) {
    if (uci.length < 4) return;
    _onMove(uci.substring(0, 2), uci.substring(2, 4),
        uci.length > 4 ? uci.substring(4, 5) : '');
  }

  bool _isPromotion(chess.Chess board, String from, String to) {
    final piece = board.get(from);
    if (piece == null || piece.type != chess.PieceType.PAWN) return false;
    final rank = to.substring(1);
    return rank == '8' || rank == '1';
  }

  /// A move played on the board, for whichever side is to move. It is kept at
  /// once: playing it is the decision.
  Future<void> _onMove(String from, String to, String promotion) async {
    final fen = _boardFen;
    if (fen == null || _busy) return;

    final board = chess.Chess.fromFEN(fen);
    final isPromotion = _isPromotion(board, from, to);
    // The piece the reader picked. A repertoire line is stored as UCI, and
    // 'e8q' and 'e8n' are different lines.
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
    final after = board.fen;

    if (_isMine(fen)) {
      await _playOwnMove(fen: fen, uci: uci, san: san, after: after);
    } else {
      await _playOpponentMove(fen: fen, uci: uci, san: san, after: after);
    }
  }

  /// A move of the student's: kept, and the board goes on — past the book's
  /// top reply when the server entered one, or to the position after the move
  /// when there is none.
  Future<void> _playOwnMove({
    required String fen,
    required String uci,
    required String san,
    required String after,
  }) async {
    final node = _node;
    if (node == null) return;

    // Already in the repertoire: playing it is going to look at what comes
    // after it, not a second decision.
    final already = _kept.where((move) => move.uci == uci).firstOrNull;
    if (already != null) {
      await _standAfterMove(fen: after, uci: uci, san: already.san);
      return;
    }

    setState(() {
      _busy = true;
      _note = null;
    });
    final kept = await _api.keepMove(
      color: widget.color,
      fen: fen,
      uci: uci,
      san: san,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!kept.saved) {
      _boardController.loadFen(fen);
      setState(() => _note = 'Move was not saved — server did not respond.');
      return;
    }

    final top = kept.topReply;
    if (top != null) {
      final landed = _fenAfter(after, top.uci);
      if (landed != null) {
        await _show(_Pending(
          fen: landed,
          path: [...node.path, san, top.san],
          lastUci: top.uci,
        ));
      } else {
        await _standAfterMove(fen: after, uci: uci, san: san);
      }
    } else {
      await _standAfterMove(fen: after, uci: uci, san: san);
    }
    if (!mounted) return;
    setState(() {
      _note = top == null
          ? '$san is in your repertoire. The book has no reply here — play '
              'the opponent move you want to prepare.'
          : '$san is in your repertoire, with the most played reply, '
              '${top.san}.';
    });
    _judgeInBackground(fen: fen, uci: uci, san: san);
    await _loadTree();
    _refreshCounts();
  }

  /// An opponent move: entered, and the board goes to the position after it,
  /// where the student is to move.
  Future<void> _playOpponentMove({
    required String fen,
    required String uci,
    required String san,
    required String after,
  }) async {
    final node = _node;
    final mine = _standingAfter;
    if (node == null || mine == null) return;

    setState(() {
      _busy = true;
      _note = null;
    });
    final entered = await _api.addOpponentMove(
      color: widget.color,
      fen: fen,
      uci: uci,
      san: san,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!entered) {
      _boardController.loadFen(fen);
      setState(() =>
          _note = 'Opponent move was not saved — server did not respond.');
      return;
    }
    await _show(_Pending(
      fen: after,
      path: [...node.path, mine.san, san],
      lastUci: uci,
    ));
    await _loadTree();
    _refreshCounts();
  }

  /// What the judge makes of a move just kept, shown when it arrives and
  /// written on the attempt either way. Not awaited: the board has already
  /// moved on, and a judge that is slow must not hold it.
  Future<void> _judgeInBackground({
    required String fen,
    required String uci,
    required String san,
  }) async {
    final key = '${_keyOf(fen)} $uci';
    setState(() {
      _verdictSan = san;
      _verdictKey = key;
      _verdict = null;
      _verdictReason = null;
      _judging = true;
    });
    final lookup = await _judge.judge(fen, uci);
    if (!mounted) return;
    if (_verdictKey == key) {
      setState(() {
        _judging = false;
        _verdict = lookup.judgement;
        _verdictReason = lookup.reason;
      });
    }
    await _api.recordAttempt(
      color: widget.color,
      fen: fen,
      uci: uci,
      san: san,
      verdict: lookup.judgement?.verdict.name,
      kept: true,
    );
  }

  /// What the board draws, one layer at a time: the book's weight after the
  /// student's move, the engine when it has been asked, and otherwise the moves
  /// already kept.
  List<EngineArrow> _boardArrows() {
    final settings = AppSettingsService.instance;

    if (_afterMyMove) {
      if (settings.showStatisticsArrows) {
        final book = _bookFor == _boardFen ? _book : null;
        final shares = book == null
            ? const <EngineArrow>[]
            : _shareArrows([
                for (final move in book.moves)
                  (
                    uci: move.uci,
                    share: book.total == 0 ? 0.0 : move.total / book.total,
                  ),
              ]);
        if (shares.isNotEmpty) return shares;
      }
      // The book had nothing to say here, which is the position the engine is
      // asked about in the first place. Its lines are about this board.
      if (settings.showEngineArrows) return _engineArrows();
      return const [];
    }

    if (settings.showEngineArrows) {
      final engine = _engineArrows();
      if (engine.isNotEmpty) return engine;
    }

    if (settings.showChosenMoveArrow) return _keptArrows();
    return const [];
  }

  /// A share, as a reader reads it. Below one percent is `<1%` rather than
  /// `0%`, which would say "never played" about a move that was.
  String _shareText(double share) {
    final percent = share * 100;
    if (percent <= 0) return '';
    return percent < 1 ? '<1%' : '${percent.round()}%';
  }

  /// How many book arrows a board can carry before it stops being readable.
  static const _maxBookArrows = 4;

  /// Below this a move is in the book and not on the board.
  static const _minArrowShare = 0.02;

  List<EngineArrow> _shareArrows(List<({String uci, double share})> moves) {
    final worth = [
      for (final move in moves)
        if (move.uci.length >= 4 && move.share >= _minArrowShare) move,
    ]..sort((a, b) => b.share.compareTo(a.share));

    final arrows = <EngineArrow>[];
    var rank = 1;
    for (final move in worth.take(_maxBookArrows)) {
      arrows.add(EngineArrow(
        from: move.uci.substring(0, 2),
        to: move.uci.substring(2, 4),
        evalText: _shareText(move.share),
        rank: rank,
      ));
      rank += 1;
    }
    return arrows;
  }

  /// The moves the student has already decided on here, the primary starred —
  /// which move is the main one must never rest on hue alone.
  List<EngineArrow> _keptArrows() {
    final book = _bookFor == _current ? _book : null;
    final shares = <String, double>{
      if (book != null && book.total > 0)
        for (final move in book.moves) move.uci: move.total / book.total,
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

  List<EngineArrow> _engineArrows() {
    if (_linesFen != _boardFen) return const [];
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
    // an engine that stopped working.
    await _askEngine();
  }

  /// The engine, asked about the position **on the board**.
  ///
  /// The board and not [_node]: after one of the student's own moves the board
  /// stands a ply further on, with the opponent to move, and that is exactly
  /// where the book most often has nothing left to say — so hiding the engine
  /// there took it away at the one moment there was nothing else to go on.
  /// Reported live by the owner, 16.9.2026. The comment panel has followed the
  /// board all along; this now reads the same way.
  Future<void> _askEngine() async {
    final fen = _boardFen;
    if (fen == null || _thinking) return;

    setState(() {
      _thinking = true;
      _lines = const [];
      _linesFen = null;
    });

    List<AnalysisLine> lines;
    try {
      lines = await _analyse(
        fen,
        _analysisDepth,
        _analysisLines,
        onProgress: (partial) {
          if (!mounted || _boardFen != fen) return;
          setState(() {
            _lines = partial;
            _linesFen = fen;
          });
        },
      );
    } catch (e) {
      lines = const [];
    }
    if (!mounted) return;

    // Asked about one position, answered about that one.
    if (_boardFen != fen) return;

    setState(() {
      _thinking = false;
      _lines = lines;
      _linesFen = fen;
      _note = lines.isEmpty ? 'Engine did not respond in time.' : null;
    });

    if (lines.isNotEmpty) await _saveNote(fen, lines.first);
  }

  Future<List<AnalysisLine>> _analyse(
    String fen,
    int depth,
    int multiPV, {
    void Function(List<AnalysisLine> partial)? onProgress,
  }) async {
    final injected = widget.analyse;
    if (injected != null) return injected(fen, depth, multiPV);
    final engine = StockfishService();
    await engine.initEngine();
    return engine.analyzePositionSync(
      fen,
      depth: depth,
      multiPV: multiPV,
      timeout: Duration(seconds: 5 + depth),
      onProgress: onProgress,
    );
  }

  /// The engine's evaluation as two numbers: centipawns, and a mate if it is
  /// one — read through the one parser this app has.
  ({int cp, int? mateIn})? _evalOf(String raw) {
    final pawns = parseWhiteRelativeEval(raw);
    if (pawns == null) return null;
    final cp = (pawns * 100).round();
    final mate = RegExp(r'^\s*(-)?M(\d+)\s*$').firstMatch(raw);
    if (mate == null) return (cp: cp, mateIn: null);
    final moves = int.tryParse(mate.group(2)!) ?? 0;
    if (moves == 0) return (cp: cp, mateIn: null);
    return (cp: cp, mateIn: mate.group(1) != null ? -moves : moves);
  }

  Future<void> _saveNote(String fen, AnalysisLine line) async {
    final parsed = _evalOf(line.evaluation);
    if (parsed == null) return;
    final stored = await _api.putNote(
      color: widget.color,
      fen: fen,
      evalCp: parsed.cp,
      mateIn: parsed.mateIn,
      evalDepth: line.depth,
      bestUci: line.bestMoveLan.isEmpty ? null : line.bestMoveLan,
      bestLineSan: line.continuationSan.isEmpty
          ? line.bestMoveSan
          : line.continuationSan,
    );
    if (!mounted || stored == null) return;
    setState(() => _notes = {..._notes, stored.fenKey: stored});
  }

  /// Plays the engine's move as the reader's own, the same as one played by
  /// hand.
  void _playLine(AnalysisLine line) {
    if (line.fromSquare.isEmpty || line.toSquare.isEmpty) return;
    final lan = line.bestMoveLan;
    final promotion = lan.length > 4 ? lan[4].toLowerCase() : '';
    _onMove(line.fromSquare, line.toSquare, promotion);
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

  /// Re-reads the walk for its numbers and leaves the board where it is. Not
  /// awaited by its callers: nothing on screen has to wait for a count.
  Future<void> _refreshCounts() async {
    final walk = await _api.frontier(
      color: widget.color,
      rootFen: widget.rootFen,
      rootPath: widget.rootPath,
      gateUci: widget.gateUci,
    );
    // A walk that could not be read leaves the old number standing rather than
    // replacing it with a zero nobody measured.
    if (!mounted || walk == null) return;
    setState(() => _frontier = walk);
  }

  Future<void> _makePrimary(RepertoireMove move) async {
    final fen = _current;
    if (fen == null) return;
    await _api.makePrimary(color: widget.color, fen: fen, uci: move.uci);
    await _loadKept();
    await _loadTree();
  }

  /// Asks before a deletion that would take the student's own moves with it.
  ///
  /// True to go ahead. A count that could not be read goes ahead too: the move
  /// itself is what was asked for, and the server still refuses to sweep a
  /// position anything else reaches.
  Future<bool> _confirmStranded(
      String san, ({List<String> keys, int decisions})? orphans) async {
    final decisions = orphans?.decisions ?? 0;
    if (decisions <= 0) return true;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $san?'),
        content: Text(
          'After $san there ${decisions == 1 ? "is 1 move" : "are $decisions moves"} '
          'of yours that nothing else leads to. '
          '${decisions == 1 ? "It" : "They"} will be deleted with it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return sure == true;
  }

  /// Removes a move of the student's from the position on the board, and what
  /// only it reached.
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
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!await _confirmStranded(move.san, orphans) || !mounted) return;

    setState(() => _busy = true);
    await _api.removeMove(color: widget.color, fen: fen, uci: move.uci);
    if (orphans != null && orphans.keys.isNotEmpty) {
      await _api.prune(color: widget.color, keys: orphans.keys);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _loadKept();
    await _loadTree();
    _refreshCounts();
  }

  /// Removes an opponent move the student entered, and what only it reached.
  /// True when it went.
  Future<bool> _removeOpponentMove({
    required String fromFen,
    required String uci,
    required String san,
  }) async {
    if (_busy) return false;
    setState(() => _busy = true);
    final orphans = await _api.orphansOfRemoving(
      color: widget.color,
      fen: fromFen,
      uci: uci,
    );
    if (!mounted) return false;
    setState(() => _busy = false);
    if (!await _confirmStranded(san, orphans) || !mounted) return false;

    setState(() => _busy = true);
    final done = await _api.removeOpponentMove(
      color: widget.color,
      fen: fromFen,
      uci: uci,
    );
    if (done && orphans != null && orphans.keys.isNotEmpty) {
      await _api.prune(color: widget.color, keys: orphans.keys);
    }
    if (!mounted) return false;
    setState(() {
      _busy = false;
      if (!done) {
        _note = 'Opponent move was not removed — server did not respond.';
      }
    });
    if (!done) return false;
    await _loadTree();
    _refreshCounts();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        toolbarHeight: LandscapeBoardLayout.toolbarHeight(context),
        // The opening's name beside the title where there is room for it —
        // `ultraWide`, because at 900 dp the banner and the repertoire's name
        // overflowed the bar.
        title: Breakpoints.isUltraWide(context)
            ? Row(
                children: [
                  Flexible(
                      child: Text(widget.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (_boardFen != null) ...[
                    const SizedBox(width: AppSpacing.md),
                    Flexible(
                      child: OpeningBanner(
                        key: _openingKey,
                        fen: _boardFen!,
                        lookup: widget.openingLookup,
                        bare: true,
                      ),
                    ),
                  ],
                ],
              )
            : Text(widget.name),
        elevation: 0,
        actions: const [
          SpeechToggleButton(),
          BoardViewMenu(arrows: true),
        ],
      ),
      body: MoveKeyboardShortcuts(
        cursor: _moveCursor(),
        onChanged: () {},
        enabled: !_busy,
        child: SafeArea(child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    // Told apart on purpose. "Still working out where you were" and "there is
    // nothing left to do" look identical if both render the finished screen.
    if (_resuming) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_current == null) return _buildDone();

    // Before the width test: a large phone on its side is past `wide`, and the
    // wide layout's board column assumes a desktop's height under the board.
    if (LandscapeBoardLayout.applies(context)) {
      return LandscapeBoardLayout(
        board: _buildBoard,
        panels: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_boardFen != null)
                OpeningBanner(
                  key: _openingKey,
                  fen: _boardFen!,
                  lookup: widget.openingLookup,
                ),
              ..._buildPositionPanels(context, commentBeside: false),
              const SizedBox(height: AppSpacing.lg),
              _buildTree(context),
            ],
          ),
        ),
        footer: [
          _buildNavigation(context),
          _buildControls(context),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= Breakpoints.wide;
        if (!wide) {
          return _buildBoardColumn(context, _boardSize(constraints, wide),
              treeBelow: true);
        }
        final left = (constraints.maxWidth * 0.42).clamp(420.0, 620.0);
        final third = constraints.maxWidth >= Breakpoints.ultraWide;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: left,
              child: _buildBoardColumn(context, _boardSize(constraints, wide),
                  commentBeside: third),
            ),
            VerticalDivider(width: 1, color: context.colors.border),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: _buildTree(context),
              ),
            ),
            if (third) ...[
              VerticalDivider(width: 1, color: context.colors.border),
              SizedBox(
                width: 320,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _buildComment(context, dense: false),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// How much of the window's height the board may take, on any layout, so
  /// something of what is under it still fits on a short screen.
  static const double _boardShare = 0.50;

  double _boardSize(BoxConstraints constraints, bool wide) {
    if (!wide) {
      final byWidth = (constraints.maxWidth - 24).clamp(200.0, 420.0);
      if (!constraints.maxHeight.isFinite) return byWidth;
      final byHeight = constraints.maxHeight * _boardShare;
      return byHeight < byWidth ? byHeight.clamp(200.0, 420.0) : byWidth;
    }
    final byWidth = (constraints.maxWidth * 0.42).clamp(420.0, 620.0) - 24;
    final byHeight = constraints.maxHeight.isFinite
        ? constraints.maxHeight * _boardShare
        : byWidth;
    final smaller = byWidth < byHeight ? byWidth : byHeight;
    return smaller.clamp(200.0, 560.0);
  }

  /// The tree, drawn by the analysis board's own widget. Nothing until the
  /// walk has answered: an empty canvas would read as an empty repertoire.
  Widget _buildTree(BuildContext context) {
    final root = _treeRoot;
    final active = _activeNode;
    if (root == null || active == null) return const SizedBox.shrink();
    return RepertoireTreePanel(
      key: _treeKey,
      root: root,
      active: active,
      nodeLook: (node) => _looks[node.id],
      narrowed: _viewFrom != null,
      onNarrow: _node == null ? null : _narrowToHere,
      onWiden: _widenToWhole,
      onSelect: _jumpTo,
      onPromote: _promoteFromTree,
      onDelete: _deleteFromTree,
      truncatedAt: _tree?.truncated == true ? _tree?.maxPly : null,
      deleteLabel: (node) {
        final move = _moveOf(node);
        if (move == null) return 'Delete this variation';
        return _isMine(move.from.fen)
            ? 'Delete this move'
            : 'Delete this opponent move';
      },
      // Only on the reader's own moves: an opening is a decision of theirs.
      extraLabel: (node) {
        final move = _moveOf(node);
        if (move == null || !_isMine(move.from.fen)) return null;
        return 'Extract into new opening';
      },
      onExtra: _forkFromTree,
    );
  }

  /// The board and everything that belongs to the position standing on it.
  ///
  /// The banner, the board and the strip stay put; everything a reader scrolls
  /// *to* moves under them.
  Widget _buildBoardColumn(BuildContext context, double boardSize,
      {bool commentBeside = false, bool treeBelow = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!Breakpoints.isUltraWide(context) && _boardFen != null)
                OpeningBanner(
                  key: _openingKey,
                  fen: _boardFen!,
                  lookup: widget.openingLookup,
                ),
              Center(child: _buildBoard(boardSize)),
              _buildNavigation(context),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              top: AppSpacing.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ..._buildPositionPanels(context, commentBeside: commentBeside),
                const SizedBox(height: AppSpacing.md),
                _buildControls(context),
                if (treeBelow) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _buildTree(context),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBoard(double boardSize) => BoardWithCoordinates(
        size: boardSize,
        orientation: _forWhite ? PlayerColor.white : PlayerColor.black,
        builder: (inner) => ChessBoardWithOverlay(
          controller: _boardController,
          boardOrientation: _forWhite ? PlayerColor.white : PlayerColor.black,
          boardSize: inner,
          // Either side can be played: the student's own moves when it is
          // their turn, the opponent's moves they want to prepare when it is
          // not.
          isAllowedToMove: !_busy,
          isDrawingMode: false,
          drawingStartSquare: null,
          arrows: const [],
          lastMoveFrom: _lastMoveFrom,
          lastMoveTo: _lastMoveTo,
          engineArrows: _boardArrows(),
          onMove: _onMove,
          onSquareTapForDrawing: (_) {},
        ),
      );

  /// What belongs to the position standing on the board, from the line that
  /// reached it to the engine's note — the same list in every layout.
  List<Widget> _buildPositionPanels(BuildContext context,
      {required bool commentBeside}) {
    final active = _activeNode;
    return [
      if (active != null) ...[
        const SizedBox(height: AppSpacing.xxs),
        RepertoireLineStrip(active: active, onSelect: _jumpTo),
      ],
      if (!commentBeside) _buildComment(context, dense: true),
      const SizedBox(height: AppSpacing.md),
      _buildQuestion(context),
      const SizedBox(height: AppSpacing.sm),
      if (_verdictSan != null) _buildVerdict(context),
      _buildBook(context),
      if (!_afterMyMove && _kept.isNotEmpty) _buildKept(context),
      if (_thinking || _linesFen == _boardFen || _noteHere != null)
        _buildEngine(context),
      if (_note != null) ...[
        const SizedBox(height: AppSpacing.sm),
        SpeakableInfo(
          text: _note!,
          autoSpeak: true,
          child: Text(_note!,
              style: AppText.caption.copyWith(color: context.colors.textMuted)),
        ),
      ],
    ];
  }

  /// The gate, written as a move — "via 0-0", not "via e1g1".
  String? get _gateSan {
    final gate = widget.gateUci;
    if (gate == null) return null;
    for (final option in gateOptionsFor(widget.rootFen)) {
      if (option.uci == gate) return option.san;
    }
    return gate;
  }

  Widget _buildQuestion(BuildContext context) {
    final line = _lineText();
    final walk = _frontier;
    final gate = _gateSan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (gate != null) ...[
          Row(
            children: [
              Icon(Icons.alt_route, size: 14, color: context.colors.info),
              const SizedBox(width: AppSpacing.xxs),
              Expanded(
                child: Text(
                  'This repertoire goes through $gate — the rest of this position '
                  'is not displayed.',
                  style: AppText.caption.copyWith(color: context.colors.info),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
        ],
        if (line.isNotEmpty) ...[
          Text(
            line,
            style: AppText.caption.copyWith(color: context.colors.accent),
          ),
          const SizedBox(height: AppSpacing.xxs),
        ],
        // Read aloud: it says what to do on this board, and never reads a line
        // of moves.
        //
        // The sentence and nothing else. It used to carry how many positions
        // were still unanswered, which meant the spoken text changed at every
        // position and the count was read out over and over — reported live by
        // the owner, 16.9.2026. It is not only noise: since 15.9.2026 the
        // student's own move is kept with the book's top reply beside it, so
        // whether a line is carried further is a choice rather than a debt, and
        // counting what has not been answered describes a model this screen no
        // longer works by.
        //
        // What follows from dropping it: two positions in a row ask the same
        // thing, the text does not change, and `SpeechService` says it once.
        // That is the intent — the instruction is spoken when it turns into a
        // different instruction.
        Builder(builder: (context) {
          final question = _standingAfter != null
              ? 'After ${_standingAfter!.san} — which opponent moves do you prepare?'
              : (_forWhite
                  ? 'What do you play with White?'
                  : 'What do you play with Black?');
          return SpeakableInfo(
            autoSpeak: true,
            text: question,
            child: Text(
              question,
              style:
                  AppText.bodyBold.copyWith(color: context.colors.textPrimary),
            ),
          );
        }),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '$repertoireBuildPrinciple $repertoireBuildAdvice',
          style: AppText.micro.copyWith(color: context.colors.textMuted),
        ),
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

  /// How far the repertoire has got: what has been decided, and nothing about
  /// what has not.
  ///
  /// „open" was the same number as the sentence above it in shorter words, and
  /// it went with it — a half-fix here is how the rank numbers stayed invisible
  /// for two days after the file letters were put right. What is left is a
  /// count of work done, which is not a debt.
  String _progressText(RepertoireFrontier walk) {
    final parts = <String>[
      'decided ${walk.decided}',
      if (walk.truncated) 'preview shortened',
    ];
    return parts.join(' · ');
  }

  Widget _buildVerdict(BuildContext context) {
    // The same panel the analysis board uses, so a verdict is worded in one
    // place and cannot come to mean two different things.
    return OpeningJudgePanelWidget(
      moveSan: _verdictSan,
      isLoading: _judging,
      judgement: _verdict,
      reason: _verdictReason,
    );
  }

  /// The book's moves for the position on the board, as the Analysis board
  /// draws them: a row of chips, each played by a tap.
  Widget _buildBook(BuildContext context) {
    final fen = _boardFen;
    final here = _bookFor == fen;
    return OpeningExplorerPanelWidget(
      isLoading: !here,
      result: here ? _book : null,
      reason: here ? _bookReason : null,
      onMoveSelected: _busy ? null : _playFromBook,
      markOf: _bookMark,
      showGames: true,
    );
  }

  /// ★ on the student's main move and ✓ on any other move already in the
  /// repertoire, so a chip says whether playing it adds anything.
  String? _bookMark(String uci) {
    if (!_afterMyMove) {
      final kept = _kept.where((move) => move.uci == uci).firstOrNull;
      if (kept == null) return null;
      return kept.isPrimary ? '★' : '✓';
    }
    final active = _activeNode;
    if (active == null || active.fen != _activeFenOnBoard) return null;
    return active.children.any((child) => child.moveUci == uci) ? '✓' : null;
  }

  /// The board's position, when the drawing holds a card for it.
  String? get _activeFenOnBoard {
    final fen = _boardFen;
    final root = _treeRoot;
    if (fen == null || root == null) return null;
    return findNodeByFen(root, fen)?.fen;
  }

  /// The moves kept here, and which of them is the main one.
  Widget _buildKept(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Your moves here',
              style: AppText.bodyBold.copyWith(color: context.colors.accent)),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            _kept.length == 1
                ? 'Star marks the main move — drill will ask for this.'
                : 'Star marks the main move — drill will ask for this. '
                    'Tap another move to make it main.',
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
                        move.isPrimary ? 'main' : 'tap for main',
                        style: AppText.micro
                            .copyWith(color: context.colors.textMuted),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove',
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

  /// The buttons that act on the position on the board.
  Widget _buildControls(BuildContext context) {
    final drill = !_afterMyMove && widget.onDrillHere != null && _node != null;
    final buttons = [
      (
        Icons.psychology_outlined,
        'Ask engine',
        _busy || _thinking ? null : _askEngine,
      ),
      // To the next position after an opponent move with no answer yet.
      (
        Icons.skip_next,
        'Next position',
        _busy || _queue.isEmpty ? null : _advance,
      ),
      if (drill)
        (
          Icons.fitness_center,
          'Drill this branch',
          _busy ? null : () => widget.onDrillHere!(_node!.fen),
        ),
    ];

    // On a phone on its side: one row, strictly, in the side column. Wrapped,
    // the three took two rows of a 360 dp tall screen (TODO-provera 172, item
    // 4). Smaller type, smaller icons, and a label that is cut short rather
    // than wrapped where even that does not fit.
    if (LandscapeBoardLayout.applies(context)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Row(
          children: [
            for (final (i, b) in buttons.indexed) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: b.$3,
                  icon: Icon(b.$1, size: 16),
                  label:
                      Text(b.$2, maxLines: 1, overflow: TextOverflow.ellipsis),
                  style: OutlinedButton.styleFrom(
                    textStyle: AppText.caption,
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    minimumSize: const Size(0, 36),
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Wrap and not Row: a release build clips an overflow without a stripe.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final b in buttons)
          OutlinedButton.icon(
            onPressed: b.$3,
            icon: Icon(b.$1, size: 18),
            label: Text(b.$2),
          ),
      ],
    );
  }

  /// The engine's lines, and the two dials that decide what it answers.
  Widget _buildEngine(BuildContext context) {
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
                child: Text('Engine',
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
            'Local engine. Evaluation is from White\'s perspective.',
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
          _buildStoredNote(context),
          const SizedBox(height: AppSpacing.xs),
          for (final line in (_linesFen == _boardFen ? _lines : const []))
            InkWell(
              onTap: _busy ? null : () => _playLine(line),
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
          if (_lines.isNotEmpty && _linesFen == _boardFen)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text('Tap a line to play its first move.',
                  style:
                      AppText.micro.copyWith(color: context.colors.textMuted)),
            ),
        ],
      ),
    );
  }

  /// The evaluation stored on this position, with its depth and its date — an
  /// eval without them is a number that ages invisibly.
  Widget _buildStoredNote(BuildContext context) {
    final note = _noteHere;
    if (note == null) return const SizedBox.shrink();
    final when = note.updatedAt?.toLocal();
    final date =
        when == null ? null : '${when.day}.${when.month}.${when.year}.';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            [
              'Saved: ${note.text}',
              'depth ${note.evalDepth}',
              if (date != null) date,
            ].join(' · '),
            style: AppText.caption.copyWith(color: context.colors.textPrimary),
          ),
          if (note.bestLineSan != null)
            Text(
              note.bestLineSan!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.micro.copyWith(color: context.colors.textMuted),
            ),
        ],
      ),
    );
  }

  Widget _buildDone() {
    // Written once, shown and spoken from the same string.
    const done =
        'You have answered all positions reachable by this repertoire.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 40),
            const SizedBox(height: AppSpacing.md),
            SpeakableInfo(
              text: done,
              child: Text(
                done,
                style: AppText.bodyBold,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Everything is saved. The repertoire goes deeper when you play '
              'more opponent moves.',
              style: AppText.caption.copyWith(color: context.colors.textMuted),
              textAlign: TextAlign.center,
            ),
            if (_note != null) ...[
              const SizedBox(height: 10),
              SpeakableInfo(
                text: _note!,
                child: Text(
                  _note!,
                  style: AppText.caption.copyWith(color: context.colors.accent),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            // The door the sentence above promises.
            FilledButton.icon(
              onPressed: _busy ? null : _openRoot,
              icon: const Icon(Icons.account_tree_outlined, size: 18),
              label: const Text('Open repertoire'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One position on the board, and the way it was reached.
class _Pending {
  const _Pending({
    required this.fen,
    required this.path,
    this.lastUci,
  });

  final String fen;

  /// The move that led here, when the caller knows it. The board marks it.
  final String? lastUci;

  /// SAN from the repertoire's root to here.
  final List<String> path;
}
