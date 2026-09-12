// video_renderer.test.js — what a frame of a tutorial video actually shows.
//
// Phase 2 of `docs/PLAN-ZAVRSNICA.md`. The renderer draws PNGs and pipes them
// into ffmpeg, so until now nothing here could be tested at all and nothing was
// — the whole file was written, shipped and verified live by watching a video.
// Two faults had been in every export ever rendered and were found by **looking
// at one frame**: a tofu box where a pawn glyph was meant to be, and eight file
// letters painted in the colour of the square they stand on.
//
// So these tests read pixels. `renderFrameBuffer` returns a PNG buffer, and
// `loadImage` puts it back on a canvas where `getImageData` can be asked what
// colour a square, an arrow or the board's own edge came out. A drawing that
// cannot be measured is a drawing nobody can grade, and this feature is about
// to be handed to a batch.
const test = require('node:test');
const assert = require('node:assert/strict');
const { createCanvas, loadImage } = require('@napi-rs/canvas');

const renderer = require('../videoRenderer');
const {
  renderFrameBuffer,
  captionLines,
  revealedLines,
  captionBandLines,
  drawColorOf,
  getResolutionParams,
  lookOf,
  recolouredPieces,
  tenPercentReporter,
  applyEvent,
  initialFrameState,
  ffmpegArgsFor,
  OUTPUT_FPS,
} = renderer;

const FEN = 'r1bqkb1r/pp2pppp/2n2n2/3p4/3P4/2N2NP1/PP2PPBP/R1BQK2R w KQkq - 0 7';

/// One rendered frame, as something a test can ask about a pixel.
async function pixels(options) {
  const buf = await renderFrameBuffer(options);
  const img = await loadImage(buf);
  const canvas = createCanvas(img.width, img.height);
  const ctx = canvas.getContext('2d');
  ctx.drawImage(img, 0, 0);
  return {
    width: img.width,
    height: img.height,
    at(x, y) {
      const d = ctx.getImageData(Math.round(x), Math.round(y), 1, 1).data;
      return { r: d[0], g: d[1], b: d[2] };
    },
  };
}

function hexToRgb(hex) {
  return {
    r: parseInt(hex.slice(1, 3), 16),
    g: parseInt(hex.slice(3, 5), 16),
    b: parseInt(hex.slice(5, 7), 16),
  };
}

function distance(a, b) {
  return Math.hypot(a.r - b.r, a.g - b.g, a.b - b.b);
}

/// Geometry the tests re-derive rather than import: if the renderer moves the
/// board, these probes must fail rather than follow it.
///
/// Two layouts since 9.9.2026. A film that says nothing keeps the centred board
/// this renderer has always drawn — the recorded-lesson export is verified live.
/// A film with a caption anywhere puts the board on the left and the sentence in
/// a column of its own, which is four times the room the old strip under the
/// board had, and means a longer sentence cannot move the board.
function boardGeometry(frame, { resolution = '720p', captionBand = 0, flipped = false } = {}) {
  const cfg = getResolutionParams(resolution);
  const captionColumn = captionBand > 0;
  const margin = Math.round(cfg.offsetY * 0.6);
  const boardSize = Math.min(cfg.boardSize, cfg.height - cfg.offsetY - margin);
  const offsetX = captionColumn ? margin : (cfg.width - boardSize) / 2;
  const captionLeft = offsetX + boardSize + margin;
  return {
    offsetX,
    offsetY: cfg.offsetY,
    tileSize: boardSize / 8,
    boardSize,
    captionColumn,
    captionLeft,
    captionWidth: Math.max(0, cfg.width - captionLeft - margin),
    flipped,
    cfg,
  };
}

/// A point on the colour band of a marked square — the outermost of the three
/// strokes a `[%csl]` frame is drawn with.
///
/// The three probes that used to live at the call sites each carried a copy of
/// the ring's radius formula, and when the ring became a frame on 12.9.2026 all
/// three went red together pointing at a number that no longer existed
/// anywhere. One helper now, on the mid-point of the square's top edge: inside
/// the colour band, and far from the corners where three strokes meet.
function onMarkBand(square, geom) {
  const col = square.charCodeAt(0) - 97;
  const row = 8 - parseInt(square[1], 10);
  const c = geom.flipped ? 7 - col : col;
  const r = geom.flipped ? 7 - row : row;
  const band = geom.tileSize * renderer.SQUARE_MARK_FRACTIONS.core;
  return {
    x: geom.offsetX + (c + 0.5) * geom.tileSize,
    y: geom.offsetY + r * geom.tileSize + band / 2,
  };
}

