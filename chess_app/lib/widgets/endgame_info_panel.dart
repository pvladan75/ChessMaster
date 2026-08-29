import 'package:flutter/material.dart';

import 'package:chess_app/services/speech_service.dart';
import 'package:chess_app/theme/app_colors.dart';

/// Everything the endgame screens have to say, in one place and in one order.
///
/// It used to be two places: the task and the context above the board, the
/// verdict below it. On a desktop window that meant looking over the board and
/// then under it to follow a single exercise, and the two halves were never
/// both in view.
///
/// The order inside it is the order the reader needs it in, which is not the
/// order it was first written in:
///
///   1. which game this is, and how far along the session is;
///   2. what is being asked right now;
///   3. what happened when they answered.
///
/// Right of the board rather than left, and under rather than over on a phone.
/// The board is the thing being looked at, so its caption belongs after it; and
/// text that appears and disappears above a board pushes the board down as it
/// changes, which is worse than a caption a glance further away.
class EndgameInfoPanel extends StatefulWidget {
  const EndgameInfoPanel({
    super.key,
    required this.title,
    this.subtitle,
    this.chips = const [],
    this.message,
    this.messageIsGood = false,
  });

  /// What to do now, in a sentence, and always phrased as something to do.
  final String title;

  /// The same instruction spelled out, when it needs to be.
  final String? subtitle;

  /// Which game, which ending, how far along. Context rather than instruction,
  /// so it sits above the ask instead of between the ask and the answer.
  final List<String> chips;

  /// The verdict on the last move, or a note about what just happened.
  final String? message;

  final bool messageIsGood;

  /// Beside the board on an expanded window.
  static const double sideWidth = 280;

  @override
  State<EndgameInfoPanel> createState() => _EndgameInfoPanelState();
}

/// The panel is also where the app speaks from.
///
/// Here rather than in the two screens that use it, because the panel already
/// holds the rule about what is worth reading and in what order - and because
/// a screen that sets its feedback in six places would have to remember to
/// speak in all six. What is on the panel is what is said; there is no second
/// list to keep in step.
class _EndgameInfoPanelState extends State<EndgameInfoPanel> {
  @override
  void initState() {
    super.initState();
    _say();
  }

  @override
  void didUpdateWidget(EndgameInfoPanel old) {
    super.didUpdateWidget(old);
    if (old.message != widget.message ||
        old.title != widget.title ||
        old.subtitle != widget.subtitle) {
      _say();
    }
  }

  /// The verdict when there is one, the task when there is not.
  ///
  /// Both at once would mean hearing the question again after every answer,
  /// which is the thing that makes spoken interfaces tiring: the verdict is
  /// the new information, and the task is still on the screen for the eyes.
  void _say() {
    final message = widget.message;
    if (message != null && message.trim().isNotEmpty) {
      SpeechService.instance.speak(message);
      return;
    }
    final subtitle = widget.subtitle;
    SpeechService.instance.speak(
      subtitle == null || subtitle.isEmpty
          ? widget.title
          : '${widget.title}. $subtitle',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.title;
    final subtitle = widget.subtitle;
    final chips = widget.chips;
    final message = widget.message;
    final messageIsGood = widget.messageIsGood;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chips.isNotEmpty) ...[
            // Wrap, not Row: a game label with two full names and two ratings
            // outgrows any column, and a release build clips instead of
            // warning.
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [for (final text in chips) _Chip(text: text)],
            ),
            const SizedBox(height: 10),
          ],
          Text(title, style: theme.textTheme.titleMedium),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle, style: theme.textTheme.bodySmall),
          ],
          if (message != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (messageIsGood
                        ? context.colors.success
                        : context.colors.warning)
                    .withValues(alpha: 0.15),
                borderRadius: AppRadii.roundedSm,
              ),
              child: Text(message),
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
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall),
      );
}

/// Sizes the board and puts the panel beside it, or under it on a phone.
///
/// The size is worked out here rather than by each screen because the answer
/// depends on where the panel went. The first version let the board column take
/// every pixel left over and centred a capped board inside it, which on a wide
/// monitor left the panel marooned at the far edge with a hand's width of empty
/// board between them - the two things you have to read together, as far apart
/// as the window allowed.
class EndgameBoardLayout extends StatelessWidget {
  const EndgameBoardLayout({
    super.key,
    required this.wide,
    required this.constraints,
    required this.panel,
    required this.reserveHeight,
    required this.builder,
    this.maxBoard = 720,
  });

  final bool wide;
  final BoxConstraints constraints;
  final Widget panel;

  /// Room the caller needs under the board for its own controls.
  final double reserveHeight;

  /// Called with the size the board should be.
  final Widget Function(double boardSize) builder;

  /// A board bigger than this stops being easier to read and starts being a
  /// long way for the eye to travel.
  final double maxBoard;

  static const double _gap = 16;
  static const double _minColumn = 380;

  @override
  Widget build(BuildContext context) {
    final aside = wide ? EndgameInfoPanel.sideWidth + _gap : 0.0;
    // The board is square, so the tighter axis bounds it. Both are needed: a
    // short wide window and a tall narrow one fail in opposite directions, and
    // a release build paints no warning when either does.
    final widthBased =
        (constraints.maxWidth - aside - 24).clamp(160.0, maxBoard);
    final heightBased =
        (constraints.maxHeight - reserveHeight).clamp(160.0, maxBoard);
    final boardSize = heightBased < widthBased ? heightBased : widthBased;

    if (!wide) return builder(boardSize);

    // The column is at least wide enough for the navigation strip, which does
    // not shrink with the board.
    final columnWidth = boardSize < _minColumn ? _minColumn : boardSize;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: columnWidth, child: builder(boardSize)),
          const SizedBox(width: _gap),
          SizedBox(width: EndgameInfoPanel.sideWidth, child: panel),
        ],
      ),
    );
  }
}
