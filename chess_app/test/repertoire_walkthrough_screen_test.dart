import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/repertoire/screens/repertoire_walkthrough_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/speakable_info.dart';

class _FakeApi extends RepertoireApiService {
  _FakeApi({this.treeToReturn})
      : super(client: MockClient((_) async => http.Response('{}', 500)));

  final RepertoireTree? treeToReturn;
  final Map<String, RepertoireComment> commentsToReturn = const {};

  @override
  Future<RepertoireTree?> repertoireTree({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int? minRating,
    String? gateUci,
    String? breadth,
    int? maxPly,
  }) async {
    return treeToReturn;
  }

  @override
  Future<Map<String, RepertoireComment>> comments(
      {required String color}) async {
    return commentsToReturn;
  }
}

RepertoireTree buildTestTree() {
  return RepertoireTree(
    rootFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    children: [
      RepertoireTreeMove(
        uci: 'e2e4',
        san: 'e4',
        fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
        mine: true,
        role: 'primary',
        share: 1.0,
        state: 'decided',
        children: [
          RepertoireTreeMove(
            uci: 'e7e5',
            san: 'e5',
            fen:
                'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
            mine: false,
            role: null,
            share: 0.55,
            state: 'decided',
            children: [
              RepertoireTreeMove(
                uci: 'g1f3',
                san: 'Nf3',
                fen:
                    'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2',
                mine: true,
                role: 'primary',
                share: 1.0,
                state: 'decided',
                children: [],
              ),
            ],
          ),
          RepertoireTreeMove(
            uci: 'e7e6',
            san: 'e6',
            fen: 'rnbqkbnr/pppp1ppp/4p3/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
            mine: false,
            role: null,
            share: 0.14,
            state: 'decided',
            children: [
              RepertoireTreeMove(
                uci: 'd2d4',
                san: 'd4',
                fen:
                    'rnbqkbnr/pppp1ppp/4p3/8/3PP3/8/PPP2PPP/RNBQKBNR b KQkq d3 0 2',
                mine: true,
                role: 'primary',
                share: 1.0,
                state: 'decided',
                children: [
                  RepertoireTreeMove(
                    uci: 'd7d5',
                    san: 'd5',
                    fen:
                        'rnbqkbnr/ppp2ppp/4p3/3p4/3PP3/8/PPP2PPP/RNBQKBNR w KQkq - 0 3',
                    mine: false,
                    role: null,
                    share: 0.60,
                    state: 'open',
                    children: [],
                  ),
                ],
              ),
            ],
          ),
          RepertoireTreeMove(
            uci: 'c7c5',
            san: 'c5',
            fen:
                'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq c6 0 2',
            mine: false,
            role: null,
            share: 0.31,
            state: 'open',
            children: [],
          ),
        ],
      ),
    ],
  );
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    _FakeApi api, {
    void Function(String fen)? onBuildHere,
    Size size = const Size(360, 640),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: RepertoireWalkthroughScreen(
        name: 'Test Repertoire',
        color: 'w',
        rootFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        api: api,
        onBuildHere: onBuildHere,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'mutated 8: The card says the right sentence for each of the three kinds',
      (tester) async {
    final api = _FakeApi(treeToReturn: buildTestTree());
    await pump(tester, api);

    expect(find.text('Vaš potez — glavna linija.'), findsOneWidget);

    // Scroll down manually
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    final chip = find.byType(ActionChip).at(0);
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(find.text('Protivnik igra e5 — 55% partija.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('Vaš potez — glavna linija.'), findsOneWidget);

    // Nf3 ends the first line, so the next press is the tour coming back to
    // e4 rather than a move. Asserted here rather than skipped past: this walk
    // is the closest thing in the suite to what the reader actually presses.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(
        find.text('Videli smo liniju posle e5. Sada ide e6.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('Protivnik igra e6 — 14% partija.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('Vaš potez — glavna linija.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('Na d5, 60% partija, nemate odgovor.'), findsOneWidget);

    // And the second climb, back to the same fork for the last reply.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(
        find.text('Videli smo liniju posle e6. Sada ide c5.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('Na c5, 31% partija, nemate odgovor.'), findsOneWidget);
  });

  testWidgets(
      'mutated 9: A hole shows Napravi odgovor, tapping it reports that positions FEN',
      (tester) async {
    String? builtFen;
    final api = _FakeApi(treeToReturn: buildTestTree());
    await pump(tester, api, onBuildHere: (fen) => builtFen = fen);

    // Scroll down manually
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    final chip = find.byType(ActionChip).at(1);
    await tester.tap(chip);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('Napravi odgovor'), findsOneWidget);
    await tester.tap(find.text('Napravi odgovor'));
    await tester.pumpAndSettle();

    expect(builtFen,
        'rnbqkbnr/ppp2ppp/4p3/3p4/3PP3/8/PPP2PPP/RNBQKBNR w KQkq - 0 3');
  });

  testWidgets(
      'mutated 10: At Size(360, 640) nothing overflows on a fork with five replies',
      (tester) async {
    final manyRepliesTree = RepertoireTree(
      rootFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      children: [
        RepertoireTreeMove(
          uci: 'e2e4',
          san: 'e4',
          fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
          mine: true,
          role: 'primary',
          share: 1.0,
          state: 'decided',
          children: [
            RepertoireTreeMove(
                uci: 'a',
                san: 'a',
                fen:
                    'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
                mine: false,
                role: null,
                share: 0.1,
                state: 'open',
                children: []),
            RepertoireTreeMove(
                uci: 'b',
                san: 'b',
                fen:
                    'rnbqkbnr/pppp2pp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
                mine: false,
                role: null,
                share: 0.1,
                state: 'open',
                children: []),
            RepertoireTreeMove(
                uci: 'c',
                san: 'c',
                fen:
                    'rnbqkbnr/pppp3p/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
                mine: false,
                role: null,
                share: 0.1,
                state: 'open',
                children: []),
            RepertoireTreeMove(
                uci: 'd',
                san: 'd',
                fen:
                    'rnbqkbnr/pppp4/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
                mine: false,
                role: null,
                share: 0.1,
                state: 'open',
                children: []),
            RepertoireTreeMove(
                uci: 'e',
                san: 'e',
                fen:
                    'rnbqkbnr/pppp5/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
                mine: false,
                role: null,
                share: 0.1,
                state: 'open',
                children: []),
          ],
        ),
      ],
    );

    final api = _FakeApi(treeToReturn: manyRepliesTree);
    await pump(tester, api, size: const Size(360, 640));

    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'At Size(1400, 900) the tree panel is drawn, at Size(360, 640) it is absent',
      (tester) async {
    final api = _FakeApi(treeToReturn: buildTestTree());

    // Narrow
    await pump(tester, api, size: const Size(360, 640));
    expect(
        find.textContaining('Uz protivnikov potez stoji koliko se često igra'),
        findsNothing);

    // Wide
    await pump(tester, api, size: const Size(1400, 900));
    expect(
        find.textContaining('Uz protivnikov potez stoji koliko se često igra'),
        findsOneWidget);
  });

  testWidgets('every word the voice is handed is a word on the card',
      (tester) async {
    // Phase 5's one rule, as a guard rather than as an intention: the sentence
    // spoken is the sentence on screen, so a reader who turns speech off loses
    // nothing but the sound. The card and the voice are two renderings of one
    // list; this fails the moment somebody composes the spoken string a second
    // time from the same facts.
    final api = _FakeApi(treeToReturn: buildTestTree());
    await pump(tester, api, size: const Size(1400, 900));

    final speakable = tester.widget<SpeakableInfo>(find.byType(SpeakableInfo));
    final shown = tester
        .widgetList<Text>(find.descendant(
          of: find.byType(SpeakableInfo),
          matching: find.byType(Text),
        ))
        .map((t) => t.data)
        .whereType<String>()
        .toList();

    expect(speakable.text, isNotEmpty);
    for (final part in speakable.text.split(' ')) {
      expect(shown.any((line) => line.contains(part)), isTrue,
          reason: 'spoken but not shown anywhere on the card: $part');
    }
  });

  testWidgets('the trunk is silent and a hole is not', (tester) async {
    // The budget lives in walkthrough_speech_test.dart; this is the wiring —
    // that `autoSpeak` actually follows the stop, and does not sit true for
    // every card the way an ordinary panel would.
    final api = _FakeApi(treeToReturn: buildTestTree());
    await pump(tester, api, size: const Size(1400, 900));

    SpeakableInfo speakable() =>
        tester.widget<SpeakableInfo>(find.byType(SpeakableInfo));

    // Stop 0 is `e4`, the reader's own move, with two replies below it — a
    // fork, so it speaks.
    expect(speakable().autoSpeak, isTrue);

    // Into `e5`, an answered reply with one move under it. Nothing to say.
    // Taken by the chip rather than by the forward arrow, because the arrow at
    // a fork opens the sheet — which is the strip working, not a way forward.
    await tester.tap(find.widgetWithText(ActionChip, 'e5 55%'));
    await tester.pumpAndSettle();
    expect(speakable().autoSpeak, isFalse);
  });

  testWidgets('at a fork the replies are drawn on the board, in tour order',
      (tester) async {
    // Rank carries stroke width as well as colour, so rank 1 is the thickest
    // arrow. It has to be the reply the tour takes first, or the board and the
    // chips would be telling the reader two different things about where this
    // line goes next.
    final api = _FakeApi(treeToReturn: buildTestTree());
    await pump(tester, api, size: const Size(1400, 900));

    final board = tester
        .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay));
    final arrows = board.engineArrows;

    expect(arrows.length, 3, reason: 'e5, e6 and c5 out of e4');
    expect(arrows[0].rank, 1);
    expect(arrows[0].evalText, '55%');
    expect(arrows[1].evalText, '14%');
    // The hole says so with the tree's own glyph, never with a colour.
    expect(arrows[2].evalText, '31% ?');

    // And the order is the tour's, which is not the order by share: e6 at 14%
    // comes before c5 at 31% because the reader has work under it.
    expect(arrows.map((a) => a.rank), [1, 2, 3]);
  });

  testWidgets('one reply is not a fork, and draws nothing', (tester) async {
    final api = _FakeApi(treeToReturn: buildTestTree());
    await pump(tester, api, size: const Size(1400, 900));

    // Walked all the way to `d4`, which has exactly **one** reply under it:
    // the hole `d5`. The obvious place to stand for this is `e5`, and the
    // first version of this test did — but the only move under `e5` is one of
    // the reader's own, so it proved that a position with *no* opponent
    // replies draws nothing, which nobody doubted. Dropping the fork rule
    // outright left it green. The one-reply case has to be walked to.
    await tester.tap(find.widgetWithText(ActionChip, 'e5 55%'));
    await tester.pumpAndSettle();
    // Nf3, the return to e4, e6, then d4.
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
    }
    expect(find.text('Vaš potez — glavna linija.'), findsOneWidget);

    final board = tester
        .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay));
    expect(board.engineArrows, isEmpty,
        reason: 'the board is about to move there anyway');
  });

  testWidgets('the end of a line returns to the fork before the next one',
      (tester) async {
    // The owner's request, as a guard: after the last move of a line the tour
    // stands on the fork again — board and all — and says which line it has
    // just shown and which it is about to.
    final api = _FakeApi(treeToReturn: buildTestTree());
    await pump(tester, api, size: const Size(1400, 900));

    // e4 -> e5 -> Nf3 is the first line; Nf3 ends it.
    await tester.tap(find.widgetWithText(ActionChip, 'e5 55%'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('Vaš potez — glavna linija.'), findsOneWidget);

    // One more press ends the line and comes back to e4.
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(
        find.text('Videli smo liniju posle e5. Sada ide e6.'), findsOneWidget);
    // Standing at the fork means the fork's own replies are on the board.
    final board = tester
        .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay));
    expect(board.engineArrows.length, 3);

    // And the board is actually *on* the fork. Asserted because the first
    // version of this screen was not: it indexed the stop list with a beat
    // number, so the pieces showed a position out of another line while the
    // card, the arrows and the sentence were all correct. Everything that made
    // the screen look right was covered; the one thing that was wrong was not.
    expect(board.controller.getFen(),
        startsWith('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR'),
        reason: 'the board stands on e4, not on the line just finished');
  });

  testWidgets('The server answering null shows the error', (tester) async {
    final api = _FakeApi(treeToReturn: null);
    await pump(tester, api);

    expect(find.text('Ne mogu da učitam repertoar. Pokušajte ponovo.'),
        findsOneWidget);
    expect(find.text('U ovom repertoaru još nema poteza.'), findsNothing);
  });

  testWidgets('Empty repertoire shows the empty-repertoire sentence',
      (tester) async {
    final api = _FakeApi(
        treeToReturn: RepertoireTree(
            rootFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
            children: []));
    await pump(tester, api);

    expect(find.text('U ovom repertoaru još nema poteza.'), findsOneWidget);
  });
}
