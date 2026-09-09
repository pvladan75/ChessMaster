const { createCanvas, loadImage } = require('@napi-rs/canvas');
const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');
const { alphaPieceSvgs, classicPieceSvgs } = require('./pieceThemes');

// Standard Staunton SVG definitions
const stauntonPieceSvgs = {
  'P': `<svg xmlns="http://www.w3.org/2000/svg" width="45" height="45"><path d="M 22.5,9 C 20.29,9 18.5,10.79 18.5,13 C 18.5,13.89 18.79,14.71 19.28,15.38 C 17.33,16.5 16,18.59 16,21 C 16,23.03 16.94,24.84 18.41,26.03 C 15.41,27.09 11,31.58 11,39.5 L 34,39.5 C 34,31.58 29.59,27.09 26.59,26.03 C 28.06,24.84 29,23.03 29,21 C 29,18.59 27.67,16.5 25.72,15.38 C 26.21,14.71 26.5,13.89 26.5,13 C 26.5,10.79 24.71,9 22.5,9 z" fill="#ffffff" stroke="#000000" stroke-width="1.5" stroke-linecap="round"/></svg>`,
  'N': `<svg xmlns="http://www.w3.org/2000/svg" width="45" height="45"><path d="M 22,10 C 32.5,11 38.5,18 38,39 L 15,39 C 15,30 25,32.5 23,24 C 21.5,17.5 13,18 13,18 C 13,18 16.5,13 22,10 z" fill="#ffffff" stroke="#000000" stroke-width="1.5" stroke-linecap="round"/><circle cx="27" cy="16" r="1.5" fill="#000000"/></svg>`,
  'B': `<svg xmlns="http://www.w3.org/2000/svg" width="45" height="45"><g fill="none" fill-rule="evenodd" stroke="#000" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><g fill="#fff"><path d="M 9,36 C 12.39,35.03 19.11,36.46 22.5,34 C 25.89,36.46 32.61,35.03 36,36 C 36,36 37.65,36.54 39,38 C 38.32,38.97 37.35,39.5 36,39.5 L 9,39.5 C 7.65,39.5 6.68,38.97 6,38 C 7.35,36.54 9,36 9,36 z"/><path d="M 15,32 C 17.5,34.5 27.5,34.5 30,32 C 30.5,30.5 30,22 30,22 C 30.5,20.5 32,18 32,15.5 C 32,13 30,8.5 22.5,8.5 C 15,8.5 13,13 13,15.5 C 13,18 14.5,20.5 15,22 C 15,22 14.5,30.5 15,32 z"/><circle cx="22.5" cy="6" r="2"/></g><path d="M 17.5,26 L 27.5,26 M 22.5,21 L 22.5,31" stroke="#000"/></g></svg>`,
  'R': `<svg xmlns="http://www.w3.org/2000/svg" width="45" height="45"><g fill="#fff" fill-rule="evenodd" stroke="#000" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M 9,39 L 36,39 L 36,36 L 9,36 z"/><path d="M 12,36 L 12,32 L 33,32 L 33,36 z"/><path d="M 11,14 L 11,9 L 15,9 L 15,11 L 20,11 L 20,9 L 25,9 L 25,11 L 30,11 L 30,9 L 34,9 L 34,14 z"/><path d="M 12,14 L 33,14 L 31,32 L 14,32 z"/></g></svg>`,
  'Q': `<svg xmlns="http://www.w3.org/2000/svg" width="45" height="45"><g fill="#fff" fill-rule="evenodd" stroke="#000" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M 9,26 C 17.5,24.5 30,24.5 36,26 L 38,14 L 31,25 L 22.5,11 L 14,25 L 7,14 z"/><path d="M 9,26 L 36,26 L 36,36 L 9,36 z"/><path d="M 9,39 L 36,39 L 36,36 L 9,36 z"/><circle cx="6" cy="12" r="2"/><circle cx="14" cy="9" r="2"/><circle cx="22.5" cy="6" r="2"/><circle cx="31" cy="9" r="2"/><circle cx="39" cy="12" r="2"/></g></svg>`,
  'K': `<svg xmlns="http://www.w3.org/2000/svg" width="45" height="45"><g fill="none" fill-rule="evenodd" stroke="#000" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M 22.5,11.63 L 22.5,6 M 20,8 L 25,8" stroke="#000"/><g fill="#fff"><path d="M 22.5,25 C 22.5,25 27,17.5 27,14 C 27,11.5 25,9.5 22.5,9.5 C 20,9.5 18,11.5 18,14 C 18,17.5 22.5,25 22.5,25 z"/><path d="M 11.5,37 C 17,35.5 28,35.5 33.5,37 L 35.5,25 C 35.5,25 31,31 22.5,31 C 14,31 9.5,25 9.5,25 z"/><path d="M 11.5,37 L 33.5,37 L 33.5,40 L 11.5,40 z"/></g></g></svg>`,
  'p': `<svg xmlns="http://www.w3.org/2000/svg" width="45" height="45"><path d="M 22.5,9 C 20.29,9 18.5,10.79 18.5,13 C 18.5,13.89 18.79,14.71 19.28,15.38 C 17.33,16.5 16,18.59 16,21 C 16,23.03 16.94,24.84 18.41,26.03 C 15.41,27.09 11,31.58 11,39.5 L 34,39.5 C 34,31.58 29.59,27.09 26.59,26.03 C 28.06,24.84 29,23.03 29,21 C 29,18.59 27.67,16.5 25.72,15.38 C 26.21,14.71 26.5,13.89 26.5,13 C 26.5,10.79 24.71,9 22.5,9 z" fill="#333333" stroke="#ffffff" stroke-width="1.5" stroke-linecap="round"/></svg>`,
  'n': `<svg xmlns="http://www.w3.org/2000/svg" width="45" height="45"><path d="M 22,10 C 32.5,11 38.5,18 38,39 L 15,39 C 15,30 25,32.5 23,24 C 21.5,17.5 13,18 13,18 C 13,18 16.5,13 22,10 z" fill="#333333" stroke="#ffffff" stroke-width="1.5" stroke-linecap="round"/><circle cx="27" cy="16" r="1.5" fill="#ffffff"/></svg>`,
  'b': `<svg xmlns="http://www.w3.org/2000/svg" width="45" height="45"><g fill="none" fill-rule="evenodd" stroke="#fff" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><g fill="#333"><path d="M 9,36 C 12.39,35.03 19.11,36.46 22.5,34 C 25.89,36.46 32.61,35.03 36,36 C 36,36 37.65,36.54 39,38 C 38.32,38.97 37.35,39.5 36,39.5 L 9,39.5 C 7.65,39.5 6.68,38.97 6,38 C 7.35,36.54 9,36 9,36 z"/><path d="M 15,32 C 17.5,34.5 27.5,34.5 30,32 C 30.5,30.5 30,22 30,22 C 30.5,20.5 32,18 32,15.5 C 32,13 30,8.5 22.5,8.5 C 15,8.5 13,13 13,15.5 C 13,18 14.5,20.5 15,22 C 15,22 14.5,30.5 15,32 z"/><circle cx="22.5" cy="6" r="2"/></g><path d="M 17.5,26 L 27.5,26 M 22.5,21 L 22.5,31" stroke="#fff"/></g></svg>`,
  'r': `<svg xmlns="http://www.w3.org/2000/svg" width="45" height="45"><g fill="#333" fill-rule="evenodd" stroke="#fff" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M 9,39 L 36,39 L 36,36 L 9,36 z"/><path d="M 12,36 L 12,32 L 33,32 L 33,36 z"/><path d="M 11,14 L 11,9 L 15,9 L 15,11 L 20,11 L 20,9 L 25,9 L 25,11 L 30,11 L 30,9 L 34,9 L 34,14 z"/><path d="M 12,14 L 33,14 L 31,32 L 14,32 z"/></g></svg>`,
  'q': `<svg xmlns="http://www.w3.org/2000/svg" width="45" height="45"><g fill="#333" fill-rule="evenodd" stroke="#fff" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M 9,26 C 17.5,24.5 30,24.5 36,26 L 38,14 L 31,25 L 22.5,11 L 14,25 L 7,14 z"/><path d="M 9,26 L 36,26 L 36,36 L 9,36 z"/><path d="M 9,39 L 36,39 L 36,36 L 9,36 z"/><circle cx="6" cy="12" r="2"/><circle cx="14" cy="9" r="2"/><circle cx="22.5" cy="6" r="2"/><circle cx="31" cy="9" r="2"/><circle cx="39" cy="12" r="2"/></g></svg>`,
  'k': `<svg xmlns="http://www.w3.org/2000/svg" width="45" height="45"><g fill="none" fill-rule="evenodd" stroke="#fff" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M 22.5,11.63 L 22.5,6 M 20,8 L 25,8" stroke="#fff"/><g fill="#333"><path d="M 22.5,25 C 22.5,25 27,17.5 27,14 C 27,11.5 25,9.5 22.5,9.5 C 20,9.5 18,11.5 18,14 C 18,17.5 22.5,25 22.5,25 z"/><path d="M 11.5,37 C 17,35.5 28,35.5 33.5,37 L 35.5,25 C 35.5,25 31,31 22.5,31 C 14,31 9.5,25 9.5,25 z"/><path d="M 11.5,37 L 33.5,37 L 33.5,40 L 11.5,40 z"/></g></g></svg>`
};

