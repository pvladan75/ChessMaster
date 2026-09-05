// lesson_step_kinds.test.js
// Phase 0 of `docs/PLAN-INTERAKTIVNA-LEKCIJA.md`: the step schema (§4), the
// three kinds (§2.1), the refusals, and the redaction contract (§2.4).
//
// Written before the implementation and expected to fail — that is what phase 0
// delivers. Two things are deliberately NOT here, because each belongs with the
// phase that makes it green: step identity (`id`) is phase 1, and the group
// fan-out is phase 8.
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
  redactStepForStudent,
} = require('../services/lessonSteps');

// A quiet rook ending: Ra8 is mate, Ra7 is legal and not mate, Rh8 is legal.
const FEN = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';

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

test('an unknown kind is refused rather than treated as show', () => {
  // Falling back to `show` would turn a typo in the editor into a step that
  // silently stops asking the child anything — the trainer sees their question
  // vanish with no error. Loud failure, per CLAUDE.md.
  const built = buildLessonStep({ fen: FEN, kind: 'ask_anything' });

  assert.equal(built.ok, false);
  assert.equal(built.status, 400);
  assert.match(built.error, /korak/i);
});

test('a show step carries no answer fields even if it was sent some', () => {
  // Only the fields a step is made of, as the file already does for everything
  // else. A `show` step with a solution attached would be judged by nothing and
  // redacted by nothing, which is the worst of both.
  const built = buildLessonStep({
    fen: FEN,
    kind: 'show',
    solutionSan: 'Ra8#',
    choices: [{ text: 'a', correct: true }, { text: 'b' }],
  });

  assert.equal(built.ok, true);
  assert.equal(built.entry.solutionSan, undefined);
  assert.equal(built.entry.choices, undefined);
});

// ---------------------------------------------------------------------------
// §2.5 — ask_move, and the moves that are also right
// ---------------------------------------------------------------------------

test('ask_move without a solution is refused', () => {
  // A board whose every answer is wrong. Same reasoning as `canAssign` in
  // customPuzzleJudge.js, and the scanner can produce exactly this row: a
  // claimed solution that did not verify is stored as NULL.
  const built = buildLessonStep({ fen: FEN, kind: 'ask_move' });

  assert.equal(built.ok, false);
  assert.equal(built.status, 400);
  assert.match(built.error, /rešenj|potez/i);
});

test('a solution that cannot be played in the position is refused', () => {
  const built = buildLessonStep({ fen: FEN, kind: 'ask_move', solutionSan: 'Qd8#' });

  assert.equal(built.ok, false);
  assert.equal(built.status, 422);
});

test('acceptedSans survive, and the author move stays the one the story follows', () => {
  const built = buildLessonStep({
    fen: FEN,
    kind: 'ask_move',
    solutionSan: 'Ra8#',
    acceptedSans: ['Rb1', 'Ra7'],
  });

  assert.equal(built.ok, true);
  assert.equal(built.entry.solutionSan, 'Ra8#');
  assert.deepEqual(built.entry.acceptedSans, ['Rb1', 'Ra7']);
});

test('an accepted move that is not legal is refused, and the move is named', () => {
  // Refuses rather than repairs, like the position does. Dropping the bad entry
  // silently would tell a child "netačno" for a move their trainer believed
  // they had accepted — the exact failure acceptedSans exists to prevent.
  const built = buildLessonStep({
    fen: FEN,
    kind: 'ask_move',
    solutionSan: 'Ra8#',
    acceptedSans: ['Nf6'],
  });

  assert.equal(built.ok, false);
  assert.equal(built.status, 422);
  assert.match(built.error, /Nf6/);
});

test('an accepted move repeating the author move is dropped, not refused', () => {
  // This one is a repair rather than a refusal, and deliberately so: it is not
  // a trainer's mistake about chess, it is the same right answer written twice.
  const built = buildLessonStep({
    fen: FEN,
    kind: 'ask_move',
    solutionSan: 'Ra8#',
    acceptedSans: ['Ra8#', 'Ra7'],
  });

  assert.equal(built.ok, true);
  assert.deepEqual(built.entry.acceptedSans, ['Ra7']);
});

test('more than six accepted moves is refused', () => {
  const built = buildLessonStep({
    fen: FEN,
    kind: 'ask_move',
    solutionSan: 'Ra8#',
    acceptedSans: ['Ra7', 'Ra6', 'Ra5', 'Ra4', 'Ra3', 'Ra2', 'Rb1'],
  });

  assert.equal(built.ok, false);
  assert.equal(built.status, 400);
});

// ---------------------------------------------------------------------------
// §4 — ask_choice
// ---------------------------------------------------------------------------

