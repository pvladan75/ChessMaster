import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/move_tree.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// A promotion is one move away: white pawn on g7, and the black king off
/// every line the new queen would give check along, so the SAN is a plain
/// "g8=Q" and the test is about the promotion rather than about the check.
const _promoFen = '8/6P1/8/8/k7/8/8/7K w - - 0 1';

void main() {
  group('MoveTree.appendLine', () {
    test('an engine line becomes a line of named moves', () {
      final tree = MoveTree(startingFen: _startFen);

      final result =
          MoveTree.appendLine(tree.root, ['e2e4', 'e7e5', 'g1f3', 'b8c6']);

      expect(result.added, 4);
      expect(result.rejected, isFalse);
      expect(result.head?.san, 'e4');
      expect(result.end.san, 'Nc6');

      // The moves are named, not spelled out as squares — which is what the
      // move list, the PGN export and the lesson all read afterwards.
      final sans = <String>[];
      for (var node = result.end; node.parent != null; node = node.parent!) {
        sans.insert(0, node.san);
      }
      expect(sans, ['e4', 'e5', 'Nf3', 'Nc6']);
    });

    test('a line already in the tree is stepped into, not doubled', () {
      final tree = MoveTree(startingFen: _startFen);
      MoveTree.appendLine(tree.root, ['e2e4', 'e7e5']);

      final again = MoveTree.appendLine(tree.root, ['e2e4', 'e7e5']);

      expect(again.added, 0);
      expect(again.rejected, isFalse);
      expect(tree.root.children.length, 1);
      expect(tree.root.children.first.children.length, 1);
      // It still reports where the line begins, so the evaluation can be
      // written onto a move that was already there.
      expect(again.head?.san, 'e4');
    });

    test('a shared opening grows one branch, not two', () {
      final tree = MoveTree(startingFen: _startFen);
      MoveTree.appendLine(tree.root, ['e2e4', 'e7e5']);

      final second = MoveTree.appendLine(tree.root, ['e2e4', 'c7c5']);

      expect(second.added, 1);
      expect(tree.root.children.length, 1);
      expect(tree.root.children.first.children.map((c) => c.san), ['e5', 'c5']);
    });

    test('an illegal move ends the walk and keeps what came before it', () {
      final tree = MoveTree(startingFen: _startFen);

      // 1. e4 is fine; a rook cannot move to h5 with its own pawn on h2.
      final result = MoveTree.appendLine(tree.root, ['e2e4', 'h1h5', 'd7d5']);

      expect(result.rejected, isTrue);
      expect(result.added, 1);
      expect(result.end.san, 'e4');
      expect(result.end.children, isEmpty);
    });

    test('a promotion keeps the piece it promotes to', () {
      final tree = MoveTree(startingFen: _promoFen);

      final result = MoveTree.appendLine(tree.root, ['g7g8q']);

      expect(result.added, 1);
      expect(result.end.san, 'g8=Q');
      expect(result.end.fen.split(' ').first, contains('Q'));
    });

    test('a position that will not load is rejected rather than guessed at',
        () {
      final broken = MoveNode(san: 'Root', fen: 'not a fen', from: '', to: '');

      final result = MoveTree.appendLine(broken, ['e2e4']);

      expect(result.rejected, isTrue);
      expect(result.added, 0);
      expect(broken.children, isEmpty);
    });

    test('the line survives a round trip through PGN', () {
      final tree = MoveTree(startingFen: _startFen);
      final result = MoveTree.appendLine(tree.root, ['e2e4', 'e7e5', 'g1f3']);
      result.head!.comment = '[+0.32 / dubina 20]';

      final reparsed = MoveTree.parsePgn(tree.exportToPgn());

      expect(reparsed, isNotNull);
      expect(reparsed!.root.children.first.san, 'e4');
      expect(reparsed.root.children.first.comment, '[+0.32 / dubina 20]');
    });
  });
}
