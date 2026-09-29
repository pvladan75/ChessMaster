// film_name.test.js — a rendered film downloads under its title and day.
//
// The owner's word of 29.9.2026: a folder of `tutorial_12_wood_720p_1759…_
// a3f9c21e.mp4` tells nobody which lesson is which. The film keeps that name on
// disk — it is what the row stores, the token is bound to and the retention
// timer reads — and is **downloaded** as „<title> - <YYYY-MM-DD>.mp4".
//
// Gates:
//  1. the on-disk name is written and read back by one module;
//  2. a title becomes a file name every system accepts, and nothing more;
//  3. the day is the server's own, not UTC's;
//  4. a name never stops a download: a foreign name, a missing row, an empty
//     title and a database that does not answer give the on-disk name;
//  5. over real HTTP, the trainer's download of a tutorial and of a recording
//     carries the title in its Content-Disposition.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const express = require('express');
const jwt = require('jsonwebtoken');
const db = require('../db');
const {
  filmFilename, filmOfFilename, cleanTitle, downloadNameFor, downloadNameOf,
} = require('../services/filmName');

// Just past midnight, local time: in any zone east of Greenwich this is still
// the day before in UTC, so a day read from `toISOString` is caught here.
const JUST_AFTER_MIDNIGHT = new Date(2026, 8, 29, 0, 30).getTime();

// ---- 1. the on-disk name ------------------------------------------------------

test('the on-disk name is written and read back by the same module', () => {
  const name = filmFilename({
    kind: 'tutorial', id: 12, boardTheme: 'marble', resolution: '1080p',
    now: JUST_AFTER_MIDNIGHT, random: 'a3f9c21e',
  });
  assert.equal(name, `tutorial_12_marble_1080p_${JUST_AFTER_MIDNIGHT}_a3f9c21e.mp4`);
  const film = filmOfFilename(name);
  assert.equal(film.kind, 'tutorial');
  assert.equal(film.id, 12);
  assert.equal(film.renderedAt.getTime(), JUST_AFTER_MIDNIGHT);

  const recording = filmOfFilename(filmFilename({ kind: 'recording', id: '7' }));
  assert.equal(recording.kind, 'recording');
  assert.equal(recording.id, 7, 'an id from req.params reads back as a number');
});

test('two films rendered in the same millisecond never share a name', () => {
  const now = Date.now();
  const a = filmFilename({ kind: 'tutorial', id: 1, now });
  const b = filmFilename({ kind: 'tutorial', id: 1, now });
  assert.notEqual(a, b);
  assert.match(a, /^tutorial_1_wood_720p_\d{13}_[0-9a-f]{8}\.mp4$/, 'wood and 720p unless asked');
});

test('a name the module did not write is not read as a film', () => {
  for (const name of [
    'tutorial_test_123_ab12cd34.mp4',
    'x.mp4',
    'lesson_12_wood_720p_1759137000000_a3f9c21e.mp4',
    'tutorial_12_wood_720p_1759137000000_a3f9c21e.mp4.exe',
    '',
    undefined,
  ]) {
    assert.equal(filmOfFilename(name), null, String(name));
  }
  assert.throws(() => filmFilename({ kind: 'lesson', id: 1 }), /Unknown film kind/);
});

// ---- 2 and 3. the download name -----------------------------------------------

test('the download name is the title and the day, in the server\'s time zone', () => {
  assert.equal(
    downloadNameFor({ title: 'Topovske završnice, 2. deo', renderedAt: new Date(JUST_AFTER_MIDNIGHT) }),
    'Topovske završnice, 2. deo - 2026-09-29.mp4',
  );
  assert.equal(downloadNameFor({ title: 'Rook endings', renderedAt: null }), 'Rook endings.mp4',
    'no day when none is known');
  assert.equal(downloadNameFor({ title: 'Rook endings', renderedAt: new Date(NaN) }), 'Rook endings.mp4');
});

test('a title becomes a file name every system accepts', () => {
  assert.equal(cleanTitle('Pawn: "a/b" \\ c|d? *e* <f>'), 'Pawn a b c d e f');
  assert.equal(cleanTitle('  two\t\nlines  '), 'two lines');
  assert.equal(cleanTitle('Ends in dots...'), 'Ends in dots', 'Windows drops a trailing dot');
  assert.equal(cleanTitle('con'), 'con_', 'a device name is not a file name on Windows');
  assert.equal(cleanTitle('COM1'), 'COM1_');
  assert.equal(cleanTitle('Console'), 'Console', 'only the device names themselves');
  assert.equal(cleanTitle('Šah i čćžđ'), 'Šah i čćžđ', 'any alphabet stays');
});

test('a long title is cut at 80 characters, never inside one', () => {
  // 😀 is two UTF-16 units: a cut counted in units would keep half of it.
  const long = 'ž'.repeat(79) + '😀end';
  const cut = cleanTitle(long);
  assert.equal(Array.from(cut).length, 80);
  assert.equal(cut, 'ž'.repeat(79) + '😀', 'whole characters only');
  assert.equal(cleanTitle('a'.repeat(79) + ' b'), 'a'.repeat(79), 'no trailing space after the cut');
});

test('a title with nothing usable in it gives no name', () => {
  for (const title of ['', '   ', '???', '...', null, undefined]) {
    assert.equal(downloadNameFor({ title, renderedAt: new Date() }), null, String(title));
  }
});

// ---- 4. a name never stops a download -----------------------------------------

