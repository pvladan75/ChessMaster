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
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/services/desktop_google_sign_in.dart';
import 'package:chess_app/services/oauth_pkce.dart' show OAuthRedirectException;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/theme/app_spacing.dart';
import 'package:chess_app/theme/app_radii.dart';

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

  @override
  void initState() {
    super.initState();
    // The address from the last remembered sign-in. Only the address: the
    // password is the platform password manager's job, which is what the
    // autofill hints below are for. Storing it here would put it in a plain
    // file in the user's profile, and most of these accounts belong to
    // children.
    final remembered = SessionService.instance.lastEmail;
    if (remembered != null && remembered.isNotEmpty) {
      _emailController.text = remembered;
      _emailIsKnown = true;
    }

    // Why they are looking at this screen, when the app decided it rather than
    // they did. Without it the trip here is unexplained: the previous screen is
    // gone and nothing says the session ran out.
    final reason = SessionService.instance.expiryReason;
    if (reason != null) {
      _expiryNotice = reason == 'account-gone'
          ? 'Ovaj nalog više ne postoji na serveru. Prijavite se drugim '
              'nalogom.'
          : 'Prijava je istekla. Prijavite se ponovo.';
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
          _showError(data['error'] ?? 'Google prijava nije uspela.');
        } catch (_) {
          _showError(
              'Greška na serveru prilikom Google prijave (Status ${response.statusCode}).');
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
      _showError('Google prijava nije podržana na ovoj platformi.');
      return null;
    }

    final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
    final String? idToken = googleUser.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      _showError('Google nije vratio identitet (id_token).');
      return null;
    }
    return idToken;
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    final email = _emailController.text.trim();
    if (email.isEmpty || code.isEmpty) {
      _showError('Unesite email i 6-cifreni verifikacioni kod.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/auth/verify-email'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'code': code}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final session = UserSession.fromJson(data['user'], data['token']);
        await _saveSession(session);
        _showSuccess('Email verifikovan! Dobrodošli.');
        _navigateToHome(session);
      } else {
        try {
          final data = jsonDecode(response.body);
          _showError(data['error'] ?? 'Verifikacija nije uspela.');
          // Nothing left to do on this screen: the account is verified and the
          // way in is a password or Google. Leaving the user in front of a code
          // field that can never work again is how a person concludes the app
          // is broken rather than that they are already done.
          if (data['alreadyVerified'] == true) {
            setState(() => _isAwaitingVerification = false);
          }
        } catch (_) {
          _showError(
              'Greška pri verifikaciji (Status ${response.statusCode}).');
        }
      }
    } catch (e) {
      _showError('Mrežna greška pri verifikaciji koda.');
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
        // Login API Call
        final response = await http.post(
          Uri.parse('$backendUrl/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': _emailController.text.trim(),
            'password': _passwordController.text,
          }),
        );

        final data = jsonDecode(response.body);
        if (response.statusCode == 200) {
          final session = UserSession.fromJson(data['user'], data['token']);
          await _saveSession(session);
          _navigateToHome(session);
        } else if (data['requiresVerification'] == true) {
          setState(() {
            _isAwaitingVerification = true;
          });
          _showSuccess(
              data['error'] ?? 'Unesite verifikacioni kod poslat na email.');
        } else {
          _showError(data['error'] ?? 'Prijava nije uspela.');
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
              'Kod za verifikaciju je generisan! Unesite 6-cifreni kod.');
        } else {
          _showError(data['error'] ?? 'Registracija nije uspela.');
        }
      }
    } catch (e) {
      _showError('Greška u mreži. Proverite konekciju sa serverom.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSession(UserSession session) async {
    await SessionService.instance.signIn(session, rememberMe: _rememberMe);
    // Tells the platform the sign-in went through, which is what makes Android
    // and Windows offer to save the password — and, next time, to fill it. The
    // app never sees or stores it either way.
    TextInput.finishAutofillContext();
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
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _showSuccess(String message) {
    AppFeedback.show(
      context,
      () => SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade800,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isAwaitingVerification
            ? 'Verifikacija Email-a'
            : (_isLogin ? 'Prijava' : 'Registracija')),
        actions: [
          TextButton.icon(
            onPressed: () => _navigateToHome(UserSession.guest()),
            icon: const Icon(Icons.person_outline),
            label: const Text('Nastavi kao Gost'),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Form(
            key: _formKey,
            // One group, so the platform reads these fields as a single
            // sign-in rather than as unrelated boxes it has nothing to offer.
            child: AutofillGroup(
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: AppRadii.roundedLg),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                            ? 'Unesite Verifikacioni Kod'
                            : (_isLogin ? 'Mislisha' : 'Registracija Naloga'),
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      if (_expiryNotice != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.15),
                            borderRadius: AppRadii.roundedSm,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock_clock,
                                  size: 18, color: Colors.orangeAccent),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  _expiryNotice!,
                                  style: AppText.body
                                      .copyWith(color: Colors.orangeAccent),
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
                          'Poslat je verifikacioni kod na ${_emailController.text}.'
                          '\nAko ga nema u prijemnom sandučetu, pogledajte i '
                          'neželjenu poštu (spam).'
                          '${kDebugMode ? '\n(U dev okruženju kod se ispisuje u backend logovima.)' : ''}',
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TextFormField(
                          controller: _codeController,
                          decoration: const InputDecoration(
                            labelText: 'Verifikacioni Kod (6 cifara)',
                            prefixIcon: Icon(Icons.pin),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          validator: (val) => val == null || val.length != 6
                              ? 'Unesite 6 cifara'
                              : null,
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
                              labelText: 'Ime i Prezime',
                              prefixIcon: Icon(Icons.person),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Unesite ime'
                                : null,
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
                          decoration: const InputDecoration(
                            labelText: 'Email Adresa',
                            prefixIcon: Icon(Icons.email),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          autofocus: _isLogin && !_emailIsKnown,
                          validator: (value) =>
                              value == null || !value.contains('@')
                                  ? 'Unesite validnu email adresu'
                                  : null,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TextFormField(
                          controller: _passwordController,
                          autofillHints: [
                            _isLogin
                                ? AutofillHints.password
                                : AutofillHints.newPassword,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Lozinka',
                            prefixIcon: Icon(Icons.lock),
                            border: OutlineInputBorder(),
                          ),
                          obscureText: true,
                          autofocus: _isLogin && _emailIsKnown,
                          onFieldSubmitted: (_) => _submit(),
                          validator: (value) =>
                              value == null || value.length < 6
                                  ? 'Lozinka mora imati bar 6 karaktera'
                                  : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        CheckboxListTile(
                          title: const Text('Zapamti me',
                              style: TextStyle(fontSize: 14)),
                          // Said out loud, because it was read as "remember my
                          // password" and it has never meant that: it keeps the
                          // session, so the form is not asked for at all. The
                          // password itself is offered by the device's password
                          // manager, if it has been saved there.
                          subtitle: Text(
                            'Ostajete prijavljeni na ovom uređaju.',
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
                                onPressed: _submit,
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AppRadii.roundedSm,
                                  ),
                                ),
                                child: Text(_isAwaitingVerification
                                    ? 'Potvrdi Verifikaciju'
                                    : (_isLogin
                                        ? 'Prijavi se email adresom'
                                        : 'Registruj se email adresom')),
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
                          child: const Text('Nazad na prijavu'),
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
                              ? 'Nemate nalog? Registrujte se email adresom'
                              : 'Već imate nalog? Prijavite se email adresom'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
              'Prijava / Registracija preko Google-a',
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
          'Ako još nemate nalog, napraviće se sam.',
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
            'ili',
            style: TextStyle(color: Theme.of(context).hintColor),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
