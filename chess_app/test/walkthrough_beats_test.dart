import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/features/repertoire/services/walkthrough_beats.dart';
import 'package:chess_app/features/repertoire/services/walkthrough_order.dart';

/// The tour as it is *driven*, which is not quite the order it is read in.
///
/// The owner watched phase 4 running and named what was missing: at the end of
/// a line the board jumped straight into the next branch, several plies back
/// and several moves away, with nothing saying where the two lines part. A
/// returning beat is that missing moment.

RepertoireTreeMove mine(String san,
        {List<RepertoireTreeMove> children = const []}) =>
    RepertoireTreeMove(
        uci: '${san}0',
        san: san,
        fen: 'fen-$san',
        mine: true,
        role: 'primary',
        state: 'decided',
        children: children);

RepertoireTreeMove theirs(String san, double share,
        {String state = 'decided',
        List<RepertoireTreeMove> children = const []}) =>
    RepertoireTreeMove(
        uci: '${san}0',
        san: san,
        fen: 'fen-$san',
        mine: false,
        share: share,
        state: state,
        children: children);

void main() {
  test('a line that never forks is walked without a single return', () {
    final tree = RepertoireTree(rootFen: 'start', children: [
      mine('e4', children: [
        theirs('e5', 1.0, children: [mine('Nf3')]),
      ]),
    ]);
    final stops = walkthroughOrder(tree);
    final beats = walkthroughBeats(stops);

    expect(beats.length, stops.length);
    expect(beats.every((b) => !b.returning), isTrue);
  });

  test('the tour comes back to the fork before it takes another line', () {
    // e4 with three replies; the reader has work under e5 and e6, and c5 is a
    // hole. Phase 3 orders e5, e6, c5 — work never ranks below an empty
    // branch — so the tour climbs back to e4 twice.
    final tree = RepertoireTree(rootFen: 'start', children: [
      mine('e4', children: [
        theirs('e5', 0.55, children: [mine('Nf3')]),
        theirs('e6', 0.14, children: [
          mine('d4', children: [theirs('d5', 0.60, state: 'open')]),
        ]),
        theirs('c5', 0.31, state: 'open'),
      ]),
    ]);
    final stops = walkthroughOrder(tree);
    final beats = walkthroughBeats(stops);

    expect(stops.length, 7);
    expect(beats.length, 9, reason: 'seven moves and two climbs');

    final returns = [
      for (final beat in beats)
        if (beat.returning) beat,
    ];
    expect(returns.length, 2);

    // Both stand on e4 — the position the two lines part from, and the one the
    // reader has to recognise for the next line to mean anything.
    expect(returns[0].stopIndex, 0);
    expect(returns[0].done?.san, 'e5');
    expect(returns[0].next?.san, 'e6');

    expect(returns[1].stopIndex, 0);
    expect(returns[1].done?.san, 'e6',
        reason: 'the line just finished, not the first one ever walked');
    expect(returns[1].next?.san, 'c5');
  });

  test('two first moves part at the root, and the tour goes back to it', () {
    final tree = RepertoireTree(rootFen: 'start', children: [
      mine('e4', children: [theirs('e5', 1.0)]),
      mine('d4'),
    ]);
    final beats = walkthroughBeats(walkthroughOrder(tree));

    final back = beats.firstWhere((b) => b.returning);
    expect(back.stopIndex, -1, reason: 'the root is a fork like any other');
    expect(back.done?.san, 'e4');
    expect(back.next?.san, 'd4');
  });

  test('every stop is played exactly once, in the order phase 3 decided', () {
    // The invariant that keeps this from being a second ordering: returns are
    // added *between* the stops, never instead of one and never reordering
    // them. If this fails, `walkthroughBeats` has started deciding the tour.
    final tree = RepertoireTree(rootFen: 'start', children: [
      mine('e4', children: [
        theirs('e5', 0.55, children: [mine('Nf3')]),
        theirs('c5', 0.31, state: 'open'),
      ]),
      mine('d4'),
    ]);
    final stops = walkthroughOrder(tree);
    final beats = walkthroughBeats(stops);

    final played = [
      for (final beat in beats)
        if (!beat.returning) beat.stopIndex,
    ];
    expect(played, [for (var i = 0; i < stops.length; i++) i]);
  });

  test('an empty tour has no beats', () {
    expect(walkthroughBeats(const []), isEmpty);
  });
}
