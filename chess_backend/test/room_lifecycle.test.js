// room_lifecycle.test.js — a session has a beginning and an end.
//
// Reported live on 21.9.2026 as three faults — no voice, a recording „with
// several present", nobody sure who led — and the server log gave one cause:
// two accounts in two different rooms, one of them let in by an old invitation.
// A room never ended, so every invitation ever sent was still a door
// (`docs/PLAN-SESIJA.md`, §1; `services/roomLifecycle.js`).
//
// Two halves. The SQL runs on a real database, because „ends only your own
// room" and „leaves the new one alone" live in a WHERE clause and a stub
// answers whatever it was told. The announcement runs on a fake `io`, because
// what it promises is an order.
//
// Needs TEST_DATABASE_URL for the first half (see test/support/pgTestDb.js).

const { test, describe, before, after } = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const realtime = require('../services/realtime');
const { skipUnlessDatabase, freshDatabase } = require('./support/pgTestDb');

const skip = skipUnlessDatabase();

describe('a session ends, on a real database', { skip: skip ? skip.skip : false }, () => {
  let db;
  let pool;
  let lifecycle;
  let access;

  before(async () => {
    db = await freshDatabase();
    pool = db.pool;
    lifecycle = require('../services/roomLifecycle');
    access = require('../services/roomAccess');
  });

  after(async () => {
    if (db) await db.drop();
  });

  let minted = 0;
  async function person(name) {
    minted++;
    const result = await pool.query(
      `INSERT INTO users (email, password_hash, name) VALUES ($1, 'x', $2) RETURNING id`,
      [`p${process.pid}_${minted}@test.invalid`, name],
    );
    return result.rows[0].id;
  }

  /// Codes are six characters and unique, so each test mints its own.
  function code() {
    minted++;
    return String(100000 + ((process.pid * 7 + minted * 13) % 900000));
  }

  async function roomOf(creatorId) {
    const roomCode = code();
    await pool.query('INSERT INTO rooms (room_code, creator_id) VALUES ($1, $2)', [roomCode, creatorId]);
    return roomCode;
  }

  async function accepted(trainerId, studentId) {
    await pool.query(
      `INSERT INTO trainer_students (trainer_id, student_id, status) VALUES ($1, $2, 'accepted')`,
      [trainerId, studentId],
    );
  }

  const statusOf = async (roomCode) => (await pool.query(
    'SELECT status, ended_at FROM rooms WHERE room_code = $1', [roomCode],
  )).rows[0];

  test('a new room is live, and has a beginning', async () => {
    const roomCode = await roomOf(await person('Trainer'));

    const row = (await pool.query(
      'SELECT status, created_at, ended_at FROM rooms WHERE room_code = $1', [roomCode],
    )).rows[0];

    assert.equal(row.status, 'active');
    assert.ok(row.created_at instanceof Date);
    assert.equal(row.ended_at, null);
  });

  test('its creator ends it, once', async () => {
    const trainer = await person('Trainer');
    const roomCode = await roomOf(trainer);

    assert.equal(await lifecycle.endRoom(pool, { roomCode, userId: trainer }), true);
    const row = await statusOf(roomCode);
    assert.equal(row.status, 'archived');
    assert.ok(row.ended_at instanceof Date);

    // The second press finds nothing live. That is what lets the route announce
    // an ending once however often the button is pressed.
    assert.equal(await lifecycle.endRoom(pool, { roomCode, userId: trainer }), false);
  });

  test('nobody ends a room that is not theirs', async () => {
    const trainer = await person('Trainer');
    const student = await person('Ana');
    await accepted(trainer, student);
    const roomCode = await roomOf(trainer);

    assert.equal(await lifecycle.endRoom(pool, { roomCode, userId: student }), false);
    assert.equal((await statusOf(roomCode)).status, 'active');
  });

  test('starting a session ends the ones this trainer had open, and only theirs', async () => {
    const trainer = await person('Trainer');
    const other = await person('Other trainer');
    const stale = await roomOf(trainer);
    const staler = await roomOf(trainer);
    const theirs = await roomOf(other);

    const ended = await lifecycle.endLiveRoomsOf(pool, trainer);

    assert.deepEqual([...ended].sort(), [stale, staler].sort());
    assert.equal((await statusOf(stale)).status, 'archived');
    assert.equal((await statusOf(staler)).status, 'archived');
    assert.equal((await statusOf(theirs)).status, 'active', 'somebody else’s session was ended');

    // Already ended rooms are not ended again: the list is who to tell.
    assert.deepEqual(await lifecycle.endLiveRoomsOf(pool, trainer), []);
  });

  test('a double tap starts one session, not two', async () => {
    // Reported live on 22.9.2026: „Start session" pressed twice a few
    // milliseconds apart left two live rooms. Five at once, so the race has
    // every chance to show; each start is its own connection, as two HTTP
    // requests are.
    const trainer = await person('Trainer');
    const codes = [code(), code(), code(), code(), code()];

    const started = await Promise.all(
      codes.map((roomCode) => lifecycle.startSession(pool, { creatorId: trainer, roomCode })),
    );

    const live = (await pool.query(
      `SELECT room_code FROM rooms WHERE creator_id = $1 AND status <> 'archived'`, [trainer],
    )).rows.map((row) => row.room_code);
    assert.equal(live.length, 1, `live rooms after five starts: ${live.join(', ')}`);

    // Every room but the survivor was ended by exactly one later start, so the
    // people in it are told once.
    const endedCodes = started.flatMap((result) => result.ended).sort();
    assert.deepEqual(endedCodes, codes.filter((c) => c !== live[0]).sort());
  });

  test('a start that fails leaves the open session open', async () => {
    const trainer = await person('Trainer');
    const open = await roomOf(trainer);

    // A taken code makes the insert fail after the old room was ended; the
    // ending must roll back with it, or a failed start leaves no session at all.
    await assert.rejects(lifecycle.startSession(pool, { creatorId: trainer, roomCode: open }));
    assert.equal((await statusOf(open)).status, 'active');
  });

  test('an ended room is refused at the door, and says why only to its own people', async () => {
    const trainer = await person('Trainer');
    const student = await person('Ana');
    const stranger = await person('Stranger');
    await accepted(trainer, student);
    const roomCode = await roomOf(trainer);

    assert.equal(await lifecycle.roomState(pool, { roomCode, userId: student }), 'live');

    await lifecycle.endRoom(pool, { roomCode, userId: trainer });

    assert.equal(await lifecycle.roomState(pool, { roomCode, userId: student }), 'ended');
    assert.equal(await lifecycle.roomState(pool, { roomCode, userId: trainer }), 'ended');
    assert.equal(await lifecycle.roomState(pool, { roomCode, userId: stranger }), 'not-yours');
    assert.equal(await lifecycle.roomState(pool, { roomCode: '000000', userId: student }), 'not-yours');

    const seat = await access.mayJoinRoom(pool, { roomCode, userId: student });
    assert.deepEqual(seat, { allowed: false, reason: 'ended', role: null });
  });

  test('Home is told which of my trainers are in a session now', async () => {
    // What replaced typing a code (removed 21.9.2026): the app names the room
    // for the student, so there is nothing to mistype and no old code to reuse.
    const vladan = await person('Vladan');
    const other = await person('Other trainer');
    const stranger = await person('Stranger trainer');
    const pending = await person('Pending trainer');
    const student = await person('Ana');
    await accepted(vladan, student);
    await accepted(other, student);
    await pool.query(
      `INSERT INTO trainer_students (trainer_id, student_id, status) VALUES ($1, $2, 'pending')`,
      [pending, student],
    );
    // And the student teaches somebody too — whose session is not theirs to join.
    const pupil = await person('Pupil');
    await accepted(student, pupil);

    const old = await roomOf(vladan);
    await lifecycle.endRoom(pool, { roomCode: old, userId: vladan });
    const live = await roomOf(vladan);
    await roomOf(stranger);
    await roomOf(pending);
    const own = await roomOf(student);

    const sessions = await lifecycle.liveSessionsFor(pool, student);

    assert.deepEqual(sessions, [{ roomCode: live, trainerName: 'Vladan' }],
      'ended, a stranger’s, an unanswered request’s and one’s own are all left out');

    // Nothing for the trainer in their student's session: the door is one way.
    assert.deepEqual(await lifecycle.liveSessionsFor(pool, vladan), []);
    assert.ok(own);
  });

  test('a session narrowed to other people is not offered', async () => {
    const trainer = await person('Trainer');
    const invited = await person('Invited');
    const left = await person('Left out');
    await accepted(trainer, invited);
    await accepted(trainer, left);
    const roomCode = await roomOf(trainer);
    await pool.query('INSERT INTO room_guests (room_code, user_id) VALUES ($1, $2)', [roomCode, invited]);

    assert.equal((await lifecycle.liveSessionsFor(pool, invited)).length, 1);
    assert.deepEqual(await lifecycle.liveSessionsFor(pool, left), [],
      'offered a door that mayJoinRoom would then refuse');
  });

  test('the bell knows which invitations still lead somewhere', async () => {
    const trainer = await person('Trainer');
    const student = await person('Ana');
    const old = await roomOf(trainer);
    await lifecycle.endRoom(pool, { roomCode: old, userId: trainer });
    const current = await roomOf(trainer);

    for (const roomCode of [old, current]) {
      await pool.query(
        `INSERT INTO user_notifications (user_id, sender_id, room_code, title, message)
         VALUES ($1, $2, $3, 'Chess session invitation', 'x')`,
        [student, trainer, roomCode],
      );
    }
    await pool.query(
      `INSERT INTO user_notifications (user_id, sender_id, room_code, title, message)
       VALUES ($1, $2, NULL, 'Something else', 'x')`,
      [student, trainer],
    );

    const db2 = require('../db');
    const original = db2.pool.query;
    db2.pool.query = (...args) => pool.query(...args);
    let body;
    try {
      const router = require('../routes/social');
      const layer = router.stack.find(
        (l) => l.route && l.route.path === '/notifications' && l.route.methods.get,
      );
      const handlers = layer.route.stack.map((s) => s.handle);
      await handlers[handlers.length - 1](
        { user: { id: student } },
        { status() { return this; }, json(payload) { body = payload; return this; } },
      );
    } finally {
      db2.pool.query = original;
    }

    const live = Object.fromEntries(body.notifications.map((n) => [n.room_code, n.room_live]));
    assert.equal(live[old], false, 'an invitation to an ended session is still offered as a door');
    assert.equal(live[current], true);
    assert.equal(live.null, false, 'a notification that names no room is not an invitation');
  });
});

