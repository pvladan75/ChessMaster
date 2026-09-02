import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:chess_app/theme/app_colors.dart';

import 'package:chess_app/core/services/board_on_screen.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:chess_app/widgets/ai_studio/board_eval_widgets.dart'
    show SelectedSquarePainter;
import 'package:chess_app/move_tree.dart' show ChessArrow;
import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/widgets/promotion_picker.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/board/skinned_chess_board.dart';

/// The live game board plus its arrow/drawing overlays.
///
/// A tap while [isDrawingMode] is on can mean "start an arrow" or "finish
/// one" depending on [drawingStartSquare] — that two-step decision (and the
/// network broadcast it triggers) stays on the screen's State via
/// [onSquareTapForDrawing], since drawn arrows live on the shared move tree,
/// not in this widget.
///
/// Moves can be made either way, always: drag a piece, or tap it and then tap
/// its destination. The tap overlay is translucent to hit testing so it never
/// swallows the gesture — a stationary click is claimed by its tap recogniser,
/// a drag falls through to the board underneath and wins the arena as usual.
/// This used to be an either/or setting, and picking tap switched dragging off
/// outright, which to anyone reaching for it out of habit was indistinguishable
/// from a board that had stopped working.
///
/// The selected square is purely a rendering concern local to the board, so
/// it's kept as internal state rather than plumbed through the host screen.
class ChessBoardWithOverlay extends StatefulWidget {
  final ChessBoardController controller;
  final PlayerColor boardOrientation;
  final double boardSize;
  final bool isAllowedToMove;
  final bool isDrawingMode;
  final String? drawingStartSquare;
  final List<ChessArrow> arrows;
  final List<EngineArrow> engineArrows;
  final String? lastMoveFrom;
  final String? lastMoveTo;

  /// The move that was just played, with what a promoting pawn became.
  ///
  /// `promotion` is `''` for an ordinary move, and one of `q r b n` otherwise.
  /// It used to not exist, so every screen played its own `'promotion': 'q'`
  /// into its own game object — which meant an underpromotion chosen on the
  /// board became a queen in the position the screen was actually keeping.
  final void Function(String from, String to, String promotion) onMove;
  final ValueChanged<String> onSquareTapForDrawing;

  const ChessBoardWithOverlay({
    super.key,
    required this.controller,
    required this.boardOrientation,
    required this.boardSize,
    required this.isAllowedToMove,
    required this.isDrawingMode,
    required this.drawingStartSquare,
    required this.arrows,
    required this.engineArrows,
    required this.onMove,
    required this.onSquareTapForDrawing,
    this.lastMoveFrom,
    this.lastMoveTo,
  });

  @override
  State<ChessBoardWithOverlay> createState() => _ChessBoardWithOverlayState();

  /// The move that was just played, or null if none has been.
  ///
  /// This used to ask whether any legal moves *remained* and treat "none" as
  /// "nothing was played" — so a move that ended the game reported nothing at
  /// all. Checkmate is exactly that case, and checkmate is the answer to every
  /// mate-in-one exercise: the child's correct move was the one move the board
  /// never told anybody about. In a live lesson the mating move went
  /// unbroadcast for the same reason.
  static ({String from, String to, String promotion})? lastMoveSquares(
      chess.Chess game) {
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
}

class _ChessBoardWithOverlayState extends State<ChessBoardWithOverlay> {
  String? _selectedSquare;
  // A list rather than a single nullable slot: two moves made back-to-back
  // faster than the animation duration (fast tapping, quick replies) must
  // each get their own sprite. A single slot would have the second move's
  // trigger overwrite the first's, tearing down its AnimatedMovePiece mid-
  // flight (dispose() fires before the slide reaches the destination) so the
  // piece just snaps into place instead of visibly sliding there.
  final List<PendingMoveAnimation> _pendingAnimations = [];

