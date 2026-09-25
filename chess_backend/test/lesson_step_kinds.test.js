// lesson_step_kinds.test.js
// What a tutorial's part may be. Written for phase 0 of
// `docs/PLAN-INTERAKTIVNA-LEKCIJA.md`, when a part could ask a student for a
// move or a choice; since phase 4 of `docs/PLAN-TUTORIJAL-VIDEO.md` every part
// shows, a question is an exercise, and a part that asks is refused.
//
// Error strings are matched by fragment rather than byte for byte. The wording
// belongs to whoever writes the refusal — the *meaning* is what is frozen here,
// and a test that pins the sentence would have to be edited by the same person
// it is supposed to judge.

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  buildLessonStep,
  stepsOfLesson,
} = require('../services/lessonSteps');

// A quiet rook ending: Ra8 is mate, Ra7 is legal and not mate, Rh8 is legal.
const FEN = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';

const REFUSAL = /A part only shows a position and a line; a question is an exercise/;

// ---------------------------------------------------------------------------
// §2.1 — the kind, and what an absent one means
// ---------------------------------------------------------------------------

test('a step with no kind is a show step', () => {
  // The whole migration story rests on this line. Every lesson stored today
  // lacks `kind`, and every one of them has to keep working untouched — if an
  // absent kind meant anything else, this feature would need a migration over
  // live homework before it could ship a single screen.
  const built = buildLessonStep({ fen: FEN, title: 'Pozicija' });

  assert.equal(built.ok, true);
  assert.equal(built.entry.kind, 'show');
});

// ---------------------------------------------------------------------------
// §2.5 — ask_move, and the moves that are also right
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// §4 — ask_choice
// ---------------------------------------------------------------------------

test('a part that asks for a move is refused, with the reason', () => {
  // Refused rather than stored as a picture: a trainer whose question
  // silently became a show part would never know it had.
  const built = buildLessonStep({
    fen: FEN, kind: 'ask_move', instruction: 'Find the mate.', solutionSan: 'Ra8#',
  });
  assert.equal(built.ok, false);
  assert.equal(built.status, 400);
  assert.match(built.error, REFUSAL);
});

test('a part that offers answers to choose from is refused too', () => {
  const built = buildLessonStep({
    fen: FEN,
    kind: 'ask_choice',
    choices: [{ text: 'Ra8#', correct: true }, { text: 'Ra7', correct: false }],
  });
  assert.equal(built.ok, false);
  assert.match(built.error, REFUSAL);
});

test('a kind nobody knows is refused the same way', () => {
  const built = buildLessonStep({ fen: FEN, kind: 'ask_anything' });
  assert.equal(built.ok, false);
  assert.match(built.error, REFUSAL);
});

test('a show part keeps no task, no solution, no accepted moves and no answers', () => {
  // What a question used to carry, sent on a part that shows: none of it is
  // read by the film, so none of it is stored.
  const built = buildLessonStep({
    fen: FEN,
    kind: 'show',
    instruction: 'Find the mate.',
    solutionSan: 'Ra8#',
    acceptedSans: ['Ra7'],
    choices: [{ text: 'Ra8#', correct: true }],
  });
  assert.equal(built.ok, true);
  for (const field of ['instruction', 'solutionSan', 'acceptedSans', 'choices']) {
    assert.equal(field in built.entry, false, field);
  }
});

// ---------------------------------------------------------------------------
// The guard that phase 0 must not move
// ---------------------------------------------------------------------------

test('a lesson saved as a single position is still one show step', () => {
  // stepsOfLesson has four callers and one of them once knew less than the
  // other three. Nothing in this plan may narrow it — a lesson with no
  // position_list is still its own single step, and now that step has a kind.
  const steps = stepsOfLesson({ positionList: null, title: 'Jedna', fen: FEN });

  assert.equal(steps.length, 1);
  assert.equal(steps[0].fen, FEN);
  assert.equal(steps[0].kind, 'show');
});
