part of 'tutorial_studio_screen.dart';

/// The Tutorial Studio on a phone — phase 6b of
/// `docs/PLAN-REORGANIZACIJA.md` §7, over the controller phase 6a extracted.
///
/// **One layout among several over one controller.** Everything here reads
/// `_c` and calls the screen's own wrappers (`_saveTutorial`, `_undo`,
/// `_onMove`, `_addShowSection`, …) — nothing here is a second copy of a rule
/// the desktop half of the screen already holds. What is this extension's
/// own: which of Line/Task/Parts is open ([_TutorialStudioScreenState._phoneTab])
/// and the two small stateful fields below it.
///
/// **What is not drawn here, on purpose:** the Flow panel, the Tree panel,
/// the PGN panel, the labels field and the language field. `docs/
/// PLAN-REORGANIZACIJA.md` §7 mentions the Tree as reachable through a
/// fullscreen dialog for reading; that door is not part of this phase's gate
/// (`test/tutorial_phone_layout_test.dart`) and is left for a later one.
extension _PhoneLayout on _TutorialStudioScreenState {
  Widget _buildPhone(BoxConstraints constraints) {
    final landscape = LandscapeBoardLayout.applies(context);
    return Scaffold(
      appBar: _phoneAppBar(),
      // The arrow keys drive the same cursor the strip's buttons do, here as
      // on the desktop: a phone rarely has them, a tablet with a keyboard
      // does, and `move_keys_everywhere_test` holds every screen with the
      // strip to it.
      body: MoveKeyboardShortcuts(
        cursor: _moveCursor(),
        // _jumpTo does its own redraw through the controller.
        onChanged: () {},
        child:
            landscape ? _phoneLandscapeBody() : _phonePortraitBody(constraints),
      ),
    );
  }

  // ── the app bar ───────────────────────────────────────────────────────

  /// The title, „Save" and everything the bar has no room for, behind
  /// [Key('phone-more')] — Undo, Redo, Discard changes, Preview tutorial,
  /// Record narration, Export video, Save as .pgn, Position setup. Every
  /// entry calls the same wrapper the desktop's app bar calls; none of it is
  /// written twice.
  PreferredSizeWidget _phoneAppBar() {
    return AppBar(
      toolbarHeight: LandscapeBoardLayout.toolbarHeight(context),
      title: TextField(
        key: const Key('phone-title'),
        controller: _titleController,
        style: AppText.title,
        decoration: const InputDecoration(
          hintText: 'Tutorial title',
          border: InputBorder.none,
          isDense: true,
        ),
        onChanged: _c.setTitle,
      ),
      actions: [
        IconButton(
          key: const Key('phone-save'),
          icon: const Icon(Icons.save_outlined),
          tooltip: 'Save tutorial',
          onPressed: _saveTutorial,
        ),
        PopupMenuButton<String>(
          key: const Key('phone-more'),
          tooltip: 'More',
          onSelected: (value) {
            switch (value) {
              case 'undo':
                _undo();
              case 'redo':
                _redo();
              case 'discard':
                _discardChanges();
              case 'preview':
                _previewAsStudent();
              case 'record':
                _recordNarration();
              case 'export-video':
                _exportVideo();
              case 'export-pgn':
                _exportPgn();
              case 'setup':
                _showSetupDialog();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'undo',
              enabled: _c.canUndo,
              child: const Text('Undo'),
            ),
            PopupMenuItem(
              value: 'redo',
              enabled: _c.canRedo,
              child: const Text('Redo'),
            ),
            PopupMenuItem(
              value: 'discard',
              enabled: _c.hasUnsavedChanges,
              child: const Text('Discard changes'),
            ),
            const PopupMenuItem(
              value: 'preview',
              child: Text('Preview tutorial'),
            ),
            const PopupMenuItem(
              value: 'record',
              child: Text('Record narration'),
            ),
            const PopupMenuItem(
              value: 'export-video',
              child: Text('Export video'),
            ),
            const PopupMenuItem(
              value: 'export-pgn',
              child: Text('Save as .pgn'),
            ),
            const PopupMenuItem(value: 'setup', child: Text('Position setup')),
          ],
        ),
        const SizedBox(width: AppSpacing.sm),
      ],
    );
  }

  // ── portrait ─────────────────────────────────────────────────────────

