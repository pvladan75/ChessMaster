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
/// **What is not drawn here, on purpose:** the Flow panel, the Tree panel and
/// the PGN panel. `docs/PLAN-REORGANIZACIJA.md` §7 mentions the Tree as
/// reachable through a fullscreen dialog for reading; that door is not part of
/// this phase's gate (`test/tutorial_phone_layout_test.dart`) and is left for a
/// later one.
///
/// The labels and the language were left out too, until the owner's report of
/// 20.9.2026 („U portret orjentaciji ne vide se label i jezik tutorijala"): a
/// tutorial made on a phone had nothing the Library could find it by and no
/// language to choose its voice. They are behind „More" → „Details…"
/// ([_showDetails], which the desktop's bar opens too since phase 4 of
/// `docs/PLAN-MAPA-DELOVA.md`) — the same two fields, not copies.
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
  /// [Key('phone-more')] — Undo, Redo, Discard changes,
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
              case 'details':
                _showDetails();
              case 'undo':
                _undo();
              case 'redo':
                _redo();
              case 'discard':
                _discardChanges();
              case 'record':
                _recordNarration();
              case 'export-video':
                _exportVideo();
              case 'export-pgn':
                _exportPgn();
              case 'parts-add':
                _addPartsFromTutorial();
              case 'parts-extract':
                _extractPartsToNewTutorial();
              case 'setup':
                _showSetupDialog();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'details',
              child: Text('Details…'),
            ),
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
            // The two doors onto other tutorials. On the desktop they are a
            // menu of their own in the bar; here they join the one menu this
            // layout already has, because a phone bar holds a title, one save
            // and „more" and nothing else has ever fitted beside them.
            //
            // They are drawn here rather than left out because a feature that
            // exists on one layout and not the other is a feature a trainer
            // finds once and then cannot find again.
            const PopupMenuItem(
              value: 'parts-add',
              child: Text('Add parts from a tutorial…'),
            ),
            const PopupMenuItem(
              value: 'parts-extract',
              child: Text('Take parts into a new tutorial…'),
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
        // The same row as in portrait, and for the same reason: this layout
        // has no Flow, Tree or PGN panel either.
        _phoneMoveList(),
        MoveNavigationControls(
          cursor: _moveCursor(),
          centerLabel: null,
          iconSize: 20,
          onFlipBoard: _flipBoard,
        ),
      ],
    );
  }

  /// The board, the line it is standing in, and the move strip — no annotation
  /// bar, see [_phoneLandscapeBody] for why. Dense throughout, not only in
  /// landscape: a phone's width is the same problem in portrait, and the
  /// full-size strip measured 72 dp against the 48 the dense one needs.
  Widget _phoneBoardHeader(double boardSize) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _boardCard(boardSize),
        SizedBox(width: boardSize, child: _phoneMoveList()),
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

  /// The moves of the open part, in the order the reader meets them, as one
  /// scrolling row.
  ///
  /// **Reported live on 18.9.2026** against TODO-provera 179.2: „Ne vidim
  /// traku poteza", and asked about, „mislio sam da nema Flow/Tree/PGN panel".
  /// The four arrows were drawn, and they were all there was: this layout
  /// leaves out the Flow, the Tree and the PGN panel, so a trainer could build
  /// a line on a phone and never read it back — they could only walk it one
  /// move at a time and remember. A phone has no room for the desktop's card
  /// per beat, and does not need one: what is missing here is *where am I and
  /// what did I write*, which a row of moves answers.
  ///
  /// It is [beatsOf] behind it, the same projection the Flow panel draws, so
  /// the two cannot disagree about what the line is. A beat carrying a comment
  /// gets an underline — the one thing about a move a trainer cannot see on
  /// the board.
  Widget _phoneMoveList() {
    final beats = beatsOf(_c.root, _c.cursor);
    return _PhoneMoveList(
      key: const Key('phone-move-list'),
      beats: beats,
      onSelect: _jumpTo,
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
        // „Task" went with the parts that asked something
        // (docs/PLAN-TUTORIJAL-VIDEO.md, phase 4): every part shows.
        _tabButton(
          key: const Key('phone-tab-parts'),
          label: 'Parts',
          isSelected: _phoneTab == 1,
          onTap: () => _selectPhoneTab(1),
        ),
      ],
    );
  }

  Widget _phoneTabContent() {
    return switch (_phoneTab) {
      0 => _phoneLineTab(),
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

  // ── Parts ────────────────────────────────────────────────────────────

  Widget _phonePartsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(alignment: Alignment.centerLeft, child: _phoneNewPartButton()),
        const SizedBox(height: AppSpacing.sm),
        // The open part's actions, above the map — the same row the
        // desktop's header draws ([_openPartActions]). They were under every
        // row until the map (phase 3 of `docs/PLAN-MAPA-DELOVA.md`): the lanes
        // run through the gutter from one row to the next, and a row of
        // buttons under each part breaks every edge that crosses it. „Turn
        // this part" stays on each row.
        Wrap(spacing: AppSpacing.xs, children: _openPartActions()),
        const SizedBox(height: AppSpacing.xs),
        TutorialPartsMap(
          draft: _c.draft,
          onSelect: _selectSection,
          scrollable: false,
          rowKey: (i) => Key('phone-part-$i'),
          trailing: (i) => IconButton(
            key: Key('turn-part-$i'),
            tooltip: _c.draft.sections[i].blackOrientation
                ? 'Turn this part (Black at the bottom now)'
                : 'Turn this part (White at the bottom now)',
            icon: const Icon(Icons.screen_rotation_alt),
            onPressed: () => _turnPart(i),
          ),
        ),
      ],
    );
  }

  /// The next part — a new demonstration, the same door the desktop's
  /// sections panel draws.
  Widget _phoneNewPartButton() {
    return OutlinedButton.icon(
      key: const Key('phone-new-part'),
      onPressed: _addShowSection,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('New demonstration'),
    );
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

/// The scrolling row of moves under the board — see
/// [_PhoneLayout._phoneMoveList] for why it exists.
///
/// Stateful only to keep the current beat in view: a trainer twenty moves deep
/// would otherwise be looking at move 1 while the board shows move 20, which is
/// the same "I cannot see where I am" the row was added for. The scroll is
/// asked for after the frame the row is laid out in, because before that there
/// is nothing to scroll.
class _PhoneMoveList extends StatefulWidget {
  const _PhoneMoveList(
      {super.key, required this.beats, required this.onSelect});

  final List<TutorialBeat> beats;
  final void Function(AnalysisNode) onSelect;

  @override
  State<_PhoneMoveList> createState() => _PhoneMoveListState();
}

class _PhoneMoveListState extends State<_PhoneMoveList> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _currentKey = GlobalKey();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Brings the current beat into the middle of **this** row and nothing else.
  ///
  /// `Scrollable.ensureVisible` walks up every scrollable above the widget, and
  /// this row lives inside the portrait layout's `CustomScrollView`: it
  /// centred the chip in the *page* as well, dragging the board up the screen
  /// on every move played. Asking this row's own position moves this row's own
  /// offset and leaves the page where the trainer put it.
  void _keepCurrentInView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final box = _currentKey.currentContext?.findRenderObject();
      if (box == null) return;
      _scroll.position.ensureVisible(
        box,
        alignment: 0.5,
        duration: const Duration(milliseconds: 180),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    _keepCurrentInView();
    final colors = context.colors;

    return SizedBox(
      height: 34,
      child: ListView.separated(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        itemCount: widget.beats.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xxs),
        itemBuilder: (context, i) {
          final beat = widget.beats[i];
          final node = beat.node;
          // The opening position is a position, not a move, and the trainer
          // comments on it like any other beat — so it is in the row, named.
          final label = node.isRoot
              ? 'Start'
              : '${node.moveNumberLabel}${node.moveSan ?? ''}'.trim();
          final hasComment = node.comment.trim().isNotEmpty;

          return Padding(
            key: beat.isCurrent ? _currentKey : null,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: InkWell(
              key: Key('phone-move-$i'),
              onTap: () => widget.onSelect(node),
              borderRadius: AppRadii.roundedSm,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                decoration: BoxDecoration(
                  color: beat.isCurrent
                      ? colors.accent.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: AppRadii.roundedSm,
                  border: Border.all(
                    color: beat.isCurrent ? colors.accent : colors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: AppText.body.copyWith(
                        color: beat.isCurrent
                            ? colors.textPrimary
                            : colors.textSecondary,
                        fontWeight:
                            beat.isCurrent ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                    // A comment is the one thing about a beat the board cannot
                    // show, so it is the one thing marked here.
                    if (hasComment) ...[
                      const SizedBox(width: AppSpacing.xxs),
                      Icon(Icons.chat_bubble,
                          size: 10, color: colors.textMuted),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
