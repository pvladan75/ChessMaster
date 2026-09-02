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
  storedBook,
  importedMoves,
  forgetImportedMoves,
  deleteRepertoire,
  setGate,
} = require('../services/repertoireService');
const { frontier } = require('../services/repertoireFrontier');
const {
  drillLine, drillBranches, tree: repertoireTree,
} = require('../services/repertoireLine');
const {
  buildSpine, MAX_SPINE_DEPTH, MIN_SPINE_GAMES,
} = require('../services/repertoireSpine');
const { OpeningJudgeUnavailable } = require('../services/openingJudgeService');
const {
  orphansOfRemoving, pruneKeys,
} = require('../services/repertoirePrune');
const {
  putNote, notesFor, disagreements,
} = require('../services/repertoireNotes');
const {
  putComment, removeComment, commentsFor,
} = require('../services/repertoireComments');
const {
  orphansOfDeleting, deleteRepertoire: deleteRepertoireRow, colorStats,
  eraseColor,
} = require('../services/repertoireErase');
const rateLimit = require('express-rate-limit');

// A spine is up to two dozen book requests in one call, against a token that
// serves every child using this app. Judging is capped at 40 a minute for a
// person clicking; this is capped at six because each one is a burst.
const spineLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 6,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Previše kičmi u kratkom roku. Sačekajte minut.' },
});

/// The repertoire's **gate**: the one move it goes through at its root.
///
/// Read from the query on every scoped route, because two repertoires can start
/// from the same position and mean two different openings — from the Italian
/// after 3...Bc5, one plays 4.b4 and the other 4.0-0. The moves belong to
/// (user, colour) and stay in one graph; what the gate narrows is the **view**,
/// so the tree, the queue, the map and the drill are about one opening.
///
/// Absent means what it always meant: the whole graph from that root.
function gateOf(query) {
  const gate = query?.gateUci;
  return typeof gate === 'string' && gate.trim() !== '' ? gate.trim() : null;
}

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

// POST /repertoire  { name, color, rootFen, rootPath, viaUci }
//
// `rootPath` is how the student got to the root — the SAN moves they played on
// the board before pressing "build from here". Stored so the breadcrumb can
// read from move one instead of pretending the game began wherever they
// stopped.
//
// `viaUci` is the gate — the move this repertoire goes through at its root.
// Sent when the position it starts from already holds another repertoire's
// first move, which is the case that made it necessary.
router.post('/', authenticateToken, (req, res) => {
  const { name, color, rootFen, rootPath, viaUci } = req.body ?? {};
  answer(
    res,
    createRepertoire(pool, req.user.id, {
      name, color, rootFen, rootPath, viaUci,
    }),
    'Repertoar nije mogao da se napravi.',
  );
});

