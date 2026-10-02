// experiment_cut.js — phase 0b of `docs/PLAN-GOVOR-IZ-KLIPOVA.md`: words cut
// out of whole sentences instead of rendered alone.
//
//   node tools/speech_clips/experiment_cut.js
//
// The owner heard the stitched sentences and named the fault: not the pause,
// the intonation — every clip was an utterance of its own, so every word fell
// like the end of a sentence. Here every fragment is cut out of a carrier
// sentence of the same shape, so a square in the "from" position comes from a
// recording where it stood in the "from" position. The cut points are the
// word times the server's own speech-to-text returns (Groq, `services/stt/`),
// taken at the midpoint between neighbouring words.
//
// Output: `out/listen/<voice>-D-cut-vs-whole.wav` — three sentences, each
// first assembled from fragments of OTHER recordings, then spoken whole.
'use strict';

const fs = require('fs');
const path = require('path');
const { createRequire } = require('module');
const { renderAll, readPcm, riff, silence, wav } = require('./lib.js');
const { renderWithWords } = require('./sdk_render.js');

const VOICE = process.argv[2] || 'en-US-AvaNeural';
const PAUSE_AFTER_TO_MS = Number(process.argv[3] || 0);
const OUT = path.join(__dirname, 'out', 'exp-sdk', VOICE);
const LISTEN = path.join(__dirname, 'out', 'listen');

// Carriers: the sentence, and which word (1-based) each wanted fragment is.
const CARRIERS = [
  { id: 'frame', text: 'Black plays bishop from c3 to e5.', take: { black_plays: [1, 2], from: [4, 4], to: [6, 6] } },
  { id: 'white', text: 'White plays bishop from c3 to e5.', take: { white_plays: [1, 2] } },
  { id: 'p_knight', text: 'Black plays knight from c3 to e5.', take: { knight: [3, 3] } },
  { id: 'p_rook', text: 'Black plays rook from c3 to e5.', take: { rook: [3, 3] } },
  { id: 'p_queen', text: 'Black plays queen from c3 to e5.', take: { queen: [3, 3] } },
  { id: 'f_f6', text: 'Black plays bishop from f6 to e5.', take: { from_f6: [5, 5] } },
  { id: 'f_a1', text: 'Black plays bishop from a1 to e5.', take: { from_a1: [5, 5] } },
  { id: 'f_h8', text: 'Black plays bishop from h8 to e5.', take: { from_h8: [5, 5] } },
  { id: 't_d7', text: 'Black plays bishop from c3 to d7.', take: { to_d7: [7, 7] } },
  { id: 't_a8', text: 'Black plays bishop from c3 to a8.', take: { to_a8: [7, 7] } },
  { id: 't_e8', text: 'Black plays bishop from c3 to e8.', take: { to_e8: [7, 7] } },
];

const TESTS = [
  { id: 'x1', parts: ['black_plays', 'knight', 'from', 'from_f6', 'to', 'to_d7'], whole: 'Black plays knight from f6 to d7.' },
  { id: 'x2', parts: ['white_plays', 'rook', 'from', 'from_a1', 'to', 'to_a8'], whole: 'White plays rook from a1 to a8.' },
  { id: 'x3', parts: ['black_plays', 'queen', 'from', 'from_h8', 'to', 'to_e8'], whole: 'Black plays queen from h8 to e8.' },
];

const wordCount = (text) => text.replace(/[.,]/g, '').trim().split(/\s+/).length;

/// The PCM of words [a..b] of [file], cut at the midpoints between
/// neighbouring words; the first word starts where the voice starts and the
/// last ends where it ends (`speechWindow`).
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
  console.log(`whole sentences: rendered ${r.rendered}, skipped ${r.skipped}, ${r.characters} characters`);

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
    const spoken = words.map((w) => w.text.trim()).join(' ');
    const expected = wordCount(c.text);
    console.log(`  ${c.id.padEnd(9)} ${words.length}/${expected} words: ${spoken}`);
    if (words.length !== expected) {
      throw new Error(`${c.id}: the SDK reported ${words.length} words where ${expected} were said`);
    }
    for (const [name, [a, b]] of Object.entries(c.take)) {
      const cut = cutWords(file, words, a, b);
      fragments.set(name, cut);
      console.log(`      ${name.padEnd(12)} ${cut.startMs.toFixed(0)}–${cut.endMs.toFixed(0)} ms`);
    }
  }

  const info = fragments.get('from').info;
  const parts = [];
  for (const t of TESTS) {
    // The owner's one correction on the first listen: a small pause before the
    // square that ends the sentence. [PAUSE_AFTER_TO_MS] is the third argument.
    const assembled = Buffer.concat(t.parts.flatMap((p, i) => (
      i > 0 && t.parts[i - 1] === 'to' && PAUSE_AFTER_TO_MS > 0
        ? [silence(PAUSE_AFTER_TO_MS, info), fragments.get(p).pcm]
        : [fragments.get(p).pcm]
    )));
    fs.writeFileSync(path.join(OUT, `${t.id}-cut.wav`), riff(assembled, info));
    const whole = readPcm(path.join(OUT, `${t.id}-whole.wav`)).pcm;
    if (parts.length) parts.push(silence(2000, info));
    parts.push(assembled, silence(1200, info), whole);
  }
  fs.mkdirSync(LISTEN, { recursive: true });
  const suffix = PAUSE_AFTER_TO_MS > 0 ? `-pause${PAUSE_AFTER_TO_MS}ms` : '';
  const out = path.join(LISTEN, `${VOICE}-D-cut-vs-whole${suffix}.wav`);
  fs.writeFileSync(out, riff(Buffer.concat(parts), info));
  console.log(`listen: ${out}`);
}

main().catch((err) => { console.error(err); process.exit(1); });
