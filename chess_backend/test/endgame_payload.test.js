// endgame_payload.test.js — the gate of docs/PLAN-TRENER-ZAVRSNICA.md phase 2.
//
// One builder answers both /puzzles/endgame/next and
// /puzzles/by-id?source=endgame, so both routes are asked here, for a mined
// row (no material, as every one of the 1089 mined rows is, measured
// 1.10.2026) and for a row from a real mistake (with material). Handlers are
// called directly over the real pool object with `query` replaced — the idiom
// of puzzle_progress_routes.test.js.
//
// What it holds:
//   - `material_label` is the picker's own words, `labelOf(material)`, taken
//     from `material` and never from `endgame_type`;
//   - it is null, not '', where `material` is null (`labelOf(null)` is '');
//   - the stored line (`solution`, `solution_san`) is no longer sent (D8).

const test = require('node:test');
const assert = require('node:assert/strict');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret-not-used-for-signing-0123456789';

const router = require('../routes/puzzles');
const db = require('../db');
const { labelOf } = require('../services/endgameCatalog');

function lastHandler(method, path) {
  const layer = router.stack.find((l) => l.route && l.route.path === path && l.route.methods[method]);
  assert.ok(layer, `${method.toUpperCase()} ${path} must be mounted`);
  const stack = layer.route.stack.map((s) => s.handle);
  return stack[stack.length - 1];
}

async function call(method, path, { query = {}, params = {}, row }) {
  const handler = lastHandler(method, path);
  const original = db.pool.query;
  db.pool.query = async () => ({ rows: [row], rowCount: 1 });
  const sent = { status: 200, json: null };
  const res = {
    status(code) { sent.status = code; return res; },
    json(payload) { sent.json = payload; return res; },
  };
  try {
    await handler({ query, params, body: {}, user: { id: 5 } }, res);
  } finally {
    db.pool.query = original;
  }
  return sent;
}

const BLUNDER_ROW = {
  puzzle_id: 'bl-1', fen: '8/8/4k3/8/3PK3/8/8/7r w - - 0 50',
  // The type written the other way round from the normalised material, so a
  // label read from `endgame_type` says 'rook versus rook and pawn' and the
  // case sees it. Identical keys in both columns let that mutation survive.
  endgame_type: 'KRvKRP', mode: 'draw', side_to_move: 'w',
  winning_moves: ['d4d5'], solution: ['d4d5', 'h1h4'], solution_san: ['d5', 'Rh4+'],
  difficulty: 'medium', difficulty_score: 5, piece_count: 4, pawn_count: 1,
  source: 'blunder', material: 'KRPvKR', blunder_elo: 1900, played_move: 'Ke5',
  evaluation: null, wdl: 0, dtz: 0, game_white: 'A', game_black: 'B', game_date: '2001',
};

// A mined row: no material, its own seven-category type. The endgame_type is
// set to a key labelOf *can* read, so a label taken from the wrong column
// would not come out null and the case would see it.
const MINED_ROW = {
  ...BLUNDER_ROW,
  puzzle_id: 'mn-1', endgame_type: 'KQvKR', source: 'syzygy', material: null,
  blunder_elo: null, played_move: null, game_white: null,
};

const ROUTES = [
  ['/puzzles/endgame/next', (row) => call('get', '/puzzles/endgame/next', { row })],
  ['/puzzles/by-id?source=endgame', (row) => call('get', '/puzzles/by-id/:puzzleId', {
    row, params: { puzzleId: row.puzzle_id }, query: { source: 'endgame' },
  })],
];

for (const [name, ask] of ROUTES) {
  test(`${name}: a blunder row carries material_label = labelOf(material)`, async () => {
    const out = await ask(BLUNDER_ROW);
    assert.equal(out.status, 200);
    assert.equal(out.json.endgame.material_label, labelOf('KRPvKR'));
    assert.equal(out.json.endgame.material_label, 'rook and pawn versus rook');
  });

  test(`${name}: a row with no material carries material_label null, not ''`, async () => {
    const out = await ask(MINED_ROW);
    assert.equal(out.status, 200);
    assert.ok('material_label' in out.json.endgame, 'the key is sent');
    assert.equal(out.json.endgame.material_label, null);
  });

  test(`${name}: the stored line is not sent`, async () => {
    for (const row of [BLUNDER_ROW, MINED_ROW]) {
      const out = await ask(row);
      assert.equal('solution' in out.json.endgame, false);
      assert.equal('solution_san' in out.json.endgame, false);
    }
  });
}
