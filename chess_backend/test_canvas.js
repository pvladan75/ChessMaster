const { createCanvas } = require('@napi-rs/canvas');
const path = require('path');
const { spawn } = require('child_process');

const width = 1280;
const height = 720;
const canvas = createCanvas(width, height);
const ctx = canvas.getContext('2d');

ctx.fillStyle = '#1E1E2E';
ctx.fillRect(0, 0, width, height);

ctx.fillStyle = '#FFFFFF';
ctx.font = 'bold 28px sans-serif';
ctx.fillText('Snimak Časa - Chess Master', 40, 50);

const boardSize = 560;
const offsetX = (width - boardSize) / 2;
const offsetY = 90;
const tileSize = boardSize / 8;

for (let r = 0; r < 8; r++) {
  for (let c = 0; c < 8; c++) {
    const isLight = (r + c) % 2 === 0;
    ctx.fillStyle = isLight ? '#F0D9B5' : '#B58863';
    ctx.fillRect(offsetX + c * tileSize, offsetY + r * tileSize, tileSize, tileSize);
  }
}

const pieces = {
  'r': '♜', 'n': '♞', 'b': '♝', 'q': '♛', 'k': '♚', 'p': '♟',
  'R': '♖', 'N': '♘', 'B': '♗', 'Q': '♕', 'K': '♔', 'P': '♙'
};

const fen = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 1';
let r = 0, c = 0;
for (let i = 0; i < fen.length; i++) {
  const char = fen[i];
  if (char === ' ') break;
  if (char === '/') {
    r++;
    c = 0;
  } else if (!isNaN(parseInt(char))) {
    c += parseInt(char);
  } else {
    const symbol = pieces[char] || char;
    ctx.fillStyle = char === char.toUpperCase() ? '#FFFFFF' : '#000000';
    ctx.font = '48px sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(symbol, offsetX + c * tileSize + tileSize / 2, offsetY + r * tileSize + tileSize / 2);
    c++;
  }
}

const frameBuf = canvas.toBuffer('image/png');
console.log('PNG Buffer length:', frameBuf.length);

const outPath = path.join(__dirname, 'exports', 'test_canvas_out.mp4');
const exportsDir = path.join(__dirname, 'exports');
if (!require('fs').existsSync(exportsDir)) require('fs').mkdirSync(exportsDir);

const ffmpeg = spawn('ffmpeg', [
  '-y',
  '-f', 'image2pipe',
  '-vcodec', 'png',
  '-framerate', '1',
  '-i', 'pipe:0',
  '-c:v', 'libx264',
  '-pix_fmt', 'yuv420p',
  outPath
]);

ffmpeg.stdin.write(frameBuf);
ffmpeg.stdin.write(frameBuf);
ffmpeg.stdin.end();

ffmpeg.on('close', (code) => {
  console.log('FFmpeg image2pipe finished with exit code:', code);
});
