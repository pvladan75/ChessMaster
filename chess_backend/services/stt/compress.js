// stt/compress.js — a recording made small enough to send, in a child process.
//
// A lesson is kept as 16 kHz mono 16-bit wav: a 30-minute take is 57.6 MB,
// and Groq takes 25. As Ogg Opus at 32 kbit/s it is about 7 MB, and on the
// owner's corrected „proba 4" Groq heard exactly as much of it as of the
// lossless FLAC — 2 of 185 words wrong either way, at 527 KB against 1.92 MB
// (27.9.2026, one recording). So there is one format and no second path for a
// take that would not fit.
//
// **The original is only read.** ffmpeg opens it as its input and writes the
// Opus to its own standard output; nothing is written beside the recording,
// and nothing needs cleaning up after it. `uploads/` is the one store here
// that cannot be reproduced.
//
// A child process rather than a library: native work that crashes must crash
// its own process, never the server's (CLAUDE.md, phase 3h of
// docs/PLAN-SKENER-SLIKE.md).

const { spawn } = require('child_process');

/// More than any 30-minute take can be as Opus at 32 kbit/s (7.2 MB), and
/// under the vendor's 25 MB: a larger output means the input was not what the
/// route thinks it is, and it is stopped rather than sent.
const MAX_OUTPUT_BYTES = 24 * 1024 * 1024;

const ARGS = ['-ac', '1', '-ar', '16000', '-c:a', 'libopus', '-b:a', '32k',
  '-application', 'voip', '-f', 'ogg'];

class CompressFailed extends Error {
  constructor(message) {
    super(message);
    this.name = 'CompressFailed';
  }
}

/// The recording at [file] as Ogg Opus, in a Buffer.
function compressForSpeech(file, {
  ffmpeg = process.env.FFMPEG_PATH || 'ffmpeg',
  maxBytes = MAX_OUTPUT_BYTES,
  spawnImpl = spawn,
} = {}) {
  return new Promise((resolve, reject) => {
    let proc;
    try {
      proc = spawnImpl(ffmpeg, ['-hide_banner', '-loglevel', 'error', '-nostdin', '-i', file, ...ARGS, 'pipe:1'],
        { stdio: ['ignore', 'pipe', 'pipe'] });
    } catch (err) {
      reject(new CompressFailed(`ffmpeg could not be started: ${err.message}`));
      return;
    }
    const chunks = [];
    let size = 0;
    let stderr = '';
    let over = false;
    proc.stdout.on('data', (chunk) => {
      size += chunk.length;
      if (size > maxBytes) {
        over = true;
        proc.kill('SIGKILL');
        return;
      }
      chunks.push(chunk);
    });
    proc.stderr.on('data', (d) => { stderr = (stderr + d).slice(-400); });
    proc.on('error', (err) => reject(new CompressFailed(`ffmpeg could not be started: ${err.message}`)));
    proc.on('close', (code) => {
      if (over) return reject(new CompressFailed(`the compressed recording passed ${maxBytes} bytes`));
      if (code !== 0) return reject(new CompressFailed(`ffmpeg exited ${code}: ${stderr.trim()}`));
      if (size === 0) return reject(new CompressFailed('ffmpeg wrote nothing'));
      return resolve(Buffer.concat(chunks));
    });
  });
}

module.exports = { compressForSpeech, CompressFailed, MAX_OUTPUT_BYTES, ARGS };
