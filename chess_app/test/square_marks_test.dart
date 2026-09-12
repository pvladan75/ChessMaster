import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/move_tree.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// `[%csl]` reaches the board.
///
/// Phase 6 of `docs/PLAN-INTERAKTIVNA-LEKCIJA.md` needs a lesson step to be
/// able to say „look at this square", and half of what these lessons are about
/// is a square rather than a move — a weak square, an outpost, the hole a pawn
/// left behind. `SquareMark` had been parsed, stored, exported and round-trip
/// tested since phase 2, and **drawn nowhere**: it appeared in `move_tree.dart`
/// and `analysis_node.dart` and in no painter at all. This is the missing half.
///
/// What is asserted here is what a test can actually see. A ring's *pixels* are
/// not checked — that is a golden's job and the goldens are skipped — so the
/// three things below are the ones that break silently: the marks reaching the
/// painter, a change in them causing a repaint, and a square name out of a
/// trainer's PGN not being able to take the board down.
void main() {
  Widget boardWith(List<SquareMark> squares, {bool drawing = false}) {
    return MaterialApp(
      home: Scaffold(
        body: ChessBoardWithOverlay(
          controller: ChessBoardController(),
          boardOrientation: PlayerColor.white,
          boardSize: 360,
          isAllowedToMove: false,
          isDrawingMode: drawing,
          drawingStartSquare: null,
          arrows: const [],
          squares: squares,
          engineArrows: const [],
          onMove: (_, __, ___) {},
          onSquareTapForDrawing: (_) {},
        ),
      ),
    );
  }

  List<ChessBoardPainter> paintersIn(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((c) => c.painter)
      .whereType<ChessBoardPainter>()
      .toList();

  group('the marks reach the painter', () {
    testWidgets('when the board is being read', (tester) async {
      final marks = [SquareMark(square: 'd5', colorCode: 'R')];
      await tester.pumpWidget(boardWith(marks));

      final painters = paintersIn(tester);
      expect(painters, isNotEmpty);
      for (final painter in painters) {
        expect(painter.squares, same(marks));
      }
    });

    testWidgets('and when the trainer is drawing on it', (tester) async {
      // Two painters exist and only one of them is mounted at a time. A mark
      // that reached the reading one and not the drawing one would vanish the
      // moment a trainer picked up the pen, which is exactly when they are
      // looking at it.
      final marks = [SquareMark(square: 'd5', colorCode: 'R')];
      await tester.pumpWidget(boardWith(marks, drawing: true));

      final painters = paintersIn(tester);
      expect(painters, isNotEmpty);
      for (final painter in painters) {
        expect(painter.squares, same(marks));
      }
    });

    testWidgets('a board that says nothing draws no marks', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ChessBoardWithOverlay(
            controller: ChessBoardController(),
            boardOrientation: PlayerColor.white,
            boardSize: 360,
            isAllowedToMove: false,
            isDrawingMode: false,
            drawingStartSquare: null,
            arrows: const [],
            engineArrows: const [],
            onMove: (_, __, ___) {},
            onSquareTapForDrawing: (_) {},
          ),
        ),
      ));

      for (final painter in paintersIn(tester)) {
        expect(painter.squares, isEmpty);
      }
    });
  });

  group('the mark is a frame on the square\'s edge', () {
    // Asked of the canvas, because the shape is the thing the owner asked to
    // change — „ne želim krugove oko figura ili u poljima" — and a test that
    // only checks the colours would have passed the ring it replaced.
    const boardSize = 400.0;
    const squareSize = boardSize / 8;
    const overlayKey = ValueKey('marks-overlay');

    // `Material` builds CustomPaints of its own for ink and for its shape
    // border, so the painter is found by key rather than by type — the same
    // reason `last_move_marker_test.dart` did before it was deleted.
    Widget wrap(List<SquareMark> marks) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: CustomPaint(
                key: overlayKey,
                size: const Size(boardSize, boardSize),
                painter: ChessBoardPainter(
                  arrows: const [],
                  squares: marks,
                  boardSize: boardSize,
                  orientation: PlayerColor.white,
                  drawingModeColor: const ui.Color(0xFF2196F3),
                  badgeBorderColor: const ui.Color(0xFF000000),
                ),
              ),
            ),
          ),
        );

    testWidgets('it is drawn with rectangles and no circle at all',
        (tester) async {
      await tester.pumpWidget(wrap([SquareMark(square: 'd5', colorCode: 'R')]));

      expect(find.byKey(overlayKey), paintsExactlyCountTimes(#drawCircle, 0),
          reason: 'a circle is still being drawn on a marked square');
      expect(find.byKey(overlayKey), paintsExactlyCountTimes(#drawRect, 3),
          reason: 'three passes — black, white and the author\'s colour — and '
              'no more: the halo is what makes the colour legible and the '
              'colour is what says whose mark it is');
    });

    testWidgets('each pass hugs the square and none of them leaves it',
        (tester) async {
      await tester.pumpWidget(wrap([SquareMark(square: 'a1', colorCode: 'G')]));

      // a1 is the bottom-left square of a board the usual way up, and a corner
      // is the case that shows a stroke drawn a hair too wide: two of its
      // edges are the board's own.
      const square = Rect.fromLTWH(0, 350, squareSize, squareSize);
      const shade = squareSize * ChessBoardPainter.squareMarkShadeFraction;
      const light = squareSize * ChessBoardPainter.squareMarkLightFraction;
      const core = squareSize * ChessBoardPainter.squareMarkCoreFraction;

      expect(
        find.byKey(overlayKey),
        paints
          // Widest first, each inset by half its own width so its outer edge
          // lands exactly on the square's edge.
          ..rect(
              rect: square.deflate(shade / 2),
              strokeWidth: shade,
              style: PaintingStyle.stroke)
          ..rect(
              rect: square.deflate(light / 2),
              strokeWidth: light,
              style: PaintingStyle.stroke)
          ..rect(
              rect: square.deflate(core / 2),
              strokeWidth: core,
              // A stroke and never a fill: this painter draws over the
              // pieces, so anything in the middle buries the piece on the
              // very square the reader is being sent to look at.
              style: PaintingStyle.stroke),
      );
    });
  });

  group('a change in the marks repaints', () {
    ChessBoardPainter painterWith(List<SquareMark> squares) =>
        ChessBoardPainter(
          arrows: const [],
          squares: squares,
          boardSize: 360,
          orientation: PlayerColor.white,
          drawingModeColor: const ui.Color(0xFF2196F3),
          badgeBorderColor: const ui.Color(0xFF000000),
        );

    test('different marks', () {
      final a = painterWith([SquareMark(square: 'd5', colorCode: 'R')]);
      final b = painterWith([SquareMark(square: 'e4', colorCode: 'R')]);
      expect(b.shouldRepaint(a), isTrue);
    });

    test('the same list does not', () {
      final marks = [SquareMark(square: 'd5', colorCode: 'R')];
      expect(painterWith(marks).shouldRepaint(painterWith(marks)), isFalse);
    });
  });

  group('a square name out of a PGN cannot take the board down', () {
    test('every real square has a centre, and none of them is the sentinel',
        () {
      // The skip in the painter reads `Offset.zero` as "not a square", so this
      // is the assertion that makes the skip safe rather than clever: no legal
      // square may land on the sentinel, under either orientation.
      for (final file in 'abcdefgh'.split('')) {
        for (var rank = 1; rank <= 8; rank++) {
          for (final orientation in PlayerColor.values) {
            expect(getSquareCenter('$file$rank', 360, orientation),
                isNot(Offset.zero),
                reason: '$file$rank for $orientation');
          }
        }
      }
    });

    test('a name that is not a square answers the sentinel', () {
      for (final bad in ['', 'a', 'i1', 'a9', 'a0', 'xx', 'A1', '11', 'd']) {
        expect(getSquareCenter(bad, 360, PlayerColor.white), Offset.zero,
            reason: bad);
      }
    });

    test('painting a malformed mark skips it instead of throwing', () {
      // `int.parse` on the second character is what this used to do, inside a
      // `CustomPainter`, which is a red screen rather than a missing ring. The
      // squares here come out of a comment nothing validates — a book's typo
      // must cost the reader one mark and not the board.
      final painter = ChessBoardPainter(
        arrows: const [],
        squares: [
          SquareMark(square: 'xx', colorCode: 'R'),
          SquareMark(square: 'd5', colorCode: 'G'),
        ],
        boardSize: 360,
        orientation: PlayerColor.white,
        drawingModeColor: const ui.Color(0xFF2196F3),
        badgeBorderColor: const ui.Color(0xFF000000),
      );

      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(360, 360));
      expect(recorder.endRecording(), isNotNull);
    });
  });
}
