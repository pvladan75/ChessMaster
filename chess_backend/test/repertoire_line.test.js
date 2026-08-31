const test = require('node:test');
const assert = require('node:assert/strict');
const { Chess } = require('chess.js');

const { drillLine } = require('../services/repertoireLine');
const { fenKey } = require('../services/repertoireService');

const START = new Chess().fen();

/// The FEN after a line of UCI moves from the start, and its repertoire key.
///
/// Computed rather than pasted, for the same reason the frontier's tests
/// compute theirs: a hand-written FEN is a chance to assert against a position
/// that does not exist, and the walk would then be right while the test is
/// wrong.
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

/// 1.e4 c5 2.Nf3 d6 3.d4 — three decisions on one line, and nothing else.
///
/// Small on purpose: what is being tested is the shape of the line handed back,
/// and a wide tree would only make the assertions harder to read.
const SICILIAN = {
  moves: [
    { fen_key: fenKey(START), uci: 'e2e4', san: 'e4', role: 'primary' },
    {
      fen_key: keyAfter('e2e4', 'c7c5'),
      uci: 'g1f3', san: 'Nf3', role: 'primary',
    },
    {
      fen_key: keyAfter('e2e4', 'c7c5', 'g1f3', 'd7d6'),
      uci: 'd2d4', san: 'd4', role: 'primary',
    },
  ],
  replies: [
    {
      fen_key: keyAfter('e2e4'),
      uci: 'c7c5', san: 'c5', games: 500, share: '0.50000',
    },
    {
      fen_key: keyAfter('e2e4', 'c7c5', 'g1f3'),
      uci: 'd7d6', san: 'd6', games: 300, share: '0.60000',
    },
  ],
};

/// A pool that answers each of the eight questions this walk asks.
///
/// Matched on a fragment unique to each query rather than replayed in order:
/// how many times the walk asks the book is itself a thing the tests check, so
/// a positional stub would pass for the wrong reason.
function stubPool({
  moves = [], replies = [], skips = [], due = [], fresh = [], known = [],
  stats = { positions: 3, seen: 0, due: 0, known: 0 },
} = {}) {
  const calls = [];
  return {
    calls,
    paramsOf: (fragment) =>
      calls.find((c) => c.text.includes(fragment))?.params ?? null,
    query: async (text, params) => {
      const flat = text.replace(/\s+/g, ' ').trim();
      calls.push({ text: flat, params });
      const rows = (() => {
        if (flat.includes('AS positions')) {
          return [{
            positions: stats.positions,
            seen: stats.seen,
            due: stats.due,
            known: stats.known,
          }];
        }
        if (flat.includes('SELECT fen_key, uci, san, role')) return moves;
        if (flat.includes('FROM repertoire_skips')) {
          return skips.map((fen_key) => ({ fen_key }));
        }
        if (flat.includes('FROM opening_replies')) {
          const [band, keys] = params;
          return replies.filter(
            (r) => Number(r.min_rating ?? 0) === band && keys.includes(r.fen_key),
          );
        }
        if (flat.includes('AS moves')) return [{ moves: 1 }];
        if (flat.includes('r.due_at <= $3')) {
          const within = params[3];
          return due.filter((row) => within === null || within.includes(row.fen_key));
        }
        if (flat.includes('mistakes DESC')) {
          const within = params[2];
          return fresh.filter((row) => within === null || within.includes(row.fen_key));
        }
        if (flat.includes('repetitions >= $4')) {
          const within = params[2];
          return known.filter((row) => within.includes(row.fen_key));
        }
        throw new Error(`Neočekivan upit: ${flat}`);
      })();
      return { rows, rowCount: rows.length };
    },
  };
}

const DEEP = keyAfter('e2e4', 'c7c5', 'g1f3', 'd7d6');
const MIDDLE = keyAfter('e2e4', 'c7c5');

test('the question comes with the line that leads to it', async () => {
  // The drill used to put up a bare board four moves into something, with no
  // way to tell how it arose. A repertoire is played forwards, and this is the
  // difference between remembering a line and recognising a photograph of it.
  const pool = stubPool({
    ...SICILIAN,
    fresh: [{ fen_key: DEEP, mistakes: 0 }],
  });
  const line = await drillLine(pool, 7, { color: 'w', rootFen: START });

  assert.equal(line.question.fenKey, DEEP);
  assert.equal(line.question.ply, 4);
  assert.deepEqual(line.prefix.map((m) => m.san), ['e4', 'c5', 'Nf3', 'd6']);
  // Whose each move is, because the replay asks for the student's and answers
  // back with the opponent's.
  assert.deepEqual(line.prefix.map((m) => m.mine), [true, false, true, false]);
  // Nothing known yet, so the rehearsal starts where the repertoire does.
  assert.equal(line.start.fenKey, fenKey(START));
  assert.equal(line.start.known, false);
});

