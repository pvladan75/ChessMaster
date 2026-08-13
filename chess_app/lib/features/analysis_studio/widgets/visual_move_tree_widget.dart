import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/services.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// Graphical move tree: absolutely-positioned node cards connected by curved
/// edges inside a pannable/zoomable canvas — the same layout approach as the
/// "Mat u N poteza" solution tree in AI Studio (see
/// ai_studio_screen.dart's _buildGraphicalSolutionTreeWidget /
/// solution_tree_models.dart), ported here for the general analysis tree.
///
/// InteractiveViewer alone only really works with touch (pinch to zoom, drag
/// to pan), so this adds explicit desktop-friendly controls on top: mouse
/// wheel zoom, +/- buttons, a reset/center button, and a toggle between a
/// top-down and left-to-right layout.
class VisualMoveTreeWidget extends StatefulWidget {
  final AnalysisNode rootNode;
  final AnalysisNode activeNode;
  final Function(AnalysisNode node) onSelectNode;
  final Function(AnalysisNode node)? onPromoteNode;
  final Function(AnalysisNode node)? onDeleteNode;

  /// deltaCutoff the tree was last auto-generated with, if any — caps how
  /// far the post-hoc display-filter slider can be dragged, so it can't be
  /// set past the point where it stops doing anything (those branches were
  /// never generated in the first place). Null (e.g. a hand-built tree with
  /// no auto-analysis run yet) falls back to a fixed default range.
  final double? maxDisplayCutoff;

  /// Fired on a direct tap on a node card, in addition to [onSelectNode] —
  /// lets a host (e.g. the fullscreen dialog) react to *manual* navigation
  /// specifically, without also firing for the auto-player's own steps.
  final VoidCallback? onNodeTapped;

  const VisualMoveTreeWidget({
    super.key,
    required this.rootNode,
    required this.activeNode,
    required this.onSelectNode,
    this.onPromoteNode,
    this.onDeleteNode,
    this.maxDisplayCutoff,
    this.onNodeTapped,
  });

  @override
  State<VisualMoveTreeWidget> createState() => _VisualMoveTreeWidgetState();
}

class _VisualMoveTreeWidgetState extends State<VisualMoveTreeWidget> {
  static const double _nodeWidth = 124.0;
  static const double _nodeHeight = 40.0;
  static const double _levelSpacing = 34.0;
  static const double _siblingSpacing = 14.0;
  static const double _minScale = 0.3;
  static const double _maxScale = 2.5;

