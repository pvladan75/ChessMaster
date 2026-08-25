import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:chess_app/services/account_standing_service.dart';
import 'package:chess_app/services/session_service.dart';

/// Stands between a signed-in account and the rest of the app until the year
/// of birth has been stated once.
///
/// **It wraps the app rather than sitting at the end of registration.** Signing
/// up is not the only way to get an account here — Google sign-in makes one
/// without ever passing through the register form, and every account that
/// already exists never passed through it either. A question asked only at
/// registration is a question almost nobody is asked, which is this codebase's
/// recurring failure wearing a friendly face: the rule looks implemented and
/// quietly applies to nobody.
///
/// It draws *over* what is underneath instead of replacing it, so an answer
/// that arrives while a lesson is open does not tear the lesson down.
class AgeGate extends StatefulWidget {
  const AgeGate({super.key, required this.child, this.standing});

  final Widget child;

  /// The service to watch. Injected for tests; the app passes nothing and gets
  /// the singleton the rest of the app reads.
  final AccountStandingService? standing;

  @override
  State<AgeGate> createState() => _AgeGateState();
}

class _AgeGateState extends State<AgeGate> {
  AccountStandingService get _standing =>
      widget.standing ?? AccountStandingService.instance;

  @override
  void initState() {
    super.initState();
    _standing.addListener(_onChanged);
    SessionService.instance.addListener(_onSessionChanged);
    _onSessionChanged();
  }

  @override
  void dispose() {
    _standing.removeListener(_onChanged);
    SessionService.instance.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  /// The one place that asks. Both ways into an account end here — the login
  /// form and Google sign-in both go through [SessionService], and a remembered
  /// token arrives the same way at startup — so no entrance can be forgotten
  /// the way the register form would have forgotten all of them.
  void _onSessionChanged() {
    if (SessionService.instance.isSignedIn) {
      if (_standing.current == null) unawaited(_standing.refresh());
    } else {
      _standing.forget();
    }
    _onChanged();
  }

  @override
  Widget build(BuildContext context) {
    // Not gating is the answer while the server has not spoken. "We have not
    // asked yet" is a third state, and folding it into either of the other two
    // would either lock out everybody whose backend is down or let through
    // exactly the accounts this is here for.
    if (!_standing.mustStateAge) return widget.child;

    return Stack(
      children: [
        // Covered, and out of the focus tree. Those are two different things,
        // and only the first one is free: an opaque layer on top of a `Stack`
        // stops pointers, but focus traversal happily reaches a sibling that
        // nobody can see. The app underneath is fully alive — it has text
        // fields and autofocus of its own — so it took the focus back a frame
        // after the gate appeared, and every keystroke after the first went to
        // a screen the user could not see. The field looked frozen on whatever
        // had been typed before that.
        ExcludeFocus(child: widget.child),
        // Its own scope, so what is focused here is decided here and cannot be
        // handed back down to the tree above.
        Positioned.fill(
          child: FocusScope(
            autofocus: true,
            child: BirthYearScreen(standing: _standing),
          ),
        ),
      ],
    );
  }
}

/// The question itself: one year, and what it is for.
///
/// Also reachable from Settings, where it can be cancelled — somebody who
/// mistyped 1997 as 2017 must be able to correct a field they can otherwise
/// never reach again.
class BirthYearScreen extends StatefulWidget {
  const BirthYearScreen({super.key, this.standing, this.canCancel = false});

  final AccountStandingService? standing;

  /// Whether there is a way out without answering. False for the gate, true
  /// when the screen is opened to correct an answer that already exists.
  final bool canCancel;

  @override
  State<BirthYearScreen> createState() => _BirthYearScreenState();
}

class _BirthYearScreenState extends State<BirthYearScreen> {
  final TextEditingController _year = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _saving = false;
  String? _error;

  AccountStandingService get _standing =>
      widget.standing ?? AccountStandingService.instance;

  @override
  void initState() {
    super.initState();
    final known = _standing.current?.birthYear;
    if (known != null) _year.text = '$known';
    _focus.addListener(_selectAllOnFocus);
  }

  /// Coming back to the field offers the whole year, not a cursor at its end.
  ///
  /// Four digits with a length limit on them is a field that silently ignores
  /// typing once it is full, which reads as a field that cannot be changed.
  /// Selecting the year means typing replaces it, which is the only thing
  /// anybody wants to do here. A tap that lands mid-text still wins, because
  /// the tap sets its own selection after focus is granted.
  void _selectAllOnFocus() {
    if (!_focus.hasFocus || _year.text.isEmpty) return;
    _year.selection =
        TextSelection(baseOffset: 0, extentOffset: _year.text.length);
  }

  @override
  void dispose() {
    _focus.removeListener(_selectAllOnFocus);
    _focus.dispose();
    _year.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final thisYear = DateTime.now().year;
    final value = int.tryParse(_year.text.trim());
    if (value == null || value < 1900 || value > thisYear) {
      setState(
        () => _error = 'Unesite godinu rođenja, između 1900. i $thisYear.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await _standing.stateBirthYear(value);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = error;
    });
    // Only a saved year closes this. A failed save that closed the screen
    // anyway would leave the account in exactly the state the gate exists to
    // end, and would look identical to success.
    if (error == null && widget.canCancel && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final threshold = _standing.current?.ageOfConsent;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              // Taken from the screen rather than fixed: a fixed 360 is exactly
              // the width of the phone this is read on, and a release build
              // paints no overflow warning.
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width.clamp(0.0, 420.0),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.cake_outlined,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Godina rođenja',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Pitamo samo godinu, ne i datum — to je jedno polje manje '
                    'o vama, a odgovara na jedino pitanje koje nam treba.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    threshold == null
                        ? 'Od nje zavisi da li je za nalog potrebna saglasnost '
                            'roditelja.'
                        : 'Za mlađe od $threshold godina potrebna je saglasnost '
                            'roditelja.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _year,
                    focusNode: _focus,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                    decoration: const InputDecoration(
                      labelText: 'Godina rođenja',
                      hintText: 'npr. 2014',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _saving ? null : _save(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sačuvaj'),
                  ),
                  const SizedBox(height: 8),
                  if (widget.canCancel)
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Odustani'),
                    )
                  else
                    // The only way out of the gate, and it has to exist: a
                    // wrong account otherwise traps whoever is holding the
                    // phone on a screen with no other door.
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () async {
                              await SessionService.instance.signOut();
                              _standing.forget();
                            },
                      child: const Text('Odjavi se'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
