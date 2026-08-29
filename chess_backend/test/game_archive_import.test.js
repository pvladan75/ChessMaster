// game_archive_import.test.js — the stream, the split, and the count.
//
// No database and no network: the pool is a stub that answers by looking at the
// SQL, and the archive arrives from an async generator. What is worth testing
// here is not that Postgres works, it is that nothing is lost between a stream
// arriving in arbitrary chunks and a run being allowed to say 'done'.

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  createArchiveImporter,
  createGameSplitter,
  ArchiveImportUnavailable,
} = require('../services/gameArchiveImport');

const COLUMNS = 24;

function game({ white = 'subjekat', black = 'protivnik', id = 'aaaaaaaa', extra = '', moves = '1. e4 c5 2. Nf3 d6 1-0' } = {}) {
  return `[Event "rated blitz game"]
[Site "https://lichess.org/${id}"]
[White "${white}"]
[Black "${black}"]
[Result "1-0"]
[GameId "${id}"]
[UTCDate "2026.07.05"]
[UTCTime "13:04:55"]
[WhiteElo "1950"]
[BlackElo "2010"]
[TimeControl "180+2"]
${extra}
${moves}`;
}

const ARCHIVE = [
  game({ id: 'aaaaaaaa' }),
  game({ id: 'bbbbbbbb', moves: '1. d4 d5 1-0' }),
  game({ id: 'cccccccc', extra: '[Variant "Chess960"]\n' }),
  game({ id: 'dddddddd', white: 'neko', black: 'drugi' }),
].join('\n\n');

/// Feeds text through the stream as bytes, in chunks of [size].
function streamOf(text, size = 64) {
  const bytes = new TextEncoder().encode(text);
  return (async function* body() {
    for (let i = 0; i < bytes.length; i += size) yield bytes.slice(i, i + size);
  }());
}

/// A pool that answers by reading the statement. Ordered results would break
/// the moment a query is added, and this importer issues five different ones.
function fakeDb({ newest = null, running = [], insertedOf = (n) => n } = {}) {
  const calls = [];
  const query = async (text, params = []) => {
    const flat = text.replace(/\s+/g, ' ').trim();
    calls.push({ text: flat, params });
    if (/UPDATE user_game_imports SET status = 'failed'/.test(flat)) {
      return { rows: [], rowCount: 0 };
    }
    if (/SELECT id FROM user_game_imports/.test(flat)) {
      return { rows: running, rowCount: running.length };
    }
    if (/SELECT MAX\(played_at\)/.test(flat)) {
      return { rows: [{ newest }], rowCount: 1 };
    }
    if (/INSERT INTO user_game_imports/.test(flat)) {
      return { rows: [{ id: 77, started_at: new Date() }], rowCount: 1 };
    }
    if (/INSERT INTO user_games/.test(flat)) {
      const offered = params.length / COLUMNS;
      const stored = insertedOf(offered);
      return { rows: Array.from({ length: stored }, () => ({ id: 1 })), rowCount: stored };
    }
    if (/UPDATE user_game_imports/.test(flat)) return { rows: [], rowCount: 1 };
    if (/SELECT \* FROM user_game_imports/.test(flat)) {
      return { rows: [{ id: 77, status: 'done' }], rowCount: 1 };
    }
    throw new Error(`unexpected query: ${flat.slice(0, 70)}`);
  };
  return {
    calls,
    query,
    connect: async () => ({ query, release() {} }),
    lastUpdate() {
      return [...calls].reverse().find((c) => /UPDATE user_game_imports SET games_read/.test(c.text));
    },
  };
}

function importerOver(db, text, { status = 200, ...rest } = {}) {
  const seen = {};
  return {
    seen,
    importer: createArchiveImporter({
      pool: db,
      minGapMs: 0,
      sleep: async () => {},
      fetchImpl: async (url) => {
        seen.url = url;
        return {
          ok: status >= 200 && status < 300,
          status,
          body: streamOf(text),
        };
      },
      ...rest,
    }),
  };
}

test('a game split across chunk boundaries is not lost', async () => {
  // The whole reason the splitter buffers rather than emitting eagerly. Fed one
  // byte at a time, an archive has to come out as the same games it does when
  // fed whole — anything else loses the game straddling a boundary, and loses
  // it silently.
  const whole = [];
  const wholeSplitter = createGameSplitter((g) => whole.push(g));
  wholeSplitter.feed(ARCHIVE);
  wholeSplitter.end();

  for (const size of [1, 7, 64, 5000]) {
    const byChunk = [];
    const splitter = createGameSplitter((g) => byChunk.push(g));
    for (let i = 0; i < ARCHIVE.length; i += size) {
      splitter.feed(ARCHIVE.slice(i, i + size));
    }
    splitter.end();
    assert.deepEqual(byChunk, whole, `chunk size ${size} produced different games`);
  }
  assert.equal(whole.length, 4);
});

test('the last game is emitted even with no trailing newline', () => {
  const seen = [];
  const splitter = createGameSplitter((g) => seen.push(g));
  splitter.feed(game({ id: 'zzzzzzzz' }));
  assert.equal(seen.length, 0, 'nothing is complete until the stream ends');
  splitter.end();
  assert.equal(seen.length, 1);
});

