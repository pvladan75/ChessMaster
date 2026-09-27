// One fixture, two readers — phase 3 of `docs/PLAN-PRIPREMA.md`.
//
// `chess_backend/test/fixtures/lesson_timeline.json` is a lesson as
// Preparation records it. The film draws it
// (`chess_backend/test/lesson_timeline_film.test.js`) and the app's player
// replays it; this is the player's half. Both are held to the same `checks`,
// written by hand from the rule in the fixture's head (rule 12: when two ends
// must agree, they share one fixture).
//
// The rule, as the player has it since this phase: the board is what the
// latest event of a position kind said, and **the marks are what the latest
// event said, whatever its kind** — until now the player read arrows from
// `arrow_drawn` alone, so a jump to a move that holds an arrow replayed a bare
// board where the film drew the arrow.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/models/recording_models.dart';

List<Map<String, String>> _arrows(ReplayFrame frame) => [
      for (final a in frame.arrows)
        {'from': a['from']!, 'to': a['to']!, 'color': a['colorCode']!},
    ];

List<Map<String, String>> _squares(ReplayFrame frame) => [
      for (final s in frame.squares)
        {'square': s['square']!, 'color': s['colorCode']!},
    ];

List<Map<String, String>> _expected(dynamic list) => [
      for (final item in list as List)
        {
          for (final entry in (item as Map).entries)
            '${entry.key}': '${entry.value}',
        },
    ];

void main() {
  final fixture = jsonDecode(
    File('../chess_backend/test/fixtures/lesson_timeline.json')
        .readAsStringSync(),
  ) as Map<String, dynamic>;
  final timelines = (fixture['timelines'] as List).cast<Map<String, dynamic>>();

  test('the fixture holds what the cases below stand on', () {
    expect(timelines.length, greaterThanOrEqualTo(2));
    final checks = [
      for (final t in timelines) ...(t['checks'] as List),
    ];
    expect(
        checks.where((c) =>
            (c['arrows'] as List).isNotEmpty &&
            (c['squares'] as List).isNotEmpty),
        isNotEmpty,
        reason: 'no check holds an arrow and a square together');
  });

  for (final timeline in timelines) {
    test('the player replays „${timeline['name']}" as the fixture says', () {
      final events = [
        for (final e in timeline['events'] as List)
          TimelineEvent.fromJson(Map<String, dynamic>.from(e as Map)),
      ];
      for (final check in (timeline['checks'] as List).cast<Map>()) {
        final ms = check['ms'] as int;
        final frame = replayFrameAt(events, ms);
        expect(frame.fen, check['fen'], reason: 'the position at $ms ms');
        expect(_arrows(frame), _expected(check['arrows']),
            reason: 'the arrows at $ms ms');
        expect(_squares(frame), _expected(check['squares']),
            reason: 'the squares at $ms ms');
      }
    });
  }

  test('a room recording\'s turn of the board leaves its arrows alone', () {
    // `orientation_changed` is the room's, and the film never sees one in a
    // lesson. In the player it is not a change of marks: a recording made in
    // a room before this phase replays as it did.
    final frame = replayFrameAt([
      TimelineEvent(timestampMs: 0, eventType: 'init', data: {'fen': 'A'}),
      TimelineEvent(timestampMs: 100, eventType: 'arrow_drawn', data: {
        'arrows': [
          {'from': 'e2', 'to': 'e4', 'colorCode': 'R'},
        ],
      }),
      TimelineEvent(
          timestampMs: 200,
          eventType: 'orientation_changed',
          data: {'orientation': 'black'}),
    ], 300);
    expect(frame.orientation, 'black');
    expect(_arrows(frame), [
      {'from': 'e2', 'to': 'e4', 'color': 'R'},
    ]);
    expect(frame.squares, isEmpty);
  });
}
