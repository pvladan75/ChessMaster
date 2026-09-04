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

  @override
  List<MoveBranch> get forwardBranches {
    final prefix = index < 0 ? const <String>[] : stops[index].path;
    final branches = <MoveBranch>[];
    for (var j = index + 1; j < stops.length; j++) {
      final path = stops[j].path;
      if (_startsWith(path, prefix)) {
        if (path.length == prefix.length + 1) {
          final move = stops[j].move;
          final state = _detailForMove(move);
          branches.add(
            MoveBranch(
              label: '${move.san}${markOfRepertoireMove(move) ?? ''}',
              detail: state,
              isMain: branches.isEmpty,
            ),
          );
        }
      } else {
        break;
      }
    }
    return branches;
  }

  @override
  void takeBranch(int branchIndex) {
    final prefix = index < 0 ? const <String>[] : stops[index].path;
    var currentBranch = 0;
    for (var j = index + 1; j < stops.length; j++) {
      final path = stops[j].path;
      if (_startsWith(path, prefix)) {
        if (path.length == prefix.length + 1) {
          if (currentBranch == branchIndex) {
            onSelect(j);
            return;
          }
          currentBranch++;
        }
      } else {
        break;
      }
    }
    next();
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
