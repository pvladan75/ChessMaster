import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/core/models/move_cursor.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';

class EngineLineDialog extends StatefulWidget {
  final AnalysisLine line;
  final PlayerColor orientation;
  final Function(String fen)? onLoadFenToMainBoard;

  const EngineLineDialog({
    super.key,
    required this.line,
    required this.orientation,
    this.onLoadFenToMainBoard,
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
    final maxIndex = widget.line.fenList.length - 1;

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: Colors.tealAccent),
              const SizedBox(width: 8),
              Text(
                'Linija #${widget.line.multipv} (${widget.line.evaluation})',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.line.evaluation,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.tealAccent),
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
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: SelectableText(
                  widget.line.continuationSan.isNotEmpty
                      ? widget.line.continuationSan
                      : 'Nema dostupnih poteza.',
                  style: const TextStyle(
                      fontSize: 13, height: 1.4, color: Colors.white),
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
              const SizedBox(height: 12),

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
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }
}
