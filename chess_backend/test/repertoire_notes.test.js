const test = require('node:test');
const assert = require('node:assert/strict');
const { Chess } = require('chess.js');

const { putNote, notesFor, disagreements } = require('../services/repertoireNotes');
const { fenKey } = require('../services/repertoireService');

const START = new Chess().fen();

/// The FEN after a line of UCI moves, computed rather than pasted — a
/// hand-written FEN is a chance to assert against a position that does not
/// exist, and the service would then be right while the test is wrong.
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

/// A pool that answers the four questions this service asks, matched on a
/// fragment unique to each. The notes are held in a map so the upsert's depth
/// rule can be modelled rather than asserted about in the abstract.
function stubPool({ moves = [], replies = [], skips = [], notes = [] } = {}) {
  const calls = [];
  const stored = new Map(notes.map((note) => [note.fen_key, { ...note }]));
  return {
    calls,
    stored,
    paramsOf: (fragment) =>
      calls.find((c) => c.text.includes(fragment))?.params ?? null,
    query: async (text, params) => {
      const flat = text.replace(/\s+/g, ' ').trim();
      calls.push({ text: flat, params });
      const rows = (() => {
        if (flat.startsWith('INSERT INTO repertoire_notes')) {
          const [, , key, cp, mate, depth, uci, line] = params;
          const before = stored.get(key);
          // The rule the database holds: a shallower answer is refused, and
          // refused means no row comes back.
          if (before && Number(before.eval_depth) > Number(depth)) return [];
          const row = {
            fen_key: key,
            eval_cp: cp,
            mate_in: mate,
            eval_depth: depth,
            best_uci: uci,
            best_line_san: line,
            updated_at: new Date('2026-08-31T10:00:00Z'),
          };
          stored.set(key, row);
          return [row];
        }
        if (flat.includes('FROM repertoire_notes')) {
          const wanted = params[2];
          return [...stored.values()].filter(
            (row) => wanted === null || wanted === undefined
              || (Array.isArray(wanted) ? wanted.includes(row.fen_key)
                : row.fen_key === wanted),
          );
        }
        if (flat.includes('SELECT fen_key, uci, san, role')) return moves;
        if (flat.includes('FROM repertoire_skips')) {
          return skips.map((fen_key) => ({ fen_key }));
        }
        if (flat.includes('FROM opening_replies')) {
          const [band, keys] = params;
          // The whole book: `covered` and `asked` are columns the breadth rule
          // reads at walk time, not a filter this query applies.
          return replies
            .filter((r) => Number(r.min_rating ?? 0) === band
              && keys.includes(r.fen_key))
            .map((r) => ({ covered: true, asked: false, ...r }));
        }
        throw new Error(`Neočekivan upit: ${flat}`);
      })();
      return { rows, rowCount: rows.length };
    },
  };
}

/// 1.e4 c5 2.Nf3 — one decision, one reply, one decision. Small on purpose:
/// what is being tested is which positions end up in the list, and a wide tree
/// only makes the assertions harder to read.
const SICILIAN = {
  moves: [
    { fen_key: fenKey(START), uci: 'e2e4', san: 'e4', role: 'primary', source: 'chosen' },
    {
      fen_key: keyAfter('e2e4', 'c7c5'),
      uci: 'g1f3', san: 'Nf3', role: 'primary', source: 'chosen',
    },
  ],
  replies: [
    {
      fen_key: keyAfter('e2e4'),
      uci: 'c7c5', san: 'c5', games: 500, share: '0.50000',
    },
  ],
};

test('a note is written and read back White-relative', async () => {
  const pool = stubPool();
  const written = await putNote(pool, 7, {
    color: 'w', fen: START, evalCp: 35, evalDepth: 20,
    bestUci: 'e2e4', bestLineSan: 'e4 e5 Nf3',
  });
  assert.equal(written.stored, true);
  assert.equal(written.note.evalCp, 35);
  assert.equal(written.note.evalDepth, 20);
  assert.equal(written.note.bestUci, 'e2e4');

  const { notes } = await notesFor(pool, 7, { color: 'w' });
  assert.equal(notes.length, 1);
  assert.equal(notes[0].fenKey, fenKey(START));
});