function centreOf(square, geom) {
  const col = square.charCodeAt(0) - 97;
  const row = 8 - parseInt(square[1], 10);
  const c = geom.flipped ? 7 - col : col;
  const r = geom.flipped ? 7 - row : row;
  return {
    x: geom.offsetX + (c + 0.5) * geom.tileSize,
    y: geom.offsetY + (r + 0.5) * geom.tileSize,
  };
}

const BASE = {
  title: 'Test',
  fen: FEN,
  timestampSec: 4,
  totalDurationSec: 60,
  resolution: '720p',
  showMoveText: false,
};

test('a coloured square is drawn on the square it names', async () => {
  const geom = boardGeometry(null, {});
  const frame = await pixels({ ...BASE, squares: [{ square: 'd5', color: 'R' }] });

  // The probe is on the frame's own band rather than in the middle of the
  // square — where the piece standing there is, which is the reason this is a
  // frame and not a filled square.
  const on = onMarkBand('d5', geom);
  const drawn = frame.at(on.x, on.y);

  assert.ok(distance(drawn, hexToRgb('#FF2929')) < 60,
    `d5's frame should be red, got ${JSON.stringify(drawn)}`);
});

test('the same square is drawn on the other side of a flipped board', async () => {
  const geom = boardGeometry(null, { flipped: true });
  const frame = await pixels({
    ...BASE,
    orientation: 'black',
    squares: [{ square: 'd5', color: 'R' }],
  });

  const on = onMarkBand('d5', geom);
  assert.ok(distance(frame.at(on.x, on.y), hexToRgb('#FF2929')) < 60,
    'the frame follows the board round');

  // And nothing is drawn where an unflipped board would have put it.
  const unflipped = onMarkBand('d5', boardGeometry(null, {}));
  assert.ok(
    distance(frame.at(unflipped.x, unflipped.y), hexToRgb('#FF2929')) > 100,
    'an ignored orientation would leave the mark on the mirrored square');
});

test('an arrow is drawn between the two squares it joins', async () => {
  const geom = boardGeometry(null, {});
  const plain = await pixels({ ...BASE });
  const drawn = await pixels({ ...BASE, arrows: [{ from: 'c3', to: 'd5', color: 'B' }] });

  const a = centreOf('c3', geom);
  const b = centreOf('d5', geom);
  const mid = { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 };

  const before = plain.at(mid.x, mid.y);
  const after = drawn.at(mid.x, mid.y);
  assert.ok(distance(before, after) > 40, 'the shaft crosses the midpoint');
  assert.ok(distance(after, hexToRgb('#00188F')) < distance(after, before),
    'and it is the blue it was asked for');
});

test('an unknown colour code is drawn grey, never as one of the five', async () => {
  // The fallback means "this build does not know what you meant". Green means
  // something specific in this vocabulary, so a fallback that returned green
  // would be a statement rather than a default.
  assert.equal(drawColorOf('X'), '#9E9E9E');
  assert.equal(drawColorOf(null), '#9E9E9E');
  assert.equal(drawColorOf('g'), '#85FF85', 'a lowercase code is the same code');

  const geom = boardGeometry(null, {});
  const frame = await pixels({ ...BASE, squares: [{ square: 'e5', color: 'X' }] });
  const on = onMarkBand('e5', geom);
  assert.ok(distance(frame.at(on.x, on.y), hexToRgb('#9E9E9E')) < 60,
    'grey, and not a colour with a meaning');
});

test('a square that is not a square is ignored rather than drawn somewhere', async () => {
  const frame = await pixels({
    ...BASE,
    squares: [{ square: 'z9', color: 'R' }, { square: '', color: 'R' }],
    arrows: [{ from: 'c3', to: 'zz', color: 'R' }],
  });
  const plain = await pixels({ ...BASE });
  let worst = 0;
  for (let x = 0; x < frame.width; x += 7) {
    for (let y = 0; y < frame.height; y += 7) {
      worst = Math.max(worst, distance(frame.at(x, y), plain.at(x, y)));
    }
  }
  assert.ok(worst < 12, 'nothing was drawn anywhere for a square that does not exist');
});

