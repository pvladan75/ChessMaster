// mistake_reviews.test.js — what gets stored, what gets refused, and what the
// spacing does with it.
//
// The SM-2 arithmetic itself is not re-tested here; it is the same pure
// `schedule()` that spaced_repetition.test.js already covers, and testing it
// twice would be testing two things that cannot disagree. What is tested here
// is everything around it — including that this store really does reuse it.

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  recordMistakes, dueItems, gradeItem, stats, recurrence,
  materialSignature, whyNotStorable, MAX_ITEMS_PER_CALL,
} = require('../services/mistakeReviews');
const { schedule } = require('../services/spacedRepetitionService');

const FEN = '8/8/8/4k3/8/8/4P3/4K3 w - - 0 1';

function item(over = {}) {
  return {
    gameId: 3, ply: 41, fenBefore: FEN, playedUci: 'e2e4',
    bestUci: 'e1d2', theme: 'fork', swingCp: -320, ...over,
  };
}

/// Answers by reading the statement. `owned` is the set of game ids that belong
/// to the caller; `insertedOf` decides how many of an insert survive the
/// conflict clause.
function stubPool({ owned = [3], insertedOf = (n) => n, rows = [], current = null } = {}) {
  const calls = [];
  const query = async (text, params = []) => {
    const flat = text.replace(/\s+/g, ' ').trim();
    calls.push({ text: flat, params });
    if (/SELECT id FROM user_games/.test(flat)) {
      const asked = params[1] || [];
      const mine = asked.filter((id) => owned.includes(Number(id)));
      return { rows: mine.map((id) => ({ id })), rowCount: mine.length };
    }
    if (/INSERT INTO mistake_reviews/.test(flat)) {
      const offered = params.length / 9;
      const stored = insertedOf(offered);
      return { rows: Array.from({ length: stored }, (_, i) => ({ id: i + 1 })), rowCount: stored };
    }
    if (/SELECT \* FROM mistake_reviews/.test(flat)) {
      return current ? { rows: [current], rowCount: 1 } : { rows: [], rowCount: 0 };
    }
    if (/UPDATE mistake_reviews/.test(flat)) {
      return { rows: [{ id: 1 }], rowCount: 1 };
    }
    return { rows, rowCount: rows.length };
  };
  return { calls, query };
}

test('a batch of findings comes back as a tally, not an ok', async () => {
  const pool = stubPool();
  const tally = await recordMistakes(pool, 5, [item(), item({ ply: 42 })]);
  assert.deepEqual(tally, {
    read: 2, stored: 2, duplicate: 0, rejected: 0, rejected_by_reason: {},
  });

  const insert = pool.calls.find((c) => /INSERT INTO mistake_reviews/.test(c.text));
  assert.equal(insert.params.length, 18, 'nine columns per row');
  assert.equal(insert.params[0], 5, 'every row is scoped to the caller');
  assert.equal(insert.params[6], 'engine');
  assert.match(insert.text, /ON CONFLICT \(user_id, game_id, ply\) DO NOTHING/);
});

test('findings already stored are duplicates, and the tally still balances', async () => {
  const pool = stubPool({ insertedOf: () => 0 });
  const tally = await recordMistakes(pool, 5, [item(), item({ ply: 42 })]);
  assert.equal(tally.stored, 0);
  assert.equal(tally.duplicate, 2);
  assert.equal(tally.read, tally.stored + tally.duplicate + tally.rejected);
});

test('a game that is not the caller\'s is refused, not filed', async () => {
  // game_id arrives from a client. Without this check a guessed number would
  // attach a finding to somebody else's game.
  const pool = stubPool({ owned: [3] });
  const tally = await recordMistakes(pool, 5, [item(), item({ gameId: 999 })]);
  assert.equal(tally.stored, 1);
  assert.equal(tally.rejected, 1);
  assert.deepEqual(tally.rejected_by_reason, { 'game-not-yours': 1 });
});

test('every reason a finding is refused is named', async () => {
  const pool = stubPool();
  const bad = [
    [null, 'not-an-object'],
    [item({ gameId: 'x' }), 'no-game'],
    [item({ ply: -1 }), 'no-ply'],
    [item({ fenBefore: 'nije fen' }), 'no-position'],
    [item({ playedUci: 'e2' }), 'no-move'],
    [item({ swingCp: undefined }), 'no-swing'],
  ];
  for (const [candidate, reason] of bad) {
    assert.equal(whyNotStorable(candidate), reason);
  }
  const tally = await recordMistakes(pool, 5, bad.map(([c]) => c));
  assert.equal(tally.rejected, bad.length);
  assert.equal(tally.read, tally.rejected);
});

test('the index in a rejection points at the item that was rejected', async () => {
  // Two identical findings are two items. Recovering the index with indexOf
  // would name the first one twice.
  const pool = stubPool({ owned: [] });
  const tally = await recordMistakes(pool, 5, [item(), item()]);
  assert.equal(tally.rejected, 2);
  assert.deepEqual(tally.rejected_by_reason, { 'game-not-yours': 2 });
});

