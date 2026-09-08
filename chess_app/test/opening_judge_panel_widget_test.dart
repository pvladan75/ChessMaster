import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/opening_judge_panel_widget.dart';

/// What the panel says, and — as much — what it refuses to say.
///
/// Two rules are being kept. A verdict that could not be reached must never
/// read like a verdict that was: "Lichess is out of quota" and "your move is
/// fine" have to be different sentences. And a move called a mistake owes the
/// reader more than a number: what to play instead, and how the move is
/// punished. That second one was learned the expensive way in the endgame
/// trainer, where a count of remaining moves without the moves themselves
/// taught nobody anything.
void main() {
  OpeningJudgement judgement(
    OpeningVerdict verdict, {
    int mastersGames = 0,
    int bandGames = 0,
    int? minRating,
    int? lossCp,
    int? afterCp,
    int? mateAfter,
    String? better,
    List<String> punishment = const [],
  }) =>
      OpeningJudgement(
        verdict: verdict,
        fen: 'fen',
        san: 'Bc4',
        uci: 'f1c4',
        moverIsWhite: true,
        mastersGames: mastersGames,
        mastersTotal: 900,
        bandGames: bandGames,
        bandTotal: 800,
        minRating: minRating,
        lossCp: lossCp,
        afterCp: afterCp,
        mateAfter: mateAfter,
        better: better,
        punishment: punishment,
      );

  Future<void> pump(
    WidgetTester tester,
    Widget panel, {
    Size size = const Size(500, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: panel)),
    ));
    // One frame and not pumpAndSettle: the loading state draws a spinner, which
    // never settles, and the panel has nothing else that animates.
    await tester.pump();
  }

  testWidgets('without a token the panel explains itself and offers Settings',
      (tester) async {
    await pump(
      tester,
      OpeningJudgePanelWidget(
        hasToken: false,
        moveSan: 'Bc4',
        isLoading: false,
        judgement: null,
        onJudge: () {},
        onOpenSettings: () {},
      ),
    );

    expect(
        find.textContaining('requires your own Lichess token'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.textContaining('Judge'), findsNothing,
        reason: 'nothing to press when token is missing');
  });

  testWidgets('with a token and a move, the verdict is asked for by hand',
      (tester) async {
    var asked = 0;
    await pump(
      tester,
      OpeningJudgePanelWidget(
        hasToken: true,
        moveSan: 'Bc4',
        isLoading: false,
        judgement: null,
        onJudge: () => asked++,
      ),
    );

    expect(find.text('Judge Bc4'), findsOneWidget);
    await tester.tap(find.text('Judge Bc4'));
    await tester.pump();
    expect(asked, 1);
  });

  testWidgets('at the start of the game there is nothing to judge',
      (tester) async {
    await pump(
      tester,
      const OpeningJudgePanelWidget(
        hasToken: true,
        moveSan: null,
        isLoading: false,
        judgement: null,
      ),
    );

    expect(find.textContaining('Play a move'), findsOneWidget);
    expect(find.textContaining('Judge'), findsNothing);
  });

  testWidgets('theory is named, and counted', (tester) async {
    await pump(
      tester,
      OpeningJudgePanelWidget(
        hasToken: true,
        moveSan: 'Bc4',
        isLoading: false,
        judgement: judgement(OpeningVerdict.theory, mastersGames: 2000),
        onJudge: () {},
      ),
    );

    expect(find.text('Bc4 · Mainline theory'), findsOneWidget);
    expect(find.text('Played by masters: 2000 games.'), findsOneWidget);
  });

  testWidgets('a mistake says what to play instead and how it is punished',
      (tester) async {
    await pump(
      tester,
      OpeningJudgePanelWidget(
        hasToken: true,
        moveSan: 'Bc4',
        isLoading: false,
        judgement: judgement(
          OpeningVerdict.mistake,
          lossCp: 420,
          afterCp: -400,
          bandGames: 40,
          minRating: 1600,
          better: 'Nf3',
          punishment: const ['Qh4', 'Nf3', 'Qxe4+'],
        ),
        onJudge: () {},
      ),
    );

    expect(find.text('Bc4 · Dubious move'), findsOneWidget);
    expect(find.text('Costs 4.20 pawns.'), findsOneWidget);
    expect(find.text('Played by 1600+ players: 40 games.'), findsOneWidget);
    expect(find.text('Better was Nf3.'), findsOneWidget);
    expect(find.text('Punished with Qh4 Nf3 Qxe4+.'), findsOneWidget);
  });

  testWidgets('a move that walks into mate says so', (tester) async {
    await pump(
      tester,
      OpeningJudgePanelWidget(
        hasToken: true,
        moveSan: 'Bc4',
        isLoading: false,
        judgement: judgement(OpeningVerdict.mistake,
            mateAfter: -3, lossCp: 99999, afterCp: -99999),
        onJudge: () {},
      ),
    );

    expect(find.text('Mate in 3 against you after this.'), findsOneWidget);
  });

  testWidgets('a playable move is not given advice it does not need',
      (tester) async {
    await pump(
      tester,
      OpeningJudgePanelWidget(
        hasToken: true,
        moveSan: 'Bc4',
        isLoading: false,
        judgement: judgement(OpeningVerdict.playable, lossCp: 7, afterCp: 15),
        onJudge: () {},
      ),
    );

    expect(find.text('Bc4 · Practical alternative'), findsOneWidget);
    expect(find.text('Costs 0.07 pawns.'), findsOneWidget);
    expect(find.textContaining('Better was'), findsNothing);
  });

  testWidgets('an unjudged move does not read as a bad one', (tester) async {
    await pump(
      tester,
      OpeningJudgePanelWidget(
        hasToken: true,
        moveSan: 'Bc4',
        isLoading: false,
        judgement: judgement(OpeningVerdict.unknown),
        onJudge: () {},
      ),
    );

    expect(find.text('Bc4 · No verdict'), findsOneWidget);
    expect(find.textContaining('not the same as a bad move'), findsOneWidget);
    expect(find.textContaining('Dubious'), findsNothing);
  });

  testWidgets('a spent quota says so in its own words', (tester) async {
    await pump(
      tester,
      OpeningJudgePanelWidget(
        hasToken: true,
        moveSan: 'Bc4',
        isLoading: false,
        judgement: null,
        reason: 'rate-limited',
        onJudge: () {},
      ),
    );

    expect(find.textContaining('quota exceeded'), findsOneWidget);
    // And the way back is still there, because the quota returns.
    expect(find.text('Judge Bc4'), findsOneWidget);
  });

  testWidgets('every state fits a 360 dp phone', (tester) async {
    // A release build paints no overflow stripes and no assertion — it clips.
    // In a test build it throws, which is the only cheap way to catch it.
    final states = <OpeningJudgePanelWidget>[
      OpeningJudgePanelWidget(
        hasToken: false,
        moveSan: 'Bc4',
        isLoading: false,
        judgement: null,
        onOpenSettings: () {},
      ),
      OpeningJudgePanelWidget(
        hasToken: true,
        moveSan: 'Qxd8+',
        isLoading: false,
        judgement: null,
        onJudge: () {},
      ),
      OpeningJudgePanelWidget(
        hasToken: true,
        moveSan: 'Qxd8+',
        isLoading: true,
        judgement: judgement(
          OpeningVerdict.mistake,
          lossCp: 420,
          afterCp: -400,
          bandGames: 12345,
          minRating: 2500,
          better: 'Nbd2',
          punishment: const ['Qh4+', 'Nf3', 'Qxe4+'],
        ),
        onJudge: () {},
      ),
    ];

    for (final panel in states) {
      await pump(tester, panel, size: const Size(360, 640));
      expect(tester.takeException(), isNull);
    }
  });

  test('games are counted in English', () {
    expect(gamesLabel(1), '1 game');
    expect(gamesLabel(2), '2 games');
    expect(gamesLabel(4), '4 games');
    expect(gamesLabel(5), '5 games');
    expect(gamesLabel(11), '11 games');
    expect(gamesLabel(21), '21 games');
    expect(gamesLabel(22), '22 games');
    expect(gamesLabel(112), '112 games');
  });
}
