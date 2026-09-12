const { createCanvas, loadImage } = require('@napi-rs/canvas');
const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');
const { classicPieceSvgs } = require('./pieceThemes');
const { fontFamily } = require('./services/renderFont');
const { RenderAborted, killOnAbort } = require('./services/renderAbort');

/// Removes a file ffmpeg was part way through writing.
///
/// Quiet about a file that is not there: ffmpeg killed before it opened the
/// output leaves nothing behind, and that is the same success as removing it.
function removePartial(outputPath) {
  try {
    if (outputPath && fs.existsSync(outputPath)) fs.unlinkSync(outputPath);
  } catch {
    // A file the process cannot delete is a file left in `exports/`, where the
    // retention timer will take it. Not worth failing an abort over.
  }
}

/// The app's own look, sent with an export so the film matches the screen the
/// tutorial was written on.
///
/// **Colours rather than names**, and that is the whole design. The renderer
/// used to take `boardTheme: 'wood'` and keep its own idea of what wood is,
/// which drifts from the app's the first time either side retunes a square —
/// and the app has five board skins, three piece skins and a light and a dark
/// theme, none of which this file has ever heard of. What travels now is what
/// the trainer is actually looking at.
///
/// Every field is optional and a missing one falls back to what this renderer
/// has always drawn. The recorded-lesson export sends none of them.
function lookOf(look) {
  const hex = (value, fallback) =>
    (typeof value === 'string' && /^#[0-9a-fA-F]{6}$/.test(value) ? value : fallback);
  const l = look || {};
  return {
    lightSquare: hex(l.lightSquare, null),
    darkSquare: hex(l.darkSquare, null),
    background: hex(l.background, null),
    text: hex(l.text, null),
    accent: hex(l.accent, null),
    whiteFill: hex(l.whiteFill, null),
    whiteStroke: hex(l.whiteStroke, null),
    blackFill: hex(l.blackFill, null),
    blackStroke: hex(l.blackStroke, null),
    blackDecoration: hex(l.blackDecoration, null),
  };
}

/// The app's own set, recoloured to a piece skin.
///
/// The app's three piece skins are five colours over one set of shapes — the
/// `chess_vectors_flutter` vectors every board in the app draws — which is
/// exactly what this does, so „High contrast" in the app and „High contrast" in
/// the film are the same pieces rather than two designers' guesses.
///
/// **Which colour means what is read off the package's own parameters**, not
/// guessed from the attribute. On a white piece the black `fill=` is the
/// knight's eye and nostril, which the app paints with `strokeColor`; on a
/// black piece a white `stroke=` is an inlay — the rook's lines, the king's
/// cross, the queen's bands — which the app paints with `decorationColor`.
/// Painting all of those the outline colour would stop a knight looking like a
/// knight.
function repaint(svg, map) {
  // One pass over the attributes, so no colour is painted twice. A chain of
  // substitutions cannot do this: on a black piece `fill="#000000"` becomes the
  // skin's fill, and if that fill happens to be white the next rule in the
  // chain would repaint it as a decoration.
  return svg.replace(/(fill|stroke)="(#[0-9a-fA-F]{3,6})"/g, (whole, attr, colour) => {
    const to = map[`${attr}:${colour.toLowerCase()}`];
    return to ? `${attr}="${to}"` : whole;
  });
}

function recolouredPieces(look) {
  const out = {};
  for (const [key, svg] of Object.entries(classicPieceSvgs)) {
    const white = key === key.toUpperCase();
    const map = {};
    if (white) {
      if (look.whiteFill) map['fill:#ffffff'] = look.whiteFill;
      if (look.whiteStroke) {
        map['stroke:#000000'] = look.whiteStroke;
        map['fill:#000000'] = look.whiteStroke;
      }
    } else {
      if (look.blackFill) map['fill:#000000'] = look.blackFill;
      if (look.blackStroke) map['stroke:#000000'] = look.blackStroke;
      if (look.blackDecoration) {
        map['fill:#ffffff'] = look.blackDecoration;
        map['stroke:#ffffff'] = look.blackDecoration;
      }
    }
    out[key] = repaint(svg, map);
  }
  return out;
}

const loadedPieceSets = {};

/// The pieces the film draws, loaded once.
///
/// **There is one set of shapes and it is the app's.** This file used to carry
/// two more that exist nowhere in the app — „Alpha" and „Staunton" — and a
/// `pieceStyle` naming them, and the recolouring reached for the wrong one: a
/// trainer who had chosen nothing got a film in pieces they had never seen.
/// A skin is colours over the one set, which is what the app itself does.
async function preloadPieceSet(look = null) {
  const l = look || {};
  const skinColours = [l.whiteFill, l.whiteStroke, l.blackFill, l.blackStroke, l.blackDecoration];
  // A recoloured set is cached under its colours, so a film keeps one skin and
  // two trainers with different skins do not share a cache entry.
  const key = skinColours.some(Boolean) ? `skin:${skinColours.join('|')}` : 'classic';
  if (loadedPieceSets[key]) return loadedPieceSets[key];
  const dict = key === 'classic' ? classicPieceSvgs : recolouredPieces(l);
  const loaded = {};
  for (const [name, svg] of Object.entries(dict)) {
    const dataUrl = `data:image/svg+xml;base64,${Buffer.from(svg).toString('base64')}`;
    loaded[name] = await loadImage(dataUrl);
  }
  loadedPieceSets[key] = loaded;
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

/// The three stroke widths of a `[%csl]` frame, as fractions of one square's
/// side — the app's `ChessBoardPainter.squareMark*Fraction`, value for value.
///
/// Exported so a test can compare them with the app's rather than with a
/// comment claiming they match. CLAUDE.md records a motif table kept by hand in
/// two places and the two sentences that drifted apart in it; this is the same
/// shape with numbers instead of words.
/// The app's `LastMovePainter.wash`: black at 22%, and no hue at all.
///
/// Black rather than a colour because it cannot then collide with any of the
/// five a trainer marks squares in, on any board, for any kind of eye — it has
/// no hue to collide with. Worst contrast against a square of any skin is
/// 1.46:1, against the 1.03:1 of the amber it replaced.
const LAST_MOVE_WASH = 'rgba(0, 0, 0, 0.22)';

const SQUARE_MARK_FRACTIONS = Object.freeze({
  core: 0.055,
  light: 0.075,
  shade: 0.105,
});

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

/// `[%csl]` — the same three frames the app draws, in the same order and at
/// the same widths.
///
/// **These were rings until 12.9.2026**, here and in the app on the same day,
/// because a rule kept in two places is two rules and a tutorial must not look
/// one way on a trainer's screen and another way in the film a child is sent.
/// The widths are `SQUARE_MARK_FRACTIONS` below, and
/// `test/square_mark_frame.test.js` asserts they are the app's own numbers.
///
/// Black frame, white frame, then the colour — each hugging the square's edge,
/// so they nest and the colour ends up on the outermost band. Two neutral
/// passes under a coloured one is what makes the mark readable on a light
/// square and on a dark one without knowing which it landed on: measured
/// against every square of every skin, three of the palette's five colours
/// measure under 1.25:1 on their own and vanish into the square they are drawn
/// on. A filled square would be cheaper and would hide the piece standing on
/// it, which is usually the piece being talked about.
function drawSquareMark(ctx, square, code, geom) {
  const at = squareTopLeft(square, geom);
  if (!at) return;
  const side = geom.tileSize;
  if (side <= 0) return;

  // Each stroke is inset by half its own width, so its outer edge lands on the
  // square's edge and nothing bleeds onto the neighbour.
  const frame = (colour, fraction) => {
    const width = side * fraction;
    ctx.strokeStyle = colour;
    ctx.lineWidth = width;
    ctx.strokeRect(
      at.x + width / 2,
      at.y + width / 2,
      side - width,
      side - width,
    );
  };

  frame('#000000', SQUARE_MARK_FRACTIONS.shade);
  frame('#FFFFFF', SQUARE_MARK_FRACTIONS.light);
  frame(drawColorOf(code), SQUARE_MARK_FRACTIONS.core);
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
  ctx.font = `${fontSize}px ${fontFamily()}`;

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
function captionBandLines(events, { resolution = '720p', maxLines = 4, captions = true } = {}) {
  // **The trainer asked for a film without the text beside the board.**
  //
  // It enters here rather than at the drawing, because a band of zero lines is
  // already the whole answer: `renderFrameBuffer` centres the board on it,
  // `fpsForCaptionBand` drops the film to one drawing a second, and
  // `renderBudget` counts the frames through the same reading. Refusing to draw
  // the caption further down would have left the other two believing in a
  // column that is not there.
  //
  // What it does **not** touch is the sentence itself. `data.text` is also the
  // script the voice reads (`services/tutorialNarration.js`) and, on a silent
  // film, what decides how long a beat holds the screen. Hiding the captions by
  // sending no text would mute the film and race it at the same time.
  if (!captions) return 0;
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

/// Frames of film a second for a caption band of [captionBand] lines: four when
/// anything is said, one when nothing is. See the frame loop for why.
function fpsForCaptionBand(captionBand) {
  return captionBand > 0 ? CAPTION_FPS : 1;
}

/// The same rule read from the events — **the one reading of it**, used by the
/// renderer and by `services/renderBudget.js`, which decides before anything is
/// drawn whether a film fits in one request. A budget with its own idea of the
/// rate would count frames the renderer does not draw.
function framesPerSecondOf(events, { resolution, captions = true } = {}) {
  return fpsForCaptionBand(captionBandLines(events, { resolution, captions }));
}

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
    // Whether this beat's board is one the film has already shown, and the
    // move that arrived at it last time. See `applyEvent`.
    rewound: false,
    rewoundAfter: null,
  };
}

/// One event applied to [state], as a new state.
///
/// Pulled out of the render loop so it can be tested without ffmpeg, and
/// because two of its rules are easy to get wrong and impossible to see in a
/// finished MP4 without watching the whole thing:
///
///   * **`init` clears the last move, unless the part continues.** A part that
///     opens on a position of its own was arrived at by nothing, and leaving
///     the previous part's move lit under it is a highlight on a board it has
///     nothing to do with. A part that opens where the previous beat already
///     stood is the opposite case: the parts join, that move *is* how this
///     board was reached, and clearing it goes dark for no reason. `join`
///     says which — written by `tutorialVideoOf`, absent in a recording,
///     where `init` happens once and there is nothing to continue from.
///   * **Marks and the sentence belong to their beat.** Every event replaces
///     them and an event that says nothing clears them, so an arrow cannot
///     outlive the position it was drawn about.
///
/// Orientation is the exception: it persists until an event says otherwise,
/// because it is a property of the part rather than of the beat.
function applyEvent(state, event) {
  const next = { ...state };
  const data = (event && event.data) || null;

  // Belongs to one beat, like the caption and the marks below it.
  next.rewound = false;
  next.rewoundAfter = null;

  if (event && event.eventType === 'init' && data && data.fen) {
    next.fen = data.fen;
    // **A part that opens where the previous beat already stood keeps the
    // last move**, because that move is how this board was arrived at: the
    // parts join and nothing moved. `join` is written by `tutorialVideoOf`;
    // absent — the recorded lesson's single `init` — means a fresh position.
    if (data.join !== 'continues') next.lastMove = null;
    if (data.join === 'returns') {
      next.rewound = true;
      next.rewoundAfter = data.afterMove || null;
    }
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

/// How much of this beat's sentence is on screen at [currentMs].
///
/// **The writing follows the voice**: it starts when the voice does and ends
/// when it does. A synthesiser's clip is padded at both ends - about an eighth
/// of a second in front and most of a second behind, measured - and until
/// 12.9.2026 this read the clip's whole length, so the sentence began before
/// the first word and was still being written after the last. The owner
/// reported it as the voice running ahead of the text.
///
/// With no voice there is nothing to follow, so it writes over three quarters
/// of the beat and holds the finished sentence for the rest.
///
/// Split out as a value a test can read, like `underBoardText` and
/// `ffmpegArgsFor`: the frame loop cannot be reached without an ffmpeg.
function captionRevealAt({
  currentMs,
  beatStartMs,
  nextBeatStartMs,
  spokenMs = 0,
  spokenStartMs = 0,
}) {
  const spoken = Number(spokenMs) || 0;
  const over = spoken > 0
    ? spoken
    : Math.max(1, (nextBeatStartMs - beatStartMs) * 0.75);
  const from = beatStartMs + (spoken > 0 ? (Number(spokenStartMs) || 0) : 0);
  return Math.min(1, Math.max(0, (currentMs - from) / over));
}

/// What the line under the board says.
///
/// **Three answers, and the third one is why this function exists.** A tutorial
/// may cut one line into several parts, and until 12.9.2026 every part boundary
/// said „Starting position" — wrong for a part that continues from the board
/// already on screen, and worse for one that jumps back to a position the
/// viewer has seen, where the picture changes and nothing says why. The
/// owner's requirement, `docs/PLAN-VRACANJE-NA-POZICIJU.md`.
///
/// Split out as a value a test can read, the way `ffmpegArgsFor` was: text
/// drawn on a canvas cannot be read back out of a pixel, so a test that only
/// looked at the frame could tell there was ink and not what it said.
function underBoardText({ lastMove, rewound = false, rewoundAfter = null }) {
  if (rewound) {
    return rewoundAfter
      ? `Back to the position after ${rewoundAfter}`
      : 'Back to a position already shown';
  }
  return lastMove && lastMove.san ? `Last move: ${lastMove.san}` : 'Starting position';
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
  // Whether this board has been shown before, and after which move — drawn on
  // the line under the board by `underBoardText`.
  rewound = false,
  rewoundAfter = null,
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
  boardTheme = 'wood',
  showTitle = true,
  showTimer = true,
  showCoords = true,
  showMoveText = true,
  // The app's own colours, when the export carried them. See `lookOf`.
  look = null,
}) {
  const skin = lookOf(look);
  const pieceImages = await preloadPieceSet(skin);
  const cfg = getResolutionParams(resolution);
  const named = getBoardColors(boardTheme);
  const colors = {
    light: skin.lightSquare || named.light,
    dark: skin.darkSquare || named.dark,
    bg: skin.background || named.bg,
  };
  // Text and the clock. A light app theme has a light background, and white
  // text on it is the one way this feature could produce a film nobody can
  // read — so the colours travel together or not at all.
  const inkColor = skin.text || '#FFFFFF';
  const accentColor = skin.accent || '#00ADB5';

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
  // **The board and its labels together.** The letters and numbers are drawn
  // outside the squares, the way `BoardWithCoordinates` draws them in the app —
  // the owner asked for it on 12.9.2026 off a still, with the studio beside the
  // film: „oznake kolona i redova su unutar table u videu, a u studiju su
  // spolja."
  //
  // So the gutter comes **out of** this footprint rather than being added to
  // it, which is what that widget does too: with the labels off the board takes
  // the whole of it back, and everything measured from the footprint — the
  // title, the clock, the caption column — stands exactly where it did.
  const footprint = Math.min(cfg.boardSize, height - cfg.offsetY - margin);
  // Scaled with the type rather than with the board: at 720p it comes out at
  // 20 px, which is the width the app's own gutter is capped at.
  const coordGutter = showCoords ? Math.round(cfg.fontSizeCoord * 1.7) : 0;
  const boardSize = footprint - coordGutter;
  const footLeft = captionColumn ? margin : (width - footprint) / 2;
  // The board itself: right of the rank numbers, above the file letters.
  const offsetX = footLeft + coordGutter;
  const offsetY = cfg.offsetY;
  const tileSize = boardSize / 8;

  // What is left of the width, less a gap on either side of it.
  const captionLeft = footLeft + footprint + margin;
  const captionWidth = Math.max(0, width - captionLeft - margin);

  const canvas = createCanvas(width, height);
  const ctx = canvas.getContext('2d');

  // Background
  ctx.fillStyle = colors.bg;
  ctx.fillRect(0, 0, width, height);

  // Top Title Bar
  if (showTitle) {
    ctx.fillStyle = inkColor;
    ctx.font = `bold ${cfg.fontSizeTitle}px ${fontFamily()}`;
    ctx.textAlign = 'left';
    ctx.textBaseline = 'middle';
    // No pawn glyph in front of it. `@napi-rs/canvas` on this server has no
    // font with U+265F in it, so every frame of every export ever rendered has
    // carried a tofu box where the pawn was meant to be — found by looking at
    // a frame, which no test here had ever done.
    ctx.fillText(`${title || 'Session recording'}`, footLeft, offsetY / 2);
  }

  // Timer & Status Badge
  if (showTimer) {
    ctx.fillStyle = accentColor;
    ctx.font = `bold ${cfg.fontSizeTimer}px ${fontFamily()}`;
    ctx.textAlign = 'right';
    // Against the right edge of whatever the frame is showing: the board when
    // that is all there is, and the caption column when there is one. Left at
    // the board's edge it would sit in the middle of the frame with the
    // sentence beside it, which reads as a label on the text rather than as the
    // film's clock.
    const timerRight = captionColumn ? captionLeft + captionWidth : footLeft + footprint;
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
      // The app's `LastMovePainter.wash`, which is black at 22% — see
      // `docs/PLAN-OZNAKE-NA-TABLI.md`. It was a yellow of its own until
      // 12.9.2026, so the film and the app disagreed about what a last move
      // looks like and neither end knew about the other.
      //
      // Drawn here, after the squares and before the pieces, which is what the
      // app now does too. The film got that right first.
      ctx.fillStyle = LAST_MOVE_WASH;
      ctx.fillRect(offsetX + c * tileSize, offsetY + r * tileSize, tileSize, tileSize);
    };
    try {
      highlightSquare(lastMove.from);
      highlightSquare(lastMove.to);
    } catch (e) {}
  }

  /// What a label at this drawing position has to be painted, which is
  /// whatever its square is not. The square's own colour is
  /// `(row + column) % 2`, the same expression the board is painted with above
  /// — flipping the board for Black flips both indices and so leaves the parity
  /// alone, which is why this needs no perspective of its own.
  const inkOn = (row, col) => ((row + col) % 2 === 0 ? colors.dark : colors.light);

  // Draw Rank/File Coordinates
  //
  // **In the gutter, not on the squares.** Until 12.9.2026 they were painted
  // inside the board, each one in the colour of the square it stood on — which
  // cost two separate bugs, a year of invisible file letters and two days of
  // invisible rank numbers, because the bottom row and the left column start on
  // opposite colours and one hand-written parity cannot serve both. Outside the
  // board there is one background and no parity to get wrong, and the film
  // matches the studio, which is what the owner asked for.
  if (showCoords) {
    ctx.font = `bold ${cfg.fontSizeCoord}px ${fontFamily()}`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = inkColor;
    // The app draws them at 70 % of the body colour: present, and not
    // competing with the pieces, which are the thing to look at.
    const wasAlpha = ctx.globalAlpha;
    ctx.globalAlpha = 0.7;
    for (let i = 0; i < 8; i++) {
      const fileLabel = isBlackPerspective ? String.fromCharCode(104 - i) : String.fromCharCode(97 + i);
      const rankLabel = isBlackPerspective ? (i + 1).toString() : (8 - i).toString();

      // Each label centred on its own rank or file, so a flipped board needs no
      // second rule: flipping renames the labels and moves nothing.
      ctx.fillText(rankLabel, footLeft + coordGutter / 2, offsetY + (i + 0.5) * tileSize);
      ctx.fillText(fileLabel, offsetX + (i + 0.5) * tileSize, offsetY + boardSize + coordGutter / 2);
    }
    ctx.globalAlpha = wasAlpha;
    // Left as this block has always left it: the line under the board is drawn
    // next and reads the baseline without setting one.
    ctx.textBaseline = 'alphabetic';
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
    ctx.fillStyle = inkColor;
    ctx.font = `${cfg.fontSizeMove}px ${fontFamily()}`;
    ctx.textAlign = 'center';
    const moveText = underBoardText({ lastMove, rewound, rewoundAfter });
    // Below the file letters when there are any, and exactly where it has
    // always been when there are none.
    ctx.fillText(moveText, width / 2,
      offsetY + boardSize + coordGutter + cfg.fontSizeMove + 15);
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

    ctx.fillStyle = inkColor;
    ctx.font = `${cfg.fontSizeCaption}px ${fontFamily()}`;
    ctx.textAlign = 'left';
    ctx.textBaseline = 'top';
    shown.forEach((line, i) => {
      if (line) ctx.fillText(line, captionLeft, top + i * lineHeight);
    });
  }

  return canvas.toBuffer('image/png');
}

/// A progress callback that speaks every ten per cent, and on the last frame.
///
/// „Nek šalje na svakih 10 procenata osvežavanje". A three-minute film at 4 fps
/// is 720 frames, and reporting every one of them writes 720 entries to move a
/// bar that changes ten times: the client polls every 900 ms and can only draw
/// what it happens to catch. The last frame is always reported, because that is
/// the 99 the bar rests on while ffmpeg finishes writing the file.
function tenPercentReporter(onProgress, total) {
  if (typeof onProgress !== 'function' || !(total > 0)) return () => {};
  let reported = -1;
  return (drawn) => {
    const tenth = Math.floor((drawn / total) * 10);
    if (tenth === reported && drawn !== total) return;
    reported = tenth;
    onProgress(drawn, total);
  };
}

async function renderRecordingToMP4({
  title,
  timelineEvents,
  audioFilePath,
  durationSeconds,
  perspective,
  resolution = '720p',
  boardTheme = 'wood',
  showTitle = true,
  showTimer = true,
  showCoords = true,
  showMoveText = true,
  /// Whether the sentences are written beside the board. Off gives the centred
  /// board the recorded-lesson export has always used, and the voice still
  /// reads: the text travels either way.
  captions = true,
  look = null,
  /// Called with (drawn, total) after every frame, for whoever is waiting.
  onProgress = null,
  /// Fires when the client that asked for this film has gone. See
  /// `services/renderAbort.js`: the drawing stops, ffmpeg is killed, the
  /// half-written file is removed, and the queue slot goes to the next trainer
  /// instead of being held for a film nobody will collect.
  signal = null,
  outputPath
}) {
  return new Promise(async (resolve, reject) => {
    // Before anything is spawned or preloaded. A render that waited its turn
    // behind two others is the one whose client is likeliest to have given up.
    if (signal && signal.aborted) return reject(new RenderAborted());

    const totalDuration = Math.max(3, Math.min(3600, Math.ceil(durationSeconds || 10)));
    const events = Array.isArray(timelineEvents) ? timelineEvents : [];

    // Whether any beat says anything **and the trainer asked for it to be
    // written**, which decides the layout and the rate together.
    //
    // Read once, here, and used both by the drawing and by the rate ffmpeg is
    // told about. It was read twice — once for each — and the second reading
    // could be made to disagree with the first by a mutation no test could
    // catch, because the only thing that can see this path is a real render
    // with a real ffmpeg. One reading cannot disagree with itself.
    const captionBand = captionBandLines(events, { resolution, captions });

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
    // A film with no captions is drawn once a second, exactly as a wordless one
    // always was — which is most of why hiding them is worth offering.
    const fps = fpsForCaptionBand(captionBand);

    console.log(`[VIDEO_RENDER] Rendering ${resolution} MP4 (${boardTheme}): ${totalDuration}s, ${events.length} events, audio: ${audioFilePath}`);

    // Preload the pieces, in the skin this film was asked for.
    await preloadPieceSet(lookOf(look));

    const hasAudio = audioFilePath && fs.existsSync(audioFilePath);
    const ffmpeg = spawn('ffmpeg', ffmpegArgsFor({
      audioFilePath: hasAudio ? audioFilePath : null,
      outputPath,
      inputFps: fps,
    }));

    // **Killed, not asked.** ffmpeg told to stop politely finishes writing the
    // file it was given, which is the file this exists not to leave behind.
    const stopKilling = killOnAbort(ffmpeg, signal);
    let aborted = false;
    const onAbort = () => { aborted = true; };
    if (signal) signal.addEventListener('abort', onAbort, { once: true });

    ffmpeg.stderr.on('data', (data) => {
      // Quiet stderr
    });

    // A killed ffmpeg closes its stdin under the loop, and the write that lands
    // in the gap — the abort arrives while `renderFrameBuffer` is awaiting, and
    // the next statement is a write — raises EPIPE on a stream. An `error` on a
    // stream with no listener is an uncaught exception, which takes the whole
    // server down, so this one line is the difference between an abandoned
    // render and a crash.
    //
    // **Not proved by mutation, and that is stated rather than hidden.**
    // `render_abort.test.js` fakes ffmpeg, and a fake pipe cannot break the way
    // a real one does; removing this line leaves the suite green. It stays
    // because the risk is asymmetric — an unreachable guard costs a line, and
    // its absence costs the process.
    ffmpeg.stdin.on('error', () => {});

    ffmpeg.on('close', (code) => {
      stopKilling();
      if (signal) signal.removeEventListener('abort', onAbort);
      if (aborted) {
        // Half a film is not a film. Removed here rather than by the caller,
        // because this is the only place that knows ffmpeg has let go of it.
        removePartial(outputPath);
        console.log('[VIDEO_RENDER] Aborted: the render was cancelled, partial file removed');
        return reject(new RenderAborted());
      }
      if (code === 0) {
        console.log(`[VIDEO_RENDER] Success! Custom MP4 saved to ${outputPath}`);
        resolve(outputPath);
      } else {
        reject(new Error(`FFmpeg exited with code ${code}`));
      }
    });

    ffmpeg.on('error', (err) => {
      stopKilling();
      if (signal) signal.removeEventListener('abort', onAbort);
      if (aborted) {
        removePartial(outputPath);
        return reject(new RenderAborted());
      }
      reject(err);
    });

    const frames = totalDuration * fps;

    let state = initialFrameState();
    let eventIdx = 0;
    const report = tenPercentReporter(onProgress, frames + 1);
    // When the sentence now on screen started being spoken, and for how long.
    let captionStartMs = 0;
    let captionSpokenMs = 0;
    // How far into the beat the voice begins. A synthesiser's clip opens with
    // silence, and writing through it made the caption run ahead of the voice
    // from the first word.
    let captionSpokenFromMs = 0;

    for (let frame = 0; frame <= frames; frame++) {
      // The client left while the previous frame was being drawn. Stop here:
      // ffmpeg has already been killed by `killOnAbort`, and its `close`
      // handler removes the file and settles this promise.
      if (aborted) return;

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
        captionSpokenFromMs = Number(event.data?.spokenStartMs) || 0;
        eventIdx++;
      }

      const nextStart = eventIdx < events.length
        ? (events[eventIdx].timestampMs || 0)
        : totalDuration * 1000;
      const captionReveal = captionRevealAt({
        currentMs,
        beatStartMs: captionStartMs,
        nextBeatStartMs: nextStart,
        spokenMs: captionSpokenMs,
        spokenStartMs: captionSpokenFromMs,
      });

      const frameBuf = await renderFrameBuffer({
        title,
        fen: state.fen,
        perspective: perspective || 'trainer',
        orientation: state.orientation,
        lastMove: state.lastMove,
        rewound: state.rewound,
        rewoundAfter: state.rewoundAfter,
        caption: state.caption,
        arrows: state.arrows,
        squares: state.squares,
        captionBand,
        captionReveal,
        timestampSec: sec,
        totalDurationSec: totalDuration,
        resolution,
        boardTheme,
        showTitle,
        showTimer,
        showCoords,
        showMoveText,
        look
      });

      // Written even when the abort landed inside `renderFrameBuffer` above:
      // ffmpeg is already dead by then and this is the EPIPE the `stdin` error
      // handler swallows. **A second guard here was deleted rather than kept**
      // — with two checks in the loop neither one could be proved, because
      // removing either left the other stopping the render, and a check no
      // mutation can reach is a check nobody knows is working. One check, at
      // the top of the loop, one frame of overshoot.
      ffmpeg.stdin.write(frameBuf);
      // After the write rather than before it: the number means „drawn", and a
      // bar that counts frames it has not drawn yet is the same lie as a
      // progress dialog that reaches 100 % and then waits.
      report(frame + 1);

      // **Back to the event loop between frames.** Everything above is
      // synchronous — `canvas.toBuffer` draws the PNG on this thread and the
      // piece set is cached after the first frame — so every `await` in the
      // loop settles in a microtask and the whole render is one uninterrupted
      // burst. Nothing else in this process is served for its duration: the
      // progress poll the app makes while its own export request is in flight
      // sits in the queue until the film is finished, and the bar it draws says
      // „Starting…" until the video is ready. Reported live, and the number was
      // being written correctly the whole time — nobody could read it.
      //
      // `setImmediate` is the check phase, which comes after poll, so an
      // arriving request is handled before the next frame is drawn. Its cost is
      // one loop turn per frame.
      await new Promise(setImmediate);
    }

    ffmpeg.stdin.end();
  });
}

/// One frame of the film that has not been rendered, drawn as a still.
///
/// **So a trainer can see what a film will look like without making one.** An
/// export takes tens of seconds of a queue slot and, before this, the only way
/// to find out that the board skin was wrong, or that the sentence is too long
/// for the caption band, or that the part is standing the wrong way round, was
/// to render the whole thing and watch it.
///
/// It is the film's own drawing and not a second one: the same `applyEvent`
/// fold the loop uses, the same `renderFrameBuffer`, the same caption band
/// measured over the same events. Nothing here spawns anything — no ffmpeg, no
/// queue slot, no file — so a preview costs one frame's drawing and nothing
/// else.
///
/// The sentence is drawn **whole** (`captionReveal: 1`). In the film it arrives
/// at the speed it is read; a still is a question about layout, and half a
/// sentence would answer it wrongly.
async function renderPreviewFrame({
  title,
  timelineEvents,
  beatIndex = 0,
  durationSeconds,
  perspective,
  resolution = '720p',
  boardTheme = 'wood',
  showTitle = true,
  showTimer = true,
  showCoords = true,
  showMoveText = false,
  captions = true,
  look = null,
}) {
  const events = Array.isArray(timelineEvents) ? timelineEvents : [];
  if (events.length === 0) throw new Error('a preview needs at least one event');

  const at = Math.max(0, Math.min(beatIndex, events.length - 1));
  const totalDuration = Math.max(3, Math.min(3600, Math.ceil(durationSeconds || 10)));

  await preloadPieceSet(lookOf(look));

  let state = initialFrameState();
  for (let i = 0; i <= at; i++) state = applyEvent(state, events[i]);

  return renderFrameBuffer({
    title,
    fen: state.fen,
    perspective: perspective || 'trainer',
    orientation: state.orientation,
    lastMove: state.lastMove,
    rewound: state.rewound,
    rewoundAfter: state.rewoundAfter,
    caption: state.caption,
    arrows: state.arrows,
    squares: state.squares,
    // Measured over **every** event, not over this one. `renderFrameBuffer`
    // reads this as „does this film speak at all" (`captionBand > 0`), and a
    // film that speaks is laid out with the caption column beside a smaller
    // board — so a wordless beat inside a talking tutorial must be previewed
    // with the column, or the preview shows a layout the film will never have.
    captionBand: captionBandLines(events, { resolution, captions }),
    captionReveal: 1,
    timestampSec: Math.floor((events[at].timestampMs || 0) / 1000),
    totalDurationSec: totalDuration,
    resolution,
    boardTheme,
    showTitle,
    showTimer,
    showCoords,
    showMoveText,
    look,
  });
}

/// Which beats to show when nobody says: the opening, the middle, the end.
///
/// Three, because they are the three questions a trainer has — how the film
/// opens, what an ordinary beat looks like with its sentence and its arrows,
/// and where it leaves the child. Fewer for a film with fewer beats, and never
/// the same beat twice.
function previewBeatIndexes(beatCount, wanted = 3) {
  if (beatCount <= 0) return [];
  const picks = new Set([0]);
  if (wanted >= 3 && beatCount > 2) picks.add(Math.floor((beatCount - 1) / 2));
  if (wanted >= 2 && beatCount > 1) picks.add(beatCount - 1);
  return [...picks].sort((a, b) => a - b).slice(0, wanted);
}

module.exports = {
  renderFrameBuffer,
  renderRecordingToMP4,
  renderPreviewFrame,
  previewBeatIndexes,
  // Exported for the tests, which read pixels out of a rendered frame: a
  // drawing that cannot be measured is a drawing nobody can grade.
  captionLines,
  revealedLines,
  captionBandLines,
  framesPerSecondOf,
  ffmpegArgsFor,
  underBoardText,
  captionRevealAt,
  OUTPUT_FPS,
  CAPTION_FPS,
  drawColorOf,
  // Both read by `test/square_mark_frame.test.js`, which compares them with
  // the app's own constants rather than with a comment claiming they match.
  SQUARE_MARK_FRACTIONS,
  LAST_MOVE_WASH,
  getResolutionParams,
  lookOf,
  recolouredPieces,
  tenPercentReporter,
  applyEvent,
  initialFrameState
};
