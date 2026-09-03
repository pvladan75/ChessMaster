import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/services/opening_book_service.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/features/repertoire/widgets/repertoire_gate_picker.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';

class ForkRepertoireDialog extends StatefulWidget {
  const ForkRepertoireDialog({
    super.key,
    required this.color,
    required this.rootFen,
    required this.rootPath,
    required this.api,
    this.openingBook,
  });

  final String color;
  final String rootFen;
  final List<String> rootPath;
  final RepertoireApiService api;
  final OpeningBookService? openingBook;

  @override
  State<ForkRepertoireDialog> createState() => _ForkRepertoireDialogState();
}

class _ForkRepertoireDialogState extends State<ForkRepertoireDialog> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  String? _viaUci;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final book = widget.openingBook ?? OpeningBookService.instance;
    final entry = book.lookupByFen(widget.rootFen);
    if (entry != null) {
      _nameController.text = '${entry.eco} · ${entry.name}';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _pickGate() async {
    final picked = await showGatePicker(
      context,
      rootFen: widget.rootFen,
      current: _viaUci,
    );
    if (!mounted || picked == null) return;
    setState(() => _viaUci = picked.isEmpty ? null : picked);
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _busy = true);

    final ({RepertoireSummary? made, String? error}) result =
        await widget.api.create(
      name: name,
      color: widget.color,
      rootFen: widget.rootFen,
      rootPath: widget.rootPath,
      viaUci: _viaUci,
    );

    if (!mounted) return;
    setState(() => _busy = false);

    if (result.error != null) {
      AppFeedback.error(context, result.error!);
      return;
    }

    AppFeedback.success(context, 'Otvaranje uspešno izdvojeno.');
    Navigator.pop(context, result.made);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.roundedLg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Izdvoji u novo otvaranje',
                style:
                    AppText.title.copyWith(color: context.colors.textPrimary)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Ova pozicija postaje početak novog otvaranja. '
              'Potezi se ne kopiraju — sve što ste igrali ovde ostaje sačuvano i vidljivo iz novog otvaranja.',
              style: AppText.body.copyWith(color: context.colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xxl),
            TextField(
              controller: _nameController,
              focusNode: _nameFocus,
              style: AppText.body.copyWith(color: context.colors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Ime otvaranja',
                labelStyle:
                    AppText.body.copyWith(color: context.colors.textMuted),
                border: OutlineInputBorder(
                  borderRadius: AppRadii.roundedSm,
                  borderSide: BorderSide(color: context.colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadii.roundedSm,
                  borderSide: BorderSide(color: context.colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadii.roundedSm,
                  borderSide: BorderSide(color: context.colors.borderStrong),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.lg),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Kroz koji potez ide?',
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.textPrimary)),
              subtitle: Text(
                _viaUci == null ? 'Bez ograničenja' : 'Kroz potez $_viaUci',
                style: AppText.body.copyWith(color: context.colors.textMuted),
              ),
              trailing: Icon(Icons.chevron_right,
                  color: context.colors.textSecondary),
              onTap: _pickGate,
            ),
            const SizedBox(height: AppSpacing.xxl),
            // `Wrap`, not `Row`: two buttons and a dialog 280 dp wide fit on
            // most phones and not on all of them, and a release build paints
            // no overflow stripes — it simply clips whatever is past the edge,
            // which here would be the button the dialog exists for.
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Odustani'),
                ),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Izdvoji'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
