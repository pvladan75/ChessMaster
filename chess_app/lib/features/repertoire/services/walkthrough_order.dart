import 'package:chess_app/features/analysis_studio/widgets/visual_move_tree_widget.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/features/repertoire/widgets/repertoire_tree_panel.dart';

/// One move, visited once, in the order a tour reads it.
///
/// Phase 3 of `docs/PLAN-UPOZNAJ-REPERTOAR.md`. A repertoire is a picture
/// nobody can hold in their head; an opening is learned as a story. This is the
/// story's running order, and nothing else — no board, no screen, no sentence.
class WalkthroughStop {
  const WalkthroughStop({required this.move, required this.path});

  /// The move being visited.
  final RepertoireTreeMove move;

  /// The SAN moves from the root of the *drawing* down to and including [move].
  ///
  /// Not prefixed with the repertoire's own `rootPath`: a caller that wants the
  /// whole line from the first move joins the two, and a caller that wants
  /// „where am I in this picture" — which is most of them — wants this.
  final List<String> path;

  int get depth => path.length;

  /// Which of the four this is.
  ///
  /// Deliberately delegated rather than decided again here. Phase 2 already
  /// answers this question, and three hand-written copies of one condition in
  /// this codebase each forgot the same clause.
  MoveTreeNodeLook get kind => lookOfRepertoireMove(move);
}

/// Whether anything under [move], or [move] itself, is the reader's own.
///
/// Counted over what the tour will actually *visit*: a cut branch is not walked,
/// so work sitting behind one is not work this tour can show, and ranking a
/// reply above a live book line for it would promise something never delivered.
///
/// The brief for this phase said „whose subtree contains at least one move of
/// the reader's own" without saying which side of the cut that falls on. This
/// is the reading that keeps the order and the walk telling the same story.
bool _holdsOwnWork(RepertoireTreeMove move) {
  if (move.state == 'cut') return false;
  if (move.mine) return true;
  for (final child in move.children) {
    if (_holdsOwnWork(child)) return true;
  }
  return false;
}

/// The moves under one position, in the order the tour visits them.
///
/// Stable throughout: every comparison falls back to the order the server sent,
/// so two branches the rules cannot separate keep the book's own ranking rather
/// than an arbitrary one that changes between runs.
List<RepertoireTreeMove> _ordered(List<RepertoireTreeMove> moves) {
  final live = [
    for (final move in moves)
      if (move.state != 'cut') move,
  ];
  final indexOf = {
    for (var i = 0; i < live.length; i++) live[i]: i,
  };
  final sorted = [...live];
  sorted.sort((a, b) {
    // Mine before theirs. A position holds one kind or the other in practice,
    // so this almost never fires — but „almost never" is not „never", and
    // without it the order would depend on what the server happened to send.
    if (a.mine != b.mine) return a.mine ? -1 : 1;

    if (a.mine) {
      // Among my own: the main move first. Not by share — one of my own moves
      // has none, and which of them I play is a decision, not a frequency.
      if (a.isPrimary != b.isPrimary) return a.isPrimary ? -1 : 1;
      return indexOf[a]!.compareTo(indexOf[b]!);
    }

    // Among theirs: a reply I have built something under comes first, however
    // rarely it is played. This is the whole point of the phase, and the
    // owner's rule in his own words — „it is a walkthrough of my repertoire, so
    // the user's actual work must never be buried beneath untouched book
    // lines." Measured on „Druga": all twenty-one drafts sit under the
    // opponent's *second* reply, so ordering by share alone would reach the
    // reader's own work last.
    final mineA = _holdsOwnWork(a);
    final mineB = _holdsOwnWork(b);
    if (mineA != mineB) return mineA ? -1 : 1;

    final byShare = b.share.compareTo(a.share);
    if (byShare != 0) return byShare;
    return indexOf[a]!.compareTo(indexOf[b]!);
  });
  return sorted;
}

/// Every move in the drawing, in the order the tour visits them.
///
/// Depth-first: the main line is walked to its end, then the tour comes back to
/// the last fork and goes out along the next one. Read breadth-first the same
/// tree is a table of contents rather than a story, which is the thing the
/// reader already has and cannot use.
///
/// Cut branches are skipped, and so is everything under them. The tour is „what
/// I play and what awaits me", and a refused branch is the one thing on the
/// drawing that is neither — it stays in the picture, drawn dimmed.
///
/// The tree is never mutated: the same object is drawn afterwards, in the
/// server's own order, by a screen that knows nothing about this function.
List<WalkthroughStop> walkthroughOrder(RepertoireTree tree) {
  final stops = <WalkthroughStop>[];

  void visit(RepertoireTreeMove move, List<String> above) {
    final path = [...above, move.san];
    stops.add(WalkthroughStop(move: move, path: path));
    for (final child in _ordered(move.children)) {
      visit(child, path);
    }
  }

  for (final child in _ordered(tree.children)) {
    visit(child, const []);
  }
  return stops;
}
