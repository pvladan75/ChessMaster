// recordingShares.js — who may read a recorded lesson besides its host.
//
// Phase 5b.4 of docs/PLAN-SESIJA.md: a trainer records a lesson alone in
// Preparation and shares it with students, **in the app only** — no public
// link — and a student downloads the trainer's latest render while it exists
// (5b.5, the owner's answer of 22.9.2026).
//
// **A share reaches a student only while the relationship is accepted.** It is
// read through `acceptedTrainersOf`, like everything else a student sees
// because somebody teaches them: a relationship that ends closes every share
// without anybody deleting a row, and one that was never accepted never opens
// one. And it is written only by the host, only for their own accepted
// students (`trainerOwnsStudent`) — a group is ticked into people in the app,
// as with homework, so people are what is shared.

const { acceptedTrainersOf } = require('./relationshipService');
const { trainerOwnsStudent } = require('./assignmentService');
const { notify } = require('./notifications');

/// Whether [param] may read the recording `sr` — the one condition, written
/// once, used by the list and by the single read.
function readableBy(param) {
  return `(sr.host_id = ${param}
        OR ${param} = ANY(sr.participants)
        OR (EXISTS (SELECT 1 FROM recording_shares rs
                     WHERE rs.recording_id = sr.id AND rs.student_id = ${param})
            AND sr.host_id IN (${acceptedTrainersOf(param)})))`;
}

async function readableRecordings(pool, userId) {
  const result = await pool.query(
    // No `video_url`: it carries a token signed for the host, and this list is
    // read by students too. A reader asks for the one recording and gets a
    // link of their own (`recordingVideo.latestVideoFor`).
    `SELECT sr.id, sr.room_id, sr.source, sr.host_id, sr.title, sr.audio_url,
            sr.duration_ms, sr.created_at, u.name AS host_name
       FROM session_recordings sr
       LEFT JOIN users u ON sr.host_id = u.id
      WHERE ${readableBy('$1')}
      ORDER BY sr.created_at DESC`,
    [userId]
  );
  return result.rows;
}

/// The whole row, or null when [userId] may not read it — a 404 to the caller,
/// never a 403 that would say it exists.
async function readableRecording(pool, recordingId, userId) {
  const result = await pool.query(
    `SELECT sr.*, u.name AS host_name
       FROM session_recordings sr
       LEFT JOIN users u ON sr.host_id = u.id
      WHERE sr.id = $2 AND ${readableBy('$1')}`,
    [userId, recordingId]
  );
  return result.rows[0] || null;
}

/// The students a host has shared [recordingId] with, for the dialog's ticks.
async function sharedWith(pool, recordingId, hostId) {
  const result = await pool.query(
    `SELECT rs.student_id
       FROM recording_shares rs
       JOIN session_recordings sr ON sr.id = rs.recording_id
      WHERE rs.recording_id = $1 AND sr.host_id = $2
      ORDER BY rs.student_id`,
    [recordingId, hostId]
  );
  return result.rows.map((r) => r.student_id);
}

/// Replaces the list of students [recordingId] is shared with. The list is the
/// whole answer: a name left out is a share taken back. Refused whole when a
/// single id is not the host's accepted student — sharing with the valid half
/// would be a list the trainer never chose.
async function setShares(pool, { recordingId, hostId, studentIds, hostName = null }) {
  const ids = [...new Set((Array.isArray(studentIds) ? studentIds : []).map(Number))];
  if (!ids.every(Number.isInteger)) {
    return { ok: false, status: 400, error: 'The students could not be read.' };
  }
  const recording = await pool.query(
    'SELECT id, title, source FROM session_recordings WHERE id = $1 AND host_id = $2',
    [recordingId, hostId]
  );
  if (recording.rowCount === 0) {
    return { ok: false, status: 404, error: 'Recording not found.' };
  }
  // A lesson recorded alone in Preparation, and nothing else: an old room
  // recording is a lesson that had other people in it.
  if (recording.rows[0].source !== 'preparation') {
    return { ok: false, status: 403, error: 'Only a recording made in Preparation can be shared.' };
  }
  for (const id of ids) {
    if (!(await trainerOwnsStudent(pool, hostId, id))) {
      return { ok: false, status: 403, error: 'A recording is shared only with your own students.' };
    }
  }

  const client = await pool.connect();
  let added;
  try {
    await client.query('BEGIN');
    await client.query(
      'DELETE FROM recording_shares WHERE recording_id = $1 AND NOT (student_id = ANY($2::int[]))',
      [recordingId, ids]
    );
    const inserted = await client.query(
      `INSERT INTO recording_shares (recording_id, student_id)
       SELECT $1, unnest($2::int[])
       ON CONFLICT DO NOTHING
       RETURNING student_id`,
      [recordingId, ids]
    );
    await client.query('COMMIT');
    added = inserted.rows.map((r) => r.student_id).sort((a, b) => a - b);
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }

  // Told after the share exists, and only the new ones: a list saved twice is
  // not news twice.
  const title = recording.rows[0].title;
  for (const studentId of added) {
    await notify(pool, {
      recipientId: studentId,
      senderId: hostId,
      title: 'A recording',
      message: `${hostName || 'Your trainer'} shared a recording with you: ${title}`,
      kind: 'recording_shared',
      refId: recordingId,
    });
  }
  return { ok: true, added };
}

/// Deletes [recordingId] for its host, and for nobody else — a student it was
/// shared with reads it but does not own it. Its shares go with it
/// (`ON DELETE CASCADE`). Answers the deleted row's sound fields, so the
/// caller can remove the file too (`lessonRecording.soundOf`), or null — „not
/// found" to the caller, whether it never existed or belongs to somebody else.
async function deleteOwnRecording(pool, recordingId, hostId) {
  const id = Number(recordingId);
  if (!Number.isInteger(id)) return null;
  const result = await pool.query(
    `DELETE FROM session_recordings WHERE id = $1 AND host_id = $2
     RETURNING audio_file, audio_url`,
    [id, hostId]
  );
  return result.rows[0] || null;
}

module.exports = { deleteOwnRecording, readableRecording, readableRecordings, setShares, sharedWith };
