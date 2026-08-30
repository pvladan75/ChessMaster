import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/archive/models/leak_report.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

class OpeningLeakReportScreen extends StatefulWidget {
  const OpeningLeakReportScreen({
    super.key,
    required this.subject,
  });

  final String subject;

  @override
  State<OpeningLeakReportScreen> createState() =>
      _OpeningLeakReportScreenState();
}

class _OpeningLeakReportScreenState extends State<OpeningLeakReportScreen> {
  String _color = 'w'; // 'w' or 'b'

  /// Off until asked. Judging spends requests against the player's own Lichess
  /// allowance, and the counted half of this report — which positions, how
  /// often, how badly — is complete without it.
  bool _judge = false;
  Future<LeakReport>? _reportFuture;
  bool _isBackfilling = false;

  @override
  void initState() {
    super.initState();
    _fetchReport();
  }

  void _fetchReport() {
    setState(() {
      _reportFuture = ArchiveApiService.instance.getLeaks(
        subject: widget.subject,
        color: _color,
        judge: _judge ? true : null,
      );
    });
  }

  Future<void> _backfill() async {
    setState(() => _isBackfilling = true);
    try {
      await ArchiveApiService.instance.backfill();
      if (!mounted) return;
      AppFeedback.success(context, 'Indeksiranje pokrenuto.');
      _fetchReport();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, 'Greška: $e');
    } finally {
      if (mounted) {
        setState(() => _isBackfilling = false);
      }
    }
  }

  ({IconData icon, String title}) _face(OpeningVerdict verdict) {
    switch (verdict) {
      case OpeningVerdict.theory:
        return (icon: Icons.menu_book, title: 'Glavna teorija');
      case OpeningVerdict.playable:
        return (
          icon: Icons.thumb_up_alt_outlined,
          title: 'Praktična alternativa'
        );
      case OpeningVerdict.mistake:
        return (icon: Icons.warning_amber_rounded, title: 'Sumnjiv potez');
      case OpeningVerdict.unknown:
        return (icon: Icons.help_outline, title: 'Nije presuđeno');
    }
  }

  Color _colorOf(BuildContext context, OpeningVerdict verdict) {
    switch (verdict) {
      case OpeningVerdict.theory:
        return context.colors.success;
      case OpeningVerdict.playable:
        return context.colors.info;
      case OpeningVerdict.mistake:
        return context.colors.danger;
      case OpeningVerdict.unknown:
        return context.colors.textMuted;
    }
  }

  Widget _buildNode(BuildContext context, LeakReportNode node) {
    final moves = node.moves;
    if (moves.isEmpty) return const SizedBox.shrink();

    final mainMove = moves.first;
    final otherMoves = moves.skip(1).toList();

    return Container(
      key: ValueKey(node.fenKey),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadii.roundedMd,
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BoardThumbnail(
            fen: node.fen,
            size: 80,
            isWhiteBottom: _color == 'w',
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${node.ply}. polupotez · uspeh ${(node.score * 100).toStringAsFixed(1)}%',
                  style:
                      AppText.caption.copyWith(color: context.colors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  '${mainMove.san} — ${mainMove.games} od ${node.games} partija · ${(mainMove.score * 100).toStringAsFixed(1)}%',
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.textPrimary),
                ),
                if (otherMoves.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Ostali pokušaji: ${otherMoves.map((m) => '${m.san} (${m.games})').join(', ')}',
                    style: AppText.caption
                        .copyWith(color: context.colors.textSecondary),
                  ),
                ],
                if (node.judgement != null &&
                    node.judgement!.verdict != OpeningVerdict.unknown) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _buildJudgement(context, node.judgement!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJudgement(BuildContext context, LeakJudgement j) {
    final face = _face(j.verdict);
    final color = _colorOf(context, j.verdict);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(face.icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(face.title,
                  style: AppText.captionBold.copyWith(color: color)),
            ],
          ),
          if (j.better != null) ...[
            const SizedBox(height: 2),
            Text(
              'Bolje je bilo ${j.better}.',
              style: AppText.micro.copyWith(color: color),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: const Text('Rupe u otvaranju'),
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchReport,
            tooltip: 'Osveži',
          ),
        ],
      ),
      body: FutureBuilder<LeakReport>(
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Greška: ${snapshot.error}',
                style: AppText.body.copyWith(color: context.colors.danger),
              ),
            );
          }

          final report = snapshot.data;
          if (report == null) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                color: context.colors.surface,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Text('Boja:',
                        style: AppText.bodyBold
                            .copyWith(color: context.colors.textPrimary)),
                    const SizedBox(width: AppSpacing.md),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'w', label: Text('Beli')),
                        ButtonSegment(value: 'b', label: Text('Crni')),
                      ],
                      selected: {_color},
                      onSelectionChanged: (set) {
                        setState(() {
                          _color = set.first;
                          _fetchReport();
                        });
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    if (!report.judge.requested) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: AppRadii.roundedSm,
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Brojevi iznad su potpuni i bez suđenja. Ako '
                              'želite i mišljenje o potezu koji stalno '
                              'igrate, to troši vaš Lichess token.',
                              style: AppText.caption
                                  .copyWith(color: context.colors.textMuted),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() => _judge = true);
                                _fetchReport();
                              },
                              icon: const Icon(Icons.gavel, size: 16),
                              label: const Text('Presudi poteze'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (report.judge.reason == 'no-token') ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: context.colors.warning.withValues(alpha: 0.1),
                          borderRadius: AppRadii.roundedSm,
                          border: Border.all(
                              color: context.colors.warning
                                  .withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          'Izveštaj je prikazan, ali suđenje poteza zahteva Lichess token u Podešavanjima.',
                          style: AppText.caption
                              .copyWith(color: context.colors.warning),
                        ),
                      ),
                    ],
                    if (report.gamesWithoutNodes > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: context.colors.info.withValues(alpha: 0.1),
                          borderRadius: AppRadii.roundedSm,
                          border: Border.all(
                              color:
                                  context.colors.info.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${report.gamesWithoutNodes} partija nije indeksirano za otvaranja.',
                              style: AppText.body
                                  .copyWith(color: context.colors.info),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            ElevatedButton(
                              onPressed: _isBackfilling ? null : _backfill,
                              child: Text(_isBackfilling
                                  ? 'Pokretanje...'
                                  : 'Indeksiraj stare partije'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (report.nodes.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Text(
                            'Nema pronađenih grešaka u otvaranju.',
                            style: AppText.body
                                .copyWith(color: context.colors.textMuted),
                          ),
                        ),
                      )
                    else
                      ...report.nodes.map((node) => _buildNode(context, node)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
