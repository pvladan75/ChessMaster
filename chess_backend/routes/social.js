const express = require('express');
const router = express.Router();
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');
const { getUserStats } = require('../limitsService');

// POST /trainer/students/add
router.post('/trainer/students/add', authenticateToken, async (req, res) => {
  const { studentEmail } = req.body;
  const trainerId = req.user.id;

  if (!studentEmail) {
    return res.status(400).json({ error: 'Email učenika/prijatelja je obavezan.' });
  }

  try {
    const studentRes = await pool.query('SELECT id, name, email FROM users WHERE email = $1', [studentEmail]);
    if (studentRes.rows.length === 0) {
      return res.status(444 || 404).json({ error: 'Korisnik sa datim email-om nije pronađen.' });
    }

    const student = studentRes.rows[0];
    if (student.id === trainerId) {
      return res.status(400).json({ error: 'Ne možete dodati sami sebe.' });
    }

    await pool.query(
      'INSERT INTO trainer_students (trainer_id, student_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
      [trainerId, student.id]
    );

    await pool.query(
      'INSERT INTO friends (user_id, friend_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
      [trainerId, student.id]
    );
    await pool.query(
      'INSERT INTO friends (user_id, friend_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
      [student.id, trainerId]
    );

    res.json({ message: 'Prijatelj/Učenik uspešno dodat.', student });
  } catch (err) {
    console.error('Error adding student/friend:', err);
    res.status(500).json({ error: 'Greška pri dodavanju.' });
  }
});

// GET /trainer/students
router.get('/trainer/students', authenticateToken, async (req, res) => {
  const trainerId = req.user.id;

  try {
    const result = await pool.query(
      `SELECT u.id, u.name, u.email 
       FROM users u
       JOIN trainer_students ts ON u.id = ts.student_id
       WHERE ts.trainer_id = $1`,
      [trainerId]
    );
    res.json({ students: result.rows });
  } catch (err) {
    console.error('Error fetching students:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju liste.' });
  }
});

// DELETE /trainer/students/:studentId
router.delete('/trainer/students/:studentId', authenticateToken, async (req, res) => {
  const trainerId = req.user.id;
  const { studentId } = req.params;

  try {
    await pool.query('DELETE FROM trainer_students WHERE trainer_id = $1 AND student_id = $2', [trainerId, studentId]);
    await pool.query('DELETE FROM friends WHERE (user_id = $1 AND friend_id = $2) OR (user_id = $2 AND friend_id = $1)', [trainerId, studentId]);
    res.json({ message: 'Učenik/Prijatelj uspešno uklonjen.' });
  } catch (err) {
    console.error('Error removing student:', err);
    res.status(500).json({ error: 'Greška pri uklanjanju.' });
  }
});

// GET /users/me/stats
router.get('/users/me/stats', authenticateToken, async (req, res) => {
  try {
    const stats = await getUserStats(req.user.id);
    res.json(stats);
  } catch (err) {
    console.error('Error fetching user stats:', err);
    res.status(500).json({ error: 'Greška pri preuzimanju statistike.' });
  }
});

// POST /users/account-type
router.post('/users/account-type', authenticateToken, async (req, res) => {
  const { accountType } = req.body;
  const validTypes = ['free', 'premium', 'club', 'pro'];

  if (!accountType || !validTypes.includes(accountType)) {
    return res.status(400).json({ error: 'Nevažeći tip naloga.' });
  }

  try {
    await pool.query('UPDATE users SET account_type = $1 WHERE id = $2', [accountType, req.user.id]);
    res.json({ success: true, message: `Tip naloga uspešno promenjen na '${accountType}'.` });
  } catch (err) {
    console.error('Error updating account type:', err);
    res.status(500).json({ error: 'Greška pri ažuriranju tipa naloga.' });
  }
});

// GET /friends
router.get('/friends', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT u.id, u.name, u.email 
       FROM users u
       JOIN friends f ON u.id = f.friend_id
       WHERE f.user_id = $1`,
      [req.user.id]
    );
    res.json({ friends: result.rows });
  } catch (err) {
    console.error('Error fetching friends:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju liste prijatelja.' });
  }
});

// POST /friends/add
router.post('/friends/add', authenticateToken, async (req, res) => {
  const { friendEmail } = req.body;
  const userId = req.user.id;

  if (!friendEmail) {
    return res.status(400).json({ error: 'Email prijatelja je obavezan.' });
  }

  try {
    const friendRes = await pool.query('SELECT id, name, email FROM users WHERE email = $1', [friendEmail]);
    if (friendRes.rows.length === 0) {
      return res.status(404).json({ error: 'Korisnik sa datim email-om nije pronađen.' });
    }

    const friend = friendRes.rows[0];
    if (friend.id === userId) {
      return res.status(400).json({ error: 'Ne možete dodati sami sebe.' });
    }

    await pool.query('INSERT INTO friends (user_id, friend_id) VALUES ($1, $2) ON CONFLICT DO NOTHING', [userId, friend.id]);
    await pool.query('INSERT INTO friends (user_id, friend_id) VALUES ($1, $2) ON CONFLICT DO NOTHING', [friend.id, userId]);

    res.json({ message: 'Prijatelj uspešno dodat.', friend });
  } catch (err) {
    console.error('Error adding friend:', err);
    res.status(500).json({ error: 'Greška pri dodavanju prijatelja.' });
  }
});

// DELETE /friends/:friendId
router.delete('/friends/:friendId', authenticateToken, async (req, res) => {
  const userId = req.user.id;
  const { friendId } = req.params;

  try {
    await pool.query('DELETE FROM friends WHERE (user_id = $1 AND friend_id = $2) OR (user_id = $2 AND friend_id = $1)', [userId, friendId]);
    res.json({ message: 'Prijatelj uspešno uklonjen.' });
  } catch (err) {
    console.error('Error removing friend:', err);
    res.status(500).json({ error: 'Greška pri uklanjanju prijatelja.' });
  }
});

// GET /notifications
router.get('/notifications', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT n.*, u.name as sender_name 
       FROM user_notifications n
       LEFT JOIN users u ON n.sender_id = u.id
       WHERE n.user_id = $1 
       ORDER BY n.created_at DESC LIMIT 20`,
      [req.user.id]
    );
    res.json({ notifications: result.rows });
  } catch (err) {
    console.error('Error fetching notifications:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju obaveštenja.' });
  }
});

