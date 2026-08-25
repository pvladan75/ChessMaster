const logger = require('../services/logger');
const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { pool } = require('../db');
const { authenticateToken, signDownloadToken, authenticateDownloadToken } = require('../middleware/auth');
const { requireEntitlement } = require('../middleware/entitlements');
const { ENT, METRIC, recordUsage } = require('../services/entitlementService');
const videoRenderer = require('../videoRenderer');
const { trimPauses } = require('../services/audioTrimmer');
const realtime = require('../services/realtime');
const { mayRecordRoom } = require('../services/recordingConsent');

const uploadStorage = multer.diskStorage({
  destination: function (req, file, cb) {
    const uploadDir = path.join(__dirname, '..', 'uploads');
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '_' + Math.round(Math.random() * 1E9);
    const ext = path.extname(file.originalname) || '.aac';
    cb(null, 'recording_' + uniqueSuffix + ext);
  }
});
const upload = multer({ storage: uploadStorage, limits: { fileSize: 100 * 1024 * 1024 } });

// POST /recordings/save
router.post('/save', authenticateToken, upload.single('audio'), async (req, res) => {
  logger.info('[SERVER_RECORDING_LOG] Received /recordings/save request from user:', req.user ? req.user.id : 'unknown');
  logger.info('[SERVER_RECORDING_LOG] Body keys:', Object.keys(req.body));
  if (req.file) {
    logger.info('[SERVER_RECORDING_LOG] Audio file received:', req.file.path, 'Size:', req.file.size, 'bytes');
  } else {
    logger.info('[SERVER_RECORDING_LOG] No file in req.file');
  }

  const roomId = req.body.roomId;
  const title = req.body.title;
  let timelineJson = req.body.timelineJson;

  if (typeof timelineJson === 'string') {
    try {
      timelineJson = JSON.parse(timelineJson);
    } catch (e) {}
  }

  if (!roomId || !title || !timelineJson) {
    return res.status(400).json({ error: 'Polja roomId, title i timelineJson su obavezna.' });
  }

  // The second lock on the same door. The socket refuses to *start* a recording
  // that a parent has not agreed to, but a client that never announced one can
  // still arrive here with a finished file — and this is the moment a child's
  // voice would land in `uploads/`, which is the one thing in this project that
  // cannot be reproduced or taken back.
  //
  // `null` is a third answer and not a pass: the roster lives in memory, so a
  // backend restarted mid-lesson has forgotten who was there. The save then
  // goes through — refusing would destroy a real lesson over the server's own
  // restart — and says so, rather than reporting a check that never ran as one
  // that passed.
  // Multer has already written the file by the time any of this runs. Leaving
  // it behind on a refusal would put exactly the voice these checks exist for
  // into `uploads/`, refused or not.
  const discardUpload = () => {
    if (!req.file) return;
    try {
      fs.unlinkSync(req.file.path);
    } catch (unlinkErr) {
      logger.error('[SNIMANJE] Odbijen snimak nije mogao da se obriše:', unlinkErr);
    }
  };

  // **Three answers, not two.** "The recording was stopped because a parent
  // refused", "the server does not remember" and "everybody here may be
  // recorded" are three different things, and on 25.8.2026 the first was being
  // reported as the second: the join handler threw the roster away, so a save
  // thirteen seconds after a stop the server itself ordered came back as
  // *"restart usred časa?"*. Same shape as `accountGuard`, and for the same
  // reason — a state nobody can name is a state nobody enforces.
  const stopped = realtime.consentStop(roomId);
  if (stopped && !stopped.obeyed) {
    // The client was told to stop and never said it did. That is the client
    // this rule exists to survive, and its file is the one that may contain a
    // child whose parent refused.
    discardUpload();
    logger.warn(
      `[SNIMANJE] Odbijen upis snimka za sobu ${roomId}: snimanje je zaustavljeno `
      + 'zbog saglasnosti roditelja, a soba nikada nije javila da je stala.',
    );
    return res.status(403).json({
      error: stopped.reason
        || 'Snimanje je zaustavljeno jer roditelj nije dozvolio snimanje.',
      blocked: stopped.blocked,
    });
  }

  const roster = realtime.recordedRoster(roomId);
  let consentUnverified = false;
  if (roster === null) {
    consentUnverified = true;
    logger.warn(
      `[SNIMANJE] Saglasnost nije mogla da se proveri za sobu ${roomId} — `
      + 'server ne pamti ko je bio na času (restart usred časa?).',
    );
  } else {
    const verdict = await mayRecordRoom(pool, { roomCode: roomId, userIds: roster });
    if (!verdict.allowed) {
      discardUpload();
      logger.warn(`[SNIMANJE] Odbijen upis snimka za sobu ${roomId}: ${verdict.reason}`);
      return res.status(403).json({ error: verdict.reason, blocked: verdict.blocked });
    }
    if (stopped) {
      logger.info(
        `[SNIMANJE] Upis za sobu ${roomId} je deo snimljen pre prekida zbog `
        + 'saglasnosti roditelja; soba je javila prekid i taj deo se čuva.',
      );
    }
    realtime.clearRecordedRoster(roomId);
  }

  let pauseIntervals = req.body.pauseIntervals;
  if (typeof pauseIntervals === 'string') {
    try {
      pauseIntervals = JSON.parse(pauseIntervals);
    } catch (e) {
      pauseIntervals = [];
    }
  }

  try {
    let finalAudioUrl = req.body.audioUrl || null;
    let savedAudioPath = null;

    // Stored as a path, never as a full URL.
    //
    // This used to be `${req.protocol}://${req.get('host')}/uploads/...`, which
    // writes whichever host answered into the database for good. Every one of
    // the recordings saved that way points at a LAN address, and behind nginx
    // the protocol would come out as http on an HTTPS-only domain. A path
    // survives moving the server, changing the domain, and TLS; the client
    // joins it with whatever backend it is talking to.
    if (req.file) {
      savedAudioPath = req.file.path;
      finalAudioUrl = `/uploads/${req.file.filename}`;
      logger.info(`[RECORDING] Multipart audio saved: ${req.file.path}, path: ${finalAudioUrl}`);
    } else if (req.body.audioBase64 && req.body.audioBase64.length > 0) {
      const audioFileName = `audio_${Date.now()}_${Math.floor(Math.random()*10000)}.aac`;
      const audioPath = path.join(__dirname, '..', 'uploads', audioFileName);
      const buffer = Buffer.from(req.body.audioBase64, 'base64');
      fs.writeFileSync(audioPath, buffer);
      savedAudioPath = audioPath;
      finalAudioUrl = `/uploads/${audioFileName}`;
      logger.info(`[RECORDING] Base64 audio saved to ${audioPath}, path: ${finalAudioUrl}`);
    }

    // The microphone ran through every pause while the board timeline did not,
    // so the two only line up once those stretches are cut out of the audio.
    // Best effort: audio that still contains its pauses beats a failed save.
    if (savedAudioPath) {
      await trimPauses(savedAudioPath, pauseIntervals);
    }

    let participantIds = [];
    if (req.body.participants) {
      try {
        participantIds = typeof req.body.participants === 'string' ? JSON.parse(req.body.participants) : req.body.participants;
      } catch (e) {}
    }

    // The client sends whoever was in the room when the trainer pressed save —
    // which, after a stop for consent, includes the child who had just walked
    // in and is not in the recording at all. Leaving them there would write a
    // refused child into the roll of a recording they were never part of, and
    // `participants` is also who may play it back (`$1 = ANY(sr.participants)`),
    // so it would show up as *theirs*.
    if (stopped && stopped.blocked.length > 0) {
      const before = participantIds.length;
      participantIds = participantIds
        .filter((id) => !stopped.blocked.includes(Number(id)));
      if (participantIds.length !== before) {
        logger.info(
          `[SNIMANJE] Iz spiska učesnika snimka uklonjen je onaj zbog koga je `
          + `snimanje stalo (soba ${roomId}).`,
        );
      }
    }

    const result = await pool.query(
      `INSERT INTO session_recordings (room_id, host_id, title, audio_url, timeline_json, participants)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING id, room_id, title, created_at`,
      [roomId, req.user.id, title, finalAudioUrl, JSON.stringify(timelineJson), participantIds]
    );
    let message = 'Snimak časa je uspešno sačuvan.';
    if (consentUnverified) {
      message = 'Snimak je sačuvan, ali server nije mogao da proveri saglasnost '
        + 'za snimanje — proverite je pre nego što snimak podelite.';
    } else if (stopped) {
      message = 'Snimanje je zaustavljeno jer roditelj nije dozvolio snimanje. '
        + 'Sačuvan je samo deo snimljen pre nego što je učenik ušao na čas.';
    }
    res.status(201).json({
      message,
      consentUnverified,
      consentStopped: !!stopped,
      recording: result.rows[0],
    });
  } catch (err) {
    logger.error('Error saving recording:', err);
    res.status(500).json({ error: 'Greška pri čuvanju snimka časa: ' + err.message });
  }
});

