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
import 'package:chess_app/features/analysis_studio/services/analysis_persistence_service.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_draft_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/auto_analysis_dialog.dart';
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

  PlayerColor _orientation = PlayerColor.white;

  // Engine evaluation state
  bool _showEvaluation = true;
  bool _showEvalBar = true;
  double _currentRawEval = 0.0;
  String _currentEvalString = '0.00';
  int _currentEvalDepth = 18;
  Map<int, AnalysisLine> _engineLinesMap = {};
  List<EngineArrow> _engineArrows = [];
  final bool _showEngineOverlay = true;

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

        double parsedEval = 0.0;
        final numVal = double.tryParse(evaluation);
        if (numVal != null) {
          parsedEval = numVal;
        } else if (evaluation.contains('M')) {
          final mateNum = int.tryParse(evaluation.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
          parsedEval = evaluation.contains('-') ? (-10000.0 + mateNum) : (10000.0 - mateNum);
        }

        if (multipv == 1) {
          setState(() {
            _currentRawEval = parsedEval;
            _currentEvalString = evaluation;
            _currentEvalDepth = depth;
            _currentNode.eval = parsedEval;
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

    AppLogger.log('[OpeningExplorer] 🔍 hasToken=${OpeningExplorerService.hasToken} | FEN: ${_currentNode.fen}');

    if (!OpeningExplorerService.hasToken) {
      AppLogger.log('[OpeningExplorer] ⛔ Nema tokena — koristim ChessDB fallback');
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
    setState(() {
      _currentNode = node;
      _chessGame = chess.Chess.fromFEN(node.fen);
      _boardController.loadFen(node.fen);
      _engineLinesMap.clear();
    });
    _saveDraft();
    // Show this node's stored candidates immediately; the engine may still be
    // several seconds away from producing lines for the new position.
    _refreshArrows();
    _triggerEngineAnalysis();
  }

  void _handleUserMove(String from, String to, String promotion) {
    if (_chessGame == null) return;

    final moveMap = {
      'from': from,
      'to': to,
      if (promotion.isNotEmpty) 'promotion': promotion,
    };

    final success = _chessGame!.move(moveMap);
    if (success) {
      String san = '$from$to';
      try {
        final dynamic lastHist = _chessGame!.history.last;
        san = (lastHist.san as String?) ?? '$from$to';
      } catch (_) {}
      final uci = '$from$to${promotion.toLowerCase()}';
      final newFen = _chessGame!.fen;

      final childNode = _currentNode.addChild(
        childFen: newFen,
        san: san,
        uci: uci,
      );

      setState(() {
        _currentNode = childNode;
        _boardController.loadFen(newFen);
        _engineLinesMap.clear();
      });

      _saveDraft();
      _refreshArrows();
      _triggerEngineAnalysis();
    }
  }

  void _goFirst() {
    _jumpToNode(_rootNode);
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

  void _showCommentDialog() {
    dialogs.showCommentDialog(context, _currentNode.comment, (comment) {
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
        onAnalysisCompleted: () {
          // The start node now has candidate children — surface them as arrows.
          _refreshArrows();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚡ Automatska analiza uspešno završena i sačuvana u stablo!'), backgroundColor: Colors.amber),
          );
        },
      ),
    );
  }

  void _exportPgn() {
    dialogs.exportPgnDialog(context, _rootNode);
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
  void _importPgn(String pgn) {
    try {
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
            const Flexible(
              child: Text(
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
            if (AppSettingsService.instance.isPanelVisible('syzygy'))
              SyzygyPanelWidget(
                isEligible: phaseInfo.isSyzygyReady,
                isLoading: _syzygyLoading,
                result: _syzygyResult,
                onMoveSelected: _playUciMove,
              ),
            if (AppSettingsService.instance.isPanelVisible('opening_explorer'))
              OpeningExplorerPanelWidget(
                hasToken: OpeningExplorerService.hasToken,
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
              _handleUserMove(from, to, promo);
            }
          },
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
      ],
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
            tooltip: 'Početak (<<)',
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
            icon: const Icon(Icons.style, size: 18, color: Colors.amberAccent),
            tooltip: 'NAG Simboli (!, ?)',
            onPressed: _showNagSelector,
          ),
        ],
      ),
    );
  }
}
