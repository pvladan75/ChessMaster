import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_build_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/features/repertoire/widgets/breadth_dialog.dart';

/// The width is changed from the picture that says what it was drawn at.
///
/// Reported live 5.9.2026: „ručno dodajem poteze i kad izaberem potez za
/// protivnika, dodaju mi se još nekoliko alternativa". Those are the book's
/// replies inside the repertoire's width — and the only way to that width was
/// the „Predloži glavnu liniju" dialog, which saves it **only** if the reader
/// also lets it write a line of proposed moves. A reader narrowing the
/// repertoire because it writes too much had to let it write more first.
const advance = 'rnbqkbnr/ppp2ppp/4p3/3pP3/3P4/8/PPP2PPP/RNBQKBNR b KQkq - 0 3';
const afterC5 =
    'rnbqkbnr/pp3ppp/4p3/2ppP3/3P4/8/PPP2PPP/RNBQKBNR w KQkq c6 0 4';
const afterC3 =
    'rnbqkbnr/pp3ppp/4p3/2ppP3/3P4/2P5/PP3PPP/RNBQKBNR b KQkq - 0 4';

class _FakeApi extends RepertoireApiService {
  _FakeApi() : super(client: MockClient((_) async => http.Response('{}', 500)));

  /// What was written to the repertoire's row, and what every read asked at.
  /// The three have to agree: a width saved and not read is the bug this
  /// screen already paid for once.
  String? savedBreadth;
  final List<String?> treeBreadths = [];
  final List<String?> frontierBreadths = [];

  /// Whether anything was written. Changing a setting must write no moves.
  int spineCalls = 0;

  bool saveWorks = true;

  @override
  Future<bool> setBreadth({required int id, required String breadth}) async {
    if (!saveWorks) return false;
    savedBreadth = breadth;
    return true;
  }

  @override
  Future<({SpineResult? result, String? error})> buildSpine({
    required String color,
    required String rootFen,
    int depth = 8,
    int? minRating,
    int? minGames,
  }) async {
    spineCalls += 1;
    return (result: null, error: 'ne bi trebalo da bude pozvano');
  }

  @override
  Future<RepertoireFrontier?> frontier({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int? minRating,
    String? gateUci,
    String? breadth,
  }) async {
    frontierBreadths.add(breadth);
    return const RepertoireFrontier(
      open: [FrontierNode(fen: advance, path: [], reach: 1, kind: 'undecided')],
      decided: 1,
      draft: 0,
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
    treeBreadths.add(breadth);
    return const RepertoireTree(
      rootFen: advance,
      rootPath: ['e4', 'e6', 'd4', 'd5', 'e5'],
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
              state: 'open',
            ),
          ],
        ),
      ],
    );
  }

  @override
  Future<List<RepertoireMove>> movesAt({
    required String color,
    required String fen,
  }) async =>
      fen == advance
          ? const [RepertoireMove(uci: 'c7c5', san: 'c5', role: 'primary')]
          : const [];

  @override
  Future<StoredBook?> storedBook({
    required String color,
    required String fen,
    int? minRating,
  }) async =>
      null;

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

  late _FakeApi api;

  Future<void> pump(WidgetTester tester, {int? id = 7}) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    api = _FakeApi();
    await tester.pumpWidget(MaterialApp(
      home: RepertoireBuildScreen(
        name: 'French Defense: Advance — crni',
        color: 'b',
        rootFen: advance,
        rootPath: const ['e4', 'e6', 'd4', 'd5', 'e5'],
        id: id,
        breadth: 'standard',
        api: api,
        judge: _SilentJudge(),
        analyse: (fen, depth, multiPV) async => const [],
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// The legend's own words. It is the line that says what the drawing was
  /// made at, which is why the dial belongs on it rather than in a menu.
  final width = find.text('Koliko odgovora: uobičajeno 80%');

  testWidgets('the width in the legend opens its own dialog', (tester) async {
    await pump(tester);
    expect(width, findsOneWidget);

    await tester.tap(width);
    await tester.pumpAndSettle();

    expect(find.byType(BreadthSettingDialog), findsOneWidget);
    expect(find.text('Koliko odgovora spremamo'), findsOneWidget);
    // And it is the width alone: no depth, and nothing about a spine — this is
    // not `BreadthDialog`, which saves the width only if it may also write.
    expect(find.byType(BreadthDialog), findsNothing);
    expect(find.text('6 poteza'), findsNothing);
    expect(find.text('Predloži glavnu liniju odavde'), findsNothing);
  });

  testWidgets('choosing a width saves it and writes no moves', (tester) async {
    await pump(tester);
    final treeReads = api.treeBreadths.length;

    await tester.tap(width);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Samo glavni odgovor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sačuvaj'));
    await tester.pumpAndSettle();

    expect(api.savedBreadth, 'main', reason: 'širina nije upisana u red');
    // Written *and* read at. The dial spent a day being saved to the row while
    // this screen went on reading at 80%, so the picture disagreed with the
    // choice the reader had just made.
    expect(api.treeBreadths.length, greaterThan(treeReads),
        reason: 'crtež nije ponovo pročitan');
    expect(api.treeBreadths.last, 'main');
    expect(api.frontierBreadths.last, 'main',
        reason: 'red nije ponovo pročitan na novoj širini');
    // The whole point of the separate dialog.
    expect(api.spineCalls, 0, reason: 'promena širine je upisala poteze');
    // And the legend now says the new one.
    expect(find.text('Koliko odgovora: samo glavni odgovor'), findsOneWidget);
  });

  testWidgets('cancelling changes nothing at all', (tester) async {
    await pump(tester);
    final treeReads = api.treeBreadths.length;

    await tester.tap(width);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Široko (95%)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Odustani'));
    await tester.pumpAndSettle();

    expect(api.savedBreadth, isNull);
    expect(api.treeBreadths.length, treeReads,
        reason: 'crtež je ponovo čitan iako ništa nije promenjeno');
    expect(width, findsOneWidget);
  });

  testWidgets('the dialog opens on the width the repertoire is set to',
      (tester) async {
    // A dialog that opens on a default is a dialog that changes the setting by
    // being opened: pick nothing, save, and the repertoire must still be at
    // the width it had.
    await pump(tester);
    await tester.tap(width);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sačuvaj'));
    await tester.pumpAndSettle();

    expect(api.savedBreadth, 'standard');
    expect(find.text('Koliko odgovora: uobičajeno 80%'), findsOneWidget);
  });

  testWidgets('a repertoire without an id is not offered the dial',
      (tester) async {
    // `setBreadth` writes to the repertoire's row. Offering the button where
    // there is no row is offering a setting that silently does nothing.
    await pump(tester, id: null);

    expect(width, findsOneWidget);
    await tester.tap(width);
    await tester.pumpAndSettle();
    expect(find.text('Koliko odgovora spremamo'), findsNothing);
  });

  testWidgets('a save the server refuses keeps the old width', (tester) async {
    await pump(tester);
    api.saveWorks = false;

    await tester.tap(width);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Samo glavni odgovor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sačuvaj'));
    await tester.pumpAndSettle();

    // The dialog stays open and says so, and the screen has not adopted a
    // width the server does not hold.
    expect(find.text('Koliko odgovora spremamo'), findsOneWidget);
    expect(find.textContaining('Nije sačuvano'), findsOneWidget);

    await tester.tap(find.text('Odustani'));
    await tester.pumpAndSettle();
    expect(width, findsOneWidget);
  });
}
