const logger = require('./services/logger');
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
const agoraRoutes = require('./routes/agora');
const analysisRoutes = require('./routes/analysis');
const billingRoutes = require('./routes/billing');
const assignmentRoutes = require('./routes/assignments');
const reportRoutes = require('./routes/reports');
const reviewRoutes = require('./routes/reviews');
const scanRoutes = require('./routes/scans');
const libraryRoutes = require('./routes/library');
const openingExplorerRoutes = require('./routes/openingExplorer');
const openingJudgeRoutes = require('./routes/openingJudge');
const repertoireRoutes = require('./routes/repertoire');
const { authenticateToken, requireRole, verifySocketToken } = require('./middleware/auth');
const entitlementService = require('./services/entitlementService');
const realtime = require('./services/realtime');
const { cleanupOldExports } = require('./services/retentionService');

const app = express();
const server = http.createServer(app);

// One proxy hop: nginx on the same machine, and nothing in front of it.
//
// Without this every request behind nginx looks like it came from 127.0.0.1,
// which quietly defeats the rate limiters on login and the AI routes — they
// would count all users as one client and lock everyone out together. The value
// is 1 rather than `true` on purpose: trusting the whole chain would let a
// client set its own X-Forwarded-For and pick which bucket it lands in.
app.set('trust proxy', 1);

// Browser origins permitted to call the API, as a comma-separated ALLOWED_ORIGINS list.
// Native Android/Windows clients send no Origin header and are always allowed.
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

function isOriginAllowed(origin) {
  if (!origin) return true; // native client, curl, or same-origin request
  return ALLOWED_ORIGINS.includes(origin);
}

if (ALLOWED_ORIGINS.length === 0) {
  logger.warn('ALLOWED_ORIGINS is empty — browser-based clients will be blocked by CORS. Native clients are unaffected.');
}

// Initialize Socket.io with an explicit origin allowlist
const io = new Server(server, {
  cors: {
    origin: (origin, callback) => callback(null, isOriginAllowed(origin)),
    methods: ["GET", "POST"],
    credentials: true
  }
});

// Before any route is mounted: a route that raised a notification without this
// would have nobody to send it to, and would not say so.
realtime.init(io);

const PORT = process.env.PORT || 3000;

// Recording uploads carry audio, so they get a larger ceiling than the rest of the API.
app.use('/recordings', express.json({ limit: '100mb' }));
app.use(express.json({ limit: '2mb' }));
app.use(express.urlencoded({ limit: '2mb', extended: true }));

// Serve static uploads
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// CORS headers middleware
app.use((req, res, next) => {
  const origin = req.headers.origin;
  if (origin && isOriginAllowed(origin)) {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
    res.setHeader('Access-Control-Allow-Credentials', 'true');
  } else if (origin) {
    logger.warn(`[CORS] Blocked request from disallowed origin: ${origin}`);
    return res.status(403).json({ error: 'Origin not allowed' });
  }
  res.setHeader('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, DELETE');
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  next();
});

// Basic health check endpoints
app.get(['/', '/health', '/api/health'], (req, res) => {
  res.json({ status: 'ok', message: 'Chess Master backend is running', timestamp: new Date().toISOString() });
});

// NOTE: the former POST /admin/reset-all-users route was removed. It ran
// `TRUNCATE users RESTART IDENTITY CASCADE` with no authentication, so any
// unauthenticated caller could wipe every account, room, lesson and recording.
// For local resets use `node clear_users.js` against a development database.

// MOUNT ROUTE MODULES
app.use('/', authRoutes);
app.use('/rooms', roomRoutes);
app.use('/lessons', lessonRoutes);
app.use('/recordings', recordingRoutes);
app.use('/api', puzzleRoutes);
app.use('/agora', agoraRoutes);
app.use('/analysis', analysisRoutes);
app.use('/billing', billingRoutes);
app.use('/assignments', assignmentRoutes);
app.use('/reports', reportRoutes);
app.use('/reviews', reviewRoutes);
app.use('/scans', scanRoutes);
app.use('/library', libraryRoutes);
app.use('/opening-explorer', openingExplorerRoutes);
app.use('/opening-judge', openingJudgeRoutes);
app.use('/repertoire', repertoireRoutes);
app.use('/', socialRoutes);

// SOCKET.IO REALTIME EVENTS

const roomAudioUsers = {}; // roomId -> { userId -> { socketId, userId, userName, role, isMuted, handRaised } }

// Presence lives in services/realtime.js so the HTTP routes can reach a
// connected user too — a notification raised by a route used to sit in the
// database until the recipient restarted the app.
const onlineUsers = realtime.onlineUsers;
const activeRoomMembers = {}; // roomId -> { userId -> { name, role } }

