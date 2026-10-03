import 'dart:async';

import 'package:flutter/material.dart';

import 'package:chess_app/core/speech/spoken_line.dart';
import 'package:chess_app/services/speech_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/breakpoints.dart';
import 'package:chess_app/widgets/landscape_board_layout.dart';
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
    this.task,
    this.taskText,
    this.taskLeading,
    this.taskExtra,
    this.detail,
    this.chips = const [],
    this.message = const [],
    this.messageText,
    this.messageIcon,
    this.note,
    this.messageIsGood = false,
    this.children = const [],
    this.autoSpeak = true,
    this.speech,
  }) : assert(task != null || taskText != null,
            'a panel without a task line must say its task in words');

  /// What to do now, in a sentence, and always phrased as something to do. It
  /// carries the speaker, and is said when it appears and whenever it changes.
  ///
  /// Null where the screen asks something it has no clips for (Basic
  /// checkmate, „Play it out"): [taskText] is then drawn alone, with no
  /// speaker, because a speaker that says nothing — or says some other
  /// sentence — would be a control that is never a no-op turned inside out.
  final SpokenLine? task;

  /// What the task line draws, where that cannot be [SpokenLine.text]: a list
  /// of moves is drawn with commas, which the clips have no word for. Null
  /// draws the line's own text, which is every other sentence on the screen.
  /// With no [task] it is the whole line, and required.
  final String? taskText;

  /// Drawn before the task line, beside it: the side whose move it is, as a
  /// ring or a disc — a shape, never a character in the text.
  final Widget? taskLeading;

  /// Drawn right under the task line: „Your move" in a game, which is part of
  /// what is being asked and not of what happened.
  final Widget? taskExtra;

  /// A second sentence under the task — the story of the position, or what to
  /// do on the board. Said once, right after the task, when it appears.
  final SpokenLine? detail;

  /// Which game, which ending, how far along. Context rather than instruction,
  /// so it sits above the ask instead of between the ask and the answer.
  final List<String> chips;

  /// The verdict on the last move. Drawn here and said by the screen, which
  /// knows when the answer was given; the panel never says it twice.
  final List<SpokenLine> message;

  /// The verdict as drawn text, for a sentence the screen says in other words
  /// than it draws („Stockfish delivered checkmate. Try again." is drawn;
  /// „Checkmate. Stockfish wins. Try again." is what the clips say) and for
  /// lines the table has no words for, a rating. Drawn after [message], in
  /// the same box, and never spoken.
  final List<String>? messageText;

  /// A shape for the message box: good and not good are said in words and in
  /// the shape of an icon, never in the colour of the box alone (the owner is
  /// colourblind). Null draws none, which is every caller that predates it.
  final IconData? messageIcon;

  /// A note that is only drawn: "Checking tablebases…", a refusal from the
  /// server. Not a sentence of the table, so never spoken.
  final String? note;

  final bool messageIsGood;

  /// Whatever the screen shows once there is something to show: the solution
  /// tree after a puzzle, the engine's lines after it is over. Under the
  /// message, in the panel's own column, so that what is asked, what happened
  /// and what there is to learn from it are one thing to read.
  final List<Widget> children;

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
    final messageText = widget.messageText ?? const <String>[];
    final messageIcon = widget.messageIcon;
    final messageIsGood = widget.messageIsGood;
    final taskWidget = task != null
        ? SpeakableInfo(
            text: widget.taskText ?? task.text,
            line: task,
            autoSpeak: widget.autoSpeak,
            compact: true,
            speech: widget.speech,
            style: theme.textTheme.titleMedium,
          )
        : Text(widget.taskText!, style: theme.textTheme.titleMedium);
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
          if (widget.taskLeading == null)
            taskWidget
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Level with the first line of the task, whatever its size.
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: widget.taskLeading!,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: taskWidget),
              ],
            ),
          if (widget.taskExtra != null) ...[
            const SizedBox(height: AppSpacing.xs),
            widget.taskExtra!,
          ],
          if (detail != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(detail.text, style: theme.textTheme.bodySmall),
          ],
          if (message.isNotEmpty || messageText.isNotEmpty || note != null) ...[
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (messageIcon != null) ...[
                    Icon(messageIcon, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final line in message) Text(line.text),
                        for (final text in messageText) Text(text),
                        if (note != null) Text(note),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (widget.children.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            ...widget.children,
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
    this.scale = 1.0,
    this.panelWidth = TrainerInfoPanel.sideWidth,
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

  /// The reader's board size setting, 0.6–1.0. It only ever shrinks the board,
  /// and 1.0 — every screen that does not offer the slider — leaves the size
  /// exactly as it was worked out.
  final double scale;

  /// How wide the panel is beside the board: [TrainerInfoPanel.sideWidth]
  /// unless the screen puts more in it than a task and a verdict — the puzzle
  /// screen's solution tree is a card with a header row that needs about 300.
  final double panelWidth;

  static const double _gap = 16;
  static const double _minColumn = 380;

  @override
  Widget build(BuildContext context) {
    final aside = wide ? panelWidth + _gap : 0.0;
    // The board is square, so the tighter axis bounds it. Both are needed: a
    // short wide window and a tall narrow one fail in opposite directions, and
    // a release build paints no warning when either does.
    final widthBased =
        (constraints.maxWidth - aside - 24).clamp(160.0, maxBoard);
    final heightBased =
        (constraints.maxHeight - reserveHeight).clamp(160.0, maxBoard);
    final fitted = heightBased < widthBased ? heightBased : widthBased;
    final boardSize = scale >= 1.0 ? fitted : fitted * scale.clamp(0.0, 1.0);

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
          SizedBox(width: panelWidth, child: panel),
        ],
      ),
    );
  }
}

