const logger = require('../services/logger');
const express = require('express');
const router = express.Router();
const { pool } = require('../db');
const { authenticateToken, requireRole } = require('../middleware/auth');
const { getUserStats } = require('../limitsService');
const relationships = require('../services/relationshipService');
const realtime = require('../services/realtime');
const { notify } = require('../services/notifications');
const { ownsRoom } = require('../services/roomAccess');
const mailService = require('../services/mailService');

/// Tells a user, if they are looking right now, that something about their
/// relationships changed — so the bell and the list refresh themselves instead
/// of waiting for the app to be restarted.
///
/// The notification row written just before this is the durable half; a
/// recipient who is offline reads it at next launch.
function nudge(userId) {
  realtime.emitToUser(userId, 'relationship_changed', {});
}

/// Looks a user up by the address typed into the form.
async function findUserByEmail(email) {
  const result = await pool.query('SELECT id, name, email FROM users WHERE email = $1', [email]);
  return result.rows[0] || null;
}

// POST /trainer/students/add — a trainer asks someone to become their student.
//
// This now creates a *request*, not a relationship. Nothing is granted until the
// other side accepts: previously the row itself was the relationship, so anyone
// could make anyone their student by typing an address, and two people who added
// each other could both set the other homework.
router.post('/trainer/students/add', authenticateToken, async (req, res) => {
  const { studentEmail } = req.body;
  if (!studentEmail) {
    return res.status(400).json({ error: 'Student email is required.' });
  }

  try {
    const student = await findUserByEmail(studentEmail);
    if (!student) {
      return res.status(404).json({ error: 'User with this email was not found.' });
    }

    const result = await relationships.requestRelationship(pool, {
      initiatorId: req.user.id,
      otherId: student.id,
      initiatorIsTrainer: true,
    });
    if (!result.ok) return res.status(400).json({ error: result.reason });

    if (!result.alreadyPending) {
      await relationships.notifyRequest(pool, {
        recipientId: student.id,
        senderId: req.user.id,
        senderName: req.user.name || 'Trainer',
        requestId: result.id,
        senderIsTrainer: true,
      });
      nudge(student.id);
    }

    res.json({
      message: 'Invitation sent. The relationship begins when the student accepts it.',
      status: 'pending',
      student,
    });
  } catch (err) {
    logger.error('Error requesting student:', err);
    res.status(500).json({ error: 'Error sending invitation.' });
  }
});

// POST /students/trainers/request — the same thing from the other end.
router.post('/students/trainers/request', authenticateToken, async (req, res) => {
  const { trainerEmail } = req.body;
  if (!trainerEmail) {
    return res.status(400).json({ error: 'Trainer email is required.' });
  }

  try {
    const trainer = await findUserByEmail(trainerEmail);
    if (!trainer) {
      return res.status(404).json({ error: 'User with this email was not found.' });
    }

    const result = await relationships.requestRelationship(pool, {
      initiatorId: req.user.id,
      otherId: trainer.id,
      initiatorIsTrainer: false,
    });
    if (!result.ok) return res.status(400).json({ error: result.reason });

    if (!result.alreadyPending) {
      await relationships.notifyRequest(pool, {
        recipientId: trainer.id,
        senderId: req.user.id,
        senderName: req.user.name || 'Student',
        requestId: result.id,
        senderIsTrainer: false,
      });
      nudge(trainer.id);
    }

    res.json({
      message: 'Request sent. The relationship begins when the trainer accepts it.',
      status: 'pending',
      trainer,
    });
  } catch (err) {
    logger.error('Error requesting trainer:', err);
    res.status(500).json({ error: 'Error sending request.' });
  }
});

// GET /relationships/pending — requests waiting for me to answer, either direction.
router.get('/relationships/pending', authenticateToken, async (req, res) => {
  try {
    res.json({ requests: await relationships.pendingForUser(pool, req.user.id) });
  } catch (err) {
    logger.error('Error fetching pending relationships:', err);
    res.status(500).json({ error: 'Error fetching requests.' });
  }
});

