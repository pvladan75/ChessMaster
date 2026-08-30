// repertoire.js — the student's own opening decisions.
//
// Nothing here talks to Lichess, and that is the split worth keeping: the judge
// route spends the caller's token to say what a move is worth, and this one
// only records what the student decided about it. So this route works for
// anybody, token or not — a repertoire built last week can be read, edited and
// drilled with no allowance spent at all.
//
// Every query is scoped to `req.user.id`. A repertoire is nobody else's
// business, not even a trainer's, until there is a flow that says otherwise.

const express = require('express');
const { Chess } = require('chess.js');
const router = express.Router();
const logger = require('../services/logger');
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const {
  nextItem,
  revealPrimary,
  answer: gradeAnswer,
  pickReply,
  drillStats,
} = require('../services/repertoireDrillService');
const {
  createRepertoire,
  listRepertoires,
  nodeMoves,
  addMove,
  promoteMove,
  removeMove,
  recordAttempt,
  weakNodes,
  skipNode,
  unskipNode,
} = require('../services/repertoireService');
const { frontier } = require('../services/repertoireFrontier');

/// One place where a bad request becomes a 400 and everything else becomes a
/// 500 with a line in the log. Without it every handler grows its own copy and
/// they drift.
function answer(res, work, whatFailed) {
  return work.then(
    (value) => res.json(value),
    (err) => {
      if (err instanceof RangeError) {
        return res.status(400).json({ error: err.message });
      }
      // A name that is already taken is the caller's business, not a fault.
      if (err && err.code === '23505') {
        return res.status(409).json({ error: 'To ime je već zauzeto.' });
      }
      logger.error(`[REPERTOAR] ${whatFailed}: ${err.message}`);
      return res.status(500).json({ error: whatFailed });
    },
  );
}

// POST /repertoire  { name, color, rootFen, rootPath }
//
// `rootPath` is how the student got to the root — the SAN moves they played on
// the board before pressing "build from here". Stored so the breadcrumb can
// read from move one instead of pretending the game began wherever they
// stopped.
router.post('/', authenticateToken, (req, res) => {
  const { name, color, rootFen, rootPath } = req.body ?? {};
  answer(
    res,
    createRepertoire(pool, req.user.id, { name, color, rootFen, rootPath }),
    'Repertoar nije mogao da se napravi.',
  );
});

// GET /repertoire
router.get('/', authenticateToken, (req, res) => {
  answer(res, listRepertoires(pool, req.user.id),
    'Spisak repertoara nije mogao da se pročita.');
});

// GET /repertoire/node?color=b&fen=...
router.get('/node', authenticateToken, (req, res) => {
  const { color, fen } = req.query;
  answer(
    res,
    nodeMoves(pool, req.user.id, { color, fen }).then((moves) => ({ moves })),
    'Pozicija nije mogla da se pročita.',
  );
});

// POST /repertoire/node/move  { color, fen, uci, san, verdict }
router.post('/node/move', authenticateToken, (req, res) => {
  const { color, fen, uci, san, verdict } = req.body ?? {};
  answer(
    res,
    addMove(pool, req.user.id, { color, fen, uci, san, verdict }),
    'Potez nije mogao da se sačuva.',
  );
});

// POST /repertoire/node/primary  { color, fen, uci }
router.post('/node/primary', authenticateToken, (req, res) => {
  const { color, fen, uci } = req.body ?? {};
  answer(
    res,
    promoteMove(pool, req.user.id, { color, fen, uci }),
    'Glavni potez nije mogao da se promeni.',
  );
});

// DELETE /repertoire/node/move?color=b&fen=...&uci=g8f6
router.delete('/node/move', authenticateToken, (req, res) => {
  const { color, fen, uci } = req.query;
  answer(
    res,
    removeMove(pool, req.user.id, { color, fen, uci }),
    'Potez nije mogao da se ukloni.',
  );
});

// POST /repertoire/node/skip  { color, fen }
//
// "I am not preparing this." The only control in the build loop that makes the
// tree smaller — every other one adds — so it is stored rather than left to be
// said by closing the screen, which says the same thing for one session and
// forgets it.
//
// It stops the walk at this position and nothing else. A move already kept here
// stays kept and stays drilled: cutting is about how far to prepare, not about
// unlearning what was decided.
router.post('/node/skip', authenticateToken, (req, res) => {
  const { color, fen } = req.body ?? {};
  answer(
    res,
    skipNode(pool, req.user.id, { color, fen }),
    'Grana nije mogla da se odseče.',
  );
});

// DELETE /repertoire/node/skip?color=b&fen=...
router.delete('/node/skip', authenticateToken, (req, res) => {
  const { color, fen } = req.query;
  answer(
    res,
    unskipNode(pool, req.user.id, { color, fen }),
    'Grana nije mogla da se vrati.',
  );
});

