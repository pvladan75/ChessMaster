// The endgame trainer writes every outcome to the attempt log
// (docs/PLAN-NAPREDAK-VEZBI.md §4) and, in retry mode, serves the failed
// queue by id instead of the ordinary filtered fetch.
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
import 'package:chess_app/features/endgame_trainer/models/endgame_puzzle.dart';
import 'package:chess_app/features/endgame_trainer/screens/endgame_trainer_screen.dart';
import 'package:chess_app/features/endgame_trainer/services/endgame_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

class _FakeEndgameApi extends EndgameApiService {
  _FakeEndgameApi(this.result, {this.byIdResult}) : super(authToken: '');

  final EndgameFetchResult result;
  final EndgameFetchResult? byIdResult;
  final List<String> byIdRequests = [];

  @override
  Future<EndgameFetchResult> fetchNext({
    String? type,
    EndgameMode? mode,
    String? difficulty,
    int? maxPieces,
    int? minPawns,
    String? excludeId,
    String? material,
    String? band,
    bool oppositeOnly = false,
    bool includeOnline = false,
  }) async =>
      result;

  @override
  Future<EndgameFetchResult> fetchById(String id) async {
    byIdRequests.add(id);
    return byIdResult ?? result;
  }
}

EndgamePuzzle drawPuzzle({String id = 'eg_keys'}) => EndgamePuzzle.fromJson({
      'puzzle_id': id,
      'fen': '8/5pk1/8/8/8/8/5PK1/r7 b - - 0 55',
      'type': 'PawnEnding',
      'mode': 'draw',
      'winning_moves': ['a1f1', 'a1e1'],
      'solution': ['a1f1', 'g2g3'],
      'piece_count': 5,
      'pawn_count': 1,
      'source': 'syzygy',
      'difficulty': 'easy',
    });

UserSession session() => UserSession(
    token: 't', id: 1, email: 'a@b', name: 'Test', role: 'korisnik');

void main() {
  Widget wrap(Widget child) => MaterialApp(home: child);

  Offset squareOf(WidgetTester tester, String name) {
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

  testWidgets('solving records solved:true, hinted:false at /attempt',
      (tester) async {
    final sent = <http.Request>[];
    await tester.pumpWidget(wrap(EndgameTrainerScreen(
      session: session(),
      api: _FakeEndgameApi(
          EndgameFetchResult(EndgameFetchOutcome.ok, drawPuzzle())),
      attemptApi: PuzzleAttemptApi(
        authToken: 't',
        client: MockClient((req) async {
          sent.add(req);
          return http.Response('{"success":true}', 200);
        }),
      ),
    )));
    await tester.pumpAndSettle();

    await tester.tapAt(squareOf(tester, 'a1'));
    await tester.pumpAndSettle();
    await tester.tapAt(squareOf(tester, 'f1'));
    await tester.pumpAndSettle();

    expect(sent, hasLength(1));
    expect(sent.single.url.path, endsWith('/api/puzzles/attempt'));
    expect(bodyOf(sent.single), {
      'puzzleId': 'eg_keys',
      'solved': true,
      'skipped': false,
      'hinted': false,
      'source': 'endgame',
    });
  });

  testWidgets('Skip before any verdict records skipped:true', (tester) async {
    final sent = <http.Request>[];
    await tester.pumpWidget(wrap(EndgameTrainerScreen(
      session: session(),
      api: _FakeEndgameApi(
          EndgameFetchResult(EndgameFetchOutcome.ok, drawPuzzle())),
      attemptApi: PuzzleAttemptApi(
        authToken: 't',
        client: MockClient((req) async {
          sent.add(req);
          return http.Response('{"success":true}', 200);
        }),
      ),
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(sent, hasLength(1));
    expect(bodyOf(sent.single), {
      'puzzleId': 'eg_keys',
      'solved': false,
      'skipped': true,
      'hinted': false,
      'source': 'endgame',
    });
  });

  testWidgets('retry mode asks retryIds(endgame) then serves each by id',
      (tester) async {
    final sent = <http.Request>[];
    final fakeApi = _FakeEndgameApi(
      const EndgameFetchResult(EndgameFetchOutcome.unavailable),
      byIdResult:
          EndgameFetchResult(EndgameFetchOutcome.ok, drawPuzzle(id: 'eg_late')),
    );
    await tester.pumpWidget(wrap(EndgameTrainerScreen(
      session: session(),
      retry: true,
      api: fakeApi,
      attemptApi: PuzzleAttemptApi(
        authToken: 't',
        client: MockClient((req) async {
          sent.add(req);
          return http.Response(
              jsonEncode({
                'source': 'endgame',
                'ids': ['eg_late', 'eg_early']
              }),
              200);
        }),
      ),
    )));
    await tester.pumpAndSettle();

    expect(sent, hasLength(1));
    expect(sent.single.url.path, endsWith('/api/puzzles/retry'));
    expect(sent.single.url.queryParameters, {'source': 'endgame'});
    expect(fakeApi.byIdRequests, ['eg_late']);
    expect(find.text('Endgames — retry'), findsOneWidget);
  });

  testWidgets('an empty retry queue says so, without touching the fetch',
      (tester) async {
    final fakeApi = _FakeEndgameApi(
      const EndgameFetchResult(EndgameFetchOutcome.unavailable),
    );
    await tester.pumpWidget(wrap(EndgameTrainerScreen(
      session: session(),
      retry: true,
      api: fakeApi,
      attemptApi: PuzzleAttemptApi(
        authToken: 't',
        client: MockClient((req) async =>
            http.Response(jsonEncode({'source': 'endgame', 'ids': []}), 200)),
      ),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Nothing to retry.'), findsOneWidget);
    expect(fakeApi.byIdRequests, isEmpty);
  });
}
