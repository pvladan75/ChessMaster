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
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';

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

  /// Whether the branch below the student's move was cut.
  bool cutTree = false;

  /// What the tree's context menu asked the server to do.
  final List<String> promoted = [];
  final List<String> removed = [];
  final List<String> cut = [];

  @override
  Future<bool> makePrimary({
    required String color,
    required String fen,
    required String uci,
  }) async {
    promoted.add(uci);
    return true;
  }

  @override
  Future<bool> removeMove({
    required String color,
    required String fen,
    required String uci,
  }) async {
    removed.add(uci);
    return true;
  }

  @override
  Future<bool> skipNode({required String color, required String fen}) async {
    cut.add(fen);
    return true;
  }

  @override
  Future<({List<String> keys, int drafts, int decisions})?> orphansOfRemoving({
    required String color,
    required String fen,
    required String uci,
    int? minRating,
  }) async =>
      (keys: const <String>[], drafts: 0, decisions: 0);

  @override
  Future<List<RepertoireMove>> movesAt({
    required String color,
    required String fen,
  }) async =>
      fen == advance
          ? const [RepertoireMove(uci: 'c7c5', san: 'c5', role: 'primary')]
          : const [];

  /// Which positions the stored book was read for. A read is free — it comes
  /// out of what somebody's session already paid for — but *which* position it
  /// was asked about is the whole question when the board stands after a move.
  final List<String> bookReads = [];

  @override
  Future<StoredBook?> storedBook({
    required String color,
    required String fen,
    int? minRating,
  }) async {
    bookReads.add(fen);
    return const StoredBook(
      fen: afterC5,
      opened: true,
      replies: [
        StoredReply(
            uci: 'c2c3', san: 'c3', games: 640, share: 0.64, covered: true),
      ],
    );
  }

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
  Future<RepertoireTree?> repertoireTree({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int? minRating,
    int maxPly = 16,
  }) async {
    treeCalls += 1;
    if (cutTree) {
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
                state: 'cut',
              ),
            ],
          ),
        ],
      );
    }
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

  Future<void> pump(
    WidgetTester tester,
    Size size, {
    Future<List<AnalysisLine>> Function(String fen, int depth, int multiPV)?
        analyse,
    bool cutTree = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    api = _FakeApi()..cutTree = cutTree;
    await tester.pumpWidget(MaterialApp(
      home: RepertoireBuildScreen(
        name: 'French Defense: Advance — crni',
        color: 'b',
        rootFen: advance,
        rootPath: const ['e4', 'e6', 'd4', 'd5', 'e5'],
        api: api,
        judge: _SilentJudge(),
        analyse: analyse ?? (fen, depth, multiPV) async => const [],
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

  testWidgets('tapping your own move stands the board after it',
      (tester) async {
    // The position after my own move has the opponent to move, so this screen
    // has no question to ask about it. It used to bounce the tap back to the
    // position the move was chosen from — which, on the line you are standing
    // in, is where you already are: the card looked dead. What tapping your own
    // move means is "show me what comes back", and that list is already stored.
    await pump(tester, const Size(1400, 900));
    api.bookReads.clear();

    await tester.tap(find.textContaining('c5 ★').first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The breadcrumb names the board, not the position behind it.
    expect(find.text('1.e4 e6 2.d4 d5 3.e5 c5'), findsOneWidget);
    // And the book was read for the position after the move, not after the
    // main move of the position the question belongs to.
    expect(api.bookReads, contains(afterC5));
    expect(find.textContaining('Posle c5'), findsWidgets);
    // And this is where preparing the opponent's replies lives now: on the
    // position they are played from, rather than in a second list stacked under
    // the position before it.
    expect(find.text('Idi'), findsOneWidget);
  });

  testWidgets('and there is a way back to the question', (tester) async {
    // Without it the only way out of a tapped move is another tap in the tree,
    // which is a corner rather than a state.
    await pump(tester, const Size(1400, 900));
    await tester.tap(find.textContaining('c5 ★').first);
    await tester.pumpAndSettle();

    // Scrolled into view first: the controls sit under the board, and a tap on
    // a widget below the fold lands on whatever is at those coordinates.
    await tester.ensureVisible(find.text('Nazad na c5'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nazad na c5'));
    await tester.pumpAndSettle();

    expect(find.text('1.e4 e6 2.d4 d5 3.e5'), findsOneWidget);
    expect(find.text('Šta igrate crnim?'), findsOneWidget);
  });

  testWidgets('the context menu on your own move actually does something',
      (tester) async {
    // It offered "Unapredi u glavnu liniju" and "Obriši ovu varijantu" for a
    // day with nothing behind either: the shared widget calls
    // `onPromoteNode?.call`, and this panel passed neither, so the `?.`
    // swallowed the tap. A menu item that quietly does nothing is worse than no
    // menu item.
    await pump(tester, const Size(1400, 900));

    // The tree card, not the strip chip beside the board: the strip carries the
    // same move without its number and has no menu of its own.
    await tester.longPress(find.text('3... c5 ★'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unapredi u Glavnu Liniju (Main Line)'));
    await tester.pumpAndSettle();

    expect(api.promoted, ['c7c5']);
  });

  testWidgets('deleting the opponent\'s move is the cut, not a removal',
      (tester) async {
    // Their moves are not rows anybody chose, so there is nothing to delete.
    // What somebody means by it is "I am not preparing this", which is a
    // decision and is stored as one.
    await pump(tester, const Size(1400, 900));

    await tester.longPress(find.text('4. c3 64% ?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Obriši Ovu Varijantu'));
    await tester.pumpAndSettle();

    expect(api.cut, [afterC3]);
    expect(api.removed, isEmpty);
  });

  testWidgets('a cut branch is not drawn, and says how many are hidden',
      (tester) async {
    // A cut stops the walk, but the card stayed: ten cuts left ten dead leaves
    // widening a drawing that is read to find the holes. Hidden, never gone —
    // a cut is a decision and has to stay findable.
    api = _FakeApi();
    await pump(tester, const Size(1400, 900), cutTree: true);

    expect(find.text('4. c3 64% ✂'), findsNothing);
    expect(find.text('Prikaži odsečene grane (1)'), findsOneWidget);

    await tester.tap(find.text('Prikaži odsečene grane (1)'));
    await tester.pumpAndSettle();
    expect(find.text('4. c3 64% ✂'), findsWidgets);
  });

  testWidgets('the cards are numbered from where the game really is',
      (tester) async {
    // The repertoire starts after 3.e5, so its first card is Black's third
    // move. Numbered from the card's depth it read as move one, which is a
    // small lie with no upside; the FEN carries the true counter.
    await pump(tester, const Size(1400, 900));

    expect(find.textContaining('3... c5'), findsWidgets);
    expect(find.textContaining('4. c3'), findsWidgets);
  });

  testWidgets('there is a navigation palette under the board', (tester) async {
    await pump(tester, const Size(1400, 900));

    expect(find.byType(MoveNavigationControls), findsOneWidget);
    // It runs past the board to the end of the line, or its forward buttons
    // would be dead the moment the screen opens.
    expect(find.text('Potez 0 od 2'), findsOneWidget);
  });

  testWidgets('a jump to the position already on the board changes nothing',
      (tester) async {
    // The guard. Re-showing a position clears everything that belonged to it,
    // so a tap that lands where the board already is used to throw away the
    // engine lines the reader had just waited for.
    await pump(
      tester,
      const Size(1400, 900),
      analyse: (fen, depth, multiPV) async => [
        AnalysisLine(
          multipv: 1,
          depth: 20,
          evaluation: '+0.35',
          bestMoveLan: 'c7c5',
          bestMoveSan: 'c5',
          continuationLan: 'c7c5',
          continuationSan: 'c5 c3',
          sanMoveList: const ['c5'],
          fenList: const [],
          fromSquare: 'c7',
          toSquare: 'c5',
        )
      ],
    );

    // Scrolled to first: the panels above the controls grew, so a button that
    // used to be on screen is now below the fold and a tap would land on
    // whatever is at those coordinates.
    await tester.ensureVisible(find.text('Pitaj motor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pitaj motor'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dodirnite liniju'), findsOneWidget);

    // The root card is the position the board is standing on.
    await tester.tap(find.text('🏁').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Dodirnite liniju'), findsOneWidget);
  });
}
