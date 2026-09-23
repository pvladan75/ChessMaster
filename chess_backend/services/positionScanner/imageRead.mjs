// A book whose diagrams are pictures, from the upload to the positions read —
// phase 2 of docs/PLAN-SKENER-SLIKE.md. Nothing here saves anything: the
// answer is candidates, and POST /scans/confirm saves what the trainer
// accepts, as it does for the font path.
//
// A book cannot be read with another book's templates (measured: 0 of 24 on a
// scan), and templates cut from a book must not be kept, so a book is read
// with a calibration that travels with the request — the positions of a few of
// its own boards, named by page and place on the page.
import { Worker } from 'node:worker_threads';
import { createRequire } from 'node:module';

import { openPdf } from './pdf.mjs';
import { findImageDiagrams } from './imageDiagrams.mjs';
import { ScanError, clampRange } from './index.mjs';
import { placementCells, placementOf, squareName } from './reader.mjs';

const require = createRequire(import.meta.url);
const { createCanvas } = require('@napi-rs/canvas');
const { validateFen } = require('chess.js');

/** Boards read in one request: about 30 s in the worker. */
export const MAX_IMAGE_BOARDS = 60;
/** Calibration boards in one request. */
export const MAX_CALIBRATION = 8;

const SQUARE = /^[a-h][1-8]$/;

/**
 * The calibration from a request: [] when none was sent, otherwise every
 * entry { page, index, fen, ignore } checked, or a ScanError with
 * `calibration_invalid` naming the entry. A calibration is what every other
 * board is read against, so a malformed one is refused, never half-used.
 */
export function parseCalibration(raw) {
  if (raw === undefined || raw === null || raw === '') return [];
  let list = raw;
  if (typeof raw === 'string') {
    try {
      list = JSON.parse(raw);
    } catch {
      throw new ScanError('The calibration is not JSON.', { code: 'calibration_invalid' });
    }
  }
  if (!Array.isArray(list)) {
    throw new ScanError('The calibration is not a list.', { code: 'calibration_invalid' });
  }
  if (list.length > MAX_CALIBRATION) {
    throw new ScanError(`At most ${MAX_CALIBRATION} calibration boards.`, {
      code: 'calibration_invalid', details: { max: MAX_CALIBRATION },
    });
  }
  return list.map((entry, k) => {
    const bad = (why) => new ScanError(`Calibration board ${k + 1}: ${why}.`, {
      code: 'calibration_invalid', details: { entry: k },
    });
    const page = Number(entry?.page);
    const index = Number(entry?.index);
    if (!Number.isInteger(page) || page < 1) throw bad('no page');
    if (!Number.isInteger(index) || index < 1) throw bad('no index');
    const fen = typeof entry.fen === 'string' ? entry.fen.trim() : '';
    try {
      placementCells(fen);
    } catch {
      throw bad('the position is not a board of 64 squares');
    }
    const ignore = entry.ignore ?? [];
    if (!Array.isArray(ignore) || !ignore.every((s) => SQUARE.test(s))) throw bad('ignore names no squares');
    return { page, index, fen: fen.split(' ')[0], ignore };
  });
}

/**
 * A board as a JPEG, 256 px, for the trainer to look at beside what was read
 * and to find calibration boards by. A PNG of the same picture was 50–150 KB
 * a board on the owner's books, this about 20 (plan, 3e.0 (d)): a whole book
 * is browsed through these.
 */
export function preview(board, size = 512) {
  const half = size / 2;
  const canvas = createCanvas(half, half);
  const ctx = canvas.getContext('2d');
  const img = ctx.createImageData(half, half);
  for (let y = 0; y < half; y++) {
    for (let x = 0; x < half; x++) {
      const i = 2 * y * size + 2 * x;
      const v = (board[i] + board[i + 1] + board[i + size] + board[i + size + 1]) >> 2;
      const o = (y * half + x) * 4;
      img.data[o] = img.data[o + 1] = img.data[o + 2] = v;
      img.data[o + 3] = 255;
    }
  }
  ctx.putImageData(img, 0, 0);
  return canvas.toBuffer('image/jpeg', 80).toString('base64');
}

