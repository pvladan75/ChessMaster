// The reader and the judge of a find exercise, over the fixture the app's
// writer and solver also stand on (`docs/gates/exercise_line_cases.json`).
// A find exercise asks for one move (`docs/PLAN-EXERCISE.md`, phases 14, 16).
const test = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');

const fixture = require(path.join(__dirname, '..', '..', 'docs', 'gates', 'exercise_line_cases.json'));
const { judgeAttempt } = require('../services/customPuzzleJudge');
const { readSolution, firstMoveOf } = require('../services/exercise');

function solutionOf(name) {
  const entry = fixture.solutions[name];
  assert.ok(entry, `no solution named ${name}`);
  const fen = fixture.positions[entry.position];
  const read = readSolution(fen, entry.steps);
  assert.equal(read.ok, true, `${name} must be readable: ${read.error}`);
  return { fen, steps: read.steps, entry };
}

test('the fixture holds what it says it holds', () => {
  // Neither loop below can pass by being empty.
  assert.ok(fixture.judged.length >= 11, 'judged cases');
  assert.ok(fixture.refused.length >= 6, 'refused solutions');
  assert.ok(fixture.judged.some((c) => c.expect.correct === true));
  assert.ok(fixture.judged.some((c) => c.expect.correct === false));
  assert.ok(fixture.judged.some((c) => c.expect.reason === 'another correct move'));
  assert.ok(fixture.judged.some((c) => c.expect.reason === 'a different mate, but mate'));
  assert.ok(fixture.refused.some((c) => c.steps.length > 1), 'a solution refused for its length');
});

test('a solution is read back as the board spells it', () => {
  for (const name of Object.keys(fixture.solutions)) {
    const { steps, entry } = solutionOf(name);
    assert.deepEqual(steps, entry.normalised, name);
  }
});

for (const c of fixture.judged) {
  test(`judged: ${c.name}`, () => {
    const { fen, steps } = solutionOf(c.solution);
    // Through the row's one reader, as the attempt route does.
    const answer = firstMoveOf({ fen, solution: steps });
    const verdict = judgeAttempt({ fen, moveSan: c.move, ...answer });
    // Every key the case names must match; a case names what it is about.
    for (const [key, want] of Object.entries(c.expect)) {
      assert.deepEqual(verdict[key], want, `${key} of ${JSON.stringify(verdict)}`);
    }
    assert.equal(typeof verdict.reason, 'string');
  });
}

for (const c of fixture.refused) {
  test(`refused: ${c.name}`, () => {
    const read = readSolution(fixture.positions[c.position], c.steps);
    assert.equal(read.ok, false);
    assert.ok(read.error.includes(c.why), `"${read.error}" should say "${c.why}"`);
  });
}
