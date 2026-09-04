import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/features/repertoire/services/walkthrough_order.dart';
import 'package:chess_app/features/repertoire/services/walkthrough_speech.dart';

/// Phase 5 of `docs/PLAN-UPOZNAJ-REPERTOAR.md`: the tour speaks, and mostly
/// does not.
///
/// The failure this is written against is not silence, it is a voice that
/// reads every ply. So the test that matters most is the budget at the bottom:
/// a twelve-move trunk must not produce twelve sentences, however good they
/// are.

RepertoireTreeMove mine(String san,
        {String role = 'primary',
        List<RepertoireTreeMove> children = const []}) =>
    RepertoireTreeMove(
      uci: '${san}0',
      san: san,
      fen: 'fen-$san',
      mine: true,
      role: role,
      state: 'decided',
      children: children,
    );

RepertoireTreeMove theirs(String san, double share, String state,
        {List<RepertoireTreeMove> children = const []}) =>
    RepertoireTreeMove(
      uci: '${san}0',
      san: san,
      fen: 'fen-$san',
      mine: false,
      share: share,
      state: state,
      children: children,
    );

WalkthroughStop only(RepertoireTreeMove move) =>
    walkthroughOrder(RepertoireTree(rootFen: 'start', children: [move])).first;

void main() {
  group('what the tour says', () {
    test('an ordinary move on the trunk is not spoken', () {
      final line = walkthroughLine(only(mine('e4')));

      expect(line.parts, ['Vaš potez — glavna linija.']);
      expect(line.speak, isFalse);
    });

    test('an answered reply of theirs is not spoken either', () {
      final line = walkthroughLine(only(theirs('e5', 0.55, 'decided')));

      expect(line.parts.single, 'Protivnik igra e5 — 55% partija.');
      expect(line.speak, isFalse);
    });

    test('a hole is spoken, and says which move and how often', () {
      final line = walkthroughLine(only(theirs('c5', 0.31, 'open')));

      expect(line.spoken, 'Na c5, 31% partija, nemate odgovor.');
      expect(line.speak, isTrue);
    });

    test('a fork is spoken, and names the replies with their shares', () {
      final line = walkthroughLine(
        only(mine('e4')),
        replies: [
          theirs('e5', 0.55, 'decided'),
          theirs('c5', 0.31, 'open'),
        ],
      );

      expect(line.speak, isTrue);
      // The reason this clause exists rather than „ovde ima više odgovora":
      // a listener who cannot see the chips still learns what is coming and
      // which of it is unanswered.
      expect(
        line.spoken,
        'Vaš potez — glavna linija. Odavde protivnik ima 2 odgovora: '
        'e5 u 55% i c5 u 31%, bez odgovora.',
      );
    });

    test('a wide fork names three and counts the rest', () {
      final line = walkthroughLine(
        only(mine('e4')),
        replies: [
          theirs('a5', 0.30, 'decided'),
          theirs('b5', 0.25, 'decided'),
          theirs('c5', 0.20, 'decided'),
          theirs('d5', 0.15, 'decided'),
          theirs('e5', 0.10, 'decided'),
        ],
      );

      expect(line.spoken,
          endsWith('a5 u 30%, b5 u 25%, c5 u 20% i još 2 odgovora.'));
    });

    test('a note is spoken, and it is the last thing said', () {
      final line = walkthroughLine(only(mine('e4')), note: '  Pazi na f7.  ');

      expect(line.speak, isTrue);
      expect(line.parts.last, 'Vaša napomena: Pazi na f7.');
      // An empty note is not a note.
      expect(walkthroughLine(only(mine('e4')), note: '   ').speak, isFalse);
    });

    test('one move of theirs is not a fork', () {
      final line = walkthroughLine(
        only(mine('e4')),
        replies: [theirs('e5', 0.55, 'decided')],
      );

      expect(line.speak, isFalse);
      expect(line.parts.single, 'Vaš potez — glavna linija.');
    });

    test('my own alternatives are not the opponent having answers', () {
      // The clause is about what awaits the reader, not about their own
      // choices — and a position holds one kind or the other.
      final line = walkthroughLine(
        only(theirs('e5', 0.55, 'decided')),
        replies: [mine('Nf3'), mine('Bc4', role: 'alternate')],
      );

      expect(line.speak, isFalse);
      expect(line.spoken, 'Protivnik igra e5 — 55% partija.');
    });
  });

  group('the budget', () {
    /// A trunk of [moves] plies, alternating mine and their answered reply.
    List<WalkthroughStop> trunk(int moves) {
      RepertoireTreeMove? built;
      for (var i = moves; i >= 1; i--) {
        final children = built == null ? <RepertoireTreeMove>[] : [built];
        built = i.isOdd
            ? mine('m$i', children: children)
            : theirs('t$i', 0.5, 'decided', children: children);
      }
      return walkthroughOrder(
          RepertoireTree(rootFen: 'start', children: [built!]));
    }

    int spokenIn(List<WalkthroughStop> stops) {
      var said = 0;
      for (final stop in stops) {
        // Every stop on a trunk has at most one move out of it, which is what
        // makes it a trunk.
        if (walkthroughLine(stop).speak) said += 1;
      }
      return said;
    }

    test('a twelve-move trunk produces at most four spoken sentences', () {
      final stops = trunk(24);

      expect(stops.length, 24, reason: 'twelve moves is twenty-four plies');
      expect(spokenIn(stops), lessThanOrEqualTo(4));
    });

    test('and the same trunk with two holes and a note still fits', () {
      // The budget is not „say nothing" — it is that what is said is worth
      // hearing. Two holes and a note in twelve moves is a realistic line and
      // it must still come in under the ceiling.
      final stops = trunk(24);
      var said = 0;
      for (var i = 0; i < stops.length; i++) {
        final line = walkthroughLine(
          stops[i],
          replies: i == 5
              ? [theirs('x', 0.4, 'open'), theirs('y', 0.3, 'decided')]
              : const [],
          note: i == 9 ? 'Ovde se igra na kraljevom krilu.' : null,
        );
        if (line.speak) said += 1;
      }

      expect(said, lessThanOrEqualTo(4));
    });
  });
}
