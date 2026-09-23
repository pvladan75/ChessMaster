// Books drawn in a test, never taken from a real one — the fixtures of
// docs/PLAN-SKENER-SLIKE.md phases 1 and 2. Boards, scanned pages and PDFs are
// drawn here with @napi-rs/canvas and wrapped in a PDF built by hand. Pieces
// are geometric shapes, never letters: a test that draws text reads the
// machine's fonts (CLAUDE.md, rule 8).
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import { writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const require = createRequire(import.meta.url);
export const { createCanvas } = require('@napi-rs/canvas');

// ---------------------------------------------------------------- drawing

/** A board drawn on `ctx`: a 3 px frame, hatched dark squares, a few pieces
 *  as filled discs. `broken` leaves a gap in the top of the frame; `outer`
 *  draws a second frame 6 px outside the first, with paper between them —
 *  two separate outlines, as on the scanned book where keeping the inner one
 *  cut the h-file short. (A second frame *inside* would touch the hatching and
 *  make one outline, and a test drawn that way cannot see the order.) */
export function drawBoard(ctx, x0, y0, size, { broken = false, outer = false, pieces = true } = {}) {
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
  for (const [r, c] of pieces ? [[0, 4], [7, 4], [1, 1], [6, 6]] : []) {
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

export function canvasGray(canvas) {
  const { data, width, height } = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height);
  const gray = new Uint8Array(width * height);
  for (let i = 0; i < gray.length; i++) gray[i] = data[i * 4];
  return { gray, width, height };
}

/** A diagram image as a book prints it: rank numbers down the left, the
 *  board beside them. Returns the picture and where its frame was drawn. */
export function diagramImage() {
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
export function scannedPage() {
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
export function encode({ gray, width, height }, storage) {
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

/** pages: [{ size: [w, h], images: [{ picture, storage, rect: [x, y, w, h] }],
 *  content? }] with `rect` in PDF points, y measured from the top of the page.
 *  `content` is drawing operators added after the images, in PDF's own
 *  coordinates (vectorBoard writes them). `text: [{ x, top, size, str }]` is
 *  set in an embedded font — pdfjs-dist's own Liberation Sans, never one of
 *  the machine's (CLAUDE.md, rule 8) — so a page has glyphs to draw. */
export function buildPdf(pages) {
  const objects = [];
  const add = (body) => { objects.push(body); return objects.length; };
  const catalog = add(null);
  const pagesId = add(null);
  const kids = [];
  let font = null;
  const fontId = () => {
    if (font) return font;
    const bytes = readFileSync(require.resolve('pdfjs-dist/standard_fonts/LiberationSans-Regular.ttf'));
    const file = add([`<< /Length ${bytes.length} /Length1 ${bytes.length} >>`, bytes]);
    const descriptor = add(`<< /Type /FontDescriptor /FontName /LiberationSans /Flags 32 /FontBBox [-203 -303 1050 910]`
      + ` /ItalicAngle 0 /Ascent 905 /Descent -212 /CapHeight 1409 /StemV 80 /FontFile2 ${file} 0 R >>`);
    font = add(`<< /Type /Font /Subtype /TrueType /BaseFont /LiberationSans /Encoding /WinAnsiEncoding`
      + ` /FontDescriptor ${descriptor} 0 R >>`);
    return font;
  };
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
    content += page.content ?? '';
    for (const { x, top, size, str } of page.text ?? []) {
      content += `BT /F1 ${size} Tf ${x} ${ph - top - size} Td (${str}) Tj ET\n`;
    }
    const fonts = page.text?.length ? ` /Font << /F1 ${fontId()} 0 R >>` : '';
    const contentId = add([`<< /Length ${content.length} >>`, Buffer.from(content, 'latin1')]);
    kids.push(add(`<< /Type /Page /Parent ${pagesId} 0 R /MediaBox [0 0 ${pw} ${ph}]`
      + ` /Resources << /XObject << ${xobjects.join(' ')} >>${fonts} >> /Contents ${contentId} 0 R >>`));
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

/** A board drawn in PDF operators, as a chess font's page draws it when it is
 *  rendered: a frame, dark squares hatched with hairlines, pieces as filled
 *  discs. No font and no image — which is the book the image path could not
 *  see before phase 3h. `hatch` and `spacing` are in points; the defaults ink
 *  about 7% of a dark square, so its cells average some 237 against 255 on a
 *  white one: lighter than the books measured (229–233), inside the contrast
 *  15 accepts and outside the 25 that was there before. `x`, `top` put the
 *  board's top-left corner, y from the top of a page `pageHeight` tall. */
export function vectorBoard(x, top, size, pageHeight, { hatch = 0.2, spacing = 4, pieces = [[0, 4], [7, 4], [2, 2], [5, 6]] } = {}) {
  const cell = size / 8;
  const bottom = pageHeight - top - size;
  const f = (v) => v.toFixed(3);
  let ops = `q ${f(hatch)} w 0 G 0 g\n`;
  for (let r = 0; r < 8; r++) {
    for (let c = 0; c < 8; c++) {
      if ((r + c) % 2 === 0) continue;
      const sx = x + c * cell;
      const sy = bottom + (7 - r) * cell;
      ops += `q ${f(sx)} ${f(sy)} ${f(cell)} ${f(cell)} re W n\n`;
      for (let k = -cell; k < cell; k += spacing) {
        ops += `${f(sx + k)} ${f(sy)} m ${f(sx + k + cell)} ${f(sy + cell)} l S\n`;
      }
      ops += 'Q\n';
    }
  }
  const K = 0.5523;
  for (const [r, c] of pieces) {
    const cx = x + (c + 0.5) * cell;
    const cy = bottom + (7 - r + 0.5) * cell;
    const rad = cell * 0.3;
    const k = rad * K;
    ops += `${f(cx + rad)} ${f(cy)} m `
      + `${f(cx + rad)} ${f(cy + k)} ${f(cx + k)} ${f(cy + rad)} ${f(cx)} ${f(cy + rad)} c `
      + `${f(cx - k)} ${f(cy + rad)} ${f(cx - rad)} ${f(cy + k)} ${f(cx - rad)} ${f(cy)} c `
      + `${f(cx - rad)} ${f(cy - k)} ${f(cx - k)} ${f(cy - rad)} ${f(cx)} ${f(cy - rad)} c `
      + `${f(cx + k)} ${f(cy - rad)} ${f(cx + rad)} ${f(cy - k)} ${f(cx + rad)} ${f(cy)} c f\n`;
  }
  ops += `1 w ${f(x)} ${f(bottom)} ${f(size)} ${f(size)} re S Q\n`;
  return ops;
}

export async function tempPdf(t, pages) {
  const file = join(tmpdir(), `image-diagrams-${process.pid}-${Math.random().toString(36).slice(2)}.pdf`);
  await writeFile(file, buildPdf(pages));
  t.after(() => rm(file, { force: true }));
  return file;
}


// ---------------------------------------------------------------- positions

/** A small deterministic generator, so a drawn board is the same every run. */
export function seeded(seed) {
  let s = seed >>> 0;
  return () => {
    s = (Math.imul(s, 1664525) + 1013904223) >>> 0;
    return s / 2 ** 32;
  };
}

/** One piece as a shape: pawn a small disc, knight a triangle, bishop a
 *  diamond, rook a square, queen a hexagon, king a large disc with a cross.
 *  White is outlined, Black filled. */
function drawPiece(ctx, cx, cy, r, piece) {
  const white = piece === piece.toUpperCase();
  ctx.lineWidth = 3;
  ctx.strokeStyle = '#000';
  ctx.fillStyle = white ? '#fff' : '#000';
  ctx.beginPath();
  switch (piece.toLowerCase()) {
    case 'p': ctx.arc(cx, cy, r * 0.4, 0, Math.PI * 2); break;
    case 'n': ctx.moveTo(cx, cy - r * 0.75); ctx.lineTo(cx + r * 0.7, cy + r * 0.6); ctx.lineTo(cx - r * 0.7, cy + r * 0.6); ctx.closePath(); break;
    case 'b': ctx.moveTo(cx, cy - r * 0.8); ctx.lineTo(cx + r * 0.5, cy); ctx.lineTo(cx, cy + r * 0.8); ctx.lineTo(cx - r * 0.5, cy); ctx.closePath(); break;
    case 'r': ctx.rect(cx - r * 0.6, cy - r * 0.6, r * 1.2, r * 1.2); break;
    case 'q':
      for (let k = 0; k < 6; k++) {
        const a = (Math.PI / 3) * k;
        ctx[k ? 'lineTo' : 'moveTo'](cx + r * 0.75 * Math.cos(a), cy + r * 0.75 * Math.sin(a));
      }
      ctx.closePath();
      break;
    case 'k': ctx.arc(cx, cy, r * 0.8, 0, Math.PI * 2); break;
    default: throw new Error(`not a piece: ${piece}`);
  }
  ctx.fill();
  ctx.stroke();
  if (piece.toLowerCase() === 'k') {
    ctx.strokeStyle = white ? '#000' : '#fff';
    ctx.beginPath();
    ctx.moveTo(cx - r * 0.4, cy); ctx.lineTo(cx + r * 0.4, cy);
    ctx.moveTo(cx, cy - r * 0.4); ctx.lineTo(cx, cy + r * 0.4);
    ctx.stroke();
  }
}

/** The 64 squares of a FEN placement, a8 first. */
export function cellsOf(placement) {
  const cells = [];
  for (const ch of placement.split(' ')[0]) {
    if (ch === '/') continue;
    if (/\d/.test(ch)) for (let n = 0; n < Number(ch); n++) cells.push('.');
    else cells.push(ch);
  }
  return cells;
}

/**
 * A diagram image of `placement`, laid out as diagramImage() lays out its
 * board. `drift` moves every piece up to that many pixels off the middle of
 * its square, as a scan does; `specks` scatters that many small blots of ink;
 * `crosses` draws a teaching cross on the named squares (e.g. ['e4']).
 */
export function positionImage(placement, { drift = 0, specks = 0, crosses = [], seed = 1 } = {}) {
  const random = seeded(seed);
  const canvas = createCanvas(536, 480);
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#fff';
  ctx.fillRect(0, 0, 536, 480);
  const x0 = 52, y0 = 2, size = 476, cell = size / 8;
  drawBoard(ctx, x0, y0, size, { pieces: false });
  cellsOf(placement).forEach((p, i) => {
    if (p === '.') return;
    const r = Math.floor(i / 8), c = i % 8;
    const dx = (random() * 2 - 1) * drift;
    const dy = (random() * 2 - 1) * drift;
    drawPiece(ctx, x0 + (c + 0.5) * cell + dx, y0 + (r + 0.5) * cell + dy, cell * 0.42, p);
  });
  for (const sq of crosses) {
    const c = sq.charCodeAt(0) - 97, r = 8 - Number(sq[1]);
    const cx = x0 + (c + 0.5) * cell, cy = y0 + (r + 0.5) * cell, h = cell * 0.35;
    ctx.strokeStyle = '#000';
    ctx.lineWidth = 5;
    ctx.beginPath();
    ctx.moveTo(cx - h, cy - h); ctx.lineTo(cx + h, cy + h);
    ctx.moveTo(cx + h, cy - h); ctx.lineTo(cx - h, cy + h);
    ctx.stroke();
  }
  ctx.fillStyle = '#000';
  for (let k = 0; k < specks; k++) {
    ctx.fillRect(x0 + 6 + random() * (size - 12), y0 + 6 + random() * (size - 12), 2, 2);
  }
  return canvasGray(canvas);
}
