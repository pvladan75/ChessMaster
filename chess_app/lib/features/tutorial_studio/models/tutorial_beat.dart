import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/move_tree.dart';

/// One stop on the line, in the order the child meets it — and, since D4 of
/// `docs/PLAN-PRIPREMA.md`, one for every **sentence** a position holds, not
/// one for the position alone.
///
/// A beat **is a view of a node's own beat** — it holds no copy of what the
/// node carries, because two models of one tree is the fault this codebase
/// has already paid for twice. What it adds is position: which move arrived
/// here, which move leaves, what else could have left, which of the
/// position's sentences this is, and whether this is where the author is
/// standing.
class TutorialBeat {
  const TutorialBeat({
    required this.node,
    required this.index,
    required this.at,
    required this.of,
    required this.say,
    required this.isCurrent,
    this.next,
    this.branches = const [],
  });

  /// The node this beat is a view of. Its `comment`, `arrows` and `squares`
  /// read the *first* of its beats — [say] is the one this stop is about.
  final AnalysisNode node;

  /// Where on the line this stop's **position** is, counting from 0 at the
  /// opening position. The same for every beat of one position, as it always
  /// was for the position alone.
  final int index;

  /// Which of [node]'s beats this stop is, from 0.
  final int at;

  /// How many beats [node] holds.
  final int of;

  /// The sentence and the marks of this stop.
  final NodeBeat say;

  /// Whether the author is standing on this node, at this beat.
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
///
/// [currentAt] is which of [current]'s own beats the author stands on;
/// clamped to the beats it still has, so a sentence removed from under the
/// author does not read as „nowhere" but as the last one that is left.
List<TutorialBeat> beatsOf(AnalysisNode root, AnalysisNode current,
    {int currentAt = 0}) {
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

  final result = <TutorialBeat>[];
  for (var i = 0; i < spine.length; i++) {
    final node = spine[i];
    final isAnchor = identical(node, anchor);
    final clampedAt = currentAt.clamp(0, node.beats.length - 1).toInt();
    final next = i + 1 < spine.length ? spine[i + 1] : null;
    final branches = node.children.length > 1
        ? [
            for (final child in node.children)
              TutorialBranch(
                node: child,
                san: child.moveSan ?? '',
                taken: identical(child, next),
              ),
          ]
        : const <TutorialBranch>[];
    for (var at = 0; at < node.beats.length; at++) {
      result.add(TutorialBeat(
        node: node,
        index: i,
        at: at,
        of: node.beats.length,
        say: node.beats[at],
        isCurrent: isAnchor && at == clampedAt,
        next: next,
        branches: branches,
      ));
    }
  }
  return result;
}
