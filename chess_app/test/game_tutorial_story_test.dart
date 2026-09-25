// The story shape of a game tutorial — docs/PLAN-NARACIJA.md, 15.9.2026.
//
// The owner read ten games written twice and chose to replace the old prompt
// with the story one. What that shape promises, and what these tests hold the
// port to beyond the harness gate:
//
//   * at a mistake the program says „In this position White played Bd3." over
//     the board, draws the move as a blue arrow without playing it, and ends
//     the part on „The best move was…"; the best line follows in a part of its
//     own, with no introduction;
//   * the tutorial opens on what kind of game is coming and ends on who came out
//     on top, where it used to end on „The game ended here.";
//   * the claim check reads the moment so far, not one slot, and a word said
//     not to be there is not a claim that it is.
//
// Assembled here, not read out of the fixture: a fixture is what `skeleton.py`
// made, and says nothing about what this code does.

import 'dart:convert';
import 'dart:io';

import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/lessons/models/lesson_step_line.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/board_queries.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_assembly.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_moments.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/words_request.dart';

const _fixtures = 'test/fixtures/game_tutorial';

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

Set<String> _tokens(String text) =>
    text.split(RegExp(r'[^A-Za-z0-9+#=-]+')).where((t) => t.isNotEmpty).toSet();

/// What a part says aloud, read the way the child's viewer reads it.
({String root, List<String> comments, List<String> moves}) _said(Map step) {
  final read = LessonStepLine.read(
      fen: step['fen'] as String, pgn: step['pgn'] as String? ?? '');
  return (
    root: read.line.rootComment.trim(),
    comments: [for (final c in read.line.comments) c.trim()],
    moves: read.line.movesSan,
  );
}

