// render_budget.test.js — whether a film is short enough to draw in one go,
// answered before anything is drawn. Item 4 of part two of
// docs/PLAN-SNIMANJE.md; since item 5 the tutorial film's ceiling is the
// longest one film may hold the render slot (600 s), and the connection's own
// number (300 s) is read only for an export still drawn inside its request.
const test = require('node:test');
const assert = require('node:assert/strict');

const budget = require('../services/renderBudget');

const KEYS = [
  'RENDER_MAX_DRAW_SECONDS', 'RENDER_REQUEST_SECONDS', 'RENDER_DRAW_FPS_720P', 'RENDER_DRAW_FPS_1080P',
];

/// Runs [fn] with exactly [vars] set among the budget's keys, and puts the
/// environment back afterwards — a test that leaves a rate behind decides the
/// next file's verdicts.
function withEnv(vars, fn) {
  const saved = Object.fromEntries(KEYS.map((k) => [k, process.env[k]]));
  for (const k of KEYS) delete process.env[k];
  Object.assign(process.env, vars);
  try {
    return fn();
  } finally {
    for (const k of KEYS) {
      if (saved[k] === undefined) delete process.env[k];
      else process.env[k] = saved[k];
    }
  }
}

test('the defaults are the development machine\'s slow end, with a margin', () => {
  withEnv({}, () => {
    assert.equal(budget.maxDrawSeconds(), 600,
      'the owner\'s ceiling for a film drawn in the background, since item 5');
    assert.equal(budget.requestSeconds(), 300, 'nginx closes a proxied request after 300 s');
    // The two-minute fixture: 480 frames, measured at 15.4 to 30.2 s on the
    // development machine. The budget says 40, which is above every sample.
    assert.equal(budget.drawSeconds({ seconds: 120, fps: 4, resolution: '720p' }), 40);
    assert.equal(budget.drawSeconds({ seconds: 120, fps: 4, resolution: '1080p' }), 80,
      'a 1080p frame costs about twice a 720p one');
    assert.equal(budget.drawSeconds({ seconds: 120, fps: 1, resolution: '720p' }), 10,
      'a film with nothing said is drawn once a second');
    assert.equal(budget.drawSeconds({ seconds: 120, fps: 4, resolution: '480p' }), 40,
      '480p is judged at the 720p rate, never a faster one');
  });
});

test('thirty minutes of captioned film is exactly one film\'s ceiling at 720p', () => {
  // The owner's numbers of 10.9.2026: 600 s of drawing, so thirty-minute
  // tutorials at 720p. The longest recorded narration is derived from the same
  // arithmetic, so raising the ceiling or lowering the rate moves both.
  withEnv({}, () => {
    const film = { seconds: 30 * 60, fps: 4 };
    assert.equal(budget.drawSeconds({ ...film, resolution: '720p' }), budget.maxDrawSeconds());
    assert.equal(budget.longestFilmSeconds({ fps: 4, resolution: '720p' }), 30 * 60);
    assert.ok(budget.drawSeconds({ ...film, resolution: '1080p' }) > budget.maxDrawSeconds(),
      'and at 1080p it does not, which is why 720p is offered as a way out');
  });
});

test('the rate is configuration, measured where the drawing happens', () => {
  withEnv({
    RENDER_DRAW_FPS_720P: '24', RENDER_DRAW_FPS_1080P: '8', RENDER_MAX_DRAW_SECONDS: '900', RENDER_REQUEST_SECONDS: '120',
  }, () => {
    assert.equal(budget.drawSeconds({ seconds: 120, fps: 4, resolution: '720p' }), 20);
    assert.equal(budget.drawSeconds({ seconds: 120, fps: 4, resolution: '1080p' }), 60);
    assert.equal(budget.maxDrawSeconds(), 900);
    assert.equal(budget.requestSeconds(), 120);
  });
  withEnv({
    RENDER_DRAW_FPS_720P: 'fast', RENDER_DRAW_FPS_1080P: '0', RENDER_MAX_DRAW_SECONDS: '-1', RENDER_REQUEST_SECONDS: 'x',
  }, () => {
    assert.equal(budget.drawRate('720p'), 12, 'a value that is not a rate is not taken as one');
    assert.equal(budget.drawRate('1080p'), 6);
    assert.equal(budget.maxDrawSeconds(), 600);
    assert.equal(budget.requestSeconds(), 300);
  });
});

