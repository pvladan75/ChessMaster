// Where a game stops following the masters, said on the position that really is
// that position.
//
// The statistic used to be written onto the move that left the book, which in
// PGN is the comment on the position **after** it — so a student stood on a
// board no master game had ever reached and read „698 master games reached this
// position and none played it". The owner read that on 15.9.2026 and asked for
// three things: the count on the position before the move, the moves the
// database does play there named and drawn as arrows, and then the move that
// was actually played.
//
// `game_tutorial_skeleton_test.dart` proves the port agrees with the harness;
// this file states the rule itself, in the terms a reader can check — which
// move carries the sentence, and what the arrows on it are.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/lessons/models/lesson_step_line.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/board_queries.dart'
    show findMove;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_assembly.dart';
import 'package:chess_app/move_tree.dart' show PgnLine;
import 'package:chess/chess.dart' as chess;

const _game = 'g05_french-defense';
const _said = 'followed the masters database';

Map<String, dynamic> _fixture() => jsonDecode(
        File('test/fixtures/game_tutorial/$_game.json').readAsStringSync())
    as Map<String, dynamic>;

/// The pieces and the side to move, which is what „the same board" means
/// here.
///
/// Not `MoveTree.samePosition`: it also compares the en passant square, and
/// the two writers disagree about that field rather than about the position.
/// The facts are python-chess's, which writes `-` unless a capture is really
/// available; `package:chess` replays `4. c4` and writes `c3` whether or not
/// anything can take there.
String _board(String fen) => fen.trim().split(RegExp(r'\s+')).take(2).join(' ');

/// The row the game left the book on.
(int, Map<String, dynamic>) _departure(List rows) {
  for (var i = 0; i < rows.length; i++) {
    final row = (rows[i] as Map).cast<String, dynamic>();
    final played = row['played'] as Map<String, dynamic>?;
    if (played != null && played['left_book'] == true && row['book'] != null) {
      return (i, row);
    }
  }
  fail('$_game never leaves the masters database');
}

void main() {
  final fixture = _fixture();
  final facts = fixture['facts'] as Map<String, dynamic>;
  final rows = facts['rows'] as List;
  final (index, row) = _departure(rows);
  final book = row['book'] as Map<String, dynamic>;
  final alternatives = (book['alternatives'] as List).cast<Map>();

  final assembly = assembleSkeleton(
      fixture['facts'] as Map<String, dynamic>, fixture['answer'] as String);
  final steps = assembly.tutorialGame!['positionList'] as List;

  /// The one step that says it, read back through the child's own reader, with
  /// the index of the move whose comment carries the sentence.
  (PgnLine, int) reading() {
    for (final step in steps.cast<Map<String, dynamic>>()) {
      final line = LessonStepLine.read(
              fen: step['fen'] as String, pgn: step['pgn'] as String)
          .line;
      for (var m = 0; m < line.comments.length; m++) {
        if (line.comments[m].contains(_said)) return (line, m);
      }
      if (line.rootComment.contains(_said)) return (line, -1);
    }
    fail('no part of the whole game says where the book ended');
  }

  test('the sentence sits on the position the departing move is played from',
      () {
    final (line, m) = reading();
    // The move after the one that carries the sentence is the move that left
    // the book, and it is played from the position the sentence counts.
    expect(line.movesSan[m + 1], row['played']['move'],
        reason: 'the move after the sentence');
    expect(_board(line.fens[m + 1]), _board(row['fen'] as String),
        reason: 'the board the sentence is read on');
  });

  test('it names the moves the database plays there, and draws each one', () {
    final (line, m) = reading();
    final said = line.comments[m];
    expect(alternatives, isNotEmpty, reason: 'the fixture has alternatives');
    for (final alternative in alternatives) {
      expect(said, contains(alternative['move'] as String));
    }
    final board = chess.Chess.fromFEN(row['fen'] as String);
    expect(
      [for (final a in line.arrows[m]) a.toString()],
      [
        for (final alternative in alternatives)
          () {
            final move = findMove(board, alternative['move'] as String);
            return 'G${move.fromAlgebraic}${move.toAlgebraic}';
          }()
      ],
      reason: 'one green arrow per move named, in the order they are named',
    );
  });

  test(
      'it counts the games that reached that position, and says whose move it '
      'is next', () {
    final (line, m) = reading();
    expect(line.comments[m], contains('${book['games']} master games'));
    expect(line.comments[m],
        contains("${row['to_move']} played ${row['played']['move']}"));
  });

  test('the retired wording is gone from both tutorials', () {
    for (final tutorial in [assembly.tutorial!, assembly.tutorialGame!]) {
      for (final step in (tutorial['positionList'] as List).cast<Map>()) {
        expect(step['pgn'] ?? '', isNot(contains('left the masters database')));
      }
    }
  });
}
