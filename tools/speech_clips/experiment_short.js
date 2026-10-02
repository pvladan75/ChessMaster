// experiment_short.js — phase 0b again, with the owner's shorter wording:
// „rook d5" instead of „rook from d2 to d5". Same method as
// `experiment_cut.js`: every fragment cut out of a carrier of the same shape
// at the SDK's word times.
//
//   node tools/speech_clips/experiment_short.js [voice] [pauseBeforeSquareMs]
'use strict';

const fs = require('fs');
const path = require('path');
const { renderAll, readPcm, riff, silence, wav } = require('./lib.js');
const { renderWithWords } = require('./sdk_render.js');

const VOICE = process.argv[2] || 'en-US-AvaNeural';
const PAUSE_MS = Number(process.argv[3] || 0);
const OUT = path.join(__dirname, 'out', 'exp-short', VOICE);
const LISTEN = path.join(__dirname, 'out', 'listen');

const CARRIERS = [
  { id: 'frame', text: 'Black plays bishop e5.', take: { black_plays: [1, 2] } },
  { id: 'white', text: 'White plays bishop e5.', take: { white_plays: [1, 2] } },
  { id: 'p_knight', text: 'Black plays knight e5.', take: { knight: [3, 3] } },
  { id: 'p_rook', text: 'Black plays rook e5.', take: { rook: [3, 3] } },
  { id: 'p_queen', text: 'Black plays queen e5.', take: { queen: [3, 3] } },
  { id: 'sq_d7', text: 'Black plays bishop d7.', take: { sq_d7: [4, 4] } },
  { id: 'sq_a8', text: 'Black plays bishop a8.', take: { sq_a8: [4, 4] } },
  { id: 'sq_e8', text: 'Black plays bishop e8.', take: { sq_e8: [4, 4] } },
  { id: 'takes', text: 'Black plays bishop takes e5.', take: { takes: [4, 4] } },
  { id: 'tsq_e8', text: 'Black plays bishop takes e8.', take: { tsq_e8: [5, 5] } },
  { id: 'check', text: 'Black plays bishop e5. Check.', take: { check: [5, 5] } },
  // When two pieces of a kind can reach the square: the file letter, said
  // between the piece and the square, cut out of a carrier of that shape.
  { id: 'dis_a', text: 'White plays rook a a8.', take: { dis_a: [4, 4] } },
  { id: 'dis_b', text: 'Black plays knight b d7.', take: { dis_b: [4, 4], knight_dis: [3, 3] } },
  { id: 'dsq_a8', text: 'White plays rook a a8.', take: { dsq_a8: [5, 5] } },
  { id: 'dsq_d7', text: 'Black plays knight b d7.', take: { dsq_d7: [5, 5] } },
];

const TESTS = [
  { id: 'y1', parts: ['black_plays', 'knight', 'sq_d7'], whole: 'Black plays knight d7.' },
  { id: 'y2', parts: ['white_plays', 'rook', 'sq_a8'], whole: 'White plays rook a8.' },
  { id: 'y3', parts: ['black_plays', 'queen', 'takes', 'tsq_e8'], whole: 'Black plays queen takes e8.' },
  { id: 'y4', parts: ['white_plays', 'rook', 'sq_a8', 'check'], whole: 'White plays rook a8. Check.' },
  { id: 'y5', parts: ['white_plays', 'rook', 'dis_a', 'sq_a8'], whole: 'White plays rook a a8.' },
  { id: 'y6', parts: ['black_plays', 'knight', 'dis_b', 'sq_d7'], whole: 'Black plays knight b d7.' },
];

const wordCount = (text) => text.replace(/[.,]/g, '').trim().split(/\s+/).length;

function cutWords(file, words, a, b) {
  const { info, pcm } = readPcm(file);
  const window = wav.speechWindow(file);
  const frameBytes = 2 * info.channels;
  const frames = pcm.length / frameBytes;
  const atMs = (ms) => Math.min(frames, Math.max(0, Math.round((ms / 1000) * info.sampleRate)));
  const startMs = a === 1 ? window.startSeconds * 1000 : (words[a - 2].endMs + words[a - 1].startMs) / 2;
  const endMs = b === words.length ? window.endSeconds * 1000 : (words[b - 1].endMs + words[b].startMs) / 2;
  return { info, pcm: pcm.subarray(atMs(startMs) * frameBytes, atMs(endMs) * frameBytes), startMs, endMs };
}

async function main() {
  fs.mkdirSync(OUT, { recursive: true });
  const jobs = TESTS.map((t) => ({ said: t.whole, voice: VOICE, outputPath: path.join(OUT, `${t.id}-whole.wav`) }));
  const r = await renderAll(jobs, { log: () => {} });
  console.log(`whole sentences: rendered ${r.rendered}, skipped ${r.skipped}`);

  const fragments = new Map();
  for (const c of CARRIERS) {
    const file = path.join(OUT, `${c.id}.wav`);
    const timesFile = path.join(OUT, `${c.id}.words.json`);
    let words;
    if (fs.existsSync(timesFile) && fs.existsSync(file)) {
      words = JSON.parse(fs.readFileSync(timesFile, 'utf8'));
    } else {
      words = await renderWithWords({ text: c.text, voice: VOICE, outputPath: file });
      fs.writeFileSync(timesFile, JSON.stringify(words, null, 2));
    }
    const expected = wordCount(c.text);
    console.log(`  ${c.id.padEnd(9)} ${words.length}/${expected} words: ${words.map((w) => w.text).join(' ')}`);
    if (words.length !== expected) throw new Error(`${c.id}: ${words.length} words where ${expected} were said`);
    for (const [name, [a, b]] of Object.entries(c.take)) fragments.set(name, cutWords(file, words, a, b));
  }

  const info = fragments.get('takes').info;
  const parts = [];
  for (const t of TESTS) {
    const pieces = t.parts.flatMap((p, i) => (
      i > 0 && PAUSE_MS > 0 && /^(sq_|tsq_)/.test(p) ? [silence(PAUSE_MS, info), fragments.get(p).pcm] : [fragments.get(p).pcm]
    ));
    const assembled = Buffer.concat(pieces);
    if (parts.length) parts.push(silence(2000, info));
    parts.push(assembled, silence(1200, info), readPcm(path.join(OUT, `${t.id}-whole.wav`)).pcm);
  }
  const out = path.join(LISTEN, `${VOICE}-E-short-cut-vs-whole${PAUSE_MS ? `-pause${PAUSE_MS}ms` : ''}.wav`);
  fs.writeFileSync(out, riff(Buffer.concat(parts), info));
  console.log(`listen: ${out}`);
}

main().catch((err) => { console.error(err); process.exit(1); });
