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
const gameTutorialWordsRoutes = require('./routes/gameTutorialWords');
const recordingRoutes = require('./routes/recordings');
const puzzleRoutes = require('./routes/puzzles');
const socialRoutes = require('./routes/social');
const agoraRoutes = require('./routes/agora');
const analysisRoutes = require('./routes/analysis');
const billingRoutes = require('./routes/billing');
const assignmentRoutes = require('./routes/assignments');
const homeworkRoutes = require('./routes/homeworks');
const exerciseRoutes = require('./routes/exercises');
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
const { authenticateToken, requireRole, authenticateSocket, tokenFromHandshake } = require('./middleware/auth');
const entitlementService = require('./services/entitlementService');
const realtime = require('./services/realtime');
const { mayJoinRoom, maySpeakInRoom } = require('./services/roomAccess');
const { registerRoomBoardEvents, boardControlFor } = require('./services/roomBoardEvents');
const { registerRoomVoiceEvents, dropEntry } = require('./services/roomVoiceEvents');
const { cleanupOldExports } = require('./services/retentionService');
const renderJobs = require('./services/renderJobs');
const { refreshStoredReplies } = require('./services/repertoireDrillService');
const { openingJudge } = require('./services/openingJudgeService');
const { createOpponentPrep } = require('./services/opponentPrep');
const { createArchiveImporter } = require('./services/gameArchiveImport');
const { corsVerdict, parseAllowedOrigins } = require('./services/corsPolicy');
const { mountBodyParsers } = require('./middleware/bodyParsers');

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

// One JSON ceiling for every path, read before authentication — see
// middleware/bodyParsers.js for why /recordings no longer has its own.
mountBodyParsers(app);

// Serve static uploads — all of it except the folders named private in
// middleware/uploadsStatic.js. A trainer's recorded narration is read by the
// renderer from disk and is never fetched by URL.
const { serveUploads } = require('./middleware/uploadsStatic');
serveUploads(app, path.join(__dirname, 'uploads'));

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
// `clear_users.js` still exists for a local database, and refuses any other
// one unless it is named with --target=<host> (services/destructiveScriptGuard.js).

// MOUNT ROUTE MODULES
app.use('/', authRoutes);
app.use('/rooms', roomRoutes);
// Before /lessons, whose router would read `from-game` as a lesson id.
app.use('/lessons/from-game', gameTutorialWordsRoutes);
app.use('/lessons', lessonRoutes);
app.use('/recordings', recordingRoutes);
app.use('/api', puzzleRoutes);
app.use('/agora', agoraRoutes);
app.use('/analysis', analysisRoutes);
app.use('/billing', billingRoutes);
app.use('/assignments', assignmentRoutes);
app.use('/homeworks', homeworkRoutes);
app.use('/exercises', exerciseRoutes);
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
const activeRoomMembers = {}; // roomId -> { userId -> { name, role } }

// A session that ends leaves nobody seated and nobody in its voice
// (`realtime.closeRoom`). A roster that outlived its room would keep answering
// „who is here" for a room nobody can enter.
realtime.onRoomClosed((roomId) => {
  delete activeRoomMembers[roomId];
  delete roomAudioUsers[roomId];
});


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
  const token = tokenFromHandshake(socket.handshake);
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

/// Guards the actions that belong to whoever leads the room — and that is its
/// creator, nobody else. A seat used to count as well: the creator could
/// promote somebody to co-host, which is how „who leads" came to have more than
/// one answer (`docs/PLAN-SESIJA.md`, phase 3). Promotion is gone, so the seat
/// has nothing to add to the row in `rooms`.
async function canAdministerRoom(socket, roomId) {
  const user = socket.data.user;
  if (!user) return false;
  return isRoomCreator(roomId, user.id);
}

