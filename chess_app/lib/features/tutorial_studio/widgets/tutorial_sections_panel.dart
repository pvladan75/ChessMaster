import 'package:flutter/material.dart';

import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart'
    show endOfMainLine;
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// The table of contents for a tutorial being written.
///
/// Stateless, and it decides nothing: it draws [draft.sections], marks
/// [draft.selected], and reports through its callbacks. Every mutation goes
/// through the screen, which owns the draft, the board controller and the text
/// fields.
class TutorialSectionsPanel extends StatelessWidget {
  const TutorialSectionsPanel({
    super.key,
    required this.draft,
    required this.onSelect,
    required this.onAdd,
    required this.onMove,
    required this.onClone,
    required this.onRemove,
  });

  final TutorialDraft draft;
  final void Function(int index) onSelect;
  final void Function({required bool continueFromEnd}) onAdd;
  final void Function(int from, int to) onMove;
  final void Function(int index) onClone;
  final void Function(int index) onRemove;

  static bool _isJoined(TutorialSection prev, TutorialSection curr) {
    final endFen = endOfMainLine(prev.root).fen;
    final startFen = curr.root.fen;
    return _fenKey(endFen) == _fenKey(startFen);
  }

  static String _fenKey(String fen) =>
      fen.trim().split(RegExp(r'\s+')).take(4).join(' ');

  Future<void> _handleAdd(BuildContext context) async {
    final continueFromEnd = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Gde počinje novi deo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Otkaži'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Nova pozicija'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Nastavi odavde'),
          ),
        ],
      ),
    );
    if (continueFromEnd != null) {
      onAdd(continueFromEnd: continueFromEnd);
    }
  }

  Future<void> _handleDelete(BuildContext context) async {
    if (draft.sections.length <= 1) {
      onRemove(draft.selected);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Brisanje dela'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      onRemove(draft.selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canMoveUp = draft.selected > 0;
    final canMoveDown = draft.selected < draft.sections.length - 1;

    return Material(
      color: context.colors.surface,
      borderRadius: AppRadii.roundedMd,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: AppRadii.roundedMd,
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Delovi tutorijala',
                  style:
                      AppText.title.copyWith(color: context.colors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => _handleAdd(context),
                  child: const Text('+ Dodaj deo'),
                ),
                IconButton(
                  tooltip: 'Pomeri gore',
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: canMoveUp
                      ? () => onMove(draft.selected, draft.selected - 1)
                      : null,
                ),
                IconButton(
                  tooltip: 'Pomeri dole',
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: canMoveDown
                      ? () => onMove(draft.selected, draft.selected + 1)
                      : null,
                ),
                IconButton(
                  tooltip: 'Kloniraj deo',
                  icon: const Icon(Icons.copy),
                  onPressed: () => onClone(draft.selected),
                ),
                IconButton(
                  tooltip: 'Obriši deo',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _handleDelete(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.xs),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: draft.sections.length,
              itemBuilder: (context, i) {
                final isSelected = i == draft.selected;
                final rawTitle = draft.sections[i].title.trim();
                // A tutorial written before „Primer" became „Deo" arrives from
                // the server with its old generated names, and nothing has
                // renumbered it yet — the screen only does that when a part is
                // added, moved, cloned or removed.
                final label =
                    rawTitle.isEmpty || isGeneratedSectionTitle(rawTitle)
                        ? generatedSectionTitle(i)
                        : rawTitle;
                final hasJoin = i > 0 &&
                    _isJoined(draft.sections[i - 1], draft.sections[i]);

                return ListTile(
                  dense: true,
                  selected: isSelected,
                  selectedTileColor: context.colors.surfaceRaised,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadii.roundedSm,
                  ),
                  title: Text(
                    label,
                    style:
                        (isSelected ? AppText.bodyBold : AppText.body).copyWith(
                      color: isSelected
                          ? context.colors.textPrimary
                          : context.colors.textSecondary,
                    ),
                  ),
                  trailing: hasJoin
                      ? Tooltip(
                          message: 'Nastavlja se na prethodni deo',
                          child: Icon(
                            Icons.link,
                            color: context.colors.accent,
                            size: 20,
                          ),
                        )
                      : null,
                  onTap: () => onSelect(i),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
