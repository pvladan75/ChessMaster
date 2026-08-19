// customPuzzleJudge.js — deciding whether a child's move was right.
//
// A scanned position stores one move: the one the author printed. Comparing a
// child's answer to that string alone would be wrong in a way that matters —
// in a mate-in-one there is often more than one mate, and a student who finds a
// different one has solved the exercise. Being told "netačno" for a correct
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
 */
function judgeAttempt({ fen, solutionSan, moveSan }) {
  if (!fen || !solutionSan) {
    return { correct: false, reason: 'nedostaje pozicija ili rešenje', playedSan: null };
  }

  let board;
  try {
    board = new Chess(fen);
  } catch {
    return { correct: false, reason: 'pozicija nije ispravna', playedSan: null };
  }

  let played;
  try {
    played = board.move(String(moveSan || '').trim());
  } catch {
    played = null;
  }
  if (!played) {
    return { correct: false, reason: 'taj potez nije moguć u ovoj poziciji', playedSan: null };
  }

  // The author's move is always right.
  if (bareSan(played.san) === bareSan(solutionSan)) {
    return { correct: true, reason: 'autorov potez', playedSan: played.san };
  }

  // A different mate is still a mate, and the task was to mate.
  const solutionMates = /#$/.test(String(solutionSan).trim());
  if (solutionMates && board.isCheckmate()) {
    return { correct: true, reason: 'drugi mat, ali mat', playedSan: played.san };
  }

  return { correct: false, reason: 'nije traženi potez', playedSan: played.san };
}

/**
 * Can this position be given to a student at all?
 *
 * Two refusals, both loud. Without a solution nothing can judge the answer, and
 * a child would be told "netačno" whatever they played. A position still marked
 * for review is one we know we are unsure about, and homework is the last place
 * to find that out.
 */
function assignableProblem(row) {
  if (!row.solution_san) return 'nema rešenje, pa odgovor ne može da se oceni';
  if (row.needs_review) return 'označena je za proveru';
  return null;
}

module.exports = { judgeAttempt, assignableProblem, bareSan };
