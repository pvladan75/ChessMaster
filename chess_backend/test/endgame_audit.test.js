// endgame_audit.test.js — what the tables say was thrown away, and what they
// would not say at all.
//
// The probe is a stub. Nothing here is checking that Syzygy is right; it is
// checking that a verdict is only ever produced when the tables gave one, and
// that the two perspectives — the position's, which belongs to the player, and
// each move's, which belongs to the opponent — are not confused.

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  auditGame, createEndgameAuditor, EndgameAuditUnavailable, tablebaseKey,
} = require('../services/endgameAudit');

// King and pawn against king, White to move: three men, well inside the tables.
const KP_K = '8/8/8/4k3/8/8/4P3/4K3 w - - 0 1';
const OPENING = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// Answers every position the same way. `moves` carries the category **after**
/// each move, which is the opponent's outcome — the shape the real service
/// returns.
function probeReturning({ category = 'win', moves = [] } = {}) {
  const calls = [];
  const probe = async (fen) => {
    calls.push(fen);
    return { category, dtz: 1, moves };
  };
  probe.calls = calls;
  return probe;
}

test('a win turned into a draw is a finding, with both verdicts on it', async () => {
  // Position is a win for the player to move (+2). After e2e4 the opponent is
  // to move in a drawn position, so the player's own outcome is 0.
  const probe = probeReturning({
    category: 'win',
    moves: [
      { uci: 'e2e4', san: 'e4', category: 'draw' },
      { uci: 'e1d2', san: 'Kd2', category: 'loss' },
    ],
  });
  const { findings, probed, unknown } = await auditGame(
    { start_fen: KP_K, moves: ['e2e4'], subject_color: 'w' }, probe,
  );

  assert.equal(probed, 1);
  assert.equal(unknown, 0);
  assert.equal(findings.length, 1);
  assert.deepEqual(findings[0], {
    ply: 1,
    fenBefore: KP_K,
    playedUci: 'e2e4',
    playedSan: 'e4',
    // The move that keeps the win: the one leaving the opponent lost.
    bestUci: 'e1d2',
    wdlBefore: 2,
    wdlAfter: 0,
  });
});

test('a move that keeps what the player had is not a finding', async () => {
  const probe = probeReturning({
    category: 'win',
    moves: [{ uci: 'e2e4', san: 'e4', category: 'loss' }],
  });
  const { findings } = await auditGame(
    { start_fen: KP_K, moves: ['e2e4'], subject_color: 'w' }, probe,
  );
  assert.equal(findings.length, 0);
});

test('a position the tables will not commit to is counted, never rounded', async () => {
  // 'maybe-win' and 'unknown' are the categories the tablebase service refuses
  // to turn into an outcome. Treating either as a win would make this feature's
  // one promise — that a verdict here is a fact — into a guess.
  for (const category of ['maybe-win', 'unknown', 'maybe-loss']) {
    const probe = probeReturning({
      category,
      moves: [{ uci: 'e2e4', san: 'e4', category: 'draw' }],
    });
    // eslint-disable-next-line no-await-in-loop
    const { findings, unknown, probed } = await auditGame(
      { start_fen: KP_K, moves: ['e2e4'], subject_color: 'w' }, probe,
    );
    assert.equal(probed, 1, category);
    assert.equal(unknown, 1, category);
    assert.equal(findings.length, 0, category);
  }
});

test('a played move the tables did not list is unknown, not a blunder', async () => {
  const probe = probeReturning({ category: 'win', moves: [] });
  const { findings, unknown } = await auditGame(
    { start_fen: KP_K, moves: ['e2e4'], subject_color: 'w' }, probe,
  );
  assert.equal(unknown, 1);
  assert.equal(findings.length, 0);
});

test('the opponent\'s moves are not audited', async () => {
  // The archive is one player's, and their opponent giving away a win is not
  // their mistake to drill.
  const probe = probeReturning({
    category: 'win',
    moves: [{ uci: 'e2e4', san: 'e4', category: 'draw' }],
  });
  const { findings, probed } = await auditGame(
    { start_fen: KP_K, moves: ['e2e4'], subject_color: 'b' }, probe,
  );
  assert.equal(probed, 0, 'a position with the opponent to move was probed');
  assert.equal(findings.length, 0);
});

test('positions above seven men are never asked about', async () => {
  const probe = probeReturning();
  const { probed } = await auditGame(
    { start_fen: OPENING, moves: ['e2e4', 'e7e5'], subject_color: 'w' }, probe,
  );
  assert.equal(probed, 0);
  assert.equal(probe.calls.length, 0);
});

test('a game that stops replaying stops the audit of that game', async () => {
  const probe = probeReturning({
    category: 'win',
    moves: [{ uci: 'e2e4', san: 'e4', category: 'draw' }],
  });
  const { findings } = await auditGame(
    { start_fen: KP_K, moves: ['e1e8', 'e2e4'], subject_color: 'w' }, probe,
  );
  assert.equal(findings.length, 0, 'audited past a move that does not exist');
});

test('the cache key keeps the halfmove clock and drops the fullmove number', () => {
  // Four fields everywhere else in this codebase; five here, because the
  // halfmove clock is what separates a win from a cursed-win.
  assert.equal(tablebaseKey('8/8/8/4k3/8/8/4P3/4K3 w - - 0 1'), '8/8/8/4k3/8/8/4P3/4K3 w - - 0');
  assert.equal(tablebaseKey('8/8/8/4k3/8/8/4P3/4K3 w - - 0 40'), tablebaseKey(KP_K));
  assert.notEqual(tablebaseKey('8/8/8/4k3/8/8/4P3/4K3 w - - 99 1'), tablebaseKey(KP_K));
});

