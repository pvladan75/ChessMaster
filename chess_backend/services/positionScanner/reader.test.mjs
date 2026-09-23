// Phase 2 of docs/PLAN-SKENER-SLIKE.md: reading a board picture square by
// square from a few calibration boards of the same "book". The boards are
// drawn in test/support/drawnBooks.mjs with geometric pieces; drift and ink
// specks stand in for a scan.
import test from 'node:test';
import assert from 'node:assert/strict';

import { findBoard, cropBoard } from './boards.mjs';
import { calibrate, readBoard, squareName, unsureOf, UNKNOWN_INK } from './reader.mjs';
import { positionImage, cellsOf } from '../../test/support/drawnBooks.mjs';

/** A drawn position cut to the 512 x 512 board the reader takes. */
function board(placement, options) {
  const img = positionImage(placement, options);
  const box = findBoard(img.gray, img.width, img.height);
  assert.ok(box, `no board found in the drawing of ${placement}`);
  return cropBoard(img.gray, img.width, box);
}

// Every piece on both colours of square, except one: the white rooks stand
// on dark squares only (a1, c1). A white rook on a light square is a class
// these boards never show.
const CALIBRATION = [
  'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBN1',
  '7k/8/8/3q4/8/8/8/1KQ5',
  'r3k2r/1b1n1p2/2p5/8/3B4/2N5/1P3P2/2R3K1',
];

let calibrated;
function calibration() {
  calibrated ??= calibrate(CALIBRATION.map((fen, k) => ({ board: board(fen, { seed: 10 + k }), fen })));
  return calibrated;
}

function readPlacement(placement, options) {
  return readBoard(board(placement, options), calibration());
}

function wrongSquares(placement, cells) {
  const want = cellsOf(placement);
  return cells.flatMap((c, i) => (c.piece === want[i] ? [] : [`${squareName(i)}: ${want[i]} read as ${c.piece}`]));
}

test('1. a class the calibration never showed is composed, and named as composed', () => {
  assert.ok(calibration().composed.includes('R/light'), `composed: ${calibration().composed}`);
});

const READING = [
  '4k2r/8/8/8/8/8/8/R3K2R', // h1: a white rook on a light square
  'r1bq1rk1/pp2bppp/2n1pn2/3p4/2PP4/2N1PN2/PP2BPPP/R2QKB1R',
  '8/5k2/8/3Q4/8/2n5/5B2/6K1',
  '2kr3r/ppqb1ppp/2n1pn2/3p4/1bPP4/2NBPN2/PPQ2PPP/R1B2RK1',
];

test('1. the composed class is read: a white rook on a light square, every time', () => {
  for (let seed = 0; seed < 4; seed++) {
    const cells = readPlacement(READING[0], { drift: 3, specks: 30, seed: 300 + seed });
    assert.equal(cells[63].piece, 'R', `h1 read as ${cells[63].piece} (seed ${seed})`);
  }
});

test('1. other positions of the same book: at least 99% of squares right, drifting and specked', () => {
  // Measured while writing this gate, over these 16 boards: 5 of 1024 squares
  // wrong, all of them one black bishop on e7 read as a pawn — this fixture's
  // bishop is a small filled diamond and its pawn a small filled disc, and
  // the calibration shows a black bishop on a dark square only once, on the
  // rim. Every one of them marked (the next case). A bound over many boards,
  // not an exact read of a lucky one.
  let wrong = 0;
  let squares = 0;
  const seen = [];
  for (let seed = 0; seed < 4; seed++) {
    for (const placement of READING) {
      const cells = readPlacement(placement, { drift: 3, specks: 30, seed: 300 + seed });
      const errs = wrongSquares(placement, cells);
      wrong += errs.length;
      squares += 64;
      seen.push(...errs);
    }
  }
  assert.ok(wrong / squares <= 0.01, `${wrong} of ${squares} squares wrong: ${seen.join('; ')}`);
});

test('2. pieces drifting twice as far may be misread, but never silently', () => {
  // The product's promise is D1 of the plan: a square read wrong is marked.
  // Measured over these 16 boards at 6 px: 2 squares wrong, both marked.
  // From 8 px it stops holding — every unmarked miss was a white rook on the
  // h1 corner, a composed class drawn half over the frame — and that limit is
  // written in the plan rather than asserted away here.
  let wrong = 0;
  for (let seed = 0; seed < 4; seed++) {
    for (const placement of READING) {
      const want = cellsOf(placement);
      const cells = readPlacement(placement, { drift: 6, specks: 40, seed: 300 + seed });
      cells.forEach((c, i) => {
        if (c.piece === want[i]) return;
        wrong++;
        assert.ok(c.unsure, `${squareName(i)}: ${want[i]} read as ${c.piece}, unmarked (gap ${c.gap})`);
      });
    }
  }
  // If nothing is misread here the case proves nothing about marks.
  assert.ok(wrong > 0, 'no square was misread at 6 px, so this case cannot see an unmarked one');
});

