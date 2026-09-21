// Who ends a session, and when the room may be left — phase 1 of
// docs/PLAN-SESIJA.md.
//
// Until 21.9.2026 every seat had „Leave session", which forgot the room on the
// device and left it live on the server for ever. Whoever started the session
// now ends it, for everybody; anybody else only leaves.
//
// What this cannot reach: `session_ended` arrives over Socket.IO, which a
// widget test has none of. The server's own contract test holds that the app
// listens for it; here the HTTP half stands alone. Stated, not papered over.
//
// Real font (rule 8): with the test font the room's right column overflows.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/chess_game_screen.dart';
import 'package:chess_app/services/game_session_service.dart';
import 'package:chess_app/services/room_session_api.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/theme/app_colors.dart';

import 'support/landscape.dart' show loadRoboto;

const _code = '192803';

final _end = find.byKey(const Key('room-end-session'));
final _leave = find.byKey(const Key('room-leave-session'));
final _confirm = find.byKey(const Key('room-end-session-confirm'));
final _home = find.text('HOME');

/// Opens the room on top of a Home, so that leaving it has somewhere to land
/// and staying in it can be told from leaving.
Future<List<http.Request>> _room(
  WidgetTester tester, {
  required String role,
  int endStatus = 200,
}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final asked = <http.Request>[];
  final client = MockClient((req) async {
    asked.add(req);
    if (req.url.path == '/rooms/$_code/end') {
      return http.Response(jsonEncode({'ended': true}), endStatus);
    }
    if (req.url.path.endsWith('/library/positions')) {
      return http.Response(jsonEncode({'items': []}), 200);
    }
    if (req.url.path == '/trainer/students') {
      return http.Response(jsonEncode({'students': []}), 200);
    }
    return http.Response('[]', 200);
  });

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Center(child: Text('HOME'))),
        routes: [
          GoRoute(
            path: 'room',
            builder: (_, __) => ChessGamePage(
              userSession: UserSession(
                  id: 1, token: 'tok', email: 'e', name: 'N', role: 'korisnik'),
              roomCode: _code,
              initialRole: role,
              lessonApi: LessonApiService(authToken: 'tok', client: client),
              positionLibrary:
                  PositionLibraryService(authToken: 'tok', client: client),
              groupApi: GroupApiService(client: client),
              roomSessionApi: RoomSessionApi(authToken: 'tok', client: client),
            ),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(MaterialApp.router(
    theme: ThemeData(fontFamily: 'Roboto')
        .copyWith(extensions: const [AppColorTokens.light]),
    routerConfig: router,
  ));
  router.push('/room');
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  return asked;
}

Iterable<http.Request> _endCalls(List<http.Request> asked) =>
    asked.where((r) => r.url.path == '/rooms/$_code/end');

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(loadRoboto);

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'remember_me': true,
      'user_token': 'tok',
      'user_id': 1,
      'user_email': 'e',
      'user_name': 'N',
      'user_role': 'korisnik',
    });
    await SessionService.instance.init();
    await GameSessionService.instance.clear();
  });

  testWidgets('whoever started the session ends it, and is not offered Leave',
      (tester) async {
    await _room(tester, role: 'trener');
    expect(_end, findsOneWidget);
    expect(_leave, findsNothing);
    await _close(tester);
  });

  testWidgets('a student leaves, and is offered no way to end it',
      (tester) async {
    await _room(tester, role: 'ucenik');
    expect(_leave, findsOneWidget);
    expect(_end, findsNothing);
    await _close(tester);
  });

  testWidgets('ending asks the server, then forgets the room and goes Home',
      (tester) async {
    final asked = await _room(tester, role: 'trener');
    expect(GameSessionService.instance.roomCode, _code,
        reason: 'the fixture must start from a saved session');

    await tester.tap(_end);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_endCalls(asked), isEmpty, reason: 'ended before it was confirmed');

    await tester.tap(_confirm);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(_endCalls(asked).single.method, 'POST');
    expect(GameSessionService.instance.hasActiveSession, isFalse);
    expect(_home, findsOneWidget);
    expect(find.byType(ChessGamePage), findsNothing);
    await _close(tester);
  });

  testWidgets('Stay ends nothing', (tester) async {
    final asked = await _room(tester, role: 'trener');
    await tester.tap(_end);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Stay'));
    await tester.pump(const Duration(seconds: 1));

    expect(_endCalls(asked), isEmpty);
    expect(find.byType(ChessGamePage), findsOneWidget);
    expect(GameSessionService.instance.roomCode, _code);
    await _close(tester);
  });

  testWidgets(
      'a session the server did not end is not walked away from, which is how '
      'two people ended up in two rooms', (tester) async {
    final asked = await _room(tester, role: 'trener', endStatus: 500);
    await tester.tap(_end);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(_confirm);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(_endCalls(asked), hasLength(1));
    expect(find.byType(ChessGamePage), findsOneWidget);
    expect(GameSessionService.instance.roomCode, _code,
        reason: 'the room is still live, so it is still the saved session');
    expect(find.textContaining('could not be ended'), findsOneWidget);
    await _close(tester);
  });
}
