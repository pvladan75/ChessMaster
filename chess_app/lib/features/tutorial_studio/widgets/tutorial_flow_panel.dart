import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_beat.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// The timeline of a tutorial part in the order the child meets it, and the
/// surface it is written on.
///
/// It decides nothing: it projects [root] and [current] through [beatsOf],
/// draws one card per **beat** — a position may hold several (D4 of
/// `docs/PLAN-PRIPREMA.md`) — reports every selection through [onSelect] and
/// every edited sentence through [onCommentChanged]. The screen owns the
/// cursor, which beat of it is open, and the board.
///
/// A position's later sentences are drawn as cards under its first, indented,
/// so they read as belonging to it rather than as their own stops on the
/// line.
///
/// The one piece of state here is a card's own [TextEditingController] and
/// [FocusNode], keyed by the node's id and the beat's index so that a card
/// built for one sentence is never left on screen holding another's.
class TutorialFlowPanel extends StatelessWidget {
  const TutorialFlowPanel({
    super.key,
    required this.root,
    required this.current,
    this.currentAt = 0,
    required this.onSelect,
    required this.onCommentChanged,
    this.onDelete,
    this.onInsertLine,
    this.partsStartingHere = const {},
    this.onOpenPart,
    this.onAddSentence,
    this.onRemoveSentence,
  });

  final AnalysisNode root;
  final AnalysisNode current;

  /// Which of [current]'s beats is open.
  final int currentAt;

  final void Function(AnalysisNode node, int at) onSelect;
  final void Function(AnalysisNode node, int at, String text) onCommentChanged;

  /// Takes back the move that arrived at a position, with everything under
  /// it. Drawn on the position's first card only — the move belongs to the
  /// position, not to any one of its sentences.
  final void Function(AnalysisNode)? onDelete;

  /// „Insert a line here" — cut the part at the current beat and start a new
  /// line from it (phase 3 of `docs/PLAN-STUDIO-ISTORIJA.md`).
  ///
  /// Drawn on the current beat only, because „here" is where the trainer is
  /// standing, and only when given: the screen passes none when the part has
  /// no line to cut.
  final VoidCallback? onInsertLine;

  /// The later parts that go back to a beat of this one, by the beat's node
  /// id — drawn on that position's last card as „Part 4 starts here ·
  /// 18... h6". Phase 3 of `docs/PLAN-MAPA-DELOVA.md`: the other end of the
  /// map's dashed edge.
  final Map<String, List<({int part, String move})>> partsStartingHere;

  /// Opens part [index] (0-based). Null draws no chip.
  final void Function(int index)? onOpenPart;

  /// „Add a sentence here", after the open one — drawn on the open card only.
  final VoidCallback? onAddSentence;

  /// Removes one of a position's sentences — drawn on every card of a
  /// position that has more than one.
  final void Function(AnalysisNode node, int at)? onRemoveSentence;

  @override
  Widget build(BuildContext context) {
    final beats = beatsOf(root, current, currentAt: currentAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < beats.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xs),
          _BeatCard(
            // The beat itself, not its position — inserting or removing a
            // sentence shifts every later one's `at`, and a key built from
            // that would hand a rebuilt card's state to a sentence that is
            // not the one it was holding (rule 6: a helper that sets state
            // must be provable, and a `TextEditingController` reused across
            // two different beats is exactly the fault this guards against).
            key: ObjectKey(beats[i].say),
            beat: beats[i],
            onSelect: onSelect,
            onCommentChanged: onCommentChanged,
            onDelete: onDelete,
            onInsertLine: onInsertLine,
            partsStartingHere: partsStartingHere[beats[i].node.id] ?? const [],
            onOpenPart: onOpenPart,
            onAddSentence: onAddSentence,
            onRemoveSentence: onRemoveSentence,
          ),
        ],
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
    this.partsStartingHere = const [],
    this.onOpenPart,
    this.onAddSentence,
    this.onRemoveSentence,
  });

  final TutorialBeat beat;
  final void Function(AnalysisNode, int) onSelect;
  final void Function(AnalysisNode, int, String) onCommentChanged;
  final void Function(AnalysisNode)? onDelete;
  final VoidCallback? onInsertLine;
  final List<({int part, String move})> partsStartingHere;
  final void Function(int index)? onOpenPart;
  final VoidCallback? onAddSentence;
  final void Function(AnalysisNode, int)? onRemoveSentence;

  @override
  State<_BeatCard> createState() => _BeatCardState();
}

class _BeatCardState extends State<_BeatCard> {
  late final TextEditingController _controller;

