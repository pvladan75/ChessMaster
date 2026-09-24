import 'package:chess_app/services/account_local_state.dart';
import 'package:chess_app/services/app_logger.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'package:chess/chess.dart' as chess;
import 'package:chess_app/features/analysis_studio/services/game_from_moves.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/studio_lesson_step.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node_cursor.dart';
import 'package:chess_app/widgets/game_screen/move_keyboard_shortcuts.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/breakpoints.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/features/analysis_studio/widgets/analysis_panels_sheet.dart';
import 'package:chess_app/features/analysis_studio/widgets/board_setup_dialog.dart';
import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess_app/widgets/board_view_menu.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/landscape_board_layout.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/widgets/promotion_picker.dart';
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
import 'package:chess_app/features/analysis_studio/widgets/opening_explorer_panel_widget.dart';
import 'package:chess_app/features/analysis_studio/services/opening_book_service.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/teach_menu.dart';
import 'package:chess_app/core/models/tactical_motif.dart';
import 'package:chess_app/core/services/tactical_motif_detector.dart';
import 'package:chess_app/core/models/positional_factor.dart';
import 'package:chess_app/core/services/positional_evaluator_service.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_persistence_service.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_draft_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/auto_analysis_dialog.dart';
import 'package:chess_app/features/analysis_studio/widgets/quick_extend_dialog.dart';
import 'package:chess_app/features/analysis_studio/widgets/game_review_dialog.dart';
import 'package:chess_app/features/analysis_studio/services/game_review_runner.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/core/services/eval_parsing.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_import.dart';
import 'package:chess_app/services/puzzle_api_service.dart';
import 'package:chess_app/features/analysis_studio/dialogs/analysis_studio_dialogs.dart'
    as dialogs;
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/board/skinned_chess_board.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/library/widgets/course_picker_dialog.dart';
import 'package:chess_app/features/tutorial_studio/tutorial_editor_entry.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_handover.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_library_card.dart';
import 'package:chess_app/features/tutorial_studio/widgets/game_tutorial_flow.dart';

class AnalysisStudioScreen extends StatefulWidget {
  final UserSession userSession;
  final String? initialFen;

  /// A whole game to open, with the cursor on one of its plies — how an archive
  /// mistake opens its game (D4 of `docs/PLAN-SKELET.md`). Like [initialFen],
  /// it wins over the draft kept on the device: the caller asked for this game.
  final AnalysisGame? initialGame;

  /// A whole saved tree to open — variations, comments and arrows included —
  /// how the Library opens a saved analysis (phase 3 of
  /// `docs/PLAN-REORGANIZACIJA.md`). [initialGame] is a main line and would
  /// drop the sidelines; a tree that was saved with them is opened as it was
  /// saved. Wins over the device draft for the same reason the other two do.
  final AnalysisNode? initialTree;

  /// Opens the book scanner, when the caller has somewhere to open it from.
  ///
  /// It arrives here because the Analyse tab used to carry „Scan a book" in a
  /// row of its own above the board, and that row cost three screens' worth of
  /// height on a phone for two buttons (reported live 18.9.2026). „My games"
  /// had a second door — the card on Practise — so it simply went; this one had
  /// **none**: `/scan/saved` is only reachable after a scan, so deleting the
  /// button would have deleted the way into the scanner. It is in the toolbar
  /// instead, which is behind „More tools" on a phone and costs no height.
  final VoidCallback? onOpenScanner;

  /// The review's home; defaults to the app's one runner. A test passes its
  /// own so a review started on it lands on this screen without reaching the
  /// real singleton.
  final GameReviewRunner? reviewRunner;

  const AnalysisStudioScreen({
    super.key,
    required this.userSession,
    this.initialFen,
    this.initialGame,
    this.initialTree,
    this.onOpenScanner,
    this.reviewRunner,
  });

  @override
  State<AnalysisStudioScreen> createState() => _AnalysisStudioScreenState();
}

