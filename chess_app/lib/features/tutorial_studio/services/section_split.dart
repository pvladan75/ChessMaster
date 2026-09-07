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

  final question = TutorialSection(
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
bool canSplitForQuestion(TutorialSection part, AnalysisNode cursor) =>
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