// POST /repertoire/attempt  { color, fen, uci, san, verdict, kept, lookedUp }
//
// Written whether or not the move was kept. The rejected attempts are the point
// of the table: they are where the student's first instinct was wrong, and the
// drill will ask about those positions first.
router.post('/attempt', authenticateToken, (req, res) => {
  const { color, fen, uci, san, verdict, kept, lookedUp } = req.body ?? {};
  answer(
    res,
    recordAttempt(pool, req.user.id, {
      color, fen, uci, san, verdict, kept: !!kept, lookedUp: !!lookedUp,
    }),
    'Pokušaj nije mogao da se zabeleži.',
  );
});

// GET /repertoire/frontier?color=b&rootFen=...&rootPath=e4+c5&minRating=1600
//
// Where the student is, rebuilt from what they have already decided and the
// books already fetched. This is what makes closing the build screen safe: the
// queue was never a fact worth storing, and deriving it costs no Lichess
// request at all — so resuming is free, and free on any device.
router.get('/frontier', authenticateToken, (req, res) => {
  const { color, rootFen, rootPath, minRating, limit } = req.query;
  answer(
    res,
    frontier(pool, req.user.id, {
      color,
      rootFen,
      rootPath: typeof rootPath === 'string' && rootPath.trim() !== ''
        ? rootPath.trim().split(/\s+/)
        : [],
      minRating: Number(minRating) || 0,
      limit: Math.min(Math.max(Number(limit) || 200, 1), 500),
    }),
    'Pregled repertoara nije mogao da se izračuna.',
  );
});

// GET /repertoire/weak?color=b
router.get('/weak', authenticateToken, (req, res) => {
  const { color, limit } = req.query;
  answer(
    res,
    weakNodes(pool, req.user.id, {
      color,
      limit: Math.min(Math.max(Number(limit) || 20, 1), 100),
    }).then((nodes) => ({ nodes })),
    'Slabe pozicije nisu mogle da se pročitaju.',
  );
});

// GET /repertoire/drill/next?color=b
//
// The question and nothing else. What the student decided is deliberately not
// in the answer: a question that arrives with its answer attached is one a
// determined child reads out of the network log instead of out of memory.
router.get('/drill/next', authenticateToken, (req, res) => {
  const { color } = req.query;
  answer(
    res,
    Promise.all([
      nextItem(pool, req.user.id, { color }),
      drillStats(pool, req.user.id, { color }),
    ]).then(([item, stats]) => ({ item, stats })),
    'Sledeća pozicija nije mogla da se pročita.',
  );
});

// GET /repertoire/drill/reveal?color=b&fen=...
//
// Its own call because looking is a decision: the question never arrives with
// the answer attached, and asking for it is what makes the next answer count as
// recognised rather than remembered.
router.get('/drill/reveal', authenticateToken, (req, res) => {
  const { color, fen } = req.query;
  answer(
    res,
    revealPrimary(pool, req.user.id, { color, fen }),
    'Potez nije mogao da se pročita.',
  );
});

// POST /repertoire/drill/answer  { color, fen, uci, revealed, minRating }
//
// Grades the move against what the student decided, reschedules it, and hands
// back the opponent's reply so the line can go on. The reply comes from the
// stored book, so a drill costs no Lichess request at all - which is what lets
// somebody without a token of their own practise what they built last week.
router.post('/drill/answer', authenticateToken, (req, res) => {
  const { color, fen, uci, revealed, minRating } = req.body ?? {};
  answer(
    res,
    gradeAnswer(pool, req.user.id, {
      color, fen, uci, revealed: !!revealed,
    }).then(async (graded) => {
      const reply = await pickReply(pool, {
        fen: _fenAfterOrSame(fen, graded, uci),
        minRating: Number(minRating) || 0,
      });
      return { ...graded, reply };
    }),
    'Odgovor nije mogao da se oceni.',
  );
});

/// The position the opponent has to answer from: after the student's own move
/// when it was one of theirs, and after the primary when it was not — because a
/// line that carries on from a move the student has just been told is wrong
/// would be rehearsing the mistake.
function _fenAfterOrSame(fen, graded, uci) {
  const move = graded.outcome === 'unknown' && graded.primary
    ? graded.primary.uci
    : uci;
  try {
    const board = new Chess(fen);
    const played = board.move({
      from: move.slice(0, 2),
      to: move.slice(2, 4),
      promotion: move.length > 4 ? move[4] : undefined,
    });
    return played ? board.fen() : fen;
  } catch {
    return fen;
  }
}

module.exports = router;
