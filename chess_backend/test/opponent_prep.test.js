// opponent_prep.test.js — the query that goes on the wire, and the policy in front of it.
//
// Two separate risks. The query builder's is that every one of its parameters
// is a way to get a *smaller* answer than you asked for, silently: Lichess
// ignores a misspelled `perfType` rather than refusing it, so a typo widens the
// pull to every format and looks identical to a correct request.
//
// The policy's is the opposite — that it opens. This is the one feature in the
// project that reads about a person who never opened the app, and most accounts
// here belong to children, so the tests that matter are the ones asserting it
// stays shut.

const test = require('node:test');
const assert = require('node:assert/strict');

const { buildArchiveQuery } = require('../services/gameArchiveImport');
const { createOpponentPrep, OpponentPrepUnavailable, policyFrom } = require('../services/opponentPrep');

const ON = { OPPONENT_PREP_ENABLED: 'true' };

function q(filters, since = null) {
  return Object.fromEntries(buildArchiveQuery({ since, filters }));
}

function refusal(fn) {
  return fn().then(
    () => { throw new Error('expected a refusal, got none'); },
    (err) => {
      assert.ok(err instanceof OpponentPrepUnavailable, `wrong error: ${err.message}`);
      return err;
    },
  );
}

// --- the query -------------------------------------------------------------

test('the openings tags are always asked for', () => {
  // Lichess computes [ECO] and [Opening] when asked, which costs nothing and
  // spares a local ECO database. It is not a filter and is never optional.
  assert.equal(q({}).opening, 'true');
});

test('head to head is one parameter, not a second pull', () => {
  assert.equal(q({ vs: 'rival' }).vs, 'rival');
  assert.equal(q({}).vs, undefined, 'and it is absent when nobody asked');
});

test('colour is translated into the word Lichess wants', () => {
  // The rest of this codebase says 'w' and 'b'; Lichess wants the words. A
  // request carrying 'w' is not refused by Lichess, it is ignored — which
  // returns both colours and looks exactly like a correct answer.
  assert.equal(q({ color: 'w' }).color, 'white');
  assert.equal(q({ color: 'b' }).color, 'black');
  assert.equal(q({ color: 'black' }).color, 'black');
});

test('a colour nobody plays is refused rather than dropped', () => {
  assert.throws(() => q({ color: 'green' }), /Boja/);
});

test('an unknown format is refused rather than ignored', () => {
  // The specific hazard: Lichess ignores an unrecognised perfType, so this
  // typo would quietly return every format at every time control.
  assert.throws(() => q({ perfType: 'bliz' }), /Nepoznat tempo/);
  assert.equal(q({ perfType: 'blitz,rapid' }).perfType, 'blitz,rapid');
});

test('rated must be a boolean, because a string is always truthy', () => {
  assert.throws(() => q({ rated: 'false' }), /rated/);
  assert.equal(q({ rated: false }).rated, 'false');
  assert.equal(q({ rated: true }).rated, 'true');
});

test('max is bounded at both ends', () => {
  assert.throws(() => q({ max: 0 }));
  assert.throws(() => q({ max: 20001 }));
  assert.throws(() => q({ max: 2.5 }));
  assert.equal(q({ max: 200 }).max, '200');
});

test('since is sent as epoch milliseconds', () => {
  const when = new Date('2025-01-01T00:00:00.000Z');
  assert.equal(q({}, when).since, String(when.getTime()));
});

// --- the policy ------------------------------------------------------------

test('the feature is off unless somebody turned it on', () => {
  // The default is the decision this file is waiting for. Absent configuration
  // means off, not open.
  assert.equal(policyFrom({}).enabled, false);
  assert.equal(policyFrom({ OPPONENT_PREP_ENABLED: 'yes' }).enabled, false);
  assert.equal(policyFrom({ OPPONENT_PREP_ENABLED: 'true' }).enabled, true);
});

test('being off is a refusal by name, not an empty report', () => {
  // An empty report reads as "this opponent has no weaknesses", which is the
  // one answer a disabled feature must never give.
  const prep = createOpponentPrep({ pool: stubPool(), importer: stubImporter(), env: {} });

  return refusal(() => prep.prepare({ userId: 1, subject: 'rival' }))
    .then((err) => {
      assert.equal(err.reason, 'disabled');
      assert.equal(err.status, 403);
    });
});

test('nothing is fetched while the feature is off', async () => {
  // The refusal has to come before the request, or being "off" still means
  // holding the archive.
  const importer = stubImporter();
  const prep = createOpponentPrep({ pool: stubPool(), importer, env: {} });

  await refusal(() => prep.prepare({ userId: 1, subject: 'rival' }));
  assert.equal(importer.started.length, 0);
});

