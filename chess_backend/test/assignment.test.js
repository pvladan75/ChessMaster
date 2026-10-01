// assignment.test.js
// Covers the progress arithmetic and the puzzle-selection filters behind
// homework — the numbers a trainer repeats to a parent, and the query that
// decides what a child is asked to do.

const test = require('node:test');
const assert = require('node:assert/strict');

const realtime = require('../services/realtime');
const {
  summariseAttempts,
  resolvePuzzles,
  recordPuzzleResult,
  markCompleteIfDone,
  MAX_ITEMS,
  DEFAULT_ITEMS,
} = require('../services/assignmentService');

/// Finishing an assignment notifies the trainer, and notifying nudges them.
/// Without a server that is a wiring mistake loud enough to throw; nobody is
/// registered as online here, so nothing is actually sent.
realtime.init({ to: () => ({ emit: () => {} }) });

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

/// One row of the attempt log, as `attemptsOf` reads it. Every puzzle gets its
/// own id: since 1.10.2026 the summary counts puzzles, not rows, so two rows
/// with one id are one puzzle tried twice.
let minuteOfAugust = 0;
function attempt(id, solved, themes, extra = {}) {
  minuteOfAugust += 1;
  return {
    puzzle_id: id,
    source: 'lichess',
    solved,
    skipped: false,
    hinted: false,
    themes,
    // As the database hands them: a drill that does not rate writes null.
    rating_before: null,
    rating_after: null,
    created_at: new Date(Date.UTC(2026, 7, 15, 10, minuteOfAugust)).toISOString(),
    ...extra,
  };
}

let nextId = 0;
const fresh = () => `p${(nextId += 1)}`;

// Until 1.10.2026 the summary counted rows: „accuracy is computed over all
// attempts" held 2 of 4 rows as 50%, a puzzle tried five times as five, and a
// skip — `solved` false — as a wrong answer. It now counts puzzles through the
// Practise cards' own fold (`puzzlesOf`), and the cases below hold that.

test('a puzzle counts once, however often it is tried', () => {
  const id = fresh();
  const summary = summariseAttempts([
    attempt(id, false, ['fork']),
    attempt(id, false, ['fork']),
    attempt(id, false, ['fork']),
    attempt(id, false, ['fork']),
    attempt(id, true, ['fork']),
  ]);

  assert.equal(summary.puzzles, 1);
  assert.equal(summary.solved, 1, 'it stands solved: its latest try solved it');
  assert.equal(summary.firstTries, 1);
  assert.equal(summary.solvedFirstTry, 0, 'but it was not solved when first met');
  assert.equal(summary.accuracy, 0);
});

test('a skip is a skip: never a failure, and out of the accuracy', () => {
  const summary = summariseAttempts([
    attempt(fresh(), true, ['fork']),
    attempt(fresh(), false, ['fork']),
    attempt(fresh(), false, ['fork'], { skipped: true }),
  ]);

  assert.equal(summary.puzzles, 3);
  assert.equal(summary.solved, 1);
  assert.equal(summary.failed, 1);
  assert.equal(summary.skipped, 1);
  assert.equal(summary.firstTries, 2, 'a puzzle skipped at first sight was not answered');
  assert.equal(summary.accuracy, 50);
});

test('a hinted first solve is a solve, but not at the first attempt', () => {
  const summary = summariseAttempts([
    attempt(fresh(), true, ['fork'], { hinted: true }),
    attempt(fresh(), true, ['fork']),
  ]);

  assert.equal(summary.solved, 2);
  assert.equal(summary.firstTries, 2);
  assert.equal(summary.solvedFirstTry, 1);
  assert.equal(summary.accuracy, 50);
});

test('a puzzle met before the period is in what was done, not in the accuracy', () => {
  const since = '2026-08-15T10:30:00Z';
  const old = fresh();
  const rows = [
    attempt(old, false, ['pin'], { created_at: '2026-08-01T09:00:00Z' }),
    attempt(old, true, ['pin'], { created_at: '2026-08-20T09:00:00Z' }),
    // Every row before the period: not in it at all.
    attempt(fresh(), false, ['pin'], { created_at: '2026-08-02T09:00:00Z' }),
    // Met in the period and solved there.
    attempt(fresh(), true, ['fork'], { created_at: '2026-08-21T09:00:00Z' }),
  ];

  const summary = summariseAttempts(rows, { since });
  assert.equal(summary.puzzles, 2);
  assert.equal(summary.solved, 2);
  assert.equal(summary.firstTries, 1, 'the old puzzle was first met before the period');
  assert.equal(summary.accuracy, 100);
  assert.deepEqual(summary.themes.map((t) => t.theme), ['fork']);

  // And without a period, the whole log.
  const lifetime = summariseAttempts(rows);
  assert.equal(lifetime.puzzles, 3);
  assert.equal(lifetime.failed, 1);
  assert.equal(lifetime.firstTries, 3);
  assert.equal(lifetime.accuracy, 33);
});

