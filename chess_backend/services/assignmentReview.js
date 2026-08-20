// assignmentReview.js — what actually happened, position by position.
//
// Until this existed both sides saw only arithmetic: "2/2 urađeno, tačnost
// 100%". Neither could look at a single position and see which board the child
// had in front of them and what they played — which is the part that says *why*
// it went wrong, and the only part a trainer can teach from.
//
// The three kinds of item are kept apart rather than flattened. A scanned
// position carries one move and a written task, a Lichess puzzle is a forced
// line, and a lesson step is read rather than solved; pretending they are the
// same row would make every reader branch anyway.

const { Chess } = require('chess.js');
const { assignmentParticipant } = require('./assignmentService');

/// Whether the answer may be shown to whoever is asking.
///
/// A solution is the answer to the question being asked, and it stays on the
/// server until the student has answered — sending it earlier hands them the
/// very thing being asked of them. Once they *have* answered, hiding it would
/// only stop them learning what they missed.
///
/// The trainer is not held to that: it is their own material, they chose it,
/// and they may look at an unanswered position without pretending not to know.
function mayRevealSolution({ attempted, isTrainer }) {
  return attempted || isTrainer;
}

/// A Lichess puzzle line, in notation a person reads.
///
/// It is stored the way Lichess ships it — `e7b7 b8b7 g7g8q`, squares and a
/// promotion letter — which is precise and unreadable. A trainer looking at
/// what their student missed should see `Rb7 Rxb7 g8=Q`.
///
/// The raw line is returned unchanged if anything at all goes wrong: a move
/// that will not play means this position and this line disagree, and that is
/// worth seeing rather than hiding behind an empty field. Half a translated
/// line is likewise not offered — it would read as the whole answer.
function lineToSan(fen, uci) {
  const moves = String(uci || '').trim().split(/\s+/).filter(Boolean);
  if (!fen || moves.length === 0) return uci || null;

  try {
    const board = new Chess(fen);
    const san = [];
    for (const move of moves) {
      const played = board.move({
        from: move.slice(0, 2),
        to: move.slice(2, 4),
        promotion: move.length > 4 ? move[4] : undefined,
      });
      if (!played) return uci;
      san.push(played.san);
    }
    return san.join(' ');
  } catch {
    return uci;
  }
}

/// Lesson steps, keyed by position, so an item can find the board it was.
function stepsByPosition(positionList) {
  const list = Array.isArray(positionList)
    ? positionList
    : (typeof positionList === 'string' ? safeParse(positionList) : null);
  if (!Array.isArray(list)) return new Map();
  return new Map(list.map((step, index) => [index, step]));
}

