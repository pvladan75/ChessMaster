// Reading glyph identities straight out of the printed solutions.
//
//   node identify.mjs <file.pdf> --tests 78-79 --answers 81
//
// Enumerating every possible map and testing it was the wrong instrument: two
// and a half million candidates, seven minutes, and a bare "none fit" that says
// nothing about which assumption broke.
//
// The solution already names the piece. `1.Ng5` means a white knight stands a
// knight's move from g5 — and which squares are *occupied* is known without any
// map at all, since an empty square has its own glyph. So walk back from the
// destination, look at what is standing there, and the glyph identifies itself.
// Where several origins are possible the answer is a set, and sets from
// different positions intersect.
import { openPdf, pageSpans, mergeSpans } from './pdf.mjs';
import { spansToLines, parseSolutionLines } from './solutions.mjs';

const FILES = 'abcdefgh';
const EMPTYISH = new Set(['w', 'D', 'd']); // empty squares and marked empty squares

function boardRows(spans) {
  return spans.filter((s) => s.text.length >= 10 && s.text.length <= 11);
}

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
    const runs = [];
    let run = [sorted[0]];
    for (let i = 1; i < sorted.length; i += 1) {
      if (typical > 0 && sorted[i].y - sorted[i - 1].y > typical * 1.6) {
        runs.push(run);
        run = [];
      }
      run.push(sorted[i]);
    }
    runs.push(run);
    for (const r of runs) {
      if (r.length === 0 || r.length % 10 !== 0) continue;
      for (let start = 0; start < r.length; start += 10) {
        const board = r.slice(start, start + 10);
        const grid = board.slice(1, 9).map((row) => [...row.text.slice(1, 9)]);
        if (grid.some((g) => g.length !== 8)) continue;
        let label = null;
        for (const s of spans) {
          if (!/^\d{1,2}$/.test(s.text.trim())) continue;
          const rise = board[0].y - s.y;
          if (rise <= 0 || rise > 40 || Math.abs(s.x - board[0].x) > 40) continue;
          label = Number(s.text.trim());
        }
        out.push({ page: pageNo, label, grid });
      }
    }
  }
  return out;
}

/** grid[rowIndex][fileIndex]; row 0 is rank 8. */
const at = (grid, file, rank) => grid[8 - rank]?.[file];
const occupied = (grid, file, rank) => {
  const g = at(grid, file, rank);
  return g !== undefined && !EMPTYISH.has(g);
};
const onBoard = (f, r) => f >= 0 && f < 8 && r >= 1 && r <= 8;

const RAYS = {
  R: [[1, 0], [-1, 0], [0, 1], [0, -1]],
  B: [[1, 1], [1, -1], [-1, 1], [-1, -1]],
};
RAYS.Q = [...RAYS.R, ...RAYS.B];
const LEAPS = {
  N: [[1, 2], [2, 1], [2, -1], [1, -2], [-1, -2], [-2, -1], [-2, 1], [-1, 2]],
  K: [[1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1], [0, -1], [1, -1]],
};

/** Squares a piece of this type could have come from, given what is occupied. */
function origins(grid, type, destFile, destRank, side, isCapture) {
  const found = [];
  if (type === 'P') {
    const dir = side === 'w' ? -1 : 1; // walk backwards from the destination
    if (isCapture) {
      for (const df of [-1, 1]) {
        const f = destFile + df;
        const r = destRank + dir;
        if (onBoard(f, r) && occupied(grid, f, r)) found.push([f, r]);
      }
    } else {
      const one = destRank + dir;
      if (onBoard(destFile, one) && occupied(grid, destFile, one)) found.push([destFile, one]);
      const startRank = side === 'w' ? 2 : 7;
      const two = destRank + 2 * dir;
      if (two === startRank && !occupied(grid, destFile, one) && occupied(grid, destFile, two)) {
        found.push([destFile, two]);
      }
    }
    return found;
  }
  if (LEAPS[type]) {
    for (const [df, dr] of LEAPS[type]) {
      const f = destFile + df;
      const r = destRank + dr;
      if (onBoard(f, r) && occupied(grid, f, r)) found.push([f, r]);
    }
    return found;
  }
  for (const [df, dr] of RAYS[type]) {
    let f = destFile + df;
    let r = destRank + dr;
    while (onBoard(f, r)) {
      if (occupied(grid, f, r)) {
        found.push([f, r]);
        break; // anything further along the ray is blocked by this piece
      }
      f += df;
      r += dr;
    }
  }
  return found;
}

