const test = require('node:test');
const assert = require('node:assert/strict');

const { summariseAttempts } = require('../services/assignmentService');

/// Builds `count` puzzles of one theme, each met once, `solved` of them
/// solved at that first meeting. One row per puzzle, each with its own id:
/// since 1.10.2026 the summary counts puzzles (`puzzlesOf`), not rows.
///
/// The themes are real Lichess motif tags. Since 1.10.2026 a row counts only
/// under motifs the server trains (puzzleProgress, `motifsOf`), and the names
/// these cases used before — 'dvojni napad', 'izložen kralj', 'vezivanje',
/// 'a' to 'd' — are not motifs: they dropped out of every list, and „too few
/// attempts means unmeasured" passed for that reason alone. Renamed, not
/// rewritten: each case asserts what it asserted.
let serial = 0;
function attempts(theme, count, solved) {
  return Array.from({ length: count }, (_, i) => {
    serial += 1;
    return {
      puzzle_id: `${theme}-${serial}`,
      source: 'lichess',
      themes: [theme],
      solved: i < solved,
      created_at: new Date(Date.UTC(2026, 7, 15, 0, 0, serial)).toISOString(),
    };
  });
}

test('a theme is never both a strength and a weakness', () => {
  // The bug as it reached a parent: with only two measured themes, the report
  // listed 25% under "what is going well" and 70% under "what we work on
  // next" — the same two lines twice, in both directions.
  const rows = [
    ...attempts('fork', 10, 7), // 70%
    ...attempts('exposedKing', 4, 1), // 25%
  ];
  const summary = summariseAttempts(rows);

  const strong = summary.strongestThemes.map((t) => t.theme);
  const weak = summary.weakestThemes.map((t) => t.theme);

  assert.deepEqual(strong, ['fork']);
  assert.deepEqual(weak, ['exposedKing']);
  assert.equal(strong.filter((t) => weak.includes(t)).length, 0);
});

test('a middling theme is neither, and says so by absence', () => {
  // "You get about three fifths of these right" is not a headline in either
  // direction. It still appears in the full per-theme list.
  const summary = summariseAttempts(attempts('pin', 10, 6)); // 60%
  assert.deepEqual(summary.strongestThemes, []);
  assert.deepEqual(summary.weakestThemes, []);
  assert.equal(summary.themes.length, 1, 'but it is still reported among all themes');
});

test('a single strong theme still counts as a strength', () => {
  const summary = summariseAttempts(attempts('fork', 8, 8));
  assert.deepEqual(summary.strongestThemes.map((t) => t.theme), ['fork']);
  assert.deepEqual(summary.weakestThemes, []);
});

test('a single weak theme still counts as a weakness', () => {
  const summary = summariseAttempts(attempts('exposedKing', 8, 1));
  assert.deepEqual(summary.weakestThemes.map((t) => t.theme), ['exposedKing']);
  assert.deepEqual(summary.strongestThemes, []);
});

test('too few attempts means unmeasured, not weak', () => {
  // One missed puzzle must never be reported to a parent as a weak side.
  const summary = summariseAttempts(attempts('pin', 2, 0));
  assert.deepEqual(summary.weakestThemes, []);
  assert.deepEqual(summary.strongestThemes, []);
});

test('strengths come best first, weaknesses worst first', () => {
  const rows = [
    ...attempts('fork', 10, 8), // 80%
    ...attempts('pin', 10, 10), // 100%
    ...attempts('skewer', 10, 1), // 10%
    ...attempts('deflection', 10, 4), // 40%
  ];
  const summary = summariseAttempts(rows);
  assert.deepEqual(summary.strongestThemes.map((t) => t.theme), ['pin', 'fork']);
  assert.deepEqual(summary.weakestThemes.map((t) => t.theme), ['skewer', 'deflection']);
});

test('no attempts at all produces no claims', () => {
  const summary = summariseAttempts([]);
  assert.equal(summary.accuracy, null, 'accuracy must not divide by zero');
  assert.deepEqual(summary.strongestThemes, []);
  assert.deepEqual(summary.weakestThemes, []);
});