// POST /relationships/:id/accept
router.post('/relationships/:id/accept', authenticateToken, async (req, res) => {
  const requestId = Number.parseInt(req.params.id, 10);
  if (!Number.isInteger(requestId)) {
    return res.status(400).json({ error: 'Invalid request.' });
  }

  try {
    const result = await relationships.respondToRequest(pool, {
      requestId,
      userId: req.user.id,
      accept: true,
    });
    if (!result.ok) return res.status(403).json({ error: result.reason });

    // A minor's relationship stops here: both sides agreed, and the parent has
    // not. Saying "odnos je uspostavljen" would be the exact failure this
    // codebase keeps paying for — a step that did not happen, reported as
    // success one layer up — and here it would tell a trainer they may teach a
    // child they may not.
    if (result.awaitingParent) {
      if (result.missingParentEmail) {
        await relationships.notifyAwaitingParent(pool, {
          recipientId: result.senderId,
          accepterId: req.user.id,
          accepterName: req.user.name || 'User',
          delivered: false,
        });
        nudge(result.senderId);
        return res.json({
          status: 'awaiting_parent',
          parentEmailMissing: true,
          message: 'Parental consent is required, but there is no parent address on the student account. '
            + 'The student should enter it in Settings.',
        });
      }

      let delivered = true;
      let deliveryError = null;
      try {
        await mailService.sendParentConsentRequest(result.parentEmail, {
          childName: result.studentName,
          trainerName: result.trainerName,
          link: result.consentLink,
        });
      } catch (mailErr) {
        // Not fatal and not hidden. The request row stands, so the link can be
        // sent again; what must not happen is the app reporting that a parent
        // was asked when nothing left the server.
        delivered = false;
        deliveryError = mailErr.message;
        logger.error('[SAGLASNOST] Poruka roditelju nije poslata:', mailErr);
      }

      await relationships.notifyAwaitingParent(pool, {
        recipientId: result.senderId,
        accepterId: req.user.id,
        accepterName: req.user.name || 'User',
        delivered,
      });
      nudge(result.senderId);

      return res.json({
        status: 'awaiting_parent',
        parentEmailMissing: false,
        mailDelivered: delivered,
        deliveryError,
        message: delivered
          ? 'A message has been sent to the parent. The relationship begins when the parent confirms.'
          : 'The relationship is awaiting parental consent, but the message could not be sent. '
            + 'Please try again from the student list.',
      });
    }

    await relationships.notifyAccept(pool, {
      recipientId: result.senderId,
      accepterId: req.user.id,
      accepterName: req.user.name || 'User',
    });
    nudge(result.senderId);

    res.json({ status: 'accepted', message: 'Relationship established.' });
  } catch (err) {
    logger.error('Error accepting relationship:', err);
    res.status(500).json({ error: 'Error accepting request.' });
  }
});

// POST /relationships/:id/decline
router.post('/relationships/:id/decline', authenticateToken, async (req, res) => {
  const requestId = Number.parseInt(req.params.id, 10);
  if (!Number.isInteger(requestId)) {
    return res.status(400).json({ error: 'Invalid request.' });
  }

  try {
    const result = await relationships.respondToRequest(pool, {
      requestId,
      userId: req.user.id,
      accept: false,
    });
    if (!result.ok) return res.status(403).json({ error: result.reason });

    await relationships.notifyDecline(pool, {
      recipientId: result.senderId,
      declinerId: req.user.id,
      declinerName: req.user.name || 'User',
    });
    nudge(result.senderId);

    res.json({ message: 'Request declined.' });
  } catch (err) {
    logger.error('Error declining relationship:', err);
    res.status(500).json({ error: 'Error declining request.' });
  }
});

