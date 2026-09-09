// tutorial_preview_frames.test.js — POST /lessons/:id/preview-frames
//
// **A still of a film nobody has rendered yet.** Before it, the only way to
// find out that the board skin was wrong, that a sentence overflows the caption
// band, or that a part stands the wrong way round was to spend a queue slot on
// the whole film and watch it.
//
// The frames here are drawn for real — `renderPreviewFrame` needs no ffmpeg,
// which is the property that makes a preview cheap and this file honest: it
// reads pixels out of the actual answer rather than out of a stub.
//
// Gates:
//  1. no entitlement → refused;
//  2. somebody else's tutorial → 404, and the query carries the user;
//  3. empty `events` → 400;
//  4. more than the cap, or a beat that is not in the film → 400;
//  5. the default picks the opening, a middle beat and the end;
//  6. the frames are PNGs, and **different frames**, which is what says the
//     events were applied rather than the first board drawn three times;
//  7. nothing is metered and no file is written.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const db = require('../db');
const lessonsRouter = require('../routes/lessons');
const videoRenderer = require('../videoRenderer');

/// Three beats, each on a different position, the middle one carrying a
/// sentence, an arrow and a coloured square.
const EVENTS = [
  {
    timestampMs: 0,
    eventType: 'init',
    data: {
      fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      text: 'We start from the opening position and look at the centre.',
      orientation: 'white',
    },
  },
  {
    timestampMs: 4000,
    eventType: 'move',
    data: {
      fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
      san: 'e4', from: 'e2', to: 'e4',
      text: 'The king pawn takes a central square and opens two lines at once.',
      arrows: [{ from: 'e2', to: 'e4', color: 'G' }],
      squares: [{ square: 'd5', color: 'R' }],
      orientation: 'white',
    },
  },
  {
    timestampMs: 9000,
    eventType: 'move',
    data: {
      fen: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
      san: 'e5', from: 'e7', to: 'e5',
      text: 'Black answers in the middle and the fight is about who develops faster.',
      orientation: 'white',
    },
  },
];

function handlers() {
  const layer = lessonsRouter.stack.find(
    (l) => l.route && l.route.path === '/:id/preview-frames' && l.route.methods.post,
  );
  assert.ok(layer, 'POST /lessons/:id/preview-frames must be mounted');
  return layer.route.stack.map((s) => s.handle);
}

async function run({
  params = { id: '15' },
  body = { events: EVENTS, seconds: 12, resolution: '480p', boardTheme: 'wood' },
  userId = 4,
  tier = 'premium',
  lesson = { id: 15, title: 'Weak squares' },
} = {}) {
  const queries = [];
  const originalQuery = db.pool.query;

  // The same three questions the export route's own test answers, in the same
  // order: the account's type, its subscription, and the tutorial.
  db.pool.query = async (sql, values) => {
    queries.push({ sql, values });
    if (/SELECT account_type FROM users/i.test(sql)) {
      return { rows: [{ account_type: tier }], rowCount: 1 };
    }
    if (/SELECT tier, status/i.test(sql)) {
      return { rows: [], rowCount: 0 };
    }
    if (/FROM saved_lessons/i.test(sql)) {
      return { rows: lesson ? [lesson] : [], rowCount: lesson ? 1 : 0 };
    }
    return { rows: [], rowCount: 0 };
  };

  const res = {
    statusCode: 200,
    body: null,
    writableFinished: false,
    on() { return this; },
    off() { return this; },
    status(code) { this.statusCode = code; return this; },
    json(payload) { this.body = payload; return this; },
  };
  const req = { params, body, user: { id: userId, role: 'trener' } };

  try {
    // `authenticateToken` is skipped and the user is set by hand, exactly as
    // `tutorial_video_export.test.js` does: this file is about the preview, and
    // signing a JWT here would test the middleware a hundred other routes share.
    const stack = handlers();
    assert.equal(stack.length, 3,
      'route must carry authenticateToken, requireEntitlement and the handler');

    // `requireEntitlement` calls `next()` without awaiting it, so awaiting the
    // middleware is not awaiting the handler — the first version of this
    // harness read `res.body` while the frames were still being drawn and saw
    // null. The handler's own completion is what is waited on.
    let handlerDone = Promise.resolve();
    await stack[1](req, res, () => { handlerDone = stack[2](req, res); });
    await handlerDone;
  } finally {
    db.pool.query = originalQuery;
  }

  return { res, queries };
}

const PNG_MAGIC = Buffer.from([0x89, 0x50, 0x4e, 0x47]);

test('the default preview is the opening, a middle beat and the end', async () => {
  const { res } = await run();

  assert.equal(res.statusCode, 200, JSON.stringify(res.body));
  assert.equal(res.body.frames.length, 3);
  assert.deepEqual(res.body.frames.map((f) => f.beatIndex), [0, 1, 2]);
});

test('the frames are PNGs, and they are different frames', async () => {
  const { res } = await run();

  const buffers = res.body.frames.map((f) => Buffer.from(f.png, 'base64'));
  for (const buf of buffers) {
    assert.ok(buf.subarray(0, 4).equals(PNG_MAGIC), 'each frame is a PNG');
    assert.ok(buf.length > 1000, 'and not an empty one');
  }

  // **The gate that matters.** A preview that folded no events would draw the
  // opening position three times and every other assertion here would still
  // pass — a picture of a film nobody is going to render.
  assert.notEqual(buffers[0].length === buffers[1].length && buffers[0].equals(buffers[1]), true,
    'beat 1 is not the same drawing as beat 0');
  assert.notEqual(buffers[1].length === buffers[2].length && buffers[1].equals(buffers[2]), true,
    'beat 2 is not the same drawing as beat 1');
});

