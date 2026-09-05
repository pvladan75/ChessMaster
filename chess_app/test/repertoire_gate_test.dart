import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_build_screen.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_list_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/features/repertoire/widgets/repertoire_gate_picker.dart';
import 'package:chess_app/models/analysis_models.dart';

/// The Italian after 1.e4 e5 2.Nf3 Nc6 3.Bc4 Bc5 — White to move, and the
/// position this feature came from: one repertoire plays 4.b4 (the Evans), the
/// other 4.0-0, and until the gate existed each showed the other's opening.
const italian =
    'r1bqk1nr/pppp1ppp/2n5/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4';

/// After 4.0-0, Black to move.
const afterCastles =
    'r1bqk1nr/pppp1ppp/2n5/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQ1RK1 b kq - 5 4';

/// After 4.0-0 Nf6 — White to move again, a position the screen can ask about.
const afterNf6 =
    'r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQ1RK1 w kq - 6 5';

class _FakeApi extends RepertoireApiService {
  _FakeApi() : super(client: MockClient((_) async => http.Response('{}', 500)));

  /// What each read was asked to narrow itself to.
  final List<String?> treeGates = [];
  final List<String?> frontierGates = [];

  /// What `setGate` was told, and what the root already holds.
  final List<({int id, String? viaUci})> gated = [];
  List<RepertoireMove> keptAtRoot = const [
    RepertoireMove(uci: 'b2b4', san: 'b4', role: 'primary'),
  ];

  @override
  Future<List<RepertoireMove>> movesAt({
    required String color,
    required String fen,
  }) async =>
      fen == italian ? keptAtRoot : const [];

  @override
  Future<RepertoireFrontier?> frontier({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int? minRating,
    String? gateUci,
    String? breadth,
  }) async {
    frontierGates.add(gateUci);
    return const RepertoireFrontier(
      open: [
        FrontierNode(
            fen: afterNf6, path: ['O-O', 'Nf6'], reach: 1, kind: 'undecided')
      ],
      decided: 1,
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
    String? breadth,
    List<String> alongPath = const [],
  }) async {
    treeGates.add(gateUci);
    // The server does the narrowing; the fake answers with what a gated read
    // would come back with, so the screen is tested on what it draws.
    return const RepertoireTree(
      rootFen: italian,
      rootPath: ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Bc5'],
      children: [
        RepertoireTreeMove(
          uci: 'e1g1',
          san: 'O-O',
          fen: afterCastles,
          mine: true,
          role: 'primary',
          children: [
            RepertoireTreeMove(
              uci: 'g8f6',
              san: 'Nf6',
              fen: afterNf6,
              mine: false,
              share: 0.7,
              state: 'open',
            ),
          ],
        ),
      ],
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
  Future<List<RepertoireSummary>> list() async => const [
        RepertoireSummary(
          id: 3,
          name: 'Italijanka — rokada',
          color: 'w',
          rootFen: italian,
          moves: 40,
          viaUci: 'e1g1',
          viaSan: 'O-O',
        ),
      ];

  @override
  Future<({bool saved, String? viaUci, String? viaSan})> setGate(
    int id, {
    String? viaUci,
  }) async {
    gated.add((id: id, viaUci: viaUci));
    return (saved: true, viaUci: viaUci, viaSan: viaUci == null ? null : 'O-O');
  }
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the moves offered as a gate', () {
    test('every legal move is there, the kept ones first and marked', () {
      // A repertoire being created may go through a move nobody has kept yet —
      // which is exactly the case that made the gate necessary: 4.0-0 does not
      // exist in the graph until the second repertoire keeps it.
      final options = gateOptionsFor(italian, kept: const ['b2b4']);

      expect(options.first.uci, 'b2b4');
      expect(options.first.kept, isTrue);
      expect(options.any((o) => o.uci == 'e1g1'), isTrue,
          reason: 'rokada nije ponuđena kao kapija');
      // Read from the library, not assembled: castling has three spellings in
      // this codebase and a wrong one would pick a different move.
      expect(options.firstWhere((o) => o.uci == 'e1g1').san, 'O-O');
      expect(options.where((o) => o.kept).length, 1);
    });

    test('a position that cannot be read offers nothing rather than throwing',
        () {
      expect(gateOptionsFor('not a fen'), isEmpty);
    });
  });

