// reportService.js
// The monthly report a trainer sends to a parent.
//
// Two rules shape everything here:
//
// 1. It is written for a parent, not a coach. No Elo talk, no English theme
//    codes, no accuracy figure presented without saying how many puzzles it is
//    based on. A number a parent cannot interpret is worse than no number.
//
// 2. It is a snapshot. The figures are frozen when the trainer generates it, so
//    the link shows what was sent rather than what happens to be true later.

const { getStudentProgress } = require('./assignmentService');

/// Readable names for the Lichess motif tags.
///
/// The app has the same table (`themeLabels` in
/// `chess_app/lib/features/assignments/models/assignment.dart`), and both are
/// held to `test/fixtures/puzzle_themes.json`, which both suites read: the two
/// say the same words, every motif the server trains has them, and every
/// theme here is one a puzzle homework keeps (`homeworkThemes`). Until
/// 1.10.2026 they were kept in sync by hand, and six mate motifs had no words
/// on either side. Both still fall back to the raw tag.
const THEME_LABELS = {
  fork: 'fork',
  pin: 'pin',
  skewer: 'skewer',
  discoveredAttack: 'discovered attack',
  doubleCheck: 'double check',
  deflection: 'deflection',
  attraction: 'attraction',
  clearance: 'clearance',
  interference: 'interference',
  intermezzo: 'intermezzo',
  xRayAttack: 'x-ray attack',
  zugzwang: 'zugzwang',
  sacrifice: 'sacrifice',
  hangingPiece: 'hanging piece',
  trappedPiece: 'trapped piece',
  defensiveMove: 'defensive move',
  quietMove: 'quiet move',
  capturingDefender: 'capturing defender',
  exposedKing: 'exposed king',
  backRankMate: 'back-rank mate',
  smotheredMate: 'smothered mate',
  anastasiaMate: "Anastasia's mate",
  arabianMate: 'Arabian mate',
  bodenMate: "Boden's mate",
  doubleBishopMate: 'double bishop mate',
  dovetailMate: 'dovetail mate',
  hookMate: 'hook mate',
  advancedPawn: 'advanced pawn',
  promotion: 'promotion',
  underPromotion: 'underpromotion',
  attackingF2F7: 'attacking f2/f7',
  kingsideAttack: 'kingside attack',
  queensideAttack: 'queenside attack',
  enPassant: 'en passant',
  mateIn1: 'mate in 1',
  mateIn2: 'mate in 2',
  mateIn3: 'mate in 3',
  mateIn4: 'mate in 4',
  mateIn5: 'mate in 5',
  rookEndgame: 'rook endgame',
  pawnEndgame: 'pawn endgame',
  knightEndgame: 'knight endgame',
  bishopEndgame: 'bishop endgame',
};

/// Two names no new snapshot can hold. Until 1.10.2026 the mate drill and
/// winning positions stored their own names as themes (`POST /api/puzzles/
/// submit`), so a report frozen before then may list one; it is shown as it
/// was sent, in words (rules 1 and 2 above). Only this page needs them — the
/// app reads live figures, which count motifs only (puzzleProgress,
/// `motifsOf`) — so they stay out of the table the app shares. Links last 60
/// days (`REPORT_TTL_DAYS`): once this has been live that long, nothing reads
/// these and they can go.
const FROZEN_DRILL_LABELS = {
  mate_puzzle: 'mate puzzles',
  winning_position: 'winning positions',
};

function themeLabel(theme) {
  return THEME_LABELS[theme] || FROZEN_DRILL_LABELS[theme] || theme;
}

