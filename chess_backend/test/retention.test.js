const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');

const { cleanupOldExports } = require('../services/retentionService');

function makeTempDir() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'retention-test-'));
}

function writeAged(dir, filename, ageDays) {
  const filePath = path.join(dir, filename);
  fs.writeFileSync(filePath, 'fake mp4 bytes');
  const ageMs = ageDays * 24 * 60 * 60 * 1000;
  const past = new Date(Date.now() - ageMs);
  fs.utimesSync(filePath, past, past);
  return filePath;
}

test('deletes exports older than the cutoff, keeps recent ones', async () => {
  const dir = makeTempDir();
  const oldFile = writeAged(dir, 'old.mp4', 20);
  const freshFile = writeAged(dir, 'fresh.mp4', 1);

  const result = await cleanupOldExports(null, { dir, maxAgeDays: 14 });

  assert.strictEqual(result.deleted, 1);
  assert.strictEqual(fs.existsSync(oldFile), false);
  assert.strictEqual(fs.existsSync(freshFile), true);
});

test('a missing directory is a no-op, not an error', async () => {
  const result = await cleanupOldExports(null, { dir: path.join(os.tmpdir(), 'does-not-exist-xyz'), maxAgeDays: 14 });
  assert.deepStrictEqual(result, { deleted: 0, freedBytes: 0 });
});

test('nothing older than the cutoff means nothing deleted', async () => {
  const dir = makeTempDir();
  writeAged(dir, 'fresh.mp4', 2);

  const result = await cleanupOldExports(null, { dir, maxAgeDays: 14 });

  assert.strictEqual(result.deleted, 0);
});

test('clears video_url for recordings pointing at a deleted export', async () => {
  const dir = makeTempDir();
  writeAged(dir, 'recording_42_classic_wood_720p_1234.mp4', 30);

  const queries = [];
  const fakePool = {
    query: async (sql, params) => {
      queries.push({ sql, params });
      return { rows: [] };
    },
  };

  await cleanupOldExports(fakePool, { dir, maxAgeDays: 14 });

  // Two now, one per table that names an export: a recorded lesson's
  // `video_url` and a tutorial's `video_filename`. Found by name rather than by
  // position, because „exactly one query" was an assertion about the sweep's
  // shape rather than about what it clears — and the next table to keep a
  // filename would break it again.
  const cleared = queries.find((q) => /UPDATE session_recordings SET video_url = NULL/.test(q.sql));
  assert.ok(cleared, 'the recording that named this export is cleared');
  assert.match(cleared.params[0], /recording_42_classic_wood_720p_1234\.mp4/);
});

test('clears video_filename for tutorials pointing at a deleted export', async () => {
  // A tutorial keeps the name of its current film. Left behind, the
  // saved-tutorials list draws „Download video" on a row whose file this sweep
  // has just deleted.
  const dir = makeTempDir();
  writeAged(dir, 'tutorial_12_wood_720p_1234_abcd.mp4', 30);

  const queries = [];
  const fakePool = {
    query: async (sql, params) => {
      queries.push({ sql, params });
      return { rows: [] };
    },
  };

  await cleanupOldExports(fakePool, { dir, maxAgeDays: 14 });

  const cleared = queries.find((q) => /UPDATE saved_lessons SET video_filename = NULL/.test(q.sql));
  assert.ok(cleared, 'the tutorial that named this export is cleared');
  // The whole filename, not a `LIKE` over part of it: this column holds the
  // name itself, and a pattern would match a second tutorial whose film is
  // named with this one as a prefix.
  assert.strictEqual(cleared.params[0], 'tutorial_12_wood_720p_1234_abcd.mp4');
});
