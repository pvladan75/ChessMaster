/// Preparation, as its own screen — phase 1 of `docs/PLAN-PRIPREMA.md`.
///
/// Built from what exists elsewhere in the app (see the gate's head comment,
/// `test/preparation_screen_test.dart`, for the full list): the board, the
/// marking bar, the move strip and cursor, the graphical/notation tree, the
/// engine's panel and the two evaluation bars, `LandscapeBoardLayout` for a
/// phone on its side, `playedMove` for a move on a position, and
/// `PreparationLayout` for where everything goes. On `AnalysisNode`. No
/// socket, no request — `test/preparation_screen_test.dart`'s „no server"
/// group and its own source guard hold that.
library;

import 'package:flutter/foundation.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'package:go_router/go_router.dart';

import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node_cursor.dart';
import 'package:chess_app/features/analysis_studio/services/insert_line_as_variation.dart';
import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/features/preparation/services/preparation_engine.dart';
import 'package:chess_app/features/preparation/services/preparation_layout.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/theme/breakpoints.dart';
import 'package:chess_app/widgets/ai_studio/board_eval_widgets.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart' show EngineArrow;
import 'package:chess_app/widgets/board_view_menu.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/game_screen/board_annotation_bar.dart';
import 'package:chess_app/widgets/game_screen/board_annotation_controller.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/game_screen/move_keyboard_shortcuts.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';
import 'package:chess_app/widgets/landscape_board_layout.dart';
import 'package:chess_app/widgets/stockfish_analysis_widget.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

class PreparationScreen extends StatefulWidget {
  const PreparationScreen({
    super.key,
    required this.userSession,
    this.initialFen,
    this.initialTree,
    this.engine,
  });

  final UserSession userSession;

  /// A position to open on. The starting position when neither this nor
  /// [initialTree] is given.
  final String? initialFen;

  /// A whole tree to open — variations, comments, arrows and squares as they
  /// are — with the cursor on its root. Wins over [initialFen].
  final AnalysisNode? initialTree;

  /// The engine's glue. Injected by a test, which has no engine to ask and
  /// needs to see what was asked of one; built by the screen otherwise.
  final PreparationEngine? engine;

  @override
  State<PreparationScreen> createState() => _PreparationScreenState();
}

