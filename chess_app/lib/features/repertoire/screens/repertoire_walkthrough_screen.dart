import 'package:flutter/material.dart';

import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/features/repertoire/services/walkthrough_order.dart';
import 'package:chess_app/features/repertoire/services/walkthrough_speech.dart';
import 'package:chess_app/features/repertoire/widgets/repertoire_tree_panel.dart';
import 'package:chess_app/features/repertoire/models/walkthrough_cursor.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/widgets/visual_move_tree_widget.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/theme/breakpoints.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';
import 'package:chess_app/widgets/game_screen/move_keyboard_shortcuts.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/speakable_info.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;

class RepertoireWalkthroughScreen extends StatefulWidget {
  const RepertoireWalkthroughScreen({
    super.key,
    required this.name,
    required this.color,
    required this.rootFen,
    required this.api,
    this.rootPath = const [],
    this.gateUci,
    this.minRating,
    this.breadth,
    this.onBuildHere,
  });

  final String name;
  final String color; // 'w' | 'b'
  final String rootFen;
  final List<String> rootPath;
  final String? gateUci;
  final int? minRating;
  final String? breadth;
  final RepertoireApiService api;
  final void Function(String fen)? onBuildHere;

  @override
  State<RepertoireWalkthroughScreen> createState() =>
      _RepertoireWalkthroughScreenState();
}

