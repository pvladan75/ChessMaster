// phase0.js — the ear test of `docs/PLAN-GOVOR-IZ-KLIPOVA.md`, phase 0.
//
//   node tools/speech_clips/phase0.js
//
// For each of three candidate voices: renders the pilot's alphabet (phrases,
// pieces, squares, numbers) one clip per token, trims each clip, and then says
// every sentence of the draft table (D3) two ways — stitched from the clips,
// and whole in one Azure call. The two sets go into listening files under
// `out/listen/`, one per voice per way, with a second of silence between
// sentences; and for the first voice a fourth file plays one sentence with
// four different pauses between words, for D6.
//
// Idempotent by file: a clip or a whole sentence that already exists under
// `out/` is not rendered again. Phase 1 replaces the hand-written token list
// below with the manifest generated from the app's Dart vocabulary (D7).
'use strict';

const fs = require('fs');
const path = require('path');
const { renderAll, trimmed, stitch, silence, riff, readPcm } = require('./lib.js');

const OUT = path.join(__dirname, 'out');
const LISTEN = path.join(OUT, 'listen');

const VOICES = ['en-US-AvaNeural', 'en-US-AndrewNeural', 'en-GB-SoniaNeural'];
const PAUSE_MS = 80;
const PAUSES_TO_HEAR = [40, 80, 120, 160];
const GAP_BETWEEN_SENTENCES_MS = 1000;

/// The phase-0 vocabulary. `text` is what the screen will draw; `said` is what
/// Azure is told, the same unless the spelling has to steer the reading.
function tokens() {
  const list = [];
  const add = (id, text, said = text) => list.push({ id, text, said });

  add('white', 'White');
  add('black', 'Black');
  add('to_move', 'to move.');
  add('mate_in', 'Mate in');
  add('find_winning_path', 'Find the winning path.');
  add('plays', 'plays');
  add('from', 'from');
  add('to', 'to');
  add('takes', 'takes');
  add('check', 'Check.');
  add('checkmate', 'Checkmate.');
  add('castles_kingside', 'castles kingside.');
  add('castles_queenside', 'castles queenside.');
  add('promotes_to', 'promotes to');
  add('correct_keep_going', 'Correct. Keep going.');
  add('incorrect_try_another', 'Incorrect. Try another move.');
  add('puzzle_solved', 'Puzzle solved.');
  add('stockfish_wins_try_again', 'Stockfish wins. Try again.');
  add('draw_stalemate_try_again', 'Draw by stalemate. Try again.');

  for (const piece of ['king', 'queen', 'rook', 'bishop', 'knight', 'pawn']) {
    add(`piece_${piece}`, piece);
  }
  for (const file of 'abcdefgh') {
    for (let rank = 1; rank <= 8; rank++) add(`sq_${file}${rank}`, `${file}${rank}`);
  }
  for (let n = 0; n <= 99; n++) add(`n_${n}`, String(n));
  return list;
}

/// The draft table of D3, each sentence as the tokens that stitch it and as
/// the text Azure is handed whole.
const SENTENCES = [
  { id: 's01', tokens: ['white', 'to_move', 'mate_in', 'n_2'], whole: 'White to move. Mate in 2.' },
  { id: 's02', tokens: ['black', 'to_move', 'find_winning_path'], whole: 'Black to move. Find the winning path.' },
  { id: 's03', tokens: ['black', 'plays', 'piece_knight', 'from', 'sq_f6', 'to', 'sq_d7'], whole: 'Black plays knight from f6 to d7.' },
  { id: 's04', tokens: ['white', 'plays', 'piece_queen', 'from', 'sq_h5', 'takes', 'sq_f7', 'checkmate'], whole: 'White plays queen from h5 takes f7. Checkmate.' },
  { id: 's05', tokens: ['white', 'plays', 'piece_pawn', 'from', 'sq_e7', 'to', 'sq_e8', 'promotes_to', 'piece_queen', 'check'], whole: 'White plays pawn from e7 to e8, promotes to queen. Check.' },
  { id: 's06', tokens: ['black', 'castles_kingside'], whole: 'Black castles kingside.' },
  { id: 's07', tokens: ['correct_keep_going'], whole: 'Correct. Keep going.' },
  { id: 's08', tokens: ['incorrect_try_another'], whole: 'Incorrect. Try another move.' },
  { id: 's09', tokens: ['checkmate', 'puzzle_solved'], whole: 'Checkmate. Puzzle solved.' },
  { id: 's10', tokens: ['checkmate', 'stockfish_wins_try_again'], whole: 'Checkmate. Stockfish wins. Try again.' },
  { id: 's11', tokens: ['draw_stalemate_try_again'], whole: 'Draw by stalemate. Try again.' },
  { id: 's12', tokens: ['white', 'to_move', 'mate_in', 'n_3'], whole: 'White to move. Mate in 3.' },
  { id: 's13', tokens: ['white', 'plays', 'piece_rook', 'from', 'sq_a1', 'to', 'sq_a8', 'check'], whole: 'White plays rook from a1 to a8. Check.' },
];

function clipPath(voice, id) {
  return path.join(OUT, voice, 'clips', `${id}.wav`);
}

