// relationshipService.js
// Who may teach whom.
//
// The model in one sentence: *trainer* is not a property of a person but a
// position in a relationship. The same account is a trainer in one edge and a
// student in another, which is why `users.role` plays no part here and why
// nobody has to grant anyone the right to be a trainer.
//
// An edge is created by either side and grants nothing until the other side
// accepts. Before that, `trainer_students` was the relationship itself, so
// whoever typed the other's email first became the trainer — and two people who
// added each other could both set the other homework.

const logger = require('./logger');

/// Creates a request and returns what happened, rather than throwing.
///
/// `initiatorIsTrainer` decides only which column the initiator lands in; the
/// consent step is identical in both directions.
async function requestRelationship(pool, { initiatorId, otherId, initiatorIsTrainer }) {
  if (initiatorId === otherId) {
    return { ok: false, reason: 'Ne možete zasnovati odnos sa samim sobom.' };
  }

  const trainerId = initiatorIsTrainer ? initiatorId : otherId;
  const studentId = initiatorIsTrainer ? otherId : initiatorId;

  const existing = await pool.query(
    'SELECT id, status, initiated_by FROM trainer_students WHERE trainer_id = $1 AND student_id = $2',
    [trainerId, studentId]
  );

  if (existing.rows.length > 0) {
    const row = existing.rows[0];
    if (row.status === 'accepted') {
      return { ok: false, reason: 'Taj odnos već postoji.', id: row.id };
    }
    // A repeated request is not an error: the invitation simply still stands.
    return { ok: true, alreadyPending: true, id: row.id, awaitingMe: row.initiated_by !== initiatorId };
  }

  const inserted = await pool.query(
    `INSERT INTO trainer_students (trainer_id, student_id, status, initiated_by)
     VALUES ($1, $2, 'pending', $3)
     RETURNING id`,
    [trainerId, studentId, initiatorId]
  );

  return { ok: true, id: inserted.rows[0].id, alreadyPending: false };
}

/// Requests waiting for this user to answer.
///
/// Deliberately covers both directions at once: from the answering side it makes
/// no difference whether a trainer enrolled them or they asked a trainer, only
/// that somebody is waiting.
async function pendingForUser(pool, userId) {
  const result = await pool.query(
    `SELECT ts.id,
            ts.created_at,
            (ts.student_id = $1) AS i_am_student,
            u.id   AS other_id,
            u.name AS other_name,
            u.email AS other_email
       FROM trainer_students ts
       JOIN users u
         ON u.id = CASE WHEN ts.student_id = $1 THEN ts.trainer_id ELSE ts.student_id END
      WHERE ts.status = 'pending'
        AND ts.initiated_by <> $1
        AND $1 IN (ts.trainer_id, ts.student_id)
      ORDER BY ts.created_at DESC`,
    [userId]
  );
  return result.rows;
}

/// Accepts or declines, and refuses everything else in a single statement.
///
/// The WHERE clause carries the whole rule: only a participant, only the side
/// that did not start it, and only while it is still pending. Checking those in
/// JavaScript first would leave a gap between the check and the write.
async function respondToRequest(pool, { requestId, userId, accept }) {
  if (accept) {
    const updated = await pool.query(
      `UPDATE trainer_students
          SET status = 'accepted', responded_at = CURRENT_TIMESTAMP
        WHERE id = $1
          AND status = 'pending'
          AND initiated_by <> $2
          AND $2 IN (trainer_id, student_id)
        RETURNING trainer_id, student_id`,
      [requestId, userId]
    );

    if (updated.rows.length === 0) {
      return { ok: false, reason: 'Zahtev ne postoji, već je rešen, ili nije upućen vama.' };
    }

    const { trainer_id: trainerId, student_id: studentId } = updated.rows[0];

    // Friendship follows acceptance rather than the request. Creating it earlier
    // would put someone in your friend list without your ever agreeing.
    await pool.query(
      `INSERT INTO friends (user_id, friend_id) VALUES ($1, $2), ($2, $1)
       ON CONFLICT DO NOTHING`,
      [trainerId, studentId]
    );

    return { ok: true, trainerId, studentId };
  }

  const deleted = await pool.query(
    `DELETE FROM trainer_students
      WHERE id = $1
        AND status = 'pending'
        AND initiated_by <> $2
        AND $2 IN (trainer_id, student_id)
      RETURNING trainer_id, student_id`,
    [requestId, userId]
  );

  if (deleted.rows.length === 0) {
    return { ok: false, reason: 'Zahtev ne postoji, već je rešen, ili nije upućen vama.' };
  }
  return { ok: true, declined: true };
}

/// Accepted students of a trainer, plus the ones still waiting, so the client
/// can show "čeka potvrdu" instead of a name that silently does nothing.
async function listStudents(pool, trainerId) {
  const result = await pool.query(
    `SELECT u.id, u.name, u.email, ts.status, (ts.initiated_by = $1) AS i_asked
       FROM users u
       JOIN trainer_students ts ON u.id = ts.student_id
      WHERE ts.trainer_id = $1
      ORDER BY ts.status DESC, u.name ASC`,
    [trainerId]
  );
  return result.rows;
}

/// The same edge read from the other end.
async function listTrainers(pool, studentId) {
  const result = await pool.query(
    `SELECT u.id, u.name, u.email, ts.status, (ts.initiated_by = $1) AS i_asked
       FROM users u
       JOIN trainer_students ts ON u.id = ts.trainer_id
      WHERE ts.student_id = $1
      ORDER BY ts.status DESC, u.name ASC`,
    [studentId]
  );
  return result.rows;
}

/// Ends a relationship from either side.
async function removeRelationship(pool, { userId, otherId }) {
  const deleted = await pool.query(
    `DELETE FROM trainer_students
      WHERE (trainer_id = $1 AND student_id = $2)
         OR (trainer_id = $2 AND student_id = $1)
      RETURNING id`,
    [userId, otherId]
  );
  if (deleted.rows.length > 0) {
    await pool.query(
      `DELETE FROM friends
        WHERE (user_id = $1 AND friend_id = $2) OR (user_id = $2 AND friend_id = $1)`,
      [userId, otherId]
    );
  }
  return deleted.rows.length;
}

/// Raises the in-app notification that carries the request.
///
/// Best effort on purpose: a notification that fails to insert must not undo a
/// request the user already made. It is logged instead.
async function notifyRequest(pool, { recipientId, senderId, senderName, requestId, senderIsTrainer }) {
  const title = senderIsTrainer ? 'Poziv trenera' : 'Zahtev učenika';
  const message = senderIsTrainer
    ? `${senderName} želi da vas upiše kao učenika.`
    : `${senderName} želi da mu budete trener.`;

  try {
    await pool.query(
      `INSERT INTO user_notifications (user_id, sender_id, room_code, title, message, kind, ref_id)
       VALUES ($1, $2, NULL, $3, $4, 'student_request', $5)`,
      [recipientId, senderId, title, message, requestId]
    );
  } catch (err) {
    logger.error('Could not create relationship notification:', err);
  }
}

module.exports = {
  requestRelationship,
  pendingForUser,
  respondToRequest,
  listStudents,
  listTrainers,
  removeRelationship,
  notifyRequest,
};
