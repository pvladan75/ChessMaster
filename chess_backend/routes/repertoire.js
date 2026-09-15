// repertoire.js — the student's own opening decisions.
//
// Nothing here talks to Lichess, and that is the split worth keeping: the judge
// route asks what a move is worth, and this one only records what the student
// played. Every entry in a repertoire is a move played on the board — the
// student's own, and the opponent's they entered — with the one exception
// `repertoireBook.keepMove` names (docs/PLAN-REPERTOAR-RUCNO.md).
//
// **No rating travels here any more.** There is one book (2200+, since
// `docs/PLAN-OTVARANJA-LOKALNO.md`), so a `minRating` the app still sends is
// not read by any handler: reading it would be believing it still selects
// something.
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
  promoteMove,
  removeMove,
  recordAttempt,
  weakNodes,
  addExtraReply,
  removeExtraReply,
  importedMoves,
  forgetImportedMoves,
  deleteRepertoire,
  setGate,
  repertoiresByIds,
} = require('../services/repertoireService');
const { bookAt, keepMove } = require('../services/repertoireBook');
const { repertoireProgress } = require('../services/repertoireProgress');
const { practisedSince } = require('../services/repertoirePractice');
const { frontier } = require('../services/repertoireFrontier');
const {
  drillLine, drillBranches, tree: repertoireTree,
} = require('../services/repertoireLine');
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

/// The repertoires a **combined** session runs over, or null for the old shape.
///
/// `ids=3,7`. The doors and their gates are read from the rows rather than sent
/// as parallel query parameters, which is the shape that goes wrong the first
/// time one of them is shorter than the other — and
/// it is also what lets a branch say which repertoire it came from, since the
/// name comes along with the row.
///
/// A `color` sent beside the ids has to agree with them. Preferring the rows
/// silently would answer a different question from the one that was asked, and
/// this endpoint has exactly one honest answer to a contradiction.
async function rootsFrom(query, userId) {
  const raw = Array.isArray(query?.ids)
    ? query.ids
    : (typeof query?.ids === 'string' ? query.ids.split(',') : []);
  const ids = raw
    .map((one) => String(one).trim())
    .filter((one) => one !== '')
    .map(Number)
    .filter((one) => Number.isInteger(one));
  if (ids.length === 0) return null;

  const roots = await repertoiresByIds(pool, userId, ids);
  const asked = query?.color;
  if (typeof asked === 'string' && asked !== '' && asked !== roots[0].color) {
    throw new RangeError('Color does not match selected repertoires.');
  }
  return roots;
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
        return res.status(409).json({ error: 'That name is already taken.' });
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
    'Repertoire could not be created.',
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
    'Repertoire gate move could not be saved.',
  );
});

// GET /repertoire/practice/today?since=<ISO>&color=w
//
// How much has actually been practised since the reader's own day started, so
// a screen can say it. `since` comes from the client because the day is theirs:
// a server counting in UTC tells a child in Belgrade at 01:00 that they have
// already practised tomorrow.
//
// Deliberately not read by anything that schedules. `repertoire_reviews` still
// decides what is due; this only counts work done, including the work done
// ahead of schedule that the schedule refuses — on purpose — to hear about.
router.get('/practice/today', authenticateToken, (req, res) => {
  const { since, color } = req.query;
  answer(
    res,
    practisedSince(pool, req.user.id, {
      since: typeof since === 'string' && since.trim() !== ''
        ? since.trim()
        : new Date().toISOString(),
      color: typeof color === 'string' && color.trim() !== ''
        ? color.trim()
        : null,
    }),
    'Could not read practised position count.',
  );
});

// GET /repertoire/progress
//
// How many positions each repertoire still has nobody's answer in, one entry
// per repertoire. A walk each, so the list screen asks for this *after* it has
// drawn its cards rather than before: the number is worth waiting a moment for
// and the list is not worth waiting at all for.
//
// There used to be a band here, and reading it wrong walked a book with no
// replies at that band and reported every repertoire finished — exactly what
// an empty `minRating=` did to the draft review. One book has no wrong band.
router.get('/progress', authenticateToken, (req, res) => {
  answer(
    res,
    repertoireProgress(pool, req.user.id),
    'Could not read repertoire progress.',
  );
});

// GET /repertoire
router.get('/', authenticateToken, (req, res) => {
  answer(res, listRepertoires(pool, req.user.id),
    'Could not read repertoire list.');
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
    'Could not read imported move count.',
  );
});

router.delete('/imported', authenticateToken, (req, res) => {
  answer(
    res,
    forgetImportedMoves(pool, req.user.id, { color: req.query.color }),
    'Could not remove imported moves.',
  );
});

