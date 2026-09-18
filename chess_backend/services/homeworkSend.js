// homeworkSend.js
//
// Sending a homework (docs/PLAN-DOMACI-ZADATAK.md §4 variant A, phase 4).
// Writing one and sending it are two acts, by the owner's rule; this is the
// second. It copies the template into `assignments`: one parent of
// `kind = 'homework'` per student, and one ordinary assignment per item under
// it, with that item's content resolved **now, for that student**.
//
// Three things it is careful about:
//
//   * **One transaction.** A parent with some of its items is a homework whose
//     gate chain points at a hole and which can never complete. Either the
//     whole homework lands or nothing does.
//   * **Resolved per student, at send time.** A puzzle set excludes puzzles
//     *this* student already attempted (`resolvePuzzles`), and a tutorial's
//     steps are snapshotted, exactly as the older send paths do — an edit to
//     the tutorial afterwards must not shift a half-finished assignment.
//   * **One notice.** The student is told about the homework, not about each
//     of its items; the trainer hears once when the last item lands
//     (`homeworkService.markHomeworkCompleteIfDone`).
//
// Quota: one unit per student per homework, whatever it holds (owner,
// 17.9.2026). That is enforced by the route, which takes exactly one student
// per request — the dialog sends one request per student it was given, so
// three students cost three units and a five-item homework costs one.

const logger = require('./logger');
const assignments = require('./assignmentService');
const { loadHomework } = require('./homeworkTemplate');
const { assignableProblem, exerciseColumns } = require('./exercise');

/// What each kind of item becomes as an assignment of its own.
const CHILD_KIND = {
  lesson: 'lesson',
  positions: 'puzzles',
  puzzles: 'puzzles',
  engine_game: 'engine_game',
};

/// A short name for one item, so a student's list reads as sentences rather
/// than as „item 3". The homework's own title is the parent's.
function childTitle(item, { lessonTitle = null, itemCount = 0 } = {}) {
  switch (item.kind) {
    case 'lesson':
      return lessonTitle || 'Tutorial';
    case 'positions':
      return itemCount === 1 ? 'One position' : `${itemCount} positions`;
    case 'puzzles':
      return itemCount === 1 ? 'One puzzle' : `${itemCount} puzzles`;
    case 'engine_game': {
      const goal = item.task.goal === 'win'
        ? 'win it'
        : item.task.goal === 'hold'
          ? 'hold the draw'
          : `survive ${item.task.surviveMoves} moves`;
      return `Play it out: ${goal}`;
    }
    default:
      return 'Item';
  }
}

/// Refused loudly, with what to tell the trainer. Nothing is written when one
/// of these is raised — it is raised before the transaction opens.
class SendRefused extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

/// Works out what every item's assignment will hold, before anything is
/// written. Each entry is `{ item, childKind, title, lessonId, itemRows }`
/// where `itemRows` are the `assignment_items` to insert.
async function planItems(pool, { trainerId, studentId, items }) {
  const planned = [];
  for (const item of items) {
    switch (item.kind) {
      case 'lesson': {
        const lesson = await assignments.loadAssignableLesson(pool, trainerId, item.task.lessonId);
        if (!lesson) {
          throw new SendRefused(422, `A tutorial in this homework is no longer yours.`);
        }
        if (lesson.steps.length === 0) {
          throw new SendRefused(422, `The tutorial "${lesson.title}" has no parts.`);
        }
        planned.push({
          item,
          childKind: 'lesson',
          title: childTitle(item, { lessonTitle: lesson.title }),
          lessonId: lesson.id,
          // `position` orders, `step_key` says which step it is — the bridge to
          // the student's own schedule, and the reason an edited tutorial does
          // not re-aim a half-finished assignment.
          itemRows: lesson.steps.map((step, index) => ({
            position: index,
            stepKey: step.id,
            puzzleId: null,
            rating: null,
          })),
        });
        break;
      }
      case 'positions': {
        const found = await pool.query(
          `SELECT puzzle_id, ${exerciseColumns()} FROM custom_puzzles
            WHERE owner_id = $1 AND puzzle_id = ANY($2::varchar[])`,
          [trainerId, item.task.puzzleIds]
        );
        const byId = new Map(found.rows.map((row) => [row.puzzle_id, row]));
        for (const id of item.task.puzzleIds) {
          const row = byId.get(id);
          // Checked again here, not only when the homework was written: a
          // position can be edited or marked for review in between, and a
          // position with no solution cannot be judged in front of a student.
          if (!row) throw new SendRefused(422, `A position in this homework is no longer yours.`);
          const problem = assignableProblem(row);
          if (problem) throw new SendRefused(422, `A position in this homework ${problem}.`);
        }
        planned.push({
          item,
          childKind: 'puzzles',
          title: childTitle(item, { itemCount: item.task.puzzleIds.length }),
          lessonId: null,
          itemRows: item.task.puzzleIds.map((id, index) => ({
            position: index,
            stepKey: null,
            puzzleId: id,
            rating: null,
          })),
        });
        break;
      }
      case 'puzzles': {
        const puzzles = await assignments.resolvePuzzles(pool, {
          studentId,
          themes: item.task.themes,
          minRating: item.task.minRating,
          maxRating: item.task.maxRating,
          count: item.task.count,
        });
        if (puzzles.length === 0) {
          throw new SendRefused(422, 'No puzzles match one of this homework\'s sets.');
        }
        planned.push({
          item,
          childKind: 'puzzles',
          title: childTitle(item, { itemCount: puzzles.length }),
          lessonId: null,
          itemRows: puzzles.map((puzzle, index) => ({
            position: index,
            stepKey: null,
            puzzleId: puzzle.puzzle_id,
            rating: puzzle.rating,
          })),
        });
        break;
      }
      case 'engine_game': {
        planned.push({
          item,
          childKind: 'engine_game',
          title: childTitle(item),
          lessonId: null,
          // One row, so the item completes the moment the game is recorded
          // (`recordEngineGameResult` writes it, `markCompleteIfDone` reads it).
          itemRows: [{ position: 0, stepKey: 'game', puzzleId: null, rating: null }],
        });
        break;
      }
      default:
        throw new SendRefused(400, `A homework item of an unknown kind cannot be sent.`);
    }
  }
  return planned;
}

