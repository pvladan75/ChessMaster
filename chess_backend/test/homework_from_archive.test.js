// homework_from_archive.test.js — the gate, the spread, and what cannot become
// a task.
//
// Most of what matters here is refusal. Homework is the one feature in this
// plan that reaches across accounts, and most of those accounts belong to
// children, so the tests that matter are the ones that say no.

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  homeworkFromArchive, spread, sanOf, instructionFor, puzzleIdFor,
  HomeworkRefused, CANDIDATE_FACTOR,
} = require('../services/homeworkFromArchive');

// A rook-and-pawn ending, White to move.
const ENDGAME = '8/5k2/8/8/8/8/4PK2/8 w - - 0 1';
// After 1.e4 e5 2.Qh5, Black to move.
const MIDDLE = 'rnbqkbnr/pppp1ppp/8/4p2Q/4P3/8/PPPP1PPP/RNB1KBNR b KQkq - 1 2';

function mistake(over = {}) {
  return {
    id: 1, game_id: 3, ply: 41, fen_before: ENDGAME,
    played_uci: 'e2e4', best_uci: 'f2e3', kind: 'engine', theme: 'fork',
    swing_cp: -320, wdl_before: null, wdl_after: null,
    played_at: new Date('2026-07-05'), opening: 'Sicilian', opponent: 'neko',
    ...over,
  };
}

/// Answers by reading the statement, and records what was written.
function stubPool({ owns = true, candidates = [], assignment = null } = {}) {
  const calls = [];
  const puzzles = [];
  const query = async (text, params = []) => {
    const flat = text.replace(/\s+/g, ' ').trim();
    calls.push({ text: flat, params });
    if (/FROM trainer_students/.test(flat)) {
      return { rows: owns ? [{ 1: 1 }] : [], rowCount: owns ? 1 : 0 };
    }
    if (/FROM mistake_reviews m JOIN user_games g/.test(flat)) {
      return { rows: candidates, rowCount: candidates.length };
    }
    if (/INSERT INTO custom_puzzles/.test(flat)) {
      puzzles.push({ puzzleId: params[0], owner: params[1], fen: params[2], solution: params[4], instruction: params[5] });
      return { rows: [], rowCount: 1 };
    }
    if (/SELECT puzzle_id, solution_san, needs_review FROM custom_puzzles/.test(flat)) {
      const ids = params[1] || [];
      return {
        rows: ids.map((id) => ({ puzzle_id: id, solution_san: 'Ke3', needs_review: false })),
        rowCount: ids.length,
      };
    }
    if (/INSERT INTO assignments/.test(flat)) {
      return { rows: [assignment || { id: 9, student_id: 7, title: params[2] }], rowCount: 1 };
    }
    return { rows: [], rowCount: 0 };
  };
  return {
    calls, puzzles, query,
    connect: async () => ({ query, release() {} }),
  };
}

test('a trainer who is not the student\'s trainer is refused', async () => {
  // Three hand-written copies of a similar condition in this codebase each
  // forgot the accepted status, so an unanswered invitation already unlocked
  // the sender's lessons. This one calls the shared gate.
  const pool = stubPool({ owns: false, candidates: [mistake()] });
  await assert.rejects(
    () => homeworkFromArchive(pool, { trainerId: 1, studentId: 7 }),
    (err) => err instanceof HomeworkRefused && err.status === 403,
  );
  const wrote = pool.calls.find((c) => /INSERT/.test(c.text));
  assert.equal(wrote, undefined, 'a refusal must not have written anything');
});

test('the gate is asked before the student\'s games are read', async () => {
  const pool = stubPool({ owns: false, candidates: [mistake()] });
  await assert.rejects(() => homeworkFromArchive(pool, { trainerId: 1, studentId: 7 }));
  assert.match(pool.calls[0].text, /FROM trainer_students/);
  assert.equal(pool.calls.length, 1, 'nothing else should have been asked');
});

test('only the student\'s own archive is read', async () => {
  // A child may have imported an opponent's games to prepare. Those are not
  // their mistakes and must never become their homework.
  const pool = stubPool({ candidates: [mistake()] });
  await homeworkFromArchive(pool, { trainerId: 1, studentId: 7, dryRun: true });
  const read = pool.calls.find((c) => /FROM mistake_reviews m JOIN user_games g/.test(c.text));
  assert.match(read.text, /g\.subject_is_owner = TRUE/);
  assert.equal(read.params[0], 7, 'scoped to the student');
});

test('a trainer cannot set homework for themselves', async () => {
  const pool = stubPool();
  await assert.rejects(
    () => homeworkFromArchive(pool, { trainerId: 4, studentId: 4 }),
    HomeworkRefused,
  );
  assert.equal(pool.calls.length, 0);
});

test('a student with no mistakes gets a reason, not an empty assignment', async () => {
  const pool = stubPool({ candidates: [] });
  await assert.rejects(
    () => homeworkFromArchive(pool, { trainerId: 1, studentId: 7 }),
    (err) => err instanceof HomeworkRefused && /uveze arhivu/.test(err.message),
  );
});

