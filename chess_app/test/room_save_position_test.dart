import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/lessons/models/lesson_step_line.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/chess_game_screen.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// The room's „Save position" writes a `fen` and a `pgn` that belong together.
///
/// Found by the architecture audit on 16.9.2026 (`docs/audit/app.md`, 2). It
/// sent `fen` from the board — wherever the trainer was standing — and `pgn`
/// exported from the root of the move tree. The reader replays the `pgn` from
/// the `fen`, so a line saved from anywhere but move zero had every move
/// rejected, while the screen said „saved successfully". It is the fault the
/// studio's „Napravi korak od ove pozicije" had on 6.9.2026, still alive in the
/// room; CLAUDE.md's rule for it is that one node answers for both fields and
/// the writer reads its own work back before saving.
///
/// Asserted on the request, read back through the reader the student's screen
/// uses.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'a line saved after two moves replays from the position it is saved with',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final saved = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path.endsWith('/lessons/save')) {
        saved.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
            jsonEncode({
              'id': 1,
              'lesson': {'id': 1}
            }),
            201);
      }
      return http.Response('[]', 200);
    });

    await tester.pumpWidget(MaterialApp(
      home: ChessGamePage(
        roomCode: 'STUDIO',
        userSession: UserSession(
            token: 't', id: 7, email: 'a@b.c', name: 'Trener', role: 'trener'),
        lessonApi: LessonApiService(authToken: 'tok', client: client),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    ChessBoardWithOverlay board() => tester.widget<ChessBoardWithOverlay>(
        find.byType(ChessBoardWithOverlay).first);
    // The way the board reports a move: it plays it on its controller, then
    // tells the screen.
    Future<void> play(String from, String to) async {
      board().controller.makeMove(from: from, to: to);
      board().onMove(from, to, '');
      await tester.pump(const Duration(milliseconds: 50));
    }

    await play('e2', 'e4');
    await play('e7', 'e5');

    final state = tester.state(find.byType(ChessGamePage)) as dynamic;
    await state.saveCurrentPosition('Open game', '', <String>[]);
    await tester.pump(const Duration(milliseconds: 200));

    expect(saved, hasLength(1));
    final fen = saved.single['fen'] as String;
    final pgn = saved.single['pgn'] as String;
    final reading = LessonStepLine.read(fen: fen, pgn: pgn);
    expect(reading.rejectedMoves, 0, reason: 'fen: $fen\npgn: $pgn');
    expect(pgn, contains('e4'));
    expect(pgn, contains('e5'));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
