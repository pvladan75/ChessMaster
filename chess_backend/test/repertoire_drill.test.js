const test = require('node:test');
const assert = require('node:assert/strict');

const {
  nextItem,
  answer,
  pickReply,
  rememberReplies,
  drillStats,
  QUALITY,
} = require('../services/repertoireDrillService');
const { GRADES } = require('../services/spacedRepetitionService');

const SMITH_MORRA =
  'rnbqkbnr/pp1ppppp/8/8/4P3/2N5/PP3PPP/R1BQKBNR b KQkq - 0 4';
const KEY = 'rnbqkbnr/pp1ppppp/8/8/4P3/2N5/PP3PPP/R1BQKBNR b KQkq -';

function stubPool(results = [[]]) {
  const calls = [];
  let index = 0;
  const query = async (text, params) => {
    calls.push({ text: text.replace(/\s+/g, ' ').trim(), params });
    const rows = results[Math.min(index, results.length - 1)];
    index += 1;
    return { rows, rowCount: rows.length };
  };
  return {
    calls,
    query,
    // Storing a book replaces the whole set for the position, which is two
    // statements and therefore a transaction.
    connect: async () => ({ query, release: () => {} }),
    ran: (fragment) => calls.filter((c) => c.text.includes(fragment)).length,
  };
}

const moveRows = (rows) => rows;

test('a due position comes before one that has never been drilled', async () => {
  const pool = stubPool([
    [{ fen_key: KEY, due_at: 'x', repetitions: '4', interval_days: 12 }],
    [{ moves: 2 }],
  ]);

  const item = await nextItem(pool, 7, { color: 'b' });

  assert.equal(item.fenKey, KEY);
  assert.equal(item.fresh, false);
  assert.equal(item.repetitions, 4);
  // A board needs six FEN fields; the repertoire keeps four on purpose.
  assert.equal(item.fen, `${KEY} 0 1`);
  assert.equal(pool.ran('repertoire_reviews'), 1);
});

test('a due row whose position lost its primary is not asked about', async () => {
  // Otherwise the drill would ask a question with no answer behind it.
  const pool = stubPool([[]]);
  await nextItem(pool, 7, { color: 'b' });
  assert.match(pool.calls[0].text, /role = 'primary'/);
});

test('nothing due falls back to the positions the instinct got wrong',
  async () => {
    const pool = stubPool([
      [], // nothing due
      [{ fen_key: KEY, mistakes: '3' }],
      [{ moves: 1 }],
    ]);

    const item = await nextItem(pool, 7, { color: 'b' });

    assert.equal(item.fresh, true);
    // That ordering is the whole reason the attempts table exists.
    assert.match(pool.calls[1].text, /ORDER BY mistakes DESC/);
  });

test('an empty repertoire has nothing to ask', async () => {
  const pool = stubPool([[], []]);
  assert.equal(await nextItem(pool, 7, { color: 'b' }), null);
});

test('the primary is a pass, and the schedule moves on', async () => {
  const pool = stubPool([
    moveRows([{ uci: 'b8c6', san: 'Nc6', role: 'primary' }]),
    [{ id: 5, ease_factor: '2.50', interval_days: 0, repetitions: 0, lapses: 0 }],
    [],
  ]);

  const graded = await answer(pool, 7, {
    color: 'b', fen: SMITH_MORRA, uci: 'b8c6',
  });

  assert.equal(graded.outcome, 'primary');
  assert.equal(graded.quality, GRADES.good);
  assert.equal(graded.intervalDays, 1, 'prvi tačan odgovor se vraća sutra');
  assert.match(pool.calls[2].text, /UPDATE repertoire_reviews/);
});

test("one of the student's own alternates is accepted, and named as such",
  async () => {
    const pool = stubPool([
      moveRows([
        { uci: 'b8c6', san: 'Nc6', role: 'primary' },
        { uci: 'd7d6', san: 'd6', role: 'alternate' },
      ]),
      [{ id: 5, ease_factor: '2.50', interval_days: 0, repetitions: 0, lapses: 0 }],
      [],
    ]);

    const graded = await answer(pool, 7, {
      color: 'b', fen: SMITH_MORRA, uci: 'd7d6',
    });

    assert.equal(graded.outcome, 'alternate');
    assert.equal(graded.quality, GRADES.good);
    // So the screen can say "and your main move here is Nc6".
    assert.deepEqual(graded.primary, { uci: 'b8c6', san: 'Nc6' });
  });

