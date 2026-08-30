// homeworkFromArchive.js — homework made of the student's own mistakes.
//
// Section 6 of docs/PLAN-MOJE-PARTIJE.md, and the one that makes this whole
// plan a coaching feature rather than a solitaire one. A trainer picks a
// student and gets an assignment built from positions that child actually got
// wrong last week.
//
// **The gate is `trainerOwnsStudent` and nothing else.** Three hand-written
// copies of a similar condition elsewhere in this codebase each forgot the
// status, so an unanswered invitation already unlocked the sender's lessons.
// This file calls that function and never writes the condition again; the
// assignment itself is then created by `createCustomAssignment`, which checks
// it a second time on its own.
//
// One property worth naming, because it is structural rather than promised:
// **a trainer can only build homework out of an archive the student imported
// themselves.** The import route is scoped to `req.user.id`, so no other
// account can put games in a student's archive, and the query below reads only
// rows where `subject_is_owner` is true — a child's own games, never an
// opponent's profile the child happened to look up.
//
// What a trainer sees through this is positions and mistakes, not a browsable
// game history. That is deliberate: the narrower read is the one the
// relationship actually needs.

const crypto = require('crypto');
const { Chess } = require('chess.js');
const {
  trainerOwnsStudent, createCustomAssignment, MAX_ITEMS, DEFAULT_ITEMS,
} = require('./assignmentService');
const { materialSignature } = require('./mistakeReviews');
const { OWN_GAMES_SQL } = require('./archiveScope');
const logger = require('./logger');

/// How many candidates are read for every item wanted. Enough to spread the set
/// across different mistakes rather than handing a child eight versions of the
/// same fork.
const CANDIDATE_FACTOR = 5;

class HomeworkRefused extends Error {
  constructor(message, { status = 400 } = {}) {
    super(message);
    this.name = 'HomeworkRefused';
    this.status = status;
  }
}

/// The move that should have been played, in the notation a child reads.
function sanOf(fen, uci) {
  if (!uci) return null;
  try {
    const board = new Chess(fen);
    const played = board.move({
      from: uci.slice(0, 2),
      to: uci.slice(2, 4),
      promotion: uci.length > 4 ? uci.slice(4, 5) : undefined,
    });
    return played ? played.san : null;
  } catch {
    return null;
  }
}

function sideToMove(fen) {
  const field = String(fen).split(' ')[1];
  return field === 'b' ? 'b' : 'w';
}

/// What the child is actually asked to do. A board with no task is not an
/// exercise — `custom_puzzles` says so in its own schema, and a tablebase
/// position with "find the best move" written over it is a different exercise
/// from an engine one.
function instructionFor(row, playedSan) {
  if (row.kind === 'tablebase') {
    if (Number(row.wdl_before) > 0) {
      return 'Ovde si imao dobijenu poziciju. Nađi potez koji dobitak zadržava.';
    }
    return 'Ovde je pozicija bila remi. Nađi potez koji remi drži.';
  }
  return playedSan
    ? `U ovoj poziciji si odigrao ${playedSan}. Nađi bolji potez.`
    : 'Nađi najbolji potez u ovoj poziciji.';
}

/// A stable id, so regenerating homework from the same mistake reuses the
/// position instead of filling the trainer's library with copies of it.
function puzzleIdFor(row) {
  const material = `${row.fen_before} ${row.best_uci}`;
  return `hw_${crypto.createHash('sha1').update(material).digest('hex').slice(0, 24)}`;
}

/// The student's mistakes, worst first inside each kind, then spread out.
///
/// Ranked **within** kind rather than across it. An engine mistake is measured
/// in centipawns and a tablebase one in a change of result; putting them on one
/// scale would mean inventing an exchange rate between "gave away 300
/// centipawns" and "turned a win into a draw", and every number after it would
/// carry that invention without saying so.
async function candidateMistakes(pool, studentId, { kind = null, limit }) {
  const { rows } = await pool.query(
    `SELECT m.id, m.game_id, m.ply, m.fen_before, m.played_uci, m.best_uci,
            m.kind, m.theme, m.swing_cp, m.wdl_before, m.wdl_after,
            g.played_at, g.opening, g.opponent,
            ROW_NUMBER() OVER (
              PARTITION BY m.kind
              ORDER BY CASE WHEN m.kind = 'engine'
                            THEN ABS(COALESCE(m.swing_cp, 0))
                            ELSE (m.wdl_before - m.wdl_after) * 1000 END DESC,
                       m.id DESC
            ) AS rank_in_kind
       FROM mistake_reviews m
       JOIN user_games g ON g.id = m.game_id
      WHERE m.user_id = $1
        AND g.${OWN_GAMES_SQL}
        AND m.best_uci IS NOT NULL
        AND ($2::varchar IS NULL OR m.kind = $2)
      ORDER BY rank_in_kind, m.kind
      LIMIT $3`,
    [studentId, kind, limit],
  );
  return rows;
}

