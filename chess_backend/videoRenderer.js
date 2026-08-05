const { createCanvas, loadImage } = require('@napi-rs/canvas');
const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');
const { alphaPieceSvgs } = require('./pieceThemes');

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

async function preloadPieceSet(style = 'alpha') {
  if (loadedPieceSets[style]) return loadedPieceSets[style];
  const dict = style === 'staunton' ? stauntonPieceSvgs : alphaPieceSvgs;
  const loaded = {};
  for (const [key, svg] of Object.entries(dict)) {
    loaded[key] = await loadImage(Buffer.from(svg));
  }
  loadedPieceSets[style] = loaded;
  return loaded;
}

function getBoardColors(themeStr) {
  switch (themeStr) {
    case 'green':
      return { light: '#EEEED2', dark: '#769656', bg: '#1B281B' };
    case 'blue':
      return { light: '#EAE9D2', dark: '#4B7399', bg: '#141E28' };
    case 'wood':
    default:
      return { light: '#F0D9B5', dark: '#B58863', bg: '#1E1E2E' };
  }
}

function getResolutionParams(resolutionStr) {
  switch (resolutionStr) {
    case '1080p':
      return { width: 1920, height: 1080, boardSize: 840, offsetY: 120, fontSizeTitle: 32, fontSizeTimer: 26, fontSizeCoord: 18, fontSizeMove: 24 };
    case '480p':
      return { width: 854, height: 480, boardSize: 360, offsetY: 55, fontSizeTitle: 16, fontSizeTimer: 14, fontSizeCoord: 10, fontSizeMove: 14 };
    case '720p':
    default:
      return { width: 1280, height: 720, boardSize: 560, offsetY: 90, fontSizeTitle: 24, fontSizeTimer: 20, fontSizeCoord: 12, fontSizeMove: 16 };
  }
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
  lastMove,
  timestampSec,
  totalDurationSec,
  resolution = '720p',
  pieceStyle = 'alpha',
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
  const boardSize = cfg.boardSize;
  const offsetX = (width - boardSize) / 2;
  const offsetY = cfg.offsetY;
  const tileSize = boardSize / 8;

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
    ctx.fillText(`♟ ${title || 'Snimak Časa - Chess Master'}`, offsetX, offsetY / 2);
  }

  // Timer & Status Badge
  if (showTimer) {
    ctx.fillStyle = '#00ADB5';
    ctx.font = `bold ${cfg.fontSizeTimer}px sans-serif`;
    ctx.textAlign = 'right';
    ctx.fillText(`${formatTime(timestampSec)} / ${formatTime(totalDurationSec)}`, offsetX + boardSize, offsetY / 2);
  }

  // Draw 8x8 Board
  const isBlackPerspective = perspective === 'student';
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
    for (let i = 0; i < 8; i++) {
      const fileLabel = isBlackPerspective ? String.fromCharCode(104 - i) : String.fromCharCode(97 + i);
      const rankLabel = isBlackPerspective ? (i + 1).toString() : (8 - i).toString();

      // Files at bottom
      ctx.fillStyle = i % 2 === 0 ? colors.dark : colors.light;
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

  // Footer Move Text
  if (showMoveText) {
    ctx.fillStyle = '#EEEEEE';
    ctx.font = `${cfg.fontSizeMove}px sans-serif`;
    ctx.textAlign = 'center';
    const moveText = lastMove && lastMove.san ? `Zadnji potez: ${lastMove.san}` : 'Početna pozicija';
    ctx.fillText(moveText, width / 2, offsetY + boardSize + cfg.fontSizeMove + 15);
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
  pieceStyle = 'alpha',
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

    // Build FFmpeg args
    const ffmpegArgs = [
      '-y',
      '-f', 'image2pipe',
      '-vcodec', 'png',
      '-framerate', '1',
      '-i', 'pipe:0'
    ];

    const hasAudio = audioFilePath && fs.existsSync(audioFilePath);
    if (hasAudio) {
      ffmpegArgs.push('-i', audioFilePath, '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '192k', '-shortest', outputPath);
    } else {
      ffmpegArgs.push('-f', 'lavfi', '-i', 'anullsrc=r=44100:cl=stereo', '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-shortest', outputPath);
    }

    const ffmpeg = spawn('ffmpeg', ffmpegArgs);

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

    // Write 1 frame per second to pipe:0
    let currentFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    let lastMove = null;
    let eventIdx = 0;

    for (let sec = 0; sec <= totalDuration; sec++) {
      const currentMs = sec * 1000;

      while (eventIdx < events.length && (events[eventIdx].timestampMs || 0) <= currentMs) {
        const ev = events[eventIdx];
        if (ev.eventType === 'init' && ev.data && ev.data.fen) {
          currentFen = ev.data.fen;
        } else if (ev.eventType === 'move' && ev.data) {
          if (ev.data.fen) currentFen = ev.data.fen;
          lastMove = { from: ev.data.from, to: ev.data.to, san: ev.data.san };
        }
        eventIdx++;
      }

      const frameBuf = await renderFrameBuffer({
        title,
        fen: currentFen,
        perspective: perspective || 'trainer',
        lastMove,
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
  renderRecordingToMP4
};
