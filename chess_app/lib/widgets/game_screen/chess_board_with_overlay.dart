import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:chess_app/widgets/ai_studio/board_eval_widgets.dart' show SelectedSquarePainter;
import 'package:chess_app/move_tree.dart' show ChessArrow;
import 'package:chess_app/services/app_settings_service.dart';

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
  final void Function(String from, String to) onMove;
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
  });

  @override
  State<ChessBoardWithOverlay> createState() => _ChessBoardWithOverlayState();
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

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_clearSelection);
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

  void _handleSquareTapForMove(String square) {
    final game = widget.controller.game;
    final piece = game.get(square);
    final isOwnPiece = piece != null && piece.color == game.turn;

    if (isOwnPiece) {
      setState(() => _selectedSquare = (square == _selectedSquare) ? null : square);
      return;
    }

    final from = _selectedSquare;
    if (from == null || from == square) return;

    final pieceBeforeMove = game.get(from);
    setState(() => _selectedSquare = null);
    final moveColor = game.turn;
    // Promotion is always queried as 'q'; the chess package ignores it for
    // non-promoting moves, so this is safe to pass unconditionally (see
    // ai_studio_screen's puzzle autoplay, which does the same).
    widget.controller.makeMoveWithPromotion(from: from, to: square, pieceToPromoteTo: 'q');
    if (game.turn != moveColor) {
      // Read the piece back from its destination (post-move) rather than
      // using pieceBeforeMove directly: on a promotion, the piece sitting on
      // `square` is already the queen the real board now shows, while
      // pieceBeforeMove is still the pawn — animating the pawn sprite would
      // visibly mismatch the queen that's already rendered underneath.
      final animatedPiece = game.get(square) ?? pieceBeforeMove;
      if (animatedPiece != null) _triggerMoveAnimation(from, square, animatedPiece);
      widget.onMove(from, square);
    }
  }

  void _triggerMoveAnimation(String from, String to, Piece movingPiece) {
    final durationMs = AppSettingsService.instance.moveAnimationDurationMs;
    if (durationMs <= 0) return;
    setState(() {
      _pendingAnimations.add(PendingMoveAnimation(from: from, to: to, piece: movingPiece));
    });
  }

  @override
  Widget build(BuildContext context) {
    final tapModeActive = widget.isAllowedToMove && !widget.isDrawingMode;

    return Stack(
      children: [
        IgnorePointer(
          ignoring: !widget.isAllowedToMove || widget.isDrawingMode,
          child: ChessBoard(
            controller: widget.controller,
            boardColor: BoardColor.brown,
            boardOrientation: widget.boardOrientation,
            size: widget.boardSize,
            onMove: () {
              final lastMove = widget.controller.getPossibleMoves().isEmpty
                  ? null
                  : widget.controller.game.history.last;
              if (lastMove != null) {
                // Deliberately not animated: the user just dragged the piece
                // to this square themselves, so sliding it along the same path
                // again reads as the move happening twice.
                widget.onMove(lastMove.move.fromAlgebraic, lastMove.move.toAlgebraic);
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
              final square = getSquareFromOffset(details.localPosition, widget.boardSize, widget.boardOrientation);
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
              final square = getSquareFromOffset(localPos, widget.boardSize, widget.boardOrientation);
              widget.onSquareTapForDrawing(square);
            },
            child: CustomPaint(
              size: Size(widget.boardSize, widget.boardSize),
              painter: ChessBoardPainter(
                arrows: widget.arrows,
                engineArrows: widget.engineArrows,
                boardSize: widget.boardSize,
                orientation: widget.boardOrientation,
                highlightedSquare: widget.drawingStartSquare,
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
                arrows: widget.arrows,
                engineArrows: widget.engineArrows,
                boardSize: widget.boardSize,
                orientation: widget.boardOrientation,
              ),
            ),
          ),
        for (final pendingAnim in _pendingAnimations)
          AnimatedMovePiece(
            key: ValueKey(pendingAnim),
            pending: pendingAnim,
            boardSize: widget.boardSize,
            orientation: widget.boardOrientation,
            duration: Duration(milliseconds: AppSettingsService.instance.moveAnimationDurationMs),
            onCompleted: () {
              if (mounted) setState(() => _pendingAnimations.remove(pendingAnim));
            },
          ),
      ],
    );
  }
}
