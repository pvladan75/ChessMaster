// recording_shares.test.js
// A lesson recorded in Preparation, shared with students — phase 5b.4 of
// docs/PLAN-SESIJA.md.
//
// **A share reaches a student only while the relationship is accepted.** Read
// through `acceptedTrainersOf`, like everything else a student sees because
// somebody teaches them — so a relationship that ends closes every share
// without anybody deleting a row, and one that was never accepted never opens
// one. Proved on a real database: a stub answers what it was told, whatever
// the WHERE clause says (rule 6).
//
// Needs TEST_DATABASE_URL (see test/support/pgTestDb.js); the source case at
// the end runs everywhere.

const { describe, before, after, test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const { skipUnlessDatabase, freshDatabase } = require('./support/pgTestDb');
const realtime = require('../services/realtime');

// The notification's nudge goes through the socket layer, which the server
// sets up at start and a test does not (as in homework_send.test.js).
realtime.init({ to: () => ({ emit: () => {} }) });

const skip = skipUnlessDatabase();

describe('who reads a shared lesson, on a real database', { skip: skip ? skip.skip : false }, () => {
  let db;
  let pool;
  let shares;

  before(async () => {
    db = await freshDatabase();
    pool = db.pool;
    shares = require('../services/recordingShares');
  });

  after(async () => {
    if (db) await db.drop();
  });

  let minted = 0;
  async function person(name) {
    minted++;
    const result = await pool.query(
      `INSERT INTO users (email, password_hash, name) VALUES ($1, 'x', $2) RETURNING id`,
      [`s${process.pid}_${minted}@test.invalid`, name],
    );
    return result.rows[0].id;
  }

  async function edge(trainerId, studentId, status = 'accepted') {
    await pool.query(
      'INSERT INTO trainer_students (trainer_id, student_id, status) VALUES ($1, $2, $3)',
      [trainerId, studentId, status],
    );
  }

  async function lessonOf(hostId) {
    const result = await pool.query(
      `INSERT INTO session_recordings (room_id, source, host_id, title, audio_file, duration_ms, timeline_json)
       VALUES (NULL, 'preparation', $1, 'Lucena', 'lesson_x.wav', 1000, '[]') RETURNING id`,
      [hostId],
    );
    return result.rows[0].id;
  }

  const listed = async (userId) => (await shares.readableRecordings(pool, userId)).map((r) => r.id);

  test('the host reads it, a shared student reads it, anybody else does not', async () => {
    const trainer = await person('Vladan');
    const mila = await person('Mila');
    const marko = await person('Marko');
    const stranger = await person('Stranger');
    await edge(trainer, mila);
    await edge(trainer, marko);
    const id = await lessonOf(trainer);

    const done = await shares.setShares(pool, { recordingId: id, hostId: trainer, studentIds: [mila] });
    assert.deepEqual(done, { ok: true, added: [mila] });

    assert.ok((await listed(trainer)).includes(id));
    assert.ok((await listed(mila)).includes(id));
    assert.ok(!(await listed(marko)).includes(id), 'shared with Mila, not with the class');
    assert.ok(!(await listed(stranger)).includes(id));

    assert.ok(await shares.readableRecording(pool, id, mila));
    assert.equal(await shares.readableRecording(pool, id, marko), null);
  });

  test('a relationship that ends closes the share without a row being deleted', async () => {
    const trainer = await person('T');
    const mila = await person('M');
    await edge(trainer, mila);
    const id = await lessonOf(trainer);
    await shares.setShares(pool, { recordingId: id, hostId: trainer, studentIds: [mila] });
    assert.ok((await listed(mila)).includes(id));

    // How the app ends one (relationshipService.js): the row goes. There is
    // no „removed" status — the real database refused the first draft of this
    // fixture for inventing one.
    await pool.query(
      'DELETE FROM trainer_students WHERE trainer_id = $1 AND student_id = $2',
      [trainer, mila],
    );
    assert.ok(!(await listed(mila)).includes(id));
    assert.equal(await shares.readableRecording(pool, id, mila), null);
    const row = await pool.query('SELECT 1 FROM recording_shares WHERE recording_id = $1', [id]);
    assert.equal(row.rowCount, 1, 'the share row is still there — it is the relationship that closed it');
  });

  test('only the host shares, and only with their own accepted students', async () => {
    const trainer = await person('T');
    const other = await person('Other trainer');
    const mila = await person('M');
    const pending = await person('Pending');
    const stranger = await person('S');
    await edge(trainer, mila);
    await edge(trainer, pending, 'pending');
    const id = await lessonOf(trainer);

    assert.deepEqual(
      await shares.setShares(pool, { recordingId: id, hostId: other, studentIds: [mila] }),
      { ok: false, status: 404, error: 'Recording not found.' },
    );
    for (const who of [pending, stranger]) {
      const refused = await shares.setShares(pool, { recordingId: id, hostId: trainer, studentIds: [who] });
      assert.equal(refused.ok, false);
      assert.equal(refused.status, 403);
    }
    const none = await pool.query('SELECT 1 FROM recording_shares WHERE recording_id = $1', [id]);
    assert.equal(none.rowCount, 0, 'a refused list shares with nobody, not with the valid half');
  });

  test('a room recording is not shared — it had other people in it', async () => {
    const trainer = await person('T');
    const mila = await person('M');
    await edge(trainer, mila);
    const room = await pool.query(
      `INSERT INTO session_recordings (room_id, host_id, title, timeline_json)
       VALUES ('123456', $1, 'room', '[]') RETURNING id`, [trainer]);
    const refused = await shares.setShares(pool, {
      recordingId: room.rows[0].id, hostId: trainer, studentIds: [mila],
    });
    assert.equal(refused.ok, false);
    assert.equal(refused.status, 403);
    assert.match(refused.error, /Preparation/);
  });

  test('the list is the whole list: sharing again replaces it, and says who is new', async () => {
    const trainer = await person('T');
    const a = await person('A');
    const b = await person('B');
    await edge(trainer, a);
    await edge(trainer, b);
    const id = await lessonOf(trainer);
    await shares.setShares(pool, { recordingId: id, hostId: trainer, studentIds: [a] });
    const second = await shares.setShares(pool, { recordingId: id, hostId: trainer, studentIds: [b] });
    assert.deepEqual(second, { ok: true, added: [b] });
    assert.deepEqual(await shares.sharedWith(pool, id, trainer), [b]);
    assert.ok(!(await listed(a)).includes(id));
  });

  test('a notification tells each new student, once', async () => {
    const trainer = await person('Vladan');
    const mila = await person('Mila');
    await edge(trainer, mila);
    const id = await lessonOf(trainer);
    await shares.setShares(pool, { recordingId: id, hostId: trainer, studentIds: [mila], hostName: 'Vladan' });
    await shares.setShares(pool, { recordingId: id, hostId: trainer, studentIds: [mila], hostName: 'Vladan' });
    const notes = await pool.query(
      "SELECT kind, ref_id, message FROM user_notifications WHERE user_id = $1 AND kind = 'recording_shared'",
      [mila],
    );
    assert.equal(notes.rowCount, 1);
    assert.equal(notes.rows[0].ref_id, id);
    assert.match(notes.rows[0].message, /Vladan.*Lucena/);
  });

  test('only the host deletes a recording, and its shares go with it', async () => {
    const trainer = await person('T');
    const other = await person('Other trainer');
    const mila = await person('M');
    await edge(trainer, mila);
    const id = await lessonOf(trainer);
    const kept = await lessonOf(trainer);
    await shares.setShares(pool, { recordingId: id, hostId: trainer, studentIds: [mila] });

    // A student it is shared with reads it; reading is not owning.
    assert.equal(await shares.deleteOwnRecording(pool, id, mila), null);
    assert.equal(await shares.deleteOwnRecording(pool, id, other), null);
    assert.equal(await shares.deleteOwnRecording(pool, 'x', trainer), null);
    assert.ok((await listed(mila)).includes(id), 'a refused delete deletes nothing');

    assert.deepEqual(await shares.deleteOwnRecording(pool, id, trainer),
      { audio_file: 'lesson_x.wav', audio_url: null }, 'the sound it named, for the route to remove');
    assert.ok(!(await listed(trainer)).includes(id));
    assert.ok(!(await listed(mila)).includes(id));
    const left = await pool.query('SELECT 1 FROM recording_shares WHERE recording_id = $1', [id]);
    assert.equal(left.rowCount, 0, 'the shares went with the row');
    assert.ok((await listed(trainer)).includes(kept), 'one recording, not every one of the host\'s');
    assert.equal(await shares.deleteOwnRecording(pool, id, trainer), null, 'twice is not found');
  });
});

test('the share\'s reader goes through acceptedTrainersOf, not a copy of it', () => {
  // The third hand-written copy of that subquery once forgot the status
  // (CLAUDE.md, „Consent"); a fourth is what this holds off.
  const source = fs.readFileSync(path.join(__dirname, '..', 'services', 'recordingShares.js'), 'utf8');
  assert.match(source, /\$\{acceptedTrainersOf\(/, 'the fragment is interpolated into the SQL');
  assert.doesNotMatch(source, /FROM trainer_students/);
});
