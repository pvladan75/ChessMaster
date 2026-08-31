import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// The repertoire as the analysis board's own tree widget wants it.
///
/// One node per ply, parents linked, the student's primary first in each list
/// so the widget's "main line" rule lands on the move they settled on rather
/// than on whichever move happened to be stored first.
AnalysisNode repertoireTreeToNodes(RepertoireTree tree) {
  final root = AnalysisNode(fen: tree.rootFen);
  void add(AnalysisNode parent, RepertoireTreeMove move) {
    final node = parent.addChild(
      childFen: move.fen,
      san: move.san,
      uci: move.uci,
    );
    node.nag = markOfRepertoireMove(move);
    for (final child in move.children) {
      add(node, child);
    }
  }

  for (final child in tree.children) {
    add(root, child);
  }
  return root;
}

/// What a card says beside the move, in characters rather than in colour.
///
/// `★` the student's main move, a percentage for how often the opponent plays
/// theirs, and one mark for the state of the position after it: `?` nothing
/// decided, `…` decided but the replies were never taken, `✂` cut on purpose.
/// Without these the picture is a decoration; with them the holes are the first
/// thing anybody sees.
String? markOfRepertoireMove(RepertoireTreeMove move) {
  if (move.mine) return move.isPrimary ? ' ★' : null;
  final parts = <String>[];
  final percent = move.share * 100;
  if (percent > 0) parts.add(percent < 1 ? '<1%' : '${percent.round()}%');
  switch (move.state) {
    case 'open':
      parts.add('?');
      break;
    case 'unopened':
      parts.add('…');
      break;
    case 'cut':
      parts.add('✂');
      break;
  }
  return parts.isEmpty ? null : ' ${parts.join(" ")}';
}

/// The node standing at a position, or null.
///
/// First match wins where a position is reachable two ways, which is the same
/// rule the walk itself keeps: a transposition is one position, and the line
/// that reached it first is the one it is filed under.
AnalysisNode? findNodeByFen(AnalysisNode root, String fen) {
  if (root.fen == fen) return root;
  for (final child in root.children) {
    final found = findNodeByFen(child, fen);
    if (found != null) return found;
  }
  return null;
}

/// The repertoire drawn, beside the board rather than instead of it.
///
/// Deliberately not a new drawing: [AnalysisMoveTreeWidget] already pans,
/// zooms, toggles between PGN and the graph, marks transpositions, and opens
/// fullscreen with a tap that closes it again. A second tree written here would
/// be a second place for all of that to be got wrong.
///
/// It was a separate screen for one day, which is one day of it being useless:
/// seeing what you were building meant leaving the board and coming back.
class RepertoireTreePanel extends StatelessWidget {
  const RepertoireTreePanel({
    super.key,
    required this.root,
    required this.active,
    required this.onSelect,
    this.truncatedAt,
  });

  final AnalysisNode root;
  final AnalysisNode active;

  /// The node that was tapped. The whole node rather than its position: the
  /// caller needs the parent chain to know where in the line it sits, and
  /// whose move it is.
  final void Function(AnalysisNode node) onSelect;

  /// Set when the drawing was cut short at a depth, so the panel can say so
  /// instead of looking like the whole repertoire.
  final int? truncatedAt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Uz protivnikov potez stoji koliko se često igra. ★ je vaš glavni '
          'potez, ? pozicija bez vaše odluke, … odluka bez uzetih odgovora, '
          '✂ odsečena grana. Dodirnite potez da tabla ode tamo.',
          style: AppText.micro.copyWith(color: context.colors.textMuted),
        ),
        if (truncatedAt != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Crtež je skraćen na $truncatedAt poluporeza — repertoar ide dublje.',
            style: AppText.micro.copyWith(color: context.colors.warning),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        AnalysisMoveTreeWidget(
          rootNode: root,
          activeNode: active,
          onSelectNode: onSelect,
        ),
      ],
    );
  }
}

/// One row: where you came from, where you are, and what comes next.
///
/// The part of the tree you actually need while answering a position, and the
/// only part that is readable at 360 dp — a pan-and-zoom canvas in a box that
/// size is not a picture. On a phone this *is* the tree; the canvas is a scroll
/// away.
class RepertoireLineStrip extends StatelessWidget {
  const RepertoireLineStrip({
    super.key,
    required this.active,
    required this.onSelect,
  });

  final AnalysisNode active;
  final void Function(AnalysisNode node) onSelect;

  @override
  Widget build(BuildContext context) {
    final parent = active.parent;
    final children = active.children;
    if (parent == null && children.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (parent != null) ...[
            _chip(context, parent, current: false),
            _arrow(context),
          ],
          _chip(context, active, current: true),
          if (children.isNotEmpty) _arrow(context),
          for (final child in children) _chip(context, child, current: false),
        ],
      ),
    );
  }

  Widget _arrow(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Center(
          child: Icon(Icons.chevron_right,
              size: 16, color: context.colors.textMuted),
        ),
      );

  Widget _chip(BuildContext context, AnalysisNode node,
      {required bool current}) {
    final label =
        node.moveSan == null ? 'koren' : '${node.moveSan}${node.nag ?? ""}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
      child: InkWell(
        onTap: current ? null : () => onSelect(node),
        borderRadius: AppRadii.roundedSm,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: current
                ? context.colors.accent.withValues(alpha: 0.22)
                : context.colors.surface.withValues(alpha: 0.5),
            borderRadius: AppRadii.roundedSm,
            border: Border.all(
              color: current ? context.colors.accent : context.colors.border,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: (current ? AppText.captionBold : AppText.caption)
                  .copyWith(color: context.colors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
