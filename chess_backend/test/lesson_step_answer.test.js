// lesson_step_answer.test.js
// Phase 4a of `docs/PLAN-INTERAKTIVNA-LEKCIJA.md`: judging a lesson step, and
// keeping the answer on this side of the wire.
//
// The contract file (`lesson_step_kinds.test.js`) says what a step may *be*.
// This says what happens when a child answers one — the half the client batch
// builds against, and the half that must be right before that batch starts.

const test = require('node:test');
const assert = require('node:assert/strict');

const { judgeAttempt } = require('../services/customPuzzleJudge');
const { buildLessonStep, redactStepForStudent } = require('../services/lessonSteps');

// Ra8 is mate; Ra7 and Rb1 are legal and are not.
const FEN = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';

// Two mates: Qe6 and Qh7. Used by the existing judge tests for the same reason.
const TWO_MATES = '6R1/5k2/8/4K3/8/7Q/8/8 w - - 0 1';

test('a move the author listed as also right is correct', () => {
  // Chess positions frequently have several equally good answers. A child who
  // finds a different sound defence must not read „netačno" — that is the whole
  // reason `acceptedSans` exists.
  const verdict = judgeAttempt({
    fen: FEN,
    solutionSan: 'Ra8#',
    acceptedSans: ['Ra7'],
    moveSan: 'Ra7',
  });

  assert.equal(verdict.correct, true);
  assert.equal(verdict.playedSan, 'Ra7');
});

test('an accepted move is matched without its decoration', () => {
  // The author writes `Ra7`, the board says `Ra7+` or the child's client sends
  // `Ra7`. Comparing raw strings would call one of those wrong.
  // `Rg7+` is legal here and is not mate, so only the accepted-move rule can
  // return true — if it matched raw strings, `Rg7` against a played `Rg7+`
  // would come back wrong.
  const verdict = judgeAttempt({
    fen: TWO_MATES,
    solutionSan: 'Qe6#',
    acceptedSans: ['Rg7'],
    moveSan: 'Rg7+',
  });

  assert.equal(verdict.correct, true);
  assert.equal(verdict.reason, 'another correct move',
      'the mate rule must not be the one answering here');
});

test('a move nobody listed is still wrong', () => {
  const verdict = judgeAttempt({
    fen: FEN,
    solutionSan: 'Ra8#',
    acceptedSans: ['Ra7'],
    moveSan: 'Rb1',
  });

  assert.equal(verdict.correct, false);
  assert.equal(verdict.playedSan, 'Rb1');
});

test('the existing custom-puzzle path is unchanged by the new argument', () => {
  // `acceptedSans` defaults to empty, so every caller that does not pass it —
  // which is every caller that existed before this phase — behaves exactly as
  // it did. Both directions asserted, because "unchanged" is the claim.
  assert.equal(
    judgeAttempt({ fen: FEN, solutionSan: 'Ra8#', moveSan: 'Ra8#' }).correct,
    true,
  );
  assert.equal(
    judgeAttempt({ fen: FEN, solutionSan: 'Ra8#', moveSan: 'Ra7' }).correct,
    false,
  );
  // And a different mate is still a mate, which must not have been displaced by
  // the accepted-move rule sitting in front of it.
  assert.equal(
    judgeAttempt({ fen: TWO_MATES, solutionSan: 'Qe6#', moveSan: 'Qh7#' }).correct,
    true,
  );
});

test('an illegal move is not an answer at all', () => {
  const verdict = judgeAttempt({
    fen: FEN,
    solutionSan: 'Ra8#',
    acceptedSans: ['Ra7'],
    moveSan: 'Nf6',
  });

  assert.equal(verdict.correct, false);
  assert.equal(verdict.playedSan, null,
    'a null played move is what tells the route the two boards disagree');
});

test('what a student is served carries no answer, whatever the kind', () => {
  // The blunt version of the redaction check, over each kind in turn. A field
  // added later that happens to carry the answer fails here without anyone
  // remembering this file exists.
  const move = buildLessonStep({
    fen: FEN,
    kind: 'ask_move',
    solutionSan: 'Ra8#',
    acceptedSans: ['Ra7'],
  }).entry;
  const choice = buildLessonStep({
    fen: FEN,
    kind: 'ask_choice',
    choices: [{ text: 'Otvoriti liniju', correct: true }, { text: 'Rokada' }],
  }).entry;
  const show = buildLessonStep({ fen: FEN, solutionSan: 'Ra8#' }).entry;

  for (const step of [move, choice, show]) {
    const forChild = JSON.stringify(redactStepForStudent(step));
    assert.equal(/Ra8|Ra7|correct/.test(forChild), false,
      `an answer survived redaction: ${forChild}`);
  }
});

test('a show step still keeps its own solution on the server', () => {
  // Redaction is what protects the child's side of the wire; it must not be
  // mistaken for a reason to stop storing the move. Every step the course
  // builder makes from the library has carried one since before kinds existed.
  const step = buildLessonStep({ fen: FEN, solutionSan: 'Ra8#' }).entry;

  assert.equal(step.solutionSan, 'Ra8#');
  assert.equal(redactStepForStudent(step).solutionSan, undefined);
});

test('redaction leaves the question and the board alone', () => {
  const step = buildLessonStep({
    fen: FEN,
    title: 'Zadnji red',
    instruction: 'Nađi mat u jednom potezu.',
    kind: 'ask_move',
    solutionSan: 'Ra8#',
  }).entry;

  const forChild = redactStepForStudent(step);

  assert.equal(forChild.fen, FEN);
  assert.equal(forChild.title, 'Zadnji red');
  assert.equal(forChild.instruction, 'Nađi mat u jednom potezu.');
  assert.equal(forChild.kind, 'ask_move');
  assert.equal(forChild.id, step.id);
});

test('a redacted choice step keeps its options, in order', () => {
  // The child has to be able to answer, so the options survive — only which of
  // them is right does not. Order matters: the answer is sent back as an index.
  const step = buildLessonStep({
    fen: FEN,
    kind: 'ask_choice',
    choices: [
      { text: 'Otvoriti liniju', correct: true },
      { text: 'Zameniti damu' },
      { text: 'Rokada' },
    ],
  }).entry;

  const forChild = redactStepForStudent(step);

  assert.deepEqual(
    forChild.choices,
    [{ text: 'Otvoriti liniju' }, { text: 'Zameniti damu' }, { text: 'Rokada' }],
  );
});
