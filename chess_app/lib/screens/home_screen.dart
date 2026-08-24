import 'package:chess_app/features/analysis_studio/services/opening_book_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:chess_app/constants.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/models/pending_session_intent.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/theme/breakpoints.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/services/server_status_service.dart';
import 'package:chess_app/services/game_session_service.dart';
import 'package:chess_app/services/billing_service.dart';
import 'package:chess_app/features/reviews/services/review_api_service.dart';

import 'package:chess_app/features/training/screens/training_hub_screen.dart';

import 'package:chess_app/widgets/home/home_dialogs.dart' as dialogs;
import 'package:chess_app/widgets/home/dashboard_tab.dart';
import 'package:chess_app/widgets/home/biblioteka_tab.dart';
import 'package:chess_app/widgets/home/friends_tab.dart';
import 'package:chess_app/models/relationship_request_target.dart';

class HomeScreen extends StatefulWidget {
  final UserSession session;

  /// A login-gated action to resume now that the user is signed in — see
  /// login_screen.dart's `_navigateToHome` and this screen's `initState`.
  final PendingSessionIntent? pendingIntent;

  const HomeScreen({super.key, required this.session, this.pendingIntent});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  /// Tabs are built on first visit and kept alive after that. Building all of
  /// them up front meant AI Studio spun up and attached to the shared engine
  /// before the user had opened anything.
  final Set<int> _visitedTabs = {0};

  /// Visit order, so Android back returns to the previous tab instead of
  /// dropping straight out of the app.
  final List<int> _tabHistory = [0];

  /// Index of the "Prijatelji" tab in the navigation bar.
  static const _friendsTabIndex = 3;

  void _selectTab(int idx) {
    if (idx == _selectedIndex) return;
    setState(() {
      _selectedIndex = idx;
      _visitedTabs.add(idx);
      _tabHistory.remove(idx);
      _tabHistory.add(idx);
    });

    // The other side answers on their own device, and nothing tells this one.
    // Until it was fetched again only at startup, a trainer whose student had
    // just accepted still saw "čeka potvrdu" and had to restart the app.
    if (idx == _friendsTabIndex) {
      _fetchStudents();
    }
  }

  final _codeController = TextEditingController();
  bool _isLoading = false;

  late io.Socket _socket;
  List<dynamic> _students = [];
  List<dynamic> _pendingRequests = [];
  List<dynamic> _trainers = [];

  /// The badge counts what has *not* been read. `/notifications` returns the
  /// last 20 regardless of `is_read`, so counting the list showed a number that
  /// never went down no matter how much the user read.
  ///
  /// A request waiting for an answer counts once, from the pending list rather
  /// than from its notification: the notification can scroll out of the last
  /// twenty, and the thing somebody is waiting on must not stop being counted
  /// because of that. Its notification is therefore skipped here.
  int get _unreadNotifications {
    final pendingIds = _pendingRequests.map((r) => r['id'] as int).toSet();
    final unread = _notifications.where((n) {
      if (n['is_read'] == true) return false;
      if ((n['kind'] ?? 'room').toString() != 'student_request') return true;
      final ref = n['ref_id'];
      return !(ref is int && pendingIds.contains(ref));
    }).length;
    return unread + _pendingRequests.length;
  }

  /// Which side the user is claiming when they send the next request. Defaults
  /// to trainer because that is what the button did before the choice existed,
  /// so nobody's habit silently changes meaning.
  bool _iAmTrainerInRequest = true;
  bool _isLoadingStudents = false;
  final TextEditingController _studentEmailController = TextEditingController();


  List<dynamic> _recordings = [];
  bool _isLoadingRecordings = false;

  List<dynamic> _friends = [];
  bool _isLoadingFriends = false;
  final TextEditingController _friendEmailController = TextEditingController();

  List<dynamic> _notifications = [];
  bool _isLoadingNotifications = false;

  List<dynamic> _scheduledSessions = [];
  bool _isLoadingScheduled = false;

  late final BillingService _billing;
  int _dueReviews = 0;

