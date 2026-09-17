import 'package:flutter/material.dart';

import 'package:chess_app/features/library/models/library_entry.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// One list of everything a user keeps — phase 3 of
/// `docs/PLAN-REORGANIZACIJA.md` (S3).
///
/// Six shelves lived in five places; this widget is the one place. It draws
/// only what it is given (rule 15): the entries, a row of kind chips, a search
/// field, and a row per entry with whatever [actionsFor] hands back for it.
/// Fetching, opening and deleting are the caller's — `LibraryScreen` on Home
/// and, in 3b, the room's left column — so the same list can sit under two
/// different sets of actions without knowing either.
///
/// The chips are frozen here; the manual quotes them.
class LibraryList extends StatefulWidget {
  const LibraryList({
    super.key,
    required this.entries,
    required this.onOpen,
    this.actionsFor,
    this.initialChip,
  });

  final List<LibraryEntry> entries;

  /// Tapping a row.
  final void Function(LibraryEntry entry) onOpen;

  /// The trailing controls of one row — a tutorial's send and video, a
  /// recording's play. Null draws none.
  final List<Widget> Function(LibraryEntry entry)? actionsFor;

  /// Which chip is selected when the list opens; null is „All".
  final LibraryChip? initialChip;

  static const String searchHint = 'Search';
  static const String empty = 'Nothing here yet.';

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
        .where((e) => _chip.shows(e))
        .where((e) => query.isEmpty || e.title.toLowerCase().contains(query))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final chip in LibraryChip.values)
              ChoiceChip(
                label: Text(chip.label),
                selected: _chip == chip,
                onSelected: (_) => setState(() => _chip = chip),
              ),
          ],
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
        Expanded(
          child: shown.isEmpty
              ? Center(
                  child: Text(
                    LibraryList.empty,
                    style: AppText.body.copyWith(color: colors.textSecondary),
                  ),
                )
              : ListView.builder(
                  itemCount: shown.length,
                  itemBuilder: (context, index) {
                    final entry = shown[index];
                    final actions = widget.actionsFor?.call(entry) ?? const [];
                    return ListTile(
                      leading: Icon(_iconFor(entry.kind), color: colors.accent),
                      title: Text(entry.title),
                      subtitle: Text(_subtitleFor(entry)),
                      trailing: actions.isEmpty
                          ? null
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: actions,
                            ),
                      onTap: () => widget.onOpen(entry),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