// GET /trainer/students — my students, accepted and still pending.
//
// Pending ones are included on purpose, with their status: a name that silently
// does nothing is worse than one labelled "čeka potvrdu".
router.get('/trainer/students', authenticateToken, async (req, res) => {
  try {
    res.json({ students: await relationships.listStudents(pool, req.user.id) });
  } catch (err) {
    logger.error('Error fetching students:', err);
    res.status(500).json({ error: 'Error fetching list.' });
  }
});

// GET /students/trainers — the same edge read from the other end.
router.get('/students/trainers', authenticateToken, async (req, res) => {
  try {
    res.json({ trainers: await relationships.listTrainers(pool, req.user.id) });
  } catch (err) {
    logger.error('Error fetching trainers:', err);
    res.status(500).json({ error: 'Error fetching list.' });
  }
});

// PATCH /trainer/students/:studentId/voice  { level: 'listen' | 'talk' }
//
// The trainer decides whether this student speaks in their room. It is not a
// button on the student's screen and not a setting on the account: it is a row
// the voice token is minted from, so it holds against any client.
//
// A student who is in a room right now is told, so their app rejoins the channel
// with a token that matches — otherwise taking the microphone back would apply
// only from the next lesson, which is not what anybody would expect it to mean.
router.patch('/trainer/students/:studentId/voice', authenticateToken, async (req, res) => {
  const studentId = Number.parseInt(req.params.studentId, 10);
  if (!Number.isInteger(studentId)) {
    return res.status(400).json({ error: 'Invalid student.' });
  }

  try {
    const result = await relationships.setVoiceLevel(pool, {
      trainerId: req.user.id,
      studentId,
      level: req.body?.level,
    });
    if (!result.ok) return res.status(403).json({ error: result.reason });

    realtime.emitToUser(studentId, 'voice_level_changed', {
      level: result.level,
      trainerId: req.user.id,
    });

    logger.info(
      `[GLAS] Trener ${req.user.id} je učeniku ${studentId} postavio glas na ${result.level}`
    );
    res.json({ level: result.level });
  } catch (err) {
    logger.error('[GLAS] Nivo glasa nije mogao da se promeni:', err);
    res.status(500).json({ error: 'Failed to save change.' });
  }
});

// DELETE /trainer/students/:studentId — ends the relationship from either side.
router.delete('/trainer/students/:studentId', authenticateToken, async (req, res) => {
  const otherId = Number.parseInt(req.params.studentId, 10);
  if (!Number.isInteger(otherId)) {
    return res.status(400).json({ error: 'Invalid user.' });
  }

  try {
    await relationships.removeRelationship(pool, { userId: req.user.id, otherId });
    res.json({ message: 'Relationship terminated.' });
  } catch (err) {
    logger.error('Error removing relationship:', err);
    res.status(500).json({ error: 'Error removing relationship.' });
  }
});

// GET /users/me/stats
router.get('/users/me/stats', authenticateToken, async (req, res) => {
  try {
    const stats = await getUserStats(pool, req.user.id);
    res.json(stats);
  } catch (err) {
    logger.error('Error fetching user stats:', err);
    res.status(500).json({ error: 'Error fetching stats.' });
  }
});

// POST /users/account-type — administrative grant, not a self-service upgrade.
//
// This used to be reachable by any authenticated user and changed *their own*
// account_type, so every paid tier was one request away from being free. Until
// billing exists, tiers are granted manually by an admin; once it does, the
// payment provider's webhook becomes the only writer and this stays the manual
// override for comped and support cases.
router.post('/users/account-type', authenticateToken, requireRole('admin'), async (req, res) => {
  const { accountType, userId } = req.body;
  const validTypes = ['free', 'premium', 'club', 'pro'];

  if (!accountType || !validTypes.includes(accountType)) {
    return res.status(400).json({ error: 'Invalid account type.' });
  }

  const targetId = Number.parseInt(userId, 10);
  if (!Number.isInteger(targetId)) {
    return res.status(400).json({ error: 'userId is required and must be a number.' });
  }

  try {
    const result = await pool.query(
      'UPDATE users SET account_type = $1 WHERE id = $2 RETURNING id, email, account_type',
      [accountType, targetId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found.' });
    }

    const updated = result.rows[0];
    logger.info(
      { adminId: req.user.id, targetUserId: updated.id, accountType },
      'Account type granted by admin'
    );
    res.json({
      success: true,
      message: `Account type for ${updated.email} changed to '${accountType}'.`,
      user: updated
    });
  } catch (err) {
    logger.error('Error updating account type:', err);
    res.status(500).json({ error: 'Error updating account type.' });
  }
});

// GET /friends
router.get('/friends', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      // Names, not addresses — see listStudents for why.
      `SELECT u.id, u.name
       FROM users u
       JOIN friends f ON u.id = f.friend_id
       WHERE f.user_id = $1`,
      [req.user.id]
    );
    res.json({ friends: result.rows });
  } catch (err) {
    logger.error('Error fetching friends:', err);
    res.status(500).json({ error: 'Error fetching friends list.' });
  }
});

