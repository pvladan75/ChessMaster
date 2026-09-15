import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/services/opening_explorer_service.dart';
import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/visual_move_tree_widget.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_build_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// The drawing has to contain the position the board is standing on.
///
/// Reported live 5.9.2026: „posle izbora poteza protivnika, taj potez se ne
/// prikazuje na stablu poteza, a trebalo bi — da vidim i u stablu na šta treba
/// da odgovaram." The way in then was a „Go" button on a book row; since the
/// repertoire is built on the board, it is playing the opponent's move there.
const advance = 'rnbqkbnr/ppp2ppp/4p3/3pP3/3P4/8/PPP2PPP/RNBQKBNR b KQkq - 0 3';

/// After 3...c5 — the student's own move.
const afterC5 =
    'rnbqkbnr/pp3ppp/4p3/2ppP3/3P4/8/PPP2PPP/RNBQKBNR w KQkq c6 0 4';

/// After 4.c3 — the opponent move the reader plays on the board.
const afterC3 =
    'rnbqkbnr/pp3ppp/4p3/2ppP3/3P4/2P5/PP3PPP/RNBQKBNR b KQkq - 0 4';

/// A server that answers the way the real one does: the opponent's move is in
/// the drawing only once it has been entered.
class _FakeApi extends RepertoireApiService {
  _FakeApi() : super(client: MockClient((_) async => http.Response('{}', 500)));

  int treeReads = 0;
  final List<({String fen, String uci})> entered = [];

  @override
  Future<RepertoireFrontier?> frontier({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    String? gateUci,
  }) async =>
      const RepertoireFrontier(
        open: [FrontierNode(fen: advance, path: [])],
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
    treeReads += 1;
    final hasC3 = entered.any((e) => e.uci == 'c2c3');
    return RepertoireTree(
      rootFen: advance,
      rootPath: const ['e4', 'e6', 'd4', 'd5', 'e5'],
      children: [
        RepertoireTreeMove(
          uci: 'c7c5',
          san: 'c5',
          fen: afterC5,
          mine: true,
          role: 'primary',
          children: [
            if (hasC3)
              const RepertoireTreeMove(
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
  Future<bool> addOpponentMove({
    required String color,
    required String fen,
    required String uci,
    String? san,
  }) async {
    entered.add((fen: fen, uci: uci));
    return true;
  }
}

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late _FakeApi api;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    api = _FakeApi();
    await tester.pumpWidget(MaterialApp(
      home: RepertoireBuildScreen(
        name: 'French Defense: Advance — Black',
        color: 'b',
        rootFen: advance,
        rootPath: const ['e4', 'e6', 'd4', 'd5', 'e5'],
        id: 7,
        api: api,
        judge: _SilentJudge(),
        explore: (fen) async =>
            const OpeningExplorerLookup.unavailable('not-configured'),
        analyse: (fen, depth, multiPV) async => const [],
      ),
    ));
    await tester.pumpAndSettle();
  }

  Offset squareAt(WidgetTester tester, String name) {
    final finder = find.byType(ChessBoardWithOverlay);
    final widget = tester.widget<ChessBoardWithOverlay>(finder);
    final rect = tester.getRect(finder);
    final size = widget.boardSize / 8;
    final file = name.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = name.codeUnitAt(1) - '1'.codeUnitAt(0);
    final col = widget.boardOrientation == PlayerColor.black ? 7 - file : file;
    final row = widget.boardOrientation == PlayerColor.black ? rank : 7 - rank;
    return rect.topLeft + Offset((col + 0.5) * size, (row + 0.5) * size);
  }

  /// Stands the board after the student's own move, with White to move.
  Future<void> standAfterC5(WidgetTester tester) async {
    await tester.tap(find.textContaining('c5 ★').first);
    await tester.pumpAndSettle();
  }

  testWidgets('an opponent move played on the board is on the drawing',
      (tester) async {
    await pump(tester);
    await standAfterC5(tester);

    final cardForC3 = find.descendant(
      of: find.byType(VisualMoveTreeWidget),
      matching: find.textContaining('c3'),
    );
    expect(find.byType(VisualMoveTreeWidget), findsOneWidget);
    expect(cardForC3, findsNothing,
        reason: 'the drawing already holds the move, so this proves nothing');

    await tester.tapAt(squareAt(tester, 'c2'));
    await tester.pumpAndSettle();
    await tester.tapAt(squareAt(tester, 'c3'));
    await tester.pumpAndSettle();

    // Entered from the position after the student's move, and drawn.
    expect(api.entered, [(fen: afterC5, uci: 'c2c3')]);
    expect(cardForC3, findsWidgets,
        reason: 'the opponent move is not on the drawing after it was played');
  });

  testWidgets('a board move inside the drawing costs no second read',
      (tester) async {
    // Walking around inside a picture that already holds the line asks the
    // server nothing.
    await pump(tester);
    final reads = api.treeReads;

    await standAfterC5(tester);

    expect(api.treeReads, reads,
        reason: 'the drawing was read again though it holds the position');
  });
}
