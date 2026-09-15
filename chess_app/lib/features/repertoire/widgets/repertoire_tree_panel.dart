import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/features/analysis_studio/widgets/visual_move_tree_widget.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// Which of the three a card is, out of what the server said about it.
///
/// The state the tree answers with is about the position a move *leads to*, so
/// it reads differently on the two kinds of card: on the student's own move it
/// describes the board the opponent then faces, and on the opponent's it
/// describes the board the student faces — which is where a hole is a hole.
MoveTreeNodeLook lookOfRepertoireMove(RepertoireTreeMove move) {
  if (move.mine) return MoveTreeNodeLook.authored;
  if (move.state == 'open') return MoveTreeNodeLook.gap;
  return MoveTreeNodeLook.covered;
}

/// The repertoire as the analysis board's own tree widget wants it.
///
/// One node per ply, parents linked, the student's primary first in each list
/// so the widget's "main line" rule lands on the move they settled on rather
/// than on whichever move happened to be stored first.
///
/// [looks], when given, is filled with one entry per drawn card, keyed by the
/// node's id — the drawing's own key, so a position reached two ways keeps one
/// look per card rather than one per position.
AnalysisNode repertoireTreeToNodes(
  RepertoireTree tree, {
  Map<String, MoveTreeNodeLook>? looks,
}) {
  final root = AnalysisNode(fen: tree.rootFen);
  void add(AnalysisNode parent, RepertoireTreeMove move) {
    final node = parent.addChild(
      childFen: move.fen,
      san: move.san,
      uci: move.uci,
    );
    node.nag = markOfRepertoireMove(move);
    looks?[node.id] = lookOfRepertoireMove(move);
    // No engine number on the card. The drawing's job is to show the holes,
    // and an opinion about a move the reader already decided is not one.
    for (final child in move.children) {
      add(node, child);
    }
  }

  for (final child in tree.children) {
    add(root, child);
  }
  return root;
}

/// How often the opponent plays a reply, in the words the card uses.
///
/// Null when there is no number to say — a move the book does not know — which
/// is how every caller drops it out of the sentence rather than writing „0%".
/// Exposed because the walkthrough screen says the same number in prose, and a
/// second rounding rule beside this one is how two places that mean the same
/// thing start disagreeing.
String? shareLabel(double share) {
  final percent = share * 100;
  if (percent <= 0) return null;
  return percent < 1 ? '<1%' : '${percent.round()}%';
}

/// What a card says beside the move, in characters rather than in colour.
///
/// `★` the student's main move, a percentage for how often the book says the
/// opponent plays theirs, and `?` for a position where the student has not
/// chosen a move yet. Without these the picture is a decoration; with them the
/// holes are the first thing anybody sees.
String? markOfRepertoireMove(RepertoireTreeMove move) {
  if (move.mine) return move.isPrimary ? ' ★' : null;
  final parts = <String>[];
  final share = shareLabel(move.share);
  if (share != null) parts.add(share);
  if (move.state == 'open') parts.add('?');
  return parts.isEmpty ? null : ' ${parts.join(" ")}';
}

/// The node standing at a position, or null.
///
/// First match wins where a position is reachable two ways, which is the same
/// rule the walk itself keeps: a transposition is one position, and the line
/// that reached it first is the one it is filed under.
///
/// Compared by `fenKeyOf`, like every other position comparison here. The
/// tree's FENs come from the server; the position the board is standing on is
/// computed locally after a move. The two agree about the position and may
/// disagree about the halfmove clock and the move number, which are arithmetic
/// and not position.
///
/// The en-passant square stays inside the key: two positions differing only in
/// it are different positions, and in one of them a capture is legal.
AnalysisNode? findNodeByFen(AnalysisNode root, String fen) {
  final key = fenKeyOf(fen);
  AnalysisNode? search(AnalysisNode node) {
    if (fenKeyOf(node.fen) == key) return node;
    for (final child in node.children) {
      final found = search(child);
      if (found != null) return found;
    }
    return null;
  }

  return search(root);
}

