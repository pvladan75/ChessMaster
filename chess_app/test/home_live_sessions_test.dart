// Home names the session; nobody types a code — docs/PLAN-SESIJA.md, §5.7.
//
// Typing a six-digit code was removed on 21.9.2026 for everybody. A student
// gets into a session by an invitation, or from this block: the sessions of the
// people who teach them, running now.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/trainer_panel/models/trainer_panel.dart';
import 'package:chess_app/services/room_session_api.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/home/dashboard_tab.dart';

Future<List<String>> _home(
  WidgetTester tester, {
  required List<LiveSession> sessions,
  Size size = const Size(1000, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final joined = <String>[];
  await tester.pumpWidget(MaterialApp(
    key: UniqueKey(),
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: Scaffold(
      body: HomeDashboardTab(
        userName: 'Ana',
        liveSessions: sessions,
        recordings: const [],
        isLoadingRecordings: false,
        panel: TrainerPanel.empty,
        onOpenPanelAssignment: (_) {},
        onOpenStudent: (_, __) {},
        hasTrainer: true,
        onOpenAssignments: () {},
        onOpenReviews: () {},
        onJoinSession: joined.add,
        onRefreshRecordings: () {},
        onOpenReplay: (_) {},
      ),
    ),
  ));
  await tester.pump();
  return joined;
}

final _block = find.byKey(const Key('home-live-sessions'));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the block on Home', () {
    testWidgets('nobody in a session: no block, and no code field anywhere',
        (tester) async {
      await _home(tester, sessions: const []);
      expect(_block, findsNothing);
      expect(find.byType(TextField), findsNothing,
          reason: 'there is still somewhere to type a room code');
      expect(find.textContaining('room code'), findsNothing);
    });

    testWidgets('a trainer in a session is named, and Join goes to that room',
        (tester) async {
      final joined = await _home(tester, sessions: const [
        LiveSession(roomCode: '923337', trainerName: 'Vladan'),
        LiveSession(roomCode: '516851', trainerName: 'Other trainer'),
      ]);

      expect(find.descendant(of: _block, matching: find.text('Vladan')),
          findsOneWidget);
      // The second row, so that „the first one" cannot pass for „this one".
      await tester.tap(find.byKey(const ValueKey('home-join-516851')));
      await tester.pump();
      expect(joined, ['516851']);
    });

    testWidgets('a long name does not push Join off a 360 dp phone',
        (tester) async {
      await _home(tester,
          sessions: const [
            LiveSession(
                roomCode: '923337',
                trainerName: 'Aleksandra Đorđević-Petrović Stojanović'),
          ],
          size: const Size(360, 800));
      expect(tester.takeException(), isNull);
      final join =
          tester.getRect(find.byKey(const ValueKey('home-join-923337')));
      expect(join.right, lessThanOrEqualTo(360));
      expect(join.width, greaterThan(60));
    });
  });

  group('GET /rooms/live', () {
    RoomSessionApi api(http.Response Function(http.Request) answer,
        [List<http.Request>? asked]) {
      return RoomSessionApi(
          authToken: 'tok',
          client: MockClient((req) async {
            asked?.add(req);
            return answer(req);
          }));
    }

    test('the rows are read, and the request is the one the server mounts',
        () async {
      final asked = <http.Request>[];
      final sessions = await api(
              (_) => http.Response(
                  jsonEncode({
                    'sessions': [
                      {'roomCode': '923337', 'trainerName': 'Vladan'},
                      {'trainerName': 'No code, so no door'},
                    ]
                  }),
                  200),
              asked)
          .live();

      expect(sessions.map((s) => (s.roomCode, s.trainerName)),
          [('923337', 'Vladan')]);
      expect(asked.single.method, 'GET');
      expect(asked.single.url.path, '/rooms/live');
      expect(asked.single.headers['Authorization'], 'Bearer tok');
    });

    test('a server that fails, or says something else, draws nothing',
        () async {
      expect(await api((_) => http.Response('boom', 500)).live(), isEmpty);
      expect(await api((_) => http.Response('[]', 200)).live(), isEmpty);
      expect(await api((_) => http.Response('not json', 200)).live(), isEmpty);
    });
  });
}
