// node --test test.mjs
//
// Covers the two places where this pipeline can be wrong quietly: notation that
// parses into the wrong move, and FEN metadata a diagram cannot show.
import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeSan, splitFirstMove, parseSolutionLines } from './solutions.mjs';
import { rowToFenRank, FONT_MAPS, selectFontMap } from './fonts.mjs';
import { buildPosition, materialProblem } from './verify.mjs';
import { flagDuplicateNumbers, scanDocument } from './index.mjs';
import { classifyUnreadable } from './diagrams.mjs';
import { writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const skak = FONT_MAPS[0];

test('book notation becomes SAN chess.js accepts', () => {
  assert.equal(normalizeSan('QXg7m'), 'Qxg7#');
  assert.equal(normalizeSan('Rh3m'), 'Rh3#');
  assert.equal(normalizeSan('eXd8Qm'), 'exd8=Q#');
  assert.equal(normalizeSan('g8Nm'), 'g8=N#');
  assert.equal(normalizeSan('c4+'), 'c4+');
  assert.equal(normalizeSan('a5!'), 'a5');
});

test('a solution line yields the move, not the move plus the reply', () => {
  // `1.Nc6 b5` reaches us as `Nc6b5` once the typesetter's space is gone. It is
  // spelled exactly like a disambiguated Nc6b5, so both are offered, short first.
  assert.deepEqual(splitFirstMove('Nc6b5 2.Qa8m').candidates, ['Nc6', 'Nc6b5']);
  assert.deepEqual(splitFirstMove('Rd1+ 2.NXd1').candidates, ['Rd1+']);
  assert.deepEqual(splitFirstMove('Rhg7m').candidates, ['Rhg7m']);
});

test('side to move is the first move token, not any ellipsis on the line', () => {
  const parsed = parseSolutionLines([
    '1255 1...Rd1+ 2.NXd1',
    '307 1.Kc3 [threatening Qa7m] 1...Ka2',
  ]);
  assert.equal(parsed.get(1255).side, 'b');
  assert.equal(parsed.get(307).side, 'w', 'a reply written 1... must not flip the side');
});

test('the number runs into the move and is still recovered', () => {
  // The typesetter prints no space: `1 1.QXg7m` arrives as `11.QXg7m`.
  const parsed = parseSolutionLines(['11.QXg7m', '12551...Rd1+']);
  assert.equal(parsed.get(1).san, 'Qxg7#');
  assert.equal(parsed.get(1255).san, 'Rd1+');
});

test('glyph rows become FEN ranks, and an unknown glyph is fatal', () => {
  assert.equal(rowToFenRank('0Z0Z0L0Z', skak, 'test'), '5Q2');
  assert.equal(rowToFenRank('ZZZZZZZZ', skak, 'test'), '8');
  assert.throws(() => rowToFenRank('0Z0Z0§0Z', skak, 'test'), /nepoznat glif/);
});

test('a map is chosen by alphabet, and refused when nothing fits', () => {
  assert.equal(selectFontMap(['0Z0Z0L0Z', 'Z0Z0Z0Z0']).map.id, 'skaknew');
  assert.equal(selectFontMap(['cuuuuuuuuC', '(wdwdwdwd}']).map.id, 'tacticscourse');
  assert.equal(selectFontMap(['0Z0Z0§0Z', 'Z0Z0§0Z0']), null);
});

test('castling rights are restored from the solution, not assumed', () => {
  // Diagram 305: mate in one by castling. With the rights thrown away the
  // position imports as unsolvable — pieces right, move forbidden.
  const diagram = { placement: '8/8/8/8/8/5N2/1pr3PP/r1k1K2R' };
  const result = buildPosition(diagram, { side: 'w', san: 'O-O#', sans: ['O-O#'] });
  assert.equal(result.solutionLegal, true);
  assert.equal(result.fen.split(' ')[2], 'K');
  assert.deepEqual(result.repairs, ['rokada: postavljeno pravo K']);
});

test('the en passant square is restored from a capture onto an empty square', () => {
  const diagram = { placement: 'rb6/k1p4R/P1P5/PpK5/8/8/8/5B2' };
  const result = buildPosition(diagram, { side: 'w', san: 'axb6#', sans: ['axb6#'] });
  assert.equal(result.solutionLegal, true);
  assert.equal(result.fen.split(' ')[3], 'b6');
});

test('a position with no solution is kept but marked, never guessed', () => {
  const diagram = { placement: '8/8/8/8/8/3NkN2/Q7/4K3' };
  const result = buildPosition(diagram, undefined);
  assert.equal(result.solutionLegal, null);
  assert.equal(result.problem, null);
  assert.ok(['nepoznato', 'jedina legalna strana'].includes(result.sideSource));
});

// Both of these guard the same thing from different sides: a diagram read wrong
// in a way that still produces a legal FEN. That is what a swapped pair of
// queen glyphs did to 22 of one book's 210 diagrams while every other check in
// this file passed.

test('material that could never stand on a board is refused', () => {
  assert.equal(materialProblem('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR'), null);

  // A white queen deep in Black's camp while White still has its own, and the
  // pawns all present — the exact shape of the misread this check exists for.
  assert.match(
    materialProblem('r1bQk2r/pppp1ppp/5n2/1B2p3/1b1nP3/2NP1N2/PPPB1PPP/R2QK2R'),
    /beli.*viška uz 8 pešaka/
  );

  assert.match(materialProblem('4k3/8/8/8/8/8/PPPPPPPPP/4K3'), /beli ima 9 pešaka/);
  assert.match(materialProblem('4k3/pppppppppp/8/8/8/8/8/4K3'), /crni ima 10 pešaka/);
});

test('a promotion is possible material, and is not refused', () => {
  // Two white queens with a white pawn missing is an ordinary promotion. The
  // check must not turn "unusual" into "impossible", or a real position from a
  // book gets held back for no reason.
  assert.equal(materialProblem('4k3/8/8/8/8/8/PPPPPPP1/3QQ2K'), null);

  // Three queens needs two pawns gone, and only two are.
  assert.equal(materialProblem('4k3/8/8/8/8/8/PPPPPP2/2QQQ2K'), null);
  assert.match(materialProblem('4k3/8/8/8/8/8/PPPPPPP1/2QQQ2K'), /viška/);
});

test('a number printed over two diagrams binds to neither', () => {
  // The second test book numbers its final test *and* its worked examples, so
  // its number 6 stands over two boards. Both used to be handed the same
  // solution, and the one it did not belong to reported the book's own move as
  // illegal — which reads as a broken glyph map.
  const positions = [
    { label: 6, page: 40, solutionLegal: false, problem: 'potez iz knjige "Re7+" nije legalan' },
    { label: 6, page: 78, solutionLegal: true, problem: null },
    { label: 7, page: 79, solutionLegal: true, problem: null },
    { label: null, page: 12, solutionLegal: null, problem: null },
  ];

  flagDuplicateNumbers(positions);

  assert.match(positions[0].problem, /broj 6 stoji na više dijagrama \(strane 40, 78\)/);
  assert.match(positions[1].problem, /broj 6 stoji na više dijagrama/);
  assert.equal(positions[0].solutionLegal, null, 'not called illegal — called unbound');
  assert.equal(positions[1].solutionLegal, null, 'the right one is not guessed at either');

  assert.equal(positions[2].problem, null, 'a unique number is left alone');
  assert.equal(positions[3].problem, null, 'an unnumbered diagram has nothing to collide with');
});

// A book this scanner cannot read is not one problem but three, and only the
// third of them wants a glyph map. Reported as one, the other two send the
// reader off to derive a map for a font that is not in the file at all.

function span(text, x, y, fontId = 'f1') {
  return { text, x, y, width: text.length * 6, height: 9, fontId };
}

test('nothing on the page is reported as a scan, not as an unknown font', () => {
  // Two of the books tried on 5.9.2026: 252 and 388 pages, one image per page,
  // zero text spans in either. The old code reached the same message here with
  // an empty list of unknown glyphs and did not notice the list was empty.
  assert.equal(classifyUnreadable([[], []]).code, 'no_text');
});

test('prose without diagrams is not an alphabet we failed to recognise', () => {
  // An OCR text layer over picture diagrams. Its words are 8 to 12 characters
  // with no space in them, exactly like a diagram row, and the book that hit
  // this reported "e" 26 times and "t" 5 as unknown chess glyphs.
  const prose = [
    span('Nowadays this move is rarely seen at', 34, 200),
    span('the top level, and only then as a', 34, 212),
    span('Nowadays', 34, 224),
    span('eliminate', 120, 236),
    span('exchanging', 210, 248),
  ];

  const verdict = classifyUnreadable([prose]);
  assert.equal(verdict.code, 'no_diagram_text');
  assert.deepEqual(verdict.unknownGlyphs, [], 'no letter of English prose is a chess glyph');
});

test('eight rows stacked in a column are a diagram, and then the font is the problem', () => {
  const prose = [
    span('Nowadays this move is rarely seen at', 34, 200),
    span('eliminate', 120, 236),
  ];
  const rows = [];
  for (let i = 0; i < 8; i += 1) rows.push(span('§§§§§§§§', 100, 300 + i * 11, 'f2'));

  const verdict = classifyUnreadable([[...prose, ...rows]]);
  assert.equal(verdict.code, 'unknown_font');
  assert.deepEqual(verdict.unknownGlyphs, [['§', 64]]);
  assert.ok(
    !verdict.unknownGlyphs.some(([glyph]) => glyph === 'e'),
    'the glyph list names the diagram, never the prose around it'
  );
});

test('a PDF with no text reaches the caller as no_text, not as unknown_font', async (t) => {
  // End to end through scanDocument, because the classification being right
  // and the scanner asking it are two different things.
  const objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Resources << >> >>',
  ];
  const lines = ['%PDF-1.4'];
  const offsets = [];
  let length = lines[0].length + 1;
  objects.forEach((body, i) => {
    offsets.push(length);
    const object = [`${i + 1} 0 obj`, body, 'endobj'];
    lines.push(...object);
    length += object.reduce((sum, line) => sum + line.length + 1, 0);
  });

  const startxref = length;
  lines.push('xref', `0 ${objects.length + 1}`, '0000000000 65535 f ');
  for (const at of offsets) lines.push(`${String(at).padStart(10, '0')} 00000 n `);
  lines.push('trailer', `<< /Size ${objects.length + 1} /Root 1 0 R >>`, 'startxref', `${startxref}`, '%%EOF', '');
  const pdf = lines.join('\n');

  const file = join(tmpdir(), 'scanner-no-text-' + process.pid + '.pdf');
  await writeFile(file, Buffer.from(pdf, 'latin1'));
  t.after(() => rm(file, { force: true }));

  await assert.rejects(
    () => scanDocument({ filePath: file, fromPage: 1, toPage: 1 }),
    (err) => {
      assert.equal(err.code, 'no_text');
      assert.match(err.message, /nema nikakvog teksta/);
      return true;
    }
  );
});
