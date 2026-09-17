// library_kinds.test.js — the library view gains two shelves: tutorials and
// recordings. docs/PLAN-REORGANIZACIJA.md phase 3a (S3).
//
// The gate of the phase's backend half. Copied into chess_backend/test/ by the
// implementer and left there green. Written 17.9.2026, red on master: KINDS
// has three entries and the two readers do not exist.
//
// Same stub as position_library.test.js: queries are captured, canned rows
// replayed, and every assertion reads what the service asked the database.

const test = require('node:test');
const assert = require('node:assert/strict');

const lib = require('../services/positionLibrary');
const { listLibrary, isKind, KINDS } = lib;

function stubPool(results = [[]]) {
  const calls = [];
  let index = 0;
  return {
    calls,
    async query(text, params) {
      calls.push({ text: text.replace(/\s+/g, ' ').trim(), params });
      const rows = results[Math.min(index, results.length - 1)];
      index++;
      return { rows, rowCount: rows.length };
    },
  };
}

test('five shelves, by the names the API uses', () => {
  assert.deepEqual(KINDS, ['scan', 'position', 'analysis', 'tutorial', 'recording']);
  assert.equal(isKind('tutorial'), true);
  assert.equal(isKind('recording'), true);
  assert.equal(isKind('puzzle_set'), false, 'puzzle sets are device-local, never a server shelf');
  assert.equal(typeof lib.listTutorials, 'function');
  assert.equal(typeof lib.listRecordings, 'function');
});

test('a tutorial is a saved lesson with parts, read through acceptedTrainersOf', async () => {
  const pool = stubPool([[{
    id: 7, title: 'Sicilian: the Najdorf', fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    parts_count: 6, has_video: true, render_job_id: null, language: 'en',
    from_trainer: false, created_at: '2026-09-10T10:00:00Z',
  }]]);
  const rows = await lib.listTutorials(pool, 5, { search: null });
  assert.equal(pool.calls.length, 1);
  const { text, params } = pool.calls[0];
  assert.match(text, /FROM saved_lessons/);
  assert.match(text, /position_list IS NOT NULL/, 'a saved position (no parts) is not a tutorial');
  assert.match(text, /jsonb_array_length\(position_list\) AS parts_count/);
  assert.match(text, /status = 'accepted'/, 'read through acceptedTrainersOf, not a fifth copy of the condition');
  assert.deepEqual(params, [5]);
  assert.equal(rows.length, 1);
  const row = rows[0];
  assert.equal(row.kind, 'tutorial');
  assert.equal(row.id, '7');
  assert.equal(row.title, 'Sicilian: the Najdorf');
  assert.equal(row.partsCount, 6);
  assert.equal(row.hasVideo, true);
  assert.equal(row.rendering, false);
  assert.equal(row.language, 'en');
  assert.equal(row.fromTrainer, false);
  assert.equal(row.assignable, false, 'a tutorial is sent, not set as a puzzle');
  assert.ok(row.createdAt);
});

test('a tutorial with a render in flight says so', async () => {
  const pool = stubPool([[{
    id: 8, title: 'Rook endings', fen: '8/8/8/8/8/8/8/8 w - - 0 1', parts_count: 3,
    has_video: false, render_job_id: 'job-1', language: null, from_trainer: true, created_at: '2026-09-11T10:00:00Z',
  }]]);
  const [row] = await lib.listTutorials(pool, 5, { search: null });
  assert.equal(row.rendering, true);
  assert.equal(row.hasVideo, false);
  assert.equal(row.fromTrainer, true);
});

test('a recording is the host\'s own, and knows whether it has a film', async () => {
  const pool = stubPool([[
    { id: 3, title: 'Endgames, part 1', audio_url: null, video_url: null, created_at: '2026-09-12T18:00:00Z' },
    { id: 4, title: 'Endgames, part 2', audio_url: null, video_url: 'https://x/y.mp4', created_at: '2026-09-13T18:00:00Z' },
  ]]);
  const rows = await lib.listRecordings(pool, 5, { search: null });
  const { text, params } = pool.calls[0];
  assert.match(text, /FROM session_recordings/);
  assert.match(text, /host_id = \$1/);
  assert.deepEqual(params, [5]);
  assert.equal(rows.length, 2);
  assert.equal(rows[0].kind, 'recording');
  assert.equal(rows[0].id, '3');
  assert.equal(rows[0].hasVideo, false);
  assert.equal(rows[1].hasVideo, true);
  assert.equal(rows[0].fen, '', 'a recording has no board of its own');
  assert.equal(rows[0].assignable, false);
});

test('a search term reaches the two new shelves too', async () => {
  const pool = stubPool([[]]);
  await listLibrary(pool, 5, { search: 'naj' });
  assert.equal(pool.calls.length, 5, 'one query per shelf');
  for (const call of pool.calls) {
    assert.ok(call.params.includes('%naj%'), `a shelf ignored the search: ${call.text.slice(0, 40)}`);
  }
});

test('asking for one of the new shelves queries only that shelf', async () => {
  for (const kind of ['tutorial', 'recording']) {
    const pool = stubPool([[]]);
    await listLibrary(pool, 5, { kind });
    assert.equal(pool.calls.length, 1, kind);
  }
});
