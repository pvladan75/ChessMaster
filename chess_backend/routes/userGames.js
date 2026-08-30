// userGames.js — a player's own archive: start an import, ask how it went.
//
// The import itself takes minutes, so nothing here waits for it. A POST creates
// the run and answers 202 with its id; the client asks this route how it is
// going. That is also why the failure of a run is not this route's 500: a run
// that fails writes its own reason into `user_game_imports`, where it is still
// there tomorrow.
//
// Every query is scoped to `req.user.id`. An archive is nobody else's business
// — not a trainer's either, until the flow in section 6 of the plan exists.

const express = require('express');
const router = express.Router();
const rateLimit = require('express-rate-limit');
const multer = require('multer');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const logger = require('../services/logger');
const {
  PGN_TMP_DIR, sweepLeftovers, removeQuietly,
} = require('../services/scanTempFiles');
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const {
  createArchiveImporter, ArchiveImportUnavailable,
} = require('../services/gameArchiveImport');
const { leakReport, backfillNodes } = require('../services/openingLeaks');
const {
  createOpponentPrep, OpponentPrepUnavailable, policyFrom,
} = require('../services/opponentPrep');
const { createPrepNarrative } = require('../services/prepNarrative');
const { isOwnSubject } = require('../services/archiveScope');
const { GoogleGenAI } = require('@google/genai');
const { generateContentWithRetry } = require('../geminiService');
const { openingJudge } = require('../services/openingJudgeService');
const {
  createEndgameAuditor, EndgameAuditUnavailable,
} = require('../services/endgameAudit');
const { seedFromArchive, repertoireDiff } = require('../services/repertoireArchive');
const { playerProfile } = require('../services/playerProfile');

const importer = createArchiveImporter({ pool });
const auditor = createEndgameAuditor({ pool });
const prep = createOpponentPrep({ pool, importer });

/// One call to the model, or a throw. Everything about *whether* the answer may
/// be shown lives in `prepNarrative`; this only knows how to ask.
const narrator = createPrepNarrative({
  generate: async (prompt) => {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey || apiKey === 'YOUR_GEMINI_API_KEY' || !apiKey.trim()) {
      throw new Error('GEMINI_API_KEY missing');
    }
    const response = await generateContentWithRetry(
      new GoogleGenAI({ apiKey }),
      { model: 'gemini-flash-latest', contents: prompt },
    );
    return response.text;
  },
});

// A ten-year archive exported from Lichess with clocks is about 9 MB. This is
// generous room above that and still far below what would hurt a 960 MB
// droplet, since the file is written to disk and read back as a stream rather
// than held in memory.
const MAX_ARCHIVE_BYTES = 25 * 1024 * 1024;

// The upload is deleted once the run that reads it finishes. Anything still
// here at startup belongs to a run that died with its process — nodemon
// restarting on a file save is enough — and a PGN left behind is a copy of
// somebody's whole game history.
sweepLeftovers(PGN_TMP_DIR, 'pgn_');

const upload = multer({
  storage: multer.diskStorage({
    destination(req, file, cb) {
      fs.mkdirSync(PGN_TMP_DIR, { recursive: true });
      cb(null, PGN_TMP_DIR);
    },
    filename(req, file, cb) {
      cb(null, `pgn_${Date.now()}_${crypto.randomBytes(6).toString('hex')}.pgn`);
    },
  }),
  limits: { fileSize: MAX_ARCHIVE_BYTES },
  fileFilter(req, file, cb) {
    const looksPgn = path.extname(file.originalname).toLowerCase() === '.pgn'
      || (file.mimetype || '').startsWith('text/')
      || file.mimetype === 'application/x-chess-pgn';
    cb(looksPgn ? null : new Error('Podržan je samo .pgn fajl.'), looksPgn);
  },
});

// An import is one long stream from a service someone else pays to run, and a
// second one for the same user is refused by the importer anyway. This cap is
// for a client that has stopped asking and started hammering.
const importLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  max: 12,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Previše pokušaja uvoza. Sačekajte malo.' },
});

