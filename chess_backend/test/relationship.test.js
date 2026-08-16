// relationship.test.js
// Pins who may teach whom.
//
// The rule these tests defend is one WHERE clause, and losing it looks like
// nothing: every screen keeps working, homework keeps being created, and the
// only difference is that anyone can set homework for anyone whose email they
// know. That is exactly the bug this replaced, so it is asserted directly on the
// SQL rather than through behaviour that would still pass without it.

const test = require('node:test');
const assert = require('node:assert/strict');

const { trainerOwnsStudent } = require('../services/assignmentService');
const {
  requestRelationship,
  respondToRequest,
  pendingForUser,
} = require('../services/relationshipService');

/// Captures queries and replays canned rows, one result per call in order.
function stubPool(results = [[]]) {
  const calls = [];
  let index = 0;
  return {
    calls,
    async query(text, params) {
      calls.push({ text, params });
      const rows = results[Math.min(index, results.length - 1)];
      index++;
      return { rows };
    },
  };
}

test('an edge only counts once it has been accepted', async () => {
  const pool = stubPool([[{ '?column?': 1 }]]);
  await trainerOwnsStudent(pool, 1, 2);

  assert.match(pool.calls[0].text, /status\s*=\s*'accepted'/);
  assert.deepEqual(pool.calls[0].params, [1, 2]);
});

test('a pending edge grants nothing', async () => {
  // The database returns no row because the status condition filtered it out.
  const pool = stubPool([[]]);
  assert.equal(await trainerOwnsStudent(pool, 1, 2), false);
});

test('a request starts pending and remembers who started it', async () => {
  const pool = stubPool([[], [{ id: 7 }]]);
  const result = await requestRelationship(pool, {
    initiatorId: 1,
    otherId: 2,
    initiatorIsTrainer: true,
  });

  assert.equal(result.ok, true);
  assert.equal(result.id, 7);
  const insert = pool.calls[1];
  assert.match(insert.text, /'pending'/);
  assert.deepEqual(insert.params, [1, 2, 1], 'trainer, student, initiator');
});

test('a student asking a trainer lands in the other column', async () => {
  const pool = stubPool([[], [{ id: 8 }]]);
  await requestRelationship(pool, { initiatorId: 5, otherId: 9, initiatorIsTrainer: false });

  // trainer_id is the other party, student_id is the initiator, and the
  // initiator is still recorded as the one who started it.
  assert.deepEqual(pool.calls[1].params, [9, 5, 5]);
});

test('nobody may become their own trainer', async () => {
  const pool = stubPool();
  const result = await requestRelationship(pool, {
    initiatorId: 3,
    otherId: 3,
    initiatorIsTrainer: true,
  });

  assert.equal(result.ok, false);
  assert.equal(pool.calls.length, 0, 'refused before touching the database');
});

test('an existing accepted relationship is not requested again', async () => {
  const pool = stubPool([[{ id: 4, status: 'accepted', initiated_by: 1 }]]);
  const result = await requestRelationship(pool, {
    initiatorId: 1,
    otherId: 2,
    initiatorIsTrainer: true,
  });

  assert.equal(result.ok, false);
  assert.equal(pool.calls.length, 1, 'no second insert');
});

test('repeating a request is not an error, the invitation still stands', async () => {
  const pool = stubPool([[{ id: 4, status: 'pending', initiated_by: 1 }]]);
  const result = await requestRelationship(pool, {
    initiatorId: 1,
    otherId: 2,
    initiatorIsTrainer: true,
  });

  assert.equal(result.ok, true);
  assert.equal(result.alreadyPending, true);
});

test('accepting requires being the side that did not ask', async () => {
  const pool = stubPool([[{ trainer_id: 1, student_id: 2 }], []]);
  const result = await respondToRequest(pool, { requestId: 7, userId: 2, accept: true });

  assert.equal(result.ok, true);
  const update = pool.calls[0];
  assert.match(update.text, /initiated_by <> \$2/);
  assert.match(update.text, /status = 'pending'/);
  assert.match(update.text, /\$2 IN \(trainer_id, student_id\)/);
});

test('friendship is created only after a request is actually accepted', async () => {
  const pool = stubPool([[{ trainer_id: 1, student_id: 2 }], []]);
  await respondToRequest(pool, { requestId: 7, userId: 2, accept: true });

  assert.equal(pool.calls.length, 2);
  assert.match(pool.calls[1].text, /INSERT INTO friends/);
});

test('a refused acceptance creates no friendship', async () => {
  // No row matched: wrong user, already answered, or the initiator trying to
  // accept their own request.
  const pool = stubPool([[]]);
  const result = await respondToRequest(pool, { requestId: 7, userId: 99, accept: true });

  assert.equal(result.ok, false);
  assert.equal(pool.calls.length, 1, 'stopped before touching friends');
});

test('declining deletes the request under the same guard', async () => {
  const pool = stubPool([[{ trainer_id: 1, student_id: 2 }]]);
  const result = await respondToRequest(pool, { requestId: 7, userId: 2, accept: false });

  assert.equal(result.ok, true);
  assert.match(pool.calls[0].text, /DELETE FROM trainer_students/);
  assert.match(pool.calls[0].text, /initiated_by <> \$2/);
});

test('pending list excludes what I asked for myself', async () => {
  const pool = stubPool([[]]);
  await pendingForUser(pool, 4);

  const sql = pool.calls[0].text;
  assert.match(sql, /initiated_by <> \$1/);
  assert.match(sql, /\$1 IN \(ts\.trainer_id, ts\.student_id\)/);
});
