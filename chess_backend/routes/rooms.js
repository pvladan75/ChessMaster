const logger = require('../services/logger');
const crypto = require('crypto');
const express = require('express');
const router = express.Router();
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const rateLimit = require('express-rate-limit');
const { guestAccess, setGuestAccess, mayJoinRoom } = require('../services/roomAccess');

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

    const result = await pool.query(
      'INSERT INTO rooms (room_code, creator_id) VALUES ($1, $2) RETURNING *',
      [roomCode, creatorId]
    );

    res.status(201).json({
      room: result.rows[0],
      room_code: roomCode,
    });
  } catch (err) {
    logger.error('Room creation error:', err);
    res.status(500).json({ error: 'Server error during room creation' });
  }
});

// Joining is a handful of taps a day for a real person, and six digits is a
// small space: without a limit this route answers a walk through every code.
const joinLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many attempts. Please try again in 15 minutes.' },
});
router.joinLimiter = joinLimiter;

// POST /rooms/join
//
// Asks the socket's own guest list (`mayJoinRoom`) and answers with the seat —
// never the `rooms` row. It used to return `SELECT *` to anybody signed in, which
// told a stranger who made a room, whether its board was open to students and
// whether guests were let in: a directory for finding a lesson to walk into.
// „No such room" and „not on the guest list" read the same, so the answer does
// not confirm that a code exists. test/rooms_join.test.js.
router.post('/join', joinLimiter, authenticateToken, async (req, res) => {
  const { roomCode } = req.body;

  if (!roomCode) {
    return res.status(400).json({ error: 'Room code is required' });
  }

  try {
    const seat = await mayJoinRoom(pool, { roomCode: String(roomCode), userId: req.user.id });
    if (!seat.allowed) {
      return res.status(404).json({
        error: 'A room with that code does not exist, or you are not on its guest list.',
      });
    }

    res.json({ room: { room_code: String(roomCode), role: seat.role } });
  } catch (err) {
    logger.error('Room join error:', err);
    res.status(500).json({ error: 'Error joining room' });
  }
});

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