  /// Whether the app is running under the test binding.
  ///
  /// The same guard the AI screen's health check already uses, and for the same
  /// reason: a socket that keeps trying to reconnect, and a billing client that
  /// polls, leave timers running after the widget tree is gone - which fails
  /// every test that so much as opens this screen. Reading the binding's type
  /// is ugly and is the honest version of the alternative, which is not being
  /// able to test the shell at all.
  bool get _inTest {
    final binding = WidgetsBinding.instance.runtimeType.toString();
    return binding.contains('Test') || binding.contains('test');
  }

  @override
  void initState() {
    super.initState();
    _billing = BillingService(authToken: widget.session.token);
    if (!widget.session.isGuest && !_inTest) {
      // Before anything else: does being signed in currently mean anything?
      // Everything below assumes a server that answers, and when none does the
      // screen should say so rather than fail one request at a time.
      ServerStatusService.instance.check(widget.session.token);
      // Also picks up a subscription bought on another device and finishes any
      // purchase whose verification was interrupted.
      _billing.init();
      _initSocket();
      _fetchStudents();
      _fetchRecordings();
      _fetchFriends();
      _fetchNotifications();
      _fetchScheduledSessions();
      _fetchDueReviews();
    }
    OpeningBookService.instance.ensureLoaded();
    GameSessionService.instance.addListener(_onGameSessionChanged);

    final intent = widget.pendingIntent;
    if (intent != null) {
      // Deferred to after the first frame: the actions below (pushing a
      // route, opening a dialog) need a settled BuildContext.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _resumePendingIntent(intent));
    }
  }

  @override
  void dispose() {
    if (!widget.session.isGuest && !_inTest) {
      _socket.disconnect();
      _socket.dispose();
    }
    GameSessionService.instance.removeListener(_onGameSessionChanged);
    _billing.dispose();
    _codeController.dispose();
    _studentEmailController.dispose();
    _friendEmailController.dispose();
    super.dispose();
  }

  void _onGameSessionChanged() {
    if (mounted) setState(() {});
  }

  /// Runs the action that sent a guest to /login, now that they're signed in.
  void _resumePendingIntent(PendingSessionIntent intent) {
    if (!mounted) return;
    switch (intent.action) {
      case PendingSessionAction.createRoom:
        _createRoom();
        break;
      case PendingSessionAction.showCreateRoomDialog:
        _showCreateRoomWithFriendsDialog();
        break;
      case PendingSessionAction.joinRoomByCode:
        _codeController.text = intent.roomCode ?? '';
        _joinRoom();
        break;
      case PendingSessionAction.joinInviteRoom:
        if (intent.roomCode != null) _joinInviteRoom(intent.roomCode!);
        break;
      case PendingSessionAction.inviteStudent:
        if (intent.studentId != null) _inviteStudent(intent.studentId!);
        break;
    }
  }

