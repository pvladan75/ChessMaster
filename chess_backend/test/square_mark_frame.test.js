// square_mark_frame.test.js — a trainer's marked square, drawn the same way in
// the app and in the film.
//
// Phase 3 of `docs/PLAN-OZNAKE-NA-TABLI.md`. Until 12.9.2026 both ends drew a
// ring; on that day both became a thin frame on the square's own edge, because
// the owner asked for one — „ne želim krugove oko figura ili u poljima".
//
// **The point of this file is that the two ends are compared with each other**,
// not each with a comment claiming they agree. CLAUDE.md already records a
// motif table kept by hand in two places whose sentences drifted apart, and a
// „neither Google nor Azure has a Serbian voice" repeated in three files that
// had only ever been checked against one list. A tutorial that looks one way on
// a trainer's screen and another way in the film a child is sent is the same
// fault wearing a picture.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createCanvas, loadImage } = require('@napi-rs/canvas');

const renderer = require('../videoRenderer');
const {
  renderFrameBuffer,
  getResolutionParams,
  SQUARE_MARK_FRACTIONS,
  LAST_MOVE_WASH,
} = renderer;

/// The app's copy of the same constants, read out of the Dart source.
///
/// Reading source as text, which this repository has been bitten by four times
/// — so it matches one named constant at a time and **asserts it found each
/// one**, rather than scanning a region and trusting the shape of it. A rename
/// on the app's side fails this file loudly instead of silently checking
/// nothing.
function appConstants() {
  const file = path.join(
    __dirname, '..', '..', 'chess_app', 'lib', 'widgets',
    'board_overlay_painter.dart');
  const source = fs.readFileSync(file, 'utf8');

  const number = (name) => {
    const hit = source.match(
      new RegExp(`static const double ${name}\\s*=\\s*([0-9.]+)\\s*;`));
    assert.ok(hit, `${name} is not a plain number in ${path.basename(file)} — `
      + 'it was renamed, or computed from another constant, and this test is '
      + 'no longer comparing the two ends');
    return Number(hit[1]);
  };

  const wash = source.match(
    /static const ui\.Color wash = ui\.Color\(0x([0-9A-Fa-f]{8})\)/);

  return {
    core: number('squareMarkCoreFraction'),
    light: number('squareMarkLightFraction'),
    shade: number('squareMarkShadeFraction'),
    washArgb: wash ? wash[1] : null,
  };
}

/// The same constant, which lives in the board widget rather than the painter.
function appWash() {
  const file = path.join(
    __dirname, '..', '..', 'chess_app', 'lib', 'widgets', 'board',
    'skinned_chess_board.dart');
  const source = fs.readFileSync(file, 'utf8');
  const hit = source.match(
    /static const ui\.Color wash = ui\.Color\(0x([0-9A-Fa-f]{8})\)/);
  assert.ok(hit, 'LastMovePainter.wash is not a plain colour literal any more');
  const argb = hit[1];
  return {
    alpha: parseInt(argb.slice(0, 2), 16),
    r: parseInt(argb.slice(2, 4), 16),
    g: parseInt(argb.slice(4, 6), 16),
    b: parseInt(argb.slice(6, 8), 16),
  };
}

test('the frame widths are the app\'s own numbers, not a copy that drifted',
  () => {
    const app = appConstants();
    assert.equal(SQUARE_MARK_FRACTIONS.core, app.core);
    assert.equal(SQUARE_MARK_FRACTIONS.light, app.light);
    assert.equal(SQUARE_MARK_FRACTIONS.shade, app.shade);
  });

test('the last-move wash is the app\'s own colour', () => {
  const app = appWash();
  assert.equal(app.r, 0, 'the app\'s wash gained a hue');
  assert.equal(app.g, 0);
  assert.equal(app.b, 0);

  const film = LAST_MOVE_WASH.match(
    /^rgba\((\d+),\s*(\d+),\s*(\d+),\s*([0-9.]+)\)$/);
  assert.ok(film, `the film's wash is not an rgba(): ${LAST_MOVE_WASH}`);
  assert.equal(Number(film[1]), app.r);
  assert.equal(Number(film[2]), app.g);
  assert.equal(Number(film[3]), app.b);

  // 0x38 is 56, and 56/255 is 0.2196…, which the film writes as 0.22. Within
  // one step of 1/255, which is the finest either end can actually draw.
  const appAlpha = app.alpha / 255;
  assert.ok(Math.abs(Number(film[4]) - appAlpha) < 1 / 255,
    `the film paints the wash at ${film[4]} and the app at `
    + `${appAlpha.toFixed(4)}`);
});

