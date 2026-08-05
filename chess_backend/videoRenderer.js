const { createCanvas } = require('@napi-rs/canvas');
const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');

const width = 1280;
const height = 720;
const boardSize = 560;
const offsetX = (width - boardSize) / 2; // 360
const offsetY = 90;
const tileSize = boardSize / 8; // 70

const pieceSymbols = {
  'r': '♜', 'n': '♞', 'b': '♝', 'q': '♛', 'k': '♚', 'p': '♟',
  'R': '♖', 'N': '♘', 'B': '♗', 'Q': '♕', 'K': '♔', 'P': '♙'
};

function formatTime(sec) {
  const m = Math.floor(sec / 60).toString().padStart(2, '0');
  const s = Math.floor(sec % 60).toString().padStart(2, '0');
  return `${m}:${s}`;
}

function renderFrameBuffer({ title, fen, perspective, lastMove, timestampSec, totalDurationSec }) {
  const canvas = createCanvas(width, height);
  const ctx = canvas.getContext('2d');

  // Background
  ctx.fillStyle = '#1E1E2E';
  ctx.fillRect(0, 0, width, height);

  // Top Title Bar
  ctx.fillStyle = '#FFFFFF';
  ctx.font = 'bold 24px sans-serif';
  ctx.textAlign = 'left';
  ctx.textBaseline = 'middle';
  ctx.fillText(`♟ ${title || 'Snimak Časa - Chess Master'}`, 40, 45);

  // Timer & Status Badge
  ctx.fillStyle = '#00ADB5';
  ctx.font = 'bold 20px sans-serif';
  ctx.textAlign = 'right';
  ctx.fillText(`${formatTime(timestampSec)} / ${formatTime(totalDurationSec)}`, width - 40, 45);

  // Draw 8x8 Board
  const isBlackPerspective = perspective === 'student';
  for (let r = 0; r < 8; r++) {
    for (let c = 0; c < 8; c++) {
      const displayR = isBlackPerspective ? 7 - r : r;
      const displayC = isBlackPerspective ? 7 - c : c;

      const isLight = (displayR + displayC) % 2 === 0;
      ctx.fillStyle = isLight ? '#F0D9B5' : '#B58863';
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
  ctx.font = 'bold 12px sans-serif';
  for (let i = 0; i < 8; i++) {
    const fileLabel = isBlackPerspective ? String.fromCharCode(104 - i) : String.fromCharCode(97 + i);
    const rankLabel = isBlackPerspective ? (i + 1).toString() : (8 - i).toString();

    // Files at bottom
    ctx.fillStyle = i % 2 === 0 ? '#B58863' : '#F0D9B5';
    ctx.textAlign = 'right';
    ctx.fillText(fileLabel, offsetX + (i + 1) * tileSize - 4, offsetY + boardSize - 4);

    // Ranks at left
    ctx.textAlign = 'left';
    ctx.fillText(rankLabel, offsetX + 4, offsetY + i * tileSize + 14);
  }

  // Render Pieces from FEN
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

      const symbol = pieceSymbols[char] || char;
      const isWhitePiece = char === char.toUpperCase();

      // Shadow
      ctx.fillStyle = 'rgba(0,0,0,0.3)';
      ctx.font = '48px sans-serif';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(symbol, offsetX + displayC * tileSize + tileSize / 2 + 2, offsetY + displayR * tileSize + tileSize / 2 + 2);

      // Main Piece Symbol
      ctx.fillStyle = isWhitePiece ? '#FFFFFF' : '#111111';
      ctx.fillText(symbol, offsetX + displayC * tileSize + tileSize / 2, offsetY + displayR * tileSize + tileSize / 2);

      c++;
    }
  }

  // Footer Notation
  ctx.fillStyle = '#EEEEEE';
  ctx.font = '16px sans-serif';
  ctx.textAlign = 'center';
  const moveText = lastMove && lastMove.san ? `Zadnji potez: ${lastMove.san}` : 'Početna pozicija';
  ctx.fillText(moveText, width / 2, offsetY + boardSize + 35);

  return canvas.toBuffer('image/png');
}

async function renderRecordingToMP4({ title, timelineEvents, audioFilePath, durationSeconds, perspective, outputPath }) {
  return new Promise((resolve, reject) => {
    const totalDuration = Math.max(3, Math.min(3600, Math.ceil(durationSeconds || 10)));
    const events = Array.isArray(timelineEvents) ? timelineEvents : [];

    console.log(`[VIDEO_RENDER] Rendering MP4: ${totalDuration}s, ${events.length} events, audio: ${audioFilePath}`);

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
      // Log FFmpeg progress quietly
    });

    ffmpeg.on('close', (code) => {
      if (code === 0) {
        console.log(`[VIDEO_RENDER] Success! Video saved to ${outputPath}`);
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

      // Advance events up to currentMs
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

      const frameBuf = renderFrameBuffer({
        title,
        fen: currentFen,
        perspective: perspective || 'trainer',
        lastMove,
        timestampSec: sec,
        totalDurationSec: totalDuration
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
