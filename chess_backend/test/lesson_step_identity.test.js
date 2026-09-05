// lesson_step_identity.test.js
// Phase 1 of `docs/PLAN-INTERAKTIVNA-LEKCIJA.md`: a step keeps its identity
// when the lesson around it is edited.
//
// The bug this pins exists today and is silent. `review_items UNIQUE(user_id,
// lesson_id, position)` and `assignment_items(assignment_id, position)` key a
// student's memory and their recorded answers to an *index*. Insert a step at
// the front and every one of those rows points at a different position — no
// error, no log, and the schedule quietly teaches the wrong board.
//
// `getDue` already carries half the story in a comment: a row pointing *past*
// the end is surfaced as null and skipped. That is the visible half. The half
// nobody could see is a row still inside the array and now aimed elsewhere.

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  buildLessonStep,
  buildLessonSteps,
  stepsOfLesson,
  stepByKey,
  STEP_ID_PATTERN,
} = require('../services/lessonSteps');

const FEN = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';
const FEN2 = 'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 0 1';

// ---------------------------------------------------------------------------
// The id itself
// ---------------------------------------------------------------------------

test('a built step carries an id', () => {
  const built = buildLessonStep({ fen: FEN });

  assert.equal(built.ok, true);
  assert.match(built.entry.id, STEP_ID_PATTERN);
});

test('an id that arrives is kept, never regenerated', () => {
  // This is the whole guarantee. A step that is read, edited and written back
  // has to come out the other side as the same step, or every schedule row
  // naming it is orphaned — and orphaned silently, since nothing joins on it.
  const built = buildLessonStep({ id: 'a3f9c1d2', fen: FEN });

  assert.equal(built.entry.id, 'a3f9c1d2');
});

test('an id that could not have been written here is refused', () => {
  // Loud rather than repaired. A client sending rubbish in this field is a
  // client that has lost the id it was given, and silently minting a fresh one
  // is exactly how the schedule would be orphaned without anybody noticing.
  for (const bad of ['', '   ', 'no spaces here', 'x'.repeat(17), 'drop;table']) {
    const built = buildLessonStep({ id: bad, fen: FEN });
    assert.equal(built.ok, false, `expected refusal for ${JSON.stringify(bad)}`);
    assert.equal(built.status, 400);
  }
});

test('generated ids never collide with the backfill namespace', () => {
  // Legacy steps are backfilled as p0, p1, p2… A generated id that could come
  // out as "p3" would collide with a real step in another lesson read of the
  // same list. Hex cannot produce a leading `p`, and this test is what keeps
  // that true if the generator is ever swapped.
  for (let i = 0; i < 200; i++) {
    const { entry } = buildLessonStep({ fen: FEN });
    // Asserted before the shape check on purpose: without it a missing id
    // stringifies to "undefined", fails to look like `p3`, and the test passes
    // while proving nothing.
    assert.match(entry.id, STEP_ID_PATTERN);
    assert.equal(/^p\d+$/.test(entry.id), false, `generated a backfill-shaped id: ${entry.id}`);
  }
});

// ---------------------------------------------------------------------------
// A whole lesson at once
// ---------------------------------------------------------------------------

test('every step in a lesson gets a different id', () => {
  const built = buildLessonSteps([
    { fen: FEN }, { fen: FEN }, { fen: FEN }, { fen: FEN },
  ]);

  assert.equal(built.ok, true);
  const ids = built.entries.map((s) => s.id);
  assert.equal(new Set(ids).size, 4, 'four identical positions are still four steps');
});

test('a duplicate id inside one lesson is refused', () => {
  // Two steps claiming one id makes `stepByKey` ambiguous, and the schedule row
  // that names it would resolve to whichever came first. Refused at the door.
  const built = buildLessonSteps([
    { id: 'aaaa1111', fen: FEN },
    { id: 'aaaa1111', fen: FEN2 },
  ]);

  assert.equal(built.ok, false);
  assert.equal(built.status, 400);
  assert.match(built.error, /aaaa1111/);
});

