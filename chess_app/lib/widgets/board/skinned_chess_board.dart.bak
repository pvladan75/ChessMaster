import 'dart:ui' as ui;

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/theme/board_skins.dart';
import 'package:chess_app/widgets/board/chess_piece_image.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:chess_app/widgets/promotion_picker.dart';

/// The board, drawn from a [BoardSkin] instead of from a photograph of a board.
///
/// **This is a fork of `ChessBoard` from `flutter_chess_board` 1.0.1**, kept as
/// close to the original as the changes allow so the two can still be diffed.
/// It exists because that widget paints its squares with `Image.asset` — four
/// baked PNGs picked by an enum, no colour parameters — and no amount of
/// tinting gets two independently chosen square colours out of one image. The
/// package is not going to grow them: it still declares `sdk: <3.0.0` and still
/// calls `onWillAccept`/`onAccept`.
///
/// **The package stays a dependency.** Only the rendering widget is replaced.
/// `ChessBoardController`, `PlayerColor` and `BoardArrow` come from it and are
/// named in 35 files; replacing those too would be a rename with no gain.
///
/// What changed from the original, all of it deliberate:
///
/// 1. Squares are painted from the skin (`_SquaresPainter`) rather than drawn
///    from `images/brown_board.png`. The classic skin holds that image's own
///    two colours, so a reader who changes nothing sees the same board — with
///    sharper seams, since the PNG is 375 px and 375/8 is not a whole number.
/// 2. Pieces take their colours from the reader's [PieceSkin].
/// 3. **Promotion asks in Serbian.** The original opens its own dialog reading
///    "Choose promotion" and drawing four white pieces whichever side is
///    moving. Every tap-to-move path in this app already used
///    [askPromotionPiece]; dragging was the one way left to reach the English
///    one, which `promotion_picker.dart` has documented as a known gap since it
///    was written.
/// 4. The dragged piece is sized to the square it came from. The original
///    hands its `feedback` an unconstrained widget, which renders at the
///    package's 45 px default — right by accident on a 360 dp phone, and too
///    small on every desktop board.
/// 5. Arrow support is dropped. The original paints `BoardArrow`s over the
///    board; nothing in this app passed any, because arrows are drawn by
///    `ChessBoardPainter` in `board_overlay_painter.dart` on a layer above.
/// 6. A third layer, [LastMovePainter], sits between the squares and the
///    pieces. The original has nothing there and neither did this fork until
///    12.9.2026; it is here because it is the only place in the app where those
///    two are separate layers, and a mark that must darken the square without
///    dimming the piece on it has nowhere else to go.
class SkinnedChessBoard extends StatelessWidget {
  const SkinnedChessBoard({
    super.key,
    required this.controller,
    this.size,
    this.enableUserMoves = true,
    this.boardOrientation = PlayerColor.white,
    this.onMove,
    this.boardSkin,
    this.pieceSkin,
    this.lastMoveFrom,
    this.lastMoveTo,
  });

  final ChessBoardController controller;

  /// The board's edge. Null means "take what the parent offers", which is what
  /// the dialogs do; the square stays square either way.
  final double? size;

  final bool enableUserMoves;
  final PlayerColor boardOrientation;
  final VoidCallback? onMove;

  /// Both default to the reader's choice. A caller passes one only to show a
  /// skin that is not selected — the preview in Settings.
  final BoardSkin? boardSkin;
  final PieceSkin? pieceSkin;

  /// The two squares of the move just played, drawn **under the pieces**.
  ///
  /// Here rather than in `ChessBoardPainter` because that painter draws over
  /// the pieces, and a mark that has to sit between the board and the piece
  /// cannot be made there at any alpha. This widget is the one place in the app
  /// where those two are separate layers — see [build] — so it is the only
  /// place the mark can go.
  ///
  /// Null means "no move to show", which is the honest state of a board loaded
  /// from a FEN: it has a position and no history. It is not the same as a move
  /// the caller chose to hide.
  ///
  /// Nothing passes these yet. Phase 1 of `docs/PLAN-OZNAKE-NA-TABLI.md` moves
  /// the last-move marker onto them and deletes the one drawn above.
  final String? lastMoveFrom;
  final String? lastMoveTo;

