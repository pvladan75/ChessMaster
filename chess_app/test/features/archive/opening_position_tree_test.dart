// The tree a position of the opening report opens in Analysis with (the
// owner, 30.9.2026): the moves of the game that reached it, standing on it,
// and a branch for each move the report knows about there.
//
// Every FEN key and every engine line below is taken from a run of the
// server's chess.js (1.4), not written from memory — the keys are what
// `GET /games/openings/leaks` actually sends.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/archive/models/leak_report.dart';
import 'package:chess_app/features/archive/services/opening_position_tree.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// After 1.e4 c5 — a double push, so chess.js writes no en passant square
/// here and the app's `chess` package writes `c6`.
const _afterC5 = 'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq -';

/// After 1.e4 c5 2.Nf3 — Black to move.
const _afterNf3 = 'rnbqkbnr/pp1ppppp/8/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq -';

/// After 1.e4 c5 2.Nf3 d6 — White to move.
const _afterD6 = 'rnbqkbnr/pp2pppp/3p4/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq -';

const _toD6 =
    OpeningLine(startFen: _start, uciMoves: ['e2e4', 'c7c5', 'g1f3', 'd7d6']);

/// 14 plies each, as the engine hands a line back whole.
const _d4Line = [
  'd4', 'cxd4', 'Nxd4', 'Nf6', 'Nc3', 'a6', 'Be3', 'e5', 'Nb3', 'Be6', //
  'f3', 'Be7', 'Qd2', 'O-O',
];
const _bb5Line = [
  'Bb5+', 'Bd7', 'Bxd7+', 'Qxd7', 'O-O', 'Nc6', 'c3', 'Nf6', 'Re1', 'e6', //
  'd4', 'cxd4', 'cxd4', 'd5',
];

HabitJudgement _judged(
  HabitVerdict verdict, {
  required List<String> moveLine,
  required List<String> bestLine,
  required String bestUci,
  int depth = 20,
}) =>
    HabitJudgement(
      verdict: verdict,
      lostChances: verdict == HabitVerdict.mistake ? 14 : 2,
      bestUci: bestUci,
      bestSan: bestLine.first,
      bestLine: bestLine,
      moveLine: moveLine,
      depth: depth,
      engine: 'sf-test',
    );

List<String> _sans(Iterable<AnalysisNode> nodes) =>
    [for (final n in nodes) n.moveSan ?? '?'];

/// The main line from [node] down, as SAN.
List<String> _mainLine(AnalysisNode node) {
  final out = <String>[];
  var at = node;
  while (at.children.isNotEmpty) {
    at = at.children.first;
    out.add(at.moveSan!);
  }
  return out;
}

Iterable<AnalysisNode> _everyNode(AnalysisNode root) sync* {
  yield root;
  for (final child in root.children) {
    yield* _everyNode(child);
  }
}

String _head(String fen, int fields) =>
    fen.trim().split(RegExp(r'\s+')).take(fields).join(' ');

