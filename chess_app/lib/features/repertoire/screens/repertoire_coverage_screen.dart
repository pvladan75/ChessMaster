import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/services/opening_book_service.dart';
import 'package:chess_app/features/repertoire/line_text.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// How far each of the opponent's answers has been taken — the map of the
/// repertoire rather than a place in it.
///
/// The last part of the trainer and the one that teaches least, which is why it
/// was built last: it adds no new arithmetic. Every number here comes out of
/// the walk the build screen already asks for, so opening this map costs one
/// request and no Lichess allowance at all.
///
/// **A branch is named by the opponent's choice**, not the student's — the
/// Advance, the Exchange, the Two Knights. In a repertoire the first move is
/// already decided; what splits the work is what the other side does about it.
///
/// **Three numbers, and they are never added together.** How often the branch
/// is played, how much of it is answered, and how much of it was cut. The first
/// says whether the branch matters, the second how finished it is, and the
/// third is work refused rather than work done — a bar that folded the cut part
/// into the finished part would turn "I am not preparing this" into progress.
///
/// **Nothing here is said in colour alone.** Every share is written out as a
/// percentage and every state carries an icon. That is a rule of this project
/// and a condition of acceptance rather than a nicety: a screen whose meaning
/// lives in a hue is a screen some of its readers cannot use.
class RepertoireCoverageScreen extends StatefulWidget {
  const RepertoireCoverageScreen({
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

  /// 'w' or 'b' — the side this repertoire is for.
  final String color;

  final String rootFen;
  final List<String> rootPath;
  final int? minRating;
  final RepertoireApiService? api;

  /// Opens the build screen at a branch, and the drill over that branch alone.
  /// Callbacks rather than pushes from here, the same way the drill hands a
  /// position back to be built: the screens stay strangers and whoever opened
  /// them decides what happens between them.
  final void Function(String fen)? onBuildAt;
  final void Function(String fen)? onDrillAt;

  @override
  State<RepertoireCoverageScreen> createState() =>
      _RepertoireCoverageScreenState();
}

class _RepertoireCoverageScreenState extends State<RepertoireCoverageScreen> {
  late final RepertoireApiService _api = widget.api ?? RepertoireApiService();

  RepertoireFrontier? _walk;
  bool _loading = true;

  /// True when the server did not answer. Told apart from an empty map on
  /// purpose: "we could not find out" must never be drawn as "you have built
  /// nothing", which is the same sentence the build screen refuses to say.
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Named lines, so a branch reads as "Sicilian Defense" and not only as two
    // moves. Local and offline — no token, no request, and the map still works
    // if it never loads.
    OpeningBookService.instance.ensureLoaded();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final walk = await _api.frontier(
      color: widget.color,
      rootFen: widget.rootFen,
      rootPath: widget.rootPath,
      minRating: widget.minRating,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _walk = walk;
      _failed = walk == null;
    });
  }

  /// The moves of a branch, numbered the way a book numbers them.
  String _lineOf(CoverageBranch branch) => numberedLine(
        [...widget.rootPath, ...branch.path],
        from: widget.rootPath.isEmpty ? widget.rootFen : null,
      );

  /// What this branch is called, when the book knows.
  String? _nameOf(CoverageBranch branch) =>
      OpeningBookService.instance.lookupByFen(branch.fen)?.name;

  String _percent(double share) {
    final value = share * 100;
    if (value <= 0) return '0%';
    return value < 1 ? '<1%' : '${value.round()}%';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: Text('Pokrivenost — ${widget.name}'),
        elevation: 0,
        actions: [
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
        title: 'Mapa nije mogla da se pročita.',
        detail: 'Server nije odgovorio, pa se ne zna dokle ste stigli. To nije '
            'isto što i prazan repertoar — proverite da li backend radi, pa '
            'osvežite.',
      );
    }