/// Records what was done to it, in order.
function fakeIo() {
  const log = [];
  return {
    log,
    to: (room) => ({ emit: (event, payload) => log.push(['emit', room, event, payload]) }),
    in: (room) => ({ socketsLeave: (left) => log.push(['leave', room, left]) }),
  };
}

test('ending a room tells the people in it before it puts them out', () => {
  const io = fakeIo();
  realtime.init(io);
  const forgotten = [];
  realtime.onRoomClosed((roomCode) => forgotten.push(roomCode));

  realtime.closeRoom('123456', { reason: 'ended' });

  // Emptied first, the announcement would go to an empty room and everybody in
  // it would sit in a dead session with nothing said.
  assert.deepEqual(io.log.map((entry) => entry[0]), ['emit', 'leave']);
  assert.deepEqual(io.log[0], ['emit', '123456', 'session_ended', { roomId: '123456', reason: 'ended' }]);
  assert.deepEqual(forgotten, ['123456']);
});

test('a closer that throws does not keep the others from forgetting the room', () => {
  const io = fakeIo();
  realtime.init(io);
  const forgotten = [];
  realtime.onRoomClosed(() => { throw new Error('boom'); });
  realtime.onRoomClosed((roomCode) => forgotten.push(roomCode));

  assert.doesNotThrow(() => realtime.closeRoom('654321'));
  assert.deepEqual(forgotten, ['654321']);
});

