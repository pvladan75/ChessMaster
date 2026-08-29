import 'package:chess_app/theme/app_typography.dart';
import 'package:flutter/material.dart';

import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';
import 'package:chess_app/theme/app_spacing.dart';

/// Asks which piece the pawn becomes.
///
/// One dialog for every board in the app that moves by tapping, because there
/// is one answer to give and it should not look like four different questions.
/// Until 27.8.2026 nobody was asked at all: a tap-move promoted to a queen and
/// said nothing, so an exercise whose answer is a knight could not be played by
/// tapping — and the reader had no way of knowing the choice existed.
///
/// In the reader's own language and in the moving side's own colour. The board
/// package's dialog, which still runs when a piece is *dragged* to the last
/// rank, says "Choose promotion" and always draws white pieces; most of the
/// people using this app are Serbian children, and half of them are playing
/// black.
///
/// Returns `null` when the reader backed out, which is a real answer: the move
/// is then not played at all, rather than played as something they did not
/// choose.
Future<String?> askPromotionPiece(
  BuildContext context, {
  required bool isWhite,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (context) => AlertDialog(
      title: const Text('U šta se pretvara pešak?'),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final piece in kPromotionPieces)
            _PromotionChoice(piece: piece, isWhite: isWhite),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
      ],
    ),
  );
}

/// The Serbian name of each piece, under its picture.
///
/// Written out rather than left to the drawing: the pieces are small, a child
/// is choosing, and "lovac" and "top" are exactly the two that get mixed up.
const Map<String, String> _pieceNames = {
  'q': 'Dama',
  'r': 'Top',
  'b': 'Lovac',
  'n': 'Skakač',
};

class _PromotionChoice extends StatelessWidget {
  const _PromotionChoice({required this.piece, required this.isWhite});

  final String piece;
  final bool isWhite;

  @override
  Widget build(BuildContext context) {
    final letter = isWhite ? piece.toUpperCase() : piece;
    return Semantics(
      button: true,
      label: _pieceNames[piece],
      child: InkWell(
        onTap: () => Navigator.of(context).pop(piece),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              chessPieceWidget(letter, size: 44) ?? const SizedBox(height: 44),
              const SizedBox(height: AppSpacing.xs),
              Text(_pieceNames[piece] ?? piece, style: AppText.caption),
            ],
          ),
        ),
      ),
    );
  }
}
