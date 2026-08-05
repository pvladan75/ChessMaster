require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');
const { pool, initDB } = require('./db');
const { getUserStats, checkUserLimits } = require('./limitsService');
const geminiService = require('./geminiService');

const app = express();
const server = http.createServer(app);

// Initialize Socket.io with CORS enabled for frontend connection
const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'chessmaster_jwt_default_secret_key_2026';

// Middleware for parsing JSON
app.use(express.json());

// CORS headers middleware
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  next();
});

// Authentication Middleware
function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token is required' });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired token' });
    }
    req.user = user;
    next();
  });
}

// Role authorization Middleware
function requireRole(role) {
  return (req, res, next) => {
    if (!req.user || req.user.role !== role) {
      return res.status(403).json({ error: `Access denied. Role '${role}' required.` });
    }
    next();
  };
}

// Basic health check endpoint
app.get('/', (req, res) => {
  res.json({ status: 'ok', message: 'Chess Master backend is running' });
});

// AUTHENTICATION ROUTES

// POST /register
app.post('/register', async (req, res) => {
  const { email, password, name, role } = req.body;

  if (!email || !password || !name || !role) {
    return res.status(400).json({ error: 'All fields (email, password, name, role) are required' });
  }

  if (role !== 'trener' && role !== 'ucenik') {
    return res.status(400).json({ error: "Role must be 'trener' or 'ucenik'" });
  }

  try {
    // Check if user already exists
    const userCheck = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    if (userCheck.rows.length > 0) {
      return res.status(400).json({ error: 'User with this email already exists' });
    }

    // Hash password
    const saltRounds = 10;
    const passwordHash = await bcrypt.hash(password, saltRounds);

    // Save user to DB
    const result = await pool.query(
      'INSERT INTO users (email, password_hash, name, role) VALUES ($1, $2, $3, $4) RETURNING id, email, name, role',
      [email, passwordHash, name, role]
    );

    const user = result.rows[0];

    // Generate JWT
    const token = jwt.sign(
      { id: user.id, email: user.email, name: user.name, role: user.role },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.status(201).json({ token, user });
  } catch (err) {
    console.error('Registration error:', err);
    res.status(500).json({ error: 'Server error during registration' });
  }
});

// POST /login
app.post('/login', async (req, res) => {
  const { email, password } = req.body;

  if (!email || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }

  try {
    // Fetch user
    const result = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    if (result.rows.length === 0) {
      return res.status(400).json({ error: 'Invalid email or password' });
    }

    const user = result.rows[0];

    // Verify password
    const validPassword = await bcrypt.compare(password, user.password_hash);
    if (!validPassword) {
      return res.status(400).json({ error: 'Invalid email or password' });
    }

    // Generate JWT
    const token = jwt.sign(
      { id: user.id, email: user.email, name: user.name, role: user.role },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role
      }
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: 'Server error during login' });
  }
});

// GOOGLE AUTH & STUDENT MANAGEMENT ROUTES

// POST /auth/google
app.post('/auth/google', async (req, res) => {
  const { idToken, accessToken, email: reqEmail, name: reqName } = req.body;

  let email, name;

  if (idToken) {
    try {
      const verifyUrl = `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`;
      const response = await fetch(verifyUrl);
      if (response.ok) {
        const payload = await response.json();
        email = payload.email;
        name = payload.name;
      }
    } catch (e) {
      console.error('Google ID Token verification failed:', e);
    }
  }

  if (!email && accessToken) {
    try {
      const userInfoUrl = `https://www.googleapis.com/oauth2/v3/userinfo?access_token=${encodeURIComponent(accessToken)}`;
      const response = await fetch(userInfoUrl);
      if (response.ok) {
        const payload = await response.json();
        email = payload.email;
        name = payload.name || payload.given_name;
      }
    } catch (e) {
      console.error('Google Access Token verification failed:', e);
    }
  }

  if (!email && reqEmail) {
    email = reqEmail;
    name = reqName;
  }

  if (!email) {
    return res.status(400).json({ error: 'Nije moguće verifikovati Google nalog.' });
  }

  try {
    let userResult = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    let user;

    if (userResult.rows.length === 0) {
      const defaultPasswordHash = 'google_oauth_placeholder_hash';
      const insertResult = await pool.query(
        'INSERT INTO users (email, password_hash, name, role) VALUES ($1, $2, $3, $4) RETURNING id, email, name, role',
        [email, defaultPasswordHash, name || 'Korisnik', 'user']
      );
      user = insertResult.rows[0];
    } else {
      user = userResult.rows[0];
    }

    const token = jwt.sign(
      { id: user.id, email: user.email, name: user.name, role: user.role },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      token,
      user: {
        id: user.id,
        email: user.email,
        name: user.name,
        role: user.role
      }
    });
  } catch (err) {
    console.error('Error during Google authentication:', err);
    res.status(500).json({ error: 'Greška na serveru prilikom Google prijave.' });
  }
});

// POST /trainer/students/add
app.post('/trainer/students/add', authenticateToken, requireRole('trener'), async (req, res) => {
  const { email } = req.body;
  if (!email) {
    return res.status(400).json({ error: 'Student email is required' });
  }

  try {
    const studentCheck = await pool.query('SELECT id, email, name, role FROM users WHERE email = $1', [email.trim()]);
    if (studentCheck.rows.length === 0) {
      return res.status(404).json({ error: 'Korisnik sa tim emailom nije pronađen.' });
    }

    const student = studentCheck.rows[0];
    if (student.role !== 'ucenik') {
      return res.status(400).json({ error: 'Taj korisnik nije registrovan kao učenik.' });
    }

    await pool.query(
      'INSERT INTO trainer_students (trainer_id, student_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
      [req.user.id, student.id]
    );

    res.status(200).json({
      message: 'Student je uspešno dodat.',
      student: {
        id: student.id,
        email: student.email,
        name: student.name,
        role: student.role
      }
    });
  } catch (err) {
    console.error('Add student error:', err);
    res.status(500).json({ error: 'Server error while adding student' });
  }
});

