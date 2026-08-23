const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const {
  ONLINE_SOURCE_DB, isOnlineSource, excludeOnlineClause,
} = require('../services/endgameSources');

test('the master bases are over-the-board, not online', () => {
  // Forty-three single-player bases plus the OTB gigabase are one pool: games
  // played at a board, by people whose rating means what it usually means.
  assert.equal(isOnlineSource('Carlsen.pgn'), false);
  assert.equal(isOnlineSource('LumbrasGigaBase_OTB_Complete.pgn'), false);
  assert.equal(isOnlineSource(ONLINE_SOURCE_DB), true);
});

test('a position with no source at all is not online', () => {
  // Most of the collection came from the miner rather than from a game, and
  // carries no source. It has to survive the filter.
  assert.equal(isOnlineSource(null), false);
  assert.equal(isOnlineSource(undefined), false);
});

test('the filter uses IS DISTINCT FROM, so nulls survive it', () => {
  // The bug this exists to prevent, and it would be silent: `source_db <> '...'`
  // is NULL for every mined position, NULL is not TRUE, and the row vanishes.
  // A trainer would ask for over-the-board endings and be handed a fraction of
  // the collection, with no error anywhere.
  const clause = excludeOnlineClause();
  assert.match(clause, /IS DISTINCT FROM/);
  assert.doesNotMatch(clause, /<>/);
  assert.doesNotMatch(clause, /!=/);
  assert.ok(clause.includes(ONLINE_SOURCE_DB));
});

test('the column can be named, so both tables can use one rule', () => {
  // endgame_puzzles and blunder_games both record where a row came from, and
  // the walk needs the same filter as the trainer.
  assert.match(excludeOnlineClause('g.source_db'), /^g\.source_db /);
});

test('only one file knows what the online base is called', () => {
  // Same guard as the one over acceptedTrainersOf: the name written a second
  // time is a name that will disagree with the first after the next rename.
  const root = path.join(__dirname, '..');
  const skip = new Set(['node_modules', 'uploads', 'exports', '.git', 'test']);
  const offenders = [];

  const walk = (dir) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      if (skip.has(entry.name)) continue;
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(full);
      } else if (entry.isFile() && entry.name.endsWith('.js')) {
        if (full.endsWith(path.join('services', 'endgameSources.js'))) continue;
        if (fs.readFileSync(full, 'utf8').includes(ONLINE_SOURCE_DB)) {
          offenders.push(path.relative(root, full));
        }
      }
    }
  };
  walk(root);

  assert.deepEqual(offenders, [],
    `ime online baze je prepisano u: ${offenders.join(', ')}`);
});
