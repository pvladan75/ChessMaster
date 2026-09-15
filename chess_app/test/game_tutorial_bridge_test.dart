// „Back to the game" where a tutorial leaves a sideline and the game resumes.
//
// Point 9 of the owner's live pass, 14.9.2026: „kada ode na liniju sporednu i
// vrati se, treba obaveštenje u komentaru … (a da se ne ponavlja više puta,
// nego da ima i varijante)".
//
// Half of it already existed and worked — `kLexicon['resumed']`, three
// wordings, written by the app and not by the model. What it could not cover
// was measured over the ten harness games before anything was changed:
//
//   * whole-game mode was short one bridge in four of the ten (g03, g05, g09,
//     g10). Two mistakes close together leave no filler block between them,
//     because the second moment's lead-in reaches back past the first, and
//     `fill()` returns null — so the game resumed with no word at all;
//   * key-moments mode had **none in any game**, because it has no filler.
//
// The counts below are the invariant that replaced both gaps: after each
// chosen moment's answer the game resumes exactly once, so whole-game carries
// one bridge per chosen moment and key-moments one fewer — nothing precedes
// the first moment.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_assembly.dart';

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

/// The fixed opening of each wording, derived from the lexicon rather than
/// retyped: a pool that gains a variant must not quietly stop being counted.
List<String> _openings(String pool) => [
      for (final line in kLexicon[pool]!) line.split('{').first.trimRight(),
    ];

int _bridgesIn(Map<String, dynamic> tutorial) {
  final openings = [..._openings('resumed'), ..._openings('back_to_game')];
  var found = 0;
  for (final step in (tutorial['positionList'] as List)) {
    final text = '${(step as Map)['pgn'] ?? ''} ${step['instruction'] ?? ''}';
    for (final opening in openings) {
      found += opening.allMatches(text).length;
    }
  }
  return found;
}

void main() {
  final games = _games();

  test('the ten games are all here', () => expect(games, hasLength(10)));

  test('no two wordings of a bridge can be confused for one another', () {
    final all = [..._openings('resumed'), ..._openings('back_to_game')];
    expect(all, hasLength(6));
    // By position, not by value: `a == b` skipped exactly the clash this test
    // is for. The story wording „Back to the game. White played…" opened like
    // the bridge „Back to the game." and counted twice in one sentence, with
    // this test green (docs/PLAN-NARACIJA.md, 15.9.2026).
    for (var i = 0; i < all.length; i++) {
      for (var j = 0; j < all.length; j++) {
        if (i == j) continue;
        expect(all[i].contains(all[j]), isFalse,
            reason: '„${all[i]}" contains „${all[j]}"');
      }
    }
  });

  // **Assembled here, not read out of the fixture.** Written the other way
  // first, and two mutations survived it: deleting the bridge from either mode
  // left all eighteen green, because a fixture is what `skeleton.py` made and
  // says nothing about what this code does. The port gate compares the two;
  // this asks what the port produces.
  group('the game is picked up out loud, once per moment', () {
    for (final game in games) {
      test('${game['game']}', () {
        final assembly = assembleSkeleton(
          game['facts'] as Map<String, dynamic>,
          game['answer'] as String,
        );
        final chosen = (assembly.report['chosen'] as List).length;
        expect(chosen, greaterThan(1));

        expect(_bridgesIn(assembly.tutorialGame!), chosen,
            reason: 'whole game: one after each moment');
        // One fewer, and the one missing is the first: nothing precedes it.
        expect(_bridgesIn(assembly.tutorial!), chosen - 1,
            reason: 'key moments: one after each moment but the first');
      });
    }
  });

  group('bridged', () {
    Map<String, dynamic> part(String id,
            {bool sideline = false, bool resumed = false, String? intro}) =>
        {
          'kind': 'show',
          if (intro != null) 'intro': intro,
          'moves': [
            {'slot': '$id.1'}
          ],
          if (sideline) 'sideline': true,
          if (resumed) 'resumed': true,
        };

    test('nothing is said before the first part', () {
      final parts = [part('a', intro: 'a.intro')];
      final out = bridged(parts, {'a.intro': 'A.', 'a.1': 'One.'}, {});
      expect(out['a.intro'], 'A.');
    });

    test('a part after a sideline is picked up, on its first words', () {
      final parts = [part('a', sideline: true), part('b', intro: 'b.intro')];
      final out = bridged(
          parts, {'a.1': 'Sideline.', 'b.intro': 'B.', 'b.1': 'One.'}, {});
      expect(out['b.intro'], 'Back to the game. B.');
      expect(out['b.1'], 'One.', reason: 'only the first words carry it');
      expect(out['a.1'], 'Sideline.', reason: 'the sideline is left alone');
    });

    test('an empty introduction is read as nothing, so the move carries it',
        () {
      final parts = [part('a', sideline: true), part('b', intro: 'b.intro')];
      final out =
          bridged(parts, {'a.1': 'S.', 'b.intro': '  ', 'b.1': 'One.'}, {});
      expect(out['b.intro'], '  ', reason: 'an empty slot stays empty');
      expect(out['b.1'], 'Back to the game. One.');
    });

    test('a part that already resumed the game aloud is left alone', () {
      final parts = [
        part('a', sideline: true),
        part('b', resumed: true, intro: 'b.intro'),
      ];
      final out = bridged(parts,
          {'a.1': 'S.', 'b.intro': '', 'b.1': 'Back in the game, White…'}, {});
      expect(out['b.1'], 'Back in the game, White…');
      expect(out['b.intro'], '');
    });

    test('two sidelines in a row are two different wordings', () {
      final parts = [
        part('a', sideline: true),
        part('b', intro: 'b.intro'),
        part('c', sideline: true),
        part('d', intro: 'd.intro'),
      ];
      final out = bridged(
        parts,
        {'a.1': 'S.', 'b.intro': 'B.', 'c.1': 'S.', 'd.intro': 'D.'},
        {},
      );
      expect(out['b.intro'], startsWith(kLexicon['back_to_game']![0]));
      expect(out['d.intro'], startsWith(kLexicon['back_to_game']![1]));
      expect(out['b.intro'], isNot(out['d.intro']));
    });

    test('the words it was given are not written through', () {
      final words = {'a.1': 'S.', 'b.intro': 'B.'};
      final parts = [part('a', sideline: true), part('b', intro: 'b.intro')];
      bridged(parts, words, {});
      expect(words['b.intro'], 'B.', reason: 'the caller keeps its own map');
    });
  });
}
