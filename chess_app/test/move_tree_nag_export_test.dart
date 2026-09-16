import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/move_tree.dart';

/// The room's PGN writer writes back the move marks its reader keeps.
///
/// Found by the architecture audit on 16.9.2026 (`docs/audit/app.md`, 3). On
/// 12.9.2026 `MoveTree.parsePgn` learned to keep `c5??` on the move instead of
/// stripping it; `MoveTree.exportToPgn` was not taught to write it back. So a
/// reviewed game loaded into a room lost every `!` and `?` the first time the
/// room broadcast or saved it. `PgnExporterService` already wrote them; this is
/// the same round trip for the other writer.
void main() {
  test('a mark on the main line survives being read and written', () {
    final pgn = MoveTree.parsePgn('1. e4 c5?? 2. Nf3! Nc6')!.exportToPgn();
    expect(pgn, contains('c5??'));
    expect(pgn, contains('Nf3!'));
  });

  test('a mark in a sideline survives too', () {
    final pgn =
        MoveTree.parsePgn('1. e4 e5 (1... c5!? 2. Nf3) 2. Nf3')!.exportToPgn();
    expect(pgn, contains('c5!?'));
  });

  test('what is written reads back to the same marks', () {
    final first = MoveTree.parsePgn('1. d4?! d5 2. c4!! e6?')!;
    final again = MoveTree.parsePgn(first.exportToPgn())!;
    final marks = <String?>[];
    var node = again.root;
    while (node.children.isNotEmpty) {
      node = node.children.first;
      marks.add(node.nag);
    }
    expect(marks, ['?!', null, '!!', '?']);
    expect(again.rejectedMoves, 0);
  });
}
