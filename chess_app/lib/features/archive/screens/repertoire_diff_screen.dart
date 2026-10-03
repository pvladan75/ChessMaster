import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/features/archive/models/repertoire_diff.dart';
import 'package:chess_app/features/archive/screens/position_games_screen.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

class RepertoireDiffScreen extends StatefulWidget {
  final String subject;
  final String? color;

  const RepertoireDiffScreen({super.key, required this.subject, this.color});

  @override
  State<RepertoireDiffScreen> createState() => _RepertoireDiffScreenState();
}

class _RepertoireDiffScreenState extends State<RepertoireDiffScreen> {
  final ArchiveApiService _api = ArchiveApiService.instance;

  RepertoireDiff? _diff;
  bool _loading = true;
  String _selectedColor = 'white';

  /// The deviation whose position is drawn — by its `fenKey`, so a reload
  /// that no longer holds it falls back instead of pointing at a stranger.
  /// On a window null means the first one; on a phone, none.
  String? _chosenKey;

  /// The window's width from which the position stands beside the list
  /// (pattern B of docs/PLAN-EKRANI.md), the shelf's own split.
  static const double _paneFrom = 840;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.color ?? 'white';
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final diff = await _api.getRepertoireDiff(
          username: widget.subject, color: _selectedColor);
      if (!mounted) return;
      setState(() {
        _diff = diff;
        _chosenKey = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppFeedback.error(context, 'Error loading repertoire: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: Text('Repertoire: ${widget.subject}'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  RepertoireDiffPosition? _chosen(
      List<RepertoireDiffPosition> positions, bool wide) {
    for (final p in positions) {
      if (p.fenKey == _chosenKey) return p;
    }
    // A window opens on the first deviation; a phone shows none until asked.
    return wide && positions.isNotEmpty ? positions.first : null;
  }

  /// On a phone a second tap on the open row closes it; on a window a row
  /// stays chosen — there is always a position beside the list.
  void _choose(RepertoireDiffPosition p, {required bool toggle}) {
    setState(
        () => _chosenKey = toggle && _chosenKey == p.fenKey ? '' : p.fenKey);
  }

  void _openInAnalysis(RepertoireDiffPosition p) {
    context.push(AppRoutes.analysisPath(fen: p.fen));
  }

  void _openGames(RepertoireDiffPosition p) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PositionGamesScreen(
        subject: widget.subject,
        color: p.color == 'white' ? 'w' : 'b',
        fenKey: p.fenKey,
        fen: p.fen,
      ),
    ));
  }

  void _pickColor(String color) {
    if (_selectedColor == color) return;
    setState(() => _selectedColor = color);
    _load();
  }

  /// White / Black and the three figures on one row; it wraps on a phone.
  Widget _buildHeader() {
    final diff = _diff;
    return Container(
      width: double.infinity,
      color: context.colors.surface,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.sm,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              ChoiceChip(
                label: const Text('White'),
                selected: _selectedColor == 'white',
                onSelected: (_) => _pickColor('white'),
              ),
              ChoiceChip(
                label: const Text('Black'),
                selected: _selectedColor == 'black',
                onSelected: (_) => _pickColor('black'),
              ),
            ],
          ),
          if (diff != null && !_loading)
            Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: [
                _StatBox(
                    label: 'Repertoire games',
                    value: diff.coveredGames.toString()),
                _StatBox(
                    label: 'Repertoire followed',
                    value: diff.followedGames.toString()),
                _StatBox(
                    label: 'Repertoire abandoned',
                    value: diff.leftGames.toString()),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final diff = _diff;
    if (diff == null) {
      return Center(
        child: Text('No data.',
            style: AppText.body.copyWith(color: context.colors.textMuted)),
      );
    }
    final positions =
        diff.positions.where((p) => p.prepared.isNotEmpty).toList();

    final intro = Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Deviations from repertoire',
              style: AppText.title.copyWith(color: context.colors.textPrimary)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'The repertoire is built manually in drills — this report '
            'only compares games to what you have built. '
            'Imported games are not added to the repertoire.',
            style: AppText.caption.copyWith(color: context.colors.textMuted),
          ),
        ],
      ),
    );

    if (positions.isEmpty) {
      return ListView(children: [
        intro,
        Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text('No recorded deviations.',
                style: AppText.body.copyWith(color: context.colors.textMuted)),
          ),
        ),
      ]);
    }

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= _paneFrom;
      final chosen = _chosen(positions, wide);

      if (!wide) {
        // A phone keeps the list; a tap opens the position under its row.
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          itemCount: positions.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) return intro;
            final p = positions[i - 1];
            final open = identical(p, chosen);
            return _CompactRow(
              position: p,
              open: open,
              onTap: () => _choose(p, toggle: true),
              pane: open
                  ? _PositionPane(
                      position: p,
                      boardMax: 280,
                      onAnalysis: () => _openInAnalysis(p),
                      onGames: () => _openGames(p),
                    )
                  : null,
            );
          },
        );
      }

      final paneWidth = (box.maxWidth * 0.4).clamp(340.0, 480.0);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                intro,
                const _TableHead(),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
                    itemCount: positions.length,
                    itemBuilder: (context, i) {
                      final p = positions[i];
                      return _TableRow(
                        position: p,
                        selected: identical(p, chosen),
                        onTap: () => _choose(p, toggle: false),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: paneWidth,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  0, AppSpacing.md, AppSpacing.md, AppSpacing.md),
              child: chosen == null
                  ? const SizedBox.shrink()
                  : Card(
                      margin: EdgeInsets.zero,
                      child: _PositionPane(
                        position: chosen,
                        boardMax: 380,
                        onAnalysis: () => _openInAnalysis(chosen),
                        onGames: () => _openGames(chosen),
                      ),
                    ),
            ),
          ),
        ],
      );
    });
  }
}

