import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_build_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeApi extends RepertoireApiService {
  _FakeApi() : super(client: MockClient((_) async => http.Response('{}', 500)));

  bool unconfirmedCalled = false;
  int confirmedCount = 0;
  int skippedCount = 0;
  String? lastConfirmedUci;
  String? lastSkippedFen;

  @override
  Future<RepertoireUnconfirmedWalk?> unconfirmedPositions({
    required String color,
    required String rootFen,
    List<String>? rootPath,
    String? gateUci,
    String? breadth,
    int? minRating,
    int? limit,
  }) async {
    unconfirmedCalled = true;
    return const RepertoireUnconfirmedWalk(
      total: 2,
      positions: [
        UnconfirmedNode(
          fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
          path: ['e4'],
          fenKey: 'dummy',
          ply: 1,
          moves: [RepertoireMove(uci: 'c7c5', san: 'c5', role: 'draft')],
        ),
      ],
    );
  }

  @override
  Future<bool> confirmNode({
    required String color,
    required String fen,
    String? uci,
  }) async {
    confirmedCount++;
    lastConfirmedUci = uci;
    return true;
  }

  @override
  Future<bool> skipNode({
    required String color,
    required String fen,
  }) async {
    skippedCount++;
    lastSkippedFen = fen;
    return true;
  }

  @override
  Future<RepertoireFrontier?> frontier({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int? minRating,
    String? gateUci,
  }) async {
    return const RepertoireFrontier(
      open: [
        FrontierNode(
            fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
            path: [],
            reach: 1,
            kind: 'undecided')
      ],
      decided: 1,
      draft: 5,
    );
  }

  @override
  Future<RepertoireTree?> repertoireTree({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int? minRating,
    int maxPly = 16,
    String? gateUci,
  }) async {
    return const RepertoireTree(
      rootFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      rootPath: [],
      children: [],
    );
  }

  @override
  Future<Map<String, RepertoireNote>> notes({required String color}) async =>
      const {};
  @override
  Future<Map<String, RepertoireComment>> comments(
          {required String color}) async =>
      const {};
  @override
  Future<List<RepertoireMove>> movesAt(
          {required String color, required String fen}) async =>
      const [];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('UnconfirmedBanner appears and opens Wizard', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final api = _FakeApi();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RepertoireBuildScreen(
          name: 'Test Repertoire',
          color: 'w',
          rootFen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          api: api,
          openingLookup: (fen) => null,
          judge: OpeningJudgeService.instance,
          analyse: (fen, depth, multi) async => [],
        ),
      ),
    ));

    await tester.pumpAndSettle();

    // Check banner is rendered
    expect(find.text('5 nepotvrđenih u grafu'), findsOneWidget);
    expect(find.text('Pregledaj nacrt'), findsOneWidget);

    // Open wizard
    await tester.tap(find.text('Pregledaj nacrt'));
    await tester.pumpAndSettle();

    // Wizard is open
    expect(api.unconfirmedCalled, isTrue);
    expect(find.text('Pregled nacrta (2 ostalo)'), findsOneWidget);
    expect(find.text('Predlog: c5'), findsOneWidget);

    // Test Potvrdi
    await tester.tap(find.text('Potvrdi'));
    await tester.pump();

    expect(api.confirmedCount, 1);
    expect(api.lastConfirmedUci, 'c7c5');
  });
}
