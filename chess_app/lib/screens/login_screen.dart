import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:chess_app/constants.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/models/pending_session_intent.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/services/session_service.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:chess_app/widgets/app_feedback.dart';

class LoginRegisterScreen extends StatefulWidget {
  /// The login-gated action (create/join a room, invite a student...) that
  /// sent the user here, if any — resumed automatically by HomeScreen once
  /// signing in succeeds. See home_screen.dart's `_checkAuthRequired`.
  final PendingSessionIntent? pendingIntent;

  const LoginRegisterScreen({super.key, this.pendingIntent});

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

  Future<void> _handleGoogleSignIn() async {
    if (kIsWeb && googleWebClientId.isEmpty) {
      _showError(
          'Google Sign-In na Webu zahteva Web ClientID u constants.dart ili web/index.html.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _googleSignInInit;
      if (!_googleSignIn.supportsAuthenticate()) {
        _showError('Google Sign-In nije podržan na ovoj platformi.');
        return;
      }

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      final String? idToken = googleUser.authentication.idToken;

      final Map<String, dynamic> reqPayload = {
        if (idToken != null && idToken.isNotEmpty) 'idToken': idToken,
        'email': googleUser.email,
        'name': googleUser.displayName,
      };

      final response = await http.post(
        Uri.parse('$backendUrl/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(reqPayload),
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
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled) {
        _showError('Google Sign-In Error: ${e.description ?? e.code}');
      }
    } catch (e) {
      _showError('Google Sign-In Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
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
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
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
                    const SizedBox(height: 12),
                    Text(
                      _isAwaitingVerification
                          ? 'Unesite Verifikacioni Kod'
                          : (_isLogin
                              ? 'Šahovski trener'
                              : 'Registracija Naloga'),
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    if (_isAwaitingVerification) ...[
                      Text(
                        'Poslat je verifikacioni kod na ${_emailController.text}.\n(U dev okruženju kod se ispisuje u backend logovima).',
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 16),
                    ] else ...[
                      if (!_isLogin) ...[
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Ime i Prezime',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Unesite ime'
                              : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email Adresa',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) =>
                            value == null || !value.contains('@')
                                ? 'Unesite validnu email adresu'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Lozinka',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        validator: (value) => value == null || value.length < 6
                            ? 'Lozinka mora imati bar 6 karaktera'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        title: const Text('Zapamti me',
                            style: TextStyle(fontSize: 14)),
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
                    const SizedBox(height: 16),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: _submit,
                                  style: ElevatedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(_isAwaitingVerification
                                      ? 'Potvrdi Verifikaciju'
                                      : (_isLogin
                                          ? 'Prijavi Se'
                                          : 'Registruj Se')),
                                ),
                              ),
                              if (!_isAwaitingVerification && _isLogin) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    onPressed: _handleGoogleSignIn,
                                    icon: Image.network(
                                      'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
                                      height: 18,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(Icons.g_mobiledata,
                                                  size: 24),
                                    ),
                                    label:
                                        const Text('Prijavi se preko Google-a'),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                          color:
                                              Theme.of(context).primaryColor),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                    const SizedBox(height: 12),
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
                        child: Text(_isLogin
                            ? "Nemate nalog? Registrujte se"
                            : "Već imate nalog? Prijavite se"),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
