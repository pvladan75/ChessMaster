import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:chess_app/models/analysis_models.dart';

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

  @override
  void initState() {
    super.initState();
    previewController = ChessBoardController();
    if (widget.line.fenList.isNotEmpty) {
      previewController.loadFen(widget.line.fenList[0]);
    }
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
                  boardOrientation: widget.orientation,
                  enableUserMoves: false,
                ),
              ),
              const SizedBox(height: 12),

              // Navigation stepper buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.first_page),
                    onPressed: currentIndex > 0 ? () => _goToIndex(0) : null,
                    tooltip: 'Početak linije',
                  ),
                  IconButton(
                    icon: const Icon(Icons.navigate_before),
                    onPressed: currentIndex > 0
                        ? () => _goToIndex(currentIndex - 1)
                        : null,
                    tooltip: 'Prethodni potez',
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Text(
                      '$currentIndex / $maxIndex',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.navigate_next),
                    onPressed: currentIndex < maxIndex
                        ? () => _goToIndex(currentIndex + 1)
                        : null,
                    tooltip: 'Sledeći potez',
                  ),
                  IconButton(
                    icon: const Icon(Icons.last_page),
                    onPressed: currentIndex < maxIndex
                        ? () => _goToIndex(maxIndex)
                        : null,
                    tooltip: 'Kraj linije',
                  ),
                ],
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
