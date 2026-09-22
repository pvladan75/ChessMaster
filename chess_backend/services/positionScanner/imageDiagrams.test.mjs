// Phase 1 of docs/PLAN-SKENER-SLIKE.md: boards cut out of a PDF whose
// diagrams are pictures. Every fixture is drawn here with @napi-rs/canvas and
// wrapped in a PDF built by hand — no book is in the repository, and the three
// faults phase 0 met on a real scan (a broken frame, a double frame, a square
// that is not a board) are drawn on purpose.
import test from 'node:test';
import assert from 'node:assert/strict';

import { findBoard, boardsOnScan, cropBoard } from './boards.mjs';
import { toGray } from './images.mjs';
import { findImageDiagrams } from './imageDiagrams.mjs';

import {
  createCanvas, canvasGray, diagramImage, scannedPage, tempPdf,
} from '../../test/support/drawnBooks.mjs';

// ---------------------------------------------------------------- the gate

test('1. the frame of a diagram image is found to within a pixel, beside its rank numbers', () => {
  const { gray, width, height, frame } = diagramImage();
  const box = findBoard(gray, width, height);
  assert.ok(box, 'no board found in a drawn diagram');
  for (const side of ['top', 'bottom', 'left', 'right']) {
    assert.ok(Math.abs(box[side] - frame[side]) <= 1,
      `${side}: found ${box[side]}, drawn ${frame[side]}`);
  }
});

test('1. a diagram-shaped image with no frame is refused, not cut anyway', () => {
  const canvas = createCanvas(500, 480);
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#fff';
  ctx.fillRect(0, 0, 500, 480);
  ctx.fillStyle = '#000';
  ctx.beginPath();
  ctx.arc(250, 240, 150, 0, Math.PI * 2);
  ctx.fill();
  const { gray, width, height } = canvasGray(canvas);
  assert.equal(findBoard(gray, width, height), null);
});

test('2. every storage pdfjs hands back decodes to the same grey picture', async (t) => {
  const picture = diagramImage();
  const pages = ['bit1', 'gray8', 'rgb'].map((storage) => ({
    size: [400, 400],
    images: [{ picture, storage, rect: [20, 20, 268, 240] }],
  }));
  const file = await tempPdf(t, pages);
  const found = await findImageDiagrams(file, { fromPage: 1, toPage: 3 });
  assert.equal(found.diagrams.length, 3, JSON.stringify(found.refused));
  for (const d of found.diagrams) {
    assert.equal(d.source, 'image');
    for (const side of ['top', 'bottom', 'left', 'right']) {
      assert.ok(Math.abs(d.box[side] - picture.frame[side]) <= 1,
        `page ${d.page} ${side}: ${d.box[side]} vs ${picture.frame[side]}`);
    }
  }
  // The same board, whichever way it was stored. Grey and RGB hold the same
  // pixels, so their crops agree to rounding. A 1-bit image holds the picture
  // thresholded at 128 — the canvas's antialiased edges are gone — so its crop
  // must equal the crop of exactly that, pixel for pixel, not "be close".
  const [a, b, c] = found.diagrams.map((d) => d.board);
  const diff = (x, y) => x.reduce((s, v, i) => s + Math.abs(v - y[i]), 0) / x.length;
  assert.ok(diff(b, c) < 1, `grey and RGB crops differ by ${diff(b, c)}`);
  const thresholded = picture.gray.map((v) => (v >= 128 ? 255 : 0));
  const expected = cropBoard(thresholded, picture.width, found.diagrams[0].box);
  assert.equal(diff(a, expected), 0, '1-bit crop is not the thresholded picture');
});

test('2. toGray reads a 1-bit image with 1 as white', () => {
  // Two pixels in one byte: white then black.
  const gray = toGray({ width: 2, height: 1, kind: 1, data: new Uint8ClampedArray([0b10000000]) });
  assert.deepEqual([...gray], [255, 0]);
});

test('1. a framed table in a diagram-shaped image is not a board', () => {
  // Long ruled lines pass the frame test on their own; a frame that is not
  // square, or fills too little of the picture, must still be refused.
  const canvas = createCanvas(520, 480);
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#fff';
  ctx.fillRect(0, 0, 520, 480);
  ctx.fillStyle = '#000';
  // Rules 500 wide and 300 tall: both pass the frame-line test (more than 60%
  // of the picture), so only the shape — 500 x 300 is no square — refuses it.
  for (const y of [90, 190, 290, 387]) ctx.fillRect(10, y, 500, 3);
  ctx.fillRect(10, 90, 3, 300);
  ctx.fillRect(507, 90, 3, 300);
  const { gray, width, height } = canvasGray(canvas);
  assert.equal(findBoard(gray, width, height), null);
});

