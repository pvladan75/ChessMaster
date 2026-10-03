import 'package:chess_app/theme/app_typography.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:chess_app/constants.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/models/pending_session_intent.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/services/saved_sign_ins.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/services/desktop_google_sign_in.dart';
import 'package:chess_app/services/oauth_pkce.dart' show OAuthRedirectException;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';
import 'package:chess_app/theme/app_colors.dart';

class LoginRegisterScreen extends StatefulWidget {
  /// The login-gated action (create/join a room, invite a student...) that
  /// sent the user here, if any — resumed automatically by HomeScreen once
  /// signing in succeeds. See home_screen.dart's `_checkAuthRequired`.
  final PendingSessionIntent? pendingIntent;

  /// Overrides whether the Google block is offered.
  ///
  /// Only tests pass it. What it stands in for is a compile-time constant —
  /// whether this build was given a desktop OAuth client — and a test cannot
  /// change one of those, so without a seam here the two states of this screen
  /// could only ever be seen by rebuilding the app.
  @visibleForTesting
  final bool? googleAvailableOverride;

  /// From this width the screen is two halves — the brand on the left, the
  /// form on the right (`docs/PLAN-PRIJAVA-I-PODESAVANJA.md`, D1 B).
  ///
  /// Read from the width this screen is given, never the window, and set so
  /// the smallest Windows window (900, `windows/runner/win32_window.cpp`)
  /// gets the panel while a phone on its side (760 × 360) keeps today's
  /// screen. At 880 each half is 440, and the form keeps at least 392 of it.
  static const double panelFromWidth = 880;

  /// The form is never wider than this, however wide its half.
  static const double formMaxWidth = 440;

  const LoginRegisterScreen({
    super.key,
    this.pendingIntent,
    this.googleAvailableOverride,
  });

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  late final Future<void> _googleSignInInit = _googleSignIn.initialize(
    clientId:
        (kIsWeb && googleWebClientId.isNotEmpty) ? googleWebClientId : null,
    serverClientId: googleWebClientId.isNotEmpty ? googleWebClientId : null,
  );

  bool _isLogin = true;
  bool _isAwaitingVerification = false;
  bool _isLoading = false;
  bool _rememberMe = true;

  /// The address whose kept password the password field was filled with,
  /// for as long as what is in the field grew from it — that is, until the
  /// field has been emptied. Null when the field holds only what the person
  /// typed.
  ///
  /// Three rules hang on it. The eye stays locked, so editing one character
  /// is not a way to read a kept password. Changing the address empties the
  /// field, so a kept password is never sent with an address it was not kept
  /// for. And a refusal forgets the kept password only when what was sent
  /// was that password, unchanged.
  String? _filledFrom;

  /// Whether the eye was last set to show the password. What is drawn also
  /// asks [_filledFrom]: a kept password is never shown, whatever this says.
  bool _passwordVisible = false;

  final _passwordFocus = FocusNode();
  final _submitFocus = FocusNode();
  final _accountsMenu = MenuController();

