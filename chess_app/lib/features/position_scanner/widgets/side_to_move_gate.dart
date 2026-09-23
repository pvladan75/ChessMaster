import 'package:flutter/material.dart';

import 'package:chess_app/widgets/app_feedback.dart';

import '../services/scanner_api_service.dart';

/// Who is to move, asked of the trainer: `w`, `b`, or null when they backed
/// out. [detail] says where the question comes from — a diagram number, a
/// page.
Future<String?> askSideToMove(BuildContext context, {String? detail}) =>
    showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('side-to-move-dialog'),
        title: const Text('Who is to move?'),
        content: Text(detail ??
            'The book does not state it for this position. The answer is '
                'kept with the position, and asked only once.'),
        actions: [
          TextButton(
              key: const ValueKey('side-to-move-cancel'),
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              key: const ValueKey('side-to-move-black'),
              onPressed: () => Navigator.pop(context, 'b'),
              child: const Text('Black')),
          FilledButton(
              key: const ValueKey('side-to-move-white'),
              onPressed: () => Navigator.pop(context, 'w'),
              child: const Text('White')),
        ],
      ),
    );

/// The FEN a saved position may be used with — one home for the rule that a
/// side nobody set is asked before the position goes anywhere that reads it.
///
/// A diagram does not print who is to move, and a FEN cannot say „nobody
/// knows", so such a position is stored with White and marked for review.
/// Until 23.9.2026 only Saved Positions asked; the Library opened it in
/// Analysis, made an exercise of it, and added it to a tutorial as White to
/// move, and the room put it on the shared board so — and an exercise made
/// that way carried no mark, so it could be sent to a student (the owner:
/// „popravi ovu rupu").
///
/// Not [needsReview]: the position's own [fen], without a question. Otherwise
/// the trainer is asked, the answer is kept on the position (the server
/// rewrites the FEN, and clears the mark unless the book's move no longer
/// plays), and the kept FEN is returned — or null when the trainer backed
/// out or the server refused, which is said.
Future<String?> settledFen(
  BuildContext context, {
  required ScannerApiService api,
  required String puzzleId,
  required String fen,
  required bool needsReview,
  String? detail,
}) async {
  if (!needsReview) return fen;
  final side = await askSideToMove(context, detail: detail);
  if (side == null || !context.mounted) return null;
  final settled = await api.setSideToMove(puzzleId, side);
  if (!context.mounted) return null;
  if (settled == null) {
    AppFeedback.error(context, 'That side cannot be to move in this position.');
    return null;
  }
  return settled;
}
