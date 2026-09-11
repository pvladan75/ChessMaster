import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_beat.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// The timeline of a tutorial part in the order the child meets it, and the
/// surface it is written on.
///
/// It decides nothing: it projects [root] and [current] through [beatsOf],
/// draws one card per beat, reports every selection through [onSelect] and
/// every edited sentence through [onCommentChanged], and draws the [question]
/// the screen hands it under the last beat. The screen owns the cursor, the
/// board, and everything the question card shows — a part's kind, task and
/// answers are per *part*, and a panel that held them would have a model.
///
/// The one piece of state here is a card's own [TextEditingController] and
/// [FocusNode], keyed by `beat.node.id` so that a card built for one node is
/// never left on screen holding another node's sentence.
class TutorialFlowPanel extends StatelessWidget {
  const TutorialFlowPanel({
    super.key,
    required this.root,
    required this.current,
    required this.onSelect,
    required this.onCommentChanged,
    required this.question,
    this.onDelete,
    this.onInsertLine,
  });

  final AnalysisNode root;
  final AnalysisNode current;
  final void Function(AnalysisNode) onSelect;
  final void Function(AnalysisNode, String) onCommentChanged;
  final Widget question;

  /// Takes back the move that arrived at a beat, with everything under it.
  ///
  /// Optional, and drawn only on the beats that *are* a move — the opening
  /// position of a part is not one, and there is a different action for
  /// throwing that away. The screen owns what deleting means, including
  /// whether to ask first; this only says which move was pointed at.
  final void Function(AnalysisNode)? onDelete;

  /// „Insert a line here" — cut the part at the current beat and start a new
  /// line from it (phase 3 of `docs/PLAN-STUDIO-ISTORIJA.md`).
  ///
  /// Drawn on the current beat only, because „here" is where the trainer is
  /// standing, and only when given: the screen passes none when the part has
  /// no line to cut.
  final VoidCallback? onInsertLine;

  @override
  Widget build(BuildContext context) {
    final beats = beatsOf(root, current);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < beats.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xs),
          _BeatCard(
            key: ValueKey(beats[i].node.id),
            beat: beats[i],
            onSelect: onSelect,
            onCommentChanged: onCommentChanged,
            onDelete: onDelete,
            onInsertLine: onInsertLine,
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        question,
      ],
    );
  }
}

class _BeatCard extends StatefulWidget {
  const _BeatCard({
    super.key,
    required this.beat,
    required this.onSelect,
    required this.onCommentChanged,
    this.onDelete,
    this.onInsertLine,
  });

  final TutorialBeat beat;
  final void Function(AnalysisNode) onSelect;
  final void Function(AnalysisNode, String) onCommentChanged;
  final void Function(AnalysisNode)? onDelete;
  final VoidCallback? onInsertLine;

  @override
  State<_BeatCard> createState() => _BeatCardState();
}

class _BeatCardState extends State<_BeatCard> {
  late final TextEditingController _controller;

  /// Held by the card rather than by the field.
  ///
  /// The field's own `Key` changes the moment this card becomes the current
  /// one — `example-sentence` is the current beat's field and
  /// `beat-comment-<index>` is every other — and a changed key unmounts the
  /// element. A `TextField` that builds its own `FocusNode` therefore loses
  /// the caret exactly when the trainer clicks into another card's sentence
  /// to write it: the click selects the beat, the field is rebuilt under the
  /// new key, and the typing goes nowhere. Owned here, the node outlives that
  /// rebuild. No test could see this — `enterText` focuses the field itself.
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.beat.node.comment);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final beat = widget.beat;
    final headerText =
        beat.index == 0 ? 'Starting position' : 'after ${beat.arrivedLabel}';

    return Material(
      key: Key('beat-${beat.index}'),
      color: beat.isCurrent
          ? context.colors.surfaceRaised
          : context.colors.surface,
      borderRadius: AppRadii.roundedMd,
      child: InkWell(
        borderRadius: AppRadii.roundedMd,
        onTap: () => widget.onSelect(beat.node),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: AppRadii.roundedMd,
            border: Border.all(
              color: beat.isCurrent
                  ? context.colors.borderStrong
                  : context.colors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (beat.isCurrent) ...[
                    Icon(
                      Icons.radio_button_checked,
                      key: const Key('beat-current'),
                      size: 16,
                      color: context.colors.accent,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Expanded(
                    child: Text(
                      headerText,
                      style: (beat.isCurrent ? AppText.bodyBold : AppText.body)
                          .copyWith(
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                  // The move that arrived here, taken back from the surface
                  // the tutorial is written on. Until 7.9.2026 the only place
                  // a move could be deleted was the „PGN" tab, by retyping the
                  // line — the tree's own menu drew the action and did
                  // nothing.
                  if (widget.onInsertLine != null && beat.isCurrent)
                    IconButton(
                      key: const Key('insert-line'),
                      icon: const Icon(Icons.alt_route, size: 16),
                      color: context.colors.textMuted,
                      tooltip: 'Insert a line here',
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.onInsertLine,
                    ),
                  if (widget.onDelete != null && beat.arrivedBy != null)
                    IconButton(
                      key: Key('beat-delete-${beat.index}'),
                      icon: const Icon(Icons.backspace_outlined, size: 16),
                      color: context.colors.textMuted,
                      tooltip: 'Delete this move',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => widget.onDelete!(beat.node),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                key: beat.isCurrent
                    ? const Key('example-sentence')
                    : Key('beat-comment-${beat.index}'),
                controller: _controller,
                focusNode: _focus,
                // The label says „trenutni", and it is true of exactly one
                // card. Beside the timeline there was one field and the word
                // was right; on four cards, three of them would claim to be
                // the move the trainer is standing on. The header of each card
                // („posle 1. e4") already says which move its sentence is
                // about, so the other cards carry the field without a label —
                // and the label becomes one more non-colour mark of where the
                // author is.
                decoration: beat.isCurrent
                    ? const InputDecoration(
                        labelText: 'Comment for current move',
                      )
                    : null,
                // Wrapped, not scrolled sideways. A single-line field shows
                // the *end* of a long sentence and hides where it began, so a
                // trainer rereading what they wrote sees the tail of it — and
                // these sentences are read out to a child, which makes them
                // longer than a label.
                //
                // It grows with the text rather than starting two lines tall.
                // An empty field two lines high on every card pushes the
                // question card and „Dodaj odgovor" under it below the fold of
                // the scrolling half — a control a trainer cannot press is a
                // worse problem than the one being fixed, and it is the same
                // trap batch 58 lost a round to.
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                onTap: () {
                  if (!beat.isCurrent) {
                    widget.onSelect(beat.node);
                  }
                },
                onChanged: (val) => widget.onCommentChanged(beat.node, val),
              ),
              if (beat.branches.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final branch in beat.branches)
                      ActionChip(
                        backgroundColor: branch.taken
                            ? context.colors.surfaceRaised
                            : context.colors.surface,
                        side: BorderSide(
                          color: branch.taken
                              ? context.colors.accent
                              : context.colors.border,
                        ),
                        label: Text(
                          branch.label,
                          style:
                              (branch.taken ? AppText.bodyBold : AppText.body)
                                  .copyWith(
                            color: branch.taken
                                ? context.colors.textPrimary
                                : context.colors.textSecondary,
                          ),
                        ),
                        onPressed: () => widget.onSelect(branch.node),
                      ),
                  ],
                ),
              ] else if (!beat.isLast && beat.playsLabel != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'then plays: ${beat.playsLabel}',
                  style: AppText.caption.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
