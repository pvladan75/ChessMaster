// trainerPanelService.js — what a trainer's day looks like, in one answer.
//
// The panel replaces "open the app and go looking": today's lessons, homework
// about to run out of time, work that has been handed in, and the students who
// have gone quiet. Four questions that were each answerable already, but only
// by opening four screens and knowing which to open.
//
// Everything here is read-only and scoped to `trainerId`. The student list is
// built from `acceptedStudentsOf` rather than from a hand-written subquery, for
// the reason written above that fragment: every copy of the condition so far
// has forgotten `status`, and a forgotten status puts somebody who never
// answered into a list the trainer then acts on.

const { acceptedStudentsOf } = require('./relationshipService');

/// How long a student may be silent before the panel says so.
const IDLE_DAYS = 7;

/// How far ahead homework counts as "running out".
const DUE_SOON_HOURS = 48;

/// How long homework may sit without a single move before it is standing still.
///
/// Shorter than [IDLE_DAYS] on purpose: a student who was given something and
/// has not touched it is a smaller silence than a student nobody has heard from
/// at all, and it is answerable sooner.
const STALLED_DAYS = 3;

/// How many rows any one section may return.
///
/// A trainer with forty students would otherwise get forty cards in a section
/// meant to be read at a glance, and the useful ones are the oldest — which is
/// what each ORDER BY puts first.
const SECTION_LIMIT = 20;

/// Lessons this trainer is hosting today.
///
/// The window starts two hours back rather than at `now()`: a lesson at 17:00
/// is the one thing the trainer wants at 17:20, and a card that disappears the
/// moment the lesson begins is a card that vanishes exactly when it is needed.
///
/// `scheduled_sessions.scheduled_at` is a bare TIMESTAMP while `now()` carries
/// a zone, so the comparison happens in the database session's timezone. That
/// is the same timezone the row was written in, which is why "today" here means
/// what the trainer meant when they scheduled it.
async function todaysLessons(pool, trainerId, { limit = SECTION_LIMIT } = {}) {
  const result = await pool.query(
    `SELECT s.id,
            s.room_code,
            s.title,
            s.description,
            s.scheduled_at,
            COALESCE(
              ARRAY_AGG(u.name ORDER BY u.name) FILTER (WHERE u.id IS NOT NULL),
              '{}'
            ) AS guests
       FROM scheduled_sessions s
       LEFT JOIN scheduled_session_invites i
         ON i.session_id = s.id AND i.status <> 'declined'
       LEFT JOIN users u ON u.id = i.user_id
      WHERE s.host_id = $1
        AND s.scheduled_at >= now() - interval '2 hours'
        AND s.scheduled_at < date_trunc('day', now()) + interval '1 day'
      GROUP BY s.id
      ORDER BY s.scheduled_at ASC
      LIMIT $2`,
    [trainerId, limit]
  );
  return result.rows;
}

/// Homework that is about to run out of time, or already has.
///
/// Overdue work is included rather than dropped — the deadline passing is when
/// the trainer most needs to see it, and a card that disappears at midnight
/// takes the reminder with it.
async function dueSoon(pool, trainerId, { hours = DUE_SOON_HOURS, limit = SECTION_LIMIT } = {}) {
  const result = await pool.query(
    `SELECT a.id,
            a.title,
            a.kind,
            a.due_at,
            u.id   AS student_id,
            u.name AS student_name,
            COUNT(ai.id)::int                       AS total_items,
            COUNT(ai.attempted_at)::int             AS attempted_items
       FROM assignments a
       JOIN users u ON u.id = a.student_id
       LEFT JOIN assignment_items ai ON ai.assignment_id = a.id
      WHERE a.trainer_id = $1
        AND a.completed_at IS NULL
        AND a.due_at IS NOT NULL
        AND a.due_at < now() + make_interval(hours => $2)
      GROUP BY a.id, u.id, u.name
      ORDER BY a.due_at ASC
      LIMIT $3`,
    [trainerId, hours, limit]
  );
  return result.rows;
}

/// Finished homework the trainer has not looked at yet.
///
/// This is the half of the count that can actually reach zero: `completed_at`
/// is written by the student finishing, `reviewed_at` by the trainer opening
/// the review. Without the second one the badge would only ever grow.
async function awaitingReview(pool, trainerId, { limit = SECTION_LIMIT } = {}) {
  const result = await pool.query(
    `SELECT a.id,
            a.title,
            a.kind,
            a.completed_at,
            u.id   AS student_id,
            u.name AS student_name,
            COUNT(ai.id)::int                        AS total_items,
            COUNT(*) FILTER (WHERE ai.solved)::int   AS solved_items
       FROM assignments a
       JOIN users u ON u.id = a.student_id
       LEFT JOIN assignment_items ai ON ai.assignment_id = a.id
      WHERE a.trainer_id = $1
        AND a.completed_at IS NOT NULL
        AND a.reviewed_at IS NULL
      GROUP BY a.id, u.id, u.name
      ORDER BY a.completed_at ASC
      LIMIT $2`,
    [trainerId, limit]
  );
  return result.rows;
}

