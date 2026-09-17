// Tactics writes every outcome through `TacticsApiService.submitAttempt`
// (docs/PLAN-NAPREDAK-VEZBI.md §4): a hinted solve, a skip on an unfinished
// free puzzle, and — in retry mode — the failed queue served by id.
//
// Fake the client, assert the request (rule 7). `TacticsApiService` and
// `TacticsTrainerScreen` gained an injectable client/service for exactly this
// (they had none before; see the note in wrong_move_board_test.dart, which
// this batch's change makes stale for tactics).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/core/services/puzzle_attempt_api.dart';
import 'package:chess_app/features/tactics_trainer/screens/tactics_trainer_screen.dart';
import 'package:chess_app/features/tactics_trainer/services/tactics_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

Widget wrap(Widget child) => MaterialApp(home: child);

UserSession session() => UserSession(
    token: 't', id: 1, email: 'a@b', name: 'Test', role: 'korisnik');

/// White to move, mate in one: the adaptive endpoint's answer for every test
/// here. Setup move h7h6 (black, played on the stored fen) hands White the
/// position; a1a8 is the only solution.
const _adaptiveBody = '''
{
  "puzzle": {
    "puzzle_id": "p1",
    "fen": "6k1/5ppp/8/8/8/8/8/R5K1 b - - 0 1",
    "setup_move": "h7h6",
    "solution": ["a1a8"],
    "rating": 1200,
    "themes": ["mateIn1"]
  },
  "selection": {"targetRating": 1200}
}
''';

Offset squareAt(WidgetTester tester, String name, {required bool flipped}) {
  final board = find.byType(ChessBoardWithOverlay);
  final rect = tester.getRect(board);
  final square = rect.width / 8;
  final file = name.codeUnitAt(0) - 'a'.codeUnitAt(0);
  final rank = name.codeUnitAt(1) - '1'.codeUnitAt(0);
  final col = flipped ? 7 - file : file;
  final row = flipped ? rank : 7 - rank;
  return rect.topLeft + Offset((col + 0.5) * square, (row + 0.5) * square);
}

Map<String, dynamic> bodyOf(http.Request r) =>
    jsonDecode(r.body) as Map<String, dynamic>;

void main() {
  testWidgets('a hinted solve records solved:false, hinted:true',
      (tester) async {
    final sent = <http.Request>[];
    await tester.pumpWidget(wrap(TacticsTrainerScreen(
      session: session(),
      api: TacticsApiService(
        authToken: 't',
        client: MockClient((req) async {
          if (req.url.path.endsWith('/api/puzzles/attempt')) sent.add(req);
          return http.Response(_adaptiveBody, 200);
        }),
      ),
    )));
    await tester.pumpAndSettle();

    // White to move after the setup move, board not flipped.
    await tester.tap(find.text('Hint'));
    await tester.pumpAndSettle();

    await tester.tapAt(squareAt(tester, 'a1', flipped: false));
    await tester.pumpAndSettle();
    await tester.tapAt(squareAt(tester, 'a8', flipped: false));
    await tester.pumpAndSettle();

    expect(sent, hasLength(1));
    expect(sent.single.url.path, endsWith('/api/puzzles/attempt'));
    final body = bodyOf(sent.single);
    expect(body['puzzleId'], 'p1');
    expect(body['solved'], false, reason: 'a hinted solve does not count');
    expect(body['hinted'], true);
    expect(body['skipped'], false);
  });

  testWidgets('Skip on an unfinished free puzzle records skipped:true',
      (tester) async {
    final sent = <http.Request>[];
    await tester.pumpWidget(wrap(TacticsTrainerScreen(
      session: session(),
      api: TacticsApiService(
        authToken: 't',
        client: MockClient((req) async {
          if (req.url.path.endsWith('/api/puzzles/attempt')) sent.add(req);
          return http.Response(_adaptiveBody, 200);
        }),
      ),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(sent, hasLength(1));
    final body = bodyOf(sent.single);
    expect(body['puzzleId'], 'p1');
    expect(body['solved'], false);
    expect(body['skipped'], true);
  });

  testWidgets(
      'retry mode asks retryIds(lichess), then serves each by id, and the '
      'app bar says Retry', (tester) async {
    final byIdRequests = <String>[];
    await tester.pumpWidget(wrap(TacticsTrainerScreen(
      session: session(),
      retry: true,
      attemptApi: PuzzleAttemptApi(
        authToken: 't',
        client: MockClient((req) async {
          expect(req.url.path, endsWith('/api/puzzles/retry'));
          expect(req.url.queryParameters, {'source': 'lichess'});
          return http.Response(
              jsonEncode({
                'source': 'lichess',
                'ids': ['p9']
              }),
              200);
        }),
      ),
      api: TacticsApiService(
        authToken: 't',
        client: MockClient((req) async {
          byIdRequests.add(req.url.path);
          return http.Response(_adaptiveBody, 200);
        }),
      ),
    )));
    await tester.pumpAndSettle();

    expect(byIdRequests, ['/api/puzzles/by-id/p9']);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('an empty retry queue says so, without any by-id request',
      (tester) async {
    final byIdRequests = <String>[];
    await tester.pumpWidget(wrap(TacticsTrainerScreen(
      session: session(),
      retry: true,
      attemptApi: PuzzleAttemptApi(
        authToken: 't',
        client: MockClient((req) async =>
            http.Response(jsonEncode({'source': 'lichess', 'ids': []}), 200)),
      ),
      api: TacticsApiService(
        authToken: 't',
        client: MockClient((req) async {
          byIdRequests.add(req.url.path);
          return http.Response(_adaptiveBody, 200);
        }),
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Nothing to retry.'), findsOneWidget);
    expect(byIdRequests, isEmpty);
  });
}
