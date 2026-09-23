// Reading a board picture square by square — phase 2 of
// docs/PLAN-SKENER-SLIKE.md, ported from phase 0's
// tools/diagram_vision/classify.py.
//
// A book draws every piece the same way on every page, so a book is read with
// templates taken from a few of its own boards whose positions a person gave
// (the calibration). Every square is binarised, lightly blurred, and compared
// with every calibration square of its colour, the template sliding up to
// SHIFT pixels either way; the nearest example wins, and the gap to the
// nearest example of any *other* class is the square's confidence.
//
// Boards are 512 x 512 grey (boards.mjs cuts them so). Squares are indexed a8
// first, as a FEN reads.

export const CELL = 64;
export const INSET = 6;
export const SHIFT = 10;
// Measured in docs/PLAN-SKENER-SLIKE.md, phase 2: examples kept per class, and
// how far a square may move from the board's own offset.
export const KEEP = Number(process.env.DV_KEEP ?? 6);
export const LOCAL = Number(process.env.DV_LOCAL ?? 3);
// A square this far from the nearest example of *any* class — the share of
// its compared pixels that differ — holds something the calibration never
// showed, and is marked whatever its gap (phase 3e.0 of the plan). Measured on
// the three books with each piece left out of the calibration in turn: on the
// scan, 32 of 386 squares of the missing piece were read wrong and unmarked by
// the gap alone, 4 with this rule, at 0.02 new marks a board; on the two
// digital books it added no mark at all. A cut relative to the median failed
// there, whose median is near zero.
export const UNKNOWN_INK = 0.1;
const SIDE = CELL - 2 * INSET; // 52: the part of a square that is compared

/** Otsu's threshold of a grey picture. */
function otsu(gray) {
  const hist = new Float64Array(256);
  for (const v of gray) hist[v]++;
  const total = gray.length;
  let sum = 0;
  for (let i = 0; i < 256; i++) sum += i * hist[i];
  let sumB = 0, wB = 0, best = 0, threshold = 0;
  for (let t = 0; t < 256; t++) {
    wB += hist[t];
    if (!wB) continue;
    const wF = total - wB;
    if (!wF) break;
    sumB += t * hist[t];
    const mB = sumB / wB;
    const mF = (sum - sumB) / wF;
    const between = wB * wF * (mB - mF) * (mB - mF);
    if (between > best) { best = between; threshold = t; }
  }
  return threshold;
}

/**
 * The board as floats in 0..1: ink or paper by Otsu, then a 3 x 3 Gaussian
 * (1-2-1), with SHIFT pixels of the edge repeated around it so a square on
 * the rim can slide as far as one in the middle.
 */
export function prepare(board, size = 512) {
  const t = otsu(board);
  const bin = new Float32Array(size * size);
  for (let i = 0; i < bin.length; i++) bin[i] = board[i] > t ? 1 : 0;
  const k = [0.25, 0.5, 0.25];
  const tmp = new Float32Array(size * size);
  const clamp = (v) => (v < 0 ? 0 : v >= size ? size - 1 : v);
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      tmp[y * size + x] = k[0] * bin[y * size + clamp(x - 1)] + k[1] * bin[y * size + x]
        + k[2] * bin[y * size + clamp(x + 1)];
    }
  }
  const padded = size + 2 * SHIFT;
  const out = new Float32Array(padded * padded);
  for (let y = 0; y < padded; y++) {
    const sy = clamp(y - SHIFT);
    for (let x = 0; x < padded; x++) {
      const sx = clamp(x - SHIFT);
      out[y * padded + x] = k[0] * tmp[clamp(sy - 1) * size + sx] + k[1] * tmp[sy * size + sx]
        + k[2] * tmp[clamp(sy + 1) * size + sx];
    }
  }
  return { data: out, padded };
}

