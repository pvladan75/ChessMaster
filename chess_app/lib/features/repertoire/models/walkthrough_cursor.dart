import 'package:flutter/material.dart';

import 'package:chess_app/core/models/move_cursor.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
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
    required this.index,
    required this.onSelect,
  });

  final RepertoireTree tree;
  final List<WalkthroughStop> stops;

  /// Where the tour is standing. **-1 is the root position**, before the first
  /// move of the tour has been played.
  final int index;

  /// The index the tour should move to.
  final ValueChanged<int> onSelect;

  @override
  bool get canGoBack => index >= 0;

  @override
  bool get canGoForward => index < stops.length - 1;

  @override
  String? get currentFen => index < 0 ? tree.rootFen : stops[index].move.fen;

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
    final prefix = index < 0 ? const <String>[] : stops[index].path;
    var lastIndex = index;
    for (var j = index + 1; j < stops.length; j++) {
      final path = stops[j].path;
      if (_startsWith(path, prefix)) {
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
    final prefix = index < 0 ? const <String>[] : stops[index].path;
    final found = <int>[];
    for (var j = index + 1; j < stops.length; j++) {
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

  @override
  List<MoveBranch> get forwardBranches {
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

  @override
  void takeBranch(int branchIndex) {
    final found = _forwardIndices;
    if (branchIndex < 0 || branchIndex >= found.length) {
      next();
      return;
    }
    onSelect(found[branchIndex]);
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
