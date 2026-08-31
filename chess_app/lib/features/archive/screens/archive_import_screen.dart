import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/features/archive/models/archive_run.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/features/archive/widgets/import_counters.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';

class ArchiveImportScreen extends StatefulWidget {
  const ArchiveImportScreen({super.key});

  @override
  State<ArchiveImportScreen> createState() => _ArchiveImportScreenState();
}

class _ArchiveImportScreenState extends State<ArchiveImportScreen> {
  final TextEditingController _usernameController = TextEditingController();
  ArchiveRun? _run;
  bool _isUploading = false;
  Timer? _pollTimer;

  @override
  void dispose() {
    _usernameController.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _pickAndUpload() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      AppFeedback.error(context, 'Unesite korisničko ime.');
      return;
    }

    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pgn'],
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    setState(() {
      _isUploading = true;
      _run = null;
    });

    try {
      final importId =
          await ArchiveApiService.instance.importFile(path, username);
      _poll(importId);
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        AppFeedback.error(context, 'Greška: $e');
      }
    }
  }

  void _poll(int importId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final run = await ArchiveApiService.instance.getImport(importId);
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _run = run;
        });

        if (run.status == 'done' || run.status == 'failed') {
          timer.cancel();
          setState(() {
            _isUploading = false;
          });
          if (run.status == 'failed' && run.error != null) {
            AppFeedback.error(context, run.error!);
          } else if (run.status == 'done') {
            AppFeedback.success(context, 'Uvoz je završen.');
          }
        }
      } catch (e) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        timer.cancel();
        setState(() {
          _isUploading = false;
        });
        AppFeedback.error(context, 'Greška pri čitanju statusa: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: const Text('Uvoz partija'),
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Korisničko ime na Lichess / Chess.com:',
                style: AppText.bodyBold
                    .copyWith(color: context.colors.textPrimary)),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _usernameController,
              enabled: !_isUploading,
              style: AppText.body.copyWith(color: context.colors.textPrimary),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'npr. magnuscarlsen',
                hintStyle:
                    AppText.body.copyWith(color: context.colors.textMuted),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _pickAndUpload,
              icon: const Icon(Icons.file_upload),
              label: Text(_isUploading ? 'Uvoz u toku...' : 'Izaberi PGN fajl'),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_run != null) ...[
              ImportCounters(run: _run!),
              if (_run!.status == 'done' &&
                  (_run!.gamesStored + _run!.gamesDuplicate) > 0) ...[
                const SizedBox(height: AppSpacing.md),
                // Offered rather than jumped to. The four counters above are
                // the answer this screen exists to give, and navigating past
                // them the moment a run finishes throws that away.
                FilledButton.icon(
                  onPressed: () =>
                      context.push(AppRoutes.archiveLeaksPath(_run!.subject)),
                  icon: const Icon(Icons.search),
                  label: const Text('Pogledaj rupe u otvaranju'),
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: () => context.push(
                      '${AppRoutes.archiveRepertoire}?subject=${Uri.encodeQueryComponent(_run!.subject)}'),
                  icon: const Icon(Icons.account_tree_outlined),
                  label: const Text('Repertoar iz partija'),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        context.colors.brand.withValues(alpha: 0.08),
                    foregroundColor: context.colors.brand,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: () =>
                      context.push(AppRoutes.archiveProfilePath(_run!.subject)),
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Profil i navike'),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              if (_isUploading) const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}
