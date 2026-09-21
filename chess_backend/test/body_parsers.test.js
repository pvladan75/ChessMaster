// body_parsers.test.js
// No path reads a large JSON body before the caller is authenticated.
// See `middleware/bodyParsers.js` for the audit finding behind it.
//
// Sent over a real socket to an app mounted the way `server.js` mounts it, so
// what is asserted is what a client would meet — the parser refusing the body
// before any route runs — rather than a limit read out of source text.

const test = require('node:test');
const assert = require('node:assert/strict');
const http = require('http');
const express = require('express');

const { mountBodyParsers } = require('../middleware/bodyParsers');

function post(port, path, bytes) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify({ audioBase64: 'a'.repeat(bytes) });
    const req = http.request(
      { port, path, method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) } },
      (res) => {
        res.resume();
        res.on('end', () => resolve(res.statusCode));
      },
    );
    req.on('error', reject);
    req.end(body);
  });
}

async function withApp(fn) {
  const app = express();
  mountBodyParsers(app);
  let reached = 0;
  // Stands in for every router: if the parser let the body through, the request
  // arrives here and is answered 401, as `authenticateToken` would.
  app.use((req, res) => {
    reached += 1;
    res.status(401).json({ error: 'no token' });
  });
  const server = app.listen(0);
  await new Promise((r) => server.once('listening', r));
  try {
    await fn(server.address().port, () => reached);
  } finally {
    await new Promise((r) => server.close(r));
  }
}

for (const path of ['/recordings/1/export-mp4', '/lessons', '/invitations/send']) {
  test(`a 3 MB JSON body to ${path} is refused before any route sees it`, async () => {
    await withApp(async (port, reached) => {
      const status = await post(port, path, 3 * 1024 * 1024);
      assert.equal(status, 413);
      assert.equal(reached(), 0);
    });
  });
}

test('an ordinary JSON body still reaches the routes', async () => {
  await withApp(async (port, reached) => {
    const status = await post(port, '/recordings/1/export-mp4', 1024);
    assert.equal(status, 401);
    assert.equal(reached(), 1);
  });
});
