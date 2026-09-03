import 'package:flutter/material.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/widgets/visual_move_tree_widget.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

class AnalysisMoveTreeWidget extends StatefulWidget {
  final AnalysisNode rootNode;
  final AnalysisNode activeNode;
  final Function(AnalysisNode node) onSelectNode;
  final Function(AnalysisNode node)? onPromoteNode;
  final Function(AnalysisNode node)? onDeleteNode;

  /// What the second menu item is called, when the caller knows better.
  ///
  /// „Obriši ovu varijantu" is true on an analysis board, where every move is
  /// the reader's own. In a repertoire it is true for half the cards: on the
  /// opponent's move nothing is deleted — the branch is refused, reversibly —
  /// and the label went on promising a deletion that never happened, beside a
  /// button doing the same thing under its real name.
  final String Function(AnalysisNode node)? deleteLabel;

  /// One more action, offered only on the cards the caller names.
  ///
  /// Null for every card by default, so a board that has nothing extra to
  /// offer looks exactly as it did. The repertoire uses it for „Izdvoji u novo
  /// otvaranje", which belongs on the move it forks from and was reachable
  /// only from the row under the board.
  final String? Function(AnalysisNode node)? extraLabel;
  final void Function(AnalysisNode node)? onExtra;

  /// deltaCutoff the tree was last auto-generated with, if any — caps the
  /// graphical view's post-hoc display-filter slider so it can't be dragged
  /// past the point where it would stop doing anything.
  final double? maxEvalDisplayCutoff;

  const AnalysisMoveTreeWidget({
    super.key,
    required this.rootNode,
    required this.activeNode,
    required this.onSelectNode,
    this.onPromoteNode,
    this.onDeleteNode,
    this.deleteLabel,
    this.extraLabel,
    this.onExtra,
    this.maxEvalDisplayCutoff,
  });

  @override
  State<AnalysisMoveTreeWidget> createState() => _AnalysisMoveTreeWidgetState();
}

