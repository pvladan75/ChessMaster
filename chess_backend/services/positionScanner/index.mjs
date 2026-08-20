// Scanning a PDF into candidate positions.
//
// This is the library the HTTP route uses; `scan.mjs` is the same thing with a
// command line around it.
//
// Two limits are deliberate:
//
//   * A request scans a **page range**, not a book. The droplet has one vCPU,
//     and the first test book takes about a third of a second per page — a
//     thousand-page catalogue would hold a request open for seven minutes and
//     starve every other caller. A trainer preparing a lesson wants a chapter
//     anyway.
//   * Solutions are **optional**. In a course they sit a few pages after the
//     diagrams; in a catalogue they are two hundred pages away, and reading
//     them would cost more than the scan. Without them the side to move is
//     simply unknown, which is a thing the confirmation screen can ask.
import { openPdf, pageSpans, fontNames } from './pdf.mjs';
import { selectFontMap, unknownGlyphs } from './fonts.mjs';
import { extractDiagrams } from './diagrams.mjs';
import { readSolutions } from './solutions.mjs';
import { buildPosition } from './verify.mjs';

export const MAX_PAGES_PER_SCAN = 40;

export class ScanError extends Error {
  constructor(message, { code = 'scan_failed', details = null } = {}) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

function clampRange(from, to, pageCount, label) {
  const start = Math.max(1, Math.min(Number(from) || 1, pageCount));
  const end = Math.max(start, Math.min(Number(to) || start, pageCount));
  if (end - start + 1 > MAX_PAGES_PER_SCAN) {
    throw new ScanError(
      `Najviše ${MAX_PAGES_PER_SCAN} strana po prolazu (${label}).`,
      { code: 'range_too_large' }
    );
  }
  return { start, end };
}

/**
 * Marks every diagram whose printed number is not unique in the book.
 *
 * A solution is found by the number over the diagram, which assumes the number
 * identifies exactly one. In the first book it does. The second prints a
 * numbered final test at the back *and* numbered examples in the text, so its
 * number 6 stands over two different boards — and both were handed the same
 * solution. One then read as "the book's move is not legal", which blamed the
 * glyph map for a problem it did not have.
 *
 * Neither copy is guessed at. Both are marked for a human, like everything else
 * here that cannot be settled from the page.
 *
 * Exported because `scan.mjs` walks the same diagrams to measure a book, and a
 * guard only one of the two paths applies is worse than none: the tool that
 * reports the numbers would disagree with the library that feeds the app.
 */
export function flagDuplicateNumbers(positions, numberOf = (p) => p.label) {
  const byNumber = new Map();
  for (const position of positions) {
    const raw = numberOf(position);
    if (raw === null || raw === undefined) continue;
    const key = Number(raw);
    if (!byNumber.has(key)) byNumber.set(key, []);
    byNumber.get(key).push(position);
  }

  for (const [number, sharing] of byNumber) {
    if (sharing.length < 2) continue;
    const pages = sharing.map((p) => p.page).join(', ');
    for (const position of sharing) {
      position.solutionLegal = null;
      position.problem = `broj ${number} stoji na više dijagrama (strane ${pages}) — rešenje se ne može vezati`;
    }
  }
  return positions;
}

/**
 * Scan one page range of a PDF.
 *
 * Returns candidates, never saved rows: nothing here decides what is worth
 * keeping. Positions the parser is unsure about carry `problem` and travel with
 * the rest rather than being dropped, because a scanner that silently discards
 * what it could not read is the failure this whole pipeline is built to avoid.
 */
export async function scanDocument({
  filePath,
  fromPage = 1,
  toPage = MAX_PAGES_PER_SCAN,
  solutionsFrom = null,
  solutionsTo = null,
}) {
  const doc = await openPdf(filePath);
  const pageCount = doc.numPages;
  const { start, end } = clampRange(fromPage, toPage, pageCount, 'dijagrami');

  // Pick the glyph map from a sample of the requested range. Selection goes by
  // alphabet, not font name: the second test book calls its diagram font
  // `TTE2BEAF20t00`, which identifies nothing.
  const sample = [];
  const step = Math.max(1, Math.floor((end - start) / 8));
  for (let p = start; p <= end && sample.length < 400; p += step) {
    for (const s of await pageSpans(doc, p)) {
      if (!/\s/.test(s.text) && s.text.length >= 8 && s.text.length <= 12) sample.push(s.text);
    }
  }

  const picked = selectFontMap(sample);
  if (!picked) {
    throw new ScanError(
      'Dijagrami u ovoj knjizi koriste font koji još ne znamo da čitamo.',
      { code: 'unknown_font', details: { unknownGlyphs: unknownGlyphs(sample).slice(0, 20) } }
    );
  }
  const map = picked.map;

  let solutions = new Map();
  if (solutionsFrom) {
    const range = clampRange(solutionsFrom, solutionsTo ?? solutionsFrom, pageCount, 'rešenja');
    solutions = await readSolutions(doc, range.start, range.end);
  }

  const positions = [];
  const anomalies = [];
  const glyphErrors = [];

  for (let page = start; page <= end; page += 1) {
    let result;
    try {
      result = extractDiagrams(await pageSpans(doc, page), map, page);
    } catch (err) {
      glyphErrors.push({ page, message: err.message });
      continue;
    }
    anomalies.push(...result.anomalies);

    for (const diagram of result.diagrams) {
      const id = diagram.label ? Number(diagram.label) : null;
      const solution = id !== null ? solutions.get(id) : undefined;
      const built = buildPosition(diagram, solution);
      positions.push({
        label: diagram.label,
        page,
        fen: built.fen,
        sideToMove: built.side,
        sideSource: built.sideSource,
        solutionSan: built.solutionLegal ? built.solutionSan : (solution?.san ?? null),
        solutionLegal: built.solutionLegal,
        themesText: solution?.tail || null,
        repairs: built.repairs,
        problem: built.problem,
      });
    }
  }

  flagDuplicateNumbers(positions);

  let fonts = [];
  try {
    fonts = [...new Set((await fontNames(doc, start)).values())];
  } catch {
    fonts = []; // diagnostics only; a scan is not worth failing over a font name
  }

  return {
    pageCount,
    scannedFrom: start,
    scannedTo: end,
    font: map.label,
    fontsOnPage: fonts,
    positions,
    anomalies,
    glyphErrors,
  };
}
