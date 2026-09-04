import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/widgets/app_feedback.dart';

/// The three widths, named once.
///
/// The labels the reader chooses between, so a screen that has to say which
/// width it is drawing at says the same three words the dialog offered rather
/// than a fourth wording of its own. (`RepertoireTreePanel` keeps a lowercase
/// in-sentence form for its legend — same three, different register, and a
/// live verification item quotes it word for word.)
const Map<String, String> kBreadthNames = {
  'main': 'Samo glavna linija',
  'standard': 'Standardno (80%)',
  'broad': 'Široko (95%)',
};

/// The width's name, or the key itself when it is one this build does not know.
///
/// Never a guess and never a default: a width the app cannot name is a width
/// somebody added on the server, and printing the key says so.
String breadthName(String? breadth) =>
    kBreadthNames[breadth] ?? (breadth ?? 'nepoznata širina');

class BreadthDialog extends StatefulWidget {
  const BreadthDialog({
    super.key,
    required this.id,
    required this.api,
    this.current,
  });

  final int? id;
  final RepertoireApiService? api;

  /// The width this repertoire is already set to.
  ///
  /// Without it the dialog opened on `standard` every time, so a repertoire set
  /// to `main` was quietly reset to 80% by anybody who opened the dialog and
  /// picked a depth — a setting changed by a screen nobody asked to change it.
  final String? current;

  @override
  State<BreadthDialog> createState() => _BreadthDialogState();
}

class _BreadthDialogState extends State<BreadthDialog> {
  late String _selectedWidth = widget.current ?? 'standard';
  bool _saving = false;

  /// Both halves of the answer, not only the depth.
  ///
  /// The width was written to the row and the screen went on reading at the
  /// server's default, so a repertoire set to `main` kept drawing the 80%
  /// picture until it was next opened from the list. The caller needs to know
  /// what was chosen, here and now.
  Future<void> _saveAndReturn(int depth) async {
    if (widget.id == null) {
      Navigator.of(context).pop((depth: depth, breadth: _selectedWidth));
      return;
    }

    setState(() => _saving = true);
    final api = widget.api ?? RepertoireApiService();
    final done = await api.setBreadth(id: widget.id!, breadth: _selectedWidth);
    if (!mounted) return;

    if (done) {
      Navigator.of(context).pop((depth: depth, breadth: _selectedWidth));
    } else {
      setState(() => _saving = false);
      AppFeedback.error(context, 'Nije sačuvano — server nije odgovorio.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.id == null;

    return AlertDialog(
      title: const Text('Napravi kičmu odavde'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upisuje najigraniji potez za obe strane, koliko poteza kažete. '
              'To su predlozi, ne vaše odluke — vežba ih neće pitati dok ih ne '
              'potvrdite. Staje ranije ako linija postane retka.',
              style: AppText.caption.copyWith(color: context.colors.textMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Širina repertoara', style: AppText.bodyBold),
            // Whose width this is, said before it is changed.
            //
            // Reported live 4.9.2026: „napravim kičmu iz pozicije koja nije na
            // glavnoj liniji, izaberem samo glavna linija, aplikacija ne
            // napravi ispod te pozicije nove, već se nešto vraća." It did make
            // them — they are in the graph — and then this dial narrowed the
            // whole repertoire to one reply a position, so the branch the
            // reader was standing in fell out of the picture and took the new
            // line with it.
            //
            // The sentence is the fix because the misreading is reasonable:
            // this is a dialog titled „Napravi kičmu odavde", so a width in it
            // reads as the width *of the kičma*. It is not — the spine is one
            // line whatever this says, and this dial belongs to the whole
            // repertoire and stays after the spine is written.
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text(
                'Ovo je širina celog repertoara, ne širina kičme — kičma je '
                'uvek jedna linija. Uža širina sakriva grane koje ste već '
                'pripremili.',
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (disabled)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Text(
                  'Ova opcija nije dostupna (nedostaje ID repertoara).',
                  style: AppText.caption.copyWith(color: context.colors.danger),
                ),
              ),
            // RadioGroup rather than a groupValue on each tile: the per-tile
            // groupValue and onChanged were deprecated after Flutter 3.32, and
            // this project's analyze gate compares a list rather than an exit
            // code, so a deprecation is a new info and a new info is a
            // failure.
            // AbsorbPointer rather than a null onChanged: RadioGroup takes a
            // non-nullable ValueChanged, so "disabled" has to be expressed by
            // not letting the taps arrive. The sentence above already says
            // why it is unavailable, so nothing here is silent.
            AbsorbPointer(
              absorbing: disabled || _saving,
              child: RadioGroup<String>(
                groupValue: _selectedWidth,
                onChanged: (v) => setState(() => _selectedWidth = v!),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final entry in kBreadthNames.entries)
                      RadioListTile<String>(
                        value: entry.key,
                        title: Text(entry.value),
                        dense: true,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Dubina', style: AppText.bodyBold),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final option in const [4, 6, 8, 10, 12])
                  ActionChip(
                    label: Text('$option poteza'),
                    onPressed: _saving ? null : () => _saveAndReturn(option),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
      ],
    );
  }
}
