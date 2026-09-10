const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const logger = require('../services/logger');
const express = require('express');
const router = express.Router();
const { pool } = require('../db');
const { authenticateToken, signDownloadToken } = require('../middleware/auth');
const { requireEntitlement } = require('../middleware/entitlements');
const { ENT, METRIC, recordUsage } = require('../services/entitlementService');
const videoRenderer = require('../videoRenderer');
const { acceptedTrainersOf } = require('../services/relationshipService');
const { buildLessonStep, buildLessonSteps } = require('../services/lessonSteps');
const tts = require('../services/tts');
const renderProgress = require('../services/renderProgress');
const renderQueue = require('../services/renderQueue');
const renderBudget = require('../services/renderBudget');
const renderJobs = require('../services/renderJobs');
const { RenderAborted, throwIfAborted } = require('../services/renderAbort');
const tutorialNarration = require('../services/tutorialNarration');
const multer = require('multer');
const narrationUpload = require('../services/narrationUpload');
const { mayRecordNarration } = require('../services/recordingConsent');

/// Runs a submitted step list through the one builder, or answers the caller.
///
/// Returns the built entries, or null after having already sent the refusal —
/// so a route reads `if (steps === null) return;`.
function buildOrReject(res, positionList) {
  if (!positionList || (Array.isArray(positionList) && positionList.length === 0)) {
    return [];
  }
  const built = buildLessonSteps(positionList);
  if (!built.ok) {
    res.status(built.status).json({ error: built.error });
    return null;
  }
  return built.entries;
}

/// The default name for a copy, kept inside the column it has to fit.
///
/// `title` is `VARCHAR(255)`. Appending „ (kopija)" to a title already near the
/// limit is a 22001 from the driver and a 500 to the trainer, which reads as
/// „cloning is broken" rather than „your title is long" — so the base is
/// shortened instead, and only as much as it must be.
const COPY_SUFFIX = ' (copy)';
const MAX_LESSON_TITLE = 255;

/// How many preview stills one request may ask for. Each comes back as a
/// base64 PNG, so this is a cap on the answer's size as much as on the work.
const MAX_PREVIEW_FRAMES = 4;

function copyTitle(title) {
  const base = typeof title === 'string' ? title : '';
  const room = MAX_LESSON_TITLE - COPY_SUFFIX.length;
  return `${base.length > room ? base.slice(0, room) : base}${COPY_SUFFIX}`;
}

