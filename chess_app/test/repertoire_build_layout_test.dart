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
import 'package:chess_app/features/repertoire/widgets/unconfirmed_banner.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';

/// 1.e4 e6 2.d4 d5 3.e5 — the French Advance, Black to move, and the root of
/// the repertoire in every test here.
const advance = 'rnbqkbnr/ppp2ppp/4p3/3pP3/3P4/8/PPP2PPP/RNBQKBNR b KQkq - 0 3';

/// After 3...c5, White to move.
// With the en-passant square, because that is what a real FEN for this
// position carries and what the board computes after 4...c5. Without it the
// fixture and the screen disagree about the same position, and every match
// against it fails for a reason that has nothing to do with the test.
const afterC5 =
    'rnbqkbnr/pp3ppp/4p3/2ppP3/3P4/8/PPP2PPP/RNBQKBNR w KQkq c6 0 4';

/// After 4.c3, Black to move again — a position this screen can ask about.
const afterC3 =
    'rnbqkbnr/pp3ppp/4p3/2ppP3/3P4/2P5/PP3PPP/RNBQKBNR b KQkq - 0 4';

/// After 4.Nf3 instead — the second branch, so the line has a fork in it.
const afterNf3 =
    'rnbqkbnr/pp3ppp/4p3/2ppP3/3P4/5N2/PPP2PPP/RNBQKB1R b KQkq - 1 4';

class _FakeApi extends RepertoireApiService {
  _FakeApi() : super(client: MockClient((_) async => http.Response('{}', 500)));

  int treeCalls = 0;

  /// The line the screen said the reader is standing on.
  List<String>? lastAlongPath;

  /// Which root the drawing was asked for — the repertoire's, or the
  /// position the reader narrowed to.
  String? lastTreeRootFen;
  List<String>? lastTreeRootPath;
  String? lastTreeGate;

  /// The position the frontier's open node stands on. Different from the
  /// repertoire's own root in the narrowing tests — with the two the same,
  /// narrowing to "here" asks for the root again and proves nothing.
  String nodeFen = advance;

