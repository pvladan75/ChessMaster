import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_app/constants.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/home_screen.dart';

import 'package:flutter/foundation.dart' show kIsWeb;

class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({super.key});

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: (kIsWeb && googleWebClientId.isNotEmpty) ? googleWebClientId : null,
    serverClientId: googleWebClientId.isNotEmpty ? googleWebClientId : null,
    scopes: ['email'],
  );
  
  bool _isLogin = true;
  String _role = 'ucenik'; // Default role is student ('ucenik')
  bool _isLoading = false;
  bool _rememberMe = false;

  Future<void> _handleGoogleSignIn() async {
    if (kIsWeb && googleWebClientId.isEmpty) {
      _showError('Google Sign-In na Webu zahteva Web ClientID u constants.dart ili web/index.html.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final String? idToken = googleAuth.idToken;
        final String? accessToken = googleAuth.accessToken;

        final Map<String, dynamic> reqPayload = {
          if (idToken != null && idToken.isNotEmpty) 'idToken': idToken,
          if (accessToken != null && accessToken.isNotEmpty) 'accessToken': accessToken,
          'email': googleUser.email,
          'name': googleUser.displayName,
        };

        final response = await http.post(
          Uri.parse('$backendUrl/auth/google'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(reqPayload),
        );

        final data = jsonDecode(response.body);
        if (response.statusCode == 200) {
          final session = UserSession.fromJson(data['user'], data['token']);
          await _saveSession(session);
          _navigateToHome(session);
        } else {
          _showError(data['error'] ?? 'Google prijava nije uspela.');
        }
      }
    } catch (e) {
      _showError('Google Sign-In Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
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
        } else {
          _showError(data['error'] ?? 'Login failed');
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
            'role': _role,
          }),
        );

        final data = jsonDecode(response.body);
        if (response.statusCode == 201) {
          final session = UserSession.fromJson(data['user'], data['token']);
          await _saveSession(session);
          _navigateToHome(session);
        } else {
          _showError(data['error'] ?? 'Registration failed');
        }
      }
    } catch (e) {
      _showError('Network error. Check if backend is running.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSession(UserSession session) async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setBool('remember_me', true);
      await prefs.setString('user_token', session.token);
      await prefs.setInt('user_id', session.id);
      await prefs.setString('user_email', session.email);
      await prefs.setString('user_name', session.name);
      await prefs.setString('user_role', session.role);
    } else {
      await prefs.remove('remember_me');
      await prefs.remove('user_token');
      await prefs.remove('user_id');
      await prefs.remove('user_email');
      await prefs.remove('user_name');
      await prefs.remove('user_role');
    }
  }

  void _navigateToHome(UserSession session) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => HomeScreen(session: session)),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.emoji_events,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isLogin ? 'Chess Master Login' : 'Register Account',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    if (!_isLogin) ...[
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          prefixIcon: Icon(Icons.person),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.isEmpty ? 'Please enter name' : null,
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) =>
                          value == null || !value.contains('@') ? 'Please enter a valid email' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock),
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      validator: (value) =>
                          value == null || value.length < 6 ? 'Password must be at least 6 characters' : null,
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      title: const Text('Zapamti me', style: TextStyle(fontSize: 14)),
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
                                  child: Text(_isLogin ? 'Login' : 'Register'),
                                ),
                              ),
                              if (_isLogin) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    onPressed: _handleGoogleSignIn,
                                    icon: Image.network(
                                      'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
                                      height: 18,
                                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, size: 24),
                                    ),
                                    label: const Text('Prijavi se preko Google-a'),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: Theme.of(context).primaryColor),
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
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isLogin = !_isLogin;
                        });
                      },
                      child: Text(_isLogin
                          ? "Don't have an account? Register"
                          : "Already have an account? Login"),
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
