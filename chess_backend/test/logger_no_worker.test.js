// A test process that has logged must not be holding a worker thread.
//
// pino's pretty-printing transport runs in a worker (`thread-stream`). In CI
// that worker kept finished test files alive — `node --test` waits for its
// child, and four runs froze for six hours (19.9.2026; the story is in
// `services/logger.js` and docs/LESSONS.md). The logger therefore writes
// plainly under `node --test`, and this test is what keeps it so.
//
// It asserts on the process, not on the logger's options: what froze CI was a
// handle, and a handle is what is looked for.
const test = require('node:test');
const assert = require('node:assert/strict');

const logger = require('../services/logger');

test('after logging, the process holds no worker thread and no message port', () => {
  assert.ok(process.env.NODE_TEST_CONTEXT, 'this must run as a child of node --test');
  logger.info('a line, so the stream is really opened');

  const held = process.getActiveResourcesInfo();
  assert.deepEqual(
    held.filter((r) => r === 'MessagePort' || r === 'Worker'),
    [],
    `the logger opened a worker thread: ${JSON.stringify(held)}`
  );
});