// GET /trainer/students
app.get('/trainer/students', authenticateToken, requireRole('trener'), async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT u.id, u.email, u.name, u.role 
       FROM users u 
       JOIN trainer_students ts ON u.id = ts.student_id 
       WHERE ts.trainer_id = $1 
       ORDER BY u.name ASC`,
      [req.user.id]
    );

    const students = result.rows.map(student => {
      const isOnline = onlineUsers[student.id] ? true : false;
      return {
        ...student,
        status: isOnline ? 'online' : 'offline'
      };
    });

    res.json(students);
  } catch (err) {
    console.error('Get students error:', err);
    res.status(500).json({ error: 'Server error while fetching students' });
  }
});

// ROOM MANAGEMENT ROUTES

// POST /rooms/create (restricted to trainers)
app.post('/rooms/create', authenticateToken, requireRole('trener'), async (req, res) => {
  try {
    let roomCode = '';
    let isUnique = false;

    // Generate unique 6-digit room code
    while (!isUnique) {
      roomCode = Math.floor(100000 + Math.random() * 900000).toString();
      const codeCheck = await pool.query('SELECT id FROM rooms WHERE room_code = $1', [roomCode]);
      if (codeCheck.rows.length === 0) {
        isUnique = true;
      }
    }

    const defaultFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

    // Insert room into DB
    const result = await pool.query(
      'INSERT INTO rooms (room_code, creator_id, current_fen) VALUES ($1, $2, $3) RETURNING id, room_code, creator_id, current_fen, status, board_control',
      [roomCode, req.user.id, defaultFen]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Room creation error:', err);
    res.status(500).json({ error: 'Server error during room creation' });
  }
});

// POST /rooms/join (allows students to check if code is valid)
app.post('/rooms/join', authenticateToken, async (req, res) => {
  const { roomCode } = req.body;

  if (!roomCode) {
    return res.status(400).json({ error: 'Room code is required' });
  }

  try {
    const result = await pool.query(
      'SELECT id, room_code, creator_id, current_fen, status, board_control FROM rooms WHERE room_code = $1 AND status = \'active\'',
      [roomCode]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Room not found or is no longer active' });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error('Join room error:', err);
    res.status(500).json({ error: 'Server error while checking room status' });
  }
});

// LESSONS PERSISTENCE ROUTES

// POST /lessons/save (accessible to all authenticated users)
app.post('/lessons/save', authenticateToken, async (req, res) => {
  const { title, description, tags, fen, pgn, positionList } = req.body;

  if (!title || (!fen && (!positionList || positionList.length === 0))) {
    return res.status(400).json({ error: 'Title and either FEN or positionList are required' });
  }

  // Default starting FEN if positionList course is provided
  const initialFen = fen || (positionList && positionList.length > 0 ? positionList[0].fen : 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');

  try {
    const result = await pool.query(
      'INSERT INTO saved_lessons (user_id, trainer_id, title, description, tags, fen, pgn, position_list) VALUES ($1, $1, $2, $3, $4, $5, $6, $7) RETURNING *',
      [req.user.id, title, description || null, tags || null, initialFen, pgn || null, positionList ? JSON.stringify(positionList) : null]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Save lesson error:', err);
    res.status(500).json({ error: 'Server error while saving lesson' });
  }
});

// GET /lessons/labels (fetch unique labels used by user or their trainer for autocomplete)
app.get('/lessons/labels', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT DISTINCT unnest(tags) AS label 
       FROM saved_lessons 
       WHERE user_id = $1 
          OR trainer_id = $1 
          OR trainer_id IN (SELECT trainer_id FROM trainer_students WHERE student_id = $1) 
       ORDER BY label ASC`,
      [req.user.id]
    );
    const labels = result.rows.map(row => row.label).filter(Boolean);
    res.json(labels);
  } catch (err) {
    console.error('Fetch labels error:', err);
    res.status(500).json({ error: 'Server error while fetching labels' });
  }
});

// GET /lessons (accessible to all authenticated users with advanced logical matrix search and trainer lessons)
app.get('/lessons', authenticateToken, async (req, res) => {
  const { search, includeTags, excludeTags, matchMode } = req.query;
  try {
    let query = `
      SELECT id, title, description, tags, fen, pgn, position_list, created_at,
             (trainer_id != $1 AND user_id != $1) AS is_trainer_lesson
      FROM saved_lessons 
      WHERE (user_id = $1 OR trainer_id = $1 OR trainer_id IN (SELECT trainer_id FROM trainer_students WHERE student_id = $1))
    `;
    const params = [req.user.id];

    if (search && search.trim() !== '') {
      params.push(`%${search.trim()}%`);
      query += ` AND (title ILIKE $${params.length} OR description ILIKE $${params.length} OR fen ILIKE $${params.length})`;
    }

    if (includeTags && includeTags.trim() !== '') {
      const includesArr = includeTags.split(',').map(t => t.trim()).filter(Boolean);
      if (includesArr.length > 0) {
        params.push(includesArr);
        if (matchMode === 'any') {
          query += ` AND tags && $${params.length}::varchar[]`;
        } else {
          query += ` AND tags @> $${params.length}::varchar[]`;
        }
      }
    }

    if (excludeTags && excludeTags.trim() !== '') {
      const excludesArr = excludeTags.split(',').map(t => t.trim()).filter(Boolean);
      if (excludesArr.length > 0) {
        params.push(excludesArr);
        query += ` AND NOT (tags && $${params.length}::varchar[])`;
      }
    }

    query += ' ORDER BY created_at DESC';

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (err) {
    console.error('Fetch lessons error:', err);
    res.status(500).json({ error: 'Server error while fetching lessons' });
  }
});

// Helper function to extract piece color from FEN at a specific square (e.g. "e2")
function getPieceColorAt(fen, square) {
  if (!fen || !square || square.length < 2) return null;
  const boardPart = fen.split(' ')[0];
  const ranks = boardPart.split('/');

  const colChar = square[0];
  const rowChar = square[1];

  const col = colChar.charCodeAt(0) - 97; // 'a' -> 0, 'b' -> 1...
  const row = 8 - parseInt(rowChar);       // '8' -> 0, '7' -> 1...

  if (row < 0 || row > 7 || col < 0 || col > 7) return null;

  const rankStr = ranks[row];
  let colIndex = 0;
  for (let i = 0; i < rankStr.length; i++) {
    const char = rankStr[i];
    if (/\d/.test(char)) {
      colIndex += parseInt(char);
    } else {
      if (colIndex === col) {
        return char === char.toUpperCase() ? 'white' : 'black';
      }
      colIndex++;
    }
  }
  return null;
}

// STATS & LIMITS ROUTES
app.get('/users/me/stats', authenticateToken, async (req, res) => {
  try {
    const stats = await getUserStats(pool, req.user.id);
    res.json(stats);
  } catch (err) {
    console.error('Error fetching user stats:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju statistike korisnika.' });
  }
});

