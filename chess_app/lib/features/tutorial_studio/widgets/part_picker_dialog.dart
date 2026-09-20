/// Which parts, and — when a new tutorial is being made from them — what it is
/// called.
///
/// One dialog for both directions, because the question is the same one: a
/// tutorial's parts, in the order it has them, with a box beside each. „Add
/// parts from a tutorial…" asks it about somebody else's tutorial and „Take
/// parts into a new tutorial…" about the open one; only the heading, the
/// button and the name field differ.
///
/// It decides nothing about the parts themselves. It is handed labels —
/// `TutorialSection.label`, the same name the contents panel shows — and
/// answers with indices into the list it was given.
library;

import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// What the trainer chose. [name] is empty unless the dialog asked for one.
typedef PartChoice = ({List<int> indices, String name});

/// Shows [labels] with a box beside each, and answers null when the trainer
/// backed out.
///
/// [nameLabel] turns the name field on; without it the dialog is only a
/// chooser. [confirmLabel] is the button, written as the thing it does rather
/// than „OK", so the trainer reads what will happen before it happens.
Future<PartChoice?> showPartPickerDialog(
  BuildContext context, {
  required String title,
  required List<String> labels,
  required String confirmLabel,
  String? subtitle,
  String? nameLabel,
  String initialName = '',
}) {
  return showDialog<PartChoice>(
    context: context,
    builder: (ctx) => _PartPickerDialog(
      title: title,
      labels: labels,
      confirmLabel: confirmLabel,
      subtitle: subtitle,
      nameLabel: nameLabel,
      initialName: initialName,
    ),
  );
}

class _PartPickerDialog extends StatefulWidget {
  const _PartPickerDialog({
    required this.title,
    required this.labels,
    required this.confirmLabel,
    this.subtitle,
    this.nameLabel,
    this.initialName = '',
  });

  final String title;
  final List<String> labels;
  final String confirmLabel;
  final String? subtitle;
  final String? nameLabel;
  final String initialName;

  @override
  State<_PartPickerDialog> createState() => _PartPickerDialogState();
}

class _PartPickerDialogState extends State<_PartPickerDialog> {
  /// Everything ticked to begin with. A trainer who reached for „add parts
  /// from a tutorial" usually wants the tutorial; unticking three is less work
  /// than ticking eleven, and an empty list would put the button out of reach
  /// on the way in, which reads as a broken dialog rather than as a choice.
  late final Set<int> _chosen = {
    for (var i = 0; i < widget.labels.length; i++) i,
  };

  late final TextEditingController _name =
      TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _asksName => widget.nameLabel != null;

  /// Nothing ticked is nothing to do; a name field left empty is a tutorial
  /// with no name, which the server refuses — better the button says so by
  /// being out of reach than a refusal after the work.
  bool get _canConfirm =>
      _chosen.isNotEmpty && (!_asksName || _name.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final all = _chosen.length == widget.labels.length;

    return AlertDialog(
      title: Text(widget.title,
          style: AppText.title.copyWith(color: colors.textPrimary)),
      content: SizedBox(
        // Wide enough for a part named by its first sentence, and capped so the
        // dialog does not run to the edge of a desktop window.
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.subtitle != null) ...[
              Text(widget.subtitle!,
                  style: AppText.caption.copyWith(color: colors.textSecondary)),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (_asksName) ...[
              TextField(
                key: const Key('part-picker-name'),
                controller: _name,
                autofocus: true,
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  labelText: widget.nameLabel,
                  filled: true,
                  fillColor: colors.canvas,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _chosen.length == 1
                      ? '1 part chosen'
                      : '${_chosen.length} parts chosen',
                  style: AppText.caption.copyWith(color: colors.textSecondary),
                ),
                TextButton(
                  key: const Key('part-picker-all'),
                  onPressed: () => setState(() {
                    if (all) {
                      _chosen.clear();
                    } else {
                      _chosen.addAll([
                        for (var i = 0; i < widget.labels.length; i++) i,
                      ]);
                    }
                  }),
                  child: Text(all ? 'None' : 'All'),
                ),
              ],
            ),
            // Bounded, and scrolling: a tutorial with twenty parts must not
            // grow a dialog taller than the window it is drawn in.
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.labels.length,
                itemBuilder: (_, i) => CheckboxListTile(
                  key: Key('part-picker-$i'),
                  dense: true,
                  value: _chosen.contains(i),
                  title: Text(
                    '${i + 1}. ${widget.labels[i]}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body.copyWith(color: colors.textPrimary),
                  ),
                  onChanged: (on) => setState(() {
                    if (on == true) {
                      _chosen.add(i);
                    } else {
                      _chosen.remove(i);
                    }
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const Key('part-picker-confirm'),
          onPressed: _canConfirm
              ? () => Navigator.pop<PartChoice>(
                    context,
                    (
                      indices: (_chosen.toList()..sort()),
                      name: _name.text.trim(),
                    ),
                  )
              : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