function denyPrivileged(socket, event, roomId) {
  logger.warn(
    `[SOCKET AUTHZ] Denied '${event}' on room ${roomId} for ` +
    `${socket.data.user ? `user ${socket.data.user.id}` : 'guest'} (socket ${socket.id})`
  );
  socket.emit('action_denied', { event, reason: 'You do not have permission for this action in this room.' });
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

  // Lesson invitations go through `POST /invitations/send`, which checks the
  // relationship and writes the notification before nudging the socket. The
  // socket-only path it replaces checked neither.

  socket.on('joinGame', async ({ roomId } = {}) => {
    // The guest list, before the door. This handler used to join first and ask
    // nothing — not a relationship, not an invitation, not even a login — so a
    // guessed six-digit code put a stranger in a live lesson, and in the
    // recording when rooms were still recorded.
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
    socket.userName = authUser ? authUser.name : 'Guest';

    // Reachable here too, not only at Home: what is sent to a person
    // (`voice_level_changed` above all) has to find them in the room they are
    // sitting in, and their Home socket is often disconnected meanwhile.
    if (authUser) realtime.setOnline(authUser, socket.id);

    if (!activeRoomMembers[roomId]) {
      activeRoomMembers[roomId] = {};
    }

    // The seat is what the guest list says, every time. It used to survive a
    // rejoin, for the sake of a promotion that no longer exists.
    socket.userRole = seat.role;

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
        // No engine permission any more: a student has no engine in the room
        // (docs/PLAN-SESIJA.md, phase 6). `rooms.allow_student_engine` stays
        // in the schema and is read by nobody.
        socket.emit('permissions_updated', {
          boardControl: room.board_control || 'host_only',
        });
        // The position the room is on, for somebody arriving after the first
        // move. `current_fen` was written on every move and read by nothing
        // since 10.8.2026, so a late joiner opened on the starting position. The
        // app applies it only to an empty move tree.
        if (room.current_fen) {
          socket.emit('gameState', { currentFen: room.current_fen });
        }
      }
    } catch (e) {
      logger.error('Error fetching room permissions:', e);
    }
  });

  socket.on('change_permissions', async ({ roomId, boardControl }) => {
    if (!(await canAdministerRoom(socket, roomId))) {
      return denyPrivileged(socket, 'change_permissions', roomId);
    }
    // Two states, whatever spelling was asked for; anything else is refused
    // rather than stored — the column is read back by every client in the room.
    const stored = boardControlFor(boardControl);
    if (stored === null) {
      return denyPrivileged(socket, 'change_permissions', roomId);
    }
    try {
      await pool.query('UPDATE rooms SET board_control = $1 WHERE room_code = $2', [stored, roomId]);
      io.to(roomId).emit('permissions_updated', { boardControl: stored });
      logger.info(`[PERMISSIONS] Room ${roomId} boardControl updated to ${stored}`);
    } catch (e) {
      logger.error('Error updating permissions:', e);
    }
  });

  socket.on('force_flip_board', async ({ roomId, orientation }) => {
    if (!(await canAdministerRoom(socket, roomId))) {
      return denyPrivileged(socket, 'force_flip_board', roomId);
    }
    socket.to(roomId).emit('board_flipped', { orientation });
    logger.info(`[FORCE FLIP] Room ${roomId} -> orientation: ${orientation}`);
  });

  // `move`, `pgn_loaded` and a student sharing a position live in
  // services/roomBoardEvents.js: a socket acts only in the room it was seated in.
  registerRoomBoardEvents(socket, {
    pool, canAdministerRoom, denyPrivileged, members: () => activeRoomMembers,
  });

  socket.on('audio_join', async ({ roomId, isMuted }) => {
    // Asked again rather than trusted from the board join: voice is the part
    // in which a child is heard, and two paths into the same room
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
      userName: socket.userName || (authUser ? authUser.name : 'Guest'),
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

  // `audio_leave` lives in services/roomVoiceEvents.js: leaving the voice must
  // not take a seated socket out of the room its board is broadcast in.
  registerRoomVoiceEvents(socket, {
    io, audioUsers: () => roomAudioUsers, flushAudioUsage,
  });

  // Users may always mute themselves; muting someone else is a host action.
  socket.on('audio_mute_toggle', async ({ roomId, userId, isMuted }) => {
    const targetId = userId === undefined || userId === null ? socket.audioUserId : userId;
    const isSelf = String(targetId) === String(socket.audioUserId);
    if (!isSelf && !(await canAdministerRoom(socket, roomId))) {
      return denyPrivileged(socket, 'audio_mute_toggle', roomId);
    }
    if (roomAudioUsers[roomId] && roomAudioUsers[roomId][targetId]) {
      const target = roomAudioUsers[roomId][targetId];
      target.isMuted = isMuted;
      if (!isSelf && !isMuted) target.handRaised = false;
      io.to(roomId).emit('audio_users_list', Object.values(roomAudioUsers[roomId]));
      // The roster flag alone only changed a list; the member's own app is what
      // closes or opens the microphone, so a host's decision is sent to it.
      // Two literal names rather than a ternary: test/socket_contract.test.js
      // pairs event names by reading both ends, and a computed name is one it
      // cannot see.
      if (!isSelf && target.socketId && isMuted) {
        io.to(target.socketId).emit('audio_force_mute_student', { targetUserId: targetId });
      } else if (!isSelf && target.socketId) {
        io.to(target.socketId).emit('audio_force_unmute_student', { targetUserId: targetId });
      }
    }
  });

  /// A ready answer from somebody who is listening rather than speaking.
  ///
  /// This is what makes a listening-only seat a lesson instead of a broadcast:
  /// the trainer asks "jasno?" and gets an answer, without a child's voice being
  /// published into the channel.
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
      userName: socket.userName || 'Student',
      answer,
    });
  });

  // Raising a hand only ever applies to the socket that sent it.
  socket.on('audio_hand_raise_toggle', ({ roomId, handRaised }) => {
    const userId = socket.audioUserId;
    if (socket.audioRoomId !== roomId) return;
    if (roomAudioUsers[roomId] && roomAudioUsers[roomId][userId]) {
      roomAudioUsers[roomId][userId].handRaised = handRaised;
      io.to(roomId).emit('audio_users_list', Object.values(roomAudioUsers[roomId]));
      if (handRaised === true) {
        io.to(roomId).emit('audio_hand_raised_alert', {
          userId,
          userName: roomAudioUsers[roomId][userId].userName,
        });
      }
    }
  });

  socket.on('disconnect', () => {
    logger.info(`User disconnected: ${socket.id}`);

    if (socket.userId && realtime.goOffline(socket.userId, socket.id)) {
      logger.info(`[ONLINE PRESENCE] User disconnected: ID ${socket.userId}`);
    }

    // Only the seat this socket took: a late `disconnect` of an old socket must
    // not unseat the person who has already come back on a new one.
    if (socket.roomId && socket.userId
        && dropEntry(activeRoomMembers, socket.roomId, socket.userId, socket.id)) {
      if (activeRoomMembers[socket.roomId]) {
        io.to(socket.roomId).emit('room_members_list', Object.values(activeRoomMembers[socket.roomId]));
      }
    }

    // The voice half of a closing socket is in services/roomVoiceEvents.js,
    // beside `audio_leave`: one way out of the voice, whichever event brought it.
  });
});

