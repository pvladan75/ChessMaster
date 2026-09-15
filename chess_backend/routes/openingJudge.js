// openingJudge.js — "what is this move: theory, playable, or a mistake?"
//
// Two guards, for two different dangers. `authenticateToken` keeps the route
// from becoming an open proxy onto Lichess's cloud evaluation the moment this
// server is reachable from the internet. The limiter keeps a client stuck in a
// loop from turning into a scan of a service somebody else runs.
//
// Until 15.9.2026 there was a third rule: the caller had to send a Lichess
// token of their own, because judging asked the Lichess explorers four times a
// move. The book is a file on this server now (`docs/PLAN-OTVARANJA-LOKALNO.md`)
// and the evaluation answers anonymously, so there is no token to send and no
// allowance to protect — and a repertoire can be built by anybody signed in.

const express = require('express');
const router = express.Router();
const rateLimit = require('express-rate-limit');
const logger = require('../services/logger');
const { authenticateToken } = require('../middleware/auth');
const { pool } = require('../db');
const {
  openingJudge, OpeningJudgeUnavailable,
} = require('../services/openingJudgeService');
const { OpeningBookUnavailable } = require('../services/openingBook');
const { rememberReplies } = require('../services/repertoireDrillService');

// Judging is asked for by hand, one move at a time, and repeats come from the
// cache. This cap is far above a person clicking and only bites a loop.
const judgeLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 40,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests to judge moves. Please wait a moment.' },
});

/// One answer for a failure, the same on both routes. A book that is missing
/// and a Lichess that is refusing are both loud and both carry their reason,
/// because from the app they look identical — no verdict — and this line is the
/// only place the difference survives.
function refuse(res, err, whatFailed) {
  if (err instanceof RangeError) {
    return res.status(400).json({ error: err.message });
  }
  if (err instanceof OpeningBookUnavailable) {
    logger.error(`[BOOK] ${err.reason}: ${err.message}`);
    return res.status(err.status).json({ error: err.message, reason: err.reason });
  }
  if (err instanceof OpeningJudgeUnavailable) {
    logger.error(`[JUDGE] ${err.reason}: ${err.message}`);
    return res.status(err.status).json({ error: err.message, reason: err.reason });
  }
  logger.error(`[JUDGE] Neočekivana greška: ${err.message}`);
  return res.status(500).json({ error: whatFailed });
}

// GET /opening-judge?fen=...&move=...
//
// A `minRating` the app still sends selects nothing: there is one book.
router.get('/', authenticateToken, judgeLimiter, async (req, res) => {
  const { fen, move } = req.query;
  try {
    res.json(await openingJudge.judge(fen, move));
  } catch (err) {
    refuse(res, err, 'Failed to judge move.');
  }
});

// GET /opening-judge/replies?fen=...
//
// The other half of the build loop: which of the opponent's answers are worth
// preparing for, and how much is left uncovered. Same route file because it is
// the same book and the same judge.
router.get('/replies', authenticateToken, judgeLimiter, async (req, res) => {
  const { fen } = req.query;
  try {
    const answer = await openingJudge.replies(fen);

    // Kept for the drill and the tree, which read it without asking again. The
    // rows are about a position and never about a person, so one student's
    // building draws the next student's tree too. A failure to store is not a
    // failure to answer: the caller asked what the book says, and it says it
    // whether or not we managed to write it down.
    try {
      await rememberReplies(pool, { fen, moves: answer.all ?? [] });
    } catch (err) {
      logger.error(`[JUDGE] Odgovori nisu sačuvani: ${err.message}`);
    }

    res.json(answer);
  } catch (err) {
    refuse(res, err, 'Failed to read opponent replies.');
  }
});

module.exports = router;
