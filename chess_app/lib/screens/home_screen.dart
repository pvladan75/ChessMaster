import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_app/constants.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/chess_game_screen.dart';
import 'package:chess_app/screens/login_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserSession session;

  const HomeScreen({super.key, required this.session});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _createRoom() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/rooms/create'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.session.token}'
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        final roomCode = data['room_code'];
        _navigateToGame(roomCode);
      } else {
        _showError(data['error'] ?? 'Failed to create room');
      }
    } catch (e) {
      _showError('Network error. Check if server is running.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _joinRoom() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _showError('Enter a valid 6-digit code');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/rooms/join'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.session.token}'
        },
        body: jsonEncode({'roomCode': code}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _navigateToGame(code);
      } else {
        _showError(data['error'] ?? 'Failed to join room');
      }
    } catch (e) {
      _showError('Network error. Check if server is running.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToGame(String roomCode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChessGamePage(roomCode: roomCode, userSession: widget.session),
      ),
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

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('remember_me');
    await prefs.remove('user_token');
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('user_name');
    await prefs.remove('user_role');

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginRegisterScreen()),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTrener = widget.session.role == 'trener';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess Master Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Welcome, ${widget.session.name}!',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Chip(
                label: Text(
                  isTrener ? 'Role: Instructor (Trener)' : 'Role: Student (Učenik)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              ),
              const SizedBox(height: 48),
              if (_isLoading)
                const CircularProgressIndicator()
              else if (isTrener) ...[
                // Trainer UI
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Icon(Icons.school, size: 48, color: Colors.amber),
                        const SizedBox(height: 12),
                        const Text(
                          'Create a new lesson room to teach chess.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _createRoom,
                            icon: const Icon(Icons.add),
                            label: const Text('Kreiraj lekciju (Create Lesson)'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Student UI
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        const Icon(Icons.group, size: 48, color: Colors.blue),
                        const SizedBox(height: 12),
                        const Text(
                          'Enter the 6-digit lesson code from your instructor.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _codeController,
                          decoration: const InputDecoration(
                            labelText: '6-Digit Code',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.vpn_key),
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _joinRoom,
                            icon: const Icon(Icons.login),
                            label: const Text('Pridruži se (Join Room)'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