test('the board is in the same place whatever this beat says', async () => {
  // The reason the caption moved beside the board rather than under it: the
  // column is a fixed width and the text is centred inside it, so a long
  // sentence and a silent beat draw the board in exactly the same place. Under
  // the board, the height it needed had to be measured once for the whole film
  // or the board grew and shrank between two sentences.
  const geom = boardGeometry(null, { captionBand: 1 });
  const long = await pixels({
    ...BASE,
    captionBand: 1,
    caption: 'A sentence long enough to need several whole lines of the column '
      + 'beside the board, which is what the column is for.',
  });
  const silent = await pixels({ ...BASE, captionBand: 1, caption: '' });

  const probe = { x: geom.offsetX + 4, y: geom.offsetY + geom.boardSize - 4 };
  assert.deepEqual(silent.at(probe.x, probe.y), long.at(probe.x, probe.y),
    'the same pixel is board on both');
  const below = { x: geom.offsetX + 4, y: geom.offsetY + geom.boardSize + 8 };
  assert.deepEqual(silent.at(below.x, below.y), long.at(below.x, below.y),
    'and background on both');
});

test('the caption is drawn beside the board, never under it', async () => {
  // What the owner asked for, and the reason: under the board the text pushed
  // everything below it around as it grew. Beside it, the board is untouched.
  const geom = boardGeometry(null, { captionBand: 1 });
  const frame = await pixels({
    ...BASE,
    captionBand: 1,
    caption: 'Look at the d5 square, because both white pieces are aiming at it.',
  });
  const bg = frame.at(4, 4);

  assert.ok(geom.captionLeft > geom.offsetX + geom.boardSize,
    'the column starts to the right of the board');
  assert.ok(geom.captionWidth > geom.cfg.fontSizeCaption * 6,
    'and is wide enough to hold a sentence');

  // **Where the board actually is**, read off the picture. Without this, a
  // renderer that kept the board centred passed everything below: the column's
  // pixels would then be the board's own, and „there is ink beside the board"
  // is satisfied by the board. A mutation found exactly that.
  const row = Math.round(geom.offsetY + 10);
  let boardLeft = null;
  for (let x = 0; x < frame.width; x++) {
    if (distance(frame.at(x, row), bg) > 20) { boardLeft = x; break; }
  }
  assert.ok(Math.abs(boardLeft - geom.offsetX) <= 2,
    `the board starts at the margin, not centred; found ${boardLeft} wanted ${geom.offsetX}`);

  let inkBeside = 0;
  for (let x = Math.round(geom.captionLeft); x < geom.captionLeft + geom.captionWidth; x += 2) {
    for (let y = geom.offsetY; y < geom.offsetY + geom.boardSize; y += 2) {
      if (distance(frame.at(x, y), bg) > 40) inkBeside += 1;
    }
  }
  assert.ok(inkBeside > 100, 'the sentence is in the column');

  let inkBelow = 0;
  for (let x = Math.round(geom.offsetX); x < geom.offsetX + geom.boardSize; x += 2) {
    for (let y = Math.round(geom.offsetY + geom.boardSize + 6); y < frame.height; y += 2) {
      if (distance(frame.at(x, y), bg) > 40) inkBelow += 1;
    }
  }
  assert.equal(inkBelow, 0, 'and nothing at all is written under the board');
});

test('a film with no caption anywhere keeps the geometry it always had', async () => {
  // The recorded-lesson export is verified live and this phase must not move it
  // by a pixel: no caption in any event means the centred board, full size.
  const cfg = getResolutionParams('720p');
  assert.equal(captionBandLines([
    { eventType: 'init', data: { fen: FEN } },
    { eventType: 'move', data: { fen: FEN, from: 'c3', to: 'd5', san: 'Nd5' } },
  ]), 0);

  const geom = boardGeometry(null, {});
  assert.equal(geom.captionColumn, false);
  assert.equal(geom.boardSize, cfg.boardSize);
  assert.equal(geom.offsetX, (cfg.width - cfg.boardSize) / 2, 'centred, as it always was');

  const frame = await pixels({ ...BASE, captionBand: 0 });
  const bg = frame.at(4, 4);
  // Symmetric: the same distance of background either side of the board.
  const row = Math.round(geom.offsetY + 10);
  let left = null;
  let right = null;
  for (let x = 0; x < frame.width; x++) {
    if (distance(frame.at(x, row), bg) > 20) {
      if (left === null) left = x;
      right = x;
    }
  }
  assert.ok(Math.abs(left - (frame.width - 1 - right)) <= 2, 'the board is centred');
  assert.ok(Math.abs((right - left + 1) - cfg.boardSize) <= 2, 'and full size');
});