/// One of each theme before a second of any, so a set of eight is eight
/// different lessons rather than eight copies of one.
function spread(rows, count) {
  const buckets = new Map();
  for (const row of rows) {
    const key = row.kind === 'tablebase'
      ? `zavrsnica:${materialSignature(row.fen_before)}`
      : `motiv:${row.theme || 'bez teme'}`;
    if (!buckets.has(key)) buckets.set(key, []);
    buckets.get(key).push(row);
  }

  const picked = [];
  const queues = [...buckets.values()];
  while (picked.length < count) {
    let tookOne = false;
    for (const queue of queues) {
      if (picked.length >= count) break;
      const row = queue.shift();
      if (!row) continue;
      picked.push(row);
      tookOne = true;
    }
    if (!tookOne) break;
  }
  return picked;
}

/// Turns chosen mistakes into positions the trainer owns.
async function storePositions(pool, trainerId, rows) {
  const stored = [];
  const skipped = [];

  for (const row of rows) {
    const solutionSan = sanOf(row.fen_before, row.best_uci);
    if (!solutionSan) {
      // Without a solution nothing can judge the answer and the child is told
      // "netačno" whatever they play. `assignableProblem` refuses these anyway;
      // catching it here means the reason is countable instead of a rejection
      // list at the end.
      skipped.push({ id: row.id, reason: 'nema rešenje koje se može odigrati' });
      continue;
    }
    const playedSan = sanOf(row.fen_before, row.played_uci);
    const puzzleId = puzzleIdFor(row);
    const themes = row.kind === 'tablebase'
      ? ['zavrsnica']
      : [row.theme].filter(Boolean);

    // eslint-disable-next-line no-await-in-loop
    await pool.query(
      `INSERT INTO custom_puzzles
         (puzzle_id, owner_id, fen, side_to_move, solution_san, instruction,
          themes, source_title, needs_review)
       VALUES ($1, $2, $3, $4, $5, $6, $7::varchar[], $8, FALSE)
       ON CONFLICT (puzzle_id) DO NOTHING`,
      [
        puzzleId, trainerId, row.fen_before, sideToMove(row.fen_before),
        solutionSan, instructionFor(row, playedSan), themes,
        'Iz partija učenika',
      ],
    );
    stored.push({ puzzleId, mistakeId: row.id, kind: row.kind, solutionSan });
  }

  return { stored, skipped };
}

/// Builds an assignment out of a student's own mistakes.
///
/// `dryRun` returns the chosen positions and writes nothing, which is what a
/// trainer should see before a child does.
async function homeworkFromArchive(pool, {
  trainerId, studentId, title, instructions = null, dueAt = null,
  count = DEFAULT_ITEMS, kind = null, dryRun = false,
}) {
  if (!Number.isInteger(trainerId) || !Number.isInteger(studentId)) {
    throw new TypeError('trainerId and studentId are required');
  }
  if (trainerId === studentId) {
    throw new HomeworkRefused('Sebi se domaći ne zadaje.');
  }
  if (kind !== null && !['engine', 'tablebase'].includes(kind)) {
    throw new HomeworkRefused('Vrsta greške mora biti „engine" ili „tablebase".');
  }
  const wanted = Math.min(Math.max(Number(count) || DEFAULT_ITEMS, 1), MAX_ITEMS);

  // The one gate, called rather than rewritten.
  if (!(await trainerOwnsStudent(pool, trainerId, studentId))) {
    throw new HomeworkRefused('Taj učenik nije na vašoj listi.', { status: 403 });
  }

  const candidates = await candidateMistakes(pool, studentId, {
    kind, limit: wanted * CANDIDATE_FACTOR,
  });
  if (candidates.length === 0) {
    throw new HomeworkRefused(
      'Taj učenik nema nijednu grešku iz svojih partija. Prvo treba da uveze arhivu i pusti analizu.',
    );
  }

  const chosen = spread(candidates, wanted);

  if (dryRun) {
    return {
      dryRun: true,
      candidates: candidates.length,
      chosen: chosen.map((row) => ({
        mistakeId: row.id,
        kind: row.kind,
        theme: row.theme,
        fen: row.fen_before,
        playedSan: sanOf(row.fen_before, row.played_uci),
        solutionSan: sanOf(row.fen_before, row.best_uci),
        playedAt: row.played_at,
        opening: row.opening,
      })),
    };
  }

  const { stored, skipped } = await storePositions(pool, trainerId, chosen);
  if (stored.length === 0) {
    throw new HomeworkRefused('Nijedna greška nije mogla da postane zadatak.');
  }

  // The assignment itself is created by the function that already owns that
  // job, gate included — this file adds positions, it does not add a second way
  // to hand out homework.
  const outcome = await createCustomAssignment(pool, {
    trainerId,
    studentId,
    title: title || 'Iz tvojih partija',
    instructions,
    dueAt,
    puzzleIds: stored.map((s) => s.puzzleId),
  });

  if (!outcome.ok) throw new HomeworkRefused(outcome.reason || 'Domaći nije mogao da se napravi.');

  logger.info(
    { trainerId, studentId, items: stored.length, skipped: skipped.length },
    'Homework generated from student archive',
  );
  return {
    dryRun: false,
    assignment: outcome.assignment,
    items: stored.length,
    candidates: candidates.length,
    skipped,
  };
}

module.exports = {
  homeworkFromArchive,
  candidateMistakes,
  spread,
  sanOf,
  instructionFor,
  puzzleIdFor,
  HomeworkRefused,
  CANDIDATE_FACTOR,
};