test('a choice step keeps its options in the order the trainer wrote them', () => {
  const built = buildLessonStep({
    fen: FEN,
    kind: 'ask_choice',
    instruction: 'Koji je plan?',
    choices: [
      { text: 'Otvoriti liniju', correct: true },
      { text: 'Zameniti damu' },
      { text: 'Rokada' },
    ],
  });

  assert.equal(built.ok, true);
  assert.equal(built.entry.choices.length, 3);
  assert.equal(built.entry.choices[0].text, 'Otvoriti liniju');
  assert.equal(built.entry.choices[0].correct, true);
  assert.equal(built.entry.choices[1].correct, false);
});

test('fewer than two choices is refused', () => {
  const built = buildLessonStep({
    fen: FEN,
    kind: 'ask_choice',
    choices: [{ text: 'Jedina', correct: true }],
  });

  assert.equal(built.ok, false);
  assert.equal(built.status, 400);
});

test('more than four choices is refused', () => {
  const built = buildLessonStep({
    fen: FEN,
    kind: 'ask_choice',
    choices: [
      { text: 'a', correct: true }, { text: 'b' }, { text: 'c' },
      { text: 'd' }, { text: 'e' },
    ],
  });

  assert.equal(built.ok, false);
  assert.equal(built.status, 400);
});

test('a choice step without exactly one correct answer is refused', () => {
  // Both directions, because they fail differently on screen: none correct is a
  // question no child can pass, two correct is a question that calls a right
  // answer wrong. v1 is one correct answer — a trainer who wants two writes two
  // steps.
  const none = buildLessonStep({
    fen: FEN,
    kind: 'ask_choice',
    choices: [{ text: 'a' }, { text: 'b' }],
  });
  assert.equal(none.ok, false);
  assert.equal(none.status, 400);

  const two = buildLessonStep({
    fen: FEN,
    kind: 'ask_choice',
    choices: [{ text: 'a', correct: true }, { text: 'b', correct: true }],
  });
  assert.equal(two.ok, false);
  assert.equal(two.status, 400);
});

test('an empty option text is refused', () => {
  const built = buildLessonStep({
    fen: FEN,
    kind: 'ask_choice',
    choices: [{ text: '   ', correct: true }, { text: 'b' }],
  });

  assert.equal(built.ok, false);
  assert.equal(built.status, 400);
});

// ---------------------------------------------------------------------------
// §2.4 — the answer never leaves the server
// ---------------------------------------------------------------------------

test('the redaction exists at all', () => {
  // Named on its own so the first failure of this file reads as "it is not
  // written yet" rather than as a TypeError inside the next test.
  assert.equal(typeof redactStepForStudent, 'function');
});

test('a redacted ask_move step carries no solution', () => {
  const { entry } = buildLessonStep({
    fen: FEN,
    kind: 'ask_move',
    instruction: 'Nađi mat u jednom potezu.',
    solutionSan: 'Ra8#',
    acceptedSans: ['Ra7'],
  });

  const forChild = redactStepForStudent(entry);

  // Sending the solution so the client could mark its own work would hand the
  // student the very thing being asked of them — the rule already written into
  // POST /assignments/:id/custom-attempt.
  assert.equal(forChild.solutionSan, undefined);
  assert.equal(forChild.acceptedSans, undefined);

  // ...and everything the child does need is still there.
  assert.equal(forChild.kind, 'ask_move');
  assert.equal(forChild.fen, FEN);
  assert.equal(forChild.instruction, 'Nađi mat u jednom potezu.');
});

test('a redacted ask_choice step keeps the options and loses which one is right', () => {
  const { entry } = buildLessonStep({
    fen: FEN,
    kind: 'ask_choice',
    choices: [{ text: 'Otvoriti liniju', correct: true }, { text: 'Rokada' }],
  });

  const forChild = redactStepForStudent(entry);

  assert.equal(forChild.choices.length, 2);
  assert.equal(forChild.choices[0].text, 'Otvoriti liniju');
  for (const choice of forChild.choices) {
    assert.equal(choice.correct, undefined);
  }

  // The blunt version of the same assertion: no answer survives anywhere in the
  // payload, however it was nested. A field added later that happens to carry
  // the answer fails here without anyone remembering to update this file.
  assert.equal(/correct|solution/i.test(JSON.stringify(forChild)), false);
});

test('redaction leaves a show step alone', () => {
  const { entry } = buildLessonStep({
    fen: FEN,
    title: 'Slaba polja',
    instruction: 'Pogledaj polje d5.',
  });

  assert.deepEqual(redactStepForStudent(entry), entry);
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
