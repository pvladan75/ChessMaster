// puzzle_list_db.test.js — the puzzle list's questions on a real database.
//
// puzzle_list.test.js holds the list's rules on stubs. This holds its five
// questions to the puzzle tables against the schema `initDB` builds, so a
// column that is not there fails here rather than in the first list a player
// opens — a stub answers any SQL it is sent. Skipped on a workstation without
// TEST_DATABASE_URL; in CI a missing one fails the run
// (test/support/pgTestDb.js).

const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const { skipUnlessDatabase, freshDatabase } = require('./support/pgTestDb');

const skip = skipUnlessDatabase();

// The first row of the Lichess puzzle database, and the board after its setup
// move, worked out by hand (puzzle_list.test.js says how).
const LICHESS_FEN = 'r6k/pp2r2p/4Rp1Q/3p4/8/1N1P2R1/PqP2bPP/7K b - - 0 24';
const LICHESS_MOVES = 'f2g3 e6e7 b2b1 b3c1 b1c1 h6c1';
const LICHESS_SHOWN = 'r6k/pp2r2p/4Rp1Q/3p4/8/1N1P2b1/PqP3PP/7K w - - 0 25';
const MATE_FEN = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';
const ENDGAME_FEN = '8/8/4k3/8/3PK3/8/r7/7R w - - 0 1';
const BLUNDER_FEN = '8/5pk1/8/8/8/8/5PK1/r7 b - - 0 55';
const OWN_FEN = '6k1/5ppp/8/8/8/8/5PPP/1R4K1 w - - 0 1';
const BASIC = 'basic:easy:4k3/8/4K3/8/8/8/8/7Q w - -';

describe('the puzzle list on a real database', { skip: skip ? skip.skip : false }, () => {
  let db;
  let pool;
  let puzzleListOf;

  before(async () => {
    db = await freshDatabase();
    pool = db.pool;
    ({ puzzleListOf } = require('../services/puzzleList'));
  });

  after(async () => {
    if (db) await db.drop();
  });

  async function account(name) {
    const res = await pool.query(
      `INSERT INTO users (email, password_hash, name) VALUES ($1, 'x', $2) RETURNING id`,
      [`${name}${process.pid}@test.invalid`, name]
    );
    return res.rows[0].id;
  }

  test("every source's board comes from its own table, and own exercises only the caller's", async () => {
    const me = await account('me');
    const them = await account('them');

    await pool.query(
      `INSERT INTO lichess_puzzles (puzzle_id, fen, moves, rating, themes)
       VALUES ('00008', $1, $2, 1939, $3)`,
      [LICHESS_FEN, LICHESS_MOVES, ['crushing', 'hangingPiece', 'long', 'middlegame']]
    );
    await pool.query(
      `INSERT INTO puzzles (puzzle_id, source, fen, side_to_move, eval, type, mate_depth,
                            winning_move_uci, winning_move_san)
       VALUES ('m1', 'test', $1, 'w', '#2', 'mate_puzzle', 2, 'a1a8', 'Ra8#')`,
      [MATE_FEN]
    );
    await pool.query(
      `INSERT INTO endgame_puzzles (puzzle_id, fen, mode, endgame_type, material)
       VALUES ('eg_1', $1, 'win', 'RookEndgame', 'KRPvKR')`,
      [ENDGAME_FEN]
    );
    await pool.query(
      `INSERT INTO blunder_games (game_id, start_fen, blunders, white, black)
       VALUES ('tw:42', $1, $2, 'Chiburdanidze, Maia', 'Gaprindashvili, Nona')`,
      [BLUNDER_FEN, JSON.stringify([{ ply: 57, fen: BLUNDER_FEN, side: 'black' }])]
    );
    await pool.query(
      `INSERT INTO custom_puzzles (puzzle_id, owner_id, fen, side_to_move, instruction, origin)
       VALUES ('ex_mine', $1, $2, 'w', 'Mine', 'manual'), ('ex_theirs', $3, $4, 'w', 'Theirs', 'manual')`,
      [me, OWN_FEN, them, MATE_FEN]
    );

    // The log, as the drills write it — and another account's solve of the
    // same Lichess puzzle, which is not this list's.
    for (const [source, id] of [
      ['lichess', '00008'], ['mate_puzzle', 'm1'], ['endgame', 'eg_1'],
      ['blunder_game', 'tw:42:57'], ['basic_mate', BASIC], ['own', 'ex_mine'], ['own', 'ex_theirs'],
    ]) {
      await pool.query(
        `INSERT INTO user_puzzle_attempts (user_id, puzzle_id, source, solved) VALUES ($1, $2, $3, false)`,
        [me, id, source]
      );
    }
    await pool.query(
      `INSERT INTO user_puzzle_attempts (user_id, puzzle_id, source, solved) VALUES ($1, '00008', 'lichess', true)`,
      [them]
    );

    const page = await puzzleListOf(pool, me, { limit: 100 });
    const by = Object.fromEntries(page.puzzles.map((p) => [p.puzzleId, p]));

    assert.equal(page.puzzles.length, 7);
    assert.equal(page.next, null);
    assert.equal(by['00008'].fen, LICHESS_SHOWN);
    assert.equal(by['00008'].state, 'failed', "the other account's solve is not this list's");
    assert.deepEqual(by['00008'].detail.themes, ['hangingPiece'], 'motifs only');
    assert.equal(by.m1.fen, MATE_FEN);
    assert.deepEqual(by.m1.detail, { mateDepth: 2 });
    assert.equal(by.eg_1.fen, ENDGAME_FEN);
    assert.equal(by.eg_1.detail.materialLabel, 'rook and pawn versus rook');
    assert.equal(by['tw:42:57'].fen, BLUNDER_FEN);
    assert.equal(by['tw:42:57'].detail.white, 'Chiburdanidze, Maia');
    assert.equal(by[BASIC].available, true);
    assert.equal(by.ex_mine.fen, OWN_FEN);
    assert.equal(by.ex_theirs.available, false, "another account's exercise shows no board");

    const theirs = await puzzleListOf(pool, them);
    assert.deepEqual(theirs.puzzles.map((p) => p.puzzleId), ['00008']);
    assert.equal(theirs.puzzles[0].state, 'solved');
  });
});