const loadedPieceSets = {};

async function preloadPieceSet(style = 'classic') {
  const normalizedStyle = (style || 'classic').toLowerCase().trim();
  if (loadedPieceSets[normalizedStyle]) return loadedPieceSets[normalizedStyle];
  const dict = normalizedStyle === 'staunton'
    ? stauntonPieceSvgs
    : normalizedStyle === 'alpha'
      ? alphaPieceSvgs
      : classicPieceSvgs;
  const loaded = {};
  for (const [key, svg] of Object.entries(dict)) {
    const dataUrl = `data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}`;
    loaded[key] = await loadImage(dataUrl);
  }
  loadedPieceSets[normalizedStyle] = loaded;
  return loaded;
}

function getBoardColors(themeStr) {
  const normalized = (themeStr || 'wood').toLowerCase().trim();
  switch (normalized) {
    case 'green':
      return { light: '#EEEED2', dark: '#769656', bg: '#1B281B' };
    case 'blue':
      return { light: '#EAE9D2', dark: '#4B7399', bg: '#141E28' };
    case 'charcoal':
      return { light: '#E0E0E0', dark: '#555555', bg: '#181818' };
    case 'wood':
    default:
      return { light: '#F0D9B5', dark: '#B58863', bg: '#1E1E2E' };
  }
}

