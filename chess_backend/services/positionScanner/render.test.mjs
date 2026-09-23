// Pages drawn by the server for a book no glyph map reads — phase 3h of
// docs/PLAN-SKENER-SLIKE.md. Every book here is drawn in the test
// (test/support/drawnBooks.mjs): a board made of PDF operators, with no font
// and no picture, is what such a book's diagram is once its page is drawn.
import test from 'node:test';
import assert from 'node:assert/strict';
import { writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { findImageDiagrams } from './imageDiagrams.mjs';
import { renderedBoards } from './render.mjs';
import { bookKind } from './bookKind.mjs';
import { ScanError } from './index.mjs';
import { createCanvas, canvasGray, tempPdf, vectorBoard } from '../../test/support/drawnBooks.mjs';

// A 300 x 300 pt page with one 200 pt board, its top-left corner at (50, 60).
const PAGE = 300;
const boardPage = (extra = {}) => ({ size: [PAGE, PAGE], images: [], content: vectorBoard(50, 60, 200, PAGE), ...extra });

// A picture that is neither a diagram nor a page: a strip, like a publisher's
// ornament. Drawing any picture makes pdfjs reach for a scratch canvas.
function strip() {
  const canvas = createCanvas(120, 30);
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#fff';
  ctx.fillRect(0, 0, 120, 30);
  ctx.fillStyle = '#000';
  ctx.fillRect(10, 10, 100, 10);
  return canvasGray(canvas);
}

async function script(t, body) {
  const file = join(tmpdir(), `render-worker-${process.pid}-${Math.random().toString(36).slice(2)}.mjs`);
  await writeFile(file, body);
  t.after(() => rm(file, { force: true }));
  return file;
}

test('a board drawn as lines, with no font and no picture, is found on the drawn page', async (t) => {
  const file = await tempPdf(t, [boardPage()]);
  const found = await findImageDiagrams(file, { fromPage: 1, toPage: 1 });
  assert.equal(found.diagrams.length, 1);
  const [d] = found.diagrams;
  assert.equal(d.source, 'render');
  assert.equal(d.page, 1);
  assert.equal(d.index, 1);
  assert.equal(d.board.length, 512 * 512);
  // The box is in the drawn page's pixels, 300 dpi: 50 pt is 208 px.
  const px = (pt) => (pt * 300) / 72;
  assert.ok(Math.abs(d.box.left - px(50)) <= 4, `left ${d.box.left}`);
  assert.ok(Math.abs(d.box.top - px(60)) <= 4, `top ${d.box.top}`);
  assert.ok(Math.abs(d.box.right - d.box.left - px(200)) <= 6, `width ${d.box.right - d.box.left}`);
  assert.equal(found.rendered, 1);
});

test('a page with a picture beside the board is drawn without taking the process down', async (t) => {
  const file = await tempPdf(t, [boardPage({ images: [{ picture: strip(), storage: 'gray8', rect: [60, 10, 120, 30] }] })]);
  const found = await findImageDiagrams(file, { fromPage: 1, toPage: 1 });
  assert.deepEqual(found.diagrams.map((d) => d.source), ['render']);
});

test('a page whose font is drawn glyph by glyph is drawn, its board found', async (t) => {
  // A glyph is a path, and pdfjs makes it with whatever `Path2D` it finds;
  // one from the other copy of the canvas library is refused by ours.
  const file = await tempPdf(t, [boardPage({ text: [{ x: 50, top: 30, size: 14, str: 'Diagram 1' }] })]);
  const found = await findImageDiagrams(file, { fromPage: 1, toPage: 1 });
  assert.deepEqual(found.diagrams.map((d) => d.source), ['render']);
});

test('a book whose pictures give a board is not drawn', async (t) => {
  const { diagramImage } = await import('../../test/support/drawnBooks.mjs');
  const file = await tempPdf(t, [
    { size: [PAGE, PAGE], images: [{ picture: diagramImage(), storage: 'gray8', rect: [30, 40, 240, 215] }] },
    boardPage(),
  ]);
  const asked = [];
  const found = await findImageDiagrams(file, {
    fromPage: 1, toPage: 2, render: async (f, pages) => { asked.push(pages); return []; },
  });
  assert.deepEqual(asked, []);
  assert.deepEqual(found.diagrams.map((d) => d.source), ['image']);
});

test('a scanned page is not drawn again; the other pages are', async (t) => {
  const { scannedPage } = await import('../../test/support/drawnBooks.mjs');
  const empty = scannedPage();
  empty.gray.fill(255);
  const file = await tempPdf(t, [
    { size: [PAGE, PAGE], images: [{ picture: empty, storage: 'gray8', rect: [0, 0, PAGE, PAGE] }] },
    boardPage(),
  ]);
  const asked = [];
  await findImageDiagrams(file, {
    fromPage: 1, toPage: 2, render: async (f, pages) => { asked.push(pages); return []; },
  });
  assert.deepEqual(asked, [[2]]);
});

test('a drawing that fails is a refusal, not "no boards"', async (t) => {
  const file = await tempPdf(t, [boardPage()]);
  const failing = async () => { throw new Error('the process was ended by SIGSEGV'); };
  await assert.rejects(
    findImageDiagrams(file, { fromPage: 1, toPage: 1, render: failing }),
    (err) => err instanceof ScanError && err.code === 'render_failed' && /SIGSEGV/.test(err.cause.message),
  );
});

test('a drawing process that dies is reported, with how it died', async (t) => {
  const worker = await script(t, "process.once('message', () => process.exit(3));\n");
  await assert.rejects(renderedBoards('unused.pdf', [1], { worker }), /exited with 3/);
});

test('a drawing process that never answers is ended at its deadline', async (t) => {
  const worker = await script(t, "process.once('message', () => setInterval(() => {}, 1000));\n");
  // The case's own deadline, so that a call which never ends fails here and
  // says so, rather than waiting for the runner's.
  const own = new Promise((_, reject) => setTimeout(() => reject(new Error('the call did not end within 8 s')), 8000).unref());
  await assert.rejects(
    Promise.race([renderedBoards('unused.pdf', [1], { worker, deadline: 1500 }), own]),
    /no answer within 1500 ms/,
  );
});

test('a book of drawn boards is a picture book to the kind check', async (t) => {
  const file = await tempPdf(t, [boardPage(), boardPage()]);
  const kind = await bookKind(file);
  assert.equal(kind.kind, 'pictures');
  assert.equal(kind.imageDiagrams, 2);
});