/// A pool that answers by reading the statement.
function stubPool({ cached = null, games = [], running = [] } = {}) {
  const calls = [];
  const query = async (text, params = []) => {
    const flat = text.replace(/\s+/g, ' ').trim();
    calls.push({ text: flat, params });
    if (/FROM tablebase_cache/.test(flat)) {
      return cached ? { rows: [cached], rowCount: 1 } : { rows: [], rowCount: 0 };
    }
    if (/INSERT INTO tablebase_cache/.test(flat)) return { rows: [], rowCount: 1 };
    // Deliberately loose about the column list. This branch matched
    // `SELECT id FROM endgame_audits` byte for byte, so adding `subject` to the
    // real query dropped the statement through to the catch-all below — which
    // answers `rowCount: 1` with no rows, a shape no database ever produces.
    if (/SELECT id.*FROM endgame_audits/.test(flat)) {
      return { rows: running, rowCount: running.length };
    }
    if (/INSERT INTO endgame_audits/.test(flat)) return { rows: [{ id: 8 }], rowCount: 1 };
    if (/FROM user_games/.test(flat)) return { rows: games, rowCount: games.length };
    if (/INSERT INTO mistake_reviews/.test(flat)) {
      return { rows: [], rowCount: params.length / 9 };
    }
    return { rows: [], rowCount: 1 };
  };
  return { calls, query };
}

test('a cached position costs no request, and a fresh one is written down', async () => {
  const asked = [];
  const tablebase = {
    probe: async (fen) => {
      asked.push(fen);
      return { category: 'win', dtz: 3, moves: [{ uci: 'e2e4', category: 'draw' }] };
    },
  };

  const cold = createEndgameAuditor({ pool: stubPool(), tablebase });
  await cold.cachedProbe(KP_K);
  assert.equal(asked.length, 1, 'a miss must reach the tables');

  const warm = createEndgameAuditor({
    pool: stubPool({ cached: { category: 'win', dtz: 3, moves: [{ uci: 'e2e4', category: 'draw' }] } }),
    tablebase,
  });
  const answer = await warm.cachedProbe(KP_K);
  assert.equal(asked.length, 1, 'a hit must not reach the tables');
  assert.equal(answer.category, 'win');
});

test('an audit walks only the games that reached the tables, and closes', async () => {
  const pool = stubPool({
    games: [{ id: 3, start_fen: KP_K, moves: ['e2e4'], subject_color: 'w' }],
  });
  const auditor = createEndgameAuditor({
    pool,
    tablebase: {
      probe: async () => ({
        category: 'win', dtz: 1,
        moves: [{ uci: 'e2e4', category: 'draw' }, { uci: 'e1d2', category: 'loss' }],
      }),
    },
  });

  const { auditId, finished } = await auditor.start({ userId: 5, subject: 'subjekat' });
  const counts = await finished;
  assert.equal(auditId, 8);
  assert.equal(counts.gamesTotal, 1);
  assert.equal(counts.gamesDone, 1);
  assert.equal(counts.mistakes, 1);
  assert.equal(counts.unknown, 0);

  const select = pool.calls.find((c) => /FROM user_games/.test(c.text));
  assert.match(select.text, /min_men <= \$3/, 'the audit must not walk the whole archive');
  assert.equal(select.params[2], 7);

  const write = pool.calls.find((c) => /INSERT INTO mistake_reviews/.test(c.text));
  assert.equal(write.params[6], 'tablebase');
  assert.equal(write.params[7], 2, 'wdl_before');
  assert.equal(write.params[8], 0, 'wdl_after');
  assert.match(write.text, /ON CONFLICT \(user_id, game_id, ply\) DO NOTHING/);

  const closing = [...pool.calls].reverse().find((c) => /UPDATE endgame_audits SET games_total/.test(c.text));
  assert.equal(closing.params[7], 'done');
});

test('a second audit for the same user is refused', async () => {
  const auditor = createEndgameAuditor({
    pool: stubPool({ running: [{ id: 2, subject: 'neko-drugi' }] }),
  });
  await assert.rejects(
    () => auditor.start({ userId: 5, subject: 'subjekat' }),
    (err) => err instanceof EndgameAuditUnavailable && err.status === 409,
  );
});

test('the refusal names the run it is refusing in favour of', async () => {
  // A client that crashed mid-audit met this refusal and nothing else for the
  // full hour of STALE_RUN_MS: the screen could not start a run and could not
  // find the one already going. The id makes the refusal followable.
  //
  // Still a refusal rather than a redirect, and the subject is why: the running
  // audit may be for another handle, and handing back its id unasked would show
  // that player's progress under this player's name.
  const auditor = createEndgameAuditor({
    pool: stubPool({ running: [{ id: 2, subject: 'neko-drugi' }] }),
  });
  await assert.rejects(
    () => auditor.start({ userId: 5, subject: 'subjekat' }),
    (err) => err.reason === 'already-running'
      && err.auditId === 2
      && err.subject === 'neko-drugi',
  );
});

test('a run whose process died is reaped before the next one starts', async () => {
  const pool = stubPool({ games: [] });
  const auditor = createEndgameAuditor({ pool });
  const { finished } = await auditor.start({ userId: 5, subject: 'subjekat' });
  await finished;
  const reap = pool.calls.find((c) => /UPDATE endgame_audits SET status = 'failed'/.test(c.text));
  assert.ok(reap, 'one crash would block that user forever');
});
