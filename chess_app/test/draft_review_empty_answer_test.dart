import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_build_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';

/// „Nema više nepotvrđenih poteza." must be true when it is said.
///
/// Found live 4.9.2026 on a repertoire holding twenty-one of them. The review
/// walks the repertoire — its gate and its width — and a spine written while
/// the width was wider is a spine the walk can no longer reach: at „Samo
/// glavna linija" it follows one reply a position, and every one of those
/// drafts sat under the second. So the walk came back empty, honestly, and the
/// screen turned that into a sentence about the whole graph.
///
/// The same shape as everything in CLAUDE.md's recurring-bug section: a step
/// that skipped, reported success, and was found one layer later.
class _NoDraftsHere extends RepertoireApiService {
  _NoDraftsHere({required this.heldInGraph})
      : super(client: MockClient((_) async => http.Response('{}', 500)));

  /// What the colour holds, whatever this repertoire's walk can see.
  final int heldInGraph;

  @override
  Future<RepertoireUnconfirmedWalk?> unconfirmedPositions({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    String? gateUci,
    String? breadth,
    int? minRating,
    int? limit,
  }) async =>
      const RepertoireUnconfirmedWalk();

  @override
  Future<RepertoireUnconfirmedCounts?> unconfirmedCounts() async =>
      RepertoireUnconfirmedCounts(
        w: UnconfirmedColorCount(positions: heldInGraph, moves: heldInGraph),
      );
}

class _SilentJudge implements OpeningJudgeService {
  @override
  bool get hasPersonalToken => false;

  @override
  Future<OpeningJudgeLookup> judge(String fen, String move,
          {int? minRating}) async =>
      const OpeningJudgeLookup.unavailable('no-token');

  @override
  Future<OpponentRepliesLookup> replies(String fen, {int? minRating}) async =>
      const OpponentRepliesLookup.unavailable('no-token');

  @override
  void clearCache() {}
}

const _italian =
    'r1bqk1nr/pppp1ppp/2n5/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, {required int heldInGraph}) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: RepertoireBuildScreen(
        name: 'Italian Game: Giuoco Piano — beli',
        color: 'w',
        rootFen: _italian,
        rootPath: const ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Bc5'],
        breadth: 'main',
        api: _NoDraftsHere(heldInGraph: heldInGraph),
        judge: _SilentJudge(),
        analyse: (fen, depth, multiPV) async => const [],
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('drafts the walk cannot reach are not reported as none',
      (tester) async {
    await pump(tester, heldInGraph: 21);

    await tester.tap(find.text('Pregledaj nepotvrđene'));
    await tester.pumpAndSettle();

    expect(find.textContaining('21'), findsWidgets,
        reason: 'broj koji stoji u grafu mora da se kaže');
    expect(find.text('Nema više nepotvrđenih poteza.'), findsNothing,
        reason: 'nije istina — ima ih dvadeset jedan');
  });

  testWidgets('an empty graph still says there is nothing left',
      (tester) async {
    await pump(tester, heldInGraph: 0);

    await tester.tap(find.text('Pregledaj nepotvrđene'));
    await tester.pumpAndSettle();

    expect(find.text('Nema više nepotvrđenih poteza.'), findsOneWidget);
  });
}
