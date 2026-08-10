const express = require('express');
const router = express.Router();
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');

function generateRoomCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
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

    res.status(201).json({ room: result.rows[0] });
  } catch (err) {
    console.error('Room creation error:', err);
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
    console.error('Room join error:', err);
    res.status(500).json({ error: 'Greška pri pridruživanju sobi' });
  }
});

module.exports = router;
