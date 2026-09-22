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
 * { page, source, box, rect, board }:
 *  - `source` is 'image' (the picture is one diagram) or 'scan' (the board was
 *    found on a scanned page);
 *  - `box` is the board in the image's pixels;
 *  - `rect` is where the image sits on the page, in points, y from the top;
 *  - `board` is the board cut to 512 x 512 grey.
 * `refused` counts every image that gave no board, by reason, so a book that
 * yields nothing says why.
 */
export async function findImageDiagrams(filePath, { fromPage = 1, toPage } = {}) {
  const doc = await openPdf(filePath);
  const last = Math.min(toPage ?? doc.numPages, doc.numPages);
  const diagrams = [];
  const refused = {};
  const refuse = (reason) => { refused[reason] = (refused[reason] ?? 0) + 1; };
  let imagesSeen = 0;
  let undecoded = 0;
  try {
    for (let page = fromPage; page <= last; page++) {
      const found = await pageImages(doc, page);
      undecoded += found.undecoded;
      for (const img of found.images) {
        imagesSeen++;
        if (pageSized(img)) {
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
    }
  } finally {
    await doc.destroy();
  }
  return { diagrams, refused, imagesSeen, undecoded };
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
