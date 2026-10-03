import 'dart:async';

import 'package:flutter/material.dart';

import 'package:chess_app/core/speech/spoken_line.dart';
import 'package:chess_app/services/speech_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/speakable_info.dart';

/// Everything a board screen has to say, in one place and in one order — the
/// panel of rules R2 and R3 in `docs/PLAN-EKRANI.md`. Built for the endgame
/// trainer and the blunder walk, and named for every board screen since
/// 3.10.2026.
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
///
/// **Every sentence on it is a [SpokenLine]** (`docs/PLAN-GOVOR-IZ-KLIPOVA.md`,
/// phase 4b): what is drawn is the line's text, and what is heard is the same
/// line played from the shipped clips, so the two cannot differ. Nothing here
/// reaches the device voice.
class TrainerInfoPanel extends StatefulWidget {
  const TrainerInfoPanel({
    super.key,
    required this.task,
    this.taskText,
    this.detail,
    this.chips = const [],
    this.message = const [],
    this.note,
    this.messageIsGood = false,
    this.autoSpeak = true,
    this.speech,
  });

  /// What to do now, in a sentence, and always phrased as something to do. It
  /// carries the speaker, and is said when it appears and whenever it changes.
  final SpokenLine task;

  /// What the task line draws, where that cannot be [SpokenLine.text]: a list
  /// of moves is drawn with commas, which the clips have no word for. Null
  /// draws the line's own text, which is every other sentence on the screen.
  final String? taskText;

  /// A second sentence under the task — the story of the position, or what to
  /// do on the board. Said once, right after the task, when it appears.
  final SpokenLine? detail;

  /// Which game, which ending, how far along. Context rather than instruction,
  /// so it sits above the ask instead of between the ask and the answer.
  final List<String> chips;

  /// The verdict on the last move. Drawn here and said by the screen, which
  /// knows when the answer was given; the panel never says it twice.
  final List<SpokenLine> message;

  /// A note that is only drawn: "Checking tablebases…", a refusal from the
  /// server. Not a sentence of the table, so never spoken.
  final String? note;

  final bool messageIsGood;

  /// Say the task (and the detail) when they appear. Off where the task only
  /// repeats the verdict that was just said, so the verdict is not followed by
  /// its own echo.
  final bool autoSpeak;

  /// Injectable for tests; the app's one `SpeechService` otherwise.
  final SpeechService? speech;

  /// Beside the board on an expanded window.
  static const double sideWidth = 280;

  @override
  State<TrainerInfoPanel> createState() => _TrainerInfoPanelState();
}

/// The panel is also where the task is said from — by [SpeakableInfo], which
/// owns the speaker and the rule that it is never a no-op — and where the line
/// under it is said right after.
class _TrainerInfoPanelState extends State<TrainerInfoPanel> {
  SpeechService get _speech => widget.speech ?? SpeechService.instance;

  @override
  void initState() {
    super.initState();
    _sayDetail();
  }

  @override
  void didUpdateWidget(TrainerInfoPanel old) {
    super.didUpdateWidget(old);
    if (old.detail?.text != widget.detail?.text) _sayDetail();
  }

  /// After the frame, so the task — said from [SpeakableInfo]'s `initState`,
  /// which runs during this frame's build — is the first thing the voice
  /// hears and the detail is queued behind it. Forced, because the same
  /// sentence two positions in a row is two sentences.
  void _sayDetail() {
    final detail = widget.detail;
    if (detail == null || !widget.autoSpeak) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        unawaited(
            _speech.speakLine(detail, force: true).catchError((Object _) {}));
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = widget.task;
    final detail = widget.detail;
    final chips = widget.chips;
    final message = widget.message;
    final note = widget.note;
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
          SpeakableInfo(
            text: widget.taskText ?? task.text,
            line: task,
            autoSpeak: widget.autoSpeak,
            compact: true,
            speech: widget.speech,
            style: theme.textTheme.titleMedium,
          ),
          if (detail != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(detail.text, style: theme.textTheme.bodySmall),
          ],
          if (message.isNotEmpty || note != null) ...[
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in message) Text(line.text),
                  if (note != null) Text(note),
                ],
              ),
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
class TrainerBoardLayout extends StatelessWidget {
  const TrainerBoardLayout({
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
    final aside = wide ? TrainerInfoPanel.sideWidth + _gap : 0.0;
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
          SizedBox(width: TrainerInfoPanel.sideWidth, child: panel),
        ],
      ),
    );
  }
}