/// Books the voice time a socket has been connected for.
///
/// Agora bills by the minute, so this is the only place the real cost of a
/// lesson becomes visible. Time is measured server-side between audio_join and
/// whichever comes first — audio_leave or the socket dropping — because a client
/// that crashes or loses signal never sends a leave event, and trusting it to
/// report its own usage would undercount exactly the sessions that ran longest.
///
/// Idempotent: clears the start marker so a leave followed by a disconnect books
/// the interval once.
async function flushAudioUsage(socket) {
  const startedAt = socket.audioJoinedAt;
  const userId = socket.userId;
  socket.audioJoinedAt = null;

  if (!startedAt || !Number.isInteger(userId)) return; // guests are not billed to anyone

  const seconds = Math.round((Date.now() - startedAt) / 1000);
  if (seconds <= 0) return;

  await entitlementService.recordUsage(pool, userId, entitlementService.METRIC.AGORA_SECONDS, seconds);
  logger.info(`[AUDIO] Booked ${seconds}s of voice for user ${userId}`);
}

// Reject connections carrying a bad token; allow tokenless guests through read-only.
// socket.data.user is the ONLY trusted identity — client-supplied userId/role in event
// payloads is treated as a hint at best and never as authorization.
io.use((socket, next) => {
  const token = socket.handshake.auth?.token || socket.handshake.query?.token;
  try {
    socket.data.user = verifySocketToken(token);
    next();
  } catch (err) {
    logger.warn(`[SOCKET AUTH] Rejected connection ${socket.id}: ${err.message}`);
    next(new Error('Invalid or expired authentication token'));
  }
});

/// True when this socket's authenticated user created the room.
async function isRoomCreator(roomId, userId) {
  if (!userId) return false;
  try {
    const res = await pool.query('SELECT creator_id FROM rooms WHERE room_code = $1', [roomId]);
    return res.rows.length > 0 && res.rows[0].creator_id === userId;
  } catch (e) {
    logger.error('Error checking room creator:', e);
    return false;
  }
}

/// Guards host-only realtime actions. A socket qualifies if it created the room or
/// currently holds a host/trener seat granted by the creator.
async function canAdministerRoom(socket, roomId) {
  const user = socket.data.user;
  if (!user) return false;
  if (await isRoomCreator(roomId, user.id)) return true;
  const member = activeRoomMembers[roomId] && activeRoomMembers[roomId][user.id];
  return !!member && (member.role === 'host' || member.role === 'trener');
}

function denyPrivileged(socket, event, roomId) {
  logger.warn(
    `[SOCKET AUTHZ] Denied '${event}' on room ${roomId} for ` +
    `${socket.data.user ? `user ${socket.data.user.id}` : 'guest'} (socket ${socket.id})`
  );
  socket.emit('action_denied', { event, reason: 'Nemate ovlašćenje za ovu akciju u ovoj sobi.' });
}

