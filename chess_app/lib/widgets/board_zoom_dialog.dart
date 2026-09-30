// board_zoom_dialog.dart — a position on a board as large as the window
// allows, with what it shows said in words.
//
// The owner, 30.9.2026, on the Opening leaks screen: a click on the board
// should give him the board enlarged, so he can read the position.
//
// Not the Library's `BoardPreviewDialog`: that one previews a `LibraryEntry`
// — its title, its task — and caps the board at 320, which is a larger look
// on a phone and a smaller one on the desktop where this was asked for. What
// the two share is the rule both keep: the side to move is said in words,
// never left to a dot of colour (the owner is colour-blind).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' show PlayerColor;

import 'package:chess_app/features/exercises/models/exercise_task_words.dart'
    show sideToMoveWords;
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';

class BoardZoomDialog extends StatelessWidget {
  const BoardZoomDialog({
    super.key,
    required this.fen,
    required this.whiteBottom,
    required this.title,
    this.details = const [],
    this.onOpenInAnalysis,
  });

  final String fen;
  final bool whiteBottom;
  final String title;

  /// Lines under the side to move, each at most two lines tall.
  final List<String> details;

  /// Drawn as „Open in Analysis" when given, absent when null — a widget
  /// draws only what it was given (CLAUDE.md rule 15). Pressing it closes
  /// this dialog first and then calls back, so what it opens is pushed over
  /// the screen and not over a dialog that is about to go.
  final VoidCallback? onOpenInAnalysis;

  /// Never smaller than a thumbnail made readable, never larger than a board
  /// anyone reads a position from.
  static const double minBoard = 200;
  static const double maxBoard = 720;

  static const double _insetX = 16;
  static const double _insetY = 24;
  static const double _padding = 16;

  /// Everything around the board, generously: a two-line title, the side to
  /// move, [details] lines of two, the gaps and the row of buttons. Generous
  /// because text is measured here by budget and not by layout — the
  /// dialog scrolls rather than clip if a budget is ever short.
  static double _around(int details) =>
      2 * 24 + 20 + details * 2 * 18 + 3 * AppSpacing.md + 48;

  /// The board's side in a window of [window]: as large as both the width
  /// and the height leave it, between [minBoard] and [maxBoard].
  static double boardSideFor(Size window, {int details = 0}) {
    final wide = window.width - 2 * (_insetX + _padding);
    final tall = window.height - 2 * (_insetY + _padding) - _around(details);
    return math.min(wide, tall).clamp(minBoard, maxBoard).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final side =
        boardSideFor(MediaQuery.sizeOf(context), details: details.length);
    final open = onOpenInAnalysis;
    return Dialog(
      key: const Key('board-zoom-dialog'),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: _insetX, vertical: _insetY),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(_padding),
        child: SizedBox(
          width: side,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.title.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                sideToMoveWords(fen),
                style: AppText.bodyLarge.copyWith(color: colors.textSecondary),
              ),
              for (final line in details) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  line,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppText.bodyLarge.copyWith(color: colors.textSecondary),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              BoardWithCoordinates(
                key: const Key('board-zoom-board'),
                size: side,
                orientation:
                    whiteBottom ? PlayerColor.white : PlayerColor.black,
                builder: (boardSize) => BoardThumbnail(
                  fen: fen,
                  size: boardSize,
                  isWhiteBottom: whiteBottom,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                    if (open != null)
                      FilledButton.icon(
                        key: const Key('board-zoom-open-in-analysis'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          open();
                        },
                        icon: const Icon(Icons.biotech_outlined, size: 16),
                        label: const Text('Open in Analysis'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
