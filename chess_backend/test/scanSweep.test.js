const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

// Deliberately the service, not the route. Requiring the route pulled in the
// auth middleware, which exits the process when JWT_SECRET is unset — so this
// file killed CI at import, before a single assertion ran.
const { sweepLeftovers } = require('../services/scanTempFiles');

test('a document orphaned by a killed scan is swept at startup', () => {
  // The route deletes its upload in a `finally`, which does not run when the
  // process is killed mid-request — nodemon restarting on a save is enough.
  // Found live: a 5 MB copy of a book left in the temp directory.
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sweep-test-'));
  fs.writeFileSync(path.join(dir, 'scan_123_abc.pdf'), 'ostatak');
  fs.writeFileSync(path.join(dir, 'scan_456_def.pdf'), 'ostatak');
  fs.writeFileSync(path.join(dir, 'nesto-drugo.txt'), 'ne diraj');
  // Left by a process that died an hour ago.
  const anHourAgo = new Date(Date.now() - 60 * 60 * 1000);
  for (const name of fs.readdirSync(dir)) fs.utimesSync(path.join(dir, name), anHourAgo, anHourAgo);

  const removed = sweepLeftovers(dir);

  assert.equal(removed, 2);
  assert.deepEqual(fs.readdirSync(dir), ['nesto-drugo.txt'], 'only scan_ uploads are swept');
  fs.rmSync(dir, { recursive: true, force: true });
});

test('an upload still in flight in another process is not swept', () => {
  // Every process that loads the scan route sweeps at startup, and node --test
  // runs test files as parallel processes: one file's startup deleted another
  // file's upload mid-request (CI, 22.9 and 23.9.2026: ENOENT on the upload,
  // a 500 from POST /scans/images). A dev server restarting beside a running
  // suite did the same. A leftover is old; an upload in flight is seconds old.
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sweep-test-'));
  fs.writeFileSync(path.join(dir, 'scan_789_ghi.pdf'), 'u toku');
  const old = path.join(dir, 'scan_111_old.pdf');
  fs.writeFileSync(old, 'ostatak');
  const anHourAgo = new Date(Date.now() - 60 * 60 * 1000);
  fs.utimesSync(old, anHourAgo, anHourAgo);

  assert.equal(sweepLeftovers(dir), 1);
  assert.deepEqual(fs.readdirSync(dir), ['scan_789_ghi.pdf']);
  fs.rmSync(dir, { recursive: true, force: true });
});

test('sweeping a directory that does not exist is not an error', () => {
  const missing = path.join(os.tmpdir(), 'sweep-test-nema-me-' + Date.now());
  assert.equal(sweepLeftovers(missing), 0);
});

test('the sweeper needs no secrets, no database and no routes', () => {
  // The point of the split: CI has no .env, and a test about files must not
  // depend on one. Loading the module in a bare process is the whole assertion.
  const before = process.env.JWT_SECRET;
  delete process.env.JWT_SECRET;
  try {
    delete require.cache[require.resolve('../services/scanTempFiles')];
    const fresh = require('../services/scanTempFiles');
    assert.equal(typeof fresh.sweepLeftovers, 'function');
  } finally {
    if (before !== undefined) process.env.JWT_SECRET = before;
  }
});