// POST /lessons/save
router.post('/save', authenticateToken, async (req, res) => {
  const { title, description, tags, fen, pgn, positionList } = req.body;

  if (!title || (!fen && (!positionList || positionList.length === 0))) {
    return res.status(400).json({ error: 'Title and either FEN or positionList are required' });
  }

  const initialFen = fen || (positionList && positionList.length > 0 ? positionList[0].fen : 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');

  // Every step gets its id here, once, and keeps it for the rest of its life.
  const steps = buildOrReject(res, positionList);
  if (steps === null) return;

  try {
    const result = await pool.query(
      'INSERT INTO saved_lessons (user_id, trainer_id, title, description, tags, fen, pgn, position_list) VALUES ($1, $1, $2, $3, $4, $5, $6, $7) RETURNING *',
      [req.user.id, title, description || null, tags || null, initialFen, pgn || null, steps.length > 0 ? JSON.stringify(steps) : null]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    logger.error('Save lesson error:', err);
    res.status(500).json({ error: 'Server error while saving lesson' });
  }
});

/// Did this request say anything at all about the steps?
///
/// The difference between "leave them alone" and "there are none now", and the
/// two used to be one thing. `_editSinglePosition` in the app renames a saved
/// position and sends no `positionList` — which wrote `position_list = NULL`
/// over whatever was there, because a missing list and an empty one both came
/// out of `buildOrReject` as `[]`.
///
/// Nothing lost data, and only because the *caller* was careful: the list in
/// the app offers that rename for a single position and the course dialog for a
/// course, so the nulling path was never handed a lesson with steps in it. That
/// is a guarantee living in a widget's `isCourse ? ... : ...`, two files and one
/// refactor away from the write that would destroy every step of a lesson —
/// silently, since nothing joins on them and nothing would log it. The same
/// shape as every bug in the CLAUDE.md list.
///
/// `lesson_rename_keeps_steps.test.js` drives the mounted route rather than
/// this function: the helper being right and the route asking it are two
/// different things, and on the last occasion it was the second one missing.
function sentPositionList(body) {
  return Object.prototype.hasOwnProperty.call(body || {}, 'positionList')
    && body.positionList !== null
    && body.positionList !== undefined;
}

// GET /lessons/tts/voices — available voices for tutorial video narration.
// Mounted before any /:id route so ':id' cannot swallow 'tts'.
router.get('/tts/voices', authenticateToken, async (req, res) => {
  try {
    const available = tts.narrationAvailable();
    const voices = await tts.voices();
    res.json({ available, voices });
  } catch (err) {
    logger.error('Fetch TTS voices error:', err);
    res.status(500).json({ error: 'Server error while fetching TTS voices' });
  }
});

// PUT /lessons/:id — update a lesson you own (either creator or the trainer who shared it)
router.put('/:id', authenticateToken, async (req, res) => {
  const { title, description, tags, fen, pgn, positionList } = req.body;
  const touchesSteps = sentPositionList(req.body);

  if (!title || (!fen && (!positionList || positionList.length === 0))) {
    return res.status(400).json({ error: 'Title and either FEN or positionList are required' });
  }

  const initialFen = fen || (positionList && positionList.length > 0 ? positionList[0].fen : 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');

  const steps = touchesSteps ? buildOrReject(res, positionList) : [];
  if (steps === null) return;

  try {
    // A client that sends back a list of the same length with every id stripped
    // has lost the ids it was given, and writing it would orphan every schedule
    // row and every recorded answer naming those steps — silently, because
    // nothing joins on them.
    //
    // So it fails loudly instead. A lesson whose stored steps never had ids has
    // nothing to lose and is let through; this only fires where a real identity
    // would be destroyed.
    const stored = await pool.query(
      'SELECT position_list FROM saved_lessons WHERE id = $1 AND (user_id = $2 OR trainer_id = $2)',
      [req.params.id, req.user.id]
    );
    const storedList = Array.isArray(stored.rows[0]?.position_list) ? stored.rows[0].position_list : [];
    const hasId = (s) => typeof s?.id === 'string' && s.id !== '';
    if (
      touchesSteps
      && storedList.length > 0
      && storedList.length === steps.length
      && storedList.some(hasId)
      && !(positionList || []).some(hasId)
    ) {
      return res.status(409).json({
        error: 'Steps arrived without their IDs. Refresh the tutorial and save again.',
      });
    }

    // A request that said nothing about the steps leaves the column alone. It
    // is written as two statements rather than one clever `CASE`, because the
    // thing being protected here is a list that cannot be reconstructed once it
    // is gone, and the reader of this file should be able to see which
    // statement runs without evaluating an expression in their head.
    const result = touchesSteps
      ? await pool.query(
        `UPDATE saved_lessons
         SET title = $1, description = $2, tags = $3, fen = $4, pgn = $5, position_list = $6
         WHERE id = $7 AND (user_id = $8 OR trainer_id = $8)
         RETURNING *`,
        [title, description || null, tags || null, initialFen, pgn || null, steps.length > 0 ? JSON.stringify(steps) : null, req.params.id, req.user.id]
      )
      : await pool.query(
        `UPDATE saved_lessons
         SET title = $1, description = $2, tags = $3, fen = $4, pgn = $5
         WHERE id = $6 AND (user_id = $7 OR trainer_id = $7)
         RETURNING *`,
        [title, description || null, tags || null, initialFen, pgn || null, req.params.id, req.user.id]
      );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Tutorial not found or you do not have permission to edit it.' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    logger.error('Update lesson error:', err);
    res.status(500).json({ error: 'Server error while updating lesson' });
  }
});

// POST /lessons/:id/steps — append one position to an existing course.
//
// The other half of "add to lesson": a trainer looking at a position wants it
// in a lesson without opening the editor and rebuilding the list.
//
// It appends server-side, in one statement, rather than having the client read
// the lesson, push a step and PUT the whole thing back. Two people editing the
// same lesson that way lose one of the edits, and the loser is silent.
router.post('/:id/steps', authenticateToken, async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  if (!Number.isInteger(id)) {
    return res.status(400).json({ error: 'Unknown tutorial.' });
  }

  const built = buildLessonStep(req.body?.step);
  if (!built.ok) {
    return res.status(built.status).json({ error: built.error });
  }

  try {
    const result = await pool.query(
      `UPDATE saved_lessons
          SET position_list = position_list || $1::jsonb
        WHERE id = $2
          AND (user_id = $3 OR trainer_id = $3)
          AND position_list IS NOT NULL
        RETURNING id, title, jsonb_array_length(position_list) AS step_count`,
      [JSON.stringify([built.entry]), id, req.user.id]
    );

    if (result.rows.length === 0) {
      // Three different reasons look identical from a failed UPDATE, and the
      // trainer can act on only two of them. Worth one more query to say which.
      const existing = await pool.query(
        `SELECT (user_id = $2 OR trainer_id = $2) AS mine, position_list IS NULL AS bare
           FROM saved_lessons WHERE id = $1`,
        [id, req.user.id]
      );
      if (existing.rows.length === 0 || existing.rows[0].mine !== true) {
        return res.status(404).json({ error: 'Tutorial not found or you do not have permission to edit it.' });
      }
      return res.status(409).json({
        error: 'This is a single position, not a tutorial with steps. Create a tutorial in the editor.',
      });
    }

    res.status(201).json({ success: true, lesson: result.rows[0] });
  } catch (err) {
    logger.error('Append lesson step error:', err);
    res.status(500).json({ error: 'Server error while appending lesson step' });
  }
});

// POST /lessons/:id/clone — save a tutorial as a new version.
//
// Phase 3a of `docs/PLAN-TUTORIJAL.md`. The trainer keeps one tutorial and makes
// an easier or harder version of it for another group, and the original must
// come out untouched — which is the whole reason this is a route and not a
// client that reads, edits and PUTs back.
//
// **Every copied step gets a fresh id.** A step id is the identity of a step
// *in this tutorial*: `stepByKey` resolves a schedule row and a recorded answer
// by it, and two tutorials carrying one id is an ambiguity nobody would find
// until a child's progress showed up in the wrong copy. Stripping the ids and
// running the list back through `buildLessonSteps` mints new ones from the one
// place allowed to build a step, and validates the copy on the way — a stored
// list written before a validation rule existed is refused here rather than
// duplicated.
//
// The copy belongs to whoever asked for it, even when they were the trainer on
// the original rather than its owner: „sačuvaj kao novu verziju" makes *your*
// version.
router.post('/:id/clone', authenticateToken, async (req, res) => {
  const id = Number.parseInt(req.params.id, 10);
  if (!Number.isInteger(id)) {
    return res.status(400).json({ error: 'Unknown tutorial.' });
  }

  const asked = typeof req.body?.title === 'string' ? req.body.title.trim() : '';

  try {
    const found = await pool.query(
      `SELECT title, description, tags, fen, pgn, position_list
         FROM saved_lessons
        WHERE id = $1 AND (user_id = $2 OR trainer_id = $2)`,
      [id, req.user.id]
    );
    if (found.rows.length === 0) {
      return res.status(404).json({ error: 'Tutorial not found or you do not have permission to edit it.' });
    }

    const source = found.rows[0];
    const title = asked !== '' ? asked : copyTitle(source.title);

    let steps = null;
    const stored = Array.isArray(source.position_list) ? source.position_list : [];
    if (stored.length > 0) {
      const stripped = stored.map((step) => {
        const { id: _replaced, ...rest } = step || {};
        return rest;
      });
      const built = buildLessonSteps(stripped);
      if (!built.ok) {
        return res.status(built.status).json({ error: built.error });
      }
      steps = built.entries;
    }

    const result = await pool.query(
      'INSERT INTO saved_lessons (user_id, trainer_id, title, description, tags, fen, pgn, position_list) VALUES ($1, $1, $2, $3, $4, $5, $6, $7) RETURNING *',
      [req.user.id, title, source.description || null, source.tags || null, source.fen, source.pgn || null, steps ? JSON.stringify(steps) : null]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    logger.error('Clone lesson error:', err);
    res.status(500).json({ error: 'Server error while cloning lesson' });
  }
});

// DELETE /lessons/:id — delete a lesson you own
//
// **The recording goes with it**, after the row. A recorded voice lives under
// `uploads/`, which no timer sweeps, so if this route did not delete it nothing
// ever would: the file would outlive the only row that could reach it. The row
// first, because the other order leaves a tutorial naming a file that is gone.
router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'DELETE FROM saved_lessons WHERE id = $1 AND (user_id = $2 OR trainer_id = $2) RETURNING id, narration_filename',
      [req.params.id, req.user.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Tutorial not found or you do not have permission to delete it.' });
    }
    narrationUpload.removeNarrationFile(result.rows[0].narration_filename);
    res.json({ success: true });
  } catch (err) {
    logger.error('Delete lesson error:', err);
    res.status(500).json({ error: 'Server error while deleting lesson' });
  }
});

