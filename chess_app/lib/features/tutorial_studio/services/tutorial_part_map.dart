/// The parts of a tutorial as a map — phase 3 of `docs/PLAN-MAPA-DELOVA.md`.
///
/// Rows in film order, lanes on the left (D3): top to bottom is the film, and
/// the lanes are how the parts join. A part that **continues** hangs from the
/// one before it by a solid edge; a part that **goes back** hangs by a dashed
/// edge from the beat that last showed its position; a **new board** hangs
/// from nothing and is drawn as a square rather than a circle. Nothing here is
/// told apart by colour — the owner reads luminance and shape.
///
/// **It reads the film's own answer** ([partOpeningsOf] over [filmBeatsOf]),
/// never a second one: the contents list used to compare positions itself
/// (`_isJoined`), knew „continues" and never „goes back", and said so with a
/// link icon. Two definitions of „the same position" are how two screens come
/// to disagree about one tutorial.
library;

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_video.dart';

/// Where a part hangs from: a part, and a beat of its line (0 is its start).
typedef PartSource = ({int part, int beat});

/// One row of the map.
class PartMapEntry {
  const PartMapEntry({
    required this.part,
    required this.entry,
    required this.from,
    required this.afterMove,
    required this.lane,
    required this.moves,
  });

  /// Which part, 0-based. The screen says it 1-based.
  final int part;

  final PartEntry entry;

  /// The part and beat it hangs from; null on a new board.
  final PartSource? from;

  /// On a return, the move that last arrived at the position — „18. Rfe1".
  /// Null when the position was only ever shown as some part's start.
  final String? afterMove;

  /// Which lane of the gutter its marker stands in, 0 on the left.
  final int lane;

  /// Its line on one line — „17. Bg5 Nxe5 18. Rfe1 cxd4", empty for a part
  /// that is only a position.
  final String moves;

  /// How it opens, in words: „new board", „continues", „back to after
  /// 18. Rfe1".
  String get kind => switch (entry) {
        PartEntry.fresh => 'new board',
        PartEntry.continues => 'continues',
        PartEntry.returns => afterMove != null
            ? 'back to after $afterMove'
            : 'back to the start of part ${from!.part + 1}',
      };

  /// What the row says ahead of the part's name: „4 · back to after 18. Rfe1".
  String get rowText => '${part + 1} · $kind';
}

/// One edge between two rows: a continuation (solid) or a return (dashed).
class PartMapEdge {
  const PartMapEdge({
    required this.fromRow,
    required this.toRow,
    required this.lane,
    required this.dashed,
  });

  final int fromRow;
  final int toRow;

  /// The lane it runs down, which is its target's lane.
  final int lane;

  /// A return; a continuation is solid.
  final bool dashed;
}

/// The whole map.
class PartMap {
  const PartMap({required this.entries, required this.edges});

  final List<PartMapEntry> entries;
  final List<PartMapEdge> edges;

  int get laneCount => entries.isEmpty
      ? 1
      : entries.map((e) => e.lane).reduce((a, b) => a > b ? a : b) + 1;

  /// What one row's slice of the gutter draws — the whole map, cut at the
  /// row's edges, so a list that builds only the rows on screen still draws
  /// every edge that crosses them.
  PartGutter gutterOf(int row, {required bool open}) {
    final at = entries[row];
    return PartGutter(
      markerLane: at.lane,
      square: at.entry == PartEntry.fresh,
      open: open,
      through: [
        for (final e in edges)
          if (e.fromRow < row && row < e.toRow)
            (lane: e.lane, dashed: e.dashed),
      ],
      arriving: [
        for (final e in edges)
          if (e.toRow == row) (lane: e.lane, dashed: e.dashed),
      ],
      leaving: [
        for (final e in edges)
          if (e.fromRow == row) (lane: e.lane, dashed: e.dashed),
      ],
    );
  }
}

/// A run of an edge inside one row: which lane, and whether it is dashed.
typedef GutterRun = ({int lane, bool dashed});

/// What the painter of one row is given, and all it is given — so what it
/// draws is asserted on this and not on pixels.
class PartGutter {
  const PartGutter({
    required this.markerLane,
    required this.square,
    required this.open,
    required this.through,
    required this.arriving,
    required this.leaving,
  });

