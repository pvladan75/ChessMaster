// The gate for phase 1 of `docs/PLAN-PRIPREMA.md` — Preparation as its own
// screen, in the shape the owner chose from the sketches (D11, variant C).
//
// Written by the lead before the screen, and watched going red on a screen
// that draws nothing (`lib/features/preparation/screens/preparation_screen.dart`
// as the lead left it).
//
// ---------------------------------------------------------------------------
// THE FROZEN CONTRACT
//
// **The screen**:
// `PreparationScreen({userSession, initialFen, initialTree, engine})`.
// It stands on `AnalysisNode`, opens no socket and sends no request.
//
// **It is built from what exists** — a second copy of any of these is a
// finding:
//
//   BoardWithCoordinates + ChessBoardWithOverlay   the board
//   BoardAnnotationController + BoardAnnotationBar the marks
//   MoveNavigationControls + AnalysisNodeCursor    the strip (dense)
//   AnalysisMoveTreeWidget                         the tree, both views
//   StockfishAnalysisWidget                        the engine's lines
//   VerticalEvalBarWidget / HorizontalEvalBarWidget
//   LandscapeBoardLayout                           a phone on its side
//   playedMove (core/services/legal_moves.dart)    a move on a position
//   PreparationLayout                              where everything goes
//
// **Keys**
//
//   Key('prep-comment')            the comment's TextField
//   Key('annotation-bar')          the marking bar (its own key, as ever)
//   Key('annotate-arrow')          arrow mode on/off
//   Key('annotate-square')         square mode on/off
//   Key('annotate-undo')           NEW — takes back the last mark
//   Key('annotate-clear')          clears this move's marks, both kinds
//   Key('annotate-color-<id>')     one per ArrowColor.all
//   Key('annotate-color-menu')     NEW — the one colour button of the tight
//                                  bar; it opens the five
//
// **Copy** — and nothing else new:
//
//   'Preparation'                  the bar's title
//   'Comment for <move>'           over the comment, e.g. „Comment for 1. e4"
//   'Comment (select a move)'      over it on the starting position
//   'Undo'                         the new button's label and tooltip
//   'No mark to undo.'             when there is none
//   'Tree', 'Comment', 'Engine'    a phone's tabs
//   'Moves added to variation: N.' an engine's line played into the tree
//   'Line does not match current position.'
//   'Line was already in the tree.'
//
// **What is deliberately not carried over from the room**: an evaluation is
// never written into a comment. The room stamps „[+0.30 / depth 24]" on an
// inserted line and offers „Insert evaluation into comment"; a comment here
// may become what a tutorial's voice reads out.
// ---------------------------------------------------------------------------

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' show PlayerColor;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/features/analysis_studio/widgets/visual_move_tree_widget.dart';
import 'package:chess_app/features/preparation/screens/preparation_screen.dart';
import 'package:chess_app/features/preparation/services/preparation_engine.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/ai_studio/board_eval_widgets.dart';
import 'package:chess_app/widgets/board/skinned_chess_board.dart';
import 'package:chess_app/widgets/board_flip_button.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/game_screen/arrow_color_button.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';
import 'package:chess_app/widgets/landscape_board_layout.dart';
import 'package:chess_app/widgets/stockfish_analysis_widget.dart';

import 'support/dart_source.dart';
import 'support/landscape.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// The owner's window (1920 × 1080 at 125%), a common laptop window, and the
/// narrowest window Windows gives the app.
///
/// `board` is a literal: what the rule gives at that window. `floor` is the
/// sketch the owner chose less 16 (D11), and `today` what the room draws.
const _desktop = [
  (size: Size(1536, 792), board: 608.0, floor: 584.0, today: 491.0),
  (size: Size(1200, 800), board: 616.0, floor: 592.0, today: 496.0),
  (size: Size(900, 700), board: 442.0, floor: 424.0, today: 269.0),
];

const _phone = Size(360, 640);

String _name(Size s) => '${s.width.toInt()} × ${s.height.toInt()}';

UserSession _session() => UserSession(
    token: 't', id: 7, email: 'a@b.c', name: 'Trainer', role: 'korisnik');

/// An engine that answers nothing and remembers what it was asked.
///
/// The real one is a process on the machine, and a widget test has none: a
/// switch that asks the engine nothing looks, in a test, exactly like one
/// that asks. The worker of phase 1 shipped that, and every case was green.
class _AskedEngine extends PreparationEngine {
  final List<String> asked = [];
  int stopped = 0;

  @override
  void triggerAnalysis(String fen) {
    if (isOn) {
      asked.add(fen);
    } else {
      stopped++;
    }
  }
}

Future<void> _open(
  WidgetTester tester,
  Size size, {
  String? fen,
  AnalysisNode? tree,
  PreparationEngine? engine,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  // Closed whatever the case did: a screen left standing by a case that failed
  // half way is read by the next one as its own.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: PreparationScreen(
      // A new State for every case: the same widget type pumped twice keeps
      // the first one's.
      key: UniqueKey(),
      userSession: _session(),
      initialFen: fen,
      initialTree: tree,
      engine: engine,
    ),
  ));
  await tester.pump(const Duration(milliseconds: 200));
}

Finder get _outerBoard => find.byType(BoardWithCoordinates);

