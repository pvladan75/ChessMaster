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
  addExtraReply,
  removeExtraReply,
  confirmNode,
  confirmLine,
  importedMoves,
  forgetImportedMoves,
  deleteRepertoire,
} = require('../services/repertoireService');
const { frontier } = require('../services/repertoireFrontier');
const { drillLine, tree: repertoireTree } = require('../services/repertoireLine');

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

// GET /repertoire/imported?color=b — how many moves nobody was ever asked about
// DELETE /repertoire/imported?color=b — and taking them out
//
// Until 31.8.2026 a repertoire could also be built out of imported games. It
// wrote through the same `addMove` as the build screen, into the same graph, so
// a move nobody had chosen was indistinguishable from a decision — and the
// drill went on to ask for it. The seed is gone; this is for what it left.
//
// The test is whether a kept attempt was ever written for the move, which is
// what the build screen writes the moment anything is kept. A heuristic, and
// the screen says so before it deletes anything.
router.get('/imported', authenticateToken, (req, res) => {
  answer(
    res,
    importedMoves(pool, req.user.id, { color: req.query.color }),
    'Broj uvezenih poteza nije mogao da se pročita.',
  );
});

router.delete('/imported', authenticateToken, (req, res) => {
  answer(
    res,
    forgetImportedMoves(pool, req.user.id, { color: req.query.color }),
    'Uvezeni potezi nisu mogli da se uklone.',
  );
});

// DELETE /repertoire/:id — the name and the starting point, never the moves.
router.delete('/:id', authenticateToken, (req, res) => {
  answer(
    res,
    deleteRepertoire(pool, req.user.id, req.params.id),
    'Repertoar nije mogao da se obriše.',
  );
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

// POST /repertoire/node/confirm  { color, fen, uci? }
//
// A generated move becomes a decision. Without `uci`, every draft in the
// position; with it, one move.
//
// Confirming is an act, and that is what makes generating moves safe to offer
// at all: until somebody says "yes, this one", a generated move is scaffolding
// — drawn, walked through, and never asked about by the drill. The archive seed
// had no such act, which is why it was deleted.
router.post('/node/confirm', authenticateToken, (req, res) => {
  const { color, fen, uci } = req.body ?? {};
  answer(
    res,
    confirmNode(pool, req.user.id, { color, fen, uci: uci ?? null }),
    'Potez nije mogao da se potvrdi.',
  );
});

// POST /repertoire/line/confirm  { color, fens: [...] }
//
// A whole line at once. One statement, because a line half confirmed is a line
// the student would have to walk twice.
router.post('/line/confirm', authenticateToken, (req, res) => {
  const { color, fens } = req.body ?? {};
  answer(
    res,
    confirmLine(pool, req.user.id, { color, fens }),
    'Linija nije mogla da se potvrdi.',
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

// POST /repertoire/node/reply  { color, fen, uci, san }
//
// "Prepare this opponent move too." The wave covers 80% of what is played, up
// to four moves, and names the remainder; this is the way through that wall,
// one move at a time.
//
// `fen` is the position the opponent answers *from* — after the student's own
// move — and `uci` is their reply. Stored per student, never by flipping
// `opening_replies.covered`, which is shared by everybody.
router.post('/node/reply', authenticateToken, (req, res) => {
  const { color, fen, uci, san } = req.body ?? {};
  answer(
    res,
    addExtraReply(pool, req.user.id, { color, fen, uci, san }),
    'Potez nije mogao da se doda u pripremu.',
  );
});

// DELETE /repertoire/node/reply?color=b&fen=...&uci=g1f3
router.delete('/node/reply', authenticateToken, (req, res) => {
  const { color, fen, uci } = req.query;
  answer(
    res,
    removeExtraReply(pool, req.user.id, { color, fen, uci }),
    'Potez nije mogao da se izbaci iz pripreme.',
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

// GET /repertoire/tree?color=b&rootFen=...&rootPath=e4+c5&minRating=0&maxPly=16
//
// The repertoire as a picture: one node per ply, each saying whose move it is,
// how often the opponent plays it, and what state the position it leads to is
// in. Same walk, same two tables, no Lichess request.
//
// `maxPly` keeps it a picture rather than a wall. A seeded repertoire runs to
// thousands of moves and nobody reads a drawing of all of them; the answer says
// when the depth was reached.
router.get('/tree', authenticateToken, (req, res) => {
  const { color, rootFen, rootPath, minRating, maxPly } = req.query;
  answer(
    res,
    repertoireTree(pool, req.user.id, {
      color,
      rootFen,
      rootPath: typeof rootPath === 'string' && rootPath.trim() !== ''
        ? rootPath.trim().split(/\s+/)
        : [],
      minRating: Number(minRating) || 0,
      maxPly: Math.min(Math.max(Number(maxPly) || 16, 2), 40),
    }),
    'Stablo repertoara nije moglo da se sastavi.',
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

// GET /repertoire/drill/line?color=b&rootFen=...&rootPath=e4+c5&minRating=1600
//     [&fromFen=...]
//
// A line to rehearse and the question at the end of it, instead of a bare board
// four moves into something with no way to tell how it got there.
//
// The replay starts at the deepest position the student already knows cold, not
// at move one — twelve plies of rehearsal to reach one question is how a drill
// stops being opened. `fromFen` narrows the whole thing to one branch, which is
// what makes it usable the day after a build session.
//
// The moves in `prefix` are played, never graded. Only the position at the end
// is answered, through the same `/drill/answer` as before.
router.get('/drill/line', authenticateToken, (req, res) => {
  const { color, rootFen, rootPath, minRating, fromFen, ahead } = req.query;
  answer(
    res,
    drillLine(pool, req.user.id, {
      color,
      rootFen,
      rootPath: typeof rootPath === 'string' && rootPath.trim() !== ''
        ? rootPath.trim().split(/\s+/)
        : [],
      minRating: Number(minRating) || 0,
      fromFen: typeof fromFen === 'string' && fromFen.trim() !== ''
        ? fromFen
        : null,
      // Practising before a position is due. Nothing is written down for it,
      // so it cannot be used to push an interval out.
      ahead: ahead === '1' || ahead === 'true',
    }),
    'Linija za vežbanje nije mogla da se sastavi.',
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
  const { color, fen, uci, revealed, minRating, practice } = req.body ?? {};
  answer(
    res,
    gradeAnswer(pool, req.user.id, {
      color, fen, uci, revealed: !!revealed, practice: !!practice,
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