test('the file letters are readable, which they were not for a year', async () => {
  // Painted in the colour of the square they stand on, eight times over: the
  // parity that is right for the ranks is inverted for the files, and the same
  // expression served both. Nothing could see it but a pixel.
  //
  // **The first version of this test could not see it either.** It asked
  // whether anything in the bottom strip differed from the square above, and
  // the pieces standing on rank one answered yes on their own — so putting the
  // old parity back left it green. The board is empty here for that reason, and
  // the question is asked per file: is there ink on this square that is not the
  // colour of this square?
  const geom = boardGeometry(null, {});
  const frame = await pixels({ ...BASE, fen: '8/8/8/8/8/8/8/8 w - - 0 1', showCoords: true });
  const board = { light: { r: 0xF0, g: 0xD9, b: 0xB5 }, dark: { r: 0xB5, g: 0x88, b: 0x63 } };

  const bottom = geom.offsetY + geom.boardSize;
  const unreadable = [];
  for (let file = 0; file < 8; file++) {
    // Bottom row is rank 1, drawn at row 7: light when the column is odd.
    const squareColour = file % 2 === 1 ? board.light : board.dark;
    const right = geom.offsetX + (file + 1) * geom.tileSize;
    let ink = 0;
    for (let x = Math.round(right - 18); x < Math.round(right - 2); x++) {
      for (let y = Math.round(bottom - 20); y < Math.round(bottom - 2); y++) {
        if (distance(frame.at(x, y), squareColour) > 30) ink++;
      }
    }
    if (ink < 8) unreadable.push(String.fromCharCode(97 + file));
  }
  assert.deepEqual(unreadable, [],
    'every file letter is drawn in a colour that is not its own square');
});

test('the rank numbers are readable, which they stopped being when the files were fixed', async () => {
  // The other half of the same two lines. Fixing the file letters on 9.9.2026
  // set `fillStyle` for the files and left the ranks reading it - so from that
  // day the numbers were the invisible ones, painted in the colour of their own
  // square eight times over. Reported on 11.9.2026 off a still of a film.
  //
  // Written as the file test's twin on purpose: same empty board, same
  // question per label, opposite parity. Neither line owns a parity any more -
  // both ask the board's own expression - so this pair cannot be half-fixed
  // again.
  const geom = boardGeometry(null, {});
  const frame = await pixels({ ...BASE, fen: '8/8/8/8/8/8/8/8 w - - 0 1', showCoords: true });
  const board = { light: { r: 0xF0, g: 0xD9, b: 0xB5 }, dark: { r: 0xB5, g: 0x88, b: 0x63 } };

  const unreadable = [];
  for (let row = 0; row < 8; row++) {
    // Left column, drawn at column 0: light when the row is even.
    const squareColour = row % 2 === 0 ? board.light : board.dark;
    const top = geom.offsetY + row * geom.tileSize;
    let ink = 0;
    for (let x = Math.round(geom.offsetX + 2); x < Math.round(geom.offsetX + 20); x++) {
      for (let y = Math.round(top + 2); y < Math.round(top + 22); y++) {
        if (distance(frame.at(x, y), squareColour) > 30) ink++;
      }
    }
    if (ink < 8) unreadable.push(8 - row);
  }
  assert.deepEqual(unreadable, [],
    'every rank number is drawn in a colour that is not its own square');
});

test('the file says 30 frames a second, whatever we drew', () => {
  // Two different rates, and the whole point is that they differ: one drawing
  // per second of film, a file that claims 30. A 1 fps file scrubs badly in
  // players and some upload pipelines refuse it, and ffmpeg fills the gap by
  // repeating a frame it has already encoded — half a second and 62 KB on a
  // nineteen-second film, measured.
  const silent = ffmpegArgsFor({ outputPath: 'out.mp4' });
  const spoken = ffmpegArgsFor({ audioFilePath: 'voice.m4a', outputPath: 'out.mp4' });

  for (const args of [silent, spoken]) {
    assert.equal(args[args.indexOf('-framerate') + 1], '1',
      'the pictures still arrive once a second');
    assert.equal(args[args.indexOf('-r') + 1], String(OUTPUT_FPS));

    // **After both inputs**, which is what makes it an output option. Written
    // one input earlier it becomes an input option for the audio and silently
    // does nothing — which is exactly what the first attempt did, producing a
    // byte-identical 1 fps file that looked like a working change.
    const lastInput = args.lastIndexOf('-i');
    assert.ok(args.indexOf('-r') > lastInput,
      '-r must come after every -i or it is not an output option');
    assert.ok(args.indexOf('-r') < args.indexOf('-c:v'),
      'and before the encoder it applies to');
    assert.equal(args[args.length - 1], 'out.mp4', 'the output path stays last');
  }
});

