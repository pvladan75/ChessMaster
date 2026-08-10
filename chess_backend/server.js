require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const { Chess } = require('chess.js');
const fs = require('fs');
const path = require('path');
const { pool, initDB } = require('./db');

const authRoutes = require('./routes/auth');
const roomRoutes = require('./routes/rooms');
const lessonRoutes = require('./routes/lessons');
const recordingRoutes = require('./routes/recordings');
const puzzleRoutes = require('./routes/puzzles');
const socialRoutes = require('./routes/social');
const { authenticateToken, requireRole } = require('./middleware/auth');

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

// Middleware for parsing JSON & Urlencoded with large limit for audio recordings
app.use(express.json({ limit: '100mb' }));
app.use(express.urlencoded({ limit: '100mb', extended: true }));

// Serve static uploads
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// CORS headers middleware
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, DELETE');
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  next();
});

// Basic health check endpoint
app.get('/', (req, res) => {
  res.json({ status: 'ok', message: 'Chess Master backend is running' });
});

// ADMIN ROUTE - RESET ALL USERS & DATA
app.post('/admin/reset-all-users', async (req, res) => {
  try {
    await pool.query('TRUNCATE users RESTART IDENTITY CASCADE;');
    res.json({ message: 'Svi nalozi i povezani podaci su uspešno izbrisani iz baze.' });
  } catch (err) {
    console.error('Error resetting DB:', err);
    res.status(500).json({ error: 'Greška pri brisanju podataka.' });
  }
});

