const test = require('node:test');
const assert = require('node:assert/strict');
const { Chess } = require('chess.js');

const { playAlternative } = require('../services/repertoireAlternative');
const { fenKey } = require('../services/repertoireService');

const START = new Chess().fen();

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

/// A pool that records the order it was asked things in.
///
/// The order is the point of most of these tests: this service's whole subtlety
/// is *when* the walk happens relative to the write, and a stub that only
/// answered queries could not tell a correct implementation from one that asks
/// the two questions the wrong way round.
function stubPool({
  moves = [], replies = [], roots = [START], counts = {}, source = 'auto',
  missing = false,
} = {}) {
  const calls = [];
  const deleted = [];
  const query = async (text, params) => {
    const flat = text.replace(/\s+/g, ' ').trim();
    calls.push({ text: flat, params });
    if (flat.startsWith('SELECT source FROM repertoire_moves')) {
      return missing
        ? { rows: [], rowCount: 0 }
        : { rows: [{ source }], rowCount: 1 };
    }
    if (flat.startsWith('SELECT 1 FROM repertoire_moves')) {
      return { rows: [], rowCount: 0 };
    }
    if (flat.startsWith('INSERT INTO repertoire_moves')) {
      const [, , , uci, san, role] = params;
      return {
        rows: [{ uci, san, role, verdict: null, source: 'chosen' }],
        rowCount: 1,
      };
    }
    if (flat.includes('FROM repertoires WHERE user_id')) {
      const rows = roots.map((root_fen) => ({
        root_fen, via_uci: null, breadth: 'standard',
      }));
      return { rows, rowCount: rows.length };
    }
    if (flat.includes('SELECT fen_key, uci, san, role, source')) {
      return { rows: moves, rowCount: moves.length };
    }
    if (flat.includes('FROM opening_replies')) {
      const [band, keys] = params;
      const rows = replies
        .filter((r) => Number(r.min_rating ?? 0) === band
          && keys.includes(r.fen_key))
        .map((r) => ({ covered: true, asked: false, ...r }));
      return { rows, rowCount: rows.length };
    }
    if (flat.includes('AS drafts')) {
      return {
        rows: [{ drafts: counts.drafts ?? 0, decisions: counts.decisions ?? 0 }],
        rowCount: 1,
      };
    }
    if (flat.startsWith('DELETE FROM repertoire_moves')) {
      deleted.push(params);
      return { rows: [], rowCount: counts.removed ?? 1 };
    }
    if (flat.includes("SET role = 'primary' WHERE id IN")) {
      return { rows: [], rowCount: 0 };
    }
    if (flat.includes("SET role = 'alternate'")
      || flat.includes("SET role = 'primary'")) {
      return { rows: [], rowCount: 1 };
    }
    if (['BEGIN', 'COMMIT', 'ROLLBACK'].includes(flat)) {
      return { rows: [], rowCount: 0 };
    }
    throw new Error(`Neočekivan upit: ${flat}`);
  };
  return {
    calls,
    deleted,
    query,
    connect: async () => ({ query, release: () => {} }),
    /// Where a query first appears in the order things were asked.
    indexOf: (needle) => calls.findIndex((c) => c.text.includes(needle)),
  };
}

/// The spine drafted 1.d4; 1.e4 is what the student plays instead. Black has
/// one reply to each, and they transpose nowhere.
const DRAFTED_D4 = {
  moves: [
    { fen_key: fenKey(START), uci: 'd2d4', san: 'd4', role: 'primary', source: 'auto' },
  ],
  replies: [
    { fen_key: keyAfter('d2d4'), uci: 'd7d5', san: 'd5', games: 500, share: '0.5' },
    { fen_key: keyAfter('e2e4'), uci: 'e7e5', san: 'e5', games: 500, share: '0.5' },
  ],
};

