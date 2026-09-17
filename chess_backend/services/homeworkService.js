// homeworkService.js
//
// The rule behind a sent homework: when an item counts as passed, when it is
// locked, and when the whole homework is complete
// (docs/PLAN-DOMACI-ZADATAK.md, variant A, §6 and phase 1).
//
// **This file is the only home of that rule.** It is written as SQL fragments
// rather than as JavaScript over fetched rows because the same condition has
// to hold in two kinds of place: where a student's screen is told what is
// locked, and inside the UPDATE that records an answer — where a check made in
// JavaScript a moment earlier would be a second copy of the rule and a gap
// between asking and writing. Every reader and every guard interpolates these.
//
// The tests that prove it run against a real PostgreSQL
// (`test/homework_gate.test.js`), because a stub pool returns whatever it was
// given and cannot tell a correct WHERE clause from a wrong one.

const logger = require('./logger');
const { notify } = require('./notifications');

/// An item has **passed** when it is complete and, if the trainer asked for
/// „must be solved", nothing in it was answered wrongly or revealed.
///
/// „Complete" is the existing `completed_at`, written by `markCompleteIfDone`
/// when every item has been attempted — so by default a passed item is an
/// *attempted* one (owner, 17.9.2026). A reading step has `solved` NULL and
/// never fails this; a revealed step does, because being shown the answer is
/// not solving it.
function childPassedSql(alias) {
  return `(${alias}.completed_at IS NOT NULL AND (
    NOT ${alias}.require_solved OR NOT EXISTS (
      SELECT 1 FROM assignment_items gx
       WHERE gx.assignment_id = ${alias}.id
         AND (gx.solved = FALSE OR gx.revealed_at IS NOT NULL)
    )
  ))`;
}

/// An item is **locked** when it is a child with a gate that the trainer has
/// not opened, it is not already complete, and the item directly before it has
/// not passed.
///
/// „Directly before" is the sibling with the greatest smaller `position` —
/// positions are unique per parent (`idx_assignments_child_position`), so
/// there is exactly one, or none for the first item, whose gate therefore
/// never locks. A locked item further down is locked by the chain: its
/// predecessor is locked, so not complete, so not passed.
///
/// A complete item is never locked, whatever happened before it: work the
/// student has done does not disappear because the trainer changed a gate.
function childLockedSql(alias) {
  return `(${alias}.parent_id IS NOT NULL
    AND ${alias}.gate
    AND ${alias}.gate_opened_at IS NULL
    AND ${alias}.completed_at IS NULL
    AND EXISTS (
      SELECT 1 FROM assignments gp
       WHERE gp.parent_id = ${alias}.parent_id
         AND gp.position = (
           SELECT MAX(gq.position) FROM assignments gq
            WHERE gq.parent_id = ${alias}.parent_id
              AND gq.position < ${alias}.position
         )
         AND NOT ${childPassedSql('gp')}
    ))`;
}

/// The id of the item that holds [alias] locked — its direct predecessor — or
/// NULL. Only meaningful beside `childLockedSql`.
function blockedBySql(alias) {
  return `(SELECT gb.id FROM assignments gb
            WHERE gb.parent_id = ${alias}.parent_id
              AND gb.position < ${alias}.position
            ORDER BY gb.position DESC LIMIT 1)`;
}

/// The items of one sent homework, in order, with what the student's screen
/// needs to draw each: its progress, whether it has passed, whether it is
/// locked and by what.
async function childrenOf(pool, parentId) {
  const result = await pool.query(
    `SELECT c.id, c.title, c.kind, c.position, c.item_key, c.lesson_id,
            c.gate, c.require_solved, c.gate_opened_at, c.completed_at, c.task,
            COUNT(ai.id)::int AS total_items,
            COUNT(ai.attempted_at)::int AS attempted_items,
            COUNT(*) FILTER (WHERE ai.solved)::int AS solved_items,
            ${childPassedSql('c')} AS passed,
            ${childLockedSql('c')} AS locked,
            CASE WHEN ${childLockedSql('c')} THEN ${blockedBySql('c')} END AS blocked_by
       FROM assignments c
       LEFT JOIN assignment_items ai ON ai.assignment_id = c.id
      WHERE c.parent_id = $1
      GROUP BY c.id
      ORDER BY c.position`,
    [parentId]
  );
  return result.rows;
}

