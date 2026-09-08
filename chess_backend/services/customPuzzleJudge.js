// customPuzzleJudge.js — deciding whether a child's move was right.
//
// A scanned position stores one move: the one the author printed. Comparing a
// child's answer to that string alone would be wrong in a way that matters —
// in a mate-in-one there is often more than one mate, and a student who finds a
// different one has solved the exercise. Being told "wrong" for a correct
// mate is the kind of thing that makes a child distrust the app, and they would
// be right to.
//
// So the rule follows the task rather than the text: when the stored solution
// mates, any move that mates is accepted. Otherwise only the author's move is,
// because nothing here knows what else the position was meant to teach.
const { Chess } = require('chess.js');

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

  // A different mate is still a mate, and the task was to mate.
  const solutionMates = /#$/.test(String(solutionSan).trim());
  if (solutionMates && board.isCheckmate()) {
    return { correct: true, reason: 'a different mate, but mate', playedSan: played.san };
  }

  return { correct: false, reason: 'That is not the move the exercise asks for.', playedSan: played.san };
}

/**
 * Can this position be given to a student at all?
 *
 * Two refusals, both loud. Without a solution nothing can judge the answer, and
 * a child would be told "wrong" whatever they played. A position still marked
 * for review is one we know we are unsure about, and homework is the last place
 * to find that out.
 */
function assignableProblem(row) {
  if (!row.solution_san) return 'has no solution, so an answer cannot be judged';
  if (row.needs_review) return 'is marked for review';
  return null;
}

module.exports = { judgeAttempt, assignableProblem, bareSan };
