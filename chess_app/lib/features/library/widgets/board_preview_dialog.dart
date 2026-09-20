// board_preview_dialog.dart — a larger look at a row's board, without opening
// it (`docs/PLAN-EXERCISE.md`, phase 4, decision 3: no stepping through the
// solution in this first version, just the name, the task and who is to
// move — all in words, because the owner is colour-blind and a dot of one
// hue beside a dot of another tells them nothing).

import 'package:flutter/material.dart';

import '../models/library_entry.dart';
import 'board_preview_panel.dart';

class BoardPreviewDialog extends StatelessWidget {
  const BoardPreviewDialog({super.key, required this.entry, this.onOpen});

  final LibraryEntry entry;

  /// Drawn as an „Open" button when given; absent when null — a widget draws
  /// only what it was given (CLAUDE.md rule 15). Pressing it closes this
  /// dialog first, then calls back.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final onOpenCallback = onOpen;
    // AlertDialog wraps its content in an IntrinsicWidth (the same reason
    // `PositionPickerDialog` gives its content a fixed `SizedBox` rather than
    // a `LayoutBuilder`), so the size is read from `MediaQuery` instead — as
    // large as the screen allows, never a fixed width, matching the insets
    // and content padding set below.
    final boardSize =
        (MediaQuery.of(context).size.width - 64).clamp(240.0, 320.0);

    return AlertDialog(
      // The default insets and content padding leave a 360 dp phone with
      // less than 240 dp for the board itself; narrowed here rather than in
      // the board's own size, so the dialog still reads as one on a wide
      // screen.
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      title: Text(entry.title),
      // The body is shared with the pane phase 5 put beside the shelf — one
      // home for what „a larger look at this entry" consists of, so the two
      // cannot drift into saying different things about the same position.
      content: SizedBox(
        width: boardSize,
        child: BoardPreviewPanel(entry: entry, boardSize: boardSize),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (onOpenCallback != null)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onOpenCallback();
            },
            child: const Text('Open'),
          ),
      ],
    );
  }
}
