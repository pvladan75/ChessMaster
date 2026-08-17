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

/// SQL fragment: the ids of the users who are `param`'s **accepted** trainers.
///
/// It exists because the same subquery was written out by hand at three call
/// sites and all three forgot the status condition, so a request nobody had
/// answered already unlocked the other side's lessons. `trainerOwnsStudent`
/// guards homework and reports; this guards everything read through the edge.
///
/// `param` is a placeholder name, never a value — anything else is a call site
/// about to interpolate data into SQL, so it throws instead of building it.
function acceptedTrainersOf(param) {
  if (!/^\$\d+$/.test(param)) {
    throw new Error(`acceptedTrainersOf expects a placeholder like "$1", got: ${param}`);
  }
  return `SELECT trainer_id FROM trainer_students
            WHERE student_id = ${param} AND status = 'accepted'`;
}

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

  // Both directions, not just the one being asked for. Looking only for
  // (trainer, student) let the reverse row through, because it is a different
  // row — which is how two people ended up teaching each other. Consent alone
  // does not fix that: the second request looks ordinary to whoever answers it,
  // and says nothing about the relationship already running the other way.
  const existing = await pool.query(
    `SELECT id, trainer_id, student_id, status, initiated_by
       FROM trainer_students
      WHERE (trainer_id = $1 AND student_id = $2)
         OR (trainer_id = $2 AND student_id = $1)
      ORDER BY (trainer_id = $1) DESC`,
    [trainerId, studentId]
  );

  if (existing.rows.length > 0) {
    // Same direction first, so "you already asked this" wins over "the reverse
    // exists" when a legacy pair still has both rows.
    const row = existing.rows[0];
    const sameDirection = row.trainer_id === trainerId;

    if (sameDirection) {
      if (row.status === 'accepted') {
        return { ok: false, reason: 'Taj odnos već postoji.', id: row.id };
      }
      // A repeated request is not an error: the invitation simply still stands.
      return { ok: true, alreadyPending: true, id: row.id, awaitingMe: row.initiated_by !== initiatorId };
    }

    // The reverse exists. Whatever the sender is claiming now, the running
    // relationship casts them as the opposite.
    if (row.status === 'accepted') {
      return {
        ok: false,
        id: row.id,
        reason: initiatorIsTrainer
          ? 'Sa tom osobom već postoji odnos — ona je vaš trener. Raskinite ga pre nego što zatražite obrnuto.'
          : 'Sa tom osobom već postoji odnos — vi ste njen trener. Raskinite ga pre nego što zatražite obrnuto.',
      };
    }
    return {
      ok: false,
      id: row.id,
      reason: 'Zahtev u suprotnom smeru već čeka odgovor. Rešite njega pre nego što pošaljete ovaj.',
    };
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

    await closeRequestNotification(pool, requestId);
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
  await closeRequestNotification(pool, requestId);

  // The sender is simply the other participant: only two people are on a
  // request, and the one answering is `userId`.
  const { trainer_id: trainerId, student_id: studentId } = deleted.rows[0];
  const senderId = userId === trainerId ? studentId : trainerId;

  return { ok: true, declined: true, senderId };
}

/// Marks the notification that carried a request as read, once it is answered.
///
/// The request card disappears on its own — it is drawn from `trainer_students`
/// — but the notification is a separate row and stayed unread forever, so the
/// bell kept a permanent count for something already dealt with. After a
/// decline it is worse than stale: `ref_id` points at a row that no longer
/// exists.
///
/// Read rather than deleted: the notification is the record that the request
/// was made, and that outlives the request itself.
async function closeRequestNotification(pool, requestId) {
  try {
    await pool.query(
      `UPDATE user_notifications
          SET is_read = TRUE
        WHERE kind = 'student_request' AND ref_id = $1`,
      [requestId]
    );
  } catch (err) {
    // Best effort, like raising it was: an answered request must not be undone
    // because its notification could not be tidied up.
    logger.error('Could not close relationship notification:', err);
  }
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

/// Tells the sender that their request was answered with no.
///
/// Without it a declined request simply vanishes: the row is deleted so that
/// asking again works, and the sender is left unable to tell "declined" from
/// "never sent" — whose natural answer is to send it again, and again.
///
/// Deliberately says only that it was not accepted. No reason is asked for and
/// none is passed on; a refusal that has to be justified is harder to give, and
/// the people refusing here are often children.
async function notifyDecline(pool, { recipientId, declinerId, declinerName }) {
  try {
    await pool.query(
      `INSERT INTO user_notifications (user_id, sender_id, room_code, title, message, kind, ref_id)
       VALUES ($1, $2, NULL, $3, $4, 'request_declined', NULL)`,
      [
        recipientId,
        declinerId,
        'Zahtev nije prihvaćen',
        `${declinerName} nije prihvatio vaš zahtev.`,
      ]
    );
  } catch (err) {
    // Best effort, like every other notification here: a decline that went
    // through must not be undone because the note about it failed.
    logger.error('Could not create decline notification:', err);
  }
}

module.exports = {
  acceptedTrainersOf,
  notifyDecline,
  requestRelationship,
  pendingForUser,
  respondToRequest,
  listStudents,
  listTrainers,
  removeRelationship,
  notifyRequest,
};