/// The whole body of a board screen, with the one choice rule R1 of
/// `docs/PLAN-EKRANI.md` describes made once.
///
/// A window at least [Breakpoints.wide] wide gets the board sized by its
/// height and the panel beside it ([TrainerBoardLayout]); a phone held upright
/// gets the panel under the board, the whole body scrolling; a phone on its
/// side ([LandscapeBoardLayout.applies]) gets the board on the left and the
/// panel in the right column, the buttons pinned under it. **The choice is the
/// window's, never `MediaQuery.orientation`**: a desktop window that is wider
/// than it is tall is not a phone on its side, and the puzzle screen used to
/// treat it as one.
///
/// It was written out in `endgame_trainer_screen.dart`, and the puzzle screen
/// was about to be the second copy; the endgame trainer calls this now and
/// draws exactly what it drew.
class TrainerScreenLayout extends StatelessWidget {
  const TrainerScreenLayout({
    super.key,
    required this.board,
    required this.panel,
    required this.controls,
    this.strip,
    this.asidePanel,
    this.extras,
    this.boardAside,
    this.scale = 1.0,
    this.panelWidth = TrainerInfoPanel.sideWidth,
    this.wideReserve = 140,
    this.phoneReserve = 280,
  });

  /// Draws the board at the side it is given.
  final Widget Function(double side) board;

  /// Everything the screen says: under the board on a phone held upright, and
  /// beside it wherever [asidePanel] is not given.
  final Widget panel;

  /// The buttons: under the board, centred on it; pinned under the right
  /// column when the phone is on its side.
  final Widget controls;

  /// A strip of its own between the board and the buttons (the move strip),
  /// pinned above the buttons on a phone on its side.
  final Widget? strip;

  /// What stands beside the board — on a window, and as the right column of a
  /// phone on its side — where that is more than [panel] is under it: the
  /// endgame trainer's panel with the tablebase findings under it.
  final Widget? asidePanel;

  /// What a phone held upright shows after the buttons: whatever the screen
  /// puts in [asidePanel] beside the board on a window, so that on a phone the
  /// buttons are not a long scroll below it. Nothing is drawn for it on a
  /// window or a phone on its side — those have [asidePanel].
  final Widget? extras;

  /// An eval bar as tall as the board, on a phone on its side.
  final Widget Function(double height)? boardAside;

  /// The reader's board size setting, 0.6–1.0, which only ever shrinks the
  /// board. A screen that offers the slider must pass it.
  final double scale;

  /// The panel's width beside the board on a window; see
  /// [TrainerBoardLayout.panelWidth].
  final double panelWidth;

  /// Room under the board for the strip and the buttons, on a window and on a
  /// phone (where the panel is under the board as well).
  final double wideReserve;
  final double phoneReserve;

  @override
  Widget build(BuildContext context) {
    final wide = Breakpoints.isWide(context);

    if (LandscapeBoardLayout.applies(context)) {
      return LandscapeBoardLayout(
        board: board,
        boardAside: boardAside,
        boardScale: scale,
        panels: asidePanel ?? panel,
        footer: [
          if (strip != null) strip!,
          const SizedBox(height: AppSpacing.sm),
          controls,
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: TrainerBoardLayout(
            wide: wide,
            constraints: constraints,
            panel: asidePanel ?? panel,
            scale: scale,
            panelWidth: panelWidth,
            // The buttons under the board; on a phone the panel as well.
            reserveHeight: wide ? wideReserve : phoneReserve,
            builder: (boardSize) {
              return Column(
                children: [
                  Center(child: board(boardSize)),
                  if (strip != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    strip!,
                  ],
                  if (!wide) ...[
                    const SizedBox(height: AppSpacing.md),
                    panel,
                  ],
                  const SizedBox(height: AppSpacing.md),
                  controls,
                  if (!wide && extras != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    extras!,
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}
