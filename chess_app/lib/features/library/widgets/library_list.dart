import 'package:flutter/material.dart';

import 'package:chess_app/features/library/models/library_entry.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/matrix_filter_panel.dart';

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

  /// Below this width a row's actions go on a line of their own under its
  /// title. Beside it, four 48 dp buttons left a title on a phone no width
  /// at all — the owner's screenshot of 17.9.2026 showed rows of icons and
  /// no names.
  static const double actionsBesideFrom = 480;

  /// Below this height the filters scroll with the list rather than above it.
  static const double headerScrollsBelow = 480;

  static const String searchHint = 'Search';
  static const String empty = 'Nothing here yet.';
  static const String mine = 'Mine';
  static const String fromTrainer = 'From trainer';

  @override
  State<LibraryList> createState() => _LibraryListState();
}

/// The chips, in the order they are drawn. „Positions" holds both a position
/// saved from a board and one read out of a book — one kind to the reader,
/// with the source on the row.
enum LibraryChip {
  all('All', null),
  tutorials('Tutorials', {LibraryKind.tutorial}),
  positions('Positions', {LibraryKind.position, LibraryKind.scan}),
  analyses('Analyses', {LibraryKind.analysis}),
  recordings('Recordings', {LibraryKind.recording}),
  puzzleSets('Puzzle sets', {LibraryKind.puzzleSet});

  const LibraryChip(this.label, this.kinds);

  final String label;

  /// The kinds the chip shows; null shows every kind.
  final Set<LibraryKind>? kinds;

  bool shows(LibraryEntry entry) =>
      kinds == null || kinds!.contains(entry.kind);
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
        return entry.subtitle;
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final query = _search.text.trim().toLowerCase();
    final shown = widget.entries
        .where(_kindShown)
        .where(_originShown)
        .where(_labelsShown)
        .where((e) => _searchShown(e, query))
        .toList();

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
          : LayoutBuilder(
              builder: (context, constraints) {
                final beside =
                    constraints.maxWidth >= LibraryList.actionsBesideFrom;
                return ListView.builder(
                  shrinkWrap: compact,
                  physics:
                      compact ? const NeverScrollableScrollPhysics() : null,
                  itemCount: shown.length,
                  itemBuilder: (context, index) {
                    final entry = shown[index];
                    final actions = widget.actionsFor?.call(entry) ?? const [];
                    final tile = ListTile(
                      leading: Icon(_iconFor(entry.kind), color: colors.accent),
                      title: Text(entry.title, overflow: TextOverflow.ellipsis),
                      subtitle: Text(_subtitleFor(entry)),
                      trailing: (beside && actions.isNotEmpty)
                          ? Row(
                              mainAxisSize: MainAxisSize.min, children: actions)
                          : null,
                      onTap: () => widget.onOpen(entry),
                    );
                    return KeyedSubtree(
                      key: ValueKey(
                          'library-row-${entry.kind.name}-${entry.id}'),
                      child: (beside || actions.isEmpty)
                          ? tile
                          // Under the tile, not in its subtitle: a tap lands on
                          // a widget's centre, and a tile tall enough to hold a
                          // row of buttons puts its centre on one of them —
                          // the phone layout of phase 6b learned that on
                          // „Clone part".
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                tile,
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 56, bottom: 4),
                                  child: Wrap(children: actions),
                                ),
                              ],
                            ),
                    );
                  },
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
