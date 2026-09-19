// „For N moves", and the position a game reaches (`docs/PLAN-EXERCISE.md`,
// phase 3a), over the `forMoves` half of the fixture the app will also read.
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const fixture = require(path.join(__dirname, '..', '..', 'docs', 'gates', 'engine_game_cases.json')).forMoves;
const {
  parseEngineGameTask, judgeEngineGame, goalMetByTablebase, pieceCount, TABLEBASE_PIECES,
} = require('../services/engineGameTask');
const { wdlOf, TablebaseUnavailable } = require('../services/tablebaseService');

test('the fixture holds what it says it holds', () => {
  assert.ok(fixture.judged.length >= 7);
  assert.ok(fixture.rejected.length >= 2);
  assert.ok(fixture.byTablebase.length >= 6);
  // Both answers, for every goal a tablebase is asked about, and both sides
  // to move: a table of one answer cannot tell a rule from a constant. A win
  // has no rows — „checkmate in N moves" is the rules' alone (19.9.2026).
  assert.ok(!fixture.byTablebase.some((r) => r.goal === 'win'));
  for (const goal of ['hold', 'survive']) {
    const rows = fixture.byTablebase.filter((r) => r.goal === goal);
    assert.ok(rows.some((r) => r.goalMet) && rows.some((r) => !r.goalMet), goal);
  }
  const turns = new Set(fixture.byTablebase.map((r) => `${r.fen.split(' ')[1] === r.side}`));
  assert.deepEqual([...turns].sort(), ['false', 'true']);
  assert.ok(fixture.judged.some((c) => c.expect.needsTablebase));
  assert.ok(fixture.judged.some((c) => c.expect.ending === 'moveTarget' && !c.expect.needsTablebase));
  // Checkmate in N, on both sides of its boundary: missed with few enough
  // pieces that a tablebase *could* have been asked, and met on move N itself.
  const mates = fixture.judged.filter((c) => c.task.goal === 'win' && c.task.surviveMoves);
  assert.ok(mates.some((c) => c.expect.ending === 'moveTarget' && !c.expect.goalMet
    && pieceCount(c.expect.fen) <= TABLEBASE_PIECES));
  assert.ok(mates.some((c) => c.expect.goalMet && c.expect.ownMoves === c.task.surviveMoves));
});

for (const c of fixture.judged) {
  test(`for N moves: ${c.name}`, () => {
    const verdict = judgeEngineGame({ task: c.task, moves: c.moves });
    assert.equal(verdict.ok, true, verdict.error);
    for (const [key, want] of Object.entries(c.expect)) {
      assert.deepEqual(verdict[key], want, key);
    }
  });
}

for (const c of fixture.rejected) {
  test(`for N moves, refused: ${c.name}`, () => {
    const parsed = parseEngineGameTask(c.task);
    assert.equal(parsed.ok, false);
    assert.ok(parsed.error.includes(c.why), `"${parsed.error}" should say "${c.why}"`);
  });
}

for (const row of fixture.byTablebase) {
  test(`by tablebase, ${row.goal} as ${row.side}: ${row.name}`, () => {
    const met = goalMetByTablebase({
      task: { goal: row.goal, side: row.side }, fen: row.fen, category: row.category, wdlOf,
    });
    assert.equal(met, row.goalMet);
  });
}

test('a win is never for the tablebase to judge: asking is a fault, not an answer', () => {
  assert.throws(
    () => goalMetByTablebase({
      task: { goal: 'win', side: 'w' }, fen: '8/8/8/8/8/R2k4/8/4K3 b - - 3 2', category: 'loss', wdlOf,
    }),
    /judged by checkmate/
  );
});

test('no outcome is not an outcome: it throws, it does not fail the student', () => {
  for (const category of fixture.noOutcome) {
    assert.throws(
      () => goalMetByTablebase({
        task: { goal: 'hold', side: 'w' }, fen: '8/8/8/8/8/R2k4/8/4K3 w - - 3 2', category, wdlOf,
      }),
      TablebaseUnavailable,
      String(category)
    );
  }
});

test('a number of moves is kept on a win and a hold, and still demanded of survive', () => {
  // Until phase 3a this file's neighbour asserted the opposite — „a number to
  // survive means nothing to a win goal" — which was decision §9.2 of the
  // homework plan. Superseded by decision 6 of `docs/PLAN-EXERCISE.md`.
  const base = { fen: '8/8/8/8/8/4k3/8/R3K3 w - - 0 1', side: 'w' };
  assert.equal(parseEngineGameTask({ ...base, goal: 'win', surviveMoves: 3 }).task.surviveMoves, 3);
  assert.equal(parseEngineGameTask({ ...base, goal: 'hold', surviveMoves: '4' }).task.surviveMoves, 4);
  assert.equal(parseEngineGameTask({ ...base, goal: 'win' }).task.surviveMoves, null);
  assert.equal(parseEngineGameTask({ ...base, goal: 'survive' }).ok, false);
});

test('pieces are counted off the board field, kings included', () => {
  assert.equal(TABLEBASE_PIECES, 7);
  assert.equal(pieceCount('8/8/8/8/8/4k3/8/R3K3 w - - 0 1'), 3);
  assert.equal(pieceCount('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'), 32);
  // The letters after the board — `w`, `KQkq`, `b` — are not pieces.
  assert.equal(pieceCount('8/8/8/4k3/8/4K3/4P3/8 b KQkq - 0 1'), 3);
});

test('the homework row names the number: two different tasks are two different rows', () => {
  // Required here, not at the top: `homeworkSend` reaches the database module,
  // and the rest of this file is pure.
  const { childTitle } = require('../services/homeworkSend');
  const title = (task) => childTitle({ kind: 'engine_game', task });
  assert.equal(title({ goal: 'win', surviveMoves: null }), 'Play it out: win it');
  assert.equal(title({ goal: 'win', surviveMoves: 5 }), 'Play it out: checkmate in 5 moves');
  assert.equal(title({ goal: 'win', surviveMoves: 1 }), 'Play it out: checkmate in 1 move');
  assert.equal(title({ goal: 'hold', surviveMoves: null }), 'Play it out: hold the draw');
  assert.equal(title({ goal: 'hold', surviveMoves: 4 }), 'Play it out: do not lose for 4 moves');
  assert.equal(title({ goal: 'survive', surviveMoves: 4 }), 'Play it out: do not lose for 4 moves');
});
