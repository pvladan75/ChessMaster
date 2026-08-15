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

  assert.strictEqual(queries.length, 1);
  assert.match(queries[0].sql, /UPDATE session_recordings SET video_url = NULL/);
  assert.match(queries[0].params[0], /recording_42_classic_wood_720p_1234\.mp4/);
});
