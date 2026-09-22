// Phase 1 of docs/PLAN-SKENER-SLIKE.md: boards cut out of a PDF whose
// diagrams are pictures. Every fixture is drawn here with @napi-rs/canvas and
// wrapped in a PDF built by hand — no book is in the repository, and the three
// faults phase 0 met on a real scan (a broken frame, a double frame, a square
// that is not a board) are drawn on purpose.
import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { findBoard, boardsOnScan, cropBoard } from './boards.mjs';
import { toGray } from './images.mjs';
import { findImageDiagrams } from './imageDiagrams.mjs';

const require = createRequire(import.meta.url);
const { createCanvas } = require('@napi-rs/canvas');

// ---------------------------------------------------------------- drawing

/** A board drawn on `ctx`: a 3 px frame, hatched dark squares, a few pieces
 *  as filled discs. `broken` leaves a gap in the top of the frame; `outer`
 *  draws a second frame 6 px outside the first, with paper between them —
 *  two separate outlines, as on the scanned book where keeping the inner one
 *  cut the h-file short. (A second frame *inside* would touch the hatching and
 *  make one outline, and a test drawn that way cannot see the order.) */
function drawBoard(ctx, x0, y0, size, { broken = false, outer = false } = {}) {
  const cell = size / 8;
  ctx.fillStyle = '#000';
  for (let r = 0; r < 8; r++) {
    for (let c = 0; c < 8; c++) {
      if ((r + c) % 2 === 0) continue;
      const x = x0 + c * cell;
      const y = y0 + r * cell;
      // Diagonal hatching, clipped to the square.
      ctx.save();
      ctx.beginPath();
      ctx.rect(x, y, cell, cell);
      ctx.clip();
      ctx.lineWidth = 2;
      ctx.strokeStyle = '#000';
      for (let k = -cell; k < cell; k += 6) {
        ctx.beginPath();
        ctx.moveTo(x + k, y + cell);
        ctx.lineTo(x + k + cell, y);
        ctx.stroke();
      }
      ctx.restore();
    }
  }
  for (const [r, c] of [[0, 4], [7, 4], [1, 1], [6, 6]]) {
    ctx.beginPath();
    ctx.arc(x0 + (c + 0.5) * cell, y0 + (r + 0.5) * cell, cell * 0.3, 0, Math.PI * 2);
    ctx.fill();
  }
  const frame = (x, y, s) => {
    ctx.fillRect(x, y, s, 3);
    ctx.fillRect(x, y + s - 3, s, 3);
    ctx.fillRect(x, y, 3, s);
    ctx.fillRect(x + s - 3, y, 3, s);
  };
  frame(x0, y0, size);
  if (outer) frame(x0 - 6, y0 - 6, size + 12);
  if (broken) {
    ctx.fillStyle = '#fff';
    ctx.fillRect(x0 + size / 3, y0, 24, 3);
  }
}

function canvasGray(canvas) {
  const { data, width, height } = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height);
  const gray = new Uint8Array(width * height);
  for (let i = 0; i < gray.length; i++) gray[i] = data[i * 4];
  return { gray, width, height };
}

/** A diagram image as a book prints it: rank numbers down the left, the
 *  board beside them. Returns the picture and where its frame was drawn. */
function diagramImage() {
  const canvas = createCanvas(536, 480);
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#fff';
  ctx.fillRect(0, 0, 536, 480);
  ctx.fillStyle = '#000';
  ctx.font = '28px sans-serif';
  for (let r = 0; r < 8; r++) ctx.fillText(String(8 - r), 8, 40 + r * 58);
  drawBoard(ctx, 52, 2, 476);
  return { ...canvasGray(canvas), frame: { top: 2, bottom: 477, left: 52, right: 527 } };
}

/** A scanned page: text, a plain framed square that is not a board, a board
 *  with a broken frame and one with a double frame. */
function scannedPage() {
  const canvas = createCanvas(1400, 2000);
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#fff';
  ctx.fillRect(0, 0, 1400, 2000);
  ctx.fillStyle = '#000';
  for (let line = 0; line < 12; line++) {
    for (let x = 100; x < 1250; x += 70) ctx.fillRect(x, 60 + line * 30, 50, 14);
  }
  ctx.fillRect(900, 500, 300, 4);
  ctx.fillRect(900, 796, 300, 4);
  ctx.fillRect(900, 500, 4, 300);
  ctx.fillRect(1196, 500, 4, 300);
  drawBoard(ctx, 100, 500, 400, { broken: true });
  drawBoard(ctx, 700, 1200, 440, { outer: true });
  return {
    ...canvasGray(canvas),
    broken: { top: 500, left: 100, size: 400 },
    // Cut at the outer frame.
    double: { top: 1194, left: 694, size: 452 },
  };
}

