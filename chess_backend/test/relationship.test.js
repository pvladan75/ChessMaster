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
const fs = require('fs');
const path = require('path');

const { trainerOwnsStudent } = require('../services/assignmentService');
const {
  acceptedTrainersOf,
  requestRelationship,
  respondToRequest,
  pendingForUser,
  notifyAccept,
  notifyDecline,
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
  const pool = stubPool([
    [{ id: 4, trainer_id: 1, student_id: 2, status: 'accepted', initiated_by: 1 }],
  ]);
  const result = await requestRelationship(pool, {
    initiatorId: 1,
    otherId: 2,
    initiatorIsTrainer: true,
  });

  assert.equal(result.ok, false);
  assert.equal(pool.calls.length, 1, 'no second insert');
});

test('the existing-relationship check looks both ways', () => {
  // Not a behaviour test: the reverse row is a different row, and a lookup that
  // only matches one direction cannot see it. That gap is what let two people
  // become each other's trainer.
  const pool = stubPool([[], [{ id: 9 }]]);
  return requestRelationship(pool, { initiatorId: 1, otherId: 2, initiatorIsTrainer: true })
    .then(() => {
      const lookup = pool.calls[0].text;
      assert.match(lookup, /trainer_id = \$1 AND student_id = \$2/);
      assert.match(lookup, /trainer_id = \$2 AND student_id = \$1/);
    });
});

test('you cannot become the trainer of your own trainer', async () => {
  // A teaches B. B now claims to be A's trainer. Refused: a pair where each
  // teaches the other makes every right symmetric — homework, progress and
  // lessons in both directions — and describes nothing that happens in a real
  // lesson.
  const pool = stubPool([
    [{ id: 4, trainer_id: 1, student_id: 2, status: 'accepted', initiated_by: 1 }],
  ]);
  const result = await requestRelationship(pool, {
    initiatorId: 2,
    otherId: 1,
    initiatorIsTrainer: true,
  });

  assert.equal(result.ok, false);
  assert.match(result.reason, /ona je vaš trener/);
  assert.equal(pool.calls.length, 1, 'refused before inserting the mirror row');
});

test('asking to be taught by your own student is refused the same way', async () => {
  // The other phrasing of the same move: A teaches B, and A now asks B to teach
  // them. One relationship, one direction at a time.
  const pool = stubPool([
    [{ id: 4, trainer_id: 1, student_id: 2, status: 'accepted', initiated_by: 1 }],
  ]);
  const result = await requestRelationship(pool, {
    initiatorId: 1,
    otherId: 2,
    initiatorIsTrainer: false,
  });

  assert.equal(result.ok, false);
  assert.match(result.reason, /vi ste njen trener/);
  assert.equal(pool.calls.length, 1);
});

test('an unanswered request in the other direction blocks this one too', async () => {
  const pool = stubPool([
    [{ id: 4, trainer_id: 1, student_id: 2, status: 'pending', initiated_by: 1 }],
  ]);
  const result = await requestRelationship(pool, {
    initiatorId: 2,
    otherId: 1,
    initiatorIsTrainer: true,
  });

  assert.equal(result.ok, false);
  assert.match(result.reason, /suprotnom smeru/);
  assert.equal(pool.calls.length, 1);
});

test('the reverse row does not block once it is gone', async () => {
  // Breaking the relationship must genuinely free both people to start the
  // opposite one — otherwise the refusal above would be a dead end.
  const pool = stubPool([[], [{ id: 11 }]]);
  const result = await requestRelationship(pool, {
    initiatorId: 2,
    otherId: 1,
    initiatorIsTrainer: true,
  });

  assert.equal(result.ok, true);
  assert.deepEqual(pool.calls[1].params, [2, 1, 2], 'trainer, student, initiator');
});

test('repeating a request is not an error, the invitation still stands', async () => {
  const pool = stubPool([
    [{ id: 4, trainer_id: 1, student_id: 2, status: 'pending', initiated_by: 1 }],
  ]);
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

  assert.match(pool.calls[1].text, /INSERT INTO friends/);
});

test('answering a request stops its notification from nagging', async () => {
  // The card on screen is drawn from trainer_students and disappears by itself,
  // but the notification is a separate row: left unread, the bell keeps a
  // permanent count for something already dealt with.
  const pool = stubPool([[{ trainer_id: 1, student_id: 2 }], [], []]);
  await respondToRequest(pool, { requestId: 7, userId: 2, accept: true });

  const closing = pool.calls.at(-1);
  assert.match(closing.text, /UPDATE user_notifications/);
  assert.match(closing.text, /is_read = TRUE/);
  assert.match(closing.text, /kind = 'student_request'/);
  assert.deepEqual(closing.params, [7]);
});

test('declining names the sender so they can be told', async () => {
  // A declined request is deleted, so nothing is left for the sender to see.
  // Silence reads the same as "never sent", and the natural response to that is
  // to send it again.
  const pool = stubPool([[{ trainer_id: 1, student_id: 2 }], []]);
  const result = await respondToRequest(pool, { requestId: 7, userId: 2, accept: false });

  assert.equal(result.senderId, 1, 'the other participant asked; user 2 answered');
});

