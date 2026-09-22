const logger = require('../services/logger');
const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const { pool } = require('../db');
const { authenticateToken, signDownloadToken, authenticateDownloadToken } = require('../middleware/auth');
const { requireEntitlement } = require('../middleware/entitlements');
const { ENT, METRIC, recordUsage } = require('../services/entitlementService');
const videoRenderer = require('../videoRenderer');
const renderQueue = require('../services/renderQueue');
const renderBudget = require('../services/renderBudget');
const multer = require('multer');
const narrationUpload = require('../services/narrationUpload');
const lessonRecording = require('../services/lessonRecording');
const recordingShares = require('../services/recordingShares');
const { latestVideoFor } = require('../services/recordingVideo');
const { EXPORTS_DIR } = require('../services/retentionService');
const { mayRecordNarration } = require('../services/recordingConsent');

// There is no `POST /recordings/save` any more (phase 5a of
// docs/PLAN-SESIJA.md): a session with other people in it is not recorded at
// all, and the room's writer went first. The one writer here is
// `POST /recordings/lesson` below — an adult alone in Preparation (phase 5b).
// test/recording_writer_gone.test.js.

// POST /recordings/lesson — a lesson recorded alone in Preparation. Phase 5b.2
// of docs/PLAN-SESIJA.md; services/lessonRecording.js says what is checked.
//
// Three stages, in this order on purpose, as the narration's: who may record
// is asked **before** multer accepts a byte, so a refused voice never touches
// the disk; the file is received with the cap as multer's own limit; and only
// then is it judged and kept.

/// Eighteen and a known age — the narration's rule, because it is the same act:
/// putting one's own voice into `uploads/`, where nothing can be taken back.
async function lessonGate(req, res, next) {
  try {
    const consent = await mayRecordNarration(pool, req.user.id);
    if (!consent.allowed) return res.status(403).json({ error: consent.reason });
    return next();
  } catch (err) {
    logger.error('[LESSON] Gate failed:', err);
    return res.status(500).json({ error: 'Server error while checking the recording.' });
  }
}

const lessonMulter = multer({
  storage: multer.diskStorage({
    destination(req, file, cb) {
      const dir = lessonRecording.lessonDir();
      try {
        fs.mkdirSync(dir, { recursive: true });
        cb(null, dir);
      } catch (err) {
        cb(err);
      }
    },
    filename(req, file, cb) {
      cb(null, lessonRecording.lessonFilename(req.user.id));
    },
  }),
  // The events travel as one multipart field: 20 000 of them is about 3 MB.
  limits: { fileSize: narrationUpload.narrationMaxBytes(), files: 1, fields: 8, fieldSize: 4 * 1024 * 1024 },
});

/// The file, received — or a sentence rather than Express's HTML error page.
function receiveLesson(req, res, next) {
  lessonMulter.single('audio')(req, res, (err) => {
    if (!err) return next();
    if (req.file) narrationUpload.removeQuietly(req.file.path);
    if (err instanceof multer.MulterError && err.code === 'LIMIT_FILE_SIZE') {
      return res.status(413).json({
        error: `This recording is longer than ${Math.floor(narrationUpload.narrationMaxSeconds() / 60)} minutes, `
          + 'which is the most one recording may be. Record a shorter one.',
      });
    }
    logger.error('[LESSON] Upload failed:', err);
    return res.status(400).json({ error: 'The recording could not be received. Upload it again.' });
  });
}

/// Judged, and kept — or deleted, with the reason.
async function saveLesson(req, res) {
  const file = req.file;
  if (!file) return res.status(400).json({ error: 'No recording was sent.' });
  const drop = (status, error) => {
    narrationUpload.removeQuietly(file.path);
    return res.status(status).json({ error });
  };

  const title = typeof req.body.title === 'string' ? req.body.title.trim() : '';
  if (title === '' || title.length > 255) {
    return drop(400, 'A recording needs a title of at most 255 characters.');
  }

  const header = narrationUpload.judgeWavHeader({
    file: file.path,
    durationMs: Number(req.body.durationMs),
    tooLong: 'Record a shorter one.',
  });
  if (!header.ok) return drop(header.status, header.error);

  const judged = lessonRecording.judgeLessonEvents({
    events: req.body.events,
    durationMs: header.measuredMs,
  });
  if (!judged.ok) return drop(judged.status, judged.error);

  const level = narrationUpload.judgeWavLevel(file.path, header.info);
  if (!level.ok) return drop(level.status, level.error);

  try {
    // No `audio_url`: that column holds a public path, and this sound is not
    // public. `audio_file` names it in the private folder; readers are handed
    // a signed link (`lessonRecording.lessonAudioUrl`).
    const result = await pool.query(
      `INSERT INTO session_recordings
         (room_id, source, host_id, title, audio_file, duration_ms, timeline_json, participants)
       VALUES (NULL, 'preparation', $1, $2, $3, $4, $5, '{}')
       RETURNING id, title, created_at`,
      [req.user.id, title, file.filename, header.measuredMs, JSON.stringify(judged.events)]
    );
    return res.status(201).json({ recording: result.rows[0] });
  } catch (err) {
    logger.error('[LESSON] Could not keep the recording:', err);
    return drop(500, 'Server error while keeping the recording.');
  }
}

