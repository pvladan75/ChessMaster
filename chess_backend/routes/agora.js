require('dotenv').config();
const logger = require('../services/logger');
const express = require('express');
const router = express.Router();
const { RtcTokenBuilder, RtcRole } = require('agora-token');
const { authenticateToken } = require('../middleware/auth');

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
router.post('/token', authenticateToken, (req, res) => {
  const { channelName, uid } = req.body;

  if (!channelName || typeof channelName !== 'string') {
    return res.status(400).json({ error: 'channelName je obavezan.' });
  }

  const numericUid = Number.isInteger(uid) ? uid : parseInt(uid, 10);
  if (!Number.isInteger(numericUid) || numericUid < 0) {
    return res.status(400).json({ error: 'uid mora biti nenegativan ceo broj.' });
  }

  if (!isConfigured) {
    // Honest signal: the client keeps working in the current tokenless mode, but the
    // response makes clear the channel is not actually protected.
    return res.json({
      appId: APP_ID || null,
      token: null,
      tokenRequired: false,
      warning: 'Agora App Certificate nije konfigurisan — kanal nije zaštićen tokenom.',
    });
  }

  const expiresAt = Math.floor(Date.now() / 1000) + TOKEN_TTL_SECONDS;

  try {
    const token = RtcTokenBuilder.buildTokenWithUid(
      APP_ID,
      APP_CERTIFICATE,
      channelName,
      numericUid,
      RtcRole.PUBLISHER,
      expiresAt,
      expiresAt
    );

    logger.info(`[AGORA] Issued RTC token for user ${req.user.id} on channel ${channelName}`);
    res.json({ appId: APP_ID, token, tokenRequired: true, expiresAt });
  } catch (err) {
    logger.error('[AGORA] Failed to build RTC token:', err);
    res.status(500).json({ error: 'Greška pri generisanju Agora tokena.' });
  }
});

module.exports = router;
