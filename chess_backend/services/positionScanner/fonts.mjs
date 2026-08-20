// Glyph maps for chess diagram fonts.
//
// A diagram in a typeset chess book is not a picture: it is eight lines of text
// in a font whose glyphs are pieces-on-squares. Reading it is therefore exact,
// but the alphabet is different in every font, so each book needs a map here.
//
// Maps are selected by the *alphabet* a span uses, not by the font name. Font
// names are frequently useless — the second test book calls its diagram font
// `TTE2BEAF20t00` — and a subset prefix (`OFGDGB+`) changes per file.
//
// An unmapped glyph is a hard error, never a silent empty square: a board that
// quietly loses a piece still produces a legal-looking FEN, and the mistake
// only surfaces when a child is asked to solve an unsolvable position.

/**
 * SkakNew-Diagram — the LaTeX `skak` package font.
 *
 * A row is exactly 8 glyphs, no border. Each piece has two glyphs because the
 * font draws the piece differently on a light and on a dark square; both map to
 * the same piece.
 */
const SKAK_NEW = {
  id: 'skaknew',
  label: 'SkakNew-Diagram (LaTeX skak)',
  rowLength: 8,
  squares: (text) => text,
  isBorderRow: () => false,
  glyphs: {
    '0': '.', 'Z': '.',
    P: 'P', O: 'P', N: 'N', M: 'N', B: 'B', A: 'B',
    R: 'R', S: 'R', Q: 'Q', L: 'Q', K: 'K', J: 'K',
    p: 'p', o: 'p', n: 'n', m: 'n', b: 'b', a: 'b',
    r: 'r', s: 'r', q: 'q', l: 'q', k: 'k', j: 'k',
  },
};

/**
 * Tactics Course (Exeter Chess Club, Dave Regis).
 *
 * A row is 10 characters: a left margin border/coordinate character, 8 piece
 * glyphs, and a right margin border character. `X` is an attacked-square marker
 * (not a piece) and explicitly maps to empty string ('.').
 */
const TACTICS_COURSE = {
  id: 'tacticscourse',
  label: 'Tactics Course (Exeter Chess Club)',
  rowLength: [10, 11],
  squares: (text) => text.slice(1, 9),
  isBorderRow: (text) => text.startsWith('c') || text.startsWith('C') || text.startsWith('v'),
  glyphs: {
    w: '.', D: '.', d: '.', X: '.',
    P: 'P', ')': 'P', N: 'N', H: 'N', B: 'B', G: 'B',
    R: 'R', $: 'R', Q: 'Q', '1': 'Q', K: 'K', I: 'K',
    p: 'p', '0': 'p', n: 'n', h: 'n', b: 'b', g: 'b',
    r: 'r', '4': 'r', q: 'q', '!': 'q', k: 'k', i: 'k',
    Z: 'k', '*': 'K',
  },
};

export const FONT_MAPS = [SKAK_NEW, TACTICS_COURSE];

/** Glyphs a map understands, as a Set, for alphabet matching. */
function alphabetOf(map) {
  return new Set(Object.keys(map.glyphs));
}

/**
 * Pick the map that explains a sample of candidate row strings.
 *
 * Returns the map covering the most rows completely. Returns null when no map
 * covers any row — the caller reports which glyphs were unknown rather than
 * guessing, because guessing here is how a book silently imports as garbage.
 */
export function selectFontMap(rows) {
  let best = null;
  for (const map of FONT_MAPS) {
    const alphabet = alphabetOf(map);
    let covered = 0;
    for (const row of rows) {
      const isLenValid = typeof map.rowLength === 'function'
        ? map.rowLength(row.length)
        : Array.isArray(map.rowLength)
          ? map.rowLength.includes(row.length)
          : row.length === map.rowLength;
      if (!isLenValid) continue;
      const squares = map.squares(row);
      if ([...squares].every((c) => alphabet.has(c))) covered += 1;
    }
    if (covered > 0 && (!best || covered > best.covered)) best = { map, covered };
  }
  return best;
}

/** Glyphs in `rows` that no map explains — the "write a map for this book" list. */
export function unknownGlyphs(rows) {
  const known = new Set();
  for (const map of FONT_MAPS) for (const g of alphabetOf(map)) known.add(g);
  const unknown = new Map();
  for (const row of rows) {
    for (const c of row) if (!known.has(c)) unknown.set(c, (unknown.get(c) ?? 0) + 1);
  }
  return [...unknown.entries()].sort((a, b) => b[1] - a[1]);
}

/**
 * One diagram row of glyphs -> one FEN rank.
 * Throws on an unmapped glyph, by design.
 */
export function rowToFenRank(row, map, where) {
  const squares = map.squares(row);
  if (squares.length !== 8) {
    throw new Error(`${where}: red ima ${squares.length} polja umesto 8: ${JSON.stringify(row)}`);
  }
  let out = '';
  let empty = 0;
  for (const glyph of squares) {
    const piece = map.glyphs[glyph];
    if (piece === undefined) {
      throw new Error(`${where}: nepoznat glif ${JSON.stringify(glyph)} u redu ${JSON.stringify(row)}`);
    }
    if (piece === '.') {
      empty += 1;
      continue;
    }
    if (empty > 0) {
      out += String(empty);
      empty = 0;
    }
    out += piece;
  }
  if (empty > 0) out += String(empty);
  return out;
}
