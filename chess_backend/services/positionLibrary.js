// positionLibrary.js — one shelf a trainer can look at, over three that stay
// where they are.
//
// Until this existed a scanned position could not be put into a lesson at all:
// `custom_puzzles` was visible only in "Moje pozicije", while the lesson editor
// read `saved_lessons` and `saved_analyses` and knew nothing about the scanner.
// That is a hole in the chain, not a missing convenience.
//
// It is a **view**, not a merge. The three shapes are genuinely different — a
// scanned position is one board, one move and a task; a saved analysis is a
// tree of variations with a PGN — and folding them into one table would force
// every consumer to branch on kind anyway. That is the same reason `puzzles`
// and `lichess_puzzles` were deliberately left apart (see `db.js`).
//
// So each source keeps its own query, its own ordering and its own rights
// check, and only the row a caller reads is common.

const { acceptedTrainersOf } = require('./relationshipService');
const { assignableProblem } = require('./customPuzzleJudge');

/// The three shelves, by the name the API uses for them.
const KINDS = ['scan', 'position', 'analysis'];

/// Rows a caller may filter to. Anything else is a typo, and a typo that
/// silently returned everything would look like the filter working.
function isKind(value) {
  return typeof value === 'string' && KINDS.includes(value);
}

/// Whether this entry can be set as homework, and if not, why not.
///
/// The rule lives in `customPuzzleJudge` and is not restated here: a position
/// with no solution cannot judge an answer, so a child would be told "netačno"
/// whatever they play. Only scanned positions ever carry a solution today, but
/// the question is asked of every kind so that changes in one place when one of
/// the others learns to.
function assignability(row) {
  const problem = assignableProblem(row);
  return { assignable: problem === null, blockedReason: problem };
}

/// Scanned positions — the trainer's own book, already confirmed by them.
///
/// Ordered the way the book is rather than the way the rows were written: the
/// scanner walks a page down and then across, a book numbers its diagrams down
/// one column and then the next, and everything from one scan shares a
/// `created_at` to the microsecond. The printed label is what a trainer looks
/// for, and it is text, so it is compared as a number or 100 lands before 97.
async function listScanned(pool, userId, { search }) {
  const params = [userId];
  let where = 'owner_id = $1';
  if (search) {
    params.push(`%${search}%`);
    where += ` AND (COALESCE(instruction, '') ILIKE $${params.length}
                 OR COALESCE(source_title, '') ILIKE $${params.length}
                 OR COALESCE(source_label, '') ILIKE $${params.length}
                 OR array_to_string(themes, ' ') ILIKE $${params.length})`;
  }

  const result = await pool.query(
    `SELECT puzzle_id, fen, side_to_move, solution_san, instruction, themes,
            source_title, source_page, source_label, needs_review, created_at
       FROM custom_puzzles
      WHERE ${where}
      ORDER BY source_title NULLS LAST,
               source_page NULLS LAST,
               CASE WHEN source_label ~ '^[0-9]+$' THEN source_label::int END NULLS LAST,
               id
      LIMIT 500`,
    params
  );

  return result.rows.map((row) => ({
    kind: 'scan',
    id: row.puzzle_id,
    // A scanned position has no name of its own. The book and the printed
    // number are what the trainer recognises it by, so they stand in for one
    // rather than a title being invented.
    title: [row.source_title, row.source_label && `#${row.source_label}`]
      .filter(Boolean)
      .join(' ') || 'Skenirana pozicija',
    fen: row.fen,
    sideToMove: row.side_to_move,
    instruction: row.instruction,
    themes: row.themes || [],
    hasSolution: Boolean(row.solution_san),
    needsReview: row.needs_review === true,
    sourceTitle: row.source_title,
    sourcePage: row.source_page,
    sourceLabel: row.source_label,
    createdAt: row.created_at,
    ...assignability(row),
  }));
}

/// Single positions saved from the board — `saved_lessons` rows without a step
/// list. A row *with* one is a course, which is a container of these and not
/// one of them.
///
/// Read through `acceptedTrainersOf`, never a hand-written copy of that
/// subquery: three copies once forgot the status and an unanswered request
/// already unlocked the sender's lessons.
async function listSavedPositions(pool, userId, { search }) {
  const params = [userId];
  let where = `position_list IS NULL
               AND (user_id = $1 OR trainer_id = $1 OR trainer_id IN (${acceptedTrainersOf('$1')}))`;
  if (search) {
    params.push(`%${search}%`);
    where += ` AND (title ILIKE $${params.length}
                 OR COALESCE(description, '') ILIKE $${params.length})`;
  }

  const result = await pool.query(
    `SELECT id, title, description, fen, pgn, tags, created_at,
            (trainer_id != $1 AND user_id != $1) AS from_trainer
       FROM saved_lessons
      WHERE ${where}
      ORDER BY created_at DESC
      LIMIT 500`,
    params
  );

  return result.rows.map((row) => ({
    kind: 'position',
    id: String(row.id),
    title: row.title || 'Bez naziva',
    fen: row.fen,
    pgn: row.pgn,
    instruction: null,
    themes: row.tags || [],
    hasSolution: false,
    needsReview: false,
    // Someone else's material, readable because they teach this user. Worth
    // showing, because a trainer picking from a list should know which of it
    // is theirs to change.
    fromTrainer: row.from_trainer === true,
    createdAt: row.created_at,
    ...assignability({ solution_san: null, needs_review: false }),
  }));
}

/// Saved variation trees. The tree itself is deliberately absent — it is the
/// heavy half, and a picker only needs to show what is on the shelf. Whoever
/// takes one still loads it through `GET /analysis/:id`.
async function listAnalyses(pool, userId, { search }) {
  const params = [userId];
  let where = 'user_id = $1';
  if (search) {
    params.push(`%${search}%`);
    where += ` AND title ILIKE $${params.length}`;
  }

  const result = await pool.query(
    `SELECT id, title, starting_fen, created_at
       FROM saved_analyses
      WHERE ${where}
      ORDER BY created_at DESC
      LIMIT 500`,
    params
  );

  return result.rows.map((row) => ({
    kind: 'analysis',
    id: String(row.id),
    title: row.title || 'Bez naziva',
    fen: row.starting_fen,
    instruction: null,
    themes: [],
    hasSolution: false,
    needsReview: false,
    createdAt: row.created_at,
    ...assignability({ solution_san: null, needs_review: false }),
  }));
}

/// Everything the caller can put into a lesson, from all three shelves.
///
/// `kind` narrows it to one shelf; anything unrecognised is refused by the
/// route rather than quietly ignored, because a filter that appears to do
/// nothing is the oldest bug in this codebase.
async function listLibrary(pool, userId, { kind = null, search = null } = {}) {
  const term = typeof search === 'string' && search.trim() !== '' ? search.trim() : null;
  const options = { search: term };

  const wanted = kind ? [kind] : KINDS;
  const readers = {
    scan: listScanned,
    position: listSavedPositions,
    analysis: listAnalyses,
  };

  const groups = await Promise.all(wanted.map((k) => readers[k](pool, userId, options)));
  return groups.flat();
}

module.exports = { listLibrary, listScanned, listSavedPositions, listAnalyses, isKind, KINDS };
