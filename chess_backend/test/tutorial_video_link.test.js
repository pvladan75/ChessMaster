// tutorial_video_link.test.js — a tutorial keeps its film, and hands out a link
// for it later.
//
// Until this, the only reference to a rendered video was the link in the
// export's own response, and its token expires in thirty minutes. A trainer who
// closed the „Video ready!" dialog had to render the whole film again — while
// the file sat in `exports/` for a fortnight, unreachable, until the retention
// timer took it. Ten exports of one tutorial were ten orphans.
//
// Gates:
//  1. a finished export writes the filename, the time, the resolution, the
//     length and whether it speaks onto the tutorial's own row;
//  2. the film it replaces is deleted, and the row is written **first**;
//  3. GET /lessons/:id/video mints a **fresh** token rather than storing one;
//  4. its three answers are told apart: none, expired, ready;
//  5. somebody else's tutorial is a 404.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const db = require('../db');
const lessonsRouter = require('../routes/lessons');

const EXPORTS_DIR = path.join(__dirname, '..', 'exports');

function routeHandlers(routePath, method = 'get') {
  const layer = lessonsRouter.stack.find(
    (l) => l.route && l.route.path === routePath && l.route.methods[method],
  );
  assert.ok(layer, `${method.toUpperCase()} ${routePath} must be mounted`);
  return layer.route.stack.map((s) => s.handle);
}

/// Drives GET /lessons/:id/video with the row the database would return.
async function askForVideo({ row, userId = 4, id = '12' }) {
  const queries = [];
  const originalQuery = db.pool.query;
  db.pool.query = async (sql, values) => {
    queries.push({ sql, values });
    if (/FROM saved_lessons/i.test(sql)) {
      return { rows: row ? [row] : [], rowCount: row ? 1 : 0 };
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
  const req = { params: { id }, user: { id: userId, role: 'trener' } };

  try {
    const stack = routeHandlers('/:id/video');
    // `authenticateToken` skipped and the user set by hand, as the sibling
    // export test does: this file is not about the middleware.
    await stack[stack.length - 1](req, res);
  } finally {
    db.pool.query = originalQuery;
  }
  return { res, queries };
}

function writeExport(name) {
  fs.mkdirSync(EXPORTS_DIR, { recursive: true });
  const file = path.join(EXPORTS_DIR, name);
  fs.writeFileSync(file, 'not really an mp4');
  return file;
}

test('a tutorial with no video says so, and says which kind of nothing', async () => {
  const { res } = await askForVideo({
    row: { id: 12, title: 'x', video_filename: null },
  });

  assert.equal(res.statusCode, 404);
  assert.equal(res.body.status, 'none');
});

test('a film whose file is gone is not the same answer as no film', async () => {
  // The retention timer takes an export after a fortnight because a film is
  // reproducible. „It has expired" and „there never was one" lead a trainer to
  // different buttons, so they must not read the same.
  const { res } = await askForVideo({
    row: {
      id: 12,
      title: 'x',
      video_filename: 'tutorial_12_gone_720p_1_deadbeef.mp4',
      video_rendered_at: new Date('2026-09-01T10:00:00Z'),
    },
  });

  assert.equal(res.statusCode, 410);
  assert.equal(res.body.status, 'expired');
  assert.match(res.body.error, /again/i);
});

test('a film that is there comes back with a link and what it is', async () => {
  const name = `tutorial_12_wood_720p_${Date.now()}_abcdef01.mp4`;
  const file = writeExport(name);
  try {
    const { res } = await askForVideo({
      row: {
        id: 12,
        title: 'x',
        video_filename: name,
        video_rendered_at: new Date('2026-09-09T20:00:00Z'),
        video_resolution: '1080p',
        video_seconds: 632,
        video_narrated: true,
      },
    });

    assert.equal(res.statusCode, 200);
    assert.equal(res.body.status, 'ready');
    assert.equal(res.body.filename, name);
    assert.equal(res.body.resolution, '1080p');
    assert.equal(res.body.seconds, 632);
    assert.equal(res.body.narrated, true);
    assert.match(res.body.downloadUrl, /\/recordings\/export-download\//);
    assert.match(res.body.downloadUrl, /token=/);
  } finally {
    fs.unlinkSync(file);
  }
});

test('the token is minted now, not stored', async () => {
  // **Why the column holds a filename and not a URL.** A stored link carries a
  // token, and a stored token is one that outlives its own expiry — thirty
  // minutes after the export it is a link that 401s, kept for a fortnight.
  const name = `tutorial_12_wood_720p_${Date.now()}_beefcafe.mp4`;
  const file = writeExport(name);
  try {
    const first = await askForVideo({
      row: { id: 12, title: 'x', video_filename: name },
    });
    // A second ask a second later gets a token signed at that second. Same
    // secret, same payload except `iat`, so the two are only equal if one of
    // them was kept.
    await new Promise((r) => setTimeout(r, 1100));
    const second = await askForVideo({
      row: { id: 12, title: 'x', video_filename: name },
    });

    assert.equal(first.res.statusCode, 200);
    assert.equal(second.res.statusCode, 200);
    assert.notEqual(first.res.body.downloadUrl, second.res.body.downloadUrl);
  } finally {
    fs.unlinkSync(file);
  }
});

test('somebody else\'s tutorial is a 404, and the query carries the user', async () => {
  const { res, queries } = await askForVideo({ row: null, userId: 9 });

  assert.equal(res.statusCode, 404);
  const lookup = queries.find((q) => /FROM saved_lessons/i.test(q.sql));
  assert.deepEqual(lookup.values, ['12', 9]);
  assert.match(lookup.sql, /user_id = \$2 OR trainer_id = \$2/);
});

test('the list says which tutorials have a film', async () => {
  // The row has to know, or the button cannot be drawn — and a button drawn on
  // every row is the fault this repository keeps finding: an action offered
  // where it cannot be performed.
  const queries = [];
  const originalQuery = db.pool.query;
  db.pool.query = async (sql, values) => {
    queries.push({ sql, values });
    return { rows: [], rowCount: 0 };
  };

  const res = {
    statusCode: 200,
    body: null,
    status(code) { this.statusCode = code; return this; },
    json(payload) { this.body = payload; return this; },
  };

  try {
    const stack = routeHandlers('/');
    await stack[stack.length - 1]({ query: {}, user: { id: 4 } }, res);
  } finally {
    db.pool.query = originalQuery;
  }

  assert.equal(res.statusCode, 200);
  assert.match(queries[0].sql, /video_filename IS NOT NULL\) AS has_video/);
});