function poolAnswering(answer) {
  const queries = [];
  return {
    queries,
    async query(sql, values) {
      queries.push({ sql, values });
      return answer(sql, values);
    },
  };
}

test('the title is asked of the film\'s own table, by the id in its name', async () => {
  const tutorial = filmFilename({ kind: 'tutorial', id: 12, now: JUST_AFTER_MIDNIGHT });
  const pool = poolAnswering(() => ({ rows: [{ title: 'Rook endings' }] }));
  assert.equal(await downloadNameOf(pool, tutorial), 'Rook endings - 2026-09-29.mp4');
  assert.match(pool.queries[0].sql, /FROM saved_lessons WHERE id = \$1/);
  assert.deepEqual(pool.queries[0].values, [12]);

  const recording = filmFilename({ kind: 'recording', id: 7, now: JUST_AFTER_MIDNIGHT });
  const other = poolAnswering(() => ({ rows: [{ title: 'Lesson with Mila' }] }));
  assert.equal(await downloadNameOf(other, recording), 'Lesson with Mila - 2026-09-29.mp4');
  assert.match(other.queries[0].sql, /FROM session_recordings WHERE id = \$1/);
  assert.deepEqual(other.queries[0].values, [7]);
});

test('a foreign name, a missing row, an empty title or a silent database keep the on-disk name', async () => {
  const foreign = poolAnswering(() => { throw new Error('must not be asked'); });
  assert.equal(await downloadNameOf(foreign, 'export.mp4'), 'export.mp4');
  assert.equal(foreign.queries.length, 0, 'nothing to ask about a name it did not write');

  const name = filmFilename({ kind: 'tutorial', id: 12 });
  assert.equal(await downloadNameOf(poolAnswering(() => ({ rows: [] })), name), name);
  assert.equal(await downloadNameOf(poolAnswering(() => ({ rows: [{ title: '???' }] })), name), name);
  assert.equal(await downloadNameOf(poolAnswering(() => { throw new Error('ECONNRESET'); }), name), name);
});

// ---- 5. over real HTTP --------------------------------------------------------

const recordingsRouter = require('../routes/recordings');
const { EXPORTS_DIR } = require('../services/retentionService');

async function withServer(fn) {
  const app = express();
  app.use('/recordings', recordingsRouter);
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  try {
    return await fn(server.address().port);
  } finally {
    await new Promise((resolve) => server.close(resolve));
  }
}

function get(port, urlPath) {
  return new Promise((resolve, reject) => {
    http.get({ host: '127.0.0.1', port, path: urlPath }, (res) => {
      let body = '';
      res.on('data', (chunk) => { body += chunk.toString('utf8'); });
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body }));
    }).on('error', reject);
  });
}

/// The name a browser saves an attachment under: the UTF-8 `filename*` when
/// there is one, which is what every current browser prefers.
function savedAs(header) {
  assert.match(header, /^attachment;/);
  const utf8 = /filename\*=UTF-8''([^;]+)/i.exec(header);
  if (utf8) return decodeURIComponent(utf8[1]);
  return /filename="([^"]*)"/.exec(header)[1];
}

/// Downloads [name] through the trainer's route with the database answering
/// [answer], and gives back the name the browser would save it under.
async function downloadedAs(name, answer) {
  fs.mkdirSync(EXPORTS_DIR, { recursive: true });
  const file = path.join(EXPORTS_DIR, name);
  fs.writeFileSync(file, 'mp4 bytes');
  const original = db.pool.query;
  db.pool.query = async (sql, values) => answer(sql, values);
  try {
    return await withServer(async (port) => {
      const token = jwt.sign({ purpose: 'download', file: name, id: 4 }, process.env.JWT_SECRET, { expiresIn: '5m' });
      const res = await get(port, `/recordings/export-download/${encodeURIComponent(name)}?token=${encodeURIComponent(token)}`);
      assert.equal(res.status, 200);
      assert.equal(res.body, 'mp4 bytes', 'the file itself, whatever it is called');
      assert.equal(res.headers['content-type'], 'video/mp4');
      return savedAs(res.headers['content-disposition']);
    });
  } finally {
    db.pool.query = original;
    fs.rmSync(file, { force: true });
  }
}

test('the trainer downloads a tutorial\'s film under its title and day', async () => {
  const name = filmFilename({ kind: 'tutorial', id: 12, now: JUST_AFTER_MIDNIGHT });
  const saved = await downloadedAs(name, (sql, values) => (
    /FROM saved_lessons/.test(sql) && values[0] === 12
      ? { rows: [{ title: 'Topovske završnice, 2. deo' }] }
      : { rows: [] }));
  assert.equal(saved, 'Topovske završnice, 2. deo - 2026-09-29.mp4');
});

test('a recording\'s film downloads under the recording\'s title and day', async () => {
  const name = filmFilename({ kind: 'recording', id: 7, now: JUST_AFTER_MIDNIGHT });
  const saved = await downloadedAs(name, (sql, values) => (
    /FROM session_recordings/.test(sql) && values[0] === 7
      ? { rows: [{ title: 'Lesson with Mila' }] }
      : { rows: [] }));
  assert.equal(saved, 'Lesson with Mila - 2026-09-29.mp4');
});

test('a database that does not answer still hands over the film, under its on-disk name', async () => {
  const name = filmFilename({ kind: 'tutorial', id: 12 });
  assert.equal(await downloadedAs(name, () => { throw new Error('ECONNRESET'); }), name);
});