async function main() {
  const file = process.argv[2];
  const arg = (name) => {
    const i = process.argv.indexOf(`--${name}`);
    return i === -1 ? null : process.argv[i + 1];
  };
  const [testFrom, testTo] = (arg('tests') ?? '1-1').split('-').map(Number);
  const answersPage = Number(arg('answers'));

  const doc = await openPdf(file);
  const answers = parseSolutionLines(spansToLines(await pageSpans(doc, answersPage)));

  const tests = [];
  for (let p = testFrom; p <= testTo; p += 1) {
    for (const d of rawDiagrams(mergeSpans(await pageSpans(doc, p)), p)) {
      const answer = d.label !== null ? answers.get(d.label) : null;
      if (answer) tests.push({ ...d, answer });
    }
  }

  // glyph -> set of "type+colour" labels still possible for it
  const possible = new Map();
  const note = (glyph, options) => {
    const set = new Set(options);
    if (!possible.has(glyph)) possible.set(glyph, set);
    else {
      const current = possible.get(glyph);
      for (const v of [...current]) if (!set.has(v)) current.delete(v);
    }
  };

  console.log(`Test-pozicija sa rešenjem: ${tests.length}\n`);
  for (const t of tests) {
    const san = t.answer.san;
    const side = t.answer.side;
    const m = /^([KQRBN])?([a-h])?x?([a-h])([1-8])/.exec(san);
    if (!m) {
      console.log(`#${t.label}: ${san} — ne umem da pročitam, preskačem`);
      continue;
    }
    const type = m[1] ?? 'P';
    const destFile = FILES.indexOf(m[3]);
    const destRank = Number(m[4]);
    const isCapture = san.includes('x');
    const from = origins(t.grid, type, destFile, destRank, side, isCapture);
    const glyphs = [...new Set(from.map(([f, r]) => at(t.grid, f, r)))];
    const role = `${side}${type}`;

    console.log(
      `#${String(t.label).padStart(2)}: ${(side === 'b' ? 'crni ' : 'beli ')}${san.padEnd(7)} ` +
        `polazi sa ${from.map(([f, r]) => FILES[f] + r).join('/') || '(ništa)'}  ` +
        `→ glif ${glyphs.map((g) => JSON.stringify(g)).join(' ili ')} je ${role}`
    );
    if (glyphs.length === 1) note(glyphs[0], [role]);

    // A capture proves the target square holds a piece of the other colour.
    if (isCapture) {
      const target = at(t.grid, destFile, destRank);
      if (target && !EMPTYISH.has(target)) {
        const enemy = side === 'w' ? 'b' : 'w';
        note(target, ['Q', 'R', 'B', 'N', 'P'].map((p) => `${enemy}${p}`));
      }
    }
  }

  console.log('\nZaključeno:');
  const contradictions = [];
  for (const [glyph, options] of [...possible.entries()].sort()) {
    const list = [...options];
    if (list.length === 0) {
      contradictions.push(glyph);
      continue;
    }
    console.log(`   ${JSON.stringify(glyph)} → ${list.length === 1 ? list[0] : list.join(' ili ')}`);
  }

  // An empty set is not "unknown" — it means two positions in the same book
  // demand incompatible things of one glyph. Printing it as a blank would hide
  // exactly the disagreement worth looking at.
  if (contradictions.length) {
    console.log('\nPROTIVREČNO — isti glif traži dve nespojive figure:');
    for (const glyph of contradictions) {
      console.log(`   ${JSON.stringify(glyph)}: vidi test-pozicije u kojima se javlja.`);
    }
    console.log(
      '\nNajčešći uzrok nije font nego knjiga: rešenje tvrdi jednu stranu na potezu,\n' +
        'a pozicija dopušta samo drugu. To je isti raskorak koji trener treba da vidi\n' +
        'u ekranu za potvrdu — ne rešava ga parser.'
    );
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