  /// The board, then Line | Task | Parts pinned, then the open tab's
  /// content — a `CustomScrollView` for the same reason the desktop's narrow
  /// branch is one: the strip must stay put while the tab under it scrolls.
  ///
  /// **The board's share of the height is smaller than half.** §7's sketch
  /// suggested `maxHeight * 0.5`, sized for a bare square; what actually
  /// stands under the tabs is the board plus the move strip
  /// ([_phoneBoardHeader]), and at 0.5 the two of them plus the tab strip
  /// filled a 360 × 640 window with nothing left for the Task tab's dropdown,
  /// its text field and one answer — all of it below the fold and untappable
  /// by centre, which is how `tester.tap` finds a widget. 0.34 was measured
  /// against that exact case: the dropdown, the field, one answer and „Add
  /// answer" all land on screen without a scroll.
  Widget _phonePortraitBody(BoxConstraints constraints) {
    final byWidth = constraints.maxWidth - 2 * AppSpacing.md;
    final byHeight = constraints.maxHeight * 0.34;
    final boardSize = byWidth < byHeight ? byWidth : byHeight;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            0,
          ),
          sliver: SliverToBoxAdapter(child: _phoneBoardHeader(boardSize)),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _PinnedEditorTabs(
            child: ColoredBox(
              color: context.colors.canvas,
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: _phoneTabs(),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          sliver: SliverToBoxAdapter(child: _phoneTabContent()),
        ),
      ],
    );
  }

  // ── landscape ────────────────────────────────────────────────────────

  /// The board on the left, taking the whole height `LandscapeBoardLayout`
  /// gives it, with the move strip pinned under the panels; the tab strip
  /// pinned at the top of the right column and the open tab's content
  /// scrolling under it. Draw is reached inside the Line tab, beside the
  /// comment field — see [_phoneLineTab] — not as permanent chrome: on a
  /// 360-wide board the annotation bar wraps to more than one row, and
  /// stacked under the board (as [_boardColumn] draws it on the desktop) it
  /// alone would fill the screen this layout is given.
  Widget _phoneLandscapeBody() {
    return LandscapeBoardLayout(
      board: (side) => BoardWithCoordinates(
        size: side,
        orientation: _orientation,
        builder: _chessBoard,
      ),
      header: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: _phoneTabs(),
      ),
      panels: _phoneTabContent(),
      footer: [
        MoveNavigationControls(
          cursor: _moveCursor(),
          centerLabel: null,
          iconSize: 20,
          onFlipBoard: _flipBoard,
        ),
      ],
    );
  }

  /// The board and the move strip — no annotation bar, see
  /// [_phoneLandscapeBody] for why. Dense throughout, not only in landscape:
  /// a phone's width is the same problem in portrait, and the full-size strip
  /// measured 72 dp against the 48 the dense one needs.
  Widget _phoneBoardHeader(double boardSize) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _boardCard(boardSize),
        SizedBox(
          width: boardSize,
          child: MoveNavigationControls(
            cursor: _moveCursor(),
            centerLabel: null,
            iconSize: 20,
            dense: true,
            onFlipBoard: _flipBoard,
          ),
        ),
      ],
    );
  }

  // ── the tab strip, shared by both orientations ──────────────────────

  Widget _phoneTabs() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _tabButton(
          key: const Key('phone-tab-line'),
          label: 'Line',
          isSelected: _phoneTab == 0,
          onTap: () => _selectPhoneTab(0),
        ),
        const SizedBox(width: AppSpacing.xs),
        _tabButton(
          key: const Key('phone-tab-task'),
          label: 'Task',
          isSelected: _phoneTab == 1,
          onTap: () => _selectPhoneTab(1),
        ),
        const SizedBox(width: AppSpacing.xs),
        _tabButton(
          key: const Key('phone-tab-parts'),
          label: 'Parts',
          isSelected: _phoneTab == 2,
          onTap: () => _selectPhoneTab(2),
        ),
      ],
    );
  }

  Widget _phoneTabContent() {
    return switch (_phoneTab) {
      0 => _phoneLineTab(),
      1 => _phoneTaskTab(),
      _ => _phonePartsTab(),
    };
  }

  // ── Line ─────────────────────────────────────────────────────────────

  /// The comment on the beat the trainer is standing on, the two moves that
  /// touch a single move — insert a line, delete this one, the desktop's
  /// Flow card carries both and the phone has no Flow to put them in
  /// instead — and the drawing bar: with no room for it as permanent chrome
  /// (see [_phoneLandscapeBody]), it is part of the tab that is about the
  /// line being drawn on.
  Widget _phoneLineTab() {
    final current = _c.cursor;
    final isRoot = identical(current, _c.root);
    final heading = isRoot
        ? 'Comment on the starting position'
        : 'Comment on ${current.moveNumberLabel}${current.moveSan}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(heading, style: AppText.bodyBold),
        const SizedBox(height: AppSpacing.xs),
        _PhoneCommentField(
          key: ValueKey('phone-comment-${current.id}'),
          node: current,
          onChanged: (text) => _c.setComment(current, text, typing: true),
        ),
        const SizedBox(height: AppSpacing.sm),
        BoardAnnotationBar(
          mode: _annotationController.mode,
          selectedColorCode: _annotationController.colorCode,
          onArrowPressed: _toggleArrowMode,
          onSquarePressed: _toggleSquareMode,
          onColorSelected: _selectColor,
          onClearPressed: _clearMarks,
          rangeMode: _annotationController.rangeMode,
          onRangePressed: _toggleRangeMode,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            if (canSplitForLine(_c.section))
              OutlinedButton(
                onPressed: _insertLine,
                child: const Text('Insert a line here'),
              ),
            if (!isRoot)
              OutlinedButton(
                onPressed: () => _deleteNode(current),
                child: const Text('Delete this move'),
              ),
          ],
        ),
      ],
    );
  }

  // ── Task ─────────────────────────────────────────────────────────────

  /// The kind, its text and its answers — the desktop's `_questionCard`,
  /// mirrored rather than shared: that card carries the keys the desktop's
  /// own tests reach it by.
  Widget _phoneTaskTab() {
    final section = _c.section;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyedSubtree(
          key: ValueKey('phone-kind-$_fieldsEpoch'),
          child: DropdownButtonFormField<LessonStepKind>(
            key: const Key('phone-task-kind'),
            initialValue: section.kind,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Task type'),
            items: const [
              DropdownMenuItem(
                value: LessonStepKind.show,
                child: Text('Show only'),
              ),
              DropdownMenuItem(
                value: LessonStepKind.askMove,
                child: Text('Ask for move on board'),
              ),
              DropdownMenuItem(
                value: LessonStepKind.askChoice,
                child: Text('Ask for answer from list'),
              ),
            ],
            onChanged: _chooseKind,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (section.kind != LessonStepKind.show) ...[
          TextField(
            key: const Key('phone-task-text'),
            controller: _instructionController,
            decoration: const InputDecoration(labelText: 'Task for student'),
            onChanged: _c.setInstruction,
            maxLines: null,
            keyboardType: TextInputType.multiline,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (section.kind == LessonStepKind.askMove &&
            section.solutionSan != null)
          Text('Correct move: ${section.solutionSan}'),
        if (section.kind == LessonStepKind.askChoice) ...[
          Text('Offered answers', style: AppText.bodyBold),
          RadioGroup<int>(
            groupValue: _c.correctChoice,
            onChanged: _c.setCorrectChoice,
            child: Column(
              children: [
                for (var i = 0; i < _choiceControllers.length; i++)
                  Row(
                    children: [
                      Radio<int>(value: i),
                      Expanded(
                        child: TextField(
                          key: Key('phone-choice-$i'),
                          controller: _choiceControllers[i],
                          onChanged: (text) => _c.setChoiceText(i, text),
                        ),
                      ),
                      IconButton(
                        key: Key('phone-choice-delete-$i'),
                        icon: const Icon(Icons.delete),
                        onPressed: () => _removeChoiceField(i),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          ElevatedButton(
            key: const Key('phone-add-answer'),
            onPressed: _addChoiceField,
            child: const Text('Add answer'),
          ),
        ],
      ],
    );
  }

  // ── Parts ────────────────────────────────────────────────────────────

  Widget _phonePartsTab() {
    final sections = _c.draft.sections;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(alignment: Alignment.centerLeft, child: _phoneNewPartButton()),
        const SizedBox(height: AppSpacing.sm),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sections.length,
          itemBuilder: (context, i) => _phonePartRow(i, sections[i]),
        ),
      ],
    );
  }

  /// The next part, of one of three kinds — the same three doors the
  /// desktop's sections panel draws as buttons, behind one menu because
  /// three buttons do not fit a 360 dp row.
  Widget _phoneNewPartButton() {
    return PopupMenuButton<String>(
      key: const Key('phone-new-part'),
      tooltip: 'New part',
      onSelected: (value) {
        switch (value) {
          case 'show':
            _addShowSection();
          case 'move':
            _askHere(LessonStepKind.askMove);
          case 'choice':
            _askHere(LessonStepKind.askChoice);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'show', child: Text('New demonstration')),
        PopupMenuItem(value: 'move', child: Text('Find the move')),
        PopupMenuItem(value: 'choice', child: Text('Choose the answer')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: AppRadii.roundedSm,
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 18, color: context.colors.accent),
            const SizedBox(width: AppSpacing.xs),
            const Text('New part'),
          ],
        ),
      ),
    );
  }

  /// One row of the list — kind icon, title, moves count, and the five
  /// actions in a [Wrap] under it: a row of five 48 dp buttons beside the
  /// title does not fit a 360 dp screen, which is why they are here rather
  /// than as `ListTile.trailing`.
  ///
  /// **The actions sit outside the `ListTile`, not in its `subtitle`.** They
  /// did once — `tester.tap` finds a widget by its key and taps its
  /// *centre*, and a `ListTile` tall enough to hold a moves count and a
  /// five-button `Wrap` puts that centre over the second button, „Clone
  /// part". A tap meant to select part 0 cloned it instead, leaving the
  /// trainer on a part they never asked for. Keeping the `ListTile` to the
  /// leading icon, the title and the moves count keeps its centre over
  /// something that only selects.
  Widget _phonePartRow(int i, TutorialSection section) {
    final count = _mainLineMoveCount(section);
    final last = _c.draft.sections.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: Key('phone-part-$i'),
          leading: Icon(_phoneKindIcon(section.kind)),
          title: Text(section.label(i)),
          subtitle: Text('$count ${count == 1 ? 'move' : 'moves'}'),
          selected: i == _c.draft.selected,
          onTap: () => _c.select(i),
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.sm,
            bottom: AppSpacing.xs,
          ),
          child: Wrap(
            spacing: AppSpacing.xs,
            children: [
              IconButton(
                tooltip: 'Move up',
                icon: const Icon(Icons.arrow_upward),
                onPressed: i > 0 ? () => _moveSection(i, i - 1) : null,
              ),
              IconButton(
                tooltip: 'Move down',
                icon: const Icon(Icons.arrow_downward),
                onPressed: i < last ? () => _moveSection(i, i + 1) : null,
              ),
              IconButton(
                tooltip: 'Clone part',
                icon: const Icon(Icons.copy),
                onPressed: () => _cloneSection(i),
              ),
              IconButton(
                tooltip: 'Rename',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _renameSection(i),
              ),
              IconButton(
                tooltip: 'Delete part',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _removeSection(i),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _phoneKindIcon(LessonStepKind kind) => switch (kind) {
        LessonStepKind.show => Icons.visibility_outlined,
        LessonStepKind.askMove => Icons.help_outline,
        LessonStepKind.askChoice => Icons.list_alt,
      };

  /// The main line's length, in moves — [endOfMainLine] finds where it ends,
  /// this counts the steps it took to get there.
  int _mainLineMoveCount(TutorialSection section) {
    var count = 0;
    var node = section.root;
    while (node.children.isNotEmpty) {
      node = node.children.first;
      count++;
    }
    return count;
  }
}

/// The comment field for one node on the phone — a `StatefulWidget` for the
/// reason `_CommentDialog` above is one: the controller has to belong to
/// something that goes away with the node it was seeded from, not to a
/// build method that runs again under the caret. Keyed by the node's id in
/// [_PhoneLayout._phoneLineTab], so a new node gets a fresh instance rather
/// than this one's text.
class _PhoneCommentField extends StatefulWidget {
  const _PhoneCommentField({
    super.key,
    required this.node,
    required this.onChanged,
  });

  final AnalysisNode node;
  final ValueChanged<String> onChanged;

  @override
  State<_PhoneCommentField> createState() => _PhoneCommentFieldState();
}

class _PhoneCommentFieldState extends State<_PhoneCommentField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.node.comment,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('phone-comment'),
      controller: _controller,
      minLines: 2,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      onChanged: widget.onChanged,
    );
  }
}
