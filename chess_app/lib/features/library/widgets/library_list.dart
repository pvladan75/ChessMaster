import 'package:flutter/material.dart';

import 'package:chess_app/features/exercises/models/exercise_task_words.dart';
import 'package:chess_app/features/library/models/exercise_filter.dart';
import 'package:chess_app/features/library/models/library_entry.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/adaptive_card_grid.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';
import 'package:chess_app/widgets/matrix_filter_panel.dart';

import 'board_preview_dialog.dart';

/// One list of everything a user keeps — phase 3 of
/// `docs/PLAN-REORGANIZACIJA.md` (S3).
///
/// Six shelves lived in five places; this widget is the one place. It draws
/// only what it is given (rule 15): the entries, a row of kind chips, a search
/// field, and a row per entry with whatever [actionsFor] hands back for it.
/// Fetching, opening and deleting are the caller's — `LibraryScreen` on Teach
/// and, since 3b, the room's left column — so the same list can sit under two
/// different sets of actions without knowing either.
///
/// The chips are frozen here; the manual quotes them. The column brought
/// three needs of its own (phase 3b): only the chips for what can go on a
/// board, a split by who keeps the row, and the label filter it already had —
/// which is why the filter's home is here and not on either screen.
class LibraryList extends StatefulWidget {
  const LibraryList({
    super.key,
    required this.entries,
    required this.onOpen,
    this.actionsFor,
    this.initialChip,
    this.chips = LibraryChip.values,
    this.originChips = false,
    this.labels = const [],
    this.shrinkWrap = false,
    this.initialFromTrainer,
    this.onNewExercise,
    this.onSelect,
    this.selectedId,
  });

  final List<LibraryEntry> entries;

  /// Tapping a row.
  final void Function(LibraryEntry entry) onOpen;

  /// The trailing controls of one row — a tutorial's send and video, a
  /// recording's play. Null draws none.
  final List<Widget> Function(LibraryEntry entry)? actionsFor;

  /// Which chip is selected when the list opens; null is „All".
  final LibraryChip? initialChip;

  /// The kind chips to draw, in order. „All" shows the union of the others
  /// given, so a column that lists only what can go on a board never shows a
  /// recording under All. The Library screen passes the six; the room three.
  final List<LibraryChip> chips;

  /// Draw [mine] and [fromTrainer], which split the list by
  /// [LibraryEntry.fromTrainer]. A student in a room reads their trainer's
  /// material beside their own; a trainer alone has no use for the two.
  final bool originChips;

  /// The labels this user has used. Non-empty draws the label panel, which
  /// filters by [LibraryEntry.themes] — include, exclude, all-or-any — the
  /// way the room's column did over the wire until 3b.
  final List<String> labels;

  /// Take only the height the rows need, for a column that scrolls as a
  /// whole. The default fills what it is given, which inside a
  /// SingleChildScrollView is nothing at all.
  final bool shrinkWrap;

  /// Which of [mine] and [fromTrainer] is selected when the list opens; null
  /// is neither, so everyone's rows show. Only read with [originChips].
  final bool? initialFromTrainer;

  /// „New exercise" under the Exercises chip — a door to Preparation, where
  /// the sheet that makes one lives (`docs/PLAN-EXERCISE.md`, phase 4). Null
  /// draws nothing: the room's column has no use for it, only the Library
  /// screen does.
  final VoidCallback? onNewExercise;

  /// Tapping a card's board, when the caller has somewhere to put it.
  ///
  /// Null — the room's column, and the Library on a narrow window — keeps the
  /// dialog this list has always opened (rule 15: a widget draws only what it
  /// was given). Given, the board goes to the caller instead, which is how
  /// phase 5 of `docs/PLAN-LISTE.md` puts it in a pane beside the shelf
  /// rather than over it.
  final void Function(LibraryEntry entry)? onSelect;

  /// Which card is drawn as chosen, as [idOf] spells it. Null draws none.
  final String? selectedId;

  /// Which card is which, in one place.
  ///
  /// The kind belongs in it: ids come from different tables, so a position 12
  /// and a tutorial 12 both exist, and an id alone would draw the chosen mark
  /// on whichever of them the list happened to reach first. This is the same
  /// string the row's key is built from, so „which card is this" has one
  /// answer (rule 12).
  static String idOf(LibraryEntry entry) => '${entry.kind.name}-${entry.id}';