  /// Held by the card rather than by the field.
  ///
  /// The field's own `Key` changes the moment this card becomes the current
  /// one — `example-sentence` is the current beat's field and
  /// `beat-comment-<index>[.<at>]` is every other — and a changed key
  /// unmounts the element. A `TextField` that builds its own `FocusNode`
  /// therefore loses the caret exactly when the trainer clicks into another
  /// card's sentence to write it: the click selects the beat, the field is
  /// rebuilt under the new key, and the typing goes nowhere. Owned here, the
  /// node outlives that rebuild. No test could see this — `enterText` focuses
  /// the field itself.
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.beat.say.comment);
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
    final isFirst = beat.at == 0;
    final isLastBeat = beat.at == beat.of - 1;
    final hasMultiple = beat.of > 1;
    final keySuffix = isFirst ? '${beat.index}' : '${beat.index}.${beat.at}';
    final headerText =
        beat.index == 0 ? 'Starting position' : 'after ${beat.arrivedLabel}';

    final card = Material(
      key: Key('beat-$keySuffix'),
      color: beat.isCurrent
          ? context.colors.surfaceRaised
          : context.colors.surface,
      borderRadius: AppRadii.roundedMd,
      child: InkWell(
        borderRadius: AppRadii.roundedMd,
        onTap: () => widget.onSelect(beat.node, beat.at),
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
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            headerText,
                            style: (beat.isCurrent
                                    ? AppText.bodyBold
                                    : AppText.body)
                                .copyWith(
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ),
                        if (hasMultiple) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '${beat.at + 1} of ${beat.of}',
                            style: AppText.caption.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
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
                  if (isFirst &&
                      widget.onDelete != null &&
                      beat.arrivedBy != null)
                    IconButton(
                      key: Key('beat-delete-${beat.index}'),
                      icon: const Icon(Icons.backspace_outlined, size: 16),
                      color: context.colors.textMuted,
                      tooltip: 'Delete this move',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => widget.onDelete!(beat.node),
                    ),
                  if (hasMultiple && widget.onRemoveSentence != null)
                    IconButton(
                      key: Key('remove-sentence-${beat.index}.${beat.at}'),
                      icon: const Icon(Icons.close, size: 16),
                      color: context.colors.textMuted,
                      tooltip: 'Remove this sentence',
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          widget.onRemoveSentence!(beat.node, beat.at),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                key: beat.isCurrent
                    ? const Key('example-sentence')
                    : Key('beat-comment-$keySuffix'),
                controller: _controller,
                focusNode: _focus,
                // The label says „trenutni", and it is true of exactly one
                // card. Beside the timeline there was one field and the word
                // was right; on several cards, only one of them would claim
                // to be the sentence the trainer is standing on. The header
                // of each card already says which move and which sentence it
                // is about, so the other cards carry the field without a
                // label — and the label becomes one more non-colour mark of
                // where the author is.
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
                // An empty field two lines high on every card pushes what
                // follows below the fold of the scrolling half — a control a
                // trainer cannot press is a worse problem than the one being
                // fixed, and it is the same trap batch 58 lost a round to.
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                onTap: () {
                  if (!beat.isCurrent) {
                    widget.onSelect(beat.node, beat.at);
                  }
                },
                onChanged: (val) =>
                    widget.onCommentChanged(beat.node, beat.at, val),
              ),
              if (beat.isCurrent && widget.onAddSentence != null) ...[
                const SizedBox(height: AppSpacing.xs),
                OutlinedButton(
                  key: const Key('add-sentence'),
                  onPressed: widget.onAddSentence,
                  child: const Text('Add a sentence here'),
                ),
              ],
              if (isLastBeat) ...[
                if (widget.onOpenPart != null &&
                    widget.partsStartingHere.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final later in widget.partsStartingHere)
                        ActionChip(
                          key: Key('part-starts-here-${later.part + 1}'),
                          avatar: const Icon(Icons.subdirectory_arrow_right,
                              size: 16),
                          label: Text(
                            later.move.isEmpty
                                ? 'Part ${later.part + 1} starts here'
                                : 'Part ${later.part + 1} starts here · '
                                    '${later.move}',
                            style: AppText.body
                                .copyWith(color: context.colors.textPrimary),
                          ),
                          onPressed: () => widget.onOpenPart!(later.part),
                        ),
                    ],
                  ),
                ],
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
                          onPressed: () => widget.onSelect(branch.node, 0),
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
            ],
          ),
        ),
      ),
    );

    if (isFirst) return card;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.lg),
      child: card,
    );
  }
}