// There is deliberately no POST /friends/add, and no DELETE either.
//
// It existed until 25.8.2026: it took an **email**, found the user and wrote the
// row **in both directions with nobody's consent**. Anyone who knew a child's
// address could put themselves on that child's list, and `GET /friends` then
// handed back the name and the address of everyone on it. It was the one hole
// in a consent model that is honoured everywhere else in this app — and the
// closest thing here to a social network.
//
// Removed rather than given a request flow, because there was nothing to keep:
// no screen in the app ever called it. The dead client code went with it.
//
// So a `friends` row now has exactly one origin: an accepted trainer–student
// relationship writes the pair, and ending that relationship deletes it. Every
// connection in this app is therefore something both sides agreed to, and a
// minor's only connection is an adult who teaches them. If friendship between
// adults is ever wanted as a feature of its own, it gets the same
// pending → accepted edge that `trainer_students` already has; what it does not
// get is a second way in that skips the asking.

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
    logger.error('Error fetching notifications:', err);
    res.status(500).json({ error: 'Error fetching notifications.' });
  }
});

// POST /notifications/read — everything the user has just been shown.
//
// Until this existed only a room invitation was ever marked read, and only by
// being joined. Every other kind stayed unread for good: a user could open the
// bell, read all of it, close it, and the badge still said three. The count was
// arithmetically right and useless.
//
// A request still waiting is not affected. It is counted from
// `/relationships/pending`, not from its notification, precisely so that
// reading about it cannot make it stop being waited on.
router.post('/notifications/read', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'UPDATE user_notifications SET is_read = TRUE WHERE user_id = $1 AND is_read = FALSE',
      [req.user.id]
    );
    res.json({ success: true, marked: result.rowCount });
  } catch (err) {
    logger.error('Error marking notifications read:', err);
    res.status(500).json({ error: 'Error updating notifications.' });
  }
});

// POST /notifications/:id/read
router.post('/notifications/:id/read', authenticateToken, async (req, res) => {
  try {
    await pool.query('UPDATE user_notifications SET is_read = TRUE WHERE id = $1 AND user_id = $2', [req.params.id, req.user.id]);
    res.json({ success: true });
  } catch (err) {
    logger.error('Error marking notification read:', err);
    res.status(500).json({ error: 'Error updating notification.' });
  }
});

