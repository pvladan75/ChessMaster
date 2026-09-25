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
///
/// **What a trainer reads here is not „Part 1, Part 2, Part 3".** A tutorial is
/// written by playing moves and saying things about them, and the parts it
/// falls into are the *consequence* of asking a question — not a thing to plan.
/// So a row is called by what it says ([TutorialSection.label]). Every part
/// shows (`docs/PLAN-TUTORIJAL-VIDEO.md`, phase 4); a question for a student is
/// an exercise.
class TutorialSectionsPanel extends StatelessWidget {
  const TutorialSectionsPanel({
    super.key,
    required this.draft,
    required this.onSelect,
    required this.onAddShow,
    required this.onMove,
    required this.onClone,
    required this.onRename,
    required this.onRemove,
    this.onAddPartsFrom,
    this.onExtractParts,
    this.onTurn,
  });

  final TutorialDraft draft;
  final void Function(int index) onSelect;

  /// „Novi prikaz" — a new demonstration after this one.
  final VoidCallback onAddShow;

  final void Function(int from, int to) onMove;
  final void Function(int index) onClone;
  final void Function(int index) onRename;
  final void Function(int index) onRemove;

  /// „Add parts from a tutorial…" — another tutorial's parts, copied in here.
  /// Null draws nothing, the rule this panel already follows.
  final VoidCallback? onAddPartsFrom;

  /// „Take parts into a new tutorial…" — parts of this one, written out as a
  /// tutorial of their own. This one keeps them.
  final VoidCallback? onExtractParts;

  /// „Turn this part" — that row's part, drawn from the other side. On each
  /// row rather than among the actions above, which have no pixel to spare at
  /// 840 dp, and so it names the part it acts on. Null draws nothing.
  final void Function(int index)? onTurn;

  static bool _isJoined(TutorialSection prev, TutorialSection curr) {
    final endFen = endOfMainLine(prev.root).fen;
    final startFen = curr.root.fen;
    return _fenKey(endFen) == _fenKey(startFen);
  }

  static String _fenKey(String fen) =>
      fen.trim().split(RegExp(r'\s+')).take(4).join(' ');

  Future<void> _handleDelete(BuildContext context) async {
    if (draft.sections.length <= 1) {
      onRemove(draft.selected);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete part'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
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
                  'Tutorial contents',
                  style:
                      AppText.title.copyWith(color: context.colors.textPrimary),
                ),
                // In this row, and sized so the row cannot grow by a pixel.
                //
                // Every other action here lives in the Wrap below, and that is
                // where this went first: the Wrap has **two pixels** of room at
                // 840 dp (`tutorial_raspored_test`) and one more item in it
                // costs a whole run. The studio's bar was tried next — it had
                // 15 px and an icon costs 48.
                //
                // So: this row, which is as tall as a 16 px title and had
                // nothing on its right. 20 × 20 is a small target, and it is
                // the price of not moving something else a trainer already
                // reaches in one tap. On a phone the same two doors are in the
                // „More" menu, at full size.
                if (onAddPartsFrom != null || onExtractParts != null)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: PopupMenuButton<_PartsMenu>(
                      key: const Key('parts-menu'),
                      tooltip: 'Parts and other tutorials',
                      icon: const Icon(Icons.swap_horiz),
                      iconSize: 18,
                      padding: EdgeInsets.zero,
                      onSelected: (choice) => switch (choice) {
                        _PartsMenu.addFrom => onAddPartsFrom?.call(),
                        _PartsMenu.extract => onExtractParts?.call(),
                      },
                      itemBuilder: (_) => [
                        if (onAddPartsFrom != null)
                          const PopupMenuItem(
                            key: Key('parts-menu-add'),
                            value: _PartsMenu.addFrom,
                            child: Text('Add parts from a tutorial…'),
                          ),
                        if (onExtractParts != null)
                          const PopupMenuItem(
                            key: Key('parts-menu-extract'),
                            value: _PartsMenu.extract,
                            child: Text('Take parts into a new tutorial…'),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // What comes next, said as the thing itself. The two questions act
            // on the beat the trainer is standing on; „Novi prikaz" starts one
            // after this part and asks which position it opens on.
            // One Wrap, not two rows. The three actions and the housekeeping
            // buttons flow together, which is what keeps the fixed part of this
            // panel short enough for the narrowest wide window — 840 dp, where
            // it overflowed by two pixels when they were separate.
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  key: const Key('add-show'),
                  onPressed: onAddShow,
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('New demonstration'),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Move up',
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: canMoveUp
                      ? () => onMove(draft.selected, draft.selected - 1)
                      : null,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Move down',
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: canMoveDown
                      ? () => onMove(draft.selected, draft.selected + 1)
                      : null,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Clone part',
                  icon: const Icon(Icons.copy),
                  onPressed: () => onClone(draft.selected),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Rename',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => onRename(draft.selected),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Delete part',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _handleDelete(context),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.xs),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: draft.sections.length,
                itemBuilder: (context, i) {
                  final section = draft.sections[i];
                  final isSelected = i == draft.selected;
                  // The one function the wire uses too — see
                  // [TutorialSection.toJson]. A row labelled from its index
                  // over a stored title that says something else is batch 57's
                  // finding, and computing the name once is the version of
                  // that fix which cannot come apart.
                  final label = section.label(i);
                  final hasJoin = i > 0 &&
                      _isJoined(draft.sections[i - 1], draft.sections[i]);

                  return ListTile(
                    dense: true,
                    selected: isSelected,
                    selectedTileColor: context.colors.surfaceRaised,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadii.roundedSm,
                    ),
                    leading: Icon(
                      Icons.visibility_outlined,
                      size: 18,
                      color: isSelected
                          ? context.colors.accent
                          : context.colors.textSecondary,
                    ),
                    title: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: (isSelected ? AppText.bodyBold : AppText.body)
                          .copyWith(
                        color: isSelected
                            ? context.colors.textPrimary
                            : context.colors.textSecondary,
                      ),
                    ),
                    trailing: (hasJoin || onTurn != null)
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasJoin)
                                Tooltip(
                                  message: 'Continues from previous part',
                                  child: Icon(
                                    Icons.link,
                                    color: context.colors.accent,
                                    size: 20,
                                  ),
                                ),
                              if (onTurn != null)
                                IconButton(
                                  key: Key('turn-part-$i'),
                                  visualDensity: VisualDensity.compact,
                                  iconSize: 18,
                                  tooltip: section.blackOrientation
                                      ? 'Turn this part (Black at the bottom now)'
                                      : 'Turn this part (White at the bottom now)',
                                  icon: const Icon(Icons.screen_rotation_alt),
                                  onPressed: () => onTurn!(i),
                                ),
                            ],
                          )
                        : null,
                    onTap: () => onSelect(i),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The two doors the contents panel offers onto other tutorials.
enum _PartsMenu { addFrom, extract }
