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
const { assignableProblem, exerciseColumns, exerciseOf } = require('./exercise');

/// The five shelves, by the name the API uses for them.
const KINDS = ['scan', 'position', 'analysis', 'tutorial', 'recording'];

/// Rows a caller may filter to. Anything else is a typo, and a typo that
/// silently returned everything would look like the filter working.
function isKind(value) {
  return typeof value === 'string' && KINDS.includes(value);
}

/// Whether this entry can be set as homework, and if not, why not.
///
/// The rule lives in `exercise.js` and is not restated here: a position
/// with no solution cannot judge an answer, so a child would be told "netačno"
/// whatever they play. Only scanned positions ever carry a solution today, but
/// the question is asked of every kind so that changes in one place when one of
/// the others learns to.
///
/// An exercise is asked *as what it is*: a game exercise is assignable as a
/// game. The default of `assignableProblem` — „as a find-the-move item" —
/// protects the paths that can only build one; the shelf is not such a path,
/// and with the default every game exercise on it would read „cannot be set".
function assignability(row) {
  const type = exerciseOf(row).task?.type ?? 'find';
  const problem = assignableProblem(row, { as: type });
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
    where += ` AND (COALESCE(name, '') ILIKE $${params.length}
                 OR COALESCE(instruction, '') ILIKE $${params.length}
                 OR COALESCE(source_title, '') ILIKE $${params.length}
                 OR COALESCE(source_label, '') ILIKE $${params.length}
                 OR array_to_string(themes, ' ') ILIKE $${params.length})`;
  }

  const result = await pool.query(
    `SELECT puzzle_id, side_to_move, name, origin, ${exerciseColumns()}, instruction, themes,
            source_title, source_page, source_label, created_at
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
    // An exercise made by hand has a name. A scanned one has none of its own:
    // the book and the printed number are what the trainer recognises it by,
    // so they stand in for one rather than a title being invented.
    title: (typeof row.name === 'string' && row.name.trim())
      || [row.source_title, row.source_label && `#${row.source_label}`]
        .filter(Boolean)
        .join(' ')
      || 'Scanned position',
    // What wrote it, and what it asks (`docs/PLAN-EXERCISE.md`, phase 4): the
    // shelf filters by both. The task is what `exerciseOf` reads — never the
    // solution, which this list has no business carrying.
    origin: row.origin ?? 'book',
    task: exerciseOf(row).task,
    fen: row.fen,
    sideToMove: row.side_to_move,
    instruction: row.instruction,
    themes: row.themes || [],
    hasSolution: exerciseOf(row).solution !== null,
    // Position or exercise, decided here by the one reader
    // (docs/PLAN-MATERIJAL.md §3, decision 1): the app reads this field and
    // no longer restates the rule. A row still marked for review can be an
    // exercise — its doors ask about the side first.
    isExercise: exerciseOf(row).problem === null,
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
    title: row.title || 'Untitled',
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
    ...assignability({}),
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
    title: row.title || 'Untitled',
    fen: row.starting_fen,
    instruction: null,
    themes: [],
    hasSolution: false,
    needsReview: false,
    createdAt: row.created_at,
    ...assignability({}),
  }));
}

/// Tutorials — `saved_lessons` rows *with* a step list. A row without one is a
/// single saved position (`listSavedPositions`), not one of these.
///
/// **The account's own only.** A trainer's tutorial reaches their student as
/// its film, sent to them — never as a tutorial on the student's shelf
/// (docs/PLAN-TUTORIJAL-VIDEO.md, D6). A trainer's single positions still do
/// (`listSavedPositions`).
async function listTutorials(pool, userId, { search }) {
  const params = [userId];
  let where = `position_list IS NOT NULL
               AND (user_id = $1 OR trainer_id = $1)`;
  if (search) {
    params.push(`%${search}%`);
    where += ` AND (title ILIKE $${params.length}
                 OR COALESCE(description, '') ILIKE $${params.length})`;
  }

  const result = await pool.query(
    `SELECT id, title, fen, language, created_at, tags,
            jsonb_array_length(position_list) AS parts_count,
            (video_filename IS NOT NULL) AS has_video,
            (SELECT j.id FROM tutorial_render_jobs j
              WHERE j.lesson_id = saved_lessons.id AND j.user_id = $1
                AND j.status = 'running'
              LIMIT 1) AS render_job_id,
            (trainer_id != $1 AND user_id != $1) AS from_trainer
       FROM saved_lessons
      WHERE ${where}
      ORDER BY created_at DESC
      LIMIT 500`,
    params
  );

  return result.rows.map((row) => ({
    kind: 'tutorial',
    id: String(row.id),
    title: row.title || 'Untitled',
    fen: row.fen,
    partsCount: row.parts_count,
    hasVideo: row.has_video === true,
    rendering: row.render_job_id != null,
    language: row.language,
    fromTrainer: row.from_trainer === true,
    createdAt: row.created_at,
    assignable: false,
    blockedReason: null,
    instruction: null,
    // The labels its author gave it — the room's column filters by them
    // (phase 3b), the same way it filters a saved position.
    themes: row.tags || [],
    hasSolution: false,
    needsReview: false,
  }));
}

/// Recordings — a trainer's own `session_recordings`. Never shown to the
/// student side: only the host who made the recording can see or replay it.
async function listRecordings(pool, userId, { search }) {
  const params = [userId];
  let where = 'host_id = $1';
  if (search) {
    params.push(`%${search}%`);
    where += ` AND title ILIKE $${params.length}`;
  }

  const result = await pool.query(
    `SELECT id, title, video_url, created_at
       FROM session_recordings
      WHERE ${where}
      ORDER BY created_at DESC
      LIMIT 500`,
    params
  );

  return result.rows.map((row) => ({
    kind: 'recording',
    id: String(row.id),
    title: row.title || 'Untitled',
    fen: '',
    hasVideo: row.video_url != null,
    createdAt: row.created_at,
    assignable: false,
    blockedReason: null,
    instruction: null,
    themes: [],
    hasSolution: false,
    needsReview: false,
  }));
}

/// Everything the caller can put into a lesson, from all five shelves.
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
    tutorial: listTutorials,
    recording: listRecordings,
  };

  const groups = await Promise.all(wanted.map((k) => readers[k](pool, userId, options)));
  return groups.flat();
}

module.exports = {
  listLibrary,
  listScanned,
  listSavedPositions,
  listAnalyses,
  listTutorials,
  listRecordings,
  isKind,
  KINDS,
};
