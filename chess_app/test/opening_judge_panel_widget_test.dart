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

    expect(find.textContaining('traži vaš Lichess token'), findsOneWidget);
    expect(find.text('Podešavanja'), findsOneWidget);
    expect(find.textContaining('Presudi'), findsNothing,
        reason: 'nema šta da se pritisne dok tokena nema');
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

    expect(find.text('Presudi Bc4'), findsOneWidget);
    await tester.tap(find.text('Presudi Bc4'));
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

    expect(find.textContaining('Odigrajte potez'), findsOneWidget);
    expect(find.textContaining('Presudi'), findsNothing);
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

    expect(find.text('Bc4 · Glavna teorija'), findsOneWidget);
    expect(find.text('Majstori ga igraju: 2000 partija.'), findsOneWidget);
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

    expect(find.text('Bc4 · Sumnjiv potez'), findsOneWidget);
    expect(find.text('Košta 4.20 pešaka.'), findsOneWidget);
    expect(find.text('Odigran kod 1600+ igrača: 40 partija.'), findsOneWidget);
    expect(find.text('Bolje je bilo Nf3.'), findsOneWidget);
    expect(find.text('Kažnjava se sa Qh4 Nf3 Qxe4+.'), findsOneWidget);
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

    expect(find.text('Posle njega je mat u 3 protiv vas.'), findsOneWidget);
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

    expect(find.text('Bc4 · Praktična alternativa'), findsOneWidget);
    expect(find.text('Košta 0.07 pešaka.'), findsOneWidget);
    expect(find.textContaining('Bolje je bilo'), findsNothing);
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

    expect(find.text('Bc4 · Nije presuđeno'), findsOneWidget);
    expect(find.textContaining('nije isto što i loš potez'), findsOneWidget);
    expect(find.textContaining('Sumnjiv'), findsNothing);
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

    expect(find.textContaining('Potrošen je dozvoljeni broj upita'),
        findsOneWidget);
    // And the way back is still there, because the quota returns.
    expect(find.text('Presudi Bc4'), findsOneWidget);
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

  test('games are counted in Serbian', () {
    expect(gamesLabel(1), '1 partija');
    expect(gamesLabel(2), '2 partije');
    expect(gamesLabel(4), '4 partije');
    expect(gamesLabel(5), '5 partija');
    expect(gamesLabel(11), '11 partija');
    expect(gamesLabel(21), '21 partija');
    expect(gamesLabel(22), '22 partije');
    expect(gamesLabel(112), '112 partija');
  });
}