/// Sends one homework to one student.
///
/// Returns `{ ok: true, assignment }` — the parent, with its children — or
/// `{ ok: false, status, error }`. Nothing is written on any refusal, which is
/// what lets the route hand the quota unit back.
async function sendHomework(pool, { trainerId, studentId, homeworkId, dueAt = null, note = null }) {
  if (!(await assignments.trainerOwnsStudent(pool, trainerId, studentId))) {
    return { ok: false, status: 403, error: 'That student is not on your list.' };
  }
  const homework = await loadHomework(pool, homeworkId, trainerId);
  if (!homework) return { ok: false, status: 404, error: 'Homework not found.' };
  if (homework.items.length === 0) {
    return { ok: false, status: 422, error: 'This homework has no items yet.' };
  }

  let planned;
  try {
    planned = await planItems(pool, { trainerId, studentId, items: homework.items });
  } catch (err) {
    if (err instanceof SendRefused) return { ok: false, status: err.status, error: err.message };
    throw err;
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const parentRes = await client.query(
      `INSERT INTO assignments
         (trainer_id, student_id, title, instructions, kind, homework_id, due_at)
       VALUES ($1, $2, $3, $4, 'homework', $5, $6)
       RETURNING *`,
      [trainerId, studentId, homework.title, note || homework.instructions, homeworkId, dueAt]
    );
    const parent = parentRes.rows[0];

    const children = [];
    for (const plan of planned) {
      const { item } = plan;
      const childRes = await client.query(
        `INSERT INTO assignments
           (trainer_id, student_id, title, kind, parent_id, position, item_key,
            gate, require_solved, task, lesson_id, themes, min_rating, max_rating)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10::jsonb, $11, $12, $13, $14)
         RETURNING *`,
        [
          trainerId,
          studentId,
          plan.title,
          plan.childKind,
          parent.id,
          item.position,
          item.item_key,
          item.gate,
          item.require_solved,
          item.kind === 'engine_game' ? JSON.stringify(item.task) : null,
          plan.lessonId,
          item.kind === 'puzzles' ? item.task.themes : [],
          item.kind === 'puzzles' ? item.task.minRating : null,
          item.kind === 'puzzles' ? item.task.maxRating : null,
        ]
      );
      const child = childRes.rows[0];

      const values = [];
      const tuples = plan.itemRows.map((row, index) => {
        const base = index * 5;
        values.push(child.id, row.position, row.stepKey, row.puzzleId, row.rating);
        return `($${base + 1}, $${base + 2}, $${base + 3}, $${base + 4}, $${base + 5})`;
      });
      await client.query(
        `INSERT INTO assignment_items
           (assignment_id, position, step_key, puzzle_id, puzzle_rating)
         VALUES ${tuples.join(', ')}`,
        values
      );
      children.push({ ...child, itemCount: plan.itemRows.length });
    }

    await client.query('COMMIT');
    logger.info(
      { trainerId, studentId, homeworkId, assignmentId: parent.id, items: children.length },
      'Homework sent'
    );
    return { ok: true, assignment: { ...parent, children } };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

module.exports = { sendHomework, childTitle, CHILD_KIND };
