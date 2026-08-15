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

/// Serbian names for the Lichess motif tags.
///
/// Duplicated from `chess_app/lib/features/assignments/models/assignment.dart`,
/// which needs the same table for the in-app UI. Kept in sync by hand — new
/// Lichess themes appear rarely, and both sides fall back to the raw tag, so a
/// missed entry degrades to "untranslated" rather than "missing".
const THEME_LABELS = {
  fork: 'dvojni napad',
  pin: 'vezivanje',
  skewer: 'ražanj',
  discoveredAttack: 'otkriveni napad',
  doubleCheck: 'dvostruki šah',
  deflection: 'odvlačenje',
  attraction: 'privlačenje',
  clearance: 'oslobađanje polja',
  interference: 'presecanje',
  intermezzo: 'međupotez',
  xRayAttack: 'rendgenski napad',
  zugzwang: 'cugcvang',
  sacrifice: 'žrtva',
  hangingPiece: 'nezaštićena figura',
  trappedPiece: 'uhvaćena figura',
  defensiveMove: 'odbrambeni potez',
  quietMove: 'tihi potez',
  capturingDefender: 'uklanjanje branioca',
  exposedKing: 'izložen kralj',
  backRankMate: 'mat po zadnjoj liniji',
  smotheredMate: 'ugušeni mat',
  advancedPawn: 'napredovali pešak',
  promotion: 'promocija',
  underPromotion: 'potpromocija',
  attackingF2F7: 'napad na f2/f7',
  kingsideAttack: 'napad na kraljevom krilu',
  queensideAttack: 'napad na daminom krilu',
  enPassant: 'en passant',
  mateIn1: 'mat u 1',
  mateIn2: 'mat u 2',
  mateIn3: 'mat u 3',
  mateIn4: 'mat u 4',
  mateIn5: 'mat u 5',
  rookEndgame: 'topovska završnica',
  pawnEndgame: 'pešačka završnica',
  knightEndgame: 'skakačka završnica',
  bishopEndgame: 'lovačka završnica',
};

function themeLabel(theme) {
  return THEME_LABELS[theme] || theme;
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
    totalAttempts: progress.totalAttempts,
    solvedAttempts: progress.solvedAttempts,
    accuracy: progress.accuracy,
    activeDays: progress.activeDays,
    lifetimeSolved: progress.lifetimeSolved,
    assignments: progress.assignments,
    strengths: progress.strongestThemes.slice(0, 3),
    toWorkOn: progress.weakestThemes.slice(0, 3),
  };
}

/// Renders the snapshot as a self-contained page.
///
/// Deliberately one file with inline styles and a print stylesheet: the parent
/// opens it on a phone from a messaging app, and the trainer prints it to PDF
/// from the browser when a paper copy is wanted.
function renderHtml(report) {
  const s = report.snapshot;
  const hasData = s.totalAttempts > 0;

  const themeList = (themes, emptyText) => {
    if (!themes || themes.length === 0) return `<p class="muted">${esc(emptyText)}</p>`;
    return `<ul class="themes">${themes
      .map(
        (t) =>
          `<li><span>${esc(themeLabel(t.theme))}</span><b>${t.accuracy}%</b>` +
          `<small>${t.attempts} ${t.attempts === 1 ? 'zadatak' : 'zadataka'}</small></li>`
      )
      .join('')}</ul>`;
  };

  const ratingLine =
    s.ratingChange === null || s.ratingChange === undefined
      ? `<b>${s.rating}</b>`
      : `<b>${s.rating}</b> <span class="${s.ratingChange >= 0 ? 'up' : 'down'}">` +
        `${s.ratingChange >= 0 ? '+' : ''}${s.ratingChange}</span>`;

  return `<!doctype html>
<html lang="sr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>Izveštaj o napretku — ${esc(s.studentName)}</title>
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
  <div class="eyebrow">Izveštaj o napretku</div>
  <h1>${esc(s.studentName)}</h1>
  <p class="sub">Period od ${s.periodDays} dana &middot; sastavljeno ${formatDate(s.generatedAt)}${
    s.trainerName ? ` &middot; trener: ${esc(s.trainerName)}` : ''
  }</p>
</header>

${
  hasData
    ? `
<div class="grid">
  <div class="stat"><b>${ratingLine}</b><span>Rejting u rešavanju zagonetki</span></div>
  <div class="stat"><b>${s.solvedAttempts}/${s.totalAttempts}</b><span>Tačno rešenih zadataka</span></div>
  <div class="stat"><b>${s.accuracy === null ? '—' : `${s.accuracy}%`}</b><span>Tačnost</span></div>
  <div class="stat"><b>${s.activeDays}</b><span>Dana sa vežbanjem</span></div>
</div>

<h2>Šta ide dobro</h2>
${themeList(s.strengths, 'Još nema dovoljno rešenih zadataka da bismo izdvojili jaku stranu.')}

<h2>Na čemu radimo dalje</h2>
${themeList(s.toWorkOn, 'Još nema dovoljno rešenih zadataka da bismo izdvojili slabu stranu.')}
<p class="muted" style="font-size:13px">
  Tema ulazi u izveštaj tek kada dete uradi nekoliko zadataka iz nje — jedan
  promašen zadatak ne znači da je to slaba strana.
</p>

<h2>Domaći zadaci</h2>
<div class="grid">
  <div class="stat"><b>${s.assignments?.completed ?? 0}/${s.assignments?.total ?? 0}</b><span>Završenih zadataka</span></div>
  <div class="stat"><b>${s.assignments?.overdue ?? 0}</b><span>Van roka</span></div>
</div>
`
    : `
<h2>Ovaj period</h2>
<p>U poslednjih ${s.periodDays} dana nema zabeleženog vežbanja, pa u izveštaju
nema brojeva. To ne znači da dete nije napredovalo na časovima — samo da nije
rešavalo zadatke u aplikaciji.</p>
`
}

${
  report.note
    ? `<h2>Poruka trenera</h2><div class="note"><p>${esc(report.note)}</p></div>`
    : ''
}

<footer>
  Izveštaj je sastavljen automatski iz onoga što je dete uradilo u aplikaciji.
  Brojevi se odnose na navedeni period i ne menjaju se naknadno.
  Za pitanja se obratite treneru${s.trainerName ? ` (${esc(s.trainerName)})` : ''}.
</footer>

</div>
</body>
</html>`;
}

module.exports = { THEME_LABELS, themeLabel, esc, buildSnapshot, renderHtml, formatDate };