class _PreparationScreenState extends State<PreparationScreen>
    with SingleTickerProviderStateMixin {
  final ChessBoardController _boardController = ChessBoardController();
  final BoardAnnotationController _annotation = BoardAnnotationController();
  late final PreparationEngine _engine = widget.engine ?? PreparationEngine();
  late final TabController _phoneTabs = TabController(length: 3, vsync: this);

  late AnalysisNode _rootNode;
  late AnalysisNode _currentNode;
  PlayerColor _orientation = PlayerColor.white;

  ValueListenable<TickerModeData>? _shown;

  @override
  void initState() {
    super.initState();
    final tree = widget.initialTree;
    final startFen = tree?.fen ?? widget.initialFen ?? _startFen;
    if (tree != null) {
      _rootNode = tree;
      _currentNode = tree;
    } else {
      _rootNode = AnalysisNode(fen: startFen);
      _currentNode = _rootNode;
    }
    _boardController.loadFen(_currentNode.fen);
    _engine.init();
    AppSettingsService.instance.addListener(_onAppSettingsChanged);
    _phoneTabs.addListener(_onPhoneTabChanged);
  }

  void _onAppSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _onPhoneTabChanged() {
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

  /// Leaving this screen — a route over it, or `dispose` — switches the
  /// engine off and releases it, exactly as `AnalysisStudioScreen` does
  /// (`_onShownChanged`); coming back leaves it off until asked again.
  void _onShownChanged() {
    final shown = _shown?.value.enabled ?? true;
    if (shown) {
      _attachEngine();
      return;
    }
    if (_engine.isOn) {
      setState(_engine.reset);
    }
    _engine.detach();
  }

  void _attachEngine() {
    _engine.attach(
      getFen: () => _currentNode.fen,
      onRefused: (reason) {
        if (!mounted) return;
        AppFeedback.error(context, 'Engine cannot calculate: $reason');
      },
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _shown?.removeListener(_onShownChanged);
    _phoneTabs.removeListener(_onPhoneTabChanged);
    _phoneTabs.dispose();
    AppSettingsService.instance.removeListener(_onAppSettingsChanged);
    _engine.detach();
    super.dispose();
  }

  // ── the cursor, moves and the tree ────────────────────────────────────

  AnalysisNodeCursor _moveCursor() =>
      AnalysisNodeCursor(currentNode: _currentNode, onSelect: _jumpTo);

  void _jumpTo(AnalysisNode node) {
    setState(() {
      _currentNode = node;
      _boardController.loadFen(node.fen);
      _annotation.cancelPending();
    });
    _engine.triggerAnalysis(node.fen);
  }

  void _playMove(String from, String to, String promotion) {
    final played = playedMove(
      fen: _currentNode.fen,
      from: from,
      to: to,
      promotion: promotion,
    );
    if (played == null) {
      // Refused: the board reloads the position it had.
      setState(() => _boardController.loadFen(_currentNode.fen));
      return;
    }
    setState(() {
      _currentNode = _currentNode.addChild(
        childFen: played.fen,
        san: played.san,
        uci: played.uci,
      );
      _boardController.loadFen(played.fen);
      _annotation.cancelPending();
    });
    _engine.triggerAnalysis(played.fen);
  }

  void _promoteNode(AnalysisNode node) {
    final parent = node.parent;
    if (parent == null) return;
    setState(() => parent.promoteToMainLine(node));
  }

  bool _isDescendantOf(AnalysisNode node, AnalysisNode ancestor) {
    AnalysisNode? n = node;
    while (n != null) {
      if (identical(n, ancestor)) return true;
      n = n.parent;
    }
    return false;
  }

  void _deleteNode(AnalysisNode node) {
    final parent = node.parent;
    if (parent == null) return;
    setState(() {
      final cursorFallsUnder = _isDescendantOf(_currentNode, node);
      parent.removeChild(node);
      if (cursorFallsUnder) {
        _currentNode = parent;
        _boardController.loadFen(parent.fen);
      }
    });
  }

  void _moveVariation(AnalysisNode node, {required bool earlier}) {
    setState(() => node.parent?.moveVariation(node, earlier: earlier));
  }

  void _insertEngineLine(AnalysisLine line) {
    final result = insertLineAsVariation(_currentNode, line.continuationLan);
    setState(() {});
    if (result.added > 0) {
      AppFeedback.info(context, 'Moves added to variation: ${result.added}.');
    } else if (result.rejected) {
      AppFeedback.warning(context, 'Line does not match current position.');
    } else {
      AppFeedback.info(context, 'Line was already in the tree.');
    }
  }

  /// Loads [fen] as a new root, as the room does from an engine line's
  /// dialog.
  void _loadFenToMainBoard(String fen) {
    setState(() {
      _rootNode = AnalysisNode(fen: fen);
      _currentNode = _rootNode;
      _boardController.loadFen(fen);
      _annotation.cancelPending();
    });
    _engine.triggerAnalysis(fen);
  }

  // ── marks ──────────────────────────────────────────────────────────────

  void _toggleArrowMode() {
    setState(() {
      if (_annotation.mode == AnnotationMode.arrow) {
        _annotation.stop();
      } else {
        _annotation.setMode(AnnotationMode.arrow);
      }
    });
  }

  void _toggleSquareMode() {
    setState(() {
      if (_annotation.mode == AnnotationMode.square) {
        _annotation.stop();
      } else {
        _annotation.setMode(AnnotationMode.square);
      }
    });
  }

  void _toggleRangeMode() {
    setState(() {
      _annotation.rangeMode = !_annotation.rangeMode;
      if (!_annotation.rangeMode) _annotation.pendingRangeFrom = null;
    });
  }

  void _selectColor(String code) {
    setState(() => _annotation.setColor(code));
  }

  void _onSquareTapForDrawing(String square) {
    // The first tap of an arrow changes neither list but must still repaint:
    // the board draws the square it will be drawn from, which is the only
    // thing telling the trainer their tap was heard.
    _annotation.tap(
      square,
      arrows: _currentNode.arrows,
      squares: _currentNode.squares,
      asRange:
          _annotation.rangeMode || HardwareKeyboard.instance.isShiftPressed,
    );
    setState(() {});
  }

  void _clearMarks() {
    final changed = _annotation.clearMarks(
      arrows: _currentNode.arrows,
      squares: _currentNode.squares,
    );
    if (changed) setState(() {});
  }

  void _undoMark() {
    final squares = _currentNode.squares;
    final arrows = _currentNode.arrows;
    final squareFirst = _annotation.mode == AnnotationMode.square;
    var changed = squareFirst
        ? _annotation.undoLastSquare(squares)
        : _annotation.undoLastArrow(arrows);
    if (!changed) {
      changed = squareFirst
          ? _annotation.undoLastArrow(arrows)
          : _annotation.undoLastSquare(squares);
    }
    if (changed) {
      setState(() {});
    } else {
      AppFeedback.info(context, 'No mark to undo.');
    }
  }

  // ── the shape ─────────────────────────────────────────────────────────

  Future<void> _openSettings() async {
    await context.push(AppRoutes.preferences);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: LandscapeBoardLayout.toolbarHeight(context),
        title: const Text('Preparation', overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'More',
            onSelected: (value) {
              if (value == 'settings') _openSettings();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'settings', child: Text('Settings')),
            ],
          ),
        ],
      ),
      body: MoveKeyboardShortcuts(
        cursor: _moveCursor(),
        onChanged: () {},
        child: LayoutBuilder(
          builder: (context, constraints) {
            final body = Size(constraints.maxWidth, constraints.maxHeight);
            if (LandscapeBoardLayout.applies(context)) {
              return _buildLandscape(body);
            }
            if (Breakpoints.isWide(context)) return _buildDesktop(body);
            return _buildPhone(body);
          },
        ),
      ),
    );
  }

  // ── shared pieces ────────────────────────────────────────────────────

  Widget _boardWidget(double size) {
    return BoardWithCoordinates(
      size: size,
      orientation: _orientation,
      builder: (boardSize) => ChessBoardWithOverlay(
        controller: _boardController,
        boardOrientation: _orientation,
        boardSize: boardSize,
        isAllowedToMove: true,
        isDrawingMode: _annotation.isDrawing,
        drawingStartSquare: _annotation.pendingFrom,
        arrows: _currentNode.arrows,
        squares: _currentNode.squares,
        engineArrows: _engineArrows(),
        lastMoveFrom: _lastMoveFrom,
        lastMoveTo: _lastMoveTo,
        onMove: _playMove,
        onSquareTapForDrawing: _onSquareTapForDrawing,
      ),
    );
  }

  String? get _lastMoveFrom {
    final uci = _currentNode.moveUci;
    return uci != null && uci.length >= 4 ? uci.substring(0, 2) : null;
  }

  String? get _lastMoveTo {
    final uci = _currentNode.moveUci;
    return uci != null && uci.length >= 4 ? uci.substring(2, 4) : null;
  }

  List<EngineArrow> _engineArrows() {
    if (!AppSettingsService.instance.showEngineArrows || !_engine.isOn) {
      return const [];
    }
    return [
      for (final line in _engine.lines.values)
        if (line.bestMoveLan.length >= 4)
          EngineArrow(
            from: line.bestMoveLan.substring(0, 2),
            to: line.bestMoveLan.substring(2, 4),
            evalText: line.evaluation,
            rank: line.multipv,
          ),
    ];
  }

  Widget _marksWidget(MarkingDensity density) {
    return BoardAnnotationBar(
      mode: _annotation.mode,
      selectedColorCode: _annotation.colorCode,
      onArrowPressed: _toggleArrowMode,
      onSquarePressed: _toggleSquareMode,
      onColorSelected: _selectColor,
      onClearPressed: _clearMarks,
      rangeMode: _annotation.rangeMode,
      onRangePressed: _toggleRangeMode,
      density: density,
      onUndoPressed: _undoMark,
    );
  }

  Widget _stripWidget() {
    return MoveNavigationControls(
      cursor: _moveCursor(),
      dense: true,
      onFlipBoard: () => setState(() {
        _orientation = _orientation == PlayerColor.white
            ? PlayerColor.black
            : PlayerColor.white;
      }),
      trailing: const [BoardViewMenu(arrows: true, boardSize: true)],
    );
  }

  Widget _treeWidget({required bool startOnGraph, bool fills = false}) {
    return AnalysisMoveTreeWidget(
      fills: fills,
      rootNode: _rootNode,
      activeNode: _currentNode,
      onSelectNode: _jumpTo,
      onPromoteNode: _promoteNode,
      onDeleteNode: _deleteNode,
      onMoveVariation: _moveVariation,
      startOnGraph: startOnGraph,
    );
  }

  String _commentLabel(AnalysisNode node) => node.isRoot
      ? 'Comment (select a move)'
      : 'Comment for ${node.moveNumberLabel}${node.moveSan}';

  Widget _commentPanel() {
    final node = _currentNode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_commentLabel(node), style: AppText.bodyBold),
        const SizedBox(height: 4),
        _CommentField(
          key: ValueKey('prep-comment-${node.id}'),
          node: node,
          enabled: !node.isRoot,
          onChanged: (text) => setState(() => node.comment = text),
        ),
      ],
    );
  }

  List<AnalysisLine> _sortedEngineLines() {
    final keys = _engine.lines.keys.toList()..sort();
    return [for (final k in keys) _engine.lines[k]!];
  }

  Widget _enginePanel() {
    return StockfishAnalysisWidget(
      isEngineEnabled: _engine.showEvaluation,
      isAllowedToUseEngine: true,
      isOnline: _engine.isOnline,
      isCustomEngineActive: _engine.isCustomEngineActive,
      lines: _sortedEngineLines(),
      orientation: _orientation,
      onToggleEngine: () {
        setState(() => _engine.showEvaluation = !_engine.showEvaluation);
        _engine.triggerAnalysis(_currentNode.fen);
      },
      isShowEvalBarEnabled: _engine.showEvalBar,
      onToggleShowEvalBar: () {
        setState(() => _engine.showEvalBar = !_engine.showEvalBar);
        _engine.triggerAnalysis(_currentNode.fen);
      },
      onLoadFenToMainBoard: _loadFenToMainBoard,
      onInsertLineAsVariation: _insertEngineLine,
    );
  }

  // ── a desktop window (D11) ───────────────────────────────────────────

  Widget _buildDesktop(Size body) {
    final layout = PreparationLayout.desktop(
      body,
      scale: AppSettingsService.instance.boardSizeScale,
    );
    final boardColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: layout.board,
          height: layout.board,
          child: _boardWidget(layout.board),
        ),
        const SizedBox(height: PreparationLayout.rowGap),
        SizedBox(width: layout.board, child: _marksWidget(layout.marks)),
        const SizedBox(height: PreparationLayout.rowGap),
        SizedBox(width: layout.board, child: _stripWidget()),
      ],
    );

    final evalSlot = SizedBox(
      width: PreparationLayout.evalBar,
      height: layout.board,
      child: _engine.showEvalBar
          ? VerticalEvalBarWidget(
              eval: _engine.eval,
              evalString: _engine.evalString,
              depth: _engine.evalDepth,
              height: layout.board,
              orientation: _orientation,
            )
          : null,
    );

    // Each in a box of its own height, scrolling inside it: an engine with
    // three lines to show is taller than its place, and what does not fit
    // scrolls in its own panel rather than moving the tree or the board.
    Widget boxed(Widget child) => SingleChildScrollView(child: child);
    final commentAndEngine = layout.commentBesideEngine
        ? SizedBox(
            height: PreparationLayout.underTreeBeside,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: boxed(_commentPanel())),
                const SizedBox(width: PreparationLayout.gap),
                Expanded(child: boxed(_enginePanel())),
              ],
            ),
          )
        : SizedBox(
            height: PreparationLayout.underTreeStacked,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: PreparationLayout.commentAlone,
                  child: boxed(_commentPanel()),
                ),
                const SizedBox(height: PreparationLayout.gap),
                Expanded(child: boxed(_enginePanel())),
              ],
            ),
          );

    // The pane is as tall as the body lets it be, and the tree takes what the
    // comment and the engine leave: nothing here is behind a tab, and nothing
    // is pushed off the window (D11).
    final pane = SizedBox(
      width: layout.paneWidth,
      height: math.max(0.0, body.height - 2 * PreparationLayout.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _treeWidget(startOnGraph: true, fills: true)),
          const SizedBox(height: PreparationLayout.gap),
          commentAndEngine,
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(PreparationLayout.padding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          evalSlot,
          const SizedBox(width: PreparationLayout.evalGap),
          boardColumn,
          const SizedBox(width: PreparationLayout.gap),
          pane,
        ],
      ),
    );
  }

  // ── a phone held upright ─────────────────────────────────────────────

  Widget _buildPhone(Size body) {
    final layout = PreparationLayout.phone(
      body,
      scale: AppSettingsService.instance.boardSizeScale,
    );
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(PreparationLayout.padding),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_engine.showEvalBar)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: PreparationLayout.rowGap),
                    child: SizedBox(
                      width: layout.board,
                      child: HorizontalEvalBarWidget(
                        eval: _engine.eval,
                        evalString: _engine.evalString,
                        depth: _engine.evalDepth,
                        orientation: _orientation,
                      ),
                    ),
                  ),
                SizedBox(
                  width: layout.board,
                  height: layout.board,
                  child: _boardWidget(layout.board),
                ),
                const SizedBox(height: PreparationLayout.rowGap),
                SizedBox(
                    width: layout.board, child: _marksWidget(layout.marks)),
                const SizedBox(height: PreparationLayout.rowGap),
                SizedBox(width: layout.board, child: _stripWidget()),
              ],
            ),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _PinnedPhoneTabs(child: _phoneTabBar()),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(PreparationLayout.padding),
          sliver: SliverToBoxAdapter(child: _phoneTabContent()),
        ),
      ],
    );
  }

  Widget _phoneTabBar() {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: TabBar(
        controller: _phoneTabs,
        tabs: const [
          Tab(text: 'Tree'),
          Tab(text: 'Comment'),
          Tab(text: 'Engine')
        ],
      ),
    );
  }

  Widget _phoneTabContent() {
    return switch (_phoneTabs.index) {
      0 => _treeWidget(startOnGraph: false),
      1 => _commentPanel(),
      _ => _enginePanel(),
    };
  }

  // ── a phone held on its side ─────────────────────────────────────────

  Widget _buildLandscape(Size body) {
    return LandscapeBoardLayout(
      boardScale: AppSettingsService.instance.boardSizeScale,
      board: _boardWidget,
      boardAside: (height) => _engine.showEvalBar
          ? VerticalEvalBarWidget(
              eval: _engine.eval,
              evalString: _engine.evalString,
              depth: _engine.evalDepth,
              height: height,
              orientation: _orientation,
            )
          : const SizedBox.shrink(),
      header: _phoneTabBar(),
      panels: _phoneTabContent(),
      footer: [
        _marksWidget(
            PreparationLayout.marksFor(LandscapeBoardLayout.minPanelWidth)),
        _stripWidget(),
      ],
    );
  }
}

class _PinnedPhoneTabs extends SliverPersistentHeaderDelegate {
  const _PinnedPhoneTabs({required this.child});

  final Widget child;

  static const double _extent = 48;

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      child;

  @override
  bool shouldRebuild(_PinnedPhoneTabs oldDelegate) =>
      oldDelegate.child != child;
}

/// The comment's `TextField` — a `StatefulWidget` so its controller belongs to
/// the node it was seeded from rather than to a `build()` that runs again
/// under the caret. Keyed by the node's id at the call site, so a new node
/// gets a fresh instance rather than this one's text.
class _CommentField extends StatefulWidget {
  const _CommentField({
    super.key,
    required this.node,
    required this.enabled,
    required this.onChanged,
  });

  final AnalysisNode node;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  State<_CommentField> createState() => _CommentFieldState();
}

class _CommentFieldState extends State<_CommentField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.node.comment);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('prep-comment'),
      controller: _controller,
      enabled: widget.enabled,
      minLines: 2,
      maxLines: 4,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
      ),
      onChanged: widget.onChanged,
    );
  }
}