/// Homework that has stopped moving.
///
/// The section exists because of a hole the first version left: an assignment
/// with **no deadline** appeared nowhere at all, and one that stalled halfway
/// disappeared from "Nije vežbao" the moment the student solved their first
/// puzzle. Both are the same fact — work was set and it is not progressing —
/// and neither is visible from a deadline.
///
/// Deliberately not filtered to untouched work: 8 of 10, four days ago, is
/// exactly the shape a trainer needs to see, and "not started" is only its
/// first case. `GREATEST` ignores nulls, so an assignment nobody has opened
/// dates from when it was set.
///
/// Assignments already in [dueSoon] are excluded by the complement of that
/// window, so no assignment can appear in both sections and no student is
/// counted twice on one screen.
async function stalled(
  pool,
  trainerId,
  { days = STALLED_DAYS, dueHours = DUE_SOON_HOURS, limit = SECTION_LIMIT } = {}
) {
  const result = await pool.query(
    `SELECT a.id,
            a.title,
            a.kind,
            a.due_at,
            a.created_at,
            u.id   AS student_id,
            u.name AS student_name,
            COUNT(ai.id)::int             AS total_items,
            COUNT(ai.attempted_at)::int   AS attempted_items,
            GREATEST(a.created_at, MAX(ai.attempted_at)) AS last_move_at
       FROM assignments a
       JOIN users u ON u.id = a.student_id
       LEFT JOIN assignment_items ai ON ai.assignment_id = a.id
      WHERE a.trainer_id = $1
        AND a.completed_at IS NULL
        AND (a.due_at IS NULL OR a.due_at >= now() + make_interval(hours => $2))
      GROUP BY a.id, u.id, u.name
     HAVING GREATEST(a.created_at, MAX(ai.attempted_at))
              < now() - make_interval(days => $3)
      ORDER BY GREATEST(a.created_at, MAX(ai.attempted_at)) ASC
      LIMIT $4`,
    [trainerId, dueHours, days, limit]
  );
  return result.rows;
}

/// Students who have not solved anything for a while.
///
/// A student who has never attempted a puzzle sorts first, not last: they are
/// the ones nothing else on this screen would ever mention, since every other
/// section is driven by something they did.
///
/// A student with homework still open is left out: the useful sentence about
/// them is which assignment is standing still, not that they are quiet, and
/// they are already in [stalled] or [dueSoon]. One person, one row, one thing
/// to do about it — the alternative is a trainer reading the same name three
/// times and choosing between three buttons that mean the same thing.
async function idleStudents(pool, trainerId, { days = IDLE_DAYS, limit = SECTION_LIMIT } = {}) {
  const result = await pool.query(
    `SELECT u.id,
            u.name,
            MAX(p.created_at) AS last_active_at
       FROM users u
       LEFT JOIN user_puzzle_attempts p ON p.user_id = u.id
      WHERE u.id IN (${acceptedStudentsOf('$1')})
        AND NOT EXISTS (
          SELECT 1 FROM assignments a
           WHERE a.student_id = u.id
             AND a.trainer_id = $1
             AND a.completed_at IS NULL
        )
      GROUP BY u.id, u.name
     HAVING MAX(p.created_at) IS NULL
         OR MAX(p.created_at) < now() - make_interval(days => $2)
      ORDER BY MAX(p.created_at) ASC NULLS FIRST
      LIMIT $3`,
    [trainerId, days, limit]
  );
  return result.rows;
}

/// Requests waiting for this user to answer.
///
/// Counted, not listed: the rows themselves are already on this tab, and the
/// number is here so the badge and the panel cannot disagree about how much is
/// waiting. The condition is `pendingForUser`'s, kept in step with it: only
/// what somebody else started, and only while it is still pending.
async function pendingRequestCount(pool, userId) {
  const result = await pool.query(
    `SELECT COUNT(*)::int AS count
       FROM trainer_students
      WHERE status = 'pending'
        AND initiated_by <> $1
        AND $1 IN (trainer_id, student_id)`,
    [userId]
  );
  return result.rows[0]?.count ?? 0;
}

/// The whole panel, in one round trip.
///
/// The sections are gathered in parallel because none of them reads what
/// another writes, and a panel that costs four sequential round trips is a
/// panel that shows up after the trainer has already tapped past it.
///
/// `waiting` is the number the tab badge shows. It counts only the two things
/// the trainer can clear by acting — homework they have not opened, and
/// requests they have not answered. Deadlines and quiet students are on the
/// screen but not in the number: neither is cleared by the trainer doing
/// anything, so counting them would leave a badge that never reaches zero.
async function trainerPanel(pool, userId) {
  const [today, due, review, standing, idle, requests] = await Promise.all([
    todaysLessons(pool, userId),
    dueSoon(pool, userId),
    awaitingReview(pool, userId),
    stalled(pool, userId),
    idleStudents(pool, userId),
    pendingRequestCount(pool, userId),
  ]);

  return {
    today,
    dueSoon: due,
    awaitingReview: review,
    stalled: standing,
    idle,
    counts: {
      awaitingReview: review.length,
      requests,
      waiting: review.length + requests,
    },
  };
}

/// Marks a finished assignment as looked at.
///
/// Written by the trainer opening the review, and only by them: a student
/// reading their own feedback must not empty the trainer's queue. The whole
/// rule sits in the WHERE clause rather than in a check before it, so there is
/// no gap between asking and writing.
///
/// Returns whether a row moved, which is also the honest answer to "was this
/// yours" — a foreign id and an already-reviewed one both simply write nothing.
async function markReviewed(pool, { assignmentId, trainerId }) {
  const result = await pool.query(
    `UPDATE assignments
        SET reviewed_at = CURRENT_TIMESTAMP
      WHERE id = $1
        AND trainer_id = $2
        AND completed_at IS NOT NULL
        AND reviewed_at IS NULL
      RETURNING id`,
    [assignmentId, trainerId]
  );
  return result.rows.length > 0;
}

module.exports = {
  IDLE_DAYS,
  DUE_SOON_HOURS,
  STALLED_DAYS,
  SECTION_LIMIT,
  todaysLessons,
  dueSoon,
  awaitingReview,
  stalled,
  idleStudents,
  pendingRequestCount,
  trainerPanel,
  markReviewed,
};