// Each of these says what is missing before it reaches for it: a finder that
// throws „Bad state: No element" is a red nobody can read.

ChessBoardWithOverlay _board(WidgetTester tester) {
  final board = find.byType(ChessBoardWithOverlay);
  expect(board, findsOneWidget, reason: 'there is no board on the screen');
  return tester.widget<ChessBoardWithOverlay>(board);
}

Rect _boardRect(WidgetTester tester) {
  expect(_outerBoard, findsOneWidget,
      reason: 'there is no board on the screen');
  return tester.getRect(_outerBoard);
}

AnalysisMoveTreeWidget _tree(WidgetTester tester) {
  final tree = find.byType(AnalysisMoveTreeWidget, skipOffstage: false);
  expect(tree, findsOneWidget, reason: 'there is no move tree on the screen');
  return tester.widget<AnalysisMoveTreeWidget>(tree);
}

StockfishAnalysisWidget _engine(WidgetTester tester) {
  final panel = find.byType(StockfishAnalysisWidget, skipOffstage: false);
  expect(panel, findsOneWidget,
      reason: 'there is no engine panel on the screen');
  return tester.widget<StockfishAnalysisWidget>(panel);
}

TextField _comment(WidgetTester tester) {
  final field = find.byKey(const Key('prep-comment'));
  expect(field, findsOneWidget, reason: 'there is no comment field');
  return tester.widget<TextField>(field);
}

/// A move as the board reports one, and the frame that follows it.
Future<void> _play(WidgetTester tester, String from, String to,
    [String promotion = '']) async {
  _board(tester).onMove(from, to, promotion);
  await tester.pump(const Duration(milliseconds: 50));
}

