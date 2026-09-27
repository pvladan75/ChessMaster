// Speech to text, measured — phase 5 of docs/PLAN-PRIPREMA.md. Groq's half.
//
// Sends one sound file to Groq's Whisper and writes down what came back, in
// the **same shape Azure's answer has**, so that `beats.js` and every count
// read both vendors through one reader:
//
//   { durationMilliseconds, combinedPhrases: [{text}],
//     phrases: [{ offsetMilliseconds, durationMilliseconds, text, confidence,
//                 words: [{ text, offsetMilliseconds, durationMilliseconds }] }] }
//
// Groq's own answer is kept beside it, untouched, as `<tag>.groq.<model>.raw.json`.
//
//   node tools/stt_measure/groq.js <sound file> [--language sr]
//        [--model whisper-large-v3] [--tag name] [--prompt file]
//
// The key is read from `chess_backend/.env` (GROQ_API_KEY) and never printed.
// The sound is sent as FLAC, which loses nothing and is about half the size:
// Groq's free tier takes 25 MB, and half an hour as recorded is 57.6 MB.
//
// **A sound file leaves this machine when this runs.** It is run on a
// recording only on its owner's word.

'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

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
  return at === -1 ? fallback : process.argv[at + 1];
}

function scriptOf(text) {
  let cyrillic = 0;
  let latin = 0;
  for (const ch of text) {
    if (/[Ѐ-ӿ]/.test(ch)) cyrillic++;
    else if (/[A-Za-zÀ-ɏ]/.test(ch)) latin++;
  }
  return { cyrillic, latin };
}

/// Whisper's segments and words as Azure's phrases. A word belongs to the
/// segment it starts in. Whisper says how sure it was of a segment as the mean
/// logarithm of a probability; its exponent is put where Azure has
/// `confidence`, and the two are **not** the same measure.
function asPhrases(raw) {
  const words = (raw.words || []).map((w) => ({
    text: String(w.word).trim(),
    offsetMilliseconds: Math.round(w.start * 1000),
    durationMilliseconds: Math.max(0, Math.round((w.end - w.start) * 1000)),
  }));
  const segments = raw.segments || [];
  const phrases = segments.map((s, i) => {
    const from = Math.round(s.start * 1000);
    const to = i + 1 < segments.length
      ? Math.round(segments[i + 1].start * 1000) : Infinity;
    return {
      offsetMilliseconds: from,
      durationMilliseconds: Math.round((s.end - s.start) * 1000),
      text: String(s.text).trim(),
      confidence: Math.exp(s.avg_logprob ?? 0),
      noSpeech: s.no_speech_prob,
      words: words.filter(
          (w) => w.offsetMilliseconds >= from && w.offsetMilliseconds < to),
    };
  });
  // Whisper's words carry no punctuation and its segments do; the reader cuts
  // sentences at a word that ends one, so a segment's last word takes its
  // segment's last mark.
  for (const p of phrases) {
    const mark = /[.?!]$/.exec(p.text);
    const last = p.words[p.words.length - 1];
    if (mark && last && !/[.?!]$/.test(last.text)) last.text += mark[0];
  }
  return {
    durationMilliseconds: Math.round((raw.duration || 0) * 1000),
    combinedPhrases: [{ text: String(raw.text || '').trim() }],
    phrases,
  };
}

async function main() {
  const file = process.argv[2];
  if (!file || file.startsWith('--')) {
    console.error('usage: node tools/stt_measure/groq.js <sound file> ' +
        '[--language sr] [--model whisper-large-v3] [--tag name] [--prompt file]');
    process.exit(2);
  }
  const language = arg('language', 'sr');
  const model = arg('model', 'whisper-large-v3');
  const tag = arg('tag', path.basename(file).replace(/\.[^.]+$/, ''));
  const promptFile = arg('prompt', null);

  const env = envFrom(path.join(__dirname, '..', '..', 'chess_backend', '.env'));
  const key = env.GROQ_API_KEY;
  if (!key) {
    console.error('GROQ_API_KEY is not set in chess_backend/.env');
    process.exit(1);
  }

  const flac = path.join(os.tmpdir(), `stt-${process.pid}.flac`);
  execFileSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', '-i', file,
    '-ar', '16000', '-ac', '1', '-c:a', 'flac', flac]);
  let sound;
  try {
    sound = fs.readFileSync(flac);
  } finally {
    fs.rmSync(flac, { force: true });
  }

  const form = new FormData();
  form.append('file', new Blob([sound]), 'sound.flac');
  form.append('model', model);
  form.append('language', language);
  form.append('response_format', 'verbose_json');
  form.append('timestamp_granularities[]', 'word');
  form.append('timestamp_granularities[]', 'segment');
  form.append('temperature', '0');
  if (promptFile) form.append('prompt', fs.readFileSync(promptFile, 'utf8').trim());

  const started = Date.now();
  const res = await fetch('https://api.groq.com/openai/v1/audio/transcriptions', {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}` },
    body: form,
  });
  const tookMs = Date.now() - started;
  const body = await res.text();

  const outDir = path.join(__dirname, 'out');
  fs.mkdirSync(outDir, { recursive: true });
  const stem = path.join(outDir, `${tag}.groq.${model}`);

  if (!res.ok) {
    fs.writeFileSync(`${stem}.error.txt`, `${res.status}\n${body}`);
    console.log(`REFUSED ${res.status} after ${tookMs} ms`);
    console.log(body.slice(0, 600));
    process.exit(1);
  }

  const raw = JSON.parse(body);
  fs.writeFileSync(`${stem}.raw.json`, JSON.stringify(raw, null, 1));
  const answer = asPhrases(raw);
  fs.writeFileSync(`${stem}.json`, JSON.stringify(answer, null, 1));
  const text = answer.combinedPhrases[0].text;
  fs.writeFileSync(`${stem}.txt`, text);

  const words = answer.phrases.flatMap((p) => p.words);
  let backwards = 0;
  for (let i = 1; i < words.length; i++) {
    if (words[i].offsetMilliseconds < words[i - 1].offsetMilliseconds) backwards++;
  }
  const summary = {
    vendor: 'groq',
    model,
    language,
    promptGiven: Boolean(promptFile),
    sentBytes: sound.length,
    recordedBytes: fs.statSync(file).size,
    answerMs: tookMs,
    audioMs: answer.durationMilliseconds,
    segments: answer.phrases.length,
    words: words.length,
    wordsOutsideAnySegment: (raw.words || []).length - words.length,
    script: scriptOf(text),
    times: { backwards },
  };
  fs.writeFileSync(`${stem}.summary.json`, JSON.stringify(summary, null, 1));
  console.log(JSON.stringify(summary, null, 1));
}

if (require.main === module) {
  main().catch((e) => {
    console.error(`failed: ${e.message}`);
    process.exit(1);
  });
}

module.exports = { asPhrases };
