// player_profile.test.js — the clock arithmetic, which is where this can be
// wrong without anything failing.
//
// The GROUP BY half is tested only for shape. What gets real attention is the
// two things that produce plausible wrong numbers instead of errors: which
// entries on the clock array belong to the player, and the fact that a clock
// with an increment is not a stopwatch.

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  playerProfile, monthlyTrend, clockProfile, subjectClocks, clockAfterMove,
  incrementOf, CLOCK_AT_MOVE, HURRIED_SECONDS,
} = require('../services/playerProfile');

// Clock after each ply, in centiseconds. White is on the odd plies.
const CLOCKS = [18000, 17900, 17500, 17700, 17000, 17500];

test('the player\'s clocks are every other entry, and which one is the colour', () => {
  // Reversing this does not throw. It reports the opponent's time trouble as
  // the player's, and every number downstream stays plausible.
  assert.deepEqual(subjectClocks(CLOCKS, 'w'), [180, 175, 170]);
  assert.deepEqual(subjectClocks(CLOCKS, 'b'), [179, 177, 175]);
  assert.deepEqual(subjectClocks(null, 'w'), []);
});

test('a missing reading stays missing rather than becoming zero', () => {
  assert.deepEqual(subjectClocks([18000, null, null, 17700], 'w'), [180, null]);
  assert.deepEqual(subjectClocks([18000, null, null, 17700], 'b'), [null, 177]);
});

test('the clock after a move is read from the same parity rule', () => {
  assert.equal(clockAfterMove(CLOCKS, 'w', 1), 180);
  assert.equal(clockAfterMove(CLOCKS, 'w', 3), 170);
  assert.equal(clockAfterMove(CLOCKS, 'b', 2), 177);
  // A game that did not get there.
  assert.equal(clockAfterMove(CLOCKS, 'w', 20), null);
});

test('the increment is read, because a clock is not a stopwatch', () => {
  // In a 3+2 game a move played in one second leaves the clock higher than it
  // was. Forgetting this says a 3+2 player never hurries.
  assert.equal(incrementOf('180+2'), 2);
  assert.equal(incrementOf('180+0'), 0);
  assert.equal(incrementOf('300'), 0);
  assert.equal(incrementOf(null), 0);
});

/// Builds a game whose player spends `spent` seconds on every move.
function gameSpending(spent, { color = 'w', increment = 2, moves = 30, score = 1 } = {}) {
  const clocks = [];
  let mine = 180;
  let theirs = 180;
  for (let ply = 1; ply <= moves * 2; ply += 1) {
    const whiteToMove = ply % 2 === 1;
    const iMoved = (color === 'w') === whiteToMove;
    if (iMoved) {
      mine = mine - spent + increment;
      clocks.push(Math.round(mine * 100));
    } else {
      theirs = theirs - 5 + increment;
      clocks.push(Math.round(theirs * 100));
    }
  }
  return {
    subject_color: color,
    subject_score: score,
    clocks,
    ply_count: moves * 2,
    termination: 'Normal',
    time_control: `180+${increment}`,
  };
}

function stubPool(rows) {
  const calls = [];
  return {
    calls,
    query: async (text, params = []) => {
      calls.push({ text: text.replace(/\s+/g, ' ').trim(), params });
      return { rows, rowCount: rows.length };
    },
  };
}

test('a hurried move is measured after the increment is added back', async () => {
  // One second a move in a 3+2 game: the clock rises, and a naive
  // before-minus-after would call it a slow move.
  const fast = await clockProfile(stubPool([gameSpending(1)]), 5, 's');
  assert.equal(fast.hurriedShare, 1, 'every move took one second');

  const slow = await clockProfile(stubPool([gameSpending(8)]), 5, 's');
  assert.equal(slow.hurriedShare, 0, 'every move took eight seconds');

  // And exactly at the threshold, which is where an off-by-one would live.
  const borderline = await clockProfile(stubPool([gameSpending(HURRIED_SECONDS)]), 5, 's');
  assert.equal(borderline.hurriedShare, 0);
});

test('the opening is not counted as hurrying', async () => {
  // The first ten moves of a prepared line are meant to be fast. Counting them
  // would make every player look rushed.
  const short = await clockProfile(stubPool([gameSpending(1, { moves: 9 })]), 5, 's');
  assert.equal(short.hurriedShare, null, 'nothing after move ten to measure');
});

test('games are bucketed by the clock the player had at move 20', async () => {
  // 4 seconds a move with a 2-second increment: 2 net a move, so after 20 moves
  // about 140 seconds are left.
  const rows = [
    gameSpending(4, { score: 1 }),
    // 8 a move nets 6: about 60 left at move 20, and this one was lost.
    gameSpending(8, { score: 0 }),
  ];
  const profile = await clockProfile(stubPool(rows), 5, 's');
  assert.equal(profile.sampled, 2);
  assert.equal(profile.reachedMove20, 2);

  const filled = profile.atMove20.filter((b) => b.games > 0);
  assert.deepEqual(filled.map((b) => [b.key, b.games, b.score]), [
    ['60-120s', 1, 0],
    ['over-120s', 1, 1],
  ]);
  // Every bucket is present even when empty, so a chart has an axis.
  assert.equal(profile.atMove20.length, 4);
});

test('a game too short to reach the reading is counted but not bucketed', async () => {
  const profile = await clockProfile(stubPool([gameSpending(4, { moves: 12 })]), 5, 's');
  assert.equal(profile.sampled, 1);
  assert.equal(profile.reachedMove20, 0);
  assert.equal(profile.atMove20.every((b) => b.games === 0), true);
});

test('a loss on time is counted, and a win on time is not', async () => {
  const rows = [
    { ...gameSpending(4, { score: 0 }), termination: 'Time forfeit' },
    { ...gameSpending(4, { score: 1 }), termination: 'Time forfeit' },
  ];
  const profile = await clockProfile(stubPool(rows), 5, 's');
  assert.equal(profile.lostOnTime, 1);
});

test('the sample is bounded and the bound is reported', async () => {
  const pool = stubPool([]);
  const profile = await clockProfile(pool, 5, 's', { sample: 50 });
  assert.equal(pool.calls[0].params[2], 50);
  assert.equal(profile.sampled, 0);
  assert.equal(profile.hurriedShare, null);
});

test('the profile refuses a missing handle before querying anything', async () => {
  const pool = stubPool([]);
  await assert.rejects(() => playerProfile(pool, 5, { subject: '  ' }), RangeError);
  await assert.rejects(() => playerProfile(pool, 'nije broj', { subject: 's' }), TypeError);
  assert.equal(pool.calls.length, 0);
});

test('the reading is taken at move twenty', () => {
  // Named rather than inlined, so a change to it is a change somebody made
  // rather than a number that drifted.
  assert.equal(CLOCK_AT_MOVE, 20);
});

test('the monthly trend comes back oldest first, and is only a trend', async () => {
  // The query asks newest-first so a LIMIT keeps the recent months; a chart
  // wants them the other way round, and reversing at the wrong end is the kind
  // of thing that draws an improving player as a declining one.
  const pool = stubPool([
    { month: '2026-08', games: 100, points: '55.0', avg_elo: 1950 },
    { month: '2026-07', games: 80, points: '36.0', avg_elo: 1930 },
  ]);
  const trend = await monthlyTrend(pool, 5, 's');
  assert.deepEqual(trend.map((m) => m.month), ['2026-07', '2026-08']);
  assert.ok(Math.abs(trend[1].score - 0.55) < 1e-9);
  assert.equal(trend[0].avgElo, 1930);
  assert.equal(pool.calls[0].params[2], 12);
});
