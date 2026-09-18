import 'package:flutter/material.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';

/// The label (tag) editor this dialog first drew: active chips, a text field
/// to add one, and a suggestion list drawn from what the trainer has used
/// before. `MakeExerciseSheet` (`docs/PLAN-EXERCISE.md`, phase 2b) needs the
/// same editor, so it lives here as its own widget rather than a second copy.
class LabelChipInput extends StatefulWidget {
  const LabelChipInput({
    super.key,
    required this.availableUserLabels,
    required this.initialLabels,
    required this.onChanged,
  });

  final List<String> availableUserLabels;
  final List<String> initialLabels;
  final ValueChanged<List<String>> onChanged;

  @override
  State<LabelChipInput> createState() => _LabelChipInputState();
}

class _LabelChipInputState extends State<LabelChipInput> {
  final TextEditingController _inputController = TextEditingController();
  late List<String> _active;

  @override
  void initState() {
    super.initState();
    _active = List<String>.from(widget.initialLabels);
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _add(String tag) {
    final cleaned = tag.trim();
    if (cleaned.isEmpty || _active.contains(cleaned)) return;
    setState(() {
      _active.add(cleaned);
      _inputController.clear();
    });
    widget.onChanged(List<String>.unmodifiable(_active));
  }

  void _remove(String tag) {
    setState(() => _active.remove(tag));
    widget.onChanged(List<String>.unmodifiable(_active));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final suggestions = widget.availableUserLabels
        .where((l) => !_active.contains(l))
        .where((l) =>
            _inputController.text.isEmpty ||
            l.toLowerCase().contains(_inputController.text.toLowerCase()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Labels (Tags):', style: AppText.bodyLargeBold),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ..._active.map((t) => Chip(
                  label: Text(t, style: AppText.caption),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => _remove(t),
                  backgroundColor: colors.accent.withValues(alpha: 0.2),
                )),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputController,
                decoration: const InputDecoration(
                  hintText: 'Type and add label...',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 10, vertical: AppSpacing.sm),
                ),
                style: AppText.body,
                onChanged: (_) => setState(() {}),
                onSubmitted: (val) => _add(val),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ElevatedButton(
              onPressed: () => _add(_inputController.text),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.md)),
              child: const Text('Add'),
            ),
          ],
        ),
        if (suggestions.isNotEmpty && _inputController.text.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
              border:
                  Border.all(color: colors.textMuted.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final suggestion = suggestions[index];
                return ListTile(
                  dense: true,
                  title: Text(suggestion, style: AppText.body),
                  onTap: () => _add(suggestion),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class SavePositionDialog extends StatefulWidget {
  final List<String> availableUserLabels;
  final List<String> initialPersistedLabels;
  final bool initialShouldPersist;
  final Function(
      String title, String desc, List<String> tags, bool shouldPersist) onSave;

  const SavePositionDialog({
    super.key,
    required this.availableUserLabels,
    required this.initialPersistedLabels,
    required this.initialShouldPersist,
    required this.onSave,
  });

  @override
  State<SavePositionDialog> createState() => _SavePositionDialogState();
}

class _SavePositionDialogState extends State<SavePositionDialog> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descController = TextEditingController();

  late List<String> dialogActiveTags;
  late bool persistChecked;

  @override
  void initState() {
    super.initState();
    dialogActiveTags = widget.initialShouldPersist
        ? List<String>.from(widget.initialPersistedLabels)
        : [];
    persistChecked = widget.initialShouldPersist;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save position'),
      // The width must be tight: AlertDialog wraps its children in an
      // IntrinsicWidth, and a loose maxWidth would let that intrinsic pass
      // descend into the suggestion list below, which cannot report intrinsics.
      content: SizedBox(
        width: 360,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Position name',
                    hintText: 'E.g. Sicilian Defense - Najdorf',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'Brief notes for students...',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.lg),
                LabelChipInput(
                  availableUserLabels: widget.availableUserLabels,
                  initialLabels: dialogActiveTags,
                  onChanged: (tags) => dialogActiveTags = tags,
                ),
                const SizedBox(height: AppSpacing.lg),
                CheckboxListTile(
                  title: const Text(
                    'Remember these labels for next positions',
                    style: AppText.bodyBold,
                  ),
                  value: persistChecked,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (val) {
                    setState(() {
                      persistChecked = val ?? false;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final title = titleController.text.trim();
            final desc = descController.text.trim();

            if (title.isEmpty) {
              AppFeedback.show(
                context,
                () => SnackBar(
                    content: const Text('Enter a name.'),
                    backgroundColor: context.colors.danger),
              );
              return;
            }

            Navigator.pop(context);
            widget.onSave(title, desc, dialogActiveTags, persistChecked);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
