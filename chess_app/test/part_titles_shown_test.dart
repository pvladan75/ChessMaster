// A part the trainer did not name is „Part 3" — on every screen that shows one.
//
// It was „Deo 3" until 11.9.2026: the one Serbian word the English pivot left
// in the studio, because it carries no letter the Serbian-text gate can see.
// The studio writes „Part N" now, and rewrites an old stored „Deo N" the next
// time the tutorial is saved — but every tutorial already on the server keeps
// its stored name until then, so each screen that shows a stored name reads it
// through `shownPartTitle`. This file drives every one of those screens with a
// tutorial stored the old way; the rule itself is pinned in
// `tutorial_section_titles_test.dart`.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/chess_game_screen.dart';

const _fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

final _trainer = UserSession(
  token: 't',
  id: 7,
  email: 'a@b.c',
  name: 'Trener',
  role: 'trener',
);

/// Two parts stored with the old generated names.
final _oldSteps = [
  {'id': 'aaaa1111', 'fen': _fen, 'title': 'Deo 1', 'kind': 'show'},
  {'id': 'bbbb2222', 'fen': _fen, 'title': 'Deo 2', 'kind': 'show'},
];

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await TutorialDraftService.instance.clear();
  });

  group('the room', () {
    testWidgets('loads, steps and lists a tutorial\'s parts as „Part N"',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Since phase 3b the column lists the shelf (`/library/positions`) and
      // reads the tutorial's row (`/lessons/42`) when it is tapped.
      final client = MockClient((req) async {
        if (req.method == 'GET' && req.url.path.endsWith('/labels')) {
          return http.Response('[]', 200);
        }
        if (req.method == 'GET' &&
            req.url.path.endsWith('/library/positions')) {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'kind': 'tutorial',
                  'id': '42',
                  'title': 'Opozicija',
                  'fen': _oldSteps.first['fen'],
                  'partsCount': 2,
                },
              ],
            }),
            200,
          );
        }
        if (req.method == 'GET' && req.url.path.endsWith('/lessons/42')) {
          return http.Response(
            jsonEncode({
              'id': 42,
              'title': 'Opozicija',
              'tags': <String>[],
              'position_list': _oldSteps,
            }),
            200,
          );
        }
        return http.Response('{}', 200);
      });
      final api = LessonApiService(authToken: 'tok', client: client);

      await tester.pumpWidget(MaterialApp(
        home: ChessGamePage(
          userSession: _trainer,
          roomCode: 'STUDIO',
          initialRole: 'trener',
          lessonApi: api,
          positionLibrary:
              PositionLibraryService(authToken: 'tok', client: client),
        ),
      ));
      await tester.pumpAndSettle();

      // The room says „Position loaded" first and this second, one message
      // after the other, so it is waited for rather than expected at once.
      Future<bool> said(String text) async {
        for (var i = 0; i < 15; i++) {
          if (find.textContaining(text).evaluate().isNotEmpty) return true;
          await tester.pump(const Duration(seconds: 1));
        }
        return false;
      }

      await tester.tap(find.text('Opozicija').first);
      await tester.pump();
      expect(await said('from tutorial: "Part 1"'), isTrue);

      await tester.tap(find.byTooltip('Next step'));
      await tester.pump();
      expect(await said('Step 2/2: "Part 2"'), isTrue);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.tap(find.byTooltip('Jump to step'));
      await tester.pumpAndSettle();
      expect(find.text('1. Part 1'), findsOneWidget);
      expect(find.text('2. Part 2'), findsOneWidget);
      expect(find.textContaining('Deo'), findsNothing);

      await _close(tester);
    });
  });
}