app.post('/users/account-type', authenticateToken, async (req, res) => {
  const { account_type } = req.body;
  if (!['free', 'premium'].includes(account_type)) {
    return res.status(400).json({ error: 'Nevažeći tip naloga (podržani: free, premium).' });
  }

  try {
    await pool.query('UPDATE users SET account_type = $1 WHERE id = $2', [account_type, req.user.id]);
    const stats = await getUserStats(pool, req.user.id);
    res.json({ message: 'Tip naloga je uspešno ažuriran.', stats });
  } catch (err) {
    console.error('Error updating account type:', err);
    res.status(500).json({ error: 'Greška pri ažuriranju tipa naloga.' });
  }
});

// LESSON RECORDINGS ROUTES
app.post('/recordings/save', authenticateToken, async (req, res) => {
  const { roomId, title, timelineJson, audioUrl } = req.body;
  if (!roomId || !title || !timelineJson) {
    return res.status(400).json({ error: 'Polja roomId, title i timelineJson su obavezna.' });
  }

  try {
    const result = await pool.query(
      `INSERT INTO session_recordings (room_id, host_id, title, audio_url, timeline_json)
       VALUES ($1, $2, $3, $4, $5) RETURNING id, room_id, title, created_at`,
      [roomId, req.user.id, title, audioUrl || null, JSON.stringify(timelineJson)]
    );
    res.status(201).json({ message: 'Snimak časa je uspešno sačuvan.', recording: result.rows[0] });
  } catch (err) {
    console.error('Error saving recording:', err);
    res.status(500).json({ error: 'Greška pri čuvanju snimka časa.' });
  }
});