/// A tap on a square while drawing, as the board reports one.
Future<void> _tapSquare(WidgetTester tester, String square) async {
  _board(tester).onSquareTapForDrawing(square);
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _press(WidgetTester tester, Key key) async {
  expect(find.byKey(key), findsOneWidget, reason: 'nothing is keyed $key');
  await tester.tap(find.byKey(key));
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _tooltip(WidgetTester tester, String message) async {
  expect(find.byTooltip(message), findsOneWidget,
      reason: 'no control says „$message"');
  await tester.tap(find.byTooltip(message));
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _switchEngineOn(WidgetTester tester) async {
  _engine(tester).onToggleEngine();
  await tester.pump(const Duration(milliseconds: 50));
  _engine(tester).onToggleShowEvalBar!();
  await tester.pump(const Duration(milliseconds: 50));
  expect(_engine(tester).isEngineEnabled, isTrue,
      reason: 'the fixture never switched the engine on');
  expect(_engine(tester).isShowEvalBarEnabled, isTrue,
      reason: 'the fixture never switched the evaluation bar on');
  // Past the engine's own debounce (180 ms): a switch asks the engine about
  // the position in front of it, and a case that ends before that question
  // is sent leaves its timer behind.
  await tester.pump(const Duration(milliseconds: 300));
}

/// Every control of the marking bar stands on one line.
void _expectOneRowOfMarks(WidgetTester tester, String where) {
  final bar = find.byKey(const Key('annotation-bar'));
  expect(bar, findsOneWidget, reason: 'no marking bar $where');
  final controls = [
    find.byKey(const Key('annotate-arrow')),
    find.byKey(const Key('annotate-square')),
    find.byKey(const Key('annotate-undo')),
    find.byKey(const Key('annotate-clear')),
  ];
  for (final control in controls) {
    expect(find.descendant(of: bar, matching: control), findsOneWidget,
        reason: '$control is not in the marking bar $where');
  }
  final colours = find.descendant(
      of: bar,
      matching: find.byWidgetPredicate((w) =>
          w is ArrowColorButton || w.key == const Key('annotate-color-menu')));
  expect(colours, findsWidgets, reason: 'no colour in the marking bar $where');
  final rows = <int>{
    for (final control in controls) tester.getCenter(control).dy.round(),
    for (final e in colours.evaluate())
      tester.getCenter(find.byWidget(e.widget)).dy.round(),
  };
  expect(rows, hasLength(1), reason: 'the marking bar wrapped $where');
  expect(tester.getSize(bar).height, lessThanOrEqualTo(56.5),
      reason: 'the marking bar is taller than its row $where');
}

void _expectOneRowOfStrip(WidgetTester tester, String where) {
  final strip = find.byType(MoveNavigationControls);
  expect(strip, findsOneWidget, reason: 'no move strip $where');
  final rows = find
      .descendant(of: strip, matching: find.byType(IconButton))
      .evaluate()
      .map((e) => tester.getCenter(find.byWidget(e.widget)).dy.round())
      .toSet();
  expect(rows, hasLength(1), reason: 'the move strip wrapped $where');
  expect(tester.getSize(strip).height, lessThanOrEqualTo(48.5),
      reason: 'the move strip is taller than its row $where');
}

class _CountingHttp extends HttpOverrides {
  int asked = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    asked++;
    throw StateError('Preparation asked for the network');
  }
}

void main() {
  // Rows are measured, and a widget test otherwise draws every letter as a
  // square a full em wide.
  setUpAll(loadRoboto);

  final windows = TargetPlatformVariant.only(TargetPlatform.windows);
  final android = TargetPlatformVariant.only(TargetPlatform.android);

  group('the board on a desktop window', () {
    for (final w in _desktop) {
      testWidgets('is a square of ${w.board.toInt()} at ${_name(w.size)}',
          (tester) async {
        await _open(tester, w.size);
        final where = 'at ${_name(w.size)}';

        expect(_outerBoard, findsOneWidget, reason: 'no board $where');
        final outer = _boardRect(tester);
        // Measured, not asked: a board drawn larger than its own box
        // overflows nothing and complains nowhere.
        expect(outer.width, closeTo(outer.height, 0.01));
        expect(outer.width, closeTo(w.board, 0.5));
        expect(outer.width, greaterThanOrEqualTo(w.floor),
            reason: 'more than 16 px under the sketch the owner chose');
        expect(outer.width, greaterThanOrEqualTo(w.today),
            reason: 'smaller than the room draws it today');
        final squares = tester.getRect(find.byType(SkinnedChessBoard).first);
        expect(squares.width, closeTo(squares.height, 0.01),
            reason: 'the squares themselves are not a square');
        expect((Offset.zero & w.size).contains(outer.topLeft), isTrue);
        expect(
            (Offset.zero & w.size)
                .contains(outer.bottomRight - const Offset(1, 1)),
            isTrue);

        _expectOneRowOfMarks(tester, where);
        _expectOneRowOfStrip(tester, where);
        final bar = tester.getRect(find.byKey(const Key('annotation-bar')));
        final strip = tester.getRect(find.byType(MoveNavigationControls));
        expect(bar.top, greaterThanOrEqualTo(outer.bottom),
            reason: 'the marking bar is not under the board');
        expect(strip.top, greaterThanOrEqualTo(bar.bottom),
            reason: 'the move strip is not under the marking bar');
        expect(bar.width, lessThanOrEqualTo(outer.width + 0.5));
        expect(strip.width, lessThanOrEqualTo(outer.width + 0.5));
        expectOnScreen(tester, w.size, find.byType(MoveNavigationControls));
      }, variant: windows);

      testWidgets(
          'the tree, the comment and the engine are all in sight at '
          '${_name(w.size)}', (tester) async {
        await _open(tester, w.size);
        expect(find.byType(TabBar), findsNothing,
            reason: 'nothing is behind a tab on a desktop window (D11)');
        expect(find.byType(Tab), findsNothing);

        final tree = find.byType(AnalysisMoveTreeWidget);
        final comment = find.byKey(const Key('prep-comment'));
        final engine = find.byType(StockfishAnalysisWidget);
        expectOnScreen(tester, w.size, tree);
        expectOnScreen(tester, w.size, comment);
        expectOnScreen(tester, w.size, engine);
        expect(find.byType(VisualMoveTreeWidget), findsOneWidget,
            reason: 'a desktop window opens on the graphical tree');

        final board = _boardRect(tester);
        final treeRect = tester.getRect(tree);
        final commentRect = tester.getRect(comment);
        final engineRect = tester.getRect(engine);
        expect(treeRect.left, greaterThan(board.right),
            reason: 'the tree is not beside the board');
        expect(commentRect.top, greaterThanOrEqualTo(treeRect.bottom),
            reason: 'the comment is not under the tree');
        expect(engineRect.top, greaterThanOrEqualTo(treeRect.bottom),
            reason: 'the engine\'s lines are not under the tree');
        if (w.size.width >= 1200) {
          expect(engineRect.left, greaterThanOrEqualTo(commentRect.right),
              reason: 'the engine\'s lines are not beside the comment');
        } else {
          expect(engineRect.top, greaterThanOrEqualTo(commentRect.bottom),
              reason: 'the engine\'s lines are not under the comment');
        }
      }, variant: windows);

      testWidgets(
          'is the same board with the engine on as with it off at '
          '${_name(w.size)}', (tester) async {
        await _open(tester, w.size);
        final before = _boardRect(tester);
        expect(find.byType(VerticalEvalBarWidget), findsNothing);

        await _switchEngineOn(tester);

        expect(find.byType(VerticalEvalBarWidget), findsOneWidget,
            reason: 'the evaluation bar stands beside the board (D11)');
        expect(find.byType(HorizontalEvalBarWidget), findsNothing);
        final bar = tester.getRect(find.byType(VerticalEvalBarWidget));
        final after = _boardRect(tester);
        expect(after, before,
            reason: 'switching the engine on moved or resized the board');
        expect(bar.right, lessThanOrEqualTo(after.left),
            reason: 'the evaluation bar is not beside the board');
        expect(bar.height, closeTo(after.height, 0.5));
        expect(tester.takeException(), isNull);
      }, variant: windows);
    }

    testWidgets('the title is whole at the narrowest window', (tester) async {
      await _open(tester, const Size(900, 700));
      final title = tester.renderObject<RenderParagraph>(find.descendant(
          of: find.byType(AppBar), matching: find.text('Preparation')));
      expect(title.didExceedMaxLines, isFalse);
    }, variant: windows);
  });

  group('a phone held upright', () {
    testWidgets('the board is 344, and it and its two rows need no scrolling',
        (tester) async {
      await _open(tester, _phone);
      final outer = _boardRect(tester);
      expect(outer.width, closeTo(outer.height, 0.01));
      expect(outer.width, closeTo(344, 0.5));
      expect(outer.width, greaterThanOrEqualTo(324),
          reason: 'smaller than the room draws it today');
      _expectOneRowOfMarks(tester, 'on a phone');
      _expectOneRowOfStrip(tester, 'on a phone');
      expectOnScreen(tester, _phone, _outerBoard);
      expectOnScreen(tester, _phone, find.byKey(const Key('annotation-bar')));
      expectOnScreen(tester, _phone, find.byType(MoveNavigationControls));
      final title = tester.renderObject<RenderParagraph>(find.descendant(
          of: find.byType(AppBar), matching: find.text('Preparation')));
      expect(title.didExceedMaxLines, isFalse);
    }, variant: android);

    testWidgets('the rest is behind three tabs, and the tree is notation',
        (tester) async {
      await _open(tester, _phone);
      for (final label in ['Tree', 'Comment', 'Engine']) {
        expect(find.widgetWithText(Tab, label), findsOneWidget,
            reason: 'no tab „$label"');
      }
      expectOnScreen(tester, _phone, find.byType(Tab));
      expect(find.byType(AnalysisMoveTreeWidget), findsOneWidget,
          reason: 'a phone opens on the tree');
      expect(find.byType(VisualMoveTreeWidget), findsNothing,
          reason: 'on a phone the tree opens as notation (D11)');

      await tester.tap(find.widgetWithText(Tab, 'Comment'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('prep-comment')), findsOneWidget);

      await tester.tap(find.widgetWithText(Tab, 'Engine'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(StockfishAnalysisWidget), findsOneWidget);
    }, variant: android);

    testWidgets('the engine changes where the board stands, never its size',
        (tester) async {
      await _open(tester, _phone);
      final before = _boardRect(tester).size;
      expect(find.widgetWithText(Tab, 'Engine'), findsOneWidget,
          reason: 'no tab „Engine"');
      await tester.tap(find.widgetWithText(Tab, 'Engine'));
      await tester.pump(const Duration(milliseconds: 400));
      await _switchEngineOn(tester);
      expect(find.byType(HorizontalEvalBarWidget), findsOneWidget,
          reason: 'on a phone the evaluation bar lies over the board');
      expect(find.byType(VerticalEvalBarWidget), findsNothing);
      expect(_boardRect(tester).size, before);
      expect(tester.takeException(), isNull);
    }, variant: android);

    testWidgets('the marking bar has one colour button, and it opens the five',
        (tester) async {
      await _open(tester, _phone);
      expect(find.byKey(const Key('annotate-color-menu')), findsOneWidget);
      expect(find.byType(ArrowColorButton), findsNothing,
          reason: 'five colours do not fit a phone\'s row');
      await _press(tester, const Key('annotate-color-menu'));
      await tester.pump(const Duration(milliseconds: 400));
      for (final id in ['R', 'O', 'G', 'B', 'P']) {
        expect(find.byKey(Key('annotate-color-$id')), findsOneWidget,
            reason: 'colour $id is not offered');
      }
      await _press(tester, const Key('annotate-color-R'));
      await tester.pump(const Duration(milliseconds: 400));
      await _press(tester, const Key('annotate-arrow'));
      await _tapSquare(tester, 'g1');
      await _tapSquare(tester, 'f3');
      expect(_board(tester).arrows.single.colorCode, 'R');
    }, variant: android);
  });

  group('a phone held on its side', () {
    for (final size in landscapePhones) {
      testWidgets('the board stands beside the rest at ${sizeLabel(size)}',
          (tester) async {
        await _open(tester, size);
        expectBoardBeside(tester, size);
        _expectOneRowOfMarks(tester, 'at ${sizeLabel(size)}');
        final board = _boardRect(tester);
        final bar = tester.getRect(find.byKey(const Key('annotation-bar')));
        expect(bar.left, greaterThan(board.right),
            reason: 'on its side the marks stand beside the board');
        expectOnScreen(tester, size, find.byKey(const Key('annotation-bar')));
      }, variant: android);

      testWidgets(
          'is the same board with the engine on as with it off at '
          '${sizeLabel(size)}', (tester) async {
        await _open(tester, size);
        final before = _boardRect(tester);
        expect(find.widgetWithText(Tab, 'Engine'), findsOneWidget,
            reason: 'no tab „Engine"');
        await tester.tap(find.widgetWithText(Tab, 'Engine'));
        await tester.pump(const Duration(milliseconds: 400));
        await _switchEngineOn(tester);
        expect(find.byType(VerticalEvalBarWidget), findsOneWidget);
        expect(_boardRect(tester), before);
        expect(tester.takeException(), isNull);
      }, variant: android);
    }
  });

  group('moves and the tree', () {
    const size = Size(1536, 792);

    testWidgets('the screen opens on the starting position, on its root',
        (tester) async {
      await _open(tester, size);
      expect(_tree(tester).rootNode.fen, _start);
      expect(_tree(tester).activeNode, same(_tree(tester).rootNode));
      expect(_board(tester).controller.getFen(), _start);
      expect(_board(tester).isAllowedToMove, isTrue);
    }, variant: windows);

    testWidgets('a position handed in is the root', (tester) async {
      const fen = '8/8/4k3/8/8/4K3/4P3/8 w - - 0 1';
      await _open(tester, size, fen: fen);
      expect(_tree(tester).rootNode.fen, fen);
      expect(_board(tester).controller.getFen(), fen);
    }, variant: windows);

    testWidgets('a tree handed in is opened as it is, and wins over a position',
        (tester) async {
      final root = AnalysisNode(fen: _start);
      final e4 = root.addChild(
          childFen:
              'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
          san: 'e4',
          uci: 'e2e4');
      e4.comment = 'Takes the centre.';
      await _open(tester, size,
          fen: '8/8/4k3/8/8/4K3/4P3/8 w - - 0 1', tree: root);
      expect(_tree(tester).rootNode, same(root));
      expect(_tree(tester).activeNode, same(root));
      expect(_board(tester).controller.getFen(), _start);
    }, variant: windows);

    testWidgets('a move on the board is a move in the tree', (tester) async {
      await _open(tester, size);
      await _play(tester, 'e2', 'e4');
      final tree = _tree(tester);
      expect(tree.rootNode.children, hasLength(1));
      expect(tree.activeNode.moveSan, 'e4');
      expect(tree.activeNode.moveUci, 'e2e4');
      expect(tree.activeNode.parent, same(tree.rootNode));
      expect(_board(tester).controller.getFen(), tree.activeNode.fen);
      expect(tree.activeNode.fen, contains('4P3'));
      expect(_board(tester).lastMoveFrom, 'e2');
      expect(_board(tester).lastMoveTo, 'e4');
    }, variant: windows);

    testWidgets('a move the position does not allow changes nothing',
        (tester) async {
      await _open(tester, size);
      await _play(tester, 'e2', 'e5');
      expect(_tree(tester).rootNode.children, isEmpty);
      expect(_tree(tester).activeNode, same(_tree(tester).rootNode));
      expect(_board(tester).controller.getFen(), _start);
      expect(tester.takeException(), isNull);
    }, variant: windows);

    testWidgets('a pawn promotes to what was chosen', (tester) async {
      await _open(tester, size, fen: '8/4P3/8/8/8/2k5/8/K7 w - - 0 1');
      await _play(tester, 'e7', 'e8', 'n');
      expect(_tree(tester).activeNode.moveSan, 'e8=N');
      expect(_tree(tester).activeNode.moveUci, 'e7e8n');
    }, variant: windows);

    testWidgets('a second move from one position is a variation',
        (tester) async {
      await _open(tester, size);
      await _play(tester, 'e2', 'e4');
      await _tooltip(tester, 'Previous move');
      expect(_tree(tester).activeNode, same(_tree(tester).rootNode));
      expect(_board(tester).controller.getFen(), _start);

      await _play(tester, 'd2', 'd4');
      final tree = _tree(tester);
      expect([for (final c in tree.rootNode.children) c.moveSan], ['e4', 'd4']);
      expect(tree.activeNode.moveSan, 'd4');
    }, variant: windows);

    testWidgets('a move the line already plays walks into it', (tester) async {
      await _open(tester, size);
      await _play(tester, 'e2', 'e4');
      final first = _tree(tester).activeNode;
      await _tooltip(tester, 'Previous move');
      await _play(tester, 'e2', 'e4');
      expect(_tree(tester).rootNode.children, hasLength(1));
      expect(_tree(tester).activeNode, same(first));
    }, variant: windows);

    testWidgets('the strip walks the line both ways', (tester) async {
      await _open(tester, size);
      await _play(tester, 'e2', 'e4');
      await _play(tester, 'e7', 'e5');
      await _tooltip(tester, 'Previous move');
      expect(_tree(tester).activeNode.moveSan, 'e4');
      await _tooltip(tester, 'Next move');
      expect(_tree(tester).activeNode.moveSan, 'e5');
      expect(_board(tester).controller.getFen(), _tree(tester).activeNode.fen);
    }, variant: windows);

    testWidgets('a move chosen in the tree is the move on the board',
        (tester) async {
      await _open(tester, size);
      await _play(tester, 'e2', 'e4');
      await _play(tester, 'e7', 'e5');
      final e4 = _tree(tester).rootNode.children.single;
      _tree(tester).onSelectNode(e4);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_tree(tester).activeNode, same(e4));
      expect(_board(tester).controller.getFen(), e4.fen);
    }, variant: windows);

    testWidgets('the tree\'s menu has what Analysis\'s has, and it works',
        (tester) async {
      await _open(tester, size);
      await _play(tester, 'e2', 'e4');
      await _tooltip(tester, 'Previous move');
      await _play(tester, 'd2', 'd4');
      await _tooltip(tester, 'Previous move');
      await _play(tester, 'c2', 'c4');

      var tree = _tree(tester);
      expect(tree.onPromoteNode, isNotNull);
      expect(tree.onDeleteNode, isNotNull);
      expect(tree.onMoveVariation, isNotNull);
      List<String?> order() =>
          [for (final c in _tree(tester).rootNode.children) c.moveSan];
      expect(order(), ['e4', 'd4', 'c4']);

      tree.onMoveVariation!(tree.rootNode.children[2], earlier: true);
      await tester.pump(const Duration(milliseconds: 50));
      expect(order(), ['e4', 'c4', 'd4']);

      tree = _tree(tester);
      tree.onPromoteNode!(tree.rootNode.children[2]);
      await tester.pump(const Duration(milliseconds: 50));
      expect(order(), ['d4', 'e4', 'c4']);

      // The cursor stands on c4; deleting c4 leaves it on c4's parent.
      tree = _tree(tester);
      expect(tree.activeNode.moveSan, 'c4');
      tree.onDeleteNode!(tree.activeNode);
      await tester.pump(const Duration(milliseconds: 50));
      expect(order(), ['d4', 'e4']);
      expect(_tree(tester).activeNode, same(_tree(tester).rootNode));
      expect(_board(tester).controller.getFen(), _start);
    }, variant: windows);

    testWidgets('the board turns', (tester) async {
      await _open(tester, size);
      expect(_board(tester).boardOrientation, PlayerColor.white);
      expect(find.byType(BoardFlipButton), findsOneWidget,
          reason: 'the strip has no flip button');
      await tester.tap(find.byType(BoardFlipButton));
      await tester.pump(const Duration(milliseconds: 50));
      expect(_board(tester).boardOrientation, PlayerColor.black);
      expect(tester.widget<BoardWithCoordinates>(_outerBoard).orientation,
          PlayerColor.black);
    }, variant: windows);
  });

  group('marks', () {
    const size = Size(1536, 792);

    testWidgets('the bar is icons and five colours at the owner\'s window',
        (tester) async {
      await _open(tester, size);
      expect(find.byType(ArrowColorButton), findsNWidgets(5));
      expect(find.byKey(const Key('annotate-color-menu')), findsNothing);
      // Icons: the words are in the tooltips, not beside them.
      final bar = find.byKey(const Key('annotation-bar'));
      for (final word in ['Arrow', 'Square', 'Undo', 'Clear marks']) {
        expect(
            find.descendant(of: bar, matching: find.text(word)), findsNothing,
            reason: '„$word" is written out in a bar that has no room for it');
        expect(find.byTooltip(word), findsOneWidget,
            reason: 'no control says „$word"');
      }
    }, variant: windows);

    testWidgets('a square marked is on the move, in the PGN, and comes back',
        (tester) async {
      await _open(tester, size);
      await _play(tester, 'e2', 'e4');
      expect(_board(tester).isDrawingMode, isFalse);

      await _press(tester, const Key('annotate-square'));
      expect(_board(tester).isDrawingMode, isTrue);
      await _tapSquare(tester, 'e5');

      final shown = _board(tester).squares;
      expect([for (final s in shown) '$s'], ['Ge5']);
      final node = _tree(tester).activeNode;
      expect([for (final s in node.squares) '$s'], ['Ge5'],
          reason: 'the mark is on the board and not on the move');

      final pgn = PgnExporterService.exportToPgn(_tree(tester).rootNode);
      expect(pgn, contains('[%csl Ge5]'));
      final back = readStepTree(fen: _start, pgn: pgn);
      expect(back.rejectedMoves, 0);
      expect(
          [for (final s in back.root.children.single.squares) '$s'], ['Ge5']);
    }, variant: windows);

    testWidgets('an arrow is two taps, in the colour that is picked',
        (tester) async {
      await _open(tester, size);
      await _press(tester, const Key('annotate-color-R'));
      await _press(tester, const Key('annotate-arrow'));
      await _tapSquare(tester, 'g1');
      expect(_board(tester).drawingStartSquare, 'g1');
      expect(_board(tester).arrows, isEmpty);
      await _tapSquare(tester, 'f3');
      expect([for (final a in _board(tester).arrows) '$a'], ['Rg1f3']);
      expect(
          [for (final a in _tree(tester).activeNode.arrows) '$a'], ['Rg1f3']);
      expect(_board(tester).drawingStartSquare, isNull);
    }, variant: windows);

    testWidgets('marks belong to their move', (tester) async {
      await _open(tester, size);
      await _play(tester, 'e2', 'e4');
      await _press(tester, const Key('annotate-square'));
      await _tapSquare(tester, 'd5');
      await _tooltip(tester, 'Previous move');
      expect(_board(tester).squares, isEmpty);
      await _tooltip(tester, 'Next move');
      expect([for (final s in _board(tester).squares) '$s'], ['Gd5']);
    }, variant: windows);

    testWidgets('undo takes back the last mark of the kind being drawn',
        (tester) async {
      await _open(tester, size);
      await _press(tester, const Key('annotate-arrow'));
      await _tapSquare(tester, 'g1');
      await _tapSquare(tester, 'f3');
      await _tapSquare(tester, 'b1');
      await _tapSquare(tester, 'c3');
      await _press(tester, const Key('annotate-square'));
      await _tapSquare(tester, 'e4');
      expect(_board(tester).arrows, hasLength(2));
      expect(_board(tester).squares, hasLength(1));

      // Squares are being drawn: the square goes, the arrows stay.
      await _press(tester, const Key('annotate-undo'));
      expect(_board(tester).squares, isEmpty);
      expect(_board(tester).arrows, hasLength(2));

      // No square is left: the last arrow goes.
      await _press(tester, const Key('annotate-undo'));
      expect([for (final a in _board(tester).arrows) '$a'], ['Gg1f3']);

      await _press(tester, const Key('annotate-undo'));
      expect(_board(tester).arrows, isEmpty);

      await _press(tester, const Key('annotate-undo'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('No mark to undo.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: windows);

    testWidgets('clear empties the move of both kinds', (tester) async {
      await _open(tester, size);
      await _press(tester, const Key('annotate-arrow'));
      await _tapSquare(tester, 'g1');
      await _tapSquare(tester, 'f3');
      await _press(tester, const Key('annotate-square'));
      await _tapSquare(tester, 'e4');
      await _press(tester, const Key('annotate-clear'));
      expect(_board(tester).arrows, isEmpty);
      expect(_board(tester).squares, isEmpty);
      expect(_tree(tester).activeNode.arrows, isEmpty);
      expect(_tree(tester).activeNode.squares, isEmpty);
    }, variant: windows);

    testWidgets('walking to another move forgets a half-drawn arrow',
        (tester) async {
      await _open(tester, size);
      await _play(tester, 'e2', 'e4');
      await _press(tester, const Key('annotate-arrow'));
      await _tapSquare(tester, 'g1');
      expect(_board(tester).drawingStartSquare, 'g1');
      await _tooltip(tester, 'Previous move');
      expect(_board(tester).drawingStartSquare, isNull);
      expect(_board(tester).isDrawingMode, isTrue,
          reason: 'the started square is forgotten, the mode is not');
    }, variant: windows);
  });

  group('the comment', () {
    const size = Size(1536, 792);

    testWidgets('is written on the move it was typed on', (tester) async {
      await _open(tester, size);
      expect(_comment(tester).enabled, isFalse,
          reason: 'the starting position is not a move');
      expect(find.text('Comment (select a move)'), findsOneWidget);

      await _play(tester, 'e2', 'e4');
      expect(_comment(tester).enabled, isTrue);
      expect(find.text('Comment for 1. e4'), findsOneWidget);
      await tester.enterText(
          find.byKey(const Key('prep-comment')), 'Takes the centre.');
      await tester.pump(const Duration(milliseconds: 50));
      expect(_tree(tester).activeNode.comment, 'Takes the centre.');

      await _play(tester, 'e7', 'e5');
      expect(find.text('Comment for 1... e5'), findsOneWidget);
      expect(_comment(tester).controller!.text, isEmpty,
          reason: 'the next move was shown the last move\'s sentence');
      await _tooltip(tester, 'Previous move');
      expect(_comment(tester).controller!.text, 'Takes the centre.');

      final pgn = PgnExporterService.exportToPgn(_tree(tester).rootNode);
      final back = readStepTree(fen: _start, pgn: pgn);
      expect(back.rejectedMoves, 0);
      expect(back.root.children.single.comment, 'Takes the centre.');
    }, variant: windows);
  });

  group('the engine', () {
    const size = Size(1536, 792);

    testWidgets('is off on arrival', (tester) async {
      await _open(tester, size);
      expect(_engine(tester).isEngineEnabled, isFalse);
      expect(_engine(tester).isShowEvalBarEnabled, isFalse);
      expect(_engine(tester).isAllowedToUseEngine, isTrue);
      expect(find.byType(VerticalEvalBarWidget), findsNothing);
      expect(find.byType(HorizontalEvalBarWidget), findsNothing);
      expect(_board(tester).engineArrows, isEmpty);
    }, variant: windows);

    testWidgets('a switch asks it about the position on the board',
        (tester) async {
      final engine = _AskedEngine();
      await _open(tester, size, engine: engine);
      await _play(tester, 'e2', 'e4');
      expect(engine.asked, isEmpty,
          reason: 'the engine was asked while it was switched off');
      final afterE4 = _tree(tester).activeNode.fen;

      _engine(tester).onToggleEngine();
      await tester.pump(const Duration(milliseconds: 50));
      expect(engine.asked, [afterE4],
          reason: 'switched on, it waits for the next move to be asked');

      await _play(tester, 'e7', 'e5');
      expect(engine.asked, [afterE4, _tree(tester).activeNode.fen]);
      await _tooltip(tester, 'Previous move');
      expect(engine.asked.last, afterE4,
          reason: 'a jump to another move did not ask about it');

      final stops = engine.stopped;
      _engine(tester).onToggleEngine();
      await tester.pump(const Duration(milliseconds: 50));
      expect(engine.stopped, greaterThan(stops),
          reason: 'switched off, it was not told to stop');
      expect(engine.asked, hasLength(3));
    }, variant: windows);

    testWidgets('the evaluation bar\'s switch asks it too', (tester) async {
      final engine = _AskedEngine();
      await _open(tester, size, engine: engine);
      _engine(tester).onToggleShowEvalBar!();
      await tester.pump(const Duration(milliseconds: 50));
      expect(engine.asked, [_start]);
    }, variant: windows);

    testWidgets('a screen over this one switches it off, and it stays off',
        (tester) async {
      await _open(tester, size);
      await _switchEngineOn(tester);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));

      showDialog<void>(
          context: navigator.context,
          builder: (_) => const AlertDialog(content: Text('over the board')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_engine(tester).isEngineEnabled, isTrue,
          reason: 'a dialog over the board is not leaving the screen');
      navigator.pop();
      await tester.pump(const Duration(milliseconds: 400));

      navigator.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('somewhere else'))));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_engine(tester).isEngineEnabled, isFalse,
          reason: 'the engine is still on under another screen');
      expect(_engine(tester).isShowEvalBarEnabled, isFalse);

      navigator.pop();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_engine(tester).isEngineEnabled, isFalse,
          reason: 'the engine came back on by itself');
    }, variant: windows);

    testWidgets('a line of it is played into the tree, with no number on it',
        (tester) async {
      await _open(tester, size);
      final panel = _engine(tester);
      expect(panel.onInsertLineAsVariation, isNotNull);
      panel.onInsertLineAsVariation!(AnalysisLine.fromPv(
        multipv: 1,
        depth: 24,
        eval: '+0.30',
        pvString: 'e2e4 e7e5 g1f3',
        startingFen: _start,
      ));
      await tester.pump(const Duration(milliseconds: 100));

      final root = _tree(tester).rootNode;
      final line = <String?>[];
      for (AnalysisNode? n = root.children.isEmpty ? null : root.children.first;
          n != null;
          n = n.children.isEmpty ? null : n.children.first) {
        line.add(n.moveSan);
        expect(n.comment, isEmpty,
            reason: 'an evaluation was written into a comment');
      }
      expect(line, ['e4', 'e5', 'Nf3']);
      expect(_tree(tester).activeNode, same(root),
          reason: 'inserting a line must not move the cursor');
      expect(find.text('Moves added to variation: 3.'), findsOneWidget);
    }, variant: windows);

    testWidgets('a line from another position adds nothing and says so',
        (tester) async {
      await _open(tester, size);
      await _play(tester, 'e2', 'e4');
      _engine(tester).onInsertLineAsVariation!(AnalysisLine.fromPv(
        multipv: 1,
        depth: 24,
        eval: '+0.30',
        pvString: 'e2e4 e7e5',
        startingFen: _start,
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_tree(tester).activeNode.children, isEmpty);
      expect(
          find.text('Line does not match current position.'), findsOneWidget);
    }, variant: windows);

    testWidgets('a line already there adds nothing and says so',
        (tester) async {
      await _open(tester, size);
      await _play(tester, 'e2', 'e4');
      await _tooltip(tester, 'Previous move');
      _engine(tester).onInsertLineAsVariation!(AnalysisLine.fromPv(
        multipv: 1,
        depth: 24,
        eval: '+0.30',
        pvString: 'e2e4',
        startingFen: _start,
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(_tree(tester).rootNode.children, hasLength(1));
      expect(find.text('Line was already in the tree.'), findsOneWidget);
    }, variant: windows);
  });

  group('no server', () {
    testWidgets('opens, plays, marks and comments without one request',
        (tester) async {
      final before = HttpOverrides.current;
      final counting = _CountingHttp();
      HttpOverrides.global = counting;
      addTearDown(() => HttpOverrides.global = before);

      await _open(tester, const Size(1536, 792));
      await _play(tester, 'e2', 'e4');
      await _press(tester, const Key('annotate-square'));
      await _tapSquare(tester, 'e5');
      await _press(tester, const Key('annotate-square'));
      await tester.enterText(
          find.byKey(const Key('prep-comment')), 'Takes the centre.');
      await tester.pump(const Duration(seconds: 2));

      expect(_tree(tester).activeNode.moveSan, 'e4',
          reason: 'the case never played its move');
      expect(counting.asked, 0,
          reason: 'Preparation needs no server to move a piece');
      expect(tester.takeException(), isNull);
    }, variant: windows);

    test('nothing under features/preparation names a socket', () {
      final dir = Directory('lib/features/preparation');
      expect(dir.existsSync(), isTrue);
      final files = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      expect(files.length, greaterThanOrEqualTo(2),
          reason: 'the walk found too little to have read the screen');
      expect(
          files.any((f) =>
              f.path.replaceAll('\\', '/').endsWith('preparation_screen.dart')),
          isTrue,
          reason: 'the screen itself is not in the walk');

      final socket = RegExp(r'\b(io|IO)\s*\.\s*io\s*\(');
      for (final file in files) {
        for (final part in partsOf(file.readAsStringSync())) {
          if (part.kind == SourcePart.comment) continue;
          if (part.kind == SourcePart.literal) {
            expect(part.text, isNot(contains('socket_io_client')),
                reason: '${file.path} imports the socket');
            expect(part.text, isNot(contains('chess_game_screen.dart')),
                reason: '${file.path} imports the room\'s screen');
          } else {
            expect(socket.hasMatch(part.text), isFalse,
                reason: '${file.path} opens a socket');
          }
        }
      }
    });
  });

  // Asked of the platform the case names, so a variant left behind by a case
  // that threw cannot colour the next file.
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  // The landscape layout is reached by height, and the case above proves it
  // through `expectBoardBeside`; this names the widget once so a rename of it
  // fails here rather than in six places.
  test('the landscape layout is the app\'s one', () {
    expect(LandscapeBoardLayout.compactToolbarHeight, 44);
  });
}
