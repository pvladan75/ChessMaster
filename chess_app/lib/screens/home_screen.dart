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
    if (widget.session.role == 'trener') {
      _fetchStudents();
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pozivnica! ${data['senderName']} vas poziva u sobu ${data['roomCode']}!'),
          action: SnackBarAction(
            label: 'Pridruži se',
            textColor: Colors.tealAccent,
            onPressed: () => _joinInviteRoom(data['roomCode']),
          ),
          duration: const Duration(seconds: 8),
        ),
      );
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
              if (_friends.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Text('Nemate dodatih prijatelja. Možete ih dodati u kartici "Lista prijatelja" ispod.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                )
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: Column(
                      children: _friends.map((f) {
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

        _navigateToGame(roomCode, 'trener');
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
                if (_friends.isEmpty)
                  const Text('Nemate dodatih prijatelja.', style: TextStyle(fontSize: 11, color: Colors.grey))
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 140),
                    child: SingleChildScrollView(
                      child: Column(
                        children: _friends.map((f) {
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
    final effectiveRole = sessionRole ?? (roomCode == 'STUDIO' ? 'trener' : (widget.session.role == 'unassigned' ? 'ucenik' : widget.session.role));
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
        builder: (context) => ChessGamePage(roomCode: roomCode, userSession: sessionForRoom),
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
    final isTrener = widget.session.role == 'trener';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chess Master Home'),
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
                  // AI Studio Card
                  Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Colors.amberAccent, width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade900.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.psychology, size: 36, color: Colors.amberAccent),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'AI Trener & Vežbe',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Rešavajte adaptivne zagonetke i tražite AI objašnjenje šahovskih pozicija.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: const Text('Otvori'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AiStudioScreen(userSession: widget.session),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

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
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _showCreateRoomWithFriendsDialog,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Kreiraj odmah'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _showScheduleSessionDialog,
                                    icon: const Icon(Icons.calendar_month),
                                    label: const Text('Zakaži unapred'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Scheduled Sessions & Calendar Card
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
                                    Icon(Icons.calendar_month, color: Colors.amberAccent),
                                    SizedBox(width: 8),
                                    Text(
                                      'Zakazane sesije i Kalendar',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 18),
                                  onPressed: _fetchScheduledSessions,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_isLoadingScheduled)
                              const Center(child: CircularProgressIndicator())
                            else if (_scheduledSessions.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12.0),
                                child: Center(
                                  child: Text('Nemate zakazanih budućih sesija.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _scheduledSessions.length,
                                separatorBuilder: (ctx, idx) => const Divider(height: 1),
                                itemBuilder: (ctx, idx) {
                                  final item = _scheduledSessions[idx];
                                  final dateStr = DateTime.parse(item['scheduled_at']).toLocal().toString().substring(0, 16);
                                  final roomCode = item['room_code'];
                                  final calUrl = item['calendarUrl'];
                                  final hostName = item['host_name'] ?? 'Trener';

                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const CircleAvatar(
                                      backgroundColor: Colors.amber,
                                      child: Icon(Icons.event, color: Colors.black, size: 18),
                                    ),
                                    title: Text(item['title'] ?? 'Šahovska sesija', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    subtitle: Text('Domaćin: $hostName | $dateStr | Soba: $roomCode', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    trailing: Wrap(
                                      spacing: 4,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_calendar, color: Colors.blueAccent, size: 20),
                                          tooltip: 'Dodaj u Google Kalendar',
                                          onPressed: () {
                                            if (calUrl != null) {
                                              launchUrl(Uri.parse(calUrl), mode: LaunchMode.externalApplication);
                                            }
                                          },
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                                          onPressed: () => _joinInviteRoom(roomCode),
                                          child: const Text('Pridruži se', style: TextStyle(fontSize: 11)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
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

                  const SizedBox(height: 24),

                  // Resource Usage Statistics Card
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
                                  Text(
                                    'Statistika upotrebe (Resource Usage)',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
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
                          if (_isLoadingStats)
                            const Center(child: CircularProgressIndicator())
                          else ...[
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
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.mic, color: Colors.amberAccent),
                              title: const Text('Ukupno snimljenih časova', style: TextStyle(fontSize: 13)),
                              trailing: Text(
                                '${_userStats?['totalRecordingsCount'] ?? 0}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _showPremiumModal,
                                icon: const Icon(Icons.workspace_premium, color: Colors.amber, size: 16),
                                label: const Text('Upravljaj Premium nalogom'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Recorded Lessons Card
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
                                  Text(
                                    'Snimljeni časovi (Replay)',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.refresh, size: 18),
                                onPressed: _fetchRecordings,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_isLoadingRecordings)
                            const Center(child: CircularProgressIndicator())
                          else if (_recordings.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Center(
                                child: Text(
                                  'Nema sačuvanih snimaka časova.',
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _recordings.length,
                              separatorBuilder: (ctx, idx) => const Divider(height: 1),
                              itemBuilder: (ctx, idx) {
                                final rec = _recordings[idx];
                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    rec['video_url'] != null ? Icons.file_download_done : Icons.play_circle_fill,
                                    color: rec['video_url'] != null ? Colors.tealAccent : Colors.deepPurpleAccent,
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          rec['title'] ?? 'Snimak časa',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (rec['video_url'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.withValues(alpha: 0.3),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.tealAccent, width: 0.5),
                                          ),
                                          child: const Text(
                                            'MP4 Video',
                                            style: TextStyle(fontSize: 9, color: Colors.tealAccent, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text('Trener: ${rec['host_name'] ?? 'Trener'}'),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (ctx) => ReplayPlayerScreen(
                                          recordingId: rec['id'],
                                          userSession: widget.session,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
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