  @override
  void initState() {
    super.initState();
    // The address from the last remembered sign-in, and — where this platform
    // keeps passwords (Windows Credential Manager; docs/PLAN-PRIJAVA-I-
    // PODESAVANJA.md) — the password kept for it. On Android the password is
    // the phone's own password manager's, reached through the autofill hints
    // below, and nothing is filled from here.
    final remembered = SavedSignIns.instance.last;
    if (remembered != null && remembered.isNotEmpty) {
      _emailController.text = remembered;
      _emailIsKnown = true;
      _putKept(remembered, SavedSignIns.instance.passwordFor(remembered));
    }

    // Why they are looking at this screen, when the app decided it rather than
    // they did. Without it the trip here is unexplained: the previous screen is
    // gone and nothing says the session ran out.
    final reason = SessionService.instance.expiryReason;
    if (reason != null) {
      _expiryNotice = switch (reason) {
        SessionService.accountDeletedReason => 'Your account has been deleted.',
        'account-gone' =>
          'This account no longer exists on the server. Sign in with another '
              'account.',
        _ => 'Session expired. Please sign in again.',
      };
      // After the frame, not during it: acknowledging notifies, the router
      // listens, and a router rebuilt in the middle of this build is how one
      // message becomes a loop.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SessionService.instance.acknowledgeExpiry();
      });
    }
  }

  /// The sentence explaining an arrival nobody asked for. Held in the screen
  /// rather than read from the service at build time, because the service is
  /// told to forget the reason as soon as this screen has shown it.
  String? _expiryNotice;

  /// Whether the address came back from the last sign-in, which decides where
  /// the caret starts: in the password when there is nothing to type above it,
  /// in the address otherwise. It also settles what the desktop's focus ring
  /// lands on — part of why the Google button read as the marked choice.
  bool _emailIsKnown = false;

  /// Whether this build can actually sign in with Google here.
  ///
  /// On Windows and Linux that depends on the desktop client being configured;
  /// the button used to be shown regardless and answered "nije podržan na ovoj
  /// platformi" after the tap, which is a dead end dressed as an option.
  bool get _googleAvailable =>
      widget.googleAvailableOverride ??
      (DesktopGoogleSignIn.isSupported
          ? DesktopGoogleSignIn.isConfigured
          : !(kIsWeb && googleWebClientId.isEmpty));

  static bool _sameAddress(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  /// Puts the [password] kept for [address] into the password field, or
  /// empties the field when [password] is null. The one place the app itself
  /// writes that field, so what is in it and [_filledFrom] cannot drift.
  void _putKept(String? address, String? password) {
    _passwordController.text = password ?? '';
    _filledFrom = password == null ? null : address?.trim();
  }

  /// The address field changed under the person's hands.
  ///
  /// A kept password belongs to one address: once the field names another,
  /// the password field is emptied, so a kept password — or one grown from
  /// it — is never sent with an address it was not kept for. And an address
  /// that has one kept fills it in, but only into an empty field — never
  /// over what the person typed.
  void _emailChanged(String text) {
    final from = _filledFrom;
    if (from != null && !_sameAddress(from, text)) _putKept(null, null);
    if (_filledFrom == null && _passwordController.text.isEmpty) {
      final password = SavedSignIns.instance.passwordFor(text);
      if (password != null) _putKept(text, password);
    }
    setState(() {});
  }

  /// The field is the person's own once they have emptied it; until then,
  /// whatever they changed in it grew from a kept password.
  void _passwordChanged(String value) {
    if (value.isEmpty && _filledFrom != null) {
      setState(() => _filledFrom = null);
    }
  }

  /// An address chosen from the remembered list, with its password if one is
  /// kept. The caret goes where the next keystroke is needed — the button
  /// when there is nothing left to type.
  void _chooseAddress(String address) {
    final password = SavedSignIns.instance.passwordFor(address);
    setState(() {
      _emailController.text = address;
      _putKept(address, password);
    });
    (password == null ? _passwordFocus : _submitFocus).requestFocus();
  }

  /// × in the remembered list: the address and its password leave this
  /// device. Done first, then said — and said honestly when the store would
  /// not let go.
  Future<void> _forgetAddress(String address) async {
    _accountsMenu.close();
    final gone = await SavedSignIns.instance.forget(address);
    if (!mounted) return;
    setState(() {
      final from = _filledFrom;
      if (from != null && _sameAddress(from, address)) _putKept(null, null);
    });
    if (gone) {
      AppFeedback.info(context, '$address is forgotten on this device.');
    } else {
      AppFeedback.warning(
          context,
          '$address is off the list, but its password could not be removed '
          'from ${SavedSignIns.instance.storeName}. Remove it there.');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final idToken = DesktopGoogleSignIn.isSupported
          ? await const DesktopGoogleSignIn()
              .obtainIdToken(loginHint: _emailController.text.trim())
          : await _pluginIdToken();
      if (idToken == null) return;

      // Only the token. The server reads the identity out of it — an address
      // sent beside it would be a second, unverified answer to the same
      // question, which is the bug this route was fixed for once already.
      final response = await http.post(
        Uri.parse('$backendUrl/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final session = UserSession.fromJson(data['user'], data['token']);
        await _saveSession(session);
        _navigateToHome(session);
      } else {
        try {
          final data = jsonDecode(response.body);
          _showError(data['error'] ?? 'Google sign-in failed.');
        } catch (_) {
          _showError(
              'Server error during Google sign-in (Status ${response.statusCode}).');
        }
      }
    } on OAuthRedirectException catch (e) {
      // Already a sentence for a person: cancelled, timed out, or refused.
      _showError(e.message);
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        _showError('Google Sign-In Error: ${e.description ?? e.code}');
      }
    } catch (e) {
      _showError('Google Sign-In Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// The plugin's path — Android, iOS, macOS and the web.
  ///
  /// Null means the platform said no and the message has already been shown:
  /// the caller has nothing left to do with it.
  Future<String?> _pluginIdToken() async {
    await _googleSignInInit;
    if (!_googleSignIn.supportsAuthenticate()) {
      _showError('Google sign-in is not supported on this platform.');
      return null;
    }

    final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
    final String? idToken = googleUser.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      _showError('Google did not return identity (id_token).');
      return null;
    }
    return idToken;
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    final email = _emailController.text.trim();
    if (email.isEmpty || code.isEmpty) {
      _showError('Enter your email and the 6-digit verification code.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/auth/verify-email'),
        headers: {'Content-Type': 'application/json'},
        // The password still in the form proves this is the registration the
        // code was mailed for: registering an unverified address again replaces
        // its password, and the server refuses a code whose password changed in
        // between. Empty when the code is typed in a later session, which the
        // server accepts.
        body: jsonEncode({
          'email': email,
          'code': code,
          if (_passwordController.text.isNotEmpty)
            'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final session = UserSession.fromJson(data['user'], data['token']);
        final keeping = await _saveSession(session,
            password: _passwordController.text.isEmpty
                ? null
                : _passwordController.text);
        _showSuccess('Email verified! Welcome.');
        _navigateToHome(session);
        _sayIfNotKept(keeping);
      } else {
        try {
          final data = jsonDecode(response.body);
          _showError(data['error'] ?? 'Verification failed.');
          // Nothing left to do on this screen: the account is verified and the
          // way in is a password or Google. Leaving the user in front of a code
          // field that can never work again is how a person concludes the app
          // is broken rather than that they are already done.
          if (data['alreadyVerified'] == true) {
            setState(() => _isAwaitingVerification = false);
          }
        } catch (_) {
          _showError('Verification error (Status ${response.statusCode}).');
        }
      }
    } catch (e) {
      _showError('Network error during code verification.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (_isAwaitingVerification) {
      await _verifyCode();
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // Whether what goes out is the password kept for this address,
        // unchanged: only that one is forgotten when it is refused. One the
        // person typed, or edited, is theirs to correct.
        final email = _emailController.text.trim();
        final from = _filledFrom;
        final sentKept = from != null &&
            _sameAddress(from, email) &&
            _passwordController.text ==
                SavedSignIns.instance.passwordFor(email);

        final response = await http.post(
          Uri.parse('$backendUrl/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'password': _passwordController.text,
          }),
        );

        final data = jsonDecode(response.body);
        if (response.statusCode == 200) {
          final session = UserSession.fromJson(data['user'], data['token']);
          final keeping =
              await _saveSession(session, password: _passwordController.text);
          _navigateToHome(session);
          _sayIfNotKept(keeping);
        } else if (data['requiresVerification'] == true) {
          setState(() {
            _isAwaitingVerification = true;
          });
          _showSuccess(data['error'] ??
              'Enter the verification code sent to your email.');
        } else if (response.statusCode == 400 && sentKept) {
          // The server refused the kept password itself — wrong, or an
          // account that signs in only with Google — so it is forgotten. Only
          // a 400 says that: too many attempts (429), a server fault or no
          // network say nothing about the password, and it stays.
          final gone = SavedSignIns.instance.forgetPassword(email);
          setState(() => _putKept(null, null));
          _passwordFocus.requestFocus();
          // The server's sentence has no full stop of its own.
          final said = '${data['error'] ?? 'Sign-in failed'}';
          final reason = said.endsWith('.') ? said : '$said.';
          _showError(gone
              ? '$reason The saved password did not work, so it has been '
                  'forgotten. Type it again.'
              : '$reason The saved password did not work, and it could not '
                  'be removed from ${SavedSignIns.instance.storeName}.');
        } else {
          _showError(data['error'] ?? 'Sign-in failed.');
        }
      } else {
        // Register API Call
        final response = await http.post(
          Uri.parse('$backendUrl/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': _emailController.text.trim(),
            'password': _passwordController.text,
            'name': _nameController.text.trim(),
          }),
        );

        final data = jsonDecode(response.body);
        if (response.statusCode == 201 ||
            data['requiresVerification'] == true) {
          setState(() {
            _isAwaitingVerification = true;
          });
          _showSuccess(data['message'] ??
              'Verification code generated! Enter the 6-digit code.');
        } else {
          _showError(data['error'] ?? 'Registration failed.');
        }
      }
    } catch (e) {
      _showError('Network error. Check connection to the server.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// [password] is the one the server has just accepted, null for Google.
  Future<PasswordKeeping> _saveSession(UserSession session,
      {String? password}) async {
    final keeping = await SessionService.instance
        .signIn(session, rememberMe: _rememberMe, password: password);
    // Tells the platform the sign-in went through, which is what makes
    // Android's password manager offer to save the password and, next time,
    // fill it. Windows has no such service for a desktop program — its engine
    // does not even receive this call — which is why a password is kept in
    // Credential Manager there instead (`SavedSignIns`).
    TextInput.finishAutofillContext();
    return keeping;
  }

  /// The sign-in has happened; this only reports that the password could not
  /// be kept, after the fact and through a helper that cannot throw.
  void _sayIfNotKept(PasswordKeeping keeping) {
    if (keeping != PasswordKeeping.failed) return;
    AppFeedback.warning(
        context,
        'Signed in, but the password could not be saved in '
        '${SavedSignIns.instance.storeName}. You will be asked for it next '
        'time.');
  }

  void _navigateToHome(UserSession session) {
    // go() rather than push(): after signing in there is nothing meaningful to
    // go "back" to, and the login screen should not stay on the stack.
    // A guest declining to log in must not silently run a login-gated action.
    context.go(AppRoutes.home,
        extra: session.isGuest ? null : widget.pendingIntent);
  }

  void _showError(String message) {
    AppFeedback.show(
      context,
      () => SnackBar(
        content: Text(message,
            style: AppText.body.copyWith(color: context.colors.canvas)),
        backgroundColor: context.colors.danger,
      ),
    );
  }

  void _showSuccess(String message) {
    AppFeedback.show(
      context,
      () => SnackBar(
        content: Text(message,
            style: AppText.body
                .copyWith(color: context.colors.onSuccessContainer)),
        backgroundColor: context.colors.successContainer,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _codeController.dispose();
    _passwordFocus.dispose();
    _submitFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth >= LoginRegisterScreen.panelFromWidth
              ? _buildWide(context)
              : _buildNarrow(context),
    );
  }

  String get _screenTitle => _isAwaitingVerification
      ? 'Email Verification'
      : (_isLogin ? 'Sign In' : 'Register');

  Widget _guestButton() => TextButton.icon(
        onPressed: () => _navigateToHome(UserSession.guest()),
        icon: const Icon(Icons.person_outline),
        label: const Text('Continue as Guest'),
      );

  /// A phone, and any window narrower than [panelFromWidth]: the screen as it
  /// was before the desktop layout — a bar with the title and the guest
  /// button, and the form in a card.
  Widget _buildNarrow(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitle),
        actions: [_guestButton()],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedLg),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: _buildForm(context, wide: false),
            ),
          ),
        ),
      ),
    );
  }

  /// A wide window: the brand panel on the left and the form on the right,
  /// with no bar and no card. The guest button sits in the form half's top
  /// right corner, where the bar had it; the form scrolls under it when the
  /// window is short, so it starts below it.
  Widget _buildWide(BuildContext context) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Expanded(child: _BrandPanel()),
          Expanded(
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.xxl,
                        AppSpacing.xxxl * 2, AppSpacing.xxl, AppSpacing.xxl),
                    child: ConstrainedBox(
                      key: const Key('sign-in-form'),
                      constraints: const BoxConstraints(
                          maxWidth: LoginRegisterScreen.formMaxWidth),
                      child: _buildForm(context, wide: true),
                    ),
                  ),
                ),
                Positioned(
                  top: AppSpacing.md,
                  right: AppSpacing.md,
                  child: _guestButton(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The form itself, the same on both layouts. Only its heading differs:
  /// on a wide window the trophy and the name are the panel's, so the form
  /// is headed by what the bar says on a phone.
  Widget _buildForm(BuildContext context, {required bool wide}) {
    return Form(
      key: _formKey,
      // One group, so the platform reads these fields as a single
      // sign-in rather than as unrelated boxes it has nothing to offer.
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (wide)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_screenTitle, style: AppText.headline),
              )
            else ...[
              Icon(
                _isAwaitingVerification
                    ? Icons.mark_email_unread
                    : Icons.emoji_events,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _isAwaitingVerification
                    ? 'Enter Verification Code'
                    : (_isLogin ? 'Mislisha' : 'Account Registration'),
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
            if (_expiryNotice != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colors.warning.withValues(alpha: 0.15),
                  borderRadius: AppRadii.roundedSm,
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_clock,
                        size: 18, color: context.colors.warning),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _expiryNotice!,
                        style: AppText.body
                            .copyWith(color: context.colors.warning),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            if (_isAwaitingVerification) ...[
              Text(
                // The spam line is not a nicety. The domain started sending on
                // 26.8.2026 and has no reputation yet, so Gmail files these under
                // junk - and a verification code nobody sees is a registration
                // nobody finishes. It comes out when the reputation is built.
                //
                // The developer note used to be shown to everybody, including a
                // parent registering a child.
                'A verification code has been sent to ${_emailController.text}.'
                '\nIf you do not see it in your inbox, please check your spam folder.'
                '${kDebugMode ? '\n(In dev environment, the code is printed in backend logs.)' : ''}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: context.colors.textMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Verification Code (6 digits)',
                  prefixIcon: Icon(Icons.pin),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                validator: (val) =>
                    val == null || val.length != 6 ? 'Enter 6 digits' : null,
              ),
              const SizedBox(height: AppSpacing.lg),
            ] else ...[
              // Google first, and above a divider. It is one tap, it
              // registers as well as signs in, and underneath the email
              // form it read as "press this one instead" to somebody
              // halfway through typing their address — reported live on
              // 27.8.2026. The two ways in are now two blocks with a
              // line between them, rather than three buttons in a row.
              if (_googleAvailable) ...[
                _buildGoogleBlock(context),
                const SizedBox(height: AppSpacing.xl),
                _buildOrDivider(context),
                const SizedBox(height: AppSpacing.xl),
              ],
              if (!_isLogin) ...[
                TextFormField(
                  controller: _nameController,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Enter name' : null,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              TextFormField(
                controller: _emailController,
                // The hints are what let the phone's or the desktop's
                // password manager offer the address and the password.
                // That is the honest version of "remember my password":
                // the app asks the platform, and never holds it itself.
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email),
                  suffixIcon: _rememberedAccounts(context),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                autofocus: _isLogin && !_emailIsKnown,
                onChanged: _emailChanged,
                validator: (value) => value == null || !value.contains('@')
                    ? 'Enter a valid email address'
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                autofillHints: [
                  _isLogin ? AutofillHints.password : AutofillHints.newPassword,
                ],
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: _visibilityButton(),
                  border: const OutlineInputBorder(),
                ),
                // Never shown while it grew from a kept password,
                // whatever the eye was last left at.
                obscureText: !_passwordVisible || _filledFrom != null,
                autofocus: _isLogin && _emailIsKnown && _filledFrom == null,
                onChanged: _passwordChanged,
                onFieldSubmitted: (_) => _submit(),
                validator: (value) => value == null || value.length < 6
                    ? 'Password must be at least 6 characters'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              CheckboxListTile(
                title:
                    const Text('Remember me', style: TextStyle(fontSize: 14)),
                // Said out loud, and said per platform, because the
                // box does different things: on Windows it keeps the
                // password too, and names where; elsewhere it keeps
                // the session, and the password is the phone's own
                // password manager's.
                subtitle: Text(
                  SavedSignIns.instance.keepsPasswords
                      ? 'Your email and password are kept in '
                          '${SavedSignIns.instance.storeName}, and '
                          'you stay signed in.'
                      : 'You stay signed in on this device.',
                  style: AppText.body,
                ),
                value: _rememberMe,
                activeColor: Theme.of(context).primaryColor,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  setState(() {
                    _rememberMe = val ?? false;
                  });
                },
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      // With a kept password there is nothing left
                      // to type, so Enter should sign in.
                      focusNode: _submitFocus,
                      autofocus: _isLogin && _filledFrom != null,
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadii.roundedSm,
                        ),
                      ),
                      child: Text(_isAwaitingVerification
                          ? 'Confirm Verification'
                          : (_isLogin
                              ? 'Sign in with email'
                              : 'Register with email')),
                    ),
                  ),
            const SizedBox(height: AppSpacing.md),
            if (_isAwaitingVerification)
              TextButton(
                onPressed: () {
                  setState(() {
                    _isAwaitingVerification = false;
                  });
                },
                child: const Text('Back to sign in'),
              )
            else
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                  });
                },
                // Which of the two ways in this switches is now in the
                // text. "Registrujte se" on its own sat under a Google
                // button that also registers, and said nothing about
                // which one it meant.
                child: Text(_isLogin
                    ? "Don't have an account? Register with email"
                    : 'Already have an account? Sign in with email'),
              ),
          ],
        ),
      ),
    );
  }

  /// The remembered addresses, as a list under the address field (sketch
  /// `docs/skice/prijava-i-podesavanja/login-accounts.html`). Only when
  /// signing in, and only when there is something to choose.
  ///
  /// No tooltip anywhere in it: a tooltip inside a popup is the shape that
  /// sent the Windows screen reader a node no parent lists, and the crash
  /// that follows (`move_tree_semantics_orphan_test`). The buttons carry
  /// their names as semantic labels on their icons instead.
  Widget? _rememberedAccounts(BuildContext context) {
    final saved = SavedSignIns.instance;
    final addresses = saved.addresses;
    if (!_isLogin || addresses.isEmpty) return null;
    return MenuAnchor(
      controller: _accountsMenu,
      menuChildren: [
        for (final address in addresses)
          MenuItemButton(
            key: ValueKey('remembered-$address'),
            leadingIcon: const Icon(Icons.person_outline),
            trailingIcon: IconButton(
              key: ValueKey('forget-$address'),
              icon:
                  Icon(Icons.close, size: 18, semanticLabel: 'Forget $address'),
              onPressed: () => _forgetAddress(address),
            ),
            onPressed: () => _chooseAddress(address),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(address),
                if (saved.keepsPasswords)
                  Text(
                    saved.hasPassword(address)
                        ? 'Password saved'
                        : 'Address only',
                    style: AppText.caption
                        .copyWith(color: context.colors.textMuted),
                  ),
              ],
            ),
          ),
      ],
      builder: (context, controller, _) => IconButton(
        key: const Key('remembered-accounts'),
        icon: Icon(
          controller.isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
          semanticLabel: 'Remembered accounts',
        ),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  /// Show / hide what is in the password field — the owner's request of
  /// 29.9.2026, for checking what was typed.
  ///
  /// A kept password is not shown: the eye is greyed out until the person
  /// has emptied the field, as Edge does for a password it filled — not
  /// merely edited it, or one keystroke would be the way to read the rest.
  /// Anybody at a shared computer could otherwise read the saved password of
  /// whoever signed in there last, and many of these accounts belong to
  /// minors.
  Widget _visibilityButton() {
    final kept = _filledFrom != null;
    return IconButton(
      key: const Key('password-visibility'),
      tooltip: kept
          ? 'A saved password is not shown'
          : (_passwordVisible ? 'Hide password' : 'Show password'),
      icon: Icon(
        _passwordVisible && !kept ? Icons.visibility_off : Icons.visibility,
        // Said by luminance, not only by the tooltip: the field draws its
        // suffix in one colour whatever the button's state, so a disabled
        // eye looked exactly like an enabled one (rendered 29.9.2026). The
        // colour is the icon's own, because the button's `disabledColor`
        // leaked into its enabled state too.
        color: kept ? context.colors.textMuted.withValues(alpha: 0.4) : null,
      ),
      onPressed: kept
          ? null
          : () => setState(() => _passwordVisible = !_passwordVisible),
    );
  }

  /// The Google half: one button that both signs in and registers.
  ///
  /// Its own block, above the divider, and shown in registration mode too —
  /// it was login-only, so somebody who came to register was offered only the
  /// email form and had no way of knowing Google would have made the account
  /// for them.
  ///
  /// Neutral border rather than the primary colour: the coloured outline made
  /// this look like the marked choice while the user was typing an address into
  /// the form below it.
  Widget _buildGoogleBlock(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _handleGoogleSignIn,
            icon: Image.network(
              'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
              height: 18,
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.g_mobiledata, size: 24),
            ),
            // Both words, because the button does both: there is no separate
            // Google registration anywhere, and "Prijavi se" alone made people
            // look for one.
            label: const Text(
              'Sign in / Register with Google',
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Theme.of(context).dividerColor),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadii.roundedSm,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'If you do not have an account yet, one will be created automatically.',
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(color: Theme.of(context).hintColor),
        ),
      ],
    );
  }

  /// The line between the two ways in.
  Widget _buildOrDivider(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'or',
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

/// The left half of the sign-in screen on a wide window
/// (`docs/PLAN-PRIJAVA-I-PODESAVANJA.md`, D1 B): who this is, in the brand
/// colour, and nothing that can be pressed.
///
/// The light theme's violet in both themes: the dark theme's brand is a pale
/// violet that white text does not read on, and the panel is the same place
/// whichever theme is chosen. White on it measures 5.7:1
/// (`AppColorTokens.light`).
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  static const _start =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  @override
  Widget build(BuildContext context) {
    const tokens = AppColorTokens.light;
    return Container(
      key: const Key('sign-in-brand-panel'),
      color: tokens.brand,
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxxl * 2, vertical: AppSpacing.xxxl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events, size: 56, color: tokens.surface),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Mislisha',
              style: AppText.display.copyWith(
                  color: tokens.surface,
                  fontSize: 40,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.md),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Text(
                'Sessions with your trainer, homework, puzzles from your own '
                'games, and tutorials.',
                style: AppText.bodyLarge.copyWith(color: tokens.surface),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const BoardThumbnail(
              key: Key('sign-in-brand-board'),
              fen: _start,
              size: 208,
            ),
          ],
        ),
      ),
    );
  }
}
