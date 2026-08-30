// repertoire_archive.test.js — the seed that must not overwrite, and the diff
// that must not silently find nothing.

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  seedFromArchive, repertoireDiff, playedMoves, uciOf,
  DEFAULT_MIN_GAMES,
} = require('../services/repertoireArchive');
const { fenKey } = require('../services/gameArchive');

const START = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const START_KEY = fenKey(START);
// After 1.e4, Black to move.
const AFTER_E4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq -';

function nodeRow(over = {}) {
  return {
    fen_key: START_KEY, color: 'w', san: 'e4', games: 40, ply: 1, ...over,
  };
}

/// Answers by reading the statement, and records every write.
function stubPool({ nodes = [], diff = [], hasPrimary = () => false } = {}) {
  const calls = [];
  const inserted = [];
  const query = async (text, params = []) => {
    const flat = text.replace(/\s+/g, ' ').trim();
    calls.push({ text: flat, params });
    if (/FROM opening_nodes WHERE user_id/.test(flat)) {
      return { rows: nodes, rowCount: nodes.length };
    }
    if (/WITH covered AS/.test(flat)) return { rows: diff, rowCount: diff.length };
    if (/SELECT 1 FROM repertoire_moves/.test(flat)) {
      const already = hasPrimary(params[2]);
      return { rows: already ? [{ 1: 1 }] : [], rowCount: already ? 1 : 0 };
    }
    if (/INSERT INTO repertoire_moves/.test(flat)) {
      const row = {
        uci: params[3], san: params[4], role: params[5], verdict: params[6],
      };
      inserted.push(row);
      return { rows: [row], rowCount: 1 };
    }
    return { rows: [], rowCount: 0 };
  };
  return { calls, inserted, query };
}

test('a SAN becomes the UCI the repertoire stores', () => {
  assert.equal(uciOf(START_KEY, 'e4'), 'e2e4');
  assert.equal(uciOf(START_KEY, 'Nf3'), 'g1f3');
  // A move that does not fit its own position is not guessed at.
  assert.equal(uciOf(START_KEY, 'Qh5xf7'), null);
  assert.equal(uciOf(START_KEY, 'nonsense'), null);
});

test('positions below the floor are not part of a repertoire', async () => {
  const pool = stubPool({
    nodes: [
      nodeRow({ games: 40 }),
      nodeRow({ fen_key: AFTER_E4, color: 'b', san: 'e5', games: 2 }),
    ],
  });
  const positions = await playedMoves(pool, 5, {
    subject: 's', color: null, minGames: DEFAULT_MIN_GAMES,
  });
  assert.equal(positions.length, 1);
  assert.equal(positions[0].fenKey, START_KEY);
});

test('a dry run plans and writes nothing', async () => {
  const pool = stubPool({ nodes: [nodeRow()] });
  const out = await seedFromArchive(pool, 5, { subject: 's', dryRun: true });
  assert.equal(out.dryRun, true);
  assert.equal(out.moves, 1);
  assert.deepEqual(out.plan[0].uci, 'e2e4');
  assert.equal(pool.inserted.length, 0);
  assert.equal(pool.calls.filter((c) => /INSERT/.test(c.text)).length, 0);
});

test('a rare second answer is not a repertoire choice', async () => {
  // 38 of 40 games is a decision; 2 of 40 is a slip, and putting it in the
  // repertoire would mean drilling a move the player does not actually play.
  const pool = stubPool({
    nodes: [
      nodeRow({ san: 'e4', games: 38 }),
      nodeRow({ san: 'd4', games: 2 }),
    ],
  });
  const out = await seedFromArchive(pool, 5, { subject: 's', dryRun: true });
  assert.deepEqual(out.plan.map((m) => m.san), ['e4']);
});