router.post('/lesson', authenticateToken, lessonGate, receiveLesson, saveLesson);

// GET /recordings/lesson-limits — asked by the app before the microphone opens:
// whether this account may record at all, and for how long. A trainer who may
// not record is told before they have spoken for half an hour, not at upload;
// the cap is the server's, derived from the render budget, never a copy in the
// app. The gate above still decides — this only says in advance what it will.
router.get('/lesson-limits', authenticateToken, async (req, res) => {
  try {
    const consent = await mayRecordNarration(pool, req.user.id);
    return res.json({
      allowed: consent.allowed,
      reason: consent.reason,
      maxMs: narrationUpload.narrationMaxSeconds() * 1000,
    });
  } catch (err) {
    logger.error('[LESSON] Limits failed:', err);
    return res.status(500).json({ error: 'Server error while checking the recording.' });
  }
});

// GET /recordings/lesson-audio/:filename?token=… — a lesson's sound, for the
// reader the token was signed for and for this one file. Range requests are
// served (`sendFile`), so a player can seek.
router.get('/lesson-audio/:filename', authenticateDownloadToken, (req, res) => {
  const file = lessonRecording.lessonAudioPath(req.params.filename);
  if (!fs.existsSync(file)) return res.status(404).json({ error: 'The recording\'s sound is missing.' });
  res.type('audio/wav');
  return res.sendFile(file);
});

// GET /recordings — the host's own, the room's participants', and those shared
// with the reader by a trainer who still teaches them (services/recordingShares.js).
router.get('/', authenticateToken, async (req, res) => {
  try {
    res.json(await recordingShares.readableRecordings(pool, req.user.id));
  } catch (err) {
    logger.error('Error fetching recordings:', err);
    res.status(500).json({ error: 'Error fetching recordings.' });
  }
});

// GET /recordings/:id/shares — who the host has shared this with, for the
// dialog's ticks. The host's question only; anybody else reads an empty list.
router.get('/:id/shares', authenticateToken, async (req, res) => {
  try {
    res.json({ studentIds: await recordingShares.sharedWith(pool, req.params.id, req.user.id) });
  } catch (err) {
    logger.error('Error fetching shares:', err);
    res.status(500).json({ error: 'Error fetching who this is shared with.' });
  }
});

// PUT /recordings/:id/shares { studentIds } — the whole list; a name left out
// is a share taken back. The host's own accepted students only.
router.put('/:id/shares', authenticateToken, async (req, res) => {
  try {
    const result = await recordingShares.setShares(pool, {
      recordingId: req.params.id,
      hostId: req.user.id,
      studentIds: req.body && req.body.studentIds,
      hostName: req.user.name,
    });
    if (!result.ok) return res.status(result.status).json({ error: result.error });
    return res.json({ added: result.added });
  } catch (err) {
    logger.error('Error sharing a recording:', err);
    return res.status(500).json({ error: 'Error sharing the recording.' });
  }
});

// GET /recordings/:id
// Scoped as the list is — a recording contains a whole lesson and a voice, so
// it must not be readable by id alone. Not yours reads as not found.
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const found = await recordingShares.readableRecording(pool, req.params.id, req.user.id);
    if (!found) {
      return res.status(404).json({ error: 'Recording not found.' });
    }
    // A lesson's sound is private: the reader gets a link signed for them and
    // for that file, and never the file's name alone.
    const row = { ...found };
    const signed = lessonRecording.lessonAudioUrl(row, req.user.id);
    if (signed) row.audio_url = signed;
    delete row.audio_file;
    // The trainer's latest render, signed for this reader while it is still
    // on disk (phase 5b.5); the stored link carries the host's token.
    row.video_download_url = latestVideoFor(row, req.user.id, EXPORTS_DIR);
    delete row.video_url;
    res.json(row);
  } catch (err) {
    logger.error('Error fetching recording details:', err);
    res.status(500).json({ error: 'Error fetching recording details.' });
  }
});

