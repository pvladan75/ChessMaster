// assignment.test.js
// Covers the progress arithmetic and the puzzle-selection filters behind
// homework — the numbers a trainer repeats to a parent, and the query that
// decides what a child is asked to do.

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  summariseAttempts,
  resolvePuzzles,
  recordPuzzleResult,
  MAX_ITEMS,
  DEFAULT_ITEMS,
} = require('../services/assignmentService');

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

function attempt(solved, themes) {
  return { solved, themes, puzzle_rating: 1500, created_at: '2026-08-15T10:00:00Z' };
}

test('accuracy is computed over all attempts', () => {
  const summary = summariseAttempts([
    attempt(true, ['fork']),
    attempt(true, ['fork']),
    attempt(false, ['pin']),
    attempt(false, ['pin']),
  ]);

  assert.equal(summary.totalAttempts, 4);
  assert.equal(summary.solvedAttempts, 2);
  assert.equal(summary.accuracy, 50);
});

test('a student with no attempts reports null accuracy, not zero', () => {
  const summary = summariseAttempts([]);

  // Zero would read as "gets everything wrong"; null reads as "no data", which
  // is the truth and the only honest thing to show a parent.
  assert.equal(summary.accuracy, null);
  assert.equal(summary.totalAttempts, 0);
  assert.deepEqual(summary.weakestThemes, []);
});

test('a theme needs enough attempts before it counts as a weakness', () => {
  const rows = [
    // pin: one attempt, failed — 0% but meaningless.
    attempt(false, ['pin']),
    // fork: five attempts, two solved — 40% and real.
    attempt(true, ['fork']),
    attempt(true, ['fork']),
    attempt(false, ['fork']),
    attempt(false, ['fork']),
    attempt(false, ['fork']),
  ];

  const summary = summariseAttempts(rows, { minAttemptsPerTheme: 4 });

  assert.deepEqual(
    summary.weakestThemes.map((entry) => entry.theme),
    ['fork'],
    'a single failed puzzle must not brand a motif as the student\'s weakness'
  );
  assert.equal(summary.weakestThemes[0].accuracy, 40);
});

test('weakest and strongest are ordered from the same measured set', () => {
  const rows = [];
  for (let i = 0; i < 5; i++) rows.push(attempt(true, ['fork']));
  for (let i = 0; i < 5; i++) rows.push(attempt(false, ['pin']));
  for (let i = 0; i < 5; i++) rows.push(attempt(i < 3, ['skewer']));

  const summary = summariseAttempts(rows);

  assert.equal(summary.weakestThemes[0].theme, 'pin');
  assert.equal(summary.weakestThemes[0].accuracy, 0);
  assert.equal(summary.strongestThemes[0].theme, 'fork');
  assert.equal(summary.strongestThemes[0].accuracy, 100);
});

test('a puzzle tagged with several motifs counts towards each', () => {
  const summary = summariseAttempts([
    attempt(true, ['fork', 'hangingPiece']),
    attempt(false, ['fork', 'pin']),
  ]);

  const byTheme = Object.fromEntries(summary.themes.map((entry) => [entry.theme, entry]));
  assert.equal(byTheme.fork.attempts, 2);
  assert.equal(byTheme.hangingPiece.attempts, 1);
  assert.equal(byTheme.pin.attempts, 1);
});

test('attempts without themes do not break the summary', () => {
  const summary = summariseAttempts([
    { solved: true, themes: null },
    { solved: false },
  ]);

  assert.equal(summary.totalAttempts, 2);
  assert.equal(summary.accuracy, 50);
  assert.deepEqual(summary.themes, []);
});

test('assigned puzzles exclude ones the student already attempted', async () => {
  const pool = stubPool([[{ puzzle_id: 'a', rating: 1400 }]]);
  await resolvePuzzles(pool, { studentId: 7, themes: ['fork'], count: 5 });

  const sql = pool.calls[0].text;
  // Re-issuing a solved puzzle measures recall, not skill.
  assert.match(sql, /NOT EXISTS/);
  assert.match(sql, /user_puzzle_attempts/);
});