class _AnalysisMoveTreeWidgetState extends State<AnalysisMoveTreeWidget> {
  bool _showVisualGraph = true; // Default to interactive visual tree graph!

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: context.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedMd),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Flexible, and the title ellipsised: this header is a Row of
                // a title and four controls, and at 360 dp it overflowed by
                // 180 px — invisible in a release build, which paints no
                // stripes. It had never been pumped at phone width until the
                // repertoire screen put this panel under a board.
                Flexible(
                  child: Row(
                    children: [
                      Icon(Icons.account_tree,
                          color: context.colors.accent, size: 18),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Stablo Varijanti',
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodyLargeBold
                              .copyWith(color: context.colors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    // Mode selector toggle buttons
                    InkWell(
                      onTap: () => setState(() => _showVisualGraph = true),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: _showVisualGraph
                              ? context.colors.accent.withValues(alpha: 0.22)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: _showVisualGraph
                                  ? context.colors.accent
                                  : context.colors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.bar_chart,
                                size: 13, color: context.colors.accent),
                            const SizedBox(width: 3),
                            Text('Grafičko',
                                style: AppText.caption.copyWith(
                                    color: context.colors.textPrimary)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    InkWell(
                      onTap: () => setState(() => _showVisualGraph = false),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: !_showVisualGraph
                              ? context.colors.accent.withValues(alpha: 0.22)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: !_showVisualGraph
                                  ? context.colors.accent
                                  : context.colors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.notes,
                                size: 13, color: context.colors.accent),
                            const SizedBox(width: 3),
                            Text('PGN',
                                style: AppText.caption.copyWith(
                                    color: context.colors.textPrimary)),
                          ],
                        ),
                      ),
                    ),
                    if (_showVisualGraph) ...[
                      const SizedBox(width: AppSpacing.xs),
                      IconButton(
                        onPressed: () => _openFullscreen(context),
                        tooltip: 'Prikaži preko celog ekrana',
                        icon: Icon(Icons.open_in_full,
                            size: 16, color: context.colors.accent),
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: const EdgeInsets.all(6),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            Divider(height: 16, color: context.colors.border),
            Container(
              constraints: const BoxConstraints(maxHeight: 420),
              width: double.infinity,
              child: _showVisualGraph
                  ? VisualMoveTreeWidget(
                      rootNode: widget.rootNode,
                      activeNode: widget.activeNode,
                      onSelectNode: widget.onSelectNode,
                      onPromoteNode: widget.onPromoteNode,
                      onDeleteNode: widget.onDeleteNode,
                      deleteLabel: widget.deleteLabel,
                      extraLabel: widget.extraLabel,
                      onExtra: widget.onExtra,
                      maxDisplayCutoff: widget.maxEvalDisplayCutoff,
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _buildNotation(context),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFullscreen(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(AppSpacing.lg),
          backgroundColor: dialogContext.colors.surface,
          child: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(dialogContext).size.height * 0.85,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.account_tree,
                              color: dialogContext.colors.accent, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Stablo Varijanti',
                            style: AppText.subtitle.copyWith(
                                color: dialogContext.colors.textPrimary),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: Icon(Icons.close,
                            color: dialogContext.colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: dialogContext.colors.border),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: VisualMoveTreeWidget(
                      rootNode: widget.rootNode,
                      activeNode: widget.activeNode,
                      onSelectNode: widget.onSelectNode,
                      // A direct tap on a node closes the fullscreen dialog
                      // (the point was to jump there and see it on the main
                      // board); the auto-player's own steps must not, or
                      // playback would close the dialog after its first move.
                      onNodeTapped: () => Navigator.pop(dialogContext),
                      onPromoteNode: widget.onPromoteNode,
                      onDeleteNode: widget.onDeleteNode,
                      deleteLabel: widget.deleteLabel,
                      extraLabel: widget.extraLabel,
                      onExtra: widget.onExtra,
                      maxDisplayCutoff: widget.maxEvalDisplayCutoff,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The move number of the position a line is standing in, read off its FEN.
  ///
  /// Not counted from the root's depth: a tree that begins at move four used to
  /// number its first move as one, which is a small lie and the one the owner
  /// met while building a repertoire from a position deep in the Advance
  /// French. The counter is in the FEN, which is the only thing that knows.
  int _numberAt(String fen) {
    final parts = fen.split(' ');
    if (parts.length < 6) return 1;
    return int.tryParse(parts[5]) ?? 1;
  }

  /// The notation, laid out the way a notation pane lays it out: the main line
  /// as running text, and every variation on its own indented line under the
  /// move it branches from.
  ///
  /// What was here before was one flat `Wrap` of boxed chips — every move a
  /// little card, variations inline among them, and each variation printed
  /// **one move deep** and then abandoned. So a branch appeared as `(Be7 11%)`
  /// floating between two main-line moves, with no way to see what followed it
  /// and nothing to say where the line it belonged to went. The owner's word
  /// for it was that he could not make it out, and he was right: the structure
  /// was not being drawn at all, only the moves.
  ///
  /// Three things this fixes, and they are the same thing: a variation is a
  /// **line**, so it is followed to its end; it belongs *under* the move it
  /// leaves, so the main line resumes on the line below it; and depth is shown
  /// by indentation rather than by a colour, so nesting is visible at a glance.
  List<Widget> _buildNotation(BuildContext context) =>
      _notationBlocks(context, widget.rootNode, null, 0);

  /// One block per run of moves, plus a block for every variation under it.
  ///
  /// [firstChild] enters on a move other than the main one, which is how a
  /// variation starts. Everything below it is then its own main line, so a
  /// variation of a variation comes out one indent further in without any
  /// special case.
  List<Widget> _notationBlocks(BuildContext context, AnalysisNode from,
      AnalysisNode? firstChild, int depth) {
    final blocks = <Widget>[];
    var run = <Widget>[];
    var parent = from;
    var next =
        firstChild ?? (from.children.isEmpty ? null : from.children.first);
    // Whether the next move printed opens a line, which is the only case where
    // Black's move carries its number — `12...Bh5` at the head of a variation,
    // and a bare `Bh5` in the middle of one.
    var opensLine = true;

    while (next != null) {
      run.add(_notationMove(context, parent, next, depth, opensLine));
      opensLine = false;

      final onMainLine = identical(next, parent.children.first);
      if (onMainLine && parent.children.length > 1) {
        // The run so far ends here: the variations belong under the move that
        // was just printed, and the main line picks up beneath them.
        blocks.add(_notationLine(context, run, depth));
        run = <Widget>[];
        for (final variation in parent.children.skip(1)) {
          blocks.addAll(_notationBlocks(context, parent, variation, depth + 1));
        }
        opensLine = true;
      }

      parent = next;
      next = parent.children.isEmpty ? null : parent.children.first;
    }

    if (run.isNotEmpty) blocks.add(_notationLine(context, run, depth));
    return blocks;
  }

  /// One line of the notation, indented by how deep the variation is.
  ///
  /// The rule the eye reads: the further in, the deeper. A rule kept by an edge
  /// and a margin rather than by a colour, so it survives a reader who does not
  /// separate hues — and so nesting past two levels stays legible, which colour
  /// alone cannot do at any depth.
  Widget _notationLine(BuildContext context, List<Widget> moves, int depth) {
    final line = Wrap(
      spacing: 1,
      runSpacing: 1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: moves,
    );
    if (depth == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: line,
      );
    }
    return Padding(
      padding: EdgeInsets.only(left: 10.0 * depth, top: 1, bottom: 1),
      child: Container(
        padding: const EdgeInsets.only(left: 6),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: context.colors.accentAlt.withValues(alpha: 0.55),
              width: 2,
            ),
          ),
        ),
        child: line,
      ),
    );
  }

  /// One move, as text rather than as a card.
  ///
  /// Only the move the board is standing on wears a background; everything else
  /// is plain, because a page where every move is a box is a page with no
  /// shape. Tap moves the board, a long press (or a right click) opens the same
  /// context menu the graphical tree has.
  Widget _notationMove(BuildContext context, AnalysisNode parent,
      AnalysisNode node, int depth, bool opensLine) {
    final isSelected = node.id == widget.activeNode.id;
    final isWhiteMove = parent.fen.contains(' w ');
    final number = _numberAt(parent.fen);
    final numberText = isWhiteMove
        ? '$number. '
        : opensLine
            ? '$number... '
            : '';

    final base = depth == 0 ? AppText.body : AppText.caption;
    final color = isSelected
        ? context.colors.accent
        : depth == 0
            ? context.colors.textPrimary
            : context.colors.textSecondary;

    return InkWell(
      onTap: () => widget.onSelectNode(node),
      onLongPress: () => _showNodeContextMenu(context, node),
      onSecondaryTap: () => _showNodeContextMenu(context, node),
      borderRadius: AppRadii.roundedXs,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: isSelected
            ? BoxDecoration(
                color: context.colors.accent.withValues(alpha: 0.22),
                borderRadius: AppRadii.roundedXs,
              )
            : null,
        child: RichText(
          text: TextSpan(
            style: base.copyWith(color: color),
            children: [
              if (numberText.isNotEmpty)
                TextSpan(
                  text: numberText,
                  style: base.copyWith(color: context.colors.textMuted),
                ),
              TextSpan(
                text: node.moveSan ?? '',
                style: base.copyWith(
                  color: color,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
              if (node.nag != null)
                TextSpan(
                  text: node.nag!,
                  style: base.copyWith(
                      color: context.colors.warning,
                      fontWeight: FontWeight.bold),
                ),
              if (node.comment.isNotEmpty)
                TextSpan(
                  text: ' {${node.comment}}',
                  style: AppText.micro.copyWith(
                      color: context.colors.info, fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNodeContextMenu(BuildContext context, AnalysisNode node) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
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
                title: Text(
                    widget.deleteLabel?.call(node) ?? 'Obriši Ovu Varijantu',
                    style: TextStyle(color: ctx.colors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onDeleteNode?.call(node);
                },
              ),
              if (widget.extraLabel?.call(node) != null)
                ListTile(
                  leading: Icon(Icons.call_split, color: ctx.colors.accent),
                  title: Text(widget.extraLabel!.call(node)!,
                      style: TextStyle(color: ctx.colors.textPrimary)),
                  onTap: () {
                    Navigator.pop(ctx);
                    widget.onExtra?.call(node);
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