function getResolutionParams(resolutionStr) {
  switch (resolutionStr) {
    case '1080p':
      return { width: 1920, height: 1080, boardSize: 840, offsetY: 120, fontSizeTitle: 32, fontSizeTimer: 26, fontSizeCoord: 18, fontSizeMove: 24, fontSizeCaption: 40 };
    case '480p':
      return { width: 854, height: 480, boardSize: 360, offsetY: 55, fontSizeTitle: 16, fontSizeTimer: 14, fontSizeCoord: 10, fontSizeMove: 14, fontSizeCaption: 20 };
    case '720p':
    default:
      return { width: 1280, height: 720, boardSize: 560, offsetY: 90, fontSizeTitle: 24, fontSizeTimer: 20, fontSizeCoord: 12, fontSizeMove: 16, fontSizeCaption: 28 };
  }
}

/// The five colours a trainer can draw with, and the grey for anything else.
///
/// Copied by value from `chess_app/lib/theme/arrow_colors.dart`, which is where
/// they were chosen and where the reasoning lives — hue *and* luminance are
/// spread on purpose, because the person who signs this work off is colourblind
/// and reads shape and lightness rather than hue.
///
/// The fallback is grey on purpose and must stay grey: green *means* something
/// in this vocabulary, so drawing an unrecognised code green would be a
/// statement rather than a default.
const DRAW_COLORS = {
  R: '#FF2929',
  O: '#FF9429',
  G: '#85FF85',
  B: '#00188F',
  P: '#910FB3',
};
const DRAW_FALLBACK = '#9E9E9E';

function drawColorOf(code) {
  return DRAW_COLORS[String(code || '').toUpperCase()] || DRAW_FALLBACK;
}

/// Where a square sits on the drawn board, or null when it is not a square.
function squareTopLeft(square, { offsetX, offsetY, tileSize, flipped }) {
  const name = String(square || '').trim().toLowerCase();
  if (!/^[a-h][1-8]$/.test(name)) return null;
  const col = name.charCodeAt(0) - 97;
  const row = 8 - parseInt(name[1], 10);
  const c = flipped ? 7 - col : col;
  const r = flipped ? 7 - row : row;
  return { x: offsetX + c * tileSize, y: offsetY + r * tileSize };
}

function squareCenter(square, geom) {
  const at = squareTopLeft(square, geom);
  if (!at) return null;
  return { x: at.x + geom.tileSize / 2, y: at.y + geom.tileSize / 2 };
}

/// `[%csl]` — the same three rings the app draws, in the same order.
///
/// Black halo, white halo, then the colour. Two neutral rings under a coloured
/// one is what makes the mark readable on a light square and on a dark one
/// without knowing which it landed on; a filled square would be cheaper and
/// would hide the piece standing on it, which is usually the piece being talked
/// about.
function drawSquareMark(ctx, square, code, geom) {
  const centre = squareCenter(square, geom);
  if (!centre) return;
  const side = geom.tileSize;
  const core = side * 0.055;
  const light = core * 1.8;
  const shade = core * 2.8;
  const radius = side / 2 - shade / 2 - side * 0.03;
  if (radius <= 0) return;

  const ring = (colour, width) => {
    ctx.beginPath();
    ctx.arc(centre.x, centre.y, radius, 0, Math.PI * 2);
    ctx.strokeStyle = colour;
    ctx.lineWidth = width;
    ctx.stroke();
  };
  ring('#000000', shade);
  ring('#FFFFFF', light);
  ring(drawColorOf(code), core);
}