function fail(res, err, whatFailed) {
  if (err instanceof ArchiveImportUnavailable || err instanceof EndgameAuditUnavailable) {
    return res.status(err.status).json({ error: err.message, reason: err.reason });
  }
  if (err instanceof TypeError) {
    return res.status(400).json({ error: err.message });
  }
  logger.error(`[ARHIVA] ${whatFailed}: ${err.message}`);
  return res.status(500).json({ error: whatFailed });
}

/// The run continues after the response. Its failure is recorded in its own row
/// — this only stops an unhandled rejection from taking the process down with
/// a job that already knows how to report itself.
function detach(finished, importId) {
  finished.catch((err) => logger.info(
    `[ARHIVA] Uvoz ${importId} završen greškom: ${err.message}`,
  ));
}

// POST /games/import  { username, since? }
//
// `subject_is_owner` is fixed at true here on purpose. The table and the
// importer can both hold somebody else's archive — that is what match
// preparation needs, section 6 of docs/PLAN-MOJE-PARTIJE.md — but whether this
// app lets one account pull a profile of a named child is a decision for the
// product, not a default to arrive at through an unused parameter.
router.post('/import', authenticateToken, importLimiter, async (req, res) => {
  const { username, since } = req.body ?? {};
  try {
    const { importId, since: resumeFrom, finished } = await importer.start({
      userId: req.user.id,
      subject: username,
      source: 'lichess',
      subjectIsOwner: true,
      since: since ?? undefined,
    });
    detach(finished, importId);
    return res.status(202).json({ importId, since: resumeFrom });
  } catch (err) {
    return fail(res, err, 'Uvoz partija nije mogao da počne.');
  }
});

// POST /games/import/pgn  { pgn, username }
//
// The paste and file path, for a player who is not on Lichess. Bounded by the
// 2 MB JSON body limit in server.js — roughly a few hundred games — which is
// why the streaming route above exists for a whole archive.
router.post('/import/pgn', authenticateToken, importLimiter, async (req, res) => {
  const { pgn, username } = req.body ?? {};
  if (typeof pgn !== 'string' || pgn.trim().length === 0) {
    return res.status(400).json({ error: 'Nedostaje PGN.' });
  }
  try {
    const { importId, finished } = await importer.start({
      userId: req.user.id,
      subject: username,
      source: 'pgn',
      subjectIsOwner: true,
      pgnText: pgn,
    });
    detach(finished, importId);
    return res.status(202).json({ importId });
  } catch (err) {
    return fail(res, err, 'Uvoz partija nije mogao da počne.');
  }
});

// POST /games/import/file — multipart, field `archive`, plus `username`.
//
// The path the player takes when they export their own games from Lichess and
// hand us the file. It reaches the database through exactly the same pipeline
// as everything else — the splitter does not care whether a chunk came off a
// socket or off a disk — so nothing here re-implements parsing or counting.
//
// The file is read as a stream and deleted when the run that reads it ends,
// not when this response is sent: the run outlives the request by minutes.
router.post(
  '/import/file',
  authenticateToken,
  importLimiter,
  upload.single('archive'),
  async (req, res) => {
    if (!req.file) return res.status(400).json({ error: 'Nedostaje .pgn fajl.' });
    const uploadedPath = req.file.path;
    try {
      const { importId, finished } = await importer.start({
        userId: req.user.id,
        subject: req.body?.username,
        source: 'pgn',
        subjectIsOwner: true,
        pgnStream: fs.createReadStream(uploadedPath),
      });
      finished.catch(() => {}).finally(() => removeQuietly(uploadedPath));
      detach(finished, importId);
      return res.status(202).json({ importId, bytes: req.file.size });
    } catch (err) {
      removeQuietly(uploadedPath);
      return fail(res, err, 'Uvoz partija nije mogao da počne.');
    }
  },
);

