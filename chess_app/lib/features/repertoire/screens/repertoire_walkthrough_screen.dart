import 'package:flutter/material.dart';

import 'package:chess_app/core/services/serbian_plural.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/features/repertoire/services/walkthrough_order.dart';
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
    final move = stop.move;
    final kind = stop.kind;

    final parts = <Widget>[];

    if (kind == MoveTreeNodeLook.authored) {
      final primary = move.role == 'primary' || move.role == null;
      parts.add(Text(
        primary ? 'Vaš potez — glavna linija.' : 'Vaš potez — druga mogućnost.',
        style: AppText.body.copyWith(color: context.colors.textPrimary),
      ));
    } else if (kind == MoveTreeNodeLook.covered) {
      final percentStr = shareLabel(move.share);
      if (percentStr != null) {
        parts.add(Text(
          'Protivnik igra ${move.san} — $percentStr partija.',
          style: AppText.body.copyWith(color: context.colors.textPrimary),
        ));
      } else {
        parts.add(Text(
          'Protivnik igra ${move.san}.',
          style: AppText.body.copyWith(color: context.colors.textPrimary),
        ));
      }
      if (move.state == 'unopened') {
        parts.add(const SizedBox(height: AppSpacing.xs));
        parts.add(Text(
          'Odluka bez uzetih odgovora.',
          style: AppText.body.copyWith(color: context.colors.textSecondary),
        ));
      }
    } else if (kind == MoveTreeNodeLook.gap) {
      // The same rule the covered sentence follows and the mark follows: a
      // share of nothing is left out rather than written as „0%".
      final percentStr = shareLabel(move.share);
      parts.add(Text(
        percentStr == null
            ? 'Na ${move.san} nemate odgovor.'
            : 'Na ${move.san}, $percentStr partija, nemate odgovor.',
        style: AppText.body.copyWith(color: context.colors.textPrimary),
      ));
      if (widget.onBuildHere != null) {
        parts.add(const SizedBox(height: AppSpacing.sm));
        parts.add(ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: context.colors.brand,
            foregroundColor: context.colors.canvas,
          ),
          onPressed: () => widget.onBuildHere!(move.fen),
          child: const Text('Napravi odgovor'),
        ));
      }
    }

    final forward = cursor.forwardBranches;
    // The next moves are the opponent's if the current move is ours (mine),
    // or if we are at the root (index < 0, but we return early above).
    if (forward.length > 1 && move.mine) {
      parts.add(const SizedBox(height: AppSpacing.md));
      parts.add(Text(
        'Odavde protivnik ima ${forward.length} '
        '${serbianCount(forward.length, one: "odgovor", few: "odgovora", many: "odgovora")}:',
        style: AppText.body.copyWith(color: context.colors.textSecondary),
      ));
      parts.add(const SizedBox(height: AppSpacing.sm));
      parts.add(Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: forward.asMap().entries.map((e) {
          final branchIndex = e.key;
          final branch = e.value;
          return ActionChip(
            backgroundColor: context.colors.surfaceRaised,
            label: Text(branch.label,
                style:
                    AppText.body.copyWith(color: context.colors.textPrimary)),
            onPressed: () => cursor.takeBranch(branchIndex),
          );
        }).toList(),
      ));
    }

    final key = fenKeyOf(move.fen);
    final comment = _comments?[key];
    if (comment != null && comment.body.isNotEmpty) {
      parts.add(const SizedBox(height: AppSpacing.md));
      parts.add(Text(
        'Vaša napomena:',
        style: AppText.bodyBold.copyWith(color: context.colors.textPrimary),
      ));
      parts.add(const SizedBox(height: AppSpacing.xs));
      parts.add(Text(
        comment.body,
        style: AppText.body.copyWith(color: context.colors.textSecondary),
      ));
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadii.roundedMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: parts,
      ),
    );
  }
}
