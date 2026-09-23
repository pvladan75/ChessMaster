// The grid reader for DiagramTTFritz (gridFont.mjs).
//
// The fixture is page 14 of `pawnvsking.pdf` as pageSpans hands it back: every
// span's geometry, the diagram glyphs and bare numbers as printed, and the
// prose replaced by `x`s of the same length — the book is not ours to publish,
// and its prose only has to be there, where it was.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { extractGridDiagrams, gridGlyphs } from './gridFont.mjs';
import { extractDiagrams } from './diagrams.mjs';
import { FONT_MAPS } from './fonts.mjs';
import { pickFontMap } from './index.mjs';

const PAGE_14 = JSON.parse(readFileSync(new URL('./gridFont.page14.json', import.meta.url)));
const page = () => PAGE_14.map((s) => ({ ...s }));

// Read by hand off the glyphs, square by square, before the reader existed.
const DIAGRAM_3 = '6k1/8/6K1/6P1/8/8/8/8';
const DIAGRAM_2 = '4k3/8/5K2/4P3/8/8/8/8';

test('page 14: both boards, each with the number printed over it', () => {
  const { diagrams } = extractGridDiagrams(page(), 14);
  assert.deepEqual(
    diagrams.map((d) => [d.label, d.placement]),
    [['3', DIAGRAM_3], ['2', DIAGRAM_2]]
  );
});

// Page 14's own running head sits left of both boards, so it could not tell a
// window from no window (both survived mutation). These move a number to
// where a window is the only thing that keeps it off.
test('a number more than four squares over the board is not its number', () => {
  const spans = page().filter((s) => s.text !== '2');
  const board = extractGridDiagrams(page(), 14).diagrams[1];
  spans.push({ text: '99', x: board.x + 66, y: board.y - 5 * 18, width: 12, height: 11.5 });
  assert.equal(extractGridDiagrams(spans, 14).diagrams[1].label, null);
});

test("a number over the neighbouring board's column is not this board's", () => {
  const spans = page().filter((s) => s.text !== '2');
  const [right, left] = extractGridDiagrams(page(), 14).diagrams;
  assert.ok(right.x > left.x + 8 * 18, 'the fixture boards are not side by side');
  // Over the right board's column, at the left board's number height.
  spans.push({ text: '99', x: right.x + 66, y: left.y - 57, width: 12, height: 11.5 });
  assert.equal(extractGridDiagrams(spans, 14).diagrams[1].label, null);
});

test('a few glyphs of the font elsewhere on the page are not a board', () => {
  const spans = [...page(), { text: '+', x: 500, y: 700, width: 18, height: 18 }];
  assert.deepEqual(
    extractGridDiagrams(spans, 14).diagrams.map((d) => d.placement),
    [DIAGRAM_3, DIAGRAM_2]
  );
});

test('extractDiagrams hands a grid map to the grid reader', () => {
  const grid = { id: 'fritz', layout: 'grid' };
  assert.deepEqual(
    extractDiagrams(page(), grid, 14).diagrams.map((d) => d.placement),
    [DIAGRAM_3, DIAGRAM_2]
  );
});

test('a mask and its piece read the same in either order', () => {
  const { diagrams } = extractGridDiagrams(page().reverse(), 14);
  assert.deepEqual(diagrams.map((d) => d.placement), [DIAGRAM_3, DIAGRAM_2]);
});

test('a letter in body text is not a piece on the board', () => {
  const board = extractGridDiagrams(page(), 14).diagrams[1];
  // A `P` at body size, set on the board's own f5 line: square advance fails.
  const stray = { text: 'P', x: board.x + 5 * 18, y: board.y + 3 * 18, width: 7, height: 11.5 };
  const { diagrams } = extractGridDiagrams([...page(), stray], 14);
  assert.deepEqual(diagrams.map((d) => d.placement), [DIAGRAM_3, DIAGRAM_2]);
});

test('a dark square that lost its glyph is refused, by name', () => {
  const spans = page();
  const board = extractGridDiagrams(spans, 14).diagrams[1];
  // a7: the a-file, one row down.
  const a7 = spans.findIndex(
    (s) => s.text === '+' && Math.abs(s.x - board.x) < 1 && Math.abs(s.y - (board.y + 18)) < 1
  );
  assert.ok(a7 >= 0, 'the fixture has no a7');
  spans.splice(a7, 1);
  assert.throws(() => extractGridDiagrams(spans, 14), /dark square a7 has no glyph/);
});

test('a piece on a dark square with no known mask under it is refused', () => {
  const spans = page().filter((s) => !(s.width === 0 && s.text === 'm'));
  assert.throws(() => extractGridDiagrams(spans, 14), /no mask glyph under it/);
});