// POST /invitations/send
router.post('/invitations/send', authenticateToken, async (req, res) => {
  const { studentId, friendIds, roomCode } = req.body;
  const senderId = req.user.id;

  const targetIds = Array.isArray(friendIds) ? friendIds : (studentId ? [studentId] : []);

  if (targetIds.length === 0 || !roomCode) {
    return res.status(400).json({ error: 'Recipient parameters (studentId/friendIds) and roomCode are required.' });
  }

  try {
    // Only people this sender is actually in a relationship with. The list of
    // ids arrives from the client, so without this anybody could push a
    // notification naming themselves at any user id they cared to type — and
    // most of the ids in this app belong to children. Being unable to reach
    // somebody who never agreed to be taught by you is the whole model.
    const allowed = [];
    for (const targetId of targetIds) {
      if (await relationships.acceptedEdgeBetween(pool, senderId, targetId)) {
        allowed.push(targetId);
      }
    }
    if (allowed.length === 0) {
      return res.status(403).json({
        error: 'An invitation can only be sent to a student or trainer who has accepted the relationship.',
      });
    }

    const senderRes = await pool.query('SELECT name FROM users WHERE id = $1', [senderId]);
    const senderName = senderRes.rows[0]?.name || 'Trainer/Friend';

    const title = 'Chess session invitation';
    const message = `${senderName} invites you to join a chess session in room: ${roomCode}`;

    for (const targetId of allowed) {
      await notify(pool, {
        recipientId: targetId,
        senderId,
        roomCode,
        title,
        message,
      });
    }

    // Said out loud when part of the list was dropped: a silent partial success
    // is how somebody concludes the app is broken and sends it four more times.
    res.json({
      success: true,
      message: allowed.length === targetIds.length
        ? 'Invitation sent successfully.'
        : `Invitation sent: ${allowed.length} of ${targetIds.length}. `
          + 'The others are not in an accepted relationship with you.',
      sent: allowed.length,
    });
  } catch (err) {
    logger.error('Error sending invitation:', err);
    res.status(500).json({ error: 'Error sending invitation.' });
  }
});

// POST /sessions/schedule
router.post('/sessions/schedule', authenticateToken, async (req, res) => {
  const { title, description, scheduledAt, invites, roomCode } = req.body;
  const hostId = req.user.id;

  if (!title || !scheduledAt || !roomCode) {
    return res.status(400).json({ error: 'Title, time and room code are required.' });
  }

  try {
    // The room has to be the caller's own. An invitation to a scheduled session
    // is one of the ways into a room (`roomAccess.mayJoinRoom`), so scheduling
    // one on a room code that belongs to somebody else is writing yourself a
    // key. `mayJoinRoom` now also checks who the host was, so this is the second
    // lock on the same door — deliberately, because the first one was missing
    // for a day.
    if (!(await ownsRoom(pool, { roomCode, userId: hostId }))) {
      return res.status(403).json({
        error: 'A session is scheduled in your own room. Create a room first, then schedule it.',
      });
    }

    const sessionRes = await pool.query(
      `INSERT INTO scheduled_sessions (host_id, room_code, title, description, scheduled_at)
       VALUES ($1, $2, $3, $4, $5) RETURNING id`,
      [hostId, roomCode, title, description || '', scheduledAt]
    );

    const sessionId = sessionRes.rows[0].id;

    if (invites && Array.isArray(invites) && invites.length > 0) {
      for (const userId of invites) {
        // Same rule as everywhere else: an invitation is not a way around
        // consent. Somebody who never accepted you is not invited, quietly
        // skipped rather than refusing the whole schedule.
        if (!(await relationships.acceptedEdgeBetween(pool, hostId, userId))) {
          continue;
        }
        await pool.query(
          `INSERT INTO scheduled_session_invites (session_id, user_id)
           VALUES ($1, $2) ON CONFLICT DO NOTHING`,
          [sessionId, userId]
        );

        const hostRes = await pool.query('SELECT name FROM users WHERE id = $1', [hostId]);
        const hostName = hostRes.rows[0]?.name || 'Trainer';

        await notify(pool, {
          recipientId: userId,
          senderId: hostId,
          roomCode,
          title: `Scheduled session: ${title}`,
          message: `${hostName} scheduled a session for ${new Date(scheduledAt).toLocaleString()}. Room code: ${roomCode}`,
        });
      }
    }

    res.json({ success: true, message: 'Session scheduled successfully.', sessionId });
  } catch (err) {
    logger.error('Error scheduling session:', err);
    res.status(500).json({ error: 'Error scheduling session.' });
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
    logger.error('Error fetching scheduled sessions:', err);
    res.status(500).json({ error: 'Error fetching scheduled sessions.' });
  }
});

module.exports = router;
