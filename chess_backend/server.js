require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { pool, initDB } = require('./db');

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
  const { idToken } = req.body;
  if (!idToken) {
    return res.status(400).json({ error: 'idToken is required' });
  }

  try {
    const verifyUrl = `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`;
    const response = await fetch(verifyUrl);
    
    if (!response.ok) {
      return res.status(400).json({ error: 'Invalid Google ID Token' });
    }

    const payload = await response.json();
    const { email, name } = payload;

    if (!email) {
      return res.status(400).json({ error: 'Google account does not provide email' });
    }

    let userResult = await pool.query('SELECT * FROM users WHERE email = $1', [email]);
    let user;

    if (userResult.rows.length === 0) {
      const defaultPasswordHash = 'google_oauth_placeholder_hash';
      const insertResult = await pool.query(
        'INSERT INTO users (email, password_hash, name, role) VALUES ($1, $2, $3, $4) RETURNING id, email, name, role',
        [email, defaultPasswordHash, name || 'Korisnik', 'ucenik']
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
    console.error('Google auth error:', err);
    res.status(500).json({ error: 'Server error during Google authentication' });
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
  const { title, description, tags, fen, pgn } = req.body;

  if (!title || !fen) {
    return res.status(400).json({ error: 'Title and FEN are required' });
  }

  try {
    const result = await pool.query(
      'INSERT INTO saved_lessons (user_id, trainer_id, title, description, tags, fen, pgn) VALUES ($1, $1, $2, $3, $4, $5, $6) RETURNING *',
      [req.user.id, title, description || null, tags || null, fen, pgn || null]
    );
    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error('Save lesson error:', err);
    res.status(500).json({ error: 'Server error while saving lesson' });
  }
});

// GET /lessons/labels (fetch unique labels used by user for autocomplete)
app.get('/lessons/labels', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT DISTINCT unnest(tags) AS label FROM saved_lessons WHERE user_id = $1 OR trainer_id = $1 ORDER BY label ASC',
      [req.user.id]
    );
    const labels = result.rows.map(row => row.label).filter(Boolean);
    res.json(labels);
  } catch (err) {
    console.error('Fetch labels error:', err);
    res.status(500).json({ error: 'Server error while fetching labels' });
  }
});

// GET /lessons (accessible to all authenticated users with advanced logical matrix search)
app.get('/lessons', authenticateToken, async (req, res) => {
  const { search, includeTags, excludeTags, matchMode } = req.query;
  try {
    let query = 'SELECT id, title, description, tags, fen, pgn, created_at FROM saved_lessons WHERE (user_id = $1 OR trainer_id = $1)';
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
