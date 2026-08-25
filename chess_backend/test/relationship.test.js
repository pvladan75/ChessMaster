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

const realtime = require('../services/realtime');
const { trainerOwnsStudent } = require('../services/assignmentService');
const {
  acceptedTrainersOf,
  setVoiceLevel,
  requestRelationship,
  respondToRequest,
  pendingForUser,
  notifyAccept,
  notifyDecline,
} = require('../services/relationshipService');

/// Every notification nudges its recipient, and doing that without a server is
/// a wiring mistake loud enough to throw. Nobody is registered as online here,
/// so nothing is actually sent — this only satisfies that check.
realtime.init({ to: () => ({ emit: () => {} }) });

/// Captures queries and replays canned rows, one result per call in order.
///
/// One question is answered by *who is being asked about* rather than by its
/// place in the queue: how old somebody says they are. It is asked from a
/// different service, at a point that moves as the flow changes, and threading
/// it through the positional queue would mean every test here carrying a row
/// about a rule it is not testing. `ages` is empty by default, which is the
/// state every account is in today — nobody has ever been asked.
function stubPool(results = [[]], { ages = {} } = {}) {
  const calls = [];
  let index = 0;
  return {
    calls,
    async query(text, params) {
      calls.push({ text, params });
      if (/birth_year/.test(text)) {
        const year = ages[params[0]];
        return {
          rows: [{ birth_year: year === undefined ? null : year }],
          rowCount: 1,
        };
      }
      const rows = results[Math.min(index, results.length - 1)];
      index++;
      return { rows, rowCount: rows.length };
    },
  };
}

/// The statement a test is about, found by what it says rather than by how many
/// came before it. Counting queries makes a test fail the day a rule is added
/// next to the one it pins, which is a fail for the wrong reason.
function stmt(pool, pattern) {
  const found = pool.calls.find((call) => pattern.test(call.text));
  assert.ok(found, `nema upita koji odgovara ${pattern}`);
  return found;
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
  const insert = stmt(pool, /INSERT INTO trainer_students/);
  assert.match(insert.text, /'pending'/);
  assert.deepEqual(insert.params, [1, 2, 1, 'talk'],
    'trainer, student, initiator, glas');
});

