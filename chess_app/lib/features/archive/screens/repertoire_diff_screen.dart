import 'package:flutter/material.dart';

import 'package:chess_app/features/archive/models/repertoire_diff.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';

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
            _buildTabs(),
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

  Widget _buildTabs() {
    return Container(
      color: context.colors.surface,
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              title: 'White',
              selected: _selectedColor == 'white',
              onTap: () {
                setState(() => _selectedColor = 'white');
                _load();
              },
            ),
          ),
          Expanded(
            child: _TabButton(
              title: 'Black',
              selected: _selectedColor == 'black',
              onTap: () {
                setState(() => _selectedColor = 'black');
                _load();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_diff == null) {
      return Center(
        child: Text('No data.',
            style: AppText.body.copyWith(color: context.colors.textMuted)),
      );
    }

    final diff = _diff!;
    final mappedPositions =
        diff.positions.where((p) => p.prepared.isNotEmpty).toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: context.colors.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Repertoire overview', style: AppText.title),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.md,
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
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'The repertoire is built manually in drills — this report '
                          'only compares games to what you have built. '
                          'Imported games are not added to the repertoire.',
                          style: AppText.caption
                              .copyWith(color: context.colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Deviations from repertoire',
                    style: AppText.title
                        .copyWith(color: context.colors.textPrimary)),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
        if (mappedPositions.isEmpty)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text('No recorded deviations.',
                    style:
                        AppText.body.copyWith(color: context.colors.textMuted)),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final pos = mappedPositions[index];
                return _PositionRow(position: pos);
              },
              childCount: mappedPositions.length,
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.xxl)),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;

  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: AppText.headline.copyWith(color: context.colors.brand)),
        Text(label,
            style: AppText.micro.copyWith(color: context.colors.textSecondary)),
      ],
    );
  }
}

class _PositionRow extends StatelessWidget {
  final RepertoireDiffPosition position;

  const _PositionRow({required this.position});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
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
                  color: context.colors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text('Move ${position.ply ~/ 2 + 1}', style: AppText.bodyBold),
                const Spacer(),
                Text(
                    '${position.leftGames} ${position.leftGames == 1 ? 'game' : 'games'}',
                    style: AppText.caption
                        .copyWith(color: context.colors.textSecondary)),
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
                              .copyWith(color: context.colors.textMuted)),
                      if (position.prepared.isEmpty)
                        Text('-', style: AppText.body)
                      else
                        ...position.prepared.map((m) => Text(m.san,
                            style: AppText.body
                                .copyWith(color: context.colors.brand))),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Played',
                          style: AppText.micro
                              .copyWith(color: context.colors.textMuted)),
                      if (position.played.isEmpty)
                        Text('-', style: AppText.body)
                      else
                        ...position.played.map((m) =>
                            Text('${m.san} (${m.games})', style: AppText.body)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? context.colors.brand : context.colors.textMuted;
    final border = selected ? context.colors.brand : Colors.transparent;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: border, width: 2)),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: AppText.bodyBold.copyWith(color: color),
        ),
      ),
    );
  }
}