test('the audio input replaces the silent one rather than joining it', () => {
  // `-shortest` with two audio inputs is a film as long as the shorter of them,
  // and a silent track is exactly as long as the video. A voice-over that ran
  // past the last beat would be cut; one that stopped early would end the film.
  const spoken = ffmpegArgsFor({ audioFilePath: 'voice.m4a', outputPath: 'out.mp4' });
  assert.ok(!spoken.includes('anullsrc=r=44100:cl=stereo'), 'no silent track beside the voice');
  assert.equal(spoken.filter((a) => a === '-i').length, 2, 'the frames and the voice, nothing else');
  assert.ok(spoken.includes('-shortest'));
});

test('the sentence is written as it is spoken, whole words at a time', () => {
  const lines = ['Look at the d5 square, because both', 'white pieces are aiming at it.'];

  assert.deepEqual(revealedLines(lines, 0), ['', ''], 'nothing before the voice starts');
  assert.deepEqual(revealedLines(lines, 1), lines, 'all of it by the time it ends');
  assert.deepEqual(revealedLines(lines, 2), lines, 'and never more than all of it');
  assert.deepEqual(revealedLines(lines, -1), ['', '']);
  assert.deepEqual(revealedLines(lines, NaN), lines, 'a film with no voice writes it at once');

  // **Whole words.** Cutting mid-word writes „the knig" for a quarter of a
  // second, which reads as a glitch rather than as typing.
  for (let i = 0; i <= 20; i++) {
    for (const line of revealedLines(lines, i / 20)) {
      if (!line) continue;
      const whole = lines.find((l) => l.startsWith(line));
      assert.ok(whole, `„${line}" is not the start of any line`);
      const next = whole[line.length];
      assert.ok(next === undefined || next === ' ',
        `„${line}" stops inside a word`);
    }
  }
});

test('the writing runs at one speed from the first word to the last', () => {
  // Measured across the whole sentence rather than per line: per line, a short
  // first line and a long second would be written at two different speeds and
  // the reader would see it pause at the break.
  const lines = ['Short.', 'A very much longer second line of the same sentence.'];
  const at = (f) => revealedLines(lines, f).join(' ').trim().length;
  assert.ok(at(0.25) < at(0.5) && at(0.5) < at(0.75), 'it only ever grows');
  const early = at(0.5) - at(0.25);
  const late = at(0.75) - at(0.5);
  assert.ok(Math.abs(early - late) < lines.join('').length * 0.25,
    `the two halves are written at about the same speed: ${early} then ${late}`);
});

test("the film takes the app's own colours when it is given them", async () => {
  // The app has five board skins, three piece skins and a light and a dark
  // theme, and the renderer had heard of none of them: it took a name like
  // „wood" and kept its own idea of what wood is. Colours travel now, so the
  // film is the screen the tutorial was written on.
  const light = {
    lightSquare: '#E9EDCC',
    darkSquare: '#779556',
    background: '#F7F8FA',
    text: '#101418',
    accent: '#0F766E',
  };
  // An empty board, so a probe lands on a square rather than on the rook
  // standing on it — the first version of this sampled the middle of a8.
  const frame = await pixels({
    ...BASE,
    fen: '8/8/8/8/8/8/8/8 w - - 0 1',
    captionBand: 1,
    caption: 'Beside.',
    look: light,
  });

  assert.ok(distance(frame.at(4, 4), hexToRgb('#F7F8FA')) < 12,
    "the background is the app theme, not this renderer's dark blue");

  const geom = boardGeometry(null, { captionBand: 1 });
  // A light square and a dark one, read off the board rather than computed.
  // a8 is the light one, and a8 is where the board starts drawing.
  const lightAt = frame.at(geom.offsetX + geom.tileSize * 0.5, geom.offsetY + geom.tileSize * 0.5);
  const darkAt = frame.at(geom.offsetX + geom.tileSize * 1.5, geom.offsetY + geom.tileSize * 0.5);
  assert.ok(distance(lightAt, hexToRgb('#E9EDCC')) < 20, "the light squares are the skin's");
  assert.ok(distance(darkAt, hexToRgb('#779556')) < 20, 'and so are the dark ones');
});

