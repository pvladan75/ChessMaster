// render.js — the clips of `chess_app/assets/speech/` from its manifest.
//
//   cd chess_app && dart run tool/speech_manifest.dart
//   node tools/speech_clips/render.js            (from the repository root)
//
// Reads `assets/speech/manifest.json` (written from the Dart vocabulary, D7),
// renders every distinct carrier sentence once through Azure's Speech SDK
// with the times of its words (`sdk_render.js`), cuts each token's words out
// at the midpoints between neighbours (`cut.js`), trims a phrase to the speech
// floor `wav.js` defines, and writes `<id>.wav` beside the manifest together
// with `rendered.json` — the lock: for every id, the carrier, the words and
// the voice its clip was made from. A token whose lock entry matches and whose
// file exists is not rendered again; a changed carrier or voice is.
//
// Carriers are cached under `out/render/<voice>/` (gitignored) so a re-cut
// costs no characters. A carrier whose reported word count is not the
// manifest's is refused: the cut points could not be trusted.
'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { trimmed, readPcm, riff, wav } = require('./lib.js');
const { renderWithWords } = require('./sdk_render.js');
const { wordCount, wordRangeMs, slicePcm, lockEntry, sameLock } = require('./cut.js');

const ASSETS = path.resolve(__dirname, '..', '..', 'chess_app', 'assets', 'speech');
const MANIFEST = path.join(ASSETS, 'manifest.json');
const LOCK = path.join(ASSETS, 'rendered.json');

async function carrierWithWords(voice, text) {
  const dir = path.join(__dirname, 'out', 'render', voice);
  const key = crypto.createHash('sha256').update(text).digest('hex').slice(0, 24);
  const file = path.join(dir, `${key}.wav`);
  const timesFile = path.join(dir, `${key}.words.json`);
  let words;
  let rendered = false;
  if (fs.existsSync(file) && fs.existsSync(timesFile)) {
    words = JSON.parse(fs.readFileSync(timesFile, 'utf8'));
  } else {
    words = await renderWithWords({ text, voice, outputPath: file });
    fs.writeFileSync(timesFile, JSON.stringify({ text, words }, null, 2));
    rendered = true;
  }
  if (words.words) words = words.words;
  const expected = wordCount(text);
  if (words.length !== expected) {
    throw new Error(`"${text}": the SDK reported ${words.length} words where ${expected} were said`);
  }
  return { file, words, rendered };
}

async function main() {
  const manifest = JSON.parse(fs.readFileSync(MANIFEST, 'utf8'));
  const voice = manifest.voice;
  const lock = fs.existsSync(LOCK) ? JSON.parse(fs.readFileSync(LOCK, 'utf8')) : {};
  const newLock = {};
  let rendered = 0;
  let cut = 0;
  let kept = 0;
  let characters = 0;

  for (const token of manifest.tokens) {
    const entry = lockEntry(token, voice);
    const file = path.join(ASSETS, `${token.id}.wav`);
    if (sameLock(lock[token.id], entry) && fs.existsSync(file)) {
      newLock[token.id] = entry;
      kept++;
      continue;
    }
    const carrier = await carrierWithWords(voice, token.carrier);
    if (carrier.rendered) {
      rendered++;
      characters += token.carrier.length;
    }
    if (token.kind === 'phrase') {
      const t = trimmed(carrier.file);
      fs.writeFileSync(file, riff(t.pcm, t.info));
    } else {
      const { info, pcm } = readPcm(carrier.file);
      const window = wav.speechWindow(carrier.file);
      const range = wordRangeMs(carrier.words, token.wordFrom, token.wordTo, {
        startMs: window.startSeconds * 1000,
        endMs: window.endSeconds * 1000,
      });
      fs.writeFileSync(file, riff(slicePcm(pcm, info, range.fromMs, range.toMs), info));
    }
    newLock[token.id] = entry;
    cut++;
    process.stdout.write(`\r  ${cut} clips written, ${rendered} carriers rendered     `);
  }

  // A clip whose token is gone from the manifest goes with it.
  const wanted = new Set(manifest.tokens.map((t) => `${t.id}.wav`));
  let removed = 0;
  for (const name of fs.readdirSync(ASSETS)) {
    if (name.endsWith('.wav') && !wanted.has(name)) {
      fs.unlinkSync(path.join(ASSETS, name));
      removed++;
    }
  }
  fs.writeFileSync(LOCK, `${JSON.stringify(newLock, null, 2)}\n`);

  let bytes = 0;
  for (const name of wanted) bytes += fs.statSync(path.join(ASSETS, name)).size;
  console.log(`\n${manifest.tokens.length} tokens: ${kept} kept, ${cut} written, ${removed} removed; `
    + `${rendered} carriers rendered (${characters} characters); ${(bytes / 1048576).toFixed(1)} MB of clips`);
}

main().catch((err) => { console.error(err); process.exit(1); });