/** Square `i` (a8 = 0) of a prepared board, widened by `pad` on every side. */
export function square(prepared, i, pad = 0) {
  const r = (i / 8) | 0;
  const c = i % 8;
  const side = SIDE + 2 * pad;
  const out = new Float32Array(side * side);
  const y0 = r * CELL + SHIFT + INSET - pad;
  const x0 = c * CELL + SHIFT + INSET - pad;
  for (let y = 0; y < side; y++) {
    const row = (y0 + y) * prepared.padded + x0;
    for (let x = 0; x < side; x++) out[y * side + x] = prepared.data[row + x];
  }
  return out;
}

export const isDark = (i) => (((i / 8) | 0) + (i % 8)) % 2 === 1;

/** What a FEN puts on each square, a8 first: a piece letter or '.'. */
export function placementCells(fen) {
  const cells = [];
  for (const ch of fen.split(' ')[0]) {
    if (ch === '/') continue;
    if (/\d/.test(ch)) for (let n = 0; n < Number(ch); n++) cells.push('.');
    else cells.push(ch);
  }
  if (cells.length !== 64) throw new Error(`not a placement of 64 squares: ${fen}`);
  return cells;
}

export function placementOf(cells) {
  const rows = [];
  for (let r = 0; r < 8; r++) {
    let row = '';
    let empty = 0;
    for (let c = 0; c < 8; c++) {
      const p = cells[r * 8 + c];
      if (p === '.') empty++;
      else { row += (empty || '') + p; empty = 0; }
    }
    rows.push(row + (empty || ''));
  }
  return rows.join('/');
}

const SQUARE_NAMES = [];
for (let r = 8; r >= 1; r--) for (const f of 'abcdefgh') SQUARE_NAMES.push(f + r);
export const squareName = (i) => SQUARE_NAMES[i];

/**
 * Templates from calibration boards: [{ board, fen, ignore? }], `ignore`
 * naming squares with a teaching mark on them (a cross, a dashed line), which
 * are neither a piece nor an empty square and stay out.
 *
 * A class no calibration board showed — a white rook on a light square, say —
 * is composed from the same piece on the other colour: inside the piece's
 * outline the square does not show, so where the seen template differs from
 * its own empty square the piece is drawn, and elsewhere the missing colour's
 * empty square is. `composed` names every class made that way.
 *
 * A piece shown on neither colour cannot be composed and is not read at all:
 * its squares come out as whatever fits best. `unseen` names those pieces, so
 * the answer can say so rather than leave it to the marks.
 */
export function learn(calibration) {
  const examples = [];
  const sums = new Map();
  for (const { board, fen, ignore = [] } of calibration) {
    const prepared = prepare(board);
    const cells = placementCells(fen);
    const skip = new Set(ignore);
    for (let i = 0; i < 64; i++) {
      if (skip.has(squareName(i))) continue;
      const v = square(prepared, i);
      const key = `${cells[i]}|${isDark(i) ? 'd' : 'l'}`;
      examples.push({ piece: cells[i], dark: isDark(i), v });
      const s = sums.get(key) ?? { sum: new Float32Array(v.length), n: 0 };
      for (let j = 0; j < v.length; j++) s.sum[j] += v[j];
      s.n++;
      sums.set(key, s);
    }
  }
  const mean = (key) => {
    const s = sums.get(key);
    return s ? s.sum.map((x) => x / s.n) : null;
  };
  const composed = [];
  for (const piece of 'PNBRQKpnbrqk') {
    for (const dark of [false, true]) {
      const want = `${piece}|${dark ? 'd' : 'l'}`;
      if (sums.has(want)) continue;
      const seen = mean(`${piece}|${dark ? 'l' : 'd'}`);
      const emptySeen = mean(`.|${dark ? 'l' : 'd'}`);
      const emptyWant = mean(`.|${dark ? 'd' : 'l'}`);
      if (!seen || !emptySeen || !emptyWant) continue;
      const v = new Float32Array(seen.length);
      for (let j = 0; j < v.length; j++) {
        v[j] = Math.abs(seen[j] - emptySeen[j]) > 0.15 ? seen[j] : emptyWant[j];
      }
      examples.push({ piece, dark, v });
      composed.push(`${piece}/${dark ? 'dark' : 'light'}`);
    }
  }
  // Class means, for aligning a board before its squares are compared.
  const means = [];
  for (const [key, sm] of sums) {
    const [piece, colour] = key.split('|');
    means.push({ piece, dark: colour === 'd', v: sm.sum.map((x) => x / sm.n) });
  }
  for (const ex of examples) {
    if (composed.includes(`${ex.piece}/${ex.dark ? 'dark' : 'light'}`)) {
      means.push({ piece: ex.piece, dark: ex.dark, v: ex.v });
    }
  }
  const unseen = [...'PNBRQKpnbrqk'].filter((p) => !sums.has(`${p}|l`) && !sums.has(`${p}|d`));
  return { examples: thin(examples, KEEP), means, composed, unseen };
}

