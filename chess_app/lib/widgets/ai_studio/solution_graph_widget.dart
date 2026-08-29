import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess/chess.dart' as chess;

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/ai_studio/solution_tree_models.dart';
import 'package:chess_app/widgets/ai_studio/grouped_moves_dialog.dart';

/// Walks [currentLevel] (and its subtrees) looking for [target], returning
/// the chain of nodes from the top of [currentLevel] down to it. Used to
/// replay a puzzle's solution up to a node the user tapped in the graph,
/// since grouped nodes need every ancestor's currently-selected branch
/// applied in order to land on the right FEN.
List<SolutionGraphNode> findPathToGraphNode(
    List<SolutionGraphNode> currentLevel, SolutionGraphNode target) {
  for (var node in currentLevel) {
    if (node.id == target.id) {
      return [node];
    }
    if (node.children.isNotEmpty) {
      final subPath = findPathToGraphNode(node.children, target);
      if (subPath.isNotEmpty) {
        return [node, ...subPath];
      }
    }
  }
  return [];
}

enum _PlaySpeed {
  slow(Duration(milliseconds: 1400), 'Sporo'),
  normal(Duration(milliseconds: 800), 'Normalno'),
  fast(Duration(milliseconds: 350), 'Brzo');

  final Duration interval;
  final String label;
  const _PlaySpeed(this.interval, this.label);
}

/// Renders the puzzle's solution tree as a pannable/zoomable node graph.
///
/// The tree-building and layout math (turning the raw `{uci: {uci: ...}}`
/// solutions map into positioned, sized nodes) lives here since it only
/// depends on read-only inputs — [solutions] and [selectedGroupedMoveIndices]
/// — not on the screen's live puzzle-solving state. Tapping a node reports
/// back through [onNodeTap] / [onGroupedMoveSelected]; the screen still owns
/// applying that to the board, since it also has to update the engine and
/// the shared board controller.
///
/// Also owns an auto-player: steps through every node in the tree currently
/// shown (a preorder walk — a variation is played to its end before
/// backtracking to the next one), reusing the same [onNodeTap] navigation a
/// manual click would use. Grouped nodes are advanced directly rather than
/// popping the "choose a variant" dialog, since that would stall playback
/// waiting on input — it follows whichever variant is already selected.
class SolutionGraphWidget extends StatefulWidget {
  final bool visible;
  final String? initialFen;
  final Map<String, dynamic> solutions;
  final String mateDepthLabel;
  final String? activeFen;
  final Map<String, int> selectedGroupedMoveIndices;
  final ValueChanged<List<SolutionGraphNode>> onNodesBuilt;
  final ValueChanged<SolutionGraphNode> onNodeTap;
  final void Function(SolutionGraphNode node, int selectedIndex)
      onGroupedMoveSelected;

  const SolutionGraphWidget({
    super.key,
    required this.visible,
    required this.initialFen,
    required this.solutions,
    required this.mateDepthLabel,
    required this.activeFen,
    required this.selectedGroupedMoveIndices,
    required this.onNodesBuilt,
    required this.onNodeTap,
    required this.onGroupedMoveSelected,
  });

  @override
  State<SolutionGraphWidget> createState() => _SolutionGraphWidgetState();
}

class _SolutionGraphWidgetState extends State<SolutionGraphWidget> {
  Timer? _playTimer;
  _PlaySpeed _playSpeed = _PlaySpeed.normal;
  List<SolutionGraphNode> _playbackOrder = [];

  bool get _isPlaying => _playTimer != null;

