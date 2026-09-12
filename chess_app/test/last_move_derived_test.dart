import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/theme/board_skins.dart';
import 'package:chess_app/widgets/board/skinned_chess_board.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// Phase 2 of `docs/PLAN-OZNAKE-NA-TABLI.md`: a board works out its own last
/// move, so a screen does not have to remember to say.
///
/// ## What this is guarding against
///
/// Ten of the fifteen screens that draw a board passed no last move at all —
/// the room a live lesson runs in, the tactics trainer the owner reported, the
/// endgame trainer, the review session, the child's lesson viewer. Every layer
/// underneath them was correct and had been for months. That is this
/// repository's most expensive recurring shape, and a parameter each screen has
/// to remember is how it happens.
///
/// So the assertion is not "screen X draws it". It is that **a board with a
/// move in its history draws that move without being told**, which is true of
/// all ten at once and of the eleventh nobody has written yet.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsService.instance.init();
  });

  const skin = BoardSkin(
    id: 'test-derive',
    name: 'Testna',
    lightSquare: Color(0xFFE8E8E8),
    darkSquare: Color(0xFF3C6E3C),
  );
  const boardEdge = 400.0;
  const squareEdge = boardEdge / 8;
  const key = ValueKey('board');

  Rect squareAt(String name) {
    final file = name.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = name.codeUnitAt(1) - '1'.codeUnitAt(0);
    return Rect.fromLTWH(
        file * squareEdge, (7 - rank) * squareEdge, squareEdge, squareEdge);
  }

  Future<(Uint8List, int)> shoot(WidgetTester tester) async {
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
    late Uint8List bytes;
    late int width;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      width = image.width;
      bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
    });
    return (bytes, width);
  }

  Color pixel(Uint8List bytes, int width, int x, int y) {
    final i = (y * width + x) * 4;
    return Color.fromARGB(bytes[i + 3], bytes[i], bytes[i + 1], bytes[i + 2]);
  }

  /// Whether every sampled pixel of [name] is still one of the skin's two plain
  /// square colours. A washed square is neither.
  bool isPlain(Uint8List bytes, int width, String name) {
    final area = squareAt(name);
    for (var y = area.top.toInt() + 2; y < area.bottom.toInt() - 2; y += 3) {
      for (var x = area.left.toInt() + 2; x < area.right.toInt() - 2; x += 3) {
        final c = pixel(bytes, width, x, y);
        if (c == skin.lightSquare || c == skin.darkSquare) return true;
      }
    }
    return false;
  }

  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child:
                  SizedBox(width: boardEdge, height: boardEdge, child: child),
            ),
          ),
        ),
      );

  testWidgets('a board told nothing draws the move that was played on it',
      (tester) async {
    final controller = ChessBoardController();
    await tester.pumpWidget(wrap(SkinnedChessBoard(
      controller: controller,
      boardSkin: skin,
    )));
    await tester.pumpAndSettle();

    final (before, width) = await shoot(tester);
    expect(isPlain(before, width, 'e2'), isTrue,
        reason: 'nothing has been played, so no square may be washed');
    expect(isPlain(before, width, 'e4'), isTrue);

    // No parameter, no setState from a screen: the move is made on the
    // controller, which is all any of the ten screens actually do.
    controller.makeMove(from: 'e2', to: 'e4');
    await tester.pumpAndSettle();

    final (after, _) = await shoot(tester);
    expect(isPlain(after, width, 'e2'), isFalse,
        reason: 'the square the move came from was not marked, and no screen '
            'passed anything — this is the whole of phase 2');
    expect(isPlain(after, width, 'e4'), isFalse,
        reason: 'the square the move went to was not marked');
    expect(isPlain(after, width, 'd4'), isTrue,
        reason: 'a square with nothing to do with the move was marked');
  });

  testWidgets('the opponent replying is drawn too — the report this came from',
      (tester) async {
    // „Treba highlajtovati poslednji potez za obe strane, nekad ne vidim da je
    // suprotna strana odgovorila" — 12.9.2026, filed under Tactics tailored to
    // you, which passed nothing at all.
    final controller = ChessBoardController();
    await tester.pumpWidget(wrap(SkinnedChessBoard(
      controller: controller,
      boardSkin: skin,
    )));
    controller.makeMove(from: 'e2', to: 'e4');
    await tester.pumpAndSettle();
    controller.makeMove(from: 'c7', to: 'c5');
    await tester.pumpAndSettle();

    final (bytes, width) = await shoot(tester);
    expect(isPlain(bytes, width, 'c7'), isFalse);
    expect(isPlain(bytes, width, 'c5'), isFalse);
    expect(isPlain(bytes, width, 'e2'), isTrue,
        reason: 'the move before last is still marked, so the wash is not '
            'following the game');
  });

  testWidgets('a caller that names the move wins, and is not second-guessed',
      (tester) async {
    final controller = ChessBoardController();
    await tester.pumpWidget(wrap(SkinnedChessBoard(
      controller: controller,
      boardSkin: skin,
      lastMoveFrom: 'a7',
      lastMoveTo: 'a5',
    )));
    controller.makeMove(from: 'e2', to: 'e4');
    await tester.pumpAndSettle();

    final (bytes, width) = await shoot(tester);
    expect(isPlain(bytes, width, 'a7'), isFalse,
        reason: 'the caller named a7 and it was ignored');
    expect(isPlain(bytes, width, 'a5'), isFalse);
    expect(isPlain(bytes, width, 'e4'), isTrue,
        reason: 'the board derived a move over the top of the one the caller '
            'named — five screens track this themselves and would be fought');
  });

  testWidgets('half an answer is still the caller\'s answer', (tester) async {
    // The pair is taken whole. A caller naming one square and not the other
    // means that; mixing its `from` with a derived `to` would be two nodes
    // answering for one move, which this repository has paid for once already.
    final controller = ChessBoardController();
    await tester.pumpWidget(wrap(SkinnedChessBoard(
      controller: controller,
      boardSkin: skin,
      lastMoveTo: 'h6',
    )));
    controller.makeMove(from: 'e2', to: 'e4');
    await tester.pumpAndSettle();

    final (bytes, width) = await shoot(tester);
    expect(isPlain(bytes, width, 'h6'), isFalse);
    expect(isPlain(bytes, width, 'e2'), isTrue,
        reason: 'the missing half was filled in from the game, so one mark '
            'came from the caller and the other from somewhere else');
    expect(isPlain(bytes, width, 'e4'), isTrue);
  });

  testWidgets('it reaches a board built through the overlay', (tester) async {
    // The path ten of the fifteen screens actually take. Nothing here passes a
    // last move, exactly as those screens do not.
    final controller = ChessBoardController();
    await tester.pumpWidget(wrap(ChessBoardWithOverlay(
      controller: controller,
      boardOrientation: PlayerColor.white,
      boardSize: boardEdge,
      isAllowedToMove: true,
      isDrawingMode: false,
      drawingStartSquare: null,
      arrows: const [],
      engineArrows: const [],
      onMove: (_, __, ___) {},
      onSquareTapForDrawing: (_) {},
    )));
    controller.makeMove(from: 'g1', to: 'f3');
    await tester.pumpAndSettle();

    final (bytes, width) = await shoot(tester);
    expect(isPlain(bytes, width, 'g1'), isFalse);
    expect(isPlain(bytes, width, 'f3'), isFalse);
  });

  testWidgets('a screen that syncs by loadFen still shows the move',
      (tester) async {
    // The pattern every one of the ten screens uses, and the reason phase 2
    // alone was not enough. `tactics_trainer_screen` plays the move on its own
    // `chess.Chess` and then calls `loadFen(game.fen)` to put the board in
    // step — which empties the history the derivation was reading. Measured:
    // after the drag the history holds e2e4, after the sync it holds nothing.
    final controller = ChessBoardController();
    await tester.pumpWidget(wrap(SkinnedChessBoard(
      controller: controller,
      boardSkin: skin,
    )));
    await tester.pumpAndSettle();

    final game = chess.Chess.fromFEN(controller.game.fen);
    game.move({'from': 'e2', 'to': 'e4'});
    controller.loadFen(game.fen);
    await tester.pumpAndSettle();

    expect(lastMoveSquaresOf(controller.game), isNull,
        reason: 'if the history survives a loadFen this test is no longer '
            'about the thing it was written for');

    final (bytes, width) = await shoot(tester);
    expect(isPlain(bytes, width, 'e2'), isFalse);
    expect(isPlain(bytes, width, 'e4'), isFalse);
    expect(isPlain(bytes, width, 'd4'), isTrue);
  });

  testWidgets("and the opponent's reply, loaded the same way", (tester) async {
    final controller = ChessBoardController();
    await tester.pumpWidget(wrap(SkinnedChessBoard(
      controller: controller,
      boardSkin: skin,
    )));
    await tester.pumpAndSettle();

    final game = chess.Chess.fromFEN(controller.game.fen);
    for (final move in [
      {'from': 'e2', 'to': 'e4'},
      {'from': 'c7', 'to': 'c5'},
    ]) {
      game.move(move);
      controller.loadFen(game.fen);
      await tester.pumpAndSettle();
    }

    final (bytes, width) = await shoot(tester);
    expect(isPlain(bytes, width, 'c7'), isFalse,
        reason: '„nekad ne vidim da je suprotna strana odgovorila" — the '
            'report this whole plan came from');
    expect(isPlain(bytes, width, 'c5'), isFalse);
    expect(isPlain(bytes, width, 'e2'), isTrue,
        reason: 'the move before last is still marked');
  });

  testWidgets('a new position that is not one move away marks nothing',
      (tester) async {
    // Loading the next puzzle. Two unrelated positions have no move between
    // them, and a wash on two squares nobody moved between would be a lie.
    final controller = ChessBoardController();
    await tester.pumpWidget(wrap(SkinnedChessBoard(
      controller: controller,
      boardSkin: skin,
    )));
    final game = chess.Chess.fromFEN(controller.game.fen);
    game.move({'from': 'e2', 'to': 'e4'});
    controller.loadFen(game.fen);
    await tester.pumpAndSettle();

    controller.loadFen('4k3/8/8/8/8/8/5Q2/4K3 w - - 0 1');
    await tester.pumpAndSettle();

    final (bytes, width) = await shoot(tester);
    for (final square in ['e2', 'e4', 'f2', 'e1', 'e8']) {
      expect(isPlain(bytes, width, square), isTrue,
          reason: '$square is washed after an unrelated position was loaded');
    }
  });

  testWidgets('a rebuild that changes nothing keeps the mark', (tester) async {
    // A skin change, a parent's setState, a tab coming back onstage. The move
    // has not been played again and the mark must not vanish.
    final controller = ChessBoardController();
    await tester.pumpWidget(wrap(SkinnedChessBoard(
      controller: controller,
      boardSkin: skin,
    )));
    final game = chess.Chess.fromFEN(controller.game.fen);
    game.move({'from': 'g1', 'to': 'f3'});
    controller.loadFen(game.fen);
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      await tester.pumpWidget(wrap(SkinnedChessBoard(
        controller: controller,
        boardSkin: skin,
      )));
      await tester.pumpAndSettle();
    }

    final (bytes, width) = await shoot(tester);
    expect(isPlain(bytes, width, 'g1'), isFalse,
        reason: 'the mark was lost on a rebuild that played no move');
    expect(isPlain(bytes, width, 'f3'), isFalse);
  });

  testWidgets('a board loaded from a position shows no move, which is honest',
      (tester) async {
    // Every puzzle screen starts here: a FEN, no history, nothing played yet.
    // A wash on a square nobody moved from would be a lie about the position.
    final controller = ChessBoardController()
      ..loadFen('4k3/8/8/8/8/8/8/4K2R w K - 0 1');
    await tester.pumpWidget(wrap(SkinnedChessBoard(
      controller: controller,
      boardSkin: skin,
    )));
    await tester.pumpAndSettle();

    final (bytes, width) = await shoot(tester);
    for (final square in ['e1', 'h1', 'e8', 'a1']) {
      expect(isPlain(bytes, width, square), isTrue,
          reason: '$square is washed on a board with an empty history');
    }
  });
}
