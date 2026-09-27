// Speech to text, measured — phase 5 of docs/PLAN-PRIPREMA.md. Azure's half.
//
// Sends one sound file to Azure Speech's fast transcription and writes down
// what came back and what it cost to get: the size sent, the time the answer
// took, the script the text is in, and whether every word has a time and the
// times never run backwards.
//
// Run by hand, never by the app and never by the server:
//
//   node tools/stt_measure/azure.js <sound file> [--locale sr-RS] [--tag name]
//                                   [--phrases file]
//
// `--phrases` names a text file of words to expect, one to a line
// (`chess_words.sr.txt` beside this file).
//
// The key and the region are read from `chess_backend/.env`
// (AZURE_SPEECH_KEY, AZURE_SPEECH_REGION) — the same two the voice uses — and
// are never printed. The answer is kept under `tools/stt_measure/out/`, which
// git ignores: a transcript is what somebody said.
//
// **A sound file leaves this machine when this runs.** It is run on a
// recording only on its owner's word.

'use strict';

const fs = require('fs');
const path = require('path');

// The version that takes a phrase list — words the vendor is told to expect.
const API_VERSION = '2025-10-15';

function envFrom(file) {
  const out = {};
  for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
    const m = /^([A-Z0-9_]+)=(.*)$/.exec(line.trim());
    if (m) out[m[1]] = m[2].replace(/^["']|["']$/g, '');
  }
  return out;
}

function arg(name, fallback) {
  const at = process.argv.indexOf(`--${name}`);
  return at === -1 ? fallback : process.argv[at + 2 - 1];
}

/// Which script a text is written in, by counting letters.
function scriptOf(text) {
  let cyrillic = 0;
  let latin = 0;
  for (const ch of text) {
    if (/[Ѐ-ӿ]/.test(ch)) cyrillic++;
    else if (/[A-Za-zÀ-ɏ]/.test(ch)) latin++;
  }
  return { cyrillic, latin };
}

/// Every word of the answer in order, with where it starts and ends.
function wordsOf(answer) {
  const words = [];
  for (const phrase of answer.phrases || []) {
    for (const w of phrase.words || []) {
      words.push({
        text: w.text,
        startMs: w.offsetMilliseconds,
        endMs: w.offsetMilliseconds + w.durationMilliseconds,
      });
    }
  }
  return words;
}

function timesOf(words) {
  let untimed = 0;
  let backwards = 0;
  let overlapping = 0;
  for (let i = 0; i < words.length; i++) {
    const w = words[i];
    if (!Number.isFinite(w.startMs) || !Number.isFinite(w.endMs)) {
      untimed++;
      continue;
    }
    if (i > 0 && w.startMs < words[i - 1].startMs) backwards++;
    if (i > 0 && w.startMs < words[i - 1].endMs) overlapping++;
  }
  return { untimed, backwards, overlapping };
}

async function main() {
  const file = process.argv[2];
  if (!file || file.startsWith('--')) {
    console.error('usage: node tools/stt_measure/azure.js <sound file> ' +
        '[--locale sr-RS] [--tag name]');
    process.exit(2);
  }
  const locale = arg('locale', 'sr-RS');
  const tag = arg('tag', path.basename(file).replace(/\.[^.]+$/, ''));

  const env = envFrom(path.join(__dirname, '..', '..', 'chess_backend', '.env'));
  const key = env.AZURE_SPEECH_KEY;
  const region = env.AZURE_SPEECH_REGION;
  if (!key || !region) {
    console.error('AZURE_SPEECH_KEY or AZURE_SPEECH_REGION is not set in ' +
        'chess_backend/.env');
    process.exit(1);
  }

  const sound = fs.readFileSync(file);
  const form = new FormData();
  form.append('audio', new Blob([sound]), path.basename(file));
  const phrasesFile = arg('phrases', null);
  const phrases = phrasesFile
    ? fs.readFileSync(phrasesFile, 'utf8').split(/\r?\n/)
        .map((l) => l.trim()).filter((l) => l && !l.startsWith('#'))
    : [];
  const definition = { locales: [locale] };
  if (phrases.length) definition.phraseList = { phrases };
  form.append('definition', JSON.stringify(definition));

  const url = `https://${region}.api.cognitive.microsoft.com/speechtotext/` +
      `transcriptions:transcribe?api-version=${API_VERSION}`;
  const started = Date.now();
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Ocp-Apim-Subscription-Key': key },
    body: form,
  });
  const tookMs = Date.now() - started;
  const body = await res.text();

  const outDir = path.join(__dirname, 'out');
  fs.mkdirSync(outDir, { recursive: true });
  const stem = path.join(outDir, `${tag}.azure.${locale}`);

  if (!res.ok) {
    fs.writeFileSync(`${stem}.error.txt`, `${res.status}\n${body}`);
    console.log(`REFUSED ${res.status} after ${tookMs} ms`);
    console.log(body.slice(0, 600));
    process.exit(1);
  }

  const answer = JSON.parse(body);
  fs.writeFileSync(`${stem}.json`, JSON.stringify(answer, null, 1));

  const text = (answer.combinedPhrases || []).map((p) => p.text).join(' ');
  fs.writeFileSync(`${stem}.txt`, text);
  const words = wordsOf(answer);
  const summary = {
    vendor: 'azure fast transcription',
    apiVersion: API_VERSION,
    locale,
    phrasesGiven: phrases.length,
    sentBytes: sound.length,
    answerMs: tookMs,
    audioMs: answer.durationMilliseconds,
    phrases: (answer.phrases || []).length,
    words: words.length,
    script: scriptOf(text),
    times: timesOf(words),
    lowestConfidence: Math.min(
        ...(answer.phrases || []).map((p) => p.confidence ?? 1)),
  };
  fs.writeFileSync(`${stem}.summary.json`, JSON.stringify(summary, null, 1));
  console.log(JSON.stringify(summary, null, 1));
}

main().catch((e) => {
  console.error(`failed: ${e.message}`);
  process.exit(1);
});
