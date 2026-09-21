// What the replay shows at a moment — phase 5b of docs/PLAN-SESIJA.md.
//
// The app's player and the server's film read one timeline (rule 13). A lesson
// recorded in Preparation writes `init` whenever the trainer puts a new
// position on the board — not only at 0, as the room did — and the player
// preferred any earlier `move` to a later `init`, so such a lesson replayed on
// the wrong board: dormant while nothing wrote a second `init`, woken by 5b
// (rule 14). And a lesson's arrows carry `color`, the film's key, where the
// room's carried `colorCode`.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/models/recording_models.dart';

TimelineEvent _e(int ms, String type, Map<String, dynamic> data) =>
    TimelineEvent(timestampMs: ms, eventType: type, data: data);

void main() {
  test('a later init is the board, whatever moves came before it', () {
    final events = [
      _e(0, 'init', {'fen': 'A'}),
      _e(100, 'move', {'fen': 'B'}),
      _e(200, 'init', {'fen': 'C'}),
    ];
    expect(replayFrameAt(events, 150).fen, 'B');
    expect(replayFrameAt(events, 250).fen, 'C');
    expect(replayFrameAt(events, 0).fen, 'A');
  });

  test('the room\'s old kinds still move the board', () {
    final events = [
      _e(0, 'init', {'fen': 'A'}),
      _e(100, 'fen_change', {'fen': 'B'}),
      _e(200, 'lesson_loaded', {'fen': 'C'}),
    ];
    expect(replayFrameAt(events, 150).fen, 'B');
    expect(replayFrameAt(events, 250).fen, 'C');
  });

  test('arrows read the film\'s key and the room\'s', () {
    final lesson = replayFrameAt([
      _e(0, 'init', {'fen': 'A'}),
      _e(50, 'arrow_drawn', {
        'arrows': [
          {'from': 'e2', 'to': 'e4', 'color': 'R'}
        ]
      }),
    ], 60);
    expect(lesson.arrows.single, {'from': 'e2', 'to': 'e4', 'colorCode': 'R'});

    final room = replayFrameAt([
      _e(0, 'init', {'fen': 'A'}),
      _e(50, 'arrow_drawn', {
        'arrows': [
          {'from': 'd2', 'to': 'd4', 'colorCode': 'B'}
        ]
      }),
    ], 60);
    expect(room.arrows.single['colorCode'], 'B');
  });

  test('a change of position after the arrows clears them — by order, not by '
      'the clock', () {
    // Two events in one millisecond are one audio chunk apart at most; their
    // order is what the trainer did.
    final events = [
      _e(0, 'init', {'fen': 'A'}),
      _e(400, 'arrow_drawn', {
        'arrows': [
          {'from': 'e2', 'to': 'e4', 'color': 'G'}
        ]
      }),
      _e(400, 'move', {'fen': 'B'}),
    ];
    expect(replayFrameAt(events, 400).arrows, isEmpty);

    final drawnAfter = [
      _e(0, 'init', {'fen': 'A'}),
      _e(400, 'move', {'fen': 'B'}),
      _e(400, 'arrow_drawn', {
        'arrows': [
          {'from': 'e2', 'to': 'e4', 'color': 'G'}
        ]
      }),
    ];
    expect(replayFrameAt(drawnAfter, 400).arrows, hasLength(1));
  });

  test('before anything happened there is nothing to show', () {
    final frame = replayFrameAt([_e(100, 'init', {'fen': 'A'})], 50);
    expect(frame.fen, isNull);
    expect(frame.arrows, isEmpty);
  });
}
