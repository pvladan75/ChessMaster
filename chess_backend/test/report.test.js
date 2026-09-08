// report.test.js
// Covers the parent report's rendering.
//
// This page is the one artefact that leaves the app and lands in front of
// someone who is not a user, so two things matter: nothing user-written can
// break out into markup, and no number is shown in a way a parent would
// misread.

const test = require('node:test');
const assert = require('node:assert/strict');

const { esc, themeLabel, renderHtml, formatDate } = require('../services/reportService');

function snapshot(overrides = {}) {
  return {
    generatedAt: '2026-08-15T10:00:00Z',
    periodDays: 30,
    studentName: 'Marko Petrović',
    trainerName: 'Vladan',
    rating: 1620,
    ratingChange: 45,
    totalAttempts: 40,
    solvedAttempts: 26,
    accuracy: 65,
    activeDays: 9,
    lifetimeSolved: 210,
    assignments: { total: 6, completed: 4, overdue: 1 },
    strengths: [{ theme: 'fork', attempts: 12, solved: 11, accuracy: 92 }],
    toWorkOn: [{ theme: 'pin', attempts: 8, solved: 2, accuracy: 25 }],
    ...overrides,
  };
}

test('escapes every character that could break out into markup', () => {
  assert.equal(esc('<script>alert(1)</script>'), '&lt;script&gt;alert(1)&lt;/script&gt;');
  assert.equal(esc(`" & '`), '&quot; &amp; &#39;');
  assert.equal(esc(null), '');
  assert.equal(esc(undefined), '');
  assert.equal(esc(42), '42');
});

test('a trainer note cannot inject script into the parent\'s page', () => {
  const html = renderHtml({
    snapshot: snapshot(),
    note: '<img src=x onerror="alert(document.cookie)">Dobar napredak',
  });

  // The note is written by a person and read by another; unescaped it would run.
  assert.ok(!html.includes('<img src=x'), 'raw tag must not survive into the page');
  assert.ok(html.includes('&lt;img src=x'));
  assert.ok(html.includes('Dobar napredak'));
});

test('a student name with markup characters is escaped too', () => {
  const html = renderHtml({ snapshot: snapshot({ studentName: 'Ana <b>Test</b>' }) });

  assert.ok(html.includes('Ana &lt;b&gt;Test&lt;/b&gt;'));
  // Including in the <title>, which is the other place it lands.
  assert.ok(!html.includes('<title>Progress report — Ana <b>'));
});

test('motif codes are shown with readable labels, not as raw tags', () => {
  const html = renderHtml({ snapshot: snapshot({
    strengths: [{ theme: 'doubleCheck', attempts: 12, solved: 11, accuracy: 92 }],
    toWorkOn: [{ theme: 'hangingPiece', attempts: 8, solved: 2, accuracy: 25 }],
  }) });

  // A parent cannot be expected to know what "hangingPiece" means.
  assert.ok(html.includes('double check'));
  assert.ok(html.includes('hanging piece'));
  assert.ok(!html.includes('>doubleCheck<'));
  assert.ok(!html.includes('>hangingPiece<'));
});

test('an unknown motif falls back to its raw tag rather than disappearing', () => {
  assert.equal(themeLabel('brandNewTheme'), 'brandNewTheme');

  const html = renderHtml({
    snapshot: snapshot({ toWorkOn: [{ theme: 'brandNewTheme', attempts: 5, accuracy: 40 }] }),
  });
  assert.ok(html.includes('brandNewTheme'));
});

test('every theme line states how many attempts it is based on', () => {
  const html = renderHtml({ snapshot: snapshot() });

  // "25%" alone invites a parent to read a bad month as a verdict; "8 puzzles"
  // is what makes it interpretable.
  assert.ok(html.includes('8 puzzles'));
  assert.ok(html.includes('12 puzzles'));
});

test('a single attempt is counted in the singular', () => {
  const html = renderHtml({
    snapshot: snapshot({ toWorkOn: [{ theme: 'pin', attempts: 1, accuracy: 0 }] }),
  });
  assert.ok(html.includes('1 puzzle<'), 'English singular, not "1 puzzles"');
});

test('a period with no activity says so instead of showing zeroes', () => {
  const html = renderHtml({
    snapshot: snapshot({
      totalAttempts: 0,
      solvedAttempts: 0,
      accuracy: null,
      activeDays: 0,
      ratingChange: null,
      strengths: [],
      toWorkOn: [],
    }),
  });

  assert.ok(html.includes('no practice recorded'));
  // A wall of zeroes would read as failure rather than as absence of data.
  assert.ok(!html.includes('Accuracy'));
  assert.ok(html.includes('does not mean the student'));
});

test('an unknown accuracy renders as a dash, never as 0%', () => {
  const html = renderHtml({ snapshot: snapshot({ accuracy: null }) });
  assert.ok(html.includes('<b>—</b>'));
});

test('rating movement is signed, and absent when there is nothing to compare', () => {
  assert.ok(renderHtml({ snapshot: snapshot({ ratingChange: 45 }) }).includes('+45'));
  assert.ok(renderHtml({ snapshot: snapshot({ ratingChange: -20 }) }).includes('-20'));

  const flat = renderHtml({ snapshot: snapshot({ ratingChange: null }) });
  assert.ok(!flat.includes('+0'), 'no data must not be dressed up as no change');
});

test('empty theme lists explain themselves rather than rendering blank', () => {
  const html = renderHtml({ snapshot: snapshot({ strengths: [], toWorkOn: [] }) });
  assert.ok(html.includes('Not enough puzzles solved yet'));
});

test('the note section is omitted entirely when the trainer wrote nothing', () => {
  assert.ok(!renderHtml({ snapshot: snapshot() }).includes("Coach's message"));
  assert.ok(renderHtml({ snapshot: snapshot(), note: 'Bravo!' }).includes("Coach's message"));
});

test('the page asks not to be indexed', () => {
  const html = renderHtml({ snapshot: snapshot() });
  assert.ok(html.includes('noindex'));
});

test('dates render in Serbian day-first order', () => {
  assert.equal(formatDate('2026-08-15T10:00:00Z'), '15. 8. 2026.');
});
