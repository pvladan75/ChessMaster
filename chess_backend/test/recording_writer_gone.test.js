// recording_writer_gone.test.js
// A room's recording has no writer any more — phase 5a of docs/PLAN-SESIJA.md.
//
// `POST /recordings/save` was the one door by which a room's audio reached
// `uploads/`, and it went first: the checks that guarded it (the roster half of
// `mayRecordRoom`, the consent stop, the recorded roster) are only safe to
// delete once nothing can write what they checked. What stays is the reading
// half — the list, one recording, the MP4 export and its download — because
// `uploads/` and the `session_recordings` rows are kept as they are.

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const recordingsRouter = require('../routes/recordings');

function routes() {
  return recordingsRouter.stack
    .filter((l) => l.route)
    .flatMap((l) => Object.keys(l.route.methods)
      .map((m) => `${m.toUpperCase()} ${l.route.path}`))
    .sort();
}

// Phase 5b (22.9.2026) brought one writer back, on purpose: a lesson an adult
// records alone in Preparation. The room's stays gone. What this file holds
// now is that the lesson's is the only one — its own rules, gate before multer
// included, are test/lesson_recording.test.js.

test("the room's writer stays gone, and the lesson's is the only one", () => {
  const writers = routes().filter((r) => !r.startsWith('GET ')
    && r !== 'POST /:id/export-mp4' && r !== 'PUT /:id/shares');
  assert.deepEqual(writers, ['POST /lesson']);
  assert.equal(routes().includes('POST /save'), false);
});

test('what exists is still read, played and exported', () => {
  assert.deepEqual(routes(), [
    'GET /',
    'GET /:id',
    'GET /:id/shares',
    'GET /export-download/:filename',
    'GET /lesson-audio/:filename',
    'GET /lesson-limits',
    'POST /:id/export-mp4',
    'POST /lesson',
    'PUT /:id/shares',
  ]);
});
