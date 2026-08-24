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

test('the opponent is drawn by how often a move is really played', async () => {
  const pool = stubPool([[
    { uci: 'g1f3', san: 'Nf3', games: 700, covered: true },
    { uci: 'f1c4', san: 'Bc4', games: 250, covered: true },
    { uci: 'a2a3', san: 'a3', games: 50, covered: false },
  ]]);

  // Tickets land in the three bands: 0-700, 700-950, 950-1000.
  const first = await pickReply(pool, { fen: SMITH_MORRA, random: () => 0.1 });
  const second = await pickReply(pool, { fen: SMITH_MORRA, random: () => 0.8 });
  const rare = await pickReply(pool, { fen: SMITH_MORRA, random: () => 0.99 });

  assert.equal(first.san, 'Nf3');
  assert.equal(second.san, 'Bc4');
  // The uncovered move is in the draw on purpose: meeting one is the drill
  // showing the student the edge of what they prepared.
  assert.equal(rare.san, 'a3');
  assert.equal(rare.covered, false);
});

test('a position whose book was never stored answers with nothing', async () => {
  const pool = stubPool([[]]);
  assert.equal(await pickReply(pool, { fen: SMITH_MORRA }), null);
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
    { positions: 20, seen: 12, due: 3, known: 5 },
  ]]);

  const stats = await drillStats(pool, 7, { color: 'b' });

  assert.deepEqual(stats, { positions: 20, due: 3, known: 5, fresh: 8 });
});
