import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/widgets/visual_move_tree_widget.dart';
import 'package:chess_app/features/repertoire/line_text.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// The repertoire drawn, in the same tree the Analysis board uses.
///
/// Deliberately not a new drawing. [VisualMoveTreeWidget] already pans, zooms,
/// lays out top-down or left-to-right, marks transpositions and reads the same
/// on a phone and on a desktop; a second tree written here would be a second
/// place for all of that to be got wrong. It takes an [AnalysisNode] tree, so
/// the only work is turning the repertoire into one.
///
/// **What each card says, it says in text.** The opponent's moves carry how
/// often they are played and one mark for the state of the position after
/// them — `?` nothing chosen yet, `…` chosen but the answers were never taken,
/// `✂` cut on purpose. The student's own main move carries a star. Nothing
/// here depends on telling two colours apart.
///
/// The picture has a **depth**, and it is a real limit rather than a detail: a
/// repertoire seeded from an archive runs to thousands of moves, and a drawing
/// of all of them is not a drawing anybody reads.
class RepertoireTreeScreen extends StatefulWidget {
  const RepertoireTreeScreen({
    super.key,
    required this.name,
    required this.color,
    required this.rootFen,
    this.rootPath = const [],
    this.minRating,
    this.api,
    this.onBuildAt,
    this.onDrillAt,
  });

  final String name;

  /// 'w' or 'b' — the side this repertoire is for. It is also how the screen
  /// tells whose move a position is: a card can be built or drilled from only
  /// when the student is the one to move there.
  final String color;

  final String rootFen;
  final List<String> rootPath;
  final int? minRating;
  final RepertoireApiService? api;

  final void Function(String fen)? onBuildAt;
  final void Function(String fen)? onDrillAt;

  @override
  State<RepertoireTreeScreen> createState() => _RepertoireTreeScreenState();
}

class _RepertoireTreeScreenState extends State<RepertoireTreeScreen> {
  late final RepertoireApiService _api = widget.api ?? RepertoireApiService();

  RepertoireTree? _tree;
  AnalysisNode? _root;
  AnalysisNode? _selected;
  bool _loading = true;

  /// True when the server did not answer. Told apart from an empty repertoire,
  /// the way every other screen here tells them apart.
  bool _failed = false;

