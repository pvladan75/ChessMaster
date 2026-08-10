import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_app/constants.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/chess_game_screen.dart';
import 'package:chess_app/screens/login_screen.dart';

import 'package:chess_app/screens/replay_player_screen.dart';
import 'package:chess_app/screens/ai_studio_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chess_app/screens/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final UserSession session;

  const HomeScreen({super.key, required this.session});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final _codeController = TextEditingController();
  bool _isLoading = false;

  late io.Socket _socket;
  List<dynamic> _students = [];
  bool _isLoadingStudents = false;
  final TextEditingController _studentEmailController = TextEditingController();

  Map<String, dynamic>? _userStats;
  bool _isLoadingStats = false;

  List<dynamic> _recordings = [];
  bool _isLoadingRecordings = false;

  List<dynamic> _friends = [];
  bool _isLoadingFriends = false;
  final TextEditingController _friendEmailController = TextEditingController();

  List<dynamic> _notifications = [];
  bool _isLoadingNotifications = false;

  List<dynamic> _scheduledSessions = [];
  bool _isLoadingScheduled = false;

  @override
  void initState() {
    super.initState();
    _initSocket();
    _fetchStudents();
    _fetchUserStats();
    _fetchRecordings();
    _fetchFriends();
    _fetchNotifications();
    _fetchScheduledSessions();
  }

  @override
  void dispose() {
    _socket.disconnect();
    _socket.dispose();
    _codeController.dispose();
    _studentEmailController.dispose();
    _friendEmailController.dispose();
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

    _socket.on('session_invite_received', (data) {
      if (!mounted) return;
      _fetchNotifications();
      final senderName = data['senderName'] ?? data['trainerName'] ?? 'Prijatelj';
      final roomCode = data['roomCode'] ?? '';
      _showInviteDialog(roomCode, senderName);
    });

    _socket.on('lesson_invite', (data) {
      if (!mounted) return;
      _fetchNotifications();
      final senderName = data['trainerName'] ?? data['senderName'] ?? 'Prijatelj';
      final roomCode = data['roomCode'] ?? '';
      _showInviteDialog(roomCode, senderName);
    });
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
          initialRole: 'ucenik',
        ),
      ),
    );
    if (mounted) {
      _socket.connect();
    }
  }

  Future<void> _fetchStudents() async {
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
      print("Error fetching friends: $e");
    } finally {
      if (mounted) setState(() => _isLoadingStudents = false);
    }
  }

  Future<void> _deleteStudent(int studentId) async {
    try {
      final res = await http.delete(
        Uri.parse('$backendUrl/trainer/students/$studentId'),
        headers: {'Authorization': 'Bearer ${widget.session.token}'},
      );
      if (res.statusCode == 200) {
        _fetchStudents();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prijatelj je uklonjen iz liste.')),
        );
      }
    } catch (e) {
      print("Error deleting friend: $e");
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
      print("Error adding student: $e");
    }
  }

  Future<void> _fetchUserStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/users/me/stats'),
        headers: {'Authorization': 'Bearer ${widget.session.token}'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _userStats = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print("Error fetching user stats: $e");
    } finally {
      setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _fetchRecordings() async {
    setState(() => _isLoadingRecordings = true);
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/recordings'),
        headers: {'Authorization': 'Bearer ${widget.session.token}'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _recordings = jsonDecode(response.body);
        });
      }
    } catch (e) {
      print("Error fetching recordings: $e");
    } finally {
      setState(() => _isLoadingRecordings = false);
    }
  }

  Future<void> _updateAccountType(String newType) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/users/account-type'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.session.token}'
        },
        body: jsonEncode({'account_type': newType}),
      );
      if (response.statusCode == 200) {
        _fetchUserStats();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Nalog uspešno promenjen na $newType!'),
              backgroundColor: Colors.teal,
            ),
          );
        }
      }
    } catch (e) {
      print("Error updating account type: $e");
    }
  }

  Future<void> _fetchFriends() async {
    setState(() => _isLoadingFriends = true);
    try {
      final res = await http.get(
        Uri.parse('$backendUrl/friends'),
        headers: {'Authorization': 'Bearer ${widget.session.token}'},
      );
      if (res.statusCode == 200) {
        setState(() => _friends = jsonDecode(res.body));
      }
    } catch (e) {
      print("Error fetching friends: $e");
    } finally {
      if (mounted) setState(() => _isLoadingFriends = false);
    }
  }

  Future<void> _addFriend() async {
    final email = _friendEmailController.text.trim();
    if (email.isEmpty) return;
    try {
      final res = await http.post(
        Uri.parse('$backendUrl/friends/add'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.session.token}'
        },
        body: jsonEncode({'email': email}),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 201) {
        _friendEmailController.clear();
        _fetchFriends();
        _showSuccess(data['message'] ?? 'Prijatelj je uspešno dodat!');
      } else {
        _showError(data['error'] ?? 'Neuspešno dodavanje prijatelja.');
      }
    } catch (e) {
      _showError('Greška pri dodavanju prijatelja.');
    }
  }

  Future<void> _removeFriend(int friendId) async {
    try {
      final res = await http.delete(
        Uri.parse('$backendUrl/friends/$friendId'),
        headers: {'Authorization': 'Bearer ${widget.session.token}'},
      );
      if (res.statusCode == 200) {
        _fetchFriends();
        _showSuccess('Prijatelj je uklonjen iz liste.');
      }
    } catch (e) {
      _showError('Greška pri uklanjanju prijatelja.');
    }
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoadingNotifications = true);
    try {
      final res = await http.get(
        Uri.parse('$backendUrl/notifications'),
        headers: {'Authorization': 'Bearer ${widget.session.token}'},
      );
      if (res.statusCode == 200) {
        setState(() => _notifications = jsonDecode(res.body));
      }
    } catch (e) {
      print("Error fetching notifications: $e");
    } finally {
      if (mounted) setState(() => _isLoadingNotifications = false);
    }
  }

  Future<void> _markNotificationRead(int notifId) async {
    try {
      await http.post(
        Uri.parse('$backendUrl/notifications/$notifId/read'),
        headers: {'Authorization': 'Bearer ${widget.session.token}'},
      );
      _fetchNotifications();
    } catch (e) {
      print("Error marking notification read: $e");
    }
  }

  void _showNotificationsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.notifications_active, color: Colors.amberAccent),
              SizedBox(width: 8),
              Text('Notifikacije i Pozivnice', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_notifications.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Nemate novih notifikacija.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                )
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: SingleChildScrollView(
                    child: Column(
                      children: _notifications.map((n) {
                        final notifId = n['id'] as int;
                        final roomCode = n['room_code'] as String;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          child: ListTile(
                            dense: true,
                            leading: const Icon(Icons.star, color: Colors.amber),
                            title: Text(n['message'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            subtitle: Text('Soba: $roomCode', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                              onPressed: () {
                                _markNotificationRead(notifId);
                                Navigator.pop(ctx);
                                _joinInviteRoom(roomCode);
                              },
                              child: const Text('Pridruži se', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Zatvori'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateRoomWithFriendsDialog() {
    final List<int> selectedFriendIds = [];
    final availableFriends = _students.isNotEmpty ? _students : _friends;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.add_circle_outline, color: Colors.tealAccent),
              SizedBox(width: 8),
              Text('Kreiranje sesije i Pozivanje', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Izaberite prijatelje koje želite da pozovete u novu sesiju:', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              if (availableFriends.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Text('Nemate dodatih prijatelja. Možete ih dodati u kartici "Lista prijatelja" ispod.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                )
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: Column(
                      children: availableFriends.map((f) {
                        final fId = f['id'] as int;
                        final isSel = selectedFriendIds.contains(fId);
                        return CheckboxListTile(
                          dense: true,
                          title: Text(f['name'] ?? 'Prijatelj', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          subtitle: Text(f['email'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          value: isSel,
                          onChanged: (val) {
                            setModalState(() {
                              if (val == true) {
                                selectedFriendIds.add(fId);
                              } else {
                                selectedFriendIds.remove(fId);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Otkaži'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.rocket_launch, size: 16),
              label: Text(selectedFriendIds.isNotEmpty ? 'Kreiraj i Pozovi (${selectedFriendIds.length})' : 'Kreiraj sesiju'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                _createRoomWithInvites(selectedFriendIds);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createRoomWithInvites(List<int> friendIds) async {
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

        if (friendIds.isNotEmpty) {
          await http.post(
            Uri.parse('$backendUrl/invitations/send'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${widget.session.token}'
            },
            body: jsonEncode({'friendIds': friendIds, 'roomCode': roomCode}),
          );
        }

        _navigateToGame(roomCode, 'host');
      } else {
        _showError(data['error'] ?? 'Neuspešno kreiranje sobe.');
      }
    } catch (e) {
      _showError('Greška pri kreiranju sobe.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchScheduledSessions() async {
    setState(() => _isLoadingScheduled = true);
    try {
      final res = await http.get(
        Uri.parse('$backendUrl/sessions/scheduled'),
        headers: {'Authorization': 'Bearer ${widget.session.token}'},
      );
      if (res.statusCode == 200) {
        setState(() => _scheduledSessions = jsonDecode(res.body));
      }
    } catch (e) {
      print("Error fetching scheduled sessions: $e");
    } finally {
      if (mounted) setState(() => _isLoadingScheduled = false);
    }
  }

  void _showScheduleSessionDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 3));
    TimeOfDay selectedTime = const TimeOfDay(hour: 18, minute: 0);
    final List<int> selectedFriendIds = [];
    final availableFriends = _students.isNotEmpty ? _students : _friends;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.calendar_month, color: Colors.amberAccent),
              SizedBox(width: 8),
              Text('Zakazivanje sesije unapred', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Naslov sesije / lekcije',
                    hintText: 'npr. Sicilijanska odbrana - Predavanje',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Opis (opciono)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 14),
                        label: Text('${selectedDate.day}.${selectedDate.month}.${selectedDate.year}.'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setModalState(() => selectedDate = picked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time, size: 14),
                        label: Text('${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}'),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (picked != null) {
                            setModalState(() => selectedTime = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Pozovi prijatelje na zakazani čas:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (availableFriends.isEmpty)
                  const Text('Nemate dodatih prijatelja.', style: TextStyle(fontSize: 11, color: Colors.grey))
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 140),
                    child: SingleChildScrollView(
                      child: Column(
                        children: availableFriends.map((f) {
                          final fId = f['id'] as int;
                          final isSel = selectedFriendIds.contains(fId);
                          return CheckboxListTile(
                            dense: true,
                            title: Text(f['name'] ?? 'Prijatelj', style: const TextStyle(fontSize: 12)),
                            subtitle: Text(f['email'] ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            value: isSel,
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  selectedFriendIds.add(fId);
                                } else {
                                  selectedFriendIds.remove(fId);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Otkaži'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.event_available),
              label: const Text('Zakaži i Sačuvaj'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;

                final scheduledDateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );

                Navigator.pop(ctx);
                _scheduleSession(title, descCtrl.text.trim(), scheduledDateTime, selectedFriendIds);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scheduleSession(String title, String desc, DateTime scheduledAt, List<int> friendIds) async {
    try {
      final res = await http.post(
        Uri.parse('$backendUrl/sessions/schedule'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.session.token}'
        },
        body: jsonEncode({
          'title': title,
          'description': desc,
          'scheduledAt': scheduledAt.toIso8601String(),
          'friendIds': friendIds,
        }),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 201) {
        _fetchScheduledSessions();
        _showScheduledSuccessDialog(data['message'] ?? 'Sesija zakazana!', data['calendarUrl'], data['session']['room_code']);
      } else {
        _showError(data['error'] ?? 'Greška pri zakazivanju.');
      }
    } catch (e) {
      _showError('Greška na mreži pri zakazivanju.');
    }
  }

  void _showScheduledSuccessDialog(String message, String? calendarUrl, String roomCode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.tealAccent),
            SizedBox(width: 8),
            Text('Zakazivanje Uspešno!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Text('Kod sobe: $roomCode', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.tealAccent)),
            const SizedBox(height: 12),
            if (calendarUrl != null) ...[
              const Text('Sinhronizujte sa kalendarom:', style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 6),
              ElevatedButton.icon(
                icon: const Icon(Icons.edit_calendar),
                label: const Text('Dodaj u Google Kalendar'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                onPressed: () {
                  launchUrl(Uri.parse(calendarUrl), mode: LaunchMode.externalApplication);
                },
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('U redu'),
          ),
        ],
      ),
    );
  }

  void _showPremiumModal() {
    final isPremium = _userStats?['account_type'] == 'premium';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('Chess Master Premium', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unapredite nalog za neograničeno stvaranje sesija i snimanje časova!',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const ListTile(
              dense: true,
              leading: Icon(Icons.check_circle, color: Colors.tealAccent),
              title: Text('Neograničeno sačuvanih pozicija i lekcija (Free: do 20)'),
            ),
            const ListTile(
              dense: true,
              leading: Icon(Icons.check_circle, color: Colors.tealAccent),
              title: Text('Neograničeno živih sesija mesečno (Free: do 5)'),
            ),
            const ListTile(
              dense: true,
              leading: Icon(Icons.check_circle, color: Colors.tealAccent),
              title: Text('Izvoz snimljenih časova u MP4 Video format'),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Napomena (Faza testiranja): Trenutno možete besplatno prebaciti nalog klikom ispod.',
                style: TextStyle(fontSize: 11, color: Colors.amberAccent),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Zatvori'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isPremium ? Colors.grey : Colors.amber,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(context);
              _updateAccountType(isPremium ? 'free' : 'premium');
            },
            child: Text(isPremium ? 'Prebaci na Besplatan nalog' : 'Aktiviraj Premium'),
          ),
        ],
      ),
    );
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
              initialRole: 'trener',
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

  void _navigateToGame(String roomCode, [String? sessionRole]) {
    final effectiveRole = sessionRole ?? (roomCode == 'STUDIO' ? 'host' : 'korisnik');
    final sessionForRoom = UserSession(
      id: widget.session.id,
      email: widget.session.email,
      name: widget.session.name,
      role: effectiveRole,
      token: widget.session.token,
      accountType: widget.session.accountType,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChessGamePage(
          roomCode: roomCode,
          userSession: sessionForRoom,
          initialRole: effectiveRole,
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.teal,
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
    final media = MediaQuery.of(context);
    final isWide = media.size.width > 800;

    final List<Widget> pages = [
      _buildDashboardTab(),
      AiStudioScreen(userSession: widget.session),
      _buildBibliotekaTab(),
      _buildFriendsTab(),
      SettingsScreen(session: widget.session),
    ];

    final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: isLandscape
          ? null
          : AppBar(
              title: const Text('Chess Master'),
              actions: [
                IconButton(
                  tooltip: 'Notifikacije i Pozivnice',
                  icon: Badge(
                    isLabelVisible: _notifications.isNotEmpty,
                    label: Text('${_notifications.length}'),
                    child: const Icon(Icons.notifications, color: Colors.amberAccent),
                  ),
                  onPressed: _showNotificationsDialog,
                ),
              ],
            ),
      body: Row(
        children: [
          if (isWide || (isLandscape && _selectedIndex != 1))
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
              labelType: NavigationRailLabelType.none,
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: Text('Početna')),
                NavigationRailDestination(icon: Icon(Icons.psychology_outlined), selectedIcon: Icon(Icons.psychology), label: Text('Trening')),
                NavigationRailDestination(icon: Icon(Icons.library_books_outlined), selectedIcon: Icon(Icons.library_books), label: Text('Biblioteka')),
                NavigationRailDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: Text('Prijatelji')),
                NavigationRailDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: Text('Podešavanja')),
              ],
            ),
          if (isWide || (isLandscape && _selectedIndex != 1)) const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: (isWide || isLandscape)
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Početna'),
                NavigationDestination(icon: Icon(Icons.psychology_outlined), selectedIcon: Icon(Icons.psychology), label: 'Trening'),
                NavigationDestination(icon: Icon(Icons.library_books_outlined), selectedIcon: Icon(Icons.library_books), label: 'Biblioteka'),
                NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Prijatelji'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Podešavanja'),
              ],
            ),
    );
  }

  void _openStudioRoom() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChessGamePage(
          userSession: widget.session,
          roomCode: 'STUDIO',
          initialRole: 'host',
        ),
      ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Header Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.deepPurple,
                        child: Text(
                          widget.session.name.isNotEmpty ? widget.session.name[0].toUpperCase() : 'K',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dobrodošli, ${widget.session.name}!',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Spremite se za šahovski čas, rešavajte zagonetke ili analizirajte pozicije.',
                              style: TextStyle(color: Colors.grey[400], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Action Cards Grid (Multiplayer Session & Studio)
              Row(
                children: [
                  Expanded(
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Colors.teal, width: 1.5),
                      ),
                      child: InkWell(
                        onTap: _showCreateRoomWithFriendsDialog,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Icon(Icons.video_call, size: 36, color: Colors.tealAccent),
                              SizedBox(height: 12),
                              Text('Nova Sesija', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.tealAccent)),
                              SizedBox(height: 4),
                              Text('Pokrenite čas kao Host ili zakažite termin za učenike.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Colors.deepPurpleAccent, width: 1.5),
                      ),
                      child: InkWell(
                        onTap: _openStudioRoom,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Icon(Icons.dashboard, size: 36, color: Colors.purpleAccent),
                              SizedBox(height: 12),
                              Text('Šahovski Studio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.purpleAccent)),
                              SizedBox(height: 4),
                              Text('Samostalni rad, FEN postavljanje, PGN i Stockfish analiza.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Join Room Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          decoration: const InputDecoration(
                            labelText: 'Unesite kod sobe (npr. 123456)',
                            prefixIcon: Icon(Icons.vpn_key),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.login),
                        label: const Text('Pridruži se'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                        onPressed: () {
                          final code = _codeController.text.trim();
                          if (code.isNotEmpty) _joinInviteRoom(code);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Resource Usage Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.pie_chart, color: Colors.tealAccent),
                              SizedBox(width: 8),
                              Text('Statistika naloga', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Chip(
                            label: Text(
                              _userStats?['account_type'] == 'premium' ? 'PREMIUM' : 'FREE',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                            ),
                            backgroundColor: _userStats?['account_type'] == 'premium'
                                ? Colors.amber.withValues(alpha: 0.3)
                                : Colors.teal.withValues(alpha: 0.3),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.bookmark, color: Colors.teal),
                        title: const Text('Sačuvane lekcije / pozicije', style: TextStyle(fontSize: 13)),
                        trailing: Text(
                          '${_userStats?['savedLessonsCount'] ?? 0} / ${_userStats?['limits']?['maxSavedLessons'] == -1 ? '∞' : (_userStats?['limits']?['maxSavedLessons'] ?? 20)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.video_camera_front, color: Colors.blueAccent),
                        title: const Text('Kreirano sesija u tekućem mesecu', style: TextStyle(fontSize: 13)),
                        trailing: Text(
                          '${_userStats?['monthlySessionsCount'] ?? 0} / ${_userStats?['limits']?['maxMonthlySessions'] == -1 ? '∞' : (_userStats?['limits']?['maxMonthlySessions'] ?? 5)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Recordings Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.video_library, color: Colors.deepPurpleAccent),
                              SizedBox(width: 8),
                              Text('Snimljeni časovi (Replay)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 18),
                            onPressed: _fetchRecordings,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isLoadingRecordings)
                        const Center(child: CircularProgressIndicator())
                      else if (_recordings.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(child: Text('Nemate sačuvanih snimaka.', style: TextStyle(color: Colors.grey))),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _recordings.length,
                          separatorBuilder: (ctx, idx) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final rec = _recordings[idx];
                            final title = rec['title'] ?? 'Snimljena sesija';
                            final dateStr = DateTime.parse(rec['created_at']).toLocal().toString().substring(0, 16);
                            final durationSec = rec['duration'] ?? 0;
                            final durationMin = (durationSec / 60).toStringAsFixed(1);

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                backgroundColor: Colors.deepPurple,
                                child: Icon(Icons.play_arrow, color: Colors.white),
                              ),
                              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('$dateStr • $durationMin min', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              trailing: ElevatedButton.icon(
                                icon: const Icon(Icons.movie, size: 14),
                                label: const Text('Pusti', style: TextStyle(fontSize: 11)),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurpleAccent, foregroundColor: Colors.white),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ReplayPlayerScreen(recordingId: rec['id'], userSession: widget.session),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBibliotekaTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.library_books, color: Colors.tealAccent, size: 28),
                          SizedBox(width: 12),
                          Text('Biblioteka Pozicija i Lekcija', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Upravljajte vašim sačuvanim pozicijama, PGN fajlovima i kursevima.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.dashboard_customize),
                        label: const Text('Otvori Šahovski Studio sa praznom tablom'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _openStudioRoom,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFriendsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.people, color: Colors.purpleAccent, size: 28),
                          SizedBox(width: 12),
                          Text('Moji Prijatelji & Kontakti', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _studentEmailController,
                              decoration: const InputDecoration(
                                labelText: 'Email prijatelja',
                                hintText: 'prijatelj@example.com',
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
                            child: const Text('Dodaj prijatelja'),
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
                          child: Center(child: Text('Nemate još uvek dodatih prijatelja.', style: TextStyle(color: Colors.grey))),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _students.length,
                          separatorBuilder: (ctx, idx) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final s = _students[idx];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(child: Icon(Icons.person)),
                              title: Text(s['name'] ?? 'Prijatelj', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(s['email'] ?? ''),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                onPressed: () => _deleteStudent(s['id']),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
