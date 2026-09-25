// lesson_step_answer.test.js
// Written for phase 4a of `docs/PLAN-INTERAKTIVNA-LEKCIJA.md`, judging a
// tutorial's move question. Those questions are gone
// (`docs/PLAN-TUTORIJAL-VIDEO.md`); what stays is the half that was always
// shared — `judgeAttempt` with moves the author also accepts, which an
// exercise is judged by.

const test = require('node:test');
const assert = require('node:assert/strict');

const { judgeAttempt } = require('../services/customPuzzleJudge');

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