  @override
  void dispose() {
    _playTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SolutionGraphWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.visible && _isPlaying) {
      _stopPlay();
    }
  }

  void _togglePlay() {
    if (_isPlaying) {
      _stopPlay();
    } else {
      _startPlay();
    }
  }

  void _startPlay() {
    if (_playbackOrder.isEmpty) return;
    setState(() {
      _playTimer = Timer.periodic(_playSpeed.interval, (_) => _advancePlay());
    });
    _advancePlay();
  }

  void _stopPlay() {
    if (!_isPlaying) return;
    setState(() {
      _playTimer?.cancel();
      _playTimer = null;
    });
  }

  void _setPlaySpeed(_PlaySpeed speed) {
    setState(() => _playSpeed = speed);
    if (_isPlaying) {
      _playTimer?.cancel();
      _playTimer = Timer.periodic(_playSpeed.interval, (_) => _advancePlay());
    }
  }

  void _advancePlay() {
    if (_playbackOrder.isEmpty) {
      _stopPlay();
      return;
    }
    final activeBoard = widget.activeFen?.split(' ')[0];
    final currentIdx =
        _playbackOrder.indexWhere((n) => n.fen.split(' ')[0] == activeBoard);
    final nextIdx = currentIdx + 1;
    if (nextIdx >= _playbackOrder.length) {
      _stopPlay();
      return;
    }
    widget.onNodeTap(_playbackOrder[nextIdx]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (!widget.visible ||
        widget.solutions.isEmpty ||
        widget.initialFen == null) {
      return const SizedBox.shrink();
    }

    final List<SolutionGraphNode> rootNodes = _buildSolutionGraphNodes(
      widget.initialFen!,
      widget.solutions,
      true,
      'root',
    );
    widget.onNodesBuilt(rootNodes);
    if (rootNodes.isEmpty) return const SizedBox.shrink();

    final List<PositionedNode> positionedNodes = [];
    double currentLeft = 0.0;
    const double nodeWidth = 115.0;
    const double nodeHeight = 44.0;
    const double levelSpacing = 36.0;
    const double siblingSpacing = 16.0;

    for (var rNode in rootNodes) {
      final w = _calculateSubtreeWidth(rNode, nodeWidth, siblingSpacing);
      _layoutGraphNodes(
        rNode,
        currentLeft,
        0.0,
        nodeWidth,
        nodeHeight,
        levelSpacing,
        siblingSpacing,
        null,
        positionedNodes,
      );
      currentLeft += w + siblingSpacing;
    }

    // Preorder = exactly the order _layoutGraphNodes just walked the tree
    // in, so this doubles as the auto-player's script.
    _playbackOrder = positionedNodes.map((pn) => pn.node).toList();

    double maxRight = 0.0;
    double maxBottom = 0.0;
    for (var pn in positionedNodes) {
      if (pn.x + pn.width > maxRight) maxRight = pn.x + pn.width;
      if (pn.y + pn.height > maxBottom) maxBottom = pn.y + pn.height;
    }

    final double canvasWidth =
        math.max(maxRight + 20.0, MediaQuery.of(context).size.width - 32.0);
    final double canvasHeight = maxBottom + 20.0;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs, vertical: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.canvas,
        borderRadius: AppRadii.roundedLg,
        border: Border.all(color: colors.info, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: colors.info.withValues(alpha: 0.25),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.account_tree_outlined,
                      color: colors.info, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Grafičko Stablo Poteza',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: colors.textPrimary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: AppRadii.roundedSm,
                ),
                child: Text(
                  widget.mateDepthLabel,
                  style: AppText.captionBold.copyWith(color: colors.info),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              InkWell(
                onTap: _togglePlay,
                borderRadius: AppRadii.roundedLg,
                child: Icon(
                  _isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  size: 26,
                  color: colors.info,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _isPlaying
                    ? 'Reprodukcija rešenja...'
                    : 'Pusti rešenje automatski',
                style: AppText.caption.copyWith(color: colors.textSecondary),
              ),
              const Spacer(),
              _buildSpeedButton(),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: math.min(
                canvasHeight + 20.0,
                MediaQuery.of(context).orientation == Orientation.landscape
                    ? math.max(
                        280.0, MediaQuery.of(context).size.height - 180.0)
                    : 340.0),
            child: ClipRRect(
              borderRadius: AppRadii.roundedMd,
              child: Container(
                color: colors.canvasRecessed,
                child: InteractiveViewer(
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(40),
                  minScale: 0.5,
                  maxScale: 2.5,
                  child: Container(
                    width: canvasWidth,
                    height: canvasHeight,
                    padding: const EdgeInsets.all(10),
                    child: Stack(
                      children: [
                        CustomPaint(
                          size: Size(canvasWidth, canvasHeight),
                          painter: TreeEdgesPainter(
                            positionedNodes: positionedNodes,
                            activeFen: widget.activeFen,
                            edgeColor: colors.surfaceRaised,
                            activeEdgeColor: colors.info,
                          ),
                        ),
                        ...positionedNodes
                            .map((pn) => _buildGraphNodeWidget(context, pn)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedButton() {
    final colors = context.colors;

    return PopupMenuButton<_PlaySpeed>(
      tooltip: 'Brzina: ${_playSpeed.label}',
      initialValue: _playSpeed,
      color: colors.surface,
      onSelected: _setPlaySpeed,
      itemBuilder: (ctx) => _PlaySpeed.values.map((s) {
        return PopupMenuItem<_PlaySpeed>(
          value: s,
          child: Row(
            children: [
              Icon(s == _playSpeed ? Icons.check : null,
                  size: 14, color: colors.info),
              const SizedBox(width: 6),
              Text(
                s.label,
                style: AppText.bodyLarge.copyWith(color: colors.textPrimary),
              ),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: AppRadii.roundedSm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.speed, size: 13, color: colors.info),
            const SizedBox(width: AppSpacing.xs),
            Text(
              _playSpeed.label,
              style: AppText.caption.copyWith(color: colors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphNodeWidget(BuildContext context, PositionedNode pn) {
    final colors = context.colors;
    final node = pn.node;
    final bool isActive = (widget.activeFen != null &&
        widget.activeFen!.split(' ')[0] == node.fen.split(' ')[0]);

    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData? iconData;

    if (isActive) {
      bgColor = colors.infoContainer;
      borderColor = colors.info;
      textColor = colors.onInfoContainer;
      iconData = Icons.play_arrow_rounded;
    } else if (node.isCheckmate) {
      bgColor = colors.successContainer;
      borderColor = colors.successContainerBorder;
      textColor = colors.onSuccessContainer;
      iconData = Icons.emoji_events;
    } else if (node.isGrouped) {
      bgColor = colors.groupedContainer;
      borderColor = colors.groupedContainerBorder;
      textColor = colors.onGroupedContainer;
      iconData = Icons.filter_list;
    } else if (node.isWhite) {
      bgColor = colors.surface;
      borderColor = colors.textMuted;
      textColor = colors.textPrimary;
    } else {
      bgColor = colors.canvas;
      borderColor = colors.surfaceRaised;
      textColor = colors.textMuted;
    }

    return Positioned(
      left: pn.x,
      top: pn.y,
      width: pn.width,
      height: pn.height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _stopPlay();
            if (node.isGrouped && node.groupedOpponentMoves.isNotEmpty) {
              showGroupedMovesDialog(
                context: context,
                node: node,
                onMoveSelected: widget.onGroupedMoveSelected,
              );
            } else {
              widget.onNodeTap(node);
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(
                horizontal: 6, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: borderColor, width: isActive ? 2.5 : 1.5),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: colors.info.withValues(alpha: 0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (iconData != null) ...[
                  Icon(iconData, size: 14, color: textColor),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Flexible(
                  child: Text(
                    node.moveSan,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (isActive || node.isCheckmate
                            ? AppText.bodyBold
                            : AppText.body)
                        .copyWith(
                      fontWeight: isActive || node.isCheckmate
                          ? FontWeight.bold
                          : FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<SolutionGraphNode> _buildSolutionGraphNodes(
    String currentFen,
    Map<String, dynamic> treeMap,
    bool isWhiteMove,
    String parentIdPath,
  ) {
    final List<SolutionGraphNode> nodes = [];

    if (isWhiteMove) {
      int moveIdx = 0;
      for (var whiteMoveUci in treeMap.keys) {
        if (whiteMoveUci.length < 4) continue;
        moveIdx++;
        final nodeId = '${parentIdPath}_w$moveIdx';
        final game = chess.Chess.fromFEN(currentFen);

        final from = whiteMoveUci.substring(0, 2);
        final to = whiteMoveUci.substring(2, 4);
        final promo = whiteMoveUci.length > 4 ? whiteMoveUci[4] : null;

        String san = '$from$to';
        for (var m in legalMoves(game)) {
          if (m['from'] == from && m['to'] == to) {
            if (promo == null ||
                m['promotion'] == promo ||
                m['promotion'] == promo.toLowerCase()) {
              san = m['san'] ?? san;
              break;
            }
          }
        }

        game.move({'from': from, 'to': to, 'promotion': promo});
        final fenAfterWhite = game.fen;
        final isMate = game.in_checkmate;

        final dynamic sub = treeMap[whiteMoveUci];
        List<SolutionGraphNode> children = [];

        if (sub is Map && sub.isNotEmpty) {
          children = _buildSolutionGraphNodes(
            fenAfterWhite,
            Map<String, dynamic>.from(sub),
            false,
            nodeId,
          );
        }

        nodes.add(SolutionGraphNode(
          id: nodeId,
          moveUci: whiteMoveUci,
          moveSan: san,
          fen: fenAfterWhite,
          isWhite: true,
          isCheckmate: isMate || sub == "CHECKMATE",
          children: children,
        ));
      }
    } else {
      final Map<String, List<String>> signatureToOpponentMoves = {};
      final Map<String, dynamic> signatureToSubTree = {};

      for (var oppMoveUci in treeMap.keys) {
        final sub = treeMap[oppMoveUci];
        String sig = '';
        if (sub is Map) {
          sig = sub.keys.join(',');
        } else if (sub is List) {
          sig = sub.join(',');
        } else {
          sig = sub.toString();
        }

        signatureToOpponentMoves
            .putIfAbsent(sig, () => [])
            .add(oppMoveUci.toString());
        signatureToSubTree[sig] = sub;
      }

      int groupIdx = 0;
      for (var sig in signatureToOpponentMoves.keys) {
        groupIdx++;
        final oppMovesList = signatureToOpponentMoves[sig]!;
        final sub = signatureToSubTree[sig];
        final nodeId = '${parentIdPath}_b$groupIdx';

        if (oppMovesList.length == 1) {
          final oppMoveUci = oppMovesList.first;
          if (oppMoveUci.length < 4) continue;
          final game = chess.Chess.fromFEN(currentFen);
          final from = oppMoveUci.substring(0, 2);
          final to = oppMoveUci.substring(2, 4);
          final promo = oppMoveUci.length > 4 ? oppMoveUci[4] : null;

          String san = '$from$to';
          for (var m in legalMoves(game)) {
            if (m['from'] == from && m['to'] == to) {
              san = m['san'] ?? san;
              break;
            }
          }

          game.move({'from': from, 'to': to, 'promotion': promo});
          final fenAfterBlack = game.fen;

          List<SolutionGraphNode> children = [];
          if (sub is Map && sub.isNotEmpty) {
            children = _buildSolutionGraphNodes(
              fenAfterBlack,
              Map<String, dynamic>.from(sub),
              true,
              nodeId,
            );
          }

          nodes.add(SolutionGraphNode(
            id: nodeId,
            moveUci: oppMoveUci,
            moveSan: '..$san',
            fen: fenAfterBlack,
            parentFen: currentFen,
            isWhite: false,
            children: children,
          ));
        } else {
          final int selectedIdx =
              (widget.selectedGroupedMoveIndices[nodeId] ?? 0)
                  .clamp(0, oppMovesList.length - 1);
          final selectedOppMove = oppMovesList[selectedIdx];
          final game = chess.Chess.fromFEN(currentFen);
          final from = selectedOppMove.substring(0, 2);
          final to = selectedOppMove.substring(2, 4);
          final promo = selectedOppMove.length > 4 ? selectedOppMove[4] : null;

          game.move({'from': from, 'to': to, 'promotion': promo});
          final fenAfterSelected = game.fen;

          List<SolutionGraphNode> children = [];
          if (sub is Map && sub.isNotEmpty) {
            children = _buildSolutionGraphNodes(
              fenAfterSelected,
              Map<String, dynamic>.from(sub),
              true,
              nodeId,
            );
          }

          final List<String> sanList = [];
          final List<String> uciList = [];
          for (var mUci in oppMovesList) {
            if (mUci.length < 4) continue;
            final gTest = chess.Chess.fromFEN(currentFen);
            final f = mUci.substring(0, 2);
            final t = mUci.substring(2, 4);
            final pr = mUci.length > 4 ? mUci[4] : null;
            String s = '$f$t';
            for (var vm in legalMoves(gTest)) {
              if (vm['from'] == f && vm['to'] == t) {
                if (pr == null ||
                    vm['promotion'] == pr ||
                    vm['promotion'] == pr.toLowerCase()) {
                  s = vm['san'] ?? s;
                  break;
                }
              }
            }
            sanList.add('..$s');
            uciList.add(mUci);
          }

          nodes.add(SolutionGraphNode(
            id: nodeId,
            moveUci: selectedOppMove,
            moveSan: '.. [${oppMovesList.length} varijanti]',
            fen: fenAfterSelected,
            parentFen: currentFen,
            isWhite: false,
            isGrouped: true,
            selectedGroupedIndex: selectedIdx,
            groupedOpponentMoves: sanList,
            groupedOpponentMovesUci: uciList,
            children: children,
          ));
        }
      }
    }

    return nodes;
  }

  double _calculateSubtreeWidth(
      SolutionGraphNode node, double nodeWidth, double siblingSpacing) {
    if (node.children.isEmpty) {
      return nodeWidth;
    }
    double sum = 0;
    for (int i = 0; i < node.children.length; i++) {
      if (i > 0) sum += siblingSpacing;
      sum +=
          _calculateSubtreeWidth(node.children[i], nodeWidth, siblingSpacing);
    }
    return math.max(nodeWidth, sum);
  }

  void _layoutGraphNodes(
    SolutionGraphNode node,
    double leftX,
    double topY,
    double nodeWidth,
    double nodeHeight,
    double levelSpacing,
    double siblingSpacing,
    PositionedNode? parentPosNode,
    List<PositionedNode> outNodes,
  ) {
    final subtreeWidth =
        _calculateSubtreeWidth(node, nodeWidth, siblingSpacing);
    final nodeX = leftX + (subtreeWidth - nodeWidth) / 2;

    final posNode = PositionedNode(
      node: node,
      x: nodeX,
      y: topY,
      width: nodeWidth,
      height: nodeHeight,
      parent: parentPosNode,
    );
    if (parentPosNode != null) {
      parentPosNode.children.add(posNode);
    }
    outNodes.add(posNode);

    double currentLeft = leftX;
    for (var child in node.children) {
      final childSubtreeWidth =
          _calculateSubtreeWidth(child, nodeWidth, siblingSpacing);
      _layoutGraphNodes(
        child,
        currentLeft,
        topY + nodeHeight + levelSpacing,
        nodeWidth,
        nodeHeight,
        levelSpacing,
        siblingSpacing,
        posNode,
        outNodes,
      );
      currentLeft += childSubtreeWidth + siblingSpacing;
    }
  }
}
