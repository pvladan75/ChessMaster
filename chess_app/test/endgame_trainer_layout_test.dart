import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/endgame_trainer/models/endgame_puzzle.dart';
import 'package:chess_app/features/endgame_trainer/screens/endgame_trainer_screen.dart';
import 'package:chess_app/features/endgame_trainer/services/endgame_api_service.dart';
import 'package:chess_app/models/user_session.dart';

/// Serves one position without a network.
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
  }) async =>
      result;
}

/// The longest labels the screen can be handed, all at once: a long type name,
/// a long pair of player names, and the tablebase chip. If anything overflows a
/// phone, it overflows here.
EndgamePuzzle worstCasePuzzle() => EndgamePuzzle.fromJson({
      'puzzle_id': 'eg_test',
      'fen': '8/5pk1/8/8/8/8/5PK1/r7 b - - 0 55',
      'type': 'DoubleBishopVsBishopKnight',
      'mode': 'draw',
      'winning_moves': ['a1f1', 'a1e1'],
      'solution': ['a1f1', 'g2g3'],
      'piece_count': 5,
      'pawn_count': 1,
      'source': 'syzygy',
      'difficulty': 'hard',
      'difficulty_score': 9,
      'game': {
        'white': 'Chiburdanidze, Maia',
        'black': 'Gaprindashvili, Nona',
        'date': '1978.09.14',
      },
    });

Widget wrap(Widget child) => MaterialApp(home: child);

void main() {
  // A release build paints no overflow stripes and throws no assertion - it
  // just clips. In a test build it does throw, which is the only cheap way to
  // catch it. 360x640 is the phone this project has actually been bitten on.
  testWidgets('lays out on a 360x640 phone without overflowing',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrap(
        EndgameTrainerScreen(
          session: UserSession(
              token: 't', id: 1, email: 'a@b', name: 'Test', role: 'korisnik'),
          api: _FakeEndgameApi(
            EndgameFetchResult(EndgameFetchOutcome.ok, worstCasePuzzle()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('održite remi'), findsOneWidget);
  });

  testWidgets('says "nothing matches" and "unavailable" differently', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final entry in {
      EndgameFetchOutcome.noneMatch: 'odgovara traženim uslovima',
      EndgameFetchOutcome.unavailable: 'nije moguće dobaviti',
    }.entries) {
      await tester.pumpWidget(
        wrap(
          EndgameTrainerScreen(
            // A distinct key per outcome. Without it Flutter reuses the same
            // State across the two pumps, initState never runs again, and the
            // second case quietly asserts against the first one's message.
            key: ValueKey(entry.key),
            session: UserSession(
                token: 't',
                id: 1,
                email: 'a@b',
                name: 'Test',
                role: 'korisnik'),
            api: _FakeEndgameApi(EndgameFetchResult(entry.key)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(entry.value),
        findsOneWidget,
        reason: 'ishod ${entry.key} mora imati svoju poruku',
      );
    }
  });
}