/// `[%cal]` — a line from the middle of one square to the middle of another,
/// with a head, stopping short of the far centre so the head sits inside the
/// square it points at rather than over the piece standing there.
function drawArrow(ctx, from, to, code, geom) {
  const a = squareCenter(from, geom);
  const b = squareCenter(to, geom);
  if (!a || !b) return;
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const length = Math.hypot(dx, dy);
  if (length < 1) return;

  const ux = dx / length;
  const uy = dy / length;
  const head = geom.tileSize * 0.38;
  const shaftWidth = geom.tileSize * 0.16;
  // The tail leaves the edge of its own square rather than its centre: an arrow
  // that starts under the piece it is about hides the piece.
  const start = { x: a.x + ux * geom.tileSize * 0.22, y: a.y + uy * geom.tileSize * 0.22 };
  const tip = { x: b.x - ux * geom.tileSize * 0.12, y: b.y - uy * geom.tileSize * 0.12 };
  const neck = { x: tip.x - ux * head, y: tip.y - uy * head };
  if (Math.hypot(neck.x - start.x, neck.y - start.y) < 1) return;

  ctx.save();
  ctx.globalAlpha = 0.85;
  ctx.strokeStyle = drawColorOf(code);
  ctx.fillStyle = drawColorOf(code);
  ctx.lineWidth = shaftWidth;
  ctx.lineCap = 'butt';
  ctx.beginPath();
  ctx.moveTo(start.x, start.y);
  ctx.lineTo(neck.x, neck.y);
  ctx.stroke();

  const wing = head * 0.55;
  ctx.beginPath();
  ctx.moveTo(tip.x, tip.y);
  ctx.lineTo(neck.x - uy * wing, neck.y + ux * wing);
  ctx.lineTo(neck.x + uy * wing, neck.y - ux * wing);
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

/// How many lines the caption needs, and what they are.
///
/// Wrapped on words, with a hard split for a word longer than the line — a FEN
/// pasted into a sentence must not run off the frame. `\n` in the text is the
/// trainer's own break: a part that asks something carries its task on the line
/// under what was written, and the two are not one paragraph.
function captionLines(ctx, text, maxWidth, fontSize, maxLines) {
  const trimmed = String(text || '').trim();
  if (!trimmed) return [];
  ctx.font = `${fontSize}px sans-serif`;

  const lines = [];
  for (const paragraph of trimmed.split('\n')) {
    let line = '';
    for (const word of paragraph.trim().split(/\s+/)) {
      if (!word) continue;
      const candidate = line ? `${line} ${word}` : word;
      if (ctx.measureText(candidate).width <= maxWidth || !line) {
        line = candidate;
        continue;
      }
      lines.push(line);
      line = word;
    }
    if (line) lines.push(line);
  }

  if (lines.length <= maxLines) return lines;
  // Truncated rather than shrunk: a caption that shrinks to fit is a caption
  // nobody can read, and the dwell time was computed from the whole sentence
  // anyway. The ellipsis says something is missing.
  const kept = lines.slice(0, maxLines);
  kept[maxLines - 1] = `${kept[maxLines - 1].replace(/\s+\S*$/, '')}…`;
  return kept;
}

/// How much of a wrapped caption is on screen at [reveal] of the way through it.
///
/// Characters rather than words, and measured across the whole sentence rather
/// than per line, so the writing runs at one speed from the first word to the
/// last instead of pausing at every line break.
///
/// **Whole words on the way in.** Cutting mid-word writes „the knig" for a
/// quarter of a second, which reads as a glitch rather than as typing; the
/// partial word is held back until it is complete. The exception is a word
/// longer than a line, which would otherwise never appear at all.
function revealedLines(lines, reveal) {
  const fraction = Number.isFinite(reveal) ? Math.min(1, Math.max(0, reveal)) : 1;
  if (fraction >= 1) return lines;

  const total = lines.reduce((sum, line) => sum + line.length, 0);
  let budget = Math.floor(total * fraction);
  const out = [];

  for (const line of lines) {
    if (budget <= 0) {
      out.push('');
      continue;
    }
    if (budget >= line.length) {
      out.push(line);
      budget -= line.length;
      continue;
    }
    const cut = line.slice(0, budget);
    const lastSpace = cut.lastIndexOf(' ');
    if (lastSpace > 0) {
      out.push(cut.slice(0, lastSpace));
    } else if (line.includes(' ')) {
      // Not one whole word yet. Nothing, rather than „Loo" — which is what the
      // first version drew for the first quarter-second of every line, and
      // reads as a glitch rather than as writing.
      out.push('');
    } else {
      // One word longer than the whole line. Held back completely it would
      // never appear at all, so this is the one place a partial word is right.
      out.push(cut);
    }
    budget = 0;
  }
  return out;
}

/// The most lines any caption in [events] needs, measured once for the film.
///
/// The band is one height for the whole video, and that is the point: the board
/// is sized around it, so a per-frame height would make the board grow and
/// shrink under the viewer between one sentence and the next.
function captionBandLines(events, { resolution = '720p', maxLines = 4 } = {}) {
  const cfg = getResolutionParams(resolution);
  const probe = createCanvas(cfg.width, cfg.height).getContext('2d');
  let most = 0;
  for (const event of Array.isArray(events) ? events : []) {
    const text = event && event.data ? event.data.text : null;
    if (!text) continue;
    const lines = captionLines(probe, text, cfg.boardSize, cfg.fontSizeCaption, maxLines);
    if (lines.length > most) most = lines.length;
  }
  return most;
}

/// One picture is drawn per second of film, and the file says 30 frames a
/// second.
///
/// Those are two different numbers on purpose. **What the board shows only
/// changes when a beat changes**, so drawing thirty times a second would be
/// thirty identical pictures: measured on this machine, a three-minute film is
/// 180 drawings and 4.7 seconds at 720p, and would be 5,400 drawings and 140
/// seconds. The *container's* rate is a different question — a 1 fps file is
/// unusual enough that players scrub it badly and some upload pipelines refuse
/// it — and ffmpeg fills the gap by repeating a frame it has already encoded.
/// Measured too: the same nineteen drawings came out as a normal 30 fps file
/// for half a second of extra encoding and 62 KB.
///
/// The moment this stops being right is the moment something *moves* — a piece
/// sliding, an arrow drawing itself. Then the frames between two beats are all
/// different and have to be drawn, and this constant is the rate to draw them
/// at.
const OUTPUT_FPS = 30;

/// Drawings a second while a sentence is being written on screen.
///
/// Not `OUTPUT_FPS`: that is what the file claims and costs nothing, this is
/// what the canvas actually draws and costs four times. Four is enough for the
/// eye at reading speed — a word appears about every third of a second — and a
/// film without captions is still drawn once a second.
const CAPTION_FPS = 4;

/// The ffmpeg command line, as a value a test can read.
///
/// Split out for the same reason `applyEvent` was: everything else in this file
/// can be checked by looking at a picture, and this cannot be checked at all
/// without spawning a process — which is a test that fails on a machine with no
/// ffmpeg on it.
function ffmpegArgsFor({ audioFilePath = null, outputPath, inputFps = 1 }) {
  const args = [
    '-y',
    '-f', 'image2pipe',
    '-vcodec', 'png',
    // The rate the pictures arrive at, which is what the film's clock is made
    // of. It is not the rate the file claims; see `-r` below.
    '-framerate', String(inputFps),
    '-i', 'pipe:0',
  ];

  if (audioFilePath) {
    args.push('-i', audioFilePath);
  } else {
    args.push('-f', 'lavfi', '-i', 'anullsrc=r=44100:cl=stereo');
  }

  args.push(
    // The rate the file claims, after both inputs and before the output, which
    // is what makes it an *output* option. Written one input earlier it becomes
    // an input option for the audio and silently does nothing — which is how
    // the first attempt at this produced a byte-identical 1 fps file.
    '-r', String(OUTPUT_FPS),
    '-c:v', 'libx264',
    '-pix_fmt', 'yuv420p',
    '-c:a', 'aac',
  );
  if (audioFilePath) args.push('-b:a', '192k');
  args.push('-shortest', outputPath);
  return args;
}

const OPENING_FEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// The state of the picture before any event has been read.
function initialFrameState() {
  return {
    fen: OPENING_FEN,
    lastMove: null,
    caption: '',
    arrows: [],
    squares: [],
    orientation: null,
  };
}

/// One event applied to [state], as a new state.
///
/// Pulled out of the render loop so it can be tested without ffmpeg, and
/// because two of its rules are easy to get wrong and impossible to see in a
/// finished MP4 without watching the whole thing:
///
///   * **`init` clears the last move.** A new part opens on a position nothing
///     arrived at. Left uncleared, the previous part's move stays lit under a
///     board it has nothing to do with — harmless in a recording, where `init`
///     happens once, and wrong at every join of a tutorial.
///   * **Marks and the sentence belong to their beat.** Every event replaces
///     them and an event that says nothing clears them, so an arrow cannot
///     outlive the position it was drawn about.
///
/// Orientation is the exception: it persists until an event says otherwise,
/// because it is a property of the part rather than of the beat.
function applyEvent(state, event) {
  const next = { ...state };
  const data = (event && event.data) || null;

  if (event && event.eventType === 'init' && data && data.fen) {
    next.fen = data.fen;
    next.lastMove = null;
  } else if (event && event.eventType === 'move' && data) {
    if (data.fen) next.fen = data.fen;
    next.lastMove = { from: data.from, to: data.to, san: data.san };
  }

  if (data) {
    next.caption = data.text || '';
    next.arrows = Array.isArray(data.arrows) ? data.arrows : [];
    next.squares = Array.isArray(data.squares) ? data.squares : [];
    if (data.orientation) next.orientation = data.orientation;
  }
  return next;
}

function formatTime(sec) {
  const m = Math.floor(sec / 60).toString().padStart(2, '0');
  const s = Math.floor(sec % 60).toString().padStart(2, '0');
  return `${m}:${s}`;
}

async function renderFrameBuffer({
  title,
  fen,
  perspective,
  // A colour, and it wins over `perspective` when it is given. The two say the
  // same thing in different vocabularies: `perspective` spells the sides
  // „trainer" and „student", which is what a recorded lesson has, while a
  // tutorial is written from White's side or Black's and says so per part.
  orientation = null,
  lastMove,
  caption = '',
  // How much of the sentence has been said, 0 to 1. The caption is written on
  // screen at the speed it is spoken; 1 is the whole of it, which is what a
  // film with no voice draws from its first frame of a beat onwards.
  captionReveal = 1,
  arrows = [],
  squares = [],
  // Reserved for the caption band, in lines, for the whole film. See
  // `captionBandLines`: one height throughout, so the board does not resize
  // under the viewer between two sentences.
  captionBand = 0,
  timestampSec,
  totalDurationSec,
  resolution = '720p',
  pieceStyle = 'classic',
  boardTheme = 'wood',
  showTitle = true,
  showTimer = true,
  showCoords = true,
  showMoveText = true,
}) {
  const pieceImages = await preloadPieceSet(pieceStyle);
  const cfg = getResolutionParams(resolution);
  const colors = getBoardColors(boardTheme);

  const width = cfg.width;
  const height = cfg.height;
  // **A film that speaks puts the sentence beside the board, not under it.**
  //
  // The frame is 16:9 and the board is square, so a centred board leaves 720
  // unused pixels either side of it at 720p while the caption is squeezed into
  // whatever height is left underneath. Moving the text into a column of its
  // own buys it four times the room, keeps the board at full size, and — the
  // reason the owner asked for it — means a longer sentence cannot move
  // anything: the column is a fixed width and the text is centred inside it, so
  // the board sits in the same place on every frame of the film whatever this
  // beat says.
  //
  // A film with no caption anywhere keeps the centred layout exactly as it has
  // always been drawn. The recorded-lesson export is verified live and must not
  // move by a pixel.
  const captionColumn = captionBand > 0;
  const margin = Math.round(cfg.offsetY * 0.6);
  const boardSize = Math.min(cfg.boardSize, height - cfg.offsetY - margin);
  const offsetX = captionColumn ? margin : (width - boardSize) / 2;
  const offsetY = cfg.offsetY;
  const tileSize = boardSize / 8;

  // What is left of the width, less a gap on either side of it.
  const captionLeft = offsetX + boardSize + margin;
  const captionWidth = Math.max(0, width - captionLeft - margin);

  const canvas = createCanvas(width, height);
  const ctx = canvas.getContext('2d');

  // Background
  ctx.fillStyle = colors.bg;
  ctx.fillRect(0, 0, width, height);

  // Top Title Bar
  if (showTitle) {
    ctx.fillStyle = '#FFFFFF';
    ctx.font = `bold ${cfg.fontSizeTitle}px sans-serif`;
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    // No pawn glyph in front of it. `@napi-rs/canvas` on this server has no
    // font with U+265F in it, so every frame of every export ever rendered has
    // carried a tofu box where the pawn was meant to be — found by looking at
    // a frame, which no test here had ever done.
    ctx.fillText(`${title || 'Session recording'}`, offsetX, offsetY / 2);
  }

  // Timer & Status Badge
  if (showTimer) {
    ctx.fillStyle = '#00ADB5';
    ctx.font = `bold ${cfg.fontSizeTimer}px sans-serif`;
    ctx.textAlign = 'right';
    // Against the right edge of whatever the frame is showing: the board when
    // that is all there is, and the caption column when there is one. Left at
    // the board's edge it would sit in the middle of the frame with the
    // sentence beside it, which reads as a label on the text rather than as the
    // film's clock.
    const timerRight = captionColumn ? captionLeft + captionWidth : offsetX + boardSize;
    ctx.fillText(`${formatTime(timestampSec)} / ${formatTime(totalDurationSec)}`, timerRight, offsetY / 2);
  }

  // Draw 8x8 Board
  const isBlackPerspective = orientation
    ? String(orientation).toLowerCase() === 'black'
    : perspective === 'student';
  for (let r = 0; r < 8; r++) {
    for (let c = 0; c < 8; c++) {
      const displayR = isBlackPerspective ? 7 - r : r;
      const displayC = isBlackPerspective ? 7 - c : c;

      const isLight = (displayR + displayC) % 2 === 0;
      ctx.fillStyle = isLight ? colors.light : colors.dark;
      ctx.fillRect(offsetX + c * tileSize, offsetY + r * tileSize, tileSize, tileSize);
    }
  }

  // Draw Move Highlight if present
  if (lastMove && lastMove.from && lastMove.to) {
    const highlightSquare = (sq) => {
      const col = sq.charCodeAt(0) - 97; // 'a' -> 0
      const row = 8 - parseInt(sq[1]);   // '8' -> 0
      const c = isBlackPerspective ? 7 - col : col;
      const r = isBlackPerspective ? 7 - row : row;
      ctx.fillStyle = 'rgba(247, 236, 89, 0.45)';
      ctx.fillRect(offsetX + c * tileSize, offsetY + r * tileSize, tileSize, tileSize);
    };
    try {
      highlightSquare(lastMove.from);
      highlightSquare(lastMove.to);
    } catch (e) {}
  }

  // Draw Rank/File Coordinates
  if (showCoords) {
    ctx.font = `bold ${cfg.fontSizeCoord}px sans-serif`;
    // The title block left the baseline on `middle`, which centred the file
    // letters on the board's own bottom edge and cut every one of them in half.
    ctx.textBaseline = 'alphabetic';
    for (let i = 0; i < 8; i++) {
      const fileLabel = isBlackPerspective ? String.fromCharCode(104 - i) : String.fromCharCode(97 + i);
      const rankLabel = isBlackPerspective ? (i + 1).toString() : (8 - i).toString();

      // Files at bottom.
      //
      // The parity is the opposite of the ranks', and that is not a typo: a
      // label has to be painted in the colour its square is *not*. The bottom
      // row and the left column start on opposite colours, so one expression
      // cannot serve both — and this one served the ranks, which is why the
      // rank numbers have always been readable and **not one file letter has
      // ever been drawn in any export**: dark on dark, then light on light,
      // eight times. Found by looking at a frame.
      ctx.fillStyle = i % 2 === 0 ? colors.light : colors.dark;
      ctx.textAlign = 'right';
      ctx.fillText(fileLabel, offsetX + (i + 1) * tileSize - 4, offsetY + boardSize - 4);

      // Ranks at left
      ctx.textAlign = 'left';
      ctx.fillText(rankLabel, offsetX + 4, offsetY + i * tileSize + cfg.fontSizeCoord + 2);
    }
  }

  // Render Vector SVG Pieces from FEN
  const fenParts = (fen || 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR').split(' ');
  const boardFen = fenParts[0];
  let r = 0, c = 0;

  for (let i = 0; i < boardFen.length; i++) {
    const char = boardFen[i];
    if (char === '/') {
      r++;
      c = 0;
    } else if (!isNaN(parseInt(char))) {
      c += parseInt(char);
    } else {
      const displayR = isBlackPerspective ? 7 - r : r;
      const displayC = isBlackPerspective ? 7 - c : c;

      const pieceImg = pieceImages[char];
      if (pieceImg) {
        ctx.drawImage(
          pieceImg,
          offsetX + displayC * tileSize,
          offsetY + displayR * tileSize,
          tileSize,
          tileSize
        );
      }

      c++;
    }
  }

  // The trainer's drawings, over the pieces rather than under them — the same
  // order the app's overlay painter uses, and for the same reason: an arrow
  // about a piece that is drawn beneath it is an arrow about nothing.
  const geom = { offsetX, offsetY, tileSize, flipped: isBlackPerspective };
  for (const mark of Array.isArray(squares) ? squares : []) {
    if (mark) drawSquareMark(ctx, mark.square, mark.color, geom);
  }
  for (const arrow of Array.isArray(arrows) ? arrows : []) {
    if (arrow) drawArrow(ctx, arrow.from, arrow.to, arrow.color, geom);
  }

  // Footer Move Text
  if (showMoveText) {
    ctx.fillStyle = '#EEEEEE';
    ctx.font = `${cfg.fontSizeMove}px sans-serif`;
    ctx.textAlign = 'center';
    const moveText = lastMove && lastMove.san ? `Last move: ${lastMove.san}` : 'Starting position';
    ctx.fillText(moveText, width / 2, offsetY + boardSize + cfg.fontSizeMove + 15);
  }

  // The caption, which for a tutorial is most of the teaching.
  //
  // Left-aligned in its column and centred vertically against the board: a
  // sentence set ragged-right is easier to read across many lines than a
  // centred block, and a short one sits opposite the middle of the position it
  // is about rather than floating at the top of an empty column.
  if (captionColumn && captionWidth > cfg.fontSizeCaption * 4) {
    const lineHeight = cfg.fontSizeCaption * 1.4;
    const maxLines = Math.max(1, Math.floor((boardSize - lineHeight) / lineHeight));
    // **Wrapped whole, then revealed.** Wrapping only what has been said so far
    // would reflow the sentence as it arrives — a word jumping to the line above
    // as the next one lands — and the block would move under the reader. The
    // lines are the finished sentence's lines; the reveal only decides how much
    // of each is drawn.
    const lines = captionLines(ctx, caption, captionWidth, cfg.fontSizeCaption, maxLines);
    const block = lines.length * lineHeight;
    const top = offsetY + Math.max(0, (boardSize - block) / 2);
    const shown = revealedLines(lines, captionReveal);

    ctx.fillStyle = '#FFFFFF';
    ctx.font = `${cfg.fontSizeCaption}px sans-serif`;
    ctx.textAlign = 'left';
    ctx.textBaseline = 'top';
    shown.forEach((line, i) => {
      if (line) ctx.fillText(line, captionLeft, top + i * lineHeight);
    });
  }

  return canvas.toBuffer('image/png');
}

async function renderRecordingToMP4({
  title,
  timelineEvents,
  audioFilePath,
  durationSeconds,
  perspective,
  resolution = '720p',
  pieceStyle = 'classic',
  boardTheme = 'wood',
  showTitle = true,
  showTimer = true,
  showCoords = true,
  showMoveText = true,
  outputPath
}) {
  return new Promise(async (resolve, reject) => {
    const totalDuration = Math.max(3, Math.min(3600, Math.ceil(durationSeconds || 10)));
    const events = Array.isArray(timelineEvents) ? timelineEvents : [];

    console.log(`[VIDEO_RENDER] Rendering ${resolution} MP4 (${pieceStyle}/${boardTheme}): ${totalDuration}s, ${events.length} events, audio: ${audioFilePath}`);

    // Preload piece set
    await preloadPieceSet(pieceStyle);

    const hasAudio = audioFilePath && fs.existsSync(audioFilePath);
    const ffmpeg = spawn('ffmpeg', ffmpegArgsFor({
      audioFilePath: hasAudio ? audioFilePath : null,
      outputPath,
      inputFps: captionBandLines(events, { resolution }) > 0 ? CAPTION_FPS : 1,
    }));

    ffmpeg.stderr.on('data', (data) => {
      // Quiet stderr
    });

    ffmpeg.on('close', (code) => {
      if (code === 0) {
        console.log(`[VIDEO_RENDER] Success! Custom MP4 saved to ${outputPath}`);
        resolve(outputPath);
      } else {
        reject(new Error(`FFmpeg exited with code ${code}`));
      }
    });

    ffmpeg.on('error', (err) => {
      reject(err);
    });

    // Whether any beat says anything, which decides the layout and the rate.
    const captionBand = captionBandLines(events, { resolution });

    // **Frames a second, and why it is not one.**
    //
    // Nothing moves between beats when the sentence is simply printed, so one
    // drawing a second was right and cheap. A sentence that *arrives as it is
    // spoken* changes every frame while it is being read, so the film has to be
    // drawn often enough for that to look like writing rather than like a
    // slideshow of half-sentences. Four is enough for the eye at reading speed
    // and costs four times the drawing — a three-minute film goes from about
    // five seconds to twenty at 720p, measured on this machine.
    //
    // A film with no captions is still drawn once a second, exactly as it always
    // was. The recorded-lesson export is verified live.
    const fps = captionBand > 0 ? CAPTION_FPS : 1;
    const frames = totalDuration * fps;

    let state = initialFrameState();
    let eventIdx = 0;
    // When the sentence now on screen started being spoken, and for how long.
    let captionStartMs = 0;
    let captionSpokenMs = 0;

    for (let frame = 0; frame <= frames; frame++) {
      const currentMs = Math.round((frame * 1000) / fps);
      const sec = Math.floor(currentMs / 1000);

      while (eventIdx < events.length && (events[eventIdx].timestampMs || 0) <= currentMs) {
        const event = events[eventIdx];
        state = applyEvent(state, event);
        captionStartMs = event.timestampMs || 0;
        // `spokenMs` is written by `narrationPlan` when a voice read this beat:
        // the sentence is then revealed at exactly the speed it is being said.
        // Without it — a silent film — the reveal takes the beat's own length,
        // less a breath, so the last words are on screen before it moves on.
        captionSpokenMs = Number(event.data?.spokenMs) || 0;
        eventIdx++;
      }

      const nextStart = eventIdx < events.length
        ? (events[eventIdx].timestampMs || 0)
        : totalDuration * 1000;
      const revealOver = captionSpokenMs > 0
        ? captionSpokenMs
        : Math.max(1, (nextStart - captionStartMs) * 0.75);
      const captionReveal = Math.min(1, Math.max(0, (currentMs - captionStartMs) / revealOver));

      const frameBuf = await renderFrameBuffer({
        title,
        fen: state.fen,
        perspective: perspective || 'trainer',
        orientation: state.orientation,
        lastMove: state.lastMove,
        caption: state.caption,
        arrows: state.arrows,
        squares: state.squares,
        captionBand,
        captionReveal,
        timestampSec: sec,
        totalDurationSec: totalDuration,
        resolution,
        pieceStyle,
        boardTheme,
        showTitle,
        showTimer,
        showCoords,
        showMoveText
      });

      ffmpeg.stdin.write(frameBuf);
    }

    ffmpeg.stdin.end();
  });
}

module.exports = {
  renderFrameBuffer,
  renderRecordingToMP4,
  // Exported for the tests, which read pixels out of a rendered frame: a
  // drawing that cannot be measured is a drawing nobody can grade.
  captionLines,
  revealedLines,
  captionBandLines,
  ffmpegArgsFor,
  OUTPUT_FPS,
  CAPTION_FPS,
  drawColorOf,
  getResolutionParams,
  applyEvent,
  initialFrameState
};