// ---------------------------------------------------------------- a PDF

/** Image bytes for a PDF image XObject in one of three storages. */
function encode({ gray, width, height }, storage) {
  if (storage === 'gray8') return { bytes: Buffer.from(gray), cs: '/DeviceGray', bpc: 8 };
  if (storage === 'rgb') {
    const out = Buffer.alloc(width * height * 3);
    for (let i = 0; i < gray.length; i++) out[i * 3] = out[i * 3 + 1] = out[i * 3 + 2] = gray[i];
    return { bytes: out, cs: '/DeviceRGB', bpc: 8 };
  }
  // 1 bit per pixel, rows padded to a byte; 1 is white.
  const rowBytes = Math.ceil(width / 8);
  const out = Buffer.alloc(rowBytes * height);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      if (gray[y * width + x] >= 128) out[y * rowBytes + (x >> 3)] |= 0x80 >> (x & 7);
    }
  }
  return { bytes: out, cs: '/DeviceGray', bpc: 1 };
}

/** pages: [{ size: [w, h], images: [{ picture, storage, rect: [x, y, w, h] }] }]
 *  with `rect` in PDF points, y measured from the top of the page. */
function buildPdf(pages) {
  const objects = [];
  const add = (body) => { objects.push(body); return objects.length; };
  const catalog = add(null);
  const pagesId = add(null);
  const kids = [];
  for (const page of pages) {
    const [pw, ph] = page.size;
    const xobjects = [];
    let content = '';
    page.images.forEach((img, k) => {
      const { bytes, cs, bpc } = encode(img.picture, img.storage);
      const id = add([
        `<< /Type /XObject /Subtype /Image /Width ${img.picture.width} /Height ${img.picture.height}`
        + ` /ColorSpace ${cs} /BitsPerComponent ${bpc} /Length ${bytes.length} >>`,
        bytes,
      ]);
      xobjects.push(`/Im${k} ${id} 0 R`);
      const [x, y, w, h] = img.rect;
      content += `q ${w} 0 0 ${h} ${x} ${ph - y - h} cm /Im${k} Do Q\n`;
    });
    const contentId = add([`<< /Length ${content.length} >>`, Buffer.from(content, 'latin1')]);
    kids.push(add(`<< /Type /Page /Parent ${pagesId} 0 R /MediaBox [0 0 ${pw} ${ph}]`
      + ` /Resources << /XObject << ${xobjects.join(' ')} >> >> /Contents ${contentId} 0 R >>`));
  }
  objects[catalog - 1] = `<< /Type /Catalog /Pages ${pagesId} 0 R >>`;
  objects[pagesId - 1] = `<< /Type /Pages /Kids [${kids.map((k) => `${k} 0 R`).join(' ')}] /Count ${kids.length} >>`;

  const chunks = [Buffer.from('%PDF-1.4\n', 'latin1')];
  let length = chunks[0].length;
  const offsets = [];
  objects.forEach((body, i) => {
    offsets.push(length);
    const parts = [Buffer.from(`${i + 1} 0 obj\n`, 'latin1')];
    if (Array.isArray(body)) {
      parts.push(Buffer.from(`${body[0]}\nstream\n`, 'latin1'), body[1], Buffer.from('\nendstream\n', 'latin1'));
    } else {
      parts.push(Buffer.from(`${body}\n`, 'latin1'));
    }
    parts.push(Buffer.from('endobj\n', 'latin1'));
    for (const p of parts) { chunks.push(p); length += p.length; }
  });
  let tail = `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  for (const at of offsets) tail += `${String(at).padStart(10, '0')} 00000 n \n`;
  tail += `trailer\n<< /Size ${objects.length + 1} /Root ${catalog} 0 R >>\nstartxref\n${length}\n%%EOF\n`;
  chunks.push(Buffer.from(tail, 'latin1'));
  return Buffer.concat(chunks);
}

async function tempPdf(t, pages) {
  const file = join(tmpdir(), `image-diagrams-${process.pid}-${Math.random().toString(36).slice(2)}.pdf`);
  await writeFile(file, buildPdf(pages));
  t.after(() => rm(file, { force: true }));
  return file;
}

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