  void _initSocket() {
    // The server derives identity from this token; guests connect without one.
    _socket = io.io(
        backendUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .enableForceNewConnection()
            .disableAutoConnect()
            .setAuth({'token': widget.session.token})
            .build());

    _socket.connect();

    _socket.onConnect((_) {
      print("Home socket connected!");
      // Proof the backend exists, and it often arrives after the startup check
      // has already failed — the server can take the better part of a minute to
      // finish its migrations. A warning that contradicts traffic already
      // flowing is worse than no warning at all.
      ServerStatusService.instance.markOnline();
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

    // Anything that raised a notification at the other end — homework set, a
    // note written, a lesson scheduled, a request answered. Without this the
    // bell only ever filled at startup: nothing polls, so a notification
    // arriving while the app is open was invisible until it was restarted.
    _socket.on('notifications_changed', (_) {
      if (!mounted) return;
      _fetchNotifications();
    });

    // A relationship in particular also changes the Prijatelji lists, which the
    // bell does not cover: the tab would otherwise keep saying "čeka potvrdu"
    // until it was left and entered again — which is how this was noticed.
    _socket.on('relationship_changed', (_) {
      if (!mounted) return;
      _fetchStudents();
    });

    _socket.on('session_invite_received', (data) {
      if (!mounted) return;
      _fetchNotifications();
      final senderName =
          data['senderName'] ?? data['trainerName'] ?? 'Prijatelj';
      final roomCode = data['roomCode'] ?? '';
      _showInviteDialog(roomCode, senderName);
    });

    _socket.on('lesson_invite', (data) {
      if (!mounted) return;
      _fetchNotifications();
      final senderName =
          data['trainerName'] ?? data['senderName'] ?? 'Prijatelj';
      final roomCode = data['roomCode'] ?? '';
      _showInviteDialog(roomCode, senderName);
    });
  }

  void _showInviteDialog(String roomCode, String trainerName) {
    dialogs.showInviteDialog(
      context,
      roomCode: roomCode,
      trainerName: trainerName,
      onJoin: () => _joinInviteRoom(roomCode),
    );
  }

  Future<void> _joinInviteRoom(String roomCode) async {
    if (!_checkAuthRequired(PendingSessionIntent.joinInviteRoom(roomCode))) {
      return;
    }
    if (!_checkNoActiveSession(targetRoomCode: roomCode)) return;
    _socket.disconnect();
    await context.push(AppRoutes.roomPath(roomCode, role: 'ucenik'));
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
          _students = jsonDecode(response.body)['students'] ?? [];
        });
      }
    } catch (e) {
      print("Error fetching students: $e");
      if (mounted) AppFeedback.error(context, 'Greška pri učitavanju učenika.');
    } finally {
      if (mounted) setState(() => _isLoadingStudents = false);
    }
    await _fetchTrainers();
    await _fetchPendingRequests();
  }

  /// The same relationships read from the other end.
  ///
  /// Without this the tab showed only people the user teaches, so a student
  /// with a trainer and no students of their own was told "Još nemate ni
  /// učenika ni trenera" while the relationship existed and worked.
  Future<void> _fetchTrainers() async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/students/trainers'),
        headers: {'Authorization': 'Bearer ${widget.session.token}'},
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _trainers = jsonDecode(response.body)['trainers'] ?? [];
        });
      }
    } catch (e) {
      print("Error fetching trainers: $e");
    }
  }

  /// Requests waiting for this user to answer, in either direction.
  ///
  /// Fetched alongside the student list rather than on its own timer: the two
  /// are read on the same screen, and a request answered elsewhere should not
  /// leave a stale card sitting here.
  Future<void> _fetchPendingRequests() async {
    try {
      final response = await http.get(
        Uri.parse('$backendUrl/relationships/pending'),
        headers: {'Authorization': 'Bearer ${widget.session.token}'},
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _pendingRequests = jsonDecode(response.body)['requests'] ?? [];
        });
      }
    } catch (e) {
      // Silent on purpose: an empty request list is the normal case, and a
      // failure here must not bury the student list behind an error banner.
      print("Error fetching pending requests: $e");
    }
  }

  /// Answers one request. Returns whether it went through, because the bell
  /// shows the outcome in place of the row rather than closing itself.
  Future<bool> _respondToRequest(int requestId, {required bool accept}) async {
    try {
      final response = await http.post(
        Uri.parse(
            '$backendUrl/relationships/$requestId/${accept ? 'accept' : 'decline'}'),
        headers: {'Authorization': 'Bearer ${widget.session.token}'},
      );
      if (!mounted) return false;

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Sačuvano.')),
        );
        await _fetchStudents();
        return true;
      }
      AppFeedback.error(context, data['error'] ?? 'Greška pri odgovoru.');
      return false;
    } catch (e) {
      print("Error responding to request: $e");
      if (mounted) AppFeedback.error(context, 'Greška pri odgovoru.');
      return false;
    }
  }

  Future<void> _deleteStudent(int studentId) async {
    try {
      final res = await http.delete(
        Uri.parse('$backendUrl/trainer/students/$studentId'),
        headers: {'Authorization': 'Bearer ${widget.session.token}'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        _fetchStudents();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prijatelj je uklonjen iz liste.')),
        );
      }
    } catch (e) {
      print("Error deleting friend: $e");
      if (mounted) AppFeedback.error(context, 'Greška pri uklanjanju.');
    }
  }

  Future<void> _addStudent() async {
    final email = _studentEmailController.text.trim();
    if (email.isEmpty) return;

    // The side the sender claims decides the route and the field name both.
    // The field is named studentEmail / trainerEmail server-side; sending
    // 'email' made every add fail with "Email učenika/prijatelja je obavezan".
    final target =
        RelationshipRequestTarget.forRole(iAmTrainer: _iAmTrainerInRequest);

    try {
      final response = await http.post(
        Uri.parse('$backendUrl${target.path}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.session.token}'
        },
        body: jsonEncode({target.emailField: email}),
      );

      final data = jsonDecode(response.body);
      if (!mounted) return;
      if (response.statusCode == 200) {
        _studentEmailController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Učenik dodat.')),
        );
        _fetchStudents();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(data['error'] ?? 'Greška pri dodavanju učenika.')),
        );
      }
    } catch (e) {
      print("Error adding student: $e");
      if (mounted) AppFeedback.error(context, 'Greška pri dodavanju učenika.');
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
      if (mounted) AppFeedback.error(context, 'Greška pri učitavanju snimaka.');
    } finally {
      setState(() => _isLoadingRecordings = false);
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
        setState(() => _friends = jsonDecode(res.body)['friends'] ?? []);
      }
    } catch (e) {
      print("Error fetching friends: $e");
      if (mounted) {
        AppFeedback.error(context, 'Greška pri učitavanju prijatelja.');
      }
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
        body: jsonEncode({'friendEmail': email}),
      );
      final data = jsonDecode(res.body);
      // The endpoint answers 200, not 201 — checking for 201 reported a
      // successful add as a failure.
      if (res.statusCode == 200) {
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
        setState(
            () => _notifications = jsonDecode(res.body)['notifications'] ?? []);
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
      if (mounted) {
        AppFeedback.error(context, 'Greška pri ažuriranju obaveštenja.');
      }
    }
  }

  /// Marks everything the bell is about to show as read.
  ///
  /// Only a room invitation was ever marked read before, and only by being
  /// joined — so the badge never went down. The user could open the bell, read
  /// all of it, close it, and still be told there were three.
  ///
  /// The list handed to the dialog is the one already in hand, so what was new
  /// still reads as new while it is open; the refetch settles it on close.
  Future<void> _markShownNotificationsRead() async {
    if (_notifications.every((n) => n['is_read'] == true)) return;
    try {
      await http.post(
        Uri.parse('$backendUrl/notifications/read'),
        headers: {'Authorization': 'Bearer ${widget.session.token}'},
      );
      if (mounted) await _fetchNotifications();
    } catch (e) {
      // The badge staying up is not worth an error in the user's face.
      print("Error marking notifications read: $e");
    }
  }

  void _showNotificationsDialog() {
    _markShownNotificationsRead();
    dialogs.showNotificationsDialog(
      context,
      notifications: _notifications,
      pendingRequests: _pendingRequests,
      onJoinFromNotification: (notifId, roomCode) {
        _markNotificationRead(notifId);
        _joinInviteRoom(roomCode);
      },
      // The bell is where a request is answered now, so the answer is handed
      // to it rather than to the Prijatelji tab. The server closes the matching
      // notification itself; both lists are refetched so the badge and the
      // student list stop disagreeing with what just happened.
      onRespondToRequest: (requestId, accept) async {
        final ok = await _respondToRequest(requestId, accept: accept);
        if (ok) await _fetchNotifications();
        return ok;
      },
    );
  }

  void _showCreateRoomWithFriendsDialog() {
    if (!_checkAuthRequired(
        const PendingSessionIntent.showCreateRoomDialog())) {
      return;
    }
    if (!_checkNoActiveSession()) return;
    final availableFriends = _students.isNotEmpty ? _students : _friends;
    dialogs.showCreateRoomWithFriendsDialog(
      context,
      availableFriends: availableFriends,
      onCreate: _createRoomWithInvites,
    );
  }

  Future<void> _createRoomWithInvites(List<int> friendIds) async {
    if (!_checkNoActiveSession()) return;
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
        final roomCode = data['room_code'] ?? data['room']?['room_code'];

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
        setState(
            () => _scheduledSessions = jsonDecode(res.body)['sessions'] ?? []);
      }
    } catch (e) {
      print("Error fetching scheduled sessions: $e");
    } finally {
      if (mounted) setState(() => _isLoadingScheduled = false);
    }
  }

  void _showScheduleSessionDialog() {
    final availableFriends = _students.isNotEmpty ? _students : _friends;
    dialogs.showScheduleSessionDialog(
      context,
      availableFriends: availableFriends,
      onSchedule: _scheduleSession,
    );
  }

  Future<void> _scheduleSession(String title, String desc, DateTime scheduledAt,
      List<int> friendIds) async {
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
        _showScheduledSuccessDialog(data['message'] ?? 'Sesija zakazana!',
            data['calendarUrl'], data['session']['room_code']);
      } else {
        _showError(data['error'] ?? 'Greška pri zakazivanju.');
      }
    } catch (e) {
      _showError('Greška na mreži pri zakazivanju.');
    }
  }

  void _showScheduledSuccessDialog(
      String message, String? calendarUrl, String roomCode) {
    dialogs.showScheduledSuccessDialog(context,
        message: message, calendarUrl: calendarUrl, roomCode: roomCode);
  }

  void _openStudentProgress(Map<String, dynamic> student) {
    final id = (student['id'] as num?)?.toInt();
    if (id == null) return;

    context.push(AppRoutes.studentProgressPath(
      id,
      name: student['name']?.toString() ?? 'Učenik',
    ));
  }

  void _openMyAssignments() {
    context.push(AppRoutes.assignments);
  }

  Future<void> _openReviews() async {
    await context.push(AppRoutes.review);
    // The badge is stale the moment a session ends, so it is refetched rather
    // than decremented locally — a failed grade must not shrink the count.
    if (mounted) _fetchDueReviews();
  }

  Future<void> _fetchDueReviews() async {
    if (widget.session.isGuest) return;
    final stats =
        await ReviewApiService(authToken: widget.session.token).fetchStats();
    if (mounted) setState(() => _dueReviews = stats.due);
  }


  Future<void> _inviteStudent(int studentId) async {
    if (!_checkAuthRequired(PendingSessionIntent.inviteStudent(studentId))) {
      return;
    }
    if (!_checkNoActiveSession()) return;
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/rooms/create'),
        headers: {'Authorization': 'Bearer ${widget.session.token}'},
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final String createdRoomCode =
            data['room_code'] ?? data['room']?['room_code'] ?? '';

        _socket.emit('send_lesson_invite', {
          'studentId': studentId,
          'roomCode': createdRoomCode,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Pozivnica poslata za sobu $createdRoomCode! Povezivanje...')),
        );

        _socket.disconnect();
        await context.push(AppRoutes.roomPath(createdRoomCode, role: 'trener'));
        if (mounted) {
          _socket.connect();
        }
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(errorData['error'] ?? 'Greška pri kreiranju sobe')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška pri kreiranju sobe: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createRoom() async {
    if (!_checkAuthRequired(const PendingSessionIntent.createRoom())) return;
    if (!_checkNoActiveSession()) return;
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
        final roomCode = data['room_code'] ?? data['room']?['room_code'];
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
    if (!_checkAuthRequired(PendingSessionIntent.joinRoomByCode(code))) return;
    if (code.length != 6) {
      _showError('Enter a valid 6-digit code');
      return;
    }
    if (!_checkNoActiveSession(targetRoomCode: code)) return;

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
    // The role travels in the URL; the room route rebuilds the session with it.
    final effectiveRole =
        sessionRole ?? (roomCode == 'STUDIO' ? 'host' : 'korisnik');
    context.push(AppRoutes.roomPath(roomCode, role: effectiveRole));
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

  /// Redirects a guest straight to /login (carrying [intent] so the action
  /// resumes automatically after signing in) instead of asking first —
  /// entering or creating a session always requires being logged in.
  bool _checkAuthRequired(PendingSessionIntent intent) {
    if (widget.session.isGuest) {
      context.push(AppRoutes.login, extra: intent);
      return false;
    }
    return true;
  }

  /// Blocks starting/joining a *different* room while one is already active
  /// — rejoining the same room (e.g. resuming) is always allowed.
  bool _checkNoActiveSession({String? targetRoomCode}) {
    final gs = GameSessionService.instance;
    if (!gs.hasActiveSession ||
        (targetRoomCode != null && gs.isSameSession(targetRoomCode))) {
      return true;
    }
    dialogs.showActiveSessionBlockedDialog(
      context,
      roomCode: gs.roomCode!,
      onGoToSession: () =>
          context.push(AppRoutes.roomPath(gs.roomCode!, role: gs.role)),
    );
    return false;
  }

  Future<void> _logout() async {
    await GameSessionService.instance.clear();
    await SessionService.instance.signOut();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isWide = Breakpoints.isWide(context);

    // Unvisited tabs render as an empty box; once visited they stay in the
    // stack so their state survives switching away and back.
    final List<Widget> pages = List.generate(4, (i) {
      if (!_visitedTabs.contains(i)) return const SizedBox.shrink();
      switch (i) {
        // 0 is the crossroads, and it sits at the bottom of this switch as the
        // default rather than being listed twice.
        case 1:
          return HomeDashboardTab(
            userName: widget.session.name,
            codeController: _codeController,
            recordings: _recordings,
            isLoadingRecordings: _isLoadingRecordings,
            onCreateSessionTap: _showCreateRoomWithFriendsDialog,
            onOpenStudio: _openStudioRoom,
            onOpenAssignments: _openMyAssignments,
            onOpenReviews: _openReviews,
            dueReviewCount: _dueReviews,
            onJoinRoom: _joinInviteRoom,
            onRefreshRecordings: _fetchRecordings,
            onOpenReplay: (id) => context.push(AppRoutes.replayPath(id)),
          );
        case 2:
          return HomeBibliotekaTab(
            onOpenStudio: _openStudioRoom,
            onOpenAnalysis: () => context.push(AppRoutes.analysis),
            onOpenScanner: () => context.push(AppRoutes.scan),
            onOpenSavedPositions: () => context.push(AppRoutes.savedPositions),
          );
        case 3:
          return HomeFriendsTab(
            studentEmailController: _studentEmailController,
            isLoadingStudents: _isLoadingStudents,
            students: _students,
            trainers: _trainers,
            iAmTrainerInRequest: _iAmTrainerInRequest,
            onRoleChanged: (v) => setState(() => _iAmTrainerInRequest = v),
            onRefresh: _fetchStudents,
            onAddStudent: _addStudent,
            onDeleteStudent: _deleteStudent,
            onOpenProgress: _openStudentProgress,
          );
        default:
          // The crossroads, not the working screen. Everything it offers is a
          // route now, so the tab holds a list of cards and nothing heavier.
          //
          // First, and default, because it is the one thing that is true for
          // everybody who opens the app. Rooms and homework need a second
          // person; practice does not.
          return TrainingHubScreen(session: widget.session);
      }
    });

    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return PopScope(
      canPop: _tabHistory.length <= 1,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _tabHistory.length <= 1) return;
        setState(() {
          _tabHistory.removeLast();
          _selectedIndex = _tabHistory.last;
        });
      },
      child: Scaffold(
        appBar: isLandscape
            ? null
            : AppBar(
                title: const Text('Šahovski trener'),
                actions: [
                  if (widget.session.isGuest)
                    TextButton.icon(
                      onPressed: () {
                        context.push(AppRoutes.login);
                      },
                      icon: const Icon(Icons.login, color: Colors.white),
                      label: const Text('Prijavi Se',
                          style: TextStyle(color: Colors.white)),
                    ),
                  IconButton(
                    tooltip: 'Podešavanja',
                    icon: const Icon(Icons.settings_outlined,
                        color: Colors.white70),
                    // Out of the tabs and into the bar. Settings is not a place
                    // anybody lives in, and it already had a path of its own -
                    // one that opens over whatever is underneath rather than
                    // tearing it down.
                    onPressed: () => context.push(AppRoutes.preferences),
                  ),
                  IconButton(
                    tooltip: 'Notifikacije i Pozivnice',
                    icon: Badge(
                      isLabelVisible: _unreadNotifications > 0,
                      label: Text('$_unreadNotifications'),
                      child: const Icon(Icons.notifications,
                          color: Colors.amberAccent),
                    ),
                    onPressed: _showNotificationsDialog,
                  ),
                ],
              ),
        body: Column(
          children: [
            _buildActiveSessionBanner(),
            Expanded(
              child: Row(
                children: [
                  // The rail stays visible for every tab in landscape. AI Studio's
                  // landscape board is sized from available *height*, so the rail's
                  // width costs it nothing — and hiding it used to leave that tab with
                  // no AppBar, no bottom bar and no rail, i.e. no way out at all.
                  if (isWide || isLandscape)
                    NavigationRail(
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: _selectTab,
                      labelType: NavigationRailLabelType.none,
                      // At the foot of the rail, where a desktop looks for it.
                      // The same lesson as the bell above: the AppBar is null in
                      // landscape, and Windows is always landscape, so anything
                      // that lives only in the bar cannot be reached there at
                      // all. Settings was put in the bar and was invisible on
                      // the one platform it was tested on.
                      trailing: Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: IconButton(
                              tooltip: 'Podešavanja',
                              icon: const Icon(Icons.settings_outlined,
                                  color: Colors.white70),
                              onPressed: () =>
                                  context.push(AppRoutes.preferences),
                            ),
                          ),
                        ),
                      ),
                      // The AppBar is null in landscape, and the bell lived in
                      // it — so on Windows, which is always landscape, there
                      // was no way to reach notifications at all. The rail is
                      // the only thing that survives this layout.
                      leading: widget.session.isGuest
                          ? null
                          : Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 8),
                              child: IconButton(
                                tooltip: 'Notifikacije i Pozivnice',
                                icon: Badge(
                                  isLabelVisible: _unreadNotifications > 0,
                                  label: Text('$_unreadNotifications'),
                                  child: const Icon(Icons.notifications,
                                      color: Colors.amberAccent),
                                ),
                                onPressed: _showNotificationsDialog,
                              ),
                            ),
                      destinations: const [
                        NavigationRailDestination(
                            icon: Icon(Icons.dashboard_outlined),
                            selectedIcon: Icon(Icons.dashboard),
                            label: Text('Početna')),
                        NavigationRailDestination(
                            icon: Icon(Icons.school_outlined),
                            selectedIcon: Icon(Icons.school),
                            label: Text('Časovi')),
                        NavigationRailDestination(
                            icon: Icon(Icons.library_books_outlined),
                            selectedIcon: Icon(Icons.library_books),
                            label: Text('Biblioteka')),
                        NavigationRailDestination(
                            icon: Icon(Icons.people_outline),
                            selectedIcon: Icon(Icons.people),
                            label: Text('Ljudi')),
                      ],
                    ),
                  if (isWide || isLandscape)
                    const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: pages,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: (isWide || isLandscape)
            ? null
            : NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _selectTab,
                destinations: const [
                  NavigationDestination(
                      icon: Icon(Icons.psychology_outlined),
                      selectedIcon: Icon(Icons.psychology),
                      label: 'Trening'),
                  NavigationDestination(
                      icon: Icon(Icons.school_outlined),
                      selectedIcon: Icon(Icons.school),
                      label: 'Časovi'),
                  NavigationDestination(
                      icon: Icon(Icons.library_books_outlined),
                      selectedIcon: Icon(Icons.library_books),
                      label: 'Biblioteka'),
                  NavigationDestination(
                      icon: Icon(Icons.people_outline),
                      selectedIcon: Icon(Icons.people),
                      label: 'Ljudi'),
                ],
              ),
      ),
    );
  }

  void _openStudioRoom() {
    context.push(AppRoutes.roomPath('STUDIO', role: 'host'));
  }

  /// Lets the user find their way back into a room after stepping away from
  /// it (back button, switching tabs, app restart) — see chess_game_screen's
  /// "Napusti sesiju" action for the only thing that clears this.
  Widget _buildActiveSessionBanner() {
    final gs = GameSessionService.instance;
    if (!gs.hasActiveSession) return const SizedBox.shrink();

    return Material(
      color: Colors.teal.shade700,
      child: InkWell(
        onTap: () =>
            context.push(AppRoutes.roomPath(gs.roomCode!, role: gs.role)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.podcasts, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Aktivna sesija (kod: ${gs.roomCode}) — dodirnite da nastavite',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () => context
                    .push(AppRoutes.roomPath(gs.roomCode!, role: gs.role)),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Nastavi sesiju'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