test('a move that is good chess but not theirs is still a miss', async () => {
  // The drill asks about a decision, not about chess. Accepting anything sound
  // would make the schedule meaningless: everything would always be a pass.
  const pool = stubPool([
    moveRows([{ uci: 'b8c6', san: 'Nc6', role: 'primary' }]),
    [{ id: 5, ease_factor: '2.50', interval_days: 6, repetitions: 2, lapses: 0 }],
    [],
  ]);

  const graded = await answer(pool, 7, {
    color: 'b', fen: SMITH_MORRA, uci: 'g8f6',
  });

  assert.equal(graded.outcome, 'unknown');
  assert.equal(graded.quality, QUALITY.missed);
  assert.equal(graded.intervalDays, 0, 'promašeno se vraća isti čas');
  assert.deepEqual(graded.primary, { uci: 'b8c6', san: 'Nc6' });
});

test('right after looking is weaker than right from memory', async () => {
  const pool = stubPool([
    moveRows([{ uci: 'b8c6', san: 'Nc6', role: 'primary' }]),
    [{ id: 5, ease_factor: '2.50', interval_days: 6, repetitions: 2, lapses: 0 }],
    [],
  ]);

  const graded = await answer(pool, 7, {
    color: 'b', fen: SMITH_MORRA, uci: 'b8c6', revealed: true,
  });

  assert.equal(graded.quality, GRADES.hard);
  assert.ok(graded.intervalDays > 0 && graded.intervalDays < 15,
    'prepoznato nije isto što i zapamćeno');
});

test('a position with nothing decided is not graded at all', async () => {
  const pool = stubPool([[]]);

  const graded = await answer(pool, 7, {
    color: 'b', fen: SMITH_MORRA, uci: 'b8c6',
  });

  assert.equal(graded.outcome, 'unprepared');
  assert.equal(pool.ran('repertoire_reviews'), 0,
    'nema šta da se rasporedi dok pozicija nije izgrađena');
});

/// A pool for the draw, which asks two questions: the book for the position,
/// and then what the student holds where each of those replies lands.
///
/// Answered by *which* query it is rather than by call order, because a draw is
/// two queries now and a test that runs a hundred of them off one pool would
/// otherwise be feeding the second answer to the first question.
function replyPool(book, landing) {
  const calls = [];
  const query = async (text, params) => {
    calls.push({ text: text.replace(/\s+/g, ' ').trim(), params });
    const rows = /opening_replies/.test(text) ? book : landing;
    return { rows, rowCount: rows.length };
  };
  return {
    calls,
    query,
    connect: async () => ({ query, release: () => {} }),
  };
}

// The Smith-Morra one move on, so that it is White — the opponent — to move.
// `pickReply` is always asked from the position *after* the student's own
// move, and it now plays the reply out to see where it lands, so a fixture
// whose replies are illegal is a fixture that answers nothing.
const MORRA_REPLY =
  'r1bqkbnr/pp1ppppp/2n5/8/4P3/2N5/PP3PPP/R1BQKBNR w KQkq - 1 5';

/// Where each of those replies lands, by key. Written out rather than computed
/// in the test, so that a change to the walk's `step` shows up here as a
/// failure instead of being cancelled out by the same bug on both sides.
const LANDS = {
  g1f3: 'r1bqkbnr/pp1ppppp/2n5/8/4P3/2N2N2/PP3PPP/R1BQKB1R b KQkq -',
  f1c4: 'r1bqkbnr/pp1ppppp/2n5/8/2B1P3/2N5/PP3PPP/R1BQK1NR b KQkq -',
  a2a3: 'r1bqkbnr/pp1ppppp/2n5/8/4P3/P1N5/1P3PPP/R1BQKBNR b KQkq -',
};

/// The second query's rows: what the student holds at each landing position.
/// Defaults are the permissive ones, so a test only states the thing it is
/// about — `{ g1f3: { cut: true } }` reads as "they cut the Nf3 branch".
const landings = (spec) => Object.entries(spec).map(([uci, state]) => ({
  fen_key: LANDS[uci],
  decided: (state ?? {}).decided !== false,
  cut: (state ?? {}).cut === true,
}));

/// Who is asking. Both new conditions are per student, so every draw carries
/// it — see the RangeError test below for what happens when it does not.
const ASKING = { userId: 7, color: 'b' };

test('the opponent is drawn by how often a move is really played', async () => {
  const pool = replyPool([
    { uci: 'g1f3', san: 'Nf3', games: 700, covered: true },
    { uci: 'f1c4', san: 'Bc4', games: 250, covered: true },
  ], landings({ g1f3: {}, f1c4: {} }));

  // Tickets land in the two bands: 0-700 and 700-950.
  const first = await pickReply(pool,
    { ...ASKING, fen: MORRA_REPLY, random: () => 0.1 });
  const second = await pickReply(pool,
    { ...ASKING, fen: MORRA_REPLY, random: () => 0.8 });

  assert.equal(first.san, 'Nf3');
  assert.equal(second.san, 'Bc4');
});

