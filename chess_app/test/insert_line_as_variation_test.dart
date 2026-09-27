// The pure part of playing an engine's line into an AnalysisNode tree —
// beside `insert_line_as_variation.dart`'s own small test, as
// `docs/PLAN-PRIPREMA.md` asks for phase 1.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/insert_line_as_variation.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

void main() {
  test('every move of the line is added, in order', () {
    final root = AnalysisNode(fen: _start);
    final result = insertLineAsVariation(root, 'e2e4 e7e5 g1f3');
    expect(result.added, 3);
    expect(result.rejected, isFalse);
    expect(root.children, hasLength(1));
    expect(root.children.single.moveSan, 'e4');
    final e4 = root.children.single;
    expect(e4.children.single.moveSan, 'e5');
    expect(e4.children.single.children.single.moveSan, 'Nf3');
  });

  test('a move the position does not allow is rejected, nothing added', () {
    final root = AnalysisNode(fen: _start);
    final result = insertLineAsVariation(root, 'e2e5');
    expect(result.added, 0);
    expect(result.rejected, isTrue);
    expect(root.children, isEmpty);
  });

  test('a line already in the tree is walked into, not duplicated', () {
    final root = AnalysisNode(fen: _start);
    insertLineAsVariation(root, 'e2e4');
    final result = insertLineAsVariation(root, 'e2e4');
    expect(result.added, 0);
    expect(result.rejected, isFalse);
    expect(root.children, hasLength(1));
  });

  test('an empty line adds nothing and is rejected', () {
    final root = AnalysisNode(fen: _start);
    final result = insertLineAsVariation(root, '');
    expect(result.added, 0);
    expect(result.rejected, isTrue);
  });

  test('a promoting move is added once', () {
    final root = AnalysisNode(fen: '8/4P3/8/8/8/2k5/8/K7 w - - 0 1');
    final result = insertLineAsVariation(root, 'e7e8q');
    expect(result.added, 1);
    expect(root.children.single.moveSan, 'e8=Q');
  });
}