/// All [parts] (already-stitched wavs as `{ info, pcm }`) one after another
/// with [gapMs] between them, as one file to listen to.
function listening(parts, gapMs) {
  const info = parts[0].info;
  const buffers = [];
  parts.forEach((part, i) => {
    if (i > 0) buffers.push(silence(gapMs, info));
    buffers.push(part.pcm);
  });
  return riff(Buffer.concat(buffers), info);
}

async function runVoice(voice, vocabulary) {
  const byId = new Map(vocabulary.map((t) => [t.id, t]));
  for (const s of SENTENCES) {
    for (const id of s.tokens) {
      if (!byId.has(id)) throw new Error(`${s.id} names a token with no clip: ${id}`);
    }
  }

  console.log(`\n== ${voice} ==`);
  const clipJobs = vocabulary.map((t) => ({ said: t.said, voice, outputPath: clipPath(voice, t.id) }));
  const clips = await renderAll(clipJobs, { log: (line) => process.stdout.write(`\r  clips ${line}      `) });
  console.log(`\n  clips: ${clips.rendered} rendered, ${clips.skipped} already there, ${clips.characters} characters`);

  const wholeJobs = SENTENCES.map((s) => ({ said: s.whole, voice, outputPath: path.join(OUT, voice, 'whole', `${s.id}.wav`) }));
  const whole = await renderAll(wholeJobs, { log: (line) => process.stdout.write(`\r  whole ${line}      `) });
  console.log(`\n  whole: ${whole.rendered} rendered, ${whole.skipped} already there, ${whole.characters} characters`);

  // Trim every clip once; report what the trim took off, because the seams are
  // only as tight as the trim.
  const trimmedById = new Map();
  let cutStart = [];
  let cutEnd = [];
  for (const t of vocabulary) {
    const clip = trimmed(clipPath(voice, t.id));
    trimmedById.set(t.id, clip);
    cutStart.push(clip.cutStartMs);
    cutEnd.push(clip.cutEndMs);
  }
  const median = (xs) => { const s = [...xs].sort((a, b) => a - b); return s[Math.floor(s.length / 2)]; };
  console.log(`  trim: leading median ${median(cutStart).toFixed(0)} ms (max ${Math.max(...cutStart).toFixed(0)}), trailing median ${median(cutEnd).toFixed(0)} ms (max ${Math.max(...cutEnd).toFixed(0)})`);

  fs.writeFileSync(
    path.join(OUT, voice, 'manifest.json'),
    JSON.stringify({ voice, format: 'riff-22050hz-16bit-mono-pcm', tokens: vocabulary }, null, 2),
  );

  const stitchedDir = path.join(OUT, voice, 'stitched');
  fs.mkdirSync(stitchedDir, { recursive: true });
  const stitchedParts = [];
  const wholeParts = [];
  for (const s of SENTENCES) {
    const wavBuf = stitch(s.tokens.map((id) => trimmedById.get(id)), { pauseMs: PAUSE_MS });
    fs.writeFileSync(path.join(stitchedDir, `${s.id}.wav`), wavBuf);
    stitchedParts.push(trimmed(path.join(stitchedDir, `${s.id}.wav`), { marginMs: 0 }));
    wholeParts.push(trimmed(path.join(OUT, voice, 'whole', `${s.id}.wav`)));
  }

  fs.mkdirSync(LISTEN, { recursive: true });
  const a = path.join(LISTEN, `${voice}-A-stitched.wav`);
  const b = path.join(LISTEN, `${voice}-B-whole.wav`);
  fs.writeFileSync(a, listening(stitchedParts, GAP_BETWEEN_SENTENCES_MS));
  fs.writeFileSync(b, listening(wholeParts, GAP_BETWEEN_SENTENCES_MS));
  const secs = (p) => (readPcm(p).pcm.length / readPcm(p).info.byteRate).toFixed(1);
  console.log(`  listen: ${path.basename(a)} (${secs(a)} s), ${path.basename(b)} (${secs(b)} s)`);
  return { trimmedById };
}

async function pausesFile(voice, trimmedById) {
  const s = SENTENCES.find((x) => x.id === 's03');
  const parts = PAUSES_TO_HEAR.map((pauseMs) => {
    const buf = stitch(s.tokens.map((id) => trimmedById.get(id)), { pauseMs });
    const info = trimmedById.get(s.tokens[0]).info;
    return { info, pcm: buf.subarray(44) };
  });
  const file = path.join(LISTEN, `${voice}-C-pauses-${PAUSES_TO_HEAR.join('-')}ms.wav`);
  fs.writeFileSync(file, listening(parts, 1500));
  console.log(`  pauses: ${path.basename(file)} — "${s.whole}" at ${PAUSES_TO_HEAR.join(', ')} ms`);
}

async function main() {
  const vocabulary = tokens();
  console.log(`vocabulary: ${vocabulary.length} tokens, ${SENTENCES.length} sentences, ${VOICES.length} voices`);
  let first = null;
  for (const voice of VOICES) {
    const result = await runVoice(voice, vocabulary);
    if (!first) first = { voice, ...result };
  }
  await pausesFile(first.voice, first.trimmedById);
  console.log('\ndone');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
