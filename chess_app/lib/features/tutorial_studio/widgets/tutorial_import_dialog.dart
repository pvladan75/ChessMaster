/// What was in the files, before anything is opened or written.
///
/// The import has two doors and this dialog is the one place both are drawn:
/// **open it** — one file, into the studio, unsaved, which is the flow a
/// trainer checking a tutorial wants — and **save them** — several files
/// straight into the library, which is the flow somebody who has just generated
/// a dozen wants. What makes both safe is the same report, shown before either.
///
/// It is worth a screen rather than a `SnackBar` because the faults are per
/// part and a trainer cannot act on „3 problems": the sentences name the part
/// and say what is wrong with it, and the studio is where they are fixed.
library;

import 'package:flutter/material.dart';

import 'package:chess_app/features/lessons/models/lesson_labels.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_import.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// What the trainer asked for.
sealed class TutorialImportChoice {
  const TutorialImportChoice();
}

/// One file, into the studio, saved by nothing but the trainer's own press of
/// „Save tutorial".
class ImportChoiceOpen extends TutorialImportChoice {
  const ImportChoiceOpen(this.tutorial);
  final ImportedTutorial tutorial;
}

/// Every file that can be stored, written to the library now.
class ImportChoiceSave extends TutorialImportChoice {
  const ImportChoiceSave(this.tutorials);
  final List<ImportedTutorial> tutorials;
}

/// Shows what was read and asks what to do with it.
///
/// Answers null when the trainer backed out. The tutorials carried by the
/// answer already have the labels typed here — the labels are applied at this
/// one point rather than by each caller, so the two doors cannot disagree about
/// them.
Future<TutorialImportChoice?> showTutorialImportDialog(
  BuildContext context,
  List<ImportedTutorial> read,
) {
  return showDialog<TutorialImportChoice>(
    context: context,
    builder: (ctx) => _TutorialImportDialog(read: read),
  );
}

class _TutorialImportDialog extends StatefulWidget {
  const _TutorialImportDialog({required this.read});

  final List<ImportedTutorial> read;

  @override
  State<_TutorialImportDialog> createState() => _TutorialImportDialogState();
}

class _TutorialImportDialogState extends State<_TutorialImportDialog> {
  final TextEditingController _labels = TextEditingController();

  @override
  void dispose() {
    _labels.dispose();
    super.dispose();
  }

  List<String> get _typedLabels => normaliseLabels(_labels.text.split(','));

  ImportedTutorial _labelled(ImportedTutorial t) =>
      _typedLabels.isEmpty ? t : t.withLabels(_typedLabels);

  List<ImportedTutorial> get _storable =>
      widget.read.where((t) => t.storable).toList();

  bool get _single => widget.read.length == 1;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final storable = _storable;
    final refused = widget.read.length - storable.length;

    return AlertDialog(
      title: Text(_single ? 'Import tutorial' : 'Import tutorials'),
      content: SizedBox(
        // Wide enough for a sentence about a part, and never wider than the
        // phone it is drawn on: a fixed 360 on a 360 dp screen is one of the
        // overflows this project has already paid for.
        width: 460,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _summary(storable.length, refused),
                style: AppText.body.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Flexible(
                fit: FlexFit.loose,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.read.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) => _fileTile(widget.read[i]),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                key: const Key('import-labels'),
                controller: _labels,
                decoration: InputDecoration(
                  labelText: 'Labels, separated by commas',
                  helperText: _single
                      ? 'Used to filter the saved tutorials list'
                      : 'Given to every tutorial imported here',
                ),
                // The buttons below say how many will be saved and nothing
                // about the labels, so nothing needs redrawing as this is
                // typed. The text is read when one of them is pressed.
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_single && widget.read.single.openable)
          FilledButton(
            key: const Key('import-open'),
            onPressed: () => Navigator.of(context).pop(
              ImportChoiceOpen(_labelled(widget.read.single)),
            ),
            child: const Text('Open for editing'),
          ),
        if (!_single && storable.isNotEmpty)
          FilledButton(
            key: const Key('import-save'),
            onPressed: () => Navigator.of(context).pop(
              ImportChoiceSave([for (final t in storable) _labelled(t)]),
            ),
            child: Text('Save ${storable.length} to the library'),
          ),
      ],
    );
  }

  /// The one line above the list, and the only place the two numbers meet.
  String _summary(int storable, int refused) {
    if (widget.read.isEmpty) return 'No files were read.';
    if (_single) {
      final one = widget.read.single;
      if (!one.openable) return 'This file could not be read.';
      if (one.clean) {
        return '${one.partCount} ${one.partCount == 1 ? 'part' : 'parts'}, '
            'nothing wrong with it.';
      }
      return '${one.partCount} ${one.partCount == 1 ? 'part' : 'parts'}. '
          'Open it and fix what is listed below — it is not saved until you '
          'press "Save tutorial" there.';
    }
    // Three numbers, and the middle one is the one that gets lost: a file can
    // be *stored* and still be wrong, because the server has no PGN reader and
    // takes a line that does not replay without complaint. Saying only „6 of 8
    // can be saved" would hide the four that will be saved damaged.
    final damaged = widget.read.where((t) => t.storable && !t.clean).length;
    final flawed = damaged == 0
        ? ''
        : ' $damaged of them ${damaged == 1 ? 'has a fault' : 'have faults'} '
            'listed below and would be saved as ${damaged == 1 ? 'it is' : 'they are'}.';
    if (refused == 0) {
      return '$storable files.'
          '${damaged == 0 ? ' Nothing wrong with any of them.' : flawed}';
    }
    return '$storable of ${widget.read.length} files can be saved.$flawed '
        'The rest are listed below with the reason.';
  }

  Widget _fileTile(ImportedTutorial tutorial) {
    final colors = context.colors;
    final (icon, colour) = switch (tutorial) {
      final t when !t.storable => (Icons.error_outline, colors.danger),
      final t when !t.clean => (Icons.warning_amber, colors.warning),
      _ => (Icons.check_circle_outline, colors.success),
    };

    return ListTile(
      dense: true,
      leading: Icon(icon, color: colour, size: 20),
      title: Text(
        tutorial.title.isEmpty
            ? (tutorial.fileName ?? 'Unnamed file')
            : tutorial.title,
        style: AppText.body.copyWith(color: colors.textPrimary),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tutorial.openable)
            Text(
              '${tutorial.partCount} '
              '${tutorial.partCount == 1 ? 'part' : 'parts'}'
              '${tutorial.tags.isEmpty ? '' : ' · ${tutorial.tags.join(', ')}'}',
              style: AppText.caption.copyWith(color: colors.textSecondary),
            ),
          for (final problem in tutorial.problems)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                problem.sentence,
                style: AppText.caption.copyWith(
                  color: problem.fault == ImportFault.refused
                      ? colors.danger
                      : colors.warning,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