// POST /games/prep/import  { username, vs?, color?, perfType?, rated?, max? }
//
// Section 7: the same importer pointed at somebody else. Lichess serves any
// account's games to an unauthenticated caller, so mechanically this is the
// route above with one flag flipped — and that flag, `subject_is_owner`, is the
// only thing separating an opponent's games from the player's own inside
// `user_games`. Everything that reads "the player's" goes through
// `services/archiveScope.js` for exactly that reason.
//
// **This is the one route here that reads about a person who never opened the
// app**, and most accounts in this product belong to children. The policy in
// `services/opponentPrep.js` is in front of it, and it is off by default: the
// question of who may be profiled is a product decision, not a default to
// arrive at by leaving a parameter unused.
//
// The report needs no route of its own — `GET /games/openings/leaks?subject=`
// already aggregates by subject, which is the whole reason this was worth
// building after section 1 rather than before it.
router.post('/prep/import', authenticateToken, importLimiter, async (req, res) => {
  const body = req.body ?? {};
  try {
    const { importId, finished } = await prep.prepare({
      userId: req.user.id,
      subject: body.username,
      filters: {
        vs: body.vs,
        color: body.color,
        perfType: body.perfType,
        rated: body.rated,
        max: body.max,
      },
    });
    detach(finished, importId);
    return res.status(202).json({ importId });
  } catch (err) {
    // Both error types carry their own status and a Serbian message written for
    // the person reading it — a refusal here is an answer, not a fault.
    if (err instanceof OpponentPrepUnavailable || err instanceof ArchiveImportUnavailable) {
      return res.status(err.status || 400).json({ error: err.message, reason: err.reason });
    }
    return fail(res, err, 'Priprema za protivnika nije mogla da počne.');
  }
});

// GET /games/prep/narrative?subject=&color=&limit= — the report, said in words.
//
// The numbers are computed here and the sentence is checked against them, so
// this route owns both halves on purpose: a narrative generated over a report
// the client fetched separately could be checked only against what the client
// said the report was.
//
// Fails open in the useful direction. A missing key, a model outage, a refused
// sentence — all return the report's own summary with `narrative: null` and a
// named reason. The table was always the answer; the sentence is decoration,
// and decoration must not take the thing it decorates down with it.
router.get('/prep/narrative', authenticateToken, async (req, res) => {
  const q = req.query ?? {};
  const handle = String(q.subject || '').trim();
  if (!handle) return res.status(400).json({ error: 'Nedostaje korisničko ime.' });

  try {
    // Narrating your own report is an ordinary feature and needs no gate. Doing
    // it about somebody else is the feature that has one — and it is the same
    // gate as the pull, so turning preparation off also stops the sentences
    // about people it already fetched.
    const own = await isOwnSubject(pool, req.user.id, handle);
    if (!own && !policyFrom().enabled) {
      return res.status(403).json({
        error: 'Priprema za protivnika nije uključena na ovom serveru.',
        reason: 'disabled',
      });
    }

    const report = await leakReport(pool, req.user.id, {
      subject: handle,
      color: q.color ?? null,
      limit: q.limit,
    });
    const said = await narrator.narrate(report);

    return res.json({
      subject: handle,
      color: report.color,
      games: report.games,
      positions: report.nodes.length,
      ...said,
    });
  } catch (err) {
    if (err instanceof RangeError) return res.status(400).json({ error: err.message });
    return fail(res, err, 'Opis protivnika nije dostupan.');
  }
});

// GET /games/imports — the last runs, newest first.
router.get('/imports', authenticateToken, async (req, res) => {
  try {
    return res.json({ runs: await importer.listRuns(req.user.id) });
  } catch (err) {
    return fail(res, err, 'Istorija uvoza nije dostupna.');
  }
});

// GET /games/imports/:id — how one run is going, including its skip reasons.
router.get('/imports/:id', authenticateToken, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return res.status(400).json({ error: 'Loš id.' });
  try {
    const run = await importer.getRun(req.user.id, id);
    if (!run) return res.status(404).json({ error: 'Nema tog uvoza.' });
    return res.json(run);
  } catch (err) {
    return fail(res, err, 'Stanje uvoza nije dostupno.');
  }
});