test('the film\'s ceiling and the connection\'s are two settings, not one', () => {
  // They were one number while the film was drawn inside its request. They are
  // not any more, and a setting honoured under the other's name is two
  // settings that can disagree without anybody seeing it.
  withEnv({ RENDER_REQUEST_SECONDS: '120' }, () => {
    assert.equal(budget.maxDrawSeconds(), 600);
  });
  withEnv({ RENDER_MAX_DRAW_SECONDS: '900' }, () => {
    assert.equal(budget.requestSeconds(), 300);
  });
});

test('a promise is never shorter than the work', () => {
  withEnv({}, () => {
    // 121 s at 4 fps is 484 frames, 40.33 s at 12 a second.
    assert.equal(budget.drawSeconds({ seconds: 121, fps: 4, resolution: '720p' }), 41);
    // And what fits is rounded the other way: 600 s at 12 a second is 7200
    // frames, 1800 s of film at 4 fps.
    assert.equal(budget.longestFilmSeconds({ fps: 4, resolution: '720p' }), 1800);
    assert.equal(budget.longestFilmSeconds({ fps: 4, resolution: '1080p' }), 900);
  });
});

test('the refusal says how long, how much fits, and what to do', () => {
  withEnv({}, () => {
    const alone = budget.tooLongSentence({ drawSeconds: 900, fps: 4, resolution: '720p' });
    assert.match(alone, /^This video would take about 15 minutes to render/);
    assert.match(alone, /about 30 minutes of video in one go/);
    assert.match(alone, /Split the tutorial into two shorter ones\.$/,
      'splitting is always a way out, and the only one when nothing else was checked');

    const doors = budget.tooLongSentence({
      drawSeconds: 900, fps: 4, resolution: '1080p',
      doors: ['export it at 720p', 'export it without your recording'],
    });
    assert.match(doors, /about 15 minutes of video in one go/, 'what fits at the resolution asked for');
    assert.match(doors,
      /Split the tutorial into two shorter ones, export it at 720p, or export it without your recording\.$/);

    // Two tutorials of a film that needs three goes are two refusals.
    assert.match(budget.tooLongSentence({ drawSeconds: 1300, fps: 4, resolution: '720p' }),
      /into three shorter ones/);

    assert.match(budget.tooLongSentence({ drawSeconds: 900, fps: 4, resolution: '720p', narrated: true }),
      /^With narration, this video would take/);
  });
});

test('the retry says when, and never „in 0 minutes"', () => {
  assert.match(budget.retrySentence(0), /Try again in a minute or two\.$/);
  assert.match(budget.retrySentence(45_000), /Try again in a minute or two\.$/);
  assert.match(budget.retrySentence(5 * 60_000 + 1), /Try again in about 6 minutes\.$/);
  assert.doesNotMatch(budget.retrySentence(0), /busy/,
    'the server has room; what it lacks is time, and „busy" is the queue-full sentence');
});

test('the frames counted are the frames the renderer draws', () => {
  // `framesPerSecondOf` is the renderer's own rule, and the budget reads it
  // rather than keeping a copy. It had no test of its own: a mutation drawing
  // every film once a second passed the whole suite, which would have made
  // every captioned film look four times cheaper than it is.
  const videoRenderer = require('../videoRenderer');
  const fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  const said = [{ timestampMs: 0, eventType: 'init', data: { fen, text: 'Look at the d5 square.' } }];
  const silent = [{ timestampMs: 0, eventType: 'init', data: { fen } }];
  assert.equal(videoRenderer.CAPTION_FPS, 4);
  assert.equal(videoRenderer.framesPerSecondOf(said, { resolution: '720p' }), 4);
  assert.equal(videoRenderer.framesPerSecondOf(silent, { resolution: '720p' }), 1);
});