test('2. a square read as a composed class is marked, however clear its gap', () => {
  // A composed template is a guess about how the book draws a piece it never
  // showed; a guess is never trusted. h1 holds the composed white rook.
  const cells = readPlacement(READING[0], { seed: 9 });
  assert.equal(cells[63].piece, 'R');
  assert.ok(cells[63].unsure, `h1 read as the composed R with gap ${cells[63].gap}, unmarked`);
});

test('2. a teaching cross on an empty square is marked, not read quietly', () => {
  const placement = 'r3k3/8/8/8/8/8/8/4K2R';
  const cells = readPlacement(placement, { crosses: ['d5'], seed: 7 });
  assert.equal(squareName(27), 'd5');
  const d5 = cells[27];
  assert.ok(d5.unsure, `d5 read as ${d5.piece} with gap ${d5.gap}, not marked`);
});

test('2. a clean board of the same book is not covered in marks', () => {
  // A mark that falls on every square is no mark at all: the check above
  // only means something if an ordinary board keeps its marks few.
  const cells = readPlacement('8/5k2/8/3Q4/8/2n5/5B2/6K1', { seed: 55 });
  const marked = cells.filter((c) => c.unsure);
  assert.ok(marked.length <= 3, `${marked.length} squares marked on a clean board`);
});

// Phase 3e of the plan: a piece the calibration never showed on either colour
// cannot be composed. Its squares come out as whatever fits best, so the
// answer names the piece, and a square that far from everything known is
// marked however clear its gap.
const NO_BLACK_QUEEN = [
  'rnb1kbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBN1',
  '7k/8/8/8/8/8/8/1KQ5',
  'r3k2r/1b1n1p2/2p5/8/3B4/2N5/1P3P2/2R3K1',
];
let withoutQueen;
function calibrationWithoutQueen() {
  withoutQueen ??= calibrate(NO_BLACK_QUEEN.map((fen, k) => ({ board: board(fen, { seed: 40 + k }), fen })));
  return withoutQueen;
}

test('3e. a piece shown on neither colour is named unseen, and a composed one is not', () => {
  const c = calibrationWithoutQueen();
  assert.deepEqual(c.unseen, ['q']);
  assert.ok(!c.composed.some((k) => k.startsWith('q/')), `composed: ${c.composed}`);
  // The full calibration shows every piece: nothing unseen, R/light composed.
  assert.deepEqual(calibration().unseen, []);
});

test('3e. a square farther than UNKNOWN_INK from every example is marked, whatever its gap', () => {
  // The threshold was measured on the owner's three books (plan, 3e.0): with
  // a piece left out of the calibration, its squares on a scan sat above it
  // and known pieces below. These drawn pieces are small plain shapes, all
  // within 0.055 of one another, so a drawn board cannot stand on that line;
  // the rule is held here at its boundary, and its number by the measurement.
  const calibrated = { cut: 0.02 };
  const clear = { gap: 0.5, guessed: false };
  assert.equal(unsureOf({ ...clear, d1: UNKNOWN_INK }, calibrated), false, 'at the threshold is not beyond it');
  assert.equal(unsureOf({ ...clear, d1: UNKNOWN_INK + 0.001 }, calibrated), true, 'just beyond it is marked');
  assert.equal(unsureOf({ ...clear, d1: 0.05 }, calibrated), false, 'a known piece stays unmarked');
  // The two older rules still hold on their own.
  assert.equal(unsureOf({ gap: 0.01, guessed: false, d1: 0 }, calibrated), true, 'a small gap');
  assert.equal(unsureOf({ gap: 0.5, guessed: true, d1: 0 }, calibrated), true, 'a composed class');
  assert.equal(UNKNOWN_INK, 0.1, 'the measured threshold; change it only with a new measurement');
});

test('3e. a reading marks ink the calibration never showed, with the gap taken out of it', () => {
  // A teaching cross is such ink: no calibration board shows one. With the cut
  // set below every gap, only the distance can mark it.
  const noGap = { ...calibration(), cut: -Infinity };
  const cells = readBoard(board('r3k3/8/8/8/8/8/8/4K2R', { crosses: ['d5'], seed: 7 }), noGap);
  assert.ok(cells[27].d1 > UNKNOWN_INK, `the cross on d5 is only ${cells[27].d1} from ${cells[27].piece}`);
  assert.equal(cells[27].guessed, false);
  assert.ok(cells[27].unsure, 'd5 holds a cross the calibration never showed, and is unmarked');
});

test('3e. pieces the calibration did show are never that far', () => {
  // The distance mark only means something if it stays off known pieces.
  for (const [k, placement] of READING.entries()) {
    const cells = readPlacement(placement, { drift: 3, specks: 30, seed: 500 + k });
    const far = cells.flatMap((c, i) => (c.d1 > UNKNOWN_INK ? [`${squareName(i)} ${c.piece} ${c.d1.toFixed(3)}`] : []));
    assert.deepEqual(far, [], `squares of known pieces marked as unknown ink on ${placement}`);
  }
});