io.on('connection', (socket) => {
  const authUser = socket.data.user;
  logger.info(`User connected: ${socket.id} (${authUser ? `user ${authUser.id}` : 'guest'})`);

  // Register online user presence. Identity comes from the token, not the payload.
  socket.on('register_user', () => {
    if (!authUser) {
      logger.warn(`[ONLINE PRESENCE] Ignoring register_user from unauthenticated socket ${socket.id}`);
      return;
    }

    socket.userId = authUser.id;
    socket.userName = authUser.name;
    socket.userEmail = authUser.email;
    socket.userRole = authUser.role;

    realtime.setOnline(authUser, socket.id);

    logger.info(`[ONLINE PRESENCE] User registered: ${authUser.name} (ID: ${authUser.id})`);
  });

  socket.on('send_lesson_invite', ({ studentId, roomCode }) => {
    if (!authUser) {
      return denyPrivileged(socket, 'send_lesson_invite', roomCode);
    }
    logger.info(`[REALTIME INVITE] Sender: ${authUser.name} -> Student ID: ${studentId} | Room: ${roomCode}`);
    const recipient = onlineUsers[studentId];
    if (recipient) {
      io.to(recipient.socketId).emit('lesson_invite_received', {
        senderId: authUser.id,
        senderName: authUser.name || 'Trener',
        roomCode
      });
    }
  });

  socket.on('joinGame', async ({ roomId, playerColor }) => {
    socket.join(roomId);
    socket.roomId = roomId;
    // Guests get a socket-scoped identity so they can watch without impersonating anyone.
    socket.userId = authUser ? authUser.id : socket.id;
    socket.userName = authUser ? authUser.name : 'Gost';

    if (!activeRoomMembers[roomId]) {
      activeRoomMembers[roomId] = {};
    }

    // The room's creator is the host. Everyone else starts as a student and can only
    // be promoted by someone who already administers the room.
    const previousSeat = activeRoomMembers[roomId][socket.userId];
    const creator = await isRoomCreator(roomId, authUser && authUser.id);
    socket.userRole = creator ? 'trener' : (previousSeat ? previousSeat.role : 'ucenik');

    activeRoomMembers[roomId][socket.userId] = {
      userId: socket.userId,
      name: socket.userName,
      role: socket.userRole,
      socketId: socket.id
    };

    logger.info(`User ${socket.userName} (${socket.userId}) joined room: ${roomId} as ${socket.userRole}`);

    // Tell the joiner its authoritative role, then broadcast the refreshed roster.
    socket.emit('role_changed', { newRole: socket.userRole });
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
      logger.error('Error fetching room permissions:', e);
    }
  });

  socket.on('change_user_role', async ({ roomId, targetUserId, newRole }) => {
    if (!(await canAdministerRoom(socket, roomId))) {
      return denyPrivileged(socket, 'change_user_role', roomId);
    }
    if (!['trener', 'host', 'ucenik'].includes(newRole)) {
      return denyPrivileged(socket, 'change_user_role', roomId);
    }
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
    if (!(await canAdministerRoom(socket, roomId))) {
      return denyPrivileged(socket, 'change_permissions', roomId);
    }
    try {
      await pool.query('UPDATE rooms SET board_control = $1 WHERE room_code = $2', [boardControl, roomId]);
      io.to(roomId).emit('permissions_updated', { boardControl });
      logger.info(`[PERMISSIONS] Room ${roomId} boardControl updated to ${boardControl}`);
    } catch (e) {
      logger.error('Error updating permissions:', e);
    }
  });

  socket.on('recording_status_update', async ({ roomId, status, recordingStartTimeMs, fen, paused }) => {
    if (!(await canAdministerRoom(socket, roomId))) {
      return denyPrivileged(socket, 'recording_status_update', roomId);
    }
    socket.to(roomId).emit('recording_status_changed', {
      status,
      recordingStartTimeMs,
      fen,
      paused: !!paused
    });
    logger.info(`[RECORDING STATUS] Room ${roomId} -> status: ${status}, paused: ${paused}`);
  });

  socket.on('change_engine_permission', async ({ roomId, allowStudentEngine }) => {
    if (!(await canAdministerRoom(socket, roomId))) {
      return denyPrivileged(socket, 'change_engine_permission', roomId);
    }
    try {
      await pool.query('UPDATE rooms SET allow_student_engine = $1 WHERE room_code = $2', [allowStudentEngine, roomId]);
      io.to(roomId).emit('engine_permission_updated', { allowStudentEngine });
      logger.info(`[PERMISSIONS] Room ${roomId} allowStudentEngine updated to ${allowStudentEngine}`);
    } catch (e) {
      logger.error('Error updating engine permission:', e);
    }
  });

  socket.on('force_flip_board', async ({ roomId, orientation }) => {
    if (!(await canAdministerRoom(socket, roomId))) {
      return denyPrivileged(socket, 'force_flip_board', roomId);
    }
    socket.to(roomId).emit('board_flipped', { orientation });
    logger.info(`[FORCE FLIP] Room ${roomId} -> orientation: ${orientation}`);
  });

  socket.on('toggle_blunder_alert', async ({ roomId, enabled }) => {
    if (!(await canAdministerRoom(socket, roomId))) {
      return denyPrivileged(socket, 'toggle_blunder_alert', roomId);
    }
    socket.to(roomId).emit('blunder_alert_toggled', { enabled });
    logger.info(`[BLUNDER ALERT] Room ${roomId} -> enabled: ${enabled}`);
  });

  /// Enforces the room's board_control setting server-side. Rooms that do not exist in
  /// the database (e.g. the local 'STUDIO' board) have no shared state to protect.
  async function canMoveInRoom(roomId) {
    let room;
    try {
      const res = await pool.query('SELECT board_control FROM rooms WHERE room_code = $1', [roomId]);
      room = res.rows[0];
    } catch (err) {
      logger.error('Error checking board control:', err);
      return false;
    }
    if (!room) return true;
    const control = room.board_control || 'host_only';
    if (control !== 'host_only' && control !== 'trainer_only') return true;
    return canAdministerRoom(socket, roomId);
  }

  socket.on('move', async ({ roomId, move, currentFen, role, currentMoveIndex, movePath }) => {
    if (!(await canMoveInRoom(roomId))) {
      return denyPrivileged(socket, 'move', roomId);
    }
    socket.to(roomId).emit('move', { move, currentFen, role, currentMoveIndex, movePath });
    try {
      await pool.query('UPDATE rooms SET current_fen = $1 WHERE room_code = $2', [currentFen, roomId]);
    } catch (err) {
      logger.error('Error updating room FEN:', err);
    }
  });

  socket.on('pgn_loaded', async ({ roomId, pgn }) => {
    if (!(await canMoveInRoom(roomId))) {
      return denyPrivileged(socket, 'pgn_loaded', roomId);
    }
    socket.to(roomId).emit('pgn_loaded', { pgn });
  });

  socket.on('audio_join', ({ roomId, isMuted }) => {
    socket.join(roomId);
    const audioUserId = socket.userId || (authUser ? authUser.id : socket.id);
    socket.audioRoomId = roomId;
    socket.audioUserId = audioUserId;
    socket.audioJoinedAt = Date.now();

    if (!roomAudioUsers[roomId]) {
      roomAudioUsers[roomId] = {};
    }

    const seat = activeRoomMembers[roomId] && activeRoomMembers[roomId][audioUserId];
    roomAudioUsers[roomId][audioUserId] = {
      socketId: socket.id,
      userId: audioUserId,
      userName: socket.userName || (authUser ? authUser.name : 'Gost'),
      role: seat ? seat.role : 'ucenik',
      isMuted: isMuted !== undefined ? isMuted : false,
      handRaised: false
    };

    io.to(roomId).emit('audio_users_list', Object.values(roomAudioUsers[roomId]));
    logger.info(`[AUDIO] User ${roomAudioUsers[roomId][audioUserId].userName} (${audioUserId}) joined audio in room ${roomId}`);
  });

  socket.on('audio_leave', ({ roomId }) => {
    const userId = socket.audioUserId;
    flushAudioUsage(socket);
    if (roomAudioUsers[roomId] && roomAudioUsers[roomId][userId]) {
      delete roomAudioUsers[roomId][userId];
      if (Object.keys(roomAudioUsers[roomId]).length === 0) {
        delete roomAudioUsers[roomId];
      } else {
        io.to(roomId).emit('audio_users_list', Object.values(roomAudioUsers[roomId]));
      }
    }
    socket.leave(roomId);
    logger.info(`[AUDIO] User ${userId} left audio in room ${roomId}`);
  });

  // Users may always mute themselves; muting someone else is a host action.
  socket.on('audio_mute_toggle', async ({ roomId, userId, isMuted }) => {
    const targetId = userId === undefined || userId === null ? socket.audioUserId : userId;
    const isSelf = String(targetId) === String(socket.audioUserId);
    if (!isSelf && !(await canAdministerRoom(socket, roomId))) {
      return denyPrivileged(socket, 'audio_mute_toggle', roomId);
    }
    if (roomAudioUsers[roomId] && roomAudioUsers[roomId][targetId]) {
      roomAudioUsers[roomId][targetId].isMuted = isMuted;
      io.to(roomId).emit('audio_users_list', Object.values(roomAudioUsers[roomId]));
    }
  });

  socket.on('audio_mute_all_students', async ({ roomId }) => {
    if (!(await canAdministerRoom(socket, roomId))) {
      return denyPrivileged(socket, 'audio_mute_all_students', roomId);
    }
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

  // Raising a hand only ever applies to the socket that sent it.
  socket.on('audio_hand_raise_toggle', ({ roomId, handRaised }) => {
    const userId = socket.audioUserId;
    if (roomAudioUsers[roomId] && roomAudioUsers[roomId][userId]) {
      roomAudioUsers[roomId][userId].handRaised = handRaised;
      io.to(roomId).emit('audio_users_list', Object.values(roomAudioUsers[roomId]));
    }
  });

  socket.on('audio_speaker_active', ({ roomId, isSpeaking }) => {
    socket.to(roomId).emit('audio_speaker_active', { userId: socket.audioUserId, isSpeaking });
  });

  socket.on('disconnect', () => {
    logger.info(`User disconnected: ${socket.id}`);

    if (socket.userId && realtime.goOffline(socket.userId)) {
      logger.info(`[ONLINE PRESENCE] User disconnected: ID ${socket.userId}`);
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
      // A dropped connection is the common ending for a lesson, not the rare one.
      flushAudioUsage(socket);
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
      logger.info(`Server is listening on port ${PORT}`);
    });

    // exports/ holds rendered MP4s, which are always reproducible from the
    // recording that made them — unlike uploads/ audio, they are safe to age
    // out automatically before the droplet's disk fills silently.
    const retentionDays = Number(process.env.EXPORT_RETENTION_DAYS) || undefined;
    const runCleanup = () =>
      cleanupOldExports(pool, retentionDays ? { maxAgeDays: retentionDays } : undefined)
        .catch((err) => logger.error(`[RETENTION] Export cleanup failed: ${err.message}`));
    runCleanup();
    setInterval(runCleanup, 24 * 60 * 60 * 1000);
  } catch (err) {
    logger.error('Failed to start server due to DB initialization failure:', err);
    process.exit(1);
  }
}

startServer();
