// Grouping positioned spans into diagrams.
//
// Deliberately structural rather than keyed on a diagram number: the first test
// book numbers every diagram, the second numbers none, and a parser that keys on
// the number finds 0 of 211 diagrams in the second book while reporting success.
// Eight rows of diagram glyphs stacked in one column *is* the diagram.
import { rowToFenRank } from './fonts.mjs';
import { mergeSpans } from './pdf.mjs';

const COLUMN_TOLERANCE = 3; // px; rows of one diagram share an x almost exactly
const GAP_FACTOR = 1.6; // a gap this much larger than typical ends a diagram

/** Spans that look like a row of diagram glyphs for this map. */
export function diagramRows(spans, map) {
  const alphabet = new Set(Object.keys(map.glyphs));
  return spans.filter((s) => {
    const t = s.text;
    const isLenValid = Array.isArray(map.rowLength)
      ? map.rowLength.includes(t.length)
      : t.length === map.rowLength;
    if (!isLenValid) return false;
    if (map.isBorderRow(t)) return false;
    return [...map.squares(t)].every((c) => alphabet.has(c));
  });
}

/** Group rows sharing an x into vertical runs, cutting on unusually large gaps. */
function runsByColumn(rows) {
  const columns = [];
  for (const row of [...rows].sort((a, b) => a.x - b.x || a.y - b.y)) {
    const col = columns.find((c) => Math.abs(c.x - row.x) <= COLUMN_TOLERANCE);
    if (col) col.rows.push(row);
    else columns.push({ x: row.x, rows: [row] });
  }

  const runs = [];
  for (const col of columns) {
    const sorted = col.rows.sort((a, b) => a.y - b.y);
    const gaps = sorted.slice(1).map((r, i) => r.y - sorted[i].y);
    const typical = gaps.length ? [...gaps].sort((a, b) => a - b)[Math.floor(gaps.length / 2)] : 0;
    let run = [sorted[0]];
    for (let i = 1; i < sorted.length; i += 1) {
      const gap = sorted[i].y - sorted[i - 1].y;
      if (typical > 0 && gap > typical * GAP_FACTOR) {
        runs.push(run);
        run = [];
      }
      run.push(sorted[i]);
    }
    if (run.length) runs.push(run);
  }
  return runs;
}

/**
 * The label printed above a diagram, when the book prints one.
 *
 * Two things sit near the top-left of a board and both are digits: the diagram
 * number, and the rank coordinates 8..1 running down the left margin. Taking the
 * nearest one picks the rank label and numbers every diagram in the book "8".
 * The number is set above the board and never left of its edge; the coordinates
 * are level with their rank and always in the margin.
 */
function labelAbove(spans, firstRow, rowSpacing) {
  const minRise = 0.4 * rowSpacing;
  let best = null;
  for (const s of spans) {
    if (!/^\d{1,4}$/.test(s.text.trim())) continue;
    if (s.x < firstRow.x - 4 || s.x > firstRow.x + 60) continue; // not the margin coordinates
    const rise = firstRow.y - s.y;
    if (rise < minRise || rise > 3 * rowSpacing) continue;
    if (!best || s.y > best.y) best = s;
  }
  return best ? best.text.trim() : null;
}

/**
 * Diagrams on one page: { label, page, x, y, rows, placement }.
 * `placement` is the board part of a FEN — side to move and rights are decided
 * later, from the book's own solution, not guessed here.
 */
export function extractDiagrams(rawSpans, map, pageNo) {
  const spans = mergeSpans(rawSpans);
  const rows = diagramRows(spans, map);
  const out = [];
  const anomalies = [];

  for (const run of runsByColumn(rows)) {
    if (run.length === 0) continue;
    if (run.length % 8 !== 0) {
      anomalies.push({ page: pageNo, x: run[0].x, y: run[0].y, rowCount: run.length });
      continue;
    }
    for (let start = 0; start < run.length; start += 8) {
      const eight = run.slice(start, start + 8);
      const where = `str. ${pageNo}, x=${eight[0].x.toFixed(0)}, y=${eight[0].y.toFixed(0)}`;
      const placement = eight.map((r) => rowToFenRank(r.text, map, where)).join('/');
      const rowSpacing = (eight[7].y - eight[0].y) / 7;
      out.push({
        label: labelAbove(spans, eight[0], rowSpacing),
        page: pageNo,
        x: eight[0].x,
        y: eight[0].y,
        placement,
      });
    }
  }

  out.sort((a, b) => a.y - b.y || a.x - b.x);
  return { diagrams: out, anomalies };
}