app.get('/recordings', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT sr.id, sr.room_id, sr.host_id, sr.title, sr.audio_url, sr.video_url, sr.created_at, u.name as host_name
       FROM session_recordings sr
       LEFT JOIN users u ON sr.host_id = u.id
       ORDER BY sr.created_at DESC`
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching recordings:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju snimaka.' });
  }
});

app.get('/recordings/:id', authenticateToken, async (req, res) => {
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

app.post('/recordings/:id/export-mp4', authenticateToken, async (req, res) => {
  const { perspective } = req.body; // 'trainer' or 'student'
  try {
    const limitCheck = await checkUserLimits(pool, req.user.id, 'export_mp4');
    if (!limitCheck.allowed) {
      return res.status(403).json({ error: limitCheck.reason });
    }

    const recId = req.params.id;

    // Check if cached video url already exists in DB
    const checkRes = await pool.query('SELECT video_url FROM session_recordings WHERE id = $1', [recId]);
    if (checkRes.rows.length > 0 && checkRes.rows[0].video_url) {
      return res.json({
        message: 'Video je već ranije izrenderovan i dostupan za brzo preuzimanje!',
        status: 'completed',
        downloadUrl: checkRes.rows[0].video_url,
        cached: true,
      });
    }

    const recRes = await pool.query('SELECT * FROM session_recordings WHERE id = $1', [recId]);
    const recording = recRes.rows[0];

    const filename = `recording_${recId}_${perspective || 'trainer'}_${Date.now()}.mp4`;
    const exportsDir = path.join(__dirname, 'exports');
    if (!fs.existsSync(exportsDir)) {
      fs.mkdirSync(exportsDir, { recursive: true });
    }

    const exportPath = path.join(exportsDir, filename);

    // Calculate duration or fallback to 10 seconds
    const duration = Math.max(5, Math.min(3600, (recording && recording.duration_seconds) ? recording.duration_seconds : 10));
    const audioPath = recording ? recording.audio_file_path : null;

    let ffmpegCmd;
    if (audioPath && fs.existsSync(audioPath)) {
      ffmpegCmd = `ffmpeg -y -f lavfi -i color=c=0x1E1E2E:s=1280x720:d=${duration} -i "${audioPath}" -c:v libx264 -tune stillimage -pix_fmt yuv420p -c:a aac -b:a 192k -shortest "${exportPath}"`;
    } else {
      ffmpegCmd = `ffmpeg -y -f lavfi -i color=c=0x1E1E2E:s=1280x720:d=${duration} -f lavfi -i anullsrc=r=44100:cl=stereo -c:v libx264 -tune stillimage -pix_fmt yuv420p -c:a aac -b:a 192k -shortest "${exportPath}"`;
    }

    await new Promise((resolve, reject) => {
      exec(ffmpegCmd, (error, stdout, stderr) => {
        if (error) {
          console.error('FFmpeg MP4 export error:', stderr);
          return reject(error);
        }
        resolve();
      });
    });

    const host = req.get('host');
    const protocol = req.protocol;
    const downloadUrl = `${protocol}://${host}/recordings/export-download/${filename}`;

    // Cache video_url in session_recordings table
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

app.get('/recordings/export-download/:filename', (req, res) => {
  const filePath = path.join(__dirname, 'exports', req.params.filename);
  if (fs.existsSync(filePath)) {
    res.download(filePath);
  } else {
    res.status(404).send('Fajl videa nije pronađen.');
  }
});

// ADMIN ROUTE - RESET ALL USERS & DATA
app.post('/admin/reset-all-users', async (req, res) => {
  try {
    await pool.query('TRUNCATE users RESTART IDENTITY CASCADE;');
    res.json({ message: 'Svi nalozi i povezani podaci su uspešno izbrisani iz baze.' });
  } catch (err) {
    console.error('Error clearing users:', err);
    res.status(500).json({ error: 'Greška pri brisanju korisnika iz baze.' });
  }
});

// FRIENDS MANAGEMENT ROUTES
app.get('/friends', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT f.id as friendship_id, u.id, u.email, u.name
       FROM friends f
       JOIN users u ON f.friend_id = u.id
       WHERE f.user_id = $1
       ORDER BY u.name ASC`,
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching friends:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju liste prijatelja.' });
  }
});

app.post('/friends/add', authenticateToken, async (req, res) => {
  const { email } = req.body;
  if (!email || !email.trim()) {
    return res.status(400).json({ error: 'Email adresa je obavezna.' });
  }

  const targetEmail = email.trim().toLowerCase();
  if (targetEmail === req.user.email.toLowerCase()) {
    return res.status(400).json({ error: 'Ne možete dodati sebe kao prijatelja.' });
  }

  try {
    const userRes = await pool.query('SELECT id, email, name FROM users WHERE LOWER(email) = $1', [targetEmail]);
    if (userRes.rows.length === 0) {
      return res.status(404).json({ error: 'Korisnik sa tom email adresom nije pronađen.' });
    }

    const friend = userRes.rows[0];

    // Insert relationship both ways (user -> friend, friend -> user)
    await pool.query(
      `INSERT INTO friends (user_id, friend_id) VALUES ($1, $2), ($2, $1) ON CONFLICT DO NOTHING`,
      [req.user.id, friend.id]
    );

    res.status(201).json({ message: 'Prijatelj je uspešno dodat!', friend });
  } catch (err) {
    console.error('Error adding friend:', err);
    res.status(500).json({ error: 'Greška pri dodavanju prijatelja.' });
  }
});

app.delete('/friends/:friendId', authenticateToken, async (req, res) => {
  try {
    const friendId = req.params.friendId;
    await pool.query(
      `DELETE FROM friends WHERE (user_id = $1 AND friend_id = $2) OR (user_id = $2 AND friend_id = $1)`,
      [req.user.id, friendId]
    );
    res.json({ message: 'Prijatelj je uklonjen iz liste.' });
  } catch (err) {
    console.error('Error removing friend:', err);
    res.status(500).json({ error: 'Greška pri uklanjanju prijatelja.' });
  }
});

// NOTIFICATIONS & INVITATIONS ROUTES
app.get('/notifications', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT n.id, n.room_code, n.title, n.message, n.is_read, n.created_at, u.name as sender_name
       FROM user_notifications n
       JOIN users u ON n.sender_id = u.id
       WHERE n.user_id = $1 AND n.is_read = FALSE
       ORDER BY n.created_at DESC`,
      [req.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('Error fetching notifications:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju notifikacija.' });
  }
});

app.post('/notifications/:id/read', authenticateToken, async (req, res) => {
  try {
    await pool.query(
      `UPDATE user_notifications SET is_read = TRUE WHERE id = $1 AND user_id = $2`,
      [req.params.id, req.user.id]
    );
    res.json({ message: 'Notifikacija označena kao pročitana.' });
  } catch (err) {
    console.error('Error reading notification:', err);
    res.status(500).json({ error: 'Greška pri ažuriranju notifikacije.' });
  }
});

app.post('/invitations/send', authenticateToken, async (req, res) => {
  const { friendIds, roomCode } = req.body;
  if (!Array.isArray(friendIds) || friendIds.length === 0 || !roomCode) {
    return res.status(400).json({ error: 'Nevažeći parametri za pozivnicu.' });
  }

  try {
    const senderRes = await pool.query('SELECT name FROM users WHERE id = $1', [req.user.id]);
    const senderName = senderRes.rows[0]?.name || 'Prijatelj';

    for (const friendId of friendIds) {
      await pool.query(
        `INSERT INTO user_notifications (user_id, sender_id, room_code, title, message)
         VALUES ($1, $2, $3, $4, $5)`,
        [
          friendId,
          req.user.id,
          roomCode,
          'Pozivnica u sesiju',
          `Korisnik ${senderName} vas poziva da se pridružite šahovskoj sesiji (Soba: ${roomCode}).`
        ]
      );

      const onlineUser = onlineUsers[friendId];
      if (onlineUser && onlineUser.socketId) {
        io.to(onlineUser.socketId).emit('session_invite_received', {
          senderName,
          roomCode,
          message: `Korisnik ${senderName} vas poziva u sobu ${roomCode}!`,
        });
      }
    }

    res.json({ message: 'Pozivnice su uspešno poslate prijateljima!' });
  } catch (err) {
    console.error('Error sending invitations:', err);
    res.status(500).json({ error: 'Greška pri slanju pozivnica.' });
  }
});

// SCHEDULED SESSIONS & GOOGLE CALENDAR ROUTES

