import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/endgame_trainer/screens/blunder_walk_screen.dart';
import 'package:chess_app/features/endgame_trainer/services/endgame_api_service.dart';
import 'package:chess_app/models/user_session.dart';

/// Serves one game without a network.
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
  }) async =>
      result;
}

/// Seger - Lambert 2005: three mistakes in six moves, alternating sides.
BlunderGame game() => BlunderGame.fromJson({
      'game_id': 'bg_test',
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
          'should_play': ['Kc5'],
          'should_play_uci': ['c6c5'],
          'outcome_before': 'win',
          'outcome_after': 'draw',
          'material': 'KRPPvKR',
        },
      ],
    });

Widget wrap(Widget child) => MaterialApp(home: child);

Widget screen({BlunderGame? withGame, EndgameFetchOutcome? failing}) =>
    BlunderWalkScreen(
      session: UserSession(
          token: 't', id: 1, email: 'a@b', name: 'Test', role: 'korisnik'),
      api: _FakeApi(failing != null
          ? GameFetchResult(failing)
          : GameFetchResult(EndgameFetchOutcome.ok, withGame ?? game())),
    );

void main() {
  testWidgets('opens on the first mistake and says whose it was',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(screen()));
    await tester.pumpAndSettle();

    // A release build paints no overflow stripes, so this is the only cheap
    // place to catch a row that outgrows the phone.
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Crni je ovde odigrao Rd3'), findsOneWidget);
    expect(find.textContaining('Nađite potez koji drži remi'), findsOneWidget);
    expect(find.textContaining('Seger, Ruediger (2416)'), findsOneWidget);
    expect(find.text('Greške: 0/2'), findsOneWidget);
  });

  testWidgets('the strip cannot walk past an unanswered mistake',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(screen()));
    await tester.pumpAndSettle();

    // The wall is at the opening board, so every navigation button is dead:
    // there is nothing behind the cursor and nothing open ahead of it.
    final forward = find.byIcon(Icons.chevron_right);
    expect(forward, findsOneWidget);
    expect(
        tester
            .widget<IconButton>(find.ancestor(
              of: forward,
              matching: find.byType(IconButton),
            ))
            .onPressed,
        isNull);
  });

  testWidgets(
      'a game the filters cannot match is said differently from one '
      'the server could not send', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final entry in {
      EndgameFetchOutcome.noneMatch: 'odgovara traženim uslovima',
      EndgameFetchOutcome.unavailable: 'nije moguće dobaviti',
    }.entries) {
      await tester.pumpWidget(wrap(Container(
        key: ValueKey(entry.key),
        child: screen(failing: entry.key),
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining(entry.value), findsOneWidget,
          reason: 'ishod ${entry.key}');
    }
  });
}