// GET /repertoire/removal?id=12 — what deleting a repertoire
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
      // The keys themselves stay on the server: they are a list of FENs the
      // screen has no use for, and `positions` — how many of them actually
      // hold moves — is the number the sentence "18 moves in 12 positions" is
      // made of. `stranded` is the wider count, kept because it is what the
      // delete will sweep.
    }).then(({ keys, ...rest }) => ({ ...rest, stranded: keys.length })),
    'Could not calculate what deletion would remove.',
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
    'Could not read color status.',
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
    'Could not delete moves.',
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
    'Could not save comment.',
  );
});

// DELETE /repertoire/comment?color=b&fen=...
router.delete('/comment', authenticateToken, (req, res) => {
  const { color, fen } = req.query;
  answer(
    res,
    removeComment(pool, req.user.id, { color, fen }),
    'Could not delete comment.',
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
    'Could not read comments.',
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
      })
      : deleteRepertoire(pool, req.user.id, req.params.id),
    'Could not delete repertoire.',
  );
});

// GET /repertoire/node?color=b&fen=...
router.get('/node', authenticateToken, (req, res) => {
  const { color, fen } = req.query;
  answer(
    res,
    nodeMoves(pool, req.user.id, { color, fen }).then((moves) => ({ moves })),
    'Could not read position.',
  );
});

// POST /repertoire/node/move  { color, fen, uci, san, verdict }
//
// A move of the student's, played on the board. Kept for the first time, it
// brings the book's most played reply with it, entered as an opponent move they
// can delete; the answer names that reply as `topReply` so the board can go on
// to the position after it.
router.post('/node/move', authenticateToken, (req, res) => {
  const { color, fen, uci, san, verdict } = req.body ?? {};
  answer(
    res,
    keepMove(pool, req.user.id, { color, fen, uci, san, verdict }),
    'Could not save move.',
  );
});

// POST /repertoire/node/primary  { color, fen, uci }
router.post('/node/primary', authenticateToken, (req, res) => {
  const { color, fen, uci } = req.body ?? {};
  answer(
    res,
    promoteMove(pool, req.user.id, { color, fen, uci }),
    'Could not change main move.',
  );
});

// GET /repertoire/book?color=b&fen=...
//
// What is played here, from the local opening book, with `prepared` on the
// moves this student entered. A position never stored is read from the book
// and stored on the way, so the panel beside the board is simply there.
//
// `opened: false` now means the book has no games here; `unavailable` carries
// the book's reason when the file cannot be read.
router.get('/book', authenticateToken, (req, res) => {
  const { color, fen } = req.query;
  answer(
    res,
    bookAt(pool, req.user.id, { color, fen }),
    'Could not read book.',
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
    'Could not save evaluation.',
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
    'Could not read evaluations.',
  );
});

// GET /repertoire/disagreements?color=b&rootFen=...&rootPath=e4+c5
//     [&fromFen=...&limit=50]
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
  const { color, rootFen, rootPath, fromFen, limit } = req.query;
  answer(
    res,
    disagreements(pool, req.user.id, {
      color,
      rootFen,
      gateUci: gateOf(req.query),
      rootPath: typeof rootPath === 'string' && rootPath.trim() !== ''
        ? rootPath.trim().split(/\s+/)
        : [],
      fromFen: typeof fromFen === 'string' && fromFen.trim() !== ''
        ? fromFen
        : null,
      limit: Number(limit) || undefined,
    }),
    'Could not compile disagreement list.',
  );
});

// GET /repertoire/node/orphans?color=b&fen=...&uci=g8f6
//
// What removing that move would strand, without removing anything. Asked
// *before* the removal, because "would this still be reachable without that
// move" cannot be answered once the move is gone.
//
// The positions only that move reaches, and how many of the student's moves
// stand in them — so a screen can ask before anything goes. `uci` may be the
// student's move or an opponent move they entered. Losing an evening's work to
// a deleted move with no sentence about it is the kind of thing that happens
// once and ends trust in a feature.
router.get('/node/orphans', authenticateToken, (req, res) => {
  const { color, fen, uci } = req.query;
  answer(
    res,
    orphansOfRemoving(pool, req.user.id, {
      color, fen, uci,
    }),
    'Could not calculate what becomes stranded.',
  );
});

// POST /repertoire/prune  { color, keys }
//
// Takes out positions that nothing reaches any more, with the opponent moves
// entered after them. The screen asks first, with the count from
// `/node/orphans`.
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
    }),
    'Pruning failed.',
  );
});

// DELETE /repertoire/node/move?color=b&fen=...&uci=g8f6
router.delete('/node/move', authenticateToken, (req, res) => {
  const { color, fen, uci } = req.query;
  answer(
    res,
    removeMove(pool, req.user.id, { color, fen, uci }),
    'Could not remove move.',
  );
});

// POST /repertoire/node/reply  { color, fen, uci, san }
//
// An opponent move, played on the board by the student. `fen` is the position
// the opponent moves *from* — after the student's own move. The move does not
// have to be in the book.
router.post('/node/reply', authenticateToken, (req, res) => {
  const { color, fen, uci, san } = req.body ?? {};
  answer(
    res,
    addExtraReply(pool, req.user.id, { color, fen, uci, san }),
    'Could not save opponent move.',
  );
});

