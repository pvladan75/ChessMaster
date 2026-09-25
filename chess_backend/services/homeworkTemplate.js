// homeworkTemplate.js
//
// The homework a trainer writes and keeps — the template half of variant A
// (docs/PLAN-DOMACI-ZADATAK.md §4 and §7, phase 3). Sending it is a different
// act and a different table; nothing here touches `assignments`, and editing a
// homework changes nothing a student already has.
//
// **An item's key is minted, never its index.** `position` orders the list and
// nothing else: a trainer who drags the third item to the front must not
// re-aim anything, and the one thing that could be re-aimed is an item that a
// sent copy points back at (`assignments.item_key`). This is the lesson
// `assignment_items.step_key` and `review_items.step_key` were both migrated
// for (both since dropped, with phase 2 of docs/PLAN-TUTORIJAL-VIDEO.md); the
// third time it is designed in rather than repaired.

const crypto = require('crypto');

const logger = require('./logger');
const { parseEngineGameTask } = require('./engineGameTask');
const { assignableProblem, exerciseColumns } = require('./exercise');
const { trainableThemes } = require('./puzzleSelectionService');

const KINDS = ['lesson', 'positions', 'puzzles', 'engine_game'];
const MAX_ITEMS = 20;
const MAX_TITLE = 255;

/// A key that is not an index and not guessable from one. Eight base-36
/// characters fit `VARCHAR(16)` with room to spare.
function mintItemKey() {
  return `i${crypto.randomBytes(5).toString('hex').slice(0, 8)}`;
}

/// Reads one item of a homework, or says why it is not one.
///
/// The task is validated **per kind**, because an item whose task the sender
/// cannot act on is a homework that breaks when it is sent, one screen away
/// from the trainer who wrote it. `engine_game` is read by the same
/// `parseEngineGameTask` the server judges a played game with, so a position
/// that cannot be played is refused here rather than at the board.
function parseItem(raw, { index }) {
  const where = `item ${index + 1}`;
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return { ok: false, error: `${where} is not an item.` };
  }
  if (!KINDS.includes(raw.kind)) {
    return { ok: false, error: `${where}: the kind must be one of ${KINDS.join(', ')}.` };
  }
  const task = raw.task && typeof raw.task === 'object' && !Array.isArray(raw.task)
    ? raw.task
    : {};

  let cleanTask;
  switch (raw.kind) {
    case 'lesson': {
      const lessonId = Number.parseInt(task.lessonId, 10);
      if (!Number.isInteger(lessonId)) {
        return { ok: false, error: `${where}: a tutorial item needs a tutorial.` };
      }
      cleanTask = { lessonId };
      break;
    }
    case 'positions': {
      const ids = Array.isArray(task.puzzleIds)
        ? task.puzzleIds.filter((id) => typeof id === 'string' && id.trim())
        : [];
      if (ids.length === 0) {
        return { ok: false, error: `${where}: a positions item needs at least one position.` };
      }
      cleanTask = { puzzleIds: ids };
      break;
    }
    case 'puzzles': {
      const count = Number.parseInt(task.count, 10);
      if (!Number.isInteger(count) || count < 1 || count > 50) {
        return { ok: false, error: `${where}: a puzzle set needs a count from 1 to 50.` };
      }
      const themes = trainableThemes(Array.isArray(task.themes) ? task.themes : []);
      const min = task.minRating === undefined || task.minRating === null
        ? null
        : Number.parseInt(task.minRating, 10);
      const max = task.maxRating === undefined || task.maxRating === null
        ? null
        : Number.parseInt(task.maxRating, 10);
      if ((min !== null && !Number.isInteger(min)) || (max !== null && !Number.isInteger(max))) {
        return { ok: false, error: `${where}: the rating range is not a range.` };
      }
      if (min !== null && max !== null && min > max) {
        return { ok: false, error: `${where}: the rating range runs backwards.` };
      }
      cleanTask = { themes, count, minRating: min, maxRating: max };
      break;
    }
    case 'engine_game': {
      const parsed = parseEngineGameTask(task);
      if (!parsed.ok) return { ok: false, error: `${where}: ${parsed.error}` };
      cleanTask = parsed.task;
      break;
    }
    default:
      return { ok: false, error: `${where}: unknown kind.` };
  }

  // A key the client sends back is an item that already exists; anything else
  // is new. Never trusted as an identity on its own — `saveHomework` keeps only
  // keys the homework really holds.
  const itemKey = typeof raw.itemKey === 'string' && /^[a-z0-9]{2,16}$/i.test(raw.itemKey)
    ? raw.itemKey
    : null;

  return {
    ok: true,
    item: {
      itemKey,
      kind: raw.kind,
      task: cleanTask,
      gate: raw.gate === true,
    },
  };
}