test('one bad step refuses the whole lesson, and says which one', () => {
  // Saving three of four steps leaves the trainer with a lesson they did not
  // write and no way to tell which part is missing.
  const built = buildLessonSteps([
    { fen: FEN },
    { fen: 'not a position' },
    { fen: FEN2 },
  ]);

  assert.equal(built.ok, false);
  assert.match(built.error, /2/, 'the refusal names the step by its place in the list');
});

// ---------------------------------------------------------------------------
// Legacy lessons — everything stored before this phase
// ---------------------------------------------------------------------------

test('a stored step with no id is backfilled from its index', () => {
  // `p<index>` and not a random id, because this value becomes a database key
  // the moment a schedule row is written against it. A generator here would
  // hand out a different key on every read of the same lesson.
  const steps = stepsOfLesson({
    positionList: [{ fen: FEN }, { fen: FEN2 }],
    title: 'Stara lekcija',
  });

  assert.deepEqual(steps.map((s) => s.id), ['p0', 'p1']);
});

test('the backfill is stable across reads', () => {
  const lesson = { positionList: [{ fen: FEN }, { fen: FEN2 }], title: 'Stara' };
  const first = stepsOfLesson(lesson).map((s) => s.id);

  // Two reads agreeing on `[undefined, undefined]` would satisfy the deepEqual
  // below and prove nothing, so the ids have to be real before they are
  // compared.
  for (const id of first) assert.match(id, STEP_ID_PATTERN);
  assert.deepEqual(stepsOfLesson(lesson).map((s) => s.id), first);
});

test('a lesson saved as a single position is step p0', () => {
  // The four-caller function that once had a copy knowing less than the others.
  // A bare lesson is still one step, and now that step has a name.
  const steps = stepsOfLesson({ positionList: null, title: 'Jedna', fen: FEN });

  assert.equal(steps.length, 1);
  assert.equal(steps[0].id, 'p0');
});

test('the backfill fills only the gaps', () => {
  // A half-migrated lesson: some steps written after this phase, some before.
  // The stored ids win, and the rest are named by where they sit.
  const steps = stepsOfLesson({
    positionList: [{ fen: FEN }, { id: 'c0ffee11', fen: FEN2 }, { fen: FEN }],
    title: 'Pola',
  });

  assert.deepEqual(steps.map((s) => s.id), ['p0', 'c0ffee11', 'p2']);
});

// ---------------------------------------------------------------------------
// The bug, stated directly
// ---------------------------------------------------------------------------

test('inserting a step at the front does not rename the steps after it', () => {
  // The regression this whole phase exists for. Before: the second step was
  // `position 1`. After the insert it is `position 2`, and every review_items
  // row still saying 1 now points at somebody else's board.
  const before = stepsOfLesson({
    positionList: [
      { id: 'aaaa0001', fen: FEN },
      { id: 'bbbb0002', fen: FEN2 },
    ],
    title: 'Lekcija',
  });

  const after = stepsOfLesson({
    positionList: [
      { id: 'cccc0003', fen: FEN2 },
      { id: 'aaaa0001', fen: FEN },
      { id: 'bbbb0002', fen: FEN2 },
    ],
    title: 'Lekcija',
  });

  // The index moved...
  assert.equal(before.findIndex((s) => s.id === 'bbbb0002'), 1);
  assert.equal(after.findIndex((s) => s.id === 'bbbb0002'), 2);

  // ...and the identity did not. This is what a schedule row will hold.
  assert.equal(stepByKey(after, 'bbbb0002').fen, stepByKey(before, 'bbbb0002').fen);
  assert.equal(stepByKey(after, 'aaaa0001').fen, stepByKey(before, 'aaaa0001').fen);
});

test('a key whose step is gone resolves to null, never to a neighbour', () => {
  // A trainer may delete a step a student has a schedule for. Returning the
  // step that inherited its index would ask the child about a position nobody
  // ever showed them — worse than showing nothing, which is what `getDue`
  // already does with rows pointing past the end.
  const steps = stepsOfLesson({
    positionList: [{ id: 'aaaa0001', fen: FEN }],
    title: 'Lekcija',
  });

  assert.equal(stepByKey(steps, 'bbbb0002'), null);
  assert.equal(stepByKey(steps, undefined), null);
  assert.equal(stepByKey([], 'aaaa0001'), null);
});