test('the replay starts at the last position known cold', async () => {
  // Twelve plies of rehearsal to reach one question is how a drill stops being
  // opened. What the student has already got to three clean repetitions is not
  // worth their evening.
  const pool = stubPool({
    ...SICILIAN,
    fresh: [{ fen_key: DEEP, mistakes: 0 }],
    known: [{ fen_key: MIDDLE, repetitions: 4 }],
  });
  const line = await drillLine(pool, 7, { color: 'w', rootFen: START });

  assert.equal(line.start.fenKey, MIDDLE);
  assert.equal(line.start.known, true);
  assert.deepEqual(line.prefix.map((m) => m.san), ['Nf3', 'd6']);
  // Only the positions above the question are consulted. The question's own
  // review says nothing about where the rehearsal should begin — it is the
  // thing being asked.
  assert.deepEqual(pool.paramsOf('repetitions >= $4')[2],
    [fenKey(START), MIDDLE]);
});

test('the line never carries the move it is asking for', async () => {
  // The oldest rule of this drill: a question that arrives with its answer
  // attached is one a determined child reads out of the network log instead of
  // out of their memory. The prefix is not an exception to it — those moves are
  // rehearsal, and the one move that is a question is 3.d4.
  const pool = stubPool({
    ...SICILIAN,
    fresh: [{ fen_key: DEEP, mistakes: 0 }],
  });
  const line = await drillLine(pool, 7, { color: 'w', rootFen: START });

  const wire = JSON.stringify(line);
  assert.equal(wire.includes('d2d4'), false, 'odgovor je otišao sa pitanjem');
  assert.equal(wire.includes('"d4"'), false, 'odgovor je otišao sa pitanjem');
});

test('one branch can be drilled on its own', async () => {
  // The block. The day after a build session the ten positions just built are
  // the thing somebody sits down to practise, and the rest of the repertoire is
  // in the way.
  const pool = stubPool({
    ...SICILIAN,
    fresh: [{ fen_key: DEEP, mistakes: 0 }, { fen_key: fenKey(START), mistakes: 9 }],
  });
  const line = await drillLine(pool, 7, {
    color: 'w', rootFen: START, fromFen: after('e2e4', 'c7c5'),
  });

  // The root has nine missed attempts and would win the whole-colour ordering
  // outright. It is not in this branch, so it is not asked.
  assert.equal(line.question.fenKey, DEEP);
  assert.equal(line.from, MIDDLE);
  const within = pool.paramsOf('mistakes DESC')[2];
  assert.deepEqual([...within].sort(), [DEEP, MIDDLE].sort());
});

test('a branch that is no longer there is an empty block, not a bad request',
  async () => {
    // Cut since, or built under a move that is no longer kept. The request was
    // well formed and the honest answer is "there is nothing there any more".
    const pool = stubPool({
      ...SICILIAN,
      stats: { positions: 0, seen: 0, due: 0, known: 0 },
    });
    const line = await drillLine(pool, 7, {
      color: 'w', rootFen: START, fromFen: after('d2d4'),
    });

    assert.equal(line.question, null);
    assert.equal(line.reason, 'nothing-built');
    assert.equal(line.stats.positions, 0);
  });

test('nothing due and nothing built are two different answers', async () => {
  // Only one of them is good news, and a screen that renders them the same way
  // tells a beginner they have finished something they have not started.
  const pool = stubPool({ ...SICILIAN, stats: { positions: 3, seen: 3, due: 0, known: 3 } });
  const line = await drillLine(pool, 7, { color: 'w', rootFen: START });

  assert.equal(line.question, null);
  assert.equal(line.reason, 'nothing-due');
});

test('a cut branch is not rehearsed', async () => {
  // A line the student refused to prepare is not a line to be played down. The
  // walk stops at the cut, so nothing below it can be the question.
  const pool = stubPool({
    ...SICILIAN,
    skips: [MIDDLE],
    fresh: [{ fen_key: DEEP, mistakes: 0 }, { fen_key: fenKey(START), mistakes: 0 }],
  });
  const line = await drillLine(pool, 7, { color: 'w', rootFen: START });

  assert.equal(line.question.fenKey, fenKey(START));
  const within = pool.paramsOf('mistakes DESC')[2];
  assert.equal(within.includes(DEEP), false, 'odsečena grana je ušla u vežbu');
});

test('the book is asked once per wave, not once per branch', async () => {
  // The same shape the frontier keeps. A walk that asked per branch would turn
  // one drill question into a minute of database time on a wide repertoire.
  const pool = stubPool({ ...SICILIAN, fresh: [{ fen_key: DEEP, mistakes: 0 }] });
  await drillLine(pool, 7, { color: 'w', rootFen: START });

  const waves = pool.calls.filter((c) => c.text.includes('FROM opening_replies'));
  assert.equal(waves.length, 3, `talasa: ${waves.length}`);
});