  /// The board on a card, and it is 48 rather than 56 because of what a
  /// `ListTile` does to its leading slot.
  ///
  /// The slot is laid out with `maxHeight = 56 + visualDensity.dy`, and
  /// `ThemeData` uses `adaptivePlatformDensity`, which is **compact on every
  /// desktop** — so on Windows and macOS the slot allows 48 of height while
  /// the board took its width from 56. Measured 20.9.2026: `56.0 x 48.0` on
  /// Windows and macOS, `56.0 x 56.0` on Android. Eight ranks sized from the
  /// width drew into 48 px and the bottom one was clipped, in silence — a
  /// widget drawing outside its own box raises nothing, in test or release,
  /// because clipping is not overflow.
  ///
  /// `Center` does not help here, unlike the panes: the slot imposes a *max
  /// height*, so the board has to ask for a size that fits it. 48 is the
  /// number both densities allow, and it makes the two platforms agree.
  ///
  /// Found by the owner's eye on the Repertoire pane, which had the same
  /// fault in a different shape, and then by sweeping every board in `lib/`.
  static const double thumbnailSize = 48;

  /// Below this height the filters scroll with the list rather than above it.
  static const double headerScrollsBelow = 480;

  /// One card, top to bottom — phase 3b of `docs/PLAN-LISTE.md`.
  ///
  /// Taken from the tallest card this list can draw: a `ListTile` led by a
  /// 56 px board thumbnail, with a line of four action buttons under it. A
  /// card with fewer actions, or none, is the same height — that is what a
  /// grid is, and it is why the content sits at the top of the card rather
  /// than being spread over it.
  ///
  /// Until 20.9.2026 this widget had an `actionsBesideFrom = 480` instead:
  /// beside that width the actions were the tile's `trailing`, under it they
  /// went on a line of their own. A card is never wider than
  /// [AdaptiveCardGrid.maxTileWidth], which is 420, so the wide branch could
  /// no longer be reached and the constant went with it.
  static const double cardHeight = 132;

  static const String searchHint = 'Search';
  static const String empty = 'Nothing here yet.';
  static const String mine = 'Mine';
  static const String fromTrainer = 'From trainer';

  @override
  State<LibraryList> createState() => _LibraryListState();
}

/// The chips, in the order they are drawn.
///
/// Until 18.9.2026 „Positions" held both a position saved from a board and
/// one read out of a book — „one kind to the reader", with the source on the
/// row. **Superseded the same day** (`docs/PLAN-EXERCISE.md`, decision 2, as
/// amended when phase 4 was briefed): a trainer does not send a position,
/// they send an exercise, so a scan is now told apart as [exercises] and
/// [positions] narrows to a bare board.
enum LibraryChip {
  all('All', null),
  tutorials('Tutorials', {LibraryKind.tutorial}),
  exercises('Exercises', {LibraryKind.scan}),
  positions('Positions', {LibraryKind.position}),
  analyses('Analyses', {LibraryKind.analysis}),
  recordings('Recordings', {LibraryKind.recording}),
  puzzleSets('Puzzle sets', {LibraryKind.puzzleSet});

  const LibraryChip(this.label, this.kinds);

  final String label;

  /// The kinds the chip shows; null shows every kind.
  final Set<LibraryKind>? kinds;

  /// [kinds] is what the chip can hold; this is what it shows. The two part
  /// company over a scan: one with something to judge is an exercise, one
  /// without is a position (`LibraryEntry.isExercise`).
  bool shows(LibraryEntry entry) => switch (this) {
        LibraryChip.exercises => entry.isExercise,
        LibraryChip.positions => entry.kind == LibraryKind.position ||
            (entry.kind == LibraryKind.scan && !entry.isExercise),
        _ => kinds == null || kinds!.contains(entry.kind),
      };
}

class _LibraryListState extends State<LibraryList> {
  late LibraryChip _chip = widget.initialChip ?? LibraryChip.all;
  final TextEditingController _search = TextEditingController();

  /// null is everyone; true only the trainer's rows; false only mine.
  late bool? _fromTrainer =
      widget.originChips ? widget.initialFromTrainer : null;

  List<String> _include = const [];
  List<String> _exclude = const [];
  String _matchMode = 'all';

  /// The Exercises chip's two filters — single-choice, clearable, and never
  /// drawn under any other chip.
  ExerciseAsk? _ask;
  ExerciseOrigin? _origin;

  /// What „All" means here: every kind one of the given chips shows.
  Set<LibraryKind> get _allKinds => {
        for (final chip in widget.chips)
          if (chip.kinds != null) ...chip.kinds!,
      };