test('a look that is not colours is ignored rather than drawn', () => {
  // It arrives in a request body. Anything that is not `#rrggbb` falls back to
  // what this renderer has always drawn, which is the difference between a
  // malformed export and a film nobody can read.
  const look = lookOf({
    lightSquare: 'red',
    darkSquare: '#12345',
    background: '#F7F8FA',
    text: 42,
    accent: null,
  });
  assert.equal(look.lightSquare, null);
  assert.equal(look.darkSquare, null, 'five digits is not a colour');
  assert.equal(look.background, '#F7F8FA');
  assert.equal(look.text, null);
  assert.deepEqual(lookOf(null).accent, null);
  assert.deepEqual(lookOf(undefined).lightSquare, null);
});

test('the film draws the app\'s own pieces and no others', () => {
  // „Nije isti set, ovaj drugi set ne postoji" — the video came back in pieces
  // that exist nowhere in the app. This file used to hold a „Staunton" set and
  // pieceThemes.js an „Alpha" one, neither of them drawn by any board in the
  // app, and the skin recolouring reached for the Staunton one: a trainer who
  // had chosen nothing got a set they had never seen.
  //
  // The shapes are the `chess_vectors_flutter` vectors, pixel for pixel, and
  // this asserts on the path data rather than on a name — a set swapped
  // underneath keeps whatever name it is given.
  const themes = require('../pieceThemes');
  assert.deepEqual(Object.keys(themes), ['classicPieceSvgs'], "one set, and it is the app's");

  const set = recolouredPieces(lookOf({}));
  // The knight's head and the king's base: two paths that differ between any
  // two sets anybody would substitute here.
  assert.ok(set.N.includes('M 22,10 C 32.5,11 38.5,18 38,39 L 15,39 C 15,30 25,32.5 23,18'));
  assert.ok(set.K.includes('M 11.5,37 C 17,40.5 27,40.5 32.5,37'));
});

test('a piece skin repaints every piece, outline and decoration apart', () => {
  // The app's piece skins are five colours over one set of shapes, which is
  // what this does — so „High contrast" in the app and in the film are the same
  // pieces rather than two designers' guesses.
  //
  // Which colour means what is read off `chess_vectors_flutter`'s own
  // parameters rather than guessed: on a white piece the black `fill=` is the
  // knight's eye and nostril, which the app paints with `strokeColor`; on a
  // black piece a white `stroke=` is an inlay — the rook's lines, the king's
  // cross — which the app paints with `decorationColor`. Painting all of them
  // the outline colour would stop a knight looking like a knight.
  const set = recolouredPieces(lookOf({
    whiteFill: '#FFFF00',
    whiteStroke: '#112233',
    blackFill: '#445566',
    blackStroke: '#778899',
    blackDecoration: '#FFFF00',
  }));

  for (const key of ['P', 'N', 'B', 'R', 'Q', 'K']) {
    assert.ok(set[key].includes('fill="#FFFF00"'), `white ${key} takes the skin`);
    assert.ok(!/fill="#(fff|ffffff)"/i.test(set[key]), `no unpainted white left in ${key}`);
    assert.ok(!/stroke="#(000|000000)"/i.test(set[key]), `no unpainted outline left in ${key}`);
  }
  assert.ok(set.N.includes('fill="#112233"'), "the white knight's eye is drawn in the outline colour");

  for (const key of ['p', 'n', 'b', 'r', 'q', 'k']) {
    assert.ok(set[key].includes('fill="#445566"'), `black ${key} takes the skin`);
    assert.ok(!/="#(fff|ffffff)"/i.test(set[key]), `no unpainted decoration left in ${key}`);
  }
  assert.ok(set.n.includes('fill="#FFFF00"'), "the black knight's eye is the decoration");
  assert.ok(set.r.includes('stroke="#FFFF00"'), "and the rook's inlay is the decoration too");
  assert.ok(set.n.includes('stroke="#778899"'), 'while the outline is the stroke colour');
});