test('an import counts what was stored, what was known, and what was refused', async () => {
  const db = fakeDb();
  const { importer, seen } = importerOver(db, ARCHIVE);
  const { importId, finished } = await importer.start({ userId: 5, subject: 'subjekat' });
  const snapshot = await finished;

  assert.equal(importId, 77);
  // Four read: two usable, one Chess960, one the subject is not in.
  assert.deepEqual(snapshot, {
    read: 4,
    stored: 2,
    duplicate: 0,
    skipped: 2,
    skipped_by_reason: { 'not-standard-variant': 1, 'subject-not-in-game': 1 },
  });
  assert.match(seen.url, /\/subjekat\?/);
  assert.match(seen.url, /clocks=true/);
  assert.match(seen.url, /opening=true/);

  const closing = db.lastUpdate();
  assert.equal(closing.params[6], 'done');
});

test('games the database already had are counted as duplicates, not lost', async () => {
  // ON CONFLICT DO NOTHING returns fewer rows than were offered, and the
  // difference is the only honest source of the duplicate count. Counting it
  // anywhere else would be guessing at what the database did.
  const db = fakeDb({ insertedOf: () => 0 });
  const { importer } = importerOver(db, ARCHIVE);
  const { finished } = await importer.start({ userId: 5, subject: 'subjekat' });
  const snapshot = await finished;
  assert.equal(snapshot.stored, 0);
  assert.equal(snapshot.duplicate, 2);
  assert.equal(snapshot.read, snapshot.stored + snapshot.duplicate + snapshot.skipped);
});

test('an incremental run resumes from the newest game it already has', async () => {
  const newest = new Date('2026-07-05T13:04:55Z');
  const db = fakeDb({ newest });
  const { importer, seen } = importerOver(db, ARCHIVE);
  const { since, finished } = await importer.start({ userId: 5, subject: 'subjekat' });
  await finished;
  assert.equal(since, newest);
  assert.match(seen.url, new RegExp(`since=${newest.getTime()}`));
});

test('a second run for the same user is refused rather than doubled', async () => {
  // Two streams over one archive would spend the shared allowance twice and
  // count every game twice.
  const db = fakeDb({ running: [{ id: 41 }] });
  const { importer } = importerOver(db, ARCHIVE);
  await assert.rejects(
    () => importer.start({ userId: 5, subject: 'subjekat' }),
    (err) => err instanceof ArchiveImportUnavailable && err.status === 409,
  );
});

test('a run abandoned by a restarted process is reaped before the next one', async () => {
  const db = fakeDb();
  const { importer } = importerOver(db, ARCHIVE);
  const { finished } = await importer.start({ userId: 5, subject: 'subjekat' });
  await finished;
  const reap = db.calls.find((c) => /SET status = 'failed'/.test(c.text));
  assert.ok(reap, 'stale runs are never reaped, so one crash blocks the user forever');
  assert.match(reap.text, /status = 'running'/);
});

test('an unknown account fails the run and says which kind of failure it was', async () => {
  const db = fakeDb();
  const { importer } = importerOver(db, '', { status: 404 });
  const { finished } = await importer.start({ userId: 5, subject: 'nepostojeci' });
  await assert.rejects(finished, (err) => err.reason === 'not-found' && err.status === 404);

  const closing = db.lastUpdate();
  assert.equal(closing.params[6], 'failed');
  assert.match(closing.params[7], /ne zna za nalog/);
});

test('a refusal from Lichess is never written as a finished run', async () => {
  const db = fakeDb();
  const { importer } = importerOver(db, '', { status: 429 });
  const { finished } = await importer.start({ userId: 5, subject: 'subjekat' });
  await assert.rejects(finished, (err) => err.reason === 'rate-limited');
  const done = db.calls.filter((c) => c.params && c.params[6] === 'done');
  assert.equal(done.length, 0);
});

test('an archive past the ceiling stops instead of pulling forever', async () => {
  const db = fakeDb();
  const { importer } = importerOver(db, ARCHIVE, { maxGames: 2 });
  const { finished } = await importer.start({ userId: 5, subject: 'subjekat' });
  await assert.rejects(finished, (err) => err.reason === 'too-large');
});

test('a pasted PGN takes the same path and needs no network', async () => {
  const db = fakeDb();
  const importer = createArchiveImporter({
    pool: db,
    fetchImpl: () => { throw new Error('the paste path must not reach the network'); },
  });
  const { finished } = await importer.start({
    userId: 5, subject: 'subjekat', source: 'pgn', pgnText: ARCHIVE,
  });
  const snapshot = await finished;
  assert.equal(snapshot.read, 4);
  assert.equal(snapshot.stored, 2);
  assert.equal(snapshot.skipped, 2);
});

test('an unknown source and a missing handle are refused before anything runs', async () => {
  const db = fakeDb();
  const { importer } = importerOver(db, ARCHIVE);
  await assert.rejects(
    () => importer.start({ userId: 5, subject: '   ' }),
    (err) => err.status === 400,
  );
  await assert.rejects(
    () => importer.start({ userId: 5, subject: 'subjekat', source: 'chessbase' }),
    (err) => err.status === 400,
  );
  assert.equal(db.calls.length, 0, 'nothing should have been written');
});

test('rows are written in batches, with every column bound', async () => {
  const db = fakeDb();
  const { importer } = importerOver(db, ARCHIVE, { batchSize: 1 });
  const { finished } = await importer.start({ userId: 5, subject: 'subjekat' });
  await finished;
  const inserts = db.calls.filter((c) => /INSERT INTO user_games/.test(c.text));
  assert.equal(inserts.length, 2, 'one insert per game at batch size 1');
  for (const insert of inserts) {
    assert.equal(insert.params.length, COLUMNS);
    assert.equal(insert.params[0], 5, 'every row is scoped to the caller');
    assert.match(insert.text, /ON CONFLICT \(user_id, source, external_id, subject\) DO NOTHING/);
  }
});