// POST /notifications/:id/read
router.post('/notifications/:id/read', authenticateToken, async (req, res) => {
  try {
    await pool.query('UPDATE user_notifications SET is_read = TRUE WHERE id = $1 AND user_id = $2', [req.params.id, req.user.id]);
    res.json({ success: true });
  } catch (err) {
    console.error('Error marking notification read:', err);
    res.status(500).json({ error: 'Greška pri ažuriranju obaveštenja.' });
  }
});

// POST /invitations/send
router.post('/invitations/send', authenticateToken, async (req, res) => {
  const { studentId, roomCode } = req.body;
  const senderId = req.user.id;

  if (!studentId || !roomCode) {
    return res.status(400).json({ error: 'Parametri studentId i roomCode su obavezni.' });
  }

  try {
    const senderRes = await pool.query('SELECT name FROM users WHERE id = $1', [senderId]);
    const senderName = senderRes.rows[0]?.name || 'Trener/Prijatelj';

    const title = 'Poziv na čas šaha';
    const message = `${senderName} vas poziva da se pridružite šahovskom času u sobi: ${roomCode}`;

    await pool.query(
      `INSERT INTO user_notifications (user_id, sender_id, room_code, title, message)
       VALUES ($1, $2, $3, $4, $5)`,
      [studentId, senderId, roomCode, title, message]
    );

    res.json({ success: true, message: 'Pozivnica uspešno poslata.' });
  } catch (err) {
    console.error('Error sending invitation:', err);
    res.status(500).json({ error: 'Greška pri slanju pozivnice.' });
  }
});

// POST /sessions/schedule
router.post('/sessions/schedule', authenticateToken, async (req, res) => {
  const { title, description, scheduledAt, invites, roomCode } = req.body;
  const hostId = req.user.id;

  if (!title || !scheduledAt || !roomCode) {
    return res.status(400).json({ error: 'Naslov, vreme i kod sobe su obavezni.' });
  }

  try {
    const sessionRes = await pool.query(
      `INSERT INTO scheduled_sessions (host_id, room_code, title, description, scheduled_at)
       VALUES ($1, $2, $3, $4, $5) RETURNING id`,
      [hostId, roomCode, title, description || '', scheduledAt]
    );

    const sessionId = sessionRes.rows[0].id;

    if (invites && Array.isArray(invites) && invites.length > 0) {
      for (const userId of invites) {
        await pool.query(
          `INSERT INTO scheduled_session_invites (session_id, user_id)
           VALUES ($1, $2) ON CONFLICT DO NOTHING`,
          [sessionId, userId]
        );

        const hostRes = await pool.query('SELECT name FROM users WHERE id = $1', [hostId]);
        const hostName = hostRes.rows[0]?.name || 'Trener';

        await pool.query(
          `INSERT INTO user_notifications (user_id, sender_id, room_code, title, message)
           VALUES ($1, $2, $3, $4, $5)`,
          [
            userId,
            hostId,
            roomCode,
            `Zakazan čas: ${title}`,
            `${hostName} je zakazao čas za ${new Date(scheduledAt).toLocaleString('sr-RS')}. Kod sobe: ${roomCode}`
          ]
        );
      }
    }

    res.json({ success: true, message: 'Čas uspešno zakazan.', sessionId });
  } catch (err) {
    console.error('Error scheduling session:', err);
    res.status(500).json({ error: 'Greška pri zakazivanju časa.' });
  }
});

// GET /sessions/scheduled
router.get('/sessions/scheduled', authenticateToken, async (req, res) => {
  const userId = req.user.id;

  try {
    const result = await pool.query(
      `SELECT DISTINCT s.*, u.name as host_name
       FROM scheduled_sessions s
       LEFT JOIN users u ON s.host_id = u.id
       LEFT JOIN scheduled_session_invites i ON s.id = i.session_id
       WHERE s.host_id = $1 OR i.user_id = $1
       ORDER BY s.scheduled_at ASC`,
      [userId]
    );
    res.json({ sessions: result.rows });
  } catch (err) {
    console.error('Error fetching scheduled sessions:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju zakazanih časova.' });
  }
});

module.exports = router;
