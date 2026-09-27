import 'package:flutter/material.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/theme/arrow_colors.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:chess_app/widgets/game_screen/arrow_color_button.dart';
import 'package:chess_app/widgets/game_screen/board_annotation_controller.dart';

/// How the marking bar is drawn in the width it is given — Preparation's own
/// (`docs/PLAN-PRIPREMA.md`, D11). Lives beside [BoardAnnotationBar] rather
/// than in `preparation_layout.dart`, which imports it back from here, so a
/// low-level widget under `widgets/` does not depend on a feature folder.
///
/// * [regular] — the Tutorial Studio's bar as it has always been: labelled
///   buttons and the five colours.
/// * [compact] — the same controls as 40 dp icon buttons, their words in the
///   tooltips, and the five colours.
/// * [tight] — icons, and one colour button that opens the five.
enum MarkingDensity { regular, compact, tight }

/// The annotation bar under the board — the Tutorial Studio's, and, from
/// [density], Preparation's own two narrower ones.
///
/// Holds the drawing controls: arrow toggle, square toggle, the range toggle,
/// the swatches in [ArrowColor.all], and the clear button.
///
/// Reports every action through callbacks and owns nothing about the marks
/// themselves — the screen owns the [BoardAnnotationController]. It is a
/// `StatefulWidget` only for the one bit of purely visual state the [tight]
/// density needs: whether its single colour button has opened the five.
class BoardAnnotationBar extends StatefulWidget {
  const BoardAnnotationBar({
    super.key,
    required this.mode,
    required this.selectedColorCode,
    required this.onArrowPressed,
    required this.onSquarePressed,
    required this.onColorSelected,
    required this.onClearPressed,
    required this.rangeMode,
    required this.onRangePressed,
    this.density = MarkingDensity.regular,
    this.onUndoPressed,
  });

  final AnnotationMode mode;
  final String selectedColorCode;
  final VoidCallback onArrowPressed;
  final VoidCallback onSquarePressed;
  final ValueChanged<String> onColorSelected;
  final VoidCallback onClearPressed;

  /// Whether the next two taps name a line of squares rather than two squares.
  ///
  /// **A button and not only a modifier key.** SHIFT is the obvious way to ask
  /// for a range and it does not exist on a phone, so a SHIFT-only design would
  /// ship this to half the users — Android is a real target for this app. The
  /// screen holds SHIFT as a shortcut for the same flag, so there is one code
  /// path and the desktop way in is not a second implementation of it.
  final bool rangeMode;
  final VoidCallback onRangePressed;

  /// How this bar is drawn in the width it is given — Preparation's own three
  /// (`docs/PLAN-PRIPREMA.md`, D11). Defaults to [MarkingDensity.regular], the
  /// Tutorial Studio's bar as it has always been, so neither existing caller
  /// changes.
  final MarkingDensity density;

  /// Takes back the last mark of the kind being drawn. Drawn only when given
  /// (rule 15) — the studio does not pass one and gets no button.
  final VoidCallback? onUndoPressed;

  @override
  State<BoardAnnotationBar> createState() => _BoardAnnotationBarState();
}

class _BoardAnnotationBarState extends State<BoardAnnotationBar> {
  /// Whether the [MarkingDensity.tight] bar's one colour button has opened
  /// the five. Forgotten (not carried across a mode change) the same way
  /// [BoardAnnotationController.pendingFrom] is — nothing here depends on it
  /// surviving, and starting closed is simplest to reason about.
  bool _colorMenuOpen = false;

  /// The style of a mode button, written as two whole styles rather than as
  /// one style made of ternaries.
  ///
  /// The pairing is the point: on the accent ground the foreground is
  /// `canvas`, and off it the foreground is `textPrimary` on the surface. Both
  /// are right, and the ternary version said so too — but it said it in four
  /// separate conditions, and anything reading this file (the contrast gate
  /// included) has to pair `background ? a : null` with `foreground ? b : c`
  /// by understanding that the two conditions are the same one. Written out,
  /// each branch carries its own pair and there is nothing to infer.
  ButtonStyle _labelledModeStyle(BuildContext context, {required bool active}) {
    if (active) {
      return OutlinedButton.styleFrom(
        backgroundColor: context.colors.accent,
        foregroundColor: context.colors.canvas,
        side: BorderSide(color: context.colors.accent),
        minimumSize: const Size(48, 48),
      );
    }
    return OutlinedButton.styleFrom(
      foregroundColor: context.colors.textPrimary,
      side: BorderSide(color: context.colors.border),
      minimumSize: const Size(48, 48),
    );
  }

