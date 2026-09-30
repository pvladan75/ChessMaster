// Analysis opened on a tree, standing on one of its nodes — how a position of
// the opening report opens with the moves that led to it (the owner,
// 30.9.2026). The real screen, not a stand-in: what is under test is where it
// stands and which way the board faces when it arrives.

import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' show PlayerColor;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/services/eval_cache.dart';
import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/features/archive/models/leak_report.dart';
import 'package:chess_app/features/archive/services/opening_position_tree.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board/skinned_chess_board.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// After 1.e4 c5 2.Nf3 — Black to move, as chess.js keys it.
const _afterNf3 = 'rnbqkbnr/pp1ppppp/8/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq -';

UserSession _session() =>
    UserSession(token: 't', id: 1, email: 'a@b.c', name: 'N', role: 'korisnik');

OpeningPositionTree _tree() => openingPositionTree(
      line: const OpeningLine(
          startFen: _start, uciMoves: ['e2e4', 'c7c5', 'g1f3']),
      fenKey: _afterNf3,
      branches: const [
        ['d6', 'd4', 'cxd4', 'Nxd4'],
        ['Nc6'],
      ],
    )!;

Future<void> _pump(WidgetTester tester, Widget screen) async {
  SharedPreferences.setMockInitialValues({});
  EvalCache.instance.clear();
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  // Closed in the tear-down, so a failure here cannot leave the screen
  // standing for the next case.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: screen,
  ));
  await tester.pumpAndSettle();
}

String _board(String fen) => fen.split(' ').take(3).join(' ');

void main() {
  testWidgets(
      'it stands on the node it was given, facing the side to move there',
      (tester) async {
    final tree = _tree();
    await _pump(
      tester,
      AnalysisStudioScreen(
        userSession: _session(),
        initialTree: tree.root,
        initialNodeId: tree.position.id,
      ),
    );

    final moves = tester.widget<AnalysisMoveTreeWidget>(
        find.byType(AnalysisMoveTreeWidget, skipOffstage: false));
    expect(moves.rootNode, same(tree.root));
    expect(moves.activeNode, same(tree.position));
    final board = tester.widget<SkinnedChessBoard>(
        find.byType(SkinnedChessBoard, skipOffstage: false));
    expect(board.boardOrientation, PlayerColor.black);
    expect(_board(board.controller.getFen()), _board(_afterNf3));
  });

  testWidgets(
      'without a node it stands on the root and faces its side to move, as a '
      'saved analysis always opened', (tester) async {
    final tree = _tree();
    await _pump(
      tester,
      AnalysisStudioScreen(userSession: _session(), initialTree: tree.root),
    );

    final moves = tester.widget<AnalysisMoveTreeWidget>(
        find.byType(AnalysisMoveTreeWidget, skipOffstage: false));
    expect(moves.activeNode, same(tree.root));
    final board = tester.widget<SkinnedChessBoard>(
        find.byType(SkinnedChessBoard, skipOffstage: false));
    expect(board.boardOrientation, PlayerColor.white);
    expect(_board(board.controller.getFen()), _board(_start));
  });
}