/// Escapes text that came from a person before it goes into HTML.
///
/// The trainer's note, the student's name and assignment titles are all
/// user-written and land in a page a parent opens. Without this, a stray angle
/// bracket breaks the layout and a deliberate one runs script in the reader's
/// browser.
function esc(value) {
  if (value === null || value === undefined) return '';
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function formatDate(date) {
  const d = new Date(date);
  return `${d.getDate()}. ${d.getMonth() + 1}. ${d.getFullYear()}.`;
}

/// Builds the frozen figures for one student over one period.
async function buildSnapshot(pool, { studentId, studentName, trainerName, days }) {
  const progress = await getStudentProgress(pool, studentId, { days });

  return {
    generatedAt: new Date().toISOString(),
    periodDays: days,
    studentName,
    trainerName,
    rating: progress.overallRating,
    ratingChange: progress.ratingChange ?? null,
    // Puzzles, each counted once, a skip apart from a failure, and the
    // accuracy over new puzzles met first in the period (summariseAttempts).
    puzzles: progress.puzzles,
    solved: progress.solved,
    skipped: progress.skipped,
    firstTries: progress.firstTries,
    accuracy: progress.accuracy,
    activeDays: progress.activeDays,
    lifetimeSolved: progress.lifetimeSolved,
    assignments: progress.assignments,
    strengths: progress.strongestThemes.slice(0, 3),
    toWorkOn: progress.weakestThemes.slice(0, 3),
  };
}

function plural(count, noun) {
  return `${count} ${count === 1 ? noun : `${noun}s`}`;
}

/// The page's figures, from either shape a stored snapshot has.
///
/// A snapshot is frozen when it is sent (rule 2 above). Those built before
/// 1.10.2026 counted attempts — a puzzle tried five times was five, a skip a
/// wrong answer — and say so in their own field names, `totalAttempts` and
/// `solvedAttempts`. They are read in those names and under their old labels,
/// so a link still shows what it showed when it was sent. Links last 60 days
/// (`REPORT_TTL_DAYS`), so this branch has nothing left to read after
/// 30.11.2026 and can go then.
function figuresOf(s) {
  if (s.puzzles === undefined) {
    return {
      seen: s.totalAttempts,
      solved: s.solvedAttempts,
      skipped: 0,
      solvedLabel: 'Puzzles solved correctly',
      accuracyLabel: 'Accuracy',
    };
  }
  return {
    seen: s.puzzles,
    solved: s.solved,
    skipped: s.skipped,
    solvedLabel: 'Puzzles solved',
    accuracyLabel: s.accuracy === null
      ? 'Solved at the first attempt'
      : `Solved at the first attempt, of ${plural(s.firstTries, 'new puzzle')}`,
  };
}

/// Whether a snapshot has anything to show. One rule for the page, which then
/// shows figures rather than "no practice recorded", and for the route that
/// tells the trainer which of the two the parent will see.
function snapshotHasData(s) {
  return figuresOf(s).seen > 0;
}

/// Renders the snapshot as a self-contained page.
///
/// Deliberately one file with inline styles and a print stylesheet: the parent
/// opens it on a phone from a messaging app, and the trainer prints it to PDF
/// from the browser when a paper copy is wanted.
function renderHtml(report) {
  const s = report.snapshot;
  const figures = figuresOf(s);
  const hasData = snapshotHasData(s);

  const themeList = (themes, emptyText) => {
    if (!themes || themes.length === 0) return `<p class="muted">${esc(emptyText)}</p>`;
    return `<ul class="themes">${themes
      .map(
        (t) =>
          `<li><span>${esc(themeLabel(t.theme))}</span><b>${t.accuracy}%</b>` +
          `<small>${plural(t.firstTries ?? t.attempts, 'puzzle')}</small></li>`
      )
      .join('')}</ul>`;
  };

  const ratingLine =
    s.ratingChange === null || s.ratingChange === undefined
      ? `<b>${s.rating}</b>`
      : `<b>${s.rating}</b> <span class="${s.ratingChange >= 0 ? 'up' : 'down'}">` +
        `${s.ratingChange >= 0 ? '+' : ''}${s.ratingChange}</span>`;

  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>Progress report — ${esc(s.studentName)}</title>
<style>
  :root {
    --ink: #1a1f1c; --muted: #6b7870; --line: #dde3dd;
    --bg: #ffffff; --panel: #f4f7f4; --accent: #2c6b4f; --warn: #9a6b12;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; padding: 24px 16px 56px; background: var(--bg); color: var(--ink);
    font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
    line-height: 1.55; font-size: 16px;
  }
  .sheet { max-width: 640px; margin: 0 auto; }
  header { border-bottom: 3px solid var(--ink); padding-bottom: 16px; margin-bottom: 24px; }
  .eyebrow { font-size: 12px; letter-spacing: .12em; text-transform: uppercase; color: var(--accent); font-weight: 700; }
  h1 { font-size: 26px; margin: 6px 0 4px; line-height: 1.2; }
  .sub { color: var(--muted); font-size: 14px; margin: 0; }
  h2 { font-size: 13px; letter-spacing: .1em; text-transform: uppercase; color: var(--accent);
       margin: 28px 0 10px; padding-bottom: 6px; border-bottom: 1px solid var(--line); }
  .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)); gap: 12px; }
  .stat { background: var(--panel); border-radius: 6px; padding: 14px; }
  .stat b { display: block; font-size: 24px; line-height: 1.1; }
  .stat span { font-size: 12.5px; color: var(--muted); }
  .up { color: var(--accent); font-size: 17px; }
  .down { color: var(--warn); font-size: 17px; }
  ul.themes { list-style: none; padding: 0; margin: 0; }
  ul.themes li { display: flex; align-items: baseline; gap: 10px; padding: 7px 0; border-bottom: 1px solid var(--line); }
  ul.themes li span { flex: 1; }
  ul.themes li b { font-variant-numeric: tabular-nums; }
  ul.themes li small { color: var(--muted); width: 92px; text-align: right; }
  .note { background: var(--panel); border-left: 3px solid var(--accent); padding: 14px 16px; border-radius: 0 6px 6px 0; }
  .note p { margin: 0; white-space: pre-wrap; }
  .muted { color: var(--muted); }
  footer { margin-top: 36px; padding-top: 14px; border-top: 1px solid var(--line); font-size: 12.5px; color: var(--muted); }
  @media print {
    body { padding: 0; font-size: 12pt; }
    .sheet { max-width: none; }
    .noprint { display: none; }
  }