test('a skin whose fill is the decoration colour is not painted twice', () => {
  // A chain of substitutions cannot do this: it turns the fill into the new
  // colour and then, when that colour happens to be one a later rule looks for,
  // paints it again. One pass over the attributes is what stops it.
  const set = recolouredPieces(lookOf({
    blackFill: '#FFFFFF',
    blackStroke: '#000000',
    blackDecoration: '#FF0000',
  }));
  assert.ok(set.p.includes('fill="#FFFFFF"'), 'the fill is the fill');
  assert.ok(!set.p.includes('fill="#FF0000"'), 'and not the decoration painted over it');
});

test('the bar is told every ten per cent, and on the last frame', () => {
  // „Nek šalje na svakih 10 procenata osvežavanje". A three-minute film at 4 fps
  // is 720 frames; reporting each of them moves a bar the reader sees change
  // ten times, since the client polls every 900 ms.
  const seen = [];
  const report = tenPercentReporter(
    (drawn, total) => seen.push(Math.round((drawn / total) * 100)), 721);
  for (let frame = 1; frame <= 721; frame++) report(frame);
  assert.deepEqual(seen, [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]);

  // A film short enough that every frame is its own step still reports each one
  // — and never the same one twice.
  const few = [];
  const short = tenPercentReporter((drawn) => few.push(drawn), 4);
  for (let frame = 1; frame <= 4; frame++) short(frame);
  assert.deepEqual(few, [1, 2, 3, 4]);

  // No callback is an ordinary export with nobody watching.
  assert.doesNotThrow(() => tenPercentReporter(null, 10)(1));
  assert.doesNotThrow(() => tenPercentReporter(() => {}, 0)(1));
});

test('a caption wraps on words and keeps the trainer\'s own line break', () => {
  const ctx = createCanvas(1280, 720).getContext('2d');
  assert.deepEqual(captionLines(ctx, '', 400, 22, 4), []);
  assert.deepEqual(captionLines(ctx, '   ', 400, 22, 4), []);

  // Two paragraphs: what was written about the position, and the task under it.
  // They are not one paragraph and must not be reflowed into one.
  const two = captionLines(ctx, 'Look at d5.\nFind the move that defends it.', 4000, 22, 4);
  assert.deepEqual(two, ['Look at d5.', 'Find the move that defends it.']);

  const wrapped = captionLines(ctx, 'one two three four five six seven eight nine ten', 60, 22, 8);
  assert.ok(wrapped.length > 1, 'a sentence wider than the board is broken up');
  assert.ok(wrapped.every((line) => line.trim() !== ''), 'and no line comes out empty');
});

test('a caption too long for its band is cut with an ellipsis, not shrunk', () => {
  const ctx = createCanvas(1280, 720).getContext('2d');
  const lines = captionLines(ctx, 'one two three four five six seven eight nine ten', 60, 22, 2);
  assert.equal(lines.length, 2);
  assert.ok(lines[1].endsWith('…'), 'the reader is told something is missing');
});

test('one caption anywhere makes the film a narrated one', () => {
  // The number decides the layout now rather than a height: any beat with words
  // puts the board on the left and opens the column.
  assert.ok(captionBandLines([
    { data: { fen: FEN } },
    { data: { text: 'Short.' } },
  ]) > 0, 'a caption on the second beat still counts');
  assert.equal(captionBandLines([{ data: { fen: FEN } }, { data: {} }, null]), 0);
  assert.equal(captionBandLines([]), 0);
  assert.equal(captionBandLines(null), 0);
});

test('a new part clears the move that was lit under the old one', () => {
  // `init` opens a position nothing arrived at. Left uncleared, the previous
  // part's last move stays highlighted on a board it has nothing to do with —
  // once per join, for the rest of the film.
  let state = initialFrameState();
  state = applyEvent(state, {
    eventType: 'move',
    data: { fen: FEN, from: 'c3', to: 'd5', san: 'Nd5' },
  });
  assert.equal(state.lastMove.san, 'Nd5');

  state = applyEvent(state, { eventType: 'init', data: { fen: FEN } });
  assert.equal(state.lastMove, null);
});

test('a beat that says nothing clears what the last one drew', () => {
  let state = initialFrameState();
  state = applyEvent(state, {
    eventType: 'init',
    data: {
      fen: FEN,
      text: 'Look at d5.',
      arrows: [{ from: 'c3', to: 'd5', color: 'G' }],
      squares: [{ square: 'd5', color: 'R' }],
    },
  });
  assert.equal(state.caption, 'Look at d5.');
  assert.equal(state.arrows.length, 1);

  state = applyEvent(state, { eventType: 'move', data: { fen: FEN, san: 'Nd5' } });
  assert.equal(state.caption, '', 'the sentence belonged to that beat');
  assert.deepEqual(state.arrows, [], 'and so did the arrow');
  assert.deepEqual(state.squares, []);
});

