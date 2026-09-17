// The blunder walk writes one attempt row per stop, to
// `PuzzleSource.blunderGame` (docs/PLAN-NAPREDAK-VEZBI.md §4): the move that
// held was found, "Show" was pressed, or the stop was walked past unanswered.
//
// Fake the client, assert the request (rule 7): every test here reads what
// was sent to `PuzzleAttemptApi`, not what a stub answered.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/core/services/puzzle_attempt_api.dart';
import 'package:chess_app/features/endgame_trainer/screens/blunder_walk_screen.dart';
import 'package:chess_app/features/endgame_trainer/services/endgame_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// Serves one game without a network — same fixture shape as
/// blunder_walk_screen_test.dart, with a numeric game id since
/// `PuzzleSource.blunderGameId` takes one.
class _FakeApi extends EndgameApiService {
  _FakeApi(this.result) : super(authToken: '');

  final GameFetchResult result;

  @override
  Future<GameFetchResult> fetchNextGame({
    int? minBlunders,
    int? maxBlunders,
    int? minElo,
    int? maxElo,
    String? material,
    String? excludeId,
    bool includeOnline = false,
  }) async =>
      result;
}

BlunderGame game() => BlunderGame.fromJson({
      'game_id': '42',
      'white': 'Seger, Ruediger',
      'black': 'Lambert, Andreas',
      'white_elo': 2416,
      'black_elo': 2204,
      'date': '2005.03.13',
      'start_fen': '8/8/k1K5/P6R/8/5r2/7P/8 b - - 1 59',
      'moves': ['Rd3', 'h4', 'Rd1', 'Rh6', 'Kxa5', 'Rc4'],
      'blunders': [
        {
          'ply': 0,
          'fen': '8/8/k1K5/P6R/8/5r2/7P/8 b - - 1 59',
          'side': 'black',
          'played': 'Rd3',
          'played_uci': 'f3d3',
          'should_play': ['Rb3', 'Rf2'],
          'should_play_uci': ['f3b3', 'f3f2'],
          'outcome_before': 'draw',
          'outcome_after': 'loss',
          'material': 'KRPPvKR',
        },
        {
          'ply': 1,
          'fen': '8/8/k1K5/P6R/8/3r4/7P/8 w - - 2 60',
          'side': 'white',
          'played': 'h4',
          'played_uci': 'h2h4',
          'should_play': ['Kc5'],
          'should_play_uci': ['c6c5'],
          'outcome_before': 'win',
          'outcome_after': 'draw',
          'material': 'KRPPvKR',
        },
      ],
    });

Widget wrap(Widget child) => MaterialApp(home: child);

UserSession session() => UserSession(
    token: 't', id: 1, email: 'a@b', name: 'Test', role: 'korisnik');

Offset squareAt(WidgetTester tester, String name) {
  final board = find.byType(ChessBoardWithOverlay);
  final widget = tester.widget<ChessBoardWithOverlay>(board);
  final rect = tester.getRect(board);
  final square = widget.boardSize / 8;
  final file = name.codeUnitAt(0) - 'a'.codeUnitAt(0);
  final rank = name.codeUnitAt(1) - '1'.codeUnitAt(0);
  final col = widget.boardOrientation == PlayerColor.black ? 7 - file : file;
  final row = widget.boardOrientation == PlayerColor.black ? rank : 7 - rank;
  return rect.topLeft + Offset((col + 0.5) * square, (row + 0.5) * square);
}

Map<String, dynamic> bodyOf(http.Request r) =>
    jsonDecode(r.body) as Map<String, dynamic>;

void main() {
  Future<List<http.Request>> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final sent = <http.Request>[];
    await tester.pumpWidget(wrap(BlunderWalkScreen(
      session: session(),
      api: _FakeApi(GameFetchResult(EndgameFetchOutcome.ok, game())),
      attemptApi: PuzzleAttemptApi(
        authToken: 't',
        client: MockClient((req) async {
          sent.add(req);
          return http.Response('{"success":true}', 200);
        }),
      ),
    )));
    await tester.pumpAndSettle();
    return sent;
  }

  testWidgets('the move that holds is found — solved:true, hinted:false',
      (tester) async {
    final sent = await pump(tester);

    await tester.tapAt(squareAt(tester, 'f3'));
    await tester.pumpAndSettle();
    await tester.tapAt(squareAt(tester, 'b3'));
    await tester.pumpAndSettle();

    expect(sent, hasLength(1));
    expect(sent.single.url.path, endsWith('/api/puzzles/attempt'));
    expect(bodyOf(sent.single), {
      'puzzleId': '42:0',
      'solved': true,
      'skipped': false,
      'hinted': false,
      'source': 'blunder_game',
    });
  });

  testWidgets('"Show" records solved:false, hinted:true', (tester) async {
    final sent = await pump(tester);

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    expect(sent, hasLength(1));
    expect(bodyOf(sent.single), {
      'puzzleId': '42:0',
      'solved': false,
      'skipped': false,
      'hinted': true,
      'source': 'blunder_game',
    });
  });

  testWidgets('"Skip" on the pending stop records skipped:true',
      (tester) async {
    final sent = await pump(tester);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(sent, hasLength(1));
    expect(bodyOf(sent.single), {
      'puzzleId': '42:0',
      'solved': false,
      'skipped': true,
      'hinted': false,
      'source': 'blunder_game',
    });
  });
}