test('a student with no attempts reports null accuracy, not zero', () => {
  const summary = summariseAttempts([]);

  // Zero would read as "gets everything wrong"; null reads as "no data", which
  // is the truth and the only honest thing to show a parent.
  assert.equal(summary.accuracy, null);
  assert.equal(summary.puzzles, 0);
  assert.deepEqual(summary.weakestThemes, []);
});

test('only skips: something was done, and there is no accuracy to report', () => {
  const summary = summariseAttempts([
    attempt(fresh(), false, ['fork'], { skipped: true }),
  ]);
  assert.equal(summary.puzzles, 1);
  assert.equal(summary.skipped, 1);
  assert.equal(summary.accuracy, null);
});

test('a theme needs enough puzzles before it counts as a weakness', () => {
  const rows = [
    // pin: one puzzle, failed — 0% but meaningless.
    attempt(fresh(), false, ['pin']),
    // fork: five puzzles, two solved — 40% and real.
    attempt(fresh(), true, ['fork']),
    attempt(fresh(), true, ['fork']),
    attempt(fresh(), false, ['fork']),
    attempt(fresh(), false, ['fork']),
    attempt(fresh(), false, ['fork']),
  ];

  const summary = summariseAttempts(rows, { minPuzzlesPerTheme: 4 });

  assert.deepEqual(
    summary.weakestThemes.map((entry) => entry.theme),
    ['fork'],
    'a single failed puzzle must not brand a motif as the student\'s weakness'
  );
  assert.equal(summary.weakestThemes[0].accuracy, 40);
});

test('one puzzle tried four times is one puzzle towards the threshold, not four', () => {
  const id = fresh();
  const summary = summariseAttempts([
    attempt(id, false, ['pin']),
    attempt(id, false, ['pin']),
    attempt(id, false, ['pin']),
    attempt(id, false, ['pin']),
  ]);
  assert.deepEqual(summary.weakestThemes, [],
    'four tries of one puzzle used to brand „pin" a weakness');
  assert.equal(summary.themes[0].firstTries, 1);
});

test('weakest and strongest are ordered from the same measured set', () => {
  const rows = [];
  for (let i = 0; i < 5; i++) rows.push(attempt(fresh(), true, ['fork']));
  for (let i = 0; i < 5; i++) rows.push(attempt(fresh(), false, ['pin']));
  for (let i = 0; i < 5; i++) rows.push(attempt(fresh(), i < 3, ['skewer']));

  const summary = summariseAttempts(rows);

  assert.equal(summary.weakestThemes[0].theme, 'pin');
  assert.equal(summary.weakestThemes[0].accuracy, 0);
  assert.equal(summary.strongestThemes[0].theme, 'fork');
  assert.equal(summary.strongestThemes[0].accuracy, 100);
});

test('a puzzle tagged with several motifs counts towards each', () => {
  const summary = summariseAttempts([
    attempt(fresh(), true, ['fork', 'hangingPiece']),
    attempt(fresh(), false, ['fork', 'pin']),
  ]);

  const byTheme = Object.fromEntries(summary.themes.map((entry) => [entry.theme, entry]));
  assert.equal(byTheme.fork.firstTries, 2);
  assert.equal(byTheme.hangingPiece.firstTries, 1);
  assert.equal(byTheme.pin.firstTries, 1);
});

test('attempts without themes do not break the summary', () => {
  const summary = summariseAttempts([
    attempt(fresh(), true, null),
    attempt(fresh(), false, undefined),
  ]);

  assert.equal(summary.puzzles, 2);
  assert.equal(summary.accuracy, 50);
  assert.deepEqual(summary.themes, []);
});

// A drill is not a motif (the owner's choice (b), 1.10.2026): until then
// `/submit` stored ['mate_puzzle'] or ['winning_position'] as a row's themes,
// and the report named them as motifs. The rows are as `attemptsOf` hands
// them back — the puzzle's depth joined as text in `bucket`.

