import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/repertoire/screens/repertoire_walkthrough_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';

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

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('Protivnik igra e6 — 14% partija.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('Vaš potez — glavna linija.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('Na d5, 60% partija, nemate odgovor.'), findsOneWidget);

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
