import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/services/fen_legality.dart';

/// „Insert a line here" — phase 3 of `docs/PLAN-STUDIO-ISTORIJA.md`: one part
/// becomes a demonstration up to [cursor], a new line from it, and the original
/// continuation.
///
/// The owner's example, 11.9.2026: `1. Ra1 Kc6 2. Ra6 Bb2 3. c3 Kb5` from
/// `8/3k4/1n3b2/8/8/8/2PK4/2R5 w`, and a second line `2. Ra8 Bb2` to be shown
/// from the position after `Kc6`. Until now the only way was to rebuild the
/// part by hand. The parts come back in order:
///
///  * **A** — the tree as it was, cut at [cursor], with every sentence, arrow
///    and square on it. It keeps the part's step id and name. Omitted when the
///    cursor is the part's own starting position.
///  * **B** — the new line, [line]: a demonstration on the cursor's position.
///    Its first position carries the cursor's arrows and squares, because the
///    board does not reload across the join from A; not its sentence, which A
///    has just read out — unless there is no A. Any sideline already played at
///    the cursor becomes B's line, so a trainer who played it first loses
///    nothing by cutting afterwards.
///  * **C** — the original continuation from the cursor's position, with
///    everything written on it. The board reloads here, after B's line, so the
///    cursor's marks are drawn again. Omitted when nothing followed the cursor.
///    When there is no A, C *is* the original part, and it keeps the step id:
///    a step id is what a child's schedule and recorded answers name a step by,
///    and cutting a line in front of a part must not cut them off from it.
///
/// The original is not modified. The caller replaces it with [parts].
({List<TutorialSection> parts, TutorialSection line}) splitForLine(
  TutorialSection part,
  AnalysisNode cursor,
) {
  final path = _pathTo(part.root, cursor);
  final beforeRoot = copyTree(part.root);
  final beforeCursor = _resolve(beforeRoot, path);
  // A trainer standing on a sideline is cutting that sideline: A has to end
  // where B begins.
  _promotePath(beforeCursor);

  final tail = [...beforeCursor.children];
  beforeCursor.children.clear();
  final hasBefore = path.isNotEmpty;
  final continuation = tail.isEmpty ? null : tail.first;
  final sidelines = tail.skip(1).toList();

  AnalysisNode rootOn(List<AnalysisNode> children, {String comment = ''}) {
    final root = AnalysisNode(
      fen: cursor.fen,
      comment: comment,
      arrows: [...beforeCursor.arrows],
      squares: [...beforeCursor.squares],
    );
    for (final child in children) {
      child.parent = root;
      root.children.add(child);
    }
    return root;
  }

  final line = TutorialSection(
    root: rootOn(sidelines, comment: hasBefore ? '' : beforeCursor.comment),
    blackOrientation: part.blackOrientation,
  );

  final out = <TutorialSection>[];
  if (hasBefore) {
    out.add(TutorialSection(
      stepId: part.stepId,
      root: beforeRoot,
      title: part.title,
      blackOrientation: part.blackOrientation,
      // Not `part.storedPgn`: the tree is shorter now, and a part holding the
      // old text would send it.
      storedPgn: null,
    ));
  }
  out.add(line);
  if (continuation != null) {
    out.add(TutorialSection(
      stepId: hasBefore ? null : part.stepId,
      title: hasBefore ? '' : part.title,
      root: rootOn([continuation]),
      blackOrientation: part.blackOrientation,
    ));
  }
  return (parts: out, line: line);
}

/// Whether „Insert a line here" has a line to cut: a part with at least one
/// move. A part with no moves is already where a new demonstration would
/// start.
bool canSplitForLine(TutorialSection part) => part.root.children.isNotEmpty;

/// Makes the line from the root down to [node] the main line of its tree.
void _promotePath(AnalysisNode node) {
  var child = node;
  var parent = child.parent;
  while (parent != null) {
    parent.promoteToMainLine(child);
    child = parent;
    parent = child.parent;
  }
}

/// The child indices leading from [root] to [target], empty when it is the root
/// itself — and empty, too, when it belongs to some other tree, which no caller
/// here can produce.
List<int> _pathTo(AnalysisNode root, AnalysisNode target) {
  final path = <int>[];
  var node = target;
  while (node.parent != null) {
    final parent = node.parent!;
    final index = parent.children.indexWhere((c) => c.id == node.id);
    if (index < 0) return const [];
    path.insert(0, index);
    node = parent;
  }
  return node.id == root.id ? path : const [];
}

AnalysisNode _resolve(AnalysisNode root, List<int> path) {
  var node = root;
  for (final index in path) {
    if (index < 0 || index >= node.children.length) break;
    node = node.children[index];
  }
  return node;
}

