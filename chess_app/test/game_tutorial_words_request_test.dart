// Phase 4 of `docs/PLAN-SKELET.md`: the request the app sends for the words.
//
// Held to `expected.wordsRequest`, which the harness writes, on every fixture
// game. The server's test holds its prompt from that same request to the
// harness's prompt byte for byte, so these two tests together say the app's
// request becomes the validated prompt.
//
// One field is compared by its moves rather than its text: the game. The
// harness quotes python-chess's movetext, wrapped at 80 columns; the app writes
// its own on one line. The model reads the same moves either way, and neither
// text ever carries the players' names.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/tutorial_studio/services/game_tutorial/words_request.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';

const _fixtures = 'test/fixtures/game_tutorial';
const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

List<Map<String, dynamic>> _games() {
  final files = Directory(_fixtures)
      .listSync()
      .whereType<File>()
      .where((f) => RegExp(r'g\d\d_[a-z-]+\.json$').hasMatch(f.path))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final f in files)
      jsonDecode(f.readAsStringSync()) as Map<String, dynamic>
  ];
}

/// The moves of a movetext, without numbers, results or line breaks.
List<String> _moves(String movetext) => movetext
    .split(RegExp(r'\s+'))
    .where((t) =>
        t.isNotEmpty &&
        !RegExp(r'^\d+\.+$').hasMatch(t) &&
        !const {'*', '1-0', '0-1', '1/2-1/2'}.contains(t))
    .map((t) => t.replaceFirst(RegExp(r'^\d+\.+'), ''))
    .toList();

void main() {
  final games = _games();

  test('there are ten games to hold the request to', () {
    expect(games, hasLength(10));
  });

  for (final game in games) {
    test('the request for ${game['game']} is the harness\'s', () {
      final read = readStepTree(fen: _start, pgn: game['plainPgn'] as String);
      expect(read.rejectedMoves, 0);
      final sans = <String>[
        for (var node = read.root;
            node.children.isNotEmpty;
            node = node.children.first)
          node.children.first.moveSan!
      ];
      final movetext = movetextOf(_start, sans);
      final made = wordsRequestOf(
        game['facts'] as Map<String, dynamic>,
        movetext: movetext,
      );
      final expected = game['expected']['wordsRequest'] as Map<String, dynamic>;

      expect(jsonEncode(made['moments']), jsonEncode(expected['moments']));
      expect(made['opening'], expected['opening']);
      expect(
          _moves(made['game'] as String), _moves(expected['game'] as String));
      expect(made['game'], isNot(contains('[')),
          reason: 'no header ever leaves the device');
    });
  }

  test('a game the masters database never reached sends no opening', () {
    // Every fixture game has an opening, so the harness's `or None` is
    // otherwise never reached.
    final facts =
        jsonDecode(jsonEncode(games.first['facts'])) as Map<String, dynamic>;
    for (final row in (facts['rows'] as List).cast<Map<String, dynamic>>()) {
      row.remove('book');
      final played = row['played'];
      if (played is Map) played.remove('left_book');
    }
    final made = wordsRequestOf(facts, movetext: '1. e4');
    expect(made.containsKey('opening'), isTrue);
    expect(made['opening'], isNull,
        reason: 'the harness sends None, not an empty line');
  });

  group('movetextOf', () {
    test('numbers from the start of a game', () {
      expect(movetextOf(_start, ['e4', 'e5', 'Nf3']), '1. e4 e5 2. Nf3');
    });

    test('a game that starts with Black to move says so once', () {
      const fen = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 5';
      expect(movetextOf(fen, ['e5', 'Nf3', 'Nc6']), '5... e5 6. Nf3 Nc6');
    });

    test('no moves is no text', () {
      expect(movetextOf(_start, const []), '');
    });
  });
}
