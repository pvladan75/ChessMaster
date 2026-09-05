// scan_upload_limits.test.js
// What a trainer is told when the upload fails before any scanning starts.
//
// Found live on 5.9.2026: a 43 MB book against a 25 MB ceiling produced
// `Skeniranje nije uspelo (500).` in the app and `MulterError: File too large`
// in the server log. Nothing in the message said "too big", so the one thing
// the trainer could actually do about it — split the PDF — was unguessable.
//
// **What hid it:** multer aborts the upload mid-stream, so the route handler
// never runs and never gets to its own error handling. The error walks past it
// to Express, whose default handler answers with an HTML page and a bare 500 —
// no `error` field for the client to read, so the client falls back to printing
// the status code. The route looked like it handled its failures; the failure
// it looked like it handled was the only one that never reached it.

const test = require('node:test');
const assert = require('node:assert/strict');
const multer = require('multer');

const { uploadRejection, MAX_DOCUMENT_BYTES } = require('../services/scanIntake');

test('a book over the ceiling is refused by size, and says so', () => {
  const rejection = uploadRejection(new multer.MulterError('LIMIT_FILE_SIZE', 'document'));

  assert.equal(rejection.status, 413, 'not a 500: nothing on this server went wrong');
  assert.equal(rejection.body.code, 'file_too_large');
  assert.match(
    rejection.body.error,
    new RegExp(`${Math.round(MAX_DOCUMENT_BYTES / (1024 * 1024))} MB`),
    'the ceiling is a number the client does not know, so the server names it'
  );
});

test('a document that is not a PDF is the caller\'s business too, not a server error', () => {
  const rejection = uploadRejection(new Error('Podržan je samo PDF.'));

  assert.equal(rejection.status, 400);
  assert.equal(rejection.body.error, 'Podržan je samo PDF.');
});

test('an upload failure that is not about size does not claim the file was too big', () => {
  // Blaming size for every multer failure would be the same mistake one layer
  // down: a message that is confidently about the wrong thing.
  const rejection = uploadRejection(new multer.MulterError('LIMIT_UNEXPECTED_FILE', 'document'));

  assert.equal(rejection.status, 400);
  assert.doesNotMatch(rejection.body.error, /MB/);
});

test('a request that did not fail is not refused', () => {
  assert.equal(uploadRejection(null), null);
  assert.equal(uploadRejection(undefined), null);
});

test('the scans route actually asks, rather than letting the error walk past it', () => {
  // The helper being right and the route calling it are two different things,
  // and it was the second one that was missing. Express marks an error handler
  // by arity, so this reads the mounted router rather than the file's text.
  const router = require('../routes/scans');
  const handlers = router.stack
    .filter((layer) => typeof layer.handle === 'function' && layer.handle.length === 4)
    .map((layer) => layer.handle);

  assert.equal(handlers.length, 1, 'the scans router must handle upload errors itself');

  const answered = { status: null, body: null };
  const res = {
    status(code) {
      answered.status = code;
      return this;
    },
    json(body) {
      answered.body = body;
      return this;
    },
  };
  handlers[0](new multer.MulterError('LIMIT_FILE_SIZE', 'document'), {}, res, () => {
    throw new Error('next() bi vratio grešku Expressu, što je i bio kvar');
  });

  assert.equal(answered.status, 413);
  assert.equal(answered.body.code, 'file_too_large');
});