  final TransformationController _transformController =
      TransformationController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'VisualMoveTreeWidget');
  bool _isHorizontal = false;
  Size _viewportSize = Size.zero;
  String? _lastCenteredNodeId;

  // Post-hoc display filter: hides children whose eval is worse than their
  // best sibling by more than this many pawns. Purely visual — it reads the
  // eval each node already got at generation time and never touches
  // AnalysisNode.children, so nothing here is destructive. Lets the user
  // react to a tree that came out too wide (too weak a deltaCutoff when
  // generating it) without re-running the engine.
  bool _filterEnabled = false;
  double _displayCutoff = 1.5;

  /// Ceiling for [_displayCutoff]'s slider — see [VisualMoveTreeWidget.maxDisplayCutoff].
  double get _effectiveMaxCutoff =>
      (widget.maxDisplayCutoff ?? 5.0).clamp(0.5, 10.0);

  /// [_displayCutoff] kept within the current [_effectiveMaxCutoff] — read
  /// this everywhere instead of the raw field so a generation that used a
  /// smaller cutoff than the slider's last position can never push the
  /// Slider widget itself out of its own min/max range.
  double get _clampedDisplayCutoff =>
      _displayCutoff.clamp(0.1, _effectiveMaxCutoff);

  // Auto-player: steps through every node the tree currently shows (i.e.
  // respecting the eval filter above) in the same order they're laid out —
  // a preorder walk, so it visits a variation in full before backtracking
  // to try the next one. Reuses the existing onSelectNode navigation, the
  // same as a manual click would.
  Timer? _playTimer;
  bool get _isPlaying => _playTimer != null;
  _PlaySpeed _playSpeed = _PlaySpeed.normal;
  List<AnalysisNode> _playbackOrder = [];

  @override
  void dispose() {
    _playTimer?.cancel();
    _transformController.dispose();
    _focusNode.dispose();
    super.dispose();
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
    final currentIdx =
        _playbackOrder.indexWhere((n) => n.id == widget.activeNode.id);
    final nextIdx = currentIdx + 1;
    if (nextIdx >= _playbackOrder.length) {
      _stopPlay();
      return;
    }
    widget.onSelectNode(_playbackOrder[nextIdx]);
  }

  void _selectParent() {
    final parent = widget.activeNode.parent;
    if (parent != null) widget.onSelectNode(parent);
  }

  void _selectFirstChild() {
    if (widget.activeNode.children.isNotEmpty) {
      widget.onSelectNode(widget.activeNode.children.first);
    }
  }

  void _selectSibling(int direction) {
    final parent = widget.activeNode.parent;
    if (parent == null) return;
    final siblings = parent.children;
    final idx = siblings.indexWhere((c) => c.id == widget.activeNode.id);
    if (idx == -1) return;
    final newIdx = idx + direction;
    if (newIdx >= 0 && newIdx < siblings.length) {
      widget.onSelectNode(siblings[newIdx]);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      _selectParent();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _selectFirstChild();
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _selectSibling(-1);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _selectSibling(1);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.numpadAdd) {
      _zoomBy(1.25);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract) {
      _zoomBy(1 / 1.25);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Groups nodes (root excluded) by position — board+turn+castling+en
  /// passant, ignoring the move-count fields so the same position reached at
  /// different move numbers still matches. Only transposition-relevant
  /// groups (2+ nodes) end up mattering to callers.
  Map<String, List<AnalysisNode>> _buildTranspositionGroups() {
    final groups = <String, List<AnalysisNode>>{};
    void walk(AnalysisNode node) {
      if (!node.isRoot) {
        final fenParts = node.fen.split(' ');
        final key =
            fenParts.length >= 4 ? fenParts.sublist(0, 4).join(' ') : node.fen;
        (groups[key] ??= []).add(node);
      }
      for (final child in node.children) {
        walk(child);
      }
    }

    walk(widget.rootNode);
    groups.removeWhere((_, nodes) => nodes.length < 2);
    return groups;
  }

  /// Short move-path label for a node, e.g. "3.d4 g6 4.Be2", used to tell
  /// transposed occurrences of the same position apart in the jump menu.
  String _movePathLabel(AnalysisNode node) {
    final chain = <AnalysisNode>[];
    AnalysisNode? cur = node;
    while (cur != null && !cur.isRoot) {
      chain.insert(0, cur);
      cur = cur.parent;
    }

    final parts = <String>[];
    for (final n in chain) {
      final parentFenParts = n.parent?.fen.split(' ') ?? const [];
      final isWhiteMove = parentFenParts.length > 1 && parentFenParts[1] == 'w';
      final moveNum = parentFenParts.length > 5 ? parentFenParts[5] : null;
      if (isWhiteMove && moveNum != null) {
        parts.add('$moveNum.${n.moveSan ?? "?"}');
      } else {
        parts.add(n.moveSan ?? '?');
      }
    }
    return parts.join(' ');
  }

  double get _siblingUnit => _isHorizontal ? _nodeHeight : _nodeWidth;
  double get _levelUnit => _isHorizontal ? _nodeWidth : _nodeHeight;

  /// True if [node] is the active node or one of its ancestors — the
  /// currently selected line is never hidden by the eval filter, so turning
  /// the cutoff down can't make the position you're looking at disappear.
  bool _isOnActivePath(AnalysisNode node) {
    AnalysisNode? cur = widget.activeNode;
    while (cur != null) {
      if (cur.id == node.id) return true;
      cur = cur.parent;
    }
    return false;
  }

  /// [node]'s children that should actually be laid out, given the current
  /// eval filter. A child survives if its eval is within [_displayCutoff]
  /// pawns of the best sibling eval — "best" meaning highest for White to
  /// move, lowest for Black, same convention the tree generator's own
  /// deltaCutoff uses. Children without an eval (e.g. hand-played moves)
  /// are always kept, since there's nothing to judge them against.
  List<AnalysisNode> _visibleChildren(AnalysisNode node) {
    final children = node.children;
    if (!_filterEnabled || children.length <= 1) return children;

    final isWhiteMove = node.fen.contains(' w ');
    double? bestEval;
    for (final c in children) {
      final e = c.eval;
      if (e == null) continue;
      if (bestEval == null || (isWhiteMove ? e > bestEval : e < bestEval)) {
        bestEval = e;
      }
    }
    if (bestEval == null) return children;

    return children.where((c) {
      final e = c.eval;
      if (e == null) return true;
      if (_isOnActivePath(c)) return true;
      final delta = isWhiteMove ? (bestEval! - e) : (e - bestEval!);
      return delta <= _clampedDisplayCutoff;
    }).toList();
  }

  double _subtreeExtent(AnalysisNode node) {
    final children = _visibleChildren(node);
    if (children.isEmpty) return _siblingUnit;
    double sum = 0;
    for (int i = 0; i < children.length; i++) {
      if (i > 0) sum += _siblingSpacing;
      sum += _subtreeExtent(children[i]);
    }
    return math.max(_siblingUnit, sum);
  }

  void _layout(AnalysisNode node, double crossStart, double mainStart,
      _PositionedNode? parentPos, List<_PositionedNode> out) {
    final extent = _subtreeExtent(node);
    final crossPos = crossStart + (extent - _siblingUnit) / 2;

    final posNode = _PositionedNode(
      node: node,
      x: _isHorizontal ? mainStart : crossPos,
      y: _isHorizontal ? crossPos : mainStart,
      width: _nodeWidth,
      height: _nodeHeight,
      parent: parentPos,
    );
    out.add(posNode);

    double currentCross = crossStart;
    for (final child in _visibleChildren(node)) {
      _layout(child, currentCross, mainStart + _levelUnit + _levelSpacing,
          posNode, out);
      currentCross += _subtreeExtent(child) + _siblingSpacing;
    }
  }

  /// Formats a node's stored eval (White's-perspective pawns, with mate
  /// lines encoded as ±(1000 - movesToMate) — see AutoTreeGeneratorService)
  /// back into the usual "+2.80" / "-1.35" / "M3" / "-M4" notation.
  String _formatEval(double val) {
    if (val.abs() > 500) {
      final mateNum = (val > 0 ? (1000 - val) : (1000 + val)).round();
      return val > 0 ? 'M$mateNum' : '-M$mateNum';
    }
    return val > 0 ? '+${val.toStringAsFixed(2)}' : val.toStringAsFixed(2);
  }

  void _zoomBy(double factor, {Offset? focalViewportPoint}) {
    final focal = focalViewportPoint ??
        Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final targetScale = (currentScale * factor).clamp(_minScale, _maxScale);
    final effectiveFactor = targetScale / currentScale;
    if (effectiveFactor == 1.0) return;

    final focalScenePoint = _transformController.toScene(focal);
    final updated = _transformController.value.clone()
      ..translateByDouble(focalScenePoint.dx, focalScenePoint.dy, 0, 1)
      ..scaleByDouble(effectiveFactor, effectiveFactor, 1, 1)
      ..translateByDouble(-focalScenePoint.dx, -focalScenePoint.dy, 0, 1);
    _transformController.value = updated;
  }

  void _resetView() {
    _transformController.value = Matrix4.identity();
  }

  void _centerOnActive(List<_PositionedNode> positioned) {
    if (_viewportSize == Size.zero) return;
    _PositionedNode? activePos;
    for (final pn in positioned) {
      if (pn.node.id == widget.activeNode.id) {
        activePos = pn;
        break;
      }
    }
    if (activePos == null) return;

    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final targetX = activePos.x + activePos.width / 2;
    final targetY = activePos.y + activePos.height / 2;

    final matrix = Matrix4.identity()
      ..translateByDouble(
          _viewportSize.width / 2, _viewportSize.height / 2, 0, 1)
      ..scaleByDouble(currentScale, currentScale, 1, 1)
      ..translateByDouble(-targetX, -targetY, 0, 1);
    _transformController.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    final List<_PositionedNode> positioned = [];
    _layout(widget.rootNode, 0.0, 0.0, null, positioned);
    final transpositionGroups = _buildTranspositionGroups();

    // Preorder = exactly the order _layout just walked the (filtered) tree
    // in, so this doubles as the auto-player's script.
    _playbackOrder = positioned.map((pn) => pn.node).toList();

    double maxRight = 0.0;
    double maxBottom = 0.0;
    for (final pn in positioned) {
      if (pn.x + pn.width > maxRight) maxRight = pn.x + pn.width;
      if (pn.y + pn.height > maxBottom) maxBottom = pn.y + pn.height;
    }
    final canvasWidth = maxRight + 20.0;
    final canvasHeight = maxBottom + 20.0;

    if (_lastCenteredNodeId != widget.activeNode.id) {
      _lastCenteredNodeId = widget.activeNode.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _centerOnActive(positioned);
      });
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
          return Focus(
            focusNode: _focusNode,
            onKeyEvent: _handleKeyEvent,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Listener(
                    onPointerSignal: (event) {
                      if (event is PointerScrollEvent) {
                        final factor = event.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1;
                        _zoomBy(factor,
                            focalViewportPoint: event.localPosition);
                      }
                    },
                    child: Container(
                      color: const ui.Color(0xFF020617),
                      child: InteractiveViewer(
                        transformationController: _transformController,
                        constrained: false,
                        boundaryMargin: const EdgeInsets.all(200),
                        minScale: _minScale,
                        maxScale: _maxScale,
                        child: SizedBox(
                          width: canvasWidth,
                          height: canvasHeight,
                          child: Stack(
                            children: [
                              CustomPaint(
                                size: Size(canvasWidth, canvasHeight),
                                painter: _TreeEdgesPainter(
                                  positionedNodes: positioned,
                                  activeNodeId: widget.activeNode.id,
                                  isHorizontal: _isHorizontal,
                                ),
                              ),
                              ...positioned.map((pn) => _buildNodeCard(
                                  context, pn, transpositionGroups)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: _buildToolbar(positioned),
                ),
                if (_filterEnabled)
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: _buildCutoffBar(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolbar(List<_PositionedNode> positioned) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toolbarButton(Icons.add, 'Uvećaj', () => _zoomBy(1.25)),
          _toolbarButton(Icons.remove, 'Umanji', () => _zoomBy(1 / 1.25)),
          _toolbarButton(Icons.center_focus_strong,
              'Centriraj na aktivni potez', () => _centerOnActive(positioned)),
          _toolbarButton(Icons.restart_alt, 'Resetuj pogled', _resetView),
          _toolbarButton(
            _isHorizontal ? Icons.swap_vert : Icons.swap_horiz,
            _isHorizontal ? 'Vertikalni raspored' : 'Horizontalni raspored',
            () => setState(() => _isHorizontal = !_isHorizontal),
          ),
          _toolbarButton(
            _filterEnabled ? Icons.filter_alt : Icons.filter_alt_off,
            _filterEnabled
                ? 'Isključi naknadni filter po eval-u'
                : 'Uključi naknadni filter po eval-u (sakrij slabije grane)',
            () => setState(() => _filterEnabled = !_filterEnabled),
          ),
          const Divider(height: 6, color: Colors.white24),
          _toolbarButton(
            _isPlaying ? Icons.pause : Icons.play_arrow,
            _isPlaying
                ? 'Pauziraj automatsko prikazivanje'
                : 'Pusti automatsko prikazivanje svih (vidljivih) linija',
            _togglePlay,
          ),
          _buildSpeedButton(),
        ],
      ),
    );
  }

  Widget _buildSpeedButton() {
    return PopupMenuButton<_PlaySpeed>(
      tooltip: 'Brzina prikazivanja: ${_playSpeed.label}',
      initialValue: _playSpeed,
      color: Colors.grey.shade900,
      onSelected: _setPlaySpeed,
      itemBuilder: (ctx) => _PlaySpeed.values.map((s) {
        return PopupMenuItem<_PlaySpeed>(
          value: s,
          child: Row(
            children: [
              Icon(
                s == _playSpeed ? Icons.check : null,
                size: 14,
                color: context.colors.accent,
              ),
              const SizedBox(width: 6),
              Text(s.label, style: TextStyle(color: context.colors.textPrimary)),
            ],
          ),
        );
      }).toList(),
      child: Tooltip(
        message: 'Brzina prikazivanja: ${_playSpeed.label}',
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Icon(Icons.speed, size: 16, color: context.colors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildCutoffBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.filter_alt, size: 14, color: context.colors.warning),
          const SizedBox(width: 6),
          Text(
            'Prag: ${_clampedDisplayCutoff.toStringAsFixed(1)} / ${_effectiveMaxCutoff.toStringAsFixed(1)}',
            style: TextStyle(fontSize: 11, color: context.colors.textPrimary),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: _clampedDisplayCutoff,
                min: 0.1,
                max: _effectiveMaxCutoff,
                divisions: (((_effectiveMaxCutoff - 0.1) * 10).round()).clamp(1, 200),
                activeColor: context.colors.warning,
                onChanged: (v) => setState(() => _displayCutoff = v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbarButton(IconData icon, String tooltip, VoidCallback onPressed) {
    // 10px padding around a 16px icon gives a 36px tap target — short of the
    // 48dp guideline, but this is a 5-button column floating over the tree
    // canvas, so a full 48dp each would make the toolbar dominate a phone
    // screen. 36px is the practical middle ground.
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Icon(icon, size: 16, color: context.colors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildNodeCard(BuildContext context, _PositionedNode pn,
      Map<String, List<AnalysisNode>> transpositionGroups) {
    final node = pn.node;
    final isSelected = node.id == widget.activeNode.id;
    final isMainLine = node.isMainLine;

    final fenParts = node.fen.split(' ');
    final posKey =
        fenParts.length >= 4 ? fenParts.sublist(0, 4).join(' ') : node.fen;
    final transpositionGroup = transpositionGroups[posKey];
    final isTransposition = transpositionGroup != null;

    Color bgColor;
    Color borderColor;
    Color textColor = Colors.white;

    if (isSelected) {
      bgColor = Colors.teal.shade700;
      borderColor = Colors.tealAccent;
    } else if (node.isRoot) {
      bgColor = const ui.Color(0xFF1E293B);
      borderColor = Colors.white24;
      textColor = Colors.white70;
    } else if (isMainLine) {
      bgColor = const ui.Color(0xFF0F172A);
      borderColor = Colors.teal.shade600;
    } else {
      bgColor = Colors.purple.shade900.withValues(alpha: 0.85);
      borderColor = Colors.purpleAccent.shade100;
    }

    String label;
    Color evalBg = Colors.grey.shade700;
    if (node.isRoot) {
      label = '🏁';
    } else {
      label = '${node.moveSan ?? ""}${node.nag ?? ""}';
      if (node.eval != null) {
        final val = node.eval!;
        label += ' (${_formatEval(val)})';
        if (val.abs() > 500) {
          evalBg = val > 0 ? Colors.amber.shade800 : Colors.red.shade900;
        } else if (val > 0.3) {
          evalBg = Colors.green.shade800;
        } else if (val < -0.3) {
          evalBg = Colors.red.shade800;
        }
      }
    }

    return Positioned(
      left: pn.x,
      top: pn.y,
      width: pn.width,
      height: pn.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                _focusNode.requestFocus();
                _stopPlay();
                widget.onSelectNode(node);
                widget.onNodeTapped?.call();
              },
              onLongPress: node.isRoot
                  ? null
                  : () =>
                      _showNodeContextMenu(context, node, transpositionGroup),
              onSecondaryTap: node.isRoot
                  ? null
                  : () =>
                      _showNodeContextMenu(context, node, transpositionGroup),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: borderColor, width: isSelected ? 2.0 : 1.2),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                              color: Colors.tealAccent.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 1)
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                    if (!node.isRoot && node.eval != null) ...[
                      const SizedBox(width: 3),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: evalBg, shape: BoxShape.circle),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (isTransposition)
            Positioned(
              right: -4,
              top: -4,
              child: Tooltip(
                message:
                    'Ova pozicija je dostignuta i drugim redosledom poteza',
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                      color: Colors.amber, shape: BoxShape.circle),
                  child: const Icon(Icons.call_split,
                      size: 9, color: Colors.black),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showNodeContextMenu(BuildContext context, AnalysisNode node,
      [List<AnalysisNode>? transpositionGroup]) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final others = (transpositionGroup ?? const [])
            .where((n) => n.id != node.id)
            .toList();
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.star, color: ctx.colors.warning),
                title: Text('Unapredi u Glavnu Liniju (Main Line)',
                    style: TextStyle(color: ctx.colors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  if (node.parent != null) {
                    widget.onPromoteNode?.call(node);
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: ctx.colors.danger),
                title: Text('Obriši Ovu Varijantu',
                    style: TextStyle(color: ctx.colors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onDeleteNode?.call(node);
                },
              ),
              if (others.isNotEmpty) ...[
                Divider(color: ctx.colors.border, height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ista pozicija dostignuta i preko:',
                      style: AppText.captionBold.copyWith(color: ctx.colors.textMuted),
                    ),
                  ),
                ),
                for (final other in others)
                  ListTile(
                    leading:
                        Icon(Icons.call_split, color: ctx.colors.warning),
                    title: Text(_movePathLabel(other),
                        style:
                            AppText.bodyLarge.copyWith(color: ctx.colors.textPrimary)),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onSelectNode(other);
                    },
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

enum _PlaySpeed {
  slow(Duration(milliseconds: 1800), 'Sporo'),
  normal(Duration(milliseconds: 900), 'Normalno'),
  fast(Duration(milliseconds: 400), 'Brzo');

  final Duration interval;
  final String label;
  const _PlaySpeed(this.interval, this.label);
}

class _PositionedNode {
  final AnalysisNode node;
  final double x;
  final double y;
  final double width;
  final double height;
  final _PositionedNode? parent;

  _PositionedNode({
    required this.node,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.parent,
  });
}

class _TreeEdgesPainter extends CustomPainter {
  final List<_PositionedNode> positionedNodes;
  final String activeNodeId;
  final bool isHorizontal;

  _TreeEdgesPainter(
      {required this.positionedNodes,
      required this.activeNodeId,
      required this.isHorizontal});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const ui.Color(0xFF334155)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    final activePaint = Paint()
      ..color = Colors.tealAccent
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    for (final pn in positionedNodes) {
      final parent = pn.parent;
      if (parent == null) continue;

      final isActiveEdge = pn.node.id == activeNodeId;
      final path = Path();

      if (isHorizontal) {
        final parentX = parent.x + parent.width;
        final parentY = parent.y + parent.height / 2;
        final childX = pn.x;
        final childY = pn.y + pn.height / 2;
        path.moveTo(parentX, parentY);
        final midX = (parentX + childX) / 2;
        path.cubicTo(midX, parentY, midX, childY, childX, childY);
      } else {
        final parentX = parent.x + parent.width / 2;
        final parentY = parent.y + parent.height;
        final childX = pn.x + pn.width / 2;
        final childY = pn.y;
        path.moveTo(parentX, parentY);
        final midY = (parentY + childY) / 2;
        path.cubicTo(parentX, midY, childX, midY, childX, childY);
      }

      canvas.drawPath(path, isActiveEdge ? activePaint : linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TreeEdgesPainter oldDelegate) {
    return oldDelegate.activeNodeId != activeNodeId ||
        oldDelegate.positionedNodes != positionedNodes ||
        oldDelegate.isHorizontal != isHorizontal;
  }
}
