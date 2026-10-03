import 'package:flutter/material.dart';

import 'package:chess_app/services/account_standing_service.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/theme/app_colors.dart';

/// The word an account without a password types. The server checks the same
/// word (`services/accountDeletion.js`, `CONFIRM_WORD`).
const String deleteAccountWord = 'DELETE';

/// Confirms, and then deletes, the signed-in account — for good.
///
/// The owner's decisions of 3.10.2026: the account's own password confirms
/// it, or the typed word where there is no password (an account made through
/// Google); it happens at once; and the server removes the files with the
/// rows. So this dialog is the last place anything can be stopped, and it
/// says what goes before it asks.
///
/// Which field is drawn is the **server's** answer
/// ([AccountStanding.deletionAsksPassword]), never a guess: while the standing
/// is unknown nothing can be confirmed, and the dialog says the server could
/// not be reached rather than offering a field the server would refuse.
///
/// Once the server says it is gone the dialog closes and the session ends
/// through [SessionService.expire], which is what takes the app to the
/// sign-in screen and forgets the address and password kept on this device.
Future<void> showDeleteAccountDialog(
  BuildContext context, {
  AccountStandingService? standing,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _DeleteAccountDialog(standing: standing),
  );
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({this.standing});

  final AccountStandingService? standing;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final TextEditingController _proof = TextEditingController();
  bool _asking = true;
  bool _deleting = false;
  String? _error;

  AccountStandingService get _standing =>
      widget.standing ?? AccountStandingService.instance;

  @override
  void initState() {
    super.initState();
    _proof.addListener(() => setState(() {}));
    _ask();
  }

  @override
  void dispose() {
    _proof.dispose();
    super.dispose();
  }

  /// Asked every time the dialog opens, not read from what Settings already
  /// holds: the answer decides what is sent, and a standing fetched at app
  /// start is from before a password could have changed.
  Future<void> _ask() async {
    await _standing.refresh();
    if (!mounted) return;
    setState(() => _asking = false);
  }

  bool get _asksPassword => _standing.current?.deletionAsksPassword ?? true;

  bool get _proven =>
      _asksPassword ? _proof.text.isNotEmpty : _proof.text == deleteAccountWord;

  bool get _canDelete => !_asking && !_deleting && _proven;

  Future<void> _delete() async {
    // The lock is here and not only in the button: Enter in the field calls
    // this too, and two requests would have the second one answered „account
    // does not exist" over a deletion that worked.
    if (!_canDelete) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    final error = await _standing.deleteAccount(
      password: _asksPassword ? _proof.text : null,
      confirmWord: _asksPassword ? null : _proof.text,
    );
    if (error != null) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = error;
      });
      return;
    }
    // Gone on the server. The dialog leaves first, then the session ends —
    // and the session ends whether or not the dialog was still there to
    // close: a device that kept a token for a deleted account would be told
    // „account no longer exists" by its next request instead.
    if (mounted) Navigator.of(context).pop();
    _standing.forget();
    await SessionService.instance
        .expire(reason: SessionService.accountDeletedReason);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unreachable = !_asking && _standing.current == null;
    return AlertDialog(
      title: const Text('Delete account'),
      // Scrolls, because the keyboard takes half of a phone and the field
      // must stay reachable above it.
      scrollable: true,
      content: SizedBox(
        width: (MediaQuery.of(context).size.width - 112).clamp(220.0, 400.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This deletes your account and everything in it: your '
              'tutorials and their videos, your recordings and their sound, '
              'your exercises, games, repertoires, homework and progress. '
              'What you sent to other users goes with it.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('This cannot be undone.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.lg),
            if (_asking)
              const Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (unreachable)
              Text(
                'The server could not be reached, so nothing can be deleted '
                'now. Try again later.',
                key: const Key('delete-account-unreachable'),
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.error),
              )
            else
              TextField(
                key: const Key('delete-account-proof'),
                controller: _proof,
                autofocus: true,
                enabled: !_deleting,
                obscureText: _asksPassword,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: _asksPassword
                      ? 'Your password'
                      : 'Type $deleteAccountWord to confirm',
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _delete(),
              ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                key: const Key('delete-account-error'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('delete-account-confirm'),
          style: FilledButton.styleFrom(
              backgroundColor: context.colors.danger,
              foregroundColor: context.colors.canvas),
          onPressed: _canDelete ? _delete : null,
          child: _deleting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Delete account'),
        ),
      ],
    );
  }
}
