// lesson_steps.test.js
// Covers the crossing where a position from the library becomes a lesson step:
// what has to survive it, and what must not get through.

const test = require('node:test');
const assert = require('node:assert/strict');

const { buildLessonStep, stepsOfLesson } = require('../services/lessonSteps');

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


// A lesson has its steps in `position_list` — unless it was saved as a single
// position, and then it *is* one step made of its own columns. Four places read
// that, and one of them read only the list.

test('a lesson built in the builder is its list of steps', () => {
  const steps = stepsOfLesson({
    positionList: [{ title: 'A', fen: FEN }, { title: 'B', fen: FEN }],
    title: 'cela lekcija',
    fen: FEN,
  });

  assert.equal(steps.length, 2);
  assert.equal(steps[1].title, 'B');
});

test('a lesson saved as a single position is one step, not none', () => {
  // This is the bug seen live on 20.8.2026: the review screen read only
  // `position_list`, found nothing, and drew an empty square under the heading
  // "Pozicija 1" while the same lesson opened correctly everywhere else.
  const steps = stepsOfLesson({
    positionList: null,
    title: 'pozicija 1',
    fen: FEN,
    pgn: '1. Ra8#',
  });

  assert.equal(steps.length, 1);
  assert.equal(steps[0].fen, FEN, 'the board it was saved with');
  assert.equal(steps[0].title, 'pozicija 1');
  assert.equal(steps[0].pgn, '1. Ra8#');
});

test('a list stored as text is read, and an empty one is not a lesson of nothing', () => {
  assert.equal(stepsOfLesson({ positionList: '[{"title":"A"}]' })[0].title, 'A');
  assert.equal(stepsOfLesson({ positionList: [], fen: FEN }).length, 1);
  assert.equal(stepsOfLesson({ positionList: '[]', fen: FEN }).length, 1);
});

test('an unreadable list falls back rather than emptying the screen', () => {
  // Same reasoning as an absent one: the lesson still has its own position, and
  // showing it beats showing nothing.
  const steps = stepsOfLesson({ positionList: 'not json', title: 't', fen: FEN });

  assert.equal(steps.length, 1);
  assert.equal(steps[0].fen, FEN);
});

test('nothing rebuilds this fallback on its own', () => {
  // Asserted on the source because the failure is invisible: a copy that omits
  // the fallback returns an empty list, and an empty list draws a screen that
  // looks merely bare rather than broken. Three of the four copies had it and
  // one did not, which is exactly how it survived.
  const fs = require('fs');
  const path = require('path');
  const dir = path.join(__dirname, '..', 'services');

  const offenders = fs
    .readdirSync(dir)
    .filter((f) => f.endsWith('.js') && f !== 'lessonSteps.js')
    .filter((f) => /list\.length\s*>\s*0/.test(fs.readFileSync(path.join(dir, f), 'utf8')));

  assert.deepEqual(offenders, [], 'these resolve the steps of a lesson themselves');
});
