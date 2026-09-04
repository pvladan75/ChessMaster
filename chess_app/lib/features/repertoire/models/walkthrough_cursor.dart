import 'package:flutter/material.dart';

import 'package:chess_app/core/models/move_cursor.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/features/repertoire/services/walkthrough_beats.dart';
import 'package:chess_app/features/repertoire/services/walkthrough_order.dart';
import 'package:chess_app/features/analysis_studio/widgets/visual_move_tree_widget.dart';
import 'package:chess_app/features/repertoire/widgets/repertoire_tree_panel.dart';

bool _startsWith(List<String> path, List<String> prefix) {
  if (path.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (path[i] != prefix[i]) return false;
  }
  return true;
}

/// The tour, as something the strip and the arrow keys can drive.
///
/// Built fresh in `build()` from the stop list and the current index, like
/// every other [MoveCursor]: it holds no state and calls back into the screen.
class WalkthroughCursor implements MoveCursor {
  const WalkthroughCursor({
    required this.tree,
    required this.stops,
    required this.beats,
    required this.index,
    required this.onSelect,
  });

  final RepertoireTree tree;
  final List<WalkthroughStop> stops;

  /// The tour as it is driven: every stop, plus a return to the fork before
  /// each climb. See `walkthroughBeats`.
  final List<WalkthroughBeat> beats;

  /// Where the tour is standing, **as a beat**. -1 is the root position,
  /// before the first move of the tour has been played.
  ///
  /// A beat rather than a stop because the strip and the keys drive the tour
  /// the reader sees, and the reader sees the returns. Keeping the index over
  /// stops and hiding the returns inside the screen would have put a second
  /// idea of "where am I" beside this one.
  final int index;

  /// The stop the board stands on, or -1 for the root.
  int get _stopIndex =>
      index < 0 || index >= beats.length ? -1 : beats[index].stopIndex;

  /// The beat the tour is standing on, or null at the root.
  WalkthroughBeat? get beat =>
      index < 0 || index >= beats.length ? null : beats[index];

  /// The index the tour should move to.
  final ValueChanged<int> onSelect;

  @override
  bool get canGoBack => index >= 0;

  @override
  bool get canGoForward => index < beats.length - 1;

  @override
  String? get currentFen =>
      _stopIndex < 0 ? tree.rootFen : stops[_stopIndex].move.fen;

  @override
  void first() => onSelect(-1);

  @override
  void previous() {
    if (canGoBack) {
      onSelect(index - 1);
    }
  }

  @override
  void next() {
    if (canGoForward) {
      onSelect(index + 1);
    }
  }

  @override
  void last() {
    // The end of *this* line, and a returning beat is never part of it: it
    // stands on the fork, which is an ancestor rather than a descendant, so
    // the scan stops there of its own accord. That is the behaviour the
    // interface asks for — „never jumping into a sibling variation" — and it
    // falls out rather than being special-cased.
    final prefix = _stopIndex < 0 ? const <String>[] : stops[_stopIndex].path;
    var lastIndex = index;
    for (var j = index + 1; j < beats.length; j++) {
      final at = beats[j].stopIndex;
      if (at >= 0 &&
          !beats[j].returning &&
          _startsWith(stops[at].path, prefix)) {
        lastIndex = j;
      } else {
        break;
      }
    }
    onSelect(lastIndex);
  }

  /// The index in [stops] of every move out of the current position, in tour
  /// order.
  ///
  /// The one derivation. Three things want these — the strip's fork question,
  /// the chips on the card, and the sentence that names them — and each of
  /// them writing its own scan is how the sheet and the tour would end up
  /// disagreeing about which reply comes first. The scan itself is the rule
  /// from the brief: a child is a stop whose path is the current one plus a
  /// single move, taken while we are still inside the current subtree.
  List<int> get _forwardIndices {
    final from = _stopIndex;
    final prefix = from < 0 ? const <String>[] : stops[from].path;
    final found = <int>[];
    for (var j = from + 1; j < stops.length; j++) {
      final path = stops[j].path;
      if (!_startsWith(path, prefix)) break;
      if (path.length == prefix.length + 1) found.add(j);
    }
    return found;
  }

  /// The moves out of the current position, in tour order.
  ///
  /// What the card's sentence is built from, so the words and the sheet name
  /// the same replies in the same order.
  List<RepertoireTreeMove> get forwardMoves =>
      [for (final j in _forwardIndices) stops[j].move];

  /// Every reply out of this position, as the card lists them.
  ///
  /// Kept apart from [forwardBranches] because the two answer different
  /// questions. This one is „what awaits the reader here", and it is the same
  /// at a returning beat as anywhere else — that beat exists precisely to show
  /// the fork. [forwardBranches] is the strip's question, „what could pressing
  /// forward mean", and at a returning beat it has exactly one answer.
  List<MoveBranch> get replyBranches {
    final moves = forwardMoves;
    return [
      for (var i = 0; i < moves.length; i++)
        MoveBranch(
          label: '${moves[i].san}${markOfRepertoireMove(moves[i]) ?? ''}',
          detail: _detailForMove(moves[i]),
          isMain: i == 0,
        ),
    ];
  }

  /// What pressing forward could mean — the strip's question, and nothing else.
  ///
  /// Empty on a returning beat. The tour has just said which line it is about
  /// to take („Videli smo liniju posle e5. Sada ide e6."), so asking „odavde
  /// ide više linija — kojom?" in the very next breath contradicts it — and
  /// worse, the forward button then opens a sheet instead of going anywhere.
  /// The replies are still on the card as chips and on the board as arrows;
  /// a reader who wants a different one picks it there.
  @override
  List<MoveBranch> get forwardBranches =>
      beat?.returning == true ? const [] : replyBranches;

  @override
  void takeBranch(int branchIndex) {
    final found = _forwardIndices;
    if (branchIndex < 0 || branchIndex >= found.length) {
      next();
      return;
    }
    // Back from a stop to the beat that visits it. A stop is visited exactly
    // once as a move, so this is unambiguous — the returning beats that also
    // name it are the tour standing at a fork, not playing it.
    final at = beats
        .indexWhere((b) => !b.returning && b.stopIndex == found[branchIndex]);
    if (at >= 0) onSelect(at);
  }

  /// The second line of a branch in the sheet: the state, in plain words.
  ///
  /// Keyed off the look rather than off `state`, because `state` describes the
  /// position a move leads to and reads differently on the two kinds of card:
  /// a move of *mine* can sit in front of an `open` position, and reading the
  /// raw field would have told the reader „nemate odgovor" about their own
  /// move. `lookOfRepertoireMove` is the one place that question is answered.
  String? _detailForMove(RepertoireTreeMove move) {
    switch (lookOfRepertoireMove(move)) {
      case MoveTreeNodeLook.gap:
        return 'nemate odgovor';
      case MoveTreeNodeLook.covered:
        return move.state == 'unopened' ? 'odluka bez uzetih odgovora' : null;
      case MoveTreeNodeLook.authored:
      case MoveTreeNodeLook.refused:
        return null;
    }
  }
}
