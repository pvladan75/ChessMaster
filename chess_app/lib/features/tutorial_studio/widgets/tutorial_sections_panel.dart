import 'package:flutter/material.dart';

import 'package:chess_app/features/assignments/models/assignment.dart'
    show LessonStepKind;
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
/// **What a trainer reads here is not „Deo 1, Deo 2, Deo 3".** A tutorial is
/// written by playing moves and saying things about them, and the parts it
/// falls into are the *consequence* of asking a question — not a thing to plan.
/// So a row is called by what it says ([TutorialSection.label]) and the three
/// buttons name what the next step will be rather than that a section is being
/// added. Two of them do not add anything at all: they cut the part being
/// written at the beat the trainer is standing on and put the question there.
class TutorialSectionsPanel extends StatelessWidget {
  const TutorialSectionsPanel({
    super.key,
    required this.draft,
    required this.onSelect,
    required this.onAddShow,
    required this.onAsk,
    required this.onMove,
    required this.onClone,
    required this.onRename,
    required this.onRemove,
  });

  final TutorialDraft draft;
  final void Function(int index) onSelect;

  /// „Novi prikaz" — a new demonstration after this one.
  final VoidCallback onAddShow;

  /// „Traži potez na tabli" / „Traži odgovor iz liste" — ask, here.
  final void Function(LessonStepKind kind) onAsk;

  final void Function(int from, int to) onMove;
  final void Function(int index) onClone;
  final void Function(int index) onRename;
  final void Function(int index) onRemove;

  static bool _isJoined(TutorialSection prev, TutorialSection curr) {
    final endFen = endOfMainLine(prev.root).fen;
    final startFen = curr.root.fen;
    return _fenKey(endFen) == _fenKey(startFen);
  }

  static String _fenKey(String fen) =>
      fen.trim().split(RegExp(r'\s+')).take(4).join(' ');

  /// The chip that says what a part is.
  ///
  /// An icon as well as a word, and never colour alone: the one reader whose
  /// live sign-off this project runs on cannot tell these apart by hue.
  static (String, IconData) _chipOf(LessonStepKind kind) => switch (kind) {
        LessonStepKind.show => ('Show', Icons.visibility_outlined),
        LessonStepKind.askMove => ('Move', Icons.touch_app_outlined),
        LessonStepKind.askChoice => ('Choice', Icons.list_alt_outlined),
      };

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
                OutlinedButton.icon(
                  key: const Key('ask-move'),
                  onPressed: () => onAsk(LessonStepKind.askMove),
                  icon: const Icon(Icons.touch_app_outlined, size: 18),
                  label: const Text('Find the move'),
                ),
                OutlinedButton.icon(
                  key: const Key('ask-choice'),
                  onPressed: () => onAsk(LessonStepKind.askChoice),
                  icon: const Icon(Icons.list_alt_outlined, size: 18),
                  label: const Text('Choose the answer'),
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
                  final (chip, icon) = _chipOf(section.kind);
                  final hasJoin = i > 0 &&
                      _isJoined(draft.sections[i - 1], draft.sections[i]);

                  return ListTile(
                    dense: true,
                    selected: isSelected,
                    selectedTileColor: context.colors.surfaceRaised,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadii.roundedSm,
                    ),
                    leading: Tooltip(
                      message: chip,
                      child: Icon(
                        icon,
                        size: 18,
                        color: isSelected
                            ? context.colors.accent
                            : context.colors.textSecondary,
                      ),
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
                    subtitle: Text(
                      chip,
                      style: AppText.caption
                          .copyWith(color: context.colors.textSecondary),
                    ),
                    trailing: hasJoin
                        ? Tooltip(
                            message: 'Continues from previous part',
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
            ),
          ],
        ),
      ),
    );
  }
}
