// endgame_kept_sentence_test.dart — docs/PLAN-TRENER-ZAVRSNICA.md, D11.
//
// After `Save for later` both endgame screens said „Saved in "My positions"",
// a screen that no longer exists; the position goes to the Library, under
// Positions. The sentence is asserted through the Library chip's own label,
// so a renamed chip turns these red instead of leaving a sentence that points
// nowhere. Written against the literal rather than the screens' shared
// constant, so the cases are red on the old code rather than not compiling.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/endgame_trainer/models/endgame_puzzle.dart';
import 'package:chess_app/features/endgame_trainer/screens/blunder_walk_screen.dart';
import 'package:chess_app/features/endgame_trainer/screens/endgame_trainer_screen.dart';
import 'package:chess_app/features/endgame_trainer/services/endgame_api_service.dart';
import 'package:chess_app/features/library/widgets/library_list.dart'
    show LibraryChip;
import 'package:chess_app/models/user_session.dart';

class _FakeApi extends EndgameApiService {
  _FakeApi() : super(authToken: '');

  final kept = <String>[];

  @override
  Future<EndgameFetchResult> fetchNext({
    EndgameMode? mode,
    String? excludeId,
    String? material,
    String? band,
    bool oppositeOnly = false,
    bool includeOnline = false,
  }) async =>
      EndgameFetchResult(
        EndgameFetchOutcome.ok,
        EndgamePuzzle.fromJson({
          'puzzle_id': 'eg_kept',
          'fen': '8/5pk1/8/8/8/8/5PK1/r7 b - - 0 55',
          'type': 'RookPawnVsRook',
          'mode': 'draw',
          'winning_moves': ['a1f1', 'a1e1'],
          'piece_count': 5,
          'pawn_count': 2,
          'source': 'syzygy',
        }),
      );

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
      GameFetchResult(
        EndgameFetchOutcome.ok,
        BlunderGame.fromJson({
          'game_id': 'bg_kept',
          'white': 'Seger, Ruediger',
          'black': 'Lambert, Andreas',
          'white_elo': 2416,
          'black_elo': 2204,
          'date': '2005.03.13',
          'start_fen': '8/8/k1K5/P6R/8/5r2/7P/8 b - - 1 59',
          'moves': ['Rd3', 'h4'],
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
          ],
        }),
      );

  @override
  Future<bool> keepForLater({
    required String fen,
    required String title,
    required String description,
  }) async {
    kept.add(fen);
    return true;
  }
}

final _session =
    UserSession(token: 't', id: 1, email: 'a@b', name: 'Test', role: 'k');

final _sentence = 'Saved to the Library under ${LibraryChip.positions.label}, '
    'tagged "Unclear".';

void main() {
  for (final entry in <String, Widget Function(_FakeApi)>{
    'the trainer': (api) => EndgameTrainerScreen(session: _session, api: api),
    'the game walk': (api) => BlunderWalkScreen(session: _session, api: api),
  }.entries) {
    testWidgets('${entry.key}: Save for later names the Library and its chip',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final api = _FakeApi();
      await tester.pumpWidget(MaterialApp(home: entry.value(api)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save for later'));
      await tester.pumpAndSettle();

      expect(api.kept, hasLength(1));
      expect(find.text(_sentence), findsOneWidget);
      expect(find.textContaining('My positions'), findsNothing);
    });
  }
}
