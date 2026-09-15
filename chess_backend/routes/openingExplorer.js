// openingExplorer.js — the opening book, for a signed-in user.
//
// Until 15.9.2026 this route was a proxy in front of the Lichess explorer, and
// its whole design was about a token: one belonging to this server, spent by
// every student at once, with a cache and a pacer to make that survivable.
// `docs/PLAN-OTVARANJA-LOKALNO.md` replaced the upstream with a file — games
// in which both players are rated 2200+, keyed by the Polyglot hash — so none
// of that is left. There is no allowance to spend, nothing to rate-limit
// ourselves against, and no failure that means „somebody else refused us".
//
// The two guards stay. `authenticateToken` because an endpoint reading a
// several-hundred-megabyte file must not be reachable by anyone who finds the
// URL, and the limiter because a client stuck in a loop is the same danger
// whatever it is asking.

const express = require('express');
const router = express.Router();
const rateLimit = require('express-rate-limit');
const logger = require('../services/logger');
const { authenticateToken } = require('../middleware/auth');
const { createOpeningBook, OpeningBookUnavailable } = require('../services/openingBook');

// The local opening database. Opened on the first question, not at start-up, so
// a server without the file serves everything else.
let openingBook = createOpeningBook();

/// What the panel draws at most, and what it draws when it does not say.
const MAX_MOVES = 30;
const DEFAULT_MOVES = 12;

// A student clicking through an opening asks once per move. This cap is well
// above that and only bites a client that has stopped asking questions and
// started hammering.
const explorerLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 90,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many requests to the opening database. Please wait a moment.' },
});

// GET /opening-explorer?fen=...&moves=12
//
// `minRating` is still accepted and selects nothing. There is one book — 2200+
// — because a student learns the sound move whatever their own rating; the
// parameter survives only because `opening_replies` is keyed by it and the
// repertoire still passes it everywhere. `test/opening_explorer_route.test.js`
// holds two values to the same answer so nobody comes to believe it filters.
router.get('/', authenticateToken, explorerLimiter, (req, res) => {
  const { fen, moves } = req.query;
  try {
    const asked = Number(moves);
    const limit = Number.isFinite(asked) && asked >= 1
      ? Math.min(Math.trunc(asked), MAX_MOVES)
      : DEFAULT_MOVES;
    const here = openingBook.answer(typeof fen === 'string' ? fen : '');
    const shown = here.moves.slice(0, limit);
    const total = here.white + here.draws + here.black;
    const inShown = shown.reduce((n, m) => n + m.white + m.draws + m.black, 0);

    res.json({
      fen,
      white: here.white,
      draws: here.draws,
      black: here.black,
      // The file holds no opening names, and a second table of them here would
      // be a second vocabulary to keep. The app names the position from the ECO
      // data it already ships — which gave back all 52 of Lichess's names on
      // the harness games, word for word.
      opening: null,
      moves: shown,
      // Games played here in moves the panel is not being shown: the ones past
      // the limit, and the ones a pruned file no longer lists. Without it the
      // shares under the moves would not add up to the count above them, and
      // nothing would say why.
      unlisted: total - inShown,
      // Not „nobody played this": „this file does not go that far".
      beyondBook: here.beyondBook,
    });
  } catch (err) {
    if (err instanceof RangeError) {
      return res.status(400).json({ error: err.message });
    }
    if (err instanceof OpeningBookUnavailable) {
      // Loud on purpose. A missing or unreadable file looks exactly like an
      // opening nobody has ever played, and only this line tells them apart
      // afterwards.
      logger.error(`[BOOK] ${err.reason}: ${err.message}`);
      return res.status(err.status).json({ error: err.message, reason: err.reason });
    }
    logger.error(`[BOOK] Neočekivana greška: ${err.message}`);
    res.status(500).json({ error: 'Failed to read the opening database.' });
  }
});

// POST /opening-explorer/masters-walk   { "fens": ["<FEN>", ...] }
//
// A game's positions in order, answered until the first one no game reached —
// what a tutorial made from a game says about its opening (phase 2 of
// `docs/PLAN-SKELET.md`). A POST because a game is up to sixty-four FENs, which
// is not a query string. The app calls it by this name, so it keeps it.
router.post('/masters-walk', authenticateToken, explorerLimiter, (req, res) => {
  try {
    res.json(openingBook.walk(req.body?.fens));
  } catch (err) {
    if (err instanceof RangeError) {
      return res.status(400).json({ error: err.message });
    }
    if (err instanceof OpeningBookUnavailable) {
      logger.error(`[BOOK] ${err.reason}: ${err.message}`);
      return res.status(err.status).json({ error: err.message, reason: err.reason });
    }
    logger.error(`[BOOK] Neočekivana greška: ${err.message}`);
    res.status(500).json({ error: 'Failed to read the opening database.' });
  }
});

/// For tests only: answer from [book] instead of the configured file.
router.useOpeningBook = (book) => {
  openingBook = book;
};

module.exports = router;
