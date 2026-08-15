import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';

/// Builds a chain of moves under [root], returning the deepest node.
MoveNode _chain(MoveNode root, List<String> sans) {
  var node = root;
  for (final san in sans) {
    final child = MoveNode(san: san, fen: node.fen, from: '', to: '', parent: node);
    node.children.add(child);
    node = child;
  }
  return node;
}

MoveNode _rootAt(String fen) => MoveNode(san: '', fen: fen, from: '', to: '');

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
// Same position but Black to move, with the fullmove counter at 12.
const _blackToMoveFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR b KQkq - 0 12';

void main() {
  test('white moves carry their number, black moves after them do not', () {
    final root = _rootAt(_startFen);
    final last = _chain(root, ['e4', 'e5', 'Nf3']);

    final black = last.parent!;
    final firstWhite = black.parent!;

    expect(formatMoveWithNumber(firstWhite, root), '1. e4');
    expect(formatMoveWithNumber(black, root), 'e5');
    expect(formatMoveWithNumber(last, root), '2. Nf3');
  });

  test('a line starting on black opens with the elided form', () {
    // This is the case the old `moveIndex == 0 && !rootIsWhite` guard existed
    // for. Reaching the black branch at index 0 already implies the root was
    // black to move, so dropping the second half of the condition must not
    // change what comes out here.
    final root = _rootAt(_blackToMoveFen);
    final last = _chain(root, ['e5', 'Nf3']);
    final firstBlack = last.parent!;

    expect(formatMoveWithNumber(firstBlack, root), '12... e5');
    expect(formatMoveWithNumber(last, root), '13. Nf3');
  });

  test('the root itself is labelled as the start', () {
    final root = _rootAt(_startFen);
    expect(formatMoveWithNumber(root, root), 'Početak');
  });

  test('numbering continues from the root position fullmove counter', () {
    final root = _rootAt('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 7');
    final last = _chain(root, ['e4', 'e5']);

    expect(formatMoveWithNumber(last.parent!, root), '7. e4');
    expect(formatMoveWithNumber(last, root), 'e5');
  });
}
