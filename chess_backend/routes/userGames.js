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
const logger = require('../services/logger');
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const {
  createArchiveImporter, ArchiveImportUnavailable,
} = require('../services/gameArchiveImport');

const importer = createArchiveImporter({ pool });

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
  if (err instanceof ArchiveImportUnavailable) {
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

// GET /games/stats — what the archive holds, before anything analyses it.
router.get('/stats', authenticateToken, async (req, res) => {
  try {
    return res.json(await importer.archiveStats(req.user.id));
  } catch (err) {
    return fail(res, err, 'Statistika arhive nije dostupna.');
  }
});

module.exports = router;