test('a dry run chooses positions and writes nothing', async () => {
  const pool = stubPool({ candidates: [mistake(), mistake({ id: 2, theme: 'pin' })] });
  const out = await homeworkFromArchive(pool, {
    trainerId: 1, studentId: 7, count: 2, dryRun: true,
  });
  assert.equal(out.dryRun, true);
  assert.equal(out.chosen.length, 2);
  assert.equal(out.chosen[0].solutionSan, 'Ke3');
  assert.equal(pool.puzzles.length, 0);
  assert.equal(pool.calls.filter((c) => /INSERT/.test(c.text)).length, 0);
});

test('the set is spread across themes before it doubles up on one', () => {
  // Eight versions of the same fork is one lesson repeated, not homework.
  const rows = [
    mistake({ id: 1, theme: 'fork' }), mistake({ id: 2, theme: 'fork' }),
    mistake({ id: 3, theme: 'fork' }), mistake({ id: 4, theme: 'pin' }),
    mistake({ id: 5, theme: 'skewer' }),
  ];
  assert.deepEqual(spread(rows, 3).map((r) => r.theme), ['fork', 'pin', 'skewer']);
  // And when a theme runs out, the rest comes from whatever is left.
  assert.deepEqual(spread(rows, 5).map((r) => r.id), [1, 4, 5, 2, 3]);
});

test('endgame mistakes are spread by material, not by a missing theme', () => {
  // Tablebase findings carry no motif, so bucketing them by `theme` would put
  // every one of them in the same bucket called "bez teme".
  const rows = [
    mistake({ id: 1, kind: 'tablebase', theme: null, fen_before: ENDGAME }),
    mistake({ id: 2, kind: 'tablebase', theme: null, fen_before: '8/8/8/4k3/8/8/4P3/4K3 w - - 0 1' }),
  ];
  const picked = spread(rows, 2);
  assert.deepEqual(picked.map((r) => r.id), [1, 2]);
});

test('a candidate whose answer will not replay is skipped and counted', async () => {
  // Without a solution nothing can judge the answer and the child is told
  // "netačno" whatever they play.
  const pool = stubPool({
    candidates: [mistake({ best_uci: 'a1a8' }), mistake({ id: 2 })],
  });
  const out = await homeworkFromArchive(pool, { trainerId: 1, studentId: 7, count: 2 });
  assert.equal(out.items, 1);
  assert.equal(out.skipped.length, 1);
  assert.match(out.skipped[0].reason, /nema rešenje/);
});

test('the instruction says what kind of task this is', () => {
  assert.match(
    instructionFor({ kind: 'engine' }, 'Qh5'),
    /odigrao Qh5/,
  );
  assert.match(
    instructionFor({ kind: 'tablebase', wdl_before: 2 }, 'Ke2'),
    /dobitak zadržava/,
  );
  assert.match(
    instructionFor({ kind: 'tablebase', wdl_before: 0 }, 'Ke2'),
    /remi drži/,
  );
});

test('the same mistake makes the same position twice', () => {
  // Regenerating homework must reuse the position rather than filling the
  // trainer's library with copies of it.
  const a = puzzleIdFor({ fen_before: ENDGAME, best_uci: 'f2e3' });
  const b = puzzleIdFor({ fen_before: ENDGAME, best_uci: 'f2e3' });
  const c = puzzleIdFor({ fen_before: ENDGAME, best_uci: 'f2f3' });
  assert.equal(a, b);
  assert.notEqual(a, c);
  assert.match(a, /^hw_[0-9a-f]{24}$/);
});

test('a real assignment carries the positions and the trainer owns them', async () => {
  const pool = stubPool({ candidates: [mistake(), mistake({ id: 2, theme: 'pin' })] });
  const out = await homeworkFromArchive(pool, {
    trainerId: 1, studentId: 7, count: 2, title: 'Iz tvojih partija',
  });
  assert.equal(out.items, 2);
  assert.equal(pool.puzzles.length, 2);
  for (const puzzle of pool.puzzles) {
    assert.equal(puzzle.owner, 1, 'the trainer owns the position they set');
    assert.equal(puzzle.solution, 'Ke3');
  }
  assert.match(
    pool.calls.find((c) => /INSERT INTO custom_puzzles/.test(c.text)).text,
    /ON CONFLICT \(puzzle_id\) DO NOTHING/,
  );
});

test('sanOf refuses a move that does not fit the board', () => {
  assert.equal(sanOf(ENDGAME, 'f2e3'), 'Ke3');
  assert.equal(sanOf(ENDGAME, 'a1a8'), null);
  assert.equal(sanOf(MIDDLE, null), null);
});

test('more candidates are read than are needed, so there is something to spread', async () => {
  const pool = stubPool({ candidates: [mistake()] });
  await homeworkFromArchive(pool, { trainerId: 1, studentId: 7, count: 4, dryRun: true });
  const read = pool.calls.find((c) => /FROM mistake_reviews m JOIN user_games g/.test(c.text));
  assert.equal(read.params[2], 4 * CANDIDATE_FACTOR);
});
