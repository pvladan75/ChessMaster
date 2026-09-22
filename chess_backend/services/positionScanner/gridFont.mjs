// Diagram fonts that are set square by square rather than row by row.
//
// The maps in fonts.mjs read a diagram as eight strings of eight glyphs. The
// ChessBase font `DiagramTTFritz` cannot be read that way: an empty light
// square is a space, which never reaches the text layer, so a rank arrives as
// scattered glyphs with gaps between them. What it does keep is position —
// every glyph is one square wide — so a board is rebuilt by placing each glyph
// on the square under it.
//
// The font, as measured on `pawnvsking.pdf` (22.9.2026, all 21 pages):
//   * `+` is an empty dark square;
//   * a piece on a light square is its letter, `K` … `p`;
//   * a piece on a dark square is a zero-width mask glyph drawn first — the
//     dark square with the piece's silhouette left out — and then the letter
//     at the same x. The mask follows the piece's *shape*, not its colour:
//     `m` under both kings, `z` under the pawn.
// That book holds only kings and pawns, so the masks of the other pieces are
// not known yet. They are not guessed: a piece on a dark square without a
// known mask under it is refused, loudly, with the square named, and the new
// mask goes into MASKS below.
//
// The colouring of the board is the check that makes this safe. Every dark
// square must carry a glyph (`+` or a mask), and no light square may, other
// than a bare piece — so a dropped glyph, a stray letter from the prose or a
// board cut in two all fail instead of producing a legal-looking FEN.

const PIECES = new Set(['K', 'Q', 'R', 'B', 'N', 'P', 'k', 'q', 'r', 'b', 'n', 'p']);
const DARK_EMPTY = '+';
const MASKS = new Set(['m', 'z']);

export const FRITZ_DIAGRAM = {
  id: 'fritz',
  label: 'DiagramTTFritz (ChessBase)',
  layout: 'grid',
};

const ADVANCE_TOLERANCE = 0.2; // a glyph's advance against its height
const NEIGHBOUR = 1.5; // cells; glyphs this close belong to one board
// A board has 32 dark squares and each carries a glyph, so a real one has at
// least 32. A handful is a stray `+` or letter set in this font elsewhere on
// the page; anything between is a board missing glyphs, and is refused.
const STRAY = 8;
const FULL_BOARD = 32;

function isGridGlyph(c) {
  return c === DARK_EMPTY || MASKS.has(c) || PIECES.has(c);
}

/**
 * Every diagram glyph on a page, placed: { glyph, x, y, cell }.
 *
 * A span is taken only if every character belongs to the font and its glyphs
 * are square — each advance as wide as the span is tall. Body text is never
 * that wide per letter, which is what keeps a `K` in the prose off the board.
 */
export function gridGlyphs(spans) {
  const out = [];
  for (const s of spans) {
    const chars = [...s.text];
    if (chars.length === 0 || !chars.every(isGridGlyph)) continue;
    const advancing = chars.filter((c) => !MASKS.has(c)).length;
    if (advancing === 0) {
      if (s.width !== 0) continue;
      for (const c of chars) out.push({ glyph: c, x: s.x, y: s.y, cell: null });
      continue;
    }
    const cell = s.width / advancing;
    if (!(s.height > 0) || Math.abs(cell - s.height) > ADVANCE_TOLERANCE * s.height) continue;
    let x = s.x;
    for (const c of chars) {
      out.push({ glyph: c, x, y: s.y, cell });
      if (!MASKS.has(c)) x += cell;
    }
  }
  return out;
}

/** Glyphs grouped into boards: neighbours within NEIGHBOUR cells, transitively. */
function clusters(glyphs) {
  const cells = glyphs.map((g) => g.cell).filter((c) => c);
  if (cells.length === 0) return [];
  const reach = NEIGHBOUR * Math.max(...cells);
  const parent = glyphs.map((_, i) => i);
  const find = (i) => (parent[i] === i ? i : (parent[i] = find(parent[i])));
  for (let i = 0; i < glyphs.length; i += 1) {
    for (let j = i + 1; j < glyphs.length; j += 1) {
      if (Math.abs(glyphs[i].x - glyphs[j].x) <= reach && Math.abs(glyphs[i].y - glyphs[j].y) <= reach) {
        parent[find(i)] = find(j);
      }
    }
  }
  const groups = new Map();
  glyphs.forEach((g, i) => {
    const root = find(i);
    if (!groups.has(root)) groups.set(root, []);
    groups.get(root).push(g);
  });
  return [...groups.values()];
}

/**
 * The number printed over a board. This book centres it over the board, about
 * three squares above the top rank (measured: 57 pt over, 66 pt right of the
 * a-file, with 18 pt squares) — where the row reader's `labelAbove`, which
 * looks at the left edge, never finds it. So: a bare number above the board,
 * within its width, no more than four squares up; the nearest one wins. The
 * running head (the page number) sits far higher and is never that close.
 */
