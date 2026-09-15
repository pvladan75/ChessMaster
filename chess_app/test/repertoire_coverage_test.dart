import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/repertoire/screens/repertoire_coverage_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';

/// 1.e4 c5 2.d4 cxd4 3.c3 dxc3 4.Nxc3 — the Smith-Morra accepted, Black to
/// move, which is the root of the repertoire in every one of these tests.
const smithMorra = 'rnbqkbnr/pp1ppppp/8/8/4P3/2N5/PP3PPP/R1BQKBNR b KQkq - 0 4';

class _FakeApi extends RepertoireApiService {
  _FakeApi({this.walk})
      : super(client: MockClient((_) async => http.Response('{}', 500)));

  /// Null stands for a server that did not answer — which the map must tell
  /// apart from a repertoire with nothing in it.
  final RepertoireFrontier? walk;
  int calls = 0;

  @override
  Future<RepertoireFrontier?> frontier({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    String? gateUci,
  }) async {
    calls += 1;
    return walk;
  }
}

void main() {
  late _FakeApi api;
  final built = <String>[];
  final drilled = <String>[];

  Future<void> pump(
    WidgetTester tester, {
    RepertoireFrontier? walk,
    Size size = const Size(500, 1000),
    bool withDoors = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    built.clear();
    drilled.clear();
    api = _FakeApi(walk: walk);
    await tester.pumpWidget(MaterialApp(
      home: RepertoireCoverageScreen(
        name: 'Smith-Morra, Black',
        color: 'b',
        rootFen: smithMorra,
        rootPath: const ['e4', 'c5', 'd4', 'cxd4', 'c3', 'dxc3', 'Nxc3'],
        api: api,
        onBuildAt: withDoors ? built.add : null,
        onDrillAt: withDoors ? drilled.add : null,
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Two branches: the main one has three positions answered and one open,
  /// the sideline — an opponent move the book does not know — one of each.
  RepertoireFrontier twoBranches() => const RepertoireFrontier(
        decided: 4,
        maxPly: 6,
        open: [
          FrontierNode(fen: 'a', path: ['Nc6', 'Nf3', 'e6', 'd4']),
          FrontierNode(fen: 'b', path: ['d6', 'h3']),
        ],
        branches: [
          CoverageBranch(
            key: 'Nc6 Nf3',
            path: ['Nc6', 'Nf3'],
            fen:
                'r1bqkbnr/pp1ppppp/2n5/8/4P3/2N2N2/PP3PPP/R1BQKB1R b KQkq - 0 5',
            share: 0.5,
            decided: 3,
            open: 1,
            maxPly: 6,
          ),
          CoverageBranch(
            key: 'd6 h3',
            path: ['d6', 'h3'],
            fen: 'rnbqkbnr/pp2pppp/3p4/8/4P3/2N4P/PP3PP1/R1BQKBNR b KQkq - 0 5',
            share: 0,
            decided: 1,
            open: 1,
            maxPly: 2,
          ),
        ],
      );

  testWidgets('each branch says how far it is taken, in counts',
      (tester) async {
    await pump(tester, walk: twoBranches());

    expect(api.calls, 1);
    // The line, numbered from move one because the root path is known.
    expect(find.text('1.e4 c5 2.d4 cxd4 3.c3 dxc3 4.Nxc3 Nc6 5.Nf3'),
        findsOneWidget);
    expect(find.textContaining('played in 50%'), findsOneWidget);
    expect(find.textContaining('3 decided · 1 open'), findsOneWidget);
    // No share of games is offered as progress any more.
    expect(find.textContaining('unanswered 40%'), findsNothing);
  });

  testWidgets('a branch the book does not know carries no share',
      (tester) async {
    await pump(tester, walk: twoBranches());

    expect(find.textContaining('played in 0%'), findsNothing);
    expect(find.textContaining('1 decided · 1 open'), findsOneWidget);
  });

  testWidgets('the whole repertoire is summed up in counts', (tester) async {
    await pump(tester, walk: twoBranches());

    expect(
        find.textContaining('2 positions have no answer yet'), findsOneWidget);
    expect(find.textContaining('4 positions are decided'), findsOneWidget);
    expect(find.textContaining('not preparing'), findsNothing);
  });

  testWidgets('a server that did not answer is not an empty repertoire',
      (tester) async {
    // "We could not find out" must never be drawn as "there is nothing here".
    await pump(tester);

    expect(find.textContaining('could not be loaded'), findsOneWidget);
    expect(find.textContaining('No branches on the map'), findsNothing);
  });

  testWidgets(
      'a repertoire without a first move says that, and offers to fix '
      'it', (tester) async {
    await pump(tester,
        walk: const RepertoireFrontier(
          open: [FrontierNode(fen: smithMorra, path: [])],
        ));

    expect(find.text('First move has not been chosen yet.'), findsOneWidget);
    await tester.tap(find.text('Build'));
    await tester.pumpAndSettle();
    expect(built.single, smithMorra);
  });

  testWidgets('both doors out of a branch carry that branch with them',
      (tester) async {
    await pump(tester, walk: twoBranches());

    await tester.tap(find.text('Build here').first);
    await tester.pumpAndSettle();
    expect(built.single, twoBranches().branches.first.fen);

    await tester.tap(find.text('Drill branch').first);
    await tester.pumpAndSettle();
    expect(drilled.single, twoBranches().branches.first.fen);
  });

  testWidgets('a branch with nothing decided is not offered for drilling',
      (tester) async {
    await pump(tester,
        walk: const RepertoireFrontier(
          branches: [
            CoverageBranch(
              key: 'd6 Bc4',
              path: ['d6', 'Bc4'],
              fen: 'x',
              share: 0.1,
              open: 1,
            ),
          ],
        ));

    expect(find.text('Build here'), findsOneWidget);
    expect(find.text('Drill branch'), findsNothing);
  });

  testWidgets('the map fits a 360 dp phone', (tester) async {
    // A release build paints no overflow stripes; in a test build it throws.
    await pump(tester, walk: twoBranches(), size: const Size(360, 640));
    expect(tester.takeException(), isNull);
  });
}
