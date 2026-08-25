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
const { notify } = require('./notifications');
// The one rule about age that this file has to obey, kept in one place so the
// request and the acceptance cannot drift apart.
const { mayRelate, startingVoiceLevel, ageStatus } = require('./ageService');
// A minor's relationship does not begin when the two of them agree; it begins
// when the parent says so. The step in between is `awaiting_parent`, which the
// status column has allowed since it was written and nothing filled until now.
const { openRequest } = require('./parentConsentService');

/// Who to write to, and whose names go in the letter.
///
/// One query for all three because they are always wanted together, and one
/// place because "no address on file" is a state the flow has to name rather
/// than trip over: it is the difference between a parent who has not answered
/// and a parent who was never asked.
async function parentContactOf(pool, studentId, trainerId) {
  const result = await pool.query(
    `SELECT s.parent_email, s.name AS student_name, t.name AS trainer_name
       FROM users s, users t
      WHERE s.id = $1 AND t.id = $2`,
    [studentId, trainerId],
  );
  const row = result.rows[0] ?? {};
  const email = row.parent_email;
  return {
    parentEmail: email && String(email).trim() !== '' ? email : null,
    studentName: row.student_name ?? null,
    trainerName: row.trainer_name ?? null,
  };
}

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

/// Whether two people are in an accepted relationship, in either direction.
///
/// The third place rights are read from, and it exists for the same reason as
/// the other two: the condition that matters is `status = 'accepted'`, and
/// every hand-written copy of it so far has forgotten it. Direction is not
/// asked about on purpose — a trainer and their student are related whichever
/// way the request originally went, and callers that cared about direction
/// already have `trainerOwnsStudent`.
async function acceptedEdgeBetween(pool, a, b) {
  if (a === null || a === undefined || b === null || b === undefined) {
    return false;
  }
  if (Number(a) === Number(b)) return false;

  const result = await pool.query(
    `SELECT 1 FROM trainer_students
      WHERE status = 'accepted'
        AND ((trainer_id = $1 AND student_id = $2)
          OR (trainer_id = $2 AND student_id = $1))
      LIMIT 1`,
    [a, b],
  );
  return result.rowCount > 0;
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

  // A minor is somebody's student, never somebody's trainer. Asked at the last
  // moment, once it is clear a row is actually going to be written: how old a
  // child says they are is not a thing to look up in order to answer "that
  // relationship already exists". Asked again when the request is answered — a
  // request made before anybody had stated an age must not quietly become a
  // relationship afterwards.
  const age = await mayRelate(pool, { trainerId, studentId });
  if (!age.allowed) {
    return { ok: false, reason: age.message };
  }

  // The row says what it means rather than taking the column default. The
  // default is `'talk'`, which exists to grandfather the relationships written
  // before any of this — a new one starts where it should: a child listens.
  const voiceLevel = await startingVoiceLevel(pool, studentId);

  const inserted = await pool.query(
    `INSERT INTO trainer_students (trainer_id, student_id, status, initiated_by, voice_level)
     VALUES ($1, $2, 'pending', $3, $4)
     RETURNING id`,
    [trainerId, studentId, initiatorId, voiceLevel]
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
    // Asked before the write rather than woven into it. The UPDATE below still
    // carries every rule about *who* may answer — a participant, not the
    // sender, still pending — and that stays one statement. The age is a
    // different kind of condition: it is read from the same service the request
    // side reads it from, because a second hand-written copy of a rule about
    // children is exactly what this codebase has paid for three times.
    //
    // It matters most here: every request that exists today was made while
    // nobody had stated an age at all.
    const pendingRow = await pool.query(
      `SELECT trainer_id, student_id FROM trainer_students
        WHERE id = $1 AND status = 'pending'`,
      [requestId],
    );
    if (pendingRow.rows.length > 0) {
      const age = await mayRelate(pool, {
        trainerId: pendingRow.rows[0].trainer_id,
        studentId: pendingRow.rows[0].student_id,
      });
      if (!age.allowed) {
        return { ok: false, reason: age.message };
      }
    }

    // Whether the parent has to be asked, decided **before** the write, so the
    // row never spends a moment saying `accepted`. A relationship that is
    // accepted for one statement and then corrected is a relationship that is
    // accepted for whatever read happens in between.
    const student = pendingRow.rows.length > 0
      ? await ageStatus(pool, pendingRow.rows[0].student_id)
      : { minor: false };
    const nextStatus = student.minor ? 'awaiting_parent' : 'accepted';

    const updated = await pool.query(
      `UPDATE trainer_students
          SET status = $3, responded_at = CURRENT_TIMESTAMP
        WHERE id = $1
          AND status = 'pending'
          AND initiated_by <> $2
          AND $2 IN (trainer_id, student_id)
        RETURNING trainer_id, student_id`,
      [requestId, userId, nextStatus]
    );

    if (updated.rows.length === 0) {
      return { ok: false, reason: 'Zahtev ne postoji, već je rešen, ili nije upućen vama.' };
    }

    const { trainer_id: trainerId, student_id: studentId } = updated.rows[0];
    // Reported the same way as on a decline, so the caller has one person to
    // tell either way and does not work out "the other participant" itself.
    const senderId = userId === trainerId ? studentId : trainerId;

    if (student.minor) {
      // Both people agreed; the relationship still does not exist. Nothing that
      // an accepted edge unlocks — homework, reports, the room, the microphone —
      // is reachable from `awaiting_parent`, and no row goes into `friends`.
      await closeRequestNotification(pool, requestId);
      const contact = await parentContactOf(pool, studentId, trainerId);
      if (contact.parentEmail === null) {
        // Said out loud rather than left as a row nobody is waiting on. The
        // child has to add a parent's address before anybody can be asked, and
        // silence here would look exactly like an email that got lost.
        return {
          ok: true, awaitingParent: true, missingParentEmail: true,
          trainerId, studentId, senderId, ...contact,
        };
      }
      const request = await openRequest(pool, {
        relationshipId: requestId,
        studentId,
        trainerId,
        parentEmail: contact.parentEmail,
      });
      return {
        ok: true, awaitingParent: true, missingParentEmail: false,
        consentLink: request.link,
        trainerId, studentId, senderId, ...contact,
      };
    }

    // Friendship follows acceptance rather than the request. Creating it earlier
    // would put someone in your friend list without your ever agreeing.
    await pool.query(
      `INSERT INTO friends (user_id, friend_id) VALUES ($1, $2), ($2, $1)
       ON CONFLICT DO NOTHING`,
      [trainerId, studentId]
    );

    await closeRequestNotification(pool, requestId);
    return { ok: true, awaitingParent: false, trainerId, studentId, senderId };
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
  // No email. A list of people is not the place for their addresses, and most
  // of the people in this one are children: an address that travels through a
  // list ends up on a screen it was never meant for. Whoever needs to write to
  // a student already knows how — they invited them by that very address.
  const result = await pool.query(
    `SELECT u.id, u.name, ts.status, ts.voice_level,
            (ts.initiated_by = $1) AS i_asked
       FROM users u
       JOIN trainer_students ts ON u.id = ts.student_id
      WHERE ts.trainer_id = $1
      ORDER BY ts.status DESC, u.name ASC`,
    [trainerId]
  );
  return result.rows;
}

/// Grants or takes back the microphone for one student of this trainer.
///
/// A right rather than a request: it is read again when the voice token is
/// issued, so taking it back holds even against a client that would rather not
/// notice. The caller checks first that the student is theirs — through
/// `trainerOwnsStudent`, the same place homework and reports are checked, since
/// this is the same kind of decision about the same person.
async function setVoiceLevel(pool, { trainerId, studentId, level }) {
  if (level !== 'listen' && level !== 'talk') {
    return { ok: false, reason: 'Glas može biti samo „listen" ili „talk".' };
  }

  const updated = await pool.query(
    `UPDATE trainer_students
        SET voice_level = $1
      WHERE trainer_id = $2 AND student_id = $3 AND status = 'accepted'
      RETURNING voice_level`,
    [level, trainerId, studentId]
  );
  if (updated.rows.length === 0) {
    return { ok: false, reason: 'Taj učenik nije vaš, ili veza još nije prihvaćena.' };
  }
  // Read back, not echoed: the value on the screen and the value in the row are
  // two different things, and only one of them decides what the token says.
  return { ok: true, level: updated.rows[0].voice_level };
}

/// The same edge read from the other end.
async function listTrainers(pool, studentId) {
  const result = await pool.query(
    `SELECT u.id, u.name, ts.status, (ts.initiated_by = $1) AS i_asked
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

  await notify(pool, {
    recipientId,
    senderId,
    title,
    message,
    kind: 'student_request',
    refId: requestId,
  });
}

/// Tells the sender that their request was answered with yes.
///
/// Until this existed, acceptance was the one answer nobody was told about:
/// a decline raised a notification, while an accept raised nothing at all. The
/// sender was left watching a row that said "čeka potvrdu" with no way to learn
/// that it no longer did — the relationship worked, and only looked broken.
async function notifyAccept(pool, { recipientId, accepterId, accepterName }) {
  await notify(pool, {
    recipientId,
    senderId: accepterId,
    title: 'Zahtev je prihvaćen',
    message: `${accepterName} je prihvatio vaš zahtev.`,
    kind: 'request_accepted',
  });
}

/// Tells the sender that the answer was yes and the relationship still has not
/// started, because a parent has to say so.
///
/// Its own message rather than `notifyAccept` with different wording: "prihvaćen"
/// and "čeka roditelja" are different states, and a trainer who reads the first
/// one will go looking for a student who is not there yet.
///
/// It also carries whether the mail actually left. A parent who was never
/// written to and a parent who has not replied look identical from the app, and
/// only one of them is somebody's fault.
async function notifyAwaitingParent(pool, { recipientId, accepterId, accepterName, delivered }) {
  await notify(pool, {
    recipientId,
    senderId: accepterId,
    title: 'Čeka se saglasnost roditelja',
    message: delivered
      ? `${accepterName} je prihvatio/la zahtev. Poslata je poruka roditelju — `
        + 'veza počinje kad roditelj potvrdi.'
      : `${accepterName} je prihvatio/la zahtev, ali poruka roditelju nije `
        + 'poslata. Veza čeka saglasnost.',
    kind: 'awaiting_parent',
  });
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
  await notify(pool, {
    recipientId,
    senderId: declinerId,
    title: 'Zahtev nije prihvaćen',
    message: `${declinerName} nije prihvatio vaš zahtev.`,
    kind: 'request_declined',
  });
}

module.exports = {
  acceptedTrainersOf,
  acceptedEdgeBetween,
  notifyAccept,
  notifyAwaitingParent,
  notifyDecline,
  requestRelationship,
  parentContactOf,
  pendingForUser,
  respondToRequest,
  listStudents,
  setVoiceLevel,
  listTrainers,
  removeRelationship,
  notifyRequest,
};
