import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:chess_app/features/archive/models/archive_run.dart';
import 'package:chess_app/features/archive/services/archive_api_service.dart';
import 'package:chess_app/features/archive/widgets/archive_doors.dart';
import 'package:chess_app/features/archive/widgets/import_counters.dart';
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
      AppFeedback.error(context, 'Enter username.');
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
        AppFeedback.error(context, 'Error: $e');
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
          // A finished import is said in the result card (R3). A failed one
          // that names its cause still says it as a message, as before.
          if (run.status == 'failed' && run.error != null) {
            AppFeedback.error(context, run.error!);
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
        AppFeedback.error(context, 'Error reading status: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final run = _run;
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: const Text('Import games'),
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary,
      ),
      // One column of reading width in the middle of the window, not a field
      // the width of the window (R1 of docs/PLAN-EKRANI.md).
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Username on Lichess / Chess.com:',
                    style: AppText.bodyBold
                        .copyWith(color: context.colors.textPrimary)),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _usernameController,
                  enabled: !_isUploading,
                  style:
                      AppText.body.copyWith(color: context.colors.textPrimary),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: 'e.g. magnuscarlsen',
                    hintStyle:
                        AppText.body.copyWith(color: context.colors.textMuted),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: _isUploading ? null : _pickAndUpload,
                    icon: const Icon(Icons.file_upload),
                    label:
                        Text(_isUploading ? 'Importing...' : 'Select PGN file'),
                  ),
                ),
                if (run != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _ResultCard(run: run, running: _isUploading),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The running and the finished import, said where the result is (R3): until
/// phase 9 „Import completed." was a snackbar that went away in a few seconds
/// over four figures that stayed.
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.run, required this.running});

  final ArchiveRun run;
  final bool running;

  @override
  Widget build(BuildContext context) {
    final done = run.status == 'done';
    // Offered rather than jumped to. The four counters are the answer this
    // screen exists to give, and navigating past them the moment a run
    // finishes throws that away.
    final offerDoors = done && (run.gamesStored + run.gamesDuplicate) > 0;
    return Card(
      color: context.colors.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: context.colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (done) ...[
              Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: context.colors.success),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('Import completed.',
                        style: AppText.headline
                            .copyWith(color: context.colors.textPrimary)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            ImportCounters(run: run),
            if (offerDoors) ...[
              const SizedBox(height: AppSpacing.sm),
              ArchiveDoors(subject: run.subject),
            ],
            if (running) ...[
              const SizedBox(height: AppSpacing.md),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
      ),
    );
  }
}