/// Whether one assignment is locked, and by which item. `{ locked: false }`
/// for anything that is not a gated child.
async function lockOf(pool, assignmentId) {
  const result = await pool.query(
    `SELECT ${childLockedSql('a')} AS locked, ${blockedBySql('a')} AS blocked_by
       FROM assignments a WHERE a.id = $1`,
    [assignmentId]
  );
  const row = result.rows[0];
  if (!row || !row.locked) return { locked: false, blockedBy: null };
  return { locked: true, blockedBy: row.blocked_by };
}

/// The trainer opens one locked item for the student it was sent to.
///
/// Written only by the trainer who set it, and only on a child — a gate that
/// is not a gate has nothing to open. Returns whether a row moved.
async function openGate(pool, { assignmentId, trainerId }) {
  const result = await pool.query(
    `UPDATE assignments
        SET gate_opened_at = CURRENT_TIMESTAMP
      WHERE id = $1 AND trainer_id = $2
        AND parent_id IS NOT NULL
        AND gate_opened_at IS NULL
      RETURNING id`,
    [assignmentId, trainerId]
  );
  return result.rows.length > 0;
}

/// Stamps a sent homework complete once its last item is.
///
/// Called by `markCompleteIfDone` right after a child finishes, which is the
/// only moment a parent can become complete. `EXISTS` a child is what stops an
/// empty homework from completing vacuously; `completed_at IS NULL` is what
/// makes the notice go out once.
async function markHomeworkCompleteIfDone(pool, parentId) {
  const done = await pool.query(
    `WITH finished AS (
       UPDATE assignments p SET completed_at = CURRENT_TIMESTAMP
        WHERE p.id = $1 AND p.kind = 'homework' AND p.completed_at IS NULL
          AND EXISTS (SELECT 1 FROM assignments c WHERE c.parent_id = p.id)
          AND NOT EXISTS (
            SELECT 1 FROM assignments c
             WHERE c.parent_id = p.id AND c.completed_at IS NULL
          )
       RETURNING p.id, p.trainer_id, p.student_id, p.title
     )
     SELECT f.id, f.trainer_id, f.student_id, f.title, u.name AS student_name
       FROM finished f LEFT JOIN users u ON u.id = f.student_id`,
    [parentId]
  );
  if (done.rows.length === 0) return null;

  const row = done.rows[0];
  try {
    await notify(pool, {
      recipientId: row.trainer_id,
      senderId: row.student_id,
      title: 'Homework completed',
      message: `${row.student_name || 'Student'} completed the homework: ${row.title}`,
      kind: 'assignment_done',
      refId: row.id,
    });
  } catch (err) {
    // The stamp is the fact; the notice only reports it.
    logger.error({ parentId }, `Homework completion notice failed: ${err.message}`);
  }
  return row;
}

/// Withdraws an assignment the trainer set.
///
/// A child cannot be withdrawn on its own: the homework it belongs to could
/// then never complete, and its gate chain would point at a hole. The trainer
/// withdraws the homework, and the cascade takes its items with it.
///
/// Returns `'ok'`, `'child'` or `'not_found'` (which also covers „not yours",
/// so a guessed id tells nobody which assignments exist).
async function withdrawAssignment(pool, { assignmentId, trainerId }) {
  const result = await pool.query(
    `DELETE FROM assignments
      WHERE id = $1 AND trainer_id = $2 AND parent_id IS NULL
      RETURNING id`,
    [assignmentId, trainerId]
  );
  if (result.rows.length > 0) return 'ok';

  const child = await pool.query(
    'SELECT 1 FROM assignments WHERE id = $1 AND trainer_id = $2 AND parent_id IS NOT NULL',
    [assignmentId, trainerId]
  );
  return child.rows.length > 0 ? 'child' : 'not_found';
}

module.exports = {
  childPassedSql,
  childLockedSql,
  childrenOf,
  lockOf,
  openGate,
  markHomeworkCompleteIfDone,
  withdrawAssignment,
};
