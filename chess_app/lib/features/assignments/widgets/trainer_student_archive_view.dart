import 'package:flutter/material.dart';

import 'package:chess_app/features/archive/models/trainer_student_archive.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';

class TrainerStudentArchiveView extends StatefulWidget {
  final int studentId;
  final TrainerStudentArchive? archive;
  final String? error;
  final VoidCallback onRefresh;

  const TrainerStudentArchiveView({
    super.key,
    required this.studentId,
    required this.archive,
    this.error,
    required this.onRefresh,
  });

  @override
  State<TrainerStudentArchiveView> createState() =>
      _TrainerStudentArchiveViewState();
}

class _TrainerStudentArchiveViewState extends State<TrainerStudentArchiveView> {
  bool _creating = false;

  Future<void> _createHomework(bool dryRun) async {
    setState(() => _creating = true);
    try {
      final res = await ArchiveApiService.instance.createHomeworkFromArchive(
        studentId: widget.studentId.toString(),
        dryRun: dryRun,
      );

      if (!mounted) return;

      if (dryRun) {
        final count = res.chosen?.length ?? 0;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Zadaj iz partija?'),
            content: Text('Pronađeno je $count grešaka za domaći.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Otkaži')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Zadaj'),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await _createHomework(false);
        }
      } else {
        AppFeedback.success(context, 'Domaći je zadat iz partija.');
        widget.onRefresh();
      }
    } catch (e) {
      if (mounted) AppFeedback.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.error != null) {
      return Center(
        child: Text(widget.error!,
            style: AppText.body.copyWith(color: context.colors.danger)),
      );
    }
    final archive = widget.archive;
    if (archive == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (archive.subject == null || archive.games == 0) {
      return Center(
        child: Text('Učenik još nije uvezao partije',
            style: AppText.bodyLarge
                .copyWith(color: context.colors.textSecondary)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _buildOverview(archive),
        const SizedBox(height: AppSpacing.lg),
        if (archive.mistakes != null) _buildMistakes(archive),
        const SizedBox(height: AppSpacing.lg),
        if (archive.trend != null && archive.trend!.isNotEmpty)
          _buildTrend(archive),
      ],
    );
  }

  Widget _buildOverview(TrainerStudentArchive archive) {
    return Card(
      color: context.colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Partije (${archive.subject})', style: AppText.title),
            const SizedBox(height: AppSpacing.md),
            Text('Ukupno analizirano: ${archive.games} partija',
                style: AppText.bodyLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildMistakes(TrainerStudentArchive archive) {
    final m = archive.mistakes!;
    return Card(
      color: context.colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Greške', style: AppText.title),
            const SizedBox(height: AppSpacing.md),
            Text('Ukupno pronađeno: ${m.total}', style: AppText.body),
            Text('Čeka za ponavljanje: ${m.due}', style: AppText.body),
            Text('Zrelo: ${m.mature}', style: AppText.body),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: _creating ? null : () => _createHomework(true),
              icon: const Icon(Icons.assignment),
              label: Text(_creating ? 'Zadajem...' : 'Zadaj greške za domaći'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrend(TrainerStudentArchive archive) {
    return Card(
      color: context.colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Aktivnost u poslednjih 12 meseci',
                style: AppText.title),
            const SizedBox(height: AppSpacing.md),
            ...archive.trend!.map((t) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Wrap(
                  spacing: AppSpacing.md,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                        width: 80,
                        child: Text(t.month, style: AppText.bodyBold)),
                    Text('${t.games} partija', style: AppText.body),
                    if (t.score != null)
                      Text('${(t.score! * 100).round()}%',
                          style: AppText.bodyBold
                              .copyWith(color: context.colors.textPrimary)),
                    if (t.avgElo != null)
                      Text('Elo: ${t.avgElo}',
                          style: AppText.caption
                              .copyWith(color: context.colors.textMuted)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
