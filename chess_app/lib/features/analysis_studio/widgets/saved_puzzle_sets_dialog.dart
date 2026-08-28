import 'package:flutter/material.dart';
import 'package:chess_app/core/services/local_puzzle_extractor_service.dart';
import 'package:chess_app/core/services/local_puzzle_set_storage_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// Browses puzzle sets extracted from games during whole-game review (see
/// [GameReviewDialog]) and auto-saved on-device by
/// [LocalPuzzleSetStorageService] — lets the user reopen or discard a set
/// without having to re-run analysis.
class SavedPuzzleSetsDialog extends StatefulWidget {
  final void Function(List<LocalPuzzle> puzzles, int startIndex)
      onPuzzleSetOpened;

  const SavedPuzzleSetsDialog({super.key, required this.onPuzzleSetOpened});

  @override
  State<SavedPuzzleSetsDialog> createState() => _SavedPuzzleSetsDialogState();
}

class _SavedPuzzleSetsDialogState extends State<SavedPuzzleSetsDialog> {
  List<SavedPuzzleSet> _sets = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sets = await LocalPuzzleSetStorageService.instance.loadSets();
    if (!mounted) return;
    setState(() {
      _sets = sets;
      _loading = false;
    });
  }

  Future<void> _delete(SavedPuzzleSet set) async {
    await LocalPuzzleSetStorageService.instance.deleteSet(set.id);
    if (!mounted) return;
    setState(() => _sets = _sets.where((s) => s.id != set.id).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.roundedLg),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.extension, color: context.colors.accent, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Text('Sačuvane vežbe',
                    style: AppText.title
                        .copyWith(color: context.colors.textPrimary)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Vežbe se automatski čuvaju na uređaju kad se otkriju tokom "Analiziraj celu partiju".',
              style: AppText.body.copyWith(color: context.colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_sets.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  'Još nema sačuvanih vežbi.',
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: context.colors.textMuted),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5),
                child: SingleChildScrollView(
                  child: Column(
                    children: _sets.map((set) {
                      return Card(
                        margin:
                            const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        color: context.colors.surfaceRaised,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.folder_open,
                              color: context.colors.info, size: 18),
                          title: Text(set.title,
                              style: AppText.bodyLarge
                                  .copyWith(color: context.colors.textPrimary)),
                          subtitle: Text(
                            '${set.puzzles.length} vežbi',
                            style: AppText.caption
                                .copyWith(color: context.colors.textSecondary),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.delete_outline,
                                    color: context.colors.danger, size: 20),
                                tooltip: 'Obriši',
                                onPressed: () => _delete(set),
                              ),
                              ElevatedButton(
                                onPressed: set.puzzles.isEmpty
                                    ? null
                                    : () {
                                        Navigator.pop(context);
                                        widget.onPuzzleSetOpened(
                                            set.puzzles, 0);
                                      },
                                child: const Text('Otvori'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Zatvori'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