void main() {
  final games = _games();

  test('the ten games are all here', () => expect(games, hasLength(10)));

  group('at a mistake: what was played, drawn, then the best line', () {
    for (final game in games) {
      test('${game['game']}', () {
        final facts = game['facts'] as Map<String, dynamic>;
        final moments = skeletonMoments(facts);
        expect(moments, isNotEmpty);
        for (final m in moments) {
          final id = m['id'] as String;
          final parts = (m['parts'] as List).cast<Map<String, dynamic>>();
          final forks = parts.where((p) => p['program'] == true).toList();
          expect(forks, hasLength(1), reason: '$id: one program part');
          final fork = forks.single;
          final at = parts.indexOf(fork);
          final answer = parts[at + 1];

          expect(fork['moves'], isEmpty, reason: '$id: the move is not played');
          expect(fork['intro'], '$id.fork');
          expect(answer['sideline'], isTrue,
              reason: '$id: the best line follows at once');
          expect(answer['alternative'], isNot(isTrue));
          expect(answer['intro'], isNull,
              reason: '$id: „The best move was…" is the introduction');
          expect((m['slots'] as Map).containsKey('$id.answer.intro'), isFalse);

          final san = (m['played'] as String).split(' ').last;
          final mover = m['mover'] as String;
          // An only move the player found says what it is (phase 1b of
          // docs/PLAN-ZAGONETKE-IZ-PARTIJE.md): the game played the best move.
          expect(
              (m['program'] as Map)['$id.fork'],
              m['kind'] == 'only'
                  ? 'In this position $mover found the only move that held…'
                  : 'In this position $mover played $san. The best move was…');
          expect(_tokens((m['program'] as Map)['$id.fork'] as String),
              isNot(contains(m['best'])),
              reason: '$id: a move read before it is played is given away');

          final board = chess.Chess.fromFEN(fork['fen'] as String);
          final move = findMove(board, san);
          expect(fork['arrow'], [move.fromAlgebraic, move.toAlgebraic],
              reason: '$id: the arrow is the move that was played');
        }
      });
    }
  });

  test('the program\'s part is no slot of the model\'s', () {
    for (final game in games) {
      final request = wordsRequestOf(game['facts'] as Map<String, dynamic>,
          movetext: '1. e4');
      for (final m in (request['moments'] as List).cast<Map>()) {
        for (final slot in (m['slots'] as List).cast<Map>()) {
          expect(slot['id'], isNot(endsWith('.fork')), reason: game['game']);
        }
        expect(m['events'], isA<List>());
      }
      expect(request['arc'], isA<Map>());
      expect((request['arc'] as Map).keys, ['opening', 'ending']);
    }
  });

  group('both tutorials', () {
    for (final game in games) {
      test('${game['game']}: the arrow, the beginning and the end', () {
        final facts = game['facts'] as Map<String, dynamic>;
        final answer = jsonDecode(game['answer'] as String) as Map;
        final opening = (answer['slots'] as Map)['story.opening'] as String;
        final ending = (answer['slots'] as Map)['story.ending'] as String;
        final assembly = assembleSkeleton(facts, game['answer'] as String);

        for (final tutorial in [assembly.tutorial!, assembly.tutorialGame!]) {
          final steps = (tutorial['positionList'] as List).cast<Map>();

          final forks = steps
              .where((s) =>
                  (s['pgn'] as String? ?? '').contains('In this position'))
              .toList();
          expect(forks, isNotEmpty);
          for (final step in forks) {
            expect(step['pgn'], contains('[%cal B'),
                reason: 'the move played is drawn in blue');
          }

          expect(_said(steps.first).root, startsWith(opening),
              reason: 'the first words the student hears');

          // The whole game ends on its own last move; the recap after it is a
          // line that was never played.
          final last = tutorial == assembly.tutorialGame
              ? steps.lastWhere((s) =>
                  !(s['pgn'] as String).contains('Looking back, the game'))
              : steps.last;
          final lastSaid = _said(last);
          final lastWords =
              lastSaid.moves.isEmpty ? lastSaid.root : lastSaid.comments.last;
          expect(lastWords, endsWith(ending),
              reason: 'the last words the student hears');
          for (final step in steps) {
            expect(step['pgn'] ?? '', isNot(contains('The game ended here.')));
          }
        }
      });
    }
  });

  group('the claim check reads the moment, not the slot', () {
    const facts = {'text': 'Nf3 by White (knight g1-f3)', 'motifs': ''};

    test('a pin carried over from the slot before is backed', () {
      expect(claimsFor('m1.lead.2', 'The pin is broken.', facts),
          ['m1.lead.2 names a pin the facts do not show']);
      expect(
          claimsFor('m1.lead.2', 'The pin is broken.', facts,
              'pinned to their king afterwards: c6'),
          isEmpty);
    });

    test('a word said not to be there is not a claim', () {
      expect(
          claimsFor(
              'm1.answer.3', 'Black keeps the better game but no mate.', facts),
          isEmpty);
      expect(claimsFor('m1.answer.3', 'This is mate.', facts),
          ['m1.answer.3 speaks of mate, and the facts of that slot have none']);
    });

    test('a forced mate in the facts backs „win"', () {
      expect(
          claimsFor('m7.lead.intro', 'Black has a forced win in hand.',
              {'text': 'Black to move, Black mates in 5', 'motifs': ''}),
          isEmpty);
      expect(
          claimsFor('m7.lead.intro', 'Black has a forced win in hand.',
              {'text': 'Black to move, Black is clearly better', 'motifs': ''}),
          [
            'm7.lead.intro says a move wins, and the facts show no material won'
          ]);
    });
  });

  group('a move left in silence', () {
    final g01 = games.first;
    final facts = g01['facts'] as Map<String, dynamic>;
    final real = jsonDecode(g01['answer'] as String) as Map<String, dynamic>;
    final first = (real['chosen'] as List).first as String;

    Map<String, dynamic> report(String slot) => assembleSkeleton(
          facts,
          jsonEncode({
            ...real,
            'slots': {...(real['slots'] as Map), slot: ''},
          }),
        ).report;

    test('a lead-in move may be silent, and is said to be', () {
      final r = report('$first.lead.2');
      expect(r['silent_slots'], contains('$first.lead.2'));
      expect(r['missing_slots'], isNot(contains('$first.lead.2')));
    });

    test('the first move of a best line may not', () {
      final r = report('$first.answer.1');
      expect(r['missing_slots'], contains('$first.answer.1'));
      expect(r['silent_slots'] ?? const [], isNot(contains('$first.answer.1')));
    });
  });

  group('the story of a game', () {
    test('every missed chance belongs to the side that missed it', () {
      for (final game in games) {
        final rows = ((game['facts'] as Map)['rows'] as List)
            .cast<Map<String, dynamic>>();
        for (final e in gameStory(rows)) {
          final kind = e['kind'] as String;
          if (!kind.contains('chance')) continue;
          expect(e['text'], contains('hands ${e['side']} a chance'),
              reason: '${game['game']}: $e');
        }
      }
    });

    test('the arc counts missed chances per side', () {
      for (final game in games) {
        final rows = ((game['facts'] as Map)['rows'] as List)
            .cast<Map<String, dynamic>>();
        final missed = gameStory(rows)
            .where((e) => (e['kind'] as String).endsWith('chance_missed'));
        final opening = gameArc(rows)['opening']!;
        if (missed.isEmpty) {
          expect(opening, contains('chances missed: none'));
          continue;
        }
        for (final side in const ['White', 'Black']) {
          final n = missed.where((e) => e['side'] == side).length;
          if (n > 0) expect(opening, contains('$side missed $n'));
          if (n == 0) expect(opening, isNot(contains('$side missed')));
        }
      }
    });
  });

  // Boundaries no fixture game reaches, so the harness gate cannot hold them.
  group('the edges of the story rules', () {
    const start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    const afterE4 =
        'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1';

    List<Map<String, dynamic>> gameWith(String motifs) => [
          {
            'label': 'start',
            'fen': start,
            'to_move': 'White',
            'played': {'move': 'e4', 'label': '1. e4'},
            'motifs_after_played': motifs,
          },
          {'label': '1. e4', 'fen': afterE4, 'to_move': 'Black'},
        ];

    test('exactly twice as many tactical sentences is mostly tactical', () {
      // Two tactical, one positional: `>=` in skeleton.py, and a port with
      // `>` would call this game tactical and positional in turn.
      final arc = gameArc(gameWith('The white knight on f3 is pinned. '
          'The white bishop forks the rooks. The black pawn on a7 is isolated.'));
      expect(arc['opening'],
          contains('2 tactical and 1 positional - mostly tactical'));
    });

    test('a mate in three is a quick mate, a mate in four is not', () {
      expect(quickMate('#3'), isTrue);
      expect(quickMate('#-3'), isTrue);
      expect(quickMate('#4'), isFalse);
      expect(quickMate('+2.40'), isFalse);
      expect(quickMate(null), isFalse);
    });

    test('en passant takes a pawn from an empty square, and is a capture', () {
      final board = chess.Chess.fromFEN('k7/8/8/3pP3/8/8/8/K7 w - d6 0 1');
      expect(isCapture(board, findMove(board, 'exd6')), isTrue);
      expect(isCapture(board, findMove(board, 'e6')), isFalse);
    });
  });
}
