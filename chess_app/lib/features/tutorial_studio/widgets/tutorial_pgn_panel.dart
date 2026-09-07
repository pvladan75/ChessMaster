import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/theme/arrow_colors.dart';

/// The open part as PGN text, and the text as a surface to write on.
///
/// T2 of `docs/PLAN-PGN-TEKST.md`. Two things it is for, and the second is the
/// larger: some edits are text edits — deleting one arrow is deleting eleven
/// characters — and until this tab the app had **no door** for an annotated
/// line produced anywhere else. The only PGN import goes through
/// `AnalysisStudioScreen._importPgn`, which keeps the main line and throws away
/// every comment, every `[%cal]`, every `[%csl]` and every variation, so a game
/// annotated in a book, by an engine or by a language model could not enter a
/// tutorial except by being replayed move by move and retyped.
///
/// **It decides nothing.** It holds the text the trainer is editing and reports
/// it when they press „Primeni"; the screen owns the tree, and what a text
/// comes to is decided by `LessonStepLine` — the one reader, the child's.
///
/// **Applied, not parsed as it is typed.** Half a written move is not a valid
/// PGN, and a live parse would empty the part while somebody types in it.
class TutorialPgnPanel extends StatefulWidget {
  const TutorialPgnPanel({
    super.key,
    required this.pgn,
    required this.onApply,
  });

  /// The part's text as the tree exports it.
  ///
  /// When it changes underneath — a move played on the board, an arrow drawn,
  /// another part selected — the field follows it, **unless** the trainer has
  /// unapplied edits in front of them. Their text is not something to
  /// overwrite because something else moved.
  final String pgn;

  final void Function(String text) onApply;

  @override
  State<TutorialPgnPanel> createState() => _TutorialPgnPanelState();
}

class _TutorialPgnPanelState extends State<TutorialPgnPanel> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.pgn);

  bool get _dirty => _controller.text != widget.pgn;

  @override
  void didUpdateWidget(TutorialPgnPanel old) {
    super.didUpdateWidget(old);
    // Only when the trainer has nothing of their own in the field: `_dirty` is
    // measured against the *previous* text, which is what makes this safe.
    if (widget.pgn != old.pgn && _controller.text == old.pgn) {
      _controller.text = widget.pgn;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// What the tags mean, and which letter is which colour.
  ///
  /// Generated from [ArrowColor.all] rather than written out: the picker was
  /// once a hand-written list of four while the catalogue held five, and the
  /// fifth could not be chosen by anybody for months. A legend that drifts from
  /// the palette is the same fault wearing a different coat.
  String get _legend {
    final colours = ArrowColor.all
        .map((c) => '${c.id} ${c.name.toLowerCase()}')
        .join(' · ');
    return '[%cal Gd2d4] strelica · [%csl Rd5] polje · $colours';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('pgn-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _legend,
          style: AppText.caption.copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          key: const Key('pgn-field'),
          controller: _controller,
          minLines: 6,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          style: AppText.body.copyWith(fontFamily: 'monospace'),
          decoration: const InputDecoration(border: OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            FilledButton(
              key: const Key('pgn-apply'),
              onPressed: () => widget.onApply(_controller.text),
              child: const Text('Primeni'),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _dirty ? 'izmenjeno' : 'primenjeno',
              key: const Key('pgn-state'),
              style: AppText.caption.copyWith(
                color: _dirty
                    ? context.colors.warning
                    : context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
