// lesson_steps.test.js
// Covers the crossing where a position from the library becomes a lesson step:
// what has to survive it, and what must not get through.

const test = require('node:test');
const assert = require('node:assert/strict');

const { buildLessonStep } = require('../services/lessonSteps');

const FEN = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';

test('the task travels with the position', () => {
  const built = buildLessonStep({
    title: '#122 · Mat u 333',
    fen: FEN,
    instruction: 'Beli matira u jednom potezu',
  });

  // A step with no task is a board with no question on it — the oldest
  // complaint about this feature, and the reason the field exists at all.
  assert.equal(built.ok, true);
  assert.equal(built.entry.instruction, 'Beli matira u jednom potezu');
});

test('the solution travels too, even though a lesson is read and not solved', () => {
  const built = buildLessonStep({ fen: FEN, solutionSan: 'Ra8#' });

  // Dropped here it would be gone, and the same step may later be set as
  // homework, where the move is the only thing that can judge an answer.
  assert.equal(built.entry.solutionSan, 'Ra8#');
});

test('a position no board can load is refused, not repaired', () => {
  const built = buildLessonStep({ fen: 'not a position' });

  assert.equal(built.ok, false);
  assert.equal(built.status, 422);
  assert.match(built.error, /nije ispravna/);
});

test('a step with no position at all is refused', () => {
  assert.equal(buildLessonStep({ title: 'Prazno' }).ok, false);
  assert.equal(buildLessonStep(null).ok, false);
  assert.equal(buildLessonStep([]).ok, false);
});

test('only the fields a step is made of get through', () => {
  const built = buildLessonStep({
    fen: FEN,
    title: 'Korak',
    id: 7,
    owner_id: 3,
    needs_review: true,
    themes: ['mate'],
  });

  assert.deepEqual(Object.keys(built.entry).sort(), ['fen', 'title']);
});

test('a step with no name still gets one, rather than an empty title', () => {
  const built = buildLessonStep({ fen: FEN, title: '   ' });

  assert.notEqual(built.entry.title.trim(), '');
});

test('long text is cut rather than refused', () => {
  const built = buildLessonStep({
    fen: FEN,
    title: 'x'.repeat(500),
    instruction: 'y'.repeat(900),
  });

  // A trainer who pasted a paragraph gets a step, not an error: nothing here
  // is wrong, only long.
  assert.equal(built.entry.title.length, 200);
  assert.equal(built.entry.instruction.length, 500);
});

test('empty text is absent, not stored as an empty string', () => {
  const built = buildLessonStep({ fen: FEN, instruction: '  ', solutionSan: '' });

  // The viewer says nothing when the field is missing; an empty string would
  // render as a task that says nothing at all.
  assert.equal('instruction' in built.entry, false);
  assert.equal('solutionSan' in built.entry, false);
});