function generateGoogleCalendarUrl(title, description, roomCode, scheduledAtIso) {
  const startDate = new Date(scheduledAtIso);
  const endDate = new Date(startDate.getTime() + 60 * 60 * 1000); // 1 hour duration

  const formatCalDate = (d) => d.toISOString().replace(/-|:|\.\d\d\d/g, '');
  const dates = `${formatCalDate(startDate)}/${formatCalDate(endDate)}`;

  const details = `${description || 'Šahovska sesija i lekcija'}\n\nKod sobe za pristup: ${roomCode}\nAplikacija Chess Master`;
  const location = `Chess Master Soba: ${roomCode}`;

  return `https://calendar.google.com/calendar/render?action=TEMPLATE&text=${encodeURIComponent(title)}&dates=${dates}&details=${encodeURIComponent(details)}&location=${encodeURIComponent(location)}`;
}

app.post('/sessions/schedule', authenticateToken, async (req, res) => {
  const { title, description, scheduledAt, friendIds } = req.body;
  if (!title || !scheduledAt) {
    return res.status(400).json({ error: 'Naslov i datum/vreme zakazivanja su obavezni.' });
  }

  try {
    let roomCode;
    let isUnique = false;
    while (!isUnique) {
      roomCode = Math.floor(100000 + Math.random() * 900000).toString();
      const check = await pool.query('SELECT id FROM rooms WHERE room_code = $1', [roomCode]);
      if (check.rows.length === 0) isUnique = true;
    }

    await pool.query(
      `INSERT INTO rooms (room_code, creator_id, status) VALUES ($1, $2, 'active')`,
      [roomCode, req.user.id]
    );

    const sessResult = await pool.query(
      `INSERT INTO scheduled_sessions (host_id, room_code, title, description, scheduled_at)
       VALUES ($1, $2, $3, $4, $5) RETURNING *`,
      [req.user.id, roomCode, title, description || '', scheduledAt]
    );

    const scheduledSession = sessResult.rows[0];

    const hostRes = await pool.query('SELECT name FROM users WHERE id = $1', [req.user.id]);
    const hostName = hostRes.rows[0]?.name || 'Trener';

    if (Array.isArray(friendIds) && friendIds.length > 0) {
      const formattedDate = new Date(scheduledAt).toLocaleString();
      for (const friendId of friendIds) {
        await pool.query(
          `INSERT INTO scheduled_session_invites (session_id, user_id, status) VALUES ($1, $2, 'pending')`,
          [scheduledSession.id, friendId]
        );

        await pool.query(
          `INSERT INTO user_notifications (user_id, sender_id, room_code, title, message)
           VALUES ($1, $2, $3, $4, $5)`,
          [
            friendId,
            req.user.id,
            roomCode,
            'Zakazana šahovska sesija',
            `Korisnik ${hostName} je zakazao sesiju "${title}" za ${formattedDate}. Soba: ${roomCode}.`
          ]
        );

        const onlineUser = onlineUsers[friendId];
        if (onlineUser && onlineUser.socketId) {
          io.to(onlineUser.socketId).emit('session_invite_received', {
            senderName: hostName,
            roomCode,
            message: `Korisnik ${hostName} je zakazao sesiju "${title}" za ${formattedDate}!`,
          });
        }
      }
    }

    const calendarUrl = generateGoogleCalendarUrl(title, description, roomCode, scheduledAt);

    res.status(201).json({
      message: 'Sesija je uspešno zakazana i sačuvana u bazi!',
      session: scheduledSession,
      calendarUrl,
    });
  } catch (err) {
    console.error('Error scheduling session:', err);
    res.status(500).json({ error: 'Greška pri zakazivanju sesije.' });
  }
});