test('a real second answer is kept, and only so many of them', async () => {
  const pool = stubPool({
    nodes: [
      nodeRow({ san: 'e4', games: 20 }),
      nodeRow({ san: 'd4', games: 15 }),
      nodeRow({ san: 'c4', games: 10 }),
      nodeRow({ san: 'Nf3', games: 8 }),
    ],
  });
  const out = await seedFromArchive(pool, 5, { subject: 's', dryRun: true });
  assert.deepEqual(out.plan.map((m) => m.san), ['e4', 'd4', 'c4']);
});

test('the seed never demotes a decision the player already made', async () => {
  // addMove makes the first move into a position primary and every later one an
  // alternate. A seed that overwrote a hand-built repertoire would be the worst
  // possible way to introduce this feature, so it goes through that function
  // rather than inserting a role of its own.
  const pool = stubPool({
    nodes: [nodeRow({ san: 'e4', games: 40 }), nodeRow({ san: 'd4', games: 20 })],
    hasPrimary: () => true,
  });
  const out = await seedFromArchive(pool, 5, { subject: 's' });
  assert.equal(out.added, 2);
  assert.equal(out.primary, 0, 'an existing primary must survive the seed');
  assert.deepEqual(pool.inserted.map((r) => r.role), ['alternate', 'alternate']);
});

test('an empty position takes the primary', async () => {
  const pool = stubPool({ nodes: [nodeRow()], hasPrimary: () => false });
  const out = await seedFromArchive(pool, 5, { subject: 's' });
  assert.equal(out.primary, 1);
  assert.equal(pool.inserted[0].role, 'primary');
  assert.equal(pool.inserted[0].uci, 'e2e4');
});

test('two moves into one position are never written at the same time', async () => {
  // addMove decides primary versus alternate by looking for an existing
  // primary. Two moves into the same position at once would both find none,
  // both insert a primary, and the partial unique index would refuse the
  // second — failing a seed halfway through for a reason that has nothing to do
  // with the player. Positions may go in parallel; the moves inside one may not.
  const active = new Set();
  let clash = false;
  const pool = {
    calls: [],
    query: async (text, params = []) => {
      const flat = text.replace(/\s+/g, ' ').trim();
      if (/FROM opening_nodes/.test(flat)) {
        return {
          rows: [
            nodeRow({ fen_key: START_KEY, san: 'e4', games: 20 }),
            nodeRow({ fen_key: START_KEY, san: 'd4', games: 15 }),
            nodeRow({ fen_key: AFTER_E4, color: 'b', san: 'e6', games: 30 }),
            nodeRow({ fen_key: AFTER_E4, color: 'b', san: 'c5', games: 12 }),
          ],
          rowCount: 4,
        };
      }
      const key = `${params[1]}|${params[2]}`;
      if (/SELECT 1 FROM repertoire_moves/.test(flat)) {
        if (active.has(key)) clash = true;
        active.add(key);
        await new Promise((resolve) => { setTimeout(resolve, 1); });
        return { rows: [], rowCount: 0 };
      }
      if (/INSERT INTO repertoire_moves/.test(flat)) {
        active.delete(key);
        return { rows: [{ role: 'primary' }], rowCount: 1 };
      }
      return { rows: [], rowCount: 0 };
    },
  };

  const out = await seedFromArchive(pool, 5, { subject: 's' });
  assert.equal(out.added, 4);
  assert.equal(clash, false, 'two moves into one position overlapped');
});

test('a node whose move will not replay is counted, not dropped', async () => {
  // The number being above zero is a bug report about the importer, and it can
  // only be that if somebody keeps it.
  const pool = stubPool({ nodes: [nodeRow({ san: 'Qxz9' })] });
  const out = await seedFromArchive(pool, 5, { subject: 's', dryRun: true });
  assert.equal(out.unplayable, 1);
  assert.equal(out.moves, 0);
});