test('the rejected draft goes and the played move takes its place', async () => {
  const pool = stubPool({ ...DRAFTED_D4, counts: { drafts: 2, removed: 2 } });
  const out = await playAlternative(pool, 7, {
    color: 'w', fen: START, uci: 'e2e4', san: 'e4', rejectedUci: 'd2d4',
  });

  assert.equal(out.played.uci, 'e2e4');
  assert.equal(out.played.source, 'chosen');
  assert.equal(out.rejected, 'd2d4');
  // The draft itself, deleted by name.
  assert.ok(pool.deleted.some((p) => p[3] === 'd2d4'));
  // And what it was holding up: the position after 1.d4, and 1.d4 d5.
  const swept = pool.deleted.find((p) => Array.isArray(p[2]));
  assert.deepEqual([...swept[2]].sort(),
    [keyAfter('d2d4'), keyAfter('d2d4', 'd7d5')].sort());
});

test('the move is written before the walk asks what is unreachable', async () => {
  // The whole subtlety of the file. The question is not "what did the old move
  // reach" but "what will nothing reach once the new move is in" — asking in
  // the wrong order deletes work the student's own choice had just made
  // reachable again.
  const pool = stubPool({ ...DRAFTED_D4, counts: { drafts: 2 } });
  await playAlternative(pool, 7, {
    color: 'w', fen: START, uci: 'e2e4', san: 'e4', rejectedUci: 'd2d4',
  });

  const written = pool.indexOf('INSERT INTO repertoire_moves');
  const walked = pool.indexOf('FROM repertoires WHERE user_id');
  assert.ok(written >= 0 && walked >= 0);
  assert.ok(written < walked,
    'the reachability walk ran before the new move was written');
});

test('the position the choice was made in is never swept', async () => {
  // A line that transposes back to where the choice was made puts that key in
  // the orphan set, and the sweep would then delete the move that had just been
  // played — the student's own answer, removed by the tidy-up that was supposed
  // to be about the one they refused.
  //
  // Built with the knights, because it is the shortest true cycle in chess:
  // 1.Nf3 Nf6 2.Ng1 Ng8 is the starting position again, and `fenKey` keeps four
  // fields, so it is the same key. The rejected draft is 1.Nf3 and the walk
  // behind it comes back round to the position it was played from.
  //
  // The root is elsewhere and reaches nothing, so that cycle is the *only* way
  // the key appears — which is what makes this test fail when the guard goes,
  // rather than passing for a reason that has nothing to do with it.
  const cycle = {
    moves: [
      { fen_key: fenKey(START), uci: 'g1f3', san: 'Nf3', role: 'primary', source: 'auto' },
      {
        fen_key: keyAfter('g1f3', 'g8f6'),
        uci: 'f3g1',
        san: 'Ng1',
        role: 'primary',
        source: 'chosen',
      },
    ],
    replies: [
      { fen_key: keyAfter('g1f3'), uci: 'g8f6', san: 'Nf6', games: 500, share: '0.9' },
      {
        fen_key: keyAfter('g1f3', 'g8f6', 'f3g1'),
        uci: 'f6g8',
        san: 'Ng8',
        games: 500,
        share: '0.9',
      },
    ],
    roots: [after('e2e4', 'e7e5')],
    counts: { drafts: 2, removed: 2 },
  };

  const pool = stubPool(cycle);
  await playAlternative(pool, 7, {
    color: 'w', fen: START, uci: 'd2d4', san: 'd4', rejectedUci: 'g1f3',
  });

  const swept = pool.deleted.filter((p) => Array.isArray(p[2]));
  assert.ok(swept.length > 0, 'nothing was swept, so the guard was not reached');
  for (const params of swept) {
    assert.equal(params[2].includes(fenKey(START)), false,
      'the sweep took the position the student had just answered');
  }
  // The rest of the cycle did go — the guard spares one position, not the walk.
  assert.ok(swept.some((p) => p[2].includes(keyAfter('g1f3'))));
});