// DELETE /repertoire/node/reply?color=b&fen=...&uci=g1f3
router.delete('/node/reply', authenticateToken, (req, res) => {
  const { color, fen, uci } = req.query;
  answer(
    res,
    removeExtraReply(pool, req.user.id, { color, fen, uci }),
    'Could not remove opponent move.',
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
    'Could not record attempt.',
  );
});

// GET /repertoire/frontier?color=b&rootFen=...&rootPath=e4+c5
//
// Where the student is, rebuilt from the moves they played. This is what makes
// closing the build screen safe: the queue was never a fact worth storing, and
// deriving it costs nothing — so resuming is free, and free on any device.
router.get('/frontier', authenticateToken, (req, res) => {
  const { color, rootFen, rootPath, limit } = req.query;
  answer(
    res,
    frontier(pool, req.user.id, {
      color,
      rootFen,
      gateUci: gateOf(req.query),
      rootPath: typeof rootPath === 'string' && rootPath.trim() !== ''
        ? rootPath.trim().split(/\s+/)
        : [],
      limit: Math.min(Math.max(Number(limit) || 200, 1), 500),
    }),
    'Could not calculate repertoire overview.',
  );
});

// GET /repertoire/tree?color=b&rootFen=...&rootPath=e4+c5&maxPly=16
//
// The repertoire as a picture: one node per ply, each saying whose move it is,
// how often the opponent plays it, and what state the position it leads to is
// in. Same walk, same two tables, no Lichess request.
//
// `maxPly` keeps it a picture rather than a wall. A seeded repertoire runs to
// thousands of moves and nobody reads a drawing of all of them; the answer says
// when the depth was reached.
router.get('/tree', authenticateToken, (req, res) => {
  const { color, rootFen, rootPath, maxPly } = req.query;
  answer(
    res,
    repertoireTree(pool, req.user.id, {
      color,
      rootFen,
      gateUci: gateOf(req.query),
      rootPath: typeof rootPath === 'string' && rootPath.trim() !== ''
        ? rootPath.trim().split(/\s+/)
        : [],
      maxPly: Math.min(Math.max(Number(maxPly) || 16, 2), 40),
    }),
    'Could not assemble repertoire tree.',
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
    'Could not read weak positions.',
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
    'Could not read next position.',
  );
});

// GET /repertoire/drill/line?color=b&rootFen=...&rootPath=e4+c5
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
    color, rootFen, rootPath, fromFen, viaFen, viaUci, ahead,
  } = req.query;
  const exclude = Array.isArray(req.query.exclude)
    ? req.query.exclude.filter((k) => typeof k === 'string')
    : (typeof req.query.exclude === 'string' ? [req.query.exclude] : []);
  answer(
    res,
    rootsFrom(req.query, req.user.id).then((roots) => drillLine(pool, req.user.id, {
      // With `ids` the colour is the repertoires' own, and `rootsFrom` has
      // already refused a request that says otherwise.
      color: roots === null ? color : roots[0].color,
      roots,
      rootFen,
      rootPath: typeof rootPath === 'string' && rootPath.trim() !== ''
        ? rootPath.trim().split(/\s+/)
        : [],
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
    })),
    'Could not assemble the drill line.',
  );
});

// GET /repertoire/drill/branches?color=b&rootFen=...&rootPath=e4+c5
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
  const { color, rootFen, rootPath } = req.query;
  answer(
    res,
    rootsFrom(req.query, req.user.id).then(
      (roots) => drillBranches(pool, req.user.id, {
        color: roots === null ? color : roots[0].color,
        roots,
        rootFen,
        gateUci: gateOf(req.query),
        rootPath: typeof rootPath === 'string' && rootPath.trim() !== ''
          ? rootPath.trim().split(/\s+/)
          : [],
      }),
    ),
    'Could not read drill branches.',
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
    'Could not read move.',
  );
});

// POST /repertoire/drill/answer
//   { color, fen, uci, revealed, practice, onlyIfDue }
//
// Grades the move against what the student decided, reschedules it, and hands
// back the opponent's reply so the line can go on. The reply comes from the
// stored book, so a drill reads nothing but this server's own tables.
//
// `practice` judges and writes nothing. `onlyIfDue` writes only when this
// position was what the schedule asked for, which is what a line walked on past
// its question needs — see `answer` for why the two are not the same flag.
router.post('/drill/answer', authenticateToken, (req, res) => {
  const {
    color, fen, uci, revealed, practice, onlyIfDue,
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
        // Whose repertoire it is: the opponent plays the moves this student
        // entered, and nobody else's.
        userId: req.user.id,
        color,
      });
      return { ...graded, reply };
    }),
    'Could not evaluate answer.',
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