test('a reply the student never prepared is never played at them', async () => {
  // This used to be the other way round, deliberately: meeting an uncovered
  // move showed the student the edge of what they had prepared. The owner
  // asked for it gone, and the line walk already refused to rehearse one — so
  // the live opponent was playing moves the rehearsal would not.
  const pool = replyPool([
    { uci: 'g1f3', san: 'Nf3', games: 700, covered: true },
    { uci: 'f1c4', san: 'Bc4', games: 250, covered: true },
    { uci: 'a2a3', san: 'a3', games: 50, covered: false },
  ], landings({ g1f3: {}, f1c4: {} }));

  // The last ticket there is. Under the old rule it drew the uncovered move;
  // it must now land on the last prepared one instead.
  const rare = await pickReply(pool,
    { ...ASKING, fen: MORRA_REPLY, random: () => 0.999 });
  assert.equal(rare.san, 'Bc4');

  // And the unprepared move is out of the total as well as out of the answer:
  // a ticket at 0.9 of 950 is Bc4, where 0.9 of 1000 would still have been.
  const drawn = new Set();
  for (let i = 0; i < 100; i += 1) {
    drawn.add((await pickReply(pool,
      { ...ASKING, fen: MORRA_REPLY, random: () => i / 100 })).san);
  }
  assert.deepEqual([...drawn].sort(), ['Bc4', 'Nf3']);
});

test('a move the student asked for by name counts as prepared', async () => {
  // "Prepared" means covered *or* pressed "prepare this too" on, the same as
  // everywhere else. Forgetting the second half would refuse a reply they
  // chose themselves — and it is stored per student, so the draw has to know
  // who is asking.
  const pool = replyPool(
    [{ uci: 'a2a3', san: 'a3', games: 50, covered: true }],
    landings({ a2a3: {} }));

  const drawn = await pickReply(pool,
    { ...ASKING, fen: MORRA_REPLY, random: () => 0.5 });

  assert.equal(drawn.san, 'a3');
  assert.match(pool.calls[0].text, /repertoire_extra_replies/);
  assert.deepEqual(pool.calls[0].params.slice(2), [7, 'b']);
});

test('a branch the student cut is never played at them', async () => {
  // The bug this pair of tests was written for. `repertoire_skips` stopped the
  // walk and the coverage map for months while the drill's own opponent kept
  // playing into the cut branch — so a student was asked to remember a
  // decision they had made by deleting it.
  const pool = replyPool([
    { uci: 'g1f3', san: 'Nf3', games: 700, covered: true },
    { uci: 'f1c4', san: 'Bc4', games: 250, covered: true },
  ], landings({ g1f3: { cut: true }, f1c4: {} }));

  // 0.1 of the old total is Nf3 by a distance. Every ticket there is must now
  // be Bc4, which is what makes this fail if the condition is taken back out.
  const drawn = new Set();
  for (let i = 0; i < 100; i += 1) {
    drawn.add((await pickReply(pool,
      { ...ASKING, fen: MORRA_REPLY, random: () => i / 100 })).san);
  }
  assert.deepEqual([...drawn], ['Bc4']);
  assert.match(pool.calls[1].text, /repertoire_skips/);
});

test('a reply is only played into a position the student decided something in',
  async () => {
    // The other half of the same hole: the reply was legal, covered and not
    // cut, and led somewhere the student had never answered. `answer()` would
    // have graded the next move `unprepared` — a question with nothing behind
    // it — so the draw asks the same thing `answer()` asks, and asks it first.
    const pool = replyPool([
      { uci: 'g1f3', san: 'Nf3', games: 700, covered: true },
      { uci: 'f1c4', san: 'Bc4', games: 250, covered: true },
    ], landings({ g1f3: { decided: false }, f1c4: {} }));

    const drawn = new Set();
    for (let i = 0; i < 100; i += 1) {
      drawn.add((await pickReply(pool,
        { ...ASKING, fen: MORRA_REPLY, random: () => i / 100 })).san);
    }
    assert.deepEqual([...drawn], ['Bc4']);
    assert.match(pool.calls[1].text, /source = 'chosen'/);
  });