</style>
</head>
<body>
<div class="sheet">

<header>
  <div class="eyebrow">Progress report</div>
  <h1>${esc(s.studentName)}</h1>
  <p class="sub">Period of ${s.periodDays} days &middot; generated ${formatDate(s.generatedAt)}${
    s.trainerName ? ` &middot; coach: ${esc(s.trainerName)}` : ''
  }</p>
</header>

${
  hasData
    ? `
<div class="grid">
  <div class="stat"><b>${ratingLine}</b><span>Puzzle solving rating</span></div>
  <div class="stat"><b>${figures.solved}/${figures.seen}</b><span>${figures.solvedLabel}</span></div>
  <div class="stat"><b>${s.accuracy === null ? '—' : `${s.accuracy}%`}</b><span>${esc(figures.accuracyLabel)}</span></div>${
    figures.skipped > 0
      ? `
  <div class="stat"><b>${figures.skipped}</b><span>Skipped</span></div>`
      : ''
  }
  <div class="stat"><b>${s.activeDays}</b><span>Days with practice</span></div>
</div>

<h2>What is going well</h2>
${themeList(s.strengths, 'Not enough puzzles solved yet to highlight a strong theme.')}

<h2>What we are working on next</h2>
${themeList(s.toWorkOn, 'Not enough puzzles solved yet to highlight a weak theme.')}
<p class="muted" style="font-size:13px">
  A theme is measured by how often its puzzles are solved at the first attempt, and only
  enters the report once the student has met several of them — a single missed puzzle
  does not mean it is a weakness.
</p>

<h2>Assignments</h2>
<div class="grid">
  <div class="stat"><b>${s.assignments?.completed ?? 0}/${s.assignments?.total ?? 0}</b><span>Completed assignments</span></div>
  <div class="stat"><b>${s.assignments?.overdue ?? 0}</b><span>Overdue</span></div>
</div>
`
    : `
<h2>This period</h2>
<p>There is no practice recorded in the last ${s.periodDays} days, so there are no
numbers in the report. This does not mean the student did not make progress in lessons —
only that they did not solve puzzles in the app.</p>
`
}

${
  report.note
    ? `<h2>Coach's message</h2><div class="note"><p>${esc(report.note)}</p></div>`
    : ''
}

<footer>
  This report was generated automatically from what the student did in the app.
  The numbers apply to the specified period and will not change retroactively.
  For questions, please contact the coach${s.trainerName ? ` (${esc(s.trainerName)})` : ''}.
</footer>

</div>
</body>
</html>`;
}

module.exports = {
  THEME_LABELS, themeLabel, esc, buildSnapshot, renderHtml, formatDate, snapshotHasData,
};
