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
const groupRoutes = require('./routes/groups');
const accountRoutes = require('./routes/account');
const consentRoutes = require('./routes/consent');
const trainerPanelRoutes = require('./routes/trainerPanel');
const userGamesRoutes = require('./routes/userGames');
const mistakeDrillRoutes = require('./routes/mistakeDrill');
const { authenticateToken, requireRole, authenticateSocket } = require('./middleware/auth');
const entitlementService = require('./services/entitlementService');
const realtime = require('./services/realtime');
const { mayJoinRoom, maySpeakInRoom } = require('./services/roomAccess');
const { mayRecordRoom } = require('./services/recordingConsent');
const { cleanupOldExports } = require('./services/retentionService');
const { corsVerdict, parseAllowedOrigins } = require('./services/corsPolicy');

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
const ALLOWED_ORIGINS = parseAllowedOrigins(process.env.ALLOWED_ORIGINS);

/// Kept for the socket handshake, which only needs a yes or no.
///
/// It has no request to look at, so it cannot recognise our own page — and it
/// does not have to: the consent page opens no socket.
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
  // `same-origin` is the answer that was missing until 25.8.2026: the parent's
  // consent page is served by this server and posts back to it, so its form
  // carried an Origin that was not on the list and was refused. The page opened
  // (navigation sends no Origin) and only the button failed.
  const verdict = corsVerdict(origin, req.headers.host, ALLOWED_ORIGINS);
  if (verdict === 'allowed') {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Vary', 'Origin');
    res.setHeader('Access-Control-Allow-Credentials', 'true');
  } else if (verdict === 'blocked') {
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
  res.json({ status: 'ok', message: 'backend is running', timestamp: new Date().toISOString() });
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
app.use('/games/mistakes', mistakeDrillRoutes);
app.use('/games', userGamesRoutes);
app.use('/groups', groupRoutes);
app.use('/', accountRoutes);
// The parent's page. Mounted at the root and deliberately unauthenticated:
// the person it is for has no account here, and the link is the whole lock.
app.use('/', consentRoutes);
app.use('/', trainerPanelRoutes);
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
io.use(async (socket, next) => {
  const token = socket.handshake.auth?.token || socket.handshake.query?.token;
  try {
    socket.data.user = await authenticateSocket(token);
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

/// Tells the room whether it may be recorded right now, and why not.
///
/// Emitted whenever the roster changes rather than asked for: the answer
/// depends entirely on who is in the room, so the moment it can change is the
/// moment the roster does. That is also what lets the app draw a disabled
/// record button with the reason on it instead of a button that fails when
/// pressed — a control that looks available and is not is the same surprise as
/// one that works while its button is hidden.
///
/// A hint, not the lock. The lock is in `recording_status_update`, because a
/// client that never asks is exactly the case a rule about children has to
/// survive.
async function emitRecordingConsent(roomId) {
  try {
    const verdict = await mayRecordRoom(pool, {
      roomCode: roomId,
      userIds: Object.keys(activeRoomMembers[roomId] ?? {}),
    });
    io.to(roomId).emit('recording_consent', {
      roomId,
      allowed: verdict.allowed,
      reason: verdict.reason,
      blocked: verdict.blocked,
    });
  } catch (err) {
    // Deliberately not silent, and deliberately not fatal: the button stays as
    // it was and the lock still holds when it is pressed.
    logger.error(`[SNIMANJE] Stanje saglasnosti za sobu ${roomId} nije poslato:`, err);
  }
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
    // The guest list, before the door. This handler used to join first and ask
    // nothing — not a relationship, not an invitation, not even a login — so a
    // guessed six-digit code put a stranger in a live lesson, and in the
    // recording when one was running.
    const seat = await mayJoinRoom(pool, {
      roomCode: roomId,
      userId: authUser ? authUser.id : null,
    });
    if (!seat.allowed) {
      logger.warn(
        `[SOBA] Odbijen ulazak u ${roomId}: ${seat.reason} (korisnik ${authUser ? authUser.id : 'gost'})`
      );
      // Said out loud rather than left as a socket that never answers: a
      // refusal that reads as "connecting…" forever is the same silent failure
      // this codebase keeps meeting.
      socket.emit('join_refused', { roomId, reason: seat.reason });
      return;
    }

    socket.join(roomId);
    socket.roomId = roomId;
    // Guests get a socket-scoped identity so they can watch without impersonating anyone.
    socket.userId = authUser ? authUser.id : socket.id;
    socket.userName = authUser ? authUser.name : 'Gost';

    if (!activeRoomMembers[roomId]) {
      activeRoomMembers[roomId] = {};
    }

    // The room's creator is the host. Everyone else keeps whatever seat they
    // had, or the one the guest list gave them.
    const previousSeat = activeRoomMembers[roomId][socket.userId];
    socket.userRole = seat.role === 'trener'
      ? 'trener'
      : (previousSeat ? previousSeat.role : seat.role);

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

    // Somebody walked into a lesson that is being recorded. If their parent has
    // not agreed to that, the recording stops — it does not refuse them the
    // lesson. The approved consent text says the class must not be recorded,
    // not that the child must not attend, and shutting a child out of their own
    // lesson over their parent's paperwork would be the wrong half to give up.
    //
    // What was recorded before they arrived is theirs to keep: they were not in
    // it.
    await emitRecordingConsent(roomId);

    if (realtime.noteRecordedParticipant(roomId, socket.userId)) {
      const verdict = await mayRecordRoom(pool, {
        roomCode: roomId,
        userIds: [socket.userId],
      });
      if (!verdict.allowed) {
        logger.warn(`[SNIMANJE] Zaustavljeno u sobi ${roomId}: ${verdict.reason}`);
        // Recorded rather than forgotten. The roster survives without the
        // newcomer — the part already recorded does not contain them — and the
        // save can tell this apart from a server that was restarted and knows
        // nothing, which is the difference the log was lying about.
        realtime.stopRecordingForConsent(roomId, {
          reason: verdict.reason,
          blocked: [socket.userId],
        });
        io.to(roomId).emit('recording_must_stop', {
          roomId,
          reason: verdict.reason,
          blocked: verdict.blocked,
        });
      }
    }

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

    const starting = status === 'started' || status === 'resumed';
    if (starting) {
      const members = Object.keys(activeRoomMembers[roomId] ?? {});

      // Who was here when recording was *attempted*, recorded before the
      // verdict rather than after it.
      //
      // It used to be written only when the attempt succeeded, and that left
      // the second lock holding nothing: a refused start created no roster, so
      // the upload that followed found none and fell into "the check could not
      // run", which lets the save through. A client that ignores
      // `recording_denied` and uploads anyway — which is exactly the client
      // this rule has to survive — walked straight past it.
      if (status === 'started') {
        realtime.beginRecordingRoster(roomId, members);
      } else {
        // Resuming adds to the record rather than replacing it: a pause does
        // not unhear the first half, and a roster restarted here would leave
        // whoever was recorded before the pause out of the check at save time.
        for (const id of members) realtime.noteRecordedParticipant(roomId, id);
      }

      // The lock, as opposed to the request. The app asks before it starts and
      // draws a disabled button, but a client that does not ask is exactly the
      // case a rule about children has to survive — so the answer is decided
      // here, where the server knows who is in the room.
      const verdict = await mayRecordRoom(pool, { roomCode: roomId, userIds: members });
      if (!verdict.allowed) {
        logger.warn(`[SNIMANJE] Odbijeno u sobi ${roomId}: ${verdict.reason}`);
        socket.emit('recording_denied', {
          roomId,
          reason: verdict.reason,
          blocked: verdict.blocked,
        });
        return;
      }
    }

    if (status === 'stopped') {
      // The room answering a stop this server ordered. Kept as a fact, because
      // the alternative is assuming it: a client that ignores
      // `recording_must_stop` never sends this, and its upload is the one the
      // save has to refuse.
      realtime.noteRecordingStopped(roomId);
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

  socket.on('audio_join', async ({ roomId, isMuted }) => {
    // Asked again rather than trusted from the board join: voice is the part
    // that ends up in a recording of children, and two paths into the same room
    // must not be able to drift apart.
    //
    // The same question also answers **who may be heard**, so the roster can say
    // it. The right itself is enforced where it cannot be argued with — the role
    // in the Agora token — and this is the same answer, read once so the screen
    // and the token cannot disagree.
    const seat = await maySpeakInRoom(pool, {
      roomCode: roomId,
      userId: authUser ? authUser.id : null,
    });
    if (!seat.allowed) {
      logger.warn(
        `[AUDIO] Odbijen ulazak u glas ${roomId}: ${seat.reason} (korisnik ${authUser ? authUser.id : 'gost'})`
      );
      socket.emit('join_refused', { roomId, reason: seat.reason });
      return;
    }

    socket.join(roomId);
    const audioUserId = socket.userId || (authUser ? authUser.id : socket.id);
    socket.audioRoomId = roomId;
    socket.audioUserId = audioUserId;
    socket.audioJoinedAt = Date.now();

    if (!roomAudioUsers[roomId]) {
      roomAudioUsers[roomId] = {};
    }

    // Named apart from the `seat` above, which is the access decision for this
    // very join. Two `const seat` in one block is a SyntaxError, and it stopped
    // the whole file from loading — see the test that compiles server.js.
    const member = activeRoomMembers[roomId] && activeRoomMembers[roomId][audioUserId];
    roomAudioUsers[roomId][audioUserId] = {
      socketId: socket.id,
      userId: audioUserId,
      userName: socket.userName || (authUser ? authUser.name : 'Gost'),
      role: member ? member.role : 'ucenik',
      // What the server decided, not what the client says about itself. The mute
      // flag below is the opposite kind of thing — a choice, reported by whoever
      // made it — and the two are kept apart on purpose.
      maySpeak: seat.maySpeak === true,
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

  /// A ready answer from somebody who is listening rather than speaking.
  ///
  /// This is what makes a listening-only seat a lesson instead of a broadcast:
  /// the trainer asks "jasno?" and gets an answer, without a child's voice being
  /// published into the channel — or into the recording.
  ///
  /// Three values and nothing else. Free text would be a message field between a
  /// child and whoever else is in the room, which is the thing this app has
  /// spent two days deciding not to be. The **name comes from the socket**, not
  /// from the message: a sender who names themselves is a sender who can name
  /// somebody else.
  const QUICK_ANSWERS = ['da', 'ne', 'nejasno'];
  socket.on('quick_answer', ({ roomId, answer }) => {
    if (!socket.roomId || socket.roomId !== roomId) {
      return denyPrivileged(socket, 'quick_answer', roomId);
    }
    if (!QUICK_ANSWERS.includes(answer)) {
      logger.warn(`[SOBA] Odbačen nepoznat brzi odgovor u ${roomId}`);
      return;
    }
    io.to(roomId).emit('quick_answer', {
      userId: socket.userId,
      userName: socket.userName || 'Učenik',
      answer,
    });
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
        // A child leaving can make a refused room recordable again, and the
        // button has to notice: a control that stays disabled after the reason
        // is gone is as wrong as one that stays enabled after it appears.
        emitRecordingConsent(socket.roomId);
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
