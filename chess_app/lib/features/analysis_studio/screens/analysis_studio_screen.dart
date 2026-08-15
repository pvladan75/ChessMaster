import 'package:chess_app/services/app_logger.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/features/analysis_studio/widgets/board_setup_dialog.dart';
import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/widgets/stockfish_analysis_widget.dart';
import 'package:chess_app/widgets/engine_settings_dialog.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_app/widgets/ai_studio/board_eval_widgets.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:chess_app/features/analysis_studio/services/position_info_service.dart';
import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/syzygy_panel_widget.dart';
import 'package:chess_app/features/analysis_studio/services/opening_explorer_service.dart';
import 'package:chess_app/features/analysis_studio/services/chessdb_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/opening_explorer_panel_widget.dart';
import 'package:chess_app/features/analysis_studio/services/opening_book_service.dart';
import 'package:chess_app/core/models/tactical_motif.dart';
import 'package:chess_app/core/services/tactical_motif_detector.dart';
import 'package:chess_app/features/analysis_studio/widgets/tactical_findings_panel_widget.dart';
import 'package:chess_app/core/models/positional_factor.dart';
import 'package:chess_app/core/services/positional_evaluator_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/positional_findings_panel_widget.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_persistence_service.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_draft_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/auto_analysis_dialog.dart';
import 'package:chess_app/features/analysis_studio/widgets/quick_extend_dialog.dart';
import 'package:chess_app/features/analysis_studio/widgets/game_review_dialog.dart';
import 'package:chess_app/features/analysis_studio/widgets/saved_puzzle_sets_dialog.dart';
import 'package:chess_app/core/services/local_puzzle_extractor_service.dart';
import 'package:chess_app/core/services/eval_parsing.dart';
import 'package:chess_app/pgn_parser.dart' show PgnParser;
import 'package:chess_app/services/puzzle_api_service.dart';
import 'package:chess_app/features/analysis_studio/dialogs/analysis_studio_dialogs.dart' as dialogs;

class AnalysisStudioScreen extends StatefulWidget {
  final UserSession userSession;
  final String? initialFen;

  const AnalysisStudioScreen({
    super.key,
    required this.userSession,
    this.initialFen,
  });

  @override
  State<AnalysisStudioScreen> createState() => _AnalysisStudioScreenState();
}

class _AnalysisStudioScreenState extends State<AnalysisStudioScreen> {
  final ChessBoardController _boardController = ChessBoardController();
  final StockfishService _stockfishService = StockfishService();

  late AnalysisNode _rootNode;
  late AnalysisNode _currentNode;
  chess.Chess? _chessGame;
  String? _selectedSquareForTap;
  // A list rather than a single nullable slot: two moves made back-to-back
  // faster than the animation duration would otherwise have the second
  // move's trigger tear down the first's AnimatedMovePiece mid-flight, so
  // the piece snaps into place instead of visibly sliding there.
  final List<PendingMoveAnimation> _pendingAnimations = [];

  PlayerColor _orientation = PlayerColor.white;

  // Player identity from the last imported PGN's headers (White/Black/Elo/
  // Result) — null until a PGN with those headers is loaded, so the AppBar
  // falls back to the generic title otherwise. Purely informational.
  String? _pgnWhiteName;
  String? _pgnBlackName;
  String? _pgnWhiteElo;
  String? _pgnBlackElo;
  String? _pgnResult;

  // Puzzle-viewing mode: when non-null, the board is walking through
  // [_activePuzzleSet] (extracted from a game) instead of free analysis.
  // Entering a puzzle shows the position *before* the opponent's mistake
  // first, then plays that move after a short delay so the solver actually
  // sees what happened, highlighting the from/to squares via [_lastMoveFrom]
  // / [_lastMoveTo].
  List<LocalPuzzle>? _activePuzzleSet;
  int _activePuzzleIndex = 0;
  String? _lastMoveFrom;
  String? _lastMoveTo;
  Timer? _puzzleRevealTimer;

  // Engine evaluation state
  bool _showEvaluation = true;
  bool _showEvalBar = true;
  double _currentRawEval = 0.0;
  String _currentEvalString = '0.00';
  int _currentEvalDepth = 18;
  Map<int, AnalysisLine> _engineLinesMap = {};
  List<EngineArrow> _engineArrows = [];
  final bool _showEngineOverlay = true;

  // deltaCutoff the auto-analysis tree was last generated with, so the tree
  // view's post-hoc display filter can cap its slider there instead of
  // offering a range that would silently do nothing above that value.
  double? _lastAutoAnalysisDeltaCutoff;

  // Syzygy tablebase state
  final SyzygyTablebaseService _syzygyService = SyzygyTablebaseService.instance;
  SyzygyResult? _syzygyResult;
  bool _syzygyLoading = false;
  int _syzygyRequestId = 0;

  // Lichess Opening Explorer state
  final OpeningExplorerService _openingExplorerService = OpeningExplorerService.instance;
  OpeningExplorerResult? _openingExplorerResult;
  bool _openingExplorerLoading = false;
  int _openingExplorerRequestId = 0;

  final ChessDbService _chessDbService = ChessDbService.instance;
  ChessDbResult? _chessDbResult;
  bool _chessDbLoading = false;
  int? _openingExplorerMinRating;

  // Tactical motifs for _currentNode, memoized by fen+move so the frequent
  // setState calls while the engine streams eval updates don't re-run the
  // detector for a position that hasn't actually changed.
  final _tacticalDetector = const TacticalMotifDetector();
  String? _tacticalCacheKey;
  MotifResult _tacticalResult = MotifResult.empty();

  MotifResult _computeTacticalFindings() {
    final key = '${_currentNode.fen}|${_currentNode.moveUci}';
    if (key != _tacticalCacheKey) {
      _tacticalCacheKey = key;
      _tacticalResult = _tacticalDetector.detect(
        fen: _currentNode.fen,
        lastMoveUci: _currentNode.moveUci,
        evalText: _currentEvalString,
      );
    }
    return _tacticalResult;
  }

  // Positional factors for _currentNode — same memoization approach; eval
  // text doesn't factor into positional findings, so the key is just the fen.
  final _positionalEvaluator = const PositionalEvaluatorService();
  String? _positionalCacheKey;
  PositionalResult _positionalResult = PositionalResult.empty();

  bool _isGeneratingAiComment = false;

  PositionalResult _computePositionalFindings() {
    final key = _currentNode.fen;
    if (key != _positionalCacheKey) {
      _positionalCacheKey = key;
      _positionalResult = _positionalEvaluator.evaluate(fen: _currentNode.fen);
    }
    return _positionalResult;
  }

  @override
  void initState() {
    super.initState();
    final startFen = widget.initialFen ?? 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    AppLogger.log('[AnalysisStudio] 🎬 initState initialized with FEN: $startFen');
    _initAnalysisTree(startFen);
    _initEngine();
    OpeningBookService.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    // An explicit initialFen means the caller wants that exact position
    // (e.g. exported from a game), so it must not be overwritten by a draft.
    if (widget.initialFen == null) {
      _restoreDraft();
    }
  }

  @override
  void dispose() {
    _puzzleRevealTimer?.cancel();
    // A debounced write would be lost with this screen, so force it out first.
    unawaited(AnalysisDraftService.instance.flush(
      rootNode: _rootNode,
      currentNode: _currentNode,
      blackOrientation: _orientation == PlayerColor.black,
    ));
    // Hands the shared engine back to the screen that pushed this one.
    _stockfishService.detach(this);
    super.dispose();
  }

