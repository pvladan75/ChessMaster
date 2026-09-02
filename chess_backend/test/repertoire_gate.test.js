const test = require('node:test');
const assert = require('node:assert/strict');
const { Chess } = require('chess.js');

const { frontier, gateMoves } = require('../services/repertoireFrontier');
const { tree, drillBranches } = require('../services/repertoireLine');
const {
  createRepertoire, setGate, fenKey,
} = require('../services/repertoireService');

/// The Italian after 1.e4 e5 2.Nf3 Nc6 3.Bc4 Bc5 — White to move, and the
/// position this whole feature came from. Two repertoires start here: one plays
/// 4.b4 (the Evans), the other 4.0-0, and until the gate existed the second
/// one's tree showed the first one's opening.
const ITALIAN = ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'f8c5'];

function after(...ucis) {
  const board = new Chess();
  for (const uci of ucis) {
    board.move({ from: uci.slice(0, 2), to: uci.slice(2, 4) });
  }
  return board.fen();
}

function keyAfter(...ucis) {
  return fenKey(after(...ucis));
}

const ROOT = after(...ITALIAN);
const ROOT_KEY = fenKey(ROOT);

/// Both openings, kept in one graph — which is where they belong, and the whole
/// reason the view needs a gate.
const BOTH = {
  moves: [
    { fen_key: ROOT_KEY, uci: 'b2b4', san: 'b4', role: 'primary', source: 'chosen' },
    { fen_key: ROOT_KEY, uci: 'e1g1', san: 'O-O', san_alt: '0-0', role: 'alternate', source: 'chosen' },
    // One decision inside each opening, so each has something below it.
    {
      fen_key: keyAfter(...ITALIAN, 'b2b4', 'c5b4'),
      uci: 'c2c3', san: 'c3', role: 'primary', source: 'chosen',
    },
    {
      fen_key: keyAfter(...ITALIAN, 'e1g1', 'g8f6'),
      uci: 'd2d3', san: 'd3', role: 'primary', source: 'chosen',
    },
  ],
  replies: [
    {
      fen_key: keyAfter(...ITALIAN, 'b2b4'),
      uci: 'c5b4', san: 'Bxb4', games: 800, share: '0.80000',
    },
    {
      fen_key: keyAfter(...ITALIAN, 'e1g1'),
      uci: 'g8f6', san: 'Nf6', games: 700, share: '0.70000',
    },
  ],
};

function stubPool({ moves = [], replies = [], skips = [], reviews = [] } = {}) {
  return {
    query: async (text, params) => {
      const flat = text.replace(/\s+/g, ' ').trim();
      const rows = (() => {
        if (flat.includes('SELECT fen_key, uci, san, role')) return moves;
        if (flat.includes('FROM repertoire_skips')) {
          return skips.map((fen_key) => ({ fen_key }));
        }
        if (flat.includes('FROM opening_replies')) {
          const [band, keys] = params;
          return replies.filter(
            (r) => Number(r.min_rating ?? 0) === band && keys.includes(r.fen_key));
        }
        if (flat.includes('SELECT fen_key, due_at, repetitions')) {
          const within = params[2];
          return reviews.filter((row) => within.includes(row.fen_key));
        }
        throw new Error(`Neočekivan upit: ${flat}`);
      })();
      return { rows, rowCount: rows.length };
    },
  };
}

test('the gate narrows the root and touches nothing else', () => {
  // One function, applied to the map the whole walk reads. That is why one
  // filter reaches the queue, the picture, the map and the drill at once.
  const kept = new Map([
    [ROOT_KEY, [{ uci: 'b2b4' }, { uci: 'e1g1' }]],
    ['other', [{ uci: 'd2d4' }]],
  ]);
  gateMoves(kept, ROOT_KEY, 'e1g1');

  assert.deepEqual(kept.get(ROOT_KEY).map((m) => m.uci), ['e1g1']);
  assert.deepEqual(kept.get('other').map((m) => m.uci), ['d2d4']);
});

test('a gate whose move is not kept leaves the position undecided', () => {
  // Rather than leaving it untouched, which would silently show the other
  // opening. "You have not decided this position yet" is exactly true of a
  // repertoire whose first move has not been kept.
  const kept = new Map([[ROOT_KEY, [{ uci: 'b2b4' }]]]);
  gateMoves(kept, ROOT_KEY, 'e1g1');

  assert.deepEqual(kept.get(ROOT_KEY), []);
});

