const logger = require('../services/logger');
const crypto = require('crypto');
const express = require('express');
const router = express.Router();
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const rateLimit = require('express-rate-limit');
const { guestAccess, setGuestAccess } = require('../services/roomAccess');
const { endRoom, startSession, roomState, liveSessionsFor } = require('../services/roomLifecycle');
const realtime = require('../services/realtime');

/// Six digits, from the cryptographic source rather than from `Math.random()`.
///
/// The code stopped being what authorises anybody — `roomAccess.mayJoinRoom`
/// does that now — but it is still what somebody types to name a room, and a
/// predictable one invites the guessing it used to reward.
function generateRoomCode() {
  return String(crypto.randomInt(100000, 1000000));
}

// POST /rooms/create
router.post('/create', authenticateToken, async (req, res) => {
  const creatorId = req.user.id;
  let roomCode = generateRoomCode();

  try {
    let codeCheck = await pool.query('SELECT * FROM rooms WHERE room_code = $1', [roomCode]);
    while (codeCheck.rows.length > 0) {
      roomCode = generateRoomCode();
      codeCheck = await pool.query('SELECT * FROM rooms WHERE room_code = $1', [roomCode]);
    }

    // A trainer has at most one live session (`services/roomLifecycle.js`), so
    // starting this one ends whatever they had open — atomically, or a double
    // tap makes two.
    const { room, ended } = await startSession(pool, { creatorId, roomCode });

    // After the row exists: telling people must not be able to stop the room
    // they were promised from being made.
    announceEnded(ended, 'replaced');

    res.status(201).json({
      room,
      room_code: roomCode,
    });
  } catch (err) {
    logger.error('Room creation error:', err);
    res.status(500).json({ error: 'Server error during room creation' });
  }
});

/// Tells whoever is still sitting in these rooms that they are over. Never
/// throws: the rooms are already ended in the database, and that is the fact.
function announceEnded(roomCodes, reason) {
  for (const code of roomCodes) {
    try {
      realtime.closeRoom(code, { reason });
    } catch (err) {
      logger.error(`[SOBA] Kraj sesije ${code} nije objavljen:`, err);
    }
  }
}

// POST /rooms/:roomCode/end
//
// Only the room's creator. Ending twice is not an error — the second call finds
// nothing live and says so — because „End session" pressed on a bad connection
// is pressed again.
router.post('/:roomCode/end', authenticateToken, async (req, res) => {
  try {
    const ended = await endRoom(pool, {
      roomCode: req.params.roomCode,
      userId: req.user.id,
    });
    if (ended) announceEnded([req.params.roomCode], 'ended');
    res.json({ ended });
  } catch (err) {
    logger.error('[SOBA] Sesija nije mogla da se završi:', err);
    res.status(500).json({ error: 'Could not end the session.' });
  }
});

// GET /rooms/live  ->  { sessions: [{ roomCode, trainerName }] }
//
// The sessions the caller could walk into now — those of the people who teach
// them. Mounted **before** `/:roomCode/...` so that „live" is never read as a
// room code.
router.get('/live', authenticateToken, async (req, res) => {
  try {
    res.json({ sessions: await liveSessionsFor(pool, req.user.id) });
  } catch (err) {
    logger.error('[SOBA] Žive sesije nisu mogle da se pročitaju:', err);
    res.status(500).json({ error: 'Could not read the sessions.' });
  }
});

// GET /rooms/:roomCode/state  ->  { state: 'live' | 'ended' | 'not-yours' }
//
// What the app asks about a room it remembers, before offering to go back to
// it. Limited like `/join`, since it answers the same question about a code —
// but on a counter of its own: Home asks this on every load, and spending the
// join allowance on it would lock somebody out of the room they are asking about.
const stateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 120,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many attempts. Please try again in 15 minutes.' },
});

router.get('/:roomCode/state', stateLimiter, authenticateToken, async (req, res) => {
  try {
    const state = await roomState(pool, {
      roomCode: req.params.roomCode,
      userId: req.user.id,
    });
    res.json({ state });
  } catch (err) {
    logger.error('[SOBA] Stanje sobe nije moglo da se pročita:', err);
    res.status(500).json({ error: 'Could not read the room.' });
  }
});

// There is no `POST /rooms/join` any more. Typing a six-digit code was removed
// on 21.9.2026 on the owner's word, for everybody: the ways into a session are
// an invitation and `GET /rooms/live`, and both name the room for the person
// instead of asking them to.

// GET /rooms/:roomCode/guest-access
//
// Only the room's creator, and a plain 403 for anybody else: whether a room is
// open to strangers is not a thing to learn about somebody else's room.
router.get('/:roomCode/guest-access', authenticateToken, async (req, res) => {
  try {
    const allowGuests = await guestAccess(pool, {
      roomCode: req.params.roomCode,
      userId: req.user.id,
    });
    if (allowGuests === null) {
      return res.status(403).json({ error: 'That room is not yours.' });
    }
    res.json({ allowGuests });
  } catch (err) {
    logger.error('[SOBA] Prekidač za goste nije mogao da se pročita:', err);
    res.status(500).json({ error: 'Could not read room settings.' });
  }
});

// PATCH /rooms/:roomCode/guest-access  { allowGuests }
//
// The body has to say which way, in so many words. `undefined` used to be a
// perfectly good `false` in JavaScript, and a switch that turns itself off
// because a field was misspelt is the quiet failure this project keeps paying
// for — here it would quietly *open* or *close* a room full of children.
router.patch('/:roomCode/guest-access', authenticateToken, async (req, res) => {
  const wanted = req.body?.allowGuests;
  if (wanted !== true && wanted !== false) {
    return res.status(400).json({ error: 'Missing allowGuests (true or false).' });
  }

  try {
    const allowGuests = await setGuestAccess(pool, {
      roomCode: req.params.roomCode,
      userId: req.user.id,
      allowGuests: wanted,
    });
    if (allowGuests === null) {
      return res.status(403).json({ error: 'That room is not yours.' });
    }
    logger.info(
      `[SOBA] ${req.params.roomCode}: gosti ${allowGuests ? 'dozvoljeni' : 'zabranjeni'} (korisnik ${req.user.id})`,
    );
    res.json({ allowGuests });
  } catch (err) {
    logger.error('[SOBA] Prekidač za goste nije mogao da se promeni:', err);
    res.status(500).json({ error: 'Could not save room settings.' });
  }
});

module.exports = router;
