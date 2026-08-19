// Deriving a glyph map for a book we have never seen.
//
//   node derive.mjs <file.pdf> [--pages 6-79]
//
// Writing a map by hand means staring at 48 glyphs and guessing which one is a
// dark-square black knight. The book answers most of it itself:
//
//   * a glyph carries its square colour, so it can only ever appear on one
//     colour — that halves the problem and catches a bad row split;
//   * the two commonest glyphs are the empty squares;
//   * exactly one king of each colour stands on every diagram;
//   * pawns never stand on the first or the eighth rank.
//
// What is left after that is which piece is which, and that is settled by the
// book's own test solutions rather than by eye.
import { openPdf, pageSpans, mergeSpans } from './pdf.mjs';

const FILES = 'abcdefgh';

/** Rows of a bordered diagram: label glyph, eight squares, border glyph. */
function boardRows(spans) {
  return spans.filter((s) => s.text.length >= 10 && s.text.length <= 11);
}

/**
 * Diagrams as 8x8 glyph grids, found structurally: a run of ten rows in one
 * column is a top border, eight ranks and a bottom border.
 */
function rawDiagrams(spans, pageNo) {
  const rows = boardRows(spans);
  const columns = [];
  for (const row of [...rows].sort((a, b) => a.x - b.x || a.y - b.y)) {
    const col = columns.find((c) => Math.abs(c.x - row.x) <= 3);
    if (col) col.rows.push(row);
    else columns.push({ x: row.x, rows: [row] });
  }

  const out = [];
  for (const col of columns) {
    const sorted = col.rows.sort((a, b) => a.y - b.y);
    const gaps = sorted.slice(1).map((r, i) => r.y - sorted[i].y);
    const typical = gaps.length ? [...gaps].sort((a, b) => a - b)[Math.floor(gaps.length / 2)] : 0;
    let run = [sorted[0]];
    const runs = [];
    for (let i = 1; i < sorted.length; i += 1) {
      if (typical > 0 && sorted[i].y - sorted[i - 1].y > typical * 1.6) {
        runs.push(run);
        run = [];
      }
      run.push(sorted[i]);
    }
    runs.push(run);

    for (const r of runs) {
      // Diagrams stacked with the same spacing as their own rows do not get cut
      // apart by the gap rule, so a run may hold several boards end to end.
      if (r.length === 0 || r.length % 10 !== 0) continue;
      for (let start = 0; start < r.length; start += 10) {
        const board = r.slice(start, start + 10);
        const grid = board.slice(1, 9).map((row) => [...row.text.slice(1, 9)]);
        if (grid.some((g) => g.length !== 8)) continue;
        out.push({ page: pageNo, x: board[0].x, y: board[0].y, grid, rows: board });
      }
    }
  }
  return out;
}

/** Dark if file+rank is odd; a1 is dark. */
function isDark(fileIndex, rank) {
  return (fileIndex + rank) % 2 === 1;
}

function tally(diagrams) {
  const stats = new Map();
  for (const d of diagrams) {
    const perDiagram = new Map();
    d.grid.forEach((row, rowIndex) => {
      const rank = 8 - rowIndex;
      row.forEach((glyph, fileIndex) => {
        if (!stats.has(glyph)) {
          stats.set(glyph, { glyph, total: 0, onDark: 0, onLight: 0, ranks: new Set(), maxPerDiagram: 0 });
        }
        const s = stats.get(glyph);
        s.total += 1;
        if (isDark(fileIndex, rank)) s.onDark += 1;
        else s.onLight += 1;
        s.ranks.add(rank);
        perDiagram.set(glyph, (perDiagram.get(glyph) ?? 0) + 1);
      });
    });
    for (const [glyph, n] of perDiagram) {
      const s = stats.get(glyph);
      s.maxPerDiagram = Math.max(s.maxPerDiagram, n);
    }
  }
  return stats;
}

async function main() {
  const file = process.argv[2];
  const range = process.argv.includes('--pages')
    ? process.argv[process.argv.indexOf('--pages') + 1].split('-').map(Number)
    : null;

  const doc = await openPdf(file);
  const from = range?.[0] ?? 1;
  const to = range?.[1] ?? doc.numPages;

  const diagrams = [];
  for (let p = from; p <= to; p += 1) {
    diagrams.push(...rawDiagrams(mergeSpans(await pageSpans(doc, p)), p));
  }
  console.log(`Dijagrama nađeno: ${diagrams.length} (strane ${from}–${to})`);

  const stats = [...tally(diagrams).values()].sort((a, b) => b.total - a.total);
  const n = diagrams.length;

  console.log('\nglif  ukupno   svetla   tamna  redovi          najviše/dijagramu  zaključak');
  for (const s of stats) {
    const colour = s.onDark === 0 ? 'svetlo' : s.onLight === 0 ? 'tamno' : 'OBOJE(!)';
    const ranks = [...s.ranks].sort((a, b) => a - b).join('');
    const notes = [];
    if (s.total > n * 10) notes.push('prazno polje');
    if (s.maxPerDiagram === 1 && s.total > n * 0.5) notes.push('kandidat za kralja');
    if (!s.ranks.has(1) && !s.ranks.has(8) && s.total > n) notes.push('kandidat za pešaka');
    if (colour === 'OBOJE(!)') notes.push('nije glif polja — ivica ili oznaka');
    console.log(
      `  ${JSON.stringify(s.glyph).padEnd(5)} ${String(s.total).padStart(6)} ` +
        `${String(s.onLight).padStart(8)} ${String(s.onDark).padStart(7)}  ${ranks.padEnd(14)} ` +
        `${String(s.maxPerDiagram).padStart(8)}           ${notes.join(', ')}`
    );
  }

  // Kings: one of each colour per diagram. Pair the light-square and dark-square
  // variants by requiring the pair to total exactly one on every diagram.
  const kingCandidates = stats.filter((s) => s.maxPerDiagram === 1);
  const pairs = [];
  for (const a of kingCandidates) {
    for (const b of kingCandidates) {
      if (a.glyph >= b.glyph) continue;
      if (a.onDark === 0 && b.onLight === 0) pairs.push([a, b]);
      else if (a.onLight === 0 && b.onDark === 0) pairs.push([a, b]);
    }
  }
  const kingPairs = pairs.filter(([a, b]) =>
    diagrams.every((d) => {
      const flat = d.grid.flat();
      return flat.filter((g) => g === a.glyph || g === b.glyph).length === 1;
    })
  );
  console.log('\nParovi koji stoje tačno jednom na svakom dijagramu (kraljevi):');
  for (const [a, b] of kingPairs) {
    console.log(`   ${JSON.stringify(a.glyph)} + ${JSON.stringify(b.glyph)}  (${a.total} + ${b.total} = ${a.total + b.total}, dijagrama ${n})`);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
