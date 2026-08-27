// trainer_panel.test.js
// Pins the four questions the trainer panel answers, and the one number it puts
// on the tab.
//
// Two kinds of failure are worth defending against here, and neither shows up
// as a broken screen. The first is a section that quietly widens: a list of
// "my students" that forgets `status = 'accepted'` shows the trainer somebody
// who never answered, and every card in that row is an action taken against a
// stranger. The second is a badge that cannot reach zero — a number nobody can
// clear is a number nobody reads, and the section it counts may as well not be
// there.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const {
  todaysLessons,
  dueSoon,
  awaitingReview,
  stalled,
  idleStudents,
  pendingRequestCount,
  trainerPanel,
  markReviewed,
} = require('../services/trainerPanelService');

/// Answers by what is being asked rather than by turn.
///
/// The panel fires its five queries together, so a queue keyed on call order
/// would pin the order they happen to be listed in — a fail for the wrong
/// reason the day one moves. Each entry is a pattern and the rows to answer it
/// with; anything unmatched answers empty.
function stubPool(answers = []) {
  const calls = [];
  return {
    calls,
    async query(text, params) {
      calls.push({ text, params });
      const hit = answers.find(([pattern]) => pattern.test(text));
      const rows = hit ? hit[1] : [];
      return { rows, rowCount: rows.length };
    },
  };
}

/// The statement a test is about, found by what it says.
function stmt(pool, pattern) {
  const found = pool.calls.find((call) => pattern.test(call.text));
  assert.ok(found, `nema upita koji odgovara ${pattern}`);
  return found;
}

test("today means today, and a lesson that has started is still today's", async () => {
  const pool = stubPool();
  await todaysLessons(pool, 7);

  const sql = stmt(pool, /FROM scheduled_sessions/).text;
  assert.match(sql, /s\.host_id = \$1/, 'only lessons this trainer hosts');
  // The window opens before now: a card that disappears the moment the lesson
  // begins vanishes exactly when the trainer reaches for it.
  assert.match(sql, /now\(\) - interval '2 hours'/);
  // And closes at midnight rather than in 24 hours, or "Danas" would be a lie
  // every evening.
  assert.match(sql, /date_trunc\('day', now\(\)\) \+ interval '1 day'/);
  assert.doesNotMatch(sql, /status = 'declined'/, 'declined guests are excluded, not selected');
});

test('a deadline still counts after it has passed', async () => {
  const pool = stubPool();
  await dueSoon(pool, 7);

  const sql = stmt(pool, /FROM assignments/).text;
  assert.match(sql, /a\.trainer_id = \$1/);
  assert.match(sql, /a\.completed_at IS NULL/, 'finished homework is not a deadline');
  assert.match(sql, /a\.due_at IS NOT NULL/, 'homework without a deadline never runs out');
  // Upper bound only. An overdue assignment is the one the trainer most needs
  // to see, so nothing here filters out the past.
  assert.match(sql, /a\.due_at < now\(\) \+ make_interval\(hours => \$2\)/);
  assert.doesNotMatch(sql, /a\.due_at > /, 'overdue work must not fall off the list');
});

test('handed-in work leaves the queue only once it has been opened', async () => {
  const pool = stubPool();
  await awaitingReview(pool, 7);

  const sql = stmt(pool, /a\.completed_at IS NOT NULL/).text;
  assert.match(sql, /a\.trainer_id = \$1/);
  assert.match(sql, /a\.reviewed_at IS NULL/, 'without this the queue only grows');
});

test('homework that has stopped moving is visible without a deadline', async () => {
  // The hole this closes, found live on 27.8.2026: an assignment with no
  // deadline appeared nowhere at all, and one that stalled at 8 of 10 dropped
  // out of "Nije vežbao" the moment the student solved their first puzzle. A
  // deadline is not the only reason to look at homework.
  const pool = stubPool();
  await stalled(pool, 7);

  const sql = stmt(pool, /GREATEST/).text;
  assert.match(sql, /a\.trainer_id = \$1/);
  assert.match(sql, /a\.completed_at IS NULL/);
  // Work that has never been opened dates from when it was set, not from a
  // null nobody can compare against.
  assert.match(sql, /GREATEST\(a\.created_at, MAX\(ai\.attempted_at\)\)/);
  assert.doesNotMatch(sql, /attempted_items = 0|COUNT\(ai\.attempted_at\) = 0/,
    'partly finished homework stalls too');
});

test('no assignment can be in both homework sections at once', async () => {
  // The two windows are complements: what is due inside DUE_SOON_HOURS belongs
  // to one section, everything else may belong to the other. Overlapping them
  // would put the same student on the same screen twice, under two headings
  // whose buttons do the same thing.
  const due = stubPool();
  await dueSoon(due, 7);
  const stall = stubPool();
  await stalled(stall, 7);

  const dueSql = stmt(due, /FROM assignments/).text;
  assert.match(dueSql, /a\.due_at IS NOT NULL/);
  assert.match(dueSql, /a\.due_at < now\(\) \+ make_interval\(hours => \$2\)/);

  const stallSql = stmt(stall, /GREATEST/).text;
  assert.match(stallSql, /a\.due_at IS NULL OR a\.due_at >= now\(\) \+ make_interval\(hours => \$2\)/);
  assert.doesNotMatch(stallSql, /a\.due_at < now\(\)/, 'the two windows must not overlap');
});