  /// Persists the working tree so leaving the screen — to change a setting, to
  /// take a call, or because Android reclaimed memory — never loses analysis.
  void _saveDraft() {
    AnalysisDraftService.instance.scheduleSave(
      rootNode: _rootNode,
      currentNode: _currentNode,
      blackOrientation: _orientation == PlayerColor.black,
    );
  }

  Future<void> _restoreDraft() async {
    final draft = await AnalysisDraftService.instance.load();
    if (!mounted || draft == null) return;

    setState(() {
      _rootNode = draft.rootNode;
      _currentNode = draft.resolveCurrentNode();
      _orientation = draft.blackOrientation ? PlayerColor.black : PlayerColor.white;
      _chessGame = chess.Chess.fromFEN(_currentNode.fen);
      _boardController.loadFen(_currentNode.fen);
      _engineLinesMap.clear();
    });
    _refreshArrows();
    _triggerEngineAnalysis();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Vraćena je vaša poslednja analiza.'),
        backgroundColor: Colors.teal,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Počni iznova',
          textColor: Colors.white,
          onPressed: () {
            AnalysisDraftService.instance.clear();
            setState(() {
              _initAnalysisTree('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
              _engineLinesMap.clear();
            });
            _refreshArrows();
            _triggerEngineAnalysis();
          },
        ),
      ),
    );
  }

  void _initAnalysisTree(String fen) {
    _rootNode = AnalysisNode(fen: fen);
    _currentNode = _rootNode;
    _chessGame = chess.Chess.fromFEN(fen);
    _boardController.loadFen(fen);
    final side = fen.split(' ')[1];
    _orientation = side == 'b' ? PlayerColor.black : PlayerColor.white;
    _lastMoveFrom = null;
    _lastMoveTo = null;
    _pgnWhiteName = null;
    _pgnBlackName = null;
    _pgnWhiteElo = null;
    _pgnBlackElo = null;
    _pgnResult = null;
  }

  Future<void> _initEngine() async {
    await _stockfishService.initEngine();
    // Set before attach() so the auto-triggered first analysis (fired
    // synchronously inside attach(), see below) already uses the configured
    // MultiPV count instead of whatever the previous screen left behind.
    _stockfishService.setMultiPV(AppSettingsService.instance.defaultMultiPV);
    _stockfishService.attach(
      this,
      getFen: () => _currentNode.fen,
      isEnabled: () => _showEvaluation || _showEvalBar,
      onEvaluation: (evaluation, bestMove, continuation, multipv, depth, isFinal, analyzedFen) {
        if (!mounted) return;
        if (!_showEvaluation && !_showEvalBar) return;

        final parsedEval = parseWhiteRelativeEval(evaluation) ?? 0.0;

        if (multipv == 1) {
          setState(() {
            _currentRawEval = parsedEval;
            _currentEvalString = evaluation;
            _currentEvalDepth = depth;
            // Never let a shallower live pass (e.g. this node just came back
            // into view while the engine is still climbing toward its
            // target depth) regress an eval a prior whole-game review
            // already computed at a greater depth.
            if (_currentNode.evalDepth == null || depth >= _currentNode.evalDepth!) {
              _currentNode.eval = parsedEval;
              _currentNode.evalDepth = depth;
            }
          });
        }
      },
      onMultiPV: (linesMap) {
        if (!mounted) return;
        setState(() {
          _engineLinesMap = linesMap;
        });
        // Stored candidates take precedence over live lines, so route through
        // the same chooser the navigation path uses.
        _refreshArrows();
      },
    );

    // attach() above already auto-triggers engine analysis for the current FEN
    // (StockfishService._activateTopSubscriber). Calling _triggerEngineAnalysis()
    // here too used to fire a second, near-simultaneous stop/position/go
    // sequence, and the two writes to the native engine's stdin raced and
    // corrupted each other (Stockfish would log "Unknown command: 'sstop'" or a
    // mangled FEN and silently drop the request). Only kick off the lookups
    // that attach() doesn't cover.
    _fetchSyzygyIfEligible();
    _fetchOpeningExplorerIfEligible();
  }

  Future<void> _fetchSyzygyIfEligible() async {
    final fen = _currentNode.fen;
    final phaseInfo = PositionInfoService.analyzeFen(fen);
    final reqId = ++_syzygyRequestId;

    if (!phaseInfo.isSyzygyReady) {
      if (_syzygyResult != null || _syzygyLoading) {
        setState(() {
          _syzygyResult = null;
          _syzygyLoading = false;
        });
      }
      return;
    }

    setState(() {
      _syzygyLoading = true;
      _syzygyResult = null;
    });

    final result = await _syzygyService.lookup(fen);
    if (!mounted || reqId != _syzygyRequestId) return;

    setState(() {
      _syzygyResult = result;
      _syzygyLoading = false;
    });
  }

  Future<void> _fetchOpeningExplorerIfEligible() async {
    final reqId = ++_openingExplorerRequestId;

    final wantsChessDb = AppSettingsService.instance.openingDbSource == 'chessdb';
    AppLogger.log('[OpeningExplorer] 🔍 hasToken=${OpeningExplorerService.hasToken} | wantsChessDb=$wantsChessDb | FEN: ${_currentNode.fen}');

    if (wantsChessDb || !OpeningExplorerService.hasToken) {
      AppLogger.log(wantsChessDb
          ? '[OpeningExplorer] ⚙️ Korisnik je izabrao ChessDB'
          : '[OpeningExplorer] ⛔ Nema tokena — koristim ChessDB fallback');
      if (_openingExplorerResult != null || _openingExplorerLoading) {
        setState(() {
          _openingExplorerResult = null;
          _openingExplorerLoading = false;
        });
      }
      await _fetchChessDbFallback(reqId);
      return;
    }

    setState(() {
      _openingExplorerLoading = true;
      _openingExplorerResult = null;
    });

    final result = await _openingExplorerService.lookup(
      _currentNode.fen,
      minRating: _openingExplorerMinRating,
    );
    if (!mounted || reqId != _openingExplorerRequestId) return;

    AppLogger.log('[OpeningExplorer] 📊 Rezultat: ${result == null ? "null" : "${result.moves.length} poteza, ${result.total} partija"}');

    setState(() {
      _openingExplorerResult = result;
      _openingExplorerLoading = false;
    });
  }

  Future<void> _fetchChessDbFallback(int reqId) async {
    setState(() {
      _chessDbLoading = true;
      _chessDbResult = null;
    });

    final result = await _chessDbService.lookup(_currentNode.fen);
    if (!mounted || reqId != _openingExplorerRequestId) return;

    AppLogger.log('[ChessDB] 📊 Rezultat: ${result == null ? "null" : "${result.moves.length} poteza"}');

    setState(() {
      _chessDbResult = result;
      _chessDbLoading = false;
    });
  }

  void _onOpeningExplorerMinRatingChanged(int? minRating) {
    setState(() => _openingExplorerMinRating = minRating);
    _fetchOpeningExplorerIfEligible();
  }

  void _playUciMove(String uci) {
    if (uci.length < 4) return;
    final from = uci.substring(0, 2);
    final to = uci.substring(2, 4);
    final promotion = uci.length > 4 ? uci.substring(4, 5) : '';
    _handleUserMove(from, to, promotion);
  }

  /// Pushes Settings *over* this screen rather than making the user pop back
  /// to the home shell — the analysis stays mounted underneath, so returning
  /// lands exactly where they left off.
  Future<void> _openAppSettings() async {
    await context.push(AppRoutes.preferences);
    // Board scale and panel visibility are read during build, so re-read them.
    if (mounted) setState(() {});
  }

  Future<void> _openEngineSettings() async {
    await showEngineSettingsDialog(
      context,
      stockfishService: _stockfishService,
      isEngineEnabled: _showEvaluation || _showEvalBar,
    );
    if (mounted) setState(() {});
  }

  void _triggerEngineAnalysis() {
    AppLogger.log('[AnalysisStudio] ⚡ _triggerEngineAnalysis fired | showEval: $_showEvaluation | showEvalBar: $_showEvalBar | Current FEN: ${_currentNode.fen}');
    _fetchSyzygyIfEligible();
    _fetchOpeningExplorerIfEligible();
    if (_showEvaluation || _showEvalBar) {
      // Validate FEN before sending to engine
      try {
        final testGame = chess.Chess.fromFEN(_currentNode.fen);
        AppLogger.log('[AnalysisStudio] ✅ FEN is valid for chess game: ${_currentNode.fen}');
      } catch (e) {
        AppLogger.log('[AnalysisStudio ERROR] ❌ Invalid FEN string: ${_currentNode.fen} | Error: $e');
      }

      final depth = AppSettingsService.instance.defaultEngineDepth;
      _stockfishService.stopAnalysis();
      _stockfishService.setMultiPV(AppSettingsService.instance.defaultMultiPV);
      _stockfishService.analyzePosition(_currentNode.fen, depth: depth);
    } else {
      AppLogger.log('[AnalysisStudio] ⏸️ Engine evaluation disabled by user switch. Stopping analysis.');
      _stockfishService.stopAnalysis();
      setState(() {
        _engineLinesMap.clear();
        _engineArrows.clear();
      });
    }
  }

  List<EngineArrow> _buildArrowsFromEngineLines(List<AnalysisLine> lines) {
    if (!_showEngineOverlay || lines.isEmpty) return [];
    final List<EngineArrow> arrows = [];
    for (var line in lines) {
      if (line.bestMoveLan.length >= 4) {
        final from = line.bestMoveLan.substring(0, 2);
        final to = line.bestMoveLan.substring(2, 4);
        arrows.add(EngineArrow(
          from: from,
          to: to,
          evalText: line.evaluation,
          rank: line.multipv,
        ));
      }
    }
    return arrows;
  }

  /// Builds arrows from the candidate moves already stored under [node].
  ///
  /// After an automatic analysis every node carries its n best replies as
  /// children with their evaluations, so walking the generated tree shows the
  /// candidates at each intermediate step without waiting for the engine to
  /// re-analyze the position.
  List<EngineArrow> _buildArrowsFromChildren(AnalysisNode node) {
    if (!_showEngineOverlay || node.children.isEmpty) return [];

    final isWhiteToMove = node.fen.split(' ').length > 1 && node.fen.split(' ')[1] == 'w';

    // Rank by how good the reply is for the side to move.
    final ranked = node.children.where((c) => c.moveUci != null && c.moveUci!.length >= 4).toList()
      ..sort((a, b) {
        final ea = a.eval;
        final eb = b.eval;
        if (ea == null && eb == null) return 0;
        if (ea == null) return 1;
        if (eb == null) return -1;
        return isWhiteToMove ? eb.compareTo(ea) : ea.compareTo(eb);
      });

    final arrows = <EngineArrow>[];
    for (var i = 0; i < ranked.length; i++) {
      final child = ranked[i];
      final uci = child.moveUci!;
      arrows.add(EngineArrow(
        from: uci.substring(0, 2),
        to: uci.substring(2, 4),
        evalText: child.eval != null
            ? (child.eval! > 0 ? '+${child.eval!.toStringAsFixed(2)}' : child.eval!.toStringAsFixed(2))
            : (child.moveSan ?? ''),
        rank: i + 1,
      ));
    }
    return arrows;
  }

  /// Chooses which candidate arrows to draw for the current node.
  ///
  /// Stored children win when they exist: they are the result the user asked
  /// for after an automatic analysis, and they stay stable while navigating.
  /// Live engine lines cover nodes that have not been expanded yet.
  void _refreshArrows() {
    final stored = _buildArrowsFromChildren(_currentNode);
    setState(() {
      _engineArrows = stored.isNotEmpty
          ? stored
          : _buildArrowsFromEngineLines(_engineLinesMap.values.toList());
    });
  }

  void _jumpToNode(AnalysisNode node) {
    // A single ply forward (stepping to a direct child — "next", or one
    // step of tree playback/auto-play) has an unambiguous from/to to
    // animate. Jumps elsewhere in the tree (a distant node click, "first",
    // going back to the parent) change more than one piece's story at once,
    // so those still just snap to the target position as before.
    final isSingleStepForward = node.parent?.id == _currentNode.id;
    final moveUci = node.moveUci;

    setState(() {
      _currentNode = node;
      _chessGame = chess.Chess.fromFEN(node.fen);
      _boardController.loadFen(node.fen);
      _engineLinesMap.clear();
      _lastMoveFrom = null;
      _lastMoveTo = null;
    });

    if (isSingleStepForward && moveUci != null && moveUci.length >= 4) {
      final from = moveUci.substring(0, 2);
      final to = moveUci.substring(2, 4);
      final piece = _chessGame!.get(to);
      if (piece != null) _triggerMoveAnimation(from, to, piece);
    }

    _saveDraft();
    // Show this node's stored candidates immediately; the engine may still be
    // several seconds away from producing lines for the new position.
    _refreshArrows();
    _triggerEngineAnalysis();
  }

  /// [animate] is off for moves the user made by dragging: the piece has
  /// already travelled to [to] under their pointer, so sliding it along the
  /// same path again reads as the move happening twice.
  void _handleUserMove(String from, String to, String promotion, {bool animate = true}) {
    if (_chessGame == null) return;

    final movingPiece = _chessGame!.get(from);

    final moveMap = {
      'from': from,
      'to': to,
      if (promotion.isNotEmpty) 'promotion': promotion,
    };

    // The chess package's history entries carry no SAN string at all (only
    // from/to/flags/piece) — has to come from the verbose pre-move
    // candidate list, which does have a 'san' key, so look it up there
    // before actually playing the move.
    String san = '$from$to';
    final promo = promotion.isEmpty ? null : promotion;
    for (final m in _chessGame!.moves({'verbose': true})) {
      if (m['from'] == from && m['to'] == to) {
        if (promo == null || m['promotion'] == promo || m['promotion'] == promo.toLowerCase()) {
          san = (m['san'] as String?) ?? san;
          break;
        }
      }
    }

    final success = _chessGame!.move(moveMap);
    if (success) {
      final uci = '$from$to${promotion.toLowerCase()}';
      final newFen = _chessGame!.fen;

      final childNode = _currentNode.addChild(
        childFen: newFen,
        san: san,
        uci: uci,
      );

      if (!AppSettingsService.instance.manualCommentMode && childNode.comment.isEmpty) {
        final tacticalDiff = _tacticalDetector.explainMove(
          beforeFen: _currentNode.fen,
          afterFen: newFen,
          lastMoveUci: uci,
        );
        final positionalDiff = _positionalEvaluator.explainMove(beforeFen: _currentNode.fen, afterFen: newFen);
        final autoComment = [
          _tacticalDetector.describeMoveDiff(tacticalDiff),
          _positionalEvaluator.describeMoveDiff(positionalDiff),
        ].where((s) => s.isNotEmpty).join(' | ');
        if (autoComment.isNotEmpty) {
          childNode.comment = autoComment;
        }
      }

      setState(() {
        _currentNode = childNode;
        _boardController.loadFen(newFen);
        _engineLinesMap.clear();
        _lastMoveFrom = null;
        _lastMoveTo = null;
      });
      // Read the piece back from its destination (post-move) rather than
      // using movingPiece directly: on a promotion, the piece sitting on
      // `to` is already the queen the real board now shows, while
      // movingPiece is still the pre-move pawn.
      final animatedPiece = _chessGame!.get(to) ?? movingPiece;
      if (animate && animatedPiece != null) _triggerMoveAnimation(from, to, animatedPiece);

      _saveDraft();
      _refreshArrows();
      _triggerEngineAnalysis();
    }
  }

  void _triggerMoveAnimation(String from, String to, chess.Piece movingPiece) {
    final durationMs = AppSettingsService.instance.moveAnimationDurationMs;
    if (durationMs <= 0) return;
    setState(() {
      _pendingAnimations.add(PendingMoveAnimation(from: from, to: to, piece: movingPiece));
    });
  }

  void _goFirst() {
    _jumpToNode(_nearestLineStart(_currentNode));
  }

  /// Walks up from [node] to the nearest ancestor that is itself a branch
  /// point (has more than one child) — i.e. the node the current line
  /// diverged from. If the path back to the root never branches, that's
  /// effectively the same as "the line's start", so this falls back to it.
  AnalysisNode _nearestLineStart(AnalysisNode node) {
    var cur = node;
    while (!cur.isRoot) {
      final parent = cur.parent!;
      if (parent.children.length > 1) return parent;
      cur = parent;
    }
    return cur;
  }

  void _goPrevious() {
    if (_currentNode.parent != null) {
      _jumpToNode(_currentNode.parent!);
    }
  }

  void _goNext() {
    if (_currentNode.children.isNotEmpty) {
      _jumpToNode(_currentNode.children.first);
    }
  }

  void _goLast() {
    var curr = _currentNode;
    while (curr.children.isNotEmpty) {
      curr = curr.children.first;
    }
    _jumpToNode(curr);
  }

  /// Always opens the checklist editor (see [dialogs.showManualCommentDialog])
  /// rather than a plain free-text box, regardless of the "manualCommentMode"
  /// app setting — that setting only controls whether a *freshly played*
  /// move gets auto-commented, not how an existing comment is edited. Every
  /// clause the current comment is already built from — auto-generated or
  /// not — comes back pre-checked, so editing means picking which findings
  /// to keep, not retyping the whole thing.
  void _showCommentDialog() {
    final parentFen = _currentNode.parent?.fen;
    final moveUci = _currentNode.moveUci;

    final tacticalCandidates = <String>[];
    final positionalCandidates = <String>[];
    if (parentFen != null && moveUci != null) {
      final tacticalDiff = _tacticalDetector.explainMove(
        beforeFen: parentFen,
        afterFen: _currentNode.fen,
        lastMoveUci: moveUci,
      );
      final positionalDiff = _positionalEvaluator.explainMove(beforeFen: parentFen, afterFen: _currentNode.fen);
      tacticalCandidates.addAll(_tacticalDetector.candidateCommentLines(tacticalDiff));
      positionalCandidates.addAll(_positionalEvaluator.candidateCommentLines(positionalDiff));
    }

    dialogs.showManualCommentDialog(context, _currentNode.comment, tacticalCandidates, positionalCandidates, (comment) {
      setState(() => _currentNode.comment = comment);
    });
  }

  Map<String, dynamic> _motifFindingToJson(MotifFinding f) => {
        'motifs': f.motifs.map((m) => m.name).toList(),
        'description': f.description,
        'significance': f.significance,
        'favorsMover': f.favorsMover,
      };
  Map<String, dynamic> _positionalFindingToJson(PositionalFinding f) => {
        'factors': f.factors.map((p) => p.name).toList(),
        'description': f.description,
        'significance': f.significance,
        'favorsMover': f.favorsMover,
      };

  /// Tactical + positional finding diff between two positions, serialized
  /// for the AI endpoint — the same computation [_generateAiComment] needs
  /// for the played move, the previous move, engine alternatives, and
  /// sibling variations alike, just with different (beforeFen, afterFen).
  ({List<Map<String, dynamic>> tactical, List<Map<String, dynamic>> positional}) _findingsPairFor(
    String beforeFen,
    String afterFen,
    String lastMoveUci,
  ) {
    final tacticalDiff = _tacticalDetector.explainMove(beforeFen: beforeFen, afterFen: afterFen, lastMoveUci: lastMoveUci);
    final positionalDiff = _positionalEvaluator.explainMove(beforeFen: beforeFen, afterFen: afterFen);
    return (
      tactical: [...tacticalDiff.created, ...tacticalDiff.resolved].map(_motifFindingToJson).toList(),
      positional: [...positionalDiff.created, ...positionalDiff.resolved].map(_positionalFindingToJson).toList(),
    );
  }

  /// Sends the move's tactical/positional finding diff (the same data
  /// [_showCommentDialog] already computes) plus its eval swing to the
  /// backend's Gemini-backed endpoint, then opens the same checklist editor
  /// pre-filled with the generated prose. Free-flowing AI text never matches
  /// a candidate finding line, so [dialogs.showManualCommentDialog] naturally
  /// drops it into its free-text box — reviewable/editable there, nothing is
  /// saved until the user hits "Sačuvaj".
  ///
  /// Also gathers comparative context so the model can contrast what was
  /// played against what else was possible: the previous move, an unplayed
  /// sibling variation (if this move was played from a branch point), and
  /// the engine's own alternative to what was actually played.
  Future<void> _generateAiComment() async {
    final parent = _currentNode.parent;
    final moveUci = _currentNode.moveUci;
    if (parent == null || moveUci == null) return;

    final played = _findingsPairFor(parent.fen, _currentNode.fen, moveUci);
    final tacticalCandidates = _tacticalDetector.candidateCommentLines(
      _tacticalDetector.explainMove(beforeFen: parent.fen, afterFen: _currentNode.fen, lastMoveUci: moveUci),
    );
    final positionalCandidates = _positionalEvaluator.candidateCommentLines(
      _positionalEvaluator.explainMove(beforeFen: parent.fen, afterFen: _currentNode.fen),
    );

    // Previous move — what led into the position this move was played from.
    Map<String, dynamic>? previousMoveData;
    final grandparent = parent.parent;
    final parentMoveUci = parent.moveUci;
    if (grandparent != null && parentMoveUci != null) {
      final pair = _findingsPairFor(grandparent.fen, parent.fen, parentMoveUci);
      previousMoveData = {
        'moveSan': parent.moveSan ?? '',
        'tacticalFindings': pair.tactical,
        'positionalFindings': pair.positional,
      };
    }

    // Sibling variation(s) — only present if the played move came from a
    // branch point (parent has more than one explored child).
    final siblingAlternatives = <Map<String, dynamic>>[];
    for (final sibling in parent.children) {
      if (sibling.id == _currentNode.id) continue;
      final siblingUci = sibling.moveUci;
      if (siblingUci == null) continue;
      final pair = _findingsPairFor(parent.fen, sibling.fen, siblingUci);
      siblingAlternatives.add({
        'moveSan': sibling.moveSan ?? '',
        'tacticalFindings': pair.tactical,
        'positionalFindings': pair.positional,
      });
    }

    setState(() => _isGeneratingAiComment = true);

    // Engine's alternative to the played move, from the same (parent)
    // position — the expensive part. analyzePositionSync interrupts the
    // live eval panel's own search to answer this one-off query, so the
    // panel is always re-triggered afterward regardless of outcome.
    Map<String, dynamic>? engineAlternativeData;
    try {
      final lines = await _stockfishService.analyzePositionSync(
        parent.fen,
        depth: 14,
        multiPV: 1,
        timeout: const Duration(seconds: 8),
      );
      if (lines.isNotEmpty) {
        final best = lines.first;
        if (best.bestMoveLan.isNotEmpty && best.bestMoveLan != moveUci) {
          final altGame = chess.Chess.fromFEN(parent.fen);
          bool moveOk = false;
          if (best.bestMoveSan.isNotEmpty) {
            try {
              moveOk = altGame.move(best.bestMoveSan);
            } catch (_) {}
          }
          if (!moveOk && best.bestMoveLan.length >= 4) {
            final from = best.bestMoveLan.substring(0, 2);
            final to = best.bestMoveLan.substring(2, 4);
            final promo = best.bestMoveLan.length > 4 ? best.bestMoveLan.substring(4, 5) : null;
            try {
              moveOk = altGame.move({'from': from, 'to': to, if (promo != null) 'promotion': promo});
            } catch (_) {}
          }
          if (moveOk) {
            final pair = _findingsPairFor(parent.fen, altGame.fen, best.bestMoveLan);
            engineAlternativeData = {
              'moveSan': best.bestMoveSan.isNotEmpty ? best.bestMoveSan : best.bestMoveLan,
              'eval': best.evaluation,
              'tacticalFindings': pair.tactical,
              'positionalFindings': pair.positional,
            };
          }
        }
      }
    } catch (e) {
      print('[AnalysisStudio] Engine alternative query for AI comment failed: $e');
    } finally {
      // Resume live analysis for the position actually on screen.
      _triggerEngineAnalysis();
    }

    // Cheap fallback: if there's no fresh engine alternative, but the game
    // actually continued past this move, that reply's eval is already
    // sitting in the tree — free forward-looking context, no extra query.
    Map<String, dynamic>? nextMoveEvalData;
    if (engineAlternativeData == null && _currentNode.children.isNotEmpty) {
      final nextChild = _currentNode.children.first;
      if (nextChild.eval != null) {
        nextMoveEvalData = {'moveSan': nextChild.moveSan ?? '', 'eval': nextChild.eval};
      }
    }

    String? aiComment;
    try {
      aiComment = await PuzzleApiService.instance.generateMoveComment(
        moveSan: _currentNode.moveSan ?? '',
        evalBefore: parent.eval,
        evalAfter: _currentNode.eval,
        tacticalFindings: played.tactical,
        positionalFindings: played.positional,
        previousMove: previousMoveData,
        engineAlternative: engineAlternativeData,
        nextMoveEval: nextMoveEvalData,
        siblingAlternatives: siblingAlternatives,
        userToken: widget.userSession.token,
      );
    } finally {
      if (mounted) setState(() => _isGeneratingAiComment = false);
    }

    if (!mounted) return;
    if (aiComment == null || aiComment.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Greška pri generisanju AI komentara.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    dialogs.showManualCommentDialog(context, aiComment, tacticalCandidates, positionalCandidates, (comment) {
      setState(() => _currentNode.comment = comment);
    });
  }

  void _showNagSelector() {
    dialogs.showNagSelector(context, (nag) {
      setState(() => _currentNode.nag = nag);
    });
  }

  void _showAutoAnalysisDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AutoAnalysisDialog(
        startNode: _currentNode,
        stockfishService: _stockfishService,
        onAnalysisCompleted: (deltaCutoffUsed) {
          // The start node now has candidate children — surface them as arrows.
          setState(() => _lastAutoAnalysisDeltaCutoff = deltaCutoffUsed);
          _refreshArrows();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚡ Automatska analiza uspešno završena i sačuvana u stablo!'), backgroundColor: Colors.amber),
          );
        },
      ),
    );
  }

  void _showQuickExtendDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => QuickExtendDialog(
        startNode: _currentNode,
        stockfishService: _stockfishService,
        onCompleted: (lastAdded) {
          if (lastAdded != null) {
            _jumpToNode(lastAdded);
          }
        },
      ),
    );
  }

  void _exportPgn() {
    dialogs.exportPgnDialog(context, _rootNode);
  }

  void _showGameReviewDialog() {
    showDialog(
      context: context,
      // Long-running engine walk — barrier tap must not silently discard it.
      barrierDismissible: false,
      builder: (ctx) => GameReviewDialog(
        rootNode: _rootNode,
        currentNode: _currentNode,
        stockfishService: _stockfishService,
        onCompleted: ({extractedPuzzles}) {
          setState(() {});
          _saveDraft();
          if (extractedPuzzles != null && extractedPuzzles.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🧩 Izvučeno ${extractedPuzzles.length} vežbi (sačuvano)'),
                backgroundColor: Colors.teal,
                duration: const Duration(seconds: 6),
                action: SnackBarAction(
                  label: 'Prikaži',
                  textColor: Colors.white,
                  onPressed: () {
                    setState(() => _activePuzzleSet = extractedPuzzles);
                    _loadPuzzleAtIndex(0);
                  },
                ),
              ),
            );
          }
        },
      ),
    );
  }

  void _showSavedPuzzleSetsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SavedPuzzleSetsDialog(
        onPuzzleSetOpened: (puzzles, startIndex) {
          setState(() => _activePuzzleSet = puzzles);
          _loadPuzzleAtIndex(startIndex);
        },
      ),
    );
  }

  /// Loads puzzle [index] of [_activePuzzleSet]: shows the position right
  /// before the mistake first, then (after a short pause so the solver can
  /// register the starting position) plays that move and highlights its
  /// from/to squares — rather than dropping the solver straight into the
  /// post-mistake position with no context, as before.
  void _loadPuzzleAtIndex(int index) {
    _puzzleRevealTimer?.cancel();
    final puzzle = _activePuzzleSet![index];
    _activePuzzleIndex = index;

    final canReveal = puzzle.fenBefore != null && puzzle.moveUci != null;
    setState(() {
      _initAnalysisTree(canReveal ? puzzle.fenBefore! : puzzle.fen);
    });
    _refreshArrows();
    _saveDraft();
    _triggerEngineAnalysis();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('🧩 ${puzzle.themeLabel}'), backgroundColor: Colors.teal),
    );

    if (canReveal) {
      _puzzleRevealTimer = Timer(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        _applyPuzzleOpponentMove(puzzle);
      });
    }
  }

  /// Plays the blunder move ([LocalPuzzle.moveUci]) onto the current
  /// position (the puzzle's "before" FEN) and highlights it, landing on the
  /// same post-blunder position the rest of the app treats as [puzzle.fen].
  void _applyPuzzleOpponentMove(LocalPuzzle puzzle) {
    if (_chessGame == null) return;
    final uci = puzzle.moveUci!;
    final from = uci.substring(0, 2);
    final to = uci.substring(2, 4);
    final promo = uci.length > 4 ? uci.substring(4) : '';

    String san = '$from$to';
    final promoLower = promo.isEmpty ? null : promo.toLowerCase();
    for (final m in _chessGame!.moves({'verbose': true})) {
      if (m['from'] == from && m['to'] == to) {
        if (promoLower == null || m['promotion'] == promoLower) {
          san = (m['san'] as String?) ?? san;
          break;
        }
      }
    }

    final moveMap = {
      'from': from,
      'to': to,
      if (promo.isNotEmpty) 'promotion': promo,
    };
    final success = _chessGame!.move(moveMap);
    if (!success) return;

    final newFen = _chessGame!.fen;
    final childNode = _currentNode.addChild(childFen: newFen, san: san, uci: uci);

    setState(() {
      _currentNode = childNode;
      _boardController.loadFen(newFen);
      _lastMoveFrom = from;
      _lastMoveTo = to;
      _engineLinesMap.clear();
    });
    _refreshArrows();
    _saveDraft();
    _triggerEngineAnalysis();
  }

  void _goToPuzzle(int delta) {
    final set = _activePuzzleSet;
    if (set == null) return;
    final newIndex = _activePuzzleIndex + delta;
    if (newIndex < 0 || newIndex >= set.length) return;
    _loadPuzzleAtIndex(newIndex);
  }

  void _exitPuzzleSet() {
    _puzzleRevealTimer?.cancel();
    setState(() {
      _activePuzzleSet = null;
      _activePuzzleIndex = 0;
    });
  }

  void _showSetupDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AnalysisBoardSetupDialog(
        initialFen: _currentNode.fen,
        onPositionSet: (newFen) {
          setState(() {
            _initAnalysisTree(newFen);
          });
          _saveDraft();
          _triggerEngineAnalysis();
        },
        onPgnLoaded: (pgn) {
          _importPgn(pgn);
        },
      ),
    );
  }

  /// Imports a PGN game as a full move tree.
  ///
  /// Replays the game's SAN history onto the analysis tree rather than keeping
  /// only the final position, so the imported game is navigable and can carry
  /// variations, comments and NAGs like any hand-played line.
  void _importPgn(String rawPgn) {
    try {
      final pgn = PgnParser.sanitizeForLoadPgn(rawPgn);
      final tempGame = chess.Chess();
      if (!tempGame.load_pgn(pgn)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Neispravan PGN format.'), backgroundColor: Colors.red),
        );
        return;
      }

      // A PGN may start from a custom position via the SetUp/FEN headers.
      final headerFen = tempGame.header['FEN'] as String?;
      final startFen = (headerFen != null && headerFen.trim().isNotEmpty)
          ? headerFen.trim()
          : 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

      // SAN encodes promotions, so replaying by SAN reproduces the game exactly.
      final sanHistory = tempGame.getHistory().cast<String>();

      _initAnalysisTree(startFen);
      _pgnWhiteName = (tempGame.header['White'] as String?)?.trim();
      _pgnBlackName = (tempGame.header['Black'] as String?)?.trim();
      _pgnWhiteElo = (tempGame.header['WhiteElo'] as String?)?.trim();
      _pgnBlackElo = (tempGame.header['BlackElo'] as String?)?.trim();
      _pgnResult = (tempGame.header['Result'] as String?)?.trim();
      if (_pgnWhiteName != null && (_pgnWhiteName!.isEmpty || _pgnWhiteName == '?')) _pgnWhiteName = null;
      if (_pgnBlackName != null && (_pgnBlackName!.isEmpty || _pgnBlackName == '?')) _pgnBlackName = null;

      final replay = chess.Chess.fromFEN(startFen);
      var node = _rootNode;
      var imported = 0;

      for (final san in sanHistory) {
        if (!replay.move(san)) {
          AppLogger.log('[AnalysisStudio] ⚠️ PGN uvoz zaustavljen na nelegalnom potezu: $san');
          break;
        }
        final moveObj = replay.history.last.move;
        final uci = moveObj.fromAlgebraic +
            moveObj.toAlgebraic +
            (moveObj.promotion?.name ?? '');
        node = node.addChild(childFen: replay.fen, san: san, uci: uci);
        imported++;
      }

      // Land on the final position; the tree is there to walk back through.
      setState(() {
        _currentNode = node;
        _chessGame = chess.Chess.fromFEN(node.fen);
        _boardController.loadFen(node.fen);
      });
      _saveDraft();
      _triggerEngineAnalysis();

      AppLogger.log('[AnalysisStudio] 📥 PGN uvezen: $imported poteza od ${sanHistory.length}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ PGN učitan — $imported poteza u stablu.'),
          backgroundColor: Colors.teal,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška pri uvozu PGN-a: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Entry point for the cloud icon: lets the user save the current tree or
  /// browse/load/delete previously saved ones. Requires a logged-in account
  /// since the data lives server-side, scoped to the user.
  void _showSavedAnalysesDialog() {
    dialogs.showSavedAnalysesDialog(
      context,
      userSession: widget.userSession,
      rootNode: _rootNode,
      onLoad: _loadSavedAnalysis,
    );
  }

  Future<void> _loadSavedAnalysis(SavedAnalysisSummary summary) async {
    final confirmed = await dialogs.confirmReplaceAnalysisDialog(context, summary.title);
    if (!confirmed) return;

    final loadedRoot = await AnalysisPersistenceService.instance.loadAnalysis(
      id: summary.id,
      userToken: widget.userSession.token,
    );

    if (!mounted) return;

    if (loadedRoot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Učitavanje nije uspelo. Proverite konekciju.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _rootNode = loadedRoot;
      _currentNode = loadedRoot;
      _chessGame = chess.Chess.fromFEN(loadedRoot.fen);
      _boardController.loadFen(loadedRoot.fen);
      final side = loadedRoot.fen.split(' ')[1];
      _orientation = side == 'b' ? PlayerColor.black : PlayerColor.white;
    });
    _saveDraft();
    _triggerEngineAnalysis();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✅ Učitano: "${summary.title}"'), backgroundColor: Colors.teal),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    // Landscape: board width must leave room for the panel column next to it
    // (kMinPanelWidth), so its true ceiling is screen-derived, not a fixed
    // constant — on a big monitor the board should actually get bigger.
    const double kMinPanelWidth = 300.0;
    final double landscapeHeightBudget = screenSize.height - 120.0 - (_showEvalBar ? 30.0 : 0.0);
    final double boardSize = (isLandscape
            ? math.min(landscapeHeightBudget, screenSize.width - kMinPanelWidth - 28.0)
            : math.min(screenSize.width - 32.0, 700.0)) *
        AppSettingsService.instance.boardSizeScale;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8.0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.biotech, color: context.colors.accent, size: 20),
            const SizedBox(width: 6),
            Flexible(
              child: (_pgnWhiteName != null || _pgnBlackName != null)
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_pgnWhiteName ?? '?'}${_pgnWhiteElo != null ? ' ($_pgnWhiteElo)' : ''} — ${_pgnBlackName ?? '?'}${_pgnBlackElo != null ? ' ($_pgnBlackElo)' : ''}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: AppText.title,
                        ),
                        if (_pgnResult != null && _pgnResult!.isNotEmpty && _pgnResult != '*')
                          Text(
                            _pgnResult!,
                            style: AppText.micro.copyWith(color: context.colors.textMuted),
                          ),
                      ],
                    )
                  : const Text(
                      'Tabla za Analizu',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: AppText.title,
                    ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.terminal, color: context.colors.warning),
            tooltip: 'Logovi Engine-a 📜',
            onPressed: () => dialogs.showLogsDialog(context),
          ),
          IconButton(
            icon: Icon(Icons.auto_awesome, color: context.colors.warning),
            tooltip: 'Automatska Analiza ⚡',
            onPressed: _showAutoAnalysisDialog,
          ),
          IconButton(
            icon: Icon(Icons.trending_flat, color: context.colors.accent),
            tooltip: 'Produži granu (najbolja linija motora)',
            onPressed: _showQuickExtendDialog,
          ),
          IconButton(
            icon: Icon(Icons.fact_check, color: context.colors.accent),
            tooltip: 'Analiziraj celu partiju',
            onPressed: _showGameReviewDialog,
          ),
          IconButton(
            icon: Icon(Icons.extension, color: context.colors.accent),
            tooltip: 'Sačuvane vežbe',
            onPressed: _showSavedPuzzleSetsDialog,
          ),
          IconButton(
            icon: Icon(Icons.share, color: context.colors.info),
            tooltip: 'Izvezi PGN',
            onPressed: _exportPgn,
          ),
          IconButton(
            icon: Icon(Icons.cloud_outlined, color: context.colors.info),
            tooltip: 'Sačuvane analize',
            onPressed: _showSavedAnalysesDialog,
          ),
          IconButton(
            icon: Icon(Icons.settings, color: context.colors.textMuted),
            tooltip: 'Podešavanja',
            onPressed: _openAppSettings,
          ),
          IconButton(
            icon: Icon(Icons.tune, color: context.colors.accent),
            tooltip: 'Unos Pozicije / PGN',
            onPressed: _showSetupDialog,
          ),
          IconButton(
            icon: Icon(
              _orientation == PlayerColor.white ? Icons.rotate_right : Icons.rotate_left,
              color: context.colors.warning,
            ),
            tooltip: 'Okreni Tablu',
            onPressed: () {
              setState(() {
                _orientation = _orientation == PlayerColor.white ? PlayerColor.black : PlayerColor.white;
              });
              _saveDraft();
            },
          ),
        ],
      ),
      body: isLandscape ? _buildLandscapeLayout(boardSize) : _buildPortraitLayout(boardSize),
    );
  }

  Widget _buildPortraitLayout(double boardSize) {
    return Column(
      children: [
        if (_activePuzzleSet != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: _buildPuzzleSetBar(),
          ),
        // Static Fixed Board at top
        Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
          child: Center(
            child: SizedBox(
              width: boardSize,
              height: boardSize,
              child: Card(
                elevation: 4,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _buildBoardWidget(boardSize - 16.0),
                ),
              ),
            ),
          ),
        ),

        // Navigation Toolbar
        _buildNavigationToolbar(),
        _buildCurrentCommentPanel(),

        // Scrollable Controls Below Board
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                if (_showEvalBar) ...[
                  HorizontalEvalBarWidget(
                    eval: _currentRawEval,
                    evalString: _currentEvalString,
                    depth: _currentEvalDepth,
                    orientation: _orientation,
                  ),
                  const SizedBox(height: 8),
                ],
                _buildPositionInfoPanel(),
                _buildAnalysisAndTreeSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(double boardSize) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Side: Board & Eval Bar
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_activePuzzleSet != null)
                SizedBox(
                  width: boardSize,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: _buildPuzzleSetBar(),
                  ),
                ),
              SizedBox(
                width: boardSize,
                height: boardSize,
                child: Card(
                  elevation: 4,
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: _buildBoardWidget(boardSize - 12.0),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              if (_showEvalBar) ...[
                SizedBox(
                  width: boardSize,
                  child: HorizontalEvalBarWidget(
                    eval: _currentRawEval,
                    evalString: _currentEvalString,
                    depth: _currentEvalDepth,
                    orientation: _orientation,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              SizedBox(
                width: boardSize,
                child: _buildNavigationToolbar(),
              ),
              SizedBox(
                width: boardSize,
                child: _buildCurrentCommentPanel(),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Right Side: Tree & Engine Analysis
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildPositionInfoPanel(),
                  _buildAnalysisAndTreeSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Opening/endgame phase banner plus the Syzygy and opening-explorer panels
  /// for [_currentNode]. Shared by portrait and landscape layouts.
  Widget _buildPositionInfoPanel() {
    return Builder(
      builder: (ctx) {
        final phaseInfo = PositionInfoService.analyzeFen(_currentNode.fen);
        final bookEntry = OpeningBookService.instance.lookupByFen(_currentNode.fen);
        final displayOpeningName = (!phaseInfo.isEndgame && bookEntry != null)
            ? '${bookEntry.eco} · ${bookEntry.name}'
            : phaseInfo.openingName;
        return Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: phaseInfo.isEndgame ? Colors.indigo.shade900 : Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: phaseInfo.isEndgame ? Colors.cyanAccent : Colors.tealAccent,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    phaseInfo.isEndgame ? Icons.auto_awesome : Icons.menu_book,
                    color: phaseInfo.isEndgame ? Colors.cyanAccent : Colors.tealAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayOpeningName,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            if (AppSettingsService.instance.isPanelVisible('tactical_motifs'))
              TacticalFindingsPanelWidget(result: _computeTacticalFindings()),
            if (AppSettingsService.instance.isPanelVisible('positional_factors'))
              PositionalFindingsPanelWidget(result: _computePositionalFindings()),
            if (AppSettingsService.instance.isPanelVisible('syzygy'))
              SyzygyPanelWidget(
                isEligible: phaseInfo.isSyzygyReady,
                isLoading: _syzygyLoading,
                result: _syzygyResult,
                onMoveSelected: _playUciMove,
              ),
            if (AppSettingsService.instance.isPanelVisible('opening_explorer'))
              OpeningExplorerPanelWidget(
                hasToken: OpeningExplorerService.hasToken && AppSettingsService.instance.openingDbSource != 'chessdb',
                isLoading: _openingExplorerLoading,
                result: _openingExplorerResult,
                minRating: _openingExplorerMinRating,
                onMoveSelected: _playUciMove,
                onMinRatingChanged: _onOpeningExplorerMinRatingChanged,
                chessDbResult: _chessDbResult,
                isLoadingChessDb: _chessDbLoading,
              ),
          ],
        );
      },
    );
  }

  /// Move tree plus the engine analysis panel for [_currentNode]. Shared by
  /// portrait and landscape layouts.
  Widget _buildAnalysisAndTreeSection() {
    return Column(
      children: [
        if (AppSettingsService.instance.isPanelVisible('move_tree'))
          AnalysisMoveTreeWidget(
            rootNode: _rootNode,
            activeNode: _currentNode,
            maxEvalDisplayCutoff: _lastAutoAnalysisDeltaCutoff,
            onSelectNode: _jumpToNode,
            onPromoteNode: (node) {
              setState(() {
                node.parent?.promoteToMainLine(node);
              });
              _saveDraft();
            },
            onDeleteNode: (node) {
              setState(() {
                node.parent?.removeChild(node);
                if (_currentNode.id == node.id && node.parent != null) {
                  _jumpToNode(node.parent!);
                }
              });
              _saveDraft();
            },
          ),
        const SizedBox(height: 8),
        if (AppSettingsService.instance.isPanelVisible('engine_analysis'))
          StockfishAnalysisWidget(
            isEngineEnabled: _showEvaluation,
            isAllowedToUseEngine: true,
            isOnline: _stockfishService.isOnline,
            isCustomEngineActive: _stockfishService.isCustomEngineActive,
            onOpenSettings: isCustomEngineSupported ? _openEngineSettings : null,
            onForceRestart: _triggerEngineAnalysis,
            lines: _engineLinesMap.values.toList(),
            orientation: _orientation,
            isShowEvalBarEnabled: _showEvalBar,
            onToggleShowEvalBar: () {
              setState(() {
                _showEvalBar = !_showEvalBar;
              });
              _triggerEngineAnalysis();
            },
            onToggleEngine: () {
              setState(() {
                _showEvaluation = !_showEvaluation;
              });
              _triggerEngineAnalysis();
            },
          ),
      ],
    );
  }

  void _handleTapMoveInput(String square) {
    final game = _chessGame;
    if (game == null) return;
    final piece = game.get(square);
    final isOwnPiece = piece != null && piece.color == game.turn;

    if (isOwnPiece) {
      setState(() => _selectedSquareForTap = (square == _selectedSquareForTap) ? null : square);
      return;
    }

    final from = _selectedSquareForTap;
    if (from == null || from == square) return;

    setState(() => _selectedSquareForTap = null);
    // Auto-queen, same as the rest of the app's tap-to-move; the chess
    // package ignores the promotion key for non-promoting moves.
    _handleUserMove(from, square, 'q');
  }

  Widget _buildBoardWidget(double size) {
    return Stack(
      children: [
        ChessBoard(
          controller: _boardController,
          boardOrientation: _orientation,
          onMove: () {
            final history = _boardController.game.history;
            if (history.isNotEmpty) {
              final lastMove = history.last;
              final from = lastMove.move.fromAlgebraic;
              final to = lastMove.move.toAlgebraic;
              final promo = lastMove.move.promotion?.name ?? '';
              _handleUserMove(from, to, promo, animate: false);
            }
          },
        ),
        // Translucent, so the tap overlay joins the gesture arena without
        // reporting a hit — dragging still reaches the board beneath it.
        Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (details) {
                final square = getSquareFromOffset(details.localPosition, size, _orientation);
                _handleTapMoveInput(square);
              },
              child: CustomPaint(
                size: Size(size, size),
                painter: _selectedSquareForTap != null
                    ? SelectedSquarePainter(
                        selectedSquare: _selectedSquareForTap!,
                        boardSize: size,
                        orientation: _orientation,
                      )
                    : null,
              ),
            ),
          ),
        if (_lastMoveFrom != null && _lastMoveTo != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                size: Size(size, size),
                painter: ChessBoardPainter(
                  arrows: const [],
                  boardSize: size,
                  orientation: _orientation,
                  lastMoveFrom: _lastMoveFrom,
                  lastMoveTo: _lastMoveTo,
                ),
              ),
            ),
          ),
        if (_showEngineOverlay && _engineArrows.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                size: Size(size, size),
                painter: ChessBoardPainter(
                  arrows: const [],
                  engineArrows: _engineArrows,
                  boardSize: size,
                  orientation: _orientation,
                ),
              ),
            ),
          ),
        for (final pendingAnim in _pendingAnimations)
          AnimatedMovePiece(
            key: ValueKey(pendingAnim),
            pending: pendingAnim,
            boardSize: size,
            orientation: _orientation,
            duration: Duration(milliseconds: AppSettingsService.instance.moveAnimationDurationMs),
            onCompleted: () {
              if (mounted) setState(() => _pendingAnimations.remove(pendingAnim));
            },
          ),
      ],
    );
  }

  /// Shown above the board while stepping through an extracted puzzle set:
  /// which puzzle this is, and controls to move to the next/previous one or
  /// leave puzzle mode back to free analysis.
  Widget _buildPuzzleSetBar() {
    final set = _activePuzzleSet;
    if (set == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.teal.shade900,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20, color: Colors.white),
            tooltip: 'Prethodna vežba',
            onPressed: _activePuzzleIndex > 0 ? () => _goToPuzzle(-1) : null,
          ),
          Text(
            'Vežba ${_activePuzzleIndex + 1} / ${set.length}',
            style: AppText.bodyBold.copyWith(color: Colors.white),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20, color: Colors.white),
            tooltip: 'Sledeća vežba',
            onPressed: _activePuzzleIndex < set.length - 1 ? () => _goToPuzzle(1) : null,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: Colors.white70),
            tooltip: 'Zatvori vežbe',
            onPressed: _exitPuzzleSet,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.first_page, size: 20),
            tooltip: 'Početak linije (<<)',
            onPressed: _currentNode.isRoot ? null : _goFirst,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            tooltip: 'Prethodni Potez (<)',
            onPressed: _currentNode.isRoot ? null : _goPrevious,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            tooltip: 'Sledeći Potez (>)',
            onPressed: _currentNode.children.isEmpty ? null : _goNext,
          ),
          IconButton(
            icon: const Icon(Icons.last_page, size: 20),
            tooltip: 'Kraj Glavne Linije (>>)',
            onPressed: _currentNode.children.isEmpty ? null : _goLast,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.comment, size: 18, color: Colors.lightBlueAccent),
            tooltip: 'Dodaj Komentar',
            onPressed: _showCommentDialog,
          ),
          IconButton(
            icon: _isGeneratingAiComment
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome, size: 18, color: Colors.tealAccent),
            tooltip: 'Generiši AI komentar',
            onPressed: (_isGeneratingAiComment || _currentNode.isRoot) ? null : _generateAiComment,
          ),
          IconButton(
            icon: const Icon(Icons.style, size: 18, color: Colors.amberAccent),
            tooltip: 'NAG Simboli (!, ?)',
            onPressed: _showNagSelector,
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: context.colors.danger),
            tooltip: 'Obriši ovaj potez (i granu iza njega)',
            onPressed: _currentNode.isRoot ? null : _confirmDeleteCurrentNode,
          ),
        ],
      ),
    );
  }

  /// Shows [_currentNode]'s move + NAG + comment right under the board, so
  /// browsing an already-annotated game (or one just run through "Analiziraj
  /// partiju") surfaces its commentary without having to go hunting for it
  /// in the move-tree text below. Collapses to nothing on a move with no
  /// comment/NAG, so it doesn't add empty chrome while stepping through an
  /// unannotated game.
  Widget _buildCurrentCommentPanel() {
    final comment = _currentNode.comment;
    final nag = _currentNode.nag;
    if (comment.isEmpty && nag == null) return const SizedBox.shrink();

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _showCommentDialog,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.colors.info.withValues(alpha: 0.35)),
        ),
        // A long auto-generated comment (several concatenated findings) can
        // wrap several lines — capping the panel's height and letting it
        // scroll internally keeps it from pushing the board/toolbar around,
        // or overflowing the layout on the landscape side column, which has
        // no scrollable ancestor of its own to absorb extra height.
        constraints: const BoxConstraints(maxHeight: 90),
        child: SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.comment, size: 16, color: context.colors.info),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: AppText.caption.copyWith(color: context.colors.textPrimary),
                    children: [
                      if (_currentNode.moveSan != null)
                        TextSpan(
                          text: _currentNode.moveSan,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      if (nag != null)
                        TextSpan(
                          text: ' $nag',
                          style: TextStyle(color: context.colors.warning, fontWeight: FontWeight.bold),
                        ),
                      if (comment.isNotEmpty) TextSpan(text: '  $comment'),
                    ],
                  ),
                ),
              ),
              Icon(Icons.edit, size: 14, color: context.colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  /// Counts [node] itself plus every descendant — used only to tell the user
  /// how much a deletion actually removes (a single move vs. a long branch).
  int _subtreeSize(AnalysisNode node) {
    var count = 1;
    for (final child in node.children) {
      count += _subtreeSize(child);
    }
    return count;
  }

  /// Deletes [_currentNode] and everything under it (the whole branch from
  /// that move onward), after confirming — this can't be undone, and a
  /// sideline can easily hide many moves behind one node.
  Future<void> _confirmDeleteCurrentNode() async {
    final node = _currentNode;
    final parent = node.parent;
    if (parent == null) return;

    final removedCount = _subtreeSize(node);
    final label = node.moveSan ?? 'ovaj potez';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text('Obriši potez?', style: TextStyle(color: context.colors.textPrimary)),
        content: Text(
          removedCount > 1
              ? 'Ovo briše "$label" i svih preostalih $removedCount poteza u ovoj grani (uključujući varijacije). Ne može se opozvati.'
              : 'Ovo briše "$label". Ne može se opozvati.',
          style: TextStyle(color: context.colors.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Otkaži')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    parent.removeChild(node);
    _jumpToNode(parent);
  }
}
