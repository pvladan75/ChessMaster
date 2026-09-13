/// „Save as .pgn" for a whole tutorial — phase 4 of
/// `docs/PLAN-PGN-TUTORIJAL.md`.
///
/// It exists to say two things before a file is written, and the second is the
/// reason it is a dialog rather than a button that just saves.
///
///  * **How the tutorial comes apart.** Parts that continue one another are one
///    game and a part that opens on a board of its own starts another, so a
///    trainer learns what the file will hold before they name it.
///  * **What a PGN cannot carry.** A trainer who finds that out by opening the
///    file somewhere else and missing their questions finds it out too late.
library;

import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/services/pgn_file_saver.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/pgn_tutorial_export.dart';
import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';

/// The one sentence about what stays behind.
///
/// The `instruction` is deliberately not in it: a part's wording does travel,
/// written on the position it is asked from. What has no home in a PGN is
/// everything that makes a part a *question* rather than a demonstration, and
/// the three things that belong to the tutorial rather than to any game.
const String pgnExportLoses =
    'A PGN carries the moves, the sentences, the drawings and the '
    'assessments. What a part asks for — the answer, the moves accepted '
    'beside it, which way round the board is drawn — stays behind, and so do '
    'this tutorial\'s title, labels and language. The saved tutorial keeps '
    'all of it.';

/// How the parts come apart into games, in one line.
String pgnExportSummary(int parts, int games) {
  final partWord = parts == 1 ? 'part' : 'parts';
  if (games == 1) {
    return '$parts $partWord, one game: every part continues the one before '
        'it.';
  }
  return '$parts $partWord, $games games — a new game wherever a part opens '
      'on a position the one before it did not reach.';
}

/// Shows what the file will hold and writes it where the trainer says.
///
/// The export is taken from the draft, so what leaves is what is on the screen
/// — unsaved edits included. A trainer who has just written a part and exports
/// before saving must not get the version without it.
Future<void> showTutorialPgnExportDialog(
  BuildContext context,
  TutorialDraft draft,
) async {
  final games = pgnGamesOfTutorial(draft);
  final summary = pgnExportSummary(draft.sections.length, games.length);

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.save_alt, color: ctx.colors.info),
          const SizedBox(width: AppSpacing.sm),
          // Flexible for the reason the analysis export already carries it: an
          // icon beside a Text that cannot shrink is clipped on a narrow
          // dialog, and a release build draws no stripes over it.
          Flexible(
            child: Text('Save tutorial as .pgn',
                style: AppText.title.copyWith(color: ctx.colors.textPrimary)),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(summary,
                style: AppText.body.copyWith(color: ctx.colors.textPrimary)),
            const SizedBox(height: AppSpacing.sm),
            Text(pgnExportLoses,
                style:
                    AppText.caption.copyWith(color: ctx.colors.textSecondary)),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('tutorial-pgn-cancel'),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          key: const Key('tutorial-pgn-save'),
          icon: const Icon(Icons.save_alt, size: 16),
          label: const Text('Save as .pgn'),
          onPressed: () async {
            final save = debugSavePgnFile ?? savePgnFile;
            String? path;
            try {
              path = await save(
                fileName: tutorialPgnFileName(draft.title, DateTime.now()),
                pgn: pgnFileOfTutorial(draft),
              );
            } catch (e) {
              AppLogger.log('[PGN] tutorial not saved: $e');
              if (context.mounted) {
                AppFeedback.error(context, 'The file could not be saved.');
              }
              return;
            }
            // Null is the trainer closing the picker, and somebody who
            // cancelled a save does not need to be told they cancelled it.
            if (path == null) return;

            // The dialog goes first and the message second: a SnackBar under an
            // open dialog is dimmed by its own barrier, and this repository has
            // already shipped a refusal that covered the button it was
            // refusing.
            if (ctx.mounted) Navigator.pop(ctx);
            if (context.mounted) AppFeedback.success(context, 'Saved: $path');
          },
        ),
      ],
    ),
  );
}
