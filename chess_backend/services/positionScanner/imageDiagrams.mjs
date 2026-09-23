// Boards cut out of a PDF whose diagrams are pictures — phase 1 of
// docs/PLAN-SKENER-SLIKE.md. Nothing here reads a square; that is phase 2.
//
//   node imageDiagrams.mjs BOOK.pdf [FROM-TO] [--boxes OUT.json]
//
// prints how many boards were found and why every other image was refused,
// which is how phase 1 is held to phase 0's counts on the owner's books.
import { writeFile } from 'node:fs/promises';
import { pathToFileURL } from 'node:url';

import { openPdf } from './pdf.mjs';
import { pageImages } from './images.mjs';
import { findBoard, boardsOnScan, cropBoard } from './boards.mjs';
import { renderedBoards } from './render.mjs';
import { ScanError } from './index.mjs';

/** An image the size of a diagram: one board and its coordinates. */
function diagramShaped({ width, height }) {
  return width >= 200 && width <= 2000 && width / height >= 0.8 && width / height <= 1.25;
}

/** An image that covers most of its page: a scanned page. */
function pageSized({ rect, pageSize }) {
  return rect[2] * rect[3] >= 0.6 * pageSize[0] * pageSize[1];
}

/**
 * Every board on pages fromPage..toPage (1-based, inclusive).
 *
 * Returns { diagrams, refused, imagesSeen, undecoded }. Each diagram is
 * { page, index, source, box, rect, board }:
 *  - `index` is its place on the page, from 1, in reading order;
 *  - `source` is 'image' (the picture is one diagram), 'scan' (the board was
 *    found on a scanned page) or 'render' (found on the page as the server
 *    drew it);
 *  - `box` is the board in the image's pixels (or the drawn page's);
 *  - `rect` is where the image sits on the page, in points, y from the top;
 *  - `board` is the board cut to 512 x 512 grey.
 * `refused` counts every image that gave no board, by reason, so a book that
 * yields nothing says why.
 *
 * Pages are drawn (phase 3h, render.mjs) only when the pictures gave **no**
 * board on any page asked for — a book whose diagrams are a chess font no map
 * knows, or lines — and then only the pages that are not a scan, whose
 * drawing would be the scan again. So a picture book is read exactly as
 * before, and a book that is drawn is drawn on every page, which keeps a
 * board's name (page and index) the same from one request to the next. A
 * drawing that fails is a refusal, never "no boards".
 */
/**
 * A page's boards, named 1, 2, … in reading order: the image's place first,
 * then the board's within a scanned or drawn page. The same file gives the
 * same names on every upload, which is what lets a client name a calibration
 * board once and send the book again.
 */
function named(onPage) {
  onPage.sort((a, b) => a.rect[1] - b.rect[1] || a.rect[0] - b.rect[0]
    || a.box.top - b.box.top || a.box.left - b.box.left);
  onPage.forEach((d, k) => { d.index = k + 1; });
  return onPage;
}

export async function findImageDiagrams(filePath, { fromPage = 1, toPage, pages, render = renderedBoards } = {}) {
  const doc = await openPdf(filePath);
  const last = Math.min(toPage ?? doc.numPages, doc.numPages);
  // `pages`, when given, names exactly which pages to open — a range plus the
  // pages a calibration board lies on, which need not be inside it.
  const wanted = pages
    ? [...new Set(pages)].filter((p) => p >= 1 && p <= doc.numPages).sort((x, y) => x - y)
    : Array.from({ length: Math.max(0, last - fromPage + 1) }, (_, k) => fromPage + k);
  const diagrams = [];
  const refused = {};
  const refuse = (reason) => { refused[reason] = (refused[reason] ?? 0) + 1; };
  let imagesSeen = 0;
  let undecoded = 0;
  const scanned = new Set();
  try {
    for (const page of wanted) {
      const found = await pageImages(doc, page);
      const before = diagrams.length;
      undecoded += found.undecoded;
      for (const img of found.images) {
        imagesSeen++;
        if (pageSized(img)) {
          scanned.add(page);
          const boxes = boardsOnScan(img.gray, img.width, img.height);
          if (!boxes.length) refuse('scanned page with no board');
          for (const box of boxes) {
            diagrams.push({ page, source: 'scan', box, rect: img.rect,
              board: cropBoard(img.gray, img.width, box) });
          }
        } else if (diagramShaped(img)) {
          const box = findBoard(img.gray, img.width, img.height);
          if (!box) {
            refuse('no frame');
            continue;
          }
          diagrams.push({ page, source: 'image', box, rect: img.rect,
            board: cropBoard(img.gray, img.width, box) });
        } else {
          refuse('not diagram-shaped');
        }
      }
      diagrams.push(...named(diagrams.splice(before)));
    }
  } finally {
    await doc.destroy();
  }

  const toDraw = diagrams.length ? [] : wanted.filter((p) => !scanned.has(p));
  let rendered = 0;
  if (toDraw.length) {
    let drawn;
    try {
      drawn = await render(filePath, toDraw);
    } catch (err) {
      const refusal = new ScanError('The pages of this book could not be drawn to look for diagrams.', {
        code: 'render_failed',
      });
      refusal.cause = err;
      throw refusal;
    }
    for (const { page, rect, found } of drawn) {
      rendered++;
      if (!found.length) refuse('drawn page with no board');
      diagrams.push(...named(found.map(({ box, board }) => ({ page, source: 'render', box, rect, board }))));
    }
  }
  return { diagrams, refused, imagesSeen, undecoded, rendered };
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [file, ...rest] = process.argv.slice(2);
  const range = rest.find((a) => /^\d+-\d+$/.test(a));
  const [fromPage, toPage] = range ? range.split('-').map(Number) : [1, undefined];
  const boxesAt = rest.includes('--boxes') ? rest[rest.indexOf('--boxes') + 1] : null;
  const started = Date.now();
  const found = await findImageDiagrams(file, { fromPage, toPage });
  const bySource = {};
  for (const d of found.diagrams) bySource[d.source] = (bySource[d.source] ?? 0) + 1;
  console.log(`${found.diagrams.length} boards (${JSON.stringify(bySource)}) from `
    + `${found.imagesSeen} images in ${((Date.now() - started) / 1000).toFixed(1)} s`);
  for (const [reason, n] of Object.entries(found.refused)) console.log(`  refused, ${reason}: ${n}`);
  if (found.undecoded) console.log(`  not decoded by pdfjs: ${found.undecoded}`);
  if (boxesAt) {
    await writeFile(boxesAt, JSON.stringify(found.diagrams.map(
      ({ page, source, box, rect }) => ({ page, source, box, rect })), null, 1));
  }
}