/// **A part is one line** — D2 of `docs/PLAN-MAPA-DELOVA.md`: every fork in
/// [part] made into parts, in the order „Insert a line here" makes them.
///
/// The film walks first children, so a side line left inside a part is saved
/// and never shown. Every door that can bring a fork in — the PGN tab, the
/// handover from Analysis, an import — passes the part through here, and only
/// a move played on the board makes its part itself (D1).
///
/// At the first fork down the main line the part is cut by [splitForLine]:
/// the part up to the fork, then each side line **in the order it stands**,
/// then the original continuation going back to the fork. Each of those is
/// split again the same way until no part forks. For a single fork the answer
/// is [splitForLine]'s at that fork — one rule with two callers, and the gate
/// holds it to that.
///
/// A part with no fork comes back as itself; any other is not modified.
List<TutorialSection> splitAtForks(TutorialSection part) {
  final fork = _firstFork(part.root);
  if (fork == null) return [part];

  final cut = splitForLine(part, fork);
  return [
    for (final piece in cut.parts)
      if (identical(piece, cut.line))
        for (final line in _onePerSideLine(piece)) ...splitAtForks(line)
      else
        ...splitAtForks(piece),
  ];
}

/// Whether any position in [part] goes on in more than one way.
bool partForks(TutorialSection part) => _forksBelow(part.root);

bool _forksBelow(AnalysisNode node) =>
    node.children.length > 1 || node.children.any(_forksBelow);

/// The first position down the main line that goes on in more than one way.
AnalysisNode? _firstFork(AnalysisNode root) {
  for (AnalysisNode node = root;
      node.children.isNotEmpty;
      node = node.children.first) {
    if (node.children.length > 1) return node;
  }
  return null;
}

/// [splitForLine]'s new line holds every side line at the fork as one child
/// each; this makes a part of each, in order. The first keeps what the line's
/// first position says, since that is read out once; every one carries its
/// arrows and squares, because the board reloads at each return.
List<TutorialSection> _onePerSideLine(TutorialSection line) {
  final root = line.root;
  if (root.children.length < 2) return [line];
  return [
    for (var i = 0; i < root.children.length; i++)
      TutorialSection(
        root: _rootWith(root, root.children[i], keepComment: i == 0),
        blackOrientation: line.blackOrientation,
      ),
  ];
}

AnalysisNode _rootWith(
  AnalysisNode like,
  AnalysisNode child, {
  required bool keepComment,
}) {
  final root = AnalysisNode(
    fen: like.fen,
    comment: keepComment ? like.comment : '',
    arrows: [...like.arrows],
    squares: [...like.squares],
  );
  final moved = copyTree(child);
  moved.parent = root;
  root.children.add(moved);
  return root;
}

/// [root] made the open part's line, and the part made into parts at every
/// fork ([splitAtForks]). Answers how many parts it became; the first stays
/// open, standing on its start.
///
/// The one door for a whole tree arriving in a part: the PGN tab's Apply and
/// both handovers from Analysis. What the part said before is gone, so its
/// stored text goes with it.
int openLineAsParts(TutorialDraft draft, AnalysisNode root) {
  final part = draft.section
    ..root = root
    ..cursorNode = root
    ..storedPgn = null;
  final parts = splitAtForks(part);
  draft.replaceSelected(parts);
  return parts.length;
}

/// One stored step — the shape `position_list` holds — made into steps at
/// every fork. The door for a tutorial arriving from outside: a JSON file, a
/// PGN game, and through them „Open" and „Save" alike.
///
/// Read by the app's one reader ([TutorialSection.fromStep]) and written by
/// the save's own writer ([TutorialSection.toJson]), so nothing here parses or
/// prints a line a second way. [index] is the step's place in the tutorial,
/// for the names a part with none is given.
///
/// **A step that does not fork comes back as it was**, its text untouched. So
/// does one this cannot read whole — a position that is not chess, a kind that
/// is not „show", moves that do not replay: the import's report names what is
/// wrong with it, and splitting what the reader could make of it would save a
/// shorter line under a clean report. No step that comes out carries an `id`.
List<Map<String, dynamic>> splitStepAtForks(
  Map<String, dynamic> step, {
  int index = 0,
}) {
  if ((step['kind']?.toString() ?? 'show') != 'show') return [step];
  if (fenIllegalReason(step['fen']?.toString() ?? '') != null) return [step];
  final part = TutorialSection.fromStep(step);
  if (part.rejectedMoves > 0 || !partForks(part)) return [step];

  final parts = splitAtForks(part);
  return [
    for (var i = 0; i < parts.length; i++)
      parts[i].toJson(index: index + i)..remove('id'),
  ];
}
