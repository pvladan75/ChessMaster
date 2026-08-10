const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { checkUserLimits } = require('../limitsService');
const videoRenderer = require('../videoRenderer');

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
  console.log('[SERVER_RECORDING_LOG] Received /recordings/save request from user:', req.user ? req.user.id : 'unknown');
  console.log('[SERVER_RECORDING_LOG] Body keys:', Object.keys(req.body));
  if (req.file) {
    console.log('[SERVER_RECORDING_LOG] Audio file received:', req.file.path, 'Size:', req.file.size, 'bytes');
  } else {
    console.log('[SERVER_RECORDING_LOG] No file in req.file');
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

  try {
    let finalAudioUrl = req.body.audioUrl || null;

    if (req.file) {
      finalAudioUrl = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;
      console.log(`[RECORDING] Multipart audio saved: ${req.file.path}, URL: ${finalAudioUrl}`);
    } else if (req.body.audioBase64 && req.body.audioBase64.length > 0) {
      const audioFileName = `audio_${Date.now()}_${Math.floor(Math.random()*10000)}.aac`;
      const audioPath = path.join(__dirname, '..', 'uploads', audioFileName);
      const buffer = Buffer.from(req.body.audioBase64, 'base64');
      fs.writeFileSync(audioPath, buffer);
      finalAudioUrl = `${req.protocol}://${req.get('host')}/uploads/${audioFileName}`;
      console.log(`[RECORDING] Base64 audio saved to ${audioPath}, URL: ${finalAudioUrl}`);
    }

    let participantIds = [];
    if (req.body.participants) {
      try {
        participantIds = typeof req.body.participants === 'string' ? JSON.parse(req.body.participants) : req.body.participants;
      } catch (e) {}
    }

    const result = await pool.query(
      `INSERT INTO session_recordings (room_id, host_id, title, audio_url, timeline_json, participants)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING id, room_id, title, created_at`,
      [roomId, req.user.id, title, finalAudioUrl, JSON.stringify(timelineJson), participantIds]
    );
    res.status(201).json({ message: 'Snimak časa je uspešno sačuvan.', recording: result.rows[0] });
  } catch (err) {
    console.error('Error saving recording:', err);
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
    console.error('Error fetching recordings:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju snimaka.' });
  }
});

// GET /recordings/:id
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT sr.*, u.name as host_name
       FROM session_recordings sr
       LEFT JOIN users u ON sr.host_id = u.id
       WHERE sr.id = $1`,
      [req.params.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Snimak nije pronađen.' });
    }
    res.json(result.rows[0]);
  } catch (err) {
    console.error('Error fetching recording details:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju detalja snimka.' });
  }
});

// POST /recordings/:id/export-mp4
router.post('/:id/export-mp4', authenticateToken, async (req, res) => {
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
    const limitCheck = await checkUserLimits(pool, req.user.id, 'export_mp4');
    if (!limitCheck.allowed) {
      return res.status(403).json({ error: limitCheck.reason });
    }

    const recId = req.params.id;

    const recRes = await pool.query('SELECT * FROM session_recordings WHERE id = $1', [recId]);
    const recording = recRes.rows[0];

    const filename = `recording_${recId}_${pieceStyle || 'alpha'}_${boardTheme || 'wood'}_${resolution || '720p'}_${Date.now()}.mp4`;
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
      pieceStyle: pieceStyle || 'alpha',
      boardTheme: boardTheme || 'wood',
      showTitle,
      showTimer,
      showCoords,
      showMoveText,
      outputPath: exportPath
    });

    const host = req.get('host');
    const protocol = req.protocol;
    const downloadUrl = `${protocol}://${host}/recordings/export-download/${filename}`;

    await pool.query('UPDATE session_recordings SET video_url = $1 WHERE id = $2', [downloadUrl, recId]);

    res.json({
      message: 'MP4 video je uspešno izrenderovan, sačuvan i spreman za preuzimanje!',
      jobId: `job_${recId}_${Date.now()}`,
      perspective: perspective || 'trainer',
      status: 'completed',
      downloadUrl: downloadUrl,
      filename: filename
    });
  } catch (err) {
    console.error('Error initiating MP4 export:', err);
    res.status(500).json({ error: 'Greška pri pokretanju MP4 izvoza.' });
  }
});

// GET /recordings/export-download/:filename
router.get('/export-download/:filename', (req, res) => {
  const filePath = path.join(__dirname, '..', 'exports', req.params.filename);
  if (fs.existsSync(filePath)) {
    res.setHeader('Content-Type', 'video/mp4');
    res.setHeader('Content-Disposition', `attachment; filename="${req.params.filename}"`);
    res.download(filePath, req.params.filename);
  } else {
    res.status(404).send('Fajl videa nije pronađen.');
  }
});

module.exports = router;
