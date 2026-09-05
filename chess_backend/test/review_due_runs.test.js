// review_due_runs.test.js
// Proves that `getDue` *runs*, which nothing did until now.
//
// It did not. `stepsOfLesson` was called inside it and never imported, so every
// call threw `ReferenceError: stepsOfLesson is not defined` — from 60648ba, the
// commit whose message is „the review screen knew less about a lesson than three
// other readers". Consolidating the four readers added the call and left out the
// require.
//
// `npm test` stayed green for the same reason it stayed green over a `server.js`
// that did not parse: `sources_compile.test.js` *compiles* every source, and a
// missing binding is not a syntax error — it is a name that resolves at call
// time, and nothing ever called it. The spaced-repetition queue was in
// TODO-provera as "tested in code, never run live", and this is what that gap
// was hiding.
//
// So the guard is not another assertion about the schedule arithmetic, which was
// always fine. It is one test that reaches the function with a pool and lets it
// execute.

const test = require('node:test');
const assert = require('node:assert/strict');

const { getDue } = require('../services/spacedRepetitionService');

const FEN = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';
const FEN2 = 'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 0 1';

/// A pool that answers one query with the rows it was given.
function stubPool(rows) {
  return { async query() { return { rows }; } };
}

function dueRow(overrides = {}) {
  return {
    id: 1,
    lesson_id: 5,
    step_key: 'p0',
    position: 0,
    interval_days: 1,
    repetitions: 1,
    due_at: new Date('2026-09-05T10:00:00Z'),
    lesson_title: 'Slaba polja',
    lesson_fen: FEN,
    lesson_pgn: null,
    position_list: null,
    ...overrides,
  };
}

test('a due row comes back with the board it names', async () => {
  const due = await getDue(stubPool([dueRow()]), 1);

  assert.equal(due.length, 1);
  assert.equal(due[0].step.fen, FEN);
  assert.equal(due[0].stepKey, 'p0');
});

test('the schedule follows the step through an edit, not the index', async () => {
  // The regression this phase exists for, end to end. The student's row was
  // written when „bbbb0002" was the second step. The trainer has since inserted
  // a step at the front, so it is now third — and the queue must still show the
  // same board.
  const positionList = [
    { id: 'cccc0003', fen: FEN2, title: 'Novi prvi korak' },
    { id: 'aaaa0001', fen: FEN, title: 'Prvi' },
    { id: 'bbbb0002', fen: FEN2, title: 'Drugi' },
  ];

  const due = await getDue(
    stubPool([dueRow({ step_key: 'bbbb0002', position: 1, position_list: positionList })]),
    1,
  );

  assert.equal(due.length, 1);
  assert.equal(due[0].step.title, 'Drugi');

  // The stored `position` is now stale — it says 1, and the step sits at 2.
  // That is exactly why nothing may read it as an identity any more.
  assert.equal(due[0].position, 1);
});

test('a row naming a step the trainer deleted is skipped, not answered wrongly', async () => {
  const positionList = [{ id: 'aaaa0001', fen: FEN, title: 'Jedini' }];

  const due = await getDue(
    stubPool([dueRow({ step_key: 'bbbb0002', position: 0, position_list: positionList })]),
    1,
  );

  // Skipped. Handing back whichever step inherited index 0 would ask the child
  // about a board nobody ever showed them.
  assert.equal(due.length, 0);
});

test('a legacy row still finds its step through the backfilled name', async () => {
  // Every row written before this phase says `p<index>`, and `stepsOfLesson`
  // names an id-less stored step the same way. The two agree by construction —
  // this is the test that says so out loud.
  const positionList = [{ fen: FEN, title: 'Nulti' }, { fen: FEN2, title: 'Prvi' }];

  const due = await getDue(
    stubPool([dueRow({ step_key: 'p1', position: 1, position_list: positionList })]),
    1,
  );

  assert.equal(due.length, 1);
  assert.equal(due[0].step.title, 'Prvi');
});
