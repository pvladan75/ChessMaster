const logger = require('../services/logger');
const crypto = require('crypto');
const express = require('express');
const router = express.Router();
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { guestAccess, setGuestAccess } = require('../services/roomAccess');

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

// POST /rooms/join
router.post('/join', authenticateToken, async (req, res) => {
  const { roomCode } = req.body;

  if (!roomCode) {
    return res.status(400).json({ error: 'Kod sobe je obavezan' });
  }

  try {
    const result = await pool.query('SELECT * FROM rooms WHERE room_code = $1 AND status = $2', [roomCode, 'active']);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Soba sa unetim kodom ne postoji ili je zatvorena' });
    }

    res.json({ room: result.rows[0] });
  } catch (err) {
    logger.error('Room join error:', err);
    res.status(500).json({ error: 'Greška pri pridruživanju sobi' });
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
      return res.status(403).json({ error: 'Ta soba nije vaša.' });
    }
    res.json({ allowGuests });
  } catch (err) {
    logger.error('[SOBA] Prekidač za goste nije mogao da se pročita:', err);
    res.status(500).json({ error: 'Podešavanje sobe nije moglo da se pročita.' });
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
    return res.status(400).json({ error: 'Nedostaje allowGuests (true ili false).' });
  }

  try {
    const allowGuests = await setGuestAccess(pool, {
      roomCode: req.params.roomCode,
      userId: req.user.id,
      allowGuests: wanted,
    });
    if (allowGuests === null) {
      return res.status(403).json({ error: 'Ta soba nije vaša.' });
    }
    logger.info(
      `[SOBA] ${req.params.roomCode}: gosti ${allowGuests ? 'dozvoljeni' : 'zabranjeni'} (korisnik ${req.user.id})`,
    );
    res.json({ allowGuests });
  } catch (err) {
    logger.error('[SOBA] Prekidač za goste nije mogao da se promeni:', err);
    res.status(500).json({ error: 'Podešavanje sobe nije moglo da se sačuva.' });
  }
});

module.exports = router;