test('a shallower answer never overwrites a deeper one', async () => {
  // The rule `AnalysisNode.evalDepth` keeps on the client. A whole-line sweep
  // at depth 12 must not flatten a hand-run search at 30, or the number on the
  // card silently gets worse every time somebody presses the line button.
  const pool = stubPool();
  await putNote(pool, 7, {
    color: 'w', fen: START, evalCp: 40, evalDepth: 30, bestUci: 'd2d4',
  });
  const shallow = await putNote(pool, 7, {
    color: 'w', fen: START, evalCp: -200, evalDepth: 12, bestUci: 'g1f3',
  });

  assert.equal(shallow.stored, false);
  // And the answer is the row that won, not the one that was refused: the
  // caller is about to draw it.
  assert.equal(shallow.note.evalCp, 40);
  assert.equal(shallow.note.evalDepth, 30);
  assert.equal(shallow.note.bestUci, 'd2d4');
});

test('an equally deep answer does overwrite', async () => {
  // Re-running the same depth is how somebody asks again after changing a
  // move; refusing it would make the second answer invisible.
  const pool = stubPool();
  await putNote(pool, 7, { color: 'w', fen: START, evalCp: 10, evalDepth: 20 });
  const again = await putNote(pool, 7, {
    color: 'w', fen: START, evalCp: 55, evalDepth: 20,
  });
  assert.equal(again.stored, true);
  assert.equal(again.note.evalCp, 55);
});

test('a note with no evaluation in it is refused', async () => {
  // A row that exists and says nothing is worse than no row: the tree would
  // draw a card for it and the line pass would count the position as done.
  const pool = stubPool();
  await assert.rejects(
    () => putNote(pool, 7, { color: 'w', fen: START, evalDepth: 20 }),
    RangeError,
  );
});

test('a mate is kept apart from its collapsed centipawns', async () => {
  const pool = stubPool();
  const written = await putNote(pool, 7, {
    color: 'w', fen: START, evalCp: 9600, mateIn: 4, evalDepth: 20,
  });
  assert.equal(written.note.mateIn, 4);
  assert.equal(written.note.evalCp, 9600);
});

test('a disagreement is listed with how much it costs, in the student\'s favour',
  async () => {
    // White plays 1.e4; the engine wanted 1.d4 and thinks the position is worth
    // 45 before the move and 10 after it. The loss is 35 from White's side.
    const pool = stubPool({
      ...SICILIAN,
      notes: [
        {
          fen_key: fenKey(START),
          eval_cp: 45, mate_in: null, eval_depth: 20,
          best_uci: 'd2d4', best_line_san: 'd4 d5 c4',
          updated_at: new Date('2026-08-31T10:00:00Z'),
        },
        {
          fen_key: keyAfter('e2e4'),
          eval_cp: 10, mate_in: null, eval_depth: 20,
          best_uci: 'c7c5', best_line_san: 'c5',
          updated_at: new Date('2026-08-31T10:00:00Z'),
        },
      ],
    });

    const answer = await disagreements(pool, 7, { color: 'w', rootFen: START });
    assert.equal(answer.disagreements.length, 1);
    const row = answer.disagreements[0];
    assert.equal(row.mine.uci, 'e2e4');
    assert.equal(row.engine.uci, 'd2d4');
    // Spelled by the same library that spells every other move here, rather
    // than sliced out of the stored line.
    assert.equal(row.engine.san, 'd4');
    assert.equal(row.loss, 35);
  });

test('for Black the loss is counted from Black\'s side', async () => {
  // The store is White-relative, which is right for storage and wrong for a
  // list about somebody's own moves: unflipped, a Black repertoire would sort
  // its best moves to the top of a list of its worst.
  const black = {
    moves: [
      {
        fen_key: keyAfter('e2e4'),
        uci: 'c7c5', san: 'c5', role: 'primary', source: 'chosen',
      },
    ],
    replies: [],
  };
  const pool = stubPool({
    ...black,
    notes: [
      {
        fen_key: keyAfter('e2e4'),
        eval_cp: 20, mate_in: null, eval_depth: 20,
        best_uci: 'e7e5', best_line_san: 'e5',
        updated_at: new Date('2026-08-31T10:00:00Z'),
      },
      {
        fen_key: keyAfter('e2e4', 'c7c5'),
        eval_cp: 60, mate_in: null, eval_depth: 20,
        best_uci: 'g1f3', best_line_san: 'Nf3',
        updated_at: new Date('2026-08-31T10:00:00Z'),
      },
    ],
  });

  const answer = await disagreements(pool, 7, {
    color: 'b', rootFen: after('e2e4'),
  });
  assert.equal(answer.disagreements.length, 1);
  // 20 before, 60 after — forty centipawns worse *for Black*, so the loss is
  // positive rather than negative.
  assert.equal(answer.disagreements[0].loss, 40);
});