test('a student asking a trainer lands in the other column', async () => {
  const pool = stubPool([[], [{ id: 8 }]]);
  await requestRelationship(pool, { initiatorId: 5, otherId: 9, initiatorIsTrainer: false });

  // trainer_id is the other party, student_id is the initiator, and the
  // initiator is still recorded as the one who started it.
  assert.deepEqual(
    stmt(pool, /INSERT INTO trainer_students/).params, [9, 5, 5, 'talk']);
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
  assert.equal(pool.calls.filter((c) => /INSERT/.test(c.text)).length, 0,
    'no second insert');
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
  assert.deepEqual(stmt(pool, /INSERT INTO trainer_students/).params,
    [2, 1, 2, 'talk'], 'trainer, student, initiator, glas');
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

const thisYear = new Date().getFullYear();
const bornAgo = (years) => thisYear - years - 1;

test('a minor cannot be enrolled as anybody’s trainer', async () => {
  // The rule that keeps this from being a place where children connect to each
  // other. It is refused where the row would have been written, so nothing is
  // created and the person who asked is told why.
  const pool = stubPool([[], [{ id: 7 }]], { ages: { 1: bornAgo(12) } });

  const result = await requestRelationship(pool, {
    initiatorId: 1,
    otherId: 2,
    initiatorIsTrainer: true,
  });

  assert.equal(result.ok, false);
  assert.match(result.reason, /Maloletnik/);
  assert.ok(!pool.calls.some((c) => /INSERT INTO trainer_students/.test(c.text)),
    'nijedan red nije upisan');
});

test('a child asking an adult to teach them is the ordinary case', async () => {
  const pool = stubPool([[], [{ id: 7 }]], { ages: { 1: bornAgo(9) } });

  const result = await requestRelationship(pool, {
    initiatorId: 1,
    otherId: 2,
    initiatorIsTrainer: false,
  });

  assert.equal(result.ok, true);
  // And the child starts by listening: they hear the trainer and answer on the
  // board, and their voice is never published — so it is never in the recording
  // either. Talking is granted afterwards, by the trainer, when there is a
  // reason to.
  assert.deepEqual(stmt(pool, /INSERT INTO trainer_students/).params,
    [2, 1, 1, 'listen'], 'trainer, student, initiator, glas');
});

test('a request from before the age was known is checked again on the answer',
  async () => {
    // Every request that exists today was made while nobody had stated an age
    // at all. Asking only at the sending end would let all of those become
    // relationships the moment the other side tapped "prihvati".
    const pool = stubPool([
      [{ trainer_id: 1, student_id: 2 }],
      [{ trainer_id: 1, student_id: 2 }],
      [],
    ], { ages: { 1: bornAgo(13) } });

    const result = await respondToRequest(pool,
      { requestId: 7, userId: 2, accept: true });

    assert.equal(result.ok, false);
    assert.match(result.reason, /Maloletnik/);
    assert.ok(!pool.calls.some((c) => /UPDATE trainer_students/.test(c.text)),
      'veza nije prihvaćena');
    assert.ok(!pool.calls.some((c) => /INSERT INTO friends/.test(c.text)));
  });

test('accepting requires being the side that did not ask', async () => {
  // Two answers now: the row is read first (to ask how old the trainer says
  // they are), and then written under the guard that is the point of this test.
  const pool = stubPool([
    [{ trainer_id: 1, student_id: 2 }],
    [{ trainer_id: 1, student_id: 2 }],
    [],
  ]);
  const result = await respondToRequest(pool, { requestId: 7, userId: 2, accept: true });

  assert.equal(result.ok, true);
  const update = stmt(pool, /UPDATE trainer_students/);
  assert.match(update.text, /initiated_by <> \$2/);
  assert.match(update.text, /status = 'pending'/);
  assert.match(update.text, /\$2 IN \(trainer_id, student_id\)/);
});

test('friendship is created only after a request is actually accepted', async () => {
  const pool = stubPool([
    [{ trainer_id: 1, student_id: 2 }],
    [{ trainer_id: 1, student_id: 2 }],
    [],
  ]);
  await respondToRequest(pool, { requestId: 7, userId: 2, accept: true });

  assert.ok(stmt(pool, /INSERT INTO friends/));
});

test('answering a request stops its notification from nagging', async () => {
  // The card on screen is drawn from trainer_students and disappears by itself,
  // but the notification is a separate row: left unread, the bell keeps a
  // permanent count for something already dealt with.
  const pool = stubPool([
    [{ trainer_id: 1, student_id: 2 }],
    [{ trainer_id: 1, student_id: 2 }],
    [],
    [],
  ]);
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
  const pool = stubPool([
    [{ trainer_id: 2, student_id: 1 }],
    [{ trainer_id: 2, student_id: 1 }],
    [],
    [],
  ]);
  const result = await respondToRequest(pool, { requestId: 7, userId: 1, accept: true });

  assert.equal(result.ok, true);
  assert.equal(result.senderId, 2, 'the trainer asked, the student answered');
});

test('the accept notice says who accepted', async () => {
  const pool = stubPool([[]]);
  await notifyAccept(pool, { recipientId: 3, accepterId: 4, accepterName: 'pvladan' });

  const sent = pool.calls[0];
  assert.match(sent.text, /INSERT INTO user_notifications/);
  assert.deepEqual(sent.params.slice(0, 2), [3, 4], 'to the sender, from the accepter');
  assert.equal(sent.params[4], 'pvladan je prihvatio vaš zahtev.');
  assert.equal(sent.params[5], 'request_accepted');
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
  assert.deepEqual(sent.params.slice(0, 2), [3, 4], 'to the sender, from the decliner');
  assert.equal(sent.params[4], 'pvladan nije prihvatio vaš zahtev.');
  assert.equal(sent.params[5], 'request_declined');
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

  assert.ok(!pool.calls.some((c) => /UPDATE user_notifications/.test(c.text)));
});

test('a refused acceptance creates no friendship', async () => {
  // No row matched: wrong user, already answered, or the initiator trying to
  // accept their own request.
  const pool = stubPool([[]]);
  const result = await respondToRequest(pool, { requestId: 7, userId: 99, accept: true });

  assert.equal(result.ok, false);
  assert.ok(!pool.calls.some((c) => /INSERT INTO friends/.test(c.text)),
    'stopped before touching friends');
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


test('the badge counts a waiting request even after it has been read about', () => {
  // Reading the bell marks notifications read, and that must not quietly answer
  // a request. What is still waiting comes from `/relationships/pending`, never
  // from whether its notification was read — which is what makes marking
  // everything read safe.
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'routes', 'social.js'),
    'utf8'
  );

  const route = source.slice(source.indexOf("router.post('/notifications/read'"));
  const body = route.slice(0, route.indexOf('});'));

  assert.match(body, /UPDATE user_notifications/);
  assert.match(body, /user_id = \$1/, 'only the caller own rows');
  assert.doesNotMatch(body, /trainer_students/, 'it must not touch requests');
});

test('a friendship has exactly one origin, and it is consent', () => {
  // `POST /friends/add` took an email and wrote the connection **both ways with
  // nobody's consent**, so whoever knew a child's address could put themselves
  // on that child's list. It was removed on 25.8.2026 rather than given a
  // request flow, because no screen in the app had ever called it.
  //
  // Asserted on the source because the failure is invisible in behaviour: every
  // screen keeps working, and the only difference is that there is a second way
  // into a child's list of people, one that skips the asking. That is the same
  // reason `acceptedTrainersOf` is pinned this way.
  const root = path.join(__dirname, '..');
  const written = [];

  for (const dir of ['routes', 'services']) {
    for (const name of fs.readdirSync(path.join(root, dir))) {
      if (!name.endsWith('.js')) continue;
      const source = fs.readFileSync(path.join(root, dir, name), 'utf8')
        // Comments first: the note explaining why the route is gone names the
        // very thing it says no longer happens.
        .replace(/^\s*\/\/.*$/gm, '');
      if (/INSERT\s+INTO\s+friends/i.test(source)) written.push(`${dir}/${name}`);
      if (/friends\/add/.test(source)) written.push(`${dir}/${name} (ruta)`);
    }
  }

  // Two files, because there are now two doors into `accepted` and both of them
  // are consent: an adult student answering for themselves, and a parent
  // answering for a child. `parentConsentService` writes it inside the same
  // transaction that records the consent, which is the point — a friendship
  // that appeared before the parent answered, or an accepted relationship with
  // no friendship behind it, would both be halves of a record.
  //
  // A third file is still a failure, and that is what this test is for.
  assert.deepEqual(written, [
    'services/parentConsentService.js',
    'services/relationshipService.js',
  ], 'prijateljstvo se pravi negde osim iz prihvaćene veze');
});

test('the microphone is granted by the trainer, and only to their own student',
  async () => {
    // A right, not a request: the same row is read again every time a voice
    // token is minted, so taking it back holds even against a client that would
    // rather not notice.
    const granted = stubPool([[{ voice_level: 'talk' }]]);
    const ok = await setVoiceLevel(granted,
      { trainerId: 1, studentId: 2, level: 'talk' });

    assert.deepEqual(ok, { ok: true, level: 'talk' });
    const update = stmt(granted, /UPDATE trainer_students/);
    assert.match(update.text, /status = 'accepted'/,
      'glas se daje samo u prihvaćenoj vezi');
    assert.match(update.text, /RETURNING voice_level/,
      'odgovor se čita iz reda, ne iz zahteva');

    // Somebody else's student, or a request nobody has answered yet.
    const notMine = stubPool([[]]);
    const refused = await setVoiceLevel(notMine,
      { trainerId: 1, studentId: 99, level: 'talk' });
    assert.equal(refused.ok, false);

    // And nothing else is a level. An unknown value must not fall through to
    // the permissive one.
    const nonsense = stubPool([[{ voice_level: 'talk' }]]);
    assert.equal(
      (await setVoiceLevel(nonsense, { trainerId: 1, studentId: 2, level: 'sve' })).ok,
      false);
    assert.equal(nonsense.calls.length, 0, 'baza se ne dira zbog besmislice');
  });