test('several chosen themes mean "any of", not "all of"', async () => {
  const pool = stubPool([[{ puzzle_id: 'a', rating: 1400 }]]);
  await resolvePuzzles(pool, { studentId: 7, themes: ['fork', 'pin'], count: 5 });

  // Containment (@>) would demand both motifs on one puzzle and usually return
  // nothing; overlap (&&) is what ticking two boxes means.
  assert.match(pool.calls[0].text, /themes && \$/);
  assert.ok(pool.calls[0].params.some((p) => Array.isArray(p) && p.includes('fork')));
});

test('non-trainable themes are dropped from the filter', async () => {
  const pool = stubPool([[{ puzzle_id: 'a', rating: 1400 }]]);
  await resolvePuzzles(pool, { studentId: 7, themes: ['crushing', 'long'], count: 5 });

  // "crushing" and "long" describe the puzzle, not a skill, and filtering on
  // them would produce a set that trains nothing in particular.
  assert.ok(!pool.calls[0].text.includes('themes &&'));
});

test('an empty first result falls back rather than assigning nothing', async () => {
  const pool = stubPool([[], [{ puzzle_id: 'b', rating: 1500 }]]);
  const rows = await resolvePuzzles(pool, { studentId: 7, count: 5 });

  assert.equal(pool.calls.length, 2, 'must retry without the unseen constraint');
  assert.equal(rows.length, 1);
});

test('the item count is clamped to a sane range', async () => {
  const pool = stubPool([[{ puzzle_id: 'a', rating: 1400 }]]);

  await resolvePuzzles(pool, { studentId: 7, count: 9999 });
  assert.equal(pool.calls[0].params.at(-1), MAX_ITEMS, 'a typo must not materialise thousands of rows');

  await resolvePuzzles(pool, { studentId: 7, count: 0 });
  assert.equal(pool.calls[1].params.at(-1), DEFAULT_ITEMS);

  await resolvePuzzles(pool, { studentId: 7, count: -5 });
  assert.equal(pool.calls[2].params.at(-1), 1);
});

test('a missing rating range widens to the whole dataset', async () => {
  const pool = stubPool([[{ puzzle_id: 'a', rating: 1400 }]]);
  await resolvePuzzles(pool, { studentId: 7, count: 5 });

  assert.equal(pool.calls[0].params[0], 400);
  assert.equal(pool.calls[0].params[1], 3200);
});


// The move the student played is the part that cannot be recovered later. A
// wrong answer one square off and a wrong answer that missed the point are the
// same row once only `solved` is kept.
test('the move the student played is stored beside the verdict', async () => {
  const pool = stubPool([[{ assignment_id: 3 }]]);
  await recordPuzzleResult(pool, {
    studentId: 7,
    puzzleId: 'cust_12',
    solved: false,
    msTaken: 4200,
    playedSan: 'Qh7+',
  });

  const update = pool.calls[0];
  assert.ok(update.text.includes('played_san = $5'));
  assert.equal(update.params[4], 'Qh7+');
});

test('a move nothing could resolve is stored as unknown, not as empty text', async () => {
  const pool = stubPool([[{ assignment_id: 3 }]]);
  await recordPuzzleResult(pool, {
    studentId: 7,
    puzzleId: 'cust_12',
    solved: false,
    msTaken: null,
    playedSan: null,
  });

  // NULL reads as "not known"; '' would read as "played nothing", which is not
  // a thing a student can do.
  assert.equal(pool.calls[0].params[4], null);
});

test('a caller that knows no move leaves the column null rather than failing', async () => {
  const pool = stubPool([[{ assignment_id: 3 }]]);

  // The Lichess attempt route reports only whether the puzzle was solved. It
  // must keep marking homework, and must not invent a move.
  await recordPuzzleResult(pool, { studentId: 7, puzzleId: '00abc', solved: true, msTaken: 900 });

  assert.equal(pool.calls[0].params[4], null);
});