// Start Database and Server
async function startServer() {
  try {
    await initDB();
    server.listen(PORT, () => {
      logger.info(`Server is listening on port ${PORT}`);
    });

    // A tutorial's film is drawn after its request has been answered, so a
    // render this process was holding when it stopped left a row that says
    // 'running' and never will be. Each is failed and its trainer told, rather
    // than left for them to find as a bar that never moves.
    renderJobs.reapInterrupted(pool)
      .then((count) => {
        if (count > 0) logger.warn(`[RENDER] ${count} render(s) interrupted by the restart were marked failed`);
      })
      .catch((err) => logger.error(`[RENDER] Could not mark interrupted renders: ${err.message}`));

    // What the opponent plays in a stored position was read from the Lichess
    // explorer by rating band until 15.9.2026, and those rows are a real
    // student's tree. They are rewritten from the local book once, here; every
    // start after that finds none and costs one query. A server without the
    // book leaves them as they are and says so — nothing reads them either way.
    refreshStoredReplies(pool, { judge: openingJudge })
      .then(({ positions, rewritten, removed }) => {
        if (positions > 0) {
          logger.warn(`[BOOK] ${positions} stored position(s) from the Lichess explorer: `
            + `${rewritten} rewritten from the book, ${removed} removed`);
        }
      })
      .catch((err) => logger.error(
        `[BOOK] Stored replies were not rewritten from the book (${err.reason || 'error'}): ${err.message}`,
      ));

    // exports/ holds rendered MP4s, which are always reproducible from the
    // recording that made them — unlike uploads/ audio, they are safe to age
    // out automatically before the droplet's disk fills silently.
    const retentionDays = Number(process.env.EXPORT_RETENTION_DAYS) || undefined;
    // An opponent's archive rides the same sweep. It is reproducible in one
    // request, so there is no reason to keep it — and unlike the player's own
    // games, which they uploaded and cannot re-derive, holding it is the whole
    // exposure. `forgetOldOpponents` only ever deletes `subject_is_owner =
    // FALSE` rows.
    const opponents = createOpponentPrep({
      pool, importer: createArchiveImporter({ pool }),
    });
    const runCleanup = () => Promise.all([
      cleanupOldExports(pool, retentionDays ? { maxAgeDays: retentionDays } : undefined)
        .catch((err) => logger.error(`[RETENTION] Export cleanup failed: ${err.message}`)),
      opponents.forgetOldOpponents()
        .catch((err) => logger.error(`[RETENTION] Opponent cleanup failed: ${err.message}`)),
    ]);
    runCleanup();
    setInterval(runCleanup, 24 * 60 * 60 * 1000);
  } catch (err) {
    logger.error('Failed to start server due to DB initialization failure:', err);
    process.exit(1);
  }
}

startServer();