export function gridLabel(spans, x0, y0, cell) {
  let best = null;
  for (const s of spans) {
    if (!/^\d{1,4}$/.test(s.text.trim())) continue;
    if (s.x < x0 - cell / 2 || s.x > x0 + 8 * cell) continue;
    const rise = y0 - s.y;
    if (rise < cell || rise > 4 * cell) continue;
    if (!best || s.y > best.y) best = s;
  }
  return best ? best.text.trim() : null;
}

const FILES = 'abcdefgh';
const squareName = (file, row) => `${FILES[file]}${8 - row}`;

/**
 * One board's glyphs -> its FEN placement. Throws, naming the square, on
 * anything the colouring does not allow.
 *
 * The top-left glyph is always a8's file and rank 8's row: a7 and b8 are dark,
 * so the a-file and the eighth rank always carry a glyph.
 */
function placementOf(glyphs, where) {
  const cell = glyphs.map((g) => g.cell).filter((c) => c).sort((a, b) => a - b)[0];
  const x0 = Math.min(...glyphs.map((g) => g.x));
  const y0 = Math.min(...glyphs.map((g) => g.y));
  const squares = Array.from({ length: 8 }, () => Array.from({ length: 8 }, () => []));
  for (const g of glyphs) {
    const file = Math.round((g.x - x0) / cell);
    const row = Math.round((g.y - y0) / cell);
    if (file > 7 || row > 7) {
      throw new Error(`${where}: the board is larger than 8×8 (a glyph at ${file + 1}×${row + 1})`);
    }
    squares[row][file].push(g.glyph);
  }

  const ranks = [];
  for (let row = 0; row < 8; row += 1) {
    let rank = '';
    let empty = 0;
    for (let file = 0; file < 8; file += 1) {
      const dark = (file + row) % 2 === 1;
      const on = squares[row][file];
      const name = squareName(file, row);
      let piece = null;
      if (dark) {
        if (on.length === 1 && on[0] === DARK_EMPTY) piece = null;
        else if (on.length === 2 && on.some((c) => MASKS.has(c)) && on.some((c) => PIECES.has(c))) {
          piece = on.find((c) => PIECES.has(c));
        }
        else if (on.length === 1 && PIECES.has(on[0])) {
          throw new Error(`${where}: ${on[0]} on the dark square ${name} has no mask glyph under it — a mask this map does not know yet`);
        } else if (on.length === 0) {
          throw new Error(`${where}: the dark square ${name} has no glyph`);
        } else {
          throw new Error(`${where}: the dark square ${name} holds ${JSON.stringify(on.join(''))}`);
        }
      } else if (on.length === 0) {
        piece = null;
      } else if (on.length === 1 && PIECES.has(on[0])) {
        piece = on[0];
      } else {
        throw new Error(`${where}: the light square ${name} holds ${JSON.stringify(on.join(''))}`);
      }
      if (piece === null) {
        empty += 1;
      } else {
        if (empty > 0) rank += String(empty);
        empty = 0;
        rank += piece;
      }
    }
    if (empty > 0) rank += String(empty);
    ranks.push(rank);
  }
  return { placement: ranks.join('/'), x: x0, y: y0, cell };
}

/**
 * Diagrams on one page, in the shape `extractDiagrams` returns:
 * { diagrams: [{ label, page, x, y, placement }], anomalies }.
 */
export function extractGridDiagrams(spans, pageNo) {
  const diagrams = [];
  for (const group of clusters(gridGlyphs(spans))) {
    if (group.length < STRAY) continue;
    const x = Math.min(...group.map((g) => g.x));
    const y = Math.min(...group.map((g) => g.y));
    const where = `str. ${pageNo}, x=${x.toFixed(0)}, y=${y.toFixed(0)}`;
    if (group.length < FULL_BOARD) {
      throw new Error(`${where}: ${group.length} diagram glyphs where a board has at least ${FULL_BOARD}`);
    }
    const board = placementOf(group, where);
    diagrams.push({
      label: gridLabel(spans, board.x, board.y, board.cell),
      page: pageNo,
      x: board.x,
      y: board.y,
      placement: board.placement,
    });
  }
  diagrams.sort((a, b) => a.y - b.y || a.x - b.x);
  return { diagrams, anomalies: [] };
}

/** How many grid boards the sampled pages hold; a page that will not place counts none. */
export function countGridBoards(pages) {
  let boards = 0;
  for (const spans of pages) {
    try {
      boards += extractGridDiagrams(spans, 0).diagrams.length;
    } catch {
      // A board that fails its colouring still says this is the font; the
      // scan proper reports the failure against its page.
      boards += 1;
    }
  }
  return boards;
}
