// account_deletion_db.test.js
// Deleting an account, on a real database — the half a stub cannot hold.
//
// `services/accountDeletion.js` deletes two tables by hand and leaves every
// other row to `ON DELETE CASCADE`. That is a claim about the whole schema,
// and it stays true only while every table that is added keeps it, so it is
// asked of the schema itself rather than of a list somebody maintains:
//
//   1. every foreign key cascades or sets null — one that does neither makes
//      `DELETE FROM users` fail for whoever has a row behind it;
//   2. every column that names a user is a foreign key — one that is not
//      leaves that account's rows behind, silently;
//   3. every column that names a file is one this deletion has been told
//      about — a cascade deletes rows, never files.
//
// Then the deletion itself, on an account with rows in the tables that carry
// files and people: nothing that names it is left, what it returns is what
// went, and somebody else's rows are untouched.

const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');

const { skipUnlessDatabase, freshDatabase } = require('./support/pgTestDb');

const skip = skipUnlessDatabase();

describe('deleting an account on a real database', { skip: skip ? skip.skip : false }, () => {
  let db;
  let pool;
  let accountDeletion;

  before(async () => {
    db = await freshDatabase();
    pool = db.pool;
    accountDeletion = require('../services/accountDeletion');
  });

  after(async () => {
    if (db) await db.drop();
  });

  let minted = 0;
  async function user(name = 'Vladan') {
    minted += 1;
    const r = await pool.query(
      `INSERT INTO users (email, password_hash, name) VALUES ($1, 'x', $2) RETURNING id`,
      [`del${process.pid}_${minted}@test.invalid`, name],
    );
    return r.rows[0].id;
  }

  /// Every column that references `users`, as `{ tbl, col }`.
  async function userColumns() {
    const r = await pool.query(
      `SELECT c.conrelid::regclass::text AS tbl, a.attname AS col
         FROM pg_constraint c
         JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY (c.conkey)
        WHERE c.contype = 'f' AND c.confrelid = 'users'::regclass`,
    );
    return r.rows;
  }

  test('every foreign key in the schema cascades or sets null', async () => {
    const r = await pool.query(
      `SELECT c.conrelid::regclass::text AS tbl, c.conname, c.confdeltype
         FROM pg_constraint c
        WHERE c.contype = 'f' AND c.confdeltype NOT IN ('c', 'n')`,
    );
    assert.deepEqual(r.rows, [], 'a key that neither cascades nor nulls blocks the deletion of an account');
    const all = await pool.query(`SELECT count(*)::int AS n FROM pg_constraint WHERE contype = 'f'`);
    assert.ok(all.rows[0].n > 50, `the query must be looking at the real schema: ${all.rows[0].n} keys`);
  });

  test('every column that names a user is a foreign key to users', async () => {
    const named = await pool.query(
      `SELECT table_name || '.' || column_name AS c
         FROM information_schema.columns
        WHERE table_schema = 'public' AND data_type IN ('integer', 'bigint')
          AND column_name ~ '(^|_)(user|trainer|student|host|owner|creator|author|sender|friend|recipient|by)(_id)?$'
        ORDER BY 1`,
    );
    const keyed = new Set((await userColumns()).map((k) => `${k.tbl}.${k.col}`));
    assert.ok(named.rows.length > 40, `the pattern must match the real columns: ${named.rows.length}`);
    assert.deepEqual(named.rows.map((r) => r.c).filter((c) => !keyed.has(c)), []);
  });

  test('every column that names a file is one the deletion knows', async () => {
    const r = await pool.query(
      `SELECT table_name || '.' || column_name AS c
         FROM information_schema.columns
        WHERE table_schema = 'public' AND column_name ~ '(file|filename|url|path)$'
        ORDER BY 1`,
    );
    // A new name here is a new file an account can own. Before adding it to
    // this list, teach `accountDeletion.deleteAccount` (and its caller) to
    // remove it — or say here why it is not a file of the account's.
    assert.deepEqual(r.rows.map((row) => row.c), [
      'lichess_puzzles.game_url', // a web address of a public game
      'repertoires.root_path', // moves, not a file
      'saved_lessons.narration_filename', // removed
      'saved_lessons.video_filename', // removed
      'session_recordings.audio_file', // removed
      'session_recordings.audio_url', // removed
      'session_recordings.video_url', // removed
      'tutorial_render_jobs.filename', // the film `video_filename` names
    ]);
  });

  /// An account with a tutorial of its own (narrated, filmed), a tutorial it
  /// taught that sits on a student's shelf, two recordings — one shared, one
  /// with a transcript — a live session, a student, an analysis and a
  /// notification it sent.
  async function populated() {
    const id = await user('Trener');
    const student = await user('Ucenik');
    const own = await pool.query(
      `INSERT INTO saved_lessons (user_id, title, fen, narration_filename, video_filename)
       VALUES ($1, 'Own', 'startpos', 'narration_own.wav', 'tutorial_own.mp4') RETURNING id`,
      [id],
    );
    await pool.query(
      `INSERT INTO saved_lessons (user_id, trainer_id, title, fen, narration_filename)
       VALUES ($1, $2, 'Taught', 'startpos', 'narration_taught.wav')`,
      [student, id],
    );
    await pool.query(
      `INSERT INTO tutorial_render_jobs (id, user_id, lesson_id, status, filename)
       VALUES ($1, $2, $3, 'done', 'tutorial_own.mp4')`,
      [`job-${id}`, id, own.rows[0].id],
    );
    const shared = await pool.query(
      `INSERT INTO session_recordings (host_id, title, timeline_json, audio_file, video_url)
       VALUES ($1, 'Shared', '[]', 'lesson_a.wav', '/recordings/export-download/recording_a.mp4?token=t')
       RETURNING id`,
      [id],
    );
    await pool.query(
      `INSERT INTO session_recordings (host_id, title, timeline_json, audio_url)
       VALUES ($1, 'Old', '[]', '/uploads/recording_old.aac')`,
      [id],
    );
    await pool.query('INSERT INTO recording_shares (recording_id, student_id) VALUES ($1, $2)', [shared.rows[0].id, student]);
    await pool.query(`INSERT INTO rooms (room_code, creator_id) VALUES ($1, $2)`, [String(100000 + id), id]);
    await pool.query(
      `INSERT INTO rooms (room_code, creator_id, status, ended_at) VALUES ($1, $2, 'archived', NOW())`,
      [String(200000 + id), id],
    );
    await pool.query(
      `INSERT INTO trainer_students (trainer_id, student_id, status, initiated_by) VALUES ($1, $2, 'accepted', $1)`,
      [id, student],
    );
    await pool.query(
      `INSERT INTO user_notifications (user_id, sender_id, title, message) VALUES ($1, $2, 'T', 'M')`,
      [student, id],
    );
    return { id, student };
  }

  async function rowsNaming(id) {
    const left = [];
    for (const { tbl, col } of await userColumns()) {
      // eslint-disable-next-line no-await-in-loop
      const r = await pool.query(`SELECT count(*)::int AS n FROM ${tbl} WHERE "${col}" = $1`, [id]);
      if (r.rows[0].n > 0) left.push(`${tbl}.${col}: ${r.rows[0].n}`);
    }
    return left;
  }

  test('nothing that names the account is left, and what went is what is answered', async () => {
    const { id, student } = await populated();
    const before = await rowsNaming(id);
    assert.ok(before.length >= 8, `the fixture must put rows behind the account: ${before}`);

    const gone = await accountDeletion.deleteAccount(pool, id);

    assert.deepEqual(await rowsNaming(id), []);
    assert.equal((await pool.query('SELECT 1 FROM users WHERE id = $1', [id])).rowCount, 0);
    assert.deepEqual(gone.rooms, [String(100000 + id)], 'only the session that was live');
    const byName = (a, b) => String(a.narration_filename).localeCompare(String(b.narration_filename));
    assert.deepEqual(gone.lessons.sort(byName), [
      { narration_filename: 'narration_own.wav', video_filename: 'tutorial_own.mp4' },
      { narration_filename: 'narration_taught.wav', video_filename: null },
    ], 'the tutorial it taught cascades too, so its file is answered too');
    assert.deepEqual(gone.recordings.sort((a, b) => String(a.audio_file).localeCompare(String(b.audio_file))), [
      { audio_file: 'lesson_a.wav', audio_url: null, video_url: '/recordings/export-download/recording_a.mp4?token=t' },
      { audio_file: null, audio_url: '/uploads/recording_old.aac', video_url: null },
    ]);
    // The student is still there, with nothing of the trainer's.
    assert.equal((await pool.query('SELECT 1 FROM users WHERE id = $1', [student])).rowCount, 1);
    assert.equal((await pool.query('SELECT 1 FROM saved_lessons WHERE user_id = $1', [student])).rowCount, 0);
  });

  test('somebody else\'s account is untouched', async () => {
    const a = await populated();
    const b = await populated();
    const before = await rowsNaming(b.id);
    const tables = async () => (await pool.query(
      `SELECT (SELECT count(*) FROM saved_lessons)::int AS lessons,
              (SELECT count(*) FROM session_recordings)::int AS recordings,
              (SELECT count(*) FROM rooms)::int AS rooms,
              (SELECT count(*) FROM users)::int AS users`,
    )).rows[0];
    const was = await tables();

    await accountDeletion.deleteAccount(pool, a.id);

    assert.deepEqual(await rowsNaming(b.id), before);
    const now = await tables();
    assert.deepEqual(now, {
      lessons: was.lessons - 2, recordings: was.recordings - 2, rooms: was.rooms - 2, users: was.users - 1,
    });
    assert.equal(
      (await pool.query(`SELECT status FROM rooms WHERE room_code = $1`, [String(100000 + b.id)])).rows[0].status,
      'active',
      'the other trainer\'s session is still live',
    );
  });

  test('an account that does not exist deletes nothing', async () => {
    await populated();
    const count = async () => (await pool.query('SELECT count(*)::int AS n FROM users')).rows[0].n;
    const was = await count();
    assert.equal(await accountDeletion.deleteAccount(pool, 99999999), null);
    assert.equal(await count(), was);
  });

  test('a failure half way leaves the account whole', async () => {
    const { id } = await populated();
    const before = await rowsNaming(id);
    const failing = {
      async connect() {
        const client = await pool.connect();
        const query = client.query.bind(client);
        client.query = (text, params) => {
          if (/^DELETE FROM users/.test(String(text).trim())) {
            return Promise.reject(new Error('refused'));
          }
          return query(text, params);
        };
        const release = client.release.bind(client);
        client.release = () => {
          client.query = query;
          release();
        };
        return client;
      },
    };
    await assert.rejects(accountDeletion.deleteAccount(failing, id), /refused/);
    assert.deepEqual(await rowsNaming(id), before, 'the two deletes before it were rolled back');
    assert.equal(
      (await pool.query(`SELECT status FROM rooms WHERE room_code = $1`, [String(100000 + id)])).rows[0].status,
      'active',
    );
  });
});
