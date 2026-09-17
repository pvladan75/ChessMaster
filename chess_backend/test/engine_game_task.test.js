// engine_game_task.test.js
//
// „Play it out" (docs/PLAN-DOMACI-ZADATAK.md §3, phase 2), judged from the
// shared fixture `docs/gates/engine_game_cases.json` — the same file the app's
// `engine_game_goal_test.dart` reads, because the two ends must agree about
// when an assigned game is over and whether its goal was met.
//
// Every position and move in that fixture was replayed on a real board before
// it was written down: the first draft had four cases whose moves were not
// legal and one that was not the ending it claimed.

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const {
  parseEngineGameTask,
  judgeEngineGame,
  ENDINGS,
  DEFAULT_PLY_CAP,
} = require('../services/engineGameTask');

const fixturePath = path.join(__dirname, '..', '..', 'docs', 'gates', 'engine_game_cases.json');
const fixture = JSON.parse(fs.readFileSync(fixturePath, 'utf8'));

test('the fixture is there and has both halves', () => {
  // A fixture that silently shrank would make every loop below vacuous.
  assert.ok(fixture.cases.length >= 16, `cases: ${fixture.cases.length}`);
  assert.ok(fixture.rejected.length >= 5, `rejected: ${fixture.rejected.length}`);
});

for (const c of fixture.cases) {
  test(`${c.name}`, () => {
    const verdict = judgeEngineGame({ task: c.task, moves: c.moves, resigned: c.resigned === true });
    assert.equal(verdict.ok, true, verdict.error);
    assert.equal(verdict.ending, c.expect.ending ?? null, 'ending');
    assert.equal(verdict.outcome, c.expect.outcome, 'outcome');
    assert.equal(verdict.goalMet, c.expect.goalMet, 'goal met');
    assert.equal(verdict.ownMoves, c.expect.ownMoves, "the student's own moves");
    if (verdict.ending !== null) assert.ok(ENDINGS.includes(verdict.ending));
  });
}

for (const c of fixture.rejected) {
  test(`refused: ${c.name}`, () => {
    const verdict = judgeEngineGame({ task: c.task, moves: c.moves });
    assert.equal(verdict.ok, false);
    assert.match(verdict.error, /\S/);
  });
}

test('an unfinished game meets no goal, whatever the goal is', () => {
  const running = { fen: '4k3/8/8/8/8/8/8/4K2R w - - 0 1', side: 'w', plyCap: 40 };
  for (const goal of ['win', 'hold']) {
    const verdict = judgeEngineGame({ task: { ...running, goal }, moves: ['Rh2'] });
    assert.equal(verdict.ending, null);
    assert.equal(verdict.goalMet, false, goal);
  }
});

test('the task is read back as it will be stored, with its defaults', () => {
  const parsed = parseEngineGameTask({
    fen: '4k3/8/8/8/8/8/8/4K2R w - - 0 1',
    side: 'w',
    goal: 'hold',
    level: 'tesko',
    thinkSeconds: 5,
  });
  assert.equal(parsed.ok, true);
  assert.deepEqual(parsed.task, {
    fen: '4k3/8/8/8/8/8/8/4K2R w - - 0 1',
    side: 'w',
    goal: 'hold',
    surviveMoves: null,
    level: 'tesko',
    thinkSeconds: 5,
    plyCap: DEFAULT_PLY_CAP,
  });
});

test('the engine the trainer chose is part of the task, and refused if invented', () => {
  const base = { fen: '4k3/8/8/8/8/8/8/4K2R w - - 0 1', side: 'w', goal: 'win' };
  assert.equal(parseEngineGameTask({ ...base, level: 'nemoguce' }).ok, false);
  assert.equal(parseEngineGameTask({ ...base, thinkSeconds: 0 }).ok, false);
  assert.equal(parseEngineGameTask({ ...base, thinkSeconds: 61 }).ok, false);
  assert.equal(parseEngineGameTask({ ...base, plyCap: 0 }).ok, false);
  assert.equal(parseEngineGameTask({ ...base, plyCap: 601 }).ok, false);
  assert.equal(parseEngineGameTask({ ...base, surviveMoves: 3 }).task.surviveMoves, null,
    'a number to survive means nothing to a win goal');
});

test('an illegal move is refused, not skipped', () => {
  // The bug shape this codebase has paid for most often: a reader that drops a
  // move it cannot play and says nothing.
  const verdict = judgeEngineGame({
    task: { fen: '4k3/8/8/8/8/8/8/4K2R w - - 0 1', side: 'w', goal: 'win', plyCap: 40 },
    moves: ['Rh2', 'Kd8', 'Qxd8'],
  });
  assert.equal(verdict.ok, false);
  assert.match(verdict.error, /Move 3 \(Qxd8\)/);
});

test('moves may arrive as one string', () => {
  const verdict = judgeEngineGame({
    task: { fen: '6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1', side: 'w', goal: 'win', plyCap: 40 },
    moves: 'Rd8#',
  });
  assert.equal(verdict.ending, 'checkmate');
  assert.equal(verdict.goalMet, true);
});

test('more moves than the limit allows is refused', () => {
  const verdict = judgeEngineGame({
    task: { fen: '4k3/8/8/8/8/8/8/4K2R w - - 0 1', side: 'w', goal: 'hold', plyCap: 2 },
    moves: ['Rh2', 'Kd8', 'Rh3', 'Ke8'],
  });
  assert.equal(verdict.ok, false);
});
