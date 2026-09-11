import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/assignments/models/assignment.dart'
    show LessonStepKind;
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';

/// „Postavi pitanje odavde": one part becomes a demonstration, a question and
/// a continuation.
///
/// The arrangement was already the studio's advice — „Demonstracija ide u deo
/// ispred pitanja — pitanje ostaje samo pozicija" — and until now a trainer had
/// to build it by hand. The only automatic route was the kind dropdown, which
/// offers to *delete* the line, because a step's `pgn` is not redacted on its
/// way to a child and the viewer draws the move strip for every kind: a
/// question carrying its own line hands the answer to anyone who presses
/// „Sledeći potez".
///
/// Nothing is thrown away. The parts come back in the order they belong in:
///
///  * **A**, the demonstration — the tree as it was, cut at [cursor]. Omitted
///    when the cursor is the part's own starting position, where it would be an
///    empty diagram in front of a question about the same board.
///  * **B**, the question — a bare position on [cursor], `ask_move`, with the
///    move that already followed taken as the answer.
///  * **C**, the continuation — the same position again, carrying that answer
///    and everything after it, sidelines included. Omitted when the cursor is
///    the end of the line and there is nothing to continue with.
///
/// **The step id stays with the original line.** A step id is what a child's
/// schedule and recorded answers name a step by, and a part sent without one
/// is given a new id by the server. So A keeps it; with no A, C *is* the
/// original part and keeps it, with the part's name; with neither, B is the
/// whole part. Until 11.9.2026 a question placed at the part's own starting
/// position left no part holding the id.
///
/// Every part stands on a position that joins the one before it, which is what
/// makes this one board on the child's screen rather than three: the viewer
/// crosses a join without reloading the pieces.
///
/// The original is not modified. The caller replaces it with what comes back.
List<TutorialSection> splitForQuestion(
  TutorialSection part,
  AnalysisNode cursor, {
  LessonStepKind kind = LessonStepKind.askMove,
}) {
  final path = _pathTo(part.root, cursor);

  // A copy, so the caller's tree survives a split it may still cancel — and
  // because `copyTree` mints fresh node ids, which is what keeps two parts from
  // sharing node identity.
  final beforeRoot = copyTree(part.root);
  final beforeCursor = _resolve(beforeRoot, path);

  // The demonstration has to end where the question begins, so the line that
  // leads there is made the main one. A trainer standing on a sideline is
  // asking about that sideline; a demonstration that walked the main line
  // instead would never reach the position it is asking about.
  _promotePath(beforeCursor);

  final tail = [...beforeCursor.children];
  beforeCursor.children.clear();

  final hasBefore = path.isNotEmpty;
  final hasAfter = tail.isNotEmpty;

  // With nothing in front and nothing after, the question is the whole part.
  final wholePart = !hasBefore && !hasAfter;
  final question = TutorialSection(
    stepId: wholePart ? part.stepId : null,
    title: wholePart ? part.title : '',
    root: AnalysisNode(
      fen: cursor.fen,
      // The marks travel because the board does not reload across a join: a
      // circle that vanishes the moment the question starts is a flicker in
      // the middle of one continuous board. The sentence does not, because the
      // part in front has just read it out — unless there is no part in front,
      // and then this is the only place it can live.
      comment: hasBefore ? '' : beforeCursor.comment,
      arrows: [...cursor.arrows],
      squares: [...cursor.squares],
    ),
    kind: kind,
    // The move the trainer had already played is the move they are asking
    // about. Null at the end of a line, where they play it on the board and
    // `_onMove` records it — which is what an `ask_move` part does with a move.
    //
    // Kept for a question with offered answers too. It is a property of the
    // position rather than of the question — the server has said so since
    // before kinds existed — and a trainer who changes their mind about how to
    // ask should not have to find the move again.
    solutionSan: hasAfter ? tail.first.moveSan : null,
    blackOrientation: part.blackOrientation,
  );

  final out = <TutorialSection>[];

  if (hasBefore) {
    out.add(TutorialSection(
      stepId: part.stepId,
      root: beforeRoot,
      title: part.title,
      instruction: part.instruction,
      solutionSan: part.solutionSan,
      acceptedSans: [...part.acceptedSans],
      blackOrientation: part.blackOrientation,
      // **Not** `part.storedPgn`. A section decides „untouched" by comparing
      // `treeSignature` against the tree it is holding, and it takes that
      // reading in its constructor — so a shortened part carrying the old text
      // would look pristine, and the save would send the whole original line
      // as this part's. The tree is different now; the text has to be written
      // again from it.
      storedPgn: null,
    ));
  }

  out.add(question);

  if (hasAfter) {
    final afterRoot = AnalysisNode(fen: cursor.fen);
    for (final child in tail) {
      child.parent = afterRoot;
      afterRoot.children.add(child);
    }
    out.add(TutorialSection(
      // With no demonstration in front, this is the original line: the step a
      // child's progress names.
      stepId: hasBefore ? null : part.stepId,
      title: hasBefore ? '' : part.title,
      root: afterRoot,
      blackOrientation: part.blackOrientation,
    ));
  }

  return out;
}

/// Whether [part] can be split at [cursor] into anything worth having.
///
/// A question is one part's whole job, so a part that already asks something
/// has nothing to split; and a part with no moves at all is already the bare
/// position a question wants — the kind dropdown is the way to turn that one
/// into a question.
bool canSplitForQuestion(TutorialSection part) =>
    part.kind == LessonStepKind.show && part.root.children.isNotEmpty;

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
      instruction: part.instruction,
      solutionSan: part.solutionSan,
      acceptedSans: [...part.acceptedSans],
      blackOrientation: part.blackOrientation,
      // Not `part.storedPgn`, for the reason [splitForQuestion] gives: the
      // tree is shorter now, and a part holding the old text would send it.
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

/// Whether „Insert a line here" has a line to cut: a demonstration with at
/// least one move. A question carries no line — that is the rule
/// [TutorialSection.leaksAnswer] enforces — and a part with no moves is
/// already where a new demonstration would start.
bool canSplitForLine(TutorialSection part) =>
    part.kind == LessonStepKind.show && part.root.children.isNotEmpty;

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
