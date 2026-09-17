import 'package:flutter/material.dart';

import 'package:chess_app/features/library/models/library_entry.dart';

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
  @override
  Widget build(BuildContext context) {
    // Phase 3a builds this. The seam exists so the gate compiles and fails on
    // what it asserts, not on a missing file.
    return const SizedBox.shrink();
  }
}
