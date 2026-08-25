import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:chess_app/constants.dart';
import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/services/session_service.dart';

/// A trainer's named list of students.
class StudentGroup {
  const StudentGroup({
    required this.id,
    required this.name,
    required this.members,
  });

  final int id;
  final String name;

  /// How many people are in it, so the list can be read without opening each.
  final int members;

  factory StudentGroup.fromJson(Map<String, dynamic> json) => StudentGroup(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
        members: (json['members'] as num?)?.toInt() ?? 0,
      );
}

/// A person, by name. Deliberately no address: most of the people in these
/// lists are children, and a list of people is not the place for their emails.
class NamedPerson {
  const NamedPerson({required this.id, required this.name});

  final int id;
  final String name;

  factory NamedPerson.fromJson(Map<String, dynamic> json) => NamedPerson(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? 'Korisnik',
      );
}

/// One entry on a room's guest list: a whole group, or one student.
class RoomGuest {
  const RoomGuest({
    required this.kind,
    required this.id,
    required this.name,
  });

  /// `group` or `student`. Both live on the same list, because the trainer
  /// asked for both and one mechanism is enough.
  final String kind;
  final int id;
  final String name;

  bool get isGroup => kind == 'group';

  factory RoomGuest.fromJson(Map<String, dynamic> json) => RoomGuest(
        kind: json['kind'] as String? ?? 'student',
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
      );
}

/// Groups of students, and the guest list of a room.
///
/// Both live here because they are the same job seen twice: a group is a list
/// of people named once so it does not have to be assembled again every
/// Tuesday, and a room's guest list is what that group is *for*.
class GroupApiService {
  GroupApiService({http.Client? client}) : _client = client;

  final http.Client? _client;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${SessionService.instance.current.token}',
        'Content-Type': 'application/json',
      };

  Future<List<StudentGroup>> list() async {
    final res = await _send(() => _get(Uri.parse('$backendUrl/groups')));
    if (res.body == null) return const [];
    return ((res.body!['groups'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => StudentGroup.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Makes a group, or says why not — a taken name and a server that is not
  /// running are fixed in different places.
  Future<({StudentGroup? group, String? error})> create(String name) async {
    final res = await _send(() => _post('$backendUrl/groups', {'name': name}));
    if (res.body == null) return (group: null, error: res.error);
    return (group: StudentGroup.fromJson(res.body!), error: null);
  }

  Future<String?> rename(int groupId, String name) async {
    final res = await _send(
        () => _patch('$backendUrl/groups/$groupId', {'name': name}));
    return res.error;
  }

  Future<String?> remove(int groupId) async {
    final res =
        await _send(() => _delete(Uri.parse('$backendUrl/groups/$groupId')));
    return res.error;
  }

  Future<List<NamedPerson>> members(int groupId) async {
    final res = await _send(
        () => _get(Uri.parse('$backendUrl/groups/$groupId/members')));
    if (res.body == null) return const [];
    return ((res.body!['members'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => NamedPerson.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<String?> addMember(int groupId, int studentId) async {
    final res = await _send(() =>
        _post('$backendUrl/groups/$groupId/members', {'studentId': studentId}));
    return res.error;
  }

  Future<String?> removeMember(int groupId, int studentId) async {
    final res = await _send(() =>
        _delete(Uri.parse('$backendUrl/groups/$groupId/members/$studentId')));
    return res.error;
  }

  /// The trainer's own students, names only — the same list the home screen
  /// shows, fetched here so a dialog that needs it does not have to be handed
  /// it through three widgets.
  Future<List<Map<String, dynamic>>> myStudents() async {
    final res =
        await _send(() => _get(Uri.parse('$backendUrl/trainer/students')));
    if (res.body == null) return const [];
    return ((res.body!['students'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<RoomGuest>> roomGuests(String roomCode) async {
    final res = await _send(
        () => _get(Uri.parse('$backendUrl/groups/rooms/$roomCode/guests')));
    if (res.body == null) return const [];
    return ((res.body!['guests'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => RoomGuest.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Puts groups and people on the room's guest list.
  ///
  /// The first entry narrows the room to that list — which is the whole point
  /// of inviting a group — so the screen above says so before it is used.
  Future<String?> invite(
    String roomCode, {
    List<int> groupIds = const [],
    List<int> userIds = const [],
  }) async {
    final res =
        await _send(() => _post('$backendUrl/groups/rooms/$roomCode/guests', {
              'groupIds': groupIds,
              'userIds': userIds,
            }));
    return res.error;
  }

  Future<String?> uninvite(
    String roomCode, {
    int? groupId,
    int? userId,
  }) async {
    final uri = Uri.parse('$backendUrl/groups/rooms/$roomCode/guests').replace(
      queryParameters: {
        if (groupId != null) 'groupId': '$groupId',
        if (userId != null) 'userId': '$userId',
      },
    );
    final res = await _send(() => _delete(uri));
    return res.error;
  }

  Future<http.Response> _get(Uri uri) =>
      _client?.get(uri, headers: _headers) ?? http.get(uri, headers: _headers);

  Future<http.Response> _delete(Uri uri) =>
      _client?.delete(uri, headers: _headers) ??
      http.delete(uri, headers: _headers);

  Future<http.Response> _post(String url, Map<String, dynamic> body) {
    final uri = Uri.parse(url);
    final encoded = jsonEncode(body);
    return _client?.post(uri, headers: _headers, body: encoded) ??
        http.post(uri, headers: _headers, body: encoded);
  }

  Future<http.Response> _patch(String url, Map<String, dynamic> body) {
    final uri = Uri.parse(url);
    final encoded = jsonEncode(body);
    return _client?.patch(uri, headers: _headers, body: encoded) ??
        http.patch(uri, headers: _headers, body: encoded);
  }

  /// One place where a failed call becomes a reason rather than a silence.
  ///
  /// The server already distinguishes "not yours" from "name taken" from "that
  /// student never accepted you"; throwing all three away and showing one
  /// sentence would be the same fault this project keeps meeting, one layer up.
  Future<({Map<String, dynamic>? body, String? error})> _send(
      Future<http.Response> Function() call) async {
    try {
      final res = await call().timeout(const Duration(seconds: 12));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = res.body.isEmpty ? {} : jsonDecode(res.body);
        return (
          body: decoded is Map
              ? Map<String, dynamic>.from(decoded)
              : <String, dynamic>{},
          error: null,
        );
      }
      AppLogger.log('[Grupe] ⚠️ ${res.statusCode}: ${res.body}');
      return (body: null, error: _errorOf(res));
    } catch (e) {
      AppLogger.log('[Grupe] ❌ $e');
      return (
        body: null,
        error: 'Server nije dostupan — proverite da li backend radi.',
      );
    }
  }

  String _errorOf(http.Response res) {
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } catch (_) {
      // A body that is not JSON says nothing about why.
    }
    return 'Server je odgovorio ${res.statusCode}.';
  }

  @visibleForTesting
  static GroupApiService withClient(http.Client client) =>
      GroupApiService(client: client);
}
