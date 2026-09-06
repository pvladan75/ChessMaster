import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';

/// One stop on the line, in the order the child meets it.
///
/// A beat **is** a node — it holds no copy of what the node carries, because
/// two models of one tree is the fault this codebase has already paid for
/// twice. What it adds is position: which move arrived here, which move leaves,
/// what else could have left, and whether this is where the author is standing.
class TutorialBeat {
  const TutorialBeat({
    required this.node,
    required this.index,
    required this.isCurrent,
    this.next,
    this.branches = const [],
  });

  /// The node this beat is a view of. Its `comment`, `arrows` and `squares` are
  /// read from here rather than copied onto the beat.
  final AnalysisNode node;

  /// Where on the line this stop is, counting from 0 at the opening position.
  final int index;

  /// Whether the author is standing on this node.
  final bool isCurrent;

  /// Where the line goes from here. Null on the last beat, where it runs out
  /// and the question, if there is one, is asked.
  ///
  /// The node rather than its move, so that a card can write „pa se igra:
  /// 3. Nc3" without composing the number itself — [playsLabel] is the whole
  /// sentence and [plays] the bare move, both read from this one field. Two
  /// fields holding the same move is how two views of one thing come to
  /// disagree.
  final AnalysisNode? next;

  /// Every move that leaves this position, when there is more than one.
  ///
  /// Empty on a node with a single child: one move out is [plays] and nothing
  /// to choose. The branch that this projection follows is the one marked
  /// [TutorialBranch.taken].
  final List<TutorialBranch> branches;

  /// The move that **arrived** at this position, so the beat reads as a place.
  /// Null on the opening position, which nothing arrived at.
  String? get arrivedBy => node.moveSan;

  /// The move played **out** of this position, once the child has been told
  /// what there is to say here.
  String? get plays => next?.moveSan;

  /// „1... e5" — the move that arrived, numbered the way a book writes it.
  String? get arrivedLabel =>
      node.moveSan == null ? null : '${node.moveNumberLabel}${node.moveSan}';

  /// „2. Nf3" — the move that leaves.
  String? get playsLabel =>
      next?.moveSan == null ? null : '${next!.moveNumberLabel}${next!.moveSan}';

  bool get isLast => next == null;
}

/// One of the moves leaving a fork.
class TutorialBranch {
  const TutorialBranch({
    required this.node,
    required this.san,
    required this.taken,
  });

  final AnalysisNode node;
  final String san;

  /// Whether the timeline below this fork follows this branch.
  final bool taken;

  /// „3. Nc3" — what a chip says, numbered like the beats around it.
  String get label => '${node.moveNumberLabel}$san';
}

/// The beats of the line the author is standing on, in the order the child
/// meets them.
///
/// **The order is the viewer's, not the tree's.** It comes from the narration
/// loop in `lesson_viewer_screen.dart`, which is the definition of what the
/// child experiences: standing on a node, the viewer draws that node's marks,
/// speaks that node's comment, and only *then* plays the move to its child. So
/// a beat's arrows belong beside its sentence, and the move belongs after both
/// — a panel that drew the move first would be teaching the author something
/// false about their own tutorial.
///
/// **The line runs through [current] and then continues.** Above [current] the
/// path is forced: it is the one the author reached by. Below, it follows the
/// first child, which is what `isMainLine` means here and what
/// `endOfMainLine` already does. Alternatives at a fork are named rather than
/// walked — pressing one is how the panel re-projects.
///
/// **A [current] that does not belong to [root] projects the root's line
/// instead.** That is not defensive dressing: the author's node is held by a
/// screen across edits, and a stale one used to be read as „no beats at all",
/// which draws an empty panel over a tutorial that is perfectly fine.
List<TutorialBeat> beatsOf(AnalysisNode root, AnalysisNode current) {
  var anchor = current;
  final spine = <AnalysisNode>[];
  for (AnalysisNode? node = current; node != null; node = node.parent) {
    spine.add(node);
  }
  final reversed = spine.reversed.toList();
  spine
    ..clear()
    ..addAll(reversed);

  if (!identical(spine.first, root)) {
    // Written without recursing on purpose: a `root` that itself has a parent
    // would otherwise call this with the same two arguments for ever.
    anchor = root;
    spine
      ..clear()
      ..add(root);
  }

  // Past the author, the first child each time, to the end of the line.
  for (var node = spine.last;
      node.children.isNotEmpty;
      node = node.children.first) {
    spine.add(node.children.first);
  }

  return [
    for (var i = 0; i < spine.length; i++)
      TutorialBeat(
        node: spine[i],
        index: i,
        isCurrent: identical(spine[i], anchor),
        next: i + 1 < spine.length ? spine[i + 1] : null,
        branches: spine[i].children.length > 1
            ? [
                for (final child in spine[i].children)
                  TutorialBranch(
                    node: child,
                    san: child.moveSan ?? '',
                    taken:
                        i + 1 < spine.length && identical(child, spine[i + 1]),
                  ),
              ]
            : const [],
      ),
  ];
}