// DELETE /recordings/:id — the host deletes their own recording, and its
// sound with it (the owner's decision of 22.9.2026: a deleted recording is
// gone, voice included). Anybody else, a student it is shared with included,
// reads not found.
//
// The row goes first and the file after it: a file that cannot be removed
// leaves a sound nothing names, which `removeQuietly` logs, rather than a row
// in the list whose sound is gone.
router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const deleted = await recordingShares.deleteOwnRecording(pool, req.params.id, req.user.id);
    if (!deleted) return res.status(404).json({ error: 'Recording not found.' });
    narrationUpload.removeQuietly(lessonRecording.soundOf(deleted));
    return res.json({ deleted: true });
  } catch (err) {
    logger.error('Error deleting a recording:', err);
    return res.status(500).json({ error: 'Error deleting the recording.' });
  }
});

// POST /recordings/:id/export-mp4
// Rendering a lesson costs real server CPU, so the entitlement is checked before
// any of that work starts — not inside the handler after the fact.
router.post('/:id/export-mp4', authenticateToken, requireEntitlement(ENT.MP4_EXPORT), async (req, res) => {
  const {
    perspective,
    resolution,
    boardTheme,
    showTitle = true,
    showTimer = true,
    showCoords = true,
    showMoveText = true
  } = req.body;
  try {
    const recId = req.params.id;

    // Only the host may spend server CPU rendering their own lesson.
    const recRes = await pool.query(
      'SELECT * FROM session_recordings WHERE id = $1 AND host_id = $2',
      [recId, req.user.id]
    );
    const recording = recRes.rows[0];
    if (!recording) {
      return res.status(404).json({ error: 'Recording not found.' });
    }

    // A clock is not a name: two exports of one recording starting in the same
    // millisecond used to agree on a filename, and the second overwrote the
    // first while both download links pointed at it. See the tutorial export.
    const filename = `recording_${recId}_${boardTheme || 'wood'}_${resolution || '720p'}`
      + `_${Date.now()}_${crypto.randomBytes(4).toString('hex')}.mp4`;
    const exportsDir = path.join(__dirname, '..', 'exports');
    if (!fs.existsSync(exportsDir)) {
      fs.mkdirSync(exportsDir, { recursive: true });
    }

    const exportPath = path.join(exportsDir, filename);

    let timelineEvents = [];
    try {
      timelineEvents = typeof recording.timeline_json === 'string' ? JSON.parse(recording.timeline_json) : (recording.timeline_json || []);
    } catch (e) {}

    // A lesson knows how long its audio is; the film must run to its end, not
    // stop at the last move. A room recording never said, and keeps the old
    // guess.
    let duration = recording && recording.duration_ms ? Math.ceil(recording.duration_ms / 1000) : 10;
    if (timelineEvents.length > 0) {
      const maxMs = timelineEvents[timelineEvents.length - 1].timestampMs || 0;
      duration = Math.max(duration, Math.ceil(maxMs / 1000));
    }

    let audioFilePath = recording && recording.audio_file
      ? lessonRecording.lessonAudioPath(recording.audio_file)
      : null;
    if (!audioFilePath && recording && recording.audio_url) {
      const parts = recording.audio_url.split('/uploads/');
      if (parts.length > 1) {
        audioFilePath = path.join(__dirname, '..', 'uploads', parts[1]);
      }
    }

    // The same queue the tutorial export waits in: one machine, one film at a
    // time, whichever door the render came through.
    //
    // **This export is still drawn inside the request that asked for it**, so
    // its client stops waiting when nginx closes that request
    // (`requestSeconds`, 300 s). It tells the queue so, with a deadline: a job
    // with one goes in front of every tutorial film waiting in the background,
    // and one the queue cannot finish in time is refused with a sentence now,
    // rather than cut off by the proxy later (item 5 of part two of
    // docs/PLAN-SNIMANJE.md). A film already being drawn is not interrupted —
    // one slot draws one film — so the time left of it counts against this one.
    // The estimate is what the queue judges that by.
    const arrivedAt = Date.now();
    const size = resolution || '720p';
    const estimateMs = renderBudget.drawSeconds({
      seconds: duration,
      fps: videoRenderer.framesPerSecondOf(timelineEvents, { resolution: size }),
      resolution: size,
    }) * 1000;

    const rendered = await renderQueue.run(filename, () => videoRenderer.renderRecordingToMP4({
      title: recording ? recording.title : 'Session Recording',
      timelineEvents,
      audioFilePath,
      durationSeconds: duration,
      perspective: perspective || 'trainer',
      resolution: resolution || '720p',
      boardTheme: boardTheme || 'wood',
      showTitle,
      showTimer,
      showCoords,
      showMoveText,
      outputPath: exportPath
    // The account, so this export competes for its own share rather than for
    // the whole machine: the same queue serves tutorial films, and one user's
    // three exports used to fill it for everybody.
    }), () => {}, {
      owner: req.user.id,
      estimateMs,
      deadline: arrivedAt + renderBudget.requestSeconds() * 1000,
    }).catch((err) => {
      if (err instanceof renderQueue.RenderAccountBusy) return 'account-busy';
      if (err instanceof renderQueue.RenderQueueFull) return 'queue-full';
      // No time rather than no room — at the door, or at its turn.
      if (err instanceof renderQueue.RenderWontFit) return err;
      throw err;
    });

    if (rendered === 'account-busy') {
      return res.status(429).json({
        error: 'You already have a video rendering and another one waiting. '
          + 'Wait for one of them to finish and try again.',
      });
    }

    if (rendered === 'queue-full') {
      return res.status(429).json({
        error: 'The server is rendering other videos right now. Try again in a minute or two.',
      });
    }

    if (rendered instanceof renderQueue.RenderWontFit) {
      // Room in the queue, not time: what is in front of this film would leave
      // it unfinished when the proxy closes this request. Said now, while the
      // trainer is still connected to read it; nothing was drawn or metered.
      return res.status(429).json({ error: renderBudget.retrySentence(rendered.waitMs) });
    }

    // The client hands this to the system browser, which cannot send an
    // Authorization header — so the grant travels as a short-lived token bound
    // to this one file. Stored as a path for the same reason as the audio: the
    // host that rendered the video must not be baked into the row.
    const downloadToken = signDownloadToken(req.user.id, filename);
    const downloadUrl =
      `/recordings/export-download/${encodeURIComponent(filename)}` +
      `?token=${encodeURIComponent(downloadToken)}`;

    await pool.query('UPDATE session_recordings SET video_url = $1 WHERE id = $2', [downloadUrl, recId]);

    // Booked only after the render succeeded — a failed job costs CPU but the
    // user got nothing, and charging for that would be wrong twice over.
    // Rendered seconds track cost better than a render count, since a 90-minute
    // lesson and a 3-minute clip are not the same job.
    await recordUsage(pool, req.user.id, METRIC.MP4_RENDERS, 1);
    await recordUsage(pool, req.user.id, METRIC.MP4_RENDER_SECONDS, duration);

    res.json({
      message: 'MP4 video rendered successfully, saved, and ready for download!',
      jobId: `job_${recId}_${Date.now()}`,
      perspective: perspective || 'trainer',
      status: 'completed',
      downloadUrl: downloadUrl,
      filename: filename
    });
  } catch (err) {
    logger.error('Error initiating MP4 export:', err);
    res.status(500).json({ error: 'Error initiating MP4 export.' });
  }
});

// GET /recordings/export-download/:filename?token=...
// The token is issued by the export route and is bound to a single filename.
// path.basename is a second line of defence so a traversal sequence can never
// escape the exports directory even if a token were somehow forged.
router.get('/export-download/:filename', authenticateDownloadToken, (req, res) => {
  const safeName = path.basename(req.params.filename);
  const exportsDir = path.join(__dirname, '..', 'exports');
  const filePath = path.join(exportsDir, safeName);

  if (!filePath.startsWith(exportsDir + path.sep)) {
    logger.warn(`[DOWNLOAD] Rejected path outside exports directory: ${req.params.filename}`);
    return res.status(400).send('Invalid filename.');
  }

  if (fs.existsSync(filePath)) {
    res.setHeader('Content-Type', 'video/mp4');
    res.download(filePath, safeName);
  } else {
    res.status(404).send('Video file not found.');
  }
});

module.exports = router;
