// endgame_analysis_tree_test.dart — the tree of docs/PLAN-TRENER-ZAVRSNICA.md
// phase 5, pure: what `Open in Analysis` hands Analysis from what the trainer
// knows (D1, D6, D14, D15).

import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/endgame_trainer/services/endgame_analysis_tree.dart';

/// White to keep the win: Kd2, Kf1 and e8=N hold; the server lists them in
/// its own order, the underpromotion first.
const _start = '8/4P3/8/8/8/8/1p6/4K2k w - - 0 1';
const _holding = ['e7e8n', 'e1d2', 'e1f1'];

/// The position after [ucis] from [fen], by the chess package.
String _after(String fen, List<String> ucis) {
  final board = chess.Chess.fromFEN(fen);
  for (final uci in ucis) {
    final ok = board.move({
      'from': uci.substring(0, 2),
      'to': uci.substring(2, 4),
      if (uci.length > 4) 'promotion': uci.substring(4),
    });
    expect(ok, isNot(false), reason: '$uci from $fen');
  }
  return board.fen;
}

List<String?> _ucis(AnalysisNode node) =>
    node.children.map((c) => c.moveUci).toList();

AnalysisNode _childOf(AnalysisNode node, String uci) =>
    node.children.singleWhere((c) => c.moveUci == uci);

Iterable<AnalysisNode> _all(AnalysisNode node) sync* {
  yield node;
  for (final child in node.children) {
    yield* _all(child);
  }
}

/// The board part of a FEN.
String _placement(String fen) => fen.split(' ').first;

EndgameTreeInput _input({
  List<String> found = const ['e1d2', 'e1f1'],
  Map<String, String?> replies = const {'e1d2': 'b2b1n'},
  String? gameMoveSan = 'Ke2',
  DrillLog? drill,
}) =>
    EndgameTreeInput(
      fen: _start,
      found: found,
      replies: replies,
      holding: _holding,
      gameMoveSan: gameMoveSan,
      drill: drill?.moves ?? const [],
      drillFromGameMove: drill?.fromGameMove ?? false,
    );