  /// Kept rather than rebuilt: the same closure has to be handed back on the
  /// way out, or the board is never forgotten and the keyboard keeps copying
  /// from a screen that is gone.
  late final VoidCallback _copyPositionForKeyboard;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_clearSelection);
    // Ctrl+C is bound above every screen and asks whoever is on top; the right
    // click asks this same method directly. One behaviour, two ways in.
    _copyPositionForKeyboard = () => _copyFen(context);
    BoardOnScreen.register(_copyPositionForKeyboard);
  }

  @override
  void didUpdateWidget(covariant ChessBoardWithOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_clearSelection);
      widget.controller.addListener(_clearSelection);
    }
    // Drawing borrows the taps, so a half-finished selection must not survive
    // into it and fire a move on the next tap.
    if (widget.isDrawingMode && _selectedSquare != null) {
      _selectedSquare = null;
    }
  }

  @override
  void dispose() {
    BoardOnScreen.forget(_copyPositionForKeyboard);
    widget.controller.removeListener(_clearSelection);
    super.dispose();
  }

  /// Any board change (our own move, an opponent's move arriving over the
  /// network, undo, reset...) invalidates a pending selection.
  void _clearSelection() {
    if (_selectedSquare != null) {
      setState(() => _selectedSquare = null);
    }
  }

  Future<void> _handleSquareTapForMove(String square) async {
    final game = widget.controller.game;
    final piece = game.get(square);
    final isOwnPiece = piece != null && piece.color == game.turn;

    if (isOwnPiece) {
      setState(
          () => _selectedSquare = (square == _selectedSquare) ? null : square);
      return;
    }

    final from = _selectedSquare;
    if (from == null || from == square) return;

    final pieceBeforeMove = game.get(from);
    setState(() => _selectedSquare = null);
    final moveColor = game.turn;

    // A tap-move used to promote to a queen without asking, which is why an
    // exercise whose answer is a knight could not be played by tapping at all.
    // Dragging has always asked — through the board package's own dialog — so
    // the same move gave two different answers depending on how the piece was
    // moved.
    var promotion = '';
    if (isPromotionMove(game, from, square)) {
      final chosen = await askPromotionPiece(
        context,
        isWhite: moveColor == chess.Color.WHITE,
      );
      // Backing out means the move is not played, rather than played as
      // something nobody chose.
      if (chosen == null || !mounted) return;
      promotion = chosen;
    }

    widget.controller.makeMoveWithPromotion(
        from: from,
        to: square,
        pieceToPromoteTo: promotion.isEmpty ? 'q' : promotion);
    if (game.turn != moveColor) {
      // Read the piece back from its destination (post-move) rather than
      // using pieceBeforeMove directly: on a promotion, the piece sitting on
      // `square` is already the queen the real board now shows, while
      // pieceBeforeMove is still the pawn — animating the pawn sprite would
      // visibly mismatch the queen that's already rendered underneath.
      final animatedPiece = game.get(square) ?? pieceBeforeMove;
      if (animatedPiece != null) {
        _triggerMoveAnimation(from, square, animatedPiece);
      }
      widget.onMove(from, square, promotion);
    }
  }

  void _triggerMoveAnimation(String from, String to, Piece movingPiece) {
    final durationMs = AppSettingsService.instance.moveAnimationDurationMs;
    if (durationMs <= 0) return;
    setState(() {
      _pendingAnimations
          .add(PendingMoveAnimation(from: from, to: to, piece: movingPiece));
    });
  }

  /// Puts the position on the clipboard and says so.
  ///
  /// The FEN rather than a picture: it is what gets pasted into an engine, a
  /// chat with another trainer, or this app's own analysis board.
  Future<void> _copyFen(BuildContext context) async {
    final fen = widget.controller.getFen();
    await Clipboard.setData(ClipboardData(text: fen));
    if (!context.mounted) return;
    AppFeedback.show(
      context,
      () => const SnackBar(
        content: Text('FEN je kopiran.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tapModeActive = widget.isAllowedToMove && !widget.isDrawingMode;

    // Right-click copies the position. Every board program has this, and here
    // it is one gesture around the one board widget, so it works on every
    // screen that draws a board rather than on whichever one it was added to.
    // Harmless where there is no mouse: a touch screen has no secondary tap.
    return GestureDetector(
      onSecondaryTap: () => _copyFen(context),
      child: Stack(
        children: [
          IgnorePointer(
            ignoring: !widget.isAllowedToMove || widget.isDrawingMode,
            child: SkinnedChessBoard(
              controller: widget.controller,
              boardOrientation: widget.boardOrientation,
              size: widget.boardSize,
              onMove: () {
                // Deliberately not animated: the user just dragged the piece to
                // this square themselves, so sliding it along the same path again
                // reads as the move happening twice.
                final played = ChessBoardWithOverlay.lastMoveSquares(
                    widget.controller.game);
                if (played != null) {
                  widget.onMove(played.from, played.to, played.promotion);
                }
              },
            ),
          ),
          // Tap-to-move interactive overlay (selects a piece, then a destination).
          // Translucent, not opaque: it must take part in hit testing without
          // reporting a hit, so the board underneath still receives the pointer
          // and dragging keeps working while this is active.
          IgnorePointer(
            ignoring: !tapModeActive,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (details) {
                final square = getSquareFromOffset(details.localPosition,
                    widget.boardSize, widget.boardOrientation);
                _handleSquareTapForMove(square);
              },
              child: CustomPaint(
                size: Size(widget.boardSize, widget.boardSize),
                painter: _selectedSquare != null
                    ? SelectedSquarePainter(
                        selectedSquare: _selectedSquare!,
                        boardSize: widget.boardSize,
                        orientation: widget.boardOrientation,
                      )
                    : null,
              ),
            ),
          ),
          // Interactive paint overlay for trainer drawing arrows
          IgnorePointer(
            ignoring: !widget.isDrawingMode,
            child: GestureDetector(
              onTapDown: (details) {
                if (!widget.isDrawingMode) return;
                final localPos = details.localPosition;
                final square = getSquareFromOffset(
                    localPos, widget.boardSize, widget.boardOrientation);
                widget.onSquareTapForDrawing(square);
              },
              child: CustomPaint(
                size: Size(widget.boardSize, widget.boardSize),
                painter: ChessBoardPainter(
                  lastMoveColor: context.colors.warning,
                  drawingModeColor: context.colors.accent,
                  badgeBorderColor: context.colors.canvas,
                  arrows: widget.arrows,
                  engineArrows: widget.engineArrows,
                  boardSize: widget.boardSize,
                  orientation: widget.boardOrientation,
                  highlightedSquare: widget.drawingStartSquare,
                  lastMoveFrom: widget.lastMoveFrom,
                  lastMoveTo: widget.lastMoveTo,
                ),
              ),
            ),
          ),
          // Non-interactive overlay to draw arrows for both when not in drawing mode
          if (!widget.isDrawingMode)
            IgnorePointer(
              child: CustomPaint(
                size: Size(widget.boardSize, widget.boardSize),
                painter: ChessBoardPainter(
                  lastMoveColor: context.colors.warning,
                  drawingModeColor: context.colors.accent,
                  badgeBorderColor: context.colors.canvas,
                  arrows: widget.arrows,
                  engineArrows: widget.engineArrows,
                  boardSize: widget.boardSize,
                  orientation: widget.boardOrientation,
                  lastMoveFrom: widget.lastMoveFrom,
                  lastMoveTo: widget.lastMoveTo,
                ),
              ),
            ),
          for (final pendingAnim in _pendingAnimations)
            AnimatedMovePiece(
              key: ValueKey(pendingAnim),
              pending: pendingAnim,
              boardSize: widget.boardSize,
              orientation: widget.boardOrientation,
              duration: Duration(
                  milliseconds:
                      AppSettingsService.instance.moveAnimationDurationMs),
              onCompleted: () {
                if (mounted) {
                  setState(() => _pendingAnimations.remove(pendingAnim));
                }
              },
            ),
        ],
      ),
    );
  }
}
