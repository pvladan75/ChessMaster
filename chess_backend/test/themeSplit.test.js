const test = require('node:test');
const assert = require('node:assert/strict');

const { summariseAttempts } = require('../services/assignmentService');

/// Builds `count` attempt rows for one theme, `solved` of them correct.
function attempts(theme, count, solved) {
  return Array.from({ length: count }, (_, i) => ({
    themes: [theme],
    solved: i < solved,
  }));
}

test('a theme is never both a strength and a weakness', () => {
  // The bug as it reached a parent: with only two measured themes, the report
  // listed 25% under "what is going well" and 70% under "what we work on
  // next" — the same two lines twice, in both directions.
  const rows = [
    ...attempts('dvojni napad', 10, 7), // 70%
    ...attempts('izložen kralj', 4, 1), // 25%
  ];
  const summary = summariseAttempts(rows);

  const strong = summary.strongestThemes.map((t) => t.theme);
  const weak = summary.weakestThemes.map((t) => t.theme);

  assert.deepEqual(strong, ['dvojni napad']);
  assert.deepEqual(weak, ['izložen kralj']);
  assert.equal(strong.filter((t) => weak.includes(t)).length, 0);
});

test('a middling theme is neither, and says so by absence', () => {
  // "You get about three fifths of these right" is not a headline in either
  // direction. It still appears in the full per-theme list.
  const summary = summariseAttempts(attempts('vezivanje', 10, 6)); // 60%
  assert.deepEqual(summary.strongestThemes, []);
  assert.deepEqual(summary.weakestThemes, []);
  assert.equal(summary.themes.length, 1, 'but it is still reported among all themes');
});

test('a single strong theme still counts as a strength', () => {
  const summary = summariseAttempts(attempts('dvojni napad', 8, 8));
  assert.deepEqual(summary.strongestThemes.map((t) => t.theme), ['dvojni napad']);
  assert.deepEqual(summary.weakestThemes, []);
});

test('a single weak theme still counts as a weakness', () => {
  const summary = summariseAttempts(attempts('izložen kralj', 8, 1));
  assert.deepEqual(summary.weakestThemes.map((t) => t.theme), ['izložen kralj']);
  assert.deepEqual(summary.strongestThemes, []);
});

test('too few attempts means unmeasured, not weak', () => {
  // One missed puzzle must never be reported to a parent as a weak side.
  const summary = summariseAttempts(attempts('vezivanje', 2, 0));
  assert.deepEqual(summary.weakestThemes, []);
  assert.deepEqual(summary.strongestThemes, []);
});

test('strengths come best first, weaknesses worst first', () => {
  const rows = [
    ...attempts('a', 10, 8), // 80%
    ...attempts('b', 10, 10), // 100%
    ...attempts('c', 10, 1), // 10%
    ...attempts('d', 10, 4), // 40%
  ];
  const summary = summariseAttempts(rows);
  assert.deepEqual(summary.strongestThemes.map((t) => t.theme), ['b', 'a']);
  assert.deepEqual(summary.weakestThemes.map((t) => t.theme), ['c', 'd']);
});

test('no attempts at all produces no claims', () => {
  const summary = summariseAttempts([]);
  assert.equal(summary.accuracy, null, 'accuracy must not divide by zero');
  assert.deepEqual(summary.strongestThemes, []);
  assert.deepEqual(summary.weakestThemes, []);
});