// POST /lessons/:id/narration — the trainer's own recorded voice over a
// tutorial. Phase 3 of docs/PLAN-SNIMANJE.md; see services/narrationUpload.js
// for what is checked and why.
//
// Three stages, in this order on purpose: who may record over this tutorial is
// asked **before** multer accepts a byte, so a refusal never writes anything
// into `uploads/`; the file is received with the cap as multer's own limit; and
// only then is it judged and kept.

/// Whether this account may record over this tutorial at all.
async function narrationGate(req, res, next) {
  const id = Number.parseInt(req.params.id, 10);
  if (!Number.isInteger(id) || String(id) !== String(req.params.id)) {
    return res.status(400).json({ error: 'Unknown tutorial.' });
  }
  try {
    const found = await pool.query(
      'SELECT id FROM saved_lessons WHERE id = $1 AND (user_id = $2 OR trainer_id = $2)',
      [id, req.user.id]
    );
    if (found.rowCount === 0) {
      return res.status(404).json({ error: 'Tutorial not found or you do not have permission to record over it.' });
    }
    const consent = await mayRecordNarration(pool, req.user.id);
    if (!consent.allowed) {
      return res.status(403).json({ error: consent.reason });
    }
    return next();
  } catch (err) {
    logger.error('[NARRATION] Gate failed:', err);
    return res.status(500).json({ error: 'Server error while checking the recording.' });
  }
}

const narrationMulter = multer({
  storage: multer.diskStorage({
    destination(req, file, cb) {
      const dir = narrationUpload.narrationDir();
      try {
        fs.mkdirSync(dir, { recursive: true });
        cb(null, dir);
      } catch (err) {
        cb(err);
      }
    },
    filename(req, file, cb) {
      cb(null, narrationUpload.narrationFilename(req.params.id));
    },
  }),
  // The derived cap, read once as the route is built — which is when the
  // environment it is derived from is read.
  limits: { fileSize: narrationUpload.narrationMaxBytes(), files: 1, fields: 8 },
});

/// The file, received — or a sentence rather than Express's HTML error page.
function receiveNarration(req, res, next) {
  narrationMulter.single('audio')(req, res, (err) => {
    if (!err) return next();
    if (req.file) narrationUpload.removeQuietly(req.file.path);
    if (err instanceof multer.MulterError && err.code === 'LIMIT_FILE_SIZE') {
      return res.status(413).json({
        error: `This recording is longer than ${Math.floor(narrationUpload.narrationMaxSeconds() / 60)} minutes, `
          + 'which is the most one recording may be. Split the tutorial into two, or record a shorter narration.',
      });
    }
    logger.error('[NARRATION] Upload failed:', err);
    return res.status(400).json({ error: 'The recording could not be received. Upload it again.' });
  });
}

/// Judged, and kept — or deleted, with the reason.
async function saveNarration(req, res) {
  const file = req.file;
  if (!file) {
    return res.status(400).json({ error: 'No recording was sent.' });
  }
  const lessonId = Number.parseInt(req.params.id, 10);

  const takeId = typeof req.body.takeId === 'string' && req.body.takeId !== '' ? req.body.takeId : null;
  if (takeId !== null && !narrationUpload.TAKE_ID.test(takeId)) {
    narrationUpload.removeQuietly(file.path);
    return res.status(400).json({ error: 'The recording arrived with a name this server does not accept. Upload it again.' });
  }

  // The beats this was recorded against, signed by the app (phase 5). Optional:
  // a take is a real recording whether or not it carries one, and the column
  // being NULL is what says an older app made it. A value of the wrong shape is
  // not the same as none — it is a client this server does not recognise, and
  // storing it would leave a signature nothing can ever match.
  const signature = typeof req.body.signature === 'string' && req.body.signature !== ''
    ? req.body.signature
    : null;
  if (signature !== null && !narrationUpload.SIGNATURE.test(signature)) {
    narrationUpload.removeQuietly(file.path);
    return res.status(400).json({ error: 'The recording arrived with a beat signature this server does not accept. Upload it again.' });
  }

  const judged = narrationUpload.judgeNarration({
    file: file.path,
    markersMs: req.body.markersMs,
    durationMs: Number(req.body.durationMs),
    beats: Number(req.body.beats),
  });
  if (!judged.ok) {
    narrationUpload.removeQuietly(file.path);
    return res.status(judged.status).json({ error: judged.error });
  }

  // The old name is read in the same statement that writes the new one, with
  // the row locked, so two uploads racing each other each learn which file the
  // other left behind — and the old file is deleted only after the row stops
  // naming it. The other order leaves a tutorial naming a file that is gone.
  let result;
  try {
    result = await pool.query(
      `WITH old AS (SELECT narration_filename FROM saved_lessons WHERE id = $1 FOR UPDATE)
       UPDATE saved_lessons
          SET narration_filename = $2, narration_ms = $3, narration_markers = $4,
              narration_recorded_at = NOW(), narration_take_id = $6,
              narration_signature = $7
        WHERE id = $1 AND (user_id = $5 OR trainer_id = $5)
    RETURNING (SELECT narration_filename FROM old) AS replaced, narration_recorded_at`,
      [lessonId, file.filename, judged.durationMs, JSON.stringify(judged.markers), req.user.id, takeId,
        signature]
    );
  } catch (err) {
    narrationUpload.removeQuietly(file.path);
    logger.error('[NARRATION] Could not keep the recording:', err);
    return res.status(500).json({ error: 'Server error while keeping the recording.' });
  }
  if (result.rowCount === 0) {
    // Deleted between the gate and now.
    narrationUpload.removeQuietly(file.path);
    return res.status(404).json({ error: 'Tutorial not found or you do not have permission to record over it.' });
  }

  const replaced = result.rows[0].replaced;
  if (replaced && replaced !== file.filename) {
    narrationUpload.removeNarrationFile(replaced);
  }

  return res.status(201).json({
    narration: {
      ms: judged.durationMs,
      beats: judged.markers.length,
      takeId,
      recordedAt: result.rows[0].narration_recorded_at,
    },
  });
}

