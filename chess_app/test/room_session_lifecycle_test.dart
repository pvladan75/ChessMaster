// A saved session that is no longer a session — phase 1 of
// docs/PLAN-SESIJA.md.
//
// Reported live on 21.9.2026: two accounts in two different rooms, one of them
// held there by a room the app remembered and the server had no reason to keep.
// The save was cleared by the Leave button and by nothing else.
//
// Rule 7: the client is faked, not the method, and the request is asserted —
// a fake `state()` could not see the question go to the wrong room.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/services/game_session_service.dart';
import 'package:chess_app/services/room_session_api.dart';

/// Answers `/rooms/<code>/state` from [states]; anything else is a 404.
/// A state of `null` is a server that fails.
({RoomSessionApi api, List<http.Request> asked}) _server(
    Map<String, String?> states) {
  final asked = <http.Request>[];
  final client = MockClient((req) async {
    asked.add(req);
    final m = RegExp(r'^/rooms/(\w+)/state$').firstMatch(req.url.path);
    if (m != null && req.method == 'GET') {
      final state = states[m.group(1)];
      if (state == null) return http.Response('boom', 500);
      return http.Response(jsonEncode({'state': state}), 200);
    }
    if (RegExp(r'^/rooms/\w+/end$').hasMatch(req.url.path) &&
        req.method == 'POST') {
      return http.Response(jsonEncode({'ended': true}), 200);
    }
    return http.Response('no', 404);
  });
  return (api: RoomSessionApi(authToken: 'tok', client: client), asked: asked);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final gs = GameSessionService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await gs.clear();
  });

  test('a saved room that has ended is forgotten, on the device too', () async {
    await gs.setActive('856933', 'ucenik');
    final s = _server({'856933': 'ended'});

    expect(await gs.reconcile(s.api), isTrue);

    expect(gs.hasActiveSession, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('active_room_code'), isNull,
        reason: 'forgotten in memory and back after a restart');
    expect(s.asked.single.url.path, '/rooms/856933/state');
    expect(s.asked.single.headers['Authorization'], 'Bearer tok');
  });

  test('a room that refuses this account is forgotten as well', () async {
    await gs.setActive('856933', 'ucenik');
    expect(await gs.reconcile(_server({'856933': 'not-yours'}).api), isTrue);
    expect(gs.hasActiveSession, isFalse);
  });

  test('a live room is kept', () async {
    await gs.setActive('192803', 'trener');
    expect(await gs.reconcile(_server({'192803': 'live'}).api), isFalse);
    expect(gs.roomCode, '192803');
    expect(gs.role, 'trener');
  });

  test('a server that cannot be asked is not an ended session', () async {
    await gs.setActive('192803', 'trener');
    expect(await gs.reconcile(_server({'192803': null}).api), isFalse);
    expect(gs.roomCode, '192803');
  });

  test('an answer nobody understands is not an ended session either', () async {
    await gs.setActive('192803', 'trener');
    expect(await gs.reconcile(_server({'192803': 'archived?'}).api), isFalse);
    expect(gs.roomCode, '192803');
  });

  test('with nothing saved, nothing is asked', () async {
    final s = _server({});
    expect(await gs.reconcile(s.api), isFalse);
    expect(s.asked, isEmpty);
  });

  test('a room reporting its own end does not wipe a different saved one',
      () async {
    await gs.setActive('192803', 'ucenik');
    await gs.clearIf('856933');
    expect(gs.roomCode, '192803');
    await gs.clearIf('192803');
    expect(gs.hasActiveSession, isFalse);
  });

  test('ending a session is a POST to that room', () async {
    final s = _server({});
    expect(await s.api.end('192803'), isTrue);
    expect(s.asked.single.method, 'POST');
    expect(s.asked.single.url.path, '/rooms/192803/end');
  });

  // Making way for another session — what replaced the dialog that refused
  // outright and offered only the way back into the remembered room.
  group('making way for another session', () {
    /// Records the question and answers it with [answer].
    ({Future<bool?> Function(String) ask, List<String> asked}) question(
        bool? answer) {
      final asked = <String>[];
      return (
        ask: (code) async {
          asked.add(code);
          return answer;
        },
        asked: asked
      );
    }

    test('the room of an old invitation does not stand in the way of a new one',
        () async {
      // 21.9.2026, word for word: 856933 remembered, 192803 is the invitation.
      await gs.setActive('856933', 'ucenik');
      final q = question(false);

      final clear = await gs.makeWayFor(
          targetRoomCode: '192803',
          api: _server({'856933': 'ended'}).api,
          askToLeave: q.ask);

      expect(clear, isTrue);
      expect(q.asked, isEmpty,
          reason: 'a dead room is forgotten without asking');
      expect(gs.hasActiveSession, isFalse);
    });

    test('a live session of another trainer is left only on a yes', () async {
      await gs.setActive('856933', 'ucenik');
      final no = question(false);
      expect(
          await gs.makeWayFor(
              targetRoomCode: '192803',
              api: _server({'856933': 'live'}).api,
              askToLeave: no.ask),
          isFalse);
      expect(no.asked, ['856933']);
      expect(gs.roomCode, '856933',
          reason: 'Cancel must leave it where it was');

      final yes = question(true);
      expect(
          await gs.makeWayFor(
              targetRoomCode: '192803',
              api: _server({'856933': 'live'}).api,
              askToLeave: yes.ask),
          isTrue);
      expect(gs.hasActiveSession, isFalse);
    });

    test('a dismissed question is a no', () async {
      await gs.setActive('856933', 'ucenik');
      expect(
          await gs.makeWayFor(
              targetRoomCode: '192803',
              api: _server({'856933': 'live'}).api,
              askToLeave: question(null).ask),
          isFalse);
      expect(gs.roomCode, '856933');
    });

    test('going back into the remembered room asks nothing of anybody',
        () async {
      await gs.setActive('192803', 'ucenik');
      final s = _server({'192803': 'live'});
      final q = question(false);
      expect(
          await gs.makeWayFor(
              targetRoomCode: '192803', api: s.api, askToLeave: q.ask),
          isTrue);
      expect(s.asked, isEmpty);
      expect(q.asked, isEmpty);
      expect(gs.roomCode, '192803');
    });

    test('a trainer starting a new session is not asked about their own',
        () async {
      // The server ends it for everybody when the new one is made.
      await gs.setActive('192803', 'trener');
      final q = question(false);
      expect(
          await gs.makeWayFor(
              targetRoomCode: null,
              api: _server({'192803': 'live'}).api,
              askToLeave: q.ask),
          isTrue);
      expect(q.asked, isEmpty);
      expect(gs.hasActiveSession, isFalse);
    });

    test(
        'a student starting a session of their own is asked about the one '
        'they are in', () async {
      await gs.setActive('856933', 'ucenik');
      final q = question(false);
      expect(
          await gs.makeWayFor(
              targetRoomCode: null,
              api: _server({'856933': 'live'}).api,
              askToLeave: q.ask),
          isFalse);
      expect(q.asked, ['856933']);
    });

    test('a trainer joining another room is asked about their own', () async {
      // Joining ends nothing on the server, so their students are still in it.
      await gs.setActive('192803', 'trener');
      final q = question(false);
      expect(
          await gs.makeWayFor(
              targetRoomCode: '555555',
              api: _server({'192803': 'live'}).api,
              askToLeave: q.ask),
          isFalse);
      expect(q.asked, ['192803']);
    });
  });
}
