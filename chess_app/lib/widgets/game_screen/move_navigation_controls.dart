import 'package:chess_app/theme/app_spacing.dart';
import 'package:chess_app/theme/app_radii.dart';
import 'package:flutter/material.dart';

import 'package:chess_app/core/models/move_cursor.dart';
import 'package:chess_app/widgets/board_flip_button.dart';

/// First/prev/next/last toolbar for walking a line of moves, with an optional
/// flip button.
///
/// This is the one navigation strip in the app. It used to be six: this one for
/// the lesson room, a near-identical `MoveHistoryNavigationWidget` for the AI
/// Studio, and one apiece in the lesson viewer, the review session and the
/// Analysis Studio — which had drifted into different icons
/// (`navigate_before` vs `chevron_left`) and different tooltips for the same
/// four buttons.
///
/// What kept them apart was three different move models underneath, so the
/// widget no longer speaks to any of them: it drives a [MoveCursor] and knows
/// nothing else.
class MoveNavigationControls extends StatelessWidget {
  final MoveCursor cursor;

  /// Disables every control. Used in a room where this seat may not drive the
  /// shared board, since navigating broadcasts the position to everyone.
  final bool canNavigate;

  /// Omitted where the screen has no board orientation to flip.
  final VoidCallback? onFlipBoard;

  /// Label between the back and forward buttons, e.g. "Potez 3 od 12".
  final String? centerLabel;

  /// Screen-specific buttons appended after the flip button — the Analysis
  /// Studio's comment, NAG and delete actions. They sit in this row because
  /// they act on the move the cursor is standing on.
  final List<Widget> trailing;

  /// Smaller icons for a screen where this strip shares a crowded column.
  final double? iconSize;

  const MoveNavigationControls({
    super.key,
    required this.cursor,
    this.canNavigate = true,
    this.onFlipBoard,
    this.centerLabel = 'Navigacija',
    this.trailing = const [],
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final canGoBack = canNavigate && cursor.canGoBack;
    final canGoForward = canNavigate && cursor.canGoForward;

    // A Wrap, not a Row. Nine buttons at a 48 dp touch target need 432 dp and a
    // phone has 360–410, so the Analysis Studio's NAG and delete buttons ran off
    // the right edge. In a release build that is silent — Flutter paints no
    // overflow stripes and logs nothing — so they were simply not there.
    // Wrapping puts them on a second line instead of past the edge, and lets the
    // label keep its full width, which stops "Navigacija" reading as "Naviga…".
    final buttons = Wrap(
      alignment: WrapAlignment.spaceEvenly,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 4,
      children: [
        IconButton(
          icon: Icon(Icons.first_page, size: iconSize),
          onPressed: canGoBack ? cursor.first : null,
          tooltip: 'Idi na početak',
        ),
        IconButton(
          icon: Icon(Icons.chevron_left, size: iconSize),
          onPressed: canGoBack ? cursor.previous : null,
          tooltip: 'Prethodni potez',
        ),
        if (centerLabel != null)
          Text(
            centerLabel!,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        IconButton(
          icon: Icon(Icons.chevron_right, size: iconSize),
          onPressed: canGoForward ? cursor.next : null,
          tooltip: 'Sledeći potez',
        ),
        IconButton(
          icon: Icon(Icons.last_page, size: iconSize),
          onPressed: canGoForward ? cursor.last : null,
          tooltip: 'Idi na kraj',
        ),
        if (onFlipBoard != null)
          BoardFlipButton(size: iconSize, onPressed: onFlipBoard!),
        ...trailing,
      ],
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadii.roundedMd,
      ),
      child: buttons,
    );
  }
}