test('the sender is found from whichever column they sit in', async () => {
  // Either side may start a request, so the sender is not always the trainer.
  const pool = stubPool([[{ trainer_id: 1, student_id: 2 }], []]);
  const result = await respondToRequest(pool, { requestId: 7, userId: 1, accept: false });

  assert.equal(result.senderId, 2);
});

test('accepting names the sender too, so they can be told', async () => {
  // Acceptance used to be the one answer that told nobody: the row changed
  // status and the person waiting was never informed.
  const pool = stubPool([[{ trainer_id: 2, student_id: 1 }], [], []]);
  const result = await respondToRequest(pool, { requestId: 7, userId: 1, accept: true });

  assert.equal(result.ok, true);
  assert.equal(result.senderId, 2, 'the trainer asked, the student answered');
});

test('the accept notice says who accepted', async () => {
  const pool = stubPool([[]]);
  await notifyAccept(pool, { recipientId: 3, accepterId: 4, accepterName: 'pvladan' });

  const sent = pool.calls[0];
  assert.match(sent.text, /INSERT INTO user_notifications/);
  assert.match(sent.text, /'request_accepted'/);
  assert.deepEqual(sent.params.slice(0, 2), [3, 4], 'to the sender, from the accepter');
  assert.equal(sent.params[3], 'pvladan je prihvatio vaš zahtev.');
});

test('a failed accept notice does not undo the acceptance', async () => {
  const pool = {
    async query() {
      throw new Error('database went away');
    },
  };
  await notifyAccept(pool, { recipientId: 3, accepterId: 4, accepterName: 'pvladan' });
});

test('the decline notice says no without saying why', async () => {
  const pool = stubPool([[]]);
  await notifyDecline(pool, { recipientId: 3, declinerId: 4, declinerName: 'pvladan' });

  const sent = pool.calls[0];
  assert.match(sent.text, /INSERT INTO user_notifications/);
  assert.match(sent.text, /'request_declined'/);
  assert.deepEqual(sent.params.slice(0, 2), [3, 4], 'to the sender, from the decliner');
  assert.equal(sent.params[3], 'pvladan nije prihvatio vaš zahtev.');
});

test('a failed decline notice does not undo the decline', async () => {
  // Same rule as every other notification here: the answer already happened.
  const pool = {
    async query() {
      throw new Error('database went away');
    },
  };
  await notifyDecline(pool, { recipientId: 3, declinerId: 4, declinerName: 'pvladan' });
});

test('a declined request closes its notification too', async () => {
  // Worse than stale after a decline: ref_id points at a row that is gone.
  const pool = stubPool([[{ trainer_id: 1, student_id: 2 }], []]);
  await respondToRequest(pool, { requestId: 7, userId: 2, accept: false });

  const closing = pool.calls.at(-1);
  assert.match(closing.text, /UPDATE user_notifications/);
  assert.deepEqual(closing.params, [7]);
});

test('a refused answer leaves the notification alone', async () => {
  // Nothing was answered, so nothing is tidied up — otherwise a stranger
  // guessing request ids could silence someone else's bell.
  const pool = stubPool([[]]);
  await respondToRequest(pool, { requestId: 7, userId: 99, accept: true });

  assert.equal(pool.calls.length, 1);
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

test('reading through the edge also requires acceptance', () => {
  assert.match(acceptedTrainersOf('$1'), /status\s*=\s*'accepted'/);
  assert.match(acceptedTrainersOf('$2'), /student_id\s*=\s*\$2/);
});

test('the fragment refuses anything that is not a placeholder', () => {
  // A call site passing a value instead of a placeholder is interpolating data
  // into SQL. Loud, not lenient.
  assert.throws(() => acceptedTrainersOf('5'), /placeholder/);
  assert.throws(() => acceptedTrainersOf("1 OR 1=1"), /placeholder/);
});

test('no call site reads the edge without filtering on status', () => {
  // Asserted on the source rather than on behaviour, because the bug this
  // catches *is* invisible in behaviour: every screen keeps working, and the
  // only difference is that a request nobody answered already grants access.
  // Three hand-written copies of this subquery all omitted the condition, so
  // what is pinned here is that no fourth copy appears.
  const dirs = ['routes', 'services'].map((d) => path.join(__dirname, '..', d));
  const files = dirs.flatMap((dir) =>
    fs.readdirSync(dir).filter((f) => f.endsWith('.js')).map((f) => path.join(dir, f))
  );

  const offenders = [];
  for (const file of files) {
    const source = fs.readFileSync(file, 'utf8');
    // Each subquery that pulls trainer ids out of the edge table, up to the
    // bracket or template literal that closes it.
    const pattern = /SELECT\s+trainer_id\s+FROM\s+trainer_students[\s\S]{0,240}?(?=\)|`)/g;
    for (const [snippet] of source.matchAll(pattern)) {
      if (!/status/.test(snippet)) {
        offenders.push(`${path.basename(file)}: ${snippet.replace(/\s+/g, ' ').trim()}`);
      }
    }
  }

  assert.deepEqual(offenders, [], 'these read the edge without requiring acceptance');
});

test('pending list excludes what I asked for myself', async () => {
  const pool = stubPool([[]]);
  await pendingForUser(pool, 4);

  const sql = pool.calls[0].text;
  assert.match(sql, /initiated_by <> \$1/);
  assert.match(sql, /\$1 IN \(ts\.trainer_id, ts\.student_id\)/);
});