test('the diff separates following the plan from leaving it', async () => {
  const pool = stubPool({
    diff: [
      { fen_key: AFTER_E4, color: 'b', san: 'e6', in_repertoire: true, games: 90, points: '45.0', ply: 2 },
      { fen_key: AFTER_E4, color: 'b', san: 'c5', in_repertoire: false, games: 18, points: '6.0', ply: 2 },
      { fen_key: AFTER_E4, color: 'b', san: 'd5', in_repertoire: false, games: 10, points: '3.0', ply: 2 },
    ],
  });
  const out = await repertoireDiff(pool, 5, { subject: 's' });

  assert.equal(out.coveredGames, 118);
  assert.equal(out.followedGames, 90);
  assert.equal(out.leftGames, 28);
  assert.equal(out.positions.length, 1);

  const position = out.positions[0];
  assert.equal(position.leftGames, 28);
  assert.deepEqual(position.prepared.map((m) => m.san), ['e6']);
  // Most-abandoned first, so the row shows the habit rather than the exception.
  assert.deepEqual(position.played.map((m) => m.san), ['c5', 'd5']);
  assert.ok(Math.abs(position.played[0].score - 6 / 18) < 1e-9);
  assert.equal(position.fen.endsWith(' 0 1'), true);
});

test('every move in the diff carries a uci the drill can actually play', async () => {
  // The diff exists to hand positions to the drill, and a drill plays a move in
  // the notation a board takes. Deriving it in the client would mean a second
  // replay of the same position in a second chess library, with its own opinion
  // about an ambiguous SAN — and the two would disagree silently, on exactly
  // the positions that are hardest to read. Found by the agent building the
  // screen: the seed plan carried `uci` and this did not.
  const pool = stubPool({
    diff: [
      { fen_key: AFTER_E4, color: 'b', san: 'e6', in_repertoire: true, games: 90, points: '45.0', ply: 2 },
      { fen_key: AFTER_E4, color: 'b', san: 'c5', in_repertoire: false, games: 18, points: '6.0', ply: 2 },
    ],
  });
  const out = await repertoireDiff(pool, 5, { subject: 's' });
  const position = out.positions[0];

  assert.equal(position.prepared[0].uci, 'e7e6');
  assert.equal(position.played[0].uci, 'c7c5');
  assert.equal(out.unplayable, 0);
});

test('a diff move that will not replay is counted rather than hidden', async () => {
  // Above zero is a bug report, not a statistic: the node was written wrong.
  // Same rule as the seed, and the reason both report the number.
  const pool = stubPool({
    diff: [
      { fen_key: AFTER_E4, color: 'b', san: 'Qh8', in_repertoire: false, games: 4, points: '1.0', ply: 2 },
    ],
  });
  const out = await repertoireDiff(pool, 5, { subject: 's' });

  assert.equal(out.unplayable, 1);
  assert.equal(out.positions[0].played[0].uci, null, 'null, not a guess');
});

test('a position that was always followed is not a deviation', async () => {
  const pool = stubPool({
    diff: [
      { fen_key: AFTER_E4, color: 'b', san: 'e6', in_repertoire: true, games: 90, points: '45.0', ply: 2 },
    ],
  });
  const out = await repertoireDiff(pool, 5, { subject: 's' });
  assert.equal(out.followedGames, 90);
  assert.equal(out.leftGames, 0);
  assert.equal(out.positions.length, 0);
});

test('the diff joins on the same key the repertoire uses', async () => {
  // If these two ever spelled the key differently the diff would not error - it
  // would come back empty, which reads as "you never left your repertoire".
  const pool = stubPool();
  await repertoireDiff(pool, 5, { subject: 's' });
  const sql = pool.calls[0].text;
  assert.match(sql, /c\.fen_key = n\.fen_key AND c\.color = n\.subject_color/);
  assert.match(sql, /r\.fen_key = n\.fen_key AND r\.san = n\.san/);
});

test('a missing handle or a colour that is not a colour is refused', async () => {
  const pool = stubPool();
  await assert.rejects(() => repertoireDiff(pool, 5, { subject: ' ' }), RangeError);
  await assert.rejects(
    () => seedFromArchive(pool, 5, { subject: 's', color: 'white' }), RangeError,
  );
  assert.equal(pool.calls.length, 0);
});
