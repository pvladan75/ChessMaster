import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/models/pgn_span.dart';

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
    required this.export,
    required this.currentNodeId,
    required this.onApply,
    required this.onCaretMoved,
    required this.onDrawArrow,
    required this.onMarkSquare,
    required this.onEditComment,
  });

  /// The part's text, and where each node's move and comment sit inside it.
  ///
  /// When it changes underneath — a move played on the board, an arrow drawn,
  /// another part selected — the field follows it, **unless** the trainer has
  /// unapplied edits in front of them. Their text is not something to
  /// overwrite because something else moved.
  final PgnWithSpans export;

  /// Where the cursor is, so the caret can be put on the same move.
  final String? currentNodeId;

  final void Function(String text) onApply;

  /// The trainer put the caret inside a move: that move becomes the cursor.
  final void Function(String nodeId) onCaretMoved;

  /// The three things the right-click menu offers, each for the node the caret
  /// is in. The first two hand the work to the board, which is where drawing
  /// already lives.
  final void Function(String nodeId) onDrawArrow;
  final void Function(String nodeId) onMarkSquare;
  final void Function(String nodeId) onEditComment;

  String get pgn => export.pgn;

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
    // The cursor moved somewhere else — a beat card, the move strip, a move
    // played — so the caret follows it onto the same move. Never while the
    // trainer has unapplied text: the offsets describe the exported text, not
    // theirs, and moving a caret in text somebody is writing is worse than not
    // moving it at all.
    if (!_dirty && widget.currentNodeId != old.currentNodeId) {
      _putCaretOn(widget.currentNodeId);
    }
  }

  void _putCaretOn(String? nodeId) {
    if (nodeId == null) return;
    final span = widget.export.spans
        .where((s) => s.nodeId == nodeId && s.kind == PgnSpanKind.move)
        .firstOrNull;
    if (span == null) return;
    _controller.selection =
        TextSelection(baseOffset: span.start, extentOffset: span.end);
  }

  /// The node the caret is in, or null where the caret is in nobody's text.
  String? get _nodeUnderCaret {
    final offset = _controller.selection.baseOffset;
    if (offset < 0 || _dirty) return null;
    return widget.export.nodeIdAt(offset);
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
    return '[%cal Gd2d4] arrow · [%csl Rd5] square · $colours';
  }

  /// Tells the screen which move the caret landed in.
  ///
  /// One cursor, three surfaces: „Tok", „Stablo" and this. Clicking a move here
  /// is the same act as clicking a beat card — the board goes to that position
  /// and anything drawn on it lands on that node.
  void _reportCaret() {
    final id = _nodeUnderCaret;
    if (id != null) widget.onCaretMoved(id);
  }

  /// The standard menu plus the three things this tab is for.
  ///
  /// They are offered only where the caret is in a move: the whitespace between
  /// two moves belongs to neither, and a menu that wrote onto whichever move
  /// was nearest would be worse than no menu. And only while the text is what
  /// the writer wrote — the offsets describe that text, so on edited text they
  /// point at nothing anybody can trust.
  Widget _menu(BuildContext context, EditableTextState state) {
    final id =
        widget.export.nodeIdAt(state.textEditingValue.selection.baseOffset);
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: [
        ...state.contextMenuButtonItems,
        if (id != null && !_dirty) ...[
          ContextMenuButtonItem(
            label: 'Add arrow',
            onPressed: () {
              ContextMenuController.removeAny();
              widget.onDrawArrow(id);
            },
          ),
          ContextMenuButtonItem(
            label: 'Mark square',
            onPressed: () {
              ContextMenuController.removeAny();
              widget.onMarkSquare(id);
            },
          ),
          ContextMenuButtonItem(
            label: 'Add comment',
            onPressed: () {
              ContextMenuController.removeAny();
              widget.onEditComment(id);
            },
          ),
        ],
      ],
    );
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
          onTap: _reportCaret,
          contextMenuBuilder: _menu,
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            FilledButton(
              key: const Key('pgn-apply'),
              onPressed: () => widget.onApply(_controller.text),
              child: const Text('Apply'),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _dirty ? 'edited' : 'applied',
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
