import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// What the student wrote about the position on the board, with the
/// position's other panels — and **nothing at all** while nothing is written.
/// The place beside the book and the engine is the most expensive on the
/// screen; a card saying "no comment" would push them down to tell the reader
/// something they already know. Writing one starts from „Add comment" on the
/// strip under the board.
///
/// Until 30.9.2026 a desktop window gave it a column of its own, where it
/// stood empty as an invitation. The owner had that column removed so the
/// book and the engine could take its place beside the board.
class RepertoireCommentPanel extends StatelessWidget {
  const RepertoireCommentPanel({
    super.key,
    required this.body,
    required this.onEdit,
    this.onDelete,
    this.busy = false,
  });

  /// Null or empty means nothing has been written about this position.
  final String? body;

  final VoidCallback onEdit;

  /// Absent while there is nothing to delete.
  final VoidCallback? onDelete;

  /// A save is in flight. The text stays on screen — it is what the student
  /// typed and it is not in question — and only the buttons wait.
  final bool busy;

  bool get _hasText => (body ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_hasText) return const SizedBox.shrink();

    final colors = context.colors;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.roundedSm,
        border: Border.all(color: colors.info.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sticky_note_2_outlined, size: 14, color: colors.info),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text('My comment',
                    style: AppText.captionBold.copyWith(color: colors.info)),
              ),
              // Never hidden behind a long press or a menu: this is the button
              // the whole panel exists for.
              IconButton(
                icon: Icon(Icons.edit_outlined, size: 16, color: colors.info),
                tooltip: 'Edit comment',
                visualDensity: VisualDensity.compact,
                onPressed: busy ? null : onEdit,
              ),
              if (onDelete != null)
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 16, color: colors.danger),
                  tooltip: 'Delete comment',
                  visualDensity: VisualDensity.compact,
                  onPressed: busy ? null : onDelete,
                ),
            ],
          ),
          InkWell(
            borderRadius: AppRadii.roundedSm,
            onTap: busy ? null : onEdit,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Text(body!.trim(),
                  style: AppText.body.copyWith(color: colors.textPrimary)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The editor, as a sheet on a phone and a dialog on a desktop.
///
/// Returns what was typed, or null when it was closed without saving — and
/// those are different answers: an empty string is "clear this comment", which
/// the server turns into a delete, while null must leave what is stored alone.
///
/// The sheet is `isScrollControlled` and padded by `viewInsets`, or the
/// keyboard covers the box being typed into. On a release build that is not an
/// overflow warning, it is simply a field nobody can see.
Future<String?> showRepertoireCommentEditor(
  BuildContext context, {
  String initial = '',
  String? line,
  bool wide = false,
  int maxLength = 4000,
}) {
  final controller = TextEditingController(text: initial);

  Widget field(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (line != null && line.trim().isNotEmpty) ...[
            Text(line,
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted)),
            const SizedBox(height: AppSpacing.sm),
          ],
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: 6,
            minLines: 3,
            maxLength: maxLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'What should you know about this position?',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      );

  if (wide) {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Comment on position'),
        content: SizedBox(
          // From MediaQuery rather than a fixed number: a dialog 360 wide on a
          // 360 dp screen has no margin at all, and that has happened here
          // before.
          width: MediaQuery.of(context).size.width * 0.5,
          child: SingleChildScrollView(child: field(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Comment on position',
              style:
                  AppText.bodyBold.copyWith(color: context.colors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          field(context),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