// GET /lessons/:id/narration — which take the server holds for this tutorial.
//
// The app asks before an export so a take already here is not sent again. Two
// answers that must not read alike: a tutorial that is not yours is a 404, and
// one of yours with no recording is `none` — the second is the ordinary state
// of every tutorial nobody has recorded over.
router.get('/:id/narration', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT narration_filename, narration_ms, narration_markers, narration_take_id, narration_recorded_at
         FROM saved_lessons
        WHERE id = $1 AND (user_id = $2 OR trainer_id = $2)`,
      [req.params.id, req.user.id]
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Tutorial not found or you do not have permission to see it.' });
    }
    const row = result.rows[0];
    // The longest take this server accepts, in both answers. The app asks
    // before recording rather than keeping a copy of a number the server
    // derives from its render budget (`narrationUpload.narrationMaxSeconds`).
    const maxMs = narrationUpload.narrationMaxSeconds() * 1000;
    if (!row.narration_filename) return res.json({ status: 'none', maxMs });
    return res.json({
      status: 'ready',
      maxMs,
      takeId: row.narration_take_id,
      ms: row.narration_ms,
      beats: Array.isArray(row.narration_markers) ? row.narration_markers.length : 0,
      recordedAt: row.narration_recorded_at,
    });
  } catch (err) {
    logger.error('[NARRATION] Could not read the recording:', err);
    return res.status(500).json({ error: 'Server error while reading the recording.' });
  }
});

router.post(
  '/:id/narration',
  authenticateToken,
  requireEntitlement(ENT.MP4_EXPORT),
  narrationGate,
  receiveNarration,
  saveNarration,
);

// POST /lessons/:id/export-video
/// What to tell a trainer whose video is finished.
///
/// **A voice that was asked for and did not arrive is news**, and the render
/// answering „Video ready!" is how a missing speech engine came to look like an
/// ordinary export on 9.9.2026 — the log said piper could not start and the app
/// said the video was ready. The film is still worth having, so this is a
/// sentence on a successful export rather than a failure: do the thing, then
/// say what happened to it.
function messageFor(silentBecause) {
  const ready = 'Video rendered successfully, saved, and ready for download!';
  if (!silentBecause) return ready;
  if (silentBecause === 'unavailable') {
    return `${ready} It has no narration: this server has no speech voices installed.`;
  }
  if (silentBecause === 'track') {
    return `${ready} It has no narration: the spoken clips could not be joined into one track.`;
  }
  return `${ready} It has no narration: the voice produced nothing. The server log says why.`;
}

/// What a trainer is told about a render that failed for a reason nobody
/// planned for — one sentence, shared with the job's own last resort.
const { RENDER_FAILED } = renderJobs;

/// Where rendered films are written. They are reproducible, so the retention
/// timer ages them out (services/retentionService.js).
const EXPORTS_DIR = path.join(__dirname, '..', 'exports');

/// A link to [filename] in exports/, signed for [userId] now.
///
/// A filename is what is stored and a link is what is handed out, because a
/// stored token is one that outlives its own expiry.
function downloadUrlFor(userId, filename) {
  return `/recordings/export-download/${encodeURIComponent(filename)}`
    + `?token=${encodeURIComponent(signDownloadToken(userId, filename))}`;
}

// Renders a saved tutorial as an MP4 video with moves, comments, arrows and
// highlighted squares.
//
// **Answered before it is drawn** — item 5 of part two of docs/PLAN-SNIMANJE.md.
// Everything that can refuse a film is still asked here, inside the request, so
// a refusal is a sentence the trainer reads at once: the tutorial, the
// recording, the length, a render of it already running, the queue. A film that
// is accepted is answered 202 with a job id, and drawn behind the answer
// (`services/renderJobs.js`). The app polls `/lessons/export-video/:jobId/
// progress`, whose last answer carries the download link, and the trainer is
// notified either way.
router.post('/:id/export-video', authenticateToken, requireEntitlement(ENT.MP4_EXPORT), async (req, res) => {
  const lessonId = req.params.id;

  try {
    const lessonRes = await pool.query(
      'SELECT id, title FROM saved_lessons WHERE id = $1 AND (user_id = $2 OR trainer_id = $2)',
      [lessonId, req.user.id]
    );
    const lesson = lessonRes.rows[0];
    if (!lesson) {
      return res.status(404).json({ error: 'Tutorial not found or you do not have permission to export it.' });
    }

    const {
      events,
      seconds,
      title,
      resolution,
      boardTheme,
      // The app's own colours: board skin, piece skin and the light or dark
      // theme the trainer is actually looking at. Validated in the renderer,
      // where a value that is not a colour is ignored rather than drawn.
      look,
      narrate,
      voice,
      // The trainer's own recorded voice instead of a synthesised one — phase 4
      // of docs/PLAN-SNIMANJE.md — and the id of the take the app holds.
      useRecording,
      takeId,
      // What the beats say now (phase 5). The recording was made against a beat
      // list, and one that has moved makes every marker after the edit name a
      // beat it was not recorded against.
      signature,
    } = req.body;

    if (!Array.isArray(events) || events.length === 0) {
      return res.status(400).json({ error: 'events must be a non-empty array.' });
    }
    if (!Number.isInteger(seconds) || seconds <= 0) {
      return res.status(400).json({ error: 'seconds must be a positive integer.' });
    }

    const duration = Math.min(seconds, 3600);

    // Looked up and judged before the queue, so a recording that cannot be used
    // is a sentence now rather than a render slot spent finding out.
    let recording = null;
    if (useRecording === true) {
      const stored = await pool.query(
        `SELECT narration_filename, narration_ms, narration_markers, narration_take_id, narration_signature
           FROM saved_lessons WHERE id = $1`,
        [lessonId]
      );
      const judged = narrationUpload.recordingForFilm({
        row: stored.rows[0],
        takeId: typeof takeId === 'string' ? takeId : null,
        signature: typeof signature === 'string' ? signature : null,
        events,
      });
      if (!judged.ok) {
        return res.status(409).json({ error: judged.error, recording: judged.code });
      }
      recording = judged;
    }

    // **Refused before drawing, not after** — item 4 of part two of
    // docs/PLAN-SNIMANJE.md. The frames are countable now, and a film too long
    // to draw used to be drawn until the connection went: a trainer watching a
    // bar for five minutes and getting nothing. Since item 5 no connection is
    // waiting, and the ceiling is the longest one film may hold the render slot
    // (`maxDrawSeconds`). A recorded film is as long as its recording, so that
    // is the length judged; a synthesised voice's length is not known until it
    // has spoken, so that film is judged on the app's reading-speed length here
    // and again at its turn.
    const size = resolution || '720p';
    const filmSeconds = recording ? Math.min(recording.seconds, 3600) : duration;
    const fps = videoRenderer.framesPerSecondOf(recording ? recording.events : events, { resolution: size });
    const draw = renderBudget.drawSeconds({ seconds: filmSeconds, fps, resolution: size });
    if (draw > renderBudget.maxDrawSeconds()) {
      // Only the ways out that were checked would fit.
      const fitsAt = (secs, fpsOf, at) => renderBudget.drawSeconds({ seconds: secs, fps: fpsOf, resolution: at })
        <= renderBudget.maxDrawSeconds();
      const doors = [];
      if (size === '1080p' && fitsAt(filmSeconds, fps, '720p')) doors.push('export it at 720p');
      if (recording && fitsAt(duration, videoRenderer.framesPerSecondOf(events, { resolution: size }), size)) {
        doors.push('export it without your recording');
      }
      return res.status(422).json({
        error: renderBudget.tooLongSentence({ drawSeconds: draw, fps, resolution: size, doors }),
        tooLong: true,
      });
    }

    // **A clock is not a name.** Two renders of one tutorial that start in the
    // same millisecond — the same trainer twice, or a trainer and the student
    // they share it with — used to agree on a filename, and the second one
    // overwrote the first while both download links pointed at it. Whoever
    // clicked got a film they had not asked for. Four random bytes end that.
    const filename = `tutorial_${lessonId}_${boardTheme || 'wood'}_${resolution || '720p'}`
      + `_${Date.now()}_${crypto.randomBytes(4).toString('hex')}.mp4`;
    const exportsDir = EXPORTS_DIR;
    if (!fs.existsSync(exportsDir)) {
      fs.mkdirSync(exportsDir, { recursive: true });
    }

    const exportPath = path.join(exportsDir, filename);

    // **The job, before the queue.** Its row is what the trainer polls and
    // cancels by, and what says how the film ended once this request is long
    // gone — so it exists before anything can start drawing.
    let job;
    try {
      job = await renderJobs.create(pool, { userId: req.user.id, lessonId });
    } catch (err) {
      if (err instanceof renderJobs.RenderAlreadyRunning) {
        // Not a refusal to try again later: the film the trainer wants is
        // already being made, and the app shows that one rather than start a
        // second that would replace it the moment it finished.
        return res.status(409).json({
          error: 'This tutorial is already being rendered.',
          jobId: err.jobId,
          alreadyRendering: true,
        });
      }
      throw err;
    }
    const jobId = job.id;
    // Fired by the trainer's „Cancel" (the DELETE route below), never by the
    // connection: this request is answered before the first frame, and a socket
    // that closes with its answer would otherwise stop every render at birth.
    const { signal } = job;

    let renderEvents = events;
    let renderDuration = duration;
    let audioFilePath = null;
    let narrationAudioPath = null;
    // Null unless a voice was asked for and none was heard. See `narrateFilm`:
    // a silent film that was supposed to speak must not come back wearing the
    // same „Video ready!" as one that spoke.
    let silentBecause = null;

    // **One film at a time.** Two renders side by side share one CPU and finish
    // together, both late; in a queue the first is done in its own time and the
    // second no later than it would have been. The narration is inside the
    // queue with the drawing, because synthesis is the same machine doing the
    // same kind of work.
    const drawFilm = async () => {
      // Cancelled while it waited. Checked before any work, so the slot passes
      // straight to the next trainer.
      throwIfAborted(signal);

      if (recording) {
        // The recording's own timing replaces the app's reading-speed guess,
        // and the file is muxed as it is. **Never `narrationAudioPath`**: that
        // is the synthesised track, deleted in the `finally` below once the
        // film is drawn — and a trainer's voice exists nowhere else.
        renderEvents = recording.events;
        renderDuration = Math.min(recording.seconds, 3600);
        audioFilePath = recording.audioPath;
      } else if (narrate === true) {
        const narrated = await tutorialNarration.narrateFilm({
          events, voice, exportsDir, filename, signal,
        });
        if (narrated) {
          if (narrated.events) renderEvents = narrated.events;
          if (narrated.seconds != null) renderDuration = Math.min(narrated.seconds, 3600);
          narrationAudioPath = narrated.audioPath || null;
          audioFilePath = narrated.audioPath || null;
          silentBecause = narrated.silentBecause || null;
        }
      }

      try {
        // **Asked again at its turn, with what is known now.** A synthesised
        // voice's real length arrives only after it has spoken. Inside the
        // `try` so a synthesised track is still removed by the `finally` below.
        const fpsNow = videoRenderer.framesPerSecondOf(renderEvents, { resolution: size });
        const drawNow = renderBudget.drawSeconds({ seconds: renderDuration, fps: fpsNow, resolution: size });
        renderQueue.revise(jobId, drawNow * 1000);
        if (drawNow > renderBudget.maxDrawSeconds()) {
          throw new renderBudget.RenderTooLong({
            drawSeconds: drawNow, fps: fpsNow, narrated: narrationAudioPath !== null,
          });
        }

        await videoRenderer.renderRecordingToMP4({
          title: title || lesson.title || 'Tutorial',
          timelineEvents: renderEvents,
          audioFilePath: audioFilePath,
          durationSeconds: renderDuration,
          perspective: 'trainer',
          resolution: size,
          boardTheme: boardTheme || 'wood',
          showTitle: true,
          showTimer: true,
          showCoords: true,
          showMoveText: false,
          look,
          onProgress: (drawn, total) => renderProgress.report(jobId, drawn, total),
          signal,
          outputPath: exportPath,
        });
      } finally {
        if (narrationAudioPath) {
          try {
            if (fs.existsSync(narrationAudioPath)) {
              fs.unlinkSync(narrationAudioPath);
            }
          } catch (cleanErr) {
            logger.warn('[TTS] Failed to clean up narration audio file:', cleanErr);
          }
        }
      }
    };

    // **The tutorial keeps its film.** Until this, the only reference to a
    // rendered video was the link in the response, and its token dies in
    // thirty minutes — so closing the „Video ready!" dialog meant rendering the
    // whole thing again, while the file sat in `exports/` for a fortnight where
    // nobody could reach it.
    //
    // The row is written **before** the old file is removed. A crash between
    // the two leaves a file nothing points at, which the retention timer
    // collects; the other order leaves a row pointing at a file that is gone,
    // which is a trainer pressing „Download" and getting nothing.
    const keepFilm = async () => {
      let replaced = null;
      try {
        // Read, then write. A subquery inside `RETURNING` would also give the
        // old value — by the statement's own snapshot — but that is a rule a
        // reader has to know rather than one they can see, and only the render
        // queue and the one-running-render index stop two exports of one
        // tutorial overlapping here.
        const before = await pool.query(
          'SELECT video_filename FROM saved_lessons WHERE id = $1',
          [lessonId]
        );
        replaced = before.rows[0] ? before.rows[0].video_filename : null;

        await pool.query(
          `UPDATE saved_lessons
              SET video_filename = $1, video_rendered_at = NOW(),
                  video_resolution = $2, video_seconds = $3, video_narrated = $4
            WHERE id = $5`,
          [filename, size, renderDuration, recording !== null || (narrate === true && !silentBecause), lessonId]
        );
      } catch (recordErr) {
        // The film exists and the trainer is about to be told so. Failing the
        // export because a bookkeeping write failed would throw away work that
        // succeeded.
        logger.error('Could not record the tutorial video:', recordErr);
      }

      if (replaced && replaced !== filename) {
        const old = path.join(exportsDir, path.basename(replaced));
        try {
          if (fs.existsSync(old)) fs.unlinkSync(old);
        } catch (cleanErr) {
          logger.warn(`[RENDER] Could not remove the replaced video ${replaced}: ${cleanErr.message}`);
        }
      }

      // Metered once there is a film to charge for. A metering write that
      // fails is logged and does not undo the film: the trainer has it either
      // way, and a 500 used to say otherwise.
      try {
        await recordUsage(pool, req.user.id, METRIC.MP4_RENDERS, 1);
        await recordUsage(pool, req.user.id, METRIC.MP4_RENDER_SECONDS, renderDuration);
      } catch (meterErr) {
        logger.error('Could not meter the tutorial video:', meterErr);
      }

      renderProgress.finish(jobId);
      return { status: 'done', message: messageFor(silentBecause), filename };
    };

    // Every other ending, as the outcome its row records. Nothing is metered
    // and no film is recorded on the tutorial: the trainer got none.
    const endingOf = (err) => {
      // The bar has to stop either way. A render that failed and a bar that
      // goes on creeping towards 99 % is the worst of both.
      renderProgress.finish(jobId, { ok: false });
      if (err instanceof RenderAborted) {
        // The trainer cancelled it. The partial file was removed by whichever
        // stage was interrupted, and the slot is already the next trainer's.
        logger.info({ job: jobId }, '[RENDER] cancelled: drawing stopped, slot released');
        return { status: 'cancelled' };
      }
      if (err instanceof renderBudget.RenderTooLong) {
        // Too long only once the voice had spoken — the check before the queue
        // passed on the app's reading-speed length. The film without the voice
        // is the length that passed, so that door is a real one.
        return {
          status: 'failed',
          error: renderBudget.tooLongSentence({
            drawSeconds: err.drawSeconds,
            fps: err.fps,
            resolution: size,
            narrated: err.narrated,
            doors: err.narrated ? ['export it without narration'] : [],
          }),
        };
      }
      logger.error('Tutorial video render failed:', err);
      return { status: 'failed', error: RENDER_FAILED };
    };

    // **Admission is still answered in the request.** The queue refuses a film
    // before it starts — this account's share, or a full queue — and those are
    // sentences a trainer can act on now, so the answer waits until the queue
    // has either taken the film or turned it away. It says it took it by
    // telling the film its place, which it does at once, drawing or waiting.
    let admitted;
    const accepted = new Promise((resolve) => { admitted = resolve; });
    const drawing = renderQueue.run(jobId, drawFilm, (ahead) => {
      admitted();
      renderProgress.queued(jobId, ahead);
    }, {
      owner: req.user.id,
      // No deadline: nothing waits on a connection any more, so there is no
      // moment after which the film is worthless. The estimate still says how
      // long this film will hold the slot.
      estimateMs: draw * 1000,
    });

    try {
      await Promise.race([accepted, drawing]);
    } catch (err) {
      // Refused before any work: nothing drawn, nothing metered, no file
      // written, and no row left behind to say otherwise.
      await renderJobs.discard(pool, jobId);
      if (err instanceof renderQueue.RenderAccountBusy) {
        // **Not „the server is busy".** The films in the way are this trainer's
        // own, and telling them otherwise sends them off to wait for somebody
        // else to finish.
        return res.status(429).json({
          error: 'You already have a video rendering and another one waiting. '
            + 'Wait for one of them to finish and try again.',
        });
      }
      if (err instanceof renderQueue.RenderQueueFull) {
        // 429 rather than 503: this is one client too many for a moment, not a
        // server that is down.
        return res.status(429).json({
          error: 'The server is rendering other videos right now. Try again in a minute or two.',
        });
      }
      throw err;
    }

    renderJobs.detach(pool, jobId, drawing.then(keepFilm, endingOf), {
      userId: req.user.id,
      lessonId,
      title: title || lesson.title || 'Tutorial',
    });

    return res.status(202).json({ jobId, status: 'running' });
  } catch (err) {
    logger.error('Error initiating video export:', err);
    res.status(500).json({ error: 'Error initiating video export.' });
  }
});

// GET /lessons/export-video/:jobId/progress — how far along that render is, and
// what it came to.
//
// Polled by the app while it shows the bar. The row says whether the film is
// still being made, was made, failed or was cancelled — the part that has to
// outlive the process — and while it is being made, the numbers come from
// `renderProgress`, which only the drawing process has. A finished film's
// answer carries a link minted now, so the app needs no second request for it.
//
// Mounted above `/:id` for the same reason `/tts/voices` is.
router.get('/export-video/:jobId/progress', authenticateToken, async (req, res) => {
  const job = renderProgress.jobIdFrom(req.params.jobId);
  if (!job) return res.status(400).json({ error: 'Not a job id.' });

  try {
    // Scoped to the account: a render's state, and above all its download
    // link, are nobody else's — the id alone must not be a way in.
    const row = await renderJobs.find(pool, { id: job, userId: req.user.id });
    if (!row) {
      return res.status(404).json({ error: 'There is no such video render.', status: 'unknown' });
    }
    if (row.status === 'running') {
      return res.json({ ...renderProgress.statusOf(job), status: 'running' });
    }

    const answer = {
      status: row.status,
      done: true,
      known: true,
      percent: row.status === 'done' ? 100 : 0,
      etaSeconds: null,
      queuedAhead: 0,
    };
    if (row.status === 'done') {
      answer.message = row.message;
      const name = row.filename ? path.basename(row.filename) : null;
      // Absent when the file has aged out since: a „Download" on a file that
      // is gone is a button that does nothing.
      if (name && fs.existsSync(path.join(EXPORTS_DIR, name))) {
        answer.downloadUrl = downloadUrlFor(req.user.id, name);
      }
    }
    if (row.status === 'failed') answer.error = row.error;
    return res.json(answer);
  } catch (err) {
    logger.error('Render progress error:', err);
    return res.status(500).json({ error: 'Server error while reading the render.' });
  }
});

// DELETE /lessons/export-video/:jobId — stop a render.
//
// The trigger the disconnect abort used to be (services/renderAbort.js). With a
// 202 the socket closes the moment the answer is sent, so „the client is gone"
// can no longer mean „stop"; the trainer's own button does. A film still waiting
// leaves the queue at once, and one being drawn stops at its next frame — its
// row says so when that has happened, which is why this answers 202.
router.delete('/export-video/:jobId', authenticateToken, async (req, res) => {
  const job = renderProgress.jobIdFrom(req.params.jobId);
  if (!job) return res.status(400).json({ error: 'Not a job id.' });

  try {
    const row = await renderJobs.find(pool, { id: job, userId: req.user.id });
    if (!row) return res.status(404).json({ error: 'There is no such video render.' });
    if (row.status !== 'running') {
      return res.status(409).json({ error: 'This video is no longer rendering.', status: row.status });
    }
    renderJobs.cancel(job);
    return res.status(202).json({ status: 'cancelling' });
  } catch (err) {
    logger.error('Render cancel error:', err);
    return res.status(500).json({ error: 'Server error while cancelling the render.' });
  }
});

// POST /lessons/:id/preview-frames
//
// **A still of the film that has not been made yet.** An export costs tens of
// seconds of the one render slot, and until this the only way to find out that
// the board skin was wrong, that a sentence is too long for the caption band,
// or that a part stands the wrong way round was to render the whole film and
// watch it.
//
// Deliberately **not** in the render queue: a preview is one frame's drawing
// with no ffmpeg, no file and no metering, and the whole point of it is that it
// answers while a film is being drawn for somebody else.
router.post('/:id/preview-frames', authenticateToken, requireEntitlement(ENT.MP4_EXPORT), async (req, res) => {
  try {
    const lessonRes = await pool.query(
      'SELECT id, title FROM saved_lessons WHERE id = $1 AND (user_id = $2 OR trainer_id = $2)',
      [req.params.id, req.user.id]
    );
    const lesson = lessonRes.rows[0];
    if (!lesson) {
      return res.status(404).json({ error: 'Tutorial not found or you do not have permission to preview it.' });
    }

    const { events, seconds, title, resolution, boardTheme, look, beats } = req.body;

    if (!Array.isArray(events) || events.length === 0) {
      return res.status(400).json({ error: 'events must be a non-empty array.' });
    }

    // Which beats, and a hard ceiling on how many. Each frame is a PNG carried
    // back as base64, so this is the one place where „a few more" is a
    // megabyte more.
    const asked = Array.isArray(beats) && beats.length > 0
      ? beats
      : videoRenderer.previewBeatIndexes(events.length);
    if (asked.length > MAX_PREVIEW_FRAMES) {
      return res.status(400).json({ error: `At most ${MAX_PREVIEW_FRAMES} preview frames at a time.` });
    }
    const wanted = [];
    for (const raw of asked) {
      const index = Number(raw);
      if (!Number.isInteger(index) || index < 0 || index >= events.length) {
        return res.status(400).json({ error: 'A preview beat must name an event of this film.' });
      }
      wanted.push(index);
    }

    const frames = [];
    for (const beatIndex of wanted) {
      const png = await videoRenderer.renderPreviewFrame({
        title: title || lesson.title || 'Tutorial',
        timelineEvents: events,
        beatIndex,
        durationSeconds: Number.isInteger(seconds) && seconds > 0 ? seconds : undefined,
        perspective: 'trainer',
        resolution: resolution || '720p',
        boardTheme: boardTheme || 'wood',
        showTitle: true,
        showTimer: true,
        showCoords: true,
        showMoveText: false,
        look,
      });
      frames.push({ beatIndex, png: png.toString('base64') });
    }

    // No `recordUsage`: nothing was rendered and nothing is downloadable. A
    // preview that ate into a trainer's quota would push them back towards
    // rendering blind, which is what it exists to stop.
    res.json({ frames });
  } catch (err) {
    logger.error('Error rendering preview frames:', err);
    res.status(500).json({ error: 'Error rendering the preview.' });
  }
});

// GET /lessons/:id/video
//
// **A link, minted now.** The one from the export dialog expires in thirty
// minutes and lives nowhere else, so this is how a trainer gets their film back
// tomorrow — or on another device, or after closing the dialog without
// pressing Download.
//
// Three answers, and telling them apart is the point: no film has been rendered
// yet, a film was rendered and its file is gone (the retention timer takes an
// export after a fortnight, because a film is reproducible), or here it is.
router.get('/:id/video', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, title, video_filename, video_rendered_at, video_resolution,
              video_seconds, video_narrated
         FROM saved_lessons
        WHERE id = $1 AND (user_id = $2 OR trainer_id = $2)`,
      [req.params.id, req.user.id]
    );
    const lesson = result.rows[0];
    if (!lesson) {
      return res.status(404).json({ error: 'Tutorial not found or you do not have permission to open it.' });
    }
    if (!lesson.video_filename) {
      return res.status(404).json({ error: 'This tutorial has no video yet.', status: 'none' });
    }

    const filename = path.basename(lesson.video_filename);
    const filePath = path.join(EXPORTS_DIR, filename);
    if (!fs.existsSync(filePath)) {
      // Said rather than 404'd, because „it is gone" and „there never was one"
      // lead a trainer to different buttons.
      return res.status(410).json({
        error: 'This video has been deleted to save space. Export it again — it takes as long as it did the first time.',
        status: 'expired',
      });
    }

    res.json({
      status: 'ready',
      filename,
      downloadUrl: downloadUrlFor(req.user.id, filename),
      renderedAt: lesson.video_rendered_at,
      resolution: lesson.video_resolution,
      seconds: lesson.video_seconds,
      narrated: lesson.video_narrated === true,
    });
  } catch (err) {
    logger.error('Fetch tutorial video error:', err);
    res.status(500).json({ error: 'Server error while looking for the video.' });
  }
});

// GET /lessons/labels
router.get('/labels', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT DISTINCT unnest(tags) AS label 
       FROM saved_lessons 
       WHERE user_id = $1 
          OR trainer_id = $1 
          OR trainer_id IN (${acceptedTrainersOf('$1')})
       ORDER BY label ASC`,
      [req.user.id]
    );
    const labels = result.rows.map(row => row.label).filter(Boolean);
    res.json(labels);
  } catch (err) {
    logger.error('Fetch labels error:', err);
    res.status(500).json({ error: 'Server error while fetching labels' });
  }
});