test('an announcement that fails does not leave the rosters behind', () => {
  realtime.init({ to: () => { throw new Error('transport down'); }, in: () => ({ socketsLeave() {} }) });
  const forgotten = [];
  realtime.onRoomClosed((roomCode) => forgotten.push(roomCode));

  assert.doesNotThrow(() => realtime.closeRoom('111111'));
  assert.deepEqual(forgotten, ['111111']);
});

// The routes, on a stubbed pool: what they ask and in which order.
const db = require('../db');
const roomsRouter = require('../routes/rooms');

async function call(method, path, { userId, params = {}, body = {} }, answer) {
  const layer = roomsRouter.stack.find(
    (l) => l.route && l.route.path === path && l.route.methods[method],
  );
  assert.ok(layer, `${method.toUpperCase()} /rooms${path} must be mounted`);

  const queries = [];
  const original = db.pool.query;
  const originalConnect = db.pool.connect;
  db.pool.query = async (text, values) => {
    const sql = text.replace(/\s+/g, ' ').trim();
    queries.push(sql);
    return answer(sql, values) ?? { rows: [], rowCount: 0 };
  };
  // A transaction's client records into the same list, so the order across
  // `pool` and `client` is the order the route asked in.
  db.pool.connect = async () => ({ query: db.pool.query, release() {} });
  const answered = { status: 200, body: null };
  const res = {
    status(codeValue) { answered.status = codeValue; return this; },
    json(payload) { answered.body = payload; return this; },
  };
  const handlers = layer.route.stack.map((s) => s.handle);
  try {
    await handlers[handlers.length - 1]({ user: { id: userId }, params, body }, res);
  } finally {
    db.pool.query = original;
    db.pool.connect = originalConnect;
  }
  return { ...answered, queries };
}