  group('the build screen', () {
    testWidgets('carries its gate into every read that walks the graph',
        (tester) async {
      // The tree, the queue and the counts are all one walk. If the gate does
      // not reach them, the "clean view" is a sentence on screen and nothing
      // more.
      final api = _FakeApi();
      await tester.pumpWidget(MaterialApp(
        home: RepertoireBuildScreen(
          name: 'Italijanka — rokada',
          color: 'w',
          rootFen: italian,
          rootPath: const ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Bc5'],
          gateUci: 'e1g1',
          api: api,
          judge: _SilentJudge(),
          analyse: (fen, depth, multiPV) async => const <AnalysisLine>[],
        ),
      ));
      await tester.pumpAndSettle();

      expect(api.frontierGates, isNotEmpty);
      expect(api.frontierGates.every((gate) => gate == 'e1g1'), isTrue);
      expect(api.treeGates, isNotEmpty);
      expect(api.treeGates.every((gate) => gate == 'e1g1'), isTrue);
    });

    testWidgets('says which opening it is showing', (tester) async {
      // A filtered view that does not say it is filtered is how somebody
      // concludes their work has been deleted.
      final api = _FakeApi();
      await tester.pumpWidget(MaterialApp(
        home: RepertoireBuildScreen(
          name: 'Italijanka — rokada',
          color: 'w',
          rootFen: italian,
          gateUci: 'e1g1',
          api: api,
          judge: _SilentJudge(),
          analyse: (fen, depth, multiPV) async => const <AnalysisLine>[],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('ide kroz O-O'), findsOneWidget);
    });

    testWidgets('without a gate it says nothing and asks for everything',
        (tester) async {
      final api = _FakeApi();
      await tester.pumpWidget(MaterialApp(
        home: RepertoireBuildScreen(
          name: 'Italijanka',
          color: 'w',
          rootFen: italian,
          api: api,
          judge: _SilentJudge(),
          analyse: (fen, depth, multiPV) async => const <AnalysisLine>[],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('ide kroz'), findsNothing);
      expect(api.treeGates.every((gate) => gate == null), isTrue);
    });
  });

  group('the list screen', () {
    testWidgets('names the gate on the card', (tester) async {
      // Two repertoires from one position are otherwise two identical rows with
      // different names.
      final api = _FakeApi();
      await tester
          .pumpWidget(MaterialApp(home: RepertoireListScreen(api: api)));
      await tester.pumpAndSettle();

      expect(find.textContaining('kroz O-O'), findsOneWidget);
    });

    testWidgets('can set the gate on a repertoire that already exists',
        (tester) async {
      // The repertoires that most need a gate are the ones built before the
      // column was — the owner has two of them right now.
      final api = _FakeApi();
      await tester
          .pumpWidget(MaterialApp(home: RepertoireListScreen(api: api)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Još'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kroz koji potez ide'));
      await tester.pumpAndSettle();

      // The move already kept in that position is at the top, marked.
      expect(find.text('b4'), findsOneWidget);
      expect(find.text('Bez ograničenja'), findsOneWidget);
      await tester.tap(find.text('b4'));
      await tester.pumpAndSettle();

      expect(api.gated.single.id, 3);
      expect(api.gated.single.viaUci, 'b2b4');
    });

    testWidgets('clearing the gate is a decision, closing the sheet is not',
        (tester) async {
      final api = _FakeApi();
      await tester
          .pumpWidget(MaterialApp(home: RepertoireListScreen(api: api)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Još'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kroz koji potez ide'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bez ograničenja'));
      await tester.pumpAndSettle();

      expect(api.gated.single.viaUci, isNull);
    });
  });
}