  bool _kindShown(LibraryEntry entry) {
    if (_chip != LibraryChip.all) return _chip.shows(entry);
    return _allKinds.isEmpty || _allKinds.contains(entry.kind);
  }

  bool _originShown(LibraryEntry entry) =>
      _fromTrainer == null || entry.fromTrainer == _fromTrainer;

  bool _labelsShown(LibraryEntry entry) {
    if (_include.isEmpty && _exclude.isEmpty) return true;
    final themes = entry.themes.toSet();
    if (_exclude.any(themes.contains)) return false;
    if (_include.isEmpty) return true;
    return _matchMode == 'all'
        ? _include.every(themes.contains)
        : _include.any(themes.contains);
  }

  bool _searchShown(LibraryEntry entry, String query) =>
      query.isEmpty ||
      entry.title.toLowerCase().contains(query) ||
      entry.themes.any((t) => t.toLowerCase().contains(query));

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The line under the title: what kind of thing this is, in the trainer's
  /// terms — not `entry.subtitle`, whose wording serves the picker dialog
  /// rather than this row.
  String _subtitleFor(LibraryEntry entry) {
    switch (entry.kind) {
      case LibraryKind.tutorial:
        final parts = '${entry.partsCount ?? 0} parts';
        return entry.hasVideo ? '$parts · video' : parts;
      case LibraryKind.scan:
        // An exercise's subtitle starts with what it asks; the source (book,
        // page) rides after it when there is one.
        // A scan with nothing to judge asks nothing: its source alone.
        final source = entry.subtitle;
        if (!entry.isExercise) {
          return source.isEmpty ? 'scanned position' : source;
        }
        final words = exerciseTaskWords(entry.task);
        return source.isEmpty ? words : '$words · $source';
      case LibraryKind.position:
        return 'saved position';
      case LibraryKind.analysis:
        return 'analysis';
      case LibraryKind.recording:
        final d = entry.createdAt;
        return d == null ? '' : '${d.day}.${d.month}.${d.year}';
      case LibraryKind.puzzleSet:
        return 'puzzle set';
    }
  }

  IconData _iconFor(LibraryKind kind) => switch (kind) {
        LibraryKind.scan => Icons.menu_book_outlined,
        LibraryKind.position => Icons.push_pin_outlined,
        LibraryKind.analysis => Icons.biotech_outlined,
        LibraryKind.tutorial => Icons.auto_stories_outlined,
        LibraryKind.recording => Icons.videocam_outlined,
        LibraryKind.puzzleSet => Icons.extension_outlined,
      };

  void _previewBoard(BuildContext context, LibraryEntry entry) {
    showDialog<void>(
      context: context,
      builder: (_) => BoardPreviewDialog(
        entry: entry,
        onOpen: () => widget.onOpen(entry),
      ),
    );
  }