class _RepertoireWalkthroughScreenState
    extends State<RepertoireWalkthroughScreen> {
  RepertoireTree? _tree;
  Map<String, RepertoireComment>? _comments;
  bool _loading = true;
  bool _failed = false;

  List<WalkthroughStop> _stops = [];
  AnalysisNode? _root;
  final Map<String, MoveTreeNodeLook> _looks = {};

  int _index = 0;

  /// Whether the board is shown from the other side. A repertoire for Black
  /// opens from Black's side, which is right; the button is there for the
  /// moment the reader wants to see the position the way the opponent does.
  bool _flipped = false;
  final ChessBoardController _boardController = ChessBoardController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final tree = await widget.api.repertoireTree(
      color: widget.color,
      rootFen: widget.rootFen,
      rootPath: widget.rootPath,
      minRating: widget.minRating,
      gateUci: widget.gateUci,
      breadth: widget.breadth,
      maxPly: 30,
    );
    final comments = await widget.api.comments(color: widget.color);

    if (!mounted) return;

    if (tree == null) {
      setState(() {
        _failed = true;
        _loading = false;
      });
      return;
    }

    _stops = walkthroughOrder(tree);
    _root = repertoireTreeToNodes(tree, looks: _looks);

    setState(() {
      _tree = tree;
      _comments = comments;
      _loading = false;
      if (_stops.isEmpty) {
        _index = -1;
      } else {
        _index = 0;
      }
    });

    _syncBoard();
  }

  void _syncBoard() {
    if (_tree == null) return;
    if (_index < 0) {
      _boardController.loadFen(_tree!.rootFen);
    } else if (_index < _stops.length) {
      _boardController.loadFen(_stops[_index].move.fen);
    }
  }

  void _onSelect(int index) {
    if (index < -1 || index >= _stops.length) return;
    setState(() {
      _index = index;
    });
    _syncBoard();
  }

  @override
  Widget build(BuildContext context) {
    final tree = _tree;

    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upoznaj repertoar',
                style:
                    AppText.title.copyWith(color: context.colors.textPrimary)),
            Text(widget.name,
                style:
                    AppText.body.copyWith(color: context.colors.textSecondary)),
          ],
        ),
        backgroundColor: context.colors.surface,
        iconTheme: IconThemeData(color: context.colors.textPrimary),
      ),
      body: _buildBody(context, tree),
    );
  }

  Widget _buildBody(BuildContext context, RepertoireTree? tree) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed) {
      return Center(
        child: Text(
          'Ne mogu da učitam repertoar. Pokušajte ponovo.',
          style: AppText.body.copyWith(color: context.colors.danger),
        ),
      );
    }
    if (tree == null || _stops.isEmpty) {
      return Center(
        child: Text(
          'U ovom repertoaru još nema poteza.',
          style: AppText.body.copyWith(color: context.colors.textMuted),
        ),
      );
    }

    final cursor = WalkthroughCursor(
      tree: tree,
      stops: _stops,
      index: _index,
      onSelect: _onSelect,
    );

    final isWide = Breakpoints.isWide(context);
    final ownSide = widget.color == 'w' ? PlayerColor.white : PlayerColor.black;
    final boardOrientation = _flipped
        ? (ownSide == PlayerColor.white ? PlayerColor.black : PlayerColor.white)
        : ownSide;

    String? lastMoveFrom;
    String? lastMoveTo;
    if (_index >= 0 && _index < _stops.length) {
      final uci = _stops[_index].move.uci;
      if (uci.length >= 4) {
        lastMoveFrom = uci.substring(0, 2);
        lastMoveTo = uci.substring(2, 4);
      }
    }

    final boardCol = Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final size =
                constraints.maxWidth < 600 ? constraints.maxWidth : 600.0;
            return SizedBox(
              width: size,
              height: size,
              child: ChessBoardWithOverlay(
                controller: _boardController,
                boardSize: size,
                boardOrientation: boardOrientation,
                isAllowedToMove: false,
                isDrawingMode: false,
                drawingStartSquare: null,
                arrows: const [],
                engineArrows: const [],
                onMove: (String from, String to, String promotion) {},
                onSquareTapForDrawing: (String square) {},
                lastMoveFrom: lastMoveFrom,
                lastMoveTo: lastMoveTo,
              ),
            );
          },
        ),
        MoveKeyboardShortcuts(
          cursor: cursor,
          onChanged: () {},
          child: MoveNavigationControls(
            cursor: cursor,
            centerLabel: _stops.length > 1
                ? 'Potez ${_index + 1} od ${_stops.length}'
                : null,
            canNavigate: _stops.length > 1,
            onFlipBoard: () => setState(() => _flipped = !_flipped),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _buildCard(context, cursor),
            ],
          ),
        ),
      ],
    );

    if (isWide && _root != null) {
      final currentFen = cursor.currentFen;
      AnalysisNode? activeNode = _root;
      if (currentFen != null) {
        activeNode = findNodeByFen(_root!, currentFen) ?? _root;
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 1, child: boardCol),
          Container(
            width: 1,
            color: context.colors.border,
          ),
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: RepertoireTreePanel(
                root: _root!,
                active: activeNode!,
                onSelect: (node) {
                  final key = fenKeyOf(node.fen);
                  final idx =
                      _stops.indexWhere((s) => fenKeyOf(s.move.fen) == key);
                  if (idx >= 0) _onSelect(idx);
                },
                nodeLook: (node) => _looks[node.id],
                showCut: false,
                minRating: widget.minRating,
                breadth: widget.breadth,
              ),
            ),
          ),
        ],
      );
    } else {
      return boardCol;
    }
  }

  Widget _buildCard(BuildContext context, WalkthroughCursor cursor) {
    if (_index < 0) return const SizedBox.shrink();

    final stop = _stops[_index];
    final replies = cursor.forwardMoves;
    final comment = _comments?[fenKeyOf(stop.move.fen)];

    // One composition, drawn twice. `line.parts` become the lines on the card
    // and `line.spoken` is those same words joined for the voice, so what is
    // read aloud is what is on screen by construction rather than by two
    // functions agreeing.
    final line = walkthroughLine(
      stop,
      replies: replies,
      note: comment?.body,
    );

    final parts = <Widget>[];
    for (var i = 0; i < line.parts.length; i++) {
      if (i > 0) parts.add(const SizedBox(height: AppSpacing.xs));
      parts.add(Text(
        line.parts[i],
        style: AppText.body.copyWith(
          color: i == 0
              ? context.colors.textPrimary
              : context.colors.textSecondary,
        ),
      ));
    }

    // The chips read the same list the sentence names, in the same order, so
    // the two cannot disagree about which reply comes first.
    final theirs = replies.where((move) => !move.mine).length;
    if (theirs > 1) {
      final branches = cursor.forwardBranches;
      parts.add(const SizedBox(height: AppSpacing.sm));
      parts.add(Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: branches.asMap().entries.map((e) {
          return ActionChip(
            backgroundColor: context.colors.surfaceRaised,
            label: Text(e.value.label,
                style:
                    AppText.body.copyWith(color: context.colors.textPrimary)),
            onPressed: () => cursor.takeBranch(e.key),
          );
        }).toList(),
      ));
    }

    if (stop.kind == MoveTreeNodeLook.gap && widget.onBuildHere != null) {
      parts.add(const SizedBox(height: AppSpacing.sm));
      parts.add(ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: context.colors.brand,
          foregroundColor: context.colors.canvas,
        ),
        onPressed: () => widget.onBuildHere!(stop.move.fen),
        child: const Text('Napravi odgovor'),
      ));
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadii.roundedMd,
      ),
      // `autoSpeak` is the whole anti-fatigue design: a fork, a hole or a note
      // is worth interrupting the reader for and an ordinary move on the trunk
      // is not. Nothing here calls `stop()` — the reader ends a sentence by
      // moving, and on Windows a `stop()` before anything was said takes the
      // process with it.
      child: SpeakableInfo(
        text: line.spoken,
        autoSpeak: line.speak,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: parts,
        ),
      ),
    );
  }
}
