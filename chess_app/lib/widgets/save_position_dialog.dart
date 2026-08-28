import 'package:flutter/material.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';

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
  final TextEditingController tagInputController = TextEditingController();

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

  void addTag(String tag) {
    final cleaned = tag.trim();
    if (cleaned.isNotEmpty && !dialogActiveTags.contains(cleaned)) {
      setState(() {
        dialogActiveTags.add(cleaned);
        tagInputController.clear();
      });
    }
  }

  void removeTag(String tag) {
    setState(() {
      dialogActiveTags.remove(tag);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final suggestions = widget.availableUserLabels
        .where((l) => !dialogActiveTags.contains(l))
        .where((l) =>
            tagInputController.text.isEmpty ||
            l.toLowerCase().contains(tagInputController.text.toLowerCase()))
        .toList();

    return AlertDialog(
      title: const Text('Sačuvaj trenutnu lekciju / poziciju'),
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
                    labelText: 'Naziv lekcije / pozicije',
                    hintText: 'Npr. Sicilijanska odbrana - Najdorf',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Opis (opciono)',
                    hintText: 'Kratke napomene za učenike...',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Labele (Oznake):',
                  style: AppText.bodyLargeBold,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...dialogActiveTags.map((t) => Chip(
                          label: Text(t, style: AppText.caption),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () => removeTag(t),
                          backgroundColor: colors.accent.withValues(alpha: 0.2),
                        )),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: tagInputController,
                        decoration: const InputDecoration(
                          hintText: 'Ukucaj i dodaj labelu...',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        style: AppText.body,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (val) => addTag(val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => addTag(tagInputController.text),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12)),
                      child: const Text('Dodaj'),
                    ),
                  ],
                ),
                if (suggestions.isNotEmpty &&
                    tagInputController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: colors.textMuted.withValues(alpha: 0.3)),
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
                          onTap: () => addTag(suggestion),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text(
                    'Zapamti ove Labele za sledeće pozicije',
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
          child: const Text('Otkaži'),
        ),
        ElevatedButton(
          onPressed: () {
            final title = titleController.text.trim();
            final desc = descController.text.trim();

            if (title.isEmpty) {
              AppFeedback.show(
                context,
                () => SnackBar(
                    content: const Text('Unesite naziv lekcije.'),
                    backgroundColor: context.colors.danger),
              );
              return;
            }

            Navigator.pop(context);
            widget.onSave(title, desc, dialogActiveTags, persistChecked);
          },
          child: const Text('Sačuvaj'),
        ),
      ],
    );
  }
}