test('3. a scanned page gives exactly its two boards: broken frame found, double frame cut outside', () => {
  const page = scannedPage();
  const boxes = boardsOnScan(page.gray, page.width, page.height);
  assert.equal(boxes.length, 2, `found ${JSON.stringify(boxes)}`);
  const byTop = [...boxes].sort((p, q) => p.top - q.top);
  const [broken, double] = byTop;
  for (const [box, drawn, name] of [[broken, page.broken, 'broken'], [double, page.double, 'double']]) {
    assert.ok(Math.abs(box.top - drawn.top) <= 1, `${name} top ${box.top} vs ${drawn.top}`);
    assert.ok(Math.abs(box.left - drawn.left) <= 1, `${name} left ${box.left} vs ${drawn.left}`);
    assert.ok(Math.abs(box.right - box.left + 1 - drawn.size) <= 2,
      `${name} width ${box.right - box.left + 1} vs ${drawn.size}`);
  }
});

test('3. a crop is 512 x 512 and keeps light squares light and dark ones darker', () => {
  const { gray, width, height } = diagramImage();
  const box = findBoard(gray, width, height);
  const board = cropBoard(gray, width, box);
  assert.equal(board.length, 512 * 512);
  const cellMean = (r, c) => {
    let s = 0;
    for (let y = r * 64 + 16; y < r * 64 + 48; y++) {
      for (let x = c * 64 + 16; x < c * 64 + 48; x++) s += board[y * 512 + x];
    }
    return s / (32 * 32);
  };
  // a6 is light (row 2, col 0), b6 dark; neither holds a disc.
  assert.ok(cellMean(2, 0) - cellMean(2, 1) > 40,
    `light ${cellMean(2, 0)} vs dark ${cellMean(2, 1)}`);
});

test('3. enlarging a small board keeps a line the same whichever pixel it falls on', () => {
  // A scanned board is often smaller than 512 (Silman's are about 350 px), so
  // it is enlarged. Enlarged in blocks, a 1-pixel line comes out one pixel
  // thick or two depending on where it falls, so the same piece looks
  // different on different squares — measured in phase 2: white pawns on
  // light squares read as empty on 4 boards in 24 until enlarging was
  // bilinear. Two lines must carry the same ink. (Columns 100 and 203 are
  // chosen because blocks give the first one output column and the second
  // two; a first draft used 201, which blocks also give one, and the block
  // version passed it.)
  const w = 350;
  const gray = new Uint8Array(w * w).fill(255);
  for (let y = 0; y < w; y++) {
    gray[y * w + 100] = 0;
    gray[y * w + 203] = 0;
  }
  const out = cropBoard(gray, w, { top: 0, bottom: w - 1, left: 0, right: w - 1 });
  const inkNear = (col) => {
    const c = Math.round(((col + 0.5) * 512) / w);
    let ink = 0;
    for (let x = c - 4; x <= c + 4; x++) ink += 255 - out[256 * 512 + x];
    return ink;
  };
  const a = inkNear(100);
  const b = inkNear(203);
  // Measured: bilinear 336 and 383 (12% apart), blocks 255 and 510 (the one
  // line twice the other). The bound sits between the two.
  assert.ok(Math.abs(a - b) / Math.max(a, b) < 0.25, `a line at x=100 carries ink ${a}, at x=203 ${b}`);
});

test('4. end to end: a diagram page and a scanned page give three boards with page and source', async (t) => {
  const diagram = diagramImage();
  const scan = scannedPage();
  const file = await tempPdf(t, [
    { size: [400, 400], images: [{ picture: diagram, storage: 'bit1', rect: [30, 40, 268, 240] }] },
    { size: [420, 600], images: [{ picture: scan, storage: 'bit1', rect: [0, 0, 420, 600] }] },
  ]);
  const found = await findImageDiagrams(file, { fromPage: 1, toPage: 2 });
  const summary = found.diagrams.map((d) => `${d.page}:${d.source}`);
  assert.deepEqual(summary, ['1:image', '2:scan', '2:scan']);
  // The image's place on the page travels with it, top-down, in points.
  const [x, y, w, h] = found.diagrams[0].rect;
  assert.deepEqual([x, y, w, h].map(Math.round), [30, 40, 268, 240]);
});

test('4. a PDF with no images gives no boards, and says it saw none', async (t) => {
  const file = await tempPdf(t, [{ size: [200, 200], images: [] }]);
  const found = await findImageDiagrams(file, { fromPage: 1, toPage: 1 });
  assert.equal(found.diagrams.length, 0);
  assert.equal(found.imagesSeen, 0);
});
