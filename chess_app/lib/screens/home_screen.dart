import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as io;
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

  late io.Socket _socket;
  List<dynamic> _students = [];
  bool _isLoadingStudents = false;
  final TextEditingController _studentEmailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initSocket();
    if (widget.session.role == 'trener') {
      _fetchStudents();
    }
  }

  @override
  void dispose() {
    _socket.disconnect();
    _socket.dispose();
    _codeController.dispose();
    _studentEmailController.dispose();
    super.dispose();
  }

  void _initSocket() {
    _socket = io.io(backendUrl, io.OptionBuilder()
      .setTransports(['websocket'])
      .enableForceNewConnection()
      .disableAutoConnect()
      .build());

    _socket.connect();

    _socket.onConnect((_) {
      print("Home socket connected!");
      _socket.emit('register_user', {
        'userId': widget.session.id,
        'name': widget.session.name,
        'email': widget.session.email,
        'role': widget.session.role,
      });
    });

    _socket.on('user_presence_changed', (data) {
      if (mounted) {
        _fetchStudents();
      }
    });

    if (widget.session.role == 'ucenik') {
      _socket.on('lesson_invite', (data) {
        if (mounted) {
          _showInviteDialog(data['roomCode'], data['trainerName']);
        }
      });
    }
  }

  void _showInviteDialog(String roomCode, String trainerName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Poziv na lekciju'),
          content: Text('Trener $trainerName vas poziva na lekciju. Da li želite da se pridružite?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Odbij'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _joinInviteRoom(roomCode);
              },
              child: const Text('Pridruži se'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _joinInviteRoom(String roomCode) async {
    _socket.disconnect();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChessGamePage(
          userSession: widget.session,
          roomCode: roomCode,
        ),
      ),
    );
    if (mounted) {
      _socket.connect();
    }
  }

  Future<void> _fetchStudents() async {
    if (widget.session.role != 'trener') return;
    setState(() => _isLoadingStudents = true);
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/trainer/students'),
        headers: {'Authorization': 'Bearer ${widget.session.token}'},
      );

      if (response.statusCode == 200) {
        setState(() {
          _students = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print("Error fetching students: $e");
    } finally {
      setState(() => _isLoadingStudents = false);
    }
  }

  Future<void> _addStudent() async {
    final email = _studentEmailController.text.trim();
    if (email.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/trainer/students/add'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.session.token}'
        },
        body: jsonEncode({'email': email}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        _studentEmailController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Učenik dodat.')),
        );
        _fetchStudents();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['error'] ?? 'Greška pri dodavanju učenika.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška: $e')),
      );
    }
  }

  Future<void> _inviteStudent(int studentId) async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/rooms/create'),
        headers: {'Authorization': 'Bearer ${widget.session.token}'},
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final String createdRoomCode = data['room_code'];

        _socket.emit('send_lesson_invite', {
          'studentId': studentId,
          'roomCode': createdRoomCode,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pozivnica poslata za sobu $createdRoomCode! Povezivanje...')),
        );

        _socket.disconnect();
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChessGamePage(
              userSession: widget.session,
              roomCode: createdRoomCode,
            ),
          ),
        );
        if (mounted) {
          _socket.connect();
        }
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorData['error'] ?? 'Greška pri kreiranju sobe')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška pri kreiranju sobe: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Text(
                    'Welcome, ${widget.session.name}!',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Chip(
                    label: Text(
                      isTrener ? 'Role: Instructor (Trener)' : 'Role: Student (Učenik)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  ),
                ),
                const SizedBox(height: 32),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  if (isTrener) ...[
                    // Trainer UI
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            const Icon(Icons.school, size: 48, color: Colors.amber),
                            const SizedBox(height: 12),
                            const Text(
                              'Kreirajte novu lekciju za učenike.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 16),
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
                    const SizedBox(height: 24),
                    // Students Card
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Moji Učenici',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _studentEmailController,
                                    decoration: const InputDecoration(
                                      labelText: 'Email učenika',
                                      hintText: 'student@example.com',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _addStudent,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  ),
                                  child: const Text('Dodaj'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),
                            if (_isLoadingStudents)
                              const Center(child: CircularProgressIndicator())
                            else if (_students.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24.0),
                                child: Center(
                                  child: Text(
                                    'Nemate još uvek dodatih učenika.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _students.length,
                                separatorBuilder: (context, index) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final student = _students[index];
                                  final isOnline = student['status'] == 'online';
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(
                                      backgroundColor: isOnline ? Colors.green : Colors.grey,
                                      radius: 6,
                                    ),
                                    title: Text(student['name']),
                                    subtitle: Text(student['email']),
                                    trailing: ElevatedButton.icon(
                                      onPressed: isOnline ? () => _inviteStudent(student['id']) : null,
                                      icon: const Icon(Icons.send, size: 14),
                                      label: const Text('Pozovi'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isOnline ? Colors.teal : Colors.blueGrey.withOpacity(0.2),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  );
                                },
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
                              'Unesite 6-cifreni kod koji ste dobili od trenera.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _codeController,
                              decoration: const InputDecoration(
                                labelText: 'Kod (6 cifara)',
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
                  const SizedBox(height: 24),
                  // Studio for Position Preparation (Accessible to both Trainer and Student)
                  Card(
                    elevation: 4,
                    color: Colors.indigo.withOpacity(0.15),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Icon(Icons.architecture, size: 44, color: Colors.indigoAccent),
                          const SizedBox(height: 10),
                          const Text(
                            'Studio za pripremu pozicija',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Samostalno kreirajte pozicije, uvozite PGN/FEN, analizirajte motorm i upravljajte svojom bibliotekom sa labelama.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChessGamePage(
                                      userSession: widget.session,
                                      roomCode: 'STUDIO',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.explore),
                              label: const Text('Otvori Studio (Studio za pripremu)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.indigoAccent,
                                foregroundColor: Colors.white,
                              ),
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
      ),
    );
  }
}
