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
    int? minRating,
    String? gateUci,
    String? breadth,
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
        name: 'Smit-Mora, crni',
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

  /// Two branches: the main one is half of everything and half answered, the
  /// sideline is rare and untouched.
  RepertoireFrontier twoBranches() => const RepertoireFrontier(
        decided: 4,
        openReach: 0.4,
        maxPly: 6,
        branches: [
          CoverageBranch(
            key: 'Nc6 Nf3',
            path: ['Nc6', 'Nf3'],
            fen:
                'r1bqkbnr/pp1ppppp/2n5/8/4P3/2N2N2/PP3PPP/R1BQKB1R b KQkq - 0 5',
            share: 0.5,
            decided: 3,
            open: 1,
            undecided: 1,
            openWithin: 0.4,
            maxPly: 6,
          ),
          CoverageBranch(
            key: 'd6 Bc4',
            path: ['d6', 'Bc4'],
            fen:
                'rnbqkbnr/pp2pppp/3p4/8/2B1P3/2N5/PP3PPP/R1BQK1NR b KQkq - 1 5',
            share: 0.1,
            decided: 1,
            open: 1,
            unopened: 1,
            openWithin: 1,
            maxPly: 2,
          ),
        ],
      );

  testWidgets('each branch says how often it is played and how far it is done',
      (tester) async {
    await pump(tester, walk: twoBranches());

    expect(api.calls, 1);
    // The line, numbered from move one because the root path is known.
    expect(find.text('1.e4 c5 2.d4 cxd4 3.c3 dxc3 4.Nxc3 Nc6 5.Nf3'),
        findsOneWidget);
    expect(find.textContaining('played in 50%'), findsOneWidget);
    // Every share is written out. Nothing on this screen is said in colour
    // alone — a hue is not allowed to be the only place a number lives.
    expect(
        find.textContaining('prepared 60% · unanswered 40%'), findsOneWidget);
  });

  testWidgets(
      'a rare sideline is measured against itself, not against the '
      'whole repertoire', (tester) async {
    await pump(tester, walk: twoBranches());

    // Played in a tenth of games and entirely unanswered. Measured against the
    // whole repertoire it would read as nine-tenths finished, which is the
    // number that would have been wrong.
    expect(
        find.textContaining('prepared 0% · unanswered 100%'), findsOneWidget);
    expect(find.textContaining('played in 10%'), findsOneWidget);
  });

  testWidgets('a cut branch is not drawn as a finished one', (tester) async {
    // The map must never turn a refusal into progress: there is nothing open
    // in a cut branch, and only the number beside it says why.
    await pump(tester,
        walk: const RepertoireFrontier(
          decided: 1,
          prunedReach: 0.2,
          branches: [
            CoverageBranch(
              key: 'd6 Bc4',
              path: ['d6', 'Bc4'],
              fen: 'x',
              share: 0.2,
              pruned: 1,
              prunedWithin: 1,
            ),
          ],
        ));

    expect(find.textContaining('not preparing 100%'), findsOneWidget);
    expect(find.textContaining('prepared 100%'), findsNothing);
  });

  testWidgets('a server that did not answer is not an empty repertoire',
      (tester) async {
    // The oldest sentence in this codebase: "we could not find out" must never
    // be drawn as "there is nothing here".
    await pump(tester);

    expect(find.textContaining('could not be loaded'), findsOneWidget);
    expect(find.textContaining('No branches on the map'), findsNothing);
  });

  testWidgets(
      'a repertoire without a first move says that, and offers to fix '
      'it', (tester) async {
    await pump(tester,
        walk: const RepertoireFrontier(
          open: [
            FrontierNode(fen: smithMorra, path: [], reach: 1, kind: 'undecided')
          ],
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
    // Nothing to be asked about there yet, and a button that leads to an empty
    // screen is worse than no button.
    await pump(tester,
        walk: const RepertoireFrontier(
          branches: [
            CoverageBranch(
              key: 'd6 Bc4',
              path: ['d6', 'Bc4'],
              fen: 'x',
              share: 0.1,
              open: 1,
              undecided: 1,
              openWithin: 1,
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