  /// A position or an exercise leads with its board — decision 3 of
  /// `docs/PLAN-EXERCISE.md`: a list of boards shows the boards. Every other
  /// kind keeps its icon. 64 piece widgets per row in a long list, so each
  /// one gets its own [RepaintBoundary].
  Widget _leadingFor(BuildContext context, LibraryEntry entry) {
    if (entry.kind != LibraryKind.scan && entry.kind != LibraryKind.position) {
      return Icon(_iconFor(entry.kind), color: context.colors.accent);
    }
    return RepaintBoundary(
      child: GestureDetector(
        // Over the list, or beside it. The caller decides by whether it gave
        // this list anywhere to put a board; nothing here asks how wide the
        // screen is, which is why the room's column keeps its dialog inside a
        // window that is plenty wide enough for a pane.
        onTap: () => widget.onSelect == null
            ? _previewBoard(context, entry)
            : widget.onSelect!(entry),
        child: BoardThumbnail(
          fen: entry.fen,
          size: LibraryList.thumbnailSize,
          isWhiteBottom: entry.task?['side'] != 'b',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final query = _search.text.trim().toLowerCase();
    final kindFiltered = widget.entries
        .where(_kindShown)
        .where(_originShown)
        .where(_labelsShown)
        .where((e) => _searchShown(e, query))
        .toList();
    // Drawn and read only under the Exercises chip — elsewhere the two
    // fields stay set but unused, so switching chips and back does not lose
    // what was chosen.
    final shown = _chip == LibraryChip.exercises
        ? filterExercises(kindFiltered, ask: _ask, origin: _origin)
        : kindFiltered;

    return LayoutBuilder(builder: (context, constraints) {
      final compact = widget.shrinkWrap ||
          constraints.maxHeight < LibraryList.headerScrollsBelow;
      final list = shown.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  LibraryList.empty,
                  style: AppText.body.copyWith(color: colors.textSecondary),
                ),
              ),
            )
          // Cards in a grid, not rows in a list — phase 3b of
          // `docs/PLAN-LISTE.md`. The column count is never written down
          // here: `AdaptiveCardGrid` works it out from the constraint this
          // widget is handed, which is why the room's 300 px column gets one
          // card across without being asked which screen it is on, and why
          // the phone is unchanged.
          : AdaptiveCardGrid(
              itemCount: shown.length,
              tileHeight: LibraryList.cardHeight,
              shrinkWrap: compact,
              physics: compact ? const NeverScrollableScrollPhysics() : null,
              // The two callers already pad their own side of the screen.
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                final entry = shown[index];
                final actions = widget.actionsFor?.call(entry) ?? const [];
                final chosen = widget.selectedId != null &&
                    widget.selectedId == LibraryList.idOf(entry);
                return KeyedSubtree(
                  key: ValueKey('library-row-${LibraryList.idOf(entry)}'),
                  child: Card(
                    // An outline, not a tint. The owner's live sign-off reads
                    // luminance and shape and never hue, so „this is the one
                    // you are looking at" is said with a border that is there
                    // or is not, rather than with a wash of accent colour
                    // that a colour-blind reader cannot tell from the card
                    // beside it.
                    shape: chosen
                        ? AppRadii.cardShape.copyWith(
                            side: BorderSide(color: colors.accent, width: 2))
                        : AppRadii.cardShape,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ListTile(
                          leading: _leadingFor(context, entry),
                          title: Text(entry.title,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(_subtitleFor(entry),
                              overflow: TextOverflow.ellipsis),
                          onTap: () => widget.onOpen(entry),
                        ),
                        // Under the tile, not in its subtitle: a tap lands on
                        // a widget's centre, and a tile tall enough to hold a
                        // row of buttons puts its centre on one of them — the
                        // phone layout of phase 6b learned that on „Clone
                        // part".
                        if (actions.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 56, bottom: 4),
                            child: Wrap(children: actions),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );

      final column = Column(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final chip in widget.chips)
                ChoiceChip(
                  label: Text(chip.label),
                  selected: _chip == chip,
                  onSelected: (_) => setState(() => _chip = chip),
                ),
              if (widget.originChips) ...[
                FilterChip(
                  label: const Text(LibraryList.mine),
                  selected: _fromTrainer == false,
                  onSelected: (on) =>
                      setState(() => _fromTrainer = on ? false : null),
                ),
                FilterChip(
                  label: const Text(LibraryList.fromTrainer),
                  selected: _fromTrainer == true,
                  onSelected: (on) =>
                      setState(() => _fromTrainer = on ? true : null),
                ),
              ],
            ],
          ),
          // Only under the Exercises chip: „New exercise" and the two
          // filters. `Wrap` on a phone so neither pushes the list off the
          // screen (CLAUDE.md's release-build overflow lesson).
          if (_chip == LibraryChip.exercises) ...[
            const SizedBox(height: 8),
            if (widget.onNewExercise != null)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const Key('library-new-exercise'),
                  onPressed: widget.onNewExercise,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New exercise'),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final ask in ExerciseAsk.values)
                  ChoiceChip(
                    label: Text(ask.label),
                    selected: _ask == ask,
                    onSelected: (on) => setState(() => _ask = on ? ask : null),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final origin in ExerciseOrigin.values)
                  ChoiceChip(
                    label: Text(origin.label),
                    selected: _origin == origin,
                    onSelected: (on) =>
                        setState(() => _origin = on ? origin : null),
                  ),
              ],
            ),
          ],
          if (widget.labels.isNotEmpty)
            MatrixFilterPanel(
              availableUserLabels: widget.labels,
              selectedIncludeTags: _include,
              selectedExcludeTags: _exclude,
              filterMatchMode: _matchMode,
              onFilterChanged: (include, exclude, mode) => setState(() {
                _include = include;
                _exclude = exclude;
                _matchMode = mode;
              }),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: LibraryList.searchHint,
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
          const SizedBox(height: 8),
          if (compact) list else Expanded(child: list),
        ],
      );
      // Below [headerScrollsBelow] the chips, the label panel and the search
      // box scroll away with the rows instead of standing over them: on a
      // phone held sideways (640 × 360) they took the whole height.
      return (compact && !widget.shrinkWrap)
          ? SingleChildScrollView(child: column)
          : column;
    });
  }
}
