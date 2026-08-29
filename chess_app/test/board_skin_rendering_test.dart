import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
// The package's barrel re-exports `package:chess`, whose `Color` enum would
// otherwise shadow Flutter's. `board_overlay_painter.dart` solves the same
// collision with a `ui.` prefix; here there is nothing to prefix but the one
// name, so it is hidden.
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/theme/board_skins.dart';
import 'package:chess_app/widgets/board/chess_piece_image.dart';
import 'package:chess_app/widgets/board/skinned_chess_board.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

/// A skin whose colours appear nowhere else, so a test that finds them has
/// found *this* skin rather than a default that happens to match.
const _loud = BoardSkin(
  id: 'test-loud',
  name: 'Testna',
  lightSquare: Color(0xFF112233),
  darkSquare: Color(0xFF445566),
);

const _loudPieces = PieceSkin(
  id: 'test-loud-pieces',
  name: 'Testne',
  whiteFill: Color(0xFF010203),
  whiteStroke: Color(0xFF040506),
  blackFill: Color(0xFF070809),
  blackStroke: Color(0xFF0A0B0C),
  blackDecoration: Color(0xFF0D0E0F),
);

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 400, height: 400, child: child)),
      ),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsService.instance.init();
  });

  group('SkinnedChessBoard paints the skin', () {
    testWidgets('the squares it draws are the skin it was given',
        (tester) async {
      await tester.pumpWidget(_wrap(SkinnedChessBoard(
        controller: ChessBoardController(),
        boardSkin: _loud,
      )));

      // The painter draws row-major from the top-left, and the top-left square
      // is the light one in both orientations.
      expect(
        find.byType(SkinnedChessBoard),
        paints
          ..rect(color: _loud.lightSquare)
          ..rect(color: _loud.darkSquare),
      );
    });

    testWidgets('with no skin given it draws the reader\'s choice',
        (tester) async {
      await tester.pumpWidget(
          _wrap(SkinnedChessBoard(controller: ChessBoardController())));

      expect(
        find.byType(SkinnedChessBoard),
        paints..rect(color: BoardSkin.classic.lightSquare),
      );
    });

    testWidgets('a flipped board keeps the light square top-left',
        (tester) async {
      await tester.pumpWidget(_wrap(SkinnedChessBoard(
        controller: ChessBoardController(),
        boardSkin: _loud,
        boardOrientation: PlayerColor.black,
      )));

      expect(
        find.byType(SkinnedChessBoard),
        paints
          ..rect(color: _loud.lightSquare)
          ..rect(color: _loud.darkSquare),
      );
    });
  });

  group('the pieces take their colours from the skin', () {
    test('a white piece carries the skin\'s fill and stroke', () {
      final pawn = chessPieceWidget('P', skin: _loudPieces) as WhitePawn;
      expect(pawn.fillColor, _loudPieces.whiteFill);
      expect(pawn.strokeColor, _loudPieces.whiteStroke);
    });

    test('a black piece also carries the decoration colour', () {
      final knight = chessPieceWidget('n', skin: _loudPieces) as BlackKnight;
      expect(knight.fillColor, _loudPieces.blackFill);
      expect(knight.strokeColor, _loudPieces.blackStroke);
      // The knight's eye and mane. Without this the piece is a silhouette.
      expect(knight.decorationColor, _loudPieces.blackDecoration);
    });

    test('with no skin given the pieces take the reader\'s choice', () {
      final pawn = chessPieceWidget('P') as WhitePawn;
      expect(pawn.fillColor, PieceSkin.classic.whiteFill);
    });

    test('a piece from the chess package draws as the same piece', () {
      final piece = chess.Piece(chess.PieceType.QUEEN, chess.Color.BLACK);
      final queen = chessPieceWidgetFor(piece, skin: _loudPieces) as BlackQueen;
      expect(queen.fillColor, _loudPieces.blackFill);
      expect(queen.decorationColor, _loudPieces.blackDecoration);
    });
  });

  group('the move animation covers the square it lands on', () {
    // a1 is dark, and everything else follows from it. Orientation is not part
    // of the question: flipping the board moves squares around the screen, it
    // does not repaint them.
    test('light and dark squares are told apart', () {
      expect(AnimatedMovePiece.isLightSquare('a1'), isFalse);
      expect(AnimatedMovePiece.isLightSquare('h1'), isTrue);
      expect(AnimatedMovePiece.isLightSquare('a8'), isTrue);
      expect(AnimatedMovePiece.isLightSquare('h8'), isFalse);
      expect(AnimatedMovePiece.isLightSquare('e4'), isTrue);
      expect(AnimatedMovePiece.isLightSquare('d4'), isFalse);
    });

    testWidgets('the cover is the destination square\'s own colour',
        (tester) async {
      // e4 is light; e5 is dark. Same board, same skin, two different covers —
      // which is the whole reason the crop of a board image had to go.
      for (final (square, expected) in [
        ('e4', _loud.lightSquare),
        ('e5', _loud.darkSquare),
      ]) {
        await tester.pumpWidget(_wrap(AnimatedMovePiece(
          pending: PendingMoveAnimation(
            from: 'e2',
            to: square,
            piece: chess.Piece(chess.PieceType.PAWN, chess.Color.WHITE),
          ),
          boardSize: 400,
          orientation: PlayerColor.white,
          duration: const Duration(milliseconds: 200),
          onCompleted: () {},
          boardSkin: _loud,
        )));

        final cover = tester.widget<ColoredBox>(
          find.descendant(
            of: find.byType(AnimatedMovePiece),
            matching: find.byType(ColoredBox),
          ),
        );
        expect(cover.color, expected, reason: 'cover over $square');
        await tester.pumpAndSettle();
      }
    });
  });

  group('the thumbnails draw the same board as the live one', () {
    testWidgets('a thumbnail paints the skin', (tester) async {
      await tester.pumpWidget(_wrap(const BoardThumbnail(
        fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        size: 80,
        skin: _loud,
      )));

      // Sixty-four Containers, and the first of them is the top-left square.
      final first = tester.widgetList<Container>(find.byType(Container)).first;
      expect(first.color, _loud.lightSquare);
    });
  });

  group("promotion asks in the reader's language", () {
    testWidgets('dragging a pawn to the last rank opens the Serbian dialog',
        (tester) async {
      // The fork's one behaviour change. The package's own board opens an
      // English dialog drawing four white pieces whichever side is moving, and
      // dragging was the last way to reach it — every tap-to-move path in the
      // app already asked in Serbian.
      final controller =
          ChessBoardController.fromFEN('4k3/P7/8/8/8/8/8/4K3 w - - 0 1');
      await tester.pumpWidget(_wrap(SkinnedChessBoard(
        controller: controller,
        size: 400,
      )));

      // a7 and a8, in a board whose top-left corner is a8.
      final topLeft = tester.getTopLeft(find.byType(SkinnedChessBoard));
      const square = 400 / 8;
      final from = topLeft + const Offset(square * 0.5, square * 1.5);
      final to = topLeft + const Offset(square * 0.5, square * 0.5);

      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(to);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('U šta se pretvara pešak?'), findsOneWidget);
      expect(find.text('Choose promotion'), findsNothing);
      // The four Serbian names, in the moving side's colour.
      expect(find.text('Skakač'), findsOneWidget);

      await tester.tap(find.text('Skakač'));
      await tester.pumpAndSettle();

      expect(controller.game.get('a8')?.type.name, 'n');
    });

    testWidgets('backing out of the dialog plays no move at all',
        (tester) async {
      final controller =
          ChessBoardController.fromFEN('4k3/P7/8/8/8/8/8/4K3 w - - 0 1');
      await tester.pumpWidget(_wrap(SkinnedChessBoard(
        controller: controller,
        size: 400,
      )));

      final topLeft = tester.getTopLeft(find.byType(SkinnedChessBoard));
      const square = 400 / 8;
      final gesture = await tester
          .startGesture(topLeft + const Offset(square * 0.5, square * 1.5));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.moveTo(topLeft + const Offset(square * 0.5, square * 0.5));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Odustani'));
      await tester.pumpAndSettle();

      // Not promoted to a queen nobody chose: the pawn is still on a7.
      expect(controller.game.get('a8'), isNull);
      expect(controller.game.get('a7')?.type.name, 'p');
    });
  });
}
