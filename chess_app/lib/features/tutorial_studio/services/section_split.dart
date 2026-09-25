import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';

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