/// One rendered frame, as something a test can ask about a pixel.
async function pixels(options) {
  const buf = await renderFrameBuffer(options);
  const img = await loadImage(buf);
  const canvas = createCanvas(img.width, img.height);
  const ctx = canvas.getContext('2d');
  ctx.drawImage(img, 0, 0);
  return {
    at(x, y) {
      const d = ctx.getImageData(Math.round(x), Math.round(y), 1, 1).data;
      return { r: d[0], g: d[1], b: d[2] };
    },
  };
}

function geometry(resolution = '720p') {
  const cfg = getResolutionParams(resolution);
  const margin = Math.round(cfg.offsetY * 0.6);
  const boardSize = Math.min(cfg.boardSize, cfg.height - cfg.offsetY - margin);
  return {
    offsetX: (cfg.width - boardSize) / 2,
    offsetY: cfg.offsetY,
    tile: boardSize / 8,
  };
}

function topLeftOf(square, geom) {
  const col = square.charCodeAt(0) - 97;
  const row = 8 - parseInt(square[1], 10);
  return { x: geom.offsetX + col * geom.tile, y: geom.offsetY + row * geom.tile };
}

// An empty board on purpose. The file-letter test in `video_renderer.test.js`
// was answered by the pieces standing on rank one before it was fixed, and a
// mark drawn on a square with a piece on it has the same hole: the question
// „is there ink here that is not the square's colour" is answered by a rook.
const EMPTY = '8/8/8/8/8/8/8/8 w - - 0 1';

test('a marked square is framed at its edge and empty in the middle',
  async () => {
    const geom = geometry();
    const at = topLeftOf('d5', geom);
    const frame = await pixels({
      fen: EMPTY,
      squares: [{ square: 'd5', color: 'G' }],
      showCoords: false,
      showMoveText: false,
    });
    const plain = await pixels({
      fen: EMPTY,
      squares: [],
      showCoords: false,
      showMoveText: false,
    });

    const middle = { x: at.x + geom.tile / 2, y: at.y + geom.tile / 2 };
    assert.deepEqual(frame.at(middle.x, middle.y), plain.at(middle.x, middle.y),
      'the middle of the square was painted — this is a frame precisely so the '
      + 'piece standing there stays readable');

    // Two pixels in from the top edge, on the square's own centre line: inside
    // the colour band, which is the outermost of the three.
    const onBand = { x: middle.x, y: at.y + geom.tile * 0.02 };
    assert.notDeepEqual(frame.at(onBand.x, onBand.y),
      plain.at(onBand.x, onBand.y),
      'nothing was drawn on the square\'s edge');

    // And the square next door is untouched, which is what the inset is for.
    const next = topLeftOf('d4', geom);
    const inNext = { x: next.x + geom.tile / 2, y: next.y + geom.tile * 0.02 };
    assert.deepEqual(frame.at(inNext.x, inNext.y), plain.at(inNext.x, inNext.y),
      'the frame bled onto the square below');
  });

test('the frame is not a circle: the corners of the square carry it too',
  async () => {
    // The one assertion a ring cannot pass. A ring is inscribed, so a pixel
    // just inside a corner is board; a frame runs along both edges and meets
    // there.
    const geom = geometry();
    const at = topLeftOf('d5', geom);
    const frame = await pixels({
      fen: EMPTY,
      squares: [{ square: 'd5', color: 'G' }],
      showCoords: false,
      showMoveText: false,
    });
    const plain = await pixels({
      fen: EMPTY,
      squares: [],
      showCoords: false,
      showMoveText: false,
    });

    const corner = { x: at.x + geom.tile * 0.02, y: at.y + geom.tile * 0.02 };
    assert.notDeepEqual(frame.at(corner.x, corner.y),
      plain.at(corner.x, corner.y),
      'the corner of the marked square is untouched, so what is drawn there is '
      + 'still a ring rather than a frame');
  });
