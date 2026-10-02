// lib.js — the pure parts of the speech-clip tool: render a token through the
// backend's own Azure provider, trim a clip to the speech floor `wav.js`
// defines, and stitch trimmed clips into one RIFF/WAVE buffer.
//
// Run by hand from the repository root, never by the app or the server:
//
//   node tools/speech_clips/phase0.js
//
// It requires the backend's modules the way `tools/status/status.js` does, so
// the provider, the output format (22050 Hz, 16-bit, mono) and the definition
// of silence are the server's and not a second copy. The key and region come
// from `chess_backend/.env`; nothing here is metered to an account, because a
// build step is the owner's own cost and not a trainer's.
//
// Plan: `docs/PLAN-GOVOR-IZ-KLIPOVA.md`.
'use strict';

const fs = require('fs');
const path = require('path');
const { createRequire } = require('module');

const BACKEND = path.resolve(__dirname, '..', '..', 'chess_backend');
const backendRequire = createRequire(path.join(BACKEND, 'package.json'));
backendRequire('dotenv').config({ path: path.join(BACKEND, '.env') });

const azure = backendRequire('./services/tts/azure.js');
const wav = backendRequire('./services/tts/wav.js');

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/// One clip through Azure, with a short retry: 429 is the free tier's
/// concurrency, and a second try a moment later is what it asks for.
async function renderOne({ said, voice, outputPath }, { retries = 3 } = {}) {
  for (let attempt = 1; ; attempt++) {
    try {
      await azure.synthesize({ text: said, voice, outputPath });
      return;
    } catch (err) {
      if (attempt >= retries) throw err;
      await sleep(1500 * attempt);
    }
  }
}

/// Renders every job whose `outputPath` does not exist yet, a few at a time.
/// Returns how many were rendered and how many characters Azure was sent.
async function renderAll(jobs, { concurrency = 3, log = () => {} } = {}) {
  const pending = jobs.filter((job) => !fs.existsSync(job.outputPath));
  let rendered = 0;
  let characters = 0;
  let next = 0;
  async function worker() {
    while (next < pending.length) {
      const job = pending[next++];
      fs.mkdirSync(path.dirname(job.outputPath), { recursive: true });
      await renderOne(job);
      rendered++;
      characters += job.said.length;
      log(`${rendered}/${pending.length} ${path.basename(job.outputPath)}`);
    }
  }
  await Promise.all(Array.from({ length: Math.min(concurrency, pending.length) }, worker));
  return { rendered, skipped: jobs.length - pending.length, characters };
}

/// The format and the raw PCM of a wav, read through the server's reader.
function readPcm(file) {
  const info = wav.wavInfo(file);
  if (!info) throw new Error(`not a readable wav: ${file}`);
  if (info.audioFormat !== 1 || info.bitsPerSample !== 16) {
    throw new Error(`not 16-bit PCM: ${file}`);
  }
  const buf = fs.readFileSync(file);
  return { info, pcm: buf.subarray(info.dataOffset, info.dataOffset + info.dataBytes) };
}

/// The clip cut to where `speechWindow` says the voice is, with a margin of
/// [marginMs] on each side so a soft consonant at the edge of a block is not
/// lost. A clip with no block above the floor is returned whole.
function trimmed(file, { marginMs = 10 } = {}) {
  const { info, pcm } = readPcm(file);
  const frameBytes = 2 * info.channels;
  const frames = Math.floor(pcm.length / frameBytes);
  const window = wav.speechWindow(file);
  if (!window) return { info, pcm, cutStartMs: 0, cutEndMs: 0, seconds: frames / info.sampleRate };
  const margin = Math.round((marginMs / 1000) * info.sampleRate);
  const start = Math.max(0, Math.round(window.startSeconds * info.sampleRate) - margin);
  const end = Math.min(frames, Math.round(window.endSeconds * info.sampleRate) + margin);
  return {
    info,
    pcm: pcm.subarray(start * frameBytes, end * frameBytes),
    cutStartMs: (start / info.sampleRate) * 1000,
    cutEndMs: ((frames - end) / info.sampleRate) * 1000,
    seconds: (end - start) / info.sampleRate,
  };
}

function sameFormat(a, b) {
  return a.sampleRate === b.sampleRate && a.channels === b.channels
    && a.bitsPerSample === b.bitsPerSample;
}

function silence(ms, info) {
  const frames = Math.round((ms / 1000) * info.sampleRate);
  return Buffer.alloc(frames * 2 * info.channels);
}

/// The canonical 44-byte header in front of [pcm].
function riff(pcm, info) {
  const header = Buffer.alloc(44);
  const blockAlign = 2 * info.channels;
  header.write('RIFF', 0, 'ascii');
  header.writeUInt32LE(36 + pcm.length, 4);
  header.write('WAVE', 8, 'ascii');
  header.write('fmt ', 12, 'ascii');
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(info.channels, 22);
  header.writeUInt32LE(info.sampleRate, 24);
  header.writeUInt32LE(info.sampleRate * blockAlign, 28);
  header.writeUInt16LE(blockAlign, 32);
  header.writeUInt16LE(16, 34);
  header.write('data', 36, 'ascii');
  header.writeUInt32LE(pcm.length, 40);
  return Buffer.concat([header, pcm]);
}

/// [clips] joined with [pauseMs] of silence between each pair, as one wav.
/// Every clip must share the first one's format; a mismatch is refused, not
/// resampled — the tool renders them all at one format on purpose.
function stitch(clips, { pauseMs }) {
  if (clips.length === 0) throw new Error('nothing to stitch');
  const info = clips[0].info;
  const parts = [];
  clips.forEach((clip, i) => {
    if (!sameFormat(clip.info, info)) {
      throw new Error(`clip ${i} is ${clip.info.sampleRate} Hz / ${clip.info.channels} ch, the first is ${info.sampleRate} / ${info.channels}`);
    }
    if (i > 0) parts.push(silence(pauseMs, info));
    parts.push(clip.pcm);
  });
  return riff(Buffer.concat(parts), info);
}

module.exports = { azure, wav, renderAll, readPcm, trimmed, stitch, silence, riff, sameFormat };