test('an opponent pull is marked as not the player\'s own', async () => {
  const importer = stubImporter();
  const prep = createOpponentPrep({ pool: stubPool(), importer, env: ON });

  await prep.prepare({ userId: 1, subject: 'rival', filters: { vs: 'me', color: 'w' } });

  assert.equal(importer.started.length, 1);
  const [call] = importer.started;
  assert.equal(call.subjectIsOwner, false, 'the whole difference from an own-archive import');
  assert.equal(call.incremental, false, 'a preparation pull is a fresh question, not a resume');
  assert.deepEqual(call.filters, { vs: 'me', color: 'w' });
});

test('one account cannot pull an unlimited number of people', async () => {
  const prep = createOpponentPrep({
    pool: stubPool({ subjectsToday: 3 }),
    importer: stubImporter(),
    env: { ...ON, OPPONENT_PREP_MAX_SUBJECTS_PER_DAY: '3' },
  });

  const err = await refusal(() => prep.prepare({ userId: 1, subject: 'rival' }));
  assert.equal(err.reason, 'too-many-subjects');
});

test('a rating floor refuses below it and allows above', async () => {
  const env = { ...ON, OPPONENT_PREP_MIN_RATING: '1800' };
  const importer = stubImporter();

  const weak = createOpponentPrep({
    pool: stubPool(), importer, env, ratingOf: async () => 1400,
  });
  const err = await refusal(() => weak.prepare({ userId: 1, subject: 'rival' }));
  assert.equal(err.reason, 'below-rating-floor');
  assert.equal(importer.started.length, 0, 'and nothing was fetched');

  const strong = createOpponentPrep({
    pool: stubPool(), importer, env, ratingOf: async () => 2100,
  });
  await strong.prepare({ userId: 1, subject: 'rival' });
  assert.equal(importer.started.length, 1);
});

test('the refusal does not report the person\'s rating back', async () => {
  // Telling whoever asked about a named player what that player's rating is is
  // the smaller half of the problem the floor exists for.
  const prep = createOpponentPrep({
    pool: stubPool(),
    importer: stubImporter(),
    env: { ...ON, OPPONENT_PREP_MIN_RATING: '1800' },
    ratingOf: async () => 1437,
  });

  const err = await refusal(() => prep.prepare({ userId: 1, subject: 'rival' }));
  assert.equal(/1437/.test(err.message), false, err.message);
  assert.equal(/1800/.test(err.message), true, 'the floor may be named; the person may not');
});

test('a rating that cannot be checked refuses rather than waves through', async () => {
  // A floor that opens itself whenever the lookup fails is not a floor.
  const prep = createOpponentPrep({
    pool: stubPool(),
    importer: stubImporter(),
    env: { ...ON, OPPONENT_PREP_MIN_RATING: '1800' },
    ratingOf: async () => null,
  });

  const err = await refusal(() => prep.prepare({ userId: 1, subject: 'rival' }));
  assert.equal(err.reason, 'no-rating');
});

test('retention deletes opponents and can never touch the player\'s own games', async () => {
  const pool = stubPool();
  const prep = createOpponentPrep({
    pool, importer: stubImporter(), env: { ...ON, OPPONENT_PREP_RETENTION_DAYS: '30' },
  });

  await prep.forgetOldOpponents();

  const [deletion] = pool.calls.filter((c) => /DELETE FROM user_games/.test(c.text));
  assert.ok(deletion, 'a deletion was issued');
  assert.match(
    deletion.text, /subject_is_owner = FALSE/,
    'the player\'s own archive is the one thing here that cannot be re-fetched',
  );
});

test('retention off means nothing is deleted at all', async () => {
  const pool = stubPool();
  const prep = createOpponentPrep({
    pool, importer: stubImporter(), env: { ...ON, OPPONENT_PREP_RETENTION_DAYS: '0' },
  });

  const result = await prep.forgetOldOpponents();
  assert.equal(result.deleted, 0);
  assert.equal(
    pool.calls.filter((c) => /DELETE/.test(c.text)).length, 0,
    'a zero window is "keep", not "delete everything"',
  );
});

// --- stubs -----------------------------------------------------------------

function stubPool({ subjectsToday = 0 } = {}) {
  const calls = [];
  return {
    calls,
    query: async (text, params = []) => {
      const flat = text.replace(/\s+/g, ' ').trim();
      calls.push({ text: flat, params });
      if (/COUNT\(DISTINCT i\.subject\)/.test(flat)) {
        return { rows: [{ subjects: subjectsToday }], rowCount: 1 };
      }
      if (/DELETE FROM user_games/.test(flat)) return { rows: [], rowCount: 4 };
      return { rows: [], rowCount: 0 };
    },
  };
}

function stubImporter() {
  const started = [];
  return {
    started,
    start: async (options) => {
      started.push(options);
      return { importId: '1', finished: Promise.resolve() };
    },
  };
}