  int _depth = 16;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tree = await _api.repertoireTree(
      color: widget.color,
      rootFen: widget.rootFen,
      rootPath: widget.rootPath,
      minRating: widget.minRating,
      maxPly: _depth,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _tree = tree;
      _failed = tree == null;
      _root = tree == null ? null : _convert(tree);
      _selected = _root;
    });
  }

  /// The repertoire as the tree widget wants it.
  ///
  /// One node per move, parents linked, the student's primary first in each
  /// list so the widget's own "main line" rule lands on the move they settled
  /// on rather than on whichever move was stored first.
  AnalysisNode _convert(RepertoireTree tree) {
    final root = AnalysisNode(fen: tree.rootFen);
    void add(AnalysisNode parent, RepertoireTreeMove move) {
      final node = parent.addChild(
        childFen: move.fen,
        san: move.san,
        uci: move.uci,
      );
      node.nag = _markOf(move);
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
  String? _markOf(RepertoireTreeMove move) {
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

  /// The moves from the repertoire's root down to a node.
  List<String> _pathTo(AnalysisNode node) {
    final moves = <String>[];
    AnalysisNode? at = node;
    while (at != null && at.moveSan != null) {
      moves.insert(0, at.moveSan!);
      at = at.parent;
    }
    return moves;
  }

  /// Whether the student is the one to move in a position — the only kind of
  /// card that can be built or drilled from, because both of those screens ask
  /// "what do you play here".
  bool _isMine(String fen) {
    final parts = fen.trim().split(RegExp(r'\s+'));
    return parts.length >= 2 && parts[1] == widget.color;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: Text('Stablo — ${widget.name}'),
        elevation: 0,
        actions: [
          PopupMenuButton<int>(
            tooltip: 'Dubina crteža',
            icon: const Icon(Icons.unfold_more),
            onSelected: (value) {
              setState(() => _depth = value);
              _load();
            },
            itemBuilder: (context) => [
              for (final option in const [8, 16, 24, 40])
                PopupMenuItem(
                  value: option,
                  child: Text(option == _depth
                      ? 'do $option poluporeza ✓'
                      : 'do $option poluporeza'),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Osveži',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return _buildMessage(
        context,
        icon: Icons.cloud_off,
        title: 'Stablo nije moglo da se pročita.',
        detail: 'Server nije odgovorio, pa se ne zna šta je u repertoaru. To '
            'nije isto što i prazan repertoar — proverite da li backend radi.',
      );
    }

    final tree = _tree!;
    final root = _root!;
    if (tree.isEmpty) {
      return _buildMessage(
        context,
        icon: Icons.account_tree_outlined,
        title: 'U repertoaru još nema nijednog poteza.',
        detail: 'Stablo se crta od vaših odluka — izgradite prvi potez pa se '
            'vratite.',
        action: widget.onBuildAt == null
            ? null
            : FilledButton.icon(
                onPressed: () => widget.onBuildAt!(widget.rootFen),
                icon: const Icon(Icons.playlist_add, size: 18),
                label: const Text('Gradi'),
              ),
      );
    }

    return Column(
      children: [
        _buildLegend(context, tree),
        Expanded(
          child: VisualMoveTreeWidget(
            rootNode: root,
            activeNode: _selected ?? root,
            onSelectNode: (node) => setState(() => _selected = node),
          ),
        ),
        _buildSelection(context),
      ],
    );
  }

  Widget _buildLegend(BuildContext context, RepertoireTree tree) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Uz protivnikov potez stoji koliko se često igra. ★ je vaš glavni '
            'potez, ? pozicija bez vaše odluke, … odluka bez uzetih odgovora, '
            '✂ odsečena grana.',
            style: AppText.micro.copyWith(color: context.colors.textMuted),
          ),
          if (tree.truncated) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Crtež je skraćen na ${tree.maxPly} poluporeza — repertoar ide '
              'dublje. Dubina se menja gore desno.',
              style: AppText.micro.copyWith(color: context.colors.warning),
            ),
          ],
        ],
      ),
    );
  }

  /// What was tapped, and the two things that can be done from there.
  Widget _buildSelection(BuildContext context) {
    final node = _selected;
    if (node == null) return const SizedBox.shrink();
    final line = numberedLine(
      [...widget.rootPath, ..._pathTo(node)],
      from: widget.rootPath.isEmpty ? widget.rootFen : null,
    );
    // Only a position where the student is to move. From anywhere else both
    // doors lead to a screen that would ask them what the opponent plays.
    final mine = _isMine(node.fen);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.5),
        border: Border(top: BorderSide(color: context.colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            line.isEmpty ? 'Koren repertoara' : line,
            style: AppText.caption.copyWith(color: context.colors.accent),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (!mine)
            Text(
              'Ovde je protivnik na potezu — izaberite njegov potez da biste '
              'radili sa pozicijom posle njega.',
              style: AppText.micro.copyWith(color: context.colors.textMuted),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.onBuildAt != null)
                  OutlinedButton.icon(
                    onPressed: () => widget.onBuildAt!(node.fen),
                    icon: const Icon(Icons.playlist_add, size: 18),
                    label: const Text('Gradi odavde'),
                  ),
                if (widget.onDrillAt != null)
                  OutlinedButton.icon(
                    onPressed: () => widget.onDrillAt!(node.fen),
                    icon: const Icon(Icons.fitness_center, size: 18),
                    label: const Text('Vežbaj ovu granu'),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMessage(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String detail,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppText.bodyBold, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(detail,
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted),
                textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
