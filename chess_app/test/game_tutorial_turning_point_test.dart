// The moment the game turned on, and the recap that comes back to it.
//
// Points 7 and 8 of the owner's live pass, 14.9.2026. Every moment offered is
// already a mistake - that much was built - so what point 7 adds is *which* of
// them decided the game, marked in the request so the model can weight it. And
// point 8 comes back to it at the end, in whole-game mode only.
//
// The rule is not "the costliest move". A game already lost collects expensive
// blunders that decide nothing: on g01 a move costing a forced mate is passed
// over for one costing 2.11 pawns, because the first was played from a position
// already lost and the second is where it was lost.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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

/// One row of facts: [best] is the evaluation after the best move and [played]
/// the evaluation after the move the game made, both from White's side.
Map<String, dynamic> _row(String mover, String best, String played) => {
      'to_move': mover,
      'candidates': [
        {'move': 'd4', 'eval': best}
      ],
      'played': {'move': 'e4', 'eval': played},
    };

Map<String, dynamic> _moment(String id, int index, Object? cost) =>
    {'id': id, 'index': index, 'cost': cost};

void main() {
  final games = _games();

  group('decisiveMoment', () {
    test('a move that changed who is better beats a costlier one that did not',
        () {
      // Row 0: White was lost (-3) and is now mated. Expensive, decided nothing.
      // Row 1: White was level and is now clearly worse. This is the one.
      final rows = [
        _row('White', '-3.0', '#-4'),
        _row('White', '+0.2', '-2.0'),
      ];
      expect(
        decisiveMoment([_moment('m1', 0, 'mate'), _moment('m2', 1, 1.0)], rows),
        'm2',
      );
    });

    test('among moves that changed it, the costliest wins', () {
      final rows = [
        _row('White', '+0.2', '-2.0'),
        _row('White', '+0.2', '-2.0'),
      ];
      expect(
        decisiveMoment([_moment('m1', 0, 1.0), _moment('m2', 1, 4.0)], rows),
        'm2',
      );
    });

    test('on equal cost the game turned the first time it turned', () {
      final rows = [
        _row('White', '+0.2', '-2.0'),
        _row('White', '+0.2', '-2.0'),
      ];
      expect(
        decisiveMoment([_moment('m1', 0, 2.0), _moment('m2', 1, 2.0)], rows),
        'm1',
      );
    });

    test('when nothing changed hands it falls back to the costliest', () {
      final rows = [
        _row('White', '-3.0', '#-4'),
        _row('White', '-3.0', '#-4'),
      ];
      expect(
        decisiveMoment([_moment('m1', 0, 2.0), _moment('m2', 1, 5.0)], rows),
        'm2',
      );
    });

    test('no moments, no answer', () => expect(decisiveMoment([], []), isNull));
  });

  group('exactly one moment of a game is marked', () {
    for (final game in games) {
      test('${game['game']}', () {
        final moments = skeletonMoments(game['facts'] as Map<String, dynamic>);
        final marked =
            moments.where((m) => m['turning_point'] == true).toList();
        expect(marked, hasLength(1), reason: 'one game, one turning point');

        // And it travels: the model is told, which is the whole of point 7.
        final request = wordsRequestOf(game['facts'] as Map<String, dynamic>,
            movetext: '1. e4');
        final sent = (request['moments'] as List)
            .where((m) => (m as Map)['turning_point'] == true)
            .toList();
        expect(sent, hasLength(1));
        expect((sent.single as Map)['id'], marked.single['id']);
      });
    }
  });

  test('g01 is the case the rule exists for', () {
    final g01 =
        games.firstWhere((g) => g['game'] == 'g01_scandinavian-defense');
    final moments = skeletonMoments(g01['facts'] as Map<String, dynamic>);
    final marked = moments.firstWhere((m) => m['turning_point'] == true);

    // Not m6, which costs a forced mate - Black was already losing there.
    expect(marked['id'], 'm3');
    expect(marked['cost'], 2.11);
    final costliest = moments
        .reduce((a, b) => costValue(b['cost']) > costValue(a['cost']) ? b : a);
    expect(costliest['cost'], 'mate',
        reason: 'the fixture must hold a costlier moment that is not the '
            'turning point, or this test cannot tell the rule from "costliest"');
  });

  group('the recap comes back to it, in whole-game mode only', () {
    for (final game in games) {
      test('${game['game']}', () {
        final assembly = assembleSkeleton(
          game['facts'] as Map<String, dynamic>,
          game['answer'] as String,
        );
        final whole = assembly.tutorialGame!['positionList'] as List;
        final only = assembly.tutorial!['positionList'] as List;

        final recapId = assembly.report['game']['recap'] as String?;
        expect(recapId, isNotNull, reason: 'every fixture chooses a moment');

        // The last part of the whole game is the recap, and it opens on the
        // sentence written here rather than on anything the model wrote.
        final last = whole.last as Map<String, dynamic>;
        expect(last['kind'], 'show');
        expect(last['pgn'], contains('Looking back, the game turned on'));

        // Key moments never carries it.
        for (final step in only) {
          expect((step as Map)['pgn'] ?? '',
              isNot(contains('Looking back, the game turned on')));
        }
      });
    }
  });

  test('the recap is the decisive part, position, line and all', () {
    final g01 =
        games.firstWhere((g) => g['game'] == 'g01_scandinavian-defense');
    final assembly = assembleSkeleton(
        g01['facts'] as Map<String, dynamic>, g01['answer'] as String);
    final whole = assembly.tutorialGame!['positionList'] as List;
    final recap = whole.last as Map<String, dynamic>;
    final recapId = assembly.report['game']['recap'] as String;

    // The answer part of that moment, as it stands earlier in the same
    // tutorial: same position, same moves. A recap that opened somewhere else
    // would still contain the sentence the test above looks for.
    final moment = skeletonMoments(g01['facts'] as Map<String, dynamic>)
        .firstWhere((m) => m['id'] == recapId);
    final answer = (moment['parts'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => p['sideline'] == true);
    expect(recap['fen'], answer['fen']);

    final sans = RegExp(r'(?:^|\s)(?:\d+\.+\s*)?([A-Za-z][A-Za-z0-9+#=-]*)')
        .allMatches(
            (recap['pgn'] as String).replaceAll(RegExp(r'\{[^}]*\}'), ''))
        .map((m) => m.group(1))
        .where((m) => m != null && m != '*')
        .toList();
    for (final move in (answer['moves'] as List).cast<Map<String, dynamic>>()) {
      expect(sans, contains(move['san']));
    }

    // And the sentence names the move the game turned on, draws it as the
    // moment's own part did, and counts no pawns aloud.
    expect(recap['pgn'], contains(moment['played']));
    final fork = (moment['parts'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => p['program'] == true);
    final arrow = (fork['arrow'] as List).join();
    expect(recap['pgn'], contains('[%cal B$arrow]'));
    expect(recap['pgn'], isNot(contains('pawns')));
  });
}