    final walk = _walk!;
    if (walk.branches.isEmpty) {
      return _buildMessage(
        context,
        icon: walk.rootOpen ? Icons.play_circle_outline : Icons.map_outlined,
        title: walk.rootOpen
            ? 'Prvi potez još nije izabran.'
            : 'Još nema grana na mapi.',
        detail: walk.rootOpen
            ? 'Mapa se deli po odgovorima protivnika, a njih nema dok vi ne '
                'odigrate prvi potez.'
            : 'Grane nastaju kad uzmete protivnikove odgovore na svoj potez.',
        action: widget.onBuildAt == null
            ? null
            : FilledButton.icon(
                onPressed: () => widget.onBuildAt!(widget.rootFen),
                icon: const Icon(Icons.playlist_add, size: 18),
                label: const Text('Gradi'),
              ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _buildSummary(context, walk),
        const SizedBox(height: AppSpacing.md),
        for (final branch in walk.branches) ...[
          _buildBranch(context, branch),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
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

  /// The whole repertoire in one line, above the branches it is made of.
  Widget _buildSummary(BuildContext context, RepertoireFrontier walk) {
    final open = (walk.openReach * 100).clamp(0, 100).round();
    final cut = (walk.prunedReach * 100).clamp(0, 100).round();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.5),
        borderRadius: AppRadii.roundedSm,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ceo repertoar',
              style: AppText.bodyBold.copyWith(color: context.colors.accent)),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Bez odgovora $open% partija koje kroz njega prođu'
            '${cut > 0 ? ", odsečeno $cut%" : ""}. '
            'Ide do ${walk.depthInMoves}. poteza, '
            '${walk.decided} pozicija je odlučeno.',
            style: AppText.caption.copyWith(color: context.colors.textPrimary),
          ),
          if (walk.truncated) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Pregled je skraćen — repertoar je veći od onoga što jedan '
              'prolaz stigne da izbroji.',
              style: AppText.micro.copyWith(color: context.colors.warning),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBranch(BuildContext context, CoverageBranch branch) {
    final name = _nameOf(branch);
    final ({IconData icon, String label}) state = branch.prunedWithin >= 1
        ? (icon: Icons.content_cut, label: 'odsečeno')
        : branch.isFinished
            ? (icon: Icons.check_circle_outline, label: 'spremljeno')
            : (icon: Icons.hourglass_empty, label: 'u izradi');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.5),
        borderRadius: AppRadii.roundedSm,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Shape first: which state a branch is in must be readable with
              // the colour ignored entirely.
              Icon(state.icon, size: 18, color: context.colors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_lineOf(branch),
                    style: AppText.bodyBold
                        .copyWith(color: context.colors.textPrimary)),
              ),
              Text('igra se u ${_percent(branch.share)}',
                  style:
                      AppText.micro.copyWith(color: context.colors.textMuted)),
            ],
          ),
          if (name != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(name,
                style: AppText.caption.copyWith(color: context.colors.accent)),
          ],
          const SizedBox(height: AppSpacing.xs),
          _CoverageBar(
            covered: branch.coveredWithin,
            open: branch.openWithin,
            cut: branch.prunedWithin,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'spremljeno ${_percent(branch.coveredWithin)} · '
            'bez odgovora ${_percent(branch.openWithin)}'
            '${branch.prunedWithin > 0 ? " · odsečeno ${_percent(branch.prunedWithin)}" : ""}',
            style: AppText.caption.copyWith(color: context.colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            // Depth in whole moves, because that is how anybody says it: "I am
            // prepared to move six", never "to ply twelve".
            'do ${((branch.maxPly + 1) / 2).ceil()}. poteza posle korena · '
            '${branch.decided} odlučeno · ${branch.open} otvoreno'
            '${branch.pruned > 0 ? " · ${branch.pruned} odsečeno" : ""} · '
            '${state.label}',
            style: AppText.micro.copyWith(color: context.colors.textMuted),
          ),
          if (widget.onBuildAt != null || widget.onDrillAt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            // Wrap and not Row: two Serbian labels beside a long line do not fit
            // a 360 dp phone, and a release build clips what does not fit
            // without drawing a stripe.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.onBuildAt != null)
                  OutlinedButton.icon(
                    onPressed: () => widget.onBuildAt!(branch.fen),
                    icon: const Icon(Icons.playlist_add, size: 18),
                    label: const Text('Gradi ovde'),
                  ),
                if (widget.onDrillAt != null && branch.decided > 0)
                  OutlinedButton.icon(
                    onPressed: () => widget.onDrillAt!(branch.fen),
                    icon: const Icon(Icons.fitness_center, size: 18),
                    label: const Text('Vežbaj granu'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One branch as a bar: what is answered, what is open, what was refused.
///
/// The three parts are told apart by fill *and* by their labels above, never by
/// hue alone. A cut share is drawn hollow — it is not progress, and it must not
/// look like the finished part with a different colour on it.
class _CoverageBar extends StatelessWidget {
  const _CoverageBar({
    required this.covered,
    required this.open,
    required this.cut,
  });

  final double covered;
  final double open;
  final double cut;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        Widget segment(double share, Color color, {bool hollow = false}) {
          final part = width * share.clamp(0, 1);
          if (part <= 0) return const SizedBox.shrink();
          return Container(
            width: part,
            height: 10,
            decoration: BoxDecoration(
              color: hollow ? Colors.transparent : color,
              border: hollow ? Border.all(color: color) : null,
            ),
          );
        }

        return ClipRRect(
          borderRadius: AppRadii.roundedSm,
          child: Container(
            height: 10,
            color: colors.canvas,
            child: Row(
              children: [
                segment(covered, colors.accent),
                segment(open, colors.textMuted.withValues(alpha: 0.35)),
                segment(cut, colors.textMuted, hollow: true),
              ],
            ),
          ),
        );
      },
    );
  }
}