// GET /lessons
router.get('/', authenticateToken, async (req, res) => {
  const { search, includeTags, excludeTags, matchMode } = req.query;
  try {
    let query = `
      SELECT id, title, description, tags, fen, pgn, position_list, created_at,
             (video_filename IS NOT NULL) AS has_video, video_rendered_at,
             -- A film this account has being drawn right now, so the list can
             -- offer its progress rather than a second render (item 5 of part
             -- two of docs/PLAN-SNIMANJE.md).
             (SELECT j.id FROM tutorial_render_jobs j
               WHERE j.lesson_id = saved_lessons.id AND j.user_id = $1
                 AND j.status = 'running'
               LIMIT 1) AS render_job_id,
             (trainer_id != $1 AND user_id != $1) AS is_trainer_lesson
      FROM saved_lessons 
      WHERE (user_id = $1 OR trainer_id = $1 OR trainer_id IN (${acceptedTrainersOf('$1')}))
    `;
    const params = [req.user.id];

    if (search && search.trim() !== '') {
      params.push(`%${search.trim()}%`);
      query += ` AND (title ILIKE $${params.length} OR description ILIKE $${params.length} OR fen ILIKE $${params.length})`;
    }

    if (includeTags && includeTags.trim() !== '') {
      const includesArr = includeTags.split(',').map(t => t.trim()).filter(Boolean);
      if (includesArr.length > 0) {
        params.push(includesArr);
        if (matchMode === 'any') {
          query += ` AND tags && $${params.length}::varchar[]`;
        } else {
          query += ` AND tags @> $${params.length}::varchar[]`;
        }
      }
    }

    if (excludeTags && excludeTags.trim() !== '') {
      const excludesArr = excludeTags.split(',').map(t => t.trim()).filter(Boolean);
      if (excludesArr.length > 0) {
        params.push(excludesArr);
        query += ` AND NOT (tags && $${params.length}::varchar[])`;
      }
    }

    query += ' ORDER BY created_at DESC';

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    logger.error('Fetch lessons error:', err);
    res.status(500).json({ error: 'Server error while fetching lessons' });
  }
});

module.exports = router;
