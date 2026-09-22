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
/** Boards suggested for calibrating when none is given. */
export const SUGGESTED = 3;

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

/** A board as a PNG, 256 px, for the trainer to look at beside what was read. */
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
  return canvas.toBuffer('image/png').toString('base64');
}

/**
 * How many squares of a board hold something: the middle of a square whose
 * share of ink differs from the other squares of its colour. The boards worth
 * calibrating show the most pieces.
 */
export function busy(board) {
  const ink = [];
  for (let i = 0; i < 64; i++) {
    const r = (i / 8) | 0;
    const c = i % 8;
    let n = 0;
    for (let y = r * 64 + 12; y < r * 64 + 52; y++) {
      for (let x = c * 64 + 12; x < c * 64 + 52; x++) if (board[y * 512 + x] < 100) n++;
    }
    ink.push(n / 1600);
  }
  const median = (xs) => [...xs].sort((a, b) => a - b)[xs.length >> 1];
  const light = median(ink.filter((_, i) => (((i / 8) | 0) + (i % 8)) % 2 === 0));
  const dark = median(ink.filter((_, i) => (((i / 8) | 0) + (i % 8)) % 2 === 1));
  return ink.filter((v, i) => Math.abs(v - ((((i / 8) | 0) + (i % 8)) % 2 ? dark : light)) > 0.08).length;
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
 * the pages, with a preview each and the ones suggested for calibrating. With
 * one: every other board read, `source: 'image'`, its uncertain squares named.
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
  if ((calibration.length ? toRead.length : inRange.length) > MAX_IMAGE_BOARDS) {
    throw new ScanError(
      `Those pages hold ${inRange.length} diagrams; at most ${MAX_IMAGE_BOARDS} are read at a time. Choose fewer pages.`,
      { code: 'too_many_boards', details: { boards: inRange.length, max: MAX_IMAGE_BOARDS } },
    );
  }

  const base = { pageCount, scannedFrom: start, scannedTo: end, refused: found.refused };

  if (!calibration.length) {
    const suggested = [...inRange]
      .map((d) => ({ d, n: busy(d.board) }))
      .sort((a, b) => b.n - a.n || a.d.page - b.d.page || a.d.index - b.d.index)
      .slice(0, SUGGESTED)
      .map(({ d }) => ({ page: d.page, index: d.index }));
    return {
      ...base,
      needsCalibration: true,
      boards: inRange.map((d) => ({ page: d.page, index: d.index, source: 'image', preview: preview(d.board) })),
      suggested,
    };
  }

  const { cells, composed } = await readInWorker(
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
      .map((c) => ({ page: c.page, index: c.index, source: 'image', placement: c.fen, calibration: true, preview: preview(c.board) })),
    positions,
    composed,
    marksPerBoard: positions.length ? marks / positions.length : 0,
  };
}
