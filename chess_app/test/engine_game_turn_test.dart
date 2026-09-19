// Who is to move in „play it out" — the owner's suggestion of 20.9.2026.
//
// He set an exercise where the student plays Black and White is to move. It
// worked: the board came up Black-side down and the engine played first. But
// *he* knew to wait for that move; a student sees a still board with his
// pieces at the bottom and no sign that anything is about to happen. The
// banner now says whose move it is, in words and in the icon's shape.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/models/engine_game_task.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/ai_studio_screen.dart';
import 'package:chess_app/theme/app_colors.dart';

import 'support/landscape.dart' show loadRoboto;

const _fen = '4k3/8/8/8/8/8/8/4K2R w K - 0 1';

void main() {
  setUpAll(loadRoboto);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test("the words: mine, the engine's, and nothing once it is over", () {
    expect(engineGameTurnWords(finished: false, opponentToMove: false),
        'Your move');
    expect(engineGameTurnWords(finished: false, opponentToMove: true),
        'The engine is thinking…');
    expect(engineGameTurnWords(finished: true, opponentToMove: true), isNull);
    expect(engineGameTurnWords(finished: true, opponentToMove: false), isNull);
  });

  Future<void> pump(WidgetTester tester, Size size, String side) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: AiStudioScreen(
          userSession: UserSession(
              token: 't', id: 1, email: 's@example.com', name: 'S', role: 'u'),
          initialCategory: 'engine_game',
          engineGameTask: EngineGameTask.fromJson(
              {'fen': _fen, 'side': side, 'goal': 'hold', 'plyCap': 40})!,
          assignmentId: 42,
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  String shown(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const Key('engine-game-turn')).first)
      .data!;

  for (final size in [const Size(360, 640), const Size(800, 400)]) {
    final at = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets("White to move, the student is Black: the engine's, at $at",
        (tester) async {
      await http.runWithClient(() async {
        await pump(tester, size, 'b');
        expect(tester.takeException(), isNull);
        expect(shown(tester), 'The engine is thinking…');
        expect(find.byIcon(Icons.hourglass_top), findsWidgets);
      }, () => MockClient((_) async => http.Response('{}', 200)));
    });

    testWidgets('White to move, the student is White: his, at $at',
        (tester) async {
      await http.runWithClient(() async {
        await pump(tester, size, 'w');
        expect(tester.takeException(), isNull);
        expect(shown(tester), 'Your move');
        expect(find.byIcon(Icons.hourglass_top), findsNothing);

        await tester.ensureVisible(find.text('Resign').first);
        await tester.tap(find.text('Resign').first);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('engine-game-turn')), findsNothing,
            reason: "a finished game is nobody's move");
      }, () => MockClient((_) async => http.Response('{}', 200)));
    });
  }
}
