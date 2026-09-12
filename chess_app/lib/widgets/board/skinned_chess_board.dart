import 'dart:ui' as ui;

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/core/services/move_between_positions.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/theme/board_skins.dart';
import 'package:chess_app/widgets/board/chess_piece_image.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:chess_app/widgets/promotion_picker.dart';

/// The move that was just played on [game], or null if none has been.
///
/// This used to ask whether any legal moves *remained* and treat "none" as
/// "nothing was played" — so a move that ended the game reported nothing at
/// all. Checkmate is exactly that case, and checkmate is the answer to every
/// mate-in-one exercise: the child's correct move was the one move the board
/// never told anybody about. In a live lesson the mating move went
/// unbroadcast for the same reason.
///
/// It lived on `ChessBoardWithOverlay` until 12.9.2026 and moved here because
/// [SkinnedChessBoard] needs it and is imported *by* that widget — the other
/// direction is a cycle. Writing the rule a second time was the alternative,
/// and this repository has paid for a second copy of a rule more than once.
({String from, String to, String promotion})? lastMoveSquaresOf(Chess game) {
  if (game.history.isEmpty) return null;
  final move = game.history.last.move;
  return (
    from: move.fromAlgebraic,
    to: move.toAlgebraic,
    // Read back rather than assumed: a piece dragged to the last rank is
    // promoted by the board package's own dialog, and whatever the reader
    // picked there has to reach the screen keeping the position.
    promotion: move.promotion?.name ?? '',
  );
}

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
class SkinnedChessBoard extends StatefulWidget {
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
  /// **Both null is the ordinary case, and it means "work it out".** Ten of the
  /// fifteen screens that draw a board passed nothing — the room a live lesson
  /// runs in, the tactics trainer the owner's report came from — and a
  /// parameter each of them has to remember is how it got to ten. See
  /// [_SkinnedChessBoardState._wash].
  ///
  /// A caller that tracks the move itself passes both and wins; the five that
  /// do are held to it by `test/last_move_reaches_board_test.dart`.
  ///
  /// There is deliberately **no way to turn the wash off**. Nothing wants that
  /// today, and a control drawn for nobody is this repository's most frequent
  /// mistake; a board no move leads to already shows nothing.
  final String? lastMoveFrom;
  final String? lastMoveTo;

  @override
  State<SkinnedChessBoard> createState() => _SkinnedChessBoardState();
}

class _SkinnedChessBoardState extends State<SkinnedChessBoard> {
  static const _files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];

  /// The position this board last drew, and the move that arrived at it.
  ///
  /// **Phase 2b, and the reason it exists is measured rather than reasoned
  /// about.** Phase 2 read the move out of `game.history`, which is right and
  /// which is a no-op on nine of the ten screens it was written for: they all
  /// drive the board with `loadFen`, and `loadFen` empties the history. The
  /// tactics trainer — the screen the owner's report came from — plays the move
  /// on its own `chess.Chess` and then calls `loadFen(game.fen)` to put the
  /// board in step. After the drag the history holds `e2e4`; after that one
  /// line it holds nothing at all.
  String? _shownFen;
  String? _shownPlacement;
  ({String from, String to})? _derived;

  /// Which two squares to wash, for the position now on the board.
  ///
  /// The caller wins whenever it said anything, and **the pair is taken
  /// whole**: a screen that named one square and not the other means that, and
  /// mixing its `from` with a derived `to` would be two nodes answering for one
  /// move — a fault this repository has already paid for once.
  ({String? from, String? to}) _wash(Chess game) {
    if (widget.lastMoveFrom != null || widget.lastMoveTo != null) {
      return (from: widget.lastMoveFrom, to: widget.lastMoveTo);
    }

    final fen = game.fen;
    final placement = placementOf(fen);

    // Nothing moved since the last build — a rebuild for a skin change, a
    // parent's setState, a tab coming back onstage. The mark has to survive
    // those, so the answer is the one already worked out and not a fresh null.
    if (placement != null && placement == _shownPlacement) {
      return (from: _derived?.from, to: _derived?.to);
    }

    // Played on directly, which is what the room and the two studios do. The
    // cheaper and more certain of the two readings, so it is asked first.
    final played = lastMoveSquaresOf(game);
    final derived = played != null
        ? (from: played.from, to: played.to)
        // Loaded as a position, which is what the other ten do. What single
        // legal move gets from the board we were showing to this one? An
        // unrelated position — a new puzzle, a jump to another node, a move
        // taken back — is not one move away, and the answer is no mark.
        : (_shownFen == null ? null : moveBetweenPositions(_shownFen!, fen));

    _shownFen = fen;
    _shownPlacement = placement;
    _derived = derived;
    return (from: derived?.from, to: derived?.to);
  }

  @override
  Widget build(BuildContext context) {
    // Listens so a skin chosen in Settings reaches every board already built
    // underneath the settings page, which is the same reason
    // BoardWithCoordinates listens for the coordinate switch.
    return ListenableBuilder(
      listenable: AppSettingsService.instance,
      builder: (context, _) {
        final board = widget.boardSkin ?? AppSettingsService.instance.boardSkin;
        final pieces =
            widget.pieceSkin ?? AppSettingsService.instance.pieceSkin;

        return ValueListenableBuilder<Chess>(
          valueListenable: widget.controller,
          builder: (context, game, _) {
            // Worked out here and not in `ChessBoardWithOverlay` for two
            // reasons: this builder already holds the `game` and already
            // re-runs when it changes, and this widget is what all six boards
            // in the app are built from — the analysis studio and the drill
            // screen reach it without going through the overlay at all.
            final wash = _wash(game);

            return SizedBox(
              width: widget.size,
              height: widget.size,
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
                                from: wash.from,
                                to: wash.to,
                                orientation: widget.boardOrientation,
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
        final boardRank = widget.boardOrientation == PlayerColor.black
            ? '${row + 1}'
            : '${(7 - row) + 1}';
        final boardFile = widget.boardOrientation == PlayerColor.white
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
          onWillAcceptWithDetails: (_) => widget.enableUserMoves,
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
      widget.controller.makeMoveWithPromotion(
        from: moveData.squareName,
        to: squareName,
        pieceToPromoteTo: promotion,
      );
    } else {
      widget.controller.makeMove(from: moveData.squareName, to: squareName);
    }

    if (game.turn != moveColor) widget.onMove?.call();
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
