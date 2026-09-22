// positionDeletion.js — deleting a position of one's own (`custom_puzzles`).
//
// A sent homework does not copy its positions: every time a student opens an
// item, or a trainer sends a saved homework, the position is read from
// `custom_puzzles` by its id (`assignmentService.loadCustomPositions`,
// `homeworkTemplate`). So a position deleted from under a homework leaves an
// item nobody can open. The owner's rule of 22.9.2026: **a position cannot be
// deleted while a homework that is not finished holds it** — sent and not yet
// completed, or saved and not yet sent — and the trainer is told which.
//
// The rule is part of the DELETE itself, not a check before it: one statement,
// so a delete can never slip between a check and itself. What it cannot see is
// a send that read the position before the delete and writes its items after;
// that window is a send's own milliseconds, and the send reads the position
// again for every item it writes.

/// Homework that holds [puzzleId] and is not finished. `$1` the position,
/// `$2` its owner.
const OPEN_SENT = `
  SELECT a.id, COALESCE(p.title, a.title) AS title, u.name AS student
    FROM assignment_items ai
    JOIN assignments a ON a.id = ai.assignment_id
    LEFT JOIN assignments p ON p.id = a.parent_id
    LEFT JOIN users u ON u.id = a.student_id
   WHERE ai.puzzle_id = $1 AND a.trainer_id = $2
     AND (a.completed_at IS NULL OR (a.parent_id IS NOT NULL AND p.completed_at IS NULL))`;

const SAVED_PLAN = `
  SELECT h.id, h.title
    FROM homework_items hi
    JOIN homeworks h ON h.id = hi.homework_id
   WHERE h.trainer_id = $2 AND hi.kind = 'positions'
     AND hi.task -> 'puzzleIds' ? $1`;

/// Deletes the owner's position unless an unfinished homework holds it.
///
/// Answers `{ ok: true }`, `{ ok: false, status: 404 }` when there is no such
/// position of theirs, or `{ ok: false, status: 409, uses }` with every
/// homework that holds it: `{ kind: 'sent', title, student }` or
/// `{ kind: 'plan', title }`.
async function deleteOwnPosition(pool, { puzzleId, ownerId }) {
  const deleted = await pool.query(
    `DELETE FROM custom_puzzles
      WHERE puzzle_id = $1 AND owner_id = $2
        AND NOT EXISTS (${OPEN_SENT})
        AND NOT EXISTS (${SAVED_PLAN})
      RETURNING puzzle_id`,
    [puzzleId, ownerId]
  );
  if (deleted.rowCount > 0) return { ok: true };

  const owned = await pool.query(
    'SELECT 1 FROM custom_puzzles WHERE puzzle_id = $1 AND owner_id = $2',
    [puzzleId, ownerId]
  );
  if (owned.rowCount === 0) return { ok: false, status: 404 };

  const [sent, plans] = await Promise.all([
    pool.query(`${OPEN_SENT} ORDER BY a.id`, [puzzleId, ownerId]),
    pool.query(`${SAVED_PLAN} ORDER BY h.id`, [puzzleId, ownerId]),
  ]);
  const uses = [
    ...sent.rows.map((r) => ({ kind: 'sent', title: r.title, student: r.student })),
    ...plans.rows.map((r) => ({ kind: 'plan', title: r.title })),
  ];
  return { ok: false, status: 409, uses };
}

/// The sentence a trainer reads when the delete is refused.
function inUseMessage(uses) {
  const named = uses.slice(0, 3).map((u) =>
    u.kind === 'sent' ? `„${u.title}" (${u.student || 'a student'})` : `the saved homework „${u.title}"`
  );
  const more = uses.length > 3 ? ` and ${uses.length - 3} more` : '';
  return `This position is in homework that is not finished: ${named.join(', ')}${more}. ` +
    'It can be deleted once that homework is handed in, withdrawn or no longer holds it.';
}

module.exports = { deleteOwnPosition, inUseMessage };