  ButtonStyle _labelledMutedStyle(BuildContext context) {
    return OutlinedButton.styleFrom(
      foregroundColor: context.colors.textSecondary,
      side: BorderSide(color: context.colors.border),
      minimumSize: const Size(48, 48),
    );
  }

  /// A square icon button of exactly [size] — [MarkingDensity.compact] and
  /// [MarkingDensity.tight], which have no room for a label beside the icon.
  ButtonStyle _iconModeStyle(BuildContext context,
      {required bool active, required double size}) {
    if (active) {
      return OutlinedButton.styleFrom(
        backgroundColor: context.colors.accent,
        foregroundColor: context.colors.canvas,
        side: BorderSide(color: context.colors.accent),
        minimumSize: Size.square(size),
        maximumSize: Size.square(size),
        padding: EdgeInsets.zero,
      );
    }
    return OutlinedButton.styleFrom(
      foregroundColor: context.colors.textPrimary,
      side: BorderSide(color: context.colors.border),
      minimumSize: Size.square(size),
      maximumSize: Size.square(size),
      padding: EdgeInsets.zero,
    );
  }

  ButtonStyle _iconMutedStyle(BuildContext context, {required double size}) {
    return OutlinedButton.styleFrom(
      foregroundColor: context.colors.textSecondary,
      side: BorderSide(color: context.colors.border),
      minimumSize: Size.square(size),
      maximumSize: Size.square(size),
      padding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('annotation-bar'),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: widget.density == MarkingDensity.regular
          ? _labelledBar(context)
          : _iconBar(context),
    );
  }

  bool get _isArrow => widget.mode == AnnotationMode.arrow;
  bool get _isSquare => widget.mode == AnnotationMode.square;

