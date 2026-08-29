import 'package:flutter/material.dart';

import 'package:chess_app/services/account_standing_service.dart';
import 'package:chess_app/theme/app_spacing.dart';

/// Asks for the address a parent will be written to.
///
/// It is asked of the child rather than of the trainer on purpose: it is the
/// child's account, and a consent letter sent to an address the trainer was
/// told over the phone is the one failure in this flow that looks exactly like
/// success — a parent who never got it and a parent who has not answered are
/// the same thing from every screen.
///
/// Saving it also sends whatever was waiting on it. The server does that, so
/// the letter goes out no matter which screen the address was typed into.
Future<bool?> showParentEmailDialog(
  BuildContext context, {
  AccountStandingService? standing,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _ParentEmailDialog(standing: standing),
  );
}

class _ParentEmailDialog extends StatefulWidget {
  const _ParentEmailDialog({this.standing});

  final AccountStandingService? standing;

  @override
  State<_ParentEmailDialog> createState() => _ParentEmailDialogState();
}

class _ParentEmailDialogState extends State<_ParentEmailDialog> {
  // Owned by the dialog's own State rather than created around `showDialog`.
  // A controller disposed when the dialog closes dies while the dialog is still
  // animating out, and the field is painted one frame later over a dead one.
  final TextEditingController _email = TextEditingController();
  bool _saving = false;
  String? _error;

  AccountStandingService get _standing =>
      widget.standing ?? AccountStandingService.instance;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _email.text.trim();
    if (value.isEmpty || !value.contains('@') || !value.contains('.')) {
      setState(() => _error = 'Unesite ispravnu email adresu roditelja.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await _standing.setParentEmail(value);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    // Closed only on a saved address. A dialog that closed either way would
    // look the same whether the letter went out or nothing happened at all.
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Email roditelja'),
      content: SizedBox(
        // A firm width, because an AlertDialog wraps its content in
        // IntrinsicWidth and a lazy list inside one without it throws instead
        // of laying out. Taken from the screen rather than written as 360: on a
        // 360 dp phone a fixed 360 is wider than the dialog can be, and a
        // release build paints no overflow warning — it simply clips.
        width: (MediaQuery.of(context).size.width - 112).clamp(220.0, 360.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Da bi trener mogao da radi sa vama, roditelj mora da potvrdi '
              'saglasnost. Na ovu adresu šaljemo poruku sa linkom na kom se '
              'saglasnost daje.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Adresa se koristi samo za to i ne prikazuje se drugim '
              'korisnicima.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _email,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email roditelja',
                hintText: 'roditelj@primer.rs',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _saving ? null : _save(),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Pošalji'),
        ),
      ],
    );
  }
}
