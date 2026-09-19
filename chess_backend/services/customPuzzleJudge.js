// customPuzzleJudge.js — deciding whether a child's move was right.
//
// A scanned position stores one move: the one the author printed. Comparing a
// child's answer to that string alone would be wrong in a way that matters —
// in a mate-in-one there is often more than one mate, and a student who finds a
// different one has solved the exercise. Being told "wrong" for a correct
// mate is the kind of thing that makes a child distrust the app, and they would
// be right to.
//
// So the rule follows the board rather than the text: **any move that mates is
// accepted.** Short of mate only the author's moves are, because nothing here
// knows what else the position was meant to teach.
//
// Until 20.9.2026 a different mate counted only where the author's own move
// mated. That left one case the wrong way round, found by the owner on his own
// exercise: had he written the quiet move first and the mate as its
// alternative, a student who gave a *third* move, mate on the spot, would have
// been told „wrong". No position was ever meant to teach that a checkmate is a
// mistake, and a mate refused is worse than a mate accepted.
const { Chess } = require('chess.js');

/// The verdict's label for a mate the author did not write.
const DIFFERENT_MATE = 'a different mate, but mate';

/// Strips the decoration SAN carries so `Qf1#`, `Qf1+` and `Qf1` compare equal
/// once the board has already told us what the move actually does.
function bareSan(san) {
  return String(san || '').trim().replace(/[+#!?]+$/g, '');
}

/**
 * Judge one attempt.
 *
 * Returns { correct, reason, playedSan } — `playedSan` is the move as the board
 * understands it, so the caller can record what was actually tried rather than
 * what was typed.
 *
 * **`reason` is read twice and by two different kinds of reader**, which is why
 * the wording below is not uniform. A *false* verdict's reason is drawn verbatim
 * in the wrong-answer banner of `lesson_viewer_screen.dart`, so it is a sentence
 * a child reads. A *true* verdict's reason is never shown — the screen writes
 * its own "Correct." — but `custom_puzzle_solver_screen.dart` compares one of
 * them, `'a different mate, but mate'`, to decide whether to explain that a
 * different mate still counted. So those three are labels for code, and
 * changing one of them is a change to the wire the app reads: change both ends
 * in the same commit or the explanation silently stops appearing.
 */
function judgeAttempt({ fen, solutionSan, moveSan, acceptedSans = [] }) {
  if (!fen || !solutionSan) {
    return { correct: false, reason: 'The position or the solution is missing.', playedSan: null };
  }

  let board;
  try {
    board = new Chess(fen);
  } catch {
    return { correct: false, reason: 'The position is not valid.', playedSan: null };
  }

  let played;
  try {
    played = board.move(String(moveSan || '').trim());
  } catch {
    played = null;
  }
  if (!played) {
    return { correct: false, reason: 'That move is not possible in this position.', playedSan: null };
  }

  // The author's move is always right.
  if (bareSan(played.san) === bareSan(solutionSan)) {
    return { correct: true, reason: "the author's move", playedSan: played.san };
  }

  // A move the author listed as also right.
  //
  // Chess positions frequently have several equally good answers, and a child
  // who finds a different sound defence must not read "wrong". The author's
  // move stays the one the lesson continues on — the caller says so — but the
  // verdict here is simply correct.
  const accepted = Array.isArray(acceptedSans) ? acceptedSans : [];
  if (accepted.some((san) => bareSan(san) === bareSan(played.san))) {
    return { correct: true, reason: 'another correct move', playedSan: played.san };
  }

  // A different mate is still a mate — whatever the author's own move does.
  // The label is read by the app (the solver says it aloud, the review reports
  // it); it is a wire value, not copy.
  if (board.isCheckmate()) {
    return { correct: true, reason: DIFFERENT_MATE, playedSan: played.san };
  }

  return { correct: false, reason: 'That is not the move the exercise asks for.', playedSan: played.san };
}

// „Can this be given to a student at all?" used to be answered here. It moved
// to `exercise.js` with everything else that reads what a row asks.

/**
 * Judge the moves a student has played so far in a line.
 *
 * [solution] is what `exercise.readSolution` returns — one step per move of
 * the student, `accept[0]` the move the line goes on from, `reply` the move
 * that answers it. [moves] are the student's own moves only, first to last;
 * the replies are this side's to give, one at a time, and **never ahead of
 * the move that earns them**: the answer to move two is not in the response to
 * move one.
 *
 * Every move in the list is judged, not only the last. A client that sent
 * `['anything', 'anything', 'Qxe5#']` would otherwise be asking to be judged on
 * the last step of a line it never played.
 *
 * **The line goes on from the author's move**, whatever accepted move was
 * played — the rule tutorials already keep. The replies were written after the
 * author's move and may not even be legal after another; `continuesOn` tells
 * the caller which move to show before the reply. **A different mate is
 * accepted at any step — `judgeAttempt`'s rule — and ends the line there**:
 * done, with no reply and nothing to continue on, because the replies were
 * written for a game that is no longer being played.
 *
 * Returns `{ correct, done, reason, playedSan, step, reply, continuesOn }`.
 * `step` is the index of the move the verdict is about.
 */
function judgeLine({ fen, solution, moves }) {
  const nothing = { done: false, playedSan: null, step: 0, reply: null, continuesOn: null };
  if (!fen || !Array.isArray(solution) || solution.length === 0) {
    return { ...nothing, correct: false, reason: 'The position or the solution is missing.' };
  }
  if (!Array.isArray(moves) || moves.length === 0) {
    return { ...nothing, correct: false, reason: 'No move was sent.' };
  }
  if (moves.length > solution.length) {
    return { ...nothing, correct: false, reason: 'More moves were sent than the line has.' };
  }

  let board;
  try {
    board = new Chess(fen);
  } catch {
    return { ...nothing, correct: false, reason: 'The position is not valid.' };
  }

  for (let i = 0; i < moves.length; i += 1) {
    const step = solution[i];
    const [main, ...others] = step.accept;
    const verdict = judgeAttempt({
      fen: board.fen(), solutionSan: main, acceptedSans: others, moveSan: moves[i],
    });
    if (!verdict.correct) {
      return { ...nothing, ...verdict, step: i };
    }
    if (verdict.reason === DIFFERENT_MATE) {
      return { ...nothing, ...verdict, step: i, done: true };
    }
    const authors = board.move(main);
    const onTheLine = bareSan(authors.san) === bareSan(verdict.playedSan);
    if (step.reply) board.move(step.reply);

    if (i === moves.length - 1) {
      const done = i === solution.length - 1;
      return {
        ...verdict,
        step: i,
        done,
        reply: step.reply ?? null,
        continuesOn: !done && !onTheLine ? authors.san : null,
      };
    }
  }
  // Unreachable: the loop returns on its last turn.
  return { ...nothing, correct: false, reason: 'No move was sent.' };
}

module.exports = { judgeAttempt, judgeLine, bareSan };
