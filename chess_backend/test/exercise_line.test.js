// The line judge, over the fixture the app's writer and solver also stand on
// (`docs/gates/exercise_line_cases.json`, `docs/PLAN-EXERCISE.md` phase 2a).
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const fixture = require(path.join(__dirname, '..', '..', 'docs', 'gates', 'exercise_line_cases.json'));
const { judgeLine } = require('../services/customPuzzleJudge');
const { readSolution } = require('../services/exercise');

function solutionOf(name) {
  const entry = fixture.solutions[name];
  assert.ok(entry, `no solution named ${name}`);
  const fen = fixture.positions[entry.position];
  const read = readSolution(fen, entry.steps);
  assert.equal(read.ok, true, `${name} must replay: ${read.error}`);
  return { fen, steps: read.steps, entry };
}

test('the fixture holds what it says it holds', () => {
  // Neither loop below can pass by being empty.
  assert.ok(fixture.judged.length >= 14, 'judged cases');
  assert.ok(fixture.refused.length >= 9, 'refused lines');
  assert.ok(fixture.judged.some((c) => c.expect.correct === true && c.expect.done === false));
  assert.ok(fixture.judged.some((c) => c.expect.correct === true && c.expect.done === true));
  assert.ok(fixture.judged.some((c) => c.expect.correct === false));
  assert.ok(fixture.judged.some((c) => c.expect.continuesOn));
});

test('a solution is read back as the board spells it', () => {
  for (const name of Object.keys(fixture.solutions)) {
    const { steps, entry } = solutionOf(name);
    assert.deepEqual(steps, entry.normalised, name);
  }
});

for (const c of fixture.judged) {
  test(`line: ${c.name}`, () => {
    const { fen, steps } = solutionOf(c.solution);
    const verdict = judgeLine({ fen, solution: steps, moves: c.moves });
    // Every key the case names must match; a case names what it is about.
    for (const [key, want] of Object.entries(c.expect)) {
      assert.deepEqual(verdict[key], want, `${key} of ${JSON.stringify(verdict)}`);
    }
    // And whatever the case is about, these hold of every verdict:
    assert.equal(typeof verdict.reason, 'string');
    if (!verdict.correct) {
      assert.equal(verdict.reply, null, 'a wrong move earns no reply');
      assert.equal(verdict.done, false);
    }
    if (verdict.done) assert.equal(verdict.reply, null, 'a finished line has no reply left');
  });
}

for (const c of fixture.refused) {
  test(`refused: ${c.name}`, () => {
    const read = readSolution(fixture.positions[c.position], c.steps);
    assert.equal(read.ok, false);
    assert.ok(read.error.includes(c.why), `"${read.error}" should say "${c.why}"`);
  });
}

test('the reply to a move is never in the answer to the move before it', () => {
  const { fen, steps } = solutionOf('scholarLine');
  const first = judgeLine({ fen, solution: steps, moves: ['Qh5'] });
  assert.equal(JSON.stringify(first).includes('Qxe5'), false, 'move two must not travel with move one');
});
