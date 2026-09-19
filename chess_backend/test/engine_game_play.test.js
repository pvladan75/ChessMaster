// „Play N moves" — a game with no goal, judged by the trainer
// (`docs/PLAN-EXERCISE.md`, §10, phase 15), over the `play` half of the
// fixture the app reads too.
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const fixture = require(path.join(__dirname, '..', '..', 'docs', 'gates', 'engine_game_cases.json')).play;
const {
  parseEngineGameTask, judgeEngineGame, goalMetByTablebase, pieceCount, TABLEBASE_PIECES, GOALS,
} = require('../services/engineGameTask');
const { wdlOf } = require('../services/tablebaseService');

test('the fixture holds what it says it holds', () => {
  assert.ok(fixture.judged.length >= 4);
  assert.ok(fixture.rejected.length >= 2);
  // A tablebase could answer the first case — that is what makes „nobody is
  // asked" a claim about the rule and not about the position.
  const asked = fixture.judged.find((c) => c.expect.ending === 'moveTarget');
  assert.ok(pieceCount(asked.task.fen) <= TABLEBASE_PIECES);
  // The board ending the game and the number ending it, both.
  assert.ok(fixture.judged.some((c) => c.expect.ending === 'checkmate'));
  assert.ok(fixture.judged.some((c) => c.expect.ending === null));
  assert.ok(fixture.judged.some((c) => c.task.side === 'b'));
});

test('play is a goal', () => {
  assert.ok(GOALS.includes('play'));
});

for (const c of fixture.judged) {
  test(`play: ${c.name}`, () => {
    const verdict = judgeEngineGame({ task: c.task, moves: c.moves });
    assert.equal(verdict.ok, true, verdict.error);
    for (const [key, want] of Object.entries(c.expect)) {
      assert.deepEqual(verdict[key], want, key);
    }
  });
}

test(`control: ${fixture.control.name}`, () => {
  const c = fixture.control;
  const verdict = judgeEngineGame({ task: c.task, moves: c.moves });
  for (const [key, want] of Object.entries(c.expect)) {
    assert.deepEqual(verdict[key], want, key);
  }
});

for (const c of fixture.rejected) {
  test(`play, refused: ${c.name}`, () => {
    const parsed = parseEngineGameTask(c.task);
    assert.equal(parsed.ok, false);
    assert.ok(parsed.error.includes(c.why), `"${parsed.error}" should say "${c.why}"`);
  });
}

test('giving up is not a verdict either: the trainer still judges', () => {
  const c = fixture.judged[0];
  const verdict = judgeEngineGame({ task: c.task, moves: ['Ra8', 'Kd3'], resigned: true });
  assert.equal(verdict.ending, 'resignation');
  assert.equal(verdict.goalMet, null);
  assert.equal(verdict.needsTrainer, true);
});

test('a game with no goal is never for the tablebase: asking is a fault, not an answer', () => {
  assert.throws(
    () => goalMetByTablebase({
      task: { goal: 'play', side: 'w' }, fen: '8/8/8/8/8/R2k4/8/4K3 b - - 3 2', category: 'loss', wdlOf,
    }),
    /no goal/
  );
});

test('the homework row says what it is, with its number', () => {
  const { childTitle } = require('../services/homeworkSend');
  assert.equal(
    childTitle({ kind: 'engine_game', task: { goal: 'play', surviveMoves: 12 } }),
    'Play it out: play 12 moves'
  );
  assert.equal(
    childTitle({ kind: 'engine_game', task: { goal: 'play', surviveMoves: 1 } }),
    'Play it out: play 1 move'
  );
});
