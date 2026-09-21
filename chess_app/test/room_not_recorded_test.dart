// A session with other people in it has no recording — phase 5a of
// docs/PLAN-SESIJA.md, sentence 5 of its §2.
//
// Not a disabled button: no button. The card, its socket events, the roster
// lock and the Agora capture left the room together; recording returns alone
// in Preparation (phase 5b). The server's half is held by
// `chess_backend/test/socket_contract.test.js` and
// `recording_writer_gone.test.js`; this is the screen's.
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

  for (final seat in ['trener', 'ucenik']) {
    testWidgets('the room offers no recording to the $seat seat',
        (tester) async {
      await _room(tester, role: seat);
      // The scan must be able to see the column the card used to sit in, or
      // its absence proves nothing.
      expect(find.byType(ChessGamePage), findsOneWidget);
      expect(find.text('Arrow drawing (Trainer)', skipOffstage: false),
          seat == 'trener' ? findsOneWidget : findsNothing);
      expect(
          find.textContaining(RegExp('record', caseSensitive: false),
              skipOffstage: false),
          findsNothing);
      await _close(tester);
    });
  }
}