function safeParse(text) {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

/// One item, in the shape the review screen reads.
function shapeItem(row, { isTrainer, step }) {
  const attempted = row.attempted_at !== null && row.attempted_at !== undefined;
  const reveal = mayRevealSolution({ attempted, isTrainer });

  const base = {
    itemId: row.id,
    position: row.position,
    puzzleId: row.puzzle_id,
    attempted,
    attemptedAt: row.attempted_at,
    solved: row.solved,
    msTaken: row.ms_taken,
    // The move the child made. NULL is "not known", which is the truth for
    // everything answered before the column existed and for the Lichess path,
    // which reports only whether the puzzle was solved. It is never "nothing
    // was played" — a student cannot play nothing.
    playedSan: row.played_san ?? null,
  };

  if (row.puzzle_id === null || row.puzzle_id === undefined) {
    return {
      ...base,
      kind: 'step',
      title: step?.title ?? null,
      fen: step?.fen ?? null,
      instruction: step?.instruction ?? null,
      // A lesson step is marked read, not solved. Saying "netačno" about one
      // would be answering a question nobody asked.
      solved: null,
    };
  }

  if (row.custom_fen) {
    return {
      ...base,
      kind: 'custom',
      title: [row.source_title, row.source_label && `#${row.source_label}`]
        .filter(Boolean)
        .join(' ') || null,
      fen: row.custom_fen,
      instruction: row.instruction,
      themes: row.custom_themes || [],
      solutionSan: reveal ? row.solution_san : null,
      solutionHidden: !reveal && Boolean(row.solution_san),
    };
  }

  if (row.lichess_fen) {
    return {
      ...base,
      kind: 'lichess',
      title: null,
      fen: row.lichess_fen,
      instruction: null,
      themes: row.lichess_themes || [],
      rating: row.puzzle_rating ?? row.lichess_rating ?? null,
      // The whole forced line, in notation a person reads. Falls back to the
      // stored form if it will not replay, because a line that disagrees with
      // its own position is worth seeing.
      solutionMoves: reveal ? lineToSan(row.lichess_fen, row.lichess_moves) : null,
      solutionHidden: !reveal && Boolean(row.lichess_moves),
    };
  }

  // The puzzle row is gone — a Lichess id that was never imported, or a scanned
  // position the trainer has since deleted. The attempt still happened and is
  // still worth showing; inventing a board for it is not.
  return { ...base, kind: 'unknown', title: null, fen: null, instruction: null };
}

/// The whole review: the assignment, its items, and the conversation about it.
///
/// One request rather than three, because it is one screen — the same reason
/// the student's viewer gets its lesson steps inline.
///
/// Returns null when the caller is neither side of this assignment.
async function buildReview(pool, assignmentId, viewerId) {
  const access = await assignmentParticipant(pool, assignmentId, viewerId);
  if (!access) return null;

  const { assignment, isTrainer, isStudent } = access;

  const itemRows = await pool.query(
    `SELECT ai.id, ai.position, ai.puzzle_id, ai.puzzle_rating, ai.solved,
            ai.ms_taken, ai.played_san, ai.attempted_at,
            cp.fen AS custom_fen, cp.instruction, cp.solution_san,
            cp.themes AS custom_themes, cp.source_title, cp.source_label,
            lp.fen AS lichess_fen, lp.moves AS lichess_moves,
            lp.themes AS lichess_themes, lp.rating AS lichess_rating
       FROM assignment_items ai
       LEFT JOIN custom_puzzles cp ON cp.puzzle_id = ai.puzzle_id
       LEFT JOIN lichess_puzzles lp ON lp.puzzle_id = ai.puzzle_id
      WHERE ai.assignment_id = $1
      ORDER BY ai.position`,
    [assignmentId]
  );

  // A lesson assignment's items are its steps, and the boards live on the
  // lesson rather than on the item.
  let steps = new Map();
  if (assignment.kind === 'lesson' && assignment.lesson_id) {
    const lesson = await pool.query(
      'SELECT position_list FROM saved_lessons WHERE id = $1',
      [assignment.lesson_id]
    );
    steps = stepsByPosition(lesson.rows[0]?.position_list);
  }

  const items = itemRows.rows.map((row) =>
    shapeItem(row, { isTrainer, step: steps.get(row.position) })
  );

  const notes = await listNotes(pool, assignmentId, viewerId);

  return {
    assignment: {
      id: assignment.id,
      title: assignment.title,
      kind: assignment.kind,
      instructions: assignment.instructions,
      dueAt: assignment.due_at,
      completedAt: assignment.completed_at,
      createdAt: assignment.created_at,
      trainerName: assignment.trainer_name,
      studentName: assignment.student_name,
    },
    viewer: { isTrainer, isStudent },
    items,
    notes,
  };
}

/// The conversation, oldest first — it reads as one.
///
/// `mine` is computed here rather than left to the client: whose words these
/// are decides how they are shown, and an id comparison done in three places
/// eventually disagrees with itself.
async function listNotes(pool, assignmentId, viewerId) {
  const result = await pool.query(
    `SELECT n.id, n.item_id, n.author_id, n.body, n.created_at, u.name AS author_name
       FROM assignment_notes n
       LEFT JOIN users u ON u.id = n.author_id
      WHERE n.assignment_id = $1
      ORDER BY n.created_at, n.id`,
    [assignmentId]
  );

  return result.rows.map((row) => ({
    id: row.id,
    itemId: row.item_id,
    authorId: row.author_id,
    authorName: row.author_name,
    mine: row.author_id === viewerId,
    body: row.body,
    createdAt: row.created_at,
  }));
}

module.exports = { buildReview, listNotes, mayRevealSolution, shapeItem, stepsByPosition, lineToSan };
