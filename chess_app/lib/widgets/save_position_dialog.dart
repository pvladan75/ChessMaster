import 'package:flutter/material.dart';

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
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...dialogActiveTags.map((t) => Chip(
                          label: Text(t, style: const TextStyle(fontSize: 11)),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () => removeTag(t),
                          backgroundColor: Colors.teal.withValues(alpha: 0.2),
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
                        style: const TextStyle(fontSize: 12),
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
                      border:
                          Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = suggestions[index];
                        return ListTile(
                          dense: true,
                          title: Text(suggestion,
                              style: const TextStyle(fontSize: 12)),
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
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Unesite naziv lekcije.'),
                    backgroundColor: Colors.redAccent),
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
