import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/core/models/move_cursor.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';

class EngineLineDialog extends StatefulWidget {
  final AnalysisLine line;
  final PlayerColor orientation;
  final Function(String fen)? onLoadFenToMainBoard;

  /// Plays the whole line into the calling screen's move tree. Null where
  /// there is no tree to play it into.
  final Function(AnalysisLine line)? onInsertLineAsVariation;

  const EngineLineDialog({
    super.key,
    required this.line,
    required this.orientation,
    this.onLoadFenToMainBoard,
    this.onInsertLineAsVariation,
  });

  @override
  State<EngineLineDialog> createState() => _EngineLineDialogState();
}

class _EngineLineDialogState extends State<EngineLineDialog> {
  int currentIndex = 0;
  late ChessBoardController previewController;
  late PlayerColor _orientation;

  @override
  void initState() {
    super.initState();
    _orientation = widget.orientation;
    previewController = ChessBoardController();
    if (widget.line.fenList.isNotEmpty) {
      previewController.loadFen(widget.line.fenList[0]);
    }
  }

  void _toggleOrientation() {
    setState(() {
      _orientation = _orientation == PlayerColor.white
          ? PlayerColor.black
          : PlayerColor.white;
    });
  }

  void _goToIndex(int index) {
    if (index < 0 || index >= widget.line.fenList.length) return;
    setState(() {
      currentIndex = index;
      previewController.loadFen(widget.line.fenList[index]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final maxIndex = widget.line.fenList.length - 1;

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.psychology, color: colors.accent),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Linija #${widget.line.multipv} (${widget.line.evaluation})',
                style: AppText.title,
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.line.evaluation,
              style: AppText.bodyBold.copyWith(color: colors.accent),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Full SAN text representation
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.canvas,
                  borderRadius: AppRadii.roundedSm,
                  border: Border.all(
                      color: colors.textMuted.withValues(alpha: 0.2)),
                ),
                child: SelectableText(
                  widget.line.continuationSan.isNotEmpty
                      ? widget.line.continuationSan
                      : 'Nema dostupnih poteza.',
                  style: AppText.bodyLarge
                      .copyWith(height: 1.4, color: colors.textPrimary),
                ),
              ),
              const SizedBox(height: 14),

              // Mini interactive board preview
              SizedBox(
                width: 280,
                height: 280,
                child: ChessBoard(
                  controller: previewController,
                  boardColor: BoardColor.green,
                  boardOrientation: _orientation,
                  enableUserMoves: false,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Navigation stepper buttons
              MoveNavigationControls(
                cursor: LinearMoveCursor(
                  fens: widget.line.fenList,
                  index: currentIndex,
                  onSeek: _goToIndex,
                ),
                centerLabel: '$currentIndex / $maxIndex',
                onFlipBoard: _toggleOrientation,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Zatvori'),
        ),
        if (widget.onInsertLineAsVariation != null &&
            widget.line.sanMoveList.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () {
              widget.onInsertLineAsVariation!(widget.line);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.call_split, size: 16),
            label: const Text('Ubaci kao varijaciju'),
          ),
        if (widget.onLoadFenToMainBoard != null &&
            widget.line.fenList.isNotEmpty)
          ElevatedButton.icon(
            onPressed: () {
              widget.onLoadFenToMainBoard!(widget.line.fenList[currentIndex]);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.input, size: 16),
            label: const Text('Učitaj ovaj poziciju na glavnu tablu'),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.canvas,
            ),
          ),
      ],
    );
  }
}
