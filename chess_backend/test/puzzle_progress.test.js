// puzzle_progress.test.js — the three states are derived from the first and the
// latest row, and nothing else. docs/PLAN-NAPREDAK-VEZBI.md, phase 0.
//
// Mutations tried when written (17.9.2026), each caught by the test named:
//   - latest picked by `<` instead of `>=`      → "the latest row wins"
//   - firstTry ignoring `hinted`                 → "a hinted solve is not first try"
//   - skipped counted as failed                  → "a skip is not a failure"
//   - retryIds sorted newest first               → "oldest failure first"
//   - SQL without ORDER BY / with wrong param    → "asks the database for ..."

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  SOURCES, isKnownSource, foldAttempts, retryIds, progressOf, retryIdsOf,
} = require('../services/puzzleProgress');

let clock = 0;
function row(over = {}) {
  clock += 1000;
  return {
    puzzle_id: 'p1', source: 'lichess', solved: true, skipped: false,
    hinted: false, created_at: new Date(1_700_000_000_000 + clock).toISOString(),
    ...over,
  };
}

// Six until 23.9.2026; `own` joined with docs/PLAN-MATERIJAL.md phase 1 — one's
// own exercise solved alone, written only by POST /exercises/:id/attempt
// (test/exercise_solo.test.js).
test('the seven sources are frozen and named', () => {
  assert.deepEqual([...SOURCES], [
    'lichess', 'mate_puzzle', 'winning_position', 'endgame', 'blunder_game', 'basic_mate', 'own',
  ]);
  assert.ok(Object.isFrozen(SOURCES));
  assert.equal(isKnownSource('endgame'), true);
  assert.equal(isKnownSource('tactics'), false);
});

test('a source with nothing seen is absent, not zero', () => {
  assert.deepEqual(foldAttempts([]), {});
  const out = foldAttempts([row({ source: 'endgame' })]);
  assert.deepEqual(Object.keys(out), ['endgame']);
});

test('solved on the first try, and solved later, are told apart', () => {
  const out = foldAttempts([
    row({ puzzle_id: 'a', solved: true }),                       // first try
    row({ puzzle_id: 'b', solved: false }),
    row({ puzzle_id: 'b', solved: true }),                       // solved later
  ]);
  assert.deepEqual(out.lichess, {
    seen: 2, solved: 2, firstTry: 1, failed: 0, skipped: 0, toRetry: 0,
  });
});

test('the latest row wins, whatever order the rows arrive in', () => {
  const failedThenSolved = [row({ puzzle_id: 'a', solved: false }), row({ puzzle_id: 'a', solved: true })];
  const solvedThenFailed = [row({ puzzle_id: 'b', solved: true }), row({ puzzle_id: 'b', solved: false })];
  const out = foldAttempts([...failedThenSolved.reverse(), ...solvedThenFailed.reverse()]);
  assert.equal(out.lichess.toRetry, 1, 'b is to retry, a is not');
  assert.equal(out.lichess.firstTry, 1, 'b was first-try, a was not');
  assert.equal(out.lichess.solved, 1);
  assert.equal(out.lichess.failed, 1);
});

test('a hinted solve is not first try', () => {
  const out = foldAttempts([row({ puzzle_id: 'a', hinted: true })]);
  assert.equal(out.lichess.solved, 1);
  assert.equal(out.lichess.firstTry, 0);
});

test('a skip is not a failure, but it is to retry', () => {
  const out = foldAttempts([
    row({ puzzle_id: 'a', solved: false, skipped: true }),
    row({ puzzle_id: 'b', solved: false }),
  ]);
  assert.deepEqual(out.lichess, {
    seen: 2, solved: 0, firstTry: 0, failed: 1, skipped: 1, toRetry: 2,
  });
});

test('sources do not mix, and an unknown source is dropped', () => {
  const out = foldAttempts([
    row({ puzzle_id: 'x', source: 'mate_puzzle' }),
    row({ puzzle_id: 'x', source: 'endgame', solved: false }),
    row({ puzzle_id: 'x', source: 'tactics' }),
  ]);
  assert.deepEqual(Object.keys(out).sort(), ['endgame', 'mate_puzzle']);
  assert.equal(out.mate_puzzle.solved, 1);
  assert.equal(out.endgame.toRetry, 1);
});

test('a bucket is tallied inside its source', () => {
  const out = foldAttempts([
    row({ puzzle_id: 'a', source: 'mate_puzzle', bucket: 2 }),
    row({ puzzle_id: 'b', source: 'mate_puzzle', bucket: 2, solved: false }),
    row({ puzzle_id: 'c', source: 'mate_puzzle', bucket: 3 }),
  ]);
  assert.equal(out.mate_puzzle.seen, 3);
  assert.deepEqual(out.mate_puzzle.buckets['2'], {
    seen: 2, solved: 1, firstTry: 1, failed: 1, skipped: 0, toRetry: 1,
  });
  assert.equal(out.mate_puzzle.buckets['3'].seen, 1);
});

test('retry ids: the unsolved of one source, oldest failure first', () => {
  const rows = [
    row({ puzzle_id: 'late', solved: false }),
    row({ puzzle_id: 'early', solved: false }),
    row({ puzzle_id: 'fixed', solved: false }),
    row({ puzzle_id: 'fixed', solved: true }),
    row({ puzzle_id: 'other', source: 'endgame', solved: false }),
    row({ puzzle_id: 'skipped', solved: false, skipped: true }),
  ];
  // `late` failed first in time, so it is first in the queue.
  assert.deepEqual(retryIds(rows, 'lichess'), ['late', 'early', 'skipped']);
  assert.deepEqual(retryIds(rows, 'endgame'), ['other']);
  assert.throws(() => retryIds(rows, 'tactics'), RangeError);
});

/// Answers by reading the statement; keeps what it was asked.
function stubPool(rows = []) {
  const calls = [];
  return {
    calls,
    async query(text, params = []) {
      calls.push({ text: text.replace(/\s+/g, ' ').trim(), params });
      return { rows, rowCount: rows.length };
    },
  };
}

test('asks the database for one user, ordered by time', async () => {
  const pool = stubPool([row({ puzzle_id: 'a', solved: false })]);
  const out = await progressOf(pool, 42);
  assert.equal(pool.calls.length, 1);
  const { text, params } = pool.calls[0];
  assert.match(text, /FROM user_puzzle_attempts a/);
  assert.match(text, /WHERE a\.user_id = \$1 ORDER BY a\.created_at ASC/);
  assert.match(text, /a\.puzzle_id, a\.source, a\.solved, a\.skipped, a\.hinted, a\.created_at/);
  // The finer group comes from the puzzle's own row: a mate's depth, an
  // endgame's mode.
  assert.match(text, /LEFT JOIN puzzles p ON a\.source IN \('mate_puzzle', 'winning_position'\)/);
  assert.match(text, /LEFT JOIN endgame_puzzles e ON a\.source = 'endgame'/);
  assert.match(text, /COALESCE\(p\.mate_depth::text, e\.mode\) AS bucket/);
  assert.deepEqual(params, [42]);
  assert.equal(out.lichess.toRetry, 1);
});

test('retryIdsOf reads the same log with the same query', async () => {
  const pool = stubPool([row({ puzzle_id: 'a', solved: false })]);
  assert.deepEqual(await retryIdsOf(pool, 7, 'lichess'), ['a']);
  assert.deepEqual(pool.calls[0].params, [7]);
  assert.match(pool.calls[0].text, /ORDER BY a\.created_at ASC/);
});