/// The repertoire drawn, beside the board rather than instead of it.
///
/// Deliberately not a new drawing: [AnalysisMoveTreeWidget] already pans,
/// zooms, toggles between PGN and the graph, marks transpositions, and opens
/// fullscreen with a tap that closes it again. A second tree written here would
/// be a second place for all of that to be got wrong.
class RepertoireTreePanel extends StatelessWidget {
  const RepertoireTreePanel({
    super.key,
    required this.root,
    required this.active,
    required this.onSelect,
    this.onPromote,
    this.onDelete,
    this.truncatedAt,
    this.narrowed = false,
    this.onNarrow,
    this.onWiden,
    this.deleteLabel,
    this.extraLabel,
    this.onExtra,
    this.nodeLook,
  });

  final AnalysisNode root;
  final AnalysisNode active;

  /// The node that was tapped. The whole node rather than its position: the
  /// caller needs the parent chain to know where in the line it sits, and
  /// whose move it is.
  final void Function(AnalysisNode node) onSelect;

  /// The two edits in the card's own context menu — long press, or right
  /// click. A menu item bound to nothing is a menu that does nothing, so the
  /// widget draws only what it was given.
  final void Function(AnalysisNode node)? onPromote;
  final void Function(AnalysisNode node)? onDelete;

  /// Set when the drawing was cut short at a depth, so the panel can say so
  /// instead of looking like the whole repertoire.
  final int? truncatedAt;

  /// The drawing is showing one branch rather than the whole repertoire.
  ///
  /// It is the repertoire's own gate doing it — the same `rootFen` + `gateUci`
  /// pair „Vežbaj X" runs on — asked for a different position. A second filter
  /// written beside that one is how two „only this branch" in one app start
  /// disagreeing, so there is not one.
  final bool narrowed;

  /// Narrow the drawing to the position on the board, and widen it back.
  final VoidCallback? onNarrow;
  final VoidCallback? onWiden;

  /// What the card's second menu item is called on this particular card.
  final String Function(AnalysisNode node)? deleteLabel;

  /// One more action, on the cards the screen names.
  final String? Function(AnalysisNode node)? extraLabel;
  final void Function(AnalysisNode node)? onExtra;

  /// What each card is, so the drawing says it without being read. See
  /// `lookOfRepertoireMove`.
  final MoveTreeNodeLook? Function(AnalysisNode node)? nodeLook;

  /// The sentence above the drawing that says what its marks mean. One copy,
  /// read by the tests, so the legend cannot drift from the marks.
  static const legend =
      'Beside the opponent\'s move is how often it is played in master games. '
      '★ is your main move, ? is a position where you have not chosen a move '
      'yet. Tap a move to go there, and long press (or right click) to delete '
      'it or make it your main move.';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          legend,
          style: AppText.micro.copyWith(color: context.colors.textMuted),
        ),
        if (narrowed && onWiden != null)
          TextButton.icon(
            onPressed: onWiden,
            icon: const Icon(Icons.unfold_more, size: 16),
            label: const Text('Show entire repertoire'),
          )
        else if (!narrowed && onNarrow != null)
          TextButton.icon(
            onPressed: onNarrow,
            icon: const Icon(Icons.unfold_less, size: 16),
            label: const Text('Show only from this position'),
          ),
        if (truncatedAt != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Drawing is truncated at $truncatedAt plies — repertoire goes deeper.',
            style: AppText.micro.copyWith(color: context.colors.warning),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        AnalysisMoveTreeWidget(
          nodeLook: nodeLook,
          rootNode: root,
          activeNode: active,
          onSelectNode: onSelect,
          onPromoteNode: onPromote,
          onDeleteNode: onDelete,
          deleteLabel: deleteLabel,
          extraLabel: extraLabel,
          onExtra: onExtra,
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
        node.moveSan == null ? 'root' : '${node.moveSan}${node.nag ?? ""}';
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