void main() {
  group('the line to the position', () {
    test('replays from the game\'s start and stands on the position', () {
      final tree = openingPositionTree(line: _toD6, fenKey: _afterD6)!;
      expect(tree.root.fen, _start);
      expect(tree.root.parent, isNull);
      expect(_mainLine(tree.root), ['e4', 'c5', 'Nf3', 'd6']);
      expect(tree.position.parent!.parent!.parent!.parent, same(tree.root));
      expect(_head(tree.position.fen, 3), _head(_afterD6, 3));
      expect(tree.position.children, isEmpty,
          reason: 'no branch was asked for');
    });

    test(
        'a position right after a double push is found, whatever the two '
        'libraries write for en passant', () {
      final tree = openingPositionTree(
        line: const OpeningLine(startFen: _start, uciMoves: ['e2e4', 'c7c5']),
        fenKey: _afterC5,
      );
      expect(tree, isNotNull,
          reason: 'the app writes c6 where the server writes -, and the '
              'board is the same');
      expect(tree!.position.fen.split(' ')[3], 'c6',
          reason: 'the fixture must hold the two spellings apart');
    });

    test('the start itself is a line with no moves', () {
      final tree = openingPositionTree(
        line: const OpeningLine(startFen: _start, uciMoves: []),
        fenKey: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq -',
      );
      expect(tree, isNotNull);
      expect(tree!.position, same(tree.root));
    });

    test(
        'a line one move short or one move long is refused, not opened on '
        'the wrong board', () {
      expect(
          openingPositionTree(
            line: const OpeningLine(
                startFen: _start, uciMoves: ['e2e4', 'c7c5', 'g1f3']),
            fenKey: _afterD6,
          ),
          isNull);
      expect(
          openingPositionTree(
            line: const OpeningLine(
                startFen: _start,
                uciMoves: ['e2e4', 'c7c5', 'g1f3', 'd7d6', 'd2d4']),
            fenKey: _afterD6,
          ),
          isNull);
    });

    test('a line with a move that does not play is refused whole', () {
      expect(
          openingPositionTree(
            line: const OpeningLine(
                startFen: _start, uciMoves: ['e2e4', 'c7c5', 'g1f3', 'e8e1']),
            fenKey: _afterD6,
          ),
          isNull);
    });

    test('the side to move and castling are part of the position', () {
      // Same placement as after 2...d6, other side to move.
      const blackToMove =
          'rnbqkbnr/pp2pppp/3p4/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq -';
      expect(openingPositionTree(line: _toD6, fenKey: blackToMove), isNull);
      const noCastling =
          'rnbqkbnr/pp2pppp/3p4/2p5/4P3/5N2/PPPP1PPP/RNBQKB1R w - -';
      expect(openingPositionTree(line: _toD6, fenKey: noCastling), isNull);
    });
  });

  group('the branches at the position', () {
    test(
        'a losing habit is the main line and the better move a variation, '
        'each cut as a reveal is cut', () {
      final habit = LosingHabit(
        fenKey: _afterD6,
        fen: '$_afterD6 0 1',
        ply: 5,
        nodeGames: 20,
        nodeScore: 0.6,
        san: 'd4',
        uci: 'd2d4',
        games: 12,
        score: 0.55,
        share: 0.6,
        habit: true,
        judgement: _judged(HabitVerdict.mistake,
            moveLine: _d4Line, bestLine: _bb5Line, bestUci: 'f1b5'),
        cost: 168,
        line: _toD6,
      );
      final tree = openingPositionTree(
        line: habit.line!,
        fenKey: habit.fenKey,
        branches: branchesOfHabit(habit),
      )!;
      expect(_sans(tree.position.children), ['d4', 'Bb5+']);
      // Material is level after four plies of each, so the reveal's rule
      // stops there — not at the fourteen the engine handed back.
      expect(_mainLine(tree.position.children[0]), ['cxd4', 'Nxd4', 'Nf6']);
      expect(_mainLine(tree.position.children[1]), ['Bd7', 'Bxd7+', 'Qxd7']);
    });

    test('a habit never judged is one move, and there is nothing to add', () {
      final habit = LosingHabit(
        fenKey: _afterD6,
        fen: '$_afterD6 0 1',
        ply: 5,
        nodeGames: 20,
        nodeScore: 0.6,
        san: 'd4',
        uci: 'd2d4',
        games: 12,
        score: 0.55,
        share: 0.6,
        habit: true,
        cost: 0,
      );
      expect(branchesOfHabit(habit), [
        ['d4']
      ]);
    });

    test(
        'a flagged position has every move the player chose, most played '
        'first, and the engine\'s choice last when the player never made it',
        () {
      final node = LeakReportNode(
        fenKey: _afterNf3,
        fen: '$_afterNf3 0 1',
        ply: 4,
        games: 10,
        score: 0.3,
        line: const OpeningLine(
            startFen: _start, uciMoves: ['e2e4', 'c7c5', 'g1f3']),
        moves: [
          LeakReportMove(
            san: 'Nc6',
            uci: 'b8c6',
            games: 6,
            score: 0.25,
            share: 0.6,
            habit: true,
            judgement: _judged(HabitVerdict.holds,
                moveLine: const ['Nc6', 'd4', 'cxd4', 'Nxd4', 'g6', 'Nc3'],
                bestLine: const ['d6', 'd4', 'cxd4', 'Nxd4', 'Nf6', 'Nc3'],
                bestUci: 'd7d6'),
          ),
          const LeakReportMove(
              san: 'e6', uci: 'e7e6', games: 3, score: 0.33, share: 0.3),
          const LeakReportMove(
              san: 'a6', uci: 'a7a6', games: 1, score: 0.5, share: 0.1),
        ],
      );
      final tree = openingPositionTree(
        line: node.line!,
        fenKey: node.fenKey,
        branches: branchesOfNode(node),
      )!;
      expect(_sans(tree.position.children), ['Nc6', 'e6', 'a6', 'd6']);
      expect(_mainLine(tree.position.children[0]), ['d4', 'cxd4', 'Nxd4'],
          reason: 'the judged habit carries its own line');
      expect(tree.position.children[1].children, isEmpty,
          reason: 'a move never judged has no line to show');
      expect(_mainLine(tree.position.children[3]), ['d4', 'cxd4', 'Nxd4']);
    });

    test(
        'when the engine\'s choice is a move the player made unjudged, it '
        'carries the best line once, and no second branch', () {
      final node = LeakReportNode(
        fenKey: _afterNf3,
        fen: '$_afterNf3 0 1',
        ply: 4,
        games: 10,
        score: 0.3,
        moves: [
          LeakReportMove(
            san: 'Nc6',
            uci: 'b8c6',
            games: 8,
            score: 0.25,
            share: 0.8,
            habit: true,
            judgement: _judged(HabitVerdict.mistake,
                moveLine: const ['Nc6', 'd4', 'cxd4', 'Nxd4', 'g6', 'Nc3'],
                bestLine: const ['d6', 'd4', 'cxd4', 'Nxd4', 'Nf6', 'Nc3'],
                bestUci: 'd7d6'),
          ),
          const LeakReportMove(
              san: 'd6', uci: 'd7d6', games: 2, score: 0.5, share: 0.2),
        ],
      );
      final branches = branchesOfNode(node);
      expect(branches, [
        ['Nc6', 'd4', 'cxd4', 'Nxd4', 'g6', 'Nc3'],
        ['d6', 'd4', 'cxd4', 'Nxd4', 'Nf6', 'Nc3'],
      ]);
    });

    test('a report without UCI on its moves still gives one branch per move',
        () {
      // The old report shape (before §9.2) sends no `uci`, so nothing tells
      // the engine's choice from the player's move but the tree itself.
      final node = LeakReportNode(
        fenKey: _afterNf3,
        fen: '$_afterNf3 0 1',
        ply: 4,
        games: 10,
        score: 0.3,
        moves: [
          LeakReportMove(
            san: 'Nc6',
            games: 8,
            score: 0.25,
            share: 0.8,
            habit: true,
            judgement: _judged(HabitVerdict.holds,
                moveLine: const ['Nc6', 'd4', 'cxd4', 'Nxd4', 'g6', 'Nc3'],
                bestLine: const ['Nc6', 'd4', 'cxd4', 'Nxd4', 'g6', 'Nc3'],
                bestUci: 'b8c6'),
          ),
        ],
      );
      final tree = openingPositionTree(
        line: const OpeningLine(
            startFen: _start, uciMoves: ['e2e4', 'c7c5', 'g1f3']),
        fenKey: _afterNf3,
        branches: branchesOfNode(node),
      )!;
      expect(branchesOfNode(node), hasLength(2),
          reason: 'the fixture must hand the tree the same move twice');
      expect(_sans(tree.position.children), ['Nc6']);
      expect(_mainLine(tree.position.children.single), ['d4', 'cxd4', 'Nxd4']);
      expect(tree.position.children.single.children, hasLength(1));
    });

    test('the deepest judgement gives the best line, the first of equals', () {
      LeakReportMove move(String san, String uci, int depth, String best) =>
          LeakReportMove(
            san: san,
            uci: uci,
            games: 4,
            score: 0.3,
            share: 0.4,
            habit: true,
            judgement: _judged(HabitVerdict.holds,
                moveLine: [san],
                bestLine: [best],
                bestUci: best == 'd6' ? 'd7d6' : 'e7e5',
                depth: depth),
          );
      final node = LeakReportNode(
        fenKey: _afterNf3,
        fen: '$_afterNf3 0 1',
        ply: 4,
        games: 10,
        score: 0.3,
        moves: [
          move('Nc6', 'b8c6', 18, 'e5'),
          move('e6', 'e7e6', 22, 'd6'),
          move('a6', 'a7a6', 22, 'e5'),
        ],
      );
      expect(branchesOfNode(node).last, ['d6']);
    });

    test('a line with a move that does not play keeps the moves before it', () {
      final habit = LosingHabit(
        fenKey: _afterD6,
        fen: '$_afterD6 0 1',
        ply: 5,
        nodeGames: 20,
        nodeScore: 0.6,
        san: 'd4',
        uci: 'd2d4',
        games: 12,
        score: 0.55,
        share: 0.6,
        habit: true,
        judgement: _judged(HabitVerdict.mistake,
            moveLine: const ['d4', 'cxd4', 'Qxa8'],
            bestLine: _bb5Line,
            bestUci: 'f1b5'),
        cost: 168,
      );
      final tree = openingPositionTree(
          line: _toD6, fenKey: _afterD6, branches: branchesOfHabit(habit))!;
      final d4 = tree.position.children.first;
      expect(d4.moveSan, 'd4');
      expect(_mainLine(d4), ['cxd4']);
    });

    test('nothing but moves goes into the tree', () {
      final habit = LosingHabit(
        fenKey: _afterD6,
        fen: '$_afterD6 0 1',
        ply: 5,
        nodeGames: 20,
        nodeScore: 0.6,
        san: 'd4',
        uci: 'd2d4',
        games: 12,
        score: 0.55,
        share: 0.6,
        habit: true,
        judgement: _judged(HabitVerdict.mistake,
            moveLine: _d4Line, bestLine: _bb5Line, bestUci: 'f1b5'),
        cost: 168,
      );
      final tree = openingPositionTree(
          line: _toD6, fenKey: _afterD6, branches: branchesOfHabit(habit))!;
      for (final node in _everyNode(tree.root)) {
        expect([for (final b in node.beats) b.comment].join(), isEmpty);
        expect(node.nag, isNull);
        expect(node.arrows, isEmpty);
      }
    });
  });

  test('a line reads from the report, and a missing one reads as none', () {
    expect(OpeningLine.fromJson(null), isNull);
    expect(OpeningLine.fromJson({'startFen': _start}), isNull);
    final line = OpeningLine.fromJson({
      'startFen': _start,
      'moves': ['e2e4', 'c7c5'],
    })!;
    expect(line.startFen, _start);
    expect(line.uciMoves, ['e2e4', 'c7c5']);
    final node = LeakReportNode.fromJson({
      'fenKey': _afterC5,
      'fen': '$_afterC5 0 1',
      'ply': 3,
      'games': 9,
      'score': 0.3,
      'moves': const [],
      'line': {'startFen': _start, 'moves': const []},
    });
    expect(node.line!.uciMoves, isEmpty,
        reason: 'an empty line is the start, not „no line"');
    final habit = LosingHabit.fromJson({
      'fenKey': _afterC5,
      'fen': '$_afterC5 0 1',
      'ply': 3,
      'nodeGames': 9,
      'nodeScore': 0.3,
      'san': 'Nf3',
      'games': 5,
      'score': 0.2,
      'share': 0.5,
      'cost': 10,
    });
    expect(habit.line, isNull);
  });
}