test('creating a room ends the previous ones first, and tells the people in them', async () => {
  const io = fakeIo();
  realtime.init(io);

  const result = await call('post', '/create', { userId: 7 }, (sql) => {
    if (/^UPDATE rooms SET status = 'archived'/.test(sql)) {
      return { rows: [{ room_code: '856933' }], rowCount: 1 };
    }
    if (/^INSERT INTO rooms/.test(sql)) {
      return { rows: [{ room_code: 'new' }], rowCount: 1 };
    }
    return null;
  });

  assert.equal(result.status, 201);
  const update = result.queries.findIndex((sql) => /^UPDATE rooms SET status = 'archived'/.test(sql));
  const insert = result.queries.findIndex((sql) => /^INSERT INTO rooms/.test(sql));
  assert.ok(update >= 0, 'the previous session was never ended');
  // The other way round, the room just made is ended with the rest.
  assert.ok(update < insert, 'the new room is inserted before the old ones are ended');
  // One transaction, the trainer locked before anything is read: a second
  // start waits for this one, which is what keeps a double tap to one room.
  const at = (re) => result.queries.findIndex((sql) => re.test(sql));
  const lock = at(/^SELECT id FROM users WHERE id = \$1 FOR NO KEY UPDATE$/);
  assert.ok(at(/^BEGIN$/) >= 0 && at(/^BEGIN$/) < lock, 'the trainer is not locked inside a transaction');
  assert.ok(lock < update, 'the old sessions are ended before the trainer is locked');
  assert.ok(insert < at(/^COMMIT$/), 'the new room is inserted outside the transaction');
  assert.deepEqual(
    io.log.filter((entry) => entry[0] === 'emit').map((entry) => [entry[1], entry[2], entry[3].reason]),
    [['856933', 'session_ended', 'replaced']],
  );
});

test('ending is announced once: a second press ends nothing and says nothing', async () => {
  const io = fakeIo();
  realtime.init(io);

  const first = await call('post', '/:roomCode/end', { userId: 7, params: { roomCode: '192803' } },
    (sql) => (/^UPDATE rooms/.test(sql) ? { rows: [{ room_code: '192803' }], rowCount: 1 } : null));
  const second = await call('post', '/:roomCode/end', { userId: 7, params: { roomCode: '192803' } },
    () => null);

  assert.deepEqual(first.body, { ended: true });
  assert.deepEqual(second.body, { ended: false });
  assert.equal(io.log.filter((entry) => entry[0] === 'emit').length, 1);
});