test('a decision is not a draft, and is refused rather than replaced',
  async () => {
    // A decision changed is a different act with a different confirmation in
    // front of it. Accepting one here would let a wizard about scaffolding
    // delete work the student had already agreed to.
    const pool = stubPool({ ...DRAFTED_D4, source: 'chosen' });
    await assert.rejects(
      playAlternative(pool, 7, {
        color: 'w', fen: START, uci: 'e2e4', san: 'e4', rejectedUci: 'd2d4',
      }),
      /odluka/,
    );
    assert.equal(pool.deleted.length, 0);
    assert.ok(pool.indexOf('ROLLBACK') >= 0);
    assert.equal(pool.indexOf('COMMIT'), -1);
  });

test('a move that is not in the repertoire is refused', async () => {
  const pool = stubPool({ ...DRAFTED_D4, missing: true });
  await assert.rejects(
    playAlternative(pool, 7, {
      color: 'w', fen: START, uci: 'e2e4', san: 'e4', rejectedUci: 'g1f3',
    }),
    /nije u repertoaru/,
  );
  assert.equal(pool.deleted.length, 0);
});

test('rejecting and playing the same move is refused', async () => {
  const pool = stubPool(DRAFTED_D4);
  await assert.rejects(
    playAlternative(pool, 7, {
      color: 'w', fen: START, uci: 'd2d4', san: 'd4', rejectedUci: 'd2d4',
    }),
    /isti/,
  );
});

test('decisions under the rejected draft are counted, not deleted', async () => {
  // Drafts go without asking; a move the student made themselves is handed
  // back as a number so the screen can ask.
  const pool = stubPool({
    ...DRAFTED_D4,
    counts: { drafts: 1, decisions: 3, removed: 1 },
  });
  const out = await playAlternative(pool, 7, {
    color: 'w', fen: START, uci: 'e2e4', san: 'e4', rejectedUci: 'd2d4',
  });

  assert.equal(out.decisions, 3);
  // The sweep carried `includeDecisions = false`, so the three are still there.
  const swept = pool.deleted.find((p) => Array.isArray(p[2]));
  assert.equal(swept[3], false);
});

test('asked to, the sweep takes the decisions too', async () => {
  const pool = stubPool({
    ...DRAFTED_D4,
    counts: { drafts: 1, decisions: 3, removed: 4 },
  });
  await playAlternative(pool, 7, {
    color: 'w', fen: START, uci: 'e2e4', san: 'e4', rejectedUci: 'd2d4',
    includeDecisions: true,
  });

  const swept = pool.deleted.find((p) => Array.isArray(p[2]));
  assert.equal(swept[3], true);
});

test('the two writes commit together or not at all', async () => {
  // Half of this is a repertoire with a decision at the top of a line the
  // student has just said they will not play, and a queue that keeps offering
  // the positions underneath it.
  const pool = stubPool({ ...DRAFTED_D4, counts: { drafts: 2, removed: 2 } });
  await playAlternative(pool, 7, {
    color: 'w', fen: START, uci: 'e2e4', san: 'e4', rejectedUci: 'd2d4',
  });

  const begun = pool.indexOf('BEGIN');
  const committed = pool.indexOf('COMMIT');
  assert.ok(begun === 0);
  assert.ok(committed > 0);
  // Every delete happened inside the transaction.
  for (const [at, call] of pool.calls.entries()) {
    if (call.text.startsWith('DELETE')) {
      assert.ok(at > begun && at < committed);
    }
  }
});

test('the played move ends up primary, by demote then promote', async () => {
  // The same two statements `promoteMove` uses, and for the same reason: the
  // partial unique index is checked per row, so one clever UPDATE can fail on
  // the planner's whim.
  const pool = stubPool({ ...DRAFTED_D4, counts: { drafts: 2 } });
  const out = await playAlternative(pool, 7, {
    color: 'w', fen: START, uci: 'e2e4', san: 'e4', rejectedUci: 'd2d4',
  });

  assert.equal(out.played.role, 'primary');
  const demoted = pool.indexOf("SET role = 'alternate'");
  const promoted = pool.calls.findIndex(
    (c) => c.text.includes("SET role = 'primary'")
      && !c.text.includes('id IN'));
  assert.ok(demoted >= 0 && promoted > demoted);
});