// GET /games/openings/leaks?subject=&color=&fromPly=&toPly=&minGames=&maxScore=&speed=&limit=
// Optional: &judge=true with header X-Lichess-Token
//
// The counting half costs nothing — no engine, no network — and it is the
// whole report. Judging is an extra opinion on the move the player keeps
// choosing, it costs requests against the caller's own Lichess allowance, and
// it is therefore asked for rather than assumed.
//
// A missing or refused token does not take the report down with it. The
// numbers were computed before anything was asked of Lichess, and this codebase
// has twice shipped a bug where the message about the work killed the work.
router.get('/openings/leaks', authenticateToken, async (req, res) => {
  const q = req.query ?? {};
  try {
    const report = await leakReport(pool, req.user.id, {
      subject: q.subject,
      color: q.color ?? null,
      fromPly: q.fromPly,
      toPly: q.toPly,
      minGames: q.minGames,
      maxScore: q.maxScore,
      speed: q.speed ?? null,
      limit: q.limit,
    });

    if (String(q.judge) === 'true') {
      report.judge = await annotate(report.nodes, {
        token: req.get('X-Lichess-Token') || '',
        minRating: q.minRating ?? null,
        limit: Number(q.judgeLimit) > 0 ? Number(q.judgeLimit) : 10,
      });
    }
    return res.json(report);
  } catch (err) {
    if (err instanceof RangeError) return res.status(400).json({ error: err.message });
    return fail(res, err, 'Izveštaj o otvaranjima nije dostupan.');
  }
});

/// Asks the judge about the move the player chose most often in each of the
/// worst positions, and counts what that cost. The count is the point as much
/// as the verdicts are: it is how anyone finds out whether this report is a
/// handful of requests or a scan.
async function annotate(nodes, { token, minRating, limit }) {
  if (!token) return { requested: true, judged: 0, requests: 0, reason: 'no-token' };
  let judged = 0;
  for (const node of nodes.slice(0, limit)) {
    const favourite = node.moves[0];
    if (!favourite) continue;
    try {
      // eslint-disable-next-line no-await-in-loop
      node.judgement = await openingJudge.judge(node.fen, favourite.san, {
        token, minRating,
      });
      judged += 1;
    } catch (err) {
      // `unknown` is a fourth answer here for the same reason it is one in the
      // judge itself: a move nobody has evaluated, shown as a mistake, is an
      // answer that looks computed and is a guess.
      node.judgement = { verdict: 'unknown', reason: err.reason || 'error' };
    }
  }
  return { requested: true, judged, nodes: Math.min(nodes.length, limit) };
}

// POST /games/openings/backfill — fills opening_nodes for games imported before
// that table existed. Idempotent; safe to run twice.
router.post('/openings/backfill', authenticateToken, importLimiter, async (req, res) => {
  try {
    return res.json(await backfillNodes(pool, req.user.id));
  } catch (err) {
    return fail(res, err, 'Dopuna otvaranja nije uspela.');
  }
});

// POST /games/endgame/audit  { username }
//
// Walks every archived game that reached seven men or fewer and records the
// moves that threw away what the tables say the player had. Minutes on a first
// run and seconds afterwards, since every answer lands in the shared
// `tablebase_cache` — so this answers 202 with an id, like the import does.
router.post('/endgame/audit', authenticateToken, importLimiter, async (req, res) => {
  try {
    const { auditId, finished } = await auditor.start({
      userId: req.user.id,
      subject: req.body?.username,
    });
    finished.catch((err) => logger.info(
      `[ZAVRŠNICE] Provera ${auditId} završena greškom: ${err.message}`,
    ));
    return res.status(202).json({ auditId });
  } catch (err) {
    return fail(res, err, 'Provera završnica nije mogla da počne.');
  }
});

// GET /games/endgame/audits/:id — how the run is going.
router.get('/endgame/audits/:id', authenticateToken, async (req, res) => {
  const id = Number(req.params.id);
  if (!Number.isInteger(id)) return res.status(400).json({ error: 'Loš id.' });
  try {
    const run = await auditor.getRun(req.user.id, id);
    if (!run) return res.status(404).json({ error: 'Nema te provere.' });
    return res.json(run);
  } catch (err) {
    return fail(res, err, 'Stanje provere nije dostupno.');
  }
});

// GET /games/endgame/mistakes — the findings, worst swing first.
router.get('/endgame/mistakes', authenticateToken, async (req, res) => {
  const limit = Number(req.query?.limit);
  try {
    return res.json({
      mistakes: await auditor.listMistakes(req.user.id, {
        limit: Number.isInteger(limit) && limit > 0 && limit <= 200 ? limit : 50,
      }),
    });
  } catch (err) {
    return fail(res, err, 'Nalazi iz završnica nisu dostupni.');
  }
});

