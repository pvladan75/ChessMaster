import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:chess_app/widgets/ai_studio/board_eval_widgets.dart' show SelectedSquarePainter;
import 'package:chess_app/move_tree.dart' show ChessArrow;
import 'package:chess_app/services/app_settings_service.dart';

/// The live game board plus its arrow/blindfold/drawing overlays.
///
/// A tap while [isDrawingMode] is on can mean "start an arrow" or "finish
/// one" depending on [drawingStartSquare] — that two-step decision (and the
/// network broadcast it triggers) stays on the screen's State via
/// [onSquareTapForDrawing], since drawn arrows live on the shared move tree,
/// not in this widget.
///
/// When [useTapToMove] is on, the package's drag-and-drop is switched off
/// and a tap-to-select-then-tap-destination overlay drives moves instead.
/// The selected square is purely a rendering concern local to the board, so
/// it's kept as internal state rather than plumbed through the host screen.
class ChessBoardWithOverlay extends StatefulWidget {
  final ChessBoardController controller;
  final PlayerColor boardOrientation;
  final double boardSize;
  final bool isAllowedToMove;
  final bool isDrawingMode;
  final bool isBlindfoldMode;
  final bool useTapToMove;
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
    required this.isBlindfoldMode,
    required this.useTapToMove,
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
    if (!widget.useTapToMove && _selectedSquare != null) {
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
    final tapModeActive = widget.useTapToMove && widget.isAllowedToMove && !widget.isDrawingMode;

    return Stack(
      children: [
        IgnorePointer(
          ignoring: !widget.isAllowedToMove || widget.isDrawingMode || widget.useTapToMove,
          child: Opacity(
            opacity: widget.isBlindfoldMode ? 0.05 : 1.0,
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
                  final from = lastMove.move.fromAlgebraic;
                  final to = lastMove.move.toAlgebraic;
                  // On a promotion, move.piece is still the pre-move pawn;
                  // move.promotion (when set) is what the destination square
                  // actually shows now, so prefer it for the sprite.
                  final pieceType = lastMove.move.promotion ?? lastMove.move.piece;
                  _triggerMoveAnimation(from, to, Piece(pieceType, lastMove.move.color));
                  widget.onMove(from, to);
                }
              },
            ),
          ),
        ),
        if (widget.isBlindfoldMode)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withValues(alpha: 0.25),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.visibility_off, size: 56, color: Colors.amberAccent),
                      SizedBox(height: 6),
                      Text('🙈 Šah Na Slepo', style: TextStyle(color: Colors.amberAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('Figure su skrivene radi vežbanja vizuelizacije', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Tap-to-move interactive overlay (selects a piece, then a destination)
        IgnorePointer(
          ignoring: !tapModeActive,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
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