String _gamesWord(int n) => '$n ${n == 1 ? 'game' : 'games'}';

String _moveNumber(RepertoireDiffPosition p) => 'Move ${p.ply ~/ 2 + 1}';

String _preparedText(RepertoireDiffPosition p) =>
    p.prepared.isEmpty ? '-' : p.prepared.map((m) => m.san).join(', ');

String _playedText(RepertoireDiffPosition p) => p.played.isEmpty
    ? '-'
    : p.played.map((m) => '${m.san} (${m.games})').join(', ');

class _StatBox extends StatelessWidget {
  final String label;
  final String value;

  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: AppText.headline.copyWith(color: context.colors.brand)),
        Text(label,
            style: AppText.micro.copyWith(color: context.colors.textSecondary)),
      ],
    );
  }
}

/// The widths of the table's columns, shared by its head and its rows.
const double _moveColumn = 96;
const double _gamesColumn = 64;

class _TableHead extends StatelessWidget {
  const _TableHead();

  @override
  Widget build(BuildContext context) {
    final style = AppText.micro.copyWith(color: context.colors.textMuted);
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(width: _moveColumn, child: Text('Move', style: style)),
          Expanded(flex: 2, child: Text('Prepared', style: style)),
          Expanded(flex: 3, child: Text('Played instead', style: style)),
          SizedBox(
              width: _gamesColumn,
              child: Text('Games', style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

/// One deviation on a window: move, prepared, played instead, games — one
/// glance wide. The chosen row is outlined, which a colour-blind reader can
/// see, and tinted.
class _TableRow extends StatelessWidget {
  final RepertoireDiffPosition position;
  final bool selected;
  final VoidCallback onTap;

  const _TableRow(
      {required this.position, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Material(
        color: selected
            ? colors.brand.withValues(alpha: 0.14)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
              color: selected ? colors.brand : Colors.transparent, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
            child: Row(
              children: [
                SizedBox(
                  width: _moveColumn - AppSpacing.sm,
                  child: Row(
                    children: [
                      Icon(
                        position.color == 'white'
                            ? Icons.circle_outlined
                            : Icons.circle,
                        size: 14,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(_moveNumber(position), style: AppText.bodyBold),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(_preparedText(position),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(color: colors.brand)),
                ),
                Expanded(
                  flex: 3,
                  child: Text(_playedText(position),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body),
                ),
                SizedBox(
                  width: _gamesColumn - AppSpacing.sm,
                  child: Text('${position.leftGames}',
                      textAlign: TextAlign.right, style: AppText.body),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One deviation on a phone: the card it always was, tappable, with the
/// position opening under it.
class _CompactRow extends StatelessWidget {
  final RepertoireDiffPosition position;
  final bool open;
  final VoidCallback onTap;
  final Widget? pane;

  const _CompactRow({
    required this.position,
    required this.open,
    required this.onTap,
    this.pane,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: open ? colors.brand : Colors.transparent, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        position.color == 'white'
                            ? Icons.circle_outlined
                            : Icons.circle,
                        size: 16,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(_moveNumber(position), style: AppText.bodyBold),
                      const Spacer(),
                      Text(_gamesWord(position.leftGames),
                          style: AppText.caption
                              .copyWith(color: colors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Prepared',
                                style: AppText.micro
                                    .copyWith(color: colors.textMuted)),
                            Text(_preparedText(position),
                                style:
                                    AppText.body.copyWith(color: colors.brand)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Played instead',
                                style: AppText.micro
                                    .copyWith(color: colors.textMuted)),
                            Text(_playedText(position), style: AppText.body),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (pane != null) pane!,
        ],
      ),
    );
  }
}

/// The chosen deviation's position, drawn from the FEN the row already
/// carries — nothing is asked of the server — with the two doors out of it.
class _PositionPane extends StatelessWidget {
  final RepertoireDiffPosition position;
  final double boardMax;
  final VoidCallback onAnalysis;
  final VoidCallback onGames;

  const _PositionPane({
    required this.position,
    required this.boardMax,
    required this.onAnalysis,
    required this.onGames,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = TextButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    );
    final played = position.played.isEmpty
        ? '-'
        : position.played
            .map((m) => '${m.san} in ${_gamesWord(m.games)}')
            .join(', ');
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(builder: (context, box) {
            final size = box.maxWidth < boardMax ? box.maxWidth : boardMax;
            // Centred and asked for exactly its size: handed a tight width
            // wider than its height a board draws past its own box.
            return Center(
              child: BoardThumbnail(
                fen: position.fen,
                size: size,
                isWhiteBottom: position.color == 'white',
              ),
            );
          }),
          const SizedBox(height: AppSpacing.md),
          Text(_moveNumber(position), style: AppText.bodyBold),
          const SizedBox(height: 2),
          Text('Prepared: ${_preparedText(position)}',
              style: AppText.caption.copyWith(color: colors.brand)),
          Text('Played instead: $played',
              style: AppText.caption.copyWith(color: colors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              TextButton.icon(
                key: const ValueKey('diff-open-in-analysis'),
                style: style,
                onPressed: onAnalysis,
                icon: const Icon(Icons.biotech_outlined, size: 16),
                label: const Text('Open in Analysis'),
              ),
              TextButton.icon(
                key: const ValueKey('diff-position-games'),
                style: style,
                onPressed: onGames,
                icon: const Icon(Icons.format_list_bulleted, size: 16),
                label: const Text('Games through this position'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
