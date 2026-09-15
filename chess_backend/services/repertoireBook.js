// repertoireBook.js — the book beside the board, and the one move it enters.
//
// Two rules from docs/PLAN-REPERTOAR-RUCNO.md, both written here once:
//
//   * **The book is simply there.** The opening book is a file on this server,
//     so a position nobody has looked at is read from it and stored on the
//     spot. There is no „open the book" step and nothing to spend.
//   * **One opponent move is entered for the student**: when a move of theirs
//     is kept for the first time, the book's most played reply after it goes in
//     with it, as an ordinary entered move they can delete. Without it a student
//     can build a careful answer to an obscure sideline and never meet the move
//     most games continue with. Every other opponent move is played by hand.

const logger = require('./logger');
const { OpeningBookUnavailable } = require('./openingBook');
const { openingJudge } = require('./openingJudgeService');
const { rememberReplies } = require('./repertoireDrillService');
const { step, enteredReplies } = require('./repertoireFrontier');
const {
  addMove, addExtraReply, fenKey, storedBook,
} = require('./repertoireService');

/// What the book says about a position, filled from the local book when it has
/// never been stored.
///
/// `unavailable` carries the book's own reason when the file cannot be read,
/// so a screen says „the book is not available" rather than drawing an empty
/// list that reads as a position nobody plays. A position the book has no
/// games for answers `opened: false` and nothing is stored.
async function bookAt(pool, userId, { color, fen, judge = openingJudge }) {
  const stored = await storedBook(pool, userId, { color, fen });
  if (stored.opened) return stored;

  let answer;
  try {
    answer = await judge.replies(fen);
  } catch (err) {
    if (err instanceof OpeningBookUnavailable) {
      logger.error(`[BOOK] ${err.reason}: ${err.message}`);
      return { ...stored, unavailable: err.reason };
    }
    throw err;
  }
  if ((answer.all ?? []).length === 0) return stored;
  await rememberReplies(pool, { fen, moves: answer.all });
  return storedBook(pool, userId, { color, fen });
}

/// Keeps a move of the student's, and enters the book's top reply after it.
///
/// Only when the move is new. Playing a move already kept is the student going
/// back to look, and re-entering the top reply then would put back a move they
/// deleted on purpose. And only when nothing is entered after it yet — a
/// position reached by transposition that already has the student's replies is
/// theirs, not the book's.
async function keepMove(pool, userId, {
  color, fen, uci, san, verdict = null, judge = openingJudge,
}) {
  const kept = await addMove(pool, userId, { color, fen, uci, san, verdict });
  const answer = { ...kept, topReply: null };
  if (kept?.inserted !== true) return answer;

  const after = step(fen, uci);
  if (after === null) return answer;
  const afterKey = fenKey(after.fen);
  const entered = await enteredReplies(pool, userId, color, [afterKey]);
  if ((entered.get(afterKey) ?? []).length > 0) return answer;

  const book = await bookAt(pool, userId, { color, fen: after.fen, judge });
  const top = book.replies?.[0];
  if (!top) return answer;
  await addExtraReply(pool, userId, {
    color, fen: after.fen, uci: top.uci, san: top.san,
  });
  return { ...answer, topReply: { uci: top.uci, san: top.san, fen: after.fen } };
}

module.exports = { bookAt, keepMove };
