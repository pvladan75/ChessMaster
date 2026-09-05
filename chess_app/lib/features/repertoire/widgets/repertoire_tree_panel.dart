import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/features/analysis_studio/widgets/visual_move_tree_widget.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// The repertoire as the analysis board's own tree widget wants it.
///
/// One node per ply, parents linked, the student's primary first in each list
/// so the widget's "main line" rule lands on the move they settled on rather
/// than on whichever move happened to be stored first.
///
/// [showCut] draws the branches the student said they are not preparing.
/// Off by default: a cut stops the walk but the card stayed, so ten cuts left
/// ten dead leaves widening a drawing that is read to find the holes. The count
/// is beside the toggle, so nothing disappears silently — a cut is a decision
/// and has to stay findable.
/// Which of the four a card is, out of what the server said about it.
///
/// The states the tree answers with are about the position a move *leads to*,
/// so they read differently on the two kinds of card: on the student's own move
/// the state describes the board the opponent then faces, and on the opponent's
/// it describes the board the student faces — which is where a hole is a hole.
///
/// `unopened` is drawn as covered on purpose. It means „decided, but the
/// replies were never taken", which is work outstanding rather than a gap in
/// the preparation; the `…` already on the label says the rest, and a fifth
/// silhouette would cost more than it tells.
MoveTreeNodeLook lookOfRepertoireMove(RepertoireTreeMove move) {
  if (move.state == 'cut') return MoveTreeNodeLook.refused;
  if (move.mine) return MoveTreeNodeLook.authored;
  if (move.state == 'open') return MoveTreeNodeLook.gap;
  return MoveTreeNodeLook.covered;
}