test('the guards are asked about where a reply lands, not where it leaves',
  async () => {
    const pool = replyPool([
      { uci: 'g1f3', san: 'Nf3', games: 700, covered: true },
      { uci: 'f1c4', san: 'Bc4', games: 250, covered: true },
    ], landings({ g1f3: {}, f1c4: {} }));
    await pickReply(pool, { ...ASKING, fen: MORRA_REPLY, random: () => 0.1 });

    assert.deepEqual([...pool.calls[1].params[2]].sort(),
      [LANDS.f1c4, LANDS.g1f3].sort());
  });

test('a spar with no qualifying reply ends instead of walking off the edge',
  async () => {
    const pool = replyPool(
      [{ uci: 'g1f3', san: 'Nf3', games: 700, covered: true }],
      landings({ g1f3: { decided: false } }));
    // Null, which is what the end of the book has always looked like: the
    // screen reads it as "grana odigrana do kraja" and stops the run.
    assert.equal(
      await pickReply(pool, { ...ASKING, fen: MORRA_REPLY }), null);
  });

test('a draw that does not know who is asking is refused, not answered',
  async () => {
    // Both conditions are per student. Answering null without a student would
    // read on screen as "the branch is played out", which is a lie a caller
    // with a missing argument must not be able to tell.
    const pool = replyPool([], []);
    await assert.rejects(
      () => pickReply(pool, { fen: MORRA_REPLY, color: 'b' }), RangeError);
    await assert.rejects(
      () => pickReply(pool, { fen: MORRA_REPLY, userId: 7 }), RangeError);
    assert.equal(pool.calls.length, 0, 'odbijeno pre nego što se baza pita');
  });

test('a position with nothing prepared answers with nothing', async () => {
  const pool = replyPool(
    [{ uci: 'a2a3', san: 'a3', games: 50, covered: false }], []);
  assert.equal(await pickReply(pool, { ...ASKING, fen: MORRA_REPLY }), null);
});

test('a position whose book was never stored answers with nothing', async () => {
  const pool = replyPool([], []);
  assert.equal(await pickReply(pool, { ...ASKING, fen: MORRA_REPLY }), null);
});

test('the book is stored per position and band, and refreshed in place',
  async () => {
    const pool = stubPool([[]]);

    const stored = await rememberReplies(pool, {
      fen: SMITH_MORRA,
      minRating: 1600,
      moves: [
        { uci: 'g1f3', san: 'Nf3', games: 700, share: 0.7, covered: true },
        { uci: 'a2a3', san: 'a3', games: 50, share: 0.05, covered: false },
      ],
    });

    assert.equal(stored, 2);
    // Replaced, not merged: yesterday's rows for this position go first. That
    // is not housekeeping — castling used to be stored in Lichess's own
    // notation, and merging would have left those unplayable rows in the draw
    // forever, beside the corrected ones.
    assert.match(pool.calls[0].text, /BEGIN/);
    assert.match(pool.calls[1].text, /DELETE FROM opening_replies/);
    assert.deepEqual(pool.calls[1].params, [KEY, 1600]);
    const call = pool.calls[2];
    assert.match(call.text, /INSERT INTO opening_replies/);
    assert.equal(call.params[0], KEY);
    assert.equal(call.params[1], 1600);
    assert.match(pool.calls[3].text, /COMMIT/);
    // The uncovered move is stored too — that is what makes the drill able to
    // surprise the student without asking Lichess anything.
    assert.ok(call.params.includes('a2a3'));
  });

test('an empty book is not written as an empty row set', async () => {
  const pool = stubPool([[]]);
  assert.equal(await rememberReplies(pool, { fen: SMITH_MORRA, moves: [] }), 0);
  assert.equal(pool.calls.length, 0);
});

test('the counts tell "nothing due" apart from "nothing built"', async () => {
  const pool = stubPool([[
    { positions: 20, seen: 12, due: 3, known: 5, next_due: null },
  ]]);

  const stats = await drillStats(pool, 7, { color: 'b' });

  assert.deepEqual(stats,
    { positions: 20, due: 3, known: 5, fresh: 8, nextDueAt: null });
});

test('the counts say when the next position comes back', async () => {
  // Without this, "nothing is due" reads as "you cannot practise this" — which
  // is exactly how it read the first time a branch of one position, already
  // drilled and scheduled for tomorrow, was opened.
  const back = new Date('2026-09-01T09:00:00Z');
  const pool = stubPool([[
    { positions: 1, seen: 1, due: 0, known: 0, next_due: back },
  ]]);

  const stats = await drillStats(pool, 7, { color: 'b' });

  assert.equal(stats.fresh, 0);
  assert.equal(stats.nextDueAt, back);
});

