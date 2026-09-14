// The answer line is not cut while the sacrifice is still unpaid.
//
// The owner, 14.9.2026, on "Punish, Count, Retreat: Three Missed Chances":
// a sideline ended on a position where White was better and it was not clear
// why - the piece had been given and the point of giving it was the move after
// the cut. Their proposal was to not cut such a line, or to show it whole.
//
// Measured over the ten fixture games before anything was written: 16 of 69
// answer parts ended with the mover down material, so it is about one in four
// rather than a corner case. Extending until material is level brings that to
// 7, and those seven are lines whose compensation is not material at all -
// they run to the end of what is stored, which is all there is to show.
//
// On g01 the line `g7 Qe8 h7+ Kxg7 h8=R Qxh8` runs 0, 0, 0, -1, +3, -2. Cut at
// four it stops on "a pawn down"; one ply further it stops on the promotion,
// which is the whole idea of the line.

import 'dart:convert';
import 'dart:io';

import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/tutorial_studio/services/game_tutorial/board_queries.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_moments.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_parameters.dart';

const _fixtures = 'test/fixtures/game_tutorial';

/// White to move, a rook down after the exchange on a7 and a queen to win back
/// on d5. Built rather than taken from a game, so the material after every ply
/// is visible in the test: from -1 it runs 0, -5, -5, -5, +4.
const _sacFen = 'r5k1/p7/8/3q4/8/8/8/R2Q2K1 w - - 0 1';

List<Map<String, dynamic>> _games() {
  final files = Directory(_fixtures)
      .listSync()
      .whereType<File>()
      .where((f) => RegExp(r'g\d\d_[a-z-]+\.json$').hasMatch(f.path))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final f in files)
      jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
  ];
}

/// Material from [mover]'s side after each ply of [line].
List<int> _materialAfterEachPly(String fen, String mover, List<String> line) {
  final board = chess.Chess.fromFEN(fen);
  final sign = mover == 'White' ? 1 : -1;
  return [
    for (final san in line)
      if (board.move(san)) sign * materialOf(board) else -9999,
  ];
}

int _startMaterial(String fen, String mover) =>
    (mover == 'White' ? 1 : -1) * materialOf(chess.Chess.fromFEN(fen));

void main() {
  const defaults = SkeletonParameters();

  group('answerPlyCount', () {
    test('a quiet line stops where it always did', () {
      expect(
        answerPlyCount(_sacFen, 'White',
            const ['Rb1', 'Rb8', 'Ra1', 'Ra8', 'Rb1', 'Rb8'], defaults),
        defaults.answerPlies,
      );
    });

    test('a line still down material at the cut runs on until it is not', () {
      const line = ['Rxa7', 'Rxa7', 'Qh5', 'Ra8', 'Qxd5+', 'Kf8'];
      // -5 after four plies against -1 at the start, and +4 after five.
      expect(
          _materialAfterEachPly(_sacFen, 'White', line), [0, -5, -5, -5, 4, 4]);
      expect(answerPlyCount(_sacFen, 'White', line, defaults), 5);
    });

    test('a line that never pays is shown whole rather than cut short', () {
      const line = ['Rxa7', 'Rxa7', 'Qh5', 'Ra8', 'Qh6', 'Ra1+'];
      expect(answerPlyCount(_sacFen, 'White', line, defaults), line.length);
    });

    test('the cap bounds it, whatever the line does', () {
      const line = ['Rxa7', 'Rxa7', 'Qh5', 'Ra8', 'Qxd5+', 'Kf8'];
      // The same line that reaches five plies above stops at four here, so the
      // cap is doing the stopping and not the material.
      expect(
        answerPlyCount(_sacFen, 'White', line,
            const SkeletonParameters(maxAnswerPlies: 4)),
        4,
      );
    });

    test('a line shorter than the cut is all of it', () {
      expect(
          answerPlyCount(_sacFen, 'White', const ['Qh5', 'Kf8'], defaults), 2);
    });

    test('no line, nothing to show',
        () => expect(answerPlyCount(_sacFen, 'White', const [], defaults), 0));
  });

  group('over the ten games, no part ends mid-sacrifice', () {
    for (final game in _games()) {
      test('${game['game']}', () {
        final facts = game['facts'] as Map<String, dynamic>;
        final rows = (facts['rows'] as List).cast<Map<String, dynamic>>();
        var checked = 0;
        for (final moment in skeletonMoments(facts)) {
          final row = rows[moment['index'] as int];
          final mover = row['to_move'] as String;
          final fen = row['fen'] as String;
          final line = ((row['candidates'] as List).first['line'] as String)
              .split(RegExp(r'\s+'))
              .where((t) => t.isNotEmpty)
              .toList();
          final shown = answerPlyCount(fen, mover, line, defaults);
          final after = _materialAfterEachPly(fen, mover, line);
          final start = _startMaterial(fen, mover);

          // The rule, stated as what must be true of every answer part: either
          // it ends with the mover not down material, or there was nothing
          // further to show. Never "it ended down material with more to come".
          final endsDown = shown > 0 && after[shown - 1] < start;
          if (endsDown) {
            expect(shown, anyOf(line.length, defaults.maxAnswerPlies),
                reason: '${moment['id']} ends $start -> ${after[shown - 1]} '
                    'with $shown of ${line.length} plies shown');
          }
          checked++;
        }
        expect(checked, greaterThan(0));
      });
    }
  });

  test('the extension is surgical, not a blanket lengthening', () {
    var extended = 0, total = 0;
    for (final game in _games()) {
      final facts = game['facts'] as Map<String, dynamic>;
      final rows = (facts['rows'] as List).cast<Map<String, dynamic>>();
      for (final moment in skeletonMoments(facts)) {
        final row = rows[moment['index'] as int];
        final line = ((row['candidates'] as List).first['line'] as String)
            .split(RegExp(r'\s+'))
            .where((t) => t.isNotEmpty)
            .toList();
        total++;
        if (answerPlyCount(row['fen'] as String, row['to_move'] as String, line,
                defaults) >
            defaults.answerPlies) {
          extended++;
        }
      }
    }
    // Sixteen of sixty-nine when this was written. Pinned as a band rather than
    // a number: the point is that most parts are untouched, and that the rule
    // has not quietly become "always show six".
    expect(total, 69);
    expect(extended, inInclusiveRange(10, 25));
  });

  test('the fixtures miss only the plies their recorded answer never saw', () {
    // The ten recorded model answers were written against four-ply requests, so
    // the plies this rule added have no text in them. Held here rather than
    // left as an oddity: it explains every missing slot in the fixtures, and it
    // fails loudly if a future change starts losing slots of any other kind.
    for (final game in _games()) {
      final missing =
          ((game['expected']['report']['missing_slots'] as List?) ?? const [])
              .cast<String>();
      for (final slot in missing) {
        final match = RegExp(r'^m\d+\.answer\.(\d+)$').firstMatch(slot);
        expect(match, isNotNull,
            reason: '${game['game']}: $slot is not an answer ply');
        expect(int.parse(match!.group(1)!),
            greaterThan(const SkeletonParameters().answerPlies),
            reason: '${game['game']}: $slot was offered before this change');
      }
    }
  });
}
