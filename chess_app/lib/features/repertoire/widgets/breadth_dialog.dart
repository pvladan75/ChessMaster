import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/widgets/app_feedback.dart';

class BreadthDialog extends StatefulWidget {
  const BreadthDialog({
    super.key,
    required this.id,
    required this.api,
  });

  final int? id;
  final RepertoireApiService? api;

  @override
  State<BreadthDialog> createState() => _BreadthDialogState();
}

class _BreadthDialogState extends State<BreadthDialog> {
  String _selectedWidth = 'standard';
  bool _saving = false;

  Future<void> _saveAndReturn(int depth) async {
    if (widget.id == null) {
      Navigator.of(context).pop(depth);
      return;
    }

    setState(() => _saving = true);
    final api = widget.api ?? RepertoireApiService();
    final done = await api.setBreadth(id: widget.id!, breadth: _selectedWidth);
    if (!mounted) return;

    if (done) {
      Navigator.of(context).pop(depth);
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
            Text('Širina', style: AppText.bodyBold),
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
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<String>(
                      value: 'main',
                      title: Text('Samo glavna linija'),
                      dense: true,
                    ),
                    RadioListTile<String>(
                      value: 'standard',
                      title: Text('Standardno (80%)'),
                      dense: true,
                    ),
                    RadioListTile<String>(
                      value: 'broad',
                      title: Text('Široko (95%)'),
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
