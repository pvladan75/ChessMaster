// Drawing a PDF's pages and cutting their boards out — the child process of
// render.mjs (phase 3h of docs/PLAN-SKENER-SLIKE.md).
//
// It runs in a process of its own, never a worker thread, because what can
// fail here is native code: a crash in the canvas library takes down the
// process it is in, and a worker thread's process is the server's.
//
// One copy of the canvas library draws everything. pdfjs-dist carries its own
// (0.1.x, beside our 1.x), and if pdfjs is left to make its own scratch
// canvases — it draws a page's embedded picture on one — a picture from one
// copy is handed to the other and the process dies with a segmentation fault
// (measured 23.9.2026 on two books). So the page's canvas, every scratch
// canvas (the factory) and the glyph paths (`Path2D` on globalThis, read by
// pdfjs when it draws a glyph) all come from ours, and the globals are set
// before pdfjs is loaded.
import { createCanvas, Path2D, DOMMatrix, ImageData } from '@napi-rs/canvas';
import { readFile } from 'node:fs/promises';

Object.assign(globalThis, { Path2D, DOMMatrix, ImageData });
const pdfjs = await import('pdfjs-dist/legacy/build/pdf.mjs');
const { boardsOnScan, cropBoard } = await import('./boards.mjs');

class CanvasFactory {
  create(width, height) {
    const canvas = createCanvas(width, height);
    return { canvas, context: canvas.getContext('2d') };
  }

  reset(pair, width, height) {
    pair.canvas.width = width;
    pair.canvas.height = height;
  }

  destroy(pair) {
    pair.canvas.width = 0;
    pair.canvas.height = 0;
    pair.canvas = null;
    pair.context = null;
  }
}

/** A page drawn on white, as 8-bit grey, and the scale it was drawn at. */
async function renderGray(doc, pageNo, dpi, maxPixels) {
  const page = await doc.getPage(pageNo);
  const points = page.getViewport({ scale: 1 });
  const scale = Math.min(dpi / 72, Math.sqrt(maxPixels / (points.width * points.height)));
  const viewport = page.getViewport({ scale });
  const canvas = createCanvas(Math.ceil(viewport.width), Math.ceil(viewport.height));
  const context = canvas.getContext('2d');
  context.fillStyle = '#fff';
  context.fillRect(0, 0, canvas.width, canvas.height);
  await page.render({ canvasContext: context, viewport }).promise;
  const { data, width, height } = context.getImageData(0, 0, canvas.width, canvas.height);
  const gray = new Uint8Array(width * height);
  for (let i = 0, j = 0; i < gray.length; i++, j += 4) gray[i] = (data[j] + data[j + 1] + data[j + 2]) / 3;
  page.cleanup();
  return { gray, width, height, rect: [0, 0, points.width, points.height] };
}

process.once('message', async ({ filePath, pages, dpi, maxPixels }) => {
  const doc = await pdfjs.getDocument({
    data: new Uint8Array(await readFile(filePath)),
    CanvasFactory,
  }).promise;
  try {
    for (const page of pages) {
      const { gray, width, height, rect } = await renderGray(doc, page, dpi, maxPixels);
      const found = boardsOnScan(gray, width, height).map((box) => ({
        box,
        board: cropBoard(gray, width, box),
      }));
      process.send({ page, rect, found });
    }
  } finally {
    await doc.destroy();
  }
  process.send({ done: true }, () => process.exit(0));
});
