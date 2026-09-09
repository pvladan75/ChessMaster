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
  captionBandLines,
  captionBandHeight,
  drawColorOf,
  getResolutionParams,
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
function boardGeometry(frame, { resolution = '720p', captionBand = 0, flipped = false } = {}) {
  const cfg = getResolutionParams(resolution);
  const band = captionBandHeight(captionBand, resolution);
  const boardSize = band === 0
    ? cfg.boardSize
    : Math.max(
      Math.round(cfg.boardSize * 0.6),
      Math.min(cfg.boardSize, cfg.height - cfg.offsetY - band - Math.round(cfg.offsetY * 0.3)),
    );
  const offsetX = (cfg.width - boardSize) / 2;
  return { offsetX, offsetY: cfg.offsetY, tileSize: boardSize / 8, boardSize, flipped, cfg };
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

  // The mark is a ring, so the probe is on the ring's own radius rather than in
  // the middle of the square — where the piece standing there is, which is the
  // reason it is a ring and not a filled square.
  const centre = centreOf('d5', geom);
  const side = geom.tileSize;
  const radius = side / 2 - (side * 0.055 * 2.8) / 2 - side * 0.03;
  const onRing = frame.at(centre.x + radius, centre.y);

  assert.ok(distance(onRing, hexToRgb('#FF2929')) < 60,
    `d5's ring should be red, got ${JSON.stringify(onRing)}`);
});

test('the same square is drawn on the other side of a flipped board', async () => {
  const geom = boardGeometry(null, { flipped: true });
  const frame = await pixels({
    ...BASE,
    orientation: 'black',
    squares: [{ square: 'd5', color: 'R' }],
  });

  const centre = centreOf('d5', geom);
  const side = geom.tileSize;
  const radius = side / 2 - (side * 0.055 * 2.8) / 2 - side * 0.03;
  assert.ok(distance(frame.at(centre.x + radius, centre.y), hexToRgb('#FF2929')) < 60,
    'the ring follows the board round');

  // And nothing is drawn where an unflipped board would have put it.
  const unflipped = centreOf('d5', boardGeometry(null, {}));
  assert.ok(distance(frame.at(unflipped.x + radius, unflipped.y), hexToRgb('#FF2929')) > 100,
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
  const centre = centreOf('e5', geom);
  const side = geom.tileSize;
  const radius = side / 2 - (side * 0.055 * 2.8) / 2 - side * 0.03;
  const onRing = frame.at(centre.x + radius, centre.y);
  assert.ok(distance(onRing, hexToRgb('#9E9E9E')) < 60, 'grey, and not a colour with a meaning');
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

test('the board is the same size whatever this beat says', async () => {
  // The band is reserved for the whole film, so a beat with nothing written
  // must not let the board grow back. A board that resizes between two
  // sentences is the reason the height is computed once and passed in.
  const geom = boardGeometry(null, { captionBand: 3 });
  const long = await pixels({
    ...BASE,
    captionBand: 3,
    caption: 'A sentence long enough to need three whole lines of the band under '
      + 'the board, which is what the film reserved room for in the first place.',
  });
  const silent = await pixels({ ...BASE, captionBand: 3, caption: '' });

  // A pixel just inside the board's bottom-left corner is board on both frames,
  // and background on both if the board shrank or grew.
  const probe = { x: geom.offsetX + 4, y: geom.offsetY + geom.boardSize - 4 };
  assert.deepEqual(silent.at(probe.x, probe.y), long.at(probe.x, probe.y));

  // And the row below the board is background on both.
  const below = { x: geom.offsetX + 4, y: geom.offsetY + geom.boardSize + 4 };
  assert.deepEqual(silent.at(below.x, below.y), long.at(below.x, below.y));
});

test('a film with no caption anywhere keeps the geometry it always had', async () => {
  // The recorded-lesson export is verified live and this phase must not move it
  // by a pixel: no caption in any event means no band, and no band means the
  // board is exactly the size this renderer has always drawn.
  const cfg = getResolutionParams('720p');
  assert.equal(captionBandLines([
    { eventType: 'init', data: { fen: FEN } },
    { eventType: 'move', data: { fen: FEN, from: 'c3', to: 'd5', san: 'Nd5' } },
  ]), 0);
  assert.equal(captionBandHeight(0), 0);

  const geom = boardGeometry(null, {});
  assert.equal(geom.boardSize, cfg.boardSize);

  const frame = await pixels({ ...BASE, captionBand: 0 });
  const inside = frame.at(geom.offsetX + 4, geom.offsetY + cfg.boardSize - 4);
  const outside = frame.at(geom.offsetX + 4, geom.offsetY + cfg.boardSize + 8);
  assert.notDeepEqual(inside, outside, 'the board ends exactly where it always did');
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

test('the caption band is room the board actually gave up', async () => {
  // Reserving a band and then drawing the board at full size would put the
  // sentence over the bottom rank, or off the frame. Nothing said otherwise
  // until a mutation that ignored the band left every other test here green.
  const cfg = getResolutionParams('720p');
  const geom = boardGeometry(null, { captionBand: 3 });
  assert.ok(geom.boardSize < cfg.boardSize, 'the board shrank to make the room');

  const frame = await pixels({
    ...BASE,
    captionBand: 3,
    caption: 'A sentence long enough to need three whole lines of the band under '
      + 'the board, which is what the film reserved room for in the first place.',
  });

  // How wide the board came out, read off the picture rather than computed.
  // The board is square and centred, so its width is its size — and unlike its
  // bottom edge, the width cannot be confused with the caption drawn below it.
  //
  // **The first version of this measured the bottom edge and allowed the board
  // to be lower than expected**, which is the one failure it existed to catch:
  // a mutation drawing the board at full size under a reserved band passed it.
  // An assertion with an escape clause is not an assertion.
  const bg = frame.at(4, 4);
  const row = Math.round(geom.offsetY + 10);
  let left = null;
  let right = null;
  for (let x = 0; x < frame.width; x++) {
    if (distance(frame.at(x, row), bg) > 20) {
      if (left === null) left = x;
      right = x;
    }
  }
  const drawnSize = right - left + 1;
  assert.ok(Math.abs(drawnSize - geom.boardSize) <= 2,
    `the board is ${geom.boardSize}px, the size the band left it; drawn ${drawnSize}px`);
  const boardBottom = geom.offsetY + geom.boardSize;

  // And there is ink below the board: the caption is in the room, not over it.
  let inkBelow = 0;
  for (let y = Math.round(boardBottom + 4); y < frame.height; y++) {
    for (let x = Math.round(geom.offsetX); x < geom.offsetX + geom.boardSize; x += 2) {
      if (distance(frame.at(x, y), bg) > 40) inkBelow++;
    }
  }
  assert.ok(inkBelow > 100, 'the sentence is drawn under the board, in its own band');
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

test('the band is measured over every event, not over the first one', () => {
  const band = captionBandLines([
    { data: { text: 'Short.' } },
    { data: { fen: FEN } },
    {
      data: {
        text: 'A much longer sentence about this position, long enough that it '
          + 'has to wrap across more than one line of the band under the board.',
      },
    },
  ]);
  assert.ok(band >= 2, 'the tallest caption decides the band');
  assert.ok(captionBandHeight(band) > captionBandHeight(1));
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