/** Squared distance between two squares of the same size. */
function ssd(a, b) {
  let s = 0;
  for (let j = 0; j < a.length; j++) { const d = a[j] - b[j]; s += d * d; }
  return s;
}

/**
 * At most `keep` examples per class, chosen farthest-first: a book has a few
 * hundred empty squares that all look alike, and comparing a square with
 * every one of them costs time and tells nothing the first few did not.
 */
function thin(examples, keep) {
  const byClass = new Map();
  for (const ex of examples) {
    const key = `${ex.piece}|${ex.dark}`;
    if (!byClass.has(key)) byClass.set(key, []);
    byClass.get(key).push(ex);
  }
  const out = [];
  for (const group of byClass.values()) {
    if (group.length <= keep) { out.push(...group); continue; }
    const chosen = [group[0]];
    const near = group.map((ex) => ssd(ex.v, group[0].v));
    while (chosen.length < keep) {
      let far = 0;
      for (let j = 1; j < group.length; j++) if (near[j] > near[far]) far = j;
      chosen.push(group[far]);
      for (let j = 0; j < group.length; j++) near[j] = Math.min(near[j], ssd(group[j].v, group[far].v));
    }
    out.push(...chosen);
  }
  return out;
}

/** The least squared difference of `m` (SIDE x SIDE) placed in `wide`
 *  ((SIDE + 2 SHIFT) square) at offsets dy, dx in [y0, y1] x [x0, x1], every
 *  `step`-th pixel, stopping a placement once `limit` is beaten. */
function bestFit(wide, m, limit, y0, y1, x0, x1, step = 1) {
  const W = SIDE + 2 * SHIFT;
  let best = limit;
  let at = null;
  for (let dy = y0; dy <= y1; dy++) {
    for (let dx = x0; dx <= x1; dx++) {
      let s = 0;
      for (let y = 0; y < SIDE && s < best; y += step) {
        const row = (dy + y) * W + dx;
        const mrow = y * SIDE;
        for (let x = 0; x < SIDE; x += step) {
          const d = wide[row + x] - m[mrow + x];
          s += d * d;
        }
      }
      if (s < best) { best = s; at = [dy, dx]; }
    }
  }
  return { d: best, at };
}

/**
 * Each class's own best shift for square `wide`, judged against the class's
 * mean on every other pixel; the TOP classes that fit best, with the shift
 * each chose.
 *
 * Measured on a scan (phase 2): one offset for a whole board read 1 board in
 * 6 right, and one offset per square — whichever class fitted best — lost
 * pieces on the rim, where the empty square fits best by sliding the piece
 * out of view and the king's own examples were then looked for in the wrong
 * place. Each class looking for itself costs a dozen coarse searches a square
 * instead of hundreds of full ones.
 */
export const TOP = Number(process.env.DV_TOP ?? 3);