test('orientation survives a beat that does not mention it', () => {
  // It is a property of the part, not of the beat: only the first event of a
  // part carries it, and every move after that is drawn the same way round.
  let state = initialFrameState();
  state = applyEvent(state, { eventType: 'init', data: { fen: FEN, orientation: 'black' } });
  state = applyEvent(state, { eventType: 'move', data: { fen: FEN, san: 'Nd5' } });
  assert.equal(state.orientation, 'black');

  state = applyEvent(state, { eventType: 'init', data: { fen: FEN, orientation: 'white' } });
  assert.equal(state.orientation, 'white', 'and the next part may turn the board round');
});

// --- The trainer chooses whether the sentences are written beside the board ---
//
// The drawing of both layouts is already covered above; what is new is that a
// flag can pick between them without touching the text, which the voice reads
// and which decides how long a silent beat holds the screen.

const TALKING = [
  { eventType: 'init', timestampMs: 0, data: { fen: FEN, text: 'Look at the d5 square, because both white pieces are aiming at it and the knight cannot be driven away.' } },
];

test('turning the captions off empties the band without touching the text', () => {
  assert.ok(captionBandLines(TALKING, { resolution: '720p' }) > 0,
    'the sentence needs a band when it is drawn');
  assert.equal(captionBandLines(TALKING, { resolution: '720p', captions: false }), 0,
    'and none when the trainer asked for the board alone');

  // The event is untouched: the same text still reaches the voice and still
  // decides the beat's length. Hiding the caption by sending no text would mute
  // the film and race it at the same time.
  assert.ok(TALKING[0].data.text.length > 0);
});

test('a film without captions is drawn once a second, not four times', () => {
  assert.equal(renderer.framesPerSecondOf(TALKING, { resolution: '720p' }), 4);
  assert.equal(renderer.framesPerSecondOf(TALKING, { resolution: '720p', captions: false }), 1,
    'a quarter of the drawing, which is what makes it worth offering');
});

test('the preview shows the layout the film will have, not the other one', async () => {
  // The preview exists so a trainer sees the film's own drawing before spending
  // a render on it, so it has to answer to the same flag. Read off the picture
  // rather than off the flag: a preview that passed the flag on and drew the
  // column anyway would satisfy anything less.
  const withText = await pixels({
    ...BASE,
    captionBand: captionBandLines(TALKING, { resolution: '720p' }),
    caption: TALKING[0].data.text,
  });
  const without = await pixels({
    ...BASE,
    captionBand: captionBandLines(TALKING, { resolution: '720p', captions: false }),
    caption: TALKING[0].data.text,
  });

  const cfg = getResolutionParams('720p');
  const bg = without.at(4, 4);
  const centred = boardGeometry(null, {});

  // **Probed to the right of where a centred board ends**, and not over the
  // caption column itself. A centred board runs into that column's pixels, so
  // „there is no ink beside the board" would be answered by the board — which
  // is the same trap, in mirror image, that a mutation found for the test
  // above. This strip is background in one layout and text in the other.
  const stripLeft = Math.round(centred.offsetX + centred.boardSize + 6);
  const inkRightOfCentre = (frame) => {
    let n = 0;
    for (let x = stripLeft; x < frame.width - 4; x += 2) {
      for (let y = centred.offsetY; y < centred.offsetY + centred.boardSize; y += 2) {
        if (distance(frame.at(x, y), bg) > 40) n += 1;
      }
    }
    return n;
  };
  assert.ok(inkRightOfCentre(withText) > 100,
    'the sentence reaches past where a centred board would end');
  assert.equal(inkRightOfCentre(without), 0,
    'and nothing at all is drawn there when the captions are off');

  // And the board moved back to the middle, at full size.
  const row = Math.round(cfg.offsetY + 10);
  let left = null;
  let right = null;
  for (let x = 0; x < without.width; x++) {
    if (distance(without.at(x, row), bg) > 20) {
      if (left === null) left = x;
      right = x;
    }
  }
  assert.ok(Math.abs(left - (without.width - 1 - right)) <= 2, 'the board is centred');
  assert.ok(Math.abs((right - left + 1) - cfg.boardSize) <= 2, 'and full size');
});
