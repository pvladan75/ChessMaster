import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';

/// Everything the endgame screens have to say, in one place.
///
/// It used to be two: the task and the context above the board, the verdict
/// below it. On a desktop window that meant looking over the board and then
/// under it to follow a single exercise, and the two halves were never both in
/// view at once.
///
/// So the panel is one block wherever it goes — right of the board when there
/// is room, under it when there is not. Under rather than over on a phone on
/// purpose: text that appears and disappears above the board pushes the board
/// down as it changes, and a board that moves while you are looking at it is
/// worse than a caption a glance further away.
class EndgameInfoPanel extends StatelessWidget {
  const EndgameInfoPanel({
    super.key,
    required this.title,
    this.subtitle,
    this.chips = const [],
    this.message,
    this.messageIsGood = false,
  });

  /// What the position asks, in a sentence.
  final String title;

  /// The same thing said as an instruction, when there is one.
  final String? subtitle;

  /// Where it came from: the game, the material, how far along the session is.
  final List<String> chips;

  /// The verdict on the last move, or a note about what just happened.
  final String? message;

  final bool messageIsGood;

  /// Beside the board on an expanded window. Narrow enough to leave the board
  /// the bigger half of a 840 dp layout.
  static const double sideWidth = 280;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: theme.textTheme.bodySmall),
          ],
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 8),
            // Wrap, not Row: a game label with two full names and two ratings
            // outgrows any column, and a release build clips instead of warning.
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [for (final text in chips) _Chip(text: text)],
            ),
          ],
          if (message != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (messageIsGood ? Colors.green : Colors.orange)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(message!),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall),
      );
}

/// Places the panel to the right of the board or under it, and hands the board
/// what is left of the width either way.
///
/// The caller works out its own board size from [boardArea] rather than being
/// told one, because each screen reserves a different amount for its own
/// controls under the board.
class EndgameBoardLayout extends StatelessWidget {
  const EndgameBoardLayout({
    super.key,
    required this.wide,
    required this.constraints,
    required this.panel,
    required this.builder,
  });

  final bool wide;
  final BoxConstraints constraints;
  final Widget panel;

  /// Called with the width available for the board column.
  final Widget Function(double boardArea) builder;

  @override
  Widget build(BuildContext context) {
    if (!wide) {
      return builder(constraints.maxWidth);
    }
    const gap = 16.0;
    final boardArea = (constraints.maxWidth - EndgameInfoPanel.sideWidth - gap)
        .clamp(200.0, constraints.maxWidth);
    // The board first and the panel to the right of it: the board is what is
    // being looked at, and on a left-to-right reading a caption belongs after
    // the thing it captions rather than before it.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: builder(boardArea)),
        const SizedBox(width: gap),
        SizedBox(width: EndgameInfoPanel.sideWidth, child: panel),
      ],
    );
  }
}