test('running ahead takes an early position rather than nothing', async () => {
  // A branch of one position, drilled once and scheduled for tomorrow, has
  // nothing due — and "come back tomorrow" is the wrong answer to somebody who
  // has just built it and wants to run it once. This is that button.
  const pool = stubPool([
    [{ fen_key: KEY, due_at: 'tomorrow', repetitions: '2', interval_days: 1 }],
    [],
    [{ moves: 1 }],
  ]);

  const item = await nextItem(pool, 7, { color: 'b', ahead: true });

  assert.equal(item.fenKey, KEY);
  assert.equal(item.fresh, false);
  // The "is it due yet" condition is the one thing that is dropped; the order
  // is still soonest first.
  assert.match(pool.calls[0].text, /\$5 = TRUE OR r.due_at <= \$3/);
  assert.equal(pool.calls[0].params[4], true);
});

test('running ahead still asks a never-drilled position first', async () => {
  // The one thing in the queue that is not practice but real. Burying it under
  // an early repetition would be the wrong order.
  const pool = stubPool([
    [{ fen_key: KEY, due_at: 'tomorrow', repetitions: '2', interval_days: 1 }],
    [{ fen_key: 'drugi kljuc', mistakes: 0 }],
    [{ moves: 1 }],
  ]);

  const item = await nextItem(pool, 7, { color: 'b', ahead: true });

  assert.equal(item.fenKey, 'drugi kljuc');
  assert.equal(item.fresh, true);
});

test('a position walked into and not yet due is judged and not written down',
  async () => {
    // The line walks on past the question it was asked, and the positions
    // below it are not what the schedule asked for. Writing them down would
    // push their intervals out on moves nobody had to remember cold — the
    // sparring rule, said once more where `due_at` actually is.
    const soon = new Date(Date.now() + 3 * 24 * 3600 * 1000);
    const pool = stubPool([
      [{ uci: 'b8c6', san: 'Nc6', role: 'primary' }],
      [{ due_at: soon.toISOString() }],
    ]);

    const graded = await answer(pool, 7, {
      color: 'b', fen: SMITH_MORRA, uci: 'b8c6', onlyIfDue: true,
    });

    assert.equal(graded.outcome, 'primary');
    assert.equal(graded.practice, true);
    assert.equal(graded.intervalDays, null);
    assert.equal(pool.ran('UPDATE repertoire_reviews'), 0,
      'setnja je pomerila raspored pozicije koja nije bila dospela');
  });

test('but one that really was due is written down like any other', async () => {
  const pool = stubPool([
    [{ uci: 'b8c6', san: 'Nc6', role: 'primary' }],
    [{ due_at: new Date(Date.now() - 3600 * 1000).toISOString() }],
    [{ id: 3, ease_factor: 2.5, interval_days: 1, repetitions: 1, lapses: 0 }],
    [],
  ]);

  const graded = await answer(pool, 7, {
    color: 'b', fen: SMITH_MORRA, uci: 'b8c6', onlyIfDue: true,
  });

  assert.equal(graded.practice, undefined);
  assert.ok(graded.intervalDays > 0);
});

test('and a position never reviewed at all is the most due thing there is',
  async () => {
    // The rule the branch counts already keep. A position nobody has opened
    // must not read as finished, and walking into one is exactly when it is
    // worth writing down.
    const pool = stubPool([
      [{ uci: 'b8c6', san: 'Nc6', role: 'primary' }],
      [], // no review row at all
      [{ id: 3, ease_factor: 2.5, interval_days: 0, repetitions: 0, lapses: 0 }],
      [],
    ]);

    const graded = await answer(pool, 7, {
      color: 'b', fen: SMITH_MORRA, uci: 'b8c6', onlyIfDue: true,
    });

    assert.equal(graded.practice, undefined);
    assert.ok(graded.intervalDays >= 0);
  });

test('an answer given ahead of schedule is judged and not written down',
  async () => {
    // The same rule the line drill's rehearsal keeps, for the same reason: a
    // position run through five times in one evening must not come back in a
    // month on the strength of it.
    const pool = stubPool([
      [{ uci: 'b8c6', san: 'Nc6', role: 'primary' }],
    ]);

    const graded = await answer(pool, 7, {
      color: 'b', fen: SMITH_MORRA, uci: 'b8c6', practice: true,
    });

    assert.equal(graded.outcome, 'primary');
    assert.equal(graded.practice, true);
    // Nothing to promise, because nothing was stored.
    assert.equal(graded.intervalDays, null);
    assert.equal(pool.calls.length, 1, 'vezba van rasporeda je pisala u bazu');
    assert.equal(pool.ran('repertoire_reviews'), 0);
  });
