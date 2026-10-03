import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/services/opening_explorer_service.dart';
import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/opening_explorer_panel_widget.dart';
import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/features/analysis_studio/widgets/visual_move_tree_widget.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_build_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/features/repertoire/widgets/repertoire_tree_panel.dart';
import 'package:chess_app/features/analysis_studio/services/opening_book_service.dart';
import 'package:chess_app/features/repertoire/widgets/opening_banner.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';

import 'support/landscape.dart';

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

  /// What the tree's context menu asked the server to do.
  final List<String> promoted = [];
  final List<String> removed = [];
  final List<({String fen, String uci})> removedOpponent = [];
  final List<List<String>> pruned = [];

  /// What removing a move would strand.
  ({List<String> keys, int decisions})? orphans =
      (keys: const <String>[], decisions: 0);

  /// A server that does not answer the removal of an opponent move.
  bool removeOpponentFails = false;

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
  Future<bool> removeOpponentMove({
    required String color,
    required String fen,
    required String uci,
  }) async {
    if (removeOpponentFails) return false;
    removedOpponent.add((fen: fen, uci: uci));
    return true;
  }

  @override
  Future<({List<String> keys, int decisions})?> orphansOfRemoving({
    required String color,
    required String fen,
    required String uci,
  }) async =>
      orphans;

  @override
  Future<int> prune({
    required String color,
    required List<String> keys,
  }) async {
    pruned.add(keys);
    return keys.length;
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
  Future<RepertoireFrontier?> frontier({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    String? gateUci,
  }) async =>
      RepertoireFrontier(
        // One open position — the root — so the screen has a board rather than
        // the "nothing left in the queue" state.
        open: [FrontierNode(fen: nodeFen, path: nodePath)],
        decided: 1,
      );

  @override
  Future<RepertoireTree?> repertoireTree({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int maxPly = 16,
    String? gateUci,
  }) async {
    treeCalls += 1;
    lastTreeRootFen = rootFen;
    lastTreeRootPath = rootPath;
    lastTreeGate = gateUci;
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
class _SilentJudge implements OpeningJudgeService {
  @override
  Future<OpeningJudgeLookup> judge(String fen, String move) async =>
      const OpeningJudgeLookup.unavailable('not-configured');

  @override
  Future<OpponentRepliesLookup> replies(String fen) async =>
      const OpponentRepliesLookup.unavailable('not-configured');

  @override
  void clearCache() {}
}

/// An opening the fixture can actually name, so the banner draws something.
final _entry = OpeningBookEntry(
    eco: 'C54', name: 'Italian Game: Giuoco Pianissimo', pgn: '');
const _openingLabel = 'C54 · Italian Game: Giuoco Pianissimo';
OpeningBookEntry? _named(String fen) => _entry;

OpeningExplorerMove _bookMove(String uci, String san, int games) =>
    OpeningExplorerMove(
        uci: uci,
        san: san,
        white: games ~/ 3,
        draws: games ~/ 3,
        black: games - 2 * (games ~/ 3));

/// The book at every position: three moves, so the panel draws its chips.
Future<OpeningExplorerLookup> _book(String fen) async =>
    OpeningExplorerLookup.ok(OpeningExplorerResult(
      fen: fen,
      white: 2600,
      draws: 2200,
      black: 1700,
      moves: [
        _bookMove('c7c5', 'c5', 4100),
        _bookMove('d8b6', 'Qb6', 1500),
        _bookMove('b8c6', 'Nc6', 900),
      ],
    ));

/// Three lines, each with an evaluation no other text on the screen carries,
/// and a continuation long enough to be cut, as a real one is.
const _evals = ['-0.31', '-0.47', '-0.62'];
Future<List<AnalysisLine>> _engine(String fen, int depth, int multiPV) async =>
    [
      for (var i = 0; i < multiPV; i++)
        AnalysisLine(
          multipv: i + 1,
          depth: depth,
          evaluation: _evals[i % 3],
          bestMoveLan: const ['c7c5', 'd8b6', 'b8c6'][i % 3],
          bestMoveSan: const ['c5', 'Qb6', 'Nc6'][i % 3],
          continuationLan: '',
          continuationSan: 'c3 Nc6 Nf3 Qb6 a3 c4 Nbd2 Bd7 Be2 Na5 O-O Ne7',
          sanMoveList: const [],
          fenList: const [],
          fromSquare: const ['c7', 'd8', 'b8'][i % 3],
          toSquare: const ['c5', 'b6', 'c6'][i % 3],
        ),
    ];

/// The rectangle an element is drawn in.
Rect _rectOf(Element element) {
  final box = element.renderObject! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Every widget [finder] matches is seen: inside the window **and** inside
/// every box that scrolls it. `expectOnScreen` alone passes a panel that is
/// built below the fold of its own box — laid out, inside the window, and a
/// scroll away, which is the very thing the owner asked to be rid of.
void _expectSeen(WidgetTester tester, Size size, Finder finder) {
  expectOnScreen(tester, size, finder);
  for (final element in finder.evaluate()) {
    final rect = _rectOf(element);
    element.visitAncestorElements((ancestor) {
      if (ancestor.widget is Scrollable) {
        final box = _rectOf(ancestor);
        expect(
            box.contains(rect.topLeft) &&
                box.contains(rect.bottomRight - const Offset(1, 1)),
            isTrue,
            reason: '${element.widget} is a scroll away at ${sizeLabel(size)}: '
                '$rect outside $box');
      }
      return true;
    });
  }
}

void main() {
  // Real glyphs: these tests measure whether rows fit.
  setUpAll(loadRoboto);

  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late _FakeApi api;

  Future<void> pump(
    WidgetTester tester,
    Size size, {
    Future<List<AnalysisLine>> Function(String fen, int depth, int multiPV)?
        analyse,
    List<String> nodePath = const [],
    String nodeFen = advance,
    String? gateUci,
    OpeningBookEntry? Function(String fen)? openingLookup,
    OpeningJudgeService? judge,
    void Function(String fen)? onDrillHere,
    Future<OpeningExplorerLookup> Function(String fen)? explore,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    api = _FakeApi()
      ..nodePath = nodePath
      ..nodeFen = nodeFen;
    await tester.pumpWidget(MaterialApp(
      home: RepertoireBuildScreen(
        name: 'French Defense: Advance — crni',
        color: 'b',
        rootFen: advance,
        rootPath: const ['e4', 'e6', 'd4', 'd5', 'e5'],
        gateUci: gateUci,
        openingLookup: openingLookup,
        api: api,
        judge: judge ?? _SilentJudge(),
        onDrillHere: onDrillHere,
        analyse: analyse ?? (fen, depth, multiPV) async => const [],
        explore: explore,
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

  for (final size in landscapePhones) {
    testWidgets('on a phone held sideways at ${sizeLabel(size)}',
        (tester) async {
      await pump(tester, size, openingLookup: _named, onDrillHere: (_) {});
      expectBoardBeside(tester, size);
      // The buttons under the strip: one row, all three on screen.
      final labels = ['Ask engine', 'Next position', 'Drill this branch'];
      for (final label in labels) {
        expectOnScreen(tester, size, find.text(label));
      }
      expect(
          labels.map((l) => tester.getCenter(find.text(l)).dy.round()).toSet(),
          hasLength(1),
          reason: 'the buttons wrapped at ${sizeLabel(size)}');
      expect(find.byType(AnalysisMoveTreeWidget), findsOneWidget);
      expect(find.text(_openingLabel), findsOneWidget);
    });
  }

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
    // The position after my own move has the opponent to move, and that is
    // where the opponent's moves are played on the board.
    await pump(tester, const Size(1400, 900));

    await tester.tap(find.textContaining('c5 ★').first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The breadcrumb names the board, not the position behind it.
    expect(find.text('1.e4 e6 2.d4 d5 3.e5 c5'), findsOneWidget);
    // SUPERSEDED: „After c5 — which opponent moves do you prepare?" — the move
    // is said as a move now (phase 4c of `docs/PLAN-GOVOR-IZ-KLIPOVA.md`).
    expect(find.text('After pawn c5 which opponent moves do you prepare?'),
        findsOneWidget);
    // No button back to the position already on the board: the strip under
    // it is the way back.
    expect(find.text('Back to c5'), findsNothing);
    expect(
      tester
          .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
          .isAllowedToMove,
      isTrue,
      reason: 'the opponent\'s move is played on the board',
    );
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
    await tester.tap(find.text('Promote to Main Line'));
    await tester.pumpAndSettle();

    expect(api.promoted, ['c7c5']);
  });

  testWidgets('deleting the opponent\'s move removes the move they entered',
      (tester) async {
    // Every opponent move in a repertoire is one the student played, so it is
    // deleted like one — from the position it is played from.
    await pump(tester, const Size(1400, 900));

    await tester.longPress(find.text('4. c3 64% ?'));
    await tester.pumpAndSettle();
    expect(find.text('Do not prepare this branch'), findsNothing);
    await tester.tap(find.text('Delete this opponent move'));
    await tester.pumpAndSettle();

    expect(api.removedOpponent, [(fen: afterC5, uci: 'c2c3')]);
    expect(api.removed, isEmpty);
  });

  testWidgets('deleting the opponent\'s move takes what only it reached',
      (tester) async {
    // Positions reached only through the deleted move go with it, or they are
    // left in the database where no walk can find them.
    await pump(tester, const Size(1400, 900));
    api.orphans = (keys: const ['k1'], decisions: 0);

    await tester.longPress(find.text('4. c3 64% ?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete this opponent move'));
    await tester.pumpAndSettle();

    expect(api.pruned, [
      ['k1']
    ]);
  });

  testWidgets('an opponent move the server kept takes nothing with it',
      (tester) async {
    await pump(tester, const Size(1400, 900));
    api.orphans = (keys: const ['k1'], decisions: 0);
    api.removeOpponentFails = true;

    await tester.longPress(find.text('4. c3 64% ?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete this opponent move'));
    await tester.pumpAndSettle();

    expect(api.pruned, isEmpty);
    expect(find.textContaining('was not removed'), findsOneWidget);
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
    expect(find.text('Extract into new opening'), findsOneWidget);

    await tester.tap(find.text('Extract into new opening'));
    await tester.pumpAndSettle();

    // The dialog is up, and it already knows which move it is about.
    expect(find.text('Fork into new opening'), findsOneWidget);
    expect(find.textContaining('Through move'), findsOneWidget);
  });

  testWidgets('the opponent move is not something to fork', (tester) async {
    await pump(tester, const Size(1400, 900));

    await tester.longPress(find.text('4. c3 64% ?'));
    await tester.pumpAndSettle();

    expect(find.text('Extract into new opening'), findsNothing);
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
    expect(find.text('Move 0 of 2'), findsOneWidget);
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

    expect(find.text('Multiple lines from here — which one?'), findsOneWidget);
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
    await tester.ensureVisible(find.text('Ask engine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask engine'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tap a line'), findsOneWidget);

    // The root card is the position the board is standing on.
    await tester.tap(find.text('🏁').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Tap a line'), findsOneWidget);
  });

  testWidgets('tapping your own move lights up that move in the drawing',
      (tester) async {
    // Reported live 4.9.2026: „pita me za potez, a u stablu mi je fokus na
    // drugoj poziciji." The tree highlights the board, never the position
    // behind it.
    await pump(tester, const Size(1400, 900));

    await tester.tap(find.textContaining('c5 ★').first);
    await tester.pumpAndSettle();

    final panel =
        tester.widget<RepertoireTreePanel>(find.byType(RepertoireTreePanel));
    expect(panel.active.moveSan, 'c5',
        reason: 'the drawing must light up the move the board shows');
  });

  testWidgets('nothing retired is drawn under the board', (tester) async {
    await pump(tester, const Size(1400, 900));

    for (final gone in const [
      'Review unconfirmed',
      'Suggest main line',
      'Do not prepare this',
      'Next',
      'Skip',
    ]) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
    expect(find.textContaining('queries'), findsNothing);
  });

  group('the opening name rides in the app bar', () {
    testWidgets('wide: in the bar; narrow: above the board', (tester) async {
      // Handed a lookup that names the position. Without one the banner draws
      // `SizedBox.shrink()` and every assertion below is about a zero-sized box
      // sitting wherever the layout left it — which is how the first version of
      // these tests passed with the whole move reverted.
      await pump(tester, const Size(1400, 900), openingLookup: _named);
      expect(tester.takeException(), isNull);
      expect(find.text(_openingLabel), findsOneWidget,
          reason: 'ime otvaranja se uopšte ne crta');
      // Exactly one, always. A `GlobalKey` in two places throws, and the key is
      // what keeps the carried name across the move.
      expect(find.byType(OpeningBanner), findsOneWidget);
      expect(tester.getRect(find.text(_openingLabel)).bottom,
          lessThanOrEqualTo(kToolbarHeight + 8),
          reason: 'ime otvaranja nije u zaglavlju');

      await pump(tester, const Size(360, 640), openingLookup: _named);
      expect(find.byType(OpeningBanner), findsOneWidget);
      expect(tester.getRect(find.text(_openingLabel)).top,
          greaterThan(kToolbarHeight),
          reason: 'na telefonu u zaglavlju nema mesta za njega');
    });

    testWidgets('the carried name survives crossing the breakpoint',
        (tester) async {
      // The whole reason `_openingKey` exists. `_lastNamed` is State, and a
      // widget that changes parent normally gets a new one — which would blank
      // the opening's name every time a window is dragged past 840 dp.
      // A lookup that answers **once**. That is the situation the carried name
      // exists for: the opening was named at some earlier position and the
      // board has since walked into unnamed ones. A lookup that always answers
      // would let a fresh `State` find the name again, and the test would pass
      // with the key removed — which is exactly what it did at first.
      var answers = 1;
      OpeningBookEntry? once(String fen) => answers-- > 0 ? _entry : null;

      await pump(tester, const Size(1400, 900), openingLookup: once);
      expect(find.text(_openingLabel), findsOneWidget,
          reason: 'ništa nije imenovano ni pre praga');

      // Same screen, resized across the threshold rather than rebuilt.
      tester.view.physicalSize = const Size(900, 900);
      await tester.pumpAndSettle();

      expect(find.byType(OpeningBanner), findsOneWidget);
      expect(find.text(_openingLabel), findsOneWidget,
          reason: 'nošeno ime je nestalo pri prelasku praga');
    });

    testWidgets('between the thresholds it heads the panels beside the board',
        (tester) async {
      // 900 dp is not wide enough: the opening's name waits for `ultraWide`.
      //
      // Rewritten 30.9.2026. It used to say „and the board is still below
      // it": the name stood over the board in the board's column. Since the
      // board takes the window's height (`RepertoireLayout`), a row over it
      // is height the board gives up, so the name heads the position's
      // panels instead — beside the board, with the book it names.
      await pump(tester, const Size(900, 800), openingLookup: _named);

      expect(tester.takeException(), isNull);
      expect(find.byType(OpeningBanner), findsOneWidget);
      final name = tester.getRect(find.text(_openingLabel));
      expect(name.top, greaterThan(kToolbarHeight),
          reason: 'the opening name is in the bar where it has no room');
      expect(
          name.left,
          greaterThanOrEqualTo(
              tester.getRect(find.byType(BoardWithCoordinates)).right),
          reason: 'the opening name is not beside the board');
    });
  });

  group('the drawing keeps what the reader set by hand', () {
    // Reported live 5.9.2026: „zum mi se resetuje kad promenim veličinu
    // prozora". The tree has two homes across `Breakpoints.wide` (840) — its
    // own column beside the board, and under the controls — and a widget that
    // changes parent gets a new `State`, so its `TransformationController`
    // went back to the identity matrix. Measured then: 1,5625 -> 1,0.
    //
    // The rule it breaks is unconditional: „aplikacija nikad ne menja sama
    // zum". This asserts the scale rather than the pan, because crossing does
    // legitimately move the view — a narrower viewport can put the active card
    // at an edge, and `_ensureActiveVisible` translates. It never scales.
    double scaleOf(WidgetTester tester) {
      final viewer = tester.widget<InteractiveViewer>(find.descendant(
        of: find.byType(VisualMoveTreeWidget),
        matching: find.byType(InteractiveViewer),
      ));
      return viewer.transformationController!.value.getMaxScaleOnAxis();
    }

    testWidgets('the zoom survives crossing the breakpoint', (tester) async {
      await pump(tester, const Size(1000, 900));
      expect(find.byType(VisualMoveTreeWidget), findsOneWidget);

      // What the reader's pinch or scroll wheel does, done directly: the
      // widget's own `_zoomBy` writes this same controller.
      final viewer = tester.widget<InteractiveViewer>(find.descendant(
        of: find.byType(VisualMoveTreeWidget),
        matching: find.byType(InteractiveViewer),
      ));
      viewer.transformationController!.value = Matrix4.identity()
        ..scaleByDouble(1.5625, 1.5625, 1, 1);
      await tester.pumpAndSettle();
      expect(scaleOf(tester), closeTo(1.5625, 0.0001),
          reason: 'zum nije ni postavljen, pa prelazak ništa ne dokazuje');

      // Same screen, resized across 840 rather than rebuilt — which is what
      // dragging a window edge on Windows is.
      tester.view.physicalSize = const Size(800, 900);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(VisualMoveTreeWidget), findsOneWidget);
      expect(scaleOf(tester), closeTo(1.5625, 0.0001),
          reason: 'zum je resetovan pri prelasku praga');

      // And back, because a window edge is dragged in both directions.
      tester.view.physicalSize = const Size(1000, 900);
      await tester.pumpAndSettle();
      expect(scaleOf(tester), closeTo(1.5625, 0.0001),
          reason: 'zum je resetovan pri povratku preko praga');
    });

    testWidgets('the zoom survives the tree leaving its own column',
        (tester) async {
      // Since 30.9.2026 a desktop window has two homes for the tree as well:
      // a column of its own beside the panels, from 1508 wide at this height,
      // and over the panels below that (`RepertoireLayout`). The same rule
      // holds across that width.
      await pump(tester, const Size(1508, 792));
      final viewer = tester.widget<InteractiveViewer>(find.descendant(
        of: find.byType(VisualMoveTreeWidget),
        matching: find.byType(InteractiveViewer),
      ));
      viewer.transformationController!.value = Matrix4.identity()
        ..scaleByDouble(1.5625, 1.5625, 1, 1);
      await tester.pumpAndSettle();
      final treeInColumn = tester.getRect(find.byType(VisualMoveTreeWidget));

      tester.view.physicalSize = const Size(1507, 792);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Proof the home changed — without it the scale surviving proves
      // nothing: the tree over the panels is wider and shorter.
      expect(tester.getRect(find.byType(VisualMoveTreeWidget)).width,
          greaterThan(treeInColumn.width + 300));
      expect(scaleOf(tester), closeTo(1.5625, 0.0001),
          reason: 'the zoom was reset when the tree left its column');

      tester.view.physicalSize = const Size(1508, 792);
      await tester.pumpAndSettle();
      expect(scaleOf(tester), closeTo(1.5625, 0.0001),
          reason: 'the zoom was reset when the tree went back to its column');
    });

    testWidgets('and it is drawn exactly once at every width', (tester) async {
      // `_treeKey` in two places at once throws, so the two homes have to be
      // mutually exclusive at every width — including the ones where the body's
      // `LayoutBuilder` and a second reading of `MediaQuery` could disagree.
      for (final size in const [
        Size(360, 640),
        Size(800, 900),
        Size(840, 900),
        Size(1000, 900),
        Size(1400, 900),
        Size(1507, 792),
        Size(1508, 792),
        Size(1536, 792),
      ]) {
        await pump(tester, size);
        expect(tester.takeException(), isNull, reason: 'na $size');
        expect(find.byType(VisualMoveTreeWidget), findsOneWidget,
            reason: 'crtež nije tačno jednom na $size');
      }
    });
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

    // „A desktop window keeps room under the board too" stood here: at
    // 1920 × 1000 the board had to stay under 560 and leave 340 px under the
    // strip, for the panels that stood there. Superseded on the owner's word
    // of 30.9.2026 — the book and the engine go beside the board and the
    // board takes the window's height (`RepertoireLayout`); the group below
    // holds the new rule at the same window.

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

  group('the book and the engine beside the board (30.9.2026)', () {
    // The owner's request: „da korisnik ne skroluje sve vreme ispod table dok
    // traži najbolje poteze koje daje statistika iz otvaranja i engine", the
    // comment column gone, and a larger board. Chosen from the sketches in
    // `docs/skice/repertoar.html`: three columns where they fit, the tree
    // over the panels where they do not. The board sizes are the literals of
    // `test/repertoire_layout_test.dart`, held here to the real screen.
    tearDown(() => AppSettingsService.instance.setBoardSizeScale(1.0));

    Future<void> askEngine(WidgetTester tester) async {
      await tester.tap(find.text('Ask engine'));
      await tester.pumpAndSettle();
      expect(find.text(_evals.first), findsOneWidget,
          reason: 'the engine was asked and drew nothing');
    }

    testWidgets(
        "the owner's window: a board of 668, and everything beside it seen",
        (tester) async {
      const size = Size(1536, 792);
      await pump(tester, size, explore: _book, analyse: _engine);
      await askEngine(tester);
      expect(tester.takeException(), isNull);

      // Measured on `BoardWithCoordinates`, the widget the layout's size is
      // handed to; the board inside it is that less its coordinates.
      final board = tester.getRect(find.byType(BoardWithCoordinates));
      expect(board.height, 668, reason: "today's rule gave 368 here");
      expect(board.width, 668);
      final strip = tester.getRect(find.byType(MoveNavigationControls));
      expect(strip.top, greaterThanOrEqualTo(board.bottom));
      expect(strip.bottom, lessThanOrEqualTo(size.height));

      // The book, the moves kept and every engine line, without a scroll.
      _expectSeen(tester, size, find.byType(OpeningExplorerPanelWidget));
      _expectSeen(tester, size, find.text('Your moves here'));
      for (final eval in _evals) {
        _expectSeen(tester, size, find.text(eval));
      }
      _expectSeen(tester, size, find.text('Ask engine'));
      _expectSeen(tester, size, find.text('Next position'));

      // Three columns: the panels beside the board, the tree beside them.
      final book = tester.getRect(find.byType(OpeningExplorerPanelWidget));
      final tree = tester.getRect(find.byType(VisualMoveTreeWidget));
      expect(book.left, greaterThanOrEqualTo(board.right));
      expect(tree.left, greaterThanOrEqualTo(book.right));
      // As tall as its column, not the 420 the card keeps under a board.
      expect(tree.height, greaterThan(500),
          reason: 'the tree does not fill its column');
      expect(tree.bottom, lessThanOrEqualTo(size.height));

      // No column for the comment: with nothing written there is nothing.
      expect(find.text('My comment'), findsNothing);
    });

    testWidgets('1920 × 1000: the board takes the height, 876', (tester) async {
      const size = Size(1920, 1000);
      await pump(tester, size, explore: _book, analyse: _engine);
      await askEngine(tester);
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byType(BoardWithCoordinates)).height, 876);
      expect(tester.getRect(find.byType(MoveNavigationControls)).bottom,
          lessThanOrEqualTo(size.height));
      _expectSeen(tester, size, find.byType(OpeningExplorerPanelWidget));
      for (final eval in _evals) {
        _expectSeen(tester, size, find.text(eval));
      }
    });

    testWidgets('under the tree, the book and the engine stand side by side',
        (tester) async {
      // 1400 × 792 is too narrow for three columns beside a board of 668,
      // and leaves a pane of 704 — past the 640 the two halves need.
      const size = Size(1400, 792);
      await pump(tester, size, explore: _book, analyse: _engine);
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byType(BoardWithCoordinates)).height, 668);

      // Before it is asked the engine's half says so, and is not empty.
      _expectSeen(tester, size,
          find.text('The engine has not been asked about this position.'));

      await askEngine(tester);
      final book = tester.getRect(find.byType(OpeningExplorerPanelWidget));
      final line = tester.getRect(find.text(_evals.first));
      final tree = tester.getRect(find.byType(VisualMoveTreeWidget));
      expect(line.left, greaterThanOrEqualTo(book.right),
          reason: 'the engine is not beside the book');
      expect(book.top, greaterThanOrEqualTo(tree.bottom),
          reason: 'the panels are not under the tree');
      _expectSeen(tester, size, find.byType(OpeningExplorerPanelWidget));
      for (final eval in _evals) {
        _expectSeen(tester, size, find.text(eval));
      }
      _expectSeen(tester, size, find.text('Ask engine'));
    });

    for (final size in const [Size(1200, 800), Size(900, 700)]) {
      testWidgets('at ${sizeLabel(size)} the book is seen beside the board',
          (tester) async {
        // The narrow desktop windows: one column under the tree, which
        // scrolls. The book comes first in it and must not need that.
        await pump(tester, size, explore: _book, analyse: _engine);
        expect(tester.takeException(), isNull);
        final board = tester.getRect(find.byType(BoardWithCoordinates));
        final book = tester.getRect(find.byType(OpeningExplorerPanelWidget));
        expect(book.left, greaterThanOrEqualTo(board.right));
        _expectSeen(tester, size, find.byType(OpeningExplorerPanelWidget));
        _expectSeen(tester, size, find.text('Ask engine'));
        expect(tester.getRect(find.byType(MoveNavigationControls)).bottom,
            lessThanOrEqualTo(size.height));
      });
    }

    testWidgets('the board-size setting shrinks the board, and the tree gains',
        (tester) async {
      const size = Size(1536, 792);
      await pump(tester, size);
      final fullTree = tester.getRect(find.byType(VisualMoveTreeWidget));

      await AppSettingsService.instance.setBoardSizeScale(0.6);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byType(BoardWithCoordinates)).height,
          closeTo(668 * 0.6, 0.01));
      expect(tester.getRect(find.byType(VisualMoveTreeWidget)).width,
          closeTo(fullTree.width + 668 * 0.4, 0.01));
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

      await tester.tap(find.text('Show only from this position'));
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
    });

    testWidgets('widening puts the whole repertoire back', (tester) async {
      await pump(tester, const Size(1200, 900),
          nodePath: const ['c5', 'c3'], nodeFen: afterC3);
      final wholeRoot = api.lastTreeRootFen;

      await tester.tap(find.text('Show only from this position'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show entire repertoire'));
      await tester.pumpAndSettle();

      expect(api.lastTreeRootFen, wholeRoot);
      expect(api.lastTreeRootPath, const ['e4', 'e6', 'd4', 'd5', 'e5']);
    });
  });
}