test('mate puzzles count under their mate in N, beside the Lichess mates of that depth', () => {
  const summary = summariseAttempts([
    // Two as /submit wrote them until 1.10.2026, two as it writes now.
    attempt(fresh(), false, ['mate_puzzle'], { source: 'mate_puzzle', bucket: '2' }),
    attempt(fresh(), false, ['mate_puzzle'], { source: 'mate_puzzle', bucket: '2' }),
    attempt(fresh(), true, [], { source: 'mate_puzzle', bucket: '2' }),
    attempt(fresh(), false, [], { source: 'mate_puzzle', bucket: '2' }),
    // A Lichess mate in two is the same motif and the same tally.
    attempt(fresh(), false, ['mateIn2']),
  ]);

  assert.deepEqual(
    summary.themes.map((t) => [t.theme, t.firstTries, t.solvedFirstTry]),
    [['mateIn2', 5, 1]]
  );
  assert.deepEqual(summary.weakestThemes.map((t) => [t.theme, t.accuracy]), [['mateIn2', 20]]);
});

test('a winning position is in the totals and under no motif, whatever its depth', () => {
  // Depth 4: `mateIn4` is a motif, so reading the depth of any puzzle would
  // file these under it.
  const rows = [];
  for (let i = 0; i < 4; i++) {
    rows.push(attempt(fresh(), false, ['winning_position'], { source: 'winning_position', bucket: '4' }));
  }
  const summary = summariseAttempts(rows);

  assert.equal(summary.puzzles, 4);
  assert.equal(summary.firstTries, 4);
  assert.equal(summary.accuracy, 0);
  assert.deepEqual(summary.themes, [], 'four failed first tries read „winning_position 0%" until 1.10.2026');
  assert.deepEqual(summary.weakestThemes, []);
});

// ── the whole report, from the one query the cards read ──────────────────

/// A pool that answers the report's three questions by what they ask.
function progressPool(attemptRows, { rating = null, assignments = { total: 0, completed: 0, overdue: 0 } } = {}) {
  const calls = [];
  return {
    calls,
    async query(text, params) {
      calls.push({ text: String(text), params });
      if (/FROM user_puzzle_attempts/.test(text)) return { rows: attemptRows };
      if (/FROM user_puzzle_ratings/.test(text)) return { rows: rating ? [rating] : [] };
      if (/FROM assignments/.test(text)) return { rows: [assignments] };
      throw new Error(`unexpected query: ${text}`);
    },
  };
}

const NOW = Date.parse('2026-09-30T12:00:00Z');
const daysAgo = (n) => new Date(NOW - n * 24 * 60 * 60 * 1000).toISOString();

test('the report reads the whole log once, and counts its period by `now`', async () => {
  const { getStudentProgress } = require('../services/assignmentService');
  const old = fresh();
  const pool = progressPool([
    attempt(old, false, ['pin'], { created_at: daysAgo(40) }),
    attempt(old, true, ['pin'], { created_at: daysAgo(3) }),
    attempt(fresh(), true, ['fork'], { created_at: daysAgo(2), source: 'mate_puzzle' }),
    attempt(fresh(), false, [], { created_at: daysAgo(2), source: 'endgame', skipped: true }),
    attempt(fresh(), true, [], { created_at: daysAgo(35), source: 'blunder_game' }),
  ]);

  const progress = await getStudentProgress(pool, 9, { days: 30, now: NOW });

  const asked = pool.calls.filter((c) => /FROM user_puzzle_attempts/.test(c.text));
  assert.equal(asked.length, 1);
  assert.deepEqual(asked[0].params, [9]);
  // The cards' query, whole: no window in SQL, because a period's puzzles
  // need first rows older than the period.
  assert.match(asked[0].text, /WHERE a\.user_id = \$1\s+ORDER BY/);

  assert.equal(progress.puzzles, 3, 'the 40-day-old puzzle retried in the period, the mate, the skipped endgame');
  assert.equal(progress.solved, 2);
  assert.equal(progress.skipped, 1);
  assert.equal(progress.failed, 0);
  assert.equal(progress.firstTries, 1, 'only the mate was first met in the period and answered');
  assert.equal(progress.accuracy, 100);
  assert.equal(progress.activeDays, 2);
  // Lifetime: every puzzle of the log, by where it stands.
  assert.equal(progress.lifetimeSolved, 3);
  assert.equal(progress.lifetimeFailed, 0);
});