test('a board missing most of its glyphs is refused, not skipped', () => {
  const board = extractGridDiagrams(page(), 14).diagrams[1];
  const spans = page().filter(
    (s) => !(s.text === '+' && s.y > board.y + 3 * 18 - 1 && s.x < board.x + 8 * 18 && s.x >= board.x - 1)
  );
  assert.throws(() => extractGridDiagrams(spans, 14), /diagram glyphs where a board has at least 32/);
});

test('every glyph is placed where the span says, masks taking no room', () => {
  const placed = gridGlyphs([{ text: '+zP+', x: 100, y: 50, width: 54, height: 18 }]);
  assert.deepEqual(placed.map((g) => [g.glyph, g.x]), [['+', 100], ['z', 118], ['P', 118], ['+', 136]]);
});

test('a row font keeps its map; the grid font is asked only when none fits', () => {
  const skak = FONT_MAPS.find((m) => m.id === 'skaknew');
  assert.equal(pickFontMap(['rnbqkbnr'], [page()]).map, skak);
  assert.equal(pickFontMap([], [page()]).map.layout, 'grid');
  assert.equal(pickFontMap([], [[{ text: 'prose', x: 0, y: 0, width: 30, height: 11 }]]), null);
});

// Books that set an empty light square as `-` hand back whole ranks, masks and
// all. The glyphs of two boards as pdfjs returns them (23.9.2026): page 14 of
// `7809.pdf`, with its rook's mask as a zero-width span of its own, and page
// 14 of `queenminorvsqueen.pdf`, which has a queen and a bishop on dark squares,
// and page 13 of the same book, whose white bishop stands on a light square.
const ranks = (rows, x, y0, loose = []) => [
  ...rows.map((text, i) => ({ text, x, y: y0 + 18 * i, width: 144, height: 18 })),
  ...loose.map(([text, row]) => ({ text, x, y: y0 + 18 * row, width: 0, height: 18 })),
];
const ROOK_BOARD = () =>
  ranks(
    ['-+-+-+-+', '+-+-+K+-', '-+-+-+-+', '+-+-+-+-', '-+-+pmk-+', '+-+-+-+-', '-+-+-+-+', 'R-+-+-+-'],
    70.8,
    425,
    [['t', 7]]
  );
const QUEEN_BOARD = () =>
  ranks(
    ['-+-+-+-wQ', '+qvl-+-+-', '-+-+-+-+', '+-+-+-+-', '-+-+-+-+', '+K+-+-+-', '-+-+k+-+', '+-+-+-+-'],
    253.7,
    164
  );
const WHITE_BISHOP_BOARD = () =>
  ranks(
    ['-+-+-+KwQ', '+-+-+-+-', '-+-+-+L+', '+-+-+-+-', '-+-+-+-+', '+-+-+-+-', 'k+-+-+-+', 'q-+-+-+-'],
    270.7,
    281,
    [['w', 7]]
  );

test('a book that sets light squares as `-` reads, with the rook, queen and bishop masks', () => {
  const read = (spans) => extractGridDiagrams(spans, 14).diagrams.map((d) => d.placement);
  assert.deepEqual(read(ROOK_BOARD()), ['8/5K2/8/8/4pk2/8/8/R7']);
  // `L` is the bishop, `wQ` a white queen on h8 and `vl` a black bishop on c7.
  assert.deepEqual(read(QUEEN_BOARD()), ['7Q/1qb5/8/8/8/1K6/4k3/8']);
  assert.deepEqual(read(WHITE_BISHOP_BOARD()), ['6KQ/8/6B1/8/8/8/k7/q7']);
  assert.equal(pickFontMap([], [QUEEN_BOARD()]).map.layout, 'grid');
});

test('a mask under a piece of another shape is refused, by square', () => {
  const spans = QUEEN_BOARD().map((s) => ({ ...s, text: s.text.replace('wQ', 'tQ') }));
  assert.throws(() => extractGridDiagrams(spans, 14), /dark square h8 has Q over the mask of another piece/);
});

test('`B` is not a glyph of this font: the bishop is `L`', () => {
  const black = QUEEN_BOARD().map((s) => ({ ...s, text: s.text.replace('vl', 'vb') }));
  assert.throws(() => extractGridDiagrams(black, 14));
  const white = WHITE_BISHOP_BOARD().map((s) => ({ ...s, text: s.text.replace('L', 'B') }));
  assert.throws(() => extractGridDiagrams(white, 13));
});

test('a light square holding anything but a piece or `-` is refused', () => {
  const spans = ROOK_BOARD().map((s) => ({ ...s, text: s.text.replace('+K+-', '+K++') }));
  assert.throws(() => extractGridDiagrams(spans, 14), /light square h7 holds "\+"/);
});
