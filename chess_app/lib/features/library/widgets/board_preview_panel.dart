// board_preview_panel.dart — what a larger look at an entry's board consists
// of, in one place.
//
// Extracted from `board_preview_dialog.dart` for phase 5 of
// `docs/PLAN-LISTE.md`, which puts the same thing in a pane beside the shelf
// on a wide window. The plan's own words: the detail pane does **not**
// duplicate what a dialog already builds. So the dialog keeps its title, its
// insets and its buttons — those are a dialog's business — and everything
// inside it that is about the *entry* lives here, drawn identically by both.
//
// The wording is deliberate and is not this file's to change: the task and
// the side to move are said **in words**, because the owner is colour-blind
// and a dot of one hue beside a dot of another tells them nothing
// (`docs/PLAN-EXERCISE.md`, phase 4, decision 3).

import 'package:flutter/material.dart';

import 'package:chess_app/features/exercises/models/exercise_task_words.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

import '../models/library_entry.dart';

class BoardPreviewPanel extends StatelessWidget {
  const BoardPreviewPanel({
    super.key,
    required this.entry,
    required this.boardSize,
  });

  final LibraryEntry entry;

  /// The board's side length. Both callers work it out from the room they
  /// have — the dialog from `MediaQuery`, the pane from its own constraint —
  /// so this widget is told rather than asking, and cannot read the window
  /// when it is not the window that decides.
  final double boardSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The task, for an exercise only — a bare position was never asked to
        // do anything.
        if (entry.isExercise) ...[
          Text(
            exerciseTaskWords(entry.task),
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Text(
          sideToMoveWords(entry.fen),
          style: AppText.body.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        BoardThumbnail(
          fen: entry.fen,
          size: boardSize,
          isWhiteBottom: entry.task?['side'] != 'b',
        ),
      ],
    );
  }
}