test('rating movement is read from rated rows, whatever drill sits at either end', async () => {
  const { getStudentProgress } = require('../services/assignmentService');
  const pool = progressPool([
    // An endgame first and a game blunder last carry no rating. Until
    // 1.10.2026 either one at an end of the period made the change null.
    attempt(fresh(), true, [], { created_at: daysAgo(20), source: 'endgame' }),
    attempt(fresh(), true, ['fork'], { created_at: daysAgo(15), rating_before: 1500, rating_after: 1512 }),
    attempt(fresh(), false, ['pin'], { created_at: daysAgo(10), rating_before: 1512, rating_after: 1505 }),
    attempt(fresh(), true, ['fork'], { created_at: daysAgo(5), rating_before: 1505, rating_after: 1520 }),
    attempt(fresh(), false, [], { created_at: daysAgo(1), source: 'blunder_game' }),
  ]);

  const progress = await getStudentProgress(pool, 9, { days: 30, now: NOW });
  assert.equal(progress.ratingChange, 20);
});

test('no rated row in the period is no rating change, not +0', async () => {
  const { getStudentProgress } = require('../services/assignmentService');
  const pool = progressPool([
    attempt(fresh(), true, [], { created_at: daysAgo(2), source: 'endgame' }),
  ]);
  const progress = await getStudentProgress(pool, 9, { days: 30, now: NOW });
  assert.equal(progress.ratingChange, null);
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

test('a tag that is neither a motif nor a game phase is dropped from the filter', async () => {
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

test('what the client sends as a move is kept only where it could be one', async () => {
  const pool = stubPool([[{ assignment_id: 3 }]]);
  await recordPuzzleResult(pool, {
    studentId: 7,
    puzzleId: '00abc',
    solved: false,
    msTaken: 900,
    playedSan: ' <b>Qe2+</b> ',
  });

  // The puzzle path takes this from the client, which already decides `solved`
  // there — so the move is trusted no further than the verdict it arrives with,
  // and nothing that cannot appear in notation reaches a trainer's screen.
  assert.equal(pool.calls[0].params[4], 'bQe2+b');
});

test('a legitimate move survives being cleaned', () => {
  const { cleanSan } = require('../services/assignmentService');

  for (const san of ['Ra8#', 'exd8=Q+', 'O-O', 'Nbd7', 'e4', 'axb6', 'Qh1#']) {
    assert.equal(cleanSan(san), san);
  }
  assert.equal(cleanSan('   '), null);
  assert.equal(cleanSan(null), null);
  assert.equal(cleanSan('x'.repeat(40)).length, 20);
});


test('the trainer is told when the last item lands', async () => {
  // The trainer used to have to keep opening the list to find out.
  const pool = stubPool([
    [{ id: 3, trainer_id: 1, student_id: 7, title: 'Matovi u dva', student_name: 'pavle' }],
  ]);
  const done = await markCompleteIfDone(pool, 3);

  assert.equal(done.id, 3);
  const stamp = pool.calls[0];
  assert.match(stamp.text, /completed_at IS NULL/, 'only the first time');
  assert.match(stamp.text, /attempted_at IS NULL/, 'and only once nothing is left');

  const notice = pool.calls[1];
  assert.match(notice.text, /INSERT INTO user_notifications/);
  assert.equal(notice.params[0], 1, 'to the trainer');
  assert.equal(notice.params[4], 'pavle completed the assignment: Matovi u dva');
  assert.equal(notice.params[5], 'assignment_done');
  assert.equal(notice.params[6], 3, 'points at the assignment');
});

test('an assignment that was already finished tells nobody again', async () => {
  // Re-walking a finished lesson or re-solving one of its puzzles updates no
  // row, and that is what keeps the notice to exactly one.
  const pool = stubPool([[]]);
  assert.equal(await markCompleteIfDone(pool, 3), null);
  assert.equal(pool.calls.length, 1, 'stopped before writing a notice');
});

test('a student whose name is missing is still named something', async () => {
  const pool = stubPool([
    [{ id: 3, trainer_id: 1, student_id: 7, title: 'Matovi u dva', student_name: null }],
  ]);
  await markCompleteIfDone(pool, 3);

  assert.equal(pool.calls[1].params[4], 'Student completed the assignment: Matovi u dva');
});
