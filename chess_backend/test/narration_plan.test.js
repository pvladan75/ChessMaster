// narration_plan.test.js — the picture and the voice cannot disagree.
//
// `narrationPlan` is the pure core of phase 2's narrated half: it decides how
// long each beat holds the screen once a voice has said its sentence, and it
// emits the audio track's segments from the same numbers. These tests exist
// because that agreement is the whole feature — a film whose sound is half a
// second out is worse than a silent one.
const test = require('node:test');
const assert = require('node:assert/strict');

const {
  narrationPlan,
  retimeEvents,
  BREATH_SECONDS,
  SILENT_BEAT_SECONDS,
  MAX_BEAT_SECONDS,
} = require('../services/narrationPlan');

const secondsOf = (plan) => plan.segments.reduce((sum, s) => sum + s.seconds, 0);

test('the audio is exactly as long as the film, to the millisecond', () => {
  // Not "about as long". `-shortest` cuts the film to whichever track ends
  // first, so a track a fraction short takes the last beat's picture with it.
  const plan = narrationPlan([
    { clipSeconds: 8.078 },
    { clipSeconds: null },
    { clipSeconds: 2.4 },
    { clipSeconds: 0.9 },
  ]);
  assert.ok(Math.abs(secondsOf(plan) - plan.totalSeconds) < 1e-9,
    `segments ${secondsOf(plan)} vs film ${plan.totalSeconds}`);
});

test('every beat starts where the one before it ended', () => {
  const plan = narrationPlan([{ clipSeconds: 3.2 }, { clipSeconds: 1.1 }, { clipSeconds: null }]);
  let at = 0;
  for (let i = 0; i < plan.beatSeconds.length; i++) {
    assert.equal(plan.startMs[i], Math.round(at * 1000), `beat ${i} starts on the second before it`);
    at += plan.beatSeconds[i];
  }
  assert.equal(plan.totalSeconds, at);
});

test('a beat is a whole number of seconds, because a frame is', () => {
  // The renderer draws one picture per second. A boundary inside a second shows
  // the next position while the previous sentence is still being read.
  const plan = narrationPlan([{ clipSeconds: 8.078 }, { clipSeconds: 0.4 }, { clipSeconds: null }]);
  for (const seconds of plan.beatSeconds) {
    assert.equal(seconds, Math.round(seconds), 'whole seconds only');
  }
  for (const ms of plan.startMs) {
    assert.equal(ms % 1000, 0, 'and so every beat starts on a frame');
  }
});

test('there is a breath after the voice, never a beat that ends mid-word', () => {
  const clip = 5.0;
  const plan = narrationPlan([{ clipSeconds: clip }]);
  assert.ok(plan.beatSeconds[0] >= clip + BREATH_SECONDS - 1e-9,
    'the beat outlasts the sentence by at least the breath');
  const silence = plan.segments.find((s) => s.kind === 'silence');
  assert.ok(silence && silence.seconds > 0, 'and the track holds that breath as real silence');
});

test('a beat with nothing written is silent, not skipped', () => {
  // „Look at this" is a whole beat: a part can open on a position with no
  // sentence, and the film still has to stay on it long enough to be seen.
  const plan = narrationPlan([{ clipSeconds: null }]);
  assert.equal(plan.beatSeconds[0], SILENT_BEAT_SECONDS);
  assert.deepEqual(plan.segments, [{ kind: 'silence', index: 0, seconds: SILENT_BEAT_SECONDS }]);
});

test('a runaway clip is dropped, not trimmed', () => {
  // Trimming was the first answer and this test is why it is not the answer.
  // Shortening the *number* does not shorten the *file*: the track would have
  // carried the whole runaway clip while the pictures moved on at the trimmed
  // length, and every beat after it would have drifted further from its board.
  const plan = narrationPlan([{ clipSeconds: MAX_BEAT_SECONDS + 1 }, { clipSeconds: 2 }]);
  assert.equal(plan.beatSeconds[0], SILENT_BEAT_SECONDS, 'the beat is played silent');
  assert.deepEqual(
    plan.segments.filter((s) => s.kind === 'clip').map((s) => s.index),
    [1],
    'and the runaway clip never reaches the track',
  );
  assert.ok(Math.abs(secondsOf(plan) - plan.totalSeconds) < 1e-9);
  assert.ok(plan.segments.every((s) => s.seconds > 0), 'no zero-length segment reaches ffmpeg');

  // The edge itself is spoken, so the ceiling is a ceiling and not a fence.
  const edge = narrationPlan([{ clipSeconds: MAX_BEAT_SECONDS }]);
  assert.equal(edge.segments[0].kind, 'clip');
});

test('a clip that is not a number is a silent beat, not a crash', () => {
  // The duration is read out of a wav header, and a header that could not be
  // read answers 0. That must arrive here as "this beat has no voice".
  for (const clipSeconds of [0, -1, NaN, Infinity, null, undefined, '3']) {
    const plan = narrationPlan([{ clipSeconds }]);
    assert.equal(plan.beatSeconds[0], SILENT_BEAT_SECONDS, `clipSeconds ${clipSeconds}`);
  }
  assert.equal(narrationPlan([null, undefined]).beatSeconds.length, 2);
});

test('the segments name the beat they belong to, in film order', () => {
  const plan = narrationPlan([{ clipSeconds: 1.2 }, { clipSeconds: null }, { clipSeconds: 2.0 }]);
  const clips = plan.segments.filter((s) => s.kind === 'clip').map((s) => s.index);
  assert.deepEqual(clips, [0, 2], 'only the beats that were spoken');
  const order = plan.segments.map((s) => s.index);
  assert.deepEqual(order, [...order].sort((a, b) => a - b), 'and the track never goes backwards');
});

test('the events are retimed to the voice, and nothing else about them moves', () => {
  const events = [
    { timestampMs: 0, eventType: 'init', data: { fen: 'x', text: 'One.' } },
    { timestampMs: 3000, eventType: 'move', data: { fen: 'y', san: 'Nd5', text: 'Two.' } },
  ];
  const plan = narrationPlan([{ clipSeconds: 4.5 }, { clipSeconds: 1.0 }]);
  const out = retimeEvents(events, plan);

  assert.deepEqual(out.map((e) => e.timestampMs), plan.startMs);
  assert.equal(out[1].data.san, 'Nd5', 'the payload is untouched');
  assert.equal(events[1].timestampMs, 3000, 'and the input is not mutated');
});

test('an event with no plan entry keeps the timestamp it arrived with', () => {
  // Belt and braces: the two lists are built from the same captions, so this
  // cannot happen — and if it ever does, the film is still playable rather than
  // carrying an `undefined` into the renderer's frame loop.
  const events = [{ timestampMs: 0 }, { timestampMs: 9000 }];
  const out = retimeEvents(events, narrationPlan([{ clipSeconds: 2 }]));
  assert.equal(out[1].timestampMs, 9000);
});
