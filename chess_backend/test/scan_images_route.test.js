// scan_images_route.test.js
// Phase 2 of docs/PLAN-SKENER-SLIKE.md, at the route: POST /scans/images, and
// the door POST /scans now points at.
//
// Driven over a real socket with a real signed token and a multipart upload,
// against a fake database that records every query it is sent — "nothing is
// saved" is asserted on the SQL, not assumed from the code. The books are drawn
// in test/support/drawnBooks.mjs; none is in the repository.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const express = require('express');
const jwt = require('jsonwebtoken');

// Requiring a route drags in middleware/auth, which exits at import without
// JWT_SECRET (CLAUDE.md, the 5.9.2026 note). Worthless and never used to sign
// anything real.
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const db = require('../db');
const { mountBodyParsers } = require('../middleware/bodyParsers');
const { SCAN_TMP_DIR } = require('../services/scanTempFiles');

const queries = [];
db.pool.query = async (text) => {
  const sql = String(text);
  queries.push(sql);
  if (/FROM users/.test(sql)) return { rows: [{ id: 1, role: 'korisnik', account_type: 'free' }], rowCount: 1 };
  return { rows: [], rowCount: 0 };
};
db.pool.connect = async () => ({
  query: db.pool.query,
  release() {},
});

let drawn;
const books = () => (drawn ??= import('./support/drawnBooks.mjs'));

// Each request its own account: the scan limiter counts per account and lives
// as long as the module does.
let nextUser = 500;

async function withApp(fn) {
  const router = require('../routes/scans');
  const app = express();
  mountBodyParsers(app);
  app.use('/scans', router);
  const server = app.listen(0);
  await new Promise((r) => server.once('listening', r));
  try {
    await fn(server.address().port);
  } finally {
    await new Promise((r) => server.close(r));
  }
}

