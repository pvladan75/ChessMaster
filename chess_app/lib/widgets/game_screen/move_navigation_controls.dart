import 'package:chess_app/theme/app_spacing.dart';
import 'package:chess_app/theme/app_radii.dart';
import 'package:flutter/material.dart';

import 'package:chess_app/core/models/move_cursor.dart';
import 'package:chess_app/widgets/game_screen/branch_choice_sheet.dart';
import 'package:chess_app/widgets/board_flip_button.dart';
import 'package:chess_app/theme/breakpoints.dart';
import 'package:chess_app/widgets/landscape_board_layout.dart';

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

  /// Label between the back and forward buttons, e.g. "Move 3 of 12".
  ///
  /// **Null by default since 18.9.2026.** It used to default to the word
  /// „Navigation", which named the strip rather than saying anything about the
  /// position — and it was wide enough to push the flip and board-view buttons
  /// onto a second row on a 360 dp phone. Reported live against TODO-provera
  /// 180.3: „moglo bi da se u portret modu navigaciona paleta svede na jedan
  /// red". Every screen that wants a label passes a real one („Move 3 of 12",
  /// „5/20"); the three that relied on the default — the room, and the exercise
  /// screen twice — wanted nothing.
  final String? centerLabel;

  /// Screen-specific buttons appended after the flip button — the Analysis
  /// Studio's comment, NAG and delete actions. They sit in this row because
  /// they act on the move the cursor is standing on.
  final List<Widget> trailing;

  /// Smaller icons for a screen where this strip shares a crowded column.
  final double? iconSize;

  /// 40 dp buttons instead of 48, and less padding, so the strip stays one row
  /// where it has to share a narrow screen. Null decides by [_isTight]; every
  /// button in the strip — the screen's [trailing] ones included — takes the
  /// smaller size.
  final bool? dense;

  /// Whether this strip has to earn its width: a phone on its side, where the
  /// strip shares a column with the panels, **or** a phone held upright, where
  /// it is the full width of a 360 dp screen and was wrapping to two rows.
  ///
  /// The second half was missing until 18.9.2026, even though the comment on
  /// [_PhoneLayout] had already written down why — „a phone's width is the same
  /// problem in portrait" — and the tutorial studio passed `dense: true` by
  /// hand to work around it.
  static bool _isTight(BuildContext context) =>
      LandscapeBoardLayout.applies(context) ||
      MediaQuery.sizeOf(context).width < Breakpoints.compactWidth;

  /// What a dense strip needs per button, for anyone sizing a column to hold
  /// one: [LandscapeBoardLayout.minPanelWidth] is derived from it.
  static const double denseButton = 40.0;
  static const double densePadding = AppSpacing.sm;

  const MoveNavigationControls({
    super.key,
    required this.cursor,
    this.canNavigate = true,
    this.onFlipBoard,
    this.centerLabel,
    this.trailing = const [],
    this.iconSize,
    this.dense,
  });

  /// One step forward — and a question first where that step has more than one
  /// meaning.
  ///
  /// The rule holds for every screen with this strip, because the alternative
  /// is the one the owner met: at a fork the strip took the first child every
  /// time, so the other lines could not be reached by navigation at all. A
  /// model that does not branch answers with an empty list and is never asked.
  ///
  /// "Go to the end" is deliberately left alone: it means the end of *this*
  /// line, and a question at every fork on the way would make it unusable.
  Future<void> _forward(BuildContext context) async {
    final branches = cursor.forwardBranches;
    if (branches.length < 2) {
      cursor.next();
      return;
    }
    final picked = await showBranchChoice(context, branches);
    // Closing the sheet leaves the board where it was. Being asked and saying
    // nothing is not the same as choosing the main line.
    if (picked == null) return;
    cursor.takeBranch(picked);
  }

  @override
  Widget build(BuildContext context) {
    final dense = this.dense ?? _isTight(context);
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
          tooltip: 'Go to start',
        ),
        IconButton(
          icon: Icon(Icons.chevron_left, size: iconSize),
          onPressed: canGoBack ? cursor.previous : null,
          tooltip: 'Previous move',
        ),
        if (centerLabel != null)
          Text(
            centerLabel!,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        IconButton(
          icon: Icon(Icons.chevron_right, size: iconSize),
          onPressed: canGoForward ? () => _forward(context) : null,
          tooltip: 'Next move',
        ),
        IconButton(
          icon: Icon(Icons.last_page, size: iconSize),
          onPressed: canGoForward ? cursor.last : null,
          tooltip: 'Go to end',
        ),
        if (onFlipBoard != null)
          BoardFlipButton(size: iconSize, onPressed: onFlipBoard!),
        ...trailing,
      ],
    );

    return Container(
      margin:
          EdgeInsets.symmetric(vertical: dense ? AppSpacing.xs : AppSpacing.sm),
      padding: EdgeInsets.symmetric(
          horizontal: dense ? densePadding : AppSpacing.lg,
          vertical: dense ? 0 : AppSpacing.xs),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadii.roundedMd,
      ),
      child: dense
          ? IconButtonTheme(
              data: IconButtonThemeData(
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(denseButton),
                  maximumSize: const Size.square(denseButton),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              child: buttons,
            )
          : buttons,
    );
  }
}