  static const _files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];

  @override
  Widget build(BuildContext context) {
    // Listens so a skin chosen in Settings reaches every board already built
    // underneath the settings page, which is the same reason
    // BoardWithCoordinates listens for the coordinate switch.
    return ListenableBuilder(
      listenable: AppSettingsService.instance,
      builder: (context, _) {
        final board = boardSkin ?? AppSettingsService.instance.boardSkin;
        final pieces = pieceSkin ?? AppSettingsService.instance.pieceSkin;

        return ValueListenableBuilder<Chess>(
          valueListenable: controller,
          builder: (context, game, _) {
            return SizedBox(
              width: size,
              height: size,
              child: AspectRatio(
                aspectRatio: 1.0,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boardSize = constraints.biggest.shortestSide;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _SquaresPainter(
                              lightSquare: board.lightSquare,
                              darkSquare: board.darkSquare,
                            ),
                          ),
                        ),
                        // Between the squares and the pieces, and that is the
                        // whole point of it. `IgnorePointer` is belt and
                        // braces — a `CustomPaint` whose painter does not
                        // override `hitTest` absorbs nothing — but the piece
                        // grid below is made of `DragTarget`s, and the next
                        // person to give this layer a gesture should have to
                        // delete a word rather than discover a bug.
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: LastMovePainter(
                                from: lastMoveFrom,
                                to: lastMoveTo,
                                orientation: boardOrientation,
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: _pieceGrid(game, pieces, boardSize / 8),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// The original's `GridView.builder`, square-index maths unchanged.
  Widget _pieceGrid(Chess game, PieceSkin pieces, double squareSize) {
    return GridView.builder(
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
      itemCount: 64,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final row = index ~/ 8;
        final column = index % 8;
        final boardRank = boardOrientation == PlayerColor.black
            ? '${row + 1}'
            : '${(7 - row) + 1}';
        final boardFile = boardOrientation == PlayerColor.white
            ? _files[column]
            : _files[7 - column];
        final squareName = '$boardFile$boardRank';
        final pieceOnSquare = game.get(squareName);

        // An empty square still has to fill its cell: the DragTarget under it
        // is what makes the square a legal destination, and a shrunken child
        // gives it nothing to hit-test.
        Widget draggable = const SizedBox.expand();
        if (pieceOnSquare != null) {
          final piece = chessPieceWidgetFor(pieceOnSquare,
              size: squareSize, skin: pieces);
          draggable = Draggable<PieceMoveData>(
            data: PieceMoveData(
              squareName: squareName,
              pieceType: pieceOnSquare.type.toUpperCase(),
              pieceColor: pieceOnSquare.color,
            ),
            feedback: SizedBox(
              width: squareSize,
              height: squareSize,
              child: piece,
            ),
            childWhenDragging: const SizedBox.shrink(),
            child: piece,
          );
        }

        return DragTarget<PieceMoveData>(
          builder: (context, candidate, rejected) => draggable,
          onWillAcceptWithDetails: (_) => enableUserMoves,
          onAcceptWithDetails: (details) =>
              _onPieceDropped(context, game, details.data, squareName),
        );
      },
    );
  }

  Future<void> _onPieceDropped(
    BuildContext context,
    Chess game,
    PieceMoveData moveData,
    String squareName,
  ) async {
    // Captured before the move, so "did anything happen" can be answered
    // afterwards without asking the board to explain itself.
    final chess.Color moveColor = game.turn;

    if (_isPromotion(moveData, squareName)) {
      final promotion = await askPromotionPiece(
        context,
        isWhite: moveData.pieceColor == chess.Color.WHITE,
      );
      // Null is a real answer: the reader backed out, so the move is not
      // played at all rather than played as a queen they did not choose.
      if (promotion == null) return;
      controller.makeMoveWithPromotion(
        from: moveData.squareName,
        to: squareName,
        pieceToPromoteTo: promotion,
      );
    } else {
      controller.makeMove(from: moveData.squareName, to: squareName);
    }

    if (game.turn != moveColor) onMove?.call();
  }

  static bool _isPromotion(PieceMoveData moveData, String squareName) {
    if (moveData.pieceType != 'P') return false;
    final from = moveData.squareName[1];
    final to = squareName[1];
    if (moveData.pieceColor == chess.Color.WHITE) {
      return from == '7' && to == '8';
    }
    return from == '2' && to == '1';
  }
}

/// The board's sixty-four squares, and nothing else.
///
/// Painted rather than built as sixty-four `Container`s: it is one layer under
/// a `GridView` that already builds sixty-four widgets, and it never changes
/// except when the skin does.
///
/// The light square is always the top-left one, in both orientations — a8 with
/// White at the bottom, h1 with Black, and both of those are light on a real
/// board. The original relied on the same fact by using one un-flipped image
/// for both.
/// The two squares of the last move, as a wash under the pieces.
///
/// **Black, and no hue at all**, which is the one decision in this class worth
/// defending. The marker it replaces was amber, and amber over a square
/// measured 1.03:1 at its worst against the square beneath it — a hue signal
/// and nothing else, which is the one channel a red-green deficiency takes
/// away, and the reason corner brackets had to be bolted onto it. A wash of
/// black at a fixed alpha is a luminance signal by construction: it darkens
/// whatever it covers by the same proportion, on every skin, for every kind of
/// eye. It also cannot collide with the five colours a trainer marks squares
/// in, now or when a sixth is added, because it has no hue to collide with.
///
/// Measured in `probe_layer.png` and `probe_layer_protanopia.png`
/// (`docs/PLAN-OZNAKE-NA-TABLI.md`): the two renderings are pixel-identical,
/// which is the property being bought.
///
/// **Drawn under the piece rather than over it**, so the square darkens and the
/// piece standing on it does not. That is what makes a wash possible here at
/// all — `ChessBoardPainter` had to give one up and draw a frame instead.
class LastMovePainter extends CustomPainter {
  const LastMovePainter({
    required this.from,
    required this.to,
    required this.orientation,
  });

  final String? from;
  final String? to;
  final PlayerColor orientation;

  /// How much darker a square of the last move is than the same square is
  /// otherwise. One number in one place: the difference between "visible" and
  /// "shouting" is a live judgement and not a measurement, so when it is
  /// changed it is changed here.
  static const ui.Color wash = ui.Color(0x38000000); // black, 22%

  @override
  void paint(Canvas canvas, Size size) {
    // No guard for "both null" above the loop: the loop already skips a null
    // square, so one would be a second way of saying the same thing and no test
    // could fail it. Two guards that prove the same thing prove neither.
    final boardSize = size.width;
    if (boardSize <= 0) return;
    final squareSize = boardSize / 8;
    final paint = Paint()..color = wash;

    for (final square in [from, to]) {
      if (square == null) continue;
      // `Offset.zero` is this function's way of saying "not a square", and it
      // can never be a real centre: every centre is at least half a square in
      // from both edges. A name out of a PGN nobody validated gets here.
      final centre = getSquareCenter(square, boardSize, orientation);
      if (centre == Offset.zero) continue;
      canvas.drawRect(
        Rect.fromCenter(center: centre, width: squareSize, height: squareSize),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(LastMovePainter oldDelegate) =>
      oldDelegate.from != from ||
      oldDelegate.to != to ||
      oldDelegate.orientation != orientation;
}

class _SquaresPainter extends CustomPainter {
  const _SquaresPainter({required this.lightSquare, required this.darkSquare});

  final ui.Color lightSquare;
  final ui.Color darkSquare;

  @override
  void paint(Canvas canvas, Size size) {
    final squareSize = size.width / 8;
    final light = Paint()..color = lightSquare;
    final dark = Paint()..color = darkSquare;

    for (var row = 0; row < 8; row++) {
      for (var column = 0; column < 8; column++) {
        canvas.drawRect(
          Rect.fromLTWH(
            column * squareSize,
            row * squareSize,
            // Overdrawn by a hair so neighbouring squares meet without a
            // hairline of background showing through at fractional sizes —
            // a board is rarely a whole number of pixels wide.
            squareSize + 0.5,
            squareSize + 0.5,
          ),
          (row + column) % 2 == 0 ? light : dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SquaresPainter oldDelegate) =>
      oldDelegate.lightSquare != lightSquare ||
      oldDelegate.darkSquare != darkSquare;
}