/// Reads a whole homework as the editor sends it.
function parseHomework(raw) {
  if (!raw || typeof raw !== 'object') return { ok: false, error: 'Nothing to save.' };
  const title = typeof raw.title === 'string' ? raw.title.trim() : '';
  if (!title) return { ok: false, error: 'A homework needs a title.' };
  if (title.length > MAX_TITLE) return { ok: false, error: 'That title is too long.' };
  const instructions = typeof raw.instructions === 'string' && raw.instructions.trim()
    ? raw.instructions.trim()
    : null;

  const rawItems = Array.isArray(raw.items) ? raw.items : [];
  if (rawItems.length > MAX_ITEMS) {
    return { ok: false, error: `A homework holds at most ${MAX_ITEMS} items.` };
  }
  const items = [];
  for (const [index, rawItem] of rawItems.entries()) {
    const parsed = parseItem(rawItem, { index });
    if (!parsed.ok) return parsed;
    items.push(parsed.item);
  }
  // Two items claiming one key would each overwrite the other's row.
  const keys = items.map((i) => i.itemKey).filter(Boolean);
  if (new Set(keys).size !== keys.length) {
    return { ok: false, error: 'Two items claim the same key.' };
  }

  return { ok: true, homework: { title, instructions, items } };
}

/// What the trainer's items point at has to be theirs, and usable.
///
/// Checked at authoring time rather than at sending time: a tutorial that is
/// not yours, or a position with no solution, is a homework that would break
/// one screen away from the person who wrote it. The same two rules the send
/// paths already keep (`loadAssignableLesson`, `assignableProblem`).
async function contentProblem(pool, trainerId, items) {
  const lessonIds = items.filter((i) => i.kind === 'lesson').map((i) => i.task.lessonId);
  if (lessonIds.length > 0) {
    const found = await pool.query(
      `SELECT id FROM saved_lessons
        WHERE id = ANY($1::int[]) AND (user_id = $2 OR trainer_id = $2)`,
      [lessonIds, trainerId]
    );
    const mine = new Set(found.rows.map((r) => r.id));
    const missing = lessonIds.find((id) => !mine.has(id));
    if (missing !== undefined) return `Tutorial ${missing} is not yours.`;
  }

  const puzzleIds = items
    .filter((i) => i.kind === 'positions')
    .flatMap((i) => i.task.puzzleIds);
  if (puzzleIds.length > 0) {
    const found = await pool.query(
      `SELECT puzzle_id, ${exerciseColumns()} FROM custom_puzzles
        WHERE owner_id = $1 AND puzzle_id = ANY($2::varchar[])`,
      [trainerId, puzzleIds]
    );
    const byId = new Map(found.rows.map((r) => [r.puzzle_id, r]));
    for (const id of puzzleIds) {
      const row = byId.get(id);
      if (!row) return `Position ${id} is not yours.`;
      const problem = assignableProblem(row);
      if (problem) return `Position ${id} ${problem}.`;
    }
  }
  return null;
}

