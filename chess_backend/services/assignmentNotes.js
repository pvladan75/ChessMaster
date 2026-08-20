// assignmentNotes.js — writing into the conversation about one assignment.
//
// One table, `assignment_notes`, holds all four things that were once going to
// be four columns: the trainer on the assignment, the student on the
// assignment, the trainer on a position, the student on a position. `item_id`
// says which position, or NULL for the whole assignment; the author comes from
// the account.
//
// The point of the student half is the thing numbers cannot say. "Ovu nisam
// razumeo" tells a trainer exactly what an accuracy percentage never will.

const { assignmentParticipant } = require('./assignmentService');

const MAX_BODY = 2000;

/// Adds one note, if the writer is one of the two people this assignment is
/// between.
///
/// Returns `{ ok: true, note }` or `{ ok: false, status, error }`.
async function addNote(pool, { assignmentId, itemId = null, authorId, body }) {
  const text = typeof body === 'string' ? body.trim() : '';
  if (text === '') {
    return { ok: false, status: 400, error: 'Poruka ne može biti prazna.' };
  }

  const access = await assignmentParticipant(pool, assignmentId, authorId);
  if (!access) {
    // Same answer as for an assignment that does not exist: an id typed by hand
    // must not reveal which ones are real.
    return { ok: false, status: 404, error: 'Zadatak nije pronađen.' };
  }

  // A note about a position has to be about a position *in this assignment*.
  // Without this check an item id from someone else's homework would attach
  // here, and the note would read as being about a board it is not about.
  if (itemId !== null && itemId !== undefined) {
    const item = await pool.query(
      'SELECT 1 FROM assignment_items WHERE id = $1 AND assignment_id = $2',
      [itemId, assignmentId]
    );
    if (item.rowCount === 0) {
      return { ok: false, status: 400, error: 'Ta pozicija nije deo ovog zadatka.' };
    }
  }

  const inserted = await pool.query(
    `INSERT INTO assignment_notes (assignment_id, item_id, author_id, body)
     VALUES ($1, $2, $3, $4)
     RETURNING id, item_id, author_id, body, created_at`,
    [assignmentId, itemId ?? null, authorId, text.slice(0, MAX_BODY)]
  );

  const row = inserted.rows[0];
  const { assignment, isTrainer } = access;
  return {
    ok: true,
    // Who is on the other end of this note, and what it is about. Worked out
    // here because the access check above already read both sides of the
    // assignment; the route would have to ask the database again.
    recipientId: isTrainer ? assignment.student_id : assignment.trainer_id,
    assignmentTitle: assignment.title,
    note: {
      id: row.id,
      itemId: row.item_id,
      authorId: row.author_id,
      mine: true,
      body: row.body,
      createdAt: row.created_at,
    },
  };
}

/// Removes a note. Only its author may, and only from the assignment it is on.
///
/// A child who wrote something they regret should be able to take it back; a
/// trainer deleting the child's words, or the other way round, is a different
/// thing entirely and is not offered.
async function deleteNote(pool, { assignmentId, noteId, authorId }) {
  const result = await pool.query(
    `DELETE FROM assignment_notes
      WHERE id = $1 AND assignment_id = $2 AND author_id = $3
      RETURNING id`,
    [noteId, assignmentId, authorId]
  );
  if (result.rows.length === 0) {
    return { ok: false, status: 404, error: 'Poruka nije pronađena ili nije vaša.' };
  }
  return { ok: true };
}

module.exports = { addNote, deleteNote, MAX_BODY };
