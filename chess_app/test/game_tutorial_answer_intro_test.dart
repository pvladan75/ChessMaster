// The answer part introduces the line; the line's first move names it.
//
// Point 5 of the owner's live pass on 14.9.2026, against „Lost chances: a fork,
// a pawn, a mate": every answer part said the same move twice, in two sentences
// the student reads one after the other —
//
//   „White should have played Qe3 instead of the game move Nxc7. …"
//   „White should have played Qe3: the queen attacks the black queen on f4. …"
//
// The model was faithful. `m*.answer.intro` and `m*.answer.1` were handed the
// same fact, so a prompt instruction telling the model to notice the repetition
// would be asking it to work around its own input. The introduction says what
// the game did and what the line is worth, and stops there.
//
// Held over all ten harness games rather than one, because a single fixture
// cannot tell a rule from a coincidence: a move the intro happens not to name.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_moments.dart';

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

/// The words of [text], so „Qe3" is not found inside „Qe3xd4" or „NQe3".
Set<String> _tokens(String text) =>
    text.split(RegExp(r'[^A-Za-z0-9+#=-]+')).where((t) => t.isNotEmpty).toSet();

void main() {
  final games = _games();

  test('the ten games are all here', () => expect(games, hasLength(10)));

  group('the answer introduction does not name the move', () {
    for (final game in games) {
      test('${game['game']}', () {
        final moments = skeletonMoments(game['facts'] as Map<String, dynamic>);
        expect(moments, isNotEmpty);
        var checked = 0;
        for (final moment in moments) {
          final slots = (moment['slots'] as Map).cast<String, String>();
          final intro = slots['${moment['id']}.answer.intro'];
          expect(intro, isNotNull, reason: '${moment['id']} has no answer');
          final best = moment['best'] as String;

          expect(_tokens(intro!), isNot(contains(best)),
              reason: '${moment['id']}: the introduction names $best');

          // The other half of the rule, and the half that makes it worth
          // having: the move is still said, once, on the move itself. An
          // introduction that named nothing because the naming had been
          // deleted everywhere would pass the assertion above.
          expect(_tokens(slots['${moment['id']}.answer.1']!), contains(best),
              reason: '${moment['id']}: nothing names $best');
          checked++;
        }
        expect(checked, greaterThan(0));
      });
    }
  });

  test('the introduction still carries what the game move cost', () {
    for (final game in games) {
      for (final moment
          in skeletonMoments(game['facts'] as Map<String, dynamic>)) {
        final intro =
            (moment['slots'] as Map)['${moment['id']}.answer.intro'] as String;
        expect(intro, contains(moment['cost_text'] as String),
            reason: '${game['game']} ${moment['id']}');
        // `played` is the label — „5... Qf7" — and the intro writes the bare
        // SAN, which is its last word.
        final playedSan = (moment['played'] as String).split(' ').last;
        expect(_tokens(intro), contains(playedSan),
            reason: '${game['game']} ${moment['id']}: the game move');
      }
    }
  });
}