// GET /recordings
router.get('/', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT sr.id, sr.room_id, sr.host_id, sr.title, sr.audio_url, sr.video_url, sr.created_at, u.name as host_name
       FROM session_recordings sr
       LEFT JOIN users u ON sr.host_id = u.id
       WHERE sr.host_id = $1 OR $1 = ANY(sr.participants)
       ORDER BY sr.created_at DESC`,
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    logger.error('Error fetching recordings:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju snimaka.' });
  }
});

// GET /recordings/:id
// Scoped to the host and the lesson's participants — a recording contains a full
// lesson timeline and the trainer's audio, so it must not be readable by id alone.
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT sr.*, u.name as host_name
       FROM session_recordings sr
       LEFT JOIN users u ON sr.host_id = u.id
       WHERE sr.id = $1 AND (sr.host_id = $2 OR $2 = ANY(sr.participants))`,
      [req.params.id, req.user.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Snimak nije pronađen.' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    logger.error('Error fetching recording details:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju detalja snimka.' });
  }
});

// POST /recordings/:id/export-mp4
// Rendering a lesson costs real server CPU, so the entitlement is checked before
// any of that work starts — not inside the handler after the fact.
router.post('/:id/export-mp4', authenticateToken, requireEntitlement(ENT.MP4_EXPORT), async (req, res) => {
  const {
    perspective,
    resolution,
    pieceStyle,
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
      return res.status(404).json({ error: 'Snimak nije pronađen.' });
    }

    const filename = `recording_${recId}_${pieceStyle || 'classic'}_${boardTheme || 'wood'}_${resolution || '720p'}_${Date.now()}.mp4`;
    const exportsDir = path.join(__dirname, '..', 'exports');
    if (!fs.existsSync(exportsDir)) {
      fs.mkdirSync(exportsDir, { recursive: true });
    }

    const exportPath = path.join(exportsDir, filename);

    let timelineEvents = [];
    try {
      timelineEvents = typeof recording.timeline_json === 'string' ? JSON.parse(recording.timeline_json) : (recording.timeline_json || []);
    } catch (e) {}

    let duration = recording && recording.duration_seconds ? recording.duration_seconds : 10;
    if (timelineEvents.length > 0) {
      const maxMs = timelineEvents[timelineEvents.length - 1].timestampMs || 0;
      duration = Math.max(duration, Math.ceil(maxMs / 1000));
    }

    let audioFilePath = recording ? recording.audio_file_path : null;
    if (!audioFilePath && recording && recording.audio_url) {
      const parts = recording.audio_url.split('/uploads/');
      if (parts.length > 1) {
        audioFilePath = path.join(__dirname, '..', 'uploads', parts[1]);
      }
    }

    await videoRenderer.renderRecordingToMP4({
      title: recording ? recording.title : 'Snimak Časa',
      timelineEvents,
      audioFilePath,
      durationSeconds: duration,
      perspective: perspective || 'trainer',
      resolution: resolution || '720p',
      pieceStyle: pieceStyle || 'classic',
      boardTheme: boardTheme || 'wood',
      showTitle,
      showTimer,
      showCoords,
      showMoveText,
      outputPath: exportPath
    });

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
      message: 'MP4 video je uspešno izrenderovan, sačuvan i spreman za preuzimanje!',
      jobId: `job_${recId}_${Date.now()}`,
      perspective: perspective || 'trainer',
      status: 'completed',
      downloadUrl: downloadUrl,
      filename: filename
    });
  } catch (err) {
    logger.error('Error initiating MP4 export:', err);
    res.status(500).json({ error: 'Greška pri pokretanju MP4 izvoza.' });
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
    return res.status(400).send('Neispravno ime fajla.');
  }

  if (fs.existsSync(filePath)) {
    res.setHeader('Content-Type', 'video/mp4');
    res.download(filePath, safeName);
  } else {
    res.status(404).send('Fajl videa nije pronađen.');
  }
});

module.exports = router;
