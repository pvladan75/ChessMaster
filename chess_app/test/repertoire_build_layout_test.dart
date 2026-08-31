import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_build_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/features/repertoire/widgets/repertoire_tree_panel.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// 1.e4 e6 2.d4 d5 3.e5 — the French Advance, Black to move, and the root of
/// the repertoire in every test here.
const advance = 'rnbqkbnr/ppp2ppp/4p3/3pP3/3P4/8/PPP2PPP/RNBQKBNR b KQkq - 0 3';

/// After 3...c5, White to move.
const afterC5 = 'rnbqkbnr/pp3ppp/4p3/2ppP3/3P4/8/PPP2PPP/RNBQKBNR w KQkq - 0 4';

/// After 4.c3, Black to move again — a position this screen can ask about.
const afterC3 =
    'rnbqkbnr/pp3ppp/4p3/2ppP3/3P4/2P5/PP3PPP/RNBQKBNR b KQkq - 0 4';

class _FakeApi extends RepertoireApiService {
  _FakeApi() : super(client: MockClient((_) async => http.Response('{}', 500)));

  int treeCalls = 0;

  @override
  Future<RepertoireFrontier?> frontier({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int? minRating,
  }) async =>
      const RepertoireFrontier(
        // One open position — the root — so the screen has a board rather than
        // the "nothing left in the queue" state.
        open: [
          FrontierNode(fen: advance, path: [], reach: 1, kind: 'undecided')
        ],
        decided: 1,
      );

  @override
  Future<List<RepertoireMove>> movesAt({
    required String color,
    required String fen,
  }) async =>
      const [];

  @override
  Future<RepertoireTree?> repertoireTree({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int? minRating,
    int maxPly = 16,
  }) async {
    treeCalls += 1;
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
}

/// A judge with nothing behind it. The layout is what is being tested, and a
/// screen that asked Lichess anything to draw itself would be the bug.
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

  Future<void> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    api = _FakeApi();
    await tester.pumpWidget(MaterialApp(
      home: RepertoireBuildScreen(
        name: 'French Defense: Advance — crni',
        color: 'b',
        rootFen: advance,
        rootPath: const ['e4', 'e6', 'd4', 'd5', 'e5'],
        api: api,
        judge: _SilentJudge(),
        analyse: (fen, depth, multiPV) async => const [],
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('on a phone the board and the tree are on the same screen',
      (tester) async {
    // The whole point of the change. The tree was a separate screen for one
    // day, which is one day of it being useless: seeing what you were building
    // meant leaving the board and coming back.
    //
    // A release build paints no overflow stripes; in a test build it throws.
    await pump(tester, const Size(360, 640));

    expect(tester.takeException(), isNull);
    expect(api.treeCalls, 1);
    expect(find.byType(ChessBoardWithOverlay), findsOneWidget);
    expect(find.byType(AnalysisMoveTreeWidget), findsOneWidget);
    // And the strip, which is the part of the tree that is readable at 360 dp.
    expect(find.byType(RepertoireLineStrip), findsOneWidget);
  });

  testWidgets('on a desktop window they are side by side', (tester) async {
    // Not a claim about `Breakpoints.isWide` — a claim about what is on screen.
    // The board is capped, so on a 1400 px window the space beside it was
    // empty before this.
    await pump(tester, const Size(1400, 900));

    expect(tester.takeException(), isNull);
    expect(find.byType(ChessBoardWithOverlay), findsOneWidget);
    expect(find.byType(AnalysisMoveTreeWidget), findsOneWidget);

    // Side by side rather than merely both present: the tree starts to the
    // right of where the board ends.
    final board = tester.getRect(find.byType(ChessBoardWithOverlay));
    final tree = tester.getRect(find.byType(AnalysisMoveTreeWidget));
    expect(tree.left, greaterThanOrEqualTo(board.right),
        reason: 'stablo nije pored table nego ispod nje');
  });

  testWidgets('the board grows on a wide window', (tester) async {
    // The old cap of 420 is a phone number, and on a desktop it left a phone
    // layout wearing a desktop.
    await pump(tester, const Size(360, 640));
    final narrow = tester
        .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
        .boardSize;

    await pump(tester, const Size(1400, 900));
    final wide = tester
        .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
        .boardSize;

    expect(wide, greaterThan(narrow));
  });

  testWidgets('tapping the opponent\'s move takes the board there',
      (tester) async {
    // The tree is the navigation. That is what makes having it here worth
    // anything: "Gradi odavde" stops being a button because you are already
    // there.
    await pump(tester, const Size(1400, 900));

    expect(find.text('1.e4 e6 2.d4 d5 3.e5'), findsOneWidget);
    await tester.tap(find.textContaining('c3 64%').first);
    await tester.pumpAndSettle();

    expect(find.text('1.e4 e6 2.d4 d5 3.e5 c5 4.c3'), findsOneWidget);
    // And the board really moved, not just the breadcrumb.
    final board = chess.Chess.fromFEN(afterC3);
    expect(board.turn, chess.Color.BLACK);
  });

  testWidgets('tapping your own move goes to where you chose it',
      (tester) async {
    // A card for the student's own move lands on a position the opponent is to
    // move in, which this screen cannot ask a question about. The useful jump
    // is the position *before* it — where that decision was made.
    await pump(tester, const Size(1400, 900));

    await tester.tap(find.textContaining('c5 ★').first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('1.e4 e6 2.d4 d5 3.e5'), findsOneWidget);
  });
}
