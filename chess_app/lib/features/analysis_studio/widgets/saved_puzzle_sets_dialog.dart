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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.extension, color: context.colors.accent, size: 22),
                const SizedBox(width: 8),
                Text('Sačuvane vežbe',
                    style: AppText.title
                        .copyWith(color: context.colors.textPrimary)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Vežbe se automatski čuvaju na uređaju kad se otkriju tokom "Analiziraj celu partiju".',
              style: AppText.body.copyWith(color: context.colors.textMuted),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_sets.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
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
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: Colors.black26,
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.folder_open,
                              color: context.colors.info, size: 18),
                          title: Text(set.title,
                              style: AppText.caption
                                  .copyWith(color: context.colors.textPrimary)),
                          subtitle: Text(
                            '${set.puzzles.length} vežbi',
                            style: AppText.micro
                                .copyWith(color: context.colors.textMuted),
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
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white),
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
            const SizedBox(height: 12),
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
