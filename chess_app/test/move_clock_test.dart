// The clock among a moment's facts — docs/PLAN-ZAGONETKE-IZ-PARTIJE.md, phase 3
// (moved there from 1.3, with its only reader).
//
// Online games write `[%clk H:MM:SS]` after every move, and until 25.9.2026 the
// PGN reader threw it away with every other command when it cleaned a comment.
// Now it is read first, carried through the Analysis tree, kept in the draft,
// written back on export, and — with the game's `TimeControl`, which says the
// increment — turned into the time left and the time a move took. Without the
// header only the time left is said (the owner's choice of 25.9.2026).

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/move_clock.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/game_review_runner.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_import.dart';
import 'package:chess_app/move_tree.dart';

/// Three minutes and two seconds a move, as Lichess exports a blitz game.
const _lichess = '''
[Event "Rated Blitz game"]
[White "Ana"]
[Black "Boris"]
[TimeControl "180+2"]

1. e4 { [%clk 0:03:00] } 1... e5 { [%clk 0:03:01.5] } 2. Nf3 { [%clk 0:02:55] } 2... Nc6 { good [%clk 0:02:59.9] } *
''';

void main() {
  group('reading and writing the command', () {
    test('a clock is seconds, with or without hours and tenths', () {
      expect(MoveTree.parsePgnClock('[%clk 0:02:59.9]'), closeTo(179.9, 1e-9));
      expect(MoveTree.parsePgnClock('[%clk 1:02:03]'), 3723);
      expect(MoveTree.parsePgnClock('[%clk 2:59]'), 179);
      expect(MoveTree.parsePgnClock('a good move [%cal Ge2e4]'), isNull);
    });

    test('a clock written out reads back the same', () {
      for (final s in [0.0, 1.0, 59.9, 179.9, 3723.0, 3600.4]) {
        expect(MoveTree.parsePgnClock(MoveTree.pgnClock(s)), closeTo(s, 1e-9),
            reason: MoveTree.pgnClock(s));
      }
      expect(MoveTree.pgnClock(59.96), '[%clk 0:01:00]',
          reason: 'rounded to tenths before it is split');
    });
  });

  group('through the tree', () {
    test('each move keeps its own clock, and the words stay clean of it', () {
      final read = readAnalysisPgn(_lichess)!;
      final moves = <AnalysisNode>[];
      var node = read.root;
      while (node.children.isNotEmpty) {
        node = node.children.first;
        moves.add(node);
      }
      expect([for (final m in moves) m.clockSeconds], [180, 181.5, 175, 179.9]);
      expect(moves.last.comment, 'good');
      expect(read.root.timeControl, '180+2');
      expect(read.root.clockSeconds, isNull);
    });

    test(
        'the draft keeps the clock and the time control; an old draft has none',
        () {
      final read = readAnalysisPgn(_lichess)!;
      final back = AnalysisNode.fromJson(read.root.toJson());
      expect(back.timeControl, '180+2');
      expect(back.children.first.clockSeconds, 180);
      final old = AnalysisNode.fromJson({
        'fen': read.root.fen,
        'children': <Object>[],
      });
      expect(old.timeControl, isNull);
    });

    test('an export writes the clocks and the time control back', () {
      final read = readAnalysisPgn(_lichess)!;
      final pgn = PgnExporterService.exportToPgn(read.root);
      expect(pgn, contains('[TimeControl "180+2"]'));
      expect(pgn, contains('[%clk 0:03:01.5]'));
      final again = readAnalysisPgn(pgn)!;
      expect(again.root.timeControl, '180+2');
      expect(again.root.children.first.children.first.clockSeconds, 181.5);
    });

    test('a header of `-` is no time control', () {
      final read = readAnalysisPgn(
          _lichess.replaceFirst('[TimeControl "180+2"]', '[TimeControl "-"]'))!;
      expect(read.root.timeControl, isNull);
    });
  });

  group('the facts', () {
    const control = TimeControl(180, 2);
    final clocks = <double?>[180, 181.5, 175, 179.9];

    test('the time control\'s two online forms, and nothing else', () {
      expect(TimeControl.parse('180+2')?.incrementSeconds, 2);
      expect(TimeControl.parse('600')?.baseSeconds, 600);
      expect(TimeControl.parse('600')?.incrementSeconds, 0);
      expect(TimeControl.parse('40/7200:3600'), isNull);
      expect(TimeControl.parse('-'), isNull);
      expect(TimeControl.parse(null), isNull);
    });

    test('the time spent counts the increment, and the first move the base',
        () {
      // 1.e4: 180 before, 180 after, +2 increment — it took two seconds.
      expect(moveClock(clocks, 0, control)!.spent, 2);
      // 2.Nf3: 180 after the first move, 175 after this one, +2 — seven.
      expect(moveClock(clocks, 2, control)!.spent, 7);
      // 2...Nc6: 181.5 before, 179.9 after, +2.
      expect(moveClock(clocks, 3, control)!.spent, closeTo(3.6, 1e-9));
      expect(moveClock(clocks, 3, control)!.left, 179.9);
    });

    test('without the time control only the time left is said', () {
      final c = moveClock(clocks, 2, null)!;
      expect(c.left, 175);
      expect(c.spent, isNull);
      expect(clockWords('White', clocks, 2, null),
          "2 minutes 55 seconds left on White's clock.");
    });

    test('a move with no clock has none', () {
      expect(moveClock(<double?>[180, null], 1, control), isNull);
      expect(clockWords('Black', <double?>[180, null], 1, control), isNull);
      expect(moveClock(clocks, 9, control), isNull);
    });

    test('the words say it as a person would', () {
      expect(clockWords('White', <double?>[180, 180, 12, 20], 2, control),
          "12 seconds left on White's clock; the move took 2 minutes 50 seconds.");
      expect(clockWords('Black', <double?>[180, 180.2, 170, 179.5], 3, control),
          "3 minutes left on Black's clock; the move took 3 seconds.");
      expect(clockWords('White', <double?>[60.4, 60, 62], 2, control),
          "1 minute 2 seconds left on White's clock; the move took under a second.");
    });
  });

  test('a review carries the clocks of every move and the time control', () {
    final read = readAnalysisPgn(_lichess)!;
    final start = read.root.children.first; // after 1.e4
    final game = ReviewedGame.of(root: read.root, start: start);
    expect(game.pathUci, ['e2e4']);
    expect(game.clocks, [180, 181.5, 175, 179.9]);
    expect(game.timeControl, '180+2');
  });
}
