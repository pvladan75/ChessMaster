const test = require('node:test');
const assert = require('node:assert/strict');

const {
  logAnswer, practisedSince, MAX_WINDOW_DAYS,
} = require('../services/repertoirePractice');

/// The record of work done, which is not the schedule and must never become it.
///
/// Phase 3 of `docs/PLAN-JEDNOSTAVNOST.md`. The rule being protected here is
/// the one that makes early practice safe to offer at all: an answer given
/// ahead of schedule is judged, counted, and **never** allowed to move a due
/// date. Two piles, one table, and a `scored` column that says which is which.
function stubPool({ rows = [{}], fail = false } = {}) {
  const calls = [];
  return {
    calls,
    ran: (fragment) => calls.filter((c) => c.text.includes(fragment)).length,
    query: async (text, params) => {
      calls.push({ text: text.replace(/\s+/g, ' ').trim(), params });
      if (fail) throw new Error('baza ne odgovara');
      return { rows, rowCount: rows.length };
    },
  };
}

test('an answer is written down with whether it was scored', async () => {
  const pool = stubPool();
  await logAnswer(pool, 7,
    { color: 'b', fenKey: 'k', scored: false, outcome: 'primary' });

  assert.equal(pool.calls.length, 1);
  assert.match(pool.calls[0].text, /INSERT INTO repertoire_practice_log/);
  assert.deepEqual(pool.calls[0].params, [7, 'b', 'k', false, 'primary']);
});

test('a log that cannot be written does not throw', async () => {
  // The oldest rule in this codebase, applied to a write: a record of the
  // action must never be able to take the action down. The caller has already
  // judged and scheduled by the time this runs.
  const pool = stubPool({ fail: true });
  await logAnswer(pool, 7,
    { color: 'b', fenKey: 'k', scored: true, outcome: 'primary' });
  // Reaching here at all is the assertion.
  assert.equal(pool.calls.length, 1);
});

test('an outcome nobody passed is stored as unknown, not as null', async () => {
  const pool = stubPool();
  await logAnswer(pool, 7, { color: 'w', fenKey: 'k', scored: true });
  assert.equal(pool.calls[0].params[4], 'unknown');
});

test('the day counted is the one the caller names', async () => {
  const pool = stubPool({
    rows: [{ positions: 12, answers: 19, scored: 7, practice: 12 }],
  });
  const since = new Date(Date.now() - 3 * 60 * 60 * 1000).toISOString();

  const out = await practisedSince(pool, 7, { since, color: 'w' });

  assert.equal(out.positions, 12);
  assert.equal(out.answers, 19);
  // The two kinds stay apart. Adding them into one number would say the early
  // practice counted for repetition, which is exactly what it does not do.
  assert.equal(out.scored, 7);
  assert.equal(out.practice, 12);
  assert.equal(pool.calls[0].params[1], new Date(since).toISOString());
  assert.equal(pool.calls[0].params[2], 'w');
});

test('both colours at once when no colour is given', async () => {
  const pool = stubPool({
    rows: [{ positions: 3, answers: 3, scored: 3, practice: 0 }],
  });
  await practisedSince(pool, 7, { since: new Date().toISOString() });
  assert.equal(pool.calls[0].params[2], null);
});

test('a broken date is refused rather than counted as the epoch', async () => {
  const pool = stubPool();
  await assert.rejects(
    () => practisedSince(pool, 7, { since: 'juče' }),
    RangeError,
  );
  assert.equal(pool.calls.length, 0);
});

test('a window nobody could mean is refused', async () => {
  // A clock a year out, or a hand-written query, would otherwise scan the whole
  // table to answer a question about today.
  const pool = stubPool();
  const old = new Date(
    Date.now() - (MAX_WINDOW_DAYS + 1) * 24 * 60 * 60 * 1000,
  ).toISOString();

  await assert.rejects(() => practisedSince(pool, 7, { since: old }), RangeError);
  assert.equal(pool.calls.length, 0);
});

test('a colour this server does not know is refused', async () => {
  const pool = stubPool();
  await assert.rejects(
    () => practisedSince(pool, 7,
      { since: new Date().toISOString(), color: 'white' }),
    RangeError,
  );
  assert.equal(pool.calls.length, 0);
});

test('an empty table reads as nothing done, not as a missing answer',
  async () => {
    const pool = stubPool({ rows: [] });
    const out = await practisedSince(pool, 7,
      { since: new Date().toISOString() });

    assert.equal(out.positions, 0);
    assert.equal(out.answers, 0);
  });
