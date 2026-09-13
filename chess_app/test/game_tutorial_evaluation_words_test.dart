// Phase 1 of `docs/PLAN-SKELET.md`, the lead's half: the first two functions of
// the skeleton ported from `tools/game_annotate/skeleton.py`, and the proof
// that the rest of the phase can be held to the harness at all.
//
// Every expectation here was written by the harness, not by hand:
// `tools/game_annotate/export_fixtures.py` computes them from `skeleton.py` and
// `--check` fails when the two part. So this file cannot agree with a port that
// disagrees with the reference, and neither can the batch's gate.
//
// The last group is not about these two functions. The batch will write each
// part's `pgn` through the app's own writer (`StudioLessonStep.from`), and the
// fixtures hold python-chess's text, wrapped at 80 columns. Byte equality is
// impossible, so the gate compares what the child's reader reads back. That
// comparison is only fair if python-chess's text and the app's writer read back
// the same for every part of every fixture — which is what the group proves,
// before any batch depends on it.

import 'dart:convert';
import 'dart:io';

import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/studio_lesson_step.dart';
import 'package:chess_app/features/lessons/models/lesson_step_line.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/evaluation_words.dart';

const _fixtures = 'test/fixtures/game_tutorial';

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> _games() {
  final files = Directory(_fixtures)
      .listSync()
      .whereType<File>()
      .where((f) => RegExp(r'g\d\d_[a-z-]+\.json$').hasMatch(f.path))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return [for (final f in files) _read(f.path)];
}

String _spaced(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

/// A part's line rebuilt as the port will build it: a chain of nodes carrying
/// the moves and the words, written by the app's one writer.
StudioLessonStep _rewritten(String fen, LessonStepLine read) {
  final line = read.line;
  final root = AnalysisNode(fen: fen, comment: line.rootComment);
  var parent = root;
  final board = chess.Chess.fromFEN(fen);
  for (var i = 0; i < line.movesSan.length; i++) {
    expect(board.move(line.movesSan[i]), isTrue,
        reason: 'the app cannot play ${line.movesSan[i]} from ${board.fen}');
    final node = AnalysisNode(
      fen: board.fen,
      moveSan: line.movesSan[i],
      comment: line.comments[i],
      parent: parent,
    );
    parent.children.add(node);
    parent = node;
  }
  return StudioLessonStep.from(root);
}

void main() {
  final games = _games();
  final cases = _read('$_fixtures/evaluation_words_cases.json');

  test('the ten games of the harness are all here', () {
    expect(games.map((g) => g['game']), hasLength(10));
  });

  group('wordsFor', () {
    for (final game in games) {
      test('${game['game']}: every evaluation the game carries', () {
        final table =
            (game['expected']['wordsFor'] as Map).cast<String, String>();
        expect(table, isNotEmpty);
        for (final entry in table.entries) {
          expect(wordsFor(entry.key), entry.value, reason: entry.key);
        }
      });
    }

    test('the boundaries, as the harness answered them', () {
      for (final row in cases['wordsFor'] as List) {
        final evalText = row[0] as String?;
        expect(wordsFor(evalText), row[1], reason: '$evalText');
      }
    });
  });

  group('standing', () {
    for (final game in games) {
      test('${game['game']}: every evaluation, from both sides', () {
        final rows = game['expected']['standing'] as List;
        expect(rows, isNotEmpty);
        for (final row in rows) {
          expect(standing(row[0] as String?, row[1] as String), row[2],
              reason: '${row[0]} for ${row[1]}');
        }
      });
    }

    test('the boundaries, and an unknown evaluation', () {
      for (final row in cases['standing'] as List) {
        expect(standing(row[0] as String?, row[1] as String), row[2],
            reason: '${row[0]} for ${row[1]}');
      }
    });
  });

  group('a part written by the app reads back as the harness wrote it', () {
    for (final game in games) {
      test('${game['game']}: every part of both tutorials', () {
        var parts = 0;
        for (final kind in ['tutorial', 'tutorialGame']) {
          for (final step in game['expected'][kind]['positionList'] as List) {
            if (step['kind'] != 'show') continue;
            final fen = step['fen'] as String;
            final harness = LessonStepLine.read(fen: fen, pgn: step['pgn']);
            expect(harness.rejectedMoves, 0, reason: '$kind: ${step['title']}');
            expect(harness.line.movesSan, isNotEmpty);

            final app = _rewritten(fen, harness);
            expect(app.replays, isTrue, reason: '$kind: ${step['title']}');
            expect(app.line.movesSan, harness.line.movesSan);
            expect(_spaced(app.line.rootComment),
                _spaced(harness.line.rootComment));
            expect(app.line.comments.map(_spaced).toList(),
                harness.line.comments.map(_spaced).toList(),
                reason: '$kind: ${step['title']}');
            parts++;
          }
        }
        // Not vacuous: g08, the game with the fewest moments, has nine.
        expect(parts, greaterThanOrEqualTo(9));
      });
    }
  });
}