async function upload(port, path, pdf, fields = {}) {
  const token = jwt.sign({ id: nextUser++, email: 'x@example.test', role: 'korisnik' }, process.env.JWT_SECRET);
  const form = new FormData();
  form.append('document', new Blob([pdf], { type: 'application/pdf' }), 'book.pdf');
  for (const [k, v] of Object.entries(fields)) form.append(k, typeof v === 'string' ? v : JSON.stringify(v));
  const res = await fetch(`http://127.0.0.1:${port}${path}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: form,
  });
  return { status: res.status, body: await res.json() };
}

/** A PDF with one diagram image per page, of each placement in turn. */
async function bookOf(placements) {
  const { positionImage, buildPdf } = await books();
  return buildPdf(placements.map((p, k) => ({
    size: [400, 400],
    images: [{ picture: positionImage(p, { seed: 20 + k }), storage: 'gray8', rect: [40, 40, 268, 240] }],
  })));
}

const tempFiles = () => (fs.existsSync(SCAN_TMP_DIR) ? fs.readdirSync(SCAN_TMP_DIR).sort() : []);

const CALIBRATION = [
  'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBN1',
  '7k/8/8/3q4/8/8/8/1KQ5',
  'r3k2r/1b1n1p2/2p5/8/3B4/2N5/1P3P2/2R3K1',
];
const TO_READ = ['8/5k2/8/3Q4/8/2n5/5B2/6K1', '4k2r/8/8/8/8/8/8/R3K2R'];

test('3. without a calibration: the boards, a preview each, three suggestions, and nothing saved', async () => {
  const pdf = await bookOf([...TO_READ, CALIBRATION[0]]);
  const before = tempFiles();
  queries.length = 0;
  await withApp(async (port) => {
    const { status, body } = await upload(port, '/scans/images', pdf, { fromPage: '1', toPage: '3' });
    assert.equal(status, 200, JSON.stringify(body));
    assert.equal(body.needsCalibration, true);
    assert.deepEqual(body.boards.map((b) => `${b.page}:${b.index}:${b.source}`), ['1:1:image', '2:1:image', '3:1:image']);
    for (const b of body.boards) {
      assert.ok(Buffer.from(b.preview, 'base64').subarray(1, 4).toString() === 'PNG', 'a preview is a PNG');
    }
    assert.equal(body.suggested.length, 3);
    // The fullest board is suggested first: the opening position on page 3.
    assert.deepEqual(body.suggested[0], { page: 3, index: 1 });
  });
  assert.ok(!queries.some((q) => /INSERT INTO custom_puzzles|UPDATE custom_puzzles/.test(q)),
    `a position was written: ${queries.filter((q) => /custom_puzzles/.test(q)).join(' | ')}`);
  assert.deepEqual(tempFiles(), before, 'the uploaded document was left behind');
});

test('4. with a calibration: every other board is read, source image, and the calibration echoed', async () => {
  const pdf = await bookOf([...CALIBRATION, ...TO_READ]);
  const before = tempFiles();
  await withApp(async (port) => {
    const calibration = CALIBRATION.map((fen, k) => ({ page: k + 1, index: 1, fen }));
    const { status, body } = await upload(port, '/scans/images', pdf, { fromPage: '1', toPage: '5', calibration });
    assert.equal(status, 200, JSON.stringify(body));
    assert.equal(body.needsCalibration, false);
    assert.deepEqual(body.calibration.map((c) => `${c.page}:${c.calibration}`), ['1:true', '2:true', '3:true']);
    // The app offers the boards the trainer set up for saving with the rest,
    // and keeps the ones that are not positions out: it reads both of these.
    for (const c of body.calibration) {
      assert.deepEqual(c.uncertain, [], `calibration board ${c.page} names uncertain squares`);
      assert.equal(typeof c.legal, 'boolean', `calibration board ${c.page} does not say whether it is a position`);
    }
    // All three are positions (the first is the opening position without its
    // h1 rook). A board the reader calls "not a position" is the app's case,
    // image_scan_screen_test.dart; here the field has to be there and true.
    assert.deepEqual(body.calibration.map((c) => c.legal), [true, true, true]);
    assert.deepEqual(body.positions.map((p) => [p.page, p.source, p.placement]),
      [[4, 'image', TO_READ[0]], [5, 'image', TO_READ[1]]]);
    for (const p of body.positions) {
      assert.ok(Array.isArray(p.uncertain), 'every position names its uncertain squares');
      assert.equal(p.legal, true);
    }
    assert.ok(body.composed.includes('R/light'), `composed: ${body.composed}`);
  });
  assert.deepEqual(tempFiles(), before, 'the uploaded document was left behind');
});

test('4. a calibration that is not a board is refused, never half-used', async () => {
  const pdf = await bookOf(TO_READ);
  await withApp(async (port) => {
    const { status, body } = await upload(port, '/scans/images', pdf, {
      fromPage: '1', toPage: '2', calibration: [{ page: 1, index: 1, fen: '8/8/8 w' }],
    });
    assert.equal(status, 422);
    assert.equal(body.code, 'calibration_invalid');
  });
});

test('4. a calibration naming a board that is not there is refused by name', async () => {
  const pdf = await bookOf(TO_READ);
  await withApp(async (port) => {
    const { status, body } = await upload(port, '/scans/images', pdf, {
      fromPage: '1', toPage: '2', calibration: [{ page: 1, index: 2, fen: TO_READ[0] }],
    });
    assert.equal(status, 422);
    assert.equal(body.code, 'calibration_board_missing');
    assert.deepEqual(body.details, { page: 1, index: 2 });
  });
});

test('4. more boards than one request reads are refused with the number', async () => {
  const { MAX_IMAGE_BOARDS } = await import('../services/positionScanner/imageRead.mjs');
  // Pages with two boards each, so the count passes the ceiling within the
  // 40-page limit of a scan.
  const { positionImage, buildPdf } = await books();
  const picture = positionImage(TO_READ[0], { seed: 3 });
  const pages = Math.ceil((MAX_IMAGE_BOARDS + 1) / 2);
  const pdf = buildPdf(Array.from({ length: pages }, () => ({
    size: [400, 600],
    images: [
      { picture, storage: 'bit1', rect: [40, 20, 268, 240] },
      { picture, storage: 'bit1', rect: [40, 320, 268, 240] },
    ],
  })));
  await withApp(async (port) => {
    const { status, body } = await upload(port, '/scans/images', pdf, { fromPage: '1', toPage: String(pages) });
    assert.equal(status, 422, JSON.stringify(body).slice(0, 300));
    assert.equal(body.code, 'too_many_boards');
    assert.deepEqual(body.details, { boards: pages * 2, max: MAX_IMAGE_BOARDS });
  });
});

test('5. the font path points at the image path: no_text, with the pictures counted', async () => {
  const pdf = await bookOf(TO_READ);
  await withApp(async (port) => {
    const { status, body } = await upload(port, '/scans', pdf, { fromPage: '1', toPage: '2' });
    assert.equal(status, 422, JSON.stringify(body));
    assert.equal(body.code, 'no_text');
    assert.equal(body.details?.imageDiagrams, 2, JSON.stringify(body.details));
  });
});