// POST /games/repertoire/seed  { username, color?, minGames?, dryRun? }
//
// Builds a repertoire out of what the player already plays. Writes through
// `addMove`, which makes the first move into a position primary and every later
// one an alternate — so a position the player has already decided about keeps
// their decision. A seed that overwrote a hand-built repertoire would be the
// worst possible introduction to this feature.
//
// `dryRun: true` returns the plan and writes nothing, which is the sensible
// thing for the UI to show first.
router.post('/repertoire/seed', authenticateToken, importLimiter, async (req, res) => {
  const body = req.body ?? {};
  try {
    return res.json(await seedFromArchive(pool, req.user.id, {
      subject: body.username,
      color: body.color ?? null,
      minGames: Number(body.minGames) > 0 ? Number(body.minGames) : undefined,
      dryRun: body.dryRun === true,
    }));
  } catch (err) {
    if (err instanceof RangeError) return res.status(400).json({ error: err.message });
    return fail(res, err, 'Repertoar nije mogao da se zaseje iz arhive.');
  }
});

// GET /games/repertoire/diff?username=&color=&limit=
//
// The games that reached a position the player had prepared and then did not
// follow the preparation. Positions the repertoire says nothing about are not
// deviations — those are a gap, which is a different report.
router.get('/repertoire/diff', authenticateToken, async (req, res) => {
  const q = req.query ?? {};
  try {
    return res.json(await repertoireDiff(pool, req.user.id, {
      subject: q.username,
      color: q.color ?? null,
      limit: Number(q.limit),
    }));
  } catch (err) {
    if (err instanceof RangeError) return res.status(400).json({ error: err.message });
    return fail(res, err, 'Poređenje sa repertoarom nije dostupno.');
  }
});

// GET /games/profile?username=
//
// The weaknesses that are not about openings: colour, speed, game length, the
// phase a game reached, the year, and what the clock does. All of it out of
// `user_games` — no engine, no tablebase, no network.
router.get('/profile', authenticateToken, async (req, res) => {
  try {
    return res.json(await playerProfile(pool, req.user.id, {
      subject: req.query?.username,
    }));
  } catch (err) {
    if (err instanceof RangeError) return res.status(400).json({ error: err.message });
    return fail(res, err, 'Profil igrača nije dostupan.');
  }
});

// GET /games/subjects — whose games the archive holds, one row per handle.
//
// The archive screen's list, and the reason it exists is a live failure: the
// four analysis screens took a `subject` in the query string and there was no
// screen that knew the handles, so the only door was the import screen and only
// while its last run was still in memory. An empty archive answers with an
// empty list, never a 404 — "you have imported nothing" is a state to render,
// not an error to report.
router.get('/subjects', authenticateToken, async (req, res) => {
  try {
    return res.json({ subjects: await importer.archiveSubjects(req.user.id) });
  } catch (err) {
    return fail(res, err, 'Spisak igrača iz arhive nije dostupan.');
  }
});

// GET /games/stats — what the archive holds, before anything analyses it.
router.get('/stats', authenticateToken, async (req, res) => {
  try {
    return res.json(await importer.archiveStats(req.user.id));
  } catch (err) {
    return fail(res, err, 'Statistika arhive nije dostupna.');
  }
});

/// Multer's own failures arrive here rather than as a 500 with no explanation:
/// a file over the ceiling and a file that is not a PGN are both the caller's
/// business, and both are things a person will hit by accident.
// eslint-disable-next-line no-unused-vars
router.use((err, req, res, next) => {
  if (err instanceof multer.MulterError && err.code === 'LIMIT_FILE_SIZE') {
    return res.status(413).json({
      error: `Fajl je veći od ${Math.round(MAX_ARCHIVE_BYTES / (1024 * 1024))} MB.`,
    });
  }
  if (err) {
    logger.error(`[ARHIVA] Otpremanje odbijeno: ${err.message}`);
    return res.status(400).json({ error: err.message });
  }
  return next();
});

module.exports = router;