void main() {
  test(
      'the root is the puzzle; the reader\'s moves, then the others, then '
      'the game\'s', () {
    final tree = endgameAnalysisTree(_input());
    expect(tree.root.fen, _start);
    expect(_ucis(tree.root), ['e1d2', 'e1f1', 'e7e8n', 'e1e2']);
    expect(tree.standOn, same(tree.root));
  });

  test(
      'each found move carries its reply; one whose reply never came is a '
      'leaf', () {
    final tree = endgameAnalysisTree(_input());
    final kd2 = _childOf(tree.root, 'e1d2');
    expect(_ucis(kd2), ['b2b1n']);
    expect(_childOf(tree.root, 'e1f1').children, isEmpty);
    // The reply hangs under its move, not beside it.
    expect(_ucis(tree.root), isNot(contains('b2b1n')));
  });

  test('an underpromotion is replayed as the piece it was', () {
    final tree = endgameAnalysisTree(_input());
    final reply = _childOf(_childOf(tree.root, 'e1d2'), 'b2b1n');
    expect(_placement(reply.fen), '8/4P3/8/8/8/8/3K4/1n5k');
    final e8n = _childOf(tree.root, 'e7e8n');
    expect(_placement(e8n.fen), '4N3/8/8/8/8/8/1p6/4K2k');
  });

  test('a game\'s move that also holds is one node, not two', () {
    final tree = endgameAnalysisTree(_input(gameMoveSan: 'Kd2'));
    expect(_ucis(tree.root), ['e1d2', 'e1f1', 'e7e8n']);
  });

  test('a position with no game\'s move adds no branch', () {
    final tree = endgameAnalysisTree(_input(gameMoveSan: null));
    expect(_ucis(tree.root), ['e1d2', 'e1f1', 'e7e8n']);
  });

  group('the drill', () {
    test(
        'a drill whose first move holds continues under that branch, and '
        'Analysis stands where it stopped', () {
      final afterReply = _after(_start, ['e1d2', 'b2b1n']);
      final log = DrillLog()..start(fromGameMove: false);
      log.played(_start, 'e1d2', replyUci: 'b2b1n');
      log.played(afterReply, 'd2c2', replyUci: 'b1a3');

      final tree = endgameAnalysisTree(_input(drill: log), fromDrill: true);
      expect(_ucis(tree.root), ['e1d2', 'e1f1', 'e7e8n', 'e1e2']);
      final kd2 = _childOf(tree.root, 'e1d2');
      final reply = _childOf(kd2, 'b2b1n');
      final kc2 = _childOf(reply, 'd2c2');
      final last = _childOf(kc2, 'b1a3');
      expect(tree.standOn, same(last));
    });

    test(
        'a drill whose first move loses adds a last branch, and Analysis '
        'stands on it', () {
      final log = DrillLog()..start(fromGameMove: false);
      log.played(_start, 'e1f2');
      final tree = endgameAnalysisTree(_input(drill: log), fromDrill: true);
      expect(_ucis(tree.root), ['e1d2', 'e1f1', 'e7e8n', 'e1e2', 'e1f2']);
      expect(tree.standOn, same(_childOf(tree.root, 'e1f2')));
    });

    test('opened from solving, it stands on the root even with a drill kept',
        () {
      final log = DrillLog()..start(fromGameMove: false);
      log.played(_start, 'e1f2');
      final tree = endgameAnalysisTree(_input(drill: log));
      expect(tree.standOn, same(tree.root));
    });

    test('a Punish line hangs under the game\'s move', () {
      final afterGame = _after(_start, ['e1e2']);
      final log = DrillLog()..start(fromGameMove: true);
      log.played(afterGame, 'b2b1q', replyUci: 'e7e8q');
      final tree = endgameAnalysisTree(_input(drill: log), fromDrill: true);
      final ke2 = _childOf(tree.root, 'e1e2');
      expect(_ucis(ke2), ['b2b1q']);
      expect(tree.standOn, same(_childOf(_childOf(ke2, 'b2b1q'), 'e7e8q')));
      expect(_ucis(tree.root), ['e1d2', 'e1f1', 'e7e8n', 'e1e2']);
    });

    test('Take back keeps every taken-back move as a side branch (D15)', () {
      final log = DrillLog()..start(fromGameMove: false);
      log.played(_start, 'e1f2');
      log.takeBack();
      log.played(_start, 'e1e2');
      log.takeBack();
      log.played(_start, 'e1d2', replyUci: 'b2b1n');

      final tree = endgameAnalysisTree(_input(gameMoveSan: null, drill: log),
          fromDrill: true);
      // Both taken back, from the same position: kept, not only the last.
      expect(_ucis(tree.root), ['e1d2', 'e1f1', 'e7e8n', 'e1f2', 'e1e2']);
      expect(_childOf(tree.root, 'e1f2').children, isEmpty);
      expect(_childOf(tree.root, 'e1e2').children, isEmpty);
      // The move played instead continues the line.
      final kd2 = _childOf(tree.root, 'e1d2');
      expect(tree.standOn, same(_childOf(kd2, 'b2b1n')));
    });

    test('Start over leaves no branch', () {
      final log = DrillLog()..start(fromGameMove: false);
      log.played(_start, 'e1f2');
      log.start(fromGameMove: false);
      final tree = endgameAnalysisTree(_input(gameMoveSan: null, drill: log),
          fromDrill: true);
      expect(_ucis(tree.root), ['e1d2', 'e1f1', 'e7e8n']);
    });
  });

  test(
      'no node carries a comment, a NAG, an arrow or a square, and every '
      'node is its parent after its move', () {
    final afterReply = _after(_start, ['e1d2', 'b2b1n']);
    final log = DrillLog()..start(fromGameMove: false);
    log.played(_start, 'e1f2');
    log.takeBack();
    log.played(_start, 'e1d2', replyUci: 'b2b1n');
    log.played(afterReply, 'd2c2', replyUci: 'b1a3');
    final tree = endgameAnalysisTree(_input(drill: log), fromDrill: true);

    var count = 0;
    for (final node in _all(tree.root)) {
      count++;
      expect(node.comment, isEmpty, reason: node.moveSan);
      expect(node.nag, isNull, reason: node.moveSan);
      expect(node.arrows, isEmpty, reason: node.moveSan);
      expect(node.squares, isEmpty, reason: node.moveSan);
      for (final child in node.children) {
        expect(child.fen, _after(node.fen, [child.moveUci!]),
            reason: '${child.moveSan} after ${node.fen}');
      }
    }
    expect(count, greaterThan(8));
  });
}