/** Whether a placement is a position with either side to move. */
function legal(placement) {
  return validateFen(`${placement} w - - 0 1`).ok || validateFen(`${placement} b - - 0 1`).ok;
}

/** Read `boards` in a worker thread against `calibration`. */
function readInWorker(calibration, boards) {
  return new Promise((resolve, reject) => {
    const worker = new Worker(new URL('./readWorker.mjs', import.meta.url), {
      workerData: { calibration, boards },
    });
    let answered = false;
    worker.once('message', (m) => { answered = true; resolve(m); });
    worker.once('error', reject);
    worker.once('exit', (code) => {
      if (!answered) reject(new Error(`the reading worker stopped with code ${code} and no answer`));
    });
  });
}

/**
 * The image path of one upload. Without a calibration: the boards found on
 * the pages, with a preview each — the trainer browses the book through
 * these and chooses the calibration boards himself (phase 3e of the plan). With
 * one: every other board read, `source: 'image'`, its uncertain squares named,
 * and `unseen` naming any piece the calibration shows on neither colour.
 */
export async function scanImages({ filePath, fromPage, toPage, calibration = [] }) {
  const doc = await openPdf(filePath);
  const pageCount = doc.numPages;
  await doc.destroy();
  const { start, end } = clampRange(fromPage, toPage, pageCount, 'pages');

  const pages = [];
  for (let p = start; p <= end; p++) pages.push(p);
  for (const c of calibration) pages.push(c.page);
  const found = await findImageDiagrams(filePath, { pages });

  const key = (d) => `${d.page}:${d.index}`;
  const inRange = found.diagrams.filter((d) => d.page >= start && d.page <= end);
  if (!inRange.length) {
    throw new ScanError('No diagram pictures were found on those pages.', {
      code: 'no_image_diagrams', details: { refused: found.refused },
    });
  }

  const byKey = new Map(found.diagrams.map((d) => [key(d), d]));
  const calibrationBoards = calibration.map((c) => {
    const d = byKey.get(key(c));
    if (!d) {
      throw new ScanError(`There is no board ${c.index} on page ${c.page}.`, {
        code: 'calibration_board_missing', details: { page: c.page, index: c.index },
      });
    }
    return { ...c, board: d.board };
  });
  const calibrated = new Set(calibration.map(key));
  const toRead = inRange.filter((d) => !calibrated.has(key(d)));
  // Only reading is limited: finding boards and drawing their previews is a
  // fraction of a second a page (plan, 3e.0 (d)), and the page range is
  // already capped.
  if (calibration.length && toRead.length > MAX_IMAGE_BOARDS) {
    throw new ScanError(
      `Those pages hold ${inRange.length} diagrams; at most ${MAX_IMAGE_BOARDS} are read at a time. Choose fewer pages.`,
      { code: 'too_many_boards', details: { boards: inRange.length, max: MAX_IMAGE_BOARDS } },
    );
  }

  const base = { pageCount, scannedFrom: start, scannedTo: end, refused: found.refused };

  if (!calibration.length) {
    return {
      ...base,
      needsCalibration: true,
      boards: inRange.map((d) => ({ page: d.page, index: d.index, source: 'image', preview: preview(d.board) })),
    };
  }

  const { cells, composed, unseen } = await readInWorker(
    calibrationBoards.map(({ board, fen, ignore }) => ({ board, fen, ignore })),
    toRead.map((d) => d.board),
  );
  const positions = toRead.map((d, k) => {
    const placement = placementOf(cells[k].map((c) => c.piece));
    return {
      page: d.page,
      index: d.index,
      source: 'image',
      placement,
      uncertain: cells[k].flatMap((c, i) => (c.unsure ? [squareName(i)] : [])),
      legal: legal(placement),
      preview: preview(d.board),
    };
  });
  const marks = positions.reduce((n, p) => n + p.uncertain.length, 0);
  return {
    ...base,
    needsCalibration: false,
    calibration: calibrationBoards
      .filter((c) => c.page >= start && c.page <= end)
      .map((c) => ({
        page: c.page, index: c.index, source: 'image', placement: c.fen, calibration: true,
        uncertain: [], legal: legal(c.fen), preview: preview(c.board),
      })),
    positions,
    composed,
    unseen,
    marksPerBoard: positions.length ? marks / positions.length : 0,
  };
}