class _AnalysisStudioScreenState extends State<AnalysisStudioScreen>
    implements ReviewBoard {
  final ChessBoardController _boardController = ChessBoardController();
  final StockfishService _stockfishService = StockfishService();

  GameReviewRunner get _reviewRunner =>
      widget.reviewRunner ?? GameReviewRunner.instance;

  @override
  AnalysisNode get reviewRoot => _rootNode;

  @override
  void reviewLanded() {
    if (!mounted) return;
    setState(() {});
    _saveDraft();
  }

  /// The account wipe this screen was made under ([AccountLocalState.epoch]).
  /// Taken once, here: the Analyse tab outlives a sign-out by a frame, and its
  /// `dispose` flush must not hand this tree to the next account.
  final int _draftEpoch = AccountLocalState.epoch;

  /// Whether this screen is in front of the reader — see [_onShownChanged].
  ValueListenable<TickerModeData>? _shown;
  bool _engineReady = false;
  bool _engineAttached = false;

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

  // Engine evaluation state.
  //
  // **Off on arrival, both of them.** Asked for twice by the owner while
  // checking the reorganisation live — 17.9.2026 („U Analizu treba da se ulazi
  // sa ugašenim engin-om") and again on 18.9 against TODO-provera 177.4 —
  // and the reason is the tab: since the shell put Analyse behind one tap, the
  // screen is opened to look at a position far more often than to have it
  // judged, and an engine that starts itself spends the phone's battery, fills
  // the board with arrows and answers a question nobody asked. The toolbar's
  // two switches turn it on, and the screen lives as long as the tab does, so
  // it is asked for once per run rather than once per visit.
  bool _showEvaluation = false;
  bool _showEvalBar = false;
  double _currentRawEval = 0.0;
  String _currentEvalString = '0.00';
  int _currentEvalDepth = 18;
  Map<int, AnalysisLine> _engineLinesMap = {};
  List<EngineArrow> _engineArrows = [];
  final bool _showEngineOverlay = true;

  // deltaCutoff the auto-analysis tree was last generated with, so the tree
  // view's post-hoc display filter can cap its slider there instead of
  // offering a range that would silently do nothing above that value.

  // Syzygy tablebase state
  final SyzygyTablebaseService _syzygyService = SyzygyTablebaseService.instance;
  SyzygyResult? _syzygyResult;
  bool _syzygyLoading = false;
  int _syzygyRequestId = 0;

  // Opening explorer state
  final OpeningExplorerService _openingExplorerService =
      OpeningExplorerService.instance;
  OpeningExplorerResult? _openingExplorerResult;
  String? _openingExplorerReason;
  bool _openingExplorerLoading = false;
  int _openingExplorerRequestId = 0;

  // The tactical and positional findings are not shown on this screen
  // (22.9.2026): they are computed only for what [_generateAiComment]
  // sends to the AI, never because the board changed.
  final _tacticalDetector = const TacticalMotifDetector();
  final _positionalEvaluator = const PositionalEvaluatorService();

  bool _isGeneratingAiComment = false;

  @override
  void initState() {
    super.initState();
    final tree = widget.initialTree;
    final startFen = tree?.fen ??
        widget.initialGame?.startFen ??
        widget.initialFen ??
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    AppLogger.log(
        '[AnalysisStudio] 🎬 initState initialized with FEN: $startFen');
    _initAnalysisTree(startFen);
    final game = widget.initialGame;
    if (game != null) _loadGame(game);
    if (tree != null) _loadTree(tree);
    _initEngine();
    _reviewRunner.attachBoard(this);
    _stockfishService.held.addListener(_onEngineHeldChanged);
    AppSettingsService.instance.addListener(_onAppSettingsChanged);
    OpeningBookService.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    // An explicit initialFen, game or tree means the caller wants exactly
    // that (e.g. exported from a game), so it must not be overwritten by a
    // draft.
    if (widget.initialFen == null && game == null && tree == null) {
      _restoreDraft();
    }
  }

  /// The board size slider and the panel checkboxes are on this screen — its
  /// board menu and its Panels sheet — so what they change has to follow them
  /// while the screen is showing, not only after a page opened on top of it
  /// has closed. Both are read during build.
  void _onAppSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shown = TickerMode.getValuesNotifier(context);
    if (!identical(shown, _shown)) {
      _shown?.removeListener(_onShownChanged);
      _shown = shown..addListener(_onShownChanged);
    }
  }

  /// **Leaving this screen switches the engine off, and it stays off.** Asked
  /// for by the owner on 21.9.2026. The Analyse tab lives in the shell's
  /// `IndexedStack`, which keeps a hidden tab alive, so nothing used to tell
  /// the engine that nobody was looking any more.
  ///
  /// One signal covers both ways out: `TickerMode` is false for a tab the shell
  /// is not showing and for a route covered by an opaque one. A dialog or a
  /// sheet is not leaving — the board is still in front of the reader.
  ///
  /// Released rather than merely stopped: a screen pushed on top may be using
  /// the same engine, and `detach` stops this screen's search and hands the
  /// engine back to whoever is on top, where a bare `stopAnalysis` would stop
  /// theirs. Coming back takes the engine again, with both switches off.
  void _onShownChanged() {
    final shown = _shown?.value.enabled ?? true;
    if (shown) {
      if (_engineReady && !_engineAttached) _attachEngine();
      return;
    }
    if (_showEvaluation || _showEvalBar) {
      setState(() {
        _showEvaluation = false;
        _showEvalBar = false;
        _engineLinesMap.clear();
        _engineArrows.clear();
      });
      _refreshArrows();
    }
    if (_engineAttached) {
      _engineAttached = false;
      _stockfishService.detach(this);
    }
  }

  void _onEngineHeldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _shown?.removeListener(_onShownChanged);
    _stockfishService.held.removeListener(_onEngineHeldChanged);
    _reviewRunner.detachBoard(this);
    AppSettingsService.instance.removeListener(_onAppSettingsChanged);
    // A debounced write would be lost with this screen, so force it out first.
    unawaited(AnalysisDraftService.instance.flush(
      rootNode: _rootNode,
      currentNode: _currentNode,
      blackOrientation: _orientation == PlayerColor.black,
      epoch: _draftEpoch,
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
      epoch: _draftEpoch,
    );
  }

  /// The toolbar's actions, as icons on a wide screen and behind a menu on a
  /// narrow one.
  ///
  /// There are ten of them. An `AppBar` does not wrap or scroll its actions —
  /// it clips them, silently — so on a phone the last two were simply not
  /// reachable: "Settings" and "Setup Position / PGN" sat past the right
  /// edge with nothing to say they were there. Reported from a phone on
  /// 20.8.2026, and invisible in a release build, which paints no overflow
  /// warning.
  List<Widget> _toolbarActions(BuildContext context) {
    final actions = <_ToolAction>[
      _ToolAction(Icons.tune, context.colors.accent, 'Setup Position / PGN',
          _showSetupDialog),
      _ToolAction(Icons.fact_check, context.colors.accent, 'Review entire game',
          _showGameReviewDialog),
      _ToolAction(Icons.auto_awesome, context.colors.warning, 'Auto Analysis ⚡',
          _showAutoAnalysisDialog),
      _ToolAction(Icons.trending_flat, context.colors.accent,
          'Extend branch (engine best line)', _showQuickExtendDialog),
      // S2 of docs/PLAN-REORGANIZACIJA.md: the four doors into teaching
      // material — two "add to a tutorial" actions and two "start a new
      // tutorial" actions, the latter pair drawn only where the studio
      // exists — became one door and one sheet (`TeachMenuSheet`), and the
      // question of which of the six flows is asked inside it, after the tap.
      _ToolAction(Icons.school, context.colors.success, 'Use in a tutorial',
          _openTeachMenu),
      // Drawn only when it was given, like everything else in this bar
      // (rule 15): the screen is pushed from a dozen places and only the tab
      // has a scanner to offer.
      if (widget.onOpenScanner != null)
        _ToolAction(Icons.document_scanner_outlined, context.colors.info,
            'Scan a book', widget.onOpenScanner!),
      _ToolAction(Icons.share, context.colors.info, 'Export PGN', _exportPgn),
      _ToolAction(Icons.cloud_outlined, context.colors.info, 'Saved analyses',
          _showSavedAnalysesDialog),
      _ToolAction(Icons.view_quilt_outlined, context.colors.textMuted, 'Panels',
          () => showAnalysisPanelsSheet(context)),
      _ToolAction(Icons.settings, context.colors.textMuted, 'Settings',
          _openAppSettings),
      _ToolAction(Icons.terminal, context.colors.warning, 'Engine Logs 📜',
          () => dialogs.showLogsDialog(context)),
    ];

    Widget asIcon(_ToolAction a) => IconButton(
        icon: Icon(a.icon, color: a.color),
        tooltip: a.tooltip,
        onPressed: a.onPressed);

    // Kept out of the list and never folded into the overflow menu: it is the
    // one control here that changes what the board *looks* like, and it draws
    // its own state, which a `_ToolAction` cannot.
    const coordinates = BoardViewMenu(arrows: true, boardSize: true);

    if (Breakpoints.isWide(context)) {
      return [coordinates, ...actions.map(asIcon)];
    }

    // The two that start a piece of work stay on the bar; the rest are one tap
    // further away but reachable, which is the whole point.
    const visible = 2;
    return [
      coordinates,
      ...actions.take(visible).map(asIcon),
      PopupMenuButton<int>(
        icon: const Icon(Icons.more_vert),
        tooltip: 'More tools',
        onSelected: (index) => actions[index].onPressed(),
        itemBuilder: (context) => [
          for (var i = visible; i < actions.length; i += 1)
            PopupMenuItem<int>(
              value: i,
              child: Row(
                children: [
                  Icon(actions[i].icon, color: actions[i].color, size: 20),
                  const SizedBox(width: AppSpacing.md),
                  Flexible(child: Text(actions[i].tooltip)),
                ],
              ),
            ),
        ],
      ),
    ];
  }

  Future<void> _restoreDraft() async {
    final draft = await AnalysisDraftService.instance.load();
    if (!mounted || draft == null) return;

    setState(() {
      _rootNode = draft.rootNode;
      _currentNode = draft.resolveCurrentNode();
      _orientation =
          draft.blackOrientation ? PlayerColor.black : PlayerColor.white;
      _chessGame = chess.Chess.fromFEN(_currentNode.fen);
      _boardController.loadFen(_currentNode.fen);
      _engineLinesMap.clear();
    });
    _refreshArrows();
    _triggerEngineAnalysis();
    // Restored without a word. A notice with „Start over" used to follow, and
    // on 16.9.2026 the owner asked for it gone: it greeted every visit, and a
    // fresh board is in Setup Position, under „Starting Position".
  }

  /// [game] as the tree, standing on its cursor ply, with the board turned to
  /// the side the player had.
  /// Opens a saved tree whole, standing on its root.
  void _loadTree(AnalysisNode tree) {
    _rootNode = tree;
    _currentNode = tree;
    _chessGame = chess.Chess.fromFEN(tree.fen);
    _boardController.loadFen(tree.fen);
    final side = tree.fen.split(' ')[1];
    _orientation = side == 'b' ? PlayerColor.black : PlayerColor.white;
  }

  void _loadGame(AnalysisGame game) {
    final tree = analysisTreeFromMoves(game.startFen, game.uciMoves);
    _rootNode = tree.root;
    final node = nodeAtPly(_rootNode, game.cursorPly);
    _currentNode = node;
    _chessGame = chess.Chess.fromFEN(node.fen);
    _boardController.loadFen(node.fen);
    _orientation =
        game.blackOrientation ? PlayerColor.black : PlayerColor.white;
  }

  void _initAnalysisTree(String fen) {
    _rootNode = AnalysisNode(fen: fen);
    _currentNode = _rootNode;
    _chessGame = chess.Chess.fromFEN(fen);
    _boardController.loadFen(fen);
    final side = fen.split(' ')[1];
    _orientation = side == 'b' ? PlayerColor.black : PlayerColor.white;
    _pgnWhiteName = null;
    _pgnBlackName = null;
    _pgnWhiteElo = null;
    _pgnBlackElo = null;
    _pgnResult = null;
  }

  /// This board's analysis dials — see [EngineAnalysisDials]. Started from what
  /// was last chosen and changed here, on the board being looked at, rather
  /// than in Settings where the number also decided how strongly the engine
  /// plays.
  int _analysisDepth = AppSettingsService.instance.analysisDepth;
  int _analysisLines = AppSettingsService.instance.analysisLines;

  /// Re-asks the engine after a dial moves. Leaving the old lines up under a
  /// new depth reads as an engine that stopped working.
  void _applyAnalysisDials({int? depth, int? lines}) {
    setState(() {
      if (depth != null) _analysisDepth = depth;
      if (lines != null) _analysisLines = lines;
    });
    if (depth != null) AppSettingsService.instance.setAnalysisDepth(depth);
    if (lines != null) AppSettingsService.instance.setAnalysisLines(lines);
    _stockfishService.setMultiPV(_analysisLines);
    _triggerEngineAnalysis();
  }

  Future<void> _initEngine() async {
    await _stockfishService.initEngine();
    if (!mounted) return;
    _engineReady = true;
    // A screen that is already out of sight takes the engine when it comes
    // back ([_onShownChanged]), not now.
    if (_shown?.value.enabled ?? true) _attachEngine();

    // attach() already auto-triggers engine analysis for the current FEN
    // (StockfishService._activateTopSubscriber). Calling _triggerEngineAnalysis()
    // here too used to fire a second, near-simultaneous stop/position/go
    // sequence, and the two writes to the native engine's stdin raced and
    // corrupted each other (Stockfish would log "Unknown command: 'sstop'" or a
    // mangled FEN and silently drop the request). Only kick off the lookups
    // that attach() doesn't cover.
    _fetchSyzygyIfEligible();
    _fetchOpeningExplorerIfEligible();
  }

  void _attachEngine() {
    _engineAttached = true;
    // Set before attach() so the auto-triggered first analysis (fired
    // synchronously inside attach(), see below) already uses the configured
    // MultiPV count instead of whatever the previous screen left behind.
    _stockfishService.setMultiPV(_analysisLines);
    _stockfishService.attach(
      this,
      getFen: () => _currentNode.fen,
      isEnabled: () => _showEvaluation || _showEvalBar,
      // A position that is not a possible game never reaches the engine, and
      // the reader is told why rather than left with a board that quietly never
      // evaluates. Reported live 30.8.2026 as a crash: a board set up by hand
      // with no king, imported here, engine switched on.
      onRefused: (reason) {
        if (!mounted) return;
        AppFeedback.show(
            context,
            () => SnackBar(
                  content: Text('Engine cannot calculate: $reason'),
                  backgroundColor: context.colors.danger,
                ));
      },
      onEvaluation: (evaluation, bestMove, continuation, multipv, depth,
          isFinal, analyzedFen) {
        if (!mounted) return;
        if (!_showEvaluation && !_showEvalBar) return;

        final parsedEval = parseWhiteRelativeEval(evaluation) ?? 0.0;

        if (multipv == 1) {
          setState(() {
            _currentRawEval = parsedEval;
            _currentEvalString = evaluation;
            _currentEvalDepth = depth;
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

    setState(() {
      _openingExplorerLoading = true;
      _openingExplorerResult = null;
      _openingExplorerReason = null;
    });

    final lookup = await _openingExplorerService.lookup(_currentNode.fen);
    if (!mounted || reqId != _openingExplorerRequestId) return;

    if (!lookup.isAvailable) {
      setState(() {
        _openingExplorerReason = lookup.reason;
        _openingExplorerResult = null;
        _openingExplorerLoading = false;
      });
      return;
    }

    final result = lookup.result;
    AppLogger.log(
        '[OpeningExplorer] 📊 Result: ${result == null ? "empty" : "${result.moves.length} moves, ${result.total} games"}');

    setState(() {
      _openingExplorerResult = result;
      _openingExplorerReason = null;
      _openingExplorerLoading = false;
    });
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
    AppLogger.log(
        '[AnalysisStudio] ⚡ _triggerEngineAnalysis fired | showEval: $_showEvaluation | showEvalBar: $_showEvalBar | Current FEN: ${_currentNode.fen}');
    _fetchSyzygyIfEligible();
    _fetchOpeningExplorerIfEligible();
    if (_showEvaluation || _showEvalBar) {
      // Validate FEN before sending to engine
      try {
        final testGame = chess.Chess.fromFEN(_currentNode.fen);
        AppLogger.log(
            '[AnalysisStudio] ✅ FEN is valid for chess game: ${_currentNode.fen}');
      } catch (e) {
        AppLogger.log(
            '[AnalysisStudio ERROR] ❌ Invalid FEN string: ${_currentNode.fen} | Error: $e');
      }

      _stockfishService.stopAnalysis();
      _stockfishService.setMultiPV(_analysisLines);
      _stockfishService.analyzePosition(_currentNode.fen,
          depth: _analysisDepth);
    } else {
      AppLogger.log(
          '[AnalysisStudio] ⏸️ Engine evaluation disabled by user switch. Stopping analysis.');
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

    final isWhiteToMove =
        node.fen.split(' ').length > 1 && node.fen.split(' ')[1] == 'w';

    // In the order they were generated, which for an auto-generated tree is
    // already best-first: the generator sorts its candidate lines by score
    // before it adds them. Re-sorting here needed a number on the node, and
    // the node no longer carries one.
    final ranked = node.children
        .where((c) => c.moveUci != null && c.moveUci!.length >= 4)
        .toList();

    final arrows = <EngineArrow>[];
    for (var i = 0; i < ranked.length; i++) {
      final child = ranked[i];
      final uci = child.moveUci!;
      arrows.add(EngineArrow(
        from: uci.substring(0, 2),
        to: uci.substring(2, 4),
        evalText: child.moveSan ?? '',
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
  void _handleUserMove(String from, String to, String promotion,
      {bool animate = true}) {
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
    for (final m in legalMoves(_chessGame!)) {
      if (m['from'] == from && m['to'] == to) {
        if (promo == null ||
            m['promotion'] == promo ||
            m['promotion'] == promo.toLowerCase()) {
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

      setState(() {
        _currentNode = childNode;
        _boardController.loadFen(newFen);
        _engineLinesMap.clear();
      });
      // Read the piece back from its destination (post-move) rather than
      // using movingPiece directly: on a promotion, the piece sitting on
      // `to` is already the queen the real board now shows, while
      // movingPiece is still the pre-move pawn.
      final animatedPiece = _chessGame!.get(to) ?? movingPiece;
      if (animate && animatedPiece != null) {
        _triggerMoveAnimation(from, to, animatedPiece);
      }

      _saveDraft();
      _refreshArrows();
      _triggerEngineAnalysis();
    }
  }

  void _triggerMoveAnimation(String from, String to, chess.Piece movingPiece) {
    final durationMs = AppSettingsService.instance.moveAnimationDurationMs;
    if (durationMs <= 0) return;
    setState(() {
      _pendingAnimations
          .add(PendingMoveAnimation(from: from, to: to, piece: movingPiece));
    });
  }

  /// Orientation is part of the saved draft, so flipping persists the board
  /// the way the user left it rather than resetting on the next visit.
  void _flipBoard() {
    setState(() {
      _orientation = _orientation == PlayerColor.white
          ? PlayerColor.black
          : PlayerColor.white;
    });
    _saveDraft();
  }

  /// The move's comment, as the reader wrote it — a plain text box. It used
  /// to offer the tactical and positional findings as a checklist; since
  /// 22.9.2026 those findings are for the AI only.
  void _showCommentDialog() {
    dialogs.showCommentDialog(context, _currentNode.comment, (comment) {
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
  ({List<Map<String, dynamic>> tactical, List<Map<String, dynamic>> positional})
      _findingsPairFor(
    String beforeFen,
    String afterFen,
    String lastMoveUci,
  ) {
    final tacticalDiff = _tacticalDetector.explainMove(
        beforeFen: beforeFen, afterFen: afterFen, lastMoveUci: lastMoveUci);
    final positionalDiff = _positionalEvaluator.explainMove(
        beforeFen: beforeFen, afterFen: afterFen, lastMoveUci: lastMoveUci);
    return (
      tactical: [...tacticalDiff.created, ...tacticalDiff.resolved]
          .map(_motifFindingToJson)
          .toList(),
      positional: [...positionalDiff.created, ...positionalDiff.resolved]
          .map(_positionalFindingToJson)
          .toList(),
    );
  }

  /// Sends the move's tactical/positional finding diff plus its eval swing
  /// to the backend's Gemini-backed endpoint, then opens the comment editor
  /// pre-filled with the generated prose — reviewable and editable there,
  /// nothing is saved until the user hits "Save". This is the one place on
  /// the screen the findings are computed.
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
            final promo = best.bestMoveLan.length > 4
                ? best.bestMoveLan.substring(4, 5)
                : null;
            try {
              moveOk = altGame.move({
                'from': from,
                'to': to,
                if (promo != null) 'promotion': promo
              });
            } catch (_) {}
          }
          if (moveOk) {
            final pair =
                _findingsPairFor(parent.fen, altGame.fen, best.bestMoveLan);
            engineAlternativeData = {
              'moveSan': best.bestMoveSan.isNotEmpty
                  ? best.bestMoveSan
                  : best.bestMoveLan,
              'eval': best.evaluation,
              'tacticalFindings': pair.tactical,
              'positionalFindings': pair.positional,
            };
          }
        }
      }
    } catch (e) {
      print(
          '[AnalysisStudio] Engine alternative query for AI comment failed: $e');
    } finally {
      // Resume live analysis for the position actually on screen.
      _triggerEngineAnalysis();
    }

    // Cheap fallback: if there's no fresh engine alternative, but the game
    // actually continued past this move, that reply's eval is already
    // sitting in the tree — free forward-looking context, no extra query.
    // There used to be a cheap fallback here: the reply already in the tree
    // carried an eval, so it came along as free forward-looking context. The
    // node no longer stores one, so the comment is written from the tactical
    // and positional findings and from a fresh engine alternative when there
    // is one.
    const Map<String, dynamic>? nextMoveEvalData = null;

    String? aiComment;
    try {
      aiComment = await PuzzleApiService.instance.generateMoveComment(
        moveSan: _currentNode.moveSan ?? '',
        evalBefore: null,
        evalAfter: null,
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
      AppFeedback.show(
        context,
        () => SnackBar(
            content: const Text('Error generating AI comment.'),
            backgroundColor: context.colors.danger),
      );
      return;
    }

    dialogs.showCommentDialog(context, aiComment, (comment) {
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
        onAnalysisCompleted: (_) {
          // The start node now has candidate children — surface them as arrows.
          // The cutoff it used is no longer kept: it capped a display filter
          // that read the eval off each node, and neither survives.
          _refreshArrows();
          AppFeedback.show(
            context,
            () => SnackBar(
                content: const Text(
                    '⚡ Automatic analysis completed successfully and saved to tree!'),
                backgroundColor: context.colors.warning),
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

  /// Opens the step editor on a lesson the trainer picks.
  ///
  /// §6 of `docs/PLAN-INTERAKTIVNA-LEKCIJA.md` puts the authoring surface here,
  /// beside the button that makes a step: the studio is where the tree, the
  /// comments and the arrows already are.
  ///
  /// Phase 7c, 6.9.2026, and it exists because phase 7b shipped a panel nothing
  /// opened. Every gate passed — the widget was built, tested and formatted —
  /// because what was missing was not code but a caller, and a test that pumps
  /// a widget directly proves it works without proving anyone can reach it.
  /// `lesson_editor_test.dart` now fails if this method stops constructing it.
  Future<void> _editLessonSteps() async {
    final library = PositionLibraryService(authToken: widget.userSession.token);
    final lessons = LessonApiService(authToken: widget.userSession.token);

    final course = await showDialog(
      context: context,
      builder: (context) => CoursePickerDialog(
        service: library,
        title: 'Which tutorial are you editing?',
      ),
    );
    if (course == null || !mounted) return;

    // There is no `GET /lessons/:id`; the list route is the only reader of a
    // lesson's steps, and it already returns `position_list`. Finding the
    // lesson in the list it hands back beats adding an endpoint for one screen.
    final all = await lessons.fetchAll();
    if (!mounted) return;

    Map<String, dynamic>? lesson;
    for (final entry in all) {
      if (entry is Map && entry['id'] == course.id) {
        lesson = Map<String, dynamic>.from(entry);
        break;
      }
    }

    if (lesson == null) {
      AppFeedback.show(
        context,
        () => const SnackBar(content: Text('Tutorial not found.')),
      );
      return;
    }

    await openTutorialEditor(
      context,
      session: widget.userSession,
      api: lessons,
      lesson: lesson,
    );
  }

  /// Where the step being saved begins.
  ///
  /// There is a choice here because both answers are things a trainer wants: a
  /// lesson about the opposition is the whole line from the diagram, and a
  /// lesson about the position five moves in is what follows *it*. There used
  /// to be no choice and no question — see [_addToTutorial].
  ///
  /// Whichever is picked, the step's `fen` and its `pgn` come from the same
  /// node. That is the entire point of the type.
  Future<AnalysisNode?> _askStepAnchor() async {
    // Nothing to ask when the board is standing on the root: both answers are
    // the same node.
    if (identical(_currentNode, _rootNode)) return _rootNode;

    // The viewer walks first children, so "from the start" means the main
    // line — which is not the trainer's line when they are standing in a
    // sideline. Said out loud rather than discovered later: it is the one way
    // the two answers differ in kind and not only in length.
    final offMainLine = !_isOnMainLine(_currentNode);

    return showDialog<AnalysisNode>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Where does the step begin?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The student receives the board at the starting position of the step '
              'and steps through the moves one by one, with your comment on each.',
            ),
            if (offMainLine) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'The current move is in a sideline. Step "from start of line" '
                'shows the main line, not this one.',
                style: TextStyle(color: context.colors.warning),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_currentNode),
            child: const Text('From here'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(_rootNode),
            child: const Text('From start of line'),
          ),
        ],
      ),
    );
  }

  /// Whether [node] can be reached from the root by taking first children —
  /// the same walk the lesson viewer makes.
  bool _isOnMainLine(AnalysisNode node) {
    var walk = _rootNode;
    while (true) {
      if (identical(walk, node)) return true;
      if (walk.children.isEmpty) return false;
      walk = walk.children.first;
    }
  }

  /// Opens the one door into teaching material — S2 of
  /// `docs/PLAN-REORGANIZACIJA.md`. The sheet asks which of the six flows the
  /// trainer wants; every callback below is one of the three flows this
  /// screen used to reach with a separate bar action each.
  Future<void> _openTeachMenu() => showTeachMenu(
        context,
        hasLine: _currentNode.children.isNotEmpty,
        hasGame: _rootNode.children.isNotEmpty,
        onNewFromPosition: () => _openTutorialStudio(wholeLine: false),
        onNewFromLine: () => _openTutorialStudio(wholeLine: true),
        onNewFromGame: _makeTutorialFromGame,
        onAddPosition: () => _addToTutorial(anchor: _currentNode),
        onAddLine: _addLineToTutorial,
        onEdit: _editLessonSteps,
      );

  /// Hands the line worked out here over to the tutorial studio.
  ///
  /// The whole point of the door is that a line reached with the engine
  /// becomes a tutorial **without being retyped**, so the tree travels and
  /// not only a FEN. [wholeLine] used to be asked here with a dialog; the
  /// question is now the sheet's own two rows — "New tutorial from this
  /// position" and "New tutorial from this line" — so this method only acts
  /// on the answer.
  Future<void> _openTutorialStudio({required bool wholeLine}) async {
    final blackOrientation = _orientation == PlayerColor.black;
    final handover = wholeLine
        ? TutorialHandover.tree(_currentNode,
            blackOrientation: blackOrientation)
        : TutorialHandover.position(_currentNode.fen,
            blackOrientation: blackOrientation);

    final intoOpenDraft = await askTutorialDestination(context);
    if (intoOpenDraft == null || !mounted) return;

    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TutorialStudioScreen(
        session: widget.userSession,
        entry: TutorialEntry.fromAnalysis(
          handover,
          intoOpenDraft: intoOpenDraft,
        ),
      ),
    ));
  }

  /// Saves [anchor] — and the line that runs through it — as one lesson step.
  /// The shared body behind the sheet's "Add this position" (anchor:
  /// `_currentNode`, no question) and "Add this line" ([_askStepAnchor] asks
  /// From here / From start of line first) rows.
  ///
  /// The step is one step, not one per half-move: the viewer replays a `pgn`
  /// and shows each move's comment and arrows as the student walks it.
  ///
  /// What it did before, and why the check below exists: it sent
  /// `_currentNode.fen` as the position and the whole tree from `_rootNode` as
  /// the line. Standing anywhere but the root, those two describe different
  /// games — and `MoveTree.parsePgn` skips a move it cannot play without a
  /// word, so the student's screen showed a still picture and the trainer was
  /// told the step had been saved. Two things fix it: one node answers for
  /// both fields, and the step is read back here before it is sent.
  Future<void> _addToTutorial({required AnalysisNode anchor}) async {
    final library = PositionLibraryService(authToken: widget.userSession.token);
    final lessons = LessonApiService(authToken: widget.userSession.token);

    final course = await showDialog(
      context: context,
      builder: (context) => CoursePickerDialog(service: library, count: 1),
    );
    if (course == null || !mounted) return;

    // One node answers for the position and for the line, and the step is read
    // back exactly the way the student's screen will read it. A line that does
    // not replay from its own position is not saved: a step that quietly loses
    // its moves is worse than a step that was never made, because the trainer
    // finds out from a child.
    final step = StudioLessonStep.from(anchor);
    if (!step.replays) {
      AppFeedback.show(
        context,
        () => SnackBar(
          content: Text('Step was not saved: ${step.rejectedMoves} '
              'moves from the line cannot be played from this position.'),
          backgroundColor: context.colors.danger,
        ),
      );
      return;
    }

    final error = await lessons.appendStep(
      lessonId: course.id,
      step: step.toJson(title: 'New task'),
    );

    if (!mounted) return;
    if (error != null) {
      AppFeedback.show(
          context,
          () => SnackBar(
                content: Text(error),
                backgroundColor: context.colors.danger,
              ));
    } else {
      AppFeedback.show(
          context,
          () => SnackBar(
                content: const Text('Step successfully added to tutorial.'),
                backgroundColor: context.colors.success,
              ));
    }
  }

  /// "Add this line to a tutorial…": asks where the line begins, then runs
  /// the shared body in [_addToTutorial].
  Future<void> _addLineToTutorial() async {
    final anchor = await _askStepAnchor();
    if (anchor == null || !mounted) return;
    await _addToTutorial(anchor: anchor);
  }

  void _exportPgn() {
    dialogs.exportPgnDialog(context, PgnExporterService.exportToPgn(_rootNode));
  }

  /// The main line from the root, through the engine and the words route, to a
  /// tutorial open in the studio.
  Future<void> _makeTutorialFromGame() => makeTutorialFromGame(
        context,
        session: widget.userSession,
        root: _rootNode,
        gameName: 'Game from Analysis',
        onOpenEngineSettings: _openEngineSettings,
      );

  Future<void> _showGameReviewDialog() async {
    final kept = await showDialog<int>(
      context: context,
      // Long-running engine walk — barrier tap must not silently discard it.
      barrierDismissible: false,
      builder: (ctx) => GameReviewDialog(
        rootNode: _rootNode,
        currentNode: _currentNode,
        stockfishService: _stockfishService,
        exerciseApi: ExerciseApiService(authToken: widget.userSession.token),
        gameTitle: _gameTitleForExercises(),
        runner: _reviewRunner,
      ),
    );
    if (!mounted || kept == null || kept == 0) return;
    AppFeedback.success(
        context,
        kept == 1
            ? 'Kept 1 exercise — in the Library, under Exercises.'
            : 'Kept $kept exercises — in the Library, under Exercises.');
  }

  /// What the exercises a review keeps are named after: the players, when
  /// the game says who they were, else nothing — the dialog then names them
  /// by the date.
  String? _gameTitleForExercises() {
    final white = _pgnWhiteName?.trim();
    final black = _pgnBlackName?.trim();
    if (white == null || white.isEmpty || black == null || black.isEmpty) {
      return null;
    }
    return '$white – $black';
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
  /// Read by [readAnalysisPgn] — the app's one PGN reader — so variations,
  /// comments, arrows and assessments arrive with the main line, and a PGN this
  /// app exported (a repertoire, or an analysis with a sideline) is accepted.
  void _importPgn(String rawPgn) {
    try {
      final read = readAnalysisPgn(rawPgn);
      if (read == null) {
        AppFeedback.show(
          context,
          () => SnackBar(
              content: const Text(
                  '⚠️ Invalid PGN format: no move in it could be played.'),
              backgroundColor: context.colors.danger),
        );
        return;
      }

      String? header(String key) {
        final value = read.headers[key]?.trim();
        return (value == null || value.isEmpty || value == '?') ? null : value;
      }

      setState(() {
        _initAnalysisTree(read.root.fen);
        _rootNode = read.root;
        _pgnWhiteName = header('White');
        _pgnBlackName = header('Black');
        _pgnWhiteElo = header('WhiteElo');
        _pgnBlackElo = header('BlackElo');
        _pgnResult = header('Result');
        // Land on the end of the main line; the tree is there to walk back
        // through.
        _currentNode = read.tip;
        _chessGame = chess.Chess.fromFEN(read.tip.fen);
        _boardController.loadFen(read.tip.fen);
      });
      _saveDraft();
      _triggerEngineAnalysis();

      AppLogger.log(
          '[AnalysisStudio] 📥 PGN imported: ${read.moveCount} moves, '
          '${read.rejectedMoves} rejected, game 1 of ${read.gameCount}');

      // Loud when anything was left behind: a shorter game shown as the whole
      // one is the fault this app keeps having.
      final leftOut = [
        if (read.rejectedMoves > 0)
          '${read.rejectedMoves} ${read.rejectedMoves == 1 ? "move" : "moves"} '
              'could not be played and ${read.rejectedMoves == 1 ? "was" : "were"} left out',
        if (read.gameCount > 1)
          'only the first of ${read.gameCount} games was loaded',
      ];
      AppFeedback.show(
        context,
        () => SnackBar(
          content: Text(leftOut.isEmpty
              ? '✅ PGN loaded — ${read.moveCount} moves in tree.'
              : '⚠️ PGN loaded — ${read.moveCount} moves in tree, but '
                  '${leftOut.join(", and ")}.'),
          backgroundColor:
              leftOut.isEmpty ? context.colors.accent : context.colors.warning,
        ),
      );
    } catch (e) {
      AppFeedback.show(
        context,
        () => SnackBar(
            content: Text('Error importing PGN: $e'),
            backgroundColor: context.colors.danger),
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
    final confirmed =
        await dialogs.confirmReplaceAnalysisDialog(context, summary.title);
    if (!confirmed) return;

    final loadedRoot = await AnalysisPersistenceService.instance.loadAnalysis(
      id: summary.id,
      userToken: widget.userSession.token,
    );

    if (!mounted) return;

    if (loadedRoot == null) {
      AppFeedback.show(
        context,
        () => SnackBar(
            content: const Text('⚠️ Loading failed. Check your connection.'),
            backgroundColor: context.colors.danger),
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

    AppFeedback.show(
      context,
      () => SnackBar(
          content: Text('✅ Loaded: "${summary.title}"'),
          backgroundColor: context.colors.accent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    // Portrait only; landscape sizes its board from the room it is given.
    final double boardSize = math.min(screenSize.width - 32.0, 700.0) *
        AppSettingsService.instance.boardSizeScale;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: LandscapeBoardLayout.toolbarHeight(context),
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
                        if (_pgnResult != null &&
                            _pgnResult!.isNotEmpty &&
                            _pgnResult != '*')
                          Text(
                            _pgnResult!,
                            style: AppText.micro
                                .copyWith(color: context.colors.textMuted),
                          ),
                      ],
                    )
                  : const Text(
                      'Analysis',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: AppText.title,
                    ),
            ),
          ],
        ),
        actions: _toolbarActions(context),
      ),
      // Arrow keys drive the same cursor the strip's buttons do. This is the
      // screen a variation is read on, and reading it with the mouse alone is
      // what makes a desktop window feel like a phone in a frame.
      body: MoveKeyboardShortcuts(
        cursor: _moveCursor(),
        // _jumpToNode does its own setState.
        onChanged: () {},
        child: isLandscape
            // The app bar owns the top inset; a notch on a phone held sideways
            // is on the left or the right.
            ? SafeArea(top: false, child: _buildLandscapeLayout())
            : _buildPortraitLayout(boardSize),
      ),
    );
  }

  Widget _buildPortraitLayout(double boardSize) {
    return Column(
      children: [
        // Static Fixed Board at top
        Padding(
          padding:
              const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
          child: Center(
            child: SizedBox(
              width: boardSize,
              height: boardSize,
              child: Card(
                elevation: 4,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: BoardWithCoordinates(
                    size: boardSize - 16.0,
                    orientation: _orientation,
                    builder: _buildBoardWidget,
                  ),
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
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Column(
              children: [
                if (_showEvalBar) ...[
                  HorizontalEvalBarWidget(
                    eval: _currentRawEval,
                    evalString: _currentEvalString,
                    depth: _currentEvalDepth,
                    orientation: _orientation,
                  ),
                  const SizedBox(height: AppSpacing.sm),
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

  /// The board beside the panels, for every landscape window — a phone held
  /// sideways and a desktop alike. See [LandscapeBoardLayout] for why the move
  /// strip is not under the board.
  Widget _buildLandscapeLayout() {
    return LandscapeBoardLayout(
      boardScale: AppSettingsService.instance.boardSizeScale,
      board: (side) => Card(
        elevation: 4,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(6.0),
          child: BoardWithCoordinates(
            size: side - 12.0,
            orientation: _orientation,
            builder: _buildBoardWidget,
          ),
        ),
      ),
      boardAside: _showEvalBar
          ? (height) => VerticalEvalBarWidget(
                eval: _currentRawEval,
                evalString: _currentEvalString,
                depth: _currentEvalDepth,
                height: height,
                orientation: _orientation,
              )
          : null,
      panels: Column(
        children: [
          _buildPositionInfoPanel(),
          _buildAnalysisAndTreeSection(),
        ],
      ),
      footer: [
        // Lower than its own 90 on a short screen, so the tree above keeps
        // room to scroll.
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: LandscapeBoardLayout.applies(context) ? 64 : 96,
          ),
          child: _buildCurrentCommentPanel(),
        ),
        _buildNavigationToolbar(),
      ],
    );
  }

  /// Opening/endgame phase banner plus the Syzygy and opening-explorer panels
  /// for [_currentNode]. Shared by portrait and landscape layouts.
  Widget _buildPositionInfoPanel() {
    return Builder(
      builder: (ctx) {
        final phaseInfo = PositionInfoService.analyzeFen(_currentNode.fen);
        final bookEntry =
            OpeningBookService.instance.lookupByFen(_currentNode.fen);
        final displayOpeningName = (!phaseInfo.isEndgame && bookEntry != null)
            ? '${bookEntry.eco} · ${bookEntry.name}'
            : phaseInfo.openingName;
        return Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: phaseInfo.isEndgame
                    ? context.colors.groupedContainer
                    : context.colors.surfaceRaised,
                borderRadius: AppRadii.roundedSm,
                border: Border.all(
                  color: phaseInfo.isEndgame
                      ? context.colors.groupedContainerBorder
                      : context.colors.accent,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    phaseInfo.isEndgame ? Icons.auto_awesome : Icons.menu_book,
                    color: phaseInfo.isEndgame
                        ? context.colors.groupedContainerBorder
                        : context.colors.accent,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      displayOpeningName,
                      style: AppText.bodyBold
                          .copyWith(color: context.colors.textPrimary),
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
                isLoading: _openingExplorerLoading,
                result: _openingExplorerResult,
                reason: _openingExplorerReason,
                openingName: displayOpeningName,
                onMoveSelected: _playUciMove,
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
        const SizedBox(height: AppSpacing.sm),
        // Above the panel, not in its place: the switch stays in reach, so
        // the reader can turn the engine off while the review has it.
        if (AppSettingsService.instance.isPanelVisible('engine_analysis') &&
            _showEvaluation &&
            _stockfishService.held.value)
          Container(
            key: const Key('analysis-engine-busy'),
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.colors.surface.withValues(alpha: 0.5),
              borderRadius: AppRadii.roundedSm,
              border: Border.all(color: context.colors.border),
            ),
            child: Text(
              'The engine is busy with the game review.',
              style: AppText.body.copyWith(color: context.colors.textMuted),
            ),
          ),
        if (AppSettingsService.instance.isPanelVisible('engine_analysis'))
          StockfishAnalysisWidget(
            isEngineEnabled: _showEvaluation,
            isAllowedToUseEngine: true,
            analysisDepth: _analysisDepth,
            analysisLines: _analysisLines,
            onAnalysisDepthChanged: (value) =>
                _applyAnalysisDials(depth: value),
            onAnalysisLinesChanged: (value) =>
                _applyAnalysisDials(lines: value),
            isOnline: _stockfishService.isOnline,
            isCustomEngineActive: _stockfishService.isCustomEngineActive,
            onOpenSettings:
                isCustomEngineSupported ? _openEngineSettings : null,
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

  Future<void> _handleTapMoveInput(String square) async {
    final game = _chessGame;
    if (game == null) return;
    final piece = game.get(square);
    final isOwnPiece = piece != null && piece.color == game.turn;

    if (isOwnPiece) {
      setState(() => _selectedSquareForTap =
          (square == _selectedSquareForTap) ? null : square);
      return;
    }

    final from = _selectedSquareForTap;
    if (from == null || from == square) return;

    setState(() => _selectedSquareForTap = null);

    // Asked, not assumed. Dragging a pawn to the last rank has always opened a
    // dialog (the board package's own); tapping quietly made a queen, so the
    // same move meant two different things depending on how it was played —
    // and an analysis line that turns on a knight could not be entered by
    // tapping at all.
    var promotion = '';
    if (isPromotionMove(game, from, square)) {
      final chosen = await askPromotionPiece(
        context,
        isWhite: game.turn == chess.Color.WHITE,
      );
      if (chosen == null || !mounted) return;
      promotion = chosen;
    }
    _handleUserMove(from, square, promotion);
  }

  Widget _buildBoardWidget(double size) {
    return Stack(
      children: [
        SkinnedChessBoard(
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
              final square = getSquareFromOffset(
                  details.localPosition, size, _orientation);
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
        if (_showEngineOverlay &&
            _engineArrows.isNotEmpty &&
            AppSettingsService.instance.showEngineArrows)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                size: Size(size, size),
                painter: ChessBoardPainter(
                  drawingModeColor: context.colors.accent,
                  badgeBorderColor: context.colors.canvas,
                  arrows: const [],
                  engineArrows: AppSettingsService.instance.showEngineArrows
                      ? _engineArrows
                      : const [],
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
            duration: Duration(
                milliseconds:
                    AppSettingsService.instance.moveAnimationDurationMs),
            onCompleted: () {
              if (mounted) {
                setState(() => _pendingAnimations.remove(pendingAnim));
              }
            },
          ),
      ],
    );
  }

  /// Shown above the board while stepping through an extracted puzzle set:
  /// which puzzle this is, and controls to move to the next/previous one or
  /// leave puzzle mode back to free analysis.
  /// The one cursor this screen is walked by. The strip's buttons and the arrow
  /// keys read it from here rather than each building their own, so there is no
  /// second copy to fall out of step.
  AnalysisNodeCursor _moveCursor() =>
      AnalysisNodeCursor(currentNode: _currentNode, onSelect: _jumpToNode);

  /// Where you are in the line, and what can be done to the move you are on —
  /// one row, on a phone as on a desktop.
  ///
  /// **The second attempt at TODO-provera 180.5.** The first took the four move
  /// actions out of this strip and gave them a row of their own under it: the
  /// strip became one row, and the screen still spent two cards of chrome
  /// between the board and anything worth reading. „Malo je bolje, ali nije
  /// najbolje" (18.9.2026).
  ///
  /// So the two rows became one, using the rule this screen's own toolbar
  /// already follows — icons where there is room, one button and a sheet where
  /// there is not. The move the cursor stands on is the strip's centre label,
  /// which is what that slot is for and what it was wasting on the word
  /// „Navigation" until this morning. The comment panel goes back to being
  /// *content*: drawn when the move actually carries a sentence, which is the
  /// only thing it was ever meant to say.
  Widget _buildNavigationToolbar() {
    final node = _currentNode;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.compactWidth;
    return MoveNavigationControls(
      cursor: _moveCursor(),
      centerLabel:
          node.isRoot ? null : '${node.moveNumberLabel}${node.moveSan ?? ''}',
      iconSize: 20,
      onFlipBoard: _flipBoard,
      trailing: wide
          ? _moveActions()
          : [
              IconButton(
                icon: Icon(Icons.more_horiz,
                    size: 18, color: context.colors.textSecondary),
                tooltip: 'What to do with this move',
                onPressed: _showMoveActionsSheet,
              ),
            ],
    );
  }

  /// The four move actions on a phone: comment, AI comment, NAG, delete.
  ///
  /// Named rather than drawn as icons here, because a sheet has the room for
  /// words and a 360 dp row does not — and because „Delete this move" is worth
  /// reading before it is tapped.
  void _showMoveActionsSheet() {
    final isRoot = _currentNode.isRoot;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.comment, color: context.colors.info),
              title: const Text('Add comment'),
              onTap: () {
                Navigator.of(sheet).pop();
                _showCommentDialog();
              },
            ),
            ListTile(
              leading: Icon(Icons.auto_awesome, color: context.colors.accent),
              title: const Text('Generate AI comment'),
              enabled: !_isGeneratingAiComment && !isRoot,
              onTap: () {
                Navigator.of(sheet).pop();
                _generateAiComment();
              },
            ),
            ListTile(
              leading: Icon(Icons.style, color: context.colors.warning),
              title: const Text('NAG symbols (!, ?)'),
              onTap: () {
                Navigator.of(sheet).pop();
                _showNagSelector();
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: context.colors.danger),
              title: const Text('Delete this move'),
              enabled: !isRoot,
              onTap: () {
                Navigator.of(sheet).pop();
                _confirmDeleteCurrentNode();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Comment, AI comment, NAG and delete — the four that act on the move the
  /// cursor is standing on rather than on where the cursor is.
  ///
  /// **They used to hang off the navigation strip**, which made nine buttons in
  /// one `Wrap`: nine 40 dp targets need 360 dp before the container's own
  /// padding, so on a phone they wrapped onto a row of their own anyway — an
  /// unlabelled second row of icons under the arrows. Reported live on
  /// 18.9.2026 (TODO-provera 180.5). Here they sit beside the move they act
  /// on, and the strip above is five buttons and one row on every phone.
  List<Widget> _moveActions() => [
        IconButton(
          icon: Icon(Icons.comment, size: 18, color: context.colors.info),
          tooltip: 'Add Comment',
          onPressed: _showCommentDialog,
        ),
        IconButton(
          icon: _isGeneratingAiComment
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.auto_awesome,
                  size: 18, color: context.colors.accent),
          tooltip: 'Generate AI comment',
          onPressed: (_isGeneratingAiComment || _currentNode.isRoot)
              ? null
              : _generateAiComment,
        ),
        IconButton(
          icon: Icon(Icons.style, size: 18, color: context.colors.warning),
          tooltip: 'NAG Symbols (!, ?)',
          onPressed: _showNagSelector,
        ),
        IconButton(
          icon: Icon(Icons.delete_outline,
              size: 18, color: context.colors.danger),
          tooltip: 'Delete this move (and branch after it)',
          onPressed: _currentNode.isRoot ? null : _confirmDeleteCurrentNode,
        ),
      ];

  /// Shows [_currentNode]'s move + NAG + comment right under the board, so
  /// browsing an already-annotated game (or one just run through "Analiziraj
  /// partiju") surfaces its commentary without having to go hunting for it
  /// in the move-tree text below. Collapses to nothing on a move with no
  /// comment/NAG, so it doesn't add empty chrome while stepping through an
  /// unannotated game.
  /// What was written about the move the cursor is on.
  ///
  /// **Content, not chrome**: drawn only when the move actually carries a
  /// sentence or a NAG, so a phone spends no height saying that there is
  /// nothing to say. It briefly drew on every move — while the four move
  /// actions lived in it, „Add Comment" could not be hidden behind „there is
  /// no comment yet" — and that is over: the actions are in the navigation
  /// strip, where they are reachable whatever this panel does.
  Widget _buildCurrentCommentPanel() {
    final comment = _currentNode.comment;
    final nag = _currentNode.nag;
    if (comment.isEmpty && nag == null) return const SizedBox.shrink();

    return InkWell(
      borderRadius: AppRadii.roundedSm,
      onTap: _showCommentDialog,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadii.roundedSm,
          border:
              Border.all(color: context.colors.info.withValues(alpha: 0.35)),
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
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: AppText.caption
                        .copyWith(color: context.colors.textPrimary),
                    children: [
                      if (_currentNode.moveSan != null)
                        TextSpan(
                          text: _currentNode.moveSan,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      if (nag != null)
                        TextSpan(
                          text: ' $nag',
                          style: TextStyle(
                              color: context.colors.warning,
                              fontWeight: FontWeight.bold),
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
    final label = node.moveSan ?? 'this move';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete move?',
            style: TextStyle(color: context.colors.textPrimary)),
        content: Text(
          removedCount > 1
              ? 'This deletes "$label" and all remaining $removedCount moves in this branch (including variations). This cannot be undone.'
              : 'This deletes "$label". This cannot be undone.',
          style: TextStyle(color: context.colors.textMuted),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.danger,
                foregroundColor: context.colors.canvas),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    parent.removeChild(node);
    _jumpToNode(parent);
  }
}

/// One toolbar action. A plain class rather than a record because the theme
/// hands back nullable colours and a record's field type would have to spell
/// that out at every call site.
class _ToolAction {
  final IconData icon;
  final Color? color;
  final String tooltip;
  final VoidCallback onPressed;

  const _ToolAction(this.icon, this.color, this.tooltip, this.onPressed);
}