// MOUNT ROUTE MODULES
app.use('/', authRoutes);
app.use('/rooms', roomRoutes);
app.use('/lessons', lessonRoutes);
app.use('/recordings', recordingRoutes);
app.use('/api', puzzleRoutes);
app.use('/', socialRoutes);

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

    console.log(`[ONLINE PRESENCE] User registered: ${name} (ID: ${userId})`);
  });

  socket.on('send_lesson_invite', ({ studentId, roomCode }) => {
    console.log(`[REALTIME INVITE] Sender: ${socket.userName} -> Student ID: ${studentId} | Room: ${roomCode}`);
    const recipient = onlineUsers[studentId];
    if (recipient) {
      io.to(recipient.socketId).emit('lesson_invite_received', {
        senderId: socket.userId,
        senderName: socket.userName || 'Trener',
        roomCode
      });
    }
  });

  socket.on('joinGame', async ({ roomId, playerColor, userId, userName, role }) => {
    socket.join(roomId);
    socket.roomId = roomId;
    socket.userId = userId || socket.id;
    socket.userName = userName || 'Gost';
    socket.userRole = role || 'ucenik';

    if (!activeRoomMembers[roomId]) {
      activeRoomMembers[roomId] = {};
    }
    activeRoomMembers[roomId][socket.userId] = {
      userId: socket.userId,
      name: socket.userName,
      role: socket.userRole,
      socketId: socket.id
    };

    console.log(`User ${socket.userName} (${socket.userId}) joined room: ${roomId} as ${socket.userRole}`);

    io.to(roomId).emit('room_members_list', Object.values(activeRoomMembers[roomId]));

    try {
      const roomRes = await pool.query('SELECT * FROM rooms WHERE room_code = $1', [roomId]);
      if (roomRes.rows.length > 0) {
        const room = roomRes.rows[0];
        socket.emit('permissions_updated', {
          boardControl: room.board_control || 'host_only',
          allowStudentEngine: room.allow_student_engine || false
        });
      }
    } catch (e) {
      console.error('Error fetching room permissions:', e);
    }
  });

  socket.on('change_user_role', ({ roomId, targetUserId, newRole }) => {
    if (activeRoomMembers[roomId] && activeRoomMembers[roomId][targetUserId]) {
      activeRoomMembers[roomId][targetUserId].role = newRole;
      io.to(roomId).emit('room_members_list', Object.values(activeRoomMembers[roomId]));
      const targetMember = activeRoomMembers[roomId][targetUserId];
      if (targetMember && targetMember.socketId) {
        io.to(targetMember.socketId).emit('role_changed', { newRole });
      }
    }
  });

  socket.on('change_permissions', async ({ roomId, boardControl }) => {
    try {
      await pool.query('UPDATE rooms SET board_control = $1 WHERE room_code = $2', [boardControl, roomId]);
      io.to(roomId).emit('permissions_updated', { boardControl });
      console.log(`[PERMISSIONS] Room ${roomId} boardControl updated to ${boardControl}`);
    } catch (e) {
      console.error('Error updating permissions:', e);
    }
  });

  socket.on('recording_status_update', ({ roomId, status, recordingStartTimeMs, fen, paused }) => {
    socket.to(roomId).emit('recording_status_changed', {
      status,
      recordingStartTimeMs,
      fen,
      paused: !!paused
    });
    console.log(`[RECORDING STATUS] Room ${roomId} -> status: ${status}, paused: ${paused}`);
  });

  socket.on('change_engine_permission', async ({ roomId, allowStudentEngine }) => {
    try {
      await pool.query('UPDATE rooms SET allow_student_engine = $1 WHERE room_code = $2', [allowStudentEngine, roomId]);
      io.to(roomId).emit('engine_permission_updated', { allowStudentEngine });
      console.log(`[PERMISSIONS] Room ${roomId} allowStudentEngine updated to ${allowStudentEngine}`);
    } catch (e) {
      console.error('Error updating engine permission:', e);
    }
  });

  socket.on('force_flip_board', ({ roomId, orientation }) => {
    socket.to(roomId).emit('board_flipped', { orientation });
    console.log(`[FORCE FLIP] Room ${roomId} -> orientation: ${orientation}`);
  });

  socket.on('toggle_blunder_alert', ({ roomId, enabled }) => {
    socket.to(roomId).emit('blunder_alert_toggled', { enabled });
    console.log(`[BLUNDER ALERT] Room ${roomId} -> enabled: ${enabled}`);
  });

  socket.on('move', async ({ roomId, move, currentFen, role, currentMoveIndex, movePath }) => {
    socket.to(roomId).emit('move', { move, currentFen, role, currentMoveIndex, movePath });
    try {
      await pool.query('UPDATE rooms SET current_fen = $1 WHERE room_code = $2', [currentFen, roomId]);
    } catch (err) {
      console.error('Error updating room FEN:', err);
    }
  });

  socket.on('pgn_loaded', ({ roomId, pgn }) => {
    socket.to(roomId).emit('pgn_loaded', { pgn });
  });

  socket.on('audio_join', ({ roomId, userId, userName, role, isMuted }) => {
    socket.join(roomId);
    socket.audioRoomId = roomId;
    socket.audioUserId = userId;

    if (!roomAudioUsers[roomId]) {
      roomAudioUsers[roomId] = {};
    }

    roomAudioUsers[roomId][userId] = {
      socketId: socket.id,
      userId,
      userName: userName || 'Korisnik',
      role: role || 'ucenik',
      isMuted: isMuted !== undefined ? isMuted : false,
      handRaised: false
    };

    io.to(roomId).emit('audio_users_list', Object.values(roomAudioUsers[roomId]));
    console.log(`[AUDIO] User ${userName} (${userId}) joined audio in room ${roomId}`);
  });

  socket.on('audio_leave', ({ roomId, userId }) => {
    if (roomAudioUsers[roomId] && roomAudioUsers[roomId][userId]) {
      delete roomAudioUsers[roomId][userId];
      if (Object.keys(roomAudioUsers[roomId]).length === 0) {
        delete roomAudioUsers[roomId];
      } else {
        io.to(roomId).emit('audio_users_list', Object.values(roomAudioUsers[roomId]));
      }
    }
    socket.leave(roomId);
    console.log(`[AUDIO] User ${userId} left audio in room ${roomId}`);
  });

  socket.on('audio_mute_toggle', ({ roomId, userId, isMuted }) => {
    if (roomAudioUsers[roomId] && roomAudioUsers[roomId][userId]) {
      roomAudioUsers[roomId][userId].isMuted = isMuted;
      io.to(roomId).emit('audio_users_list', Object.values(roomAudioUsers[roomId]));
    }
  });

  socket.on('audio_mute_all_students', ({ roomId }) => {
    if (roomAudioUsers[roomId]) {
      Object.keys(roomAudioUsers[roomId]).forEach(uId => {
        if (roomAudioUsers[roomId][uId].role !== 'host' && roomAudioUsers[roomId][uId].role !== 'trener') {
          roomAudioUsers[roomId][uId].isMuted = true;
        }
      });
      io.to(roomId).emit('audio_users_list', Object.values(roomAudioUsers[roomId]));
      io.to(roomId).emit('audio_force_muted_all');
    }
  });

  socket.on('audio_hand_raise_toggle', ({ roomId, userId, handRaised }) => {
    if (roomAudioUsers[roomId] && roomAudioUsers[roomId][userId]) {
      roomAudioUsers[roomId][userId].handRaised = handRaised;
      io.to(roomId).emit('audio_users_list', Object.values(roomAudioUsers[roomId]));
    }
  });

  socket.on('audio_speaker_active', ({ roomId, userId, isSpeaking }) => {
    socket.to(roomId).emit('audio_speaker_active', { userId, isSpeaking });
  });

  socket.on('disconnect', () => {
    console.log(`User disconnected: ${socket.id}`);

    if (socket.userId && onlineUsers[socket.userId]) {
      delete onlineUsers[socket.userId];
      console.log(`[ONLINE PRESENCE] User disconnected: ID ${socket.userId}`);
    }

    if (socket.roomId && socket.userId && activeRoomMembers[socket.roomId]) {
      delete activeRoomMembers[socket.roomId][socket.userId];
      if (Object.keys(activeRoomMembers[socket.roomId]).length === 0) {
        delete activeRoomMembers[socket.roomId];
      } else {
        io.to(socket.roomId).emit('room_members_list', Object.values(activeRoomMembers[socket.roomId]));
      }
    }

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