app.get('/sessions/scheduled', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT ss.*, u.name as host_name,
         COALESCE(ssi.status, 'host') as my_status
       FROM scheduled_sessions ss
       JOIN users u ON ss.host_id = u.id
       LEFT JOIN scheduled_session_invites ssi ON ssi.session_id = ss.id AND ssi.user_id = $1
       WHERE ss.host_id = $1 OR ssi.user_id = $1
       ORDER BY ss.scheduled_at ASC`,
      [req.user.id]
    );

    const sessionsWithCal = result.rows.map((s) => ({
      ...s,
      calendarUrl: generateGoogleCalendarUrl(s.title, s.description, s.room_code, s.scheduled_at),
    }));

    res.json(sessionsWithCal);
  } catch (err) {
    console.error('Error fetching scheduled sessions:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju zakazanih sesija.' });
  }
});

// PUZZLES & AI COACH ENDPOINTS

// GET /api/puzzles/next - Fetch next adaptive puzzle matching user rating
app.get('/api/puzzles/next', authenticateToken, async (req, res) => {
  const { theme } = req.query;
  const userId = req.user.id;

  try {
    let userRatingRes = await pool.query(
      'SELECT overall_rating, theme_ratings FROM user_puzzle_ratings WHERE user_id = $1',
      [userId]
    );

    let userRating = 1500;
    let themeRatings = {};
    if (userRatingRes.rows.length === 0) {
      await pool.query(
        'INSERT INTO user_puzzle_ratings (user_id, overall_rating) VALUES ($1, 1500) ON CONFLICT DO NOTHING',
        [userId]
      );
    } else {
      userRating = userRatingRes.rows[0].overall_rating || 1500;
      themeRatings = userRatingRes.rows[0].theme_ratings || {};
    }

    const minRating = Math.max(800, userRating - 250);
    const maxRating = userRating + 250;

    let puzzleRes;
    if (theme && theme.trim() !== '') {
      puzzleRes = await pool.query(
        `SELECT * FROM puzzles
         WHERE rating BETWEEN $1 AND $2 AND $3 = ANY(themes)
         ORDER BY RANDOM() LIMIT 1`,
        [minRating, maxRating, theme.trim()]
      );
      if (puzzleRes.rows.length === 0) {
        puzzleRes = await pool.query(
          `SELECT * FROM puzzles WHERE $1 = ANY(themes) ORDER BY ABS(rating - $2) LIMIT 1`,
          [theme.trim(), userRating]
        );
      }
    } else {
      puzzleRes = await pool.query(
        `SELECT * FROM puzzles
         WHERE rating BETWEEN $1 AND $2
         ORDER BY RANDOM() LIMIT 1`,
        [minRating, maxRating]
      );
    }

    if (puzzleRes.rows.length === 0) {
      puzzleRes = await pool.query('SELECT * FROM puzzles ORDER BY RANDOM() LIMIT 1');
    }

    if (puzzleRes.rows.length === 0) {
      return res.status(404).json({ error: 'Nema dostupnih zagonetki u bazi.' });
    }

    const puzzle = puzzleRes.rows[0];
    res.json({
      puzzle: {
        puzzle_id: puzzle.puzzle_id,
        fen: puzzle.fen,
        moves: puzzle.moves.split(' '),
        rating: puzzle.rating,
        themes: puzzle.themes,
        game_url: puzzle.game_url,
        opening_tags: puzzle.opening_tags
      },
      userRating,
      themeRatings
    });
  } catch (err) {
    console.error('Error fetching next puzzle:', err);
    res.status(500).json({ error: 'Greška pri dobavljanju zagonetke.' });
  }
});

// POST /api/puzzles/submit - Submit puzzle result & update Elo rating
app.post('/api/puzzles/submit', authenticateToken, async (req, res) => {
  const { puzzleId, solved, theme } = req.body;
  const userId = req.user.id;

  try {
    const puzzleRes = await pool.query('SELECT rating FROM puzzles WHERE puzzle_id = $1', [puzzleId]);
    const puzzleRating = puzzleRes.rows[0]?.rating || 1500;

    const userRes = await pool.query(
      'SELECT overall_rating, theme_ratings, puzzles_solved, puzzles_failed FROM user_puzzle_ratings WHERE user_id = $1',
      [userId]
    );

    let currentRating = userRes.rows[0]?.overall_rating || 1500;
    let themeRatings = userRes.rows[0]?.theme_ratings || {};
    let solvedCount = userRes.rows[0]?.puzzles_solved || 0;
    let failedCount = userRes.rows[0]?.puzzles_failed || 0;

    const K = 32;
    const expected = 1 / (1 + Math.pow(10, (puzzleRating - currentRating) / 400));
    const actual = solved ? 1 : 0;
    const ratingChange = Math.round(K * (actual - expected));
    const newRating = Math.max(800, currentRating + ratingChange);

    if (solved) {
      solvedCount++;
    } else {
      failedCount++;
    }

    if (theme) {
      const currentThemeRating = themeRatings[theme] || currentRating;
      const themeExpected = 1 / (1 + Math.pow(10, (puzzleRating - currentThemeRating) / 400));
      const themeChange = Math.round(K * (actual - themeExpected));
      themeRatings[theme] = Math.max(800, currentThemeRating + themeChange);
    }

    await pool.query(
      `INSERT INTO user_puzzle_ratings (user_id, overall_rating, theme_ratings, puzzles_solved, puzzles_failed, updated_at)
       VALUES ($1, $2, $3, $4, $5, CURRENT_TIMESTAMP)
       ON CONFLICT (user_id) DO UPDATE SET
         overall_rating = EXCLUDED.overall_rating,
         theme_ratings = EXCLUDED.theme_ratings,
         puzzles_solved = EXCLUDED.puzzles_solved,
         puzzles_failed = EXCLUDED.puzzles_failed,
         updated_at = CURRENT_TIMESTAMP`,
      [userId, newRating, JSON.stringify(themeRatings), solvedCount, failedCount]
    );

    res.json({
      solved,
      ratingChange,
      newRating,
      themeRatings,
      puzzlesSolved: solvedCount,
      puzzlesFailed: failedCount
    });
  } catch (err) {
    console.error('Error submitting puzzle result:', err);
    res.status(500).json({ error: 'Greška pri obradi rezultata zagonetke.' });
  }
});

// POST /api/ai/explain-position - AI Chess Coach powered by Gemini SDK (@google/genai)
app.post('/api/ai/explain-position', authenticateToken, async (req, res) => {
  const { fen, evals, userLanguage } = req.body;
  if (!fen) {
    return res.status(400).json({ error: 'FEN kod je obavezan parametar.' });
  }

  try {
    const explanation = await geminiService.explainPosition({
      fen,
      evals: evals || {},
      userLanguage: userLanguage || 'sr'
    });

    res.json(explanation);
  } catch (err) {
    console.error('Error in AI position explanation route:', err);
    res.status(500).json({ error: 'Greška pri generisanju AI objašnjenja.' });
  }
});

// SOCKET.IO REALTIME EVENTS

const roomAudioUsers = {}; // roomId -> { userId -> { socketId, userId, userName, role, isMuted, handRaised } }
const onlineUsers = {}; // userId -> { socketId, name, email, role }
const activeRoomMembers = {}; // roomId -> { userId -> { name, role } }

io.on('connection', (socket) => {
  console.log(`User connected: ${socket.id}`);

  // Register online user presence
  socket.on('register_user', ({ userId, name, email, role }) => {
    socket.userId = userId;
    socket.userName = name;
    socket.userEmail = email;
    socket.userRole = role;

    onlineUsers[userId] = {
      socketId: socket.id,
      userId,
      name,
      email,
      role
    };
    console.log(`User registered online: ${name} (${userId})`);
    io.emit('user_presence_changed', { userId, status: 'online' });
  });

  // Send in-app invite
  socket.on('send_lesson_invite', ({ studentId, roomCode }) => {
    const student = onlineUsers[studentId];
    if (student) {
      console.log(`Sending lesson invite for room ${roomCode} from trainer ${socket.userName} to student ${student.name}`);
      io.to(student.socketId).emit('lesson_invite', {
        roomCode,
        trainerName: socket.userName || 'Trener'
      });
    }
  });

  // When a player wants to join a game room
  socket.on('joinGame', async ({ roomId, playerColor, userId, userName, role }) => {
    socket.join(roomId);
    console.log(`Player ${socket.id} joined room: ${roomId} as ${playerColor}`);

    if (userId && userName && role) {
      if (!activeRoomMembers[roomId]) {
        activeRoomMembers[roomId] = {};
      }
      activeRoomMembers[roomId][userId] = { userId, name: userName, role };
      socket.currentRoomId = roomId;
      socket.currentUserId = userId;
      io.to(roomId).emit('room_members_list', Object.values(activeRoomMembers[roomId]));
    }

    try {
      // Fetch current room state (FEN & boardControl) from DB
      const result = await pool.query('SELECT current_fen, board_control, allow_student_engine FROM rooms WHERE room_code = $1', [roomId]);
      if (result.rows.length > 0) {
        socket.emit('gameState', {
          currentFen: result.rows[0].current_fen,
          boardControl: result.rows[0].board_control,
          allowStudentEngine: result.rows[0].allow_student_engine
        });
      }
    } catch (err) {
      console.error('Socket joinGame DB error:', err);
    }
  });

  // Host / Trainer changes participant role in room (promote to trainer / revert to student)
  socket.on('change_user_role', ({ roomId, targetUserId, newRole }) => {
    console.log(`Changing role for user ${targetUserId} in room ${roomId} to ${newRole}`);
    if (activeRoomMembers[roomId] && activeRoomMembers[roomId][targetUserId]) {
      activeRoomMembers[roomId][targetUserId].role = newRole;
      io.to(roomId).emit('room_members_list', Object.values(activeRoomMembers[roomId]));
      io.to(roomId).emit('user_role_changed', { targetUserId, newRole });
    }
  });

  // Trainer changes student permissions
  socket.on('change_permissions', async ({ roomId, boardControl }) => {
    console.log(`Updating permissions for room ${roomId} to ${boardControl}`);
    try {
      await pool.query('UPDATE rooms SET board_control = $1 WHERE room_code = $2', [boardControl, roomId]);
      io.to(roomId).emit('permissions_updated', { boardControl });
    } catch (err) {
      console.error('Socket change_permissions DB error:', err);
    }
  });

  // Trainer changes student engine permissions
  socket.on('change_engine_permission', async ({ roomId, allowStudentEngine }) => {
    console.log(`Updating engine permission for room ${roomId} to ${allowStudentEngine}`);
    try {
      await pool.query('UPDATE rooms SET allow_student_engine = $1 WHERE room_code = $2', [allowStudentEngine, roomId]);
      io.to(roomId).emit('engine_permission_updated', { allowStudentEngine });
    } catch (err) {
      console.error('Socket change_engine_permission DB error:', err);
    }
  });

  // Trainer forces board flip for student(s)
  socket.on('force_flip_board', ({ roomId, orientation }) => {
    console.log(`Forcing board flip for students in room ${roomId} to ${orientation}`);
    // Emit only to other players in the room (the students)
    socket.to(roomId).emit('flip_board_forced', { orientation });
  });

  // When a player makes a move
  socket.on('move', async ({ roomId, move, currentFen, role, currentMoveIndex, movePath }) => {
    console.log(`Move request in room ${roomId} by role ${role}:`, move);
    try {
      // Fetch room state
      const roomResult = await pool.query('SELECT current_fen, board_control FROM rooms WHERE room_code = $1', [roomId]);
      if (roomResult.rows.length === 0) return;

      const oldFen = roomResult.rows[0].current_fen;
      const boardControl = roomResult.rows[0].board_control;

      // Validate student moves
      if (role === 'ucenik') {
        if (move === null) {
          // Reset board request
          if (boardControl !== 'student_both') {
            console.log(`Reset rejected for student in room ${roomId}`);
            socket.emit('gameState', { currentFen: oldFen, boardControl });
            return;
          }
        } else {
          // Normal move request
          if (boardControl === 'trainer_only') {
            console.log(`Move rejected (trainer_only) for student in room ${roomId}`);
            socket.emit('gameState', { currentFen: oldFen, boardControl });
            return;
          }

          const pieceColor = getPieceColorAt(oldFen, move.from);
          if (boardControl === 'student_white' && pieceColor !== 'white') {
            console.log(`Move rejected (student_white, but moved ${pieceColor}) in room ${roomId}`);
            socket.emit('gameState', { currentFen: oldFen, boardControl });
            return;
          }

          if (boardControl === 'student_black' && pieceColor !== 'black') {
            console.log(`Move rejected (student_black, but moved ${pieceColor}) in room ${roomId}`);
            socket.emit('gameState', { currentFen: oldFen, boardControl });
            return;
          }
        }
      }

      // If allowed (or Trainer), update DB and broadcast to room
      await pool.query('UPDATE rooms SET current_fen = $1 WHERE room_code = $2', [currentFen, roomId]);
      socket.to(roomId).emit('moveMade', { move, currentFen, currentMoveIndex, movePath });
    } catch (err) {
      console.error('Socket move DB error:', err);
    }
  });

  // Trainer loads a PGN game
  socket.on('pgn_loaded', ({ roomId, pgn }) => {
    console.log(`PGN loaded in room ${roomId}`);
    socket.to(roomId).emit('pgn_loaded', { pgn });
  });

  // AGORA AUDIO CLASSROOM SOCKET EVENTS
  socket.on('audio_join', ({ roomId, userId, userName, role, isMuted }) => {
    console.log(`Audio join in room ${roomId} by user ${userName} (${userId})`);
    if (!roomAudioUsers[roomId]) {
      roomAudioUsers[roomId] = {};
    }
    roomAudioUsers[roomId][userId] = {
      socketId: socket.id,
      userId,
      userName,
      role,
      isMuted: isMuted || false,
      handRaised: false
    };
    socket.audioRoomId = roomId;
    socket.audioUserId = userId;

    io.to(roomId).emit('audio_users_list', Object.values(roomAudioUsers[roomId]));
  });

  socket.on('audio_leave', ({ roomId, userId }) => {
    console.log(`Audio leave in room ${roomId} by user ID ${userId}`);
    if (roomAudioUsers[roomId] && roomAudioUsers[roomId][userId]) {
      delete roomAudioUsers[roomId][userId];
      if (Object.keys(roomAudioUsers[roomId]).length === 0) {
        delete roomAudioUsers[roomId];
      } else {
        io.to(roomId).emit('audio_users_list', Object.values(roomAudioUsers[roomId]));
      }
    }
    socket.audioRoomId = null;
    socket.audioUserId = null;
  });

  socket.on('audio_mute_toggle', ({ roomId, userId, isMuted }) => {
    if (roomAudioUsers[roomId] && roomAudioUsers[roomId][userId]) {
      roomAudioUsers[roomId][userId].isMuted = isMuted;
      io.to(roomId).emit('audio_users_list', Object.values(roomAudioUsers[roomId]));
    }
  });

  socket.on('audio_mute_all_students', ({ roomId }) => {
    console.log(`Muting all students in room ${roomId}`);
    if (roomAudioUsers[roomId]) {
      Object.keys(roomAudioUsers[roomId]).forEach(uId => {
        if (roomAudioUsers[roomId][uId].role === 'ucenik') {
          roomAudioUsers[roomId][uId].isMuted = true;
        }
      });
      io.to(roomId).emit('audio_users_list', Object.values(roomAudioUsers[roomId]));
      socket.to(roomId).emit('audio_force_mute_student', { targetUserId: 'all' });
    }
  });

  socket.on('audio_mute_student', ({ roomId, targetUserId }) => {
    console.log(`Muting student ${targetUserId} in room ${roomId}`);
    if (roomAudioUsers[roomId] && roomAudioUsers[roomId][targetUserId]) {
      roomAudioUsers[roomId][targetUserId].isMuted = true;
      io.to(roomId).emit('audio_users_list', Object.values(roomAudioUsers[roomId]));
      io.to(roomId).emit('audio_force_mute_student', { targetUserId });
    }
  });

  socket.on('audio_raise_hand', ({ roomId, userId }) => {
    console.log(`User ${userId} raised hand in room ${roomId}`);
    if (roomAudioUsers[roomId] && roomAudioUsers[roomId][userId]) {
      roomAudioUsers[roomId][userId].handRaised = true;
      io.to(roomId).emit('audio_users_list', Object.values(roomAudioUsers[roomId]));
      io.to(roomId).emit('audio_hand_raised_alert', { userId, userName: roomAudioUsers[roomId][userId].userName });
    }
  });

  socket.on('audio_allow_speech', ({ roomId, targetUserId }) => {
    console.log(`Allowing speech for user ${targetUserId} in room ${roomId}`);
    if (roomAudioUsers[roomId] && roomAudioUsers[roomId][targetUserId]) {
      roomAudioUsers[roomId][targetUserId].handRaised = false;
      roomAudioUsers[roomId][targetUserId].isMuted = false;
      io.to(roomId).emit('audio_users_list', Object.values(roomAudioUsers[roomId]));
      io.to(roomId).emit('audio_force_unmute_student', { targetUserId });
    }
  });

  socket.on('leaveGame', ({ roomId, userId }) => {
    console.log(`User ${userId} explicitly left room ${roomId}`);
    if (roomId && userId && activeRoomMembers[roomId]) {
      delete activeRoomMembers[roomId][userId];
      if (Object.keys(activeRoomMembers[roomId]).length === 0) {
        delete activeRoomMembers[roomId];
      } else {
        io.to(roomId).emit('room_members_list', Object.values(activeRoomMembers[roomId]));
      }
    }
  });

  socket.on('student_shares_position', ({ roomId, studentId, studentName, title, fen, pgn }) => {
    console.log(`Student ${studentName} (${studentId}) shared position "${title}" in room ${roomId}`);
    io.to(roomId).emit('student_position_shared', {
      studentId,
      studentName,
      title,
      fen,
      pgn
    });
  });

  socket.on('disconnect', () => {
    console.log(`User disconnected: ${socket.id}`);
    
    // Clean up online user presence
    if (socket.userId) {
      delete onlineUsers[socket.userId];
      io.emit('user_presence_changed', { userId: socket.userId, status: 'offline' });
      console.log(`User went offline: ${socket.userName} (${socket.userId})`);
    }

    // Clean up classroom active room memberships
    const roomId = socket.currentRoomId;
    const userId = socket.currentUserId;
    if (roomId && userId && activeRoomMembers[roomId]) {
      delete activeRoomMembers[roomId][userId];
      if (Object.keys(activeRoomMembers[roomId]).length === 0) {
        delete activeRoomMembers[roomId];
      } else {
        io.to(roomId).emit('room_members_list', Object.values(activeRoomMembers[roomId]));
      }
    }

    // Clean up audio connections
    if (socket.audioRoomId && socket.audioUserId) {
      const rId = socket.audioRoomId;
      const uId = socket.audioUserId;
      if (roomAudioUsers[rId]) {
        delete roomAudioUsers[rId][uId];
        if (Object.keys(roomAudioUsers[rId]).length === 0) {
          delete roomAudioUsers[rId];
        } else {
          io.to(rId).emit('audio_users_list', Object.values(roomAudioUsers[rId]));
        }
      }
    }
  });
});

// Start Database and Server
async function startServer() {
  try {
    await initDB();
    server.listen(PORT, () => {
      console.log(`Server is listening on port ${PORT}`);
    });
  } catch (err) {
    console.error('Failed to start server due to DB initialization failure:', err);
    process.exit(1);
  }
}

startServer();