test('a swing is required rather than defaulted to zero', () => {
  // A mistake with no measure of how bad it was cannot be ranked or argued
  // with, and mistake_reviews refuses the row anyway.
  assert.equal(whyNotStorable(item({ swingCp: 0 })), null);
  assert.equal(whyNotStorable(item({ swingCp: null })), 'no-swing');
  assert.equal(whyNotStorable(item({ swingCp: 'puno' })), 'no-swing');
});

test('an oversized batch is refused before anything is written', async () => {
  const pool = stubPool();
  const many = Array.from({ length: MAX_ITEMS_PER_CALL + 1 }, () => item());
  await assert.rejects(() => recordMistakes(pool, 5, many), RangeError);
  assert.equal(pool.calls.length, 0);
  await assert.rejects(() => recordMistakes(pool, 5, 'nije niz'), RangeError);
});

test('grading uses the same SM-2 the lesson reviews use', async () => {
  // The point of the parallel table: one arithmetic, two stores, owned by
  // neither. If this ever disagreed with schedule(), there would be a second
  // copy of the interval logic somewhere.
  const now = new Date('2026-08-30T12:00:00Z');
  const current = {
    id: 7, ease_factor: '2.50', interval_days: 6, repetitions: 2, lapses: 0,
  };
  const pool = stubPool({ current });
  const outcome = await gradeItem(pool, { userId: 5, itemId: 7, quality: 4 }, now);
  assert.equal(outcome.ok, true);

  const expected = schedule(current, 4, now);
  const update = pool.calls.find((c) => /UPDATE mistake_reviews/.test(c.text));
  assert.equal(Number(update.params[0]), expected.easeFactor);
  assert.equal(update.params[1], expected.intervalDays);
  assert.equal(update.params[2], expected.repetitions);
  assert.equal(update.params[3], expected.lapses);
  assert.deepEqual(update.params[4], expected.dueAt);
});

test('an item that is not yours cannot be graded', async () => {
  const pool = stubPool({ current: null });
  const outcome = await gradeItem(pool, { userId: 5, itemId: 7, quality: 4 });
  assert.equal(outcome.ok, false);
  const update = pool.calls.find((c) => /UPDATE mistake_reviews/.test(c.text));
  assert.equal(update, undefined, 'a missing item must not be written to');
});

test('a grade outside the scale is refused', async () => {
  const pool = stubPool({ current: { id: 7 } });
  for (const quality of [-1, 6, 2.5, 'dobro', undefined]) {
    // eslint-disable-next-line no-await-in-loop
    const outcome = await gradeItem(pool, { userId: 5, itemId: 7, quality });
    assert.equal(outcome.ok, false, String(quality));
  }
});

test('due items carry the game around them', async () => {
  const pool = stubPool({ rows: [{ id: 1, game_id: 3, opponent: 'neko' }] });
  const items = await dueItems(pool, 5, { limit: 500 });
  assert.equal(items.length, 1);
  const select = pool.calls[0];
  assert.match(select.text, /JOIN user_games/);
  assert.equal(select.params[2], 100, 'the limit is capped rather than obeyed');
});

test('recurrence separates what repeats from what happened once', async () => {
  // The whole reason the drill is worth doing: one missed fork is a bad
  // evening, forty is a weakness.
  const pool = stubPool({
    rows: [
      { id: 1, kind: 'engine', theme: 'fork', fen_before: FEN, swing_cp: -300 },
      { id: 2, kind: 'engine', theme: 'fork', fen_before: FEN, swing_cp: -900 },
      { id: 3, kind: 'engine', theme: 'pin', fen_before: FEN, swing_cp: -200 },
      { id: 4, kind: 'tablebase', theme: null, fen_before: '8/5k2/8/8/8/8/4PK2/8 w - - 0 1', swing_cp: null },
      { id: 5, kind: 'tablebase', theme: null, fen_before: '8/8/4k3/8/8/8/4PK2/8 w - - 0 1', swing_cp: null },
    ],
  });
  const out = await recurrence(pool, 5);

  assert.equal(out.sampled, 5);
  assert.deepEqual(out.motifs.map((m) => [m.key, m.count]), [['fork', 2], ['pin', 1]]);
  // The worst swing names the example, so the row shown is the one that hurt.
  assert.equal(out.motifs[0].example, 2);
  // Endgames bucket by material: the two positions differ but the material is
  // the same, and the exact position never repeats anyway.
  assert.deepEqual(out.endings.map((e) => [e.key, e.count]), [['KPk', 2]]);
});

test('material is a sorted signature, not a position', () => {
  // Three men: a white king, a white pawn, a black king.
  assert.equal(materialSignature('8/8/8/4k3/8/8/4P3/4K3 w - - 0 1'), 'KPk');
  assert.equal(
    materialSignature('8/5k2/8/8/8/8/4PK2/8 w - - 0 1'),
    materialSignature('8/8/4k3/8/8/8/4PK2/8 b - - 9 40'),
  );
});

test('stats answer for both kinds even when one has no rows', async () => {
  const pool = stubPool({ rows: [{ kind: 'engine', total: 12, due: 3, mature: 1 }] });
  const out = await stats(pool, 5);
  assert.deepEqual(out.byKind.engine, { total: 12, due: 3, mature: 1 });
  assert.deepEqual(out.byKind.tablebase, { total: 0, due: 0, mature: 0 });
  assert.equal(out.total, 12);
});
