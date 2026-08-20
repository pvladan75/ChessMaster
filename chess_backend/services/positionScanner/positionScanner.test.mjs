// node --test test.mjs
//
// Covers the two places where this pipeline can be wrong quietly: notation that
// parses into the wrong move, and FEN metadata a diagram cannot show.
import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeSan, splitFirstMove, parseSolutionLines } from './solutions.mjs';
import { rowToFenRank, FONT_MAPS, selectFontMap } from './fonts.mjs';
import { buildPosition } from './verify.mjs';

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
