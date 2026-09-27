// One fixture, two readers — phase 3 of docs/PLAN-PRIPREMA.md.
//
// `test/fixtures/lesson_timeline.json` is a lesson as Preparation records it:
// the board's events stamped on the audio's clock, a change of marks carrying
// `squares` beside `arrows`. The app's player replays it
// (`chess_app/test/lesson_timeline_readers_test.dart`) and the film draws it;
// this is the film's half. Both are held to the same `checks`, written by hand
// from the rule in the fixture's head, so the two cannot drift apart without
// one of the two files going red.
//
// The film is read the way its frame loop reads it (`renderRecordingToMP4`):
// every event whose `timestampMs` is not after the frame's own time, in the
// order they were written, folded through `applyEvent`. Nothing here draws a
// frame or starts ffmpeg.
//
// The judge is here too, because it stands between the two: what it lets
// through is what both readers are given.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-for-lesson-timeline';

const { applyEvent, initialFrameState } = require('../videoRenderer');
const { judgeLessonEvents, LESSON_EVENT_TYPES } = require('../services/lessonRecording');

const fixture = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'fixtures', 'lesson_timeline.json'), 'utf8'),
);

/// The film's state at [ms], as its frame loop reaches it.
function filmAt(events, ms) {
  let state = initialFrameState();
  for (const event of events) {
    if ((event.timestampMs || 0) > ms) break;
    state = applyEvent(state, event);
  }
  return state;
}

test('the fixture is one the test can fail on', () => {
  assert.ok(fixture.timelines.length >= 2);
  const all = fixture.timelines.flatMap((t) => t.checks);
  assert.ok(all.some((c) => c.arrows.length > 0 && c.squares.length > 0),
    'no check holds an arrow and a square together');
  assert.ok(all.some((c) => c.arrows.length === 0 && c.squares.length > 0),
    'no check holds a square alone');
  const events = fixture.timelines.flatMap((t) => t.events);
  assert.ok(events.some((e) => e.eventType === 'move' && Array.isArray(e.data.squares)),
    'no jump lands on a move that holds marks');
  assert.ok(events.some((e) => e.eventType === 'arrow_drawn' && !('squares' in e.data)),
    'no event is written as a recording made before this phase wrote it');
});

for (const timeline of fixture.timelines) {
  test(`the film draws „${timeline.name}" as the fixture says`, () => {
    for (const check of timeline.checks) {
      const state = filmAt(timeline.events, check.ms);
      assert.equal(state.fen, check.fen, `the position at ${check.ms} ms`);
      assert.deepEqual(
        state.arrows.map((a) => ({ from: a.from, to: a.to, color: a.color })),
        check.arrows, `the arrows at ${check.ms} ms`,
      );
      assert.deepEqual(
        state.squares.map((s) => ({ square: s.square, color: s.color })),
        check.squares, `the squares at ${check.ms} ms`,
      );
    }
  });

  test(`the judge lets „${timeline.name}" through whole`, () => {
    const judged = judgeLessonEvents({ events: JSON.stringify(timeline.events), durationMs: 60000 });
    assert.equal(judged.ok, true, judged.error);
    // Whole: what is stored is what was sent, squares and all. A judge that
    // kept the kinds and dropped a field it did not know would pass every
    // other case in this file.
    assert.deepEqual(judged.events, timeline.events);
  });
}

test('the kinds are still three, and a fourth is refused by name', () => {
  assert.deepEqual([...LESSON_EVENT_TYPES].sort(), ['arrow_drawn', 'init', 'move']);
  const events = [
    ...fixture.timelines[0].events.slice(0, 2),
    { timestampMs: 1300, eventType: 'square_marked', data: { squares: [{ square: 'd5', color: 'R' }] } },
  ];
  const judged = judgeLessonEvents({ events, durationMs: 60000 });
  assert.equal(judged.ok, false);
  assert.equal(judged.status, 400);
  assert.match(judged.error, /square_marked/);
});
