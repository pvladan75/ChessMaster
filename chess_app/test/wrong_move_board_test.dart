import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/endgame_trainer/models/endgame_puzzle.dart';
import 'package:chess_app/features/endgame_trainer/screens/endgame_trainer_screen.dart';
import 'package:chess_app/features/endgame_trainer/services/endgame_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// What happens after a wrong move.
///
/// Reported live on 27.8.2026, in the tactics trainer and seen again here: a
/// wrong answer left the position "failed" until a button was pressed, and
/// while it sat there the board still took drags — which every guard then
/// refused with a bare `return`, leaving the piece where the finger dropped it.
/// A few drags in, the board on screen and the position being solved were two
/// different things, for both colours.
///
/// The rule now: a wrong move puts the position back and lets the reader try
/// again immediately. That is what everybody pressed "Pokušaj ponovo" for.
///
/// Tested on the endgame trainer because its screen takes an injected API. The
/// tactics trainer builds its own and cannot be reached without a network, so
/// the same change there is a live check (item 41 in `docs/TODO-provera.md`).
class _FakeEndgameApi extends EndgameApiService {
  _FakeEndgameApi(this.result) : super(authToken: '');

  final EndgameFetchResult result;

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
  Future<bool> keepForLater({
    required String fen,
    required String title,
    required String description,
  }) async =>
      true;
}

/// Black to move, rook on a1: a1f1 and a1e1 hold the draw, everything else
/// loses it.
EndgamePuzzle drawPuzzle() => EndgamePuzzle.fromJson({
      'puzzle_id': 'eg_wrong_move',
      'fen': '8/5pk1/8/8/8/8/5PK1/r7 b - - 0 55',
      'type': 'RookVsPawn',
      'mode': 'draw',
      'winning_moves': ['a1f1', 'a1e1'],
      'solution': ['a1f1', 'g2g3'],
      'piece_count': 5,
      'pawn_count': 1,
      'source': 'syzygy',
      'difficulty': 'hard',
      'difficulty_score': 9,
    });

void main() {
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: EndgameTrainerScreen(
        session: UserSession(
            token: 't', id: 1, email: 'a@b', name: 'Test', role: 'korisnik'),
        api: _FakeEndgameApi(
          EndgameFetchResult(EndgameFetchOutcome.ok, drawPuzzle()),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder boardFinder() => find.byType(ChessBoardWithOverlay);

  String fenOf(WidgetTester tester) =>
      tester.widget<ChessBoardWithOverlay>(boardFinder()).controller.game.fen;

  /// A move the way the board itself produces one: the piece is already on its
  /// new square when the screen is told about it. That order is the whole
  /// point — it is why a screen that refuses a move has to put the board back.
  Future<void> move(WidgetTester tester, String from, String to) async {
    final board = tester.widget<ChessBoardWithOverlay>(boardFinder());
    board.controller.makeMove(from: from, to: to);
    board.onMove(from, to, '');
    await tester.pumpAndSettle();
  }

  testWidgets('a wrong move puts the position back', (tester) async {
    await open(tester);
    final start = fenOf(tester);

    await move(tester, 'a1', 'a2');

    expect(find.textContaining('ispušta').hitTestable(), findsNothing,
        reason: 'ovo je remi pozicija, ne dobitna');
    expect(find.textContaining('gubi remi'), findsOneWidget);
    expect(fenOf(tester), start,
        reason: 'na tabli mora da stoji pozicija koja se rešava');
  });

  testWidgets('the next move is accepted without pressing anything first',
      (tester) async {
    // The regression. The wrong answer used to leave the position `failed`,
    // which counts as complete, so every further move was refused until
    // "Pokušaj ponovo" was pressed — and refused moves stayed on the board.
    await open(tester);

    await move(tester, 'a1', 'a2');
    await move(tester, 'a1', 'f1');

    expect(find.textContaining('gubi remi'), findsNothing,
        reason: 'tačan potez posle greške mora da bude prihvaćen');
    expect(fenOf(tester), isNot('8/5pk1/8/8/8/8/5PK1/r7 b - - 0 55'),
        reason: 'tačan potez mora da se odigra na tabli');
  });

  testWidgets('there is no retry button left to press', (tester) async {
    await open(tester);
    await move(tester, 'a1', 'a2');

    expect(find.text('Pokušaj ponovo'), findsNothing);
    // And the board is still live, which is the whole point of removing it.
    expect(
      tester.widget<ChessBoardWithOverlay>(boardFinder()).isAllowedToMove,
      isTrue,
    );
  });

  testWidgets('a solve after a mistake is still a solve with a mistake',
      (tester) async {
    // Auto-retry must not quietly turn a missed position into a clean one.
    // What the mistake costs is decided in the session and pinned there
    // (`endgame_solve_session_test.dart`: a retried solve does not count as
    // solved unaided); what this checks is that the screen still goes through
    // that same path rather than around it.
    await open(tester);

    await move(tester, 'a1', 'a2');
    await move(tester, 'a1', 'f1');

    expect(find.textContaining('Tačno').hitTestable(), findsWidgets,
        reason: 'pozicija je rešena i posle greške');
  });
}
