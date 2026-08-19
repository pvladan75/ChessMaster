const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const { sweepLeftovers } = require('../routes/scans');

test('a document orphaned by a killed scan is swept at startup', () => {
  // The route deletes its upload in a `finally`, which does not run when the
  // process is killed mid-request — nodemon restarting on a save is enough.
  // Found live: a 5 MB copy of a book left in the temp directory.
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sweep-test-'));
  fs.writeFileSync(path.join(dir, 'scan_123_abc.pdf'), 'ostatak');
  fs.writeFileSync(path.join(dir, 'scan_456_def.pdf'), 'ostatak');
  fs.writeFileSync(path.join(dir, 'nesto-drugo.txt'), 'ne diraj');

  const removed = sweepLeftovers(dir);

  assert.equal(removed, 2);
  assert.deepEqual(fs.readdirSync(dir), ['nesto-drugo.txt'], 'only scan_ uploads are swept');
  fs.rmSync(dir, { recursive: true, force: true });
});

test('sweeping a directory that does not exist is not an error', () => {
  const missing = path.join(os.tmpdir(), 'sweep-test-nema-me-' + Date.now());
  assert.equal(sweepLeftovers(missing), 0);
});