test('the tree draws one opening, not both', async () => {
  // The owner's own words: while working on the 0-0 repertoire, 4.b4 and
  // everything under it must not be on the picture.
  const pool = stubPool(BOTH);
  const drawn = await tree(pool, 7, {
    color: 'w', rootFen: ROOT, gateUci: 'e1g1',
  });

  assert.deepEqual(drawn.children.map((c) => c.uci), ['e1g1']);
  // And the reply under it is still there — the gate narrows the root, not the
  // depth.
  assert.deepEqual(drawn.children[0].children.map((c) => c.san), ['Nf6']);
});

test('without a gate the tree is what it always was', async () => {
  // Every repertoire made before this column has no gate, and must not change.
  const pool = stubPool(BOTH);
  const drawn = await tree(pool, 7, { color: 'w', rootFen: ROOT });

  assert.deepEqual(drawn.children.map((c) => c.uci).sort(),
    ['b2b4', 'e1g1'].sort());
});

test('the queue asks only about the gated opening', async () => {
  // The frontier is what the build screen walks. With the gate on 0-0, no
  // position under 4.b4 may be in it — that is the "clean view" the whole
  // feature is for.
  const pool = stubPool(BOTH);
  const walk = await frontier(pool, 7, {
    color: 'w', rootFen: ROOT, gateUci: 'e1g1',
  });

  const reached = [...walk.open, ...walk.pruned].map((node) => node.path.join(' '));
  assert.equal(reached.some((line) => line.startsWith('b4')), false,
    'red sadrži poziciju iz druge grane');
  assert.ok(walk.branches.every((branch) => branch.path[0] === 'O-O'),
    'tabla grana sadrži granu koja ne ide kroz kapiju');
});

test('the branch list is one opening too', async () => {
  const pool = stubPool(BOTH);
  const listed = await drillBranches(pool, 7, {
    color: 'w', rootFen: ROOT, gateUci: 'e1g1',
  });

  assert.deepEqual(listed.branches.map((b) => b.san), ['O-O Nf6']);
});

/// A pool for the two service functions that write the gate.
function writePool({ rows = [], onWrite = () => {} } = {}) {
  return {
    written: [],
    query: async function query(text, params) {
      const flat = text.replace(/\s+/g, ' ').trim();
      if (flat.startsWith('SELECT root_fen FROM repertoires')) {
        return { rows, rowCount: rows.length };
      }
      if (flat.startsWith('UPDATE repertoires')) {
        onWrite(params);
        return { rows: [{ id: params[0], via_uci: params[2] }], rowCount: 1 };
      }
      if (flat.startsWith('INSERT INTO repertoires')) {
        onWrite(params);
        return {
          rows: [{
            id: 1,
            name: params[1],
            color: params[2],
            root_fen: params[3],
            root_path: params[4],
            via_uci: params[5],
          }],
          rowCount: 1,
        };
      }
      throw new Error(`Neočekivan upit: ${flat}`);
    },
  };
}

test('a gate that cannot be played in that position is refused', async () => {
  // Loud, not stored. A gate that matches nothing is a repertoire that opens on
  // an empty tree with no sentence anywhere saying why — the silent failure
  // this codebase keeps meeting.
  const pool = writePool();
  await assert.rejects(
    () => createRepertoire(pool, 7, {
      name: 'Italijanka', color: 'w', rootFen: ROOT, viaUci: 'a1a8',
    }),
    RangeError,
  );
});

test('a legal gate is stored, and comes back as a move you can read',
  async () => {
    const written = [];
    const pool = writePool({ onWrite: (params) => written.push(params) });
    const made = await createRepertoire(pool, 7, {
      name: 'Italijanka — rokada', color: 'w', rootFen: ROOT, viaUci: 'e1g1',
    });

    assert.equal(made.viaUci, 'e1g1');
    // "O-O", not "e1g1": the server has the board, the client would need one.
    assert.equal(made.viaSan, 'O-O');
    assert.equal(written[0][5], 'e1g1');
  });

test('the gate can be set on a repertoire that already exists, and cleared',
  async () => {
    // The repertoires that most need a gate are the ones built before the
    // column was.
    const pool = writePool({ rows: [{ root_fen: ROOT }] });
    const set = await setGate(pool, 7, { id: 4, viaUci: 'b2b4' });
    assert.equal(set.viaUci, 'b2b4');
    assert.equal(set.viaSan, 'b4');

    const cleared = await setGate(pool, 7, { id: 4, viaUci: null });
    assert.equal(cleared.viaUci, null);
    assert.equal(cleared.viaSan, null);
  });

test('a repertoire that is not yours cannot be gated', async () => {
  const pool = writePool({ rows: [] });
  await assert.rejects(() => setGate(pool, 7, { id: 4, viaUci: 'b2b4' }),
    RangeError);
});