  /// The Tutorial Studio's bar, unchanged in shape from before [density]
  /// existed — labelled buttons, a label under each icon.
  Widget _labelledBar(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        _Tip(
          message: 'Arrow',
          child: OutlinedButton.icon(
            key: const Key('annotate-arrow'),
            onPressed: widget.onArrowPressed,
            icon: const Icon(Icons.arrow_right_alt, size: 18),
            label: const Text('Arrow', style: AppText.body),
            style: _labelledModeStyle(context, active: _isArrow),
          ),
        ),
        _Tip(
          message: 'Square',
          child: OutlinedButton.icon(
            key: const Key('annotate-square'),
            onPressed: widget.onSquarePressed,
            icon: const Icon(Icons.crop_square, size: 18),
            label: const Text('Square', style: AppText.body),
            style: _labelledModeStyle(context, active: _isSquare),
          ),
        ),
        // Drawn only in square mode: a range of squares is the only thing it
        // can mean, and a control that is drawn where it cannot act is this
        // repository's most frequent mistake — a menu offering „Obriši ovu
        // varijantu" with nothing wired to it, a dialog tab handing its
        // result to a callback nobody passed.
        if (_isSquare)
          _Tip(
            message: 'Mark a line of squares — tap one end, then the other. '
                'Hold Shift instead, on a keyboard.',
            child: OutlinedButton.icon(
              key: const Key('annotate-range'),
              onPressed: widget.onRangePressed,
              icon: const Icon(Icons.linear_scale, size: 18),
              label: const Text('Line', style: AppText.body),
              style: _labelledModeStyle(context, active: widget.rangeMode),
            ),
          ),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final arrow in ArrowColor.all)
              ArrowColorButton(
                key: Key('annotate-color-${arrow.id}'),
                arrow: arrow,
                isSelected: widget.selectedColorCode == arrow.id,
                onTap: () => widget.onColorSelected(arrow.id),
              ),
          ],
        ),
        if (widget.onUndoPressed != null)
          _Tip(
            message: 'Undo',
            child: OutlinedButton.icon(
              key: const Key('annotate-undo'),
              onPressed: widget.onUndoPressed,
              icon: const Icon(Icons.undo, size: 18),
              label: const Text('Undo', style: AppText.body),
              style: _labelledMutedStyle(context),
            ),
          ),
        _Tip(
          message: 'Clear marks',
          child: OutlinedButton.icon(
            key: const Key('annotate-clear'),
            onPressed: widget.onClearPressed,
            icon: const Icon(Icons.layers_clear, size: 18),
            label: const Text('Clear marks', style: AppText.body),
            style: _labelledMutedStyle(context),
          ),
        ),
      ],
    );
  }

  /// [MarkingDensity.compact] and [MarkingDensity.tight]: the same controls
  /// as 40 dp icon buttons, their words in the tooltips rather than beside
  /// them, and either the five colours ([MarkingDensity.compact]) or the one
  /// button that opens them ([MarkingDensity.tight]).
  Widget _iconBar(BuildContext context) {
    const size = 40.0;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        _Tip(
          message: 'Arrow',
          child: OutlinedButton(
            key: const Key('annotate-arrow'),
            onPressed: widget.onArrowPressed,
            style: _iconModeStyle(context, active: _isArrow, size: size),
            child: const Icon(Icons.arrow_right_alt, size: 18),
          ),
        ),
        _Tip(
          message: 'Square',
          child: OutlinedButton(
            key: const Key('annotate-square'),
            onPressed: widget.onSquarePressed,
            style: _iconModeStyle(context, active: _isSquare, size: size),
            child: const Icon(Icons.crop_square, size: 18),
          ),
        ),
        if (_isSquare)
          _Tip(
            message: 'Line',
            child: OutlinedButton(
              key: const Key('annotate-range'),
              onPressed: widget.onRangePressed,
              style:
                  _iconModeStyle(context, active: widget.rangeMode, size: size),
              child: const Icon(Icons.linear_scale, size: 18),
            ),
          ),
        if (widget.density == MarkingDensity.tight)
          _colorMenuButton(context)
        else
          for (final arrow in ArrowColor.all)
            ArrowColorButton(
              key: Key('annotate-color-${arrow.id}'),
              arrow: arrow,
              isSelected: widget.selectedColorCode == arrow.id,
              onTap: () => widget.onColorSelected(arrow.id),
            ),
        if (widget.density == MarkingDensity.tight && _colorMenuOpen)
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final arrow in ArrowColor.all)
                ArrowColorButton(
                  key: Key('annotate-color-${arrow.id}'),
                  arrow: arrow,
                  isSelected: widget.selectedColorCode == arrow.id,
                  onTap: () {
                    widget.onColorSelected(arrow.id);
                    setState(() => _colorMenuOpen = false);
                  },
                ),
            ],
          ),
        if (widget.onUndoPressed != null)
          _Tip(
            message: 'Undo',
            child: OutlinedButton(
              key: const Key('annotate-undo'),
              onPressed: widget.onUndoPressed,
              style: _iconMutedStyle(context, size: size),
              child: const Icon(Icons.undo, size: 18),
            ),
          ),
        _Tip(
          message: 'Clear marks',
          child: OutlinedButton(
            key: const Key('annotate-clear'),
            onPressed: widget.onClearPressed,
            style: _iconMutedStyle(context, size: size),
            child: const Icon(Icons.layers_clear, size: 18),
          ),
        ),
      ],
    );
  }

  /// [MarkingDensity.tight]'s one colour button: the picked colour, with its
  /// letter, opening the five when tapped.
  Widget _colorMenuButton(BuildContext context) {
    final selected = ArrowColor.byId(widget.selectedColorCode);
    return _Tip(
      message: 'Colour: ${selected.name}',
      child: GestureDetector(
        key: const Key('annotate-color-menu'),
        onTap: () => setState(() => _colorMenuOpen = !_colorMenuOpen),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected.color,
            shape: BoxShape.circle,
            border: Border.all(color: context.colors.border),
          ),
          child: Text(
            ArrowColorButton.initialOf(selected),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: ChessBoardPainter.readableOn(selected.color),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tooltip with a semantics node of its own to hang from.
///
/// `Tooltip` around a button puts the popup's node **outside** the button's
/// own, so it hangs from whatever node encloses the bar. On Preparation that
/// is the node around the whole board column, and Flutter 3.47 does not
/// always send that node again when the popup arrives: measured on
/// 27.9.2026, „Square", „Undo" and „Clear marks" each sent a node no parent
/// listed — the update Windows refuses, and the crash of 20–22.9.2026 with a
/// screen reader attached. A container here is a parent that is always sent
/// with its popup. Held by `move_tree_semantics_orphan_test.dart`.
class _Tip extends StatelessWidget {
  const _Tip({required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        child: Tooltip(message: message, child: child),
      );
}