test('a chosen beat is the one drawn', async () => {
  const one = await run({ body: { events: EVENTS, seconds: 12, resolution: '480p', beats: [2] } });
  assert.equal(one.res.statusCode, 200);
  assert.deepEqual(one.res.body.frames.map((f) => f.beatIndex), [2]);

  const both = await run({ body: { events: EVENTS, seconds: 12, resolution: '480p', beats: [0, 2] } });
  assert.deepEqual(both.res.body.frames.map((f) => f.beatIndex), [0, 2]);
});

test('somebody else\'s tutorial is a 404, and the query carries the user', async () => {
  const { res, queries } = await run({ lesson: null, userId: 9 });

  assert.equal(res.statusCode, 404);
  const lookup = queries.find((q) => /FROM saved_lessons/i.test(q.sql));
  assert.deepEqual(lookup.values, ['15', 9]);
});

test('empty events is refused', async () => {
  const { res } = await run({ body: { events: [], seconds: 12 } });
  assert.equal(res.statusCode, 400);
  assert.match(res.body.error, /events/);
});

test('more frames than the cap is refused', async () => {
  const { res } = await run({
    body: { events: EVENTS, seconds: 12, beats: [0, 1, 2, 0, 1] },
  });
  assert.equal(res.statusCode, 400);
  assert.match(res.body.error, /At most/);
});

test('a beat that is not in this film is refused', async () => {
  for (const beats of [[3], [-1], [1.5], ['first']]) {
    const { res } = await run({ body: { events: EVENTS, seconds: 12, beats } });
    assert.equal(res.statusCode, 400, `beats ${JSON.stringify(beats)} must be refused`);
  }
});

test('a preview writes no file and meters nothing', async () => {
  const exportsDir = path.join(__dirname, '..', 'exports');
  const before = fs.existsSync(exportsDir) ? fs.readdirSync(exportsDir).length : 0;

  const { res, queries } = await run();

  assert.equal(res.statusCode, 200);
  const after = fs.existsSync(exportsDir) ? fs.readdirSync(exportsDir).length : 0;
  assert.equal(after, before, 'a preview leaves nothing in exports/');

  // A preview that ate into the quota would push a trainer back towards
  // rendering blind, which is the thing it exists to stop.
  const metered = queries.filter((q) => /usage|metric/i.test(q.sql));
  assert.deepEqual(metered, []);
});

test('previewBeatIndexes never repeats a beat and never leaves the film', () => {
  for (const count of [1, 2, 3, 4, 10, 240]) {
    const picks = videoRenderer.previewBeatIndexes(count);
    assert.ok(picks.length >= 1 && picks.length <= 3);
    assert.equal(new Set(picks).size, picks.length, `no repeats for ${count}`);
    for (const p of picks) {
      assert.ok(Number.isInteger(p) && p >= 0 && p < count, `${p} is a beat of ${count}`);
    }
  }
  assert.deepEqual(videoRenderer.previewBeatIndexes(0), []);
});

test('a wordless beat is previewed with the layout its film has', async () => {
  // `renderFrameBuffer` asks only whether the film speaks at all — the caption
  // column, and a smaller board beside it. So the beat being previewed is not
  // the question: a silent opening inside a talking tutorial has to be drawn
  // the way the film will draw it, or the preview answers about a layout that
  // will never exist.
  const silent = {
    timestampMs: 0,
    eventType: 'init',
    data: { fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1' },
  };
  const spoken = {
    timestampMs: 3000,
    eventType: 'move',
    data: {
      fen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
      san: 'e4', from: 'e2', to: 'e4',
      text: 'The king pawn takes a central square, and this film therefore speaks.',
    },
  };

  const inSilentFilm = await videoRenderer.renderPreviewFrame({
    title: 'x', timelineEvents: [silent], beatIndex: 0, durationSeconds: 6, resolution: '480p',
  });
  const inTalkingFilm = await videoRenderer.renderPreviewFrame({
    title: 'x', timelineEvents: [silent, spoken], beatIndex: 0, durationSeconds: 6, resolution: '480p',
  });

  assert.equal(inSilentFilm.equals(inTalkingFilm), false,
    'the same wordless beat is drawn differently once its film has a sentence in it');
});

test('a later beat is a later position, not just a later clock', async () => {
  // **The mutation that got past the test above.** Three frames of one film
  // differ in the timer overlay alone — 00:00, 00:04, 00:09 — so „the frames
  // are different" was still true when the preview drew beat 0 three times.
  // Same family as the file letters answered by the pieces standing on rank
  // one: an assertion is only as good as the thing that can satisfy it.
  //
  // Both beats here carry the same timestamp, so the clock is identical and
  // any difference at all is the board.
  const at = (fen, extra = {}) => ({
    timestampMs: 0,
    eventType: 'init',
    data: { fen, ...extra },
  });
  const events = [
    at('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'),
    at('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1'),
  ];

  const first = await videoRenderer.renderPreviewFrame({
    title: 'x', timelineEvents: events, beatIndex: 0, durationSeconds: 6, resolution: '480p',
  });
  const second = await videoRenderer.renderPreviewFrame({
    title: 'x', timelineEvents: events, beatIndex: 1, durationSeconds: 6, resolution: '480p',
  });

  assert.equal(first.equals(second), false,
    'beat 1 must draw the position beat 1 is on');
});