// PUT /repertoire/gate  { id, viaUci }
//
// Sets, changes or clears the gate of a repertoire that already exists — which
// is most of them: the repertoires that most need one were built before the
// column was. `viaUci: null` clears it, back to the whole graph.
//
// Above `/:id` for the same reason the comment routes are: `/gate` is one path
// segment.
router.put('/gate', authenticateToken, (req, res) => {
  const { id, viaUci } = req.body ?? {};
  answer(
    res,
    setGate(pool, req.user.id, { id, viaUci: viaUci ?? null }),
    'Potez kroz koji ide repertoar nije mogao da se sačuva.',
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

// GET /repertoire/removal?id=12[&minRating=1600] — what deleting a repertoire
// would take with it, before anything is deleted.
//
// Reachable from this repertoire's root, minus everything reachable from the
// other roots of the same colour: a position two repertoires share is not
// stranded by losing one of them. When this is the last repertoire of its
// colour there is no second set, and the count is everything the walk reaches —
// which is exactly the number worth reading before pressing the button.
router.get('/removal', authenticateToken, (req, res) => {
  answer(
    res,
    orphansOfDeleting(pool, req.user.id, {
      id: req.query.id,
      minRating: Number(req.query.minRating) || 0,
      // The keys themselves stay on the server: they are a list of FENs the
      // screen has no use for, and `positions` — how many of them actually
      // hold moves — is the number the sentence "18 moves in 12 positions" is
      // made of. `stranded` is the wider count, kept because it is what the
      // delete will sweep.
    }).then(({ keys, ...rest }) => ({ ...rest, stranded: keys.length })),
    'Nije moglo da se izračuna šta bi brisanje odnelo.',
  );
});

// GET /repertoire/color?color=b — everything stored for one side, counted.
//
// The question the owner actually had, and the one nothing could answer: delete
// every repertoire of a colour and the moves stay, with no root left for the
// prune to reason from and no screen that can reach them. This counts them.
router.get('/color', authenticateToken, (req, res) => {
  answer(
    res,
    colorStats(pool, req.user.id, { color: req.query.color }),
    'Stanje boje nije moglo da se pročita.',
  );
});

// DELETE /repertoire/color?color=b[&comments=1] — emptying a side.
//
// Every move, cut, extra reply, attempt, review and evaluation for that colour.
// The repertoires themselves stay: they are a name and a starting point, and
// somebody emptying the moves is starting that opening again rather than
// disowning it.
//
// The comments the student wrote stay too, unless `comments=1`. Prose is the
// one thing here nothing can recompute.
//
// Registered before `/:id`, or Express would read "color" as an id.
router.delete('/color', authenticateToken, (req, res) => {
  answer(
    res,
    eraseColor(pool, req.user.id, {
      color: req.query.color,
      includeComments: req.query.comments === '1'
        || req.query.comments === 'true',
    }),
    'Potezi nisu mogli da se obrišu.',
  );
});

// The comment routes sit above `/:id` on purpose: `/comment` is a single
// path segment, so Express would otherwise match it as an id and answer
// "Repertoar nije imenovan brojem". `/node/...` is safe where it stands
// because `/:id` matches one segment and those are two.
// PUT /repertoire/comment  { color, fen, body }
//
// What the student wrote about a position, in their own words. Its own table
// rather than a field on the note: a note is the engine's answer and is
// rewritten by every deeper search, and `putNote` refuses a row with no
// evaluation in it — which is exactly the row a comment on an un-analysed
// position needs.
//
// An empty body deletes the row. A screen that saved an emptied box would
// otherwise leave a comment card with nothing in it on a position nobody has
// said anything about.
router.put('/comment', authenticateToken, (req, res) => {
  const body = req.body ?? {};
  answer(
    res,
    putComment(pool, req.user.id, {
      color: body.color,
      fen: body.fen,
      body: body.body,
    }),
    'Komentar nije mogao da se sačuva.',
  );
});

// DELETE /repertoire/comment?color=b&fen=...
router.delete('/comment', authenticateToken, (req, res) => {
  const { color, fen } = req.query;
  answer(
    res,
    removeComment(pool, req.user.id, { color, fen }),
    'Komentar nije mogao da se obriše.',
  );
});

// GET /repertoire/comments?color=b[&keys=a,b,c]
//
// Every comment for that side in one call, shaped like `/notes` and read by the
// same caller: the tree draws a hundred cards, and a request per card is a
// request per card.
router.get('/comments', authenticateToken, (req, res) => {
  const { color, keys } = req.query;
  answer(
    res,
    commentsFor(pool, req.user.id, {
      color,
      keys: typeof keys === 'string' && keys.trim() !== ''
        ? keys.split(',').map((key) => key.trim()).filter((key) => key !== '')
        : null,
    }),
    'Komentari nisu mogli da se pročitaju.',
  );
});

// DELETE /repertoire/:id[?moves=1&comments=1]
//
// Without `moves`, what it always was: the name and the starting point, never
// the moves — they belong to the colour, and another repertoire of that colour
// may be standing on them.
//
// With it, the moves only this repertoire reaches go as well, in the same
// transaction. `/removal` is the count to show first.
router.delete('/:id', authenticateToken, (req, res) => {
  const withMoves = req.query.moves === '1' || req.query.moves === 'true';
  answer(
    res,
    withMoves
      ? deleteRepertoireRow(pool, req.user.id, {
        id: req.params.id,
        withMoves: true,
        includeComments: req.query.comments === '1'
          || req.query.comments === 'true',
        minRating: Number(req.query.minRating) || 0,
      })
      : deleteRepertoire(pool, req.user.id, req.params.id),
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

// POST /repertoire/spine  { color, rootFen, depth, minRating, minGames }
// Header: X-Lichess-Token
//
// The trunk: the most played move for both sides, `depth` of the student's
// moves deep. Everything it writes is `source = 'auto'` — a draft the drill
// never asks about until somebody confirms it — and it never overwrites a
// position that already has a move, which is what makes it safe to re-run and
// makes "continue from here" the same operation as "start here".
//
// Synchronous on purpose. Two paced requests per move is a few seconds, and the
// one background job this project had was deleted for taking too long and
// falling over.
router.post('/spine', authenticateToken, spineLimiter, (req, res) => {
  const body = req.body ?? {};
  answer(
    res,
    buildSpine(pool, req.user.id, {
      color: body.color,
      rootFen: body.rootFen,
      depth: body.depth,
      minRating: body.minRating,
      minGames: body.minGames,
      token: req.get('X-Lichess-Token') || '',
    }).catch((err) => {
      // The book is the one thing this cannot do without, and "no token" is a
      // sentence the caller can act on rather than a five hundred.
      if (err instanceof OpeningJudgeUnavailable) {
        const wrapped = new RangeError(err.message);
        wrapped.reason = err.reason;
        throw wrapped;
      }
      throw err;
    }),
    'Kičma nije mogla da se napravi.',
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

// GET /repertoire/book?color=b&fen=...&minRating=1600
//
// What the opponent plays here, out of what has already been fetched — by
// anybody. **No Lichess request.** The panel that sits beside the board follows
// it around, and one token serves every child using this app, so a list that
// refetched on every click would spend their allowance on a drawing nobody
// asked for.
//
// `opened: false` means nobody has ever looked here, which the screen turns
// into an offer to look rather than into "the opponent plays nothing".
router.get('/book', authenticateToken, (req, res) => {
  const { color, fen, minRating } = req.query;
  answer(
    res,
    storedBook(pool, req.user.id, {
      color, fen, minRating: Number(minRating) || 0,
    }),
    'Knjiga nije mogla da se pročita.',
  );
});

// PUT /repertoire/note  { color, fen, evalCp, mateIn, evalDepth, bestUci,
//                        bestLineSan }
//
// What the engine said about one position. Information and nothing else: the
// build screen's verdict comes from the opening judge — "is this sound, judged
// by games real people played" — and a second opinion from a different notion
// of "good" on the same card is how a screen starts contradicting itself in
// front of a child. What the number is for is `/disagreements` below.
//
// A shallower answer never overwrites a deeper one, and the reply says which of
// the two is stored — "yours was kept because it was deeper" and "nothing
// happened" look identical from outside and are not.
//
// The eval is computed on the client, which is the shape `tablebaseService`
// refuses for the endgame drill. It is acceptable here for one reason worth
// writing down: nobody cheats themselves out of an engine eval, and this number
// grades nothing. If it ever starts grading anything, that reasoning is void.
router.put('/note', authenticateToken, (req, res) => {
  const body = req.body ?? {};
  answer(
    res,
    putNote(pool, req.user.id, {
      color: body.color,
      fen: body.fen,
      evalCp: body.evalCp,
      mateIn: body.mateIn ?? null,
      evalDepth: body.evalDepth ?? 0,
      bestUci: body.bestUci ?? null,
      bestLineSan: body.bestLineSan ?? null,
    }),
    'Ocena nije mogla da se sačuva.',
  );
});

// GET /repertoire/notes?color=b[&keys=a,b,c]
//
// Every eval this student has for that side, in one call — the tree draws a
// hundred cards and a request per card is a request per card. `keys` narrows it
// for a caller that knows which positions it needs.
router.get('/notes', authenticateToken, (req, res) => {
  const { color, keys } = req.query;
  answer(
    res,
    notesFor(pool, req.user.id, {
      color,
      keys: typeof keys === 'string' && keys.trim() !== ''
        ? keys.split(',').map((key) => key.trim()).filter((key) => key !== '')
        : null,
    }),
    'Ocene nisu mogle da se pročitaju.',
  );
});

// GET /repertoire/disagreements?color=b&rootFen=...&rootPath=e4+c5
//     [&fromFen=...&minRating=1600&limit=50]
//
// The review list: where the engine's move is not the one that was chosen,
// worst first. This is what the evals are *for* — no flag on any card, one list
// gone through deliberately.
//
// Derived from the notes and the moves, so no new judgement is made anywhere
// and no Lichess request is spent. A position the engine has never been asked
// about is not in the list: "not asked" and "agrees" are different answers, and
// the counts beside the list say which one a short list means.
router.get('/disagreements', authenticateToken, (req, res) => {
  const { color, rootFen, rootPath, minRating, fromFen, limit } = req.query;
  answer(
    res,
    disagreements(pool, req.user.id, {
      color,
      rootFen,
      gateUci: gateOf(req.query),
      rootPath: typeof rootPath === 'string' && rootPath.trim() !== ''
        ? rootPath.trim().split(/\s+/)
        : [],
      minRating: Number(minRating) || 0,
      fromFen: typeof fromFen === 'string' && fromFen.trim() !== ''
        ? fromFen
        : null,
      limit: Number(limit) || undefined,
    }),
    'Spisak neslaganja nije mogao da se sastavi.',
  );
});

// GET /repertoire/node/orphans?color=b&fen=...&uci=g8f6&minRating=1600
//
// What removing that move would strand, without removing anything. Asked
// *before* the removal, because "would this still be reachable without that
// move" cannot be answered once the move is gone.
//
// Positions, and how many moves in them are drafts and how many are decisions —
// so a screen can take the first silently and ask about the second. Losing an
// evening's work to a changed second move with no sentence about it is the kind
// of thing that happens once and ends trust in a feature.
router.get('/node/orphans', authenticateToken, (req, res) => {
  const { color, fen, uci, minRating } = req.query;
  answer(
    res,
    orphansOfRemoving(pool, req.user.id, {
      color, fen, uci, minRating: Number(minRating) || 0,
    }),
    'Nije moglo da se izračuna šta ostaje bez veze.',
  );
});

// POST /repertoire/prune  { color, keys, includeDecisions, minRating }
//
// Takes out positions that nothing reaches any more. Drafts go by default;
// decisions only when the caller says so, which is what the count from
// `/node/orphans` is for.
//
// Every key is re-checked against the roots first: the answer to "is this still
// unreachable" can change between the question and the confirmation, and a
// sweep that trusted a minute-old list would delete a line that is back in use.
router.post('/prune', authenticateToken, (req, res) => {
  const body = req.body ?? {};
  answer(
    res,
    pruneKeys(pool, req.user.id, {
      color: body.color,
      keys: Array.isArray(body.keys) ? body.keys : [],
      includeDecisions: body.includeDecisions === true,
      minRating: Number(body.minRating) || 0,
    }),
    'Orezivanje nije uspelo.',
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
      gateUci: gateOf(req.query),
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
      gateUci: gateOf(req.query),
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
//     [&fromFen=...][&viaFen=...&viaUci=d2d4][&exclude=...&exclude=...]
//
// A line to rehearse and the question at the end of it, instead of a bare board
// four moves into something with no way to tell how it got there.
//
// The replay starts at the deepest position the student already knows cold, not
// at move one — twelve plies of rehearsal to reach one question is how a drill
// stops being opened. `fromFen` narrows the whole thing to one branch, which is
// what makes it usable the day after a build session.
//
// `viaFen` + `viaUci` narrow it further, to the lines that go through one
// decision: a repertoire keeps more than one move in plenty of positions, and
// "the line behind my main move" was a thing the student could see on the board
// and had no way to ask for.
//
// `exclude` drops positions already refused this session, which is what makes
// "another line" mean anything — the queue is deterministic and skipping writes
// nothing down, so without it the same line came back every time.
//
// The moves in `prefix` are played, never graded. Only the position at the end
// is answered, through the same `/drill/answer` as before.
router.get('/drill/line', authenticateToken, (req, res) => {
  const {
    color, rootFen, rootPath, minRating, fromFen, viaFen, viaUci, ahead,
  } = req.query;
  const exclude = Array.isArray(req.query.exclude)
    ? req.query.exclude.filter((k) => typeof k === 'string')
    : (typeof req.query.exclude === 'string' ? [req.query.exclude] : []);
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
      // The chosen road out of a fork. Without these two reaching the service,
      // "Vežbaj 0-0" was a button that changed the sentence above the board and
      // nothing else — the query still came back through whichever move the
      // schedule preferred.
      viaFen: typeof viaFen === 'string' && viaFen.trim() !== ''
        ? viaFen
        : null,
      viaUci: typeof viaUci === 'string' && viaUci.trim() !== ''
        ? viaUci
        : null,
      // What was refused this session. The queue is a deterministic
      // `ORDER BY due_at LIMIT 1`, so without it "Druga linija" asked for the
      // same line it had just been given.
      exclude,
      // Practising before a position is due. Nothing is written down for it,
      // so it cannot be used to push an interval out.
      ahead: ahead === '1' || ahead === 'true',
      gateUci: gateOf(req.query),
    }),
    'Linija za vežbanje nije mogla da se sastavi.',
  );
});

// GET /repertoire/drill/branches?color=b&rootFen=...&rootPath=e4+c5&minRating=1600
//
// The opponent's first answers, each with how many positions in it are waiting.
// This is what a session is chosen by: a repertoire is a handful of branches,
// and the ten positions that hang together are the ones worth meeting in a row
// — mixing every position in the colour into one queue is right for a schedule
// and wrong for sitting down to practise.
//
// `dueKeys` comes with each branch so a run through it can grade the positions
// that are due and leave the rest alone. Costs no Lichess request, like
// everything that reads what was built.
router.get('/drill/branches', authenticateToken, (req, res) => {
  const { color, rootFen, rootPath, minRating } = req.query;
  answer(
    res,
    drillBranches(pool, req.user.id, {
      color,
      rootFen,
      gateUci: gateOf(req.query),
      rootPath: typeof rootPath === 'string' && rootPath.trim() !== ''
        ? rootPath.trim().split(/\s+/)
        : [],
      minRating: Number(minRating) || 0,
    }),
    'Grane za vežbanje nisu mogle da se pročitaju.',
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

// POST /repertoire/drill/answer
//   { color, fen, uci, revealed, minRating, practice, onlyIfDue }
//
// Grades the move against what the student decided, reschedules it, and hands
// back the opponent's reply so the line can go on. The reply comes from the
// stored book, so a drill costs no Lichess request at all - which is what lets
// somebody without a token of their own practise what they built last week.
//
// `practice` judges and writes nothing. `onlyIfDue` writes only when this
// position was what the schedule asked for, which is what a line walked on past
// its question needs — see `answer` for why the two are not the same flag.
router.post('/drill/answer', authenticateToken, (req, res) => {
  const {
    color, fen, uci, revealed, minRating, practice, onlyIfDue,
  } = req.body ?? {};
  answer(
    res,
    gradeAnswer(pool, req.user.id, {
      color,
      fen,
      uci,
      revealed: !!revealed,
      practice: !!practice,
      onlyIfDue: !!onlyIfDue,
    }).then(async (graded) => {
      const reply = await pickReply(pool, {
        fen: _fenAfterOrSame(fen, graded, uci),
        minRating: Number(minRating) || 0,
        // Whose preparation counts. A reply this student pressed "prepare this
        // too" on is theirs, and a draw that did not know who was asking would
        // refuse a move they chose by name.
        userId: req.user.id,
        color,
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
