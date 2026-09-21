// recording_video.test.js
// A shared lesson's video, for the student — phase 5b.5 of docs/PLAN-SESIJA.md.
//
// The owner's answer of 22.9.2026: a student downloads **the trainer's latest
// render**, while it exists. Exports age out on the retention timer
// (`retentionService.js`), and then there is nothing to hand over — the app
// says „No video yet — ask your trainer". Rendering stays the trainer's.
//
// And the link stored on the row is **not** handed out: it carries a token
// signed for the host, and since 5b.4 a row is read by students too.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const jwt = require('jsonwebtoken');
const { latestVideoFor } = require('../services/recordingVideo');

const DIR = fs.mkdtempSync(path.join(os.tmpdir(), 'exports-test-'));
const NAME = 'recording_7_wood_720p_1_ab.mp4';
const STORED = `/recordings/export-download/${encodeURIComponent(NAME)}?token=host-token`;

test('a render still on disk is handed to the reader, signed for them', () => {
  fs.writeFileSync(path.join(DIR, NAME), 'mp4');
  const url = latestVideoFor({ video_url: STORED }, 42, DIR);
  const match = /^\/recordings\/export-download\/([^?]+)\?token=(.+)$/.exec(url);
  assert.ok(match, url);
  assert.equal(decodeURIComponent(match[1]), NAME);
  const payload = jwt.verify(decodeURIComponent(match[2]), process.env.JWT_SECRET);
  assert.equal(payload.id, 42, 'signed for the student, not the host');
  assert.equal(payload.file, NAME);
  assert.equal(payload.purpose, 'download');
});

test('a render that aged out hands nothing over', () => {
  const gone = 'recording_7_gone.mp4';
  assert.equal(latestVideoFor({ video_url: `/recordings/export-download/${gone}?token=t` }, 42, DIR), null);
});

test('no render, or a link that is not an export, hands nothing over', () => {
  assert.equal(latestVideoFor({ video_url: null }, 42, DIR), null);
  assert.equal(latestVideoFor({ video_url: '/uploads/../../etc/passwd' }, 42, DIR), null);
  // A file that really is there, one folder up: without the check this would
  // be found and signed, so the case can fail.
  fs.writeFileSync(path.join(DIR, '..', 'escape-test.mp4'), 'x');
  assert.equal(latestVideoFor({ video_url: '/recordings/export-download/..%2Fescape-test.mp4?token=x' }, 42, DIR), null,
    'a name that is a path is refused, not followed');
});