test('a student with open homework is not also called quiet', async () => {
  const pool = stubPool();
  await idleStudents(pool, 7);

  const sql = stmt(pool, /user_puzzle_attempts/).text;
  assert.match(sql, /NOT EXISTS/);
  assert.match(sql, /a\.completed_at IS NULL/,
    'only *open* homework moves them to the other section');
  assert.match(sql, /a\.trainer_id = \$1/,
    'somebody else’s homework is not my row to show');
});

test('the quiet-student list reads the edge through the accepted fragment', async () => {
  // The bug this defends against is invisible: the section keeps working, and
  // the only difference is that somebody who never accepted appears in a list
  // of "my students" — which this screen then offers actions on.
  const pool = stubPool();
  await idleStudents(pool, 7);

  const sql = stmt(pool, /user_puzzle_attempts/).text;
  assert.match(sql, /SELECT student_id FROM trainer_students/);
  assert.match(sql, /status\s*=\s*'accepted'/);
  // Never attempted is a longer silence than any interval, and must not be
  // swallowed by comparing NULL against a date.
  assert.match(sql, /MAX\(p\.created_at\) IS NULL/);
});

test('a request I sent myself is not waiting for me', async () => {
  const pool = stubPool([[/COUNT\(\*\)/, [{ count: 3 }]]]);
  const count = await pendingRequestCount(pool, 4);

  assert.equal(count, 3);
  const sql = stmt(pool, /FROM trainer_students/).text;
  assert.match(sql, /status = 'pending'/);
  assert.match(sql, /initiated_by <> \$1/, 'my own request is not my inbox');
  assert.match(sql, /\$1 IN \(trainer_id, student_id\)/);
});

test('the badge counts only what the trainer can clear', async () => {
  const pool = stubPool([
    [/a\.completed_at IS NOT NULL/, [{ id: 1 }, { id: 2 }]],
    [/COUNT\(\*\)::int AS count/, [{ count: 1 }]],
    [/a\.due_at IS NOT NULL/, [{ id: 3 }, { id: 4 }, { id: 5 }]],
    [/user_puzzle_attempts/, [{ id: 6 }]],
    [/GREATEST/, [{ id: 7 }, { id: 8 }]],
  ]);

  const panel = await trainerPanel(pool, 7);

  assert.equal(panel.counts.awaitingReview, 2);
  assert.equal(panel.counts.requests, 1);
  // Two deadlines and a quiet student are on the screen and out of the number:
  // neither is cleared by the trainer doing anything, and a badge that cannot
  // reach zero stops being read.
  assert.equal(panel.dueSoon.length, 3);
  assert.equal(panel.idle.length, 1);
  assert.equal(panel.stalled.length, 2);
  assert.equal(panel.counts.waiting, 3);
});

test('an empty panel is a panel, not an error', async () => {
  const panel = await trainerPanel(stubPool(), 7);

  assert.deepEqual(panel.today, []);
  assert.deepEqual(panel.idle, []);
  assert.deepEqual(panel.stalled, []);
  assert.equal(panel.counts.waiting, 0);
});

test('marking reviewed carries its whole rule in the WHERE clause', async () => {
  const pool = stubPool([[/UPDATE assignments/, [{ id: 5 }]]]);
  assert.equal(await markReviewed(pool, { assignmentId: 5, trainerId: 7 }), true);

  const sql = stmt(pool, /UPDATE assignments/).text;
  assert.match(sql, /trainer_id = \$2/, 'only the trainer who set it');
  assert.match(sql, /completed_at IS NOT NULL/, 'nothing to review until it is done');
  assert.match(sql, /reviewed_at IS NULL/, 'the first look is the one recorded');
});

test('marking somebody else’s assignment writes nothing and says so', async () => {
  const pool = stubPool();
  assert.equal(await markReviewed(pool, { assignmentId: 5, trainerId: 7 }), false);
});

/// The body of one route, by matching the parentheses that open it.
///
/// Not a fixed slice: a slice runs past the end of the route and into the next
/// one, so a check removed from *this* route still matches in the one below and
/// the test keeps passing. That has already happened once in this repository.
function routeBody(source, marker) {
  const start = source.indexOf(marker);
  assert.ok(start !== -1, `nema rute ${marker}`);

  let depth = 0;
  for (let i = source.indexOf('(', start); i < source.length; i++) {
    if (source[i] === '(') depth++;
    else if (source[i] === ')') {
      depth--;
      if (depth === 0) return source.slice(start, i + 1);
    }
  }
  assert.fail(`ruta ${marker} nije zatvorena`);
}

test('reading a review does not empty the trainer’s queue', () => {
  // The student reads the same review. If the GET wrote `reviewed_at`, a child
  // looking at their own feedback would take the item off their trainer's list
  // — and the trainer would never learn it had been there.
  const source = fs.readFileSync(
    path.join(__dirname, '..', 'routes', 'assignments.js'),
    'utf8'
  );

  const read = routeBody(source, "router.get('/:id/review'");
  assert.doesNotMatch(read, /reviewed_at|markReviewed/);

  // And the route that does write it is a POST of its own.
  const write = routeBody(source, "router.post('/:id/reviewed'");
  assert.match(write, /markReviewed/);
});

test('the brace matcher stops at the end of its own route', () => {
  // Proving the reader above by mutation rather than trusting it: a marker
  // whose route does not contain the pattern must not find it in the next one.
  const fake = [
    "router.get('/a', (req, res) => { res.json({ ok: true }); });",
    "router.post('/b', (req, res) => { markReviewed(pool, {}); });",
  ].join('\n');

  assert.doesNotMatch(routeBody(fake, "router.get('/a'"), /markReviewed/);
  assert.match(routeBody(fake, "router.post('/b'"), /markReviewed/);
});
