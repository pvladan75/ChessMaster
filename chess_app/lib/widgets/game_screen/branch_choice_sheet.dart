import 'package:flutter/material.dart';

import 'package:chess_app/core/models/move_cursor.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// Which line to follow out of a position that branches.
///
/// The rule this exists for holds everywhere in the app, not on one screen: at
/// a fork, **"forward" has more than one meaning**, and a strip that walks into
/// the first child every time is a strip on which the other lines cannot be
/// reached at all. That was found in the repertoire — a position with two
/// replies and no way to navigate into the second — and it was true of every
/// screen with a branching model, which is the lesson board, the studio and the
/// repertoire.
///
/// One sheet rather than one per screen, for the same reason there is one
/// [MoveCursor]: this is the same question with the same answer shape, and six
/// copies of it would drift into six wordings.
///
/// Answers the index into [branches], or null when the reader closed it — which
/// must leave the board exactly where it was rather than defaulting to the main
/// line. Being asked and saying nothing is not the same as choosing.
Future<int?> showBranchChoice(
  BuildContext context,
  List<MoveBranch> branches,
) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xxs),
            child: Text(
              'Odavde ide više linija — kojom?',
              style: AppText.bodyBold.copyWith(color: sheet.colors.textPrimary),
            ),
          ),
          for (var i = 0; i < branches.length; i++)
            ListTile(
              dense: true,
              leading: Icon(
                // The move that would have been taken without asking is marked
                // rather than preselected: the whole point is that the others
                // are reachable, and a highlighted default invites pressing it
                // again without reading.
                branches[i].isMain ? Icons.star : Icons.arrow_forward,
                size: 18,
                color: branches[i].isMain
                    ? sheet.colors.warning
                    : sheet.colors.accent,
              ),
              title: Text(
                branches[i].label,
                style:
                    AppText.bodyLarge.copyWith(color: sheet.colors.textPrimary),
              ),
              subtitle: branches[i].detail == null
                  ? null
                  : Text(
                      branches[i].detail!,
                      style: AppText.caption
                          .copyWith(color: sheet.colors.textMuted),
                    ),
              onTap: () => Navigator.pop(sheet, i),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}
