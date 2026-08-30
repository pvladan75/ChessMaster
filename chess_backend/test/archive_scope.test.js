// archive_scope.test.js — that an opponent's games stay out of the player's own.
//
// `user_games` holds two kinds of row under one `user_id`: the player's own
// archive, and — from section 7 — an opponent's, pulled to prepare for a match.
// Only `subject_is_owner` tells them apart, so every query that answers a
// question *about the player* has to say so, and a query that forgets returns
// a bigger, wrong, entirely plausible answer.
//
// The stub pool below is deliberately not a mock that says yes. It reads the
// statement it is handed and applies `subject_is_owner = TRUE` **only when the
// statement asked for it** — so a query that drops the condition really does
// see the opponent's row, and the assertion really does fail. Every test here
// was proved by removing the condition from the code under test and watching it
// go red.

const test = require('node:test');
const assert = require('node:assert/strict');

const { ownGameIds, isOwnSubject } = require('../services/archiveScope');
const { recordMistakes } = require('../services/mistakeReviews');
const { createArchiveImporter } = require('../services/gameArchiveImport');

const FEN = '8/8/8/4k3/8/8/4P3/4K3 w - - 0 1';

/// Two rows: one the player's own, one an opponent's, both under user 1.
const GAMES = [
  { id: 3, user_id: 1, subject: 'me', subject_is_owner: true, min_men: 5 },
  { id: 9, user_id: 1, subject: 'rival', subject_is_owner: false, min_men: 5 },
];

/// A pool that behaves like Postgres rather than like an expectation.
function stubPool({ games = GAMES } = {}) {
  const calls = [];
  const query = async (text, params = []) => {
    const flat = text.replace(/\s+/g, ' ').trim();
    calls.push({ text: flat, params });

    // The condition is honoured only if the statement contains it. That is what
    // makes forgetting it visible instead of harmless.
    //
    // Spelled out here rather than read from `OWN_GAMES_SQL` **on purpose**.
    // Importing the constant would make this stub agree with whatever the
    // constant happens to say, so blanking it to `TRUE` would blank the
    // detector too and every test below would still pass. That is exactly what
    // happened on the first draft, and it is the reason this file says the
    // predicate twice.
    const scoped = /subject_is_owner\s*=\s*TRUE/i.test(flat);
    const visible = games.filter((g) => (scoped ? g.subject_is_owner : true));

    if (/SELECT id FROM user_games/.test(flat)) {
      const asked = (params[1] || []).map(Number);
      const mine = visible.filter((g) => asked.includes(g.id));
      return { rows: mine.map((g) => ({ id: String(g.id) })), rowCount: mine.length };
    }
    if (/SELECT 1 FROM user_games/.test(flat)) {
      const mine = visible.filter((g) => g.subject === params[1]);
      return { rows: mine.map(() => ({ '?column?': 1 })), rowCount: mine.length };
    }
    if (/COUNT\(\*\)::int AS games/.test(flat)) {
      return {
        rows: [{
          games: visible.length, with_clocks: 0, reached_tablebase: visible.length,
          subjects: new Set(visible.map((g) => g.subject)).size,
          oldest: null, newest: null, plies: 0,
        }],
        rowCount: 1,
      };
    }
    if (/INSERT INTO mistake_reviews/.test(flat)) {
      const offered = params.length / 9;
      return {
        rows: Array.from({ length: offered }, (_, i) => ({ id: i + 1 })),
        rowCount: offered,
      };
    }
    return { rows: [], rowCount: 0 };
  };
  return { calls, query };
}

test('ownGameIds keeps the player\'s own game and drops the opponent\'s', async () => {
  const pool = stubPool();
  const mine = await ownGameIds(pool, 1, [3, 9]);

  assert.equal(mine.has('3'), true, 'the player\'s own game is theirs');
  assert.equal(mine.has('9'), false, 'an opponent archive row is not');
  assert.equal(mine.size, 1);
});

test('ownGameIds normalises bigint ids, which arrive as strings', async () => {
  const pool = stubPool();
  // `pg` returns `bigint` as a string, and callers hold either. Both forms of
  // the same id must answer the same way or the check is a coin toss.
  const fromNumbers = await ownGameIds(pool, 1, [3]);
  const fromStrings = await ownGameIds(pool, 1, ['3']);

  assert.deepEqual([...fromNumbers], [...fromStrings]);
  assert.deepEqual([...fromNumbers], ['3']);
});

test('ownGameIds asks nothing of the database for an empty list', async () => {
  const pool = stubPool();
  const mine = await ownGameIds(pool, 1, []);

  assert.equal(mine.size, 0);
  assert.equal(pool.calls.length, 0, 'an empty batch is not a round trip');
});

test('isOwnSubject separates the player from the opponent they prepared for', async () => {
  const pool = stubPool();

  assert.equal(await isOwnSubject(pool, 1, 'me'), true);
  assert.equal(await isOwnSubject(pool, 1, 'rival'), false);
  assert.equal(await isOwnSubject(pool, 1, '   '), false, 'a blank handle is nobody');
});

test('a mistake out of an opponent\'s game is refused, not drilled', async () => {
  // The path that matters most: without the owner condition this is stored,
  // and then ranked in the player's recurrence report as their own weakness.
  const pool = stubPool();
  const tally = await recordMistakes(pool, 1, [
    { gameId: 3, ply: 41, fenBefore: FEN, playedUci: 'e2e4', bestUci: 'e1d2', swingCp: -320 },
    { gameId: 9, ply: 41, fenBefore: FEN, playedUci: 'e2e4', bestUci: 'e1d2', swingCp: -320 },
  ]);

  assert.equal(tally.stored, 1, 'only the player\'s own game is stored');
  assert.equal(tally.rejected, 1);
  assert.deepEqual(
    tally.rejected_by_reason, { 'game-not-yours': 1 },
    'the opponent\'s game is refused by name, not dropped quietly',
  );
  assert.equal(
    tally.read, tally.stored + tally.duplicate + tally.rejected,
    'and the counters still add up',
  );
});

test('the archive summary counts the player\'s games and not their opponent\'s', async () => {
  const pool = stubPool();
  const importer = createArchiveImporter({ pool });
  const summary = await importer.archiveStats(1);

  assert.equal(summary.games, 1, '"your archive has N games" means yours');
  assert.equal(summary.subjects, 1);
});

test('the condition is written in one place and imported everywhere else', async () => {
  // The same guard `acceptedTrainersOf` has, for the same reason: three
  // hand-written copies of that subquery all forgot the status. A fourth copy
  // of this one would forget something too, and nothing else would notice.
  const fs = require('node:fs');
  const path = require('node:path');

  const root = path.join(__dirname, '..');
  const offenders = [];
  for (const dir of ['services', 'routes']) {
    for (const name of fs.readdirSync(path.join(root, dir))) {
      if (!name.endsWith('.js') || name === 'archiveScope.js') continue;
      const source = fs.readFileSync(path.join(root, dir, name), 'utf8');
      // Interpolating the shared constant is the sanctioned form; spelling the
      // predicate out again is not.
      const spelledOut = source.replace(/\$\{OWN_GAMES_SQL\}/g, '');
      if (/subject_is_owner\s*=\s*TRUE/i.test(spelledOut)) {
        offenders.push(`${dir}/${name}`);
      }
    }
  }

  assert.deepEqual(
    offenders, [],
    `hand-written copies of the own-games condition: ${offenders.join(', ')} — import OWN_GAMES_SQL instead`,
  );
});