  /// The path the frontier's open node carries. Non-empty in the test that
  /// checks the line is forwarded — with an empty one that assertion cannot
  /// fail, because the parameter defaults to `const []`.
  List<String> nodePath = const [];

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
    String? gateUci,
    String? breadth,
  }) async =>
      RepertoireFrontier(
        // One open position — the root — so the screen has a board rather than
        // the "nothing left in the queue" state.
        open: [
          FrontierNode(
              fen: nodeFen, path: nodePath, reach: 1, kind: 'undecided')
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
    String? gateUci,
    String? breadth,
    List<String> alongPath = const [],
  }) async {
    treeCalls += 1;
    lastAlongPath = alongPath;
    lastTreeRootFen = rootFen;
    lastTreeRootPath = rootPath;
    lastTreeGate = gateUci;
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
            // A second reply, so the line forks and "forward" has more than one
            // meaning at that node.
            RepertoireTreeMove(
              uci: 'g1f3',
              san: 'Nf3',
              fen: afterNf3,
              mine: false,
              share: 0.2,
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
/// Answers for the position after the student's own move, so the "Dalje"
/// step has something to open. `_SilentJudge` returns nothing, which sends
/// `_openReplies` down its other path and never moves the board.
class _RepliesJudge implements OpeningJudgeService {
  @override
  bool get hasPersonalToken => false;

  @override
  Future<OpeningJudgeLookup> judge(String fen, String move,
          {int? minRating}) async =>
      const OpeningJudgeLookup.unavailable('no-token');

  /// The position it was actually asked about, so a fixture that disagrees
  /// with the board says so instead of silently answering nothing.
  String? lastAsked;

  @override
  Future<OpponentRepliesLookup> replies(String fen, {int? minRating}) async {
    lastAsked = fen;
    // Matched on the placement and the side to move, not the whole FEN: the
    // counters and the en-passant square are the board's arithmetic, and a
    // fixture that guesses them wrong should not look like "no replies".
    if (!fen.startsWith('rnbqkbnr/pp3ppp/4p3/2ppP3/3P4/8/PPP2PPP/RNBQKBNR w')) {
      return const OpponentRepliesLookup.unavailable('n/a');
    }
    return const OpponentRepliesLookup.ok(OpponentReplies(
      total: 1000,
      replies: [
        OpponentReply(
            uci: 'c2c3', san: 'c3', games: 640, share: 0.64, covered: true),
      ],
      all: [
        OpponentReply(
            uci: 'c2c3', san: 'c3', games: 640, share: 0.64, covered: true),
      ],
      coveredShare: 0.64,
      tailMoves: 0,
      tailShare: 0,
    ));
  }

  @override
  void clearCache() {}
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

  Future<void> pump(
    WidgetTester tester,
    Size size, {
    Future<List<AnalysisLine>> Function(String fen, int depth, int multiPV)?
        analyse,
    bool cutTree = false,
    List<String> nodePath = const [],
    String nodeFen = advance,
    String? gateUci,
    OpeningJudgeService? judge,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    api = _FakeApi()
      ..cutTree = cutTree
      ..nodePath = nodePath
      ..nodeFen = nodeFen;
    await tester.pumpWidget(MaterialApp(
      home: RepertoireBuildScreen(
        name: 'French Defense: Advance — crni',
        color: 'b',
        rootFen: advance,
        rootPath: const ['e4', 'e6', 'd4', 'd5', 'e5'],
        gateUci: gateUci,
        api: api,
        judge: judge ?? _SilentJudge(),
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
    // decision and is stored as one — and the menu says so now, in the same
    // words as the button, because a label promising a deletion that never
    // happens is how the two came to look like two different powers over one
    // branch.
    await pump(tester, const Size(1400, 900));

    await tester.longPress(find.text('4. c3 64% ?'));
    await tester.pumpAndSettle();
    expect(find.text('Obriši Ovu Varijantu'), findsNothing);
    await tester.tap(find.text('Ne spremam ovu granu'));
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
    expect(find.text('Prikaži grane koje ne spremam (1)'), findsOneWidget);

    await tester.tap(find.text('Prikaži grane koje ne spremam (1)'));
    await tester.pumpAndSettle();
    expect(find.text('4. c3 64% ✂'), findsWidgets);
  });

  testWidgets('your own move can be forked into its own opening',
      (tester) async {
    // The fork lived on the row under the board, which forks the position
    // standing there. What somebody points at is a move — usually the second
    // one they play here — and that is a fork of the position it comes from,
    // gated on the move itself.
    await pump(tester, const Size(1400, 900));

    await tester.longPress(find.text('3... c5 ★'));
    await tester.pumpAndSettle();
    expect(find.text('Izdvoji u novo otvaranje'), findsOneWidget);

    await tester.tap(find.text('Izdvoji u novo otvaranje'));
    await tester.pumpAndSettle();

    // The dialog is up, and it already knows which move it is about.
    expect(find.text('Izdvoji u novo otvaranje'), findsWidgets);
    expect(find.textContaining('Kroz potez'), findsOneWidget);
  });

  testWidgets('the opponent move is not something to fork', (tester) async {
    await pump(tester, const Size(1400, 900));

    await tester.longPress(find.text('4. c3 64% ?'));
    await tester.pumpAndSettle();

    expect(find.text('Izdvoji u novo otvaranje'), findsNothing);
  });

  testWidgets('a cut branch is not offered as prepared', (tester) async {
    // The book's `covered` flag is about the 80% wave and knows nothing about
    // what this reader refused. So the replies panel offered „Idi" on a branch
    // the drawing was hiding behind „Prikaži odsečene grane" — two screens,
    // one repertoire, opposite answers, and the reader looking for the branch
    // in a tree that had deliberately put it away.
    api = _FakeApi();
    await pump(tester, const Size(1400, 900), cutTree: true);

    await tester.tap(find.textContaining('c5 ★').first);
    await tester.pumpAndSettle();

    expect(find.text('Idi'), findsNothing);
    expect(find.text('Vidi šta ne spremam'), findsOneWidget);
    expect(find.textContaining('✂ ne spremam'), findsOneWidget);
  });

  testWidgets('a reply that was not cut still says Idi', (tester) async {
    // The other half, so the test above cannot pass by the row never saying
    // „Idi" at all.
    api = _FakeApi();
    await pump(tester, const Size(1400, 900));

    await tester.tap(find.textContaining('c5 ★').first);
    await tester.pumpAndSettle();

    expect(find.text('Idi'), findsOneWidget);
    expect(find.textContaining('✂ ne spremam'), findsNothing);
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

  testWidgets('forward out of a branching position asks which line',
      (tester) async {
    // "Forward" has more than one meaning at a fork, and the palette always
    // took the first child — so every other branch was unreachable by
    // navigation at all, which is what the owner ran into.
    await pump(tester, const Size(1400, 900));

    // One step onto the student's own move, which is where the fork is.
    // The palette's own forward button: the strip below the board draws the
    // same chevron between its chips.
    final forward = find.descendant(
      of: find.byType(MoveNavigationControls),
      matching: find.byIcon(Icons.chevron_right),
    );
    await tester.tap(forward);
    await tester.pumpAndSettle();
    await tester.tap(forward);
    await tester.pumpAndSettle();

    expect(find.text('Odavde ide više linija — kojom?'), findsOneWidget);
    await tester.tap(find.descendant(
      of: find.byType(ListTile),
      matching: find.textContaining('Nf3 20%'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('1.e4 e6 2.d4 d5 3.e5 c5 4.Nf3'), findsOneWidget);
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

  testWidgets('going on lights up the move the board just made',
      (tester) async {
    // Reported live 4.9.2026: „pita me za potez, a u stablu mi je fokus na
    // drugoj poziciji."
    //
    // Going on moves the board to the position after the student's own move,
    // because that is where the opponent's answers belong. It did that by
    // loading the FEN straight through the board controller, which is the one
    // way to move the board that tells nothing else on the screen. The tree
    // highlights `_standingAfter ?? _current`, and `_standingAfter` was still
    // null -- so the picture went on lighting up the position behind the
    // board, and the stored book was still the one for the position behind it.
    final judge = _RepliesJudge();
    await pump(tester, const Size(1400, 900), judge: judge);

    final dalje = find.widgetWithText(FilledButton, 'Dalje');
    await tester.ensureVisible(dalje);
    await tester.pumpAndSettle();
    await tester.tap(dalje);
    await tester.pumpAndSettle();

    // The wave was opened at all -- otherwise the rest asserts nothing.
    expect(judge.lastAsked, isNotNull,
        reason: 'Dalje mora da otvori odgovore protivnika');

    final panel =
        tester.widget<RepertoireTreePanel>(find.byType(RepertoireTreePanel));
    expect(panel.active.moveSan, 'c5',
        reason: 'stablo mora da svetli na potezu koji tabla pokazuje');
    // The same thing said the other way: the book under the board belongs to
    // the position the board is standing on.
    expect(api.bookReads.last, judge.lastAsked);
  });

  group('the board does not scroll away from its own question', () {
    // Reported live 5.9.2026: „tabla sa navigacionom paletom ispod se
    // skrolovanjem ne vidi, treba da bude statična, a da se pomera samo ono
    // što je ispod". Reading the answer used to scroll the board off the top.
    for (final size in const [
      Size(360, 640),
      Size(360, 740),
      Size(900, 800),
    ]) {
      testWidgets(
          'board and palette stay inside the viewport at '
          '${size.width}x${size.height}', (tester) async {
        await pump(tester, size);

        // An overflowing Row or Column throws in a test build and is silently
        // clipped in a release one, which is why this is asserted rather than
        // looked at.
        expect(tester.takeException(), isNull);

        final board = tester.getRect(find.byType(ChessBoardWithOverlay));
        expect(board.top, greaterThanOrEqualTo(0.0));
        expect(board.bottom, lessThanOrEqualTo(size.height));

        final palette = tester.getRect(find.byType(MoveNavigationControls));
        expect(palette.bottom, lessThanOrEqualTo(size.height),
            reason: 'paleta ispod table mora da stane na ekran');
      });
    }

    testWidgets('scrolling the part below moves it and leaves the board',
        (tester) async {
      await pump(tester, const Size(360, 640));

      final boardBefore = tester.getRect(find.byType(ChessBoardWithOverlay));
      // A widget that lives *below* the split, so the drag is proved to have
      // scrolled something. Without this the board standing still would also
      // pass on a screen that simply does not scroll.
      final stripBefore = tester.getRect(find.byType(RepertoireLineStrip));

      // The scrollable the strip actually lives in, rather than a point on the
      // screen: a drag aimed by coordinate landed on the strip itself and moved
      // nothing, which made the board standing still prove nothing.
      final scroller = find
          .ancestor(
              of: find.byType(RepertoireLineStrip),
              matching: find.byType(Scrollable))
          .first;
      await tester.drag(scroller, const Offset(0, -160));
      await tester.pump();

      expect(tester.getRect(find.byType(RepertoireLineStrip)).top,
          lessThan(stripBefore.top),
          reason: 'ispod table ništa se nije pomerilo — potez nije skrolovao');
      expect(tester.getRect(find.byType(ChessBoardWithOverlay)), boardBefore,
          reason: 'tabla se pomerila sa ostatkom');
    });

    testWidgets('a short screen shrinks the board rather than the question',
        (tester) async {
      // The height rule only bites here. On an ordinary 360x640 phone the width
      // rule caps the board at 336 anyway, so a test there passes with the
      // height clamp deleted — which is a test that proves nothing. At 360x480
      // width alone would ask for 336, the banners and palette take another
      // ~114, and the region below would be a few pixels high.
      await pump(tester, const Size(360, 480));

      expect(tester.takeException(), isNull);
      final board = tester.getRect(find.byType(ChessBoardWithOverlay));
      expect(board.bottom, lessThanOrEqualTo(480.0));
      final palette = tester.getRect(find.byType(MoveNavigationControls));
      expect(480.0 - palette.bottom, greaterThan(60.0),
          reason: 'na niskom ekranu ispod palete nije ostalo ništa');
    });

    testWidgets('a desktop window keeps room under the board too',
        (tester) async {
      // The owner's screenshot of 5.9.2026: at 1920x1015 the board sat on its
      // 560 ceiling and left 189 px under it, because the wide branch clamped
      // by a flat `maxHeight - 280` that never bit on a real window. The share
      // rule is the phone's, and it is now the same constant.
      await pump(tester, const Size(1920, 1000));

      expect(tester.takeException(), isNull);
      // Measured on `BoardWithCoordinates`, which is the widget `_boardSize`
      // is handed to. `ChessBoardWithOverlay` inside it is the board *minus*
      // its coordinate gutter, and asserting on that is how the first version
      // of this test passed with the rule reverted: 540 is under 560 either
      // way.
      final board = tester.getRect(find.byType(BoardWithCoordinates));
      final palette = tester.getRect(find.byType(MoveNavigationControls));

      // With the old flat `maxHeight - 280` this window gave a board of exactly
      // 560 — its ceiling — and 300 px under the palette. Measured 5.9.2026,
      // both numbers, before and after.
      expect(board.height, lessThan(560.0),
          reason: 'tabla je i dalje na plafonu — pravilo po visini ne ujeda');
      expect(1000.0 - palette.bottom, greaterThan(340.0),
          reason: 'ispod table na desktopu nije ostalo više nego ranije');
    });

    testWidgets('there is something left to scroll', (tester) async {
      // The failure this exists for: a board sized by width alone, pinned,
      // fills the screen and leaves the region under it a few pixels high — so
      // nothing is clipped and nothing is reachable either.
      await pump(tester, const Size(360, 640));

      final palette = tester.getRect(find.byType(MoveNavigationControls));
      expect(640.0 - palette.bottom, greaterThan(80.0),
          reason: 'ispod table i palete nije ostalo šta da se skroluje');
    });
  });

  group('showing only one branch', () {
    testWidgets('narrowing asks the drawing for the position on the board',
        (tester) async {
      // The owner's decision of 5.9.2026: this is the repertoire's own gate
      // asked for a different position — `rootFen` plus the path down to it —
      // and *not* a second filter written beside it. Two different „only this
      // branch" in one app is the shape that drifts apart later.
      // With a real gate on the screen: dropping it while narrowed is one of
      // the two things this test holds, and a null gate would prove neither.
      await pump(tester, const Size(1200, 900),
          nodePath: const ['c5', 'c3'], nodeFen: afterC3, gateUci: 'c7c5');
      final wholeRoot = api.lastTreeRootFen;
      expect(api.lastTreeGate, 'c7c5');

      await tester.tap(find.text('Prikaži samo od ove pozicije'));
      await tester.pumpAndSettle();

      expect(api.lastTreeRootFen, afterC3);
      expect(api.lastTreeRootFen, isNot(wholeRoot),
          reason: 'crtež je i dalje tražen od korena repertoara');
      // The breadcrumb still reads from move one: the repertoire's own path,
      // then the line down to where the reader narrowed.
      expect(api.lastTreeRootPath,
          containsAllInOrder(const ['e4', 'e6', 'd4', 'd5', 'e5', 'c5', 'c3']));
      // And the repertoire's gate is dropped, because a gate out of a root the
      // walk no longer starts at means nothing.
      expect(api.lastTreeGate, isNull);
      // The standing line is said from the new root, not from the repertoire's.
      // Handed over absolute it would not replay from this position, and the
      // server refuses a path that does not replay rather than trimming it —
      // so this would be a 500 rather than a wrong drawing.
      expect(api.lastAlongPath, isEmpty);
    });

    testWidgets('widening puts the whole repertoire back', (tester) async {
      await pump(tester, const Size(1200, 900),
          nodePath: const ['c5', 'c3'], nodeFen: afterC3);
      final wholeRoot = api.lastTreeRootFen;

      await tester.tap(find.text('Prikaži samo od ove pozicije'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Prikaži ceo repertoar'));
      await tester.pumpAndSettle();

      expect(api.lastTreeRootFen, wholeRoot);
      expect(api.lastTreeRootPath, const ['e4', 'e6', 'd4', 'd5', 'e5']);
    });
  });

  group('the drawing is asked to reach the reader', () {
    testWidgets('the tree read carries the line the board is standing on',
        (tester) async {
      // The other half of the fix reported live 5.9.2026: „ne treba gubiti
      // fokus u stablu poteza". The picture is drawn at the repertoire's width,
      // and a move played outside that width was written and then not drawn —
      // so the highlight fell back to the repertoire's root, which reads as
      // being thrown to the beginning mid-thought.
      //
      // The server follows this line whatever the breadth says
      // (`coveredReplies`, and its own tests). What this test holds is the half
      // that lives here: the screen has to actually send it. It is the same
      // shape as `maxPly`, which was added for depth on 4.9.2026 — a picture
      // that cannot reach the reader is the bug, and width was the other half.
      // A non-empty path on purpose. `alongPath` defaults to `const []`, so
      // with an empty one this assertion passes whether or not the screen sends
      // anything — which is a test that cannot fail, and this codebase has
      // shipped two of those.
      await pump(tester, const Size(1200, 900),
          nodePath: const ['c5', 'c3'], nodeFen: afterC3);

      expect(api.treeCalls, greaterThan(0));
      expect(api.lastAlongPath, ['c5', 'c3']);
    });
  });

  group('the unconfirmed banner has room for its own label', () {
    /// „Pregledaj nepotvrđene" is four characters longer than the „Pregledaj
    /// nacrt" this banner was built around, and on a 360 dp phone that is a
    /// 22-pixel overflow. In a release build nothing is painted over it — the
    /// button is simply clipped and unreachable, which is the whole reason
    /// CLAUDE.md keeps a section about it. In a test build it throws, which is
    /// what these two tests are for.
    Future<void> pumpBanner(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: UnconfirmedBanner(total: 4, onOpenWizard: () {})),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('a 360 dp phone puts the button under the sentence',
        (tester) async {
      await pumpBanner(tester, 360);

      expect(tester.takeException(), isNull, reason: 'preliv na telefonu');
      // The property is that they are stacked, not that a particular gap is a
      // particular size. The old form asserted `sentence.dy + 30`, which is a
      // proxy for the row's height — and it broke the day the banner was
      // compacted from 134 px to 66, saying nothing about whether the button
      // had moved. Below the sentence's *bottom* is the thing that was meant.
      final sentence = tester.getRect(find.text('4 nepotvrđenih u grafu'));
      final button = tester.getTopLeft(find.text('Pregledaj nepotvrđene'));
      expect(button.dy, greaterThan(sentence.bottom),
          reason: 'na telefonu dugme ide ispod rečenice');
    });

    testWidgets('a wide window keeps them on one row', (tester) async {
      // The half that is easy to lose while fixing the half above: a `Wrap`
      // solves the phone and stacks the desktop too, because `SpeakableInfo`
      // is a `Row` with an `Expanded` in it and takes the whole width.
      await pumpBanner(tester, 1200);

      expect(tester.takeException(), isNull);
      final sentence = tester.getTopLeft(find.text('4 nepotvrđenih u grafu'));
      final button = tester.getTopLeft(find.text('Pregledaj nepotvrđene'));
      expect((button.dy - sentence.dy).abs(), lessThan(30),
          reason: 'u širokom prozoru stoje jedno pored drugog');
    });
  });
}