test('agreement is not a row, and neither is a position never asked about',
  async () => {
    const pool = stubPool({
      ...SICILIAN,
      notes: [
        {
          fen_key: fenKey(START),
          eval_cp: 30, mate_in: null, eval_depth: 20,
          best_uci: 'e2e4', best_line_san: 'e4',
          updated_at: new Date('2026-08-31T10:00:00Z'),
        },
      ],
    });

    const answer = await disagreements(pool, 7, { color: 'w', rootFen: START });
    assert.equal(answer.disagreements.length, 0);
    // Two positions the student moves in, one of them ever put to the engine.
    // Without the second number a short list reads as "the engine agrees with
    // almost everything", when it may only mean nobody has run it yet.
    assert.equal(answer.positions, 2);
    assert.equal(answer.evaluated, 1);
  });

test('a disagreement whose size is unknown is listed, and listed last',
  async () => {
    // The position after the student's move has never been evaluated. The
    // engine plainly plays something else, so the row belongs in the list — but
    // it carries `loss: null` rather than a zero, which would read as "no
    // difference at all".
    const pool = stubPool({
      ...SICILIAN,
      notes: [
        {
          fen_key: fenKey(START),
          eval_cp: 45, mate_in: null, eval_depth: 20,
          best_uci: 'd2d4', best_line_san: 'd4',
          updated_at: new Date('2026-08-31T10:00:00Z'),
        },
        {
          fen_key: keyAfter('e2e4', 'c7c5'),
          eval_cp: 30, mate_in: null, eval_depth: 20,
          best_uci: 'd2d4', best_line_san: 'd4',
          updated_at: new Date('2026-08-31T10:00:00Z'),
        },
        {
          fen_key: keyAfter('e2e4', 'c7c5', 'g1f3'),
          eval_cp: 10, mate_in: null, eval_depth: 20,
          best_uci: 'd7d6', best_line_san: 'd6',
          updated_at: new Date('2026-08-31T10:00:00Z'),
        },
      ],
    });

    const answer = await disagreements(pool, 7, { color: 'w', rootFen: START });
    assert.equal(answer.disagreements.length, 2);
    // The measured one first — 30 before 2.Nf3, 10 after it — and the one with
    // no note after it below, however deep in the line it sits.
    assert.equal(answer.disagreements[0].loss, 20);
    assert.equal(answer.disagreements[1].loss, null);
    assert.equal(answer.disagreements[1].mine.uci, 'e2e4');
  });

test('a branch narrows the list to what is under it', async () => {
  const pool = stubPool({
    ...SICILIAN,
    notes: [
      {
        fen_key: fenKey(START),
        eval_cp: 45, mate_in: null, eval_depth: 20,
        best_uci: 'd2d4', best_line_san: 'd4',
        updated_at: new Date('2026-08-31T10:00:00Z'),
      },
      {
        fen_key: keyAfter('e2e4', 'c7c5'),
        eval_cp: 30, mate_in: null, eval_depth: 20,
        best_uci: 'd2d4', best_line_san: 'd4',
        updated_at: new Date('2026-08-31T10:00:00Z'),
      },
    ],
  });

  const answer = await disagreements(pool, 7, {
    color: 'w', rootFen: START, fromFen: after('e2e4', 'c7c5'),
  });
  assert.equal(answer.positions, 1);
  assert.equal(answer.disagreements.length, 1);
  assert.equal(answer.disagreements[0].mine.uci, 'g1f3');
});

test('a branch the walk never reaches is an empty list, not a failure',
  async () => {
    // Cut since, or built under a move that is no longer kept. The request was
    // well formed and "there is nothing there any more" is the answer.
    const pool = stubPool(SICILIAN);
    const answer = await disagreements(pool, 7, {
      color: 'w', rootFen: START, fromFen: after('d2d4'),
    });
    assert.equal(answer.disagreements.length, 0);
    assert.equal(answer.positions, 0);
  });

test('a colour that is not w or b is refused rather than queried', async () => {
  const pool = stubPool();
  await assert.rejects(
    () => notesFor(pool, 7, { color: 'x' }),
    RangeError,
  );
  assert.equal(pool.calls.length, 0);
});
