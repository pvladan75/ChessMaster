// homework_themes.test.js — what a puzzle homework may ask for, and the words
// for it, held to one list both ends read (test/fixtures/puzzle_themes.json;
// the app's half is chess_app/test/homework_themes_test.dart).
//
// Found 1.10.2026: both homework dialogs offered „rook endgame" and „pawn
// endgame", and the server kept only the motifs it trains (`trainableThemes`),
// so a homework of rook endgames went out as puzzles of any kind, with no word
// said. The owner chose (a): a game phase is a filter a homework keeps, never
// rated and never in the report. Six motifs the server trains had no words
// either, so the parent report would have printed „anastasiaMate 30%".

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');

const selection = require('../services/puzzleSelectionService');
const { THEME_LABELS } = require('../services/reportService');
const { resolvePuzzles, createPuzzleAssignment } = require('../services/assignmentService');
const { parseHomework } = require('../services/homeworkTemplate');

const shared = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'fixtures', 'puzzle_themes.json'), 'utf8')
);
const sorted = (list) => [...list].sort();

test('the server trains, and filters by, exactly the shared list', () => {
  assert.deepEqual(sorted(selection.TRAINABLE_THEMES), sorted(shared.motifs));
  assert.deepEqual(sorted(selection.PHASE_THEMES), sorted(shared.phases));
});

test('the parent report has words for every motif, the same words the app has', () => {
  assert.deepEqual(THEME_LABELS, shared.labels);
  assert.deepEqual(shared.motifs.filter((theme) => !(theme in THEME_LABELS)), [],
    'a motif with no words is printed as its tag');
});

test('every theme with words is one a homework keeps', () => {
  // The homework editor offers a chip for every labelled theme: one the server
  // dropped would be a chip that does nothing.
  const labelled = Object.keys(shared.labels);
  assert.deepEqual(selection.homeworkThemes(labelled), labelled);
});

test('a homework keeps the motifs and the game phases, and drops the rest', () => {
  assert.deepEqual(
    selection.homeworkThemes([
      'rookEndgame', 'fork', 'crushing', 'pawnEndgame', 'mate_puzzle', 'mateIn2', 'long', 'endgame',
    ]),
    ['rookEndgame', 'fork', 'pawnEndgame', 'mateIn2', 'endgame']
  );
  // A phase narrows a homework and is still not a skill: what rates, selects
  // and reports reads `trainableThemes`, which does not take it.
  assert.deepEqual(selection.trainableThemes(['rookEndgame', 'fork']), ['fork']);
});

test('a homework of rook endgames asks the pool for rook endgames', async () => {
  const calls = [];
  const pool = {
    async query(text, params) {
      calls.push({ text, params });
      return { rows: [{ puzzle_id: 'a', rating: 1500 }] };
    },
  };
  await resolvePuzzles(pool, { studentId: 7, themes: ['rookEndgame'], count: 5 });

  assert.match(calls[0].text, /themes && \$/);
  assert.deepEqual(calls[0].params.filter(Array.isArray), [['rookEndgame']]);
});

test('the drill a trainer assigns stores the endgame it was asked for', async () => {
  const inserted = [];
  const client = {
    async query(text, params) {
      if (/INSERT INTO assignments/.test(text)) {
        inserted.push(params);
        return { rows: [{ id: 41 }] };
      }
      return { rows: [] };
    },
    release() {},
  };
  const pool = {
    async query(text) {
      if (/FROM trainer_students/.test(text)) return { rows: [{ '?column?': 1 }] };
      if (/FROM lichess_puzzles/.test(text)) return { rows: [{ puzzle_id: 'a', rating: 1500 }] };
      throw new Error(`unexpected query: ${text}`);
    },
    async connect() { return client; },
  };

  const out = await createPuzzleAssignment(pool, {
    trainerId: 1, studentId: 2, title: 'Rook endgames',
    themes: ['rookEndgame', 'pawnEndgame', 'crushing'], count: 3,
  });

  assert.equal(out.ok, true, out.reason);
  assert.deepEqual(inserted[0][4], ['rookEndgame', 'pawnEndgame']);
});

test('a homework the editor writes keeps the endgame it was asked for', () => {
  const parsed = parseHomework({
    title: 'Endgames',
    items: [{ kind: 'puzzles', task: { count: 5, themes: ['rookEndgame', 'pin', 'mate_puzzle', 'pawnEndgame'] } }],
  });

  assert.equal(parsed.ok, true, parsed.error);
  assert.deepEqual(parsed.homework.items[0].task.themes, ['rookEndgame', 'pin', 'pawnEndgame']);
});
