// The parts as a map — phase 3 of `docs/PLAN-MAPA-DELOVA.md`, the pure half.
//
// `partMapOf` is held to §3's table of the sketch the owner accepted — entry,
// source, words and lane of every row — and to the lane rule's properties on
// shapes the sketch does not have. What a row's painter is given is asserted
// here too, so „dashed or solid" and „square or circle" are facts about data
// rather than about pixels (the owner reads shape and luminance, never hue).

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_part_map.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_video.dart';

import 'support/tutorial_part_fixtures.dart';

/// Every property the lane rule promises, on any map.
void _holdsTheLaneRule(PartMap map) {
  final lanes = [for (final e in map.entries) e.lane];
  for (final edge in map.edges) {
    for (var k = edge.fromRow + 1; k < edge.toRow; k++) {
      expect(lanes[k], isNot(edge.lane),
          reason: 'the edge ${edge.fromRow + 1}→${edge.toRow + 1} runs through '
              'the marker of row ${k + 1}');
    }
  }
  for (final e in map.entries) {
    if (e.entry == PartEntry.continues) {
      expect(e.lane, lanes[e.from!.part],
          reason: 'part ${e.part + 1} continues and changed lane');
    }
  }
  // Two edges never run down one lane over the same row.
  for (var k = 0; k < lanes.length; k++) {
    final used = [
      for (final edge in map.edges)
        if (edge.fromRow < k && k < edge.toRow) edge.lane,
    ];
    expect(used.toSet().length, used.length,
        reason: 'two edges share a lane past row ${k + 1}');
  }
}

void main() {
  group('§3, the sketch the owner accepted', () {
    late PartMap map;
    setUp(() => map = partMapOf(sketchDraft()));

    test('every row says what §3 says', () {
      expect(map.entries.map((e) => e.rowText), [
        '1 · new board',
        '2 · continues',
        '3 · continues',
        '4 · back to after 18. Rfe1',
        '5 · back to after 16... Nc4',
        '6 · back to after 16... Nc4',
        '7 · continues',
        '8 · new board',
      ]);
    });

    test('each hangs from the part and beat §3 names', () {
      expect(map.entries.map((e) => e.from), [
        null,
        (part: 0, beat: 1),
        (part: 1, beat: 0),
        (part: 2, beat: 3), // 18. Rfe1, in the middle of part 3
        (part: 2, beat: 0), // the start of part 3
        (part: 4, beat: 0), // the start of part 5, the last to show it
        (part: 5, beat: 2),
        null,
      ]);
    });

    test('the lanes of §3', () {
      expect(map.entries.map((e) => e.lane), [0, 0, 0, 1, 0, 0, 0, 0]);
      expect(map.laneCount, 2);
      _holdsTheLaneRule(map);
    });

    test('its moves on one line', () {
      expect(map.entries.map((e) => e.moves), [
        '16... Nc4',
        '',
        '17. Bg5 Nxe5 18. Rfe1 cxd4',
        '18... h6 19. Rxe5',
        '17. Be3 Nxe3 18. fxe3',
        '17. Bc1 Nxe5',
        '18. Qe2 Re8 19. Re1',
        '1. d4 d5 2. c4 c6 3. Nc3 Nf6',
      ]);
    });
  });

  group('the lane rule', () {
    test('no return: every part in lane 0', () {
      final map = partMapOf(TutorialDraft(sections: [
        partOf(forkPosition, '17. Bg5 Nxe5 *'),
        partOf(fenAfter(forkPosition, '17. Bg5 Nxe5'), '18. Rfe1 cxd4 *'),
        partOf(standardStart, '1. e4 *'),
      ]));
      expect(map.entries.map((e) => e.entry),
          [PartEntry.fresh, PartEntry.continues, PartEntry.fresh]);
      expect(map.entries.map((e) => e.lane), [0, 0, 0]);
    });

    test('a continuation shares its source\'s lane, even off lane 0', () {
      // Part 3 goes back into the middle of part 1, so it stands right of it;
      // part 4 continues part 3 and stays with it.
      final afterBg5 = fenAfter(forkPosition, '17. Bg5');
      final map = partOf2([
        partOf(forkPosition, '17. Bg5 Nxe5 18. Rfe1 *'),
        partOf(standardStart, '1. e4 *'),
        partOf(afterBg5, '17... h6 *'),
        partOf(fenAfter(afterBg5, '17... h6'), '18. Bxf6 *'),
      ]);
      expect(map.entries.map((e) => e.entry), [
        PartEntry.fresh,
        PartEntry.fresh,
        PartEntry.returns,
        PartEntry.continues,
      ]);
      expect(map.entries.map((e) => e.lane), [0, 0, 1, 1]);
      _holdsTheLaneRule(map);
    });

    test('a return into the middle of a part is never left of it', () {
      // The sketch's part 4 goes back to 18. Rfe1, in the middle of part 3.
      final parts = sketchDraft().sections;
      final map = partOf2(parts);
      var middles = 0;
      for (final e in map.entries) {
        if (e.entry != PartEntry.returns) continue;
        final source = e.from!;
        final last = map.entries[source.part].moves.isEmpty
            ? 0
            : parts[source.part].step.line.movesSan.length;
        if (source.beat == 0 || source.beat == last) continue;
        middles++;
        expect(e.lane, greaterThan(map.entries[source.part].lane),
            reason: e.rowText);
      }
      expect(middles, greaterThan(0),
          reason: 'the fixture must return into a middle, or this is empty');
      _holdsTheLaneRule(map);
    });

    test('two returns over the same row take two lanes', () {
      // Parts 3 and 4 both go back into the middle of part 1, past part 2;
      // the second cannot run down the lane the first one's marker holds.
      final map = partOf2([
        partOf(forkPosition, '17. Bg5 Nxe5 18. Rfe1 *'),
        partOf(standardStart, '1. e4 *'),
        partOf(fenAfter(forkPosition, '17. Bg5'), '17... h6 *'),
        partOf(fenAfter(forkPosition, '17. Bg5 Nxe5'), '18. Qe2 *'),
      ]);
      expect(map.entries.map((e) => e.from), [
        null,
        null,
        (part: 0, beat: 1),
        (part: 0, beat: 2),
      ]);
      expect(map.entries.map((e) => e.lane), [0, 0, 1, 2]);
      _holdsTheLaneRule(map);
    });
  });

  group('what a row\'s painter is given', () {
    late PartMap map;
    setUp(() => map = partMapOf(sketchDraft()));

    test('a new board is a square, every other marker a circle', () {
      expect([for (var r = 0; r < 8; r++) map.gutterOf(r, open: false).square],
          [true, false, false, false, false, false, false, true]);
    });

    test('a continuation is solid and a return dashed', () {
      final third = map.gutterOf(2, open: false);
      expect(third.arriving, [(lane: 0, dashed: false)]);
      expect(
          third.leaving,
          unorderedEquals([
            (lane: 1, dashed: true), // to part 4, into its middle
            (lane: 0, dashed: true), // to part 5, back to its start
          ]));
      final fourth = map.gutterOf(3, open: false);
      expect(fourth.markerLane, 1);
      expect(fourth.arriving, [(lane: 1, dashed: true)]);
      expect(fourth.through, [(lane: 0, dashed: true)]);
    });

    test('only the open part is drawn open', () {
      expect(map.gutterOf(2, open: true).open, isTrue);
      expect(map.gutterOf(2, open: false).open, isFalse);
    });
  });
}

PartMap partOf2(List<TutorialSection> parts) =>
    partMapOf(TutorialDraft(sections: parts));
