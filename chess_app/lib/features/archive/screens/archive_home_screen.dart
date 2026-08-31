import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/features/archive/models/archive_run.dart';
import 'package:chess_app/features/archive/models/archive_subject.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

class ArchiveHomeScreen extends StatefulWidget {
  const ArchiveHomeScreen({super.key});

  @override
  State<ArchiveHomeScreen> createState() => _ArchiveHomeScreenState();
}

class _ArchiveHomeScreenState extends State<ArchiveHomeScreen> {
  List<ArchiveSubject>? _subjects;
  List<ArchiveRun>? _runs;
  bool _isLoading = true;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _isError = false;
    });

    try {
      final subjects = await ArchiveApiService.instance.getSubjects();
      final runs = await ArchiveApiService.instance.listImports();
      if (mounted) {
        setState(() {
          _subjects = subjects;
          _runs = runs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.colors.canvas,
        appBar: AppBar(
          title: const Text('Moje partije'),
          backgroundColor: context.colors.surface,
          foregroundColor: context.colors.textPrimary,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isError) {
      return Scaffold(
        backgroundColor: context.colors.canvas,
        appBar: AppBar(
          title: const Text('Moje partije'),
          backgroundColor: context.colors.surface,
          foregroundColor: context.colors.textPrimary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Greška pri učitavanju.',
                style: AppText.body.copyWith(color: context.colors.danger),
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Pokušaj ponovo'),
              ),
            ],
          ),
        ),
      );
    }

    final subjects = _subjects ?? [];
    final runs = _runs ?? [];

    if (subjects.isEmpty) {
      return Scaffold(
        backgroundColor: context.colors.canvas,
        appBar: AppBar(
          title: const Text('Moje partije'),
          backgroundColor: context.colors.surface,
          foregroundColor: context.colors.textPrimary,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Nema arhiviranih partija.',
                style:
                    AppText.body.copyWith(color: context.colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              ElevatedButton.icon(
                onPressed: () => context.push(AppRoutes.archiveImport),
                icon: const Icon(Icons.file_upload),
                label: const Text('Uvoz partija'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: const Text('Moje partije'),
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          for (final subject in subjects) _SubjectCard(subject: subject),
          const SizedBox(height: AppSpacing.lg),
          if (runs.isNotEmpty) ...[
            Text(
              'Poslednji uvozi',
              style: AppText.title.copyWith(color: context.colors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final run in runs) _RunRow(run: run),
          ],
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: FilledButton.icon(
              onPressed: () => context.push(AppRoutes.archiveImport),
              icon: const Icon(Icons.file_upload),
              label: const Text('Uvezi još partija'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final ArchiveSubject subject;

  const _SubjectCard({required this.subject});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.colors.surface,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: context.colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subject.subject,
              style:
                  AppText.headline.copyWith(color: context.colors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Partije: ${subject.games}',
              style: AppText.body.copyWith(color: context.colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                FilledButton.icon(
                  onPressed: () =>
                      context.push(AppRoutes.archiveLeaksPath(subject.subject)),
                  icon: const Icon(Icons.search),
                  label: const Text('Pogledaj rupe u otvaranju'),
                ),
                FilledButton.icon(
                  onPressed: () => context.push(
                      '${AppRoutes.archiveRepertoire}?subject=${Uri.encodeQueryComponent(subject.subject)}'),
                  icon: const Icon(Icons.account_tree_outlined),
                  label: const Text('Repertoar iz partija'),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        context.colors.brand.withValues(alpha: 0.08),
                    foregroundColor: context.colors.brand,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => context
                      .push(AppRoutes.archiveProfilePath(subject.subject)),
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Profil i navike'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RunRow extends StatelessWidget {
  final ArchiveRun run;

  const _RunRow({required this.run});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${run.subject} (${run.source})',
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.textPrimary),
                ),
                Text(
                  'Uvezeno: ${run.gamesStored} / ${run.gamesRead}',
                  style: AppText.caption
                      .copyWith(color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: run.status == 'done'
                  ? context.colors.success.withValues(alpha: 0.1)
                  : (run.status == 'failed'
                      ? context.colors.danger.withValues(alpha: 0.1)
                      : context.colors.warning.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Text(
              run.status,
              style: AppText.captionBold.copyWith(
                color: run.status == 'done'
                    ? context.colors.success
                    : (run.status == 'failed'
                        ? context.colors.danger
                        : context.colors.warning),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
