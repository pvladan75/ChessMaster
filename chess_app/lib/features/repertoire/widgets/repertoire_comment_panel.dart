import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// What the student wrote about the position on the board.
///
/// One widget, two mountings, and that is the whole point of it being a widget
/// rather than two pieces of screen:
///
///   * **Beside the board**, in the third column of a desktop window, where it
///     is a panel that says so even when it is empty — an empty panel there is
///     an invitation, and the space was going to be empty anyway.
///   * **Under the board**, on a phone or a narrow window, where an empty
///     comment draws **nothing at all**. The column under a board on a 360 dp
///     screen is the most expensive space in the app; a card saying "no
///     comment" would push the question off the bottom to tell the reader
///     something they already know.
///
/// That is what [dense] switches. Everything else — the text, the edit and the
/// delete — is the same in both places, because it is the same comment.
class RepertoireCommentPanel extends StatelessWidget {
  const RepertoireCommentPanel({
    super.key,
    required this.body,
    required this.onEdit,
    this.onDelete,
    this.dense = false,
    this.busy = false,
  });

  /// Null or empty means nothing has been written about this position.
  final String? body;

  final VoidCallback onEdit;

  /// Absent while there is nothing to delete.
  final VoidCallback? onDelete;

  /// Under the board rather than beside it: collapses to nothing when empty.
  final bool dense;

  /// A save is in flight. The text stays on screen — it is what the student
  /// typed and it is not in question — and only the buttons wait.
  final bool busy;

  bool get _hasText => (body ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (dense && !_hasText) return const SizedBox.shrink();

    final colors = context.colors;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: dense ? AppSpacing.xs : 0),
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
                child: Text('Moj komentar',
                    style: AppText.captionBold.copyWith(color: colors.info)),
              ),
              // Never hidden behind a long press or a menu: this is the button
              // the whole panel exists for.
              IconButton(
                icon: Icon(Icons.edit_outlined, size: 16, color: colors.info),
                tooltip: _hasText ? 'Izmeni komentar' : 'Napiši komentar',
                visualDensity: VisualDensity.compact,
                onPressed: busy ? null : onEdit,
              ),
              if (_hasText && onDelete != null)
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 16, color: colors.danger),
                  tooltip: 'Obriši komentar',
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
              child: _hasText
                  ? Text(body!.trim(),
                      style: AppText.body.copyWith(color: colors.textPrimary))
                  : Text(
                      'Ništa još nije zapisano o ovoj poziciji. Plan, zamka, '
                      'čega se paziti — ono što biste sebi rekli za pola '
                      'godine.',
                      style: AppText.caption.copyWith(color: colors.textMuted)),
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
              hintText: 'Šta treba znati o ovoj poziciji?',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      );

  if (wide) {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Komentar uz poziciju'),
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
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Sačuvaj'),
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
          Text('Komentar uz poziciju',
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
                child: const Text('Odustani'),
              ),
              const SizedBox(width: AppSpacing.sm),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('Sačuvaj'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
