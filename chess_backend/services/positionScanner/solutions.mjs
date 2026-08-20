// Reading the book's own solutions.
//
// The solution is the strongest signal in the whole pipeline and it does two
// jobs at once:
//
//   1. It says who is to move. `1255  1...Rd1+` is black. The rule is that the
//      *first* move token is `1...`, not that the line contains `1...` — the
//      line `307  1.Kc3 [threatening Qa7m] 1...Ka2` also contains it and is
//      white to move.
//   2. It is a test of the extracted board. If the book's move is not even
//      legal in the FEN we read off the page, the board was misread.
import { pageSpans } from './pdf.mjs';

/**
 * Rebuild visual lines from spans; pdfjs hands back fragments, not lines.
 *
 * A solutions page is typeset in columns, so one visual line holds two unrelated
 * entries. Joining the whole line produces `11.QXg7m271.NXe6m` — entry 1 and
 * entry 27 fused, which parses as neither. Split wherever the horizontal gap is
 * far wider than the gaps inside a word.
 */
const COLUMN_GAP = 1.0; // multiples of the glyph height

export function spansToLines(spans) {
  const rows = [];
  for (const s of [...spans].sort((a, b) => a.y - b.y || a.x - b.x)) {
    const row = rows.find((l) => Math.abs(l.y - s.y) < 3);
    if (row) row.parts.push(s);
    else rows.push({ y: s.y, parts: [s] });
  }

  const lines = [];
  for (const row of rows) {
    const parts = row.parts.sort((a, b) => a.x - b.x);
    let segment = [parts[0]];
    for (let i = 1; i < parts.length; i += 1) {
      const prev = parts[i - 1];
      const gap = parts[i].x - (prev.x + prev.width);
      if (gap > COLUMN_GAP * Math.max(prev.height, 6)) {
        lines.push(segment);
        segment = [];
      }
      segment.push(parts[i]);
    }
    if (segment.length) lines.push(segment);
  }

  return lines.map((seg) =>
    seg
      .map((p) => p.text)
      .join('')
      .replace(/\s+/g, ' ')
      .trim()
  );
}

/**
 * Book notation -> SAN chess.js accepts.
 * Handles `X` for captures, `m` for mate, bare promotions, and editorial marks.
 */
export function normalizeSan(token) {
  let san = token.trim();
  san = san.replace(/[!?]+/g, '');
  san = san.replace(/^\(+|\)+$/g, '');
  san = san.replace(/X/g, 'x');
  san = san.replace(/m$/, '#');
  // `eXd8Q` / `g8N` -> `exd8=Q` / `g8=N`; chess.js requires the `=`.
  san = san.replace(/^([a-h](?:x[a-h])?[18])([QRBN])/, '$1=$2');
  // Castling is written with letter O or digit 0 depending on the typesetter.
  san = san.replace(/0-0-0/, 'O-O-O').replace(/^0-0(?!-)/, 'O-O');
  return san;
}

// The typesetter puts no space between the diagram number and the move, so
// `1 1.QXg7m` reaches us as `11.QXg7m`. The number is still unambiguous: the
// move always begins `1.` or `1...`, and backtracking settles it.
// Some books number the entry with a trailing period (`1. 1...a5!`), some with
// nothing at all (`1 1.QXg7m`, which arrives as `11.QXg7m`). Both are covered;
// backtracking still lands on the right number because the move itself always
// begins `1.` or `1...`.
const ENTRY = /^(\d{1,4})\.?\s*(1\.\.\.|1\.)\s*(.*)$/;

// A SAN token in book conventions: `X` for captures, bare promotion letters,
// `m` for mate. Longest forms first, or `g8N` parses as the pawn move `g8`.
const SAN_TOKEN = new RegExp(
  '^(?:' +
    '(?:O-O-O|O-O|0-0-0|0-0)' + // castling
    '|(?:[a-h][18][QRBN])' + // promotion by push
    '|(?:[a-h][Xx][a-h][18][QRBN])' + // promotion by capture
    '|(?:[KQRBN][a-h]?[1-8]?[Xx]?[a-h][1-8])' + // piece move
    '|(?:[a-h]?[Xx]?[a-h][1-8])' + // pawn move or capture
    ')[+#m]?[!?]*'
);

/**
 * First move of a solution line, plus whatever text followed it.
 *
 * Returns candidates shortest-first, because the notation is genuinely
 * ambiguous once the typesetter's spaces are gone. `Nc6b5` is `1.Nc6 b5` — a
 * move and the reply — but it is spelled exactly like a rank-and-file
 * disambiguated `Nc6b5`. Nothing in the text decides it; the board does, so the
 * caller tries them in order and lets chess.js reject the wrong one.
 */
const PIECE_THEN_REPLY = /^([KQRBN][a-h][1-8])([a-h][1-8][+#]?)$/;

export function splitFirstMove(rest) {
  const m = SAN_TOKEN.exec(rest.trim());
  if (!m) return null;
  const token = m[0];
  const candidates = [token];
  const split = PIECE_THEN_REPLY.exec(token);
  if (split) candidates.unshift(split[1]);
  return { token, candidates, tail: rest.trim().slice(token.length).trim() };
}

/**
 * Parse a solutions section into Map<id, {side, san, raw, tail}>.
 *
 * `tail` is whatever followed the first move — in the second test book that is
 * the motif in words (`1...a5! undermining`), which is exactly what
 * `assignments.themes` needs and what scanned positions otherwise lack.
 */
export function parseSolutionLines(lines) {
  const out = new Map();
  for (const line of lines) {
    const m = ENTRY.exec(line.trim());
    if (!m) continue;
    const id = Number(m[1]);
    if (out.has(id)) continue; // first occurrence wins; later pages repeat headers
    const move = splitFirstMove(m[3]);
    if (!move) continue;
    out.set(id, {
      side: m[2] === '1...' ? 'b' : 'w',
      san: normalizeSan(move.candidates[0]),
      sans: move.candidates.map(normalizeSan),
      raw: line.trim(),
      tail: move.tail,
    });
  }
  return out;
}

/** Read solutions from a page range (1-based, inclusive). */
export async function readSolutions(doc, fromPage, toPage) {
  const lines = [];
  for (let p = fromPage; p <= toPage; p += 1) {
    lines.push(...spansToLines(await pageSpans(doc, p)));
  }
  return parseSolutionLines(lines);
}

/** First page whose text announces a solutions section, or null. */
export async function findSolutionsStart(doc, textOf) {
  for (let p = 1; p <= doc.numPages; p += 1) {
    const t = await textOf(p);
    if (/\b(solutions?|answers?|rje[sš]enja|re[sš]enja)\b/i.test(t)) return p;
  }
  return null;
}
