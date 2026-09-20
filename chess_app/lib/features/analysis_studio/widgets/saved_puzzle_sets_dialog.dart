import 'package:flutter/material.dart';
import 'package:chess_app/core/services/local_puzzle_extractor_service.dart';
import 'package:chess_app/core/services/local_puzzle_set_storage_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/adaptive_card_grid.dart';

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
    // A plain `Dialog`, not an `AlertDialog` — it does not lay its child out
    // under an `IntrinsicWidth`, but the fixed `Container(width: 460)` this
    // replaces still overflowed on a 360 dp phone, where `Dialog`'s default
    // insets leave about 280: less than 460, and the size a `ListTile`'s
    // trailing row needed. Read from `MediaQuery` instead, the same instinct
    // `BoardPreviewDialog` and `GameSelectorDialog` already carry, and a
    // fixed width can never fit two columns of cards either.
    final mediaSize = MediaQuery.of(context).size;
    final dialogWidth = (mediaSize.width - 64).clamp(280.0, 640.0);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.roundedLg),
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.extension, color: context.colors.accent, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Text('Saved puzzles',
                    style: AppText.title
                        .copyWith(color: context.colors.textPrimary)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Puzzles are automatically saved on this device when found during "Review full game".',
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
                  'No saved puzzles yet.',
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: context.colors.textMuted),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5),
                child: AdaptiveCardGrid(
                  shrinkWrap: true,
                  tileHeight: 140,
                  padding: EdgeInsets.zero,
                  itemCount: _sets.length,
                  itemBuilder: (context, index) {
                    final set = _sets[index];
                    return Card(
                      color: context.colors.surfaceRaised,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.folder_open,
                                    color: context.colors.info, size: 18),
                                const SizedBox(width: AppSpacing.xs),
                                Expanded(
                                  child: Text(
                                    set.title,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.bodyLarge.copyWith(
                                        color: context.colors.textPrimary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '${set.puzzles.length} ${set.puzzles.length == 1 ? 'puzzle' : 'puzzles'}',
                              style: AppText.caption.copyWith(
                                  color: context.colors.textSecondary),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      color: context.colors.danger, size: 20),
                                  tooltip: 'Delete',
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _delete(set),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                ElevatedButton(
                                  onPressed: set.puzzles.isEmpty
                                      ? null
                                      : () {
                                          Navigator.pop(context);
                                          widget.onPuzzleSetOpened(
                                              set.puzzles, 0);
                                        },
                                  child: const Text('Open'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