/// [looks], when given, is filled with one entry per drawn card, keyed by the
/// node's id — the drawing's own key, so a position reached two ways keeps one
/// look per card rather than one per position.
AnalysisNode repertoireTreeToNodes(
  RepertoireTree tree, {
  bool showCut = false,
  Map<String, MoveTreeNodeLook>? looks,
  Map<String, double>? reaches,
}) {
  final root = AnalysisNode(fen: tree.rootFen);
  void add(AnalysisNode parent, RepertoireTreeMove move, double reachSoFar) {
    if (!showCut && move.state == 'cut') return;
    final node = parent.addChild(
      childFen: move.fen,
      san: move.san,
      uci: move.uci,
    );
    node.nag = markOfRepertoireMove(move);
    looks?[node.id] = lookOfRepertoireMove(move);
    // How likely this position is to arrive at all, from the root of the
    // drawing. The opponent's replies multiply — they are frequencies — and the
    // reader's own moves do not, because which of them they play is a decision
    // and a decision has no probability.
    final reach = move.mine ? reachSoFar : reachSoFar * move.share;
    reaches?[node.id] = reach;
    // No engine number on the card. That was already true here before a node
    // stopped carrying one at all — the drawing's job is to show the holes,
    // and an opinion about a move the reader already decided is not one.
    for (final child in move.children) {
      add(node, child, reach);
    }
  }

  for (final child in tree.children) {
    add(root, child, 1);
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
/// How often the opponent plays a reply, in the words the card uses.
///
/// Null when there is no number to say, which is how both callers drop it out
/// of the sentence rather than writing „0%". Exposed because the walkthrough
/// screen says the same number in prose and a second rounding rule beside this
/// one is how two places that mean the same thing start disagreeing.
String? shareLabel(double share) {
  final percent = share * 100;
  if (percent <= 0) return null;
  return percent < 1 ? '<1%' : '${percent.round()}%';
}

/// „Šansa linije" for one card, as the reader is told it.
///
/// **The clause is not decoration and must not be trimmed to fit.** The number
/// is conditional: it is the chance of arriving *while the opponent stays
/// inside what this repertoire prepares*, so a narrow breadth makes it read
/// high — at „samo glavna linija" the product runs over one reply a position
/// and can say 100% about a line the opponent leaves at move two. A percentage
/// without that sentence beside it is a number that lies quietly, which is the
/// failure this codebase keeps paying for.
///
/// Null where there is nothing to say, so a card with no number carries no
/// tooltip rather than an empty one.
String? reachSentence(double? reach) {
  if (reach == null) return null;
  final said = shareLabel(reach);
  if (said == null) return null;
  return 'Šansa linije: $said (u okviru pokrivenog repertoara)';
}

String? markOfRepertoireMove(RepertoireTreeMove move) {
  if (move.mine) return move.isPrimary ? ' ★' : null;
  final parts = <String>[];
  final share = shareLabel(move.share);
  if (share != null) parts.add(share);
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

/// How many moves in the drawing lead into a branch that was cut.
///
/// Counted over the whole tree rather than taken from the drawing, so the
/// number is right whether or not those cards are being drawn.
int countCutMoves(RepertoireTree tree) {
  var cut = 0;
  void walk(RepertoireTreeMove move) {
    if (move.state == 'cut') cut += 1;
    for (final child in move.children) {
      walk(child);
    }
  }

  for (final child in tree.children) {
    walk(child);
  }
  return cut;
}

/// The node standing at a position, or null.
///
/// First match wins where a position is reachable two ways, which is the same
/// rule the walk itself keeps: a transposition is one position, and the line
/// that reached it first is the one it is filed under.
/// Compared by `fenKeyOf`, like every other position comparison here.
///
/// The tree's FENs come from the server; the position the board is standing on
/// is computed locally by the chess engine after a move. The two agree about
/// the position and may disagree about the halfmove clock and the move number,
/// which are arithmetic and not position. Compared whole, this returned null
/// and the caller fell back to the root — the picture then highlighted the
/// opening instead of where the reader was, and said nothing about it.
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
///
/// It was a separate screen for one day, which is one day of it being useless:
/// seeing what you were building meant leaving the board and coming back.
class RepertoireTreePanel extends StatelessWidget {
  const RepertoireTreePanel({
    super.key,
    required this.root,
    required this.active,
    required this.onSelect,
    this.onPromote,
    this.onDelete,
    this.truncatedAt,
    this.cutHidden = 0,
    this.showCut = false,
    this.onToggleCut,
    this.narrowed = false,
    this.onNarrow,
    this.onWiden,
    this.minRating,
    this.breadth,
    this.deleteLabel,
    this.extraLabel,
    this.onExtra,
    this.nodeLook,
    this.nodeTooltip,
  });

  final AnalysisNode root;
  final AnalysisNode active;

  /// The node that was tapped. The whole node rather than its position: the
  /// caller needs the parent chain to know where in the line it sits, and
  /// whose move it is.
  final void Function(AnalysisNode node) onSelect;

  /// The two edits in the card's own context menu — long press, or right
  /// click. The widget draws them whatever happens; passing nothing is how the
  /// repertoire spent a day offering "Unapredi u glavnu liniju" and "Obriši ovu
  /// varijantu" bound to a `?.call` that went nowhere, which is exactly what it
  /// looked like from the outside: a menu that does nothing.
  final void Function(AnalysisNode node)? onPromote;
  final void Function(AnalysisNode node)? onDelete;

  /// Set when the drawing was cut short at a depth, so the panel can say so
  /// instead of looking like the whole repertoire.
  final int? truncatedAt;

  /// How many cut branches there are, and whether they are being drawn. A cut
  /// is a decision, so it is never silently gone: the number is on screen with
  /// the switch that brings them back.
  final int cutHidden;
  final bool showCut;
  final VoidCallback? onToggleCut;

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

  /// The two settings this drawing is made of: which games the book answers
  /// from, and how much of their answer is taken.
  ///
  /// Said on the picture rather than left in a popup, because the picture
  /// changes shape when either one changes and nothing on screen used to say
  /// which one it was drawn at. A repertoire set to „Samo glavna linija" and a
  /// repertoire read at a band it was never fetched in look the same from
  /// here: thin, for reasons the reader cannot see.
  final int? minRating;
  final String? breadth;

  /// What the card's second menu item is called on this particular card.
  final String Function(AnalysisNode node)? deleteLabel;

  /// One more action, on the cards the screen names.
  final String? Function(AnalysisNode node)? extraLabel;
  final void Function(AnalysisNode node)? onExtra;

  /// What each card is, so the drawing says it without being read. See
  /// `lookOfRepertoireMove`.
  final MoveTreeNodeLook? Function(AnalysisNode node)? nodeLook;

  /// A sentence for one card. See `VisualMoveTreeWidget.nodeTooltip`.
  final String? Function(AnalysisNode node)? nodeTooltip;

  static const _widthNames = {
    'main': 'samo glavni odgovor',
    'standard': 'uobičajeno 80%',
    'broad': 'široko 95%',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Uz protivnikov potez stoji koliko se često igra. ★ je vaš glavni '
          'potez, ? pozicija bez vaše odluke, … odluka bez uzetih odgovora, '
          '✂ grana koju ne spremam. Zadržite pokazivač nad kartom da vidite '
          'šansu linije. Dodirnite potez da tabla ode tamo, a '
          'dugim pritiskom (ili desnim klikom) otvorite izmene.',
          style: AppText.micro.copyWith(color: context.colors.textMuted),
        ),
        if (minRating != null || breadth != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          // `Wrap`, because these are two sentences on a phone and one on a
          // desktop, and a release build clips rather than warns.
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            children: [
              if (minRating != null)
                Text('Knjiga: partije od $minRating+',
                    style: AppText.micro
                        .copyWith(color: context.colors.textSecondary)),
              if (breadth != null)
                Text('Koliko odgovora: ${_widthNames[breadth] ?? breadth}',
                    style: AppText.micro
                        .copyWith(color: context.colors.textSecondary)),
            ],
          ),
        ],
        if (cutHidden > 0 && onToggleCut != null)
          TextButton.icon(
            onPressed: onToggleCut,
            icon: Icon(showCut ? Icons.visibility_off : Icons.content_cut,
                size: 16),
            label: Text(showCut
                ? 'Sakrij grane koje ne spremam ($cutHidden)'
                : 'Prikaži grane koje ne spremam ($cutHidden)'),
          ),
        if (narrowed && onWiden != null)
          TextButton.icon(
            onPressed: onWiden,
            icon: const Icon(Icons.unfold_more, size: 16),
            label: const Text('Prikaži ceo repertoar'),
          )
        else if (!narrowed && onNarrow != null)
          TextButton.icon(
            onPressed: onNarrow,
            icon: const Icon(Icons.unfold_less, size: 16),
            label: const Text('Prikaži samo od ove pozicije'),
          ),
        if (truncatedAt != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Crtež je skraćen na $truncatedAt polupoteza — repertoar ide dublje.',
            style: AppText.micro.copyWith(color: context.colors.warning),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        AnalysisMoveTreeWidget(
          nodeLook: nodeLook,
          nodeTooltip: nodeTooltip,
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
