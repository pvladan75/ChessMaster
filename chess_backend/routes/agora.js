require('dotenv').config();
const logger = require('../services/logger');
const express = require('express');
const router = express.Router();
const { RtcTokenBuilder, RtcRole } = require('agora-token');
const { authenticateToken } = require('../middleware/auth');
const { pool } = require('../db');
const { maySpeakInRoom } = require('../services/roomAccess');

const APP_ID = process.env.AGORA_APP_ID;
const APP_CERTIFICATE = process.env.AGORA_APP_CERTIFICATE;
const TOKEN_TTL_SECONDS = parseInt(process.env.AGORA_TOKEN_TTL_SECONDS || '3600', 10);

const isConfigured = Boolean(APP_ID && APP_CERTIFICATE);

if (!isConfigured) {
  logger.warn(
    '[AGORA] AGORA_APP_ID / AGORA_APP_CERTIFICATE are not set. Voice channels will fall back to ' +
    'App-ID-only mode, which lets anyone holding the App ID join any channel. Enable the App ' +
    'Certificate in the Agora console and set both values before going to production.'
  );
}

// GET /agora/config - lets the client learn the App ID without shipping it in the binary
router.get('/config', authenticateToken, (req, res) => {
  res.json({ appId: APP_ID || null, tokenRequired: isConfigured });
});

// POST /agora/token - issues a channel-scoped RTC token for the calling user
//
// The channel name **is the room code**, which is why this route decides two
// things rather than none. Until 25.8.2026 it decided nothing: any signed-in
// caller could ask for any channel and was handed a `PUBLISHER` token. The guest
// list guarded `joinGame` and `audio_join`, and this route walked around both —
// take a token, join the Agora channel, be heard in a lesson, and never appear
// on the roster.
//
// So: who may be in the room is asked here too, and **whether they may be heard
// becomes the role in the token**. A microphone that is off because the app
// muted itself is off until somebody replaces the app; a subscriber token cannot
// publish no matter what client holds it. That is the difference between a rule
// and a request, and this one is about children's voices ending up in uploads/.
router.post('/token', authenticateToken, async (req, res) => {
  const { channelName, uid } = req.body;

  if (!channelName || typeof channelName !== 'string') {
    return res.status(400).json({ error: 'channelName je obavezan.' });
  }

  const numericUid = Number.isInteger(uid) ? uid : parseInt(uid, 10);
  if (!Number.isInteger(numericUid) || numericUid < 0) {
    return res.status(400).json({ error: 'uid mora biti nenegativan ceo broj.' });
  }

  let seat;
  try {
    seat = await maySpeakInRoom(pool, {
      roomCode: channelName,
      userId: req.user.id,
    });
  } catch (err) {
    logger.error('[AGORA] Provera pristupa sobi nije uspela:', err);
    return res.status(500).json({ error: 'Greška pri proveri pristupa sobi.' });
  }

  if (!seat.allowed) {
    logger.warn(
      `[AGORA] Odbijen token za kanal ${channelName}: ${seat.reason} (korisnik ${req.user.id})`
    );
    // Refused out loud, with the same reason the socket gives, so the app says
    // one thing rather than hanging on "povezivanje…".
    return res.status(403).json({ error: 'Niste na spisku za ovu sobu.', reason: seat.reason });
  }

  if (!isConfigured) {
    // Honest signal: the client keeps working in the current tokenless mode, but the
    // response makes clear the channel is not actually protected.
    //
    // `maySpeak` is still answered, because the app uses it to decide whether to
    // ask for the microphone at all — but it is worth being plain about what it
    // is worth here: without the App Certificate the role is advice, since
    // anybody holding the App ID can join the channel as they please.
    return res.json({
      appId: APP_ID || null,
      token: null,
      tokenRequired: false,
      maySpeak: seat.maySpeak,
      role: seat.role,
      warning: 'Agora App Certificate nije konfigurisan — kanal nije zaštićen tokenom, '
        + 'pa ni pravo na mikrofon nije stvarno ograničeno.',
    });
  }

  const expiresAt = Math.floor(Date.now() / 1000) + TOKEN_TTL_SECONDS;

  try {
    const token = RtcTokenBuilder.buildTokenWithUid(
      APP_ID,
      APP_CERTIFICATE,
      channelName,
      numericUid,
      seat.maySpeak ? RtcRole.PUBLISHER : RtcRole.SUBSCRIBER,
      expiresAt,
      expiresAt
    );

    logger.info(
      `[AGORA] Issued ${seat.maySpeak ? 'PUBLISHER' : 'SUBSCRIBER'} token for user `
      + `${req.user.id} on channel ${channelName} (${seat.role})`
    );
    res.json({
      appId: APP_ID,
      token,
      tokenRequired: true,
      expiresAt,
      maySpeak: seat.maySpeak,
      role: seat.role,
    });
  } catch (err) {
    logger.error('[AGORA] Failed to build RTC token:', err);
    res.status(500).json({ error: 'Greška pri generisanju Agora tokena.' });
  }
});

module.exports = router;