function candidates(wide, means, dark) {
  const byPiece = new Map();
  for (const t of means) {
    if (t.dark !== dark) continue;
    const prev = byPiece.get(t.piece);
    const f = bestFit(wide, t.v, prev ? prev.d : Infinity, 0, 2 * SHIFT, 0, 2 * SHIFT, 2);
    if (f.at) byPiece.set(t.piece, { d: f.d, at: f.at });
  }
  return [...byPiece.entries()].sort((x, y) => x[1].d - y[1].d).slice(0, TOP);
}

/**
 * Read one board: [{ piece, gap, guessed, d1 }] for its 64 squares, a8 first.
 * `gap` is the distance to the nearest other class minus the distance to the
 * winner, per pixel — small means unsure. `d1` is the distance to the winner,
 * per pixel — large means nothing the calibration showed looks like it.
 */
export function read(board, templates) {
  const prepared = prepare(board);
  const wides = [];
  for (let i = 0; i < 64; i++) wides.push(square(prepared, i, SHIFT));
  const out = [];
  for (let i = 0; i < 64; i++) {
    const dark = isDark(i);
    const bestOf = new Map();
    for (const [piece, { at: [oy, ox] }] of candidates(wides[i], templates.means, dark)) {
      const y0 = Math.max(0, oy - LOCAL), y1 = Math.min(2 * SHIFT, oy + LOCAL);
      const x0 = Math.max(0, ox - LOCAL), x1 = Math.min(2 * SHIFT, ox + LOCAL);
      for (const ex of templates.examples) {
        if (ex.dark !== dark || ex.piece !== piece) continue;
        const prev = bestOf.get(piece) ?? Infinity;
        const { d } = bestFit(wides[i], ex.v, prev, y0, y1, x0, x1);
        if (d < prev) bestOf.set(piece, d);
      }
    }
    const ranked = [...bestOf.entries()].sort((a, b) => a[1] - b[1]);
    const [piece, d1] = ranked[0];
    const d2 = ranked.length > 1 ? ranked[1][1] : Infinity;
    const colour = dark ? 'dark' : 'light';
    out.push({
      piece,
      gap: (d2 - d1) / (SIDE * SIDE),
      // A composed class is a guess about how the book draws a piece it never
      // showed, and a guess can be confidently wrong (phase 2, drawn boards: a
      // composed white rook read with a gap well above the cut). So a square
      // *read as* a composed class is never trusted, whatever its gap. Not a
      // square where one merely came second: a composed template is mostly
      // its empty square, so it is the runner-up on nearly every empty square,
      // and marking those put 20 marks on a board of Back to Basics.
      guessed: templates.composed.includes(`${piece}/${colour}`),
      d1: d1 / (SIDE * SIDE),
    });
  }
  return out;
}

/**
 * Templates for one book from its calibration boards, plus the gap below
 * which a square is marked unsure: the 2nd percentile of the calibration
 * boards' own gaps, read back through the templates — phase 0's rule, kept
 * until phase 3 can measure what it costs a trainer.
 */
export function calibrate(calibration) {
  if (!calibration.length) throw new Error('a book cannot be read without a calibration board');
  const templates = learn(calibration);
  const gaps = [];
  for (const { board } of calibration) for (const c of read(board, templates)) gaps.push(c.gap);
  gaps.sort((a, b) => a - b);
  const cut = gaps[Math.floor(gaps.length * 0.02)];
  return { ...templates, cut };
}

/**
 * Whether a square read is marked for the trainer to check: its gap is under
 * the calibration's cut, it was read as a composed class, or it is farther
 * from every example than UNKNOWN_INK.
 */
export function unsureOf(cell, calibrated) {
  return cell.gap < calibrated.cut || cell.guessed || cell.d1 > UNKNOWN_INK;
}

/** One board read with a calibration: [{ piece, gap, unsure }], a8 first. */
export function readBoard(board, calibrated) {
  return read(board, calibrated).map((c) => ({ ...c, unsure: unsureOf(c, calibrated) }));
}