  final int markerLane;

  /// A new board is a square; every other marker a circle.
  final bool square;

  /// The part being written: a filled marker with a ring round it.
  final bool open;

  /// Edges passing this row from top to bottom.
  final List<GutterRun> through;

  /// Edges ending at this row's marker, from the top.
  final List<GutterRun> arriving;

  /// Edges leaving this row's marker, across to their lane and down.
  final List<GutterRun> leaving;
}

/// [draft]'s parts as a map.
///
/// **Lanes.** A continuation takes its source's lane. A new board and a return
/// take the lowest lane that no marker uses on any row strictly between the
/// source's row and their own — so no edge ever passes a marker on the lane it
/// runs down — and a return into the **middle** of a part (neither its first
/// beat nor its last) takes at least its source's lane + 1, so it is drawn to
/// the right of the part it leaves.
///
/// **Two edges never share a lane past a row, and nothing has to keep track of
/// it.** An edge runs down its target's lane, so the target's marker holds that
/// lane; any later edge that passes a row the first one passes starts above its
/// target and ends below it, so it passes that marker too. A set of „lanes held
/// by edges" was built first and survived its own mutation — it could never
/// change an answer.
PartMap partMapOf(TutorialDraft draft) {
  final stops = filmBeatsOf(draft);
  final openings = partOpeningsOf(stops);

  // By identity: a part is the object in the list, whatever it compares equal
  // to.
  final partOf = Map<TutorialSection, int>.identity();
  for (var i = 0; i < draft.sections.length; i++) {
    partOf[draft.sections[i]] = i;
  }
  final lastBeat = <int, int>{};
  for (final stop in stops) {
    final p = partOf[stop.section]!;
    lastBeat[p] = stop.beat.index;
  }

  final entries = <PartMapEntry>[];
  final edges = <PartMapEdge>[];

  for (var i = 0; i < stops.length; i++) {
    final opening = openings[i];
    if (opening == null) continue;
    final row = partOf[stops[i].section]!;

    PartSource? from;
    if (opening.from != null) {
      final source = stops[opening.from!];
      from = (part: partOf[source.section]!, beat: source.beat.index);
    }

    final int lane;
    switch (opening.entry) {
      case PartEntry.continues:
        lane = entries[from!.part].lane;
      case PartEntry.fresh:
        lane = _lowestFree(entries, from: row, to: row, atLeast: 0);
      case PartEntry.returns:
        final middle = from!.beat != 0 && from.beat != lastBeat[from.part];
        lane = _lowestFree(
          entries,
          from: from.part,
          to: row,
          atLeast: middle ? entries[from.part].lane + 1 : 0,
        );
    }

    if (from != null) {
      edges.add(PartMapEdge(
        fromRow: from.part,
        toRow: row,
        lane: lane,
        dashed: opening.entry == PartEntry.returns,
      ));
    }

    entries.add(PartMapEntry(
      part: row,
      entry: opening.entry,
      from: from,
      afterMove: opening.afterMove,
      lane: lane,
      moves: movesLineOf(stops[i].section.root),
    ));
  }

  return PartMap(entries: entries, edges: edges);
}

/// The lowest lane from [atLeast] on that no marker strictly between [from]
/// and [to] stands in.
int _lowestFree(List<PartMapEntry> entries,
    {required int from, required int to, required int atLeast}) {
  for (var lane = atLeast;; lane++) {
    var free = true;
    for (var k = from + 1; k < to && free; k++) {
      if (entries[k].lane == lane) free = false;
    }
    if (free) return lane;
  }
}

/// A part's line on one line, numbered the way a book writes it:
/// „17. Bg5 Nxe5 18. Rfe1 cxd4", and „16... Nc4" when it starts with Black.
String movesLineOf(AnalysisNode root) {
  final out = <String>[];
  var first = true;
  for (var node = root; node.children.isNotEmpty;) {
    node = node.children.first;
    final label = node.moveNumberLabel;
    final black = label.endsWith('... ');
    out.add(black && !first ? node.moveSan! : '$label${node.moveSan}');
    first = false;
  }
  return out.join(' ');
}
