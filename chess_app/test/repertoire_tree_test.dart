import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/analysis_studio/widgets/visual_move_tree_widget.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_tree_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';

/// 1.e4 e6 2.d4 d5 3.e5 — the French Advance, Black to move, which is the root
/// of the repertoire in every one of these tests.
const advance = 'rnbqkbnr/ppp2ppp/4p3/3pP3/3P4/8/PPP2PPP/RNBQKBNR b KQkq - 0 3';

/// After 3...c5, White to move.
const afterC5 = 'rnbqkbnr/pp3ppp/4p3/2ppP3/3P4/8/PPP2PPP/RNBQKBNR w KQkq - 0 4';

/// After 4.c3, Black to move again.
const afterC3 =
    'rnbqkbnr/pp3ppp/4p3/2ppP3/3P4/2P5/PP3PPP/RNBQKBNR b KQkq - 0 4';

class _FakeApi extends RepertoireApiService {
  _FakeApi({this.tree})
      : super(client: MockClient((_) async => http.Response('{}', 500)));

  /// Null stands for a server that did not answer.
  final RepertoireTree? tree;
  int calls = 0;
  int? lastDepth;

  @override
  Future<RepertoireTree?> repertoireTree({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int? minRating,
    int maxPly = 16,
  }) async {
    calls += 1;
    lastDepth = maxPly;
    return tree;
  }
}

void main() {
  late _FakeApi api;
  final built = <String>[];
  final drilled = <String>[];

  Future<void> pump(
    WidgetTester tester, {
    RepertoireTree? tree,
    Size size = const Size(700, 1000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    built.clear();
    drilled.clear();
    api = _FakeApi(tree: tree);
    await tester.pumpWidget(MaterialApp(
      home: RepertoireTreeScreen(
        name: 'French Defense: Advance — crni',
        color: 'b',
        rootFen: advance,
        rootPath: const ['e4', 'e6', 'd4', 'd5', 'e5'],
        api: api,
        onBuildAt: built.add,
        onDrillAt: drilled.add,
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// 3...c5 4.c3, with 4.c3 leading to a position nothing is decided in.
  RepertoireTree oneLine({String state = 'open'}) => RepertoireTree(
        rootFen: advance,
        rootPath: const ['e4', 'e6', 'd4', 'd5', 'e5'],
        children: [
          RepertoireTreeMove(
            uci: 'c7c5',
            san: 'c5',
            fen: afterC5,
            mine: true,
            role: 'primary',
            children: [
              RepertoireTreeMove(
                uci: 'c2c3',
                san: 'c3',
                fen: afterC3,
                mine: false,
                share: 0.64,
                state: state,
              ),
            ],
          ),
        ],
      );

  testWidgets('the repertoire is drawn in the tree the analysis board uses',
      (tester) async {
    // Deliberately not a second drawing. A tree written here would be a second
    // place for panning, zooming and transposition marks to be got wrong.
    await pump(tester, tree: oneLine());

    expect(api.calls, 1);
    expect(find.byType(VisualMoveTreeWidget), findsOneWidget);
    // The student's main move wears its star, and the opponent's move carries
    // how often it is played — both in characters, not in colour.
    expect(find.textContaining('c5 ★'), findsOneWidget);
    expect(find.textContaining('c3 64%'), findsOneWidget);
  });

  testWidgets('a card says what the position after it is', (tester) async {
    // Without this the picture is a decoration. With it, the holes are the
    // first thing anybody sees.
    await pump(tester, tree: oneLine(state: 'open'));
    expect(find.textContaining('?'), findsWidgets);

    await pump(tester, tree: oneLine(state: 'cut'));
    expect(find.textContaining('✂'), findsOneWidget);

    await pump(tester, tree: oneLine(state: 'unopened'));
    expect(find.textContaining('…'), findsOneWidget);
  });

  testWidgets('tapping a position offers to build and to drill it',
      (tester) async {
    await pump(tester, tree: oneLine());

    await tester.tap(find.textContaining('c3 64%'));
    await tester.pumpAndSettle();

    // The line reads from move one, because the root path is known.
    expect(find.text('1.e4 e6 2.d4 d5 3.e5 c5 4.c3'), findsOneWidget);
    await tester.tap(find.text('Gradi odavde'));
    await tester.pumpAndSettle();
    expect(built.single, afterC3);
  });

  testWidgets('a position where the opponent is to move offers neither door',
      (tester) async {
    // Both screens ask "what do you play here", and there is no answer to that
    // in a position that is not yours to move in.
    await pump(tester, tree: oneLine());

    await tester.tap(find.textContaining('c5 ★'));
    await tester.pumpAndSettle();

    expect(find.text('Gradi odavde'), findsNothing);
    expect(find.textContaining('protivnik na potezu'), findsOneWidget);
  });

  testWidgets('the depth is a control, and reaching it is said out loud',
      (tester) async {
    // A repertoire seeded from an archive runs to thousands of moves, and a
    // drawing of all of them is not a drawing anybody reads.
    await pump(tester,
        tree: RepertoireTree(
          rootFen: advance,
          children: oneLine().children,
          maxPly: 8,
          truncated: true,
        ));

    expect(api.lastDepth, 16);
    expect(find.textContaining('Crtež je skraćen na 8'), findsOneWidget);
  });

  testWidgets('a server that did not answer is not an empty repertoire',
      (tester) async {
    await pump(tester);

    expect(find.textContaining('nije moglo da se pročita'), findsOneWidget);
    expect(find.textContaining('još nema nijednog poteza'), findsNothing);
  });

  testWidgets('an empty repertoire says so and offers the way in',
      (tester) async {
    await pump(tester, tree: const RepertoireTree(rootFen: advance));

    expect(find.textContaining('još nema nijednog poteza'), findsOneWidget);
    await tester.tap(find.text('Gradi'));
    await tester.pumpAndSettle();
    expect(built.single, advance);
  });
}