/// Creates or replaces a homework and its items, in one transaction.
///
/// The items arrive as the list the editor shows, in order. An item that comes
/// back with a key it really has keeps that key and its history; an item with
/// no key is new and gets one minted; an item the editor did not send is gone.
/// `position` is then simply the index in the list — it orders and nothing
/// else, so a reorder rewrites positions and no keys.
async function saveHomework(pool, { trainerId, homeworkId = null, payload }) {
  const parsed = parseHomework(payload);
  if (!parsed.ok) return { ok: false, status: 400, error: parsed.error };
  const { title, instructions, items } = parsed.homework;

  const problem = await contentProblem(pool, trainerId, items);
  if (problem) return { ok: false, status: 422, error: problem };

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    let id = homeworkId;
    if (id === null) {
      const created = await client.query(
        `INSERT INTO homeworks (trainer_id, title, instructions)
         VALUES ($1, $2, $3) RETURNING id`,
        [trainerId, title, instructions]
      );
      id = created.rows[0].id;
    } else {
      const updated = await client.query(
        `UPDATE homeworks SET title = $3, instructions = $4,
                              updated_at = CURRENT_TIMESTAMP
          WHERE id = $1 AND trainer_id = $2 RETURNING id`,
        [id, trainerId, title, instructions]
      );
      if (updated.rows.length === 0) {
        await client.query('ROLLBACK');
        return { ok: false, status: 404, error: 'No such homework.' };
      }
    }

    // Which keys this homework really holds. A key the client invented, or one
    // belonging to another homework, is treated as a new item rather than
    // silently writing over somebody else's row.
    const existing = await client.query(
      'SELECT item_key FROM homework_items WHERE homework_id = $1',
      [id]
    );
    const held = new Set(existing.rows.map((r) => r.item_key));

    const keptKeys = [];
    const rows = items.map((item, index) => {
      const key = item.itemKey && held.has(item.itemKey) ? item.itemKey : mintItemKey();
      keptKeys.push(key);
      return { ...item, key, position: index };
    });

    await client.query(
      `DELETE FROM homework_items
        WHERE homework_id = $1 AND NOT (item_key = ANY($2::varchar[]))`,
      [id, keptKeys]
    );

    for (const row of rows) {
      await client.query(
        `INSERT INTO homework_items
           (homework_id, item_key, position, kind, task, gate)
         VALUES ($1, $2, $3, $4, $5::jsonb, $6)
         ON CONFLICT (homework_id, item_key) DO UPDATE
            SET position = EXCLUDED.position,
                kind = EXCLUDED.kind,
                task = EXCLUDED.task,
                gate = EXCLUDED.gate`,
        [id, row.key, row.position, row.kind, JSON.stringify(row.task), row.gate]
      );
    }

    await client.query('COMMIT');
    logger.info({ trainerId, homeworkId: id, items: rows.length },
      homeworkId === null ? 'Homework created' : 'Homework saved');
    return { ok: true, homework: await loadHomework(pool, id, trainerId) };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

/// One homework with its items in order, and where it has already been sent.
///
/// Null for „no such homework" and for „not yours" alike, so a guessed id
/// tells nobody which homeworks exist.
async function loadHomework(pool, homeworkId, trainerId) {
  const found = await pool.query(
    'SELECT * FROM homeworks WHERE id = $1 AND trainer_id = $2',
    [homeworkId, trainerId]
  );
  if (found.rows.length === 0) return null;

  const items = await pool.query(
    `SELECT item_key, position, kind, task, gate
       FROM homework_items WHERE homework_id = $1 ORDER BY position`,
    [homeworkId]
  );
  // The copies already sent. They are `assignments`, so they are unaffected by
  // anything above — which is the whole point of the two halves.
  const sent = await pool.query(
    `SELECT a.id, a.student_id, u.name AS student_name, a.created_at, a.completed_at,
            (SELECT COUNT(*)::int FROM assignments c WHERE c.parent_id = a.id) AS child_total,
            (SELECT COUNT(c.completed_at)::int FROM assignments c WHERE c.parent_id = a.id)
              AS child_completed
       FROM assignments a
       LEFT JOIN users u ON u.id = a.student_id
      WHERE a.homework_id = $1 AND a.trainer_id = $2
      ORDER BY a.created_at DESC`,
    [homeworkId, trainerId]
  );

  return { ...found.rows[0], items: items.rows, sent: sent.rows };
}

/// The trainer's own homeworks, newest edit first.
async function listHomeworks(pool, trainerId) {
  const result = await pool.query(
    `SELECT h.*,
            (SELECT COUNT(*)::int FROM homework_items i WHERE i.homework_id = h.id) AS item_count,
            (SELECT COUNT(*)::int FROM assignments a WHERE a.homework_id = h.id) AS sent_count
       FROM homeworks h
      WHERE h.trainer_id = $1
      ORDER BY h.updated_at DESC`,
    [trainerId]
  );
  return result.rows;
}

/// Deletes a homework the trainer wrote. What was sent from it stays sent:
/// `assignments.homework_id` is `ON DELETE SET NULL`.
async function deleteHomework(pool, homeworkId, trainerId) {
  const result = await pool.query(
    'DELETE FROM homeworks WHERE id = $1 AND trainer_id = $2 RETURNING id',
    [homeworkId, trainerId]
  );
  return result.rows.length > 0;
}

module.exports = {
  KINDS,
  MAX_ITEMS,
  mintItemKey,
  parseHomework,
  saveHomework,
  loadHomework,
  listHomeworks,
  deleteHomework,
};
